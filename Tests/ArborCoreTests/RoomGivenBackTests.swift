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

  /// `[ a | b ]`, a half each, and nothing is left over. With a column for the Desktop `[ a | b | Desktop ]`, a third each.
  private func row(desktopColumn: Bool) -> LayoutTree {
    var tree = LayoutTree()
    tree.dock(b, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    tree.dock(a, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    return tree
  }

  /// What each place in `row` has.
  private func place(_ desktopColumn: Bool) -> Double { desktopColumn ? 1 / 3 : 1 / 2 }

  @Test(arguments: [Edge.left, .right], [false, true]) func aVisitLeavesEverythingAsItWas(edge: Edge, desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    let place = place(desktopColumn)
    for visit in 1...10 {
      tree.dock(x, beside: tree.leaf(containing: a)!, edge: edge, desktopColumn: desktopColumn)
      #expect(tree.share(of: a) == place / 2 && tree.share(of: x) == place / 2 && tree.share(of: b) == place)
      tree.remove(x)
      #expect(tree.picture == before, "visit \(visit)")
    }
  }

  @Test(arguments: [false, true]) func aVisitorsVisitorUnwindsLastInFirstOut(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(y, beside: tree.leaf(containing: x)!, edge: .right, desktopColumn: desktopColumn)
    let place = place(desktopColumn)
    #expect(tree.share(of: a) == place / 2 && tree.share(of: x) == place / 4 && tree.share(of: y) == place / 4)
    tree.remove(y)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test(arguments: [false, true]) func twoVisitorsOfOneWindowUnwindLastInFirstOut(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(y, beside: tree.leaf(containing: a)!, edge: .left, desktopColumn: desktopColumn)
    tree.remove(y)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test(arguments: [false, true]) func aVisitorThatWasAGroupForAWhileStillGivesItBack(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(z, beside: tree.leaf(containing: x)!, edge: .bottom, desktopColumn: desktopColumn)
    tree.remove(z)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  /// With a column for the Desktop, which is a host like any other.
  @Test func theDesktopGetsItsRoomBackToo() {
    var tree = row(desktopColumn: true)
    let before = tree.picture
    tree.dock(x, beside: tree.desktop, edge: .left, desktopColumn: true)
    #expect(tree.share(of: x) == 1 / 6 && tree.share(of: a) == 1 / 3)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test(arguments: [false, true]) func whatJoinsARowAtItsEndTakesFromAllAndGivesBackToAll(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.root, edge: .left, desktopColumn: desktopColumn)
    let even: Double = desktopColumn ? 1 / 4 : 1 / 3
    #expect(tree.share(of: x) == even && tree.share(of: a) == even)
    tree.remove(x)
    #expect(tree.picture == before)
  }

  @Test(arguments: [false, true]) func movingTheVisitorAwayGivesTheRoomBackAsWell(desktopColumn: Bool) {
    var workspace = Workspace(tree: row(desktopColumn: desktopColumn))
    workspace.dock(x, at: .beside(workspace.tree.leaf(containing: a)!, .right), desktopColumn: desktopColumn)
    workspace.dock(x, at: .beside(workspace.tree.leaf(containing: b)!, .right), desktopColumn: desktopColumn)
    #expect(workspace.tree.share(of: a) == place(desktopColumn) && workspace.tree.share(of: b) == place(desktopColumn) / 2)
    workspace.forget(x)
    #expect(workspace.tree.picture == row(desktopColumn: desktopColumn).picture)
  }

  @Test(arguments: [false, true]) func whatHappensInAnotherRowDoesNotMatter(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(z, beside: tree.leaf(containing: b)!, edge: .bottom, desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(y, beside: tree.leaf(containing: z)!, edge: .bottom, desktopColumn: desktopColumn)
    tree.remove(x)
    tree.remove(y)
    #expect(tree.picture == before)
  }

  // MARK: Once the row has changed, T06

  /// How much wider each of the windows became, and the Desktop if it had room.
  private func growth(from before: TreePicture, to after: TreePicture) -> [Double] {
    after.shares.keys.sorted().filter { before.shares[$0]! > 0 }.map { after.shares[$0]! / before.shares[$0]! }
  }

  private func expectSharedByTheWholeRow(_ tree: LayoutTree, without window: WindowID, _ comment: Comment) {
    var after = tree
    after.remove(window)
    let growth = growth(from: tree.picture, to: after.picture)
    #expect(growth.allSatisfy { $0 > 1.01 && abs($0 - growth[0]) < 1e-9 }, "\(comment): \(growth)")
    #expect(after.desktopHasRoom == tree.desktopHasRoom, "no room opens for a Desktop that had none")
    #expect(growth.count == after.allWindows.count + (tree.desktopHasRoom ? 1 : 0))
  }

  @Test(arguments: [false, true]) func afterAnotherArrivalTheRoomGoesToTheWholeRow(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(y, beside: tree.leaf(containing: b)!, edge: .right, desktopColumn: desktopColumn)
    expectSharedByTheWholeRow(tree, without: x, "y came after x")
  }

  @Test(arguments: [false, true]) func afterADepartureTheRoomGoesToTheWholeRow(desktopColumn: Bool) {
    // Three, so that two are left: without a column for the Desktop one alone would stay as it is.
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(z, beside: tree.root, edge: .right, desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.remove(b)
    expectSharedByTheWholeRow(tree, without: x, "b left after x came")
  }

  @Test(arguments: [false, true]) func afterAResizeTheRoomGoesToTheWholeRow(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.moveBoundary(
      leading: tree.leaf(containing: x)!, trailing: tree.leaf(containing: b)!, by: 100, pointsPerWeight: 480,
      minimumPoints: 20)
    expectSharedByTheWholeRow(tree, without: x, "the sizes are somebody's choice now")
  }

  @Test(arguments: [false, true]) func afterTradingPlacesTheRoomGoesToTheWholeRow(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.swapSiblings(tree.leaf(containing: x)!, tree.leaf(containing: b)!)
    expectSharedByTheWholeRow(tree, without: x, "x is not beside a any more")
  }

  /// T06's own example: it is the newcomer that undoes its arrival, not the one it came to.
  @Test(arguments: [false, true]) func whenTheHostLeavesTheRoomGoesToTheWholeRow(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    expectSharedByTheWholeRow(tree, without: a, "a was there before x")
  }

  @Test(arguments: [false, true]) func theFirstOfTwoVisitorsToLeaveSharesItsRoom(desktopColumn: Bool) {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
    tree.dock(y, beside: tree.leaf(containing: a)!, edge: .left, desktopColumn: desktopColumn)
    expectSharedByTheWholeRow(tree, without: x, "y came after x")
  }

  // MARK: Files

  @Test(arguments: [false, true]) func itIsRememberedAcrossARestart(desktopColumn: Bool) throws {
    var tree = row(desktopColumn: desktopColumn)
    let before = tree.picture
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
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

  @Test(arguments: [false, true]) func treesSavedBeforeThisStillLoad(desktopColumn: Bool) throws {
    var tree = row(desktopColumn: desktopColumn)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right, desktopColumn: desktopColumn)
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
    var tree = row(desktopColumn: false)
    tree.dock(x, beside: tree.leaf(containing: a)!, edge: .right)
    let value = try JSONSerialization.jsonObject(with: Data(visits.utf8), options: .fragmentsAllowed)
    var read = try JSONDecoder().decode(LayoutTree.self, from: file(of: tree, visits: value))
    #expect(read.picture == tree.picture && read.invariantViolations() == [])
    for window in [x, a, b] {
      read.remove(window)
      #expect(read.invariantViolations() == [])
    }
  }

  @Test(arguments: [false, true]) func onlyTheLastFewAreRemembered(desktopColumn: Bool) throws {
    var tree = row(desktopColumn: desktopColumn)
    for id in 100..<200 { tree.dock(WindowID(UInt32(id)), beside: tree.leaf(containing: a)!, edge: .right) }
    #expect(tree.visits.count <= LayoutTree.mostVisits)
    for id in 100..<200 { tree.remove(WindowID(UInt32(id))) }
    #expect(tree.visits.isEmpty && tree.invariantViolations() == [])
  }

  // MARK: Any tree

  /// Up to four visitors, anywhere in any tree and beside each other, leaving last in, first out. Without a column for the Desktop,
  /// in any tree where nothing is left over: what is goes first, and whoever took it is no visitor. And up to where a visitor leaves one place
  /// alone beside the Desktop: that place stays as it is, which is the other rule, and the walk ends there.
  @Test(arguments: [true, false]) func visitsLeaveAnyTreeAsItWas(desktopColumn: Bool) {
    var random = SeededRandom(seed: 153)
    let visitors = (1001...1004).map { WindowID($0) }
    var walks = 0
    for seed in 0..<3000 as Range<UInt64> {
      var dice = NotationRandom(seed: seed)
      let start = LayoutNotationTreeTests.randomTree(&dice, desktopColumn: desktopColumn)
      guard desktopColumn || !start.desktopHasRoom else { continue }
      let before = start.picture
      var tree = start
      var steps: [String] = []
      let party = visitors.prefix(Int(seed % 4) + 1)
      for window in party {
        let target = tree.preorder().randomElement(using: &random)!
        let edge = Edge.allCases.randomElement(using: &random)!
        tree.dock(window, beside: target, edge: edge, desktopColumn: desktopColumn)
        steps.append("\(window) \(edge) of \(target): \(tree.picture)")
        #expect(tree.invariantViolations() == [], "seed \(seed)")
      }
      var oneWasLeftAlone = false
      for window in party.reversed() where !oneWasLeftAlone {
        let alone = tree.placeLeftAloneBesideTheDesktop(without: window)
        let asItWas = tree
        tree.remove(window)
        steps.append("without \(window): \(tree.picture)")
        #expect(tree.invariantViolations() == [], "seed \(seed)")
        guard let alone else { continue }
        oneWasLeftAlone = true
        for stays in tree.windows(under: alone) {
          #expect(abs(tree.share(of: stays) - asItWas.share(of: stays)) < 1e-9, "seed \(seed):\n\(steps.joined(separator: "\n"))")
        }
      }
      guard !oneWasLeftAlone else { continue }
      walks += 1
      #expect(tree.picture.isClose(to: before), "seed \(seed):\n\(before)\n\(steps.joined(separator: "\n"))")
    }
    #expect(walks > 1000, "the walk has to meet what it is about: \(walks)")
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
  /// Of the two places that everything consists of, the one that is left once `window` has gone, if that is how it ends and the Desktop has
  /// no room: it stays as it is.
  func placeLeftAloneBesideTheDesktop(without window: WindowID) -> NodeID? {
    guard !desktopHasRoom, var leaving = leaf(containing: window), windows(under: leaving) == [window] else { return nil }
    // Everything: the root, or the one group that is all there is to see of it.
    var top = root
    while case let seen = children(of: top).filter({ $0 != desktop }), seen.count == 1, isSplit(seen[0]) { top = seen[0] }
    // A group that holds nothing else, but perhaps the Desktop, goes with it.
    while let group = self[leaving]?.parent, group != top, children(of: group).allSatisfy({ $0 == leaving || $0 == desktop }) {
      leaving = group
    }
    guard self[leaving]?.parent == top else { return nil }
    let others = children(of: top).filter { $0 != leaving && $0 != desktop }
    return others.count == 1 ? others[0] : nil
  }

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
