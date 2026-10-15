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

  /// Longer than lies between "it is off its app's list" and "it is in full screen": 1 to 4 ms in ten rounds on a hosted Mac.
  static let timeToSayWhyItWent = 0.1
  /// Longer than the way into full screen takes: the Space it leaves was reported away 0.47 to 0.62 s after the window had said so.
  static let timeToLeaveForFullScreen = 1.5

  /// A docked window goes into full screen. It takes no room from now on, and its neighbours are to have it. But not now: the
  /// way in plays for half a second over the Space they are on, in plain view, and if the window comes straight back they give
  /// the room up again: two moves each, for nothing. So the layout waits until that Space is away. Then nobody is there to be
  /// moved; whoever comes back to it without the window finds the neighbours closing up, once; and when the window comes back
  /// with it, nothing but the window has moved. True if that is what `window` reports, and all there is to do about it.
  func neighboursWaitWhileItGoesIntoFullScreen(
    _ window: WindowSnapshot, was previous: WindowSnapshot?, on displayID: DisplayID
  ) -> Bool {
    guard window.isFullScreen else { return false }
    // What else it reports from there (its size is the display's) is nothing to lay out for, nor to put right.
    guard previous?.isFullScreen == false else { return previous?.isPresent == window.isPresent }
    // The reports that the Space has gone bring the layout forward.
    scheduleSpaceRelayout(displayID, after: Self.timeToLeaveForFullScreen)
    scheduleSave()
    return true
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
