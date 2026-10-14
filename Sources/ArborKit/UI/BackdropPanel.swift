import AppKit
import ArborCore
import CoreGraphics
import QuartzCore

/// The backdrops of all displays (docs/features/F15-appearance-options.md).
@MainActor
final class Backdrops {
  private var panels: [DisplayID: BackdropPanel] = [:]

  func update(display: DisplayID, model: BackdropModel?) {
    guard let model else {
      panels[display]?.hide()
      return
    }
    let panel = panels[display] ?? BackdropPanel()
    panels[display] = panel
    panel.show(model)
  }

  /// What `display` shows now, for whoever covers it for a moment and has to draw the same (`BackdropLayer`).
  func model(on display: DisplayID) -> BackdropModel? { panels[display]?.model }

  func removeAll() {
    panels.values.forEach { $0.close() }
    panels.removeAll()
  }
}

/// The shape that darkens the wallpaper, as a layer. The backdrop's panel hosts one; whatever covers that panel for
/// a moment and has to look the same (a stage, while windows move) can host another.
@MainActor
final class BackdropLayer {
  /// How long one shape takes to fade into the next.
  static let fade: CFTimeInterval = 0.15

  let layer = CAShapeLayer()
  /// The hairline around the Desktop.
  private let edge = CAShapeLayer()
  private var shown: (model: BackdropModel?, frame: CGRect) = (nil, .zero)

  init() {
    edge.fillColor = nil
    layer.addSublayer(edge)
  }

  /// From global coordinates to those of a layer or view that covers `frame` (a rectangle in global coordinates):
  /// origin at its bottom-left corner, y up.
  private static func local(_ outline: [PathElement], in frame: CGRect) -> [PathElement] {
    outline.mapPoints { CGPoint(x: $0.x - frame.minX, y: frame.maxY - $0.y) }
  }

  /// `model`'s outline in the coordinates of a layer or view that covers `frame`.
  static func outline(of model: BackdropModel, in frame: CGRect) -> [PathElement] {
    local(model.outline(slotRadius: ContinuousCorners.windowRadius), in: frame)
  }

  /// Shows `model`'s shape, or nothing, in a layer the size of `frame`. What it showed before fades into it over `fade`
  /// seconds; 0 changes it at once.
  func show(_ model: BackdropModel?, in frame: CGRect, fade: CFTimeInterval) {
    if fade > 0 {
      let transition = CATransition()
      transition.type = .fade
      transition.duration = fade
      layer.add(transition, forKey: "shape")
    } else {
      layer.removeAnimation(forKey: "shape")
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.frame = CGRect(origin: .zero, size: frame.size)
    layer.path = model.map { CGPath.make(Self.outline(of: $0, in: frame)) }
    shown = (model, frame)
    colour()
    drawEdge()
    CATransaction.commit()
  }

  /// Again when the accent colour may have changed.
  func colour() {
    let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB).map {
      RGBA(red: Double($0.redComponent), green: Double($0.greenComponent), blue: Double($0.blueComponent))
    }
    layer.fillColor = shown.model?.fill(accent: accent ?? .black).nsColor.cgColor
  }

  /// One pixel wide, so it depends on the scale.
  private func drawEdge() {
    let width = 1 / max(layer.contentsScale, 1)
    edge.frame = layer.bounds
    edge.path = shown.model?.desktopOutline(width: width, radius: ContinuousCorners.windowRadius).map {
      CGPath.make(Self.local($0, in: shown.frame))
    }
    edge.lineWidth = width
    // White, like the border of the Desktop's tile: what is behind it has nothing to do with light or dark mode.
    edge.strokeColor = CGColor(gray: 1, alpha: CGFloat(shown.model?.desktopEdge ?? 0))
  }

  /// AppKit looks after the scale of its own layers only, and at the wrong one the curves are coarse.
  func match(scale: CGFloat) {
    guard scale != layer.contentsScale else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.contentsScale = scale
    edge.contentsScale = scale
    drawEdge()
    CATransaction.commit()
  }
}

/// Hosts the shape: a layer tree of Arbor's own, because a shape costs no bitmap the size of the display.
private final class DimView: NSView {
  let surface = BackdropLayer()

