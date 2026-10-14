import ArborCore
import CoreGraphics

/// The small queries (ArborCore/Queries.swift, docs/SCRIPTING.md): what a script wants to know without walking `state`.
extension Controller {
  private func answer<Row: Encodable>(_ rows: [Row], fields: (Row) -> [String], noun: String) -> CommandResult {
    CommandResult(
      ok: true, message: Self.count(rows.count, noun), text: Query.table(rows.map(fields)), json: JSONValue(encoding: rows))
  }

  /// A pause is not a failure: Arbor is well and is not looking, so there is nothing to list, and a status bar can tell that from
  /// something having gone wrong by the exit code alone. `status` says that it is a pause, and the events say when it begins and ends.
  private func whileNotRunning<Row: Encodable>(_ none: [Row]) -> CommandResult {
    guard isPaused else { return .failure(statusText) }
    return CommandResult(ok: true, message: statusText, text: "", json: JSONValue(encoding: none))
  }

  /// In the order in which a name finds its window (`windowCandidates()`), so the first line with an app on it is the window
  /// `zoom <app>` means: most recently focused first, and those that are minimised, hidden or on another macOS Space after the others.
  func listWindows(titles: Bool) -> CommandResult {
    guard isRunning else { return whileNotRunning([Query.Window]()) }
    let focused = system.focusedWindow()
    let rows = windowCandidates().compactMap { candidate -> Query.Window? in
      guard let window = windows[candidate.id], let display = workspaceID(containing: window.id),
        let workspace = workspaces[display]
      else { return nil }
      let leaf = workspace.tree.leaf(containing: window.id)
      let role = workspace.role(of: window.id)
      var isSummoned = false
      if case .summoned = role { isSummoned = true }
      return Query.Window(
        id: window.id, docked: leaf != nil, state: eventState(of: window, in: layouts[display], docked: leaf != nil),
        display: number(of: display) ?? 1, displayID: display, bundleID: window.bundleID, app: window.appName,
        title: titles ? window.title : nil, focused: window.id == focused, frame: window.frame, node: leaf,
        pinned: role == .pinned, summoned: isSummoned)
    }
    return answer(rows, fields: \.fields, noun: "window")
  }

  /// What the `view` event says (`eventSummary`), asked for instead of waited for: the two must never tell different stories.
  func listPlaces() -> CommandResult {
    guard isRunning else { return whileNotRunning([Query.Place]()) }
    let views = eventSummary(focused: nil).views
    let rows = numberedDisplays.enumerated().compactMap { index, display -> Query.Place? in
      guard let view = views.first(where: { $0.display == display.id }), let tree = workspaces[display.id]?.tree else { return nil }
      return Query.Place(
        display: index + 1, displayID: display.id, label: view.label, node: view.node, kind: view.kind, depth: view.depth,
        deepest: tree.preorder().map { stepsOut(from: $0, on: display.id) }.max() ?? 0, outOfView: view.outOfView,
        windows: view.windows, apps: view.apps, canGoBack: view.canGoBack, canGoForward: view.canGoForward, name: view.name)
    }
    return answer(rows, fields: \.fields, noun: "display")
  }

  func listViews() -> CommandResult {
    guard isRunning else { return whileNotRunning([Query.SavedView]()) }
    var rows: [Query.SavedView] = []
    for (index, display) in numberedDisplays.enumerated() {
      guard let workspace = workspaces[display.id] else { continue }
      // What fills the display, as in `where`.
      let showing = layouts[display.id]?.camera ?? workspace.camera
      for slot in 1...9 {
        guard let node = workspace.savedView(slot: slot) else { continue }
        rows.append(
          Query.SavedView(
            display: index + 1, displayID: display.id, view: slot, label: label(of: node, on: display.id), node: node,
            current: node == showing, name: spaceName(of: node, on: display.id)))
      }
    }
    return answer(rows, fields: \.fields, noun: "saved view")
  }

  /// Also before Arbor has started (F25): whoever writes `displays` into settings.json wants to hear what became of it.
  func listDisplays() -> CommandResult {
    let pointer = isRunning ? pointerDisplayID : nil
    let focus = isRunning ? system.focusedWindow().flatMap { workspaceID(containing: $0) } : nil
    let rows = (isRunning ? numberedDisplays : []).enumerated().map { index, display in
      var row = Query.Display(
        display: index + 1, id: display.id, frame: display.frame, visibleFrame: display.visibleFrame, main: display.isMain,
        pointer: display.id == pointer, focus: display.id == focus)
      let inEffect = options(for: display.id)
      row.name = display.name.flatMap { $0.isEmpty ? nil : $0 }
      row.builtIn = display.isBuiltIn
      (row.gap, row.screenEdgeBand) = (inEffect.gap, inEffect.screenEdgeBand)
      (row.minimumUsableWidth, row.minimumUsableHeight) = (inEffect.minimumUsableWidth, inEffect.minimumUsableHeight)
      for given in DisplayOptions.given(by: settings.displays, to: display.traits) { row.from[given.key] = "\(given.match)" }
      return row
    }
    var result = answer(rows, fields: \.fields, noun: "display")
    // The table stays a table, for `cut`. What else there is to say goes beside it.
    if !isRunning { result.message = statusText }
    // Not during a pause, which is no news to whoever asks every two seconds.
    var remarks = isRunning || isPaused ? [] : ["no displays yet: \(statusText)"]
    if !settings.skippedDisplays.isEmpty {
      remarks.append("skipped entries of \"displays\" in settings.json:\n" + settings.skippedDisplays.map { "  \($0)" }.joined(separator: "\n"))
    }
    if !remarks.isEmpty { result.warning = remarks.joined(separator: "\n") }
    return result
  }

  /// The core knows the usage and the other names; the shortcuts in effect are known here.
  func help(on topic: String) -> CommandResult {
    guard var text = Command.help(on: topic), let verb = Command.canonicalVerb(topic) else {
      return .failure("no command `\(topic)`; try `help`")
    }
    // On the keyboard in use, as `bindings` and the menu show them.
    let shortcuts = effectiveBindings.bindings
      .filter { $0.command.text.prefix { $0 != " " } == verb }
      .map { "\($0.label) \($0.command.text)" }
    if !shortcuts.isEmpty, settings.hotkeysEnabled {
      text += "\n  shortcut\(shortcuts.count == 1 ? "" : "s"): " + shortcuts.joined(separator: ", ")
    }
    return CommandResult(ok: true, message: "help on \(verb)", text: text)
  }
}
