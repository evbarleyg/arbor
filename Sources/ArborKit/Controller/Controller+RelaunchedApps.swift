import ArborCore
import CoreGraphics
import Foundation

/// An app that is quit and opened again while Arbor runs goes back to its place.
///
/// Someone who quits Mail and opens it again, or whose browser restarts for an update, expects it where it was;
/// someone who closes a window expects its neighbours to close over the gap for good. Both arrive as "this
/// window is gone". What tells them apart is that the app ended, and that news comes after the windows of
/// an app that closes them as it quits, and before those of one that is killed or simply exits.
///
/// People quit apps all day and mostly do not open them again, so quitting must cost nothing: a window that goes is
/// forgotten there and then, exactly as a closed one, and nothing moves later on its account. Arbor only
/// keeps a note beside the tree: how the display was arranged before, and which windows have gone since. If the
/// app of one of them ended (within `closedPlaceGrace` of the window's going), and a window of that app
/// appears within `pendingSlotLifetime` that is the one that went, by its title or because there is nothing to confuse,
/// and **the arrangement has not been changed meanwhile**, the arrangement is put back as it was with that window, and the
/// window takes its place as one does after a login (Controller+PendingSlots.swift). Someone who has rearranged things
/// meanwhile has decided otherwise, and the window is a new window.
///
/// **It comes back in one layout, and takes nothing back that a person has done.**
/// - A window that takes no place changes nothing: the note goes on waiting for the right one, or for its title.
/// - Each window comes back by itself. Meanwhile things are as if only the others had gone: what it looks like depends on who
///   is away, never on the order, and nobody moves for a window that is still away.
/// - A gap is no rearrangement, and one that a person has moved meanwhile stays moved. What Arbor did to the gaps by itself
///   (room before tiles) is nobody's decision: with that alone, everybody is exactly where they were.
/// - What was done meanwhile can still be undone, and no `undo` or `redo` takes the window out of its place again.
/// - On a view that is held nothing is put back: it would make the windows in view give up room, as a rule's dock would.
extension Controller {
  /// How long after a window went its app can end and still count as having quit, in seconds. Apps that ask
  /// about unsaved changes do so before they close anything; what takes time afterwards is saving state.
  public static let closedPlaceGrace: Double = 5

  struct ClosedPlaces {
    struct Closed {
      var pid: Int32
      var hint: WindowHint
      var wentAt: Date
      /// Nil while its app lives on, as far as anybody knows.
      var appEndedAt: Date?
      /// Other processes of the same app that were running when it went (`open -n`). A window of theirs is not the app
      /// coming back.
      var otherCopies: Set<Int32>
      /// Its app had other windows, docked or not. Then only the title says which of them has come back: the first to
      /// open may be one that floated, and would be moved into the place and out again.
      var hadSiblings: Bool
      /// How small it was found to go. The app will not have changed its mind, and asking again costs the neighbours a
      /// second move.
      var minimumSize: CGSize?

      /// Until when the note is kept for it.
      @MainActor var isKeptUntil: Date {
        appEndedAt?.addingTimeInterval(Controller.pendingSlotLifetime) ?? wentAt.addingTimeInterval(Controller.closedPlaceGrace)
      }
    }

    /// The display's workspace before the first of `windows` went, with what a person has done to it since.
    var before: Workspace
    /// The same after the last of them went, with what Arbor's own layouts have done to the gaps since. While the display's
    /// arrangement is still this one's, nothing else has changed in it; where its gaps differ, a person has moved them.
    var after: Workspace
    /// Docked in `before`, and gone.
    var windows: [WindowID: Closed]
    /// Another window went with them, or just before them, that is not expected back: `undo` still has that to say.
    var someStayClosed: Bool
    /// The slots in `before` that their person had squeezed into tiles (Controller+MakeRoom.swift), which is forgotten
    /// with a slot.
    var squeezedByHand: Set<NodeID>
  }

  /// `window` has gone and has just been forgotten on `display`, whose workspace was `before` until then.
  func rememberPlace(of window: WindowSnapshot?, minimumSize: CGSize?, in before: Workspace, on display: DisplayID) {
    guard let window, window.bundleID != nil, filter.manages(window), let after = workspaces[display] else { return }
    let lately = now().addingTimeInterval(-Self.closedPlaceGrace)
    looseWindowsGone = looseWindowsGone.filter { $0.value >= lately }
    guard before.isDocked(window.id) else {
      looseWindowsGone[window.pid] = now()
      return
    }
    // One note per display, for as long as windows going is all that happens to its tree.
    var places = closedPlaces[display].flatMap { $0.after.tree.isSameArrangement(as: before.tree) ? $0 : nil }
      ?? ClosedPlaces(
        before: before, after: before, windows: [:],
        // Closings in a row are one step, the last (`recordIrreversible`): this one is about to take the other's place.
        someStayClosed: undoHistory.steps(.undo, on: display).last?.isIrreversible == true,
        squeezedByHand: squeezedByHand[display] ?? [])
    places.before.follow(whatWasDoneIn: before, since: places.after)
    let otherCopies = Set(windows.values.filter { $0.bundleID == window.bundleID && $0.pid != window.pid }.map(\.pid))
    places.windows[window.id] = ClosedPlaces.Closed(
      pid: window.pid, hint: WindowHint(bundleID: window.bundleID, title: window.title), wentAt: now(),
      appEndedAt: endedApps.contains(window.pid) ? now() : nil, otherCopies: otherCopies,
      hadSiblings: looseWindowsGone[window.pid] != nil
        || windows.values.contains { $0.pid == window.pid && filter.manages($0) },
      minimumSize: minimumSize)
    places.after = after
    closedPlaces[display] = places
    // Those that went before it, on whichever display.
    let ofItsApp = closedPlaces.flatMap { note in
      note.value.windows.filter { $0.value.pid == window.pid }.map { (note.key, $0.key) }
    }
    if ofItsApp.count > 1 { for (display, sibling) in ofItsApp { closedPlaces[display]!.windows[sibling]!.hadSiblings = true } }
    scheduleTidyingOfClosedPlaces()
  }

