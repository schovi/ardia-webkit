import AppKit
import WebKit

extension WebKitTab: PageTab {
  static let unsupported = "unsupported"

  var temporary: Bool { get { false } set {} }
  var temporarySource: String? { get { nil } set {} }
  var warm: Bool { get { false } set {} }
  var neighbour: Bool { get { false } set {} }
  var shownURL: String? { get { nil } set {} }
  var frozen: Bool { get { false } set {} }
  var mediaCaptureSourceId: String? { nil }

  func startPage() { start() }

  func closePage() {
    if Thread.isMainThread { return close() }
    DispatchQueue.main.async { self.close() }
  }

  func navigationEntries(_ completion: @escaping ([[String: Any]]) -> Void) { completion(navigationEntries()) }

  func securityInfo(_ completion: @escaping ([String: Any]) -> Void) { completion(securityInfo()) }

  func showDevTools(panel: String?) {
    guard let view = webView, view.responds(to: NSSelectorFromString("_inspector")),
      let inspector = view.value(forKey: "_inspector") as? NSObject else { return }
    let preferences = view.configuration.preferences
    guard preferences.responds(to: NSSelectorFromString("_setDeveloperExtrasEnabled:")) else { return }
    preferences.setValue(true, forKey: "developerExtrasEnabled")
    guard preferences.value(forKey: "developerExtrasEnabled") as? Bool == true else { return }
    let selector = NSSelectorFromString(panel == "console" ? "showConsole" : "show")
    guard inspector.responds(to: selector) else { return }
    if LaunchConfig.shared.background {
      NSLog("[webkit] inspector %@ (background mode, not shown)", panel ?? "default")
      return
    }
    inspector.perform(selector)
    let inspect = NSSelectorFromString("toggleElementSelection")
    if panel == "inspect", inspector.responds(to: inspect) { inspector.perform(inspect) }
  }

  func downloadImage(_ url: String, maxPixels: Int, completion: @escaping ([String: Any]?) -> Void) {
    downloadFavicon(url, completion: completion)
  }

  func requestPictureInPicture(clickAt: Double, control: Int, _ completion: @escaping (Bool) -> Void) {
    setPictureInPicture(true) { completion($0 == .opened) }
  }

  func takeControlPress(clickAt: Double, control: Int) -> Bool { true }

  func exitPictureInPicture() { setPictureInPicture(false) { _ in } }

  func pageCookies(_ urls: [String], completion: @escaping ([[String: Any]]?) -> Void) { completion([]) }

  func openBlockedPopup(_ popupId: String, always: Bool) {
    guard let popup = blockedPopups.removeValue(forKey: popupId), let url = popup.request.url else { return }
    if always { WebKitHub.shared.stores.allowPopups(profile: profile, origin: popup.origin) }
    emit("openWindow", ["url": url.absoluteString, "disposition": "foreground", "userGesture": true])
  }

  func updatePageColors() {
    let color = contentsBackgroundColor ?? pageBackgroundColor ?? .textBackgroundColor
    wantsLayer = true
    layer?.backgroundColor = color.cgColor
    webView?.underPageBackgroundColor = color
  }

  func updateErrorColor() {
    guard webView?.title == "Can't Open This Page" else { return }
    let color = pageColor ?? ""
    webView?.evaluateJavaScript("window.ardiaPageColor = \(Self.jsString(color)); window.dispatchEvent(new Event('ardiapagecolor'))") { _, _ in }
  }

  func resolvePasswordPrompt(_ action: String, username: String?, password: String?) {
    resolveWebKitPasswordPrompt(action, username: username, password: password)
  }

  func resolveAutofillPrompt(_ promptId: Int, action: String) {}

  func executeExtensionAction(_ extensionId: String) -> String? {
    guard #available(macOS 15.4, *), !WebKitStores.isPrivate(profile) else { return nil }
    return WebKitExtensions.shared(profile).execute(self, id: extensionId)
  }

  func resolveDisplayMedia(_ requestId: String, sourceId: String?, audio: Bool) {}

  func notificationAction(_ notificationId: String, action: String) {}

  func resolveUnresponsive(terminate: Bool) {}

  func discard(unload: Bool) -> String { Self.unsupported }
}

extension WebKitTab {
  func print() {
    guard let view = webView, let window else { return }
    if LaunchConfig.shared.background { return NSLog("[webkit] print panel (background mode, not shown)") }
    let operation = view.printOperation(with: NSPrintInfo.shared)
    operation.view?.frame = view.bounds
    operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
  }

  func writeGeometryDiagnostic() {
    guard let view = webView else { return }
    var diagnostic: [String: Any] = ["views": WebKitModule.geometry(view), "macOS": ProcessInfo.processInfo.operatingSystemVersionString, "webKit": Bundle(for: WKWebView.self).infoDictionary?["CFBundleVersion"] as? String ?? "unknown", "backingScale": window?.backingScaleFactor ?? 0, "systemReduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "toolbar": toolbarDiagnostics, "windowMoves": view.windowMoves]
    if let inspector = view.value(forKey: "_inspector") as? NSObject, inspector.responds(to: NSSelectorFromString("inspectorWebView")),
      let frontend = inspector.perform(NSSelectorFromString("inspectorWebView"))?.takeUnretainedValue() as? WKWebView {
      diagnostic["inspector"] = WebKitModule.geometry(frontend)
    }
    let directory = URL(fileURLWithPath: ArdiaHost.dataDirectory)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("webkit-geometry.json"), options: .atomic)
    } catch { NSLog("[webkit] geometry diagnostic failed: %@", error.localizedDescription) }
  }

  func loadVersionPage(_ target: URL, in view: WKWebView) -> Bool {
    guard ["ardia", "chrome"].contains(target.scheme ?? ""), target.host == "version" else { return false }
    let info = ArdiaHost.engineInfo
    let version = info["webkitVersion"] as? String ?? "unknown"
    let app = info["appVersion"] as? String ?? "unknown"
    view.loadHTMLString("<title>Ardia WebKit Version</title><h1>Ardia WebKit</h1><p>App \(app)</p><p>WebKit \(version)</p>", baseURL: target)
    return true
  }
}
