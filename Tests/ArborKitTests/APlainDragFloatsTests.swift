import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A dragged window floats; it docks only when asked, by ⌘ held during the drag (`dragDocks`, collab/QUESTIONS.md Q29).
///
/// Everywhere else in the tests `drag` and `beginDrag` are by a hand that means to dock, which holds what Arbor is set to ask for
/// (docs/TESTING.md). Here the drags are `plainly`, and ⌘ goes down and up by name.
///
/// The arrangement is `DragScene`'s: [a | Desktop | b] with c floating on the Desktop.
@Suite @MainActor struct APlainDragFloatsTests {
  /// Everywhere a drag could dock c: the four bands along the screen's edges and every edge of both docked windows.
  private func targets(_ s: DragScene) -> [(name: String, point: CGPoint)] {
    let visible = FakeWindowSystem.standardDisplay.visibleFrame
    return [
      ("the left edge of the screen", CGPoint(x: visible.minX + 3, y: visible.midY)),
      ("the right edge of the screen", CGPoint(x: visible.maxX - 3, y: visible.midY)),
      ("the top edge of the screen", CGPoint(x: visible.midX, y: visible.minY + 3)),
      ("the bottom edge of the screen", CGPoint(x: visible.midX, y: visible.maxY - 3)),
    ] + [s.a, s.b].flatMap { window in Edge.allCases.map { ("the \($0) edge of \(window)", s.edge($0, of: window)) } }
  }

  // MARK: Nothing held

