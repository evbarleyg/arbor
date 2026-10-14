import ArborCore
import Foundation
import Testing

/// Command text arrives from the control socket, `arbor://` URLs any web page can open, settings.json
/// and scripts. Whatever it holds, parsing it either gives a command or throws a `ParseError`.
@Suite struct CommandTextTests {
  /// At least one of every case on the trunk. Not a `switch`, so that adding a command elsewhere does not break this file.
  static let samples: [Command] =
    CommandTests.samples + [
      .help, .bindings, .rules, .frameRect(x: -1920, y: 0.5, width: 640, height: 480),
      .frameRect(x: 0, y: 0, width: 1_000_000, height: 1e-7), .toggleFloat(WindowID(5)), .zoom(WindowID(.max)),
      .zoomNode(NodeID(-1)), .zoomNode(NodeID(.max)), .resize(nil, .top, 0), .resize(nil, .bottom, -0.0),
      .resize(nil, .left, 1_000_000), .resize(nil, .left, -999_999.5), .resize(nil, .left, 1e-300),
      .resize(nil, .left, 0.1 + 0.2),
    ]

  @Test(arguments: samples) func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test(arguments: samples) func helpListsEveryCommand(command: Command) {
    let verb = String(command.text.prefix { $0 != " " })
    let listed = Command.helpText.split(whereSeparator: { !($0.isLetter || $0 == "-") }).map(String.init)
    #expect(listed.contains(verb), "`\(verb)` is not in `help`")
  }

  @Test func anyWhiteSpaceAndAnySlashesSeparateWords() throws {
    for text in [
      "dock left", "  dock   left  ", "dock\tleft", "dock left\n", "dock left\r\n", "\u{00A0}dock\u{2003}left", "/dock/left",
      "//dock//left//", "dock/left/", "/ dock / left /",
    ] {
      #expect(try Command.parse(text) == .dock(nil, .left), "\(text.debugDescription)")
    }
  }

  /// A word is one argument. What a URL smuggles into one with `%20` does not become more of them.
  @Test func aWordIsNeverSplit() throws {
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["dock left"]) }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["dock", "left/right"]) }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: ["dock%20left"]) }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: []) }
    #expect(throws: Command.ParseError.self) { try Command.parse(words: [""]) }
  }

  @Test func numbersAreOnlyPlainNumbers() {
    for word in [
      "0x10", "1e3", "4294967296", "99999999999999999999999", "-1", "1.0", "1,000", "١٢", "１２", "²", "w", "ww1", "n1", "''",
      "1_000", "0b1", "٣", "NaN", "inf",
    ] {
      #expect(throws: Command.ParseError.self, "zoom \(word)") { try Command.parse(words: ["zoom", word]) }
    }
    for word in ["0", "10", "-3", "1.5", "٣", "0x3", "１", "99999999999999999999", ""] {
      #expect(throws: Command.ParseError.self, "view \(word)") { try Command.parse("view \(word)") }
      #expect(throws: Command.ParseError.self, "save-view \(word)") { try Command.parse("save-view \(word)") }
    }
    for word in ["x", "0x10", "9223372036854775808", "1.5", "١", "nn1", "w1"] {
      #expect(throws: Command.ParseError.self, "zoom-node \(word)") { try Command.parse("zoom-node \(word)") }
    }
    for text in ["frame-rect 1 2 3", "frame-rect 1 2 3 4 5", "frame-rect 1 2 3 nan", "frame-rect inf 2 3 4", "frame-rect 1e7 2 3 4", "frame-rect a b c d"] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  @Test func aSecondWindowIsNotSilentlyIgnored() {
    for text in ["zoom 1 2", "float 1 2", "toggle-float 1 2", "zoom 1 left"] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  /// `neighbor left right` went left, and `view 1 2` to view 1. A word that is not understood is a mistake somebody made,
  /// and doing the rest anyway hides it. Whatever is added to a command, it is refused or it means something.
  @Test(arguments: samples) func noWordIsSilentlyIgnored(command: Command) {
    guard command != .help else { return }  // see below
    for extra in ["left", "1", "101", "on", "all", "here", "com.apple.safari", "x"] {
      let longer = try? Command.parse(command.text + " " + extra)
      #expect(longer != command, "`\(command.text) \(extra)` does `\(command.text)`")
    }
  }

  @Test(arguments: [
    "neighbor left right", "neighbour up 3", "view 1 2", "go-view 1 x", "save-view 2 3", "zoom-node 3 4", "zoom-node n3 left",
    "exclude com.apple.safari com.apple.mail", "include com.apple.safari com.apple.mail", "include a b c",
  ]) func theOnesThatUsedToBe(text: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(text) }
  }

  @Test func theRefusalSaysHowManyItTakes() {
    func refusal(_ text: String) -> String? {
      do { _ = try Command.parse(text) } catch { return "\(error)" }
      return nil
    }
    #expect(refusal("neighbor left right") == "`neighbor` takes one argument, got 2")
    #expect(refusal("exclude a.b c.d") == "`exclude` takes one argument at most, got 2")
  }

  /// Somebody who types `help dock` wants help, and the whole of it has what they are after.
  @Test func helpIsGivenWhateverFollows() throws {
    #expect(try Command.parse("help dock") == .help && Command.parse("help me please") == .help)
  }

  @Test func errorsStayShortHoweverLongTheInput() {
    let long = String(repeating: "a", count: 1_000_000)
    for text in [long, "zoom \(long)", "dock \(long)", "view \(long)", "neighbor \(long)"] {
      do {
        _ = try Command.parse(text)
        Issue.record("should not parse")
      } catch {
        #expect("\(error)".count < 300)
      }
    }
    #expect(throws: Command.ParseError.self) { try Command.parse(String(repeating: "dock ", count: 200_000)) }
    #expect(throws: Command.ParseError.self) { try Command.parse(String(repeating: "/", count: 1_000_000)) }
  }

  /// Random sentences from the commands' own vocabulary and from junk. Whatever parses must say
  /// what it is in a form that parses back to the same command.
  @Test(arguments: Array<UInt64>(1...20)) func randomTextNeverTrapsAndWhatParsesRoundTrips(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    let vocabulary =
      Command.helpText.split(whereSeparator: { " \n|<>[]".contains($0) }).map(String.init) + [
        "left", "right", "up", "down", "top", "bottom", "beside", "1", "2", "w3", "n4", "0", "-1", "+5", "1e300", "-1e300", "nan",
        "inf", "-inf", "1e-320", "0x1p70", "4294967295", "4294967296", "9223372036854775807", "-9223372036854775808", "1.5",
        "%20", "%", "..", "~", "\u{0}", "\u{1B}[2J", "é", "e\u{301}", "🪟", "İ", "ß", "\u{202E}", "com.apple.Mail", "'", "\"", "\\", "--help", "-h",
      ]
    for _ in 0..<3_000 {
      let words = (0..<Int.random(in: 0...6, using: &random)).map { _ in vocabulary.randomElement(using: &random)! }
      for parse in [{ try Command.parse(words: words) }, { try Command.parse(words.joined(separator: " ")) }] {
        guard let command = try? parse() else { continue }
        let text = command.text
        if text.contains("nan") { continue }  // not equal even to itself
        #expect((try? Command.parse(text)) == command, "\(words) gave `\(text)`")
      }
    }
  }
}
