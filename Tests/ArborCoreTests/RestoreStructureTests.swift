import ArborCore
import CoreGraphics
import Testing

@Suite struct RestoreStructureTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let c = WindowID(3)

  /// `a`, `b` and `c` docked around the Desktop.
  func desk() -> Workspace {
    var workspace = Workspace()
    workspace.floating[a] = CGRect(x: 10, y: 10, width: 300, height: 200)
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: b)!, .bottom))
    return workspace
  }

  @Test func theArrangementIsAsItWasBeforeTheWindowsWent() {
    let earlier = desk()
    var workspace = earlier
    workspace.forget(a)
    workspace.forget(c)
    let left = workspace
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree == earlier.tree)
    #expect(workspace.tree.invariantViolations().isEmpty)
    #expect(workspace.undockedFrame(of: a) == earlier.undockedFrame(of: a), "what was remembered about it comes back")
    #expect(earlier.undockedFrame(of: a) != nil)
  }

  @Test func theViewAndItsHistoryStayAsTheyAreNow() {
    let earlier = desk()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    workspace.moveCamera(to: workspace.tree.leaf(containing: b)!)
    workspace.moveCamera(to: workspace.tree.desktop)
    let (camera, back) = (workspace.camera, workspace.back)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.camera == camera)
    #expect(workspace.back == back)
    #expect(workspace.tree.contains(workspace.camera))
  }

  @Test func floatingWindowsStayAsTheyAreNow() {
    let earlier = desk()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    let new = WindowID(9)
    workspace.floating[new] = CGRect(x: 1, y: 2, width: 3, height: 4)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.isFloating(new))
    #expect(workspace.isDocked(a) && !workspace.isFloating(a))
  }

  @Test func aSavedViewThatTheGoingMovedComesBackUnlessItWasSavedOver() {
    var earlier = desk()
    earlier.moveCamera(to: earlier.tree.leaf(containing: a)!)
    earlier.saveView(slot: 1)
    earlier.saveView(slot: 2)
    earlier.moveCamera(to: earlier.tree.root)
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    #expect(workspace.savedViews["1"] != earlier.savedViews["1"])
    workspace.moveCamera(to: workspace.tree.leaf(containing: b)!)
    workspace.saveView(slot: 2)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.savedViews["1"] == earlier.tree.leaf(containing: a))
    #expect(workspace.savedViews["2"] == workspace.tree.leaf(containing: b), "saved over meanwhile")
  }

  /// `[a | Desktop | (c | d)]`: the pair lies in a row on its own axis and exists only because a saved view is on it.
  @Test func aGroupThatOnlyASavedViewKeepsComesBackWithTheView() {
    let d = WindowID(4)
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    earlier.dock(c, at: .cameraEdge(.right))
    earlier.moveCamera(to: earlier.tree.leaf(containing: c)!)
    earlier.dock(d, at: .cameraEdge(.right))
    let pair = earlier.camera
    #expect(Set(earlier.tree.windows(under: pair)) == [c, d])
    earlier.saveView(slot: 1)
    earlier.moveCamera(to: earlier.tree.root)

    var workspace = earlier
    workspace.forget(c)
    workspace.forget(d)
    let left = workspace
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree == earlier.tree)
    #expect(workspace.savedViews["1"] == pair)
    #expect(Set(workspace.tree.windows(under: workspace.savedViews["1"]!)) == [c, d])
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aViewOfEverythingStaysAViewOfEverything() {
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    #expect(earlier.camera == earlier.tree.root)
    var workspace = earlier
    workspace.forget(a)
    #expect(workspace.tree.root == workspace.tree.desktop, "the Desktop is all there is")
    let left = workspace
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.camera == earlier.tree.root)
  }

  @Test func namesComeBackLikeSavedViews() throws {
    var earlier = desk()
    _ = try earlier.setName("Web", of: earlier.tree.leaf(containing: a)!)
    _ = try earlier.setName("Mail", of: earlier.tree.leaf(containing: c)!)
    var workspace = earlier
    workspace.forget(a)
    workspace.forget(c)
    let left = workspace
    #expect(workspace.names.isEmpty)
    // Given to something else meanwhile, in other capitals.
    _ = try workspace.setName("mail", of: workspace.tree.leaf(containing: b)!)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.names == ["Web": earlier.tree.leaf(containing: a)!, "mail": earlier.tree.leaf(containing: b)!])
  }

  @Test func whatWasSavedOrNamedBetweenTwoGoingsGoesIntoTheNote() throws {
    var note = desk()
    note.moveCamera(to: note.tree.leaf(containing: a)!)
    note.saveView(slot: 1)
    _ = try note.setName("Web", of: note.tree.leaf(containing: a)!)
    note.moveCamera(to: note.tree.root)
    var workspace = note
    workspace.forget(a)
    let left = workspace
    let notes = workspace.tree.leaf(containing: b)!
    workspace.moveCamera(to: notes)
    workspace.saveView(slot: 1)
    workspace.saveView(slot: 2)
    _ = try workspace.setName("Web", of: notes)
    note.follow(whatWasDoneIn: workspace, since: left)
    #expect(note.savedViews == ["1": notes, "2": notes])
    #expect(note.names == ["Web": notes])
  }

  @Test func movedGapsAndOtherTabsInFrontAreTheSameArrangement() {
    let workspace = desk()
    var moved = workspace
    let (left, right) = (moved.tree.leaf(containing: a)!, moved.tree.desktop)
    moved.tree.moveBoundary(leading: left, trailing: right, by: 40, pointsPerWeight: 500)
    #expect(moved.tree != workspace.tree)
    #expect(moved.tree.isSameArrangement(as: workspace.tree))

    var docked = workspace
    docked.dock(WindowID(9), at: .cameraEdge(.top))
    #expect(!docked.tree.isSameArrangement(as: workspace.tree))
    // There and back again: it looks the same, but node numbers have been handed out since.
    docked.forget(WindowID(9))
    #expect(!docked.tree.isSameArrangement(as: workspace.tree))

    var without = workspace
    without.forget(c)
    #expect(!without.tree.isSameArrangement(as: workspace.tree))
  }
}

