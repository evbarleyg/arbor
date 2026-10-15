import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Arbor starts, and macOS does not say yet who has the keyboard: whatever started Arbor is still in front, or the app is slow to
/// answer. The window that has it is a tile with everything showing, goes to the corner like any other, and a moment later the
/// report comes. The view used to go to it, and every other window left (`Controller+LetBe.swift`, "A report that comes late").
@Suite @MainActor struct LateReportAtAStartTests {
  let fixtures = LaunchLetsBeTests()

  /// Started with nobody named. The player stood in view and is in the corner, behind its tile.
  func startedBeforeMacOSSaysWhoHasTheKeyboard(
    _ change: (Harness) -> Void = { _ in }
  ) -> (Harness, player: WindowID, browser: WindowID, notes: WindowID, stood: CGRect) {
    let (h, player, browser, notes, _) = fixtures.quitWithTheKeyboardInThePlayer()
    change(h)
    let stood = h.frame(player)!
    h.system.focused = nil
    h.start()
    #expect(!h.system.isVisible(player) && h.controller.windowLetBe == nil && h.workspace.camera == h.workspace.tree.root)
    return (h, player, browser, notes, stood)
  }

  func expectTheViewFollowed(_ h: Harness, _ player: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(h.controller.windowLetBe == nil, sourceLocation: sourceLocation)
    #expect(h.workspace.camera != h.workspace.tree.root, "as at any switch to a tile", sourceLocation: sourceLocation)
    #expect(h.layout?.windowFrames[player] != nil && h.system.isVisible(player), sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, sourceLocation: sourceLocation)
  }

