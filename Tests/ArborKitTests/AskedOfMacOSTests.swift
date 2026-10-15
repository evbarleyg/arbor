import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What a person asks of macOS about a docked window stays (board 0.24; Controller+AskedOfMacOS.swift). The times are a Mac's.
@Suite @MainActor struct AskedOfMacOSTests {
  /// Four windows, arranged, everything in view, and the last layout long past.
  func arranged() -> (Harness, [WindowID]) {
    let h = Harness()
    let windows = ["TextEdit", "Mail", "Notes", "Terminal"].enumerated().map { index, app in
      h.system.open(
        app: app, pid: 1000 + Int32(index),
        frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90 + 40 * CGFloat(index), width: 640, height: 420))
    }
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, windows)
  }

  /// A click or a key `after` seconds ago, and then something moves the window, in steps 50 ms apart.
  func moved(_ h: Harness, _ window: WindowID, to frame: CGRect, steps: Int = 1, after seconds: Double = 0.4) {
    let from = h.frame(window)!
    for step in 1...steps {
      let share = CGFloat(step) / CGFloat(steps)
      h.system.secondsSinceInput = seconds + 0.05 * Double(step - 1)
      h.system.userMove(
        window,
        to: CGRect(
          x: from.minX + (frame.minX - from.minX) * share, y: from.minY + (frame.minY - from.minY) * share,
          width: from.width + (frame.width - from.width) * share, height: from.height + (frame.height - from.height) * share))
      if step < steps { h.scheduler.advance(by: 0.05) }
    }
    h.system.secondsSinceInput = .infinity
  }

  func leftHalf(_ h: Harness) -> CGRect {
    CGRect(x: h.visibleFrame.minX, y: h.visibleFrame.minY, width: h.visibleFrame.width / 2, height: h.visibleFrame.height)
  }
  func line(_ h: Harness) -> String? { h.overlays.headsUp[h.display]?.line }
  func moves(_ h: Harness, of window: WindowID) -> Int { h.system.frameLog.filter { $0.window == window }.count }

  // MARK: Let be

  /// ⌥-click on the green button: one step, 59 to 110 ms after the release. Window ▸ Zoom: one step, after 400. Fill: ten steps.
  @Test(arguments: [(0.08, 1), (0.4, 1), (0.4, 10)]) func madeAsLargeAsTheScreenItStays(_ seconds: Double, _ steps: Int) {
    let (h, windows) = arranged()
    let others = windows[1...].map { h.frame($0) }
    moved(h, windows[0], to: h.visibleFrame, steps: steps, after: seconds)
    h.scheduler.advance(by: 10)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.isEmpty, "Arbor set no frame at all")
    #expect(windows[1...].map { h.frame($0) } == others)
    #expect(h.workspace.isDocked(windows[0]), "its place is kept")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  @Test func theLineComesOnceAnActAndSaysWhatIsSo() {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame, steps: 10)
    #expect(line(h) == nil, "not while macOS moves it")
    h.scheduler.advance(by: 0.3)
    #expect(line(h) == "macOS zoomed this window · ⌃⌥Space puts it back")
    #expect(h.controller.stateToSave.hintsShown[HeadsUpHint.zoomedByMacOS.rawValue] == 1, "once an act, not once a frame")
  }

  /// "Tiled windows have margins": filled, it is eight points short of the screen all round.
  @Test func filledWithMacOSsMarginsItIsStillMacOSsDoing() {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame.insetBy(dx: 8, dy: 8), steps: 10)
    h.scheduler.advance(by: 0.3)
    #expect(line(h) == "macOS zoomed this window · ⌃⌥Space puts it back")
    #expect(h.workspace.isDocked(windows[0]))
  }

  /// ⌘+ in a terminal, a sidebar, an inspector, Window ▸ Centre: a word to the app, or to macOS, and none about the neighbours.
  @Test(arguments: ["the font grew", "centred", "smaller"]) func anyOtherFrameIsLeftAsItIs(_ what: String) {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    let others = windows[1...].map { h.frame($0) }
    let frame: CGRect =
      switch what {
      case "the font grew": CGRect(x: slot.minX, y: slot.minY, width: slot.width + 70, height: slot.height + 40)
      case "centred": CGRect(x: h.visibleFrame.midX - slot.width / 2, y: h.visibleFrame.midY - slot.height / 2, width: slot.width, height: slot.height)
      default: slot.insetBy(dx: 50, dy: 40)
      }
    moved(h, windows[0], to: frame, after: 0.1)
    h.scheduler.advance(by: 0.3)
    #expect(line(h) == "Left as it is · ⌃⌥Space puts it back in its place")
    h.scheduler.advance(by: 10)
    #expect(h.frame(windows[0]) == frame)
    #expect(h.system.frameLog.isEmpty, "Arbor set no frame at all")
    #expect(windows[1...].map { h.frame($0) } == others)
    #expect(h.workspace.isDocked(windows[0]))
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot, "one key from home")
  }

  /// ⌥-click on the green button again: macOS returns it to where it stood.
  @Test func backWhereItStoodItIsADockedWindowAgain() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    moved(h, windows[0], to: h.visibleFrame, after: 0.08)
    h.scheduler.advance(by: 3)
    moved(h, windows[0], to: slot, after: 0.06)
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    #expect(h.system.frameLog.isEmpty, "Arbor set no frame at all")
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: Home comes first

  /// The first window has half the screen: with its gap of twelve points that slot of Arbor's looks like a half with macOS's margins.
  func aHalfAndTheRest() -> (Harness, [WindowID]) {
    let h = Harness()
    let windows = ["TextEdit", "Mail", "Notes"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 400, height: 420))
    }
    h.start()
    #expect(h.run("layout TextEdit:2 | Mail:1 | Desktop:1").ok)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, windows)
  }

  /// Filled by the menu; a neighbour closes, so its slot is another; ⌥-click on the green button returns it to where it stood, which looks
  /// like a tile. It is macOS's way back and no tiling: into the slot as it is, as after the second double-click.
  @Test func theWayBackToASlotThatLooksLikeATileIsNoTiling() {
    let (h, windows) = aHalfAndTheRest()
    let old = h.frame(windows[0])!
    #expect(MacTiling.isTile(old, of: h.visibleFrame), "the test's own premise: \(old)")
    moved(h, windows[0], to: h.visibleFrame, steps: 10)
    h.scheduler.advance(by: 5)
    h.system.close(windows[1])
    h.scheduler.advance(by: 5)
    moved(h, windows[0], to: old, after: 0.08)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isDocked(windows[0]), "not out")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// An eased way home ends in steps of a point or two, which are too little to be passed on. Where it is, is asked when the act is over. Of
  /// an app that stands some points short of its slot, like a terminal with its grid of characters: for any other, near the slot is home already.
  @Test func theLastFewPointsOfTheWayHomeCount() {
    let h = Harness()
    let windows = ["Terminal", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 400, height: 420))
    }
    h.system.setMaximumSize(windows[0], CGSize(width: 688, height: 843))
    h.start()
    #expect(h.run("layout Terminal:2 | Mail:1 | Desktop:1").ok)
    h.scheduler.advance(by: 5)
    h.system.setMaximumSize(windows[0], nil)
    h.system.clearFrameLog()
    let stood = h.frame(windows[0])!
    #expect(h.layout?.windowFrames[windows[0]]?.approximatelyEquals(stood, tolerance: 4) == false, "the test's own premise: \(stood)")
    moved(h, windows[0], to: h.visibleFrame, steps: 10)
    h.scheduler.advance(by: 5)
    h.system.secondsSinceInput = 0.4
    for off in [200, 60, 12, 3, 0] as [CGFloat] {
      h.system.userMove(windows[0], to: CGRect(x: stood.minX, y: stood.minY, width: stood.width + off, height: stood.height + off / 10))
      h.scheduler.advance(by: 0.05)
    }
    h.system.secondsSinceInput = .infinity
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == stood)
    #expect(h.workspace.isDocked(windows[0]), "not out")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "home")
    #expect(line(h) == nil, "and nothing to say about it")
  }

  // MARK: Out

  /// Window ▸ Move & Resize ▸ Left: from 409 to 735 ms after the release, in ten to twelve steps.
  @Test func inOneOfMacOSsTilesItLeavesTheArrangement() {
    let (h, windows) = arranged()
    let mark = h.system.moveLog.count
    moved(h, windows[0], to: leftHalf(h), steps: 11)
    #expect(h.system.frameLog.isEmpty, "nothing while the act runs")
    h.scheduler.advance(by: 10)
    #expect(h.frame(windows[0]) == leftHalf(h), "where macOS put it")
    #expect(moves(h, of: windows[0]) == 0, "Arbor asked nothing of it")
    #expect(h.workspace.isFloating(windows[0]))
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    // A question put to a window where it stands is no move.
    let taken = windows[1...].map { movesWithoutWaste(h, of: $0, since: mark) }
    #expect(taken.allSatisfy { $0 != nil && $0! <= 1 }, "one move a neighbour at the most, and nothing twice: \(taken)")
    #expect(taken.contains(1), "somebody takes the room")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// It is its person's now, where macOS put it: whatever is laid out later goes round it.
  @Test func laterLayoutsLeaveItInItsTile() {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 1180, y: 300, width: 240, height: 300))
    h.scheduler.advance(by: 5)
    moved(h, windows[0], to: leftHalf(h), steps: 11)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    h.system.close(floating)
    h.scheduler.advance(by: 2)
    h.system.close(windows[3])
    h.scheduler.advance(by: 2)
    #expect(h.run("swap \(windows[1].rawValue) \(windows[2].rawValue)").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(windows[0]) == leftHalf(h))
    #expect(moves(h, of: windows[0]) == 0)
  }

  @Test func filledFirstAndTiledThenItLeavesToo() {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame, steps: 10)
    h.scheduler.advance(by: 5)
    moved(h, windows[0], to: leftHalf(h), steps: 11)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isFloating(windows[0]))
    #expect(h.frame(windows[0]) == leftHalf(h))
    #expect(moves(h, of: windows[0]) == 0)
  }

  /// Window ▸ Move & Resize ▸ Arrange ▸ Left & Right: two windows at one command.
  @Test func twoAtOneCommand() {
    let (h, windows) = arranged()
    let mark = h.system.moveLog.count
    let right = leftHalf(h).offsetBy(dx: h.visibleFrame.width / 2, dy: 0)
    h.system.secondsSinceInput = 0.4
    h.system.userMove(windows[0], to: leftHalf(h))
    h.system.userMove(windows[1], to: right)
    h.system.secondsSinceInput = .infinity
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isFloating(windows[0]) && h.workspace.isFloating(windows[1]))
    #expect(h.frame(windows[0]) == leftHalf(h) && h.frame(windows[1]) == right)
    #expect(moves(h, of: windows[0]) == 0 && moves(h, of: windows[1]) == 0)
    let taken = windows[2...].map { movesWithoutWaste(h, of: $0, since: mark) }
    #expect(taken.allSatisfy { $0 != nil && $0! <= 1 }, "one layout for the two: no neighbour is asked twice: \(taken)")
    expectWindowsMatchLayout(h, on: h.display)
    // And one step to undo.
    #expect(h.run("undo").ok)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(windows[0]) && h.workspace.isDocked(windows[1]))
  }

  /// One window to the left half, and then its neighbour, which has just taken the room, to the right. In one step too: over eleven, a
  /// guard that is too long only makes Arbor notice late.
  @Test(arguments: [1, 11]) func oneAndThenItsNeighbour(_ steps: Int) {
    let (h, windows) = arranged()
    let right = leftHalf(h).offsetBy(dx: h.visibleFrame.width / 2, dy: 0)
    moved(h, windows[0], to: leftHalf(h), steps: 11)
    // The act is over a quarter of a second later, and the neighbours take the room. Then ⌘Tab, and the key.
    h.scheduler.advance(by: 0.25 + 0.6)
    h.system.clearFrameLog()
    moved(h, windows[1], to: right, steps: steps, after: 0.1)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[1]) == right)
    #expect(moves(h, of: windows[1]) == 0, "not put back")
    #expect(h.workspace.isFloating(windows[1]))
  }

  @Test func itCanBeUndone() {
    let (h, windows) = arranged()
    moved(h, windows[0], to: leftHalf(h), steps: 11)
    h.scheduler.advance(by: 5)
    #expect(h.run("undo").ok)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(windows[0]))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A zoom's own size can be half the screen by chance. Arbor heard the double-click, and macOS tiles nothing at one.
  @Test func aDoubleClickLeadsNowhereOut() {
    let (h, windows) = arranged()
    let bar = CGPoint(x: h.frame(windows[0])!.midX, y: h.frame(windows[0])!.minY + 12)
    h.system.doubleClick(at: bar)
    moved(h, windows[0], to: leftHalf(h), after: 0.05)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isDocked(windows[0]))
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  // MARK: A slot's size is never a window's own

  /// Window ▸ Centre: macOS moved it and gave it no size. It is let be, in the size of its slot, which is Arbor's. A way out gives back what
  /// Arbor took: its own size, where it lies.
  @Test(arguments: ["pause", "quit"]) func letBeInItsSlotsSizeAWayOutGivesItItsOwn(_ how: String) {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    let centred = CGRect(x: h.visibleFrame.midX - slot.width / 2, y: h.visibleFrame.midY - slot.height / 2, width: slot.width, height: slot.height)
    moved(h, windows[0], to: centred, after: 0.4)
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    if how == "pause" { #expect(h.run("pause").ok) } else { h.controller.shutdown() }
    let frame = h.frame(windows[0])!
    #expect(frame.size == CGSize(width: 640, height: 420), "its own size: \(frame)")
    #expect(abs(frame.midX - centred.midX) <= 1 && abs(frame.minY - centred.minY) <= 1, "where it lies: \(frame)")
    guard how == "pause" else { return }
    // There and back a pause is nothing.
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0])?.approximatelyEquals(centred, tolerance: 1) == true, "\(h.frame(windows[0])!)")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  /// A size macOS gave it at its person's asking stays, as after the double-click.
  @Test(arguments: ["pause", "quit"]) func whatMacOSGaveItAWayOutLeaves(_ how: String) {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame, steps: 10)
    h.scheduler.advance(by: 3)
    h.system.clearFrameLog()
    if how == "pause" { #expect(h.run("pause").ok) } else { h.controller.shutdown() }
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(moves(h, of: windows[0]) == 0)
  }

  /// Two docked with the Desktop between them: centred, the left one lands on the middle third, which looks like a tile. macOS gave it no
  /// size: moved alone it is let be, wherever it lands.
  @Test func movedAloneItIsNeverOut() {
    let h = Harness()
    let windows = ["TextEdit", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 400, height: 420))
    }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok && h.run("dock \(windows[1].rawValue) right").ok)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    let slot = h.frame(windows[0])!
    let centred = CGRect(x: h.visibleFrame.midX - slot.width / 2, y: h.visibleFrame.midY - slot.height / 2, width: slot.width, height: slot.height)
    #expect(MacTiling.isTile(centred, of: h.visibleFrame), "the test's own premise: \(centred)")
    moved(h, windows[0], to: centred, after: 0.4)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isDocked(windows[0]), "not out")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
    #expect(h.system.frameLog.isEmpty, "nobody else moves")
  }

  // MARK: Another display

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 25, width: 1920, height: 1055), isMain: false)

  func arrangedBesideASecondDisplay() -> (Harness, [WindowID]) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let windows = ["TextEdit", "Mail", "Notes"].enumerated().map { index, app in
      h.system.open(
        app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90 + 40 * CGFloat(index), width: 640, height: 420))
    }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok && h.run("dock \(windows[1].rawValue) right").ok)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, windows)
  }

  /// Window ▸ Move to the other display. Nobody is let be on another display than its own: it leaves the arrangement, floats where macOS put
  /// it, in its own size as a window dragged out has it, and the neighbour takes the room.
  @Test func takenToAnotherDisplayItLeavesTheArrangement() {
    let (h, windows) = arrangedBesideASecondDisplay()
    let mark = h.system.moveLog.count
    let slot = h.frame(windows[0])!
    let there = CGRect(origin: CGPoint(x: Self.side.visibleFrame.minX + 100, y: Self.side.visibleFrame.minY + 60), size: slot.size)
    moved(h, windows[0], to: there, after: 0.4)
    h.scheduler.advance(by: 5)
    #expect(!h.controller.workspaces.values.contains { $0.isDocked(windows[0]) }, "it has left the arrangement")
    #expect(h.controller.workspaces[Self.side.id]?.isFloating(windows[0]) == true, "and floats on the display macOS took it to")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    let frame = h.frame(windows[0])!
    #expect(frame.size == CGSize(width: 640, height: 420), "its own size: \(frame)")
    #expect(frame.minY == there.minY && Self.side.frame.contains(frame), "where macOS put it: \(frame)")
    #expect(movesWithoutWaste(h, of: windows[1], since: mark) == 1, "the neighbour takes the room, in one move")
    expectWindowsMatchLayout(h, on: h.display)
    // A key that names somebody else leaves it where its person sent it.
    h.system.userFocus(windows[2])
    h.scheduler.advance(by: 2)
    #expect(h.press("dock left").ok)
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == frame, "not fetched back")
  }

  @Test func thatIsOneStepToUndo() {
    let (h, windows) = arrangedBesideASecondDisplay()
    let slot = h.frame(windows[0])!
    moved(h, windows[0], to: CGRect(origin: CGPoint(x: Self.side.visibleFrame.minX + 100, y: 85), size: slot.size), after: 0.4)
    h.scheduler.advance(by: 5)
    #expect(!h.workspace.isDocked(windows[0]), "the test's own premise")
    #expect(h.run("undo").ok)
    h.scheduler.advance(by: 3)
    #expect(h.workspace.isDocked(windows[0]) && h.workspace.isDocked(windows[1]), "one step, and only that one")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// In a size macOS gave it there, a half of the other display for one, nothing is set on it at all.
  @Test func inASizeMacOSGaveItThereNothingIsSetOnIt() {
    let (h, windows) = arrangedBesideASecondDisplay()
    let visible = Self.side.visibleFrame
    let half = CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
    moved(h, windows[0], to: half, steps: 11)
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[Self.side.id]?.isFloating(windows[0]) == true)
    #expect(h.frame(windows[0]) == half)
    #expect(moves(h, of: windows[0]) == 0)
  }

  /// A click takes a display away, macOS carries its windows over, and reports of theirs come before its word about the displays. Nobody sent them
  /// anywhere: judged by displays that are no more, each would be torn out of an arrangement that is to sleep whole and come back with its display.
  @Test func carriedOverByMacOSBecauseItsDisplayGoesItIsNotOut() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let windows = ["TextEdit", "Mail"].enumerated().map { index, app in
      h.system.open(
        app: app, pid: 1000 + Int32(index), frame: CGRect(x: Self.side.frame.minX + 80 + 60 * CGFloat(index), y: 90, width: 640, height: 420))
    }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok && h.run("dock \(windows[1].rawValue) right").ok)
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[Self.side.id]?.isDocked(windows[0]) == true, "the test's own premise")
    let tree = h.controller.workspaces[Self.side.id]!.tree
    h.system.clearFrameLog()
    let size = h.frame(windows[0])!.size
    moved(h, windows[0], to: CGRect(origin: CGPoint(x: 100, y: 85), size: size), after: 0.3)
    // The display has gone, and macOS has not said so yet.
    h.system.displayList = [FakeWindowSystem.standardDisplay]
    h.scheduler.advance(by: 0.3)
    #expect(moves(h, of: windows[0]) == 0, "no frame set on it")
    #expect(h.controller.workspaces[Self.side.id]?.tree == tree, "and the arrangement is whole")
  }

  /// A lower display than its slot is high: macOS cuts what does not fit. That is no size anybody asked for: it is its slot's still, as far as it fits.
  @Test func cutByMacOSToFitTheOtherDisplayItStillGetsItsOwnSize() {
    let low = DisplaySnapshot(
      id: DisplayID("low"), frame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 0, width: 1280, height: 600),
      visibleFrame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 25, width: 1280, height: 575), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, low])
    let windows = ["TextEdit", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 640, height: 420))
    }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok && h.run("dock \(windows[1].rawValue) right").ok)
    h.scheduler.advance(by: 5)
    let slot = h.frame(windows[0])!
    #expect(slot.height > low.visibleFrame.height, "the test's own premise")
    moved(h, windows[0], to: CGRect(x: low.visibleFrame.minX + 100, y: low.visibleFrame.minY, width: slot.width, height: low.visibleFrame.height), after: 0.4)
    h.scheduler.advance(by: 5)
    #expect(h.controller.workspaces[low.id]?.isFloating(windows[0]) == true)
    #expect(h.frame(windows[0])?.size == CGSize(width: 640, height: 420), "its own size: \(h.frame(windows[0])!)")
  }

  /// Its own size is higher than its slot was: where it lies it would hang under the bottom edge. It is slid up as far as it takes.
  @Test(arguments: ["quit", "another display"]) func inItsOwnSizeItIsWholeOnTheDisplay(_ how: String) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let windows = ["TextEdit", "Mail", "Notes", "Terminal"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 40, width: 500, height: 800))
    }
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    let slot = h.frame(windows[0])!
    #expect(slot.height < 500, "the test's own premise: \(slot)")
    let display = how == "quit" ? FakeWindowSystem.standardDisplay : Self.side
    moved(h, windows[0], to: CGRect(x: display.visibleFrame.midX - slot.width / 2, y: display.visibleFrame.midY - 40, width: slot.width, height: slot.height), after: 0.4)
    h.scheduler.advance(by: 3)
    if how == "quit" { h.controller.shutdown() }
    let frame = h.frame(windows[0])!
    #expect(frame.size == CGSize(width: 500, height: 800), "its own size: \(frame)")
    #expect(display.visibleFrame.contains(frame), "whole on the display: \(frame)")
  }

  /// A pause before Arbor has looked where the act ended. Nobody is let be on another display than its own, after the resume either.
  @Test func aPauseWithinTheQuarterSecondAndTheResumeStillJudgeIt() {
    let (h, windows) = arrangedBesideASecondDisplay()
    let slot = h.frame(windows[0])!
    moved(h, windows[0], to: CGRect(origin: CGPoint(x: Self.side.visibleFrame.minX + 100, y: 85), size: slot.size), after: 0.4)
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 3)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    #expect(!h.controller.workspaces.values.contains { $0.isDocked(windows[0]) }, "it has left the arrangement")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    #expect(Self.side.frame.contains(h.frame(windows[0])!), "and is where its person sent it")
  }

  /// Arbor says what it has looked at.
  @Test func thePauseSaysOfItOnlyWhatIsSo() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    moved(h, windows[0], to: slot.offsetBy(dx: 300, dy: 120), after: 0.4)
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    #expect(!h.run("pause").message.contains("stays as it is"), "it was given its own size")
  }

  // MARK: The second

  @Test func itIsAskedOfTheFirstFrameOnly() {
    let (h, windows) = arranged()
    // The first at 0.9 s, the last at 1.4.
    moved(h, windows[0], to: leftHalf(h), steps: 11, after: 0.9)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isFloating(windows[0]))
    #expect(moves(h, of: windows[0]) == 0)
  }

  @Test(arguments: [1.2, Double.infinity]) func withoutAClickOrAKeyInTheSecondBeforeItIsPutBackAsEver(_ seconds: Double) {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    moved(h, windows[0], to: h.visibleFrame, after: seconds)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
  }

  // MARK: Arbor having asked nothing

  /// Arbor's own commands come with a key, and apps answer late, with sizes of their own.
  @Test func aLateAnswerToACommandOfArborsIsNobodyAskingMacOS() {
    let (h, windows) = arranged()
    #expect(h.press("swap \(windows[2].rawValue) \(windows[3].rawValue)").ok)
    let slot = h.frame(windows[0])!
    h.scheduler.advance(by: 0.3)
    moved(h, windows[0], to: slot.insetBy(dx: 30, dy: 30), after: 0.3)
    h.scheduler.advance(by: 2)
    #expect(h.frame(windows[0]) == slot, "put back as ever")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
  }

  /// A hand's drag is followed by reports that trail it.
  @Test func aReportThatTrailsADragIsNobodyAskingMacOS() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    let grab = CGPoint(x: slot.midX, y: slot.minY + 12)
    // Let go at once: a docked window goes home.
    h.system.drag(windows[0], through: [grab, CGPoint(x: grab.x + 30, y: grab.y + 20)], holding: 0)
    h.scheduler.advance(by: 0.1)
    moved(h, windows[0], to: slot.offsetBy(dx: 30, dy: 20), after: 0.1)
    h.scheduler.advance(by: 2)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Later than an app's answer to the layout that took it home would come, and still the hand's.
  @Test func aReportThatTrailsADragByMoreThanHalfASecondIsStillTheHands() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    let grab = CGPoint(x: slot.midX, y: slot.minY + 12)
    h.system.drag(windows[0], through: [grab, CGPoint(x: grab.x + 30, y: grab.y + 20)], holding: 0)
    h.scheduler.advance(by: 0.7)
    moved(h, windows[0], to: slot.offsetBy(dx: 30, dy: 20), after: 0.7)
    h.scheduler.advance(by: 2)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// ⌃⌘F is a key with modifiers, and the window lands where macOS likes. Arbor meets it as it always has.
  @Test func leavingFullScreenIsNobodyAskingForAFrame() {
    let (h, windows) = arranged()
    h.system.enterFullScreen(windows[0], leaving: Array(windows[1...]))
    h.scheduler.advance(by: 5)
    h.system.secondsSinceInput = 0.002
    h.system.leaveFullScreen(windows[0], with: Array(windows[1...]))
    h.system.secondsSinceInput = .infinity
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowThatClosesInTheHandLeavesNothingBehind() {
    let (h, windows) = arranged()
    h.system.grab(windows[0])
    h.system.close(windows[0])
    h.scheduler.advance(by: 2)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  /// ⌘T: another tab is another window to macOS, in the middle of the act.
  @Test func anotherTabInTheMiddleOfTheActTakesItOver() throws {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame, steps: 1)
    let tab = try #require(h.system.openTab(in: windows[0]))
    h.scheduler.advance(by: 0.3)
    #expect(line(h) == "macOS zoomed this window · ⌃⌥Space puts it back")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [tab])
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  @Test func aReportThatTrailsAPullAtAnEdgeIsNobodyAskingMacOS() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.userResize(windows[0], to: CGRect(x: slot.minX, y: slot.minY, width: slot.width + 60, height: slot.height))
    h.scheduler.advance(by: 0.1)
    let now = h.frame(windows[0])!
    moved(h, windows[0], to: now.insetBy(dx: 8, dy: 0), after: 0.1)
    h.scheduler.advance(by: 2)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: Meanwhile

  /// A layout that comes from an event in the middle of the act leaves the window to macOS.
  @Test func nothingIsSetWhileTheActRuns() {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 1180, y: 300, width: 240, height: 300))
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    let half = leftHalf(h)
    moved(h, windows[0], to: CGRect(x: 6, y: 31, width: half.width - 100, height: half.height - 60), steps: 4)
    h.system.close(floating)
    #expect(moves(h, of: windows[0]) == 0)
    moved(h, windows[0], to: half, steps: 4, after: 0.6)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == half)
    #expect(moves(h, of: windows[0]) == 0)
    #expect(h.workspace.isFloating(windows[0]))
  }

  @Test func closedInTheMiddleOfTheActNothingIsLeftBehind() {
    let (h, windows) = arranged()
    moved(h, windows[0], to: h.visibleFrame.insetBy(dx: 100, dy: 100), steps: 3)
    h.system.close(windows[0])
    h.scheduler.advance(by: 5)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(!h.scheduler.pendingKeys.contains("asked-of-macos"))
    expectWindowsMatchLayout(h, on: h.display)
  }
}
