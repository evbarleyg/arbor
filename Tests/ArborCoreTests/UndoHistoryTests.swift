import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let main = DisplayID("main")
private let side = DisplayID("side")

/// A workspace with `count` windows docked in a row, so that workspaces with different counts differ.
private func row(_ count: UInt32) -> Workspace {
  var workspace = Workspace()
  for raw in 0..<count { workspace.dock(WindowID(100 + raw), at: .cameraEdge(.right)) }
  return workspace
}

private func change(_ before: UInt32, _ after: UInt32) -> UndoHistory.Change {
  UndoHistory.Change(before: row(before), after: row(after))
}

@Suite struct UndoHistoryTests {
  @Test func stepsComeBackNewestFirst() {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1)])
    history.record("two", changes: [main: change(1, 2)])
    #expect(history.steps(.undo, on: main).map(\.label) == ["one", "two"])

    let newest = history.take(.undo, on: main)
    #expect(newest.keys.sorted() == [main])
    #expect(newest[main]?.label == "two")
    #expect(newest[main]?.workspace == row(1))
    #expect(newest[main]?.changedTo == row(2))
    #expect(history.take(.undo, on: main)[main]?.label == "one")
    #expect(history.take(.undo, on: main).isEmpty)
    #expect(history.take(.redo, on: main).isEmpty)
  }

  @Test func aNewChangeClearsRedoOnTheDisplaysItTouches() throws {
    var history = UndoHistory()
    history.record("main", changes: [main: change(0, 1)])
    history.record("side", changes: [side: change(0, 1)])
    for display in [main, side] {
      let step = try #require(history.take(.undo, on: display)[display])
      history.push(step, to: .redo, on: display)
    }
    #expect(history.steps(.redo, on: main).count == 1)

    history.record("again", changes: [main: change(0, 2)])
    #expect(history.steps(.redo, on: main).isEmpty)
    #expect(history.steps(.redo, on: side).count == 1, "the other display can still redo")
  }

  @Test func pushingLeavesTheOtherDirectionAlone() throws {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1)])
    history.record("two", changes: [main: change(1, 2)])
    let step = try #require(history.take(.undo, on: main)[main])
    history.push(step, to: .redo, on: main)
    #expect(history.steps(.undo, on: main).map(\.label) == ["one"])
    #expect(history.steps(.redo, on: main).map(\.label) == ["two"])
  }

  @Test func onlyTheNewestFiftyStepsAreKept() {
    var history = UndoHistory()
    for index in 1...(UndoHistory.limit + 5) {
      history.record("\(index)", changes: [main: change(0, 1)])
      history.push(UndoStep(id: 1000 + index, label: "\(index)", workspace: row(0), changedTo: row(1)), to: .redo, on: side)
    }
    for steps in [history.steps(.undo, on: main), history.steps(.redo, on: side)] {
      #expect(steps.count == UndoHistory.limit)
      #expect(steps.first?.label == "6")
      #expect(steps.last?.label == "55")
    }
  }

  @Test func anEmptyChangeIsNotAStep() {
    var history = UndoHistory()
    history.record("nothing", changes: [:])
    #expect(history == UndoHistory())
  }

  @Test func changesUnderOneKeyBecomeOneStep() {
    var history = UndoHistory()
    history.record("drag", changes: [main: change(0, 1)], continuing: "seam 1")
    history.record("drag", changes: [main: change(1, 2)], continuing: "seam 1")
    history.record("drag", changes: [main: change(2, 3)], continuing: "seam 1")
    let steps = history.steps(.undo, on: main)
    #expect(steps.count == 1)
    #expect(steps.first?.workspace == row(0), "it goes back to before the first move")
    #expect(steps.first?.changedTo == row(3), "and knows where the last one ended")
  }

  @Test func aContinuationEndsWhenItIsFinishedOrSomethingElseHappens() {
    var history = UndoHistory()
    history.record("drag", changes: [main: change(0, 1)], continuing: "seam 1")
    history.record("drag", changes: [main: change(1, 2)], continuing: "seam 2")
    #expect(history.steps(.undo, on: main).count == 2, "another key is another step")

    history.record("dock", changes: [main: change(2, 3)])
    history.record("drag", changes: [main: change(3, 4)], continuing: "seam 2")
    #expect(history.steps(.undo, on: main).count == 4, "a step in between ends it")

    history.finishContinuation("seam 1")
    history.record("drag", changes: [main: change(4, 5)], continuing: "seam 2")
    #expect(history.steps(.undo, on: main).count == 4, "finishing another key does not")

    history.finishContinuation("seam 2")
    history.record("drag", changes: [main: change(5, 6)], continuing: "seam 2")
    #expect(history.steps(.undo, on: main).count == 5)

    history.finishContinuation()
    history.record("drag", changes: [main: change(6, 7)], continuing: "seam 2")
    #expect(history.steps(.undo, on: main).count == 6, "no key finishes them all")
  }

  @Test func aContinuationOnAnotherDisplayIsItsOwnStep() {
    var history = UndoHistory()
    history.record("drag", changes: [main: change(0, 1)], continuing: "key")
    history.record("drag", changes: [side: change(0, 1)], continuing: "key")
    #expect(history.steps(.undo, on: main).count == 1)
    #expect(history.steps(.undo, on: side).count == 1)
    #expect(history.steps(.undo, on: main).first?.changedTo == row(1))
  }

  @Test func aChangeToTwoDisplaysIsTakenFromBothAtOnce() {
    var history = UndoHistory()
    history.record("across", changes: [main: change(1, 0), side: change(0, 1)])
    let taken = history.take(.undo, on: side)
    #expect(taken.keys.sorted() == [main, side])
    #expect(taken[main]?.id == taken[side]?.id)
    #expect(taken[main]?.workspace == row(1))
    #expect(taken[side]?.workspace == row(0))
    #expect(history.steps(.undo, on: main).isEmpty)
  }

  @Test func aDisplayThatChangedAgainKeepsItsHalfUntilItsTurn() {
    var history = UndoHistory()
    history.record("across", changes: [main: change(1, 0), side: change(0, 1)])
    history.record("later", changes: [main: change(0, 2)])
    #expect(history.take(.undo, on: side).keys.sorted() == [side])
    #expect(history.steps(.undo, on: main).map(\.label) == ["across", "later"])
    #expect(history.take(.undo, on: main)[main]?.label == "later")
    #expect(history.take(.undo, on: main).keys.sorted() == [main], "its other half is gone; it goes alone")
  }

  @Test func separateChangesHaveSeparateIDs() {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1)])
    history.record("two", changes: [side: change(0, 1)])
    #expect(history.take(.undo, on: main).keys.sorted() == [main])
    #expect(history.steps(.undo, on: side).count == 1)
  }

  @Test func whatCannotBeTakenBackIsKeptAsAStepThatSaysSo() {
    var history = UndoHistory()
    history.record("dock", changes: [main: change(0, 1)])
    history.recordIrreversible("the closing of w5", leaving: [main: row(0)])
    #expect(history.steps(.undo, on: main).map(\.isIrreversible) == [false, true])
    let taken = history.take(.undo, on: main)
    #expect(taken[main]?.label == "the closing of w5")
    #expect(taken[main]?.isIrreversible == true)
    #expect(history.take(.undo, on: main)[main]?.label == "dock")
  }

  @Test func severalIrreversibleChangesInARowCountAsOne() {
    var history = UndoHistory()
    history.record("dock", changes: [main: change(0, 3)])
    for left: UInt32 in [2, 1, 0] { history.recordIrreversible("the closing of w\(left)", leaving: [main: row(left)]) }
    #expect(history.steps(.undo, on: main).map(\.label) == ["dock", "the closing of w0"])
    history.record("dock", changes: [main: change(0, 1)])
    history.recordIrreversible("exclude", leaving: [main: row(0)])
    #expect(history.steps(.undo, on: main).map(\.isIrreversible) == [false, true, false, true])
  }

  @Test func anIrreversibleChangeLeavesRedoAloneAndEndsAContinuation() throws {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1)])
    let step = try #require(history.take(.undo, on: main)[main])
    history.push(step, to: .redo, on: main)
    history.record("drag", changes: [side: change(0, 1)], continuing: "key")
    history.recordIrreversible("exclude", leaving: [main: row(0), side: row(0)])
    #expect(history.steps(.redo, on: main).count == 1)
    history.record("drag", changes: [side: change(0, 2)], continuing: "key")
    #expect(history.steps(.undo, on: side).map(\.label) == ["drag", "exclude", "drag"])
    history.recordIrreversible("nothing", leaving: [:])
    #expect(history.steps(.undo, on: side).count == 3)
  }

  @Test func anIrreversibleChangeToTwoDisplaysIsTakenFromBoth() {
    var history = UndoHistory()
    history.recordIrreversible("exclude", leaving: [main: row(0), side: row(0)])
    #expect(history.take(.undo, on: side).keys.sorted() == [main, side])
    #expect(history.steps(.undo, on: main).isEmpty)
  }

  @Test func aDisconnectedDisplayIsForgotten() throws {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1), side: change(0, 1)])
    history.record("two", changes: [side: change(1, 2)])
    let step = try #require(history.take(.undo, on: side)[side])
    history.push(step, to: .redo, on: side)
    history.removeAll(on: side)
    #expect(history.steps(.undo, on: side).isEmpty)
    #expect(history.steps(.redo, on: side).isEmpty)
    #expect(history.steps(.undo, on: main).count == 1)
  }

  @Test func aStepHasATitleForTheMenu() {
    #expect(UndoStep.title(from: "dock w101 left") == "Dock")
    #expect(UndoStep.title(from: "float-all here") == "Float All")
    #expect(UndoStep.title(from: "") == "")
    var history = UndoHistory()
    history.record("swap w101 left", changes: [main: change(0, 1)])
    history.record("drag the gap between a and b", title: "Resize", changes: [main: change(1, 2)])
    #expect(history.steps(.undo, on: main).map(\.title) == ["Swap", "Resize"])
  }

  @Test func aChangeNobodyAskedForLeavesRedoAlone() throws {
    var history = UndoHistory()
    history.record("one", changes: [main: change(0, 1)])
    history.push(try #require(history.take(.undo, on: main)[main]), to: .redo, on: main)
    history.record("by a rule", changes: [main: change(0, 2)], keepingRedo: true)
    #expect(history.steps(.undo, on: main).map(\.label) == ["by a rule"])
    #expect(history.steps(.redo, on: main).map(\.label) == ["one"])
  }

  @Test func everyStepFollowsAWindowThatChangesItsNumber() throws {
    let (old, new) = (WindowID(100), WindowID(900))
    let spot = CGRect(x: 10, y: 20, width: 300, height: 200)
    var floating = row(0)
    floating.floating[old] = spot
    var history = UndoHistory()
    history.record("dock", changes: [main: .init(before: floating, framesBefore: [old: spot], after: row(1))])
    history.record("more", changes: [main: change(1, 2)])
    history.record("elsewhere", changes: [side: change(0, 3)])
    history.push(try #require(history.take(.undo, on: side)[side]), to: .redo, on: side)
    history.renumber(old, as: new)

    let steps = history.steps(.undo, on: main) + history.steps(.redo, on: side)
    #expect(steps.count == 3)
    for step in steps {
      #expect(!step.workspace.contains(old) && !step.changedTo.contains(old) && step.frames[old] == nil)
      #expect(step.changedTo.isDocked(new))
    }
    #expect(steps[0].workspace.floating == [new: spot])
    #expect(steps[0].frames == [new: spot])
    #expect(steps[1].workspace.tree.allWindows == [new])
    #expect(steps[1].changedTo.tree.allWindows == [new, WindowID(101)], "in the same place")
  }
}

@Suite struct TreeComparisonTests {
  /// [a | Desktop | b]
  func columns() -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: tree.root, edge: .right)
    return tree
  }

  @Test func theSameTreeIsTheSameArrangement() {
    #expect(columns().hasSameArrangement(as: columns()))
    #expect(LayoutTree().hasSameArrangement(as: LayoutTree()))
  }

  @Test func windowsOrderWeightsAndNestingCount() {
    let tree = columns()
    let leafA = tree.leaf(containing: a)!
    let leafB = tree.leaf(containing: b)!

    var docked = tree
    docked.dock(c, beside: leafA, edge: .bottom)
    #expect(!tree.hasSameArrangement(as: docked))
    #expect(!docked.hasSameArrangement(as: tree))

    var removed = tree
    removed.remove(b)
    #expect(!tree.hasSameArrangement(as: removed))

    var swapped = tree
    swapped.swapSiblings(leafA, leafB)
    #expect(!tree.hasSameArrangement(as: swapped))

    var resized = tree
    resized.moveBoundary(leading: leafA, trailing: tree.desktop, by: 50, pointsPerWeight: 400)
    #expect(!tree.hasSameArrangement(as: resized))

    var exchanged = tree
    exchanged.swapLeaves(of: a, and: b)
    #expect(!tree.hasSameArrangement(as: exchanged))

    var stacked = tree
    stacked.addToStack(c, leaf: leafA)
    #expect(!tree.hasSameArrangement(as: stacked))
  }

  @Test func theTabThatIsShowingDoesNotCount() {
    var tree = columns()
    tree.addToStack(c, leaf: tree.leaf(containing: a)!)
    var switched = tree
    switched.activate(a)
    #expect(tree != switched)
    #expect(tree.hasSameArrangement(as: switched))
  }

  @Test func aNodeThatSurvivedAChangeIsTheSameNode() {
    let tree = columns()
    var changed = tree
    let leafC = changed.dock(c, beside: changed.leaf(containing: a)!, edge: .bottom)
    for node in tree.preorder() {
      #expect(tree.isSameNode(node, in: changed), "\(node)")
      #expect(changed.isSameNode(node, in: tree), "\(node)")
    }
    #expect(!changed.isSameNode(leafC, in: tree))
    #expect(!changed.isSameNode(changed.parent(of: leafC)!, in: tree))
    #expect(!tree.isSameNode(NodeID(99), in: changed))
  }

  @Test func aNumberUsedAgainByANewTreeIsNotTheSameNode() {
    // Both trees number their nodes from 1, and have nothing to do with each other.
    var old = LayoutTree()
    let oldLeaf = old.dock(a, beside: old.root, edge: .left)  // n1 holds a
    let oldColumnLeaf = old.dock(b, beside: oldLeaf, edge: .bottom)  // n3 holds b, n4 is the column
    let fresh = LayoutTree.grid(of: [c, d, a, b])  // n1 holds c, n3 holds d, n4 is the column [c / d]
    #expect(fresh.leaf(containing: c) == oldLeaf)
    #expect(fresh.leaf(containing: d) == oldColumnLeaf)
    #expect(!old.isSameNode(oldLeaf, in: fresh), "another window")
    #expect(!old.isSameNode(old.parent(of: oldLeaf)!, in: fresh), "a column of other windows")
    #expect(old.isSameNode(old.desktop, in: fresh), "there is only one Desktop")
    #expect(old.isSameNode(old.root, in: fresh), "both show everything")
  }

  @Test func kindAndAxisMustMatch() {
    var row = LayoutTree()
    row.dock(a, beside: row.root, edge: .left)  // n2 is a row
    var column = LayoutTree()
    column.dock(a, beside: column.root, edge: .top)  // n2 is a column
    #expect(row.root == column.root)
    #expect(!row.isSameNode(row.root, in: column))

    var leafThere = LayoutTree()
    leafThere.dock(b, beside: leafThere.root, edge: .left)
    leafThere.dock(a, beside: leafThere.root, edge: .right)  // n3 holds a
    var splitThere = LayoutTree()
    let first = splitThere.dock(b, beside: splitThere.root, edge: .left)
    splitThere.remove(b)
    _ = first
    splitThere.dock(a, beside: splitThere.root, edge: .left)  // n3 holds a, n4 is the row
    #expect(leafThere.isSameNode(NodeID(3), in: splitThere))
    #expect(!leafThere.isSameNode(NodeID(2), in: splitThere), "n2 no longer exists there")
  }
}

