import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let content = visible.insetBy(dx: 12, dy: 12)
private let display = DisplayID("main")
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
/// Floating.
private let f1 = WindowID(11)
private let f2 = WindowID(12)

/// Small enough that nothing is a tile unless a test asks for it.
private let roomy = LayoutOptions(minimumUsableSize: CGSize(width: 120, height: 120))

/// root(h)[ column(v)[a, row(h)[c, d]], desktop, b ]: three levels below the root. As it ships b took all that was left: two halves
/// and a Desktop without room. With `desktopColumn` thirds, for the tests in which the Desktop between the windows takes part.
private struct Fixture {
  var tree = LayoutTree()
  let leafA: NodeID
  let leafB: NodeID
  let leafC: NodeID
  let leafD: NodeID
  var column: NodeID { tree.parent(of: leafA)! }
  var row: NodeID { tree.parent(of: leafC)! }
  var root: NodeID { tree.root }

  init(desktopColumn: Bool = false) {
    leafA = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    leafB = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    leafC = tree.dock(c, beside: leafA, edge: .bottom)
    leafD = tree.dock(d, beside: leafC, edge: .right)
  }
}

/// The display at rest with the camera on `camera`: docked windows in their slots, `floating`
/// windows where given (leave out the ones that are out of view), `absent` windows minimized.
private func keyframe(
  _ tree: LayoutTree, camera: NodeID, floating: [WindowID: CGRect] = [:], parked: Set<WindowID> = [],
  absent: Set<WindowID> = [], options: LayoutOptions = roomy, in frame: CGRect = visible,
  minimumSize: @escaping (WindowID) -> CGSize? = { _ in nil }
) -> Keyframe {
  let present = Set(tree.allWindows).union(floating.keys).union(parked).subtracting(absent)
  let layout = LayoutEngine.layout(
    tree, camera: camera, in: frame, options: options, isPresent: { present.contains($0) },
    minimumSize: minimumSize)
  return Keyframe(
    tree: tree, layout: layout, present: present,
    visible: layout.windowFrames.merging(floating) { _, floating in floating })
}

private func plan(
  _ before: Keyframe, _ after: Keyframe, options: LayoutOptions = roomy, frontToBack: [WindowID] = []
) -> Transition {
  TransitionPlanner.plan(
    display: display, frame: screen, from: before, to: after, options: options, duration: 0.46,
    frontToBack: frontToBack)
}

/// The same journey the other way round.
private func reversed(_ transition: Transition) -> [WindowID: Transition.Item] {
  Dictionary(
    uniqueKeysWithValues: transition.items.map {
      (
        $0.window,
        Transition.Item(
          window: $0.window, from: $0.to, to: $0.from, fromLook: $0.toLook, toLook: $0.fromLook,
          fromOpacity: $0.toOpacity, toOpacity: $0.fromOpacity)
      )
    })
}

private func byWindow(_ transition: Transition) -> [WindowID: Transition.Item] {
  Dictionary(uniqueKeysWithValues: transition.items.map { ($0.window, $0) })
}

@Suite struct CameraTransitionTests {
  @Test func zoomingInOnALeafPushesTheOthersOutPastTheEdges() throws {
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.root)
    let transition = plan(before, keyframe(f.tree, camera: f.leafA))
    #expect(transition.display == display && transition.frame == screen && transition.duration == 0.46)
    #expect(Set(transition.items.map(\.window)) == [a, b, c, d])

