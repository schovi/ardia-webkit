import CryptoKit
import Foundation

struct WebKitExtensionArchive {
  static func failure(_ message: String) -> NSError { NSError(domain: "ArdiaExtensionArchive", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }

  static func identifier(_ data: Data) -> String {
    SHA256.hash(data: data).prefix(16).flatMap { [String(UnicodeScalar(97 + Int($0 >> 4))!), String(UnicodeScalar(97 + Int($0 & 15))!)] }.joined()
  }

  static func validateFolder(_ folder: URL) throws {
    guard try folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw failure("Extension folder cannot be a symbolic link") }
    guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else { throw failure("Cannot read extension folder") }
    var size = 0
    for case let file as URL in enumerator {
      let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
      guard values.isSymbolicLink != true else { throw failure("Extension folders cannot contain symbolic links") }
      guard values.isDirectory == true || values.isRegularFile == true else { throw failure("Extension folders can contain only regular files and directories") }
      size += values.fileSize ?? 0
      guard size <= 268435456 else { throw failure("Extension exceeds 256 MiB") }
    }
  }

  static func zipPayload(_ data: Data) throws -> Data {
    guard data.count >= 12, data.prefix(4) == Data("Cr24".utf8) else { throw failure("Invalid CRX header") }
    func word(_ offset: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(data[offset + $1]) << ($1 * 8) } }
    guard word(4) == 3 else { throw failure("Only CRX3 packages are supported") }
    let length = Int(word(8))
    guard length <= data.count - 16 else { throw failure("Truncated CRX3 header") }
    let payload = data.dropFirst(12 + length)
    guard payload.prefix(4) == Data([0x50, 0x4b, 3, 4]) else { throw failure("CRX3 package has no ZIP payload") }
    return Data(payload)
  }

  static func signedIdentifier(_ data: Data) throws -> String {
    _ = try zipPayload(data)
    let length = (0..<4).reduce(0) { $0 | Int(data[8 + $1]) << ($1 * 8) }
    guard let signed = try WebKitCRXSignature.fields(data.subdata(in: 12..<(12 + length)))[10000]?.first, let id = try WebKitCRXSignature.fields(signed)[1]?.first, id.count == 16 else { throw failure("Missing CRX3 extension id") }
    return id.flatMap { [String(UnicodeScalar(97 + Int($0 >> 4))!), String(UnicodeScalar(97 + Int($0 & 15))!)] }.joined()
  }

  static func unpack(_ path: String, into folder: URL) throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    guard data.count <= 134217728 else { throw failure("CRX exceeds 128 MiB") }
    _ = try WebKitCRXSignature.verify(data)
    let zip = folder.appendingPathComponent("package.zip")
    try zipPayload(data).write(to: zip)
    defer { try? FileManager.default.removeItem(at: zip) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-c", """
import pathlib, stat, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    entries = archive.infolist()
    if sum(entry.file_size for entry in entries) > 268435456:
        raise ValueError('Extension exceeds 256 MiB')
    for entry in entries:
        path = pathlib.PurePosixPath(entry.filename)
        if path.is_absolute() or '..' in path.parts or '\\\\' in entry.filename or stat.S_ISLNK(entry.external_attr >> 16):
            raise ValueError('Unsafe extension archive entry')
    archive.extractall(sys.argv[2])
""", zip.path, folder.path]
    let output = Pipe()
    process.standardError = output
    try process.run()
    let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: deadline)
    process.waitUntilExit()
    deadline.cancel()
    guard process.terminationStatus == 0 else { throw failure("Could not unpack CRX3: " + String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)) }
    try validateFolder(folder)
  }
}
