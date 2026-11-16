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
