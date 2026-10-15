import ArborCore
import CoreGraphics
import Testing

private let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let content = visible.insetBy(dx: 12, dy: 12)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)

/// Small enough that nothing in the fixture is a tile unless a test asks for it.
private let roomy = LayoutOptions(minimumUsableSize: CGSize(width: 120, height: 120))

private func everyone(_: WindowID) -> Bool { true }

/// root(h)[ column(v)[a, row(h)[c, d]], desktop, b ]: three levels below the root. As it ships b took all that was left: two halves
/// and a Desktop without room. With `desktopColumn` thirds, for the tests that look for the Desktop on the plane or need a third.
private struct Fixture {
  var tree = LayoutTree()
  let leafA: NodeID
  let leafB: NodeID
  let leafC: NodeID
  let leafD: NodeID
  var column: NodeID { tree.parent(of: leafA)! }
  var row: NodeID { tree.parent(of: leafC)! }

  init(desktopColumn: Bool = false) {
    leafA = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    leafB = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    leafC = tree.dock(c, beside: leafA, edge: .bottom)
    leafD = tree.dock(d, beside: leafC, edge: .right)
  }

  func layout(camera: NodeID, options: LayoutOptions = roomy) -> Layout {
    LayoutEngine.layout(tree, camera: camera, in: visible, options: options, isPresent: everyone)
  }

  func plane(camera: NodeID, ancestor: NodeID, options: LayoutOptions = roomy) -> Plane {
    Plane(tree: tree, camera: camera, ancestor: ancestor, in: visible, options: options, isPresent: everyone)
  }
}

@Suite struct PlaneMapTests {
  @Test func carriesOneRectangleOntoAnother() throws {
    let source = CGRect(x: 10, y: 20, width: 100, height: 50)
    let target = CGRect(x: -30, y: 5, width: 300, height: 25)
    let map = try #require(PlaneMap(carrying: source, onto: target))
    #expect(map.apply(source) == target)
    #expect(map.scaleX == 3 && map.scaleY == 0.5, "x and y are scaled independently")
    // Whatever is beside the source stays beside it, three times as far away and three times as wide.
    #expect(
      map.apply(CGRect(x: 120, y: 20, width: 40, height: 50)) == CGRect(x: 300, y: 5, width: 120, height: 25))
    #expect(map.apply(CGPoint(x: 60, y: 45)) == target.center)
    #expect(PlaneMap.identity.apply(source) == source)
  }

  @Test func nothingIsStretchedFromASliverOrFromNonsense() {
    let target = CGRect(x: 0, y: 0, width: 100, height: 100)
    #expect(PlaneMap(carrying: CGRect(x: 0, y: 0, width: 0, height: 100), onto: target) == nil)
    #expect(PlaneMap(carrying: CGRect(x: 0, y: 0, width: 100, height: 0.5), onto: target) == nil)
    #expect(PlaneMap(carrying: .null, onto: target) == nil)
    #expect(PlaneMap(carrying: CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10), onto: target) == nil)
    #expect(PlaneMap(carrying: target, onto: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10)) == nil)
  }
}

@Suite struct PlaneTests {
  @Test func withTheCameraOnTheAncestorThePlaneIsTheLayout() {
    let f = Fixture()
    let layout = f.layout(camera: f.tree.root)
    let plane = f.plane(camera: f.tree.root, ancestor: f.tree.root)
    #expect(plane.nodes == layout.nodeFrames)
    #expect(plane.windows.mapValues(\.frame) == layout.windowFrames)
    #expect(plane.windows.values.allSatisfy { $0.visibility == .inView && $0.look == .picture })
    #expect(plane.content == content)
  }

  @Test func zoomedOnALeafTheRestLiesWhereTheSameZoomPutsIt() throws {
    let f = Fixture(desktopColumn: true)
    let base = f.layout(camera: f.tree.root)
    let plane = f.plane(camera: f.leafA, ancestor: f.tree.root)
    let map = try #require(PlaneMap(carrying: base.windowFrames[a]!, onto: content))

    #expect(plane.windows[a] == Plane.Spot(frame: content, look: .picture, visibility: .inView))
    for window in [b, c, d] {
      let spot = try #require(plane.windows[window])
      #expect(spot.frame == map.apply(base.windowFrames[window]!).integralRounded, "\(window)")
      #expect(spot.visibility == .outside)
      #expect(!spot.frame.overlaps(visible), "\(window) is beyond the edges of the view")
    }
    // b is in the same row of the plane, further right; c and d are below.
    #expect(plane.windows[b]!.frame.minX > visible.maxX && plane.windows[b]!.frame.minY == content.minY)
    #expect(plane.windows[c]!.frame.minY > visible.maxY && plane.windows[c]!.frame.minX == content.minX)
    #expect(plane.windows[d]!.frame.maxX == content.maxX)
    // a is about a third of the width and half of the height, so x stretches more than y.
    #expect(abs(plane.windows[b]!.frame.width - content.width) <= 1)
    #expect(abs(plane.windows[b]!.frame.height - base.windowFrames[b]!.height * map.scaleY) <= 1)
    #expect(map.scaleX > 3 && map.scaleY < 2.1)
  }

