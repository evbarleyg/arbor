import ArborCore
import Foundation
import Testing

/// The words of F58 (docs/features/F58-hold-the-view.md): commands, what a held view lets through, and `holdStillFor`.
@Suite struct HoldCommandTests {
  static let samples: [Command] = [
    .hold(minutes: nil), .hold(minutes: 45), .hold(minutes: 0.5), .holdStill(minutes: nil), .holdStill(minutes: 90),
    .release, .toggleHold,
  ]

  @Test(arguments: samples) func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test func theWords() throws {
    #expect(try Command.parse("hold") == .hold(minutes: nil))
    #expect(try Command.parse("hold 30") == .hold(minutes: 30))
    #expect(try Command.parse("hold still") == .holdStill(minutes: nil))
    #expect(try Command.parse("Hold Still 30") == .holdStill(minutes: 30))
    #expect(try Command.parse("release") == .release)
    #expect(try Command.parse("toggle-hold") == .toggleHold)
  }

  @Test(arguments: [
    "hold 0", "hold -5", "hold 1441", "hold nan", "hold inf", "hold 5 5", "hold on", "hold still still", "hold still 0",
    "hold 5 still", "release now", "toggle-hold 5",
  ])
  func nonsenseIsRefused(text: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(text) }
  }

  @Test func noneIsAQuerySoAllCanBeBoundToKeys() {
    for command in Self.samples { #expect(!command.isQuery, "\(command.text)") }
  }

  /// A page that could hold the view would make Arbor look dead; one that could release it would show an
  /// audience what the hold was keeping from them.
  @Test func noneIsAcceptedFromURLs() {
    for command in Self.samples { #expect(!command.isAllowedFromURL, "\(command.text)") }
  }

  @Test func noneEndsAPause() {
    for command in Self.samples { #expect(!command.endsPause, "\(command.text)") }
  }

  @Test func noDefaultShortcutIsNeededAndTheHelpExplainsThem() {
    for word in ["hold [minutes]", "release", "toggle-hold", "hold still [minutes]"] {
      #expect(Command.helpText.contains(word), "\(word)")
    }
  }

  // MARK: What a held view lets through

  @Test(arguments: [
    "show-all", "home", "out", "in", "neighbor left", "back", "forward", "zoom", "zoom 101", "zoom-node 3", "desktop",
    "view 1", "frame-rect 0 0 500 500", "arrange", "arrange all",
    // These can bring windows that are out of view back into it, or resize everything.
    "exclude com.apple.mail", "include com.apple.mail", "reload-settings",
    // It comes into another display's view.
    "move-to-display next",
  ])
  func whatMovesTheViewIsRefused(text: String) throws {
    #expect(try !Command.parse(text).isAllowedWhileHeld)
  }

  @Test(arguments: [
    "status", "state", "ascii", "help", "bindings", "rules", "hold", "hold still", "release", "toggle-hold", "pause",
    "pause 5", "resume", "toggle-pause", "float-all", "float-all here", "quit", "dock left", "dock 101 beside 102 left",
    "float", "toggle-float", "resize right 20", "relayout", "save-view 1",
    "focus left", "focus next", "focus 101", "focus-display next", "swap left", "swap 101 102", "grow", "shrink 20", "balance", "rotate", "mirror",
  ])
  func queriesWaysOutAndRearrangingWhatIsInViewAreLetThrough(text: String) throws {
    #expect(try Command.parse(text).isAllowedWhileHeld)
  }

  @Test func theWindowsACommandArranges() throws {
    #expect(try Command.parse("dock left").arrangedWindows == [nil])
    #expect(try Command.parse("dock 101 beside 102 left").arrangedWindows == [WindowID(101), WindowID(102)])
    #expect(try Command.parse("float 101").arrangedWindows == [WindowID(101)])
    #expect(try Command.parse("resize 101 left 5").arrangedWindows == [WindowID(101)])
    #expect(try Command.parse("relayout").arrangedWindows.isEmpty)
    #expect(try Command.parse("focus 101").arrangedWindows == [WindowID(101)])
    #expect(try Command.parse("focus left").arrangedWindows.isEmpty)
    #expect(try Command.parse("swap 101 102").arrangedWindows == [WindowID(101), WindowID(102)])
    #expect(try Command.parse("swap left").arrangedWindows == [nil])
    for text in ["grow", "shrink", "rotate", "mirror"] { #expect(try Command.parse(text).arrangedWindows == [nil], "\(text)") }
    #expect(try Command.parse("float").takesAWindowOutOfItsPlace)
    #expect(try !Command.parse("resize left 5").takesAWindowOutOfItsPlace)
  }

  // MARK: holdStillFor

  @Test func anEntryIsABundleIDAndPerhapsPartOfATitle() {
    #expect(HoldPattern("com.apple.FaceTime") == HoldPattern("  com.apple.FaceTime  "))
    #expect(HoldPattern("com.apple.FaceTime").title == nil)
    let zoom = HoldPattern("us.zoom.xos Zoom Meeting")
    #expect(zoom.app == "us.zoom.xos")
    #expect(zoom.title == "Zoom Meeting")
    #expect(zoom.matches(bundleID: "us.zoom.xos", title: "Zoom Meeting"))
    #expect(zoom.matches(bundleID: "us.zoom.xos", title: "zoom meeting 40 minutes"))
    #expect(!zoom.matches(bundleID: "us.zoom.xos", title: "Zoom Workplace"))
    #expect(!zoom.matches(bundleID: "us.zoom.xos.other", title: "Zoom Meeting"))
    #expect(!zoom.matches(bundleID: nil, title: "Zoom Meeting"))
    #expect(HoldPattern("com.apple.FaceTime").matches(bundleID: "com.apple.FaceTime", title: ""))
  }

  @Test func anEmptyEntryMatchesNothing() {
    for text in ["", "   "] {
      #expect(!HoldPattern(text).matches(bundleID: "", title: ""))
      #expect(!HoldPattern(text).matches(bundleID: nil, title: "anything"))
    }
  }

  @Test func oldSettingsFilesLoadAndTheListCanBeEmptied() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(old.holdStillFor.isEmpty, "out of the box Arbor holds only when asked")
    let emptied = try JSONDecoder().decode(Settings.self, from: Data(#"{"holdStillFor": []}"#.utf8))
    #expect(emptied.holdStillFor.isEmpty)
    #expect(!old.holdStillWhileCameraIsOn, "a sensor nobody has seen at work on a Mac starts nothing by itself")
    #expect(!old.holdStillWhileMicrophoneIsOn, "until it has been seen on a Mac what else keeps a microphone on")
    var mine = Settings()
    mine.holdStillFor = ["com.google.Chrome Meet"]
    mine.holdStillWhileMicrophoneIsOn = true
    mine.holdStillWhileCameraIsOn = true
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(mine)) == mine)
  }

  /// Titles are never logged, nor parts of them, nor the names people give.
  @Test func whatIsRefusedIsLoggedWithoutThePersonsOwnWords() throws {
    #expect(try Command.parse("rule add com.apple.mail dock left title Salary review").textWhenRefused == "rule")
    #expect(try Command.parse("set gap 40").textWhenRefused == "set")
    #expect(try Command.parse("go Salary review").textWhenRefused == "go ‹name›")
    #expect(try Command.parse("find salary").textWhenRefused == "find …")
    #expect(try Command.parse("show-all").textWhenRefused == "show-all")
  }

  /// A trace holds no titles, nor parts of them, and a call recognised by its window's title must still replay.
  @Test func aTraceHoldsAMarkInsteadOfTheTitleTextOfHoldStillFor() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.apple.mail", title: "Inbox", action: .dock(.left))]
    settings.holdStillFor = ["us.zoom.xos Zoom Meeting", "com.apple.FaceTime", "com.google.Chrome Meet"]
    var tokens = TitleTokens()
    let recorded = tokens.sanitised(settings)
    #expect(recorded.rules[0].title == "[p1]", "rules are numbered as before")
    #expect(recorded.holdStillFor == ["us.zoom.xos [h1]", "com.apple.FaceTime", "com.google.Chrome [h2]"])

    let call = tokens.token(for: "Zoom Meeting 40 minutes")
    #expect(!call.lowercased().contains("zoom"))
    let patterns = recorded.holdStillFor.map(HoldPattern.init)
    #expect(patterns[0].matches(bundleID: "us.zoom.xos", title: call), "the replayed entry matches the windows the real one matched")
    #expect(!patterns[0].matches(bundleID: "us.zoom.xos", title: tokens.token(for: "Zoom Workplace")), "and no others")
    #expect(patterns[2].matches(bundleID: "com.google.Chrome", title: call), "there is a Meet in Meeting, for the real one too")
    #expect(!patterns[2].matches(bundleID: "com.google.Chrome", title: tokens.token(for: "Inbox")))
  }

  @Test func stateSaysHowTheViewIsHeldAndOldRepliesStillDecode() throws {
    var state = StateSnapshot(accessibility: true, running: true, focused: nil, displays: [], windows: [])
    #expect(!String(decoding: try JSONEncoder().encode(state), as: UTF8.self).contains("held"))
    state.held = .view
    let data = try JSONEncoder().encode(state)
    #expect(String(decoding: data, as: UTF8.self).contains(#""held":"view""#))
    #expect(try JSONDecoder().decode(StateSnapshot.self, from: data).held == .view)
  }
}
