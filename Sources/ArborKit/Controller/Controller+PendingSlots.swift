import ArborCore
import CoreGraphics

/// Saved slots that wait for their windows after launch.
///
/// `reconcile()` matches the saved trees against the windows the window system lists when Arbor
/// starts. A docked window that is not listed is not necessarily gone:
///
/// - **Its app has not restored it yet.** Arbor launches at login together with the apps whose
///   windows it arranged, and starts in a fraction of the time they need. Dropping those slots would
///   lose the arrangement at each login. The slot waits `pendingSlotLifetime` under a stand-in number;
///   the first window of the same app with the same title that appears (or is renamed to that title:
///   many apps name a restored window a moment after showing it) takes it over. So does a window
///   with another title, if the app has one slot waiting and one window to fill it; but what an app shows
///   first is often a welcome or sign-in window, so until the wait is over that window holds the slot
///   provisionally: a window with the saved title takes it over, and if the holder closes the slot waits again.
/// - **It is on a Space that is not showing**, where the Accessibility API does not list it. If the
///   window system says the number still exists (`existingWindowIDs()`), the slot waits under its own
///   number for as long as it does, and the window takes it back when its Space shows.
///
/// Like a minimized window, a waiting slot keeps its place in the tree and takes no space. The tree can be
/// that of a display that is not connected: the window then floats where it appears, and returns to the
/// slot with the display.
///
/// `resume` is a launch in all but this: what is missing after a pause was closed by the user, not by a
/// reboot, so only windows that still exist keep a slot.
extension Controller {
  /// How long a saved slot waits for a window that does not exist, and how often Arbor checks
  /// that the others still do, in seconds.
  public static let pendingSlotLifetime: Double = 180

  /// The window server counts up from a small number; stand-ins count down from the largest.
  static let firstStandIn: UInt32 = 0xFFFF_0000
  static func isStandIn(_ window: WindowID) -> Bool { window.rawValue >= firstStandIn }

  /// Keeps the slot of `window`, a saved docked window that is not listed now. Called by `reconcile()`.
  func keepSlotPending(
    of window: WindowID, hint: WindowHint, existing: Set<WindowID>, in workspace: inout Workspace
  ) {
    if pendingSlots.contains(window) {
      // It waits under its own number in another tree already. One window, one place: the first keeps it, as for a
      // listed window that a file has twice. (The caller has taken the hint out to hand it over; the first still needs it.)
      hints[window] = hint
      workspace.forget(window, shareSpace: settings.shareRemovedSpace)
    } else if existing.contains(window), windows[window] == nil, !Self.isStandIn(window) {
      hints[window] = hint
      pendingSlots.insert(window)
    } else if isResuming, !Self.isStandIn(window) {
      // Closed during the pause. (A stand-in was already waiting when the pause began, and goes on waiting.)
      workspace.forget(window, shareSpace: settings.shareRemovedSpace)
    } else {
      moveToStandIn(window, hint: hint, in: &workspace)
    }
  }

  /// Window numbers restart after a reboot, so a saved number may soon belong, or already belongs,
  /// to an unrelated window. The slot moves to a number no real window has.
  func moveToStandIn(_ window: WindowID, hint: WindowHint, in workspace: inout Workspace) {
    var candidate = UInt32.max
    func isTaken(_ id: WindowID) -> Bool {
      pendingSlots.contains(id) || windows[id] != nil || hints[id] != nil || workspace.contains(id)
        || workspaces.values.contains { $0.contains(id) } || dormant.values.contains { $0.workspace.contains(id) }
    }
    while isTaken(WindowID(candidate)), candidate > Self.firstStandIn { candidate -= 1 }
    let standIn = WindowID(candidate)
    guard !isTaken(standIn) else {
      // Tens of thousands are waiting already; only a damaged file gets here.
      workspace.forget(window, shareSpace: settings.shareRemovedSpace)
      pendingSlots.remove(window)
      return
    }
    workspace.replaceWindow(window, with: standIn)
    renumberInThePast(window, as: standIn)
    pendingSlots.remove(window)
    pendingSlots.insert(standIn)
    hints[standIn] = hint
  }

