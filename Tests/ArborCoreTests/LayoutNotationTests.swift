import ArborCore
import Foundation
import Testing

private typealias Space = LayoutNotation.Space
private typealias Spec = LayoutNotation.Spec

private func app(_ name: String, size: Double = 1) -> Space { Space(.windows([.app(name)]), size: size) }
private func row(_ members: Space..., size: Double = 1) -> Space { Space(.group(.horizontal, members), size: size) }
private func column(_ members: Space..., size: Double = 1) -> Space { Space(.group(.vertical, members), size: size) }
private func desktop(size: Double = 1) -> Space { Space(.desktop, size: size) }

/// A repeatable source of randomness: a failure can be run again.
struct NotationRandom: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { state = seed }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// Reading and writing arrangements as text (docs/features/F54-layouts-as-text.md).
@Suite struct LayoutNotationTests {
  // MARK: What the notation means

  @Test func theExamplesOfTheSpecParse() throws {
    #expect(
      try LayoutNotation.parse("Safari | Desktop | (Mail / Notes)")
        == Spec(root: row(app("Safari"), desktop(), column(app("Mail"), app("Notes")))))
    #expect(
      try LayoutNotation.parse("Xcode:2 | (Simulator / Terminal)")
        == Spec(root: row(app("Xcode", size: 2), column(app("Simulator"), app("Terminal")))))
    #expect(
      try LayoutNotation.parse("[Safari Chrome] | Slack")
        == Spec(root: row(Space(.windows([.app("Safari"), .app("Chrome")])), app("Slack"))))
  }

  @Test func oneNameIsAnArrangement() throws {
    #expect(try LayoutNotation.parse("Safari") == Spec(root: app("Safari")))
    #expect(try LayoutNotation.parse("Desktop") == Spec(root: desktop()))
    #expect(try LayoutNotation.parse("com.apple.Safari") == Spec(root: app("com.apple.Safari")))
  }

  @Test func spacesBetweenSignsDoNotMatter() throws {
    let expected = try LayoutNotation.parse("Safari:2 | (Mail / Notes):0.5 | [A B*]")
    #expect(try LayoutNotation.parse("Safari:2|(Mail/Notes):0.5|[A B*]") == expected)
    #expect(try LayoutNotation.parse("  Safari : 2  |  ( Mail  /  Notes ) : 0.5 | [ A  B * ]  ") == expected)
    #expect(try LayoutNotation.parse("Safari:2\t|\n(Mail/Notes):.5|[A B*]\r\n") == expected)
  }

  @Test func desktopIsTheDesktopInAnyCaseAndANameInQuotes() throws {
    #expect(try LayoutNotation.parse("desktop | A") == Spec(root: row(desktop(), app("A"))))
    #expect(try LayoutNotation.parse("DESKTOP:0.25 | A") == Spec(root: row(desktop(size: 0.25), app("A"))))
    #expect(try LayoutNotation.parse("\"Desktop\" | A") == Spec(root: row(app("Desktop"), app("A"))))
    #expect(try LayoutNotation.parse("\"Desktop\" | Desktop").mentionsDesktop)
    #expect(try !LayoutNotation.parse("\"Desktop\" | A").mentionsDesktop)
  }

  @Test func namesWithSpacesOrPunctuationGoInQuotesOfEitherKind() throws {
    let expected = Spec(root: row(app("Visual Studio Code"), app("Fantastical - Calendar & Tasks")))
    #expect(try LayoutNotation.parse("\"Visual Studio Code\" | \"Fantastical - Calendar & Tasks\"") == expected)
    #expect(try LayoutNotation.parse("'Visual Studio Code' | 'Fantastical - Calendar & Tasks'") == expected)
    // What a chat app makes of quotes pasted into it.
    #expect(try LayoutNotation.parse("“Visual Studio Code” | ‘Fantastical - Calendar & Tasks’") == expected)
  }

  @Test func plainNamesNeedNoQuotes() throws {
    for name in ["zoom.us", "iTerm2", "1Password", "com.apple.dt.Xcode", "org.mozilla.firefox-dev", "a_b", "Café", "微信", "Æther", "x-"] {
      #expect(try LayoutNotation.parse(name) == Spec(root: app(name)), "\(name)")
      #expect(try LayoutNotation.parse(name).text == name)
    }
  }

  @Test func aQuoteWrittenTwiceStandsForItself() throws {
    #expect(try LayoutNotation.parse("\"say \"\"hi\"\"\"") == Spec(root: app("say \"hi\"")))
    #expect(try LayoutNotation.parse("'it''s'") == Spec(root: app("it's")))
    #expect(try LayoutNotation.parse("'say \"hi\"'") == Spec(root: app("say \"hi\"")))
    #expect(try LayoutNotation.parse("\"it's\"") == Spec(root: app("it's")))
  }

  @Test func aWholeLineInQuotesIsUnwrapped() throws {
    // Where no shell takes the quotes off: settings.json, the simulator, the help's own example typed as it stands.
    let expected = try LayoutNotation.parse("Safari | (Mail / Notes)")
    #expect(try LayoutNotation.parse("\"Safari | (Mail / Notes)\"") == expected)
    #expect(try LayoutNotation.parse("'Safari | (Mail / Notes)'") == expected)
    #expect(try LayoutNotation.parse("  “Safari | (Mail / Notes)”  ") == expected)
    #expect(try LayoutNotation.parse("\"Safari | ('Mail' / Notes)\"") == expected)
    #expect(try LayoutNotation.parse("\"[A B]\"") == LayoutNotation.parse("[A B]"))
    #expect(try LayoutNotation.parse("\"A/B\"") == LayoutNotation.parse("A / B"))
    #expect(try LayoutNotation.parse("\"'A | B'\"") == LayoutNotation.parse("A | B"))
    // Without a sign in it, it is a name, as it is beside anything else.
    #expect(try LayoutNotation.parse("\"Visual Studio Code\"") == Spec(root: app("Visual Studio Code")))
    #expect(try LayoutNotation.parse("\"a|b\" | C") == Spec(root: row(app("a|b"), app("C"))))
    #expect(try LayoutNotation.parse("\"a|b\"*") == Spec(root: Space(.windows([.app("a|b", takesAll: true)]))))
    // An app that is really called that, alone, goes in brackets, and is written so.
    #expect(try LayoutNotation.parse("(\"a|b\")") == Spec(root: app("a|b")))
    #expect(Spec(root: app("a|b")).text == "(\"a|b\")")
    #expect(Spec(root: app("(x)")).text == "(\"(x)\")")
  }

  @Test func errorsInsideAnUnwrappedLineKeepTheirColumns() {
    let line = "\"Safari | Mail / Notes\""
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(line) }
    #expect(error?.column == 16)
    #expect(error?.pointer(in: line) == "  \"Safari | Mail / Notes\"\n                 ^")
  }

  @Test func numbersAreWindowsUnlessQuoted() throws {
    #expect(try LayoutNotation.parse("412 | w388") == Spec(root: row(Space(.windows([.window(WindowID(412))])), Space(.windows([.window(WindowID(388))])))))
    #expect(try LayoutNotation.parse("W7") == Spec(root: Space(.windows([.window(WindowID(7))]))))
    #expect(try LayoutNotation.parse("\"2048\"") == Spec(root: app("2048")))
    #expect(try LayoutNotation.parse("4294967295") == Spec(root: Space(.windows([.window(WindowID(.max))]))))
    // Not numbers: they only begin like one.
    #expect(try LayoutNotation.parse("1Password | w3m | 3.14") == Spec(root: row(app("1Password"), app("w3m"), app("3.14"))))
  }

  @Test func aStarTakesAllAndATildePrefersATitle() throws {
    #expect(try LayoutNotation.parse("Safari*") == Spec(root: Space(.windows([.app("Safari", takesAll: true)]))))
    #expect(try LayoutNotation.parse("Safari~Inbox") == Spec(root: Space(.windows([.app("Safari", title: "Inbox")]))))
    #expect(
      try LayoutNotation.parse("\"Google Chrome\"~\"Pull requests\"*:2 | A")
        == Spec(root: row(Space(.windows([.app("Google Chrome", title: "Pull requests", takesAll: true)]), size: 2), app("A"))))
    #expect(
      try LayoutNotation.parse("[Safari~412 Mail* 7]")
        == Spec(root: Space(.windows([.app("Safari", title: "412"), .app("Mail", takesAll: true), .window(WindowID(7))]))))
  }

  @Test func bracketsAroundOneThingAreThatThing() throws {
    #expect(try LayoutNotation.parse("(Safari)") == Spec(root: app("Safari")))
    #expect(try LayoutNotation.parse("((((Safari))))| (Mail)") == Spec(root: row(app("Safari"), app("Mail"))))
    #expect(try LayoutNotation.parse("[Safari] | Mail") == Spec(root: row(app("Safari"), app("Mail"))))
    #expect(try LayoutNotation.parse("(Desktop) | Mail") == Spec(root: row(desktop(), app("Mail"))))
    // The size outside wins; without one, the size inside is as good a guess as any.
    #expect(try LayoutNotation.parse("(Safari:3):2 | Mail") == Spec(root: row(app("Safari", size: 2), app("Mail"))))
    #expect(try LayoutNotation.parse("(Safari:3) | Mail") == Spec(root: row(app("Safari", size: 3), app("Mail"))))
  }

  @Test func theSizeOfTheWholeMeansNothing() throws {
    #expect(try LayoutNotation.parse("Safari:3") == Spec(root: app("Safari")))
    #expect(try LayoutNotation.parse("(Safari | Mail):3") == Spec(root: row(app("Safari"), app("Mail"))))
  }

  @Test func groupsStayAsTheyWereWritten() throws {
    // The tree flattens them (LayoutNotationTreeTests); the text of a shortcut should read as its author wrote it.
    let spec = try LayoutNotation.parse("(A | B):2 | C")
    #expect(spec == Spec(root: row(row(app("A"), app("B"), size: 2), app("C"))))
    #expect(spec.text == "(A | B):2 | C")
  }

  @Test func sizesAreReadToThreeDecimals() throws {
    func size(_ text: String) throws -> Double {
      guard case .group(_, let members) = try LayoutNotation.parse("A:\(text) | B").root.kind else { return .nan }
      return members[0].size
    }
    #expect(try size("2") == 2)
    #expect(try size("0.5") == 0.5)
    #expect(try size(".5") == 0.5)
    #expect(try size("5.") == 5)
    #expect(try size("1.373") == 1.373)
    #expect(try size("1.23456") == 1.235)
    #expect(try size("0.001") == 0.001)
    #expect(try size("1000") == 1000)
    #expect(try size("007") == 7)
    #expect(try size("1.0") == 1)
  }

  @Test func slotsAreListedInTheOrderWritten() throws {
    let spec = try LayoutNotation.parse("A | (B / [C D*]) | Desktop | 5")
    #expect(spec.slots == [.app("A"), .app("B"), .app("C"), .app("D", takesAll: true), .window(WindowID(5))])
  }

  // MARK: Writing

  @Test(arguments: [
    "Safari", "Desktop", "Safari | Desktop | (Mail / Notes)", "Xcode:2 | (Simulator / Terminal)", "[Safari Chrome] | Slack",
    "A / B / C", "A | (B / (C | (D / E)))", "(A | B):2 | C", "(A / B) / C", "A:0.5 | B:1.373 | Desktop:0.001 | C:1000",
    "Safari* | Mail", "[Safari* Mail*]:3 | Notes", "Safari~Inbox | Safari~\"Pull requests\"* | Safari", "412 | 388",
    "\"Visual Studio Code\" | \"Desktop\" | \"412\" | \"w5\" | \"-x\"", "'say \"hi\"' | \"it's\" | \"both \"\" and '\"",
    "\" padded \" | \"a|b\" | \"(\" | \"[x]\" | \"a:2\" | \"a*\" | \"a~b\" | \"@2\" | \"--open\"", "\"🪟\" | \"a,b\" | 微信", "(\"a/b\")", "\"a/b\"*", "\"a/b\"~x",
  ]) func canonicalTextComesBackUnchanged(line: String) throws {
    let spec = try LayoutNotation.parse(line)
    #expect(spec.text == line)
    #expect(try LayoutNotation.parse(spec.text) == spec)
    #expect("\(spec)" == line)
  }

  @Test func titlesCanBeLeftOutForTheLog() throws {
    let spec = try LayoutNotation.parse("Safari~\"Secret plans\" | [Mail~Payroll* Notes]")
    #expect(spec.textWithoutTitles == "Safari~… | [Mail~…* Notes]")
    #expect(try LayoutNotation.parse("A | B:2").textWithoutTitles == "A | B:2")
  }

  @Test func inJSONAnArrangementIsItsLine() throws {
    let spec = try LayoutNotation.parse("Safari:2 | (Mail / \"Visual Studio Code\")")
    let data = try JSONEncoder().encode(["main": spec])
    #expect(String(decoding: data, as: UTF8.self) == #"{"main":"Safari:2 | (Mail \/ \"Visual Studio Code\")"}"#)
    #expect(try JSONDecoder().decode([String: Spec].self, from: data) == ["main": spec])
    #expect(throws: DecodingError.self) { try JSONDecoder().decode([Spec].self, from: Data(#"["A | B / C"]"#.utf8)) }
    #expect(throws: DecodingError.self) { try JSONDecoder().decode([Spec].self, from: Data("[3]".utf8)) }
  }

  // MARK: Values made in code

  @Test func aSpecTidiesWhateverItIsGiven() throws {
    // Each of these would otherwise be a value that cannot be written down and read back.
    #expect(Spec(root: row()) == Spec(root: desktop()))
    #expect(Spec(root: Space(.windows([]))) == Spec(root: desktop()))
    #expect(Spec(root: row(app("A"))) == Spec(root: app("A")))
    #expect(Spec(root: row(app("A"), row(), column(Space(.windows([]))))) == Spec(root: app("A")))
    #expect(Spec(root: row(desktop(), app("A"), desktop(size: 3))) == Spec(root: row(desktop(), app("A"))))
    #expect(Spec(root: row(app("A", size: .nan), app("B", size: -1), app("C", size: .infinity), app("D", size: 0)))
      == Spec(root: row(app("A"), app("B", size: 0.001), app("C", size: 1000), app("D", size: 0.001))))
    #expect(Spec(root: row(app(""), app("a\u{0}b"), app("ok"), app(String(repeating: "x", count: 201)))) == Spec(root: app("ok")))
    #expect(Spec(root: Space(.windows([.app("A", title: "x\ny")]))) == Spec(root: app("A")))
    // These would melt into the quotes around them: an accent or a skin tone with nothing to sit on, a letter that leans forward.
    #expect(Spec(root: row(app("\u{301}x"), app("\u{1F3FB}"), app("x\u{D4E}"), app("ok"))) == Spec(root: app("ok")))
    #expect(Spec(root: Space(.windows([.app("A", title: "\u{301}")]))) == Spec(root: app("A")))
    #expect(Spec(root: app("e\u{301}")).text == "e\u{301}")
    #expect(
      Spec(root: Space(.windows([WindowSlot(.window(WindowID(4)), title: "x", takesAll: true)])))
        == Spec(root: Space(.windows([.window(WindowID(4))]))))
  }

  // MARK: Errors

  /// The line, the column the error names, and words its message must have.
  static let errors: [(String, Int, String)] = [
    ("", 1, "expected an app's name"),
    ("   ", 1, "expected an app's name"),
    ("Safari | Mail / Notes", 15, "put brackets around one of them"),
    ("Safari / Mail | Notes", 15, "put brackets around one of them"),
    ("A | (B / C | D)", 12, "put brackets around one of them"),
    ("Safari |", 9, "expected an app's name"),
    ("| Safari", 1, "expected an app's name"),
    ("Safari | | Mail", 10, "expected an app's name"),
    ("Safari / / Mail", 10, "expected an app's name"),
    ("()", 2, "expected an app's name"),
    ("A | ()", 6, "expected an app's name"),
    ("(Safari", 1, "this `(` is never closed"),
    ("A | (B / (C | D)", 5, "this `(` is never closed"),
    ("(A | B]", 1, "this `(` is never closed"),
    ("Safari)", 7, "there is no `(` for this `)`"),
    ("A | B) | C", 6, "there is no `(` for this `)`"),
    ("Safari]", 7, "there is no `[` for this `]`"),
    ("[Safari", 1, "this `[` is never closed"),
    ("A | [B C", 5, "this `[` is never closed"),
    ("[]", 2, "a tab group needs at least one name"),
    ("[A | B]", 4, "a tab group holds only names"),
    ("[A (B)]", 4, "a tab group holds only names"),
    ("[A [B]]", 4, "a tab group holds only names"),
    ("[A / B]", 4, "a tab group holds only names"),
    ("[A)", 3, "a tab group holds only names"),
    ("[A:2 B]", 3, "write it after the `]`"),
    ("[A Desktop]", 4, "the Desktop cannot be a tab"),
    ("Desktop | A | desktop", 15, "the Desktop is already in this arrangement"),
    ("Desktop*", 8, "an app called Desktop needs quotes"),
    ("Desktop~x", 8, "an app called Desktop needs quotes"),
    ("Visual Studio Code | Safari", 8, "a name of several words needs quotes"),
    ("A \"B\"", 3, "expected `|` or `/`"),
    ("A (B)", 3, "expected `|` or `/`"),
    ("(A B)", 4, "expected `|` or `/`"),
    ("A [B]", 3, "expected `|` or `/`"),
    ("A:2:3", 4, "expected `|`, `/` or the end of the line"),
    ("A**", 3, "expected `|`, `/` or the end of the line"),
    ("A*~x", 3, "expected `|`, `/` or the end of the line"),
    ("(A:2:3)", 5, "expected `|`, `/` or `)`"),
    ("*", 1, "expected an app's name"),
    (":2", 1, "expected an app's name"),
    ("~x", 1, "expected an app's name"),
    ("A:", 3, "expected a size from 0.001 to 1000"),
    ("A: | B", 4, "expected a size from 0.001 to 1000"),
    ("A:x", 3, "expected a size from 0.001 to 1000"),
    ("A:0", 3, "expected a size from 0.001 to 1000"),
    ("A:0.0009", 3, "expected a size from 0.001 to 1000"),
    ("A:1000.1", 3, "expected a size from 0.001 to 1000"),
    ("A:1e2", 3, "expected a size from 0.001 to 1000"),
    ("A:inf", 3, "expected a size from 0.001 to 1000"),
    ("A:nan", 3, "expected a size from 0.001 to 1000"),
    ("A:0x10", 3, "expected a size from 0.001 to 1000"),
    ("A:1.2.3", 3, "expected a size from 0.001 to 1000"),
    ("A:.", 3, "expected a size from 0.001 to 1000"),
    ("A:1_0", 3, "expected a size from 0.001 to 1000"),
    ("A:٣", 3, "expected a size from 0.001 to 1000"),
    ("A:\"2\"", 3, "expected a size from 0.001 to 1000"),
    ("A:0000000000001", 3, "expected a size from 0.001 to 1000"),
    ("A:-1", 3, "expected a size from 0.001 to 1000"),
    ("A: -1", 4, "expected a size from 0.001 to 1000"),
    ("A~", 3, "expected part of a window's title"),
    ("A~ | B", 4, "expected part of a window's title"),
    ("A~*", 3, "expected part of a window's title"),
    ("412*", 4, "not a window number"),
    ("w412~x", 5, "not a window number"),
    ("4294967296", 1, "window numbers go up to 4294967295"),
    ("A | w99999999999999999999999", 5, "window numbers go up to 4294967295"),
    ("\"Safari", 1, "this quote is never closed"),
    ("A | 'B | C", 5, "this quote is never closed"),
    ("A | “B\" | C", 5, "this quote is never closed"),
    ("\"\"", 1, "nothing between these quotes"),
    ("A | ''", 5, "nothing between these quotes"),
    ("A & B", 3, "`&` means nothing here"),
    ("A, B", 2, "`,` means nothing here"),
    ("A+B", 2, "`+` means nothing here"),
    ("A | 🪟", 5, "needs quotes"),
    ("A \\ B", 3, "means nothing here"),
    ("A | -B", 5, "a name that begins with `-` needs quotes"),
    ("A | B --open", 7, "`--open` is an option of the `layout` command"),
    ("--", 1, "is an option of the `layout` command"),
    ("@2 A", 1, "`@2` belongs to the `layout` command"),
    ("A | @", 5, "expected a display's number or id after `@`"),
    ("@1 @2 A", 4, "one display at a time"),
    ("A\u{0}B", 2, "cannot be seen"),
    ("A | \"B\u{202E}C\"", 7, "cannot be seen"),
    ("A | \"B\nC\"", 7, "cannot be seen"),
    ("A | B\u{200D}", 5, "cannot be seen"),
    ("\u{1B}[2J", 1, "cannot be seen"),
    ("\u{FEFF}A", 1, "cannot be seen"),
  ]

  @Test(arguments: errors) func errorsNameTheColumnAndWhatWasExpected(line: String, column: Int, words: String) {
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(line) }
    #expect(error?.column == column, "\(String(describing: error))")
    #expect(error?.message.contains(words) == true, "\(String(describing: error))")
    #expect(error?.description == "column \(column): \(error?.message ?? "")")
  }

  @Test func theErrorPointsAtTheColumn() {
    let line = "Safari | Mail / Notes"
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(line) }
    #expect(error?.pointer(in: line) == "  Safari | Mail / Notes\n                ^")
    let end = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse("A |") }
    #expect(end?.pointer(in: "A |") == "  A |\n     ^")
  }

  @Test func inALongLineTheErrorShowsOnlyTheNeighbourhood() throws {
    let names = (1...60).map { "App\($0)" }
    let line = names.joined(separator: " | ") + " / Oops | " + names.joined(separator: " | ")
    let error = try #require(#expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(line) })
    let lines = error.pointer(in: line).split(separator: "\n", omittingEmptySubsequences: false)
    #expect(lines.count == 2)
    #expect(lines[0].hasPrefix("  …") && lines[0].hasSuffix("…"))
    #expect(lines[0].count <= 50)
    // The caret is under the `/`.
    let caret = try #require(lines[1].firstIndex(of: "^"))
    let offset = lines[1].distance(from: lines[1].startIndex, to: caret)
    #expect(Array(lines[0])[offset] == "/")
  }

  @Test func thePointerIsTwoLinesWhateverTheTextHolds() {
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse("A\n|\t\u{0}B") }
    #expect(error?.pointer(in: "A\n|\t\u{0}B") == "  A |  B\n      ^")
  }

  // MARK: Limits

  @Test func lengthIsBounded() throws {
    let longest = String(repeating: "A | ", count: 1023) + "Zzzz"
    #expect(longest.utf8.count == LayoutNotation.maximumLength)
    #expect(try LayoutNotation.parse(longest).slots.count == 1024)
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(longest + "z") }
    #expect(error?.message.contains("at most 4096 bytes") == true)
    #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(String(repeating: "(", count: 10_000_000)) }
  }

  @Test func depthIsBounded() throws {
    func nested(_ depth: Int) -> String {
      // Alternating directions, so that no level is brackets around one thing.
      var line = "X"
      for level in 0..<depth { line = "(\(line) \(level % 2 == 0 ? "|" : "/") L\(level))" }
      return line
    }
    let deepest = try LayoutNotation.parse(nested(LayoutNotation.maximumDepth))
    #expect(try LayoutNotation.parse(deepest.text) == deepest)
    let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(nested(LayoutNotation.maximumDepth + 1)) }
    #expect(error?.message == "brackets are more than 50 deep")
    #expect(error?.column == LayoutNotation.maximumDepth + 1)
    #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(String(repeating: "(", count: 4000)) }
    #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(String(repeating: "[", count: 4000)) }
  }

  @Test func namesAreBounded() throws {
    let longest = String(repeating: "n", count: 200)
    #expect(try LayoutNotation.parse(longest).slots == [.app(longest)])
    #expect(try LayoutNotation.parse("\"\(longest)\"").slots == [.app(longest)])
    for line in [longest + "n", "\"\(longest)n\"", "A~\(longest)n", "@\(longest)n"] {
      let error = #expect(throws: LayoutNotation.ParseError.self) { try LayoutNotation.parse(line) }
      #expect(error?.message.contains("at most 200 characters") == true, "\(line.prefix(5))")
    }
  }

  // MARK: Properties

  /// A random arrangement, as `Spec.init` would leave it or not.
  static func randomSpace(_ random: inout NotationRandom, depth: Int, desktopAllowed: inout Bool) -> LayoutNotation.Space {
    let names = [
      "Safari", "Mail", "com.apple.Notes", "Visual Studio Code", "Desktop", "412", "w5", "it's", "say \"hi\"", "both \" and '",
      "a|b", "(x)", "[y]", "-dash", "微信", "🪟 window", " padded ", "a:2", "x*", "~", "@2", "--open", "Ünï.cödé_1-2",
      "\u{301}", "\u{301}x", "\u{1F3FB}", "x\u{D4E}", "e\u{301}", "👩‍👩‍👧", "\u{200D}", "",
    ]
    let size = [1, 1, 1, 2, 0.5, 1.373, 0.001, 1000, 3.25][Int.random(in: 0..<9, using: &random)]
    func slot(_ random: inout NotationRandom) -> WindowSlot {
      if Int.random(in: 0..<6, using: &random) == 0 { return .window(WindowID(UInt32.random(in: 0...UInt32.max, using: &random))) }
      let title = Int.random(in: 0..<4, using: &random) == 0 ? names.randomElement(using: &random) : nil
      return .app(names.randomElement(using: &random)!, title: title, takesAll: Int.random(in: 0..<5, using: &random) == 0)
    }
    switch Int.random(in: 0..<(depth > 4 ? 6 : 10), using: &random) {
    case 0 where desktopAllowed:
      desktopAllowed = false
      return Space(.desktop, size: size)
    case 0...3:
      return Space(.windows([slot(&random)]), size: size)
    case 4, 5:
      return Space(.windows((0..<Int.random(in: 2...4, using: &random)).map { _ in slot(&random) }), size: size)
    default:
      var members: [Space] = []
      for _ in 0..<Int.random(in: 2...4, using: &random) {
        members.append(randomSpace(&random, depth: depth + 1, desktopAllowed: &desktopAllowed))
      }
      return Space(.group(Bool.random(using: &random) ? .horizontal : .vertical, members), size: size)
    }
  }

  @Test func everyArrangementSurvivesBeingWrittenAndRead() throws {
    var random = NotationRandom(seed: 54)
    for round in 0..<3000 {
      var desktopAllowed = true
      let spec = Spec(root: Self.randomSpace(&random, depth: 0, desktopAllowed: &desktopAllowed))
      let text = spec.text
      guard text.utf8.count <= LayoutNotation.maximumLength else { continue }
      let back = try LayoutNotation.parse(text)
      #expect(back == spec, "round \(round): \(text)")
      #expect(back.text == text, "round \(round)")
    }
  }

  /// Whatever is thrown at the parser, it answers: with an arrangement that can be written and read
  /// back, or with an error about a column that exists.
  static func attempt(_ line: String) {
    do {
      let spec = try LayoutNotation.parse(line)
      let text = spec.text
      #expect((try? LayoutNotation.parse(text)) == spec, "\(line.debugDescription) became \(text.debugDescription)")
      #expect(!spec.textWithoutTitles.isEmpty)
    } catch {
      #expect((1...(line.count + 1)).contains(error.column), "\(line.debugDescription): \(error)")
      #expect(!error.message.isEmpty)
      let pointer = error.pointer(in: line)
      #expect(pointer.split(separator: "\n", omittingEmptySubsequences: false).count == 2, "\(line.debugDescription)")
      #expect(pointer.count <= 2 * 50)
    }
  }

  static let pieces: [String] = [
    "|", "/", "(", ")", "[", "]", ":", "*", "~", "\"", "'", "“", "”", "‘", "’", "@", "-", "--", " ", "  ", "\t", "\n", "\r\n", ".", "_",
    "A", "b", "Safari", "Desktop", "desktop", "0", "1", "2", "0.5", "412", "w5", "W", "w", "1e9", "inf", "nan", "4294967296", "--open", "@2", "@main",
    ",", ";", "&", "\\", "%", "$(quit)", "`", "{", "}", "<", ">", "=", "#", "?", "!", "+", "^",
    "\u{0}", "\u{7}", "\u{1B}", "\u{7F}", "\u{85}", "\u{A0}", "\u{AD}", "\u{200B}", "\u{200D}", "\u{202E}", "\u{2028}", "\u{2029}", "\u{FEFF}", "\u{FFFD}",
    "\u{E000}", "\u{301}", "e\u{301}", "é", "ß", "İ", "ǆ", "٣", "１２", "微", "🪟", "👩‍👩‍👧", "🇨🇭", "\u{1F3FB}", "\u{10FFFF}",
  ]

  @Test func randomTextNeverTrapsTheParser() {
    var random = NotationRandom(seed: 2026)
    for _ in 0..<20_000 {
      let count = Int.random(in: 0...14, using: &random)
      Self.attempt((0..<count).map { _ in Self.pieces.randomElement(using: &random)! }.joined())
    }
  }

  @Test func everyPairOfPiecesIsAnswered() {
    for first in Self.pieces {
      Self.attempt(first)
      for second in Self.pieces {
        Self.attempt(first + second)
        Self.attempt("A" + first + "B" + second)
        Self.attempt("(A | [B " + first + second)
      }
    }
  }

  @Test func damagedLinesNeverTrapTheParser() {
    var random = NotationRandom(seed: 7)
    let lines = [
      "Safari | Desktop | (Mail / Notes)", "Xcode:2 | (Simulator / Terminal)", "[Safari Chrome] | Slack",
      "\"Visual Studio Code\"~'main.swift'*:1.5 / (412 | [w5 Mail*]:0.25 | Desktop:0.5)",
    ]
    for line in lines {
      let characters = Array(line)
      // Cut short anywhere, and with any one character missing.
      for index in 0...characters.count { Self.attempt(String(characters[..<index])) }
      for index in characters.indices { Self.attempt(String(characters[..<index] + characters[(index + 1)...])) }
      for _ in 0..<3000 {
        var damaged = characters
        for _ in 0..<Int.random(in: 1...3, using: &random) {
          let piece = Array(Self.pieces.randomElement(using: &random)!)
          let index = Int.random(in: 0...damaged.count, using: &random)
          if Bool.random(using: &random) || index == damaged.count {
            damaged.insert(contentsOf: piece, at: index)
          } else {
            damaged.replaceSubrange(index...index, with: piece)
          }
        }
        Self.attempt(String(damaged))
      }
    }
  }
}