  @Test func nodesAreOnThePlaneToo() throws {
    let f = Fixture(desktopColumn: true)
    let base = f.layout(camera: f.tree.root)
    let plane = f.plane(camera: f.leafA, ancestor: f.tree.root)
    let map = try #require(PlaneMap(carrying: base.nodeFrames[f.leafA]!, onto: content))
    #expect(plane.nodes[f.leafA] == content)
    #expect(plane.nodes[f.tree.desktop] == map.apply(base.desktopFrame!).integralRounded)
    #expect(plane.nodes[f.row] == map.apply(base.nodeFrames[f.row]!).integralRounded)
    // The nodes around the camera's hold the screen.
    #expect(plane.nodes[f.column]!.contains(content))
    #expect(plane.nodes[f.tree.root]!.contains(plane.nodes[f.column]!))
    #expect(Set(plane.nodes.keys) == Set(f.tree.preorder()))
  }

  @Test func insideTheCameraTheRealLayoutWinsBecauseGapsDoNotScale() {
    let f = Fixture()
    let plane = f.plane(camera: f.column, ancestor: f.tree.root)
    let real = f.layout(camera: f.column)
    for window in [a, c, d] {
      #expect(plane.windows[window] == Plane.Spot(frame: real.windowFrames[window]!, look: .picture, visibility: .inView))
    }
    #expect(plane.windows[d]!.frame.minX - plane.windows[c]!.frame.maxX == 12)
    #expect(plane.nodes[f.row] == real.nodeFrames[f.row])
    #expect(plane.windows[b]!.visibility == .outside)
    #expect(plane.windows[b]!.frame.minX >= visible.maxX)
  }

  @Test func aNearerAncestorHoldsLessOfTheTree() {
    let f = Fixture(desktopColumn: true)
    // From c, three levels down, with the row as the ancestor: only d is on the plane with it.
    let near = f.plane(camera: f.leafC, ancestor: f.row)
    #expect(Set(near.windows.keys) == [c, d])
    #expect(near.windows[d]!.frame.minX >= visible.maxX)
    #expect(near.windows[d]!.frame.minY == content.minY && near.windows[d]!.frame.height == content.height)
    #expect(near.nodes[f.tree.desktop] == nil)

    let far = f.plane(camera: f.leafC, ancestor: f.tree.root)
    #expect(Set(far.windows.keys) == [a, b, c, d])
    #expect(far.windows[a]!.frame.maxY <= visible.minY, "a is above c")
    #expect(far.windows[b]!.frame.minX > far.windows[d]!.frame.maxX, "b is beyond d and the Desktop")
    #expect(far.windows[c]!.frame == content)
  }

  @Test func anAncestorThatDoesNotHoldTheCameraIsWidened() {
    let f = Fixture()
    let plane = f.plane(camera: f.leafB, ancestor: f.row)
    #expect(plane.ancestor == f.tree.root)
    #expect(f.plane(camera: f.leafB, ancestor: NodeID(999)).ancestor == f.tree.root)
    #expect(plane.windows[c] != nil)
  }

  @Test func absentWindowsTakeNoSpaceOnThePlane() {
    let f = Fixture()
    let plane = Plane(
      tree: f.tree, camera: f.leafA, ancestor: f.tree.root, in: visible, options: roomy,
      isPresent: { $0 != c && $0 != d })
    // Without c and d, a has the whole column, so nothing is above or below it.
    #expect(plane.windows[c] == nil && plane.windows[d] == nil)
    #expect(plane.nodes[f.row] == nil)
    #expect(plane.windows[b]!.frame.height == content.height)
  }

  @Test func aCameraWithNothingPresentFallsBackLikeTheLayout() {
    let f = Fixture()
    let plane = Plane(tree: f.tree, camera: f.leafA, ancestor: f.leafA, in: visible, isPresent: { $0 != a })
    #expect(plane.camera == f.column)
    #expect(plane.ancestor == f.column)
    #expect(plane.windows[a] == nil)
  }

