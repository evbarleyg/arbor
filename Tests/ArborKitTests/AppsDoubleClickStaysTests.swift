import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// K193: macOS has an action of its own for a title bar's double-click (fill or zoom as it comes). What it makes of a
/// docked window stays: Arbor does not pull the window back a moment later.
@Suite @MainActor struct AppsDoubleClickStaysTests {
  /// root(h)[a, Desktop, b] showing everything.
  func makeHarness() -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, a, b)
  }

  func titleBar(_ h: Harness, _ window: WindowID) -> CGPoint {
    let frame = h.frame(window)!
    return CGPoint(x: frame.midX, y: frame.minY + 12)
  }

  @Test func macOSZoomsADockedWindowAndArborLeavesItThere() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    let neighbour = h.frame(b)!
    h.system.doubleClick(at: titleBar(h, a))
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == h.visibleFrame, "not pulled back")
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
    #expect(h.frame(b) == neighbour)
    #expect(h.workspace.isDocked(a), "it is docked as before")
    #expect(h.workspace.camera == h.workspace.tree.root)

    // macOS's second double-click gives the window the frame it had, which is its slot.
    h.system.doubleClick(at: titleBar(h, a))
    h.system.userMove(a, to: slot)
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// macOS animates, and the app reports frames on the way.
  @Test func everyStageOfTheZoomIsLeftAlone() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClick(at: titleBar(h, a))
    for share in [0.3, 0.6, 1.0] as [CGFloat] {
      let full = h.visibleFrame
      h.system.userMove(
        a,
        to: CGRect(
          x: slot.minX + (full.minX - slot.minX) * share, y: slot.minY + (full.minY - slot.minY) * share,
          width: slot.width + (full.width - slot.width) * share, height: slot.height + (full.height - slot.height) * share))
      h.scheduler.advance(by: 0.1)
    }
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == h.visibleFrame)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func theNextLayoutTakesTheWindowBackInOneMove() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClick(at: titleBar(h, a))
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 5)
    h.run("zoom \(b.rawValue)")
    h.run("back")
    #expect(h.frame(a) == slot)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// "A window is in the way: ⌃⌥0" holds here too, though the view is on everything already.
  @Test func showingEverythingTakesItBackThoughTheViewStays() {
    for command in ["show-all", "home", "relayout"] {
      let (h, a, _) = makeHarness()
      let slot = h.frame(a)!
      h.system.doubleClick(at: titleBar(h, a))
      h.system.userMove(a, to: h.visibleFrame)
      h.scheduler.advance(by: 5)
      #expect(h.run(command).ok, "\(command)")
      #expect(h.frame(a) == slot, "\(command)")
      #expect(h.system.frameLog.filter { $0.window == a }.count == 1, "\(command): one move")
    }
  }

  /// The control: without a double-click, a docked window that something moves is put back as ever.
  @Test func aDockedWindowThatMovesByItselfIsStillPutBack() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  @Test func aDoubleClickSomeTimeAgoExplainsNothing() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClick(at: titleBar(h, a))
    h.scheduler.advance(by: AppsDoubleClick.patience + 0.5)
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  @Test func itExplainsOnlyTheWindowThatGotIt() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(b)!
    h.system.doubleClick(at: titleBar(h, a))
    h.system.userMove(b, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(b) == slot)
  }

  /// With "Minimize" chosen in System Settings the window goes to the Dock like any that is minimized.
  @Test func minimizingIsWhatItAlwaysWas() {
    let (h, a, b) = makeHarness()
    h.system.doubleClick(at: titleBar(h, a))
    h.system.setMinimized(a, true)
    h.scheduler.advance(by: 1)
    #expect(h.layout?.windowFrames[a] == nil)
    #expect(h.layout?.windowFrames[b] != nil)
    expectWindowsMatchLayout(h, on: h.display)
    h.system.setMinimized(a, false)
    h.scheduler.advance(by: 1)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Click a title bar and at once drag it: the press counts as a second click, and the drop is Arbor's as ever.
  @Test func aSecondPressThatDragsIsADrag() {
    let (h, a, _) = makeHarness()
    let bar = titleBar(h, a)
    h.system.doubleClick(at: bar)
    h.system.drag(a, through: [bar, h.layout!.desktopFrame!.center])
    #expect(h.workspace.isFloating(a))
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot, "the note did not outlive the drag")
  }

  @Test func aSecondPressThatResizesIsAResize() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClick(at: titleBar(h, a))
    // The left edge has nothing beside it, so it goes back.
    h.system.userResize(a, to: CGRect(x: slot.minX - 8, y: slot.minY, width: slot.width + 8, height: slot.height))
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  @Test func onlyADockedWindowInViewGetsANote() {
    let (h, a, b) = makeHarness()
    let c = h.system.open(app: "Mail", frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    h.controller.doubleClickReached(a)
    #expect(h.controller.windowJustDoubleClicked == a, "the control")
    h.controller.doubleClickReached(c)
    #expect(h.controller.windowJustDoubleClicked == nil, "it floats, and the note before it is gone too")
    h.controller.doubleClickReached(WindowID(9999))
    #expect(h.controller.windowJustDoubleClicked == nil, "nobody's")
    h.run("zoom \(a.rawValue)")
    h.controller.doubleClickReached(b)
    #expect(h.controller.windowJustDoubleClicked == nil, "out of view")
    h.run("exclude com.example.safari")
    h.controller.doubleClickReached(a)
    #expect(h.controller.windowJustDoubleClicked == nil, "not Arbor's to arrange")
  }

  @Test func duringAPauseNothingIsNoted() {
    let (h, a, _) = makeHarness()
    h.controller.doubleClickReached(a)
    h.run("pause")
    #expect(h.controller.windowJustDoubleClicked == nil, "a pause forgets it")
    h.controller.doubleClickReached(a)
    #expect(h.controller.windowJustDoubleClicked == nil)
    h.run("resume")
    let slot = h.frame(a)!
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  /// Nothing waits to put it back either.
  @Test func noTimerIsLeftBehind() {
    let (h, a, _) = makeHarness()
    h.system.doubleClick(at: titleBar(h, a))
    h.system.userMove(a, to: h.visibleFrame)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") }, "\(h.scheduler.pendingKeys)")
  }

  /// The whole of it as macOS plays it: there, and back.
  @Test func thereAndBackWithoutAMoveOfArbors() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == h.visibleFrame)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [a])
    let letBe = h.controller.snapshot().windows.filter { $0.letBe }.map { $0.id }
    #expect(letBe == [a], "whoever compares Arbor's state with the screen can tell")
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == slot)
    #expect(h.system.frameLog.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.controller.windowsLeftToTheirApps.isEmpty, "back in its slot it is a docked window like any other")
    let still = h.controller.snapshot().windows.filter { $0.letBe }
    #expect(still.isEmpty)
    #expect(h.controller.windowJustDoubleClicked == nil, "and the second double-click is used up")
  }

  /// Back in its slot it is kept there, and its edges move the seams.
  @Test func afterTheWayBackItIsKeptInItsSlotAgain() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClickTitleBar(of: a)
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    h.system.userMove(a, to: slot.offsetBy(dx: 80, dy: 60))
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
    h.system.userResize(a, to: CGRect(x: slot.minX, y: slot.minY, width: slot.width + 50, height: slot.height))
    h.scheduler.advance(by: 1)
    #expect(h.frame(a)?.width == slot.width + 50)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A double-click that moved nothing (a word in the text, or macOS set to do nothing), then a command: what the window does
  /// after Arbor has given it a frame is its answer to that.
  @Test func aLayoutOfArborsUsesTheNoteUp() {
    let (h, a, b) = makeHarness()
    h.system.doubleClick(at: h.frame(a)!.center)
    #expect(h.controller.windowJustDoubleClicked == a)
    h.run("swap \(a.rawValue) \(b.rawValue)")
    #expect(h.controller.windowJustDoubleClicked == nil)
    let slot = h.frame(a)!
    h.system.userMove(a, to: slot.offsetBy(dx: -70, dy: 30))
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  /// An app may report a stage while the button is still down. The note waits for the button.
  @Test func aReportWithTheButtonStillDownDoesNotUseTheNoteUp() {
    let (h, a, _) = makeHarness()
    h.system.doubleClick(at: titleBar(h, a))
    h.system.mouseDown = true
    h.system.userMove(a, to: h.visibleFrame.insetBy(dx: 100, dy: 100))
    #expect(h.controller.windowJustDoubleClicked == a)
    h.system.mouseDown = false
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == h.visibleFrame)
    #expect(h.system.frameLog.isEmpty)
  }

  /// A neighbour that moves by itself meanwhile is put back, and that moves nothing else.
  @Test func itsNeighboursAreKeptInTheirSlotsMeanwhile() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(b)!
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    h.system.userMove(b, to: slot.offsetBy(dx: -60, dy: 40))
    h.scheduler.advance(by: 1)
    #expect(h.frame(b) == slot)
    #expect(h.frame(a) == h.visibleFrame)
    #expect(h.system.frameLog.map(\.window) == [b])
  }

  /// Float All gives every window the frame it had before it was docked, in one move, from wherever it is.
  @Test func floatAllGivesItsOwnFrameBack() {
    let (h, a, _) = makeHarness()
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    #expect(h.run("float-all").ok)
    #expect(h.frame(a)?.size == CGSize(width: 600, height: 400))
    #expect(h.system.frameLog.filter { $0.window == a }.count == 1)
    // Docked again, it is kept in its slot like any other.
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    h.system.userMove(a, to: h.visibleFrame)
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  @Test func aWindowClosedRightAfterwardsIsForgotten() {
    let (h, a, _) = makeHarness()
    h.system.doubleClick(at: titleBar(h, a))
    h.system.close(a)
    #expect(h.controller.invariantViolations().isEmpty)
    let (h2, a2, _) = makeHarness()
    h2.system.doubleClickTitleBar(of: a2)
    h2.system.close(a2)
    #expect(h2.controller.invariantViolations().isEmpty)
    #expect(h2.controller.windowsLeftToTheirApps.isEmpty)
  }

  /// Found by a random walk: framed without a gap, a window that did not fill its slot is zoomed by macOS into that very slot.
  @Test func aZoomThatEndsInTheSlotLeavesNothingToStandAsideFor() {
    var settings = Settings()
    settings.gap = 0
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Calculator", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.system.setMaximumSize(a, CGSize(width: 800, height: 600))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 5)
    let slot = h.layout!.windowFrames[a]!
    #expect(slot == h.visibleFrame)
    #expect(h.frame(a)?.size == CGSize(width: 800, height: 600), "in the middle of its slot")
    h.system.setMaximumSize(a, nil)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: a)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == slot)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.controller.windowsLeftToTheirApps.isEmpty, "it is where it belongs, and is kept there")
    h.system.userMove(a, to: slot.insetBy(dx: 90, dy: 70))
    h.scheduler.advance(by: 1)
    #expect(h.frame(a) == slot)
  }

  /// It covers its neighbours, and whoever did not mean that wants to know the way back. Said the first three times.
  @Test func theFirstThreeTimesALineSaysHowToGetBack() {
    let (h, a, _) = makeHarness()
    let line = "macOS zoomed this window · double-click again, or ⌃⌥Space, puts it back"
    for round in 1...4 {
      h.system.doubleClickTitleBar(of: a)
      #expect((h.overlays.headsUp[h.display]?.line == line) == (round <= 3), "round \(round)")
      h.system.doubleClickTitleBar(of: a)
      #expect(h.overlays.headsUp[h.display] == nil, "back in its slot, the line has nothing left to say (round \(round))")
      h.scheduler.advance(by: 10)
    }
  }

  @Test func whateverElseAnAppMakesOfADoubleClickGetsNoLine() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.doubleClick(at: slot.center)
    h.system.userMove(a, to: slot.insetBy(dx: 40, dy: 60))
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [a])
    #expect(h.overlays.headsUp[h.display] == nil)
  }

  /// The random walks double-click too, and their rules know a window that is let be from one Arbor gave up on.
  @Test func theWalksKnowAWindowThatIsLetBe() {
    let script = """
      open 101 Safari pid 1000 at 100 100 600 400
      open 102 Notes pid 1001 at 300 200 600 400
      launch
      dock 101 left
      dock 102 right
      settle
      double-click 101
      settle
      advance 5
      double-click 101
      settle
      double-click 102
      show-all
      settle
      """
    #expect(ChaosAction.script(script).map(\.text).contains("double-click 101"))
    let failure = ChaosRunner.replay(ChaosAction.script(script), excusing: ChaosRunner.knownRules)
    #expect(failure == nil, "\(String(describing: failure))")
  }
}