  /// Called at the end of `start()`.
  func startWaitingForPendingSlots() {
    // Windows that were already open under another title (`reconcile()` matches exact titles only).
    for id in managedWindowIDs where !pendingSlots.isEmpty {
      if let window = windows[id] { _ = claimPendingSlot(for: window) }
    }
    guard !isWaitOver else { return }
    Log.info("keeping \(pendingSlots.count) saved slot(s) for windows that are not in sight yet")
    scheduleCheckOfPendingSlots()
  }

  func scheduleCheckOfPendingSlots() {
    scheduler.schedule("pending-slots", after: Self.pendingSlotLifetime) { [weak self] in
      guard let self else { return }
      let existing = self.system.existingWindowIDs()
      self.provisionalSlots.removeAll()
      self.expireSlots { !existing.contains($0) }
      if !self.pendingSlots.isEmpty { self.scheduleCheckOfPendingSlots() }
    }
  }

  /// The wait of these slots is over. **Nothing moves by a timer**: a layout three minutes after login, with nobody touching
  /// anything, pushed the window somebody was typing in onto the Desktop. A waiting slot takes no space, so as a rule it
  /// can go without a window having to move, and then it goes now, without a layout. Where its going would move
  /// something (its room was shared out otherwise than its removal shares it), it stays, overdue, and
  /// goes with the next layout that somebody causes (`dropOverdueSlots`); until then it waits like any other.
  private func expireSlots(where isOver: (WindowID) -> Bool) {
    let over = pendingSlots.filter(isOver)
    // In what is remembered of a display that is not connected there is nothing to move.
    forgetPendingSlots { over.contains($0) && workspaceID(containing: $0) == nil }
    for display in Set(over.compactMap { workspaceID(containing: $0) }).sorted() {
      let slots = over.filter { workspaceID(containing: $0) == display }.sorted()
      guard let now = workspaces[display], let shown = layouts[display] else { continue }
      for slot in slots { workspaces[display]!.forget(slot, shareSpace: settings.shareRemovedSpace) }
      // The same picture, whatever the nodes are called by now (with the last slot the row around the Desktop goes too).
      guard let fresh = layout(of: display), fresh.windowFrames == shown.windowFrames, fresh.tiles == shown.tiles,
        fresh.desktopFrame == shown.desktopFrame, fresh.hiddenWindows == shown.hiddenWindows
      else {
        workspaces[display] = now
        overdueSlots.formUnion(slots)
        continue
      }
      for slot in slots {
        pendingSlots.remove(slot)
        overdueSlots.remove(slot)
        hints[slot] = nil
        parked.remove(slot)
      }
      // Arbor's own drawings go by the nodes of the tree.
      layouts[display] = fresh
      overlays.update(display: display, scene: overlayScene(for: fresh, on: display))
      notify(.layout(display))
      scheduleSave()
    }
  }

  /// At the head of a layout that a person or an app has caused.
  func dropOverdueSlots(on display: DisplayID) {
    guard !overdueSlots.isEmpty else { return }
    for slot in overdueSlots.sorted() where workspaces[display]?.isDocked(slot) == true {
      overdueSlots.remove(slot)
      guard pendingSlots.remove(slot) != nil else { continue }
      hints[slot] = nil
      parked.remove(slot)
      workspaces[display]!.forget(slot, shareSpace: settings.shareRemovedSpace)
      scheduleSave()
    }
    endWaitIfOver()
  }

