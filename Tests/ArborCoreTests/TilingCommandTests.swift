import ArborCore
import Foundation
import Testing

/// F22: the text forms of the keyboard tiling commands.
@Suite struct TilingCommandTests {
  static let samples: [Command] = [
    .focus(.direction(.left)), .focus(.direction(.right)), .focus(.direction(.top)), .focus(.direction(.bottom)),
    .focus(.next), .focus(.previous), .focus(.window(WindowID(412))),
    .swap(nil, .left), .swap(nil, .top), .swap(WindowID(7), .bottom), .swapWindows(WindowID(7), WindowID(8)),
    .equalize(all: false), .equalize(all: true), .rotate, .mirror,
    .grow(nil), .grow(40), .grow(12.5), .grow(1_000_000), .shrink(nil), .shrink(25), .shrink(0.5),
    .moveToDisplay(.next, nil), .moveToDisplay(.previous, WindowID(9)), .moveToDisplay(.number(2), nil),
    .moveToDisplay(.number(1), WindowID(9)), .focusDisplay(.next), .focusDisplay(.previous), .focusDisplay(.number(3)),
  ]

  @Test(arguments: samples) func tilingCommandsRoundTripThroughTheirText(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
    #expect(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(command)) == command)
    #expect(!command.isQuery, "a shortcut can be bound to it")
    #expect(!command.endsPause)
  }

  /// They arrange windows or step to a neighbour. But a web page must not decide where the keyboard types.
  @Test(arguments: samples) func aURLMayRunAllButTheOnesThatPickWhereTheKeyboardGoes(command: Command) {
    switch command {
    case .focus(.window), .focusDisplay, .moveToDisplay: #expect(!command.isAllowedFromURL)
    // It focuses the window it names.
    case .swap(.some, _): #expect(!command.isAllowedFromURL)
    default: #expect(command.isAllowedFromURL)
    }
  }

  @Test func theCanonicalTextIsWhatTheHelpShows() {
    #expect(Command.focus(.direction(.top)).text == "focus up")
    #expect(Command.focus(.direction(.bottom)).text == "focus down")
    #expect(Command.focus(.window(WindowID(412))).text == "focus 412")
    #expect(Command.swap(WindowID(7), .bottom).text == "swap 7 down")
    #expect(Command.swapWindows(WindowID(7), WindowID(8)).text == "swap 7 8")
    #expect(Command.equalize(all: false).text == "balance" && Command.equalize(all: true).text == "balance all")
    #expect(Command.grow(nil).text == "grow")
    #expect(Command.grow(40).text == "grow 40")
    #expect(Command.shrink(12.5).text == "shrink 12.5")
    #expect(Command.moveToDisplay(.number(2), WindowID(9)).text == "move-to-display 2 9")
    #expect(Command.focusDisplay(.previous).text == "focus-display previous")
  }

  @Test func tilingAliasesCaseAndURLPathsAreAccepted() throws {
    #expect(try Command.parse("focus top") == .focus(.direction(.top)))
    #expect(try Command.parse("focus l") == .focus(.direction(.left)))
    #expect(try Command.parse("Focus/Left") == .focus(.direction(.left)))
    #expect(try Command.parse("focus prev") == .focus(.previous))
    #expect(try Command.parse("focus w412") == .focus(.window(WindowID(412))))
    #expect(try Command.parse("swap w7 up") == .swap(WindowID(7), .top))
    #expect(try Command.parse("swap/7/w8") == .swapWindows(WindowID(7), WindowID(8)))
    #expect(try Command.parse("equalize") == .equalize(all: false))
    #expect(try Command.parse("equalize all") == .equalize(all: true))
    #expect(try Command.parse("grow/40") == .grow(40))
    #expect(try Command.parse("move-to-display prev w9") == .moveToDisplay(.previous, WindowID(9)))
    #expect(try Command.parse("focus-display/2") == .focusDisplay(.number(2)))
    #expect(try Command.parse(url: "arbor://focus/left") == .focus(.direction(.left)))
    #expect(try Command.parse(url: "arbor://move-to-display/next/412") == .moveToDisplay(.next, WindowID(412)))
  }

