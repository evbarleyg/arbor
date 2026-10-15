import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// "At once, and in one piece" (collab/BOARD.md, 0.18): without motion every state between the first asking of an act and the last is on the
/// display for a frame or more. What must not be among them: `NotInOnePiece`.

/// As the second build ships: no motion, so no stage that hides the road.
private var light: Settings {
  var settings = Settings()
  settings.animationDuration = 0
  settings.focusRing = false
  return settings
}

/// So many windows, each of an app of its own, floating in a pile. `foretold`: the window system takes what it is foretold (`moveTogether`), so the
/// log of moves has the order of the forecasts. No Mac does yet: without, the log has the order in which `apply` asks.
@MainActor
private func pile(_ count: Int, _ settings: Settings = light, foretold: Bool = true) -> (Harness, [WindowID]) {
  let h = Harness(settings: settings)
  h.system.ignoresMoveTogether = !foretold
  let windows = (0..<count).map { index in
    h.system.open(
      app: "App\(index + 1)", pid: Int32(1001 + index),
      frame: CGRect(x: 120 + 40 * CGFloat(index), y: 90 + 30 * CGFloat(index), width: 520, height: 380))
  }
  h.start()
  return (h, windows)
}

/// Plays one act and says what was to be seen that should not have been.
@MainActor
private func seen(_ h: Harness, _ act: () -> Void) -> [NotInOnePiece] {
  let mark = h.system.moveLog.count
  act()
  h.scheduler.runPending()
  return h.system.notInOnePiece(since: mark)
}

@MainActor
private func expectInOnePiece(_ h: Harness, _ name: String, sourceLocation: SourceLocation = #_sourceLocation, _ act: () -> Void) {
  for problem in seen(h, act) { Issue.record("\(name): \(problem)", sourceLocation: sourceLocation) }
}

/// For an act that is known to show holes. How many states with a hole the net sees is written down: nobody adds one unseen, and whoever closes
/// one lowers the number here. It is a ratchet, not a measure: a change of gaps or of the cast changes it too.
/// They are of three kinds, and none is cured yet. Windows cross, each going to ground that another has yet to leave (Arrange Windows, the docks,
/// resume). The act does not go by the order at all (pause, quit, Float All: windows are let go by their numbers). An arrival of which nobody
/// knows whether it can grow is asked a question first, and so comes after the one that shrinks. What is ruled holds here too: no stray.
@MainActor
private func expectNoStray(
  _ h: Harness, _ name: String, holes known: Int, sourceLocation: SourceLocation = #_sourceLocation, _ act: () -> Void
) {
  let problems = seen(h, act)
  for problem in problems.filter(isStray) { Issue.record("\(name): \(problem)", sourceLocation: sourceLocation) }
  let holes = problems.filter(isHole)
  #expect(holes.count == known, "\(name): \(holes)", sourceLocation: sourceLocation)
}

private func isStray(_ problem: NotInOnePiece) -> Bool { if case .stray = problem { true } else { false } }
private func isHole(_ problem: NotInOnePiece) -> Bool { if case .hole = problem { true } else { false } }

/// The net itself, on orders whose truth is known: the window system is asked directly.
@MainActor
@Suite struct InOnePieceNetTests {
  let left = CGRect(x: 0, y: 25, width: 720, height: 875)
  let right = CGRect(x: 720, y: 25, width: 720, height: 875)
  let all = CGRect(x: 0, y: 25, width: 1440, height: 875)
  let corner = CGRect(x: 1439, y: 843, width: 720, height: 875)

  private func two() -> (FakeWindowSystem, WindowID, WindowID) {
    let system = FakeWindowSystem()
    return (system, system.open(app: "A", pid: 1, frame: left), system.open(app: "B", pid: 2, frame: right))
  }

  /// After whose asking there was a hole, all of it where the window on the right is before and after.
  private func holes(_ system: FakeWindowSystem) -> [WindowID] {
    system.notInOnePiece(since: 0).compactMap {
      guard case .hole(let ground, let window) = $0, right.contains(ground), ground.width > 700, ground.height > 800 else { return nil }
      return window
    }
  }

  @Test func theOneThatLeavesFirstLeavesAHole() {
    let (system, a, b) = two()
    _ = system.setFrame(corner, of: b)
    _ = system.setFrame(all, of: a)
    #expect(holes(system) == [b])
  }

  @Test func theOneThatGrowsFirstLeavesNone() {
    let (system, a, b) = two()
    _ = system.setFrame(all, of: a)
    _ = system.setFrame(corner, of: b)
    #expect(system.notInOnePiece(since: 0).isEmpty)
  }

