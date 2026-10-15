import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let notes = WindowID(1)
private let safari = WindowID(2)
private let mail = WindowID(3)
/// Two of which nothing is known.
private let plain = WindowID(4)
private let other = WindowID(5)
private let wide = CGRect(x: 0, y: 25, width: 2560, height: 1415)
private let minimums = [
  notes: CGSize(width: 709, height: 300), safari: CGSize(width: 574, height: 240), mail: CGSize(width: 864, height: 525),
]

/// Room that was made for a window goes back where it came from (F61, LayoutTree+Loans.swift).
@Suite struct LoanTests {
  /// With a column for the Desktop unless told otherwise: it is the Desktop between two windows that lends here, and is owed.
  @discardableResult
  func serve(
    _ tree: inout LayoutTree, in frame: CGRect = screen, known: [WindowID: CGSize] = minimums, leaving: Set<NodeID> = [],
    desktopColumn: Bool = true
  ) -> Layout {
    MakeRoom.serve(
      &tree, camera: tree.root, in: frame, options: LayoutOptions(desktopColumn: desktopColumn), isPresent: { _ in true },
      minimumSize: { known[$0] }, terms: MakeRoom.Terms(desktopIsInUse: false, leaving: leaving)
    ).layout
  }

  /// The weights of the root's children, as parts of their sum.
  func parts(_ tree: LayoutTree) -> [Double] {
    let weights = tree.children(of: tree.root).map { tree[$0]!.weight }
    return weights.map { $0 / weights.reduce(0, +) }
  }

