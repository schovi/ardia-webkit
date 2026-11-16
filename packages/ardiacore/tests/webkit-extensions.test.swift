import Foundation

@main struct ExtensionChecks {
  static func main() throws {
    func rejected(_ data: Data) {
      do { _ = try WebKitExtensionArchive.zipPayload(data); preconditionFailure("Accepted invalid CRX") } catch {}
    }
    rejected(Data())
    rejected(Data("Cr24".utf8))
    rejected(Data([67,114,50,52,2,0,0,0,0,0,0,0,80,75,3,4]))
    rejected(Data([67,114,50,52,3,0,0,0,255,255,255,255,80,75,3,4]))
    let signed = Data([10,16] + Array(repeating:42,count:16))
    let header = Data([0x82,0xf1,4,UInt8(signed.count)]) + signed
    let crx = Data([67,114,50,52,3,0,0,0,UInt8(header.count),0,0,0]) + header + Data([80,75,3,4])
    let payload = try WebKitExtensionArchive.zipPayload(crx)
    precondition(payload == Data([80,75,3,4]))
    let identifier = try WebKitExtensionArchive.signedIdentifier(crx)
    precondition(identifier == String(repeating:"ck",count:16))
    do { _ = try WebKitExtensionArchive.signedIdentifier(Data([67,114,50,52,3,0,0,0,0,0,0,0,80,75,3,4])); preconditionFailure("Missing signed id accepted") } catch {}
    precondition(WebKitExtensionArchive.identifier(Data("fixture".utf8)).count == 32)
    let scratch = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:scratch) }
    try Data("fixture".utf8).write(to:scratch.appendingPathComponent("manifest.json"))
    try WebKitExtensionArchive.validateFolder(scratch)
    try FileManager.default.createSymbolicLink(at:scratch.appendingPathComponent("escape"),withDestinationURL:URL(fileURLWithPath:"/tmp"))
    do { try WebKitExtensionArchive.validateFolder(scratch); preconditionFailure("Symbolic link accepted") } catch {}
    try FileManager.default.removeItem(at: scratch.appendingPathComponent("escape"))
    let zip = scratch.appendingPathComponent("hostile.zip")
    for kind in ["traversal", "symlink"] {
      let writer = Process()
      writer.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
      writer.arguments = ["-c", """
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as archive:
    if sys.argv[2] == 'traversal':
        archive.writestr('../escape', 'hostile')
    else:
        entry = zipfile.ZipInfo('escape')
        entry.create_system = 3
        entry.external_attr = 0o120777 << 16
        archive.writestr(entry, '/tmp')
""", zip.path, kind]
      try writer.run()
      writer.waitUntilExit()
      precondition(writer.terminationStatus == 0)
      let archive = scratch.appendingPathComponent("hostile.crx")
      try (Data(crx.dropLast(4)) + Data(contentsOf: zip)).write(to: archive)
      do { try WebKitExtensionArchive.unpack(archive.path, into: scratch.appendingPathComponent("unpacked")); preconditionFailure("Unsafe ZIP accepted") } catch {}
    }
    print("PASS WebKit extensions: CRX3 bounds/version/payload/id, stable Chrome alphabet, folder symlink rejection, ZIP traversal/symlink rejection")
  }
}
