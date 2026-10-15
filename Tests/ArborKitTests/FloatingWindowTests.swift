import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Floating windows as a person meets them: they live on the Desktop, follow it, make way for
/// docked windows, and otherwise stay the size and in the place the user gave them.
///
/// Making way is a setting since Q20, `floatingWindowsMakeWay`, and it ships off (`FloatingFrameTests`). The tests of making way
/// run with it on and say so (`.makingWay`, `makingWay: true`). What has to hold whatever the setting runs as Arbor ships,
/// or both ways.
@Suite @MainActor struct FloatingWindowTests {
  /// `[a | Desktop | b]` with `f` floating in the middle of the Desktop. As Arbor ships, unless `makingWay`.
  /// `apart`: each app is a process of its own, as a story about ⌘Tab needs. Otherwise they are one, and a switch among them is ⌘`.
  func makeHarness(makingWay: Bool = false, apart: Bool = false) -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    let a = h.system.open(app: "Safari", pid: apart ? 11 : 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: apart ? 12 : 1000, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", pid: apart ? 13 : 1000, frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, f)
  }

  @Test func aPushedWindowGoesBackWhenTheDesktopGrowsAgain() {
    let h = Harness(settings: .makingWay)  // nothing is pushed unless floating windows make way
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Preview", frame: CGRect(x: 200, y: 200, width: 1000, height: 500))
    h.start()
    let chosen = h.frame(f)!
    h.run("dock \(a.rawValue) left")
    #expect(isOnDesktop(f, h), "docking pushes it onto what is left of the Desktop")
    #expect(h.frame(f)!.width < chosen.width, "and here that means shrinking it")
    h.run("float \(a.rawValue)")
    #expect(h.frame(f) == chosen, "the size and place the user chose come back with the room for them")
  }

  @Test func aPushedWindowGrowsBackAsASeamGivesTheDesktopRoom() {
    let h = Harness(settings: .makingWay)  // nothing is pushed unless floating windows make way
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Preview", frame: CGRect(x: 700, y: 200, width: 700, height: 500))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("resize \(a.rawValue) right 300")
    #expect(h.frame(f)!.width < 700)
    h.run("resize \(a.rawValue) right -300")
    #expect(h.frame(f) == CGRect(x: 700, y: 200, width: 700, height: 500).fitted(into: h.layout!.desktopFrame!))
    #expect(h.frame(f)!.width == 700)
  }

  @Test func aWindowTheUserPutOverDockedWindowsStaysThere() {
    let (h, a, b, f) = makeHarness()
    // Half over Safari, half over the Desktop, on purpose.
    let chosen = CGRect(x: h.frame(a)!.maxX - 160, y: 300, width: 320, height: 300)
    h.system.userMove(f, to: chosen)
    h.system.setMinimized(b, true)
    #expect(h.frame(f) == chosen, "something else changing is no reason to move it")
    h.system.setMinimized(b, false)
    #expect(h.frame(f) == chosen)
    h.run("resize \(b.rawValue) left 50")
    #expect(h.frame(f) == chosen)
  }

  @Test func aWindowDroppedAFewPointsOverTheEdgeOfTheDesktopStillMakesWay() {
    let (h, a, b, f) = makeHarness(makingWay: true)
    // Nobody lines a window up with the Desktop to the point: this one covers the gap and a sliver of Notes.
    let desktop = h.layout!.desktopFrame!
    h.system.userMove(f, to: CGRect(x: desktop.maxX - 300, y: 300, width: 320, height: 300))
    h.run("resize \(b.rawValue) left 100")
    #expect(h.layout!.desktopFrame!.contains(h.frame(f)!), "\(h.ascii())")
    _ = a
  }

  @Test func aWindowHangingOverTheScreenEdgeMakesWayForAWindowDockedUnderIt() {
    let h = Harness(settings: .makingWay)  // nothing makes way unless the setting of that name is on
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Mail", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    // A good part of it is beyond the right edge of the screen, as people leave windows.
    let chosen = CGRect(x: 1000, y: 300, width: 600, height: 400)
    h.system.userMove(f, to: chosen)
    h.run("dock \(a.rawValue) right")
    #expect(!h.frame(f)!.overlaps(h.frame(a)!), "it was on the Desktop with all that showed of it\n\(h.ascii())")
    #expect(h.frame(f)!.size == chosen.size)
    h.run("float-all")
    #expect(h.frame(f) == chosen, "and hangs over the edge again when there is room")
  }

