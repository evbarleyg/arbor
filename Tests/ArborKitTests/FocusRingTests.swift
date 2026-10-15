import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// The line around the window that has the keyboard (docs/features/F37-focus-ring.md).
@Suite @MainActor struct FocusRingScenarioTests {
  /// [a | b | Desktop | c], with the keyboard on c, the window docked last, and long enough ago that
  /// nothing that happens next counts as caused by those commands.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("dock \(c.rawValue) right")
    h.scheduler.advance(by: 2)
    return (h, a, b, c)
  }

  func ring(_ h: Harness) -> FocusRingModel? { h.overlays.scenes[h.display]?.focusRing }

  /// Docks a window on the main display, long enough ago to cause nothing: there is no ring at all until
  /// something is docked somewhere.
  @discardableResult func dockSomething(_ h: Harness) -> WindowID {
    let anchor = h.system.open(app: "Anchor", frame: CGRect(x: 40, y: 500, width: 300, height: 300))
    h.run("dock \(anchor.rawValue) left")
    h.scheduler.advance(by: 2)
    return anchor
  }

  /// The ring is around `window`, where the window really is, and on no other display.
  func expectRing(_ h: Harness, around window: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    let rings = h.overlays.scenes.values.compactMap(\.focusRing)
    #expect(rings.count == 1, "one ring in all", sourceLocation: sourceLocation)
    #expect(rings.first?.window == window, sourceLocation: sourceLocation)
    #expect(rings.first?.frame == h.frame(window), sourceLocation: sourceLocation)
  }

  func expectNoRing(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(h.overlays.scenes.values.compactMap(\.focusRing).isEmpty, sourceLocation: sourceLocation)
  }

  // MARK: Following focus

  @Test func theRingIsAroundTheFocusedWindow() {
    let (h, _, _, c) = makeHarness()
    expectRing(h, around: c)
    #expect(ring(h)?.outerFrame == h.frame(c)!.insetBy(dx: -3, dy: -3), "in the gap, outside the window")
    #expect(ring(h)?.width == 3)
    #expect(ring(h)?.colour == .accent)
  }

  @Test func theRingFollowsClicks() {
    let (h, a, b, _) = makeHarness()
    h.system.userFocus(a)
    expectRing(h, around: a)
    h.system.userFocus(b)
    expectRing(h, around: b)
  }

  @Test func followingFocusMovesNoWindow() {
    let (h, a, b, _) = makeHarness()
    h.system.clearFrameLog()
    h.system.userFocus(a)
    h.system.userFocus(b)
    h.system.userFocusesNothing()
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func theRingFollowsSwitchingApps() {
    // No app's own focused window changes, so macOS sends no `windowFocused`.
    let (h, a, _, _) = makeHarness()
    h.system.userSwitchesApp(to: a)
    expectRing(h, around: a)
  }

  @Test func theRingFollowsTheFocusCommandsAskFor() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) right")
    expectRing(h, around: a)
    h.run("zoom \(b.rawValue)")
    expectRing(h, around: b)
  }

  @Test func aBackgroundAppsFocusChangeDoesNotTakeTheRing() {
    // An app that is not in front opens or switches a window: it reports a focus change, but the keyboard stays.
    let (h, a, _, c) = makeHarness()
    h.controller.windowFocused(a)
    expectRing(h, around: c)
  }

  @Test func aWindowThatHadTheKeyboardBeforeArborHeardOfItGetsTheRing() {
    // Some apps give a new window its role a moment after focusing it, and only then does Arbor take it on.
    let (h, _, _, _) = makeHarness()
    h.system.focused = WindowID(104)
    h.controller.keyboardFocusMoved()
    expectNoRing(h)
    let new = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    #expect(new == WindowID(104))
    expectRing(h, around: new)
  }

  @Test func theRingLooksAgainAMomentAfterTheKeyboardMoved() {
    // macOS does not change everything at once: the event can come before the answer has changed.
    let (h, a, _, c) = makeHarness()
    h.controller.keyboardFocusMoved()
    expectRing(h, around: c)
    h.system.focused = a
    h.scheduler.advance(by: 0.25)
    expectRing(h, around: a)
  }

  @Test func theRingIsThereFromTheStart() {
    let earlier = Harness()
    earlier.system.open(app: "Safari")
    earlier.start()
    earlier.run("dock 101 left")
    earlier.controller.saveNow()

    let h = Harness(saved: earlier.store.saved)
    let a = h.system.open(app: "Safari")
    h.system.focus(a)
    h.start()
    #expect(h.workspace.isDocked(a))
    expectRing(h, around: a)
    #expect(ring(h)?.pulse == 0)
  }

  // MARK: Not before Arbor is asked for anything

  @Test func thereIsNoRingUntilSomethingIsDocked() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.system.focus(a)
    h.start()
    expectNoRing(h)
    h.system.userFocus(b)
    expectNoRing(h)
    h.run("dock \(a.rawValue) left")
    expectRing(h, around: a)
    h.system.userFocus(b)
    expectRing(h, around: b)
  }

  @Test func floatAllTakesTheRingAwayWithTheArrangement() {
    let (h, _, _, c) = makeHarness()
    expectRing(h, around: c)
    h.run("float-all")
    expectNoRing(h)
    h.system.userFocus(c)
    expectNoRing(h)
  }

  @Test func floatingTheLastDockedWindowTakesTheRingAway() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    expectRing(h, around: a)
    h.run("float \(a.rawValue)")
    expectNoRing(h)
  }

  @Test func somethingDockedOnOneDisplayIsEnoughForTheOther() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.userFocus(b)
    expectNoRing(h)
    dockSomething(h)
    h.system.userFocus(b)
    expectRing(h, around: b)
  }

  // MARK: Windows that get no ring

  @Test func nothingFocusedMeansNoRing() {
    let (h, _, _, _) = makeHarness()
    h.system.userFocusesNothing()
    expectNoRing(h)
  }

  @Test func windowsArborDoesNotArrangeGetNoRing() {
    let (h, a, _, _) = makeHarness()
    h.run("exclude com.example.safari")
    h.system.userFocus(a)
    expectNoRing(h)
    h.run("include com.example.safari")
    expectRing(h, around: a)
  }

  @Test func aMinimizedWindowLosesTheRing() {
    let (h, _, _, c) = makeHarness()
    // As for the last window of its app: macOS hands the keyboard to no other window.
    h.system.echoes.keyboard = false
    h.system.setMinimized(c, true)
    expectNoRing(h)
    h.system.setMinimized(c, false)
    expectRing(h, around: c)
  }

  @Test func aMinimizedFloatingWindowLosesTheRing() {
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    // As for the last window of its app: macOS hands the keyboard to no other window.
    h.system.echoes.keyboard = false
    h.system.setMinimized(f, true)
    expectNoRing(h)
  }

  @Test func aHiddenAppLosesTheRing() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 2000)
    h.start()
    h.run("dock \(a.rawValue) left")
    expectRing(h, around: a)
    h.system.setHidden(pid: 2000, true)
    expectNoRing(h)
  }

  @Test func aWindowOnAnotherSpaceLosesTheRing() {
    let (h, _, _, c) = makeHarness()
    h.system.setOnActiveSpace(c, false)
    h.scheduler.runPending()
    expectNoRing(h)
  }

  @Test func aClosedWindowLosesTheRing() {
    let (h, _, b, c) = makeHarness()
    // As for the last window of its app: macOS hands the keyboard to no other window.
    h.system.echoes.keyboard = false
    h.system.close(c)
    expectNoRing(h)
    h.system.userFocus(b)
    expectRing(h, around: b)
  }

  @Test func aParkedWindowHasNoRing() {
    // The fake keeps the keyboard where it is told to, so this is the moment before macOS reports the new focus.
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.focused = c
    h.run("relayout")
    #expect(h.controller.parked.contains(c))
    expectNoRing(h)
  }

  @Test func aParkedFloatingWindowHasNoRing() {
    let (h, a, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    expectRing(h, around: f)
    h.run("zoom \(a.rawValue)")
    h.system.focused = f
    h.run("relayout")
    #expect(h.controller.parked.contains(f))
    expectNoRing(h)
  }

  @Test func aWindowInsideATileHasNoRing() {
    let (h, _, _, _) = makeHarness()
    let big = h.system.open(app: "Settings", minimumSize: CGSize(width: 1300, height: 300))
    // It has the keyboard already: docking does not focus a window that ends up as a tile.
    h.system.userFocus(big)
    h.run("dock \(big.rawValue) right")
    #expect(h.layout!.tiles.contains { $0.windows.contains(big) })
    #expect(h.system.focused == big)
    expectNoRing(h)
  }

  @Test func aTabBehindAnotherHasNoRing() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b, _) = makeHarness(settings: settings)
    let centre = CGPoint(x: h.frame(a)!.midX, y: h.frame(a)!.midY)
    h.system.drag(b, through: [CGPoint(x: h.frame(b)!.midX, y: h.frame(b)!.minY + 10), centre])
    #expect(h.workspace.tree.leaf(containing: a) == h.workspace.tree.leaf(containing: b))
    h.system.focused = a
    h.run("relayout")
    #expect(h.layout!.windowFrames[a] == nil, "b is the tab in front")
    expectNoRing(h)
  }

  // MARK: Floating windows

  @Test func floatingWindowsHaveARingToo() {
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    expectRing(h, around: f)
    #expect(ring(h)?.outerFrame == h.frame(f)!.insetBy(dx: -3, dy: -3))
  }

  @Test func theRingFollowsAFloatingWindowMovedWithoutTheMouse() {
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    h.system.userMove(f, to: CGRect(x: 780, y: 340, width: 220, height: 240))
    expectRing(h, around: f)
  }

  @Test func aFloatingWindowThatFillsTheScreenHasItsRingInside() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let f = h.system.open(app: "Music", frame: side.visibleFrame)
    h.start()
    dockSomething(h)
    h.system.userFocus(f)
    #expect(h.overlays.scenes[side.id]?.focusRing?.outerFrame == side.visibleFrame)
  }

  // MARK: Moving with the layout

  @Test func theRingMovesWithRelayouts() {
    let (h, a, _, c) = makeHarness()
    let start = h.frame(c)!
    h.system.close(a)
    #expect(h.frame(c) != start)
    expectRing(h, around: c)
    let before = h.frame(c)!
    h.run("resize \(c.rawValue) left 100")
    #expect(h.frame(c)!.width == before.width + 100)
    expectRing(h, around: c)
    h.run("zoom \(c.rawValue)")
    #expect(h.frame(c) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    expectRing(h, around: c)
    h.run("float \(c.rawValue)")
    expectRing(h, around: c)
  }

  @Test func theRingIsAroundTheFrameTheAppTookNotTheSlot() {
    // A terminal snaps to whole character cells and ends up a little smaller than its slot.
    let (h, _, _, c) = makeHarness()
    let slot = h.layout!.windowFrames[c]!
    h.system.setMaximumSize(c, CGSize(width: slot.width - 3, height: slot.height - 2))
    h.run("show-all")
    h.system.userMove(c, to: CGRect(x: 0, y: 0, width: 100, height: 100))
    h.scheduler.runPending()
    #expect(h.frame(c)!.size == CGSize(width: slot.width - 3, height: slot.height - 2))
    expectRing(h, around: c)
  }

  @Test func theRingFollowsADockedWindowThatAnswersLate() {
    // The app settles on its frame after the call that set it returned; Arbor sees it as its own move echoing.
    let (h, _, _, c) = makeHarness()
    var late = h.controller.windows[c]!
    late.frame.size.height -= 2
    h.controller.windowChanged(late, userInitiated: false)
    #expect(ring(h)?.frame == late.frame)
  }

  // MARK: The mouse

  @Test func theRingHidesWhileItsWindowIsDragged() {
    let (h, _, _, c) = makeHarness()
    let start = h.frame(c)!
    h.system.mouseDown = true
    h.controller.dragBegan(c, at: CGPoint(x: start.midX, y: start.minY + 10))
    h.system.userMove(c, to: start.offsetBy(dx: -40, dy: 30))
    expectNoRing(h)
    h.scheduler.advance(by: 1)
    expectNoRing(h)
    h.system.mouseDown = false
    h.controller.dragEnded(c, at: CGPoint(x: start.midX - 40, y: start.minY + 40))
    expectRing(h, around: c)
  }

  @Test func theRingReturnsAfterAFloatingWindowIsDropped() {
    // Dropping a floating window on the Desktop lays nothing out again.
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    h.system.drag(f, through: [CGPoint(x: 860, y: 310), CGPoint(x: 870, y: 350), CGPoint(x: 880, y: 400)])
    h.scheduler.advance(by: 0.1)
    expectRing(h, around: f)
  }

  @Test func theRingHidesWhileAnEdgeIsDragged() {
    let (h, _, _, c) = makeHarness()
    var frame = h.frame(c)!
    frame.origin.x -= 60
    frame.size.width += 60
    h.system.userResize(c, to: frame, release: false)
    expectNoRing(h)
    h.scheduler.advance(by: 0.5)
    expectNoRing(h)
    h.system.releaseMouse()
    expectRing(h, around: c)
    #expect(h.frame(c) == frame)
  }

  @Test func theRingHidesWhileAFloatingWindowIsResized() {
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Music", frame: CGRect(x: 760, y: 300, width: 200, height: 200))
    h.system.userFocus(f)
    h.system.userResize(f, to: CGRect(x: 760, y: 300, width: 240, height: 260), release: false)
    expectNoRing(h)
    h.system.releaseMouse()
    h.scheduler.advance(by: 0.1)
    expectRing(h, around: f)
  }

  @Test func theRingHidesWhileASeamIsDragged() {
    // Nothing tells the controller that a seam drag is over.
    let (h, _, _, c) = makeHarness()
    let seam = h.overlays.seams[h.display]!.last!
    h.system.mouseDown = true
    h.overlays.dragSeam(seam, by: -30)
    expectNoRing(h)
    h.scheduler.advance(by: 0.3)
    expectNoRing(h)
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.1)
    expectRing(h, around: c)
  }

  @Test func aClickMovesTheRingBeforeTheButtonIsUp() {
    let (h, a, _, _) = makeHarness()
    h.system.mouseDown = true
    h.system.userFocus(a)
    expectRing(h, around: a)
  }

  @Test func aLostMouseUpDoesNotLoseTheRing() {
    // The button is up but the event that ends the drag never comes.
    let (h, _, _, c) = makeHarness()
    let start = h.frame(c)!
    h.system.mouseDown = true
    h.controller.dragBegan(c, at: CGPoint(x: start.midX, y: start.minY + 10))
    h.system.userMove(c, to: start.offsetBy(dx: -40, dy: 30))
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.3)
    expectNoRing(h)
    h.scheduler.advance(by: 0.7)
    expectRing(h, around: c)
  }

  @Test func theDraggedWindowClosingDoesNotLeaveARing() {
    let (h, _, _, c) = makeHarness()
    let start = h.frame(c)!
    h.system.mouseDown = true
    h.controller.dragBegan(c, at: CGPoint(x: start.midX, y: start.minY + 10))
    h.system.userMove(c, to: start.offsetBy(dx: -40, dy: 30))
    // As for the last window of its app: macOS hands the keyboard to no other window.
    h.system.echoes.keyboard = false
    h.system.close(c)
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.2)
    expectNoRing(h)
    // With nothing focused Arbor focuses a window in view, and the ring goes there.
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow() != nil)
    if let focused = h.system.focusedWindow() { expectRing(h, around: focused) }
  }

  // MARK: The flash

  @Test func theRingFlashesWhenACommandMovesTheKeyboard() {
    let (h, a, b, _) = makeHarness()
    let before = ring(h)!.pulse
    h.run("zoom \(a.rawValue)")
    let afterZoom = ring(h)!.pulse
    #expect(afterZoom != before)
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(ring(h)!.pulse == afterZoom, "the keyboard stayed on the same window")
    h.run("dock \(b.rawValue) left")
    #expect(ring(h)!.pulse != afterZoom)
  }

  @Test func theRingFlashesWhenMacOSReportsTheNewFocusAfterTheCommand() {
    let (h, a, _, _) = makeHarness()
    let before = ring(h)!.pulse
    h.run("show-all")
    h.scheduler.advance(by: 0.1)
    h.system.userFocus(a)
    #expect(ring(h)!.pulse != before)
  }

  @Test func theRingFlashesWhenACommandBringsItBackToTheSameWindow() {
    let (h, _, _, c) = makeHarness()
    let before = ring(h)!.pulse
    h.system.userFocusesNothing()
    h.scheduler.advance(by: 2)
    h.run("zoom \(c.rawValue)")
    expectRing(h, around: c)
    #expect(ring(h)!.pulse != before)
  }

  @Test func clicksDoNotFlash() {
    let (h, a, b, _) = makeHarness()
    let before = ring(h)!.pulse
    h.system.userFocus(a)
    h.system.userFocus(b)
    h.system.userSwitchesApp(to: a)
    #expect(ring(h)!.pulse == before)
  }

  @Test func theRingFlashesWhenTheCameraMovesToShowTheFocusedWindow() {
    // ⌘Tab to a window that is out of view.
    let (h, a, _, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2)
    let before = ring(h)!.pulse
    h.system.userFocus(c)
    expectRing(h, around: c)
    #expect(ring(h)!.pulse != before)
  }

  @Test func theRingFlashesOnTheWindowOfAClickedTile() {
    let (h, _, _, c) = makeHarness()
    let big = h.system.open(app: "Settings", minimumSize: CGSize(width: 1300, height: 300))
    h.run("dock \(big.rawValue) right")
    h.system.userFocus(c)
    h.scheduler.advance(by: 2)
    let before = ring(h)!.pulse
    h.overlays.clickTile(h.layout!.tiles.first { $0.windows.contains(big) }!.node)
    // The ring goes by what macOS reports, which comes a moment after Arbor's own call.
    h.system.deliverEchoes()
    expectRing(h, around: big)
    #expect(ring(h)!.pulse != before)
  }

  @Test func aRingThatReturnsAfterADragDoesNotFlash() {
    let (h, _, _, c) = makeHarness()
    let before = ring(h)!.pulse
    let start = h.frame(c)!
    let grab = CGPoint(x: start.midX, y: start.minY + 10)
    h.system.drag(c, through: [grab, CGPoint(x: grab.x - 5, y: grab.y + 5), grab])
    h.scheduler.advance(by: 1)
    expectRing(h, around: c)
    #expect(ring(h)!.pulse == before)
  }

  // MARK: Displays

  @Test func onlyOneDisplayHasTheRing() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    dockSomething(h)
    h.system.userFocus(a)
    expectRing(h, around: a)
    #expect(h.overlays.scenes[h.display]?.focusRing != nil)
    h.system.userFocus(b)
    expectRing(h, around: b)
    #expect(h.overlays.scenes[side.id]?.focusRing != nil)
    h.system.userFocus(a)
    expectRing(h, around: a)
  }

  @Test func aRelayoutOfOneDisplayTakesTheRingOffTheOther() {
    // The keyboard moved to the other display and the first thing Arbor hears of it is a relayout there.
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.start()
    dockSomething(h)
    h.system.userFocus(a)
    h.system.focused = b
    h.system.close(c)
    expectRing(h, around: b)
  }

  @Test func theRingFollowsAWindowCarriedToAnotherDisplay() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    dockSomething(h)
    h.system.userFocus(a)
    h.system.userMove(a, to: CGRect(x: 1600, y: 100, width: 600, height: 400))
    expectRing(h, around: a)
    #expect(h.overlays.scenes[side.id]?.focusRing != nil)
  }

  @Test func aDisplayGoingAwayTakesItsRingAlong() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    dockSomething(h)
    h.system.userFocus(b)
    #expect(h.overlays.scenes[side.id]?.focusRing != nil)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    expectRing(h, around: b)
    #expect(h.overlays.scenes[h.display]?.focusRing != nil)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    expectRing(h, around: b)
  }

  // MARK: Settings

  @Test func theRingFollowsTheSettings() {
    var settings = Settings()
    settings.focusRingWidth = 6
    settings.focusRingColour = "#FF000080"
    settings.focusRingRadius = 10
    let (h, _, _, c) = makeHarness(settings: settings)
    #expect(ring(h)?.width == 6)
    #expect(ring(h)?.radius == 10)
    #expect(ring(h)?.colour == .rgba(red: 1, green: 0, blue: 0, alpha: 128.0 / 255))
    #expect(ring(h)?.outerFrame == h.frame(c)!.insetBy(dx: -6, dy: -6))
  }

  @Test func switchingTheRingOffAndOnAppliesAtOnce() {
    let (h, _, _, c) = makeHarness()
    var settings = h.controller.settings
    settings.focusRing = false
    h.controller.apply(settings: settings)
    expectNoRing(h)
    h.system.userFocus(c)
    h.run("zoom \(c.rawValue)")
    expectNoRing(h)
    settings.focusRing = true
    h.controller.apply(settings: settings)
    expectRing(h, around: c)
  }

  @Test func withoutAGapTheRingIsInsideTheWindow() {
    var settings = Settings()
    settings.gap = 0
    let (h, _, _, c) = makeHarness(settings: settings)
    #expect(ring(h)?.outerFrame == h.frame(c))
  }

  @Test func aLineThickerThanTheGapStaysOffTheNeighbours() {
    var settings = Settings()
    settings.gap = 4
    settings.focusRingWidth = 10
    let (h, a, b, _) = makeHarness(settings: settings)
    h.system.userFocus(a)
    #expect(ring(h)?.outerFrame == h.frame(a)!.insetBy(dx: -4, dy: -4))
    #expect(ring(h)!.outerFrame.maxX <= h.frame(b)!.minX)
  }

  @Test func windowsEndUpInTheSamePlacesWithAndWithoutTheRing() {
    var off = Settings()
    off.focusRing = false
    let (with, a, b, c) = makeHarness()
    let (without, _, _, _) = makeHarness(settings: off)
    for h in [with, without] {
      h.run("zoom \(b.rawValue)")
      h.run("back")
      h.system.userFocus(a)
      h.run("float \(c.rawValue)")
      h.scheduler.runPending()
    }
    for window in [a, b, c] { #expect(with.frame(window) == without.frame(window)) }
  }

  // MARK: Lifecycle

  @Test func quittingRemovesTheRing() {
    let (h, _, _, c) = makeHarness()
    h.controller.shutdown()
    expectNoRing(h)
    h.system.userFocus(c)
    h.scheduler.advance(by: 1)
    expectNoRing(h)
  }

  @Test func pausingRemovesTheRingAndResumingBringsItBack() {
    let (h, _, _, c) = makeHarness()
    h.run("pause")
    expectNoRing(h)
    h.system.userFocus(c)
    h.scheduler.advance(by: 1)
    expectNoRing(h)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("focus-ring") }, "nothing keeps ticking during a pause")
    h.run("resume")
    expectRing(h, around: c)
  }

  @Test func startingAgainStartsAfresh() {
    // The view forgets the last pulse it drew when the overlays are removed, so the count starts over with it.
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(ring(h)!.pulse != 0)
    h.controller.shutdown()
    h.controller.start()
    expectRing(h, around: a)
    #expect(ring(h)!.pulse == 0)
  }

  // MARK: Scenario scripts

  @Test func scenariosCanExpectTheRing() {
    let (h, a, _, c) = makeHarness()
    func expect(_ line: String) -> String? {
      ScenarioExpectation.check(line.split(separator: " ").map(String.init), harness: h, lastCommandOK: true)
    }
    #expect(expect("ring \(c.rawValue)") == nil)
    #expect(expect("ring \(a.rawValue)") == "the focus ring is around w\(c.rawValue), not w\(a.rawValue)")
    #expect(expect("ring none") == "the focus ring is around w\(c.rawValue)")
    #expect(expect("ring")?.hasPrefix("cannot read `ring`") == true)
    #expect(expect("ring round")?.hasPrefix("cannot read `ring round`") == true)
    h.system.userFocusesNothing()
    #expect(expect("ring none") == nil)
    #expect(expect("ring \(c.rawValue)") == "there is no focus ring")
  }

  // MARK: What the view paints

  func model(frame: CGRect, outset: CGFloat, width: CGFloat, radius: CGFloat = 0) -> FocusRingModel {
    FocusRingModel(
      window: WindowID(1), frame: frame, outerFrame: frame.insetBy(dx: -outset, dy: -outset), width: width,
      radius: radius, colour: .accent, pulse: 0)
  }

  @Test func anOutsideLinesInnerEdgeFollowsTheWindowsCorners() {
    let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let band = model(frame: frame, outset: 3, width: 3).band(automaticRadius: 16)
    #expect(band.thickness == 3)
    #expect(band.frame == frame.insetBy(dx: -3, dy: -3))
    #expect(band.cornerRadius == 19)
    #expect(band.innerRadius == 16, "the window's own")
  }

  @Test func anInsideLinesOuterEdgeFollowsTheWindowsCorners() {
    let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let band = model(frame: frame, outset: 0, width: 4).band(automaticRadius: 16)
    #expect(band.frame == frame)
    #expect(band.cornerRadius == 16)
  }

  @Test func theRadiusSettingWinsOverTheAutomaticOne() {
    let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
    #expect(model(frame: frame, outset: 2, width: 2, radius: 10).band(automaticRadius: 16).cornerRadius == 12)
  }

  @Test func theFlashGrowsOutwardsOnly() {
    let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let ring = model(frame: frame, outset: 3, width: 3)
    let flash = ring.band(reaching: ring.flashReach, automaticRadius: 16)
    #expect(flash.thickness == 9)
    #expect(flash.frame == frame.insetBy(dx: -9, dy: -9))
    #expect(flash.frame.insetBy(dx: flash.thickness, dy: flash.thickness) == frame, "the inner edge stays")
    #expect(flash.cornerRadius == 25)
  }

  @Test func theRadiusNeverExceedsHalfASide() {
    let frame = CGRect(x: 0, y: 0, width: 48, height: 48)
    for width in [1, 3, 12] as [CGFloat] {
      for outset in [0, width] {
        let ring = model(frame: frame, outset: outset, width: width, radius: 60)
        for reach in [0, ring.flashReach] {
          let band = ring.band(reaching: reach, automaticRadius: 16)
          #expect(band.cornerRadius >= 0)
          #expect(band.cornerRadius * 2 <= min(band.frame.width, band.frame.height))
          #expect(band.innerRadius >= 0)
        }
      }
    }
  }
}
