import AppKit
import CryptoKit
import WebKit

@available(macOS 15.4, *)
final class WebKitExtensions: NSObject, WKWebExtensionControllerDelegate {
  static var profiles: [String: WebKitExtensions] = [:]
  static var prompts: [String: (Bool) -> Void] = [:]
  let profile: String
  let controller: WKWebExtensionController
  var contexts: [String: WKWebExtensionContext] = [:]
  var tabs: [ObjectIdentifier: WebKitExtensionTab] = [:]
  var windows: [ObjectIdentifier: WebKitExtensionWindow] = [:]
  var watching = false
  var errorsObserver: NSObjectProtocol?

  deinit { if let errorsObserver { NotificationCenter.default.removeObserver(errorsObserver) } }

  static func shared(_ profile: String) -> WebKitExtensions {
    if let existing = profiles[profile] { return existing }
    let made = WebKitExtensions(profile)
    profiles[profile] = made
    Task { @MainActor in
      for (id, value) in made.records {
        guard let record = value as? [String: Any], record["enabled"] as? Bool == true else { continue }
        do { try await made.load(id, record: record) }
        catch { made.saveError(id, error) }
      }
    }
    return made
  }

  init(_ profile: String) {
    self.profile = profile
    let config = WKWebExtensionController.Configuration(identifier: WebKitStores.storeIdentifier(profile))
    config.defaultWebsiteDataStore = WebKitHub.shared.stores.dataStore(for: profile)
    controller = WKWebExtensionController(configuration: config)
    super.init()
    controller.delegate = self
    errorsObserver = NotificationCenter.default.addObserver(forName: WKWebExtensionContext.errorsDidUpdateNotification, object: nil, queue: .main) { [weak self] note in
      guard let self, let context = note.object as? WKWebExtensionContext, self.contexts[context.uniqueIdentifier] === context,
        var record = self.records[context.uniqueIdentifier] as? [String: Any] else { return }
      record["errors"] = context.errors.map(\.localizedDescription)
      self.save(context.uniqueIdentifier, record)
      self.changed(context.uniqueIdentifier, "configured")
    }
  }

  var records: [String: Any] { WebKitProfileSettings(profile, "extensions") as? [String: Any] ?? [:] }

  func save(_ id: String, _ record: [String: Any]?) { WebKitSetProfileSetting(profile, "extensions", id, record) }

  func saveError(_ id: String, _ error: Error) {
    guard var record = records[id] as? [String: Any] else { return }
    record["errors"] = [error.localizedDescription]
    record["enabled"] = false
    record["state"] = "DISABLED"
    record["disabledReason"] = "unsupported"
    save(id, record)
  }

  func load(_ id: String, record: [String: Any]) async throws {
    guard let path = record["path"] as? String else { throw Self.error("Missing installed extension folder") }
    let extensionObject = try await WKWebExtension(resourceBaseURL: URL(fileURLWithPath: path, isDirectory: true))
    let context = WKWebExtensionContext(for: extensionObject)
    context.uniqueIdentifier = id
    context.baseURL = URL(string: "webkit-extension://\(id)/")!
    context.hasAccessToPrivateData = false
    for permission in record["grantedPermissions"] as? [String] ?? [] { context.setPermissionStatus(.grantedExplicitly, for: WKWebExtension.Permission(rawValue: permission)) }
    for pattern in record["sites"] as? [String] ?? [] {
      context.setPermissionStatus(.grantedExplicitly, for: try WKWebExtension.MatchPattern(string: pattern))
    }
    context.setPermissionStatus(.deniedExplicitly, for: try WKWebExtension.MatchPattern(string: "file:///*"))
    try controller.load(context)
    contexts[id] = context
    for tab in WebKitHub.shared.transfers.liveTabs where tab.profile == profile { opened(tab) }
  }

