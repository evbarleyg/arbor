import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let b = WindowID(102)

/// What a script left behind: the world, every rule that spoke, known or not, and the frames Arbor set from the mark on.
@MainActor private struct Played {
  var runner = ChaosRunner()
  var rules: [String] = []
  var mark = 0

  var system: FakeWindowSystem { runner.harness.system }
  func frame(_ window: WindowID) -> CGRect? { system.frame(of: window) }
  func moves(of window: WindowID) -> [CGRect] { system.frameLog[mark...].filter { $0.0 == window }.map(\.1) }
  func share(of window: WindowID) -> CGFloat {
    guard let frame = frame(window) else { return 0 }
    return frame.areaShowing(on: system.displayList.map(\.frame)) / frame.area
  }

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

/// A desk with a window docked and a floating one, 102, somewhere on it; and what happens to the displays then.
struct ADeskThatChanges: CustomTestStringConvertible, Sendable {
  var testDescription: String
  var desk: String
  /// Where the docked window and the floating one open: on the display the story is about.
  var opens = (docked: "100 100", floating: "800 200")
  var size = "400 400 min 100 100"
  /// Where a hand puts it then. Nil: it stays where its app opened it, and no hand's note vouches for anything.
  var place: String?
  var change: String

  func before(docking: Bool = true) -> String {
    """
    mac-tiling off
    displays \(desk) windows-never
    launch
    open 101 Safari pid 1000 at \(opens.docked) 900 600 min 100 100
    open 102 Chat pid 1001 at \(opens.floating) \(size)
    \(docking ? "dock 101 left" : "settle")
    settle
    \(place.map { "move 102 \($0) \(size.components(separatedBy: " min").first!)" } ?? "settle")
    settle
    advance 60
    """
  }

  func after(_ order: String) -> String { "displays \(change) \(order)\nsettle\nadvance 30\nsettle" }

  /// The change takes nothing from the window: as much of it shows afterwards, and its title bar is where it was.
  static let thatTakeNothing: [ADeskThatChanges] = [
    .init(testDescription: "the display grows", desk: "main:0,0,1440,900:25,0,0,0*", place: "-250 300", change: "main:0,0,1728,1117:25,0,0,0*"),
    .init(
      testDescription: "the display gets smaller on its other sides", desk: "main:0,0,1440,900:25,0,0,0*", place: "-250 300",
      change: "main:0,0,1280,800:25,0,0,0*"),
    .init(testDescription: "the display is turned", desk: "main:0,0,1440,900:25,0,0,0*", place: "-250 300", change: "main:0,0,900,1440:25,0,0,0*"),
    .init(
      testDescription: "the display grows and its neighbour goes", desk: "main:0,0,1440,900:25,0,0,0* side:1440,0,1280,720:25,0,0,0", place: "-250 300",
      change: "main:0,0,1728,1117:25,0,0,0*"),
    .init(
      testDescription: "a neighbour comes, above", desk: "main:0,0,1440,900:25,0,0,0*", place: "-250 300",
      change: "main:0,0,1728,1117:25,0,0,0* side:0,-720,1280,720:25,0,0,0"),
    .init(
      testDescription: "the lid shuts, and every corner moves", desk: "main:0,0,1440,900:25,0,0,0* side:1440,0,2560,1440:25,0,0,0",
      opens: ("1600 100", "2000 200"), place: "3900 300", change: "side:0,0,2560,1440:25,0,0,0*"),
    .init(
      testDescription: "the menu bar goes to the other display", desk: "main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0",
      opens: ("1600 100", "2000 200"), place: "3260 300", change: "main:-1440,0,1440,900:25,0,0,0 side:0,0,1920,1080:25,0,0,0*"),
    .init(
      testDescription: "the display with the menu bar is unplugged", desk: "side:0,0,2560,1440:25,0,0,0* main:-1440,540,1440,900:25,0,0,0",
      opens: ("-1300 700", "-900 800"), place: "-1740 800", change: "main:0,0,1440,900:25,0,0,0*"),
    .init(testDescription: "the Dock comes", desk: "main:0,0,1440,900:25,0,0,0*", place: "1280 300", change: "main:0,0,1440,900:25,0,80,0*"),
    .init(testDescription: "four points narrower, a hundredth", desk: "main:0,0,1440,900:25,0,0,0*", place: "1320 300", change: "main:0,0,1436,900:25,0,0,0*"),
    .init(
      testDescription: "wider than every display, which it covers from edge to edge", desk: "main:0,0,1440,900:25,0,0,0*", opens: ("100 100", "0 100"),
      size: "3000 300 min 3000 300", place: "-800 100", change: "main:0,0,1280,800:25,0,0,0*"),
    .init(
      testDescription: "where its app opened it, its title bar above the top before and after, and the Dock comes", desk: "main:0,0,1440,900:25,0,0,0*",
      opens: ("100 100", "900 -40"), place: nil, change: "main:0,0,1440,900:25,0,80,0*"),
  ]

