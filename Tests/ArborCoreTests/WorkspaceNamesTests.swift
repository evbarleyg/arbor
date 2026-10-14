import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let d = WindowID(4)

/// root(h)[ a, column(v)[b, c], desktop ]
private struct Fixture {
  var workspace = Workspace()
  let leafA: NodeID, leafB: NodeID, leafC: NodeID, column: NodeID

  init() {
    workspace.dock(a, at: .cameraEdge(.left))
    leafA = workspace.tree.leaf(containing: a)!
    workspace.dock(b, at: .beside(leafA, .right))
    leafB = workspace.tree.leaf(containing: b)!
    workspace.dock(c, at: .beside(leafB, .bottom))
    leafC = workspace.tree.leaf(containing: c)!
    column = workspace.tree.parent(of: leafB)!
  }
}

extension Workspace {
  fileprivate func windows(named name: String) -> [WindowID]? { node(named: name).map { tree.windows(under: $0) } }
}

/// F20: the names of one display's spaces.
@Suite struct WorkspaceNamesTests {
  // MARK: The two rules

  @Test func aNameIsKeptAsTypedAndFoundWhateverTheCapitals() throws {
    var f = Fixture()
    let naming = try f.workspace.setName("  Writing   Desk ", of: f.column)
    #expect(naming.name == "Writing Desk" && naming.node == f.column && naming.changed)
    #expect(naming.replaced == nil && naming.takenFrom == nil)
    #expect(f.workspace.names == ["Writing Desk": f.column])
    #expect(f.workspace.name(of: f.column) == "Writing Desk")
    #expect(f.workspace.node(named: "writing desk") == f.column)
    #expect(f.workspace.node(named: "writing") == nil, "no beginnings here")
  }

  @Test func namingANamedSpaceRenamesIt() throws {
    var f = Fixture()
    try f.workspace.setName("Draft", of: f.column)
    let naming = try f.workspace.setName("Writing", of: f.column)
    #expect(naming.replaced == "Draft" && naming.takenFrom == nil && naming.changed)
    #expect(f.workspace.names == ["Writing": f.column])
  }