@Suite struct WorkspaceRestoreTests {
  let spot = CGRect(x: 100, y: 100, width: 300, height: 200)

  /// [a | Desktop | b] with c floating.
  func base() -> Workspace {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.floating[c] = spot
    return workspace
  }

  @Test func arrangementIsTheTreeAndWhoFloats() {
    let workspace = base()
    var other = workspace
    other.moveCamera(to: workspace.tree.leaf(containing: a)!)
    other.saveView(slot: 1)
    other.floating[c] = spot.offsetBy(dx: 40, dy: 0)
    #expect(workspace.hasSameArrangement(as: other), "the camera, views and floating frames do not count")

    other.floating[d] = spot
    #expect(!workspace.hasSameArrangement(as: other))
    other.floating[d] = nil
    other.floating[c] = nil
    #expect(!workspace.hasSameArrangement(as: other))
    other.floating[d] = spot
    #expect(!workspace.hasSameArrangement(as: other), "as many floating windows, but not the same ones")

    var undocked = workspace
    undocked.undock(b, floatingAt: spot)
    #expect(!workspace.hasSameArrangement(as: undocked))
  }

  @Test func withNothingDoneSinceEverythingComesBack() {
    // The camera is on a, with history and a saved view there. Floating a moves them all.
    var before = base()
    let leaf = before.tree.leaf(containing: a)!
    before.moveCamera(to: leaf)
    before.saveView(slot: 1)
    var after = before
    after.undock(a, floatingAt: spot)
    #expect(after.camera != leaf)
    #expect(after.savedViews["1"] != leaf)
    #expect(before.restored(over: after, since: after) == before)
  }

