import Foundation
import Security
import CryptoKit

@main struct ExtensionChecks {
  static func sign(_ payload: Data, declared: Data? = nil, rsa: Bool = true) throws -> Data {
    func variable(_ value: Int) -> Data {
      var value = value, bytes = Data()
      repeat { bytes.append(UInt8(value & 127) | (value > 127 ? 128 : 0)); value >>= 7 } while value > 0
      return bytes
    }
    func field(_ number: Int, _ value: Data) -> Data { variable(number * 8 + 2) + variable(value.count) + value }
    func der(_ tag: UInt8, _ value: Data) -> Data {
      let size = value.count
      let length = size < 128 ? Data([UInt8(size)]) : size < 256 ? Data([0x81, UInt8(size)]) : Data([0x82, UInt8(size >> 8), UInt8(size & 255)])
      return Data([tag]) + length + value
    }
    let key = SecKeyCreateRandomKey([kSecAttrKeyType: rsa ? kSecAttrKeyTypeRSA : kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits: rsa ? 2048 : 256] as CFDictionary, nil)!
    let raw = SecKeyCopyExternalRepresentation(SecKeyCopyPublicKey(key)!, nil)! as Data
    let algorithm = rsa ? Data([0x30,13,6,9,42,134,72,134,247,13,1,1,1,5,0]) : Data([0x30,19,6,7,42,134,72,206,61,2,1,6,8,42,134,72,206,61,3,1,7])
    let spki = der(0x30, algorithm + der(3, Data([0]) + raw))
    let signed = field(1, declared ?? Data(SHA256.hash(data: spki).prefix(16)))
    var count = UInt32(signed.count).littleEndian
    let message = Data("CRX3 SignedData\0".utf8) + withUnsafeBytes(of: &count) { Data($0) } + signed + payload
    let signature = SecKeyCreateSignature(key, rsa ? .rsaSignatureMessagePKCS1v15SHA256 : .ecdsaSignatureMessageX962SHA256, message as CFData, nil)! as Data
    let header = field(rsa ? 2 : 3, field(1, spki) + field(2, signature)) + field(10000, signed)
    var size = UInt32(header.count).littleEndian
    return Data([67,114,50,52,3,0,0,0]) + withUnsafeBytes(of: &size) { Data($0) } + header + payload
  }
  static func main() throws {
    if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--sign" {
      let signed = try sign(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
      try signed.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
      print(try WebKitCRXSignature.verify(signed)); return
    }
    for rsa in [true, false] {
      let valid = try sign(Data([80,75,3,4,0]), rsa: rsa)
      let id = try WebKitCRXSignature.verify(valid)
      precondition(id.count == 32)
      var tampered = valid; tampered[tampered.count-1] ^= 1
      var header = valid; header[header.count-6] ^= 1
      let wrong = try sign(Data([80,75,3,4]), declared: Data(repeating: 0, count: 16), rsa: rsa)
      for bad in [tampered, header, wrong, Data(valid.prefix(15))] {
        do { _ = try WebKitCRXSignature.verify(bad); preconditionFailure("Invalid signature accepted") } catch {}
      }
      do { _ = try WebKitCRXSignature.verify(valid, expected: String(repeating: "a", count: 32)); preconditionFailure("Wrong store id accepted") } catch {}
    }
    precondition(WebKitStorePolicy.identifier(URL(string: "https://chromewebstore.google.com/detail/name/" + String(repeating: "a", count: 32))) != nil)
    for text in ["http://chromewebstore.google.com/detail/", "https://evil.test/detail/", "https://chromewebstore.google.com:444/detail/", "https://chromewebstore.google.com/detail/name/bad"] {
      precondition(WebKitStorePolicy.identifier(URL(string: text)) == nil)
    }
    precondition(WebKitStorePolicy.allows(main: true, scheme: "https", host: "chromewebstore.google.com", port: 443))
    precondition(!WebKitStorePolicy.allows(main: false, scheme: "https", host: "chromewebstore.google.com", port: 443))
    precondition(!WebKitStorePolicy.allows(main: true, scheme: "https", host: "chromewebstore.google.com.evil.test", port: 443))

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
      try sign(Data(contentsOf: zip)).write(to: archive)
      let unpacked = scratch.appendingPathComponent("unpacked-" + kind)
      try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
      do { try WebKitExtensionArchive.unpack(archive.path, into: unpacked); preconditionFailure("Unsafe ZIP accepted") }
      catch { precondition(error.localizedDescription.contains("Unsafe extension archive entry"), error.localizedDescription) }
    }
    print("PASS WebKit extensions: RSA/ECDSA authentication, tampered payload/header, wrong id, truncation, store origin/URL; CRX3 bounds/version/payload/id, stable Chrome alphabet, folder symlink rejection, ZIP traversal/symlink rejection")
  }
}
