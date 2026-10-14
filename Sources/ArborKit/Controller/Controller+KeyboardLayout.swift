import ArborCore

/// Shortcuts follow the keyboard layout (docs/features/F44-shortcuts-follow-the-keyboard-layout.md). The
/// rules are `KeyLayout`'s; the app reports the layout macOS has selected and registers
/// `activeBindings` again when told that they changed.
extension Controller {
  /// The layout the shortcuts are made for.
  public var layoutInEffect: KeyLayout { settings.shortcutsFollowLayout ? keyboardLayout : .us }

  /// The shortcuts in effect on that layout, and the entries that were skipped and why. What is held at
  /// this moment may be less: see `activeBindings`.
  public var effectiveBindings: (bindings: [KeyBinding], problems: [String]) {
    KeyBindings.effective(settings: settings, layout: layoutInEffect)
  }

  /// Another keyboard layout was selected. Observers hear of it only if a shortcut moved to another key or
  /// changed its label: going from one input method to another over the same Latin layout changes nothing.
  public func keyboardLayoutChanged(_ layout: KeyLayout) {
    guard layout != keyboardLayout else { return }
    let before = effectiveBindings
    keyboardLayout = layout
    Log.info("keyboard layout: \(layout.name)")
    let after = effectiveBindings
    if before.bindings != after.bindings || before.problems != after.problems { notify(.input) }
  }
}
