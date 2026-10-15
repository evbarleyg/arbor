import ArborCore

/// A global keyboard shortcut bound to a command.
public struct KeyBinding: Sendable, Equatable {
  public typealias Modifiers = KeyChord.Modifiers
  public typealias Key = KeyChord.Key

  public let chord: KeyChord
  public let command: Command
  /// The key to register, on the keyboard layout the binding was made for (`KeyLayout`).
  public let keyCode: UInt32
  /// How menus show the shortcut on that layout, e.g. ⌃⌥Space.
  public let label: String

  public init(_ chord: KeyChord, _ command: Command, layout: KeyLayout = .us) {
    self.chord = chord
    self.command = command
    keyCode = chord.code(in: layout)
    label = chord.label(in: layout)
  }

  public init(_ modifiers: Modifiers, _ key: Key, _ command: Command) {
    self.init(KeyChord(modifiers, key), command)
  }

  public var modifiers: Modifiers { chord.modifiers }
}

extension KeyChord.Modifiers {
  /// ⌃⌥, Arbor's base chord.
  public static let hyperless: KeyChord.Modifiers = [.control, .option]
}

extension KeyChord.Key {
  /// 1–9, the saved-view keys.
  static let digits: [KeyChord.Key] = [
    .digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7, .digit8, .digit9,
  ]
}

public enum KeyBindings {
  /// The shortcuts as Arbor ships (`shortcuts` is `core`): nine, each ⌃⌥ and one key, which a newcomer learns in a minute. A global
  /// shortcut is taken from every app on the Mac, so the rest is in the menu, and has a key for whoever asks (collab/IDEAS.md, I22).
  /// `LessByDefaultTests` holds the list to ten and to ⌃⌥: an eleventh takes the place of another.
  public static let core: [KeyBinding] = [
    KeyBinding(.hyperless, .left, .dock(nil, .left)),
    KeyBinding(.hyperless, .right, .dock(nil, .right)),
    KeyBinding(.hyperless, .returnKey, .zoom(nil)),
    KeyBinding(.hyperless, .space, .showAll),
    KeyBinding(.hyperless, .leftBracket, .back),
    KeyBinding(.hyperless, .z, .undo),
    KeyBinding(.hyperless, .f, .toggleFloat(nil)),
    KeyBinding(.hyperless, .g, .find(nil)),
    KeyBinding(.hyperless, .escape, .togglePause),
  ]

  /// Arbor's own shortcuts under these settings, before `bindings` changes single keys.
  public static func standard(_ settings: Settings) -> [KeyBinding] { settings.bindsTheWholeMap ? all : core }

  /// The whole map (`shortcuts` is `all`), which shipped until the nine did. ⌃⌥ moves the camera; ⌃⌥⌘ moves windows. The `bindings`
  /// key of settings.json changes it; see `effective(settings:)`.
  ///
  /// `arrange` has no key, here or among the nine. It had ⌃⌥A, which reached a chat app in front and archived the conversation there
  /// (collab/IDEAS.md, I16): that key is never bound again unless a person binds it.
  public static let all: [KeyBinding] = {
    let base: KeyBinding.Modifiers = .hyperless
    let move: KeyBinding.Modifiers = [.control, .option, .command]
    let shifted: KeyBinding.Modifiers = [.control, .option, .shift]
    var bindings: [KeyBinding] = [
      KeyBinding(base, .space, .showAll),
      KeyBinding(base, .up, .stepOut),
      KeyBinding(base, .down, .stepIn),
      KeyBinding(base, .left, .neighbor(.left)),
      KeyBinding(base, .right, .neighbor(.right)),
      KeyBinding(shifted, .up, .focus(.direction(.top))),
      KeyBinding(shifted, .down, .focus(.direction(.bottom))),
      KeyBinding(base, .returnKey, .zoom(nil)),
      KeyBinding(base, .leftBracket, .back),
      KeyBinding(base, .rightBracket, .forward),
      KeyBinding(base, .d, .desktop),
      KeyBinding(base, .f, .toggleFloat(nil)),
      KeyBinding(move, .left, .dock(nil, .left)),
      KeyBinding(move, .right, .dock(nil, .right)),
      KeyBinding(move, .up, .dock(nil, .top)),
      KeyBinding(move, .down, .dock(nil, .bottom)),
      KeyBinding(base, .z, .undo),
      KeyBinding(shifted, .z, .redo),
    ]
    // ⌘, is how apps open their settings, but Arbor is never the active app.
    bindings.append(KeyBinding(base, .comma, .settings(.showWindow())))
    for (index, key) in KeyBinding.Key.digits.enumerated() {
      bindings.append(KeyBinding(base, key, .goToView(index + 1)))
      bindings.append(KeyBinding(shifted, key, .saveView(index + 1)))
    }
    // docs/KEYBOARD.md is the map of every default, assigned and reserved key. Take keys from there.
    bindings += [
      // "View 0", and what ⌘0 does to the zoom in any app. Also for people whose ⌃⌥Space is taken
      // by macOS ("select next source in Input menu") or their IDE.
      KeyBinding(base, .digit0, .home),
      KeyBinding(shifted, .f, .floatAll),
      KeyBinding(base, .escape, .togglePause),
      KeyBinding(base, .n, .askName(cancel: false)),
      KeyBinding(base, .g, .find(nil)),
      // ⌃⌥?, as ⇧⌘/ is Help in every app.
      KeyBinding(shifted, .slash, .showShortcuts),
      KeyBinding(base, .m, .minimap),
    ]
    // Keyboard tiling tools (F22). ⌃⌥⇧ + arrow moves focus in all four directions and, with no window that way
    // in view, does what `neighbor` does, which is what these keys ran before (↑ and ↓ are further up).
    bindings += [
      KeyBinding(shifted, .left, .focus(.direction(.left))),
      KeyBinding(shifted, .right, .focus(.direction(.right))),
      KeyBinding(move, .equals, .grow(nil)),
      KeyBinding(move, .minus, .shrink(nil)),
      KeyBinding(move, .digit0, .equalize(all: false)),
      KeyBinding(base, .r, .rotate),
      KeyBinding(shifted, .r, .mirror),
    ]
    return bindings
  }()

