import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A docked window let go at macOS's own point (the last point of a side, the menu bar, anywhere with ⌥ held) belongs to macOS, if macOS takes it.
/// It does not always: it fills the screen only for a pointer that has rested in the menu bar, it was seen to overlook one that had rested
/// there for 1.7 s, and to show its preview with ⌥ alone held and then do nothing. Whoever carries a window there asked macOS, not Arbor, so either
/// way the window is out of the arrangement and its place closes at the release. What waits is the sizing: Arbor sets no frame while macOS
/// may still be moving the window (rule 1). Half a second after the release it looks at where the window server has it. Moved or
/// sized: macOS's, and Arbor never touches it. Where it was let go: it takes its own size there, in one move (QUESTIONS Q23; board 1.56).
///
/// The arrangement is [a | Desktop | b] with c floating; a and b were 600×400 before they were docked.
@Suite @MainActor struct LeftAloneByMacOSTests {
  let own = CGSize(width: 600, height: 400)

  /// macOS's own points on the standard display, 1440×900 with a menu bar of 25.
  nonisolated static let points = [
    CGPoint(x: 0, y: 450), CGPoint(x: 1439, y: 450), CGPoint(x: 700, y: 0), CGPoint(x: 700, y: 24), CGPoint(x: 0, y: 0), CGPoint(x: 1439, y: 899),
  ]

  /// The frames Arbor has set on `window` since the log was cleared.
  func framesSet(on window: WindowID, _ s: DragScene) -> [CGRect] { s.h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// a is carried out of its slot to `point`, rests there, and is let go. macOS does nothing about it.
  func carryAndBeOverlooked(_ s: DragScene, to point: CGPoint, holding keys: KeyChord.Modifiers = []) {
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 0.3)
    s.h.system.holdModifierKeys(keys)
    s.h.system.holdDrag(for: 1)
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
  }