  /// Call once. Setting the layer before asking for one is what makes the view host it instead of owning it.
  func hostSurface() {
    layer = CALayer()
    wantsLayer = true
    layer?.addSublayer(surface.layer)
  }

  /// When the panel moves to another display, or its display changes resolution.
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    matchScale()
  }

  func matchScale() {
    if let scale = window?.backingScaleFactor { surface.match(scale: scale) }
  }

  /// Also when another accent colour is chosen in System Settings.
  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    surface.colour()
  }
}

/// Darkens and blurs the wallpaper behind one display's docked windows. The panel covers the display's
/// visible frame just above the Desktop's icons, under every app's windows, and the mouse goes
/// straight through it.
final class BackdropPanel: OverlayPanel {
  private let dimView = DimView()
  private var blurView: NSVisualEffectView?
  private(set) var model: BackdropModel?
  private var lastChange: CFTimeInterval = 0

  override init() {
    super.init()
    level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    ignoresMouseEvents = true
    // Transient: Mission Control and a click on the wallpaper, which sweep the windows away, hide it with them;
    // a stationary panel would stay behind as a dark shape with nothing on it. On every Space, because the
    // scene follows the Space in view and a panel stays on the Space it was first shown on.
    collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
    dimView.hostSurface()
    let content = NSView()
    content.addSubview(dimView)
    contentView = content
  }

  func show(_ model: BackdropModel) {
    guard model != self.model else { return }
    self.model = model
    setFrame(ScreenGeometry.appKit(fromGlobal: model.frame), display: false)
    dimView.frame = NSRect(origin: .zero, size: model.frame.size)
    dimView.surface.show(model, in: model.frame, fade: fade())
    setBlur(model.blur, outline: BackdropLayer.outline(of: model, in: model.frame), size: model.frame.size)
    if !isVisible { orderFrontRegardless() }
    // Only now is the panel sure to know which display it is on.
    dimView.matchScale()
  }

  /// Fades the backdrop out, then takes the panel off screen.
  func hide() {
    guard let model else { return }
    self.model = nil
    dimView.surface.show(nil, in: model.frame, fade: fade())
    setBlur(0, outline: [], size: model.frame.size)
    DispatchQueue.main.asyncAfter(deadline: .now() + (BackdropLayer.fade + 0.05)) { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.model == nil else { return }  // Shown again in the meantime.
        self.orderOut(nil)
      }
    }
  }

  /// One shape cross-fades into the next instead of popping. A drag changes the shape many times a second, though, and
  /// fading every step would smear its edge behind the pointer.
  private func fade() -> CFTimeInterval {
    let now = CACurrentMediaTime()
    defer { lastChange = now }
    return now - lastChange > BackdropLayer.fade ? BackdropLayer.fade : 0
  }

  /// The blur exists only while it is wanted: without one the panel is a single flat shape.
  private func setBlur(_ blur: Double, outline: [PathElement], size: CGSize) {
    guard blur > 0, let content = contentView else {
      blurView?.removeFromSuperview()
      blurView = nil
      return
    }
    let view = blurView ?? makeBlurView(in: content)
    blurView = view
    view.frame = NSRect(origin: .zero, size: size)
    // macOS blurs behind a window by a fixed amount; less than all of it is that blur, faded.
    view.alphaValue = CGFloat(blur)
    // A layer mask does not reach what the window server blurs behind the window; a mask image does.
    // AppKit may draw an image on any thread, so the closure must not inherit this method's main actor.
    let drawMask: @Sendable (NSRect) -> Bool = { _ in
      NSColor.black.setFill()
      NSBezierPath.make(outline).fill()
      return true
    }
    view.maskImage = NSImage(size: size, flipped: false, drawingHandler: drawMask)
  }

  private func makeBlurView(in content: NSView) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.blendingMode = .behindWindow
    view.material = .underWindowBackground
    view.state = .active  // The panel is never key, and an inactive effect view turns flat grey.
    view.autoresizingMask = [.width, .height]
    content.addSubview(view, positioned: .below, relativeTo: nil)
    return view
  }
}