    // Everything starts where it is, and makes the journey a's slot makes to fill the screen.
    let slots = before.layout.windowFrames
    let zoom = try #require(PlaneMap(carrying: slots[a]!, onto: content))
    #expect(transition[a] == Transition.Item(window: a, from: slots[a]!, to: content))
    for window in [b, c, d] {
      let item = try #require(transition[window])
      #expect(item.from == slots[window], "\(window)")
      #expect(item.to == zoom.apply(slots[window]!).integralRounded, "\(window)")
      #expect(!item.to.overlaps(screen), "\(window) ends out of sight")
      #expect(item.fromLook == .picture && item.toLook == .picture)
      #expect(item.fromOpacity == 1 && item.toOpacity == 1, "\(window) leaves by moving, not by fading")
    }
    #expect(transition[b]!.to.minX >= screen.maxX && transition[b]!.to.minY == content.minY)
    #expect(transition[c]!.to.minY >= screen.maxY && transition[c]!.to.minX == content.minX)
    #expect(transition.hasMotion)
  }

  @Test func zoomingBackOutIsTheSameJourneyReversed() {
    let f = Fixture()
    let overview = keyframe(f.tree, camera: f.root)
    for node in [f.leafA, f.leafB, f.leafC, f.column, f.row, f.tree.desktop] {
      let zoomed = keyframe(f.tree, camera: node)
      #expect(byWindow(plan(zoomed, overview)) == reversed(plan(overview, zoomed)), "\(node)")
    }
  }

  @Test func zoomingInOnAGroupKeepsTheGroupTogether() throws {
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.root)
    let after = keyframe(f.tree, camera: f.column)
    let transition = plan(before, after)
    for window in [a, c, d] {
      #expect(
        transition[window]
          == Transition.Item(
            window: window, from: before.layout.windowFrames[window]!, to: after.layout.windowFrames[window]!))
    }
    // The column already has the full height, so the plane only stretches sideways.
    let item = try #require(transition[b])
    #expect(item.to.minX >= screen.maxX)
    #expect(item.to.minY == item.from.minY && item.to.height == item.from.height)
  }

  @Test func threeLevelsDownEverythingStillStartsWhereItIs() throws {
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.root)
    let transition = plan(before, keyframe(f.tree, camera: f.leafD))
    #expect(Set(transition.items.map(\.window)) == [a, b, c, d])
    for item in transition.items { #expect(item.from == before.layout.windowFrames[item.window]) }
    #expect(transition[d]!.to == content)
    #expect(transition[c]!.to.maxX <= screen.minX, "c leaves to the left")
    #expect(transition[a]!.to.maxY <= screen.minY, "a leaves upward")
    #expect(transition[b]!.to.minX >= screen.maxX, "b leaves to the right")
  }

  @Test func oneLevelAtATimeUsesTheNearestCommonAncestor() {
    let f = Fixture()
    // From the row to d: a and b are out of view before and after, and never cross the screen.
    let before = keyframe(f.tree, camera: f.row)
    let transition = plan(before, keyframe(f.tree, camera: f.leafD))
    #expect(Set(transition.items.map(\.window)) == [c, d])
    #expect(transition[c]!.from == before.layout.windowFrames[c])
    #expect(transition[c]!.to.maxX <= screen.minX)
    #expect(transition[c]!.to.minY == content.minY && transition[c]!.to.height == content.height)
    #expect(transition[d]!.to == content)
  }

  @Test func movingToANeighbourSlidesThePlaneSideways() {
    let f = Fixture()
    let transition = plan(keyframe(f.tree, camera: f.leafC), keyframe(f.tree, camera: f.leafD))
    #expect(Set(transition.items.map(\.window)) == [c, d])
    #expect(transition[c]!.from == content && transition[d]!.to == content)
    #expect(transition[c]!.to.maxX <= screen.minX, "c goes out on the left")
    #expect(transition[d]!.from.minX >= screen.maxX, "d comes in from the right")
    for item in transition.items {
      #expect(item.from.minY == content.minY && item.to.minY == content.minY)
      #expect(item.from.height == content.height && item.to.height == content.height)
      // c and d have the same share of the row, so nothing changes size on the way.
      #expect(abs(item.from.width - item.to.width) <= 1)
      #expect(item.to.minX < item.from.minX)
    }
  }

  @Test func aWindowBetweenTheTwoCamerasCrossesTheScreen() throws {
    // [a | b | c | desktop]: from a to c, b is out of view at both ends but passes through.
    var tree = LayoutTree()
    let leafC = tree.dock(c, beside: tree.root, edge: .left)
    _ = tree.dock(b, beside: tree.root, edge: .left)
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let transition = plan(keyframe(tree, camera: leafA), keyframe(tree, camera: leafC))
    let item = try #require(transition[b])
    #expect(item.from.minX >= screen.maxX && item.to.maxX <= screen.minX)
    #expect(item.fromOpacity == 1 && item.toOpacity == 1)
    // On the way back to a's neighbour, c starts and stays beyond the right edge.
    let short = plan(keyframe(tree, camera: leafA), keyframe(tree, camera: tree.leaf(containing: b)!))
    #expect(Set(short.items.map(\.window)) == [a, b])
  }

  @Test func showingTheDesktopPartsTheWindowsBesideIt() {
    let f = Fixture(desktopColumn: true)
    let resting = CGRect(x: 520, y: 200, width: 300, height: 200)
    let before = keyframe(f.tree, camera: f.root, floating: [f1: resting])
    let transition = plan(before, keyframe(f.tree, camera: f.tree.desktop, floating: [f1: resting]))
    for window in [a, c, d] { #expect(transition[window]!.to.maxX <= screen.minX, "\(window)") }
    #expect(transition[b]!.to.minX >= screen.maxX)
    // Arbor leaves a floating window in view where it is, so its stand-in stays too.
    #expect(transition[f1] == Transition.Item(window: f1, from: resting, to: resting))
  }

  @Test func nothingMovesWhenTheCameraStays() {
    let f = Fixture()
    let still = keyframe(f.tree, camera: f.column)
    let transition = plan(still, still)
    #expect(!transition.hasMotion)
    #expect(Set(transition.items.map(\.window)) == [a, c, d], "what is in view would still be drawn")
  }

  @Test func whatLeavesTheViewAlsoClearsTheDockAndTheMenuBar() throws {
    // A Dock 90 points high: the plane puts c just below the view, which is still on the display.
    let f = Fixture()
    let aboveTheDock = CGRect(x: 0, y: 25, width: 1440, height: 785)
    let before = keyframe(f.tree, camera: f.root, in: aboveTheDock)
    let zoomed = keyframe(f.tree, camera: f.leafA, in: aboveTheDock)
    let plane = Plane(tree: f.tree, layout: zoomed.layout, ancestor: f.root, options: roomy, isPresent: { _ in true })
    #expect(plane.windows[c]!.frame.minY < screen.maxY)

    let down = try #require(plan(before, zoomed)[c])
    #expect(down.to.minY == screen.maxY)
    #expect(down.to.size == plane.windows[c]!.frame.size && down.to.minX == plane.windows[c]!.frame.minX)

    // And upward: a ends above the top of the display, not behind the menu bar.
    let up = try #require(plan(before, keyframe(f.tree, camera: f.row, in: aboveTheDock))[a])
    #expect(up.to.maxY == screen.minY)
  }
}

