/// A keyboard shortcut: modifier keys plus one key. In settings.json it is text, the names joined
/// by `+`: `ctrl+opt+space`, `ctrl+opt+cmd+h`, `cmd+shift+f5`.
///
/// A letter, digit or sign means the key that types it on the keyboard layout in use, as in every
/// ⌘-shortcut; which key that is, is `KeyLayout`'s business. `ctrl+opt+us:z` means the key where a US
/// keyboard has its Z, on any layout.
public struct KeyChord: Hashable, Sendable, CustomStringConvertible {
  public var modifiers: Modifiers
  public var key: Key
  /// Written `us:`: the key's position on a US keyboard is meant, not the character. Never set for keys
  /// that are positions anyway, so that `us:space` and `space` are one shortcut.
  public let isPositional: Bool

  public init(_ modifiers: Modifiers, _ key: Key, positional: Bool = false) {
    self.modifiers = modifiers
    self.key = key
    isPositional = positional && key.character != nil
  }

  /// What comes before a key's name to mean its position on a US keyboard.
  static let positionPrefix = "us:"

  public struct Modifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let shift = Modifiers(rawValue: 1 << 1)
    public static let option = Modifiers(rawValue: 1 << 2)
    public static let control = Modifiers(rawValue: 1 << 3)

    /// Each modifier's name and menu glyph, in the order macOS menus show them (⌃⌥⇧⌘).
    static let order: [(modifier: Modifiers, name: String, glyph: String)] = [
      (.control, "ctrl", "⌃"), (.option, "opt", "⌥"), (.shift, "shift", "⇧"), (.command, "cmd", "⌘"),
    ]
  }

  /// Every spelling of a modifier that `init(text:)` accepts, lowercased.
  static let modifierNames: [String: Modifiers] = [
    "ctrl": .control, "control": .control, "⌃": .control,
    "opt": .option, "option": .option, "alt": .option, "⌥": .option,
    "cmd": .command, "command": .command, "⌘": .command,
    "shift": .shift, "⇧": .shift,
  ]

  // MARK: Text form

  public struct ParseError: Error, CustomStringConvertible, Equatable {
    public let description: String
    init(_ description: String) { self.description = description }
  }

  /// Parses the text form. Case, spaces and the order of the parts do not matter, and modifiers have
  /// aliases (`control`, `option`, `alt`, `command`, `⌃`, `⌥`, `⌘`, `⇧`), so `Opt + Ctrl + Space`
  /// is `ctrl+opt+space`. Glyphs may be run together and onto the key, so what a menu shows, `⌃⌥Space` or
  /// `⌃⌥⌘←`, can be pasted into settings.json: `label` is read back. A label shows what the key types and not
  /// that a position was meant, so `us:z` comes back as `z`.
  public init(text: String) throws {
    // No key or modifier name contains a space ("space" is spelled out), so dropping them all is safe.
    let compact = text.filter { !$0.isWhitespace }.lowercased()
    guard !compact.isEmpty else { throw ParseError("empty shortcut; write one like ctrl+opt+space") }
    let parts = compact.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
    var modifiers: Modifiers = []
    var found: Key?
    var positional = false
    for (index, written) in parts.enumerated() {
      let isLast = index == parts.count - 1
      if written.isEmpty {
        throw ParseError(isLast ? "missing key after the last +" : "missing modifier before a +")
      }
      var rest = Substring(written)
      while let modifier = rest.first.flatMap({ Self.modifierNames[String($0)] }) {
        modifiers.insert(modifier)
        rest.removeFirst()
      }
      if rest.isEmpty { continue }
      let part = String(rest)
      let byPosition = part.hasPrefix(Self.positionPrefix)
      if let modifier = Self.modifierNames[part] {
        modifiers.insert(modifier)
      } else if let key = Key(name: byPosition ? String(part.dropFirst(Self.positionPrefix.count)) : part) {
        if let found { throw ParseError("two keys, \(found.name) and \(key.name); a shortcut has one") }
        found = key
        positional = byPosition
      } else if isLast && found == nil {
        throw ParseError("unknown key `\(part)`; \(Key.namesHint)")
      } else {
        throw ParseError("unknown modifier `\(part)`; use ctrl, opt, cmd or shift")
      }
    }
    guard let found else { throw ParseError("no key, only modifiers; end with a key, as in ctrl+opt+space") }
    self.init(modifiers, found, positional: positional)
  }

  /// The canonical text form: modifiers in menu order (ctrl, opt, shift, cmd), then the key.
  /// `init(text:)` round-trips it.
  public var text: String {
    let names = Modifiers.order.filter { modifiers.contains($0.modifier) }.map(\.name)
    return (names + [(isPositional ? Self.positionPrefix : "") + key.name]).joined(separator: "+")
  }

  /// How macOS menus show the shortcut on a US keyboard: ⌃⌥Space, ⌃⌥⌘←, ⌃⌥⇧1. See `label(in:)`.
  public var label: String { label(in: .us) }

  public var description: String { text }

  /// Whether a global shortcut on this chord would take the key away from typing in every app.
  /// Arbor requires ctrl, opt or cmd, except for f1–f12.
  public var interferesWithTyping: Bool {
    modifiers.isDisjoint(with: [.control, .option, .command]) && !key.isFunctionKey
  }

  /// What someone should hear before making this a global shortcut, which takes the keys away from every
  /// app; nil for most. One line for each row of "Never bind by default" in docs/KEYBOARD.md that names a hazard (⌃⌥H/J/K/L
  /// as arrows is a matter of economy, and a recipe in the README). Nothing is refused: the keys are the user's.
  public var caution: String? {
    // ⌃⌥ together is what apps leave alone and Arbor builds on.
    guard modifiers.isSuperset(of: [.control, .option]) else { return "no app gets \(label) while Arbor runs" }
    let isLetter = key.character?.isLetter == true
    switch modifiers {
    case [.control, .option, .shift, .command]:
      return "⌃⌥⇧⌘ is the “hyper key” many people build for shortcuts of their own"
    case [.control, .option, .command] where [.digit8, .comma, .period].contains(key):
      return "macOS uses \(label) itself, for Accessibility (invert colours, contrast)"
    case [.control, .option, .command] where isLetter || key == .returnKey:
      return "Xcode uses ⌃⌥⌘ with letters and ↩ (fix all issues, test again, the assistant editor)"
    case [.control, .option]:
      switch key {
      case .q, .w: return "\(label) is one slipped finger from ⌘\(key.label)"
      case .delete: return "\(label) reads as “delete”"
      case .h: return "Figma (distribute spacing) and JetBrains IDEs (call hierarchy) use \(label)"
      case .v: return "Figma uses \(label) (distribute spacing)"
      case .o, .i, .l: return "JetBrains IDEs use \(label) (optimise imports, auto-indent)"
      default: return nil
      }
    default:
      return nil
    }
  }
}