  /// The change takes most of what showed, and a hand can still get hold of the window.
  static let thatTakeMostOfWhatShowed: [ADeskThatChanges] = [
    .init(testDescription: "a strip loses most of what showed", desk: "main:0,0,1440,900:25,0,0,0*", place: "1280 300", change: "main:0,0,1340,840:25,0,0,0*"),
    .init(testDescription: "wholly in view, and a quarter is left", desk: "main:0,0,1440,900:25,0,0,0*", place: "1000 300", change: "main:0,0,1100,800:25,0,0,0*"),
    .init(testDescription: "five points narrower, more than a hundredth", desk: "main:0,0,1440,900:25,0,0,0*", place: "1320 300", change: "main:0,0,1435,900:25,0,0,0*"),
    .init(
      testDescription: "a lower resolution carries it under the neighbour's bottom", desk: "main:0,0,1440,900:25,0,0,0* side:-2560,0,2560,1440:25,0,0,0",
      opens: ("-2400 100", "-1500 200"), place: "-500 720", change: "main:0,0,1440,900:25,0,0,0* side:-1920,0,1920,1080:25,0,0,0"),
  ]

  /// (But for the window that macOS carries across a border: it is the other display's then, and macOS does not carry it back.)
  static let thereAndBack = thatTakeNothing + thatTakeMostOfWhatShowed.filter { !$0.desk.contains("side") }

  /// macOS itself lets no window lie with its title bar above the top of the display that is left. Arbor copes where it did.
  static let theDisplayWithItsTitleBarGoes = ADeskThatChanges(
    testDescription: "the display that had its title bar goes", desk: "main:0,0,1440,900:25,0,0,0* side:0,-1080,1920,1080:25,0,0,0",
    opens: ("100 100", "900 -40"), place: nil, change: "main:0,0,1440,900:25,0,0,0*")
}

private let orders = ["windows-first", "windows-late", "windows-silent"]

/// A change of displays and the floating windows in view (board 0.23): **what macOS does to a floating window then is macOS's, and Arbor
/// acts only where nobody could get hold of the window.** However little of it shows, one whose title bar is within reach stays. What
/// the change took out of reach is fitted in the layout that follows the change, and in no other: nothing is owed. Whoever misses
/// a window has ⌃⌥0.
@MainActor @Suite struct WhatTheChangeTookTests {
  // MARK: Within reach, it stays