  /// Of a floating window, without exception: from the press to after the release Arbor sets no frame on any window.
  @Test func aPlainDragDocksNowhereShowsNothingAndMovesNothingElse() {
    let s = DragScene()
    s.h.system.tiling = .off
    let before = s.h.workspace.tree
    for (name, point) in targets(s) {
      s.h.system.drag(s.c, through: [s.frame(s.c).center, point], plainly: true)
      #expect(s.h.workspace.isFloating(s.c), "let go at \(name)")
      // Where the hand left it: the pointer took hold 10 points below its top, in the middle. No window goes under the menu bar.
      let top = max(point.y - 10, FakeWindowSystem.standardDisplay.visibleFrame.minY)
      #expect(s.frame(s.c).origin == CGPoint(x: point.x - 200, y: top), "let go at \(name)")
    }
    #expect(s.h.workspace.tree == before)
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil }, "no preview, not for a moment")
    #expect(s.h.system.frameLog.isEmpty, "Arbor set no frame on any window: \(s.h.system.frameLog)")
    #expect(s.h.overlays.headsUp.isEmpty, "and said nothing")
    s.expectNothingLeftBehind()
  }

  /// No waiting over a target either: a plain drag starts no timer of its own. (The press gives the window the keyboard, and the ring round
  /// the window with the keyboard follows it on timers of the ring's, whatever moves the window.)
  @Test func aPlainDragStartsNoTimer() {
    let s = DragScene()
    let butTheRings = { s.h.scheduler.pendingKeys.filter { !$0.hasPrefix("focus-ring") } }
    let before = butTheRings()
    s.h.system.beginDrag(s.c, plainly: true)
    for (name, point) in targets(s) {
      s.h.system.moveDrag(to: point)
      #expect(butTheRings() == before, "over \(name)")
    }
    s.h.system.endDrag()
    #expect(!s.h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") || $0 == "left-to-macos" })
  }

  /// As a Mac comes. Where macOS tiles, it tiles; Arbor does nothing about it and has nothing to say.
  @Test func atMacOSsDefaultsAPlainDragIsMacOSsAlone() {
    let s = DragScene()
    #expect(s.h.system.tiling == .on)
    let display = FakeWindowSystem.standardDisplay
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: display.frame.minX, y: display.visibleFrame.midY)], plainly: true)
    s.h.scheduler.advance(by: 2)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.frame(s.c).width == display.visibleFrame.width / 2, "macOS made it its left half")
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect(s.h.overlays.headsUp.isEmpty, "whoever drags plainly to macOS's edge means macOS")
    s.expectNothingLeftBehind()
  }

  /// Whoever held ⌘ meant Arbor's edge and got macOS's tile: they are told where that can be changed, as before.
  @Test func withCommandHeldAtMacOSsEdgeTheLineIsStillSaid() {
    let s = DragScene()
    let display = FakeWindowSystem.standardDisplay
    s.h.system.heldModifiers = .command
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: display.frame.minX, y: display.visibleFrame.midY)], plainly: true)
    s.h.system.heldModifiers = []
    s.h.scheduler.advance(by: 1)
    #expect(s.h.workspace.isFloating(s.c), "macOS asks nobody: the edge is its own, ⌘ or not (Q23)")
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect(s.h.overlays.headsUp[display.id] != nil)
  }

  // MARK: ⌘

  @Test func withCommandHeldADragDocks() {
    for index in targets(DragScene()).indices {
      let s = DragScene()
      s.h.system.tiling = .off
      let (name, point) = targets(s)[index]
      s.h.system.heldModifiers = .command
      s.h.system.drag(s.c, through: [s.frame(s.c).center, point], plainly: true)
      s.h.system.heldModifiers = []
      #expect(s.h.workspace.isDocked(s.c), "let go at \(name)")
      #expect(s.h.overlays.previewHistory.contains { $0 != nil }, "shown first, at \(name)")
      s.expectNothingLeftBehind()
    }
  }

  @Test func commandGoingDownOnTheWayBringsThePreviewAndGoingUpTakesItAway() {
    let s = DragScene()
    s.h.system.tiling = .off
    s.h.system.beginDrag(s.c, plainly: true)
    // At a screen edge: at once, with the pointer at rest.
    s.h.system.moveDrag(to: CGPoint(x: 3, y: 450), holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdModifierKeys(.command)
    #expect(s.h.overlays.preview != nil)
    s.h.system.holdModifierKeys([])
    #expect(s.h.overlays.preview == nil)
    // Over a window's edge: once it has been held for `dropDwell`, counted from the key.
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdModifierKeys(.command)
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdDrag(for: 0.16)
    #expect(s.h.overlays.preview != nil)
    s.h.system.holdModifierKeys([])
    #expect(s.h.overlays.preview == nil)
    #expect(s.h.system.frameLog.isEmpty, "a preview moves nothing: \(s.h.system.frameLog)")
    // Let go of before the window: no dock.
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.workspace.tree.allWindows == [s.a, s.b])
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  @Test func commandPressedOnTheWayAndHeldToTheEndDocks() {
    let s = DragScene()
    s.h.system.beginDrag(s.c, plainly: true)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.5)
    s.h.system.holdModifierKeys(.command)
    s.h.system.holdDrag(for: 0.3)
    s.h.system.endDrag()
    s.h.system.heldModifiers = []
    #expect(s.h.workspace.isDocked(s.c))
    #expect(s.frame(s.c).minY > s.frame(s.b).maxY)
    s.expectNothingLeftBehind()
  }

  /// No event tells the controller that the key went up; it has to look when the hold is over, and at the release.
  @Test func commandLetGoOfUnseenKeepsTheTargetFromActivating() {
    let s = DragScene()
    s.h.system.heldModifiers = .command
    s.h.system.beginDrag(s.c, plainly: true)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.1)
    s.h.system.heldModifiers = []
    s.h.system.holdDrag(for: 0.3)
    #expect(s.h.overlays.preview == nil)
    #expect(!s.h.scheduler.pendingKeys.contains("drag-dwell"))
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(s.c))
  }

  /// Nothing happens that the preview has not shown: a key that goes down with the release is too late for a window's edge.
  @Test func commandAtTheMomentOfReleaseAloneDocksNothingThatHasToBeHeld() {
    let s = DragScene()
    s.h.system.beginDrag(s.c, plainly: true)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.5)
    s.h.system.heldModifiers = .command
    s.h.system.endDrag()
    s.h.system.heldModifiers = []
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// A busy Mac serves the press late, and word of the drag comes when the pointer already rests at the edge. The window stood
  /// elsewhere when it was taken, so it has been carried there: whoever asks is answered. At macOS's settings as a Mac has them.
  @Test func wordOfADragThatComesWhenThePointerIsAtTheEdgeAlreadyIsAnswered() {
    let h = Harness()
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 100, width: 400, height: 300))
    h.start()
    h.system.beginDrag(window, at: CGPoint(x: 500, y: FakeWindowSystem.standardDisplay.visibleFrame.maxY - 3))
    #expect(h.overlays.preview != nil)
    h.system.endDrag()
    #expect(h.workspace.isDocked(window))
    expectWindowsMatchLayout(h)
  }

  /// Word of where the hand has carried the window can come before word that it is a drag: seen on a hosted Mac, between the press and
  /// `dragBegan` (collab/evidence/traces/drag-to-the-far-edge.jsonl). Where the window stood is what Arbor knew when the button went down.
  @Test func wordOfWhereItWasCarriedThatComesBeforeWordOfTheDragChangesNothing() {
    let h = Harness()
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 100, width: 400, height: 300))
    h.start()
    let edge = CGPoint(x: 500, y: FakeWindowSystem.standardDisplay.visibleFrame.maxY - 3)
    h.system.heldModifiers = DragDocks.key
    h.system.mouseDown = true
    h.system.cursor = edge
    h.controller.pointerPressed()
    h.system.userMove(window, to: CGRect(x: 300, y: edge.y - 10, width: 400, height: 300))
    h.controller.dragBegan(window, at: edge)
    #expect(h.overlays.preview != nil)
    h.system.mouseDown = false
    h.controller.dragEnded(window, at: edge)
    #expect(h.workspace.isDocked(window))
  }

  /// A press of long ago says nothing: the window has lain at the edge since, and is only nudged.
  @Test func whereAWindowStoodAtAPressOfLongAgoIsForgotten() {
    let h = Harness()
    h.system.tiling = .off
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 300, width: 400, height: 300))
    h.start()
    h.controller.pointerPressed()
    h.system.userMove(window, to: CGRect(x: 300, y: 25, width: 400, height: 300))
    h.scheduler.advance(by: 10)
    // This press is not heard of, as presses sometimes are not.
    h.system.heldModifiers = DragDocks.key
    h.system.mouseDown = true
    h.controller.dragBegan(window, at: CGPoint(x: 500, y: 31))
    h.scheduler.advance(by: 1)
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil })
  }

  /// The other way about: a window whose title bar lies in the band has been carried nowhere, however late the word and however far along
  /// the edge the pointer is by then. A ⌘-click that slips docks nothing.
  @Test func wordThatComesLateOfAWindowThatLayAtTheEdgeIsStillNoJourney() {
    let h = Harness()
    h.system.tiling = .off
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 25, width: 400, height: 300))
    h.start()
    h.system.beginDrag(window, at: CGPoint(x: 900, y: 31))
    h.system.holdDrag(for: 1)
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil })
    h.system.endDrag()
    #expect(h.workspace.isFloating(window))
  }

  /// ⌃⌥⌘ is the beginning of a shortcut of Arbor's own. ⇧ and ⌃ beside ⌘ change nothing, and none of the others is the key.
  @Test func whichKeysCount() {
    let table: [(KeyChord.Modifiers, Bool)] = [
      ([], false), (.command, true), ([.command, .shift], true), ([.command, .control], true), ([.command, .option], true),
      ([.control, .option, .command], false), ([.control, .option, .shift, .command], false),
      (.shift, false), (.control, false), (.option, false), ([.control, .option, .shift], false),
    ]
    for (held, docks) in table {
      let s = DragScene()
      // With its switch on, ⌥ makes the window macOS's, whatever else is held (MacTilingTests).
      s.h.system.tiling = .off
      s.h.system.heldModifiers = held
      s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], plainly: true)
      #expect(s.h.workspace.isDocked(s.c) == docks, "\(held)")
    }
  }

  // MARK: A docked window

  /// It comes out wherever it is let go, also where a ⌘-drag would send it home: over the middle of another window, over a gap.
  /// Its own size is the one frame Arbor sets on a window that is dragged plainly. Today it comes at the drop; it is to come in the hand, the
  /// moment the window has left its slot (board 0.22). Either way it is one move from the press to after the release, which is what is asked.
  @Test func aDockedWindowDraggedPlainlyComesOutAtItsOwnSizeAndTheOthersMoveOnce() {
    for place in ["the Desktop", "the middle of the other window", "its own slot, well away from where it was"] {
      // Two halves leave no Desktop between them: that one is played with the column.
      let s = place == "the Desktop" ? DragScene(settings: .withDesktopColumn) : DragScene()
      s.h.system.tiling = .off
      let slot = s.frame(s.a)
      let point: CGPoint =
        switch place {
        case "the Desktop": s.onDesktop
        case "the middle of the other window": s.frame(s.b).center
        default: CGPoint(x: slot.midX + 40, y: slot.midY)
        }
      s.h.beginStep()
      s.h.system.drag(s.a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), point], plainly: true)
      s.h.scheduler.runPending()
      #expect(s.h.workspace.isFloating(s.a), "let go over \(place)")
      #expect(s.h.workspace.tree.allWindows == [s.b], "let go over \(place)")
      #expect(s.frame(s.a).size == CGSize(width: 600, height: 400), "the size it had before it was docked (rule 5), over \(place)")
      let bar = CGRect(x: s.frame(s.a).minX, y: s.frame(s.a).minY, width: 600, height: 28)
      #expect(bar.contains(point), "its title bar is still under the pointer, over \(place): \(s.frame(s.a))")
      #expect(s.h.movesInStep.values.allSatisfy { $0 == 1 }, "one move each (rule 3), over \(place): \(s.h.movesInStep)")
      #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
      s.expectNothingLeftBehind()
    }
  }

  /// A click on a title bar slips by a few points. Nobody who clicked meant to undock a window and see it change its size.
  @Test func aSlipPutsADockedWindowBackAndMovesNothingElse() {
    for (dx, dy, out) in [(5.0, 0.0, false), (0, 9, false), (16, 16, false), (-23, 0, false), (24, 0, true), (18, 18, true)] {
      for reflow in [false, true] {
        let s = DragScene { $0.reflowWhileDragging = reflow }
        s.h.system.tiling = .off
        let (slot, before) = (s.frame(s.a), s.h.workspace.tree)
        let grab = CGPoint(x: slot.midX, y: slot.minY + 10)
        s.h.beginStep()
        s.h.system.drag(s.a, through: [grab, CGPoint(x: grab.x + dx, y: grab.y + dy)], plainly: true)
        s.h.scheduler.runPending()
        #expect(s.h.workspace.isFloating(s.a) == out, "carried by \(dx), \(dy)")
        guard !out else { continue }
        #expect(s.h.workspace.tree == before)
        #expect(s.frame(s.a) == slot, "carried by \(dx), \(dy)")
        #expect(s.h.movesInStep.filter { $0.key != s.a }.isEmpty, "live reflow \(reflow): \(s.h.movesInStep)")
        s.expectNothingLeftBehind()
      }
    }
  }

  /// There and back in one drag is a slip too: it is where it is let go that counts.
  /// A window that cannot grow to its slot lies in the middle of it. The slip is measured from where it lies.
  @Test func aSlipOfAWindowThatIsSmallerThanItsSlotTakesNothingOutEither() throws {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let calculator = h.system.open(app: "Calculator", frame: CGRect(x: 500, y: 300, width: 300, height: 400))
    h.system.setMaximumSize(calculator, CGSize(width: 300, height: 400))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(calculator.rawValue) right")
    h.scheduler.advance(by: 2)
    let (tree, lies) = (h.workspace.tree, try #require(h.frame(calculator)))
    #expect(lies.size == CGSize(width: 300, height: 400))
    h.system.clearFrameLog()
    let bar = CGPoint(x: lies.midX, y: lies.minY + 10)
    h.system.drag(calculator, through: [bar, CGPoint(x: bar.x + 3, y: bar.y + 2)], plainly: true)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.tree == tree)
    #expect(h.frame(calculator) == lies)
    #expect(h.system.frameLog.allSatisfy { $0.window == calculator }, "nothing else moves: \(h.system.frameLog)")
  }

  @Test func carriedAwayAndBackToItsPlaceItStays() {
    let s = DragScene()
    let (slot, before) = (s.frame(s.a), s.h.workspace.tree)
    let grab = CGPoint(x: slot.midX, y: slot.minY + 10)
    s.h.system.drag(s.a, through: [grab, s.frame(s.b).center, CGPoint(x: grab.x + 6, y: grab.y - 4)], plainly: true)
    #expect(s.h.workspace.tree == before)
    #expect(s.frame(s.a) == slot)
    s.expectNothingLeftBehind()
  }

  /// A plain drag means out, however it ends: the release can be lost (another tool's event tap, a busy Mac), and pulling the window back
  /// to its place would undo what its person did.
  @Test func aPlainDragWhoseReleaseIsLostStillTakesADockedWindowOut() {
    let s = DragScene()
    s.h.system.tiling = .off
    s.h.system.dragAndLoseTheRelease(s.a, to: s.frame(s.b).center, plainly: true)
    s.h.scheduler.runPending()
    #expect(s.h.workspace.isFloating(s.a))
    #expect(s.frame(s.a).size == CGSize(width: 600, height: 400))
    #expect(s.frame(s.a).contains(s.frame(s.b).center) || s.frame(s.a).minY == s.frame(s.b).midY - 10, "where it lay: \(s.frame(s.a))")
    s.expectNothingLeftBehind()
    // With the key held it goes home, as ever: where the pointer is by now says nothing about where it was meant to dock. The key is
    // long up when the layer finds the button up, so Arbor goes by what was held when it last looked.
    let held = DragScene()
    let slot = held.frame(held.a)
    held.h.system.dragAndLoseTheRelease(held.a, to: held.frame(held.b).center)
    #expect(held.h.system.modifierKeysDown() == [])
    held.h.scheduler.runPending()
    #expect(held.h.workspace.isDocked(held.a))
    #expect(held.frame(held.a) == slot)
    // And the other way round: a key that happens to be down by then pulls nothing back.
    let late = DragScene()
    late.h.system.tiling = .off
    late.h.system.beginDrag(late.a, plainly: true)
    late.h.system.moveDrag(to: late.frame(late.b).center)
    late.h.system.heldModifiers = .command
    late.h.system.loseTheReleaseOfTheDrag()
    late.h.system.heldModifiers = []
    late.h.scheduler.runPending()
    #expect(late.h.workspace.isFloating(late.a))
  }

  /// Word of a drag can come after word of where it has carried the window (`WindowGrab`'s late start). The window's place is what counts, not
  /// where Arbor last heard of it.
  @Test func aDragThatIsHeardOfLateIsNoSlip() {
    let s = DragScene()
    s.h.system.tiling = .off
    let slot = s.frame(s.a)
    let carried = slot.offsetBy(dx: 300, dy: 120)
    s.h.system.mouseDown = true
    s.h.system.userMove(s.a, to: carried)
    s.h.controller.dragBegan(s.a, at: CGPoint(x: carried.midX, y: carried.minY + 10))
    s.h.system.userMove(s.a, to: carried.offsetBy(dx: 4, dy: 2))
    s.h.system.mouseDown = false
    s.h.controller.dragEnded(s.a, at: CGPoint(x: carried.midX + 4, y: carried.minY + 12))
    s.h.scheduler.runPending()
    #expect(s.h.workspace.isFloating(s.a), "carried 300 points, of which Arbor saw the last four as a drag")
  }

  /// Arbor lets go of every window while one is in the hand. The drag is not over, so nothing has come out yet: no layout without it
  /// first, which would move the others twice. Each window takes its own frame in one move, and the pause comes back to what it left.
  @Test func aPauseInTheMiddleOfAPlainDragMovesNoWindowTwice() {
    let s = DragScene()
    s.h.system.beginDrag(s.a, plainly: true)
    s.h.system.moveDrag(to: s.frame(s.b).center)
    s.h.beginStep()
    s.h.run("pause")
    #expect(s.h.movesInStep.values.allSatisfy { $0 <= 1 }, "\(s.h.movesInStep)")
    #expect(s.frame(s.a).size == CGSize(width: 600, height: 400))
    s.h.system.endDrag()
    s.h.run("resume")
    #expect(s.h.workspace.tree.allWindows == [s.a, s.b])
  }

  /// A held view never widens by itself (F58): the only window in it cannot be floated, and so it cannot be dragged out from under its
  /// audience either, with the key or without.
  @Test func aPlainDragTakesNothingOutFromUnderAHeldView() {
    for lost in [false, true] {
      let s = DragScene()
      s.h.run("zoom \(s.a.rawValue)")
      #expect(s.h.run("hold").ok)
      #expect(!s.h.run("float \(s.a.rawValue)").ok, "the control: a command is refused")
      let (filled, before) = (s.frame(s.a), s.h.workspace)
      let grab = CGPoint(x: filled.midX, y: filled.minY + 10)
      if lost {
        s.h.system.dragAndLoseTheRelease(s.a, to: CGPoint(x: 600, y: 400), plainly: true)
      } else {
        s.h.system.drag(s.a, through: [grab, CGPoint(x: 600, y: 400)], plainly: true)
      }
      s.h.scheduler.runPending()
      #expect(s.h.workspace.isDocked(s.a), "the release \(lost ? "lost" : "seen")")
      #expect(s.h.workspace.camera == before.camera)
      #expect(s.frame(s.a) == filled)
      #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    }
  }

  /// The display under the pointer has gone, and macOS has not said yet where the pointer is now: nobody carried the window there.
  @Test func withTheDisplayUnderThePointerGoneADockedWindowGoesHome() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775),
      isMain: false)
    let s = DragScene(displays: [FakeWindowSystem.standardDisplay, side])
    s.h.system.beginDrag(s.a, plainly: true)
    s.h.system.moveDrag(to: CGPoint(x: 2000, y: 400))
    s.h.system.setDisplays([FakeWindowSystem.standardDisplay])
    s.h.scheduler.runPending()
    s.h.system.endDrag()
    s.h.scheduler.runPending()
    #expect(s.h.workspace.isDocked(s.a))
    s.expectNothingLeftBehind()
  }

  /// With ⌘ held a docked window is dragged as it always was: to another place in the arrangement, home from where there is none.
  @Test func withCommandHeldADockedWindowIsMovedWithinTheArrangementOrGoesHome() {
    let s = DragScene()
    let slot = s.frame(s.a)
    let grab = CGPoint(x: slot.midX, y: slot.minY + 10)
    s.h.system.heldModifiers = .command
    s.h.system.drag(s.a, through: [grab, s.frame(s.b).center], plainly: true)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a) == slot, "nothing is offered in the middle of a window: it goes home")
    s.h.system.drag(s.a, through: [grab, s.edge(.bottom, of: s.b)], plainly: true)
    s.h.system.heldModifiers = []
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a).minY > s.frame(s.b).maxY)
    s.expectNothingLeftBehind()
  }

  // MARK: The setting

  @Test func alwaysBringsBackWhatTheFirstBuildDid() {
    let s = DragScene { $0 = $0.withPlainDragsDocking }
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], plainly: true)
    #expect(s.h.workspace.isDocked(s.c))
    s.h.system.heldModifiers = .command
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.top, of: s.a)], plainly: true)
    s.h.system.heldModifiers = []
    #expect(s.h.workspace.isFloating(s.c), "⌘ turns docking off there")
  }

  @Test func neverMeansThatNoDragDocks() {
    for held: KeyChord.Modifiers in [[], .command] {
      let s = DragScene { $0.dragDocks = "never" }
      s.h.system.tiling = .off
      s.h.system.heldModifiers = held
      for (name, point) in targets(s) {
        s.h.system.drag(s.c, through: [s.frame(s.c).center, point], plainly: true)
        #expect(s.h.workspace.isFloating(s.c), "let go at \(name)")
      }
      #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
      #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
      // The keys dock all the same.
      s.h.system.heldModifiers = []
      s.h.run("dock \(s.c.rawValue) bottom")
      #expect(s.h.workspace.isDocked(s.c))
      // ⌘ means nothing there: a ⌘-click on a docked window's title bar that slips takes nothing out.
      let slot = s.frame(s.a)
      s.h.system.heldModifiers = held
      s.h.system.drag(s.a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: slot.midX + 6, y: slot.minY + 14)], plainly: true)
      s.h.system.heldModifiers = []
      #expect(s.h.workspace.isDocked(s.a), "\(held)")
      #expect(s.frame(s.a) == slot)
    }
  }

  @Test func whatIsNoneOfTheThreeMeansWhatShips() {
    let s = DragScene { $0.dragDocks = "sometimes" }
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], plainly: true)
    #expect(s.h.workspace.isFloating(s.c))
  }

  @Test func theSettingTakesEffectAtOnceAndIsRefusedWhenItIsNoneOfTheThree() {
    let s = DragScene()
    #expect(s.h.run("get dragDocks").message.contains("held"))
    #expect(s.h.run("set dragDocks always").ok)
    s.h.system.drag(s.c, through: [s.frame(s.c).center, s.edge(.bottom, of: s.b)], plainly: true)
    #expect(s.h.workspace.isDocked(s.c))
    #expect(!s.h.run("set dragDocks sometimes").ok)
    #expect(s.h.controller.settings.dragDocks == "always")
  }

  /// A gap between docked windows is a handle of Arbor's own: whoever takes it means Arbor.
  @Test func aGapBetweenDockedWindowsIsDraggedAtEverySetting() throws {
    for setting in DragDocks.allCases {
      let s = DragScene { $0.dragDocks = setting.rawValue }
      let width = s.frame(s.a).width
      let seam = try #require(s.h.overlays.seams[FakeWindowSystem.standardDisplay.id]?.first)
      s.h.overlays.dragSeam(seam, by: 60)
      s.h.scheduler.runPending()
      #expect(s.frame(s.a).width == width + 60, "\(setting)")
    }
  }

  /// The hand of the harnesses: it holds what Arbor is set to ask for, from before the press until after the release.
  @Test func theHarnessesHandHoldsWhatTheSettingAsksFor() {
    for (setting, keys) in [("held", KeyChord.Modifiers.command), ("always", []), ("never", [])] {
      let s = DragScene { $0.dragDocks = setting }
      #expect(s.h.system.modifierKeysDown() == [])
      s.h.system.beginDrag(s.c)
      #expect(s.h.system.modifierKeysDown() == keys, "\(setting)")
      s.h.system.endDrag()
      #expect(s.h.system.modifierKeysDown() == [])
      s.h.system.beginDrag(s.c, plainly: true)
      #expect(s.h.system.modifierKeysDown() == [])
      s.h.system.endDrag()
    }
  }
}

