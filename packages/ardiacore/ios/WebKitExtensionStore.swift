import Foundation
import WebKit

@available(macOS 15.4, *)
extension WebKitExtensions {
  func installCRX(_ path: String, expected: String? = nil, tabId: String? = nil) async throws -> String {
    guard !WebKitStores.isPrivate(profile) else { throw Self.error("Extensions are not loaded in private windows") }
    let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
    let id = try WebKitCRXSignature.verify(data, expected: expected)
    let scratch = URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("Extensions/staging-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let archive = scratch.appendingPathComponent("package.crx")
    try data.write(to: archive)
    let folder = scratch.appendingPathComponent("unpacked")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try WebKitExtensionArchive.unpack(archive.path, into: folder)
    return try await install(folder.path, chromeID: id, tabId: tabId, fromStore: expected != nil)
  }
}

final class WebKitExtensionStore: NSObject, WKScriptMessageHandler {
  static let shared = WebKitExtensionStore()
  static let world = WKContentWorld.world(name: "ardia.extensionStore")
  var rejectedNonce = 0
  var rejectedMain = 0
  var rejectedSubframe = 0
  var pending: Set<ObjectIdentifier> = []
  func attach(_ controller: WKUserContentController) {
    controller.add(self, contentWorld: Self.world, name: "ardiaExtensionStore")
    controller.addUserScript(WKUserScript(source: Self.script, injectionTime: .atDocumentEnd, forMainFrameOnly: false, in: Self.world))
  }
  func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
    let origin = message.frameInfo.securityOrigin
    guard #available(macOS 15.4, *), message.world == Self.world,
      WebKitStorePolicy.allows(main: message.frameInfo.isMainFrame, scheme: origin.protocol, host: origin.host, port: origin.port),
      let view = message.webView, let tab = WebKitHub.shared.transfers.owner(of: view),
      let id = WebKitStorePolicy.identifier(view.url) else {
        if LaunchConfig.shared.testInstance { if message.frameInfo.isMainFrame { rejectedMain += 1 } else { rejectedSubframe += 1 } }
        return
      }
    let installed = WebKitExtensions.shared(tab.profile).records[id] != nil
    if message.body as? String == "state" { return update(view, id: id, installed: installed) }
    guard !WebKitStores.isPrivate(tab.profile), !installed, let nonce = message.body as? String,
      !pending.contains(ObjectIdentifier(view)) else { return }
    view.evaluateJavaScript("window.__ardiaStoreConsume(\(WebKitTab.jsString(nonce)))", in: message.frameInfo, in: Self.world) { result in
      guard case .success(let accepted) = result, accepted as? Bool == true, WebKitStorePolicy.identifier(view.url) == id else { if LaunchConfig.shared.testInstance { self.rejectedNonce += 1 }; return }
      self.download(id, tab: tab, view: view)
    }
  }
  func update(_ view: WKWebView, id: String, installed: Bool) {
    view.evaluateJavaScript("window.__ardiaStoreState(\(WebKitTab.jsString(id)),\(installed))", in: nil, in: Self.world) { _ in }
  }
  @available(macOS 15.4, *)
  func download(_ id: String, tab: WebKitTab, view: WKWebView) {
    let key = ObjectIdentifier(view)
    guard pending.insert(key).inserted else { return }
    WebKitFetchStore(id) { data, response, error in
      Task { @MainActor in
        defer { self.pending.remove(key) }
        var archive: URL?
        defer { if let archive { try? FileManager.default.removeItem(at: archive) } }
        do {
          guard let data, error == nil, response?.statusCode == 200 else { throw error ?? WebKitExtensions.error("Store download failed (HTTP \(response?.statusCode ?? 0))") }
          _ = try WebKitCRXSignature.verify(data, expected: id)
          let root = URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("Extensions")
          try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
          let file = root.appendingPathComponent("download-" + UUID().uuidString + ".crx")
          archive = file
          try data.write(to: file)
          _ = try await WebKitExtensions.shared(tab.profile).installCRX(file.path, expected: id, tabId: tab.transferKey)
          self.update(view, id: id, installed: true)
        } catch {
          self.update(view, id: id, installed: false)
          ArdiaEvents.emit("extensions.installFailed", data: ["message": error.localizedDescription, "tabId": tab.transferKey ?? NSNull() as Any])
        }
      }
    }
  }
  static var script: String { """
(() => {
  if (location.origin !== "https://chromewebstore.google.com" && !\(LaunchConfig.shared.testInstance)) return;
  let nonce = null, requestedId = null, lastId = null, installed = false, busy = false;
  const id = () => location.pathname.split('/').filter(Boolean).at(-1);
  const button = () => [...document.querySelectorAll('button')].find(b => /^(Add to (Chrome|Ardia)|Added)$/.test(b.textContent.trim()));
  const refresh = () => {
    if (lastId !== id()) { lastId = id(); installed = false; busy = false; nonce = null; window.webkit.messageHandlers.ardiaExtensionStore.postMessage('state'); }
    const b = button(); if (!b) return;
    const text = installed ? 'Added' : 'Add to Ardia';
    if (b.textContent.trim() !== text) b.textContent = text;
    if (b.disabled !== (installed || busy)) b.disabled = installed || busy;
    if (b.getAttribute('aria-disabled') !== String(installed || busy)) b.setAttribute('aria-disabled', String(installed || busy));
    b.style.pointerEvents = 'auto';
  };
  window.__ardiaStoreState = (extensionId, value) => { if (extensionId === id()) { installed = value; busy = false; refresh(); } };
  window.__ardiaStoreConsume = value => { const valid = nonce !== null && nonce === value && requestedId === id(); nonce = null; return valid; };
  const request = () => { if (installed || busy) return false; busy = true; requestedId = id(); nonce = crypto.randomUUID(); window.webkit.messageHandlers.ardiaExtensionStore.postMessage(nonce); refresh(); return true; };
  window.addEventListener('click', event => {
    if (!button()?.contains(event.target)) return;
    event.preventDefault(); event.stopImmediatePropagation();
    if (event.isTrusted) request();
  }, true);
  new MutationObserver(refresh).observe(document.documentElement, {subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['disabled','aria-disabled']});
  refresh();
  window.webkit.messageHandlers.ardiaExtensionStore.postMessage('state');
  \(LaunchConfig.shared.testInstance ? "window.__ardiaStoreTestClick = request;" : "")
})();
""" }
}
