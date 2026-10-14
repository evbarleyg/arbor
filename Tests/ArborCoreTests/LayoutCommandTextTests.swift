import ArborCore
import Foundation
import Testing

private func spec(_ line: String) throws -> LayoutNotation.Spec { try LayoutNotation.parse(line) }

/// The `layout` command's text form: from a terminal, settings.json's `bindings` and `arbor://` URLs.
@Suite struct LayoutCommandTextTests {
  // MARK: Text

  @Test func theLineFollowsTheVerb() throws {
    #expect(try Command.parse("layout Safari | Desktop | (Mail / Notes)") == .layout(spec("Safari | Desktop | (Mail / Notes)"), display: nil, open: false))
    #expect(try Command.parse("  LAYOUT   Xcode:2|(Simulator/Terminal)  ") == .layout(spec("Xcode:2 | (Simulator / Terminal)"), display: nil, open: false))
    #expect(try Command.parse("layout\t[Safari Chrome] | Slack\r\n") == .layout(spec("[Safari Chrome] | Slack"), display: nil, open: false))
    #expect(try Command.parse("layout \"Visual Studio Code\" | 'Google Chrome'") == .layout(spec("\"Visual Studio Code\" | \"Google Chrome\""), display: nil, open: false))
  }

  @Test func theHelpsExampleWorksAsItStands() throws {
    let expected = Command.layout(try spec("Safari | Desktop | (Mail / Notes)"), display: nil, open: false)
    #expect(try Command.parse("layout \"Safari | Desktop | (Mail / Notes)\"") == expected)
    #expect(try Command.parse("layout @2 'Safari | Mail' --open") == .layout(spec("Safari | Mail"), display: "2", open: true))
    #expect(try Command.parse(url: "arbor://layout/%22Safari%7CDesktop%7C(Mail%2FNotes)%22") == expected)
  }

  @Test func namesKeepTheirCase() throws {
    guard case .layout(let parsed, _, _) = try Command.parse("layout com.apple.Safari | iTerm2") else {
      Issue.record("not a layout")
      return
    }
    #expect(parsed.slots == [.app("com.apple.Safari"), .app("iTerm2")])
  }

  @Test func onItsOwnItPrints() throws {
    #expect(try Command.parse("layout") == .printLayout(display: nil, naming: .apps))
    #expect(try Command.parse(" layout  ") == .printLayout(display: nil, naming: .apps))
    #expect(try Command.parse("layout --titles") == .printLayout(display: nil, naming: .titles))
    #expect(try Command.parse("layout --ids") == .printLayout(display: nil, naming: .ids))
    #expect(try Command.parse("layout --IDS @2") == .printLayout(display: "2", naming: .ids))
    #expect(try Command.parse("layout --ids --ids") == .printLayout(display: nil, naming: .ids))
    #expect(try Command.parse("layout @main") == .printLayout(display: "main", naming: .apps))
  }

  @Test func theDisplayAndTheOptionGoAnywhereAroundTheLine() throws {
    let expected = Command.layout(try spec("Safari | Mail"), display: "2", open: true)
    for text in [
      "layout @2 --open Safari | Mail", "layout --open @2 Safari | Mail", "layout Safari | Mail @2 --open", "layout @2 Safari | Mail --open",
      "layout --open Safari | Mail @2", "layout --open --open Safari | Mail @2",
    ] {
      #expect(try Command.parse(text) == expected, "\(text)")
    }
    #expect(try Command.parse("layout @9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21 A") == .layout(spec("A"), display: "9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21", open: false))
    // In quotes they are names.
    #expect(try Command.parse("layout \"--open\" | \"@2\"") == .layout(spec("\"--open\" | \"@2\""), display: nil, open: false))
  }

