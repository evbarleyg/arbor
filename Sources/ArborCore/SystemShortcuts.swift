/// macOS's own keyboard shortcuts (System Settings → Keyboard → Keyboard Shortcuts), as far as they concern Arbor's.
///
/// macOS lets an app register a shortcut that it uses itself, without a word, and then one of the two does
/// nothing. Which one is not documented and need not be the same for every shortcut. (Seen on macOS 26 with two input
/// sources: ⌃⌥Space reached Arbor, and the input source stayed as it was.) Either way somebody presses a key that is
/// shown as working and nothing happens, so Arbor looks and says so (`bindings`, the log).
///
/// The app fills one in whenever it is asked (`Controller.systemShortcuts`); what it means is decided here.
public struct SystemShortcuts: Equatable, Sendable {
  public struct Shortcut: Equatable, Sendable {
    public var keyCode: UInt32
    /// Carbon's modifier bits (`cmdKey`…), as macOS reports them.
    public var carbonModifiers: UInt32
    /// Its tick in System Settings.
    public var isEnabled: Bool

    public init(keyCode: UInt32, carbonModifiers: UInt32, isEnabled: Bool = true) {
      self.keyCode = keyCode
      self.carbonModifiers = carbonModifiers
      self.isEnabled = isEnabled
    }

    /// For tests and tables: a shortcut as Arbor writes them, by the key's place on a US keyboard.
    public init(_ modifiers: KeyChord.Modifiers, _ key: KeyChord.Key, isEnabled: Bool = true) {
      var bits: UInt32 = 0
      for (bit, modifier) in Self.bits where modifiers.contains(modifier) { bits |= bit }
      self.init(keyCode: key.code, carbonModifiers: bits, isEnabled: isEnabled)
    }

    private static let bits: [(UInt32, KeyChord.Modifiers)] = [
      (1 << 8, .command), (1 << 9, .shift), (1 << 11, .option), (1 << 12, .control),
    ]
    /// `kEventKeyModifierNumLockMask` and `kEventKeyModifierFnMask`; and Cocoa's numeric pad and function flags, which is how
    /// the file behind the list keeps them ("Move left a space" is ⌃ and `1 << 23`). Nobody has yet seen which arrive.
    private static let comesWithFunctionKeys: UInt32 = 1 << 16 | 1 << 17 | 1 << 21 | 1 << 23
    private static let functionKeys = Set(
      ([.left, .right, .up, .down, .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12] as [KeyChord.Key])
        .map(\.code))

    /// Its modifiers as a shortcut of Arbor's has them. Nil if it takes something that nobody can bind in Arbor, the
    /// Globe key for one: fn Q (Quick Note) is not Q. (Arbor does take its own ⌃⌥ shortcuts with fn down as well, `KeyChord.hasFnTwin`;
    /// a shortcut of macOS's on fn ⌃ ⌥ and a letter would meet that, and this does not look for one.)
    public var modifiers: KeyChord.Modifiers? {
      var rest = carbonModifiers
      var result: KeyChord.Modifiers = []
      for (bit, modifier) in Self.bits where rest & bit != 0 {
        result.insert(modifier)
        rest &= ~bit
      }
      // Events from the arrow and function keys carry these two whoever holds what, so there the Globe key cannot be told.
      if Self.functionKeys.contains(keyCode) { rest &= ~Self.comesWithFunctionKeys }
      return rest == 0 ? result : nil
    }

    /// Whether it may take the Globe key besides what `modifiers` says: it is on a key where that cannot be told, and has the bit.
    var mayTakeTheGlobeKey: Bool {
      Self.functionKeys.contains(keyCode) && carbonModifiers & Self.comesWithFunctionKeys != 0
    }
  }

  /// All of them, ticked or not.
  public var shortcuts: [Shortcut]
  /// How many keyboards and input methods the Input menu switches between. Nil if it cannot be read.
  public var inputSources: Int?

  public init(shortcuts: [Shortcut], inputSources: Int? = nil) {
    self.shortcuts = shortcuts
    self.inputSources = inputSources
  }

  /// What macOS does with a key.
  public struct Use: Equatable, Sendable {
    /// Its label in System Settings. Nil if it is not where macOS puts one of its shortcuts by default: macOS says
    /// which keys it uses, not what for.
    public var name: String?
    /// The list under Keyboard Shortcuts that has it.
    public var list: String?

