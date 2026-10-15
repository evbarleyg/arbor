import ArborCore
import CoreGraphics

/// Pinned windows (docs/features/F49-pin.md): companions to whatever you are doing, such as a video
/// call, a timer, a music player or a reference document.
///
/// A pinned window floats, but it does not live on the Desktop as other floating windows do. It
/// keeps its place on the display through every camera move, over whatever the view shows:
/// - `floatingMoves` asks `frameBringingIntoView` instead of parking it or pushing it aside;
/// - after whatever may have put another window in front of it, `raisePinnedWindows` puts it back;
/// - dragging moves it and never docks it (`dropTarget`), and `arrange` leaves it out.
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
      // Nothing else has a reason to move.
      endStretch(of: id, on: display)
      workspaces[display]!.pin(id)
      // Into view if it is not, and its own size if the Desktop had squeezed it (`frameBringingIntoView`), as a motion.
      if windows[id]?.isPresent == true { relayout(display, reason: .structure) }
      // Where it is pinned is where it stays, not where it was before docked windows pushed it aside: whatever
      // sends floating windows back to where the user left them (float-all, quitting) then leaves it alone.
      rememberWhereItIs(id, on: display)
      desktopCompanyChanged(on: display)
      notify(.layout(display))
    }
    scheduleSave()
    return .success("keeping \(id) in view")
  }

  private func rememberWhereItIs(_ id: WindowID, on display: DisplayID) {
    // One whose app did not answer is not where it belongs yet, nor the size: what is remembered says where it is to go.
    guard let snapshot = windows[id], snapshot.isPresent, !unplaced.contains(id),
      let remembered = workspaces[display]!.floating[id]
    else { return }
    let own = sizeToTakeAlong(of: id, from: display, remembered: remembered.size)
    workspaces[display]!.floating[id] = snapshot.frame
    noteFit(of: id, own: own, into: snapshot.frame.size, on: display)
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
    desktopCompanyChanged(on: display)
    notify(.layout(display))
    scheduleSave()
    return .success("no longer keeping \(id) in view")
  }

  func togglePin(_ window: WindowID?) -> CommandResult {
    switch target(window) {
    case .failure(let result): return result
    case .window(let id, _): return isPinned(id) ? unpin(id) : pin(id)
    }
  }

  /// For the reply of a command that is about to dock `window`, which ends its pin.
  func endOfPinNote(_ window: WindowID) -> String {
    switch role(of: window) {
    case .pinned: " and it is no longer kept in view"
    case .summoned, .stashed: " and it no longer comes and goes with `summon`"
    case nil: ""
    }
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
  func frameBringingIntoView(_ window: WindowID, on display: DisplaySnapshot) -> CGRect? {
    guard let current = windows[window], drag?.window != window else { return nil }
    // Out of view, or its app did not answer when it was to be placed.
    if parked.contains(window) || windowsOwedAMove.contains(window) {
      return (workspaces[display.id]?.floating[window] ?? current.frame).fitted(into: display.visibleFrame)
    }
    // Hanging over a screen edge is the user's business. Being mostly beyond it is not what they chose. Squeezed as well, it
    // comes at its own size: `pin` goes on to remember the size it has as its own.
    return frameWithoutSqueeze(of: window, on: display)
      ?? (isMostlyOffScreen(window) ? current.frame.fitted(into: display.visibleFrame) : nil)
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

  // MARK: Staying in front

  /// How often, after something that may have covered a pinned window, Arbor looks whether it is,
  /// and how long apart in seconds.
  static let pinChecks = 3
  static let pinCheckInterval = 0.2

  /// Called with every change observers hear of. Being in view is worth little behind the window
  /// that just arrived or was just clicked, and macOS has no way to keep another app's window
  /// above the rest, so after anything that may have covered a pinned window Arbor looks, and raises it.
  ///
  /// The first look waits until the command or event under way is over: commands focus a window as
  /// their last step, which puts it in front, and focusing the window that already has the keyboard
  /// is not reported back. The later looks are for what nothing reports: a clicked window takes the
  /// keyboard first and comes to the front afterwards, and some apps take their time.
  func keepPinsInFront(after change: Change) {
    guard isRunning, workspaces.values.contains(where: { $0.pinned != nil || $0.summoned != nil }) else { return }
    switch change {
    case .camera:
      break
    case .layout:
      // Dragging a gap or an edge lays out with every move of the mouse, and covers nothing.
      guard !system.isMouseButtonDown() else { return }
    case .focus(let window):
      // Raising a pinned window can make its app report it as focused. Answering that by raising
      // would never end for two pinned windows of one app.
      guard !staysInView(window) else { return }
    default:
      return
    }
    pinChecksLeft = Self.pinChecks
    scheduler.schedule("raise-pins", after: 0) { [weak self] in self?.checkPinnedWindows() }
  }

  /// A click in the window that has the keyboard already brings it to the front and changes nothing that is
  /// reported: no focus, no layout. That is every click in the editor one is working in. Arbor goes on looking
  /// for as long as the button is down (`checkPinnedWindows`), and three more times after that.
  func lookAfterPinnedWindowsAfterAPress() {
    guard isRunning, workspaces.values.contains(where: { $0.pinned != nil || $0.summoned != nil }) else { return }
    pinChecksLeft = Self.pinChecks
    scheduler.schedule("raise-pins", after: 0) { [weak self] in self?.checkPinnedWindows() }
  }

  private func checkPinnedWindows() {
    guard isRunning else { return }
    raisePinnedWindows()
    // A click is not over until the button is up.
    if !system.isMouseButtonDown() { pinChecksLeft -= 1 }
    guard pinChecksLeft > 0 else { return }
    scheduler.schedule("raise-pins", after: Self.pinCheckInterval) { [weak self] in self?.checkPinnedWindows() }
  }

  /// Brings the pinned windows that another window covers in front of it. The keyboard stays where it
  /// is. One that nothing covers is left alone: raising asks its app, which may be busy with a call.
  func raisePinnedWindows() {
    let pins = workspaces.keys.sorted()
      .flatMap { workspaces[$0]!.pinnedWindows + [workspaces[$0]!.summoned?.window].compactMap { $0 } }
      .filter { windows[$0]?.isPresent == true && isManaged($0) && !parked.contains($0) }
    let frontToBack = system.windowsFrontToBack()
    let covered = pins.filter { isCovered($0, by: frontToBack, apartFrom: pins) }
    // Nearly every look ends here. Who has the keyboard is a question to the app in front, which is being worked in.
    guard !covered.isEmpty else { return }
    // A pinned window with the keyboard is in front already, and the others must not cover it.
    if let focused = system.focusedWindow(), pins.contains(focused) { return }
    // The one used last ends up in front of the other pinned windows, as it was.
    func recency(_ window: WindowID) -> Int { focusHistory.firstIndex(of: window) ?? Int.max }
    for window in covered.sorted(by: { (recency($0), $0) > (recency($1), $1) }) {
      system.raise(window)
      Log.debug("raised \(window), which stays in view")
    }
  }

  /// Whether a window Arbor knows, other than `others`, lies over part of `window`. What Arbor does
  /// not know (menus, panels, its own overlays) does not count. True when the stacking cannot be told.
  private func isCovered(_ window: WindowID, by frontToBack: [WindowID], apartFrom others: [WindowID]) -> Bool {
    guard let frame = windows[window]?.frame, let place = frontToBack.firstIndex(of: window) else { return true }
    return frontToBack[..<place].contains { other in
      guard !others.contains(other), let above = windows[other], above.isPresent else { return false }
      return above.frame.overlaps(frame)
    }
  }
}
