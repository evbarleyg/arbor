import ArborCore
import CoreGraphics
import Foundation

/// Named spaces (docs/features/F20-named-spaces.md).
///
/// The names live in each display's `Workspace`, which keeps them on the right nodes as the tree changes.
/// Here are the commands, the search across displays, and what the menu, the Go to… picker, `watch`, the
/// minimap and the field for typing a name show.
extension Controller {
  // MARK: For whoever shows names

  /// A space that has a name.
  public struct NamedSpace: Equatable, Sendable {
    public var name: String
    public var display: DisplayID
    public var node: NodeID
    /// Arbor's own words for it, as in a reply: "Safari and Notes (n5)". (`name` is only ever what a person called it.)
    public var label: String
    /// The windows docked in it, in tree order.
    public var windows: [WindowID]
    /// Their apps, each once.
    public var apps: [String]
    /// It fills its display's view.
    public var isInView: Bool
    /// `go <name>` leads here. False for a name that a display looked at earlier has as well.
    public var isReachable: Bool
  }

  /// The name of a space, if it has one.
  public func spaceName(of node: NodeID, on display: DisplayID) -> String? {
    workspaces[display]?.name(of: node)
  }

  /// Every named space: the display commands act on first, then the others as macOS lists them, each
  /// display's by name. That is also the order `go` looks in.
  public func namedSpaces() -> [NamedSpace] {
    // Asking which display comes first is remembered as what the last command followed (InputLead), and this is no
    // command: the menu asks whenever it is opened. Within a command the next to ask gets the same answer.
    let lead = following.lead
    defer { following.lead = lead }
    var seen = Set<String>()
    return displaysInSearchOrder().flatMap { display -> [NamedSpace] in
      guard let workspace = workspaces[display] else { return [] }
      return SpaceName.sorted(workspace.names.keys).compactMap { name in
        guard let node = workspace.names[name] else { return nil }
        let docked = workspace.tree.windows(under: node)
        var apps: [String] = []
        for window in docked {
          if let app = windows[window]?.appName, !apps.contains(app) { apps.append(app) }
        }
        return NamedSpace(
          name: name, display: display, node: node, label: self.name(of: node, on: display, byName: false),
          windows: docked, apps: apps, isInView: workspace.camera == node,
          isReachable: seen.insert(SpaceName.key(name)).inserted)
      }
    }
  }

  private func displaysInSearchOrder() -> [DisplayID] {
    let acting = cameraDisplay()?.0
    return (acting.map { [$0] } ?? []) + displays.map(\.id).filter { $0 != acting && workspaces[$0] != nil }
  }

  // MARK: Finding

  enum Search {
    case found(NamedSpace)
    case several([String])
    case none
  }

  /// The space `text` means: the whole name wherever it is, before the beginning of a name anywhere.
  func search(for text: String, wholeNameOnly: Bool = false) -> Search {
    let spaces = namedSpaces().filter(\.isReachable)
    func space(_ name: String, in candidates: [NamedSpace]) -> Search {
      candidates.first { $0.name == name }.map(Search.found) ?? .none
    }
    if let name = SpaceName.exact(text, among: spaces.map(\.name)) { return space(name, in: spaces) }
    guard !wholeNameOnly, let acting = cameraDisplay()?.0 else { return .none }
    for candidates in [spaces.filter { $0.display == acting }, spaces.filter { $0.display != acting }] {
      switch SpaceName.match(text, among: candidates.map(\.name)) {
      case .found(let name): return space(name, in: candidates)
      case .several(let names): return .several(names)
      case .none: continue
      }
    }
    return .none
  }

  private func whyNotFound(_ text: String) -> String {
    if dormant.values.contains(where: { $0.workspace.node(named: text) != nil }) {
      return "\(text) is on a display that is not connected"
    }
    let names = namedSpaces().filter(\.isReachable).map(\.name)
    guard !names.isEmpty else { return "no space has a name yet; `name <text>` names the space in view" }
    guard names.count <= 6 else { return "no space is named \(text); `spaces` lists the names" }
    return "no space is named \(text); there \(names.count == 1 ? "is" : "are") \(Self.list(names))"
  }

