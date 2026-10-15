import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The window with the keyboard is closed or minimized, and macOS names its app's next window, which is out of view. One thing
/// happened, and nobody asked to see that window: nothing moves but what the going itself moves, whichever report comes first.
/// The view used to go out to the window and come back.
@Suite @MainActor struct AGoingIsOneActTests {
  // MARK: As the random walks found it

  /// Notes and Safari are docked and the view is on Notes. Terminal, carried over from the other display, floats over it. Safari
  /// opens a second window there. `order` is how a change of displays is reported, which the walks play in all three ways.
  static func aSecondWindowOverAFramedOne(order: String) -> String {
    """
    displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0 \(order)
    open 101 Notes pid 1001 at 300 200 800 600 min 709 300
    open 102 Safari pid 1000 at 500 150 900 700 min 574 240
    open 104 Terminal pid 1003 at 2000 100 700 500 min 177 60
    launch
    focus 101
    key down dock left
    key up dock left
    settle
    focus 102
    key down dock right
    key up dock right
    settle
    focus 101
    key down zoom
    key up zoom
    settle
    grab 104
    carry 700 300
    release
    settle
    open 103 Safari pid 1000 at 400 250 900 600 min 574 240
    settle
    """
  }

  /// The same on one display: Notes floats over a framed Terminal that went into the Dock and came out.
  static let onOneDisplay = """
    displays main:0,0,1512,982:37,0,0,0* windows-first
    open 101 Notes pid 1001 at 300 200 800 600 min 709 300
    open 102 Terminal pid 1003 at 700 300 600 400 min 177 60
    open 105 Safari pid 1000 at 500 150 900 700 min 574 240
    launch
    focus 102
    key down dock left
    key up dock left
    settle
    focus 105
    key down dock right
    key up dock right
    settle
    focus 102
    key down zoom
    key up zoom
    settle
    minimize 102
    settle
    restore 102
    settle
    open 103 Safari pid 1000 at 400 250 900 600 min 574 240
    settle
    """

  /// The shortest: the window out of view floats, and went out with the Desktop when Safari was framed.
  static let theOtherWindowFloats = """
    launch
    open 101 Safari pid 1000 at 100 100 700 500
    open 102 Music pid 1006 at 300 200 700 480
    settle
    dock 101 left
    settle
    focus 101
    zoom 101
    settle
    open 104 Music pid 1006 at 400 300 600 400
    settle
    """

  /// Plays `script`, whatever rules it breaks on the way (they are other stories), then `going`, and expects that to move nothing.
  func expectNothingMoves(after script: String, at going: String, sourceLocation: SourceLocation = #_sourceLocation) {
    let runner = ChaosRunner()
    for action in ChaosAction.script(script) { _ = runner.step(action) }
    let views = runner.controller.workspaces.mapValues(\.camera)
    let frames = runner.system.windows.mapValues(\.snapshot.frame)
    let moves = runner.system.moveLog.count
    for action in ChaosAction.script(going + "\nsettle") {
      let violations = runner.step(action)
      #expect(violations.isEmpty, "\(action.text): \(violations)", sourceLocation: sourceLocation)
    }
    let moved = runner.system.moveLog[moves...].filter { $0.before != $0.after }
    #expect(moved.isEmpty, "\(moved.map { "\($0.window) \($0.before) → \($0.after)" })", sourceLocation: sourceLocation)
    #expect(runner.controller.workspaces.mapValues(\.camera) == views, sourceLocation: sourceLocation)
    for (window, fake) in runner.system.windows where !fake.snapshot.isMinimized {
      #expect(fake.snapshot.frame == frames[window], "\(window)", sourceLocation: sourceLocation)
    }
    // Typing goes somewhere that can be seen.
    let holder = runner.system.focused
    let inView = holder.map { runner.system.isVisible($0) && !runner.controller.parked.contains($0) }
    #expect(inView == true, "\(String(describing: holder))", sourceLocation: sourceLocation)
  }

  @Test(arguments: ["windows-first", "windows-late", "windows-silent"], ["close 103", "minimize 103"])
  func theGoingOfAnAppsSecondWindowMovesNothing(order: String, going: String) {
    expectNothingMoves(after: Self.aSecondWindowOverAFramedOne(order: order), at: going)
  }

