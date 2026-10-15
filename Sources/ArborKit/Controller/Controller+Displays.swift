import ArborCore
import CoreGraphics
import Foundation

/// Displays going away and coming back.
///
/// When a display disconnects, its workspace is kept as dormant (in memory and
/// in state.json) and its windows float on the main display. When it
/// reconnects, the workspace comes back: windows that are still open and not
/// docked anywhere else return to their slots, and the rest are dropped from
/// the restored tree. Dormant workspaces are discarded at launch once they are
/// older than `dormantLifetime`.
extension Controller {
  /// How long the arrangement of a disconnected display is kept.
  static let dormantLifetime: TimeInterval = 30 * 24 * 60 * 60

  /// Matches the workspaces to the connected displays. Called when displays
  /// are added or removed and when their frames change.
  ///
  /// With `lettingGo` only the books are brought up to date and nothing is moved, raised or focused: for `shutdown`, which
  /// moves every window itself, once (`lookAtTheDisplaysBeforeLettingGo`).
  func updateDisplays(lettingGo: Bool = false) {
    // If windows were moved behind Arbor's back, here is the report after all. What follows looks after every window.
    movedBehindArborsBack = []
    scheduler.cancel("displays-blinked")
    overlays.finishAnimations()
    let previous = Set(workspaces.keys)
    let before = displays
    displays = system.displays()
    followDisplaysThatMoved(since: before)
    endUndoHistoryIfDisplaysMoved(
      since: Dictionary(before.map { ($0.id, $0.frame.origin) }) { first, _ in first },
      sizes: Dictionary(before.map { ($0.id, $0.frame.size) }) { first, _ in first })
    // macOS moves windows when displays change, and when the primary display changes every window's
    // coordinates do, without a notification for each. Deciding by the old frames which windows are
    // already in place would leave some where they are.
    for snapshot in system.allWindows() { windows[snapshot.id]?.frame = snapshot.frame }
    decideAboutWindowsFoundInTheDark()
    let current = Set(displays.map(\.id))
    let added = current.subtracting(previous).sorted()
    let removed = previous.subtracting(current).sorted()

    // New displays get a workspace before anything is evacuated, in case the
    // new main display is one of them.
    for id in added { workspaces[id] = Workspace() }
    var arriving: [WindowID] = []
    for id in removed { arriving += retireWorkspace(of: id, whichWasAt: before.first { $0.id == id }?.frame.origin) }
    // A display that has only just come takes nothing away. Its arrangement sleeps on, for the next start: windows that
    // lie still are not sent over to it a moment before they are let go of.
    if !lettingGo { for id in added { arriving += restoreDormantWorkspace(of: id) } }
    // Windows that had no display to go to (every display was gone).
    let homeless = managedWindowIDs.filter { workspaceID(containing: $0) == nil }
    adoptNewlyManagedWindows()
    rememberPlaces(of: homeless)
    restoreRoles(of: homeless)
    layouts = layouts.filter { current.contains($0.key) }
    keyframes = keyframes.filter { current.contains($0.key) }
    let arrivingInView = placeArrivingWindows(arriving, parkingLater: true)

    // A drag may be over, or have moved windows on, a display that went away or changed shape.
    displaysChangedDuringDrag()
    Log.info("displays changed: \(displays.count) display(s), \(dormant.count) remembered")
    // A lower resolution or a display that moved can leave windows beyond the edges of them all.
    treatStrandedWindowsAsParked()
    guard !lettingGo else { return }
    // A display that came or went sent windows to another arrangement, whose view may not include the one being
    // typed in. As after a resume, it ends with that window in view. Before anything is laid out, so that every
    // window moves once. Any other report moves no window and no view. Nor is there anything to do for a window that
    // arrives on a Desktop in view: it only counts as out of view until the layout below has placed it, and a hold would
    // take it for a window out of view that took the keyboard unasked, and give the keyboard to another.
    if !added.isEmpty || !removed.isEmpty, let focused = system.focusedWindow(), !arrivingInView.contains(focused) {
      bringIntoViewIfFocused(focused)
    }
    relayoutAll(reason: .camera, motion: .instant)
    parkAgain()
    scheduleSave()
  }

