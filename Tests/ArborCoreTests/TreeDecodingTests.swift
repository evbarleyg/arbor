import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

/// A tree as the JSON object `state.json` holds, to damage before reading it back.
struct TreeFile {
  var object: [String: Any]

  init(_ tree: LayoutTree) throws {
    object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tree)) as! [String: Any]
  }

  var nodes: [String: Any] {
    get { object["nodes"] as! [String: Any] }
    set { object["nodes"] = newValue }
  }

  mutating func edit(_ node: NodeID, _ change: (inout [String: Any]) -> Void) {
    var fields = nodes[String(node.rawValue)] as! [String: Any]
    change(&fields)
    nodes[String(node.rawValue)] = fields
  }

  mutating func setChildren(of node: NodeID, axis: Axis, _ children: [NodeID]) {
    edit(node) { $0["kind"] = ["split": ["axis": axis.rawValue, "children": children.map(\.rawValue)]] }
  }

  mutating func setWindows(of node: NodeID, _ windows: [WindowID], active: Int = 0) {
    edit(node) { $0["kind"] = ["stack": ["windows": windows.map(\.rawValue), "active": active]] }
  }

  /// Reads the file back, with what the decoder said it repaired.
  func read() throws -> (tree: LayoutTree, notes: [String]) {
    let notes = DecodingNotes()
    return (try read(noting: notes), notes.notes)
  }

  func read(noting notes: DecodingNotes) throws -> LayoutTree {
    let decoder = JSONDecoder()
    decoder.userInfo[DecodingNotes.key] = notes
    return try decoder.decode(LayoutTree.self, from: JSONSerialization.data(withJSONObject: object))
  }
}

/// root(h)[ column(v)[a, c], desktop, b ]
private struct Fixture {
  var tree = LayoutTree()
  let leafA: NodeID
  let leafB: NodeID
  let leafC: NodeID
  var column: NodeID { tree.parent(of: leafA)! }

  init() {
    leafA = tree.dock(a, beside: tree.root, edge: .left)
    leafB = tree.dock(b, beside: tree.root, edge: .right)
    leafC = tree.dock(c, beside: leafA, edge: .bottom)
  }

  func file() throws -> TreeFile { try TreeFile(tree) }
}

/// Whatever came out of a file must be a tree the rest of Arbor can use: valid, and still valid
/// after it is laid out, docked into and emptied.
private func expectUsable(_ tree: LayoutTree, _ comment: Comment? = nil, at location: SourceLocation = #_sourceLocation) {
  #expect(tree.invariantViolations() == [], comment, sourceLocation: location)
  var tree = tree
  let before = Set(tree.nodes.keys)
  let layout = LayoutEngine.layout(tree, camera: tree.root, in: screen, isPresent: { _ in true })
  #expect(layout.nodeFrames[tree.root] != nil, comment, sourceLocation: location)
  let fresh = tree.dock(WindowID(900), beside: tree.root, edge: .left)
  #expect(!before.contains(fresh), "a new node must not take an id that is in use", sourceLocation: location)
  tree.dock(WindowID(901), beside: tree.desktop, edge: .top)
  #expect(tree.invariantViolations() == [], comment, sourceLocation: location)
  // What is docked after a repair must still be there after the next launch.
  let saved = try? JSONDecoder().decode(LayoutTree.self, from: JSONEncoder().encode(tree))
  #expect(saved == tree, "what was saved after the repair does not read back equal", sourceLocation: location)
  for window in tree.allWindows { tree.remove(window) }
  #expect(tree.root == tree.desktop, comment, sourceLocation: location)
  #expect(tree.invariantViolations() == [], comment, sourceLocation: location)
}

@Suite struct TreeDecodingTests {
  @Test func aValidTreeComesBackUntouchedAndWithoutNotes() throws {
    let f = Fixture()
    let (tree, notes) = try f.file().read()
    #expect(tree == f.tree)
    #expect(notes == [])
  }

  @Test(arguments: Array<UInt64>(1...20)) func randomValidTreesComeBackUntouched(seed: UInt64) throws {
    let tree = LayoutTree.random(seed: seed, windows: 25)
    let (decoded, notes) = try TreeFile(tree).read()
    #expect(decoded == tree)
    #expect(notes == [])
  }

