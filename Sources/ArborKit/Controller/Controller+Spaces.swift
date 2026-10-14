import ArborCore

/// Windows on other macOS Spaces.
///
/// The Accessibility API lists only the windows on the Spaces that are
/// showing. `AXWindowSystem` marks the windows it stops listing as off the
/// active Space instead of dropping them, so they keep their place in the tree
/// but take no space (`WindowSnapshot.isPresent`), and come back to the same
/// place when their Space shows again. Only `windowDestroyed` (or the app
/// quitting) removes a window.
extension Controller {
  /// Lays a display out once a Space switch has been reported. A switch
  /// arrives as one `windowChanged` per window that came into or went out of
  /// view. Laying out after each of them would move windows that are still
  /// listed as present but are already on the Space that went away. All of
  /// one switch's reports arrive before scheduled work runs, so a single
  /// layout afterwards sees them all.
  func scheduleSpaceRelayout(_ displayID: DisplayID, after seconds: Double = 0) {
    postponedRelayouts.insert(displayID)
    scheduler.schedule("space-\(displayID.rawValue)", after: seconds) { [weak self] in
      self?.runPostponedRelayout(of: displayID)
    }
  }

  private func runPostponedRelayout(of displayID: DisplayID) {
    // A window being dragged can be carried to another Space (⌃→ while
    // holding it, or holding it at the screen edge). Laying out now would
    // pull it back to its slot, so wait for the drop.
    if drag != nil {
      scheduleSpaceRelayout(displayID, after: 0.25)
      return
    }
    postponedRelayouts.remove(displayID)
    // macOS has just shown the switch in its own way.
    relayout(displayID, reason: .structure, motion: .instant)
    // One of the windows that came back may have been given the keyboard before it was reported.
    let returned = returningWindows
    returningWindows.removeAll()
    if let focused = system.focusedWindow(), returned.contains(focused) {
      bringIntoViewIfFocused(focused, retries: 0)
    }
  }

  /// Runs the layouts that were put off, now. A focus report must be judged by what is in view, and it can
  /// arrive between the reports of a switch (which come in one go) and the layout after them.
  func runPostponedRelayouts() {
    guard drag == nil else { return }
    for displayID in postponedRelayouts.sorted() {
      scheduler.cancel("space-\(displayID.rawValue)")
      runPostponedRelayout(of: displayID)
    }
  }
}