  @Test func wordsAreJoinedAgain() throws {
    // As `arborctl layout Safari "|" Mail` arrives, and what a caller with words in hand passes.
    #expect(try Command.parse(words: ["layout", "Safari", "|", "Mail"]) == .layout(spec("Safari | Mail"), display: nil, open: false))
    #expect(try Command.parse(words: ["Layout", "Safari | (Mail / Notes)"]) == .layout(spec("Safari | (Mail / Notes)"), display: nil, open: false))
    #expect(try Command.parse(words: ["layout"]) == .printLayout(display: nil, naming: .apps))
  }

  @Test func otherCommandsAreSplitAsBefore() throws {
    #expect(try Command.parse("dock/left") == .dock(nil, .left))
    #expect(try Command.parse("/dock/left/") == .dock(nil, .left))
    #expect(throws: Command.ParseError.self) { try Command.parse("layouts") }
    #expect(throws: Command.ParseError.self) { try Command.parse("layout(A|B)") }
    #expect(throws: Command.ParseError.self) { try Command.parse("dock layout") }
  }

  static let commands: [String] = [
    "layout", "layout --titles", "layout --ids", "layout @2", "layout @main --ids", "layout Safari", "layout Desktop",
    "layout Safari | Desktop | (Mail / Notes)", "layout @2 Safari | Mail", "layout --open Safari | Mail", "layout @2 --open Safari:2 / [Mail* 412]",
    "layout \"Visual Studio Code\"~\"main file\" | 'say \"hi\"'",
  ]

  @Test(arguments: commands) func canonicalTextRoundTrips(text: String) throws {
    let command = try Command.parse(text)
    #expect(command.text == text)
    #expect(try Command.parse(command.text) == command)
    // Also as the words a shell would make of it, where no quotes are involved.
    if !text.contains("\"") { #expect(try Command.parse(words: text.split(separator: " ").map(String.init)) == command) }
  }

  @Test(arguments: commands) func commandsSurviveJSON(text: String) throws {
    let command = try Command.parse(text)
    #expect(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(command)) == command)
  }

  @Test func printingIsAQueryAndArrangingIsNot() throws {
    #expect(try Command.parse("layout").isQuery)
    #expect(try Command.parse("layout @2 --ids").isQuery)
    #expect(try !Command.parse("layout Safari").isQuery)
    #expect(try !Command.parse("layout Desktop").isQuery)
  }

  @Test func helpMentionsIt() {
    #expect(Command.helpText.contains("layout [@display] [--open] <line>"))
    #expect(Command.helpText.contains("layout [@display] [--titles | --ids]"))
    // The example in the help is a real one.
    #expect(throws: Never.self) { try Command.parse("layout Safari | Desktop | (Mail / Notes)") }
    #expect(Command.helpText.contains("layout \"Safari | Desktop | (Mail / Notes)\""))
  }

  // MARK: Errors

  @Test func anErrorShowsWhere() {
    let error = #expect(throws: Command.ParseError.self) { try Command.parse("layout Safari | Mail / Notes") }
    #expect(
      error?.description == """
        layout, column 15: `|` and `/` are mixed here: put brackets around one of them
          Safari | Mail / Notes
                        ^
        """)
  }

