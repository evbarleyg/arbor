/// JSON text that can be changed in one place while every other byte stays as it was: the order of
/// the keys, the spacing, the way numbers are written, keys nobody asked about.
///
/// Decoding a file and encoding it again loses all of that, and everything the decoder skipped. So
/// Arbor edits `settings.json`, which people write by hand, through this type (see
/// `Settings.rewrite`). What it adds is laid out like its surroundings: the file's indentation, line
/// endings and spacing around colons, on one line where the value it replaces was on one line.
///
/// A path is a list of object keys from the root; `[]` is the root itself. Every change returns a new
/// document parsed from the changed text, so a change can never break the structure of the file.
///
/// It reads only the structure: braces, brackets, quotes, colons and commas. What it is not asked to
/// change it does not judge, so it can edit every file `JSONDecoder` can read, which never looks at
/// values nobody decodes. `strict` is for the opposite job, telling someone whose file could not be
/// read where the typo is. Either way a comma after the last entry is fine, as it is for `JSONDecoder`.
public struct JSONText: Sendable {
  /// Where and why text is not JSON. Lines and columns count from 1; columns count characters.
  public struct SyntaxError: Error, Equatable, Sendable, CustomStringConvertible {
    public var line: Int
    public var column: Int
    public var problem: String

    public init(line: Int, column: Int, problem: String) {
      self.line = line
      self.column = column
      self.problem = problem
    }

    public var description: String { "line \(line), column \(column): \(problem)" }
  }

  /// A change that does not fit the document, such as a key inside something that is not an object.
  public struct EditError: Error, Equatable, Sendable, CustomStringConvertible {
    public var description: String

    public init(description: String) { self.description = description }
  }

  /// One element of an array passed to `settingArray`.
  public enum Element: Sendable, Equatable {
    /// JSON to lay out like its surroundings.
    case value(String)
    /// Text to keep exactly as it is, usually an element the document already has.
    case verbatim(String)
  }

  public var text: String { String(decoding: bytes, as: UTF8.self) }

  private let bytes: [UInt8]
  private let root: Node
  private let style: Style

  /// Throws a `SyntaxError`: for a broken structure, or with `strict` for anything that is not JSON.
  public init(_ text: String, strict: Bool = false) throws {
    bytes = Array(text.utf8)
    var parser = Parser(bytes: bytes, strict: strict)
    root = try parser.parseDocument()
    style = Style(bytes: bytes, root: root)
  }

  // MARK: Reading

  /// The text of the value at `path`, exactly as written, or nil if there is none.
  public func value(at path: [String]) -> String? { node(at: path).map(text(of:)) }

  /// The keys of the object at `path` in the order written, or nil if it is not an object.
  public func keys(at path: [String]) -> [String]? {
    guard case .object(let members) = node(at: path)?.kind else { return nil }
    return members.map(\.key)
  }

  /// The text of each element of the array at `path`, or nil if it is not an array.
  public func elements(at path: [String]) -> [String]? {
    guard case .array(let items) = node(at: path)?.kind else { return nil }
    return items.map(text(of:))
  }

  // MARK: Changing

  /// Sets the value at `path` to `json`, adding the key (and any missing objects on the way) at the
  /// end of its object if it is not there.
  public func setting(_ path: [String], to json: String) throws -> JSONText {
    let value = try JSONText(json)
    return try setting(path) { indent, inline in
      self.render(value.root, of: value, indent: indent, inline: inline)
    }
  }

