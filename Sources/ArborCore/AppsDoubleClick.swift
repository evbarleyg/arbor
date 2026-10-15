import Foundation

/// A double-click that went to a docked window's app.
///
/// macOS has an action of its own for a title bar's double-click (System Settings → Desktop & Dock → "Double-click a
/// window's title bar to": fill or zoom as macOS comes, or minimize), and an app may have one for whatever else was
/// double-clicked. The person asked for it, so Arbor does not undo it. Put back into its slot a quarter of a second
/// later, as a docked window is that moves by itself, the window would jump twice and macOS's action would seem
/// broken (K193). One double-click gets one answer, and this one is macOS's.
///
/// Where in the window the double-click landed is not asked. How tall a title bar is differs from app to app, and only
/// the app knows. Taking a double-click on a word for one on a title bar costs nothing unless the window then changes
/// its frame, which is as much the double-click's doing; missing a tall title bar would bring the two jumps back.
public struct AppsDoubleClick: Equatable, Sendable {
  public var window: WindowID
  /// When the second press went down, in seconds since the reference date (`Controller.now()`).
  public var time: Double

  /// How long after that press a change of the window's frame still counts as its outcome. macOS acts when the
  /// button comes up, and apps report a new frame some tenths of a second after they have it.
  public static let patience = 2.0

  public init(window: WindowID, time: Double) {
    self.window = window
    self.time = time
  }

  /// Whether a mouse-down completes a double-click. macOS keeps counting while clicks follow each
  /// other quickly, so double-clicking twice in a row arrives as clicks 1, 2, 3 and 4.
  public static func isCompleted(byClick clicks: Int) -> Bool {
    clicks >= 2 && clicks.isMultiple(of: 2)
  }

  /// Whether anything can still come of it at `time`.
  public func isFresh(at time: Double) -> Bool {
    // Either way round, so that a clock set back does not keep the note alive for hours.
    abs(time - self.time) <= Self.patience
  }

  /// Whether a new frame of `window`, reported at `time`, is what came of this double-click.
  /// - Parameter buttonIsDown: with the button still down nothing has come of it yet: that is a drag or a resize.
  public func explains(aChangeOf window: WindowID, at time: Double, buttonIsDown: Bool) -> Bool {
    window == self.window && !buttonIsDown && isFresh(at: time)
  }
}
