import ArborCore

/// The shortcuts on screen (`show-shortcuts`, ⌃⌥⇧/; docs/features/F43-say-what-happened.md): a panel with every shortcut in
/// effect. What it lists is `CheatSheetModel`'s business. It stays until a key is pressed, the mouse is clicked
/// or any command runs.
extension Controller {
  func toggleCheatSheet() -> CommandResult {
    guard headsUp.cheatSheet == nil else {
      hideCheatSheet()
      return .success("put the shortcuts away")
    }
    guard settings.hotkeysEnabled else {
      return .failure("shortcuts are switched off: hotkeysEnabled is false in settings.json")
    }
    // In an app that keeps its own ⌃⌥ the list is what people come back to, so it is all there, under a heading that
    // says what it is worth here.
    let shortcuts = isPassingThrough ? effectiveBindings.bindings : activeBindings
    guard !shortcuts.isEmpty else { return .failure("every shortcut has been removed in settings.json") }
    guard let (id, _) = cameraDisplay(), let display = display(id) else { return .failure("no display") }
    var model = CheatSheetModel(
      shortcuts: shortcuts.map { ($0.chord, $0.command) }, pointer: CheatSheetModel.pointerRows(settings: inputSettings),
      layout: layoutInEffect)
    model.area = display.visibleFrame
    var message = "showing \(Self.count(shortcuts.count, "shortcut"))"
    if isPassingThrough {
      let held = activeBindings.map(\.label)
      model.title = "Off in \(frontmostAppName)" + (held.isEmpty ? "" : ", except \(held.joined(separator: " and "))")
      message += ", off in \(frontmostAppName)" + (held.isEmpty ? "" : " except \(held.joined(separator: " and "))")
    }
    hideHeadsUp()
    // One panel has the keyboard at a time. Closed first: a field that loses the keyboard to the panel would cancel itself by
    // command, and any command puts the panel away.
    closeNamePrompt()
    headsUp.cheatSheet = id
    overlays.showCheatSheet(model, on: id)
    return CommandResult(
      ok: true, message: message + "; any key or click puts them away",
      text: (isPassingThrough ? model.title + "\n\n" : "") + model.text)
  }

  func hideCheatSheet() {
    guard let display = headsUp.cheatSheet else { return }
    headsUp.cheatSheet = nil
    overlays.showCheatSheet(nil, on: display)
  }

  /// Part of `OverlayActions`.
  public func cheatSheetDismissed() { hideCheatSheet() }
}