  @Test func aChildThatDoesNotExistIsDropped() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.tree.root, axis: .horizontal, [f.column, f.tree.desktop, f.leafB, NodeID(77)])
    let (tree, notes) = try file.read()
    #expect(tree == f.tree)
    #expect(notes.contains { $0.contains("n77") })
    expectUsable(tree)
  }

  @Test func aNodeThatCannotBeReadIsDroppedAndTheRestKept() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.leafB) { $0["kind"] = ["hologram": [:] as [String: Any]] }
    let (tree, notes) = try file.read()
    #expect(tree.allWindows == [a, c])
    #expect(!notes.isEmpty)
    expectUsable(tree)
  }

  @Test func losingAllButOneChildCollapsesTheSplit() throws {
    let f = Fixture()
    var file = try f.file()
    file.nodes[String(f.leafC.rawValue)] = nil
    let (tree, _) = try file.read()
    #expect(tree.children(of: tree.root) == [f.leafA, tree.desktop, f.leafB])
    #expect(tree[f.leafA]?.weight == f.tree[f.column]?.weight)
    expectUsable(tree)
  }

  @Test func aCycleIsCut() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.column, axis: .vertical, [f.leafA, f.leafC, f.tree.root])
    let (tree, _) = try file.read()
    #expect(tree == f.tree)
    expectUsable(tree)
  }

  @Test func aSplitThatIsItsOwnChildIsCut() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.column, axis: .vertical, [f.column, f.leafA, f.leafC])
    expectUsable(try file.read().tree)
  }

  @Test func aNodeWithTwoParentsStaysWithTheFirst() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.tree.root, axis: .horizontal, [f.column, f.tree.desktop, f.leafB, f.leafA])
    let (tree, _) = try file.read()
    #expect(tree == f.tree)
    expectUsable(tree)
  }

  @Test func wrongParentLinksAreRebuiltFromTheChildLists() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.leafA) { $0["parent"] = f.leafB.rawValue }
    file.edit(f.tree.root) { $0["parent"] = f.column.rawValue }
    file.edit(f.leafC) { $0["parent"] = nil }
    #expect(try file.read().tree == f.tree)
  }

  @Test func aNodeFiledUnderAnotherIDTakesTheIDItIsFiledUnder() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.leafA) { $0["id"] = 55 }
    #expect(try file.read().tree == f.tree)
  }

  @Test func theDesktopTheFileNamesIsTheOneKept() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.leafA) { $0["kind"] = ["desktop": [:] as [String: Any]] }
    let (tree, _) = try file.read()
    #expect(tree.desktop == f.tree.desktop)
    #expect(tree.allWindows == [c, b])
    expectUsable(tree)
  }

  @Test func aDesktopFieldThatPointsElsewhereFallsBackToTheRealDesktop() throws {
    let f = Fixture()
    for wrong in [f.leafA.rawValue, 77] as [Any] + ["desk"] {
      var file = try f.file()
      file.object["desktop"] = wrong
      let (tree, _) = try file.read()
      #expect(tree == f.tree)
    }
  }

  @Test func aMissingDesktopIsAddedAtTheRight() throws {
    let f = Fixture()
    var file = try f.file()
    file.nodes[String(f.tree.desktop.rawValue)] = nil
    let (tree, notes) = try file.read()
    #expect(tree.allWindows == [a, c, b])
    #expect(tree.children(of: tree.root).last == tree.desktop)
    #expect(f.tree[tree.desktop] == nil, "the new Desktop needs an id of its own")
    #expect(notes.contains { $0.contains("Desktop") })
    expectUsable(tree)
  }

  @Test func aMissingDesktopBesideAColumnWrapsTheColumn() throws {
    var tree = LayoutTree()
    let top = tree.dock(a, beside: tree.root, edge: .top)
    tree.dock(b, beside: top, edge: .top)
    var file = try TreeFile(tree)
    file.nodes[String(tree.desktop.rawValue)] = nil
    let repaired = try file.read().tree
    #expect(repaired.allWindows == [b, a])
    #expect(repaired.children(of: repaired.root).last == repaired.desktop)
    expectUsable(repaired)
  }

  @Test func aWindowListedTwiceIsDockedOnce() throws {
    let f = Fixture()
    var file = try f.file()
    file.setWindows(of: f.leafB, [b, a, b])
    let (tree, _) = try file.read()
    #expect(tree.allWindows == [a, c, b])
    expectUsable(tree)
  }

  @Test func aStackLeftEmptyIsRemoved() throws {
    let f = Fixture()
    for windows in [[], [a], [a, c]] as [[WindowID]] {
      var file = try f.file()
      file.setWindows(of: f.leafB, windows)
      let (tree, _) = try file.read()
      #expect(tree.allWindows == [a, c])
      #expect(!tree.contains(f.leafB))
      expectUsable(tree)
    }
  }

  @Test func theActiveTabSurvivesRepairsAndABadIndexIsReset() throws {
    let f = Fixture()
    var file = try f.file()
    file.setWindows(of: f.leafB, [a, b, WindowID(8), WindowID(9)], active: 2)
    #expect(try file.read().tree.activeWindow(of: f.leafB) == WindowID(8))
    for index in [-1, 4, Int.max, Int.min] {
      file.setWindows(of: f.leafB, [b, WindowID(8)], active: index)
      let tree = try file.read().tree
      #expect(tree.activeWindow(of: f.leafB) == b)
      expectUsable(tree)
    }
  }

  @Test func weightsThatAreNotPositiveNumbersBecomeOne() throws {
    let f = Fixture()
    for weight in [0, -1, -0.0, -1e300] {
      var file = try f.file()
      file.edit(f.leafB) { $0["weight"] = weight }
      let (tree, _) = try file.read()
      #expect(tree.allWindows == [a, c, b])
      expectUsable(tree, "weight \(weight)")
    }
  }

  @Test func weightsTooLargeToAddAreEvenedOut() throws {
    let f = Fixture()
    var file = try f.file()
    for node in [f.column, f.leafB, f.tree.desktop] { file.edit(node) { $0["weight"] = 1.7e308 } }
    expectUsable(try file.read().tree)
  }

  /// The root has no siblings to be measured against, so nothing evened it out.
  @Test func anAbsurdWeightIsNotBelievedOfTheRootEither() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.tree.root) { $0["weight"] = 1e300 }
    let (tree, notes) = try file.read()
    #expect(tree[tree.root]!.weight == 1)
    #expect(notes.contains { $0.contains("1e+300") }, "\(notes)")
    expectUsable(tree)
  }

  /// A split that gives way to its only child hands it its weight, and that child may become the root.
  @Test func norOfWhatBecomesTheRoot() throws {
    var file = try TreeFile(LayoutTree())
    file.edit(LayoutTree().desktop) { $0["weight"] = 1e300 }
    expectUsable(try file.read().tree)

    let f = Fixture()
    file = try f.file()
    file.edit(f.tree.root) { $0["weight"] = 1e300 }
    file.setChildren(of: f.tree.root, axis: .horizontal, [f.tree.desktop])
    expectUsable(try file.read().tree)
  }

  /// One window must not take the whole row because of one number. The limit is 1e12; what Arbor writes stays
  /// below 1e8 (`steadyWeights`).
  @Test func anAbsurdWeightAmongSiblingsBecomesOne() throws {
    let f = Fixture()
    var file = try f.file()
    file.edit(f.leafB) { $0["weight"] = 2e12 }
    let (tree, notes) = try file.read()
    #expect(tree[f.leafB]!.weight == 1 && !notes.isEmpty)
    file.edit(f.leafB) { $0["weight"] = 1e12 }
    #expect(try file.read().tree.invariantViolations() == [])
  }

  @Test func sameAxisNestingIsFlattenedKeepingProportions() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.column, axis: .horizontal, [f.leafA, f.leafC])
    file.edit(f.leafA) { $0["weight"] = 3 }
    let (tree, _) = try file.read()
    #expect(tree.children(of: tree.root) == [f.leafA, f.leafC, tree.desktop, f.leafB])
    #expect(abs(tree[f.leafA]!.weight - 0.75) < 1e-12 && abs(tree[f.leafC]!.weight - 0.25) < 1e-12)
    expectUsable(tree)
  }

  @Test func aCollapseThatBringsTheSameAxisTogetherIsFlattenedToo() throws {
    // root(h)[ column(v)[ a, row(h)[c, d] ], desktop ]: without a, the row lands in the root.
    var tree = LayoutTree()
    let leafA = tree.dock(a, beside: tree.root, edge: .left)
    let leafC = tree.dock(c, beside: leafA, edge: .bottom)
    let leafD = tree.dock(WindowID(4), beside: leafC, edge: .right)
    var file = try TreeFile(tree)
    file.nodes[String(leafA.rawValue)] = nil
    let repaired = try file.read().tree
    #expect(repaired.children(of: repaired.root) == [leafC, leafD, repaired.desktop])
    expectUsable(repaired)
  }

  @Test func nodesNothingRefersToAreDropped() throws {
    let f = Fixture()
    var file = try f.file()
    file.nodes["40"] = ["id": 40, "weight": 1, "kind": ["stack": ["windows": [66], "active": 0]]]
    let (tree, notes) = try file.read()
    #expect(tree.allWindows == [a, c, b])
    #expect(!tree.contains(NodeID(40)))
    #expect(notes.contains("nothing refers to n40"))
    expectUsable(tree)
  }

  /// Found by `scripts/fuzz-launch.py audit`: it went without a note, so no copy of the file was kept, and two windows'
  /// places were gone with the next save.
  @Test func aChildListThatLostAnEntryIsNoted() throws {
    let f = Fixture()
    var file = try f.file()
    file.setChildren(of: f.tree.root, axis: .horizontal, f.tree.children(of: f.tree.root).filter { $0 != f.column })
    let (tree, notes) = try file.read()
    #expect(tree.allWindows == [b])
    #expect(notes == ["nothing refers to \([f.column, f.leafA, f.leafC].sorted().map(\.description).joined(separator: ", "))"])
    expectUsable(tree)
  }

  // MARK: Could a person tell?

  /// Bookkeeping that shows nowhere. To say "your arrangement was damaged" for it would be a false alarm.
  @Test func whatNobodyCouldTellIsTidiedNotLost() throws {
    let f = Fixture()
    let changes: [(String, (inout TreeFile) -> Void)] = [
      ("names the wrong parent", { $0.edit(f.leafA) { $0["parent"] = f.leafB.rawValue } }),
      ("nextRawID 0 is in use or out of range", { $0.object["nextRawID"] = 0 }),
      ("has active index 7", { $0.setWindows(of: f.leafA, [a], active: 7) }),
      ("the visits cannot be read", { $0.object["visits"] = "often" }),
      ("is an empty stack", { $0.setWindows(of: f.leafB, []) }),
    ]
    for (note, change) in changes {
      var file = try f.file()
      change(&file)
      let notes = DecodingNotes()
      expectUsable(try file.read(noting: notes))
      #expect(notes.losses == [], "\(note)")
      #expect(notes.tidied.contains { $0.hasSuffix(note) }, "\(note): \(notes.tidied)")
      #expect(notes.notes == notes.tidied, "the log gets all of it")
    }
  }

  /// A window's place, or its size.
  @Test func whatAPersonCouldTellIsALoss() throws {
    let f = Fixture()
    let changes: [(String, (inout TreeFile) -> Void)] = [
      ("which is missing or unreadable", { $0.nodes[String(f.leafB.rawValue)] = nil }),
      ("has weight -1.0", { $0.edit(f.leafA) { $0["weight"] = -1 } }),
      ("holds windows that are already docked", { $0.setWindows(of: f.leafB, [b, a]) }),
      ("is listed more than once", { $0.setChildren(of: f.column, axis: .vertical, [f.leafA, f.leafC, f.leafA]) }),
      ("nothing refers to \(f.leafC)", { $0.setChildren(of: f.column, axis: .vertical, [f.leafA, NodeID(90)]) }),
    ]
    for (note, change) in changes {
      var file = try f.file()
      change(&file)
      let notes = DecodingNotes()
      expectUsable(try file.read(noting: notes))
      #expect(notes.losses.contains { $0.hasSuffix(note) }, "\(note): \(notes.notes)")
      #expect(Set(notes.notes) == Set(notes.losses + notes.tidied))
    }
  }

  @Test func manyNodesNothingRefersToMakeOneShortNote() throws {
    var file = try Fixture().file()
    for id in 40..<52 { file.nodes["\(id)"] = ["id": id, "weight": 1, "kind": ["stack": ["windows": [id], "active": 0]]] }
    #expect(try file.read().notes.contains("nothing refers to n40, n41, n42, n43, n44 and 7 more"))
  }

  /// Found by hand: with `nextRawID` 1 the next dock overwrote the leaf holding `a`, and the window was lost.
  @Test func newNodesNeverTakeAnIDTheFileUses() throws {
    let f = Fixture()
    for next in [0, 1, -5, Int.min] as [Any] + ["soon"] {
      var file = try f.file()
      file.object["nextRawID"] = next
      file.nodes["40"] = ["id": 40, "weight": 1, "kind": ["stack": ["windows": [66], "active": 0]]]
      var tree = try file.read().tree
      let leaf = tree.dock(WindowID(5), beside: tree.root, edge: .left)
      #expect(leaf.rawValue > 40, "even a dropped node's id may still be named by a saved view")
      #expect(tree.allWindows == [WindowID(5), a, c, b])
    }
  }

  @Test func idsSoLargeThatCountingOnWouldOverflowAreRefusedOrDropped() throws {
    let f = Fixture()
    var file = try f.file()
    file.object["nextRawID"] = Int.max
    expectUsable(try file.read().tree)

    file.nodes[String(Int.max)] = ["id": Int.max, "weight": 1, "kind": ["stack": ["windows": [66], "active": 0]]]
    file.nodes["-3"] = ["id": -3, "weight": 1, "kind": ["stack": ["windows": [67], "active": 0]]]
    file.setChildren(
      of: f.tree.root, axis: .horizontal, [f.column, f.tree.desktop, f.leafB, NodeID(Int.max), NodeID(-3)])
    let tree = try file.read().tree
    #expect(tree.allWindows == [a, c, b])
    expectUsable(tree)
  }

  /// Found by executor L's launch fuzzer. A count beyond the limit was brought down to the limit itself, so
  /// the next node got an id that the next launch refused, and the count saved with it was too
  /// large again: every window docked from then on lost its place at every launch, for good.
  @Test(arguments: [Int.max, 1 << 48, (1 << 48) + 1, (1 << 48) - 1, (1 << 47) + 1])
  func aCountThatIsFarTooLargeHealsAtTheFirstLaunch(count: Int) throws {
    let f = Fixture()
    var file = try f.file()
    file.object["nextRawID"] = count
    var (tree, notes) = try file.read()
    #expect(notes.contains { $0.contains("nextRawID") })
    for launch in 1...3 {
      let window = WindowID(UInt32(100 + launch))
      tree.dock(window, beside: tree.root, edge: .left)
      let (next, more) = try TreeFile(tree).read()
      #expect(next == tree && more == [], "launch \(launch)")
      tree = next
    }
    #expect(tree.allWindows.count == 6)
  }

  /// No session of Arbor's gets near such ids, and counting on from one would soon pass what is read back.
  @Test func aTreeWhoseIDsLeaveNoRoomToCountOnIsRefused() throws {
    let f = Fixture()
    for id in [(1 << 48) - 1, 1 << 47] {
      var file = try f.file()
      file.nodes[String(id)] = ["id": id, "weight": 1, "kind": ["stack": ["windows": [66], "active": 0]]]
      #expect(throws: DecodingError.self, "\(id)") { try file.read() }
    }
    // Short of the line it is read. (Within a few ids of it, a session's own nodes cross the line and the
    // next launch starts afresh, once. Only renumbering the tree would spare a file aimed at that number.)
    var file = try f.file()
    let large = (1 << 47) - 1_000
    file.nodes[String(large)] = ["id": large, "weight": 1, "kind": ["stack": ["windows": [66], "active": 0]]]
    expectUsable(try file.read().tree)
  }

  @Test func keysThatAreNotPlainNumbersAreSkipped() throws {
    let f = Fixture()
    var file = try f.file()
    for key in ["+1", "01", "one", "", "1.0", "١"] { file.nodes[key] = ["id": 1, "weight": 1, "kind": ["desktop": [:] as [String: Any]]] }
    #expect(try file.read().tree == f.tree)
  }

  @Test func aTreeWithoutItsRootIsRefused() throws {
    let f = Fixture()
    var file = try f.file()
    file.object["root"] = 77
    #expect(throws: DecodingError.self) { try file.read() }
    file.object["root"] = nil
    #expect(throws: DecodingError.self) { try file.read() }
    file = try f.file()
    file.nodes[String(f.tree.root.rawValue)] = nil
    #expect(throws: DecodingError.self) { try file.read() }
    file.object["nodes"] = nil
    #expect(throws: DecodingError.self) { try file.read() }
  }

  @Test func aRootWithNothingUsableUnderItBecomesABareDesktop() throws {
    let f = Fixture()
    var file = try f.file()
    file.setWindows(of: f.tree.root, [])
    let tree = try file.read().tree
    #expect(tree.root == tree.desktop && tree.allWindows.isEmpty)
    expectUsable(tree)
  }

  @Test func aStackAsTheRootGetsADesktopBesideIt() throws {
    let f = Fixture()
    var file = try f.file()
    file.setWindows(of: f.tree.root, [a])
    let tree = try file.read().tree
    #expect(tree.allWindows == [a])
    expectUsable(tree)
  }

  /// Repairing and laying out a tree recurse once per level, so a file must not be able to ask for a
  /// hundred thousand levels. (On the main actor for its 8 MB stack, like Arbor itself: macOS gives
  /// other threads 512 KB, which this many levels can overflow in a debug build.)
  @MainActor @Test func absurdNestingIsRefusedRatherThanOverflowingTheStack() throws {
    func nested(levels: Int) -> TreeFile {
      var nodes: [String: Any] = ["0": ["id": 0, "weight": 1, "kind": ["desktop": [:] as [String: Any]]]]
      // Split 2k holds leaf 2k+1 and split 2k+2, on alternating axes; the last holds the Desktop.
      for level in 1...levels {
        let id = level * 2
        nodes[String(id)] = [
          "id": id, "weight": 1,
          "kind": ["split": ["axis": level % 2 == 0 ? "horizontal" : "vertical", "children": [id + 1, level == levels ? 0 : id + 2]]],
        ]
        nodes[String(id + 1)] = ["id": id + 1, "weight": 1, "kind": ["stack": ["windows": [id], "active": 0]]]
      }
      var file = try! TreeFile(LayoutTree())
      file.object = ["nodes": nodes, "root": 2, "desktop": 0, "nextRawID": levels * 2 + 2]
      return file
    }
    // The leaves of the last split are as deep as there are splits.
    let deep = try nested(levels: 98).read().tree
    #expect(deep.allWindows.count == 98)
    expectUsable(deep)
    #expect(try nested(levels: 100).read().tree.allWindows.count == 100)
    #expect(throws: DecodingError.self) { try nested(levels: 101).read() }
    #expect(throws: DecodingError.self) { try nested(levels: 3_000).read() }
  }

  @Test func aFileWithAbsurdlyManyNodesIsRefused() throws {
    var file = try Fixture().file()
    var nodes = file.nodes
    for id in 100..<10_200 { nodes[String(id)] = ["id": id, "weight": 1, "kind": ["desktop": [:] as [String: Any]]] }
    file.nodes = nodes
    #expect(throws: DecodingError.self) { try file.read() }
  }

  /// Random damage: whatever is done to the file, reading it either throws or gives a usable tree.
  @Test(arguments: Array<UInt64>(1...60)) func randomDamageNeverGivesABrokenTree(seed: UInt64) throws {
    var random = SeededRandom(seed: seed)
    let original = LayoutTree.random(seed: seed, windows: 12)
    var file = try TreeFile(original)
    let ids = original.nodes.keys.sorted()
    func anyID() -> NodeID {
      Int.random(in: 0..<8, using: &random) == 0 ? NodeID(Int.random(in: -2...60, using: &random)) : ids.randomElement(using: &random)!
    }
    for _ in 0..<Int.random(in: 1...6, using: &random) {
      let victim = ids.randomElement(using: &random)!
      guard file.nodes[String(victim.rawValue)] != nil else { continue }
      switch Int.random(in: 0..<9, using: &random) {
      case 0: file.nodes[String(victim.rawValue)] = nil
      case 1: file.edit(victim) { $0["weight"] = [0, -3, 1e-300, 1e300, 5].randomElement(using: &random)! }
      case 2: file.edit(victim) { $0["parent"] = anyID().rawValue }
      case 3:
        let children = (0..<Int.random(in: 0...4, using: &random)).map { _ in anyID() }
        file.setChildren(of: victim, axis: Axis.allCases.randomElement(using: &random)!, children)
      case 4:
        let windows = (0..<Int.random(in: 0...3, using: &random)).map { _ in WindowID(UInt32.random(in: 1...14, using: &random)) }
        file.setWindows(of: victim, windows, active: Int.random(in: -1...3, using: &random))
      case 5: file.edit(victim) { $0["kind"] = ["desktop": [:] as [String: Any]] }
      case 6: file.object["root"] = anyID().rawValue
      case 7: file.object["desktop"] = anyID().rawValue
      default: file.object["nextRawID"] = Int.random(in: -1...30, using: &random)
      }
    }
    guard let tree = try? file.read().tree else { return }
    expectUsable(tree)
    #expect(Set(tree.allWindows).count == tree.allWindows.count)
    // Reading what was repaired changes nothing more.
    let (again, notes) = try TreeFile(tree).read()
    #expect(again == tree)
    #expect(notes == [])
  }
}

