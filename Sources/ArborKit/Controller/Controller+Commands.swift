import ArborCore
import CoreGraphics
import Dispatch
import Foundation

extension Controller {
  /// Runs a command. Every entry point (hotkeys, menu, socket, URLs, tests)
  /// ends up here, by way of `perform(_:from:)` (Controller+Lead.swift).
  func execute(_ command: Command) -> CommandResult {
    // Before it changes anything: a peek ends on the arrangement it began with. Here, so that no way in goes round it.
    // The one exception is no command but a click (Controller+FrameRect.swift).
    if let landed = landPeek(insteadOf: command) { return landed }
    if !command.isQuery { interruptPeek() }
    // Here for the same reason: the commands answered first of all open windows of Arbor's own and change settings.
    closeFinder(before: command)
    // What a command follows is remembered, what a query asks is not (`currentLead()`).
    let outer = following.decides
    following.decides = !command.isQuery
    defer { following.decides = outer }
    // Once the command has had its own say about the keyboard (Controller+LetBe.swift).
    defer { theKeyboardLeavesTheTile() }
    let start = DispatchTime.now()
    defer { if !command.isQuery { stats.record("commands", command.verb, seconds: CallStats.seconds(since: start)) } }
    // First of all: some commands below are answered whether or not Arbor is running.
    if let answer = holdAnswers(command) ?? refusalWhileHeld(command) { return answer }
    // A command must never pretend: see Controller+Permission.swift.
    if !command.isQuery, command != .quit { askAboutAccessibility(beyondDoubt: true, inPassing: true) }
    switch command {
    case .status:
      // The message stays the one line scripts compare, but for a file that cannot be read, which somebody has to hear
      // of; `arborctl status` prints the text.
      let problem = settingsFileProblem.map { "settings.json cannot be read: \($0)" }
      return CommandResult(
        ok: true, message: statusText + (problem.map { ". \($0)" } ?? ""),
        text: ([statusText] + (problem.map { [$0] } ?? []) + ["Arbor \(buildInfo.text)"]).joined(separator: "\n"))
    case .state(let titles):
      return CommandResult(ok: true, message: statusText, state: titles ? snapshot() : snapshot().withoutTitles)
    case .ascii:
      return CommandResult(ok: true, message: statusText, text: asciiDrawing())
    case .help:
      return CommandResult(ok: true, message: "commands", text: Command.helpText)
    case .quit:
      return .success("quitting")
    case .bindings:
      return listBindings()
    case .rules:
      return rulesReport()
    case .pause(let minutes):
      return pause(minutes: minutes)
    case .resume:
      return resume()
    case .togglePause:
      return togglePause()
    case .watch:
      return Self.watchNeedsAConnection
    case .doctor:
      return doctor()
    case .checkSetup:
      return showWelcomeWindow(.setup)
    case .welcome:
      return showWelcomeWindow(.firstSteps)
    case .menuBar:
      return menuBarReport()
    case .menu:
      return menuReport()
    case .stats(let reset):
      return statsReport(reset: reset)
    case .version:
      return versionReport()
    case .checkForUpdates:
      return checkForUpdates()
    case .launchAtLogin(let enabled):
      return launchAtLogin(enabled)
    case .fixSetup(let undo):
      return fixSetup(undo: undo)
    case .settings(let command):
      return performSettings(command)
    case .trace(let action):
      return trace(action)
    case .printLayout(let display, let naming):
      // Needs the windows' names, which Arbor knows only while it runs.
      return isRunning ? printLayout(display: display, naming: naming) : .failure(statusText)
    case .spaces:
      return spacesReport()
    case .displays:
      return displaysReport()
    default:
      break
    }

    guard isRunning else { return .failure(statusText) }
    expectFocusToMove()

    let namesBefore = everyName()
    // Whatever the command changes in an arrangement becomes an undo step (Controller+Undo.swift).
    let undoScope = beginUndoStep(for: command)
    defer { endUndoStep(undoScope) }
    let result: CommandResult
    switch command {
    case .showAll: result = showAll()
    case .stepOut: result = stepOut()
    case .stepIn: result = stepIn()
    case .neighbor(let edge): result = moveToNeighbor(edge)
    case .back: result = goBack()
    case .forward: result = goForward()
    case .zoom(let window): result = zoom(window)
    case .zoomNode(let node): result = zoom(node: node)
    case .desktop: result = showDesktop()
    case .saveView(let slot): result = saveView(slot)
    case .goToView(let slot): result = goToView(slot)
    case .dock(let window, let edge): result = dock(window, edge: edge)
    case .dockBeside(let window, let target, let edge): result = dock(window, beside: target, edge: edge)
    case .float(let window): result = notingWhatIsLost { float(window) }
    case .toggleFloat(let window): result = notingWhatIsLost { toggleFloat(window) }
    case .arrange: result = notingWhatIsLost { arrange() }
    case .floatAll: result = notingWhatIsLost { floatAll() }
    case .resize(let window, let edge, let amount): result = resize(window, edge: edge, by: amount)
    case .exclude(let bundleID): result = notingWhatIsLost { exclude(bundleID) }
    case .include(let bundleID): result = include(bundleID)
    case .relayout:
      // Asked for by hand, usually because something looks wrong: try every window again.
      misfits.removeAll()
      forgetLearnedMinimums()
      for display in workspaces.keys.sorted() { dropOverdueSlots(on: display, askedFor: true) }
      relayoutAll(reason: .structure)
      result = .success("laid out again")
    case .reloadSettings: result = reloadSettings()
    case .status, .state, .ascii, .help, .quit:
      result = .success("ok")
    case .bindings:
      result = .success("ok")
    case .rules:
      result = rulesReport()
    case .frameRect(let x, let y, let width, let height):
      result = frameRect(CGRect(x: x, y: y, width: width, height: height))
    case .home: result = home()
    case .pause, .resume, .togglePause:
      result = .success("ok")
    case .floatAllHere: result = notingWhatIsLost { floatAllHere() }
    case .arrangeAll: result = notingWhatIsLost { arrangeAll() }
    case .doctor, .checkSetup, .welcome, .menuBar, .menu:
      result = .success("ok")
    case .passThrough(let bundleID, let on): result = passThrough(bundleID, on: on)
    case .pin(let window): result = pin(window)
    case .unpin(let window): result = unpin(window)
    case .togglePin(let window): result = togglePin(window)
    case .watch:
      result = Self.watchNeedsAConnection
    case .stats(let reset): result = statsReport(reset: reset)
    case .hold(let minutes): result = hold(.view, minutes: minutes)
    case .holdStill(let minutes): result = hold(.still, minutes: minutes)
    case .release: result = release()
    case .toggleHold: result = toggleHold()
    case .version, .checkForUpdates, .launchAtLogin, .fixSetup:
      result = .success("ok")
    case .settings(let command):
      result = performSettings(command)
    case .reveal(let window): result = revealAndFocus(window)
    case .find(let text):
      // It logs for itself: its text, which its reply may quote, is likely to be part of a window's title.
      return find(text)
    case .trace(let action):
      result = trace(action)
    case .summon(let app): result = summon(app)
    case .layout(let spec, let display, let open):
      result = notingWhatIsLost { applyLayout(spec, display: display, open: open) }
    case .printLayout: result = .success("ok")
    case .name(let text): result = nameSpace(text)
    case .unname(let text): result = unnameSpace(text)
    case .goToSpace(let text): result = goToSpace(text)
    case .spaces: result = spacesReport()
    case .askName(let cancel): result = askName(cancel: cancel)
    case .focus(let target): result = focus(target)
    case .swap(let window, let direction): result = swap(window, toward: direction)
    case .swapWindows(let first, let second): result = swap(first, with: second)
    case .equalize(let all): result = equalize(all: all)
    case .rotate: result = rotate()
    case .sideBySide(let windows): result = sideBySide(windows)
    case .mirror: result = mirror()
    case .grow(let points): result = resizeFocusedWindow(by: points, growing: true)
    case .shrink(let points): result = resizeFocusedWindow(by: points, growing: false)
    case .moveToDisplay(let target, let window): result = move(window, to: target)
    case .focusDisplay(let target): result = focusDisplay(target)
    case .displays:
      result = displaysReport()
    case .toggleAutoDock: result = toggleAutoDock()
    case .showShortcuts: result = toggleCheatSheet()
    case .minimap: result = toggleMinimap()
    case .undo: result = undo()
    case .redo: result = redo()
    }
    // Replies call a named space by its name; the log, which people paste into bug reports, does not (F20).
    let message = Self.withoutNames(forTheLog(result.message), namesBefore.union(everyName()).union(command.namesInText))
    if result.ok {
      Log.info("\(command.textWithoutNames): \(message)")
    } else {
      Log.debug("\(command.textWithoutNames) failed: \(message)")
    }
    return result
  }

