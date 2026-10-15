import ArborCore
import ArborKit
import CoreGraphics

/// macOS shows its desktop: every window is swept to the side of its display until something brings them back.
///
/// It is a picture and nothing more, as a hosted Mac showed (macOS 26, `collab/reports/2026-10-14-the-desktop-is-shown.md`).
/// The window server lists the windows at the sides, from one moment to the next, and goes on listing them there with
/// the sizes they had. Accessibility, which asks the apps, has them where they are and reports no move. A frame that is
/// set meanwhile is taken, by the app and by Accessibility; nothing of it shows, and the sweep goes on; when it ends the
/// window is where it was put. A window that opens meanwhile opens in view. Raising, minimizing and restoring end
/// nothing; an app that comes forward does.
extension FakeWindowSystem {
  static let finder = "com.apple.finder"

  public var isSweptAside: Bool { sweptAside != nil }

  /// The user clicks on the wallpaper, with "Click wallpaper to reveal desktop" as macOS comes: the windows are swept
  /// aside, or, if they are, come back. All that is reported is what such a click always brings: the press, and, if
  /// that is news, Finder in front and the keyboard with none of the known windows.
  public func clickOnTheWallpaper() {
    mouseDown = true
    events?.pointerPressed()
    mouseDown = false
    pressShowDesktopKey()
    activate(bundleID: Self.finder, name: "Finder")
    if focused != nil { userFocusesNothing() }
    afterEvents?()
  }

  /// F11, the hot corner, the spread of the fingers: the same. With Finder in front already nothing at all was reported.
  public func pressShowDesktopKey() {
    guard sweptAside == nil else { return sweptAside = nil }
    sweptAside = windows.filter(\.value.snapshot.isPresent).mapValues { window in
      display(of: window.snapshot.frame).map { Self.whereItWaits(window.snapshot.frame, on: $0) } ?? window.snapshot.frame
    }
  }

  /// The user presses on the strip of a swept window that still shows, and lets go: they all come back, as soon as the
  /// button is down. macOS keeps the click: the window is not brought forward and gets no keyboard. No hand is quite
  /// still, so the pointer slips meanwhile, and may rest before the button comes up.
  ///
  /// What Arbor hears of it is up to the Accessibility layer, which notes the window under a press and where the window
  /// server has it, looks again when the pointer moves, and finds it somewhere else. This asks the judges it asks.
  /// - Parameter edge: how far from the edge of the display the press lands, of the twelve points that show.
  public func clickOnTheStrip(
    of window: WindowID, at edge: CGFloat = 6, slippingBy slip: CGSize = CGSize(width: 3, height: 3),
    resting seconds: Double = 0
  ) {
    guard let listed = sweptAside?[window], let frame = frame(of: window), let display = display(of: frame) else { return }
    // Between the menu bar and the bottom of the display.
    var shows = display.frame
    shows.origin.y = display.visibleFrame.minY
    shows.size.height = display.frame.maxY - shows.minY
    shows = shows.intersection(listed)
    var pressed = shows.center
    if listed.minX < display.frame.minX { pressed.x = display.frame.minX + edge }
    if listed.maxX > display.frame.maxX { pressed.x = display.frame.maxX - edge }
    if listed.minY < shows.minY { pressed.y = shows.minY + edge }
    if listed.maxY > display.frame.maxY { pressed.y = display.frame.maxY - edge }
    cursor = pressed
    mouseDown = true
    sweptAside = nil
    events?.pointerPressed()
    cursor = CGPoint(x: pressed.x + slip.width, y: pressed.y + slip.height)
    let verdict =
      WindowGrab.isListedElsewhere(listed, than: frame)
      ? .neither : WindowGrab.classify(pressedAt: pressed, frameAtPress: listed, frameNow: frame, pointerNow: cursor)
    switch verdict {
    case .drag:
      events?.dragBegan(window, at: cursor)
      events?.dragMoved(window, to: cursor)
    case .resize: events?.resizeBegan(window)
    case .neither, .undecided: break
    }
    if seconds > 0 { passTime?(seconds) }
    mouseDown = false
    if verdict == .drag || verdict == .resize, let snapshot = windows[window]?.snapshot {
      events?.windowChanged(snapshot, userInitiated: true)
      if verdict == .drag { events?.dragEnded(window, at: cursor) } else { events?.resizeEnded(window) }
    }
    afterEvents?()
  }

  private func display(of frame: CGRect) -> DisplaySnapshot? {
    displayList.max { frame.fractionInside($0.frame) < frame.fractionInside($1.frame) }
      .flatMap { frame.overlaps($0.frame) ? $0 : nil }
  }

  /// Where the window server lists a swept window: away from the middle of its display, until twelve points of it show, at
  /// the left, at the right, at the bottom, or below the menu bar. (On a Mac it also drifts along the edge, by amounts
  /// nobody has worked out.)
  public static func whereItWaits(_ frame: CGRect, on display: DisplaySnapshot) -> CGRect {
    let x = (frame.midX - display.frame.midX) / display.frame.width
    let y = (frame.midY - display.frame.midY) / display.frame.height
    var swept = frame
    if abs(x) > abs(y) {
      swept.origin.x = x < 0 ? display.frame.minX - frame.width + 12 : display.frame.maxX - 12
    } else {
      swept.origin.y = y <= 0 ? display.visibleFrame.minY - frame.height + 12 : display.frame.maxY - 12
    }
    return swept
  }
}
