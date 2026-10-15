import ArborCore
import CoreGraphics

/// Telling the window system ahead what a layout is about to ask of it (`WindowSystem.moveTogether`), so that the
/// apps move their windows side by side and Arbor waits once for all of them, not for one after the other.
///
/// `apply` stays as it is: one window at a time, each answer looked at before the next question. This only foretells
/// its questions. A move foretold and never asked for would leave a window where nobody meant it to be, so only what is
/// certain is foretold, and only just before it is asked for: docked windows going into their slots and out of view, before the
/// first `apply` of that very layout; floating windows by `placeFloatingWindows` itself, from the plan it is about to walk.
/// So a layout moves its windows in two breaths. One would not do: floating windows are placed last, after the rounds in which
/// a window that refuses its slot has the layout reckoned again, and the Desktop may be elsewhere by then. Putting windows
/// back has reasons of its own and is not foretold, nor is a drop that is only tried out (Controller+Reflow.swift). A move that is
/// not foretold costs a wait of its own and nothing else.
///
/// `BudgetTests`, `MoveTogetherTests` and the chaos test's rule `forecast` fail on a move that goes unclaimed. Whoever gives `apply`,
/// `park` or the walk in `placeFloatingWindows` a new reason to leave a window alone gives it here as well.
extension Controller {
  func movesInSight(
    for layout: Layout, on displayID: DisplayID, reason: RelayoutReason
  ) -> [(window: WindowID, frame: CGRect)] {
    guard reason != .enforce, let display = display(displayID) else { return [] }
    var moves: [(window: WindowID, frame: CGRect)] = []
    // The window in the user's hand stays there (F09): foretold, it would be pulled out of it, and nobody would claim the move.
    for (window, target) in layout.windowFrames.sorted(by: { $0.key < $1.key }) where window != drag?.window {
      guard let current = windows[window] else { continue }
      if !parked.contains(window), current.frame.approximatelyEquals(target, tolerance: 1) || misfits[window] != nil {
        continue
      }
      // The first frame `apply` asks for.
      moves.append((window, questionBeforePlacing(current, in: target, on: displayID) ?? request(for: current, in: target)))
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

  /// What `placeFloatingWindows` is about to ask for, walking `plan`.
  func movesInSight(
    in plan: [(window: WindowID, move: FloatingMove)], on display: DisplaySnapshot, reason: RelayoutReason
  ) -> [(window: WindowID, frame: CGRect)] {
    guard reason != .enforce else { return [] }
    var moves: [(window: WindowID, frame: CGRect)] = []
    for (window, move) in plan {
      guard let current = windows[window] else { continue }
      switch move {
      case .place(let target, _):
        if !isInPlace(current, at: target) { moves.append((window, target)) }
      case .park:
        // As for docked windows: with `shrinkOutOfView` it is parked at another size.
        if !settings.shrinkOutOfView {
          moves.append((window, CGRect(origin: parkingOrigin(for: current.frame.size, of: window, on: display), size: current.frame.size)))
        }
      case .fill:
        // Asked for in steps, each depending on the answer to the one before.
        break
      }
    }
    // One window needs no company.
    return moves.count > 1 ? moves : []
  }
}
