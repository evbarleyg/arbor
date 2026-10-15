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
/// With Increase Contrast macOS makes the accent colour darker in the light look and lighter in the dark one, and either way
/// there are grounds it does not stand out from: 1.1 to 2.3 to 1 on the darkened wallpaper behind docked windows, and with
/// a white second line still 2.8 over a bright window (measured on pictures from a hosted Mac). Two tones cannot stand out by
/// three to one from every ground; white and black together can, by 4.5 at the least. So with the setting on there are
/// three lines, **from the outside in: a point of black, a point of white, then the accent**, here and round the focused
/// window: a dark rim with a light line inside it is what macOS itself gives its windows then. The mark is no wider for it.
@MainActor
enum AccentInk {
  /// Fills `rect` with `accent` at `fill`, and draws a line of `width` points in it just inside the edge, with the second
  /// line, one point wide, inside that. With Increase Contrast the same `width + 1` points are black, white and, if any are
  /// left, the accent. `radius` is the outer corners'; 0 leaves them square.
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
    /// What lies between two insets. Not a stroke: two curves of macOS's kind with different radii do not run side by side, and a
    /// line stroked beside another parted from it in every bend (seen). Each line begins where the one before it ends.
    func band(from outer: CGFloat, to inner: CGFloat, _ colour: NSColor) {
      guard let shape = path(inset: outer) else { return }
      if let hole = path(inset: inner) { shape.append(hole) }
      shape.windingRule = .evenOdd
      colour.setFill()
      shape.fill()
    }
    accent.withAlphaComponent(fill).setFill()
    path(inset: 0)?.fill()
    guard increasesContrast else {
      band(from: 0, to: width, accent)
      band(from: width, to: width + 1, secondLine(inside: accent))
      return
    }
    // All three are opaque, so each reaches in as far as the last and is painted over by the next: where two only met, a
    // quarter of what lies under the mark would show through the soft edge they share.
    let end = width + 1
    for (place, colour) in (strongLines + [accent]).enumerated() where CGFloat(place) < end {
      band(from: CGFloat(place), to: end, colour)
    }
  }

  /// With Increase Contrast: the lines outside the accent's, each a point wide, from the outside in.
  static let strongLines: [NSColor] = PanelLook.strongLines.map(\.nsColor)

  /// A hint of an edge on most things, and the whole edge on a few.
  static func secondLine(inside accent: NSColor) -> NSColor {
    guard let colour = accent.usingColorSpace(.sRGB) else { return NSColor.white.withAlphaComponent(0.55) }
    let brightness = 0.2126 * colour.redComponent + 0.7152 * colour.greenComponent + 0.0722 * colour.blueComponent
    return brightness > 0.6 ? NSColor.black.withAlphaComponent(0.45) : NSColor.white.withAlphaComponent(0.55)
  }
}
