import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// macOS's own full screen is left to macOS (T63), also for a window Arbor already arranges.
@Suite @MainActor struct FullScreenTests {
  /// `[a | Desktop | b]` with `f` floating.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, f)
  }

  /// The green button on `window`: it fills the display on a new Space, which slides into view.
  func enterFullScreen(_ h: Harness, _ window: WindowID, others: [WindowID]) {
    h.system.setFullScreen(window, true)
    for other in others { h.system.setOnActiveSpace(other, false) }
    h.scheduler.advance(by: 2)
  }

  func leaveFullScreen(_ h: Harness, _ window: WindowID, others: [WindowID]) {
    h.system.setFullScreen(window, false)
    for other in others { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
  }

  @Test func aDockedWindowThatGoesFullScreenIsLeftAlone() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    h.system.clearFrameLog()
    enterFullScreen(h, a, others: [b, f])
    #expect(h.frame(a) == FakeWindowSystem.standardDisplay.frame)
    #expect(!h.system.frameLog.contains { $0.window == a }, "Arbor must not try to move it")
    #expect(h.overlays.tiles[h.display]?.isEmpty == true, "nothing of Arbor's may cover a full-screen window")
    #expect(h.overlays.seams[h.display]?.isEmpty == true)
    #expect(!h.controller.parked.contains(a))
    #expect(h.workspace.isDocked(a), "it keeps its slot")

    leaveFullScreen(h, a, others: [b, f])
    #expect(h.frame(a) == slot)
    #expect(h.layout!.tiles.isEmpty, "and is not taken for a window that refuses to shrink")
    #expect(h.system.isVisible(b) && h.system.isVisible(f))
  }

  @Test func theNeighboursOfAFullScreenWindowTakeItsSpaceOnTheirOwnSpace() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    // Back to the first Space with a swipe; Safari stays full screen on its own.
    h.system.setOnActiveSpace(a, false)
    for other in [b, f] { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[a] == nil)
    #expect(h.layout!.windowFrames[b] != nil)
    #expect(h.layout!.desktopFrame!.minX == h.visibleFrame.minX + 12, "the Desktop has Safari's space")
  }

  @Test func aFloatingWindowThatGoesFullScreenKeepsTheFrameTheUserGaveIt() {
    let (h, a, b, f) = makeHarness()
    let chosen = h.frame(f)!
    enterFullScreen(h, f, others: [a, b])
    #expect(h.workspace.floating[f] == chosen)
    leaveFullScreen(h, f, others: [a, b])
    #expect(h.frame(f) == chosen)
  }

  @Test func commandsOnAFullScreenWindowAreRefused() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.system.focused = a
    let tree = h.workspace.tree
    for command in ["dock right", "float", "toggle-float", "zoom", "resize right 50", "dock \(a.rawValue) left"] {
      let result = h.run(command)
      #expect(!result.ok, "\(command)")
      #expect(result.message.contains("full screen"), "\(command): \(result.message)")
    }
    #expect(h.workspace.tree == tree)
    #expect(h.workspace.camera == tree.root)
  }

  @Test func quittingLeavesAFullScreenWindowAlone() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(!h.system.frameLog.contains { $0.window == a })
  }
}
