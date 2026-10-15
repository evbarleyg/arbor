/// What the keys of a keyboard layout type, and so which key a shortcut's letter means
/// (docs/features/F44-shortcuts-follow-the-keyboard-layout.md).
///
/// A virtual key code names a position: 6 is the key left of X, which types Z on a US keyboard, Y on a
/// German one and `;` on Dvorak. Every ⌘-shortcut on the Mac follows the layout, so people expect ⌃⌥Z on
/// the key labelled Z. The rules:
///
/// 1. A letter, digit or sign means **the key that types it** without modifiers.
/// 2. One that the layout cannot type that way (`[` is ⌥5 on a German keyboard, `1` is ⇧& on a French one)
///    falls back to **its position on a US keyboard**, and is shown as what is printed on that key:
///    ⌃⌥Ü. If the key types the character with ⇧, the character is printed on it too and is what is shown: ⌃⌥1.
/// 3. Space, ↩, ⇥, ⎋, ⌫, the arrows and the F-keys are positions on every layout.
/// 4. `us:z` in a shortcut's text asks for the US position outright.
/// 5. A sign with ⇧ means what ⇧ makes of it on a US keyboard: ⌃⌥⇧/ is written ⌃⌥? and pressed as it is typed. If the layout
///    types that character with ⇧, that is the key (⇧ß in Germany, where ⇧7, which types /, saves view 7). Digits
///    are left out: ⌃⌥⇧2 is "save view 2", not ⌃⌥@.
/// 6. Any other single character the layout types alone can name its key as well: `ctrl+opt+ü`.
///
/// The app builds one of these from the layout macOS has selected (`Input/KeyboardLayout.swift`); everything
/// that is decided is decided here.
public struct KeyLayout: Equatable, Sendable {
  /// What people call the layout ("German"), for replies and the log.
  public let name: String
  /// Key code to the character the key types, in lower case: alone, and with ⇧.
  let plain: [UInt32: Character]
  let shifted: [UInt32: Character]
  /// The key that types each character alone, and with ⇧.
  private let codes: [Character: UInt32]
  private let shiftedCodes: [Character: UInt32]

  /// What ⇧ makes of each sign on a US keyboard.
  static let shiftedSigns: [Character: Character] = [
    "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?", "`": "~",
  ]

  /// - Parameters:
  ///   - plain: what each key code types with no modifier held. Keys that type nothing visible, more than
  ///     one character, or that sit on the numeric keypad are left out, so the whole range of key
  ///     codes can be passed in as it comes from macOS.
  ///   - shifted: the same with ⇧ held.
  public init(name: String, plain: [UInt32: String], shifted: [UInt32: String] = [:]) {
    self.name = name
    self.plain = Self.cleaned(plain)
    self.shifted = Self.cleaned(shifted)
    var codes: [Character: UInt32] = [:]
    // Lowest key code first, so that the answer does not depend on the order of a dictionary.
    for (code, character) in self.plain.sorted(by: { $0.key < $1.key }) where codes[character] == nil {
      codes[character] = code
    }
    // Where two keys type the same character, the one that does so on a US keyboard stays put.
    for key in KeyChord.Key.allCases {
      if let character = key.character, self.plain[key.code] == character { codes[character] = key.code }
    }
    self.codes = codes
    var shiftedCodes: [Character: UInt32] = [:]
    for (code, character) in self.shifted.sorted(by: { $0.key < $1.key }) where shiftedCodes[character] == nil {
      shiftedCodes[character] = code
    }
    for key in KeyChord.Key.allCases {
      if let sign = key.character, let meant = Self.shiftedSigns[sign], self.shifted[key.code] == meant {
        shiftedCodes[meant] = key.code
      }
    }
    self.shiftedCodes = shiftedCodes
  }

  /// The numeric keypad types digits and signs too, and nobody means it by "⌃⌥1".
  private static let keypad: Set<UInt32> = [65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 95]

  private static func cleaned(_ table: [UInt32: String]) -> [UInt32: Character] {
    var result: [UInt32: Character] = [:]
    for (code, text) in table where !keypad.contains(code) {
      let lowered = text.lowercased()
      guard lowered.count == 1, let character = lowered.first, isVisible(character) else { continue }
      result[code] = character
    }
    return result
  }

  private static func isVisible(_ character: Character) -> Bool {
    character.unicodeScalars.allSatisfy { scalar in
      switch scalar.properties.generalCategory {
      case .control, .format, .spaceSeparator, .lineSeparator, .paragraphSeparator, .privateUse, .unassigned, .surrogate:
        false
      default: true
      }
    }
  }

  /// The layout `KeyChord.Key`'s names and key codes come from.
  public static let us = KeyLayout(
    name: "US",
    plain: Dictionary(
      uniqueKeysWithValues: KeyChord.Key.allCases.compactMap { key in key.character.map { (key.code, String($0)) } }))

  // MARK: Answers

