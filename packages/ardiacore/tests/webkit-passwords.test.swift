import AppKit
import CryptoKit
import WebKit

final class PasswordFrameChecks: NSObject, WKScriptMessageHandler {
  var messages: [WKScriptMessage] = []
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { messages.append(message) }
}

@main struct PasswordChecks {
  static func main() throws {
    setbuf(stdout, nil)
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    let keys = FileKeyStore(directory: root)
    let directory = root.appendingPathComponent("WebKit")
    var vault = try WebKitPasswordVault(directory: directory, profile: "", keyStore: keys)
    let origin = "https://login.example"
    let password = WebKitPasswordSecret("fixture-native-secret")
    defer { password.wipe() }
    try vault.save(origin: origin + "/login", username: "fixture", password: password)
    let login = try vault.logins()[0]
    let opened = try vault.open(login)
    assert(opened.bytes.isEqual(to: password.bytes as Data))
    opened.wipe()
    assert((opened.bytes as Data).allSatisfy { $0 == 0 })
    assert(login.created > 0 && login.modified > 0 && login.lastUsed == 0)
    try vault.used(login)
    assert(try! vault.logins()[0].lastUsed > 0)
    assert(!login.encrypted.contains(Data(password.text.utf8)))
    let lock = Darwin.open(directory.appendingPathComponent("password-key.lock").path, O_RDWR)
    assert(lock >= 0 && flock(lock, LOCK_EX | LOCK_NB) == 0)
    assert((try? vault.open(login)) == nil)
    flock(lock, LOCK_UN)
    close(lock)
    assert((try? vault.save(origin: origin, username: "bad\0username", password: password)) == nil)
    let storedKey = keys.load(account: vault.account)!
    assert(storedKey.count == 32)
    assert((try! FileManager.default.attributesOfItem(atPath: keys.url(vault.account).path)[.posixPermissions] as! NSNumber).intValue == 0o600)
    vault = try WebKitPasswordVault(directory: directory, profile: "", keyStore: keys)
    assert(try! vault.open(vault.logins()[0]).text == password.text)
    assert(keys.load(account: vault.account) == storedKey)
    let other = try WebKitPasswordVault(directory: directory, profile: "other", keyStore: keys)
    assert(try! other.logins().isEmpty)
    try other.save(origin: origin, username: "fixture", password: password)
    assert(keys.load(account: other.account) == storedKey)
    let isolated = try WebKitPasswordVault(directory: root.appendingPathComponent("Other"), profile: "", keyStore: keys)
    try isolated.save(origin: origin, username: "fixture", password: password)
    assert(keys.load(account: isolated.account) != storedKey)
    var tampered = login.encrypted
    tampered[tampered.count - 1] ^= 1
    let forged = WebKitPasswordVault.Login(origin: login.origin, username: login.username, encrypted: tampered, created: 0, modified: 0, lastUsed: 0)
    assert((try? vault.open(forged)) == nil)
    let relocated = WebKitPasswordVault.Login(origin: "https://other.example", username: login.username, encrypted: login.encrypted, created: 0, modified: 0, lastUsed: 0)
    assert((try? vault.open(relocated)) == nil)
    assert((try? other.open(login)) == nil)
    let replacement = WebKitPasswordSecret("fixture-updated-secret")
    defer { replacement.wipe() }
    assert((try? vault.save(origin: origin, username: "fixture", password: replacement)) == nil)
    try vault.save(origin: origin, username: "renamed", password: replacement, replacing: "fixture")
    assert(try! vault.logins()[0].username == "renamed")
    assert(try! vault.logins()[0].created == login.created)
    try vault.setNever(origin, never: true)
    assert(try! vault.exceptions() == [origin])
    try vault.setNever(origin, never: false)
    assert(try! vault.exceptions().isEmpty)
    let csv = root.appendingPathComponent("passwords.csv")
    try vault.export(to: csv.path)
    assert((try! String(contentsOf: csv, encoding: .utf8)).hasPrefix("name,url,username,password\r\n"))
    assert((try! FileManager.default.attributesOfItem(atPath: csv.path)[.posixPermissions] as! NSNumber).intValue == 0o600)
    let sentinel = root.appendingPathComponent("sentinel")
    try Data("untouched".utf8).write(to: sentinel)
    try FileManager.default.removeItem(at: csv)
    try FileManager.default.createSymbolicLink(at: csv, withDestinationURL: sentinel)
    try vault.export(to: csv.path)
    assert(try! String(contentsOf: sentinel, encoding: .utf8) == "untouched")
    try vault.remove(origin: origin, username: "renamed")
    assert(try! vault.logins().isEmpty)
    keys.delete(account: other.account)
    assert((try? other.open(other.logins()[0])) == nil)
    assert((try? WebKitPasswordVault(directory: directory, profile: "incognito:test", keyStore: keys)) == nil)
    let canonical: (String) -> String? = WebKitPasswordOrigin.of
    assert(canonical("HTTPS://LOGIN.EXAMPLE:443/path") == origin)
    assert(canonical("http://login.example:80/path") == "http://login.example")
    for text in ["http://login.example", "https://login.example:444", "https://sub.login.example", "https://other.example"] { assert(canonical(text) != origin) }
    for text in ["file:///login", "data:text/html,login", "https://login.example:0"] { assert(canonical(text) == nil) }
    assert(canonical("http://[::1]:1234/path") == "http://[::1]:1234")
    assert(try! WebKitPasswordSecret.decode("6f6b").text == "ok")
    for hex in ["0", "gg", "ff", String(repeating: "a", count: 131074)] { assert((try? WebKitPasswordSecret.decode(hex)) == nil) }
    try forms()
    print("PASS WebKit passwords: AES-GCM round trip/tamper/AAD, key isolation/reuse/loss, metadata, duplicate/update/remove, exceptions, CSV mode/symlink, exact origins, five form fixtures")
  }

