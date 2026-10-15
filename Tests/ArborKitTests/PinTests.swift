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

/// Where the call sits in these tests: the top right corner of the main display.
private let corner = CGRect(x: 1090, y: 50, width: 320, height: 240)
/// What its strip leaves of that display for views (KeepInViewMakesRoomTests has the rule's own tests).
private let beside = CGRect(x: 0, y: 25, width: 1090, height: 875)

/// Pinned windows (docs/features/F49-pin.md).
@Suite @MainActor struct PinTests {
  /// [editor | Desktop | browser] with a video call pinned in the top right corner, beside the browser.
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
    settle(h)
    h.system.clearFrameLog()
    return (h, editor, browser, call)
  }

  /// Lets what Arbor put off until the command or event was over happen, and its later looks at the stacking.
  func settle(_ h: Harness) { h.scheduler.advance(by: 1) }

  /// Only what Arbor put off until the command or event was over.
  func finishEvent(_ h: Harness) { h.scheduler.advance(by: 0) }

  /// No timer is due that looks after windows kept in view: none that would raise one, none that would lay out around one.
  func nobodyIsLooking(_ h: Harness) -> Bool { !h.scheduler.pendingKeys.contains { $0.hasPrefix("raise") || $0.hasPrefix("pinned-room") } }

  /// Whether another window lies over part of `window`.
  func isCovered(_ window: WindowID, _ h: Harness) -> Bool {
    h.system.windowsFrontToBack().prefix { $0 != window }.contains { h.frame($0)!.overlaps(h.frame(window)!) }
  }

  func moves(of window: WindowID, _ h: Harness) -> [CGRect] {
    h.system.frameLog.filter { $0.window == window }.map(\.frame)
  }

  /// The same windows (numbers, apps, titles, frames) seen by a new Arbor process that loads what `old` saved.
  func relaunch(_ old: Harness, displays: [DisplaySnapshot]? = nil) -> Harness {
    let new = Harness(displays: displays ?? old.system.displayList, saved: old.store.saved)
    for window in old.system.allWindows() {
      new.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    new.start()
    return new
  }

  // MARK: 1. It never leaves the view

  @Test func aPinnedWindowKeepsItsPlaceThroughEveryCameraMove() {
    let (h, editor, _, call) = makeHarness()
    let journey = [
      "zoom \(editor.rawValue)", "neighbor right", "neighbor right", "show-all", "desktop", "back", "forward",
      "out", "in", "home", "save-view 1", "zoom \(editor.rawValue)", "view 1",
    ]
    for step in journey {
      #expect(h.run(step).ok, "\(step)")
      settle(h)
      #expect(h.frame(call) == corner, "after \(step)")
      #expect(!h.controller.parked.contains(call), "after \(step)")
    }
    #expect(moves(of: call, h).isEmpty, "Arbor never touched its frame")
  }

  @Test func otherFloatingWindowsStillLeaveWithTheDesktop() {
    let (h, editor, _, call) = makeHarness()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.run("zoom \(editor.rawValue)")
    #expect(h.controller.parked.contains(notes))
    #expect(h.system.isVisible(call) && !h.system.isVisible(notes))
  }

  @Test func dockedWindowsKeepClearOfItAndDoNotPushIt() {
    let (h, _, browser, call) = makeHarness()
    #expect(!h.frame(browser)!.overlaps(corner), "neither covers the other, which is the point (collab/QUESTIONS.md Q25)")
    let mail = h.system.open(app: "Mail")
    h.run("dock \(mail.rawValue) right")
    h.run("resize \(browser.rawValue) left 200")
    h.run("relayout")
    #expect(h.frame(call) == corner)
    #expect(moves(of: call, h).isEmpty)
    for window in [browser, mail] { #expect(!h.frame(window)!.overlaps(corner)) }
  }

  @Test func pinningAWindowThatIsOutOfViewBringsItBackWithoutMovingTheCamera() {
    let (h, editor, _, call) = makeHarness()
    h.run("unpin \(call.rawValue)")
    h.run("zoom \(editor.rawValue)")
    #expect(!h.system.isVisible(call))
    let camera = h.workspace.camera

    #expect(h.run("pin \(call.rawValue)").ok)
    #expect(h.frame(call) == corner, "where it was last left")
    #expect(!h.controller.parked.contains(call))
    #expect(h.workspace.camera == camera)
    #expect(h.frame(editor) == beside.insetBy(dx: 12, dy: 12))
  }

  @Test func itStaysWhenTheDesktopIsSqueezedIntoATile() {
    let (h, editor, browser, call) = makeHarness()
    // The Desktop column shrinks below the smallest usable width.
    h.run("resize \(editor.rawValue) right 150")
    h.run("resize \(browser.rawValue) left 150")
    #expect(h.layout!.tiles.contains { $0.kind == .desktop }, "the Desktop is a tile")
    #expect(h.layout!.desktopFrame == nil)
    h.run("zoom \(editor.rawValue)")
    h.run("show-all")
    #expect(h.frame(call) == corner)
    #expect(!h.controller.parked.contains(call))
    #expect(moves(of: call, h).isEmpty)
  }

  // MARK: 2. It is not covered, and does not take the keyboard
  //
  // Until 2026-10-15 these said that Arbor raised it after whatever had covered it. On a Mac that raise stops behind the window that has
  // the keyboard (collab/QUESTIONS.md Q25), so docked windows keep clear of it instead and nothing is raised. What each guards is
  // the same: after this, all of the call is to be seen.

  @Test func afterEachCameraMoveItIsInFrontAndTheKeyboardIsWhereTheMovePutIt() {
    let (h, editor, browser, call) = makeHarness()
    h.system.userFocus(editor)
    let steps: [(String, WindowID)] = [
      ("zoom \(editor.rawValue)", editor), ("neighbor right", editor), ("neighbor right", browser),
      ("show-all", browser), ("zoom \(browser.rawValue)", browser), ("back", browser), ("zoom \(editor.rawValue)", editor),
    ]
    for (step, keyboard) in steps {
      h.system.clearRaiseLog()
      #expect(h.run(step).ok, "\(step)")
      settle(h)
      #expect(!isCovered(call, h), "after \(step)")
      #expect(h.system.raiseLog.isEmpty, "and nothing had to be raised after \(step)")
      #expect(h.system.focused == keyboard, "the keyboard after \(step)")
    }
  }

  @Test func whileTheWindowsMoveItsStandInIsInFrontToo() throws {
    // The editor was clicked last, so the call is behind it in the stacking. On its way to filling what is left the editor's stand-in
    // must not pass over the one thing that stands still.
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(editor)
    settle(h)
    #expect(h.system.windowsFrontToBack().first == editor)
    h.overlays.clearTransitions()
    h.run("zoom")
    for transition in h.overlays.transitions {
      #expect(transition.items.last?.window == call, "back to front: \(transition.items.map(\.window))")
    }
    #expect(!h.overlays.transitions.isEmpty)
    settle(h)
    #expect(!isCovered(call, h), "which is how the real windows end up")
  }

  @Test func framingTheWindowThatAlreadyHasTheKeyboardDoesNotCoverIt() {
    // macOS reports no focus change here, though focusing the window again puts it in front.
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(editor)
    settle(h)
    h.run("zoom")
    settle(h)
    #expect(h.system.windowsFrontToBack().first == editor, "the command's last step is to focus the window, and there it stays")
    #expect(!isCovered(call, h))
    #expect(h.system.focused == editor)
  }

  @Test func clickingAnotherWindowDoesNotCoverIt() {
    let (h, _, browser, call) = makeHarness()
    h.system.clearRaiseLog()
    h.system.userFocus(browser)
    settle(h)
    #expect(h.system.windowsFrontToBack().first == browser, "the window switched to stays in front")
    #expect(!isCovered(call, h) && h.system.raiseLog.isEmpty)
    #expect(h.system.focused == browser, "typing goes on in the window that was clicked")
  }

  @Test func aClickedWindowThatComesToTheFrontLateDoesNotCoverItEither() {
    // Seen on macOS 26: a clicked window takes the keyboard first and comes to the front afterwards.
    let (h, _, browser, call) = makeHarness()
    h.system.clearRaiseLog()
    h.system.mouseDown = true
    h.system.focused = browser
    h.controller.windowFocused(browser)
    finishEvent(h)
    // A long press.
    h.scheduler.advance(by: 3)
    h.system.focus(browser)
    h.system.mouseDown = false
    h.scheduler.advance(by: 1)
    #expect(!isCovered(call, h))
    #expect(h.system.raiseLog.isEmpty)
    #expect(h.system.focused == browser)
    #expect(nobodyIsLooking(h), "nobody is looking")
  }

  @Test func clickingInTheWindowThatAlreadyHasTheKeyboardDoesNotCoverIt() {
    // Every click in the editor one is working in: it comes to the front, and macOS reports no change of focus.
    let (h, _, browser, call) = makeHarness()
    h.system.userFocus(browser)
    settle(h)
    h.system.clearRaiseLog()
    h.system.userClick(browser)
    #expect(!isCovered(call, h))
    settle(h)
    #expect(!isCovered(call, h) && h.system.raiseLog.isEmpty)
    #expect(h.system.focused == browser)
  }

  @Test func whileTheButtonStaysDownInThatWindowItIsNotLeftCovered() {
    // Selecting text for three seconds.
    let (h, _, browser, call) = makeHarness()
    h.system.userFocus(browser)
    settle(h)
    h.system.userClick(browser, release: false)
    h.scheduler.advance(by: 0.2)
    #expect(!isCovered(call, h))
    h.system.mouseDown = false
    settle(h)
    #expect(nobodyIsLooking(h), "and then it stops looking")
  }

  @Test func aPressAsksNoAppAnything() {
    // Selecting text for three seconds in the window beside it. Who has the keyboard is a question to the app in
    // front, the one being worked in.
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(editor)
    settle(h)
    let asked = h.system.focusedWindowReads
    h.system.userClick(editor, release: false)
    finishEvent(h)
    #expect(!isCovered(call, h))
    h.scheduler.advance(by: 3)
    #expect(nobodyIsLooking(h), "nobody goes on looking")
    h.system.mouseDown = false
    settle(h)
    #expect(h.system.focusedWindowReads == asked)
  }

  @Test func ofTwoPinnedWindowsNeitherIsCoveredAndNeitherIsRaised() {
    let (h, editor, browser, call) = makeHarness()
    // By the left edge, as the call is by the right one.
    let player = h.system.open(app: "Music", pid: 1004, frame: CGRect(x: 0, y: 600, width: 200, height: 120))
    h.run("pin \(player.rawValue)")
    h.system.userFocus(editor)
    settle(h)
    #expect(!h.frame(player)!.overlaps(h.frame(editor)!) && !h.frame(call)!.overlaps(h.frame(browser)!))
    h.system.clearRaiseLog()
    h.system.userFocus(browser)
    settle(h)
    #expect(h.system.raiseLog.isEmpty, "raising asks a window's app, which may be busy")
    #expect(!isCovered(call, h) && !isCovered(player, h))
  }

  @Test func clicksWithNothingPinnedCostNothing() {
    let (h, _, browser, call) = makeHarness()
    h.run("unpin \(call.rawValue)")
    settle(h)
    h.system.userClick(browser)
    #expect(nobodyIsLooking(h))
  }

  @Test func aPinnedWindowThatNothingCoversIsNotRaised() {
    // Raising asks the window's app, which may be busy with a call.
    let (h, editor, _, _) = makeHarness()
    h.system.clearRaiseLog()
    h.system.userFocus(editor)
    h.run("out")
    h.run("relayout")
    settle(h)
    #expect(h.system.raiseLog.isEmpty, "the editor is docked on the left, the call is in the top right corner")
  }

  @Test func whenTheStackingCannotBeToldNothingIsRaisedLaterEither() {
    // At the pin it is (KeepInViewMakesRoomTests).
    let (h, _, browser, _) = makeHarness()
    h.system.clearRaiseLog()
    h.system.stackingIsUnknown = true
    h.system.userFocus(browser)
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func clickingThePinnedWindowGivesItTheKeyboardAndMovesNothing() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    settle(h)
    let camera = h.workspace.camera
    h.system.clearRaiseLog()
    h.system.userFocus(call)
    settle(h)
    #expect(h.workspace.camera == camera, "it is in view, so the camera has nowhere to go")
    #expect(h.system.focused == call)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func aMoveOfTheViewTakesTheKeyboardAlongAlsoOutOfAPinnedWindow() {
    // Click mute in the call, ⌃⌥→ twice, type: the keys are meant for the window that arrived.
    let (h, editor, browser, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.userFocus(call)
    h.run("neighbor right")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.focused == call, "nothing has arrived on the empty Desktop")
    h.run("neighbor right")
    #expect(h.system.focused == browser)
    for (step, keyboard) in [("back", call), ("back", editor), ("forward", call), ("show-all", editor)] {
      h.system.userFocus(call)
      h.run(step)
      #expect(h.system.focused == keyboard, "after \(step)")
    }
    settle(h)
    #expect(h.frame(call) == corner && !isCovered(call, h))
  }

  @Test func aCommandThatLeavesTheViewWhereItIsLeavesTheKeyboardInThePinnedWindow() {
    let (h, _, _, call) = makeHarness()
    h.system.userFocus(call)
    for step in ["show-all", "home", "relayout", "save-view 2"] {
      h.run(step)
      #expect(h.system.focused == call, "after \(step)")
    }
  }

  @Test func theFrameShortcutInAPinnedWindowUnframesWhatIsBeneath() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.userFocus(call)
    #expect(h.run("zoom").ok)
    #expect(h.workspace.camera == h.workspace.tree.root, "not the Desktop, where it does not live")
    #expect(h.frame(call) == corner)

    // With nothing framed there is nothing to undo, and a pinned window has no place to frame.
    h.system.userFocus(call)
    #expect(h.run("zoom").message == "\(call) is kept in view; dock it to give it a place")
    #expect(h.run("zoom \(call.rawValue)").message == "\(call) is kept in view; dock it to give it a place")
    #expect(h.workspace.camera == h.workspace.tree.root)
    h.run("zoom \(editor.rawValue)")
    #expect(!h.run("zoom \(call.rawValue)").ok, "named, it never moves the view")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor))
  }

  @Test func pinnedWhereDockedWindowsHadPushedItThatIsItsPlaceFromNowOn() {
    // Or whatever sends floating windows back to where the user left them (float-all, quitting) would move it.
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    // Small enough for the Desktop, so it is pushed and not squeezed (`aWindowTheDesktopSqueezedIsItsOwnSizeOncePinned`).
    let left = CGRect(x: 100, y: 200, width: 320, height: 240)
    let call = h.system.open(app: "Zoom", pid: 1003, frame: left)
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    let pushed = h.frame(call)!
    #expect(pushed != left && pushed.size == left.size)
    h.run("pin \(call.rawValue)")
    #expect(h.frame(call) == pushed, "pinning moves nothing")
    #expect(h.workspace.floating[call] == pushed)
    h.run("zoom \(editor.rawValue)")
    h.run("float-all")
    #expect(h.frame(call) == pushed)
    h.controller.shutdown()
    #expect(h.frame(call) == pushed)
  }

  @Test func aCameraMoveNeverGivesItTheKeyboard() {
    // Keys typed into a call by surprise mute, unmute and hang up.
    let (h, editor, browser, call) = makeHarness()
    // Nearest the top left corner and under the pointer: first choice twice over, were it not pinned.
    h.system.userMove(call, to: CGRect(x: 0, y: 25, width: 320, height: 240))
    h.system.cursor = CGPoint(x: 100, y: 100)
    h.system.userFocus(editor)
    h.run("zoom \(browser.rawValue)")
    h.system.userFocus(browser)
    h.run("neighbor left")
    settle(h)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.focused == browser, "with nothing else in view the keyboard stays where it was")
    h.run("neighbor left")
    settle(h)
    #expect(h.system.focused == editor, "and goes to the window that arrives")
  }

  @Test func whichPinnedWindowLiesOverWhichIsLeftToMacOS() {
    let (h, _, browser, call) = makeHarness()
    let timer = h.system.open(app: "Timer", frame: CGRect(x: 1200, y: 100, width: 200, height: 100))
    h.run("pin \(timer.rawValue)")
    h.system.userFocus(timer)
    h.system.userFocus(call)
    settle(h)
    h.system.clearRaiseLog()
    h.system.userFocus(browser)
    settle(h)
    #expect(h.system.windowsFrontToBack().prefix(3) == [browser, call, timer], "the order the person's own acts made")
    #expect(h.system.raiseLog.isEmpty)
    h.system.userFocus(timer)
    settle(h)
    #expect(h.system.windowsFrontToBack().first == timer, "the other pinned window is not raised over it")
  }

  @Test func whileAPinnedWindowHasTheKeyboardNothingIsRaisedOverIt() {
    let (h, _, browser, call) = makeHarness()
    let timer = h.system.open(app: "Timer", frame: CGRect(x: 1200, y: 100, width: 200, height: 100))
    h.run("pin \(timer.rawValue)")
    h.system.userFocus(timer)
    settle(h)
    h.system.clearRaiseLog()
    // The browser is clicked and covers both. Before Arbor looks, the call is: it lies over the timer.
    h.system.userFocus(browser)
    h.system.userFocus(call)
    #expect(h.system.windowsFrontToBack().prefix(3) == [call, browser, timer])
    settle(h)
    #expect(h.system.raiseLog.isEmpty, "the timer is covered, but raising it would cover the window being used")
    #expect(h.system.windowsFrontToBack().first == call)
  }

  @Test func anAppReportingItsRaisedWindowAsFocusedDoesNotStartALoop() {
    // Two pinned windows of one app: raising either makes the app report a new focused window.
    let (h, editor, _, call) = makeHarness()
    let chat = h.system.open(app: "Zoom", title: "Chat", pid: 1003, frame: CGRect(x: 1090, y: 320, width: 320, height: 200))
    h.run("pin \(chat.rawValue)")
    h.system.userFocus(editor)
    settle(h)
    h.system.clearRaiseLog()
    for window in [call, chat] { h.controller.windowFocused(window) }
    #expect(nobodyIsLooking(h))
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func draggingAGapDoesNotMakeArborLookWithEveryMove() {
    let (h, _, _, _) = makeHarness()
    h.system.clearRaiseLog()
    h.system.mouseDown = true
    for _ in 0..<5 {
      h.overlays.dragSeam(h.layout!.seams[0], by: 4)
      #expect(nobodyIsLooking(h))
    }
    h.system.mouseDown = false
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func withNothingPinnedNothingIsRaised() {
    let (h, editor, browser, call) = makeHarness()
    h.run("unpin \(call.rawValue)")
    settle(h)
    h.system.clearRaiseLog()
    h.run("zoom \(editor.rawValue)")
    h.system.userFocus(browser)
    #expect(nobodyIsLooking(h))
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
  }

  // MARK: 3. Docking and pinning

  @Test func dockingUnpins() {
    let (h, _, _, call) = makeHarness()
    #expect(h.run("dock \(call.rawValue) left").message.hasPrefix("docked \(call) at the left edge and it is no longer kept in view"))
    #expect(h.workspace.isDocked(call))
    #expect(!h.controller.isPinned(call))
    #expect(h.workspace.pinned == nil)
    // Floating it again does not bring the pin back.
    h.run("float \(call.rawValue)")
    #expect(!h.controller.isPinned(call))
  }

  @Test func toggleFloatAndDockBesideUnpinToo() {
    let (h, editor, _, call) = makeHarness()
    #expect(h.run("toggle-float \(call.rawValue)").message.contains("and it is no longer kept in view"))
    #expect(h.workspace.isDocked(call) && !h.controller.isPinned(call))
    h.run("pin \(call.rawValue)")
    #expect(h.controller.isPinned(call))
    #expect(h.run("dock \(call.rawValue) beside \(editor.rawValue) bottom").message.contains("and it is no longer kept in view"))
    #expect(!h.run("dock \(call.rawValue) right").message.contains("kept in view"), "said once, when it happens")
    #expect(h.workspace.isDocked(call) && !h.controller.isPinned(call))
  }

  @Test func pinningADockedWindowFloatsItAndItsSlotCloses() {
    let (h, editor, browser, _) = makeHarness()
    let slot = h.frame(browser)!
    #expect(h.run("pin \(browser.rawValue)").ok)
    #expect(h.workspace.isFloating(browser) && h.controller.isPinned(browser))
    // As `float` has it: the size it floated at before it was docked (F48), centred on its slot, kept on the display.
    let frame = h.frame(browser)!
    #expect(
      frame
        == CGRect(x: (slot.midX - 320).rounded(), y: (slot.midY - 210).rounded(), width: 640, height: 420)
        .fitted(into: h.visibleFrame))
    #expect(h.workspace.floating[browser] == frame)
    #expect(h.workspace.tree.allWindows == [editor])
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(browser) == frame)
  }

  /// [a | Desktop | b] with a terminal 900 points wide on a Desktop that is narrower, so Arbor has squeezed it.
  func makeHarnessWithASqueezedWindow() -> (Harness, a: WindowID, terminal: WindowID, own: CGSize) {
    let h = Harness()
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002)
    let terminal = h.system.open(app: "Term", pid: 1003, frame: CGRect(x: 200, y: 200, width: 900, height: 400))
    h.start()
    #expect(h.run("dock \(a.rawValue) left").ok && h.run("dock \(b.rawValue) right").ok)
    settle(h)
    return (h, a, terminal, CGSize(width: 900, height: 400))
  }

  @Test func aWindowTheDesktopSqueezedIsItsOwnSizeOncePinned() {
    // It no longer lives on the Desktop, so it need not fit there.
    let (h, a, terminal, own) = makeHarnessWithASqueezedWindow()
    #expect(h.frame(terminal)!.width < own.width)
    h.run("pin \(terminal.rawValue)")
    settle(h)
    #expect(h.frame(terminal)!.size == own)
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(h.frame(terminal)!))
    let pinned = h.frame(terminal)!
    #expect(h.workspace.floating[terminal] == pinned)
    #expect(h.run("zoom \(a.rawValue)").ok)
    h.run("show-all")
    settle(h)
    #expect(h.frame(terminal) == pinned)
    // Nor does what sends floating windows back to where the user left them move it.
    h.run("float-all")
    #expect(h.frame(terminal) == pinned)
    h.controller.shutdown()
    #expect(h.frame(terminal) == pinned)
  }

  @Test func itGrowsToItsOwnSizeAsAMotionNotAJump() throws {
    let (h, _, terminal, own) = makeHarnessWithASqueezedWindow()
    let squeezed = h.frame(terminal)!
    h.overlays.clearTransitions()
    let moved = h.system.frameLog.count
    var movedByThen: Int?
    h.overlays.onAnimate = { _ in movedByThen = movedByThen ?? h.system.frameLog.count }
    h.run("pin \(terminal.rawValue)")
    #expect(movedByThen == moved, "the stage is up before the window moves")
    let item = try #require(h.overlays.transitions.first?[terminal])
    #expect(item.from == squeezed && item.to == h.frame(terminal) && item.to.size == own)
    #expect(h.system.frameLog.dropFirst(moved).filter { $0.window == terminal }.count == 1, "and it is moved once")
  }

  @Test func squeezedInHeightItIsItsOwnSizeOncePinnedToo() {
    let h = Harness()
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002)
    let notes = h.system.open(app: "Notes", pid: 1003, frame: CGRect(x: 500, y: 60, width: 400, height: 760))
    h.start()
    #expect(h.run("dock \(a.rawValue) top").ok && h.run("dock \(b.rawValue) bottom").ok)
    settle(h)
    #expect(h.frame(notes)!.height < 760 && h.frame(notes)!.width == 400)
    h.run("pin \(notes.rawValue)")
    settle(h)
    #expect(h.frame(notes)!.size == CGSize(width: 400, height: 760))
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(h.frame(notes)!))
  }

  @Test func squeezedAtTheEdgeOfTheScreenItGrowsInward() {
    // [a | b | Desktop]: around where it is would be half off the screen.
    let h = Harness()
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002)
    let terminal = h.system.open(app: "Term", pid: 1003, frame: CGRect(x: 500, y: 200, width: 900, height: 400))
    h.start()
    #expect(h.run("dock \(a.rawValue) left").ok && h.run("dock \(b.rawValue) beside \(a.rawValue) right").ok)
    settle(h)
    let squeezed = h.frame(terminal)!
    let visible = FakeWindowSystem.standardDisplay.visibleFrame
    #expect(squeezed.width < 900 && squeezed.midX + 450 > visible.maxX)
    h.run("pin \(terminal.rawValue)")
    settle(h)
    #expect(h.frame(terminal)!.size == CGSize(width: 900, height: 400))
    #expect(visible.contains(h.frame(terminal)!))
  }

  @Test func pinningASqueezedWindowDoesNotCostItItsSize() {
    let (h, _, terminal, own) = makeHarnessWithASqueezedWindow()
    h.run("pin \(terminal.rawValue)")
    h.run("unpin \(terminal.rawValue)")
    h.run("float-all")
    settle(h)
    #expect(h.frame(terminal)!.size == own)
  }

  @Test func pinnedWhileOutOfViewASqueezedWindowComesAtItsOwnSize() {
    let (h, a, terminal, own) = makeHarnessWithASqueezedWindow()
    #expect(h.run("zoom \(a.rawValue)").ok)
    settle(h)
    #expect(h.controller.parked.contains(terminal))
    h.run("pin \(terminal.rawValue)")
    settle(h)
    #expect(h.frame(terminal)!.size == own)
    #expect(!h.controller.parked.contains(terminal))
  }

  @Test func pinningAFramedWindowDoesNotCoverTheView() {
    let (h, editor, _, _) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    #expect(h.run("pin \(editor.rawValue)").ok)
    // Its own size again (F48), in the middle of what it filled.
    let frame = h.frame(editor)!
    #expect(frame.size == CGSize(width: 640, height: 420))
    #expect(abs(frame.midX - beside.midX) <= 0.5 && abs(frame.midY - beside.midY) <= 0.5)
    #expect(h.workspace.floating[editor] == frame)
  }

  /// Its own size can be most of the display too. It used to be halved then, so as not to hide what it accompanies, and no way
  /// home gave the size back. Arbor picks no size for a floating window (QUESTIONS Q20): one drag of its corner makes it smaller.
  @Test func pinningADockedWindowWhoseOwnSizeIsMostOfTheDisplayKeepsThatSize() {
    let (h, _, _, _) = makeHarness()
    let large = h.system.open(app: "Keynote", pid: 1004, frame: CGRect(x: 40, y: 40, width: 1300, height: 820))
    h.run("dock \(large.rawValue) right")
    h.run("zoom \(large.rawValue)")
    #expect(h.run("pin \(large.rawValue)").ok)
    let frame = h.frame(large)!
    #expect(frame.size == CGSize(width: 1300, height: 820))
    #expect(h.visibleFrame.contains(frame))
    #expect(h.workspace.floating[large] == frame)
  }

  @Test func pinningADockedWindowThatIsOutOfViewBringsItIntoView() {
    let (h, editor, browser, _) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    #expect(!h.system.isVisible(browser))
    #expect(h.run("pin \(browser.rawValue)").ok)
    #expect(h.frame(browser)!.fractionInside(h.visibleFrame) > 0.99)
    #expect(!h.controller.parked.contains(browser))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor))
  }

  @Test func draggingAPinnedWindowMovesItAndNeverDocksIt() {
    let (h, editor, _, call) = makeHarness()
    // Over the left edge of the editor, then the left edge of the screen: both dock any other window.
    for point in [CGPoint(x: 60, y: 400), CGPoint(x: 2, y: 400)] {
      h.system.drag(call, through: [corner.center, CGPoint(x: 700, y: 300), point])
      #expect(h.workspace.isFloating(call) && h.controller.isPinned(call))
      #expect(h.workspace.floating[call] == h.frame(call), "where it was dropped is where it stays")
    }
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil }, "no preview promises a dock")
    let dropped = h.frame(call)!
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(call) == dropped)
  }

  @Test func pinningAndUnpinningMoveNoFloatingWindow() {
    // The docked ones make room and take it back (KeepInViewMakesRoomTests).
    let (h, _, _, call) = makeHarness()
    // Half on the Desktop, half over the browser, like the call; put there by hand since the last layout.
    let notes = h.system.open(app: "Notes")
    let straddling = CGRect(x: 800, y: 400, width: 300, height: 200)
    h.system.userMove(notes, to: straddling)
    h.system.userMove(call, to: straddling.offsetBy(dx: 0, dy: -250))
    h.system.clearFrameLog()
    h.run("unpin \(call.rawValue)")
    h.run("pin \(call.rawValue)")
    h.run("toggle-pin \(call.rawValue)")
    #expect(moves(of: call, h).isEmpty && moves(of: notes, h).isEmpty)
  }

  @Test func unpinningLeavesItWhereItIsUntilTheCameraNextMoves() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    #expect(h.run("unpin \(call.rawValue)").ok)
    #expect(h.frame(call) == corner, "nothing jumps")
    #expect(h.workspace.isFloating(call) && !h.controller.isPinned(call))
    h.run("neighbor right")
    h.run("neighbor right")
    #expect(!h.system.isVisible(call), "it lives on the Desktop again")
  }

  @Test func togglePinGoesBothWaysAndActsOnTheFocusedWindow() {
    let (h, _, _, call) = makeHarness()
    h.system.userFocus(call)
    #expect(h.run("toggle-pin").message == "no longer keeping \(call) in view")
    #expect(!h.controller.isPinned(call))
    #expect(h.run("toggle-pin").message == "keeping \(call) in view")
    #expect(h.controller.isPinned(call))
  }

  @Test func commandsThatCannotWorkSayWhy() {
    let (h, editor, _, call) = makeHarness()
    #expect(h.run("pin \(call.rawValue)").message == "\(call) is already kept in view")
    #expect(h.run("unpin \(editor.rawValue)").message == "\(editor) is not kept in view; `pin \(editor.rawValue)` does that")
    #expect(!h.run("pin 999").ok)
    #expect(!h.run("toggle-pin 999").ok)
    #expect(!h.run("pin left").ok)
    h.system.focused = nil
    #expect(!h.run("pin").ok)
    #expect(h.run("pin") == h.run("float"), "in the words every command for the focused window uses")
    h.run("pause")
    #expect(!h.run("pin \(editor.rawValue)").ok)
  }

  // MARK: 4. Rules

  @Test func thePinRuleAppliesToNewWindows() {
    var settings = Settings()
    settings.rules = [AppRule(app: "us.zoom.xos", title: "Meeting", action: .pin)]
    let (h, editor, _, _) = makeHarness(settings: settings)
    h.run("zoom \(editor.rawValue)")
    let frame = CGRect(x: 200, y: 200, width: 400, height: 300)
    let meeting = h.system.open(app: "Zoom", bundleID: "us.zoom.xos", title: "Zoom Meeting", frame: frame)
    let home = h.system.open(app: "Zoom", bundleID: "us.zoom.xos", title: "Zoom Workplace", frame: frame)
    #expect(h.controller.isPinned(meeting))
    #expect(!h.controller.isPinned(home), "the title does not match")
    h.run("neighbor right")
    h.run("neighbor right")
    #expect(h.frame(meeting) == frame)
    #expect(!h.system.isVisible(home))
  }

  @Test func aTitleThatArrivesLateStillPins() {
    // A meeting's window gets its title a moment after it opens.
    var settings = Settings()
    settings.rules = [
      AppRule(app: "us.zoom.xos", title: "Meeting", action: .pin), AppRule(app: "us.zoom.xos", action: .dock(.right)),
    ]
    let (h, editor, _, _) = makeHarness(settings: settings)
    let frame = CGRect(x: 200, y: 200, width: 400, height: 300)
    let meeting = h.system.open(app: "Zoom", bundleID: "us.zoom.xos", title: "Zoom", frame: frame)
    #expect(h.workspace.isDocked(meeting), "the rule for the app's other windows, for now")
    h.system.setTitle(meeting, "Zoom Meeting")
    #expect(h.controller.isPinned(meeting))
    #expect(h.frame(meeting) == frame, "back where its app opened it")
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(meeting) == frame)
  }

  @Test func aLateTitleCanTakeThePinAwayAgain() {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "us.zoom.xos", title: "Settings", action: .float), AppRule(app: "us.zoom.xos", action: .pin),
    ]
    let (h, _, _, _) = makeHarness(settings: settings)
    let window = h.system.open(app: "Zoom", bundleID: "us.zoom.xos", title: "Zoom")
    #expect(h.controller.isPinned(window))
    h.system.setTitle(window, "Settings")
    #expect(!h.controller.isPinned(window) && h.workspace.isFloating(window))
  }

  @Test func aBadActionIsReportedLikeOtherBadRules() throws {
    let json = #"{"rules": [{"app": "us.zoom.xos", "action": "pin"}, {"app": "com.apple.Music", "action": "pin left"}]}"#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(settings.rules == [AppRule(app: "us.zoom.xos", action: .pin)])
    let h = Harness(settings: settings)
    h.start()
    let report = h.run("rules").text ?? ""
    #expect(report.contains("1. us.zoom.xos → pin"))
    #expect(report.contains("entry 2 (com.apple.Music): unknown action `pin left`"))
  }

  // MARK: 5. Restarts

  @Test func pinsSurviveARestart() {
    let (old, editor, _, call) = makeHarness()
    old.run("zoom \(editor.rawValue)")
    old.controller.shutdown()
    #expect(old.frame(call) == corner, "quitting leaves it exactly where it is")

    let h = relaunch(old)
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(call) == corner)
    #expect(moves(of: call, h).isEmpty)
  }

  @Test func aPinnedWindowWhoseAppRestartedIsFoundAgainByAppAndTitle() {
    let (old, editor, browser, call) = makeHarness()
    old.controller.shutdown()

    let h = Harness(saved: old.store.saved)
    for window in old.system.allWindows() where window.id != call {
      h.system.open(app: window.appName, title: window.title, pid: window.pid, frame: window.frame)
    }
    // The call's number now belongs to nothing; its app opened these since.
    _ = h.system.open(app: "Filler")
    let other = h.system.open(app: "Zoom", title: "Settings", frame: CGRect(x: 300, y: 300, width: 300, height: 300))
    let moved = CGRect(x: 100, y: 500, width: 320, height: 240)
    let again = h.system.open(app: "Zoom", title: "Meeting", frame: moved)
    h.start()
    #expect([editor, browser].allSatisfy { h.workspace.isDocked($0) })
    #expect(h.controller.isPinned(again))
    #expect(!h.controller.isPinned(other))
    #expect(h.frame(again) == moved, "starting Arbor does not move what is on screen")
    #expect(h.workspace.pinnedWindows == [again])
  }

  @Test func aStateFileFromBeforePinsLoadsAndTheNewOneRoundTrips() throws {
    let (h, _, _, call) = makeHarness()
    h.controller.saveNow()
    let saved = try #require(h.store.saved)
    let data = try JSONEncoder().encode(saved)
    #expect(try JSONDecoder().decode(PersistedState.self, from: data) == saved)

    // The same file as an older Arbor wrote it: no `pinned` key anywhere.
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var workspaces = try #require(object["workspaces"] as? [String: [String: Any]])
    for key in workspaces.keys { #expect(workspaces[key]?.removeValue(forKey: "pinned") != nil) }
    object["workspaces"] = workspaces
    let old = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.workspaces[h.display]?.pinned == nil)
    #expect(old.workspaces[h.display]?.isFloating(call) == true)
    #expect(old.workspaces[h.display]?.tree == saved.workspaces[h.display]?.tree)
  }

  // MARK: Two displays

  @Test func eachDisplaysCameraLeavesThePinnedWindowsOfBothAlone() {
    let (h, editor, _, call) = makeHarness(displays: [main, side])
    let there = CGRect(x: 2300, y: 40, width: 300, height: 200)
    let timer = h.system.open(app: "Timer", frame: there)
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.run("pin \(timer.rawValue)")
    #expect(h.controller.workspaces[side.id]!.isPinned(timer))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(mail.rawValue) left")
    h.run("zoom \(mail.rawValue)")
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("zoom \(editor.rawValue)")
    h.run("home")
    #expect(h.frame(timer) == there && h.frame(call) == corner)
    #expect(h.controller.parked.isDisjoint(with: [timer, call]))
  }

  @Test func thePinFollowsAWindowMovedToAnotherDisplay() {
    let (h, editor, _, call) = makeHarness(displays: [main, side])
    let there = CGRect(x: 2300, y: 40, width: 320, height: 240)
    h.system.userMove(call, to: there)
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.controller.workspaces[main.id]!.pinned == nil)

    // And back, this time dragged by its title bar.
    h.system.drag(call, through: [there.center, CGPoint(x: 1500, y: 300), CGPoint(x: 1200, y: 200)])
    #expect(h.controller.workspaces[main.id]!.isPinned(call))
    #expect(h.controller.workspaces[side.id]!.pinned == nil)
    let dropped = h.frame(call)!
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(call) == dropped)
  }

  // MARK: A display is unplugged

  /// The call pinned on the side display, and the main display framed on the editor.
  func makeHarnessWithTheCallOnTheSideDisplay() -> (Harness, editor: WindowID, call: WindowID, there: CGRect) {
    let (h, editor, _, call) = makeHarness(displays: [main, side])
    let there = CGRect(x: 2300, y: 40, width: 320, height: 240)
    h.system.userMove(call, to: there)
    h.run("zoom \(editor.rawValue)")
    return (h, editor, call, there)
  }

  @Test func whenItsDisplayIsUnpluggedItComesIntoViewOnTheMainOneAndGoesBackAfterwards() {
    let (h, editor, call, there) = makeHarnessWithTheCallOnTheSideDisplay()
    h.system.clearFrameLog()
    h.system.setDisplays([main])
    #expect(h.controller.workspaces[main.id]!.isPinned(call))
    #expect(h.frame(call)!.fractionInside(main.visibleFrame) > 0.99, "though the Desktop is not in view there")
    #expect(!h.controller.parked.contains(call))
    #expect(moves(of: call, h).count == 1, "straight there, not by way of the corner")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor))
    let here = h.frame(call)!
    h.run("neighbor right")
    #expect(h.frame(call) == here)

    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.controller.workspaces[main.id]!.pinned == nil)
    #expect(h.frame(call) == there, "exactly where it was")
  }

  @Test func movedByMacOSBeforeTheUnplugWasReportedItStillGoesBackPinned() {
    let (h, _, call, there) = makeHarnessWithTheCallOnTheSideDisplay()
    // The display is gone and macOS has moved its windows; Arbor hears once the displays have settled.
    h.system.displayList = [main]
    h.system.userMove(call, to: CGRect(x: 1000, y: 40, width: 320, height: 240))
    #expect(h.controller.workspaces[side.id]!.isPinned(call), "not the user's doing")
    h.system.setDisplays([main])
    #expect(h.controller.workspaces[main.id]!.isPinned(call))
    #expect(h.frame(call)!.fractionInside(main.visibleFrame) > 0.99)

    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.controller.workspaces[main.id]!.pinned == nil)
    #expect(h.frame(call) == there, "exactly where it was")
  }

  @Test func unpinnedWhileItsDisplayWasAwayItStaysUnpinned() {
    let (h, _, call, _) = makeHarnessWithTheCallOnTheSideDisplay()
    h.system.setDisplays([main])
    h.run("unpin \(call.rawValue)")
    h.system.setDisplays([main, side])
    #expect(!h.controller.isPinned(call))
    #expect(h.controller.workspaces[side.id]!.isFloating(call))
  }

  @Test func dockedAndFloatedAgainWhileItsDisplayWasAwayItStaysUnpinned() {
    let (h, _, call, _) = makeHarnessWithTheCallOnTheSideDisplay()
    h.system.setDisplays([main])
    h.run("show-all")
    h.run("dock \(call.rawValue) bottom")
    h.run("float \(call.rawValue)")
    h.system.setDisplays([main, side])
    #expect(!h.controller.isPinned(call))
  }

  @Test func aMomentWithoutAnyDisplayDoesNotCostThePin() {
    // Sleep, or a dock being unplugged: macOS can report no display at all for a moment.
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.setDisplays([])
    h.system.setDisplays([main])
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    #expect(!h.controller.parked.contains(call))

    // And when a different display is the first to appear.
    h.system.setDisplays([])
    h.system.userMove(call, to: CGRect(x: 1500, y: 40, width: 320, height: 240))
    h.system.setDisplays([side])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.system.isVisible(call))
  }

  @Test func pinnedWhileItsDisplayWasAwayItStaysWhereItWasPinned() {
    let (h, _, _, _) = makeHarness(displays: [main, side])
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(mail.rawValue) left")
    h.system.setDisplays([main])
    h.run("pin \(mail.rawValue)")
    let here = h.frame(mail)!
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[main.id]!.isPinned(mail))
    #expect(h.frame(mail) == here)
    #expect(h.controller.workspaces[side.id]!.tree.allWindows.isEmpty)
  }

  @Test func launchedWithoutTheDisplayItWasPinnedOnItIsStillPinned() {
    let (old, _, call, there) = makeHarnessWithTheCallOnTheSideDisplay()
    old.controller.shutdown()
    // macOS moves the windows of a display that goes away onto the ones that remain.
    old.system.userMove(call, to: corner)

    let h = relaunch(old, displays: [main])
    #expect(h.controller.workspaces[main.id]!.isPinned(call))
    #expect(h.frame(call) == corner)
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isPinned(call))
    #expect(h.frame(call) == there)
  }

  @Test func whenTheDisplayShrinksUnderItItIsBroughtBackIntoView() {
    let (h, _, _, call) = makeHarness()
    let small = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)
    h.system.setDisplays([small])
    #expect(h.frame(call)!.fractionInside(small.visibleFrame) > 0.99)
    #expect(h.frame(call)!.size == corner.size)
    #expect(h.controller.isPinned(call))
  }

  // MARK: Minimized, hidden, closed, no longer arranged

  @Test func minimizedItIsLeftAloneAndComesBackPinnedWhereItWas() {
    let (h, editor, _, call) = makeHarness()
    h.system.setMinimized(call, true)
    settle(h)
    h.system.clearRaiseLog()
    h.run("zoom \(editor.rawValue)")
    h.run("show-all")
    settle(h)
    #expect(h.system.raiseLog.isEmpty, "raising a minimized window would bring it out of the Dock")
    #expect(moves(of: call, h).isEmpty)
    #expect(!h.controller.parked.contains(call))

    h.run("zoom \(editor.rawValue)")
    h.system.setMinimized(call, false)
    settle(h)
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor))
    #expect(!isCovered(call, h))
  }

  @Test func whileItsAppIsHiddenItIsLeftAloneAndComesBackPinnedWhereItWas() {
    let (h, editor, _, call) = makeHarness()
    h.system.setHidden(pid: 1003, true)
    settle(h)
    h.system.clearRaiseLog()
    h.run("zoom \(editor.rawValue)")
    h.run("neighbor right")
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
    #expect(moves(of: call, h).isEmpty)

    h.system.setHidden(pid: 1003, false)
    settle(h)
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    #expect(!isCovered(call, h))
  }

  @Test func onAnotherMacOSSpaceItIsLeftAlone() {
    let (h, editor, _, call) = makeHarness()
    h.system.setOnActiveSpace(call, false)
    h.scheduler.runPending()
    h.system.clearRaiseLog()
    h.run("zoom \(editor.rawValue)")
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
    #expect(moves(of: call, h).isEmpty)
    #expect(h.controller.isPinned(call))
  }

  @Test func switchingTabsInAPinnedWindowKeepsThePin() {
    // macOS's own window tabs (Terminal, Finder): each tab is a window with a number of its own.
    let (h, editor, _, call) = makeHarness()
    let tab = try! #require(h.system.openTab(in: call))
    #expect(h.controller.isPinned(tab) && !h.controller.isPinned(call))
    #expect(h.workspace.pinnedWindows == [tab])
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(tab) == corner)
    h.system.selectTab(call, insteadOf: tab)
    #expect(h.controller.isPinned(call))
    h.run("show-all")
    #expect(h.frame(call) == corner)
  }

  @Test func pinningAWindowThatOpenedOverAFramedOneMakesItTheDisplaysNotThatSpaces() {
    let (h, editor, browser, _) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    let frame = CGRect(x: 300, y: 300, width: 300, height: 200)
    let palette = h.system.open(app: "Palette", pid: 1006, frame: frame)
    #expect(h.workspace.guests?[palette] != nil, "a guest of the editor")
    h.run("pin \(palette.rawValue)")
    #expect(h.workspace.guests == nil)
    h.run("zoom \(browser.rawValue)")
    #expect(h.frame(palette) == frame)
    // Unpinned, it is an ordinary floating window, not a guest again.
    h.run("unpin \(palette.rawValue)")
    h.run("zoom \(editor.rawValue)")
    #expect(!h.system.isVisible(palette))
  }

  @Test func closingItForgetsThePin() {
    let (h, editor, _, call) = makeHarness()
    h.system.close(call)
    #expect(h.workspace.pinned == nil)
    #expect(!h.controller.isPinned(call))
    h.system.clearRaiseLog()
    h.run("zoom \(editor.rawValue)")
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
    h.controller.saveNow()
    #expect(h.store.saved?.workspaces[h.display]?.pinned == nil)
  }

  @Test func closingItBeforeItIsRaisedIsHarmless() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.close(call)
    h.system.clearRaiseLog()
    settle(h)
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func excludingItsAppForgetsThePin() {
    let (h, _, _, call) = makeHarness()
    h.run("exclude com.example.zoom")
    #expect(h.workspace.pinned == nil)
    #expect(h.frame(call) == corner)
    h.run("include com.example.zoom")
    #expect(!h.controller.isPinned(call))
  }

  // MARK: Float all, arrange, pause, quit

  @Test func floatAllLeavesItExactlyWhereItIs() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    #expect(h.run("float-all").ok)
    #expect(h.frame(call) == corner)
    #expect(h.controller.isPinned(call))
    #expect(moves(of: call, h).isEmpty)
  }

  @Test func arrangeLeavesItOut() {
    let (h, editor, browser, call) = makeHarness()
    let notes = h.system.open(app: "Notes")
    #expect(h.run("arrange").message == "arranged 3 windows")
    #expect(Set(h.workspace.tree.allWindows) == [editor, browser, notes])
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    #expect(h.run("arrange all").ok)
    #expect(h.controller.isPinned(call) && h.frame(call) == corner)
  }

  @Test func withOnlyAPinnedWindowThereIsNothingToArrange() {
    let h = Harness()
    let call = h.system.open(app: "Zoom", frame: corner)
    h.start()
    h.run("pin \(call.rawValue)")
    #expect(!h.run("arrange").ok)
    #expect(h.controller.isPinned(call))
  }

  @Test func pausingLeavesItExactlyWhereItIsAndResumingRemembersThePin() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    settle(h)
    h.system.clearRaiseLog()
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 1)
    #expect(h.frame(call) == corner)
    #expect(moves(of: call, h).isEmpty)
    h.system.userFocus(editor)
    settle(h)
    #expect(h.system.raiseLog.isEmpty, "a paused Arbor raises nothing")

    #expect(h.run("resume").ok)
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == corner)
    h.run("show-all")
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(call) == corner)
  }

  @Test func movedDuringAPauseItStaysWhereItWasPut() {
    let (h, editor, _, call) = makeHarness()
    h.run("pause")
    let elsewhere = CGRect(x: 40, y: 600, width: 320, height: 240)
    h.system.userMove(call, to: elsewhere)
    h.run("resume")
    h.run("zoom \(editor.rawValue)")
    #expect(h.controller.isPinned(call))
    #expect(h.frame(call) == elsewhere)
  }

  // MARK: What scripts and people see

  @Test func stateAndTheDrawingShowThePin() {
    let (h, editor, _, call) = makeHarness()
    let state = h.run("state").state
    #expect(state?.window(call)?.pinned == true)
    #expect(state?.window(editor)?.pinned == false)
    #expect(state?.window(call)?.parked == false)
    #expect(h.ascii().contains("\(call) pinned"))
    #expect(h.run("status").message.contains("2 docked and 1 floating (1 kept in view)"))
    h.run("unpin \(call.rawValue)")
    #expect(h.run("status").message.contains("2 docked and 1 floating, "))
  }

  @Test func aURLCanPinAndUnpin() {
    let (h, _, _, call) = makeHarness()
    #expect(h.controller.admit(url: "arbor://unpin/\(call.rawValue)") == .success(.unpin(call)))
    #expect(h.controller.admit(url: "arbor://pin") == .success(.pin(nil)))
    #expect(h.controller.admit(url: "arbor://toggle-pin/\(call.rawValue)") == .success(.togglePin(call)))
  }
}