/// What has been done to the gaps since the windows went stays done.
extension RestoreStructureTests {
  /// The share each child of `split` has of it.
  func shares(of split: NodeID, in tree: LayoutTree) -> [NodeID: Double] {
    let children = tree.children(of: split)
    let total = children.reduce(0) { $0 + tree[$1]!.weight }
    return Dictionary(uniqueKeysWithValues: children.map { ($0, tree[$0]!.weight / total) })
  }

  func isClose(_ a: Double?, _ b: Double?) -> Bool {
    guard let a, let b else { return false }
    return abs(a - b) < 1e-9
  }

  /// `[a | Desktop | b / c]`.
  @Test func withNoGapMovedTheTreeIsExactlyTheEarlierOne() {
    let earlier = desk()
    for gone in [[a], [b], [c], [a, c], [b, c], [a, b, c]] {
      var workspace = earlier
      for window in gone { workspace.forget(window) }
      var tree = earlier.tree
      tree.follow(gapsOf: workspace.tree, since: workspace.tree)
      #expect(tree == earlier.tree)
    }
  }

  @Test func aGapMovedInARowThatLostNobodyIsMovedAsFar() {
    let earlier = desk()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    let (upper, lower) = (workspace.tree.leaf(containing: b)!, workspace.tree.leaf(containing: c)!)
    workspace.tree.moveBoundary(leading: upper, trailing: lower, by: 90, pointsPerWeight: 400)
    let column = workspace.tree.parent(of: upper)!
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree.preorder() == earlier.tree.preorder())
    #expect(workspace.tree[upper]!.weight == earlier.tree[upper]!.weight + 90.0 / 400)
    #expect(shares(of: workspace.tree.root, in: workspace.tree) == shares(of: earlier.tree.root, in: earlier.tree))
    #expect(shares(of: column, in: workspace.tree) != shares(of: column, in: earlier.tree))
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  @Test func inTheRowThatLostAWindowItGetsItsShareBackAndTheOthersKeepTheirsAmongThemselves() {
    let earlier = desk()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    let (desktop, column) = (workspace.tree.desktop, workspace.tree.parent(of: workspace.tree.leaf(containing: b)!)!)
    workspace.tree.moveBoundary(leading: desktop, trailing: column, by: -100, pointsPerWeight: 400)
    let today = shares(of: workspace.tree.root, in: workspace.tree)
    workspace.restoreStructure(from: earlier, left: left)
    let (now, then) = (shares(of: workspace.tree.root, in: workspace.tree), shares(of: earlier.tree.root, in: earlier.tree))
    let leaf = earlier.tree.leaf(containing: a)!
    #expect(isClose(now[leaf], then[leaf]))
    #expect(isClose(now[column]! / now[desktop]!, today[column]! / today[desktop]!))
  }

