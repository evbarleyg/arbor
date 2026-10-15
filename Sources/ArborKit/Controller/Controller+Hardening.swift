import ArborCore
import CoreGraphics
import Foundation

/// What real apps and real windows do that a layout engine would rather not know about (F17 and the review of
/// the Accessibility layer).
extension Controller {
  // MARK: Apps that keep moving their own windows (H2)

  /// Called before a display's docked windows are put back. Counts the put-back of each window that is out of
  /// place; a window put back too often in a short time is left where its app wants it from here on,
  /// until the layout changes (`relayout` with another reason starts the count again).
  ///
  /// Out of place is what `apply` is about to move, no more. A window that cannot take its slot's size rests where the
  /// last attempt left it (`misfits`), and would otherwise be counted at every put-back a neighbour causes, until
  /// Arbor gave up on a window that never moved. Nor is a window counted whose app does not answer (`unplaced`): it is
  /// out of place because it cannot be moved, not because it moves itself, and it is placed when its app wakes.
  func countPutBacks(on displayID: DisplayID) {
    guard let layout = layout(of: displayID) else { return }
    let time = now().timeIntervalSinceReferenceDate
    for (window, target) in layout.windowFrames.sorted(by: { $0.key < $1.key }) {
      guard let current = windows[window], !parked.contains(window), !enforcement.givenUp.contains(window),
        !unplaced.contains(window), !current.frame.approximatelyEquals(target, tolerance: 1)
      else { continue }
      if let misfit = misfits[window], misfit.slot == target, current.frame.approximatelyEquals(misfit.frame, tolerance: 1) {
        continue
      }
      if !enforcement.allowsPuttingBack(window, at: time) {
        Log.info("\(window) keeps moving itself; leaving it where its app puts it until the layout changes")
      }
    }
  }

  // MARK: Apps that hang

  /// A report about a window shows that its app is talking. If the app did not answer when the window was to be
  /// moved, now is the time to place it.
  func noteThatTheAppAnswers(_ window: WindowSnapshot, on display: DisplayID) {
    guard unplaced.remove(window.id) != nil else { return }
    // A layout that only puts windows back takes no floating window out of view: that is for a move of the camera. This
    // window missed such a move.
    owedMoves.insert(window.id)
    scheduleEnforce(display)
  }

  // MARK: A pause while an app hangs (K003, the half that Arbor lives to see)

  // A pause promises every window in view and then stops listening. A window that was out of view and whose app did not
  // answer at that moment stayed there, and nobody heard the app wake: lost until `resume`, with nothing reacting to ⌘Tab.
  // So Arbor keeps a note and tries again, as it does for a window left in full screen (Controller+LeftInFullScreen.swift).
  // Nothing cheap says that an app has woken, and every try makes Arbor wait for it, so the tries come further and further apart.

  static let couldNotComeBackKey = "could-not-come-back"
  /// After 1, 2, 4, 8 and 16 seconds, then every 30: some ten minutes in all.
  static let mostTriesForWhatCouldNotComeBack = 24
  static func waitForWhatCouldNotComeBack(afterTries tries: Int) -> Double { min(pow(2, Double(min(tries, 10))), 30) }

  /// Called where a window is brought back and its app does not answer. Counts only while a pause is letting go, and only
  /// for a window that is out of view: one that merely keeps the wrong size is not lost. The first place counts: that is where
  /// the window belongs, and what comes after is the last sweep's "anywhere, as long as it is in view".
  func noteThatItCouldNotComeBack(_ window: WindowID, to frame: CGRect) {
    guard isPaused, isRunning, isMostlyOffScreen(window), couldNotComeBack[window] == nil else { return }
    couldNotComeBack[window] = frame
  }

  /// Called when a pause has begun.
  func lookOutForWhatCouldNotComeBack() {
    guard isPaused, !couldNotComeBack.isEmpty else { return }
    let wait = Self.waitForWhatCouldNotComeBack(afterTries: triesForWhatCouldNotComeBack)
    scheduler.schedule(Self.couldNotComeBackKey, after: wait) { [weak self] in
      self?.tryWhatCouldNotComeBack()
      self?.lookOutForWhatCouldNotComeBack()
    }
  }

  /// Called when the pause ends, either way: a launch and a quit see to all windows.
  func forgetWhatCouldNotComeBack() {
    couldNotComeBack.removeAll()
    triesForWhatCouldNotComeBack = 0
    scheduler.cancel(Self.couldNotComeBackKey)
  }

  private func tryWhatCouldNotComeBack() {
    guard isPaused else { return }
    // First what the window server knows, which takes no app: it has closed, or somebody else has fetched it (Mission Control,
    // its app on waking). In view is all that was owed, wherever.
    let existing = system.existingWindowIDs()
    let screens = system.displays().map(\.frame)
    let inView = Set(system.stackedWindows().filter { !$0.frame.showsLessThanHalf(on: screens) }.map(\.id))
    couldNotComeBack = couldNotComeBack.filter { existing.contains($0.key) && !inView.contains($0.key) }
    guard !couldNotComeBack.isEmpty else { return }
    triesForWhatCouldNotComeBack += 1
    // Moving a window takes its app, which Arbor has let go of for the pause.
    system.start()
    defer { system.stop() }
    for (window, frame) in couldNotComeBack.sorted(by: { $0.key < $1.key }) {
      guard let actual = give(frame, to: window)?.frame else { continue }
      couldNotComeBack[window] = nil
      leftAt?[window] = actual
      noteThatThePauseFetched(window, to: actual)
      Log.info("\(window)'s app answers again; brought the window into view, as the pause promised")
    }
    savePause()
    if triesForWhatCouldNotComeBack >= Self.mostTriesForWhatCouldNotComeBack, !couldNotComeBack.isEmpty {
      Log.info("gave up on \(couldNotComeBack.count) window(s) out of view whose app has not answered since the pause began; `resume` fetches them")
      couldNotComeBack.removeAll()
    }
  }