  /// The shortcuts to keep registered while Arbor is paused: only those that end the pause. The
  /// point of pausing is often to give ⌃⌥ back to a game, a remote desktop or an editor.
  public static func whilePaused(_ bindings: [KeyBinding]) -> [KeyBinding] {
    bindings.filter(\.command.endsPause)
  }

  /// The shortcuts to register on top of `bindings` while a peek started with `chord` is held. The arrow keys
  /// and ⎋ arrive with the modifiers that are being held, and a peek takes those chords whatever they are bound
  /// to (of the nine ←, → and ⎋ are bound, in the whole map all five). These are the ones that are bound to nothing, so that
  /// they reach Arbor at all; their commands are never run.
  public static func whilePeeking(_ chord: KeyChord, besides bindings: [KeyBinding]) -> [KeyBinding] {
    let keys: [(KeyChord.Key, Command)] = [
      (.left, .neighbor(.left)), (.right, .neighbor(.right)), (.up, .neighbor(.top)), (.down, .neighbor(.bottom)),
      (.escape, .showAll),
    ]
    return keys.map { KeyBinding(KeyChord(chord.modifiers, $0.0), $0.1) }
      .filter { extra in !bindings.contains { $0.chord == extra.chord } }
  }

  /// The shortcuts to keep registered while an app that keeps its own ⌃⌥ is frontmost.
  public static func whilePassingThrough(_ bindings: [KeyBinding]) -> [KeyBinding] {
    bindings.filter(\.command.worksInPassThroughApps)
  }

  /// The shortcuts to keep registered in an app that keeps its own ⌃⌥ while Arbor has lost Accessibility permission with windows out of
  /// view: the ones a person who misses a window presses. They cannot help; they are there to say why. (In every other app
  /// Arbor keeps all its keys then: `Controller.activeBindings`.)
  public static func whileWindowsAreOutOfReach(_ bindings: [KeyBinding]) -> [KeyBinding] {
    bindings.filter(\.command.bringsWindowsBack)
  }

