import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Scenario tests: the real Controller against the fake window system.
@Suite @MainActor struct ControllerTests {
  /// Three floating windows, started.
  /// `apart`: each app is a process of its own, as a story about ⌘Tab needs. Otherwise they are one, and a switch among them is ⌘`.
  func makeHarness(settings: Settings = Settings(), apart: Bool = false) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: apart ? 11 : 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: apart ? 12 : 1000, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: apart ? 13 : 1000, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  @Test func startAdoptsExistingWindowsAsFloating() {
    let (h, a, b, c) = makeHarness()
    #expect(h.workspace.floating.keys.sorted() == [a, b, c])
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.system.frameLog.isEmpty, "starting must not move anything")
  }

  @Test func dockingBuildsColumnsAndTheDesktopIsWhatIsLeftOver() {
    let (h, a, b, c) = makeHarness()
    let content = h.visibleFrame.insetBy(dx: 12, dy: 12)
    #expect(h.run("dock \(a.rawValue) left").ok)
    // The first has a half. The other half is left over: the Desktop.
    let desktop = h.layout!.desktopFrame!
    #expect(desktop.minX - h.frame(a)!.maxX == 12 && desktop.maxX == content.maxX)
    #expect(desktop.width == h.frame(a)!.width)
    // The second takes all of that, and the first stays as it is.
    let half = h.frame(a)!
    #expect(h.run("dock \(b.rawValue) right").ok)
    #expect(h.frame(b) == desktop)
    #expect(h.frame(a) == half)
    #expect(h.layout!.desktopFrame == nil)
    #expect(h.run("dock \(c.rawValue) beside \(a.rawValue) bottom").ok)
    expectWindowsMatchLayout(h)
    #expect(h.frame(a)!.minX == content.minX)
    #expect(h.frame(b)!.maxX == content.maxX)
    #expect(h.frame(c)!.minY > h.frame(a)!.maxY)
  }

  /// With the option on: the Desktop has a share of its own among docked windows.
  @Test func dockingBuildsColumnsWithTheDesktopBetween() {
    let (h, a, b, c) = makeHarness(settings: .withDesktopColumn)
    #expect(h.run("dock \(a.rawValue) left").ok)
    #expect(h.run("dock \(b.rawValue) right").ok)
    #expect(h.run("dock \(c.rawValue) beside \(a.rawValue) bottom").ok)
    expectWindowsMatchLayout(h)
    let content = h.visibleFrame.insetBy(dx: 12, dy: 12)
    #expect(h.frame(a)!.minX == content.minX)
    #expect(h.frame(b)!.maxX == content.maxX)
    #expect(h.frame(c)!.minY > h.frame(a)!.maxY)
    let desktop = h.layout!.desktopFrame!
    #expect(desktop.minX > h.frame(a)!.maxX && desktop.maxX < h.frame(b)!.minX)
  }

  @Test(arguments: [false, true]) func zoomParksTheOthersAndBackRestoresThem(makingWay: Bool) {
    let (h, a, b, c) = makeHarness(settings: makingWay ? .makingWay : Settings())
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let (before, floated) = (h.frame(a)!, h.frame(c)!)
    #expect(h.run("zoom \(a.rawValue)").ok)
    #expect(h.frame(a) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(b))
    #expect(h.system.isVisible(c) == !makingWay, "floating windows leave with the Desktop only if they make way")
    if !makingWay { #expect(h.frame(c) == floated, "as Arbor ships no view takes one away, or moves it") }
    #expect(h.controller.parked == (makingWay ? [b, c] : [b]))
    #expect(h.run("back").ok)
    #expect(h.frame(a) == before && h.frame(c) == floated)
    #expect(h.system.isVisible(b) && h.system.isVisible(c))
    #expect(h.controller.parked.isEmpty)
  }

  @Test func stepInAndOutFollowThePointer() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    // (In a corner of b: over its middle lies c, which floats, and over a floating window the pointer means that.)
    h.system.cursor = CGPoint(x: h.frame(b)!.maxX - 20, y: h.frame(b)!.maxY - 20)
    #expect(h.run("in").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.run("out").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(!h.run("out").ok)
  }

  @Test func focusMovesOffAWindowThatLeavesTheView() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.focus(b)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.focused == a)
  }

  @Test func minimizingGivesTheSpaceToNeighbours() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    let full = h.visibleFrame.insetBy(dx: 12, dy: 12)
    h.system.setMinimized(c, true)
    #expect(h.frame(a)!.height == full.height)
    h.system.setMinimized(c, false)
    #expect(h.frame(a)!.height < full.height)
    #expect(h.frame(c)!.minY > h.frame(a)!.maxY)
    expectWindowsMatchLayout(h)
  }

  @Test func closingAZoomedWindowMovesTheCameraUp() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(c.rawValue)")
    h.system.close(c)
    #expect(h.workspace.tree.contains(h.workspace.camera))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(h.system.isVisible(a))
    // Up means to what the column became: a on its own, not everything.
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(!h.system.isVisible(b))
  }

  @Test func windowsThatWillNotShrinkBecomeTilesAndTilesZoomIn() {
    let (h, a, b, _) = makeHarness()
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    // More than its neighbours and the Desktop could spare between them (F61).
    h.system.setMinimumSize(big, CGSize(width: 1200, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let tiles = h.overlays.tiles[h.display] ?? []
    #expect(tiles.map(\.kind) == [.window])
    #expect(tiles.first?.items.first?.window == big)
    #expect(!h.system.isVisible(big))
    #expect(h.system.isVisible(b))

    h.overlays.clickTile(tiles[0].node)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: big))
    #expect(h.system.isVisible(big))
    #expect(h.overlays.tiles[h.display]?.isEmpty == true)
  }

  @Test func draggingToAScreenEdgeDocks() {
    let (h, a, _, _) = makeHarness()
    let start = h.frame(a)!
    let grab = CGPoint(x: start.midX, y: start.minY + 10)
    let edge = CGPoint(x: 3, y: 450)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [grab, CGPoint(x: 200, y: 400), edge])
    #expect(h.workspace.isDocked(a))
    #expect(h.frame(a)!.minX == h.visibleFrame.minX + 12)
    // The preview showed exactly where it landed.
    #expect(h.overlays.previewHistory.compactMap { $0 }.last == h.frame(a))
    #expect(h.overlays.preview == nil)
  }

  @Test func draggingADockedWindowOntoTheDesktopFloatsIt() {
    let (h, a, b, _) = makeHarness()
    // [a / b] | Desktop: a second dock in the row would leave no Desktop to drop a window on.
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let desktop = h.layout!.desktopFrame!
    let start = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: start.midX, y: start.minY + 10), desktop.center])
    #expect(h.workspace.isFloating(a))
    #expect(h.workspace.tree.allWindows == [b])
  }

  @Test func draggingADockedWindowBackOntoItselfSnapsBack() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let slot = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: slot.midX + 30, y: slot.midY)])
    #expect(h.workspace.isDocked(a))
    #expect(h.frame(a) == slot)
  }

  @Test func draggingOntoAWindowEdgeDocksBesideIt() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let target = h.frame(b)!
    let start = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: target.midX, y: target.maxY - 20)])
    #expect(h.workspace.isDocked(c))
    #expect(h.frame(c)!.minY > h.frame(b)!.maxY)
    #expect(abs(h.frame(c)!.minX - h.frame(b)!.minX) < 1)
  }

  @Test func focusingAParkedWindowRevealsIt() {
    let (h, a, b, _) = makeHarness(apart: true)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    h.system.userFocus(b)
    #expect(h.system.isVisible(b))
  }

  @Test func dockedWindowsMovedBySomethingElseAreReturned() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let slot = h.frame(a)!
    h.system.userMove(a, to: CGRect(x: 500, y: 300, width: 300, height: 300))
    #expect(h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") })
    h.scheduler.runPending()
    #expect(h.frame(a) == slot)
  }

  @Test func smallDifferencesFromTheAppAreAccepted() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    var rounded = h.frame(a)!
    rounded.size.height -= 3  // e.g. a terminal snapping to its character grid
    h.system.userMove(a, to: rounded)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") })
  }

  @Test(arguments: [false, true]) func floatingWindowsRememberWhereTheUserPutThem(makingWay: Bool) {
    let (h, a, b, c) = makeHarness(settings: makingWay ? .makingWay : Settings())
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    // Nothing is left over for the Desktop: what floats lies over the docked windows, here across the gap between the two.
    let placed = CGRect(x: h.frame(a)!.maxX - 150, y: h.frame(a)!.minY + 20, width: 300, height: 200)
    h.system.userMove(c, to: placed)
    h.run("zoom \(a.rawValue)")
    // It leaves with the Desktop only if it makes way. As Arbor ships it stays there.
    #expect(h.system.isVisible(c) == !makingWay)
    if !makingWay { #expect(h.frame(c) == placed) }
    h.run("back")
    #expect(h.frame(c) == placed)
  }

  @Test func dockingPushesOverlappingFloatingWindowsOntoTheDesktop() {
    // While floating windows make way, as until Q20. As Arbor ships they stay where they are (`FloatingFrameTests`).
    let (h, a, b, c) = makeHarness(settings: .makingWay)
    let left = CGRect(x: 20, y: 300, width: 500, height: 300)
    h.system.userMove(c, to: left)
    h.run("dock \(a.rawValue) left")
    let desktop = h.layout!.desktopFrame!
    #expect(desktop.contains(h.frame(c)!))
    // b takes all that is left. With no Desktop to lie on, c is back where it was left, over the docked windows.
    h.run("dock \(b.rawValue) right")
    #expect(h.frame(c) == left)
  }

  @Test func savedViews() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    #expect(h.run("save-view 3").ok)
    h.run("show-all")
    #expect(h.run("view 3").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(!h.run("view 4").ok)
  }

  @Test func keyboardDockMovesADockedWindowOnePlaceAtATime() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) right")
    let tree = { h.workspace.tree }
    let leafA = tree().leaf(containing: a)!
    let leafB = tree().leaf(containing: b)!
    let leafC = tree().leaf(containing: c)!
    // [a, b, c] → [b, a, c] → [b, c, a] → already at the edge.
    // The Desktop has no room: it is nobody's neighbour, and stays where it is.
    #expect(tree().children(of: tree().root) == [leafA, tree().desktop, leafB, leafC])
    #expect(h.run("dock \(a.rawValue) right").ok)
    #expect(tree().children(of: tree().root) == [leafB, tree().desktop, leafA, leafC])
    #expect(h.run("dock \(a.rawValue) right").ok)
    #expect(tree().children(of: tree().root) == [leafB, tree().desktop, leafC, leafA])
    #expect(!h.run("dock \(a.rawValue) right").ok)
    expectWindowsMatchLayout(h)
    // Sizes travel with the windows.
    #expect(abs(h.frame(a)!.width - h.frame(b)!.width) <= 1)
    #expect(abs(h.frame(a)!.width - h.frame(c)!.width) <= 1)
  }

  @Test func keyboardDockStepsOutOfAColumn() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    // c leaves the column [a / c] and sits between it and b, its neighbour on that side.
    // (The empty place is the Desktop's, which has no room.)
    #expect(h.run("dock \(c.rawValue) right").ok)
    let tree = h.workspace.tree
    #expect(tree.children(of: tree.root).map { tree.windows(under: $0) } == [[a], [], [c], [b]])
    expectWindowsMatchLayout(h)
  }

  @Test func arrangeDocksEverythingAndFloatAllUndocksIt() {
    let (h, a, b, c) = makeHarness()
    #expect(h.run("arrange").ok)
    #expect(Set(h.workspace.tree.allWindows) == [a, b, c])
    #expect(h.workspace.floating.isEmpty)
    expectWindowsMatchLayout(h)
    #expect(h.run("float-all").ok)
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(Set(h.workspace.floating.keys) == [a, b, c])
    for window in [a, b, c] { #expect(h.system.isVisible(window)) }
  }

  @Test func resizeMovesTheSharedEdge() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = h.frame(a)!.width
    #expect(h.run("resize \(a.rawValue) right 100").ok)
    #expect(abs(h.frame(a)!.width - (before + 100)) <= 1)
    #expect(!h.run("resize \(a.rawValue) left 50").ok, "nothing is left of a")
  }

  /// B2: `resize 101 right 1e300` from arborctl or a URL used to crash Arbor.
  @Test func hugeResizeAmountsAreRefusedAndChangeNothing() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = h.workspace
    for amount in ["1e300", "-1e300", "inf", "nan", "1000001"] {
      let result = h.run("resize \(a.rawValue) right \(amount)")
      #expect(!result.ok, "\(amount)")
      #expect(result.message.contains("at most ±1000000"), "\(result.message)")
    }
    #expect(h.workspace == before)

    // Commands built in code skip the parser. They must not crash or damage the tree either.
    for amount in [Double.infinity, -.infinity, .nan] {
      #expect(!h.controller.perform(.resize(a, .right, amount)).ok, "\(amount)")
      #expect(h.workspace == before, "\(amount)")
    }
    #expect(h.controller.perform(.resize(a, .right, 1e300)).ok)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// B2: a gap that leaves no room used to put frames at infinity. Floating a window then saved such a
  /// frame, after which state.json could never be written again, even with the gap put right.
  @Test(arguments: [438, 500, 1e300, -1e300]) func anAbsurdGapDoesNoLastingDamage(gap: Double) throws {
    var settings = Settings()
    settings.gap = gap
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Mail")
    h.start()
    for command in [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(a.rawValue) bottom",
      "zoom \(a.rawValue)", "float \(a.rawValue)", "show-all", "arrange", "zoom \(b.rawValue)", "float-all", "arrange",
    ] {
      h.run(command)
      _ = try JSONEncoder().encode(try #require(h.run("state").state))  // throws on a number that is not finite
    }
    let start = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 700, y: 450), CGPoint(x: 3, y: 450)])
    func isFinite(_ rect: CGRect?) -> Bool {
      rect.map { [$0.minX, $0.minY, $0.width, $0.height].allSatisfy(\.isFinite) } ?? true
    }
    #expect(h.system.frameLog.allSatisfy { isFinite($0.frame) }, "no window was ever sent to infinity")
    #expect(h.overlays.previewHistory.allSatisfy(isFinite))
    #expect(h.overlays.tiles.values.joined().allSatisfy { isFinite($0.frame) })

    h.controller.saveNow()
    _ = try JSONEncoder().encode(try #require(h.store.saved))
    h.controller.apply(settings: Settings())
    h.run("show-all")
    expectWindowsMatchLayout(h)
    h.controller.shutdown()
    for window in [a, b, c] { #expect(h.system.isVisible(window)) }
  }

  @Test(arguments: [0, -1, -2, 1.7e308]) func anAbsurdDesktopWeightStillArranges(weight: Double) throws {
    var settings = Settings.withDesktopColumn  // the weight is that column's
    settings.arrangeDesktopWeight = weight
    let h = Harness(settings: settings)
    let windows = (0..<3).map { _ in h.system.open(app: "App") }
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    expectWindowsMatchLayout(h)
    // The least Desktop leaves the windows nearly all the room; the most makes tiles of them.
    for window in windows where weight <= 0 {
      let frame = try #require(h.frame(window))
      #expect(h.visibleFrame.contains(frame) && frame.width > 600, "\(frame)")
    }
    #expect(try #require(h.layout?.desktopFrame ?? h.layout?.tiles.first { $0.kind == .desktop }?.frame).width > 0)
    h.system.close(windows[0])
    h.system.close(windows[1])
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    h.controller.saveNow()
    _ = try JSONEncoder().encode(try #require(h.store.saved))
  }

  @Test func seamDragsResizeBothSides() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let seam = h.overlays.seams[h.display]!.first!
    let before = h.frame(a)!.width
    h.overlays.dragSeam(seam, by: 80)
    #expect(abs(h.frame(a)!.width - (before + 80)) <= 1)
    #expect(h.layout!.desktopFrame!.minX - h.frame(a)!.maxX == 12)
  }

  @Test func excludingAnAppReleasesItsWindows() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    let bundle = h.controller.windows[a]!.bundleID!
    #expect(h.run("exclude \(bundle)").ok)
    #expect(!h.workspace.contains(a))
    #expect(h.system.isVisible(a), "a released window must come back into view")
    #expect(h.controller.settings.excludedBundleIDs == [bundle])
    #expect(h.run("include \(bundle)").ok)
    #expect(h.workspace.isFloating(a))
  }

  @Test func newWindowsFloatAndStayVisibleWhileZoomedIn() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let fresh = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 500, height: 300))
    #expect(h.workspace.isFloating(fresh))
    #expect(h.system.isVisible(fresh))
  }

  @Test func shutdownLeavesEveryWindowVisible() {
    let (h, a, b, c) = makeHarness()
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(a.rawValue)")
    h.controller.shutdown()
    for window in [a, b, c, big] {
      #expect(h.system.isVisible(window), "\(window)")
    }
    #expect(h.controller.parked.isEmpty)
    #expect(!h.controller.isRunning)
  }

  @Test func theArrangementSurvivesARestart() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    h.controller.saveNow()
    let saved = h.store.saved

    // Same windows, new Arbor process.
    let again = Harness(saved: saved)
    for window in h.system.allWindows() {
      again.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    again.start()
    #expect(again.workspace.tree == h.workspace.tree)
    // A launch ends showing everything (LaunchShowsEverythingTests), with the view of last time one step back.
    #expect(again.workspace.camera == again.workspace.tree.root)
    #expect(again.system.isVisible(a) && again.system.isVisible(b))
    #expect(again.run("back").ok)
    #expect(again.workspace.camera == again.workspace.tree.leaf(containing: b))
    #expect(again.system.isVisible(b))
    #expect(!again.system.isVisible(a))
  }

  @Test func restartedAppsAreMatchedByTitleAndReusedNumbersAreIgnored() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    let saved = h.store.saved!
    let snapshotA = h.controller.windows[a]!
    let snapshotB = h.controller.windows[b]!

    // After a reboot, unrelated windows reuse the old numbers and the
    // remembered windows come back under new numbers.
    let again = Harness(saved: saved)
    for _ in 0..<5 { again.system.open(app: "Filler") }
    let newA = again.system.open(
      app: snapshotA.appName, bundleID: snapshotA.bundleID, title: snapshotA.title, frame: snapshotA.frame)
    let newB = again.system.open(
      app: snapshotB.appName, bundleID: snapshotB.bundleID, title: snapshotB.title, frame: snapshotB.frame)
    again.start()
    let tree = again.workspace.tree
    #expect(Set(tree.allWindows) == [newA, newB])
    #expect(tree.invariantViolations().isEmpty)
    #expect(again.controller.windows.keys.filter { again.workspace.isFloating($0) }.count == 5)
  }

  @Test func windowsLeftParkedByACrashAreRescued() {
    let h = Harness()
    let lost = h.system.open(app: "Safari", frame: CGRect(x: 1439, y: 899, width: 600, height: 400))
    h.start()
    #expect(h.system.isVisible(lost))
  }

  @Test func aDisconnectedDisplaysWindowsFloatOnTheMainDisplay() {
    let second = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, second])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(a.rawValue) left")
    #expect(h.controller.workspaces[second.id]!.isDocked(a))
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.workspace.isFloating(a))
    #expect(h.system.isVisible(a))
  }

  @Test func commandsExplainThemselvesBeforeStarting() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let result = h.run("show-all")
    #expect(!result.ok)
    #expect(result.message.contains("Accessibility"))
    #expect(h.run("state").ok)
  }

  @Test func stateSnapshotDescribesEverything() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let state = h.run("state").state!
    #expect(state.running)
    #expect(state.displays.count == 1)
    #expect(state.displays[0].windowFrames[a] != nil)
    #expect(state.window(b)?.parked == true)
    #expect(state.window(c)?.docked == false && state.window(c)?.parked == false, "what floats stays in view")
    #expect(state.displays[0].canGoBack)
  }
}

