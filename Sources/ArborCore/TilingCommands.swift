// The arguments of the keyboard tiling commands (docs/features/F22-keyboard-tiling-tools.md), with their
// text forms. `Command.parse` and `Command.text` build on them.

/// Where `focus` sends keyboard focus.
public enum FocusTarget: Equatable, Sendable, Codable {
  /// The nearest window that way.
  case direction(Edge)
  /// The next or previous window in view, wrapping around.
  case next
  case previous
  case window(WindowID)

  /// Parses `left`, `up`, `next`, `previous` (or `prev`), `412` or `w412`.
  public init?(word: String) {
    switch word.lowercased() {
    case "next": self = .next
    case "previous", "prev": self = .previous
    default:
      if let edge = Edge(word: word) {
        self = .direction(edge)
      } else if let window = WindowID(word: word.lowercased()) {
        self = .window(window)
      } else {
        return nil
      }
    }
  }

  public var text: String {
    switch self {
    case .direction(let edge): edge.directionWord
    case .next: "next"
    case .previous: "previous"
    case .window(let window): String(window.rawValue)
    }
  }
}

/// Which display `move-to-display` and `focus-display` mean. Displays are counted from 1, left to
/// right and then top to bottom.
public enum DisplayTarget: Equatable, Sendable, Codable {
  case next
  case previous
  case number(Int)

  /// More displays than a Mac can drive; keeps the number printable and the arithmetic safe.
  public static let highestNumber = 99

  /// Parses `next`, `previous` (or `prev`), or a number from 1.
  public init?(word: String) {
    switch word.lowercased() {
    case "next": self = .next
    case "previous", "prev": self = .previous
    default:
      guard let number = Int(word), (1...Self.highestNumber).contains(number) else { return nil }
      self = .number(number)
    }
  }

  public var text: String {
    switch self {
    case .next: "next"
    case .previous: "previous"
    case .number(let number): String(number)
    }
  }

  /// The place of the display meant among `count` displays in order, counting from 0. `current` is
  /// the place of the display one is on, if known; next and previous wrap around. Nil when there is no
  /// such display.
  public func index(from current: Int?, count: Int) -> Int? {
    guard count > 0 else { return nil }
    switch self {
    case .next:
      guard let current, (0..<count).contains(current) else { return 0 }
      return (current + 1) % count
    case .previous:
      guard let current, (0..<count).contains(current) else { return count - 1 }
      return (current + count - 1) % count
    case .number(let number):
      return (1...count).contains(number) ? number - 1 : nil
    }
  }
}

extension Edge {
  /// The edge as a direction of travel: left, right, up, down. `Edge(word:)` reads it back.
  public var directionWord: String {
    switch self {
    case .left: "left"
    case .right: "right"
    case .top: "up"
    case .bottom: "down"
    }
  }

  /// The edge as a place relative to something, for messages: "no window to the left", "no window above".
  public var sidePhrase: String {
    switch self {
    case .left: "to the left"
    case .right: "to the right"
    case .top: "above"
    case .bottom: "below"
    }
  }
}
