// curtain: a plain dark window over the whole of every display, for Mac shell scripts on a person's own Mac.
//
// There the person's windows lie behind the test windows, and a press that misses (a seam that is not up, a panel of
// Arbor's that lets clicks through, a frame that came back empty) would land in one of them, or on the wallpaper, which
// sweeps every window aside. The curtain hangs between: in front of everything that was open, behind everything the
// script opens afterwards. It takes every press that reaches it, does nothing with it, and never comes forward.
// lib.sh's net lets a press through only where a window of the script's own is the first to get it, so with the
// curtain up that is anywhere between the menu bar and the Dock, and without it almost nowhere.
//
//   curtain <pid> <seconds> <file>
//
// Hangs until process <pid> (the run's supervisor) is gone, for <seconds> at most, or until somebody right-clicks it. Writes
// every display's visible frame to <file>, one `x y w h` a line in global coordinates with the origin top-left,
// again whenever the displays change: that is where a press is neither in the menu bar nor in the Dock.
//
// lib.sh compiles it (swiftc -O -swift-version 5) and arbor_start hangs it.

import AppKit

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("curtain: \(message)\n".utf8))
  exit(64)
}

final class CurtainView: NSView {
  // Together these keep a click from bringing the curtain in front of the test windows.
  override func shouldDelayWindowOrdering(for event: NSEvent) -> Bool { true }
  override func mouseDown(with event: NSEvent) { NSApp.preventWindowOrdering() }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  // Scripts press only the left button, so this is a person who wants their screen back.
  override func rightMouseDown(with event: NSEvent) { exit(0) }
}

final class CurtainPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class Curtains: NSObject, NSApplicationDelegate {
  let supervisor: pid_t
  let seconds: Double
  let file: String
  var panels: [NSPanel] = []
  var watch: Timer?
  var observer: NSObjectProtocol?

  init(supervisor: pid_t, seconds: Double, file: String) {
    self.supervisor = supervisor
    self.seconds = seconds
    self.file = file
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    hang()
    observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.hang() }
    }
    // A curtain that outlives its run would be the very thing it is there to prevent.
    watch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [supervisor] _ in
      if kill(supervisor, 0) != 0, errno == ESRCH { exit(0) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
  }

  func hang() {
    for panel in panels { panel.close() }
    panels = NSScreen.screens.map { screen in
      let panel = CurtainPanel(
        contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.isReleasedWhenClosed = false
      panel.level = .normal
      panel.isFloatingPanel = false
      // Panels hide while their app is in the background, which this one always is.
      panel.hidesOnDeactivate = false
      panel.isOpaque = true
      panel.hasShadow = false
      panel.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1)
      panel.ignoresMouseEvents = false
      panel.collectionBehavior = [.ignoresCycle]
      let view = CurtainView(frame: NSRect(origin: .zero, size: screen.frame.size))
      let label = NSTextField(
        labelWithString: "Arbor's tests are running on this Mac (scripts/mac-shell). This curtain keeps their clicks away from "
          + "your windows and leaves with them. Right-click it to take it down now.")
      label.font = .systemFont(ofSize: 13)
      label.textColor = NSColor(calibratedWhite: 0.6, alpha: 1)
      label.sizeToFit()
      // At the top of the visible frame, which is given in the same coordinates as the display's own.
      label.setFrameOrigin(
        NSPoint(
          x: screen.visibleFrame.minX - screen.frame.minX + 16,
          y: screen.visibleFrame.maxY - screen.frame.minY - label.frame.height - 10))
      view.addSubview(label)
      panel.contentView = view
      panel.setFrame(screen.frame, display: true)
      panel.orderFrontRegardless()
      return panel
    }
    // AppKit counts up from the bottom of the first display, everything else here down from its top.
    let top = NSScreen.screens.first?.frame.maxY ?? 0
    let lines = NSScreen.screens.map { screen -> String in
      let visible = screen.visibleFrame
      return "\(Int(visible.minX)) \(Int(top - visible.maxY)) \(Int(visible.width)) \(Int(visible.height))"
    }
    do {
      try (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
    } catch {
      fail("cannot write \(file): \(error)")
    }
  }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3, let supervisor = pid_t(arguments[0]), supervisor > 1, let seconds = Double(arguments[1]), seconds > 0
else { fail("usage: curtain <pid> <seconds> <file>") }

MainActor.assumeIsolated {
  let delegate = Curtains(supervisor: supervisor, seconds: min(seconds, 3600), file: arguments[2])
  let application = NSApplication.shared
  application.delegate = delegate
  // No Dock icon, no menu bar, never the active app.
  application.setActivationPolicy(.accessory)
  withExtendedLifetime(delegate) { application.run() }
}
