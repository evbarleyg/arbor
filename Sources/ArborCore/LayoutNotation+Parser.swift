/// Reading an arrangement from text. The text is whatever its author typed, pasted or sent through a
/// URL, so nothing here may trap: every index is checked, depth and length are bounded, and
/// every refusal says which column it is about and what was expected there.
extension LayoutNotation {
  public struct ParseError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Counted in characters from 1. One past the end when the line stops too early.
    public let column: Int
    /// What was expected there, or what is wrong with what is there.
    public let message: String

    public var description: String { "column \(column): \(message)" }

    /// The part of `text` around the column, and a `^` under it, each indented by two spaces.
    public func pointer(in text: String) -> String {
      // One line, whatever was sent: a line break or a tab would move the `^` away from its column.
      let characters = text.map { $0.isWhitespace || $0.unicodeScalars.contains(where: isForbidden) ? " " : $0 }
      let width = 44
      let position = min(max(column - 1, 0), characters.count)
      var start = 0
      if characters.count > width { start = min(max(position - width / 2, 0), characters.count - width) }
      let end = min(start + width, characters.count)
      let before = start > 0 ? "…" : ""
      let after = end < characters.count ? "…" : ""
      let indent = String(repeating: " ", count: 2 + before.count + position - start)
      return "  " + before + String(characters[start..<end]) + after + "\n" + indent + "^"
    }
  }

  /// Reads an arrangement such as `Safari | Desktop | (Mail / Notes)`.
  public static func parse(_ text: String) throws(ParseError) -> Spec {
    let line = try parseLine(text)
    if let option = line.options.first {
      throw ParseError(
        column: option.column, message: "`--\(option.name)` is an option of the `layout` command, not part of an arrangement")
    }
    if let display = line.display {
      throw ParseError(
        column: display.column, message: "`@\(display.name)` belongs to the `layout` command, not to an arrangement")
    }
    guard let spec = line.spec else { throw ParseError(column: 1, message: Parser.expectedSpace) }
    return spec
  }

  /// What follows the word `layout`: an arrangement, or nothing, with `--options` and one `@display`
  /// anywhere around it.
  struct Line {
    var spec: Spec?
    var options: [(name: String, column: Int)] = []
    var display: (name: String, column: Int)?
  }

  static func parseLine(_ text: String) throws(ParseError) -> Line {
    var line = Line()
    var rest: [Token] = []
    let (tokens, end) = try tokens(of: text)
    for token in tokens {
      switch token.kind {
      case .option(let name):
        line.options.append((name, token.column))
      case .display(let name):
        guard line.display == nil else { throw ParseError(column: token.column, message: "one display at a time") }
        line.display = (name, token.column)
      default:
        rest.append(token)
      }
    }
    guard !rest.isEmpty else { return line }
    // `layout "Safari | Mail"` where no shell took the quotes off: in settings.json, the simulator, a URL. One quoted name
    // with the notation's signs in it is far more likely a whole line than an app. (`("a|b")` still names such an app.)
    if rest.count == 1, case .quoted(let inner) = rest[0].kind, inner.contains(where: { "|/([".contains($0) }),
      let unwrapped = withoutQuotes(text, openedAt: rest[0].column)
    {
      return try parseLine(unwrapped)
    }
    var parser = Parser(tokens: rest, end: end)
    line.spec = Spec(root: try parser.parseAll())
    return line
  }

  /// `text` with the quote at `column` and the one that closes it replaced by spaces, so that columns stay what they were.
  /// Nil if a quote is written twice inside: the columns would shift.
  private static func withoutQuotes(_ text: String, openedAt column: Int) -> String? {
    var characters = Array(text)
    guard characters.indices.contains(column - 1) else { return nil }
    let opening = characters[column - 1]
    let closing: Character = opening == "“" ? "”" : opening == "‘" ? "’" : opening
    guard let end = characters.lastIndex(of: closing), end > column - 1,
      !characters[column..<end].contains(closing)
    else { return nil }
    characters[column - 1] = " "
    characters[end] = " "
    return String(characters)
  }

  // MARK: Tokens

  struct Token: Equatable {
    enum Kind: Equatable {
      case beside, above, open, close, openTabs, closeTabs, size, all, title
      case word(String)
      case quoted(String)
      case option(String)
      case display(String)
    }
    var kind: Kind
    var column: Int
  }

  /// The tokens of `text`, and the column just past its end.
  static func tokens(of text: String) throws(ParseError) -> ([Token], end: Int) {
    guard text.utf8.count <= maximumLength else {
      throw ParseError(column: 1, message: "an arrangement is at most \(maximumLength) bytes long")
    }
    let characters = Array(text)
    var tokens: [Token] = []
    var index = 0

    /// The run of plain characters from `index` on, which may be empty.
    func word() throws(ParseError) -> String {
      let start = index
      while index < characters.count, isBare(characters[index]) {
        try check(characters[index], at: index)
        index += 1
      }
      guard index - start <= maximumNameLength else {
        throw ParseError(column: start + 1, message: "a name is at most \(maximumNameLength) characters long")
      }
      return String(characters[start..<index])
    }
    func check(_ character: Character, at index: Int) throws(ParseError) {
      guard !character.unicodeScalars.contains(where: isForbidden) else {
        throw ParseError(column: index + 1, message: "a character that cannot be seen; names hold only ones that can")
      }
    }
    /// The text up to the quote that closes the one at `index`.
    func quoted(closedBy closing: Character, doubles: Bool) throws(ParseError) -> String {
      let start = index
      var content = ""
      index += 1
      while index < characters.count {
        let character = characters[index]
        if character == closing {
          // Written twice, a quote stands for itself.
          guard doubles, index + 1 < characters.count, characters[index + 1] == closing else {
            index += 1
            guard !content.isEmpty else { throw ParseError(column: start + 1, message: "there is nothing between these quotes") }
            guard content.count <= maximumNameLength else {
              throw ParseError(column: start + 1, message: "a name is at most \(maximumNameLength) characters long")
            }
            return content
          }
          index += 1
        }
        try check(character, at: index)
        content.append(character)
        index += 1
      }
      throw ParseError(column: start + 1, message: "this quote is never closed")
    }

    while index < characters.count {
      let character = characters[index]
      let column = index + 1
      if character.isWhitespace {
        index += 1
        continue
      }
      let simple: Token.Kind? =
        switch character {
        case "|": .beside
        case "/": .above
        case "(": .open
        case ")": .close
        case "[": .openTabs
        case "]": .closeTabs
        case ":": .size
        case "*": .all
        case "~": .title
        default: nil
        }
      if let simple {
        tokens.append(Token(kind: simple, column: column))
        index += 1
        continue
      }
      switch character {
      case "\"", "'":
        tokens.append(Token(kind: .quoted(try quoted(closedBy: character, doubles: true)), column: column))
      // What chat apps and word processors make of quotes that are typed or pasted into them.
      case "“":
        tokens.append(Token(kind: .quoted(try quoted(closedBy: "”", doubles: false)), column: column))
      case "‘":
        tokens.append(Token(kind: .quoted(try quoted(closedBy: "’", doubles: false)), column: column))
      case "@":
        index += 1
        let name = try word()
        guard !name.isEmpty else {
          throw ParseError(column: column, message: "expected a display's number or id after `@`, as in `@2`")
        }
        tokens.append(Token(kind: .display(name), column: column))
      case "-":
        guard index + 1 < characters.count, characters[index + 1] == "-" else {
          guard tokens.last?.kind != .size else { throw ParseError(column: column, message: Parser.expectedSize) }
          throw ParseError(column: column, message: "a name that begins with `-` needs quotes")
        }
        index += 2
        tokens.append(Token(kind: .option(try word().lowercased()), column: column))
      default:
        try check(character, at: index)
        guard isBare(character) else {
          throw ParseError(
            column: column, message: "`\(character)` means nothing here; a name with punctuation in it needs quotes")
        }
        tokens.append(Token(kind: .word(try word()), column: column))
      }
    }
    return (tokens, characters.count + 1)
  }

  // MARK: Grammar

  ///     space  = item { "|" item } | item { "/" item }
  ///     item   = ( slot | "Desktop" | "(" space ")" | "[" slot { slot } "]" ) [ ":" number ]
  ///     slot   = ( name | window number ) [ "~" title ] [ "*" ]
  struct Parser {
    let tokens: [Token]
    let end: Int
    var position = 0
    var desktopColumn: Int?

    static let expectedSpace = "expected an app's name, a window number, `Desktop`, `(` or `[`"
    static let joinsItsNeighbour = "a name cannot begin or end with a character that joins the one beside it"
    static let expectedSize = "expected a size from \(text(ofSize: smallestSize)) to \(text(ofSize: largestSize)) after `:`"

    init(tokens: [Token], end: Int) {
      self.tokens = tokens
      self.end = end
    }

    var next: Token? { position < tokens.count ? tokens[position] : nil }
    var column: Int { next?.column ?? end }

    mutating func take(_ kind: Token.Kind) -> Bool {
      guard next?.kind == kind else { return false }
      position += 1
      return true
    }

    mutating func parseAll() throws(ParseError) -> Space {
      let space = try parseSpace(depth: 0)
      guard let extra = next else { return space }
      throw ParseError(column: extra.column, message: Self.complaint(about: extra, closing: "the end of the line"))
    }

    /// What to say about a token found where a space has just ended.
    static func complaint(about token: Token, closing: String) -> String {
      switch token.kind {
      case .word, .quoted, .open, .openTabs:
        "expected `|` or `/` here; a name of several words needs quotes"
      case .close: "there is no `(` for this `)`"
      case .closeTabs: "there is no `[` for this `]`"
      default: "expected `|`, `/` or \(closing)"
      }
    }

    mutating func parseSpace(depth: Int) throws(ParseError) -> Space {
      var members = [try parseItem(depth: depth)]
      var axis: Axis?
      while let token = next, token.kind == .beside || token.kind == .above {
        let written: Axis = token.kind == .beside ? .horizontal : .vertical
        guard axis == nil || axis == written else {
          throw ParseError(
            column: token.column, message: "`|` and `/` are mixed here: put brackets around one of them")
        }
        axis = written
        position += 1
        members.append(try parseItem(depth: depth))
      }
      guard let axis else { return members[0] }
      return Space(.group(axis, members))
    }

    mutating func parseItem(depth: Int) throws(ParseError) -> Space {
      guard let token = next else { throw ParseError(column: end, message: Self.expectedSpace) }
      var space: Space
      switch token.kind {
      case .open:
        guard depth < maximumDepth else {
          throw ParseError(column: token.column, message: "brackets are more than \(maximumDepth) deep")
        }
        position += 1
        space = try parseSpace(depth: depth + 1)
        guard take(.close) else {
          guard let extra = next, extra.kind != .closeTabs else {
            throw ParseError(column: token.column, message: "this `(` is never closed")
          }
          throw ParseError(column: extra.column, message: Self.complaint(about: extra, closing: "`)`"))
        }
      case .openTabs:
        position += 1
        space = Space(.windows(try parseTabs(openedAt: token.column)))
      case .word(let word) where word.lowercased() == "desktop":
        position += 1
        guard desktopColumn == nil else {
          throw ParseError(column: token.column, message: "the Desktop is already in this arrangement")
        }
        desktopColumn = token.column
        if let mark = next, mark.kind == .all || mark.kind == .title {
          throw ParseError(
            column: mark.column, message: "this goes after an app's name; an app called Desktop needs quotes")
        }
        space = Space(.desktop)
      case .word, .quoted:
        space = Space(.windows([try parseSlot()]))
      default:
        throw ParseError(column: token.column, message: Self.expectedSpace)
      }
      if take(.size) { space.size = try parseSize() }
      return space
    }

    mutating func parseTabs(openedAt opening: Int) throws(ParseError) -> [WindowSlot] {
      var slots: [WindowSlot] = []
      while true {
        guard let token = next else { throw ParseError(column: opening, message: "this `[` is never closed") }
        switch token.kind {
        case .closeTabs:
          position += 1
          guard !slots.isEmpty else {
            throw ParseError(column: token.column, message: "a tab group needs at least one name")
          }
          return slots
        case .word(let word) where word.lowercased() == "desktop":
          throw ParseError(
            column: token.column, message: "the Desktop cannot be a tab; an app called Desktop needs quotes")
        case .word, .quoted:
          slots.append(try parseSlot())
        case .size:
          throw ParseError(column: token.column, message: "tabs share one size: write it after the `]`")
        default:
          throw ParseError(column: token.column, message: "a tab group holds only names: expected a name or `]`")
        }
      }
    }

    /// Call with a word or a quoted name next.
    mutating func parseSlot() throws(ParseError) -> WindowSlot {
      guard let token = next else { throw ParseError(column: end, message: Self.expectedSpace) }
      position += 1
      var slot: WindowSlot
      switch token.kind {
      case .word(let word) where looksLikeWindowNumber(word):
        guard let id = WindowID(word: word.lowercased()) else {
          throw ParseError(column: token.column, message: "window numbers go up to \(UInt32.max)")
        }
        if let mark = next, mark.kind == .all || mark.kind == .title {
          throw ParseError(
            column: mark.column, message: "this goes after an app's name, not a window number; an app called \(word) needs quotes")
        }
        return .window(id)
      case .word(let name), .quoted(let name):
        // `Spec` drops what cannot be written. Dropped in silence, the only name of a line would leave `layout Desktop`.
        guard canBeWritten(name) else { throw ParseError(column: token.column, message: Self.joinsItsNeighbour) }
        slot = .app(name)
      default:
        throw ParseError(column: token.column, message: Self.expectedSpace)
      }
      if take(.title) {
        switch next?.kind {
        case .word(let title), .quoted(let title):
          guard canBeWritten(title) else { throw ParseError(column: column, message: Self.joinsItsNeighbour) }
          position += 1
          slot.title = title
        default:
          throw ParseError(column: column, message: "expected part of a window's title after `~`")
        }
      }
      if take(.all) { slot.takesAll = true }
      return slot
    }

    /// Digits with at most one full stop. `Double` alone would also read `1e5`, `inf`, `nan` and `0x10`.
    mutating func parseSize() throws(ParseError) -> Double {
      let message = Self.expectedSize
      guard case .word(let word) = next?.kind else { throw ParseError(column: column, message: message) }
      let digits = word.utf8.filter { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }.count
      let stops = word.utf8.filter { $0 == UInt8(ascii: ".") }.count
      guard digits > 0, stops <= 1, digits + stops == word.utf8.count, word.utf8.count <= 12,
        let size = Double(word), size >= smallestSize, size <= largestSize
      else { throw ParseError(column: column, message: message) }
      position += 1
      return tidySize(size)
    }
  }
}
