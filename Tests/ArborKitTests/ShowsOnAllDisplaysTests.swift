import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(101)

private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
  CGRect(x: x, y: y, width: width, height: height)
}

/// What a script left behind: the world, every rule that spoke, known or not, and the frames Arbor set from the mark on.
@MainActor private struct Played {
  var runner = ChaosRunner()
  var rules: [String] = []
  var mark = 0

  var system: FakeWindowSystem { runner.harness.system }
  var screens: [CGRect] { system.displayList.map(\.frame) }
  func frame(_ window: WindowID) -> CGRect? { system.frame(of: window) }
  func moves(of window: WindowID) -> [CGRect] { system.frameLog[mark...].filter { $0.0 == window }.map(\.1) }

  mutating func play(_ script: String) {
    for action in ChaosAction.script(script) { rules += runner.step(action).map(\.rule) }
  }

  mutating func markHere() { (mark, rules) = (system.frameLog.count, []) }
}

@MainActor private func played(_ script: String, then rest: String = "") -> Played {
  var world = Played()
  world.play(script)
  world.markHere()
  world.play(rest)
  return world
}

/// A desk, and a place on it where no display alone shows half of a window of 800 by 600 and all together show more.
struct TwoScreens: CustomTestStringConvertible, Sendable {
  var testDescription: String
  var displays: String
  var place: CGRect

  var open: String { "open 101 Notes pid 1001 at \(Int(place.minX)) \(Int(place.minY)) 800 600 min 709 300" }
  /// Where a hand that holds the title bar 400 points from its left end and 10 from the top lets go of it.
  var carry: String { "grab 101\ncarry \(Int(place.minX) + 400) \(Int(place.minY) + 10)\nrelease" }

  /// Arbor runs, and a hand has put the window there.
  var leftByHand: String {
    """
    displays \(displays) windows-never
    launch
    open 101 Notes pid 1001 at 300 200 800 600 min 709 300
    settle
    \(carry)
    settle
    advance 5
    settle
    """
  }

  static let laptop = "main:0,0,1512,982:37,0,0,0*"
  /// As the walk found it: 36.8 % on the laptop, 42.3 % on the monitor, the rest below the laptop's lower edge.
  static let found = TwoScreens(
    testDescription: "the monitor on the right", displays: "\(laptop) side:1512,-200,2560,1440:25,0,0,0", place: rect(1050, 600, 800, 600))
  static let all = [
    found,
    TwoScreens(testDescription: "the monitor on the left", displays: "\(laptop) side:-2560,-200,2560,1440:25,0,0,0", place: rect(-338, 600, 800, 600)),
    TwoScreens(testDescription: "the monitor above", displays: "\(laptop) side:-500,-1440,2560,1440:25,0,0,0", place: rect(1200, -250, 800, 600)),
    TwoScreens(testDescription: "the monitor below", displays: "\(laptop) side:-500,982,2560,1440:25,0,0,0", place: rect(1000, 680, 800, 600)),
    TwoScreens(
      testDescription: "three displays", displays: "\(laptop) side:1512,-200,2560,1440:25,0,0,0 third:0,982,1512,982:25,0,0,0",
      place: rect(1050, 600, 800, 600)),
    TwoScreens(testDescription: "a gap between the displays", displays: "\(laptop) side:1600,-200,2560,1440:25,0,0,0", place: rect(1100, 600, 800, 600)),
  ]
}

/// How much of a window shows is asked of all displays together (a random walk of ordinary acts, 2026-10-15).
///
/// Nothing is docked. A window lies across the laptop's display and the monitor's and reaches below the laptop's lower edge:
/// 37 % here, 42 % there, 79 % in view. Arbor asked each display by itself whether it showed half, heard no twice, took the
/// window for lost and brought it to the middle of the laptop's display: at a start, when it opened, and at a quit.
///
/// Those three were cured on the way by "what is found counts as left" (a title bar within reach stays), and are held here all the
/// same. What the measure itself still broke: leaving the dock, a window kept in view, a sibling out of view, full screen, an app
/// that hangs or gives a window back smaller, a dialog, a file from before.
@Suite @MainActor struct ShowsOnAllDisplaysTests {
  // MARK: The places are what they are said to be

