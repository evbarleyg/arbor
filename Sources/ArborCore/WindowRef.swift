/// Naming a window without knowing its number (docs/features/F50-scripting.md, part 1).
///
/// Wherever a command takes `[window]`, it also takes an app's name or bundle id (`zoom Safari`,
/// `dock Mail beside Safari bottom`), `focused` or `pointer`. Which window that is depends on the moment the
/// command runs, so the parser cannot say: it keeps the name, and the controller looks the window up.
///
/// **How it fits an enum whose cases hold `WindowID`s.** The parser's one helper for window words hands out a
/// stand-in number for each name and notes the name. A command with names in it is wrapped:
/// `.naming(.dockBeside(stand-in 1, target: stand-in 2, .bottom), [.app("Mail"), .app("Safari")])`. When it runs, the
/// controller finds the windows, `filling(_:)` puts their numbers in, and the plain command is performed.
/// So every command that reads its window through that helper takes names, including commands that
/// do not exist yet, and nothing that builds or matches a plain command has to change.
public enum WindowRef: Equatable, Sendable, Codable {
  /// The most recently focused window of this app that Arbor arranges (`AppName.rank` says what counts as its name).
  case app(String)
  /// The window that has the keyboard.
  case focused
  /// The window under the pointer.
  case pointer

  /// Words that mean something else where a window can stand, so an app called that needs quotes.
  static func isReserved(_ word: String) -> Bool {
    let word = word.lowercased()
    return word == "focused" || word == "pointer" || word == "beside" || Edge(word: word) != nil
  }

  /// A number gone wrong, or one of Arbor's own ids gone wrong, is never an app's name: it is what a script's mistake looks
  /// like, and "no window of 4294967296" would send its author looking for an app. An app called that (0xED is one)
  /// needs quotes.
  /// - No letters but digits of any script: `1.0`, `1,000`, `4294967296` (one more than a window number can be), `١٢`, `²`.
  /// - What other tools print for a number: `1e3`, `0x10`, `0b1`, and awk's `nan` and `inf`.
  /// - `w` and `n` with nothing but digits after them: `w$id` with `id` empty (`w`) or already `w1` (`ww1`), and `n1`, a space.
  static func looksLikeANumber(_ word: String) -> Bool {
    if word.contains(where: \.isNumber), !word.contains(where: \.isLetter) { return true }
    if Double(word) != nil { return true }
    let small = word.lowercased()
    if small.count > 2, small.first == "0", let radix = small.dropFirst().first, "box".contains(radix),
      small.dropFirst(2).allSatisfy({ $0.isHexDigit || $0 == "_" })
    {
      return true
    }
    guard let letter = small.first, letter == "w" || letter == "n" else { return false }
    return small.drop { $0 == letter }.allSatisfy { $0.isASCII && $0.isNumber }
  }

  /// As it is written in a command: `Safari`, `"Visual Studio Code"`, `"left"`, `focused`.
  public var text: String {
    switch self {
    case .focused: return "focused"
    case .pointer: return "pointer"
    case .app(let name):
      let written = LayoutNotation.quoted(name, isName: true)
      // Also what `focus` has words of its own for (`focus "next"`): quotes that are not needed elsewhere do no harm.
      let needsQuotes = Self.isReserved(name) || Self.looksLikeANumber(name) || FocusTarget(word: name.lowercased()) != nil
      return written == name && needsQuotes ? "\"\(name)\"" : written
    }
  }

  /// Reads a word that is not a window number. `word` is as it was typed, with its quotes if it had any.
  init(word: String) throws(Command.ParseError) {
    if let quote = word.first, quote == "\"" || quote == "'" {
      guard let name = Command.unquoted(word) else { throw Command.ParseError("the quote in \(word) is never closed") }
      guard LayoutNotation.canBeWritten(name) else { throw Command.ParseError("expected an app's name between the quotes") }
      self = .app(name)
      return
    }
    switch word.lowercased() {
    case "focused": self = .focused
    case "pointer": self = .pointer
    default:
      guard !Self.isReserved(word) else {
        throw Command.ParseError("expected a window, got \(word); an app called \(word) needs quotes, or its bundle id")
      }
      guard !word.hasPrefix("-") else { throw Command.ParseError("unknown option \(word)") }
      guard !Self.looksLikeANumber(word) else {
        let what = NodeID(word: word).map { "is a space (`zoom-node \($0.rawValue)` frames it)" } ?? "is not a window's number"
        throw Command.ParseError("expected a window, and \(word) \(what); an app called \(word) needs quotes, or its bundle id")
      }
      guard LayoutNotation.canBeWritten(word) else {
        throw Command.ParseError("expected a window: a number, an app's name or bundle id, `focused` or `pointer`")
      }
      self = .app(word)
    }
  }
}

