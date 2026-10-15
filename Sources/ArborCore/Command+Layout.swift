/// The `layout` command's text form (docs/LAYOUTS.md).
///
/// Every other command is a few words, split at spaces and slashes. What follows `layout` is a line in
/// a notation of its own, in which spaces, slashes and quotes mean something, so it is cut off
/// before the splitting and read by `LayoutNotation`.
extension LayoutNotation {
  /// How `layout`, printing the arrangement, writes each window.
  public enum Naming: String, Codable, Sendable, CaseIterable {
    /// By app: a line for dotfiles, shortcuts and other people.
    case apps
    /// By app and title, to tell an app's windows apart later.
    case titles
    /// By window number: exact, for as long as the windows live.
    case ids
  }
}

extension Command {
  /// What follows the verb if `text` is a `layout` command, otherwise nil.
  static func layoutLine(in text: String) -> String? {
    let trimmed = text.drop { $0.isWhitespace || $0 == "/" }
    let verb = trimmed.prefix { !$0.isWhitespace && $0 != "/" }
    guard verb.lowercased() == "layout" else { return nil }
    // The verb and the one character that ends it.
    return String(trimmed.dropFirst(verb.count).dropFirst())
  }

  /// `arbor://layout/<line>`: everything after the verb is the line, with `%` escapes decoded once. A `/`
  /// written as it is means what it means in the notation, so `arbor://layout/Mail/Notes` puts Mail above
  /// Notes. Nil if the URL is for another command.
  static func layoutLine(ofURL text: String) throws -> String? {
    let path = try path(ofURL: text).drop { $0 == "/" }
    let verb = path.prefix { $0 != "/" }
    guard percentDecoded(verb)?.lowercased() == "layout" else { return nil }
    guard let line = percentDecoded(path.dropFirst(verb.count).dropFirst()) else {
      throw ParseError("the URL has a bad % escape")
    }
    // Only the notation reads the line, so a space cannot smuggle in another command, as it could
    // among words. Line breaks and the like still have no business in a URL.
    guard !line.unicodeScalars.contains(where: LayoutNotation.isForbidden) else {
      throw ParseError("the URL has a control character in it")
    }
    return line
  }

  /// Parses what follows `layout`: `[@display] [--open] <arrangement>`, or `[@display] [--titles | --ids]`.
  static func parseLayout(_ line: String) throws -> Command {
    do {
      let parsed = try LayoutNotation.parseLine(line)
      func refuse(_ option: (name: String, column: Int), _ message: String) -> LayoutNotation.ParseError {
        LayoutNotation.ParseError(column: option.column, message: "`--\(option.name)` \(message)")
      }
      var open = false
      var naming: LayoutNotation.Naming?
      for option in parsed.options {
        switch option.name {
        case "open":
          guard parsed.spec != nil else { throw refuse(option, "needs an arrangement to open apps for") }
          open = true
        case "titles", "ids":
          guard parsed.spec == nil else {
            throw refuse(option, "goes with `layout` on its own, which prints the arrangement")
          }
          let asked: LayoutNotation.Naming = option.name == "ids" ? .ids : .titles
          if let naming, naming != asked { throw refuse(option, "and `--\(naming.rawValue)` exclude each other") }
          naming = asked
        default:
          throw refuse(option, "is not an option; there are `--open`, `--titles` and `--ids`")
        }
      }
      guard let spec = parsed.spec else { return .printLayout(display: parsed.display?.name, naming: naming ?? .apps) }
      return .layout(spec, display: parsed.display?.name, open: open)
    } catch let error as LayoutNotation.ParseError {
      throw ParseError("layout, \(error)\n\(error.pointer(in: line))")
    }
  }

  static func layoutText(display: String?, options: [String], line: String?) -> String {
    (["layout"] + (display.map { ["@\($0)"] } ?? []) + options.map { "--\($0)" } + (line.map { [$0] } ?? []))
      .joined(separator: " ")
  }

  /// What to call the command when a URL is refused it: the part that is refused, where only a part is.
  public var nameWhenRefusedFromURL: String {
    switch self {
    case .layout(_, _, true): "layout --open"
    case .layout(let spec, _, _) where spec.slots.isEmpty: "layout` without a window, which floats everything like `float-all"
    default: String(text.prefix { $0 != " " })
    }
  }

  /// Commands whose words can be part of a window title (`rule add … title …`, `layout Safari~…`, either of them after `bind`) or a name a
  /// person gave (F20). Neither is ever logged. When one of them cannot be read there is no `logText` to go by, and the reason
  /// quotes what was typed, so the log gets the first word and no more.
  public static func mayHoldPrivateWords(verb: some StringProtocol) -> Bool {
    ["rule", "bind", "layout", "name", "unname", "go"].contains(verb.lowercased())
  }

  /// Whether `word` is the first word of one of Arbor's commands. Of what a person typed, the log and a trace hold only what is one of
  /// Arbor's own words: a slip can put anybody's word first.
  public static func isVerb(_ word: some StringProtocol) -> Bool { verbs.contains(word.lowercased()) }

  private static let verbs = Set(documentedVerbs.map { $0.lowercased() })

  /// `text` for the log: the same, without the parts of window titles an arrangement can hold, or `find` (`textForLog`).
  public var logText: String {
    guard case .layout(let spec, let display, let open) = self else { return textForLog }
    // A display goes by its number. Anything else is an id from `state`, or a word that is nobody's id.
    return Self.layoutText(display: display.map { Int($0) == nil ? "…" : $0 }, options: open ? ["open"] : [], line: spec.textWithoutTitles)
  }
}