  /// Gives `window`, which just appeared or changed its title, the saved slot that waits for it.
  /// Returns false if there is none, and the window is then an ordinary new window.
  func claimPendingSlot(for window: WindowSnapshot) -> Bool {
    guard !isWaitOver, drag?.window != window.id else { return false }
    if pendingSlots.contains(window.id) {
      // A slot waits under this very number.
      let connected = workspaceID(containing: window.id)
      let remembered = dormant.keys.sorted().first { dormant[$0]!.workspace.isDocked(window.id) }
      if hints[window.id]?.bundleID == window.bundleID {
        // The window itself, back in sight. Its title may have changed while it was away.
        if let connected {
          settle(window, on: connected)
          return true
        }
        // Its slot is on a display that is not connected. It floats here meanwhile.
        pendingSlots.remove(window.id)
        endWaitIfOver()
        return false
      }
      // Somebody else's window got the saved number after a reboot. The slot goes on waiting.
      let hint = hints.removeValue(forKey: window.id)
      if let hint, let connected, var workspace = workspaces[connected] {
        moveToStandIn(window.id, hint: hint, in: &workspace)
        workspaces[connected] = workspace
      } else if let hint, let remembered, var workspace = dormant[remembered]?.workspace {
        moveToStandIn(window.id, hint: hint, in: &workspace)
        dormant[remembered]!.workspace = workspace
      } else {
        pendingSlots.remove(window.id)
      }
    }
    if provisionalSlots[window.id]?.hint.title == window.title {
      // It was the right window all along, and only slow to say so.
      provisionalSlots[window.id] = nil
      endWaitIfOver()
    }
    guard mayTakeASlot(window) else { return false }
    let exact = slot(withTitleOf: window)
    if exact == nil, let taken = takeOverProvisionalSlot(for: window) { return taken }
    guard let slot = exact ?? onlySlot(ofAppOf: window) else { return false }
    // Where it goes back to if the slot turns out to be another window's.
    let openedAt = workspaces.values.lazy.compactMap { $0.floating[window.id] }.first ?? window.frame
    func holdProvisionally(in tree: LayoutTree) {
      guard exact == nil, let hint = hints[slot], let leaf = tree.leaf(containing: window.id) else { return }
      provisionalSlots[window.id] = ProvisionalSlot(hint: hint, leaf: leaf, openedAt: openedAt)
    }
    guard let display = workspaces.keys.sorted().first(where: { workspaces[$0]!.isDocked(slot) }) else {
      // The slot is on a display that is not connected: the window takes it over there, to return
      // to it with the display, and floats here meanwhile like any new window.
      for id in dormant.keys.sorted() { dormant[id]!.workspace.floating[window.id] = nil }
      for id in dormant.keys.sorted() where dormant[id]!.workspace.isDocked(slot) {
        dormant[id]!.workspace.replaceWindow(slot, with: window.id)
        holdProvisionally(in: dormant[id]!.workspace.tree)
        break
      }
      renumberInThePast(slot, as: window.id)
      hints[slot] = nil
      pendingSlots.remove(slot)
      endWaitIfOver()
      scheduleSave()
      return false
    }
    for id in workspaces.keys.sorted() { workspaces[id]!.floating[window.id] = nil }
    workspaces[display]!.replaceWindow(slot, with: window.id)
    renumberInThePast(slot, as: window.id)
    holdProvisionally(in: workspaces[display]!.tree)
    hints[slot] = nil
    pendingSlots.remove(slot)
    settle(window, on: display)
    return true
  }

  /// Whether `window` could be given a slot if one waited for it.
  func mayTakeASlot(_ window: WindowSnapshot) -> Bool {
    drag?.window != window.id && !hasSlot(window.id)
      && AppRule.firstMatch(in: settings.rules, bundleID: window.bundleID, title: window.title)?.action != .ignore
  }

  /// The waiting slots of the app of `window`: stand-ins first, in the order they were made.
  func slots(ofAppOf window: WindowSnapshot) -> [WindowID] {
    guard window.bundleID != nil else { return [] }
    return pendingSlots.sorted(by: >).filter { hints[$0]?.bundleID == window.bundleID }
  }

  /// The slot of the same app and title.
  private func slot(withTitleOf window: WindowSnapshot) -> WindowID? {
    slots(ofAppOf: window).first { hints[$0]?.title == window.title }
  }

  /// Titles being what they are (Mail counts messages in its, a chat app marks what is unread): the app's
  /// slot if it has only one waiting and `window` is its only window that is not docked.
  private func onlySlot(ofAppOf window: WindowSnapshot) -> WindowID? {
    let ofApp = slots(ofAppOf: window)
    // A slot that waits under its own number waits for that very window.
    guard ofApp.count == 1, Self.isStandIn(ofApp[0]) else { return nil }
    return isItsAppsOnlyWindowWithoutASlot(window) ? ofApp[0] : nil
  }

