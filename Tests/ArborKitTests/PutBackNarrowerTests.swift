import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Found by the chaos lab (K1436). People leave windows hanging over the edge of the screen, and a window that leaves the
/// arrangement goes back where it was (F48). But an app has the last word on its window's size: one that stays narrower than
/// it was can end up beyond the edge altogether, where neither Show Everything nor quitting looks for it.
@Suite @MainActor struct PutBackNarrowerTests {
  /// Finder's window hangs over the left edge, more than half of it in view; it is docked, and from then on stays narrow.
  func makeHarness() -> (Harness, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 133, width: 853, height: 206))
    h.start()
    h.system.userMove(a, to: CGRect(x: -386, y: 133, width: 853, height: 206))
    #expect(h.system.isVisible(a), "more than half of it shows")
    #expect(h.run("dock \(a.rawValue) right").ok)
    h.system.setMaximumSize(a, CGSize(width: 252, height: 869))
    return (h, a)
  }

  @Test(arguments: ["float", "float-all", "pause"])
  func aWindowThatComesBackNarrowerIsNotLeftBeyondTheEdgeItHungOver(command: String) throws {
    let (h, a) = makeHarness()
    #expect(h.run(command).ok)
    let frame = try #require(h.frame(a))
    #expect(h.system.isVisible(a), "it is at \(frame)")
    #expect(h.visibleFrame.contains(frame), "it is at \(frame)")
  }

  @Test func norWhenArborQuits() throws {
    let (h, a) = makeHarness()
    h.controller.shutdown()
    let frame = try #require(h.frame(a))
    #expect(h.system.isVisible(a), "it is at \(frame)")
    #expect(h.visibleFrame.contains(frame), "it is at \(frame)")
  }

  /// What the user chose stays: a window that keeps its size goes back over the edge, as far as it hung.
  @Test func aWindowThatKeepsItsSizeGoesBackOverTheEdge() {
    let (h, a) = makeHarness()
    h.system.setMaximumSize(a, nil)
    #expect(h.run("float-all").ok)
    #expect(h.frame(a) == CGRect(x: -386, y: 133, width: 853, height: 206))
  }
}