  /// Sets the value at `path` to an array of `elements`.
  public func settingArray(_ path: [String], to elements: [Element]) throws -> JSONText {
    let parsed = try elements.map { element -> (JSONText, verbatim: Bool) in
      switch element {
      case .value(let json): return (try JSONText(json), false)
      case .verbatim(let text): return (try JSONText(text), true)
      }
    }
    // A new element is written like the ones that stay: on one line if they are, with their space
    // inside the brackets.
    let models = parsed.filter { $0.verbatim && $0.0.isInline($0.0.root) != nil }.map(\.0)
    let likeModels = !models.isEmpty && models.allSatisfy { $0.isInline($0.root) == true }
    let padding = likeModels && models[0].bytes[models[0].root.range.lowerBound + 1] == Byte.space ? " " : ""
    return try setting(path) { indent, inline in
      let inner = indent + self.style.unit
      let items = parsed.map { item, verbatim in
        verbatim
          ? item.text(of: item.root)
          : self.render(item.root, of: item, indent: inner, inline: inline || likeModels, padding: padding)
      }
      // Text kept as it is may span lines, which cannot sit inside a one-line array.
      let inline = inline && !items.contains { $0.utf8.contains(Byte.newline) }
      return self.wrap(items, in: "[", "]", indent: indent, inline: inline)
    }
  }

  /// Removes the key at `path`, with its value. Does nothing if it is not there.
  public func removing(_ path: [String]) throws -> JSONText {
    guard let key = path.last else { throw EditError(description: "the root cannot be removed") }
    var document = self
    // A key written twice is removed twice, or the second would take over from the first.
    while let parent = document.node(at: Array(path.dropLast())), case .object(let members) = parent.kind,
      let index = members.firstIndex(where: { $0.key == key })
    {
      let range: Range<Int>
      if members.count == 1 {
        range = (parent.range.lowerBound + 1)..<(parent.range.upperBound - 1)
      } else if index < members.count - 1 {
        range = members[index].keyRange.lowerBound..<members[index + 1].keyRange.lowerBound
      } else {
        range = members[index - 1].value.range.upperBound..<members[index].value.range.upperBound
      }
      document = try document.replacing(range, with: "")
    }
    return document
  }

  /// A string as JSON text, in quotes.
  public static func quote(_ string: String) -> String {
    var result = "\""
    for scalar in string.unicodeScalars {
      switch scalar {
      case "\"": result += "\\\""
      case "\\": result += "\\\\"
      case "\n": result += "\\n"
      case "\r": result += "\\r"
      case "\t": result += "\\t"
      case _ where scalar.value < 0x20:
        let hex = String(scalar.value, radix: 16)
        result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
      default: result.unicodeScalars.append(scalar)
      }
    }
    return result + "\""
  }

  // MARK: Private: changing

  /// Puts what `make` returns at `path`. `make` gets the indentation of the line the value starts on
  /// and whether the value should stay on that line.
  private func setting(_ path: [String], _ make: (_ indent: String, _ inline: Bool) -> String) throws
    -> JSONText
  {
    guard let key = path.last else { throw EditError(description: "the root cannot be replaced") }
    let parentPath = Array(path.dropLast())
    guard let parent = node(at: parentPath) else {
      // The object the key belongs in is missing too: add it empty, then try again.
      return try setting(parentPath, to: "{}").setting(path, make)
    }
    guard case .object(let members) = parent.kind else {
      let name = parentPath.last.map { "`\($0)`" } ?? "the file"
      throw EditError(description: "\(name) is not an object, so `\(key)` cannot be set in it")
    }

    // Of a key written twice, the first: that is the one `JSONDecoder` reads.
    if let member = members.first(where: { $0.key == key }) {
      let inline = isInline(member.value) ?? opensOnItsLine(parent, before: members[0].keyRange.lowerBound)
      return try replacing(member.value.range, with: make(lineIndent(at: member.keyRange.lowerBound), inline))
    }

    let colon =
      members.first.map { text(in: $0.keyRange.upperBound..<$0.value.range.lowerBound) } ?? style.colon
    if let last = members.last {
      let inline = opensOnItsLine(parent, before: members[0].keyRange.lowerBound)
      let indent = inline ? "" : lineIndent(at: members[0].keyRange.lowerBound)
      let separator = inline ? ", " : "," + style.newline + indent
      return try replacing(
        last.value.range.upperBound..<last.value.range.upperBound,
        with: separator + Self.quote(key) + colon + make(indent, inline))
    }
    let inside = (parent.range.lowerBound + 1)..<(parent.range.upperBound - 1)
    if style.inline {
      return try replacing(inside, with: Self.quote(key) + colon + make("", true))
    }
    let outer = lineIndent(at: parent.range.lowerBound)
    let indent = outer + style.unit
    return try replacing(
      inside,
      with: style.newline + indent + Self.quote(key) + colon + make(indent, false) + style.newline + outer)
  }