extension KeyChord {
  /// The keys a shortcut can use. The raw value is the key's name in settings.json.
  public enum Key: String, CaseIterable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case digit0 = "0", digit1 = "1", digit2 = "2", digit3 = "3", digit4 = "4"
    case digit5 = "5", digit6 = "6", digit7 = "7", digit8 = "8", digit9 = "9"
    case space, returnKey = "return", tab, escape, delete
    case left, right, up, down
    case leftBracket = "[", rightBracket = "]", minus = "-", equals = "=", comma = ",", period = "."
    case slash = "/", semicolon = ";", quote = "'", grave = "`", backslash = "\\"
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    /// Finds a key by its name, ignoring case. `enter` is another name for `return`, `esc` for `escape`,
    /// and `slash` for `/`, which cannot be written inside a URL path
    /// (`arbor://bind/ctrl+opt+slash/desktop`); the glyphs menus show (`label`) are names too.
    public init?(name: String) {
      let lowered = name.lowercased()
      if lowered == "enter" {
        self = .returnKey
      } else if lowered == "esc" {
        self = .escape
      } else if lowered == "slash" {
        self = .slash
      } else if let key = Self.glyphs[lowered] {
        self = key
      } else {
        self.init(rawValue: lowered)
      }
    }

    /// The keys menus show as a glyph (`label`), by that glyph.
    private static let glyphs: [String: Key] = [
      "↩": .returnKey, "⇥": .tab, "⎋": .escape, "⌫": .delete, "←": .left, "→": .right, "↑": .up, "↓": .down,
    ]

