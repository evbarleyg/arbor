import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

/// Docking beside a window in a row takes half of that window's room and nobody else's, and what leaves a
/// row leaves its room to the whole row (T06). Put together, each window that came and went beside another
/// left it narrower, until it was a tile. So a window that leaves before anything else in the row has
/// changed leaves the row as it found it.
@Suite struct RoomGivenBackTests {
  private let a = WindowID(1), b = WindowID(2), x = WindowID(11), y = WindowID(12), z = WindowID(13)

  /// `[ a | b | Desktop ]`, a third each.
  private func row() -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(b, beside: tree.root, edge: .left)
    tree.dock(a, beside: tree.root, edge: .left)
    return tree
  }

  @Test(arguments: [Edge.left, .right]) func aVisitLeavesEverythingAsItWas(edge: Edge) {
    var tree = row()
    let before = tree.picture
    for visit in 1...10 {
      tree.dock(x, beside: tree.leaf(containing: a)!, edge: edge)
      #expect(tree.share(of: a) == 1 / 6 && tree.share(of: x) == 1 / 6 && tree.share(of: b) == 1 / 3)
      tree.remove(x)
      #expect(tree.picture == before, "visit \(visit)")
    }
  }

  @Test func aVisitorsVisitorUnwindsLastInFirstOut() {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(y, beside: tree.leaf(containing: x)!, edge: .right)
    #expect(tree.share(of: a) == 1 / 6 && tree.share(of: x) == 1 / 12 && tree.share(of: y) == 1 / 12)
    tree.remove(y)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test func twoVisitorsOfOneWindowUnwindLastInFirstOut() {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(y, beside: tree.leaf(containing: a)!, edge: .left)
    tree.remove(y)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test func aVisitorThatWasAGroupForAWhileStillGivesItBack() {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(z, beside: tree.leaf(containing: x)!, edge: .bottom)
    tree.remove(z)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test func theDesktopGetsItsRoomBackToo() {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.desktop, edge: .left)
    #expect(tree.share(of: x) == 1 / 6 && tree.share(of: a) == 1 / 3)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test func whatJoinsARowAtItsEndTakesFromAllAndGivesBackToAll() {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.root, edge: .left)
    #expect(tree.share(of: x) == 1 / 4 && tree.share(of: a) == 1 / 4)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test func movingTheVisitorAwayGivesTheRoomBackAsWell() {
    var workspace = Workspace(tree: row())
    workspace.dock(x, at: .beside(workspace.tree.leaf(containing: a)!, .right))
    workspace.dock(x, at: .beside(workspace.tree.leaf(containing: b)!, .right))
    #expect(workspace.tree.share(of: a) == 1 / 3 && workspace.tree.share(of: b) == 1 / 6)
    workspace.forget(x)
    #expect(workspace.tree.picture == row().picture)
  }

  @Test func whatHappensInAnotherRowDoesNotMatter() {
    var tree = row()
    tree.dock(z, beside: tree.leaf(containing: b)!, edge: .bottom)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(y, beside: tree.leaf(containing: z)!, edge: .bottom)
    tree.remove(x)
    tree.remove(y)
    #expect(tree.picture == before)
  }

  // MARK: Once the row has changed, T06

  /// How much wider each of `windows` and the Desktop became.
  private func growth(from before: TreePicture, to after: TreePicture) -> [Double] {
    after.shares.keys.sorted().map { after.shares[$0]! / before.shares[$0]! }
  }

  private func expectSharedByTheWholeRow(_ tree: LayoutTree, without window: WindowID, _ comment: Comment) {
    var after = tree
    after.remove(window)
    let growth = growth(from: tree.picture, to: after.picture)
    #expect(growth.allSatisfy { $0 > 1.01 && abs($0 - growth[0]) < 1e-9 }, "\(comment): \(growth)")
  }

  @Test func afterAnotherArrivalTheRoomGoesToTheWholeRow() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(y, beside: tree.leaf(containing: b)!, edge: .right)
    expectSharedByTheWholeRow(tree, without: x, "y came after x")
  }

  @Test func afterADepartureTheRoomGoesToTheWholeRow() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.remove(b)
    expectSharedByTheWholeRow(tree, without: x, "b left after x came")
  }

  @Test func afterAResizeTheRoomGoesToTheWholeRow() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.moveBoundary(
      leading: tree.leaf(containing: x)!, trailing: tree.leaf(containing: b)!, by: 100, pointsPerWeight: 480,
      minimumPoints: 20)
    expectSharedByTheWholeRow(tree, without: x, "the sizes are somebody's choice now")
  }

  @Test func afterTradingPlacesTheRoomGoesToTheWholeRow() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.swapSiblings(tree.leaf(containing: x)!, tree.leaf(containing: b)!)
    expectSharedByTheWholeRow(tree, without: x, "x is not beside a any more")
  }

  /// T06's own example: it is the newcomer that undoes its arrival, not the one it came to.
  @Test func whenTheHostLeavesTheRoomGoesToTheWholeRow() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    expectSharedByTheWholeRow(tree, without: a, "a was there before x")
  }

  @Test func theFirstOfTwoVisitorsToLeaveSharesItsRoom() {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    tree.dock(y, beside: tree.leaf(containing: a)!, edge: .left)
    expectSharedByTheWholeRow(tree, without: x, "y came after x")
  }

  // MARK: Files

  @Test func itIsRememberedAcrossARestart() throws {
    var tree = row()
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    var read = try JSONDecoder().decode(LayoutTree.self, from: JSONEncoder().encode(tree))
    #expect(read == tree)
    read.remove(x)
    #expect(read.picture == before)
  }

  private func file(of tree: LayoutTree, visits: Any?) throws -> Data {
    var file = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tree)) as! [String: Any]
    file["visits"] = visits
    return try JSONSerialization.data(withJSONObject: file)
  }

  @Test func treesSavedBeforeThisStillLoad() throws {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    let read = try JSONDecoder().decode(LayoutTree.self, from: file(of: tree, visits: nil))
    #expect(read.picture == tree.picture && read.invariantViolations() == [])
    expectSharedByTheWholeRow(read, without: x, "nothing is known about x")
  }

  /// What a file says is only ever compared with the row as it is, so nonsense matches nothing.
  @Test(arguments: [
    "7", "[7]", "[{}]", #"[{"guest":999,"host":998,"row":[999,998],"weights":[1,1]}]"#,
    #"[{"guest":3,"host":3,"row":[3],"weights":[1]}]"#, #"[{"guest":3,"host":1,"row":[],"weights":[]}]"#,
    #"[{"guest":0,"host":1,"row":[0,1],"weights":[1e300,-1]}]"#,
  ]) func nonsenseInAFileIsHarmless(visits: String) throws {
    var tree = row()
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    let value = try JSONSerialization.jsonObject(with: Data(visits.utf8), options: .fragmentsAllowed)
    var read = try JSONDecoder().decode(LayoutTree.self, from: file(of: tree, visits: value))
    #expect(read.picture == tree.picture && read.invariantViolations() == [])
    for window in [x, a, b] {
      read.remove(window)
      #expect(read.invariantViolations() == [])
    }
  }

  @Test func onlyTheLastFewAreRemembered() throws {
    var tree = row()
    for id in 100..<200 { tree.dock(WindowID(UInt32(id)), beside: tree.leaf(containing: a)!, edge: .right) }
    #expect(tree.visits.count <= LayoutTree.mostVisits)
    for id in 100..<200 { tree.remove(WindowID(UInt32(id))) }
    #expect(tree.visits.isEmpty && tree.invariantViolations() == [])
  }

  // MARK: Any tree

  /// Up to four visitors, anywhere in any tree and beside each other, leaving last in, first out.
  @Test func visitsLeaveAnyTreeAsItWas() {
    var random = SeededRandom(seed: 153)
    let visitors = (1001...1004).map { WindowID($0) }
    for seed in 0..<3000 as Range<UInt64> {
      let start = LayoutTree.random(seed: seed, windows: Int(seed % 9) + 1)
      let before = start.picture
      var tree = start
      var steps: [String] = []
      let party = visitors.prefix(Int(seed % 4) + 1)
      for window in party {
        let target = tree.preorder().randomElement(using: &random)!
        let edge = Edge.allCases.randomElement(using: &random)!
        tree.dock(window, beside: target, edge: edge)
        steps.append("\(window) \(edge) of \(target): \(tree.picture)")
        #expect(tree.invariantViolations() == [], "seed \(seed)")
      }
      for window in party.reversed() {
        tree.remove(window)
        steps.append("without \(window): \(tree.picture)")
        #expect(tree.invariantViolations() == [], "seed \(seed)")
      }
      #expect(tree.picture.isClose(to: before), "seed \(seed):\n\(before)\n\(steps.joined(separator: "\n"))")
    }
  }
}

