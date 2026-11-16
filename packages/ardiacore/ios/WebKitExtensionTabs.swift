import AppKit
import WebKit

@available(macOS 15.4, *)
final class WebKitExtensionWindow: NSObject, WKWebExtensionWindow {
  weak var window: NSWindow?
  weak var manager: WebKitExtensions?
  init(_ window: NSWindow, manager: WebKitExtensions) { self.window = window; self.manager = manager }
  func tabs(for context: WKWebExtensionContext) -> [any WKWebExtensionTab] { manager?.liveTabs.filter { $0.view?.window === window } ?? [] }
  func activeTab(for context: WKWebExtensionContext) -> (any WKWebExtensionTab)? { (tabs(for: context) as? [WebKitExtensionTab])?.first { $0.owner?.visible == true } }
  func isPrivate(for context: WKWebExtensionContext) -> Bool { false }
  func frame(for context: WKWebExtensionContext) -> CGRect { window?.frame ?? .zero }
}

@available(macOS 15.4, *)
final class WebKitExtensionTab: NSObject, WKWebExtensionTab {
  weak var view: WKWebView?
  weak var manager: WebKitExtensions?
  init(_ view: WKWebView, manager: WebKitExtensions) { self.view = view; self.manager = manager }
  var owner: WebKitTab? { view.flatMap { WebKitHub.shared.transfers.owner(of: $0) } }
  func webView(for context: WKWebExtensionContext) -> WKWebView? { view }
  func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? { view?.window.flatMap { manager?.window($0) } }
  func url(for context: WKWebExtensionContext) -> URL? { view?.url }
  func title(for context: WKWebExtensionContext) -> String? { view?.title }
  func isLoadingComplete(for context: WKWebExtensionContext) -> Bool { view?.isLoading == false }
  func isSelected(for context: WKWebExtensionContext) -> Bool { owner?.visible == true }
  func shouldGrantPermissionsOnUserGesture(for context: WKWebExtensionContext) -> Bool { false }
  func loadURL(_ url: URL, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
    guard let owner else { return completionHandler(WebKitExtensions.error("Tab is closed")) }
    owner.loadURL(url.absoluteString, userInitiated: false)
    completionHandler(nil)
  }
  func activate(for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) { owner?.emit("activateRequest", ["reason": "extension"]); completionHandler(nil) }
  func close(for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) { owner?.emit("windowClose"); completionHandler(nil) }
}

@available(macOS 15.4, *)
extension WebKitExtensions {
  var liveTabs: [WebKitExtensionTab] { tabs.values.filter { $0.view != nil } }
  func window(_ window: NSWindow) -> WebKitExtensionWindow {
    let key = ObjectIdentifier(window)
    if let existing = windows[key] { return existing }
    let made = WebKitExtensionWindow(window, manager: self)
    windows[key] = made
    controller.didOpenWindow(made)
    return made
  }
  func opened(_ tab: WebKitTab) {
    guard let view = tab.webView, tab.profile == profile, !WebKitStores.isPrivate(profile) else { return }
    let key = ObjectIdentifier(view)
    guard tabs[key] == nil else { return }
    let made = WebKitExtensionTab(view, manager: self)
    tabs[key] = made
    if let window = view.window { _ = self.window(window) }
    controller.didOpenTab(made)
  }
  func closed(_ view: WKWebView) {
    guard let tab = tabs.removeValue(forKey: ObjectIdentifier(view)) else { return }
    controller.didCloseTab(tab, windowIsClosing: false)
  }
  func updated(_ tab: WebKitTab) {
    opened(tab)
    guard let view = tab.webView, let wrapper = tabs[ObjectIdentifier(view)] else { return }
    controller.didChangeTabProperties([.URL, .title, .loading], for: wrapper)
  }
  func webExtensionController(_ controller: WKWebExtensionController, openWindowsFor context: WKWebExtensionContext) -> [any WKWebExtensionWindow] {
    WebKitHub.shared.transfers.liveTabs.filter { $0.profile == profile }.compactMap(\.window).forEach { _ = window($0) }
    return windows.values.filter { $0.window != nil }
  }
  func webExtensionController(_ controller: WKWebExtensionController, focusedWindowFor context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
    windows.values.first { $0.window?.isKeyWindow == true } ?? windows.values.first { $0.window != nil }
  }
  func webExtensionController(_ controller: WKWebExtensionController, openNewTabUsing configuration: WKWebExtension.TabConfiguration, for context: WKWebExtensionContext, completionHandler: @escaping ((any WKWebExtensionTab)?, Error?) -> Void) {
    let view = WebKitWebView(frame: .zero, configuration: WebKitHub.shared.configuration(profile: profile))
    if let url = configuration.url { view.load(URLRequest(url: url)) }
    let adapter = WebKitExtensionTab(view, manager: self)
    tabs[ObjectIdentifier(view)] = adapter
    let adopt = WebKitHub.shared.transfers.offer(view)
    ArdiaEvents.emit("extensions.tabs", data: ["action": "adopt", "adoptId": adopt, "url": configuration.url?.absoluteString ?? "about:blank", "profile": profile])
    controller.didOpenTab(adapter)
    completionHandler(adapter, nil)
  }
  func webExtensionController(_ controller: WKWebExtensionController, didUpdate action: WKWebExtension.Action, forExtensionContext context: WKWebExtensionContext) { actionChanged(context.uniqueIdentifier) }
  func webExtensionController(_ controller: WKWebExtensionController, presentActionPopup action: WKWebExtension.Action, for context: WKWebExtensionContext, completionHandler: @escaping (Error?) -> Void) {
    ArdiaEvents.emit("extensions.actionPopup", data: ["extensionId": context.uniqueIdentifier, "tabId": (action.associatedTab as? WebKitExtensionTab)?.owner?.transferKey ?? NSNull() as Any])
    completionHandler(nil)
  }
}
