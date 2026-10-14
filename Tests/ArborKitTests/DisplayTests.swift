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
@MainActor private let main = FakeWindowSystem.standardDisplay
private let day: TimeInterval = 24 * 60 * 60

/// Opens the windows of `old` in `new` with the same numbers, apps, titles
/// and frames: the same windows seen by a new Arbor process.
@MainActor
private func reopen(_ old: Harness, in new: Harness) {
  for window in old.system.allWindows() {
    new.system.open(
      app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
  }
}

/// Displays going away and coming back (docs/features/F08-displays-and-spaces.md).
@Suite @MainActor struct DisplayTests {
  /// The main and side displays, three windows docked on the side display as
  /// [a | Desktop | b / c], and the pointer on the side display.
  func makeHarness() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1700, y: 150, width: 500, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1900, y: 200, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    return (h, a, b, c)
  }

  func sideWorkspace(_ h: Harness) -> Workspace? { h.controller.workspaces[side.id] }

  /// The split holding b and c.
  func column(_ h: Harness, _ b: WindowID) -> NodeID {
    let tree = sideWorkspace(h)!.tree
    return tree.parent(of: tree.leaf(containing: b)!)!
  }

  @Test func aReconnectedDisplayGetsItsArrangementBack() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom-node \(column(h, b).rawValue)")
    #expect(h.run("save-view 2").ok)
    h.run("show-all")
    h.run("zoom-node \(column(h, b).rawValue)")
    let before = sideWorkspace(h)!
    let slots = h.controller.layouts[side.id]!.windowFrames
    #expect(slots.keys.sorted() == [b, c])

    h.system.setDisplays([main])
    #expect(sideWorkspace(h) == nil)
    #expect(h.controller.dormant[side.id]?.workspace == before)
    for window in [a, b, c] {
      #expect(h.workspace.isFloating(window))
      #expect(h.system.isVisible(window), "\(window) floats on the main display meanwhile")
    }

    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h) == before, "tree, camera, history and saved views come back")
    #expect(h.controller.dormant.isEmpty)
    #expect(h.workspace.floating.isEmpty)
    for (window, frame) in slots {
      #expect(h.frame(window) == frame, "\(window) is back in its slot")
    }
    #expect(!h.system.isVisible(a), "a is outside the camera, as before")
    expectWindowsMatchLayout(h, on: side.id)
    #expect(h.run("view 2").ok)
    #expect(sideWorkspace(h)!.camera == column(h, b))
  }

  @Test func aWindowDockedElsewhereMeanwhileStaysThere() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom-node \(column(h, b).rawValue)")
    h.run("save-view 1")
    h.system.setDisplays([main])
    h.system.cursor = CGPoint(x: 700, y: 450)
    #expect(h.run("dock \(c.rawValue) left").ok)
    let mainSlot = h.frame(c)!

    h.system.setDisplays([main, side])
    let restored = sideWorkspace(h)!
    #expect(h.workspace.isDocked(c))
    #expect(h.frame(c) == mainSlot)
    #expect(!restored.contains(c))
    #expect(restored.tree.allWindows == [a, b])
    #expect(restored.tree.invariantViolations().isEmpty)
    // The column [b / c] collapsed into b; the camera and the saved view follow.
    #expect(restored.camera == restored.tree.leaf(containing: b))
    #expect(restored.savedView(slot: 1) == restored.tree.leaf(containing: b))
    expectWindowsMatchLayout(h, on: side.id)
    expectWindowsMatchLayout(h, on: main.id)
  }

  @Test func floatingWindowsGoBackToWhereTheyFloated() {
    let (h, _, _, _) = makeHarness()
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    #expect(sideWorkspace(h)!.isFloating(d))

    h.system.setDisplays([main])
    #expect(h.workspace.isFloating(d))
    #expect(main.visibleFrame.contains(h.frame(d)!))

    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h)!.floating[d] == spot)
    #expect(h.workspace.floating[d] == nil)
    #expect(h.frame(d) == spot)
  }

  // MARK: The window being typed in stays in view

  /// FRESH EYES 2, 2026-10-14: in a call (so the view is held), typing on the big display, somebody pulls the cable. The window
  /// arrived on the laptop in full view, and the next words landed in Calendar: until the layout had placed it, it counted
  /// as out of view, and a hold gives the keyboard back from a window out of view that took it unasked.
  @Test(arguments: ["hold still", "hold", nil], [true, false])
  func unpluggingDuringAHoldLeavesTheKeyboardInTheWindowThatArrivesInView(hold: String?, docked: Bool) {
    let h = Harness(displays: [main, side])
    let calendar = h.system.open(app: "Calendar", pid: 1006, frame: CGRect(x: 200, y: 100, width: 700, height: 500))
    let xcode = h.system.open(app: "Xcode", pid: 1003, frame: CGRect(x: 1600, y: 50, width: 900, height: 600))
    h.start()
    h.system.userFocus(xcode)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    if docked { h.run("dock \(xcode.rawValue) left") }
    if let hold { #expect(h.run(hold).ok) }

    h.system.setDisplays([main])
    h.scheduler.advance(by: 3)
    #expect(h.system.focusedWindow() == xcode, "not \(calendar)")
    #expect(h.system.isVisible(xcode))
    #expect(!h.controller.parked.contains(xcode))
  }

  /// Code framed on the main display beside Safari, which is out of view. The side display as in `makeHarness`.
  func makeFramedHarness() -> (Harness, code: WindowID, a: WindowID, b: WindowID, c: WindowID) {
    let (h, a, b, c) = makeHarness()
    let code = h.system.open(app: "Code", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 200, y: 100, width: 500, height: 400))
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("dock \(code.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(code.rawValue)")
    return (h, code, a, b, c)
  }

  @Test func afterAnUnplugTheFloatingWindowBeingTypedInIsInView() {
    let (h, _, _, _, _) = makeFramedHarness()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 1900, y: 100, width: 300, height: 200))
    h.system.userFocus(terminal)
    h.system.setDisplays([main])
    #expect(h.system.focused == terminal, "the keyboard stays where it was")
    #expect(h.system.isVisible(terminal))
    #expect(!h.controller.parked.contains(terminal))
  }

  /// Not out of view first and into view afterwards, which is a flicker, of the window being typed in among others.
  @Test func whenTheViewFollowsTheKeyboardEveryWindowStillMovesOnce() {
    let (h, _, _, _, _) = makeFramedHarness()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 1900, y: 100, width: 300, height: 200))
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 2000, y: 300, width: 300, height: 200))
    h.system.userFocus(terminal)
    for displays in [[main], [main, side]] {
      h.system.clearFrameLog()
      h.system.setDisplays(displays)
      h.scheduler.advance(by: 2)
      #expect(h.system.isVisible(terminal) && h.system.isVisible(notes))
      let moves = Dictionary(grouping: h.system.frameLog, by: \.window).mapValues(\.count)
      #expect(moves.values.allSatisfy { $0 == 1 }, "\(displays.count) display(s): \(moves)")
    }
  }

  @Test func afterAnUnplugTheDockedWindowBeingTypedInIsInView() {
    let (h, _, _, b, _) = makeFramedHarness()
    h.system.userFocus(b)
    h.system.setDisplays([main])
    #expect(h.system.focused == b)
    #expect(h.system.isVisible(b))
  }

  @Test func afterAReplugTheWindowBeingTypedInIsInView() {
    let (h, _, a, b, _) = makeFramedHarness()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("zoom \(a.rawValue)")
    h.system.setDisplays([main])
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))

    // It goes home, where the view was on another window.
    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h)!.isDocked(b))
    #expect(h.system.focused == b)
    #expect(h.system.isVisible(b))
  }

  /// The lid closes with a display attached: the main display is the one that goes.
  @Test func afterTheLidClosesTheWindowBeingTypedInIsInView() {
    let (h, code, a, _, _) = makeFramedHarness()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(code)
    var alone = side
    alone.isMain = true
    h.system.setDisplays([alone])
    #expect(h.system.focused == code)
    #expect(h.system.isVisible(code))
  }

  /// For a shared screen the view stays whatever happens (F58), and then the keyboard must not stay in a window nobody
  /// can see: it goes back to one in view, as it does when a window out of view takes it.
  @Test func underAHoldTheViewStaysAndTheKeyboardComesBackIntoIt() {
    let (h, code, _, b, _) = makeFramedHarness()
    h.system.userFocus(code)
    h.system.userFocus(b)
    #expect(h.run("hold").ok)
    let view = h.workspace.camera
    h.system.setDisplays([main])
    #expect(h.workspace.camera == view)
    #expect(!h.system.isVisible(b))
    #expect(h.system.focused == code)
  }

  @Test func aChangeOfDisplaysLeavesAViewThatShowsTheFocusedWindowAlone() {
    let (h, code, _, _, _) = makeFramedHarness()
    h.system.userFocus(code)
    let view = h.workspace.camera
    h.system.setDisplays([main])
    #expect(h.workspace.camera == view)
    #expect(h.system.focused == code)
    h.system.setDisplays([main, side])
    #expect(h.workspace.camera == view)
    #expect(h.system.focused == code)
  }

  /// Only a display that comes or goes sends windows elsewhere. The Dock grows at every minimize.
  @Test func aReportAboutTheSameDisplaysMovesNoView() {
    let (h, code, _, _, _) = makeFramedHarness()
    let safari = WindowID(code.rawValue + 1)
    // However it got there (a launch leaves it where it is): the keyboard is in a window that does not show.
    h.system.focused = safari
    #expect(h.controller.parked.contains(safari))
    let view = h.workspace.camera
    var smaller = main
    smaller.visibleFrame.size.height -= 70
    for displays in [[main, side], [smaller, side]] {
      h.system.setDisplays(displays)
      #expect(h.workspace.camera == view)
    }
  }

  // MARK: macOS moves the windows before Arbor hears of the displays

  /// What a Mac does when the side display is unplugged: it moves the display's windows onto the main one at
  /// once and their apps say so. Arbor hears of the displays only once they have settled (`DisplayChange`).
  func unplugSideWithoutAWord(_ h: Harness, moving windows: [WindowID]) {
    h.system.displayList = [main]
    for (index, window) in windows.enumerated() {
      let size = h.frame(window)!.size
      h.system.userMove(window, to: CGRect(x: 100 + 40 * CGFloat(index), y: 60, width: size.width, height: size.height))
    }
  }

  @Test func aFloatingWindowThatMacOSMovedBeforeTheUnplugWasReportedStillGoesBack() {
    let (h, _, _, _) = makeHarness()
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)

    unplugSideWithoutAWord(h, moving: [d])
    #expect(sideWorkspace(h)!.floating[d] == spot, "not the user's doing: it still lives where it floated")
    h.system.setDisplays([main])
    #expect(h.workspace.isFloating(d))
    #expect(main.visibleFrame.contains(h.frame(d)!))

    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h)!.floating[d] == spot)
    #expect(h.workspace.floating[d] == nil)
    #expect(h.frame(d) == spot)
  }

  @Test func dockedWindowsThatMacOSMovedAreNotPutBackOnADisplayThatIsGone() {
    let (h, a, b, c) = makeHarness()
    let before = sideWorkspace(h)!
    let slots = h.controller.layouts[side.id]!.windowFrames
    h.system.clearFrameLog()

    unplugSideWithoutAWord(h, moving: [a, b, c])
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.isEmpty, "nothing is sent to where no display is")

    h.system.setDisplays([main])
    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h)!.tree == before.tree)
    for (window, slot) in slots { #expect(h.frame(window) == slot) }
  }

  @Test func aFloatingWindowThatMacOSMovedBackBeforeTheDisplayWasReportedIsWhereItFloated() {
    let (h, _, _, _) = makeHarness()
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    h.system.setDisplays([main])
    let meanwhile = h.workspace.floating[d]

    // macOS remembers too, roughly.
    h.system.displayList = [main, side]
    h.system.userMove(d, to: spot.offsetBy(dx: -20, dy: 30))
    #expect(h.workspace.floating[d] == meanwhile)
    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h)!.floating[d] == spot)
    #expect(h.workspace.floating[d] == nil)
    #expect(h.frame(d) == spot)
  }

  // MARK: A display that only blinked

  /// On wake, or while a dock negotiates: the display is gone, macOS clears it, and it is back before anything was
  /// reported, so nothing ever is (`DisplayChange`).
  func sideIsBackWithoutAWord(_ h: Harness) { h.system.displayList = [main, side] }

  @Test func afterABlinkWhatMacOSMovedIsPutBack() {
    let (h, a, b, c) = makeHarness()
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    let before = h.controller.workspaces
    let slots = h.controller.layouts[side.id]!.windowFrames
    #expect(!slots.isEmpty)

    unplugSideWithoutAWord(h, moving: [a, b, c, d])
    h.scheduler.advance(by: 1)
    sideIsBackWithoutAWord(h)
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaces == before)
    for (window, slot) in slots { #expect(h.frame(window) == slot, "\(window)") }
    #expect(h.frame(d) == spot)
    #expect(h.controller.dormant.isEmpty)
  }

  @Test func afterABlinkWhatMacOSPutBackItselfIsLeftAlone() {
    let (h, a, b, c) = makeHarness()
    let d = h.system.open(app: "Terminal", frame: CGRect(x: 1900, y: 100, width: 300, height: 200))
    let frames = [a, b, c, d].map { h.frame($0)! }
    unplugSideWithoutAWord(h, moving: [a, b, c, d])
    h.scheduler.advance(by: 1)
    sideIsBackWithoutAWord(h)
    for (window, frame) in zip([a, b, c, d], frames) { h.system.userMove(window, to: frame) }
    h.system.clearFrameLog()
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  @Test func aBlinkInWhichNothingMovedCostsNothing() {
    let (h, _, _, _) = makeHarness()
    h.scheduler.advance(by: 5)
    let saves = h.store.saveCount
    h.system.clearFrameLog()
    h.system.displayList = [main]
    h.scheduler.advance(by: 1)
    sideIsBackWithoutAWord(h)
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.store.saveCount == saves)
  }

  @Test func aWindowOnTheDisplayThatStaysThatMacOSShuffledIsPutBackWithTheReport() {
    let (h, a, b, c) = makeHarness()
    let spot = CGRect(x: 700, y: 300, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    #expect(h.workspace.floating[d] == spot)

    unplugSideWithoutAWord(h, moving: [a, b, c, d])
    h.scheduler.advance(by: 1.5)
    h.system.setDisplays([main])
    #expect(h.workspace.floating[d] == spot)
    #expect(h.frame(d) == spot)
    // It was no blink, so nobody looks for one any more.
    #expect(!h.scheduler.pendingKeys.contains("displays-blinked"))
    h.system.clearFrameLog()
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  @Test func displaysThatGoOnChangingAreWaitedFor() {
    let (h, a, b, c) = makeHarness()
    let slots = h.controller.layouts[side.id]!.windowFrames
    unplugSideWithoutAWord(h, moving: [a, b, c])
    h.system.clearFrameLog()
    // The report is held back for as long as the displays keep changing. Nothing is sent to where no display is.
    h.scheduler.advance(by: 10)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    sideIsBackWithoutAWord(h)
    h.scheduler.advance(by: 3)
    for (window, slot) in slots { #expect(h.frame(window) == slot, "\(window)") }
  }

  @Test func theSameDisplaysInAnotherOrderDoNotStopArborFromFollowingTheUser() {
    let (h, _, _, _) = makeHarness()
    let d = h.system.open(app: "Terminal", frame: CGRect(x: 1900, y: 100, width: 300, height: 200))
    // Never reported, because nothing about any display changed (`DisplayChange.settleTime`).
    h.system.displayList = [side, main]
    let chosen = CGRect(x: 2000, y: 300, width: 300, height: 200)
    h.system.userMove(d, to: chosen)
    #expect(sideWorkspace(h)!.floating[d] == chosen)
  }

  @Test func returningFloatingWindowsStayOutOfViewWhileTheirDesktopIs() {
    let (h, a, _, _) = makeHarness()
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", frame: spot)
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(d))

    h.system.setDisplays([main])
    #expect(h.system.isVisible(d), "the main display's Desktop is in view")

    h.system.setDisplays([main, side])
    #expect(!h.system.isVisible(d), "the side display is still zoomed in on a")
    #expect(h.controller.parked.contains(d))
    h.run("show-all")
    #expect(h.frame(d) == spot)
  }

  @Test func evacuatedWindowsStayOutOfViewWhileTheMainDesktopIs() {
    let (h, a, b, c) = makeHarness()
    let m = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 200, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 700, y: 450)
    h.run("dock \(m.rawValue) left")
    h.run("zoom \(m.rawValue)")

    // macOS moves the windows of a display that goes away onto the main display.
    for window in [a, b, c] {
      h.system.userMove(window, to: h.frame(window)!.fitted(into: main.visibleFrame))
    }
    h.system.setDisplays([main])
    h.scheduler.runPending()
    for window in [a, b, c] {
      #expect(h.workspace.isFloating(window))
      #expect(!h.system.isVisible(window), "\(window) waits on the Desktop, which is out of view")
      #expect(h.controller.parked.contains(window))
    }
    h.run("show-all")
    let desktop = h.layout!.desktopFrame!
    for window in [a, b, c] {
      #expect(desktop.contains(h.frame(window)!), "\(window)")
    }
  }

  @Test func windowsClosedWhileTheDisplayWasAwayAreDropped() {
    let (h, a, b, c) = makeHarness()
    h.system.setDisplays([main])
    h.system.close(c)
    h.system.setDisplays([main, side])
    let restored = sideWorkspace(h)!
    #expect(restored.tree.allWindows == [a, b])
    #expect(restored.tree.invariantViolations().isEmpty)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func theNewestPlaceOfAWindowWins() {
    // a was docked on the side display, then on the main display, and both
    // displays went away. It goes back to the main display, not the side one.
    let third = DisplaySnapshot(
      id: DisplayID("third"), frame: CGRect(x: -1280, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [main, side, third])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1700, y: 150, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")

    h.system.setDisplays([main, third])
    h.system.cursor = CGPoint(x: 700, y: 450)
    #expect(h.run("dock \(a.rawValue) left").ok)
    #expect(h.controller.workspaces[main.id]!.isDocked(a))

    h.system.setDisplays([third])
    #expect(h.controller.dormant[side.id]?.workspace.contains(a) == false)
    #expect(h.controller.dormant[main.id]?.workspace.isDocked(a) == true)

    h.system.setDisplays([third, side])
    #expect(sideWorkspace(h)!.tree.allWindows == [b])
    #expect(h.controller.workspaces[third.id]!.isFloating(a))

    h.system.setDisplays([main, third, side])
    #expect(h.controller.workspaces[main.id]!.isDocked(a))
    #expect(h.controller.dormant.isEmpty)
    expectWindowsMatchLayout(h, on: main.id)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func windowsComeBackAfterEveryDisplayWasGone() {
    let (h, a, b, c) = makeHarness()
    let m = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 200, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 700, y: 450)
    h.run("dock \(m.rawValue) left")
    let mainArrangement = h.workspace
    let sideArrangement = sideWorkspace(h)!

    h.system.setDisplays([])
    #expect(h.controller.workspaces.isEmpty)
    #expect(Set(h.controller.dormant.keys) == [main.id, side.id])

    h.system.setDisplays([main])
    #expect(h.workspace.tree == mainArrangement.tree)
    for window in [a, b, c] {
      #expect(h.workspace.isFloating(window), "\(window) waits on the main display")
      #expect(h.system.isVisible(window))
    }

    h.system.setDisplays([main, side])
    #expect(sideWorkspace(h) == sideArrangement)
    #expect(h.workspace == mainArrangement)
    expectWindowsMatchLayout(h, on: main.id)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func aDragThatOutlivesItsDisplayEndsCleanly() {
    let (h, a, _, _) = makeHarness()
    let start = h.frame(a)!
    h.system.mouseDown = true
    h.controller.dragBegan(a, at: CGPoint(x: start.midX, y: start.minY + 10))
    h.system.setDisplays([main])
    h.system.mouseDown = false
    h.controller.dragEnded(a, at: CGPoint(x: 700, y: 450))
    #expect(h.workspace.isFloating(a))
    #expect(h.controller.dormant[side.id]?.workspace.isDocked(a) == true)
  }

  @Test func theOverlaysOfAGoneDisplayAreRemoved() {
    let (h, _, b, _) = makeHarness()
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    #expect(h.overlays.tiles[side.id]?.isEmpty == false)
    #expect(h.overlays.seams[side.id]?.isEmpty == false)
    h.system.setDisplays([main])
    #expect(h.overlays.tiles[side.id] == [])
    #expect(h.overlays.seams[side.id] == [])
  }

  @Test func aDisplayWithNothingArrangedIsNotRemembered() {
    let h = Harness(displays: [main, side])
    h.start()
    h.system.setDisplays([main])
    #expect(h.controller.dormant.isEmpty)
  }

  @Test func aDisplayWhoseVisibleFrameChangesIsLaidOutAgainWithTheSameTree() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    let before = h.workspace
    let oldSlots = h.layout!.windowFrames

    // The Dock appears along the bottom, then moves to the left edge, then
    // the resolution changes.
    var display = main
    let shapes: [(frame: CGRect, visible: CGRect)] = [
      (main.frame, CGRect(x: 0, y: 25, width: 1440, height: 800)),
      (main.frame, CGRect(x: 80, y: 25, width: 1360, height: 875)),
      (CGRect(x: 0, y: 0, width: 1280, height: 800), CGRect(x: 0, y: 25, width: 1280, height: 775)),
    ]
    for shape in shapes {
      display.frame = shape.frame
      display.visibleFrame = shape.visible
      h.system.setDisplays([display])
      #expect(h.workspace == before, "the tree, camera and floating windows are unchanged")
      #expect(h.controller.dormant.isEmpty)
      expectWindowsMatchLayout(h, on: main.id)
      for window in [a, b, c] {
        #expect(shape.visible.contains(h.frame(window)!), "\(window) fits the new visible frame")
      }
    }
    #expect(h.layout!.windowFrames != oldSlots)
  }

  // MARK: Restarts

  @Test func aDisconnectedDisplaysArrangementSurvivesARestart() throws {
    let (h, a, b, c) = makeHarness()
    h.run("zoom-node \(column(h, b).rawValue)")
    h.system.setDisplays([main])
    let remembered = try #require(h.controller.dormant[side.id])
    h.controller.saveNow()
    let saved = try #require(h.store.saved)
    #expect(saved.dormant[side.id] == remembered)
    // Through JSON, as state.json is.
    let decoded = try JSONDecoder().decode(PersistedState.self, from: JSONEncoder().encode(saved))
    #expect(decoded == saved)

    let again = Harness(displays: [main], saved: decoded)
    reopen(h, in: again)
    again.start()
    #expect(again.controller.dormant[side.id] == remembered)
    for window in [a, b, c] {
      #expect(again.workspace.isFloating(window))
    }

    again.system.setDisplays([main, side])
    #expect(again.controller.workspaces[side.id] == remembered.workspace)
    #expect(again.controller.dormant.isEmpty)
    #expect(again.workspace.floating.isEmpty)
    expectWindowsMatchLayout(again, on: side.id)
  }

  @Test func aDisplayReconnectedWhileArborWasNotRunningIsRestoredAtLaunch() throws {
    let (h, _, _, _) = makeHarness()
    h.system.setDisplays([main])
    let remembered = try #require(h.controller.dormant[side.id]).workspace
    h.controller.saveNow()

    let again = Harness(displays: [main, side], saved: h.store.saved)
    reopen(h, in: again)
    again.start()
    #expect(again.controller.workspaces[side.id] == remembered)
    #expect(again.controller.dormant.isEmpty)
    #expect(again.workspace.floating.isEmpty)
    expectWindowsMatchLayout(again, on: side.id)
  }

  @Test func aDisplayMissingAtLaunchIsRemembered() {
    let (h, a, b, c) = makeHarness()
    let arrangement = sideWorkspace(h)!
    h.controller.saveNow()

    let again = Harness(displays: [main], saved: h.store.saved)
    reopen(h, in: again)
    again.start()
    #expect(again.controller.dormant[side.id]?.workspace == arrangement)
    for window in [a, b, c] {
      #expect(again.workspace.isFloating(window))
      #expect(again.system.isVisible(window), "\(window) was on the missing display and is brought into view")
    }

    again.system.setDisplays([main, side])
    #expect(again.controller.workspaces[side.id] == arrangement)
    expectWindowsMatchLayout(again, on: side.id)
  }

  @Test func dormantWindowsAreMatchedAgainAfterAReboot() {
    let (h, a, b, c) = makeHarness()
    h.system.setDisplays([main])
    h.controller.saveNow()
    let snapshots = [a, b, c].map { h.controller.windows[$0]! }

    // After a reboot, unrelated windows reuse the old numbers and the
    // remembered windows come back under new numbers.
    let again = Harness(displays: [main], saved: h.store.saved)
    for _ in 0..<3 { again.system.open(app: "Filler") }
    let renumbered = snapshots.map {
      again.system.open(app: $0.appName, bundleID: $0.bundleID, title: $0.title, frame: $0.frame)
    }
    again.start()
    let tree = again.controller.dormant[side.id]!.workspace.tree
    #expect(tree.allWindows == renumbered)
    #expect(tree.invariantViolations().isEmpty)

    again.system.setDisplays([main, side])
    #expect(again.controller.workspaces[side.id]!.tree.allWindows == renumbered)
    for filler in [a, b, c] {
      #expect(again.workspace.isFloating(filler), "the fillers that took the old numbers stay put")
    }
    expectWindowsMatchLayout(again, on: side.id)
  }

  @Test func dormantWorkspacesExpireAfterThirtyDays() throws {
    let unplugged = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let (h, _, _, _) = makeHarness()
    h.controller.now = { unplugged }
    h.system.setDisplays([main])
    #expect(h.controller.dormant[side.id]?.since == unplugged)
    h.controller.saveNow()

    func launch(daysLater days: Double) -> Harness {
      let again = Harness(displays: [main], saved: h.store.saved)
      reopen(h, in: again)
      again.controller.now = { unplugged.addingTimeInterval(days * day) }
      again.start()
      return again
    }
    #expect(launch(daysLater: 29).controller.dormant[side.id] != nil)
    let late = launch(daysLater: 31)
    #expect(late.controller.dormant.isEmpty)
    late.controller.saveNow()
    #expect(try #require(late.store.saved).dormant.isEmpty)
  }

  /// A crash here would come back at every launch until state.json was deleted. A date in the far
  /// future used to be kept for ever.
  @Test(arguments: [-1e300, 1e300, 900_000_000_000]) func aDormantWorkspaceWithAnAbsurdDateIsDiscarded(date: Double) throws {
    let (h, _, _, _) = makeHarness()
    h.controller.now = { Date(timeIntervalSinceReferenceDate: date) }
    h.system.setDisplays([main])
    h.controller.saveNow()
    #expect(try #require(h.store.saved).dormant[side.id] != nil)

    let again = Harness(displays: [main], saved: h.store.saved)
    reopen(h, in: again)
    again.start()
    #expect(again.controller.dormant.isEmpty)
  }

  @Test func stateWithoutDormantWorkspacesStillLoads() throws {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    let saved = try #require(h.store.saved)

    // What Arbor wrote before dormant workspaces existed.
    let encoded = try JSONEncoder().encode(saved)
    var object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["dormant"] != nil)
    object["dormant"] = nil
    let old = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(PersistedState.self, from: old)
    #expect(decoded.dormant.isEmpty)
    #expect(decoded == saved)

    let again = Harness(saved: decoded)
    reopen(h, in: again)
    again.start()
    #expect(again.workspace.tree == h.workspace.tree)
    #expect(again.controller.dormant.isEmpty)
  }

  @Test func anOldStateFileLoadsFromDisk() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("arbor-state-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(#"{"hints":{},"version":1,"workspaces":{}}"#.utf8).write(to: url)
    let state = try #require(FileStateStore(url: url).load())
    #expect(state.dormant.isEmpty)
    #expect(state.workspaces.isEmpty)
  }
}
