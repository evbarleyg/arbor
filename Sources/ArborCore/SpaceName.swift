/// The names people give to spaces (docs/features/F20-named-spaces.md): what a name may be, when two
/// names are the same, and which name a typed text means.
///
/// A name is text from outside (a command line, a hand-edited `state.json`, a field on screen) that ends
/// up in the menu, in replies and in the log, so everything that takes one goes through `tidied`.
public enum SpaceName {
  /// Long enough for a few words, short enough for a menu item, a tile's caption and one line of a reply.
  public static let maximumLength = 40
  /// A character can carry any number of combining marks, so characters alone do not bound a name.
  static let maximumScalars = 120

  /// Why a text cannot be a name, in words for the person who typed it.
  public struct Problem: Error, Equatable, Sendable, CustomStringConvertible {
    public let description: String
  }

  /// The name as it is kept and shown: words separated by one space each, capitals as typed. `/`
  /// separates words like a space, as it does in commands and `arbor://` URLs, so that a name is the
  /// same however it arrives and `Command.text` can be parsed back.
  public static func tidied(_ text: String) throws -> String {
    let words = text.split(whereSeparator: { $0 == "/" || $0.isWhitespace })
    let name = words.joined(separator: " ")
    guard !name.isEmpty else { throw Problem(description: "a name needs at least one character") }
    guard name.count <= maximumLength, name.unicodeScalars.count <= maximumScalars else {
      throw Problem(description: "a name can have at most \(maximumLength) characters")
    }
    guard name.unicodeScalars.allSatisfy(isAllowed) else {
      throw Problem(description: "a name cannot hold control characters or invisible formatting")
    }
    if words.count == 1, Edge(word: name) != nil {
      throw Problem(description: "a space cannot be named `\(name)`: `go \(name)` means the neighbouring space")
    }
    return name
  }

  /// Whether `text` is a name exactly as `tidied` would return it.
  public static func isTidy(_ text: String) -> Bool { (try? tidied(text)) == text }

  /// What names are compared by: two names with the same key are the same name.
  public static func key(_ name: String) -> String { name.lowercased() }

  public static func areSame(_ a: String, _ b: String) -> Bool { key(a) == key(b) }

  /// Names in the order lists show them: by letters, whatever the capitals.
  public static func sorted(_ names: some Sequence<String>) -> [String] {
    names.sorted { (key($0), $0) < (key($1), $1) }
  }

  // MARK: Finding

  public enum Match: Equatable, Sendable {
    case found(String)
    /// Several names begin with the text, in list order.
    case several([String])
    case none
  }

  /// The one of `names` that is `text`, capitals and spacing aside.
  public static func exact(_ text: String, among names: some Sequence<String>) -> String? {
    let wanted = searchKey(text)
    return names.first { key($0) == wanted }
  }

  /// The one of `names` that `text` means: the name itself, or else the only one that begins with it.
  public static func match(_ text: String, among names: some Sequence<String>) -> Match {
    let names = Array(names)
    if let name = exact(text, among: names) { return .found(name) }
    let wanted = searchKey(text)
    guard !wanted.isEmpty else { return .none }
    let fits = sorted(names.filter { key($0).hasPrefix(wanted) })
    switch fits.count {
    case 0: return .none
    case 1: return .found(fits[0])
    default: return .several(fits)
    }
  }

  /// Tidied like a name, but anything may be searched for: text that could not be a name finds nothing.
  private static func searchKey(_ text: String) -> String {
    key(text.split(whereSeparator: { $0 == "/" || $0.isWhitespace }).joined(separator: " "))
  }

  // MARK: Characters

  private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.properties.generalCategory {
    case .control, .lineSeparator, .paragraphSeparator, .surrogate, .unassigned, .privateUse: false
    // The joiner builds emoji such as 👩‍💻. The rest of the category hides text or turns it round.
    case .format: scalar == "\u{200D}"
    default: true
    }
  }
}

extension Command {
  /// The texts in this command that are, or may be, names of spaces. And a word where a display's number was wanted: replies quote it alike.
  public var namesInText: Set<String> {
    switch self {
    case .name(let name), .goToSpace(let name), .unname(let name?): [name]
    case .layout(_, let display?, _) where Int(display) == nil: [display]
    // What a shortcut is made to run is a command like any other.
    case .settings(.bind(_, let command)): (try? Command.parse(command))?.namesInText ?? []
    default: []
    }
  }

  /// `text` for the log, which does not get to see names: `go ‹name›`. Nor titles, hence `logText`.
  public var textWithoutNames: String {
    switch self {
    case .name: "name ‹name›"
    case .goToSpace: "go ‹name›"
    case .unname(.some): "unname ‹name›"
    default: logText
    }
  }
}