  /// `watch` is answered by the control socket, which can go on answering (`ControlEndpoint`). Here there is one reply.
  static let watchNeedsAConnection = CommandResult.failure(
    "`watch` goes on until Arbor quits, so it needs a connection that stays open: run `arborctl watch`")

  // MARK: Resolving targets

  enum Target {
    case window(WindowID, DisplayID)
    case failure(CommandResult)
  }

  /// The explicit window, or the focused window, if Arbor manages it.
  func target(_ window: WindowID?) -> Target {
    guard let id = window ?? keyboardFocus() else {
      return .failure(.failure("no focused window; click one, or name one (`state` lists their ids)"))
    }
    guard isManaged(id) else { return .failure(.failure(whyNotManaged(id))) }
    // Its arrangement is on another of the macOS Spaces: a shortcut pressed here would rearrange what cannot be seen.
    guard windows[id]?.isFullScreen != true else { return .failure(.failure("\(id) is full screen")) }
    guard let displayID = workspaceID(containing: id) else {
      return .failure(.failure("\(id) is not on any display"))
    }
    stopWatchingTitle(of: id)  // the user has taken it in hand
    return .window(id, displayID)
  }

  /// Why `isManaged(id)` is false, and what to do about it.
  func whyNotManaged(_ id: WindowID) -> String {
    guard let window = windows[id] else { return "there is no window \(id) (`state` lists their ids)" }
    if filter.ignoredWindowIDs.contains(id) { return "\(id) is left alone by an `ignore` rule (see `rules`)" }
    if let bundle = window.bundleID, filter.excludedBundleIDs.contains(bundle) {
      return "Arbor does not arrange \(window.appName); `include \(bundle)` arranges it again"
    }
    return "\(id) is not a window Arbor arranges"
  }