  private func replacing(_ range: Range<Int>, with replacement: String) throws -> JSONText {
    var changed = bytes
    changed.replaceSubrange(range, with: Array(replacement.utf8))
    return try JSONText(String(decoding: changed, as: UTF8.self))
  }

  /// `node` (a part of `source`) as text, laid out in this document's style.
  /// `padding` goes inside the brackets of what is written on one line.
  private func render(
    _ node: Node, of source: JSONText, indent: String, inline: Bool, padding: String = ""
  ) -> String {
    let inner = indent + style.unit
    switch node.kind {
    case .scalar:
      return source.text(of: node)
    case .array(let items):
      let parts = items.map { render($0, of: source, indent: inner, inline: inline, padding: padding) }
      return wrap(parts, in: "[", "]", indent: indent, inline: inline, padding: padding)
    case .object(let members):
      let parts = members.map { member in
        source.text(in: member.keyRange) + style.colon
          + render(member.value, of: source, indent: inner, inline: inline, padding: padding)
      }
      return wrap(parts, in: "{", "}", indent: indent, inline: inline, padding: padding)
    }
  }

  private func wrap(
    _ parts: [String], in open: String, _ close: String, indent: String, inline: Bool, padding: String = ""
  ) -> String {
    if parts.isEmpty { return open + close }
    if inline { return open + padding + parts.joined(separator: ", ") + padding + close }
    let inner = indent + style.unit
    let lines = parts.map { inner + $0 }.joined(separator: "," + style.newline)
    return open + style.newline + lines + style.newline + indent + close
  }

  // MARK: Private: reading

  private func node(at path: [String]) -> Node? {
    var current = root
    for key in path {
      guard case .object(let members) = current.kind, let member = members.first(where: { $0.key == key })
      else { return nil }
      current = member.value
    }
    return current
  }

  private func text(of node: Node) -> String { text(in: node.range) }

  private func text(in range: Range<Int>) -> String { String(decoding: bytes[range], as: UTF8.self) }

  /// Whether an object or array is written on one line. Nil if it is empty or not a container, which
  /// says nothing about how its writer would lay out its contents.
  private func isInline(_ node: Node) -> Bool? {
    switch node.kind {
    case .object(let members) where !members.isEmpty: break
    case .array(let items) where !items.isEmpty: break
    default: return nil
    }
    return !bytes[node.range].contains(Byte.newline)
  }

  /// Whether the first child of an object or array, which starts at `child`, is on the line of the
  /// opening bracket. That is where its writer would put another one.
  private func opensOnItsLine(_ node: Node, before child: Int) -> Bool {
    !bytes[node.range.lowerBound..<child].contains(Byte.newline)
  }

  /// The spaces and tabs at the start of the line that holds `offset`.
  private func lineIndent(at offset: Int) -> String {
    let start = (bytes[..<offset].lastIndex(of: Byte.newline) ?? -1) + 1
    let end = bytes[start...].firstIndex { $0 != Byte.space && $0 != Byte.tab } ?? bytes.count
    return text(in: start..<min(end, offset))
  }
}

// MARK: - The parsed form

extension JSONText {
  /// A value and where it is in the text (offsets into the UTF-8 bytes).
  fileprivate struct Node: Sendable {
    enum Kind: Sendable {
      case object([Member])
      case array([Node])
      /// A string, a number, true, false or null.
      case scalar
    }

    var range: Range<Int>
    var kind: Kind
  }

  fileprivate struct Member: Sendable {
    /// The key with its escapes resolved.
    var key: String
    /// The key as written, with its quotes.
    var keyRange: Range<Int>
    var value: Node
  }