  @Test(arguments: TwoScreens.all) func noDisplayAloneShowsHalfAndTogetherTheyDo(desk: TwoScreens) {
    let world = played("displays \(desk.displays) windows-never")
    #expect(world.screens.allSatisfy { desk.place.showsLessThanHalf(on: [$0]) })
    #expect(!desk.place.showsLessThanHalf(on: world.screens))
    #expect(desk.place.titleBarIsWithinReach(on: world.system.displayList.map(\.visibleFrame)))
  }

  // MARK: The fault

  /// The walk's three lines, as they were found: (1050,600) became (356,209).
  @Test func theThreeLines() {
    let world = played(
      """
      displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0 windows-never
      open 101 Notes pid 1001 at 1050 600 800 600 min 709 300
      launch
      react
      advance 1
      react
      """)
    #expect(world.frame(a) == rect(1050, 600, 800, 600))
  }

  @Test(arguments: TwoScreens.all) func aStartLeavesIt(desk: TwoScreens) {
    let world = played("displays \(desk.displays) windows-never\n\(desk.open)", then: "launch\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [])
    #expect(world.frame(a) == desk.place)
    #expect(world.rules == [])
  }

  @Test(arguments: TwoScreens.all) func whereItOpensItStays(desk: TwoScreens) {
    let world = played("displays \(desk.displays) windows-never\nlaunch", then: "\(desk.open)\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [])
    #expect(world.frame(a) == desk.place)
    #expect(world.rules == [])
  }

  /// Spared when it is found or opens, it is not pulled in a moment later by the first layout that places floating windows. Nothing is
  /// docked but in the last three, and nobody has named it.
  @Test(
    arguments: [true, false],
    [
      "close 102", "minimize 102", "hide 1002", "full-screen 102 on\nsettle\nfull-screen 102 off", "home", "show-all", "desktop", "relayout",
      "settings {\"gap\":20}", "displays \(TwoScreens.found.displays) windows-late", "pin 102", "dock 102 left", "dock 102 left\nsettle\nzoom 102\nsettle\nhome",
    ]
  ) func norDoesALaterLayoutPullItIn(found: Bool, act: String) {
    let desk = TwoScreens.found
    let world = played(
      "displays \(desk.displays) windows-never\nopen 102 Mail pid 1002 at 100 100 700 500\n"
        + (found ? "\(desk.open)\nlaunch" : "launch\n\(desk.open)") + "\nsettle\nadvance 2\nsettle\ncursor 400 400",
      then: "\(act)\nsettle\nadvance 2\nsettle")
    #expect(world.frame(a) == desk.place)
    // Out with the view and back is two moves that were asked for.
    if !act.contains("zoom") { #expect(world.moves(of: a) == []) }
  }

  /// At the side where it needs none of the window's room: making room for what is docked is another story (QUESTIONS, Q20).
  @Test(arguments: TwoScreens.all, [true, false]) func onNoDeskDoesADockOfAnotherWindowPullItIn(desk: TwoScreens, found: Bool) {
    let side = desk.place.minX < 0 ? "right" : "left"
    let world = played(
      "displays \(desk.displays) windows-never\n" + (found ? "\(desk.open)\nlaunch" : "launch\n\(desk.open)") + "\nsettle\nadvance 2\nsettle",
      then: "open 102 Mail pid 1002 at 100 100 700 500\nsettle\ncursor 400 400\ndock 102 \(side)\nsettle\nadvance 2\nsettle\nhome\nsettle\nrelayout\nsettle")
    #expect(world.runner.harness.controller.workspaces.values.contains { $0.isDocked(WindowID(102)) }, "or this proves nothing")
    #expect(world.moves(of: a) == [])
    #expect(world.frame(a) == desk.place)
  }

  /// Put there by hand while Arbor runs. Each way out gives back what Arbor took, and it took nothing.
  @Test(arguments: TwoScreens.all, ["quit", "pause", "pause\nsettle\nresume", "quit\nadvance 1\nlaunch"])
  func noWayOutMovesWhatAHandPutThere(desk: TwoScreens, way: String) {
    let world = played(desk.leftByHand, then: "\(way)\nsettle\nadvance 5\nsettle")
    #expect(world.frame(a) == desk.place, "or the hand did not put it there, and this proves nothing")
    #expect(world.moves(of: a) == [])
    #expect(world.rules == [])
  }

  // MARK: Docked from there, it goes back there

  /// Where a window floated before it was docked is still a place for it: half of it shows. It was fitted into the laptop's display.
  @Test(arguments: TwoScreens.all, ["float-all", "quit", "pause", "undo"]) func everyWayOutOfTheDockTakesItBackWhereItWas(desk: TwoScreens, way: String) {
    let world = played("\(desk.leftByHand)\ndock 101 left\nsettle\nadvance 1\nsettle", then: "\(way)\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [desk.place])
    #expect(world.frame(a) == desk.place)
  }

  /// Docked from across the two; then the monitor gets a lower resolution, so that 56 % would show where 79 % were left. The laptop's
  /// display, which the window belongs to, is as it was, but the place is not: it is fitted in, whole, as before.
  @Test func whereLessWouldShowThanWasLeftItIsFittedIn() {
    let world = played(
      "\(TwoScreens.found.leftByHand)\ndock 101 left\nsettle\ndisplays \(TwoScreens.laptop) side:1512,-200,1920,1080:25,0,0,0 windows-never\nadvance 2\nsettle",
      then: "float-all\nsettle\nadvance 5\nsettle")
    #expect(!TwoScreens.found.place.showsLessThanHalf(on: world.screens), "half of it would show: or this proves nothing")
    #expect(world.moves(of: a) == [rect(712, 382, 800, 600)])
    #expect(world.rules == [])
  }

  /// The monitor gets another resolution under a window a hand had left across the two, and a layout fits the window in: the note no
  /// longer vouches for the place. Then a pause, the resume and Quit have nothing to give back. (A first draft of this fix trusted every
  /// remembered frame of which half shows: there at the pause, back at the resume, there again at Quit.)
  @Test(arguments: ["late", "first", "silent", "never"]) func aPlaceNobodyVouchesForIsNotGoneBackTo(order: String) {
    let world = played(
      """
      displays \(TwoScreens.found.displays) windows-never
      launch
      open 101 Notes pid 1001 at 300 200 1000 800
      settle
      grab 101
      carry 1513 305
      release
      settle
      displays \(TwoScreens.laptop) side:1512,-200,1920,1080:25,0,0,0 windows-\(order)
      advance 2
      settle
      """, then: "pause\nsettle\nresume\nsettle\nquit\nsettle")
    #expect(world.moves(of: a) == [])
  }

  /// Its app will not make it as wide any more. It shrinks towards its top-left corner, and three quarters of it still show:
  /// one move, not a second one onto the display. (In the second story floating windows make way: only they leave with the Desktop.)
  @Test(arguments: [
    "dock 101 left\nsettle\nlimits 101 min 300 300 max 800 600\nsettle|float-all",
    "open 102 Mail pid 1002 at 100 100 700 500\nsettle\ndock 102 left\nzoom 102\nsettle\nadvance 1\nlimits 101 min 300 300 max 800 600\nsettle|home",
  ]) func whatComesBackSmallerAndStillShowsIsNotMovedASecondTime(story: String) {
    let acts = story.split(separator: "|").map(String.init)
    let world = played(
      """
      settings {"floatingWindowsMakeWay":\(acts[1] == "home")}
      displays \(TwoScreens.found.displays) windows-never
      launch
      open 101 Notes pid 1001 at 300 200 1000 600 min 300 300
      settle
      grab 101
      carry 1500 610
      release
      settle
      cursor 400 400
      \(acts[0])
      """, then: "\(acts[1])\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [rect(1000, 600, 800, 600)])
    #expect(world.screens.allSatisfy { rect(1000, 600, 800, 600).showsLessThanHalf(on: [$0]) }, "or this proves nothing")
  }

  // MARK: Pinned, summoned, beside a window that is out of view

  /// "Hanging over a screen edge is the user's business. Being mostly beyond it is not what they chose." It is not mostly beyond.
  @Test(arguments: TwoScreens.all) func aPinnedWindowStays(desk: TwoScreens) {
    let world = played(
      "\(desk.leftByHand)\npin 101\nsettle",
      then: "open 102 Mail pid 1002 at 100 100 700 500\nsettle\nrelayout\nsettle\ncursor 400 400\ndock 102 left\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [])
    #expect(world.frame(a) == desk.place)
  }

  /// Apps open a window beside the one they have, so what opens mostly out of view beside a window that Arbor keeps out of view is
  /// fetched. This one opens in view.
  @Test(arguments: TwoScreens.all) func itIsNotFetchedForASiblingThatIsOutOfView(desk: TwoScreens) {
    let world = played(
      """
      displays \(desk.displays) windows-never
      launch
      open 102 Notes pid 1001 at 100 100 700 500
      open 103 Safari pid 1000 at 200 100 700 500
      settle
      cursor 400 400
      dock 102 left
      dock 103 right
      zoom 103
      settle
      advance 1
      """, then: "\(desk.open)\nsettle\nadvance 5\nsettle")
    #expect(world.runner.harness.controller.parked.contains(WindowID(102)), "or this proves nothing")
    #expect(world.moves(of: a) == [])
    #expect(world.frame(a) == desk.place)
  }

  // MARK: What is still fetched

  /// Lower, so that less than half shows on all displays together, beside a sibling that is out of view: as ever.
  @Test func lessThanHalfOnAllTogetherIsStillFetched() {
    let world = played(
      """
      displays \(TwoScreens.found.displays) windows-never
      launch
      open 102 Notes pid 1001 at 100 100 700 500
      open 103 Safari pid 1000 at 200 100 700 500
      settle
      cursor 400 400
      dock 102 left
      dock 103 right
      zoom 103
      settle
      advance 1
      """, then: "open 101 Notes pid 1001 at 1050 800 800 600 min 709 300\nsettle")
    #expect(rect(1050, 800, 800, 600).showsLessThanHalf(on: world.screens), "17.5 % and 31 %")
    #expect(world.frame(a) != rect(1050, 800, 800, 600))
  }

  // MARK: What mostly shows is never fetched

  /// Wherever its title bar is: on no screen at all, or out of reach by the measure. It is in view and can be used; no hand leaves a
  /// window so, so it is its app's doing (full screen by an offset, say); and whoever wants it has ways that are asked for. Across
  /// two displays with its top above both, the old measure fetched one like that by accident: fewer moves now, and none new.
  @Test(arguments: [
    "\(TwoScreens.laptop) side:1512,100,2560,1440:25,0,0,0|1100 -40 800 600", "\(TwoScreens.found.displays)|1200 -260 800 600",
    "\(TwoScreens.laptop)|300 -40 800 600", "\(TwoScreens.laptop)|300 -13 800 600", "\(TwoScreens.laptop)|0 -28 1512 1010",
    "\(TwoScreens.laptop) side:1512,300,2560,1440:25,0,0,0|1489 100 800 600", "\(TwoScreens.laptop) side:1512,300,2560,1440:25,0,0,0|1500 100 800 600",
  ]) func whereverItsTitleBarIs(what: String) {
    let parts = what.split(separator: "|").map(String.init)
    let open = "open 101 Notes pid 1001 at \(parts[1])"
    for (before, then) in [("\(open)", "launch"), ("launch", "\(open)"), ("\(open)\nlaunch\nsettle", "pause"), ("\(open)\nlaunch\nsettle", "quit")] {
      let world = played("displays \(parts[0]) windows-never\n\(before)", then: "\(then)\nsettle\nadvance 5\nsettle")
      #expect(world.frame(a).map { !$0.titleBarIsWithinReach(on: world.screens) && !$0.showsLessThanHalf(on: world.screens) } == true, "or this proves nothing")
      #expect(world.moves(of: a) == [], "at \(then)")
      #expect(world.rules == [], "at \(then)")
    }
  }

  /// The menu bar and the Dock take no part: a window some apps open at the very top would be moved at every start.
  @Test(arguments: ["300 0", "300 -12", "1488 300"]) func underTheMenuBarOrBehindTheDockItIsWithinReach(place: String) {
    let world = played(
      "displays main:0,0,1512,982:37,0,0,70* windows-never\nopen 101 Notes pid 1001 at \(place) 800 600 min 709 300", then: "launch\nsettle\nadvance 5\nsettle")
    #expect(world.moves(of: a) == [])
    #expect(world.rules == [])
  }

  // MARK: Owed its place: full screen, an app that hangs, a file from before

  private static let laptop = DisplaySnapshot(
    id: DisplayID("main"), frame: rect(0, 0, 1512, 982), visibleFrame: rect(0, 37, 1512, 945), isMain: true)
  private static let monitor = DisplaySnapshot(
    id: DisplayID("side"), frame: rect(1512, -200, 2560, 1440), visibleFrame: rect(1512, -175, 2560, 1415), isMain: false)
  private static let place = TwoScreens.found.place

  /// `[safari | Desktop | notes]` on the laptop's display, framed on Safari. Notes floated across the two displays before it was docked.
  private func notesOutOfView() -> (h: Harness, safari: WindowID, notes: WindowID) {
    let h = Harness(displays: [Self.laptop, Self.monitor])
    let safari = h.system.open(app: "Safari", pid: 1000, frame: rect(100, 100, 600, 400))
    let notes = h.system.open(app: "Notes", pid: 2000, frame: Self.place)
    h.start()
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    #expect(h.controller.parked.contains(notes), "or this proves nothing")
    return (h, safari, notes)
  }

  /// It went into full screen out of view, so macOS gives it the corner back. Arbor takes it where it floated: not elsewhere.
  @Test(arguments: ["pause", "exclude com.example.notes"]) func leavingFullScreenItGoesWhereItFloated(lettingGo: String) {
    let (h, _, notes) = notesOutOfView()
    h.system.setFullScreen(notes, true)
    h.run(lettingGo)
    h.system.clearFrameLog()
    h.system.setFullScreen(notes, false)
    h.scheduler.advance(by: 10)
    #expect(h.system.frameLog.filter { $0.window == notes }.map(\.frame) == [Self.place], "once, and it is not asked again")
    #expect(h.frame(notes) == Self.place)
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("full-screen") }, "\(h.scheduler.pendingKeys)")
  }

  /// Its app hung when the pause was to bring it back. Somebody else has fetched it meanwhile: in view is all that was owed, wherever.
  @Test func whatSomebodyElseBroughtAcrossTwoDisplaysIsInView() {
    let (h, _, notes) = notesOutOfView()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("pause")
    h.system.setUnresponsive(pid: 2000, false)
    let chosen = Self.place.offsetBy(dx: 10, dy: -10)
    #expect([Self.laptop, Self.monitor].allSatisfy { chosen.showsLessThanHalf(on: [$0.frame]) }, "or this proves nothing")
    h.system.userMove(notes, to: chosen)
    h.system.clearFrameLog()
    h.scheduler.advance(by: 60)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == chosen)
  }

  /// A window that could not be brought back is noted only if it is out of view, and this one is not: it hung where it floats.
  @Test func anAppThatHangsWhereItsWindowShowsIsNotWaitedFor() {
    let h = Harness(displays: [Self.laptop, Self.monitor])
    let notes = h.system.open(app: "Notes", pid: 2000, frame: rect(300, 200, 800, 600))
    h.start()
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.run("dock \(notes.rawValue) left")
    // Taken there, and Arbor cannot put it back.
    h.system.setUnresponsive(pid: 2000, true)
    h.system.userMove(notes, to: Self.place)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == Self.place && h.controller.windows[notes]?.frame == Self.place, "or this proves nothing")
    h.run("pause")
    #expect(h.frame(notes) == Self.place, "it hangs")
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
  }

  /// A state file from before it said where its display was. The window that is in view is the better witness of its place.
  @Test func aFileThatDoesNotSayWhereItsDisplayWasBelievesAWindowInView() throws {
    var h = Harness(displays: [Self.laptop, Self.monitor])
    _ = h.system.open(app: "Notes", pid: 2000, frame: rect(300, 200, 800, 600))
    h.start()
    h.controller.shutdown()
    var object = try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(h.store.saved!)) as? [String: Any])
    #expect(object.removeValue(forKey: "origins") != nil)
    let saved = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    h = Harness(displays: [Self.laptop, Self.monitor], saved: saved)
    let notes = h.system.open(app: "Notes", pid: 2000, frame: Self.place)
    h.start()
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.controller.workspaces.values.compactMap { $0.floating[notes] } == [Self.place])
  }

  /// In view with the keyboard in it: someone is using it there. What is summoned is wholly on its display, so it comes in, by the
  /// shortest way: it does not jump to the middle like one that was out of view.
  @Test func summonedWhereItIsInUseItDoesNotJumpToTheMiddle() {
    let h = Harness(displays: [Self.laptop, Self.monitor])
    let notes = h.system.open(app: "Notes", pid: 2000, frame: rect(300, 200, 800, 600))
    h.start()
    h.system.cursor = CGPoint(x: 1450, y: 610)
    h.system.userMove(notes, to: Self.place)
    h.system.userFocus(notes)
    h.scheduler.advance(by: 2)
    h.run("summon Notes")
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == Self.place.fitted(into: Self.laptop.visibleFrame))
  }
}