  /// With several displays a camera command has to choose one (Controller+Lead.swift). One that fails says
  /// which it chose, because the user may have meant the other.
  var onPointerDisplay: String {
    guard displays.count > 1 else { return "" }
    let followedKeyboard = following.lead.last == .keyboard && focusedDisplayID != nil
    return followedKeyboard ? " on the focused window's display" : " on the display under the pointer"
  }

  /// Added to what `dock` says when the window's new slot is too small to show it, and when making room for
  /// it left too little for windows that were shown until now (`shownBefore`). They go out of view in the same
  /// moment, and nothing but the reply says that this command did it.
  func tileNote(_ window: WindowID, on display: DisplayID, since shownBefore: Set<WindowID>) -> String {
    let itself = windows[window]?.isPresent == true && layouts[display]?.windowFrames[window] == nil
    let inTiles = Set(layouts[display]?.tiles.flatMap(\.windows) ?? [])
    let others = shownBefore.subtracting([window]).intersection(inTiles).count
    let own = "; its space is too small to show it, so it is a tile"
    switch (itself, others) {
    case (false, 0): return ""
    case (true, 0): return own
    case (true, 1): return own + ", and so is 1 other window now"
    case (true, _): return own + ", and so are \(others) other windows now"
    case (false, 1): return "; that leaves too little room for 1 other window, which is a tile now"
    case (false, _): return "; that leaves too little room for \(others) other windows, which are tiles now"
    }
  }

  /// The docked windows that have a frame of their own on `display`: not in a tile, not out of view.
  func windowsShown(on display: DisplayID) -> Set<WindowID> { Set((layouts[display]?.windowFrames ?? [:]).keys) }

  func cameraDisplay() -> (DisplayID, Workspace)? {
    guard let id = commandDisplayID(), let workspace = workspaces[id] else { return nil }
    return (id, workspace)
  }

  // MARK: Camera

  func showAll() -> CommandResult {
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    moveCamera(on: display, to: workspace.tree.root)
    return .success("showing everything")
  }