  /// "A", "A and B", "A, B and C".
  static func list(_ words: [String], or: Bool = false) -> String {
    guard words.count > 1 else { return words.first ?? "" }
    return words.dropLast().joined(separator: ", ") + (or ? " or " : " and ") + words[words.count - 1]
  }

  // MARK: Commands

  func goToSpace(_ text: String) -> CommandResult {
    guard let (acting, _) = cameraDisplay() else { return .failure("no display") }
    switch search(for: text) {
    case .none:
      return .failure(whyNotFound(text))
    case .several(let names):
      guard names.count <= 6 else { return .failure("\(names.count) names begin with \(text); type more of the name") }
      return .failure("\(text) could be \(Self.list(names, or: true)); type more of the name")
    case .found(let space):
      let elsewhere = space.display != acting
      let place = self.name(of: space.node, on: space.display) + (elsewhere ? " on another display" : "")
      if !space.isInView { moveCamera(on: space.display, to: space.node) }
      // The user went there, so the keyboard does, and with it the shortcuts that follow (F56).
      if elsewhere { focusSomething(on: space.display) }
      return .success(space.isInView ? "already showing \(place)" : "moved to \(place)")
    }
  }

  /// Gives the keyboard to the window in view on `display` that had it last, or the top-left one, unless one of
  /// them has it already. Docked windows first: they are the space, while a floating window in view may be a
  /// pinned one that is in every view.
  private func focusSomething(on display: DisplayID) {
    guard let layout = layouts[display], let workspace = workspaces[display] else { return }
    var floating: [WindowID: CGRect] = [:]
    for window in workspace.floating.keys where !parked.contains(window) {
      if let snapshot = windows[window], snapshot.isPresent { floating[window] = snapshot.frame }
    }
    if let focused = keyboardFocus(), layout.windowFrames[focused] != nil || floating[focused] != nil { return }
    for candidates in [layout.windowFrames, floating] {
      let target =
        focusHistory.first { candidates[$0] != nil }
        ?? candidates.min { ($0.value.minY, $0.value.minX, $0.key) < ($1.value.minY, $1.value.minX, $1.key) }?.key
      guard let target else { continue }
      askForTheKeyboard(for: target)
      return
    }
  }

  /// The space `name` and `unname` act on: the one the field is open for, which may not be on the display
  /// commands act on by the time ↩ is pressed, or else the one in view.
  private func spaceToName() -> (DisplayID, NodeID)? {
    if let prompt = openNamePrompt { return (prompt.display, prompt.node) }
    return cameraDisplay().map { ($0.0, $0.1.camera) }
  }

  func nameSpace(_ text: String) -> CommandResult {
    guard let (display, node) = spaceToName() else { return .failure("no display") }
    // In words now: a group that loses the name to this one may dissolve, and its number with it.
    let contents = name(of: node, on: display, byName: false)
    let loser = workspaces[display]?.node(named: text).map { name(of: $0, on: display, byName: false) }
    let naming: Workspace.Naming
    do {
      naming = try workspaces[display]!.setName(text, of: node)
    } catch {
      return .failure("\(error)")
    }
    closeNamePrompt()
    guard naming.changed else { return .success("already named \(naming.name)") }
    namesChanged(on: display)
    var message = naming.replaced.map { "renamed \($0) to \(naming.name) (\(node))" } ?? "named \(contents): \(naming.name)"
    if naming.takenFrom != nil, let loser { message += "; \(loser) has no name now" }
    return .success(message)
  }

