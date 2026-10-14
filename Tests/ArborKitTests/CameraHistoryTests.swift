import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Back, forward and saved views while the arrangement changes under them.
@Suite @MainActor struct CameraHistoryTests {
  /// `[a / c | Desktop | b]`.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    return (h, a, b, c)
  }

  func leaf(_ h: Harness, _ window: WindowID) -> NodeID? { h.workspace.tree.leaf(containing: window) }

  @Test func aSavedViewOfAWindowFollowsItWhenItIsMoved() {
    let (h, _, _, c) = makeHarness()
    h.run("zoom \(c.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    // Mail steps out of Safari's column.
    #expect(h.run("dock \(c.rawValue) right").ok)
    #expect(h.run("view 1").ok)
    #expect(h.workspace.camera == leaf(h, c), "view 1 was Mail on its own and still is")
    #expect(h.frame(c) == h.visibleFrame.insetBy(dx: 12, dy: 12))
  }

  @Test func backReturnsToAWindowThatWasMovedMeanwhile() {
    let (h, _, _, c) = makeHarness()
    h.run("zoom \(c.rawValue)")
    h.run("show-all")
    h.run("dock \(c.rawValue) right")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == leaf(h, c))
  }

  @Test func aSavedViewOfAWindowFollowsItWhenItIsDraggedElsewhere() {
    let (h, _, b, c) = makeHarness()
    h.run("zoom \(c.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    let target = h.frame(b)!
    h.system.drag(c, through: [h.frame(c)!.center, CGPoint(x: target.midX, y: target.maxY - 20)])
    #expect(h.frame(c)!.minY > h.frame(b)!.maxY)
    h.run("view 1")
    #expect(h.workspace.camera == leaf(h, c))
  }

  @Test func backNeverLandsWhereTheCameraAlreadyIsAndNeverRepeats() {
    let (h, a, b, c) = makeHarness()
    for window in [a, c, b, a, c] { h.run("zoom \(window.rawValue)") }
    h.system.close(c)
    h.system.close(a)
    var seen = [h.workspace.camera]
    while h.run("back").ok {
      #expect(h.workspace.camera != seen.last, "back did nothing visible")
      #expect(h.workspace.tree.contains(h.workspace.camera))
      seen.append(h.workspace.camera)
      if seen.count > 20 { break }
    }
    #expect(seen.count <= 6)
  }

  @Test func zoomingOnTheFramedWindowAgainAddsNoHistory() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("zoom \(a.rawValue)")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(!h.run("back").ok)
  }

  @Test func theEdgesOfTheWorldSaySo() {
    let (h, a, _, _) = makeHarness()
    #expect(!h.run("out").ok)
    #expect(!h.run("neighbor left").ok)
    h.run("zoom \(a.rawValue)")
    #expect(!h.run("in").ok)
    #expect(!h.run("neighbor left").ok)
    #expect(!h.run("neighbor up").ok)
    #expect(h.run("neighbor down").ok)
    #expect(h.workspace.camera != leaf(h, a))
  }

  @Test func arrangeAndFloatAllStartHistoryAfresh() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    h.run("arrange")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(!h.run("back").ok)
    #expect(!h.run("view 1").ok)
    h.run("zoom \(a.rawValue)")
    h.run("float-all")
    #expect(!h.run("back").ok)
  }
}