  /// How the document's writer laid it out, read off the root object.
  fileprivate struct Style: Sendable {
    var newline = "\n"
    /// One level of indentation.
    var unit = "  "
    /// What is written between a key and its value. Arbor's own files have a space on both sides.
    var colon = " : "
    /// The root object is written on one line.
    var inline = false

    init(bytes: [UInt8], root: Node) {
      if let index = bytes.firstIndex(of: Byte.newline), index > 0, bytes[index - 1] == Byte.carriageReturn {
        newline = "\r\n"
      }
      guard case .object(let members) = root.kind, let first = members.first else { return }
      colon = String(decoding: bytes[first.keyRange.upperBound..<first.value.range.lowerBound], as: UTF8.self)
      let lead = bytes[(root.range.lowerBound + 1)..<first.keyRange.lowerBound]
      if let lineEnd = lead.lastIndex(of: Byte.newline) {
        unit = String(decoding: lead[(lineEnd + 1)...], as: UTF8.self)
      } else {
        inline = true
      }
    }
  }

  fileprivate enum Byte {
    static let newline = UInt8(ascii: "\n")
    static let carriageReturn = UInt8(ascii: "\r")
    static let space = UInt8(ascii: " ")
    static let tab = UInt8(ascii: "\t")
    static let quote = UInt8(ascii: "\"")
    static let backslash = UInt8(ascii: "\\")
  }
}

// MARK: - The parser

extension JSONText {
  /// Reads the structure of JSON text; with `strict`, all of RFC 8259 (but for that comma). Its
  /// errors are written for someone who has just made a typo in a settings file.
  fileprivate struct Parser {
    let bytes: [UInt8]
    let strict: Bool
    var index = 0
    var depth = 0

    /// Far deeper than any settings file. Each level takes up to 3 KB of stack in a debug build, and
    /// threads other than the main one have 512 KB on macOS.
    static let maximumDepth = 64

    init(bytes: [UInt8], strict: Bool) {
      self.bytes = bytes
      self.strict = strict
    }

    mutating func parseDocument() throws -> Node {
      if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { index = 3 }  // a byte order mark
      skipWhitespace()
      guard index < bytes.count else { throw error("the file is empty") }
      let node = try parseValue()
      skipWhitespace()
      guard index == bytes.count else { throw error("unexpected \(found()) after the end of the JSON") }
      return node
    }

    private mutating func parseValue() throws -> Node {
      guard index < bytes.count else { throw error("expected a value, but the file ends here") }
      switch bytes[index] {
      case UInt8(ascii: "{"): return try nested { try $0.parseObject() }
      case UInt8(ascii: "["): return try nested { try $0.parseArray() }
      case Byte.quote:
        let start = index
        _ = try parseString()
        return Node(range: start..<index, kind: .scalar)
      case _ where !strict: return try skipPlainValue()
      case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): return try parseNumber()
      case UInt8(ascii: "t"): return try parseWord("true")
      case UInt8(ascii: "f"): return try parseWord("false")
      case UInt8(ascii: "n"): return try parseWord("null")
      default: throw error("expected a value, found \(found())")
      }
    }

    private mutating func nested(_ parse: (inout Parser) throws -> Node) throws -> Node {
      depth += 1
      defer { depth -= 1 }
      guard depth <= Self.maximumDepth else {
        throw error("nested more than \(Self.maximumDepth) levels deep")
      }
      return try parse(&self)
    }

    private mutating func parseObject() throws -> Node {
      let start = index
      index += 1
      var members: [Member] = []
      skipWhitespace()
      if take(UInt8(ascii: "}")) { return Node(range: start..<index, kind: .object([])) }
      while true {
        guard index < bytes.count else { throw error("expected a key in quotes, but the file ends here") }
        if !members.isEmpty, take(UInt8(ascii: "}")) {  // after a comma
          return Node(range: start..<index, kind: .object(members))
        }
        guard bytes[index] == Byte.quote else { throw error("expected a key in quotes, found \(found())") }
        let keyStart = index
        let key = try parseString()
        let keyRange = keyStart..<index
        skipWhitespace()
        guard take(UInt8(ascii: ":")) else {
          throw error("expected `:` after the key `\(key)`, found \(found())")
        }
        skipWhitespace()
        members.append(Member(key: key, keyRange: keyRange, value: try parseValue()))
        skipWhitespace()
        if take(UInt8(ascii: ",")) {
          skipWhitespace()
        } else if take(UInt8(ascii: "}")) {
          return Node(range: start..<index, kind: .object(members))
        } else {
          throw error("expected `,` or `}` after the value of `\(key)`, found \(found())")
        }
      }
    }

