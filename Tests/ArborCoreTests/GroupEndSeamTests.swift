import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

private let a = WindowID(1), b = WindowID(2), c = WindowID(3), d = WindowID(4), e = WindowID(5)
private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

/// F62: a kept group in a row on its own axis looks like part of the row. What cannot be seen must not change what
/// a drag does (T05): the gap at its end resizes the window on either side of the gap, and nothing else.
@Suite struct GroupEndSeamTests {
  private let options = LayoutOptions(minimumUsableSize: .zero)

  private func layout(_ tree: LayoutTree, absent: Set<WindowID> = []) -> Layout {
    LayoutEngine.layout(tree, camera: tree.root, in: screen, options: options, isPresent: { !absent.contains($0) })
  }

  /// `[ a | (c | d) | b | Desktop ]`, the pair kept.
  private func row() -> (tree: LayoutTree, pair: NodeID) {
    var tree = LayoutTree()
    tree.dock(b, beside: tree.root, edge: .left)
    tree.dock(c, beside: tree.root, edge: .left)
    tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(d, beside: tree.leaf(containing: c)!, edge: .right, groupingFor: .name)
    let pair = tree.parent(of: tree.leaf(containing: c)!)!
    #expect(tree.children(of: tree.root).count == 4 && tree.windows(under: pair) == [c, d])
    return (tree, pair)
  }

  private func seam(_ layout: Layout, _ leading: NodeID, _ trailing: NodeID) -> Seam {
    layout.seams.first { $0.leading == leading && $0.trailing == trailing }!
  }

  /// Moves the seam and returns how each window's frame changed: (left edge, width).
  private func changes(
    _ tree: inout LayoutTree, _ seam: Seam, by delta: Double, absent: Set<WindowID> = []
  ) -> [WindowID: [CGFloat]] {
    let before = layout(tree, absent: absent).windowFrames
    tree.moveBoundary(at: seam, by: delta)
    #expect(tree.invariantViolations() == [])
    let after = layout(tree, absent: absent).windowFrames
    #expect(after.keys == before.keys)
    return after.reduce(into: [:]) { result, entry in
      let change = [entry.value.minX - before[entry.key]!.minX, entry.value.width - before[entry.key]!.width]
      if change != [0, 0] { result[entry.key] = change }
    }
  }

  @Test func theGapAfterTheGroupResizesItsLastWindowAndTheNeighbour() {
    var (tree, pair) = row()
    let seam = seam(layout(tree), pair, tree.leaf(containing: b)!)
    #expect(changes(&tree, seam, by: 60) == [d: [0, 60], b: [60, -60]], "c used to grow as well")
    let again = self.seam(layout(tree), pair, tree.leaf(containing: b)!)
    #expect(changes(&tree, again, by: -100) == [d: [0, -100], b: [-100, 100]])
  }

  @Test func theGapBeforeTheGroupResizesItsFirstWindowAndTheNeighbour() {
    var (tree, pair) = row()
    let seam = seam(layout(tree), tree.leaf(containing: a)!, pair)
    #expect(changes(&tree, seam, by: -40) == [a: [0, -40], c: [-40, 40]])
  }

  @Test func theGapInsideTheGroupIsAsItWas() {
    var (tree, _) = row()
    let seam = seam(layout(tree), tree.leaf(containing: c)!, tree.leaf(containing: d)!)
    #expect(seam.leadingEnds.isEmpty && seam.trailingEnds.isEmpty)
    #expect(changes(&tree, seam, by: 30) == [c: [0, 30], d: [30, -30]])
  }

  @Test func aGroupAtTheEndOfAGroupGoesAllTheWayDown() {
    var (tree, pair) = row()
    tree.dock(e, beside: tree.leaf(containing: d)!, edge: .right, groupingFor: .name)
    #expect(tree.children(of: pair).count == 2 && tree.windows(under: pair) == [c, d, e])
    let seam = seam(layout(tree), pair, tree.leaf(containing: b)!)
    #expect(seam.leadingEnds.count == 2)
    #expect(changes(&tree, seam, by: 50) == [e: [0, 50], b: [50, -50]])
  }

  @Test func twoGroupsSideBySideGiveAndTakeAtTheirEnds() {
    var (tree, pair) = row()
    tree.dock(e, beside: tree.leaf(containing: b)!, edge: .right, groupingFor: .name)
    let other = tree.parent(of: tree.leaf(containing: b)!)!
    let seam = seam(layout(tree), pair, other)
    #expect(changes(&tree, seam, by: 24) == [d: [0, 24], b: [24, -24]])
  }

