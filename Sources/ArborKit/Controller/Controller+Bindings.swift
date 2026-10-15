import ArborCore

extension Controller {
  /// `bindings`: the shortcuts in effect, one `chord → command` per line sorted by command text,
  /// then the entries of settings.json's `bindings` that were skipped and why, and the shortcuts
  /// that macOS uses as well (Controller+SystemShortcuts.swift), the commands of Arbor's own map that the entries leave without a
  /// shortcut, and with the nine how to get more. A shortcut whose key
  /// is labelled otherwise on the keyboard layout in use says so: `ctrl+opt+[ (⌃⌥Ü) → back`. One that is not Arbor's at
  /// this moment says that, and why, at the end of its line (`KeysHeld`). A query, so it works before `start()`.
  func listBindings() -> CommandResult {
    let (bindings, problems) = effectiveBindings
    let held = keysHeld
    let rows = held.keys.map { key in
      let binding = key.binding
      return (
        chord: binding.chord.text + (binding.label == binding.chord.label ? "" : " (\(binding.label))"),
        command: binding.command.text + (key.fate.mark.map { "  (\($0))" } ?? "")
      )
    }
    .sorted { ($0.command, $0.chord) < ($1.command, $1.chord) }
    let width = rows.map(\.chord.count).max() ?? 0
    var lines = rows.map { row in
      row.chord + String(repeating: " ", count: width - row.chord.count) + " → " + row.command
    }
    if !problems.isEmpty {
      lines.append("")
      lines += problems.map { "skipped \($0)" }
    }
    let clashes = systemShortcutClashes
    if !clashes.isEmpty {
      lines.append("")
      lines += clashes.map(\.sentence)
    }
    let suggestions = passThroughSuggestions
    if !suggestions.isEmpty {
      lines.append("")
      lines += suggestions.map {
        "\($0.name) uses ⌃⌥ itself: `pass-through \($0.bundleID) on` turns Arbor's shortcuts off in it"
      }
    }
    // An entry goes by the keys alone, and ⌃⌥← is one command among the nine and another in the whole map: whoever freed or took the keys of
    // one has done so to the other, and should not have to guess why a key of Arbor's is dead.
    let removed = KeyBindings.standard(settings).filter { standard in !bindings.contains { $0.command == standard.command } }
    if !removed.isEmpty {
      lines.append("")
      lines += removed.map { "no shortcut runs `\($0.command.text)`: your `bindings` take \($0.chord.text) from it" }
    }
    if !settings.bindsTheWholeMap {
      lines.append("")
      lines.append(
        "Arbor's menu and `arborctl` have the rest. `set shortcuts all` binds \(KeyBindings.all.count) keys instead of these; "
          + "`bind <shortcut> <command>` adds one.")
    }
    // Nothing to say until the app has reported a layout.
    if keyboardLayout != .us {
      lines.append("")
      lines.append(
        settings.shortcutsFollowLayout
          ? "Letters, digits and signs mean the keys that type them on the \(keyboardLayout.name) keyboard layout."
          : "Letters, digits and signs mean their places on a US keyboard, because shortcutsFollowLayout is false.")
    }
    var message = "\(bindings.count) shortcuts"
    let lost = held.lost
    if !lost.isEmpty {
      lines.append("")
      // Not one by one if there are many: each has its mark above.
      lines.append(
        (lost.count > 3 ? "\(lost.count) shortcuts" : OnboardingModel.sentenceList(lost.map(\.label)))
          + " \(lost.count == 1 ? "is" : "are") not Arbor's, though nobody asked for that: Arbor does not hear what is pressed "
          + "there, and another app may. `doctor` says what to do.")
    }
    let off =
      whyKeysAreTheApps(appInFront: frontmostAppName).map {
        (shortcutsWanted.isEmpty ? "all off" : "all but \(shortcutsWanted.count) off") + " " + $0
      }
      // Said as it is: no app gets them, and nothing comes of them.
      ?? (accessibilityGranted ? nil : "Arbor takes them and can move nothing without Accessibility permission")
    if let off {
      message += ", " + off
      // In the text as well, and last, where a terminal leaves it in sight: `arborctl` prints only the text.
      lines.append("")
      lines.append("Right now: \(off).")
    }
    if !lost.isEmpty { message += ", \(lost.count) not Arbor's" }
    if !problems.isEmpty { message += ", \(problems.count) skipped" }
    if !clashes.isEmpty { message += ", \(clashes.count) also macOS's" }
    return CommandResult(ok: true, message: message, text: lines.joined(separator: "\n"))
  }
}