    private mutating func parseArray() throws -> Node {
      let start = index
      index += 1
      var items: [Node] = []
      skipWhitespace()
      if take(UInt8(ascii: "]")) { return Node(range: start..<index, kind: .array([])) }
      while true {
        if !items.isEmpty, take(UInt8(ascii: "]")) {  // after a comma
          return Node(range: start..<index, kind: .array(items))
        }
        items.append(try parseValue())
        skipWhitespace()
        if take(UInt8(ascii: ",")) {
          skipWhitespace()
        } else if take(UInt8(ascii: "]")) {
          return Node(range: start..<index, kind: .array(items))
        } else {
          throw error("expected `,` or `]` in the list, found \(found())")
        }
      }
    }

    /// A number, a word, or whatever else stands where a value should: everything up to the next
    /// comma, bracket or space.
    private mutating func skipPlainValue() throws -> Node {
      let start = index
      let ends = [Byte.space, Byte.tab, Byte.newline, Byte.carriageReturn] + Array(",]}:\"".utf8)
      while index < bytes.count, !ends.contains(bytes[index]) { index += 1 }
      guard index > start else { throw error("expected a value, found \(found())") }
      return Node(range: start..<index, kind: .scalar)
    }

    /// Parses a string and returns it with its escapes resolved. Unless `strict`, only the closing
    /// quote matters, and a string with a bad escape in it is returned as written.
    private mutating func parseString() throws -> String {
      guard !strict else { return try parseStringStrictly() }
      let open = index
      index += 1
      while index < bytes.count, bytes[index] != Byte.quote {
        index += bytes[index] == Byte.backslash ? 2 : 1
      }
      guard index < bytes.count else {
        index = open
        throw error("the text starting here has no closing quote")
      }
      index += 1
      var checker = Parser(bytes: Array(bytes[open..<index]), strict: true)
      return (try? checker.parseStringStrictly())
        ?? String(decoding: bytes[(open + 1)..<(index - 1)], as: UTF8.self)
    }

    private mutating func parseStringStrictly() throws -> String {
      let open = index
      index += 1
      var scalars = String.UnicodeScalarView()
      var plainStart = index
      func flush(upTo end: Int) {
        scalars.append(contentsOf: String(decoding: bytes[plainStart..<end], as: UTF8.self).unicodeScalars)
      }
      while index < bytes.count {
        let byte = bytes[index]
        if byte == Byte.quote {
          flush(upTo: index)
          index += 1
          return String(scalars)
        }
        if byte == Byte.newline || byte == Byte.carriageReturn {
          index = open
          throw error("the text starting here has no closing quote on its line")
        }
        guard byte >= 0x20 else {
          throw error("a control character inside quotes; write it as an escape such as \\t")
        }
        guard byte == Byte.backslash else {
          index += 1
          continue
        }
        flush(upTo: index)
        scalars.append(try parseEscape())
        plainStart = index
      }
      index = open
      throw error("the text starting here has no closing quote")
    }

