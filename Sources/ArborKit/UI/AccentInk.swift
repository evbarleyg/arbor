import AppKit
import ArborCore
import CoreGraphics

/// How Arbor marks a place on top of other apps' windows: the drop preview, the rectangle of a ⌃⌥-drag, peek's outline.
///
/// The accent colour says "this is yours to act on", as a selection does. But what lies under it is anybody's: on a window, a
/// picture or a wallpaper of about that colour an accent line is not there at all (seen on a hosted Mac: the rectangle
/// over a blue window). So the line has a light one inside it, as the labels of icons on the Desktop have a shadow: one of the two
/// shows on anything.
@MainActor
enum AccentInk {
  /// How strong the light line is. It is a hint of an edge on most things and the whole edge on a few.
  static let lightLine: CGFloat = 0.55

  /// Fills `rect` with the accent colour at `fill`, and draws a line of `width` points in it just inside the edge, with a light
  /// line of one point inside that. `radius` is the outer corners'; 0 leaves them square.
  static func mark(_ rect: NSRect, radius: CGFloat, fill: CGFloat, width: CGFloat) {
    func path(inset: CGFloat) -> NSBezierPath {
      let inner = rect.insetBy(dx: inset, dy: inset)
      return radius > 0 ? NSBezierPath.make(RoundedPath.rect(inner, radius: max(radius - inset, 0))) : NSBezierPath(rect: inner)
    }
    NSColor.controlAccentColor.withAlphaComponent(fill).setFill()
    path(inset: 0).fill()
    // The middle of a line lies half its width inside its outer edge.
    let line = path(inset: width / 2)
    line.lineWidth = width
    NSColor.controlAccentColor.setStroke()
    line.stroke()
    let light = path(inset: width + 0.5)
    light.lineWidth = 1
    NSColor.white.withAlphaComponent(lightLine).setStroke()
    light.stroke()
  }
}