  // MARK: The Dock and the menu bar

  /// Takes over the display's visible frame as it is now. macOS says nothing when the Dock is resized, moved or
  /// set to hide, or the menu bar is set to hide, so the frame read at the last display change can be out of date.
  func refreshVisibleFrame(of displayID: DisplayID) {
    guard let index = displays.firstIndex(where: { $0.id == displayID }),
      let fresh = system.displays().first(where: { $0.id == displayID }),
      fresh.frame == displays[index].frame, fresh.visibleFrame != displays[index].visibleFrame
    else { return }
    displays[index].visibleFrame = fresh.visibleFrame
  }

  // MARK: Drags whose end nobody saw

  /// Nobody saw the button come up, so where the pointer is now says nothing about what the user meant.
  /// A docked window goes back to its slot, unless a plain drag had taken it out (`cancelDrag`); a floating one stays where it was left.
  ///
  /// macOS saw it, though. Where the pointer was last seen at the edge of the display or in the menu bar, the window is in a tile
  /// of macOS's by now, or on its way there, and no slot is a place to pull it back to. Only by the place: which keys were
  /// down when the button came up, nobody knows any more.
  public func dragCancelled(_ id: WindowID) {
    actsOfAHand += 1
    defer { actsOfAHand -= 1 }
    guard let session = drag, session.window == id else { return }
    if var macOSs = hoverLeftToMacOS(session, optionHeld: false) {
      macOSs.isPlain = session.wasPlain
      return endDrag(on: macOSs)
    }
    cancelDrag()
  }

  // MARK: Native tabs

  public func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {
    guard old != window.id else { return }
    guard isRunning, let display = workspaceID(containing: old), filter.manages(window) else {
      // Nothing to hand over: the old window was not arranged, or the new one may not be.
      let ignored = filter.ignoredWindowIDs.contains(old)
      windowDestroyed(old)
      if ignored { filter.ignoredWindowIDs.insert(window.id) }
      windowAppeared(window)
      return
    }
    windows[window.id] = window
    // The newcomer may have a place of its own, from before it was merged into this tab group.
    for id in workspaces.keys.sorted() where workspaces[id]!.contains(window.id) {
      workspaces[id]!.forget(window.id, shareSpace: settings.shareRemovedSpace)
      if id != display { relayout(id, reason: .structure) }
    }
    if workspaces[display]!.isDocked(old) {
      workspaces[display]!.replaceWindow(old, with: window.id)
    } else {
      let role = workspaces[display]!.role(of: old)
      let host = workspaces[display]!.guests?[old]
      let fillsAt = workspaces[display]!.filled?[old]
      let frame = workspaces[display]!.floating.removeValue(forKey: old)
      workspaces[display]!.floating[window.id] = frame
      workspaces[display]!.setRole(role, of: window.id)
      if let host { workspaces[display]!.receive(window.id, asGuestOf: host) }
      if let fillsAt { workspaces[display]!.fill(window.id, at: fillsAt) }
    }
    renumber(old, as: window.id)
    // Tabs of a group share their frame, so what is known about the one holds for the other.
    if parked.remove(old) != nil { parked.insert(window.id) } else { parked.remove(window.id) }
    settled[window.id] = settled.removeValue(forKey: old)
    minimumSizes[window.id] = minimumSizes.removeValue(forKey: old)
    disprovedMinimums[window.id] = disprovedMinimums.removeValue(forKey: old)
    seenSizes[window.id] = seenSizes.removeValue(forKey: old)
    if fixedSizesNoted.remove(old) != nil { fixedSizesNoted.insert(window.id) }
    misfits[window.id] = misfits.removeValue(forKey: old)
    // What stands there now is asked at the next layout like anybody.
    journeyIsOver(old)
    parkedAgain[window.id] = parkedAgain.removeValue(forKey: old)
    titleBars[window.id] = titleBars.removeValue(forKey: old)
    chosenOnShape[window.id] = chosenOnShape.removeValue(forKey: old)
    handTheZoomOver(to: window.id, from: old)
    soleFloatReplaced(old, by: window.id)
    shrunk[window.id] = shrunk.removeValue(forKey: old)
    fittedToADisplay[window.id] = fittedToADisplay.removeValue(forKey: old)
    fittedFrames[window.id] = fittedFrames.removeValue(forKey: old)
    hints[window.id] = WindowHint(bundleID: window.bundleID, title: window.title)
    focusHistory.removeAll { $0 == window.id }
    if let index = focusHistory.firstIndex(of: old) { focusHistory[index] = window.id }
    if isLetBe(old) { letBe?.window = window.id }
    // `old` is in no workspace any more, so this only clears what is remembered about it, and ends a drag of it.
    windowDestroyed(old)
    // The app has just shown the switch in its own way, and there is no picture of the new tab yet.
    relayout(display, reason: .structure, motion: .instant)
    scheduleSave()
  }
}
