import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Arbor never takes a slot's size for a window's own. A window's own size is what it had before Arbor first sized it, or what a hand has given it
/// since: that is what Quit, Float All and a pause give back (rule 5).
///
/// A docked window has its slot's size in the hand. Where macOS may be about to tile it Arbor stands aside and sets no frame, which is right, so
/// the window leaves the arrangement as large as its slot. What was wrong: that size went into the books as its own. macOS does not
/// always take the window, and where it does it remembers the slot's size as the one to give back at the next drag.
///
/// The arrangement is [a | Desktop | b] with c floating; a and b were 600×400 before they were docked.
@Suite @MainActor struct ASlotsSizeIsNoWindowsOwnTests {
  static let own = CGSize(width: 600, height: 400)
  var own: CGSize { Self.own }

  /// Every size the books hold for `window`, on whichever display.
  func remembered(_ window: WindowID, _ h: Harness) -> [CGSize] {
    h.controller.workspaces.values.flatMap { [$0.floating[window]?.size, $0.undockedFrame(of: window)?.size].compactMap { $0 } }
  }

  /// The three ways out that promise sizes back.
  nonisolated static let waysOut = ["float-all", "pause", "quit"]

  func expectItsOwnSize(_ s: DragScene, after wayOut: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(remembered(s.a, s.h) == [own], "what is remembered before \(wayOut)", sourceLocation: sourceLocation)
    take(wayOut, s.h)
    #expect(s.frame(s.a).size == own, "after \(wayOut): \(s.frame(s.a))", sourceLocation: sourceLocation)
  }

  /// As the app does: `quit` is answered, then the app ends, which shuts the controller down.
  func take(_ wayOut: String, _ h: Harness) {
    h.run(wayOut)
    if wayOut == "quit" { h.controller.shutdown() }
    h.scheduler.advance(by: 3)
  }

  // MARK: Left to macOS, and left alone by it

  /// Half a second after the release Arbor looks, and a window that macOS has left alone takes its own size (LeftAloneByMacOSTests). Until then it is
  /// as large as its slot, and whatever happens in that time goes by the books.
  let soon = 0.2

  /// macOS fills the screen only for a pointer that has rested in the menu bar. An ordinary flick upwards.
  @Test(arguments: waysOut) func thrownIntoTheMenuBarAndLetGoAtOnce(wayOut: String) {
    let s = DragScene()
    #expect(s.frame(s.a).size != own)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: soon)
    expectItsOwnSize(s, after: wayOut)
  }

