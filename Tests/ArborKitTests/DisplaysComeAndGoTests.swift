import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A laptop and a monitor, as a line of a chaos script for each state they can be in.
private struct Desk: Sendable, CustomTestStringConvertible {
  var testDescription: String
  var both: String
  var laptop: String
  var external: String
  /// Two windows on the laptop (101, 102) and three on the monitor (103 to 105), of ordinary sizes.
  var windows: [String]

  func line(_ state: String) -> String {
    switch state {
    case "both": return both
    case "laptop": return laptop
    case "external": return external
    default: return "displays"
    }
  }

  static let laptopIsMain = Desk(
    testDescription: "the laptop is main, the monitor to its right",
    both: "displays main:0,0,1440,900:25,0,70,0* side:1440,0,2560,1440:25,0,0,0",
    laptop: "displays main:0,0,1440,900:25,0,70,0*",
    external: "displays side:0,0,2560,1440:25,0,70,0*",
    windows: [
      "open 101 Safari pid 1000 at 60 65 1000 600 min 574 240",
      "open 102 Notes pid 1001 at 300 225 800 500 min 709 300",
      "open 103 Mail pid 1002 at 1540 85 1100 700 min 760 400",
      "open 104 Terminal pid 1003 at 2140 325 877 499 min 177 60",
      "open 105 Finder pid 1005 at 1840 475 920 436 min 501 300",
    ])

  static let monitorIsMain = Desk(
    testDescription: "the monitor is main, the laptop to its left and lower",
    both: "displays main:-1512,200,1512,982:37,0,0,0 side:0,0,2560,1440:25,0,70,0*",
    laptop: "displays main:0,0,1512,982:37,0,70,0*",
    external: "displays side:0,0,2560,1440:25,0,70,0*",
    windows: [
      "open 101 Safari pid 1000 at -1452 277 1000 600 min 574 240",
      "open 102 Notes pid 1001 at -1212 437 800 500 min 709 300",
      "open 103 Mail pid 1002 at 100 85 1100 700 min 760 400",
      "open 104 Terminal pid 1003 at 700 325 877 499 min 177 60",
      "open 105 Finder pid 1005 at 400 475 920 436 min 501 300",
    ])
}

/// Every way from both displays back to both through one, two or three other states: 21.
private let waysThereAndBack: [String] = {
  let states = ["laptop", "external", "none"]
  var ways = states.map { [$0] }
  var all = ways
  for _ in 0..<2 {
    ways = ways.flatMap { way in states.filter { $0 != way.last }.map { way + [$0] } }
    all += ways
  }
  return all.map { $0.joined(separator: " ") }
}()

private let laptop = DisplayID("main")
private let monitor = DisplayID("side")
private let moment = ["settle", "react", "advance 1", "react"]

/// Displays that come and go while Arbor runs and NOTHING IS DOCKED (rule 2: nothing moves until the person docks something).
///
/// A display that goes leaves its windows as visitors on the one that stays. When that one goes in its turn, it remembers them
/// with everything else that was on it, and went on doing so after they had gone home: they "came back" with it. Back at the desk
/// after a day with the lid shut and an evening on the lap, Arbor took the browser off the laptop and put it on the monitor,
/// every time, whatever its person had done with it since.
@Suite @MainActor struct DisplaysComeAndGoTests {
  /// Plays `lines`. No net may speak but of what is known. Returns the world.
  @discardableResult
  private func play(
    _ lines: [String], in runner: ChaosRunner = ChaosRunner(), sourceLocation: SourceLocation = #_sourceLocation
  ) -> ChaosRunner {
    for line in lines {
      let violations = runner.step(ChaosAction(text: line)).filter { !ChaosRunner.knownRules.contains($0.rule) }
      #expect(violations.isEmpty, "\(line): \(violations)", sourceLocation: sourceLocation)
    }
    return runner
  }

  private func frames(_ runner: ChaosRunner) -> [WindowID: CGRect] { runner.system.windows.mapValues(\.snapshot.frame) }

