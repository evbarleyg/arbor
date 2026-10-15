import ArborCore
import CoreGraphics
import Foundation
import Testing

private let wide = CGRect(x: 0, y: 25, width: 1920, height: 1055)
private let laptop = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)

private func everyone(_: WindowID) -> Bool { true }

/// With a column for the Desktop, which ships off (`Settings.desktopColumn`): it is a lender, a tile and a neighbour in these stories. `row` has none.
private let overlapping = LayoutOptions(desktopColumn: true, overlaps: true)

private func layOut(
  _ tree: LayoutTree, in frame: CGRect = wide, camera: NodeID? = nil, options: LayoutOptions = overlapping, minimums: [WindowID: CGSize] = [:]
) -> Layout {
  LayoutEngine.layout(tree, camera: camera ?? tree.root, in: frame, options: options, isPresent: everyone, minimumSize: { minimums[$0] })
}

private func serve(
  _ tree: inout LayoutTree, in frame: CGRect = wide, options: LayoutOptions = overlapping, minimums: [WindowID: CGSize], keyboard: WindowID? = nil,
  leaving: Set<NodeID> = []
) -> (served: [WindowID], layout: Layout, gaveBack: Bool) {
  let (served, layout, gaveBack) = MakeRoom.serve(
    &tree, camera: tree.root, in: frame, options: options, isPresent: everyone, minimumSize: { minimums[$0] },
    terms: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard, leaving: leaving))
  return (served.compactMap(\.window), layout, gaveBack)
}

/// [a | Desktop | b]
private func columns() -> LayoutTree {
  var tree = LayoutTree()
  tree.dock(a, beside: tree.root, edge: .left, desktopColumn: true)
  tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
  return tree
}

/// A row of windows with no Desktop among them, in a view of its own.
private func row(_ windows: [WindowID], axis: Edge = .right) -> (tree: LayoutTree, view: NodeID) {
  var tree = LayoutTree()
  // Across the root's own axis, or the row would be the root's, with the Desktop in it.
  tree.dock(windows[0], beside: tree.root, edge: axis == .right ? .top : .left, desktopColumn: true)
  var last = tree.leaf(containing: windows[0])!
  for window in windows.dropFirst() {
    tree.dock(window, beside: last, edge: axis)
    last = tree.leaf(containing: window)!
  }
  // Each docked beside the last took half of its place. Even shares.
  tree.setShares(Dictionary(uniqueKeysWithValues: windows.map { (tree.leaf(containing: $0)!, 100) }), for: nil)
  return (tree, tree.parent(of: last)!)
}

/// What cannot fit overlaps (board 0.26): where the layout used to say "it is the tile" it says "it stands at its smallest, flush
/// with the outer side of its place, and hangs over inwards".
@Suite struct OverlapTests {
  // MARK: Where it stands

  @Test func aWindowThatFitsIsInItsPlaceAndNothingIsSaidOfIt() {
    let tree = columns()
    let layout = layOut(tree, minimums: [a: CGSize(width: 500, height: 300)])
    #expect(layout == layOut(tree, options: LayoutOptions(), minimums: [a: CGSize(width: 500, height: 300)]))
    #expect(layout.overhangs.isEmpty)
    #expect(layout.fits(a) && layout.fits(b))
  }

