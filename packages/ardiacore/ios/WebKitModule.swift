import AppKit
import ExpoModulesCore
import WebKit

public class WebKitModule: Module {
  public func definition() -> ModuleDefinition {
    Name(Self.calls.moduleName)

    Self.calls.function

    PageViewDefinition.of(WebKitTabView.self)
  }
  static let calls = CallTable(domain: "webKit", handlers: [
    "removeDownloadStaging": { args, reply in
      reply.ok(WebKitDownloads.removeStaging(try args.text("path")))
    },
    "endPrivateSession": { args, reply in
      WebKitHub.shared.endPrivateSession(try args.text("session"))
      reply.ok()
    },
    "cookieStoreKey": { args, reply in reply.ok(WebKitHub.shared.stores.id(of: args.profile).wireKey) },
    "importCookies": { args, reply in
      let cookies = try args.dicts("cookies")
      WebKitHub.shared.importCookies(cookies, profile: args.profile, storeKey: try args.text("storeKey")) { reply.ok($0) }
    },
    "passkeyAccess": { _, reply in reply.ok(WebKitPasskeys.access()) },
    "requestPasskeyAccess": { _, reply in WebKitPasskeys.requestAccess { reply.ok($0) } },
  ].merging(LaunchConfig.shared.testInstance ? testInstanceCalls : [:]) { call, _ in call })

