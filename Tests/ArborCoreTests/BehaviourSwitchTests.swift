import ArborCore
import CoreGraphics
import Foundation
import Testing

private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)
// No tiles, so that narrow slots keep their windows.
private let share = LayoutOptions(minimumUsableSize: .zero)
private let keep = LayoutOptions(minimumUsableSize: .zero, shareRemovedSpace: false)

/// A row [a | b | c | desktop] whose children have the given weights: with a column for the Desktop, one more that must not move.
private func row(weights: [Double] = [1, 1, 1, 1]) -> LayoutTree {
  var tree = LayoutTree()
  let leafC = tree.dock(c, beside: tree.desktop, edge: .left, desktopColumn: true)
  let leafB = tree.dock(b, beside: leafC, edge: .left, desktopColumn: true)
  let leafA = tree.dock(a, beside: leafB, edge: .left, desktopColumn: true)
  // Docking halves shares. Move the boundaries until the weights are the ones asked for. A boundary
  // can only hand over what its two neighbours hold, so sweep both ways, more than once.
  let nodes = [leafA, leafB, leafC, tree.desktop]
  let scale = nodes.map { tree[$0]!.weight }.reduce(0, +) / weights.reduce(0, +)
  func excess(_ index: Int) -> Double { tree[nodes[index]]!.weight - weights[index] * scale }
  func move(_ index: Int, by delta: Double) {
    tree.moveBoundary(
      leading: nodes[index], trailing: nodes[index + 1], by: delta, pointsPerWeight: 1, minimumPoints: 0)
  }
  for _ in nodes {
    for index in (0..<(nodes.count - 1)).reversed() { move(index, by: excess(index + 1)) }
    for index in 0..<(nodes.count - 1) { move(index, by: -excess(index)) }
  }
  for (node, weight) in zip(nodes, weights) {
    precondition(abs(tree[node]!.weight - weight * scale) < 1e-9, "the row did not get its weights")
  }
  return tree
}

private func layout(_ tree: LayoutTree, _ options: LayoutOptions, without absent: Set<WindowID> = []) -> Layout {
  LayoutEngine.layout(tree, camera: tree.root, in: screen, options: options, isPresent: { !absent.contains($0) })
}

