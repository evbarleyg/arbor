import CoreGraphics

/// How far macOS lets a window grow where it stands, and how far it lets one shrink that hangs off its display.
///
/// A call that sets a window's size makes it grow no further than to two lines of its display, from where it stands at that moment, and puts no
/// edge into the Dock's strip. A call that sets its position is not held back so. Measured call by call on hosted Macs, macOS 26, with a plain test window and
/// with real apps alike (`collab/reality.json`: a-window-asked-to-grow-stops-at-the-dock). Arbor reckons with it, and the stand-ins play it.
///
/// Which display that is, of a window that lies astride two, is for whoever asks. Arbor and the fake go by the window's corner; the one
/// sighting there is says the larger part. On one display it makes no difference.
public struct ScreenLines: Equatable, Sendable {
  /// How far to the right growth goes: all the way to the display's edge; a point short of the visible frame's with the Dock at the right.
  public var right: CGFloat
  /// How far down growth goes: a point short of the visible frame's bottom above a Dock; with the Dock at a side or hidden all the way to the
  /// display's bottom.
  public var bottom: CGFloat
  /// The display's right edge and its bottom. Between a line and these, in the Dock's strip, a window's edge is held as it is; past them it is
  /// free to go further out. At the right edge that was seen to the point. Below, a foot at 729 was held and one at 900 free, on a display
  /// 768 high; then at 768 held and at 769 free. The strip of a Dock at the right does as the one below.
  public var end: CGPoint

  public init(frame: CGRect, visibleFrame: CGRect) {
    end = CGPoint(x: frame.maxX, y: frame.maxY)
    right = visibleFrame.maxX - (visibleFrame.maxX < frame.maxX ? 1 : 0)
    bottom = visibleFrame.maxY - (visibleFrame.maxY < frame.maxY ? 1 : 0)
  }

  /// What macOS passes on of a `size` asked of a window that stands at `standing`. Each side by itself. Its app has its say afterwards.
  public func allows(_ size: CGSize, to standing: CGRect) -> CGSize {
    CGSize(
      width: Self.allows(size.width, from: standing.minX, has: standing.width, line: right, end: end.x),
      height: Self.allows(size.height, from: standing.minY, has: standing.height, line: bottom, end: end.y))
  }

  /// One side, which begins at `start` and is `has` long.
  ///
  /// A size call leaves no edge inside the Dock's strip. 150 bare calls on a hosted Mac, a test window and a real editor, the Dock below and at the
  /// right, each ask 6 times of 6 (`collab/reality.json`: no-size-call-leaves-an-edge-in-the-docks-strip); and Arbor's own requests before them.
  /// - Its edge on the screen: it grows as far as the line, and shrinks as it is asked to.
  /// - Its edge off the display, by a point or more: free, outwards, and inwards right across the strip. Asked to end IN the strip it comes in no
  ///   further than the display's edge, so it is LONGER than asked: 650 high at y 408 of 768, asked to be 348, it became 360.
  /// - Its edge in the strip, or on the display's very edge: held, for more, and for less that would still end in the strip. Asked to end on the
  ///   screen it does.
  /// Not seen: an edge that comes in and is asked exactly to the visible frame's. That counts as on the screen, as it did before anybody looked: slots
  /// without a gap end there, and so does what is fitted onto the screen.
  private static func allows(_ asked: CGFloat, from start: CGFloat, has: CGFloat, line: CGFloat, end: CGFloat) -> CGFloat {
    let (edge, wanted) = (start + has, start + asked)
    // The line that stops growth lies a point short of the visible frame's edge, where the strip begins.
    let endsInTheStrip = line < end && wanted > line + 1 && wanted <= end
    if edge > end { return endsInTheStrip ? end - start : asked }
    if edge > line { return wanted > edge || endsInTheStrip ? has : asked }
    return min(asked, max(has, line - start))
  }

  /// What a window that stands at `standing` has of `target`'s size after the calls one request is made of (`FramePlan.steps`), if its app takes
  /// whatever it is passed. Into a frame that hangs over an edge that is size, position, size: what the first call gives it, it takes along,
  /// and may with that be off the display where it is going, and free. `rooms` as for `FramePlan.steps`; `lines`: those of the display that
  /// judges a window with its corner there.
  public static func sizeAfterOneRequest(
    for target: CGRect, from standing: CGRect, rooms: [CGRect], lines: (CGPoint) -> ScreenLines?
  ) -> CGSize {
    var isAt = standing
    for step in FramePlan.steps(from: standing, to: target, rooms: rooms) {
      switch step {
      case .position(let origin): isAt.origin = origin
      case .size(let size): isAt.size = lines(isAt.origin)?.allows(size, to: isAt) ?? size
      }
    }
    return isAt.size
  }
}
