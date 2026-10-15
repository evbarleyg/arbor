import ArborCore
import CoreGraphics
import Foundation
import Testing

private func roundTrip<T: Codable>(_ value: T) throws -> T {
  try JSONDecoder().decode(T.self, from: try JSONEncoder().encode(value))
}

private func decodeEntry(_ json: String) throws -> TraceEntry {
  try JSONDecoder().decode(TraceEntry.self, from: Data(json.utf8))
}

private let window = TraceWindow(
  id: WindowID(4123), pid: 811, bundle: "com.apple.Safari", app: "Safari", title: "title[2]",
  frame: CGRect(x: 0, y: 25, width: 720.5, height: 875))
private let display = TraceDisplay(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
  visible: CGRect(x: 0, y: 25, width: 1440, height: 875), main: true)

@Suite struct TraceFormatTests {
  @Test func everyKindOfLineSurvivesWritingAndReading() throws {
    var flagged = window
    flagged.minimized = true
    flagged.hidden = true
    flagged.offSpace = true
    flagged.fullScreen = true
    flagged.bundle = nil
    var settings = Settings()
    settings.gap = 20
    let id = WindowID(7)
    let point = CGPoint(x: 3, y: 450.25)
    let frame = CGRect(x: 12, y: 37, width: 702, height: 851)
    let seam = try JSONDecoder().decode(
      Seam.self,
      from: Data(
        #"{"split":2,"leading":1,"trailing":3,"axis":"horizontal","frame":[[714,37],[12,851]],"pointsPerWeight":702}"#.utf8))
    let lines: [TraceLine] = [
      .appeared(window), .appeared(flagged), .destroyed(id), .changed(window, user: true), .changed(flagged, user: false),
      .focused(id), .dragBegan(id, at: point), .dragMoved(id, to: point), .dragEnded(id, at: point),
      .resizeBegan(id), .resizeEnded(id), .displaysChanged([display]), .displaysChanged([]), .keyboardFocusMoved,
      .setFrame(id, frame, result: frame, took: 0.014), .setFrame(id, frame, result: nil, took: nil), .focus(id),
      .focusedWindow(id), .focusedWindow(nil), .cursorLocation(point), .isMouseButtonDown(true),
      .allWindows([window, flagged]), .displays([display]), .start, .stop, .showDropPreview(frame),
      .showDropPreview(nil), .command("dock 7 left"), .command("in", from: .shortcut), .command("in", from: .script), .done("dock 7 left", ok: false, message: "w7 \"is\" not\na window"),
      .tileActivated(display: DisplayID("main"), node: NodeID(4)),
      .seamDragged(display: DisplayID("main"), seam: seam, by: -12.5), .timer("enforce-main"), .settings(settings),
      .raw("AXWindowMoved w7"), .note("drag to the left edge"), .end(reason: "trace off", lines: 120, thinned: 40),
    ]
    for line in lines {
      let entry = TraceEntry(t: 1.25, line: line, nested: line == .focused(id))
      #expect(try roundTrip(entry) == entry, "\(line)")
    }
  }

  @Test func theHeaderSurvivesWritingAndReading() throws {
    var workspace = Workspace()
    workspace.dock(WindowID(4123), at: .cameraEdge(.left))
    workspace.floating[WindowID(9)] = CGRect(x: 800, y: 100, width: 400, height: 300)
    var header = TraceHeader(
      name: "safari-drag", arbor: "0.1.0", os: "macOS 26.6", recorded: "2026-10-14T09:30:05Z", displays: [display],
      windows: [window], settings: Settings(), workspaces: [display.id: workspace], focused: window.id,
      cursor: CGPoint(x: 10, y: 20), mouseDown: true, thinning: 0.05)
    header.dormant = [DisplayID("other"): Workspace()]
    header.parked = [WindowID(9)]
    header.minimumSizes = [WindowID(9): CGSize(width: 700, height: 500)]
    header.seenSizes = [
      WindowID(9): SeenSizes(
        least: CGSize(width: 700, height: 300), most: CGSize(width: 1400, height: 851), stoppedAt: CGSize(width: 0, height: 851),
        closeOffer: CGSize(width: 749, height: 0), closeTook: CGSize(width: 723, height: 0))
    ]
    header.appPlaced = [WindowID(9): CGRect(x: 300, y: 200, width: 640, height: 420)]
    header.focusHistory = [WindowID(9), window.id]
    header.onlyPIDs = [811]
    header.ignored = [WindowID(5)]
    header.framePlan = 2
    #expect(try roundTrip(header) == header)
  }

  @Test func whatWasSeenOfAWindowsSizesIsFivePairsInThisOrder() throws {
    let json = #"{"trace":1,"displays":[],"seenSizes":{"9":[[700,300],[1400,851],[0,851],[749,0],[723,0]],"10":[[1,2],[3,4]]}}"#
    let header = try JSONDecoder().decode(TraceHeader.self, from: Data(json.utf8))
    #expect(
      header.seenSizes == [
        WindowID(9): SeenSizes(
          least: CGSize(width: 700, height: 300), most: CGSize(width: 1400, height: 851), stoppedAt: CGSize(width: 0, height: 851),
          closeOffer: CGSize(width: 749, height: 0), closeTook: CGSize(width: 723, height: 0))
      ], "least, most, where it stopped, the offer it came close to, what it took; an entry that is anything else says nothing")
  }

  @Test func aHeaderWrittenByHandNeedsOnlyTheVersionAndTheDisplays() throws {
    let json = #"{"trace":1,"displays":[{"id":"main","frame":[0,0,1440,900],"visible":[0,25,1440,875],"main":true}]}"#
    let header = try JSONDecoder().decode(TraceHeader.self, from: Data(json.utf8))
    #expect(header.displays == [display])
    #expect(header.windows.isEmpty)
    #expect(header.settings == Settings())
    #expect(header.workspaces.isEmpty)
    #expect(header.focused == nil)
    #expect(header.framePlan == 1, "every trace from before there was a second order of calls was made by the first")
  }

  @Test func kindsOfLineWithoutACaseOfTheirOwnKeepTheirNameArgumentsAndResult() throws {
    #expect(try decodeEntry(#"{"t":1,"event":"levitated","args":[7,[1,2]]}"#).line == .other(.event, "levitated", arguments: [.number(7), .array([.number(1), .number(2)])]))
    #expect(try decodeEntry(#"{"t":1,"call":"setOpacity","args":[7,0.5]}"#).line == .other(.call, "setOpacity", arguments: [.number(7), .number(0.5)]))
    #expect(try decodeEntry(#"{"t":1,"call":"launchApp","args":["Safari"],"result":true}"#).line == .other(.call, "launchApp", arguments: [.string("Safari")], result: .bool(true)))
    #expect(try decodeEntry(#"{"t":1,"read":"frontmost","result":null}"#).line == .other(.read, "frontmost", result: .null))
    #expect(try decodeEntry(#"{"t":1,"read":"activity","result":{"keys":1.5,"last":"pointer"}}"#).line == .other(.read, "activity", result: .object(["keys": .number(1.5), "last": .string("pointer")])))
    #expect(try decodeEntry(#"{"t":1,"action":"tabClicked"}"#).line == .other(.action, "tabClicked"))
    #expect(try decodeEntry(#"{"t":1,"gesture":"pinch"}"#).line == .unknown("line"))
    #expect(!TraceLine.unknown("line").isStimulus)
  }

  @Test func linesWithoutACaseOfTheirOwnSurviveWritingAndReadingAndKnowWhatTheyAre() throws {
    let lines: [TraceLine] = [
      .other(.event, "dragCancelled", arguments: [.number(7)]), .other(.action, "cheatSheetDismissed"),
      .other(.call, "raise", arguments: [.number(7)]), .other(.call, "launchApp", arguments: [.string("Safari")], result: .bool(false)),
      .other(.read, "windowsFrontToBack", result: .array([.number(7), .number(8)])), .other(.read, "frontmost", result: .null),
    ]
    for line in lines { #expect(try roundTrip(TraceEntry(t: 1, line: line)).line == line, "\(line)") }
    #expect(lines.map(\.isStimulus) == [true, true, false, false, false, false])
    #expect(lines.map(\.isEvent) == [true, false, false, false, false, false])
    #expect(lines.map(\.isEffect) == [false, false, true, true, false, false])
    #expect(lines.map(\.description) == [
      "dragCancelled 7", "cheatSheetDismissed", "raise 7", "launchApp \"Safari\" is false", "windowsFrontToBack is [7, 8]", "frontmost is null",
    ])
  }

