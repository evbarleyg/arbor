import ArborCore

/// A shortcut of Arbor's that macOS uses as well (`SystemShortcuts`).
public struct SystemShortcutClash: Equatable, Sendable {
  public let binding: KeyBinding
  public let use: SystemShortcuts.Use
  /// For `bindings` and the setup check.
  public let sentence: String
  /// The same for the log, without the names and parts of titles that the command of a person's own shortcut can hold.
  public let logged: String
}

extension Controller {
  /// The shortcuts in effect that macOS uses as well, as things stand now, sorted as `bindings` lists them. Empty where
  /// nobody can tell (`systemShortcuts` is not set, or macOS does not say), and with Arbor's shortcuts off.
  public var systemShortcutClashes: [SystemShortcutClash] {
    guard settings.hotkeysEnabled, let system = systemShortcuts?() else { return [] }
    let bindings = effectiveBindings.bindings
    // The way out that docs/KEYBOARD.md keeps for people whose ⌃⌥Space belongs to something else.
    let home = bindings.first { $0.command == .home }
    return bindings.compactMap { binding -> SystemShortcutClash? in
      guard let use = system.use(ofKeyCode: binding.keyCode, modifiers: binding.modifiers) else { return nil }
      var more = ""
      if binding.command == .showAll, let home, system.use(ofKeyCode: home.keyCode, modifiers: home.modifiers) == nil {
        more = ". \(home.label) shows everything too"
      }
      return SystemShortcutClash(
        binding: binding, use: use, sentence: use.sentence(label: binding.label, command: binding.command.text) + more,
        logged: use.sentence(label: binding.label, command: binding.command.textWithoutNames) + more)
    }
    .sorted { ($0.binding.command.text, $0.binding.chord.text) < ($1.binding.command.text, $1.binding.chord.text) }
  }

  /// Writes them to the log, once for as long as they stay the same. The app calls it whenever it registers shortcuts,
  /// which is with every pause and every app that keeps its own keys coming and going. macOS is asked only
  /// if the shortcuts in effect have changed: reading its lists takes longer than a switch of apps should.
  public func logSystemShortcutClashes() {
    let bindings = settings.hotkeysEnabled ? effectiveBindings.bindings : []
    guard bindings != bindingsHeldAgainstMacOS else { return }
    bindingsHeldAgainstMacOS = bindings
    let sentences = systemShortcutClashes.map(\.logged)
    guard sentences != loggedSystemShortcutClashes else { return }
    if sentences.isEmpty { Log.info("shortcuts: none is macOS's as well any more") }
    for sentence in sentences { Log.info("shortcuts: \(sentence)") }
    loggedSystemShortcutClashes = sentences
  }
}