  /// When `c` goes its column goes too, and `b` stands in the row in its place.
  @Test func aGapBesideWhatIsLeftOfAGroupIsAGapBesideTheGroup() {
    let earlier = desk()
    let column = earlier.tree.parent(of: earlier.tree.leaf(containing: b)!)!
    var workspace = earlier
    workspace.forget(c)
    #expect(!workspace.tree.contains(column))
    let left = workspace
    let survivor = workspace.tree.leaf(containing: b)!
    workspace.tree.moveBoundary(leading: workspace.tree.desktop, trailing: survivor, by: -100, pointsPerWeight: 400)
    let today = shares(of: workspace.tree.root, in: workspace.tree)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(isClose(shares(of: workspace.tree.root, in: workspace.tree)[column], today[survivor]))
    #expect(shares(of: column, in: workspace.tree) == shares(of: column, in: earlier.tree))
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  /// `[a | (x / (b | c))]`: when `x` goes its column goes, and the pair, a row in a row now, is taken apart.
  @Test func aGapWithinAGroupThatWasTakenApartIsAGapWithinTheGroup() {
    let x = WindowID(7)
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    earlier.dock(b, at: .cameraEdge(.right))
    earlier.dock(x, at: .beside(earlier.tree.leaf(containing: b)!, .top))
    earlier.dock(c, at: .beside(earlier.tree.leaf(containing: b)!, .right))
    let (first, second) = (earlier.tree.leaf(containing: b)!, earlier.tree.leaf(containing: c)!)
    let pair = earlier.tree.parent(of: first)!
    let column = earlier.tree.parent(of: pair)!
    #expect(earlier.tree.parent(of: second) == pair && earlier.tree.parent(of: earlier.tree.leaf(containing: x)!) == column)
    var workspace = earlier
    workspace.forget(x)
    #expect(!workspace.tree.contains(pair) && !workspace.tree.contains(column))
    let left = workspace
    workspace.tree.moveBoundary(leading: first, trailing: second, by: 50, pointsPerWeight: 1000)
    let today = shares(of: workspace.tree.root, in: workspace.tree)
    workspace.restoreStructure(from: earlier, left: left)
    let within = shares(of: pair, in: workspace.tree)
    #expect(isClose(within[first]! / within[second]!, today[first]! / today[second]!))
    #expect(isClose(shares(of: workspace.tree.root, in: workspace.tree)[column], today[first]! + today[second]!))
    #expect(shares(of: column, in: workspace.tree) == shares(of: column, in: earlier.tree))
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  /// `b` took half of `a`'s room and gave it back when it went. Then `a` was made narrower than that half.
  @Test func whoeverGaveTheRoomIsLeftWithSomething() {
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    earlier.dock(c, at: .beside(earlier.tree.leaf(containing: a)!, .right))
    earlier.dock(b, at: .beside(earlier.tree.leaf(containing: a)!, .right))
    var workspace = earlier
    workspace.forget(b)
    let left = workspace
    let (host, next) = (workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: c)!)
    #expect(left.tree[host]!.weight > earlier.tree[host]!.weight)
    workspace.tree.moveBoundary(
      leading: host, trailing: next, by: -0.9 * left.tree[host]!.weight, pointsPerWeight: 1, minimumPoints: 0)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree[host]!.weight > 0)
    #expect(workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aGapMovedByAHairMovesByAHair() {
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    earlier.dock(c, at: .beside(earlier.tree.leaf(containing: a)!, .right))
    earlier.dock(b, at: .beside(earlier.tree.leaf(containing: a)!, .right))
    var workspace = earlier
    workspace.forget(b)
    let left = workspace
    workspace.tree.moveBoundary(
      leading: workspace.tree.leaf(containing: a)!, trailing: workspace.tree.leaf(containing: c)!, by: 1, pointsPerWeight: 1000)
    workspace.restoreStructure(from: earlier, left: left)
    let (now, then) = (shares(of: workspace.tree.root, in: workspace.tree), shares(of: earlier.tree.root, in: earlier.tree))
    for (node, share) in then { #expect(abs(now[node]! - share) < 0.002) }
    #expect(now != then)
  }

  @Test func theTabInFrontNowStaysInFront() {
    var earlier = Workspace()
    earlier.dock(a, at: .cameraEdge(.left))
    earlier.dock(b, at: .stack(earlier.tree.leaf(containing: a)!))
    earlier.dock(c, at: .stack(earlier.tree.leaf(containing: a)!))
    let leaf = earlier.tree.leaf(containing: a)!
    #expect(earlier.tree.activeWindow(of: leaf) == c)
    var workspace = earlier
    workspace.forget(c)
    let left = workspace
    workspace.tree.activate(a)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree.windows(under: leaf) == [a, b, c])
    #expect(workspace.tree.activeWindow(of: leaf) == a)
  }

