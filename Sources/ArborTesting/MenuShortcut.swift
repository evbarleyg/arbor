import ArborCore

/// A shortcut in an app's menu bar, as Accessibility tells it (collab/IDEAS.md, I16 and I25 d). For the census of menu bars and for nothing else: it
/// is here, among what only tests use, because **Arbor itself reads no other app's menu bar** (docs/KEYBOARD.md).
///
/// A global shortcut is taken from every app, so an app that has the same keys in a menu loses them while Arbor holds them, and gets them
/// back, with whatever it does on them, the moment Arbor does not: paused, quit, crashed. The fingers do not know the difference. So the
/// menu bars of the apps on hosted Macs are read, and Arbor's keys are held against them in every `make check` (`MenuKeyCensusTests`).
///
/// What the attributes hold, from 82 real menu bars (macOS 26, 2026-10-15; collab/evidence/menu-keys):
/// - `AXMenuItemCmdChar`: a letter in CAPITALS, whatever ⇧ says. What ⇧ makes of a key comes either way: as the sign that is typed, and then never
///   with ⇧ among the modifiers (⌃⌥: is `:`; 161 rows), or as the key's plain character with ⇧ (⇧⌘= beside another app's ⌘+; 72 rows,
///   nearly all the digits among them). For the keys below: a control character, the key's own symbol or one from the private-use area, which
///   is passed over here.
/// - `AXMenuItemCmdVirtualKey`: the key code, for arrows, ↩, Space, ⎋, ⇥, ⌫, Page Up and the like, and the F-keys. Never for a letter, digit or sign.
/// - `AXMenuItemCmdModifiers`: 1 is ⇧, 2 is ⌥, 4 is ⌃, 8 is **no** ⌘, and 16, which no header mentions, is fn (the Globe key): macOS's own
///   Window → Move & Resize is full of it.
///
/// Two numbers and one character. **Never an item's title**: it can hold a person's words (a document, a conversation, a bookmark).
public struct MenuShortcut: Hashable, Sendable {
  public var modifiers: Int
  public var character: String?
  public var virtualKey: Int?

  public init(modifiers: Int, character: String? = nil, virtualKey: Int? = nil) {
    self.modifiers = modifiers
    self.character = character
    self.virtualKey = virtualKey
  }

  /// A menu item that is pressed as `chord`, on a US keyboard: a letter in capitals, a key that types nothing by its code, ⇧ among the modifiers.
  public init(showing chord: KeyChord) {
    var modifiers = 0
    if chord.modifiers.contains(.shift) { modifiers |= 1 }
    if chord.modifiers.contains(.option) { modifiers |= 2 }
    if chord.modifiers.contains(.control) { modifiers |= 4 }
    if !chord.modifiers.contains(.command) { modifiers |= 8 }
    if let character = chord.key.character {
      self.init(modifiers: modifiers, character: String(character).uppercased())
    } else {
      self.init(modifiers: modifiers, virtualKey: Int(chord.key.code))
    }
  }

  /// A key and the modifiers held with it: what a hot key is registered for, and what is compared.
  public struct Press: Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: KeyChord.Modifiers

    public init(keyCode: UInt32, modifiers: KeyChord.Modifiers) {
      self.keyCode = keyCode
      self.modifiers = modifiers
    }
  }

  /// Whether the Globe key has to be held as well. Then it is another press than the same keys without.
  public var needsFn: Bool { modifiers & 16 != 0 }

  /// What has to be pressed for it on `layout`, fn aside. Nil if that cannot be told: bits nobody has seen, or a character the layout does not type.
  public func press(on layout: KeyLayout) -> Press? {
    guard 0...31 ~= modifiers else { return nil }
    var held: KeyChord.Modifiers = []
    if modifiers & 1 != 0 { held.insert(.shift) }
    if modifiers & 2 != 0 { held.insert(.option) }
    if modifiers & 4 != 0 { held.insert(.control) }
    if modifiers & 8 == 0 { held.insert(.command) }
    if let virtualKey { return UInt32(exactly: virtualKey).map { Press(keyCode: $0, modifiers: held) } }
    guard let character, character.count == 1, let typed = character.lowercased().first else { return nil }
    if let code = layout.code(typing: typed) { return Press(keyCode: code, modifiers: held) }
    // ⌃⌥: is pressed as ⌃⌥⇧; where ⇧; types the colon.
    return (0..<128).first { layout.character(at: $0, shifted: true) == typed }.map { Press(keyCode: $0, modifiers: held.union(.shift)) }
  }
}

/// The shortcuts that were read in one app's menu bar.
public struct MenuBarReading: Equatable, Sendable {
  /// Its bundle id.
  public var app: String
  public var shortcuts: [MenuShortcut]

  public init(app: String, shortcuts: [MenuShortcut]) {
    self.app = app
    self.shortcuts = shortcuts
  }

  /// Everything in it that is pressed without the Globe key (or, asked so, only with it), on `layout`.
  public func presses(on layout: KeyLayout, withFn: Bool = false) -> Set<MenuShortcut.Press> {
    Set(shortcuts.filter { $0.needsFn == withFn }.compactMap { $0.press(on: layout) })
  }
}
