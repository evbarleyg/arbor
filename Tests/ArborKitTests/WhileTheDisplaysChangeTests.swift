import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Arbor hears of a change of displays only once it has settled, a second and a half after macOS's last notice
/// (`DisplayChange`). On every recording of a hosted Mac the list of displays is new, and macOS's own moves of the windows are
/// over, within a third of a second. A person who presses one of Arbor's keys in the time that is left is looking at
/// the displays that are, and was answered by the ones Arbor still believed in: windows went to slots and corners on a display that
/// was gone and were fetched again at the report, and the key acted on an arrangement that was about to go to sleep.
///
/// As in every other wait of Arbor's: the key is taken, nothing moves, and a line says why.
@Suite @MainActor struct WhileTheDisplaysChangeTests {
  static let side = LookBeforeLettingGoTests.side
  static let refused = "the displays are still changing: nothing was done; ask again in a moment"

  /// What happens to the displays, with what macOS does to the windows by itself, which their apps report as any move.
  enum Change: String, CaseIterable, CustomTestStringConvertible {
    case theSideGoes, theLidShuts, theSideChangesSides, theSideShrinks, theSideComes
    var testDescription: String { rawValue }
  }

  struct Desk {
    var h: Harness
    /// Two to dock and one that floats, on each display: 101 to 103, 104 to 106.
    var onTheLaptop: [WindowID]
    var onTheSide: [WindowID]
    var all: [WindowID] { onTheLaptop + onTheSide }
  }

  enum Arrangement: String, CaseIterable, CustomTestStringConvertible {
    case nothingDocked, docked, framed
    var testDescription: String { rawValue }
  }

  /// Arbor as it ships, unless a test needs a key that is none of the nine: the minimap's.
  func make(_ arrangement: Arrangement, before change: Change? = nil, settings: Settings = Harness.settingsWhenNoneAreGiven) -> Desk {
    let h = Harness(
      displays: change == .theSideComes ? [FakeWindowSystem.standardDisplay] : [FakeWindowSystem.standardDisplay, Self.side], settings: settings)
    func open(_ count: Int, from x: CGFloat, pid: Int32) -> [WindowID] {
      (0..<count).map { index in
        h.system.open(
          app: "App\(pid + Int32(index))", pid: pid + Int32(index),
          frame: CGRect(x: x + 90 * CGFloat(index), y: 100 + 60 * CGFloat(index), width: 480, height: 348))
      }
    }
    let desk = Desk(h: h, onTheLaptop: open(3, from: 100, pid: 1001), onTheSide: change == .theSideComes ? [] : open(3, from: 1600, pid: 1011))
    h.start()
    if arrangement != .nothingDocked {
      for windows in [desk.onTheSide, desk.onTheLaptop] where !windows.isEmpty {
        h.system.cursor = h.frame(windows[0])!.center
        h.run("dock \(windows[0].rawValue) left")
        h.run("dock \(windows[1].rawValue) right")
        if arrangement == .framed { h.run("zoom \(windows[0].rawValue)") }
      }
    }
    // The pointer and the keyboard are on the laptop.
    h.system.cursor = CGPoint(x: 700, y: 600)
    h.system.userFocus(desk.onTheLaptop[0])
    h.scheduler.advance(by: 5)
    return desk
  }

  /// macOS has other displays from here on, and Arbor is not told.
  func quietly(_ h: Harness, _ change: () -> Void) {
    let listener = h.system.events
    h.system.events = nil
    change()
    h.system.events = listener
  }

  /// The list is new at once; macOS moves what it moves, and the apps say so; nobody has told Arbor of the displays.
  func happen(_ change: Change, to desk: Desk) {
    let h = desk.h
    /// Onto the display that stays, as far from its corner as they were from their own.
    func bringOver(_ windows: [WindowID], by dx: CGFloat) {
      for window in windows { h.system.userMove(window, to: h.frame(window)!.offsetBy(dx: dx, dy: 0)) }
    }
    switch change {
    case .theSideGoes:
      quietly(h) { h.system.unplug(Self.side.id) }
      bringOver(desk.onTheSide, by: -1440)
    case .theLidShuts:
      // Every coordinate is another, of which no app speaks; what was on the laptop lies to the left of all there is.
      quietly(h) { h.system.unplug(h.display) }
      bringOver(desk.onTheLaptop, by: 1440)
    case .theSideChangesSides:
      quietly(h) { h.system.moveDisplay(Self.side.id, to: CGPoint(x: -1920, y: 0)) }
      for window in desk.onTheSide { h.system.report(window, userInitiated: true) }
    case .theSideShrinks:
      var smaller = Self.side
      smaller.frame.size = CGSize(width: 1280, height: 720)
      smaller.visibleFrame.size = smaller.frame.size
      quietly(h) { h.system.plug(smaller) }
    case .theSideComes:
      quietly(h) { h.system.plug(Self.side) }
    }
    // The pointer cannot stay where there is no display any more.
    if !h.system.displayList.contains(where: { $0.frame.contains(h.system.cursor) }) {
      let nearest = h.system.displayList.min { $0.frame.distance(to: h.system.cursor) < $1.frame.distance(to: h.system.cursor) }!.frame
      h.system.cursor = CGPoint(
        x: min(max(h.system.cursor.x, nearest.minX), nearest.maxX - 1), y: min(max(h.system.cursor.y, nearest.minY), nearest.maxY - 1))
    }
    h.scheduler.advance(by: 0.4)
  }