@Suite struct TreeTotalityTests {
  @Test func dockingADockedWindowAgainChangesNothing() {
    let f = Fixture()
    var tree = f.tree
    let leaf = tree.dock(a, beside: f.leafB, edge: .right)
    #expect(leaf == f.leafA)
    #expect(tree == f.tree)
  }

  @Test func stackingADockedWindowAgainChangesNothing() {
    let f = Fixture()
    var tree = f.tree
    // Already docked, twice; then a split, the Desktop and a node that does not exist.
    tree.addToStack(a, leaf: f.leafB)
    tree.addToStack(a, leaf: f.leafA)
    tree.addToStack(WindowID(9), leaf: f.column)
    tree.addToStack(WindowID(9), leaf: tree.desktop)
    tree.addToStack(WindowID(9), leaf: NodeID(77))
    #expect(tree == f.tree)
    tree.addToStack(WindowID(9), leaf: f.leafB)
    #expect(tree.leaf(containing: WindowID(9)) == f.leafB)
  }

  @Test func replacingWithAWindowThatIsAlreadyDockedChangesNothing() {
    let f = Fixture()
    var tree = f.tree
    let refused = [
      tree.replaceWindow(a, with: b), tree.replaceWindow(a, with: a),
      tree.replaceWindow(WindowID(9), with: WindowID(10)),
    ]
    #expect(refused == [false, false, false])
    #expect(tree == f.tree)
    let replaced = tree.replaceWindow(a, with: WindowID(9))
    #expect(replaced)
    #expect(tree.leaf(containing: WindowID(9)) == f.leafA)
  }