  // MARK: A display that moved

  /// How long ago a window may have spoken of its place for that to count at a change of displays. The report that slips
  /// past the guard comes before macOS's FIRST notice of the change, and Arbor hears 1.5 s after the LAST
  /// (`DisplayChange`); several come at a plug, and a dock negotiates for seconds. Generous, because it costs next to
  /// nothing: a place given by hand meanwhile no longer says where the window is once macOS has taken it along, and
  /// goes with the corner however lately. It errs only if an app speaks, then hangs, and then the corner moves.
  static let spokenLately: TimeInterval = 30

  /// The frames a workspace remembers are global, and a display's place among the displays changes: whenever another
  /// one becomes the main display (a lid closes or opens) every coordinate does, and displays can be rearranged. macOS
  /// takes the windows along. A frame left behind would be a place on another part of the display, or beyond it; and
  /// where it happened to overlap the display by a strip, it passed for a place somebody had chosen (`reach`).
  private func followDisplaysThatMoved(since before: [DisplaySnapshot]) {
    // Asked for only if a display moved.
    lazy var whereWindowsAre = Dictionary(system.allWindows().map { ($0.id, $0.frame.origin) }) { first, _ in first }
    let lately = now().addingTimeInterval(-Self.spokenLately)
    for display in displays {
      guard let old = before.first(where: { $0.id == display.id })?.frame, old.origin != display.frame.origin else {
        continue
      }
      let offset = CGPoint(x: display.frame.minX - old.minX, y: display.frame.minY - old.minY)
      func moved(_ frame: CGRect) -> CGRect { frame.offsetBy(dx: offset.x, dy: offset.y) }
      // An app may have said where its window is now before anybody could know that the displays were changing
      // (`knowsTheDisplays` has nothing to see yet). That passed for the person's own move, so the place is in the new
      // coordinates already: moved again it would be as far off on the other side. The window is the witness: a place
      // that says where its window really is stays. But only if the window has spoken lately: the two also agree when
      // nothing moved the window, and when its app hangs and what is read is what was read before.
      let ahead = (workspaces[display.id]?.floating ?? [:]).filter { window, frame in
        guard let spoke = spokeOfItsPlace[window], spoke >= lately, let real = whereWindowsAre[window] else { return false }
        return abs(real.x - frame.minX) <= 1 && abs(real.y - frame.minY) <= 1
      }
      workspaces[display.id]?.shift(by: offset)
      for (window, frame) in ahead { workspaces[display.id]?.floating[window] = frame }
      // What the controller itself remembers of those windows, or it would no longer agree with the workspace.
      for window in workspaces[display.id]?.allWindows ?? [] where ahead[window] == nil {
        appPlacedFrames[window] = appPlacedFrames[window].map(moved)
        settled[window] = settled[window].map(moved)
        misfits[window] = misfits[window].map { (moved($0.slot), moved($0.frame)) }
        chosenOnShape[window] = chosenOnShape[window].map { (moved($0.frame), moved($0.display)) }
      }
      for (window, frame) in owedTheWayBack where old.contains(frame.center) { owedTheWayBack[window] = moved(frame) }
    }
  }

  /// An undo step holds workspaces and frames as they were, in the coordinates of the displays as they stood. Once a
  /// display that stays has another corner, going back to a step would put windows where those numbers now point:
  /// elsewhere on the display or beyond its edge, with no way back (the chaos lab, 2026-10-14). So that ends the history, on
  /// every display, since a step can span several: ⌃⌥Z has nothing to undo. A display that goes loses its own history
  /// anyway (`retireWorkspace`), and the others keep theirs while their frames stay (F19). Another size does the same
  /// as another corner: of a step's frame on a display that shrank a strip may still show, which passes for a place
  /// somebody chose. The Dock and the menu bar change neither. `sizes` is left out where they are not known
  /// (state.json has the corners only).
  func endUndoHistoryIfDisplaysMoved(since corners: [DisplayID: CGPoint], sizes: [DisplayID: CGSize] = [:]) {
    guard
      displays.contains(where: { display in
        corners[display.id].map { $0 != display.frame.origin } ?? false
          || sizes[display.id].map { $0 != display.frame.size } ?? false
      })
    else { return }
    for id in Set(corners.keys).union(displays.map(\.id)) { undoHistory.removeAll(on: id) }
    // They hold workspaces from the past as well (Controller+RelaunchedApps.swift).
    forgetClosedPlaces()
  }

