import ArborCore
import CoreGraphics
import Foundation
import Testing

/// K061. A file may nest `LayoutTree.maximumDepth` levels, because repairing and laying out recurse once per
/// level. A live arrangement could go deeper: it did not come back after a restart, and far beyond that
/// a layout would overflow the stack. (On the main actor for its stack, like Arbor itself.)
@MainActor @Suite struct NestingLimitTests {
  /// Every window docked inside the one before, until `levels` is how deep the last two are.
  private func chain(levels: Int) -> (workspace: Workspace, last: NodeID, next: UInt32) {
    var workspace = Workspace()
    workspace.dock(WindowID(1), at: .cameraEdge(.left))
    var last = workspace.tree.leaf(containing: WindowID(1))!
    var id: UInt32 = 2
    while workspace.tree.depth(of: last) < levels {
      workspace.dock(WindowID(id), at: .beside(last, id % 2 == 0 ? .bottom : .right))
      last = workspace.tree.leaf(containing: WindowID(id))!
      id += 1
    }
    return (workspace, last, id)
  }

  @Test func theDeepestArrangementThereCanBeComesBackFromAFile() throws {
    let (workspace, last, _) = chain(levels: 100)
    #expect(workspace.tree.depth(of: last) == 100 && workspace.tree.nesting == 100)
    #expect(workspace.tree.invariantViolations() == [])
    #expect(try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace)) == workspace)
  }

  @Test func aDockThatWouldNestDeeperIsRefusedAndChangesNothing() {
    var (workspace, last, next) = chain(levels: 100)
    let before = workspace
    // The last pair's split runs one way: across it means one more level.
    guard case .split(let axis, _) = workspace.tree[workspace.tree.parent(of: last)!]?.kind else { return }
    let across: Edge = axis == .horizontal ? .bottom : .right
    #expect(workspace.tryDock(WindowID(next), at: .beside(last, across)) == .tooDeep)
    #expect(workspace == before)
    let docked = workspace.dock(WindowID(next), at: .beside(last, across))
    #expect(!docked && workspace == before)
    let preview = workspace.previewFrame(
      for: WindowID(next), at: .beside(last, across), in: CGRect(x: 0, y: 0, width: 1440, height: 900),
      options: .init(), isPresent: { _ in true })
    #expect(preview == nil)
    // Along it the window joins the pair, no deeper.
    #expect(workspace.tryDock(WindowID(next), at: .beside(last, axis == .horizontal ? .right : .bottom)) == .docked)
    #expect(workspace.tree.nesting == 100 && workspace.tree.invariantViolations() == [])
  }

  @Test func wrappingEverythingCountsToo() {
    var (workspace, _, next) = chain(levels: 100)
    let before = workspace
    workspace.moveCamera(to: workspace.tree.root)
    let outcome = workspace.tryDock(WindowID(next), at: .cameraEdge(.top))
    #expect(outcome == .tooDeep, "the root is a row: above it means a level around it")
    #expect(workspace.tree == before.tree)
    #expect(workspace.tryDock(WindowID(next), at: .cameraEdge(.left)) == .docked)
  }

  @Test func aWindowAlreadyDockedThatCannotGoThereStaysWhereItIs() {
    var (workspace, last, _) = chain(levels: 100)
    guard case .split(let axis, _) = workspace.tree[workspace.tree.parent(of: last)!]?.kind else { return }
    let before = workspace
    let outcome = workspace.tryDock(WindowID(1), at: .beside(last, axis == .horizontal ? .bottom : .right))
    #expect(outcome != .tooDeep, "taking 1 out makes room")
    workspace = before
    // One that leaves no level behind when it goes: a tab beside the first window.
    workspace.dock(WindowID(900), at: .stack(workspace.tree.leaf(containing: WindowID(1))!))
    let tabbed = workspace
    #expect(workspace.tryDock(WindowID(900), at: .beside(last, axis == .horizontal ? .bottom : .right)) == .tooDeep)
    #expect(workspace == tabbed && workspace.isDocked(WindowID(900)))
  }

  @Test func theOtherAnswersSayWhy() {
    var workspace = Workspace()
    let (floated, dropped) = (workspace.tryDock(WindowID(1), at: .float), workspace.tryDock(WindowID(1), at: .none))
    #expect(floated == .notADock && dropped == .notADock)
    #expect(workspace.tryDock(WindowID(1), at: .cameraEdge(.left)) == .docked)
    workspace.moveCamera(to: workspace.tree.leaf(containing: WindowID(1))!)
    #expect(workspace.tryDock(WindowID(1), at: .cameraEdge(.left)) == .nothingToDockBeside)
  }
}
