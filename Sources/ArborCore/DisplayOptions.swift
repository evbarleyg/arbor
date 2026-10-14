import CoreGraphics

/// Options for particular displays, from the `displays` list of `settings.json`:
///
///     "displays": [
///       { "match": "builtin", "gap": 8 },
///       { "match": "Studio Display", "screenEdgeBand": 24 },
///       { "match": ">=2500", "gap": 16, "minimumUsableWidth": 300, "minimumUsableHeight": 200 }
///     ]
///
/// A large display wants wider gaps and larger tiles than a laptop's. The first match wins, as for rules, but key by
/// key: on a display each key has the value of the first entry that matches the display and sets that key, and
/// the general setting of the same name if none does (`Settings.applying`). So a particular entry goes before a
/// general one and need not repeat it. Docs: docs/features/F25-per-display-options.md.
public struct DisplayOptions: Codable, Equatable, Sendable {
  public var match: DisplayMatch
  public var gap: Double?
  public var minimumUsableWidth: Double?
  public var minimumUsableHeight: Double?
  public var screenEdgeBand: Double?

  public init(
    match: DisplayMatch, gap: Double? = nil, minimumUsableWidth: Double? = nil, minimumUsableHeight: Double? = nil,
    screenEdgeBand: Double? = nil
  ) {
    self.match = match
    self.gap = gap
    self.minimumUsableWidth = minimumUsableWidth
    self.minimumUsableHeight = minimumUsableHeight
    self.screenEdgeBand = screenEdgeBand
  }

  /// A key an entry can set: where the entry keeps it, and the general setting it stands in for.
  struct Key: Sendable {
    let name: String
    let value: KeyPath<DisplayOptions, Double?> & Sendable
    let setting: WritableKeyPath<Settings, Double> & Sendable
  }

  /// In the order they are declared.
  static let keys = [
    Key(name: CodingKeys.gap.rawValue, value: \.gap, setting: \.gap),
    Key(name: CodingKeys.minimumUsableWidth.rawValue, value: \.minimumUsableWidth, setting: \.minimumUsableWidth),
    Key(name: CodingKeys.minimumUsableHeight.rawValue, value: \.minimumUsableHeight, setting: \.minimumUsableHeight),
    Key(name: CodingKeys.screenEdgeBand.rawValue, value: \.screenEdgeBand, setting: \.screenEdgeBand),
  ]

  /// The names of the keys this entry sets.
  public var keysSet: [String] { Self.keys.filter { self[keyPath: $0.value] != nil }.map(\.name) }

  /// A value a display has from an entry, in place of the general setting called `key`.
  public struct Given: Equatable, Sendable {
    public var key: String
    public var value: Double
    /// The entry it comes from.
    public var match: DisplayMatch

    public init(key: String, value: Double, match: DisplayMatch) {
      self.key = key
      self.value = value
      self.match = match
    }
  }

  /// What `entries` give `display`: for each key, the first entry that matches the display and sets the key. Keys that
  /// none of them sets are not listed; the general settings apply to those.
  public static func given(by entries: [DisplayOptions], to display: DisplayTraits) -> [Given] {
    let matching = entries.filter { $0.match.matches(display) }
    return keys.compactMap { key in
      for entry in matching {
        if let value = entry[keyPath: key.value] { return Given(key: key.name, value: value, match: entry.match) }
      }
      return nil
    }
  }

  // MARK: Codable

  private enum CodingKeys: String, CodingKey {
    case match, gap, minimumUsableWidth, minimumUsableHeight, screenEdgeBand
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    /// A number within the bounds a layout can live with. A gap of a million points would leave no room
    /// for any window, and nothing good comes of laying out rectangles of negative size.
    func number(_ key: CodingKeys, upTo maximum: Double) throws -> Double? {
      guard let value = try c.decodeIfPresent(Double.self, forKey: key) else { return nil }
      guard value.isFinite, (0...maximum).contains(value) else {
        throw DecodingError.dataCorruptedError(
          forKey: key, in: c, debugDescription: "`\(key.rawValue)` must be between 0 and \(Int(maximum))")
      }
      return value
    }
    self.init(
      match: try c.decode(DisplayMatch.self, forKey: .match), gap: try number(.gap, upTo: 100),
      minimumUsableWidth: try number(.minimumUsableWidth, upTo: 1000),
      minimumUsableHeight: try number(.minimumUsableHeight, upTo: 1000),
      screenEdgeBand: try number(.screenEdgeBand, upTo: 100))
  }

  /// A short, readable reason why an entry in settings.json could not be read.
  static func reason(for error: any Error) -> String {
    guard let error = error as? DecodingError else { return "\(error)" }
    switch error {
    case .keyNotFound(let key, _):
      return "`\(key.stringValue)` is missing"
    case .typeMismatch(_, let context), .valueNotFound(_, let context):
      if let key = context.codingPath.last, key.intValue == nil {
        return key.stringValue == CodingKeys.match.rawValue
          ? "`match` must be text" : "`\(key.stringValue)` must be a number"
      }
      return #"expected an object such as {"match": "builtin", "gap": 8}"#
    case .dataCorrupted(let context):
      return context.debugDescription
    @unknown default:
      return "\(error)"
    }
  }
}

