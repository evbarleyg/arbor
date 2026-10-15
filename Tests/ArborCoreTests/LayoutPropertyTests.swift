import ArborCore
import CoreGraphics
import Foundation
import Testing

private func everyone(_: WindowID) -> Bool { true }

extension CGRect {
  fileprivate var isFinite: Bool {
    origin.x.isFinite && origin.y.isFinite && size.width.isFinite && size.height.isFinite
  }
  fileprivate func start(along axis: Axis) -> CGFloat { axis == .horizontal ? minX : minY }
  fileprivate func end(along axis: Axis) -> CGFloat { axis == .horizontal ? maxX : maxY }
}

/// What must hold for every layout, whatever the tree, the display and the options.
private func expectSound(
  _ layout: Layout, of tree: LayoutTree, isPresent: @escaping (WindowID) -> Bool = everyone, gap: CGFloat,
  _ comment: Comment? = nil, at location: SourceLocation = #_sourceLocation
) {
  let view = TreeView(tree: tree, isPresent: isPresent)
  var problems: [String] = []
  for (node, frame) in layout.nodeFrames {
    if !frame.isFinite { problems.append("\(node) has frame \(frame)") }
    if frame.size.width < 0 || frame.size.height < 0 { problems.append("\(node) has a negative size \(frame)") }
    if frame != frame.integralRounded { problems.append("\(node) is not on whole points: \(frame)") }
    if frame.isFinite, !layout.frame.contains(frame), !frame.isEmpty || !layout.frame.insetBy(dx: -0.5, dy: -0.5).contains(frame.origin) {
      problems.append("\(node) at \(frame) leaves the display \(layout.frame)")
    }
  }
  let tiled = Set(layout.tiles.map(\.node))
  for (node, frame) in layout.nodeFrames where !tiled.contains(node) {
    guard case .split(let axis, _) = tree[node]?.kind else { continue }
    let children = view.effectiveChildren(of: node)
    let frames = children.compactMap { layout.nodeFrames[$0] }
    guard frames.count == children.count else {
      problems.append("\(node) has children that were not laid out")
      continue
    }
    if children.count == 1 {
      if frames[0] != frame { problems.append("\(node)'s only child does not fill it") }
      continue
    }
    // The children and the gaps between them tile the parent exactly.
    let cross = axis.perpendicular
    if frames.first!.start(along: axis) != frame.start(along: axis) { problems.append("\(node): first child starts late") }
    if frames.last!.end(along: axis) != frame.end(along: axis) { problems.append("\(node): last child ends at \(frames.last!) in \(frame)") }
    for child in frames where child.start(along: cross) != frame.start(along: cross) || child.end(along: cross) != frame.end(along: cross) {
      problems.append("\(node): a child does not span it: \(child) in \(frame)")
    }
    let gaps = zip(frames, frames.dropFirst()).map { $1.start(along: axis) - $0.end(along: axis) }
    let roomy = frame.length(along: axis) >= 2 * gap * CGFloat(children.count - 1)
    if roomy, gaps.contains(where: { $0 != gap }) { problems.append("\(node): gaps \(Set(gaps)) are not \(gap)") }
    if gaps.contains(where: { $0 < 0 || $0 > gap }) { problems.append("\(node): children overlap or drift apart: \(Set(gaps))") }
    if Set(gaps).count > 1 { problems.append("\(node): uneven gaps \(Set(gaps))") }
  }
  // What is drawn never overlaps.
  var drawn = layout.windowFrames.values.map { $0 } + layout.tiles.map(\.frame)
  if let desktop = layout.desktopFrame { drawn.append(desktop) }
  for (index, one) in drawn.enumerated() {
    for other in drawn[(index + 1)...] where one.overlaps(other) { problems.append("\(one) overlaps \(other)") }
  }
  for tile in layout.tiles {
    for (window, frame) in tile.miniature where !frame.isFinite || !(tile.frame.contains(frame) || frame.isEmpty) {
      problems.append("miniature of \(window) at \(frame) leaves its tile \(tile.frame)")
    }
  }
  for seam in layout.seams where !seam.frame.isFinite || !seam.pointsPerWeight.isFinite || seam.pointsPerWeight < 0 {
    problems.append("seam \(seam)")
  }
  // Every present window is accounted for exactly once.
  let present = Set(tree.allWindows.filter(isPresent))
  if Set(layout.windowFrames.keys).union(layout.hiddenWindows) != present { problems.append("windows were lost or invented") }
  if !layout.hiddenWindows.isDisjoint(with: layout.windowFrames.keys) { problems.append("a window is both shown and hidden") }
  #expect(problems.prefix(6) == [], comment, sourceLocation: location)
  #expect(throws: Never.self, comment, sourceLocation: location) { try JSONEncoder().encode(layout.tiles) }
}

