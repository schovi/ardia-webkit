import AppKit
import WebKit

@available(macOS 15.4, *)
final class WebKitExtensionGate: NSObject, WKWebExtensionTab, WKWebExtensionWindow {
  static let shared = WebKitExtensionGate()
  let controller: WKWebExtensionController = {
    let config = WKWebExtensionController.Configuration.nonPersistent()
    config.defaultWebsiteDataStore = .nonPersistent()
    return WKWebExtensionController(configuration: config)
  }()
  var context: WKWebExtensionContext?
  var page: WKWebView?
  var popup: WKWebView?
  var host: NSView?

  func prepare(path: String, tab: WebKitTab, url: URL) async throws -> [String: Any] {
    let extensionObject = try await WKWebExtension(resourceBaseURL: URL(fileURLWithPath: path, isDirectory: true))
    let context = WKWebExtensionContext(for: extensionObject)
    self.context = context
    try controller.load(context)
    let config = WebKitHub.shared.configuration(profile: tab.profile)
    config.webExtensionController = controller
    let page = WKWebView(frame: tab.bounds, configuration: config)
    self.page = page
    host = tab
    tab.addSubview(page)
    controller.didOpenWindow(self)
    controller.didOpenTab(self)
    page.load(URLRequest(url: url))
    let permissions = extensionObject.allRequestedMatchPatterns.map(\.string) + extensionObject.requestedPermissions.map(\.rawValue)
    let prompt: [String: Any] = ["requestId": "webkit-gate", "profile": tab.profile, "id": "webkit-gate", "name": extensionObject.displayName ?? "Gate", "version": "1.0", "type": "install", "icon": "", "permissions": permissions, "tabId": tab.transferKey ?? NSNull() as Any]
    ArdiaEvents.emit("extensions.installPrompt", data: prompt)
    NSLog("[webkit] extension gate install prompt %@ (background mode, not shown)", permissions)
    return ["loaded": context.isLoaded, "permissions": extensionObject.allRequestedMatchPatterns.map(\.string), "errors": context.errors.map(\.localizedDescription)]
  }

  func accept(_ accepted: Bool) {
    guard accepted, let context else { return }
    for pattern in context.webExtension.allRequestedMatchPatterns { context.setPermissionStatus(.grantedExplicitly, for: pattern) }
    for permission in context.webExtension.requestedPermissions { context.setPermissionStatus(.grantedExplicitly, for: permission) }
    page?.reload()
  }

  func probe(_ reply: @escaping ([String: Any]) -> Void) {
    guard let context, let page else { return reply(["error": "Gate not prepared"]) }
    let action = context.action(for: self)
    if popup == nil, let view = action?.popupWebView, let host {
      popup = view
      view.frame = NSRect(x: 0, y: 0, width: 320, height: 200)
      host.addSubview(view)
    }
    page.evaluateJavaScript("JSON.stringify({...document.documentElement.dataset})") { value, error in
      let content = value as? String ?? ""
      guard let popup = self.popup else { return reply(["content": content, "popup": "", "attached": false, "errors": context.errors.map(\.localizedDescription)]) }
      popup.evaluateJavaScript("document.querySelector('#gate')?.textContent") { value, error in
        reply(["content": content, "popup": value as? String ?? "", "attached": popup.superview === self.host, "errors": context.errors.map(\.localizedDescription)])
      }
    }
  }

  func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] { [self] }
  func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? { self }
  func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? { self }
  func webView(for context: WKWebExtensionContext) -> WKWebView? { page }
  func url(for context: WKWebExtensionContext) -> URL? { page?.url }
  func title(for context: WKWebExtensionContext) -> String? { page?.title }
}
