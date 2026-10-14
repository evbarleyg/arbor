import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)

private func everyone(_: WindowID) -> Bool { true }

/// root(h)[ column(v)[a, c], desktop, b ]
private struct Fixture {
  var tree = LayoutTree()
  let leafA: NodeID
  let leafB: NodeID
  let leafC: NodeID
  var column: NodeID { tree.parent(of: leafA)! }

  init() {
    leafA = tree.dock(a, beside: tree.root, edge: .left)
    leafB = tree.dock(b, beside: tree.root, edge: .right)
    leafC = tree.dock(c, beside: leafA, edge: .bottom)
  }

  var view: TreeView { TreeView(tree: tree, isPresent: everyone) }

  func layout(camera: NodeID? = nil) -> Layout {
    LayoutEngine.layout(tree, camera: camera ?? tree.root, in: screen, isPresent: everyone)
  }
}

@Suite struct NavigationTests {
  @Test func stepOutGoesToTheParentSpace() {
    let f = Fixture()
    #expect(Navigation.stepOut(from: f.leafA, in: f.view) == f.column)
    #expect(Navigation.stepOut(from: f.column, in: f.view) == f.tree.root)
    #expect(Navigation.stepOut(from: f.tree.root, in: f.view) == nil)
  }

  @Test func stepOutSkipsSplitsThatLookTheSame() {
    let f = Fixture()
    // With c absent the column shows only a, so stepping out of a skips it.
    let view = TreeView(tree: f.tree, isPresent: { $0 != c })
    #expect(Navigation.stepOut(from: f.leafA, in: view) == f.tree.root)
  }

  @Test func stepInPicksTheChildUnderThePointer() {
    let f = Fixture()
    let layout = f.layout()
    let overB = layout.windowFrames[b]!.center
    #expect(Navigation.stepIn(from: f.tree.root, toward: overB, focused: nil, in: f.view, layout: layout) == f.leafB)
    let overC = layout.windowFrames[c]!.center
    #expect(Navigation.stepIn(from: f.tree.root, toward: overC, focused: nil, in: f.view, layout: layout) == f.column)
  }

  @Test func stepInFallsBackToTheFocusedWindow() {
    let f = Fixture()
    let layout = f.layout()
    #expect(Navigation.stepIn(from: f.tree.root, toward: nil, focused: b, in: f.view, layout: layout) == f.leafB)
    #expect(Navigation.stepIn(from: f.leafB, toward: nil, focused: b, in: f.view, layout: layout) == nil)
  }

  @Test func neighborWalksUpToASplitOnTheRightAxis() {
    let f = Fixture()
    #expect(Navigation.neighbor(of: f.leafA, toward: .right, in: f.view) == f.tree.desktop)
    #expect(Navigation.neighbor(of: f.leafA, toward: .bottom, in: f.view) == f.leafC)
    #expect(Navigation.neighbor(of: f.leafC, toward: .right, in: f.view) == f.tree.desktop)
    #expect(Navigation.neighbor(of: f.leafB, toward: .right, in: f.view) == nil)
    #expect(Navigation.neighbor(of: f.leafA, toward: .left, in: f.view) == nil)
  }

  @Test func commonAncestor() {
    let f = Fixture()
    #expect(Navigation.commonAncestor(f.leafA, f.leafC, in: f.tree) == f.column)
    #expect(Navigation.commonAncestor(f.leafA, f.leafB, in: f.tree) == f.tree.root)
    #expect(Navigation.commonAncestor(f.leafA, f.leafA, in: f.tree) == f.leafA)
  }

  @Test func bestFitMatchesTheClosestNode() {
    let f = Fixture()
    let layout = f.layout()
    let aFrame = layout.windowFrames[a]!
    #expect(Navigation.bestFit(for: aFrame.insetBy(dx: 10, dy: 10), in: layout) == f.leafA)
    let columnFrame = layout.nodeFrames[f.column]!
    #expect(Navigation.bestFit(for: columnFrame, in: layout) == f.column)
  }

  @Test func adjacentLeafUsesGeometry() {
    let f = Fixture()
    let layout = f.layout()
    #expect(Navigation.adjacentLeaf(to: f.leafA, toward: .bottom, in: layout, tree: f.tree) == f.leafC)
    #expect(Navigation.adjacentLeaf(to: f.leafC, toward: .top, in: layout, tree: f.tree) == f.leafA)
    #expect(Navigation.adjacentLeaf(to: f.leafB, toward: .left, in: layout, tree: f.tree) == f.tree.desktop)
    #expect(Navigation.adjacentLeaf(to: f.leafB, toward: .right, in: layout, tree: f.tree) == nil)
  }
}

@Suite struct DropTests {
  @Test func nearAScreenEdgeDocksAtTheCameraEdge() {
    let f = Fixture()
    let target = DropResolver.resolve(
      point: CGPoint(x: 3, y: 400), window: WindowID(9), layout: f.layout(), tree: f.tree, visibleFrame: screen)
    #expect(target == .cameraEdge(.left))
  }

  @Test func nearAWindowEdgeDocksBesideIt() {
    let f = Fixture()
    let layout = f.layout()
    let frame = layout.windowFrames[b]!
    let point = CGPoint(x: frame.minX + 10, y: frame.midY)
    let target = DropResolver.resolve(point: point, window: WindowID(9), layout: layout, tree: f.tree, visibleFrame: screen)
    #expect(target == .beside(f.leafB, .left))
  }

  @Test func theMiddleOfAWindowFloatsUnlessTabsAreOn() {
    let f = Fixture()
    let layout = f.layout()
    let point = layout.windowFrames[b]!.center
    let floating = DropResolver.resolve(point: point, window: WindowID(9), layout: layout, tree: f.tree, visibleFrame: screen)
    #expect(floating == .float)
    let stacked = DropResolver.resolve(
      point: point, window: WindowID(9), layout: layout, tree: f.tree, visibleFrame: screen,
      options: DropOptions(tabsEnabled: true))
    #expect(stacked == .stack(f.leafB))
  }

  @Test func droppingOnItsOwnSlotChangesNothing() {
    let f = Fixture()
    let layout = f.layout()
    let target = DropResolver.resolve(
      point: layout.windowFrames[a]!.center, window: a, layout: layout, tree: f.tree, visibleFrame: screen)
    #expect(target == DropTarget.none)
  }

  @Test func theDesktopFloats() {
    let f = Fixture()
    let layout = f.layout()
    let target = DropResolver.resolve(
      point: layout.desktopFrame!.center, window: WindowID(9), layout: layout, tree: f.tree, visibleFrame: screen)
    #expect(target == .float)
  }
}
