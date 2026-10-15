import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let mail = WindowID(1)
private let chat = WindowID(2)
private let notes = WindowID(3)
private let safari = WindowID(4)
private let wide = [
  mail: CGSize(width: 820, height: 400), chat: CGSize(width: 760, height: 500), notes: CGSize(width: 709, height: 300),
]
private let tall = [
  mail: CGSize(width: 400, height: 500), chat: CGSize(width: 400, height: 450), notes: CGSize(width: 709, height: 300),
  safari: CGSize(width: 300, height: 450),
]

/// Where room is short, whoever has the keyboard is served first, and what was lent to the others goes back for it (F61, second
/// round, 3). The one exception to "nobody in view pays with their place": how far it reaches.
@Suite struct KeyboardFirstRoomTests {
  @discardableResult
  func serve(
    _ tree: inout LayoutTree, keyboard: WindowID?, camera: NodeID? = nil, known: [WindowID: CGSize] = wide, givesBack: Bool = true
  ) -> Layout {
    var terms = MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard)
    terms.givesBack = givesBack
    return MakeRoom.serve(
      &tree, camera: camera ?? tree.root, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] },
      terms: terms
    ).layout
  }

  /// The weights of a row or column, as parts of their sum.
  func parts(of row: NodeID, _ tree: LayoutTree) -> [Double] {
    let weights = tree.children(of: row).map { tree[$0]!.weight }
    return weights.map { $0 / weights.reduce(0, +) }
  }

  func expectSame(_ parts: [Double], _ expected: [Double], sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(parts.count == expected.count, sourceLocation: sourceLocation)
    for (part, wanted) in zip(parts, expected) { #expect(abs(part - wanted) < 1e-9, "\(parts)", sourceLocation: sourceLocation) }
  }

  /// [Mail | Desktop | Chat], a third each: 820 and 760 do not both fit on 1440 points.
  func columns() -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(mail, beside: tree.root, edge: .left)
    tree.dock(chat, beside: tree.root, edge: .right)
    return tree
  }

  /// [Notes | Desktop | Mail over Chat]: 500 and 450 do not both fit into 875 points of height.
  func columnBesideNotes() -> (tree: LayoutTree, column: NodeID) {
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .left)
    let top = tree.dock(mail, beside: tree.root, edge: .right)
    tree.dock(chat, beside: top, edge: .bottom)
    return (tree, tree.parent(of: top)!)
  }

  @Test func whatWasLentToTheOtherGoesBackForTheWindowWithTheKeyboard() throws {
    var tree = columns()
    let sum = tree.children(of: tree.root).reduce(0) { $0 + tree[$1]!.weight }
    var layout = serve(&tree, keyboard: chat)
    #expect(layout.windowFrames[chat]?.width == 760)
    #expect(layout.windowFrames[mail] == nil)
    let first = tree

    layout = serve(&tree, keyboard: mail)
    #expect(layout.windowFrames[mail]?.width == 820)
    #expect(layout.windowFrames[chat] == nil)
    let leaf = try #require(tree.leaf(containing: mail))
    #expect(tree.hasLoans && tree.loans.allSatisfy { $0.borrower == leaf }, "\(tree.loans)")
    #expect(abs(tree.children(of: tree.root).reduce(0) { $0 + tree[$1]!.weight } - sum) < 1e-9, "weight moves, none is made")
    let settled = tree
    serve(&tree, keyboard: mail)
    #expect(tree == settled, "and another layout finds nothing to do")

    serve(&tree, keyboard: chat)
    expectSame(parts(of: tree.root, tree), parts(of: first.root, first))
    #expect(tree.loans.map(\.borrower) == first.loans.map(\.borrower), "there and back is nothing")
  }

  @Test func withoutTheKeyboardNobodyPaysWithTheirPlace() {
    var tree = columns()
    serve(&tree, keyboard: chat)
    let before = tree
    #expect(serve(&tree, keyboard: nil).windowFrames[chat]?.width == 760)
    #expect(tree == before)
  }

  /// Zooming never rearranges what is out of view. There it could not help the window with the keyboard, and nobody would be served
  /// again from what is left.
  @Test func whatWasLentOutOfViewStaysLent() throws {
    var (tree, column) = columnBesideNotes()
    var layout = serve(&tree, keyboard: mail, known: tall)
    #expect(layout.windowFrames[notes]?.width == 709)
    #expect(layout.windowFrames[mail]?.height == 500)
    #expect(layout.windowFrames[chat] == nil)
    let row = parts(of: tree.root, tree)
    let borrower = try #require(tree.leaf(containing: notes))
    let lent = tree.loans.filter { $0.borrower == borrower }
    #expect(!lent.isEmpty)

    layout = serve(&tree, keyboard: chat, camera: column, known: tall)
    #expect(layout.windowFrames[chat]?.height == 450)
    #expect(layout.windowFrames[mail] == nil)
    expectSame(parts(of: tree.root, tree), row)
    #expect(tree.loans.filter { $0.borrower == borrower } == lent)
  }

  /// In view, whoever gave back more than it took is served again at once from what is left.
  @Test func whoeverInViewNeedNotHavePaidIsServedAgain() {
    var (tree, _) = columnBesideNotes()
    serve(&tree, keyboard: mail, known: tall)
    let row = parts(of: tree.root, tree)
    let layout = serve(&tree, keyboard: chat, known: tall)
    #expect(layout.windowFrames[chat]?.height == 450)
    #expect(layout.windowFrames[mail] == nil)
    #expect(layout.windowFrames[notes]?.width == 709)
    expectSame(parts(of: tree.root, tree), row)
  }

  @Test func aWindowThatFitsNowhereCostsNobodyTheirPlace() {
    var tree = columns()
    serve(&tree, keyboard: chat)
    let before = tree
    var known = wide
    known[mail] = CGSize(width: 1600, height: 400)
    let layout = serve(&tree, keyboard: mail, known: known)
    #expect(layout.windowFrames[chat]?.width == 760)
    #expect(tree == before, "half a solution helps nobody")
  }

  /// `RelayoutReason.enforce`: nothing goes back because an app has moved its own window, but for the window being typed in.
  @Test func whereNothingElseGoesBackTheWindowWithTheKeyboardIsStillServed() {
    var tree = columns()
    serve(&tree, keyboard: chat)
    let before = tree
    #expect(serve(&tree, keyboard: nil, givesBack: false).windowFrames[chat]?.width == 760)
    #expect(tree == before)
    let layout = serve(&tree, keyboard: mail, givesBack: false)
    #expect(layout.windowFrames[mail]?.width == 820)
    #expect(layout.windowFrames[chat] == nil)
  }

  /// A gap that a person has moved is theirs, so nothing is owed across it that could go back. The window with the keyboard borrows
  /// across it then, at the cost of the neighbour's place, and the ledger knows where the person had put the gap.
  @Test func acrossAGapThatAPersonHasMovedItBorrowsAndTheGapComesBack() throws {
    var tree = columns()
    serve(&tree, keyboard: chat)
    tree.moveBoundary(leading: tree.desktop, trailing: try #require(tree.leaf(containing: chat)), by: -10, pointsPerWeight: 464)
    #expect(!tree.hasLoans)
    let theirs = tree
    #expect(serve(&tree, keyboard: chat).windowFrames[chat]?.width == 770)
    #expect(tree == theirs)

    var layout = serve(&tree, keyboard: mail)
    #expect(layout.windowFrames[mail]?.width == 820)
    #expect(layout.windowFrames[chat] == nil)
    let leaf = try #require(tree.leaf(containing: mail))
    #expect(tree.hasLoans && tree.loans.allSatisfy { $0.borrower == leaf }, "\(tree.loans)")
    let settled = tree
    serve(&tree, keyboard: mail)
    #expect(tree == settled, "and another layout finds nothing to do")

    layout = serve(&tree, keyboard: chat)
    #expect(layout.windowFrames[chat]?.width == 770)
    expectSame(parts(of: tree.root, tree), parts(of: theirs.root, theirs))
    #expect(!tree.hasLoans)
  }

  /// [Desktop 80 | Mail 490 | Chat 490 | Notes 320] by hand, nothing lent, the two in the middle with ten points to spare each. Both
  /// have to give more than that, and no more leave the view than must.
  @Test func ofTwoNeighboursThatPayTheNewerIsServedAgainFromWhatIsLeft() {
    let known = [mail: CGSize(width: 480, height: 400), chat: CGSize(width: 480, height: 400), notes: CGSize(width: 700, height: 300)]
    var tree = LayoutTree()
    let leaves = [mail, chat, notes].map { tree.dock($0, beside: tree.root, edge: .right) }
    tree.setShares([tree.desktop: 80, leaves[0]: 490, leaves[1]: 490, leaves[2]: 320])
    let before = tree
    let plain = serve(&tree, keyboard: nil, known: known)
    #expect(plain.windowFrames[notes] == nil && plain.windowFrames.count == 2)
    #expect(tree == before, "without the keyboard nobody pays with their place")

    let layout = serve(&tree, keyboard: notes, known: known)
    #expect(layout.windowFrames[notes]?.width == 700)
    #expect(layout.windowFrames[chat]?.width == 480, "the one docked last of the two")
    #expect(layout.windowFrames[mail] == nil)
    let settled = tree
    serve(&tree, keyboard: notes, known: known)
    #expect(tree == settled)

    // Whoever has the keyboard next finds the gaps where the person had put them.
    #expect(serve(&tree, keyboard: mail, known: known).windowFrames[mail]?.width == 490)
    expectSame(parts(of: tree.root, tree), parts(of: before.root, before))
  }

  /// A slot that the person's own hand has made short stays as they left it, whoever has the keyboard (T20).
  @Test func aSlotSqueezedByHandIsLeftAloneWhoeverHasTheKeyboard() throws {
    var tree = columns()
    serve(&tree, keyboard: chat)
    let before = tree
    var terms = MakeRoom.Terms(desktopIsInUse: false, keyboard: mail)
    terms.leaving = [try #require(tree.leaf(containing: mail))]
    let layout = MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { wide[$0] }, terms: terms
    ).layout
    #expect(layout.windowFrames[mail] == nil)
    #expect(tree == before)
  }

  /// [Mail over Chat | Desktop | Notes over Safari], neither column tall enough for both of its windows. Notes holds its place beside
  /// the tile of Safari, which is the newer. What was lent in that column could never help a window in the other.
  @Test func aColumnThatTheWindowIsNotInIsLeftAlone() throws {
    var known = tall
    known[notes] = CGSize(width: 300, height: 500)
    var tree = LayoutTree()
    let left = tree.dock(mail, beside: tree.root, edge: .left)
    tree.dock(chat, beside: left, edge: .bottom)
    let right = tree.dock(notes, beside: tree.root, edge: .right)
    tree.dock(safari, beside: right, edge: .bottom)
    var layout = serve(&tree, keyboard: notes, known: known)
    #expect(Set(layout.windowFrames.keys) == [chat, notes])
    let column = try #require(tree.parent(of: right))
    let before = parts(of: column, tree)

    layout = serve(&tree, keyboard: mail, known: known)
    #expect(Set(layout.windowFrames.keys) == [mail, notes])
    expectSame(parts(of: column, tree), before)
  }

  /// A row with the lengths `own`, of which `lent` then goes from the Desktop to each of the windows named.
  func row(_ own: [(WindowID?, Double)], lent: [WindowID: Double]) -> LayoutTree {
    var tree = LayoutTree()
    var lengths: [NodeID: Double] = [:]
    for (window, length) in own {
      lengths[window.map { tree.dock($0, beside: tree.root, edge: .right) } ?? tree.desktop] = length
    }
    tree.setShares(lengths)
    for (window, points) in lent.sorted(by: { $0.key < $1.key }) {
      let leaf = tree.leaf(containing: window)!
      lengths[leaf]! += points
      lengths[tree.desktop]! -= points
      tree.setShares([leaf: lengths[leaf]!, tree.desktop: lengths[tree.desktop]!], for: leaf)
    }
    return tree
  }

  /// [Desktop 100 | Chat 240 | Safari 500 | Mail 540]. The chat is a tile that the person's hand has made 240 points wide, and owes the
  /// Desktop 100 of them; Safari shows, on 200 of the Desktop's. Mail needs 200 more, which is what Safari gives back.
  @Test func aSlotSqueezedByHandGivesNothingBackForTheKeyboard() throws {
    let known = [chat: CGSize(width: 650, height: 400), safari: CGSize(width: 500, height: 300), mail: CGSize(width: 740, height: 400)]
    var tree = row([(nil, 400), (chat, 140), (safari, 300), (mail, 540)], lent: [chat: 100, safari: 200])
    let squeezed = try #require(tree.leaf(containing: chat))
    var terms = MakeRoom.Terms(desktopIsInUse: false, keyboard: mail)
    terms.leaving = [squeezed]
    let layout = MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] }, terms: terms
    ).layout
    #expect(layout.windowFrames[mail]?.width == 740)
    #expect(layout.windowFrames[safari] == nil)
    #expect(layout.nodeFrames[squeezed]?.width == 240, "as they left it")
  }

  /// [Desktop 392 | Safari 500 | Mail 500]. The ledger says that Safari owes 480 of its 500 points: more than leaves it a tile.
  @Test func nobodyIsLeftWithLessThanATileAndWhatCannotGoBackStaysOwed() throws {
    let known = [safari: CGSize(width: 500, height: 300), mail: CGSize(width: 1000, height: 400)]
    var tree = row([(nil, 872), (safari, 20), (mail, 500)], lent: [safari: 480])
    let slot = try #require(tree.leaf(containing: safari))
    let layout = serve(&tree, keyboard: mail, known: known)
    #expect(layout.windowFrames[mail]?.width == 1000)
    #expect(layout.windowFrames[safari] == nil)
    #expect(layout.nodeFrames[slot]?.width == 80)
    let owed = tree.loans.filter { $0.borrower == slot }.reduce(0) { $0 + $1.weight }
    let sum = tree.children(of: tree.root).reduce(0) { $0 + tree[$1]!.weight }
    #expect(abs(owed / sum * 1392 - 60) < 0.01, "\(tree.loans)")
  }

  /// Notes and the chat are both on the Desktop's room. Then Safari is docked below the chat, which puts the two into a column of their
  /// own: what the chat owes is between nodes that are no longer neighbours. It cannot go back now, and it is not forgotten.
  @Test func whatIsOwedBetweenNodesThatAreNoLongerNeighboursIsNotForgotten() throws {
    var known = [notes: CGSize(width: 709, height: 300), chat: CGSize(width: 574, height: 240)]
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .left)
    let upper = tree.dock(chat, beside: tree.root, edge: .right)
    #expect(serve(&tree, keyboard: nil, known: known).windowFrames.count == 2)
    let owed = tree.loans.filter { $0.borrower == upper }
    #expect(!owed.isEmpty)
    tree.dock(safari, beside: upper, edge: .bottom)
    #expect(tree.parent(of: upper) != tree.root)

    known[safari] = CGSize(width: 900, height: 240)
    let layout = serve(&tree, keyboard: safari, known: known)
    #expect(layout.windowFrames[safari]?.width == 900)
    #expect(layout.windowFrames[notes] == nil, "what was lent to Notes went back")
    #expect(tree.loans.filter { $0.borrower == upper && $0.receiver == upper } == owed)
  }

  /// [Mail over Desktop | Notes]. Notes stands on 7 points that the Desktop lent it while the two were neighbours; Mail, docked above the
  /// Desktop since, has put that into a column, so they cannot go back. And they would not be enough. Mail comes back out of the Dock
  /// with the keyboard, into a column 65 points too narrow for it.
  @Test func whereNothingThatWasLentCanGoBackTheNeighbourLends() throws {
    let known = [notes: CGSize(width: 709, height: 300), mail: CGSize(width: 760, height: 400)]
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .right)
    #expect(serve(&tree, keyboard: notes, known: known).windowFrames[notes]?.width == 709)
    tree.dock(mail, beside: tree.desktop, edge: .top)
    #expect(serve(&tree, keyboard: notes, known: known).windowFrames[mail] == nil, "in the background it is the tile")
    let layout = serve(&tree, keyboard: mail, known: known, givesBack: false)
    #expect(layout.windowFrames[mail]?.width == 760)
    #expect(layout.windowFrames[notes] == nil)
  }

  /// [Mail | Desktop | Chat over Notes], and Mail will not go below 1100 points: typed in, it leaves the column 212, which is too narrow
  /// for anything, so the column is one tile. A window in there is served like any other that has the keyboard.
  @Test func outOfTheTileOfAGroupToo() throws {
    let known = [mail: CGSize(width: 1100, height: 400), chat: CGSize(width: 400, height: 300), notes: CGSize(width: 400, height: 300)]
    var tree = LayoutTree()
    tree.dock(mail, beside: tree.root, edge: .left)
    let upper = tree.dock(chat, beside: tree.root, edge: .right)
    tree.dock(notes, beside: upper, edge: .bottom)
    let column = try #require(tree.parent(of: upper))
    var layout = serve(&tree, keyboard: chat, known: known)
    #expect(Set(layout.windowFrames.keys) == [chat, notes])
    let first = tree

    layout = serve(&tree, keyboard: mail, known: known)
    #expect(layout.windowFrames[mail]?.width == 1100)
    #expect(layout.tiles.contains { $0.node == column && $0.kind == .group })

    layout = serve(&tree, keyboard: chat, known: known)
    #expect(Set(layout.windowFrames.keys) == [chat, notes])
    expectSame(parts(of: tree.root, tree), parts(of: first.root, first))
    let settled = tree
    serve(&tree, keyboard: chat, known: known)
    #expect(tree == settled)
  }

  /// The same with the gaps put there by hand, so that nothing is owed: the column is grown until it is laid out again, then the window.
  @Test func outOfTheTileOfAGroupThatNothingWasLentFor() throws {
    let known = [mail: CGSize(width: 1100, height: 400), chat: CGSize(width: 500, height: 600), notes: CGSize(width: 400, height: 300)]
    var tree = LayoutTree()
    let left = tree.dock(mail, beside: tree.root, edge: .left)
    let upper = tree.dock(chat, beside: tree.root, edge: .right)
    tree.dock(notes, beside: upper, edge: .bottom)
    let column = try #require(tree.parent(of: upper))
    tree.setShares([left: 1100, tree.desktop: 80, column: 212])
    let theirs = tree
    #expect(serve(&tree, keyboard: mail, known: known).tiles.contains { $0.node == column && $0.kind == .group })
    #expect(tree == theirs)
    #expect(serve(&tree, keyboard: nil, known: known).windowFrames[mail] != nil, "without the keyboard nobody pays")
    #expect(tree == theirs)

    let layout = serve(&tree, keyboard: chat, known: known)
    #expect(layout.windowFrames[chat]?.size == CGSize(width: 500, height: 600))
    #expect(layout.windowFrames[mail] == nil)
    #expect(tree.loans.allSatisfy { $0.borrower == upper }, "\(tree.loans)")

    #expect(serve(&tree, keyboard: mail, known: known).windowFrames[mail]?.width == 1100)
    expectSame(parts(of: tree.root, tree), parts(of: theirs.root, theirs))
  }

  /// Notes has never refused a size, so Arbor does not know what it needs. It lends Mail its place and is a tile of 162 points, too small for
  /// any window. Typed in, it is back: that it is so small is Arbor's doing.
  @Test func aNeighbourThatLentItsPlaceComesBackThoughNothingIsKnownAboutIt() {
    let known = [mail: CGSize(width: 1150, height: 400)]
    var tree = LayoutTree()
    tree.dock(mail, beside: tree.root, edge: .left)
    tree.dock(notes, beside: tree.root, edge: .right)
    let first = tree
    #expect(serve(&tree, keyboard: notes, known: known).windowFrames[notes]?.width == 464)
    #expect(tree == first)
    var layout = serve(&tree, keyboard: mail, known: known)
    #expect(layout.windowFrames[mail]?.width == 1150)
    #expect(layout.windowFrames[notes] == nil)
    layout = serve(&tree, keyboard: notes, known: known)
    #expect(layout.windowFrames[notes]?.width == 464)
    #expect(layout.windowFrames[mail] == nil)
    expectSame(parts(of: tree.root, tree), parts(of: first.root, first))
  }

  /// Six columns on 1440 points are 220 each, too small for any window, and nobody made them so but the person. As ever, they are tiles.
  @Test func aSlotTooSmallForAnyWindowIsLeftAloneWhereNothingIsKnownAndNothingWasLent() {
    var tree = LayoutTree()
    let windows = (1...5).map { WindowID(UInt32($0)) }
    for window in windows { tree.dock(window, beside: tree.root, edge: .right) }
    let before = tree
    #expect(serve(&tree, keyboard: windows[2], known: [:]).windowFrames.isEmpty)
    #expect(tree == before)
  }

  // MARK: Anything

  /// Whatever the arrangement, the minimums and whoever has the keyboard.
  @Test func anyTreeAnyMinimumsAnyKeyboard() {
    let (exceptions, missed) = walk(0..<1500)
    #expect(exceptions > 20, "the walk has to meet what it is about: \(exceptions)")
    #expect(missed <= 12, "beside a group that cannot shrink any further it is still the tile; that has become more common: \(missed)")
  }

  /// Found by longer walks than the one above, each with one thing taken out of `MakeRoom`: twelve rounds (debts in a circle); a group laid
  /// out again large enough for all that is in it; the tile of a group giving like a window's; a layout after each loan that goes back.
  @Test(arguments: [
    13951, 33480, 37293, 42820, 55008, 57915,
    4388, 49686, 59304,
    5560, 11163, 16693,
    35037,
  ]) func roundsThatOnceBrokeARule(round: Int) {
    _ = walk(round..<(round + 1))
  }

  /// Each round is seeded with its number, so that one can be played again by itself. Returns in how many somebody paid with their place
  /// for the window with the keyboard, and in how many it was the tile though there would have been room.
  func walk(_ rounds: Range<Int>) -> (exceptions: Int, missed: Int) {
    var state: UInt64 = 0
    func random(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    var exceptions = 0
    var missed = 0
    for round in rounds {
      state = 0x61_2026 &+ UInt64(round) &* 0x9E37_79B9_7F4A_7C15
      _ = random(2)
      var tree = LayoutTree()
      let windows = (1...(2 + random(5))).map { WindowID(UInt32($0)) }
      var known: [WindowID: CGSize] = [:]
      for window in windows {
        let nodes = tree.preorder()
        tree.dock(window, beside: nodes[random(nodes.count)], edge: Edge.allCases[random(4)])
        if random(4) > 0 { known[window] = CGSize(width: 200 + random(14) * 50, height: 150 + random(10) * 50) }
      }
      func lay(_ tree: inout LayoutTree, keyboard: WindowID?, camera: NodeID) -> Layout {
        MakeRoom.serve(
          &tree, camera: camera, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] },
          terms: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard)
        ).layout
      }
      // A few layouts with the keyboard here and there, so that there is something in the ledger.
      for _ in 0..<(1 + random(3)) { _ = lay(&tree, keyboard: windows[random(windows.count)], camera: tree.root) }
      let splits = tree.preorder().filter(tree.isSplit)
      let camera = random(3) == 0 ? splits[random(splits.count)] : tree.root
      let keyboard = windows[random(windows.count)]
      let before = tree
      let shown = LayoutEngine.layout(
        tree, camera: camera, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] })
      let after = lay(&tree, keyboard: keyboard, camera: camera)
      let story = "round \(round), keyboard \(keyboard), camera \(camera)"

      #expect(tree.invariantViolations().isEmpty, "\(story)")
      for id in tree.preorder() where tree.isSplit(id) {
        let (was, now) = (before.children(of: id).reduce(0) { $0 + before[$1]!.weight }, tree.children(of: id).reduce(0) { $0 + tree[$1]!.weight })
        #expect(abs(was - now) < 1e-9, "weight moves, none is made: \(story)")
      }
      // Out of view nothing changes.
      for id in tree.preorder() where [shown, after].allSatisfy({ $0.nodeFrames[id] == nil && $0.nodeFrames[tree.parent(of: id) ?? id] == nil }) {
        #expect(tree[id]!.weight == before[id]!.weight, "\(id) is out of view: \(story)")
      }
      let losers = shown.windowFrames.keys.filter { after.windowFrames[$0] == nil }.sorted()
      if !losers.isEmpty {
        exceptions += 1
        #expect(shown.windowFrames[keyboard] == nil && after.windowFrames[keyboard] != nil, "\(losers) paid for nothing: \(story)")
      }
      // It is the tile only if it fits nowhere: not even with everybody beside it as small as a tile goes. (Asked only where nothing is
      // smaller than that to begin with: what follows would count on it, and the window is served from the gaps without the loans.)
      let cramped = shown.nodeFrames.values.contains { $0.width < 80 || $0.height < 80 }
      // A window that Arbor knows nothing about is left in a slot too small for any window, unless it is so small because it has lent room
      // (and still is once that has gone back: then the person's own gaps leave it no more).
      let lent = tree.loans.contains { tree.subtree($0.giver, contains: tree.leaf(containing: keyboard)!) }
      if !cramped, known[keyboard] != nil || lent, after.windowFrames[keyboard] == nil,
        after.tiles.contains(where: { $0.windows.contains(keyboard) })
      {
        let minimum = known[keyboard] ?? CGSize(width: 240, height: 160)
        var alone = before
        let others = windows.filter { $0 != keyboard }
        let roomiest = MakeRoom.serve(
          &alone, camera: camera, in: screen, options: LayoutOptions(), isPresent: { _ in true },
          minimumSize: { $0 == keyboard ? minimum : others.contains($0) ? CGSize(width: 10_000, height: 10_000) : nil },
          terms: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard)
        ).layout
        if roomiest.windowFrames[keyboard] != nil {
          // The one case known. A group shrinks in proportion, so only as far as the smallest in it is still as large as a tile: a column
          // (or a row of columns) beside the window gives less height than its windows have between them.
          func runs(_ id: NodeID, along axis: Axis) -> Bool {
            guard case .split(let direction, let children) = tree[id]?.kind else { return false }
            return (direction == axis && children.count > 1) || children.contains { runs($0, along: axis) }
          }
          var besideSuchAGroup = false
          var current = tree.leaf(containing: keyboard)!
          while current != after.camera, let parent = tree.parent(of: current) {
            if case .split(let axis, let children) = tree[parent]?.kind, children.contains(where: { $0 != current && runs($0, along: axis) }) {
              besideSuchAGroup = true
            }
            current = parent
          }
          #expect(besideSuchAGroup, "there was room for it: \(story)")
          missed += 1
        }
      }
      for (id, frame) in after.nodeFrames {
        // Nothing becomes smaller than a tile goes, 80 points, give or take what the engine itself does: a group is laid out from the
        // smallest usable size on, where three in a row have (240 - 24) / 3 = 72 each; and boundaries are whole points, so what is smaller
        // already can lose one more. What was inside the tile of a group had no size before.
        let was = shown.nodeFrames[id]?.size ?? CGSize(width: 80, height: 80)
        #expect(frame.width >= min(was.width - 1, 72) && frame.height >= min(was.height - 1, 72), "\(id) is \(frame.size): \(story)")
      }
      let settled = tree
      _ = lay(&tree, keyboard: keyboard, camera: camera)
      #expect(tree == settled, "another layout finds nothing to do: \(story)")
    }
    return (exceptions, missed)
  }

  // MARK: Rehearsals

  /// [Notes | Desktop | Mail], Mail on 136 points of the Desktop's. The chat has the keyboard and is held over the lower half of Notes.
  /// Its slot is made by the drop, so no tree has it yet when the terms are written: not if it floats, and not if it is docked
  /// somewhere else, because a window that moves gets a new slot.
  @Test(arguments: [false, true]) func aPreviewServesTheWindowInTheHandAsTheDropWill(dockedAlready: Bool) throws {
    let known = [mail: CGSize(width: 600, height: 400), chat: CGSize(width: 760, height: 500)]
    var workspace = Workspace()
    workspace.undock(chat, floatingAt: CGRect(x: 300, y: 100, width: 800, height: 520))
    workspace.dock(notes, at: .cameraEdge(.left))
    workspace.dock(mail, at: .cameraEdge(.right))
    #expect(serve(&workspace.tree, keyboard: chat, known: known).windowFrames[mail]?.width == 600)
    if dockedAlready {
      workspace.dock(chat, at: .beside(try #require(workspace.tree.leaf(containing: mail)), .bottom))
      #expect(serve(&workspace.tree, keyboard: notes, known: known).windowFrames[chat] == nil)
    }
    let target = DropTarget.beside(try #require(workspace.tree.leaf(containing: notes)), .bottom)

    func preview(keyboard: WindowID?) -> CGRect? {
      workspace.previewFrame(
        for: chat, at: target, in: screen, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] },
        makingRoom: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard))
    }
    var dropped = workspace
    dropped.dock(chat, at: target)
    let landed = try #require(serve(&dropped.tree, keyboard: chat, known: known).windowFrames[chat])
    #expect(landed.size == CGSize(width: 760, height: 500))
    #expect(preview(keyboard: chat) == landed)
    // Carried with ⌘ a window stays in the background: it is served like any other, and is the tile.
    #expect(preview(keyboard: notes)?.width == 464)
  }
}
