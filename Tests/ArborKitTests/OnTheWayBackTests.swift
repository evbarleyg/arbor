import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Backlog K963. A window that has only just come back (out of the Dock, with its app, from another macOS Space) may not be
/// ready to take a frame. What it answers in that moment says nothing about what its app allows.
@Suite @MainActor struct OnTheWayBackTests {
  /// `[a | b | Desktop]`, with `b` minimized at a size larger than the slot it will come back to.
  func makeHarness(flight: Double) -> (Harness, a: WindowID, b: WindowID) {
    let h = Harness()
    h.system.echoes.flightFromTheDock = flight
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 100, y: 100, width: 1000, height: 700))
    h.start()
    h.system.setMinimized(b, true)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    #expect(h.frame(b)!.width == 1000)
    return (h, a, b)
  }

  @Test func aWindowStillFlyingOutOfTheDockIsNotTakenToRefuseItsSlot() {
    let (h, _, b) = makeHarness(flight: 0.3)
    let view = h.workspace.camera
    h.system.setMinimized(b, false)
    #expect(h.layout!.tiles.isEmpty, "its old size is not a refusal\n\(h.ascii())")
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == view, "so the view has no reason to go to it")
    #expect(h.layout!.tiles.isEmpty)
    #expect(h.layout!.windowFrames[b] != nil)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func norIsOneThatIsSmallerThanItsSlotTakenToBeUnableToGrow() {
    let h = Harness()
    h.system.echoes.flightFromTheDock = 0.3
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 100, y: 100, width: 300, height: 200))
    h.start()
    h.system.setMinimized(b, true)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.system.setMinimized(b, false)
    #expect(h.frame(b)!.size == CGSize(width: 300, height: 200), "still flying")
    h.scheduler.advance(by: 1)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theWayBackFromFullScreenTakesLonger() {
    let h = Harness()
    h.system.echoes.flightFromFullScreen = 0.9
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.setFullScreen(b, true)
    // Its slot is wider when it comes back than the frame macOS gives it back.
    h.run("float \(a.rawValue)")
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    #expect(h.frame(b) == h.layout!.windowFrames[b], "\(h.ascii())")
  }

  @Test func aWindowThatClosesDuringAPauseIsForgotten() {
    // Found by the chaos lab's leak rule, once it was told of this list.
    let (h, _, b) = makeHarness(flight: 0.3)
    h.system.setMinimized(b, false)
    h.run("pause")
    h.system.close(b)
    h.run("resume")
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  @Test func aClockThatStandsStillDoesNotHaveArborAskForEver() {
    let (h, _, b) = makeHarness(flight: 0.3)
    h.system.setMinimized(b, false)
    // Runs what is scheduled without moving the clock: the window is still "flying" when it is asked again.
    h.scheduler.runPending()
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("landed") })
  }

  @Test func aPauseInTheMiddleOfItIsSafe() {
    let (h, _, b) = makeHarness(flight: 0.3)
    h.system.setMinimized(b, false)
    h.run("pause")
    h.system.clearFrameLog()
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.isEmpty, "paused, Arbor moves nothing")
  }

  @Test func aWindowThatClosesInTheMiddleOfItIsForgotten() {
    let (h, a, b) = makeHarness(flight: 0.3)
    h.system.setMinimized(b, false)
    h.system.close(b)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.tree.allWindows == [a])
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowThatReallyRefusesStillBecomesATileAMomentLater() {
    let (h, _, b) = makeHarness(flight: 0)
    // Without F61, which would make room for it first.
    h.run("set makeRoom off")
    h.system.setMinimumSize(b, CGSize(width: 1000, height: 700))
    h.system.setMinimized(b, false)
    h.scheduler.advance(by: 1)
    h.run("show-all")
    #expect(h.layout!.tiles.flatMap(\.windows) == [b], "\(h.ascii())")
  }

  @Test func withoutAFlightNothingIsAskedTwice() {
    let (h, _, b) = makeHarness(flight: 0)
    h.system.clearFrameLog()
    h.system.setMinimized(b, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.filter { $0.window == b }.count == 1)
    expectWindowsMatchLayout(h, on: h.display)
  }
}