  @Test func aLineWithPartsMissingIsAnError() {
    #expect(throws: DecodingError.self) { try decodeEntry(#"{"event":"focused","id":7}"#) }
    #expect(throws: DecodingError.self) { try decodeEntry(#"{"t":1,"event":"focused"}"#) }
    #expect(throws: DecodingError.self) { try decodeEntry(#"{"t":1,"call":"setFrame","id":7,"frame":[1,2,3]}"#) }
  }

  @Test func geometryIsRoundedToHundredthsAndAlwaysFinite() throws {
    let thirds = TraceLine.showDropPreview(CGRect(x: 1.0 / 3, y: 2.0 / 3, width: 100.004, height: 100.006))
    #expect(try roundTrip(thirds) == .showDropPreview(CGRect(x: 0.33, y: 0.67, width: 100, height: 100.01)))
    // JSON cannot hold infinity, and a window system that answers with a null rectangle must not end the trace.
    #expect(try roundTrip(TraceLine.showDropPreview(.null)) == .showDropPreview(.zero))
    let nowhere = CGPoint(x: CGFloat.nan, y: -CGFloat.infinity)
    #expect(try roundTrip(TraceLine.cursorLocation(nowhere)) == .cursorLocation(.zero))
  }

  @Test func linesSayWhetherArborReactsToThemOrMadeThem() {
    #expect(TraceLine.focused(WindowID(1)).isStimulus)
    #expect(TraceLine.command("arrange").isStimulus)
    #expect(TraceLine.timer("save").isStimulus)
    #expect(!TraceLine.done("arrange", ok: true, message: "").isStimulus)
    #expect(!TraceLine.focus(WindowID(1)).isStimulus)
    #expect(TraceLine.focus(WindowID(1)).isEffect)
    #expect(TraceLine.showDropPreview(nil).isEffect)
    #expect(!TraceLine.cursorLocation(.zero).isEffect)
    #expect(TraceLine.setFrame(WindowID(3), .zero, result: nil, took: nil).window == WindowID(3))
    #expect(TraceLine.note("x").window == nil)
  }