  func isItsAppsOnlyWindowWithoutASlot(_ window: WindowSnapshot) -> Bool {
    let loose = windows.values.filter { other in
      other.bundleID == window.bundleID && filter.manages(other) && !hasSlot(other.id)
    }
    return loose.count == 1
  }

  /// Whether `window` is docked already, be it on a display that is not connected.
  private func hasSlot(_ window: WindowID) -> Bool {
    workspaces.values.contains { $0.isDocked(window) } || dormant.values.contains { $0.workspace.isDocked(window) }
  }

  private func settle(_ window: WindowSnapshot, on display: DisplayID) {
    pendingSlots.remove(window.id)
    hints[window.id] = WindowHint(bundleID: window.bundleID, title: window.title)
    endWaitIfOver()
    Log.info("\(window.id) is back in its saved slot")
    // By the time Arbor hears of a new window it has the keyboard as a rule, and the view goes to whoever has it, as a tab
    // comes to the front. First, so that the window is moved once, to where it ends up, and not out of view on the way.
    let view = workspaces[display]?.camera
    let layoutsBefore = layoutsMade[display]
    if system.focusedWindow() == window.id, let tree = workspaces[display]?.tree, let view,
      let leaf = tree.leaf(containing: window.id),
      !tree.subtree(view, contains: leaf) || tree.activeWindow(of: leaf) != window.id
    {
      bringIntoViewIfFocused(window.id, retries: 0)
    }
    if layoutsMade[display] == layoutsBefore { relayout(display, reason: .structure) }
    scheduleSave()
  }

  /// `window` is back in sight, and Arbor no longer arranges it: its app was excluded while its slot waited under its
  /// number. Left in the tree it would take up room from now on, and be moved there by the next layout.
  func giveUpPendingSlot(of window: WindowID) {
    guard pendingSlots.contains(window) else { return }
    forgetPendingSlots { $0 == window }
    endWaitIfOver()
  }

  /// Drops the slots waiting on `display`: the user has rearranged everything there.
  func forgetPendingSlots(on display: DisplayID) {
    forgetPendingSlots { [self] in workspaceID(containing: $0) == display }
    provisionalSlots = provisionalSlots.filter { workspaceID(containing: $0.key) != display }
    endWaitIfOver()
  }

  /// Drops the slots that are in no tree any more: `undo` has put back an arrangement from before they were there.
  func forgetPendingSlotsWithoutAPlace() {
    forgetPendingSlots { [self] in !hasSlot($0) }
    // Not while a window holds a slot provisionally: if it closes, the slot waits again, and something has to end that.
    endWaitIfOver()
  }

  private func forgetPendingSlots(where isOver: (WindowID) -> Bool) {
    var changed = Set<DisplayID>()
    for slot in pendingSlots.sorted() where isOver(slot) {
      pendingSlots.remove(slot)
      overdueSlots.remove(slot)
      hints[slot] = nil
      parked.remove(slot)
      forgetInDormantWorkspaces(slot)
      if let home = workspaceID(containing: slot) {
        workspaces[home]!.forget(slot, shareSpace: settings.shareRemovedSpace)
        changed.insert(home)
      }
      scheduleSave()
    }
    for id in changed.sorted() { relayout(id, reason: .structure) }
  }

  // MARK: Slots held provisionally

  /// A window that took a waiting slot because it was its app's only window, and the slot its app's only slot.
  struct ProvisionalSlot {
    /// What the slot was waiting for.
    var hint: WindowHint
    /// Where in the tree. If the window is anywhere else by now, the user has decided about it.
    var leaf: NodeID
    var openedAt: CGRect
    /// How small the window that had the slot was found to go, if that was lent to the holder (Controller+RelaunchedApps.swift).
    var minimumSize: CGSize? = nil
    /// The slot is that of an app that was quit and opened again, not one saved by an earlier run.
    var isAfterARelaunch = false
  }

