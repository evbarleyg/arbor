import ArborCore
import CoreGraphics

/// Summoning (docs/features/F53-summon.md): for apps visited for ten seconds, many times a day, such as a
/// terminal, a scratch note, a calculator, a music player or a password manager.
///
/// `summon <app>` brings the app's window over whatever the view shows, with the keyboard in it. The same
/// command again, or turning to another window, sends it out of view. The camera never moves.
///
/// While it is summoned the window is a pin that ends by itself (`Workspace.staysInView`, Controller+Pin.swift).
/// Afterwards it is **stashed**: a floating window that does not live on the Desktop but stays out of view
/// whatever the camera shows, or sending it away would do nothing in any view that includes the Desktop.
/// A stashed window that gets the keyboard some other way (⌘Tab, its Dock icon) is summoned. Docking or
/// pinning it, `home`, floating everything, and closing it end all of this.
extension Controller {
  /// How long a window that `summon` asked an app to open may take to appear, in seconds.
  static let summonWait = 5.0

  // MARK: The command

  func summon(_ app: String) -> CommandResult {
    // In view already: send it away.
    for display in workspaces.keys.sorted() {
      guard let summoned = workspaces[display]!.summoned?.window, let window = windows[summoned],
        Self.isWindow(window, of: app)
      else { continue }
      guard window.isPresent else {
        // Minimized or hidden since: there is nothing to send away, and the press means "bring it".
        workspaces[display]!.dismissSummon()
        continue
      }
      dismissSummon(on: display)
      return .success("sent \(window.appName) away; summon it again, or ⌘Tab to it")
    }
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }

