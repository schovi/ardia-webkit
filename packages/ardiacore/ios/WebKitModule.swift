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
    "devExtensionStore": { args, reply in
      if args.values["stats"] as? Bool == true { return reply.ok(["nonce": WebKitExtensionStore.shared.rejectedNonce, "main": WebKitExtensionStore.shared.rejectedMain, "subframe": WebKitExtensionStore.shared.rejectedSubframe]) }
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok() }
      view.callAsyncJavaScript(try args.text("script"), arguments: [:], in: nil, in: WebKitExtensionStore.world) { result in
        switch result {
        case .success(let value): reply.ok(value)
        case .failure(let error): reply.fail("ERR_STORE_TEST", error.localizedDescription)
        }
      }
    },
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
    "devInspector": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView,
        let inspector = view.value(forKey: "_inspector") as? NSObject else { return reply.ok() }
      if let action = try args.optionalText("action"), ["detach", "attach", "close"].contains(action), inspector.responds(to: NSSelectorFromString(action)) {
        inspector.perform(NSSelectorFromString(action))
      }
      var state: [String: Any] = [:]
      for property in ["visible", "connected", "elementSelectionActive"] {
        let getter = "is" + property.prefix(1).uppercased() + property.dropFirst()
        if inspector.responds(to: NSSelectorFromString(getter)) { state[property] = inspector.value(forKey: property) }
      }
      let frontendSelector = NSSelectorFromString("inspectorWebView")
      if inspector.responds(to: frontendSelector), let frontend = inspector.perform(frontendSelector)?.takeUnretainedValue() as? WKWebView {
        state["frontend"] = ["window": frontend.window?.windowNumber ?? 0, "visible": frontend.window?.isVisible == true && !frontend.isHiddenOrHasHiddenAncestor, "width": frontend.bounds.width, "height": frontend.bounds.height, "url": frontend.url?.absoluteString ?? ""]
      }
      reply.ok(state)
    },
    "devPageGeometry": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok() }
      func cache(_ name: String) throws {
        guard args.values["cache"] as? Bool == true, let directory = LaunchConfig.shared.dataDirectory,
          let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
      }
      try cache("page-cache.png")
      if let script = try args.optionalText("record") {
        var scrollEvents: [[String: Any]] = []
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { original in
          var event = original
          let selector = NSSelectorFromString("_eventWithRetargetedLocation:")
          if args.values["nativeScroll"] as? Bool == true, original.responds(to: selector) {
            typealias Retarget = @convention(c) (AnyObject, Selector, NSPoint) -> Unmanaged<NSEvent>
            let point = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
            event = unsafeBitCast(original.method(for: selector), to: Retarget.self)(original, selector, point).takeUnretainedValue()
          }
          scrollEvents.append(["point": NSStringFromPoint(event.locationInWindow), "window": event.windowNumber, "phase": event.phase.rawValue, "momentum": event.momentumPhase.rawValue, "delta": event.scrollingDeltaY, "hit": event.window?.contentView?.hitTest(event.locationInWindow).map { String(describing: type(of: $0)) } ?? "nil"])
          return event
        }
        var samples: [[String: Any]] = [["at": 0, "views": WebKitModule.geometry(view)]]
        view.evaluateJavaScript(script)
        if args.values["nativeScroll"] as? Bool == true {
          let delta = (args.values["delta"] as? Int ?? -60)
          for index in 0..<34 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.025) {
              guard let window = view.window,
                let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: index == 16 || index == 33 ? 0 : Int32(delta), wheel2: 0, wheel3: 0) else { return }
              let point = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
              let screen = window.convertPoint(toScreen: point)
              event.location = CGPoint(x: screen.x, y: (NSScreen.screens.first?.frame.height ?? 0) - screen.y)
              event.setIntegerValueField(CGEventField(rawValue: 51)!, value: Int64(window.windowNumber))
              event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window.windowNumber))
              event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window.windowNumber))
              event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
              event.setIntegerValueField(.scrollWheelEventScrollPhase, value: index == 0 ? 1 : index < 16 ? 2 : index == 16 ? 4 : 0)
              event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: index < 17 ? 0 : index == 17 ? 1 : index == 33 ? 3 : 2)
              if let native = NSEvent(cgEvent: event) { NSApp.postEvent(native, atStart: false) }
            }
          }
        }
        for delay in [0.1, 0.4, 1.0, 2.0] {
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            samples.append(["at": delay, "views": WebKitModule.geometry(view)])
            try? cache("page-cache-\(Int(delay * 1000)).png")
            if delay == 2 {
              if let monitor { NSEvent.removeMonitor(monitor) }
              samples.append(["events": scrollEvents])
              reply.ok(samples)
            }
          }
        }
      } else { reply.ok(WebKitModule.geometry(view)) }
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
  static func geometry(_ page: NSView) -> [[String: Any]] {
    var result: [[String: Any]] = []
    var current: NSView? = page
    while let view = current {
      let layer = view.layer
      var item: [String: Any] = ["class": String(describing: type(of: view)), "frame": NSStringFromRect(view.frame), "bounds": NSStringFromRect(view.bounds), "visibleRect": NSStringFromRect(view.visibleRect), "clipsToBounds": view.clipsToBounds, "flipped": view.isFlipped, "hidden": view.isHidden, "window": view.window?.windowNumber ?? 0]
      if let layer {
        item["layer"] = ["frame": NSStringFromRect(layer.frame), "bounds": NSStringFromRect(layer.bounds), "position": NSStringFromPoint(layer.position), "anchorPoint": NSStringFromPoint(layer.anchorPoint), "transform": [layer.transform.m11, layer.transform.m12, layer.transform.m13, layer.transform.m14, layer.transform.m21, layer.transform.m22, layer.transform.m23, layer.transform.m24, layer.transform.m31, layer.transform.m32, layer.transform.m33, layer.transform.m34, layer.transform.m41, layer.transform.m42, layer.transform.m43, layer.transform.m44], "geometryFlipped": layer.isGeometryFlipped, "masksToBounds": layer.masksToBounds, "mask": layer.mask.map { String(describing: $0) } ?? "nil", "presentationFrame": layer.presentation().map { NSStringFromRect($0.frame) } ?? "nil"]
      }
      if view === page {
        for name in ["_exposedContentRect", "documentVisibleRect", "_clipsToVisibleRect", "_drawingAreaSize"] where view.responds(to: NSSelectorFromString(name)) {
          item[name] = String(describing: view.value(forKey: name))
        }
        item["children"] = view.subviews.map { ["class": String(describing: type(of: $0)), "frame": NSStringFromRect($0.frame), "bounds": NSStringFromRect($0.bounds), "visible": NSStringFromRect($0.visibleRect)] }
      }
      result.append(item)
      if view === view.window?.contentView { break }
      current = view.superview
    }
    return result
  }

}