  @Test func aNewTreeIsUndoneWithCameraHistoryAndViews() {
    var before = base()
    before.moveCamera(to: before.tree.leaf(containing: b)!)
    before.saveView(slot: 3)
    var after = before
    after.reset(tree: .grid(of: [a, b, c]))
    after.floating[c] = nil
    #expect(after.back.isEmpty && after.savedViews.isEmpty)
    #expect(before.restored(over: after, since: after) == before)
  }

  @Test func aCameraMovedSinceStaysWhereItIs() {
    let before = base()
    var after = before
    after.dock(c, at: .cameraEdge(.right))
    var current = after
    let leafA = current.tree.leaf(containing: a)!
    current.moveCamera(to: leafA)
    let restored = before.restored(over: current, since: after)
    #expect(restored.camera == leafA)
    #expect(restored.back == [before.tree.root])
    #expect(restored.tree == before.tree)
    #expect(restored.floating == before.floating)
  }

  @Test func aCameraOnANodeThatGoesAwayReturnsToWhereItWas() {
    var before = base()
    let leafB = before.tree.leaf(containing: b)!
    before.moveCamera(to: leafB)
    var after = before
    after.dock(c, at: .beside(before.tree.leaf(containing: a)!, .bottom))
    var current = after
    let leafC = current.tree.leaf(containing: c)!
    current.moveCamera(to: current.tree.leaf(containing: a)!)
    current.moveCamera(to: leafC)
    let restored = before.restored(over: current, since: after)
    #expect(restored.camera == leafB, "c's leaf does not exist in the restored tree")
    #expect(restored.back.allSatisfy { restored.tree.contains($0) })
    #expect(restored.back.contains(before.tree.leaf(containing: a)!), "places that still exist stay in history")
    #expect(!restored.back.contains(leafC))
  }