  @Test func columnsCountFromTheStartOfWhatFollowsTheVerb() {
    let error = #expect(throws: Command.ParseError.self) { try Command.parse("layout @2 --open A | | B") }
    #expect(
      error?.description == """
        layout, column 15: expected an app's name, a window number, `Desktop`, `(` or `[`
          @2 --open A | | B
                        ^
        """)
  }

  @Test(arguments: [
    ("layout --open", "`--open` needs an arrangement to open apps for"),
    ("layout @2 --open", "`--open` needs an arrangement to open apps for"),
    ("layout --titles Safari", "`--titles` goes with `layout` on its own"),
    ("layout Safari --ids", "`--ids` goes with `layout` on its own"),
    ("layout --titles --ids", "`--ids` and `--titles` exclude each other"),
    ("layout --json", "`--json` is not an option; there are `--open`, `--titles` and `--ids`"),
    ("layout --", "`--` is not an option"),
    ("layout --open=yes A", "`=` means nothing here"),
    ("layout @1 @2 A", "one display at a time"),
    ("layout @ A", "expected a display's number or id after `@`"),
  ]) func optionsThatMakeNoSenseAreRefused(text: String, words: String) {
    let error = #expect(throws: Command.ParseError.self) { try Command.parse(text) }
    #expect(error?.description.contains(words) == true, "\(String(describing: error))")
  }

  @Test func errorsStayShortHoweverLongTheLine() {
    let line = "layout " + String(repeating: "Application | ", count: 200) + "/"
    let error = #expect(throws: Command.ParseError.self) { try Command.parse(line) }
    #expect((error?.description.count ?? .max) < 200)
  }

  @Test func aRefusedURLIsToldWhichPartIsRefused() throws {
    #expect(try Command.parse("layout --open Safari").nameWhenRefusedFromURL == "layout --open")
    #expect(try Command.parse("layout Desktop").nameWhenRefusedFromURL.hasPrefix("layout` without a window"))
    #expect(try Command.parse("layout --ids").nameWhenRefusedFromURL == "layout")
    #expect(Command.quit.nameWhenRefusedFromURL == "quit")
    #expect(Command.floatAllHere.nameWhenRefusedFromURL == "float-all")
  }

  // MARK: The log

  @Test func theLogNeverSeesPartsOfTitles() throws {
    let command = try Command.parse("layout @2 --open Safari~\"Secret plans\" | Mail~Payroll*")
    #expect(command.logText == "layout @2 --open Safari~… | Mail~…*")
    #expect(try Command.parse("layout Safari | Mail").logText == "layout Safari | Mail")
    #expect(Command.dock(nil, .left).logText == "dock left")
    #expect(try Command.parse("layout --titles").logText == "layout --titles")
  }

  // MARK: URLs

  @Test func aURLCarriesTheLinePercentEncoded() throws {
    let expected = Command.layout(try spec("Safari | Desktop | (Mail / Notes)"), display: nil, open: false)
    #expect(try Command.parse(url: "arbor://layout/Safari%20%7C%20Desktop%20%7C%20(Mail%20%2F%20Notes)") == expected)
    #expect(try Command.parse(url: "arbor://layout/Safari%7CDesktop%7C%28Mail%2FNotes%29") == expected)
    #expect(try Command.parse(url: "arbor:layout/Safari%7CDesktop%7C(Mail%2FNotes)") == expected)
    #expect(try Command.parse(url: "ARBOR://LAYOUT/Safari%7CDesktop%7C(Mail%2FNotes)") == expected)
    #expect(try Command.parse(url: "arbor://%6Cayout/Safari%7CDesktop%7C(Mail%2FNotes)") == expected)
    // Signs that were left as they are mean the same.
    #expect(try Command.parse(url: "arbor://layout/Safari|Desktop|(Mail/Notes)") == expected)
    #expect(try Command.parse(url: "arbor://layout/Safari | Desktop | (Mail / Notes)") == expected)
  }

  @Test func inAURLASlashIsTheNotations() throws {
    #expect(try Command.parse(url: "arbor://layout/Mail/Notes") == .layout(spec("Mail / Notes"), display: nil, open: false))
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://layout/Mail/") }
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://layout//Mail") }
  }

  @Test func aURLCanNameTheDisplayAndQuoteNames() throws {
    #expect(try Command.parse(url: "arbor://layout/@2%20Safari%7CMail") == .layout(spec("Safari | Mail"), display: "2", open: false))
    #expect(try Command.parse(url: "arbor://layout/%22Visual%20Studio%20Code%22%7CSafari") == .layout(spec("\"Visual Studio Code\" | Safari"), display: nil, open: false))
    #expect(try Command.parse(url: "arbor://layout/'Visual%20Studio%20Code'%7CSafari") == .layout(spec("\"Visual Studio Code\" | Safari"), display: nil, open: false))
    #expect(try Command.parse(url: "arbor://layout/%E5%BE%AE%E4%BF%A1") == .layout(spec("微信"), display: nil, open: false))
  }

  @Test func aQueryOrFragmentIsIgnoredAsElsewhere() throws {
    #expect(try Command.parse(url: "arbor://layout/Safari%7CMail?x-source=Shortcuts") == .layout(spec("Safari | Mail"), display: nil, open: false))
    #expect(try Command.parse(url: "arbor://layout/Safari#%7CMail") == .layout(spec("Safari"), display: nil, open: false))
    #expect(try Command.parse(url: "arbor://layout?x") == .printLayout(display: nil, naming: .apps))
  }

  @Test func escapesAreDecodedExactlyOnce() throws {
    // Decoded twice, `%257C` would be a `|`.
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://layout/Safari%257CMail") }
    #expect(try Command.parse(url: "arbor://layout/%22100%25%22") == .layout(spec("\"100%\""), display: nil, open: false))
  }

  @Test(arguments: [
    "arbor://layout/Safari%", "arbor://layout/Safari%7", "arbor://layout/Safari%zz", "arbor://layout/%FF", "arbor://layout/%C3%28",
    "arbor://layout/Safari%0A%7CMail", "arbor://layout/Safari%0D", "arbor://layout/Safari%09%7CMail", "arbor://layout/Safari%00", "arbor://layout/%1B[2J",
    "arbor://layout/%22a%E2%80%AEb%22", "arbor://layout/Safari%E2%80%A8Mail", "arbor://layout/Safari%7C", "arbor://layout/Safari%7CMail%2FNotes",
    "arbor://layout/Safari%20quit", "arbor://layout/Safari,quit", "arbor://layout%20Safari", "arbor://layout%2FSafari",
  ]) func refuses(url: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(url: url) }
  }

  @Test func aURLIsNoLongerThanAnyOther() {
    let long = "arbor://layout/" + String(repeating: "A%7C", count: 300) + "A"
    #expect(throws: Command.ParseError.self) { try Command.parse(url: long) }
  }

  @Test func aURLMayArrangeButNotOpenAppsOrAsk() throws {
    #expect(try Command.parse(url: "arbor://layout/Safari%7CMail").isAllowedFromURL)
    // `float-all` by another name.
    #expect(try !Command.parse(url: "arbor://layout/Desktop").isAllowedFromURL)
    #expect(try !Command.parse(url: "arbor://layout/@2%20Desktop:2").isAllowedFromURL)
    #expect(try Command.parse(url: "arbor://layout/@2%20Desktop%7CSafari").isAllowedFromURL)
    #expect(try !Command.parse(url: "arbor://layout/--open%20Safari%7CMail").isAllowedFromURL)
    #expect(try !Command.parse(url: "arbor://layout").isAllowedFromURL)
    #expect(try !Command.parse(url: "arbor://layout/--titles").isAllowedFromURL)
  }

  // MARK: Hostile input

  @Test func noTextCrashesParsingOrPrinting() {
    var random = NotationRandom(seed: 5400)
    var parsed = 0
    func attempt(_ parse: () throws -> Command) {
      guard let command = try? parse() else { return }
      parsed += 1
      #expect((try? Command.parse(command.text)) == command, "\(command.text.debugDescription)")
      #expect(!command.logText.isEmpty)
      _ = command.isAllowedFromURL
    }
    for _ in 0..<10_000 {
      let pieces = (0..<Int.random(in: 0...10, using: &random)).map { _ in LayoutNotationTests.pieces.randomElement(using: &random)! }
      attempt { try Command.parse("layout " + pieces.joined()) }
      attempt { try Command.parse("layout" + pieces.joined(separator: " ")) }
      attempt { try Command.parse(words: ["layout"] + pieces) }
      attempt { try Command.parse(url: "arbor://layout/" + pieces.joined()) }
      attempt { try Command.parse(url: "arbor:layout" + pieces.joined(separator: "/")) }
    }
    #expect(parsed > 1000)
  }
}
