import AppKit
import WebKit

extension WebKitTab {
  func focusPage() {
    guard let view = webView else { return }
    view.focusRequests += 1
    window?.makeFirstResponder(view)
  }

  func observeFullScreen(_ view: WKWebView) -> NSKeyValueObservation {
    view.observe(\.fullscreenState) { [weak self] view, _ in
      let fullScreen = view.fullscreenState != .notInFullscreen
      if let window = self?.window { ArdiaChromeWindowHost.setPageFullScreen(fullScreen, in: window) }
      self?.emit("fullscreen", ["fullscreen": fullScreen])
    }
  }

  @objc(_webViewFullscreenMayReturnToInline:)
  func webViewFullscreenMayReturnToInline(_ webView: WKWebView) {
    guard !closed, webView === self.webView else { return }
    if LaunchConfig.shared.background {
      NSLog("[webkit] back to tab from Picture in Picture (background mode, not activated)")
    } else {
      NSApp.activate()
    }
    emit("activateRequest", ["reason": "pictureInPicture"])
  }

  func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
               type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
    let kinds: [String]
    switch type {
    case .camera: kinds = ["camera"]
    case .microphone: kinds = ["microphone"]
    default: kinds = ["camera", "microphone"]
    }
    let originString = Origins.of(origin)
    WebKitHub.shared.permissions.request(browserId: browserId, tabId: transferKey, profile: profile, origin: originString, kinds: kinds) { [weak webView] allowed in
      if allowed, let view = webView as? WebKitWebView {
        for kind in kinds { view.captureOrigins[kind, default: []].insert(originString) }
      }
      decisionHandler(allowed ? .grant : .deny)
    }
  }

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping () -> Void) {
    guard let window, !LaunchConfig.shared.background else { return completionHandler() }
    let alert = NSAlert()
    alert.messageText = Self.sheetTitle(frame)
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: window) { _ in completionHandler() }
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (Bool) -> Void) {
    guard let window, !LaunchConfig.shared.background else { return completionHandler(false) }
    let alert = NSAlert()
    alert.messageText = Self.sheetTitle(frame)
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
  }

  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
    guard let window, !LaunchConfig.shared.background else { return completionHandler(nil) }
    let alert = NSAlert()
    alert.messageText = Self.sheetTitle(frame)
    alert.informativeText = prompt
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
    field.stringValue = defaultText ?? ""
    alert.accessoryView = field
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
  }

  static func sheetTitle(_ frame: WKFrameInfo) -> String {
    let host = frame.securityOrigin.host
    return host.isEmpty ? "This page says" : "\(host) says"
  }

  func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping ([URL]?) -> Void) {
    guard let window else { return completionHandler(nil) }
    if LaunchConfig.shared.background {
      NSLog("[webkit] file panel (background mode, not shown)")
      return completionHandler(nil)
    }
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection
    panel.canChooseDirectories = parameters.allowsDirectories
    panel.canChooseFiles = true
    panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
  }
}

extension WebKitTab {
  func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
               completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic else {
      return completionHandler(.performDefaultHandling, nil)
    }
    resolveHTTPAuth(username: nil, password: nil)
    authenticationReply = completionHandler
    let alert = NSAlert()
    alert.messageText = "Sign in to \(challenge.protectionSpace.host)"
    alert.informativeText = "\(challenge.protectionSpace.realm ?? "This site") requires a username and password."
    let fields = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 58))
    let username = NSTextField(frame: NSRect(x: 0, y: 32, width: 280, height: 24))
    username.placeholderString = "Username"
    let password = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    password.placeholderString = "Password"
    fields.addSubview(username)
    fields.addSubview(password)
    alert.accessoryView = fields
    alert.addButton(withTitle: "Sign In")
    alert.addButton(withTitle: "Cancel")
    if LaunchConfig.shared.background {
      NSLog("[webkit] HTTP auth prompt: %@ (background mode, not shown)", challenge.protectionSpace.host)
      return
    }
    guard let window else { return resolveHTTPAuth(username: nil, password: nil) }
    authenticationSheet = alert
    alert.beginSheetModal(for: window) { [weak self, weak alert] response in
      guard let self, let alert, self.authenticationSheet === alert else { return }
      self.authenticationSheet = nil
      self.resolveHTTPAuth(username: response == .alertFirstButtonReturn ? username.stringValue : nil, password: password.stringValue)
    }
  }

  func resolveHTTPAuth(username: String?, password: String?) {
    guard let reply = authenticationReply else { return }
    authenticationReply = nil
    if let sheet = authenticationSheet {
      authenticationSheet = nil
      sheet.window.sheetParent?.endSheet(sheet.window)
    }
    if let username {
      reply(.useCredential, URLCredential(user: username, password: password ?? "", persistence: .none))
    } else {
      reply(.useCredential, nil)
    }
  }
}

extension WebKitTab {
  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction,
               windowFeatures: WKWindowFeatures) -> WKWebView? {
    let contextGesture = (webView as? WebKitWebView).map { WebKitPagePolicy.consumeContextPopup(deadline: &$0.contextPopupDeadline, now: ProcessInfo.processInfo.systemUptime) } ?? false
    let gesture = contextGesture || action.responds(to: NSSelectorFromString("_isUserInitiated")) && (action.value(forKey: "_isUserInitiated") as? Bool) == true
    let origin = Origins.of(action.sourceFrame.securityOrigin)
    if !gesture && !WebKitHub.shared.stores.allowsPopups(profile: profile, origin: origin) {
      let id = UUID().uuidString
      blockedPopups[id] = (action.request, origin)
      emit("popupBlocked", ["id": id, "url": action.request.url?.absoluteString ?? "", "origin": origin])
      return nil
    }
    let child = WebKitWebView(frame: .zero, configuration: configuration)
    child.navigationDelegate = WebKitPopupPolicy.shared
    let id = WebKitHub.shared.transfers.offer(child)
    let flags = action.modifierFlags
    let popup = windowFeatures.width != nil || windowFeatures.height != nil
    let disposition = flags.contains(.command) || action.buttonNumber == 2 ? (flags.contains(.shift) ? "foreground" : "background") : popup ? "popup" : "foreground"
    emit("openWindow", ["url": action.request.url?.absoluteString ?? "", "disposition": disposition, "adoptId": id, "userGesture": gesture])
    return child
  }

  func webViewDidClose(_ webView: WKWebView) {
    emit("windowClose")
  }
}
