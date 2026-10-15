import ArborCore
import CoreGraphics

/// Telling the window system ahead what a layout is about to ask of it (`WindowSystem.moveTogether`), so that the
/// apps move their windows side by side and Arbor waits once for all of them, not for one after the other.
///
/// `apply` stays as it is: one window at a time, each answer looked at before the next question. This only foretells
/// its questions. A move foretold and never asked for would leave a window where nobody meant it to be, so only what is
/// certain is foretold: docked windows going into their slots and out of view, which is most of what a camera move
/// moves. Floating windows have many reasons to stay where they are, and putting windows back has reasons of its own,
/// so neither is foretold. A move that is not foretold costs a wait of its own and nothing else.
///
/// `BudgetTests` and `MoveTogetherTests` fail on a move that goes unclaimed. Whoever gives `apply` or `park` a new reason to
/// leave a docked window alone gives it here as well.
extension Controller {
  func movesInSight(
    for layout: Layout, on displayID: DisplayID, reason: RelayoutReason
  ) -> [(window: WindowID, frame: CGRect)] {
    guard reason != .enforce, let display = display(displayID) else { return [] }
    var moves: [(window: WindowID, frame: CGRect)] = []
    // The window in the user's hand stays there (F09): foretold, it would be pulled out of it, and nobody would claim the move.
    for (window, target) in layout.windowFrames.sorted(by: { $0.key < $1.key })
    where window != drag?.window && !awaitedBack.contains(window) {
      guard let current = windows[window] else { continue }
      if !parked.contains(window), current.frame.approximatelyEquals(target, tolerance: 1) || misfits[window] != nil {
        continue
      }
      // Let be through this layout (`stillLetBe`), as `apply` lets it be.
      if enforcement.givenUp.contains(window) { continue }
      // The first frame `apply` asks for.
      if let question = questionBeforePlacing(current, in: target, on: displayID) {
        moves.append((window, fitted(question, for: window)))
      } else if case let asked = request(for: current, in: target), !isWhereItsAnswerBelongs(current, asked: asked, in: target) {
        moves.append((window, asked))
      }
    }
    // With `shrinkOutOfView` a window is parked at another size, which `parkingSize` works out and remembers in one
    // go: not for a forecast. Those moves wait on their own.
    for window in layout.hiddenWindows.sorted()
    where !parked.contains(window) && window != drag?.window && !isLetBe(window) && !settings.shrinkOutOfView {
      // The frame `park` asks for.
      guard let size = windows[window]?.frame.size else { continue }
      moves.append((window, CGRect(origin: parkingOrigin(for: size, of: window, on: display), size: size)))
    }
    // One window needs no company.
    return moves.count > 1 ? moves : []
  }
}