  @Test func afterANewTreeOnlyPlacesThatAreReallyTheSameSurvive() {
    var before = base()
    before.moveCamera(to: before.tree.leaf(containing: b)!)
    var after = before
    after.reset(tree: .grid(of: [c, b, a]))
    after.floating[c] = nil
    var current = after
    // n1 holds c in the new tree and a in the old one.
    current.moveCamera(to: current.tree.leaf(containing: c)!)
    current.saveView(slot: 5)
    #expect(current.camera == before.tree.leaf(containing: a))
    let restored = before.restored(over: current, since: after)
    #expect(restored.camera == before.camera)
    #expect(restored.savedViews["5"] == nil)
  }

  @Test func viewsSavedSinceAreKeptIfTheirNodeIsStillThere() {
    var before = base()
    before.saveView(slot: 1)  // everything
    var after = before
    after.dock(c, at: .cameraEdge(.right))
    var current = after
    current.moveCamera(to: current.tree.leaf(containing: a)!)
    current.saveView(slot: 2)
    current.moveCamera(to: current.tree.leaf(containing: c)!)
    current.saveView(slot: 3)
    current.saveView(slot: 1)  // saved over, on a node that will go away
    let restored = before.restored(over: current, since: after)
    #expect(restored.savedViews == ["1": before.tree.root, "2": before.tree.leaf(containing: a)!])
  }