  /// The report, when the displays have settled.
  func tell(_ h: Harness) { h.system.setDisplays(h.system.displayList) }

  /// Whatever moves or sizes a window, changes who is docked where, moves a view, lays out a display or opens a way to any of it: about
  /// windows of both displays, about none.
  static let commands = [
    "show-all", "home", "desktop", "out", "in", "back", "forward", "zoom 101", "zoom 104", "zoom 999", "view 1", "dock 103 left", "dock 106 bottom",
    "dock 103 beside 101 bottom", "float 101", "float 104", "toggle-float 102", "float-all", "float-all here", "arrange", "arrange all", "undo", "redo",
    "focus right", "focus 104", "focus-display next", "swap right", "swap 101 102", "equalize", "rotate", "mirror", "grow", "shrink", "resize 101 right 40",
    "move-to-display next", "move-to-display next 104", "pin 103", "unpin 103", "toggle-pin 106", "summon App1013", "reveal 102", "find App1012",
    "relayout", "reload-settings", "hold", "hold still", "release", "toggle-hold", "exclude com.example.app1001", "layout App1001 | App1002",
    "set gap 30", "set messages off", "name Work", "unname", "ask-name", "find", "minimap", "pass-through com.example.app1001 on", "toggle-auto-dock",
    "save-view 1", "show-shortcuts",
  ]

  /// All that a person can see or feel, and all that Arbor remembers of the arrangements.
  func expectTheSameEnd(_ one: Desk, _ other: Desk, _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
    for window in one.all {
      #expect(one.h.frame(window) == other.h.frame(window), "\(what): \(window)", sourceLocation: sourceLocation)
    }
    #expect(one.h.controller.workspaces == other.h.controller.workspaces, "\(what): the arrangements, the views, where windows float", sourceLocation: sourceLocation)
    #expect(one.h.controller.dormant.mapValues(\.workspace) == other.h.controller.dormant.mapValues(\.workspace), "\(what): what sleeps", sourceLocation: sourceLocation)
    #expect(one.h.controller.parked == other.h.controller.parked, "\(what): who is out of view", sourceLocation: sourceLocation)
    #expect(one.h.system.focused == other.h.system.focused, "\(what): who has the keyboard", sourceLocation: sourceLocation)
    #expect(one.h.run("undo").message == other.h.run("undo").message, "\(what): what can be undone", sourceLocation: sourceLocation)
  }

  // MARK: Refused, and nothing is done

  @Test(arguments: Arrangement.allCases, Change.allCases)
  func whatMovesWindowsOrViewsIsRefusedUntilArborHasHeardAndNothingIsDone(_ arrangement: Arrangement, _ change: Change) {
    for command in Self.commands {
      let desk = make(arrangement, before: change)
      let h = desk.h
      happen(change, to: desk)
      let (workspaces, parked, focused, mark) = (h.controller.workspaces, h.controller.parked, h.system.focused, h.system.frameLog.count)
      let answer = h.run(command)
      #expect(!answer.ok && answer.message == Self.refused, "`\(command)`: \(answer.message)")
      h.scheduler.advance(by: 1.3)
      #expect(h.system.frameLog.count == mark, "`\(command)`: \(h.system.frameLog[mark...])")
      #expect(h.controller.workspaces == workspaces && h.controller.parked == parked && h.system.focused == focused, "`\(command)`")
      tell(h)
      #expect(h.run(command).message != Self.refused, "`\(command)`: Arbor has heard")
    }
  }

  /// The key refused and pressed again when Arbor has heard, beside the key pressed only then.
  @Test(arguments: Arrangement.allCases, Change.allCases)
  func pressedAgainItEndsAsIfItHadBeenPressedOnlyThen(_ arrangement: Arrangement, _ change: Change) {
    func play(_ command: String, alsoWithin: Bool) -> Desk {
      let desk = make(arrangement, before: change)
      happen(change, to: desk)
      if alsoWithin { desk.h.run(command) }
      desk.h.scheduler.advance(by: 1.3)
      tell(desk.h)
      desk.h.scheduler.advance(by: 1)
      desk.h.run(command)
      desk.h.scheduler.advance(by: 5)
      return desk
    }
    for command in Self.commands {
      let twice = play(command, alsoWithin: true)
      expectWindowsMatchLayout(twice.h)
      expectTheSameEnd(twice, play(command, alsoWithin: false), "`\(command)`")
    }
  }