  /// Everything, on every display. `show-all` acts on one display (`commandDisplayID()`), which is right
  /// for a step in a journey; this is for someone who has lost a window and does not know where.
  func home() -> CommandResult {
    guard !workspaces.isEmpty else { return .failure("no display") }
    for display in workspaces.keys.sorted() {
      // "A window is gone: ⌃⌥0" may have no exception, so windows that `summon` sent away are back on the Desktop.
      // The summoned one too: the keyboard goes along with the view, which would send it away the next moment.
      workspaces[display]!.forgetSummons()
      moveCamera(on: display, to: workspaces[display]!.tree.root)
    }
    return .success(workspaces.count == 1 ? "showing everything" : "showing everything on every display")
  }

  func stepOut() -> CommandResult {
    guard let (display, workspace) = cameraDisplay(), let view = treeView(display) else {
      return .failure("no display")
    }
    guard let node = Navigation.stepOut(from: workspace.camera, in: view) else {
      return .failure("already showing everything" + onPointerDisplay)
    }
    moveCamera(on: display, to: node)
    return .success("stepped out to \(name(of: node, on: display))")
  }

  func stepIn() -> CommandResult {
    guard let (display, workspace) = cameraDisplay(), let view = treeView(display),
      let layout = layouts[display]
    else { return .failure("no display") }
    let cursor = system.cursorLocation()
    let point = self.display(display)?.frame.contains(cursor) == true ? cursor : nil
    guard
      let node = stepTowardFocus(from: workspace.camera, on: display, in: view)
        ?? Navigation.stepIn(
          from: workspace.camera, toward: point, focused: system.focusedWindow(), in: view,
          layout: layout)
    else {
      guard !workspace.tree.allWindows.isEmpty else {
        return .failure("nothing is docked yet: drag a window to a screen edge, or try `dock left`")
      }
      return .failure("nothing to step into: \(name(of: workspace.camera, on: display)) fills the view" + onPointerDisplay)
    }
    moveCamera(on: display, to: node)
    return .success("stepped in to \(name(of: node, on: display))")
  }

  func moveToNeighbor(_ edge: Edge) -> CommandResult {
    guard let (display, workspace) = cameraDisplay(), let view = treeView(display) else {
      return .failure("no display")
    }
    guard let node = Navigation.neighbor(of: workspace.camera, toward: edge, in: view) else {
      return .failure("no space \(edge.beyond)" + onPointerDisplay)
    }
    moveCamera(on: display, to: node)
    return .success("moved to \(name(of: node, on: display))")
  }