  /// The shortcuts in effect: `standard(settings)` with settings.json's `bindings` applied. An entry for a
  /// chord that is bound there replaces that binding, a null command removes it, and other
  /// chords are added. The user's bindings come first, so `label(for:)` shows the user's own shortcut
  /// for a command that has one. Entries that cannot be used are skipped; `problems` says which and
  /// why, one line each, starting with the chord as written.
  ///
  /// The result is made for `layout`: key codes, labels, and shortcuts that land on one key there.
  /// `Controller.effectiveBindings` passes the layout in use; without one, a US keyboard is assumed.
  public static func effective(
    settings: Settings, layout: KeyLayout = .us
  ) -> (bindings: [KeyBinding], problems: [String]) {
    var remaining = standard(settings)
    var added: [KeyBinding] = []
    var problems: [String] = []
    func skip(_ text: String, _ reason: String) { problems.append("\(text): \(reason)") }

    for text in settings.unreadableBindings {
      skip(text, "the command must be text, or null to remove the shortcut")
    }
    /// An entry stands in for the default with the same shortcut. One that names a key by its place or by what is printed
    /// on it (`us:[`, `ü`) also stands in for the default that sits on that key on this layout: Back, shown as ⌃⌥Ü.
    func isReplaced(_ standard: KeyChord, by chord: KeyChord) -> Bool {
      if standard == chord { return true }
      return chord.isPositional && standard.modifiers == chord.modifiers && standard.code(in: layout) == chord.code(in: layout)
    }
    var seen: [KeyChord: String] = [:]  // chord → the entry that took effect for it
    // Sorted so the result, and which of two spellings of one chord wins, does not depend on the
    // order of the keys in the file.
    for (text, value) in settings.bindings.sorted(by: { $0.key < $1.key }) {
      let chord: KeyChord
      do {
        chord = try KeyChord(text: text, layout: layout)
      } catch {
        skip(text, "\(error)")
        continue
      }
      if let earlier = seen[chord] {
        skip(text, "the same shortcut as \(earlier), which is used instead")
        continue
      }
      guard let commandText = value else {
        remaining.removeAll { isReplaced($0.chord, by: chord) }
        seen[chord] = text
        continue
      }
      let command: Command
      do {
        command = try Command.parse(commandText)
      } catch {
        skip(text, "\(error)")
        continue
      }
      if command.isQuery {
        skip(text, "`\(command.text)` is a query, and a shortcut has nowhere to show its answer")
        continue
      }
      if chord.interferesWithTyping {
        skip(text, "needs ctrl, opt or cmd so the key can still be typed (only f1–f12 can do without)")
        continue
      }
      remaining.removeAll { isReplaced($0.chord, by: chord) }
      added.append(KeyBinding(chord, command))
      seen[chord] = text
    }
    // Two shortcuts can mean one key: `us:z` and `z`, or, after falling back to its US position, a sign the
    // layout cannot type and the sign that is printed there (`/` and `-` on a German keyboard).
    var resolved: [KeyBinding] = []
    var pressed: [PressedKey: KeyBinding] = [:]
    for binding in (added + remaining).map({ KeyBinding($0.chord, $0.command, layout: layout) }) {
      let place = PressedKey(code: binding.keyCode, modifiers: binding.modifiers)
      if let earlier = pressed[place] {
        skip(
          binding.chord.text,
          "the same key as \(earlier.chord.text) on the \(layout.name) keyboard layout (\(earlier.label)), which is used instead")
        continue
      }
      pressed[place] = binding
      resolved.append(binding)
    }
    return (resolved, problems.sorted())
  }

  /// What the keyboard sends: a key by its code, and the modifiers held.
  private struct PressedKey: Hashable {
    var code: UInt32
    var modifiers: KeyChord.Modifiers
  }

  /// `problems` as the log may hold them: which shortcut, never why. A person reads them whole in `bindings`; but the reasons quote the
  /// file, and whatever stands there was typed by somebody: part of a window title, a name, or a slip that put any word where a command
  /// or a key was wanted. So each line is made of Arbor's own words: the keys as Arbor writes them, if it can read them, and the
  /// command's first word, if it is one of Arbor's.
  public static func problemsForTheLog(_ problems: [String], settings: Settings, layout: KeyLayout = .us) -> [String] {
    let entries = settings.bindings.map { ($0.key, $0.value) } + settings.unreadableBindings.map { ($0, nil) }
    return problems.map { problem in
      // The longest, so that `a: b` is not taken for `a`.
      let entry = entries.filter { problem.hasPrefix("\($0.0): ") }.max { $0.0.count < $1.0.count }
      // Without an entry it is one of Arbor's own making, about two entries that mean one key: `ctrl+opt+us:z: the same key as …`.
      let keys = entry?.0 ?? problem.firstRange(of: ": ").map { String(problem[..<$0.lowerBound]) } ?? ""
      let shortcut = (try? KeyChord(text: keys, layout: layout))?.text ?? "keys that cannot be read"
      let verb = (entry?.1 ?? nil)?.drop { $0 == "/" || $0.isWhitespace }.prefix { $0 != "/" && !$0.isWhitespace }.lowercased()
      let command = verb.map { Command.isVerb($0) ? ", for `\($0)`" : ", for what is no command" } ?? ""
      return "\(shortcut)\(command); `bindings` says why"
    }
  }

  /// The menu label of the first binding for `command` among `bindings`, e.g. ⌃⌥Space. Which are the ones in effect, for whatever a person reads.
  public static func label(for command: Command, in bindings: [KeyBinding]) -> String? {
    bindings.first { $0.command == command }?.label
  }
}
