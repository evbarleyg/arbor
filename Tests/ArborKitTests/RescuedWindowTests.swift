import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(101)
private let b = WindowID(102)

private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
  CGRect(x: x, y: y, width: width, height: height)
}

/// What a script left behind: the world, every rule that spoke on the way, and the frames Arbor set from `mark` on.
@MainActor private struct Played {
  var runner: ChaosRunner
  var rules: [String] = []
  var mark = 0

  var system: FakeWindowSystem { runner.harness.system }
  func frame(_ window: WindowID) -> CGRect? { system.frame(of: window) }
  /// The frames Arbor has set `window` since the mark.
  func moves(of window: WindowID) -> [CGRect] { system.frameLog[mark...].filter { $0.0 == window }.map(\.1) }
  /// How much of it shows, on all displays together, as a share.
  func share(of window: WindowID) -> CGFloat {
    guard let frame = frame(window), frame.area > 0 else { return 0 }
    return system.displayList.map { $0.frame.intersection(frame).area }.reduce(0, +) / frame.area
  }
  /// The rules about a window that is not where a person can see it.
  var lost: [String] {
    rules.filter { rule in ["placed-", "displays-left-", "switched-to-", "home-", "out-of-reach", "lost", "vanished"].contains { rule.hasPrefix($0) } }
  }

  mutating func play(_ script: String) {
    for action in ChaosAction.script(script) { rules += runner.step(action).map(\.rule) }
  }

  /// From here on Arbor's moves and the rules are counted.
  mutating func markHere() { (mark, rules) = (system.frameLog.count, []) }
}

@MainActor private func played(_ script: String, then rest: String = "") -> Played {
  var world = Played(runner: ChaosRunner())
  world.play(script)
  world.markHere()
  world.play(rest)
  return world
}

/// macOS brings the windows of a display that goes onto one that stays. What it has rescued stays rescued (random walks, 2026-10-15).
///
/// An external display above, the laptop's below. A window is let go with its title bar on the upper display and its body on the lower:
/// Arbor files it under the display the pointer is on, macOS under the one that shows most of it. The lid shuts.
@Suite @MainActor struct RescuedWindowTests {
  static let desk = "displays main:0,0,2560,1440:25,0,0,0* side:524,1440,1512,982:0,0,0,0 windows-never"
  static let straddling = """
    \(desk)
    launch
    open 101 Notes pid 1001 at 300 200 800 600 min 709 300
    settle
    grab 101
    carry 1200 1425
    release
    settle
    """
  static func theLidShuts(_ order: String) -> String { "displays main:0,0,2560,1440:25,0,0,0* windows-\(order)" }
  static let whereMacOSPutIt = rect(276, 25, 800, 600)

  // MARK: The fault

  /// Arbor pushed it back to (800,1408): a strip of 32 points, 5 % of the window. `first` held before, and is the control.
  @Test(arguments: ["late", "silent", "first"]) func theLidShutsUnderAWindowThatStraddlesTwoDisplays(order: String) {
    let world = played(Self.straddling, then: Self.theLidShuts(order) + "\nsettle\nadvance 5\nsettle")
    #expect(world.frame(a) == Self.whereMacOSPutIt)
    #expect(world.moves(of: a) == [], "Arbor has nothing to add to a rescue")
    #expect(world.lost == [])
  }

  /// The walk's own script, as it was found.
  @Test func asTheWalkFoundIt() {
    let world = played(
      """
      launch
      pause
      open 107 Preview pid 1007 at -287 64 585 574 max 584 767
      toggle-pause
      displays main:0,0,800,600:25,0,0,0* side:225,600,800,600:0,0,0,0 windows-late
      grab 107
      carry 80 586
      release
      """,
      then: """
        displays main:0,0,800,600:0,0,0,0* windows-silent
        react
        focus 107
        flush
        """)
    #expect(world.lost == [])
    #expect(world.share(of: WindowID(107)) > 0.99)
  }