  @Test func itIsPutBackWhereTheStartFoundItAndLetBe() {
    let (h, player, browser, notes, stood) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    let (corner, mark) = (h.frame(player)!, h.system.focusLog.count)
    let others = [browser, notes].map { h.frame($0) }
    h.scheduler.advance(by: 0.3)
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == player)
    #expect(fixtures.moves(of: player, h).suffix(2) == [corner, stood], "out, and back in one request: \(fixtures.moves(of: player, h))")
    #expect(h.frame(player) == stood && h.system.isVisible(player))
    #expect(h.workspace.camera == h.workspace.tree.root, "the view stays on everything")
    #expect([browser, notes].map { h.frame($0) } == others, "and nobody else moves")
    #expect(h.system.focusedWindow() == player && fixtures.focused(h, since: mark) == [], "the keyboard was there all along")
    #expect(h.workspace.isDocked(player) && h.layout?.tiles.contains { $0.windows.contains(player) } == true)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
    // From here on it is let be like one that was named in time.
    #expect(h.run("show-all").ok)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == nil && !h.system.isVisible(player) && h.system.focusedWindow() != player)
    expectWindowsMatchLayout(h)
  }

  /// Made small in the corner, it has its size again with its place.
  @Test func withItsOwnSizeInTheSameRequest() {
    let (h, player, _, _, stood) = startedBeforeMacOSSaysWhoHasTheKeyboard { h in
      var settings = h.controller.settings
      settings.shrinkOutOfView = true
      h.controller.apply(settings: settings)
    }
    let before = fixtures.moves(of: player, h).count
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == player && h.frame(player) == stood)
    #expect(fixtures.moves(of: player, h).count == before + 1, "\(fixtures.moves(of: player, h))")
  }

  /// Whoever has clicked or pressed something since the start has switched to it, and gets what a switch gets.
  @Test func afterAClickOrAKeyItIsASwitch() {
    for click in [true, false] {
      let (h, player, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
      h.scheduler.advance(by: 0.3)
      if click {
        h.system.userFocus(player)
      } else {
        h.system.secondsSinceInput = 0.1
        h.system.comesForward(player)
      }
      fixtures.settle(h)
      expectTheViewFollowed(h, player)
    }
  }

  /// What started Arbor was pressed before the start.
  @Test func theClickThatStartedArborIsNoSwitch() {
    let (h, player, _, _, stood) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    h.scheduler.advance(by: 0.3)
    h.system.secondsSinceInput = 0.5
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == player && h.frame(player) == stood)
  }

  @Test func afterTheFirstSecondItIsASwitch() {
    let (h, player, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    h.scheduler.advance(by: 1.2)
    h.system.comesForward(player)
    fixtures.settle(h)
    expectTheViewFollowed(h, player)
  }

  /// A script's command is nobody's click. A layout or a view somebody asked for is theirs all the same.
  @Test(arguments: ["relayout", "show-all", "home"]) func afterACommandItIsASwitch(line: String) {
    let (h, player, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    _ = h.run(line)
    h.system.comesForward(player)
    fixtures.settle(h)
    expectTheViewFollowed(h, player)
  }

  /// macOS says once who had the keyboard. The next report is a change.
  @Test func theFirstReportIsTheLateOne() {
    let (h, player, browser, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    h.system.comesForward(browser)
    h.scheduler.advance(by: 0.2)
    h.system.comesForward(player)
    fixtures.settle(h)
    expectTheViewFollowed(h, player)
  }

  /// The end of a pause is a start too.
  @Test func alsoAfterAPause() {
    let (h, player, _, _, _) = fixtures.launched()
    #expect(h.run("pause").ok)
    fixtures.settle(h)
    let stood = h.frame(player)!
    h.system.focused = nil
    #expect(h.run("resume").ok)
    #expect(!h.system.isVisible(player))
    h.scheduler.advance(by: 0.2)
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == player && h.frame(player) == stood)
    #expect(h.workspace.camera == h.workspace.tree.root)
    expectWindowsMatchLayout(h)
  }

  /// The keyboard is in the browser, and macOS says so in time.
  @Test func whereMacOSNamedAWindowInTimeThereIsNothingToWaitFor() {
    let (h, player, browser, _, _) = fixtures.launched()
    h.system.userFocus(browser)
    fixtures.settle(h)
    #expect(h.run("pause").ok)
    fixtures.settle(h)
    #expect(h.run("resume").ok)
    #expect(!h.system.isVisible(player) && h.system.focusedWindow() == browser)
    h.system.comesForward(player)
    fixtures.settle(h)
    expectTheViewFollowed(h, player)
  }

  /// A crash left it in the corner. Nobody saw it when Arbor started, so there is no place to put it back to.
  @Test func oneThatTheStartFoundInTheCornerIsNotFetched() {
    let (first, player, _, notes, _) = fixtures.launched()
    first.system.userFocus(notes)
    #expect(first.run("show-all").ok)
    fixtures.settle(first)
    #expect(!first.system.isVisible(player))
    first.system.focused = nil
    let h = first.newProcess()
    h.start()
    h.system.comesForward(player)
    fixtures.settle(h)
    expectTheViewFollowed(h, player)
  }

  /// Its app did not answer when Arbor started: it named no window and could not be sent away. It stands where it stood.
  @Test func oneWhoseAppDidNotAnswerGetsNoFrameAtAll() {
    let (h, player, browser, notes, _) = fixtures.quitWithTheKeyboardInThePlayer()
    let stood = h.frame(player)!
    h.system.focused = nil
    h.system.setUnresponsive(pid: 11, true)
    h.start()
    h.scheduler.advance(by: 0.3)
    h.system.setUnresponsive(pid: 11, false)
    h.system.comesForward(player)
    #expect(h.controller.windowsOwedAMove.isEmpty, "nothing is owed to a window that is let be")
    fixtures.settle(h)
    fixtures.expectLetBe(h, player, at: stood)
    #expect(h.system.isVisible(browser) && h.system.isVisible(notes))
  }

  /// Its neighbours go into the Dock within the second, and there is room for it: it has its place, like any docked window.
  @Test func oneThatHasGotAPlaceMeanwhileKeepsIt() {
    let (h, player, browser, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    let mail = h.system.allWindows().first { $0.appName == "Mail" }!.id
    h.system.setMinimized(browser, true)
    h.system.setMinimized(mail, true)
    h.scheduler.advance(by: 0.5)
    guard let place = h.layout?.windowFrames[player] else {
      Issue.record("the fixture: it has no place: \(h.ascii())")
      return
    }
    h.system.comesForward(player)
    #expect(h.controller.windowLetBe == nil)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == nil && h.frame(player) == place)
    expectWindowsMatchLayout(h)
  }

  /// An app that does not move when asked, or not yet, answers with the corner. Nobody is let be there: the view goes to it, as
  /// it did, and the frame it has of its own is still the one the start found.
  @Test func oneThatDoesNotComeBackIsFollowed() {
    let (h, player, _, _, stood) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    h.system.setBehaviour(player, .frozen)
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == nil && h.workspace.camera != h.workspace.tree.root)
    h.system.setBehaviour(player, .normal)
    fixtures.settle(h)
    h.controller.shutdown()
    #expect(h.frame(player) == stood)
  }

  /// A view that is held turns away whoever comes forward unasked.
  @Test func aViewThatIsHeldStaysAsItIs() {
    let (h, player, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    #expect(h.run("hold").ok)
    let view = h.workspace.camera
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == nil && !h.system.isVisible(player) && h.workspace.camera == view)
  }

  /// A display is plugged in to the left within the second, and its own moves to the right. Where the start found it is
  /// on the other display now.
  @Test func itIsNotPutOnAnotherDisplay() {
    let (h, player, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    let main = FakeWindowSystem.standardDisplay
    h.system.setDisplays([
      DisplaySnapshot(
        id: DisplayID("side"), frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true, isBuiltIn: false),
      DisplaySnapshot(
        id: main.id, frame: main.frame.offsetBy(dx: 1920, dy: 0), visibleFrame: main.visibleFrame.offsetBy(dx: 1920, dy: 0),
        isMain: false, isBuiltIn: true),
    ])
    h.system.comesForward(player)
    fixtures.settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(h.frame(player).map { $0.midX > 1920 } == true, "\(String(describing: h.frame(player)))")
  }

  /// Nothing is kept beyond the second.
  @Test func nothingIsKept() {
    let (h, _, _, _, _) = startedBeforeMacOSSaysWhoHasTheKeyboard()
    fixtures.settle(h)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(!h.scheduler.pendingKeys.contains("focus-late-report"))
  }
}
