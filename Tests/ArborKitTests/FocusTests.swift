import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Who has the keyboard and what the camera does about it: ⌘Tab, closing, minimizing, apps that
/// change focus behind the user's back.
@Suite @MainActor struct FocusTests {
  /// `[a / c | Desktop | b]`, each window in its own app.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    return (h, a, b, c)
  }

  func leaf(_ h: Harness, _ window: WindowID) -> NodeID? { h.workspace.tree.leaf(containing: window) }

  @Test func aBackgroundAppChangingItsFocusedWindowDoesNotMoveTheCamera() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.backgroundFocus(b)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == leaf(h, a), "the keyboard is still in Safari, so the view stays on it")
    #expect(h.system.focused == a)
  }

  @Test func aFocusChangeReportedBeforeTheAppIsFrontmostStillRevealsTheWindow() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    // ⌘Tab: the focus report can arrive a moment before macOS says which app is frontmost.
    h.controller.windowFocused(b)
    #expect(h.workspace.camera == leaf(h, a))
    h.system.focused = b
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(b))
    #expect(h.layout?.windowFrames[b] != nil)
  }

  @Test func unminimizingAWindowInViewDoesNotZoomOntoIt() {
    let (h, a, _, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.setMinimized(a, true)
    // Clicking it in the Dock: it gets the keyboard while it is still flying out of the Dock.
    h.system.userFocus(a)
    h.system.setMinimized(a, false)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.frame(a) == slot)
  }

  @Test func unminimizingAWindowOutOfViewRevealsItWhicheverReportComesFirst() {
    for focusFirst in [true, false] {
      let (h, a, b, _) = makeHarness()
      h.system.setMinimized(a, true)
      h.run("zoom \(b.rawValue)")
      if focusFirst { h.system.userFocus(a) }
      h.system.setMinimized(a, false)
      if !focusFirst { h.system.userFocus(a) }
      h.scheduler.advance(by: 1)
      #expect(h.layout?.windowFrames[a] != nil, "focus first: \(focusFirst)")
      #expect(h.system.isVisible(a), "focus first: \(focusFirst)")
    }
  }

  @Test func switchingToAWindowOnAnotherSpaceRevealsItOnceItsSpaceShows() {
    let (h, a, b, c) = makeHarness()
    h.system.setOnActiveSpace(a, false)
    h.scheduler.runPending()
    h.run("zoom \(b.rawValue)")
    // ⌘Tab to Safari: it gets the keyboard, macOS slides to its Space, the windows are listed again.
    h.system.userFocus(a)
    h.system.setOnActiveSpace(b, false)
    h.system.setOnActiveSpace(c, false)
    h.system.setOnActiveSpace(a, true)
    h.scheduler.advance(by: 1)
    #expect(h.layout?.windowFrames[a] != nil)
    #expect(h.system.isVisible(a))
  }

  @Test func afterTheFramedWindowClosesTheViewStillFollowsTheKeyboard() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(c.rawValue)")
    h.system.close(c)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "what closes over its place")
    // A moment later the user switches to Notes. The view was on one window, and it is again.
    h.scheduler.advance(by: 1)
    h.system.userFocus(b)
    #expect(h.layout?.windowFrames[b] != nil)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
  }

  /// `[a / c | Desktop | b / a2]`, where `a2` is a second Safari window, with the view on the left column
  /// and the keyboard in `a`.
  func columnInView() -> (Harness, a: WindowID, a2: WindowID, b: WindowID, c: WindowID) {
    let (h, a, b, c) = makeHarness()
    let a2 = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.run("dock \(a2.rawValue) beside \(b.rawValue) bottom")
    h.system.userFocus(b)
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b))
    return (h, a, a2, b, c)
  }

  @Test func theViewDoesNotChaseAKeyboardTheUserDidNotMove() {
    // The window with the keyboard goes away, and macOS hands the keyboard to a window that is out of view: the
    // app's next window after a close or a minimize, the app used before after a hide. Nobody asked to see that
    // window. The view stays, and a window in view gets the keyboard.
    let losses: [(String, (Harness, WindowID) -> Void)] = [
      ("close", { h, window in h.system.close(window) }),
      ("minimize", { h, window in h.system.setMinimized(window, true) }),
      ("hide", { h, _ in h.system.setHidden(pid: 11, true) }),
    ]
    for (name, lose) in losses {
      let (h, a, a2, b, c) = columnInView()
      lose(h, a)
      h.scheduler.advance(by: 2)
      #expect(h.system.focused == c, "\(name): \(String(describing: h.system.focused)) has the keyboard")
      #expect(h.layout?.windowFrames[c] != nil, "\(name)")
      #expect(!h.system.isVisible(b), "\(name): the view moved")
      #expect(name == "hide" || !h.system.isVisible(a2), "\(name): the view moved")
      #expect(h.layout?.windowFrames.count == 1, "\(name): \(h.ascii())")
    }
  }

  @Test func theSameHoldsWhenTheLossIsReportedBeforeTheNewFocus() {
    let (h, a, a2, _, c) = columnInView()
    h.system.echoes.keyboard = false
    h.system.close(a)
    h.system.userFocus(a2)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == c)
    #expect(!h.system.isVisible(a2))
  }

  @Test func andWhenNothingReportsTheNewFocusAtAll() {
    let (h, a, a2, _, c) = columnInView()
    h.system.echoes.keyboard = false
    h.system.close(a)
    h.system.focused = a2
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == c)
    #expect(!h.system.isVisible(a2))
  }

  @Test func backAfterSuchALossDoesNotGoToAViewNobodySaw() {
    let (h, a, _, _, _) = columnInView()
    let history = h.workspace.back.count
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.forward.isEmpty)
    #expect(h.workspace.back.count <= history)
  }

  @Test func withNothingLeftInViewTheViewFollowsTheKeyboard() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("desktop")
    h.system.userFocus(f)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    h.scheduler.advance(by: 2)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a)
    #expect(h.system.isVisible(a), "typing into a window out of view is worse than a view that moves")
  }

  @Test func aRealSwitchToAnotherAppInThatVeryMomentStillWins() {
    // After a close or a minimize macOS picks a window of the SAME app, or none. Another app's window taking the
    // keyboard is the user's ⌘Tab or click in the Dock, however soon it comes.
    for minimize in [false, true] {
      let (h, a, _, b, _) = columnInView()
      h.system.echoes.keyboard = false
      if minimize { h.system.setMinimized(a, true) } else { h.system.close(a) }
      h.system.userFocus(b)
      #expect(h.system.focused == b)
      #expect(h.system.isVisible(b), "minimize: \(minimize)")
      h.scheduler.advance(by: 2)
      #expect(h.system.focused == b && h.system.isVisible(b))
    }
  }

  @Test func switchingAppsJustBeforeTheOldWindowClosesIsNotTakenBack() {
    let (h, a, _, b, _) = columnInView()
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == b && h.system.isVisible(b))
  }

  @Test func closingTheFramedWindowEndsOnAViewWithAFocusedWindowInIt() {
    let (h, a, a2, _, c) = columnInView()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2)
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == c, "\(String(describing: h.system.focused))")
    #expect(h.layout?.windowFrames[c] != nil)
    #expect(!h.system.isVisible(a2))
  }

  @Test func switchingToAWindowOutOfViewSoonAfterALossIsStillFollowed() {
    let (h, a, _, b, _) = columnInView()
    h.system.close(a)
    h.scheduler.advance(by: 1)
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
  }

  @Test func losingAWindowThatDidNotHaveTheKeyboardMovesNothing() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.close(c)
    h.system.setMinimized(b, true)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == leaf(h, a))
  }

  @Test func arborsOwnFocusChangesSettleAtOnce() {
    let (h, a, b, c) = makeHarness()
    h.system.userFocus(b)
    for command in ["zoom \(a.rawValue)", "back", "neighbor right", "desktop", "show-all", "zoom \(c.rawValue)", "out"] {
      let camera = { h.workspace.camera }
      h.controller.perform(try! Command.parse(command))
      let after = camera()
      #expect(h.system.reportFocus() <= 1, "\(command)")
      #expect(camera() == after, "\(command): hearing about its own focus change must not move the camera")
    }
  }

  @Test func lateReportsOfArborsOwnFocusChangesDoNotMoveTheView() {
    // Two commands in quick succession: the report of the first one's focus change arrives after the second.
    let (h, a, b, c) = makeHarness()
    h.system.userFocus(b)
    h.controller.perform(.zoom(c))
    h.controller.perform(.zoom(a))
    h.controller.perform(.showAll)
    #expect(h.system.deliverEchoes() == 2)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.focused == a)
  }

  @Test func dockingAWindowThatBecomesATileDoesNotZoomOntoIt() {
    for focusedFirst in [true, false] {
      let (h, _, b, _) = makeHarness()
      let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
      // More than the display has. With less, the window with the keyboard would be served at its neighbours' cost (F61).
      h.system.setMinimumSize(big, CGSize(width: 1500, height: 600))
      if focusedFirst { h.system.userFocus(big) }
      h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
      #expect(h.workspace.camera == h.workspace.tree.root, "focused first: \(focusedFirst)")
      #expect(h.layout?.tiles.map(\.windows) == [[big]], "focused first: \(focusedFirst)")
    }
  }

  @Test func hidingAnAppLaysItsDisplayOutOnce() {
    // `[s1 | s2 | n | Desktop]`: two Safari windows and Notes.
    let h = Harness()
    let s1 = h.system.open(app: "Safari", pid: 11)
    let s2 = h.system.open(app: "Safari", pid: 11)
    let n = h.system.open(app: "Notes", pid: 12)
    h.start()
    h.run("arrange")
    var layouts = 0
    h.controller.observe { if case .layout = $0 { layouts += 1 } }
    h.system.clearFrameLog()
    let mark = h.system.moveLog.count
    h.system.setHidden(pid: 11, true)
    #expect(layouts == 1)
    #expect(movesWithoutWaste(h, of: n, since: mark) == 1, "its neighbour moves once")
    #expect(!h.system.frameLog.contains { $0.window == s1 || $0.window == s2 }, "a window being hidden is not moved")
    layouts = 0
    h.system.clearFrameLog()
    h.system.setHidden(pid: 11, false)
    #expect(layouts == 1)
    #expect(h.system.frameLog.filter { $0.window == n }.count == 1)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func showingAHiddenAppThatHasTheKeyboardDoesNotZoomOntoItsWindow() {
    let (h, a, _, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.userFocus(a)
    h.system.setHidden(pid: 11, true)
    // ⌘Tab back to it: it has the keyboard by the time its windows are reported shown.
    h.system.focused = a
    h.system.setHidden(pid: 11, false)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.frame(a) == slot)
  }

  @Test func hidingTheFramedWindowsAppShowsItsSurroundingsAndUnhidingReturns() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setHidden(pid: 11, true)
    #expect(h.system.isVisible(c), "the view is never left empty")
    h.system.setHidden(pid: 11, false)
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(b))
  }

  /// What Arbor remembers of a view that followed the focus is only good until the user moves the view.
  @Test func aMoveOfTheViewByTheUserIsNeverTakenBack() {
    let (h, a, b, c) = threeApps()
    h.system.userFocus(b)  // the view follows, away from Safari, which had the focus
    h.run("show-all")
    h.run("zoom \(a.rawValue)")
    let history = h.workspace.back
    h.system.clearFrameLog()
    h.system.setHidden(pid: 11, true)
    #expect(h.workspace.back == history)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    // Taken back and made again, the move would end the same but bring windows in and send them out again.
    for window in [b, c] where !h.system.isVisible(window) {
      #expect(!h.system.frameLog.contains { $0.window == window }, "\(window) was out of view all along")
    }
  }

  /// macOS names the app's next window before it reports the minimize, so the view has followed already. Taking that
  /// back only to find nothing in view, and following again, would show as three motions.
  @Test func aViewThatWouldHaveToFollowAnywayIsNotTakenBackFirst() {
    // With a column for the Desktop: it shares what the small one leaves, and half the display is too narrow for the big one.
    // Without, the big one would have everything and be in view.
    let h = Harness(settings: .withDesktopColumn)
    let big = h.system.open(app: "Xcode", pid: 11, minimumSize: CGSize(width: 1000, height: 400))
    let small = h.system.open(app: "Xcode", pid: 11)
    h.start()
    h.run("set makeRoom off")  // or room is made for the big one (F61)
    h.run("dock \(big.rawValue) left")
    h.run("dock \(small.rawValue) right")
    h.run("zoom \(small.rawValue)")
    h.scheduler.advance(by: 2)
    var moves = 0
    h.controller.observe { if case .camera = $0 { moves += 1 } }
    h.system.setMinimized(small, true)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    #expect(h.system.focusedWindow() == big && h.system.isVisible(big))
    #expect(moves == 1, "the view moved \(moves) times")
  }

  // MARK: The level is kept

  /// `[Safari | Desktop | Slack]` over Mail, with Calculator floating; framed on Safari.
  func livingFramed() -> (Harness, safari: WindowID, slack: WindowID, mail: WindowID, calculator: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    let slack = h.system.open(app: "Slack", pid: 12)
    let mail = h.system.open(app: "Mail", pid: 13)
    let calculator = h.system.open(app: "Calculator", pid: 14, frame: CGRect(x: 600, y: 200, width: 240, height: 300))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(slack.rawValue) right")
    h.run("dock \(mail.rawValue) bottom")
    h.run("zoom \(safari.rawValue)")
    h.scheduler.advance(by: 1)
    return (h, safari, slack, mail, calculator)
  }

  /// ⌘Tab is the most pressed key on a Mac. Someone who lives framed must not lose the frame at the first one, nor
  /// show the neighbours on a shared screen.
  @Test func switchingFromAFramedWindowFramesTheOther() {
    let (h, safari, slack, mail, _) = livingFramed()
    h.system.userFocus(slack)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: slack))
    #expect(!h.system.isVisible(safari))
    h.system.userFocus(mail)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: mail))
    h.run("back")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: slack), "one step of history each")
    h.run("back")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: safari))
  }

  @Test func switchingFromAFramedWindowToAFloatingOneShowsTheDesktopAlone() {
    let (h, safari, _, _, calculator) = livingFramed()
    h.system.userFocus(calculator)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.isVisible(calculator) && !h.system.isVisible(safari))
    // And from there the level is still that of one space.
    h.system.userFocus(safari)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: safari))
  }

  @Test func fromAGroupOrEverythingTheViewStepsOutJustFarEnoughAsBefore() {
    let (h, safari, slack, mail, _) = livingFramed()
    h.run("out")
    let row = h.workspace.camera
    #expect(h.workspace.tree.subtree(row, contains: h.workspace.tree.leaf(containing: slack)!))
    h.system.userFocus(mail)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(safari) && h.system.isVisible(mail))
  }

  @Test func aWindowAlreadyInViewNeverMovesTheView() {
    let (h, _, slack, _, _) = livingFramed()
    h.run("out")
    let row = h.workspace.camera
    h.system.userFocus(slack)
    #expect(h.workspace.camera == row)
  }

  // MARK: Nothing has the focus

  /// `[a | b | c | Desktop]`, each window its app's only one, framed on `a`.
  func threeApps() -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12)
    let c = h.system.open(app: "Terminal", pid: 13)
    h.start()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    return (h, a, b, c)
  }

  /// The ways a window goes.
  nonisolated static let goings = ["close", "minimize", "hide", "quit"]

  func go(_ way: String, _ window: WindowID, _ h: Harness) {
    let pid = h.system.allWindows().first { $0.id == window }!.pid
    switch way {
    case "close": h.system.close(window)
    case "minimize": h.system.setMinimized(window, true)
    case "hide": h.system.setHidden(pid: pid, true)
    default: h.system.quit(pid: pid)
    }
  }

  /// After a person's own act macOS decides (`collab/QUESTIONS.md`, Q29; board 0.20). ⌘W or ⌘M on an app's only window: the app
  /// stays in front with its menu bar, as on a Mac alone. These two said "…EndsWithAFocusedWindowInView": Arbor handed
  /// the keyboard to the window used last, so that shortcuts had something to act on, and another app jumped forward.
  @Test(arguments: ["close", "minimize"]) func afterAnAppsLastWindowHasGoneNobodyIsHandedTheKeyboard(way: String) {
    let (h, a, _, _) = threeApps()
    h.run("show-all")
    h.system.userFocus(a)
    h.scheduler.advance(by: 1)
    let asked = h.system.focusLog.count
    go(way, a, h)
    h.scheduler.advance(by: 2)
    #expect(h.system.focusLog.dropFirst(asked).map(\.window) == [])
    #expect(h.system.focusedWindow().map { $0 == a } != false, "nobody, or the window in the Dock that its app still names")
    #expect(!h.run("float").ok, "a key that needs a window in front says that there is none")
    expectWindowsMatchLayout(h)
  }

  /// Whoever was typing on the second display is still looking there. The next key that names no display means that one, wherever
  /// the pointer was left. Once somebody has gone elsewhere, the pointer decides again.
  @Test func theNextKeyStillMeansTheDisplayWhereTheWindowWent() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1440, height: 875), isMain: false, isBuiltIn: false)
    func desk() -> (Harness, onSide: WindowID) {
      let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
      let a = h.system.open(app: "Safari", pid: 11)
      let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
      let c = h.system.open(app: "Notes", pid: 13, frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
      h.start()
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) left")
      h.run("dock \(c.rawValue) right")
      h.system.cursor = CGPoint(x: 300, y: 300)
      h.system.userFocus(c)
      h.system.keyDown()
      h.scheduler.advance(by: 1)
      h.system.close(c)
      h.scheduler.advance(by: 1)
      return (h, b)
    }
    let (h, _) = desk()
    #expect(h.controller.displayForCommands(from: .shortcut) == side.id)
    let (gone, _) = desk()
    gone.system.userFocusesNothing()
    #expect(gone.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// An app can go on naming its window in the Dock as the focused one. A key that names no window does not act on that.
  @Test func aWindowInTheDockThatIsStillNamedIsNoWindowInFront() {
    let (h, a, _, _) = threeApps()
    h.run("show-all")
    h.system.userFocus(a)
    h.system.echoes.keyboard = false
    h.system.setMinimized(a, true)
    h.system.focused = a
    h.scheduler.advance(by: 1)
    let view = h.workspace.camera
    for command in ["zoom", "float", "dock right"] { #expect(!h.run(command).ok, "\(command)") }
    #expect(h.workspace.camera == view)
    expectWindowsMatchLayout(h)
  }

  /// With nothing docked, which is what a newcomer meets.
  @Test(arguments: ["close", "minimize"]) func norWithNothingDocked(way: String) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    let notes = h.system.open(app: "Notes", pid: 12)
    h.start()
    h.system.userFocus(safari)
    h.system.userFocus(notes)
    h.scheduler.advance(by: 1)
    go(way, notes, h)
    h.scheduler.advance(by: 2)
    #expect(h.system.focusLog.isEmpty, "\(h.system.focusLog)")
    #expect(h.system.frameLog.isEmpty)
  }

  /// Somebody clicks the desktop and renames a file there. The window used last goes away meanwhile. Arbor focused another window a
  /// quarter of a second later: the renaming was over, and the windows that the click on the wallpaper had swept aside all
  /// came back (seen on a hosted Mac; the trace `minimized-with-finder-in-front`).
  @Test(arguments: goings) func aWindowThatGoesWhileTheKeyboardIsWithFinderCostsFinderNothing(way: String) {
    let (h, a, _, _) = threeApps()
    h.run("show-all")
    h.system.userFocus(a)
    h.scheduler.advance(by: 1)
    h.system.userFocusesNothing()
    h.scheduler.advance(by: 2)
    let asked = h.system.focusLog.count
    go(way, a, h)
    h.scheduler.advance(by: 2)
    #expect(h.system.focusLog.dropFirst(asked).map(\.window) == [])
    #expect(h.system.focusedWindow() == nil)
    expectWindowsMatchLayout(h)
  }

  @Test func movingTheViewWithNothingFocusedFocusesAWindowInView() {
    let (h, a, _, _) = threeApps()
    h.system.userFocusesNothing()
    h.run("neighbor right")
    let focused = h.system.focusedWindow()
    #expect(focused != nil && focused != a)
    if let focused { #expect(h.system.isVisible(focused)) }
  }

  // MARK: Somebody Arbor does not look at has the keyboard

  /// Commands that move the view and name no window and no place.
  nonisolated static let movesOfTheView = ["show-all", "home", "neighbor right", "out", "desktop", "back"]

  /// `threeApps`, and a window that floats on the Desktop, so that every view has somebody to give the keyboard to.
  /// NEEDS A DESKTOP WITH ROOM BESIDE THE DOCKED PLACES: `desktop`, `out` and a neighbour each have to move the view, and the Desktop's tile is clicked.
  func threeAppsAndAFloat() -> (Harness, a: WindowID, b: WindowID, c: WindowID, f: WindowID) {
    let (h, a, b, c) = threeApps()
    h.run("show-all")
    let f = h.system.open(app: "Notes", pid: 14, frame: CGRect(x: 1150, y: 300, width: 250, height: 300))
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 1)
    return (h, a, b, c, f)
  }

  /// A menu bar app's window, a launcher that comes forward, an app Arbor was told nothing about.
  func aLauncherTakesTheKeyboard(_ h: Harness) {
    h.system.activate(bundleID: "com.example.launcher", name: "Launcher")
    h.system.keyboardGoesToNoKnownWindow()
  }

  /// A key that moves the view moves the view. (Ten times of ten, on a hosted Mac, it also took the keyboard.)
  @Test(arguments: movesOfTheView) func aKeyThatMovesTheViewLeavesTheKeyboardWithAnAppArborDoesNotLookAt(command: String) {
    let (h, _, _, _, _) = threeAppsAndAFloat()
    aLauncherTakesTheKeyboard(h)
    let (asked, view) = (h.system.focusLog.count, h.workspace.camera)
    #expect(h.run(command).ok)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera != view, "the view does move")
    #expect(h.system.focusLog.dropFirst(asked).map(\.window) == [])
    #expect(h.system.focusedWindow() == nil)
    expectWindowsMatchLayout(h)
  }

  /// With Finder in front and no window focused nobody has it, and it goes along with the view, as before.
  @Test(arguments: movesOfTheView) func fromTheDesktopTheKeyboardGoesAlongWithTheView(command: String) {
    let (h, _, _, _, _) = threeAppsAndAFloat()
    h.system.userFocusesNothing()
    #expect(h.run(command).ok)
    h.scheduler.advance(by: 1)
    let focused = h.system.focusedWindow()
    #expect(focused != nil && focused.map { h.system.isVisible($0) } == true)
  }

  /// A free-standing panel or dialog (Find, Fonts, Open…) stays on screen whatever the view does, so nobody takes the keyboard out of it: not while its
  /// app's window is in view, and not when that leaves. macOS names it by a number of its own, which Arbor does not know (seen on a hosted Mac).
  /// An app Arbor knows that has windows and names none as focused keeps the keyboard at these moves too.
  ///
  /// A sheet needs no test here: the real layer answers it with its window's number, so it goes by what holds for that window
  /// (`make mac-on-linux`, "a sheet").
  @Test(arguments: [WindowID(9_999), nil]) func aPanelKeepsTheKeyboardWhereverItsAppsWindowGoes(named: WindowID?) {
    let (h, a, _, _, _) = threeAppsAndAFloat()
    h.system.userFocus(a)
    h.system.keyboardGoesToNoKnownWindow(named: named)
    let asked = h.system.focusLog.count
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(a) && h.system.focusLog.count == asked)
    #expect(h.run("back").ok && h.run("neighbor right").ok)
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(a) && h.system.focusLog.count == asked, "\(h.system.focusLog.dropFirst(asked).map(\.window))")
    #expect(h.system.focusedWindow() == named)
  }

  /// A window of Arbor's own has nobody to give the keyboard back to. (Run from a terminal, or by a test, Arbor has no bundle.)
  @Test func withArborItselfInFrontTheKeyboardGoesAlongWithTheView() {
    let (h, _, _, _, _) = threeAppsAndAFloat()
    h.system.activate(bundleID: nil, name: ProcessInfo.processInfo.processName)
    h.system.keyboardGoesToNoKnownWindow()
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow().map { h.system.isVisible($0) } == true)
  }

  /// What names a window gives it the keyboard, whoever had it.
  @Test(arguments: ["zoom $b", "focus $b", "reveal $b"]) func whatNamesAWindowGetsItTheKeyboardWhoeverHadIt(ask: String) {
    let (h, _, b, _, _) = threeAppsAndAFloat()
    aLauncherTakesTheKeyboard(h)
    #expect(h.run(ask.replacingOccurrences(of: "$b", with: "\(b.rawValue)")).ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow() == b)
  }

  /// So does what names a place: a saved view, a space by its name or its number, a tile, a line of Go to…. From a launcher, and from a panel of
  /// the app in front.
  @Test(arguments: [false, true]) func whatNamesAPlaceTakesTheKeyboardThereWhoeverHadIt(fromAPanel: Bool) throws {
    func fixture() -> (Harness, b: WindowID, f: WindowID, space: NodeID) {
      let (h, a, b, _, f) = threeAppsAndAFloat()
      h.run("zoom \(b.rawValue)")
      h.run("save-view 1")
      h.run("name letters")
      let space = h.workspace.camera
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 1)
      if fromAPanel { h.system.keyboardGoesToNoKnownWindow(named: WindowID(9_999)) } else { aLauncherTakesTheKeyboard(h) }
      return (h, b, f, space)
    }
    for line in ["view 1", "go letters", "find letters", "zoom-node $space", "frame-rect $b"] {
      let (h, b, _, space) = fixture()
      // The rectangle is drawn with everything showing, around `b`.
      if line.hasPrefix("frame-rect") { h.run("show-all") }
      let around = (h.frame(b) ?? .zero).insetBy(dx: 20, dy: 20)
      let rectangle = "\(around.minX) \(around.minY) \(around.width) \(around.height)"
      #expect(
        h.run(line.replacingOccurrences(of: "$space", with: "\(space.rawValue)").replacingOccurrences(of: "$b", with: rectangle)).ok,
        "\(line)")
      h.scheduler.advance(by: 1)
      #expect(h.system.focusedWindow() == b, "\(line)")
    }
    let (palette, b, _, space) = fixture()
    #expect(palette.run("find").ok)
    palette.controller.finderChose(.space(FakeWindowSystem.standardDisplay.id, space))
    palette.scheduler.advance(by: 1)
    #expect(palette.system.focusedWindow() == b, "a line of Go to…")

    let (h, _, f, _) = fixture()
    h.overlays.clickTile(h.workspace.tree.desktop)
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow() == f, "the Desktop's tile")
  }

  /// Whoever says "focus" asks for the keyboard, also by a direction, and also where nothing lies that way in view and the command goes on to the
  /// neighbouring space as `neighbor` would, which by itself names nothing. NEEDS A DESKTOP WITH ROOM BESIDE THE DOCKED PLACES, and nothing on it.
  @Test(arguments: [false, true]) func focusInEveryFormMovesTheKeyboard(fromAPanel: Bool) {
    let (h, _, _, _) = threeApps()
    #expect(h.run("desktop").ok)
    h.scheduler.advance(by: 1)
    if fromAPanel { h.system.keyboardGoesToNoKnownWindow(named: WindowID(9_999)) } else { aLauncherTakesTheKeyboard(h) }
    let view = h.workspace.camera
    #expect(h.run("focus left").ok)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera != view, "nothing is in view to turn to, so the view moves on")
    let focused = h.system.focusedWindow()
    #expect(focused.map { h.system.isVisible($0) && h.workspace.contains($0) } == true, "\(String(describing: focused))")
  }

  /// Its last window has gone, and macOS has decided: the app is in front with its menu bar and nothing to type into. Nobody has the
  /// keyboard, and the next move of the view that a person asks for takes it along.
  /// A pause in between forgets no app.
  @Test(arguments: [false, true], [false, true]) func anAppWithNoWindowLeftIsNobody(minimized: Bool, pause: Bool) {
    let (h, _, _, _, f) = threeAppsAndAFloat()
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 1)
    if minimized { h.system.setMinimized(f, true) } else { h.system.close(f) }
    h.scheduler.advance(by: 2)
    #expect(h.system.focusedWindow().map { h.system.isVisible($0) } != true, "nothing is in view to take it")
    if pause {
      #expect(h.run("pause").ok && h.run("resume").ok)
      h.scheduler.advance(by: 2)
      #expect(h.system.focusedWindow().map { h.system.isVisible($0) } != true)
    }
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow().map { h.system.isVisible($0) } == true)
  }

  @Test func aCommandThatLeavesTheViewWhereItIsLeavesTheFocusAloneToo() {
    let (h, a, _, _) = threeApps()
    h.system.userFocusesNothing()
    h.run("zoom \(h.workspace.camera)")
    #expect(h.system.focusedWindow() == nil)
  }

  @Test func amongSeveralInViewTheOneUsedLastGetsTheFocus() {
    let (h, a, b, c) = threeApps()
    h.run("show-all")
    for window in [c, b, a] { h.system.userFocus(window) }
    h.system.cursor = h.frame(c)!.center
    h.run("zoom \(a.rawValue)")
    h.system.setMinimized(a, true)
    h.scheduler.advance(by: 1)
    // The view is empty, and a move of the view takes the keyboard along.
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow() == b, "not the one that happens to be under the pointer")
  }

  /// macOS's own pick uses up what Arbor remembers of the loss, in view or not. What comes next is the user's.
  @Test func afterAnAppIsHiddenTheUsersOwnSwitchIsFollowedAtOnce() {
    for swapped in [false, true] {
      let (h, a, b, c) = threeApps()
      let (heir, wanted) = swapped ? (c, b) : (b, c)
      h.run("show-all")
      h.system.userFocus(heir)
      h.run("zoom \(a.rawValue)")
      h.system.setHidden(pid: 11, true)
      h.system.userFocus(wanted)
      #expect(h.system.isVisible(wanted))
      #expect(h.system.focusedWindow() == wanted)
    }
  }
}