extension Command {
  /// The number that stands in for the `index`-th name of a command. The window server counts up from
  /// small numbers; nobody has seen these.
  static func standIn(_ index: Int) -> WindowID { WindowID(UInt32.max - UInt32(index)) }
  /// More names than any command has windows.
  static let mostNames = 8

  /// A word without the quotes around it, or nil if it has none. Written twice, a quote stands for itself.
  static func unquoted(_ word: String) -> String? {
    guard let quote = word.first, quote == "\"" || quote == "'", word.count >= 2, word.last == quote else { return nil }
    let twice = String(repeating: quote, count: 2)
    return word.dropFirst().dropLast().split(separator: twice, omittingEmptySubsequences: false).joined(separator: String(quote))
  }

  /// Splits command text into words. Whichever of white space and slash comes first separates the whole text, so the other can be
  /// part of a word: `bind ctrl+opt+/ desktop`, `/ dock / left /`. White space around the words of a path does not count.
  ///
  /// A word that begins with a quote runs to the quote that closes it, separators included, and keeps its quotes, which say
  /// that it is a name: `zoom "Visual Studio Code"`. Written twice, a quote stands for itself. A quote that nothing closes is a
  /// character like any other, because some commands end in words of a person's own (`trace note`, a rule's title); where a
  /// window is expected, `WindowRef` says that it is never closed.
  static func words(of text: String) -> [String] {
    let characters = Array(text)
    /// The index after the quote that closes the one at `start`, if any does.
    func end(ofQuoteAt start: Int) -> Int? {
      var index = start + 1
      while index < characters.count {
        if characters[index] == characters[start] {
          if index + 1 < characters.count, characters[index + 1] == characters[start] { index += 1 } else { return index + 1 }
        }
        index += 1
      }
      return nil
    }
    /// The words between separators, and the separator that ended the first of them.
    func split(at separates: (Character) -> Bool) -> (words: [String], first: Character?) {
      var (words, current, first): ([String], String, Character?) = ([], "", nil)
      var index = 0
      while index < characters.count {
        let character = characters[index]
        if separates(character) {
          if first == nil, !current.isEmpty { first = character }
          words.append(current)
          current = ""
        } else if current.isEmpty, character.isWhitespace {
          // Before a word of a path.
        } else if current.isEmpty, character == "\"" || character == "'", let end = end(ofQuoteAt: index) {
          current = String(characters[index..<end])
          index = end
          continue
        } else {
          current.append(character)
        }
        index += 1
      }
      words.append(current)
      // And after one.
      let trimmed = words.map { word -> String in
        var word = word
        while word.last?.isWhitespace == true { word.removeLast() }
        return word
      }
      return (trimmed.filter { !$0.isEmpty }, first)
    }
    let path = characters.first { !$0.isWhitespace } == "/" || split { $0 == "/" || $0.isWhitespace }.first == "/"
    return path ? split { $0 == "/" }.words : split(at: \.isWhitespace).words
  }

  /// `command`, which holds stand-ins for `names`, as one command. Fails if a stand-in cannot be told from a
  /// number that was typed.
  static func wrapped(_ command: Command, naming names: [WindowRef]) throws(ParseError) -> Command {
    let words = command.text.split(separator: " ")
    for index in names.indices where words.filter({ $0 == String(standIn(index).rawValue) }).count != 1 {
      throw ParseError("window numbers as large as \(standIn(index).rawValue) cannot be used beside names")
    }
    return .naming(command, names)
  }

  /// The text of a command with stand-ins, each replaced by what `replacement` gives for it.
  static func text(of command: Command, names count: Int, replacement: (Int) -> String) -> String {
    command.text.split(separator: " ").map { word -> String in
      for index in 0..<count where word == String(standIn(index).rawValue) { return replacement(index) }
      return String(word)
    }.joined(separator: " ")
  }

  /// For `.naming`: the plain command with `windows` in place of the names, in their order. Nil for any
  /// other command, or the wrong number of windows.
  public func filling(_ windows: [WindowID]) -> Command? {
    guard case .naming(let command, let names) = self, names.count == windows.count else { return nil }
    return try? Command.parse(Self.text(of: command, names: names.count) { String(windows[$0].rawValue) })
  }
}
