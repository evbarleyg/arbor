import ArborCore
import CoreGraphics
import Testing

// An independent review of F33: `shareRemovedSpace` false on trees nobody drew by hand. Nested splits, uneven
// weights, several windows absent at once, the first child, the Desktop as the neighbour.

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

/// A small repeatable random number generator, so that a failure can be run again.
private struct Dice {
  var state: UInt64
  mutating func roll(_ sides: Int) -> Int {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((state >> 33) % UInt64(sides))
  }
}

/// `count` windows docked beside nodes picked at random, then every boundary moved at random.
private func randomTree(_ dice: inout Dice, windows count: Int) -> LayoutTree {
  var tree = LayoutTree()
  for raw in 1...count {
    let nodes = tree.preorder()
    tree.dock(WindowID(UInt32(raw)), beside: nodes[dice.roll(nodes.count)], edge: Edge.allCases[dice.roll(4)])
  }
  for split in tree.preorder() where tree.isSplit(split) {
    let children = tree.children(of: split)
    for (leading, trailing) in zip(children, children.dropFirst()) {
      let share = (tree[leading]!.weight + tree[trailing]!.weight) / 3
      tree.moveBoundary(
        leading: leading, trailing: trailing, by: share * Double(dice.roll(200) - 100) / 100, pointsPerWeight: 1,
        minimumPoints: share / 2)
    }
  }
  return tree
}

private func keep(gap: CGFloat) -> LayoutOptions {
  // No tiles, so that narrow slots keep their windows.
  LayoutOptions(gap: gap, minimumUsableSize: .zero, shareRemovedSpace: false)
}

private func layout(_ tree: LayoutTree, gap: CGFloat, without absent: Set<WindowID>) -> Layout {
  LayoutEngine.layout(tree, camera: tree.root, in: screen, options: keep(gap: gap), isPresent: { !absent.contains($0) })
}

/// Every window's frame and the Desktop's (under window 0, which no window has).
private func places(_ layout: Layout) -> [WindowID: CGRect] {
  var places = layout.windowFrames
  places[WindowID(0)] = layout.desktopFrame
  return places
}

/// Whether every slot has some size. A share worth less than one gap has no room for a slot at all (its slot is
/// empty and the gap after it is cut short); such trees are left to `aRowTooShortForItsGapsStillLaysOut`.
private func hasRoom(_ layout: Layout) -> Bool {
  layout.nodeFrames.values.allSatisfy { $0.width >= 2 && $0.height >= 2 }
}

private func near(_ a: CGRect?, _ b: CGRect?, _ tolerance: CGFloat) -> Bool {
  guard let a, let b else { return a == nil && b == nil }
  return abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance && abs(a.maxX - b.maxX) <= tolerance
    && abs(a.maxY - b.maxY) <= tolerance
}

@Suite struct ReviewShareRemovedSpaceTests {
  /// Who the documentation says gets the space of `window`: in the nearest split above it that still has
  /// somebody, the nearest child before its branch that takes up space, or after it if there is none. Returns
  /// that child and the branch that went.
  func heir(of window: WindowID, in tree: LayoutTree, without absent: Set<WindowID>) -> (heir: NodeID, gone: NodeID)? {
    let view = TreeView(tree: tree, isPresent: { !absent.contains($0) && $0 != window })
    guard var branch = tree.leaf(containing: window) else { return nil }
    while let parent = tree.parent(of: branch) {
      let children = tree.children(of: parent)
      let index = children.firstIndex(of: branch)!
      if let before = children[..<index].last(where: view.isEffective) { return (before, branch) }
      if let after = children[(index + 1)...].first(where: view.isEffective) { return (after, branch) }
      branch = parent
    }
    return nil
  }