/// The `expect` forms that scenarios about pinned windows use (collab/README.md, "Scenarios").
@Suite @MainActor struct PinExpectationTests {
  func expect(_ line: String, _ h: Harness) -> String? {
    ScenarioExpectation.check(line.split(separator: " ").map(String.init), harness: h, lastCommandOK: true)
  }

  @Test func pinnedAndInFront() {
    let h = Harness()
    let a = h.system.open(app: "Editor")
    let b = h.system.open(app: "Zoom")
    h.start()
    #expect(expect("pinned \(b.rawValue)", h) == "\(b) is not pinned")
    #expect(expect("pinned 999", h) == "there is no window w999")
    #expect(expect("pinned", h)?.hasPrefix("cannot read `pinned`") == true)
    h.run("pin \(b.rawValue)")
    #expect(expect("pinned \(b.rawValue)", h) == nil)

    h.system.userFocus(a)
    #expect(expect("in-front \(a.rawValue)", h) == nil)
    #expect(expect("in-front \(b.rawValue)", h) == "\(a) covers \(b)")
    #expect(expect("in-front 999", h) == "there is no window w999")
    h.scheduler.advance(by: 1)
    #expect(expect("in-front \(b.rawValue)", h) == "\(a) covers \(b)", "Arbor does not fight for the front")
    #expect(expect("covered \(b.rawValue) yes", h) == nil)
    #expect(expect("covered \(b.rawValue) no", h) == "`state` says that \(b) is covered")
    #expect(expect("covered \(a.rawValue) yes", h) == "`state` does not say that \(a) is covered")
    #expect(expect("covered 999 no", h) == "there is no window w999")
    #expect(expect("covered \(b.rawValue)", h)?.hasPrefix("cannot read `covered") == true)
  }

  @Test func clearOfDockedWindows() {
    let h = Harness()
    let a = h.system.open(app: "Editor")
    let b = h.system.open(app: "Zoom", frame: corner)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(expect("clear 999", h) == "there is no window w999")
    _ = h.system.setFrame(corner, of: b)
    #expect(expect("clear \(b.rawValue)", h)?.hasSuffix("overlap") == true)
    h.run("pin \(b.rawValue)")
    #expect(expect("clear \(b.rawValue)", h) == nil)
    #expect(expect("fills \(a.rawValue)", h) == nil, "all that is left")
  }
}
