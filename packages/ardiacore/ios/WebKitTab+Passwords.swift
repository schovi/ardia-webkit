import AppKit
import WebKit

final class WebKitTabPasswordState {
  var frames: [WKFrameInfo] = []
  var menuOpen = false
  var pending: WebKitPasswordCandidate?
  var previousUsername: (String, String, Date)?
  func clear() { frames = []; pending = nil; previousUsername = nil }
}

final class WebKitPasswordCandidate {
  let id = UUID()
  let origin: String
  let username: String
  let password: WebKitPasswordSecret
  let updating: Bool
  init(origin: String, username: String, password: WebKitPasswordSecret, updating: Bool) {
    self.origin = origin
    self.username = username
    self.password = password
    self.updating = updating
  }
}

final class WebKitPasswordMenuAction: NSObject {
  let choose: () -> Void
  init(_ choose: @escaping () -> Void) { self.choose = choose }
  @objc func run(_ sender: NSMenuItem) { choose() }
}

extension WebKitTab {
  func passwordOrigin(_ frame: WKFrameInfo) -> String? {
    guard let frameOrigin = WebKitPasswordOrigin.of(frame.securityOrigin),
      let top = webView?.url.flatMap(WebKitPasswordOrigin.of), frameOrigin == top else { return nil }
    return frameOrigin
  }

