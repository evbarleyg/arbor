import ArborCore
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)

@Suite struct LayoutTreeTests {
  @Test func emptyTreeIsJustTheDesktop() {
    let tree = LayoutTree()
    #expect(tree.root == tree.desktop)
    #expect(tree.allWindows.isEmpty)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func firstDockWrapsTheDesktop() {
    var tree = LayoutTree()
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    guard case .split(.horizontal, let children) = tree[tree.root]?.kind else {
      Issue.record("root should be a horizontal split")
      return
    }
    #expect(children == [leaf, tree.desktop])
    #expect(tree[leaf]?.weight == 1)
    #expect(tree[tree.desktop]?.weight == 1)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func dockingAtTheEdgeOfASameAxisSplitAppendsWithTheMeanWeight() {
    var tree = LayoutTree()
    tree.dock(a, beside: tree.root, edge: .left)
    let leaf = tree.dock(b, beside: tree.root, edge: .right)
    #expect(tree.children(of: tree.root).last == leaf)
    #expect(tree.children(of: tree.root).count == 3)
    #expect(tree[leaf]?.weight == 1)
  }

  @Test func dockingBesideALeafInASameAxisSplitTakesHalfItsShare() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let second = tree.dock(b, beside: first, edge: .right)
    #expect(tree.children(of: tree.root) == [first, second, tree.desktop])
    #expect(tree[first]?.weight == 0.5)
    #expect(tree[second]?.weight == 0.5)
  }

  @Test func dockingBesideALeafWithAnEvenShareLeavesItsWeightAlone() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: 50, pointsPerWeight: 100, minimumPoints: 10)
    let second = tree.dock(b, beside: tree.desktop, edge: .left, evenShare: true)
    #expect(tree.children(of: tree.root) == [first, second, tree.desktop])
    #expect(tree[first]?.weight == 1.5)
    #expect(tree[tree.desktop]?.weight == 0.5)
    #expect(tree[second]?.weight == 1, "the average of its new siblings")
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func dockingAcrossTheAxisWrapsTheTarget() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let below = tree.dock(b, beside: first, edge: .bottom)
    let column = tree.parent(of: first)!
    #expect(tree.children(of: column) == [first, below])
    guard case .split(.vertical, _) = tree[column]?.kind else {
      Issue.record("column should be vertical")
      return
    }
    #expect(tree.parent(of: column) == tree.root)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func removingCollapsesAndFlattens() {
    // [ [a / b] , desktop ] then remove a: the column collapses into b.
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let second = tree.dock(b, beside: first, edge: .bottom)
    let column = tree.parent(of: first)!
    let remap = tree.remove(a)
    #expect(tree.children(of: tree.root) == [second, tree.desktop])
    #expect(remap.resolve(first, in: tree) == second)
    #expect(remap.resolve(column, in: tree) == second)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func removingFlattensSameAxisNesting() {
    // root(h)[ col(v)[ a, row(h)[b, c] ], desktop ]; removing a puts row(h) inside root(h).
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let second = tree.dock(b, beside: first, edge: .bottom)
    let third = tree.dock(c, beside: second, edge: .right)
    tree.remove(a)
    #expect(tree.children(of: tree.root) == [second, third, tree.desktop])
    #expect(tree.invariantViolations().isEmpty)
    // b and c split the share the column had, which matched the Desktop's.
    let shares = [second, third].map { tree[$0]!.weight }
    #expect(abs(shares.reduce(0, +) - tree[tree.desktop]!.weight) < 1e-9)
  }

  @Test func removingTheLastWindowLeavesTheDesktop() {
    var tree = LayoutTree()
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    let remap = tree.remove(a)
    #expect(tree.root == tree.desktop)
    #expect(remap.resolve(leaf, in: tree) == tree.desktop)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func stacksKeepOrderAndActiveWindow() {
    var tree = LayoutTree()
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    tree.addToStack(b, leaf: leaf)
    tree.addToStack(c, leaf: leaf)
    #expect(tree.activeWindow(of: leaf) == c)
    tree.activate(a)
    #expect(tree.activeWindow(of: leaf) == a)
    tree.remove(a)
    #expect(tree.activeWindow(of: leaf) == b)
    #expect(tree.invariantViolations().isEmpty)
  }

  @Test func moveBoundaryKeepsTheTotalAndRespectsTheMinimum() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: 100, pointsPerWeight: 500)
    #expect(abs(tree[first]!.weight - 1.2) < 1e-9)
    #expect(abs(tree[first]!.weight + tree[tree.desktop]!.weight - 2) < 1e-9)
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: 10_000, pointsPerWeight: 500)
    #expect(abs(tree[tree.desktop]!.weight - 80.0 / 500) < 1e-9)
  }

  @Test func moveBoundaryIgnoresADistanceThatIsNotANumber() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let before = tree
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: .nan, pointsPerWeight: 500)
    #expect(tree == before)
  }

  @Test(arguments: [1e300, Double.infinity, -1e300, -Double.infinity])
  func anyOtherDistanceHoweverLargeStopsAtTheMinimum(distance: Double) {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    tree.moveBoundary(leading: first, trailing: tree.desktop, by: distance, pointsPerWeight: 500)
    let squeezed = distance > 0 ? tree.desktop : first
    #expect(abs(tree[squeezed]!.weight - 80.0 / 500) < 1e-9)
    #expect(abs(tree[first]!.weight + tree[tree.desktop]!.weight - 2) < 1e-9)
    #expect(tree.invariantViolations().isEmpty)
  }

  /// `arrangeDesktopWeight` can be any number in settings.json, and the weight is saved with the tree.
  @Test(arguments: [0, -1, -2, -1e300, Double.leastNonzeroMagnitude, 1.7e308, Double.infinity, -Double.infinity, Double.nan])
  func theGridsDesktopWeightIsKeptSensible(weight: Double) {
    for count in [1, 2, 5] {
      var tree = LayoutTree.grid(of: (1...count).map { WindowID(UInt32($0)) }, desktopWeight: weight)
      #expect(tree.invariantViolations().isEmpty, "\(count) windows")
      #expect((0.05...20).contains(tree[tree.desktop]!.weight))
      // What used to divide by a total of zero, or overflow: collapsing and docking afterwards.
      tree.dock(WindowID(99), beside: tree.root, edge: .right)
      for window in 1...count { tree.remove(WindowID(UInt32(window))) }
      #expect(tree.invariantViolations().isEmpty, "\(count) windows")
    }
    #expect(LayoutTree.grid(of: [a], desktopWeight: 0.75)[LayoutTree().desktop]?.weight == 0.75)
  }

  @Test func swapLeavesExchangesWindows() {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    let second = tree.dock(b, beside: tree.root, edge: .right)
    tree.swapLeaves(of: a, and: b)
    #expect(tree.leaf(containing: a) == second)
    #expect(tree.leaf(containing: b) == first)
  }

  @Test func gridPutsWindowsInColumnsWithTheDesktopLast() {
    let tree = LayoutTree.grid(of: [a, b, c, d], desktopWeight: 0.5)
    #expect(tree.invariantViolations().isEmpty)
    let columns = tree.children(of: tree.root)
    #expect(columns.count == 3)
    #expect(columns.last == tree.desktop)
    #expect(tree[tree.desktop]?.weight == 0.5)
    #expect(tree.windows(under: columns[0]) == [a, b])
    #expect(tree.windows(under: columns[1]) == [c, d])
  }

  @Test func aTreeSurvivesCoding() throws {
    var tree = LayoutTree()
    let first = tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: first, edge: .bottom)
    let data = try JSONEncoder().encode(tree)
    let decoded = try JSONDecoder().decode(LayoutTree.self, from: data)
    #expect(decoded == tree)
    // New nodes after decoding must not reuse IDs.
    var copy = decoded
    let leaf = copy.dock(c, beside: copy.root, edge: .right)
    #expect(tree[leaf] == nil)
  }

  /// Random docks, removals, swaps, resizes, turns, mirrorings and evenings-out must never break the invariants.
  @Test(arguments: Array<UInt64>(1...25)) func randomOperationsKeepInvariants(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var tree = LayoutTree()
    var docked: [WindowID] = []
    var nextWindow: UInt32 = 1
    for _ in 0..<160 {
      switch Int.random(in: 0..<16, using: &random) {
      case 0..<5:
        let window = WindowID(nextWindow)
        nextWindow += 1
        let nodes = tree.preorder()
        let target = nodes[Int.random(in: 0..<nodes.count, using: &random)]
        let edge = Edge.allCases[Int.random(in: 0..<4, using: &random)]
        if Bool.random(using: &random), tree.isStack(target) {
          tree.addToStack(window, leaf: target)
        } else {
          tree.dock(window, beside: target, edge: edge)
        }
        docked.append(window)
      case 5..<8:
        guard !docked.isEmpty else { continue }
        let index = Int.random(in: 0..<docked.count, using: &random)
        let window = docked.remove(at: index)
        let before = tree.preorder()
        let remap = tree.remove(window)
        for node in before { #expect(tree.contains(remap.resolve(node, in: tree))) }
      case 8:
        guard docked.count >= 2 else { continue }
        tree.swapLeaves(of: docked[0], and: docked[docked.count - 1])
      case 9:
        guard !docked.isEmpty else { continue }
        let (first, second) = (
          docked[Int.random(in: 0..<docked.count, using: &random)], docked[Int.random(in: 0..<docked.count, using: &random)])
        let (leaves, shape) = ((tree.leaf(containing: first), tree.leaf(containing: second)), tree.preorder().count)
        tree.tradePlaces(of: first, and: second)
        #expect((tree.leaf(containing: first), tree.leaf(containing: second)) == leaves && tree.preorder().count == shape)
      case 10:
        // Any node: turning a leaf must do nothing, and turning a split twice must give back the same tree.
        let before = tree
        let nodes = tree.preorder()
        let node = nodes[Int.random(in: 0..<nodes.count, using: &random)]
        tree.rotate(node)
        #expect(tree.preorder() == nodes, "no node comes or goes")
        var back = tree
        back.rotate(node)
        // But for the mark "turned": here it is also put on at random, where it makes no difference and any turn takes it
        // away, and a group that ran along its parent for another reason has it afterwards.
        func shape(_ tree: LayoutTree) -> [NodeID: String] {
          tree.nodes.mapValues { "\(String(describing: $0.parent)) \($0.kind) \($0.weight) \(($0.keeps ?? []).subtracting(.turned))" }
        }
        #expect(shape(back) == shape(before))
      case 11:
        let nodes = tree.preorder()
        tree.mirror(nodes[Int.random(in: 0..<nodes.count, using: &random)])
      case 13, 14:
        // Groups that are kept (F62) may run the same way as the one around them, or hold a single child. They are turned too.
        let nodes = tree.preorder()
        let node = nodes[Int.random(in: 0..<nodes.count, using: &random)]
        let reason = [Keeps.view, .name, .guest, .turned][Int.random(in: 0..<4, using: &random)]
        if Bool.random(using: &random) { tree.keep(node, for: reason) } else { tree.stopKeeping(node, for: reason) }
      case 12:
        let nodes = tree.preorder()
        tree.equalize(
          under: nodes[Int.random(in: 0..<nodes.count, using: &random)],
          desktopWeight: Double.random(in: -0.5...2, using: &random))
      default:
        let splits = tree.preorder().filter { tree.children(of: $0).count >= 2 }
        guard let split = splits.first else { continue }
        let children = tree.children(of: split)
        tree.moveBoundary(
          leading: children[0], trailing: children[1], by: Double.random(in: -300...300, using: &random),
          pointsPerWeight: 400)
      }
      let problems = tree.invariantViolations()
      #expect(problems.isEmpty, "\(problems)")
      #expect(Set(tree.allWindows) == Set(docked))
    }
  }
}

@Suite struct SeededRandomTests {
  /// "A thousand seeds" must mean a thousand different runs. Seeded with a multiple of the step, seed n + 1
  /// gave the numbers of seed n from the second on: one run, looked at through a sliding window.
  @Test func notTwoSeedsShareANumber() {
    var seenIn: [UInt64: UInt64] = [:]
    var clash: String?
    for seed in 0..<2000 as Range<UInt64> where clash == nil {
      var random = SeededRandom(seed: seed)
      for _ in 0..<50 {
        let number = random.next()
        if let earlier = seenIn.updateValue(seed, forKey: number) { clash = "seeds \(earlier) and \(seed)" }
      }
    }
    #expect(clash == nil)
  }

  @Test func theSameSeedGivesTheSameNumbers() {
    var (one, other) = (SeededRandom(seed: 7), SeededRandom(seed: 7))
    for _ in 0..<50 { #expect(one.next() == other.next()) }
  }
}

/// SplitMix64, so random tests are reproducible.
struct SeededRandom: RandomNumberGenerator {
  var state: UInt64
  /// Not a multiple of the step below, or seed n + 1 is seed n one number later.
  init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
