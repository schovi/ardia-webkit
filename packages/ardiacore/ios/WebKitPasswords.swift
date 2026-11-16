import AppKit
import LocalAuthentication

final class WebKitPasswords {
  static let shared = WebKitPasswords()

  func vault(_ profile: String) throws -> WebKitPasswordVault {
    let config = LaunchConfig.shared
    let directory = URL(fileURLWithPath: ArdiaHost.dataDirectory)
    let store: any SyncKeyStore
    if let scratch = config.dataDirectory { store = FileKeyStore(directory: URL(fileURLWithPath: scratch)) }
    else {
      guard !config.background && !config.testInstance else { throw WebKitPasswordFailure.key }
      store = KeychainKeyStore(service: "Ardia WebKit Passwords")
    }
    return try WebKitPasswordVault(directory: directory, profile: ArdiaHost.baseProfile(of: profile), keyStore: store)
  }

  func offered(_ profile: String) -> Bool {
    WebKitProfileSettings(ArdiaHost.baseProfile(of: profile), "passwords")["offered"] as? Bool ?? true
  }

  func unlock(_ reply: @escaping (Bool) -> Void) {
    let config = LaunchConfig.shared
    if config.background || config.isolated || config.testInstance { return reply(config.testValue("reauth") == "granted") }
    let context = LAContext()
    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return reply(false) }
    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock saved passwords") { success, _ in
      DispatchQueue.main.async { reply(success) }
    }
  }

  func call(_ name: String, profile: String, args: [String: Any], reply: @escaping ([String: Any]) -> Void) {
    let privateProfile = WebKitStores.isPrivate(profile)
    let writes = ["ac_passwords_add", "ac_passwords_update", "ac_passwords_remove", "ac_passwords_allow", "ac_passwords_never"]
    if privateProfile && writes.contains(name) { return reply(["error": "private profile"]) }
    if ["ac_passwords_unlock", "ac_passwords_reveal", "ac_passwords_update", "ac_passwords_export"].contains(name) {
      return unlock { success in
        guard success else {
          if name == "ac_passwords_unlock" { return reply(["unlocked": false]) }
          if name == "ac_passwords_reveal" { return reply(["password": NSNull()]) }
          if name == "ac_passwords_export" { return reply(["status": "reauthFailed"]) }
          return reply(["error": "Not authenticated"])
        }
        self.perform(name, profile: profile, args: args, reply: reply)
      }
    }
    perform(name, profile: profile, args: args, reply: reply)
  }

  private func perform(_ name: String, profile: String, args: [String: Any], reply: ([String: Any]) -> Void) {
    do {
      if name == "ac_passwords_unlock" { return reply(["unlocked": true]) }
      let vault = try vault(profile)
      let origin = args["origin"] as? String ?? ""
      let username = args["username"] as? String ?? ""
      switch name {
      case "ac_passwords_list": reply(["passwords": try vault.logins().map(\.metadata)])
      case "ac_passwords_exceptions": reply(["origins": try vault.exceptions()])
      case "ac_passwords_allow", "ac_passwords_never":
        try vault.setNever(origin, never: name == "ac_passwords_never")
        reply(["ok": true])
      case "ac_passwords_add", "ac_passwords_update":
        let update = name == "ac_passwords_update"
        let password: WebKitPasswordSecret
        if let value = args[update ? "newPassword" : "password"] as? String { password = WebKitPasswordSecret(value) }
        else if let hex = args[update ? "newPasswordHex" : "passwordHex"] as? String { password = try WebKitPasswordSecret.decode(hex) }
        else if update, let login = try vault.logins(origin: WebKitPasswordOrigin.of(origin)).first(where: { $0.username == username }) { password = try vault.open(login) }
        else { throw WebKitPasswordFailure.arguments }
        defer { password.wipe() }
        try vault.save(origin: origin, username: args["newUsername"] as? String ?? username, password: password, replacing: update ? username : nil)
        reply(["ok": true])
      case "ac_passwords_reveal":
        guard let origin = WebKitPasswordOrigin.of(origin), let login = try vault.logins(origin: origin).first(where: { $0.username == username }) else { throw WebKitPasswordFailure.missing }
        let password = try vault.open(login)
        defer { password.wipe() }
        reply(["password": password.text])
      case "ac_passwords_remove": try vault.remove(origin: origin, username: username); reply(["ok": true])
      case "ac_passwords_export":
        guard let path = args["path"] as? String else { return reply(["status": "cancelled"]) }
        do { try vault.export(to: path); reply(["status": "succeeded", "path": path]) }
        catch { reply(["status": "writeFailed"]) }
      default: reply(["error": "unsupported password call"])
      }
    } catch { reply(["error": "Password operation failed"]) }
  }
}

@_cdecl("ArdiaWebKitPasswordsCall")
func ArdiaWebKitPasswordsCall(_ name: NSString, _ profile: NSString, _ args: NSDictionary, _ reply: @escaping @convention(block) (NSDictionary) -> Void) {
  let run = { WebKitPasswords.shared.call(name as String, profile: profile as String, args: args as? [String: Any] ?? [:]) { reply($0 as NSDictionary) } }
  if Thread.isMainThread { run() } else { DispatchQueue.main.async(execute: run) }
}