  @Test func linesReadAsSentences() {
    let frame = CGRect(x: 12, y: 37, width: 702, height: 851)
    let refused = CGRect(x: 12, y: 37, width: 900.5, height: 851)
    #expect(TraceLine.setFrame(WindowID(7), frame, result: frame, took: nil).description == "setFrame w7 12,37 702×851 (taken)")
    #expect(
      TraceLine.setFrame(WindowID(7), frame, result: refused, took: 0.0141).description
        == "setFrame w7 12,37 702×851, took 12,37 900.5×851 in 14 ms")
    #expect(TraceLine.setFrame(WindowID(7), frame, result: nil, took: nil).description == "setFrame w7 12,37 702×851, no such window")
    #expect(TraceLine.dragEnded(WindowID(7), at: CGPoint(x: 3, y: 450)).description == "drag of w7 ended at 3,450")
  }
}

@Suite struct TitleTokenTests {
  @Test func theSameTitleAlwaysGetsTheSameTokenAndDifferentTitlesDifferentOnes() {
    var tokens = TitleTokens()
    let first = tokens.token(for: "Salary review.docx")
    let second = tokens.token(for: "Inbox (3)")
    #expect(first == "title[1]")
    #expect(second == "title[2]")
    #expect(tokens.token(for: "Salary review.docx") == first)
    #expect(tokens.token(for: "") == "")
  }

