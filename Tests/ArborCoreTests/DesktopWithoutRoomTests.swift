import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)

private func everyone(_: WindowID) -> Bool { true }

private func layOut(
  _ tree: LayoutTree, camera: NodeID? = nil, options: LayoutOptions = LayoutOptions(),
  isPresent: @escaping (WindowID) -> Bool = everyone
) -> Layout {
  LayoutEngine.layout(tree, camera: camera ?? tree.root, in: screen, options: options, isPresent: isPresent)
}

/// The weights of the root's children, in their order.
private func weights(_ tree: LayoutTree) -> [Double] { tree.children(of: tree.root).map { tree[$0]!.weight } }

/// [a | Desktop], halves.
private func one() -> LayoutTree {
  var tree = LayoutTree()
  tree.dock(a, beside: tree.root, edge: .left)
  return tree
}

/// [a | Desktop without room | b], halves.
private func two() -> LayoutTree {
  var tree = one()
  tree.dock(b, beside: tree.root, edge: .right)
  return tree
}

/// The Desktop is what is left over, which can be nothing (QUESTIONS Q28, Q29; `LayoutTree.desktopHasRoom`).
@Suite struct DesktopWithoutRoomTests {
  // MARK: Docking takes what is left first

  @Test func theFirstDockTakesAHalf() {
    let tree = one()
    #expect(weights(tree) == [1, 1])
    #expect(tree.desktopHasRoom)
    #expect(LayoutTree().desktopHasRoom, "alone it has everything")
  }

  @Test(arguments: [Edge.left, .right]) func atTheEdgeOfTheRowTheSecondTakesAllThatIsLeft(edge: Edge) {
    var tree = one()
    let first = tree.leaf(containing: a)!
    let second = tree.dock(b, beside: tree.root, edge: edge)
    #expect(tree.children(of: tree.root) == (edge == .left ? [second, first, tree.desktop] : [first, tree.desktop, second]))
    #expect(tree[first]?.weight == 1, "nobody else gives anything")
    #expect(tree[second]?.weight == 1)
    #expect(tree[tree.desktop]?.weight == 0)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func howeverMuchThatIs() {
    var tree = one()
    tree.moveBoundary(leading: tree.leaf(containing: a)!, trailing: tree.desktop, by: -50, pointsPerWeight: 100, minimumPoints: 10)
    tree.dock(b, beside: tree.root, edge: .right)
    #expect(weights(tree) == [0.5, 0, 1.5])
  }

  @Test(arguments: [Edge.left, .right]) func besideAWindowInTheDesktopsRowToo(edge: Edge) {
    var tree = one()
    let first = tree.leaf(containing: a)!
    let second = tree.dock(b, beside: first, edge: edge)
    #expect(tree[first]?.weight == 1, "not half of the window it is docked beside")
    #expect(tree[second]?.weight == 1)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test(arguments: [Edge.left, .right]) func andBesideTheDesktopItself(edge: Edge) {
    var tree = one()
    let second = tree.dock(b, beside: tree.desktop, edge: edge)
    #expect(tree[second]?.weight == 1)
    #expect(!tree.desktopHasRoom)
    #expect(tree.children(of: tree.root).count == 3)
  }

  @Test func acrossTheRowWhatIsLeftStaysLeft() {
    var tree = one()
    tree.dock(b, beside: tree.leaf(containing: a)!, edge: .bottom)
    #expect(tree.desktopHasRoom)
    #expect(weights(tree) == [1, 1])
    var other = one()
    other.dock(b, beside: other.root, edge: .top)
    #expect(other.desktopHasRoom)
    var third = one()
    let below = third.dock(b, beside: third.desktop, edge: .bottom)
    #expect(third.desktopHasRoom, "half of the column that was left over")
    #expect(third.parent(of: below) == third.parent(of: third.desktop))
  }

  @Test func withNothingLeftAtTheEdgeOfTheRowEverybodyGivesAnEvenShare() {
    var tree = two()
    tree.dock(c, beside: tree.root, edge: .right)
    #expect(weights(tree) == [1, 0, 1, 1], "the Desktop does not count among those who share")
    #expect(tree.invariantViolations().isEmpty)
    let widths = [a, b, c].map { layOut(tree).windowFrames[$0]!.width }
    #expect(widths.max()! - widths.min()! <= 1)
  }

  @Test func withNothingLeftBesideAWindowThatWindowGivesHalf() {
    var tree = two()
    tree.dock(c, beside: tree.leaf(containing: b)!, edge: .left)
    #expect(weights(tree) == [1, 0, 0.5, 0.5])
    var even = two()
    even.dock(c, beside: even.leaf(containing: b)!, edge: .left, evenShare: true)
    #expect(weights(even) == [1, 0, 1, 1])
  }

