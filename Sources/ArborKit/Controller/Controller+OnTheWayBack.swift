import ArborCore
import CoreGraphics
import Foundation

/// A window that has only just come back (out of the Dock, with its app, from another macOS Space or from full screen) may
/// not be ready to take a frame: macOS may still be flying it in. Asked for its slot, it answers with the frame it
/// has. Taken at its word it would be a window that refuses to shrink, which is a tile from then on and pulls the view
/// onto itself, or one that cannot grow, which is never asked again.
///
/// So for a moment nothing is concluded from what it answers, and it is asked once more when the moment is over.
extension Controller {
  /// Longer than the flight out of the Dock takes.
  public static let timeToLand: TimeInterval = 0.5
  /// Longer than the way back from full screen takes, which is reported as over when it begins.
  static let timeToLandFromFullScreen: TimeInterval = 1.2

  /// Called with every report about a window.
  func noteWhetherItCameBack(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    guard let previous, !previous.isPresent, window.isPresent else { return }
    landsAt[window.id] = now().addingTimeInterval(previous.isFullScreen ? Self.timeToLandFromFullScreen : Self.timeToLand)
  }

  /// Called with every report about a window. macOS says that a window has left full screen when the way out begins. For 0.5 to
  /// 0.7 s a stand-in of macOS's shows the animation; the window itself is off the screen and off its app's list, at the frame it
  /// will land at: the one it had before Arbor ever moved it. That it is back Arbor hears when everybody has seen it there.
  /// Laid out only then, it is seen to land in one place and jump to another.
  ///
  /// So a docked window is given the frame of its slot while nobody can see it. Nothing else is moved, and nothing is concluded
  /// from its answer: the layout that follows its return finds it in place, or puts it there as it always has.
  ///
  /// What real apps make of that (a hosted Mac, macOS 26.6): TextEdit takes the frame at once and keeps it. Safari, which shows its own
  /// way out, says yes and stays where it is until it has placed the window once more itself, a tenth of a second or two
  /// into the flight; asked after that, it takes the frame and keeps it. So Arbor asks until it has been heard in full. In full
  /// screen no window can be asked: the position is refused, the size accepted and forgotten.
  func meetAtItsSlotIfItLeftFullScreen(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    if previous?.isFullScreen == false, window.isFullScreen { sharedItsSpace[window.id] = presentWindowIDs() }
    // Back, or in full screen again: no longer on its way.
    if window.isPresent || window.isFullScreen { metAhead[window.id] = nil }
    guard previous?.isFullScreen == true, !window.isFullScreen else { return }
    let companions = sharedItsSpace.removeValue(forKey: window.id)
    guard isRunning, !window.isPresent, !window.isMinimized, !window.isHidden, drag?.window != window.id,
      !enforcement.givenUp.contains(window.id), filter.manages(window),
      // A held view may show something else when the window is back (`holdFences`), which only the layout itself finds out.
      holdLevel != .view,
      let display = workspaceID(containing: window.id),
      let slot = slotWhenItsSpaceIsBack(of: window.id, with: companions, on: display)
    else { return }
    // Where it ended the last time it was asked to fill this slot, if it could not.
    metAhead[window.id] = (misfits[window.id].flatMap { $0.slot == slot ? $0.frame : nil } ?? slot, nil, 0)
    seeThatItHasItsSlot(window.id)
  }

  /// How often Arbor looks at a window on its way out of full screen, ten times a second: as long as the way may take
  /// (`timeToLandFromFullScreen`; 0.85 s from the report to the stand-in's end was seen). A look at a window that has its frame costs
  /// nothing, and until the last one its neighbours are not laid out without it (Controller+Spaces.swift).
  static let looksOnTheWayOut = 12

  /// By the clock, not with each of the window's reports, which come four at a time. One that left full screen from afar is never
  /// reported back: what happens to it after the last look is no part of its way out.
  private func seeThatItHasItsSlot(_ window: WindowID) {
    guard isRunning, let meeting = metAhead[window], meeting.looks < Self.looksOnTheWayOut else { return metAhead[window] = nil }
    metAhead[window]?.looks += 1
    // An app busy with its own way out may not answer in time: that is not heard either, and the next look asks again.
    if let before = windows[window]?.frame, !before.approximatelyEquals(meeting.target, tolerance: 1),
      let actual = system.setFrame(meeting.target, of: window)
    {
      // The same answer twice, at the place it was asked to: that is what its app makes of the frame (it rounds sizes, or has limits), and
      // it is not asked a dozen times. Once is not enough: a frame is set with several calls, and Safari's own placing falls
      // between them, so that it has the new size at the old place, or the new place at the old size.
      if let answer = meeting.answer, actual.approximatelyEquals(answer, tolerance: 1),
        abs(actual.minX - meeting.target.minX) <= 1, abs(actual.minY - meeting.target.minY) <= 1
      {
        metAhead[window]?.target = actual
      }
      metAhead[window]?.answer = actual
      Log.debug("\(window) is on its way out of full screen; asked for \(meeting.target.brief), it has \(actual.brief)")
      windows[window]?.frame = actual
    }
    scheduler.schedule("meet-\(window.rawValue)", after: 0.1) { [weak self] in self?.seeThatItHasItsSlot(window) }
  }

  /// The slot of a docked window once it is back on the Space it left for full screen, with `companions`, the windows that were
  /// there with it: macOS takes it back to that Space, and what is docked on a third one stays away. Nil if it has no slot then
  /// (it floats, it is out of view, or a tile). Only a look, like `layoutToCome`: the gaps are the layout's to move.
  private func slotWhenItsSpaceIsBack(
    of window: WindowID, with companions: Set<WindowID>?, on displayID: DisplayID
  ) -> CGRect? {
    let (asItIs, noted, known) = (workspaces[displayID], treesBeforeRoomWasMade[displayID], windows)
    defer { (workspaces[displayID], treesBeforeRoomWasMade[displayID], windows) = (asItIs, noted, known) }
    let kept = keptRoom[displayID]
    defer { keptRoom[displayID] = kept }
    var back = known
    let all = asItIs?.allWindows ?? []
    // If none of them is on record, Arbor heard of the full screen only when the Space had gone: then all that are away count.
    let isKnown = companions.map { !$0.isDisjoint(with: all.filter { $0 != window }) } ?? false
    for id in all where id == window || !isKnown || companions?.contains(id) == true { back[id]?.isOnActiveSpace = true }
    windows = back
    return roomyLayout(of: displayID, for: .structure)?.windowFrames[window]
  }

  /// Called by `apply` for a window that did not take the frame of its slot. True if that means nothing yet: then it
  /// does not count as a misfit, nothing is concluded about its sizes (`place` notes where one that has heard stopped growing, which
  /// only says where it is sent next), and its display is laid out again shortly.
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