  static func error(_ text: String) -> NSError { NSError(domain: "ArdiaExtensions", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }

  func prompt(id: String, name: String, version: String, permissions: [String], type: String = "install", answer: @escaping (Bool) -> Void) {
    let request = UUID().uuidString
    Self.prompts[request] = answer
    let data: [String: Any] = ["requestId": request, "profile": profile, "id": id, "name": name, "version": version, "type": type, "icon": "", "permissions": permissions, "tabId": NSNull()]
    if LaunchConfig.shared.background, let encoded = try? JSONSerialization.data(withJSONObject: data) {
      try? encoded.write(to: URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("extension-install-prompt.json"))
      NSLog("[webkit] extension install prompt %@ (background mode, not shown)", name)
    }
    ArdiaEvents.emit("extensions.installPrompt", data: data)
  }

  func install(_ path: String, chromeID: String? = nil) async throws -> String {
    guard !WebKitStores.isPrivate(profile) else { throw Self.error("Extensions are not loaded in private windows") }
    let source = URL(fileURLWithPath: path, isDirectory: true)
    try WebKitExtensionArchive.validateFolder(source)
    let package = ArdiaServices.inspectUnpacked(path)
    if let error = package["error"] as? String { throw Self.error(error) }
    let id = chromeID ?? package["id"] as? String ?? WebKitExtensionArchive.identifier(Data(source.standardizedFileURL.path.utf8))
    guard records[id] == nil else { throw Self.error("Extension already installed") }
    let root = URL(fileURLWithPath: ArdiaHost.dataDirectory).appendingPathComponent("Extensions/\(WebKitStores.storeIdentifier(profile))/\(id)")
    try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: source, to: root)
    do {
      try WebKitExtensionArchive.validateFolder(root)
      let extensionObject = try await WKWebExtension(resourceBaseURL: root)
      let hosts = extensionObject.allRequestedMatchPatterns.map(\.string).sorted()
      let permissions = extensionObject.requestedPermissions.map(\.rawValue).sorted()
      let accepted = await withCheckedContinuation { continuation in
        prompt(id: id, name: extensionObject.displayName ?? id, version: extensionObject.version ?? "", permissions: permissions + hosts) { continuation.resume(returning: $0) }
      }
      guard accepted else { throw Self.error("Extension installation cancelled") }
      var record = package
      record["id"] = id
      record["path"] = root.path
      record["enabled"] = true
      record["state"] = "ENABLED"
      record["sites"] = hosts
      record["grantedPermissions"] = permissions
      record["permissions"] = permissions + hosts
      record["siteAccess"] = "ON_SPECIFIC_SITES"
      record["icon"] = extensionObject.icon(for: CGSize(width: 32, height: 32))?.pngDataURL(points: 32, scale: 2) ?? ""
      record["actionIcon"] = extensionObject.actionIcon(for: CGSize(width: 32, height: 32))?.pngDataURL(points: 32, scale: 2) ?? record["icon"]
      record["pinned"] = false
      record["incognito"] = false
      record["fileAccess"] = false
      record["mayModify"] = true
      record["errors"] = extensionObject.errors.map(\.localizedDescription)
      record["location"] = "UNPACKED"
      record["fromWebStore"] = false
      record["sidePanel"] = NSNull()
      for key in ["optionsUrl", "webStoreUrl", "homepageUrl"] where record[key] == nil { record[key] = NSNull() }
      save(id, record)
      try await load(id, record: record)
      changed(id, "installed")
      return id
    } catch {
      save(id, nil)
      try? FileManager.default.removeItem(at: root)
      throw error
    }
  }

  func change(_ id: String, operation: String, options: [String: Any]) async throws {
    guard var record = records[id] as? [String: Any] else { throw Self.error("No such extension") }
    if operation == "configure" {
      guard options.keys.allSatisfy({ $0 == "pinned" }), let pinned = options["pinned"] as? Bool else { throw Self.error("Only toolbar pinning is supported on WebKit") }
      record["pinned"] = pinned
    } else {
      if let context = contexts[id] { try controller.unload(context); contexts.removeValue(forKey: id) }
      if operation == "uninstall" {
        if let path = record["path"] as? String { try FileManager.default.removeItem(atPath: path) }
        let types = WKWebExtensionController.allExtensionDataTypes
        let data = await controller.dataRecords(ofTypes: types).filter { $0.uniqueIdentifier == id }
        await controller.removeData(ofTypes: types, from: data)
        save(id, nil)
        return changed(id, "uninstalled")
      }
      let enabled = operation == "reload" ? record["enabled"] as? Bool == true : options["enabled"] as? Bool == true
      record["enabled"] = enabled
      record["state"] = enabled ? "ENABLED" : "DISABLED"
      record["disabledReason"] = "user"
      if enabled {
        do { try await load(id, record: record) }
        catch { saveError(id, error); changed(id, "disabled"); throw error }
      }
    }
    save(id, record)
    changed(id, operation == "configure" ? "configured" : operation == "reload" ? "reloaded" : record["enabled"] as? Bool == true ? "enabled" : "disabled")
  }

  func changed(_ id: String, _ event: String) {
    ArdiaEvents.emit("extensions.changed", data: ["profile": profile, "id": id, "event": event])
    actionChanged(id)
  }

  func actionChanged(_ id: String) {
    if watching { ArdiaEvents.emit("extensions.action", data: ["profile": profile, "id": id, "kind": "action"]) }
  }
}