  @Test func floatingWindowsMovedSinceStayWhereTheyWerePut() {
    var before = base()
    before.floating[d] = spot
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    var current = after
    let moved = spot.offsetBy(dx: 200, dy: 50)
    current.floating[c] = moved
    let restored = before.restored(over: current, since: after)
    #expect(restored.floating == [c: moved, d: spot])
  }

  @Test func theTabSwitchedToSinceKeepsShowing() {
    var before = base()
    let stack = before.tree.leaf(containing: a)!
    before.dock(d, at: .stack(stack))
    #expect(before.tree.activeWindow(of: stack) == d)
    var after = before
    after.tree.moveBoundary(leading: stack, trailing: before.tree.desktop, by: 60, pointsPerWeight: 400)

    #expect(before.restored(over: after, since: after).tree.activeWindow(of: stack) == d)
    var current = after
    current.tree.activate(a)
    let restored = before.restored(over: current, since: after)
    #expect(restored.tree.activeWindow(of: stack) == a)
    #expect(restored.tree.hasSameArrangement(as: before.tree))
  }

  @Test func aTabThatIsNotInTheRestoredStackIsNotShown() {
    // The change being undone added d to the stack; d is showing now.
    let before = base()
    let stack = before.tree.leaf(containing: a)!
    var after = before
    after.dock(d, at: .stack(stack))
    var current = after
    current.tree.activate(a)
    current.tree.activate(d)
    #expect(before.restored(over: current, since: after).tree == before.tree)
  }

  // MARK: Guests

  @Test func whoIsAGuestIsNotArrangement() {
    let workspace = base()
    var other = workspace
    other.receive(c, asGuestOf: workspace.tree.leaf(containing: a)!)
    #expect(other.guests != nil)
    #expect(workspace.hasSameArrangement(as: other))
  }

  @Test func aChangeThatEndedAVisitIsUndoneWithIt() {
    var before = base()
    before.receive(c, asGuestOf: before.tree.leaf(containing: a)!)
    var after = before
    after.dock(c, at: .cameraEdge(.right))
    #expect(after.guests == nil)
    #expect(before.restored(over: after, since: after) == before)
  }

  @Test func aWindowThatBecameAGuestSinceStaysOneWhileItsHostIsThere() {
    // The change being undone docked d. Since then c, which floats on both sides of it, became a guest.
    var before = base()
    before.floating[d] = spot
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    let host = after.tree.leaf(containing: a)!
    var current = after
    current.receive(c, asGuestOf: host)
    #expect(before.restored(over: current, since: after).guests == [c: host])

    // A guest of what the undo takes away is an ordinary floating window again.
    current.receive(c, asGuestOf: after.tree.leaf(containing: d)!)
    #expect(before.restored(over: current, since: after).guests == nil)
  }

