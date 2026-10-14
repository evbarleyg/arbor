import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let notes = WindowID(1)
private let safari = WindowID(2)
private let mail = WindowID(3)
private let minimums = [
  notes: CGSize(width: 709, height: 300), safari: CGSize(width: 574, height: 240), mail: CGSize(width: 864, height: 525),
]

/// Room that was made for a window goes back where it came from (F61, LayoutTree+Loans.swift).
@Suite struct LoanTests {
  @discardableResult
  func serve(_ tree: inout LayoutTree, in frame: CGRect = screen, known: [WindowID: CGSize] = minimums) -> Layout {
    MakeRoom.serve(
      &tree, camera: tree.root, in: frame, options: LayoutOptions(), isPresent: { _ in true }, minimumSize: { known[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false)
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

  /// [Notes | Desktop | Safari], both served: 709, 109, 574.
  func served() -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .left)
    tree.dock(safari, beside: tree.root, edge: .right)
    let layout = serve(&tree)
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

  @Test func aColumnThatGrewForAWindowInItShrinksAgainWhenThatWindowLeaves() throws {
    var tree = LayoutTree()
    let first = tree.dock(safari, beside: tree.root, edge: .left)
    expectParts(tree, [0.5, 0.5])
    tree.dock(mail, beside: first, edge: .bottom)
    #expect(serve(&tree).windowFrames[mail]!.width == 864)
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

  @Test func framedOnItsOwnAWindowGivesNothingBack() throws {
    var tree = served()
    let before = tree
    for window in [notes, safari] {
      _ = MakeRoom.serve(
        &tree, camera: try #require(tree.leaf(containing: window)), in: screen, options: LayoutOptions(), isPresent: { _ in true },
        minimumSize: { minimums[$0] }, terms: MakeRoom.Terms(desktopIsInUse: false))
      #expect(tree == before, "it has the whole display, which says nothing about what it can spare beside the others")
    }
  }

  @Test func aWindowNothingIsKnownAboutGivesNothingBack() {
    // After a launch: what it can spare could only be found out by asking it.
    var tree = served()
    let before = tree
    serve(&tree, in: CGRect(x: 0, y: 25, width: 1920, height: 1055), known: [:])
    #expect(tree == before)
  }

  @Test func aGapThatAPersonHasMovedIsTheirs() throws {
    var tree = served()
    let leaf = try #require(tree.leaf(containing: notes))
    tree.moveBoundary(leading: leaf, trailing: tree.desktop, by: 10, pointsPerWeight: 464)
    let moved = parts(tree)
    tree.remove(safari)
    // Safari's own loan went back to the Desktop; what Notes had from it stays where the person's hand left it.
    #expect(parts(tree)[0] / parts(tree)[1] < moved[0] / moved[1])
    #expect(!tree.hasLoans)
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
