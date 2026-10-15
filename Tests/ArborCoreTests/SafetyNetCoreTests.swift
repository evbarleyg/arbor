import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let stranger = WindowID(9)

private func everyone(_: WindowID) -> Bool { true }

/// Lines of the core that `scripts/mutate.py` could break on 2026-10-14 without any test noticing, where a user
/// would have noticed.
@Suite struct SafetyNetCoreTests {
  // MARK: Geometry

  @Test func edgesKnowTheirOppositeAxisAndEnd() {
    #expect(Edge.allCases.map(\.opposite) == [.right, .left, .bottom, .top])
    #expect(Edge.allCases.map(\.axis) == [.horizontal, .horizontal, .vertical, .vertical])
    #expect(Edge.allCases.map(\.isLeading) == [true, false, true, false])
    #expect(Axis.horizontal.perpendicular == .vertical && Axis.vertical.perpendicular == .horizontal)
  }

  @Test func distanceToAPointIsMeasuredFromTheNearestEdge() {
    let rect = CGRect(x: 100, y: 100, width: 200, height: 100)
    #expect(rect.distance(to: CGPoint(x: 150, y: 150)) == 0)
    #expect(rect.distance(to: CGPoint(x: 90, y: 150)) == 10)
    #expect(rect.distance(to: CGPoint(x: 320, y: 150)) == 20)
    #expect(rect.distance(to: CGPoint(x: 150, y: 70)) == 30)
    #expect(rect.distance(to: CGPoint(x: 150, y: 240)) == 40)
    #expect(rect.distance(to: CGPoint(x: 303, y: 204)) == 5)
  }

  @Test func rectanglesThatDoNotMeetHaveNothingInCommon() {
    let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(rect.intersectionOverUnion(CGRect(x: 300, y: 300, width: 100, height: 100)) == 0)
    #expect(rect.intersectionOverUnion(rect) == 1)
    #expect(rect.intersectionOverUnion(CGRect(x: 50, y: 0, width: 100, height: 100)) == 1.0 / 3)
  }

  // MARK: Drop targets