  /// The key that shows everything begins a peek, which performs no command.
  @Test(arguments: Arrangement.allCases) func theKeyThatShowsEverythingIsRefusedToo(_ arrangement: Arrangement) {
    let desk = make(arrangement, before: .theSideGoes)
    let h = desk.h
    happen(.theSideGoes, to: desk)
    let (workspaces, mark) = (h.controller.workspaces, h.system.frameLog.count)
    #expect(h.key("ctrl+opt+space")?.message == Self.refused)
    h.scheduler.advance(by: 1.3)
    #expect(h.system.frameLog.count == mark)
    #expect(h.controller.workspaces == workspaces)
    tell(h)
    h.scheduler.advance(by: 1)
    _ = h.key("ctrl+opt+space")
    h.scheduler.advance(by: 2)
    for window in desk.all { #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!)") }
  }

  /// By real presses, with the keyboard on one display and the pointer on another. A refused press is a command's press: taken for typing, it
  /// would turn the same key pressed again from the display pointed at to the one typed on.
  @Test(arguments: ["out", "in", "show-all", "desktop"]) func theSameKeyPressedAgainMeansTheSameDisplay(_ command: String) {
    func play(alsoWithin: Bool) -> Desk {
      let desk = make(.framed, before: .theSideShrinks)
      let h = desk.h
      h.system.userFocus(desk.onTheLaptop[0])
      h.system.type()
      h.scheduler.advance(by: 5)
      h.system.cursor = h.frame(desk.onTheSide[0])!.center
      h.scheduler.advance(by: 0.3)
      var third = Self.side
      (third.id, third.frame.origin.x, third.visibleFrame.origin.x) = (DisplayID("third"), -1920, -1920)
      quietly(h) { h.system.plug(third) }
      h.scheduler.advance(by: 0.3)
      if alsoWithin { #expect(h.press(command).message == Self.refused) }
      h.scheduler.advance(by: 1.3)
      tell(h)
      h.scheduler.advance(by: 0.5)
      #expect(h.press(command).message != Self.refused)
      h.scheduler.advance(by: 3)
      return desk
    }
    let (twice, once) = (play(alsoWithin: true), play(alsoWithin: false))
    #expect(twice.h.controller.workspaces.mapValues(\.camera) == once.h.controller.workspaces.mapValues(\.camera))
    expectTheSameEnd(twice, once, "`\(command)`")
  }

  /// By key, menu, gesture, script and link alike.
  @Test(arguments: [CommandSource.shortcut, .menu, .gesture, .script, .url]) func whoeverAsks(_ source: CommandSource) {
    let desk = make(.docked, before: .theSideGoes)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run("float-all", from: source).message == Self.refused)
  }

  /// Where it can be read: on a display that macOS has, as it stands now. The keyboard is on the display that goes, or on the one whose
  /// corner moves as the lid shuts, and the pointer has not been touched.
  @Test(arguments: [Change.theSideGoes, .theLidShuts, .theSideChangesSides, .theSideShrinks])
  func theLineOnScreenSaysWhyWhereItCanBeRead(_ change: Change) throws {
    let desk = make(.docked, before: change)
    let h = desk.h
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.system.userFocus(desk.onTheSide[0])
    h.scheduler.advance(by: 5)
    happen(change, to: desk)
    h.run("zoom 104", from: .shortcut)
    let shown = h.overlays.headsUp.compactMapValues { $0 }
    let (display, line) = try #require(shown.first)
    #expect(shown.count == 1)
    #expect(line.text == "The displays are still changing" && line.hint == "try again in a moment")
    let real = try #require(h.system.displayList.first { $0.id == display })
    #expect(real.visibleFrame.contains(line.anchor), "\(line.anchor) on \(real.visibleFrame)")
    #expect(real.frame.contains(h.system.cursor), "under the pointer")
    // It goes when Arbor has heard.
    h.scheduler.advance(by: 1.3)
    tell(h)
    #expect(h.overlays.headsUp.compactMapValues { $0 }.isEmpty)
  }

  /// With the pointer where no display is (any more): on the main one. And in the room the menu bar and the Dock leave.
  @Test func withThePointerNowhereTheLineIsOnTheMainDisplay() throws {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    var third = Self.side
    (third.id, third.frame.origin.x, third.visibleFrame.origin.x) = (DisplayID("third"), -1920, -1920)
    h.system.plug(third)
    h.scheduler.advance(by: 5)
    quietly(h) { h.system.unplug(Self.side.id) }
    h.system.cursor = CGPoint(x: 2000, y: 500)
    // The main one is not the first that macOS lists.
    quietly(h) { h.system.setDisplays(h.system.displayList.reversed()) }
    #expect(h.system.displayList.first?.isMain == false)
    h.run("zoom 101", from: .shortcut)
    let (display, line) = try #require(h.overlays.headsUp.compactMapValues { $0 }.first)
    #expect(display == h.system.displayList.first(where: \.isMain)?.id)
    #expect(line.text == "The displays are still changing")
  }

  /// The Dock of the display as it is now, which Arbor has not heard of either.
  @Test func theLineKeepsClearOfTheDockThatIsThere() throws {
    func anchor(dock: CGFloat) throws -> CGPoint {
      let desk = make(.docked, before: .theSideGoes)
      let h = desk.h
      var laptop = FakeWindowSystem.standardDisplay
      laptop.visibleFrame.size.height -= dock
      quietly(h) { h.system.setDisplays([laptop]) }
      h.run("zoom 101", from: .shortcut)
      return try #require(h.overlays.headsUp.compactMapValues { $0 }.first).value.anchor
    }
    #expect(try anchor(dock: 200).y == anchor(dock: 0).y - 200)
  }

  /// It keeps above a minimap on a display that stands where Arbor knows it, when it comes and when the minimap goes. On one that stands
  /// elsewhere by now, the minimap's place says nothing, and the line stays where it can be read when the minimap goes.
  @Test(arguments: [Change.theSideGoes, .theLidShuts]) func theLineAndAMinimap(_ change: Change) throws {
    func line(_ h: Harness) throws -> HeadsUpModel { try #require(h.overlays.headsUp.compactMapValues { $0 }.first).value }
    func play(withAMinimap: Bool) throws -> (Harness, HeadsUpModel) {
      let desk = make(.docked, before: change, settings: .withEveryKey)
      if withAMinimap { #expect(desk.h.key("ctrl+opt+m")?.ok == true) }
      happen(change, to: desk)
      desk.h.run("zoom 101", from: .shortcut)
      return (desk.h, try line(desk.h))
    }
    let (plain, (h, above)) = (try play(withAMinimap: false).1, try play(withAMinimap: true))
    let real = try #require(h.system.displayList.first { $0.frame.contains(h.system.cursor) })
    #expect(real.visibleFrame.contains(above.anchor))
    if change == .theSideGoes {
      #expect(above.anchor.y < plain.anchor.y, "the laptop stands where it stood: above its minimap")
    } else {
      #expect(above.anchor == plain.anchor)
    }
    // A click beside its tiles puts the minimap away, under the line.
    h.overlays.clickMinimap(at: CGPoint(x: 1, y: 1))
    #expect(h.overlays.minimaps[FakeWindowSystem.standardDisplay.id] == nil)
    #expect(try line(h).anchor == plain.anchor)
  }

  /// The minimap and the line on one display, which keeps its name and stands elsewhere by now. The minimap was drawn where the display stood: the
  /// line is not placed by it, neither when it comes nor when the minimap goes.
  @Test func theLineOnADisplayThatMovedUnderItsMinimap() throws {
    func line(_ h: Harness) throws -> HeadsUpModel { try #require(h.overlays.headsUp[Self.side.id] ?? nil) }
    func play(withAMinimap: Bool) throws -> Harness {
      let desk = make(.docked, before: .theSideChangesSides, settings: .withEveryKey)
      let h = desk.h
      h.system.cursor = h.frame(desk.onTheSide[0])!.center
      h.system.userFocus(desk.onTheSide[0])
      h.scheduler.advance(by: 5)
      if withAMinimap {
        #expect(h.key("ctrl+opt+m")?.ok == true)
        #expect(h.overlays.minimaps[Self.side.id] != nil)
      }
      quietly(h) { h.system.moveDisplay(Self.side.id, to: CGPoint(x: -1920, y: 0)) }
      h.system.cursor = h.frame(desk.onTheSide[0])!.center
      h.scheduler.advance(by: 0.3)
      h.run("zoom 104", from: .shortcut)
      return h
    }
    let (plain, h) = (try line(try play(withAMinimap: false)), try play(withAMinimap: true))
    let real = try #require(h.system.displayList.first { $0.id == Self.side.id })
    #expect(real.visibleFrame.contains(try line(h).anchor))
    #expect(try line(h).anchor == plain.anchor)
    h.overlays.clickMinimap(at: CGPoint(x: 1, y: 1), on: Self.side.id)
    #expect(h.overlays.minimaps[Self.side.id] == nil)
    #expect(try line(h).anchor == plain.anchor, "placed again, by the display as it stands")
  }

  /// A click on a tile goes where `zoom` would.
  @Test func aClickOnATileIsRefusedToo() throws {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    let (camera, node) = (h.workspace.camera, try #require(h.workspace.tree.leaf(containing: desk.onTheLaptop[0])))
    happen(.theSideGoes, to: desk)
    let mark = h.system.frameLog.count
    h.controller.tileActivated(display: h.display, node: node)
    #expect(h.workspace.camera == camera)
    #expect(h.system.frameLog.count == mark)
    #expect(h.overlays.headsUp.compactMapValues { $0 }.first?.value.text == "The displays are still changing")
  }

  // MARK: A display that only blinks

  /// What the wait is for. The display is gone, a key, the display is back as it was, and nobody ever reports anything. While the lists differ
  /// the key is refused; from the moment they are as they were nothing is. No arrangement went to sleep, and all ends as in the same
  /// blink with the key pressed only afterwards. (Not as with the displays standing still: macOS puts the windows back when the list is
  /// as Arbor knows it again, which passes for a hand's doing. An older fault, and no part of this story.)
  @Test(arguments: Arrangement.allCases, [0.1, 0.6, 1.9])
  func inABlinkTheKeyIsRefusedOnlyWhileTheDisplayIsAway(_ arrangement: Arrangement, backAfter seconds: Double) {
    func play(_ command: String, alsoWithin: Bool) -> Desk {
      let desk = make(arrangement)
      let h = desk.h
      let (before, workspaces) = (desk.onTheSide.map { h.frame($0)! }, h.controller.workspaces)
      happen(.theSideGoes, to: desk)
      if alsoWithin { #expect(h.run(command).message == Self.refused, "`\(command)`") }
      h.scheduler.advance(by: seconds)
      #expect(h.controller.workspaces == workspaces, "`\(command)`")
      // macOS puts back what it took over, as recorded.
      quietly(h) { h.system.plug(Self.side) }
      for (window, frame) in zip(desk.onTheSide, before) { h.system.userMove(window, to: frame) }
      #expect(h.run(command).message != Self.refused, "`\(command)`: at once")
      h.scheduler.advance(by: 8)
      #expect(h.controller.dormant.isEmpty, "`\(command)`")
      #expect(h.controller.displays.count == 2)
      return desk
    }
    for command in Self.commands {
      expectTheSameEnd(play(command, alsoWithin: true), play(command, alsoWithin: false), "`\(command)`")
    }
  }

  // MARK: Not for ever

  /// Nobody ever reports the displays. Arbor's keys are not dead: after three seconds commands are carried out as before.
  @Test func afterThreeSecondsWithoutAReportNothingIsRefused() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    happen(.theSideGoes, to: desk)
    h.scheduler.advance(by: 2.5)
    #expect(h.run("zoom 101").message == Self.refused, "2.9 s after the first window spoke")
    h.scheduler.advance(by: 0.2)
    #expect(h.run("zoom 101").ok)
    #expect(h.controller.parked.contains(desk.onTheLaptop[1]), "102 is out of view: 101 fills the laptop")
  }

  /// No window has spoken: the three seconds begin with the first key.
  @Test func orAfterTheFirstKeyWhereNoWindowSpoke() {
    let desk = make(.docked, before: .theSideShrinks)
    let h = desk.h
    happen(.theSideShrinks, to: desk)
    h.scheduler.advance(by: 10)
    #expect(h.run("zoom 101").message == Self.refused)
    h.scheduler.advance(by: 2.9)
    #expect(h.run("zoom 101").message == Self.refused)
    h.scheduler.advance(by: 0.2)
    #expect(h.run("zoom 101").ok)
  }

  /// However the displays go on changing, as while a dock negotiates: three seconds from the first sign, and no longer.
  @Test func theThreeSecondsDoNotBeginAgainWhileTheDisplaysGoOnChanging() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    happen(.theSideGoes, to: desk)
    for second in 1...2 {
      h.scheduler.advance(by: 1)
      let frame = Self.side.frame.offsetBy(dx: second == 1 ? -3360 : 0, dy: 100)
      quietly(h) { h.system.plug(DisplaySnapshot(id: Self.side.id, frame: frame, visibleFrame: frame, isMain: false)) }
      #expect(h.run("zoom 101").message == Self.refused)
    }
    h.scheduler.advance(by: 0.7)
    #expect(h.run("zoom 101").ok)
    // Nor a little later: the dock negotiates on, and Arbor's keys go on working.
    for second in 1...20 {
      h.scheduler.advance(by: 1)
      let frame = Self.side.frame.offsetBy(dx: 0, dy: CGFloat(second))
      quietly(h) { h.system.plug(DisplaySnapshot(id: Self.side.id, frame: frame, visibleFrame: frame, isMain: false)) }
      #expect(h.run(second % 2 == 0 ? "zoom 101" : "out").message != Self.refused, "\(second) s after the three were over")
    }
  }

  /// A clock that is set back meanwhile does not make three seconds last.
  @Test func norDoesAClockSetBackMakeThemLast() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    let now = h.controller.now
    h.controller.now = { now().addingTimeInterval(-3600) }
    #expect(h.run("zoom 101").ok)
  }

  /// The clock of one change does not shorten the next: neither after a report nor after a blink.
  @Test(arguments: [true, false]) func theNextChangeHasItsOwnThreeSeconds(reported: Bool) {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    let before = desk.onTheSide.map { h.frame($0)! }
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    if reported {
      h.scheduler.advance(by: 1.3)
      tell(h)
      h.scheduler.advance(by: 8)
      h.system.plug(Self.side)
    } else {
      quietly(h) { h.system.plug(Self.side) }
      for (window, frame) in zip(desk.onTheSide, before) { h.system.userMove(window, to: frame) }
    }
    h.scheduler.advance(by: 8)
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
  }

  /// A blink, and the cable is pulled in earnest a second later, before anybody has looked for the end of the blink: macOS's own put-back,
  /// reported under the displays as Arbor knows them, ends the first clock.
  @Test func aChangeRightAfterABlinkHasItsOwnThreeSeconds() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    let before = desk.onTheSide.map { h.frame($0)! }
    happen(.theSideGoes, to: desk)
    h.scheduler.advance(by: 0.4)
    quietly(h) { h.system.plug(Self.side) }
    for (window, frame) in zip(desk.onTheSide, before) { h.system.userMove(window, to: frame) }
    h.scheduler.advance(by: 1)
    happen(.theSideGoes, to: desk)
    h.scheduler.advance(by: 1)
    #expect(h.run("float-all").message == Self.refused, "3.2 s after the first sign of the blink, 1.4 s after that of the change")
  }

  /// A blink after which macOS leaves the windows where it took them, so that no report comes under the displays as Arbor knows them. Arbor's own
  /// look-out for the end of a blink ends the clock.
  @Test func norAfterABlinkThatMacOSDoesNotUndo() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    happen(.theSideGoes, to: desk)
    quietly(h) { h.system.plug(Self.side) }
    h.scheduler.advance(by: 6)
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused, "6.8 s after the first sign of the blink")
  }

