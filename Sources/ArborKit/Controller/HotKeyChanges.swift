import ArborCore

/// How to get from the shortcuts macOS holds for Arbor to the ones wanted now, without letting go of one that stays.
///
/// Registering anew used to mean all off and then all on: two to three milliseconds, at every pause, every change of the
/// settings or of the keyboard layout, in which every key of Arbor's was the key of the app in front, and after which a
/// key that was down never came up. To macOS a shortcut is a key and its modifiers. What Arbor does when it is pressed is
/// Arbor's own business, so a key that only gets another command, or another name, stays registered.
public struct HotKeyChanges: Equatable, Sendable {
  /// Held and no longer wanted.
  public private(set) var dropped: [KeyBinding] = []
  /// Held and wanted, as they are wanted now.
  public private(set) var kept: [KeyBinding] = []
  /// Wanted and not held: the new ones, and with them whatever macOS refused the last time, which is so tried again.
  public private(set) var added: [KeyBinding] = []

  public init(from held: [KeyBinding], to wanted: [KeyBinding]) {
    let heldKeys = Set(held.map(HotKey.init))
    var taken: Set<HotKey> = []
    for binding in wanted {
      // Two that mean one key do not come this far (`KeyBindings.effective`). If they did, the first has the key and macOS, which
      // gives an app each key once, says no to the second every time: it must not take the key over by being "kept".
      let isFirst = taken.insert(HotKey(binding)).inserted
      if isFirst, heldKeys.contains(HotKey(binding)) { kept.append(binding) } else { added.append(binding) }
    }
    dropped = held.filter { !taken.contains(HotKey($0)) }
  }

  public var isEmpty: Bool { dropped.isEmpty && added.isEmpty }
}

/// What a shortcut is to macOS.
public struct HotKey: Hashable, Sendable {
  public let keyCode: UInt32
  public let modifiers: KeyChord.Modifiers

  public init(_ binding: KeyBinding) {
    keyCode = binding.keyCode
    modifiers = binding.modifiers
  }
}
