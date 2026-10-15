import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
private let e = WindowID(5)

/// root(h)[ column(v)[ a, row(h)[c, d] ], desktop, b ]. Taking `a` away leaves the column with one
/// child, so the row takes its place, inside a root that runs the same way. (`b` took all that was left: the Desktop has no room.)
private struct Fixture {
  var workspace = Workspace()
  let leafA: NodeID, leafB: NodeID, leafC: NodeID, leafD: NodeID
  let row: NodeID, column: NodeID, root: NodeID

  init() {
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    leafA = workspace.tree.leaf(containing: a)!
    leafB = workspace.tree.leaf(containing: b)!
    workspace.dock(c, at: .beside(leafA, .bottom))
    leafC = workspace.tree.leaf(containing: c)!
    workspace.dock(d, at: .beside(leafC, .right))
    leafD = workspace.tree.leaf(containing: d)!
    row = workspace.tree.parent(of: leafC)!
    column = workspace.tree.parent(of: leafA)!
    root = workspace.tree.root
  }
}

extension Workspace {
  fileprivate func windows(in node: NodeID?) -> [WindowID] { node.map { tree.windows(under: $0) } ?? [] }
  fileprivate var inView: [WindowID] { tree.windows(under: camera) }
}

/// F62. What a person frames, saves or names is a group of windows. It must go on meaning those
/// windows, whatever happens to the tree around it.
@Suite struct GroupIdentityTests {
  @Test func aFramedGroupStaysFramedWhenItsNeighbourLeaves() {
    var f = Fixture()
    f.workspace.moveCamera(to: f.row)
    f.workspace.forget(a)
    #expect(f.workspace.inView == [c, d], "the view used to jump to everything")
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func aViewOnTheGroupAroundItNarrowsToWhatIsLeftOfIt() {
    var f = Fixture()
    f.workspace.moveCamera(to: f.column)
    f.workspace.forget(a)
    #expect(f.workspace.inView == [c, d])
  }

  @Test func aSavedViewOfAGroupStillShowsThatGroup() {
    var f = Fixture()
    f.workspace.moveCamera(to: f.row)
    f.workspace.saveView(slot: 1)
    f.workspace.moveCamera(to: f.root)
    f.workspace.forget(a)
    #expect(f.workspace.inView == [c, d, b], "the view on everything stays on everything")
    #expect(f.workspace.windows(in: f.workspace.savedView(slot: 1)) == [c, d])
  }

  @Test func movingAWindowWithinTheViewKeepsTheView() {
    // Zoomed in on the column, move `a` to the left edge of the view.
    var f = Fixture()
    f.workspace.moveCamera(to: f.column)
    f.workspace.dock(a, at: .cameraEdge(.left))
    #expect(f.workspace.inView == [a, c, d], "it used to land at the left of everything, with everything in view")
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  /// F57: a floating window that opened over a framed group belongs to it. It used to become an
  /// ordinary floating window as soon as the group dissolved, though both windows of the group were still there.
  @Test func aGroupWithAGuestWindowStaysItsHost() {
    var f = Fixture()
    f.workspace.floating[e] = CGRect(x: 100, y: 100, width: 300, height: 200)
    f.workspace.receive(e, asGuestOf: f.row)
    f.workspace.forget(a)
    #expect(f.workspace.guests == [e: f.row])
    #expect(f.workspace.windows(in: f.row) == [c, d])
    f.workspace.endVisit(of: e)
    f.workspace.forget(b)
    #expect(!f.workspace.tree.contains(f.row), "with the guest gone nothing keeps it")
  }

  // MARK: Letting go

  @Test func aGroupNothingViewsDissolvesAsBefore() {
    var f = Fixture()
    f.workspace.forget(a)
    #expect(f.workspace.tree.children(of: f.root) == [f.leafC, f.leafD, f.workspace.tree.desktop, f.leafB])
    #expect(!f.workspace.tree.contains(f.row))
  }

  /// Moving the view changes nothing in the tree, so Back still finds the group. The next change to
  /// the arrangement lets go of it.
  @Test func aGroupTheViewHasLeftLastsUntilTheArrangementChanges() {
    var f = Fixture()
    f.workspace.moveCamera(to: f.row)
    f.workspace.forget(a)
    let kept = f.workspace.tree
    f.workspace.moveCamera(to: f.root)
    #expect(f.workspace.tree == kept)
    let wentBack = f.workspace.goBack()
    #expect(wentBack && f.workspace.inView == [c, d])

    f.workspace.moveCamera(to: f.root)
    f.workspace.dock(e, at: .cameraEdge(.right))
    #expect(!f.workspace.tree.contains(f.row))
    #expect(f.workspace.tree.children(of: f.root).count == 5)
    #expect(f.workspace.back.allSatisfy(f.workspace.tree.contains))
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func savingAnotherViewInTheSlotLetsGoOfTheGroup() {
    var f = Fixture()
    f.workspace.moveCamera(to: f.row)
    f.workspace.saveView(slot: 1)
    f.workspace.moveCamera(to: f.root)
    f.workspace.forget(a)
    #expect(f.workspace.tree.contains(f.row))
    f.workspace.saveView(slot: 1)
    f.workspace.forget(b)
    #expect(!f.workspace.tree.contains(f.row))
  }

  /// Marks are in the tree only where they make a difference, so that arrangements which look
  /// alike are equal, and what is saved does not depend on where the view has been.
  @Test func ordinaryTreesCarryNoMarks() {
    var f = Fixture()
    for node in [f.column, f.row, f.root] {
      f.workspace.moveCamera(to: node)
      f.workspace.saveView(slot: 1)
      f.workspace.dock(e, at: .beside(f.leafB, .bottom))
      #expect(f.workspace.tree.nodes.values.allSatisfy { $0.keeps == nil }, "view on \(node)")
      f.workspace.forget(e)
      #expect(f.workspace.tree.nodes.values.allSatisfy { $0.keeps == nil }, "view on \(node)")
    }
    f.workspace.moveCamera(to: f.row)
    f.workspace.saveView(slot: 1)
    f.workspace.forget(a)
    #expect(f.workspace.tree.nodes.values.filter { $0.keeps != nil }.map(\.id) == [f.row])
  }

  // MARK: Aiming at a group

  /// Found in the review of the core: the group a window is dropped beside could dissolve while
  /// the window was on its way.
  @Test(arguments: Edge.allCases) func aWindowDroppedBesideTheGroupItCameFromLandsBesideThatGroup(edge: Edge) {
    var f = Fixture()
    f.workspace.dock(a, at: .beside(f.row, edge))
    let tree = f.workspace.tree
    #expect(tree.invariantViolations() == [])
    let leaf = tree.leaf(containing: a)!
    switch edge {
    case .left: #expect(tree.children(of: f.root).prefix(3) == [leaf, f.leafC, f.leafD])
    case .right: #expect(tree.children(of: f.root).prefix(3) == [f.leafC, f.leafD, leaf])
    case .top, .bottom:
      // Above or below c and d together, and nothing else: a column again.
      let column = tree.parent(of: leaf)!
      #expect(tree.windows(under: column) == (edge == .top ? [a, c, d] : [c, d, a]))
      #expect(tree.parent(of: column) == f.root)
    }
    #expect(tree.nodes.values.allSatisfy { $0.keeps == nil })
  }

  // MARK: Docking at the edge of the view

  /// T01: at the edge of the view means beside everything in view. In a row [a | desktop | b] with
  /// the view on a, the newcomer used to become one more in the row, and the view widened to all of it.
  @Test(arguments: Edge.allCases) func whatIsDockedAtTheEdgeOfTheViewJoinsWhatIsInView(edge: Edge) {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.leaf(containing: a)!)
    workspace.dock(e, at: .cameraEdge(edge))
    #expect(Set(workspace.inView) == [a, e], "\(workspace.inView)")
    #expect(workspace.inView == (edge.isLeading ? [e, a] : [a, e]))
    #expect(workspace.tree.invariantViolations() == [])
    // Seen from outside it is where it would have been: beside a, sharing a's room.
    #expect(workspace.tree.allWindows == (edge.isLeading ? [e, a, b] : [a, e, b]))
  }

  @Test(arguments: Edge.allCases) func theSameWithTheViewOnAGroup(edge: Edge) {
    var f = Fixture()
    f.workspace.moveCamera(to: f.column)
    f.workspace.dock(e, at: .cameraEdge(edge))
    #expect(Set(f.workspace.inView) == [a, c, d, e])
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  /// A drop that turns a column into a row: [a | desktop | (b / e)], the view on the column, e
  /// dragged to the left edge of the view.
  @Test func movingAWindowOfTheViewToItsOtherAxisKeepsTheView() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(e, at: .beside(workspace.tree.leaf(containing: b)!, .bottom))
    workspace.moveCamera(to: workspace.tree.parent(of: workspace.tree.leaf(containing: b)!)!)
    workspace.dock(e, at: .cameraEdge(.left))
    #expect(workspace.inView == [e, b])
    #expect(workspace.tree.invariantViolations() == [])
  }

  @Test func onceTheViewHasLeftTheRowIsFlatAgain() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.leaf(containing: a)!)
    workspace.dock(e, at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.root)
    workspace.forget(b)
    #expect(workspace.tree.children(of: workspace.tree.root).count == 3, "a, e and the Desktop in one row")
    #expect(workspace.tree.nodes.values.allSatisfy { $0.keeps == nil })
  }