  @Test func aHostIsAPlaceNotANumber() throws {
    // The change being undone started a new tree, which numbers its nodes from 1 again.
    let before = base()
    var after = before
    after.reset(tree: .grid(of: [b, a], desktopWeight: 0.2))
    let host = try #require(
      after.tree.preorder().first { after.tree.isStack($0) && before.tree.isStack($0) && !after.tree.isSameNode($0, in: before.tree) },
      "no number is used by both trees for different windows")
    var current = after
    current.receive(c, asGuestOf: host)
    #expect(current.guests == [c: host])
    #expect(before.restored(over: current, since: after).guests == nil, "not a guest of whatever has that number in the old tree")
  }

  @Test func aVisitThatEndedSinceStaysOver() {
    var before = base()
    before.floating[d] = spot
    before.receive(c, asGuestOf: before.tree.leaf(containing: a)!)
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    #expect(after.guests != nil)
    var current = after
    current.endVisit(of: c)
    #expect(before.restored(over: current, since: after).guests == nil)
  }

  // MARK: Pins

  @Test func whoIsPinnedIsNotArrangement() {
    let workspace = base()
    var other = workspace
    other.pin(c)
    #expect(workspace.hasSameArrangement(as: other))
  }

  @Test func aChangeThatEndedAPinIsUndoneWithIt() {
    var before = base()
    before.pin(c)
    var after = before
    after.dock(c, at: .cameraEdge(.right))
    #expect(after.pinned == nil)
    #expect(before.restored(over: after, since: after) == before)
  }

  @Test func pinsSetAndTakenAwaySinceStaySo() {
    // The change being undone docked d. c was pinned on both sides of it.
    var before = base()
    before.floating[d] = spot
    before.pin(c)
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    var current = after
    current.unpin(c)
    #expect(before.restored(over: current, since: after).pinned == nil)

    var unpinned = before
    unpinned.unpin(c)
    var left = unpinned
    left.dock(d, at: .cameraEdge(.right))
    current = left
    current.pin(c)
    #expect(unpinned.restored(over: current, since: left).pinned == [c])
  }

  @Test func onlyAWindowThatFloatsInTheRestoredWorkspaceIsPinned() {
    // The change being undone floated b, which was pinned afterwards.
    let before = base()
    var after = before
    after.undock(b, floatingAt: spot)
    var current = after
    current.pin(b)
    let restored = before.restored(over: current, since: after)
    #expect(restored.isDocked(b))
    #expect(restored.pinned == nil)
  }

  // MARK: Summoned and stashed windows

  @Test func whoIsSummonedOrStashedIsNotArrangement() {
    let workspace = base()
    var other = workspace
    other.summon(c, app: "Mail", at: spot)
    #expect(workspace.hasSameArrangement(as: other))
    other.dismissSummon()
    #expect(other.isStashed(c))
    #expect(workspace.hasSameArrangement(as: other))
  }

  @Test func whatWasSummonedOrSentAwaySinceStaysSo() {
    // The change being undone docked d.
    var before = base()
    before.floating[d] = spot
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    var current = after
    let place = spot.offsetBy(dx: 30, dy: 30)
    current.summon(c, app: "Mail", at: place)
    var restored = before.restored(over: current, since: after)
    #expect(restored.isSummoned(c) && restored.summonFrames == ["Mail": place])
    #expect(restored.floating[c] == place)

    current.dismissSummon()
    restored = before.restored(over: current, since: after)
    #expect(restored.summoned == nil && restored.isStashed(c))

    // And the other way round: stashed on both sides of the change, an ordinary floating window since.
    var stashed = before
    stashed.summon(c, app: "Mail", at: spot)
    stashed.dismissSummon()
    var left = stashed
    left.dock(d, at: .cameraEdge(.right))
    #expect(stashed.restored(over: left, since: left) == stashed)
    current = left
    current.forgetSummon(of: c)
    #expect(stashed.restored(over: current, since: left).stashed == nil)
  }

  @Test func aFloatingWindowHasOneRoleAtMostAndWhenInDoubtIsNotStashed() {
    // c was stashed when d was docked. Since then it has been pinned.
    var before = base()
    before.floating[d] = spot
    before.summon(c, app: "Mail", at: spot)
    before.dismissSummon()
    var after = before
    after.dock(d, at: .cameraEdge(.right))
    var current = after
    current.setRole(.pinned, of: c)
    let restored = before.restored(over: current, since: after)
    #expect(restored.role(of: c) == .pinned)
    #expect(restored.stashed == nil && restored.summoned == nil)

    // The change being undone floated b, which was summoned afterwards. Docked again, it is not.
    let docked = base()
    var floated = docked
    floated.undock(b, floatingAt: spot)
    current = floated
    current.summon(b, app: "Notes", at: spot)
    #expect(docked.restored(over: current, since: floated).summoned == nil)
  }

  // MARK: What docked windows looked like before

  @Test func whatWasRememberedAboutADockedWindowComesBackWithItsSlot() {
    // b floated at `spot` before it was docked. The change being undone floated it again.
    var before = base()
    before.undock(b, floatingAt: spot)
    before.dock(b, at: .cameraEdge(.right))
    #expect(before.undockedFrame(of: b) == spot)
    var after = before
    after.undock(b, floatingAt: spot)
    #expect(after.undockedFrames == nil)
    #expect(before.restored(over: after, since: after) == before)

    // Moved since, it is docked again from where it was moved to.
    var current = after
    let moved = spot.offsetBy(dx: 70, dy: 30)
    current.floating[b] = moved
    #expect(before.restored(over: current, since: after).undockedFrame(of: b) == moved)
  }

  // MARK: A window under another number

  @Test func aDockedWindowKeepsItsPlaceUnderItsNewNumber() {
    var workspace = base()
    let leaf = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leaf)
    workspace.renumber(a, as: d)
    #expect(workspace.tree.leaf(containing: d) == leaf)
    #expect(!workspace.contains(a))
    #expect(workspace.camera == leaf)

    var remembered = base()
    remembered.dock(c, at: .cameraEdge(.right))
    remembered.renumber(c, as: d)
    #expect(remembered.undockedFrames == [d: spot])
  }

  @Test func aFloatingWindowKeepsItsFrameAndItsHostUnderItsNewNumber() {
    var workspace = base()
    let host = workspace.tree.leaf(containing: a)!
    workspace.receive(c, asGuestOf: host)
    workspace.renumber(c, as: d)
    #expect(workspace.floating == [d: spot])
    #expect(workspace.guests == [d: host])

    var pinned = base()
    pinned.pin(c)
    pinned.renumber(c, as: d)
    #expect(pinned.pinned == [d])

    var summoned = base()
    summoned.summon(c, app: "Mail", at: spot)
    summoned.renumber(c, as: d)
    #expect(summoned.role(of: d) == .summoned(app: "Mail"))
    summoned.dismissSummon()
    summoned.renumber(d, as: c)
    #expect(summoned.role(of: c) == .stashed)
  }

  @Test func theNewNumberLosesAPlaceOfItsOwn() {
    var docked = base()
    docked.renumber(a, as: b)
    #expect(docked.tree.allWindows == [b])
    #expect(docked.tree.invariantViolations().isEmpty)

    var floating = base()
    floating.renumber(a, as: c)
    #expect(floating.tree.allWindows == [c, b])
    #expect(floating.floating.isEmpty)
  }

  @Test func aNumberThatIsNotHereChangesNothing() {
    var workspace = base()
    workspace.renumber(d, as: a)
    workspace.renumber(a, as: a)
    #expect(workspace == base())
  }
}