/// What is known about a display, for `DisplayMatch` to go by.
public struct DisplayTraits: Equatable, Sendable {
  public var id: DisplayID
  /// As System Settings shows it, e.g. "Studio Display". Empty if unknown.
  public var name: String
  /// The display with the menu bar.
  public var isMain: Bool
  /// A laptop's or an iMac's own display.
  public var isBuiltIn: Bool
  /// Its full size in points.
  public var size: CGSize

  public init(id: DisplayID, name: String, isMain: Bool, isBuiltIn: Bool, size: CGSize) {
    self.id = id
    self.name = name
    self.isMain = isMain
    self.isBuiltIn = isBuiltIn
    self.size = size
  }
}

/// Which displays an entry of `displays` is for. In settings.json it is text: `main`, `builtin`, a width
/// in points to compare with (`>=2500`, `<1800`), a display's UUID, or part of its name.
public enum DisplayMatch: Equatable, Sendable, Codable, CustomStringConvertible {
  case main
  case builtIn
  case width(Comparison, Double)
  /// The display's UUID, or text its name contains; both ignoring case.
  case named(String)

  public enum Comparison: String, Sendable, CaseIterable {
    // The two-character signs come first, so that `>=` is not read as `>` and a number starting with `=`.
    case atLeast = ">="
    case atMost = "<="
    case above = ">"
    case below = "<"
  }

  public struct ParseError: Error, CustomStringConvertible, Equatable {
    public let description: String
    init(_ description: String) { self.description = description }
  }

  public init(text: String) throws {
    let trimmed = String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    switch trimmed.lowercased() {
    case "":
      throw ParseError("`match` is empty; expected main, builtin, a width such as >=2500, a display's UUID or part of its name")
    case "main":
      self = .main
    case "builtin", "built-in":
      self = .builtIn
    case let text where !text.drop(while: { $0 == "@" }).isEmpty && text.drop(while: { $0 == "@" }).allSatisfy(\.isNumber):
      throw ParseError(
        "`\(trimmed)` is a display's number, and numbers change with the arrangement of the displays; "
          + "expected main, builtin, a width such as >=2500, the display's UUID or part of its name")
    default:
      guard let comparison = Comparison.allCases.first(where: { trimmed.hasPrefix($0.rawValue) }) else {
        self = .named(trimmed)
        return
      }
      let digits = trimmed.dropFirst(comparison.rawValue.count).drop(while: \.isWhitespace)
      guard let width = Double(digits), width.isFinite, width >= 0 else {
        throw ParseError("`\(trimmed)` compares the display's width with something that is not a number; expected e.g. >=2500")
      }
      self = .width(comparison, width)
    }
  }

  /// The canonical text form; `DisplayMatch(text:)` round-trips it.
  public var text: String {
    switch self {
    case .main: "main"
    case .builtIn: "builtin"
    case .width(let comparison, let width):
      // Widths are bounded only by being finite, so the whole-number form must not go through Int.
      comparison.rawValue + (width == width.rounded() && width < 1e15 ? String(Int(width)) : String(width))
    case .named(let text): text
    }
  }

  public var description: String { text }

  public func matches(_ display: DisplayTraits) -> Bool {
    switch self {
    case .main: return display.isMain
    case .builtIn: return display.isBuiltIn
    case .width(let comparison, let width):
      let actual = Double(display.size.width)
      switch comparison {
      case .atLeast: return actual >= width
      case .atMost: return actual <= width
      case .above: return actual > width
      case .below: return actual < width
      }
    case .named(let text):
      let wanted = text.lowercased()
      // `firstRange(of:)` compares whole characters on every platform (see AppRule.matches).
      return display.id.rawValue.lowercased() == wanted || display.name.lowercased().firstRange(of: wanted) != nil
    }
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    do {
      self = try DisplayMatch(text: text)
    } catch let error as ParseError {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

/// The `displays` list of settings.json, read one entry at a time so that an entry that cannot be read is
/// skipped, with its reason, instead of making the whole file fail to load (as `RuleList` does for rules).
struct DisplayOptionsList: Decodable {
  var entries: [DisplayOptions] = []
  /// One line per skipped entry, numbered by its place in the file: "entry 2 (>=wide): …".
  var skipped: [String] = []
  var skippedNumbers: [Int] = []

  init() {}

  init(from decoder: any Decoder) throws {
    guard var list = try? decoder.unkeyedContainer() else {
      skipped = ["`displays` must be a list of entries; none were loaded"]
      return
    }
    while !list.isAtEnd {
      let number = list.currentIndex + 1
      do {
        entries.append(try list.decode(DisplayOptions.self))
      } catch {
        // A failed decode leaves the container on the same entry. Step over it, keeping its `match`
        // (if it has one) so the message says which it is.
        let match = (try? list.decode(SkippedEntry.self))?.match
        let label = match.map { "entry \(number) (\($0))" } ?? "entry \(number)"
        skipped.append("\(label): \(DisplayOptions.reason(for: error))")
        skippedNumbers.append(number)
        // Stop rather than loop forever if the container could not move on.
        if list.currentIndex < number { break }
      }
    }
  }

  /// Any JSON value; keeps the `match` text of an object that has one.
  private struct SkippedEntry: Decodable {
    var match: String?

    private enum CodingKeys: String, CodingKey { case match }

    init(from decoder: any Decoder) throws {
      match = try? decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .match)
    }
  }
}
