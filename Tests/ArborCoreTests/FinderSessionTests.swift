import ArborCore
import CoreGraphics
import Testing

@Suite struct FinderSelectionTests {
  @Test func startsAtTheTop() {
    let selection = FinderSelection(count: 20)
    #expect(selection.selected == 0)
    #expect(selection.visible == 0..<9)
    #expect(selection.pageSize == 9)
  }

  @Test func anEmptyListHasNoSelection() {
    var selection = FinderSelection(count: 0)
    #expect(selection.selected == nil)
    #expect(selection.visible.isEmpty)
    selection.move(by: 1)
    selection.move(by: -1)
    selection.page(by: 1)
    selection.select(5)
    #expect(selection.selected == nil)
    #expect(selection.visible.isEmpty)
    #expect(selection.row(atVisible: 0) == nil)
  }

  @Test func movingGoesRoundAtBothEnds() {
    var selection = FinderSelection(count: 3)
    selection.move(by: 1)
    selection.move(by: 1)
    #expect(selection.selected == 2)
    selection.move(by: 1)
    #expect(selection.selected == 0)
    selection.move(by: -1)
    #expect(selection.selected == 2)
    selection.move(by: 7)
    #expect(selection.selected == 0, "2 + 7 = 9, three times round")
    selection.move(by: -7)
    #expect(selection.selected == 2)
  }

  @Test func theListScrollsJustFarEnoughToShowTheSelection() {
    var selection = FinderSelection(count: 12, pageSize: 4)
    for _ in 0..<3 { selection.move(by: 1) }
    #expect(selection.visible == 0..<4, "row 3 is the last that shows")
    selection.move(by: 1)
    #expect(selection.selected == 4)
    #expect(selection.visible == 1..<5)
    selection.move(by: -1)
    #expect(selection.visible == 1..<5, "going back up inside the page does not scroll")
    for _ in 0..<3 { selection.move(by: -1) }
    #expect(selection.selected == 0)
    #expect(selection.visible == 0..<4)
    // Round the top to the last row, and round the bottom to the first.
    selection.move(by: -1)
    #expect(selection.selected == 11)
    #expect(selection.visible == 8..<12)
    selection.move(by: 1)
    #expect(selection.selected == 0)
    #expect(selection.visible == 0..<4)
  }

  @Test func pagesStopAtTheEnds() {
    var selection = FinderSelection(count: 10, pageSize: 4)
    selection.page(by: 1)
    #expect(selection.selected == 4)
    selection.page(by: 1)
    #expect(selection.selected == 8)
    selection.page(by: 1)
    #expect(selection.selected == 9)
    #expect(selection.visible == 6..<10)
    selection.page(by: -5)
    #expect(selection.selected == 0)
    #expect(selection.visible == 0..<4)
  }

  @Test func selectingClampsToTheList() {
    var selection = FinderSelection(count: 5)
    selection.select(99)
    #expect(selection.selected == 4)
    selection.select(-3)
    #expect(selection.selected == 0)
  }

  @Test func visiblePlacesMapToRows() {
    var selection = FinderSelection(count: 12, pageSize: 4)
    selection.select(6)
    #expect(selection.visible == 3..<7)
    #expect(selection.row(atVisible: 0) == 3)
    #expect(selection.row(atVisible: 3) == 6)
    #expect(selection.row(atVisible: 4) == nil)
    #expect(selection.row(atVisible: -1) == nil)
    let short = FinderSelection(count: 2, pageSize: 4)
    #expect(short.row(atVisible: 1) == 1)
    #expect(short.row(atVisible: 2) == nil, "the palette has room there, but the list has ended")
  }

  @Test func aListThatChangesLengthKeepsTheRowIfItCan() {
    var selection = FinderSelection(count: 12, pageSize: 4)
    selection.select(10)
    selection.resize(to: 11)
    #expect(selection.selected == 10)
    #expect(selection.visible == 7..<11)
    selection.resize(to: 6)
    #expect(selection.selected == 5)
    #expect(selection.visible == 2..<6)
    selection.resize(to: 2)
    #expect(selection.selected == 1)
    #expect(selection.visible == 0..<2)
    selection.resize(to: 0)
    #expect(selection.selected == nil)
    #expect(selection.visible.isEmpty)
    selection.resize(to: 3)
    #expect(selection.selected == 0)
  }

  @Test func absurdNumbersDoNoHarm() {
    var selection = FinderSelection(count: .max, pageSize: .max)
    selection.move(by: .max)
    selection.move(by: .min)
    selection.page(by: .max)
    selection.page(by: .min)
    selection.select(.max)
    selection.select(.min)
    selection.resize(to: .max)
    selection.resize(to: .min)
    #expect(selection.selected == nil)
    var negative = FinderSelection(count: -5, pageSize: -5)
    #expect(negative.count == 0 && negative.pageSize == 1)
    negative.resize(to: 3)
    negative.move(by: .min)
    #expect(negative.visible.count == 1)
    #expect(negative.row(atVisible: .max) == nil && negative.row(atVisible: .min) == nil)
  }
}

private let main = DisplayID("main")
private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

private func window(_ id: UInt32, _ app: String, _ title: String, _ place: FinderPlace = .outOfView) -> FinderModel.Row {
  FinderModel.Row(
    destination: .window(WindowID(id)), name: app, detail: title, place: place, display: main, pid: 7,
    bundleID: "com.example.\(app.lowercased())")
}

private func view(_ slot: Int, _ apps: String) -> FinderModel.Row {
  FinderModel.Row(
    destination: .view(main, slot: slot), name: "View \(slot)", detail: apps, place: .savedView, display: main)
}

private func model(_ rows: [FinderModel.Row], notice: String? = nil) -> FinderModel {
  FinderModel(display: main, screen: screen, rows: rows, notice: notice)
}