  public func applicationTerminated(_ pid: Int32) {
    guard isRunning else { return }
    // Its windows may be reported next, in this turn of the run loop. Not for long: numbers are used again.
    endedApps.insert(pid)
    scheduler.schedule("ended-apps", after: 1) { [weak self] in self?.endedApps.removeAll() }
    var count = 0
    for display in closedPlaces.keys.sorted() {
      for (window, closed) in closedPlaces[display]!.windows
      where closed.pid == pid && closed.appEndedAt == nil && closed.isKeptUntil >= now() {
        closedPlaces[display]!.windows[window]!.appEndedAt = now()
        count += 1
      }
    }
    guard count > 0 else { return }
    Log.info("an app with \(count) docked window(s) ended; they go back to their places if it is opened again soon")
    scheduleTidyingOfClosedPlaces()
  }

  /// Each window has its own time, which is looked at when a window appears: another that goes later gives it no more. The
  /// timer only clears up, when the last of those times is over, so that it runs once and does not come back.
  private func scheduleTidyingOfClosedPlaces() {
    guard let last = closedPlaces.values.flatMap(\.windows.values).map(\.isKeptUntil).max() else {
      scheduler.cancel("closed-places")
      return
    }
    scheduler.schedule("closed-places", after: max(last.timeIntervalSince(now()), 0)) { [weak self] in
      self?.forgetPlaces { $0.isKeptUntil <= last }
    }
  }

  /// `old` has become `new`, the same window under another number (a native tab came to the front, a slot was taken by the
  /// window it waited for): every workspace kept from the past goes on meaning that window.
  func renumberInThePast(_ old: WindowID, as new: WindowID) {
    undoHistory.renumber(old, as: new)
    for display in closedPlaces.keys {
      closedPlaces[display]!.before.renumber(old, as: new)
      closedPlaces[display]!.after.renumber(old, as: new)
    }
  }

  /// They are not expected back: their apps live on, so they were closed, or stay away. The note is as if they had never
  /// been there.
  private func forgetPlaces(where isOver: (ClosedPlaces.Closed) -> Bool) {
    for display in closedPlaces.keys.sorted() {
      var places = closedPlaces[display]!
      for window in places.windows.keys.sorted() where isOver(places.windows[window]!) {
        places.windows[window] = nil
        places.before.forget(window, shareSpace: settings.shareRemovedSpace)
        places.someStayClosed = true
      }
      closedPlaces[display] = places.windows.isEmpty ? nil : places
    }
    scheduleTidyingOfClosedPlaces()
  }

  func forgetClosedPlaces() {
    closedPlaces.removeAll()
    looseWindowsGone.removeAll()
    endedApps.removeAll()
    for key in ["closed-places", "ended-apps"] { scheduler.cancel(key) }
  }

  /// At the end of a layout of `display`, which found it as `found`. What a layout does to the gaps is Arbor's own doing (room
  /// before tiles) and nobody's decision. It goes into the note, so that what differs from the note is what a person did.
  func closedPlacesFollow(layoutOf display: DisplayID, whichFound found: Workspace?) {
    // A layout that follows a hand moves no gap, and settles what the Desktop is owed on that hand's account.
    guard !gapsInHand, var places = closedPlaces[display], let found, let left = workspaces[display],
      left.tree != found.tree || left.desktopIsOwedRoom != found.desktopIsOwedRoom,
      left.tree.isSameArrangement(as: found.tree), left.tree.isSameArrangement(as: places.after.tree)
    else { return }
    places.after.tree.follow(gapsOf: left.tree, since: found.tree)
    if places.after.desktopIsOwedRoom == found.desktopIsOwedRoom { places.after.desktopIsOwedRoom = left.desktopIsOwedRoom }
    closedPlaces[display] = places
  }

