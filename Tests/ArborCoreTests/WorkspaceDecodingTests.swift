import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let f1 = WindowID(11)

/// A workspace as the JSON object `state.json` holds, to damage before reading it back.
private struct WorkspaceFile {
  var object: [String: Any]

  init(_ workspace: Workspace) throws {
    object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as! [String: Any]
  }

  func read() throws -> (workspace: Workspace, notes: [String]) {
    let notes = DecodingNotes()
    return (try read(noting: notes), notes.notes)
  }

  func read(noting notes: DecodingNotes) throws -> Workspace {
    let decoder = JSONDecoder()
    decoder.userInfo[DecodingNotes.key] = notes
    return try decoder.decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
  }
}

private let pinnedWindow = WindowID(77)

/// root(h)[ column(v)[a, c], desktop, b ], the camera on the column after visiting a and b, view
/// 1 saved on a, a floating window that is a guest of b, one that is pinned, one stashed, one summoned.
private func sample() -> Workspace {
  var workspace = Workspace()
  // It floated first, so its own size is remembered.
  workspace.floating[a] = CGRect(x: 50, y: 60, width: 640, height: 480)
  workspace.dock(a, at: .cameraEdge(.left))
  workspace.dock(b, at: .cameraEdge(.right))
  workspace.dock(c, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
  workspace.moveCamera(to: workspace.tree.leaf(containing: a)!)
  workspace.saveView(slot: 1)
  workspace.moveCamera(to: workspace.tree.leaf(containing: b)!)
  workspace.moveCamera(to: workspace.tree.parent(of: workspace.tree.leaf(containing: a)!)!)
  _ = workspace.goBack()
  workspace.floating[f1] = CGRect(x: 500, y: 300, width: 400, height: 300)
  workspace.receive(f1, asGuestOf: workspace.tree.leaf(containing: b)!)
  workspace.floating[pinnedWindow] = CGRect(x: 900, y: 100, width: 300, height: 200)
  workspace.pin(pinnedWindow)
  // The first is stashed when the second is summoned.
  workspace.summon(WindowID(78), app: "A", at: CGRect(x: 100, y: 100, width: 300, height: 200))
  workspace.summon(WindowID(79), app: "B", at: CGRect(x: 200, y: 200, width: 300, height: 200))
  workspace.desktopIsOwedRoom = true
  return workspace
}

/// Nothing a workspace holds may refer to something its tree does not have.
private func expectConsistent(_ workspace: Workspace, at location: SourceLocation = #_sourceLocation) {
  let tree = workspace.tree
  #expect(tree.invariantViolations() == [], sourceLocation: location)
  #expect(tree.contains(workspace.camera), sourceLocation: location)
  #expect((workspace.back + workspace.forward).allSatisfy(tree.contains), sourceLocation: location)
  #expect(workspace.savedViews.values.allSatisfy(tree.contains), sourceLocation: location)
  #expect(workspace.floating.keys.allSatisfy { !workspace.isDocked($0) }, sourceLocation: location)
  #expect(Set(workspace.allWindows).count == workspace.allWindows.count, sourceLocation: location)
}

@Suite struct WorkspaceDecodingTests {
  @Test func aValidWorkspaceComesBackUntouchedAndWithoutNotes() throws {
    let workspace = sample()
    #expect(!workspace.back.isEmpty && !workspace.forward.isEmpty && !workspace.savedViews.isEmpty)
    let (decoded, notes) = try WorkspaceFile(workspace).read()
    #expect(decoded == workspace)
    #expect(notes == [])
  }

  /// If this fails, a stored property was added without a `CodingKeys` case and a line in `init(from:)`.
  @Test func everyStoredPropertyIsSaved() throws {
    let saved = Set(try WorkspaceFile(sample()).object.keys)
    let stored = Set(Mirror(reflecting: sample()).children.compactMap(\.label))
    #expect(saved == stored)
  }

  @Test func onlyTheTreeIsRequired() throws {
    var file = try WorkspaceFile(sample())
    file.object = ["tree": file.object["tree"]!]
    let (workspace, notes) = try file.read()
    #expect(workspace.tree == sample().tree)
    #expect(workspace.camera == workspace.tree.root)
    #expect(workspace.back.isEmpty && workspace.forward.isEmpty && workspace.savedViews.isEmpty && workspace.floating.isEmpty)
    #expect(notes == [], "an older file is not a damaged one")
    file.object = [:]
    #expect(throws: DecodingError.self) { try file.read() }
  }

  @Test func aCameraThatPointsNowhereGoesToTheRoot() throws {
    for camera in [77, -1] as [Any] + ["left", [1]] {
      var file = try WorkspaceFile(sample())
      file.object["camera"] = camera
      let (workspace, notes) = try file.read()
      #expect(workspace.camera == workspace.tree.root)
      #expect(!notes.isEmpty)
      expectConsistent(workspace)
    }
  }

  @Test func historyThatPointsNowhereIsDropped() throws {
    let original = sample()
    var file = try WorkspaceFile(original)
    file.object["back"] = [77] + original.back.map(\.rawValue) + [78, 79]
    file.object["forward"] = [80]
    let (workspace, _) = try file.read()
    #expect(workspace.back == original.back)
    #expect(workspace.forward == [])
    expectConsistent(workspace)
  }

  @Test func historyIsKeptToItsLimitNewestLast() throws {
    let original = sample()
    let (x, y) = (original.tree.root.rawValue, original.tree.desktop.rawValue)
    var file = try WorkspaceFile(original)
    file.object["back"] = Array(repeating: [x, y], count: 5_000).flatMap { $0 } + [x, x, x]
    let workspace = try file.read().workspace
    #expect(workspace.back.count == Workspace.historyLimit)
    #expect(workspace.back.suffix(2) == [NodeID(y), NodeID(x)], "repeats collapse and the newest entries stay")
  }

  @Test func savedViewsThatPointNowhereAreDropped() throws {
    let original = sample()
    var file = try WorkspaceFile(original)
    file.object["savedViews"] = ["1": original.savedViews["1"]!.rawValue, "2": 77]
    let (workspace, notes) = try file.read()
    #expect(workspace.savedViews == original.savedViews)
    #expect(notes.contains { $0.contains("saved view 2") })
  }

  @Test func referencesToNodesTheTreeRepairDroppedAreDroppedToo() throws {
    let original = sample()
    let leafA = original.tree.leaf(containing: a)!
    var file = try WorkspaceFile(original)
    var tree = file.object["tree"] as! [String: Any]
    var nodes = tree["nodes"] as! [String: Any]
    nodes[String(leafA.rawValue)] = nil
    tree["nodes"] = nodes
    file.object["tree"] = tree
    file.object["camera"] = leafA.rawValue
    let (workspace, _) = try file.read()
    #expect(workspace.tree.allWindows == [c, b])
    #expect(workspace.savedView(slot: 1) == nil)
    expectConsistent(workspace)
    // A node docked later must not inherit what used to point at the dropped one.
    var later = workspace
    later.dock(WindowID(50), at: .cameraEdge(.left))
    #expect(later.tree.leaf(containing: WindowID(50)) != leafA)
  }

  @Test func aWindowBothDockedAndFloatingIsDocked() throws {
    var file = try WorkspaceFile(sample())
    file.object["floating"] = ["1": [[0, 0], [300, 200]], "11": [[500, 300], [400, 300]]]
    let (workspace, notes) = try file.read()
    #expect(workspace.isDocked(a) && !workspace.isFloating(a))
    #expect(workspace.isFloating(f1))
    #expect(notes.contains { $0.contains("w1") })
    expectConsistent(workspace)
  }

  @Test func floatingFramesThatAreNotRectanglesAreDropped() throws {
    let bad: [Any] = [
      [[0, 0], [0, 200]], [[0, 0], [300, -200]], [[1e300, 0], [300, 200]], [[0, -1e18], [300, 200]],
      [[0, 0], [1e308, 1e308]], [[0, 0]], "everywhere", [[0, "0"], [300, 200]], NSNull(),
      // Found by `scripts/fuzz-launch.py`: more than nothing, and nothing once the window is placed.
      [[0, 0], [0.5, 200]], [[0, 0], [300, 0.001]], [[0, 0], [1e-320, 200]],
    ]
    for frame in bad {
      var file = try WorkspaceFile(sample())
      file.object["floating"] = ["11": [[500, 300], [400, 300]], "77": [[900, 100], [300, 200]], "78": [[100, 100], [300, 200]],
        "79": [[200, 200], [300, 200]], "12": frame,
      ]
      let (workspace, notes) = try file.read()
      #expect(workspace.floating == sample().floating, "\(frame)")
      #expect(!notes.isEmpty, "\(frame)")
    }
  }

  @Test func placesOfSummonedWindowsThatAreNotRectanglesAreDropped() throws {
    for size in [[0, 200], [0.5, 200], [300, 1e-320], [300, -1], [1e300, 200]] {
      var file = try WorkspaceFile(sample())
      file.object["summonFrames"] = ["A": [[100, 100], [300, 200]], "B": [[200, 200], [300, 200]], "C": [[0, 0], size]]
      let (workspace, notes) = try file.read()
      #expect(workspace.summonFrames == sample().summonFrames, "\(size)")
      #expect(!notes.isEmpty, "\(size)")
    }
  }

  @Test func guestsThatDoNotFloatHereOrHaveNoHostAreDropped() throws {
    let host = sample().guests![f1]!.rawValue
    for guests in [["11": 77], ["12": host], ["1": host], ["eleven": host]] as [[String: Int]] {
      var file = try WorkspaceFile(sample())
      file.object["guests"] = guests
      let (workspace, notes) = try file.read()
      #expect(workspace.guests == nil && !notes.isEmpty, "\(guests)")
      expectConsistent(workspace)
    }
    var file = try WorkspaceFile(sample())
    file.object["guests"] = ["11": host, "12": host]
    #expect(try file.read().workspace.guests == sample().guests)
  }

  // MARK: Could a person tell?

  /// Arbor can write some of these itself (a guest that went to another display, history that repeats): no cause for alarm.
  @Test func whatNobodyCouldTellIsTidiedNotLost() throws {
    let camera = sample().camera.rawValue
    let changes: [(String, (inout [String: Any]) -> Void)] = [
      ("history ended where the view is", { $0["back"] = ($0["back"] as! [Int]) + [camera] }),
      ("dropped 1 entries of `forward`", { $0["forward"] = ($0["forward"] as! [Int]) + [4711] }),
      ("dropped pins of windows that do not float here", { $0["pinned"] = [77, 1] }),
      ("dropped guests that do not float here or whose host does not exist", { $0["guests"] = ["11": 4711] }),
      ("frames were remembered for windows that are not docked, or were impossible",
       { $0["undockedFrames"] = ["1": [[50, 60], [640, 480]], "11": [[0, 0], [100, 100]]] }),
      ("dropped stashed windows that do not float here or have another role", { $0["stashed"] = [78, 2] }),
      ("w1 was both docked and floating", { object in
        var floating = object["floating"] as! [String: Any]
        floating["1"] = [[0, 0], [100, 100]]
        object["floating"] = floating
      }),
    ]
    for (note, change) in changes {
      var file = try WorkspaceFile(sample())
      change(&file.object)
      let notes = DecodingNotes()
      expectConsistent(try file.read(noting: notes))
      #expect(notes.losses == [], "\(note)")
      #expect(notes.tidied == [note], "\(note)")
      #expect(notes.notes == [note], "the log gets all of it")
    }
  }

  /// Where they were looking, a view they saved, a name they gave, where a window floated.
  @Test func whatAPersonCouldTellIsALoss() throws {
    let changes: [(String, (inout [String: Any]) -> Void)] = [
      ("the camera was on n4711, which does not exist", { $0["camera"] = 4711 }),
      ("saved view 1 was of n4711, which does not exist", { $0["savedViews"] = ["1": 4711] }),
      ("a name was of n4711, which does not exist", { $0["names"] = ["Payroll": 4711] }),
      ("`floating` could not be read", { $0["floating"] = 5 }),
    ]
    for (note, change) in changes {
      var file = try WorkspaceFile(sample())
      change(&file.object)
      let notes = DecodingNotes()
      expectConsistent(try file.read(noting: notes))
      #expect(notes.losses.contains(note), "\(note): \(notes.notes)")
    }
  }

  @Test func partsOfTheWrongTypeCostOnlyThemselves() throws {
    for key in ["back", "forward", "savedViews", "floating", "guests"] {
      var file = try WorkspaceFile(sample())
      file.object[key] = "none"
      let (workspace, notes) = try file.read()
      #expect(workspace.tree == sample().tree)
      #expect(workspace.camera == sample().camera)
      #expect(notes.contains { $0.contains(key) }, "\(key): \(notes)")
      expectConsistent(workspace)
    }
  }

  @Test func notesSayWhereInTheFileTheyApply() throws {
    struct Wrapper: Decodable { var displays: [String: Workspace] }
    var file = try WorkspaceFile(sample())
    file.object["camera"] = 77
    let decoder = JSONDecoder()
    let notes = DecodingNotes()
    decoder.userInfo[DecodingNotes.key] = notes
    _ = try decoder.decode(Wrapper.self, from: JSONSerialization.data(withJSONObject: ["displays": ["main": file.object]]))
    #expect(notes.notes == ["displays.main: the camera was on n77, which does not exist"])
  }
}

@Suite struct WorkspaceSemanticsTests {
  /// Every dock beside a node halves its weight and a removal gives nothing back, so a window that
  /// others keep docking beside and leaving used to reach weight 0 after 1,075 rounds.
  @Test func weightsStayUsableThroughThousandsOfDocksAndRemovals() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let leaf = workspace.tree.leaf(containing: a)!
    for round in 0..<5_000 {
      workspace.dock(b, at: .beside(leaf, round % 2 == 0 ? .right : .left))
      workspace.forget(b)
    }
    #expect(workspace.tree.invariantViolations() == [])
    let weights = workspace.tree.children(of: workspace.tree.root).map { workspace.tree[$0]!.weight }
    #expect(weights.allSatisfy { $0.isNormal && $0 > 1e-9 && $0 < 1e9 }, "\(weights)")
  }

  /// The small survivors of a row whose large members left: their weights are scaled back up
  /// instead of shrinking for ever, and their proportions are kept.
  @Test func aRowOfSmallSurvivorsIsScaledBackUp() {
    var tree = LayoutTree()
    var target = tree.dock(a, beside: tree.root, edge: .left)
    for id in 2...40 { target = tree.dock(WindowID(UInt32(id)), beside: target, edge: .right) }
    // Windows 39 and 40 share the last sliver equally; everything larger leaves except the Desktop.
    for id in 1...38 { tree.remove(WindowID(UInt32(id))) }
    #expect(tree.invariantViolations() == [])
    let (x, y) = (tree[tree.leaf(containing: WindowID(39))!]!.weight, tree[tree.leaf(containing: WindowID(40))!]!.weight)
    #expect(x == y)
    #expect(x >= tree[tree.desktop]!.weight * 1e-6)
  }

  @Test(arguments: Array<UInt64>(1...8)) func aLongRandomSessionKeepsEverythingConsistent(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    var next: UInt32 = 1
    for _ in 0..<600 {
      let nodes = workspace.tree.preorder()
      let node = nodes.randomElement(using: &random)!
      let edge = Edge.allCases.randomElement(using: &random)!
      let known = workspace.allWindows.randomElement(using: &random)
      switch Int.random(in: 0..<14, using: &random) {
      case 0, 1:
        guard workspace.tree.allWindows.count < 40 else { continue }
        workspace.dock(WindowID(next), at: .beside(node, edge))
        next += 1
      case 2:
        guard workspace.tree.allWindows.count < 40 else { continue }
        workspace.dock(WindowID(next), at: .cameraEdge(edge))
        next += 1
      case 3: if let known { workspace.dock(known, at: .beside(node, edge)) }
      case 4: if let known { workspace.dock(known, at: .stack(node)) }
      case 5, 6: if let known { workspace.forget(known) }
      case 7: if let known { workspace.undock(known, floatingAt: CGRect(x: 0, y: 0, width: 300, height: 200)) }
      case 8: workspace.moveCamera(to: node)
      case 9: _ = workspace.goBack()
      case 10: _ = workspace.goForward()
      case 11: workspace.saveView(slot: Int.random(in: 1...9, using: &random))
      case 12: workspace.dock(known ?? WindowID(next), at: .beside(NodeID(Int.random(in: -5...5_000, using: &random)), edge))
      default:
        let children = workspace.tree.children(of: node)
        guard children.count >= 2 else { continue }
        workspace.tree.moveBoundary(
          leading: children[0], trailing: children[1], by: Double.random(in: -500...500, using: &random),
          pointsPerWeight: Double.random(in: 0.001...2_000, using: &random))
      }
      expectConsistent(workspace)
      #expect(workspace.back.count <= 2 * Workspace.historyLimit)
    }
  }

  /// root(h)[ col(v)[ a, row(h)[b, c] ], desktop ]. Removing a collapses the column into the row,
  /// and with nothing on the row it merges into the root: three moves to follow for history.
  @Test func historyFollowsAChainOfMerges() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let leafA = workspace.tree.leaf(containing: a)!
    workspace.dock(b, at: .beside(leafA, .bottom))
    let leafB = workspace.tree.leaf(containing: b)!
    workspace.dock(c, at: .beside(leafB, .right))
    let row = workspace.tree.parent(of: leafB)!
    let column = workspace.tree.parent(of: leafA)!
    let root = workspace.tree.root

    for node in [column, row, leafB, leafA, root] { workspace.moveCamera(to: node) }
    workspace.forget(a)

    #expect(workspace.tree.root == root && workspace.camera == root)
    #expect(workspace.tree.children(of: root) == [leafB, workspace.tree.leaf(containing: c)!, workspace.tree.desktop])
    // History was root, column, row, b, a. All but b have become part of the root: they are listed
    // once, and not at the end, which is where the view is.
    #expect(workspace.back == [root, leafB])
    let wentBack = workspace.goBack()
    #expect(wentBack && workspace.camera == leafB)
  }

  /// The same, with views saved on the column and the row (F62): the row is kept, and both mean it.
  @Test func savedViewsKeepTheirGroupThroughTheSameChain() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let leafA = workspace.tree.leaf(containing: a)!
    workspace.dock(b, at: .beside(leafA, .bottom))
    let leafB = workspace.tree.leaf(containing: b)!
    workspace.dock(c, at: .beside(leafB, .right))
    let row = workspace.tree.parent(of: leafB)!
    let column = workspace.tree.parent(of: leafA)!
    let root = workspace.tree.root

    workspace.moveCamera(to: column)
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: row)
    workspace.saveView(slot: 2)
    workspace.moveCamera(to: leafB)
    workspace.saveView(slot: 3)
    workspace.moveCamera(to: leafA)
    workspace.forget(a)

    #expect(workspace.tree.invariantViolations() == [])
    #expect(workspace.tree.children(of: root) == [row, workspace.tree.desktop])
    #expect(workspace.savedView(slot: 1) == row && workspace.savedView(slot: 2) == row)
    #expect(workspace.savedView(slot: 3) == leafB)
    #expect(workspace.camera == row, "the view was on a: it goes to what is left of the group a was in")
    #expect(workspace.back == [root, row, leafB])
  }

  @Test func dockingOnStaleOrOddTargetsStillDocks() {
    var workspace = sample()
    let leafA = workspace.tree.leaf(containing: a)!
    // Beside its own leaf, which the move deletes: it lands beside what took the leaf's place.
    let besideItself = workspace.dock(a, at: .beside(leafA, .left))
    #expect(besideItself && workspace.isDocked(a))
    expectConsistent(workspace)
    // A node that does not exist, then the Desktop and a split, which are not stacks: dock beside them.
    for target in [NodeID(999), workspace.tree.desktop, workspace.tree.root] {
      let docked = workspace.dock(a, at: .stack(target))
      #expect(docked)
      expectConsistent(workspace)
      #expect(workspace.tree.allWindows.filter { $0 == a }.count == 1)
    }
    let before = workspace
    let notDocking = [workspace.dock(a, at: .float), workspace.dock(a, at: .none)]
    #expect(notDocking == [false, false] && workspace == before)
  }
}