@Suite struct FinderSessionTests {
  private let rows = [
    window(102, "Notes", "Shopping"), window(103, "Mail", "Inbox"), window(104, "Safari", "Arbor docs"),
    window(101, "Safari", "News", .inView), view(1, "Safari, Notes"), view(3, "Mail"),
  ]

  @Test func opensWithEverythingInOrderAndTheFirstRowSelected() {
    let session = FinderSession(model: model(rows))
    #expect(session.query.isEmpty)
    #expect(session.items.map(\.row) == rows)
    #expect(session.items.map(\.isSelected) == [true, false, false, false, false, false])
    #expect(session.selected == .window(WindowID(102)))
    #expect(session.message == nil)
  }

  @Test func typingFiltersAndSelectsTheBestMatch() {
    var session = FinderSession(model: model(rows))
    session.moveSelection(by: 2)
    session.type("saf")
    // The windows of the app before the view that holds it; equals in the order given.
    #expect(session.items.map(\.row.destination) == [.window(WindowID(104)), .window(WindowID(101)), .view(main, slot: 1)])
    #expect(session.selected == .window(WindowID(104)), "a new query starts at the top again")
    #expect(session.items[0].match.nameRanges == [0..<3])
    session.type("saf news")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(101))])
    session.type("")
    #expect(session.items.map(\.row) == rows)
  }

  @Test func savedViewsAreFoundByNumberAndByWhatTheyHold() {
    var session = FinderSession(model: model(rows))
    session.type("view")
    #expect(session.items.map(\.row.destination) == [.view(main, slot: 1), .view(main, slot: 3)])
    session.type("v3")
    #expect(session.selected == .view(main, slot: 3))
    session.type("3")
    #expect(session.selected == .view(main, slot: 3))
    session.type("mail")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(103)), .view(main, slot: 3)])
  }

  @Test func nothingMatchingSaysSoAndChoosesNothing() {
    var session = FinderSession(model: model(rows))
    session.type("zebra")
    #expect(session.items.isEmpty)
    #expect(session.selected == nil)
    #expect(session.destination(atVisible: 0) == nil)
    #expect(session.message == "Nothing matches")
    session.moveSelection(by: 1)
    #expect(session.selected == nil)
    #expect(FinderSession(model: model([])).message == "No windows")
  }

  @Test func rowsCanBeChosenByTheirPlaceInThePalette() {
    var session = FinderSession(model: model((1...30).map { window(UInt32(100 + $0), "App", "Window \($0)") }))
    #expect(session.items.count == 9)
    #expect(session.destination(atVisible: 8) == .window(WindowID(109)))
    #expect(session.destination(atVisible: 9) == nil)
    session.moveSelection(by: 10)
    #expect(session.selected == .window(WindowID(111)))
    #expect(session.destination(atVisible: 0) == .window(WindowID(103)), "the list has scrolled by two")
    #expect(session.items.last?.isSelected == true)
    session.pageSelection(by: 1)
    #expect(session.selected == .window(WindowID(120)))
  }

  @Test func aFreshListKeepsTheTextAndTheSelection() {
    var session = FinderSession(model: model(rows))
    session.type("saf")
    session.moveSelection(by: 1)
    #expect(session.selected == .window(WindowID(101)))
    // The other Safari window has closed.
    session.replace(model: model(rows.filter { $0.destination != .window(WindowID(104)) }, notice: "That window has closed"))
    #expect(session.query == "saf")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(101)), .view(main, slot: 1)])
    #expect(session.selected == .window(WindowID(101)), "the same window, now a row higher")
    #expect(session.message == "That window has closed")
  }

  @Test func aNoticeStaysUntilTheTextChanges() {
    var session = FinderSession(model: model(rows))
    session.type("zebra")
    session.replace(model: model(rows, notice: "That window has closed"))
    #expect(session.message == "That window has closed")
    session.moveSelection(by: 1)
    #expect(session.message == "That window has closed")
    session.type("zebr")
    #expect(session.message == "Nothing matches")
    session.type("")
    #expect(session.message == nil)
  }

  @Test func whenTheSelectedRowHasGoneTheOneThatTookItsPlaceIsSelected() {
    var session = FinderSession(model: model(rows))
    session.moveSelection(by: 1)
    session.replace(model: model(rows.filter { $0.destination != .window(WindowID(103)) }))
    #expect(session.selected == .window(WindowID(104)))
    session.moveSelection(by: -2)
    #expect(session.selected == .view(main, slot: 3), "the last row")
    session.replace(model: model(Array(rows.prefix(2))))
    #expect(session.selected == .window(WindowID(103)), "the last row there is now")
    session.replace(model: model([], notice: "That window has closed"))
    #expect(session.selected == nil)
    #expect(session.message == "That window has closed")
  }

  @Test func notesSayWhereAndOnWhichDisplay() {
    var row = window(101, "Safari", "News", .minimized)
    #expect(row.note == "minimized")
    row.displayName = "Studio Display"
    #expect(row.note == "minimized, on Studio Display")
    // The words of docs/GLOSSARY.md: out of view, never parked; hidden only for ⌘H; macOS Spaces by their full name.
    #expect(
      FinderPlace.allCases.map(\.rawValue) == [
        "in view", "out of view", "tile", "tab", "floating", "floating, out of view", "kept in view", "summoned",
        "out of view until summoned", "minimized", "hidden",
        "full screen", "on another macOS Space", "not arranged", "saved view", "space", "command",
      ])
  }

  @Test func badgesStandInForIcons() {
    #expect(window(101, "Safari", "News").badge == nil)
    #expect(view(3, "Mail").badge == "3")
    let space = FinderModel.Row(
      destination: .space(main, NodeID(4)), name: "writing", detail: "Notes", place: .namedSpace, display: main)
    #expect(space.badge == "W")
  }

  @Test func destinationsDescribeThemselvesWithoutNamesOrTitles() {
    #expect("\(FinderDestination.window(WindowID(101)))" == "w101")
    #expect("\(FinderDestination.view(main, slot: 3))" == "view 3")
    #expect("\(FinderDestination.space(main, NodeID(4)))" == "space n4")
  }

  @Test func theTextFormShowsWhatThePaletteShows() {
    var session = FinderSession(model: model(rows))
    session.type("saf")
    session.moveSelection(by: 1)
    #expect(
      session.text == """
        go to: saf
          1 w104  Safari  Arbor docs  (out of view)
        > 2 w101  Safari  News  (in view)
          3 view 1  View 1  Safari, Notes  (saved view)
        """)
    let long = FinderSession(model: model((1...12).map { window(UInt32(100 + $0), "App", "") }))
    #expect(long.text.hasSuffix("  9 w109  App  (out of view)\n  and 3 more"))
  }
}