/// Undo keeps whole workspaces and puts them back later, so every field of `Workspace` meets it, whoever adds the field.
@Suite struct WorkspaceFieldsAndUndoTests {
  private func source(_ path: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
  }

  /// What stands between the braces of the function declared with `declaration`, comments included.
  private func body(of declaration: String, in text: String) throws -> String {
    let start = try #require(text.range(of: declaration), "`\(declaration)` has moved or changed")
    var depth = 0
    var body = ""
    for character in text[start.upperBound...] {
      if character == "}" {
        depth -= 1
        if depth == 0 { break }
      }
      if depth > 0 { body.append(character) }
      if character == "{" { depth += 1 }
    }
    return body
  }

  private func names(_ field: String, in text: String) -> Bool {
    // By default `current.camera` is one word to a Regex (Unicode's rule for full stops between letters).
    text.contains(try! Regex("\\b\(field)\\b").wordBoundaryKind(.simple))
  }

  /// **If this fails, you have added a stored property to `Workspace`.** An undo step is a copy of the whole workspace, so
  /// your field is saved and put back without any code, which is right only straight after the change. Later,
  /// putting back the old value throws away whatever happened to the field since. Decide, by the rule
  /// in docs/ARCHITECTURE.md ("Undo and redo", "A new field in `Workspace`"), and write the answer into
  /// `Workspace.restored(over:since:)`: code that carries it over, or a comment there that names the field
  /// and says why the old value is the right one.
  @Test func everyStoredPropertyOfAWorkspaceIsDealtWithWhenAnOldOneIsPutBack() throws {
    let stored = Mirror(reflecting: Workspace()).children.compactMap(\.label)
    #expect(stored.count >= 14, "Mirror no longer lists the stored properties")
    let restoring = try body(
      of: "public func restored(over current: Workspace, since reference: Workspace) -> Workspace",
      in: try source("Sources/ArborCore/Workspace.swift"))
    for field in stored {
      #expect(
        names(field, in: restoring),
        """
        `Workspace.\(field)` is not mentioned in `Workspace.restored(over:since:)`, so `undo` puts back the value it had before the \
        change that is undone and drops what happened to it since. See docs/ARCHITECTURE.md, "A new field in `Workspace`".
        """)
    }
  }

  /// **If this fails, you have added a stored property to `Workspace`.** Steps are kept for a long time, and a window can change its number
  /// meanwhile (a waiting slot is taken, a native tab comes to the front). If your field holds window numbers, as a key, a value or
  /// inside something, teach `Workspace.renumber(_:as:)` to move them, give `everyTraceOfAWindowFollowsItsNewNumber` a sample that fills
  /// the field, and put its name on the first list. If it holds none, put it on the second.
  @Test func everyStoredPropertyThatHoldsWindowNumbersIsKnownToRenumber() {
    let holdsWindows: Set = ["tree", "floating", "pinned", "guests", "undockedFrames", "summoned", "stashed"]
    let holdsNone: Set = ["camera", "back", "forward", "savedViews", "summonFrames", "names", "desktopIsOwedRoom"]
    let stored = Set(Mirror(reflecting: Workspace()).children.compactMap(\.label))
    #expect(stored.subtracting(holdsWindows).subtracting(holdsNone) == [], "on neither list")
    #expect(holdsWindows.union(holdsNone).subtracting(stored) == [], "gone from `Workspace`: take it off the list")
  }

  @Test func everyTraceOfAWindowFollowsItsNewNumber() throws {
    // Numbers that no node and no coordinate has, so that they can be looked for in what is saved.
    let (old, new, other) = (WindowID(987_654), WindowID(876_543), WindowID(765_432))
    let spot = CGRect(x: 10, y: 20, width: 300, height: 200)
    var docked = Workspace()
    docked.floating[old] = spot
    docked.dock(other, at: .cameraEdge(.left))
    docked.dock(old, at: .cameraEdge(.right))
    #expect(docked.undockedFrames?[old] != nil)
    func floating(_ prepare: (inout Workspace) -> Void) -> Workspace {
      var workspace = Workspace()
      workspace.dock(other, at: .cameraEdge(.left))
      workspace.floating[old] = spot
      prepare(&workspace)
      return workspace
    }
    let samples = [
      docked, floating { _ in }, floating { $0.pin(old) },
      floating { $0.receive(old, asGuestOf: $0.tree.leaf(containing: other)!) },
      floating { $0.summon(old, app: "Mail", at: spot) },
      floating {
        $0.summon(old, app: "Mail", at: spot)
        $0.dismissSummon()
      },
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for sample in samples {
      var renumbered = sample
      renumbered.renumber(old, as: new)
      let before = String(decoding: try encoder.encode(sample), as: UTF8.self)
      let after = String(decoding: try encoder.encode(renumbered), as: UTF8.self)
      #expect(before.contains("987654"))
      #expect(after == before.replacingOccurrences(of: "987654", with: "876543"), "the same workspace, but for the number")
    }
  }

  @Test func theReaderOfTheFunctionFindsWhatIsThere() throws {
    let text = """
      func other() { let pinned = 1 }
      func wanted() -> Int {
        // names: kept as they were
        if true { return current.camera }
      }
      func later() { stashed() }
      """
    let found = try body(of: "func wanted() -> Int", in: text)
    #expect(names("camera", in: found) && names("names", in: found))
    #expect(!names("pinned", in: found) && !names("stashed", in: found) && !names("name", in: found))
  }
}