@Suite struct LayoutPropertyTests {
  static let displays: [CGRect] = [
    CGRect(x: 0, y: 25, width: 1440, height: 875),
    CGRect(x: -1920, y: -300, width: 1920, height: 1080),
    CGRect(x: -731, y: -413, width: 1441, height: 877),  // straddles both axes
    CGRect(x: 1440, y: 0, width: 5120, height: 2160),
    CGRect(x: 0.5, y: 24.5, width: 1439.5, height: 875.25),
    CGRect(x: -100.25, y: -50.75, width: 801.5, height: 601.5),
    CGRect(x: 0, y: 0, width: 320, height: 200),
    CGRect(x: 0, y: 0, width: 30, height: 20),
    CGRect(x: 10, y: 10, width: 1, height: 1),
    CGRect(x: 10, y: 10, width: 0, height: 0),
  ]

  @Test(arguments: Array<UInt64>(1...40)) func randomTreesTileEveryDisplayExactly(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    let tree = LayoutTree.random(seed: seed, windows: Int.random(in: 1...30, using: &random))
    let absent = Set(tree.allWindows.filter { _ in Int.random(in: 0..<5, using: &random) == 0 })
    let nodes = tree.preorder()
    for display in Self.displays {
      for gap in [12, 0, 1, 40] as [CGFloat] {
        for minimum in [CGSize(width: 240, height: 160), .zero] {
          let camera = nodes.randomElement(using: &random)!
          let layout = LayoutEngine.layout(
            tree, camera: camera, in: display, options: LayoutOptions(gap: gap, minimumUsableSize: minimum),
            isPresent: { !absent.contains($0) })
          expectSound(
            layout, of: tree, isPresent: { !absent.contains($0) }, gap: gap,
            "seed \(seed), display \(display), gap \(gap), camera \(camera)")
        }
      }
    }
  }

  /// F62: splits inside a parent on their own axis, and splits with one child.
  @Test(arguments: Array<UInt64>(1...20)) func treesWithKeptGroupsTileEveryDisplayToo(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var tree = LayoutTree.random(seed: seed, windows: 24)
    for split in tree.preorder().filter(tree.isSplit) where Bool.random(using: &random) {
      tree.keep(split, for: [Keeps.view, .name, .guest].randomElement(using: &random)!)
    }
    for window in tree.allWindows.shuffled(using: &random).prefix(14) { tree.remove(window) }
    #expect(tree.invariantViolations() == [])
    let odd = tree.preorder().filter { id in
      guard case .split(let axis, let children) = tree[id]?.kind else { return false }
      if children.count == 1 { return true }
      if let parent = tree.parent(of: id), case .split(axis, _) = tree[parent]?.kind { return true }
      return false
    }
    for display in Self.displays {
      for camera in [tree.root] + odd {
        for minimum in [CGSize(width: 240, height: 160), .zero] {
          let layout = LayoutEngine.layout(
            tree, camera: camera, in: display, options: LayoutOptions(minimumUsableSize: minimum), isPresent: everyone)
          expectSound(layout, of: tree, gap: 12, "seed \(seed), display \(display), camera \(camera)")
        }
      }
    }
  }