@Suite struct TileTransitionTests {
  /// With a column for the Desktop columns are 464 wide, so the column is a group's tile and b a window's. (Halves will not do:
  /// c and d are as wide in a view of the column as the column is in a view of everything, and they are to unfold.)
  let cramped = LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 300))

  @Test func zoomingInOnAGroupsTileUnfoldsItsMiniature() throws {
    let f = Fixture(desktopColumn: true)
    let before = keyframe(f.tree, camera: f.root, options: cramped)
    let after = keyframe(f.tree, camera: f.column, options: LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 300)))
    let tile = try #require(before.layout.tiles.first { $0.node == f.column })
    let transition = plan(before, after, options: cramped)

    #expect(
      transition[a]
        == Transition.Item(
          window: a, from: tile.miniature[a]!, to: after.layout.windowFrames[a]!, fromLook: .cover, toLook: .picture))
    for window in [c, d] {
      let item = try #require(transition[window])
      #expect(item.from == tile.miniature[window] && item.fromLook == .cover)
      #expect(item.to == after.layout.windowFrames[window] && item.toLook == .picture)
    }
    // b's tile leaves as the cover it is.
    let other = try #require(transition[b])
    #expect(other.from == before.layout.tiles.first { $0.node == f.leafB }?.frame)
    #expect(other.to.minX >= screen.maxX)
    #expect(other.fromLook == .cover && other.toLook == .cover)
  }

  @Test func zoomingOutFoldsThemBackIntoTiles() {
    let f = Fixture(desktopColumn: true)
    let overview = keyframe(f.tree, camera: f.root, options: cramped)
    for node in [f.column, f.leafB, f.leafA] {
      let zoomed = keyframe(f.tree, camera: node, options: cramped)
      #expect(
        byWindow(plan(zoomed, overview, options: cramped)) == reversed(plan(overview, zoomed, options: cramped)),
        "\(node)")
    }
  }

  @Test func aWindowsTileGrowsIntoTheWindow() {
    let f = Fixture(desktopColumn: true)
    let before = keyframe(f.tree, camera: f.root, options: cramped)
    let transition = plan(before, keyframe(f.tree, camera: f.leafB, options: cramped), options: cramped)
    #expect(
      transition[b]
        == Transition.Item(
          window: b, from: before.layout.nodeFrames[f.leafB]!, to: content, fromLook: .cover, toLook: .picture))
  }

  @Test func aWindowThatRefusesItsSlotEndsAsACover() {
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.leafA)
    let after = keyframe(f.tree, camera: f.root, minimumSize: { $0 == b ? CGSize(width: 900, height: 600) : nil })
    let item = plan(before, after)[b]
    #expect(item?.to == after.layout.nodeFrames[f.leafB])
    #expect(item?.fromLook == .cover && item?.toLook == .cover, "it comes in looking as it will end")
  }

  @Test func floatingWindowsGrowOutOfTheDesktopsTile() throws {
    // A Desktop squeezed to a tile between two wide windows.
    var tree = LayoutTree()
    let left = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: true)
    _ = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
    tree.moveBoundary(leading: left, trailing: tree.desktop, by: 300, pointsPerWeight: 464)
    let before = keyframe(tree, camera: tree.root, parked: [f1], options: .init())
    let tile = try #require(before.layout.tiles.first { $0.kind == .desktop })
    let resting = CGRect(x: 300, y: 200, width: 708, height: 425)
    let item = try #require(
      plan(before, keyframe(tree, camera: tree.desktop, floating: [f1: resting], options: .init()), options: .init())[f1])
    #expect(item.to == resting)
    #expect(tile.frame.contains(item.from), "it starts as small as the tile makes it")
    #expect(abs(item.from.width - resting.width * tile.frame.width / content.width) <= 1)
    #expect(item.fromOpacity == 0 && item.toOpacity == 1, "the tile does not show it, so it fades in")
  }
}