@Suite struct FinderLayoutTests {
  @Test func sitsAQuarterOfTheWayDownInTheMiddle() {
    let layout = FinderLayout(screen: screen, rows: 4, hasMessage: false)
    #expect(layout.panel.width == 600)
    #expect(layout.panel.midX == screen.midX)
    // The type is said: inside `#expect`, Swift 6.2 on Linux takes the sum for a Double and finds it unequal to a CGFloat of the same value.
    #expect(layout.panel.minY == CGFloat((25 + 875.0 / 4).rounded()))
    #expect(layout.panel.height == CGFloat(56 + 16 + 4 * 38))
  }

  @Test func theTopStaysPutWhileTheListGrowsAndShrinks() {
    let tops = (0...9).flatMap { rows in
      [true, false].map { FinderLayout(screen: screen, rows: rows, hasMessage: $0).panel.minY }
    }
    #expect(Set(tops).count == 1)
    let heights = (0...9).map { FinderLayout(screen: screen, rows: $0, hasMessage: false).panel.height }
    #expect(heights == heights.sorted())
    #expect(heights[0] == FinderLayout.fieldBand, "with nothing under it, only the field")
  }

  @Test func thePartsFillThePaletteWithoutOverlapping() {
    let layout = FinderLayout(screen: screen, rows: 3, hasMessage: true)
    let bounds = CGRect(origin: .zero, size: layout.panel.size)
    #expect(bounds.contains(layout.field))
    // The glass stands over the rows' icons, and what is typed over the rows' words.
    #expect(bounds.contains(layout.glyph) && layout.glyph.maxX <= layout.field.minX)
    #expect(layout.glyph.midX == layout.rowFrame(0).minX + 10 + 12)
    #expect(layout.field.minX + 2 == layout.rowFrame(0).minX + 10 + 24 + 10)
    #expect(layout.glyph.midY == FinderLayout.fieldBand / 2)
    #expect(layout.field.maxY <= layout.list.minY)
    #expect(layout.list.maxY == bounds.maxY && layout.list.width == bounds.width)
    let inside = CGRect(origin: .zero, size: layout.list.size)
    let parts = (0..<3).map(layout.rowFrame) + [layout.messageFrame]
    for (part, next) in zip(parts, parts.dropFirst()) {
      #expect(inside.contains(part))
      #expect(part.maxY == next.minY)
    }
    #expect(inside.contains(layout.messageFrame))
  }

  @Test func pointsFindTheirRow() {
    let layout = FinderLayout(screen: screen, rows: 3, hasMessage: true)
    #expect(layout.row(at: CGPoint(x: 300, y: 10)) == 0)
    #expect(layout.row(at: CGPoint(x: 300, y: 8 + 38 + 1)) == 1)
    #expect(layout.row(at: CGPoint(x: 300, y: 8 + 3 * 38 - 1)) == 2)
    #expect(layout.row(at: CGPoint(x: 300, y: 8 + 3 * 38 + 5)) == nil, "the message is not a row")
    #expect(layout.row(at: CGPoint(x: 300, y: 2)) == nil, "the padding above")
    #expect(layout.row(at: CGPoint(x: 2, y: 20)) == nil, "the padding beside")
    #expect(layout.row(at: CGPoint(x: -50, y: -50)) == nil)
  }

  /// Any display, wherever it sits among the others: the longest list still ends on it.
  @Test(arguments: [
    CGRect(x: 0, y: 31, width: 1024, height: 674), CGRect(x: -1920, y: -300, width: 1920, height: 1055),
    CGRect(x: 1440, y: 200, width: 800, height: 575), CGRect(x: 0, y: 900, width: 1280, height: 420),
    CGRect(x: 0, y: 0, width: 640, height: 300), CGRect(x: 3000, y: -2000, width: 5120, height: 2855),
  ])
  func staysOnItsDisplay(screen: CGRect) {
    let rows = FinderLayout.pageSize(on: screen)
    #expect((1...9).contains(rows))
    for count in 0...rows {
      let layout = FinderLayout(screen: screen, rows: count, hasMessage: true)
      #expect(screen.contains(layout.panel), "\(count) rows: \(layout.panel)")
      #expect(layout.panel.midX.rounded() == screen.midX.rounded())
    }
  }

