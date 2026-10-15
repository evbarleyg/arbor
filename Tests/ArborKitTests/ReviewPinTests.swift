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
private let corner = CGRect(x: 1090, y: 50, width: 320, height: 240)

/// Pinned windows (docs/features/F49-pin.md) in the situations an independent review went looking for.
@Suite @MainActor struct ReviewPinTests {
  /// [editor | Desktop | browser] with a video call pinned in the top right corner, over the browser.
  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()
  ) -> (Harness, editor: WindowID, browser: WindowID, call: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let call = h.system.open(app: "Zoom", title: "Meeting", pid: 1003, frame: corner)
    h.start()
    h.run("pin \(call.rawValue)")
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.clearRaiseLog()
    return (h, editor, browser, call)
  }

  func savedPins(_ h: Harness) -> Set<WindowID> {
    h.controller.saveNow()
    let saved = h.store.saved!
    return Set(saved.workspaces.values.flatMap { $0.pinned ?? [] } + saved.dormant.values.flatMap { $0.workspace.pinned ?? [] })
  }

  // MARK: Displays

  @Test func oneDisplayGoingAsARememberedOneComesBackDoesNotCostThePin() {
    // A laptop put into its dock with the lid shut: the built-in display goes and the external one, whose
    // arrangement Arbor remembers, comes back, in one report.
    let (h, _, _, call) = makeHarness(displays: [main, side])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(mail.rawValue) left")
    h.system.setDisplays([main])
    #expect(h.controller.dormant[side.id] != nil)
    #expect(h.controller.isPinned(call))

    h.system.setDisplays([side])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.system.isVisible(call))
    #expect(!h.controller.parked.contains(call))

    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[main.id]!.isPinned(call), "and it goes home still pinned")
    #expect(h.frame(call) == corner)
  }

  @Test func closedWhileItsDisplayWasAwayItLeavesNoPinBehindInTheSavedState() {
    let (h, _, _, call) = makeHarness(displays: [main, side])
    h.system.userMove(call, to: CGRect(x: 2300, y: 40, width: 320, height: 240))
    h.system.setDisplays([main])
    #expect(savedPins(h) == [call])
    h.system.close(call)
    #expect(savedPins(h).isEmpty, "window numbers start again after a reboot: a number left behind becomes another window's")
    #expect(!h.store.saved!.dormant.values.contains { $0.workspace.contains(call) })
  }

  @Test func minimizedWhileItsDisplayGoesAndComesBackItReturnsPinnedAndInView() {
    let (h, editor, _, call) = makeHarness(displays: [main, side])
    let there = CGRect(x: 2300, y: 40, width: 320, height: 240)
    h.system.userMove(call, to: there)
    h.run("zoom \(editor.rawValue)")
    h.system.setMinimized(call, true)
    h.system.setDisplays([main])
    #expect(h.controller.workspaces[main.id]!.isPinned(call))
    // macOS gives it the keyboard first and reports it un-minimized afterwards.
    h.system.focused = call
    h.controller.windowFocused(call)
    h.system.setMinimized(call, false)
    h.scheduler.advance(by: 2)
    #expect(h.frame(call)!.fractionInside(main.visibleFrame) > 0.99)
    #expect(!h.controller.parked.contains(call))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor), "the view stays on the editor")
  }

  @Test func excludedAndIncludedAgainWhileItsDisplayWasAwayItStaysUnpinned() {
    let (h, _, _, call) = makeHarness(displays: [main, side])
    h.system.userMove(call, to: CGRect(x: 2300, y: 40, width: 320, height: 240))
    h.system.setDisplays([main])
    h.run("exclude com.example.zoom")
    #expect(!h.controller.isPinned(call))
    h.run("include com.example.zoom")
    #expect(!h.controller.isPinned(call))
    h.system.setDisplays([main, side])
    #expect(!h.controller.isPinned(call))
    #expect(h.system.isVisible(call))
  }

  @Test func draggedToAnotherDisplayItIsPinnedThereAndOnlyThere() {
    let (h, _, _, call) = makeHarness(displays: [main, side])
    h.system.drag(call, through: [CGPoint(x: 1250, y: 60), CGPoint(x: 1500, y: 100), CGPoint(x: 2000, y: 300)])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.controller.workspaces[main.id]!.pinned == nil)
    #expect(!h.controller.workspaces[main.id]!.contains(call))
    #expect(savedPins(h) == [call])
    h.system.cursor = CGPoint(x: 2000, y: 400)
    let here = h.frame(call)!
    h.run("desktop")
    h.run("show-all")
    #expect(h.frame(call) == here)
  }

  // MARK: What macOS really sends

  @Test func unMinimizedWithTheFocusReportFirstTheViewStaysAndSoDoesTheWindow() {
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(editor)
    h.run("zoom")
    h.system.setMinimized(call, true)
    h.run("neighbor right")
    h.run("neighbor left")
    let camera = h.workspace.camera
    h.system.focused = call
    h.controller.windowFocused(call)
    h.system.setMinimized(call, false)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera)
    #expect(h.frame(call) == corner)
    #expect(h.controller.isPinned(call))
  }

  @Test func closedWhileItHasTheKeyboardWithTheFocusReportFirstNothingIsLeftOfIt() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.userFocus(call)
    let camera = h.workspace.camera
    // macOS hands the keyboard on before it reports the window destroyed.
    h.system.focused = editor
    h.controller.windowFocused(editor)
    h.system.close(call)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera)
    #expect(h.workspace.pinned == nil)
    #expect(savedPins(h).isEmpty)
    #expect(!h.system.raiseLog.contains(call))
  }

  @Test func aRulePinnedWindowThatIsFocusedAsItOpensDoesNotMoveTheView() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.facetime", action: .pin)]
    let (h, editor, _, _) = makeHarness(settings: settings)
    h.run("zoom \(editor.rawValue)")
    let camera = h.workspace.camera
    var heard: [Controller.Change] = []
    h.controller.observe { heard.append($0) }
    let second = h.system.open(app: "FaceTime", pid: 1004, frame: CGRect(x: 100, y: 500, width: 300, height: 200))
    #expect(heard.contains(.layout(h.display)), "whoever shows the state hears of the pin")
    h.system.userFocus(second)
    h.scheduler.advance(by: 2)
    #expect(h.controller.isPinned(second))
    #expect(h.workspace.camera == camera)
    #expect(h.frame(second) == CGRect(x: 100, y: 500, width: 300, height: 200))
  }

  @Test func aDisplayChangeReportedForNothingLeavesItAlone() {
    // Minimizing a window makes macOS report a display change although none changed.
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.clearFrameLog()
    h.system.setDisplays([main])
    #expect(h.frame(call) == corner)
    #expect(h.system.frameLog.allSatisfy { $0.window != call })
    #expect(h.controller.isPinned(call))
  }

  // MARK: Full screen

  @Test func inFullScreenItIsLeftAloneAndComesBackPinnedWhereItWas() {
    let (h, editor, browser, call) = makeHarness()
    h.system.setFullScreen(call, true)
    h.system.clearFrameLog()
    h.system.clearRaiseLog()
    h.system.userFocus(editor)
    h.run("zoom")
    h.run("neighbor right")
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.allSatisfy { $0.window != call })
    #expect(h.system.raiseLog.isEmpty)
    h.system.setFullScreen(call, false)
    h.scheduler.advance(by: 1)
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    #expect(h.workspace.floating[call] == corner, "the display's size is not where the user put it")
    _ = browser
  }

  // MARK: Pause, quit

  @Test func aLookThatWasDueWhenArborPausedRaisesNothing() {
    let (h, editor, browser, call) = makeHarness()
    _ = editor
    h.system.userFocus(browser)
    h.run("pause")
    h.system.clearRaiseLog()
    h.scheduler.advance(by: 5)
    #expect(h.system.raiseLog.isEmpty)
    #expect(h.frame(call) == corner)
  }

  @Test func aLookThatWasDueWhenArborQuitRaisesNothing() {
    let (h, _, browser, _) = makeHarness()
    h.system.userFocus(browser)
    h.controller.shutdown()
    h.system.clearRaiseLog()
    h.scheduler.advance(by: 5)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func whileTheMouseButtonIsHeldArborStopsLookingOnceItIsPaused() {
    let (h, _, browser, _) = makeHarness()
    h.system.mouseDown = true
    h.system.userFocus(browser)
    h.scheduler.advance(by: 1)
    h.run("pause")
    h.system.clearRaiseLog()
    h.system.stackingIsUnknown = true
    h.scheduler.advance(by: 5)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func quittingLeavesItWhereItIsEvenIfItHangsOverAnEdge() {
    let (h, editor, _, call) = makeHarness()
    let overTheEdge = CGRect(x: 1300, y: 50, width: 240, height: 240)
    h.system.userMove(call, to: overTheEdge)
    h.run("zoom \(editor.rawValue)")
    h.controller.shutdown()
    #expect(h.frame(call) == overTheEdge)
  }

  // MARK: Saved state

  /// What `old` saved, seen by a new Arbor process with these windows, numbered from 101 in this order.
  func relaunch(_ old: Harness, windows: [(app: String, title: String?)]) -> Harness {
    old.controller.saveNow()
    let new = Harness(displays: old.system.displayList, saved: old.store.saved)
    for (index, window) in windows.enumerated() {
      new.system.open(app: window.app, title: window.title, pid: Int32(2001 + index))
    }
    new.start()
    return new
  }

  @Test func afterARebootANumberThatNowBelongsToAnotherAppIsNotPinned() {
    let (old, _, _, call) = makeHarness()
    // 103 was the call; now it is Notes, and the call is 104.
    let h = relaunch(old, windows: [("Editor", nil), ("Browser", nil), ("Notes", nil), ("Zoom", "Meeting")])
    #expect(!h.controller.isPinned(call))
    #expect(h.controller.isPinned(WindowID(104)))
    #expect(savedPins(h) == [WindowID(104)])
  }

  @Test func afterARebootWithoutTheCallNothingIsPinnedAndNothingIsSaved() {
    let (old, _, _, _) = makeHarness()
    let h = relaunch(old, windows: [("Editor", nil), ("Browser", nil)])
    #expect(h.workspace.pinned == nil)
    #expect(savedPins(h).isEmpty)
    // The next window to get the old number is an ordinary window.
    let notes = h.system.open(app: "Notes")
    #expect(notes == WindowID(103))
    #expect(!h.controller.isPinned(notes))
  }

  @Test func twoCallsWithTheSameTitleAreNotBothGivenOnePin() {
    let (old, _, _, _) = makeHarness()
    let h = relaunch(
      old, windows: [("Editor", nil), ("Browser", nil), ("Notes", nil), ("Zoom", "Meeting"), ("Zoom", "Meeting")])
    #expect(h.workspace.pinnedWindows == [WindowID(104)])
  }

  @Test func twoPinnedWindowsWithTheSameTitleAreEachFoundAgain() {
    let (old, _, _, _) = makeHarness()
    let second = old.system.open(app: "Zoom", title: "Meeting", pid: 1003, frame: corner.offsetBy(dx: 0, dy: 300))
    old.run("pin \(second.rawValue)")
    let h = relaunch(
      old,
      windows: [("Editor", nil), ("Browser", nil), ("Notes", nil), ("Notes", nil), ("Zoom", "Meeting"), ("Zoom", "Meeting")])
    #expect(h.workspace.pinnedWindows == [WindowID(105), WindowID(106)])
  }

  /// `workspace` as a file edited by hand would have it: `pins` are pinned, whatever they are.
  func edited(_ workspace: Workspace, pins: [WindowID]) throws -> Workspace {
    let data = try JSONEncoder().encode(workspace)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["pinned"] = pins.map { Int($0.rawValue) }
    return try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func aPinInAnEditedFileOnAWindowThatDoesNotFloatIsDroppedAndNeverComesToLife() throws {
    let (old, editor, _, _) = makeHarness(displays: [main, side])
    let mail = old.system.open(app: "Mail", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    old.system.cursor = CGPoint(x: 2000, y: 400)
    old.run("dock \(mail.rawValue) left")
    old.system.setDisplays([main])
    old.controller.saveNow()
    var saved = old.store.saved!
    saved.workspaces[main.id] = try edited(saved.workspaces[main.id]!, pins: [editor, WindowID(999)])
    saved.dormant[side.id]!.workspace = try edited(saved.dormant[side.id]!.workspace, pins: [mail])

    let h = Harness(displays: [main], saved: saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(!h.controller.isPinned(editor))
    #expect(savedPins(h).isEmpty, "what is not believed is not written back either")
    h.run("float \(editor.rawValue)")
    #expect(!h.controller.isPinned(editor))

    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isDocked(mail))
    h.run("float \(mail.rawValue)")
    #expect(!h.controller.isPinned(mail))
  }

  // MARK: Commands in odd places

  @Test func pinningATabBehindAnotherBringsItIntoViewAndLeavesTheOtherTabDocked() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, editor, _, _) = makeHarness(settings: settings)
    let notes = h.system.open(app: "Notes", pid: 1005)
    let leaf = h.workspace.tree.leaf(containing: editor)!
    h.system.drag(notes, through: [CGPoint(x: 600, y: 210), h.layout!.nodeFrames[leaf]!.center])
    #expect(h.workspace.tree.leaf(containing: notes) == leaf, "a tab group of the editor and the notes")
    h.system.userFocus(editor)
    #expect(h.run("pin \(notes.rawValue)").ok)
    #expect(h.controller.isPinned(notes))
    #expect(h.system.isVisible(notes))
    #expect(!h.controller.parked.contains(notes))
    #expect(h.workspace.isDocked(editor))
  }

  @Test func pinningTheOnlyDockedWindowLeavesAnEmptyArrangementAndAWindowInView() {
    let h = Harness()
    let only = h.system.open(app: "Only")
    h.start()
    h.run("dock \(only.rawValue) left")
    h.run("zoom \(only.rawValue)")
    #expect(h.run("pin \(only.rawValue)").ok)
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.controller.isPinned(only))
    #expect(h.frame(only)!.fractionInside(h.visibleFrame) > 0.99)
    #expect(h.frame(only)!.width <= h.visibleFrame.width / 2 + 1)
  }

  @Test func pinningAMinimizedWindowThatWasOutOfViewShowsItWhenItComesBack() {
    let (h, editor, _, _) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.run("zoom \(editor.rawValue)")
    #expect(h.controller.parked.contains(notes))
    h.system.setMinimized(notes, true)
    #expect(h.run("pin \(notes.rawValue)").ok)
    let camera = h.workspace.camera
    h.system.focused = notes
    h.controller.windowFocused(notes)
    h.system.setMinimized(notes, false)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(notes))
    #expect(!h.controller.parked.contains(notes))
    #expect(h.workspace.camera == camera)
  }

  @Test func pinnedWhileBeingDraggedItStaysInTheHandAndIsNotDockedWhenDropped() {
    let (h, _, _, _) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.system.mouseDown = true
    h.controller.dragBegan(notes, at: CGPoint(x: 700, y: 310))
    h.system.clearFrameLog()
    #expect(h.run("pin \(notes.rawValue)").ok)
    #expect(h.system.frameLog.allSatisfy { $0.window != notes })
    h.system.mouseDown = false
    h.controller.dragEnded(notes, at: CGPoint(x: 5, y: 400))
    #expect(h.controller.isPinned(notes))
    #expect(h.workspace.isFloating(notes))
  }

  @Test func framingWithThePinnedWindowFocusedNeverParksIt() {
    let (h, _, _, call) = makeHarness()
    h.system.userFocus(call)
    for command in ["zoom", "zoom", "in", "out", "neighbor left", "neighbor right", "desktop", "home", "back", "forward"] {
      h.run(command)
      h.scheduler.advance(by: 1)
      #expect(h.frame(call) == corner, "after \(command)")
      #expect(!h.controller.parked.contains(call), "after \(command)")
    }
  }

  @Test func floatAllHereAndArrangeAllLeaveItAlone() {
    let (h, _, _, call) = makeHarness(displays: [main, side])
    for command in ["arrange all", "float-all here", "arrange", "float-all", "relayout"] {
      h.run(command)
      #expect(h.frame(call) == corner, "after \(command)")
      #expect(h.controller.isPinned(call), "after \(command)")
    }
  }

  @Test func unpinnedItIsAnOrdinaryFloatingWindowAgain() {
    let (h, editor, _, call) = makeHarness()
    h.run("unpin \(call.rawValue)")
    h.run("zoom \(editor.rawValue)")
    #expect(h.controller.parked.contains(call))
    h.system.clearRaiseLog()
    h.scheduler.advance(by: 1)
    #expect(h.system.raiseLog.isEmpty)
    h.run("show-all")
    #expect(h.system.isVisible(call))
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(call, through: [CGPoint(x: 700, y: 300), CGPoint(x: 3, y: 400)])
    #expect(h.workspace.isDocked(call), "and can be docked by dragging")
  }

  @Test func pinningADockedWindowLetsItsNeighboursCloseOverItsSlotAtOnce() {
    let (h, editor, browser, _) = makeHarness()
    let before = h.frame(editor)!
    h.run("pin \(browser.rawValue)")
    #expect(h.frame(editor)!.width > before.width + 100, "not only at the next layout")
    #expect(h.layout?.windowFrames[browser] == nil)
  }

  @Test func pinningAWideDockedWindowHalvesItsWidthAndItsHeightSeparately() {
    let h = Harness()
    // The size it gets back when it leaves the arrangement (F48) covers more than half of the display.
    let wide = h.system.open(app: "Wide", frame: CGRect(x: 20, y: 100, width: 1400, height: 600))
    h.start()
    h.run("dock \(wide.rawValue) top")
    h.run("pin \(wide.rawValue)")
    #expect(abs(h.frame(wide)!.width - h.visibleFrame.width / 2) <= 1)
    #expect(abs(h.frame(wide)!.height - h.visibleFrame.height / 2) <= 1)
  }

  @Test func pinningAndUnpinningAreSavedWithoutAnythingElseHappening() {
    let (h, _, _, call) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.scheduler.advance(by: 2)
    func pinsInTheFile() -> Set<WindowID> { Set(h.store.saved!.workspaces.values.flatMap { $0.pinned ?? [] }) }
    #expect(pinsInTheFile() == [call])
    h.run("pin \(notes.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(pinsInTheFile() == [call, notes], "a crash a moment later does not cost the pin")
    h.run("unpin \(notes.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(pinsInTheFile() == [call])
  }

  @Test func whoeverShowsTheStateHearsOfPinningAndUnpinning() {
    let (h, _, _, call) = makeHarness()
    var heard: [Controller.Change] = []
    h.controller.observe { heard.append($0) }
    h.run("unpin \(call.rawValue)")
    #expect(heard.contains(.layout(h.display)))
    heard.removeAll()
    h.run("pin \(call.rawValue)")
    #expect(heard.contains(.layout(h.display)))
  }

  @Test func pinningAWindowThatLiesBehindAnotherBringsItToTheFront() {
    let (h, _, browser, call) = makeHarness()
    h.run("unpin \(call.rawValue)")
    h.system.userFocus(browser)
    h.scheduler.advance(by: 1)
    #expect(h.system.windowsFrontToBack().first == browser)
    h.system.clearRaiseLog()
    h.run("pin \(call.rawValue)")
    h.scheduler.advance(by: 1)
    #expect(h.system.raiseLog == [call])
    #expect(h.system.focused == browser)
  }

  // MARK: Staying in front

  @Test func aWindowOutOfViewInTheCornerDoesNotKeepArborRaising() {
    // The call sits in the bottom right corner, where windows out of view keep one point on screen.
    let (h, editor, _, call) = makeHarness()
    let v = h.visibleFrame
    h.system.userMove(call, to: CGRect(x: v.maxX - 320, y: v.maxY - 240, width: 320, height: 240))
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 1)
    h.system.clearRaiseLog()
    h.scheduler.advance(by: 5)
    #expect(h.system.raiseLog.isEmpty)
    _ = call
  }

  @Test func holdingTheMouseButtonDoesNotRaiseItAgainAndAgain() {
    let (h, _, browser, call) = makeHarness()
    h.system.mouseDown = true
    h.system.userFocus(browser)
    h.scheduler.advance(by: 10)
    #expect(h.system.raiseLog == [call], "once it is in front there is nothing to do")
    h.system.mouseDown = false
    h.scheduler.advance(by: 1)
    #expect(h.system.raiseLog == [call])
  }

  @Test func anAppReportingItsRaisedWindowAsFocusedDoesNotLeaveTheKeyboardOutOfView() {
    let (h, editor, browser, call) = makeHarness()
    h.system.userFocus(editor)
    h.run("zoom")
    h.scheduler.advance(by: 1)
    #expect(h.controller.parked.contains(browser))
    // ⌘Tab to the browser. Its report comes before macOS says its app is in front, so Arbor looks again a
    // moment later. Meanwhile Arbor raises the call, whose app reports that as a change of its focused window.
    h.controller.windowFocused(browser)
    h.scheduler.advance(by: 0)
    h.system.backgroundFocus(call)
    h.system.focused = browser
    h.scheduler.advance(by: 2)
    #expect(h.layout?.windowFrames[browser] != nil, "the window with the keyboard is in view")
  }

  @Test func ofTwoPinnedWindowsTheOneUsedLastEndsUpInFrontWhicheverOpenedFirst() {
    let (h, _, browser, call) = makeHarness()
    let timer = h.system.open(app: "Timer", pid: 1007, frame: corner.offsetBy(dx: -40, dy: 40))
    h.run("pin \(timer.rawValue)")
    for (first, last) in [(call, timer), (timer, call)] {
      h.system.userFocus(first)
      h.system.userFocus(last)
      h.system.clearRaiseLog()
      h.system.userFocus(browser)
      h.scheduler.advance(by: 1)
      #expect(h.system.raiseLog == [first, last])
      #expect(h.system.windowsFrontToBack().first == last)
    }
  }

  @Test func aWindowOfAnExcludedAppThatCoversItIsPutBehindItToo() {
    let (h, _, _, call) = makeHarness()
    let game = h.system.open(app: "Game", pid: 1006, frame: CGRect(x: 900, y: 40, width: 500, height: 400))
    h.run("exclude com.example.game")
    h.scheduler.advance(by: 1)
    h.system.clearRaiseLog()
    h.system.userFocus(game)
    h.scheduler.advance(by: 1)
    #expect(h.system.raiseLog == [call])
  }
}