/// The same as a person met it (collab/IDEAS.md, I19): several windows, `arrange`, and then macOS's own double-click on a
/// title bar "works for a moment, then Arbor puts it back where the arrangement had it".
@Suite @MainActor struct AZoomAfterArrangeStaysTests {
  /// Four windows, arranged, everything in view.
  func arranged() -> (Harness, [WindowID]) {
    let h = Harness()
    let windows = ["Safari", "Mail", "Notes", "Terminal"].enumerated().map { index, app in
      h.system.open(app: app, frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90 + 40 * CGFloat(index), width: 640, height: 420))
    }
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    h.system.clearFrameLog()
    return (h, windows)
  }

  func frames(_ h: Harness, _ windows: [WindowID]) -> [CGRect?] { windows.map { h.frame($0) } }

  @Test(arguments: 0..<4) func whicheverOfThemItIsItStays(_ index: Int) {
    let (h, windows) = arranged()
    let zoomed = windows[index]
    let others = windows.filter { $0 != zoomed }
    let before = frames(h, others)
    h.system.doubleClickTitleBar(of: zoomed)
    #expect(h.frame(zoomed) == h.visibleFrame, "macOS filled the display with it")
    // The moment after which it used to be put back, and a good while.
    for seconds in [0.3, 5, 60] {
      h.scheduler.advance(by: seconds)
      #expect(h.frame(zoomed) == h.visibleFrame, "after another \(seconds) s")
    }
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
    #expect(frames(h, others) == before)
    #expect(h.workspace.isDocked(zoomed), "its place is kept")
  }

  /// The control: what Arbor is told of the zoom without the double-click, which is all it went by before.
  @Test func withoutTheDoubleClickTheSameMoveIsUndone() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.userMove(windows[0], to: h.visibleFrame)
    h.scheduler.advance(by: 0.3)
    #expect(h.frame(windows[0]) == slot)
  }

  /// ⌘Tab, a click, Arbor's own `focus`: the window that is switched to comes to the front, and nothing is laid out.
  @Test func itStaysWhileOtherWindowsAreSwitchedTo() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.userFocus(windows[2])
    h.scheduler.advance(by: 1)
    #expect(h.run("focus \(windows[3].rawValue)").ok)
    h.scheduler.advance(by: 1)
    h.system.userFocus(windows[0])
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
  }

  @Test func itStaysWhenAWindowOpens() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.open(app: "Finder", frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { windows.contains($0.window) }.isEmpty, "none of the four was moved")
  }

  /// Q22: "or at the next command that lays out", though the command leaves its slot as it was.
  @Test func aCommandAboutOtherWindowsTakesItBack() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.run("swap \(windows[2].rawValue) \(windows[3].rawValue)").ok)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.count == 1, "one move")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A hand that takes the zoomed window by its title bar has the last word, as with any docked window.
  @Test func draggedItIsADockedWindowInTheHand() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let grab = CGPoint(x: h.visibleFrame.midX, y: h.visibleFrame.minY + 12)
    h.system.drag(windows[0], through: [grab, CGPoint(x: grab.x + 40, y: grab.y + 200), CGPoint(x: grab.x + 60, y: grab.y + 300)])
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// What the line on screen promises. And the way back in the history is a view, not a size: nothing is zoomed again.
  @Test func everythingTakesItBackInOneMoveAndBackLeavesItThere() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.run("home").ok)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot)
    #expect(h.system.frameLog.count == 1, "one move, of that window: \(h.system.frameLog)")
    h.run("back")
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theSecondDoubleClickBringsItBackAndFromThenOnItIsKeptThere() {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == slot, "macOS's own way back")
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
    h.system.userMove(windows[0], to: slot.offsetBy(dx: 90, dy: 60))
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == slot, "docked like any other again")
    expectWindowsMatchLayout(h, on: h.display)
  }
}