@MainActor
@Suite struct ObserverTests {
  @Test func observersHearAboutLayoutCameraViewsFocusAndSettings() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    var changes: [Controller.Change] = []
    var keyboardMoves = 0
    // `.keyboard` only says "ask who has the keyboard", as often as the window system does; it is counted apart.
    h.controller.observe { change in
      if change == .keyboard { keyboardMoves += 1 } else { changes.append(change) }
    }
    h.start()
    #expect(changes.contains(.lifecycle))

    changes.removeAll()
    h.run("dock \(a.rawValue) left")
    // Docking focuses the window, and macOS reports that back.
    #expect(changes == [.layout(h.display), .focus(a)])

    h.run("dock \(b.rawValue) right")
    changes.removeAll()
    h.run("zoom \(a.rawValue)")
    #expect(changes == [.layout(h.display), .camera(h.display), .focus(a)])

    changes.removeAll()
    h.run("save-view 1")
    #expect(changes == [.savedViews(h.display)])

    changes.removeAll()
    h.run("back")
    #expect(changes == [.layout(h.display), .camera(h.display)])

    changes.removeAll()
    h.system.userFocus(b)
    #expect(changes == [.focus(b)])

    // ⌘Tab: the app's own focused window stays the same, so no window reports anything.
    changes.removeAll()
    keyboardMoves = 0
    h.system.userSwitchesApp(to: a)
    #expect(keyboardMoves > 0)
    #expect(changes.isEmpty)

