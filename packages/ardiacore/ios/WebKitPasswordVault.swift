import CryptoKit
import Foundation
import SQLite3
import WebKit

enum WebKitPasswordOrigin {
  static func canonical(_ scheme: String, _ host: String, _ port: Int?) -> String? {
    let scheme = scheme.lowercased()
    let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    guard ["http", "https"].contains(scheme), !host.isEmpty, port == nil || (1...65535).contains(port!) else { return nil }
    let name = host.contains(":") ? "[\(host)]" : host
    let standard = scheme == "https" ? 443 : 80
    return "\(scheme)://\(name)" + (port == nil || port == standard ? "" : ":\(port!)")
  }

  static func of(_ url: URL) -> String? { canonical(url.scheme ?? "", url.host ?? "", url.port) }
  static func of(_ origin: WKSecurityOrigin) -> String? { canonical(origin.protocol, origin.host, origin.port == 0 ? nil : origin.port) }
  static func of(_ text: String) -> String? { URL(string: text).flatMap(of) }
}

final class WebKitPasswordSecret {
  let bytes: NSMutableData
  init(_ data: Data) { bytes = NSMutableData(data: data) }
  convenience init(_ text: String) { self.init(Data(text.utf8)) }
  var text: String { String(data: bytes as Data, encoding: .utf8) ?? "" }
  static func decode(_ hex: String) throws -> WebKitPasswordSecret {
    guard hex.utf8.count <= 131072, hex.utf8.count % 2 == 0 else { throw WebKitPasswordFailure.arguments }
    let secret = WebKitPasswordSecret(Data())
    var high: UInt8?
    for byte in hex.utf8 {
      let digit: UInt8
      switch byte {
      case 48...57: digit = byte - 48
      case 65...70: digit = byte - 55
      case 97...102: digit = byte - 87
      default: throw WebKitPasswordFailure.arguments
      }
      if let first = high { var value = first * 16 + digit; secret.bytes.append(&value, length: 1); high = nil }
      else { high = digit }
    }
    guard String(data: secret.bytes as Data, encoding: .utf8) != nil else { throw WebKitPasswordFailure.arguments }
    return secret
  }

  func wipe() { WebKitWipePasswordBuffer(bytes) }
  deinit { wipe() }
}

enum WebKitPasswordFailure: Error { case storage, key, arguments, missing, duplicate, authentication }

final class WebKitPasswordVault {
  struct Login {
    let origin: String
    let username: String
    let encrypted: Data
    let created: Double
    let modified: Double
    let lastUsed: Double
    var metadata: [String: Any] { ["origin": origin, "username": username, "created": created, "modified": modified] }
  }

  private let directory: URL
  private let keyStore: any SyncKeyStore
  let account: String
  private let profile: String
  private var database: OpaquePointer?
  private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  init(directory: URL, profile: String, keyStore: any SyncKeyStore) throws {
    guard !profile.hasPrefix("incognito") else { throw WebKitPasswordFailure.arguments }
    self.directory = directory.resolvingSymlinksInPath()
    self.profile = profile
    self.keyStore = keyStore
    account = "webkit-passwords-" + Self.hash(self.directory.path)
    let stores = directory.appendingPathComponent("Stores", isDirectory: true)
    try FileManager.default.createDirectory(at: stores, withIntermediateDirectories: true)
    let file = stores.appendingPathComponent(profile.isEmpty ? "default.sqlite3" : Self.hash(profile) + ".sqlite3")
    guard sqlite3_open(file.path, &database) == SQLITE_OK else { throw WebKitPasswordFailure.storage }
    sqlite3_busy_timeout(database, 3000)
    try execute("PRAGMA journal_mode=WAL")
    try execute("CREATE TABLE IF NOT EXISTS passwords(origin TEXT NOT NULL,username TEXT NOT NULL,encrypted BLOB NOT NULL,created REAL NOT NULL,modified REAL NOT NULL,last_used REAL NOT NULL,PRIMARY KEY(origin,username))")
    try execute("CREATE TABLE IF NOT EXISTS password_exceptions(origin TEXT PRIMARY KEY)")
  }

