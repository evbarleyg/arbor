import ArborCore
import CoreGraphics
import Testing

/// Ticking windows in Go to… (QUESTIONS Q29, 9; board 0.12): ⌘↩ ticks, two to four, ↩ docks them side by side.
@Suite struct FinderTickTests {
  private let display = DisplayID("main")

  private func row(_ id: UInt32, _ app: String, _ title: String = "", _ place: FinderPlace = .floating) -> FinderModel.Row {
    FinderModel.Row(destination: .window(WindowID(id)), name: app, detail: title, place: place, display: display, pid: Int32(id))
  }

  private func session(_ extra: [FinderModel.Row] = []) -> FinderSession {
    let rows = [
      row(101, "Safari", "Trains"), row(102, "Notes", "Oaks", .outOfView), row(103, "Mail", "Inbox", .tile),
      row(104, "Music", "", .minimized), row(105, "Preview", "Plan", .hiddenApp), row(106, "Xcode", "Arbor", .inView),
    ]
    return FinderSession(
      model: FinderModel(display: display, screen: CGRect(x: 0, y: 25, width: 1440, height: 875), rows: rows + extra))
  }

  private func w(_ id: UInt32) -> WindowID { WindowID(id) }

  @Test func theLineUnderTheRowsSaysHowBeforeAnybodyAsks() {
    let session = session()
    #expect(session.message == "⌘↩ ticks a window: two to four are docked side by side")
    #expect(session.layout.hasMessage && session.ticked.isEmpty && session.chosen == session.selected)
  }

  @Test func ticksAreNumberedInTheOrderMade() {
    var session = session()
    session.moveSelection(by: 2)
    #expect(session.tick() == true)
    #expect(session.tick(atVisible: 0) == true)
    #expect(session.tick(atVisible: 3) == true)
    #expect(session.ticked == [w(103), w(101), w(104)])
    #expect(session.items.map(\.tick) == [2, nil, 1, 3, nil, nil])
    #expect(session.message == "↩ docks these 3 side by side")
    #expect(session.chosen == .together([w(103), w(101), w(104)]))
  }

  /// Where the ticks meet the commands (board 0.25: Return alone never runs a command).
  @Test func withATickSetReturnNeverRunsACommandPickedOrNot() {
    let rows = [row(101, "Safari", "Trains"), row(102, "Notes", "Oaks")]
    let commands: [FinderModel.Row] = [.command(.undo, name: "Undo Dock", shortcut: "⌃⌥Z", display: display)]
    var session = FinderSession(
      model: FinderModel(display: display, screen: CGRect(x: 0, y: 25, width: 1440, height: 875), rows: rows, commands: commands))
    // A command cannot be ticked, waiting or picked.
    session.type("undo")
    #expect(session.selected == nil && session.message == "↓ picks a command, ↩ runs it")
    #expect(session.tick() == false && session.message == "Only windows can be docked side by side" && session.ticked.isEmpty)
    session.type("")
    #expect(session.tick(atVisible: 0) == true)
    session.type("undo")
    #expect(session.chosen == .window(w(101)) && session.message == "⌘↩ ticks another; ↩ goes to this one", "nothing waits for ↩")
    session.moveSelection(by: 1)
    #expect(session.selected == .command("undo") && session.chosen == .window(w(101)))
    session.type("")
    #expect(session.tick(atVisible: 1) == true)
    session.type("undo")
    session.moveSelection(by: 1)
    #expect(session.chosen == .together([w(101), w(102)]) && session.message == "↩ docks these 2 side by side")
  }

  /// The list changed by itself and the selected row is gone: nothing shows as selected (board 0.25), so ⌘↩ has nothing to tick.
  @Test func whereNothingShowsAsSelectedTheKeysTickNothingAndAClickStillDoes() {
    var session = session()
    #expect(session.tick(atVisible: 1) == true)
    session.moveSelection(by: 1)
    let selected = session.selected
    let left = session.model.rows.filter { $0.destination != selected }
    session.replace(model: FinderModel(display: display, screen: session.model.screen, rows: left))
    #expect(session.selected == nil && session.items.allSatisfy { !$0.isSelected })
    #expect(session.ticked == [w(102)], "the tick is a window's, not a row's place")
    #expect(session.tick() == false && session.ticked == [w(102)])
    #expect(session.tick(atVisible: 0) == true && session.ticked == [w(102), w(101)])
    #expect(session.chosen == .together([w(102), w(101)]))
  }

