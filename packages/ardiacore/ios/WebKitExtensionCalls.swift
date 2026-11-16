import Foundation
import WebKit

enum WebKitExtensionCalls {
  static let handlers: [String: CallHandler] = Dictionary(uniqueKeysWithValues: ["install", "installCrx", "setEnabled", "uninstall", "reload", "configure", "actionStates", "sidePanelUrl", "watchActions", "syncState", "syncApply", "resolveInstallPrompt"].map { name in
    (name, { args, reply in
      guard #available(macOS 15.4, *) else { return reply.fail("ERR_UNSUPPORTED", "Extensions require macOS 15.4") }
      if name == "resolveInstallPrompt" {
        let request = try args.text("requestId")
        let accepted = try args.bool("accepted")
        if request == "webkit-gate", LaunchConfig.shared.testInstance { WebKitExtensionGate.shared.accept(accepted) }
        else { WebKitExtensions.prompts.removeValue(forKey: request)?(accepted) }
        return reply.ok()
      }
      if name == "syncState" { return reply.ok(["ready": false, "extensions": [], "pending": [], "settling": [], "queued": [], "intents": [], "unsupported": true]) }
      if name == "syncApply" { return reply.ok(["state": "refused", "unsupported": true]) }
      if name == "sidePanelUrl" { return reply.ok() }
      if name == "actionStates" {
        guard let tab = WebKitHub.shared.transfers.liveTab(try args.text("tabId")), !WebKitStores.isPrivate(tab.profile) else { return reply.ok([:]) }
        return reply.ok(WebKitExtensions.shared(tab.profile).actionStates(tab, ids: try args.strings("ids")))
      }
      guard !WebKitStores.isPrivate(args.profile) else { return reply.fail("ERR_UNSUPPORTED", "Extensions are not loaded in private windows") }
      let manager = WebKitExtensions.shared(args.profile)
      if name == "watchActions" { manager.watching = true; return reply.ok([:]) }
      Task { @MainActor in
        do {
          if name == "install" { return reply.ok(["id": try await manager.install(args.text("path"))]) }
          if name == "installCrx" {
            let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ardia-crx-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: scratch) }
            let path = try args.text("path")
            let chromeID = try WebKitExtensionArchive.signedIdentifier(Data(contentsOf: URL(fileURLWithPath: path)))
            try WebKitExtensionArchive.unpack(path, into: scratch)
            return reply.ok(["id": try await manager.install(scratch.path, chromeID: chromeID)])
          }
          let options = name == "configure" ? try args.dict("options") : name == "setEnabled" ? ["enabled": try args.bool("enabled")] : [:]
          try await manager.change(args.text("id"), operation: name, options: options)
          reply.ok(["ok": true])
        } catch { reply.fail("ERR_EXTENSION", error.localizedDescription) }
      }
    } as CallHandler)
  })
}

@_cdecl("ArdiaWebKitExtensionsWatch")
func webKitWatchExtensions(_ profile: NSString) {
  DispatchQueue.main.async {
    guard #available(macOS 15.4, *), !WebKitStores.isPrivate(profile as String) else { return }
    WebKitExtensions.shared(profile as String).watching = true
  }
}