  /// The display that shows most of `frame`.
  private func display(showing frame: CGRect, in runner: ChaosRunner) -> DisplayID? {
    runner.system.displayList.max { frame.intersection($0.frame).area < frame.intersection($1.frame).area }
      .flatMap { frame.overlaps($0.frame) ? $0.id : nil }
  }

  // MARK: All 21 ways there and back, in all four orders in which Arbor can hear of it

  @Test(arguments: waysThereAndBack, [ChaosAction.WindowsFollow.between, .late, .silent, .first])
  func noWindowIsSentToADisplayThatIsNotItsOwn(way: String, order: ChaosAction.WindowsFollow) {
    for desk in [Desk.laptopIsMain, .monitorIsMain] {
      // `between` is how nearly all windows were recorded speaking on hosted Macs: macOS's own list is the new one already, which
      // Arbor sees (`knowsTheDisplays`). It holds like `late` and `silent`.
      // ANOTHER FAULT, older than this table and not cured with it: where a window speaks while macOS's list is still the old
      // one, a move macOS makes because a corner is about to change is judged by the displays as they still stand. In `first` all
      // windows speak so, which no recording shows; that ONE does is common (`oneWindowSpeaksBeforeTheListOfDisplaysChanges`). If that puts it across a border, the window
      // counts as the other display's own from then on, and is fetched there later, or left there. Which windows it hits has
      // changed with "home is the display it left first" (it used to be whichever display came back last), not how many.
      // Not after "none": there is nothing to judge by. Only that kind of failure passes. Strict: whoever cures a cell is told so.
      // But for the seven that another change on its way cures (#52, a display that changes side and shrinks): those may hold or
      // not, so that the two can land in either order.
      let curedElsewhere = desk.testDescription == Desk.laptopIsMain.testDescription && way.hasPrefix("external")
      withKnownIssue("a move reported before the displays change is judged by the old ones", isIntermittent: curedElsewhere) {
        thereAndBack(by: way, order: order, at: desk)
      } when: {
        order == .first && !way.hasPrefix("none")
      } matching: { issue in
        issue.comments.contains { $0.rawValue.contains("Arbor sent") || $0.rawValue.contains("ends on another display") }
      }
    }
  }