    // A new window floats where it opened: no layout changes.
    h.system.open(app: "Mail")
    #expect(changes.contains(.windows))

    changes.removeAll()
    h.run("exclude com.example.mail")
    #expect(changes.last == .settings)
  }
}

@MainActor
@Suite struct ManualSchedulerTests {
  @Test func advanceRunsOnlyWhatIsDueInTimeOrder() {
    let scheduler = ManualScheduler()
    var ran: [String] = []
    scheduler.schedule("late", after: 2) { ran.append("late") }
    scheduler.schedule("early", after: 0.5) {
      ran.append("early")
      scheduler.schedule("chained", after: 0.25) { ran.append("chained") }
    }
    scheduler.advance(by: 0.4)
    #expect(ran.isEmpty)
    scheduler.advance(by: 0.6)
    #expect(ran == ["early", "chained"])
    #expect(scheduler.pendingKeys == ["late"])
    scheduler.schedule("late", after: 5) { ran.append("later") }
    scheduler.advance(by: 2)
    #expect(ran == ["early", "chained"], "scheduling a key again replaces its time")
    scheduler.runPending()
    #expect(ran == ["early", "chained", "later"])
    #expect(scheduler.now == 3)
  }

  @Test func theControllersClockFollowsTheScheduler() {
    let h = Harness()
    let before = h.controller.now()
    h.scheduler.advance(by: 90)
    #expect(h.controller.now().timeIntervalSince(before) == 90)
  }
}