  @Test(arguments: ["close 103", "minimize 103"]) func norOnOneDisplay(going: String) {
    expectNothingMoves(after: Self.onOneDisplay, at: going)
  }

  @Test(arguments: ["close 104", "minimize 104"]) func norWhenTheOtherWindowFloats(going: String) {
    expectNothingMoves(after: Self.theOtherWindowFloats, at: going)
  }

  // MARK: Both orders end alike

  /// `[Desktop | a over (b | c) | a2]`, where `a` and `a2` are one app's. The view is on the group of `a`, `b` and `c`, and the
  /// keyboard in `a`.
  func aGroupInView() -> (Harness, a: WindowID, b: WindowID, c: WindowID, a2: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    let c = h.system.open(app: "Mail", pid: 13)
    let a2 = h.system.open(app: "Safari", pid: 11)
    h.start()
    h.run("dock \(a.rawValue) right")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(c.rawValue) beside \(b.rawValue) right")
    h.run("dock \(a2.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a)
    #expect(h.system.isVisible(b) && h.system.isVisible(c) && !h.system.isVisible(a2))
    return (h, a, b, c, a2)
  }

  /// What is left of the group is a row in a row, which the tree does not keep: a view that had gone out had nothing to come back
  /// to and stayed on everything.
  @Test(arguments: [false, true]) func theViewStaysOnWhatIsLeftOfAGroupThatDissolves(goingFirst: Bool) {
    let (h, a, b, c, a2) = aGroupInView()
    if goingFirst {
      h.system.echoes.keyboard = false
      h.system.close(a)
      h.system.userFocus(a2)
    } else {
      h.system.close(a)
    }
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(b) && h.system.isVisible(c), "\(h.ascii())")
    #expect(!h.system.isVisible(a2), "\(h.ascii())")
    #expect(h.workspace.camera != h.workspace.tree.root)
    #expect(h.system.focused == b || h.system.focused == c)
    expectWindowsMatchLayout(h)
  }

  // MARK: What the moment costs, and whom