/// What a tree looks like: its nesting, and the share of the display each window has.
struct TreePicture: Equatable, CustomStringConvertible {
  var shape: String
  var shares: [String: Double]

  var description: String { "\(shape) \(shares.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" })" }

  func isClose(to other: TreePicture) -> Bool {
    shape == other.shape && shares.keys == other.shares.keys
      && shares.allSatisfy { abs($0.value - other.shares[$0.key]!) < 1e-9 }
  }
}

extension LayoutTree {
  var picture: TreePicture {
    var shares: [String: Double] = [:]
    func walk(_ id: NodeID, share: Double) -> String {
      switch self[id]!.kind {
      case .desktop:
        shares["desktop"] = share
        return "desktop"
      case .stack(let windows, _):
        let name = windows.map(\.description).joined(separator: "+")
        shares[name] = share
        return name
      case .split(let axis, let children):
        let total = children.reduce(0) { $0 + self[$1]!.weight }
        let parts = children.map { walk($0, share: share * self[$0]!.weight / total) }
        return "(" + parts.joined(separator: axis == .horizontal ? " | " : " / ") + ")"
      }
    }
    return TreePicture(shape: walk(root, share: 1), shares: shares)
  }

  func share(of window: WindowID) -> Double {
    picture.shares.first { $0.key.split(separator: "+").contains("\(window)") }!.value
  }
}
