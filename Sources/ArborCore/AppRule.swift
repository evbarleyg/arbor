import CoreGraphics

/// A per-app rule from `settings.json`: what Arbor does with a new window of
/// one app, optionally only when the window's title contains some text.
///
///     { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" }
///
/// `Settings.rules` is checked in order and the first matching rule wins.
/// Rules apply only to windows that appear while Arbor is running; windows
/// found at launch or restored from state keep their place, except that
/// `ignore` applies to them too (see `Controller+Rules.swift`).
public struct AppRule: Codable, Equatable, Sendable, CustomStringConvertible {
  /// The app's bundle id, matched ignoring case: no two apps differ by that alone, and a rule that
  /// looks right and never matches helps nobody. A `*` at the end stands for the rest of it
  /// (`com.jetbrains.*`), so `*` alone is any app.
  public var app: String
  /// Text the window title must contain, ignoring case. Nil matches any title.
  public var title: String?
  public var action: RuleAction

  public init(app: String, title: String? = nil, action: RuleAction) {
    self.app = app
    // An empty pattern would match every title; say so with nil instead.
    self.title = title?.isEmpty == true ? nil : title
    self.action = action
  }

  /// Whether the rule is about windows of the app `bundleID`, whatever their title.
  public func covers(bundleID: String?) -> Bool {
    guard hasWildcard else { return bundleID?.lowercased() == app.lowercased() }
    // A window without a bundle id belongs to "any app" and to no family of apps.
    return (bundleID ?? "").lowercased().hasPrefix(app.dropLast().lowercased()) && (bundleID != nil || app == "*")
  }

  public var hasWildcard: Bool { app.hasSuffix("*") }

  /// Whether the rule docks windows nobody named: it was written for apps its author never listed, or leaves the
  /// place to Arbor. Such a rule passes over windows that are not worth a place (`AutoDock.accepts`).
  public var isCautious: Bool {
    switch action {
    case .dockAuto: true
    case .dock, .dockBeside: hasWildcard
    case .float, .ignore, .pin: false
    }
  }

  public func matches(bundleID: String?, title windowTitle: String) -> Bool {
    guard covers(bundleID: bundleID) else { return false }
    guard let title, !title.isEmpty else { return true }
    // `firstRange(of:)` compares whole characters on every platform. `contains` would be Foundation's
    // wherever a file of this module imports it, and that one can match part of a character.
    return windowTitle.lowercased().firstRange(of: title.lowercased()) != nil
  }

  /// The same for a new window, of which more is known: the size it opened with and whether that can be changed.
  /// `minimum` is the smallest window a cautious rule takes.
  public func matches(
    bundleID: String?, title: String, openingSize: CGSize, isResizable: Bool, minimum: CGSize
  ) -> Bool {
    matches(bundleID: bundleID, title: title)
      && (!isCautious || AutoDock.accepts(size: openingSize, isResizable: isResizable, minimum: minimum))
  }

  /// The first rule in `rules` that matches a window, or nil if none does
  /// (the window then floats, as it would without rules).
  public static func firstMatch(in rules: [AppRule], bundleID: String?, title: String) -> AppRule? {
    rules.first { $0.matches(bundleID: bundleID, title: title) }
  }

  /// `com.apple.mail, title contains "Inbox" → dock left`
  public var description: String {
    var text = app == "*" ? "any app" : app
    if let title, !title.isEmpty { text += ", title contains \"\(title)\"" }
    return text + " → " + action.text
  }

  // MARK: Codable

  private enum CodingKeys: String, CodingKey {
    case app, title, action
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let app = try c.decode(String.self, forKey: .app)
    // Bundle ids never contain spaces, so a space is a typo that would make
    // the rule silently match nothing.
    guard !app.isEmpty, !app.contains(where: \.isWhitespace) else {
      throw DecodingError.dataCorruptedError(
        forKey: .app, in: c,
        debugDescription: "`app` must be a bundle id such as com.apple.Terminal, got \"\(app)\"")
    }
    self.init(
      app: app, title: try c.decodeIfPresent(String.self, forKey: .title),
      action: try c.decode(RuleAction.self, forKey: .action))
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(app, forKey: .app)
    try c.encodeIfPresent(title, forKey: .title)
    try c.encode(action, forKey: .action)
  }

