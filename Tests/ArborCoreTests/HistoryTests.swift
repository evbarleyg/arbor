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

    var unannounced = workspace
    unannounced.moveCamera(to: root, record: false)
    expectClean(unannounced)
    #expect(unannounced.back.isEmpty && unannounced.forward.isEmpty, "which is why an unrecorded move back is not enough")

    workspace.beginLook()
    workspace.moveCamera(to: root, record: false)
    #expect(workspace.camera == root && workspace.lookingFrom == leafA)
    #expect(workspace.back == [root] && workspace.forward == [root], "the view is only visiting")
    workspace.returnFromALook()
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
    workspace.beginLook()
    workspace.moveCamera(to: root, record: false)
    workspace.forget(b)
    workspace.returnFromALook()
    #expect(workspace.camera == leafA)
    #expect(workspace.back == [root])
    expectClean(workspace)

    // The view that was left has gone as well: everything, and no way back to everything.
    workspace.beginLook()
    workspace.moveCamera(to: root, record: false)
    workspace.forget(a)
    workspace.returnFromALook()
    #expect(workspace.camera == workspace.tree.root)
    expectClean(workspace)
  }

  @Test func aLookFromAHistoryThatLeadsElsewhereAddsNothing() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    let (leafA, leafB) = (workspace.tree.leaf(containing: a)!, workspace.tree.leaf(containing: b)!)
    workspace.moveCamera(to: leafB)
    workspace.moveCamera(to: leafA)
    let before = workspace
    #expect(before.back == [workspace.tree.root, leafB])
    workspace.beginLook()
    workspace.moveCamera(to: workspace.tree.root, record: false)
    workspace.returnFromALook()
    #expect(workspace == before)
  }

  /// [ a | Desktop | (b / c) ], with the view on c, then the group, then `last`.
  private func arranged(endingOn last: (Workspace) -> NodeID) -> Workspace {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(c, at: .beside(workspace.tree.leaf(containing: b)!, .bottom))
    let group = workspace.tree.parent(of: workspace.tree.leaf(containing: c)!)!
    workspace.moveCamera(to: workspace.tree.leaf(containing: c)!)
    workspace.moveCamera(to: group)
    workspace.moveCamera(to: last(workspace))
    return workspace
  }

  private func looking(_ workspace: Workspace, while change: (inout Workspace) -> Void) -> Workspace {
    var looked = workspace
    looked.beginLook()
    looked.moveCamera(to: looked.tree.root, record: false)
    change(&looked)
    looked.returnFromALook()
    return looked
  }

  /// Copies of the lists, kept for the length of the look, missed what live history is told.
  @Test func whatChangesDuringALookReachesHistoryAsItAlwaysDoes() {
    // c closes: the group gives way to b, and Back leads to b.
    let workspace = arranged { $0.tree.leaf(containing: a)! }
    var plain = workspace
    plain.forget(c)
    let looked = looking(workspace) { $0.forget(c) }
    #expect(looked == plain)
    #expect(plain.back.last == plain.tree.leaf(containing: b)!)
    expectClean(looked)
  }

  /// Nor is the view that was left a number to keep aside: it gives way like any other.
  @Test func theViewThatWasLeftGivesWayToItsLastMemberDuringTheLook() {
    let workspace = arranged { $0.tree.parent(of: $0.tree.leaf(containing: c)!)! }
    var plain = workspace
    plain.forget(c)
    let looked = looking(workspace) { $0.forget(c) }
    #expect(looked == plain)
    #expect(looked.camera == looked.tree.leaf(containing: b)!, "not everything")
    expectClean(looked)
  }

  @Test func theViewThatWasLeftHasGoneDuringTheLook() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.moveCamera(to: workspace.tree.leaf(containing: a)!)
    var plain = workspace
    plain.forget(a)
    let looked = looking(workspace) { $0.forget(a) }
    #expect(looked == plain)
    #expect(looked.camera == looked.tree.root, "everything, and no way back to everything")
    expectClean(looked)
  }

  /// b and c are in a group of their own, and the view was on c. A view that is there would fall back on the group's remains.
  @Test func withNothingLeftOfTheViewThatWasLeftTheLookStays() {
    let workspace = arranged { $0.tree.leaf(containing: c)! }
    let looked = looking(workspace) { $0.forget(c) }
    #expect(looked.camera == looked.tree.root && looked.lookingFrom == nil)
    expectClean(looked)
  }

  @Test func fromEverythingThereIsNothingToReturnTo() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    let before = workspace
    workspace.beginLook()
    #expect(workspace.lookingFrom == nil)
    workspace.returnFromALook()
    workspace.stayAfterALook()
    #expect(workspace == before)
  }

  /// Whoever looked is gone. The view is on everything, and Back leads to where it came from.
  @Test func aLookCanBecomeAStay() {
    var workspace = arranged { $0.tree.leaf(containing: a)! }
    let (leafA, history) = (workspace.camera, workspace.back)
    workspace.beginLook()
    workspace.moveCamera(to: workspace.tree.root, record: false)
    workspace.stayAfterALook()
    #expect(workspace.lookingFrom == nil && workspace.camera == workspace.tree.root)
    #expect(workspace.back == history + [leafA])
    expectClean(workspace)
  }

  /// A look does not outlast Arbor: what is saved meanwhile is a view of everything, and reads as one.
  @Test func aLookIsNotSaved() throws {
    var workspace = arranged { $0.tree.leaf(containing: a)! }
    workspace.moveCamera(to: workspace.tree.root)
    workspace.moveCamera(to: workspace.tree.leaf(containing: a)!)
    workspace.beginLook()
    workspace.moveCamera(to: workspace.tree.root, record: false)
    #expect(workspace.back.last == workspace.tree.root)
    let read = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
    #expect(read.lookingFrom == nil && read.camera == read.tree.root)
    expectClean(read)
  }

  /// The promise as a whole: a day on which windows close ends the same with a look and without one, as long as something is left of
  /// the view that was left. (With nothing left, a view that is there falls back on the nearest thing, and a look stays on everything.)
  @Test(arguments: 1...300) func theSameDayWithAndWithoutALook(seed: UInt64) {
    var random = SeededRandom(seed: seed)
    var workspace = Workspace()
    let windows = (1...UInt32(Int.random(in: 2...7, using: &random))).map { WindowID($0) }
    for window in windows {
      let leaves = workspace.tree.preorder().filter { if case .split = workspace.tree[$0]?.kind { false } else { true } }
      let edge = [Edge.left, .right, .top, .bottom].randomElement(using: &random)!
      workspace.dock(window, at: Bool.random(using: &random) ? .cameraEdge(edge) : .beside(leaves.randomElement(using: &random)!, edge))
    }
    for _ in 0..<Int.random(in: 0...8, using: &random) {
      switch Int.random(in: 0...5, using: &random) {
      case 0: _ = workspace.goBack()
      case 1: _ = workspace.goForward()
      default: workspace.moveCamera(to: workspace.tree.preorder().randomElement(using: &random)!)
      }
    }
    var closing = Array(windows.shuffled(using: &random).prefix(Int.random(in: 0...windows.count, using: &random)))
    let viewed = workspace.tree.windows(under: workspace.camera)
    if !viewed.isEmpty, viewed.allSatisfy(closing.contains) { closing.removeAll { $0 == viewed[0] } }
    var plain = workspace
    for window in closing { plain.forget(window) }
    let looked = looking(workspace) { for window in closing { $0.forget(window) } }
    #expect(looked == plain, "closing \(closing.map(\.rawValue)): back \(looked.back) and not \(plain.back), view \(looked.camera) and not \(plain.camera)")
    expectClean(looked)
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