  /// `[a / c | Desktop | b / a2]`, where `a2` is a second Safari window, with the view on the left column and the keyboard in `a`.
  func aColumnInView() -> (Harness, a: WindowID, a2: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    let a2 = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(a2.rawValue) beside \(b.rawValue) bottom")
    h.system.userFocus(b)
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b))
    return (h, a, a2, b, c)
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] { h.system.moveLog[mark...].filter { $0.before != $0.after } }

  @Test(arguments: ["close", "minimize"]) func aGoingInAColumnMovesOnlyWhatItMakesRoomFor(going: String) {
    let (h, a, a2, b, c) = aColumnInView()
    let mark = h.system.moveLog.count
    if going == "close" { h.system.close(a) } else { h.system.setMinimized(a, true) }
    h.scheduler.advance(by: 2)
    // `c` grows into the room. Nobody else has anything to do with it.
    #expect(Set(realMoves(h, since: mark).map(\.window)) == [c], "\(realMoves(h, since: mark))")
    #expect(realMoves(h, since: mark).count == 1, "\(realMoves(h, since: mark))")
    #expect(h.system.focused == c)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b))
  }

  /// ⌘` or the Window menu: nothing goes, so the view follows, a moment later and in one move.
  @Test func aSwitchWithinOneAppIsFollowedAMomentLater() {
    let (h, _, a2, _, _) = aColumnInView()
    let mark = h.system.moveLog.count
    h.system.userFocus(a2)
    #expect(realMoves(h, since: mark).isEmpty)
    h.scheduler.advance(by: Controller.timeForAGoing)
    #expect(h.system.isVisible(a2))
    #expect(h.system.focused == a2)
    h.scheduler.advance(by: 2)
    let moves = realMoves(h, since: mark)
    #expect(Set(moves.map(\.window)).count == moves.count, "each at most once: \(moves)")
    expectWindowsMatchLayout(h)
  }

  /// ⌘Tab, a click in the Dock: macOS never picks another app's window after a close or a minimize.
  @Test func aSwitchToAnotherAppIsFollowedAtOnce() {
    let (h, _, _, b, _) = aColumnInView()
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
  }

  /// The keyboard was in something Arbor does not arrange (an app it leaves alone, the wallpaper). Of the windows it does arrange a
  /// window of the same app was the last to have it, and still this is a switch between apps.
  @Test func soIsASwitchOutOfSomethingArborDoesNotArrange() {
    let (h, _, a2, _, _) = aColumnInView()
    h.system.userFocusesNothing()
    h.scheduler.advance(by: 2)
    h.system.userFocus(a2)
    #expect(h.system.isVisible(a2))
  }

  @Test func arborsOwnKeysWaitForNothing() {
    let (h, _, a2, _, _) = aColumnInView()
    h.run("focus \(a2.rawValue)")
    #expect(h.system.isVisible(a2))
    #expect(h.system.focused == a2)
  }

  /// Arbor was not looking when the keyboard went where it is, and finds it there: no report, nothing to wait for.
  @Test func aResumeEndsWithTheFocusedWindowInViewAtOnce() {
    let (h, _, a2, _, _) = aColumnInView()
    h.run("pause")
    h.system.userFocus(a2)
    h.run("resume")
    #expect(h.system.isVisible(a2))
  }

  @Test func theKeyboardThatComesBackWithinTheMomentMovesNothing() {
    let (h, a, a2, _, _) = aColumnInView()
    let mark = h.system.moveLog.count
    h.system.userFocus(a2)
    h.scheduler.advance(by: Controller.timeForAGoing / 2)
    h.system.userFocus(a)
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty)
    #expect(h.system.focused == a)
  }

  /// macOS says the same thing two to four times. The moment is counted from the first.
  @Test func sayingItAgainDoesNotPutTheViewOff() {
    let (h, _, a2, _, _) = aColumnInView()
    h.system.userFocus(a2)
    h.scheduler.advance(by: Controller.timeForAGoing * 0.6)
    h.controller.windowFocused(a2)
    #expect(!h.system.isVisible(a2))
    // Half a moment after the second report, a little over one after the first.
    h.scheduler.advance(by: Controller.timeForAGoing * 0.5)
    #expect(h.system.isVisible(a2))
  }

  /// A Mac that is busy can be later than the moment. Then the view has followed and is taken back, as it always was.
  @Test(arguments: ["close", "minimize"]) func aGoingThatComesAfterTheMomentStillTakesTheViewBack(going: String) {
    let (h, a, a2, b, c) = aColumnInView()
    h.system.focused = a2
    h.controller.windowFocused(a2)
    h.scheduler.advance(by: Controller.timeForAGoing * 2)
    #expect(h.system.isVisible(a2))
    h.system.echoes.keyboard = false
    if going == "close" { h.system.close(a) } else { h.system.setMinimized(a, true) }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == c)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b))
  }

  /// With nothing left in view the view follows the keyboard, at the going and not a quarter of a second later.
  @Test func withNothingLeftInViewTheViewFollowsAtOnce() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(f.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(a))
    let mark = h.system.moveLog.count
    h.system.close(f)
    #expect(h.system.isVisible(a))
    #expect(h.system.focused == a)
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).count == 1, "\(realMoves(h, since: mark))")
  }

  // MARK: Who does not wait, and what ends the wait

  /// Holding still, a window its person asks for is let in, and ⌘W is a key like ⌘`: the view went out and back in front of an
  /// audience.
  @Test(arguments: ["close", "minimize"]) func holdingStillAGoingMovesOnlyWhatItMakesRoomFor(going: String) {
    let (h, a, a2, b, c) = aColumnInView()
    h.run("hold still")
    h.system.secondsSinceInput = 0
    let mark = h.system.moveLog.count
    if going == "close" { h.system.close(a) } else { h.system.setMinimized(a, true) }
    h.scheduler.advance(by: 2)
    #expect(Set(realMoves(h, since: mark).map(\.window)) == [c], "\(realMoves(h, since: mark))")
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b))
  }

  /// A held view follows nobody, and the keyboard is sent back at once.
  @Test func onAHeldViewTheKeyboardIsSentBackAtOnce() {
    let (h, a, a2, _, _) = aColumnInView()
    h.run("hold")
    let mark = h.system.moveLog.count
    h.system.userFocus(a2)
    #expect(h.system.focused == a)
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty)
  }

  /// ⌘N in the app in use, and the new window's place is out of view. macOS never picks a window that has only just opened, so it is
  /// shown in the same breath and does not lie in the corner meanwhile.
  @Test func aNewWindowOfTheAppInUseIsShownAtOnce() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    _ = h.system.open(app: "Notes", pid: 12)
    h.start()
    h.run("layout --open Safari | (Safari / Notes)")
    h.run("zoom \(safari.rawValue)")
    h.system.userFocus(safari)
    h.scheduler.advance(by: 2)
    let new = h.system.open(app: "Safari", pid: 11)
    #expect(h.workspace.isDocked(new) && h.system.isVisible(new), "\(h.ascii())")
    #expect(h.system.focused == new)
  }

  @Test func theOtherWindowGoingInsteadLeavesEverythingWhereItIs() {
    let (h, a, a2, _, _) = aColumnInView()
    h.system.echoes.keyboard = false
    let view = h.workspace.camera
    h.system.userFocus(a2)
    h.system.close(a2)
    h.system.userFocus(a)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == view)
    #expect(h.system.focused == a && h.system.isVisible(a))
    #expect(!h.scheduler.pendingKeys.contains("focus-within-one-app"))
  }

  @Test(arguments: [true, false]) func nothingWaitsOnceArborStops(pause: Bool) {
    let (h, _, a2, _, _) = aColumnInView()
    h.system.userFocus(a2)
    #expect(h.scheduler.pendingKeys.contains("focus-within-one-app"))
    if pause { h.run("pause") } else { h.controller.shutdown() }
    #expect(!h.scheduler.pendingKeys.contains("focus-within-one-app"))
  }

  /// Whoever moves the view meanwhile has said where it goes. macOS can be slow to move the keyboard along.
  @Test(arguments: ["zoom 102", "back", "undo", "home"]) func aCommandThatMovesTheViewMeanwhileHasTheLastWord(command: String) {
    let (h, _, a2, _, _) = aColumnInView()
    h.system.userFocus(a2)
    h.system.focusIsSlow = true
    let before = h.workspace.camera
    h.run(command)
    let view = h.workspace.camera
    #expect(view != before)
    h.scheduler.advance(by: Controller.timeForAGoing)
    #expect(h.workspace.camera == view)
  }

  /// An app that is busy does not say who has the keyboard. The look is taken again, like any other.
  @Test func anAppThatDoesNotAnswerAtThatMomentIsAskedAgain() {
    let (h, _, a2, _, _) = aColumnInView()
    h.system.userFocus(a2)
    h.system.focused = nil
    h.scheduler.advance(by: Controller.timeForAGoing)
    #expect(!h.system.isVisible(a2))
    h.system.focused = a2
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(a2))
  }

  /// A document and a panel open together: each is new, whichever came last.
  @Test func soIsTheFirstOfTwoNewWindows() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    _ = h.system.open(app: "Notes", pid: 12)
    h.start()
    h.run("layout --open Safari | (Safari / Notes)")
    h.run("zoom \(safari.rawValue)")
    h.system.userFocus(safari)
    h.scheduler.advance(by: 2)
    h.system.echoes.keyboard = false
    let new = h.system.open(app: "Safari", pid: 11)
    _ = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 40, y: 60, width: 200, height: 120))
    h.system.userFocus(new)
    #expect(h.workspace.isDocked(new) && h.system.isVisible(new), "\(h.ascii())")
  }

  /// New only once. A window that opened a moment ago and has had the keyboard since is picked like any other.
  @Test func aWindowThatOpenedAMomentAgoIsPickedLikeAnyOther() {
    let (h, a, _, b, c) = aColumnInView()
    let a3 = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.run("dock \(a3.rawValue) beside \(b.rawValue) bottom")
    // No time passes: Arbor's own commands wait for nothing.
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    #expect(h.system.focused == a && !h.system.isVisible(a3))
    let mark = h.system.moveLog.count
    h.system.close(a)
    #expect(Set(realMoves(h, since: mark).map(\.window)) == [c], "\(realMoves(h, since: mark))")
    #expect(!h.system.isVisible(a3))
  }
}
