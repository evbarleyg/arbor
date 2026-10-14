import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The `expect` forms of scenario scripts (collab/README.md, "Scenarios"), as arbor-sim checks them.
@Suite @MainActor struct ScenarioExpectationTests {
  /// Nil when the expectation holds, otherwise why not.
  func expect(_ line: String, _ h: Harness, lastCommandOK: Bool = true) -> String? {
    ScenarioExpectation.check(
      line.split(separator: " ").map(String.init), harness: h, lastCommandOK: lastCommandOK)
  }

  @Test func dockedFloatingCountCameraAndNeighbours() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    #expect(expect("floating \(a.rawValue)", h) == nil)
    #expect(expect("docked \(a.rawValue)", h) == "w\(a.rawValue) is not docked")
    #expect(expect("count docked 0", h) == nil)
    #expect(expect("camera root", h) == nil)
    #expect(expect("camera desktop", h) == nil, "with nothing docked, the root is the Desktop")

    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(expect("camera desktop", h)?.hasPrefix("the camera is on") == true)
    #expect(expect("docked \(a.rawValue)", h) == nil)
    #expect(expect("floating \(a.rawValue)", h) == "w\(a.rawValue) is docked")
    #expect(expect("count docked 2", h) == nil)
    #expect(expect("count docked 1", h) == "2 window(s) are docked, not 1")
    #expect(expect("left-of \(a.rawValue) \(b.rawValue)", h) == nil)
    #expect(expect("left-of \(b.rawValue) \(a.rawValue)", h)?.contains("is not left of") == true)
    #expect(expect("camera root", h) == nil)
    #expect(expect("camera \(a.rawValue)", h)?.hasPrefix("the camera is on") == true)
  }

  @Test func zoomFillsHidesAndMovesTheCamera() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Calculator", frame: CGRect(x: 500, y: 300, width: 300, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(expect("visible \(c.rawValue)", h) == nil, "a floating window on the Desktop shows")
    #expect(expect("fills \(a.rawValue)", h)?.contains("is at") == true)

    h.run("zoom \(a.rawValue)")
    #expect(expect("camera \(a.rawValue)", h) == nil)
    #expect(expect("camera root", h) != nil)
    #expect(expect("fills \(a.rawValue)", h) == nil)
    #expect(expect("visible \(a.rawValue)", h) == nil)
    #expect(expect("hidden \(b.rawValue)", h) == nil)
    #expect(expect("visible \(b.rawValue)", h)?.hasPrefix("w\(b.rawValue) is parked") == true)
    #expect(expect("hidden \(c.rawValue)", h) == nil, "floating windows leave with the Desktop")
    #expect(expect("hidden \(a.rawValue)", h)?.contains("is visible") == true)

    h.run("desktop")
    #expect(expect("camera desktop", h) == nil)
    #expect(expect("visible \(c.rawValue)", h) == nil)
  }

  @Test func aboveTilesAndMinimizedWindows() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let m = h.system.open(app: "Mail")
    let x = h.system.open(
      app: "Xcode", frame: CGRect(x: 300, y: 200, width: 700, height: 500),
      minimumSize: CGSize(width: 1200, height: 600))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(m.rawValue) beside \(a.rawValue) bottom")
    #expect(expect("above \(a.rawValue) \(m.rawValue)", h) == nil)
    #expect(expect("above \(m.rawValue) \(a.rawValue)", h)?.contains("is not above") == true)
    #expect(expect("tile \(a.rawValue)", h) == "w\(a.rawValue) is not inside a tile")

    // Xcode refuses to shrink into half a column, and wants more than the others could spare (F61), so it becomes a tile.
    h.run("dock \(x.rawValue) beside \(b.rawValue) bottom")
    #expect(expect("docked \(x.rawValue)", h) == nil)
    #expect(expect("tile \(x.rawValue)", h) == nil)
    #expect(expect("hidden \(x.rawValue)", h) == nil)
    #expect(expect("visible \(x.rawValue)", h) != nil)

    h.system.setMinimized(b, true)
    #expect(expect("hidden \(b.rawValue)", h) == nil)
    #expect(expect("visible \(b.rawValue)", h) == "w\(b.rawValue) is minimized")
    h.system.setMinimized(b, false)
    #expect(expect("visible \(b.rawValue)", h) == nil)
  }

  @Test func okFailUnknownFormsAndMissingWindows() {
    let h = Harness()
    h.start()
    #expect(expect("ok", h, lastCommandOK: true) == nil)
    #expect(expect("ok", h, lastCommandOK: false) == "the previous command failed")
    #expect(expect("fail", h, lastCommandOK: false) == nil)
    #expect(expect("fail", h, lastCommandOK: true) == "the previous command succeeded")
    #expect(expect("teleport 101", h)?.hasPrefix("unknown expectation `teleport 101`") == true)
    #expect(expect("docked", h)?.hasPrefix("cannot read `docked`") == true)
    #expect(expect("docked 999", h) == "there is no window w999")
    #expect(expect("hidden 999", h) == "there is no window w999")
    #expect(expect("count docked many", h)?.hasPrefix("cannot read") == true)
  }

  @Test func size() {
    let h = Harness()
    let a = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    h.start()
    #expect(expect("size \(a.rawValue) 400x300", h) == nil)
    #expect(expect("size \(a.rawValue) 400x301", h) == nil, "to the point")
    #expect(expect("size \(a.rawValue) 640x300", h) == "w\(a.rawValue) at (300,200 400×300) is not 640x300 in size")
    #expect(expect("size 999 400x300", h) == "there is no window w999")
    for line in ["size \(a.rawValue) 400", "size \(a.rawValue) 400x", "size \(a.rawValue) axb", "size x 1x1", "size 1"] {
      #expect(expect(line, h)?.hasPrefix("cannot read") == true, "\(line)")
    }
  }

  @Test func focusedSaysWhoHasTheKeyboard() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    #expect(expect("focused \(a.rawValue)", h) == "no window has the keyboard, not w\(a.rawValue)")
    h.system.userFocus(b)
    #expect(expect("focused \(b.rawValue)", h) == nil)
    #expect(expect("focused \(a.rawValue)", h) == "w\(b.rawValue) has the keyboard, not w\(a.rawValue)")
    #expect(expect("focused", h)?.hasPrefix("cannot read `focused`") == true)
  }
}