  @Test func aNameGivenToASecondSpaceMoves() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    let naming = try f.workspace.setName("WRITING", of: f.leafA)
    #expect(naming.takenFrom == f.column && naming.replaced == nil && naming.changed)
    #expect(f.workspace.names == ["WRITING": f.leafA])
  }

  @Test func aNameCanMoveOntoASpaceThatHasOne() throws {
    var f = Fixture()
    try f.workspace.setName("Web", of: f.leafA)
    try f.workspace.setName("Writing", of: f.column)
    let naming = try f.workspace.setName("Web", of: f.column)
    #expect(naming.replaced == "Writing" && naming.takenFrom == f.leafA)
    #expect(f.workspace.names == ["Web": f.column])
  }

  @Test func theSameNameAgainChangesNothingAndOtherCapitalsRename() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    #expect(try f.workspace.setName("Writing", of: f.column).changed == false)
    let naming = try f.workspace.setName("writing", of: f.column)
    #expect(naming.changed && naming.replaced == "Writing" && naming.takenFrom == nil)
    #expect(f.workspace.names == ["writing": f.column])
  }

  @Test func aTextThatCannotBeANameChangesNothing() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    #expect(throws: SpaceName.Problem.self) { try f.workspace.setName("left", of: f.column) }
    #expect(throws: SpaceName.Problem.self) { try f.workspace.setName(" ", of: f.leafA) }
    #expect(f.workspace.names == ["Writing": f.column])
  }

  @Test func anySpaceCanHaveAName() throws {
    var f = Fixture()
    try f.workspace.setName("All", of: f.workspace.tree.root)
    try f.workspace.setName("Scratch", of: f.workspace.tree.desktop)
    try f.workspace.setName("Web", of: f.leafA)
    try f.workspace.setName("Writing", of: f.column)
    #expect(f.workspace.names.count == 4)
    #expect(try f.workspace.setName("Nowhere", of: NodeID(999)).node == f.workspace.tree.root, "as everywhere, the root stands in")
  }

  @Test func removingAName() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    #expect(f.workspace.removeName(of: f.leafA) == nil)
    #expect(f.workspace.removeName(of: f.column) == "Writing")
    #expect(f.workspace.names.isEmpty)
  }

  @Test func namingChangesNeitherTheViewNorWhatIsWhere() throws {
    var f = Fixture()
    f.workspace.moveCamera(to: f.column)
    let before = f.workspace
    try f.workspace.setName("Writing", of: f.column)
    #expect(f.workspace.camera == before.camera && f.workspace.back == before.back)
    #expect(f.workspace.tree.allWindows == before.tree.allWindows)
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  // MARK: What a name stays with

  @Test func aNameStaysWhileOtherWindowsComeAndGo() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.forget(a)
    #expect(f.workspace.windows(named: "Writing") == [b, c])
    f.workspace.dock(d, at: .beside(f.leafB, .right))
    #expect(f.workspace.windows(named: "Writing") == [b, d, c], "docked beside a member, it is inside")
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func theNameOfAWindowsPlaceFollowsTheWindow() throws {
    var f = Fixture()
    try f.workspace.setName("Web", of: f.leafA)
    f.workspace.dock(a, at: .beside(f.leafC, .bottom))
    #expect(f.workspace.windows(named: "Web") == [a])
    #expect(f.workspace.node(named: "Web") == f.workspace.tree.leaf(containing: a))
  }

  @Test func theNameGoesWithTheLastWindow() throws {
    for leave in ["close", "float"] {
      var f = Fixture()
      try f.workspace.setName("Web", of: f.leafA)
      try f.workspace.setName("Writing", of: f.column)
      if leave == "close" { f.workspace.forget(a) } else { f.workspace.undock(a, floatingAt: CGRect(x: 0, y: 0, width: 100, height: 100)) }
      #expect(f.workspace.names.keys.sorted() == ["Writing"], "\(leave): nothing else takes the name over")
      f.workspace.forget(b)
      #expect(f.workspace.windows(named: "Writing") == [c])
      f.workspace.forget(c)
      #expect(f.workspace.names.isEmpty, "\(leave)")
      #expect(f.workspace.tree.invariantViolations() == [])
    }
  }

  @Test func aSpaceThatHoldsTheDesktopNeverEmpties() throws {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    try workspace.setName("All", of: workspace.tree.root)
    workspace.forget(a)
    let node = try #require(workspace.node(named: "All"))
    #expect(workspace.tree.subtree(node, contains: workspace.tree.desktop), "what is left of it")
    #expect(workspace.tree.invariantViolations() == [])
  }

  @Test func aTabGroupKeepsItsNameWhileTabsComeAndGo() throws {
    var f = Fixture()
    try f.workspace.setName("Web", of: f.leafA)
    f.workspace.dock(d, at: .stack(f.leafA))
    #expect(f.workspace.windows(named: "Web") == [a, d])
    f.workspace.forget(a)
    #expect(f.workspace.windows(named: "Web") == [d])
    f.workspace.dock(d, at: .beside(f.leafB, .top))
    #expect(f.workspace.windows(named: "Web") == [d], "down to one window, the name follows it")
  }

  @Test func aTabThatLeavesANamedTabGroupLeavesTheNameBehind() throws {
    var f = Fixture()
    f.workspace.dock(d, at: .stack(f.leafA))
    try f.workspace.setName("Web", of: f.leafA)
    f.workspace.dock(d, at: .beside(f.leafB, .top))
    #expect(f.workspace.windows(named: "Web") == [a])
  }

  @Test func aWindowThatJoinsANamedTabGroupGivesUpItsOwnName() throws {
    var f = Fixture()
    try f.workspace.setName("Web", of: f.leafA)
    try f.workspace.setName("Notes", of: f.leafB)
    f.workspace.dock(b, at: .stack(f.leafA))
    #expect(f.workspace.names == ["Web": f.leafA])
  }

  @Test func aNamedWindowThatBecomesATabGivesTheTabGroupItsName() throws {
    var f = Fixture()
    try f.workspace.setName("Notes", of: f.leafB)
    f.workspace.dock(b, at: .stack(f.leafA))
    #expect(f.workspace.windows(named: "Notes") == [a, b], "better than losing it")
  }

  @Test func resettingTheTreeRemovesTheNames() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.reset(tree: .grid(of: [a, b, c]))
    #expect(f.workspace.names.isEmpty)
  }

  // MARK: A named group is kept (F62)

  /// root(h)[ column(v)[ a, row(h)[c, d] ], desktop ]: without `a` the row would dissolve into the root.
  private func nested() throws -> (Workspace, row: NodeID, column: NodeID) {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: a)!, .bottom))
    workspace.dock(d, at: .beside(workspace.tree.leaf(containing: c)!, .right))
    let row = try #require(workspace.tree.parent(of: workspace.tree.leaf(containing: c)!))
    return (workspace, row, try #require(workspace.tree.parent(of: row)))
  }

  @Test func aNamedGroupSurvivesItsNeighboursLeaving() throws {
    var (workspace, row, _) = try nested()
    try workspace.setName("Pair", of: row)
    workspace.forget(a)
    #expect(workspace.node(named: "Pair") == row)
    #expect(workspace.windows(named: "Pair") == [c, d], "and not everything")
    #expect(workspace.tree.invariantViolations() == [])
  }

  @Test func aNamedGroupDownToOneWindowIsStillThatGroup() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.forget(b)
    #expect(f.workspace.node(named: "Writing") == f.column)
    f.workspace.dock(d, at: .beside(f.leafC, .top))
    #expect(f.workspace.windows(named: "Writing") == [d, c], "up again, and still Writing")
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func onlyGroupsThatHaveANameAreKeptForOne() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    try f.workspace.setName("Web", of: f.leafA)
    #expect(f.workspace.tree.kept(for: .name) == [f.column])
    try f.workspace.setName("Writing", of: f.workspace.tree.root)
    #expect(f.workspace.tree.kept(for: .name) == [f.workspace.tree.root], "the name moved, and the keeping with it")
    f.workspace.removeName(of: f.workspace.tree.root)
    #expect(f.workspace.tree.kept(for: .name) == [])
  }

  @Test func aGroupThatLosesItsNameDissolvesWhereItWouldHaveAndTheViewFollows() throws {
    var (workspace, row, _) = try nested()
    try workspace.setName("Pair", of: row)
    workspace.forget(a)
    workspace.moveCamera(to: workspace.tree.root)
    workspace.removeName(of: row)
    #expect(!workspace.tree.contains(row), "nothing holds it any more")
    #expect(workspace.tree.allWindows == [c, d])
    #expect(workspace.tree.invariantViolations() == [])

    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.forget(b)
    f.workspace.moveCamera(to: f.column)
    f.workspace.removeName(of: f.column)
    #expect(f.workspace.camera == f.leafC, "the view is on what the group held")
  }

  // MARK: What is docked at an edge of the view joins the named space

  @Test(arguments: Edge.allCases) func dockedAtAnyEdgeOfTheViewOfANamedGroupItIsInside(edge: Edge) throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.moveCamera(to: f.column)
    f.workspace.dock(d, at: .cameraEdge(edge))
    #expect(Set(try #require(f.workspace.windows(named: "Writing"))) == [b, c, d])
    #expect(f.workspace.camera == f.workspace.node(named: "Writing"), "the view is still on Writing, and on nothing more")
    #expect(f.workspace.names.count == 1)
    #expect(f.workspace.tree.kept(for: .name) == [f.workspace.camera])
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test(arguments: Edge.allCases) func dockedAtAnyEdgeOfTheViewOfANamedWindowItMakesANamedGroup(edge: Edge) throws {
    var f = Fixture()
    try f.workspace.setName("Notes", of: f.leafB)
    f.workspace.moveCamera(to: f.leafB)
    f.workspace.dock(d, at: .cameraEdge(edge))
    #expect(Set(try #require(f.workspace.windows(named: "Notes"))) == [b, d])
    #expect(f.workspace.camera == f.workspace.node(named: "Notes"))
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test(arguments: Edge.allCases) func theSameGoesForEverythingAndForTheDesktop(edge: Edge) throws {
    var f = Fixture()
    try f.workspace.setName("All", of: f.workspace.tree.root)
    f.workspace.dock(d, at: .cameraEdge(edge))
    #expect(f.workspace.node(named: "All") == f.workspace.tree.root)
    #expect(f.workspace.camera == f.workspace.tree.root)

    var g = Fixture()
    try g.workspace.setName("Scratch", of: g.workspace.tree.desktop)
    g.workspace.moveCamera(to: g.workspace.tree.desktop)
    g.workspace.dock(d, at: .cameraEdge(edge))
    let scratch = try #require(g.workspace.node(named: "Scratch"))
    #expect(g.workspace.tree.windows(under: scratch) == [d] && g.workspace.tree.subtree(scratch, contains: g.workspace.tree.desktop))
    #expect(g.workspace.camera == scratch)
    #expect(g.workspace.tree.invariantViolations() == [])
  }

  @Test func withoutANameDockingAtTheEdgeOfTheViewIsAsItWas() throws {
    var named = Fixture()
    var plain = Fixture()
    try named.workspace.setName("Elsewhere", of: named.leafA)
    for edge in Edge.allCases {
      let window = WindowID(10 + UInt32(Edge.allCases.firstIndex(of: edge)!))
      named.workspace.moveCamera(to: named.column)
      plain.workspace.moveCamera(to: plain.column)
      named.workspace.dock(window, at: .cameraEdge(edge))
      plain.workspace.dock(window, at: .cameraEdge(edge))
      #expect(named.workspace.tree == plain.workspace.tree && named.workspace.camera == plain.workspace.camera, "\(edge)")
    }
  }

  @Test func turningANamedPairRoundKeepsItsName() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.moveCamera(to: f.column)
    f.workspace.dock(b, at: .cameraEdge(.left))
    #expect(f.workspace.windows(named: "Writing") == [b, c], "side by side now")
    #expect(f.workspace.camera == f.workspace.node(named: "Writing"))
    #expect(f.workspace.tree.windows(under: f.workspace.tree.root) == [a, b, c])
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func dockedBesideTheWholeSpaceFromOutsideItStaysOutside() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.dock(d, at: .beside(f.column, .right))
    #expect(f.workspace.windows(named: "Writing") == [b, c])
    f.workspace.dock(WindowID(9), at: .beside(f.column, .top))
    #expect(f.workspace.windows(named: "Writing") == [WindowID(9), b, c], "along its own axis it joins, as any group's edge does")
  }

  @Test func theOnlyWindowOfANamedGroupTakesTheNameAlong() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    f.workspace.forget(b)
    f.workspace.dock(c, at: .beside(f.leafA, .left))
    #expect(f.workspace.windows(named: "Writing") == [c])
    #expect(!f.workspace.tree.contains(f.column))
    #expect(f.workspace.tree.kept(for: .name) == [])
    #expect(f.workspace.tree.invariantViolations() == [])
  }

  @Test func ofTwoNamesOneWindowCarriesTheFirstInListOrderStays() throws {
    var f = Fixture()
    try f.workspace.setName("Zebra", of: f.column)
    try f.workspace.setName("Alpha", of: f.leafC)
    f.workspace.forget(b)
    f.workspace.dock(c, at: .beside(f.leafA, .left))
    #expect(f.workspace.names == ["Alpha": f.workspace.tree.leaf(containing: c)!], "one place, one name")
  }

  // MARK: Anything at all

  /// Over random sessions: the two rules hold, every name is on a node that exists, exactly the named groups
  /// are kept for a name, a name never comes to mean windows that did not join it, it lives as long as
  /// one of its windows is docked, and names and tree come back from a file the same.
  @Test(arguments: Array<UInt64>(1...30)) func namesStayTrue(seed: UInt64) throws {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    var next: UInt32 = 1
    let pool = ["Alpha", "beta", "Gamma Ray", "ALPHA", "δ", "Beta"]
    for step in 0..<400 {
      let tree = workspace.tree
      let node = tree.preorder().randomElement(using: &random)!
      let edge = Edge.allCases.randomElement(using: &random)!
      let docked = tree.allWindows
      let before = workspace.names.mapValues { Set(tree.windows(under: $0)) }
      let hadDesktop = workspace.names.filter { tree.subtree($0.value, contains: tree.desktop) }.keys
      var arrived: WindowID?
      var left: WindowID?
      var renamed = false

      switch Int.random(in: 0..<16, using: &random) {
      case 0...3:
        guard docked.count < 20 else { continue }
        arrived = WindowID(next)
        next += 1
        let targets: [DropTarget] = [.beside(node, edge), .cameraEdge(edge), .stack(node)]
        workspace.dock(arrived!, at: targets.randomElement(using: &random)!)
      case 4, 5:
        guard let window = docked.randomElement(using: &random) else { continue }
        (arrived, left) = (window, window)
        let targets: [DropTarget] = [.beside(node, edge), .cameraEdge(edge), .stack(node)]
        workspace.dock(window, at: targets.randomElement(using: &random)!)
      case 6...8:
        guard let window = docked.randomElement(using: &random) else { continue }
        left = window
        if Bool.random(using: &random) { workspace.forget(window) } else { workspace.undock(window, floatingAt: CGRect(x: 0, y: 0, width: 9, height: 9)) }
      case 9, 10: workspace.moveCamera(to: node)
      case 11: workspace.saveView(slot: Int.random(in: 1...3, using: &random))
      case 12...14:
        try workspace.setName(pool.randomElement(using: &random)!, of: Bool.random(using: &random) ? node : workspace.camera)
        renamed = true
      default:
        workspace.removeName(of: workspace.names.values.sorted().randomElement(using: &random) ?? node)
        renamed = true
      }

      let after = workspace.tree
      let context: Comment = "seed \(seed), step \(step)"
      #expect(after.invariantViolations() == [], context)
      #expect(Set(workspace.names.keys.map(SpaceName.key)).count == workspace.names.count, context)
      #expect(Set(workspace.names.values).count == workspace.names.count, context)
      #expect(workspace.names.values.allSatisfy(after.contains), context)
      #expect(Set(after.kept(for: .name)) == Set(workspace.names.values.filter(after.isSplit)), context)
      #expect(after.contains(workspace.camera), context)
      guard !renamed else { continue }

      for (name, windows) in before {
        let remaining = windows.subtracting([left].compactMap { $0 })
        guard let now = workspace.names[name] else {
          // Gone with its last window, or its only window joined a space that has a name of its own.
          #expect(remaining.isEmpty && !hadDesktop.contains(name), "\(context): \(name) went with \(remaining.sorted()) in it")
          continue
        }
        let holds = Set(after.windows(under: now))
        // A name follows its only window, also into another window's place as a tab: the tab group has it then.
        if windows == [arrived], after.isStack(now) { continue }
        #expect(holds.isSuperset(of: remaining.subtracting([arrived].compactMap { $0 })), "\(context): \(name) lost windows")
        #expect(holds.subtracting(windows).isSubset(of: Set([arrived].compactMap { $0 })), "\(context): \(name) came to mean more")
      }
      if step % 25 == 0 {
        let decoder = JSONDecoder()
        let notes = DecodingNotes()
        decoder.userInfo[DecodingNotes.key] = notes
        let again = try decoder.decode(Workspace.self, from: JSONEncoder().encode(workspace))
        #expect(again.names == workspace.names && again.tree == workspace.tree && again.camera == workspace.camera, context)
        #expect(!notes.notes.contains { $0.contains("name") }, context)
      }
    }
  }

  // MARK: state.json

  private func roundTrip(_ workspace: Workspace) throws -> Workspace {
    try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
  }

  private func decode(_ workspace: Workspace, names: String?) throws -> (Workspace, [String]) {
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any])
    object["names"] = try names.map { try JSONSerialization.jsonObject(with: Data($0.utf8), options: [.fragmentsAllowed]) }
    let decoder = JSONDecoder()
    let notes = DecodingNotes()
    decoder.userInfo[DecodingNotes.key] = notes
    return (try decoder.decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object)), notes.notes)
  }

  @Test func namesAreSaved() throws {
    var f = Fixture()
    try f.workspace.setName("Writing Desk", of: f.column)
    try f.workspace.setName("Büro 📝", of: f.leafA)
    #expect(try roundTrip(f.workspace) == f.workspace)
  }

  @Test func aFileFromBeforeNamesLoads() throws {
    let f = Fixture()
    let (workspace, notes) = try decode(f.workspace, names: nil)
    #expect(workspace == f.workspace)
    #expect(notes == [])
  }

  @Test func nonsenseInAFileCostsOnlyItself() throws {
    let f = Fixture()
    let (column, leaf) = (f.column.rawValue, f.leafA.rawValue)
    let (workspace, notes) = try decode(
      f.workspace,
      names: """
        {"Writing": \(column), "Gone": 999, "left": \(leaf), " untidy": \(leaf), "bad\\u001b[0m": \(leaf), "Wrong": "x", "": \(leaf)}
        """)
    #expect(workspace.names == ["Writing": f.column])
    #expect(notes.count == 6)
    #expect(!notes.contains { $0.contains("\u{1B}") || $0.contains("untidy") }, "a refused text stays out of the log")
    #expect(!notes.contains { $0.contains("Writing") || $0.contains("Gone") || $0.contains("Wrong") }, "and so does every name")
  }

  @Test func aFileCannotBreakTheTwoRules() throws {
    let f = Fixture()
    let (column, leaf) = (f.column.rawValue, f.leafA.rawValue)
    let (alike, alikeNotes) = try decode(f.workspace, names: #"{"Writing": \#(column), "WRITING": \#(leaf)}"#)
    #expect(alikeNotes == ["the name of \(f.column) is also that of another space"])
    #expect(alike.names == ["WRITING": f.leafA], "the first in list order, whatever the order in the file")
    let (twice, twiceNotes) = try decode(f.workspace, names: #"{"Alpha": \#(column), "Beta": \#(column)}"#)
    #expect(twiceNotes == ["\(f.column) had two names"])
    #expect(twice.names == ["Alpha": f.column])
  }

  @Test func theTableDecidesWhatIsKeptForAName() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    // The tree says kept, the table has no name: an ordinary group.
    #expect(try decode(f.workspace, names: "{}").0.tree.kept(for: .name) == [])
    // The table has a name, the tree does not say kept (a file written by hand): kept.
    let plain = Fixture()
    #expect(try decode(plain.workspace, names: #"{"Writing": \#(plain.column.rawValue)}"#).0.tree.kept(for: .name) == [plain.column])
  }

  @Test func theSameSpacesCanBeShownUnderOtherNames() throws {
    var f = Fixture()
    try f.workspace.setName("Writing", of: f.column)
    try f.workspace.setName("Reading", of: f.leafA)
    #expect(f.workspace.renamingSpaces { $0 } == f.workspace)
    let renamed = f.workspace.renamingSpaces { $0 == "Writing" ? "name-1" : "name-2" }
    #expect(renamed.names == ["name-1": f.column, "name-2": f.leafA])
    #expect(renamed.node(named: "NAME-1") == f.column && renamed.node(named: "Writing") == nil)
    // All but the names is as it was, what keeps the named group together included.
    #expect(renamed.tree == f.workspace.tree && renamed.camera == f.workspace.camera)
    #expect(try roundTrip(renamed) == renamed)
  }

  @Test(arguments: ["[]", "3", "\"x\"", "null", "{}"])
  func namesOfTheWrongKindAreNoNames(json: String) throws {
    let f = Fixture()
    #expect(try decode(f.workspace, names: json).0.names.isEmpty)
  }
}