@Suite struct FloatingTransitionTests {
  @Test func floatingWindowsRideOutOfViewOnTheDesktop() throws {
    let f = Fixture(desktopColumn: true)
    let resting = CGRect(x: 520, y: 200, width: 300, height: 200)
    let before = keyframe(f.tree, camera: f.root, floating: [f1: resting])
    let after = keyframe(f.tree, camera: f.leafA, parked: [f1])
    let item = try #require(plan(before, after)[f1])
    #expect(item.from == resting)

    // It keeps its place on the Desktop, which goes where the plane takes it.
    let plane = Plane(tree: f.tree, layout: after.layout, ancestor: f.root, options: roomy, isPresent: { _ in true })
    let ride = try #require(PlaneMap(carrying: before.layout.desktopFrame!, onto: plane.nodes[f.tree.desktop]!))
    #expect(item.to == ride.apply(resting).integralRounded)
    #expect(item.to.minX >= screen.maxX)
    #expect(item.toOpacity == 1)
    #expect(byWindow(plan(after, before))[f1] == reversed(plan(before, after))[f1], "and it rides back in")
  }

  @Test func floatingWindowsOutOfViewAtBothEndsAreNotDrawn() {
    let f = Fixture()
    let transition = plan(
      keyframe(f.tree, camera: f.leafA, parked: [f1]), keyframe(f.tree, camera: f.column, parked: [f1]))
    #expect(transition[f1] == nil)
  }

