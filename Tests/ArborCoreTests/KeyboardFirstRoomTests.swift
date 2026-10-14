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

  /// The limit: only what Arbor lent goes back. A gap that a person has moved is theirs, so nothing is owed across it.
  @Test func aGapThatAPersonHasMovedDoesNotGoBack() throws {
    var tree = columns()
    serve(&tree, keyboard: chat)
    tree.moveBoundary(leading: tree.desktop, trailing: try #require(tree.leaf(containing: chat)), by: -10, pointsPerWeight: 464)
    #expect(!tree.hasLoans)
    let before = tree
    let layout = serve(&tree, keyboard: mail)
    #expect(layout.windowFrames[mail] == nil)
    #expect(layout.windowFrames[chat]?.width == 770)
    #expect(tree == before)
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

  // MARK: Anything

  /// Seeded, so a failure can be played again. Whatever the arrangement, the minimums and whoever has the keyboard.
  @Test func anyTreeAnyMinimumsAnyKeyboard() {
    var state: UInt64 = 0x61_2026
    func random(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    var exceptions = 0
    for round in 0..<1500 {
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
      let leaf = tree.leaf(containing: keyboard)!
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
      for id in tree.preorder() where after.nodeFrames[id] == nil && after.nodeFrames[tree.parent(of: id) ?? id] == nil {
        #expect(tree[id]!.weight == before[id]!.weight, "\(id) is out of view: \(story)")
      }
      let losers = shown.windowFrames.keys.filter { after.windowFrames[$0] == nil }.sorted()
      if !losers.isEmpty {
        exceptions += 1
        #expect(shown.windowFrames[keyboard] == nil && after.windowFrames[keyboard] != nil, "\(losers) paid for nothing: \(story)")
        // Whoever pays was on lent room, in a row or column that the window with the keyboard is in.
        var path: Set<NodeID> = []
        var current = leaf
        while current != after.camera, let parent = tree.parent(of: current) {
          path.insert(parent)
          current = parent
        }
        let lent = before.loans.filter { before.parent(of: $0.receiver).map(path.contains) == true }
        for loser in losers {
          #expect(lent.contains { before.subtree($0.receiver, contains: before.leaf(containing: loser)!) }, "\(loser) was on its own room: \(story)")
        }
      }
      for (id, frame) in after.nodeFrames {
        guard let was = shown.nodeFrames[id] else { continue }
        #expect(frame.width >= min(was.width, 80) - 0.5 && frame.height >= min(was.height, 80) - 0.5, "\(id) is \(frame.size): \(story)")
      }
      let settled = tree
      _ = lay(&tree, keyboard: keyboard, camera: camera)
      #expect(tree == settled, "another layout finds nothing to do: \(story)")
    }
    #expect(exceptions > 20, "the walk has to meet what it is about: \(exceptions)")
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