  @Test func againTakesTheTickOffAndTheOthersCloseUp() {
    var session = session()
    for place in [0, 1, 2] { #expect(session.tick(atVisible: place) == true) }
    #expect(session.tick(atVisible: 1) == true)
    #expect(session.ticked == [w(101), w(103)] && session.items.map(\.tick) == [1, nil, 2, nil, nil, nil])
  }

  @Test func aTickClearsTheFieldAndStaysOnItsRow() {
    var session = session()
    session.type("mai")
    #expect(session.selected == .window(w(103)) && session.items.count == 1)
    #expect(session.tick() == true)
    #expect(session.query.isEmpty && session.items.count == 6)
    #expect(session.selected == .window(w(103)), "the eyes are on that row")
    // The next one is looked for and ticked the same way.
    session.type("xco")
    #expect(session.tick() && session.ticked == [w(103), w(106)])
  }

  @Test func withOneTickedReturnGoesThereAsIfChosen() {
    var session = session()
    #expect(session.tick(atVisible: 4) == true)
    session.moveSelection(by: -3)
    #expect(session.chosen == .window(w(105)) && session.selected != session.chosen)
    #expect(session.message == "⌘↩ ticks another; ↩ goes to this one")
  }

  @Test func aFifthIsRefusedInWords() {
    var session = session()
    for place in 0..<4 { #expect(session.tick(atVisible: place) == true) }
    #expect(session.tick(atVisible: 4) == false)
    #expect(session.message == "Four at the most" && session.ticked.count == 4)
    // The words go with the next thing done; one of the four can still be let go.
    session.moveSelection(by: 1)
    #expect(session.message == "↩ docks these 4 side by side")
    #expect(session.tick(atVisible: 0) && session.tick(atVisible: 4) && session.ticked.last == w(105))
  }

  @Test func everyKindArborArrangesCanBeTickedAndNothingElse() {
    let others = [
      row(201, "Zoom", "Call", .notArranged), row(202, "Keynote", "Talk", .fullScreen), row(203, "Pages", "Letter", .otherSpace),
      FinderModel.Row(destination: .view(display, slot: 3), name: "View 3", detail: "Safari", place: .savedView, display: display),
      FinderModel.Row(destination: .space(display, NodeID(7)), name: "Writing", detail: "Notes", place: .namedSpace, display: display),
    ]
    for place in FinderPlace.allCases where ![.notArranged, .fullScreen, .otherSpace, .savedView, .namedSpace].contains(place) {
      #expect(row(1, "App", "", place).whyNotTicked == nil, "\(place)")
    }
    var session = FinderSession(
      model: FinderModel(display: display, screen: CGRect(x: 0, y: 25, width: 1440, height: 875), rows: others))
    let words = [
      "Arbor does not arrange Zoom", "A window in full screen stays there", "That window is on another macOS Space",
      "Only windows can be docked side by side", "Only windows can be docked side by side",
    ]
    for (place, why) in words.enumerated() {
      #expect(!session.tick(atVisible: place) && session.message == why && session.ticked.isEmpty, "\(place)")
    }
    // Typing takes the words away.
    session.type("z")
    #expect(session.message == FinderSession.hint)
  }

  @Test func aFreshListKeepsTheTicksOfWhatIsStillThere() {
    var session = session()
    for place in [5, 0, 2] { #expect(session.tick(atVisible: place) == true) }
    var model = session.model
    model.rows.removeAll { $0.destination == .window(w(101)) }
    model.rows[model.rows.firstIndex { $0.destination == .window(w(103)) }!].place = .fullScreen
    session.replace(model: model)
    #expect(session.ticked == [w(106)] && session.chosen == .window(w(106)))
  }

  @Test func whatHasToBeSaidComesBeforeTheHint() {
    var nothing = session()
    nothing.type("zzzz")
    #expect(nothing.message == "Nothing matches")
    #expect(nothing.tick() == false, "there is no row to tick")
    var model = session().model
    model.notice = "That window has closed"
    #expect(FinderSession(model: model).message == "That window has closed")
  }

  @Test func theCircleStandsAtTheEndOfItsRow() {
    let layout = session().layout
    for place in 0..<layout.rows {
      let (row, tick) = (layout.rowFrame(place), layout.tickFrame(place))
      #expect(row.contains(tick) && tick.width == tick.height && tick.midY == row.midY && row.maxX - tick.maxX == 12)
    }
  }

  @Test func asTextForTheSimulator() {
    var session = session()
    #expect(session.tick(atVisible: 1) && session.tick(atVisible: 0))
    let lines = session.text.split(separator: "\n").map(String.init)
    #expect(lines[1].hasSuffix("(floating)  [2]") && lines[2].hasSuffix("(out of view)  [1]"))
    #expect(lines.last == "  ↩ docks these 2 side by side")
    #expect(FinderDestination.together([w(102), w(101)]).description == "w102 w101 side by side")
  }
}
