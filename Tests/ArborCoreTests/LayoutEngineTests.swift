import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let content = screen.insetBy(dx: 12, dy: 12)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)

private func everyone(_: WindowID) -> Bool { true }

/// [a | desktop | b] with c docked below a.
private func threeWindowTree() -> (LayoutTree, NodeID, NodeID, NodeID) {
  var tree = LayoutTree()
  let leafA = tree.dock(a, beside: tree.root, edge: .left)
  let leafB = tree.dock(b, beside: tree.root, edge: .right)
  let leafC = tree.dock(c, beside: leafA, edge: .bottom)
  return (tree, leafA, leafB, leafC)
}

@Suite struct LayoutEngineTests {
  @Test func theDesktopAloneFillsTheContentArea() {
    let tree = LayoutTree()
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    #expect(layout.desktopFrame == content)
    #expect(layout.windowFrames.isEmpty)
  }

  @Test func equalWeightsSplitEvenlyWithExactGaps() {
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: tree.root, edge: .right)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    let left = layout.windowFrames[a]!
    let right = layout.windowFrames[b]!
    let desktop = layout.desktopFrame!
    #expect(left.minX == content.minX)
    #expect(right.maxX == content.maxX)
    #expect(desktop.minX - left.maxX == 12)
    #expect(right.minX - desktop.maxX == 12)
    #expect(abs(left.width - right.width) <= 1)
    for frame in [left, right, desktop] {
      #expect(frame == frame.integralRounded)
      #expect(frame.minY == content.minY && frame.height == content.height)
    }
  }

  @Test func aCameraOnALeafFillsTheScreenAndHidesTheRest() {
    let (tree, leafA, _, _) = threeWindowTree()
    let layout = LayoutEngine.layout(tree, camera: leafA, in: screen, isPresent: everyone)
    #expect(layout.windowFrames == [a: content])
    #expect(layout.hiddenWindows == [b, c])
    #expect(layout.desktopFrame == nil)
  }

  @Test func absentWindowsGiveTheirSpaceToNeighbours() {
    let (tree, _, _, _) = threeWindowTree()
    let full = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    let without = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { $0 != c })
    #expect(without.windowFrames[c] == nil)
    #expect(without.hiddenWindows.isEmpty)
    #expect(without.windowFrames[a]!.height == content.height)
    #expect(without.windowFrames[a]!.width == full.windowFrames[a]!.width)
  }

  /// A place that keeps its room for a window that is not there: laid out as if it were, then left open.
  @Test func aPlaceLeftOpenKeepsItsRoomAndHoldsNobody() {
    let (tree, _, _, leafC) = threeWindowTree()
    let full = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    let open = full.leavingOpen([c], in: tree)
    #expect(open.windowFrames == [a: full.windowFrames[a]!, b: full.windowFrames[b]!])
    #expect(open.openPlaces == [leafC: full.windowFrames[c]!])
    #expect(open.nodeFrames == full.nodeFrames.filter { $0.key != leafC })
    #expect(open.seams == full.seams && open.desktopFrame == full.desktopFrame && open.camera == full.camera)
    #expect(open.leafOrTile(at: full.windowFrames[c]!.center, in: tree) == nil, "there is nothing to point at")
    #expect(Navigation.bestFit(for: full.windowFrames[c]!, in: open, tree: tree) != leafC, "nor to draw a rectangle round")
    #expect(full.leavingOpen([], in: tree) == full)
    #expect(Set(BackdropShape.slots(of: open, in: tree).map(\.origin.y)) == Set(BackdropShape.slots(of: full, in: tree).map(\.origin.y)))

    // A group of nobody is one open place, by its outermost node.
    let column = tree.parent(of: leafC)!
    let both = full.leavingOpen([a, c], in: tree)
    #expect(both.openPlaces == [column: full.nodeFrames[column]!])
    #expect(both.nodeFrames[column] == nil && both.nodeFrames[leafC] == nil)

    // Outside the view there is nobody to take out of it.
    let framed = LayoutEngine.layout(tree, camera: tree.leaf(containing: a)!, in: screen, isPresent: everyone)
    #expect(framed.leavingOpen([c], in: tree).hiddenWindows == [b] && framed.leavingOpen([c], in: tree).openPlaces.isEmpty)
  }

  @Test func aPlaceLeftOpenIsNoTileAndIsInNone() throws {
    let (tree, leafA, _, _) = threeWindowTree()
    let narrow = CGRect(x: 0, y: 0, width: 500, height: 800)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: narrow, isPresent: everyone)
    let column = try #require(tree.parent(of: leafA))
    #expect(Set(layout.tiles.map(\.kind)) == [.group, .desktop, .window])
    // Alone in its tile: the tile goes. The Desktop's holds no window at the best of times, and stays.
    #expect(layout.leavingOpen([b], in: tree).tiles.map(\.kind).sorted { $0.rawValue < $1.rawValue } == [.desktop, .group])
    // One of a group: the other is still drawn.
    let group = try #require(layout.leavingOpen([c], in: tree).tiles.first { $0.node == column })
    #expect(group.windows == [a] && Array(group.miniature.keys) == [a])
    #expect(group.frame == layout.nodeFrames[column])
    // A group of nobody.
    #expect(!layout.leavingOpen([a, c], in: tree).tiles.contains { $0.node == column })
    #expect(layout.leavingOpen([a, c], in: tree).openPlaces[column] == layout.nodeFrames[column])
  }

  @Test func aMissingCameraFallsBackToAnEffectiveAncestor() {
    let (tree, _, _, leafC) = threeWindowTree()
    let layout = LayoutEngine.layout(tree, camera: leafC, in: screen, isPresent: { $0 != c })
    #expect(layout.camera != leafC)
    #expect(layout.windowFrames[a] != nil)
  }

  @Test func slotsBelowTheMinimumBecomeTiles() {
    let (tree, leafA, _, _) = threeWindowTree()
    let options = LayoutOptions(minimumUsableSize: CGSize(width: 500, height: 300))
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: options, isPresent: everyone)
    // Columns are about 464 wide, so every window is a tile; the column is a group tile.
    let column = tree.parent(of: leafA)!
    let tile = layout.tiles.first { $0.node == column }
    #expect(tile?.kind == .group)
    #expect(tile?.windows == [a, c])
    #expect(tile?.miniature.count == 2)
    #expect(layout.hiddenWindows.isSuperset(of: [a, b, c]))
    #expect(layout.windowFrames.isEmpty)
  }

  @Test func aLearnedMinimumSizeMakesATile() {
    let (tree, leafA, _, _) = threeWindowTree()
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, isPresent: everyone,
      minimumSize: { $0 == a ? CGSize(width: 900, height: 600) : nil })
    #expect(layout.tiles.map(\.node) == [leafA])
    #expect(layout.tiles.first?.kind == .window)
    #expect(layout.hiddenWindows == [a])
    #expect(layout.windowFrames[c] != nil)
  }

  @Test func seamsSitInTheGapsAndConvertPointsToWeights() {
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    #expect(layout.seams.count == 1)
    let seam = layout.seams[0]
    #expect(seam.leading == leafA && seam.trailing == tree.desktop)
    #expect(seam.frame.minX == layout.windowFrames[a]!.maxX)
    #expect(seam.frame.width == 12)
    #expect(abs(seam.pointsPerWeight - (content.width - 12) / 2) < 0.001)
  }

  @Test func inactiveTabsAreHidden() {
    var tree = LayoutTree()
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    tree.addToStack(b, leaf: leaf)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    #expect(layout.windowFrames[b] != nil)
    #expect(layout.hiddenWindows == [a])
  }

  @Test func asciiRendererLabelsEverything() {
    let (tree, _, _, _) = threeWindowTree()
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    let drawing = AsciiRenderer.render(layout, tree: tree, columns: 60, rows: 16)
    #expect(drawing.contains("w1"))
    #expect(drawing.contains("w2"))
    #expect(drawing.contains("w3"))
    #expect(drawing.contains("desktop"))
  }

  @Test func asciiRendererSurvivesFramesThatAreNotOnTheScreen() {
    let (tree, _, _, _) = threeWindowTree()
    var layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: everyone)
    let windows = layout.windowFrames.keys.sorted()
    layout.windowFrames[windows[0]] = CGRect(x: CGFloat.infinity, y: .infinity, width: 0, height: 0)
    layout.windowFrames[windows[1]] = CGRect(x: 1e300, y: -1e300, width: 1e300, height: 1e300)
    layout.windowFrames[windows[2]] = CGRect(x: CGFloat.nan, y: .nan, width: .nan, height: .nan)
    let drawing = AsciiRenderer.render(layout, tree: tree, columns: 60, rows: 16)
    #expect(drawing.split(separator: "\n").count == 17)
  }

  func rectangles(of layout: Layout) -> [CGRect] {
    Array(layout.nodeFrames.values) + Array(layout.windowFrames.values) + layout.tiles.map(\.frame)
      + layout.tiles.flatMap(\.miniature.values) + layout.seams.map(\.frame) + [layout.desktopFrame].compactMap { $0 }
  }

  func isSound(_ rect: CGRect, in screen: CGRect) -> Bool {
    // By coordinates: whether a rectangle "contains" one without area is not worth relying on.
    [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width >= 0 && rect.height >= 0
      && rect.minX >= screen.minX - 1 && rect.maxX <= screen.maxX + 1 && rect.minY >= screen.minY - 1
      && rect.maxY <= screen.maxY + 1
  }

  /// `gap` can be any number in settings.json. From half the screen's short side up, it used to put
  /// every frame at infinity: a slip of the finger (500 for 50) is enough.
  @Test(arguments: [
    400, 437, 438, 500, 5000, 1e300, CGFloat.greatestFiniteMagnitude, CGFloat.infinity, 0, -5, -1e300, -CGFloat.infinity,
    CGFloat.nan,
  ]) func noGapPutsAFrameOffTheScreen(gap: CGFloat) throws {
    let (tree, _, _, _) = threeWindowTree()
    for camera in tree.preorder() {
      let layout = LayoutEngine.layout(
        tree, camera: camera, in: screen, options: LayoutOptions(gap: gap), isPresent: everyone)
      for rect in rectangles(of: layout) { #expect(isSound(rect, in: screen), "\(rect) with the camera on \(camera)") }
      for seam in layout.seams { #expect(seam.pointsPerWeight.isFinite) }
      _ = try JSONEncoder().encode(layout.tiles)  // throws on a number that is not finite
      #expect(!AsciiRenderer.render(layout, tree: tree).isEmpty)
    }
  }

  @Test func aSensibleGapIsUntouched() {
    let (tree, _, _, _) = threeWindowTree()
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: LayoutOptions(gap: 40), isPresent: everyone)
    #expect(layout.nodeFrames[tree.root] == screen.insetBy(dx: 40, dy: 40))
    #expect(layout.seams.allSatisfy { min($0.frame.width, $0.frame.height) == 40 })
  }

  /// A group's miniature is laid out inside its tile with gaps of its own, which a sliver cannot hold.
  @Test func theMiniatureOfASliverOfATileIsStillSound() throws {
    var tree = LayoutTree()
    let top = tree.dock(WindowID(1), beside: tree.desktop, edge: .left)
    tree.dock(WindowID(2), beside: top, edge: .bottom)
    let narrow = CGRect(x: 0, y: 0, width: 14, height: 400)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: narrow, options: LayoutOptions(gap: 2), isPresent: everyone)
    let tile = try #require(layout.tiles.first { $0.kind == .group })
    #expect(tile.frame.width == 4 && tile.miniature.count == 2)
    for rect in rectangles(of: layout) { #expect(isSound(rect, in: narrow), "\(rect)") }
    _ = try JSONEncoder().encode(layout.tiles)
  }
}