  @Test func aNewWindowFloatingOverAZoomedViewLeavesWithThatView() throws {
    // It opened while the camera was on c, so it shows although the Desktop does not.
    let f = Fixture()
    let opened = CGRect(x: 400, y: 300, width: 500, height: 300)
    let item = try #require(
      plan(keyframe(f.tree, camera: f.leafC, floating: [f1: opened]), keyframe(f.tree, camera: f.leafD, parked: [f1]))[f1])
    #expect(item.from == opened)
    #expect(item.to.maxX <= screen.minX, "it goes the way c goes")
    #expect(item.to.minY == opened.minY && item.to.height == opened.height)
  }

  @Test func aWindowWithNowhereToGoFadesWhereItIs() throws {
    // Zooming out from c: pinned to the plane it would shrink in plain sight, but Arbor parks it.
    let f = Fixture()
    let opened = CGRect(x: 400, y: 300, width: 500, height: 300)
    let item = try #require(
      plan(keyframe(f.tree, camera: f.leafC, floating: [f1: opened]), keyframe(f.tree, camera: f.row, parked: [f1]))[f1])
    #expect(item.from == opened && item.fromOpacity == 1)
    #expect(item.toOpacity == 0)
    #expect(item.to.overlaps(screen))
  }

  @Test func windowsArborLeavesAloneAreDrawnWhereTheyAre() {
    // The stage hides every real window, so one that stays put has to be drawn as well.
    let f = Fixture()
    let frame = CGRect(x: 900, y: 500, width: 400, height: 300)
    let transition = plan(
      keyframe(f.tree, camera: f.root, floating: [f2: frame]), keyframe(f.tree, camera: f.leafA, floating: [f2: frame]))
    #expect(transition[f2] == Transition.Item(window: f2, from: frame, to: frame))
  }
}

@Suite struct StructuralTransitionTests {
  @Test func dockingTakesTheWindowFromWhereItIsToItsSlot() {
    var workspace = Workspace()
    let dropped = CGRect(x: 100, y: 100, width: 600, height: 400)
    let other = CGRect(x: 800, y: 300, width: 400, height: 300)
    let before = keyframe(workspace.tree, camera: workspace.camera, floating: [a: dropped, f1: other])
    workspace.dock(a, at: .cameraEdge(.left))
    let after = keyframe(workspace.tree, camera: workspace.camera, floating: [f1: other])
    let transition = plan(before, after)
    #expect(transition[a] == Transition.Item(window: a, from: dropped, to: after.layout.windowFrames[a]!))
    #expect(transition[f1] == Transition.Item(window: f1, from: other, to: other))
  }

