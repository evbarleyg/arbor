import ArborCore
import Testing

/// `arbor://` URLs: what they parse to, and which commands they may run.
@Suite struct CommandURLTests {
  @Test func parsesTheFormsPeopleWrite() throws {
    #expect(try Command.parse(url: "arbor://dock/left") == .dock(nil, .left))
    #expect(try Command.parse(url: "arbor://show-all") == .showAll)
    #expect(try Command.parse(url: "arbor://show-all/") == .showAll)
    #expect(try Command.parse(url: "arbor:view/2") == .goToView(2))
    #expect(try Command.parse(url: "arbor:///zoom/412") == .zoom(WindowID(412)))
    #expect(try Command.parse(url: "ARBOR://Arrange") == .arrange)
    #expect(try Command.parse(url: "arbor://frame-rect/0/25/720/875") == .frameRect(x: 0, y: 25, width: 720, height: 875))
    #expect(try Command.parse(url: "arbor://dock/412/beside/388/bottom") == .dockBeside(WindowID(412), target: WindowID(388), .bottom))
    #expect(try Command.parse(url: "arbor://exclude/com.Apple.Music") == .exclude(bundleID: "com.Apple.Music"))
  }

  @Test func ignoresQueriesAndFragments() throws {
    #expect(try Command.parse(url: "arbor://back?source=raycast") == .back)
    #expect(try Command.parse(url: "arbor://dock/left#x/quit") == .dock(nil, .left))
    #expect(try Command.parse(url: "arbor://back?/quit") == .back)
  }

  @Test func decodesEscapesExactlyOnce() throws {
    #expect(try Command.parse(url: "arbor://%64ock/l%65ft") == .dock(nil, .left))
    // Decoded twice, `%252e` would be a full stop, and this a bundle id.
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://exclude/a%252eb") }
  }

  @Test(arguments: [
    "", "arbor", "arbor:", "arbor://", "http://dock/left", "arbors://dock/left", " arbor://back", "//dock/left",
    "arbor://teleport", "arbor://dock", "arbor://dock/left/now/please",
    // One word per segment: nothing may smuggle in further words, lines or paths.
    "arbor://dock%20left", "arbor://dock left", "arbor://exclude/a%0Ab", "arbor://exclude/a%0D", "arbor://exclude/a%00",
    "arbor://exclude/a%2Fb", "arbor://exclude/a%09b", "arbor://exclude/%E2%80%AEevil", "arbor://exclude/%1B[31m",
    "arbor://exclude/a%C2%A0b", "arbor://exclude/a%E2%80%A8b",
    // Escapes that are cut short, not hexadecimal, or not UTF-8. A dropped word would turn
    // `exclude <app>` into `exclude`, which acts on the focused app.
    "arbor://exclude/100%", "arbor://exclude/%4", "arbor://exclude/%zz", "arbor://exclude/%FF", "arbor://exclude/%C3%28",
    // Someone else's idea of a URL.
    "arbor://user:password@dock/left", "arbor://dock:80/left", "arbor:\\\\dock\\left",
  ]) func refuses(url: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(url: url) }
  }

  @Test func refusesVeryLongURLs() {
    let long = "arbor://exclude/" + String(repeating: "a", count: 2000)
    #expect(throws: Command.ParseError.self) { try Command.parse(url: long) }
    #expect(throws: Command.ParseError.self) { try Command.parse(url: "arbor://" + String(repeating: "/", count: 100_000)) }
  }

  // MARK: Policy

  static let allowed: [Command] = [
    .showAll, .stepOut, .stepIn, .neighbor(.left), .back, .forward, .zoom(nil), .zoom(WindowID(4)), .zoomNode(NodeID(3)),
    .desktop, .saveView(1), .goToView(1), .frameRect(x: 0, y: 0, width: 10, height: 10), .dock(nil, .left),
    .dock(WindowID(4), .left), .dockBeside(nil, target: WindowID(4), .top), .float(nil), .toggleFloat(nil), .arrange,
    .resize(nil, .left, 20), .relayout, .home, .arrangeAll, .undo, .redo,
  ]

  static let refused: [Command] = [
    .quit, .exclude(bundleID: nil), .exclude(bundleID: "com.apple.Safari"), .include(bundleID: "com.apple.Safari"),
    .floatAll, .reloadSettings, .status, .state(titles: false), .state(titles: true), .ascii, .help, .bindings, .rules,
    .pause(minutes: nil), .pause(minutes: 5), .resume, .togglePause, .floatAllHere,
  ]

  @Test(arguments: allowed) func cameraAndArrangementCommandsAreAllowedFromURLs(command: Command) {
    #expect(command.isAllowedFromURL)
  }

  @Test(arguments: refused) func everythingElseIsRefusedFromURLs(command: Command) {
    #expect(!command.isAllowedFromURL)
  }

  /// T71: the URL commands TrellisWM publishes are "arrange, back, forward, zoom and more".
  @Test(arguments: ["arrange", "back", "forward", "zoom", "zoom-out", "zoom-in", "out", "in", "show-all", "desktop"])
  func theURLCommandsTrellisWMPublishesWork(verb: String) throws {
    #expect(try Command.parse(url: "arbor://\(verb)").isAllowedFromURL)
  }
}