    /// Parses an escape, from its backslash.
    private mutating func parseEscape() throws -> Unicode.Scalar {
      let start = index
      index += 1
      guard index < bytes.count else { throw error("the file ends in the middle of an escape") }
      let byte = bytes[index]
      index += 1
      switch byte {
      case Byte.quote: return "\""
      case Byte.backslash: return "\\"
      case UInt8(ascii: "/"): return "/"
      case UInt8(ascii: "b"): return "\u{8}"
      case UInt8(ascii: "f"): return "\u{C}"
      case UInt8(ascii: "n"): return "\n"
      case UInt8(ascii: "r"): return "\r"
      case UInt8(ascii: "t"): return "\t"
      case UInt8(ascii: "u"):
        let first = try parseHex(escapeStart: start)
        if let scalar = Unicode.Scalar(first) { return scalar }
        // Half of a pair: the other half must follow.
        if (0xD800..<0xDC00).contains(first), index + 1 < bytes.count, bytes[index] == Byte.backslash,
          bytes[index + 1] == UInt8(ascii: "u")
        {
          index += 2
          let second = try parseHex(escapeStart: start)
          if (0xDC00..<0xE000).contains(second),
            let scalar = Unicode.Scalar(0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00))
          {
            return scalar
          }
        }
        index = start
        throw error("this \\u escape is half of a pair whose other half is missing")
      default:
        index = start
        throw error("unknown escape; write a backslash itself as \\\\")
      }
    }

    private mutating func parseHex(escapeStart: Int) throws -> UInt32 {
      var value: UInt32 = 0
      for _ in 0..<4 {
        guard index < bytes.count, let digit = Character(Unicode.Scalar(bytes[index])).hexDigitValue else {
          index = escapeStart
          throw error("a \\u escape needs four hexadecimal digits")
        }
        value = value << 4 | UInt32(digit)
        index += 1
      }
      return value
    }

    private mutating func parseNumber() throws -> Node {
      let start = index
      func isDigit(_ offset: Int) -> Bool {
        offset < bytes.count && (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[offset])
      }
      func fail(_ problem: String) -> SyntaxError {
        var copy = self
        copy.index = start
        return copy.error(problem)
      }
      _ = take(UInt8(ascii: "-"))
      guard isDigit(index) else { throw fail("expected digits after `-`") }
      if bytes[index] == UInt8(ascii: "0"), isDigit(index + 1) { throw fail("a number cannot start with 0") }
      while isDigit(index) { index += 1 }
      if take(UInt8(ascii: ".")) {
        guard isDigit(index) else { throw fail("a number needs digits after its point") }
        while isDigit(index) { index += 1 }
      }
      if take(UInt8(ascii: "e")) || take(UInt8(ascii: "E")) {
        if !take(UInt8(ascii: "+")) { _ = take(UInt8(ascii: "-")) }
        guard isDigit(index) else { throw fail("a number needs digits after its exponent") }
        while isDigit(index) { index += 1 }
      }
      return Node(range: start..<index, kind: .scalar)
    }

    private mutating func parseWord(_ word: String) throws -> Node {
      let start = index
      guard bytes[index...].starts(with: Array(word.utf8)) else {
        throw error("expected a value, found \(found())")
      }
      index += word.utf8.count
      return Node(range: start..<index, kind: .scalar)
    }

    private mutating func skipWhitespace() {
      while index < bytes.count {
        switch bytes[index] {
        case Byte.space, Byte.tab, Byte.newline, Byte.carriageReturn: index += 1
        default: return
        }
      }
    }

    private mutating func take(_ byte: UInt8) -> Bool {
      guard index < bytes.count, bytes[index] == byte else { return false }
      index += 1
      return true
    }

    /// What is at `index`, for an error message.
    private func found() -> String {
      guard index < bytes.count else { return "the end of the file" }
      if bytes[index] == UInt8(ascii: "/") { return "`/` (JSON has no comments)" }
      if bytes[index] == UInt8(ascii: "'") { return "`'` (JSON uses double quotes)" }
      // The whole word or the one character, so that `True` or `gap` is named in full.
      let rest = String(decoding: bytes[index...].prefix(40), as: UTF8.self)
      let word = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
      return "`\(word.isEmpty ? String(rest.prefix(1)) : String(word))`"
    }

    func error(_ problem: String) -> SyntaxError {
      let before = bytes[..<min(index, bytes.count)]
      let lineStart = (before.lastIndex(of: Byte.newline) ?? -1) + 1
      let line = before.reduce(1) { $1 == Byte.newline ? $0 + 1 : $0 }
      let column = String(decoding: before[lineStart...], as: UTF8.self).count + 1
      return SyntaxError(line: line, column: column, problem: problem)
    }
  }
}
