import AppKit
import ArdiaCore
import ArdiaShell

final class BrowserWindow: NSWindow {
  private var restoredFrame: NSRect?
  private let trafficLightInset = NSPoint(x: 16, y: 20)

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 1360, height: 860),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    title = "Ardia"
    minSize = NSSize(width: 720, height: 460)
    isReleasedWhenClosed = false
    backgroundColor = NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.17, green: 0.12, blue: 0.14, alpha: 1)
        : NSColor(srgbRed: 0.93, green: 0.91, blue: 0.90, alpha: 1)
    }

    for name in [NSWindow.didResizeNotification, NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(layoutTrafficLights), name: name, object: self)
    }
    layoutTrafficLights()
  }

  override func toggleFullScreen(_ sender: Any?) {
    guard LaunchConfig.shared.background else { return super.toggleFullScreen(sender) }
    let entering = restoredFrame == nil
    let center = NotificationCenter.default
    center.post(name: entering ? NSWindow.willEnterFullScreenNotification : NSWindow.willExitFullScreenNotification, object: self)
    if entering {
      restoredFrame = frame
      if let screen { setFrame(screen.frame, display: true) }
    } else if let saved = restoredFrame {
      setFrame(saved, display: true)
      restoredFrame = nil
    }
    center.post(name: entering ? NSWindow.didEnterFullScreenNotification : NSWindow.didExitFullScreenNotification, object: self)
  }

  override func performClose(_ sender: Any?) {
    if ArdiaChromeWindowHost.windowShouldClose(self) { close() }
  }

  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    layoutTrafficLights()
  }

  @objc private func layoutTrafficLights() {
    guard !styleMask.contains(.fullScreen),
          let close = standardWindowButton(.closeButton),
          let mini = standardWindowButton(.miniaturizeButton),
          let zoom = standardWindowButton(.zoomButton),
          let container = close.superview?.superview else { return }

    let requested = ArdiaTrafficLightsCenter(self)?.pointValue
    let center = requested ?? NSPoint(x: trafficLightInset.x + close.frame.width / 2, y: trafficLightInset.y + close.frame.height / 2)
    let x = ArdiaTrafficLightsTrailing(self) ? frame.width - center.x : center.x
    let height = center.y * 2
    var frame = container.frame
    frame.size.height = height
    frame.origin.y = self.frame.height - height
    container.frame = frame

    let spacing = mini.frame.minX - close.frame.minX
    for (i, button) in [close, mini, zoom].enumerated() {
      button.setFrameOrigin(NSPoint(
        x: x - button.frame.width / 2 + CGFloat(i) * spacing,
        y: (height - button.frame.height) / 2
      ))
    }
  }
}