  @Test func showingEverythingDockingAtTheEdgeIsAsItWas() {
    var workspace = Workspace()
    for (window, edge) in [(a, Edge.left), (b, .right), (c, .right), (d, .top)] { workspace.dock(window, at: .cameraEdge(edge)) }
    #expect(workspace.camera == workspace.tree.root)
    #expect(workspace.tree.nodes.values.allSatisfy { $0.keeps == nil })
    #expect(workspace.tree.children(of: workspace.tree.root).count == 2, "d above the row")
  }

  /// With one window in view there is nothing to dock it beside. It used to leave the group, which
  /// died of it if it was kept for a name, and land at the edge of whatever was around.
  @Test func theOnlyWindowInViewCannotBeMovedToTheEdgeOfTheView() {
    var f = Fixture()
    f.workspace.tree.keep(f.row, for: .name)
    f.workspace.forget(a)
    f.workspace.forget(d)
    for camera in [f.row, f.leafC] {
      f.workspace.moveCamera(to: camera)
      let before = f.workspace
      let docked = f.workspace.dock(c, at: .cameraEdge(.bottom))
      #expect(!docked && f.workspace == before)
      #expect(f.workspace.previewFrame(for: c, at: .cameraEdge(.bottom), in: Self.screen, options: .init(), isPresent: { _ in true }) == nil)
    }
    // With the Desktop in view as well there is something.
    f.workspace.moveCamera(to: f.root)
    f.workspace.forget(b)
    let docked = f.workspace.dock(c, at: .cameraEdge(.right))
    #expect(docked)
  }