  @Test func theOneThatShrinksBeforeTheOtherIsBackLeavesAHole() {
    let system = FakeWindowSystem()
    let (a, b) = (system.open(app: "A", pid: 1, frame: all), system.open(app: "B", pid: 2, frame: corner))
    _ = system.setFrame(left, of: a)
    _ = system.setFrame(right, of: b)
    #expect(holes(system) == [a])
  }

  @Test func groundThatIsBareBeforeOrAfterIsNoHole() {
    let (system, _, b) = two()
    _ = system.setFrame(corner, of: b)
    #expect(system.notInOnePiece(since: 0).isEmpty)
  }

  @Test func aStateWithinNeitherFrameIsAStray() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", pid: 1, frame: CGRect(x: 800, y: 500, width: 300, height: 200))
    // By hand, as two askings: the new size at the old place. That it hangs over the edge there lets nothing off: it is where the asking ends.
    _ = system.setFrame(CGRect(x: 800, y: 500, width: 720, height: 875), of: a)
    _ = system.setFrame(left, of: a)
    #expect(system.notInOnePiece(since: 0).contains(where: isStray))
  }

  /// The ruling's exception: it cannot grow once it hangs over the edge, so it is sized where it is, and that is let off.
  @Test func growingIntoAFrameThatHangsOverTheEdgeIsLetOffTheStateBetween() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", pid: 1, frame: CGRect(x: 100, y: 100, width: 300, height: 200))
    let over = CGRect(x: 1200, y: 100, width: 400, height: 300)
    #expect(system.setFrame(over, of: a) == over, "whole")
    #expect(FakeWindowSystem.states(of: system.moveLog[0], rooms: [CGRect(x: 0, y: 0, width: 1440, height: 900)]).first == CGRect(x: 100, y: 100, width: 400, height: 300))
    #expect(system.notInOnePiece(since: 0).isEmpty)
  }

  /// The knob by itself: named last, the window that only moves is there first; two windows of one app keep their order.
  @Test func sideBySideAPlaceAloneIsDoneBeforeAResize() {
    let system = FakeWindowSystem()
    system.appsWorkSideBySide = true
    let a = system.open(app: "A", pid: 1, frame: CGRect(x: 0, y: 25, width: 300, height: 200))
    let b = system.open(app: "B", pid: 2, frame: CGRect(x: 400, y: 25, width: 300, height: 200))
    let c = system.open(app: "A", pid: 1, frame: CGRect(x: 800, y: 25, width: 300, height: 200))
    system.moveTogether([
      (a, CGRect(x: 0, y: 25, width: 350, height: 200)), (c, CGRect(x: 800, y: 300, width: 300, height: 200)),
      (b, CGRect(x: 400, y: 300, width: 300, height: 200)),
    ])
    #expect(system.moveLog.map(\.window) == [b, a, c])
  }

  @Test func statesWithinTheOldFrameOrTheNewOneAreNot() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", pid: 1, frame: CGRect(x: 100, y: 100, width: 300, height: 200))
    // Moved first, then grown.
    _ = system.setFrame(CGRect(x: 0, y: 25, width: 300, height: 200), of: a)
    _ = system.setFrame(left, of: a)
    #expect(!system.notInOnePiece(since: 0).contains(where: isStray))
  }

  @Test func whatNoDisplayShowsIsSeenByNobody() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", pid: 1, frame: corner)
    _ = system.setFrame(CGRect(x: 1439, y: 843, width: 300, height: 200), of: a)
    _ = system.setFrame(CGRect(x: 1439, y: 843, width: 900, height: 700), of: a)
    #expect(system.notInOnePiece(since: 0).isEmpty)
  }
}

/// The acts that were filmed, with four windows and with eight.
@MainActor
@Suite struct InOnePieceTests {
  /// What grows, what crosses, what shrinks. The one that shrinks bares ground that the one that crosses is to cover, so it waits for it.
  @Test func theOrder() {
    let h = Harness(settings: light)
    let shrinks = h.system.open(app: "A", pid: 1001, frame: CGRect(x: 0, y: 25, width: 960, height: 875))
    let crosses = h.system.open(app: "B", pid: 1002, frame: CGRect(x: 960, y: 25, width: 480, height: 400))
    let grows = h.system.open(app: "C", pid: 1003, frame: CGRect(x: 960, y: 425, width: 480, height: 475))
    h.start()
    let order = h.controller.inOnePiece([
      shrinks: CGRect(x: 480, y: 25, width: 480, height: 875), crosses: CGRect(x: 0, y: 25, width: 480, height: 875),
      grows: CGRect(x: 960, y: 25, width: 480, height: 875),
    ])
    #expect(order.map { $0.window } == [grows, crosses, shrinks])
  }

  @Test(arguments: [4, 8], [true, false]) func arrangeWindows(_ count: Int, foretold: Bool) {
    let (h, _) = pile(count, foretold: foretold)
    expectNoStray(h, "arrange", holes: count == 4 ? 2 : 15) { h.run("arrange") }
  }