  @Test func rulesMatchTokensExactlyWhereTheyMatchedTitles() {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "com.apple.mail", title: "Inbox", action: .dock(.left)),
      AppRule(app: "com.apple.mail", title: "draft", action: .float),
      AppRule(app: "com.apple.mail", action: .ignore),
    ]
    var tokens = TitleTokens()
    let sanitised = tokens.sanitised(settings)
    #expect(sanitised.rules.map(\.title) == ["[p1]", "[p2]", nil])
    #expect(sanitised.rules.map(\.action) == settings.rules.map(\.action))
    for title in ["Inbox (3)", "INBOX", "My Draft", "A draft in the inbox", "Sent", ""] {
      let token = tokens.token(for: title)
      for (real, replayed) in zip(settings.rules, sanitised.rules) {
        #expect(
          real.matches(bundleID: "com.apple.mail", title: title)
            == replayed.matches(bundleID: "com.apple.mail", title: token), "\(title) against \(real)")
      }
      #expect(!token.lowercased().contains("inbox") && !token.lowercased().contains("draft"))
    }
  }

  @Test func theMarkOfOnePatternIsNeverPartOfAnothers() {
    var settings = Settings()
    settings.rules = (1...12).map { AppRule(app: "a.b", title: "pattern number \($0) ", action: .float) }
    var tokens = TitleTokens()
    let sanitised = tokens.sanitised(settings)
    let token = tokens.token(for: "pattern number 12 ")
    #expect(sanitised.rules.filter { $0.matches(bundleID: "a.b", title: token) }.count == 1)
    #expect(sanitised.rules[11].matches(bundleID: "a.b", title: token))
  }

  @Test func freeTextIsScrubbedOfTheTitlesSeenSoFar() {
    var tokens = TitleTokens()
    _ = tokens.token(for: "Salary review")
    _ = tokens.token(for: "Salary review 2026.docx")
    _ = tokens.token(for: "Mail")
    _ = tokens.token(for: "abc")
    _ = tokens.token(for: "title[1]")
    #expect(tokens.scrubbed("layout Pages~Salary review 2026.docx | Pages~Salary review") == "layout Pages~title[2] | Pages~title[1]")
    #expect(tokens.scrubbed("docked Mail beside abc") == "docked title[3] beside abc")
    #expect(tokens.scrubbed("docked Mail beside abc", keeping: ["Mail"]) == "docked Mail beside abc")
    #expect(tokens.scrubbed("nothing of the kind") == "nothing of the kind")
    // A title that looks like a token is left alone, or the tokens just put in would be replaced in their turn.
    #expect(tokens.scrubbed("title[1] title[1]") == "title[1] title[1]")
    #expect(tokens.scrubbed("") == "")
  }

  @Test func rulesWithTheSamePatternShareAMark() {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "a.b", title: "Inbox", action: .float), AppRule(app: "c.d", title: "inbox", action: .ignore),
    ]
    var tokens = TitleTokens()
    #expect(tokens.sanitised(settings).rules.map(\.title) == ["[p1]", "[p1]"])
  }
}

@Suite struct TraceCommandTests {
  @Test func traceCommandsParseAndPrint() throws {
    #expect(try Command.parse("trace on") == .trace(.on(name: nil)))
    #expect(try Command.parse("trace on Safari-drag_2") == .trace(.on(name: "Safari-drag_2")))
    #expect(try Command.parse("trace off") == .trace(.off))
    #expect(try Command.parse("trace status") == .trace(.status))
    #expect(try Command.parse("trace") == .trace(.status))
    #expect(try Command.parse("trace note Drag Safari to the edge") == .trace(.note("Drag Safari to the edge")))
    #expect(try Command.parse("trace/on/url-form") == .trace(.on(name: "url-form")))
    for text in ["trace on", "trace on Safari-drag_2", "trace off", "trace status", "trace note Drag it"] {
      #expect(try Command.parse(text).text == text)
    }
  }

  @Test func aTraceNameCannotLeaveTheTracesFolder() {
    for text in [
      "trace on a b", "trace on ~", "trace on a\\b", "trace on $HOME", "trace on é", "trace off now", "trace note",
      "trace on \(String(repeating: "x", count: 41))", "trace sideways",
    ] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
    #expect(!TraceCommand.isValidName(""))
    #expect(!TraceCommand.isValidName("a/b"))
  }

  @Test func aURLCannotStartOrStopARecording() {
    for command in [Command.trace(.on(name: nil)), .trace(.off), .trace(.status), .trace(.note("x"))] {
      #expect(!command.isAllowedFromURL)
    }
  }

  @Test func onlyTraceStatusIsAQuery() {
    #expect(Command.trace(.status).isQuery)
    #expect(!Command.trace(.on(name: nil)).isQuery)
    #expect(!Command.trace(.off).isQuery)
  }

  // MARK: The names of spaces

  @Test func namesBecomeTokensWhateverTheirCapitals() {
    var tokens = TitleTokens()
    #expect(tokens.nameToken(for: "Mail Room") == "name-1")
    #expect(tokens.nameToken(for: "Mail") == "name-2")
    #expect(tokens.nameToken(for: "MAIL ROOM") == "name-1")
    #expect(tokens.nameToken(for: "Mail") == "name-2")
    #expect((try? SpaceName.tidied("name-1")) == "name-1", "a token can be a name, as it is in a replay")
  }