  /// For a workspace read from a file that does not say where its display was (written before 2026-10-14): its frames may
  /// be from another arrangement of the displays, and there is no telling. A window that is in view on the display is
  /// where macOS took it along to, which is the better witness; any other frame is fitted onto the display, not
  /// trusted. It costs a window left hanging over an edge on purpose its overhang, once.
  func healFramesOfUnknownOrigin(on display: DisplaySnapshot) {
    guard let workspace = workspaces[display.id] else { return }
    for (window, remembered) in workspace.floating.sorted(by: { $0.key < $1.key }) {
      if let actual = windows[window]?.frame, windows[window]?.isPresent == true,
        actual.intersection(display.visibleFrame).area * 2 > actual.area
      {
        workspaces[display.id]!.floating[window] = actual
      } else {
        workspaces[display.id]!.floating[window] = remembered.fitted(into: display.visibleFrame)
      }
    }
  }

  // MARK: A display that only blinked

  /// Whether the displays macOS has are the ones Arbor was told of: which there are, and where and how large each is. A
  /// display that stays can get another corner (System Settings, its neighbour's scaling, the menu bar dragged over), and
  /// until Arbor hears, what apps say of their windows is in coordinates it cannot read: it would take the move for the
  /// person's own, judge by the old frames which display the window is on, and move the frame again with the corner.
  /// Not their order, which is never reported by itself, nor the Dock and the menu bar.
  var knowsTheDisplays: Bool {
    func frames(_ list: [DisplaySnapshot]) -> [DisplayID: CGRect] { Dictionary(list.map { ($0.id, $0.frame) }) { first, _ in first } }
    return frames(system.displays()) == frames(displays)
  }

  /// Look before letting go. Arbor hears of a change of displays only once it has settled, a second and a half after
  /// macOS's last notice (`DisplayChange`). Whoever quits or pauses within that time, a laptop pulled off its dock and shut,
  /// would have every window given back its own earlier frame by the displays Arbor still believes in: on a display that is
  /// gone, and after a quit nobody is left to fetch it. The last net of `shutdown` reads the same displays. So Arbor
  /// reads them now, and lets go by the displays that are.
  ///
  /// It brings its books up to date and moves nothing: which displays there are, whose arrangement sleeps, who has to come
  /// over. A layout now would move windows that are moved again a moment later, follow the keyboard, and park.
  ///
  /// Only if a display it believes in is gone, or is elsewhere or of another size: one that has only just come takes
  /// nothing away. And not while there is no display at all, as for a moment on wake and when docking: then there is
  /// nothing to go by, and what Arbor believes in is the best guess at what comes back.
  func lookAtTheDisplaysBeforeLettingGo() {
    guard isRunning else { return }
    let real = Dictionary(system.displays().map { ($0.id, $0.frame) }) { first, _ in first }
    guard !real.isEmpty, displays.contains(where: { real[$0.id] != $0.frame }) else { return }
    Log.info("letting go before a change of displays was reported: looking at the displays first")
    updateDisplays(lettingGo: true)
  }

  /// macOS moved `window` because a display came or went that Arbor has not heard of yet. If the report comes,
  /// `updateDisplays` puts every window where it belongs. If the display only blinked, on wake or while a dock
  /// negotiates, there never is a report (`DisplayChange`), and nobody else would: the move was not the user's, so nothing
  /// followed it, and it is not put back at once, because there may be no display to put it back on.
  func noteMoveBehindArborsBack(of window: WindowID) {
    movedBehindArborsBack.insert(window)
    lookForABlink(triesLeft: Self.blinkTries)
  }

