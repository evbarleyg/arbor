import AppKit
import ArborCore
import CoreGraphics

/// How Arbor marks a place on top of other apps' windows: the drop preview, the rectangle of a ⌃⌥-drag, peek's outline.
///
/// The accent colour says "this is yours to act on", as a selection does. But what lies under it is anybody's: on a
/// window, a picture or a wallpaper of about that colour an accent line is not there at all (seen on a hosted Mac:
/// the rectangle over a blue window). So the line has a second one inside it, light inside a dark accent and dark
/// inside a light one, as the labels of icons on the Desktop have a shadow: one of the two shows on anything.
///
/// With Increase Contrast macOS makes the accent colour darker, and on the darkened wallpaper behind docked windows it stood
/// out less than before: 1.1 to 2.3 to 1 (measured on pictures from a hosted Mac). The second line is then as strong as a
/// line can be.
@MainActor
enum AccentInk {
  /// Fills `rect` with `accent` at `fill`, and draws a line of `width` points in it just inside the edge, with the second
  /// line, one point wide, inside that. `radius` is the outer corners'; 0 leaves them square.
  static func mark(
    _ rect: NSRect, radius: CGFloat, fill: CGFloat, width: CGFloat, accent: NSColor = .controlAccentColor,
    increasesContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
  ) {
    /// Nil where so far in there is nothing left: the rectangle of a drag begins a point high.
    func path(inset: CGFloat) -> NSBezierPath? {
      let inner = rect.insetBy(dx: inset, dy: inset)
      guard !inner.isNull, inner.width > 0, inner.height > 0 else { return nil }
      return radius > 0
        ? NSBezierPath.make(RoundedPath.rect(inner, radius: max(radius - inset, 0))) : NSBezierPath(rect: inner)
    }
    accent.withAlphaComponent(fill).setFill()
    path(inset: 0)?.fill()
    // The middle of a line lies half its width inside its outer edge.
    if let line = path(inset: width / 2) {
      line.lineWidth = width
      accent.setStroke()
      line.stroke()
    }
    if let second = path(inset: width + 0.5) {
      second.lineWidth = 1
      secondLine(inside: accent, increasesContrast: increasesContrast).setStroke()
      second.stroke()
    }
  }

  /// A hint of an edge on most things, and the whole edge on a few. With Increase Contrast a line in its own right.
  static func secondLine(inside accent: NSColor, increasesContrast: Bool = false) -> NSColor {
    guard let colour = accent.usingColorSpace(.sRGB) else {
      return NSColor.white.withAlphaComponent(increasesContrast ? 1 : 0.55)
    }
    let brightness = 0.2126 * colour.redComponent + 0.7152 * colour.greenComponent + 0.0722 * colour.blueComponent
    return brightness > 0.6
      ? NSColor.black.withAlphaComponent(increasesContrast ? 1 : 0.45)
      : NSColor.white.withAlphaComponent(increasesContrast ? 1 : 0.55)
  }
}