  // MARK: Names and guests

  @Test func aFirmlyKeptGroupSurvivesDownToOneWindowAndGrowsAgain() {
    var f = Fixture()
    let kept = f.workspace.tree.keep(f.row, for: .name)
    #expect(kept)
    f.workspace.forget(a)
    f.workspace.forget(d)
    #expect(f.workspace.tree.children(of: f.row) == [f.leafC])
    #expect(f.workspace.tree.invariantViolations() == [])
    for (window, edge) in [(d, Edge.bottom), (e, .left)] {
      f.workspace.dock(window, at: .beside(f.leafC, edge))
      #expect(f.workspace.tree.invariantViolations() == [])
    }
    #expect(Set(f.workspace.windows(in: f.row)) == [c, d, e], "what is docked beside its windows is in the group")
    #expect(f.workspace.tree.contains(f.row))
  }

  @Test func aKeptGroupGoesWithItsLastWindow() {
    var f = Fixture()
    f.workspace.tree.keep(f.row, for: [.name, .guest])
    f.workspace.forget(c)
    var remap = Remap()
    f.workspace.changeStructure {
      remap = $0.remove(d)
      return remap
    }
    #expect(!f.workspace.tree.contains(f.row))
    #expect(f.workspace.tree.invariantViolations() == [])
    #expect(remap.survivor(of: f.row, in: f.workspace.tree) == nil, "a name must not pass to the parent")
    #expect(remap.survivor(of: f.leafD, in: f.workspace.tree) == nil)
    #expect(f.workspace.tree.contains(remap.resolve(f.row, in: f.workspace.tree)), "a view falls back on it")
    #expect(remap.survivor(of: f.leafA, in: f.workspace.tree) == f.leafA)
  }