  /// With something docked it held before: a control.
  @Test(arguments: ["late", "silent", "first"]) func withSomethingDockedARescueStaysToo(order: String) {
    let world = played(
      """
      \(Self.desk)
      launch
      open 101 Notes pid 1001 at 300 200 800 600 min 709 300
      open 102 Safari pid 1000 at 900 300 900 600 min 574 240
      dock 102 left
      settle
      grab 101
      carry 2000 1425
      release
      settle
      """, then: Self.theLidShuts(order) + "\nsettle")
    #expect(world.frame(a) == rect(1076, 25, 800, 600))
    #expect(world.moves(of: a) == [])
    #expect(world.lost == [])
  }

  /// It stays rescued through everything a person may try next, and through a start.
  @Test(arguments: [
    "key down home", "key down show-all\nkey up show-all", "key down desktop", "key down float-all", "relayout", "focus 101", "crash\nlaunch",
    "do pause\nsettle\ndo resume", "quit\nlaunch",
  ]) func aRescuedWindowIsLeftInPeace(by way: String) {
    let world = played(Self.straddling + "\n" + Self.theLidShuts("late") + "\nsettle", then: "advance 1\n" + way + "\nsettle")
    #expect(world.frame(a) == Self.whereMacOSPutIt, "after \(way)")
    #expect(world.moves(of: a) == [], "after \(way)")
  }

  /// The lid opens again: the window is on the upper display now, which has not changed.
  @Test(arguments: ["late", "silent", "first"]) func whenTheLidOpensAgainItStaysWhereItIs(order: String) {
    let world = played(
      Self.straddling + "\n" + Self.theLidShuts("late") + "\nsettle",
      then: "displays main:0,0,2560,1440:25,0,0,0* side:524,1440,1512,982:0,0,0,0 windows-\(order)\nsettle\nkey down home\nsettle")
    #expect(world.frame(a) == Self.whereMacOSPutIt)
    #expect(world.moves(of: a) == [])
  }

  /// macOS may rescue it onto a third display. There it stays, and there it belongs from now on, kept in view if it was.
  @Test(arguments: [false, true]) func rescuedOntoAThirdDisplayItBelongsThere(pinned: Bool) {
    func display(_ id: String, _ frame: CGRect, isMain: Bool = false) -> DisplaySnapshot {
      DisplaySnapshot(id: DisplayID(id), frame: frame, visibleFrame: frame, isMain: isMain)
    }
    let upper = display("upper", rect(0, 0, 2560, 1440), isMain: true)
    let third = display("third", rect(2560, 0, 1920, 1080))
    let h = Harness(displays: [upper, display("lower", rect(524, 1440, 1512, 982)), third])
    let n = h.system.open(app: "Notes", frame: rect(300, 200, 800, 600))
    h.start()
    if pinned { #expect(h.run("pin \(n.rawValue)").ok) }
    h.system.drag(n, through: [CGPoint(x: 700, y: 210), CGPoint(x: 1000, y: 900), CGPoint(x: 1200, y: 1425)])
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaces[upper.id]?.isFloating(n) == true, "filed under the display the pointer was on")
    #expect(h.controller.workspaces[upper.id]?.isPinned(n) == pinned)
    h.system.clearFrameLog()

    let rescued = rect(2700, 100, 800, 600)
    h.system.moveSilently(n, to: rescued)
    h.system.setDisplays([upper, third])
    h.scheduler.advance(by: 3)
    for command in ["home", "relayout"] {
      h.run(command)
      h.scheduler.advance(by: 3)
    }
    #expect(h.frame(n) == rescued)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.controller.workspaces[third.id]?.floating[n] == rescued)
    #expect(h.controller.workspaces[third.id]?.isPinned(n) == pinned)
    #expect(h.controller.workspaces[upper.id]?.contains(n) == false)
  }