@Suite struct UndoCommandTests {
  @Test func undoAndRedoParseAndRoundTrip() throws {
    #expect(try Command.parse("undo") == .undo)
    #expect(try Command.parse("Redo") == .redo)
    #expect(try Command.parse(Command.undo.text) == .undo)
    #expect(try Command.parse(Command.redo.text) == .redo)
    #expect(throws: Command.ParseError.self) { try Command.parse("undo 3") }
    #expect(throws: Command.ParseError.self) { try Command.parse("redo all") }
    #expect(!Command.undo.isQuery && !Command.redo.isQuery)
    #expect(Command.helpText.contains("undo | redo"))
  }

  @Test func labelsNameTheWindowTheCommandActedOn() {
    let focused = WindowID(101)
    #expect(Command.dock(nil, .left).label(focused: focused) == "dock w101 left")
    #expect(Command.dock(WindowID(7), .top).label(focused: focused) == "dock w7 top")
    #expect(Command.dockBeside(nil, target: WindowID(8), .bottom).label(focused: focused) == "dock w101 beside w8 bottom")
    #expect(Command.float(nil).label(focused: focused) == "float w101")
    #expect(Command.toggleFloat(WindowID(9)).label(focused: focused) == "toggle-float w9")
    #expect(Command.resize(nil, .right, 40).label(focused: focused) == "resize w101 right")
    #expect(Command.resize(WindowID(3), .left, -25.5).label(focused: nil) == "resize w3 left")
    #expect(Command.float(nil).label(focused: nil) == "float")
    #expect(Command.arrange.label(focused: focused) == "arrange")
    #expect(Command.floatAll.label(focused: focused) == "float-all")
  }

  @Test func noLabelHoldsPartOfATitleOrTheNameOfASpace() throws {
    // Replies quote labels and are logged, long after anybody could tell that a word in one was a name.
    let labels = [
      "layout Safari~Zebra | Mail": "layout Safari~… | Mail", "layout --open Safari~Zebra": "layout --open Safari~…",
      "name Zebra": "name", "unname Zebra": "unname", "unname": "unname", "go Zebra": "go", "find Zebra": "find …",
      "rule add com.example.a float title Zebra": "rule", "bind ctrl+opt+2 layout Safari~Zebra | Mail": "bind",
    ]
    for (text, label) in labels.sorted(by: { $0.key < $1.key }) {
      #expect(try Command.parse(text).label(focused: nil) == label, "\(text)")
    }
    // Whoever adds a verb to the list of those that can hold such words finds its label short without doing anything.
    for verb in Set(labels.keys.map { $0.prefix { $0 != " " } }) where verb != "find" {
      #expect(Command.mayHoldPrivateWords(verb: verb), "\(verb)")
    }
  }

  @Test func onlySmallAdjustmentsMergeWithTheirRepeats() {
    #expect(Command.resize(nil, .right, 10).mergesWithRepeats)
    for command: Command in [.dock(nil, .left), .float(nil), .toggleFloat(nil), .arrange, .floatAll, .undo, .showAll] {
      #expect(!command.mergesWithRepeats, "\(command.text)")
    }
  }

  @Test func theFocusedWindowIsOnlyAskedForWhenItIsNeeded() {
    var asked = 0
    func focused() -> WindowID? {
      asked += 1
      return WindowID(101)
    }
    _ = Command.showAll.label(focused: focused())
    _ = Command.dock(WindowID(7), .left).label(focused: focused())
    #expect(asked == 0)
    _ = Command.dock(nil, .left).label(focused: focused())
    #expect(asked == 1)
  }
}