  @Test func survivorFollowsCollapsesAndMergesButNotDeletions() {
    var tree = Fixture().workspace.tree
    let f = Fixture()
    let remap = tree.remove(a)
    #expect(remap.survivor(of: f.column, in: tree) == f.root, "collapsed into the row, which merged into the root")
    #expect(remap.survivor(of: f.row, in: tree) == f.root)
    #expect(remap.survivor(of: f.leafA, in: tree) == nil)
    #expect(remap.survivor(of: NodeID(99), in: tree) == nil)
  }

  @Test func aGroupIsKeptUntilTheLastReasonGoes() {
    var tree = Fixture().workspace.tree
    let f = Fixture()
    tree.keep(f.row, for: [.name, .guest])
    tree.remove(a)
    #expect(tree.children(of: f.root).first == f.row)
    #expect(tree.kept(for: .guest) == [f.row] && tree.kept(for: .name) == [f.row] && tree.kept(for: .view) == [])
    let first = tree.stopKeeping(f.row, for: .guest)
    #expect(first.isEmpty && tree.contains(f.row) && tree.isKeptFirmly(f.row))
    let second = tree.stopKeeping(f.row, for: .name)
    #expect(second.resolve(f.row, in: tree) == f.root && !tree.contains(f.row))
    #expect(tree.children(of: f.root) == [f.leafC, f.leafD, tree.desktop, f.leafB])
    #expect(tree.invariantViolations() == [])
  }

  @Test func lettingGoOfAGroupOfOneGivesWayToThatOne() {
    var tree = Fixture().workspace.tree
    let f = Fixture()
    tree.keep(f.column, for: .name)
    tree.remove(c)
    tree.remove(d)
    #expect(tree.children(of: f.column) == [f.leafA])
    let remap = tree.stopKeeping(f.column, for: .name)
    #expect(remap.survivor(of: f.column, in: tree) == f.leafA)
    #expect(tree.children(of: f.root).first == f.leafA)
    #expect(tree.invariantViolations() == [])
  }

  /// Two branches each added a reason with `1 << 3`, a few lines apart, and Git merged them without a conflict: two
  /// reasons that were one. Nothing in the language objects, so this reads the file.
  @Test func noTwoReasonsShareABitAndEachHasAWord() throws {
    let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().appendingPathComponent("Sources/ArborCore/LayoutTree+Keeps.swift")
    let source = try String(contentsOf: file, encoding: .utf8)
    var bitOf: [String: Int] = [:]
    for line in source.split(separator: "\n") {
      // `static let view = Keeps(rawValue: 1 << 0)`
      let words = line.split(whereSeparator: { " ()".contains($0) })
      guard let start = words.firstIndex(of: "let"), words.count >= start + 8, words[start + 2] == "=",
        words[start + 3] == "Keeps", words[start + 4] == "rawValue:", words[start + 5] == "1", words[start + 6] == "<<",
        let bit = Int(words[start + 7])
      else { continue }
      bitOf[String(words[start + 1])] = bit
    }
    #expect(bitOf.count >= 4 && bitOf["view"] == 0 && bitOf["move"] == 3, "the file is not read as it should be: \(bitOf)")
    for (bit, reasons) in Dictionary(grouping: bitOf.keys.sorted(), by: { bitOf[$0]! }) {
      #expect(reasons.count == 1, "\(reasons.joined(separator: " and ")) are both 1 << \(bit)")
    }
    for (reason, bit) in bitOf {
      #expect(Keeps(rawValue: 1 << bit).description == reason, "`description` has no word for .\(reason)")
    }
  }