  /// With 150 windows in a row the gaps alone are wider than the display. They used to be kept at
  /// full width, which laid the last windows out 372 points beyond its right edge.
  @Test(arguments: [2, 3, 10, 100, 119, 120, 150, 400]) func aRowOfManyWindowsStaysOnTheDisplay(count: Int) {
    var tree = LayoutTree()
    for id in 1...count { tree.dock(WindowID(UInt32(id)), beside: tree.root, edge: .left) }
    for display in Self.displays {
      for minimum in [CGSize(width: 240, height: 160), .zero] {
        let layout = LayoutEngine.layout(
          tree, camera: tree.root, in: display, options: LayoutOptions(minimumUsableSize: minimum), isPresent: everyone)
        expectSound(layout, of: tree, gap: 12, "\(count) windows on \(display)")
      }
    }
  }

  /// `gap` comes from settings.json. An outer gap of more than half the display made `insetBy`
  /// return the null rectangle, whose origin is infinite, and every frame came out infinite or NaN.
  @Test(arguments: [438, 720, 1_000, 1e9, 1e308, CGFloat.infinity, -.infinity, -12, .nan] as [CGFloat])
  func anyGapGivesFiniteFramesOnTheDisplay(gap: CGFloat) {
    let tree = LayoutTree.random(seed: 3, windows: 6)
    let display = Self.displays[0]
    for minimum in [CGSize(width: 240, height: 160), .zero] {
      let layout = LayoutEngine.layout(
        tree, camera: tree.root, in: display, options: LayoutOptions(gap: gap, minimumUsableSize: minimum),
        isPresent: everyone)
      for frame in layout.nodeFrames.values {
        #expect(frame.isFinite && (display.contains(frame) || frame.isEmpty), "\(frame)")
      }
      #expect(layout.nodeFrames[tree.root] == LayoutEngine.content(of: display, options: LayoutOptions(gap: gap)))
    }
  }

