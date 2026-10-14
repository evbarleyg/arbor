// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// AppKit and QuartzCore as they come out when written without a compiler.
import AppKit
import QuartzCore

final class ProbePanel: NSPanel {
  init() {
    super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
  }
  override var canBecomeKey: Bool { false }

  func probe(_ frame: NSRect) {
    setFrame(frame, display: true)
    orderFrontRegardless()
    setFrame(frame, displaying: true)  // wrong
    orderAway(nil)  // wrong
    level = .flotating  // wrong
    collectionBehavior = [.canJoinAllSpaces, .stationery]  // wrong
    hasShadow = nil  // wrong
  }
}

final class ProbeView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    NSColor.controlAccentColor.withAlphaComponent(0.2).setFill()
    NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
    NSBezierPath(roundedRect: bounds, radius: 4).fill()  // wrong
  }
  override func mouseExited(with event: NSEvent) {}
  override func mouseLeft(with event: NSEvent) {}  // wrong
}

// A view with an initializer of its own owes AppKit `init?(coder:)`.
final class ProbeViewWithoutCoder: NSView {
  init(side: CGFloat) { super.init(frame: .zero) }
}  // wrong

@MainActor func probeStatusItemAndLayers() {
  let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  item.button?.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
  item.button.image = nil  // wrong
  let layer = CAShapeLayer()
  layer.fillRule = .evenOdd
  layer.fillRule = .evenodd  // wrong
  CATransaction.setDisableActions(true)
  CATransaction.disableActions = true  // wrong
}

// A selector needs a method that Objective-C can see (prepare.py's check) and that exists.
@MainActor final class ProbeTarget: NSObject {
  @objc func probeExposed() {}
  func probeNotExposed() {}
  func items() -> [NSMenuItem] {
    [
      NSMenuItem(title: "", action: #selector(probeExposed), keyEquivalent: ""),
      NSMenuItem(title: "", action: #selector(probeNotExposed), keyEquivalent: ""),  // wrong
      NSMenuItem(title: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: ""),
    ]
  }
}