  @Test func reasonsReadAsWords() {
    #expect(Keeps.view.description == "view" && Keeps([.name, .guest]).description == "name and guest")
    #expect(Keeps([.view, .turned]).description == "view and turned")
    #expect(Keeps([]).description == "nothing" && Keeps(rawValue: 33).description == "view and 32")
  }

  @Test func onlySplitsCanBeKept() {
    var tree = Fixture().workspace.tree
    let f = Fixture()
    let before = tree
    let answers = [
      tree.keep(f.leafA, for: .name), tree.keep(tree.desktop, for: .name), tree.keep(NodeID(99), for: .name),
      tree.keep(f.row, for: []),
    ]
    #expect(answers == [false, false, false, false])
    let remap = tree.stopKeeping(NodeID(99), for: .name)
    #expect(remap.isEmpty && tree == before)
    #expect(!tree.isKept(f.leafA) && !tree.isKept(NodeID(99)) && !tree.isKeptFirmly(f.row))
  }

  /// A view that was on the group around it passes to what is left, which must not dissolve either.
  @Test func whatAKeptGroupCollapsesIntoIsKeptInItsPlace() {
    var tree = Fixture().workspace.tree
    let f = Fixture()
    tree.keep(f.column, for: .view)
    let remap = tree.remove(a)
    #expect(remap.survivor(of: f.column, in: tree) == f.row)
    #expect(tree.isKept(f.row) && tree.parent(of: f.row) == f.root)
    #expect(tree.invariantViolations() == [])
  }

  // MARK: Saving

  private func reread<T: Codable>(_ value: T) throws -> (T, [String]) {
    let decoder = JSONDecoder()
    let notes = DecodingNotes()
    decoder.userInfo[DecodingNotes.key] = notes
    return (try decoder.decode(T.self, from: JSONEncoder().encode(value)), notes.notes)
  }

  @Test func keptGroupsComeBackFromAFileAsTheyWere() throws {
    var f = Fixture()
    f.workspace.moveCamera(to: f.row)
    f.workspace.forget(a)
    f.workspace.moveCamera(to: f.root)  // the mark outlives the view until the arrangement changes
    f.workspace.dock(e, at: .beside(f.leafB, .bottom))
    _ = f.workspace.goBack()
    let (sameAxis, notes) = try reread(f.workspace)
    #expect(sameAxis == f.workspace && notes == [])

    var g = Fixture()
    g.workspace.tree.keep(g.row, for: .guest)
    g.workspace.forget(a)
    g.workspace.forget(d)
    let (oneChild, more) = try reread(g.workspace)
    #expect(oneChild == g.workspace && more == [])
    #expect(oneChild.tree.children(of: g.row) == [g.leafC])
  }

  @Test func aTreeSavedBeforeKeepsExistedStillLoads() throws {
    let tree = Fixture().workspace.tree
    let json = String(decoding: try JSONEncoder().encode(tree), as: UTF8.self)
    #expect(!json.contains("keeps"), "nothing is written for a node that nothing keeps")
    #expect(try JSONDecoder().decode(LayoutTree.self, from: Data(json.utf8)) == tree)
  }