  func passwordMessage(_ kind: String, data: [String: Any], token: String, frame: WKFrameInfo) {
    guard ["focus", "submit", "username"].contains(kind), !closed, let origin = passwordOrigin(frame), token.count <= 64, !token.isEmpty,
      WebKitPasswords.shared.offered(profile) else { return }
    let username = data["username"] as? String ?? ""
    guard username.utf8.count <= 4096 else { return }
    if kind == "username", !username.isEmpty {
      passwordState.previousUsername = (origin, username, Date())
      return
    }
    do {
      let vault = try WebKitPasswords.shared.vault(profile)
      let logins = try vault.logins(origin: origin)
      if kind == "submit" {
        guard !WebKitStores.isPrivate(profile), !(try vault.exceptions()).contains(origin),
          let text = data["password"] as? String, !text.isEmpty, text.utf8.count <= 65536 else { return }
        let previous = passwordState.previousUsername
        let username = !username.isEmpty ? username : previous?.0 == origin && Date().timeIntervalSince(previous!.2) < 120 ? previous!.1 : ""
        let password = WebKitPasswordSecret(text)
        if let saved = logins.first(where: { $0.username == username }) {
          let old = try vault.open(saved)
          defer { old.wipe() }
          if old.bytes.isEqual(to: password.bytes as Data) { return }
        }
        let candidate = WebKitPasswordCandidate(origin: origin, username: username, password: password, updating: logins.contains { $0.username == username })
        passwordState.pending = candidate
        emitPendingPasswordPrompt()
        let candidateId = candidate.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
          guard self?.passwordState.pending?.id == candidateId else { return }
          self?.passwordState.pending = nil
          self?.emit("passwordPrompt", ["state": "saved", "origin": origin, "username": "", "passwordLength": 0, "federation": "", "usernames": []])
        }
      } else if kind == "focus", !logins.isEmpty {
        if logins.count == 1, data["empty"] as? Bool == true, data["gesture"] as? Bool == true {
          fillPassword(logins[0], token: token, frame: frame)
        } else if data["gesture"] as? Bool == true {
          showPasswordMenu(logins, data: data, token: token, frame: frame)
        }
      }
    } catch { }
  }

  func emitPendingPasswordPrompt() {
    guard let candidate = passwordState.pending, !closed else { return }
    let usernames = (try? WebKitPasswords.shared.vault(profile).logins(origin: candidate.origin).map(\.username)) ?? []
    emit("passwordPrompt", ["state": candidate.updating ? "update" : "save", "origin": candidate.origin, "username": candidate.username,
      "passwordLength": candidate.password.text.utf16.count, "federation": "", "usernames": usernames])
  }

  private func fillPassword(_ login: WebKitPasswordVault.Login, token: String, frame: WKFrameInfo) {
    guard passwordOrigin(frame) == login.origin, let view = webView, WebKitPasswords.shared.offered(profile) else { return }
    do {
      let vault = try WebKitPasswords.shared.vault(profile)
      let password = try vault.open(login)
      defer { password.wipe() }
      view.callAsyncJavaScript("return window.__ardiaPasswords?.fill(token, username, password) === true;",
        arguments: ["token": token, "username": login.username, "password": password.text], in: frame, in: WebKitHub.passwordWorld) { [weak self] result in
        guard let self, !self.closed, case .success(let filled) = result, filled as? Bool == true, !WebKitStores.isPrivate(self.profile) else { return }
        try? vault.used(login)
      }
    } catch { }
  }

  private func showPasswordMenu(_ logins: [WebKitPasswordVault.Login], data: [String: Any], token: String, frame: WKFrameInfo) {
    guard !passwordState.menuOpen, let view = webView else { return }
    passwordState.menuOpen = true
    defer { passwordState.menuOpen = false }
    let menu = NSMenu()
    let actions = logins.map { login in WebKitPasswordMenuAction { [weak self] in self?.fillPassword(login, token: token, frame: frame) } }
    for (login, action) in zip(logins, actions) {
      let item = NSMenuItem(title: login.username.isEmpty ? "(no username)" : login.username, action: #selector(WebKitPasswordMenuAction.run(_:)), keyEquivalent: "")
      item.target = action
      menu.addItem(item)
    }
    if LaunchConfig.shared.background {
      guard let directory = LaunchConfig.shared.dataDirectory else { return }
      let path = URL(fileURLWithPath: directory).appendingPathComponent("password-menu.json")
      try? JSONSerialization.data(withJSONObject: menu.items.map { ["title": $0.title, "enabled": $0.isEnabled] }).write(to: path)
      let pick = path.appendingPathExtension("pick")
      if let title = try? String(contentsOf: pick, encoding: .utf8), let item = menu.items.first(where: { $0.title == title }) {
        NSApp.sendAction(item.action!, to: item.target, from: item)
      }
      try? FileManager.default.removeItem(at: pick)
      withExtendedLifetime(actions) {}
      return
    }
    let x = (data["x"] as? Double ?? 0) * view.pageZoom, y = (data["y"] as? Double ?? 0) * view.pageZoom
    guard x.isFinite, y.isFinite else { return }
    let point = NSPoint(x: max(0, min(view.bounds.width, x)), y: max(0, min(view.bounds.height, view.isFlipped ? y : view.bounds.height - y)))
    menu.popUp(positioning: nil, at: point, in: view)
    withExtendedLifetime(actions) {}
  }

  func resolveWebKitPasswordPrompt(_ action: String, username: String?, password: String?) {
    guard let candidate = passwordState.pending else { return }
    passwordState.pending = nil
    defer {
      candidate.password.wipe()
      emit("passwordPrompt", ["state": "saved", "origin": candidate.origin, "username": "", "passwordLength": 0, "federation": "", "usernames": []])
    }
    guard !WebKitStores.isPrivate(profile), WebKitPasswords.shared.offered(profile) else { return }
    do {
      let vault = try WebKitPasswords.shared.vault(profile)
      if action == "never", !candidate.updating { try vault.setNever(candidate.origin, never: true) }
      else if action == "save" || action == "update" {
        let secret = password.flatMap { $0.isEmpty ? nil : WebKitPasswordSecret($0) } ?? candidate.password
        defer { secret.wipe() }
        let target = username.flatMap { $0.isEmpty ? nil : $0 } ?? candidate.username
        let existing = try vault.logins(origin: candidate.origin).contains { $0.username == target }
        try vault.save(origin: candidate.origin, username: target, password: secret,
          replacing: action == "update" && existing ? target : nil)
      }
    } catch { }
  }
}