  @Test func badTilingCommandsAreRejectedWithTheUsage() {
    let bad = [
      // Since F50 a word where a window belongs is an app's name (`focus Safari`, `swap Safari Mail`). A number gone wrong is not.
      "focus", "focus 1.5", "focus left right", "focus -1", "focus next now",
      "swap", "swap sideways", "swap 7", "swap 7 8 9", "swap left 7", "swap 7.5 8", "swap 7 -8", "swap 7 4294967296",
      "balance everything", "balance all now", "equalize everything", "rotate left", "mirror now",
      "grow 0", "grow -40", "grow nan", "grow inf", "grow 1e300", "grow 1000001", "grow forty", "grow 40 40",
      "shrink 0", "shrink -1", "shrink nan", "shrink 1e300", "shrink 4 4",
      "move-to-display", "move-to-display sideways", "move-to-display 0", "move-to-display -1", "move-to-display 100",
      "move-to-display 99999999999999999999", "move-to-display next 9.5", "move-to-display next 9 9",
      "focus-display", "focus-display 0", "focus-display 1.5", "focus-display next 2",
    ]
    for text in bad {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
    let error = #expect(throws: Command.ParseError.self) { try Command.parse("grow 1e300") }
    #expect(error?.description == "usage: grow [points] (a positive number, at most 1000000)")
  }

  @Test func everyTilingCommandIsInTheHelp() {
    for line in [
      "focus <direction>", "focus next | focus previous", "focus <window>", "swap [window] <direction>",
      "swap <window> <window>", "grow [points] | shrink [points]", "balance [all]", "rotate | mirror",
      "move-to-display <next|previous|n> [window]", "focus-display <next|previous|n>",
    ] {
      #expect(Command.helpText.contains("  \(line) "), "\(line)")
    }
  }

  @Test func directionWordsReadBackAsTheSameEdge() {
    for edge in Edge.allCases {
      #expect(Edge(word: edge.directionWord) == edge)
    }
  }

  @Test func displayTargetsCountFromOneAndWrapAround() {
    #expect(DisplayTarget.next.index(from: 0, count: 3) == 1)
    #expect(DisplayTarget.next.index(from: 2, count: 3) == 0)
    #expect(DisplayTarget.previous.index(from: 0, count: 3) == 2)
    #expect(DisplayTarget.previous.index(from: 2, count: 3) == 1)
    #expect(DisplayTarget.next.index(from: 0, count: 1) == 0)
    #expect(DisplayTarget.number(1).index(from: 2, count: 3) == 0)
    #expect(DisplayTarget.number(3).index(from: nil, count: 3) == 2)
    #expect(DisplayTarget.number(4).index(from: 0, count: 3) == nil)
    #expect(DisplayTarget.number(0).index(from: 0, count: 3) == nil)
    #expect(DisplayTarget.number(-2).index(from: 0, count: 3) == nil)
    // Not knowing where one is: the first going forward, the last going back.
    #expect(DisplayTarget.next.index(from: nil, count: 3) == 0)
    #expect(DisplayTarget.previous.index(from: nil, count: 3) == 2)
    #expect(DisplayTarget.next.index(from: 7, count: 3) == 0)
    for target in [DisplayTarget.next, .previous, .number(1)] {
      #expect(target.index(from: 0, count: 0) == nil)
    }
  }

  @Test func oldSettingsFilesGetTheDefaultResizeStep() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8))
    #expect(old.resizeStep == 40)
    let edited = try JSONDecoder().decode(Settings.self, from: Data(#"{"resizeStep": 64}"#.utf8))
    #expect(edited.resizeStep == 64)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(edited)) == edited)
  }
}
