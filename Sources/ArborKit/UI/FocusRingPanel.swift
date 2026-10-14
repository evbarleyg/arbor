import AppKit
import ArborCore
import CoreGraphics
import QuartzCore

/// Draws the focus ring (`FocusRingModel`): one panel per display, of which at most one shows.
@MainActor
final class FocusRings {
  private var panels: [DisplayID: FocusRingPanel] = [:]
  /// The pulse last drawn, on whichever display. The controller's count starts at 0 too.
  private var lastPulse = 0
  private var mouseMonitor: Any?

  func update(display: DisplayID, model: FocusRingModel?) {
    guard let model else {
      panels[display]?.orderOut(nil)
      return
    }
    let panel = panels[display] ?? FocusRingPanel()
    panels[display] = panel
    panel.show(model, flashing: model.pulse != lastPulse)
    lastPulse = model.pulse
    restackSoon()
    watchMouse()
  }

  func removeAll() {
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    panels.values.forEach { $0.close() }
    panels.removeAll()
    lastPulse = 0
  }

  /// A clicked window takes the keyboard first and comes to the front afterwards, leaving a ring that was put
  /// above it where it used to be, under other windows and their shadows. Nothing reports a change of
  /// stacking, so the ring is put above its window again when the button comes up, and a moment after
  /// that and after every change, for apps that take their time.
  private func watchMouse() {
    guard mouseMonitor == nil else { return }
    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.restack()
        self?.restackSoon()
      }
    }
  }

  private func restack() {
    panels.values.forEach { $0.restack() }
  }

  private func restackSoon() {
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 150_000_000)
      self?.restack()
    }
  }
}

/// A line around another app's window. The panel spans the whole window, lets every click through, and is
/// empty but for the line.
///
/// It sits at the normal level, directly above the window it surrounds, as if it were part of it:
/// whatever is above that window (another app's floating panel, a picture-in-picture video, the window's own
/// popovers, the stage that covers the display while windows move) is above the ring as well. At the
/// floating level the line would cut across all of those.
final class FocusRingPanel: OverlayPanel {
  private let line = CAShapeLayer()
  private let flash = CAShapeLayer()
  private var ringedWindow: WindowID?

  override init() {
    super.init()
    level = .normal
    ignoresMouseEvents = true
    // On every Space, because the keyboard can go from a window on one Space straight to a window on
    // another, and a panel stays on the Space it was first shown on. Transient: Mission Control hides it.
    collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    let view = NSView()
    view.layer = CALayer()
    view.wantsLayer = true
    for layer in [flash, line] {
      // Each is the area between two rounded rectangles.
      layer.fillRule = .evenOdd
      view.layer?.addSublayer(layer)
    }
    flash.opacity = 0
    contentView = view
  }

  func show(_ model: FocusRingModel, flashing: Bool) {
    // Room for the flash.
    let area = model.outerFrame.insetBy(dx: -model.flashReach, dy: -model.flashReach)
    let target = ScreenGeometry.appKit(fromGlobal: area)
    let scale = NSScreen.screens.first { $0.frame.overlaps(target) }?.backingScaleFactor ?? backingScaleFactor
    let colour = Self.cgColour(model.colour)
    let radius = ContinuousCorners.windowRadius

    setFrame(target, display: false)
    // The ring has to be where the window is, at once: layers would otherwise glide to their new shape.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for (layer, band) in [
      (line, model.band(automaticRadius: radius)),
      (flash, model.band(reaching: model.flashReach, automaticRadius: radius)),
    ] {
      // Layers count y upwards from the panel's bottom edge.
      let outer = CGRect(
        x: band.frame.minX - area.minX, y: area.maxY - band.frame.maxY, width: band.frame.width,
        height: band.frame.height)
      let path = CGMutablePath()
      path.addPath(ContinuousCorners.path(outer, radius: band.cornerRadius))
      path.addPath(
        ContinuousCorners.path(outer.insetBy(dx: band.thickness, dy: band.thickness), radius: band.innerRadius))
      layer.frame = CGRect(origin: .zero, size: area.size)
      layer.contentsScale = scale
      layer.path = path
      layer.fillColor = colour
    }
    CATransaction.commit()

    ringedWindow = model.window
    // Not `restack()`: this also brings a hidden panel back.
    order(.above, relativeTo: Int(model.window.rawValue))

    if flashing, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      let fade = CABasicAnimation(keyPath: "opacity")
      fade.fromValue = 1.0
      fade.toValue = 0.0
      fade.duration = FocusRingModel.pulseDuration
      fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
      flash.add(fade, forKey: "flash")
    }
  }

  /// Puts the panel directly above its window again. Window numbers are the window server's, so another
  /// app's number works.
  func restack() {
    guard isVisible, let ringedWindow else { return }
    order(.above, relativeTo: Int(ringedWindow.rawValue))
  }

  private static func cgColour(_ colour: FocusRingColour) -> CGColor {
    switch colour {
    case .accent:
      return NSColor.controlAccentColor.cgColor
    case .rgba(let red, let green, let blue, let alpha):
      return CGColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
  }
}