  /// Nor after a blink of which no window spoke, so that nobody looks out for its end: the next thing asked of Arbor finds the displays as
  /// they were.
  @Test func norAfterABlinkOfWhichOnlyAKeyKnew() {
    let desk = make(.docked, before: .theSideShrinks)
    let h = desk.h
    happen(.theSideShrinks, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    quietly(h) { h.system.plug(Self.side) }
    h.scheduler.advance(by: 4)
    #expect(h.run("zoom 101").ok)
    happen(.theSideShrinks, to: desk)
    #expect(h.run("out").message == Self.refused)
  }

  /// Nothing was asked of Arbor since. Half a minute after the first sign a sign belongs to another change: also on a Mac that slept.
  @Test func aClockLeftRunningRunsOut() {
    let desk = make(.docked, before: .theSideShrinks)
    let h = desk.h
    happen(.theSideShrinks, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    quietly(h) { h.system.plug(Self.side) }
    h.scheduler.advance(by: 31)
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    h.scheduler.advance(by: 2.7)
    #expect(h.run("zoom 101").ok, "and has three seconds like any other")
  }

  /// A start looks at the displays itself.
  @Test func norDoesAClockOutliveAPause() {
    let desk = make(.docked, before: .theSideShrinks)
    let h = desk.h
    happen(.theSideShrinks, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 4)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 1)
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 101").message == Self.refused)
  }

  // MARK: What is not refused

  /// And moves nothing, where macOS has just moved windows that a layout would send back.
  @Test(arguments: [
    "state", "status", "ascii", "displays", "help", "bindings", "get gap", "spaces", "doctor", "rules", "version", "shortcuts", "trace status", "settings-window", "settings-window close",
    "check-setup", "welcome", "check-for-updates", "launch-at-login", "ask-name cancel",
  ])
  func whatLeavesWindowsAndViewsAloneIsCarriedOut(_ command: String) {
    for arrangement in [Arrangement.docked, .framed] {
      let desk = make(arrangement, before: .theSideGoes)
      happen(.theSideGoes, to: desk)
      let (mark, parked, views) = (desk.h.system.frameLog.count, desk.h.controller.parked, desk.h.controller.workspaces.mapValues(\.camera))
      #expect(desk.h.run(command).message != Self.refused)
      desk.h.scheduler.advance(by: 1.3)
      #expect(desk.h.system.frameLog.count == mark, "\(desk.h.system.frameLog[mark...])")
      #expect(desk.h.controller.parked == parked && desk.h.controller.workspaces.mapValues(\.camera) == views)
    }
  }

  /// They look at the displays themselves (`LookBeforeLettingGoTests`).
  @Test(arguments: ["pause", "toggle-pause", "quit"]) func theWaysOutThatLookForThemselves(_ command: String) {
    let desk = make(.docked, before: .theSideGoes)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run(command).ok)
  }

