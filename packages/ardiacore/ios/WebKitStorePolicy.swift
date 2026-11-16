import Foundation

struct WebKitStorePolicy {
  static func identifier(_ url: URL?) -> String? {
    guard let url, url.scheme == "https", url.host == "chromewebstore.google.com", url.port == nil || url.port == 443,
      url.user == nil, url.password == nil else { return nil }
    let parts = url.path.split(separator: "/")
    guard (parts.count == 2 || parts.count == 3), parts[0] == "detail", let id = parts.last,
      id.range(of: "^[a-p]{32}$", options: .regularExpression) != nil else { return nil }
    return String(id)
  }
  static func allows(main: Bool, scheme: String, host: String, port: Int) -> Bool {
    main && scheme == "https" && host == "chromewebstore.google.com" && (port == 0 || port == 443)
  }
}