  @Test func windowsInTilesAreCoversWhereTheTileDrawsThem() throws {
    let f = Fixture()
    // Columns are 702 wide: with a minimum of 750 the column is a group's tile and b a window's.
    let options = LayoutOptions(minimumUsableSize: CGSize(width: 750, height: 300))
    let layout = f.layout(camera: f.tree.root, options: options)
    let plane = f.plane(camera: f.tree.root, ancestor: f.tree.root, options: options)
    let group = try #require(layout.tiles.first { $0.node == f.column })
    for window in [a, c, d] {
      #expect(plane.windows[window] == Plane.Spot(frame: group.miniature[window]!, look: .cover, visibility: .inView))
    }
    let single = try #require(layout.tiles.first { $0.node == f.leafB })
    #expect(plane.windows[b] == Plane.Spot(frame: single.frame, look: .cover, visibility: .inView))
    #expect(plane.nodes[f.column] == group.frame)
    #expect(plane.nodes[f.leafA] == nil, "the layout does not place the nodes inside a tile")
  }

  @Test func beyondTheCameraNothingIsATile() {
    let f = Fixture()
    // Seen from the root the row is too low to use; seen from a it is as large as a is.
    let options = LayoutOptions(minimumUsableSize: CGSize(width: 240, height: 430))
    #expect(f.layout(camera: f.tree.root, options: options).tiles.contains { $0.node == f.row })
    let plane = f.plane(camera: f.leafA, ancestor: f.tree.root, options: options)
    #expect(plane.windows[c]?.look == .picture)
    #expect(plane.windows[c]?.visibility == .outside)
  }

  @Test func aWindowThatRefusedItsSlotIsACover() {
    let f = Fixture()
    let plane = Plane(
      tree: f.tree, camera: f.tree.root, ancestor: f.tree.root, in: visible, options: roomy, isPresent: everyone,
      minimumSize: { $0 == b ? CGSize(width: 900, height: 600) : nil })
    #expect(plane.windows[b]?.look == .cover)
    #expect(plane.windows[b]?.frame == f.layout(camera: f.tree.root).windowFrames[b])
    #expect(plane.windows[a]?.look == .picture)
  }

  @Test func inactiveTabsAreBehindTheActiveOne() {
    var f = Fixture()
    let e = WindowID(5)
    f.tree.addToStack(e, leaf: f.leafB)  // e is now the active tab
    let inView = f.plane(camera: f.tree.root, ancestor: f.tree.root)
    #expect(inView.windows[e]?.visibility == .inView)
    #expect(inView.windows[b] == Plane.Spot(frame: inView.windows[e]!.frame, look: .picture, visibility: .behind))

    let away = f.plane(camera: f.leafA, ancestor: f.tree.root)
    #expect(away.windows[e]?.visibility == .outside)
    #expect(away.windows[b]?.visibility == .behind)
    #expect(away.windows[b]?.frame == away.windows[e]?.frame)

    // With the active tab minimized the other one shows.
    let without = Plane(tree: f.tree, camera: f.tree.root, ancestor: f.tree.root, in: visible, isPresent: { $0 != e })
    #expect(without.windows[b]?.visibility == .inView)
    #expect(without.windows[e] == nil)
  }

  @Test func howeverCrowdedTheScreenEveryFrameIsFinite() {
    // So many columns that the gaps use up the width. If that leaves the camera's slot too thin to
    // stretch from, the rest is left off the plane rather than blown up beyond reason.
    var tree = LayoutTree()
    var first: NodeID?
    for number in 1...200 {
      let leaf = tree.dock(WindowID(UInt32(number)), beside: tree.root, edge: .left)
      if first == nil { first = leaf }
    }
    let plane = Plane(tree: tree, camera: first!, ancestor: tree.root, in: visible, isPresent: everyone)
    #expect(plane.windows[WindowID(1)]?.frame == content)
    #expect(plane.nodes.values.allSatisfy { $0.isFinite })
    #expect(plane.windows.values.allSatisfy { $0.frame.isFinite })
  }

  /// A gap of 500 for 50 is a slip of the finger. The engine then takes a quarter of the shorter side; a plane that
  /// worked the rectangle out for itself got the null rectangle, and everything out of view went missing.
  @Test func theContentIsTheRectangleTheCameraFillsHoweverLargeTheGap() throws {
    let f = Fixture()
    for outerGap: CGFloat in [0, 12, 437, 500, 5000] {
      var options = roomy
      options.outerGap = outerGap
      let plane = f.plane(camera: f.leafA, ancestor: f.tree.root, options: options)
      #expect(plane.content == f.layout(camera: f.leafA, options: options).nodeFrames[f.leafA], "outer gap \(outerGap)")
      let beside = try #require(plane.windows[b], "outer gap \(outerGap)")
      #expect(beside.frame.isFinite && beside.frame.minX >= plane.content.maxX, "outer gap \(outerGap)")
    }
  }
}