  /// Nobody saw the button come up, so Arbor goes by the place alone.
  @Test(arguments: waysOut) func thrownIntoTheMenuBarWithTheReleaseLost(wayOut: String) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.loseTheReleaseOfTheDrag()
    s.h.scheduler.advance(by: soon)
    expectItsOwnSize(s, after: wayOut)
  }

  /// macOS was seen to overlook a window that had rested in the menu bar for 1.7 s, and to show its preview with ⌥ alone held and then
  /// leave the window where it was let go. Wherever Arbor stands aside, macOS may do nothing.
  @Test(arguments: [CGPoint(x: 0, y: 450), CGPoint(x: 1439, y: 450), CGPoint(x: 700, y: 0), CGPoint(x: 0, y: 0)], waysOut)
  func restedWhereMacOSTilesAndOverlooked(point: CGPoint, wayOut: String) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 1)
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    s.h.scheduler.advance(by: soon)
    expectItsOwnSize(s, after: wayOut)
  }

  @Test(arguments: waysOut) func letGoWithOptionHeldAndOverlooked(wayOut: String) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.holdModifierKeys(.option)
    s.h.system.holdDrag(for: 1)
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: soon)
    expectItsOwnSize(s, after: wayOut)
  }

  /// A move is not a resize. The app's last word about the drag comes after the release, with a place from before it and the slot's size. It makes
  /// that size nobody's own.
  @Test(arguments: waysOut) func theAppsLateWordAboutTheDragDoesNotLaunderTheSlotsSize(wayOut: String) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 0.05)
    let truth = s.h.system.allWindows().first { $0.id == s.a }!
    var stale = truth
    stale.frame = stale.frame.offsetBy(dx: -31, dy: 43)
    s.h.controller.windowChanged(stale, userInitiated: true)
    s.h.scheduler.advance(by: 0.02)
    s.h.controller.windowChanged(truth, userInitiated: true)
    s.h.scheduler.advance(by: 0.05)
    expectItsOwnSize(s, after: wayOut)
  }

  /// Nothing is left of the note once the window has its own size and macOS never had it.
  @Test(arguments: waysOut) func aWayOutLeavesNoNoteBehind(wayOut: String) {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: soon)
    expectItsOwnSize(s, after: wayOut)
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty)
    #expect(s.h.controller.leftToMacOS.isEmpty)
    guard wayOut == "float-all" else { return }
    // Made as large as that slot by another tool later on, and dragged, it is left as it is.
    let given = CGRect(x: 300, y: 100, width: slot.width + 1, height: slot.height - 1)
    s.h.system.userMove(s.a, to: given)
    s.h.scheduler.advance(by: 3)
    s.h.system.drag(s.a, through: [CGPoint(x: given.midX, y: given.minY + 10), CGPoint(x: 700, y: 300)])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == given.size, "\(s.frame(s.a))")
  }

  // MARK: Left to macOS, and taken

  /// macOS's tile is what the hand asked macOS for. But dragged off it, the window is given the size it had when macOS took it, which was
  /// the slot's. Seen on a Mac: 325×650 in the slot, 326×651 in the hand at the next drag, and it kept that size.
  @Test(arguments: [CGPoint(x: 700, y: 0), CGPoint(x: 0, y: 450)]) func draggedOffMacOSsTileItDoesNotGetTheSlotsSizeForGood(point: CGPoint) {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.a)
    #expect(tile.size != slot && tile.size != own)
    #expect(remembered(s.a, s.h) == [tile.size], "what a hand asked macOS for is the window's own")
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot, "the fake gives back what macOS does")
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    expectItsOwnSize(s, after: "float-all")
    s.expectNothingLeftBehind()
  }

  /// A release that Arbor never saw: by the time it finds the button up macOS has tiled the window. The tile's size is its own like any tile's,
  /// and the slot's is what macOS gives back.
  @Test func tiledBeforeArborHeardOfTheReleaseTheTilesSizeIsItsOwn() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 0.3)
    s.h.system.loseTheReleaseOfTheDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == s.h.visibleFrame)
    #expect(remembered(s.a, s.h) == [s.h.visibleFrame.size])
    s.h.system.clearFrameLog()
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == s.h.visibleFrame, "what a hand asked macOS for stays: \(s.h.system.frameLog)")
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    #expect(remembered(s.a, s.h) == [own])
  }

  /// On a Mac it shrank in the hand in some 17 steps over a quarter of a second, the last ones a point at a time, and came to rest a point
  /// larger than the slot each way. Let go to float or to be docked, the slot's size is in no book.
  @Test(arguments: [false, true]) func shrunkInTheHandStepByStepItIsStillNotTheSlotsSize(docked: Bool) {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.a)
    // Played by hand: the fake gives the size back in one step.
    _ = s.h.system.takeSizeBeforeTile(of: s.a)
    s.h.system.beginDrag(s.a)
    let rest = CGSize(width: slot.width + 1, height: slot.height + 1)
    for left in [0.8, 0.5, 0.25, 0.1, 0.03] + [3, 2, 1, 0].map({ $0 / (tile.width - rest.width) }) {
      let size = CGSize(
        width: (rest.width + (tile.width - rest.width) * left).rounded(), height: (rest.height + (tile.height - rest.height) * left).rounded())
      s.h.system.userMove(s.a, to: CGRect(origin: s.frame(s.a).origin, size: size))
      s.h.scheduler.advance(by: 0.015)
    }
    #expect(s.frame(s.a).size == rest)
    s.h.system.moveDrag(to: docked ? CGPoint(x: 700, y: 880) : CGPoint(x: 700, y: 400), holding: 0.3)
    if docked { s.h.system.moveDrag(to: CGPoint(x: 700, y: 897), holding: 0.3) }
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a) == docked)
    #expect(remembered(s.a, s.h) == [own])
    if !docked { #expect(s.frame(s.a).size == own, "\(s.frame(s.a))") }
    expectItsOwnSize(s, after: "float-all")
  }

  /// macOS goes on regarding the window as tiled whatever Arbor has made of it since, as it was seen to.
  @Test func dockedAndFloatedSinceMacOSStillGivesTheSlotsSizeBackAndArborDoesNotKeepIt() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.a).size
    s.h.run("dock \(s.a.rawValue) left")
    s.h.scheduler.advance(by: 3)
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == tile, "the size it floated at last")
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size != slot, "\(s.frame(s.a))")
    #expect(!remembered(s.a, s.h).contains(slot))
  }

  /// Sized by hand in its tile, that is its own size from then on. Whether macOS still gives the slot's size back at the next drag nobody
  /// has seen; if it does, what the window takes when it is let go is what the hand gave it.
  @Test func sizedByHandInItsTileThatIsWhatItTakesWhenItIsDraggedOff() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let given = CGSize(width: 650, height: 700)
    s.h.system.userResize(s.a, to: CGRect(origin: s.frame(s.a).origin, size: given))
    s.h.scheduler.advance(by: 3)
    #expect(remembered(s.a, s.h) == [given])
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == given, "\(s.frame(s.a))")
    #expect(remembered(s.a, s.h) == [given])
  }

  /// The green button, a key of another tool, its app: whoever sizes it in its tile, that is its own size from then on.
  @Test func sizedInItsTileOtherwiseThanByItsEdgesThatIsItsOwnToo() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let given = CGSize(width: 900, height: 600)
    s.h.system.userMove(s.a, to: CGRect(origin: CGPoint(x: 100, y: 100), size: given))
    s.h.scheduler.advance(by: 3)
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 300), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == given, "\(s.frame(s.a))")
    #expect(remembered(s.a, s.h) == [given])
  }

  /// A busy app can go on telling of macOS's travel after Arbor has looked. That is nobody sizing the window: the window server has had it in its tile
  /// all the while.
  @Test func toldOfTheTravelAfterTheLookItIsStillNobodysSizing() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    let letGo = s.h.system.allWindows().first { $0.id == s.a }!
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tiled = s.h.system.allWindows().first { $0.id == s.a }!
    // The same way again, as its app tells it late.
    for share in [0.0, 0.4, 0.8, 1.0] as [CGFloat] {
      var told = tiled
      told.frame = CGRect(
        x: letGo.frame.minX + (tiled.frame.minX - letGo.frame.minX) * share, y: letGo.frame.minY + (tiled.frame.minY - letGo.frame.minY) * share,
        width: letGo.frame.width + (tiled.frame.width - letGo.frame.width) * share,
        height: letGo.frame.height + (tiled.frame.height - letGo.frame.height) * share
      ).integral
      s.h.controller.windowChanged(told, userInitiated: true)
      s.h.scheduler.advance(by: 0.05)
    }
    s.h.scheduler.advance(by: 3)
    #expect(remembered(s.a, s.h) == [tiled.frame.size])
    s.h.system.beginDrag(s.a)
    #expect(s.frame(s.a).size == slot)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 300), holding: 0.3)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
  }

  /// A way out within the half second gives the window its own size by the books, and macOS takes it all the same. The slot's size is still what macOS gives back.
  @Test(arguments: [["float-all"], ["pause", "resume"]]) func aWayOutWhileMacOSIsTakingTheWindowKeepsTheNote(wayOut: [String]) {
    let s = DragScene()
    let h = s.h
    h.system.beginDrag(s.a)
    h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    // Between the release and macOS's first step.
    h.system.passTime = { seconds in
      h.system.passTime = { h.scheduler.advance(by: $0) }
      h.scheduler.advance(by: seconds / 2)
      for line in wayOut { h.run(line) }
      h.scheduler.advance(by: seconds / 2)
    }
    h.system.endDrag()
    h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).approximatelyEquals(h.system.macTile(at: CGPoint(x: 0, y: 450))!, tolerance: 1), "\(s.frame(s.a))")
    #expect(h.workspace.floating[s.a] == s.frame(s.a), "\(String(describing: h.workspace.floating[s.a]))")
    h.system.beginDrag(s.a)
    h.system.moveDrag(to: CGPoint(x: 720, y: 400), holding: 1)
    h.system.endDrag()
    h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
  }

  /// With no gaps a half of the display is a slot's size and macOS's tile's alike. The tile is macOS's all the same: nothing pulls the window out of it.
  @Test func aTileAsLargeAsTheSlotIsStillATile() {
    let s = DragScene { $0.gap = 0 }
    s.h.run("float \(s.b.rawValue)")
    s.h.run("dock \(s.a.rawValue) left")
    s.h.scheduler.advance(by: 3)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: 900, y: 450), holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    let inHand = s.frame(s.a).size
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.a)
    try? #require(tile.size == inHand, "the story needs a slot as large as the tile: \(inHand), \(tile)")
    #expect(remembered(s.a, s.h) == [tile.size])
    s.h.system.clearFrameLog()
    s.h.system.close(s.c)
    s.h.run("dock \(s.b.rawValue) right")
    s.h.scheduler.advance(by: 3)
    #expect(!s.h.system.frameLog.contains { $0.window == s.a }, "\(s.h.system.frameLog)")
    #expect(s.frame(s.a) == tile)
  }

  /// Three points off the slot's size is another size, which somebody gave it.
  @Test func aSizeNearTheSlotsIsNotTheSlots() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.ownSize(of: s.a, ifItIsAsLargeAsTheSlotItLeft: CGSize(width: slot.width + 2, height: slot.height - 2)) == own)
    #expect(s.h.controller.ownSize(of: s.a, ifItIsAsLargeAsTheSlotItLeft: CGSize(width: slot.width + 3, height: slot.height)) == nil)
    #expect(s.h.controller.ownSize(of: s.a, ifItIsAsLargeAsTheSlotItLeft: CGSize(width: slot.width, height: slot.height - 3)) == nil)
  }

  /// What is noted goes with the window: to the native tab that takes its place, and away when it closes.
  @Test func theNoteGoesWithTheWindow() throws {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let tab = try #require(s.h.system.openTab(in: s.a))
    #expect(Array(s.h.controller.leftAsLargeAsTheirSlots.keys) == [tab])
    s.h.system.close(tab)
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty)
    #expect(s.h.controller.invariantViolations().isEmpty, "\(s.h.controller.invariantViolations())")
  }

  /// A window that was as large as its slot before it was docked has nothing to be given back, and is not moved for it.
  @Test func asLargeAsItsSlotOfItsOwnThereIsNothingToNote() {
    let s = DragScene()
    let slot = s.frame(s.a)
    s.h.run("float \(s.a.rawValue)")
    s.h.system.userMove(s.a, to: slot)
    s.h.run("dock \(s.a.rawValue) left")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == slot.size)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty)
  }

  /// A size a hand gives it afterwards is its own, though it was once as large as a slot.
  @Test func resizedByHandAfterwardsThatIsItsOwnSize() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    let given = CGRect(x: 500, y: 100, width: 500, height: 500)
    s.h.system.userMove(s.a, to: given)
    s.h.scheduler.advance(by: 3)
    #expect(remembered(s.a, s.h) == [given.size])
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == given)
  }

  // MARK: Every other way out of a slot

  /// Whatever takes a docked window out of its slot, the books never hold the slot's size for it, and it has its own.
  @Test(arguments: [
    "float", "toggle-float", "pin", "float-all", "float-all here", "pause", "quit", "drag to the Desktop", "drag with ⌘", "drag, quick",
    "float and undo and redo", "float with it in the hand", "exclude its app",
  ]) func noWayOutOfASlotWritesTheSlotsSizeDown(way: String) {
    let s = DragScene()
    let slot = s.frame(s.a).size
    let a = s.a.rawValue
    switch way {
    case "drag to the Desktop": s.h.system.drag(s.a, through: [s.frame(s.a).center, s.onDesktop])
    case "drag, quick": s.h.system.drag(s.a, through: [s.frame(s.a).center, s.onDesktop], holding: 0)
    case "drag with ⌘":
      s.h.system.heldModifiers = .command
      s.h.system.drag(s.a, through: [s.frame(s.a).center, s.edge(.left, of: s.b)])
      s.h.system.heldModifiers = []
    case "float and undo and redo": for line in ["float \(a)", "undo", "redo"] { s.h.run(line) }
    case "float with it in the hand":
      s.h.system.beginDrag(s.a)
      s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
      s.h.run("float \(a)")
      s.h.system.endDrag()
    case "exclude its app": s.h.run("exclude com.example.safari")
    case "float-all", "float-all here", "pause", "quit": take(way, s.h)
    default: s.h.run("\(way) \(a)")
    }
    s.h.scheduler.advance(by: 3)
    #expect(!remembered(s.a, s.h).contains(slot), "\(remembered(s.a, s.h))")
    // Let go before anything was held long enough it goes back to its slot, where its own size is still in the books.
    if s.h.controller.isRunning, s.h.workspace.isDocked(s.a) {
      #expect(way == "drag, quick")
      #expect(remembered(s.a, s.h) == [own])
    } else {
      #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    }
  }
}