  /// How often Arbor asks whether the displays are the ones it knows again: for half a minute after the last move.
  static let blinkTries = 15

  private func lookForABlink(triesLeft: Int) {
    // By then a report that was due has come.
    scheduler.schedule("displays-blinked", after: DisplayChange.comingAndGoing + 0.5) { [weak self] in
      self?.putBackAfterABlink(triesLeft: triesLeft - 1)
    }
  }

  private func putBackAfterABlink(triesLeft: Int) {
    guard isRunning else { return movedBehindArborsBack = [] }
    // The displays go on changing, which holds the report back. Ask again, but not for ever: that was no blink, and
    // the report, whenever it comes, looks after every window.
    guard knowsTheDisplays else {
      if triesLeft > 0 { lookForABlink(triesLeft: triesLeft) } else { movedBehindArborsBack = [] }
      return
    }
    // What macOS has put back itself by now is left alone: a docked window in its slot by the layout, a floating one here.
    let moved = movedBehindArborsBack.sorted().filter { window in
      guard let home = workspaceID(containing: window).flatMap({ workspaces[$0]!.floating[window] }) else { return true }
      return windows[window]?.frame.approximatelyEquals(home, tolerance: 1) != true
    }
    movedBehindArborsBack = []
    Log.info("a display blinked: \(moved.count) window(s) that macOS moved meanwhile are looked after")
    placeArrivingWindows(moved)
    relayoutAll(reason: .camera, motion: .instant)
    parkAgain()
  }

  /// Keeps the workspace of a display that went away as dormant and floats
  /// its windows on the main display. Returns the windows that moved.
  func retireWorkspace(of displayID: DisplayID, whichWasAt corner: CGPoint? = nil) -> [WindowID] {
    guard var workspace = workspaces.removeValue(forKey: displayID) else { return [] }
    // A peek on it ends at its next tick, which no longer finds the workspace.
    workspace.stayAfterALook()
    if namePrompt?.display == displayID { namePrompt = nil }
    undoHistory.removeAll(on: displayID)
    closedPlaces[displayID] = nil
    overlays.update(display: displayID, scene: OverlayScene())
    // Without a window there can still be a name to come back to: the Desktop of a second display, say (F20).
    if !workspace.allWindows.isEmpty || !workspace.names.isEmpty {
      // A window docked here was docked after any older dormant workspace
      // that still lists it went away, so this is the arrangement to keep.
      for window in workspace.tree.allWindows { forgetInDormantWorkspaces(window) }
      dormant[displayID] = DormantWorkspace(workspace: workspace, since: now(), origin: corner)
      Log.info("display \(displayID) disconnected; remembering \(workspace.allWindows.count) window(s)")
    }
    guard let main = mainDisplayID, let mainDisplay = display(main), workspaces[main] != nil else {
      return []
    }
    // Each window keeps its size and its place relative to the display's corner. A parked window's
    // own frame says neither: a floating one has the frame the user gave it, a docked one is centred.
    let visible = mainDisplay.visibleFrame
    let origin = layouts[displayID]?.frame.origin ?? visible.origin
    // A slot that waits for its window stays behind with the arrangement: there is nothing to float.
    let moving = workspace.allWindows.filter { !pendingSlots.contains($0) }
    for window in moving {
      // A docked window floats at its own size meanwhile, not at the size of a slot on another display.
      let own = workspace.undockedFrame(of: window)
      var frame = workspace.floating[window] ?? own ?? windows[window]?.frame ?? visible
      // One nobody remembers a size for may still be as small as it was made out of view, with or without the mark.
      if own == nil, workspace.isDocked(window) { frame.size = sizeInView(of: window) ?? frame.size }
      if own == nil, workspace.isDocked(window), parked.contains(window) {
        frame.origin = CGPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
      } else {
        frame = frame.offsetBy(dx: visible.minX - origin.x, dy: visible.minY - origin.y)
      }
      workspaces[main]!.floating[window] = frame.fitted(into: visible)
      workspaces[main]!.setRole(workspace.role(of: window), of: window)
    }
    return moving
  }