  private static let testInstanceCalls: [String: CallHandler] = [
    "devExtensionPopup": { args, reply in
      func popup(_ view: NSView) -> WKWebView? {
        if let tab = view as? WebKitTab, let popup = tab.extensionPopup { return popup }
        for child in view.subviews { if let found = popup(child) { return found } }
        return nil
      }
      guard let view = NSApp.windows.compactMap(\.contentView).compactMap({ popup($0) }).first else { return reply.ok(["attached": false]) }
      var opacity = 1.0
      var ancestor: NSView? = view
      while let current = ancestor {
        opacity = min(opacity, Double(current.alphaValue), Double(current.layer?.presentation()?.opacity ?? current.layer?.opacity ?? 1))
        ancestor = current.superview
      }
      let visibleOpacity = opacity
      let popupTab = view.superview as? WebKitTab
      let popupEvents = Array((popupTab?.superview as? PageTabHost)?.pageEvents ?? [])
      view.callAsyncJavaScript(try args.optionalText("script") ?? "return document.body.innerText", arguments: [:], in: nil, in: .page) { result in
        switch result {
        case .success(let value): reply.ok(["attached": view.superview != nil, "events": popupEvents, "delegate": popupTab?.delegate == nil ? "missing" : "present", "opacity": visibleOpacity, "visible": !view.isHiddenOrHasHiddenAncestor, "windowVisible": view.window?.isVisible ?? false, "key": view.window?.isKeyWindow ?? false, "active": NSApp.isActive, "width": view.bounds.width, "height": view.bounds.height, "value": value, "url": view.url?.absoluteString ?? ""])
        case .failure(let error): reply.ok(["attached": true, "failure": error.localizedDescription])
        }
      }
    },
    "devExtensionGate": { args, reply in
      guard #available(macOS 15.4, *) else { return reply.ok(["error": "Requires macOS 15.4"]) }
      let gate = WebKitExtensionGate.shared
      if args.values["probe"] as? Bool == true { return gate.probe { reply.ok($0) } }
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")),
        let url = URL(string: try args.text("url")) else { return reply.ok(["error": "Missing tab or URL"]) }
      let path = try args.text("path")
      Task { @MainActor in
        do { reply.ok(try await gate.prepare(path: path, tab: tab, url: url)) }
        catch { reply.ok(["error": (error as NSError).description]) }
      }
    },
    "devPasswordBridge": { args, reply in
      if args.values["read"] as? Bool == true {
        return ArdiaEngineBridge.callForSecretReply("ac_passwords_logins", profile: args.profile, timeout: 1) { reply.ok($0 ?? [:]) }
      }
      let bytes = NSMutableData(data: Data((try args.text("json")).utf8))
      ArdiaEngineBridge.callWithSecret(try args.text("name"), profile: args.profile, args: bytes) { result in
        let parsed = (try? JSONSerialization.jsonObject(with: Data(result.utf8))) as? [String: Any] ?? [:]
        reply.ok(["result": parsed, "wiped": (bytes as Data).allSatisfy { $0 == 0 }])
      }
    },
    "devPasswordExport": { args, reply in
      ArdiaServices.exportPasswords(profile: args.profile, path: try args.text("path")) { reply.service($0, $1) }
    },
    "devPasswordFocus": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok(false) }
      let subframe = args.values["subframe"] as? Bool == true
      let frame = tab.passwordState.frames.last { $0.isMainFrame != subframe }
      guard let frame else { return reply.ok(false) }
      let probe = args.values["probe"] as? Bool == true
      let script = probe ? "document.querySelector('input[type=password]').value.length === 0" : "document.querySelector('input[type=password]')?.focus(); window.__ardiaPasswords.request(true);"
      view.evaluateJavaScript(script, in: frame, in: WebKitHub.passwordWorld) { result in
        var empty = false
        if case .success(let value) = result { empty = value as? Bool == true }
        reply.ok(["eligible": tab.passwordOrigin(frame) != nil, "empty": empty])
      }
    },
    "devPermission": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok(false) }
      let kind = try args.text("kind")
      guard ["camera", "microphone"].contains(kind) else { return reply.ok(false) }
      tab.permissionTestReply = { reply.ok($0) }
      view.evaluateJavaScript("window.webkit.messageHandlers.ardia.postMessage({kind:'devPermission',data:\(WebKitTab.jsString(kind))})", in: nil, in: WebKitHub.world) { _ in }
    },
    "devOpenURLs": { args, reply in
      let urls = try args.strings("urls").compactMap(URL.init(string:))
      NSApp.delegate?.application?(NSApp, open: urls)
      reply.ok()
    },
    "devPageFailure": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok(false) }
      let error = NSError(domain: NSURLErrorDomain, code: try args.int("code"), userInfo: [NSURLErrorFailingURLErrorKey: URL(string: try args.text("url"))!])
      tab.webView(view, didFailProvisionalNavigation: nil, withError: error)
      reply.ok(true)
    },
    "devHTTPAuth": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")) else { return reply.ok(false) }
      let pending = tab.authenticationReply != nil
      if let action = args.values["action"] as? String, action == "answer" {
        tab.resolveHTTPAuth(username: args.values["username"] as? String, password: args.values["password"] as? String)
      }
      reply.ok(pending)
    },
    "devPageState": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok() }
      let responder = view.window?.firstResponder as? NSView
      reply.ok(["standalone": tab.standalone, "pageColor": tab.pageColor ?? "", "backgroundColor": WebKitTab.hex(view.underPageBackgroundColor) ?? "", "inspectable": view.isInspectable, "focused": responder?.isDescendant(of: view) ?? false, "responder": view.window?.firstResponder.map { String(describing: type(of: $0)) } ?? "", "focusRequests": view.focusRequests, "fullScreen": view.fullscreenState.rawValue, "window": view.window?.windowNumber ?? 0, "active": NSApp.isActive, "key": view.window?.isKeyWindow ?? false, "background": LaunchConfig.shared.background])
    },
    "devStoreExists": { args, reply in WebKitHub.shared.storeExists(args.profile) { reply.ok($0) } },
    "devHoldStore": { args, reply in
      WebKitHub.shared.stores.holdForTest(args.profile)
      reply.ok()
    },
    "devTouchStore": { args, reply in WebKitHub.shared.touchStore(args.profile) { reply.ok($0) } },
    "devParkedTransfers": { _, reply in reply.ok(WebKitHub.shared.transfers.parkedKeys) },
    "devContentBlocker": { _, reply in reply.ok(WebKitContentBlocker.shared.state) },
  ]
}
