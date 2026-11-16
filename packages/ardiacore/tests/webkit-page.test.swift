import AppKit
import WebKit

final class ArdiaHost {
  static var dataDirectory = ""
  static func isPrivateProfile(_ profile: String) -> Bool { profile.hasPrefix("incognito") }
  static func baseProfile(of profile: String) -> String { profile.split(separator: "@", omittingEmptySubsequences: false).dropFirst().joined(separator: "@") }
}
final class LaunchConfig {
  static let shared = LaunchConfig()
  var dataDirectory: String? { ArdiaHost.dataDirectory }
}

@main struct PageChecks {
  static func main() throws {
    ArdiaHost.dataDirectory = CommandLine.arguments[1]
    let preferences = WKPreferences()
    assert(preferences.responds(to: NSSelectorFromString("_setDeveloperExtrasEnabled:")))
    preferences.setValue(true, forKey: "developerExtrasEnabled")
    assert(preferences.value(forKey: "developerExtrasEnabled") as? Bool == true)
    var deadline = 12.0
    assert(WebKitPagePolicy.consumeContextPopup(deadline: &deadline, now: 11))
    assert(!WebKitPagePolicy.consumeContextPopup(deadline: &deadline, now: 11))
    deadline = 12
    assert(!WebKitPagePolicy.consumeContextPopup(deadline: &deadline, now: 13))
    let url = URL(string: "http://127.0.0.1:12345/refused")!
    for code in [NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNotConnectedToInternet] {
      let html = WebKitPagePolicy.errorPage(url, NSError(domain: NSURLErrorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: "<script>&bad</script>"]))
      assert(html.contains("&lt;script&gt;&amp;bad&lt;/script&gt;"))
      assert(!html.contains("<script>"))
      assert(html.contains("href=\"ardia-retry:\""))
      assert(html.contains("127.0.0.1"))
    }
    let legacy = URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("popup-grants.json")
    try JSONEncoder().encode(["legacy": Set(["https://legacy.example"])]).write(to: legacy)
    let stores = WebKitStores()
    assert(stores.allowsPopups(profile: "legacy", origin: "https://legacy.example"))
    assert(!FileManager.default.fileExists(atPath: legacy.path))
    stores.setSetting(profile: "legacy", origin: "https://legacy.example", kind: "popups", value: "default")
    assert(!WebKitStores().allowsPopups(profile: "legacy", origin: "https://legacy.example"))
    let origin = "http://127.0.0.1:12345"
    assert(!stores.allowsPopups(profile: "", origin: origin))
    stores.allowPopups(profile: "", origin: origin)
    assert(WebKitStores().allowsPopups(profile: "", origin: origin))
    assert(!stores.allowsPopups(profile: "other", origin: origin))
    assert(!stores.allowsPopups(profile: "", origin: "http://127.0.0.1:54321"))
    let directory = URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("Stores")
    let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    stores.allowPopups(profile: "incognito:test", origin: origin)
    let afterPrivate = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    assert(afterPrivate == files)
    assert(stores.allowsPopups(profile: "incognito:test", origin: origin))
    assert(stores.endPrivateSession("") != nil)
    assert(!stores.allowsPopups(profile: "incognito:test", origin: origin))
    print("PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants")
  }
}