  @Test func aGapThatIsNotAWholeNumberIsRounded() {
    var tree = LayoutTree()
    for id in 1...4 { tree.dock(WindowID(UInt32(id)), beside: tree.root, edge: .left) }
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: Self.displays[0], options: LayoutOptions(gap: 7.5), isPresent: everyone)
    expectSound(layout, of: tree, gap: 8)
  }

  /// A group tile narrower than its miniature's margins: the miniature's frames were infinite and
  /// NaN, which `state` could not encode and which AppKit refuses as a layer's frame.
  @Test func theMiniatureOfASliverOfAGroupIsFinite() throws {
    var tree = LayoutTree()
    let first = tree.dock(WindowID(1), beside: tree.root, edge: .left)
    tree.dock(WindowID(2), beside: first, edge: .bottom)
    let column = tree.parent(of: first)!
    for id in 10..<19 { tree.dock(WindowID(UInt32(id)), beside: column, edge: .right) }
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: Self.displays[0], isPresent: everyone)
    let tile = try #require(layout.tiles.first { $0.node == column })
    #expect(tile.frame.width < 6)
    #expect(tile.miniature.count == 2)
    expectSound(layout, of: tree, gap: 12)
  }

  @Test(arguments: [
    CGRect.null, .infinite, CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
    CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100), CGRect(x: 0, y: 0, width: 100, height: CGFloat.nan),
    CGRect(x: CGFloat.infinity, y: 0, width: 100, height: 100), CGRect(x: 1e300, y: 0, width: 1e300, height: 100),
    CGRect(x: 100, y: 100, width: -50, height: -50),
  ])
  func aDisplayFrameThatMakesNoSenseStillGivesFiniteFrames(display: CGRect) {
    let tree = LayoutTree.random(seed: 5, windows: 5)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: display, isPresent: everyone)
    for frame in layout.nodeFrames.values { #expect(frame.isFinite, "\(frame)") }
    for tile in layout.tiles { for frame in tile.miniature.values { #expect(frame.isFinite) } }
    #expect(Set(layout.windowFrames.keys).union(layout.hiddenWindows) == Set(tree.allWindows))
    _ = AsciiRenderer.render(layout, tree: tree)
  }

  /// The same arrangement looks the same wherever its display is: moving the display by whole
  /// points moves every frame by as much. Rounding away from zero broke this across x = 0 or
  /// y = 0, where a 12-point gap came out as 13.
  @Test func aLayoutDoesNotDependOnWhereItsDisplayIs() {
    let tree = LayoutTree.random(seed: 11, windows: 9)
    let size = CGSize(width: 1441, height: 877)
    let home = LayoutEngine.layout(tree, camera: tree.root, in: CGRect(origin: .zero, size: size), isPresent: everyone)
    for x in stride(from: -1500 as CGFloat, through: 60, by: 13) {
      let offset = CGPoint(x: x, y: (x / 2).rounded())
      let moved = LayoutEngine.layout(tree, camera: tree.root, in: CGRect(origin: offset, size: size), isPresent: everyone)
      for (node, frame) in home.nodeFrames {
        #expect(moved.nodeFrames[node] == frame.offsetBy(dx: offset.x, dy: offset.y), "display at \(offset)")
      }
    }
  }

  /// Sizes follow weights to within a point. Three places: with a column for the Desktop.
  @Test func sharesAreProportionalToWeights() {
    var tree = LayoutTree()
    let one = tree.dock(WindowID(1), beside: tree.root, edge: .left, desktopColumn: true)
    let two = tree.dock(WindowID(2), beside: tree.root, edge: .right, desktopColumn: true)
    tree.moveBoundary(leading: one, trailing: tree.desktop, by: 211, pointsPerWeight: 464)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: Self.displays[0], isPresent: everyone)
    let available: CGFloat = 1440 - 24 - 24
    let total = [one, tree.desktop, two].reduce(0) { $0 + tree[$1]!.weight }
    for node in [one, tree.desktop, two] {
      #expect(abs(layout.nodeFrames[node]!.width - available * CGFloat(tree[node]!.weight / total)) <= 1)
    }
    #expect(abs(layout.seams[0].pointsPerWeight - available / CGFloat(total)) < 1e-9)
  }

  /// Dragging a seam by what the layout says moves the boundary by that many points.
  @Test func movingABoundaryByPointsMovesItByThosePoints() {
    var tree = LayoutTree.grid(of: (1...6).map { WindowID($0) })
    let before = LayoutEngine.layout(tree, camera: tree.root, in: Self.displays[0], isPresent: everyone)
    let seam = before.seams.first { $0.axis == .horizontal }!
    tree.moveBoundary(leading: seam.leading, trailing: seam.trailing, by: 57, pointsPerWeight: Double(seam.pointsPerWeight))
    let after = LayoutEngine.layout(tree, camera: tree.root, in: Self.displays[0], isPresent: everyone)
    #expect(abs(after.nodeFrames[seam.leading]!.maxX - before.nodeFrames[seam.leading]!.maxX - 57) <= 1)
    // T05: nothing else moves.
    for (node, frame) in before.nodeFrames
    where !tree.subtree(seam.leading, contains: node) && !tree.subtree(seam.trailing, contains: node) {
      #expect(after.nodeFrames[node] == frame)
    }
  }

  /// A split showing one child looks like that child, so it is treated like it: as the camera it is never a tile.
  @Test func theOnlyVisibleChildOfTheCameraIsNotATile() {
    var tree = LayoutTree()
    let top = tree.dock(WindowID(1), beside: tree.root, edge: .left)
    tree.dock(WindowID(2), beside: top, edge: .bottom)
    let column = tree.parent(of: top)!
    let huge: (WindowID) -> CGSize? = { _ in CGSize(width: 3_000, height: 2_000) }
    let onLeaf = LayoutEngine.layout(
      tree, camera: top, in: Self.displays[0], isPresent: { $0 == WindowID(1) }, minimumSize: huge)
    let onColumn = LayoutEngine.layout(
      tree, camera: column, in: Self.displays[0], isPresent: { $0 == WindowID(1) }, minimumSize: huge)
    #expect(onLeaf.tiles.isEmpty)
    #expect(onColumn.tiles.isEmpty)
    #expect(onColumn.windowFrames == onLeaf.windowFrames)
  }
}