  /// A short, readable reason why a rule in settings.json could not be read.
  static func reason(for error: any Error) -> String {
    guard let error = error as? DecodingError else { return "\(error)" }
    switch error {
    case .keyNotFound(let key, _):
      return "`\(key.stringValue)` is missing"
    case .typeMismatch(_, let context), .valueNotFound(_, let context):
      if let key = context.codingPath.last, key.intValue == nil {
        return "`\(key.stringValue)` must be text"
      }
      return #"expected an object such as {"app": "com.apple.Terminal", "action": "dock right"}"#
    case .dataCorrupted(let context):
      return context.debugDescription
    @unknown default:
      return "\(error)"
    }
  }
}

/// What a rule does with a new window. In settings.json it is text:
/// `float`, `dock auto`, `dock <edge>`, `dock beside <bundle id> <edge>`, `ignore` or `pin`.
public enum RuleAction: Equatable, Sendable, Codable, CustomStringConvertible {
  /// Float where the app put it, as windows do without rules.
  case float
  /// Dock at this edge of the current view on the window's display.
  case dock(Edge)
  /// Dock beside the most recently focused docked window of the app with this
  /// bundle id on the same display, or at this edge of the view if it has none there.
  case dockBeside(bundleID: String, Edge)
  /// Leave the window alone: never dock, float, park or move it.
  case ignore
  /// Float where the app put it, and stay in view wherever the camera goes.
  case pin
  /// Dock where there is room: beside the focused window, or at an edge of the view (AutoDock.swift).
  case dockAuto

  public struct ParseError: Error, CustomStringConvertible, Equatable {
    public let description: String
    init(_ description: String) { self.description = description }
  }

  /// Parses `float`, `ignore`, `pin`, `dock auto`, `dock right` or `dock beside com.apple.mail bottom`.
  /// Words are case-insensitive except the bundle id, which is kept as written.
  public init(text: String) throws {
    let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    let usage = "expected float, ignore, pin, dock auto, dock <edge> or dock beside <bundle id> <edge>"
    func edge(_ word: String) throws -> Edge {
      guard let edge = Edge(word: word) else {
        throw ParseError("unknown edge `\(word)` in `\(text)`; expected left, right, top or bottom")
      }
      return edge
    }
    switch (words.first?.lowercased(), words.count) {
    case ("float", 1): self = .float
    case ("ignore", 1): self = .ignore
    case ("pin", 1): self = .pin
    case ("dock", 2) where words[1].lowercased() == "auto": self = .dockAuto
    case ("dock", 2): self = .dock(try edge(words[1]))
    case ("dock", 4) where words[1].lowercased() == "beside":
      self = .dockBeside(bundleID: words[2], try edge(words[3]))
    case (nil, _): throw ParseError("`action` is empty; \(usage)")
    default: throw ParseError("unknown action `\(text)`; \(usage)")
    }
  }

  /// The canonical text form; `RuleAction(text:)` round-trips it.
  public var text: String {
    switch self {
    case .float: "float"
    case .dock(let edge): "dock \(edge.rawValue)"
    case .dockBeside(let bundleID, let edge): "dock beside \(bundleID) \(edge.rawValue)"
    case .ignore: "ignore"
    case .pin: "pin"
    case .dockAuto: "dock auto"
    }
  }

  public var description: String { text }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    do {
      self = try RuleAction(text: text)
    } catch let error as ParseError {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

/// The `rules` list of settings.json, read one rule at a time so that a rule
/// that cannot be read is skipped, with its reason, instead of making the
/// whole file fail to load.
struct RuleList: Decodable {
  var rules: [AppRule] = []
  /// One line per skipped entry, numbered by its place in the file:
  /// "entry 3 (com.apple.Notes): `action` is missing".
  var skipped: [String] = []

  init() {}

  init(from decoder: any Decoder) throws {
    guard var list = try? decoder.unkeyedContainer() else {
      skipped = ["`rules` must be a list of rules; none were loaded"]
      return
    }
    while !list.isAtEnd {
      let number = list.currentIndex + 1
      do {
        rules.append(try list.decode(AppRule.self))
      } catch {
        // A failed decode leaves the container on the same entry. Step over
        // it, keeping its `app` (if it has one) so the message says which it is.
        let app = (try? list.decode(SkippedEntry.self))?.app
        let label = app.map { "entry \(number) (\($0))" } ?? "entry \(number)"
        skipped.append("\(label): \(AppRule.reason(for: error))")
        // Stop rather than loop forever if the container could not move on.
        if list.currentIndex < number { break }
      }
    }
  }

  /// Any JSON value; keeps the `app` text of an object that has one.
  private struct SkippedEntry: Decodable {
    var app: String?

    private enum CodingKeys: String, CodingKey { case app }

    init(from decoder: any Decoder) throws {
      app = try? decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .app)
    }
  }
}
