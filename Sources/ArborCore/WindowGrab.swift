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

  // MARK: What a press takes hold of

  /// The frontmost window that the window server shows at a place.
  public enum Top: Equatable, Sendable {
    /// One that Arbor does not arrange.
    case stranger
    /// - listed: its frame by the window server.
    /// - believed: what Accessibility last said.
    case known(WindowID, listed: CGRect, believed: CGRect)
  }

  /// What is noted of a press, to hold later looks at the window against.
  public struct Hold: Equatable, Sendable {
    /// Nil: none that Arbor knows was found. Unless that is settled, what a window's app reports may still tell.
    public var window: WindowID?
    /// A place of the pointer, and the frame the window had when the pointer was there, as nearly as can be told.
    public var point: CGPoint
    public var frame: CGRect = .zero
    /// The press is not about a window Arbor knows.
    public var isSettled = false
    /// The press is served late, and the window was found on its way. For the log.
    public var isInTheHand = false

    public init(
      window: WindowID? = nil, point: CGPoint, frame: CGRect = .zero, isSettled: Bool = false, isInTheHand: Bool = false
    ) {
      (self.window, self.point, self.frame) = (window, point, frame)
      (self.isSettled, self.isInTheHand) = (isSettled, isInTheHand)
    }
  }

  /// What a press takes hold of, by what the window server lists when the press is looked at.
  ///
  /// That is at once, as a rule, and then the pointer is where the button went down. But a busy Mac serves a press late: the
  /// place of the press is of a while ago, and the list is of now. A window in the hand may have left that place, with
  /// another one showing there, or be listed as far from its app's word as one that macOS swept aside. So a window that
  /// `isInTheHand` goes first, whether it is under the pointer or still under the press.
  /// - Parameters:
  ///   - pressedAt: where the button went down.
  ///   - pointerNow: where the pointer is as the press is looked at.
  ///   - underPress, underPointer: what the window server shows at those places now.
  public static func hold(pressedAt: CGPoint, pointerNow: CGPoint, underPress: Top?, underPointer: Top?) -> Hold {
    for case .known(let window, let listed, let believed)? in [underPointer, underPress]
    where isInTheHand(listed: listed, believed: believed, pressedAt: pressedAt, pointerNow: pointerNow) {
      // Its app's last word is the nearest there is to the frame it had at the press, and is that frame if Arbor was
      // too busy to hear more. If not, and it is an edge that is in the hand, the edge has left the press behind.
      if isNearEdge(pointerNow, of: listed), !isNearEdge(pressedAt, of: believed) {
        return Hold(window: window, point: pointerNow, frame: listed, isInTheHand: true)
      }
      return Hold(window: window, point: pressedAt, frame: believed, isInTheHand: true)
    }
    switch underPress {
    case nil:
      return Hold(point: pressedAt)
    case .known(let window, let listed, let believed)? where !isListedElsewhere(listed, than: believed):
      // The same for an edge whose app has been heard all along.
      if case .known(window, _, _)? = underPointer, isNearEdge(pointerNow, of: listed), !isNearEdge(pressedAt, of: listed) {
        return Hold(window: window, point: pointerNow, frame: listed)
      }
      return Hold(window: window, point: pressedAt, frame: listed)
    case .stranger?, .known?:
      return Hold(point: pressedAt, isSettled: true)
    }
  }

  /// Whether a hand has taken the window along since the button went down.
  ///
  /// Such a window is ahead of its app's word, the way the pointer went and no farther: the window server moves it at once, and
  /// its app hears a tenth of a second later. More than a step or two ahead it is only if Arbor has not heard the app since
  /// the press, and then the app's word has it under the press. A window at rest that the pointer has merely come to is
  /// where its app says. One that macOS swept aside (`isListedElsewhere`) shows a strip at the side of the display, which can only be
  /// pulled inwards: the other way.
  ///
  /// Nothing is made of a few points. A press that is served on time finds the pointer where it was, give or take a tremble, and
  /// the two frames of a window at rest may differ a little for good; to go by the app's word then would make a drag of
  /// the difference.
  static func isInTheHand(listed: CGRect, believed: CGRect, pressedAt: CGPoint, pointerNow: CGPoint) -> Bool {
    let (px, py) = (pointerNow.x - pressedAt.x, pointerNow.y - pressedAt.y)
    let (dx, dy) = (listed.minX - believed.minX, listed.minY - believed.minY)
    let ahead = (dx * dx + dy * dy).squareRoot()
    return (px * px + py * py).squareRoot() > patience && ahead >= edgeMargin
      && wentThePointersWay(from: believed, to: listed, pressedAt: pressedAt, pointerNow: pointerNow, give: edgeMargin)
      && (ahead <= lag || believed.insetBy(dx: -edgeMargin, dy: -edgeMargin).contains(pressedAt))
  }

  /// Whether a window has moved, each way between nowhere and as far as the pointer, give or take, and not against it.
  private static func wentThePointersWay(
    from before: CGRect, to now: CGRect, pressedAt: CGPoint, pointerNow: CGPoint, give: CGFloat
  ) -> Bool {
    let (dx, dy) = (now.minX - before.minX, now.minY - before.minY)
    let (px, py) = (pointerNow.x - pressedAt.x, pointerNow.y - pressedAt.y)
    func follows(_ window: CGFloat, _ pointer: CGFloat) -> Bool {
      window >= Swift.min(pointer, 0) - give && window <= Swift.max(pointer, 0) + give
    }
    return (abs(dx) >= 1 || abs(dy) >= 1) && follows(dx, px) && follows(dy, py) && dx * px + dy * py > 0
  }

  /// How far a window that started late may be from where the pointer's travel would have it, either way. The pointer and the
  /// window are read a moment apart, and a pointer that comes in coarse steps (a script's: 66 points on a hosted Mac) is a
  /// whole step further on by the second reading.
  public static let lag: CGFloat = 100

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

  /// What is remembered of a press between two looks at it.
  public struct Memory: Equatable, Sendable {
    /// The pointer went far while the window stood still.
    public internal(set) var stoodStill = false
    /// Where the window was at the first look that found it gone the pointer's way, but not all the way.
    var followedTo: CGRect?

    public init() {}
  }

  /// `classify` for a press that is looked at again and again. A pointer that goes far while the window stands still is most
  /// likely selecting text, and the caller then looks less often. It is not the last word. A window can start late: its
  /// app was busy, or had to bring it forward first, while the hand was on its way. (A hosted Mac: 27 points at the first look,
  /// the window still in its place; the drag went on for three seconds and was never seen: no preview, nothing docked.)
  ///
  /// Late, one look is enough only if the window has caught up with the pointer. One that has merely gone the pointer's way may
  /// have jumped by itself, which cannot be told from a late start at one look. At two it can: a window in hand goes on.
  public static func judge(
    pressedAt: CGPoint, frameAtPress: CGRect, frameNow: CGRect, pointerNow: CGPoint, memory: inout Memory
  ) -> Verdict {
    guard memory.stoodStill else {
      let verdict = classify(pressedAt: pressedAt, frameAtPress: frameAtPress, frameNow: frameNow, pointerNow: pointerNow)
      if verdict == .neither { memory.stoodStill = true }
      return verdict
    }
    let verdict = reconsider(pressedAt: pressedAt, frameAtPress: frameAtPress, frameNow: frameNow, pointerNow: pointerNow)
    guard verdict == .drag else {
      memory.followedTo = nil
      return verdict
    }
    let behindX = (frameNow.minX - frameAtPress.minX) - (pointerNow.x - pressedAt.x)
    let behindY = (frameNow.minY - frameAtPress.minY) - (pointerNow.y - pressedAt.y)
    if abs(behindX) <= patience, abs(behindY) <= patience { return .drag }
    guard let before = memory.followedTo else {
      memory.followedTo = frameNow
      return .neither
    }
    return abs(frameNow.minX - before.minX) >= 1 || abs(frameNow.minY - before.minY) >= 1 ? .drag : .neither
  }

  /// What a later look shows once `classify` has said `neither`. More is asked now than that the window moved: the same size,
  /// and each way between where it was and where the pointer's travel would have it, so that a window that goes its own way
  /// during a selection is not taken for one in hand. Not exactly there: its app's reports are a step behind, and macOS holds
  /// a window back where its edges meet others'.
  static func reconsider(
    pressedAt: CGPoint, frameAtPress: CGRect, frameNow: CGRect, pointerNow: CGPoint
  ) -> Verdict {
    let resized = abs(frameNow.width - frameAtPress.width) >= 1 || abs(frameNow.height - frameAtPress.height) >= 1
    if resized { return isNearEdge(pressedAt, of: frameAtPress) ? .resize : .neither }
    guard wentThePointersWay(from: frameAtPress, to: frameNow, pressedAt: pressedAt, pointerNow: pointerNow, give: lag)
    else { return .neither }
    return .drag
  }
}