  /// No window is left that no layout may touch, and no timer. (What could not be looked at waits to be heard of, unshielded.)
  func expectTheShieldHasEnded(_ s: DragScene, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!s.h.controller.leftToMacOS.keys.contains { s.h.controller.isInOtherHands($0) }, "\(s.h.controller.leftToMacOS)", sourceLocation: sourceLocation)
    #expect(!s.h.scheduler.pendingKeys.contains { $0.hasPrefix(Controller.leftToMacOSKey) }, sourceLocation: sourceLocation)
    #expect(s.h.controller.invariantViolations().isEmpty, "\(s.h.controller.invariantViolations())", sourceLocation: sourceLocation)
  }

  /// A window that is sized on the way rests a point short of the tile.
  func expectInMacOSsTile(_ s: DragScene, at point: CGPoint, sourceLocation: SourceLocation = #_sourceLocation) {
    let tile = s.h.system.macTile(at: point)!
    #expect(s.frame(s.a).approximatelyEquals(tile, tolerance: 1), "\(s.frame(s.a)), the tile is \(tile)", sourceLocation: sourceLocation)
  }

  func expectItsOwnSizeInView(_ s: DragScene, sourceLocation: SourceLocation = #_sourceLocation) {
    let frame = s.frame(s.a)
    #expect(s.h.workspace.isFloating(s.a), sourceLocation: sourceLocation)
    #expect(frame.size == own, "\(frame)", sourceLocation: sourceLocation)
    #expect(s.h.workspace.floating[s.a] == frame, "what is remembered: \(String(describing: s.h.workspace.floating[s.a]))", sourceLocation: sourceLocation)
    #expect(frame.minY >= s.h.visibleFrame.minY, "its title bar is not under the menu bar: \(frame)", sourceLocation: sourceLocation)
    #expect(frame.fractionInside(s.h.visibleFrame) >= 0.5, "\(frame)", sourceLocation: sourceLocation)
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty, sourceLocation: sourceLocation)
  }

  // MARK: Not taken

  @Test(arguments: points) func overlookedItTakesItsOwnSizeWhereItLiesInOneMoveAndNotBeforeMacOSWouldBeDone(point: CGPoint) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: point)
    let letGo = s.frame(s.a)
    // Its place closes at the release, as it does when macOS takes the window: nobody waits.
    #expect(s.h.workspace.isFloating(s.a))
    let neighbour = s.frame(s.b)
    s.h.scheduler.advance(by: 0.45)
    #expect(framesSet(on: s.a, s).isEmpty, "macOS's own move takes up to 0.4 s: \(framesSet(on: s.a, s))")
    #expect(s.frame(s.a) == letGo)
    s.h.scheduler.advance(by: 0.1)
    #expect(s.frame(s.a).size == own, "nor much later: \(s.frame(s.a))")
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.frame(s.b) == neighbour, "nobody else moves for it")
    #expect(s.h.overlays.messages.isEmpty, "macOS took nothing, so there is nothing to say: \(s.h.overlays.messages.map(\.model.line))")
    s.expectNothingLeftBehind()
  }

  /// An ordinary flick upwards.
  @Test func thrownIntoTheMenuBarAndLetGoAtOnceItTakesItsOwnSize() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    // Under the point where it was let go, as far along its title bar as before.
    #expect(s.frame(s.a).minX < 700 && s.frame(s.a).maxX > 700, "\(s.frame(s.a))")
    s.expectNothingLeftBehind()
  }

  /// The place says what the drop means; ⌥ only adds a wish to macOS. Posted events had macOS show its preview and do nothing, 10 times of 10.
  @Test func letGoOverTheDesktopWithOptionHeldItFloatsThereAtItsOwnSize() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: s.onDesktop, holding: .option)
    let pointer = s.h.system.cursor
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.frame(s.a).insetBy(dx: -1, dy: -1).contains(pointer), "\(s.frame(s.a)) is not under \(pointer)")
    s.expectNothingLeftBehind()
  }

  /// Nobody saw the button come up. macOS did, and has long done what it was going to do.
  @Test func withTheReleaseLostItTakesItsOwnSizeToo() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.loseTheReleaseOfTheDrag()
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
  }

  /// The window server moves a dragged window at once and its app hears a tenth of a second later. So the app's last word about the drag can
  /// come after the release, with a place from before it. On hosted Macs: at most one such report, up to 53 points off, never another size.
  /// It is no move of macOS's.
  @Test(arguments: [0.005, 0.1, 0.3]) func theAppsLateWordAboutTheDragDoesNotPassForMacOSsMove(late: Double) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.scheduler.advance(by: late)
    var stale = s.h.system.allWindows().first { $0.id == s.a }!
    let truth = stale
    stale.frame = stale.frame.offsetBy(dx: -31, dy: 43)
    s.h.controller.windowChanged(stale, userInitiated: true)
    s.h.scheduler.advance(by: 0.02)
    s.h.controller.windowChanged(truth, userInitiated: true)
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.h.overlays.messages.isEmpty, "\(s.h.overlays.messages.map(\.model.line))")
  }

  /// And if that word is never put right, it is still the window server that is asked.
  @Test func aLateWordThatIsNeverPutRightDoesNotPassForMacOSsMoveEither() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.scheduler.advance(by: 0.01)
    var stale = s.h.system.allWindows().first { $0.id == s.a }!
    stale.frame = stale.frame.offsetBy(dx: -31, dy: 43)
    s.h.controller.windowChanged(stale, userInitiated: true)
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.h.overlays.messages.isEmpty, "\(s.h.overlays.messages.map(\.model.line))")
  }

  /// The window server and the app round differently. A point is no move.
  @Test func aPointOffIsStillWhereItWasLetGo() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.system.moveSilently(s.a, to: s.frame(s.a).offsetBy(dx: 1, dy: -1))
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
  }

  @Test func undoTakesItBackIntoItsSlotAndRedoOutAtItsOwnSize() {
    let s = DragScene()
    let slot = s.frame(s.a)
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 3)
    let out = s.frame(s.a)
    s.h.run("undo")
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a) == slot)
    s.h.run("redo")
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == out.size, "\(s.frame(s.a))")
    s.expectNothingLeftBehind()
  }

  // MARK: Taken

  /// Whatever macOS makes of it, Arbor sets no frame on it, at the look or ever.
  @Test(arguments: points) func takenByMacOSItIsNeverTouched(point: CGPoint) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 5)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    expectInMacOSsTile(s, at: point)
    #expect(s.h.workspace.floating[s.a] == s.frame(s.a))
    s.expectNothingLeftBehind()
  }

  /// A window that cannot grow is moved into the tile as large as it is: the slot's size still, at another place. That is macOS's doing too.
  @Test func movedIntoTheTileWithoutBeingSizedItIsMacOSsAllTheSame() {
    let s = DragScene()
    let slot = s.frame(s.a).size
    s.h.system.setMaximumSize(s.a, slot)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 1439, y: 450), holding: 1)
    let letGo = s.frame(s.a)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 5)
    #expect(s.frame(s.a).size == slot && s.frame(s.a) != letGo, "\(s.frame(s.a))")
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
  }

  /// Whoever held ⌥ asked macOS. There is nothing to tell them.
  @Test func takenWithOptionHeldNothingIsSaid() {
    let s = DragScene()
    s.h.system.optionAloneTiles = true
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.holdModifierKeys(.option)
    s.h.system.holdDrag(for: 1)
    let letGo = s.frame(s.a)
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) != letGo && framesSet(on: s.a, s).isEmpty, "\(s.frame(s.a)), \(framesSet(on: s.a, s))")
    #expect(s.h.overlays.messages.isEmpty, "\(s.h.overlays.messages.map(\.model.line))")
  }

  /// A window that was in macOS's tile before it was docked, thrown to the same point again. The tile is as large as its own size, and is a tile all the same: the
  /// hint is shown, and the slot's size that macOS gives back at the next drag does not stay.
  @Test(arguments: [CGPoint(x: 0, y: 450), CGPoint(x: 700, y: 0)]) func aTileAsLargeAsItsOwnSizeIsStillATile(point: CGPoint) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: h.system.macTile(at: point)!)
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    for line in ["dock \(a.rawValue) left", "dock \(b.rawValue) right"] { h.run(line) }
    h.scheduler.runPending()
    let slot = h.frame(a)!.size
    h.system.beginDrag(a)
    h.system.moveDrag(to: CGPoint(x: 600, y: 450), holding: 0.3)
    h.system.moveDrag(to: point, holding: 1)
    h.system.endDrag()
    h.scheduler.advance(by: 3)
    #expect(h.overlays.messages.contains { $0.model.line.contains("macOS tiled") }, "\(h.overlays.messages.map(\.model.line))")
    h.system.beginDrag(a)
    h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.5)
    h.system.endDrag()
    h.scheduler.advance(by: 3)
    #expect(h.frame(a)?.size != slot, "\(h.frame(a)!)")
    #expect(h.workspace.floating[a] == h.frame(a), "\(String(describing: h.workspace.floating[a]))")
  }

  /// A short way is a way: thirty points, no other size, and no word from its app yet.
  @Test func movedThirtyPointsItIsMacOSs() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.scheduler.advance(by: 0.2)
    let moved = s.frame(s.a).offsetBy(dx: 30, dy: 0)
    s.h.system.moveSilently(s.a, to: moved)
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    #expect(s.h.workspace.floating[s.a] == moved, "the books say what is on the screen: \(String(describing: s.h.workspace.floating[s.a]))")
  }

  /// Arbor can hear of the release late, when the window is already on its way. What it takes for the frame at the release is then a frame of
  /// macOS's travel, and the window has left it by the time Arbor looks.
  @Test func heardOfLateTheReleaseFindsTheWindowOnItsWayAndItIsMacOSs() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 1)
    s.h.system.loseTheReleaseOfTheDrag()
    s.h.scheduler.advance(by: 5)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    #expect(s.frame(s.a) == s.h.visibleFrame)
  }

  // MARK: Meanwhile

  /// Nothing is moved under a hand. The look waits for the button, and a window that is in the hand again ends in a drop of its own.
  @Test func withTheButtonDownAgainTheLookWaits() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.2)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 760, y: 500), holding: 2)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
  }

  @Test func takenInHandAgainBeforeTheLookItTakesItsOwnSizeWhereThatDragEnds() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.2)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 2)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.frame(s.a).contains(CGPoint(x: 700, y: 405)), "\(s.frame(s.a))")
  }

  /// Whatever becomes of the window in that half second, the look does nothing to a window that is no longer as it was left.
  /// And the shield always ends: no window is left that no layout may touch.
  @Test(arguments: [
    "close", "minimize", "hide", "full screen", "dock", "resize", "move", "exclude", "pause", "pause and resume", "quit", "float-all", "its app quits",
    "its app hangs", "the permission goes", "the display goes", "another display comes",
  ])
  func whatHasBecomeSomethingElseMeanwhileIsLeftAlone(what: String) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.2)
    let a = s.a.rawValue
    switch what {
    case "close": s.h.system.close(s.a)
    case "minimize": s.h.system.setMinimized(s.a, true)
    case "hide": s.h.system.setHidden(pid: 1000, true)
    case "full screen": s.h.system.setFullScreen(s.a, true)
    case "dock": s.h.run("dock \(a) left")
    case "resize": s.h.system.userResize(s.a, to: CGRect(x: 468, y: 25, width: 500, height: 500))
    case "move": s.h.system.userMove(s.a, to: s.frame(s.a).offsetBy(dx: 60, dy: 80))
    case "exclude": s.h.run("exclude com.example.safari")
    case "pause and resume": for line in ["pause", "resume"] { s.h.run(line) }
    case "its app quits": s.h.system.quit(pid: 1000)
    case "its app hangs": s.h.system.setUnresponsive(pid: 1000, true)
    case "the permission goes": s.h.revokeAccessibility()
    case "the display goes":
      s.h.system.setDisplays([
        DisplaySnapshot(
          id: DisplayID("other"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true)
      ])
    case "another display comes":
      s.h.system.setDisplays([
        FakeWindowSystem.standardDisplay,
        DisplaySnapshot(
          id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775),
          isMain: false),
      ])
    case "quit":
      s.h.run("quit")
      s.h.controller.shutdown()
    default: s.h.run(what)
    }
    s.h.scheduler.advance(by: 0.1)
    let then = s.h.frame(s.a)
    let moves = framesSet(on: s.a, s).count
    s.h.scheduler.advance(by: 6)
    // Displays that change are settled later than that, and lay everything out afresh.
    if !what.contains("display") {
      #expect(s.h.frame(s.a) == then, "\(String(describing: s.h.frame(s.a)))")
      #expect(framesSet(on: s.a, s).count == moves, "\(framesSet(on: s.a, s))")
    }
    expectTheShieldHasEnded(s)
    // And where Arbor still arranges it and it can be seen, the books say what is on the screen.
    if ["resize", "move", "float-all", "pause and resume", "the display goes", "another display comes"].contains(what) {
      let books = s.h.controller.workspaces.values.compactMap { $0.floating[s.a] }
      #expect(books == [s.frame(s.a)], "books \(books), screen \(s.frame(s.a))")
    }
  }

  /// The button that stays down puts the look off, not away: when it comes up at last, the shield ends.
  @Test func howeverLongTheButtonIsDownTheShieldEndsWhenItComesUp() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.system.beginDrag(s.c)
    s.h.system.holdDrag(for: 60)
    #expect(s.h.controller.isInOtherHands(s.a))
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 1)
    #expect(s.h.controller.leftToMacOS.isEmpty)
    expectItsOwnSizeInView(s)
  }

  /// Thrown, caught and thrown again within the half second: the second throw has a look of its own, half a second after it, and the first neither ends
  /// it nor is left over.
  @Test func theSameWindowThrownTwice() {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 0.3)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: CGPoint(x: 900, y: 12), holding: 0.05)
    // (To the fake the pointer has been in the menu bar all along, where it lets a title bar go.)
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 0.45)
    #expect(framesSet(on: s.a, s).isEmpty, "0.8 s after the first throw, 0.45 s after the second: \(framesSet(on: s.a, s))")
    #expect(s.h.controller.isInOtherHands(s.a))
    s.h.scheduler.advance(by: 3)
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectItsOwnSizeInView(s)
    #expect(s.frame(s.a).minX < 900 && s.frame(s.a).maxX > 900, "where the second throw left it: \(s.frame(s.a))")
    #expect(s.h.controller.leftToMacOS.isEmpty)
    #expect(!s.h.scheduler.pendingKeys.contains { $0.hasPrefix(Controller.leftToMacOSKey) })
  }

  /// A window that cannot be looked at when the time comes is looked at when it is next heard of. Nothing is moving it or laying it out meanwhile, so it has
  /// no shield and no timer. A difference between the books and the screen must not last.
  @Test(arguments: ["its app hangs", "minimized", "hidden", "on another Space", "in full screen"], [1.0, 20]) func awayAtTheLookItIsLookedAtWhenItIsBack(what: String, seconds: Double) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.1)
    func away(_ yes: Bool) {
      switch what {
      case "its app hangs": s.h.system.setUnresponsive(pid: 1000, yes)
      case "minimized": s.h.system.setMinimized(s.a, yes)
      case "hidden": s.h.system.setHidden(pid: 1000, yes)
      case "on another Space": s.h.system.setOnActiveSpace(s.a, !yes)
      default: s.h.system.setFullScreen(s.a, yes)
      }
    }
    away(true)
    s.h.scheduler.advance(by: seconds)
    expectTheShieldHasEnded(s)
    #expect(s.h.workspace.floating[s.a]?.size == own, "a slot's size, or a screen's, is never its own: \(String(describing: s.h.workspace.floating[s.a]))")
    away(false)
    s.h.scheduler.advance(by: 30)
    expectItsOwnSizeInView(s)
    #expect(s.h.controller.leftToMacOS.isEmpty)
    expectTheShieldHasEnded(s)
  }

  /// The look comes half a second after the FIRST word of a window that is back. An app that goes on talking (a title that changes three times a second) does not
  /// put it off.
  @Test func anOwedLookIsMadeThoughTheAppKeepsTalking() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.1)
    s.h.system.setMinimized(s.a, true)
    s.h.scheduler.advance(by: 3)
    s.h.system.setMinimized(s.a, false)
    for n in 0..<10 {
      s.h.scheduler.advance(by: 0.3)
      s.h.system.setTitle(s.a, "page \(n)")
    }
    expectItsOwnSizeInView(s)
    #expect(s.h.controller.leftToMacOS.isEmpty)
  }

  /// Taken back within the half second and brought out again later. What comes back is not the moment in which the books and the screen differed.
  @Test(arguments: [["undo", "redo"], ["arrange", "undo"]], [0.2, 20]) func takenBackWithinTheHalfSecondAndBroughtOutAgain(lines: [String], later: Double) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.scheduler.advance(by: 0.4)
    s.h.run(lines[0])
    s.h.scheduler.advance(by: later)
    s.h.run(lines[1])
    s.h.scheduler.advance(by: 60)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    // (Where it lies is the layout's business, as for every floating window that comes back with an arrangement.)
    #expect(s.h.workspace.floating[s.a]?.size == own, "\(String(describing: s.h.workspace.floating[s.a]))")
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty, "\(s.h.controller.leftAsLargeAsTheirSlots)")
    expectTheShieldHasEnded(s)
  }

  /// In a slot again before the look, by a hand or a key: macOS never had the window, and no note is left of what it might have given back.
  @Test(arguments: ["by hand", "by a key"]) func dockedAgainBeforeTheLookNoNoteIsLeft(how: String) {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 10))
    s.h.scheduler.advance(by: 0.3)
    if how == "by hand" {
      s.h.system.beginDrag(s.a)
      s.h.system.moveDrag(to: s.edge(.left, of: s.b), holding: 1)
      s.h.system.endDrag()
    } else {
      s.h.run("dock \(s.a.rawValue) left")
    }
    s.h.scheduler.advance(by: 60)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty, "\(s.h.controller.leftAsLargeAsTheirSlots)")
    expectTheShieldHasEnded(s)
  }

  /// The display it lies on goes. Everything is laid out afresh, and it with the rest.
  @Test func theDisplayGoesWithinTheHalfSecondAndTheWindowIsInViewOnTheOther() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.1)
    s.h.system.setDisplays([
      DisplaySnapshot(
        id: DisplayID("other"), frame: CGRect(x: 0, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true)
    ])
    s.h.scheduler.advance(by: 20)
    #expect(s.h.system.isVisible(s.a), "\(s.frame(s.a))")
    #expect(!s.h.controller.parked.contains(s.a))
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    expectTheShieldHasEnded(s)
  }

  /// ⌘T in the window that was just thrown: another window id at the same frame. The look is the tab's now.
  @Test func aNewTabWithinTheHalfSecondIsLookedAtInstead() throws {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.scheduler.advance(by: 0.1)
    let tab = try #require(s.h.system.openTab(in: s.a))
    s.h.scheduler.advance(by: 60)
    #expect(s.h.controller.leftToMacOS.isEmpty, "\(s.h.controller.leftToMacOS)")
    expectTheShieldHasEnded(s)
    #expect(s.h.frame(tab)?.size == own, "\(String(describing: s.h.frame(tab)))")
    #expect(s.h.workspace.floating[tab] == s.h.frame(tab))
    s.h.run("zoom \(s.b.rawValue)")
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.parked.contains(tab), "laid out like any other, it leaves with the Desktop")
  }

  /// The view moves on within the half second and the Desktop goes out of view. The window missed that; it goes after the look, in one move, and comes back at its
  /// own size.
  @Test(arguments: [true, false]) func theViewMovesOnWithinTheHalfSecondAndTheWindowGoesWithTheDesktop(overlooked: Bool) {
    let s = DragScene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.macOSOverlooksTheNextDrop = overlooked
    s.h.system.passTime = { [h = s.h] seconds in
      h.system.passTime = { h.scheduler.advance(by: $0) }
      h.scheduler.advance(by: seconds / 2)
      h.run("zoom \(s.b.rawValue)")
      h.scheduler.advance(by: seconds / 2)
    }
    s.h.system.endDrag()
    if overlooked { s.h.system.passTime?(0.15) }
    s.h.scheduler.advance(by: 0.2)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    s.h.scheduler.advance(by: 5)
    #expect(s.h.controller.parked.contains(s.c), "the other floating window has left with the Desktop")
    #expect(s.h.controller.parked.contains(s.a), "\(s.frame(s.a)) lies over the framed window")
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
    expectTheShieldHasEnded(s)
    s.h.run("back")
    s.h.scheduler.advance(by: 3)
    guard overlooked else {
      // That it comes back narrower, squeezed off the docked window, is the board's 1.18. What is remembered is the tile.
      let tile = s.h.system.macTile(at: CGPoint(x: 0, y: 450))!
      #expect(s.h.workspace.floating[s.a]?.approximatelyEquals(tile, tolerance: 1) == true, "\(String(describing: s.h.workspace.floating[s.a]))")
      #expect(s.frame(s.a).origin == s.h.workspace.floating[s.a]?.origin, "\(s.frame(s.a))")
      return
    }
    #expect(s.h.workspace.floating[s.a] == s.frame(s.a), "books \(String(describing: s.h.workspace.floating[s.a])), screen \(s.frame(s.a))")
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
  }

  /// For that half second the books and the screen differ, and macOS may be about to move the window. Whatever lays the display out meanwhile leaves it
  /// alone; afterwards there is nothing to put right.
  /// Also where floating windows make way for docked ones, which is when layouts place them at all.
  @Test(arguments: [[true, true], [true, false], [false, true], [false, false]], ["close c", "minimize b", "dock c", "set gap 20", "zoom and back", "pin"])
  func noLayoutTouchesItBeforeTheLook(how: [Bool], act: String) {
    let (overlooked, makingWay) = (how[0], how[1])
    let s = DragScene { $0.floatingWindowsMakeWay = makingWay }
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    s.h.system.macOSOverlooksTheNextDrop = overlooked
    // Between the release and macOS's first step.
    s.h.system.passTime = { [h = s.h] seconds in
      h.system.passTime = { h.scheduler.advance(by: $0) }
      h.scheduler.advance(by: seconds / 2)
      switch act {
      case "close c": h.system.close(s.c)
      case "minimize b": h.system.setMinimized(s.b, true)
      case "dock c": h.run("dock \(s.c.rawValue) right")
      case "zoom and back": for line in ["zoom \(s.b.rawValue)", "back"] { h.run(line) }
      case "pin": h.run("pin \(s.a.rawValue)")
      default: h.run(act)
      }
      h.scheduler.advance(by: seconds / 2)
    }
    s.h.system.endDrag()
    if overlooked { s.h.system.passTime?(0.15) }
    s.h.scheduler.advance(by: 0.2)
    #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
    s.h.scheduler.advance(by: 3)
    if overlooked {
      #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
      #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    } else {
      #expect(framesSet(on: s.a, s).isEmpty, "\(framesSet(on: s.a, s))")
      expectInMacOSsTile(s, at: CGPoint(x: 0, y: 450))
    }
    #expect(s.h.workspace.floating[s.a] == s.frame(s.a), "the books say what is on the screen: \(String(describing: s.h.workspace.floating[s.a]))")
  }

  /// And once it has its own size, nothing that happens to other windows changes it.
  @Test(arguments: ["close c", "minimize b", "set gap 20", "zoom and back"], [true, false])
  func afterwardsAnUnrelatedActLeavesItsSizeAlone(act: String, makingWay: Bool) {
    let s = DragScene { $0.floatingWindowsMakeWay = makingWay }
    carryAndBeOverlooked(s, to: s.onDesktop, holding: .option)
    s.h.scheduler.advance(by: 3)
    switch act {
    case "close c": s.h.system.close(s.c)
    case "minimize b": s.h.system.setMinimized(s.b, true)
    case "zoom and back": for line in ["zoom \(s.b.rawValue)", "back"] { s.h.run(line) }
    default: s.h.run(act)
    }
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
  }

  /// One look for each window.
  @Test func twoWindowsLeftAloneWithinHalfASecondBothTakeTheirOwnSizes() {
    let s = DragScene()
    carryAndBeOverlooked(s, to: CGPoint(x: 700, y: 0))
    s.h.system.beginDrag(s.b)
    s.h.system.moveDrag(to: CGPoint(x: 900, y: 10), holding: 0.05)
    s.h.system.macOSOverlooksTheNextDrop = true
    s.h.system.endDrag()
    // It made room when the first one left.
    let before = framesSet(on: s.b, s).count
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    #expect(s.frame(s.b).size == own, "\(s.frame(s.b))")
    #expect(framesSet(on: s.a, s).count == 1 && framesSet(on: s.b, s).count == before + 1, "\(s.h.system.frameLog)")
    #expect(s.h.controller.leftAsLargeAsTheirSlots.isEmpty)
    #expect(s.h.controller.leftToMacOS.isEmpty)
  }

  /// On the other display's menu bar, it is that display it floats on.
  @Test func letGoInTheMenuBarOfAnotherDisplay() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)
    let s = DragScene(displays: [FakeWindowSystem.standardDisplay, side])
    carryAndBeOverlooked(s, to: CGPoint(x: 2000, y: 5))
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.workspaces[side.id]?.isFloating(s.a) == true)
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    #expect(side.visibleFrame.contains(s.frame(s.a)), "\(s.frame(s.a))")
    #expect(framesSet(on: s.a, s).count == 1, "\(framesSet(on: s.a, s))")
  }

  /// A floating window has its own size in the hand. Left alone, it stays where it was let go, and Arbor sets no frame.
  @Test(arguments: points) func aFloatingWindowThatIsOverlookedStaysAsItIs(point: CGPoint) {
    let s = DragScene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: point, holding: 1)
    s.h.system.macOSOverlooksTheNextDrop = true
    let letGo = s.frame(s.c)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == letGo)
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty)
  }

  // MARK: In macOS's band, short of its point

  /// macOS never acts there, so nothing has to be waited for, and Arbor offers nothing there either: a drag that asked Arbor and found no target takes
  /// the window home, at once, at all three edges alike. (At the top the Desktop reaches up to the edge, which used to pass for a drop
  /// onto the Desktop.)
  @Test(arguments: [
    CGPoint(x: 5, y: 450), CGPoint(x: 1434, y: 450), CGPoint(x: 720, y: 27), CGPoint(x: 720, y: 36), CGPoint(x: 5, y: 30), CGPoint(x: 1434, y: 30),
  ]) func shortOfMacOSsPointADockedWindowGoesHomeAtEveryEdge(point: CGPoint) {
    for window in [\DragScene.a, \DragScene.b] {
      let s = DragScene()
      let dragged = s[keyPath: window]
      let before = [s.a: s.frame(s.a), s.b: s.frame(s.b), s.c: s.frame(s.c)]
      s.h.system.beginDrag(dragged)
      s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
      s.h.system.moveDrag(to: point, holding: 1)
      #expect(s.h.overlays.preview == nil)
      s.h.system.endDrag()
      #expect(s.h.workspace.isDocked(dragged), "at \(point)")
      #expect(framesSet(on: dragged, s).count == 1, "home in one move: \(framesSet(on: dragged, s))")
      s.h.scheduler.advance(by: 3)
      #expect([s.a: s.frame(s.a), s.b: s.frame(s.b), s.c: s.frame(s.c)] == before, "at \(point)")
      #expect(s.h.system.frameLog.count == 1, "its neighbours are not touched: \(s.h.system.frameLog)")
      s.expectNothingLeftBehind()
    }
  }

  /// With macOS's tiling off the top edge is Arbor's, and the band in which a drag began is silent only until the pointer has left it. A docked window
  /// in the top row slid sideways onto the Desktop comes out, as ever.
  /// Nobody pushes a window against an edge beyond which another display begins. Carried across and let go just past the border, it floats there as ever.
  @Test(arguments: [1446.0, 1434]) func theBorderBetweenTwoDisplaysIsNoEdgeOfTheScreen(x: Double) {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)
    let s = DragScene(displays: [FakeWindowSystem.standardDisplay, side])
    // b is docked at the right of the main display, so just short of the border there is a slot and no Desktop.
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: x, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    if x > 1440 {
      #expect(s.h.controller.workspaces[side.id]?.isFloating(s.a) == true, "\(s.frame(s.a))")
      #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
    } else {
      #expect(s.h.workspace.isDocked(s.a), "\(s.frame(s.a))")
    }
    s.expectNothingLeftBehind()
  }

  /// With a gap smaller than the band, the top of a top-row window's title bar lies in macOS's band. Taken there and slid sideways onto the Desktop, the window comes
  /// out as ever: nobody carried it to the edge.
  @Test(arguments: [0.0, 4]) func takenByTheTopOfItsTitleBarAndSlidOntoTheDesktopItComesOut(gap: Double) {
    let s = DragScene { $0.gap = gap }
    let bar = CGPoint(x: s.frame(s.a).midX, y: s.frame(s.a).minY + 5)
    s.h.system.beginDrag(s.a, at: bar)
    s.h.system.moveDrag(to: CGPoint(x: s.desktop.midX, y: bar.y), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == own, "\(s.frame(s.a))")
  }

  @Test func withTilingOffADockedWindowSlidAlongTheTopOntoTheDesktopStillComesOut() {
    let s = DragScene { $0.gap = 4 }
    s.h.system.tiling = .off
    let bar = CGPoint(x: s.frame(s.a).midX, y: s.frame(s.a).minY + 5)
    #expect(bar.y < s.h.visibleFrame.minY + 12, "its title bar lies in the top band")
    s.h.system.beginDrag(s.a, at: bar)
    s.h.system.moveDrag(to: CGPoint(x: s.desktop.midX, y: bar.y), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == own)
  }
}
