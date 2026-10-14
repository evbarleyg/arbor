import ArborCore
import CoreGraphics
import Testing

/// The minimap's geometry and the panel's model (docs/features/F26-minimap.md).
@Suite struct MinimapTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let c = WindowID(3)
  let laptop = CGSize(width: 1440, height: 875)

  /// [a / c | Desktop | b]
  func makeTree() -> LayoutTree {
    var tree = LayoutTree()
    let left = tree.dock(a, beside: tree.desktop, edge: .left)
    tree.dock(b, beside: tree.desktop, edge: .right)
    tree.dock(c, beside: left, edge: .bottom)
    return tree
  }

  func make(_ tree: LayoutTree, camera: NodeID, area: CGSize? = nil, absent: Set<WindowID> = []) -> Minimap? {
    Minimap.make(tree, camera: camera, area: area ?? laptop, isPresent: { !absent.contains($0) })
  }

  func frame(_ window: WindowID, in map: Minimap) -> CGRect? { map.places.first { $0.window == window }?.frame }

  // MARK: The geometry

  @Test func theMapHasTheDisplaysProportionsAndFitsTheBox() throws {
    let tree = makeTree()
    for (area, expected) in [
      (CGSize(width: 1440, height: 875), CGSize(width: 220, height: 134)),
      (CGSize(width: 2560, height: 1440), CGSize(width: 220, height: 124)),
      (CGSize(width: 1024, height: 674), CGSize(width: 213, height: 140)),
      (CGSize(width: 1080, height: 1920), CGSize(width: 79, height: 140)),
      (CGSize(width: 5120, height: 1440), CGSize(width: 220, height: 62)),
      // Nobody has such a display. The map still has a size.
      (CGSize(width: 100_000, height: 1), CGSize(width: 220, height: 1)),
      (CGSize(width: 1, height: 100_000), CGSize(width: 1, height: 140)),
    ] {
      let map = try #require(make(tree, camera: tree.root, area: area))
      #expect(map.size == expected, "\(area)")
      #expect(map.size.width <= Minimap.maximumSize.width && map.size.height <= Minimap.maximumSize.height)
    }
  }

  @Test func everythingIsWhereShowEverythingWouldPutIt() throws {
    let tree = makeTree()
    let map = try #require(make(tree, camera: tree.root))
    let bounds = CGRect(origin: .zero, size: map.size)
    let ra = try #require(frame(a, in: map))
    let rb = try #require(frame(b, in: map))
    let rc = try #require(frame(c, in: map))
    let desktop = try #require(map.desktop)
    for rect in [ra, rb, rc, desktop] {
      #expect(bounds.contains(rect))
      #expect(rect.width >= 10 && rect.height >= 10)
    }
    #expect(ra.minX == 0 && ra.minY == 0, "the map goes to its own edges; the panel adds the padding")
    #expect(rc.minY > ra.maxY && rc.minX == ra.minX && rc.maxY == map.size.height)
    #expect(desktop.minX > ra.maxX && desktop.maxX < rb.minX)
    #expect(rb.maxX == map.size.width && rb.height == map.size.height)
    #expect(map.places.map(\.window) == [a, c, b], "in tree order")

    // The same proportions as the real thing, within the rounding of so small a picture.
    let real = LayoutEngine.layout(
      tree, camera: tree.root, in: CGRect(origin: .zero, size: laptop),
      options: LayoutOptions(gap: 12, outerGap: 0, minimumUsableSize: .zero), isPresent: { _ in true })
    let scale = map.size.width / laptop.width
    for window in [a, b, c] {
      let expected = try #require(real.windowFrames[window])
      let drawn = try #require(frame(window, in: map))
      #expect(abs(drawn.midX - expected.midX * scale) <= 2)
      #expect(abs(drawn.midY - expected.midY * scale) <= 2)
    }
  }

  @Test func theHighlightIsTheSpaceInView() throws {
    let tree = makeTree()
    let whole = try #require(make(tree, camera: tree.root))
    #expect(whole.highlight == CGRect(origin: .zero, size: whole.size))
    #expect(whole.places.map(\.isInView) == [true, true, true] && whole.desktopIsInView)

    let onA = try #require(make(tree, camera: tree.leaf(containing: a)!))
    #expect(onA.highlight == frame(a, in: onA))
    #expect(onA.places.map(\.frame) == whole.places.map(\.frame), "the map stays put; only the highlight moves")
    #expect(onA.places.filter(\.isInView).map(\.window) == [a])
    #expect(!onA.desktopIsInView)

    let column = tree.parent(of: tree.leaf(containing: a)!)!
    let onColumn = try #require(make(tree, camera: column))
    #expect(onColumn.highlight == frame(a, in: onColumn)!.union(frame(c, in: onColumn)!))
    #expect(onColumn.places.filter(\.isInView).map(\.window) == [a, c])

    let onDesktop = try #require(make(tree, camera: tree.desktop))
    #expect(onDesktop.highlight == onDesktop.desktop)
    #expect(onDesktop.desktopIsInView && onDesktop.places.map(\.isInView) == [false, false, false])
  }

  @Test func everyPlaceNamesTheSpaceThatFramesIt() throws {
    let tree = makeTree()
    let map = try #require(make(tree, camera: tree.root))
    for place in map.places { #expect(place.space == tree.leaf(containing: place.window)) }
    #expect(map.desktopSpace == tree.desktop)
    #expect(map.view == tree.root)
  }

  @Test func windowsThatTakeNoSpaceAreNotOnTheMap() throws {
    let tree = makeTree()
    let map = try #require(make(tree, camera: tree.root, absent: [c]))
    #expect(map.places.map(\.window) == [a, b])
    #expect(frame(a, in: map)?.height == map.size.height, "its neighbour has the column to itself, as on screen")
  }

  @Test func aViewOfASpaceWithNothingToShowIsMarkedWhereTheDisplayReallyIs() throws {
    let tree = makeTree()
    // The camera is on c, which is minimized: the display shows the column around it, which is a alone.
    let map = try #require(make(tree, camera: tree.leaf(containing: c)!, absent: [c]))
    #expect(map.highlight == frame(a, in: map))
    #expect(map.view == tree.parent(of: tree.leaf(containing: c)!))
  }

  @Test func aTabGroupIsOneRectangle() throws {
    var tree = makeTree()
    let d = WindowID(4)
    tree.addToStack(d, leaf: tree.leaf(containing: b)!)
    let map = try #require(make(tree, camera: tree.root))
    #expect(map.places.map(\.window) == [a, c, d], "the tab in front stands for the group")
  }

  @Test func thereIsNoMapOfNothing() {
    let empty = LayoutTree()
    #expect(make(empty, camera: empty.root) == nil, "only the Desktop")
    let tree = makeTree()
    #expect(make(tree, camera: tree.root, absent: [a, b, c]) == nil, "every docked window is minimized")
  }

  @Test func aDisplayWithoutAreaHasNoMap() {
    let tree = makeTree()
    for area in [
      CGSize.zero, CGSize(width: 0, height: 900), CGSize(width: 1440, height: 0.5), CGSize(width: -5, height: 10),
      CGSize(width: CGFloat.infinity, height: 900), CGSize(width: CGFloat.nan, height: 900),
      CGSize(width: 1440, height: CGFloat.infinity), CGSize(width: 1440, height: CGFloat.nan),
      CGSize(width: 0.5, height: 900),
    ] {
      #expect(make(tree, camera: tree.root, area: area) == nil, "\(area)")
    }
    #expect(make(tree, camera: tree.root, area: CGSize(width: 1, height: 1)) != nil, "a point is an area")
  }

  @Test func aCameraThatIsNotInTheTreeCountsAsEverything() throws {
    let tree = makeTree()
    let map = try #require(make(tree, camera: NodeID(999)))
    #expect(map.highlight == CGRect(origin: .zero, size: map.size))
  }

  @Test func moreWindowsThanPointsStillMakeAMap() throws {
    var tree = LayoutTree()
    for number in 1...300 { tree.dock(WindowID(UInt32(number)), beside: tree.desktop, edge: .left) }
    let map = try #require(make(tree, camera: tree.root))
    let bounds = CGRect(origin: .zero, size: map.size)
    #expect(map.places.count == 300)
    for place in map.places {
      #expect(place.frame.width >= 0 && place.frame.height >= 0 && place.frame.minX.isFinite && place.frame.maxX.isFinite)
      #expect(bounds.insetBy(dx: -0.5, dy: -0.5).contains(place.frame))
    }
  }

  // MARK: The panel

  let visible = CGRect(x: 1440, y: 25, width: 1440, height: 875)

  func model(camera: (LayoutTree) -> NodeID = { $0.root }, caption: String? = nil, takesClicks: Bool = false) throws
    -> MinimapModel
  {
    let tree = makeTree()
    return MinimapModel(
      try #require(make(tree, camera: camera(tree))), on: DisplayID("side"), in: visible, caption: caption,
      takesClicks: takesClicks, app: { (pid: Int32($0.rawValue), bundleID: "com.example.app\($0.rawValue)") })
  }

  @Test func thePanelSitsLowOnItsDisplayInTheMiddle() throws {
    let model = try model()
    #expect(model.display == DisplayID("side"))
    #expect(model.frame == CGRect(x: 2040, y: 690, width: 240, height: 154), "a 220×134 map and 10 points around it")
    #expect(model.frame.midX == visible.midX)
    #expect(visible.maxY - model.frame.maxY == 56)
    let inside = CGRect(origin: .zero, size: model.frame.size).insetBy(dx: 10, dy: 10)
    for rect in model.items.map(\.frame) + [model.highlight, try #require(model.desktop)] {
      #expect(inside.contains(rect), "in the panel's own coordinates, inside its padding")
    }
    #expect(model.highlight == inside)
    #expect(model.caption == nil && model.captionFrame == .zero)
  }

  @Test func itemsSayWhoseColourToUse() throws {
    let model = try model(camera: { $0.leaf(containing: WindowID(2))! })
    #expect(model.items.map(\.window) == [a, c, b])
    #expect(model.items.map(\.pid) == [1, 3, 2])
    #expect(model.items.map(\.bundleID) == ["com.example.app1", "com.example.app3", "com.example.app2"])
    #expect(model.items.map(\.isInView) == [false, false, true])
    #expect(model.highlight == model.items[2].frame)
    #expect(!model.desktopIsInView)
  }

  @Test func aWindowNobodyKnowsIsLeftOut() throws {
    let tree = makeTree()
    let model = MinimapModel(
      try #require(make(tree, camera: tree.root)), on: DisplayID("main"), in: visible,
      app: { $0 == self.c ? nil : (pid: 7, bundleID: nil) })
    #expect(model.items.map(\.window) == [a, b])
    #expect(!model.takesClicks && model.caption == nil, "unless asked for")
  }

  @Test func aCaptionMakesThePanelTallerAtTheTopAndLeavesTheMapWhereItWas() throws {
    let plain = try model()
    let captioned = try model(caption: "View 3")
    #expect(captioned.caption == "View 3")
    #expect(captioned.frame.height == plain.frame.height + 18)
    #expect(captioned.frame.maxY == plain.frame.maxY && captioned.frame.minX == plain.frame.minX)
    func onScreen(_ rect: CGRect, _ model: MinimapModel) -> CGRect {
      rect.offsetBy(dx: model.frame.minX, dy: model.frame.minY)
    }
    #expect(
      captioned.items.map { onScreen($0.frame, captioned) } == plain.items.map { onScreen($0.frame, plain) },
      "two moves in a row, one to a saved view: the map must not jump")
    #expect(captioned.captionFrame == CGRect(x: 10, y: 6, width: 220, height: 18), "as wide as the map")
    #expect(captioned.captionFrame.maxY <= captioned.highlight.minY - 3, "clear of the frame around the view")
  }

  @Test func aCaptionIsOneLineOfReasonableLength() throws {
    #expect(try model(caption: "Writing\nrm -rf").caption == "Writing")
    #expect(try model(caption: "").caption == nil)
    #expect(try model(caption: "\n").caption == nil)
    let long = try model(caption: String(repeating: "x", count: 500)).caption ?? ""
    #expect(long.count == 64 && long.hasSuffix("…"))
    let justFits = String(repeating: "x", count: 64)
    #expect(try model(caption: justFits).caption == justFits)
  }

  @Test func aDisplayTooSmallForThePanelStillContainsIt() throws {
    let tree = makeTree()
    let tiny = CGRect(x: 0, y: 0, width: 200, height: 100)
    let model = MinimapModel(
      try #require(make(tree, camera: tree.root, area: tiny.size)), on: DisplayID("tiny"), in: tiny,
      app: { _ in (pid: 1, bundleID: nil) })
    #expect(tiny.contains(model.frame))
  }

  // MARK: Clicks

  @Test func aClickMeansTheSpaceUnderIt() throws {
    let tree = makeTree()
    let model = try model(takesClicks: true)
    for item in model.items {
      #expect(model.space(at: item.frame.center) == tree.leaf(containing: item.window))
      #expect(model.space(at: CGPoint(x: item.frame.minX, y: item.frame.minY)) == item.space)
    }
    #expect(model.space(at: try #require(model.desktop).center) == tree.desktop)
  }

  @Test func halfOfAGapCountsTowardsItsNeighbour() throws {
    let model = try model(takesClicks: true)
    let (top, bottom) = (model.items[0], model.items[1])
    #expect(bottom.frame.minY - top.frame.maxY == 2)
    #expect(model.space(at: CGPoint(x: top.frame.midX, y: top.frame.maxY + 0.9)) == top.space)
    #expect(model.space(at: CGPoint(x: top.frame.midX, y: bottom.frame.minY - 0.9)) == bottom.space)
  }

  @Test func aClickBesideTheMapMeansNothing() throws {
    let model = try model(caption: "View 1", takesClicks: true)
    #expect(model.space(at: CGPoint(x: 2, y: 2)) == nil)
    #expect(model.space(at: model.captionFrame.center) == nil)
    #expect(model.space(at: CGPoint(x: model.frame.width - 2, y: model.frame.height - 2)) == nil)
    #expect(model.space(at: CGPoint(x: -50, y: 4000)) == nil)
    #expect(model.space(at: CGPoint(x: CGFloat.nan, y: CGFloat.infinity)) == nil)
  }

  @Test func thePointerOutlinesTheSpaceItIsOver() throws {
    let model = try model(takesClicks: true)
    #expect(model.hover == nil)
    for item in model.items { #expect(model.pointing(at: item.frame.center).hover == item.frame) }
    #expect(model.pointing(at: try #require(model.desktop).center).hover == model.desktop)
    #expect(model.pointing(at: CGPoint(x: 2, y: 2)).hover == nil)
    let over = model.pointing(at: model.items[0].frame.center)
    #expect(over.pointing(at: CGPoint(x: 2, y: 2)) == model, "and lets go of it again; nothing else changes")
    #expect(try self.model(takesClicks: false).pointing(at: model.items[0].frame.center).hover == nil, "nothing to click, nothing to outline")
  }

  // MARK: In words

  @Test func theLineSaysWhatIsInView() throws {
    #expect(try model().line == "[w1] [w3] [w2] [desktop]")
    #expect(try model(camera: { $0.leaf(containing: WindowID(3))! }).line == "w1 [w3] w2 desktop")
    #expect(
      try model(camera: { $0.desktop }, caption: "View 3", takesClicks: true).line
        == "w1 w3 w2 [desktop] \"View 3\" (takes clicks)")
    let asked = try model(camera: { $0.leaf(containing: WindowID(3))! }, takesClicks: true)
    #expect(asked.pointing(at: asked.items[2].frame.center).line == "w1 [w3] >w2 desktop (takes clicks)")
    #expect(asked.pointing(at: asked.items[1].frame.center).line == "w1 >[w3] w2 desktop (takes clicks)")
    #expect(asked.pointing(at: asked.desktop!.center).line == "w1 [w3] w2 >desktop (takes clicks)")
  }
}
