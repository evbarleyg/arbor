import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

/// Values nobody meant: slips in settings.json, damaged state.json files, ties. Found by the chaos test
/// and the sweep that went with it (collab/reports/2026-10-14-chaos.md).
@Suite struct RobustnessTests {
  /// [a / c | Desktop | b]
  func tree() -> LayoutTree {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: tree.root, edge: .right)
    tree.dock(c, beside: first, edge: .bottom)
    return tree
  }

  func rects(of layout: Layout) -> [CGRect] {
    Array(layout.nodeFrames.values) + layout.tiles.flatMap { Array($0.miniature.values) } + layout.seams.map(\.frame)
  }

  // MARK: Gaps

  @Test(arguments: [-12, -1e9, 400, 5000, 1e9, 1e300, Double.infinity, Double.nan])
  func anyGapGivesFiniteFramesInsideTheScreen(gap: Double) {
    let tree = tree()
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, options: LayoutOptions(gap: CGFloat(gap), minimumUsableSize: .zero),
      isPresent: { _ in true })
    #expect(layout.windowFrames.count == 3)
    for rect in rects(of: layout) {
      #expect(rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite, "\(rect)")
      #expect(screen.contains(rect) || rect.isEmpty, "\(rect)")
    }
  }

  @Test func aNegativeGapIsNoGap() {
    let tree = tree()
    func layout(gap: CGFloat) -> Layout {
      LayoutEngine.layout(tree, camera: tree.root, in: screen, options: LayoutOptions(gap: gap), isPresent: { _ in true })
    }
    #expect(layout(gap: -12) == layout(gap: 0))
  }

  @Test func sensibleGapsAreLeftAlone() {
    let tree = tree()
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, options: LayoutOptions(gap: 60), isPresent: { _ in true })
    #expect(layout.windowFrames[a]?.origin == CGPoint(x: 60, y: 85))
    #expect(layout.seams.allSatisfy { min($0.frame.width, $0.frame.height) == 60 })
  }

  @Test func manyChildrenInASmallRectangleStayInsideIt() {
    var tree = LayoutTree()
    for raw in UInt32(1)...40 { tree.dock(WindowID(raw), beside: tree.root, edge: .left) }
    let small = CGRect(x: 100, y: 100, width: 300, height: 200)
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: small, options: LayoutOptions(gap: 12, minimumUsableSize: .zero),
      isPresent: { _ in true })
    #expect(layout.windowFrames.count == 40)
    for rect in layout.windowFrames.values { #expect(small.contains(rect) || rect.isEmpty, "\(rect)") }
  }

  @Test func theMiniatureOfAVerySmallGroupTileIsFinite() {
    var tree = tree()
    // The column [a / c] is squeezed to a sliver, so it is drawn as a group tile 4 points wide.
    let column = tree.parent(of: tree.leaf(containing: a)!)!
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: -5000, pointsPerWeight: 460, minimumPoints: 4)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true })
    let tile = layout.tiles.first { $0.node == column }
    #expect(tile?.kind == .group)
    #expect(tile?.miniature.count == 2)
    for rect in tile?.miniature.values.map({ $0 }) ?? [] { #expect(rect.minX.isFinite && rect.width.isFinite, "\(rect)") }
  }

  @Test(arguments: [0, -1, -1e300, 1e-300, 1e300, Double.infinity, Double.nan])
  func gridSurvivesAnyDesktopWeight(weight: Double) {
    let tree = LayoutTree.grid(of: [a, b, c], desktopWeight: weight)
    #expect(tree.invariantViolations().isEmpty)
    let share = tree[tree.desktop]!.weight
    #expect((0.05...20).contains(share))
  }

  @Test func theAsciiRendererSurvivesFramesThatAreNotNumbers() {
    let tree = tree()
    var layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true })
    layout.windowFrames[a] = .null
    layout.windowFrames[b] = CGRect(x: CGFloat.nan, y: 1e300, width: -1e300, height: CGFloat.infinity)
    #expect(!AsciiRenderer.render(layout, tree: tree).isEmpty)
  }

  // MARK: Ties

  @Test func aTieBetweenASplitAndItsOnlyPresentChildAlwaysFallsTheSameWay() {
    let tree = tree()
    let leaf = tree.leaf(containing: a)!
    // c is minimized, so the column [a / c] and a have the same rectangle.
    for _ in 0..<20 {
      let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { $0 != c })
      #expect(Navigation.bestFit(for: layout.nodeFrames[leaf]!, in: layout) == leaf)
    }
  }

  @Test func ofTwoEquallyNearNeighboursTheTopmostIsAdjacent() {
    let tree = tree()
    for _ in 0..<20 {
      let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true })
      #expect(Navigation.adjacentLeaf(to: tree.desktop, toward: .left, in: layout, tree: tree) == tree.leaf(containing: a))
    }
  }
}
