import ArborCore
import CoreGraphics

/// Telling the window system ahead what a layout is about to ask of it (`WindowSystem.moveTogether`), so that the
/// apps move their windows side by side and Arbor waits once for all of them, not for one after the other.
///
/// `apply` still asks one window at a time, and looks at each answer before the next question. This only foretells
/// its questions. A move foretold and never asked for would leave a window where nobody meant it to be, so only what is
/// certain is foretold: docked windows going into their slots (`movesInSight`) and out of view (`leavesInSight`), which is most of
/// what a camera move moves. Floating windows have many reasons to stay where they are, and putting windows back has reasons of its
/// own, so neither is foretold. A move that is not foretold costs a wait of its own and nothing else.
///
/// `BudgetTests` and `MoveTogetherTests` fail on a move that goes unclaimed. Whoever gives `apply` or `park` a new reason to
/// leave a docked window alone gives it here as well.
extension Controller {
  func movesInSight(
    for layout: Layout, on displayID: DisplayID, reason: RelayoutReason
  ) -> [(window: WindowID, frame: CGRect)] {
    guard reason != .enforce, display(displayID) != nil else { return [] }
    var moves: [(window: WindowID, frame: CGRect)] = []
    // The window in the user's hand stays there (F09): foretold, it would be pulled out of it, and nobody would claim the move.
    for (window, target) in inOnePiece(layout.windowFrames) where window != drag?.window {
      guard let current = windows[window] else { continue }
      if !parked.contains(window), current.frame.approximatelyEquals(target, tolerance: 1) || misfits[window] != nil {
        continue
      }
      // Let be through this layout (`stillLetBe`), as `apply` lets it be.
      if enforcement.givenUp.contains(window) { continue }
      // The first frame `apply` asks for.
      if let question = questionBeforePlacing(current, in: target, on: displayID) {
        moves.append((window, question))
      } else if case let asked = request(for: current, in: target), !isWhereItsAnswerBelongs(current, asked: asked, in: target) {
        moves.append((window, asked))
      }
    }
    // What leaves is not among them: it has a forecast of its own, which `apply` makes when these have their frames (`leavesInSight`).
    // One window needs no company, if it is the only one the layout moves.
    return moves.count + leavesInSight(for: layout, on: displayID).count > 1 ? moves : []
  }

  /// The docked windows `apply` is about to send out of view, which it does last, and foretells by themselves. Side by side with those who
  /// stay they would be gone first, every time: to leave is one call for a place, about a millisecond, and to grow is a resize, which takes an
  /// app 4 to 150. The desk would show through for as long as the slowest resize takes (Controller+InOnePiece.swift).
  func leavesInSight(for layout: Layout, on displayID: DisplayID) -> [(window: WindowID, frame: CGRect)] {
    // With `shrinkOutOfView` a window is parked at another size, which `parkingSize` works out and remembers in one
    // go: not for a forecast. Those moves wait on their own.
    guard let display = display(displayID), !settings.shrinkOutOfView else { return [] }
    return layout.hiddenWindows.sorted().filter { !parked.contains($0) && $0 != drag?.window && !isLetBe($0) }.compactMap { window in
      // The frame `park` asks for.
      windows[window].map { (window, CGRect(origin: parkingOrigin(for: $0.frame.size, of: window, on: display), size: $0.frame.size)) }
    }
  }
}