  static func forms() throws {
    NSApplication.shared.setActivationPolicy(.prohibited)
    let world = WKContentWorld.world(name: "password-native-test")
    let handler = PasswordFrameChecks()
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.userContentController.addUserScript(WKUserScript(source: WebKitPasswordScript.source, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: world))
    configuration.userContentController.add(handler, contentWorld: world, name: "ardiaPasswords")
    let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
    func evaluate(_ code: String, frame: WKFrameInfo? = nil, contentWorld: WKContentWorld? = nil) -> Any? {
      var done = false
      var answer: Any?
      view.evaluateJavaScript(code, in: frame, in: contentWorld ?? world) { result in
        if case .success(let value) = result { answer = value }
        done = true
      }
      let end = Date().addingTimeInterval(10)
      while !done && Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
      assert(done)
      return answer
    }
    let plain = "<form><input autocomplete='username'><input type='password'></form>"
    for (html, expected) in [(plain, true), ("<form><input type='password'></form>", true), ("<form><input type='password'><input type='password'></form>", false), ("<iframe srcdoc=\"\(plain)\"></iframe>", false), ("<script>addEventListener('load',()=>document.body.innerHTML=\"\(plain)\")</script>", true)] {
      handler.messages = []
      view.loadHTMLString("<body>\(html)</body>", baseURL: URL(string: "https://fixture.example"))
      let end = Date().addingTimeInterval(10)
      repeat { RunLoop.current.run(until: Date().addingTimeInterval(0.03)) } while view.isLoading && Date() < end
      assert(!view.isLoading)
      assert((evaluate("window.__ardiaPasswords.inspect() !== null") as? Bool) == expected)
      assert((evaluate("typeof window.webkit?.messageHandlers?.ardiaPasswords", contentWorld: .page) as? String) == "undefined")
      if html.hasPrefix("<iframe") {
        let frame = handler.messages.first { !$0.frameInfo.isMainFrame }!.frameInfo
        assert((evaluate("window.__ardiaPasswords.inspect() !== null", frame: frame) as? Bool) == true)
      }
    }
    for style in ["display:none", "visibility:hidden", "opacity:0", "width:0;height:0;padding:0;border:0", "position:absolute;top:-1000px"] {
      _ = evaluate("document.body.innerHTML = `<form><input><input type='password' style='\(style)'></form>`; true")
      assert((evaluate("window.__ardiaPasswords.inspect() === null") as? Bool) == true)
    }
    view.stopLoading()
  }
}