  @Test(arguments: Edge.allCases) func besideADesktopWithoutRoomNobodyGetsHalfOfNothing(edge: Edge) {
    var tree = two()
    let leaf = tree.dock(c, beside: tree.desktop, edge: edge)
    #expect(tree.invariantViolations().isEmpty)
    #expect((tree[leaf]?.weight ?? 0) > 0)
    #expect(layOut(tree).windowFrames.count == 3)
  }

  @Test func dockedOnTheViewOfADesktopWithoutRoomItGetsAShareLikeTheOthers() {
    // What `dock left` does while the view is on the Desktop.
    var tree = two()
    let leaf = tree.dock(c, beside: tree.desktop, edge: .left, groupingFor: .view)
    let group = tree.parent(of: leaf)!
    #expect(tree.children(of: group) == [leaf, tree.desktop])
    #expect(tree[group]?.weight == 1)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
    #expect(layOut(tree).windowFrames[c]?.width == 464)
    // And when it goes again no column is left where it was.
    tree.remove(c)
    #expect(tree.hasSameArrangement(as: two()))
  }

  @Test func besideOneOtherAloneWhatItLeavesIsLeftOver() {
    var tree = LayoutTree.grid(of: [a])
    tree.dock(b, beside: tree.desktop, edge: .top)  // [a | [b / Desktop]]
    let before = layOut(tree).windowFrames[a]
    tree.remove(b)
    #expect(layOut(tree).windowFrames[a] == before)
    #expect(tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func withAColumnTheDesktopHasAShareLikeAnyWindows() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left, desktopColumn: true)
    tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
    #expect(weights(tree) == [1, 1, 1], "thirds")
    tree.dock(c, beside: first, edge: .right, desktopColumn: true)
    #expect(weights(tree) == [0.5, 0.5, 1, 1], "half of the window it is docked beside")
  }

  @Test func throughAWorkspaceAndADrop() {
    var ships = Workspace()
    ships.dock(a, at: .cameraEdge(.left))
    ships.dock(b, at: .cameraEdge(.right))
    #expect(!ships.tree.desktopHasRoom)
    var column = Workspace()
    column.dock(a, at: .cameraEdge(.left), desktopColumn: true)
    column.dock(b, at: .cameraEdge(.right), desktopColumn: true)
    #expect(weights(column.tree) == [1, 1, 1])

    let display = DisplayID("main")
    for desktopColumn in [false, true] {
      var workspaces = [display: Workspace()]
      workspaces[display]!.floating = [a: .zero, b: .zero]
      for (window, edge) in [(a, Edge.left), (b, .right)] {
        Drop(window: window, target: .cameraEdge(edge), display: display, frame: .zero, desktopColumn: desktopColumn)
          .apply(to: &workspaces)
      }
      #expect(workspaces[display]!.tree.desktopHasRoom == desktopColumn)
    }
  }