  @Test func shortDisplaysShowFewerRows() {
    #expect(FinderLayout.pageSize(on: screen) == 9)
    #expect(FinderLayout.pageSize(on: CGRect(x: 0, y: 0, width: 1024, height: 674)) == 9)
    #expect(FinderLayout.pageSize(on: CGRect(x: 0, y: 0, width: 1024, height: 400)) == 6)
    #expect(FinderSession(model: FinderModel(
      display: main, screen: CGRect(x: 0, y: 0, width: 1024, height: 400),
      rows: (1...30).map { window(UInt32($0), "App", "") })).items.count == 6)
  }

  @Test func impossibleDisplaysDoNotCrash() {
    for screen in [
      CGRect.zero, CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 0, y: 0, width: -100, height: -100),
      CGRect.null, CGRect.infinite, CGRect(x: CGFloat.nan, y: 0, width: CGFloat.nan, height: CGFloat.nan),
      CGRect(x: 0, y: 0, width: CGFloat.infinity, height: CGFloat.infinity),
    ] {
      #expect((1...9).contains(FinderLayout.pageSize(on: screen)))
      let layout = FinderLayout(screen: screen, rows: 500, hasMessage: true)
      #expect(layout.rows <= 9)
      _ = layout.row(at: CGPoint(x: 5, y: 5))
      _ = FinderLayout(screen: screen, rows: -4, hasMessage: false)
    }
  }
}

/// Go to… finds commands (board 0.14).
@Suite struct FinderCommandRowTests {
  private let places = [window(102, "Notes", "Shopping"), window(103, "Docker", "Containers"), view(3, "Mail")]
  private let commands: [FinderModel.Row] = [
    .command(.dock(nil, .left), name: "Dock Focused Window ▸ Left", shortcut: "⌃⌥←", display: main),
    .command(.undo, name: "Undo Dock", shortcut: "⌃⌥Z", display: main),
    .command(.toggleAutoDock, name: "Dock New Windows", isOn: true, display: main),
    .command(.equalize(all: false), name: "Arrangement ▸ Balance Sizes", display: main),
    .command(.saveView(3), name: "Saved Views ▸ Save This View As ▸ View 3", display: main),
  ]

  private func session(places: [FinderModel.Row]? = nil) -> FinderSession {
    FinderSession(model: FinderModel(display: main, screen: screen, rows: places ?? self.places, commands: commands))
  }

  @Test func beforeAnythingIsTypedItListsPlacesAndNoCommand() {
    var session = session()
    #expect(session.items.map(\.row) == places)
    session.type("bal")
    #expect(session.items.map(\.row.name) == ["Arrangement ▸ Balance Sizes"])
    session.type("  ")
    #expect(session.items.map(\.row) == places, "spaces ask for nothing")
    session.type("")
    #expect(session.items.map(\.row) == places)
  }

  @Test func aCommandIsFoundByAnyOfTheWordsOfItsWayThroughTheMenu() {
    var session = session()
    for (typed, command) in [
      ("left", "dock left"), ("focused left", "dock left"), ("save 3", "save-view 3"), ("sizes", Command.equalize(all: false).text),
    ] {
      session.type(typed)
      #expect(session.items.first?.row.destination == .command(command), "\(typed)")
    }
  }