  @Test func everyOperationShrugsOffIDsThatAreNotInTheTree() {
    let f = Fixture()
    var tree = f.tree
    let ghost = NodeID(77)
    let nobody = WindowID(77)
    let remap = tree.remove(nobody)
    #expect(remap.isEmpty)
    tree.activate(nobody)
    tree.swapSiblings(ghost, f.leafA)
    tree.swapSiblings(f.leafA, ghost)
    tree.swapSiblings(f.leafA, f.leafB)  // not siblings
    tree.swapLeaves(of: nobody, and: a)
    tree.swapLeaves(of: a, and: a)
    tree.moveBoundary(leading: ghost, trailing: f.leafA, by: 10, pointsPerWeight: 100)
    tree.moveBoundary(leading: f.leafA, trailing: ghost, by: 10, pointsPerWeight: 100)
    #expect(tree == f.tree)
    #expect(tree.children(of: ghost) == [] && tree.parent(of: ghost) == nil && tree.ancestors(of: ghost) == [])
    #expect(tree.preorder(from: ghost) == [] && tree.windows(under: ghost) == [] && tree.activeWindow(of: ghost) == nil)
    #expect(!tree.subtree(f.column, contains: ghost) && tree.depth(of: ghost) == 0)
    // Docking beside a node that has gone docks beside everything.
    let leaf = tree.dock(nobody, beside: ghost, edge: .left)
    #expect(tree.children(of: tree.root).first == leaf)
    #expect(tree.invariantViolations() == [])
  }

