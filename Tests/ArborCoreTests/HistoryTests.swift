import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)

/// T34. History is a list of places: the same place twice in a row is one press of Back that does nothing to
/// see, and the decoder, which drops such repeats, logged a repair at every launch.
@Suite struct HistoryTests {
  private func expectClean(
    _ workspace: Workspace, _ comment: Comment? = nil, at location: SourceLocation = #_sourceLocation
  ) {
    for (name, list) in [("back", workspace.back), ("forward", workspace.forward)] {
      let repeats = zip(list, list.dropFirst()).contains { $0 == $1 }
      #expect(!repeats, "\(name) repeats itself: \(list)", sourceLocation: location)
      #expect(list.count <= Workspace.historyLimit, sourceLocation: location)
    }
    #expect(
      workspace.back.last != workspace.camera, "Back would go to where the view is: \(workspace.back)",
      sourceLocation: location)
    #expect(workspace.forward.last != workspace.camera, sourceLocation: location)
  }

  /// F51. A peek looks at everything without recording it, and everything is where Back most often leads.
  @Test func aLookAtThePlaceBackLeadsToCanBeUndone() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let root = workspace.tree.root
    let leafA = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leafA)
    workspace.moveCamera(to: root)
    let went = workspace.goBack()
    #expect(went)
    let before = workspace
    #expect(before.back == [root] && before.forward == [root] && before.camera == leafA)

    workspace.moveCamera(to: root, record: false)
    expectClean(workspace)
    #expect(workspace.back.isEmpty && workspace.forward.isEmpty, "which is why an unrecorded move back is not enough")
    workspace.returnFromALook(to: before.camera, back: before.back, forward: before.forward)
    #expect(workspace == before)
  }

  @Test func whatHasGoneDuringALookIsLeftOut() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(c, at: .cameraEdge(.right))
    let root = workspace.tree.root
    let (leafA, leafB) = (workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: b)!)
    workspace.moveCamera(to: leafB)
    workspace.moveCamera(to: leafA)
    let before = workspace
    #expect(before.back == [root, leafB])
    workspace.moveCamera(to: root, record: false)
    workspace.forget(b)
    workspace.returnFromALook(to: before.camera, back: before.back, forward: before.forward)
    #expect(workspace.camera == leafA)
    #expect(workspace.back == [root])
    expectClean(workspace)

    // The view that was left has gone as well: everything, and no way back to everything.
    workspace.moveCamera(to: root, record: false)
    workspace.forget(a)
    workspace.returnFromALook(to: leafA, back: [root], forward: [])
    #expect(workspace.camera == workspace.tree.root)
    expectClean(workspace)
  }

  /// Found by B11's random test. A dock outside the view widens the view onto the node that history
  /// ends with; the next move of the view then listed that node again.
  @Test func aViewThatWidensOntoTheLastPlaceInHistoryDoesNotListItTwice() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let root = workspace.tree.root
    let leafA = workspace.tree.leaf(containing: a)!
    workspace.moveCamera(to: leafA)
    #expect(workspace.back == [root])
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: b)!, .bottom))
    #expect(workspace.camera == root, "widened to show c")
    expectClean(workspace)
    workspace.moveCamera(to: leafA)
    expectClean(workspace)
    #expect(workspace.back == [root])
  }

  @Test(arguments: Array<UInt64>(1...40)) func historyStaysCleanAndReadsBackEqual(seed: UInt64) throws {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    var next: UInt32 = 1
    for step in 0..<300 {
      let node = workspace.tree.preorder().randomElement(using: &random)!
      let edge = Edge.allCases.randomElement(using: &random)!
      let docked = workspace.tree.allWindows
      switch Int.random(in: 0..<14, using: &random) {
      case 0, 1:
        guard docked.count < 16 else { continue }
        let targets: [DropTarget] = [.beside(node, edge), .cameraEdge(edge), .stack(node)]
        workspace.dock(WindowID(next), at: targets.randomElement(using: &random)!)
        next += 1
      case 2: if let window = docked.randomElement(using: &random) { workspace.dock(window, at: .beside(node, edge)) }
      case 3: if let window = docked.randomElement(using: &random) { workspace.dock(window, at: .stack(node)) }
      case 4, 5: if let window = docked.randomElement(using: &random) { workspace.forget(window) }
      case 6...9: workspace.moveCamera(to: node)
      case 10, 11: _ = workspace.goBack()
      case 12: _ = workspace.goForward()
      default: workspace.saveView(slot: Int.random(in: 1...3, using: &random))
      }
      expectClean(workspace, "seed \(seed), step \(step)")
      let decoder = JSONDecoder()
      let notes = DecodingNotes()
      decoder.userInfo[DecodingNotes.key] = notes
      let again = try decoder.decode(Workspace.self, from: JSONEncoder().encode(workspace))
      #expect(again == workspace && notes.notes == [], "seed \(seed), step \(step): \(notes.notes)")
    }
  }

  @Test func backAndForwardStillWalkTheSamePlaces() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let root = workspace.tree.root
    let (leafA, leafB) = (workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: b)!)
    for node in [leafA, leafB, root, leafA] { workspace.moveCamera(to: node) }
    var seen: [NodeID] = []
    while workspace.goBack() { seen.append(workspace.camera) }
    #expect(seen == [root, leafB, leafA, root])
    seen = []
    while workspace.goForward() { seen.append(workspace.camera) }
    #expect(seen == [leafA, leafB, root, leafA])
  }
}