  func unnameSpace(_ text: String?) -> CommandResult {
    let (display, node): (DisplayID, NodeID)
    if let text {
      guard case .found(let space) = search(for: text, wholeNameOnly: true) else {
        return .failure(whyNotFound(text))
      }
      (display, node) = (space.display, space.node)
    } else {
      guard let space = spaceToName() else { return .failure("no display") }
      (display, node) = space
    }
    let contents = name(of: node, on: display, byName: false)
    guard let name = workspaces[display]?.removeName(of: node) else {
      return .failure("the space in view has no name" + onPointerDisplay)
    }
    closeNamePrompt()
    namesChanged(on: display)
    return .success("removed the name \(name) from \(contents)")
  }

  /// Tiles are captioned with names, and a group that is let go of may close up, so the display is laid out.
  private func namesChanged(on display: DisplayID) {
    relayout(display, reason: .structure)
    notify(.names(display))
    scheduleSave()
  }

  /// `spaces`: one line per name. A query, so it also answers during a pause.
  func spacesReport() -> CommandResult {
    let spaces = namedSpaces()
    guard !spaces.isEmpty else {
      return .success("no space has a name yet; `name <text>` names the space in view")
    }
    let acting = cameraDisplay()?.0
    let rows = spaces.map { space -> [String] in
      var notes: [String] = []
      if space.isInView { notes.append("in view") }
      if space.display != acting { notes.append("on another display") }
      return [space.name, space.label, notes.joined(separator: ", ")]
    }
    let widths = (0..<2).map { column in rows.map { $0[column].count }.max() ?? 0 }
    let lines = rows.map { row in
      zip(row, widths + [0]).map { cell, width in cell + String(repeating: " ", count: max(width - cell.count, 0)) }
        .joined(separator: "   ").trimmingTrailingSpaces()
    }
    return CommandResult(
      ok: true, message: Self.count(spaces.count, "named space"), text: lines.joined(separator: "\n"))
  }

  /// `arrange`, `float-all` and `layout` start the arrangement afresh, and saved views and names of spaces that are no
  /// more go with the old one. Nobody sees a saved view or a name go, so the reply says it.
  func notingWhatIsLost(_ change: () -> CommandResult) -> CommandResult {
    func count() -> (views: Int, names: Int) {
      workspaces.values.reduce((0, 0)) { ($0.0 + $1.savedViews.count, $0.1 + $1.names.count) }
    }
    let before = count()
    var result = change()
    guard result.ok else { return result }
    let (views, names) = (before.views - count().views, before.names - count().names)
    if views > 0 { result.message += views == 1 ? "; 1 saved view is gone" : "; \(views) saved views are gone" }
    if names > 0 { result.message += names == 1 ? "; 1 name is gone" : "; \(names) names are gone" }
    return result
  }

  // MARK: The log

  /// Every name there is, also on displays that are not connected. The displays' own as well: one can be a person's
  /// ("Somebody's iPad" over Sidecar), and replies quote them (F25).
  func everyName() -> Set<String> {
    everySpaceName().union(displays.compactMap(\.name).filter { !$0.isEmpty })
  }

  /// The names of spaces alone. A trace gives these tokens of their own kind; a display's name has its stand-in there (`display-1`).
  func everySpaceName() -> Set<String> {
    var names = Set<String>()
    for workspace in workspaces.values { names.formUnion(workspace.names.keys) }
    for entry in dormant.values { names.formUnion(entry.workspace.names.keys) }
    return names
  }

  /// `text` for the log: a name is a client, a project, something nobody else should know of, and the log is what
  /// people paste into a bug report. The space's number, which follows the name in replies, stays. Whatever reads
  /// like one of `names` goes, so a space named "Mail" also costs the log the app's name: too much rather than too little.
  static func withoutNames(_ text: String, _ names: Set<String>) -> String {
    // The longest first: "Mail" must not take a bite out of "Mail Room".
    names.sorted { ($0.count, $0) > ($1.count, $1) }.reduce(text) { $0.replacingOccurrences(of: $1, with: "‹name›") }
  }

  // MARK: The menu

