import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private func everyone(_: WindowID) -> Bool { true }

/// Swift seeds hashing afresh in every process, so the order in which a Dictionary or a Set is
/// walked differs from run to run and between platforms. Nothing a user can see may depend on it.
///
/// One process has one seed, so these tests vary what is hashed instead: the same shape is built
/// many times over with different node ids, and the answer must follow the stated rule every time.
/// An answer that followed hash order would break the rule in about half of the variants.
@Suite struct DeterminismTests {
  /// A tree whose next node ids start `offset` higher, by docking and removing that many windows.
  private func tree(offset: Int) -> LayoutTree {
    var tree = LayoutTree()
    for _ in 0..<offset {
      tree.dock(WindowID(999), beside: tree.root, edge: .left)
      tree.remove(WindowID(999))
    }
    return tree
  }

  /// [ tall | top / bottom | desktop ]: both windows of the column are one gap to the right of `tall`.
  @Test func movingTowardTwoEquallyNearWindowsPicksTheFirstOfThem() {
    for offset in 0..<24 {
      for bottomFirst in [false, true] {
        var tree = tree(offset: offset)
        let tall = tree.dock(WindowID(1), beside: tree.root, edge: .left)
        // Built in either order, so neither the ids nor the hashes favour one of the two.
        var top = tree.dock(WindowID(2), beside: tall, edge: .right)
        var bottom = tree.dock(WindowID(3), beside: top, edge: bottomFirst ? .top : .bottom)
        if bottomFirst { swap(&top, &bottom) }
        let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
        #expect(layout.nodeFrames[top]!.minY < layout.nodeFrames[bottom]!.minY)
        #expect(Navigation.adjacentLeaf(to: tall, toward: .right, in: layout, tree: tree) == top, "offset \(offset)")
      }
    }
  }

  /// The same on the other axis: [ wide / (left | right) ].
  @Test func movingDownTowardTwoEquallyNearWindowsPicksTheLeftOne() {
    for offset in 0..<24 {
      var tree = tree(offset: offset)
      let wide = tree.dock(WindowID(1), beside: tree.root, edge: .left)
      let right = tree.dock(WindowID(2), beside: wide, edge: .bottom)
      let left = tree.dock(WindowID(3), beside: right, edge: .left)
      let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
      #expect(Navigation.adjacentLeaf(to: wide, toward: .bottom, in: layout, tree: tree) == left, "offset \(offset)")
    }
  }

  /// Of two equally near windows, the one that shares more of the edge is the neighbour.
  @Test func theNeighbourThatSharesMoreOfTheEdgeWins() {
    for offset in 0..<24 {
      var tree = tree(offset: offset)
      let tall = tree.dock(WindowID(1), beside: tree.root, edge: .left)
      let top = tree.dock(WindowID(2), beside: tall, edge: .right)
      let bottom = tree.dock(WindowID(3), beside: top, edge: .bottom)
      tree.moveBoundary(leading: top, trailing: bottom, by: -150, pointsPerWeight: 400)
      let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
      #expect(Navigation.adjacentLeaf(to: tall, toward: .right, in: layout, tree: tree) == bottom, "offset \(offset)")
    }
  }

  /// A split showing one child has that child's rectangle, so both fit a rectangle equally well.
  @Test func framingASplitThatShowsOneChildFramesTheChild() {
    for offset in 0..<24 {
      for lateChild in [false, true] {
        var tree = tree(offset: offset)
        let first = tree.dock(WindowID(1), beside: tree.root, edge: .left)
        tree.dock(WindowID(2), beside: first, edge: .bottom)
        // The child that stays is older than the split (a lower id) or younger (a higher one).
        let third = tree.dock(WindowID(3), beside: first, edge: .top)
        let shown = lateChild ? WindowID(3) : WindowID(1)
        let leaf = lateChild ? third : first
        let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { $0 == shown })
        let column = tree.parent(of: leaf)!
        #expect(layout.nodeFrames[column] == layout.nodeFrames[leaf])
        #expect(Navigation.bestFit(for: layout.nodeFrames[leaf]!, in: layout, tree: tree) == leaf, "offset \(offset)")
        // Without the tree there is no telling which is inside which, but the answer is still always the same.
        #expect(Navigation.bestFit(for: layout.nodeFrames[leaf]!, in: layout) == min(column, leaf), "offset \(offset)")
      }
    }
  }

  /// The order a dictionary is walked in also depends on its capacity and history. Equal layouts
  /// must give equal answers however their dictionaries came about.
  @Test func answersDoNotDependOnHowTheLayoutsDictionariesWereBuilt() {
    let tree = LayoutTree.random(seed: 21, windows: 14)
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, options: LayoutOptions(minimumUsableSize: CGSize(width: 120, height: 90)),
      isPresent: everyone)
    var random = SeededRandom(seed: 4)
    let probes = (0..<60).map { _ in
      CGPoint(x: CGFloat.random(in: screen.minX...screen.maxX, using: &random), y: CGFloat.random(in: screen.minY...screen.maxY, using: &random))
    }
    func answers(_ layout: Layout) -> [NodeID?] {
      var result: [NodeID?] = probes.map { layout.leafOrTile(at: $0, in: tree) }
      for point in probes {
        result.append(Navigation.bestFit(for: CGRect(x: point.x, y: point.y, width: 300, height: 220), in: layout, tree: tree))
      }
      for node in tree.preorder() {
        for edge in Edge.allCases { result.append(Navigation.adjacentLeaf(to: node, toward: edge, in: layout, tree: tree)) }
      }
      return result
    }
    let expected = answers(layout)
    for capacity in [0, 16, 100, 1_000, 5_000] {
      var rebuilt = layout
      rebuilt.nodeFrames = Dictionary(minimumCapacity: capacity)
      for (node, frame) in layout.nodeFrames.sorted(by: { $0.key > $1.key }) { rebuilt.nodeFrames[node] = frame }
      rebuilt.windowFrames = Dictionary(minimumCapacity: capacity)
      for (window, frame) in layout.windowFrames.sorted(by: { $0.key > $1.key }) { rebuilt.windowFrames[window] = frame }
      #expect(rebuilt == layout)
      #expect(answers(rebuilt) == expected, "capacity \(capacity)")
    }
  }

  @Test func reportsListThingsInAFixedOrder() {
    var workspace = Workspace()
    for id in [9, 3, 7, 1, 5] as [UInt32] { workspace.floating[WindowID(id)] = CGRect(x: 0, y: 0, width: 10, height: 10) }
    #expect(workspace.allWindows == [1, 3, 5, 7, 9].map { WindowID($0) })
  }
}
