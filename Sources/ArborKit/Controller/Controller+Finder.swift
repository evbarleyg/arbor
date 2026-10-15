import ArborCore
import CoreGraphics
import Foundation

/// "Go to…" (docs/features/F27-window-finder.md). Most windows are out of view most of the time, so finding
/// one has to take a keystroke and a few letters: `find` opens a palette listing every window and saved
/// view, `find <text>` goes straight to the best match, and `reveal` brings one window into view whatever keeps
/// it out of it.
///
/// The matching, the selection and the palette's geometry are pure (`FinderQuery`, `FinderSession`,
/// `FinderLayout` in ArborCore). This file makes the list and goes where the user chose.
///
/// Titles, and what the user types to find them, are shown but never logged.
extension Controller {
  // MARK: The list

  /// Every window Arbor arranges, on every display: the ones that have had the keyboard, the latest
  /// first, but the focused window after them, then the rest in the order they are laid out. As with
  /// ⌘Tab, the first is the window the user was in before this one, and never the one they are in.
  func windowsByRecency() -> [WindowID] {
    let listed = displays.flatMap { workspaces[$0.id]?.allWindows ?? [] }.filter(isManaged)
    let known = Set(listed)
    let focused = keyboardFocus().flatMap { known.contains($0) ? $0 : nil }
    var order: [WindowID] = []
    var seen = Set<WindowID>()
    for window in focusHistory.filter({ $0 != focused }) + [focused].compactMap({ $0 }) + listed
    where known.contains(window) && seen.insert(window).inserted {
      order.append(window)
    }
    // Right after launch no other window has had the keyboard yet. Return must still go somewhere.
    if order.count > 1, order[0] == focused { order.swapAt(0, 1) }
    return order
  }

  /// Everywhere the finder can go, in the order an empty query shows it.
  func finderRows() -> [FinderModel.Row] { windowRows() + leftAloneRows() + namedSpaceRows() + savedViewRows() }

  func windowRows() -> [FinderModel.Row] {
    windowsByRecency().compactMap { id in
      guard let window = windows[id], let display = workspaceID(containing: id) else { return nil }
      return FinderModel.Row(
        destination: .window(id), name: FinderCandidate.line(window.appName, limit: FinderCandidate.nameLimit),
        detail: FinderCandidate.line(window.title), place: place(of: window, on: display), display: display,
        displayName: displayLabel(display), pid: window.pid, bundleID: window.bundleID)
    }
  }

  /// Whether Arbor leaves `window` alone because the user said so: Don't Arrange, or an `ignore` rule. Someone looking
  /// for Slack does not care that Arbor does not arrange it. Not Arbor's own windows, and not those outside
  /// `onlyPIDs`, which an Arbor under test is not to know about.
  func isLeftAlone(_ window: WindowSnapshot) -> Bool {
    var allowed = filter
    allowed.excludedBundleIDs = []
    allowed.ignoredWindowIDs = []
    return !filter.manages(window) && allowed.manages(window)
  }

  /// The windows Arbor leaves alone, by app and then by number: it does not keep track of when they had the keyboard.
  func leftAloneRows() -> [FinderModel.Row] {
    windows.values.filter(isLeftAlone).sorted { ($0.appName, $0.id) < ($1.appName, $1.id) }.compactMap { window in
      guard let display = displayID(at: window.frame.center) ?? mainDisplayID else { return nil }
      return FinderModel.Row(
        destination: .window(window.id), name: FinderCandidate.line(window.appName, limit: FinderCandidate.nameLimit),
        detail: FinderCandidate.line(window.title), place: .notArranged, display: display,
        displayName: displayLabel(display), pid: window.pid, bundleID: window.bundleID)
    }
  }

  /// The saved views of every display, by number, each with the apps it shows.
  func savedViewRows() -> [FinderModel.Row] {
    displays.flatMap { display -> [FinderModel.Row] in
      guard let workspace = workspaces[display.id] else { return [] }
      return (1...9).compactMap { slot in
        guard let node = workspace.savedView(slot: slot) else { return nil }
        return FinderModel.Row(
          destination: .view(display.id, slot: slot), name: "View \(slot)", detail: contents(of: node, in: workspace),
          place: .savedView, display: display.id, displayName: displayLabel(display.id))
      }
    }
  }