  @Test func marksThatMakeNoSenseInAFileAreDropped() throws {
    let f = Fixture()
    var file = try TreeFile(f.workspace.tree)
    file.edit(f.leafA) { $0["keeps"] = 2 }
    file.edit(f.workspace.tree.desktop) { $0["keeps"] = 7 }
    file.edit(f.row) { $0["keeps"] = 0 }
    let (tree, notes) = try file.read()
    #expect(tree == f.workspace.tree)
    #expect(notes.count == 3)
    // One that cannot be read costs the node, like anything else about a node that cannot be read.
    file = try TreeFile(f.workspace.tree)
    file.edit(f.leafB) { $0["keeps"] = "always" }
    #expect(try file.read().tree.allWindows == [a, c, d])
  }

  @Test func theRepairSparesKeptSplitsAndOnlyThose() throws {
    let f = Fixture()
    // The column made horizontal: it and the row now nest the root's axis.
    var file = try TreeFile(f.workspace.tree)
    file.setChildren(of: f.column, axis: .horizontal, [f.leafA, f.row])
    file.edit(f.row) { $0["keeps"] = Keeps.name.rawValue }
    let (tree, _) = try file.read()
    #expect(tree.invariantViolations() == [])
    #expect(!tree.contains(f.column) && tree.children(of: f.root) == [f.leafA, f.row, tree.desktop, f.leafB])

    // A firmly kept split with one child stays, a softly kept one hands its mark to the child, an empty one goes.
    file = try TreeFile(f.workspace.tree)
    file.nodes[String(f.leafA.rawValue)] = nil
    file.edit(f.column) { $0["keeps"] = Keeps.guest.rawValue }
    #expect(try file.read().tree.children(of: f.column) == [f.row])
    file.edit(f.column) { $0["keeps"] = Keeps.view.rawValue }
    let soft = try file.read().tree
    #expect(!soft.contains(f.column) && soft.isKept(f.row) && soft.parent(of: f.row) == f.root)
    #expect(soft.invariantViolations() == [])
    file.edit(f.column) { $0["keeps"] = Keeps.guest.rawValue }
    file.setChildren(of: f.column, axis: .vertical, [])
    let emptied = try file.read().tree
    #expect(!emptied.contains(f.column) && emptied.allWindows == [b] && emptied.invariantViolations() == [])
  }

  // MARK: Looking at it

  private static let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
  /// Nothing becomes a tile, so that every window has a frame to look at.
  private static let untiled = LayoutOptions(minimumUsableSize: .zero)

  /// root(h)[ row(h, kept)[c, d], desktop, b ]
  private func nested() -> Fixture {
    var f = Fixture()
    f.workspace.tree.keep(f.row, for: .name)
    f.workspace.forget(a)
    return f
  }

  @Test func aGroupInARowOnItsOwnAxisIsLaidOutAsAGroup() {
    let f = nested()
    let tree = f.workspace.tree
    let layout = LayoutEngine.layout(tree, camera: f.root, in: Self.screen, options: Self.untiled, isPresent: { _ in true })
    let (group, left, right) = (layout.nodeFrames[f.row]!, layout.windowFrames[c]!, layout.windowFrames[d]!)
    #expect(left.minX == group.minX && right.maxX == group.maxX && right.minX - left.maxX == 12)
    #expect(layout.windowFrames[b]!.minX - group.maxX == 12)
    #expect(layout.seams.map(\.leading) == [f.leafC, f.row], "one gap inside the group, one in the row")
    // Framed, it fills the display.
    let framed = LayoutEngine.layout(tree, camera: f.row, in: Self.screen, isPresent: { _ in true })
    #expect(framed.nodeFrames[f.row] == Self.screen.insetBy(dx: 12, dy: 12))
    #expect(framed.hiddenWindows == [b])
    // Too small to use (it has half, 702 points), it is one tile.
    let tiles = LayoutEngine.layout(
      tree, camera: f.root, in: Self.screen, options: LayoutOptions(minimumUsableSize: CGSize(width: 720, height: 100)),
      isPresent: { _ in true })
    #expect(tiles.tiles.first { $0.node == f.row }?.kind == .group)
  }

