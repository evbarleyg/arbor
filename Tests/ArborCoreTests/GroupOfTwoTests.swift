import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

private let keynote = WindowID(1)
private let slack = WindowID(2)
private let mail = WindowID(3)
private let notes = WindowID(4)

/// F62, for the smallest group there is. Moving a window takes it out and puts it in again, and in between a
/// group of two is a group of one, which gives way to its child. So rearranging a pair that is framed or saved
/// used to end the pair: the window landed in the row outside, and the view widened to all of it.
@Suite struct GroupOfTwoTests {
  /// `[ keynote | Desktop | (slack | mail) ]` with the view on the pair.
  private func framedPair() -> (workspace: Workspace, pair: NodeID) {
    var workspace = Workspace()
    workspace.dock(keynote, at: .cameraEdge(.left))
    workspace.dock(slack, at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.leaf(containing: slack)!)
    workspace.dock(mail, at: .cameraEdge(.right))
    #expect(workspace.tree.windows(under: workspace.camera) == [slack, mail])
    #expect(workspace.tree.children(of: workspace.tree.root).count == 3)
    return (workspace, workspace.camera)
  }

  private func leaf(_ window: WindowID, _ workspace: Workspace) -> NodeID { workspace.tree.leaf(containing: window)! }

  private func expectSound(_ workspace: Workspace, at location: SourceLocation = #_sourceLocation) {
    #expect(workspace.tree.invariantViolations() == [], sourceLocation: location)
    #expect(workspace.tree.kept(for: .move) == [], "a move is over when it is over", sourceLocation: location)
  }

  @Test func tradingPlacesInAFramedPairKeepsThePairAndTheView() {
    var (workspace, pair) = framedPair()
    workspace.dock(slack, at: .beside(leaf(mail, workspace), .right))
    #expect(workspace.camera == pair)
    #expect(workspace.tree.windows(under: workspace.camera) == [mail, slack], "the view used to widen to everything")
    #expect(workspace.tree.children(of: workspace.tree.root).count == 3, "slack used to land in the row outside")
    expectSound(workspace)
  }

  @Test(arguments: Edge.allCases) func anyEdgeOfTheOtherOneKeepsExactlyTheTwoInView(edge: Edge) {
    var (workspace, _) = framedPair()
    workspace.dock(slack, at: .beside(leaf(mail, workspace), edge))
    #expect(Set(workspace.tree.windows(under: workspace.camera)) == [mail, slack])
    #expect(workspace.tree.children(of: workspace.tree.root).count == 3)
    expectSound(workspace)
  }

  @Test(arguments: Edge.allCases) func soDoesAnyEdgeOfTheView(edge: Edge) {
    var (workspace, _) = framedPair()
    workspace.dock(slack, at: .cameraEdge(edge))
    #expect(Set(workspace.tree.windows(under: workspace.camera)) == [mail, slack])
    expectSound(workspace)
  }

  @Test(arguments: Edge.allCases) func aSavedViewOfAPairStillShowsThePair(edge: Edge) {
    var (workspace, _) = framedPair()
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: workspace.tree.root)
    workspace.dock(slack, at: .beside(leaf(mail, workspace), edge))
    let saved = workspace.tree.windows(under: workspace.savedView(slot: 1)!)
    #expect(Set(saved) == [mail, slack], "it used to show mail alone")
    #expect(workspace.camera == workspace.tree.root)
    expectSound(workspace)
  }

  @Test func asATabOfTheOtherOneTheViewShowsTheTabGroup() {
    var (workspace, _) = framedPair()
    workspace.dock(slack, at: .stack(leaf(mail, workspace)))
    #expect(workspace.tree.windows(under: workspace.camera) == [mail, slack])
    #expect(workspace.camera == leaf(mail, workspace))
    expectSound(workspace)
  }

  /// As the spec has it: a view on a group that shrinks to one window shows that window.
  @Test func aWindowThatMovesOutOfThePairLeavesTheViewOnTheOther() {
    var (workspace, _) = framedPair()
    workspace.saveView(slot: 1)
    workspace.moveCamera(to: workspace.tree.root)
    workspace.dock(slack, at: .beside(leaf(keynote, workspace), .left))
    #expect(workspace.tree.windows(under: workspace.savedView(slot: 1)!) == [mail])
    #expect(workspace.tree.children(of: workspace.tree.root).count == 4, "the row is flat again")
    expectSound(workspace)
  }

  @Test func aNewcomerBesideAMemberJoinsThePair() {
    var (workspace, pair) = framedPair()
    workspace.dock(notes, at: .beside(leaf(mail, workspace), .right))
    #expect(workspace.camera == pair && workspace.tree.windows(under: pair) == [slack, mail, notes])
    expectSound(workspace)
  }

  @Test func aRefusedMoveLeavesNoMark() {
    var (workspace, _) = framedPair()
    let before = workspace
    #expect(workspace.tryDock(slack, at: .float) == .notADock && workspace == before)
    expectSound(workspace)
  }

  // MARK: The mark is never seen

  @Test func noMoveIsEverSaved() throws {
    var (workspace, _) = framedPair()
    workspace.dock(slack, at: .beside(leaf(mail, workspace), .right))
    let read = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
    #expect(read == workspace)
  }

  /// Nothing would ever take it off again, and the group would outlive its windows' leaving.
  @Test func aMoveInAFileIsNotBelieved() throws {
    var (workspace, pair) = framedPair()
    workspace.tree.keep(pair, for: .move)
    let notes = DecodingNotes()
    let decoder = JSONDecoder()
    decoder.userInfo[DecodingNotes.key] = notes
    let read = try decoder.decode(LayoutTree.self, from: JSONEncoder().encode(workspace.tree))
    #expect(read.kept(for: .move) == [] && read.isKept(pair), "the view's mark stays")
    #expect(notes.notes.contains { $0.contains("\(pair)") }, "\(notes.notes)")
  }

  @Test(arguments: Array<UInt64>(1...40)) func noSessionLeavesAMoveBehind(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    var next: UInt32 = 1
    for _ in 0..<150 {
      let node = workspace.tree.preorder().randomElement(using: &random)!
      let edge = Edge.allCases.randomElement(using: &random)!
      let targets: [DropTarget] = [.beside(node, edge), .cameraEdge(edge), .stack(node)]
      switch Int.random(in: 0..<6, using: &random) {
      case 0:
        workspace.dock(WindowID(next), at: targets.randomElement(using: &random)!)
        next += 1
      case 1, 2:
        guard let window = workspace.tree.allWindows.randomElement(using: &random) else { continue }
        workspace.dock(window, at: targets.randomElement(using: &random)!)
      case 3: workspace.moveCamera(to: node)
      case 4: workspace.saveView(slot: Int.random(in: 1...3, using: &random))
      default:
        guard let window = workspace.tree.allWindows.randomElement(using: &random) else { continue }
        workspace.forget(window)
      }
      expectSound(workspace)
    }
  }
}