  /// Brings back the arrangement `displayID` had when it went away. Windows
  /// that are still open and not docked anywhere else return to their slots
  /// (floating ones to their frames); the rest are dropped from the restored
  /// tree, which moves the camera, history and saved views to the nodes that
  /// remain. Returns the windows that came back.
  func restoreDormantWorkspace(of displayID: DisplayID) -> [WindowID] {
    guard let entry = dormant.removeValue(forKey: displayID) else { return [] }
    let arrived = workspaces[displayID] ?? Workspace()
    guard arrived.tree.allWindows.isEmpty else {
      // Only a state file listing the display as both connected and
      // disconnected gets here. Keep the arrangement in use.
      Log.info("display \(displayID) already has an arrangement; discarding the remembered one")
      return []
    }
    var restored = entry.workspace
    // It may have come back somewhere else: beside the laptop whose lid was shut when it left, say.
    if let old = entry.origin, let new = display(displayID)?.frame.origin {
      let offset = CGPoint(x: new.x - old.x, y: new.y - old.y)
      restored.shift(by: offset)
      for window in restored.allWindows {
        appPlacedFrames[window] = appPlacedFrames[window].map { $0.offsetBy(dx: offset.x, dy: offset.y) }
      }
    } else if let visible = display(displayID)?.visibleFrame {
      // Nobody knows where it was (`healFramesOfUnknownOrigin`). Its windows are on other displays by now.
      for (window, frame) in restored.floating { restored.floating[window] = frame.fitted(into: visible) }
    }
    var returning: [WindowID] = []
    for window in restored.allWindows {
      let dockedElsewhere = workspaces.values.contains { $0.isDocked(window) }
      // Pinned since the display went away, or summoned right now: told to stay where it is.
      let role = role(of: window)
      let neededElsewhere = role == .pinned ? !restored.isPinned(window) : staysInView(window)
      if pendingSlots.contains(window) {
        continue  // still waiting for its window, now on this display
      } else if isManaged(window) && !dockedElsewhere && !neededElsewhere {
        returning.append(window)
      } else {
        restored.forget(window, shareSpace: settings.shareRemovedSpace)
      }
    }
    // Pinned or not, stashed or not: as it is now, which may have changed since the display went away. (With no
    // display in between it floats nowhere, and nothing was said.)
    for window in returning where workspaceID(containing: window) != nil {
      restored.setRole(role(of: window), of: window)
    }
    for window in returning {
      for id in workspaces.keys.sorted() { workspaces[id]!.floating[window] = nil }
    }
    // Windows that floated onto the display before its arrangement came back
    // (at launch, or evacuated from another display) keep floating on it.
    for (window, frame) in arrived.floating where !restored.contains(window) {
      restored.floating[window] = frame
      if arrived.isPinned(window) { restored.pin(window) }
    }
    workspaces[displayID] = restored
    Log.info("display \(displayID) reconnected; \(returning.count) window(s) returned to it")
    return returning
  }