  @Test func whatTheDesktopIsOwedComesBackWithTheGapsUnlessItWasSettledSince() {
    var earlier = desk()
    earlier.desktopIsOwedRoom = true
    var workspace = earlier
    workspace.forget(a)
    workspace.desktopIsOwedRoom = nil
    let left = workspace
    var untouched = workspace
    untouched.restoreStructure(from: earlier, left: left)
    #expect(untouched.desktopIsOwedRoom == true)
    var owing = earlier
    owing.desktopIsOwedRoom = nil
    workspace.desktopIsOwedRoom = true
    workspace.restoreStructure(from: owing, left: left)
    #expect(workspace.desktopIsOwedRoom == true)
  }
}

/// `(((a | b) / x) | y) / Desktop`. With `x` and `y` gone, `a | b` is a group above the Desktop. With only `x` gone it is none: `a`, `b`
/// and `y` lie in one row.
extension RestoreStructureTests {
  func nested() -> (workspace: Workspace, x: WindowID, y: WindowID) {
    let (x, y) = (WindowID(7), WindowID(8))
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.top))
    workspace.dock(y, at: .beside(workspace.tree.leaf(containing: a)!, .right))
    workspace.dock(x, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
    workspace.dock(b, at: .beside(workspace.tree.leaf(containing: a)!, .right))
    return (workspace, x, y)
  }

  @Test func aGroupThereIsOnlyWhileBothAreAwayIsTakenApartWhenOneComesBack() {
    let (full, x, y) = nested()
    var workspace = full
    workspace.forget(y)
    workspace.forget(x)
    let left = workspace
    let pair = workspace.tree.parent(of: workspace.tree.leaf(containing: a)!)!
    #expect(Set(workspace.tree.windows(under: pair)) == [a, b] && pair != workspace.tree.root)
    var earlier = full
    earlier.forget(x)
    #expect(!earlier.tree.contains(pair))
    // A saved view of the pair, and the gap between the pair and the Desktop moved.
    workspace.moveCamera(to: pair)
    workspace.saveView(slot: 3)
    workspace.moveCamera(to: workspace.tree.root)
    workspace.tree.moveBoundary(leading: pair, trailing: workspace.tree.desktop, by: 100, pointsPerWeight: 500)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree.invariantViolations().isEmpty)
    #expect(Set(workspace.tree.allWindows) == [a, b, y])
    let row = workspace.tree.parent(of: workspace.tree.leaf(containing: a)!)!
    #expect(workspace.tree.contains(workspace.camera))
    #expect(workspace.savedViews["3"].map { Set(workspace.tree.windows(under: $0)).isSuperset(of: [a, b]) } == true)
    // The gap has moved as far as it was moved: on one side of it the Desktop, on the other the row that the pair is part of now.
    #expect(isClose(workspace.tree[workspace.tree.desktop]!.weight, earlier.tree[earlier.tree.desktop]!.weight - 0.2))
    #expect(isClose(workspace.tree[row]!.weight, earlier.tree[row]!.weight + 0.2))
    #expect(workspace.tree.parent(of: workspace.tree.leaf(containing: y)!) == row || workspace.savedViews["3"] == pair)
  }
}