/// The walks' net for plain drags (`plainDragViolations`, ChaosInvariants+SevenRules.swift) goes by what the hand holds. Each test is a control: a fault is done to the
/// world as if Arbor had done it, and the net has to speak; beside it the same story without the fault, where it has to be silent.
@Suite @MainActor struct ChaosPlainDragTests {
  private let scene = [
    "mac-tiling off", "launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400",
    "open 103 Safari pid 1003 at 500 200 420 300", "dock 101 left", "settle",
  ]

  /// Plays `lines`, then `last` with `fault` done as part of it. Returns what this net said about `last`.
  private func nets(after lines: [String], then last: String, fault: ((ChaosRunner) -> Void)? = nil) -> Set<String> {
    let runner = ChaosRunner()
    for line in scene + lines { _ = runner.step(ChaosAction(text: line)) }
    runner.beforeTheNextCheck = fault
    return Set(runner.step(ChaosAction(text: last)).map(\.rule).filter { $0.hasPrefix("plain-drag-") })
  }

  @Test func theWordsOfAPlainDragAreReadAndWritten() {
    #expect(ChaosAction(text: "grab 103 plain") == .grabPlainly(WindowID(103)))
    #expect(ChaosAction.grabPlainly(WindowID(103)).text == "grab 103 plain")
    #expect(ChaosAction(text: "grab 103") == .grab(WindowID(103)))
  }

