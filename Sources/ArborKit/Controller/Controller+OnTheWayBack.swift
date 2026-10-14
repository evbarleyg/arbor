import ArborCore
import Foundation

/// A window that has only just come back (out of the Dock, with its app, from another macOS Space or from full screen) may
/// not be ready to take a frame: macOS may still be flying it in. Asked for its slot, it answers with the frame it
/// has. Taken at its word it would be a window that refuses to shrink, which is a tile from then on and pulls the view
/// onto itself, or one that cannot grow, which is never asked again.
///
/// So for a moment nothing is concluded from what it answers, and it is asked once more when the moment is over.
extension Controller {
  /// Longer than the flight out of the Dock takes.
  static let timeToLand: TimeInterval = 0.5
  /// Longer than the way back from full screen takes, which is reported as over when it begins.
  static let timeToLandFromFullScreen: TimeInterval = 1.2

  /// Called with every report about a window.
  func noteWhetherItCameBack(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    guard let previous, !previous.isPresent, window.isPresent else { return }
    landsAt[window.id] = now().addingTimeInterval(previous.isFullScreen ? Self.timeToLandFromFullScreen : Self.timeToLand)
  }

  /// Called by `apply` for a window that did not take the frame of its slot. True if that means nothing yet: then it
  /// does not count as a misfit, nothing is learned about its sizes, and its display is laid out again shortly.
  func postponesJudgement(of window: WindowID, on displayID: DisplayID) -> Bool {
    guard let landing = landsAt[window] else { return false }
    let left = landing.timeIntervalSince(now())
    guard left > 0 else {
      landsAt[window] = nil
      return false
    }
    misfits[window] = nil
    scheduler.schedule("landed-\(displayID.rawValue)", after: left) { [weak self] in
      guard let self else { return }
      // Once: the second answer is believed whatever the clock says, or a clock that stands still (a test's, a Mac that
      // slept) would have Arbor ask for ever.
      for window in self.workspaces[displayID]?.allWindows ?? [] { self.landsAt[window] = nil }
      self.relayout(displayID, reason: .enforce)
    }
    return true
  }
}