  /// `[a | Desktop]` with `f` floating. The frame remembered for `f` is narrower than its app allows by now, as on a real
  /// Mac in collab/evidence/traces/seam-drag-futile.jsonl. Floating windows make way here, as until Q20
  /// (`floatingWindowsMakeWay`): it is being pushed that asks the app for that frame.
  func withAWindowThatHasGrownStubborn() -> (Harness, a: WindowID, f: WindowID) {
    let h = Harness(settings: .makingWay)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Xcode", frame: CGRect(x: 900, y: 136, width: 480, height: 352))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.system.setMinimumSize(f, CGSize(width: 700, height: 352))
    return (h, a, f)
  }

  @Test func aWindowWhoseAppHasComeToInsistOnMoreIsAskedOnceAndThenLeftInPeace() {
    let (h, a, f) = withAWindowThatHasGrownStubborn()
    // Pushed, it is asked for its remembered width and takes 700, which is what is remembered from then on (F48).
    h.run("resize \(a.rawValue) right 300")
    let took = h.frame(f)!
    #expect(took.width == 700 && h.workspace.floating[f]!.width == 700)
    #expect(h.visibleFrame.contains(took), "\(took)")
    h.system.clearFrameLog()
    // Layouts that leave the Desktop as it is: a gap dragged against its stop, settings read again.
    for _ in 0..<5 { h.controller.apply(settings: h.controller.settings) }
    #expect(h.system.frameLog.filter { $0.window == f }.isEmpty, "\(h.system.frameLog.filter { $0.window == f })")
    #expect(h.frame(f) == took)
  }

  @Test func theFrameRememberedGrowsAwayFromTheEdgeOfTheScreenNotOverIt() {
    // 900 + 700 would reach 160 points over the edge, which would pass for a place its user chose.
    let (h, a, f) = withAWindowThatHasGrownStubborn()
    h.run("resize \(a.rawValue) right 300")
    #expect(h.visibleFrame.contains(h.workspace.floating[f]!), "\(h.workspace.floating[f]!)")
    h.run("float-all")
    #expect(h.visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!)")
  }

  @Test func butWhatItsUserLeftHangingOverTheEdgeGoesOnHanging() {
    let (h, a, f) = withAWindowThatHasGrownStubborn()
    h.system.setMinimumSize(f, .zero)
    h.system.userMove(f, to: CGRect(x: 1100, y: 136, width: 480, height: 352))
    h.system.setMinimumSize(f, CGSize(width: 480, height: 500))
    h.run("resize \(a.rawValue) right 500")
    h.run("resize \(a.rawValue) right -500")
    #expect(h.workspace.floating[f]!.maxX == 1580, "\(h.workspace.floating[f]!)")
  }

