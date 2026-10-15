import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Written for the audit of `collab/parity.json`. Each test checks, in
/// a user's terms, a claim whose listed tests only came near it: they ran the command without looking
/// at the result, or tested the pure function and never the command.
@Suite @MainActor struct ParityProofTests {
  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)

  /// Three floating windows of three apps, started.
  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()
  ) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 1003, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  /// [ [a / c] | Desktop | b ]
  func dockThree(_ h: Harness, _ a: WindowID, _ b: WindowID, _ c: WindowID) {
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
  }

  func leaf(_ h: Harness, _ window: WindowID) -> NodeID? { h.workspace.tree.leaf(containing: window) }

  // MARK: Camera

  /// T30
  @Test func showAllReturnsToEverythingFromAnyDepth() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let overview = [a, b, c].map { h.frame($0)! }
    h.run("zoom \(c.rawValue)")
    #expect(h.workspace.camera == leaf(h, c))
    #expect(!h.system.isVisible(a) && !h.system.isVisible(b))

    #expect(h.run("show-all").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect([a, b, c].map { h.frame($0)! } == overview)
    #expect(h.controller.parked.isEmpty)
    #expect(h.layout?.desktopFrame != nil)
  }

  /// T33
  @Test func theNeighbourCommandWalksSidewaysAndStopsAtTheEnds() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let full = h.visibleFrame.insetBy(dx: 12, dy: 12)
    h.run("zoom \(a.rawValue)")

    #expect(h.run("neighbor down").ok)
    #expect(h.workspace.camera == leaf(h, c))
    #expect(h.frame(c) == full)
    #expect(!h.run("neighbor down").ok, "nothing is below c")
    #expect(h.run("neighbor up").ok)
    #expect(h.workspace.camera == leaf(h, a))

    #expect(h.run("neighbor right").ok)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.layout?.desktopFrame == full)
    #expect(h.run("neighbor right").ok)
    #expect(h.frame(b) == full)
    #expect(!h.system.isVisible(a) && !h.system.isVisible(c))
    #expect(!h.run("neighbor right").ok, "nothing is right of b")
    #expect(h.workspace.camera == leaf(h, b), "a move that fails leaves the camera alone")

    #expect(h.run("neighbor left").ok)
    #expect(h.run("neighbor left").ok)
    // Left of the Desktop is the whole column, not one of its windows.
    #expect(h.workspace.camera == h.workspace.tree.parent(of: leaf(h, a)!))
    #expect(h.system.isVisible(a) && h.system.isVisible(c) && !h.system.isVisible(b))
  }

  /// T34
  @Test func forwardRetracesWhatBackUndid() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    h.run("zoom \(a.rawValue)")
    h.run("zoom \(b.rawValue)")
    #expect(!h.run("forward").ok, "nothing has been undone yet")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == leaf(h, a))
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(!h.run("back").ok)

    #expect(h.run("forward").ok)
    #expect(h.workspace.camera == leaf(h, a))
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(h.run("forward").ok)
    #expect(h.workspace.camera == leaf(h, b))
    #expect(!h.system.isVisible(a))
    #expect(!h.run("forward").ok)

    // Going somewhere new forgets what lay ahead, as in a browser.
    h.run("back")
    h.run("zoom \(c.rawValue)")
    #expect(!h.run("forward").ok)
  }

  /// T35: nine views
  @Test func nineViewsAreKeptApart() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let places: [NodeID] = [
      h.workspace.tree.root, leaf(h, a)!, leaf(h, b)!, leaf(h, c)!, h.workspace.tree.desktop,
      h.workspace.tree.parent(of: leaf(h, a)!)!, leaf(h, a)!, leaf(h, b)!, leaf(h, c)!,
    ]
    for (index, node) in places.enumerated() {
      h.run("zoom-node \(node.rawValue)")
      #expect(h.run("save-view \(index + 1)").ok)
    }
    for (index, node) in places.enumerated().reversed() {
      #expect(h.run("view \(index + 1)").ok)
      #expect(h.workspace.camera == node, "view \(index + 1)")
    }
    #expect(!h.run("save-view 10").ok)
    #expect(!h.run("save-view 0").ok)
  }

  /// T03, and ⌃⌥D
  @Test func theDesktopCommandShowsTheDesktopAndItsFloatingWindowsOnly() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("desktop").ok)
    #expect(h.layout?.desktopFrame == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(a) && !h.system.isVisible(b))
    #expect(h.system.isVisible(c), "floating windows live on the Desktop")
  }

  /// T30 to T35: the keyboard table TrellisWM publishes, key by key, and
  /// A01's four. Swapping two directions in `KeyBindings.defaults` went unnoticed before this.
  @Test func theDefaultShortcutsAreTheOnesTrellisWMPublishes() throws {
    var published: [String: Command] = [
      "ctrl+opt+space": .showAll, "ctrl+opt+up": .stepOut, "ctrl+opt+down": .stepIn, "ctrl+opt+return": .zoom(nil),
      "ctrl+opt+left": .neighbor(.left), "ctrl+opt+right": .neighbor(.right), "ctrl+opt+[": .back, "ctrl+opt+]": .forward,
      "ctrl+opt+cmd+left": .dock(nil, .left), "ctrl+opt+cmd+right": .dock(nil, .right),
      "ctrl+opt+cmd+up": .dock(nil, .top), "ctrl+opt+cmd+down": .dock(nil, .bottom),
    ]
    for slot in 1...9 {
      published["ctrl+opt+shift+\(slot)"] = .saveView(slot)
      published["ctrl+opt+\(slot)"] = .goToView(slot)
    }
    for (text, command) in published {
      let chord = try KeyChord(text: text)
      #expect(KeyBindings.defaults.first { $0.chord == chord }?.command == command, "\(text)")
    }
  }

  // MARK: Arrangement

  /// T06
  @Test func aLeavingWindowsSpaceIsSharedByTheWholeRow() {
    var settings = Settings()
    settings.minimumUsableWidth = 100  // four in a row on this display, and none of them a tile
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) right")
    // [a | b | c | Desktop], of different widths.
    let before = [h.frame(a)!.width, h.frame(c)!.width, h.layout!.desktopFrame!.width]
    #expect(Set(before).count > 1)
    h.system.close(b)
    let after = [h.frame(a)!.width, h.frame(c)!.width, h.layout!.desktopFrame!.width]
    let growth = zip(after, before).map { $0 / $1 }
    for factor in growth {
      #expect(factor > 1.1, "everyone in the row gains, not only the neighbour")
      #expect(abs(factor - growth[0]) < 0.02, "in proportion to what they had: \(growth)")
    }
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// T07's "also for hidden apps (⌘H)"
  @Test func hidingAnAppGivesItsSpaceAwayAndShowingItBringsItBack() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let before = [a, b, c].map { h.frame($0)! }
    h.system.setHidden(pid: 1003, true)
    #expect(h.frame(a)!.height == h.visibleFrame.insetBy(dx: 12, dy: 12).height)
    #expect(h.workspace.isDocked(c), "it keeps its place in the tree")
    h.system.clearFrameLog()
    h.system.setHidden(pid: 1003, false)
    #expect([a, b, c].map { h.frame($0)! } == before)
  }

  /// T07, as macOS reports it: the focus change comes first, the un-minimize after it (collab/evidence/ax-events.txt,
  /// "un-minimize 33"). Until #17 the camera zoomed onto the window. T07
  /// goes back to shipped when the step "minimize a docked window and bring it back" of proof.sh has passed on a Mac.
  @Test func unMinimizingPutsTheWindowBackAndLeavesTheCameraAlone() {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let before = [a, b, c].map { h.frame($0)! }
    h.system.setMinimized(c, true)
    h.system.userFocus(c)
    h.system.setMinimized(c, false)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect([a, b, c].map { h.frame($0)! } == before)
    #expect(h.controller.parked.isEmpty)
  }

  /// T05: "nothing else moves"
  @Test func aSeamDragMovesNothingButItsTwoNeighbours() throws {
    let (h, a, b, c) = makeHarness()
    dockThree(h, a, b, c)
    let column = h.workspace.tree.parent(of: leaf(h, a)!)!
    let seam = try #require(h.overlays.seams[h.display]?.first { $0.leading == column })
    let (oldA, oldB, oldC, oldDesktop) = (h.frame(a)!, h.frame(b)!, h.frame(c)!, h.layout!.desktopFrame!)
    h.overlays.dragSeam(seam, by: 70)
    #expect(h.frame(b) == oldB)
    #expect(h.frame(a)!.width == oldA.width + 70 && h.frame(c)!.width == oldC.width + 70)
    #expect(h.frame(a)!.height == oldA.height && h.frame(c)!.height == oldC.height)
    #expect(h.layout!.desktopFrame!.width == oldDesktop.width - 70)
    #expect(h.layout!.desktopFrame!.maxX == oldDesktop.maxX)
  }

  /// T17, T62: the way out has to work from wherever the camera is.
  @Test func floatAllBringsBackWindowsThatWereOutOfView() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked == [b, c])
    #expect(h.run("float-all").ok)
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.controller.parked.isEmpty)
    for window in [a, b, c] { #expect(h.system.isVisible(window), "\(window)") }
    #expect(h.overlays.tiles[h.display]?.isEmpty == true && h.overlays.seams[h.display]?.isEmpty == true)
    #expect(!h.run("float-all").ok, "nothing is docked any more")
  }

  /// T18: the menu item names the app in front.
  @Test func excludeWithoutABundleIDTakesTheFocusedApp() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    #expect(h.run("exclude").ok)
    #expect(h.controller.settings.excludedBundleIDs == ["com.example.safari"])
    #expect(!h.workspace.contains(a) && h.workspace.isDocked(b))
    // Left alone from now on: nothing Arbor does moves it.
    h.system.clearFrameLog()
    h.run("zoom \(b.rawValue)")
    h.run("arrange")
    #expect(!h.system.frameLog.contains { $0.window == a })
    #expect(!h.run("dock \(a.rawValue) left").ok)
  }

  /// ⌃⌥F
  @Test func toggleFloatUndocksAndDocksAgain() {
    let (h, a, _, _) = makeHarness()
    h.system.userFocus(a)
    #expect(h.run("toggle-float").ok)
    #expect(h.workspace.isDocked(a))
    #expect(h.run("toggle-float").ok)
    #expect(h.workspace.isFloating(a))
    #expect(h.system.isVisible(a))
  }

  // MARK: Displays

  /// T44: "dragging a window to another display joins it to that display's arrangement"
  @Test func draggingAWindowToAnotherDisplayJoinsThatDisplaysArrangement() {
    let (h, a, b, c) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let side = Self.side

    // A docked window, dropped at the far edge of the other display.
    let start = h.frame(b)!
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(
      b, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 1600, y: 400), CGPoint(x: side.frame.maxX - 3, y: 400)])
    #expect(!h.workspace.contains(b))
    #expect(h.controller.workspaces[side.id]!.isDocked(b))
    #expect(h.frame(b)!.maxX == side.visibleFrame.maxX - 12)
    #expect(h.overlays.previewHistory.compactMap { $0 }.last == h.frame(b), "the preview was on that display too")
    #expect(h.workspace.tree.allWindows == [a], "and its old display closes the gap")
    expectWindowsMatchLayout(h, on: h.display)
    expectWindowsMatchLayout(h, on: side.id)

    // A floating window, dropped beside it.
    let target = h.frame(b)!
    let from = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: from.midX, y: from.minY + 10), CGPoint(x: target.minX + 20, y: target.midY)])
    #expect(h.controller.workspaces[side.id]!.tree.allWindows == [c, b])
    #expect(h.frame(c)!.maxX < h.frame(b)!.minX)

    // And onto the other display's Desktop: it floats there.
    let slot = h.frame(a)!
    let desktop = h.controller.layouts[side.id]!.desktopFrame!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), desktop.center])
    #expect(h.controller.workspaces[side.id]!.isFloating(a))
    #expect(!h.workspace.contains(a))
  }

  /// T44 and T35: "each display keeps its own spaces and camera", "nine per display"
  @Test func eachDisplayKeepsItsOwnCameraHistoryAndSavedViews() {
    let (h, a, b, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let side = Self.side
    let d = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let e = h.system.open(app: "Terminal", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(d.rawValue) left")
    h.run("dock \(e.rawValue) right")
    func sideSpace() -> Workspace { h.controller.workspaces[side.id]! }
    #expect(sideSpace().tree.allWindows == [d, e])

    // Camera commands act on the display under the pointer.
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("zoom \(d.rawValue)")
    h.run("save-view 1")
    #expect(sideSpace().camera == sideSpace().tree.leaf(containing: d))
    #expect(h.workspace.camera == h.workspace.tree.root, "the other display does not move")
    #expect(h.system.isVisible(a) && h.system.isVisible(b) && !h.system.isVisible(e))

    h.system.cursor = CGPoint(x: 700, y: 300)
    #expect(!h.run("view 1").ok, "view 1 was saved on the other display")
    #expect(!h.run("back").ok, "and so was the history")
    h.run("zoom \(b.rawValue)")
    h.run("save-view 1")
    h.run("show-all")

    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("show-all")
    #expect(h.run("view 1").ok)
    #expect(sideSpace().camera == sideSpace().tree.leaf(containing: d))
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  // MARK: Stacks (the model behind T12)

  @Test func focusingAnInactiveTabShowsItInTheSameSlot() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    let from = h.frame(b)!
    h.system.drag(b, through: [CGPoint(x: from.midX, y: from.minY + 10), slot.center])
    #expect(leaf(h, a) == leaf(h, b), "dropped on the middle, it joins the stack")
    #expect(h.frame(b) == slot && !h.system.isVisible(a))

    h.system.userFocus(a)  // ⌘` or a click in the Dock
    #expect(h.frame(a) == slot && !h.system.isVisible(b))
    #expect(h.workspace.camera == h.workspace.tree.root, "the camera has no reason to move")
    #expect(h.system.isVisible(c))
  }
}
