import AppKit
import ArborCore
import CoreGraphics
import Foundation

/// Draws the minimaps (`MinimapModel`, docs/features/F26-minimap.md): one panel per display, made when first needed and kept, because
/// making a panel costs more than a move of the view should.
@MainActor
final class Minimaps {
  private var panels: [DisplayID: MinimapPanel] = [:]
  /// A click in a minimap that takes clicks, in the panel's coordinates (origin top-left, y down).
  var onClick: ((DisplayID, CGPoint) -> Void)?

  func show(_ model: MinimapModel?, on display: DisplayID) {
    guard let model else {
      panels[display]?.disappear()
      return
    }
    let panel = panels[display] ?? MinimapPanel()
    panels[display] = panel
    panel.onClick = { [weak self] point in self?.onClick?(display, point) }
    panel.show(model)
  }

  func removeAll() {
    panels.values.forEach { $0.close() }
    panels.removeAll()
  }
}

/// A heads-up panel that fades in, shows a `MinimapModel` and fades out. It decides nothing: where it goes, what it holds, whether
/// it takes clicks and when it comes and goes are the controller's business.
///
/// The look is the one agreed with the heads-up line (F43): a translucent background (`PanelGround`), 0.1 s in, 0.25 s out, at once
/// with "Reduce motion". Once that line's `PassingPanel` is on the trunk this class should be one, and lose everything from
/// `animates` down.
final class MinimapPanel: OverlayPanel {
  static let fadeIn: TimeInterval = 0.1
  static let fadeOut: TimeInterval = 0.25

  private let background = PanelGround()
  private let mapView = MinimapView()
  /// Whether the panel is meant to be seen. It stays on screen a little longer, while it fades out.
  private var isWanted = false

  var onClick: ((CGPoint) -> Void)? {
    get { mapView.onClick }
    set { mapView.onClick = newValue }
  }

  override init() {
    super.init()
    // Above the stage that covers a display while windows move (F02, just below `.floating`): the minimap says where they went.
    level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
    hasShadow = true
    // Transient: hidden in Mission Control. Not `.fullScreenAuxiliary`: another app's full-screen Space is none of Arbor's business.
    collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    ignoresMouseEvents = true
    // It only informs the person at the Mac, and says which other apps are open: not for an audience. macOS decides how far this
    // is honoured. The pictures of scripts/mac-shell/shots-minimap.sh need to see it.
    sharingType = ProcessInfo.processInfo.environment["ARBOR_PANELS_IN_PICTURES"] == "1" ? .readOnly : .none
    contentView = background
    mapView.frame = background.bounds
    mapView.autoresizingMask = [.width, .height]
    background.addSubview(mapView)
    // For pictures of both looks without touching the Mac's own setting (scripts/mac-shell/shots-minimap.sh).
    switch ProcessInfo.processInfo.environment["ARBOR_APPEARANCE"] {
    case "dark": appearance = NSAppearance(named: .darkAqua)
    case "light": appearance = NSAppearance(named: .aqua)
    default: break
    }
  }

  func show(_ model: MinimapModel) {
    // Said either way: the window server lets clicks fall through where a window has not said that it wants them.
    ignoresMouseEvents = !model.takesClicks
    let target = ScreenGeometry.appKit(fromGlobal: model.frame)
    if target != frame {
      setFrame(target, display: false)
      invalidateShadow()
    }
    mapView.model = model
    appear()
  }

  private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  /// Fades in, or carries on showing. With "Reduce motion" on it only appears.
  private func appear() {
    isWanted = true
    if !isVisible {
      alphaValue = animates ? 0 : 1
      orderFrontRegardless()
    }
    // Through the animator even when there is nothing to fade, so that it replaces a fade-out under way.
    NSAnimationContext.runAnimationGroup { context in
      context.duration = animates ? Self.fadeIn : 0
      animator().alphaValue = 1
    }
  }

  /// Fades out. A panel on its way out takes no more clicks.
  func disappear() {
    guard isWanted else { return }
    isWanted = false
    ignoresMouseEvents = true
    guard animates else {
      orderOut(nil)
      return
    }
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = Self.fadeOut
        animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          // Unless it was asked for again while it faded.
          guard let self, !self.isWanted else { return }
          self.orderOut(nil)
        }
      })
  }
}

private final class MinimapView: NSView {
  var model: MinimapModel? {
    didSet { if model != oldValue { needsDisplay = true } }
  }
  var onClick: ((CGPoint) -> Void)?

  /// The model's rectangles have their origin at the panel's top-left corner, y down. The view fills the panel.
  override var isFlipped: Bool { true }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseUp(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    // The view that got the press gets the release wherever it happens. Let go elsewhere, it was a change of mind.
    if bounds.contains(point) { onClick?(point) }
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let model else { return }
    MinimapDrawing.draw(model, accent: .controlAccentColor, ink: PanelInk.main) {
      AppAppearance.colour(pid: $0.pid, bundleID: $0.bundleID)
    }
  }
}

/// Draws a `MinimapModel` into the current graphics context, whose origin is the panel's top-left corner, y down. Apart from the view so
/// that a test can have the real thing drawn into a bitmap, in colours it knows, and look at it (MinimapDrawingTests).
@MainActor
enum MinimapDrawing {
  /// What is out of view is still there, only fainter.
  static let outOfViewAlpha: CGFloat = 0.45
  static let outOfViewEdgeAlpha: CGFloat = 0.3
  static let highlightFillAlpha: CGFloat = 0.12

  /// `accent` frames the space in view, `ink` is for the Desktop's outline, the outline under the pointer and the caption, and
  /// `colour` gives each window its app's.
  static func draw(_ model: MinimapModel, accent: NSColor, ink: NSColor, colour: (MinimapModel.Item) -> NSColor) {
    if let desktop = model.desktop {
      let outline = NSBezierPath(roundedRect: desktop.insetBy(dx: 0.5, dy: 0.5), xRadius: 2.5, yRadius: 2.5)
      ink.withAlphaComponent(model.desktopIsInView ? 0.6 : 0.3).setStroke()
      outline.lineWidth = 1
      outline.stroke()
    }

    for item in model.items {
      colour(item).withAlphaComponent(item.isInView ? 1 : outOfViewAlpha).setFill()
      NSBezierPath(roundedRect: item.frame, xRadius: 2.5, yRadius: 2.5).fill()
      // Fainter must not mean gone: a dark app's window out of view merged with a dark ground (seen on a hosted Mac).
      guard !item.isInView, item.frame.width > 2, item.frame.height > 2 else { continue }
      let edge = NSBezierPath(roundedRect: item.frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
      ink.withAlphaComponent(outOfViewEdgeAlpha).setStroke()
      edge.lineWidth = 1
      edge.stroke()
    }

    // Around the space rather than on it, so that a small window's colour still shows.
    let highlight = NSBezierPath(roundedRect: model.highlight.insetBy(dx: -2, dy: -2), xRadius: 4.5, yRadius: 4.5)
    accent.withAlphaComponent(highlightFillAlpha).setFill()
    highlight.fill()
    accent.setStroke()
    highlight.lineWidth = 2
    highlight.stroke()

    if let hover = model.hover {
      let outline = NSBezierPath(roundedRect: hover.insetBy(dx: -0.5, dy: -0.5), xRadius: 3, yRadius: 3)
      ink.setStroke()
      outline.lineWidth = 1.5
      outline.stroke()
    }

    if let caption = model.caption {
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byTruncatingTail
      (caption as NSString).draw(
        in: model.captionFrame,
        withAttributes: [
          .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: ink, .paragraphStyle: paragraph,
        ])
    }
  }
}
