import AppKit
import WebKit

@available(macOS 15.4, *)
extension WebKitExtensions {
  func actionStates(_ tab: WebKitTab, ids: [String]) -> [String: Any] {
    opened(tab)
    guard let view = tab.webView, let adapter = tabs[ObjectIdentifier(view)] else { return [:] }
    var states: [String: Any] = [:]
    for id in ids {
      guard let context = contexts[id], let action = context.action(for: adapter) else { continue }
      states[id] = ["badgeText": action.badgeText, "badgeColor": NSNull(), "badgeTextColor": NSNull(), "title": action.label, "popup": action.presentsPopup ? context.baseURL.appendingPathComponent((records[id] as? [String: Any])?["popup"] as? String ?? "").absoluteString : "", "enabled": action.isEnabled, "icon": action.icon(for: CGSize(width: 32, height: 32))?.pngDataURL(points: 32, scale: 2) ?? ""]
    }
    return states
  }
  func execute(_ tab: WebKitTab, id: String) -> String? {
    opened(tab)
    guard let context = contexts[id], let view = tab.webView, let adapter = tabs[ObjectIdentifier(view)], let action = context.action(for: adapter) else { return nil }
    if action.presentsPopup { return "popup" }
    context.performAction(for: adapter)
    return nil
  }
  func popup(for url: URL) -> WKWebExtension.Action? {
    guard let context = controller.extensionContext(for: url) else { return nil }
    let tab = liveTabs.first { $0.owner?.visible == true }
    return context.action(for: tab)
  }
}

extension WebKitTab {
  func closeExtensionPopup() {
    extensionPopupObservation = nil
    extensionPopupClose?()
    extensionPopupClose = nil
    extensionPopup?.removeFromSuperview()
    extensionPopup = nil
  }

  func executeJavaScript(_ code: String) {
    (extensionPopup ?? webView)?.evaluateJavaScript(code, in: nil, in: .page) { _ in }
  }

  func evaluate(_ code: String, completion: @escaping (String?) -> Void) {
    guard let view = extensionPopup ?? webView else { return completion(nil) }
    let body = "return await new Promise((resolve) => { const post = (kind, json) => { if (kind === \"result\") resolve(json); }; setTimeout(() => resolve(null), 3000); try {\n\(code)\n} catch (e) { resolve(null); } });"
    view.callAsyncJavaScript(body, arguments: [:], in: nil, in: WebKitHub.world) { result in
      if case .success(let value) = result { completion(value as? String) } else { completion(nil) }
    }
  }


  func startExtensionPopup() -> Bool {
    guard #available(macOS 15.4, *), extensionHost == "popup", let url = initialURL.flatMap(URL.init(string:)),
      let action = WebKitExtensions.shared(profile).popup(for: url), let popup = action.popupWebView else { return false }
    extensionPopup = popup
    extensionPopupClose = { action.closePopup() }
    popup.frame = bounds
    popup.autoresizingMask = [.width, .height]
    addSubview(popup)
    emit("ready")
    extensionPopupObservation = popup.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
      guard let self, self.extensionPopup === view else { return }
      if view.isLoading { return self.emit("navigation", ["isLoading": true, "url": url.absoluteString, "title": ""]) }
      view.evaluateJavaScript("({ready:document.readyState,width:document.documentElement.scrollWidth,height:document.documentElement.scrollHeight})") { [weak self, weak view] value, _ in
        guard let self, let view, self.extensionPopup === view, let size = value as? [String: Any], size["ready"] as? String == "complete" else { return }
        self.emit("preferredSize", ["width": size["width"] ?? 25, "height": size["height"] ?? 25])
        self.emit("navigation", ["isLoading": false, "url": url.absoluteString, "title": ""])
      }
    }
    return true
  }
}
