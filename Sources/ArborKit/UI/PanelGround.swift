import AppKit
import ArborCore
import CoreGraphics

/// What Arbor's panels stand on: one of macOS's materials cut to rounded corners, a veil over it so that words can be
/// read whatever lies behind the panel, and a hairline round it. The line on screen, the panel of shortcuts, the
/// minimap, the field for a name and Go to… all stand on one. The numbers are `PanelLook`'s.
final class PanelGround: NSVisualEffectView {
  private let veil = PanelVeilView()
  private let outline = PanelOutlineView()

  /// The corners'. The line on screen changes it with its height.
  var radius: CGFloat = PanelLook.Corner.panel {
    didSet {
      guard radius != oldValue else { return }
      maskImage = Self.mask(radius: radius)
      veil.radius = radius
      outline.radius = radius
    }
  }

  /// The one way to make one. A designated initializer, so that none is inherited: as a convenience with every argument
  /// defaulted, `PanelGround()` would quietly be `NSView.init()`, and a panel without material, mask, veil or line.
  ///
  /// `drawsOutline` false: what stands on it draws the line itself (`PanelOutlineView.draw`).
  init(material: NSVisualEffectView.Material = .hudWindow, drawsOutline: Bool = true) {
    super.init(frame: .zero)
    self.material = material
    blendingMode = .behindWindow
    state = .active  // The app is never active, and an inactive effect view turns flat grey.
    maskImage = Self.mask(radius: radius)
    for view in drawsOutline ? [veil, outline] : [veil] {
      view.frame = bounds
      view.autoresizingMask = [.width, .height]
      addSubview(view)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("Arbor has no nibs") }

  /// The line lies over whatever the panel holds: a row that is selected reaches to the edge.
  override func didAddSubview(_ subview: NSView) {
    super.didAddSubview(subview)
    if subview !== outline, outline.superview === self { addSubview(outline, positioned: .above, relativeTo: nil) }
  }

  /// A layer's corner radius does not reach what the window server blurs behind the window; a mask image does. The
  /// corners keep their size and the middle stretches.
  private static func mask(radius: CGFloat) -> NSImage {
    // AppKit may draw an image on any thread, so the closure must not inherit the main actor.
    let draw: @Sendable (NSRect) -> Bool = { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
      return true
    }
    let side = radius * 2 + 1
    let image = NSImage(size: NSSize(width: side, height: side), flipped: false, drawingHandler: draw)
    image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
    image.resizingMode = .stretch
    return image
  }
}

/// `PanelLook.veil`. The mask cuts the material and nothing that lies on it, so this has corners of its own.
final class PanelVeilView: NSView {
  var radius: CGFloat = PanelLook.Corner.panel {
    didSet { needsDisplay = true }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    PanelLook.veil(isDark: effectiveAppearance.isDark).nsColor.setFill()
    NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
  }
}

/// The line round a panel: what macOS gives its own menus and popovers, and a borderless panel has to draw for
/// itself. It keeps the panel's shape over a window of the same brightness, where the shadow alone does not (seen on
/// a hosted Mac: the light panel over a light wallpaper). It takes no clicks.
final class PanelOutlineView: NSView {
  var radius: CGFloat = PanelLook.Corner.panel {
    didSet { needsDisplay = true }
  }

  override func hitTest(_ point: NSPoint) -> NSView? { nil }

  override func draw(_ dirtyRect: NSRect) {
    Self.draw(in: bounds, radius: radius, increasesContrast: effectiveAppearance.increasesContrast)
  }

  /// One point wide, just inside `bounds`, in the current appearance's colours. Nothing with Increase Contrast: macOS
  /// itself then draws a full line round every window that has a shadow (seen on a hosted Mac), and a second one
  /// inside it is one too many.
  static func draw(in bounds: NSRect, radius: CGFloat, increasesContrast: Bool) {
    guard !increasesContrast, bounds.width > 1, bounds.height > 1 else { return }
    let line = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius - 0.5, yRadius: radius - 0.5)
    line.lineWidth = 1
    NSColor.separatorColor.setStroke()
    line.stroke()
  }
}

/// `PanelLook.ink` as colours that follow the appearance they are drawn in, whenever they were made.
@MainActor
enum PanelInk {
  static let main = colour(.main)
  static let second = colour(.second)

  static func colour(_ ink: PanelLook.Ink) -> NSColor {
    NSColor(name: nil) { appearance in
      PanelLook.ink(ink, isDark: appearance.isDark, increasesContrast: appearance.increasesContrast).nsColor
    }
  }

  /// What a selected row is filled with, and the ink on it. macOS's own colour for a selected row in a list that has the
  /// keyboard, which follows the accent colour and is darker than it: white on the accent itself is 4 to 1 at best.
  /// To be asked while drawing.
  static func selection() -> (fill: NSColor, ink: NSColor) {
    let fill = NSColor.selectedContentBackgroundColor
    guard let plain = fill.usingColorSpace(.sRGB) else { return (fill, .alternateSelectedControlTextColor) }
    let colour = RGBA(red: plain.redComponent, green: plain.greenComponent, blue: plain.blueComponent)
    return (fill, PanelLook.ink(onSelection: colour).nsColor)
  }
}
