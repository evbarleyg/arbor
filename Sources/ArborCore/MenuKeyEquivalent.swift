extension KeyChord.Key {
  /// The text AppKit's menus take as this key's `keyEquivalent`, so that a menu item can show a
  /// shortcut where macOS shows them: right-aligned, in the system's own glyphs. Keys that type no
  /// character use AppKit's function-key code points (`NSUpArrowFunctionKey`, `NSF1FunctionKey`…).
  public var menuKeyEquivalent: String {
    switch self {
    case .space: return " "
    case .returnKey: return "\r"
    case .tab: return "\t"
    case .escape: return "\u{1B}"
    case .delete: return "\u{08}"
    case .up: return "\u{F700}"
    case .down: return "\u{F701}"
    case .left: return "\u{F702}"
    case .right: return "\u{F703}"
    default:
      // f1 is U+F704, and the rest follow in order.
      if isFunctionKey, let number = UInt32(rawValue.dropFirst()), let scalar = Unicode.Scalar(0xF703 + number) {
        return String(Character(scalar))
      }
      // Lowercase: AppKit reads a capital letter as the letter with ⇧.
      return rawValue
    }
  }
}