  @Test func aClosedWindowHasNoItemAndItsNeighboursTakeItsSpace() {
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.root)
    var tree = f.tree
    tree.remove(d)
    let after = keyframe(tree, camera: tree.root)
    let transition = plan(before, after)
    #expect(transition[d] == nil)
    #expect(transition[c]!.from == before.layout.windowFrames[c] && transition[c]!.to == after.layout.windowFrames[c])
    #expect(transition[c]!.to.width > transition[c]!.from.width)
    #expect(transition[a]?.moves == false && transition[b]?.moves == false)
  }

  @Test func closingTheFramedWindowBringsItsNeighbourInFromWhereThePlaneHadIt() throws {
    // [a / c], camera on c; c closes and the camera lands on a, which was above the screen.
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
    workspace.moveCamera(to: workspace.tree.leaf(containing: c)!)
    let before = keyframe(workspace.tree, camera: workspace.camera)
    workspace.forget(c)
    let after = keyframe(workspace.tree, camera: workspace.camera)
    #expect(after.layout.windowFrames[a] == content)
    let transition = plan(before, after)
    #expect(transition.items.map(\.window) == [a])
    #expect(transition[a]!.from.maxY <= screen.minY && transition[a]!.from.minX == content.minX)
    #expect(transition[a]!.to == content)
  }

  @Test func aMinimizedWindowHasNoItemAndARestoredOneStartsWhereItReappears() {
    let f = Fixture()
    let full = keyframe(f.tree, camera: f.root)
    let without = keyframe(f.tree, camera: f.root, absent: [d])
    let minimizing = plan(full, without)
    #expect(minimizing[d] == nil)
    #expect(minimizing[c]!.to.width > minimizing[c]!.from.width)

    // macOS puts it back where it was minimized from, over c, which has grown meanwhile.
    var reappeared = without
    reappeared.visible[d] = full.layout.windowFrames[d]
    let restoring = plan(reappeared, full)
    #expect(restoring[d] == Transition.Item(window: d, from: full.layout.windowFrames[d]!, to: full.layout.windowFrames[d]!))
    #expect(restoring[c]!.to == full.layout.windowFrames[c])
  }

  @Test func aWindowThatWasNotOnThePlaneFadesInWhereItGoes() {
    // Minimized while out of view, restored out of view, and now the layout shows it.
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.root, absent: [d])
    let after = keyframe(f.tree, camera: f.root)
    let slot = after.layout.windowFrames[d]!
    #expect(plan(before, after)[d] == Transition.Item(window: d, from: slot, to: slot, fromOpacity: 0, toOpacity: 1))
  }

  @Test func dockingBesideAWindowOutOfViewBringsTheSiblingsBackIntoView() throws {
    // Camera on c in the row [c, d]; docking beside d, which is out of view, widens the camera to the row.
    let f = Fixture()
    var workspace = Workspace(tree: f.tree)
    workspace.moveCamera(to: f.leafC)
    let dropped = CGRect(x: 500, y: 300, width: 400, height: 300)
    let before = keyframe(workspace.tree, camera: workspace.camera, floating: [f1: dropped])
    workspace.dock(f1, at: .beside(f.leafD, .right))
    #expect(workspace.camera == f.row)
    let after = keyframe(workspace.tree, camera: workspace.camera)
    let transition = plan(before, after)
    #expect(transition[f1] == Transition.Item(window: f1, from: dropped, to: after.layout.windowFrames[f1]!))
    #expect(transition[c] == Transition.Item(window: c, from: content, to: after.layout.windowFrames[c]!))
    let sibling = try #require(transition[d])
    #expect(sibling.from.minX >= screen.maxX, "d was beyond the right edge")
    #expect(sibling.to == after.layout.windowFrames[d])
    #expect(transition[a] == nil && transition[b] == nil)
  }

  @Test func dockingAtTheEdgeOfTheViewMakesRoomInTheViewAndNowhereElse() throws {
    // Camera on c in the row [c, d]; the newcomer forms a group with what is in view, and the view is on the group (F62).
    let f = Fixture()
    var workspace = Workspace(tree: f.tree)
    workspace.moveCamera(to: f.leafC)
    let dropped = CGRect(x: 500, y: 300, width: 400, height: 300)
    let before = keyframe(workspace.tree, camera: workspace.camera, floating: [f1: dropped])
    workspace.dock(f1, at: .cameraEdge(.left))
    #expect(Set(workspace.tree.windows(under: workspace.camera)) == [f1, c])
    let after = keyframe(workspace.tree, camera: workspace.camera)
    let transition = plan(before, after)
    #expect(transition[f1] == Transition.Item(window: f1, from: dropped, to: after.layout.windowFrames[f1]!))
    #expect(transition[c] == Transition.Item(window: c, from: content, to: after.layout.windowFrames[c]!))
    #expect(transition.items.count == 2, "what was out of view stays there, unseen")
  }

  @Test func arrangingBringsEveryWindowFromWhereItWas() {
    // A fresh tree whose node numbers mean something else: windows are matched, not nodes.
    let f = Fixture()
    let before = keyframe(f.tree, camera: f.leafA)
    let grid = LayoutTree.grid(of: [a, b, c, d])
    let after = keyframe(grid, camera: grid.root)
    let transition = plan(before, after)
    #expect(Set(transition.items.map(\.window)) == [a, b, c, d])
    #expect(transition[a]!.from == content)
    for window in [b, c, d] { #expect(!transition[window]!.from.overlaps(screen), "\(window)") }
    for item in transition.items { #expect(item.to == after.layout.windowFrames[item.window]) }
  }

  @Test func switchingTabsMovesNothing() {
    var f = Fixture()
    let e = WindowID(5)
    f.tree.addToStack(e, leaf: f.leafB)
    let before = keyframe(f.tree, camera: f.root)
    f.tree.activate(b)
    let transition = plan(before, keyframe(f.tree, camera: f.root))
    #expect(!transition.hasMotion, "so the controller shows no transition for it")
  }

  @Test func aTabThatBecomesActiveOnTheWayFadesInOverTheOldOne() throws {
    var f = Fixture()
    let e = WindowID(5)
    f.tree.addToStack(e, leaf: f.leafB)  // e covers b
    let before = keyframe(f.tree, camera: f.root)
    f.tree.activate(b)
    let transition = plan(before, keyframe(f.tree, camera: f.leafB))
    let slot = before.layout.windowFrames[e]!
    #expect(transition[b] == Transition.Item(window: b, from: slot, to: content, fromOpacity: 0, toOpacity: 1))
    #expect(transition[e] == Transition.Item(window: e, from: slot, to: content, fromOpacity: 1, toOpacity: 0))
    // A tab that is covered at both ends is never drawn.
    #expect(plan(before, keyframe(before.tree, camera: f.leafB))[b] == nil)
  }
}

@Suite struct TransitionOrderAndTextTests {
  @Test func itemsAreStackedLikeTheRealWindows() {
    let f = Fixture()
    let frame = CGRect(x: 500, y: 200, width: 300, height: 200)
    let before = keyframe(f.tree, camera: f.root, floating: [f1: frame, f2: frame])
    let after = keyframe(f.tree, camera: f.column, parked: [f1, f2])
    let transition = plan(before, after, frontToBack: [f2, c, WindowID(77), f1, a, c])
    // Back to front. Windows the list does not mention go to the back, lowest number first.
    #expect(transition.items.map(\.window) == [b, d, a, f1, c, f2])
    #expect(plan(before, after).items.map(\.window) == [a, b, c, d, f1, f2])
  }

  @Test func transitionsReadAsText() {
    let item = Transition.Item(
      window: a, from: CGRect(x: 12, y: 37, width: 464, height: 851),
      to: CGRect(x: -1200.4, y: 37, width: 1416, height: 851))
    #expect(item.description == "w1 (12,37 464x851) -> (-1200,37 1416x851)")
    var cover = item
    cover.fromLook = .cover
    #expect(cover.description.hasSuffix(" cover -> picture"))
    cover.toLook = .cover
    #expect(cover.description.hasSuffix(") cover"))
    cover.fromOpacity = 0
    #expect(cover.description.hasSuffix(" cover fades in"))
    cover.fromOpacity = 1
    cover.toOpacity = 0
    #expect(cover.description.hasSuffix(" cover fades out"))
    let transition = Transition(display: display, frame: screen, duration: 0.46, items: [item])
    #expect(transition.description == "transition on main, 0.46 s\n  w1 (12,37 464x851) -> (-1200,37 1416x851)")
  }

  @Test func twoTransitionsEndAlikeWithinAPoint() {
    let item = Transition.Item(window: a, from: .zero, to: CGRect(x: 10, y: 10, width: 100, height: 100))
    let one = Transition(display: display, frame: screen, duration: 0.46, items: [item])
    var other = one
    other.items[0].to.size.height += 1
    other.items[0].from = CGRect(x: 5, y: 5, width: 5, height: 5)
    #expect(one.endsLike(other))
    other.items[0].to.size.height += 1
    #expect(!one.endsLike(other))
    other = one
    other.items[0].toLook = .cover
    #expect(!one.endsLike(other))
    other = one
    other.items[0].toOpacity = 0
    #expect(!one.endsLike(other))
    other = one
    other.items.append(Transition.Item(window: b, from: .zero, to: .zero))
    #expect(!one.endsLike(other))
  }

  @Test func everyFrameIsFiniteHoweverCrowdedTheScreen() {
    var tree = LayoutTree()
    var leaves: [NodeID] = []
    for number in 1...200 { leaves.append(tree.dock(WindowID(UInt32(number)), beside: tree.root, edge: .left)) }
    for (from, to) in [(tree.root, leaves[0]), (leaves[0], leaves[150]), (leaves[3], tree.root)] {
      let transition = plan(keyframe(tree, camera: from), keyframe(tree, camera: to))
      #expect(transition.items.allSatisfy { $0.from.isFinite && $0.to.isFinite })
    }
  }
}