  @Test func aBoundaryOnlyMovesBetweenChildrenOfOneSplit() {
    let f = Fixture()
    var tree = f.tree
    tree.moveBoundary(leading: f.leafA, trailing: f.leafB, by: 50, pointsPerWeight: 400)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafA, by: 50, pointsPerWeight: 400)
    tree.moveBoundary(leading: tree.root, trailing: f.leafA, by: 50, pointsPerWeight: 400)
    #expect(tree == f.tree)
  }

  @Test func aBoundaryIgnoresNumbersThatAreNotNumbers() {
    let f = Fixture()
    var tree = f.tree
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: .nan, pointsPerWeight: 400)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: .nan)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: .infinity)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: 0)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: -400)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: 400, minimumPoints: .nan)
    tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: 10, pointsPerWeight: 400, minimumPoints: -80)
    #expect(tree == f.tree)
    // An endless drag stops at the minimum, in either direction, and nothing is left at zero.
    for delta in [Double.infinity, -.infinity, 1e308, -1e308] {
      tree.moveBoundary(leading: f.leafA, trailing: f.leafC, by: delta, pointsPerWeight: 400, minimumPoints: 0)
      #expect(tree.invariantViolations() == [])
      #expect(abs(tree[f.leafA]!.weight + tree[f.leafC]!.weight - 2) < 1e-5)
    }
  }

  @Test func aGridDocksAWindowListedTwiceOnce() {
    let tree = LayoutTree.grid(of: [a, b, a, c, b])
    #expect(tree.allWindows == [a, b, c])
    #expect(tree.invariantViolations() == [])
  }

  /// `arrangeDesktopWeight` comes straight from settings.json. With -1 the second column of two
  /// was laid out beyond the right edge of the display.
  @Test(arguments: [0, -1, -0.5, Double.nan, .infinity, -.infinity, 1e-300, 1e300])
  func aGridStaysOnTheDisplayWithAnyDesktopWeight(weight: Double) {
    let tree = LayoutTree.grid(of: [a, b], desktopWeight: weight)
    #expect(tree.invariantViolations() == [])
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: screen, options: LayoutOptions(minimumUsableSize: .zero), isPresent: { _ in true })
    for frame in layout.nodeFrames.values { #expect(screen.contains(frame)) }
  }

  @Test func gridColumnsDifferByAtMostOneWindow() {
    for count in 1...30 {
      let windows = (1...count).map { WindowID(UInt32($0)) }
      let tree = LayoutTree.grid(of: windows)
      #expect(tree.invariantViolations() == [])
      #expect(tree.allWindows == windows, "columns fill top to bottom, left to right")
      let columns = tree.children(of: tree.root).dropLast()
      #expect(tree.children(of: tree.root).last == tree.desktop)
      let heights = columns.map { tree.windows(under: $0).count }
      #expect(heights.count == Int(Double(count).squareRoot().rounded(.up)))
      #expect(heights.max()! - heights.min()! <= 1, "\(count) windows gave columns of \(heights)")
      #expect(heights == heights.sorted(by: >))
    }
  }
}

extension LayoutTree {
  /// A valid tree built by random docks, stacks, removals and resizes.
  static func random(seed: UInt64, windows count: Int) -> LayoutTree {
    var random = SeededRandom(seed: seed)
    var tree = LayoutTree()
    var next: UInt32 = 1
    while tree.allWindows.count < count {
      let nodes = tree.preorder()
      let target = nodes.randomElement(using: &random)!
      switch Int.random(in: 0..<10, using: &random) {
      case 0 where tree.isStack(target):
        tree.addToStack(WindowID(next), leaf: target)
        next += 1
      case 1:
        if let window = tree.allWindows.randomElement(using: &random) { tree.remove(window) }
      case 2:
        let children = tree.children(of: target)
        guard children.count >= 2 else { continue }
        let index = Int.random(in: 0..<(children.count - 1), using: &random)
        tree.moveBoundary(
          leading: children[index], trailing: children[index + 1], by: Double.random(in: -200...200, using: &random),
          pointsPerWeight: 300, minimumPoints: 20)
      default:
        tree.dock(WindowID(next), beside: target, edge: Edge.allCases.randomElement(using: &random)!)
        next += 1
      }
    }
    return tree
  }
}