    public init(name: String?, list: String?) {
      self.name = name
      self.list = list
    }
  }

  /// What macOS does with a key that Arbor wants, or nil if it does nothing with it as things stand.
  public func use(ofKeyCode keyCode: UInt32, modifiers: KeyChord.Modifiers) -> Use? {
    let found = shortcuts.filter { $0.isEnabled && $0.keyCode == keyCode && $0.modifiers == modifiers }
    guard !found.isEmpty else { return nil }
    guard let known = Self.defaults.first(where: { $0.key.code == keyCode && $0.modifiers == modifiers }) else {
      // macOS's own tiling (macOS 15) is on the arrows with the Globe key: 🌐⌃⌥⇧← is “Left & Quarters”, ticked on every Mac, and is
      // listed just as ⌃⌥⇧← would be. Taken at its word, four of Arbor's shortcuts would be called macOS's as well, which
      // they are not. Not knowing is no reason to complain.
      return found.allSatisfy(\.mayTakeTheGlobeKey) ? nil : Use(name: nil, list: nil)
    }
    // Ticked on every Mac, and does nothing on one with a single keyboard. Not knowing is no reason to complain.
    if known.list == Self.inputSourcesList, (inputSources ?? 1) < 2 { return nil }
    return Use(name: known.name, list: known.list)
  }

  private static let inputSourcesList = "Input Sources"

  /// Where macOS puts its own shortcuts until somebody moves them, with their labels in System Settings. By the keys'
  /// places on a US keyboard; the ones on signs move with the layout, and then go without a name.
  private static let defaults: [(modifiers: KeyChord.Modifiers, key: KeyChord.Key, name: String, list: String)] = [
    ([.control], .space, "Select the previous input source", inputSourcesList),
    ([.control, .option], .space, "Select next source in Input menu", inputSourcesList),
    ([.command], .space, "Show Spotlight search", "Spotlight"),
    ([.option, .command], .space, "Show Finder search window", "Spotlight"),
    ([.control], .up, "Mission Control", "Mission Control"),
    ([.control], .down, "Application windows", "Mission Control"),
    ([.control], .left, "Move left a space", "Mission Control"),
    ([.control], .right, "Move right a space", "Mission Control"),
    ([], .f11, "Show Desktop", "Mission Control"),
    ([.option, .command], .d, "Turn Dock hiding on/off", "Launchpad & Dock"),
    ([.shift, .command], .digit3, "Save picture of screen as a file", "Screenshots"),
    ([.shift, .command], .digit4, "Save picture of selected area as a file", "Screenshots"),
    ([.shift, .command], .digit5, "Screenshot and recording options", "Screenshots"),
    ([.command], .f5, "Turn VoiceOver on or off", "Accessibility"),
    ([.option, .command], .digit8, "Turn zoom on or off", "Accessibility"),
    ([.control, .option, .command], .digit8, "Invert colors", "Accessibility"),
    ([.control, .option, .command], .period, "Increase contrast", "Accessibility"),
    ([.control, .option, .command], .comma, "Decrease contrast", "Accessibility"),
    ([.command], .grave, "Move focus to next window", "Keyboard"),
    ([.control], .f2, "Move focus to the menu bar", "Keyboard"),
    ([.control], .f3, "Move focus to the Dock", "Keyboard"),
    ([.shift, .command], .slash, "Show Help menu", "App Shortcuts"),
  ]
}

extension SystemShortcuts.Use {
  /// One sentence for `bindings`, the log and the setup check.
  /// - Parameters:
  ///   - label: the shortcut as menus show it, e.g. ⌃⌥Space.
  ///   - command: what Arbor does with it, e.g. `show-all`.
  public func sentence(label: String, command: String) -> String {
    let what = name.map { "macOS's “\($0)”" } ?? "a shortcut of macOS's"
    let place = "System Settings → Keyboard → Keyboard Shortcuts" + (list.map { " → \($0)" } ?? "")
    return "\(label) (`\(command)`) is \(what) as well, so one of the two does nothing. Change either: "
      + "\(place), or `bindings` in settings.json"
  }
}