  private func thereAndBack(by way: String, order: ChaosAction.WindowsFollow, at desk: Desk) {
    let runner = play(["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"])
    let began = frames(runner)
    let home = began.mapValues { display(showing: $0, in: runner)! }
    for state in way.split(separator: " ").map(String.init) + ["both"] {
      let mark = runner.system.frameLog.count
      play(["\(desk.line(state)) windows-\(order.rawValue)"] + moment, in: runner)
      let connected = Set(runner.system.displayList.map(\.id))
      // What ARBOR did. While a window's own display is away it has to be somewhere; while it is there, nowhere else.
      for (window, frame) in runner.system.frameLog[mark...] where connected.contains(home[window]!) {
        #expect(
          display(showing: frame, in: runner) == home[window]!,
          "\(desk.testDescription), at \(state): Arbor sent \(window), which began on \(home[window]!), to \(frame)")
      }
      // Nothing is docked and no view is framed: nothing is out of view, ever.
      if !connected.isEmpty { #expect(runner.controller.parked.isEmpty, "\(desk.testDescription), at \(state)") }
    }
    // There and back is nothing, to the point. Where the windows speak first, where exactly is another story (macOS fits what it
    // moves, and that passes for somebody's doing); which display is not.
    for (window, frame) in frames(runner).sorted(by: { $0.key < $1.key }) {
      if order != .first {
        #expect(frame == began[window], "\(desk.testDescription): \(window) began at \(began[window]!)")
      } else {
        #expect(
          display(showing: frame, in: runner) == home[window]!,
          "\(desk.testDescription): \(window), which began on \(home[window]!), ends on another display, at \(frame)")
      }
    }
    #expect(runner.controller.dormant.isEmpty, "\(desk.testDescription): both displays are here, so nothing is remembered for later")
  }

  // MARK: macOS remembers too

  /// On the one kind of display anybody has recorded, a virtual one on a hosted Mac, macOS itself puts a display's windows back on it, at
  /// their old frames, 0.15 to 0.2 s after it is there and a second and a half before Arbor is told. The lab's macOS never does.
  /// Played so, on all 21 ways: whenever a window's own display is there, macOS has it where it was on it by the time Arbor
  /// hears. Then nothing in this suite leans on Arbor's fetching: Arbor finds every window in place and moves none, at any step
  /// at which a display comes. (The controller before this suite's fix moved the laptop's windows onto the monitor all the same.)
  @Test(arguments: waysThereAndBack)
  func whereMacOSPutsWindowsBackItselfArborMovesNothing(way: String) {
    for desk in [Desk.laptopIsMain, .monitorIsMain] {
      let runner = play(["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"])
      let began = frames(runner)
      let corner = Dictionary(uniqueKeysWithValues: runner.system.displayList.map { ($0.id, $0.frame.origin) })
      let home = began.mapValues { display(showing: $0, in: runner)! }
      var connected = Set(corner.keys)
      for state in way.split(separator: " ").map(String.init) + ["both"] {
        let line = "\(desk.line(state)) windows-between"
        guard case .displays(let next, _) = ChaosAction(text: line) else {
          Issue.record("\(line)")
          return
        }
        // What macOS does by itself, with its list new already and Arbor not told yet.
        let old = runner.system.displayList
        var places: [WindowID: CGRect] = [:]
        for (window, frame) in began.sorted(by: { $0.key < $1.key }) {
          if let own = next.first(where: { $0.id == home[window]! }) {
            places[window] = frame.offsetBy(dx: own.frame.minX - corner[own.id]!.x, dy: own.frame.minY - corner[own.id]!.y)
          } else {
            places[window] = whereMacOSTakes(window, when: next, in: runner)
          }
        }
        runner.system.displayList = next
        for (window, place) in places.sorted(by: { $0.key < $1.key }) where place != frames(runner)[window] {
          runner.system.userMove(window, to: place)
        }
        let found = frames(runner)
        let mark = runner.system.frameLog.count
        play([line] + moment, in: runner)
        let came = !Set(next.map(\.id)).subtracting(connected).isEmpty && Set(old.map(\.id)).isSubset(of: Set(next.map(\.id)))
        connected = Set(next.map(\.id))
        // Where a display only comes, and none goes: every window is where it belongs already.
        if came {
          for (window, frame) in runner.system.frameLog[mark...] {
            #expect(frame == found[window], "\(desk.testDescription), at \(state): Arbor moved \(window) from \(found[window]!) to \(frame)")
          }
        }
      }
      #expect(frames(runner) == began, "\(desk.testDescription)")
      #expect(runner.controller.dormant.isEmpty)
    }
  }

  // MARK: One window speaks early

  /// Where macOS takes `window` when the displays become `displays`: along with its display, or onto the main one, fitted.
  private func whereMacOSTakes(_ window: WindowID, when displays: [DisplaySnapshot], in runner: ChaosRunner) -> CGRect? {
    guard let frame = frames(runner)[window], let main = displays.first(where: \.isMain) ?? displays.first,
      let home = runner.system.displayList.max(by: { frame.intersection($0.frame).area < frame.intersection($1.frame).area })
    else { return nil }
    let destination = displays.first { $0.id == home.id } ?? main
    let moved = frame.offsetBy(dx: destination.frame.minX - home.frame.minX, dy: destination.frame.minY - home.frame.minY)
    return destination.id == home.id ? moved : moved.fitted(into: destination.visibleFrame)
  }

  /// With real apps hosted Macs were recorded speaking in both orders within one change: in 10 of 13, one window, often the one with
  /// the keyboard, said where macOS had taken it a moment BEFORE macOS's list of displays changed, and the others after.
  ///
  /// Every other window is where it began, in all 84 cells. The early speaker is not in 30: the older fault of the table above, for that
  /// one window, where its new place lies across a border of the displays as they still stand. (The controller before this
  /// suite's fix: 126 windows elsewhere, in 59 cells.) Strict, but for the eleven cells that #52 cures.
  @Test(arguments: waysThereAndBack, [101, 103])
  func oneWindowSpeaksBeforeTheListOfDisplaysChanges(way: String, early: Int) {
    for desk in [Desk.laptopIsMain, .monitorIsMain] {
      let laptopIsMain = desk.testDescription == Desk.laptopIsMain.testDescription
      let crossesABorder =
        laptopIsMain
        ? early == 103 && (!way.hasPrefix("none") || ["none external", "none laptop external"].contains(way))
        : early == 101 && !way.hasPrefix("none")
      let curedElsewhere =
        laptopIsMain
        ? ["external laptop", "external laptop none", "external none", "external none laptop"].contains(way) : way.hasPrefix("laptop")
      withKnownIssue("a move reported before the displays change is judged by the old ones", isIntermittent: curedElsewhere) {
        thereAndBack(by: way, at: desk, early: WindowID(UInt32(early)))
      } when: {
        crossesABorder
      } matching: { issue in
        issue.comments.contains { $0.rawValue.contains("w\(early) began at") }
      }
    }
  }

  private func thereAndBack(by way: String, at desk: Desk, early: WindowID) {
    do {
      let runner = play(["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"])
      let began = frames(runner)
      for state in way.split(separator: " ").map(String.init) + ["both"] {
        let line = "\(desk.line(state)) windows-between"
        if case .displays(let next, _) = ChaosAction(text: line), let to = whereMacOSTakes(early, when: next, in: runner), to != frames(runner)[early] {
          play(["move \(early.rawValue) \(Int(to.minX)) \(Int(to.minY)) \(Int(to.width)) \(Int(to.height))"], in: runner)
        }
        play([line] + moment, in: runner)
      }
      for (window, frame) in frames(runner).sorted(by: { $0.key < $1.key }) {
        #expect(frame == began[window], "\(desk.testDescription): \(window) began at \(began[window]!), ends at \(frame)")
      }
    }
  }

  // MARK: The day as it was found

  private let desk = Desk.laptopIsMain
  private let safari = WindowID(101)
  private let whereSafariIs = CGRect(x: 60, y: 65, width: 1000, height: 600)

  /// Both displays, Safari on the laptop; the lid is shut; later the laptop alone. `then` is what happens on the lap.
  private func backAtTheDesk(after then: [String] = [], order: String = "late") -> ChaosRunner {
    play(
      ["\(desk.both) windows-never", desk.windows[0], "launch", "settle"]
        + ["\(desk.external) windows-\(order)", "settle", "\(desk.laptop) windows-\(order)", "settle"] + then
        + ["\(desk.both) windows-\(order)", "settle"])
  }

  @Test(arguments: ["between", "late", "silent", "first"])
  func backAtTheDeskTheBrowserStaysOnTheLaptop(order: String) {
    #expect(frames(backAtTheDesk(order: order))[safari] == whereSafariIs)
  }

  /// The control: the same day without Arbor.
  @Test func withoutArborItStaysToo() {
    let runner = play(
      ["\(desk.both) windows-never", desk.windows[0], "settle", "\(desk.external) windows-late", "settle"]
        + ["\(desk.laptop) windows-late", "settle", "\(desk.both) windows-late", "settle"])
    #expect(frames(runner)[safari] == whereSafariIs)
  }

  @Test func draggedOnTheLapItStaysWhereItWasDropped() {
    let runner = backAtTheDesk(after: ["grab 101", "carry 700 300", "release", "react", "advance 1", "react"])
    #expect(display(showing: frames(runner)[safari]!, in: runner) == laptop)
    #expect(frames(runner)[safari]!.size == whereSafariIs.size)
    #expect(frames(runner)[safari] != whereSafariIs, "it was dragged")
  }

  @Test func resizedOnTheLapItKeepsThatSize() {
    let runner = backAtTheDesk(after: ["edge 101 60 65 900 500", "react", "advance 1", "react"])
    #expect(frames(runner)[safari] == CGRect(x: 60, y: 65, width: 900, height: 500))
  }

  @Test func afterAQuitAndAStartOnTheLapItStaysToo() {
    #expect(frames(backAtTheDesk(after: ["quit", "launch", "settle"]))[safari] == whereSafariIs)
  }

  /// The laptop alone is something Arbor never saw: it was not running, had crashed, or was paused.
  @Test(arguments: [["quit"], ["crash"], ["toggle-pause", "react", "advance 1", "react"]])
  func withTheLidOpenedBehindArborsBackItStaysToo(ending: [String]) {
    let again = ending[0] == "toggle-pause" ? ending : ["launch", "settle"]
    // In pieces, here and further down: as one sum Swift 6.2 gives up on it ("unable to type-check this expression in reasonable time").
    var lines = ["\(desk.both) windows-never", desk.windows[0], "launch", "settle", "\(desk.external) windows-late"] + moment + ending
    lines += ["\(desk.laptop) windows-silent"] + again
    lines += ["\(desk.both) windows-late"] + moment
    let runner = play(lines)
    #expect(frames(runner)[safari] == whereSafariIs)
  }

  /// And on from there: what was remembered at that start must not make the laptop forget its own windows. (It never did: a guard
  /// against a first attempt at the fault, which took a stale claim for the elder one.)
  @Test func norDoesTheLaptopForgetItsOwnAfterSuchAStart() {
    let runner = play(
      ["\(desk.both) windows-never"] + desk.windows + ["launch", "settle", "\(desk.external) windows-late"] + moment
        + ["quit", "\(desk.laptop) windows-late", "launch", "settle", "\(desk.external) windows-late"] + moment)
    let began = [safari: whereSafariIs, WindowID(102): CGRect(x: 300, y: 225, width: 800, height: 500)]
    play(["\(desk.both) windows-late"] + moment, in: runner)
    for (window, frame) in began { #expect(frames(runner)[window] == frame) }
  }

  @Test func dayAfterDay() {
    let day = ["\(desk.external) windows-late", "settle", "\(desk.laptop) windows-late", "settle", "\(desk.both) windows-late", "settle"]
    let runner = play(["\(desk.both) windows-never", desk.windows[0], "launch", "settle"] + day + day + day)
    #expect(frames(runner)[safari] == whereSafariIs)
  }

  /// With the monitor's view on one window the visitor did not change display: it went out of view.
  @Test func withTheMonitorsViewFramedNothingOfTheLaptopsGoesOutOfView() {
    func key(_ name: String) -> [String] { ["key down \(name)", "key up \(name)", "react", "advance 1", "react"] }
    func focus(_ window: Int) -> [String] { ["focus \(window)", "react", "advance 1", "react"] }
    var lines = ["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"]
    lines += focus(101) + key("dock left") + focus(103) + key("dock left")
    lines += focus(104) + key("dock right") + focus(103) + key("zoom")
    let runner = play(lines + ["settle"])
    let notes = WindowID(102)
    let began = frames(runner)[notes]!
    for state in ["external", "laptop", "both"] { play(["\(desk.line(state)) windows-late"] + moment, in: runner) }
    #expect(!runner.controller.parked.contains(notes))
    #expect(frames(runner)[notes] == began)
  }

  // MARK: What goes on holding

  /// A window that floated on the monitor is the monitor's own, and goes back with it (F08), also by way of a shut lid.
  @Test(arguments: ["laptop", "laptop external", "external laptop", "laptop none", "none laptop external"])
  func whatFloatedOnTheMonitorGoesBackWithIt(way: String) {
    let runner = play(["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"])
    let began = frames(runner)
    for state in way.split(separator: " ").map(String.init) + ["both"] {
      play(["\(desk.line(state)) windows-late"] + moment, in: runner)
    }
    for window in [103, 104, 105].map({ WindowID(UInt32($0)) }) {
      #expect(frames(runner)[window] == began[window])
      #expect(runner.controller.workspaces[monitor]?.isFloating(window) == true)
    }
  }

  // MARK: A visitor is where and what it was after a blink

  // These held before, and are here because a first attempt at the fault broke them: it made a display that goes forget its visitors.

  /// Safari visits the monitor, the lid being shut. `then` happens; the monitor blinks: no display, and back.
  private func visitorThroughABlink(_ then: [String]) -> ChaosRunner {
    var lines = ["\(desk.both) windows-never"] + desk.windows + ["launch", "settle", "\(desk.external) windows-late"]
    lines += moment + then + moment
    lines += ["displays windows-late"] + moment
    lines += ["\(desk.external) windows-late"] + moment
    return play(lines)
  }

  @Test func aVisitorPinnedByItsPersonIsStillPinned() {
    #expect(visitorThroughABlink(["pin 101"]).controller.workspaces[monitor]?.isPinned(safari) == true)
  }

  /// Pinned there, it was told to stay there (F49: a window pinned meanwhile stays where it was pinned), and is the monitor's from then
  /// on, every day alike. So is the mirror case: Mail pinned on the lap is the laptop's.
  @Test func pinnedWhileVisitingItBelongsWhereItWasPinned() {
    let day = [desk.laptop, desk.both, desk.external, desk.both, desk.laptop, desk.both].flatMap { ["\($0) windows-late"] + moment }
    let runner = play(
      ["\(desk.both) windows-never"] + desk.windows + ["launch", "settle", "\(desk.external) windows-late"] + moment + ["pin 101"] + moment)
    let pinnedAt = frames(runner)[safari]!.offsetBy(dx: 1440, dy: 0)
    play(day, in: runner)
    #expect(frames(runner)[safari] == pinnedAt)
    #expect(runner.controller.workspaces[monitor]?.isPinned(safari) == true)
  }

  @Test func aVisitorSentAwayStaysAway() {
    let runner = visitorThroughABlink(["summon Safari"] + moment + ["summon Safari"])
    #expect(runner.controller.workspaces[monitor]?.isStashed(safari) == true)
    #expect(runner.controller.parked.contains(safari))
  }

  @Test func aVisitorInFullScreenGetsItsOwnSizeBack() {
    let runner = visitorThroughABlink(["full-screen 101 on"])
    play(["full-screen 101 off"] + moment, in: runner)
    #expect(frames(runner)[safari]?.size == whereSafariIs.size)
  }

  /// Its own display stays away: the monitor at the office. At home another one is plugged in, the lid is shut and opened. Mail has sat
  /// on the laptop since the office, and there it is again: there and back is nothing, for a visitor too.
  @Test func aVisitorWhoseOwnDisplayStaysAwayGoesBackToWhereItWaited() {
    let home = "home:1440,0,1920,1080:25,0,0,0"
    let runner = play(
      ["displays main:0,0,1440,900:25,0,70,0* office:1440,0,2560,1440:25,0,0,0 windows-never", desk.windows[0], desk.windows[2]]
        + ["launch", "settle", "\(desk.laptop) windows-late"] + moment)
    let waited = frames(runner)[mail]!
    play(
      ["\(desk.laptop) \(home) windows-late"] + moment + ["displays home:0,0,1920,1080:25,0,70,0* windows-late"] + moment
        + ["\(desk.laptop) \(home) windows-late"] + moment, in: runner)
    #expect(frames(runner)[mail] == waited)
    #expect(frames(runner)[safari] == whereSafariIs)
  }

  /// No time need pass between two changes for Arbor to know which display a window left first.
  @Test(arguments: ["laptop none", "external none", "laptop external", "external laptop"])
  func whichDisplayWentFirstIsKnownThoughNoTimePassed(way: String) {
    let runner = play(["\(desk.both) windows-never"] + desk.windows + ["launch", "settle"])
    let began = frames(runner)
    for state in way.split(separator: " ").map(String.init) + ["both"] { play(["\(desk.line(state)) windows-late", "settle"], in: runner) }
    #expect(frames(runner) == began)
  }

  // MARK: Where a window is outranks what Arbor remembers of it

  private let mail = WindowID(103)
  private let whereMailWas = CGRect(x: 1540, y: 85, width: 1100, height: 700)

  /// Mail floats on the monitor, which is unplugged; `then` is what happens on the lap; the monitor is plugged in again.
  private func monitorUnpluggedAndBack(_ before: [String] = [], meanwhile then: [String]) -> ChaosRunner {
    var lines = ["\(desk.both) windows-never", desk.windows[2], "launch", "settle"] + before
    lines += ["\(desk.laptop) windows-late"] + moment + then
    lines += ["\(desk.both) windows-late"] + moment
    return play(lines)
  }

  @Test func whatItsPersonDraggedMeanwhileStaysWhereItWasDropped() {
    let runner = monitorUnpluggedAndBack(meanwhile: ["grab 103", "carry 500 200", "release", "react", "advance 1", "react"])
    #expect(display(showing: frames(runner)[mail]!, in: runner) == laptop)
    #expect(runner.controller.workspaces[laptop]?.isFloating(mail) == true)
    #expect(runner.controller.dormant.isEmpty)
  }

  @Test func whatItsPersonSizedMeanwhileKeepsPlaceAndSize() {
    let runner = monitorUnpluggedAndBack(meanwhile: ["edge 103 100 85 900 600", "react", "advance 1", "react"])
    #expect(frames(runner)[mail] == CGRect(x: 100, y: 85, width: 900, height: 600))
    #expect(runner.controller.workspaces[laptop]?.isFloating(mail) == true)
  }

  /// Sent to another display by its person's own command, it belongs there.
  @Test func whatItsPersonSentToAnotherDisplayStaysThere() {
    let three = "displays main:0,0,1440,900:25,0,70,0* side:1440,0,2560,1440:25,0,0,0 third:4000,0,1920,1080:25,0,0,0"
    let runner = play(
      ["\(three) windows-never", desk.windows[0], desk.windows[2], "launch", "settle"]
        + ["displays side:0,0,2560,1440:25,0,70,0* third:2560,0,1920,1080:25,0,0,0 windows-late"] + moment
        + ["move-to-display next 101"] + moment)
    #expect(display(showing: frames(runner)[safari]!, in: runner) == DisplayID("third"))
    let sentTo = frames(runner)[safari]!.offsetBy(dx: 1440, dy: 0)
    play(["\(three) windows-late"] + moment, in: runner)
    #expect(frames(runner)[safari] == sentTo)
  }

  /// The hand's word is on file: a crash a minute later does not bring the claim back.
  @Test func whatItsPersonSizedLastsThroughACrash() {
    let runner = monitorUnpluggedAndBack(meanwhile: [
      "edge 103 100 85 900 600 hold", "react", "advance 3", "react", "release", "react", "advance 60", "react", "crash", "launch", "settle",
    ])
    #expect(frames(runner)[mail] == CGRect(x: 100, y: 85, width: 900, height: 600))
  }

  /// The control for those above, and for what no hand did: an app, a tool or macOS itself speaks of a move in the same words,
  /// also just before anybody can know that the displays are changing. That ends nothing.
  @Test(arguments: [[], ["move 103 140 120 1100 700", "react", "advance 1", "react"]])
  func whatNoHandTouchedGoesBack(meanwhile: [String]) {
    #expect(frames(monitorUnpluggedAndBack(meanwhile: meanwhile))[mail] == whereMailWas)
  }

  /// A pin goes by the same rule (F49): back to its exact frame, still pinned; dragged meanwhile, it stays, still pinned.
  @Test func aPinGoesByTheSameRule() {
    let back = monitorUnpluggedAndBack(["pin 103", "settle"], meanwhile: [])
    #expect(frames(back)[mail] == whereMailWas)
    #expect(back.controller.workspaces[monitor]?.isPinned(mail) == true)
    let stays = monitorUnpluggedAndBack(
      ["pin 103", "settle"], meanwhile: ["grab 103", "carry 500 200", "release", "react", "advance 1", "react"])
    #expect(display(showing: frames(stays)[mail]!, in: stays) == laptop)
    #expect(stays.controller.workspaces[laptop]?.isPinned(mail) == true)
  }

  /// Docked on the monitor, it has a place in an arrangement its person made. A nudge to the stand-in on the lap does not end that.
  @Test func whatWasDockedGoesBackToItsSlotEvenIfDraggedMeanwhile() {
    let dock = ["focus 103", "react", "advance 1", "react", "key down dock left", "key up dock left", "react", "advance 1", "react"]
    let runner = play(["\(desk.both) windows-never", desk.windows[2], "launch", "settle"] + dock)
    let slot = frames(runner)[mail]!
    play(
      ["\(desk.laptop) windows-late"] + moment + ["grab 103", "carry 500 200", "release", "react", "advance 1", "react"]
        + ["\(desk.both) windows-late"] + moment, in: runner)
    #expect(runner.controller.workspaces[monitor]?.isDocked(mail) == true)
    #expect(frames(runner)[mail] == slot)
  }

  /// macOS remembers too. What it has brought back to within a few points gets no second move for nothing.
  @Test(arguments: [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: -2), CGPoint(x: -20, y: 30)])
  func whatMacOSHasBroughtBackItselfIsNotMovedAgain(off: CGPoint) {
    let main = FakeWindowSystem.standardDisplay
    let side = DisplaySnapshot(
      id: monitor, frame: CGRect(x: 1440, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      isMain: false)
    let h = Harness(displays: [main, side])
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    h.start()
    h.system.setDisplays([main])
    // The display is there, macOS acts, and Arbor hears of the display only once things have settled.
    h.system.displayList = [main, side]
    let broughtBack = spot.offsetBy(dx: off.x, dy: off.y)
    h.system.userMove(d, to: broughtBack)
    h.system.clearFrameLog()
    h.system.setDisplays([main, side])
    h.scheduler.advance(by: 3)
    let near = abs(off.x) <= 4 && abs(off.y) <= 4
    #expect(h.system.frameLog.allSatisfy { $0.frame == (near ? broughtBack : spot) }, "\(h.system.frameLog)")
    #expect(h.frame(d) == (near ? broughtBack : spot))
    #expect(h.controller.workspaces[side.id]?.floating[d] == (near ? broughtBack : spot))
    #expect(!h.controller.parked.contains(d))
  }

  /// The same with no app saying a word: the window is simply not where Arbor knew it.
  @Test func whatMacOSHasBroughtBackWithoutAWordIsNotMovedAgainEither() {
    let runner = play(["\(desk.both) windows-never", desk.windows[2], "launch", "settle", "\(desk.laptop) windows-late"] + moment)
    let broughtBack = whereMailWas.offsetBy(dx: -3, dy: 2)
    runner.system.moveSilently(mail, to: broughtBack)
    play(["\(desk.both) windows-never"] + moment, in: runner)
    #expect(frames(runner)[mail] == broughtBack)
  }

  /// At its own size only. Three points lower than the laptop can show, it was fitted there; back on the monitor it is as high as it was.
  @Test func whatWasFittedMeanwhileGetsItsOwnSizeBack() {
    let monitorAlone = "displays side:0,0,2560,1440:25,0,70,0*"
    let own = CGRect(x: 100, y: 25, width: 1100, height: 809)
    let runner = play(["\(monitorAlone) windows-never", "open 103 Mail pid 1002 at 100 25 1100 809 min 760 400", "launch", "settle"])
    for _ in 0..<2 {
      play(["displays main:0,0,1440,900:24,0,70,0* windows-late"] + moment + ["\(monitorAlone) windows-late"] + moment, in: runner)
      #expect(frames(runner)[mail] == own)
    }
  }

  /// Only what macOS moved. Alone, either display has its corner at 0,0, so where a window waited on the one can be as good as its place
  /// on the other. Taken for its place, it would creep: here by the point the two menu bars differ by, every day.
  @Test func whereItOnlyWaitedIsNotItsPlace() {
    let monitorAlone = "displays side:0,0,2560,1440:25,0,70,0*"
    let runner = play(["\(monitorAlone) windows-never", "open 103 Mail pid 1002 at 100 185 1100 600 min 760 400", "launch", "settle"])
    for _ in 0..<6 {
      play(["displays main:0,0,1440,900:24,0,70,0* windows-late"] + moment + ["\(monitorAlone) windows-late"] + moment, in: runner)
      #expect(frames(runner)[mail] == CGRect(x: 100, y: 185, width: 1100, height: 600))
    }
  }

  /// Docked on the lap, a visitor of old belongs to the laptop's arrangement.
  @Test func dockedOnTheLapItStaysDockedThere() {
    let runner = backAtTheDesk(after: [
      "focus 101", "react", "advance 1", "react", "key down dock left", "key up dock left", "react", "advance 1", "react",
    ])
    #expect(runner.controller.workspaces[laptop]?.isDocked(safari) == true)
    #expect(display(showing: frames(runner)[safari]!, in: runner) == laptop)
  }
}
