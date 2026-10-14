import AppKit
import ArborCore
import CoreGraphics

// The core and `TileArt` decide what Arbor's overlays look like; this file only copies their answers
// into AppKit's types and draws them.

extension RGBA {
  var nsColor: NSColor {
    NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
  }
}

extension NSBezierPath {
  static func make(_ elements: [PathElement]) -> NSBezierPath {
    let path = NSBezierPath()
    for element in elements {
      switch element {
      case .move(let point): path.move(to: point)
      case .line(let point): path.line(to: point)
      case .curve(let point, let control1, let control2):
        path.curve(to: point, controlPoint1: control1, controlPoint2: control2)
      case .close: path.close()
      }
    }
    return path
  }
}

extension CGPath {
  static func make(_ elements: [PathElement]) -> CGPath {
    let path = CGMutablePath()
    for element in elements {
      switch element {
      case .move(let point): path.move(to: point)
      case .line(let point): path.addLine(to: point)
      case .curve(let point, let control1, let control2):
        path.addCurve(to: point, control1: control1, control2: control2)
      case .close: path.closeSubpath()
      }
    }
    return path
  }
}

/// Draws a tile. Anything that shows a window's stand-in can use it: make a `TileModel`, then
/// `draw(art(for:in:))` inside a flipped view, or in any flipped graphics context.
@MainActor
enum TileDrawing {
  /// What `model` looks like in `view`: in its light or dark mode, on its display.
  static func art(for model: TileModel, in view: NSView) -> TileArt {
    TileArt(
      model, isDark: view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua,
      scale: view.window?.backingScaleFactor ?? 2, cornerRadius: ContinuousCorners.windowRadius
    ) { AppAppearance.rgba(pid: $0.pid, bundleID: $0.bundleID) }
  }

  /// Draws into the current graphics context, which must be flipped: `TileArt` counts y downward.
  static func draw(_ art: TileArt) {
    draw(art, image: { AppAppearance.icon(pid: $0) })
  }

  /// The same with icons from `image`, which is given a process.
  static func draw(_ art: TileArt, image: (Int32) -> NSImage?) {
    draw(art.plate)
    for cell in art.cells { draw(cell) }
    NSGraphicsContext.current?.imageInterpolation = .high
    for icon in art.icons {
      image(icon.pid)?.draw(
        in: icon.frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }
    if let glyph = art.glyph { draw(glyph) }
    if let caption = art.caption { draw(caption) }
    if let badge = art.badge {
      badge.fill.nsColor.setFill()
      NSBezierPath.make(badge.outline).fill()
      draw(badge.label)
    }
  }

  private static func draw(_ plate: TileArt.Plate) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath.make(plate.outline).addClip()
    NSGradient(starting: plate.top.nsColor, ending: plate.bottom.nsColor)?.draw(
      from: NSPoint(x: plate.frame.midX, y: plate.frame.minY), to: NSPoint(x: plate.frame.midX, y: plate.frame.maxY),
      options: [])
    NSGraphicsContext.restoreGraphicsState()

    let border = NSBezierPath.make(plate.borderOutline)
    border.lineWidth = plate.borderWidth
    plate.border.nsColor.setStroke()
    border.stroke()
  }

  private static func draw(_ glyph: TileArt.Glyph) {
    let configuration = NSImage.SymbolConfiguration(pointSize: glyph.frame.height, weight: .medium)
      .applying(NSImage.SymbolConfiguration(paletteColors: [glyph.colour.nsColor]))
    guard
      let image = NSImage(systemSymbolName: glyph.symbol, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration),
      image.size.width > 0, image.size.height > 0
    else { return }
    // Symbols are not square; fit this one into the frame and centre it.
    let scale = min(glyph.frame.width / image.size.width, glyph.frame.height / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    let frame = NSRect(
      x: glyph.frame.midX - size.width / 2, y: glyph.frame.midY - size.height / 2, width: size.width,
      height: size.height)
    NSGraphicsContext.saveGraphicsState()
    if let shadow = glyph.shadow { softShadow(shadow).set() }
    image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
  }

  private static func draw(_ label: TileArt.Label) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = label.alignment == .centre ? .center : .left
    paragraph.lineBreakMode = .byTruncatingTail
    var attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: label.size, weight: label.isStrong ? .semibold : .medium),
      .foregroundColor: label.colour.nsColor,
      .paragraphStyle: paragraph,
    ]
    if let shadow = label.shadow { attributes[.shadow] = softShadow(shadow) }
    (label.text as NSString).draw(in: label.frame, withAttributes: attributes)
  }

  static func softShadow(_ colour: RGBA) -> NSShadow {
    let shadow = NSShadow()
    shadow.shadowColor = colour.nsColor
    shadow.shadowBlurRadius = 2
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    return shadow
  }
}