  @Test(arguments: 1...60) func onlyTheHeirChangesAndItTakesExactlyTheSlotAndTheGap(seed: Int) {
    var dice = Dice(state: UInt64(seed))
    let count = 2 + dice.roll(8)
    let tree = randomTree(&dice, windows: count)
    let gap = CGFloat([0, 12, 30][dice.roll(3)])
    var absent = Set<WindowID>()
    for raw in 1...count where dice.roll(4) == 0 { absent.insert(WindowID(UInt32(raw))) }

    for raw in 1...count where !absent.contains(WindowID(UInt32(raw))) {
      let window = WindowID(UInt32(raw))
      let before = layout(tree, gap: gap, without: absent)
      let after = layout(tree, gap: gap, without: absent.union([window]))
      guard hasRoom(before) else { return }
      guard let (heir, gone) = heir(of: window, in: tree, without: absent) else {
        Issue.record("seed \(seed): the Desktop is always there, so somebody inherits")
        continue
      }
      let inside = Set(tree.windows(under: heir) + (tree.subtree(heir, contains: tree.desktop) ? [WindowID(0)] : []))
      for (other, frame) in places(before) where other != window && !inside.contains(other) {
        #expect(places(after)[other] == frame, "seed \(seed): \(other) moved when \(window) left")
      }
      // The heir covers what it had, what the branch had, and the gap between them: nothing more or less.
      #expect(
        near(after.nodeFrames[heir], before.nodeFrames[heir]!.union(before.nodeFrames[gone]!), 0),
        "seed \(seed): \(heir) after \(window) left")
    }
  }

  @Test(arguments: 1...60) func leavingForGoodLooksLikeBeingAway(seed: Int) {
    var dice = Dice(state: UInt64(seed) &+ 1000)
    let count = 2 + dice.roll(8)
    let tree = randomTree(&dice, windows: count)
    let gap = CGFloat([0, 12, 30][dice.roll(3)])
    guard hasRoom(layout(tree, gap: gap, without: [])) else { return }

    // With everybody else there. (While others are away a group can stand in for them, and shares what it
    // borrows among its members; once a collapse has made those members part of the row, only the nearest does.)
    for raw in 1...count {
      let window = WindowID(UInt32(raw))
      let away = places(layout(tree, gap: gap, without: [window]))
      var smaller = tree
      smaller.remove(window, shareSpace: false)
      #expect(smaller.invariantViolations().isEmpty, "seed \(seed)")
      let gone = places(layout(smaller, gap: gap, without: []))
      #expect(Set(away.keys) == Set(gone.keys), "seed \(seed)")
      // A column that collapses hands its rounded rectangle on, so a point of rounding is allowed.
      for (other, frame) in away { #expect(near(gone[other], frame, 1), "seed \(seed): \(other) when \(window) closed") }
    }
  }

  @Test(arguments: 1...40) func slotsFillTheScreenWithExactGapsAndNeverOverlap(seed: Int) {
    var dice = Dice(state: UInt64(seed) &+ 2000)
    let count = 1 + dice.roll(9)
    let tree = randomTree(&dice, windows: count)
    let gap = CGFloat([0, 12, 30][dice.roll(3)])
    var absent = Set<WindowID>()
    for raw in 1...count where dice.roll(3) == 0 { absent.insert(WindowID(UInt32(raw))) }
    let result = layout(tree, gap: gap, without: absent)
    let content = screen.insetBy(dx: gap, dy: gap)
    guard hasRoom(result) else { return }

    let slots = Array(places(result).values)
    for (index, slot) in slots.enumerated() {
      #expect(content.contains(slot), "seed \(seed): \(slot)")
      #expect(slot.width > 0 && slot.height > 0, "seed \(seed): \(slot)")
      for other in slots.dropFirst(index + 1) { #expect(!slot.overlaps(other), "seed \(seed)") }
    }
    for seam in result.seams {
      #expect((seam.axis == .horizontal ? seam.frame.width : seam.frame.height) == gap, "seed \(seed): \(seam.frame)")
    }
    // Nothing is left over: slots and gaps add up to the screen.
    let covered = slots.map { $0.width * $0.height }.reduce(0, +) + result.seams.map { $0.frame.width * $0.frame.height }.reduce(0, +)
    #expect(abs(covered - content.width * content.height) < 0.5, "seed \(seed)")
  }

  @Test(arguments: 1...40) func aSeamMovesByThePointsItIsDraggedAndNobodyElseMoves(seed: Int) {
    var dice = Dice(state: UInt64(seed) &+ 3000)
    let count = 2 + dice.roll(7)
    let tree = randomTree(&dice, windows: count)
    let gap = CGFloat([0, 12][dice.roll(2)])
    var absent = Set<WindowID>()
    for raw in 1...count where dice.roll(4) == 0 { absent.insert(WindowID(UInt32(raw))) }
    let before = layout(tree, gap: gap, without: absent)
    guard hasRoom(before) else { return }

    for seam in before.seams {
      let points = Double(seam.pointsPerWeight)
      // Room on both sides of the boundary in the two children's own weights.
      guard tree[seam.leading]!.weight * points > 20, tree[seam.trailing]!.weight * points > 20 else { continue }
      let delta: CGFloat = dice.roll(2) == 0 ? 7 : -7
      var moved = tree
      moved.moveBoundary(
        leading: seam.leading, trailing: seam.trailing, by: Double(delta), pointsPerWeight: points, minimumPoints: 1)
      let after = layout(moved, gap: gap, without: absent)
      let old = before.nodeFrames[seam.leading]!
      let new = after.nodeFrames[seam.leading]!
      let travelled = seam.axis == .horizontal ? new.maxX - old.maxX : new.maxY - old.maxY
      #expect(abs(travelled - delta) <= 1, "seed \(seed): the seam went \(travelled) for \(delta)")
      let touched = Set(
        tree.windows(under: seam.leading) + tree.windows(under: seam.trailing)
          + ([seam.leading, seam.trailing].contains { tree.subtree($0, contains: tree.desktop) } ? [WindowID(0)] : []))
      for (other, frame) in places(before) where !touched.contains(other) {
        #expect(places(after)[other] == frame, "seed \(seed): \(other) moved with a seam that is not beside it")
      }
    }
  }

  @Test(arguments: 1...20) func emptyingATreeOneWindowAtATimeKeepsItValidAndItsWeightsFinite(seed: Int) {
    var dice = Dice(state: UInt64(seed) &+ 4000)
    var tree = randomTree(&dice, windows: 9)
    var left = tree.allWindows
    while !left.isEmpty {
      tree.remove(left.remove(at: dice.roll(left.count)), shareSpace: false)
      #expect(tree.invariantViolations().isEmpty, "seed \(seed)")
      #expect(layout(tree, gap: 12, without: []).windowFrames.count == left.count, "seed \(seed)")
    }
    #expect(tree.root == tree.desktop)
  }

  /// Only ratios matter. Windows that left while space was shared took their weight with them, so a split's
  /// weights can add up to one or less by the time the switch is turned off.
  @Test func weightsThatAddUpToLittleStillFillTheScreen() {
    var tree = LayoutTree()
    tree.dock(WindowID(1), beside: tree.desktop, edge: .left)
    tree.dock(WindowID(2), beside: tree.desktop, edge: .right)
    tree.dock(WindowID(3), beside: tree.desktop, edge: .right)
    tree.remove(WindowID(1))
    #expect(tree.children(of: tree.root).map { tree[$0]!.weight }.reduce(0, +) <= 1)
    let result = layout(tree, gap: 12, without: [])
    #expect(result.desktopFrame == CGRect(x: 12, y: 37, width: 345, height: 851))
    #expect(result.windowFrames[WindowID(3)] == CGRect(x: 369, y: 37, width: 345, height: 851))
    #expect(result.windowFrames[WindowID(2)] == CGRect(x: 726, y: 37, width: 702, height: 851))
    #expect(result.seams.allSatisfy { $0.pointsPerWeight == 1428 })
  }

  /// A group that has a name stays when it is down to one window (F62), and goes with its last one. It is the group
  /// that leaves the row then, and the rule holds for it as for a window.
  @Test func aNamedGroupThatLosesItsLastWindowLeavesItsSpaceToTheNeighbourBefore() {
    var tree = LayoutTree()
    let c = tree.dock(WindowID(3), beside: tree.desktop, edge: .left)
    let b = tree.dock(WindowID(2), beside: c, edge: .left)
    tree.dock(WindowID(1), beside: b, edge: .left)
    tree.dock(WindowID(4), beside: b, edge: .bottom)
    let group = tree.parent(of: b)!
    tree.keep(group, for: .name)
    let before = layout(tree, gap: 12, without: [])

    tree.remove(WindowID(4), shareSpace: false)
    #expect(tree.contains(group))
    tree.remove(WindowID(2), shareSpace: false)
    #expect(!tree.contains(group))
    #expect(tree.invariantViolations().isEmpty)
    let after = layout(tree, gap: 12, without: [])
    #expect(after.windowFrames[WindowID(3)] == before.windowFrames[WindowID(3)])
    #expect(after.desktopFrame == before.desktopFrame)
    #expect(after.windowFrames[WindowID(1)] == before.windowFrames[WindowID(1)]!.union(before.nodeFrames[group]!))
  }

  /// Other features call these without the argument. They must go on sharing, as before the switch existed.
  @Test func aWorkspaceSharesUnlessToldOtherwise() {
    var workspace = Workspace()
    for raw in [3, 2, 1] as [UInt32] { workspace.dock(WindowID(raw), at: .cameraEdge(.left)) }
    func weights(_ workspace: Workspace) -> [Double] {
      workspace.tree.children(of: workspace.tree.root).map { workspace.tree[$0]!.weight }
    }
    #expect(weights(workspace) == [1, 1, 1, 1])
    var forgotten = workspace
    forgotten.forget(WindowID(2))
    #expect(weights(forgotten) == [1, 1, 1])
    var undocked = workspace
    undocked.undock(WindowID(2), floatingAt: CGRect(x: 0, y: 0, width: 400, height: 300))
    #expect(weights(undocked) == [1, 1, 1])
    var moved = workspace
    moved.dock(WindowID(2), at: .beside(workspace.tree.desktop, .bottom))
    #expect(weights(moved) == [1, 1, 1])
  }

  /// A view inside the tree: the camera's own split follows the rule too, and what is outside it does not count.
  @Test func zoomedOntoAGroupTheRuleHoldsInsideIt() {
    var tree = LayoutTree()
    let a = tree.dock(WindowID(1), beside: tree.desktop, edge: .left)
    let b = tree.dock(WindowID(2), beside: a, edge: .bottom)
    _ = tree.dock(WindowID(3), beside: b, edge: .bottom)
    let column = tree.parent(of: a)!
    func frames(without absent: Set<WindowID>) -> [WindowID: CGRect] {
      LayoutEngine.layout(
        tree, camera: column, in: screen, options: keep(gap: 12), isPresent: { !absent.contains($0) }
      ).windowFrames
    }
    let all = frames(without: [])
    let withoutMiddle = frames(without: [WindowID(2)])
    #expect(withoutMiddle[WindowID(3)] == all[WindowID(3)])
    #expect(withoutMiddle[WindowID(1)] == all[WindowID(1)]!.union(all[WindowID(2)]!))
    let withoutFirst = frames(without: [WindowID(1)])
    #expect(withoutFirst[WindowID(3)] == all[WindowID(3)])
    #expect(withoutFirst[WindowID(2)] == all[WindowID(1)]!.union(all[WindowID(2)]!))
  }
}