  /// A column at the end of the group is one thing beside the gap: both of its windows follow.
  @Test func whatIsAcrossTheAxisAtTheEndMovesAsOne() {
    var (tree, pair) = row()
    tree.dock(e, beside: tree.leaf(containing: d)!, edge: .bottom)
    let seam = seam(layout(tree), pair, tree.leaf(containing: b)!)
    #expect(changes(&tree, seam, by: 36) == [d: [0, 36], e: [0, 36], b: [36, -36]])
  }

  @Test func theLastWindowThatIsThereCounts() {
    var (tree, pair) = row()
    tree.dock(e, beside: tree.leaf(containing: d)!, edge: .right)
    #expect(tree.children(of: pair).count == 3)
    let seam = seam(layout(tree, absent: [e]), pair, tree.leaf(containing: b)!)
    #expect(changes(&tree, seam, by: 48, absent: [e]) == [d: [0, 48], b: [48, -48]])
  }

  @Test func aGroupShowingOneWindowGivesItEverything() {
    var (tree, pair) = row()
    let seam = seam(layout(tree, absent: [d]), pair, tree.leaf(containing: b)!)
    #expect(changes(&tree, seam, by: 48, absent: [d]) == [c: [0, 48], b: [48, -48]])
  }

  /// The least is a window's, as in the flat row. The group had room to give; its last window has not.
  @Test func theWindowBesideTheGapStopsAtTheLeast() {
    var (tree, pair) = row()
    let seam = seam(layout(tree), pair, tree.leaf(containing: b)!)
    let before = layout(tree).windowFrames
    tree.moveBoundary(at: seam, by: -10_000)
    let after = layout(tree).windowFrames
    #expect(abs(after[d]!.width - 80) <= 1 && after[c] == before[c] && after[a] == before[a])
    let back = self.seam(layout(tree), pair, tree.leaf(containing: b)!)
    tree.moveBoundary(at: back, by: 10_000)
    #expect(abs(layout(tree).windowFrames[b]!.width - 80) <= 1 && layout(tree).windowFrames[c] == before[c])
  }

  @Test func aSeamOfALayoutTheTreeHasLeftBehindMovesNothing() {
    var (tree, pair) = row()
    let seam = seam(layout(tree), pair, tree.leaf(containing: b)!)
    tree.remove(d)
    let before = tree
    tree.moveBoundary(at: seam, by: 50)
    #expect(tree == before)
  }

  @Test(arguments: [Double.nan, .infinity, -.infinity])
  func aDistanceThatIsNotOneMovesNothingOrStopsAtTheLeast(by: Double) {
    var (tree, pair) = row()
    tree.moveBoundary(at: seam(layout(tree), pair, tree.leaf(containing: b)!), by: by)
    #expect(tree.invariantViolations() == [])
    #expect(layout(tree).windowFrames.values.allSatisfy { $0.width >= 79 })
  }

  /// In any tree with groups kept on their parents' axes: a whole number of points at any seam changes what is beside
  /// the gap, by that much, and nothing else.
  @Test(arguments: Array<UInt64>(1...60)) func anySeamMovesOnlyWhatIsBesideIt(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var tree = LayoutTree()
    for id in 1...UInt32(Int.random(in: 3...9, using: &random)) {
      let target = tree.preorder().randomElement(using: &random)!
      tree.dock(
        WindowID(id), beside: target, edge: Edge.allCases.randomElement(using: &random)!,
        groupingFor: Bool.random(using: &random) ? .name : nil)
    }
    let big = CGRect(x: 0, y: 0, width: 5000, height: 4000)
    func frames(_ tree: LayoutTree) -> Layout {
      LayoutEngine.layout(tree, camera: tree.root, in: big, options: options, isPresent: { _ in true })
    }
    for seam in frames(tree).seams {
      var moved = tree
      let before = frames(tree)
      let delta = Double(Int.random(in: -30...30, using: &random))
      moved.moveBoundary(at: seam, by: delta, minimumPoints: 0)
      #expect(moved.invariantViolations() == [])
      let after = frames(moved)
      let beside = [seam.leadingEnds.last?.node ?? seam.leading, seam.trailingEnds.last?.node ?? seam.trailing]
      for (node, frame) in before.nodeFrames where tree.children(of: node).isEmpty {
        if beside.contains(where: { tree.subtree($0, contains: node) }) { continue }
        #expect(after.nodeFrames[node] == frame, "\(node) moved with the seam \(seam.leading)|\(seam.trailing)")
      }
      func length(_ layout: Layout) -> CGFloat { layout.nodeFrames[beside[0]]!.length(along: seam.axis) }
      let grown = length(after) - length(before)
      #expect(abs(Double(grown) - delta) < 0.5 || abs(grown) < abs(CGFloat(delta)), "\(grown) for \(delta)")
    }
  }
}