  /// The lid shuts, macOS rescues the window, and its person quits or pauses within the second and a half before Arbor is told. Arbor looks at
  /// the displays before it lets go (`lookAtTheDisplaysBeforeLettingGo`), and what macOS rescued is in its books by then: letting go gives
  /// every window its remembered place, which would be the fit of the old one, a second move.
  @Test(arguments: ["quit", "pause"]) func lettingGoBeforeArborHasHeardLeavesARescuedWindowWhereItIs(way: String) {
    let upper = DisplaySnapshot(id: DisplayID("upper"), frame: rect(0, 0, 2560, 1440), visibleFrame: rect(0, 25, 2560, 1415), isMain: true)
    let lower = DisplaySnapshot(id: DisplayID("lower"), frame: rect(524, 1440, 1512, 982), visibleFrame: rect(524, 1440, 1512, 982), isMain: false)
    let h = Harness(displays: [upper, lower])
    let n = h.system.open(app: "Notes", frame: rect(300, 200, 800, 600))
    h.start()
    h.system.drag(n, through: [CGPoint(x: 700, y: 210), CGPoint(x: 1000, y: 900), CGPoint(x: 1200, y: 1425)])
    h.scheduler.advance(by: 3)

    let listener = h.system.events
    h.system.events = nil
    h.system.unplug(lower.id)
    h.system.events = listener
    h.system.moveSilently(n, to: Self.whereMacOSPutIt)
    #expect(h.controller.displays.count == 2, "a control: Arbor has not heard")
    h.system.clearFrameLog()
    if way == "quit" { h.controller.shutdown() } else { h.run("pause") }
    #expect(h.frame(n) == Self.whereMacOSPutIt)
    #expect(h.system.frameLog.filter { $0.window == n }.isEmpty)
  }

  /// A window that opened over a framed view belongs to that view (F57), also after macOS has moved it on its own display.
  @Test func aGuestThatIsRescuedIsStillAGuest() {
    let upper = DisplaySnapshot(id: DisplayID("upper"), frame: rect(0, 0, 1440, 900), visibleFrame: rect(0, 25, 1440, 875), isMain: true)
    let lower = DisplaySnapshot(id: DisplayID("lower"), frame: rect(0, 900, 1440, 900), visibleFrame: rect(0, 900, 1440, 900), isMain: false)
    let h = Harness(displays: [upper, lower])
    let s = h.system.open(app: "Safari", pid: 11, frame: rect(100, 100, 600, 400))
    _ = h.system.open(app: "Notes", pid: 12, frame: rect(800, 200, 500, 400))
    h.start()
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("arrange")
    h.run("zoom \(s.rawValue)")
    let guest = h.system.open(app: "Safari", pid: 11, frame: rect(400, 200, 500, 400))
    h.system.userMove(guest, to: rect(400, 650, 500, 400))  // 150 points of it on the lower display
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaces[upper.id]?.guests?[guest] != nil)
    h.system.clearFrameLog()