  /// The named spaces of every display (F20), in the order `go` looks in. All of them: a row says which display it means,
  /// so a name that `go` cannot reach, because a display looked at earlier has it too, can be reached here.
  func namedSpaceRows() -> [FinderModel.Row] {
    namedSpaces().compactMap { space in
      workspaces[space.display].map {
        FinderModel.Row(
          destination: .space(space.display, space.node), name: FinderCandidate.line(space.name, limit: FinderCandidate.nameLimit),
          detail: contents(of: space.node, in: $0), place: .namedSpace, display: space.display,
          displayName: displayLabel(space.display))
      }
    }
  }

  /// What a space holds, as it is laid out, each app once: "Safari, the Desktop, Notes".
  func contents(of node: NodeID, in workspace: Workspace) -> String {
    var names: [String] = []
    for id in workspace.tree.preorder(from: node) {
      switch workspace.tree[id]?.kind {
      case .desktop: names.append("the Desktop")
      case .stack(let stacked, _): names += stacked.compactMap { windows[$0]?.appName }
      case .split, nil: break
      }
    }
    var seen = Set<String>()
    return FinderCandidate.line(names.filter { seen.insert($0).inserted }.joined(separator: ", "))
  }

  func place(of window: WindowSnapshot, on display: DisplayID) -> FinderPlace {
    if window.isMinimized { return .minimized }
    if window.isHidden { return .hiddenApp }
    if window.isFullScreen { return .fullScreen }
    if !window.isOnActiveSpace { return .otherSpace }
    guard let leaf = workspaces[display]?.tree.leaf(containing: window.id) else {
      switch workspaces[display]?.role(of: window.id) {
      case .pinned: return .keptInView
      case .summoned: return .summoned
      case .stashed: return .stashed
      case nil: return parked.contains(window.id) ? .floatingOutOfView : .floating
      }
    }
    if layouts[display]?.windowFrames[window.id] != nil { return .inView }
    if let showing = treeView(display)?.visibleWindow(of: leaf), showing != window.id { return .tab }
    if layouts[display]?.tiles.contains(where: { $0.windows.contains(window.id) }) == true { return .tile }
    return .outOfView
  }

  /// What to call a display where users read it. Nil with a single display, which needs no name.
  func displayLabel(_ id: DisplayID) -> String? {
    // Numbered as `@2` and `displays` count them: the main one, then from left to right.
    guard displays.count > 1, let display = display(id), let number = number(of: id) else { return nil }
    guard let name = display.name, !name.isEmpty else { return "display \(number)" }
    // Two displays of the same make have the same name.
    return displays.filter { $0.name == name }.count > 1 ? "\(name) (\(number))" : name
  }

  // MARK: Commands

  /// `find`: opens the palette, or closes it if it is open, as the key that summons Spotlight does.
  /// `find <text>`: goes to the best match without showing anything.
  ///
  /// `perform` does not log this command: its text is likely to be part of a window title (`Command.textForLog`).
  func find(_ text: String?) -> CommandResult {
    guard let text else { return toggleFinder() }
    let rows = finderRows()
    let ranked = FinderQuery(text).rank(rows.map(\.candidate))
    guard let best = ranked.first else {
      Log.debug("find failed: nothing matches among \(rows.count)")
      let asked = FinderCandidate.line(text, limit: 80)
      return .failure("no window, space or saved view matches “\(asked)”")
    }
    return go(to: rows[best.index].destination, by: "find")
  }

  private func toggleFinder() -> CommandResult {
    if finder != nil {
      closeFinder()
      return .success("closed Go to…")
    }
    // The hand that holds the mouse button cannot choose, and nothing could be gone to (`revealAndFocus`).
    guard drag == nil else { return .failure("a window is being dragged; drop it first") }
    guard let id = commandDisplayID(), let model = finderModel(on: id) else { return .failure("no display") }
    guard !model.rows.isEmpty else { return .failure("there are no windows to go to") }
    finder = OpenFinder(display: id, openedOver: keyboardFocus())
    overlays.showFinder(model)
    Log.info("find: showing \(model.rows.count) destination(s) on \(id)")
    return .success("Go to… is open")
  }