@Suite struct BehaviourSwitchSettingsTests {
  func decode(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  @Test func theDefaultsKeepTodaysBehaviour() {
    let settings = Settings()
    #expect(settings.previewDrags)
    #expect(settings.gapHandles == "shown")
    #expect(GapHandles(setting: settings.gapHandles) == .shown)
    #expect(settings.shareRemovedSpace)
    #expect(!settings.shrinkOutOfView)
    #expect(settings.layoutOptions.shareRemovedSpace)
    #expect(LayoutOptions().shareRemovedSpace)
  }

  @Test func anOldSettingsFileWithoutTheSwitchesStillLoads() throws {
    let settings = try decode(#"{"gap": 8, "tabsEnabled": false, "hotkeysEnabled": true}"#)
    var expected = Settings()
    expected.gap = 8
    #expect(settings == expected)
  }

  @Test func everySwitchIsReadFromTheFileAndWrittenBack() throws {
    let settings = try decode(
      #"""
      {"previewDrags": false, "gapHandles": "off", "shareRemovedSpace": false, "shrinkOutOfView": true}
      """#)
    #expect(!settings.previewDrags)
    #expect(GapHandles(setting: settings.gapHandles) == .off)
    #expect(!settings.shareRemovedSpace)
    #expect(settings.shrinkOutOfView)
    #expect(!settings.layoutOptions.shareRemovedSpace)
    let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(again == settings)
  }

  @Test func gapHandlesHasThreeValuesInAnyCase() {
    #expect(GapHandles(setting: "shown") == .shown)
    #expect(GapHandles(setting: "Hidden") == .hidden)
    #expect(GapHandles(setting: "OFF") == .off)
  }

  @Test func gapHandlesWrittenAsASwitchStillLoads() throws {
    #expect(try decode(#"{"gapHandles": true}"#).gapHandles == "shown")
    #expect(try decode(#"{"gapHandles": false, "gap": 8}"#).gapHandles == "off")
    #expect(try decode(#"{"gapHandles": false, "gap": 8}"#).gap == 8)
  }

  @Test func anUnknownValueForGapHandlesCountsAsShownAndIsReported() throws {
    let settings = try decode(#"{"gapHandles": "sometimes", "gap": 8}"#)
    #expect(settings.gapHandles == "shown")
    #expect(settings.gap == 8, "the rest of the file still counts")
    #expect(settings.valueProblems.count == 1)
    #expect(settings.valueProblems.first?.hasPrefix("gapHandles: ") == true)
  }

  @Test func whatLoadsWithoutAProblemIsNotReported() throws {
    for text in [#"{"gapHandles": true}"#, #"{"gapHandles": false}"#, #"{"gapHandles": "Hidden"}"#] {
      #expect(try decode(text).valueProblems.isEmpty, "\(text)")
    }
    #expect(try decode(#"{"gapHandles": "Hidden"}"#).gapHandles == "hidden")
  }

  @Test func aNewSettingsFileListsEverySwitch() throws {
    let json = String(decoding: try JSONEncoder().encode(Settings()), as: UTF8.self)
    for key in ["previewDrags", "gapHandles", "shareRemovedSpace", "shrinkOutOfView"] {
      #expect(json.contains("\"\(key)\""), "\(key)")
    }
  }
}

@Suite struct ShareRemovedSpaceTests {
  @Test func bothWaysAgreeWhileEveryoneIsThereAndTheWeightsAreEqual() {
    let tree = row()
    #expect(layout(tree, keep).windowFrames == layout(tree, share).windowFrames)
    #expect(layout(tree, keep).desktopFrame == layout(tree, share).desktopFrame)
  }

  @Test func theRowFillsTheScreenWithExactGapsWhateverTheWeights() {
    let result = layout(row(weights: [3, 1, 0.7, 2]), keep)
    let content = screen.insetBy(dx: 12, dy: 12)
    let frames = [result.windowFrames[a]!, result.windowFrames[b]!, result.windowFrames[c]!, result.desktopFrame!]
    #expect(frames.first!.minX == content.minX)
    #expect(frames.last!.maxX == content.maxX)
    for (left, right) in zip(frames, frames.dropFirst()) { #expect(right.minX - left.maxX == 12) }
  }

  @Test func aRemovedWindowsSpaceAndGapGoToTheNeighbourBefore() {
    for weights in [[1, 1, 1, 1], [3, 1, 0.7, 2]] {
      var tree = row(weights: weights)
      let before = layout(tree, keep)
      tree.remove(b, shareSpace: false)
      #expect(tree.invariantViolations().isEmpty)
      let after = layout(tree, keep)
      #expect(after.windowFrames[c] == before.windowFrames[c])
      #expect(after.desktopFrame == before.desktopFrame)
      #expect(after.windowFrames[a]!.minX == before.windowFrames[a]!.minX)
      #expect(after.windowFrames[a]!.maxX == before.windowFrames[b]!.maxX)
      #expect(after.windowFrames[a]!.width == before.windowFrames[a]!.width + before.windowFrames[b]!.width + 12)
    }
  }

  @Test func theFirstInTheRowLeavesItsSpaceToTheNeighbourAfter() {
    var tree = row(weights: [3, 1, 0.7, 2])
    let before = layout(tree, keep)
    tree.remove(a, shareSpace: false)
    let after = layout(tree, keep)
    #expect(after.windowFrames[b]!.minX == before.windowFrames[a]!.minX)
    #expect(after.windowFrames[b]!.maxX == before.windowFrames[b]!.maxX)
    #expect(after.windowFrames[c] == before.windowFrames[c])
    #expect(after.desktopFrame == before.desktopFrame)
  }

  @Test func sharingIsStillTheDefaultForRemoval() {
    var tree = row()
    let before = layout(tree, share)
    tree.remove(b)
    let after = layout(tree, share)
    #expect(after.windowFrames[a]!.width > before.windowFrames[a]!.width)
    #expect(after.windowFrames[c]!.width == after.windowFrames[a]!.width)
    #expect(after.desktopFrame!.width == after.windowFrames[a]!.width)
  }

  @Test func anAbsentWindowsSpaceCountsForTheNeighbourBeforeAndComesBack() {
    let tree = row(weights: [3, 1, 0.7, 2])
    let full = layout(tree, keep)
    let without = layout(tree, keep, without: [b])
    #expect(without.windowFrames[b] == nil)
    #expect(without.windowFrames[a]!.minX == full.windowFrames[a]!.minX)
    #expect(without.windowFrames[a]!.maxX == full.windowFrames[b]!.maxX)
    #expect(without.windowFrames[c] == full.windowFrames[c])
    #expect(without.desktopFrame == full.desktopFrame)
    // Nothing was written to the tree, so the window returns to the same spot.
    #expect(layout(tree, keep) == full)
  }

  @Test func absentWindowsAtTheStartCountForTheFirstThatIsThere() {
    let tree = row(weights: [3, 1, 0.7, 2])
    let full = layout(tree, keep)
    let without = layout(tree, keep, without: [a, b])
    #expect(without.windowFrames[c]!.minX == full.windowFrames[a]!.minX)
    #expect(without.windowFrames[c]!.maxX == full.windowFrames[c]!.maxX)
    #expect(without.desktopFrame == full.desktopFrame)
  }

  @Test func aRunOfAbsentWindowsCountsForTheSameNeighbour() {
    let tree = row(weights: [3, 1, 0.7, 2])
    let full = layout(tree, keep)
    let without = layout(tree, keep, without: [b, c])
    #expect(without.windowFrames[a]!.minX == full.windowFrames[a]!.minX)
    #expect(without.windowFrames[a]!.maxX == full.windowFrames[c]!.maxX)
    #expect(without.desktopFrame == full.desktopFrame)
  }

  @Test func withSharingAnAbsentWindowsSpaceGoesToTheWholeRow() {
    let tree = row()
    let full = layout(tree, share)
    let without = layout(tree, share, without: [b])
    #expect(without.windowFrames[c]!.width > full.windowFrames[c]!.width)
    #expect(without.desktopFrame!.width > full.desktopFrame!.width)
  }

  @Test func aSeamBesideAnAbsentWindowMovesByThePointsItIsDragged() {
    var tree = row(weights: [3, 1, 0.7, 2])
    let before = layout(tree, keep, without: [b])
    let seam = before.seams.first { $0.leading == tree.leaf(containing: a) }!
    #expect(seam.trailing == tree.leaf(containing: c))
    tree.moveBoundary(
      leading: seam.leading, trailing: seam.trailing, by: -40, pointsPerWeight: Double(seam.pointsPerWeight))
    let after = layout(tree, keep, without: [b])
    #expect(after.windowFrames[a]!.maxX == before.windowFrames[a]!.maxX - 40)
    #expect(after.windowFrames[c]!.minX == before.windowFrames[c]!.minX - 40)
    #expect(after.windowFrames[c]!.maxX == before.windowFrames[c]!.maxX)
    #expect(after.desktopFrame == before.desktopFrame)
  }

  @Test func dockingBesideAWindowMovesNobodyElse() {
    var tree = row(weights: [3, 1, 0.7, 2])
    let before = layout(tree, keep)
    tree.dock(d, beside: tree.leaf(containing: b)!, edge: .right, desktopColumn: true)
    let after = layout(tree, keep)
    #expect(after.windowFrames[a] == before.windowFrames[a])
    #expect(after.windowFrames[c] == before.windowFrames[c])
    #expect(after.windowFrames[b]!.minX == before.windowFrames[b]!.minX)
    #expect(after.windowFrames[d]!.maxX == before.windowFrames[b]!.maxX)
  }

  /// A window that comes and goes gives its room back to the one it took it from, whatever the switch says. It
  /// must not go to the neighbour before as well: on the left of `b` that is `a`, on the right `b` once more.
  @Test(arguments: [Edge.left, .right]) func aVisitorsRoomIsGivenBackOnlyOnce(edge: Edge) {
    let before = row(weights: [1, 2, 1, 3])
    var tree = before
    tree.dock(d, beside: tree.leaf(containing: b)!, edge: edge, desktopColumn: true)
    tree.remove(d, shareSpace: false)
    #expect(layout(tree, keep).windowFrames == layout(before, keep).windowFrames)
    #expect(layout(tree, keep).desktopFrame == layout(before, keep).desktopFrame)
    for window in [a, b, c] {
      #expect(tree[tree.leaf(containing: window)!]!.weight == before[before.leaf(containing: window)!]!.weight)
    }
  }

  /// Once something else in the row has changed it is no visit any more, and the switch decides.
  @Test func afterAnotherChangeAVisitorsRoomGoesToTheNeighbourBefore() {
    var tree = row()
    tree.dock(d, beside: tree.leaf(containing: b)!, edge: .left, desktopColumn: true)
    tree.moveBoundary(
      leading: tree.leaf(containing: c)!, trailing: tree.desktop, by: 20, pointsPerWeight: 100, minimumPoints: 0)
    let before = layout(tree, keep).windowFrames
    tree.remove(d, shareSpace: false)
    let after = layout(tree, keep).windowFrames
    #expect(after[b] == before[b])
    #expect(after[c] == before[c])
    #expect(after[a]!.minX == before[a]!.minX)
    #expect(after[a]!.maxX == before[d]!.maxX)
  }

  /// Making room (F61) says how long each slot should be. With the switch off a weight covers the gap as well.
  /// [a | Desktop | b], thirds: with a column for the Desktop, which gives.
  @Test func makingRoomGivesAWindowExactlyWhatItNeedsWithEitherValue() {
    for shareRemovedSpace in [true, false] {
      let options = LayoutOptions(shareRemovedSpace: shareRemovedSpace, desktopColumn: true)
      var tree = LayoutTree()
      tree.dock(a, beside: tree.root, edge: .left, desktopColumn: true)
      tree.dock(b, beside: tree.root, edge: .right, desktopColumn: true)
      let old = LayoutEngine.layout(tree, camera: tree.root, in: screen, options: options, isPresent: { _ in true })
      let (served, layout, _) = MakeRoom.serve(
        &tree, camera: tree.root, in: screen, options: options, isPresent: { _ in true },
        minimumSize: { $0 == a ? CGSize(width: 574, height: 240) : nil },
        terms: MakeRoom.Terms(desktopIsInUse: true))
      #expect(served.map(\.window) == [a], "\(shareRemovedSpace)")
      #expect((574...576).contains(layout.windowFrames[a]?.width ?? 0), "\(shareRemovedSpace)")
      #expect(layout.windowFrames[b] == old.windowFrames[b], "the Desktop gives first and nobody else is touched")
    }
  }

  /// What is seen of 1 includes the place reserved for 2, which is not 1's to give or to keep.
  @Test func roomIsMadeBesideAMinimizedWindowAsWellAndItsSlotIsLeftAlone() {
    var tree = LayoutTree()
    for raw in [3, 2, 1] as [UInt32] { tree.dock(WindowID(raw), beside: tree.root, edge: .left, desktopColumn: true) }
    let options = LayoutOptions(shareRemovedSpace: false, desktopColumn: true)
    // With a column for the Desktop. [1 and the slot of 2 | 3 | Desktop]: 702, 345 and 345 points. 3 needs 700.
    let (served, layout, _) = MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: options, isPresent: { $0 != WindowID(2) },
      minimumSize: { $0 == WindowID(3) ? CGSize(width: 700, height: 240) : nil },
      terms: MakeRoom.Terms(desktopIsInUse: true))
    #expect(served.map(\.window) == [WindowID(3)])
    #expect((700...702).contains(layout.windowFrames[WindowID(3)]?.width ?? 0))
    #expect((611...613).contains(layout.windowFrames[WindowID(1)]?.width ?? 0), "the Desktop gives first, down to a tile, and 1 gives the rest")
    let back = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, options: LayoutOptions(minimumUsableSize: .zero, shareRemovedSpace: false),
      isPresent: { _ in true })
    #expect((344...346).contains(back.windowFrames[WindowID(2)]?.width ?? 0), "what 2 comes back to is what it left")
    #expect((back.windowFrames[WindowID(1)]?.width ?? 0) >= 240, "and 1 has not paid with its place")
  }

  /// It gives of its own slot only, and keeps a usable width of that: when 2 comes back, 1 is still a window.
  @Test func aWindowBesideAReservedPlaceGivesNoMoreThanItsOwnSlot() {
    var tree = LayoutTree()
    for raw in [3, 2, 1] as [UInt32] { tree.dock(WindowID(raw), beside: tree.root, edge: .left, desktopColumn: true) }
    let before = tree
    // The same row. 3 wants 345 + 265 from the Desktop + more than the 105 that 1 can spare of its own 345.
    let (served, _, _) = MakeRoom.serve(
      &tree, camera: tree.root, in: screen, options: LayoutOptions(shareRemovedSpace: false, desktopColumn: true),
      isPresent: { $0 != WindowID(2) }, minimumSize: { $0 == WindowID(3) ? CGSize(width: 730, height: 240) : nil },
      terms: MakeRoom.Terms(desktopIsInUse: true))
    #expect(served.isEmpty)
    #expect(tree == before)
  }

  /// Any tree, any minimums, one window perhaps minimized, the switch off: whoever is served fits, and nobody pays with their place.
  @Test(arguments: [false, true]) func makingRoomHoldsItsPromisesWithTheSwitchOff(desktopColumn: Bool) {
    var seed: UInt64 = 0x5EED_F033
    func random(_ bound: Int) -> Int {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((seed >> 33) % UInt64(bound))
    }
    var servedInAll = 0
    for _ in 0..<400 {
      var tree = LayoutTree()
      var leaves = [tree.desktop]
      var minimums: [WindowID: CGSize] = [:]
      let count = 2 + random(6)
      for number in 1...count {
        let window = WindowID(UInt32(number))
        leaves.append(
          tree.dock(window, beside: leaves[random(leaves.count)], edge: Edge.allCases[random(4)], desktopColumn: desktopColumn))
        if random(2) == 0 { minimums[window] = CGSize(width: 100 + random(900), height: 100 + random(600)) }
      }
      let gone = WindowID(UInt32(random(2 * count)))
      let options = LayoutOptions(shareRemovedSpace: false, desktopColumn: desktopColumn)
      func serve(_ tree: inout LayoutTree) -> (served: [MakeRoom.Short], layout: Layout, gaveBack: Bool) {
        MakeRoom.serve(
          &tree, camera: tree.root, in: screen, options: options, isPresent: { $0 != gone },
          minimumSize: { minimums[$0] }, terms: MakeRoom.Terms(desktopIsInUse: true))
      }
      let old = LayoutEngine.layout(
        tree, camera: tree.root, in: screen, options: options, isPresent: { $0 != gone },
        minimumSize: { minimums[$0] })
      let (served, layout, _) = serve(&tree)
      servedInAll += served.count
      #expect(tree.invariantViolations().isEmpty)
      #expect(old.windowFrames.keys.allSatisfy { layout.windowFrames[$0] != nil })
      for window in served.compactMap(\.window) {
        let frame = layout.windowFrames[window] ?? .zero
        #expect(frame.width >= minimums[window]!.width - 1 && frame.height >= minimums[window]!.height - 1)
      }
      let settled = tree
      #expect(serve(&tree).served.isEmpty)
      #expect(tree == settled)
    }
    #expect(servedInAll > 100, "only \(servedInAll) were served: the test tests little")
  }

  @Test(arguments: [true, false]) func aCollapsingColumnThatJoinsTheRowMovesNobodyElse(desktopColumn: Bool) {
    // [a | [d over [b | c]] | desktop], the Desktop with room or without: when d leaves, b and c join the row.
    var tree = LayoutTree()
    tree.dock(a, beside: tree.desktop, edge: .left, desktopColumn: desktopColumn)
    let leafB = tree.dock(b, beside: tree.desktop, edge: .left, desktopColumn: desktopColumn)
    tree.dock(d, beside: leafB, edge: .top)
    tree.dock(c, beside: leafB, edge: .right)
    let before = layout(tree, keep)
    tree.remove(d, shareSpace: false)
    #expect(tree.invariantViolations().isEmpty)
    let after = layout(tree, keep)
    #expect(after.windowFrames[a] == before.windowFrames[a])
    #expect(after.desktopFrame == before.desktopFrame)
    #expect(after.windowFrames[b]!.minX == before.windowFrames[b]!.minX)
    #expect(after.windowFrames[b]!.width == before.windowFrames[b]!.width)
    #expect(after.windowFrames[c]!.maxX == before.windowFrames[c]!.maxX)
    #expect(after.windowFrames[b]!.minY == before.windowFrames[d]!.minY)
  }

  @Test func aTabThatLeavesItsGroupFreesNoSpace() {
    var tree = row(weights: [3, 1, 0.7, 2])
    tree.addToStack(d, leaf: tree.leaf(containing: b)!)
    let weights = tree.preorder().map { tree[$0]!.weight }
    tree.remove(d, shareSpace: false)
    #expect(tree.preorder().map { tree[$0]!.weight } == weights)
  }

  @Test func aRowTooShortForItsGapsStillLaysOut() {
    let tree = row(weights: [100, 0.001, 0.001, 1])
    let tiny = LayoutEngine.layout(
      tree, camera: tree.root, in: CGRect(x: 0, y: 0, width: 30, height: 30),
      options: keep, isPresent: { _ in true })
    // `size`, because `width` and `height` never read as negative.
    for frame in tiny.nodeFrames.values { #expect(frame.size.width >= 0 && frame.size.height >= 0) }
    let narrow = layout(tree, keep)
    for frame in narrow.nodeFrames.values { #expect(frame.size.width >= 0 && frame.size.height >= 0) }
  }

  @Test func aGroupTilesMiniatureFollowsTheSwitch() {
    // A narrow column of [a / b / c] drawn as a tile, with b absent.
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.desktop, edge: .left)
    let leafB = tree.dock(b, beside: leafA, edge: .bottom)
    tree.dock(c, beside: leafB, edge: .bottom)
    let column = tree.parent(of: leafA)!
    tree.moveBoundary(leading: column, trailing: tree.desktop, by: -0.8, pointsPerWeight: 1, minimumPoints: 0)
    func tile(_ options: LayoutOptions) -> Tile { layout(tree, options, without: [b]).tiles.first { $0.node == column }! }
    let shared = tile(LayoutOptions())
    let kept = tile(LayoutOptions(shareRemovedSpace: false))
    #expect(kept.miniature[a]!.height > shared.miniature[a]!.height)
    #expect(kept.miniature[c]!.height < shared.miniature[c]!.height)
  }

  @Test func thePreviewOfMovingADockedWindowMatchesTheDrop() {
    var workspace = Workspace(tree: row(weights: [3, 1, 0.7, 2]))
    let target = DropTarget.beside(workspace.tree.desktop, .right)
    let preview = workspace.previewFrame(for: b, at: target, in: screen, options: keep, isPresent: { _ in true })
    workspace.dock(b, at: target, shareSpace: false)
    let result = layout(workspace.tree, keep)
    #expect(preview == result.windowFrames[b])
  }

  @Test func workspaceRemovalsPassTheSwitchOn() {
    let tree = row(weights: [3, 1, 0.7, 2])
    let before = layout(tree, keep)
    var forgotten = Workspace(tree: tree)
    forgotten.forget(b, shareSpace: false)
    var undocked = Workspace(tree: tree)
    undocked.undock(b, floatingAt: CGRect(x: 0, y: 0, width: 100, height: 100), shareSpace: false)
    for workspace in [forgotten, undocked] {
      #expect(layout(workspace.tree, keep).windowFrames[c] == before.windowFrames[c])
      #expect(layout(workspace.tree, keep).windowFrames[a]!.maxX == before.windowFrames[b]!.maxX)
    }
  }
}