  /// [a | Desktop | b]
  private func row() -> (LayoutTree, Layout, NodeID) {
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    let leafB = tree.dock(b, beside: tree.root, edge: .right)
    return (tree, LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone), leafB)
  }

  @Test func everyScreenEdgeDocksAtThatEdgeOfTheView() {
    let (tree, layout, _) = row()
    let points: [(Edge, CGPoint)] = [
      (.left, CGPoint(x: screen.minX + 4, y: 450)), (.right, CGPoint(x: screen.maxX - 4, y: 450)),
      (.top, CGPoint(x: 720, y: screen.minY + 4)), (.bottom, CGPoint(x: 720, y: screen.maxY - 4)),
    ]
    for (edge, point) in points {
      let target = DropResolver.resolve(point: point, window: stranger, layout: layout, tree: tree, visibleFrame: screen)
      #expect(target == .cameraEdge(edge), "\(edge)")
    }
    // In a corner the nearer edge wins.
    let corner = DropResolver.resolve(
      point: CGPoint(x: screen.maxX - 2, y: screen.maxY - 9), window: stranger, layout: layout, tree: tree,
      visibleFrame: screen)
    #expect(corner == .cameraEdge(.right))
    // Just outside the band it is the window under the pointer that counts.
    let inside = DropResolver.resolve(
      point: CGPoint(x: screen.maxX - 14, y: 450), window: stranger, layout: layout, tree: tree, visibleFrame: screen)
    #expect(inside != .cameraEdge(.right))
  }

  /// A second display's coordinates do not start at zero, and one above the main display has negative ones.
  @Test(arguments: [CGPoint(x: 1440, y: 0), CGPoint(x: -1280, y: -300)])
  func screenEdgesAreMeasuredFromTheDisplayNotFromZero(origin: CGPoint) {
    let display = CGRect(origin: origin, size: CGSize(width: 1280, height: 800))
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: display, isPresent: everyone)
    let points: [(Edge, CGPoint)] = [
      (.left, CGPoint(x: display.minX + 4, y: display.midY)), (.right, CGPoint(x: display.maxX - 4, y: display.midY)),
      (.top, CGPoint(x: display.midX, y: display.minY + 4)), (.bottom, CGPoint(x: display.midX, y: display.maxY - 4)),
    ]
    for (edge, point) in points {
      let target = DropResolver.resolve(point: point, window: stranger, layout: layout, tree: tree, visibleFrame: display)
      #expect(target == .cameraEdge(edge), "\(edge)")
    }
    let middle = DropResolver.resolve(
      point: layout.desktopFrame!.center, window: stranger, layout: layout, tree: tree, visibleFrame: display)
    #expect(middle == .float)
  }

  @Test func everyEdgeOfAWindowDocksOnThatSideOfIt() {
    let (tree, layout, leafB) = row()
    let frame = layout.windowFrames[b]!
    let points: [(Edge, CGPoint)] = [
      (.left, CGPoint(x: frame.minX + 30, y: frame.midY)), (.right, CGPoint(x: frame.maxX - 30, y: frame.midY)),
      (.top, CGPoint(x: frame.midX, y: frame.minY + 60)), (.bottom, CGPoint(x: frame.midX, y: frame.maxY - 60)),
    ]
    for (edge, point) in points {
      let target = DropResolver.resolve(point: point, window: stranger, layout: layout, tree: tree, visibleFrame: screen)
      #expect(target == .beside(leafB, edge), "\(edge)")
    }
  }

  // MARK: The tree

  /// With a column for the Desktop, which counts like a window. (Without one the newcomer first takes what is left.)
  @Test func aWindowDockedAtTheEdgeOfARowIsAsWideAsTheAverage() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: true)
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: 300, pointsPerWeight: 500)
    // 1.6 and 0.4: the newcomer gets their mean, not a fixed share.
    let added = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
    #expect(abs(tree[added]!.weight - 1) < 1e-9)
    tree.moveBoundary(leading: tree.desktop, trailing: added, by: -100, pointsPerWeight: 500)
    let third = tree.dock(c, beside: tree.root, edge: .left, desktopColumn: true)
    #expect(abs(tree[third]!.weight - 1) < 1e-9)
    var narrow = LayoutTree()
    let only = narrow.dock(a, beside: narrow.root, edge: .left, desktopColumn: true)
    narrow.dock(b, beside: only, edge: .right, desktopColumn: true)  // 0.5, 0.5, Desktop 1
    let last = narrow.dock(c, beside: narrow.root, edge: .right, desktopColumn: true)
    #expect(abs(narrow[last]!.weight - 2.0 / 3) < 1e-9)
  }

  @Test func aRowThatMergesIntoItsParentKeepsItsShareAndItsProportions() {
    // root(h)[ col(v)[ a, row(h)[b, c] ], Desktop ], the column three times as wide as the Desktop, b twice as wide as c.
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let second = tree.dock(b, beside: first, edge: .bottom)
    let third = tree.dock(c, beside: second, edge: .right)
    let column = tree.parent(of: first)!
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: 250, pointsPerWeight: 500)
    tree.moveBoundary(leading: second, trailing: third, by: 100, pointsPerWeight: 300)
    let share = tree[column]!.weight
    let ratio = tree[second]!.weight / tree[third]!.weight
    #expect(abs(share - 1.5) < 1e-9 && abs(ratio - 2) < 1e-9)
    tree.remove(a)
    #expect(tree.children(of: tree.root) == [second, third, tree.desktop])
    #expect(abs(tree[second]!.weight + tree[third]!.weight - share) < 1e-9, "together they keep the column's width")
    #expect(abs(tree[second]!.weight / tree[third]!.weight - ratio) < 1e-9, "and their own proportions")
  }

  // MARK: Navigation

  /// root(h)[ column(v)[a, c], Desktop, b ]. As it ships b took all that was left: two halves and a Desktop without room. With
  /// `desktopColumn` thirds.
  private func columns(desktopColumn: Bool = false) -> (LayoutTree, NodeID, NodeID, NodeID) {
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    let leafB = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    let leafC = tree.dock(c, beside: leafA, edge: .bottom)
    return (tree, leafA, leafB, leafC)
  }

  @Test func neighboursAreOneStepAwayInBothDirections() {
    let (tree, leafA, leafB, leafC) = columns(desktopColumn: true)
    let view = TreeView(tree: tree, isPresent: everyone)
    #expect(Navigation.neighbor(of: leafB, toward: .left, in: view) == tree.desktop)
    #expect(Navigation.neighbor(of: tree.desktop, toward: .left, in: view) == tree.parent(of: leafA))
    #expect(Navigation.neighbor(of: leafC, toward: .top, in: view) == leafA)
  }

  @Test func steppingInSeesThroughAColumnWithOneWindowLeft() {
    let (tree, leafA, _, _) = columns()
    // c is minimized, so the column looks exactly like a: stepping into it would change nothing.
    let view = TreeView(tree: tree, isPresent: { $0 != c })
    let column = tree.parent(of: leafA)!
    #expect(view.passThrough(column) == leafA)
    let layout = LayoutEngine.layout(tree, camera: column, in: screen, isPresent: { $0 != c })
    #expect(Navigation.stepIn(from: column, toward: nil, focused: a, in: view, layout: layout) == nil)
  }

  @Test func theAdjacentLeafIsTheNearestOneBeyondThatEdge() {
    // [a | b | c | Desktop]: right of a is b, not c; left of c is b, not a.
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let leafB = tree.dock(b, beside: leafA, edge: .right)
    let leafC = tree.dock(c, beside: leafB, edge: .right)
    let options = LayoutOptions(minimumUsableSize: .zero)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: options, isPresent: everyone)
    #expect(Navigation.adjacentLeaf(to: leafA, toward: .right, in: layout, tree: tree) == leafB)
    #expect(Navigation.adjacentLeaf(to: leafC, toward: .left, in: layout, tree: tree) == leafB)
    #expect(Navigation.adjacentLeaf(to: leafA, toward: .bottom, in: layout, tree: tree) == nil)
    #expect(Navigation.adjacentLeaf(to: leafA, toward: .top, in: layout, tree: tree) == nil)

    // The same standing up.
    var tall = LayoutTree()
    let top = tall.dock(a, beside: tall.root, edge: .top)
    let middle = tall.dock(b, beside: top, edge: .bottom)
    let low = tall.dock(c, beside: middle, edge: .bottom)
    let standing = LayoutEngine.layout(tall, camera: tall.root, in: screen, options: options, isPresent: everyone)
    #expect(Navigation.adjacentLeaf(to: top, toward: .bottom, in: standing, tree: tall) == middle)
    #expect(Navigation.adjacentLeaf(to: low, toward: .top, in: standing, tree: tall) == middle)
    #expect(Navigation.adjacentLeaf(to: top, toward: .right, in: standing, tree: tall) == nil)
  }

  @Test func ofTwoNodesThatFitEquallyWellTheSmallerIsFramed() {
    // A column whose other window is absent has the same rectangle as its one window.
    let (tree, leafA, _, _) = columns()
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { $0 != c })
    let frame = layout.windowFrames[a]!
    #expect(layout.nodeFrames[tree.parent(of: leafA)!] == frame)
    let best = Navigation.bestFit(for: frame, in: layout)
    #expect(best == leafA || best == tree.parent(of: leafA), "either shows the same thing")
    // Around nothing at all: nothing.
    #expect(Navigation.bestFit(for: CGRect(x: -500, y: -500, width: 100, height: 100), in: layout) == nil)
  }

  // MARK: History

  @Test func historyKeepsTheLastFiftyPlaces() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let places = [workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: b)!]
    for step in 0..<120 { workspace.moveCamera(to: places[step % 2]) }
    #expect(workspace.back.count == 50)
    var steps = 0
    while workspace.goBack() { steps += 1 }
    #expect(steps == 50)
  }

  // MARK: Stacks

  @Test func droppingOnAStackJoinsItAndTheNewcomerShows() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let leaf = workspace.tree.leaf(containing: a)!
    workspace.floating[b] = CGRect(x: 0, y: 0, width: 100, height: 100)
    let docked = workspace.dock(b, at: .stack(leaf))
    #expect(docked)
    #expect(workspace.tree.leaf(containing: b) == leaf)
    #expect(workspace.tree.activeWindow(of: leaf) == b)
    #expect(!workspace.isFloating(b))
  }
}