  /// The key code to register for `key`. `positional` asks for the US position whatever the layout; `withShift`
  /// says that the shortcut holds ⇧.
  public func code(for key: KeyChord.Key, positional: Bool = false, withShift: Bool = false) -> UInt32 {
    guard !positional, let character = key.character else { return key.code }
    if withShift, let meant = Self.shiftedSigns[character], let code = shiftedCodes[meant] { return code }
    return codes[character] ?? key.code
  }

  /// How menus show that key: what is printed on it.
  public func label(for key: KeyChord.Key, positional: Bool = false, withShift: Bool = false) -> String {
    guard let character = key.character else { return key.label }
    let code = code(for: key, positional: positional, withShift: withShift)
    if plain[code] == character { return key.label }
    // Printed on it as well, above what the key types alone. Only where the key was not chosen for what ⇧ makes of it.
    if code == key.code, shifted[code] == character { return key.label }
    guard let printed = plain[code] else { return key.label }
    // ß has no capital that is one letter; it is printed as it is.
    let capital = String(printed).uppercased()
    return capital.count == 1 ? capital : String(printed)
  }

  /// The key that types `character` alone, if one does.
  public func code(typing character: Character) -> UInt32? {
    String(character).lowercased().first.flatMap { codes[$0] }
  }

  /// What the key with this code types, in lower case, alone or with ⇧; nil if nothing visible.
  public func character(at code: UInt32, shifted withShift: Bool = false) -> Character? {
    (withShift ? shifted : plain)[code]
  }

  /// Whether `key` had to fall back to its US position because this layout does not type it alone.
  public func fallsBack(_ key: KeyChord.Key) -> Bool {
    guard let character = key.character else { return false }
    return codes[character] == nil
  }
}

extension KeyChord.Key {
  /// The character a letter, digit or sign key is named after; nil for keys that are positions on every
  /// layout (`space`, `left`, `f5`…), whose names are words.
  public var character: Character? { rawValue.count == 1 ? rawValue.first : nil }
}

extension KeyChord {
  /// The virtual key code to register on this layout.
  public func code(in layout: KeyLayout) -> UInt32 {
    layout.code(for: key, positional: isPositional, withShift: modifiers.contains(.shift))
  }

  /// How menus show the shortcut on this layout: ⌃⌥Z, ⌃⌥Ü.
  public func label(in layout: KeyLayout) -> String {
    Modifiers.order.filter { modifiers.contains($0.modifier) }.map(\.glyph).joined()
      + layout.label(for: key, positional: isPositional, withShift: modifiers.contains(.shift))
  }

  /// Like `init(text:)`, and the key can also be named by any single character the layout types alone: `ctrl+opt+ü`, or
  /// `⌃⌥Ü` as a menu shows it. That is the key where it is printed, so the result is a position (`us:[` on a German
  /// keyboard), and on a layout that does not type the character the text cannot be read. So `label(in:)` typed
  /// back on its own layout means the same key.
  public init(text: String, layout: KeyLayout) throws {
    do {
      try self.init(text: text)
    } catch let error as ParseError {
      guard let (modifiers, character) = Self.modifiersAndOneCharacter(in: text), let code = layout.code(typing: character)
      else { throw error }
      guard let key = Key.allCases.first(where: { $0.code == code && $0.character != nil }) else {
        throw ParseError("`\(character)` is on a key that only some keyboards have, which Arbor cannot bind")
      }
      self.init(modifiers, key, positional: true)
    }
  }

  /// Modifiers and one single character besides, in lower case, if that is all the text holds: `Opt + Ctrl + Ö`, `⌃⌥Ü`,
  /// `ctrl+opt++`. Whether the character names a key depends on the layout.
  public static func modifiersAndOneCharacter(in text: String) -> (modifiers: Modifiers, character: Character)? {
    var modifiers: Modifiers = []
    var strangers: [Substring] = []
    var compact = text.filter { !$0.isWhitespace }.lowercased()
    // A German keyboard has a key for +, which also joins the parts: ⌃⌥+, ctrl+opt++.
    if compact.hasSuffix("+") {
      compact.removeLast()
      if compact.hasSuffix("+") { compact.removeLast() }
      strangers.append("+")
    }
    for part in compact.split(separator: "+", omittingEmptySubsequences: false) {
      // Glyphs may be run together and onto the key, as in `init(text:)`.
      var rest = part
      while let modifier = rest.first.flatMap({ Self.modifierNames[String($0)] }) {
        modifiers.insert(modifier)
        rest.removeFirst()
      }
      if rest.isEmpty, !part.isEmpty { continue }
      if let modifier = Self.modifierNames[String(rest)] { modifiers.insert(modifier) } else { strangers.append(rest) }
    }
    guard strangers.count == 1, strangers[0].count == 1, let character = strangers[0].first else { return nil }
    return (modifiers, character)
  }

  /// How such a shortcut is written, tidied: `ctrl+opt+ö`.
  public static func text(_ modifiers: Modifiers, typing character: Character) -> String {
    String(KeyChord(modifiers, .a).text.dropLast()) + String(character)
  }
}