  @Test(arguments: ADeskThatChanges.thatTakeNothing + ADeskThatChanges.thatTakeMostOfWhatShowed, orders)
  func whatAHandCanGetHoldOfStays(_ story: ADeskThatChanges, order: String) {
    let world = played(story.before(), then: story.after(order))
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  @Test(arguments: ADeskThatChanges.thatTakeNothing + ADeskThatChanges.thatTakeMostOfWhatShowed, orders)
  func withNothingDockedToo(_ story: ADeskThatChanges, order: String) {
    let world = played(story.before(docking: false), then: story.after(order))
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  private static let whatComesLater = "\nopen 103 Notes pid 1002 at 300 300 300 300\ndock 103 beside 101 bottom\nsettle\nminimize 103\nsettle\nfocus 101\nsettle\nadvance 60\nsettle"

  @Test(arguments: ADeskThatChanges.thatTakeNothing + ADeskThatChanges.thatTakeMostOfWhatShowed)
  func norDoesALaterLayoutMoveIt(_ story: ADeskThatChanges) {
    let world = played(story.before(), then: story.after("windows-late") + Self.whatComesLater)
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  // MARK: A way home

  /// It is where a hand left it, with as much showing: on its display as that is shaped now, too.
  @Test(arguments: ADeskThatChanges.thatTakeNothing, ["home", "key down show-all", "desktop", "relayout"])
  func noWayHomeFetchesWhatLostNothing(_ story: ADeskThatChanges, way: String) {
    // (Nobody vouches for where an app opened a window out of reach.)
    guard story.place != nil else { return }
    let world = played(story.before(), then: story.after("windows-late") + "\n\(way)\nsettle")
    #expect(world.moves(of: b) == [])
  }

  /// A key that means "bring my windows back" names it. One move, wholly into view.
  @Test(arguments: ADeskThatChanges.thatTakeMostOfWhatShowed, ["home", "key down show-all", "desktop", "relayout"])
  func everyWayHomeFetchesWhatLostMostOfWhatShowed(_ story: ADeskThatChanges, way: String) {
    let world = played(story.before() + "\n" + story.after("windows-late"), then: "\(way)\nsettle")
    #expect(world.moves(of: b).count == 1)
    #expect(world.share(of: b) > 0.995)
  }

  // MARK: Out of reach: fitted, once, at once, for good

  private static let lost = ADeskThatChanges.theDisplayWithItsTitleBarGoes

  @Test func whatTheChangeTookOutOfReachIsFittedAtOnce() {
    let world = played(Self.lost.before(), then: Self.lost.after("windows-never") + Self.whatComesLater + "\nhome\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 900, y: 25, width: 400, height: 400)])
    #expect(world.rules == [])
  }

  /// A frame that is no place is no frame to remember: no later change of displays sends it back there.
  @Test func whereItWasFittedIsItsFrameFromNowOn() {
    let world = played(
      Self.lost.before() + "\n" + Self.lost.after("windows-never"), then: "displays \(Self.lost.desk) windows-never\nsettle\nadvance 30\nzoom 101\nsettle\nback\nsettle")
    let fitted = CGRect(x: 900, y: 25, width: 400, height: 400)
    #expect(world.frame(b) == fitted)
    #expect(world.runner.controller.workspaces.values.compactMap { $0.floating[b] } == [fitted])
    #expect(world.runner.controller.fittedFrames[b] == nil)
  }

  /// The menu bar comes to a display without one, over a window that lay at its top.
  @Test func soIsOneThatTheMenuBarCameOver() {
    let story = ADeskThatChanges(
      testDescription: "", desk: "main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0", opens: ("1600 100", "2400 0"), place: nil,
      change: "main:0,0,1440,900:0,0,0,0 side:1440,0,1920,1080:25,0,0,0*")
    let world = played(story.before(), then: story.after("windows-never"))
    #expect(world.moves(of: b) == [CGRect(x: 2400, y: 25, width: 400, height: 400)])
    #expect(world.runner.controller.workspaces.values.compactMap { $0.floating[b] } == [CGRect(x: 2400, y: 25, width: 400, height: 400)])
  }

  // MARK: Nothing is owed

  @Test func aWindowWhoseAppHangsAtTheChangeIsLeftAsItIs() {
    let world = played(
      Self.lost.before() + "\nhang 1001\nsettle", then: Self.lost.after("windows-never") + "\nadvance 60\nwake 1001\nsettle\nadvance 10\ntitle 102 a\nsettle" + Self.whatComesLater)
    #expect(world.moves(of: b) == [])
    #expect(world.frame(b) == CGRect(x: 900, y: -40, width: 400, height: 400))
    #expect(world.runner.controller.windowsOwedAMove == [])
  }

  @Test func norIsItAskedAnythingOnceTheDisplaysAreAsTheyWere() {
    let world = played(
      Self.lost.before() + "\nhang 1001\nsettle",
      then: Self.lost.after("windows-never") + "\ndisplays \(Self.lost.desk) windows-never\nsettle\nadvance 120\nwake 1001\nsettle\nadvance 10\nfocus 102\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  /// What its person asks for is no debt.
  @Test func andAWayHomeFetchesIt() {
    let world = played(Self.lost.before() + "\nhang 1001\nsettle\n" + Self.lost.after("windows-never") + "\nadvance 60\nwake 1001\nsettle", then: "home\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 900, y: 25, width: 400, height: 400)])
  }

  /// Never lost outranks never moved.
  @Test func whatNoDisplayShowsAtAllIsFetchedWhenItsAppWakes() {
    let strip = ADeskThatChanges.thatTakeMostOfWhatShowed[0]
    let world = played(
      strip.before() + "\nhang 1001\nsettle", then: "displays main:0,0,1200,800:25,0,0,0* windows-never\nsettle\nadvance 60\nwake 1001\nsettle\nadvance 10\nsettle")
    #expect(world.moves(of: b).count == 1)
    #expect(world.share(of: b) > 0.995)
  }

  @Test func oneThatWasInTheDockAtTheChangeComesBackWhereItWent() {
    let world = played(Self.lost.before() + "\nminimize 102\nsettle", then: Self.lost.after("windows-never") + "\nrestore 102\nsettle\nadvance 10\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.frame(b) == CGRect(x: 900, y: -40, width: 400, height: 400))
  }

  // MARK: There and back

  @Test(arguments: ADeskThatChanges.thereAndBack, orders)
  func thereAndBackIsNothing(_ story: ADeskThatChanges, order: String) {
    let world = played(story.before(), then: story.after(order) + "\ndisplays \(story.desk) \(order)\nsettle\nadvance 30\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  /// It is where the hand left it, on the display the hand left it on. (A window that speaks before Arbor hears of the displays has
  /// written over the hand's note by then: the first half's second step.)
  @Test(arguments: ADeskThatChanges.thereAndBack, ["windows-late", "windows-silent"])
  func andNoWayHomeHasAnythingToFetchThen(_ story: ADeskThatChanges, order: String) {
    guard story.place != nil else { return }
    let world = played(story.before(), then: story.after(order) + "\ndisplays \(story.desk) \(order)\nsettle\nadvance 30\nsettle\nhome\nsettle\nrelayout\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  /// Through a shape on which more of it shows, and one on which it lies well.
  @Test(arguments: orders) func theHandsNoteOutlastsOtherShapes(order: String) {
    let story = ADeskThatChanges(testDescription: "", desk: "main:0,0,1440,900:25,0,0,0*", size: "600 400 min 100 100", place: "1340 300", change: "main:0,0,1512,982:25,0,0,0*")
    let world = played(
      story.before(),
      then: story.after(order) + "\nhome\nsettle\ndisplays main:0,0,1728,1117:25,0,0,0* \(order)\nsettle\nadvance 60\ndisplays \(story.desk) \(order)\nsettle\nadvance 60\nhome\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  /// Fitted because the change took it out of reach from where a hand had left it, it goes back when the display is as it was.
  /// (macOS itself fetches such a window. Arbor copes where it did not.)
  @Test func whatAHandLeftWhereItIsOutOfReachNowGoesBackThere() {
    let story = ADeskThatChanges(testDescription: "", desk: "main:0,0,1440,900:25,0,0,0*", place: "800 870", change: "main:0,0,1440,880:25,0,0,0*")
    let world = played(story.before(), then: story.after("windows-never") + "\ndisplays \(story.desk) windows-never\nsettle\nadvance 30\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 800, y: 480, width: 400, height: 400), CGRect(x: 800, y: 870, width: 400, height: 400)])
    #expect(world.rules == [])
  }

  // MARK: What an adversarial read found

  /// Its app hangs while its display goes and comes back, so it cannot go home. It is taken from where it lies, display and all: Arbor took
  /// it out of view with the other display's view, and moved it twice at the next unplugging.
  @Test(arguments: ["windows-late", "windows-silent"]) func whatCouldNotGoHomeBelongsWhereItLies(order: String) {
    let two = "main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0"
    let world = played(
      """
      mac-tiling off
      displays \(two) windows-never
      launch
      open 102 Chat pid 1001 at 2000 300 400 400 min 100 100
      open 103 Notes pid 1002 at 1700 300 500 400 min 100 100
      dock 103 left
      settle
      hang 1001
      displays main:0,0,1440,900:25,0,0,0* \(order)
      settle
      advance 5
      displays \(two) \(order)
      settle
      advance 5
      wake 1001
      settle
      advance 60
      """,
      then: "cursor 1800 400\nzoom 103\nsettle\nhome\nsettle\ndisplays main:0,0,1440,900:25,0,0,0* \(order)\nsettle\ndisplays \(two) \(order)\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.runner.controller.workspaces[DisplayID("main")]?.floating[b] == world.frame(b))
  }

  /// The menu bar comes over a window in the Dock, which comes back behind it. A report about the Dock in between made good a note that was
  /// good for another shape of the display, and no way home fetched the window.
  @Test(arguments: orders) func aReportAboutTheDockVouchesForNothing(order: String) {
    let world = played(
      """
      mac-tiling off
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0 windows-never
      launch
      open 102 Chat pid 1001 at 2000 300 400 400 min 100 100
      settle
      move 102 2000 2 400 400
      settle
      advance 60
      minimize 102
      settle
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1600,900:25,0,0,0 \(order)
      settle
      advance 60
      restore 102
      settle
      advance 60
      displays main:0,0,1440,900:25,0,70,0* side:1440,0,1600,900:25,0,0,0 \(order)
      settle
      """, then: "home\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 2000, y: 25, width: 400, height: 400)])
  }

  /// Whoever speaks first, the end is the same: macOS's own early report passed for a hand's, and vouched for 35 %.
  @Test(arguments: ["windows-first", "windows-late", "windows-silent"]) func anEarlyReportVouchesForNothing(order: String) {
    let world = played(
      """
      mac-tiling off
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0 windows-never
      launch
      open 102 Chat pid 1001 at 2900 300 400 400 min 100 100
      open 103 Notes pid 1002 at 1800 300 400 400 min 100 100
      settle
      advance 60
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1600,900:25,0,0,0 windows-late
      settle
      advance 120
      displays main:0,0,1440,900:25,0,0,0* side:1440,200,1600,900:25,0,0,0 \(order)
      settle
      advance 60
      """, then: "home\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 2640, y: 500, width: 400, height: 400)])
  }

  /// Its person asks while its app still hangs: that is owed.
  @Test func anAskMadeWhileItsAppHangsIsServedWhenThatWakes() {
    let strip = ADeskThatChanges.thatTakeMostOfWhatShowed[1]
    let world = played(strip.before() + "\nhang 1001\n" + strip.after("windows-never"), then: "home\nsettle\nwake 1001\nsettle\nadvance 60\nsettle")
    #expect(world.moves(of: b).count == 1)
    #expect(world.share(of: b) > 0.995)
  }

  /// A guest of a framed window is in view with its host, whatever the Desktop is.
  @Test func noGuestIsOwedAnythingEither() {
    let world = played(
      """
      mac-tiling off
      displays \(Self.lost.desk) windows-never
      launch
      open 101 Editor pid 1000 at 100 100 600 600 min 100 100
      dock 101 left
      settle
      zoom 101
      settle
      open 102 Chat pid 1001 at 900 -40 400 400 min 100 100
      settle
      hang 1001
      """, then: Self.lost.after("windows-never") + "\nadvance 60\nwake 1001\nsettle\nadvance 10\nsettle")
    #expect(world.moves(of: b) == [])
  }

  /// Nobody took it along, and its display's corner moved away from under its title bar.
  @Test func whereItIsIsAlwaysAnAnswerToWhereItWas() {
    let world = played(
      """
      mac-tiling off
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0 windows-never
      launch
      open 102 Chat pid 1001 at 2000 100 400 400 min 100 100
      settle
      advance 60
      """, then: "displays main:0,0,1440,900:25,0,0,0* side:1440,350,1920,1080:25,0,0,0 windows-never\nsettle\nadvance 60")
    #expect(world.moves(of: b).count == 1)
    #expect(world.share(of: b) > 0.995)
  }

  /// Out of reach all along, where its app opened it, and nobody takes it anywhere: a report about the Dock is no reason to move it. The key is.
  @Test func whatWasOutOfReachAllAlongIsNoneOfArborsBusinessAtAReportAboutTheDock() {
    let story = ADeskThatChanges.thatTakeNothing.last!
    #expect(story.place == nil)
    var world = played(story.before(), then: story.after("windows-never") + Self.whatComesLater)
    #expect(world.moves(of: b) == [])
    world.play("home\nsettle")
    #expect(world.moves(of: b) == [CGRect(x: 900, y: 25, width: 400, height: 400)])
  }

  /// A display comes, and macOS itself leaves a window of the display that stays behind the menu bar. Where it was nobody can tell from the
  /// displays: in doubt somebody could get hold of it.
  @Test func whatMacOSItselfMovedOutOfReachIsFitted() {
    let main = DisplaySnapshot(id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)
    let side = DisplaySnapshot(id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false)
    let h = Harness(displays: [main], settings: Settings())
    let window = h.system.open(app: "Chat", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.start()
    h.scheduler.advance(by: 60)
    h.system.clearFrameLog()
    h.system.changeDisplaysAsAMacDoes([main, side], moving: [(window, CGRect(x: 700, y: 10, width: 600, height: 400))])
    h.scheduler.advance(by: 3)
    let fitted = CGRect(x: 700, y: 25, width: 600, height: 400)
    #expect(h.system.frameLog.map(\.frame) == [fitted])
    #expect(h.workspace.floating[window] == fitted)
  }

  // MARK: What the hunters found

  /// Dropped across the border of laptop and monitor. The lid shuts, and the window says where it is before Arbor hears of the displays; later
  /// the laptop is alone. Arbor fetched it at the first change and at the second PUT it where it had said it was two arrangements ago:
  /// 24 % and 1 % in view, title bar within reach, and none of ten ways back fetched it. macOS alone has it whole.
  @Test(arguments: ["1180 400", "940 760"], ["windows-silent", "windows-late"])
  func aPlaceSaidEarlyIsNotGivenBackTwoArrangementsLater(drop: String, order: String) {
    let world = played(
      """
      displays main:0,0,1280,800:25,0,0,70* side:1280,0,1920,1080:25,0,0,0 windows-never
      mac-tiling off
      open 102 Notes pid 1001 at 92 35 1053 690 min 709 320
      launch
      grab 102
      carry \(drop)
      release
      settle
      """,
      then: """
        displays side:0,0,1920,1080:25,0,0,70* windows-first
        settle
        advance 31
        displays main:0,0,1280,800:25,0,0,70* \(order)
        settle
        advance 1
        settle
        """)
    #expect(world.share(of: b) > 0.995)
    #expect(world.moves(of: b).count <= 1)
  }

  /// A frame that Arbor set has no claim to stay: staged there by force, the keys fetch it.
  @Test(arguments: ["home", "key down show-all"]) func whatLiesUnderHalfInViewAndNoHandLeftSoIsFetchedWhoeverPutItThere(way: String) {
    var world = played("mac-tiling off\nlaunch\nopen 102 Notes pid 1001 at 92 35 1053 690 min 709 320\nsettle\nadvance 60")
    _ = world.system.setFrame(CGRect(x: -627, y: 390, width: 1053, height: 690), of: b)
    world.play("react\nsettle\nadvance 60")
    world.markHere()
    world.play("\(way)\nsettle")
    #expect(world.moves(of: b).count == 1)
    #expect(world.share(of: b) > 0.995)
  }

  /// Half or more shows at the stale place, so it passed for a place: 44 of 228 drops ended there, 51 to 97 % in view. macOS alone has them whole.
  @Test(arguments: ["1540 220", "1480 400"], ["windows-silent", "windows-late"])
  func norWhereHalfOfItShowsThere(drop: String, order: String) {
    let world = played(
      """
      displays main:0,0,1280,800:25,0,0,70* side:1280,0,1920,1080:25,0,0,0 windows-never
      mac-tiling off
      open 102 Notes pid 1001 at 92 35 1053 690 min 709 320
      launch
      grab 102
      carry \(drop)
      release
      settle
      """,
      then: """
        displays side:0,0,1920,1080:25,0,0,70* windows-first
        settle
        advance 31
        displays main:0,0,1280,800:25,0,0,70* \(order)
        settle
        advance 1
        settle
        """)
    #expect(world.moves(of: b) == [])
    #expect(world.share(of: b) > 0.995)
  }

  /// Across two displays with menu bars of unequal height: its top is behind the one's and free on the other's, where a hand takes it.
  @Test(arguments: ["home", "key down show-all", "desktop", "relayout"]) func aTitleBarThatIsFreeOnOneDisplayIsWithinReach(way: String) {
    let world = played(
      """
      mac-tiling off
      displays main:0,0,1512,982:37,0,0,0* side:1512,0,2560,1440:25,0,0,0 windows-never
      launch
      cursor 1800 400
      open 102 Chat pid 1001 at 1800 300 800 600 min 100 100
      move 102 1192 25 800 600
      settle
      advance 60
      """, then: "displays main:0,0,1512,982:37,0,0,0* side:1512,0,1920,1080:25,0,0,0 windows-late\nsettle\nadvance 60\n\(way)\nsettle")
    #expect(world.moves(of: b) == [])
    #expect(world.rules == [])
  }

  // MARK: What a second read found

  /// A layout sees the new menu bar before the report about the displays comes, and then nothing had changed.
  @Test func aMenuBarThatALayoutSawFirstHasComeAllTheSame() {
    let world = played(
      """
      mac-tiling off
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0 windows-never
      launch
      cursor 1800 400
      open 104 Mail pid 1004 at 1700 200 500 500 min 100 100
      open 102 Chat pid 1001 at 2600 2 400 400 min 100 100
      summon Mail
      summon Mail
      settle
      advance 60
      """, then: "displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0 windows-recorded\nsettle\nadvance 600")
    #expect(world.moves(of: b) == [CGRect(x: 2600, y: 25, width: 400, height: 400)])
  }

  /// The view goes elsewhere and comes back while its app hangs. Nobody asked for their windows: the wake fetched it, ten minutes later.
  @Test func aViewThatCameAndWentWhileItsAppHungIsNoAsk() {
    let strip = ADeskThatChanges.thatTakeMostOfWhatShowed[1]
    let world = played(
      strip.before() + "\n" + strip.after("windows-late"), then: "hang 1001\nzoom 101\nsettle\nback\nsettle\nadvance 600\nwake 1001\nsettle\nadvance 10\nsettle")
    #expect(world.moves(of: b) == [])
  }

  /// The hand's note is good for how much shows, whoever asks: a view that goes and comes, a pause and a resume, a quit.
  @Test(arguments: ADeskThatChanges.thatTakeNothing, ["zoom 101\nsettle\nback", "toggle-pause\nsettle\ntoggle-pause", "quit"])
  func whatLostNothingComesBackWhereItWas(_ story: ADeskThatChanges, what: String) {
    // (Of the window wider than every display less shows than the hand left showing: no way home fetches it, and these fit it as ever.)
    guard story.place != nil, !story.size.hasPrefix("3000") else { return }
    var world = played(story.before(), then: story.after("windows-late"))
    let lay = world.frame(b)
    world.play("\(what)\nsettle")
    #expect(world.frame(b) == lay)
    // (The docked window's own frame is wider than the display that was turned leaves room for: another story.)
    #expect(world.rules.filter { $0 != "home-not-whole" } == [])
  }

  /// Larger than the display that is left, behind its menu bar: fitted, it is smaller. What Arbor did to a window is given back.
  @Test func aSizeThatTheFitTookIsGivenBack() {
    let desk = "main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0"
    let world = played(
      "mac-tiling off\ndisplays \(desk) windows-never\nlaunch\nopen 102 Chat pid 1001 at 1500 2 2200 1200 min 100 100\nsettle\nadvance 60",
      then: "displays side:0,0,1920,1080:25,0,0,0* windows-late\nsettle\nadvance 60\ndisplays \(desk) windows-late\nsettle\nadvance 60")
    // (No higher than its display, as ever.)
    #expect(world.frame(b) == CGRect(x: 1500, y: 2, width: 2200, height: 1080))
  }
}