  @Test func aPreviewInAPlainDragIsCaught() {
    #expect(nets(after: ["grab 103 plain"], then: "carry 3 450").isEmpty)
    let shown = nets(after: ["grab 103 plain"], then: "carry 3 450") { $0.harness.overlays.showDropPreview(CGRect(x: 12, y: 37, width: 400, height: 800)) }
    #expect(shown == ["plain-drag-showed-a-preview"])
    // With the key down, by the hand that means to dock or on the way, a preview is what was asked for.
    #expect(nets(after: ["grab 103"], then: "carry 3 450").isEmpty)
    #expect(nets(after: ["grab 103 plain", "carry 3 450"], then: "cmd down").isEmpty)
    #expect(nets(after: ["grab 103 plain", "carry 3 450", "cmd down"], then: "cmd up").isEmpty)
  }

  @Test func aDockAtTheEndOfAPlainDragIsCaught() {
    let carried = ["grab 103 plain", "carry 3 450", "advance 0.3"]
    #expect(nets(after: carried, then: "release").isEmpty)
    let docked = nets(after: carried, then: "release") { _ = $0.harness.run("dock 103 bottom") }
    #expect(docked.contains("plain-drag-docked"))
    // The same hand where a plain drag is set to dock, and the hand that holds the key: the net stands back.
    #expect(nets(after: ["settings {\"dragDocks\":\"always\"}"] + carried, then: "release").isEmpty)
    #expect(nets(after: ["grab 103", "carry 3 450", "advance 0.3"], then: "release").isEmpty)
    #expect(nets(after: carried + ["cmd down"], then: "release").isEmpty)
  }

  @Test func anotherWindowMovedAtTheEndOfAPlainDragIsCaught() {
    let carried = ["grab 103 plain", "carry 900 600"]
    #expect(nets(after: carried, then: "release").isEmpty)
    let moved = nets(after: carried, then: "release") { _ = $0.system.setFrame(CGRect(x: 820, y: 320, width: 500, height: 400), of: WindowID(102)) }
    #expect(moved == ["plain-drag-moved-another"])
  }

  @Test func aDockedWindowComesOutOrHasOnlySlipped() {
    #expect(nets(after: ["grab 101 plain", "carry 800 500"], then: "release").isEmpty)
    #expect(nets(after: ["grab 101 plain", "carry 372 50"], then: "release").isEmpty)
  }
}