  @Test func aGroupOfOneLooksLikeThatOne() {
    var f = nested()
    f.workspace.forget(d)
    let tree = f.workspace.tree
    let layout = LayoutEngine.layout(tree, camera: f.root, in: Self.screen, options: Self.untiled, isPresent: { _ in true })
    #expect(layout.nodeFrames[f.row] == layout.windowFrames[c])
    let view = TreeView(tree: tree, isPresent: { _ in true })
    #expect(Navigation.stepOut(from: f.leafC, in: view) == f.root, "a level that looks the same is skipped")
    #expect(Navigation.stepIn(from: f.row, toward: nil, focused: c, in: view, layout: layout) == nil)
    #expect(LayoutEngine.layout(tree, camera: f.row, in: Self.screen, isPresent: { _ in true }).tiles.isEmpty)
  }

  @Test func theViewStepsThroughAGroupOnItsParentsAxis() {
    let f = nested()
    let tree = f.workspace.tree
    let view = TreeView(tree: tree, isPresent: { _ in true })
    let layout = LayoutEngine.layout(tree, camera: f.root, in: Self.screen, options: Self.untiled, isPresent: { _ in true })
    #expect(Navigation.stepOut(from: f.leafC, in: view) == f.row)
    #expect(Navigation.stepOut(from: f.row, in: view) == f.root)
    #expect(Navigation.stepIn(from: f.root, toward: layout.windowFrames[d]!.center, focused: nil, in: view, layout: layout) == f.row)
    #expect(Navigation.neighbor(of: f.leafC, toward: .right, in: view) == f.leafD)
    #expect(Navigation.neighbor(of: f.leafD, toward: .right, in: view) == f.leafB, "out of the group, along the row")
    #expect(Navigation.neighbor(of: f.leafB, toward: .left, in: view) == f.row)
    #expect(Navigation.neighbor(of: tree.desktop, toward: .left, in: view) == f.row)
    #expect(Navigation.neighbor(of: f.row, toward: .right, in: view) == f.leafB)
    #expect(Navigation.adjacentLeaf(to: f.leafD, toward: .right, in: layout, tree: tree) == f.leafB)
    #expect(Navigation.bestFit(for: layout.nodeFrames[f.row]!, in: layout, tree: tree) == f.row)
  }