  /// In a title, where a letter is worth what a command's is; and with far more left over than the command has.
  @Test func aPlaceAndACommandThatMatchEquallyWellAreThePlaceFirst() {
    let twins = [window(101, "Numbers", "Balance sheet for the year, third draft, with the auditor's remarks")]
    var session = FinderSession(
      model: FinderModel(
        display: main, screen: screen, rows: twins, commands: [.command(.equalize(all: false), name: "Balance", display: main)]))
    session.type("bal")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(101)), .command(Command.equalize(all: false).text)])
  }

  /// Until commands were listed, Return went to these windows. A word of a command begins with the letters, which scores higher.
  @Test func lettersThatStandTogetherInsideAWordOfAPlaceAreThatPlace() {
    let commands: [FinderModel.Row] = [
      .command(.hold(minutes: nil), name: "Hold This View", display: main), .command(.floatAll, name: "Float All Windows", display: main),
      .command(.back, name: "Back", display: main), .command(.rotate, name: "Arrangement ▸ Rotate Group", display: main),
    ]
    let places = [
      window(101, "Preview", "scan.pdf"), window(102, "Finder", "Wallpaper"), window(103, "Mail", "Feedback"), window(104, "Notes", "Carrot cake"),
      window(105, "Photos", "Hut, cold"),
    ]
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: places, commands: commands))
    // The last one holds its letters here and there, under a command that is spelt out.
    for (typed, window) in [("vie", 101), ("all", 102), ("back", 103), ("rot", 104), ("hold", 105)] {
      session.type(typed)
      #expect(session.selected == .window(WindowID(UInt32(window))), "\(typed)")
      #expect(session.items.map(\.row.place) == [.outOfView, .command], "the command comes after it: \(typed)")
    }
  }

  @Test func noCommandComesBeforeAPlaceThatIsBetterThanOneFoundInOnePiece() {
    // `rot`: scattered through an app's name, where letters are worth more, and together inside a word of a title.
    let places = [window(101, "Carrot", ""), window(102, "Remote Desktop", "")]
    var session = FinderSession(
      model: FinderModel(display: main, screen: screen, rows: places, commands: [.command(.rotate, name: "Rotate Group", display: main)]))
    session.type("rot")
    #expect(session.items.last?.row.destination == .command("rotate"))
    #expect(Set(session.items.dropLast().map(\.row.destination)) == [.window(WindowID(101)), .window(WindowID(102))])
  }

  @Test func amongEquallyGoodCommandsTheMenusOrderDecides() {
    let commands: [FinderModel.Row] = [
      .command(.toggleFloat(nil), name: "Float Focused Window", display: main), .command(.floatAll, name: "Float All Windows", display: main),
    ]
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: places, commands: commands))
    session.type("float")
    #expect(session.items.map(\.row.name) == ["Float Focused Window", "Float All Windows"], "though the second is shorter")
  }

  /// Found by the rehearsal of scripts/mac-shell/shots-finder.sh: `3`, Return, meant for the window, saved view 3.
  @Test func aLetterOfATitleIsWorthWhatALetterOfACommandIs() {
    var session = session(places: [window(101, "Numbers", "Report 1"), window(103, "Numbers", "Report 3, the long one, with a good deal after it")])
    session.type("3")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(103)), .command("save-view 3")])
    session.type("left")
    #expect(session.items.map(\.row.destination) == [.window(WindowID(103)), .command("dock left")], "scattered through a title, and still first")
  }

  @Test func thePlacesComeFirstAndThenTheCommandsEachKindBestFirst() {
    var session = session()
    session.type("dock")
    // The app whose name it nearly is; then what begins with the word, in the menu's order; last what only holds it.
    #expect(
      session.items.map(\.row.name) == ["Docker", "Dock Focused Window ▸ Left", "Dock New Windows", "Undo Dock"])
    session.type("view 3")
    #expect(session.items.map(\.row.name) == ["View 3", "Saved Views ▸ Save This View As ▸ View 3"])
  }

  @Test func theNoteSaysThatItIsACommandWithTheMenusTickAndTheKeyInEffect() {
    #expect(commands.map(\.note) == ["command, ⌃⌥←", "command, ⌃⌥Z", "command ✓", "command", "command"])
    #expect(FinderModel.Row.command(.stepOut, name: "Step Out", shortcut: "⌃⌥↑", isAvailable: false, display: main).note == "command, not now")
    #expect(commands.allSatisfy { $0.badge == "⌘" && $0.pid == nil && $0.detail.isEmpty })
  }

  @Test func theLogIsGivenTheFirstWordOfACommandAndNoMore() {
    #expect(FinderDestination.command("dock left").description == "command dock")
    #expect(FinderDestination.command(Command.unname("Taxes 2026").text).description == "command unname")
    #expect(FinderDestination.command("").description == "command ")
  }

  @Test func withNoPlaceLeftItSaysSoUntilACommandIsFound() {
    var session = session(places: [])
    #expect(session.items.isEmpty && session.message == "No windows")
    session.type("undo")
    #expect(session.items.first?.row.destination == .command("undo") && session.message == "↓ picks a command, ↩ runs it")
    session.type("zzz")
    #expect(session.items.isEmpty && session.message == "No windows")
  }

  @Test func aFreshListKeepsTheCommandThatWasSelected() {
    var session = session()
    session.type("dock")
    session.moveSelection(by: 1)
    #expect(session.selected == .command("dock left"))
    session.replace(model: FinderModel(display: main, screen: screen, rows: [places[0]], commands: commands))
    #expect(session.query == "dock" && session.selected == .command("dock left"))
  }

  @Test func asTextARowShowsItsFirstWordItsNameAndItsNote() {
    var session = session()
    session.type("new")
    #expect(session.text == "go to: new\n  1 command toggle-auto-dock  Dock New Windows  (command ✓)\n  ↓ picks a command, ↩ runs it")
    session.moveSelection(by: 1)
    #expect(session.text == "go to: new\n> 1 command toggle-auto-dock  Dock New Windows  (command ✓)")
  }

  // MARK: What Return can run

  /// The story it was found by. Somebody types `notes`; Notes closes behind the palette; Return: "That window has closed", and a fresh
  /// list, whose one row held the letters scattered over its way through the menu (n-o in Window, t in Don’t, e in Arrange, s in Safari).
  /// A second Return took Safari out of the arrangement and wrote that to settings.json.
  @Test func lettersScatteredOverACommandsNameDoNotListIt() {
    let row = FinderModel.Row.command(.exclude(bundleID: "com.apple.Safari"), name: "Focused Window ▸ Don’t Arrange “Safari”", display: main)
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [window(101, "Mail", "Inbox")], commands: [row]))
    session.type("notes")
    #expect(session.items.isEmpty && session.selected == nil && session.message == "Nothing matches")
  }

  @Test func aCommandIsListedOnlyWhenEveryWordTypedBeginsAWordOfItsName() {
    var session = session(places: [])
    func listed(_ text: String) -> [String] {
      session.type(text)
      return session.items.map(\.row.name)
    }
    // From inside a word, initials, letters here and there: that is how a title is found, of which nobody knows the words.
    for text in ["ock", "indow", "dfw", "dnw", "blnc", "udo", "izes", "dock eft", "lance sizes", "dock x"] {
      #expect(listed(text).isEmpty, "\(text)")
    }
    #expect(listed("bal") == ["Arrangement ▸ Balance Sizes"])
    #expect(listed("siz") == ["Arrangement ▸ Balance Sizes"])
    #expect(listed("arr b s") == ["Arrangement ▸ Balance Sizes"])
    #expect(listed("left dock") == ["Dock Focused Window ▸ Left"], "in any order")
    #expect(listed("DOCK") == ["Dock Focused Window ▸ Left", "Dock New Windows", "Undo Dock"])
    #expect(listed("save 3") == ["Saved Views ▸ Save This View As ▸ View 3"])
  }

  /// Nobody types the apostrophe, and whoever does is right too.
  @Test func anApostropheInACommandsNameNeedNotBeTyped() {
    let row = FinderModel.Row.command(.exclude(bundleID: nil), name: "Don’t Arrange “Safari”", display: main)
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: [row]))
    for text in ["dont", "don't", "don’t arr", "dont arrange saf", "don", "Don’t Arrange “Safari”", "dont \"saf", "(arr"] {
      session.type(text)
      #expect(session.items.count == 1, "\(text)")
    }
    session.type("dont")
    #expect(session.items.first?.match.nameRanges == [0..<3, 4..<5], "the letters are set off, the apostrophe is not")
  }

  /// Whatever is typed: the same places in the same order, the same one selected and the same under each digit, as far as there are places.
  /// Then the commands. ↑, ⇧⇥ and the Page keys do among the places what they did; so does ↓ as far as the last place.
  @Test func theListIsWhatItWasWithTheCommandsAfterIt() {
    let places = [
      window(101, "Safari", "Arbor: a window manager, docs and all, left to be read"), window(102, "Notes", "Shopping, balance of the month"),
      window(103, "Docker", "Containers"), window(104, "Slack", "Huddle"), window(105, "Pages", "Untitled, saved in the view of the dock"),
      window(106, "Numbers", "Big tables all over, nicely coloured, every size"), view(3, "Mail"),
    ]
    let names = places.flatMap { [$0.name, $0.detail] } + commands.map(\.name) + ["sh", "dfw", "blnc", "uo", "3", "w s", "a e", "s v"]
    var typed = Set<String>()
    for name in names {
      for word in name.lowercased().split(separator: " ") { for length in 1...word.count { typed.insert(String(word.prefix(length))) } }
      typed.insert(name)
    }
    var before = FinderSession(model: FinderModel(display: main, screen: screen, rows: places))
    var now = FinderSession(model: FinderModel(display: main, screen: screen, rows: places, commands: commands))
    var mixed = 0
    for text in typed.sorted() {
      before.type(text)
      now.type(text)
      let count = before.matches.count
      #expect(Array(now.matches.prefix(count)) == before.matches, "\(text)")
      #expect(now.matches.dropFirst(count).allSatisfy { $0.index >= places.count }, "\(text)")
      #expect(now.selected == before.selected, "Return: \(text)")
      if count > 0, now.matches.count > count { mixed += 1 }
      for place in 0..<min(count, 9) {
        #expect(now.destination(atVisible: place) == before.destination(atVisible: place), "⌘\(place + 1): \(text)")
        #expect(now.selected == before.selected, "↓ \(place) times: \(text)")
        if place + 1 < count {
          now.moveSelection(by: 1)
          before.moveSelection(by: 1)
        }
      }
      guard count > 0 else { continue }
      // From the top, from the bottom and from between, more often than there are places.
      for start in 0..<count {
        for keys: [(name: String, press: (inout FinderSession) -> Void)] in [
          Array(repeating: ("↑", { $0.moveSelection(by: -1) }), count: count + 2),
          [("↑↑↑", { $0.moveSelection(by: -3) }), ("far up", { $0.moveSelection(by: -1000) })],
          [("Page Down", { $0.pageSelection(by: 1) }), ("Page Down", { $0.pageSelection(by: 1) }), ("↑", { $0.moveSelection(by: -1) })],
          [("Page Up", { $0.pageSelection(by: -1) }), ("↑", { $0.moveSelection(by: -1) }), ("Page Down", { $0.pageSelection(by: 3) })],
        ] {
          before.type(text)
          now.type(text)
          before.moveSelection(by: start)
          now.moveSelection(by: start)
          for key in keys {
            key.press(&before)
            key.press(&now)
            #expect(now.selected == before.selected, "\(text), ↓ \(start) times, then \(keys.map(\.name)) as far as \(key.name)")
            #expect(now.items.filter(\.isSelected).map(\.row) == before.items.filter(\.isSelected).map(\.row))
          }
        }
      }
    }
    #expect(typed.count > 150 && mixed > 40, "or this looks at nothing: \(typed.count), \(mixed)")
  }

  /// More places than the palette shows: the same rows show after the same keys.
  @Test func amongManyPlacesTheListScrollsAsItDid() {
    let places = (1...25).map { window(UInt32(100 + $0), "Docker", "Container \($0)") }
    var before = FinderSession(model: FinderModel(display: main, screen: screen, rows: places))
    var now = FinderSession(model: FinderModel(display: main, screen: screen, rows: places, commands: commands))
    before.type("dock")
    now.type("dock")
    #expect(now.matches.count == before.matches.count + 3)
    let keys: [(inout FinderSession) -> Void] = [
      { $0.pageSelection(by: 1) }, { $0.pageSelection(by: 1) }, { $0.pageSelection(by: 1) }, { $0.pageSelection(by: 1) }, { $0.moveSelection(by: -1) },
      { $0.pageSelection(by: -1) }, { $0.pageSelection(by: -5) }, { $0.moveSelection(by: -1) }, { $0.moveSelection(by: -1) }, { $0.pageSelection(by: 9) },
    ]
    for (step, key) in keys.enumerated() {
      key(&before)
      key(&now)
      #expect(now.selected == before.selected, "key \(step)")
      #expect(now.items == before.items, "key \(step)")
    }
  }

  /// The one way from the places to the commands, and the ways back.
  @Test func onlyTheArrowDownPastTheLastPlaceLeadsToTheCommands() {
    var session = session(places: [window(103, "Docker", "Containers"), window(104, "Docker", "Images")])
    session.type("dock")
    #expect(session.items.map(\.row.place) == [.outOfView, .outOfView, .command, .command, .command])
    session.moveSelection(by: -1)
    #expect(session.selected == .window(WindowID(104)), "↑ from the top: round to the last place, as ever")
    session.pageSelection(by: 1)
    #expect(session.selected == .window(WindowID(104)), "Page Down stops at the last place, as ever")
    session.moveSelection(by: 1)
    #expect(session.selected == .command("dock left"))
    // Among the commands the keys are a list's.
    session.pageSelection(by: 1)
    #expect(session.selected == .command("undo"))
    session.moveSelection(by: 1)
    #expect(session.selected == .window(WindowID(103)), "round")
    session.moveSelection(by: 2)
    session.moveSelection(by: -1)
    #expect(session.selected == .window(WindowID(104)), "↑ from the first command")
    session.moveSelection(by: 2)
    #expect(session.selected == .command(Command.toggleAutoDock.text))
    session.moveSelection(by: -4)
    #expect(session.selected == .window(WindowID(104)), "once among the places it stays among them: 104, 103, 104")
    session.moveSelection(by: 3)
    session.pageSelection(by: -1)
    #expect(session.selected == .window(WindowID(103)))
  }

  /// Letters and Return do what they did before commands were listed: they go to a place, or beep.
  @Test func returnAloneNeverChoosesACommand() {
    var session = session(places: [])
    session.type("bal")
    #expect(session.items.map(\.row.name) == ["Arrangement ▸ Balance Sizes"])
    #expect(session.selected == nil, "it is shown")
    #expect(session.items.allSatisfy { !$0.isSelected }, "and not selected")
    #expect(session.message == "↓ picks a command, ↩ runs it")
    #expect(session.layout.hasMessage)
  }

  @Test func pickedByHandItIsChosen() {
    var session = session(places: [])
    session.type("dock")
    #expect(session.selected == nil)
    session.moveSelection(by: 1)
    #expect(session.selected == .command("dock left"), "↓ picks the first, not the second")
    #expect(session.items.map(\.isSelected) == [true, false, false])
    #expect(session.message == nil)
    session.moveSelection(by: 1)
    #expect(session.selected == .command(Command.toggleAutoDock.text))
    session.type("dock")
    session.moveSelection(by: -1)
    #expect(session.selected == .command("undo"), "↑ picks the last")
    session.type("dock")
    session.pageSelection(by: 1)
    #expect(session.selected != nil)
  }

  @Test func aClickAndADigitPointAtARowAndNeedNoPicking() {
    var session = session(places: [])
    session.type("dock")
    #expect(session.destination(atVisible: 1) == .command(Command.toggleAutoDock.text))
  }

  @Test func whatIsTypedAfterwardsUnpicks() {
    var session = session(places: [])
    session.type("doc")
    session.moveSelection(by: 1)
    #expect(session.selected != nil)
    session.type("dock")
    #expect(session.selected == nil && session.items.allSatisfy { !$0.isSelected })
  }

  @Test func underAPlaceACommandIsReachedWithTheArrowAndThenChosen() {
    var session = session()
    session.type("dock")
    #expect(session.selected == .window(WindowID(103)), "Docker")
    #expect(session.message == nil)
    session.moveSelection(by: 1)
    #expect(session.selected == .command("dock left"))
  }

  /// Return went to this window until commands were listed, and goes there.
  @Test func aPlaceThatOnlyHoldsTheLettersHereAndThereStillComesBeforeACommandSpeltOut() {
    var session = session(places: [window(101, "Numbers", "Big tables all over, nicely coloured, every size")])
    session.type("balance")
    #expect(session.items.map(\.row.place) == [.outOfView, .command])
    #expect(session.selected == .window(WindowID(101)) && session.message == nil)
    session.moveSelection(by: 1)
    #expect(session.selected == .command(Command.equalize(all: false).text))
  }

  /// Whoever types `saf` means Safari. In Safari's one window, `saf` ↓ Return, for the next of its windows, went round to the same window
  /// until commands were listed. It must not take Safari out of the arrangement, which is the row that stood below.
  @Test func anAppsNameInACommandsNameSaysWhomItIsAboutAndDoesNotListIt() {
    let commands: [FinderModel.Row] = [
      .command(.exclude(bundleID: "com.apple.Safari"), name: "Don’t Arrange “Safari”", display: main),
      .command(.passThrough(bundleID: "com.apple.Safari"), name: "Shortcuts Off in “Safari”", display: main),
      .command(.include(bundleID: "com.apple.iCal"), name: "Arrange Again ▸ “Calendar”", display: main),
      .command(.passThrough(bundleID: "com.apple.shortcuts"), name: "Shortcuts Off in “Shortcuts”", display: main),
    ]
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [window(101, "Safari", "Arbor")], commands: commands))
    func listed(_ text: String) -> [String] {
      session.type(text)
      return session.items.filter { $0.row.place == .command }.map(\.row.name)
    }
    for text in ["s", "saf", "safari", "\"safari\"", "“Safari”", "cal", "calendar"] { #expect(listed(text).filter { !$0.hasPrefix("Shortcuts") }.isEmpty, "\(text)") }
    #expect(listed("saf").isEmpty)
    session.moveSelection(by: 1)
    #expect(session.selected == .window(WindowID(101)), "round, as ever")
    // It narrows.
    #expect(listed("dont saf") == ["Don’t Arrange “Safari”"])
    #expect(listed("saf arr") == ["Don’t Arrange “Safari”"], "in any order")
    #expect(listed("off saf") == ["Shortcuts Off in “Safari”"])
    #expect(listed("again cal") == ["Arrange Again ▸ “Calendar”"])
    #expect(listed("arr") == ["Arrange Again ▸ “Calendar”", "Don’t Arrange “Safari”"])
    #expect(listed("dont cal").isEmpty)
    // A word of the command's own, though an app is called the same.
    #expect(listed("shortcuts") == ["Shortcuts Off in “Safari”", "Shortcuts Off in “Shortcuts”"])
    #expect(listed("Shortcuts Off in “Shortcuts”") == ["Shortcuts Off in “Shortcuts”"])
  }

  /// A row's name is cut to 80 characters, and the closing mark with it.
  @Test func anAppsNameTooLongForTheRowIsStillTheApps() {
    for app in ["Pause and Balance " + String(repeating: "Studio ", count: 12), "The \"Pro\" Pause and Balance " + String(repeating: "Studio ", count: 12)] {
      let row = FinderModel.Row.command(.exclude(bundleID: "com.example.long"), name: "Don’t Arrange “\(app)”", display: main)
      #expect(!row.name.contains("”"), "or this looks at nothing")
      var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: [row]))
      for text in ["pa", "pause", "bal", "studio", "and"] {
        session.type(text)
        #expect(session.items.isEmpty, "\(text)")
      }
      session.type("dont pause")
      #expect(session.items.count == 1)
    }
  }

  /// A row's name copied from here or from the guide, signs and all.
  @Test func aWordOfNothingButSignsAsksNothingOfACommand() {
    var session = session(places: [])
    for text in ["Dock Focused Window ▸ Left", "dock - left", "dock · left", "dock > left", "▸ left"] {
      session.type(text)
      #expect(session.items.map(\.row.name) == ["Dock Focused Window ▸ Left"], "\(text)")
    }
    for text in ["▸", "-", "▸ ▸", "\"", "…"] {
      session.type(text)
      #expect(session.items.isEmpty, "and names none: \(text)")
    }
  }

  /// A place is found by the first eight words and 64 letters of what was typed. What a command is called by is read to the end.
  @Test func ofACommandEveryWordCountsHoweverManyAreTyped() {
    let views = (1...3).map { FinderModel.Row.command(.saveView($0), name: "Saved Views ▸ Save This View As ▸ View \($0)", display: main) }
    var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: views + commands))
    func listed(_ text: String) -> [String] {
      session.type(text)
      return session.items.map(\.row.name)
    }
    #expect(listed("Saved Views ▸ Save This View As ▸ View 3") == [views[2].name, commands[4].name], "ten words")
    #expect(listed("d d d d d d d d") == ["Dock Focused Window ▸ Left", "Dock New Windows", "Undo Dock"])
    #expect(listed("d d d d d d d d zzz").isEmpty)
    #expect(listed("d d d d d d d d d n") == ["Dock New Windows"])
    #expect(listed(String(repeating: "dock ", count: 12) + "dock") == ["Dock Focused Window ▸ Left", "Dock New Windows", "Undo Dock"], "thirteen words")
    // Beyond what is read at all.
    #expect(listed("dock " + String(repeating: "d", count: 70)).isEmpty)
    #expect(listed("dock" + String(repeating: " d", count: 200)).isEmpty)
    #expect(listed("d d d d d d d d " + String(repeating: "d", count: 70)).isEmpty)
    let long = FinderModel.Row.command(.exclude(bundleID: "x"), name: "Drop “\(String(repeating: "d", count: 66))”", display: main)
    session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: [long]))
    #expect(listed("d d d d d d d d " + String(repeating: "d", count: 65) + "x").isEmpty, "a word is not read as its first 64 letters")
    // 62 letters, and room for two: þ is th, and the x is not read.
    let the = FinderModel.Row.command(.include(bundleID: "x"), name: "Arrangement ▸ Arrange Again ▸ “The Unarchiver”", display: main)
    session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: [the]))
    let most = String(repeating: "arrangement ", count: 5) + "arrange "
    #expect(listed(most + "th").count == 1, "or this looks at nothing")
    #expect(listed(most + "thx").isEmpty && listed(most + "þx").isEmpty)
  }

  @Test func movingByNothingPicksNothing() {
    var session = session(places: [])
    session.type("dock")
    session.moveSelection(by: 0)
    #expect(session.selected == nil && !session.hasPicked)
    session.pageSelection(by: 0)
    #expect(session.selected == nil && !session.hasPicked)
  }

  /// As from above the list, like the arrows: not a palette's length further down.
  @Test func thePageKeysPickTheFirstOfTheCommandsThatWait() {
    let many = (1...30).map { FinderModel.Row.command(.saveView($0), name: "Save View \($0)", display: main) }
    for pages in [1, -1] {
      var session = FinderSession(model: FinderModel(display: main, screen: screen, rows: [], commands: many))
      session.type("save")
      #expect(session.selected == nil)
      session.pageSelection(by: pages)
      #expect(session.selected == .command("save-view 1"), "\(pages)")
    }
  }

  @Test func aFreshListUnpicksUnlessThePickedRowIsStillThere() {
    var session = session()
    session.type("dock")
    session.moveSelection(by: 1)
    #expect(session.selected == .command("dock left"))
    session.replace(model: FinderModel(display: main, screen: screen, rows: [], commands: commands, notice: "“Left” can do nothing just now"))
    #expect(session.selected == .command("dock left"), "it was picked, and is")
    // The place that was selected goes, and a command takes its row.
    session = self.session()
    session.type("dock")
    #expect(session.selected == .window(WindowID(103)))
    session.replace(model: FinderModel(display: main, screen: screen, rows: [places[0]], commands: commands, notice: "That window has closed"))
    #expect(session.items.first?.row.place == .command)
    #expect(session.selected == nil, "a second Return runs nothing")
    #expect(session.message == "That window has closed")
  }

  /// The same with the arrows used before: what was picked was the place, and it has gone.
  @Test func aPickDoesNotPassToTheCommandThatTookThePlacesRow() {
    var session = session()
    session.type("dock")
    session.moveSelection(by: 1)
    session.moveSelection(by: -1)
    #expect(session.selected == .window(WindowID(103)) && session.hasPicked)
    session.replace(model: FinderModel(display: main, screen: screen, rows: [places[0]], commands: commands, notice: "That window has closed"))
    #expect(session.items.first?.row.place == .command)
    #expect(session.selected == nil && !session.hasPicked, "a second Return runs nothing")
  }

  /// ↓ to the second of two windows; it closes; Return. The row it had is a command's now.
  @Test func whereAPlaceIsLeftAFreshListSelectsAPlace() {
    let two = [window(103, "Docker", "Containers"), window(104, "Docker", "Images")]
    var session = session(places: two)
    session.type("dock")
    session.moveSelection(by: 1)
    #expect(session.selected == .window(WindowID(104)))
    session.replace(model: FinderModel(display: main, screen: screen, rows: [two[0]], commands: commands, notice: "That window has closed"))
    #expect(session.items.map(\.row.place).prefix(2) == [.outOfView, .command])
    #expect(session.selected == .window(WindowID(103)), "the nearest place, not the command in the row")
    #expect(session.items.map(\.isSelected).prefix(2) == [true, false])
  }
}
