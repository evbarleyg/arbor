import ArborCore
import CoreGraphics
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let notes = WindowID(1)
private let safari = WindowID(2)
private let mail = WindowID(3)
private let minimums = [notes: CGSize(width: 709, height: 300), safari: CGSize(width: 574, height: 240)]

/// LayoutTree+Gaps.swift.
@Suite struct GapsTests {
  private func serve(_ tree: inout LayoutTree, without absent: WindowID? = nil) {
    _ = MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: LayoutOptions(), isPresent: { $0 != absent },
      minimumSize: { minimums[$0] }, terms: MakeRoom.Terms(desktopIsInUse: false))
  }

  /// [Notes | Desktop | Safari], with room made for both.
  private func served() -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(notes, beside: tree.root, edge: .left)
    tree.dock(safari, beside: tree.root, edge: .right)
    serve(&tree)
    #expect(tree.hasLoans)
    return tree
  }

  @Test func theWeightsAndWhatIsOwedForThemComeOver() {
    let stood = served()
    var tree = stood
    // With Notes away Safari can spare what it was lent, and gives it back.
    serve(&tree, without: notes)
    #expect(tree != stood)
    tree.takeGaps(from: stood)
    #expect(tree == stood)
  }

  @Test func whichTabShowsStays() throws {
    var stood = served()
    stood.addToStack(mail, leaf: try #require(stood.leaf(containing: safari)))
    var tree = stood
    tree.activate(safari)
    serve(&tree, without: notes)
    let showing = tree
    tree.takeGaps(from: stood)
    #expect(tree.hasSameArrangement(as: stood))
    #expect(tree[try #require(tree.leaf(containing: safari))]?.kind == showing[try #require(showing.leaf(containing: safari))]?.kind)
    #expect(tree != stood)
  }

  @Test func fromATreeWithOtherNodesNothingIsTaken() {
    let stood = served()
    var docked = stood
    docked.dock(mail, beside: docked.root, edge: .right)
    let before = docked
    docked.takeGaps(from: stood)
    #expect(docked == before)

    var closed = stood
    closed.remove(notes)
    let after = closed
    closed.takeGaps(from: stood)
    #expect(closed == after)
  }

  @Test func norFromOneWithAsManyNodesUnderOtherNumbers() {
    let stood = served()
    // Notes has left and come again: as many nodes as before, two of them new.
    var again = stood
    again.remove(notes)
    again.dock(notes, beside: again.root, edge: .left)
    #expect(again.preorder().count == stood.preorder().count)
    let before = again
    again.takeGaps(from: stood)
    #expect(again == before)
  }
}
