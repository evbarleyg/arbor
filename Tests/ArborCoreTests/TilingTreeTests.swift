import ArborCore
import CoreGraphics
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

private func axis(of node: NodeID, in tree: LayoutTree) -> Axis? {
  if case .split(let axis, _) = tree[node]?.kind { return axis }
  return nil
}

private func weights(of node: NodeID, in tree: LayoutTree) -> [Double] {
  tree.children(of: node).map { tree[$0]!.weight }
}

private func frames(_ tree: LayoutTree, camera: NodeID? = nil) -> [WindowID: CGRect] {
  LayoutEngine.layout(
    tree, camera: camera ?? tree.root, in: screen, options: LayoutOptions(gap: 0, minimumUsableSize: .zero),
    isPresent: { _ in true }
  ).windowFrames
}

/// F22: the tree operations behind `equalize`, `rotate`, `mirror` and `swap` across displays.
@Suite struct TilingTreeTests {
  /// root(h)[ column(v)[a, c], desktop, b ]
  func fixture() -> (tree: LayoutTree, column: NodeID) {
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: tree.root, edge: .right)
    tree.dock(c, beside: leafA, edge: .bottom)
    return (tree, tree.parent(of: leafA)!)
  }

  // MARK: equalize

  @Test func equalizeGivesEveryChildOfEverySplitTheSameWeight() {
    let column = fixture().column
    var tree = fixture().tree
    let root = tree.root
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: 200, pointsPerWeight: 400)
    tree.moveBoundary(
      leading: tree.children(of: column)[0], trailing: tree.children(of: column)[1], by: -100, pointsPerWeight: 400)
    #expect(Set(weights(of: root, in: tree)).count > 1 && Set(weights(of: column, in: tree)).count > 1)
    tree.equalize(under: root, desktopWeight: 0.5)
    #expect(weights(of: root, in: tree) == [1, 1, 1], "the Desktop between windows counts as one")
    #expect(weights(of: column, in: tree) == [1, 1])
    #expect(tree.invariantViolations().isEmpty)
  }

  /// What `grid` does with the same setting, or evening out would not give back what `arrange` made.
  @Test(arguments: [(1e300, 20), (100, 20), (20, 20), (0.5, 0.5), (0.001, 0.05), (0, 0.05), (-3, 0.05), (.infinity, 20), (.nan, 0.5)])
  func theDesktopsWeightIsBoundedAsInAGrid(given: Double, used: Double) {
    var tree = LayoutTree.grid(of: [a, b, c, d], desktopWeight: given)
    let arranged = tree
    #expect(tree[tree.desktop]!.weight == used)
    tree.moveBoundary(leading: tree.children(of: tree.root)[0], trailing: tree.children(of: tree.root)[1], by: 50, pointsPerWeight: 400)
    tree.equalize(under: tree.root, desktopWeight: given)
    #expect(tree == arranged)
  }

  /// A group that runs along the row around it (a turned pair, F62) looks like part of the row: what cannot be seen does not
  /// change what a command does. It counts for as many places as it shows.
  @Test func aGroupThatRunsAlongItsRowCountsForAsManyPlacesAsItShows() {
    // root(h)[ a, pair(h, turned)[c, d], b, desktop ]
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    let leafC = tree.dock(c, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(d, beside: leafC, edge: .bottom)
    tree.dock(b, beside: tree.parent(of: leafC)!, edge: .right)
    let pair = tree.parent(of: leafC)!
    tree.rotate(pair)
    #expect(tree.children(of: tree.root).count == 4 && axis(of: pair, in: tree) == .horizontal)
    tree.equalize(under: tree.root)
    #expect(weights(of: tree.root, in: tree) == [1, 2, 1, 1] && weights(of: pair, in: tree) == [1, 1])
    let widths = [a, c, d, b].map { frames(tree)[$0]!.width }
    #expect(Set(widths).count == 1, "\(widths)")
    // Turned back it is one place again, with two windows one above the other.
    tree.rotate(pair)
    tree.equalize(under: tree.root)
    #expect(weights(of: tree.root, in: tree) == [1, 1, 1, 1])
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func equalizeLeavesEverythingOutsideTheSubtreeAlone() {
    let column = fixture().column
    var tree = fixture().tree
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: 200, pointsPerWeight: 400)
    tree.moveBoundary(
      leading: tree.children(of: column)[0], trailing: tree.children(of: column)[1], by: -100, pointsPerWeight: 400)
    let outside = weights(of: tree.root, in: tree)
    tree.equalize(under: column)
    #expect(weights(of: column, in: tree) == [1, 1])
    #expect(weights(of: tree.root, in: tree) == outside, "including the subtree's own share")
  }

  @Test func equalizeGivesBackWhatArrangeMade() {
    let arranged = LayoutTree.grid(of: [a, b, c, d], desktopWeight: 0.5)
    var tree = arranged
    let columns = tree.children(of: tree.root)
    tree.moveBoundary(leading: columns[0], trailing: columns[1], by: 150, pointsPerWeight: 400)
    tree.moveBoundary(leading: columns[1], trailing: columns[2], by: -90, pointsPerWeight: 400)
    #expect(tree != arranged)
    tree.equalize(under: tree.root, desktopWeight: 0.5)
    #expect(tree == arranged)
  }

  @Test func theDesktopIsNarrowOnlyWhereArrangePutsIt() {
    // First in the row.
    var leading = LayoutTree()
    leading.dock(a, beside: leading.root, edge: .right)
    leading.equalize(under: leading.root, desktopWeight: 0.5)
    #expect(weights(of: leading.root, in: leading) == [1, 1])
    // Last in a column.
    var below = LayoutTree()
    below.dock(a, beside: below.root, edge: .top)
    below.equalize(under: below.root, desktopWeight: 0.5)
    #expect(weights(of: below.root, in: below) == [1, 1])
    // Last in a row that is not the root.
    var nested = LayoutTree()
    nested.dock(a, beside: nested.root, edge: .left)
    nested.dock(b, beside: nested.root, edge: .top)
    nested.equalize(under: nested.root, desktopWeight: 0.5)
    #expect(weights(of: nested.parent(of: nested.desktop)!, in: nested) == [1, 1])
    // Last in the root row: as `arrange` leaves it.
    var trailing = LayoutTree()
    trailing.dock(a, beside: trailing.root, edge: .left)
    trailing.equalize(under: trailing.root, desktopWeight: 0.5)
    #expect(weights(of: trailing.root, in: trailing) == [1, 0.5])
  }

  @Test func equalizeOnALeafOrAMissingNodeDoesNothing() {
    let (tree, _) = fixture()
    var copy = tree
    copy.equalize(under: tree.leaf(containing: a)!)
    copy.equalize(under: tree.desktop)
    copy.equalize(under: NodeID(999))
    #expect(copy == tree)
  }

  // MARK: rotate

  @Test func rotatingTheRootTurnsRowsIntoColumnsAllTheWayDown() {
    let (original, column) = fixture()
    var tree = original
    tree.rotate(tree.root)
    #expect(tree.preorder() == original.preorder(), "every node is still there")
    #expect(axis(of: tree.root, in: tree) == .vertical)
    #expect(axis(of: column, in: tree) == .horizontal, "the group inside stays a group")
    #expect(tree.children(of: tree.root) == original.children(of: original.root))
    #expect(tree.children(of: column) == original.children(of: column))
    #expect(tree.invariantViolations().isEmpty)
    // Every window's frame is mirrored in the diagonal.
    let before = frames(original)
    let after = frames(tree)
    let (sx, sy) = (screen.width / screen.height, screen.height / screen.width)
    for (window, frame) in before {
      let expected = CGRect(x: frame.minY * sx, y: frame.minX * sy, width: frame.height * sx, height: frame.width * sy)
      #expect(after[window]!.approximatelyEquals(expected, tolerance: 1), "\(window)")
    }
    tree.rotate(tree.root)
    #expect(tree == original, "twice is back where it started")
  }

  /// It runs along the row around it now, where the tree would dissolve it. It stays, so that turning it again turns the same pair.
  @Test func anInnerGroupStaysAGroupAndTurnsBack() {
    let (original, column) = fixture()
    var tree = original
    let region = frames(original)[a]!.union(frames(original)[c]!)
    tree.rotate(column)
    #expect(tree.preorder() == original.preorder())
    #expect(axis(of: column, in: tree) == .horizontal && axis(of: tree.root, in: tree) == .horizontal)
    #expect(tree[column]?.keeps == .turned)
    #expect(tree.invariantViolations().isEmpty)
    // Side by side, in the same order, in exactly the same room; nothing else moved.
    let after = frames(tree)
    #expect(after[a]!.union(after[c]!) == region)
    #expect(after[a]!.maxX <= after[c]!.minX && after[a]!.height == region.height)
    #expect(after[b] == frames(original)[b])
    tree.rotate(column)
    #expect(tree == original, "mark and all")
  }

  @Test func aTurnedGroupGivesWayToItsLastWindow() {
    var (tree, column) = fixture()
    tree.rotate(column)
    let remap = tree.remove(c)
    #expect(!tree.contains(column) && remap.resolve(column, in: tree) == tree.leaf(containing: a))
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func turningWhatIsAroundATurnedGroupKeepsIt() {
    var (tree, column) = fixture()
    tree.rotate(column)
    tree.rotate(tree.root)
    #expect(axis(of: column, in: tree) == .vertical && axis(of: tree.root, in: tree) == .vertical)
    #expect(tree[column]?.keeps == .turned && tree.invariantViolations().isEmpty)
  }

  @Test func rotatingKeepsUnequalWeights() {
    let column = fixture().column
    var tree = fixture().tree
    tree.moveBoundary(
      leading: tree.children(of: column)[0], trailing: tree.children(of: column)[1], by: 100, pointsPerWeight: 400)
    #expect(weights(of: column, in: tree) == [1.25, 0.75])
    tree.rotate(column)
    #expect(weights(of: column, in: tree) == [1.25, 0.75] && weights(of: tree.root, in: tree) == [1, 1, 1])
  }

  @Test func groupsInsideATurnedGroupTurnToo() {
    // root(h)[ column(v)[a, row(h)[c, d]], desktop ] → root(h)[ row(h)[a, column(v)[c, d]], desktop ]
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let leafC = tree.dock(c, beside: leafA, edge: .bottom)
    let leafD = tree.dock(d, beside: leafC, edge: .right)
    let (outer, row) = (tree.parent(of: leafA)!, tree.parent(of: leafC)!)
    tree.rotate(outer)
    #expect(tree.children(of: tree.root) == [outer, tree.desktop] && tree.children(of: outer) == [leafA, row])
    #expect(axis(of: outer, in: tree) == .horizontal && axis(of: row, in: tree) == .vertical)
    #expect(tree.children(of: row) == [leafC, leafD])
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func rotatingALeafOrAMissingNodeDoesNothing() {
    let (tree, _) = fixture()
    var copy = tree
    copy.rotate(tree.leaf(containing: a)!)
    copy.rotate(tree.desktop)
    copy.rotate(NodeID(999))
    #expect(copy == tree)
  }

  // MARK: mirror

  @Test func mirrorReversesTheChildrenAndNothingInsideThem() {
    let column = fixture().column
    var tree = fixture().tree
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: 200, pointsPerWeight: 400)
    let original = tree
    tree.mirror(tree.root)
    #expect(tree.children(of: tree.root) == original.children(of: original.root).reversed())
    #expect(weights(of: tree.root, in: tree) == weights(of: original.root, in: original).reversed(), "sizes go along")
    #expect(tree.children(of: column) == original.children(of: column))
    #expect(tree.invariantViolations().isEmpty)
    tree.mirror(tree.root)
    #expect(tree == original)
    tree.mirror(tree.leaf(containing: a)!)
    tree.mirror(NodeID(999))
    #expect(tree == original)
  }

  // MARK: trading places

  @Test func leavesTradePlacesAndTheSlotsKeepTheirSizes() {
    let column = fixture().column
    var tree = fixture().tree
    tree.moveBoundary(leading: tree.desktop, trailing: tree.leaf(containing: b)!, by: -150, pointsPerWeight: 400)
    tree.moveBoundary(
      leading: tree.children(of: column)[0], trailing: tree.children(of: column)[1], by: -100, pointsPerWeight: 400)
    let (original, before) = (tree, frames(tree))
    let (leafA, leafB, leafC) = (tree.leaf(containing: a)!, tree.leaf(containing: b)!, tree.leaf(containing: c)!)

    // Across levels of the tree.
    tree.tradePlaces(of: a, and: b)
    #expect(frames(tree) == [a: before[b]!, b: before[a]!, c: before[c]!])
    #expect(tree.leaf(containing: a) == leafA && tree.leaf(containing: b) == leafB, "a leaf goes with its window")
    #expect(tree.children(of: column) == [leafB, leafC] && tree.children(of: tree.root) == [column, tree.desktop, leafA])
    #expect(tree.invariantViolations().isEmpty)
    tree.tradePlaces(of: b, and: a)
    #expect(tree == original)

    // Within one group.
    tree.tradePlaces(of: a, and: c)
    #expect(frames(tree) == [a: before[c]!, b: before[b]!, c: before[a]!])
    #expect(tree.children(of: column) == [leafC, leafA])
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func tabGroupsTradePlacesWhole() {
    var tree = fixture().tree
    tree.addToStack(d, leaf: tree.leaf(containing: a)!)
    let before = frames(tree)
    tree.tradePlaces(of: a, and: b)
    #expect(tree.leaf(containing: a) == tree.leaf(containing: d))
    #expect(frames(tree)[d] == before[b] && frames(tree)[b] == before[d])
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func nothingTradesPlacesWithItselfOrWithWhatIsNotThere() {
    var tree = fixture().tree
    tree.addToStack(d, leaf: tree.leaf(containing: a)!)
    let original = tree
    tree.tradePlaces(of: a, and: a)
    tree.tradePlaces(of: a, and: d)
    tree.tradePlaces(of: a, and: WindowID(99))
    tree.tradePlaces(of: WindowID(99), and: a)
    #expect(tree == original)
  }

  // MARK: swapping between trees

  @Test func leavesOfTwoTreesExchangeWhatTheyHold() {
    var first = fixture().tree
    var second = LayoutTree()
    let leafD = second.dock(d, beside: second.root, edge: .left)
    second.addToStack(WindowID(5), leaf: leafD)
    let leafA = first.leaf(containing: a)!
    let (shape, secondShape) = (first.preorder(), second.preorder())
    LayoutTree.swapLeaves(of: a, in: &first, and: d, in: &second)
    #expect(first.windows(under: leafA) == [d, WindowID(5)], "a tab group travels whole")
    #expect(first.activeWindow(of: leafA) == WindowID(5))
    #expect(second.windows(under: leafD) == [a])
    #expect(first.preorder() == shape && second.preorder() == secondShape, "the slots stay")
    #expect(first.invariantViolations().isEmpty && second.invariantViolations().isEmpty)
    // A window that is not where it is said to be changes nothing.
    let (before, beforeSecond) = (first, second)
    LayoutTree.swapLeaves(of: a, in: &first, and: d, in: &second)
    #expect(first == before && second == beforeSecond)
  }
}