  func goBack() -> CommandResult {
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }
    return goBack(on: display)
  }

  func goBack(on display: DisplayID) -> CommandResult {
    guard workspaces[display]!.goBack() else { return .failure("nothing to go back to" + onPointerDisplay) }
    keyboardHandOver.reveal = nil
    unframedIntoATile = nil
    relayout(display, reason: .camera)
    ensureFocusIsVisible(on: display, alsoFromAPinnedWindow: true)
    notify(.camera(display))
    scheduleSave()
    return .success("back to \(name(of: workspaces[display]!.camera, on: display))")
  }

  func goForward() -> CommandResult {
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }
    guard workspaces[display]!.goForward() else {
      return .failure("nothing to go forward to" + onPointerDisplay)
    }
    keyboardHandOver.reveal = nil
    unframedIntoATile = nil
    relayout(display, reason: .camera)
    ensureFocusIsVisible(on: display, alsoFromAPinnedWindow: true)
    notify(.camera(display))
    scheduleSave()
    return .success("forward to \(name(of: workspaces[display]!.camera, on: display))")
  }

  func zoom(_ window: WindowID?) -> CommandResult {
    // The shortcut has just un-framed a window that is a tile out here, so the focus went to another one. Pressed
    // again it is still about the first: it goes back and forth, as for any window.
    if window == nil, let last = unframedIntoATile, last.heir == keyboardFocus(), isManaged(last.window),
      now().timeIntervalSince(last.time) < Self.unframedIsRemembered
    {
      return zoom(last.window)
    }
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    let tree = workspaces[display]!.tree
    if workspaces[display]!.isStashed(id) { return summonStashed(id) }
    if workspaces[display]!.staysInView(id) {
      // It has no place to frame, and it does not live on the Desktop. The shortcut does what it would for the
      // window beneath, which is framed: it un-frames.
      let camera = workspaces[display]!.camera
      guard window == nil, camera != tree.root, tree.isStack(camera) || camera == tree.desktop else {
        let state = workspaces[display]!.isPinned(id) ? "kept in view" : "summoned"
        return .failure("\(id) is \(state); dock it to give it a place")
      }
      return unframe(camera, on: display)
    }
    // A guest's place is the space it opened over (Controller+Guests.swift).
    let space = tree.leaf(containing: id) ?? workspaces[display]!.guests?[id] ?? tree.desktop
    // The shortcut pressed again undoes itself, like the green button, a second double-click
    // (F14) and the zoom key of every tiling window manager. With a window named the command
    // stays idempotent, for scripts.
    if window == nil, workspaces[display]!.camera == space, space != tree.root {
      let result = unframe(space, on: display)
      // Whom the keyboard was asked for, not whom macOS names: it has not had the time to get there.
      if isOutOfView(id, on: display), let heir = keyboardFocus(), heir != id {
        unframedIntoATile = (id, heir, now())
      }
      return result
    }
    moveCamera(on: display, to: space)
    askForTheKeyboard(for: inFront(of: id, on: display))
    if space == tree.desktop { return .success("showing the Desktop, where \(id) floats") }
    return .success(tree.leaf(containing: id) == nil ? "framed \(name(of: space, on: display))" : "framed \(id)")
  }

  /// Leaves a framed space for a wider view: the one the camera came from if that was wider (framing
  /// a window from the overview returns to the overview), otherwise one level out (after walking
  /// from neighbour to neighbour, "back" would only frame the previous window).
  /// Whether `unframe` has somewhere to go, for the menu. Its three ways, in its order.
  func canUnframe(_ space: NodeID, on display: DisplayID) -> Bool {
    guard let workspace = workspaces[display] else { return false }
    if landedByPeek(on: space, display: display) { return true }
    if let previous = workspace.back.last, previous != space, workspace.tree.subtree(previous, contains: space) { return true }
    return treeView(display).flatMap { Navigation.stepOut(from: space, in: $0) } != nil
  }

  private func unframe(_ space: NodeID, on display: DisplayID) -> CommandResult {
    let workspace = workspaces[display]!
    // A peek stood in for Show Everything, so the way out of where it landed is everything.
    if landedByPeek(on: space, display: display) {
      moveCamera(on: display, to: workspace.tree.root)
      return .success("showing everything")
    }
    if let previous = workspace.back.last, previous != space, workspace.tree.subtree(previous, contains: space) {
      return goBack(on: display)
    }
    guard let view = treeView(display), let wider = Navigation.stepOut(from: space, in: view) else {
      return .failure("already showing everything")
    }
    moveCamera(on: display, to: wider)
    return .success("stepped out to \(name(of: wider, on: display))")
  }

  func zoom(node: NodeID) -> CommandResult {
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    guard workspace.tree.contains(node) else {
      return .failure("no space \(node)\(onPointerDisplay) (`state` lists them)")
    }
    moveCamera(on: display, to: node)
    return .success("framed \(name(of: node, on: display))")
  }

  func showDesktop() -> CommandResult {
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    moveCamera(on: display, to: workspace.tree.desktop)
    return .success("showing the Desktop")
  }

  func saveView(_ slot: Int) -> CommandResult {
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    workspaces[display]!.saveView(slot: slot)
    notify(.savedViews(display))
    scheduleSave()
    return .success("saved view \(slot): \(name(of: workspace.camera, on: display))")
  }

  func goToView(_ slot: Int) -> CommandResult {
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    guard let node = workspace.savedView(slot: slot) else {
      return .failure("view \(slot) is not saved\(onPointerDisplay); `save-view \(slot)` saves where you are looking")
    }
    moveCamera(on: display, to: node)
    return .success("view \(slot): \(name(of: node, on: display))")
  }

  // MARK: Arrangement

  /// Docks a floating window at an edge of the view, or moves a docked window
  /// one place toward that edge (trading places with its neighbour).
  func dock(_ window: WindowID?, edge: Edge) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    var workspace = workspaces[display]!
    let shown = windowsShown(on: display)

    guard let leaf = workspace.tree.leaf(containing: id) else {
      let pinNote = endOfPinNote(id)
      let outcome = workspace.tryDock(id, at: .cameraEdge(edge), shareSpace: settings.shareRemovedSpace)
      if let why = outcome.refusal(of: id) { return .failure(why) }
      workspaces[display] = keepingDesktopUsable(workspace, on: display)
      relayout(display, reason: .structure)
      focusIfShown(id, on: display)
      scheduleSave()
      return .success("docked \(id) at the \(edge.rawValue) edge" + pinNote + tileNote(id, on: display, since: shown))
    }

    switch moving(id, at: leaf, toward: edge, in: workspace, on: display) {
    case .refused(let why): return .failure(why)
    case .moved(let moved): workspaces[display] = moved
    }
    relayout(display, reason: .structure)
    focusIfShown(id, on: display)
    scheduleSave()
    return .success("moved \(id) \(edge.direction)" + tileNote(id, on: display, since: shown))
  }

  /// Focuses a window that was just docked or moved, unless its slot turned out too small and it is
  /// a tile now. macOS reports the focus change back, and a focused window out of view makes the
  /// camera zoom onto it (`windowFocused`), which is not what arranging windows should do.
  func focusIfShown(_ window: WindowID, on display: DisplayID) {
    if layouts[display]?.windowFrames[window] != nil { askForTheKeyboard(for: window) }
  }

  func dock(_ window: WindowID?, beside target: WindowID, edge: Edge) -> CommandResult {
    let (id, source): (WindowID, DisplayID)
    switch self.target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, source) = (w, d)
    }
    guard id != target else { return .failure("a window cannot dock beside itself") }
    guard let display = workspaceID(containing: target),
      let leaf = workspaces[display]?.tree.leaf(containing: target)
    else {
      return .failure("\(target) is not docked; `dock \(target.rawValue) <edge>` first, then dock \(id) beside it")
    }

    // Asked before it leaves the other display: a window that is refused here stays where it was.
    if let why = workspaces[display]!.wouldDock(id, at: .beside(leaf, edge)).refusal(of: id) { return .failure(why) }
    let pinNote = endOfPinNote(id)
    let shown = windowsShown(on: display)
    if source != display {
      transfer(id, from: source, to: display)
      relayout(source, reason: .structure)
    }
    workspaces[display]!.dock(id, at: .beside(leaf, edge), shareSpace: settings.shareRemovedSpace)
    workspaces[display] = keepingDesktopUsable(workspaces[display]!, on: display)
    relayout(display, reason: .structure)
    focusIfShown(id, on: display)
    scheduleSave()
    return .success("docked \(id) \(edge.beside) \(target)" + pinNote + tileNote(id, on: display, since: shown))
  }

  func float(_ window: WindowID?) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    if workspaces[display]!.isSummoned(id) || workspaces[display]!.isStashed(id) { return floatOrdinarily(id, on: display) }
    if takesDesktopAgain(id, on: display) { return .success("\(id) takes the Desktop again") }
    guard workspaces[display]!.isDocked(id) else { return .failure("\(id) is already floating") }
    let showsDesktop = undock(id, on: display)
    scheduleSave()
    return .success("\(id) is floating" + (showsDesktop ? "; showing the Desktop" : ""))
  }

  func toggleFloat(_ window: WindowID?) -> CommandResult {
    switch target(window) {
    case .failure(let result): return result
    case .window(let id, let display):
      guard !workspaces[display]!.isDocked(id) else { return floatRememberingItsPlace(id, on: display) }
      return dockWhereItWas(id, on: display) ?? dock(id, edge: .right)
    }
  }

  /// Docks every window on one display (`commandDisplayID()`) in a grid, in
  /// reading order, with a narrow Desktop column at the end.
  func arrange() -> CommandResult {
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }
    let arranged = arrange(on: display)
    guard arranged > 0 else { return .failure("no windows to arrange" + onPointerDisplay) }
    scheduleSave()
    return .success("arranged \(Self.count(arranged, "window"))")
  }

  /// Each display's windows, on that display.
  func arrangeAll() -> CommandResult {
    let arranged = workspaces.keys.sorted().map { arrange(on: $0) }.reduce(0, +)
    guard arranged > 0 else { return .failure("no windows to arrange") }
    scheduleSave()
    return .success("arranged \(Self.count(arranged, "window"))")
  }

  /// Returns how many windows it docked.
  private func arrange(on display: DisplayID) -> Int {
    let forgot = forgetPendingSlots(on: display)
    guard let workspace = workspaces[display] else { return 0 }
    // Pinned windows, and those that come and go with `summon`, accompany the arrangement; they are not part of it.
    let floatingPresent = workspace.floating.keys.filter { windows[$0]?.isPresent == true && workspace.role(of: $0) == nil }
    let candidates = workspace.tree.allWindows + floatingPresent.sorted()
    // A docked window counts by its place in the arrangement, not by where it is: a tile, a tab behind another, a
    // minimized window and one out of view are somewhere else, most of them in a screen corner. So the places are those
    // of a layout with everything in view and present and nothing too small. What is arranged already stays as it is.
    let places = self.display(display).map {
      LayoutEngine.layout(
        workspace.tree, camera: workspace.tree.root, in: $0.visibleFrame,
        options: LayoutOptions(gap: CGFloat(options(for: display).gap), minimumUsableSize: .zero), isPresent: { _ in true })
    }
    func place(_ window: WindowID) -> CGRect {
      workspace.tree.leaf(containing: window).flatMap { places?.nodeFrames[$0] }
        ?? (parked.contains(window) ? workspace.floating[window] : nil) ?? windows[window]?.frame ?? .zero
    }
    // Tabs share a place, and stay in their order. Floating windows in the same spot go by their numbers.
    let turn = Dictionary(uniqueKeysWithValues: candidates.enumerated().map { ($0.element, $0.offset) })
    let ordered = candidates.sorted { a, b in
      let (fa, fb) = (place(a), place(b))
      return (fa.minX, fa.minY, turn[a]!) < (fb.minX, fb.minY, turn[b]!)
    }
    guard !ordered.isEmpty else {
      if forgot { relayout(display, reason: .structure) }
      return 0
    }
    stopWatchingTitles()
    var updated = workspace
    updated.reset(tree: .grid(of: ordered, desktopWeight: settings.arrangeDesktopWeight))
    for window in ordered { updated.floating[window] = nil }
    workspaces[display] = updated
    forgetSqueezes(on: display)
    relayout(display, reason: .camera)
    notifyOfReset(display)
    return ordered.count
  }

  /// After `Workspace.reset`: the camera is at the root, and history and saved views are gone.
  func notifyOfReset(_ display: DisplayID) {
    ensureFocusIsVisible(on: display)
    notify(.camera(display))
    notify(.savedViews(display))
    notify(.names(display))
  }

  /// Undocks every window on every display and puts each back where it floated before it was docked
  /// (where it would sit if everything were shown, if that is not known). This is the promise "back to
  /// a normal Mac", so it does not stop at the display the pointer happens to be on (chosen from the
  /// menu bar, that is whichever display has the menu open).
  func floatAll() -> CommandResult {
    let floated = workspaces.keys.sorted().map { floatAll(on: $0) }.reduce(0, +)
    guard floated > 0 else { return .failure("nothing is docked") }
    scheduleSave()
    return .success("floated \(Self.count(floated, "window"))")
  }

  func floatAllHere() -> CommandResult {
    guard let (display, _) = cameraDisplay() else { return .failure("no display") }
    let floated = floatAll(on: display)
    guard floated > 0 else { return .failure("nothing is docked on this display") }
    scheduleSave()
    return .success("floated \(Self.count(floated, "window"))")
  }

  /// Returns how many windows it undocked.
  private func floatAll(on display: DisplayID) -> Int {
    var withoutTiles = options(for: display).layoutOptions
    withoutTiles.minimumUsableSize = .zero
    // As it is on screen, places that are kept open and all.
    let overview = layout(of: display, camera: workspaces[display]?.tree.root, options: withoutTiles)
    let forgot = forgetPendingSlots(on: display)
    guard let workspace = workspaces[display] else { return 0 }
    let docked = workspace.tree.allWindows
    var updated = workspace
    // "Back to a normal Mac": windows that come and go with `summon` are ordinary floating windows again.
    let released = updated.forgetSummons()
    guard !docked.isEmpty || !released.isEmpty else {
      if forgot { relayout(display, reason: .structure) }
      return 0
    }
    stopWatchingTitles()
    updated.reset(tree: LayoutTree())
    // Moved by the layout, once the stage is up (`relayout`), so that they fly back instead of appearing.
    var toPutBack: [(window: WindowID, frame: CGRect)] = []
    for window in docked {
      let asItWas = frameAsItWas(of: window, on: display)
      let frame = asItWas ?? overview?.windowFrames[window] ?? floatingFrame(for: window, on: display)
      updated.floating[window] = frame
      misfits[window] = nil
      // By hand: a layout leaves floating windows in view where they are. And whether or not the window takes
      // up space, if its frame is known: a minimized window would come back in the shape of its slot.
      guard asItWas != nil || parked.contains(window) || windows[window]?.isPresent == true else { continue }
      toPutBack.append((window, frame))
    }
    // The windows that floated all along have the whole display again.
    for (window, preferred) in workspace.floating.sorted(by: { $0.key < $1.key })
    where parked.contains(window) || wasPushedAside(window, from: preferred) {
      if let screen = self.display(display) { toPutBack.append((window, whereItWasLeft(window, preferred, on: screen))) }
    }
    workspaces[display] = updated
    // "As it was" is exact: the layout does not go on to tidy them onto the Desktop, which is a gap
    // smaller than the display all round.
    placedOnPurpose = Set(updated.floating.keys)
    defer { placedOnPurpose = [] }
    relayout(display, reason: .camera, puttingBack: toPutBack)
    notifyOfReset(display)
    return docked.count + released.count
  }

  /// Moves one edge of a docked window by `amount` points (negative shrinks).
  func resize(_ window: WindowID?, edge: Edge, by amount: Double) -> CommandResult {
    let (id, display): (WindowID, DisplayID)
    switch target(window) {
    case .failure(let result): return result
    case .window(let w, let d): (id, display) = (w, d)
    }
    guard amount.isFinite else { return .failure("expected a number of points, got \(amount)") }
    let shown = windowsShown(on: display)
    guard var workspace = workspaces[display], let leaf = workspace.tree.leaf(containing: id),
      let view = treeView(display), let layout = layouts[display]
    else { return .failure("\(id) is not docked") }

    switch Self.seam(on: edge, of: leaf, in: view, layout: layout) {
    case .noNeighbour:
      return .failure("\(id) has no neighbor on the \(edge.rawValue)")
    case .notInView:
      return .failure("that edge is not in view\(adviceToStepOut)")
    case .seam(let seam):
      let delta = edge.isLeading ? -amount : amount
      workspace.tree.moveBoundary(at: seam, by: delta, minimumPoints: minimumPointsBesideSeam(on: display))
      guard workspace.tree != workspaces[display]?.tree else {
        return .failure("that edge is as far as it goes: no space gets smaller than 80 points")
      }
      workspaces[display] = workspace
      byHand { relayout(display, reason: .structure) }
      scheduleSave()
      return .success("resized \(id)" + tileNote(id, on: display, since: shown))
    }
  }

  // MARK: Settings

  func exclude(_ bundleID: String?) -> CommandResult {
    guard
      let bundle = bundleID
        ?? system.focusedWindow().flatMap({ windows[$0]?.bundleID })
    else { return .failure("no focused window; click one of the app's, or name the app: `exclude <bundle id>`") }
    if let refusal = refusalToChangeSettings() { return refusal }
    let app = appName(forBundleID: bundle)
    guard !settings.excludedBundleIDs.contains(bundle) else { return .failure("Arbor does not arrange \(app) already") }
    var updated = settings
    updated.excludedBundleIDs.append(bundle)
    return reply("no longer arranging \(app)", unsaved: change(settings: updated))
  }

  func include(_ bundleID: String) -> CommandResult {
    if let refusal = refusalToChangeSettings() { return refusal }
    let app = appName(forBundleID: bundleID)
    guard settings.excludedBundleIDs.contains(bundleID) else { return .failure("Arbor arranges \(app) already") }
    var updated = settings
    updated.excludedBundleIDs.removeAll { $0 == bundleID }
    return reply("arranging \(app) again", unsaved: change(settings: updated))
  }
}

extension Edge {
  /// The edge as a direction to move in.
  fileprivate var direction: String {
    switch self {
    case .left: "left"
    case .right: "right"
    case .top: "up"
    case .bottom: "down"
    }
  }

  /// Where something past this edge is.
  fileprivate var beyond: String {
    switch self {
    case .left: "to the left"
    case .right: "to the right"
    case .top: "above"
    case .bottom: "below"
    }
  }

  /// Where something docked on this edge of a window is, as in "left of w101".
  fileprivate var beside: String {
    switch self {
    case .left: "left of"
    case .right: "right of"
    case .top: "above"
    case .bottom: "below"
    }
  }
}
