import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let wide = CGRect(x: 0, y: 25, width: 1920, height: 1055)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let usable = CGSize(width: 240, height: 160)
private let tileWide = CGSize(width: 80, height: 80)

private func everyone(_: WindowID) -> Bool { true }

/// What the children of every split weigh together: making room moves weight, it never makes any.
private func sums(_ tree: LayoutTree) -> [NodeID: Double] {
  var result: [NodeID: Double] = [:]
  for id in tree.preorder() where tree.isSplit(id) {
    result[id] = tree.children(of: id).reduce(0) { $0 + tree[$1]!.weight }
  }
  return result
}

private func expectSameSums(_ before: LayoutTree, _ after: LayoutTree, sourceLocation: SourceLocation = #_sourceLocation) {
  let old = sums(before)
  let new = sums(after)
  #expect(old.keys.sorted() == new.keys.sorted(), sourceLocation: sourceLocation)
  for (id, sum) in old { #expect(abs(sum - (new[id] ?? 0)) < 1e-9, "\(id)", sourceLocation: sourceLocation) }
}

extension Layout {
  /// 0 for a window that is not in view.
  fileprivate func width(of window: WindowID) -> CGFloat { windowFrames[window]?.width ?? 0 }
  fileprivate func height(of window: WindowID) -> CGFloat { windowFrames[window]?.height ?? 0 }
  fileprivate var desktopWidth: CGFloat { desktopFrame?.width ?? 0 }
}

private func noOverlaps(_ layout: Layout) -> Bool {
  var rects = Array(layout.windowFrames.values) + layout.tiles.map(\.frame)
  if let desktop = layout.desktopFrame { rects.append(desktop) }
  for (index, first) in rects.enumerated() {
    for second in rects[(index + 1)...] where first.overlaps(second) { return false }
  }
  return true
}

/// With a column for the Desktop: who gives first, how far, and what is owed is about a Desktop with a share of its own. What is not
/// about the Desktop is tried both ways.
@Suite struct MakeRoomTests {
  func serve(
    _ tree: inout LayoutTree, in frame: CGRect = screen, camera: NodeID? = nil, minimums: [WindowID: CGSize],
    inUse: Bool = false, leaving: Set<NodeID> = [], owed: Bool = false, desktopColumn: Bool = true
  ) -> (served: [WindowID], layout: Layout) {
    let (served, layout, _) = MakeRoom.serve(
      &tree, camera: camera ?? tree.root, in: frame, options: LayoutOptions(desktopColumn: desktopColumn), isPresent: everyone,
      minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: inUse, leaving: leaving, desktopIsOwed: owed))
    return (served.compactMap(\.window), layout)
  }

  /// [a | Desktop | b]: 464 points each on 1440. Without a column for the Desktop [a | b]: 702 each.
  func columns(desktopColumn: Bool = true) -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    tree.dock(b, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    return tree
  }

  @Test func theDesktopGivesFirstAndNobodyElseIsTouched() throws {
    var tree = columns()
    let before = tree
    let (served, layout) = serve(&tree, minimums: [a: CGSize(width: 574, height: 240)])
    #expect(served == [a])
    #expect(layout.width(of: a) >= 574)
    #expect(layout.width(of: a) <= 576, "no more than it needs")
    #expect(layout.windowFrames[b]?.width == 464)
    #expect(layout.desktopWidth >= 240)
    #expect(noOverlaps(layout))
    expectSameSums(before, tree)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func anEmptyDesktopGoesDownToATileSoThatBothFit() throws {
    var tree = columns()
    let minimums = [a: CGSize(width: 709, height: 300), b: CGSize(width: 574, height: 240)]
    let (served, layout) = serve(&tree, minimums: minimums)
    #expect(Set(served) == [a, b])
    #expect(layout.width(of: a) >= 709)
    #expect(layout.width(of: b) >= 574)
    #expect(layout.tiles.map(\.kind) == [.desktop])
    #expect((layout.tiles.first?.frame.width ?? 0) >= 80)
    #expect(noOverlaps(layout))
  }

  /// Somebody has asked for each docked window, nobody for the Desktop's points. What floats on it shows over the arrangement.
  @Test func aDesktopInUseGivesLikeAnEmptyOne() throws {
    let minimums = [a: CGSize(width: 709, height: 300), b: CGSize(width: 574, height: 240)]
    var tree = columns()
    let (served, layout) = serve(&tree, minimums: minimums, inUse: true)
    #expect(Set(served) == [a, b])
    #expect(layout.tiles.map(\.kind) == [.desktop])
    #expect(noOverlaps(layout))
  }

  @Test func whenThereIsNotEnoughForAllTheOneDockedLastIsServed() throws {
    let minimums = [a: CGSize(width: 709, height: 300), b: CGSize(width: 650, height: 240)]
    for (earlier, later) in [(a, b), (b, a)] {
      var tree = LayoutTree()
      tree.dock(earlier, beside: tree.root, edge: .left, desktopColumn: true)
      tree.dock(later, beside: tree.root, edge: .right, desktopColumn: true)
      let (served, layout) = serve(&tree, minimums: minimums)
      #expect(served == [later])
      #expect(layout.tiles.filter { $0.kind == .window }.map(\.windows) == [[earlier]])
      #expect(noOverlaps(layout))
    }
  }

  /// Both were served while the Desktop was empty. Now a window floats on it, and it is owed room.
  @Test func noWindowBecomesATileForTheDesktopsSake() throws {
    let minimums = [a: CGSize(width: 709, height: 300), b: CGSize(width: 574, height: 240)]
    var tree = columns()
    #expect(serve(&tree, minimums: minimums).layout.tiles.map(\.kind) == [.desktop])
    let squeezed = tree
    let (served, layout) = serve(&tree, minimums: minimums, inUse: true, owed: true)
    #expect(served.isEmpty)
    #expect(tree == squeezed)
    #expect(layout.windowFrames.count == 2)
  }

  @Test func anEmptyDesktopTakesNobodysPlace() throws {
    let minimums = [a: CGSize(width: 709, height: 300), b: CGSize(width: 574, height: 240)]
    var tree = columns()
    _ = serve(&tree, minimums: minimums)
    let squeezed = tree
    let (served, layout) = serve(&tree, minimums: minimums, owed: true)
    #expect(served.isEmpty)
    #expect(tree == squeezed)
    #expect(layout.windowFrames.count == 2)
  }

  /// Three that cannot all fit: the two docked last are served, and the tile and the empty Desktop go as narrow as it takes.
  @Test func tilesGiveAllTheyCanSoThatAsManyAsPossibleFit() throws {
    var tree = columns()
    tree.dock(c, beside: tree.root, edge: .right, desktopColumn: true)
    let minimums = [
      a: CGSize(width: 709, height: 300), b: CGSize(width: 574, height: 240), c: CGSize(width: 500, height: 300),
    ]
    let (served, layout) = serve(&tree, minimums: minimums)
    #expect(served == [c, b])
    #expect(layout.width(of: b) >= 574 && layout.width(of: c) >= 500)
    #expect(Set(layout.tiles.map(\.kind)) == [.window, .desktop])
    #expect(layout.tiles.allSatisfy { $0.frame.width >= 79 })
    #expect(noOverlaps(layout))
  }

  @Test func neighboursGiveInProportionToWhatTheyCanSpare() throws {
    // [a | b | c | Desktop] on 1920 points, the Desktop with nothing to give.
    var tree = LayoutTree()
    let leafC = tree.dock(c, beside: tree.root, edge: .left, desktopColumn: true)
    let leafB = tree.dock(b, beside: leafC, edge: .left, desktopColumn: true)
    let leafA = tree.dock(a, beside: leafB, edge: .left, desktopColumn: true)
    tree.setShares([leafA: 400, leafB: 940, leafC: 440, tree.desktop: 80])
    let before = tree
    let old = LayoutEngine.layout(tree, camera: tree.root, in: wide, isPresent: everyone)
    let (served, layout) = serve(
      &tree, in: wide, minimums: [a: CGSize(width: 650, height: 300)])
    #expect(served == [a])
    #expect(layout.width(of: a) >= 650)
    #expect(layout.tiles.map(\.frame.width) == old.tiles.map(\.frame.width), "the Desktop, a tile of 80")
    let gaveB = old.width(of: b) - layout.width(of: b)
    let gaveC = old.width(of: c) - layout.width(of: c)
    // b could spare 700 and c 200.
    #expect(abs(gaveB / gaveC - 3.5) < 0.15, "\(gaveB) and \(gaveC)")
    #expect(layout.width(of: c) >= 240)
    expectSameSums(before, tree)
  }

  @Test func aNeighbourGivesNoMoreThanItsOwnMinimumAllows() throws {
    var tree = columns()
    let before = tree
    // The Desktop can give 384 and b nothing: 14 short.
    let minimums = [a: CGSize(width: 862, height: 300), b: CGSize(width: 464, height: 240)]
    let (served, layout) = serve(&tree, minimums: minimums)
    #expect(served.isEmpty)
    #expect(tree == before, "half a solution helps nobody")
    #expect(layout.tiles.map(\.windows) == [[a]])
  }

  @Test(arguments: [true, false]) func inAColumnTheOneAboveGivesHeight(desktopColumn: Bool) throws {
    var tree = columns(desktopColumn: desktopColumn)
    let leafB = try #require(tree.leaf(containing: b))
    tree.dock(c, beside: leafB, edge: .bottom, desktopColumn: desktopColumn)
    let before = tree
    let (served, layout) = serve(&tree, minimums: [c: CGSize(width: 300, height: 600)], desktopColumn: desktopColumn)
    #expect(served == [c])
    #expect(layout.height(of: c) >= 600)
    #expect(layout.height(of: b) >= 160)
    #expect(layout.windowFrames[a]?.width == (desktopColumn ? 464 : 702), "nothing changed across")
    #expect(noOverlaps(layout))
    expectSameSums(before, tree)
  }

  @Test(arguments: [true, false]) func bothWaysAtOnce(desktopColumn: Bool) throws {
    var tree = columns(desktopColumn: desktopColumn)
    let leafB = try #require(tree.leaf(containing: b))
    tree.dock(c, beside: leafB, edge: .bottom, desktopColumn: desktopColumn)
    let (served, layout) = serve(&tree, minimums: [c: CGSize(width: 900, height: 600)], desktopColumn: desktopColumn)
    #expect(served == [c])
    let frame = try #require(layout.windowFrames[c])
    #expect(frame.width >= 900 && frame.height >= 600)
    #expect(layout.windowFrames[a] != nil && layout.windowFrames[b] != nil)
    #expect(noOverlaps(layout))
  }

  @Test(arguments: [true, false]) func wideEnoughButNeverTallEnoughChangesNothing(desktopColumn: Bool) throws {
    var tree = columns(desktopColumn: desktopColumn)
    let leafB = try #require(tree.leaf(containing: b))
    tree.dock(c, beside: leafB, edge: .bottom, desktopColumn: desktopColumn)
    let before = tree
    // The width could be found, the height could not: b needs 160 of the 839 the two share.
    let (served, _) = serve(&tree, minimums: [c: CGSize(width: 600, height: 700)], desktopColumn: desktopColumn)
    #expect(served.isEmpty)
    #expect(tree == before)
  }

  /// [a | Desktop | [[c | d] over b]]: the row c and d share lies inside the right-hand column.
  func nested(desktopColumn: Bool = true) throws -> LayoutTree {
    var tree = columns(desktopColumn: desktopColumn)
    let leafB = try #require(tree.leaf(containing: b))
    let leafC = tree.dock(c, beside: leafB, edge: .top, desktopColumn: desktopColumn)
    tree.dock(d, beside: leafC, edge: .right, desktopColumn: desktopColumn)
    return tree
  }

  @Test func whenItsOwnRowHasNothingLeftTheColumnItIsInGrows() throws {
    var tree = try nested()
    let before = tree
    let old = LayoutEngine.layout(tree, camera: tree.root, in: wide, isPresent: everyone)
    // c and d have 306 each; c can spare 66, the rest has to come from outside the column.
    let (served, layout) = serve(&tree, in: wide, minimums: [d: CGSize(width: 600, height: 200)])
    #expect(served == [d])
    #expect(layout.width(of: d) >= 600)
    #expect(layout.width(of: c) >= 239, "its neighbour in the row gave what it could, and no more")
    #expect(layout.width(of: c) <= 242, "and got none of what the column gained")
    #expect(layout.width(of: b) > old.width(of: b), "the column grew")
    #expect(layout.desktopWidth < old.desktopWidth)
    #expect(noOverlaps(layout))
    expectSameSums(before, tree)
  }

  @Test func aColumnGivesOnlyWhatTheTightestRowInItCanSpare() throws {
    var tree = try nested()
    let before = tree
    // c and d are at their minimums, so the column they are in cannot narrow, whatever b below them could spare.
    let minimums = [
      a: CGSize(width: 1300, height: 300), c: CGSize(width: 305, height: 100), d: CGSize(width: 305, height: 100),
    ]
    let (served, _) = serve(&tree, in: wide, minimums: minimums)
    #expect(served.isEmpty)
    #expect(tree == before)
  }

  @Test(arguments: [true, false]) func onlyWhatIsInViewTakesPart(desktopColumn: Bool) throws {
    var tree = try nested(desktopColumn: desktopColumn)
    let leafA = try #require(tree.leaf(containing: a))
    let leafB = try #require(tree.leaf(containing: b))
    let column = try #require(tree.parent(of: leafB))
    let outside = [tree.root, leafA, tree.desktop].map { tree[$0]!.weight }
    // Framed on the column, 1416 points wide: d gets what it needs from c alone.
    let (served, layout) = serve(&tree, camera: column, minimums: [d: CGSize(width: 900, height: 200)], desktopColumn: desktopColumn)
    #expect(served == [d])
    #expect(layout.width(of: d) >= 900)
    #expect([tree.root, leafA, tree.desktop].map { tree[$0]!.weight } == outside)
  }

  @Test func aDesktopThatGaveGetsBackWhatOthersCanSpareByNow() throws {
    // What is left when Notes has closed: a Desktop of 220 points beside a Safari of 1184.
    var tree = LayoutTree()
    let leafB = tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
    tree.setShares([tree.desktop: 220, leafB: 1184])
    let narrow = tree
    func terms(owed: Bool) -> MakeRoom.Terms { MakeRoom.Terms(desktopIsInUse: false, desktopIsOwed: owed) }
    func serve(_ tree: inout LayoutTree, owed: Bool) -> (served: [MakeRoom.Short], layout: Layout, gaveBack: Bool) {
      MakeRoom.serve(
        &tree, camera: tree.root, in: screen, options: LayoutOptions(desktopColumn: true), isPresent: everyone,
        minimumSize: { _ in CGSize(width: 574, height: 240) }, terms: terms(owed: owed))
    }
    #expect(serve(&tree, owed: false).served.isEmpty, "somebody may want it narrow")
    #expect(tree == narrow)
    let (served, layout, _) = serve(&tree, owed: true)
    #expect(served.map(\.node) == [tree.desktop])
    #expect(layout.desktopWidth >= 240 && layout.desktopWidth <= 242)
    #expect(layout.tiles.isEmpty)
    expectSameSums(narrow, tree)
  }

  @Test func aDesktopInUseGetsAsMuchAsCanBeSparedUpToItsWishAndAnEvenShare() throws {
    // [a 646 | Desktop 100 | b 646], 464 each if shared evenly. a will go down to 500, b to 600: 192 to spare.
    var start = columns()
    let leafA = try #require(start.leaf(containing: a))
    let leafB = try #require(start.leaf(containing: b))
    start.setShares([leafA: 646, start.desktop: 100, leafB: 646])
    let minimums = [a: CGSize(width: 500, height: 200), b: CGSize(width: 600, height: 200)]
    func width(wish: CGFloat) -> CGFloat {
      var tree = start
      let layout = MakeRoom.serve(
        &tree, camera: tree.root, in: screen, options: LayoutOptions(desktopColumn: true), isPresent: everyone,
        minimumSize: { minimums[$0] },
        terms: MakeRoom.Terms(desktopIsInUse: true, desktopIsOwed: true, desktopWish: CGSize(width: wish, height: 300))
      ).layout
      expectSameSums(start, tree)
      #expect(layout.windowFrames.count == 2, "nobody pays with their place for a wish")
      return layout.desktopWidth
    }
    #expect(width(wish: 0) == 240)
    #expect(width(wish: 270) == 270)
    #expect(width(wish: 1000) == 292, "all that can be spared, short of the even share")
  }

  @Test func anEmptyDesktopThatAsksNobodyTakesOnlyFromWindowsItKnows() throws {
    // [a | Desktop 100 | b]: a is known to go down to 300, nothing is known about b.
    var tree = columns()
    let leafA = try #require(tree.leaf(containing: a))
    let leafB = try #require(tree.leaf(containing: b))
    tree.setShares([leafA: 646, tree.desktop: 100, leafB: 646])
    func serve(_ tree: inout LayoutTree, known: [WindowID: CGSize]) -> Layout {
      MakeRoom.serve(
        &tree, camera: tree.root, in: screen, options: LayoutOptions(desktopColumn: true), isPresent: everyone,
        minimumSize: { known[$0] },
        terms: MakeRoom.Terms(desktopIsInUse: false, desktopIsOwed: true, emptyDesktopAsksNobody: true)
      ).layout
    }
    let narrow = tree
    #expect(serve(&tree, known: [:]).desktopFrame == nil)
    #expect(tree == narrow)
    let layout = serve(&tree, known: [a: CGSize(width: 300, height: 200)])
    #expect(layout.desktopWidth >= 240)
    #expect(layout.width(of: b) == 646, "nobody has asked it")
    #expect(layout.width(of: a) < 646)
  }

  @Test func slotsThePersonSqueezedAreLeftAlone() throws {
    var tree = columns()
    let before = tree
    let leafA = try #require(tree.leaf(containing: a))
    let (served, layout) = serve(&tree, minimums: [a: CGSize(width: 574, height: 240)], leaving: [leafA])
    #expect(served.isEmpty)
    #expect(tree == before)
    #expect(layout.tiles.map(\.windows) == [[a]])
  }

  /// It may have given down to that for a window that has gone since.
  @Test func aTileTooSmallForAnyWindowIsServedToo() throws {
    var tree = columns()
    let leafA = try #require(tree.leaf(containing: a))
    tree.setShares([leafA: 100, tree.desktop: 828])
    let narrow = tree
    #expect(serve(&tree, minimums: [:]).served.isEmpty, "what it needs is not known")
    #expect(tree == narrow)
    let (served, layout) = serve(&tree, minimums: [a: CGSize(width: 100, height: 100)])
    #expect(served == [a])
    #expect(layout.width(of: a) >= 240, "no window shows in less, whatever it would put up with")
  }

  @Test(arguments: [true, false]) func nothingShortNothingChanges(desktopColumn: Bool) {
    var tree = columns(desktopColumn: desktopColumn)
    let before = tree
    let (served, layout) = serve(&tree, minimums: [a: CGSize(width: 300, height: 200)], desktopColumn: desktopColumn)
    #expect(served.isEmpty)
    #expect(tree == before)
    #expect(layout == LayoutEngine.layout(before, camera: before.root, in: screen, isPresent: everyone))
  }

  @Test(arguments: [true, false]) func sharesKeepTheSumAndRefuseNonsense(desktopColumn: Bool) throws {
    var tree = columns(desktopColumn: desktopColumn)
    let leafA = try #require(tree.leaf(containing: a))
    let leafB = try #require(tree.leaf(containing: b))
    let before = tree
    tree.setShares([leafA: 300, leafB: 100])
    #expect(abs(tree[leafA]!.weight - 1.5) < 1e-12 && abs(tree[leafB]!.weight - 0.5) < 1e-12)
    #expect(tree[tree.desktop]!.weight == before[before.desktop]!.weight)
    for nonsense: [NodeID: Double] in [
      [leafA: .nan, leafB: 1], [leafA: 0, leafB: 1], [leafA: -5, leafB: 1], [leafA: .infinity, leafB: 1], [leafA: 1],
      [leafA: 1, NodeID(rawValue: 999): 1], [:],
    ] {
      var copy = before
      copy.setShares(nonsense)
      #expect(copy == before, "\(nonsense)")
    }
  }

  /// Any tree, any minimums: nobody in view loses their place, whoever is served fits, no weight appears or is lost.
  @Test(arguments: [true, false]) func anyTreeAnyMinimums(desktopColumn: Bool) {
    var seed: UInt64 = 0x5EED_F061
    func random(_ bound: Int) -> Int {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((seed >> 33) % UInt64(bound))
    }
    for _ in 0..<400 {
      var tree = LayoutTree()
      var leaves = [tree.desktop]
      var minimums: [WindowID: CGSize] = [:]
      let count = 2 + random(6)
      for number in 1...count {
        let window = WindowID(UInt32(number))
        leaves.append(
          tree.dock(window, beside: leaves[random(leaves.count)], edge: Edge.allCases[random(4)], desktopColumn: desktopColumn))
        if random(2) == 0 { minimums[window] = CGSize(width: 100 + random(900), height: 100 + random(600)) }
      }
      let before = tree
      let old = LayoutEngine.layout(
        tree, camera: tree.root, in: screen, isPresent: everyone, minimumSize: { minimums[$0] })
      let inUse = random(2) == 0
      let owed = random(3) == 0
      let (served, layout) = serve(&tree, minimums: minimums, inUse: inUse, owed: owed, desktopColumn: desktopColumn)
      #expect(tree.invariantViolations().isEmpty)
      expectSameSums(before, tree)
      #expect(noOverlaps(layout))
      #expect(old.windowFrames.keys.allSatisfy { layout.windowFrames[$0] != nil }, "nobody pays with their place")
      for window in served {
        let frame = layout.windowFrames[window] ?? .zero
        #expect(frame.width >= minimums[window]!.width - 1 && frame.height >= minimums[window]!.height - 1)
        #expect(old.windowFrames[window] == nil)
      }
      if served.isEmpty, old.desktopFrame != nil || layout.desktopFrame == nil { #expect(tree == before) }
      // Once is enough: asked again, it finds nothing to do.
      let settled = tree
      #expect(serve(&tree, minimums: minimums, inUse: inUse, owed: owed, desktopColumn: desktopColumn).served.isEmpty)
      #expect(tree == settled)

      // What is saved reads back as it was written.
      #expect((try? JSONDecoder().decode(LayoutTree.self, from: JSONEncoder().encode(tree))) == tree)
      // Framed on its own, a window has the whole display. That is no reason to give anything back.
      for leaf in tree.preorder() where !tree.isSplit(leaf) {
        var framed = tree
        _ = serve(&framed, camera: leaf, minimums: minimums, inUse: inUse, owed: owed, desktopColumn: desktopColumn)
        #expect(framed == tree)
      }
      // Everybody leaves, in any order: the ledger never breaks the tree, and ends empty.
      var windows = Array(1...count).map { WindowID(UInt32($0)) }
      while !windows.isEmpty {
        tree.remove(windows.remove(at: random(windows.count)))
        #expect(tree.invariantViolations().isEmpty)
        // (A Desktop without room weighs nothing, on purpose.)
        let weightless = tree.preorder().filter { !(tree[$0]!.weight.isFinite && tree[$0]!.weight > 0) }
        #expect(weightless.isEmpty || !desktopColumn && weightless == [tree.desktop] && tree[tree.desktop]!.weight == 0)
      }
      #expect(!tree.hasLoans)
    }
  }
}