    h.system.moveSilently(guest, to: rect(400, 500, 500, 400))
    h.system.setDisplays([upper])
    h.scheduler.advance(by: 3)
    #expect(h.frame(guest) == rect(400, 500, 500, 400))
    #expect(h.system.frameLog.filter { $0.0 == guest }.isEmpty)
    #expect(h.controller.workspaces[upper.id]?.floating[guest] == rect(400, 500, 500, 400))
    #expect(h.controller.workspaces[upper.id]?.guests?[guest] != nil)
  }

  // MARK: What macOS did not rescue is fitted (QUESTIONS, Q20: the one exception)

  /// No Mac leaves it there, and Arbor copes anyway: the least move that brings it wholly into view, once. Before, 4 % of it showed and
  /// nothing was said.
  @Test func whatNobodyRescuedIsFittedInOneMove() {
    let world = played(Self.straddling, then: Self.theLidShuts("never") + "\nsettle")
    #expect(world.frame(a) == rect(800, 840, 800, 600))
    #expect(world.moves(of: a).count == 1)
    #expect(world.lost == [])
  }

  // MARK: Every way home fetches what such a change left

  /// Its app does not answer while the lid shuts, so nobody can move the window; then it answers again and says nothing.
  static let leftByAHungApp = straddling + "\nhang 1001\n" + theLidShuts("never") + "\nsettle\nwake 1001"

  /// Each way that lays out, alone and at once. They all asked the note, which vouched for the strip.
  /// (A switch to the window and Float All with nothing docked lay nothing out, and nothing tries again when its app answers:
  /// that is for a mark of its own on what a change leaves behind.)
  @Test(arguments: ["key down home", "key down show-all", "key down desktop", "relayout"])
  func everyWayHomeThatLaysOutFetchesWhatTheChangeLeft(way: String) {
    let world = played(Self.leftByAHungApp, then: way)
    #expect(world.frame(a) == rect(800, 840, 800, 600), "after \(way)")
    #expect(world.moves(of: a).count == 1, "after \(way)")
  }

  /// Controls: these two never asked the note and fetched it all along.
  @Test(arguments: ["do pause", "quit"]) func aPauseAndAQuitFetchItAsTheyDid(way: String) {
    #expect(played(Self.leftByAHungApp, then: way).frame(a) == rect(800, 840, 800, 600), "after \(way)")
  }

  /// A control: until then there is something to fetch.
  @Test func untilThenItIsStillWhereItWas() {
    #expect(played(Self.leftByAHungApp).share(of: a) < 0.05)
  }

  /// Out of view when the display goes: let go across the two, then the view is framed on a docked window. Show Everything put it back
  /// where it had been let go, 39 % of it showing, and ⌃⌥0 did not fetch it.
  @Test func outOfViewWhenTheDisplayGoesItComesBackWhole() {
    let world = played(
      """
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0 windows-never
      launch
      open 101 Safari pid 1000 at 100 100 700 500 min 574 240
      open 102 Messages pid 1008 at 200 200 1000 780
      dock 101 left
      settle
      move 102 930 300 1000 780
      settle
      zoom 101
      settle
      """,
      then: """
        displays main:0,0,1440,900:25,0,0,0* windows-late
        settle
        show-all
        settle
        """)
    #expect(world.share(of: b) > 0.99, "at \(String(describing: world.frame(b)))")
    #expect(world.lost == [])
  }

  /// A start sets no frame (QUESTIONS, Q16), and what it finds counts as left, whoever put it there: Arbor cannot tell this strip from one
  /// a person parked, and its title bar is within reach. So ⌃⌥0 lets it be as well. (Before, the note was gone with the crash, and the
  /// key fetched it.)
  @Test func aStartAfterACrashMovesNothingAndWhatItFindsCountsAsLeft() {
    var world = played(Self.leftByAHungApp, then: "crash\nlaunch\nsettle")
    #expect(world.moves(of: a) == [])
    world.play("key down home")
    #expect(world.moves(of: a) == [])
    #expect(world.lost == [])
  }

  // MARK: The same strip by another road: ⌃⌥Z

  /// Let go across the two displays, then docked. The lid shuts, which leaves the upper display's history as it was. ⌃⌥Z put it back
  /// where it had been let go, 5 % of it showing: the plan of an undo let a place hang over the edge without asking who had left it there.
  @Test(arguments: ["late", "silent", "first"]) func anUndoAfterTheLidHasShutBringsItBackWhole(order: String) {
    let world = played(
      Self.straddling + "\ncursor 1200 700\ndock 101 left\nsettle\n" + Self.theLidShuts(order) + "\nsettle\ncursor 1200 700", then: "undo\nsettle")
    #expect(world.frame(a) == rect(800, 840, 800, 600))
    #expect(world.moves(of: a).count == 1)
    #expect(world.lost == [])
  }

  static let pushedAside = """
    displays main:0,0,2560,1440:25,0,0,0* windows-never
    launch
    open 101 Notes pid 1001 at 300 200 800 600 min 709 300
    settle
    move 101 2300 400 800 600
    settle
    """

  /// A control: a strip its person left, on a display that is as it was, is a strip again after a dock and ⌃⌥Z.
  @Test func anUndoStillGivesAStripLeftByHandBack() {
    #expect(played(Self.pushedAside + "\ncursor 1200 700\ndock 101 left\nsettle", then: "undo\nsettle").frame(a) == rect(2300, 400, 800, 600))
  }

  /// The same docked by a drag, to the bottom edge, which is Arbor's whatever macOS tiles (Q23). (The note of the hand outlives a dock: it used
  /// to end with one by a drag, and nobody would vouch here.)
  @Test func alsoAfterADockByADrag() {
    var world = played(Self.pushedAside + "\ngrab 101\ncarry 1200 1437\nadvance 1\nrelease\nsettle\ncursor 1200 700")
    #expect(world.runner.controller.workspaces[DisplayID("main")]?.isDocked(a) == true, "a control: the drag docked it")
    world.play("undo\nsettle")
    #expect(world.frame(a) == rect(2300, 400, 800, 600))
  }

  /// And with both displays there all along: let go across the two, docked by a key or by a drag, undone. It is across the two again.
  @Test(arguments: ["cursor 1200 700\ndock 101 left", "grab 101\ncarry 200 1437\nadvance 1\nrelease"])
  func withNothingChangedAnUndoPutsItBackAcrossTheTwo(docked: String) {
    var world = played(Self.straddling + "\n" + docked + "\nsettle\ncursor 1200 700")
    #expect(world.runner.controller.workspaces[DisplayID("main")]?.isDocked(a) == true, "a control: it is docked")
    world.play("undo\nsettle")
    // A little higher than it was let go: macOS lets no frame be set with less than the window's title bar on the display its corner is on.
    #expect(world.frame(a) == rect(800, 1440 - FakeWindowSystem.usualTitleBar, 800, 600))
    #expect(world.share(of: a) > 0.99)
  }

  // MARK: What stays (Q20: nothing is fitted of which half shows, nor what the change took nothing from)

  static let theLidOpens = "displays main:0,0,2560,1440:25,0,0,0* side:524,1440,1512,982:0,0,0,0 windows-"

  /// Let go with 73 % of it on the upper display and the rest on the lower. macOS counts it to the upper one and leaves it. So does Arbor, lid
  /// shut and lid open: a note that vouched only for "as much as before" had it moved both times.
  @Test(arguments: ["late", "silent", "first", "never"]) func aWindowThatReachesOverALittleIsNotMovedByTheLid(order: String) {
    let world = played(
      """
      \(Self.desk)
      launch
      open 101 Notes pid 1001 at 300 200 800 600 min 709 300
      settle
      grab 101
      carry 1200 1010
      release
      settle
      """, then: Self.theLidShuts(order) + "\nsettle\nkey down home\nsettle\n" + Self.theLidOpens + order + "\nsettle\nkey down home\nsettle")
    #expect(world.frame(a) == rect(800, 1000, 800, 600))
    #expect(world.moves(of: a) == [])
  }

  /// Pushed aside over the far edge of the upper display until a strip shows. The lower display takes nothing from it by going.
  @Test(arguments: ["late", "never"]) func aWindowPushedAsideByHandStaysWhenAnotherDisplayGoes(order: String) {
    let world = played(
      """
      \(Self.desk)
      launch
      open 101 Notes pid 1001 at 300 200 800 600 min 709 300
      settle
      move 101 2300 400 800 600
      settle
      """, then: Self.theLidShuts(order) + "\nsettle\nkey down home\nsettle\nrelayout\nsettle")
    #expect(world.share(of: a) < 0.5, "a control that is not pushed aside says nothing")
    #expect(world.moves(of: a) == [])
  }

  /// Pushed aside until a strip shows, and a display is plugged in just where it hangs: all of it shows. Unplugged again. If macOS leaves it, it
  /// is the strip its person left, no less. If macOS fetches it, as a Mac does with a window that lay mostly on the display that went,
  /// it stays fetched. Arbor moves nothing either way.
  @Test(arguments: ["never", "late", "silent"]) func aStripLeftByHandWhenTheDisplayItHungOverComesAndGoes(order: String) {
    let world = played(
      Self.pushedAside,
      then: """
        displays main:0,0,2560,1440:25,0,0,0* side:2560,0,1920,1080:0,0,0,0 windows-\(order)
        settle
        key down home
        settle
        displays main:0,0,2560,1440:25,0,0,0* windows-\(order)
        settle
        key down home
        settle
        """)
    #expect(world.moves(of: a) == [])
    if order == "never" { #expect(world.frame(a) == rect(2300, 400, 800, 600)) } else { #expect(world.share(of: a) > 0.99) }
  }

  /// Left by hand across the border to the display on the right; then a window is docked on that side, and Arbor pushes it aside. The
  /// display on the right goes, and macOS moves nothing. That is no rescue: its person's place is still the one Float All takes it back to.
  /// Where floating windows make way (`floatingWindowsMakeWay`): as Arbor ships it pushes nothing aside (F64).
  @Test func whereArborPushedItAsideIsNoRescue() {
    let world = played(
      """
      settings {"floatingWindowsMakeWay":true}
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0 windows-never
      launch
      open 101 Notes pid 1001 at 200 200 500 400
      open 102 Safari pid 1000 at 100 100 700 500 min 574 240
      settle
      move 101 1100 300 500 400
      settle
      cursor 700 400
      dock 102 right
      settle
      displays main:0,0,1440,900:25,0,0,0* windows-late
      settle
      """)
    #expect(world.frame(a) != rect(1100, 300, 500, 400), "a control: it was pushed aside")
    #expect(world.runner.controller.workspaces[DisplayID("main")]?.floating[a] == rect(1100, 300, 500, 400))
    var later = world
    later.play("float-all\nsettle")
    #expect(later.frame(a) == rect(1100, 300, 500, 400))
  }

  /// The same with a window too wide for what is left beside the docked one, which Arbor makes smaller; and this time something does move it,
  /// in the size Arbor gave. That size is not its own: the one remembered stays. Where floating windows make way, again.
  @Test func aSizeArborGaveIsNotTakenForItsOwn() {
    let main = DisplaySnapshot(id: DisplayID("main"), frame: rect(0, 0, 1440, 900), visibleFrame: rect(0, 25, 1440, 875), isMain: true)
    let side = DisplaySnapshot(id: DisplayID("side"), frame: rect(1440, 0, 1920, 1080), visibleFrame: rect(1440, 0, 1920, 1080), isMain: false)
    let h = Harness(displays: [main, side], settings: .makingWay)
    let n = h.system.open(app: "Notes", frame: rect(200, 200, 1000, 400))
    let s = h.system.open(app: "Safari", frame: rect(100, 100, 700, 500))
    h.start()
    let own = rect(700, 600, 1000, 400)  // over the right edge onto the other display, and over the bottom edge
    h.system.userMove(n, to: own)
    h.scheduler.advance(by: 3)
    h.system.cursor = CGPoint(x: 700, y: 400)
    #expect(h.run("dock \(s.rawValue) right").ok)
    h.scheduler.advance(by: 3)
    guard let squeezed = h.frame(n) else { return }
    #expect(squeezed.width < 1000, "a control: made smaller: \(squeezed)")

    let moved = CGRect(x: squeezed.minX, y: 300, width: squeezed.width, height: squeezed.height)
    h.system.moveSilently(n, to: moved)
    h.system.setDisplays([main])
    #expect(moved.area > main.frame.intersection(own).area, "a control: more shows of it there, in points too, than of its own place")
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaces[main.id]?.floating[n]?.size == own.size)
  }

  /// Only where the change took something. Left by hand with a sliver of it over the bottom edge of the display that stays; the other display
  /// goes, and macOS shuffles this window too. More shows of it there, but its place has lost nothing: it goes back, as one wholly in
  /// view does (`aWindowOnTheDisplayThatStaysThatMacOSShuffledIsPutBackWithTheReport`).
  @Test func whatMacOSOnlyShuffledGoesBackThoughItHangsOverAnEdge() {
    let main = FakeWindowSystem.standardDisplay
    let side = DisplaySnapshot(id: DisplayID("side"), frame: rect(1440, 0, 1920, 1080), visibleFrame: rect(1440, 0, 1920, 1080), isMain: false)
    let h = Harness(displays: [main, side])
    let d = h.system.open(app: "Terminal", frame: rect(700, 300, 300, 200))
    h.start()
    let spot = rect(700, 720, 300, 200)
    h.system.userMove(d, to: spot)
    h.scheduler.advance(by: 3)

    h.system.displayList = [main]
    h.system.userMove(d, to: rect(220, 60, 300, 200))
    h.scheduler.advance(by: 1.5)
    h.system.setDisplays([main])
    #expect(h.workspace.floating[d] == spot)
    #expect(h.frame(d) == spot)
  }

  /// And only where more shows. Let go with 73 % of it on the upper display; something pushes it almost out of sight and nobody says so; the
  /// lid shuts, which takes from its place. Where it is now is no rescue: its place is still the one its person gave it.
  @Test func aPlaceThatShowsLessIsNotTakenInstead() {
    let world = played(
      """
      \(Self.desk)
      launch
      open 101 Notes pid 1001 at 300 200 800 600 min 709 300
      settle
      grab 101
      carry 1200 1010
      release
      settle
      """)
    world.system.moveSilently(a, to: rect(2500, 1000, 800, 600))
    var later = world
    later.play(Self.theLidShuts("never") + "\nsettle")
    #expect(later.runner.controller.workspaces[DisplayID("main")]?.floating[a] == rect(800, 1000, 800, 600))
  }

  /// Nor at a report that is only about the Dock, which comes many times a day.
  @Test func aReportAboutTheDockKeepsNothing() {
    let world = played(Self.pushedAside)
    world.system.moveSilently(a, to: rect(1500, 400, 800, 600))
    var later = world
    later.play("displays main:0,0,2560,1440:25,0,80,0* windows-never\nsettle")
    #expect(later.runner.controller.workspaces[DisplayID("main")]?.floating[a] == rect(2300, 400, 800, 600))
  }

  /// A strip left by hand on the big display; the display goes, and the window is moved by hand on the laptop meanwhile. The display is back:
  /// it goes home to its strip (F52). It counts as out of view then, and is not taken for rescued where it is.
  @Test func whatGoesHomeWithItsDisplayIsNotTakenForRescued() {
    let laptop = FakeWindowSystem.standardDisplay
    let studio = DisplaySnapshot(id: DisplayID("studio"), frame: rect(1440, 0, 2560, 1440), visibleFrame: rect(1440, 25, 2560, 1415), isMain: false)
    let h = Harness(displays: [laptop, studio])
    let strip = rect(1440 + 2500, 1300, 600, 400)
    let n = h.system.open(app: "Notes", frame: rect(2000, 500, 600, 400))
    h.start()
    h.system.userMove(n, to: strip)
    h.scheduler.advance(by: 3)
    h.system.setDisplays([laptop])
    h.scheduler.advance(by: 5)
    h.system.userMove(n, to: rect(300, 300, 600, 400))
    h.scheduler.advance(by: 5)
    h.system.setDisplays([laptop, studio])
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[studio.id]?.floating[n] == strip)
    #expect(h.controller.workspaces[laptop.id]?.contains(n) == false)
    // (Fitted there, because the hand's last word was on the laptop: nobody vouches for the strip any more.)
    #expect(h.frame(n).map { studio.frame.contains($0) } == true)
  }

  // MARK: The nets

  /// Nothing about this fault is known and walked past any more: `placed-mostly-out` speaks at both scripts on the code before, and walks stop at it.
  @Test func walksStopAtIt() {
    #expect(!ChaosRunner.knownRules.contains("placed-mostly-out"))
  }
}