  private var isWaitOver: Bool { pendingSlots.isEmpty && provisionalSlots.isEmpty }

  private func endWaitIfOver() {
    if isWaitOver { scheduler.cancel("pending-slots") }
  }

  /// Gives `window`, which has the title a slot was waiting for, that slot in place of the window that
  /// holds it meanwhile. Nil if there is none. Otherwise as `claimPendingSlot(for:)`: true if it is docked
  /// on a connected display now.
  private func takeOverProvisionalSlot(for window: WindowSnapshot) -> Bool? {
    let wanted = WindowHint(bundleID: window.bundleID, title: window.title)
    guard window.bundleID != nil,
      let holder = provisionalSlots.keys.sorted().first(where: { provisionalSlots[$0]!.hint == wanted }),
      let held = provisionalSlots.removeValue(forKey: holder)
    else { return nil }
    defer { endWaitIfOver() }
    if let display = workspaces.keys.sorted().first(where: { workspaces[$0]!.tree.leaf(containing: holder) == held.leaf }) {
      let own = workspaces.values.lazy.compactMap { $0.floating[window.id] }.first ?? window.frame
      for id in workspaces.keys.sorted() { workspaces[id]!.floating[window.id] = nil }
      workspaces[display]!.replaceWindow(holder, with: window.id)
      renumberInThePast(holder, as: window.id)
      if held.isAfterARelaunch { isAnotherWindow(window.id, whichOpenedAt: own, on: display) }
      // The one that came first is a new window after all. It floats where its app had put it.
      let home = displayID(at: held.openedAt.center).flatMap { workspaces[$0] == nil ? nil : $0 } ?? display
      workspaces[home]!.floating[holder] = held.openedAt
      if let actual = system.setFrame(held.openedAt, of: holder) { windows[holder]?.frame = actual }
      parked.remove(holder)
      settled[holder] = nil
      misfits[holder] = nil
      if let known = held.minimumSize { (minimumSizes[window.id], minimumSizes[holder]) = (known, nil) }
      Log.info("\(window.id) takes the saved slot over from \(holder)")
      settle(window, on: display)
      return true
    }
    for id in dormant.keys.sorted() where dormant[id]!.workspace.tree.leaf(containing: holder) == held.leaf {
      dormant[id]!.workspace.floating[window.id] = nil
      dormant[id]!.workspace.replaceWindow(holder, with: window.id)
      renumberInThePast(holder, as: window.id)
      scheduleSave()
      return false
    }
    return nil
  }

  /// `window`, docked on `display`, has closed. If it held its slot provisionally, the slot waits again (a
  /// welcome window often closes just before the real one opens) and this returns true.
  func slotWaitsAgain(after window: WindowID, on display: DisplayID) -> Bool {
    guard let held = provisionalSlots.removeValue(forKey: window) else { return false }
    guard var workspace = workspaces[display], workspace.tree.leaf(containing: window) == held.leaf else {
      endWaitIfOver()
      return false
    }
    moveToStandIn(window, hint: held.hint, in: &workspace)
    workspaces[display] = workspace
    return true
  }

  // MARK: Telling about it

  /// For `state`: without it, the tree shows numbers that no window has.
  var waitingSlots: [StateSnapshot.Waiting] {
    pendingSlots.sorted().map { slot in
      StateSnapshot.Waiting(
        id: slot, bundleID: hints[slot]?.bundleID, title: hints[slot]?.title ?? "",
        display: workspaceID(containing: slot) ?? dormant.keys.sorted().first { dormant[$0]!.workspace.contains(slot) },
        open: !Self.isStandIn(slot))
    }
  }

  /// For `status` and the menu. Windows on another Space are open, and docked as far as anyone is concerned.
  var keptPlacesNotice: String? {
    switch pendingSlots.filter(Self.isStandIn).count {
    case 0: nil
    case 1: "1 place kept for a window that is not open yet"
    case let count: "\(count) places kept for windows that are not open yet"
    }
  }
}