  @Test func namesAreReplacedInTextWhereTheyStandAsWords() {
    var tokens = TitleTokens()
    #expect(tokens.withNameTokens("moved to Mail (n5)") == "moved to Mail (n5)", "nothing is known yet")
    for name in ["Mail", "Mail Room", "a", "name", "項目", "C++"] { _ = tokens.nameToken(for: name) }
    // The longest first, and every spelling that was seen, but no other.
    #expect(tokens.withNameTokens("moved to Mail Room (n5)") == "moved to name-2 (n5)")
    #expect(tokens.withNameTokens("Mail could be Mail or Mail Room; mail") == "name-1 could be name-1 or name-2; mail")
    // Not inside other words, or a space called "a" would leave nothing to read.
    #expect(tokens.withNameTokens("already showing a, a space; Mailbox, eMail") == "already showing name-3, name-3 space; Mailbox, eMail")
    // In one pass: a space called "name" takes no bite out of a token that has just been put in.
    #expect(tokens.withNameTokens("name and Mail") == "name-4 and name-1")
    #expect(tokens.withNameTokens("moved to 項目; no space is named C++") == "moved to name-5; no space is named name-6")
    #expect(tokens.withNameTokens("") == "")
  }

  /// Much of Arbor looks for a text anywhere in a title: rules, `holdStillFor`, `Safari~text` in a layout or a preset, Go to…. In a replay the
  /// tokens are the titles, so what asks for one window by its whole title must not get another: `title-1` was in `title-10`.
  @Test func noTokenIsContainedInAnother() {
    var tokens = TitleTokens()
    var settings = Settings()
    settings.rules = [AppRule(app: "a", title: "page 1", action: .float), AppRule(app: "a", title: "2", action: .float)]
    _ = tokens.sanitised(settings)
    let all = (1...130).map { tokens.token(for: "page \($0)") }
    #expect(Set(all).count == 130)
    for token in all {
      let within = all.filter { $0 != token && $0.contains(token) }
      #expect(within.isEmpty, "\(token) is in \(within.prefix(3))")
    }
  }

  @Test func partsOfTitlesAndTypedWordsAreReplacedAsWholeWordsAndNeverInsideAToken() {
    var tokens = TitleTokens()
    var settings = Settings()
    settings.rules = [AppRule(app: "a", title: "Title", action: .float), AppRule(app: "a", title: "pay", action: .float), AppRule(app: "a", title: "Pay rise", action: .float)]
    settings.displays = [DisplayOptions(match: .named("iPad"), gap: 1)]
    _ = tokens.sanitised(settings)
    tokens.notePartOfATitle("NAME")
    tokens.notePartOfATitle("name")
    tokens.notePartOfATitle("")
    // Tokens are made of ordinary words, which somebody may well have a rule for.
    #expect(tokens.withMarks("title[3] and title[31][p1][h2] have the title; name-4, a name; display-1[d1]") == "title[3] and title[31][p1][h2] have the [p1]; name-4, a [p4]; display-1[d1]")
    // As they were written before the number was closed in. And what only begins like a token is no token.
    #expect(tokens.withMarks("title-3 and title-31[p1][h2] have the title; title[x], title[3") == "title-3 and title-31[p1][h2] have the [p1]; [p1][x], [p1][3")
    // The longest first, whole words, whatever the capitals.
    #expect(tokens.withMarks("A PAY RISE, pay, Payment, repay; the IPAD, iPads") == "A [p3], [p2], Payment, repay; the [d1], iPads")
    // Not out of what is written with dots in it, a bundle id or a file's name. The full stop of a sentence is no such dot.
    #expect(tokens.withMarks("com.acme.pay, pay.acme.com, com.pay.acme, settings.pay; we pay. Pay.") == "com.acme.pay, pay.acme.com, com.pay.acme, settings.pay; we [p2]. [p2].")
    #expect(tokens.withMarks("") == "" && TitleTokens().withMarks("nothing known") == "nothing known")

    #expect(TitleTokens.words(in: "bind ctrl+opt+j go “Acme Merger” 7 w12") == ["bind", "ctrl", "opt", "j", "go", "acme", "merger", "w12"])
    #expect(TitleTokens.without(["acme", "title"], in: "ACME, Acme's acmes; title[3] of that title") == "…, …'s acmes; title[3] of that …")
    #expect(TitleTokens.without([], in: "as it is") == "as it is")
    // The backstop spares nothing: what was typed may well be a file's name.
    #expect(TitleTokens.without(["acme", "txt"], in: "no window called acme.txt, nor com.acme.app") == "no window called ….…, nor com.….app")
  }

