import ArborCore

/// Whose each shortcut of the map in effect is at this moment.
///
/// A shortcut that fingers know as Arbor's and that Arbor does not hold goes to the app in front, which may have a use of its
/// own for it: one archived a conversation. So Arbor knows of every key whether it holds it, and `bindings`, `doctor`, Check
/// Setup and the log say so. Made from four lists and nothing else: the map, what Arbor wants to hold now
/// (`Controller.shortcutsWanted`), and what the app reports of its dealings with macOS.
///
/// **What it cannot know.** On macOS 26 `RegisterEventHotKey` said yes every time, whoever else held the key. Another program
/// that registered the same key hears it too; one that registered it exclusively hears it alone, and Arbor is told nothing. So `held`
/// means that macOS said yes, not that the key is Arbor's alone.
public struct KeysHeld: Equatable, Sendable {
  public enum Fate: Equatable, Sendable {
    /// Arbor asked for it and macOS said yes. The app in front does not get it.
    case held
    /// Arbor does not ask for it now (`Controller.whyKeysAreTheApps`). The app in front gets it.
    case handedOver
    /// Arbor asked for it and macOS said no. Never seen on a Mac, so who gets the key then is not known.
    case refused
    /// Arbor wants it and macOS has not been asked, or Arbor cannot listen. The app in front gets it. Nothing should ever be.
    case missing
  }

  public struct Key: Equatable, Sendable {
    public let binding: KeyBinding
    public let fate: Fate
  }

  /// One for every shortcut of the map, in the map's order.
  public let keys: [Key]

  /// - Parameter registered: nil until the app has said, and where there is no app (tests, arbor-sim): then what is wanted counts as held.
  public init(map: [KeyBinding], wanted: [KeyBinding], registered: [KeyBinding]?, refused: [KeyBinding]) {
    keys = map.map { binding in
      let fate: Fate =
        if refused.contains(binding) {
          .refused
        } else if (registered ?? wanted).contains(binding) {
          .held
        } else if wanted.contains(binding) {
          .missing
        } else {
          .handedOver
        }
      return Key(binding: binding, fate: fate)
    }
  }

  public func all(_ fate: Fate) -> [KeyBinding] { keys.filter { $0.fate == fate }.map(\.binding) }

  /// The ones that Arbor does not hear though nobody asked for that.
  public var lost: [KeyBinding] { keys.filter { $0.fate == .refused || $0.fate == .missing }.map(\.binding) }

  /// What there is to say beyond "all of them", or nil: "51 of the map's 52 are the apps' while Arbor is paused; macOS refused
  /// ⌃⌥A". Labels of keys and `why`, which the caller words for whoever reads it.
  public func news(why: String?) -> String? {
    var parts: [String] = []
    let handedOver = all(.handedOver).count
    if handedOver > 0 { parts.append("\(handedOver) of the map's \(keys.count) are the apps'" + (why.map { " " + $0 } ?? "")) }
    let refused = all(.refused)
    if !refused.isEmpty { parts.append("macOS refused \(refused.map(\.label).joined(separator: " "))") }
    let missing = all(.missing)
    // Not one by one if there are many: then it is likely to be all of them.
    if !missing.isEmpty {
      parts.append(
        (missing.count > 3 ? "\(missing.count)" : missing.map(\.label).joined(separator: " "))
          + " wanted and not registered")
    }
    return parts.isEmpty ? nil : parts.joined(separator: "; ")
  }
}