  /// A row of the menu that has to do with names.
  public struct NamedSpacesMenuItem: Equatable, Sendable {
    public var title: String
    public var command: Command
    public var isTicked = false
    /// A line is drawn above this row, if anything is above it.
    public var startsSection = false
  }

  /// What names add to the menu's Saved Views submenu (docs/MENU.md): after the numbers one row per name `go` can
  /// reach, in its order, ticked when in view; then the row that names the space in view.
  public func namedSpacesMenu() -> [NamedSpacesMenuItem] {
    from(.menu) {
      namedSpaces().filter(\.isReachable).map { space in
        NamedSpacesMenuItem(title: space.name, command: .goToSpace(space.name), isTicked: space.isInView)
      } + [NamedSpacesMenuItem(title: "Name This Space…", command: .askName(cancel: false), startsSection: true)]
    }
  }

  // MARK: The field

  /// The field, if it is open and the space it was opened for still fills its display's view.
  var openNamePrompt: (display: DisplayID, node: NodeID)? {
    guard let prompt = namePrompt, workspaces[prompt.display]?.camera == prompt.node else { return nil }
    return (prompt.display, prompt.node)
  }

  func askName(cancel: Bool) -> CommandResult {
    // The shortcut pressed again puts the field away, like ⎋.
    if cancel || openNamePrompt != nil {
      closeNamePrompt()
      return .success("the name field is closed")
    }
    guard let (display, workspace) = cameraDisplay() else { return .failure("no display") }
    namePrompt = (display, workspace.camera, keyboardFocus())
    showScene(on: display)
    return .success("type a name for \(name(of: workspace.camera, on: display))")
  }

  /// Called for every focus report. The field borrows the keyboard from the window that has it, which stays the focused
  /// window meanwhile. When another window gets it (a click, ⌘Tab, a new window, a swipe to another macOS
  /// Space) the field has been left. An app in the background that changes its focused window has not taken the keyboard.
  func namePromptNoticesFocus(on id: WindowID) {
    guard let prompt = namePrompt, id != prompt.keyboard, system.focusedWindow() == id else { return }
    closeNamePrompt()
  }

  func closeNamePrompt() {
    guard let prompt = namePrompt else { return }
    namePrompt = nil
    showScene(on: prompt.display)
  }

  /// The field in `display`'s scene. Called while the scene is put together, which happens whenever the
  /// view moves or the arrangement changes: that is when a field whose space is no longer in view goes.
  func namePromptModel(on display: DisplayID) -> NamePromptModel? {
    guard namePrompt?.display == display else { return nil }
    guard let prompt = openNamePrompt, let workspace = workspaces[display], let screen = self.display(display) else {
      namePrompt = nil
      return nil
    }
    var others: [String: String] = [:]
    for (name, node) in workspace.names where node != prompt.node {
      others[name] = Self.withoutNodeNumber(self.name(of: node, on: display, byName: false))
    }
    return NamePromptModel(
      display: display, frame: NamePromptModel.frame(in: screen.visibleFrame),
      subject: .space(
        prompt.node, current: workspace.name(of: prompt.node),
        contents: Self.withoutNodeNumber(name(of: prompt.node, on: display, byName: false)), others: others))
  }

  /// Sends `display` its scene again, moving no window.
  private func showScene(on display: DisplayID) {
    guard isRunning, let layout = layouts[display] else { return }
    overlays.update(display: display, scene: overlayScene(for: layout, on: display))
  }

  /// "Safari and Notes (n5)" for the screen, where nobody types a node number: "Safari and Notes".
  private static func withoutNodeNumber(_ words: String) -> String {
    guard words.hasSuffix(")"), let open = words.lastIndex(of: "("), open > words.startIndex else { return words }
    return String(words[..<words.index(before: open)])
  }
}

extension String {
  fileprivate func trimmingTrailingSpaces() -> String {
    var text = Substring(self)
    while text.last == " " { text.removeLast() }
    return String(text)
  }
}
