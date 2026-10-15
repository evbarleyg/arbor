import CoreGraphics

/// What a press of the mouse button followed by movement is doing to the window under the pointer
/// (F17, H1 and H5). The Accessibility layer records where the button went down and the frame the
/// window had then, looks at the window's frame again as the pointer moves, and asks here.
public enum WindowGrab {
  public enum Verdict: Equatable, Sendable {
    /// Nothing has happened to the window yet; look again.
    case undecided
    /// The window is being dragged by its title bar.
    case drag
    /// The window is being resized by its edges.
    case resize
    /// The press is not about the window (a text selection, a slider): stop looking.
    case neither
  }

  /// How close to a window's border a press must be to count as taking hold of an edge. macOS's own
  /// resize area reaches a few points to either side of the border.
  public static let edgeMargin: CGFloat = 10
  /// How far the pointer may travel with the window standing still before the press is taken to be
  /// about the window's content. A window follows a drag from the first few points.
  public static let patience: CGFloat = 24
  /// How much farther than the pointer a window in the hand may seem to have gone, and how far apart the window
  /// server and Accessibility may have a window that is at rest: they are read a moment apart.
  public static let lead: CGFloat = 32

  /// Whether the window server lists a window somewhere else than its app has it. That is macOS showing its desktop
  /// (`SweptAside`): what is under the pointer is a picture of the window, and a press on it brings the window back,
  /// with the button still down. Such a press takes hold of nothing.
  /// - Parameters:
  ///   - listed: the window's frame by the window server, as the button goes down.
  ///   - believed: what Accessibility last said.
  public static func isListedElsewhere(_ listed: CGRect, than believed: CGRect) -> Bool {
    let x = listed.minX - believed.minX
    let y = listed.minY - believed.minY
    return (x * x + y * y).squareRoot() > lead
  }

  /// Whether `point` is within `margin` points of the border of `frame`, inside or outside.
  public static func isNearEdge(_ point: CGPoint, of frame: CGRect, margin: CGFloat = edgeMargin) -> Bool {
    frame.insetBy(dx: -margin, dy: -margin).contains(point)
      && !frame.insetBy(dx: Swift.min(margin, frame.width / 2), dy: Swift.min(margin, frame.height / 2)).contains(point)
  }

  /// - Parameters:
  ///   - pressedAt: where the button went down.
  ///   - frameAtPress: the window's frame at that moment.
  ///   - frameNow: its frame now, with the button still down.
  ///   - pointerNow: where the pointer is now.
  public static func classify(
    pressedAt: CGPoint, frameAtPress: CGRect, frameNow: CGRect, pointerNow: CGPoint
  ) -> Verdict {
    let moved = abs(frameNow.minX - frameAtPress.minX) >= 1 || abs(frameNow.minY - frameAtPress.minY) >= 1
    let resized = abs(frameNow.width - frameAtPress.width) >= 1 || abs(frameNow.height - frameAtPress.height) >= 1
    if resized {
      // Only a press on the border resizes by hand. macOS also changes a window's size when its title
      // bar is double-clicked, and when a window it had tiled or zoomed is dragged away and gets its
      // old size back; neither may move a seam. The second is still a drag.
      if isNearEdge(pressedAt, of: frameAtPress) { return .resize }
      return moved ? .drag : .neither
    }
    let dx = pointerNow.x - pressedAt.x
    let dy = pointerNow.y - pressedAt.y
    let travelled = (dx * dx + dy * dy).squareRoot()
    if moved {
      // A hand takes a window along, so the window goes no farther than the pointer. One that leaps under a
      // pointer at rest was moved by something else: an app, a tool, macOS bringing back what it had swept aside.
      // Taken for a drag, that last is one at the edge of the display, where Arbor docks.
      let x = frameNow.minX - frameAtPress.minX
      let y = frameNow.minY - frameAtPress.minY
      return (x * x + y * y).squareRoot() > travelled + lead ? .neither : .drag
    }
    return travelled > patience ? .neither : .undecided
  }
}