  func expectParts(_ tree: LayoutTree, _ expected: [Double], sourceLocation: SourceLocation = #_sourceLocation) {
    let parts = parts(tree)
    #expect(parts.count == expected.count, sourceLocation: sourceLocation)
    for (part, wanted) in zip(parts, expected) { #expect(abs(part - wanted) < 1e-9, "\(parts)", sourceLocation: sourceLocation) }
  }

  /// [Notes | Desktop | Safari], both served: 709, 109, 574. Without a column for the Desktop [Notes | Safari]: 709 and 695.
  func served(desktopColumn: Bool = true) -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    tree.dock(safari, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    let layout = serve(&tree, desktopColumn: desktopColumn)
    #expect(layout.windowFrames.count == 2)
    #expect(tree.hasLoans)
    return tree
  }

  @Test(arguments: [[notes, safari], [safari, notes]]) func whoeverLeavesFirstTheRestIsAsIfNoRoomHadBeenMade(order: [WindowID]) {
    var tree = served()
    tree.remove(order[0])
    // What the one that stays can spare by now goes back too: it has half the display.
    serve(&tree)
    if order[0] == notes { expectParts(tree, [0.5, 0.5]) } else { #expect(serve(&tree).windowFrames[notes]!.width == 709) }
    tree.remove(order[1])
    #expect(!tree.hasLoans)
  }

  @Test(arguments: [true, false])
  func aColumnThatGrewForAWindowInItShrinksAgainWhenThatWindowLeaves(desktopColumn: Bool) throws {
    var tree = LayoutTree()
    let first = tree.dock(safari, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    expectParts(tree, [0.5, 0.5])
    tree.dock(mail, beside: first, edge: .bottom, desktopColumn: desktopColumn)
    #expect(serve(&tree, desktopColumn: desktopColumn).windowFrames[mail]!.width == 864)
    #expect(parts(tree)[0] > 0.6)
    tree.remove(mail)
    expectParts(tree, [0.5, 0.5])
    #expect(!tree.hasLoans)
  }

  @Test func onALargerDisplayWhatCanBeSparedGoesBackAndOnTheSmallerOneItIsTakenAgain() {
    var tree = served()
    let small = tree
    let large = CGRect(x: 0, y: 25, width: 1920, height: 1055)
    let layout = serve(&tree, in: large)
    #expect(layout.windowFrames[notes]!.width == 709, "a third is 624: it still needs 85 of the Desktop's")
    #expect(layout.windowFrames[safari]!.width == 624, "a third, as the person left it")
    #expect(layout.desktopFrame?.width == 539)
    let again = serve(&tree)
    #expect(again.windowFrames[notes]!.width == 709 && again.windowFrames[safari]!.width == 574)
    for (now, then) in zip(parts(tree), parts(small)) { #expect(abs(now - then) < 1e-9) }
  }

  @Test(arguments: [true, false]) func framedOnItsOwnAWindowGivesNothingBack(desktopColumn: Bool) throws {
    var tree = served(desktopColumn: desktopColumn)
    let before = tree
    for window in [notes, safari] {
      _ = MakeRoom.serve(
        &tree, camera: try #require(tree.leaf(containing: window)), in: screen, options: LayoutOptions(desktopColumn: desktopColumn),
        isPresent: { _ in true }, minimumSize: { minimums[$0] }, terms: MakeRoom.Terms(desktopIsInUse: false))
      #expect(tree == before, "it has the whole display, which says nothing about what it can spare beside the others")
    }
  }

  @Test(arguments: [true, false]) func aWindowNothingIsKnownAboutGivesNothingBack(desktopColumn: Bool) {
    // After a launch: what it can spare could only be found out by asking it.
    var tree = served(desktopColumn: desktopColumn)
    let before = tree
    serve(&tree, in: CGRect(x: 0, y: 25, width: 1920, height: 1055), known: [:], desktopColumn: desktopColumn)
    #expect(tree == before)
  }

  @Test func aGapThatAPersonHasMovedIsTheirs() throws {
    var tree = served()
    let leaf = try #require(tree.leaf(containing: notes))
    tree.moveBoundary(leading: leaf, trailing: tree.desktop, by: 10, pointsPerWeight: 464)
    let moved = parts(tree)
    // How wide the Desktop is has been settled with it: what it is owed by Safari, on its other side, is forgotten as well
    // (decided by the product owner on 2026-10-15; until then Safari's loan went back to it).
    #expect(!tree.hasLoans)
    tree.remove(safari)
    // What Safari had is shared out as any window's is, and the gap is where the person's hand left it, in proportion.
    #expect(abs(parts(tree)[0] / parts(tree)[1] - moved[0] / moved[1]) < 1e-9)
  }

  // MARK: What a hand has made longer or shorter owes nothing

  private func seam(_ layout: Layout, _ leading: NodeID?, _ trailing: NodeID?) throws -> Seam {
    try #require(layout.seams.first { $0.leading == leading && $0.trailing == trailing })
  }

  /// [plain | Notes | Desktop]: Notes stands at its 709 on what the Desktop lent it, on the side away from `plain`. (With a column for the
  /// Desktop: it has to have a share to lend of.)
  func lentFromTheFarSide() -> (LayoutTree, Layout) {
    var tree = LayoutTree()
    let first = tree.dock(plain, beside: tree.root, edge: .left)
    tree.dock(notes, beside: first, edge: .right, desktopColumn: true)
    let layout = serve(&tree)
    #expect(layout.windowFrames[notes]?.width == 709)
    #expect(tree.hasLoans)
    return (tree, layout)
  }

  @Test func thePointsAHandGaveAreNotPointsToSpare() throws {
    var (tree, layout) = lentFromTheFarSide()
    tree.moveBoundary(at: try seam(layout, tree.leaf(containing: plain), tree.leaf(containing: notes)), by: -60)
    let left = tree
    #expect(serve(&tree).windowFrames[notes]?.width == 769)
    #expect(tree == left, "the gap on its far side, which nobody touched, is where it was")
    #expect(!tree.hasLoans)
  }

  @Test func aWindowSqueezedIntoATileByHandDoesNotPayAsATilePays() throws {
    var (tree, layout) = lentFromTheFarSide()
    let leaf = try #require(tree.leaf(containing: notes))
    tree.moveBoundary(at: try seam(layout, tree.leaf(containing: plain), leaf), by: 100)
    let left = tree
    let after = serve(&tree, leaving: [leaf])
    #expect(after.nodeFrames[leaf]?.width == 609, "as wide as the hand left it")
    #expect(tree == left)
  }

  /// [Desktop over (plain | Notes)]. The gap that is moved is the one above the row: no width has changed, and the loan of width stands.
  @Test func squeezedInHeightItKeepsTheWidthItWasLent() throws {
    var tree = LayoutTree()
    let first = tree.dock(plain, beside: tree.root, edge: .bottom)
    let leaf = tree.dock(notes, beside: first, edge: .right)
    let layout = serve(&tree)
    #expect(layout.windowFrames[notes]?.width == 709)
    tree.moveBoundary(at: try seam(layout, tree.desktop, tree.parent(of: leaf)), by: 150)
    #expect(tree.hasLoans)
    let left = tree
    let after = serve(&tree, leaving: [leaf])
    #expect(after.tiles.contains { $0.node == leaf }, "under its 300 points of height")
    #expect(after.nodeFrames[leaf]?.width == 709, "as a tile it could spare all but 240 of them")
    #expect(tree == left)
  }

  @Test func whatAColumnOwesFromTopToBottomItGoesOnOwingWhenItIsMadeWider() throws {
    var tree = LayoutTree()
    let first = tree.dock(safari, beside: tree.root, edge: .left)
    tree.dock(mail, beside: first, edge: .bottom)
    let layout = serve(&tree)
    #expect(layout.windowFrames[mail]?.size == CGSize(width: 864, height: 525), "wider than half, and taller")
    tree.moveBoundary(at: try seam(layout, tree.parent(of: first), tree.desktop), by: 40)
    #expect(tree.hasLoans, "no height has changed")
    let left = tree
    #expect(serve(&tree).windowFrames[mail]?.size == CGSize(width: 904, height: 525))
    #expect(tree == left)
  }

  /// [(plain | Notes) over Safari | Desktop]. The column is made wider, and all that is in it with it.
  @Test func whatIsInsideAGroupThatAHandMadeWiderOwesNothingAlongTheRowEither() throws {
    var tree = LayoutTree()
    let first = tree.dock(plain, beside: tree.root, edge: .left)
    tree.dock(safari, beside: first, edge: .bottom)
    tree.dock(notes, beside: first, edge: .right)
    let layout = serve(&tree)
    #expect(layout.windowFrames[notes]?.width == 709)
    #expect(layout.windowFrames[plain]?.width == 240, "it gave what it could, the Desktop the rest")
    let column = try #require(tree.children(of: tree.root).first { $0 != tree.desktop })
    tree.moveBoundary(at: try seam(layout, column, tree.desktop), by: 100)
    let left = tree
    #expect(try #require(serve(&tree).windowFrames[notes]).width > 709)
    #expect(tree == left, "the gap between the two is where it was when the hand let go")
  }

  /// The same, and the gap that is moved is the one inside, between the two. The column has not changed its width, but it has what it
  /// has for the sake of Notes, and how wide Notes is has been settled by hand.
  @Test(arguments: [40.0, 150]) func whatAGroupWasLentForTheSakeOfAWindowThatAHandHasResizedIsForgottenToo(points: Double) throws {
    var tree = LayoutTree()
    let first = tree.dock(plain, beside: tree.root, edge: .left)
    tree.dock(safari, beside: first, edge: .bottom)
    let leaf = tree.dock(notes, beside: first, edge: .right)
    // Of `plain`, too, Arbor knows how small it goes: so it knows what the row of the two can spare.
    let known = minimums.merging([plain: CGSize(width: 200, height: 200)]) { $1 }
    let layout = serve(&tree, known: known)
    #expect(layout.windowFrames[notes]?.width == 709)
    tree.moveBoundary(at: try seam(layout, first, leaf), by: points)
    let left = tree
    let after = serve(&tree, known: known, leaving: [leaf])
    #expect(after.nodeFrames[leaf]?.width == CGFloat(709 - points), "the tile they asked for, as wide as they left it")
    #expect(tree == left)
  }

  /// `[ plain | (Safari, Notes) | other | Desktop ]` on a wide display, the pair kept (F62): it looks like part of the row.
  func rowWithAKeptPair(notesLast: Bool) -> (LayoutTree, Layout, pair: NodeID) {
    var tree = LayoutTree()
    tree.dock(other, beside: tree.root, edge: .left)
    let inPair = tree.dock(notesLast ? safari : notes, beside: tree.root, edge: .left)
    tree.dock(plain, beside: tree.root, edge: .left)
    tree.dock(notesLast ? notes : safari, beside: inPair, edge: .right, groupingFor: .name)
    let layout = serve(&tree, in: wide, known: [notes: minimums[notes]!])
    #expect(layout.windowFrames[notes]?.width == 709)
    return (tree, layout, tree.parent(of: inPair)!)
  }

  @Test func theWindowAtTheEndOfAKeptGroupThatAHandMadeWiderStaysWider() throws {
    var (tree, layout, pair) = rowWithAKeptPair(notesLast: true)
    tree.moveBoundary(at: try seam(layout, pair, tree.leaf(containing: other)), by: 60)
    let left = tree
    #expect(serve(&tree, in: wide, known: [notes: minimums[notes]!]).windowFrames[notes]?.width == 769)
    #expect(tree == left)
  }

  /// `[ plain | (third, Notes, Safari) | other | Desktop ]`: Safari, at the end, is made wider. Notes and the third are as they were. But what
  /// the group was lent for the sake of Notes is forgotten, and what Safari lent it: so is what the third lent it. All or nothing: of a
  /// debt that is half forgotten, one lender would be paid when Notes leaves and the other not.
  @Test func whatIsForgottenOfABorrowersDebtsIsForgottenWhollyAndTheOthersInAKeptGroupStayAsTheyWere() throws {
    var (tree, _, pair) = rowWithAKeptPair(notesLast: false)
    let third = WindowID(6)
    tree.dock(third, beside: try #require(tree.leaf(containing: notes)), edge: .left)
    #expect(tree.windows(under: pair) == [third, notes, safari])
    tree.setShares(tree.children(of: pair).reduce(into: [:]) { $0[$1] = 1 })
    let known = [notes: CGSize(width: 800, height: 300)]
    let layout = serve(&tree, in: wide, known: known)
    #expect(layout.windowFrames[notes]?.width == 800)
    #expect(layout.windowFrames[third]?.width == layout.windowFrames[safari]?.width)
    tree.moveBoundary(at: try seam(layout, pair, tree.leaf(containing: other)), by: 60)
    #expect(!tree.hasLoans)
    let left = tree
    let after = serve(&tree, in: wide, known: known)
    #expect(after.windowFrames[notes]?.width == 800)
    #expect(after.windowFrames[third] == layout.windowFrames[third])
    #expect(tree == left)
    tree.remove(notes)
    let without = serve(&tree, in: wide, known: known)
    #expect(try #require(without.windowFrames[safari]).width > (try #require(without.windowFrames[third]).width), "the one the hand made wider is the wider")
  }

  /// [Notes | plain | Desktop | Safari] on a wide display, where the Desktop can lend to both and stay a Desktop: the gap between Notes and its
  /// neighbour says nothing about what the Desktop lent to Safari.
  @Test func anotherBorrowersDebtsOnOneSideOfTheGapStand() throws {
    let known = [notes: CGSize(width: 800, height: 300), safari: CGSize(width: 700, height: 240)]
    var tree = LayoutTree()
    tree.dock(plain, beside: tree.root, edge: .left)
    tree.dock(notes, beside: tree.root, edge: .left, desktopColumn: true)
    tree.dock(safari, beside: tree.root, edge: .right, desktopColumn: true)
    let layout = serve(&tree, in: wide, known: known)
    #expect(layout.windowFrames[notes]?.width == 800 && layout.windowFrames[safari]?.width == 700 && layout.desktopFrame != nil)
    tree.moveBoundary(at: try seam(layout, tree.leaf(containing: notes), tree.leaf(containing: plain)), by: 10)
    #expect(tree.hasLoans)
    let left = tree
    serve(&tree, in: wide, known: known)
    #expect(tree == left)
    let before = parts(tree)
    tree.remove(safari)
    #expect(!tree.hasLoans)
    #expect(parts(tree)[2] / parts(tree)[0] > before[2] / before[0], "what the Desktop lent to Safari is back")
  }

  /// [(Safari over Mail) | Desktop]: the column was lent width for the sake of Mail. Mail is squeezed in height.
  @Test func squeezedInHeightTheColumnItIsInKeepsTheWidthItWasLentForItsSake() throws {
    var tree = LayoutTree()
    let first = tree.dock(safari, beside: tree.root, edge: .left)
    let leaf = tree.dock(mail, beside: first, edge: .bottom)
    let layout = serve(&tree)
    #expect(layout.windowFrames[mail]?.size == CGSize(width: 864, height: 525))
    tree.moveBoundary(at: try seam(layout, first, leaf), by: 150)
    let left = tree
    let after = serve(&tree, leaving: [leaf])
    #expect(after.tiles.contains { $0.node == leaf })
    #expect(after.nodeFrames[leaf]?.width == 864, "Safari alone would do with 574")
    #expect(tree == left)
  }

  /// The mark outlives the tile: a neighbour has left, and the slot is large enough again. Then it pays back like anybody.
  @Test func aSlotThatWasSqueezedAndIsAWindowAgainPaysBackWhatItCanSpare() {
    var tree = served()
    let leaf = tree.leaf(containing: notes)!
    let layout = serve(&tree, in: CGRect(x: 0, y: 25, width: 1920, height: 1055), leaving: [leaf])
    #expect(layout.windowFrames[notes]?.width == 709, "a third is 624: it still needs 85 of the Desktop's, and no more")
  }

  /// Arbor moves a gap for ends of its own (a Desktop kept usable at a dock). Nobody has settled anything.
  @Test func aGapThatArborMovesItselfForgetsOnlyWhatWasLentAcrossIt() throws {
    var (tree, layout) = lentFromTheFarSide()
    tree.moveBoundary(at: try seam(layout, tree.leaf(containing: plain), tree.leaf(containing: notes)), by: -60, byHand: false)
    #expect(tree.hasLoans)
    #expect(serve(&tree).windowFrames[notes]?.width == 709, "what it can spare goes back to the Desktop")
  }

  /// At its limit a gap does not move, however far the hand goes: nothing has been decided.
  @Test func aGapThatDidNotMoveSettlesNothing() throws {
    var tree = LayoutTree()
    let first = tree.dock(plain, beside: tree.root, edge: .left)
    let leaf = tree.dock(notes, beside: first, edge: .right, desktopColumn: true)
    let known = [notes: CGSize(width: 1000, height: 300)]
    let layout = serve(&tree, known: known)
    #expect(layout.nodeFrames[tree.desktop]?.width == 80, "as far as a gap can be dragged")
    tree.moveBoundary(at: try seam(layout, leaf, tree.desktop), by: 50)
    #expect(serve(&tree, known: known).nodeFrames == layout.nodeFrames)
    tree.remove(notes)
    expectParts(tree, [0.5, 0.5])
  }

  @Test func theLedgerIsSavedAndNonsenseInItIsHarmless() throws {
    let tree = served()
    let data = try JSONEncoder().encode(tree)
    var loaded = try JSONDecoder().decode(LayoutTree.self, from: data)
    #expect(loaded == tree)
    loaded.remove(notes)
    serve(&loaded)
    expectParts(loaded, [0.5, 0.5])

    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["loans"] = [
      ["borrower": 999, "giver": 0, "receiver": 1, "weight": 5], ["borrower": 1, "giver": 0, "receiver": 1, "weight": -3],
      ["borrower": 1, "giver": 1, "receiver": 1, "weight": 1e300],
    ]
    var odd = try JSONDecoder().decode(LayoutTree.self, from: JSONSerialization.data(withJSONObject: object))
    odd.remove(notes)
    odd.remove(safari)
    #expect(odd.invariantViolations().isEmpty)
    #expect(odd.preorder().allSatisfy { odd[$0]!.weight.isFinite && odd[$0]!.weight > 0 })

    object["loans"] = "nonsense"
    #expect(throws: Never.self) { try JSONDecoder().decode(LayoutTree.self, from: JSONSerialization.data(withJSONObject: object)) }
    object["loans"] = nil
    #expect(try JSONDecoder().decode(LayoutTree.self, from: JSONSerialization.data(withJSONObject: object)).hasLoans == false)
  }
}