  /// Sends windows that changed workspace because of a display change where
  /// that workspace wants them. Docked windows are left to the next relayout,
  /// which puts them in their slots or parks them. Floating windows go onto
  /// the Desktop if it is in view and out of view if it is not, like the
  /// other floating windows there. With `parkingLater` none is moved yet: they only count as out of view, for a caller
  /// that may still move the view, then lays out, and ends with `parkAgain`. Returns the ones the next layout puts in view.
  @discardableResult
  func placeArrivingWindows(_ arriving: [WindowID], parkingLater: Bool = false) -> Set<WindowID> {
    var desktopInView: [DisplayID: Bool] = [:]
    var inViewSoon: Set<WindowID> = []
    // The window in the user's hand stays there, whichever workspace it belongs to now.
    for window in Set(arriving).sorted() where window != drag?.window {
      guard let displayID = workspaceID(containing: window), let display = display(displayID) else {
        continue
      }
      if workspaces[displayID]!.isDocked(window) {
        parked.remove(window)
        continue
      }
      // As a tile too (`floatingMoves`).
      let tree = workspaces[displayID]!.tree
      let inView =
        desktopInView[displayID] ?? layout(of: displayID).map { tree.subtree($0.camera, contains: tree.desktop) } ?? false
      desktopInView[displayID] = inView
      let stashed = workspaces[displayID]!.isStashed(window)
      if inView, !stashed { inViewSoon.insert(window) }
      if !parkingLater, !inView || stashed, windows[window]?.isPresent == true, !staysInView(window) {
        park(window, on: display)
      } else {
        // relayout moves parked floating windows to their frame on the Desktop.
        parked.insert(window)
      }
    }
    return inViewSoon
  }

  /// Where `window` was of its own accord, by the arrangement of a display that is gone: where it floated, or where it
  /// floated before it was docked (F48), which is also the size it had. The frame it has now says neither if it
  /// is out of view: that is a corner, and for a docked window the shape of its slot.
  func frameRememberedWithADisplayThatWent(of window: WindowID) -> CGRect? {
    dormant.keys.sorted().lazy.compactMap { id -> CGRect? in
      guard let workspace = self.dormant[id]?.workspace else { return nil }
      return workspace.floating[window] ?? workspace.undockedFrame(of: window)
    }.first
  }

