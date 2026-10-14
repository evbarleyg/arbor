import CoreGraphics

/// Floating a window and docking it again with the same shortcut is a way to have a look at it at its own size. It
/// should end where it began.
extension Workspace {
  /// This workspace with `window`, which floats, docked again as it was in `before`. `after` is what floating it made
  /// of `before`. Nil if anything has changed since but where floating windows are: then "where it was" may not exist any more,
  /// or may not be what the user means.
  public func docking(_ window: WindowID, backAsIn before: Workspace, floatedAs after: Workspace) -> Workspace? {
    guard isFloating(window), before.isDocked(window), floating.keys.sorted() == after.floating.keys.sorted() else { return nil }
    var unmoved = self
    unmoved.floating = after.floating
    guard unmoved == after else { return nil }
    var restored = before
    restored.floating = floating.filter { $0.key != window }
    // Where it floats next time is where it floated last.
    restored.setUndockedFrame(floating[window], of: window)
    return restored
  }
}
