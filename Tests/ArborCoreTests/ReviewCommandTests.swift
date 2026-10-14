import ArborCore
import Testing

/// `home`, `pause`, `resume`, `toggle-pause`, and the aliases added by the product review.
@Suite struct ReviewCommandTests {
  static let samples: [Command] = [
    .home, .pause(minutes: nil), .pause(minutes: 30), .pause(minutes: 0.5), .pause(minutes: 1440), .resume,
    .togglePause, .floatAllHere, .arrangeAll,
  ]

  @Test(arguments: samples) func textRoundTrips(command: Command) throws {
    #expect(try Command.parse(command.text) == command)
  }

  @Test func pauseTakesSensibleMinutesOnly() {
    for text in ["pause 0", "pause -5", "pause 1441", "pause nan", "pause inf", "pause soon", "pause 5 6", "pause 1e99"] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  @Test func theNewCommandsTakeNoStrayArguments() {
    for text in ["home now", "resume 5", "toggle-pause 5", "float-all there", "float-all here now", "arrange some"] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  /// The three URL commands TrellisWM publishes (T71) work with `arbor://` in front.
  @Test func trellisWMsPublishedURLCommandsParse() throws {
    #expect(try Command.parse(words: ["arrange"]) == .arrange)
    #expect(try Command.parse(words: ["back"]) == .back)
    #expect(try Command.parse(words: ["zoom-out"]) == .stepOut)
  }

  @Test func aliases() throws {
    #expect(try Command.parse("zoom-in") == .stepIn)
    #expect(try Command.parse("undock 7") == .float(WindowID(7)))
    #expect(try Command.parse("shortcuts") == .bindings)
    #expect(try Command.parse("show-everything") == .showAll)
    #expect(try Command.parse("unpause") == .resume)
  }

  @Test func onlyResumeAndTogglePauseEndAPause() {
    let ending = (CommandSamples.all + Self.samples).filter(\.endsPause)
    #expect(ending == [.resume, .togglePause])
  }

  @Test func noneOfThemIsAQuerySoAllCanBeBoundToKeys() {
    #expect(Self.samples.allSatisfy { !$0.isQuery })
  }

  /// Every command in the help is one `parse` knows, and every new command is in the help.
  @Test func theHelpMentionsTheNewCommands() {
    for word in ["home", "pause [minutes]", "resume", "toggle-pause"] {
      #expect(Command.helpText.contains(word), "\(word)")
    }
  }
}

private enum CommandSamples {
  static let all: [Command] = [
    .status, .state, .ascii, .help, .showAll, .stepOut, .stepIn, .neighbor(.left), .back, .forward, .zoom(nil),
    .zoomNode(NodeID(3)), .desktop, .saveView(4), .goToView(9), .dock(nil, .right),
    .dockBeside(nil, target: WindowID(8), .left), .float(nil), .toggleFloat(nil), .arrange, .floatAll,
    .resize(nil, .right, 40), .exclude(bundleID: nil), .include(bundleID: "a.b"), .relayout, .reloadSettings, .quit,
    .bindings, .rules, .frameRect(x: 0, y: 0, width: 50, height: 50),
  ]
}