  /// Windows that were out of view when the last display went are still in its corner, which can be anywhere on the
  /// display that came instead. That is not a place anybody chose: each goes where the user had it, floating or before
  /// it was docked, and to the middle if that is not known. They count as parked until the layout has moved them.
  func rememberPlaces(of adopted: [WindowID]) {
    for window in adopted where parked.contains(window) {
      guard let home = workspaceID(containing: window), let visible = display(home)?.visibleFrame,
        let size = windows[window]?.frame.size
      else { continue }
      let remembered = frameRememberedWithADisplayThatWent(of: window)
      let middle = CGRect(
        x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
      workspaces[home]!.floating[window] = (remembered ?? middle).fitted(into: visible)
    }
  }

  /// Sends the windows that are still parked after a display change to the corner that is out of view
  /// with the displays as they are now. The old corner can be in the middle of a display that grew, or on
  /// one plugged in beside it.
  func parkAgain() {
    for window in parked.sorted() {
      guard let displayID = workspaceID(containing: window), let display = display(displayID),
        let frame = windows[window]?.frame
      else { continue }
      // macOS stops a window short of the corner (`parkingOrigin`). One that is where it would stop again stays.
      let corner = parkingOrigin(for: frame.size, on: display)
      let stop = whereItStops(corner).y
      if abs(frame.minX - corner.x) <= 1, abs(frame.minY - corner.y) <= 1 || abs(frame.minY - stop) <= 1 { continue }
      park(window, on: display)
      parkedAgain[window] = nil  // nobody is fighting over it
    }
  }

  /// Removes a window from every dormant workspace, dropping workspaces left
  /// with no windows.
  func forgetInDormantWorkspaces(_ window: WindowID) {
    for id in dormant.keys.sorted() where dormant[id]!.workspace.contains(window) {
      dormant[id]!.workspace.forget(window, shareSpace: settings.shareRemovedSpace)
      if dormant[id]!.workspace.allWindows.isEmpty { dormant[id] = nil }
    }
  }

  // MARK: Launch

  /// At launch, after `reconcile()`: takes in the dormant workspaces saved
  /// last time, minus those older than `dormantLifetime`, and the saved
  /// workspaces of displays that are missing now; checks their windows
  /// against the windows that exist; and restores the ones whose display is
  /// connected again. `savedHints` are the hints as loaded, before
  /// `reconcile()` changed them.
  func resumeDormantWorkspaces(from saved: PersistedState?, hints savedHints: [WindowID: WindowHint]) {
    guard let saved else { return }
    let connected = Set(displays.map(\.id))
    let now = self.now()
    for (id, entry) in saved.dormant.sorted(by: { $0.key < $1.key }) {
      // Either way, so that a date that makes no sense (far in the future, not a number) goes too.
      guard abs(now.timeIntervalSince(entry.since)) <= Self.dormantLifetime else {
        Log.info("discarding the arrangement of display \(id): it was disconnected too long ago")
        continue
      }
      dormant[id] = entry
    }
    // Arbor last ran with these displays connected; they went away since.
    var withRolesOnMissingDisplays: [WindowID] = []
    for (id, workspace) in saved.workspaces
    where !connected.contains(id) && dormant[id] == nil && !workspace.allWindows.isEmpty {
      dormant[id] = DormantWorkspace(workspace: workspace, since: now, origin: saved.origins?[id])
      withRolesOnMissingDisplays += workspace.floating.keys.filter { workspace.role(of: $0) != nil }.sorted()
    }
    reconcileDormantWindows(hints: savedHints)
    restoreRoles(of: withRolesOnMissingDisplays)
    var returning: [WindowID] = []
    for id in connected.sorted() where dormant[id] != nil {
      returning += restoreDormantWorkspace(of: id)
    }
    placeArrivingWindows(returning)
  }

  /// Checks the windows of the dormant workspaces against the windows that
  /// exist now, as `reconcile()` does for connected displays: a docked window
  /// that is gone, or whose number now belongs to another app, is matched
  /// again by app and title among the windows not docked anywhere, or
  /// keeps its slot waiting for a while. Floating windows are not matched again.
  private func reconcileDormantWindows(hints savedHints: [WindowID: WindowHint]) {
    let managed = Set(managedWindowIDs)
    func isValid(_ window: WindowID) -> Bool {
      guard managed.contains(window) else { return false }
      guard let hint = savedHints[window], let snapshot = windows[window] else { return true }
      return hint.bundleID == snapshot.bundleID
    }
    // Candidates exclude docked windows (they are arranged elsewhere) and
    // windows a dormant workspace already lists under their own number.
    var taken = Set(workspaces.values.flatMap(\.tree.allWindows))
    taken.formUnion(dormant.values.flatMap(\.workspace.allWindows).filter(isValid))
    var rematched: [WindowID: WindowID] = [:]
    var unmatched = Set<WindowID>()
    let existing = system.existingWindowIDs()

    for id in dormant.keys.sorted() {
      var workspace = dormant[id]!.workspace
      for window in workspace.tree.allWindows where !isValid(window) {
        var replacement = rematched[window]
        if replacement == nil, !unmatched.contains(window) {
          replacement = savedHints[window].flatMap { hint in
            windows.values
              .filter {
                managed.contains($0.id) && !taken.contains($0.id) && $0.bundleID == hint.bundleID
                  && $0.title == hint.title
              }
              .map(\.id).min()
          }
          if let replacement {
            rematched[window] = replacement
            taken.insert(replacement)
          } else {
            unmatched.insert(window)
          }
        }
        if let replacement, !workspace.contains(replacement) {
          workspace.replaceWindow(window, with: replacement)
          renumberInThePast(window, as: replacement)
        } else if replacement == nil, let hint = savedHints[window],
          // Not for a window that is here, the same app's as before, and no longer arranged.
          windows[window] == nil || windows[window]?.bundleID != hint.bundleID
        {
          // Its app may not have restored it yet (Controller+PendingSlots.swift).
          keepSlotPending(of: window, hint: hint, existing: existing, in: &workspace)
        } else {
          workspace.forget(window, shareSpace: settings.shareRemovedSpace)
        }
      }
      for window in workspace.floating.keys.sorted() where !isValid(window) {
        workspace.floating[window] = nil
      }
      if workspace.allWindows.isEmpty {
        dormant[id] = nil
      } else {
        dormant[id]!.workspace = workspace
      }
    }
  }
}