  func finderModel(on id: DisplayID, notice: String? = nil) -> FinderModel? {
    // The display the palette opened on may have gone since.
    guard let display = display(id) ?? commandDisplayID().flatMap({ self.display($0) }) else { return nil }
    return FinderModel(
      display: display.id, screen: display.visibleFrame, rows: finderRows(), commands: paletteCommands(on: display.id).map(\.row),
      notice: notice)
  }

  /// The palette while it is open.
  struct OpenFinder {
    var display: DisplayID
    /// The window that had the keyboard when it opened.
    var openedOver: WindowID?
  }

  /// Also called by `shutdown`.
  func closeFinder() {
    guard finder != nil else { return }
    finder = nil
    overlays.showFinder(nil)
  }

  /// Whoever runs another command, with a shortcut or from the menu, has left the palette; and what it says about where
  /// windows are would no longer be true. `find` itself toggles it, or closes it when it goes somewhere.
  func closeFinder(before command: Command) {
    if case .find = command { return }
    if !command.isQuery { closeFinder() }
  }

  /// The palette closes itself when it loses the keyboard. But a palette left floating over everything, deaf, would be
  /// worse than one closed twice, so whatever tells the controller that the user is elsewhere closes it too:
  /// another window reports the keyboard, a drag begins, the displays change.
  func closeFinderBecauseTheUserLeft(for window: WindowID? = nil) {
    guard let finder else { return }
    // The window the palette opened over may well report late that a command gave it the keyboard.
    if let window, window == finder.openedOver { return }
    Log.debug("find: closed, the user is elsewhere")
    closeFinder()
  }

  /// Goes to a destination and logs it on behalf of `source`, with ids only.
  @discardableResult
  func go(to destination: FinderDestination, by source: String) -> CommandResult {
    // Closed first, so the keyboard is back with the apps before one of them is given it.
    closeFinder()
    let result: CommandResult
    switch destination {
    case .window(let window):
      result = revealAndFocus(window)
    case .view(let display, let slot):
      if let node = workspaces[display]?.savedView(slot: slot) {
        moveCamera(on: display, to: node)
        result = .success("view \(slot): \(name(of: node, on: display))")
      } else {
        result = .failure("view \(slot) is not saved")
      }
    case .space(let display, let node):
      if workspaces[display]?.tree.contains(node) == true {
        moveCamera(on: display, to: node)
        result = .success("framed \(name(of: node, on: display))")
      } else {
        result = .failure("that space no longer exists")
      }
    case .command:
      // `finderChose` runs those. Nothing else that goes somewhere is given one.
      result = .failure("that is a command, not a place")
    case .together(let windows):
      // As a command from one of Arbor's own windows: one step to take back, and a refusal is said on screen.
      return from(.menu) { executeAndSay(.sideBySide(windows), from: .menu) }
    }
    // Replies call a named space by its name; the log does not (F20).
    let message = Self.withoutNames(result.message, everyName())
    if result.ok {
      Log.info("\(source): \(destination): \(message)")
    } else {
      Log.debug("\(source): \(destination) failed: \(message)")
    }
    return result
  }