  /// By its key too.
  @Test func theKeyThatPausesPauses() {
    let desk = make(.docked, before: .theSideGoes)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.key("ctrl+opt+escape")?.ok == true)
    #expect(!desk.h.controller.isRunning)
  }

  /// "Nothing was done" is true under a hold too. Float All from the menu is a way out of one, and lets go of it before anything else.
  @Test func aHoldIsNotLetGoOfByWhatIsRefused() {
    let desk = make(.docked, before: .theSideGoes)
    #expect(desk.h.run("hold").ok)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run("float-all", from: .menu).message == Self.refused)
    #expect(desk.h.run("zoom 101").message == Self.refused)
    desk.h.scheduler.advance(by: 1.3)
    tell(desk.h)
    let answer = desk.h.run("zoom 101")
    #expect(!answer.ok && answer.message.hasPrefix("the view is held"), "\(answer.message)")
  }

  /// One key, two meanings. Without a hold ⌃⌥⎋ pauses, and is carried out (`theWaysOutThatLookForThemselves`). Under a held view it lets go of
  /// the hold instead, which lays out what the hold put off, by the displays Arbor believes in: refused, and it works a moment later.
  @Test func theKeyThatPausesIsRefusedWhereItWouldLetGoOfAHold() {
    let desk = make(.framed, before: .theSideGoes)
    let h = desk.h
    #expect(h.run("hold").ok)
    happen(.theSideGoes, to: desk)
    let (frames, moves) = (desk.all.map { h.frame($0) }, h.system.frameLog.count)
    #expect(h.key("ctrl+opt+escape")?.message == Self.refused)
    h.scheduler.advance(by: 0.5)
    #expect(h.controller.holdLevel == .view)
    #expect(h.controller.isRunning)
    #expect(desk.all.map { h.frame($0) } == frames)
    #expect(h.system.frameLog.count == moves)
    h.scheduler.advance(by: 0.8)
    tell(h)
    #expect(h.key("ctrl+opt+escape")?.ok == true)
    #expect(h.controller.holdLevel != .view)
    #expect(h.controller.isRunning, "the first press lets go of the hold, the next one pauses")
  }

  /// Nor is the refused key remembered as the one that let go of the hold: pressed again with its release unheard, it is answered.
  @Test func norDoesTheRefusedKeyCountAsStillDownFromLettingGo() {
    let desk = make(.framed, before: .theSideGoes)
    let h = desk.h
    #expect(h.run("hold").ok)
    happen(.theSideGoes, to: desk)
    #expect(h.keyDown("ctrl+opt+escape")?.message == Self.refused)
    h.scheduler.advance(by: 1.3)
    tell(h)
    #expect(h.keyDown("ctrl+opt+escape")?.ok == true)
    #expect(h.controller.holdLevel != .view)
    h.keyUp("ctrl+opt+escape")
  }

  /// From the menu Pause means a pause, held view or not, and a pause looks at the displays itself.
  @Test func fromTheMenuAPauseIsAPauseUnderAHoldToo() {
    let desk = make(.framed, before: .theSideGoes)
    #expect(desk.h.run("hold").ok)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run("pause", from: .menu).ok)
    #expect(!desk.h.controller.isRunning)
  }

  /// Nor is a peek ended: let go afterwards, it goes back to where it began.
  @Test func norIsAPeekEnded() {
    let desk = make(.framed, before: .theSideGoes)
    let h = desk.h
    let origin = h.workspace.camera
    _ = h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.root, "peeking")
    happen(.theSideGoes, to: desk)
    #expect(h.run("zoom 102", from: .menu).message == Self.refused)
    h.scheduler.advance(by: 1.3)
    tell(h)
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == origin)
  }

  /// Nor is Go to… closed.
  @Test func norIsAPanelClosed() {
    let desk = make(.docked, before: .theSideGoes)
    #expect(desk.h.run("find").ok)
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run("zoom 101").message == Self.refused)
    #expect(desk.h.overlays.finder != nil)
  }

  /// A row in it goes where a command would. The panel is where the person is looking: it stays, and says why.
  @Test func aRowChosenInGoToIsRefusedToo() {
    let desk = make(.framed, before: .theSideGoes)
    let h = desk.h
    #expect(h.run("find").ok)
    h.overlays.typeInFinder("App1012")
    happen(.theSideGoes, to: desk)
    let (workspaces, parked, mark) = (h.controller.workspaces, h.controller.parked, h.system.frameLog.count)
    #expect(h.overlays.chooseInFinder())
    h.scheduler.advance(by: 1)
    #expect(h.overlays.finder?.model.notice == "The displays are still changing")
    #expect(h.system.frameLog.count == mark)
    #expect(h.controller.workspaces == workspaces && h.controller.parked == parked)
    h.scheduler.advance(by: 0.3)
    tell(h)
  }

  /// Its rows for commands as the commands themselves: refused with the panel left open, or carried out.
  @Test func aCommandChosenInGoToIsAnsweredAsTheCommandIs() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    #expect(h.run("find").ok)
    happen(.theSideGoes, to: desk)
    let (workspaces, mark) = (h.controller.workspaces, h.system.frameLog.count)
    h.controller.finderChose(.command("float-all"))
    #expect(h.overlays.finder?.model.notice == "The displays are still changing")
    #expect(h.controller.workspaces == workspaces && h.system.frameLog.count == mark)
    h.controller.finderChose(.command("toggle-pause"))
    #expect(!h.controller.isRunning)
  }

  /// ⎋ in the field for a name is carried out: the field has gone by then, and left open in the books it would come up again at the report.
  @Test func theFieldForANameCanBeClosed() {
    let desk = make(.docked, before: .theSideGoes)
    let h = desk.h
    #expect(h.run("ask-name").ok)
    #expect(h.overlays.namePrompt != nil)
    happen(.theSideGoes, to: desk)
    #expect(h.run("ask-name cancel").ok)
    h.scheduler.advance(by: 1.3)
    tell(h)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.namePrompt == nil)
  }

  /// No minimap came up for the key to hold: pressed again it is answered again, and not taken for the same press repeating.
  @Test func norDoesTheMinimapsKeyCountAsHeld() {
    let desk = make(.docked, before: .theSideGoes, settings: .withEveryKey)
    let h = desk.h
    #expect(h.key("ctrl+opt+m")?.ok == true)
    h.scheduler.advance(by: 20)
    happen(.theSideGoes, to: desk)
    #expect(h.keyDown("ctrl+opt+m")?.message == Self.refused)
    #expect(h.keyDown("ctrl+opt+m")?.message == Self.refused)
    h.keyUp("ctrl+opt+m")
  }

  // MARK: What starts it, and what does not

  /// The Dock shown, hidden or resized, the menu bar: every day, many times. Nothing is refused for that.
  @Test func theDockAndTheMenuBarStartNothing() {
    let desk = make(.docked)
    var withALargerDock = FakeWindowSystem.standardDisplay
    withALargerDock.visibleFrame.size.height -= 90
    quietly(desk.h) { desk.h.system.plug(withALargerDock) }
    #expect(desk.h.run("zoom 101").ok)
  }

  /// Seen on a hosted Mac: a window goes to the Dock, the Dock gets another picture and is two points lower, and macOS reports the displays a
  /// third of a second later. No display came, went, moved or changed its size. A key before that report and a key after it are carried out.
  @Test func aWindowGoesToTheDockWhichIsTwoPointsOtherForIt() {
    let desk = make(.docked)
    let h = desk.h
    h.system.setMinimized(desk.onTheLaptop[2], true)
    var twoPointsOther = FakeWindowSystem.standardDisplay
    twoPointsOther.visibleFrame.size.height += 2
    quietly(h) { h.system.plug(twoPointsOther) }
    #expect(h.press("zoom 101").ok)
    h.scheduler.advance(by: 0.3)
    tell(h)
    #expect(h.press("out").ok)
    #expect(h.overlays.headsUp.compactMapValues { $0 }.values.allSatisfy { $0.text != "The displays are still changing" })
  }

  /// Nor the order in which macOS lists the displays.
  @Test func norTheirOrder() {
    let desk = make(.docked)
    quietly(desk.h) { desk.h.system.setDisplays(desk.h.system.displayList.reversed()) }
    #expect(desk.h.run("zoom 101").ok)
  }

  @Test func withTheDisplaysAsTheyWereNothingIsDifferent() {
    let desk = make(.docked)
    #expect(desk.h.run("zoom 101").ok)
    #expect(!desk.h.scheduler.pendingKeys.contains { $0.hasPrefix("displays-blinked") })
  }

  @Test func duringAPauseNothingIsRefusedForTheDisplays() {
    let desk = make(.docked, before: .theSideGoes)
    desk.h.run("pause")
    happen(.theSideGoes, to: desk)
    #expect(desk.h.run("zoom 101").message != Self.refused)
  }
}