  deinit { sqlite3_close(database) }
  private static func hash(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }

  private func statement(_ sql: String, _ arguments: [Any] = []) throws -> OpaquePointer {
    var prepared: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &prepared, nil) == SQLITE_OK, let prepared else { throw WebKitPasswordFailure.storage }
    for (offset, argument) in arguments.enumerated() {
      let index = Int32(offset + 1)
      let status: Int32
      if let text = argument as? String { status = sqlite3_bind_text(prepared, index, text, -1, transient) }
      else if let data = argument as? Data { status = data.withUnsafeBytes { sqlite3_bind_blob(prepared, index, $0.baseAddress, Int32($0.count), transient) } }
      else if let number = argument as? Double { status = sqlite3_bind_double(prepared, index, number) }
      else if let number = argument as? Int { status = sqlite3_bind_int64(prepared, index, Int64(number)) }
      else { sqlite3_finalize(prepared); throw WebKitPasswordFailure.arguments }
      if status != SQLITE_OK { sqlite3_finalize(prepared); throw WebKitPasswordFailure.storage }
    }
    return prepared
  }

  private func execute(_ sql: String, _ arguments: [Any] = []) throws {
    let prepared = try statement(sql, arguments)
    defer { sqlite3_finalize(prepared) }
    let status = sqlite3_step(prepared)
    guard status == SQLITE_DONE || status == SQLITE_ROW else { throw WebKitPasswordFailure.storage }
  }

  func logins(origin: String? = nil) throws -> [Login] {
    let prepared = try statement("SELECT origin,username,encrypted,created,modified,last_used FROM passwords" + (origin == nil ? "" : " WHERE origin=?") + " ORDER BY origin,username", origin.map { [$0] } ?? [])
    defer { sqlite3_finalize(prepared) }
    var result: [Login] = []
    while true {
      let status = sqlite3_step(prepared)
      if status == SQLITE_DONE { return result }
      guard status == SQLITE_ROW, let bytes = sqlite3_column_blob(prepared, 2) else { throw WebKitPasswordFailure.storage }
      result.append(Login(origin: String(cString: sqlite3_column_text(prepared, 0)), username: String(cString: sqlite3_column_text(prepared, 1)),
        encrypted: Data(bytes: bytes, count: Int(sqlite3_column_bytes(prepared, 2))), created: sqlite3_column_double(prepared, 3),
        modified: sqlite3_column_double(prepared, 4), lastUsed: sqlite3_column_double(prepared, 5)))
    }
  }

  private func key() throws -> SymmetricKey {
    let descriptor = Darwin.open(directory.appendingPathComponent("password-key.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard descriptor >= 0 else { throw WebKitPasswordFailure.key }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw WebKitPasswordFailure.key }
    defer { flock(descriptor, LOCK_UN) }
    let marker = directory.appendingPathComponent("password-key-created")
    if let data = keyStore.load(account: account) {
      guard data.count == 32 else { throw WebKitPasswordFailure.key }
      if !FileManager.default.fileExists(atPath: marker.path) { try Data().write(to: marker, options: .atomic) }
      return SymmetricKey(data: data)
    }
    guard !FileManager.default.fileExists(atPath: marker.path), try logins().isEmpty else { throw WebKitPasswordFailure.key }
    let key = SymmetricKey(size: .bits256)
    guard keyStore.save(key.withUnsafeBytes { Data($0) }, account: account) else { throw WebKitPasswordFailure.key }
    try Data().write(to: marker, options: .atomic)
    return key
  }

  private func authenticatedData(_ origin: String, _ username: String) throws -> Data {
    try JSONSerialization.data(withJSONObject: [profile, origin, username])
  }

  func open(_ login: Login) throws -> WebKitPasswordSecret {
    WebKitPasswordSecret(try AES.GCM.open(AES.GCM.SealedBox(combined: login.encrypted), using: key(), authenticating: authenticatedData(login.origin, login.username)))
  }

  func save(origin rawOrigin: String, username: String, password: WebKitPasswordSecret, replacing: String? = nil) throws {
    guard let origin = WebKitPasswordOrigin.of(rawOrigin), password.bytes.length > 0, password.bytes.length <= 65536, username.utf8.count <= 4096, !username.contains("\0") else { throw WebKitPasswordFailure.arguments }
    let previous = try logins(origin: origin).first { $0.username == (replacing ?? username) }
    if replacing != nil && previous == nil { throw WebKitPasswordFailure.missing }
    if replacing == nil, let previous {
      let old = try open(previous)
      defer { old.wipe() }
      guard old.bytes.isEqual(to: password.bytes as Data) else { throw WebKitPasswordFailure.duplicate }
      return
    }
    let sealed = try AES.GCM.seal(password.bytes as Data, using: key(), authenticating: authenticatedData(origin, username))
    guard let combined = sealed.combined else { throw WebKitPasswordFailure.storage }
    let now = Date().timeIntervalSince1970 * 1000
    try execute("BEGIN IMMEDIATE")
    do {
      if let replacing { try execute("DELETE FROM passwords WHERE origin=? AND username=?", [origin, replacing]) }
      try execute("INSERT INTO passwords VALUES(?,?,?,?,?,?)", [origin, username, combined, previous?.created ?? now, now, previous?.lastUsed ?? 0])
      try execute("COMMIT")
    } catch { try? execute("ROLLBACK"); throw error }
  }

  func remove(origin: String, username: String) throws {
    guard let origin = WebKitPasswordOrigin.of(origin) else { throw WebKitPasswordFailure.arguments }
    try execute("DELETE FROM passwords WHERE origin=? AND username=?", [origin, username])
  }

  func used(_ login: Login) throws { try execute("UPDATE passwords SET last_used=? WHERE origin=? AND username=?", [Date().timeIntervalSince1970 * 1000, login.origin, login.username]) }

  func exceptions() throws -> [String] {
    let prepared = try statement("SELECT origin FROM password_exceptions ORDER BY origin")
    defer { sqlite3_finalize(prepared) }
    var result: [String] = []
    while true {
      let status = sqlite3_step(prepared)
      if status == SQLITE_DONE { return result }
      guard status == SQLITE_ROW else { throw WebKitPasswordFailure.storage }
      result.append(String(cString: sqlite3_column_text(prepared, 0)))
    }
  }

  func setNever(_ origin: String, never: Bool) throws {
    guard let origin = WebKitPasswordOrigin.of(origin) else { throw WebKitPasswordFailure.arguments }
    try execute(never ? "INSERT OR IGNORE INTO password_exceptions VALUES(?)" : "DELETE FROM password_exceptions WHERE origin=?", [origin])
  }

  func export(to path: String) throws {
    guard (path as NSString).isAbsolutePath else { throw WebKitPasswordFailure.arguments }
    let output = NSMutableData(data: Data("name,url,username,password\r\n".utf8))
    defer { WebKitWipePasswordBuffer(output) }
    func cell(_ text: String) -> String { "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    for login in try logins() {
      let password = try open(login)
      defer { password.wipe() }
      let line = [URL(string: login.origin)?.host ?? "", login.origin, login.username, password.text].map(cell).joined(separator: ",") + "\r\n"
      output.append(Data(line.utf8))
    }
    let staging = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(".ardia-passwords-\(UUID().uuidString)").path
    let descriptor = Darwin.open(staging, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard descriptor >= 0 else { throw WebKitPasswordFailure.storage }
    defer { close(descriptor); unlink(staging) }
    guard fchmod(descriptor, 0o600) == 0 else { throw WebKitPasswordFailure.storage }
    var offset = 0
    while offset < output.length {
      let count = write(descriptor, output.bytes + offset, output.length - offset)
      if count < 0 && errno == EINTR { continue }
      guard count > 0 else { throw WebKitPasswordFailure.storage }
      offset += count
    }
    guard fsync(descriptor) == 0, rename(staging, path) == 0 else { throw WebKitPasswordFailure.storage }
  }
}
