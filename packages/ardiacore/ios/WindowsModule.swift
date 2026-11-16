import AppKit
import ExpoModulesCore

public class WindowsModule: Module {
  public func definition() -> ModuleDefinition {
    Name(Self.calls.moduleName)

    Self.calls.function
  }

  static let calls = CallTable(domain: "windows", handlers: [
    "devQuit": { _, reply in
      guard LaunchConfig.shared.testInstance else { return reply.ok(false) }
      reply.ok(true)
      Timer.scheduledTimer(withTimeInterval: 0, repeats: false) { _ in NSApp.terminate(nil) }
    },
    "list": { _, reply in reply.ok(ArdiaHost.chromeWindows) },
    "dev": { args, reply in
      let action = try args.text("action")
      guard let window = NSApp.window(withWindowNumber: try args.int("window")) else { return reply.ok("") }
      reply.ok(ArdiaChromeWindowHost.devAction(action, window: window) ?? "")
    },
  ])
}