  @Test func aPreviewShowsWhatTheDropWillDo() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.floating[b] = .zero
    let half = layOut(workspace.tree).desktopFrame
    #expect(
      workspace.previewFrame(for: b, at: .cameraEdge(.right), in: screen, options: LayoutOptions(), isPresent: everyone) == half)
    let third = workspace.previewFrame(
      for: b, at: .cameraEdge(.right), in: screen, options: LayoutOptions(desktopColumn: true), isPresent: everyone)
    #expect((third?.width ?? 0) < (half?.width ?? 0) - 200)
  }

  // MARK: Leaving

  @Test(arguments: [a, b]) func whoeverIsLeftAloneInTheDesktopsRowStaysAsItIs(leaver: WindowID) {
    var tree = two()
    let stays = leaver == a ? b : a
    let before = layOut(tree).windowFrames[stays]
    let freed = layOut(tree).windowFrames[leaver]
    tree.remove(leaver)
    #expect(layOut(tree).windowFrames[stays] == before)
    #expect(layOut(tree).desktopFrame == freed, "the room is left over, where it was freed")
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test(arguments: [a, b], [true, false]) func howeverTheyCame(leaver: WindowID, shareSpace: Bool) {
    // Arrange Windows puts the Desktop last. Without room it can be anywhere in its row, and takes the place of what leaves.
    var tree = LayoutTree.grid(of: [a, b])
    let options = LayoutOptions(shareRemovedSpace: shareSpace)
    let stays = leaver == a ? b : a
    let before = layOut(tree, options: options).windowFrames[stays]
    tree.remove(leaver, shareSpace: shareSpace)
    #expect(layOut(tree, options: options).windowFrames[stays] == before)
    #expect(tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test(arguments: [a, b], [true, false]) func ifTheOneThatLeavesWasAwayTheOtherKeepsWhatItHas(leaver: WindowID, shareSpace: Bool) {
    // Minimized, hidden, or a place kept for a window that is not open: whoever is there has its room already.
    var tree = two()
    let stays = leaver == a ? b : a
    let options = LayoutOptions(shareRemovedSpace: shareSpace)
    let before = layOut(tree, options: options, isPresent: { $0 == stays }).windowFrames[stays]
    #expect(before == LayoutEngine.content(of: screen, options: options), "the premise")
    tree.remove(leaver, shareSpace: shareSpace, away: true)
    #expect(layOut(tree, options: options).windowFrames[stays] == before)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func aColumnThatIsLeftAloneIsOnePlace() {
    var tree = LayoutTree.grid(of: [a, b, c])  // [a / b] | c
    let before = layOut(tree)
    tree.remove(c)
    #expect(layOut(tree).windowFrames[a] == before.windowFrames[a])
    #expect(layOut(tree).windowFrames[b] == before.windowFrames[b])
    #expect(layOut(tree).desktopFrame == before.windowFrames[c])
  }

  @Test func thereAndBackIsNothing() {
    let before = one()
    var tree = before
    tree.dock(b, beside: tree.root, edge: .right)
    tree.remove(b)
    #expect(tree.hasSameArrangement(as: before))
  }

  @Test(arguments: [true, false]) func fromThreeDownTheOthersShareAndNoColumnOpens(shareSpace: Bool) {
    var tree = two()
    tree.dock(c, beside: tree.root, edge: .right)
    tree.remove(c, shareSpace: shareSpace)
    #expect(!tree.desktopHasRoom)
    #expect(layOut(tree, options: LayoutOptions(shareRemovedSpace: shareSpace)).desktopFrame == nil)
    #expect(tree.invariantViolations().isEmpty)
    // The neighbour before it is the Desktop, which is not whom the room goes to.
    var other = two()
    other.dock(c, beside: other.root, edge: .right)
    other.remove(b, shareSpace: shareSpace)
    #expect(!other.desktopHasRoom)
    #expect(weights(other).reduce(0, +) == (shareSpace ? 2 : 3))
  }

  @Test func theLastToLeaveLeavesTheDesktopAlone() {
    var tree = two()
    tree.remove(a)
    tree.remove(b)
    #expect(tree.root == tree.desktop)
    #expect(tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
    var arranged = LayoutTree.grid(of: [a])
    #expect(!arranged.desktopHasRoom)
    arranged.remove(a)
    #expect(arranged.root == arranged.desktop)
    #expect(arranged.invariantViolations().isEmpty)
  }

  // MARK: Arrange, balance

  @Test(arguments: 1...9) func aGridLeavesNothingOver(count: Int) {
    let windows = (1...count).map { WindowID(UInt32($0)) }
    let tree = LayoutTree.grid(of: windows)
    #expect(!tree.desktopHasRoom)
    #expect(tree.children(of: tree.root).last == tree.desktop)
    #expect(tree.invariantViolations().isEmpty)
    let layout = layOut(tree)
    let content = LayoutEngine.content(of: screen, options: LayoutOptions())
    #expect(layout.windowFrames.count == count)
    #expect(layout.windowFrames.values.map(\.maxX).max() == content.maxX)
    #expect(layout.windowFrames.values.map(\.minX).min() == content.minX)
  }

  @Test func orAColumnAsWideAsItIsTold() {
    let tree = LayoutTree.grid(of: [a, b], desktopWeight: 0.5)
    #expect(weights(tree) == [1, 1, 0.5])
    #expect(weights(LayoutTree.grid(of: [a, b], desktopWeight: 0)) == [1, 1, 0.05], "a number from a file is still bounded")
    #expect(weights(LayoutTree.grid(of: [a, b], desktopWeight: .nan)) == [1, 1, 0.5])
  }

  @Test func eveningOutLeavesADesktopWithoutRoomWithout() {
    var tree = two()
    tree.moveBoundary(leading: tree.leaf(containing: a)!, trailing: tree.leaf(containing: b)!, by: 30, pointsPerWeight: 100)
    tree.equalize(under: tree.root)
    #expect(weights(tree) == [1, 0, 1])
    // With a column for the Desktop (the setting was switched on over this arrangement) evening out brings it back: one place between
    // the two, and at the right of everything what Arrange Windows gives it.
    tree.equalize(under: tree.root, desktopWeight: 0.5)
    #expect(weights(tree) == [1, 1, 1])
    var arranged = LayoutTree.grid(of: [a, b])
    arranged.equalize(under: arranged.root, desktopWeight: 0.5)
    #expect(weights(arranged) == [1, 1, 0.5])
  }

  @Test func aDesktopThatHasRoomIsAPlaceLikeAnother() {
    var tree = one()
    tree.moveBoundary(leading: tree.leaf(containing: a)!, trailing: tree.desktop, by: 30, pointsPerWeight: 100)
    tree.equalize(under: tree.root)
    #expect(weights(tree) == [1, 1], "whichever side it is on")
    // With a column, evening out gives what Arrange Windows would have made.
    var column = one()
    column.equalize(under: column.root, desktopWeight: 0.5)
    #expect(weights(column) == [1, 0.5])
    var leading = LayoutTree()
    leading.dock(a, beside: leading.root, edge: .right)
    leading.moveBoundary(leading: leading.desktop, trailing: leading.leaf(containing: a)!, by: 30, pointsPerWeight: 100)
    leading.equalize(under: leading.root)
    #expect(weights(leading) == [1, 1])
  }

  // MARK: What takes up space

  @Test func itTakesNoRectangleNoTileNoGapAndNoSeam() {
    let tree = two()
    let layout = layOut(tree)
    let content = LayoutEngine.content(of: screen, options: LayoutOptions())
    #expect(layout.desktopFrame == nil)
    #expect(layout.nodeFrames[tree.desktop] == nil)
    #expect(layout.tiles.isEmpty)
    #expect(layout.seams.count == 1)
    #expect(layout.seams.first?.leading == tree.leaf(containing: a))
    #expect(layout.seams.first?.trailing == tree.leaf(containing: b))
    let (left, right) = (layout.windowFrames[a]!, layout.windowFrames[b]!)
    #expect(left.minX == content.minX && right.maxX == content.maxX)
    #expect(right.minX - left.maxX == 12, "one gap")
    #expect(left.width == right.width)
    #expect(layout.leafOrTile(at: CGPoint(x: left.maxX + 6, y: 400), in: tree) == nil)
  }

  @Test func theSecondDockLeavesTheFirstWhereItWasToThePoint() {
    for width in stride(from: 1000, through: 1013, by: 1) {
      let frame = CGRect(x: 0, y: 0, width: width, height: 700)
      func frames(_ tree: LayoutTree) -> Layout {
        LayoutEngine.layout(tree, camera: tree.root, in: frame, isPresent: everyone)
      }
      #expect(frames(one()).windowFrames[a] == frames(two()).windowFrames[a], "\(width)")
      #expect(frames(one()).desktopFrame == frames(two()).windowFrames[b], "\(width)")
    }
  }

  @Test func alsoWhereAnAbsentWindowsPlaceIsKept() {
    let options = LayoutOptions(shareRemovedSpace: false)
    let layout = layOut(two(), options: options)
    #expect(layout.desktopFrame == nil)
    #expect(layout.windowFrames[a] == layOut(one(), options: options).windowFrames[a])
    #expect(layout.windowFrames[b]!.minX - layout.windowFrames[a]!.maxX == 12)
  }

  @Test func theViewCanStillBeOnIt() {
    let tree = two()
    let layout = layOut(tree, camera: tree.desktop)
    #expect(layout.camera == tree.desktop)
    #expect(layout.desktopFrame == LayoutEngine.content(of: screen, options: LayoutOptions()))
    #expect(layout.windowFrames.isEmpty)
    #expect(layout.hiddenWindows == [a, b])
    let view = TreeView(tree: tree, isPresent: everyone)
    #expect(view.effectiveAncestor(of: tree.desktop) == tree.desktop)
    #expect(!view.isEffective(tree.desktop))
    #expect(view.effectiveChildren(of: tree.root).count == 2)
    // The ways there and away.
    #expect(Navigation.stepIn(from: tree.root, toward: tree.desktop, in: view) == tree.desktop)
    #expect(Navigation.stepOut(from: tree.desktop, in: view) == tree.root)
    #expect(Navigation.neighbor(of: tree.desktop, toward: .left, in: view) == tree.leaf(containing: a))
    #expect(Navigation.neighbor(of: tree.desktop, toward: .right, in: view) == tree.leaf(containing: b))
    #expect(Navigation.neighbor(of: tree.leaf(containing: a)!, toward: .right, in: view) == tree.leaf(containing: b))
    #expect(Navigation.stepIn(from: tree.desktop, toward: tree.desktop, in: view) == nil)
  }

  @Test func withEveryDockedWindowAwayEverythingIsLeftOver() {
    let tree = two()
    let layout = layOut(tree, isPresent: { _ in false })
    #expect(layout.desktopFrame == LayoutEngine.content(of: screen, options: LayoutOptions()))
    let view = TreeView(tree: tree, isPresent: { _ in false })
    #expect(view.isEffective(tree.desktop) && view.isEffective(tree.root))
    #expect(view.passThrough(tree.root) == tree.desktop)
    #expect(view.effectiveAncestor(of: tree.leaf(containing: a)!) == tree.root)
    // One away lends its room to who is there, as between any two docked windows.
    let oneAway = layOut(tree, isPresent: { $0 == b })
    #expect(oneAway.desktopFrame == nil)
    #expect(oneAway.windowFrames[b] == LayoutEngine.content(of: screen, options: LayoutOptions()))
  }

  @Test func nestedInAGroupWhoseWindowsAreAwayItOpensNoColumn() {
    var tree = two()
    tree.dock(c, beside: tree.desktop, edge: .top)  // [a | [c / Desktop] | b]
    tree.dock(d, beside: tree.desktop, edge: .bottom)
    #expect(!tree.desktopHasRoom)
    let layout = layOut(tree, isPresent: { $0 == a || $0 == b })
    #expect(layout.desktopFrame == nil)
    #expect(layout.windowFrames[b]!.minX - layout.windowFrames[a]!.maxX == 12)
  }

  @Test func theGapBetweenTheTwoCanBeDragged() {
    var tree = two()
    let seam = layOut(tree).seams[0]
    tree.moveBoundary(at: seam, by: 100)
    let layout = layOut(tree)
    #expect(layout.windowFrames[a]!.width == 802)
    #expect(layout.windowFrames[b]!.width == 602)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
    // A Desktop without room has no boundary to move: a seam left over from an older layout changes nothing.
    let before = tree
    tree.moveBoundary(leading: tree.leaf(containing: a)!, trailing: tree.desktop, by: -100, pointsPerWeight: 702)
    tree.moveBoundary(leading: tree.desktop, trailing: tree.leaf(containing: b)!, by: 100, pointsPerWeight: 702)
    #expect(tree == before)
  }

  @Test func aloneWithEverythingIsToldFromAloneWithAHalf() {
    let tree = one()
    #expect(!tree.isAloneBesideADesktopWithoutRoom(tree.leaf(containing: a)!))
    let alone = LayoutTree.grid(of: [a])
    #expect(alone.isAloneBesideADesktopWithoutRoom(alone.leaf(containing: a)!))
    let arranged = LayoutTree.grid(of: [a, b])
    #expect(!arranged.isAloneBesideADesktopWithoutRoom(arranged.leaf(containing: a)!))
  }

  @Test func turningMirroringAndSwappingLeaveItWithout() {
    var tree = two()
    tree.rotate(tree.root)
    tree.mirror(tree.root)
    tree.swapSiblings(tree.leaf(containing: a)!, tree.leaf(containing: b)!)
    tree.tradePlaces(of: a, and: b)
    #expect(!tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty)
    #expect(layOut(tree).windowFrames.count == 2)
  }

  @Test func aLongSessionNeverGivesItASliver() {
    var tree = two()
    for round in 0..<200 {
      let window = WindowID(UInt32(100 + round))
      tree.dock(window, beside: tree.leaf(containing: b)!, edge: round.isMultiple(of: 2) ? .left : .right)
      if round.isMultiple(of: 3) { tree.remove(window) }
      #expect(tree[tree.desktop]?.weight == 0)
    }
    #expect(tree.invariantViolations().isEmpty)
  }

  // MARK: What is saved

  @Test func itIsSavedAndReadBack() throws {
    let tree = two()
    let read = try JSONDecoder().decode(LayoutTree.self, from: JSONEncoder().encode(tree))
    #expect(read == tree)
    #expect(!read.desktopHasRoom)
  }

  private func reading(_ tree: LayoutTree, _ change: (inout [String: Any]) -> Void) throws -> (LayoutTree, DecodingNotes) {
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tree)) as! [String: Any]
    change(&object)
    let decoder = JSONDecoder()
    let notes = DecodingNotes()
    decoder.userInfo[DecodingNotes.key] = notes
    return (try decoder.decode(LayoutTree.self, from: JSONSerialization.data(withJSONObject: object)), notes)
  }

  private func setWeight(_ weight: Double, of id: NodeID, in object: inout [String: Any]) {
    var nodes = object["nodes"] as! [String: Any]
    var node = nodes[String(id.rawValue)] as! [String: Any]
    node["weight"] = weight
    nodes[String(id.rawValue)] = node
    object["nodes"] = nodes
  }

  @Test func aFileOfTheFirstBuildKeepsItsColumn() throws {
    let column = LayoutTree.grid(of: [a, b], desktopWeight: 0.1)
    let (read, notes) = try reading(column) { _ in }
    #expect(read == column, "read as it is: nothing moves at a start")
    #expect(notes.notes.isEmpty)
  }

  @Test func onlyTheDesktopMayWeighNothingAndOnlyBesideOthers() throws {
    let tree = two()
    let (window, notes) = try reading(tree) { setWeight(0, of: tree.leaf(containing: a)!, in: &$0) }
    #expect(window[tree.leaf(containing: a)!]?.weight == 1)
    #expect(notes.losses.count == 1)
    let (negative, _) = try reading(tree) { setWeight(-1, of: tree.desktop, in: &$0) }
    #expect(negative[tree.desktop]?.weight == 1)
    let (alone, _) = try reading(LayoutTree()) { setWeight(0, of: NodeID(0), in: &$0) }
    #expect(alone.invariantViolations().isEmpty)
    #expect(alone.desktopHasRoom)
  }

  @Test func whatIsLeftOfADamagedFileHolds() throws {
    // Both windows are gone from the file: the Desktop is all that is left, and has everything.
    let tree = two()
    let (read, _) = try reading(tree) { object in
      var nodes = object["nodes"] as! [String: Any]
      nodes[String(tree.leaf(containing: a)!.rawValue)] = nil
      nodes[String(tree.leaf(containing: b)!.rawValue)] = nil
      object["nodes"] = nodes
    }
    #expect(read.root == read.desktop)
    #expect(read.invariantViolations().isEmpty)
  }

  // MARK: The line of text

  @Test func aLineThatDoesNotMentionTheDesktopGivesItNoRoom() throws {
    let spec = try LayoutNotation.parse("Safari | Mail")
    let tree = spec.tree(filling: [[a], [b]])
    #expect(!tree.desktopHasRoom)
    #expect(tree.children(of: tree.root).last == tree.desktop)
    #expect(tree.invariantViolations().isEmpty)
    #expect(weights(spec.tree(filling: [[a], [b]], desktopSize: 0.5)) == [1, 1, 0.5])
    let single = try LayoutNotation.parse("Safari").tree(filling: [[a]])
    #expect(!single.desktopHasRoom)
    #expect(single.invariantViolations().isEmpty)
    #expect(layOut(single).windowFrames[a] == LayoutEngine.content(of: screen, options: LayoutOptions()))
  }

  @Test func aLineThatMentionsItMeansIt() throws {
    let tree = try LayoutNotation.parse("Safari | Desktop:0.5 | Mail").tree(filling: [[a], [b]])
    #expect(weights(tree) == [1, 0.5, 1])
  }

  @Test func nothingFoundLeavesTheDesktopAlone() throws {
    let tree = try LayoutNotation.parse("Safari | Mail").tree(filling: [[], []])
    #expect(tree.root == tree.desktop)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func aDesktopWithoutRoomIsNotWritten() throws {
    func text(_ tree: LayoutTree) -> String { LayoutNotation.Spec(tree) { WindowSlot.window($0) }.text }
    #expect(text(two()) == "1 | 2")
    #expect(text(one()) == "1 | Desktop")
    #expect(text(LayoutTree.grid(of: [a])) == "1")
    #expect(text(LayoutTree.grid(of: [a, b, c])) == "(1 / 2) | 3")
    // And the line makes the same arrangement again.
    let again = try LayoutNotation.parse(text(two())).tree(filling: [[a], [b]])
    #expect(layOut(again).windowFrames == layOut(two()).windowFrames)
  }

  // MARK: Room before tiles

  private let minimums = [a: CGSize(width: 820, height: 400), b: CGSize(width: 760, height: 500)]

  private func serve(
    _ tree: inout LayoutTree, keyboard: WindowID? = nil, options: LayoutOptions = LayoutOptions(), owed: Bool = false
  ) -> Layout {
    MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: options, isPresent: everyone, minimumSize: { minimums[$0] },
      terms: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard, desktopIsOwed: owed)
    ).layout
  }

  @Test func whoeverTakesWhatIsLeftTakesWhatTheDesktopIsOwedWithIt() {
    // 820 and 760 do not both fit on 1440. The first borrowed from the Desktop; the second has the keyboard, and gets that back.
    var tree = one()
    #expect(serve(&tree).windowFrames[a]?.width == 820)
    #expect(tree.hasLoans)
    tree.dock(b, beside: tree.root, edge: .right)
    let layout = serve(&tree, keyboard: b)
    #expect(layout.windowFrames[b]?.width == 760)
    #expect(layout.tiles.map(\.windows) == [[a]])
    #expect(!tree.desktopHasRoom)
  }

  @Test func whereNothingIsLentTheOthersLendForTheWindowWithTheKeyboard() {
    // Two halves of 702, each window's own. The second's app makes it larger than that, and the first cannot spare as much.
    let needs = [a: CGSize(width: 690, height: 400), b: CGSize(width: 900, height: 500)]
    func serve(_ tree: inout LayoutTree, keyboard: WindowID?, options: LayoutOptions = LayoutOptions()) -> Layout {
      MakeRoom.serve(
        &tree, camera: tree.root, in: screen, options: options, isPresent: everyone, minimumSize: { needs[$0] },
        terms: MakeRoom.Terms(desktopIsInUse: false, keyboard: keyboard)
      ).layout
    }
    var typing = two()
    let layout = serve(&typing, keyboard: b)
    #expect(layout.windowFrames[b]?.width == 900, "whoever types into a window that nobody can see has lost it")
    #expect(layout.tiles.map(\.windows) == [[a]])
    // It is a loan: with the keyboard in the first, that one has its own back, and the second is the tile.
    #expect(serve(&typing, keyboard: a).windowFrames[a]?.width == 702)
    // In the background it costs nobody their place.
    var background = two()
    #expect(serve(&background, keyboard: a).tiles.map(\.windows) == [[b]])
    #expect(background.hasSameArrangement(as: two()))
    var nobody = two()
    #expect(serve(&nobody, keyboard: nil).tiles.map(\.windows) == [[b]])
  }

  @Test func andHandsItBackWhenItLeaves() {
    var tree = one()
    _ = serve(&tree)
    let before = tree
    tree.dock(b, beside: tree.root, edge: .right)
    tree.remove(b)
    #expect(tree.hasSameArrangement(as: before), "there and back is nothing")
    // In the ledger too: on a larger display the first can spare what it borrowed, and the Desktop has it back.
    func onALargerDisplay(_ tree: LayoutTree) -> Layout {
      var tree = tree
      return MakeRoom.serve(
        &tree, camera: tree.root, in: CGRect(x: 0, y: 25, width: 1920, height: 1055), options: LayoutOptions(), isPresent: everyone,
        minimumSize: { minimums[$0] }, terms: MakeRoom.Terms(desktopIsInUse: false)
      ).layout
    }
    #expect(onALargerDisplay(tree) == onALargerDisplay(before))
    #expect(onALargerDisplay(tree).windowFrames[a]?.width == onALargerDisplay(tree).desktopFrame?.width)
  }

  @Test func aDesktopWithoutRoomIsOwedNothing() {
    // The first borrowed seven points' worth from the Desktop. It closes: no sliver opens beside the one that stays.
    var tree = one()
    _ = serve(&tree)
    tree.dock(b, beside: tree.root, edge: .right)
    tree.dock(c, beside: tree.root, edge: .right)
    tree.remove(a)
    #expect(tree[tree.desktop]?.weight == 0)
    #expect(layOut(tree).desktopFrame == nil && layOut(tree).tiles.isEmpty)
  }

  @Test func whatIsLeftOverIsNeverServed() {
    // A Desktop that a window has made a tile of: with a column the neighbours top it up, without one nobody gives for it.
    var tree = LayoutTree()
    tree.dock(c, beside: tree.root, edge: .left)
    tree.moveBoundary(leading: tree.leaf(containing: c)!, trailing: tree.desktop, by: 550, pointsPerWeight: 702, minimumPoints: 80)
    #expect(layOut(tree).tiles.map(\.kind) == [.desktop], "the premise")
    var ships = tree
    #expect(serve(&ships, owed: true).tiles.map(\.kind) == [.desktop])
    #expect(ships == tree)
    var column = tree
    #expect(serve(&column, options: LayoutOptions(desktopColumn: true), owed: true).desktopFrame != nil)
  }

  // MARK: Windows that dock by themselves

  @Test func theFirstWindowThatDocksByItselfLeavesWhatArrangeWould() {
    var workspace = Workspace()
    workspace.floating[a] = CGRect(x: 100, y: 100, width: 800, height: 600)
    func plan(_ options: LayoutOptions) -> AutoDock.Plan {
      AutoDock.plan(
        for: a, in: workspace, recent: [], frame: screen, options: options, tabsEnabled: false, isPresent: everyone,
        emptyDesktopWeight: 0.5)
    }
    guard case .dock(let ships) = plan(LayoutOptions()), case .dock(let column) = plan(LayoutOptions(desktopColumn: true)) else {
      Issue.record("not docked")
      return
    }
    #expect(ships.slot == LayoutEngine.content(of: screen, options: LayoutOptions()), "nothing")
    #expect(column.slot.width < ships.slot.width - 400)
    var docked = workspace
    #expect(ships.apply(to: &docked, docking: a))
    #expect(!docked.tree.desktopHasRoom)
    #expect(docked.tree.invariantViolations().isEmpty)
  }

  @Test func aWindowThatDocksByItselfMayTakeAllThatIsLeft() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.floating[b] = CGRect(x: 100, y: 100, width: 800, height: 600)
    workspace.floating[c] = CGRect(x: 900, y: 100, width: 300, height: 300)
    let plan = AutoDock.plan(
      for: b, in: workspace, recent: [a], frame: screen, options: LayoutOptions(), tabsEnabled: false, isPresent: everyone,
      makingRoom: MakeRoom.Terms(desktopIsInUse: true))
    guard case .dock(let placement) = plan else {
      Issue.record("\(plan)")
      return
    }
    #expect(placement.slot == layOut(workspace.tree).desktopFrame, "what floats stays in view, over the docked windows")
  }

  // MARK: What a second reading found

  /// "No column opens" is said of a row in which others share. In a group that is kept, down to this, there are no others.
  @Test func aloneInAGroupThatIsKeptTheDesktopHasAllOfItAlsoWhenItRisesIntoIt() throws {
    var tree = try LayoutNotation.parse("((Safari / Desktop:0) | Mail) / Notes").tree(filling: [[a], [b], [c]])
    let mail = try #require(tree.leaf(containing: b))
    let group = try #require(tree.parent(of: mail))
    tree.keep(group, for: .name)
    tree.remove(b)
    #expect(tree.children(of: group).count == 1, "down to the column of Safari and a Desktop without room")
    tree.remove(a)
    #expect(tree.children(of: group) == [tree.desktop])
    #expect(tree.desktopHasRoom)
    #expect(tree.invariantViolations().isEmpty, "\(tree.invariantViolations())")
  }

  /// A tab that leaves its group leaves the group its room and brings none: it takes what is left over, like a window that floated.
  @Test func aTabThatLeavesItsGroupTakesWhatIsLeftOver() throws {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .stack(try #require(workspace.tree.leaf(containing: a))))
    let before = layOut(workspace.tree).windowFrames
    workspace.dock(b, at: .cameraEdge(.right))
    let layout = layOut(workspace.tree)
    #expect(!workspace.tree.desktopHasRoom)
    #expect(layout.windowFrames[a] == before[a] ?? before[b], "the group it leaves does not move")
    #expect(layout.windowFrames[b]?.width == layout.windowFrames[a]?.width)
  }

  /// As little as a hand has left it since is what that hand wanted.
  @Test func tooLittleIsOnlyWhatWasFoundAtTheDock() throws {
    var tree = two()
    let (first, second) = (try #require(tree.leaf(containing: a)), try #require(tree.leaf(containing: b)))
    tree.moveBoundary(leading: first, trailing: second, by: 560, pointsPerWeight: 702)
    let squeezed = weights(tree)
    #expect(layOut(tree).tiles.map(\.node) == [second])
    #expect(!MakeRoom.shareWhereTooLittleWasLeft(&tree, laidOutAs: layOut(tree), options: LayoutOptions()))
    #expect(weights(tree) == squeezed)
  }

  // MARK: Settings and recordings

  @Test func itShipsWithoutAColumnAndTheOldWidthIsNotAsked() throws {
    #expect(!Settings().desktopColumn)
    #expect(Settings().desktopWeightWhenArranged == nil)
    #expect(!Settings().layoutOptions.desktopColumn)
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"arrangeDesktopWeight": 0.1}"#.utf8))
    #expect(old.desktopWeightWhenArranged == nil, "a file may hold the old width at its floor, as a wish to be rid of the column")
    let asked = try JSONDecoder().decode(Settings.self, from: Data(#"{"arrangeDesktopWeight": 0.3, "desktopColumn": true}"#.utf8))
    #expect(asked.desktopWeightWhenArranged == 0.3)
    #expect(asked.layoutOptions.desktopColumn)
  }

  @Test func aRecordingMadeBeforeThereWasAChoiceWasMadeWithTheColumn() throws {
    func header(_ settings: String) throws -> TraceHeader {
      try JSONDecoder().decode(
        TraceHeader.self, from: Data(#"{"trace": 1, "displays": [], "settings": \#(settings)}"#.utf8))
    }
    #expect(try header(#"{"gap": 12}"#).settings.desktopColumn)
    #expect(try !header(#"{"gap": 12, "desktopColumn": false}"#).settings.desktopColumn)
    // And what is recorded today says which.
    let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as! [String: Any]
    #expect(written["desktopColumn"] as? Bool == false)
  }
}