  /// `reveal`: brings a window into view and gives it the keyboard, whatever keeps it out of view: the
  /// camera, another tab, the Dock, ⌘H, full screen or another macOS Space.
  func revealAndFocus(_ window: WindowID?) -> CommandResult {
    if let asked = window ?? keyboardFocus(), let snapshot = windows[asked], isLeftAlone(snapshot) {
      // Not Arbor's to place: it is shown and focused where it is.
      if snapshot.isHidden { system.unhideApp(pid: snapshot.pid) }
      if snapshot.isMinimized { system.setMinimized(asked, false) }
      askForTheKeyboard(for: asked)
      return .success("\(asked) is focused; Arbor does not arrange it")
    }
    let id: WindowID
    if let asked = window ?? keyboardFocus(), isManaged(asked), windows[asked]?.isFullScreen == true,
      workspaceID(containing: asked) != nil
    {
      // `target` refuses it, because commands rearrange and its arrangement is out of sight. This one only looks.
      id = asked
    } else {
      switch target(window) {
      case .failure(let result): return result
      case .window(let found, _): id = found
      }
    }
    // `bringIntoView` leaves the camera alone during a drag.
    guard drag == nil else { return .failure("a window is being dragged; drop it first") }
    guard let snapshot = windows[id] else { return .failure("\(id) has closed") }
    fetchWhole(id)

    // macOS reports that these happened a moment later, in no particular order with the focus change. The view waits for that.
    let isAskedBack = !snapshot.isPresent && snapshot.isOnActiveSpace && !snapshot.isFullScreen
    if isAskedBack { awaitTheReturn(of: id) }
    if snapshot.isHidden { system.unhideApp(pid: snapshot.pid) }
    if snapshot.isMinimized { system.setMinimized(id, false) }

    // Asked for by name. `hold still` (F58), which a call starts by itself, stops the view from following a window that
    // took the keyboard uninvited, and goes by clicks and modifier keys: Return in the palette is neither. Said after the
    // window was asked back, whose own report of the keyboard would unsay it.
    holdNotesRequest(for: id)
    if windows[id]?.isPresent == true, let home = workspaceID(containing: id), workspaces[home]!.isStashed(id) {
      // Sent away by `summon`, it has no place the view could go to: it comes over the view as `summon` brings it. Now,
      // and not when macOS reports that it has the keyboard, and the keyboard goes back where it was when it is sent away
      // again. One that is still on its way back from the Dock or from ⌘H comes with that report.
      return summonStashed(id)
    }
    if snapshot.isOnActiveSpace, !snapshot.isFullScreen, windows[id]?.isPresent == true {
      // Now, rather than when the report of the keyboard comes in (Controller+Focus.swift), so that the command does what it says
      // whether or not the window gets the keyboard. One that is still on its way back is shown when macOS says that it is
      // there, for the same reason, and in one layout (Controller+OneLayout.swift).
      onTheWay(to: id) {
        bringIntoView(id)
        // How small a window can be, Arbor learns by trying (and has forgotten since it was last launched). One that refused
        // its slot is a tile now: it is framed at once, not when macOS reports that a window out of view has the keyboard.
        if windows[id]?.isPresent == true, parked.contains(id) { bringIntoView(id) }
      }
    }
    // Otherwise focusing it makes macOS switch Spaces. Moving the camera now would rearrange the Space the user is
    // about to leave; the camera follows the focus report once the window's own Space shows.
    askForTheKeyboard(for: id)
    // By what was so when it was asked for. On a Mac no report comes before the command has ended; a stand-in's may, and an answer that
    // went by that would be another in a replay.
    if isAskedBack { return .success("\(id) is on its way back, and comes into view when it is there") }
    return .success("\(id) is in view and focused")
  }

  // MARK: What the user did in the palette (part of `OverlayActions`)

  public func finderChose(_ destination: FinderDestination) {
    actsOfAHand += 1
    defer { actsOfAHand -= 1 }
    guard isRunning, let display = finder?.display else { return }
    let gone: String?
    switch destination {
    case .window(let window):
      let isThere = isManaged(window) && workspaceID(containing: window) != nil || windows[window].map(isLeftAlone) == true
      gone = isThere ? nil : "That window has closed"
    case .view(let display, let slot):
      gone = workspaces[display]?.savedView(slot: slot) != nil ? nil : "That saved view no longer exists"
    case .space(let display, let node):
      gone = workspaces[display]?.tree.contains(node) == true ? nil : "That space no longer exists"
    case .command(let text):
      runFromThePalette(text, on: display)
      return
    case .together(let windows):
      let allThere = windows.allSatisfy { isManaged($0) && workspaceID(containing: $0) != nil }
      gone = allThere ? nil : "One of those windows has closed"
      // On the display the palette is open on, whichever a command would pick.
      sideBySideDisplay = display
    }
    defer { sideBySideDisplay = nil }
    if let gone {
      // The list is a snapshot from when the palette opened. Say so, and show what there is now.
      Log.debug("find: \(destination) has gone")
      if let model = finderModel(on: display, notice: gone) {
        overlays.showFinder(model)
      } else {
        closeFinder()
      }
      return
    }
    // As `perform` does for the commands it runs: the focus ring flashes on the window gone to.
    expectFocusToMove()
    go(to: destination, by: "find")
  }

  public func finderDismissed() {
    finder = nil
  }
}