  @Test(arguments: [4, 8], [true, false]) func fillEverythingAndBack(_ count: Int, foretold: Bool) {
    let (h, windows) = pile(count, foretold: foretold)
    h.run("arrange")
    h.system.userFocus(windows[1])
    expectInOnePiece(h, "fill, the first time") { h.run("zoom") }
    expectInOnePiece(h, "everything") { h.run("show-all") }
    expectInOnePiece(h, "back") { h.run("back") }
    expectInOnePiece(h, "fill again: back to everything") { h.run("zoom") }
    expectInOnePiece(h, "fill, the second time") { h.run("zoom") }
  }

  /// A window system that moves windows together lets apps work side by side, and to leave is a place alone: foretold with the one that
  /// grows, those who leave would be gone first, every time, and the desk show through until it has grown. So they are foretold by themselves.
  @Test(arguments: [4, 8]) func withAppsSideBySideWhatLeavesStillGoesLast(_ count: Int) {
    let (h, windows) = pile(count)
    h.system.appsWorkSideBySide = true
    h.run("arrange")
    h.system.userFocus(windows[1])
    expectInOnePiece(h, "fill, the first time") { h.run("zoom") }
    expectInOnePiece(h, "everything") { h.run("show-all") }
    expectInOnePiece(h, "fill, the second time") { h.run("zoom") }
    expectWindowsMatchLayout(h)
  }

  /// Two forecasts, and still nobody waits unannounced, however few are in one: with two windows one fills the screen and one leaves.
  @Test func oneThatStaysAndOneThatLeavesAreBothForetold() {
    let (h, windows) = pile(2)
    h.run("arrange")
    h.system.userFocus(windows[0])
    let mark = h.system.moveLog.count
    h.run("zoom")
    let moves = Array(h.system.moveLog[mark...])
    let (moved, unannounced) = (moves.map { $0.window }, moves.filter { !$0.together }.map { $0.window })
    #expect(moved == [windows[0], windows[1]], "the one that grows, then the one that leaves")
    #expect(unannounced == [])
    #expect(h.system.answersAhead.isEmpty, "and every answer was claimed")
  }

  @Test(arguments: [true, false]) func eachDock(foretold: Bool) {
    let (h, windows) = pile(4, foretold: foretold)
    for (index, window) in windows.enumerated() {
      h.system.userFocus(window)
      expectNoStray(h, "dock \(index + 1)", holes: [0, 0, 5, 4][index]) { h.run(index % 2 == 0 ? "dock left" : "dock right") }
    }
  }

  @Test(arguments: [true, false]) func floatAndUndo(foretold: Bool) {
    let (h, windows) = pile(4, foretold: foretold)
    h.run("arrange")
    h.system.userFocus(windows[0])
    expectInOnePiece(h, "float") { h.run("float") }
    expectInOnePiece(h, "undo") { h.run("undo") }
  }

  @Test(arguments: [true, false]) func pauseAndResume(foretold: Bool) {
    let (h, _) = pile(4, foretold: foretold)
    h.run("arrange")
    expectNoStray(h, "pause", holes: 2) { h.run("pause") }
    expectNoStray(h, "resume", holes: 2) { h.run("resume") }
  }

  @Test(arguments: [true, false]) func quit(foretold: Bool) {
    let (h, _) = pile(4, foretold: foretold)
    h.run("arrange")
    expectNoStray(h, "quit", holes: 2) { h.controller.shutdown() }
  }

  @Test(arguments: [true, false]) func floatAll(foretold: Bool) {
    let (h, _) = pile(4, foretold: foretold)
    h.run("arrange")
    expectNoStray(h, "float all", holes: 2) { h.run("float-all") }
  }

  /// Two of four have closed while a third filled the screen, so the one that comes back finds a wider slot than it has ever had: it is asked
  /// whether it can grow so far, out of view, and comes when the one that filled the screen has shrunk.
  @Test(arguments: [true, false]) func anArrivalThatIsAskedAQuestionComesAfterTheOneThatShrinks(foretold: Bool) {
    let (h, windows) = pile(4, foretold: foretold)
    h.run("arrange")
    h.system.userFocus(windows[1])
    h.run("zoom")
    h.system.close(windows[0])
    h.system.close(windows[2])
    h.scheduler.runPending()
    expectNoStray(h, "everything", holes: foretold ? 1 : 2) { h.run("show-all") }
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [true, false]) func aDockedWindowCloses(foretold: Bool) {
    let (h, windows) = pile(4, foretold: foretold)
    h.run("arrange")
    expectInOnePiece(h, "close") { h.system.close(windows[2]) }
  }
}
