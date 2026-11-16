import CryptoKit
import Foundation
import Security

struct WebKitCRXSignature {
  static func fields(_ bytes: Data) throws -> [Int: [Data]] {
    var offset = 0
    func variable() throws -> Int {
      var value = 0
      for shift in stride(from: 0, through: 56, by: 7) {
        guard offset < bytes.count else { throw WebKitExtensionArchive.failure("Truncated protobuf") }
        let byte = bytes[offset]; offset += 1
        value |= Int(byte & 127) << shift
        if byte < 128 { return value }
      }
      throw WebKitExtensionArchive.failure("Invalid protobuf")
    }
    var result: [Int: [Data]] = [:]
    while offset < bytes.count {
      let tag = try variable()
      guard tag >> 3 > 0 else { throw WebKitExtensionArchive.failure("Invalid protobuf field") }
      if tag & 7 == 0 { _ = try variable(); continue }
      guard tag & 7 == 2 else { throw WebKitExtensionArchive.failure("Unsupported protobuf field") }
      let size = try variable()
      guard size <= bytes.count - offset else { throw WebKitExtensionArchive.failure("Truncated protobuf field") }
      result[tag >> 3, default: []].append(bytes.subdata(in: offset..<(offset + size)))
      offset += size
    }
    return result
  }

  static func publicKey(_ spki: Data, rsa: Bool) -> SecKey? {
    let bytes = Array(spki)
    var offset = 0
    func element(_ tag: UInt8) -> Data? {
      guard offset + 2 <= bytes.count, bytes[offset] == tag else { return nil }
      offset += 1
      var size = Int(bytes[offset]); offset += 1
      if size >= 128 {
        let count = size & 127
        guard count > 0, count <= 4, offset + count <= bytes.count else { return nil }
        size = 0
        for _ in 0..<count { size = size * 256 + Int(bytes[offset]); offset += 1 }
      }
      guard size <= bytes.count - offset else { return nil }
      let data = Data(bytes[offset..<(offset + size)])
      offset += size
      return data
    }
    guard let sequence = element(0x30), offset == bytes.count else { return nil }
    offset = bytes.count - sequence.count
    guard element(0x30) != nil, let bits = element(3), bits.first == 0, offset == bytes.count else { return nil }
    return SecKeyCreateWithData(Data(bits.dropFirst()) as CFData, [kSecAttrKeyType: rsa ? kSecAttrKeyTypeRSA : kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass: kSecAttrKeyClassPublic] as CFDictionary, nil)
  }

  static func verify(_ data: Data, expected: String? = nil) throws -> String {
    guard data.count <= 104857600 else { throw WebKitExtensionArchive.failure("CRX exceeds 100 MiB") }
    let payload = try WebKitExtensionArchive.zipPayload(data)
    let length = (0..<4).reduce(0) { $0 | Int(data[8 + $1]) << ($1 * 8) }
    guard length <= 1048576 else { throw WebKitExtensionArchive.failure("CRX header exceeds 1 MiB") }
    let header = try fields(data.subdata(in: 12..<(12 + length)))
    guard let signed = header[10000], signed.count == 1 else { throw WebKitExtensionArchive.failure("Missing signed header") }
    let identifiers = try fields(signed[0])[1] ?? []
    guard identifiers.count == 1, identifiers[0].count == 16 else { throw WebKitExtensionArchive.failure("Invalid signed id") }
    let id = identifiers[0].flatMap { [String(UnicodeScalar(97 + Int($0 >> 4))!), String(UnicodeScalar(97 + Int($0 & 15))!)] }.joined()
    guard expected == nil || expected == id else { throw WebKitExtensionArchive.failure("Package id differs from requested id") }
    var count = UInt32(signed[0].count).littleEndian
    let message = Data("CRX3 SignedData\0".utf8) + withUnsafeBytes(of: &count) { Data($0) } + signed[0] + payload
    for field in [2, 3] {
      for proof in header[field] ?? [] {
        let parts = try fields(proof)
        guard let keys = parts[1], keys.count == 1, let signatures = parts[2], signatures.count == 1,
          Data(SHA256.hash(data: keys[0]).prefix(16)) == identifiers[0], let key = publicKey(keys[0], rsa: field == 2) else { continue }
        let algorithm: SecKeyAlgorithm = field == 2 ? .rsaSignatureMessagePKCS1v15SHA256 : .ecdsaSignatureMessageX962SHA256
        if SecKeyVerifySignature(key, algorithm, message as CFData, signatures[0] as CFData, nil) { return id }
      }
    }
    throw WebKitExtensionArchive.failure("CRX signature does not authenticate its id and payload")
  }
}