    let ofApp = windows.values.filter { Self.isWindow($0, of: app) }
    let candidates = ofApp.filter { filter.manages($0) && workspaceID(containing: $0.id) != nil }
    if candidates.isEmpty, let other = ofApp.first {
      return .failure("Arbor does not arrange \(other.appName) (`include \(other.bundleID ?? other.appName)` if it is excluded)")
    }
    // The one used last, among those that can show. A minimized window or a hidden app has to be asked.
    func recency(_ window: WindowSnapshot) -> Int { focusHistory.firstIndex(of: window.id) ?? Int.max }
    guard
      let window = candidates.filter(\.isPresent).min(by: { (recency($0), $0.id) < (recency($1), $1.id) })
    else { return openAndAwait(app, on: display) }
    return summon(window, on: display)
  }

  /// For a command that names a window that was sent away (`zoom 104`, and Go to… by that path): it has no
  /// place the view could go to, so it comes over the view.
  func summonStashed(_ id: WindowID) -> CommandResult {
    guard let window = windows[id], let (display, _) = cameraDisplay() else { return .failure("no display") }
    return window.isPresent ? summon(window, on: display) : openAndAwait(window.bundleID ?? window.appName, on: display)
  }

  /// `float` on a window that comes and goes with `summon`: it floats on the Desktop like any other again.
  func floatOrdinarily(_ id: WindowID, on display: DisplayID) -> CommandResult {
    workspaces[display]!.forgetSummon(of: id)
    relayout(display, reason: .structure)
    scheduleSave()
    return .success("\(id) floats on the Desktop again and no longer comes and goes with `summon`")
  }

  /// `awaitedSince`: it is the window `summon` has been waiting for (its app had none, or none that showed), and this is who had the keyboard
  /// when it was asked for. Such a window has the keyboard as soon as it is there, on a Mac before anybody says that it was created:
  /// its app was opened in front. Nobody is using it where it is and nobody came from it, so the keyboard counts as being where it was.
  private func summon(_ window: WindowSnapshot, on display: DisplayID, awaitedSince asked: WindowID?? = nil) -> CommandResult {
    stopAwaitingSummon()
    var keyboard = keyboardFocus()
    // (Or nobody has it yet, as far as macOS can tell: the app is in front and has not named a window.)
    if let asked, keyboard == window.id || keyboard == nil {
      keyboard = asked.flatMap { windows[$0] != nil && $0 != window.id ? $0 : nil } ?? focusHistory.first { $0 != window.id }
    }
    guard let home = workspaceID(containing: window.id) else { return .failure("\(window.id) is not on any display") }
    if let leaf = workspaces[home]!.tree.leaf(containing: window.id) {
      // A docked window has a place, and the place wins: go there, as ⌘Tab would. Again, and it is back where you were,
      // so that one key does for an app wherever its window lives.
      if let back = returnFromDockedWindow(window, on: home) { return back }
      let before = (camera: workspaces[home]!.camera, keyboard: keyboard)
      let inactiveTab = workspaces[home]!.tree.activeWindow(of: leaf) != window.id
      if inactiveTab { workspaces[home]!.tree.activate(window.id) }
      if parked.contains(window.id) || (layouts[home]?.windowFrames[window.id] == nil && !isLetBe(window.id)) {
        reveal(window.id, leaf: leaf, on: home)
      } else if inactiveTab {
        relayout(home, reason: .structure)
      }
      askForTheKeyboard(for: window.id)
      // With the keyboard in it already nobody came from anywhere.
      visitToDockedWindow =
        before.keyboard == window.id
        ? nil
        : VisitToDockedWindow(window: window.id, cameraBefore: before.camera, keyboardBefore: before.keyboard)
      return .success("\(window.appName) is docked: showing it where it is")
    }
    if workspaces[home]!.isPinned(window.id) {
      askForTheKeyboard(for: window.id)
      return .success("\(window.appName) is kept in view already")
    }
    present(window.id, on: display, keyboardWas: keyboard)
    askForTheKeyboard(for: window.id)
    return .success("summoned \(window.appName) (\(window.id))")
  }

  /// Where the view and the keyboard were before `summon` went to a docked window.
  struct VisitToDockedWindow {
    var window: WindowID
    var cameraBefore: NodeID
    var keyboardBefore: WindowID?
  }

  /// The second press. Only straight after the first: once the view has moved or the keyboard has gone elsewhere
  /// (`summonNotices`) there is no telling where "back" is, and the press goes to the window like a first one.
  private func returnFromDockedWindow(_ window: WindowSnapshot, on home: DisplayID) -> CommandResult? {
    guard let visit = visitToDockedWindow else { return nil }
    visitToDockedWindow = nil
    // Word of the keyboard going elsewhere can be late.
    guard visit.window == window.id, system.focusedWindow() == window.id else { return nil }
    if visit.cameraBefore != workspaces[home]!.camera, workspaces[home]!.tree.contains(visit.cameraBefore) {
      // Who gets the keyboard is said below: left to the move as well, the same window would be asked twice.
      moveCamera(on: home, to: visit.cameraBefore, refocus: false)
    }
    let before = visit.keyboardBefore.flatMap { windows[$0]?.isPresent == true && !parked.contains($0) ? $0 : nil }
    if before.map(sendTheKeyboard(to:)) != true { ensureFocusIsVisible(on: home, notTo: Set([before].compactMap { $0 })) }
    return .success("back from \(window.appName)")
  }

  /// A bundle id or an app's name, whichever the user typed, in any case.
  static func isWindow(_ window: WindowSnapshot, of app: String) -> Bool {
    let wanted = app.lowercased()
    return window.bundleID?.lowercased() == wanted || window.appName.lowercased() == wanted
  }

  // MARK: Coming and going

  /// Puts a floating window over the view of `display`: where it was the last time it was summoned there,
  /// or in the middle at its own size.
  private func present(_ window: WindowID, on displayID: DisplayID, keyboardWas previous: WindowID?) {
    guard let snapshot = windows[window], let display = display(displayID), workspaces[displayID] != nil else { return }
    // The user has taken it in hand: its next title must not bring a rule that docks it.
    stopWatchingTitle(of: window)
    let app = snapshot.bundleID ?? snapshot.appName
    let visible = display.visibleFrame
    let home = workspaceID(containing: window)
    let livedOnADesktop = home.map { workspaces[$0]!.role(of: window) == nil } ?? false
    // On the Desktop it is as large as there was room: squeezed by docked windows, or, alone there, all over it (F18). Or it fills the view.
    // What is remembered is its own frame, and a window that comes over any view should be its own size.
    let own = home.flatMap { workspaces[$0]!.floating[window] } ?? snapshot.frame
    let whereItIs =
      home.map { windowThatTakesDesktop(of: $0) == window || workspaces[$0]!.isFilled(window) } == true
      ? own : frameWithoutSqueeze(of: window, on: display) ?? snapshot.frame
    let size = own.size
    // In view with the keyboard in it already: someone is using it there, and it must not jump.
    let inUseHere =
      previous == window && !parked.contains(window) && workspaceID(containing: window) == displayID
      && !isMostlyOffScreen(window)
    // Where its app opened it is not a place anybody chose: the place it had the last time comes first then.
    let chosenByTheUser = appPlacedFrames[window] != workspaces[displayID]!.floating[window]
    let frame =
      ((inUseHere && chosenByTheUser ? whereItIs : nil) ?? workspaces[displayID]!.summonFrames?[app]
      ?? (inUseHere ? whereItIs : nil)
      // On whole points, where macOS puts windows anyway.
      ?? CGRect(
        x: (visible.midX - size.width / 2).rounded(.down), y: (visible.midY - size.height / 2).rounded(.down),
        width: size.width, height: size.height))
      .fitted(into: visible)
    for other in workspaces.keys.sorted() where other != displayID { workspaces[other]!.floating[window] = nil }
    let replaced = workspaces[displayID]!.summon(window, app: app, at: frame)
    if let replaced, windows[replaced]?.isPresent == true { park(replaced, on: display) }
    if let actual = system.setFrame(frame, of: window) {
      windows[window]?.frame = actual
      settled[window] = actual
      // What the app made of it is where it is, and where it will be next time.
      workspaces[displayID]!.floating[window] = actual
      parked.remove(window)
      unplaced.remove(window)
    } else {
      // Its app does not answer, so it is still out of view if it was. It arrives when the app answers (F17).
      unplaced.insert(window)
    }
    // It may have the keyboard already (⌘Tab, or it was in view on the Desktop): then, the window before it.
    let before = previous == window ? focusHistory.first { $0 != window } : previous
    // One summoned window straight after another: the keyboard goes back to where it was before both.
    if replaced == nil || before != replaced { keyboardBeforeSummon = before }
    // It has left a Desktop, where another window may be alone now.
    if livedOnADesktop, let home { desktopCompanyChanged(on: home) }
    notify(.layout(displayID))
    scheduleSave()
  }

  /// Sends the summoned window of `display` out of view. If it still has the keyboard, the window that had it
  /// before gets it back; otherwise the keyboard has gone where the user wanted it.
  func dismissSummon(on displayID: DisplayID) {
    guard let window = workspaces[displayID]?.dismissSummon(), let display = display(displayID) else { return }
    if windows[window]?.isPresent == true { park(window, on: display) }
    let previous = keyboardBeforeSummon
    keyboardBeforeSummon = nil
    if system.focusedWindow() == window {
      let before = previous.flatMap { windows[$0]?.isPresent == true && !parked.contains($0) ? $0 : nil }
      let asked = Set([before].compactMap { $0 })
      if before.map(sendTheKeyboard(to:)) != true, !ensureFocusIsVisible(on: displayID, notTo: asked) {
        // Nothing else is in view here. A window on another display is better than one that is out of view.
        _ = workspaces.keys.sorted().first { $0 != displayID && ensureFocusIsVisible(on: $0, notTo: asked) }
      }
    }
    notify(.layout(displayID))
    scheduleSave()
  }

  /// Its user is carrying the summoned window to `display` by hand. There is one at a time there too, and
  /// `Workspace.setRole` would stash the newcomer, which is right for a window that arrives because its display went away. In
  /// its user's hand it would vanish at the next layout. So the one that is there goes, as when another is summoned.
  func summonedWindowIsCarried(_ window: WindowID, to display: DisplayID) {
    guard let home = workspaceID(containing: window), home != display, workspaces[home]!.isSummoned(window),
      workspaces[display]?.summoned != nil
    else { return }
    dismissSummon(on: display)
  }

  /// Called when a floating window that is out of view is reported as focused, before the camera goes looking
  /// for it on the Desktop, where a stashed window is not. Returns false for a window that is not stashed.
  func summonIfStashed(_ window: WindowID) -> Bool {
    guard let display = workspaceID(containing: window), workspaces[display]!.isStashed(window) else { return false }
    // Apps in the background report focus changes too. Only a window that really has the keyboard comes.
    if windows[window]?.isPresent == true, system.focusedWindow() == window {
      present(window, on: display, keyboardWas: window)
    }
    return true
  }

  // MARK: What ends a summon

  /// Called with every change observers hear of.
  func summonNotices(_ change: Change) {
    guard isRunning else { return }
    // The view has moved or the keyboard has gone elsewhere since `summon` went to a docked window: there is no "back" now.
    switch change {
    case .camera: visitToDockedWindow = nil
    case .focus(let focused) where focused != visitToDockedWindow?.window: visitToDockedWindow = nil
    default: break
    }
    // An app can take seconds to open. Whoever takes the keyboard meanwhile is who gets it back.
    if case .focus(let focused) = change, let awaited = awaitedSummon, let window = windows[focused],
      !Self.isWindow(window, of: awaited.app), system.focusedWindow() == focused
    {
      awaitedSummon?.keyboard = focused
    }
    summonAwaitedWindow()
    guard case .focus(let focused) = change, !settings.summonStays else { return }
    for display in workspaces.keys.sorted() {
      guard let summoned = workspaces[display]!.summoned?.window, summoned != focused,
        // Apps in the background report focus changes too; only the keyboard really going elsewhere counts.
        system.focusedWindow() == focused,
        // Its own app's settings, a second terminal window, a dialog that is a window: still the same visit.
        windows[focused]?.pid != windows[summoned]?.pid || windows[focused]?.bundleID != windows[summoned]?.bundleID
      else { continue }
      dismissSummon(on: display)
    }
  }

  /// Quitting and pausing end a summon and move nothing: every window is coming into view anyway.
  func endSummonsWithoutMoving() {
    stopAwaitingSummon()
    keyboardBeforeSummon = nil
    for display in workspaces.keys.sorted() { workspaces[display]!.dismissSummon() }
  }

  // MARK: Apps without a window

  private func openAndAwait(_ app: String, on display: DisplayID) -> CommandResult {
    // Asked before the app is: it comes to the front.
    let keyboard = keyboardFocus()
    guard system.openApplication(app) else {
      return .failure("no app called \(app): use its name as the Dock shows it, or its bundle id")
    }
    awaitedSummon = (app, display, keyboard)
    scheduler.schedule("summon-wait", after: Self.summonWait) { [weak self] in
      guard let self, self.awaitedSummon != nil else { return }
      self.awaitedSummon = nil
      Log.info("gave up waiting for a window to summon")
    }
    return .success("opening \(app)")
  }

  func stopAwaitingSummon() {
    awaitedSummon = nil
    scheduler.cancel("summon-wait")
  }

  /// Summons the window `summon` is waiting for, if it has appeared (or is no longer minimized or hidden).
  func summonAwaitedWindow() {
    guard isRunning, let (app, display, keyboard) = awaitedSummon, workspaces[display] != nil,
      // The one used last, if the app showed several again; of windows never used, the newest.
      let window = windows.values
        .filter({ Self.isWindow($0, of: app) && $0.isPresent && filter.manages($0) && workspaceID(containing: $0.id) != nil })
        .min(by: { a, b in
          let (ra, rb) = (focusHistory.firstIndex(of: a.id) ?? Int.max, focusHistory.firstIndex(of: b.id) ?? Int.max)
          return ra != rb ? ra < rb : a.id > b.id
        })
    else { return }
    _ = summon(window, on: display, awaitedSince: keyboard)
  }
}
