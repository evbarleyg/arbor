import ArborCore
import CoreGraphics

/// The line Arbor draws around the window that has the keyboard, so that someone who moves between windows
/// with the keyboard always sees where typing will go. Part of `OverlayScene`; filled in by
/// `Controller+FocusRing.swift`, drawn by `FocusRingPanel`.
public struct FocusRingModel: Equatable, Sendable {
  /// The window that has the keyboard. The ring is stacked directly above it.
  public var window: WindowID
  /// That window's frame, in global coordinates.
  public var frame: CGRect
  /// The outer edge of the line: around `frame` where there is room, see `FocusRingGeometry`.
  public var outerFrame: CGRect
  /// The line's thickness.
  public var width: CGFloat
  /// The radius of the window's own corners, or 0 to let the view pick the one its macOS gives windows.
  public var radius: CGFloat
  public var colour: FocusRingColour
  /// Changes when the ring should flash, because Arbor rather than a click moved the keyboard and
  /// the eye has to find it. The value means nothing beyond being different.
  public var pulse: Int

  public init(
    window: WindowID, frame: CGRect, outerFrame: CGRect, width: CGFloat, radius: CGFloat,
    colour: FocusRingColour, pulse: Int
  ) {
    self.window = window
    self.frame = frame
    self.outerFrame = outerFrame
    self.width = width
    self.radius = radius
    self.colour = colour
    self.pulse = pulse
  }

  /// How long a flash takes to fade, in seconds.
  public static let pulseDuration = 0.25

  /// How far beyond the line's outer edge a flash reaches.
  public var flashReach: CGFloat { 2 * width }

  /// A rounded frame to paint: `thickness` points inwards from the edge of `frame`.
  public struct Band: Equatable, Sendable {
    public var frame: CGRect
    /// The radius of `frame`'s corners.
    public var cornerRadius: CGFloat
    public var thickness: CGFloat
    /// The radius of the corners of the band's inner edge.
    public var innerRadius: CGFloat { max(cornerRadius - thickness, 0) }
  }

  /// The band from the line's inner edge to `reach` points beyond its outer edge: 0 is the line itself,
  /// `flashReach` the flash. Growing outwards only keeps a flash off the window's content. The corners run
  /// parallel to the window's own, and the radius never exceeds half a side.
  public func band(reaching reach: CGFloat = 0, automaticRadius: CGFloat) -> Band {
    let frame = outerFrame.insetBy(dx: -reach, dy: -reach)
    let outset = max(
      self.frame.minX - outerFrame.minX, outerFrame.maxX - self.frame.maxX, self.frame.minY - outerFrame.minY,
      outerFrame.maxY - self.frame.maxY)
    let innerRadius = max((radius > 0 ? radius : automaticRadius) + outset - width, 0)
    let thickness = width + reach
    return Band(
      frame: frame, cornerRadius: min(innerRadius + thickness, frame.width / 2, frame.height / 2),
      thickness: thickness)
  }
}
