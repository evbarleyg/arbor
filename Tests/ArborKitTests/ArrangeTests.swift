import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// `arrange` and `float-all`, the two commands that redo everything.
@Suite @MainActor struct ArrangeTests {
  /// `[a | Desktop | b]` with `f` floating on the Desktop.
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

  @Test func arrangingWhileZoomedInKeepsTheOrderTheWindowsHad() {
    let (h, a, b, f) = makeHarness()
    h.run("zoom \(b.rawValue)")
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows == [a, f, b], "left to right as they were, not as they were parked")
  }

  // MARK: Pressed again

  /// Seven windows, two of which will not go below a size no slot of the grid has, so they are tiles.
  private func gridWithTiles() -> (h: Harness, windows: [WindowID]) {
    let h = Harness()
    var windows: [WindowID] = []
    for index in 0..<7 {
      let origin = CGPoint(x: 40 + 150 * index, y: 60 + 40 * (index % 3))
      let stubborn = index == 1 || index == 4
      windows.append(
        h.system.open(
          app: "App\(index)", frame: CGRect(origin: origin, size: CGSize(width: 400, height: 300)),
          minimumSize: stubborn ? CGSize(width: 900, height: 700) : .zero))
    }
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.layout!.tiles.count >= 2, "the two that refuse wait in a corner")
    return (h, windows)
  }

  /// A window that is a tile, a tab behind another, minimized or out of view is not where its place is. Sorted
  /// by where it was, it went to the end of the grid, and the rest moved up.
  @Test(.withTiles) func arrangingWhatIsArrangedChangesNothing() {
    let (h, _) = gridWithTiles()
    let (tree, frames) = (h.workspace.tree, h.system.allWindows().map(\.frame))
    for press in 2...4 {
      #expect(h.run("arrange").ok)
      #expect(h.workspace.tree.allWindows == tree.allWindows, "press \(press)")
      #expect(h.workspace.tree == tree && h.system.allWindows().map(\.frame) == frames, "press \(press)")
    }
  }

  @Test(.withTiles) func alsoWhileZoomedInOnOneOfThem() {
    let (h, windows) = gridWithTiles()
    let order = h.workspace.tree.allWindows
    h.run("zoom \(windows[5].rawValue)")
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows == order)
  }

  @Test(.withTiles) func aMinimizedWindowAndAHiddenAppKeepTheirPlaces() {
    let (h, windows) = gridWithTiles()
    let order = h.workspace.tree.allWindows
    h.system.setMinimized(windows[0], true)
    h.system.userMove(windows[0], to: CGRect(x: 1200, y: 700, width: 400, height: 300))
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows == order)
  }

  /// Tabs have one place between them. They stay next to each other, in their order.
  @Test func tabsBecomeNeighboursInTheirOrder() {
    var settings = Settings()
    settings.tabsEnabled = true
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.drag(f, through: [CGPoint(x: 720, y: 310), h.frame(a)!.center])
    #expect(h.workspace.tree.allWindows == [a, f, b] && !h.system.isVisible(a), "a is the tab behind, and out of view")
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows == [a, f, b])
  }

  /// Nothing may hang on the order of a dictionary: new windows often open in the very same spot.
  @Test func floatingWindowsInTheSameSpotGoByTheirNumbers() {
    let h = Harness()
    let windows = (0..<12).map { h.system.open(app: "App\($0)") }
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows == windows)
  }

  // MARK: What is lost

  @Test func theReplyNamesWhatIsLost() {
    let (h, a, b, _) = makeHarness()
    #expect(h.run("arrange").message == "arranged 3 windows", "nothing to lose, nothing said")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    #expect(h.run("arrange").message == "arranged 3 windows; 1 saved view is gone")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    h.run("zoom \(b.rawValue)")
    h.run("save-view 2")
    h.run("name Writing")
    #expect(h.run("arrange").message == "arranged 3 windows; 2 saved views are gone; 1 name is gone")
    h.run("zoom \(b.rawValue)")
    h.run("save-view 9")
    #expect(h.run("arrange all").message == "arranged 3 windows; 1 saved view is gone")
  }

  /// Every command that starts the arrangement afresh, with a view saved on a window, another on a group, and the
  /// group named. Nobody sees a saved view or a name go, so the reply says it, in the same words everywhere.
  @Test(arguments: [
    ("arrange", "arranged 3 windows; 2 saved views are gone; 1 name is gone"),
    ("arrange all", "arranged 3 windows; 2 saved views are gone; 1 name is gone"),
    ("float-all", "floated 3 windows; 2 saved views are gone; 1 name is gone"),
    ("float-all here", "floated 3 windows; 2 saved views are gone; 1 name is gone"),
    ("layout Desktop", "arranged 0 windows, floated 3; 2 saved views are gone; 1 name is gone"),
    ("layout Gamma | Beta | Alpha", "arranged 3 windows; 1 saved view is gone; 1 name is gone"),
    ("layout Alpha | Desktop", "arranged 1 window, floated 2; 1 saved view is gone; 1 name is gone"),
  ]) func whateverStartsAfreshSaysWhatWentWithTheOldArrangement(command: String, reply: String) {
    let h = Harness()
    let ids = ["Alpha", "Beta", "Gamma"].map { h.system.open(app: $0) }
    h.start()
    h.run("layout Alpha | (Beta / Gamma) | Desktop")
    h.run("zoom \(ids[0].rawValue)")
    h.run("save-view 1")
    h.run("zoom-node \(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: ids[1])!)!.rawValue)")
    h.run("save-view 2")
    h.run("name Pair")
    h.run("show-all")
    #expect(h.run(command).message == reply)
  }

  @Test func aCommandThatFailsOrLosesNothingSaysNothingOfTheKind() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    #expect(!h.run("layout Nobody").message.contains("gone"))
    #expect(h.workspace.savedViews.count == 1)
    #expect(!h.run("dock \(a.rawValue) right").message.contains("gone"))
  }

  @Test func observersHearThatTheCameraHistoryAndViewsWereReset() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    var changes: [Controller.Change] = []
    h.controller.observe { changes.append($0) }
    h.run("arrange")
    #expect(changes.contains(.camera(h.display)))
    #expect(changes.contains(.savedViews(h.display)))
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    changes.removeAll()
    h.run("float-all")
    #expect(changes.contains(.camera(h.display)))
    #expect(changes.contains(.savedViews(h.display)))
  }

  @Test func arrangeLeavesMinimizedFloatingWindowsAlone() {
    let (h, _, _, f) = makeHarness()
    h.system.setMinimized(f, true)
    h.run("arrange")
    #expect(h.workspace.isFloating(f))
    h.system.setMinimized(f, false)
    #expect(h.system.isVisible(f))
  }

  @Test func floatAllAfterArrangeShowsEveryWindow() {
    let (h, a, b, f) = makeHarness()
    h.run("arrange")
    h.run("zoom \(f.rawValue)")
    h.run("float-all")
    for window in [a, b, f] {
      #expect(h.system.isVisible(window))
      #expect(h.workspace.isFloating(window))
    }
    #expect(h.controller.parked.isEmpty)
  }
}