  @Test func theFirstOfARowIsFlushLeftAndTheLastFlushRight() throws {
    let tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let layout = layOut(tree, minimums: minimums)
    let (placeA, placeB) = (try #require(layout.nodeFrames[tree.leaf(containing: a)!]), try #require(layout.nodeFrames[tree.leaf(containing: b)!]))
    #expect(layout.windowFrames[a] == CGRect(x: placeA.minX, y: placeA.minY, width: 1188, height: placeA.height))
    #expect(layout.windowFrames[b] == CGRect(x: placeB.maxX - 760, y: placeB.minY, width: 760, height: placeB.height))
    #expect(layout.overhangs[a] == CGSize(width: 1188 - placeA.width, height: 0))
    #expect(layout.overhangs[b] == CGSize(width: 760 - placeB.width, height: 0))
    #expect(layout.tiles.isEmpty && layout.hiddenWindows.isEmpty)
    #expect(!layout.fits(a) && !layout.fits(b))
  }

  @Test func thePlacesAreTheOnesTheTileHad() {
    let tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let (over, tiled) = (layOut(tree, minimums: minimums), layOut(tree, options: LayoutOptions(), minimums: minimums))
    #expect(over.nodeFrames == tiled.nodeFrames)
    #expect(over.seams == tiled.seams)
    #expect(over.desktopFrame == tiled.desktopFrame)
    #expect(Set(tiled.tiles.flatMap(\.windows)) == Set(over.overhangs.keys))
    #expect(over.placesTooSmall == tiled.placesTooSmall)
  }

  @Test func thoseBetweenAreFlushWithTheLeftOfTheirPlace() throws {
    let (tree, view) = row([a, b, c])
    let minimum = CGSize(width: 900, height: 300)
    let layout = layOut(tree, camera: view, minimums: [a: minimum, b: minimum, c: minimum])
    let content = LayoutEngine.content(of: wide, options: overlapping)
    let place = try #require(layout.nodeFrames[tree.leaf(containing: b)!])
    #expect(layout.windowFrames[a]?.minX == content.minX)
    #expect(layout.windowFrames[b]?.minX == place.minX)
    #expect(layout.windowFrames[c]?.maxX == content.maxX)
    for window in [a, b, c] { #expect(layout.windowFrames[window]?.width == 900) }
  }

  @Test func oneBetweenIsPushedInRatherThanOutOfTheView() throws {
    let (tree, view) = row([a, b, c])
    let layout = layOut(tree, camera: view, minimums: [b: CGSize(width: 1500, height: 300)])
    let content = LayoutEngine.content(of: wide, options: overlapping)
    #expect(layout.windowFrames[b]?.maxX == content.maxX)
    #expect(layout.windowFrames[b]?.width == 1500)
  }

  @Test func oneLargerThanTheViewBeginsAtItsLeftAndTop() {
    let tree = columns()
    let layout = layOut(tree, in: laptop, minimums: [b: CGSize(width: 2000, height: 1200)])
    let content = LayoutEngine.content(of: laptop, options: overlapping)
    #expect(layout.windowFrames[b] == CGRect(x: content.minX, y: content.minY, width: 2000, height: 1200))
  }

  /// 1188 points of editor, 1170 inside the gaps and 1194 beside the Dock: it takes of the gap around the view rather than lie beyond the display's edge.
  @Test func oneLargerThanTheViewByLessThanTheGapAroundItStaysOnTheDisplay() {
    let besideTheDock = CGRect(x: 86, y: 25, width: 1194, height: 775)
    let layout = layOut(columns(), in: besideTheDock, minimums: [b: CGSize(width: 1188, height: 770)])
    #expect(layout.windowFrames[b] == CGRect(x: 92, y: 30, width: 1188, height: 770))
  }

  @Test func whatHangsOverAGapOrTheDesktopCoversNobody() throws {
    // [a | Desktop | b]: a needs a little more than its place, and the Desktop lies beside it.
    let plain = layOut(columns())
    let place = try #require(plain.windowFrames[a])
    let little = layOut(columns(), minimums: [a: CGSize(width: place.width + 30, height: 300)])
    #expect(little.overhangs[a]?.width == 30)
    #expect(little.overhangsOverWindows.isEmpty)
    let much = layOut(columns(), minimums: [a: CGSize(width: try #require(plain.windowFrames[b]).minX - place.minX + 30, height: 300)])
    #expect(much.overhangsOverWindows.keys.sorted() == [a])
  }

  @Test func columnsLikewiseTopAndBottom() throws {
    let (tree, view) = row([a, b], axis: .bottom)
    let minimum = CGSize(width: 300, height: 700)
    let layout = layOut(tree, camera: view, minimums: [a: minimum, b: minimum])
    let content = LayoutEngine.content(of: wide, options: overlapping)
    #expect(layout.windowFrames[a] == CGRect(x: content.minX, y: content.minY, width: content.width, height: 700))
    #expect(layout.windowFrames[b] == CGRect(x: content.minX, y: content.maxY - 700, width: content.width, height: 700))
    #expect(layout.overhangs[a]?.width == 0)
  }

  @Test func whichSideIsReadFromTheViewAlsoInsideAGroup() throws {
    // [a | Desktop | (b over c)]: b and c are the last of the outer row, each the whole of its own.
    var tree = columns()
    tree.dock(c, beside: tree.leaf(containing: b)!, edge: .bottom)
    let layout = layOut(tree, minimums: [c: CGSize(width: 900, height: 300)])
    let content = LayoutEngine.content(of: wide, options: overlapping)
    #expect(layout.windowFrames[c]?.maxX == content.maxX)
    #expect(layout.windowFrames[c]?.width == 900)
    #expect(layout.fits(b))
  }

  @Test func aPlaceTooSmallForAnyWindowMakesNoTileEither() throws {
    let (tree, view) = row([a, b, c, d, WindowID(5), WindowID(6), WindowID(7), WindowID(8)])
    let layout = layOut(tree, in: laptop, camera: view)
    #expect(layout.tiles.isEmpty && layout.hiddenWindows.isEmpty)
    // Nobody is asked to go under what a window is of use at.
    for frame in layout.windowFrames.values { #expect(frame.width == 240) }
    let content = LayoutEngine.content(of: laptop, options: overlapping)
    for frame in layout.windowFrames.values { #expect(content.contains(frame)) }
  }

  @Test func noGroupsTileEither() throws {
    // The column of b over c is squeezed to 100 points.
    var tree = columns()
    tree.dock(c, beside: tree.leaf(containing: b)!, edge: .bottom)
    let group = try #require(tree.parent(of: tree.leaf(containing: b)!))
    tree.setShares([tree.leaf(containing: a)!: 1000, tree.desktop: 772, group: 100], for: nil)
    #expect(layOut(tree, options: LayoutOptions()).tiles.map(\.kind) == [.group])
    let layout = layOut(tree)
    #expect(layout.tiles.isEmpty && layout.hiddenWindows.isEmpty)
    #expect(layout.windowFrames[b]?.width == 240 && layout.windowFrames[c]?.width == 240)
  }

  @Test func theDesktopCanStillBeATile() {
    var tree = columns()
    tree.setShares([tree.leaf(containing: a)!: 900, tree.desktop: 72, tree.leaf(containing: b)!: 900], for: nil)
    #expect(layOut(tree).tiles.map(\.kind) == [.desktop])
  }

  @Test func theWindowTheViewIsOnHasTheWholeViewWhateverItsSmallest() {
    let tree = columns()
    let layout = layOut(tree, in: laptop, camera: tree.leaf(containing: a), minimums: [a: CGSize(width: 2000, height: 300)])
    #expect(layout.windowFrames[a] == LayoutEngine.content(of: laptop, options: overlapping))
    #expect(layout.overhangs.isEmpty)
  }

  @Test func aPointOverIsNoOverhangAsItWasNoTile() {
    let tree = columns()
    let width = layOut(tree).windowFrames[a]!.width
    #expect(layOut(tree, minimums: [a: CGSize(width: width + 1, height: 0)]).overhangs.isEmpty)
    #expect(layOut(tree, minimums: [a: CGSize(width: width + 2, height: 0)]).overhangs[a]?.width == 2)
  }

  @Test func everyFrameIsOnWholePoints() {
    let tree = columns()
    let frame = layOut(tree, minimums: [a: CGSize(width: 1187.5, height: 0)]).windowFrames[a]!
    #expect(frame.width == 1188 && frame.minX == frame.minX.rounded())
  }

  // MARK: Room first

  @Test func theStory() throws {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let layout = serve(&tree, minimums: minimums).layout
    #expect(layout.windowFrames[a] == CGRect(x: 12, y: 37, width: 1188, height: 1031))
    #expect(layout.windowFrames[b] == CGRect(x: 1148, y: 37, width: 760, height: 1031))
    // The one docked last has what it needs; the other all that could be spared.
    #expect(layout.fits(b))
    #expect(layout.overhangs[a] == CGSize(width: 156, height: 0))
    #expect(layout.nodeFrames[tree.desktop]?.width == 80)
  }

  /// A terminal goes down to a slit. Beside an editor that hangs over whatever it gives, it was one.
  @Test func nobodyWhoFitsGoesBelowAnEvenShareForOneThatDoesNotFitAnyway() throws {
    // Two halves, as without a column for the Desktop: 942 each. b fits and could spare 182; a is short by 246.
    var (tree, view) = row([a, b])
    let before = tree
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let (served, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(layout.windowFrames[a] == CGRect(x: 12, y: 37, width: 1188, height: 1031))
    #expect(layout.windowFrames[b] == CGRect(x: 966, y: 37, width: 942, height: 1031))
    #expect(layout.overhangs[a]?.width == 246)
    #expect(served.isEmpty && tree == before)
  }

  @Test func whatItHasAboveAnEvenShareItGives() throws {
    // b has 1256 of the 1884, a 628.
    var (tree, view) = row([a, b])
    tree.setShares([tree.leaf(containing: a)!: 100, tree.leaf(containing: b)!: 200], for: nil)
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let (_, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(layout.windowFrames[a] == CGRect(x: 12, y: 37, width: 1188, height: 1031))
    #expect(layout.windowFrames[b] == CGRect(x: 966, y: 37, width: 942, height: 1031))
    // In the ledger like any loan.
    #expect(tree.hasLoans)
  }

  /// The even share is a limit only where somebody hangs over in the end. Where all fit it is F61, which takes what it needs.
  @Test func whereAllFitInTheEndTheOneThatFitsGoesBelowItsHalfAsEver() throws {
    var (tree, view) = row([a, b])
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 177, height: 64)]
    let (_, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(layout.overhangs.isEmpty)
    #expect(layout.windowFrames[a]?.width == 1188 && layout.windowFrames[b]?.width == 696)
  }

  /// [(a over c) | b]: a is too wide whatever is done. It can be as high as it needs, and c, which fits, gives that as ever.
  @Test func eachWayByItself() throws {
    var (tree, view) = row([a, b])
    tree.dock(c, beside: tree.leaf(containing: a)!, edge: .bottom)
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400), c: CGSize(width: 400, height: 300)]
    let (_, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(layout.overhangs == [a: CGSize(width: 246, height: 0)])
    #expect(layout.windowFrames[a]?.height == 685)
    #expect(layout.windowFrames[b]?.width == 942)
    #expect(try !#require(layout.windowFrames[c]).overlaps(try #require(layout.windowFrames[a])))
  }

  /// One above the other likewise.
  @Test func norLowerThanAnEvenShare() throws {
    var (tree, view) = row([a, b], axis: .bottom)
    let minimums = [a: CGSize(width: 300, height: 900), b: CGSize(width: 300, height: 200)]
    let (_, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    let half = layOut(row([a, b], axis: .bottom).tree, camera: view).windowFrames[b]
    #expect(layout.windowFrames[b] == half)
    #expect(layout.windowFrames[a]?.height == 900 && layout.windowFrames[a]?.minY == 37)
  }

  @Test func withTilesItIsAllOrNothingAsEver() throws {
    var (tree, view) = row([a, b])
    let before = tree
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let (served, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: LayoutOptions(), isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(served.isEmpty && tree == before)
    #expect(layout.tiles.flatMap(\.windows) == [a])
  }

  @Test func anotherLayoutFindsNothingToDo() {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let first = serve(&tree, minimums: minimums).layout
    let settled = tree
    let again = serve(&tree, minimums: minimums)
    #expect(again.served.isEmpty && !again.gaveBack)
    #expect(tree == settled && again.layout == first)
    // And a plain layout of the tree is what was served.
    #expect(layOut(tree, minimums: minimums) == first)
  }

  @Test func nobodyWhoFitsComesToHangOverForIt() {
    // c fits with nothing to spare.
    var (tree, view) = row([a, b, c])
    let third = layOut(tree, camera: view).windowFrames[c]!.width
    let minimums = [a: CGSize(width: 1000, height: 0), b: CGSize(width: third, height: 0), c: CGSize(width: third, height: 0)]
    let (_, layout, _) = MakeRoom.serve(
      &tree, camera: view, in: wide, options: overlapping, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false))
    #expect(layout.fits(b) && layout.fits(c))
    #expect(Array(layout.overhangs.keys) == [a])
  }

  @Test func theRoomGoesBackWhenTheNeighbourHasGone() {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    _ = serve(&tree, minimums: minimums)
    _ = tree.remove(b)
    let layout = serve(&tree, minimums: minimums).layout
    #expect(layout.fits(a))
    #expect(layout.overhangs.isEmpty)
  }

  @Test func aWindowShortInHeightAloneStillKeepsItsWidth() {
    // a over b on the left, c on the right wants more width. a hangs over in height, and goes no narrower than it goes.
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: tree.leaf(containing: a)!, edge: .bottom)
    tree.dock(c, beside: tree.root, edge: .right)
    let minimums = [a: CGSize(width: 600, height: 800), b: CGSize(width: 300, height: 400), c: CGSize(width: 1300, height: 300)]
    let layout = serve(&tree, minimums: minimums).layout
    #expect((layout.overhangs[a]?.width ?? 0) == 0)
    #expect((layout.nodeFrames[tree.leaf(containing: a)!]?.width ?? 0) >= 600)
  }

  @Test func aPlaceMadeShortByHandIsLeftAsItIsAndTheWindowHangsOver() throws {
    var tree = columns()
    let leaf = tree.leaf(containing: a)!
    tree.setShares([leaf: 400, tree.desktop: 872, tree.leaf(containing: b)!: 600], for: nil)
    let before = tree
    let result = serve(&tree, minimums: [a: CGSize(width: 700, height: 300)], leaving: [leaf])
    #expect(tree == before)
    #expect(result.layout.windowFrames[a]?.width == 700)
    #expect(result.layout.overhangs[a]?.width == 300)
  }

  // MARK: What goes by the layout

  @Test func aPointBelongsToTheWindowWhosePlaceItIsIn() throws {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let layout = serve(&tree, minimums: minimums).layout
    // Both windows lie here, in b's place.
    #expect(layout.leafOrTile(at: CGPoint(x: 1170, y: 500), in: tree) == tree.leaf(containing: b))
    // Over the Desktop's tile lies a.
    #expect(layout.leafOrTile(at: CGPoint(x: 1100, y: 500), in: tree) == tree.leaf(containing: a))
    #expect(layout.leafOrTile(at: CGPoint(x: 100, y: 500), in: tree) == tree.leaf(containing: a))
  }

  @Test func aGapUnderAWindowHasNoHandle() throws {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let layout = serve(&tree, minimums: minimums).layout
    #expect(layout.seams.count == 2)
    #expect(layout.seamsInReach.isEmpty)
  }

  @Test func whereAStretchOfItCanBeReachedThatStretchHasOne() throws {
    // [a | Desktop | (b over c)]: c hangs over the gaps to its left, b does not.
    var tree = columns()
    tree.dock(c, beside: tree.leaf(containing: b)!, edge: .bottom)
    let layout = layOut(tree, minimums: [c: CGSize(width: 1400, height: 300)])
    let covering = try #require(layout.windowFrames[c])
    let upright = layout.seamsInReach.filter { $0.axis == .horizontal }
    #expect(upright.count == 2)
    for seam in upright {
      #expect(!seam.frame.overlaps(covering))
      #expect(seam.frame.maxY == covering.minY)
    }
    // The gap between b and c lies within their column, which c covers below it and not on it.
    #expect(layout.seamsInReach.count == layout.seams.count)
  }

  @Test func withNobodyHangingOverEveryGapIsInReach() {
    let layout = layOut(columns())
    #expect(layout.seamsInReach == layout.seams)
  }

  @Test func aPlaceLeftOpenIsNotSaidToHangOver() {
    let tree = columns()
    let layout = layOut(tree, minimums: [a: CGSize(width: 1188, height: 0)]).leavingOpen([a], in: tree)
    #expect(layout.overhangs.isEmpty && layout.windowFrames[a] == nil)
  }

  @Test func theDrawingShowsThePlacesAndMarksTheSide() {
    var tree = columns()
    let minimums = [a: CGSize(width: 1188, height: 685), b: CGSize(width: 760, height: 400)]
    let layout = serve(&tree, minimums: minimums).layout
    let lines = AsciiRenderer.render(layout, tree: tree, columns: 64, rows: 6).split(separator: "\n").map(String.init)
    #expect(lines[1].contains(">"))
    #expect(!lines[1].contains("<"))
    #expect(lines.last == "camera \(tree.root)  over its place: w1 by 156")
  }

  @Test func automaticDockingCountsHangingOverAsNoRoom() {
    let tree = columns()
    let before = layOut(tree)
    let after = layOut(tree, minimums: [a: CGSize(width: 1188, height: 0)])
    #expect(!AutoDock.keepsEverythingShowing(before: before, after: after, adding: b))
    #expect(!AutoDock.keepsEverythingShowing(before: before, after: after, adding: a))
    #expect(AutoDock.keepsEverythingShowing(before: before, after: before, adding: b))
  }

  // MARK: The setting and the line

  @Test func asItShipsWindowsOverlapAndTheOtherValueIsTheTile() throws {
    #expect(Settings().windowsThatDoNotFit == "overlap")
    #expect(Settings().layoutOptions.overlaps)
    var settings = Settings()
    settings.windowsThatDoNotFit = "tile"
    #expect(!settings.layoutOptions.overlaps)
    // A file from before the key loads, and has the default.
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 10}"#.utf8))
    #expect(old.windowsThatDoNotFit == "overlap")
    let chosen = try JSONDecoder().decode(Settings.self, from: Data(#"{"windowsThatDoNotFit": "tile"}"#.utf8))
    #expect(chosen.windowsThatDoNotFit == "tile")
  }

  @Test func theLineIsSaidWhenOneMoreHangsOver() {
    var before = HeadsUpFacts(docked: 1, outOfView: 0, tiles: 0)
    var after = HeadsUpFacts(docked: 2, outOfView: 0, tiles: 0)
    after.tooWide = 1
    #expect(before.moments(to: after) == [.overlap, .docked])
    #expect(HeadsUpHint.overlap.model(facts: after, shortcut: { _ in nil }).line == "Too wide to stand side by side · they overlap")
    before = after
    #expect(before.moments(to: after).isEmpty)
    after.tooWide = 0
    #expect(before.moments(to: after).isEmpty)
    after.tooTall = 2
    #expect(before.moments(to: after) == [.overlap])
    #expect(HeadsUpHint.overlap.model(facts: after, shortcut: { _ in nil }).line == "Too tall to stand one above the other · they overlap")
  }
}
