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
    let line = "macOS zoomed this window · ⌃⌥Space puts it back"
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

  @Test func itStaysWhenAWindowOpensAndWhenThatOneCloses() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let new = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    h.system.close(new)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { windows.contains($0.window) }.isEmpty, "none of the four was moved")
  }

  /// Whatever else happens to windows that have no part in the arrangement.
  @Test func aFloatingWindowThatIsMinimizedAndRestoredEndsNothing() {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.setMinimized(floating, true)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame, "minimized")
    h.system.setMinimized(floating, false)
    h.scheduler.advance(by: 1)
    #expect(h.frame(windows[0]) == h.visibleFrame, "restored")
    #expect(h.system.frameLog.filter { windows.contains($0.window) }.isEmpty, "none of the four was moved")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
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

  /// What happens to a neighbour says nothing about this window (Q22): the others share the room behind it.
  @Test(arguments: ["closes", "is minimized", "is hidden with its app", "goes with its app"])
  func whateverBecomesOfADockedNeighbourItStays(_ what: String) {
    let (h, windows) = arranged()
    let slot = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let pid = h.system.windows[windows[1]]!.snapshot.pid
    switch what {
    case "closes": h.system.close(windows[1])
    case "is minimized": h.system.setMinimized(windows[1], true)
    case "is hidden with its app": h.system.setHidden(pid: pid, true)
    default: h.system.quit(pid: pid)
    }
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor did not move it")
    #expect(h.workspace.isDocked(windows[0]))
    let fresh = h.controller.freshLayout(of: h.display)!
    #expect(fresh.windowFrames[windows[0]] != slot, "the test's own premise: its slot is another now")
    for other in windows[2...] { #expect(h.frame(other) == fresh.windowFrames[other], "\(other) is in its slot") }
  }

  /// macOS returns it to the frame it had, which was its slot. From that double-click on it is a docked window like any
  /// other, so Arbor moves it once more, into the slot as it is now, and does not leave it lying across the others.
  @Test func afterThatTheSecondDoubleClickEndsInTheSlotAsItIsNow() {
    let (h, windows) = arranged()
    let old = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.close(windows[1])
    h.scheduler.advance(by: 3)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: windows[0])
    #expect(h.frame(windows[0]) == old, "macOS's way back")
    h.scheduler.advance(by: 0.3)
    #expect(h.frame(windows[0]) == h.controller.freshLayout(of: h.display)!.windowFrames[windows[0]])
    #expect(h.system.frameLog.map(\.window) == [windows[0]], "one move, of that window")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    h.scheduler.advance(by: 5)
    expectWindowsMatchLayout(h, on: h.display)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") }, "no timer is left behind")
  }

  /// Seen on a Mac: Terminal stands a few points out of its slot, on its grid of characters, and macOS returns it exactly there.
  @Test func backWhereTheZoomBeganItIsADockedWindowAgainThoughThatIsNotQuiteItsSlot() throws {
    let h = Harness()
    let windows = ["Terminal", "Mail", "Notes", "Safari"].enumerated().map { index, app in
      h.system.open(
        app: app, pid: 1000 + Int32(index),
        frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90 + 40 * CGFloat(index), width: 400, height: 300))
    }
    // What its app makes of a slot: less than it, and Arbor accepts that.
    h.system.setMaximumSize(windows[0], CGSize(width: 500, height: 380))
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    let stood = try #require(h.frame(windows[0]))
    let slot = try #require(h.layout?.windowFrames[windows[0]])
    #expect(!stood.approximatelyEquals(slot, tolerance: 4), "the test's own premise: \(stood) in \(slot)")
    h.system.setMaximumSize(windows[0], nil)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == stood, "macOS's way back")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "that is home")
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
  }

  /// Where macOS is set to fill, a second double-click does nothing (seen on a Mac). It stays, and stays let be.
  @Test func filledAndDoubleClickedAgainItStaysFilled() {
    let (h, windows) = arranged()
    h.system.doubleClick(at: CGPoint(x: h.frame(windows[0])!.midX, y: h.frame(windows[0])!.minY + 12))
    h.system.zoomAsMacOSDoes(windows[0], andBack: false)
    h.scheduler.advance(by: 3)
    h.system.doubleClick(at: CGPoint(x: h.visibleFrame.midX, y: h.visibleFrame.minY + 12))
    h.system.zoomAsMacOSDoes(windows[0], andBack: false)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
    #expect(h.system.frameLog.isEmpty, "Arbor moved nothing at all")
    // The note of the second double-click explains nothing that comes later.
    h.system.close(windows[1])
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
  }

  /// macOS animates the way back too: Arbor waits until it has stopped.
  @Test func itIsNotMetHalfWayBack() {
    let (h, windows) = arranged()
    let old = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.close(windows[1])
    h.scheduler.advance(by: 3)
    h.system.clearFrameLog()
    h.system.doubleClick(at: CGPoint(x: h.visibleFrame.midX, y: h.visibleFrame.minY + 12))
    let full = h.visibleFrame
    for share in [0.7, 0.4, 0.0] as [CGFloat] {
      h.system.userMove(
        windows[0],
        to: CGRect(
          x: old.minX + (full.minX - old.minX) * share, y: old.minY + (full.minY - old.minY) * share,
          width: old.width + (full.width - old.width) * share, height: old.height + (full.height - old.height) * share))
      h.scheduler.advance(by: 0.15)
      #expect(h.system.frameLog.isEmpty, "at \(share)")
    }
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.map(\.window) == [windows[0]])
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func andAKeyTakesItIntoTheSlotAsItIsNow() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.close(windows[1])
    h.scheduler.advance(by: 3)
    h.system.clearFrameLog()
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.map(\.window) == [windows[0]], "one move, of that window")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A hand on a gap lays out, and asked for it.
  @Test func aGapThatIsDraggedTakesItBack() throws {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let seam = try #require(h.layout?.seams.first)
    h.overlays.dragSeam(seam, by: 30)
    h.scheduler.advance(by: 1)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Found by walks: where it lies says nothing about who asked. Partly over the edge of its display, it is still its person's.
  @Test func partlyOverTheEdgeOfItsDisplayItIsStillLetBe() {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let over = CGRect(x: 663, y: 679, width: 513, height: 328)
    h.system.userMove(windows[0], to: over)
    h.scheduler.advance(by: 3)
    h.system.close(floating)
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == over)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor did not move it")
  }

  /// Found by walks too: an app that keeps its window larger than the display. Most of it never shows, and it is in reach all the same.
  @Test func largerThanItsDisplayItIsStillLetBe() {
    let h = Harness()
    let large = h.system.open(
      app: "Notes", pid: 1001, frame: CGRect(x: 40, y: 60, width: 2385, height: 2028), minimumSize: CGSize(width: 2385, height: 2028))
    let other = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 700, y: 200, width: 568, height: 607))
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.run("zoom \(large.rawValue)").ok)
    h.scheduler.advance(by: 5)
    h.system.doubleClickTitleBar(of: large)
    h.scheduler.advance(by: 3)
    guard h.controller.windowsLeftWhereADoubleClickPutThem == [large], let zoomed = h.frame(large) else {
      Issue.record("the test's own premise: macOS moved it, and it is let be")
      return
    }
    h.system.clearFrameLog()
    h.system.close(other)
    h.scheduler.advance(by: 3)
    #expect(h.frame(large) == zoomed)
    #expect(h.system.frameLog.filter { $0.window == large }.isEmpty, "Arbor did not move it")
  }

  /// But nothing is let be where nobody can reach it.
  @Test func mostlyOffEveryDisplayItIsFetchedByTheNextLayout() {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 1)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.userMove(windows[0], to: CGRect(x: 1300, y: 800, width: 600, height: 400))
    h.scheduler.advance(by: 3)
    h.system.close(floating)
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// No frame outlives the displays it was made for.
  @Test func aDisplayThatGetsSmallerTakesItBack() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true)
    ])
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// The same display with the Dock `points` higher than it comes.
  static func withTheDock(higherBy points: CGFloat) -> [DisplaySnapshot] {
    let display = FakeWindowSystem.standardDisplay
    var visible = display.visibleFrame
    visible.size.height -= points
    return [DisplaySnapshot(id: display.id, frame: display.frame, visibleFrame: visible, isMain: true)]
  }

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: FakeWindowSystem.standardDisplay.frame.maxX, y: 25, width: 1920, height: 1055), isMain: false)

  /// Seen on a Mac: a neighbour goes to the Dock, which gets another picture and changes its size by two points, and a third of a second later
  /// macOS reports a change of the displays. They are the displays they were. Nobody asked for anything, least of all about this window.
  @Test(arguments: [2, -2, 40] as [CGFloat]) func theDockThatChangesItsSizeIsNoChangeOfDisplays(_ points: CGFloat) {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let filled = h.frame(windows[0])!
    h.system.clearFrameLog()
    h.system.setMinimized(windows[1], true)
    h.scheduler.advance(by: 0.3)
    h.system.setDisplays(Self.withTheDock(higherBy: points))
    h.scheduler.advance(by: 10)
    #expect(h.frame(windows[0]) == filled, "where macOS put it")
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
    // And back.
    h.system.setMinimized(windows[1], false)
    h.scheduler.advance(by: 0.3)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 10)
    #expect(h.frame(windows[0]) == filled)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
    // One key from home, into the slot as it is now.
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A second display is plugged in beside it, and unplugged: that takes nothing from a window on a display that stands as it stood.
  @Test func aDisplayThatComesAndGoesBesideItTakesNothingFromIt() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let filled = h.frame(windows[0])!
    h.system.clearFrameLog()
    let main = FakeWindowSystem.standardDisplay
    for displays in [[main, Self.side], [main]] {
      h.system.setDisplays(displays)
      h.scheduler.advance(by: 10)
      #expect(h.frame(windows[0]) == filled, "with \(displays.count) display(s)")
      #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "with \(displays.count) display(s)")
    }
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
  }

  /// Its own display moves, because another one has become the main one: that ends it, as ever.
  @Test func itsOwnDisplayThatMovesEndsIt() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let main = FakeWindowSystem.standardDisplay
    h.system.setDisplays([
      DisplaySnapshot(
        id: DisplayID("desk"), frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true),
      DisplaySnapshot(
        id: main.id, frame: main.frame.offsetBy(dx: 1920, dy: 0), visibleFrame: main.visibleFrame.offsetBy(dx: 1920, dy: 0), isMain: false),
    ])
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "\(windows[0])")
    expectWindowsMatchLayout(h, on: main.id)
  }

  /// macOS takes windows along when displays change. Where it took this one is nobody's zoom.
  @Test func takenAlongByMacOSWithTheChangeItIsAnOrdinaryDockedWindow() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    // In silence, as macOS does it: the report of the displays is all Arbor hears.
    h.system.moveSilently(windows[0], to: CGRect(x: Self.side.frame.minX + 100, y: 100, width: 900, height: 700))
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.side])
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "\(windows[0])")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// The menu bar stops hiding: the display is what it was, and the window's title bar is under the menu bar now. Nothing is let be where
  /// nobody can get hold of it.
  @Test func withItsTitleBarUnderTheMenuBarItIsTakenBack() {
    let standard = FakeWindowSystem.standardDisplay
    let hidden = DisplaySnapshot(id: standard.id, frame: standard.frame, visibleFrame: standard.frame, isMain: true)
    let h = Harness(displays: [hidden])
    let windows = ["Safari", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 640, height: 420))
    }
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0])?.minY == 0 && h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    h.system.setDisplays([standard])
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// An app that stands some points short of its slot, like a terminal with its grid; the Dock changes its size meanwhile, and the slot by two
  /// points; and the window goes back to where it stood without a double-click that Arbor hears. It is home.
  @Test func backWhereItStoodAfterTheDockChangedItIsHome() {
    let h = Harness()
    let windows = ["Terminal", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90, width: 400, height: 420))
    }
    h.system.setMaximumSize(windows[0], CGSize(width: 2000, height: 845))
    h.start()
    #expect(h.run("layout Terminal | Mail").ok)
    h.scheduler.advance(by: 5)
    h.system.setMaximumSize(windows[0], nil)
    let stood = h.frame(windows[0])!
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    h.system.setDisplays(Self.withTheDock(higherBy: -2))
    h.scheduler.advance(by: 5)
    #expect(h.layout?.windowFrames[windows[0]]?.approximatelyEquals(stood, tolerance: 4) == false, "the test's own premise: \(stood)")
    h.system.userMove(windows[0], to: stood)
    h.scheduler.advance(by: 5)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "home")
  }

  /// What happens to the window itself, and is no word about its size: there and back it is as it was.
  @Test(arguments: ["another Space", "the Dock", "its app is hidden"]) func goneAndBackItIsStillWhereMacOSPutIt(_ whereTo: String) {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let pid = h.system.windows[windows[0]]!.snapshot.pid
    for away in [true, false] {
      switch whereTo {
      case "another Space": for window in windows { h.system.setOnActiveSpace(window, !away) }
      case "the Dock": h.system.setMinimized(windows[0], away)
      default: h.system.setHidden(pid: pid, away)
      }
      h.scheduler.advance(by: 5)
    }
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor did not move it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  /// A native tab is another window to macOS, and the same one to its person.
  @Test func anotherTabOfItIsLetBeInItsStead() throws {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let tab = try #require(h.system.openTab(in: windows[0]))
    h.scheduler.advance(by: 3)
    #expect(h.frame(tab) == h.visibleFrame)
    h.system.selectTab(windows[0], insteadOf: tab)
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] || $0.window == tab }.isEmpty, "Arbor moved neither")
  }

  @Test func aRuleThatDocksANewWindowLeavesItWhereItIs() {
    let (h, windows) = arranged()
    #expect(h.run("rule add com.example.finder dock right").ok)
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    let new = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    h.scheduler.advance(by: 3)
    #expect(h.workspace.isDocked(new), "the test's own premise")
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor did not move it")
  }

  /// Floated, it is nobody's docked window any more. Docked again, by whomever, it goes into its slot.
  @Test func floatedAndDockedAgainByARuleItIsADockedWindowLikeAnyOther() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.run("float \(windows[0].rawValue)").ok)
    h.scheduler.advance(by: 1)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
  }

  /// A third double-click right after the second, with the slot another by then: macOS zooms it again, and that stays too.
  @Test func zoomedAgainOnItsWayBackItStays() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.close(windows[1])
    h.scheduler.advance(by: 3)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 0.1)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
  }

  /// The ways in that a hand has and that are no commands. Each lays out, and was asked for.
  @Test(arguments: ["a key held to look", "a tile", "another window dragged in", "the settings file"])
  func whatAHandAsksForTakesItBack(_ what: String) throws {
    let (h, windows) = arranged()
    let floating = h.system.open(app: "Finder", pid: 2000, frame: CGRect(x: 1180, y: 300, width: 240, height: 300))
    h.scheduler.advance(by: 1)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    switch what {
    case "a key held to look":
      h.keyDown("ctrl+opt+space")
      h.scheduler.advance(by: 1)
      h.keyUp("ctrl+opt+space")
    case "a tile":
      h.overlays.clickTile(try #require(h.workspace.tree.leaf(containing: windows[2])))
    case "another window dragged in":
      let slot = try #require(h.layout?.windowFrames[windows[3]])
      h.system.userFocus(floating)
      h.system.drag(floating, through: [CGPoint(x: 1300, y: 312), CGPoint(x: slot.midX, y: slot.maxY - 60), CGPoint(x: slot.midX, y: slot.maxY - 8)])
      #expect(h.workspace.isDocked(floating), "the test's own premise")
    default:
      var settings = h.controller.settings
      settings.gap += 6
      h.controller.apply(settings: settings)
    }
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "\(what)")
    #expect(h.frame(windows[0]) != h.visibleFrame, "\(what)")
  }

  /// The view goes elsewhere because the keyboard did (rule 4), and the zoomed window is not part of it: it goes like the rest.
  @Test func outOfViewItIsPutAwayLikeAnyOther() {
    let (h, windows) = arranged()
    #expect(h.run("zoom \(windows[0].rawValue)").ok)
    h.scheduler.advance(by: 3)
    // Framed, with a gap round it: macOS's zoom is a little larger than its slot.
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    h.system.userFocus(windows[2])
    h.scheduler.advance(by: 3)
    #expect(h.layout?.windowFrames[windows[2]] != nil, "the window switched to is in view")
    if h.layout?.windowFrames[windows[0]] == nil {
      #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
      #expect(h.controller.parked.contains(windows[0]))
    }
  }

  /// Found by a walk: a press on its edge that pulls nothing is followed by no layout, so it must not end anything either.
  @Test func anEdgeThatIsPressedAndNotPulledLeavesItLetBe() {
    let (h, windows) = arranged()
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.userResize(windows[0], to: h.visibleFrame)
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
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

/// A pause and Quit give back what Arbor took (rule 5). Of a window that its person had macOS fill, Arbor took nothing: it is left where
/// it is (collab/QUESTIONS.md, Q22, third answer).
@Suite @MainActor struct AZoomThroughAPauseTests {
  func zoomed() -> (Harness, [WindowID]) {
    let h = Harness()
    let windows = ["Safari", "Mail", "Notes"].enumerated().map { index, app in
      h.system.open(
        app: app, pid: 1000 + Int32(index),
        frame: CGRect(x: 80 + 60 * CGFloat(index), y: 90 + 40 * CGFloat(index), width: 640, height: 420))
    }
    h.start()
    #expect(h.run("arrange").ok)
    h.scheduler.advance(by: 5)
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    h.system.clearFrameLog()
    return (h, windows)
  }

  @Test func aPauseThereAndBackIsNothing() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 3)
    #expect(h.system.windows[windows[0]]?.snapshot.frame == h.visibleFrame, "the pause left it where it was")
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.workspace.isDocked(windows[0]))
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "let be as before")
    // And from there everything is as it was before the pause.
    h.system.doubleClickTitleBar(of: windows[0])
    h.scheduler.advance(by: 3)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// The others get their own frames back, as ever.
  @Test func theOthersGetTheirOwnSizesBack() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    #expect(h.system.windows[windows[1]]?.snapshot.frame == CGRect(x: 140, y: 130, width: 640, height: 420))
    #expect(h.system.windows[windows[2]]?.snapshot.frame == CGRect(x: 200, y: 170, width: 640, height: 420))
  }

  @Test func movedDuringThePauseItIsAnOrdinaryDockedWindowAtTheResume() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    h.system.userMove(windows[0], to: CGRect(x: 300, y: 200, width: 700, height: 500))
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func quitLeavesItWhereItIs() {
    let (h, windows) = zoomed()
    h.controller.shutdown()
    #expect(h.system.windows[windows[0]]?.snapshot.frame == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.system.windows[windows[1]]?.snapshot.frame == CGRect(x: 140, y: 130, width: 640, height: 420))
  }

  /// Nothing is let be across a start: it docks what was docked (Q16), in one move.
  @Test func afterAQuitAStartDocksItLikeTheRest() {
    let (h, windows) = zoomed()
    h.controller.shutdown()
    h.system.clearFrameLog()
    h.start()
    h.scheduler.advance(by: 5)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.count <= 1, "one move at most")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A command about every window names this one too.
  @Test func floatAllGivesItItsOwnFrameLikeTheRest() {
    let (h, windows) = zoomed()
    #expect(h.run("float-all").ok)
    h.scheduler.advance(by: 3)
    #expect(h.frame(windows[0]) == CGRect(x: 80, y: 90, width: 640, height: 420))
  }

  /// macOS lists only what shows. On a Space that is not showing at the resume, its slot waits for it, and so does what is known of it.
  @Test func outOfSightAtTheResumeItIsLetBeWhenItsPersonComesBackToIt() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    h.system.setListed(windows[0], false)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    h.system.setListed(windows[0], true)
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isDocked(windows[0]), "the test's own premise: its slot waited")
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  @Test(arguments: ["in the Dock", "hidden with its app"]) func awayWhenThePauseBeginsItComesBackAsItWent(_ whereTo: String) {
    let (h, windows) = zoomed()
    let pid = h.system.windows[windows[0]]!.snapshot.pid
    func away(_ gone: Bool) { if whereTo == "in the Dock" { h.system.setMinimized(windows[0], gone) } else { h.system.setHidden(pid: pid, gone) } }
    away(true)
    h.scheduler.advance(by: 3)
    #expect(h.run("pause").ok)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 3)
    away(false)
    h.scheduler.advance(by: 5)
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
  }

  @Test func aPauseThatEndsByItselfIsNothingEither() {
    let (h, windows) = zoomed()
    #expect(h.run("pause 5").ok)
    h.scheduler.advance(by: 6 * 60)
    #expect(h.controller.isRunning, "the test's own premise")
    #expect(h.frame(windows[0]) == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  @Test func aSecondPauseSaysTheSameAndQuitDuringItMovesNothing() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    #expect(h.run("pause 10").message.contains("stays"))
    h.controller.shutdown()
    #expect(h.system.windows[windows[0]]?.snapshot.frame == h.visibleFrame)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
  }

  /// As while Arbor runs: no frame outlives the displays it was made for.
  @Test func displaysThatChangedDuringThePauseEndIt() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    h.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    ])
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 10)
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem.isEmpty, "\(windows[0])")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Nor is the Dock's size a change of the displays here: something was minimized during the pause.
  @Test func theDockThatChangedItsSizeDuringThePauseEndsNothing() {
    let (h, windows) = zoomed()
    #expect(h.run("pause").ok)
    h.system.setDisplays(AZoomAfterArrangeStaysTests.withTheDock(higherBy: 2))
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 10)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  /// A second display is plugged in during the pause, or three come back in another order: its own stands as it stood.
  @Test(arguments: ["one comes", "another order"]) func aDisplayBesideItThatChangedDuringThePauseEndsNothing(_ what: String) {
    let main = FakeWindowSystem.standardDisplay
    let side = AZoomAfterArrangeStaysTests.side
    let third = DisplaySnapshot(
      id: DisplayID("third"), frame: CGRect(x: -1280, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: -1280, y: 25, width: 1280, height: 775), isMain: false)
    let (h, windows) = zoomed()
    if what == "another order" {
      h.system.setDisplays([main, side, third])
      h.scheduler.advance(by: 10)
      h.system.clearFrameLog()
    }
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]], "the test's own premise")
    #expect(h.run("pause").ok)
    h.system.setDisplays(what == "another order" ? [main, third, side] : [main, side])
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 10)
    #expect(h.system.frameLog.filter { $0.window == windows[0] }.isEmpty, "Arbor never moved it")
    #expect(h.controller.windowsLeftWhereADoubleClickPutThem == [windows[0]])
  }

  /// `shutdown`'s last net goes by the measure the window is let be by.
  @Test func largerThanItsDisplayQuitLeavesItToo() {
    let h = Harness()
    let large = h.system.open(
      app: "Notes", pid: 1001, frame: CGRect(x: 40, y: 60, width: 2385, height: 2028), minimumSize: CGSize(width: 2385, height: 2028))
    h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 700, y: 200, width: 568, height: 607))
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.run("zoom \(large.rawValue)").ok)
    h.scheduler.advance(by: 5)
    h.system.doubleClickTitleBar(of: large)
    h.scheduler.advance(by: 3)
    guard h.controller.windowsLeftWhereADoubleClickPutThem == [large], let zoomed = h.frame(large) else {
      Issue.record("the test's own premise: macOS moved it, and it is let be")
      return
    }
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(h.system.windows[large]?.snapshot.frame == zoomed)
    #expect(h.system.frameLog.filter { $0.window == large }.isEmpty, "Arbor asked nothing of it")
  }

  /// Arbor says what it has looked at.
  @Test func thePauseDoesNotSayOfItWhatIsNotTrue() {
    let (h, _) = zoomed()
    let said = h.run("pause").message
    #expect(said.contains("in their own sizes"))
    #expect(said.contains("stays"), "\(said)")
    let plain = Harness()
    plain.system.open(app: "Safari")
    plain.start()
    plain.run("arrange")
    #expect(!plain.run("pause").message.contains("stays"))
  }
}

