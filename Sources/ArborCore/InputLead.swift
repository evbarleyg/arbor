/// Keys follow the keyboard, gestures follow the pointer (docs/features/F56-keys-follow-the-keyboard.md).
///
/// A camera command names no display and `in` names no window, so something has to choose for them.
/// A pinch means what is under the pointer. A shortcut means what its user is looking at, which is
/// where they are typing, unless they have just pointed at something else. Everything here is pure:
/// the controller feeds it where the command came from and what macOS says the hands did last.

/// Where a command came from.
public enum CommandSource: String, Sendable, CaseIterable {
  /// A global keyboard shortcut.
  case shortcut
  /// Arbor's menu bar item, or one of its own windows.
  case menu
  /// A pinch, or anything else done with the pointer.
  case gesture
  /// `arborctl`, or anything else on the control socket.
  case script
  /// An `arbor://` URL.
  case url
}

/// The values of the `stepInToward` setting.
public enum StepInToward: String, Sendable, CaseIterable {
  /// Whichever of the two the user touched last.
  case auto
  /// Always the pointer, as the TrellisWM site describes.
  case pointer
  /// Always the focused window, as TrellisWM's `stepTowardPointer: false` does.
  case focus

  /// A value nobody defined (a typo in settings.json) means the default.
  public init(setting: String) { self = StepInToward(rawValue: setting.lowercased()) ?? .auto }
}

/// What the user's hands did last, as macOS reports it to any app that asks.
public struct InputActivity: Equatable, Sendable {
  /// Seconds since the pointer last moved, clicked, dragged or scrolled.
  public var pointerIdle: Double
  /// Seconds since a key was last **released**. While a shortcut's command runs its own key is still
  /// down, so this is the key before it: the last thing typed.
  public var keyboardIdle: Double
  /// A running count of key presses. Only differences mean anything, and it may wrap round.
  public var keyPresses: UInt32

  public init(pointerIdle: Double, keyboardIdle: Double, keyPresses: UInt32) {
    self.pointerIdle = pointerIdle
    self.keyboardIdle = keyboardIdle
    self.keyPresses = keyPresses
  }
}

/// Decides, command by command, whether the pointer or the keyboard says where a command acts.
public struct InputLead: Equatable, Sendable {
  public enum Lead: String, Sendable {
    /// The display under the pointer; `in` steps toward the pointer.
    case pointer
    /// The focused window's display; `in` steps toward the focused window.
    case keyboard
  }

  /// What the last command followed.
  public private(set) var last: Lead = .keyboard
  private var keyPressesAtLastCommand: UInt32?
  private var focusChangedSinceLastCommand = false

  public init() {}

  /// The keyboard focus went to another window, whoever moved it.
  public mutating func focusChanged() { focusChangedSinceLastCommand = true }

  /// What a command from `source` follows. `focusIdle` is the time in seconds since the focus last changed.
  ///
  /// Asking again before anything else happens gives the same answer.
  public mutating func lead(
    for source: CommandSource, rule: StepInToward, activity: InputActivity, focusIdle: Double
  ) -> Lead {
    // The press that ran this command is one; more than that is typing.
    let typed = keyPressesAtLastCommand.map { activity.keyPresses &- $0 > 1 } ?? true
    let undisturbed = !typed && !focusChangedSinceLastCommand
    keyPressesAtLastCommand = activity.keyPresses
    focusChangedSinceLastCommand = false
    last = Self.lead(
      for: source, rule: rule, activity: activity, focusIdle: focusIdle, previous: undisturbed ? last : nil)
    return last
  }

  /// What a command from `source` would follow now, for whoever only asks (a menu that names the display its items act
  /// on, a caption). Nothing is remembered, so the next command follows what it would have followed unasked.
  public func answer(
    for source: CommandSource, rule: StepInToward, activity: InputActivity, focusIdle: Double
  ) -> Lead {
    var copy = self
    return copy.lead(for: source, rule: rule, activity: activity, focusIdle: focusIdle)
  }

  /// Whether `in` steps toward the focused window rather than the pointer. The pointer that chose a
  /// menu item says which display is meant, but it is resting on the menu, not on a window.
  public static func stepsTowardFocus(lead: Lead, source: CommandSource, rule: StepInToward) -> Bool {
    lead == .keyboard || (source == .menu && rule != .pointer)
  }

  /// `previous` is what the last command followed, if the user has done nothing but run commands since.
  private static func lead(
    for source: CommandSource, rule: StepInToward, activity: InputActivity, focusIdle: Double, previous: Lead?
  ) -> Lead {
    switch source {
    case .gesture, .menu:
      // A menu item is chosen with the pointer, on the display whose menu bar was clicked.
      return .pointer
    case .shortcut, .script, .url:
      break
    }
    switch rule {
    case .pointer: return .pointer
    case .focus: return .keyboard
    case .auto: break
    }
    // Someone who points at a window and then presses ⌃⌥↓ means that window.
    if activity.pointerIdle <= min(activity.keyboardIdle, focusIdle) { return .pointer }
    // ⌃⌥↓ ⌃⌥↓ goes on where the first one went: the first one's own key must not count as typing.
    return previous ?? .keyboard
  }
}
