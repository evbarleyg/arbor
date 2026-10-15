import CoreGraphics

/// How far macOS lets a window grow where it stands.
///
/// A call that sets a window's size makes it grow no further than to two lines of its display, from where it stands at that moment. A
/// call that sets its position is not held back so. Measured call by call on hosted Macs, macOS 26, with a plain test window and
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
  /// free. At the right edge that was seen to the point. Below, a foot at 729 was held and one at 900 free, on a display 768 high, so that it
  /// turns at the display's bottom is a guess. So is the strip of a Dock at the right, by likeness.
  public var end: CGPoint

  public init(frame: CGRect, visibleFrame: CGRect) {
    end = CGPoint(x: frame.maxX, y: frame.maxY)
    right = visibleFrame.maxX - (visibleFrame.maxX < frame.maxX ? 1 : 0)
    bottom = visibleFrame.maxY - (visibleFrame.maxY < frame.maxY ? 1 : 0)
  }

  /// What macOS passes on of a `size` asked of a window that stands at `standing`. Each side by itself. Nobody is made smaller by it, and a
  /// side that is off the display already is free. Its app has its say afterwards.
  public func allows(_ size: CGSize, to standing: CGRect) -> CGSize {
    CGSize(
      width: standing.maxX > end.x ? size.width : min(size.width, max(standing.width, right - standing.minX)),
      height: standing.maxY > end.y ? size.height : min(size.height, max(standing.height, bottom - standing.minY)))
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