    public var name: String { rawValue }

    static let namesHint =
      "keys are a–z, 0–9, f1–f12, space, return, tab, escape, delete, left, right, up, down and "
      + #"[ ] - = , . / ; ' ` \ (us:z is the key where a US keyboard has z)"#

    /// How menus show the key.
    public var label: String {
      switch self {
      case .space: "Space"
      case .returnKey: "↩"
      case .tab: "⇥"
      case .escape: "⎋"
      case .delete: "⌫"
      case .left: "←"
      case .right: "→"
      case .up: "↑"
      case .down: "↓"
      default: rawValue.uppercased()
      }
    }

    public var isFunctionKey: Bool {
      switch self {
      case .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12: true
      default: false
      }
    }

    /// The virtual key code of the key's position on a US keyboard (Carbon's `kVK_*` constants). Letters
    /// and digits are numbered by position, not alphabetically. `KeyLayout.code(for:)` gives the key
    /// to register on the layout in use.
    public var code: UInt32 {
      switch self {
      case .a: 0
      case .b: 11
      case .c: 8
      case .d: 2
      case .e: 14
      case .f: 3
      case .g: 5
      case .h: 4
      case .i: 34
      case .j: 38
      case .k: 40
      case .l: 37
      case .m: 46
      case .n: 45
      case .o: 31
      case .p: 35
      case .q: 12
      case .r: 15
      case .s: 1
      case .t: 17
      case .u: 32
      case .v: 9
      case .w: 13
      case .x: 7
      case .y: 16
      case .z: 6
      case .digit0: 29
      case .digit1: 18
      case .digit2: 19
      case .digit3: 20
      case .digit4: 21
      case .digit5: 23
      case .digit6: 22
      case .digit7: 26
      case .digit8: 28
      case .digit9: 25
      case .space: 49
      case .returnKey: 36
      case .tab: 48
      case .escape: 53
      case .delete: 51
      case .left: 123
      case .right: 124
      case .down: 125
      case .up: 126
      case .leftBracket: 33
      case .rightBracket: 30
      case .minus: 27
      case .equals: 24
      case .comma: 43
      case .period: 47
      case .slash: 44
      case .semicolon: 41
      case .quote: 39
      case .grave: 50
      case .backslash: 42
      case .f1: 122
      case .f2: 120
      case .f3: 99
      case .f4: 118
      case .f5: 96
      case .f6: 97
      case .f7: 98
      case .f8: 100
      case .f9: 101
      case .f10: 109
      case .f11: 103
      case .f12: 111
      }
    }
  }
}

// MARK: settings.json

/// The `bindings` object of settings.json, read one entry at a time so that a value of the wrong
/// type (a number, `false`) is set aside to be reported instead of making the whole file invalid.
struct BindingsObject: Decodable {
  var entries: [String: String?] = [:]
  /// Chords whose value is neither command text nor null.
  var unreadable: [String] = []

  init() {}

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: StringKey.self)
    for key in container.allKeys {
      if try container.decodeNil(forKey: key) {
        entries.updateValue(nil, forKey: key.stringValue)  // the entry stays: null removes a default
      } else if let command = try? container.decode(String.self, forKey: key) {
        entries[key.stringValue] = command
      } else {
        unreadable.append(key.stringValue)
      }
    }
    unreadable.sort()
  }
}