  @Test func aWindowThatAnswersWithLessThanItWasAskedForIsNotAskedAgainAndAgain() {
    // A terminal that is shrunk to fit the Desktop takes the whole text cell below. Only while floating windows make way.
    let h = Harness(settings: .makingWay)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 136, width: 1000, height: 352))
    h.start()
    h.system.setSizeStep(f, CGSize(width: 9, height: 17))
    h.run("dock \(a.rawValue) left")
    let took = h.frame(f)!
    #expect(took.width < 1000)
    h.system.clearFrameLog()
    for _ in 0..<5 { h.controller.apply(settings: h.controller.settings) }
    #expect(h.system.frameLog.filter { $0.window == f }.isEmpty, "\(h.system.frameLog.filter { $0.window == f })")
    #expect(h.frame(f) == took)
  }

  @Test func aStripOfALargeWindowIsNotTakenForAWindowOutOfView() {
    // Backlog K1385, from the chaos lab: 28 points of a window 1400 wide are under 2 % of it, and plain to see.
    let (h, _, _, f) = makeHarness()
    let strip = CGRect(x: h.visibleFrame.maxX - 28, y: 30, width: 1400, height: 860)
    h.system.userMove(f, to: strip)
    h.run("relayout")
    #expect(!h.controller.parked.contains(f))
    #expect(h.frame(f)!.intersection(h.visibleFrame).width >= 28, "\(h.frame(f)!)")
  }

  @Test func aWindowPushedAsideToAStripStaysAStrip() {
    let (h, a, b, f) = makeHarness()
    h.run("float \(b.rawValue)")
    h.system.close(b)
    // `[a | Desktop]`. All but 40 points of it are beyond the right edge of the screen, out of the way.
    let strip = CGRect(x: h.visibleFrame.maxX - 40, y: 200, width: 600, height: 400)
    h.system.userMove(f, to: strip)
    h.run("resize \(a.rawValue) right 50")
    #expect(h.frame(f) == strip, "a change of the arrangement is no reason to fetch it")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == strip, "and it comes back into view as it was left")
  }

  // MARK: A display that changes shape

  // Never lost, and a place chosen by hand is honoured: that holds whether floating windows make way or keep their frames.

  func small(_ width: CGFloat = 800, _ height: CGFloat = 600) -> DisplaySnapshot {
    DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: width, height: height),
      visibleFrame: CGRect(x: 0, y: 25, width: width, height: height - 25), isMain: true)
  }

  @Test(arguments: [false, true]) func whatADisplayThatShrankLeavesHangingWasNotLeftHanging(makingWay: Bool) {
    // Found by the chaos lab. All of it was in view at 776,135 on a display 1440 wide. On one 800 wide 24 points of it show.
    let h = Harness(settings: makingWay ? .makingWay : Settings())
    let f = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 64, y: 104, width: 230, height: 400))
    h.start()
    let chosen = CGRect(x: 776, y: 135, width: 230, height: 400)
    h.system.userMove(f, to: chosen)
    h.system.setDisplays([small()])
    h.scheduler.advance(by: 1)
    #expect(small().visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!)")
    let a = h.system.open(app: "Mail", pid: 12)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(small().visibleFrame.contains(h.frame(f)!), "nor after a round out of view: \(h.frame(f)!)")
    h.run("float \(a.rawValue)")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 1)
    #expect(h.workspace.floating[f] == chosen, "the frame is still remembered")
  }

  @Test(arguments: ["relaunch", "pause"]) func norAfterArborStartedAgainOnTheShrunkenDisplay(how: String) {
    let first = Harness()
    let f = first.system.open(app: "Safari", pid: 11, frame: CGRect(x: 64, y: 104, width: 230, height: 400))
    first.start()
    first.system.userMove(f, to: CGRect(x: 776, y: 135, width: 230, height: 400))
    first.system.setDisplays([small()])
    first.scheduler.advance(by: 1)
    var h = first
    if how == "pause" {
      h.run("pause")
      h.run("resume")
    } else {
      first.controller.shutdown()
      h = Harness(displays: [small()], saved: first.store.saved)
      #expect(h.system.open(app: "Safari", pid: 11, frame: first.system.frame(of: f)!) == f)
      h.start()
    }
    let a = h.system.open(app: "Mail", pid: 12)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(small().visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!)")
  }

  @Test(arguments: [false, true]) func aStripItsUserLeftIsStillAStripAfterAPause(makingWay: Bool) {
    let (h, a, b, f) = makeHarness(makingWay: makingWay)
    h.run("float \(b.rawValue)")
    h.system.close(b)
    let strip = CGRect(x: h.visibleFrame.maxX - 40, y: 200, width: 600, height: 400)
    h.system.userMove(f, to: strip)
    h.run("pause")
    h.run("resume")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == strip)
  }

  @Test(arguments: [false, true]) func aDisplayThatShrankDuringAPauseCountsToo(makingWay: Bool) {
    let h = Harness(settings: makingWay ? .makingWay : Settings())
    let f = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 64, y: 104, width: 230, height: 400))
    h.start()
    h.system.userMove(f, to: CGRect(x: 776, y: 135, width: 230, height: 400))
    h.run("pause")
    h.system.setDisplays([small()])
    h.run("resume")
    let a = h.system.open(app: "Mail", pid: 12)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(small().visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!)")
  }

  @Test func leftHangingOnTheShrunkenDisplayItMayHang() {
    let (h, a, b, f) = makeHarness()
    h.run("float \(b.rawValue)")
    h.system.close(b)
    h.system.setDisplays([small(1200, 800)])
    h.scheduler.advance(by: 1)
    let strip = CGRect(x: 1160, y: 200, width: 400, height: 300)
    h.system.userMove(f, to: strip)
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == strip, "chosen on the display as it is")
  }

  @Test(arguments: [false, true]) func anOverhangIsHonouredAgainWhenTheDisplayIsAsItWas(makingWay: Bool) {
    let (h, a, b, f) = makeHarness(makingWay: makingWay)
    h.run("float \(b.rawValue)")
    h.system.close(b)
    let strip = CGRect(x: h.visibleFrame.maxX - 40, y: 200, width: 600, height: 400)
    h.system.userMove(f, to: strip)
    h.system.setDisplays([small(1200, 800)])
    h.scheduler.advance(by: 1)
    #expect(small(1200, 800).visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!)")
    h.system.setDisplays([small(1000, 700)])
    h.scheduler.advance(by: 1)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 1)
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == strip)
  }

  @Test(arguments: [false, true]) func whatWouldHardlyShowIsNoPlace(makingWay: Bool) {
    let (h, a, b, f) = makeHarness(makingWay: makingWay)
    h.run("float \(b.rawValue)")
    h.system.close(b)
    h.system.userMove(f, to: CGRect(x: h.visibleFrame.maxX - 10, y: 200, width: 600, height: 400))
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.visibleFrame.contains(h.frame(f)!), "ten points are too little to see and grab: \(h.frame(f)!)")
  }

  // MARK: The order is macOS's (K087 said "floating means on top"; overruled by QUESTIONS Q20 and Q25)
  //
  // The first test below is rewritten to the decision. The five after it were the exceptions to K087's raise. They are left as they were: with no
  // raise to be excepted from they say less than they did, and each still names a moment at which a raise would do harm, should one come back.

  /// `[a | c | Desktop | b]`, and `f`, which cannot be narrower than 700, in the middle of a Desktop that is narrower: it
  /// hangs over `c` and `b`, and is behind them. `focused` says which of `a`, `c` and `f` has the keyboard.
  ///
  /// Floating windows make way here, as until Q20 (`floatingWindowsMakeWay`), unless a test says otherwise: it is a layout
  /// that moves `f` which raises it, and as Arbor ships no layout does.
  func withAWindowTooWideForTheDesktop(
    makingWay: Bool = true, focused: (WindowID, WindowID, WindowID) -> WindowID
  ) -> (Harness, a: WindowID, b: WindowID, c: WindowID, f: WindowID) {
    let h = Harness(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(
      app: "Xcode", pid: 13, frame: CGRect(x: 400, y: 300, width: 700, height: 300), minimumSize: CGSize(width: 700, height: 200))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) right")
    h.run("dock \(b.rawValue) right")
    #expect(h.layout!.tiles.isEmpty, "\(h.ascii())")
    for docked in [b, c] { #expect(h.frame(f)!.overlaps(h.frame(docked)!.insetBy(dx: 2, dy: 2)), "\(h.ascii())") }
    #expect(!h.frame(f)!.overlaps(h.frame(a)!), "\(h.ascii())")
    for window in [f, c, b, focused(a, c, f)] { h.system.userFocus(window) }
    h.system.clearRaiseLog()
    return (h, a, b, c, f)
  }

  /// Rewritten to the decision. This test said that it is brought to the front (K087). Q25: "the raise of windows left hanging over docked
  /// ones goes": Arbor raises nothing but a window kept in view. It keeps its place in the order, and can be had as any window
  /// that another one partly covers: what shows of it is there to be clicked, and ⌃⌥D shows all that floats.
  @Test func leftHangingOverADockedWindowByALayoutItKeepsItsPlaceInTheOrder() {
    let (h, a, b, c, f) = withAWindowTooWideForTheDesktop { a, _, _ in a }
    let before = h.frame(f)
    let order = h.system.windowsFrontToBack()
    for docked in [b, c] { #expect(order.firstIndex(of: f)! > order.firstIndex(of: docked)!, "it is behind both") }
    // The Desktop moves, and Xcode with it.
    h.run("resize \(c.rawValue) right 60")
    #expect(h.frame(f) != before)
    #expect(h.system.raiseLog.isEmpty)
    #expect(h.system.windowsFrontToBack() == order)
    #expect(h.system.focusedWindow() == a, "the keyboard stays where it is")
    let showing = h.frame(f)!.intersection(h.layout!.desktopFrame!)
    #expect(showing.width >= 100 && showing.height >= 100, "enough of it shows between them to be clicked: \(h.ascii())")
    h.run("desktop")
    #expect(h.system.isVisible(f) && ![a, b, c].contains { h.system.isVisible($0) }, "and on the Desktop nothing covers it")
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func notOverTheWindowThatHasTheKeyboard() {
    let (h, _, _, c, f) = withAWindowTooWideForTheDesktop { _, c, _ in c }
    let before = h.frame(f)
    h.run("resize \(c.rawValue) right 60")
    #expect(h.frame(f) != before)
    #expect(!h.system.raiseLog.contains(f), "Mail is being typed in")
  }

  @Test func notWhileHoldingStill() {
    let (h, _, _, c, f) = withAWindowTooWideForTheDesktop { a, _, _ in a }
    h.run("hold still")
    let before = h.frame(f)
    h.run("resize \(c.rawValue) right 60")
    #expect(h.frame(f) != before)
    #expect(!h.system.raiseLog.contains(f), "nothing changes places in front of an audience unasked")
  }

  @Test func alreadyInFrontItIsNotRaised() {
    let (h, _, _, c, f) = withAWindowTooWideForTheDesktop { _, _, f in f }
    let before = h.frame(f)
    h.run("resize \(c.rawValue) right 60")
    #expect(h.frame(f) != before)
    #expect(!h.system.raiseLog.contains(f))
  }

  @Test(arguments: [false, true]) func aLayoutThatDoesNotMoveItLeavesTheOrderAlone(makingWay: Bool) {
    // Mail and Notes were clicked after Xcode and cover part of it. That is their user's business.
    let (h, _, _, _, f) = withAWindowTooWideForTheDesktop(makingWay: makingWay) { a, _, _ in a }
    let before = h.frame(f)
    h.controller.apply(settings: h.controller.settings)
    h.run("relayout")
    #expect(h.frame(f) == before)
    #expect(h.system.raiseLog.isEmpty, "\(h.system.raiseLog)")
  }

  @Test func aWindowThatFitsTheDesktopIsNotRaised() {
    let (h, a, b, f) = makeHarness()
    h.system.userFocus(a)
    h.system.clearRaiseLog()
    h.run("resize \(b.rawValue) left 60")
    #expect(!h.system.raiseLog.contains(f))
  }

  @Test func theLeftEdgeOfTheScreenIsLikeTheRight() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(
      app: "Xcode", frame: CGRect(x: 300, y: 200, width: 600, height: 400), minimumSize: CGSize(width: 600, height: 300))
    h.start()
    let chosen = CGRect(x: -150, y: 300, width: 600, height: 400)
    h.system.userMove(f, to: chosen)
    h.run("dock \(a.rawValue) right")
    #expect(h.frame(f) == chosen, "the Desktop reaches that edge of the screen")
    // Safari grows until the Desktop is narrower than Xcode can be.
    h.run("resize \(a.rawValue) left 350")
    #expect(h.frame(f) == chosen, "it goes on hanging over the edge, and so covers as little of Safari as it can\n\(h.ascii())")
  }

  @Test func aWindowPutOverADockedWindowAndOverTheScreenEdgeOnPurposeStaysThere() {
    let (h, _, b, f) = makeHarness()
    // Over Notes, which is docked at the right edge, and on over that edge of the screen.
    let chosen = CGRect(x: h.frame(b)!.minX + 100, y: 300, width: 600, height: 300)
    #expect(chosen.maxX > h.visibleFrame.maxX + 100)
    h.system.userMove(f, to: chosen)
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 300, height: 300))
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    #expect(h.frame(f) == chosen, "what shows of it is over docked windows, where its user put it")
    h.system.setMinimized(c, true)
    h.system.setMinimized(c, false)
    #expect(h.frame(f) == chosen)
  }

  @Test func aWindowHangingOverTheScreenEdgeIsNotPulledInWhenNothingNeedsItsPlace() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Mail", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    for chosen in [
      CGRect(x: 1000, y: 300, width: 600, height: 400),  // far over the right edge
      CGRect(x: 1000, y: 700, width: 400, height: 400),  // over the bottom edge
      CGRect(x: 850, y: 300, width: 600, height: 400),  // ten points over the right edge
    ] {
      h.system.userMove(f, to: chosen)
      h.run("dock \(a.rawValue) left")
      #expect(h.frame(f) == chosen, "the Desktop reaches that edge of the screen")
      h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
      h.system.setMinimized(b, true)
      h.system.setMinimized(b, false)
      #expect(h.frame(f) == chosen, "nor is anything else a reason")
      h.run("zoom \(a.rawValue)")
      h.run("back")
      #expect(h.frame(f) == chosen, "and it comes back into view where it was")
      h.run("float-all")
    }
  }

  @Test func aWindowThatCannotShrinkToTheDesktopStaysOnTheScreen() {
    let h = Harness(settings: .makingWay)  // nothing is asked to shrink unless floating windows make way
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(
      app: "Xcode", frame: CGRect(x: 200, y: 200, width: 1000, height: 500),
      minimumSize: CGSize(width: 900, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(f)!.width == 900)
    #expect(h.visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!) hangs off the screen")
    #expect(h.frame(f)!.maxX == h.visibleFrame.maxX, "it covers as little docked space as it can")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.visibleFrame.contains(h.frame(f)!), "\(h.frame(f)!) hangs off the screen")
    // Once Arbor knows, other changes do not make the window twitch.
    let c = h.system.open(app: "Mail", frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    h.system.clearFrameLog()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    #expect(!h.system.frameLog.contains { $0.window == f })
    // And it goes back where the user had it when there is room again.
    h.run("float-all")
    #expect(h.frame(f) == CGRect(x: 200, y: 200, width: 1000, height: 500))
  }

  @Test func aChangeOfTheArrangementNeverSendsAFloatingWindowOutOfView() {
    let (h, a, _, f) = makeHarness()
    // Safari's right edge is pulled across the Desktop until it is too narrow to use.
    h.run("resize \(a.rawValue) right 300")
    #expect(h.layout!.desktopFrame == nil)
    #expect(h.layout!.tiles.map(\.kind) == [.desktop])
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300), "only a move of the view takes windows away")
    h.run("resize \(a.rawValue) right -300")
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300))
  }

  /// A command that leaves the view where it is changes nothing a person can see.
  @Test(arguments: ["home", "show-all", "zoom-out", "zoom n0"])
  func askingForTheViewThatIsAlreadyShowingTakesNothingAway(command: String) {
    let (h, a, _, f) = makeHarness()
    h.run("resize \(a.rawValue) right 300")
    #expect(h.layout!.desktopFrame == nil)
    let view = h.workspace.camera
    let place = h.frame(f)!
    h.run(command)
    #expect(h.workspace.camera == view)
    #expect(h.frame(f) == place, "`\(command)` sent it out of view")
  }

  @Test func framingTheFramedWindowAgainTakesNothingAway() {
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let place = CGRect(x: 400, y: 200, width: 500, height: 400)
    let f = h.system.open(app: "Calculator", frame: place)
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(f) == place)
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(f), "the view moved, so it went with the Desktop")
  }

  /// On a Mac, minimizing anything nudges the Dock, which is reported as a change of the displays.
  @Test func aChangeOfTheDisplaysThatMovesNoViewTakesNothingAway() {
    let (h, a, _, f) = makeHarness()
    h.run("resize \(a.rawValue) right 300")
    #expect(h.layout!.desktopFrame == nil)
    let place = h.frame(f)!
    var nudged = FakeWindowSystem.standardDisplay
    nudged.visibleFrame.size.height -= 2
    h.system.setDisplays([nudged])
    #expect(h.frame(f) == place)
  }

  /// Unless the change leaves it off the screen: then it is out of view, and switching to it brings it back.
  @Test func aWindowLeftOffTheScreenByASmallerDisplayCanStillBeSwitchedTo() {
    let (h, a, _, f) = makeHarness()
    h.run("resize \(a.rawValue) right 300")
    h.system.userMove(f, to: CGRect(x: 1100, y: 560, width: 320, height: 300))
    var smaller = FakeWindowSystem.standardDisplay
    smaller.frame.size = CGSize(width: 1024, height: 640)
    smaller.visibleFrame = CGRect(x: 0, y: 25, width: 1024, height: 615)
    h.system.setDisplays([smaller])
    h.system.userFocus(f)
    #expect(h.system.isVisible(f), "\(h.frame(f)!) is nowhere on a display of 1024 by 640")
    #expect(smaller.frame.contains(h.frame(f)!))
  }

  @Test func anUnrelatedMinimizeAndRestoreLeavesTheWindowBeingTypedInAlone() {
    // Five windows arranged leave the Desktop a tile. A new window opens over them and is being typed in.
    let h = Harness()
    let ids = ["A", "B", "C", "D", "E"].map { h.system.open(app: $0) }
    h.start()
    h.run("arrange")
    #expect(h.layout!.desktopFrame == nil)
    let place = CGRect(x: 300, y: 200, width: 500, height: 400)
    let f = h.system.open(app: "F", frame: place)
    h.system.userFocus(f)
    // Without E's column the Desktop is wide enough to use for a moment.
    h.system.setMinimized(ids[4], true)
    #expect(h.frame(f) == place, "not squeezed onto a Desktop that happens to show")
    h.system.setMinimized(ids[4], false)
    #expect(h.frame(f) == place, "and not sent out of view when it is a tile again")
  }

  @Test func aNewWindowItsAppOpenedOverDockedWindowsMakesWayLikeAnyOther() {
    let (h, a, _, _) = makeHarness(makingWay: true)
    // ⌘N: Safari offsets the new window a little from the docked one. Nobody put it there on purpose.
    let new = h.system.open(app: "Safari", frame: h.frame(a)!.offsetBy(dx: 30, dy: 30))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 600, y: 300, width: 300, height: 300))
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    #expect(isOnDesktop(new, h), "\(h.ascii())")
    // Once the user has moved it over a docked window, it stays.
    let chosen = h.frame(a)!.offsetBy(dx: 60, dy: 60)
    h.system.userMove(new, to: chosen)
    h.run("float \(c.rawValue)")
    #expect(h.frame(new) == chosen)
  }

  @Test func withNothingDockedBesideItAWindowMayTouchTheScreenEdge() {
    let (h, _, _, f) = makeHarness()
    let atTheEdge = CGRect(x: 0, y: 25, width: 320, height: 300)
    h.run("float-all")
    h.system.userMove(f, to: atTheEdge)
    let c = h.system.open(app: "Mail", frame: CGRect(x: 600, y: 300, width: 300, height: 300))
    h.run("dock \(c.rawValue) right")
    #expect(h.frame(f) == atTheEdge, "the gap is between windows, not a margin the Desktop keeps free")
    h.run("float-all")
    #expect(h.frame(f) == atTheEdge)
  }

  @Test func aWindowTooWideForTheDesktopCoversBothNeighboursAlikeAndNeitherWhollyNeedlessly() {
    let h = Harness(settings: .makingWay.withDesktopColumn)  // it is Arbor that places it: only while floating windows make way
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let f = h.system.open(
      app: "Xcode", frame: CGRect(x: 200, y: 150, width: 1000, height: 600), minimumSize: CGSize(width: 900, height: 500))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let desktop = h.layout!.desktopFrame!
    #expect(h.frame(f)!.width == 900)
    #expect(abs(h.frame(f)!.midX - desktop.midX) <= 1, "\(h.ascii())")
    #expect(h.visibleFrame.contains(h.frame(f)!))
  }

  // MARK: The Desktop as a tile is still part of the view

  /// "After ⌃⌥0 nothing is out of view, without exception." The gap the guide tells people to drag is one way in.
  @Test(arguments: [false, true]) func showingEverythingShowsTheFloatingWindowsAlsoWhenTheDesktopIsATile(makingWay: Bool) {
    for command in ["home", "show-all", "back", "out"] {
      let (h, a, _, f) = makeHarness(makingWay: makingWay)
      let place = h.frame(f)!
      h.run("resize \(a.rawValue) right 300")
      #expect(h.layout!.desktopFrame == nil && h.layout!.tiles.map(\.kind) == [.desktop])
      h.run("zoom \(a.rawValue)")
      #expect(!h.system.isVisible(f), "the Desktop is not part of this view")
      let order = h.system.windowsFrontToBack()
      h.system.clearRaiseLog()
      h.run(command)
      #expect(h.workspace.camera == h.workspace.tree.root)
      #expect(h.frame(f) == place, "`\(command)`: at its own frame, where the docked windows are too")
      // Rewritten to the decision. This said "and in front of them", which took a raise. Q20: "taking a window out of view and bringing it
      // back does not change its place in the order"; at Show Everything loose and docked windows may overlap; ⌃⌥D shows all that floats.
      #expect(h.system.windowsFrontToBack() == order && h.system.raiseLog.isEmpty, "`\(command)`: \(h.system.raiseLog)")
      #expect(h.layout!.tiles.map(\.kind) == [.desktop], "the arrangement is not touched, and the tile stays")
      h.run("desktop")
      let above = h.system.windowsFrontToBack().prefix { $0 != f }
      #expect(h.system.isVisible(f) && !above.contains { h.system.isVisible($0) && h.frame($0)!.overlaps(h.frame(f)!) }, "⌃⌥D after `\(command)`")
    }
  }

  /// ⌃⌥A with six windows leaves the Desktop a tile; one of them is framed, floated, and then everything is shown.
  @Test func aWindowFloatedWhileFramedIsThereWhenEverythingIsShown() {
    let h = Harness()
    let ids = ["A", "B", "C", "D", "E", "F"].map { h.system.open(app: $0) }
    h.start()
    h.run("set makeRoom off")
    h.run("arrange")
    #expect(h.layout!.desktopFrame == nil)
    h.system.userFocus(ids[0])
    h.run("zoom")
    h.run("float")
    h.run("home")
    #expect(h.system.isVisible(ids[0]), "\(h.ascii())")
  }

  /// Docking while looking at the Desktop nests it in a group. That group is a view the Desktop is part of.
  @Test func aGroupThatHoldsTheDesktopShowsItsWindowsToo() {
    let (h, a, b, f) = makeHarness()
    h.run("desktop")
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.run("dock \(c.rawValue) left")
    let group = h.workspace.camera
    #expect(group != h.workspace.tree.root && h.workspace.tree.subtree(group, contains: h.workspace.tree.desktop))
    h.run("resize \(c.rawValue) right 2000")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(f))
    h.run("zoom-node \(group.rawValue)")
    #expect(h.layout!.desktopFrame == nil, "\(h.ascii())")
    #expect(h.system.isVisible(f))
    _ = b
  }

  @Test func overATileNothingIsPushed() {
    let (h, a, b, f) = makeHarness()
    h.run("resize \(a.rawValue) right 300")
    let place = h.frame(f)!
    h.run("resize \(b.rawValue) left 40")
    h.system.setMinimized(b, true)
    h.system.setMinimized(b, false)
    #expect(h.frame(f) == place)
  }

  @Test func switchingToAFloatingWindowWhoseDesktopIsATileShowsIt() {
    let (h, a, b, f) = makeHarness(apart: true)
    let c = h.system.open(app: "Mail")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("resize \(a.rawValue) right 300")
    #expect(h.layout!.desktopFrame == nil)
    // From one window the level is kept: the Desktop fills the view.
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(f))
    h.system.userFocus(f)
    #expect(h.system.isVisible(f), "⌘Tab to a window must show it")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    // From a group the view steps out until the Desktop is part of it, tile or not.
    h.run("zoom \(b.rawValue)")
    h.run("out")
    #expect(!h.system.isVisible(f))
    h.system.userFocus(f)
    #expect(h.system.isVisible(f))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func aTitleChangeIsNotAMove() {
    // Squeezed, it is not at the frame remembered for it, which is what a report could spoil: floating windows make way here.
    let h = Harness(settings: .makingWay)
    let a = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Safari", frame: CGRect(x: 200, y: 200, width: 1000, height: 500))
    h.start()
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(f)!.width < 1000)
    // The page finishes loading: same frame, new title, reported like any change by the user.
    var snapshot = h.system.windows[f]!.snapshot
    snapshot.title = "A new page"
    h.controller.windowChanged(snapshot, userInitiated: true)
    #expect(h.workspace.floating[f] == CGRect(x: 200, y: 200, width: 1000, height: 500))
  }

  @Test func floatingAWindowOutOfAColumnPutsItOnTheDesktopNotOverItsOldNeighbour() {
    // Onto the Desktop only while floating windows make way. As Arbor ships it goes back to where it was before it was docked:
    // `FloatGivesThePlaceBackTests`.
    let (h, a, _, _) = makeHarness(makingWay: true)
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    #expect(h.run("float \(a.rawValue)").ok)
    // It has its own size back (F48), 600 wide, and the Desktop is narrower. It is on the Desktop as far as it fits
    // and hangs over on both sides alike, instead of lying where its slot was. A window that fits is wholly on the Desktop:
    // `whereFloatingWindowsMakeWayOneWindowIsPutOnTheDesktopAsBefore`.
    let desktop = h.layout!.desktopFrame!
    #expect(h.frame(a)!.size == CGSize(width: 600, height: 400))
    #expect(abs(h.frame(a)!.midX - desktop.midX) <= 1, "\(h.ascii())")
    #expect(h.frame(a)!.intersection(desktop).width == desktop.width)
    #expect(h.frame(a)!.intersection(h.frame(c)!).width < h.frame(c)!.width / 2, "most of its old neighbour shows")
  }

  @Test func floatAllPutsTheFramedWindowBackInItsPlaceToo() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(h.run("float-all").ok)
    // Where it floated before it was docked (F48). With nothing remembered that is where it would sit if
    // everything were shown: `withNothingRememberedFloatAllPutsTheFramedWindowInItsPlace`.
    #expect(h.frame(a) == CGRect(x: 100, y: 100, width: 600, height: 400), "not left as large as the display")
    #expect(h.system.isVisible(b))
  }

  @Test(arguments: [false, true])
  func aNewWindowOpenedWhileZoomedInStaysUntilTheCameraMovesAndComesBackWithTheDesktop(makingWay: Bool) {
    let (h, a, _, _) = makeHarness(makingWay: makingWay)
    h.run("zoom \(a.rawValue)")
    let frame = CGRect(x: 400, y: 200, width: 500, height: 400)
    let new = h.system.open(app: "Safari", frame: frame)
    h.system.userFocus(new)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "the camera stays")
    #expect(h.frame(new) == frame)
    h.run("show-all")
    #expect(h.system.isVisible(new))
    if makingWay {
      #expect(h.layout!.desktopFrame!.contains(h.frame(new)!))
    } else {
      #expect(h.frame(new) == frame, "where its app opened it, whatever is docked there")
    }
  }
}