  @Test func dockingAtAnEndOfAKeptGroupJoinsIt() {
    var f = nested()
    f.workspace.dock(e, at: .beside(f.row, .right))
    #expect(f.workspace.windows(in: f.row) == [c, d, e])
    f.workspace.dock(e, at: .beside(f.workspace.tree.desktop, .left))
    #expect(f.workspace.windows(in: f.row) == [c, d], "beside the Desktop is outside the group, though it looks the same")
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  // MARK: Anything at all

  /// The promise, over random sessions: what the view and each saved view show never grows because
  /// something else left, and a firmly kept group lives exactly as long as it has a window.
  @Test(arguments: Array<UInt64>(1...30), [false, true])
  func noReferenceEverComesToMeanMore(seed: UInt64, desktopColumn: Bool) throws {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    var next: UInt32 = 1
    var firm: Set<NodeID> = []
    for step in 0..<400 {
      let tree = workspace.tree
      let nodes = tree.preorder()
      let node = nodes.randomElement(using: &random)!
      let edge = Edge.allCases.randomElement(using: &random)!
      let docked = tree.allWindows
      // What every reference on a split shows now.
      var shown: [String: Set<WindowID>] = ["view": Set(tree.windows(under: workspace.camera))]
      var onSplit: Set<String> = tree.isSplit(workspace.camera) ? ["view"] : []
      for (slot, saved) in workspace.savedViews {
        shown[slot] = Set(tree.windows(under: saved))
        if tree.isSplit(saved) { onSplit.insert(slot) }
      }
      let members = Dictionary(uniqueKeysWithValues: firm.map { ($0, Set(tree.windows(under: $0))) })
      let names = workspace.names
      var arrived: WindowID?
      var left: WindowID?
      var atTheEdgeOfTheView = false

      switch Int.random(in: 0..<16, using: &random) {
      case 0...3:
        guard docked.count < 25 else { continue }
        arrived = WindowID(next)
        next += 1
        atTheEdgeOfTheView = Bool.random(using: &random)
        workspace.dock(arrived!, at: atTheEdgeOfTheView ? .cameraEdge(edge) : .beside(node, edge), desktopColumn: desktopColumn)
      case 4, 5:
        guard let window = docked.randomElement(using: &random) else { continue }
        (arrived, left) = (window, window)
        workspace.dock(window, at: .beside(node, edge), desktopColumn: desktopColumn)
      case 6...9:
        guard let window = docked.randomElement(using: &random) else { continue }
        left = window
        if Bool.random(using: &random) { workspace.forget(window) } else { workspace.undock(window, floatingAt: Self.screen) }
      case 10, 11: workspace.moveCamera(to: node)
      case 12: workspace.saveView(slot: Int.random(in: 1...3, using: &random))
      case 13: _ = Bool.random(using: &random) ? workspace.goBack() : workspace.goForward()
      case 14:
        // A name goes through the workspace's table, which decides what is kept for one (F20).
        if Bool.random(using: &random) {
          if tree.isSplit(node), (try? workspace.setName("s\(node.rawValue)", of: node)) != nil { firm.insert(node) }
        } else if workspace.tree.keep(node, for: .guest) {
          firm.insert(node)
        }
      default:
        guard let id = firm.randomElement(using: &random) else { continue }
        firm.remove(id)
        workspace.removeName(of: id)
        workspace.changeStructure { $0.stopKeeping(id, for: .firm) }
      }
      // A window docked at an edge of the view of a named space is wrapped together with it, and the wrapper
      // takes over the name (F20). The group that had it is an ordinary one from then on.
      let renamed = Set(names.filter { workspace.names[$0.key] != nil && workspace.names[$0.key] != $0.value }.values)
      firm.subtract(renamed)

      let after = workspace.tree
      #expect(after.invariantViolations() == [], "seed \(seed), step \(step)")
      #expect(after.contains(workspace.camera) && workspace.savedViews.values.allSatisfy(after.contains))
      guard arrived != nil || left != nil else { continue }

      for name in onSplit {
        let before = shown[name]!
        guard !before.subtracting([left].compactMap { $0 }).isEmpty else { continue }  // its content is gone
        guard let now = name == "view" ? workspace.camera : workspace.savedViews[name] else { continue }
        // The view may widen to show a window that was docked somewhere outside it; nothing else may grow.
        if name == "view", !atTheEdgeOfTheView, let arrived, !before.contains(arrived) || left == arrived { continue }
        let extra = Set(after.windows(under: now)).subtracting(before).subtracting([arrived].compactMap { $0 })
        #expect(extra.isEmpty, "seed \(seed), step \(step): \(name) came to show \(extra.sorted()) as well")
      }
      if atTheEdgeOfTheView {
        #expect(Set(workspace.inView) == shown["view"]!.union([arrived!]), "seed \(seed), step \(step): T01")
      }
      for (id, before) in members where !renamed.contains(id) {
        let remaining = before.subtracting([left].compactMap { $0 })
        if after.contains(id) {
          #expect(Set(after.windows(under: id)).isSuperset(of: remaining.subtracting([arrived].compactMap { $0 })))
          #expect(Set(after.windows(under: id)).subtracting(before).isSubset(of: Set([arrived].compactMap { $0 })))
        } else {
          firm.remove(id)
          #expect(remaining.isEmpty && !tree.subtree(id, contains: tree.desktop), "seed \(seed), step \(step): \(id) died with \(remaining.sorted()) in it")
        }
      }
      if step % 40 == 0 {
        let (again, notes) = try reread(workspace)
        #expect(again == workspace && notes == [], "seed \(seed), step \(step)")
      }
    }
  }
}