  @Test func theNamesOfDisplaysBecomeStandInsThatTheSameEntriesMatch() throws {
    var tokens = TitleTokens()
    tokens.displayIDs = ["9b2f6c1e-4a7d-4f03-8e15-6d0a3c5b7e21"]
    var settings = Settings()
    settings.displays = [
      DisplayOptions(match: .named("iPad"), gap: 1), DisplayOptions(match: .named("Dell"), gap: 2),
      DisplayOptions(match: .named("9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21"), gap: 3), DisplayOptions(match: .main, gap: 4),
    ]
    let recorded = tokens.sanitised(settings)
    #expect(recorded.displays.map(\.match.text) == ["[d1]", "[d2]", "9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21", "main"])
    let names = ["Robin's iPad", "DELL U2720Q", "Dell on an iPad stand", "Studio Display", "Robin's iPad"]
    let standIns = names.map { tokens.displayToken(for: $0) }
    #expect(standIns == ["display-1[d1]", "display-2[d2]", "display-3[d1][d2]", "display-4", "display-1[d1]"])
    #expect(tokens.displayToken(for: nil) == "" && tokens.displayToken(for: "") == "")
    // Each recorded entry matches exactly the stand-ins of the names the real entry matched.
    for (real, shown) in zip(settings.displays, recorded.displays).prefix(2) {
      for (name, standIn) in zip(names, standIns) {
        func traits(_ name: String) -> DisplayTraits {
          DisplayTraits(id: DisplayID("x"), name: name, isMain: false, isBuiltIn: false, size: CGSize(width: 100, height: 100))
        }
        #expect(real.match.matches(traits(name)) == shown.match.matches(traits(standIn)), "\(real.match.text) \(name)")
      }
    }
    #expect(tokens.withNameTokens("gap = 50; Robin's iPad keeps 1, DELL U2720Q keeps 2") == "gap = 50; display-1[d1] keeps 1, display-2[d2] keeps 2")
  }

  @Test func theCommandsOfPeoplesOwnShortcutsLoseTheirWords() {
    var tokens = TitleTokens()
    _ = tokens.nameToken(for: "Clients")
    var settings = Settings()
    settings.bindings = [
      "ctrl+opt+1": "go clients", "ctrl+opt+2": "name Secret", "ctrl+opt+3": "unname Secret", "ctrl+opt+4": "layout Mail~Payslip | Notes",
      "ctrl+opt+5": "dock left", "ctrl+opt+6": nil, "ctrl+opt+7": "goo Clients of mine", "ctrl+opt+8": "unname", "ctrl+opt+9": "nonsense",
    ]
    #expect(
      tokens.sanitisedBindings(settings).bindings == [
        "ctrl+opt+1": "go name-1", "ctrl+opt+2": "name name-2", "ctrl+opt+3": "unname name-2", "ctrl+opt+4": "layout Mail | Notes",
        // What cannot be read keeps its first word only if that is a verb of Arbor's: a slip can put anybody's word first, or alone.
        "ctrl+opt+5": "dock left", "ctrl+opt+6": nil, "ctrl+opt+7": "…", "ctrl+opt+8": "unname", "ctrl+opt+9": "…",
      ])
  }
}

/// A recording holds every setting its build knew. What came later is missing, and means what that build did.
@Suite struct RecordedSettingsTests {
  private func header(settings: String?) throws -> TraceHeader {
    let text = #"{"trace":1,"displays":[{"id":"main","frame":[0,0,1440,900],"visible":[0,25,1440,875],"main":true}]"# + (settings.map { #","settings":\#($0)"# } ?? "") + "}"
    return try JSONDecoder().decode(TraceHeader.self, from: Data(text.utf8))
  }

  @Test func aRecordingFromBeforeTheKeyReplaysWithPlainDragsDocking() throws {
    #expect(try header(settings: #"{"gap":8}"#).settings.dragDocks == "always")
    #expect(try header(settings: #"{"gap":8}"#).settings.gap == 8)
    #expect(try header(settings: #"{"gap":8,"dragDocks":"held"}"#).settings.dragDocks == "held")
    #expect(try header(settings: #"{"dragDocks":"never"}"#).settings.dragDocks == "never")
    // Written by hand, without settings: Arbor as it ships.
    #expect(try header(settings: nil).settings == Settings())
  }

  @Test func whatIsRecordedNowSaysWhichWayItWas() throws {
    var header = try header(settings: nil)
    header.settings.dragDocks = "held"
    #expect(try JSONDecoder().decode(TraceHeader.self, from: JSONEncoder().encode(header)).settings.dragDocks == "held")
  }
}