  /// Gives `window`, which just appeared or changed its title, the place that is kept for it: a slot that waits since Arbor
  /// started, or the one it had when its app ended. Returns false if there is none, and nothing has changed then.
  func goesBackToItsPlace(_ window: WindowSnapshot) -> Bool {
    if claimPendingSlot(for: window) { return true }
    guard let (display, gone) = placeKept(for: window) else { return false }
    guard !isHeld else {
      // Not when the view is let go either: that can come by itself, long after anybody thought of the app.
      Log.info("hold: \(window.id) floats; the places its app had are given up")
      forgetPlaces { $0.hint.bundleID == window.bundleID }
      return false
    }
    guard var places = closedPlaces.removeValue(forKey: display), let closed = places.windows.removeValue(forKey: gone),
      let found = workspaces[display]
    else { return false }
    defer { scheduleTidyingOfClosedPlaces() }
    let own = workspaces.values.lazy.compactMap { $0.floating[window.id] }.first ?? window.frame
    // As if only the others had gone: what it looks like depends on who is away, never on the order they come back in. So
    // nobody moves now for a window that is still away, and nothing waits in the tree for one that may never come.
    var earlier = places.before
    // With the view, the saved views, the names and the guests of today: a group can owe its existence to one of them.
    earlier.follow(whatKeepsGroupsIn: found, since: places.after)
    for other in places.windows.keys.sorted() { earlier.forget(other, shareSpace: settings.shareRemovedSpace) }
    // From here on it is a login, with one slot and the window for it: see there for a window that may not be the one.
    let nothingWaited = pendingSlots.isEmpty && provisionalSlots.isEmpty
    moveToStandIn(gone, hint: closed.hint, in: &earlier)
    guard let standIn = Set(earlier.tree.allWindows).subtracting(found.tree.allWindows).first else { return false }
    if nothingWaited { scheduleCheckOfPendingSlots() }
    // What was done meanwhile was done to an arrangement without the window, and taking it back would take it out again.
    let everybodyIsBack = places.windows.isEmpty && !places.someStayClosed
    undoHistory.rewriteSteps(on: display, madeWithout: standIn) { step in
      // "A window of … closed, which cannot be undone" is no longer so.
      if step.isIrreversible, everybodyIsBack { return nil }
      guard step.workspace.tree.isSameArrangement(as: places.after.tree),
        step.changedTo.tree.isSameArrangement(as: places.after.tree)
      else { return nil }
      var step = step
      step.workspace.restoreStructure(from: earlier, left: places.after)
      step.changedTo.restoreStructure(from: earlier, left: places.after)
      return step
    }
    workspaces[display]!.restoreStructure(from: earlier, left: places.after)
    // What was known of the window and of its slot is known again.
    if let known = closed.minimumSize { minimumSizes[window.id] = known }
    defer {
      provisionalSlots[window.id]?.minimumSize = closed.minimumSize
      provisionalSlots[window.id]?.isAfterARelaunch = true
    }
    let squeezed = places.squeezedByHand.filter { !found.tree.contains($0) && earlier.tree.contains($0) }
    if !squeezed.isEmpty { squeezedByHand[display, default: []].formUnion(squeezed) }
    scheduleSave()
    // The one layout.
    guard claimPendingSlot(for: window) else {
      relayout(display, reason: .structure)
      return false
    }
    isAnotherWindow(window.id, whichOpenedAt: own, on: display)
    if !places.windows.isEmpty {
      places.before.follow(whatWasDoneIn: found, since: places.after)
      places.before.renumber(gone, as: window.id)
      places.after = workspaces[display]!
      closedPlaces[display] = places
    }
    return true
  }

  /// `window` has the place of the window its app had before it ended, and its number in all that is kept from the past. It is
  /// another window all the same, and what it gets back when Arbor lets go of it (rule 5), or when the dock from back then is
  /// undone, is its own: where it opened, or was put since. Not what the window before it had before that was docked.
  func isAnotherWindow(_ window: WindowID, whichOpenedAt own: CGRect, on display: DisplayID) {
    workspaces[display]?.setOwnFrame(own, of: window)
    undoHistory.setOwnFrame(own, of: window)
  }

  /// The place `window` had before its app ended: the one with its title or, titles being what they are, the place of its app's
  /// only window if this is its only window again (as `claimPendingSlot(for:)` goes on to decide).
  private func placeKept(for window: WindowSnapshot) -> (display: DisplayID, window: WindowID)? {
    guard !closedPlaces.isEmpty, let bundleID = window.bundleID, mayTakeASlot(window) else { return nil }
    var kept: [(display: DisplayID, window: WindowID, title: String, hadSiblings: Bool)] = []
    for display in closedPlaces.keys.sorted() {
      let places = closedPlaces[display]!
      guard workspaces[display]?.tree.isSameArrangement(as: places.after.tree) == true else { continue }
      for (gone, closed) in places.windows.sorted(by: { $0.key < $1.key })
      where closed.appEndedAt != nil && closed.isKeptUntil >= now() && closed.hint.bundleID == bundleID
        && !closed.otherCopies.contains(window.pid)
      {
        kept.append((display, gone, closed.hint.title, closed.hadSiblings))
      }
    }
    if let exact = kept.first(where: { $0.title == window.title }) { return (exact.display, exact.window) }
    guard kept.count == 1, !kept[0].hadSiblings, slots(ofAppOf: window).isEmpty, isItsAppsOnlyWindowWithoutASlot(window)
    else { return nil }
    return (kept[0].display, kept[0].window)
  }
}
