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
    "devPageState": { args, reply in
      guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), let view = tab.webView else { return reply.ok() }
      let responder = view.window?.firstResponder as? NSView
      reply.ok(["focused": responder?.isDescendant(of: view) ?? false, "responder": view.window?.firstResponder.map { String(describing: type(of: $0)) } ?? "", "focusRequests": view.focusRequests, "fullScreen": view.fullscreenState.rawValue, "window": view.window?.windowNumber ?? 0, "active": NSApp.isActive, "key": view.window?.isKeyWindow ?? false, "background": LaunchConfig.shared.background])
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
