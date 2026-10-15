import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The screen's answer is not the window's (Controller+TheScreensAnswer.swift). Where it stands, macOS lets a window grow no further than
/// to the bottom of the visible frame and the right edge of its display, and with its bottom in the Dock's strip not at all. A frame that
/// hangs over such a line can be had all the same: a window is sized where the size fits, and then only moved, for a move is not held back.
@Suite @MainActor struct TheScreensAnswerTests {
  /// The display of the recordings: 1024×768, a Dock at the bottom.
  static let withADock = DisplaySnapshot(
    id: DisplayID("with-a-dock"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
    visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true)

  static let own = CGSize(width: 400, height: 600)

  /// `tall`, whose own size is 400×600, is docked in the lower of two slots on the left, 319 points high.
  func deskWithATallWindowInALowSlot(ownOrigin: CGPoint = CGPoint(x: 300, y: 60)) throws -> (h: Harness, tall: WindowID, slot: CGRect) {
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 170, y: 100, width: 480, height: 348))
    let tall = h.system.open(app: "Tall", frame: CGRect(origin: CGPoint(x: 300, y: 60), size: Self.own))
    h.start()
    if ownOrigin != CGPoint(x: 300, y: 60) {
      h.system.userMove(tall, to: CGRect(origin: ownOrigin, size: Self.own))
      h.scheduler.advance(by: 2)
    }
    h.run("dock \(a.rawValue) left")
    h.run("dock \(tall.rawValue) beside \(a.rawValue) bottom")
    let slot = try #require(h.layout?.windowFrames[tall])
    try #require(slot.height < 330 && slot.minY > 360 && h.frame(tall) == slot, "\(slot)")
    return (h, tall, slot)
  }

  /// Told on a model of a Mac first: it had 400×319, and docked and floated again it still had.
  @Test func aDockedWindowDraggedOutAndLetGoLowHasItsOwnSize() throws {
    let (h, tall, slot) = try deskWithATallWindowInALowSlot()
    let letGo = CGPoint(x: 760, y: 414)
    h.system.drag(tall, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 500, y: 400), letGo])
    try #require(h.workspace.isFloating(tall), "it floats")
    let frame = try #require(h.frame(tall))
    #expect(frame.size == Self.own, "\(frame)")
    #expect(frame.minX <= letGo.x && letGo.x <= frame.maxX && frame.minY <= letGo.y && letGo.y <= frame.minY + 28, "its title bar is where it was let go: \(frame)")
    #expect(frame.maxY > Self.withADock.visibleFrame.maxY, "the case: it hangs over the bottom")
    #expect(h.workspace.floating[tall] == frame)
    h.run("dock \(tall.rawValue) right")
    h.run("float \(tall.rawValue)")
    #expect(h.frame(tall)?.size == Self.own, "docked and floated again")
  }

  /// What a hand left hanging over the bottom is given back as it was, from a slot with no room for its height.
  @Test(arguments: ["quit", "pause", "float-all", "float"]) func lettingGoGivesBackAFrameThatHangsOverTheBottom(way: String) throws {
    let left = CGRect(origin: CGPoint(x: 560, y: 380), size: Self.own)
    let (h, tall, _) = try deskWithATallWindowInALowSlot(ownOrigin: left.origin)
    if way == "quit" { h.controller.shutdown() } else { h.run(way == "float" ? "float \(tall.rawValue)" : way) }
    // `float` fetches all of it onto the Desktop, down to the line above the Dock, where a point is missing whatever anybody does.
    let fetched = CGSize(width: Self.own.width, height: Self.own.height - 1)
    #expect(h.frame(tall)?.size == Self.own || (way == "float" && h.frame(tall)?.maxY == 704 && h.frame(tall)?.size == fetched), "\(h.frame(tall) as Any)")
    #expect(h.frame(tall) == left || way == "float", "\(h.frame(tall) as Any)")
    #expect(way != "float" || h.workspace.floating[tall]?.size == Self.own, "and is not written down: \(h.workspace.floating[tall] as Any)")
  }

  /// Sized where the size fits, then only moved: two requests, the second for the size it has. Never by way of a cut size.
  @Test func itIsSizedWhereItFitsAndThenOnlyMoved() throws {
    let left = CGRect(origin: CGPoint(x: 560, y: 380), size: Self.own)
    let (h, tall, _) = try deskWithATallWindowInALowSlot(ownOrigin: left.origin)
    let mark = h.system.moveLog.count
    h.run("float-all")
    let moves = h.system.moveLog[mark...].filter { $0.window == tall }
    #expect(moves.count == 2, "\(moves.map(\.after))")
    #expect(moves.allSatisfy { $0.after == $0.requested }, "nothing was cut: \(moves.map(\.after))")
    #expect(moves.first?.after.size == Self.own && moves.first?.after.minX == left.minX, "straight above where it goes: \(moves.map(\.after))")
    #expect(moves.last?.after == left)
    #expect(h.system.jolts(since: mark).isEmpty, "to those who count moves these two are one")
  }

  /// From a slot with room for it, one request will do: the first of the three calls a frame is set with sizes it where it stands.
  @Test func withRoomWhereItStandsOneRequestWillDo() throws {
    let left = CGRect(origin: CGPoint(x: 560, y: 380), size: Self.own)
    let h = Harness(displays: [Self.withADock])
    let tall = h.system.open(app: "Tall", frame: CGRect(origin: CGPoint(x: 300, y: 60), size: Self.own))
    h.start()
    h.system.userMove(tall, to: left)
    h.scheduler.advance(by: 2)
    h.run("dock \(tall.rawValue) left")
    let mark = h.system.moveLog.count
    h.run("float-all")
    #expect(h.frame(tall) == left)
    #expect(h.system.moveLog[mark...].filter { $0.window == tall }.count == 1)
  }

  /// It does not stand where Arbor believes: word of a move was lost, or is still on its way. The answer ends on the line, and shows it.
  @Test func cutAfterAllItIsSizedWhereItFits() throws {
    let left = CGRect(origin: CGPoint(x: 560, y: 380), size: Self.own)
    let h = Harness(displays: [Self.withADock])
    let tall = h.system.open(app: "Tall", frame: CGRect(origin: CGPoint(x: 300, y: 60), size: Self.own))
    h.start()
    h.system.userMove(tall, to: left)
    h.scheduler.advance(by: 2)
    h.run("dock \(tall.rawValue) left")
    let listener = h.system.events
    h.system.events = nil
    h.system.userMove(tall, to: CGRect(x: 100, y: 500, width: 400, height: 200))
    h.system.events = listener
    let mark = h.system.moveLog.count
    h.run("float-all")
    #expect(h.frame(tall) == left, "\(h.system.moveLog[mark...].map(\.after))")
    #expect(h.system.moveLog[mark...].filter { $0.window == tall }.count == 3, "no more than once more: \(h.system.moveLog[mark...].map(\.after))")
  }

  /// A window that will not be as large as it once was, for reasons of its own, is believed: it is moved at the size it took.
  @Test func anAppsOwnLimitIsStillItsOwn() throws {
    let left = CGRect(origin: CGPoint(x: 560, y: 380), size: Self.own)
    let (h, tall, _) = try deskWithATallWindowInALowSlot(ownOrigin: left.origin)
    h.system.setMaximumSize(tall, CGSize(width: 400, height: 450))
    h.run("float-all")
    #expect(h.frame(tall)?.size == CGSize(width: 400, height: 450) && h.frame(tall)?.origin == left.origin, "\(h.frame(tall) as Any)")
  }

  /// The right edge of the display is such a line as well, and growth goes all the way to it: no margin, and no second request for a
  /// frame that ends on it. Nor for one so far over it that the window, as wide as it could be made where it stood, is off the display there, and free.
  @Test(arguments: [(424, 1), (500, 2), (700, 1)]) func theRightEdgeIsSuchALine(x: Int, requests: Int) throws {
    let left = CGRect(x: CGFloat(x), y: 60, width: 600, height: 300)
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 480, height: 348))
    let wide = h.system.open(app: "Wide", frame: left)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(wide.rawValue) right")
    let slot = try #require(h.frame(wide))
    try #require(slot == h.layout?.windowFrames[wide] && slot.minX + left.width > 1024, "the case: no room for its width where it stands: \(slot)")
    let mark = h.system.moveLog.count
    h.run("float-all")
    let moves = h.system.moveLog[mark...].filter { $0.window == wide }
    #expect(h.frame(wide) == left, "\(moves.map(\.after))")
    #expect(moves.count == requests, "\(slot) \(moves.map(\.after))")
    #expect(moves.allSatisfy { $0.after == $0.requested }, "nothing was cut: \(moves.map(\.after))")
  }

  /// The undoing of a question is such a giving back. At a start the window with the keyboard is asked how narrow it goes, would be a tile, and
  /// is let be where it stood: ten points over the right edge. It ended ten points narrower than its person had left it, for good.
  @Test func aWindowLetBeAtAStartHasTheWidthItStoodAt() {
    let runner = ChaosRunner()
    let story = [
      "launch", "open 101 Editor pid 1004 at 100 100 1350 700 min 1300 500", "focus 101", "dock 101 left",
      "open 102 Browser pid 1000 at 300 100 600 500 min 0 0", "dock 102 right", "settle", "quit", "focus 101", "launch", "settle",
    ]
    for line in story { _ = runner.step(ChaosAction(text: line)) }
    #expect(runner.system.frame(of: WindowID(101)) == CGRect(x: 100, y: 100, width: 1350, height: 700))
  }

  /// With the Dock hidden or at a side the line is the bottom of the display, and growth goes all the way to it.
  @Test(arguments: [168, 380]) func withoutADockBelowTheLineIsTheBottomOfTheDisplay(y: Int) throws {
    let display = DisplaySnapshot(
      id: DisplayID("no-dock-below"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737), isMain: true)
    let left = CGRect(origin: CGPoint(x: 560, y: CGFloat(y)), size: Self.own)
    let h = Harness(displays: [display])
    let a = h.system.open(app: "A", frame: CGRect(x: 170, y: 100, width: 480, height: 348))
    let tall = h.system.open(app: "Tall", frame: left)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(tall.rawValue) beside \(a.rawValue) bottom")
    try #require((h.frame(tall)?.minY ?? 0) + Self.own.height > 768, "the case: no room for its height where it stands")
    let mark = h.system.moveLog.count
    h.run("float-all")
    let moves = h.system.moveLog[mark...].filter { $0.window == tall }
    #expect(h.frame(tall) == left, "\(moves.map(\.after))")
    #expect(moves.count == (left.maxY > 768 ? 2 : 1), "\(moves.map(\.after))")
  }

  /// A window that had made itself as high as the visible frame comes back a point short above a Dock, in whatever order it is sized and
  /// moved (970 of 971 on a hosted Mac). That is borne: one request, nothing asked again. It is not written down: its own height is its own.
  @Test func thePointAboveTheDockIsBorneAndNotWrittenDown() throws {
    let whole = CGRect(x: 300, y: 31, width: 400, height: 674)
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 170, y: 100, width: 480, height: 348))
    let high = h.system.open(app: "High", frame: whole)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(high.rawValue) beside \(a.rawValue) bottom")
    let mark = h.system.moveLog.count
    h.run("float \(high.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.frame(high)?.height == 673 && h.frame(high)?.width == 400, "\(h.frame(high) as Any)")
    #expect(h.system.moveLog[mark...].filter { $0.window == high }.count == 1)
    #expect(h.workspace.floating[high]?.height == 674, "\(h.workspace.floating[high] as Any)")
  }

  /// The same at the side. Seen on a hosted Mac with the Dock at the right: floated, 480 wide and ending on the visible frame's right edge, it
  /// came out 479, and after the quit it was a point less for good. (In thirds then, with a column for the Desktop; in halves, as Arbor ships,
  /// it has eleven points to grow.)
  @Test(arguments: [true, false]) func thePointShortOfADockAtTheRightIsNotWrittenDown(desktopColumn: Bool) throws {
    let display = DisplaySnapshot(
      id: DisplayID("dock-at-the-right"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 974, height: 737), isMain: true)
    let own = CGRect(x: 494, y: 226, width: 480, height: 348)
    let h = Harness(displays: [display], settings: desktopColumn ? .withDesktopColumn : Settings())
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 348))
    let w = h.system.open(app: "W", frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(w.rawValue) right")
    try #require(h.frame(w) == h.layout?.windowFrames[w] && (h.frame(w)?.width ?? 480) < (desktopColumn ? 400 : 480), "the case: it has to grow: \(h.frame(w) as Any)")
    let mark = h.system.moveLog.count
    h.run("float-all")
    #expect(h.frame(w) == CGRect(x: 494, y: 226, width: 479, height: 348), "\(h.frame(w) as Any)")
    #expect(h.system.moveLog[mark...].filter { $0.window == w }.count == 1, "borne: one request")
    #expect(h.workspace.floating[w] == own, "\(h.workspace.floating[w] as Any)")
  }

  // MARK: Told as scripts, on the display of the recordings

  private static let desk = ["displays main:0,0,1024,768:31,0,63,0* windows-never", "open 101 A pid 1001 at 170 100 480 348"]
  private static let b = WindowID(102)

  private func play(_ lines: [String], on runner: ChaosRunner = ChaosRunner()) -> ChaosRunner {
    for line in lines { _ = runner.step(ChaosAction(text: line)) }
    return runner
  }

  /// Nine keys and nothing else: a window its person had left hanging over the right edge is docked with a key and given back. It came back cut
  /// at the edge, 969 wide for 1188, at every quit.
  @Test(arguments: [
    ("open 103 Safari pid 1000 at 471 116 1188 776 min 574 240", "way-back quit", CGRect(x: 471, y: 116, width: 1188, height: 776)),
    ("open 103 Finder pid 1005 at 633 457 1021 467 min 501 300", "toggle-pause", CGRect(x: 633, y: 457, width: 1021, height: 467)),
    ("open 103 Finder pid 1005 at 633 457 1021 467 min 501 300", "key down float-all", CGRect(x: 633, y: 457, width: 1021, height: 467)),
  ]) func leftHangingOverTheRightEdgeAndDockedWithAKeyItComesBackWhole(open: String, way: String, left: CGRect) {
    let runner = play(["launch", open, "key down dock right", way])
    #expect(runner.system.frame(of: WindowID(103)) == left)
  }

  /// As high as the visible frame, there is no place where all of it fits. It is sized where most of it does, at the top, and its own height is
  /// still its own. Let go with its foot above the Dock's line or in the Dock's strip, where nothing grows and no answer ends on any line.
  @Test(arguments: [414, 450]) func asHighAsTheVisibleFrameItIsSizedAtTheTop(y: Int) {
    let runner = play(
      Self.desk + [
        "open 102 Tall pid 1002 at 300 31 400 674", "launch", "dock 101 left", "dock 102 beside 101 bottom", "settle", "grab 102", "carry 500 400",
        "carry 760 \(y)", "release", "settle",
      ])
    #expect(runner.system.frame(of: Self.b)?.size == CGSize(width: 400, height: 673), "\(runner.system.frame(of: Self.b) as Any)")
    _ = play(["dock 102 right", "settle", "float 102", "settle"], on: runner)
    // Fetched onto the Desktop it is a point short again. Given a place that hangs over the bottom, from a slot with room, it has all of it.
    let again = runner.system.frame(of: Self.b)?.size ?? .zero
    #expect(again.width == 400 && again.height >= 673, "docked and floated again: \(runner.system.frame(of: Self.b) as Any)")
  }

  /// A pin remembers where the window is. Fetched onto the Desktop it ends on the Dock's line, a point short, and lost a point with every pin.
  @Test func pinAfterPinItLosesNoPoint() {
    let again = ["pin 102", "settle", "unpin 102", "dock 102 beside 101 bottom", "settle"]
    let runner = play(
      Self.desk + ["open 102 Tall pid 1002 at 300 60 400 600", "launch", "dock 101 left", "dock 102 beside 101 bottom", "settle"] + again + again + again
        + ["float 102", "settle"])
    #expect((runner.system.frame(of: Self.b)?.height ?? 0) >= 599, "\(runner.system.frame(of: Self.b) as Any)")
  }

  /// What an app answers for reasons of its own is its own, though the window is then fetched down to the very line: judged where it
  /// answered. Taken for the screen's, the height it will not have was written down, and the next layout moved it for that.
  @Test(arguments: [["behave 102 grid"], ["limits 102 min 0 0 max 400 450"]]) func anAppsOwnAnswerFetchedOntoTheLineIsStillItsOwn(ways: [String]) {
    let runner = play(
      ["displays main:0,0,1024,768:31,0,63,0* windows-never", "open 101 A pid 1001 at 100 100 380 348", "open 102 Tall pid 1002 at 560 60 400 590", "launch",
       "dock 101 left", "settle", "grab 102", "carry 760 300", "carry 760 610", "release", "settle", "zoom 101", "settle"] + ways + ["float-all", "settle"])
    let fetched = runner.system.frame(of: Self.b)
    #expect(fetched?.maxY == 705 && (fetched?.height ?? 590) < 590, "the case: \(fetched as Any)")
    _ = play(["dock 101 left", "settle"], on: runner)
    #expect(runner.system.frame(of: Self.b) == fetched)
  }

  /// With room where it stands to the very point, one request does it.
  @Test func withRoomToThePointOneRequestWillDo() {
    let runner = play(
      ["displays main:0,0,1024,768:31,0,63,0* windows-never", "open 101 A pid 1001 at 100 100 380 348", "open 102 Tall pid 1002 at 560 100 400 660", "launch",
       "dock 102 left", "settle"])
    let mark = runner.system.moveLog.count
    _ = play(["float-all", "settle"], on: runner)
    #expect(runner.system.frame(of: Self.b) == CGRect(x: 560, y: 100, width: 400, height: 660))
    #expect(runner.system.moveLog[mark...].filter { $0.window == Self.b }.count == 1)
  }

  /// Out of view in the corner, a low window's foot is in the Dock's strip, where nothing grows. Asked there how high it goes, it seemed unable
  /// to grow at all, and ended 80 points high in the middle of its slot.
  @Test func aLowWindowOutOfViewIsNotAskedToGrowInTheDocksStrip() {
    let runner = play(
      ["displays main:0,0,1024,768:31,0,63,0* windows-never", "open 101 A pid 1001 at 100 100 380 300", "open 102 Mini pid 1002 at 600 100 300 80", "launch",
       "dock 101 left", "settle", "zoom 101", "settle", "dock 102 right", "settle"])
    #expect(runner.system.frame(of: Self.b)?.height == 650, "\(runner.system.frame(of: Self.b) as Any)")
  }

  /// The window that filled the Desktop alone, dragged off it and let go low, is its own size again like any other.
  @Test func theLoneWindowDraggedOffTheDesktopHasItsOwnSize() {
    let runner = play(
      ["settings {\"soleFloatTakesDesktop\":true,\"floatingWindowsMakeWay\":true}", "displays main:0,0,1024,768:31,0,63,0* windows-never",
       "open 101 A pid 1001 at 100 100 380 348", "open 103 B pid 1003 at 100 100 380 348", "open 102 Tall pid 1002 at 560 60 400 600", "launch",
       "dock 101 left", "dock 103 top", "settle"])
    #expect((runner.system.frame(of: Self.b)?.height ?? 600) < 400, "the case: it fills a low Desktop: \(runner.system.frame(of: Self.b) as Any)")
    _ = play(["grab 102", "carry 700 400", "carry 760 420", "release", "settle"], on: runner)
    #expect(runner.system.frame(of: Self.b)?.size == Self.own, "\(runner.system.frame(of: Self.b) as Any)")
  }

  /// Out of view and back, summoned, docked and floated, round after round: fetched onto the Dock's line it is a point short, and never two.
  @Test(arguments: [["zoom 101", "settle", "home", "settle"], ["focus 102", "summon Tall", "settle"]]) func roundAfterRoundItLosesNoPoint(between: [String]) {
    let round = ["float 102", "settle"] + between + ["dock 102 beside 101 bottom", "settle"]
    let runner = play(
      Self.desk + ["open 102 Tall pid 1002 at 300 60 400 600", "launch", "dock 101 left", "dock 102 beside 101 bottom", "settle"] + round + round + round
        + ["float 102", "settle"])
    #expect((runner.system.frame(of: Self.b)?.height ?? 0) >= 599, "\(runner.system.frame(of: Self.b) as Any)")
  }

  /// All its app allows, with its foot in the Dock's strip, looks like nothing the screen does: no hop up and back to find that out.
  @Test func anAppsOwnLimitInTheDocksStripCostsNoHop() {
    let runner = play(
      ["displays main:0,0,1024,768:31,0,63,0* windows-never", "open 101 A pid 1001 at 100 100 380 348", "open 102 Tall pid 1002 at 560 380 400 600", "launch",
       "dock 102 left", "settle", "limits 102 min 0 0 max 400 340"])
    let mark = runner.system.moveLog.count
    _ = play(["float-all", "settle"], on: runner)
    #expect(runner.system.frame(of: Self.b) == CGRect(x: 560, y: 380, width: 400, height: 340))
    #expect(runner.system.moveLog[mark...].filter { $0.window == Self.b }.count == 1, "\(runner.system.moveLog[mark...].map(\.after))")
  }

  /// The Dock has grown since the last layout, and macOS does not say so. Arbor looks before it reckons with the line.
  @Test func theDockIsLookedAtBeforeItIsReckonedWith() throws {
    let (h, tall, slot) = try deskWithATallWindowInALowSlot()
    var higher = Self.withADock
    higher.visibleFrame.size.height -= 32
    h.system.displayList = [higher]
    h.system.drag(tall, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 500, y: 400), CGPoint(x: 760, y: 414)])
    #expect(h.frame(tall)?.size == Self.own, "\(h.frame(tall) as Any)")
    #expect(h.workspace.floating[tall]?.size == Self.own)
  }

  /// An app that carries a move out late is still in its low slot when it is sized. What it answers is that place's room, not its own limit.
  @Test func anAppThatMovesLateIsNotTakenAtItsWord() throws {
    let (h, tall, slot) = try deskWithATallWindowInALowSlot()
    h.system.movesLate.insert(tall)
    h.system.drag(tall, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 500, y: 400), CGPoint(x: 760, y: 414)])
    try #require((h.frame(tall)?.height ?? 600) < 600, "the case: cut where it was let go, though it was sent up to be sized: \(h.frame(tall) as Any)")
    #expect(h.workspace.floating[tall]?.size == Self.own, "\(h.workspace.floating[tall] as Any)")
  }
}
