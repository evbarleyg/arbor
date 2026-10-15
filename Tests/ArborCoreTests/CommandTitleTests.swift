import ArborCore
import Testing

/// What people call a command, and the part of the help it belongs to (docs/features/F43-say-what-happened.md).
@Suite struct CommandTitleTests {
  @Test func titlesUseTheGlossarysWords() {
    #expect(Command.showAll.title == "Show Everything")
    #expect(Command.home.title == "Show Everything on All Displays", "docs/MENU.md, row 1")
    #expect(Command.desktop.title == "Show the Desktop", "docs/MENU.md, row 2")
    #expect(Command.dock(nil, .left).title == "Dock Left")
    #expect(Command.saveView(3).title == "Save View 3")
    #expect(Command.zoom(nil).title == "Frame Focused Window")
    #expect(Command.neighbor(.top).title == "Space Above")
    #expect(Command.togglePause.title == "Pause or Resume Arbor")
    #expect(Command.pause(minutes: 1).title == "Pause Arbor for 1 Minute")
    #expect(Command.pause(minutes: 2.5).title == "Pause Arbor for 2.5 Minutes")
    #expect(Command.resize(nil, .right, -40).title == "Shrink Right")
    #expect(Command.exclude(bundleID: nil).title == "Don’t Arrange This App")
  }

  @Test func soDoTheTitlesOfNamesSummonAndLayout() throws {
    #expect(Command.askName(cancel: false).title == "Name This Space", "docs/MENU.md, Saved Views")
    #expect(Command.name("Work").title == "Name This Space “Work”")
    #expect(Command.unname(nil).title == "Remove This Space’s Name")
    #expect(Command.unname("Work").title == "Remove the Name “Work”")
    #expect(Command.goToSpace("the den").title == "Go to “the den”", "a name keeps its spelling")
    #expect(Command.summon(app: "Notes").title == "Summon Notes")
    #expect(Command.summon(app: "com.apple.Notes").title == "Summon com.apple.Notes")
    #expect(try Command.parse("layout Safari | (Mail / Notes)").title == "Arrange as Safari | (Mail / Notes)")
    #expect(try Command.parse("layout --open Safari | Mail").title == "Open and Arrange as Safari | Mail")
    #expect(Command.checkForUpdates.title == "Check for Updates", "docs/MENU.md, Help")
    #expect(Command.launchAtLogin(true).title == "Open at Login", "macOS's own words")
    #expect(Command.launchAtLogin(false).title == "Don’t Open at Login")
    #expect(Command.toggleAutoDock.title == "Dock New Windows", "docs/MENU.md, row 23")
    #expect(Command.hold(minutes: nil).title == "Hold This View", "docs/MENU.md, row 25")
    #expect(Command.holdStill(minutes: 30).title == "Hold Still", "docs/MENU.md, row 26")
    #expect(Command.release.title == "Release the View")
    #expect(Command.find(nil).title == "Go to…", "docs/MENU.md, row 8, dots and all")
  }

  @Test func anArrangementsTitleLeavesOutThePartsOfWindowTitles() throws {
    let command = try Command.parse(#"layout Safari~"Secret plans" | Mail"#)
    #expect(command.text.contains("Secret"), "or this proves nothing")
    #expect(!command.title.contains("Secret"), "\(command.title)")
    #expect(command.title.hasPrefix("Arrange as Safari"))
  }

  @Test func aCommandNobodyNamedGetsItsTextInTitleCase() {
    #expect(Command.reloadSettings.title == "Reload Settings")
    #expect(Command.reloadSettings.listedTitle == nil)
    #expect(Command.status.title == "Status")
  }

  @Test func noTitleUsesAWordTheGlossaryRulesOut() throws {
    let commands = try [
      "show-all", "home", "out", "in", "neighbor left", "back", "forward", "zoom", "zoom 5", "zoom-node 3", "desktop", "save-view 1",
      "view 1", "frame-rect 0 0 9 9", "dock left", "dock beside 5 left", "float", "toggle-float", "arrange", "arrange all",
      "float-all", "float-all here", "resize left 10", "exclude", "include a.b", "relayout", "reload-settings", "quit", "pause",
      "resume", "toggle-pause", "show-shortcuts", "ask-name", "ask-name cancel", "name a", "unname", "unname a", "go a", "summon a",
      "layout a | b", "layout --open a", "check-setup", "welcome", "check-for-updates", "launch-at-login on", "launch-at-login off",
    ].map { try Command.parse($0) }
    for command in commands {
      let words = command.title.lowercased().split(separator: " ").map(String.init)
      for banned in ["tile", "snap", "hotkey", "hotkeys", "screen", "monitor", "node", "camera", "parked", "hidden", "stack", "maximize"] {
        #expect(!words.contains(banned), "\(command.text): \(command.title)")
      }
    }
  }

  @Test func groupsAreTheHelps() {
    let look: [Command] = [
      .showAll, .home, .stepOut, .stepIn, .neighbor(.left), .back, .forward, .zoom(nil), .zoomNode(NodeID(1)), .desktop,
      .saveView(1), .goToView(1), .frameRect(x: 0, y: 0, width: 1, height: 1),
    ]
    let arrange: [Command] = [
      .dock(nil, .left), .dockBeside(nil, target: WindowID(1), .left), .float(nil), .toggleFloat(nil), .arrange, .arrangeAll,
      .floatAll, .floatAllHere, .resize(nil, .left, 1),
    ]
    let arbor: [Command] = [
      .pause(minutes: nil), .resume, .togglePause, .exclude(bundleID: nil), .include(bundleID: "a"), .relayout, .reloadSettings,
      .quit, .status, .state(titles: false), .ascii, .help, .bindings, .rules, .showShortcuts, .passThrough(bundleID: nil),
    ]
    for command in look { #expect(command.group == .look, "\(command.text)") }
    for command in arrange { #expect(command.group == .arrange, "\(command.text)") }
    for command in arbor { #expect(command.group == .arbor, "\(command.text)") }
    for command in look + arrange + arbor { #expect(command.helpOrder < Int.max, "`\(command.verb)` is missing from the help") }
  }

  @Test func theHelpsOrderIsKept() {
    let order: [Command] = [.showAll, .home, .stepOut, .stepIn, .neighbor(.left), .back, .forward, .zoom(nil), .desktop]
    #expect(order.map(\.helpOrder) == order.map(\.helpOrder).sorted())
    #expect(Set(order.map(\.helpOrder)).count == order.count, "two commands on one line of the help still have an order")
  }

  @Test func showShortcutsIsACommandLikeAnyOther() throws {
    #expect(try Command.parse("show-shortcuts") == .showShortcuts)
    #expect(try Command.parse(Command.showShortcuts.text) == .showShortcuts)
    #expect(throws: Command.ParseError.self) { try Command.parse("show-shortcuts now") }
    #expect(!Command.showShortcuts.isQuery, "a query cannot be bound to keys")
    #expect(!Command.showShortcuts.isAllowedFromURL, "a web page has no business covering the screen")
    #expect(Command.helpText.contains("show-shortcuts"))
  }
}
