import ArborCore
import CoreGraphics

/// Pinned windows (docs/features/F49-pin.md): companions to whatever you are doing, such as a video
/// call, a timer, a music player or a reference document.
///
/// A pinned window floats, but it does not live on the Desktop as other floating windows do. It
/// keeps its place on the display through every camera move, beside whatever the view shows:
/// - `floatingMoves` asks `frameBringingIntoView` instead of parking it or pushing it aside;
/// - docked windows keep clear of it: it reserves a strip of its display (Controller+PinnedRoom.swift);
/// - it is raised once, as it is pinned. macOS lets nobody keep another app's window in front, so Arbor does not try;
/// - dragging moves it and never docks it (`dropTarget`), and `arrange` leaves it out.
/// Once pinned it is never moved or sized by Arbor: where it is, is its person's (collab/QUESTIONS.md Q20, Q25).
///
/// The pins themselves are in `Workspace.pinned`, so they are saved, and go away and come back with
/// a display, like the rest of the arrangement. A window that stops floating loses its pin there.
extension Controller {
  // MARK: Commands

  func pin(_ window: WindowID?) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    guard !workspaces[display]!.isPinned(id) else { return .failure("\(id) is already kept in view") }
    var raised = false
    if workspaces[display]!.isDocked(id) {
      // Where `float` would put it, at its own size however large (F48; QUESTIONS Q20): Arbor picks no size for a floating window.
      let frame = floatingFrame(for: id, on: display)
      workspaces[display]!.undock(id, floatingAt: frame, shareSpace: settings.shareRemovedSpace)
      workspaces[display]!.pin(id)
      place(id, at: frame, on: display)
      // What macOS and the app made of it (whole points, a minimum size) is where it is.
      rememberWhereItIs(id, on: display)
      relayout(display, reason: .structure)
    } else {
      endStretch(of: id, on: display)
      let wasOutOfView = parked.contains(id)
      workspaces[display]!.pin(id)
      comingIntoView.insert(id)
      beingPinned = id
      // Into view if it is not, and its own size if the Desktop had squeezed it (`frameBringingIntoView`), as a motion. The docked
      // windows make room in the same layout.
      if windows[id]?.isPresent == true { relayout(display, reason: .structure) }
      comingIntoView.remove(id)
      beingPinned = nil
      // Where it is pinned is where it stays, not where it was before docked windows pushed it aside: whatever
      // sends floating windows back to where the user left them (float-all, quitting) then leaves it alone.
      rememberWhereItIs(id, on: display)
      notify(.layout(display))
      // One that came into view has been raised as it came (`placeFloatingWindows`).
      if wasOutOfView { raised = true }
    }
    // The one raise there is. What covers it later is told, not fought (`isKeptInViewButCovered`).
    if !raised, windows[id]?.isPresent == true, !parked.contains(id), isCovered(id, by: system.windowsFrontToBack()) ?? true {
      system.raise(id)
      Log.debug("raised \(id), which stays in view")
    }
    scheduleSave()
    // Pinned with the button down, perhaps in the hand: room is made when it is up.
    if system.isMouseButtonDown() { keptWindowMoved(on: display, asked: true) }
    guard windows[id]?.isPresent == true, !hasRoomOfItsOwn(id) else { return .success("keeping \(id) in view") }
    return .success("\(id) \(Self.canBeCovered.fact). \(adviceForAWindowWithoutRoom(id)).")
  }

  private func rememberWhereItIs(_ id: WindowID, on display: DisplayID) {
    // One whose app did not answer is not where it belongs yet, nor the size: what is remembered says where it is to go.
    guard let snapshot = windows[id], snapshot.isPresent, !unplaced.contains(id),
      let remembered = workspaces[display]!.floating[id]
    else { return }
    let own = sizeToTakeAlong(of: id, from: display, remembered: remembered.size)
    workspaces[display]!.floating[id] = snapshot.frame
    noteFit(of: id, own: own, into: snapshot.frame.size, on: display)
    // Whoever pins a window where it is has chosen that place, what hangs over an edge included (`wasLeftThereByItsUser`).
    if let shape = self.display(display)?.frame { chosenOnShape[id] = (snapshot.frame, shape, areaShowing(of: snapshot.frame)) }
  }

  /// The window stays where it is for now, like a new window: it goes out of view with the Desktop
  /// the next time the camera moves, so nothing jumps at the moment of unpinning.
  func unpin(_ window: WindowID?) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    guard workspaces[display]!.isPinned(id) else {
      return .failure("\(id) is not kept in view; `pin \(id.rawValue)` does that")
    }
    workspaces[display]!.unpin(id)
    // From now on it goes out of view with something: with this view, unless the Desktop is showing (F57).
    receiveAsGuestOfTheView(id)
    // The docked windows take its strip back. It stays as it is meanwhile, unless it is alone on the Desktop, which it takes (F18).
    if windowThatTakesDesktop(of: display) != id { placedOnPurpose.insert(id) }
    defer { placedOnPurpose.remove(id) }
    relayout(display, reason: .structure)
    scheduleSave()
    return .success("no longer keeping \(id) in view")
  }

  func togglePin(_ window: WindowID?) -> CommandResult {
    switch target(window) {
    case .failure(let result): return result
    case .window(let id, _): return isPinned(id) ? unpin(id) : pin(id)
    }
  }

  /// For the reply of a command that is about to dock `window`, which ends what it was besides floating.
  func endOfPinNote(_ window: WindowID) -> String {
    switch role(of: window) {
    case .pinned: " and it is no longer kept in view"
    case .summoned, .stashed: " and it no longer comes and goes with its key"
    case nil: ""
    }
  }

  /// The same for the reply of a command that is about to dock several, as clauses of their own: "w7 is no longer kept in view",
  /// "2 windows no longer come and go with their keys". The line on screen knows them for a loss (`HeadsUpText.namesALoss`).
  func endOfRoleNotes(_ windows: [WindowID]) -> [String] {
    let pinned = windows.filter { role(of: $0) == .pinned }
    let summoned = windows.filter { role(of: $0) != nil && !pinned.contains($0) }
    var notes: [String] = []
    if let only = pinned.first {
      notes.append(pinned.count == 1 ? "\(only) is no longer kept in view" : "\(Self.count(pinned.count, "window")) are no longer kept in view")
    }
    if let only = summoned.first {
      notes.append(
        summoned.count == 1
          ? "\(only) no longer comes and goes with its key" : "\(Self.count(summoned.count, "window")) no longer come and go with their keys")
    }
    return notes
  }

  // MARK: Lookup

  public func isPinned(_ window: WindowID) -> Bool { workspaces.values.contains { $0.isPinned(window) } }

  /// Pinned, or summoned (Controller+Summon.swift).
  func staysInView(_ window: WindowID) -> Bool { workspaces.values.contains { $0.staysInView(window) } }

  public func role(of window: WindowID) -> FloatingRole? {
    workspaceID(containing: window).flatMap { workspaces[$0]!.role(of: window) }
  }

  /// For the drawing of the layout as text.
  static func word(for role: FloatingRole?) -> String {
    switch role {
    case .pinned: "pinned "
    case .summoned: "summoned "
    case .stashed, nil: ""
    }
  }

  /// Pins `window` on whichever display it floats on. Does nothing if it is docked or unknown.
  func pinWhereItFloats(_ window: WindowID) {
    guard let display = workspaceID(containing: window) else { return }
    workspaces[display]!.pin(window)
  }

  /// For windows that have just been adopted afresh, with nothing to say that they were pinned (or came and
  /// went with `summon`): at launch when their display is missing, and after a moment without any display
  /// (sleep, a dock being unplugged). The arrangement remembered for the missing display knows.
  func restoreRoles(of adopted: [WindowID]) {
    for window in adopted {
      guard let display = workspaceID(containing: window),
        let role = dormant.keys.sorted().lazy.compactMap({ self.dormant[$0]!.workspace.role(of: window) }).first
      else { continue }
      workspaces[display]!.setRole(role, of: window)
    }
  }

  // MARK: Staying in view

  /// What `pin` does for a window that floats, which is nearly always nothing.
  /// Where a floating window that is smaller than the size remembered for it would be at that size: around where it
  /// is, within the display. Nil if it is not smaller.
  ///
  /// On a Desktop too small for it Arbor makes a window smaller. Pinned or summoned it no longer lives there, so it is its
  /// own size again. Both commands go on to remember where the window is as its own frame: without this, the size
  /// Arbor happened to give it would be its size for good.
  func frameWithoutSqueeze(of window: WindowID, on display: DisplaySnapshot) -> CGRect? {
    guard let current = windows[window]?.frame, let own = workspaces[display.id]?.floating[window]?.size,
      own.width > current.width || own.height > current.height
    else { return nil }
    let size = CGSize(width: max(own.width, current.width), height: max(own.height, current.height))
    return CGRect(x: (current.midX - size.width / 2).rounded(), y: current.minY, width: size.width, height: size.height)
      .fitted(into: display.visibleFrame)
  }

  /// Where a pinned window has to go to be in view at its own size, or nil if it is. It is not in view when it was out of
  /// view until it was pinned, when it has just changed display because one went away or came
  /// back, and when the display under it changed shape.
  ///
  /// At every other layout the answer is nil: once pinned, a window is where its person has it, and the size they gave it, also
  /// if that was while Arbor was not looking (collab/QUESTIONS.md Q20, Q25).
  func frameBringingIntoView(_ window: WindowID, on display: DisplaySnapshot) -> CGRect? {
    guard let current = windows[window], drag?.window != window else { return nil }
    // Out of view, or its app did not answer when it was to be placed.
    if parked.contains(window) || windowsOwedAMove.contains(window) {
      let home = workspaces[display.id]?.floating[window] ?? current.frame
      // What hung over an edge does so again where its person is known to have had it there, on this display as it is shaped and placed
      // now: left by hand, or pinned there. So a display that comes back brings it back to the point. Not if less than half of it would
      // show. Every other frame may be left over from another display or another shape of this one: where in doubt, wholly in view.
      return wasLeftThereByItsUser(home, of: window, on: display) && home.fractionInside(display.frame) >= 0.5
        ? home : home.fitted(into: display.visibleFrame)
    }
    guard comingIntoView.contains(window) else { return nil }
    // Hanging over a screen edge is the user's business. Being mostly beyond it is not what they chose, unless their own hand is known to
    // have left it so on this display as it is. Squeezed as well, it comes at its own size: `pin` goes on to remember the size it
    // has as its own.
    return frameWithoutSqueeze(of: window, on: display)
      ?? (isMostlyOffScreen(window) && !wasLeftThereByItsUser(current.frame, of: window, on: display)
        ? current.frame.fitted(into: display.visibleFrame) : nil)
  }

  private func place(_ window: WindowID, at frame: CGRect, on displayID: DisplayID) {
    // A window being dragged stays in the user's hand, and takes the size when it is let go, as in `putBack`.
    if window == drag?.window {
      if frame.size != windows[window]?.frame.size { drag?.sizeOwed = frame.size }
      return
    }
    if var actual = system.setFrame(frame, of: window) {
      // Its app insists on more by now, and it grew from the corner it was given: no way home would fetch what hangs over an
      // edge. It is slid, at the size it insists on: what it has just refused is not asked of it again.
      if actual.width > frame.width + 2 || actual.height > frame.height + 2, let visible = display(displayID)?.visibleFrame {
        let slid = CGRect(origin: actual.fitted(into: visible).origin, size: actual.size)
        if slid != actual { actual = system.setFrame(slid, of: window) ?? actual }
      }
      windows[window]?.frame = actual
      settled[window] = actual
      parked.remove(window)
      unplaced.remove(window)
    } else {
      // Its app does not answer, so it is still out of view if it was. It is placed when the app answers (F17).
      unplaced.insert(window)
    }
  }

  // MARK: In front, or not

  /// Whether a window Arbor knows lies over part of `window`. What Arbor does not know (menus, panels, its own overlays) does
  /// not count. Nil when the stacking cannot be told.
  func isCovered(_ window: WindowID, by frontToBack: [WindowID]) -> Bool? {
    guard let frame = windows[window]?.frame, let place = frontToBack.firstIndex(of: window) else { return nil }
    return frontToBack[..<place].contains { other in
      // (Of a window out of view a point shows in a corner.)
      guard let above = windows[other], above.isPresent, !parked.contains(other) else { return false }
      return above.frame.overlaps(frame)
    }
  }
}