/// The ledger of what was lent (room before tiles) follows like the gaps.
extension RestoreStructureTests {
  /// `[a | b | c | Desktop]`, where the Desktop has lent `b` a tenth.
  func lent() -> (workspace: Workspace, leaves: [NodeID]) {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .beside(workspace.tree.leaf(containing: a)!, .right))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: b)!, .right))
    let leaves = [a, b, c].map { workspace.tree.leaf(containing: $0)! }
    let (borrower, desktop) = (leaves[1], workspace.tree.desktop)
    let (has, gives) = (workspace.tree[borrower]!.weight, workspace.tree[desktop]!.weight)
    workspace.tree.setShares([borrower: has + 0.1, desktop: gives - 0.1], for: borrower)
    #expect(workspace.tree.hasLoans)
    return (workspace, leaves)
  }

  /// When the borrower goes for good afterwards, the Desktop has what it lent again, or not.
  func desktopAfterTheBorrowerWent(_ workspace: Workspace) -> Double {
    var workspace = workspace
    workspace.forget(b)
    return workspace.tree[workspace.tree.desktop]!.weight
  }

  @Test func whatWasLentIsStillOwedWhenTheWindowIsBack() {
    let (earlier, _) = lent()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    workspace.restoreStructure(from: earlier, left: left)
    #expect(workspace.tree == earlier.tree)
    #expect(isClose(desktopAfterTheBorrowerWent(workspace), earlier.tree[earlier.tree.desktop]!.weight + 0.1))
  }

  @Test func whatWasLentAcrossAGapThatAHandMovedMeanwhileIsForgotten() {
    let (earlier, leaves) = lent()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    workspace.tree.moveBoundary(leading: leaves[2], trailing: workspace.tree.desktop, by: 10, pointsPerWeight: 1000)
    #expect(!workspace.tree.hasLoans)
    workspace.restoreStructure(from: earlier, left: left)
    #expect(!workspace.tree.hasLoans)
    #expect(isClose(desktopAfterTheBorrowerWent(workspace), workspace.tree[workspace.tree.desktop]!.weight))
  }

  @Test func whatWasLentOrPaidBackMeanwhileIsLentOrPaidBack() {
    let (earlier, leaves) = lent()
    var workspace = earlier
    workspace.forget(a)
    let left = workspace
    // Another tenth to `c`, and half of what `b` had goes back.
    let desktop = workspace.tree.desktop
    workspace.tree.setShares([leaves[2]: workspace.tree[leaves[2]]!.weight + 0.1, desktop: workspace.tree[desktop]!.weight - 0.1], for: leaves[2])
    workspace.tree.setShares([leaves[1]: workspace.tree[leaves[1]]!.weight - 0.05, desktop: workspace.tree[desktop]!.weight + 0.05], for: nil)
    let now = workspace
    workspace.restoreStructure(from: earlier, left: left)
    for leaf in leaves[1...] + [desktop] { #expect(isClose(workspace.tree[leaf]!.weight, now.tree[leaf]!.weight)) }
    #expect(isClose(desktopAfterTheBorrowerWent(workspace), workspace.tree[desktop]!.weight + 0.05))
    #expect(workspace.tree.invariantViolations().isEmpty)
  }
}
