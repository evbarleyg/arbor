import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The part of "the key that fills the screen fills it with a floating window too" that lives in the core (`Workspace.filled`).
@Suite struct FillModelTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let own = CGRect(x: 10, y: 20, width: 300, height: 200)
  let view = CGRect(x: 12, y: 37, width: 1416, height: 851)
  /// Where an app that will not grow that far has stopped.
  let short = CGRect(x: 320, y: 162, width: 800, height: 600)

  func workspace() -> Workspace {
    var workspace = Workspace()
    workspace.floating[a] = own
    workspace.floating[b] = own
    return workspace
  }

  @Test func onlyAFloatingWindowFillsTheView() {
    var workspace = workspace()
    let filled = workspace.fill(a, at: view)
    #expect(filled)
    #expect(workspace.isFilled(a) && !workspace.isFilled(b))
    #expect(workspace.filledWindows == [a])
    let unknown = workspace.fill(WindowID(9), at: view)
    workspace.dock(b, at: .cameraEdge(.left))
    let docked = workspace.fill(b, at: view)
    #expect(!unknown && !docked)
    #expect(workspace.filledWindows == [a])
  }

  @Test func itsOwnFrameIsKeptAndWhereTheFillLeftItIsWrittenDown() {
    var workspace = workspace()
    workspace.fill(a, at: view)
    #expect(workspace.floating[a] == own, "the fill's size never becomes the window's")
    // Its app stopped short of the view.
    let again = workspace.fill(a, at: short)
    #expect(again && workspace.filled == [a: short] && workspace.floating[a] == own)
    let ended = workspace.endFill(of: a)
    let twice = workspace.endFill(of: a)
    #expect(ended && !twice)
  }

  @Test func howeverAWindowStopsFloatingItsFillGoes() {
    for stop in ["dock", "forget", "remove", "summon"] {
      var workspace = workspace()
      workspace.fill(a, at: view)
      workspace.fill(b, at: view)
      switch stop {
      case "dock": workspace.dock(a, at: .cameraEdge(.right))
      case "forget": workspace.forget(a)
      case "summon": workspace.summon(a, app: "A", at: own)
      default: workspace.floating[a] = nil
      }
      #expect(workspace.filledWindows == [b], "\(stop)")
      // Floating again is not filling again.
      workspace.undock(a, floatingAt: own)
      #expect(!workspace.isFilled(a), "\(stop)")
    }
  }

  @Test func dockedItRemembersItsOwnFrameAndNotTheViews() {
    var workspace = workspace()
    workspace.fill(a, at: view)
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.undockedFrame(of: a) == own)
  }

  @Test func aWindowThatComesAndGoesWithSummonDoesNotFill() {
    var workspace = workspace()
    workspace.summon(a, app: "A", at: own)
    let summoned = workspace.fill(a, at: view)
    workspace.dismissSummon()
    let stashed = workspace.fill(a, at: view)
    #expect(!summoned && !stashed)
  }

  /// A display comes back, and the window it had filled has been sent away on another one meanwhile.
  @Test func givenTheRoleOfOneThatComesAndGoesItNoLongerFills() {
    for role in [FloatingRole.stashed, .summoned(app: "Notes")] {
      var workspace = workspace()
      workspace.fill(a, at: view)
      workspace.setRole(role, of: a)
      #expect(!workspace.isFilled(a) && workspace.filled == nil, "\(role)")
      #expect(workspace.floating[a] == own, "\(role)")
    }
  }

  @Test func aPinnedWindowFillsAndStaysPinned() {
    var workspace = workspace()
    workspace.pin(a)
    let filled = workspace.fill(a, at: view)
    #expect(filled && workspace.isPinned(a) && workspace.isFilled(a))
    workspace.endFill(of: a)
    #expect(workspace.isPinned(a))
  }

  @Test func fillingAndGoingBackLeavesTheWorkspaceAsItWas() {
    let before = workspace()
    var workspace = before
    workspace.endFill(of: a)
    #expect(workspace == before)
    workspace.fill(a, at: view)
    #expect(workspace != before)
    workspace.endFill(of: a)
    #expect(workspace == before)
    #expect(workspace.filled == nil)
  }

  @Test func aFillIsAChangeOfTheArrangement() {
    let before = workspace()
    var after = before
    after.fill(a, at: view)
    #expect(!before.hasSameArrangement(as: after), "or Undo would not take it back")
    var other = before
    other.fill(a, at: short)
    #expect(after.hasSameArrangement(as: other), "how far it got is no arrangement")
  }

  @Test func theDisplayMovesAndBothFramesMoveWithIt() {
    var workspace = workspace()
    workspace.fill(a, at: view)
    workspace.shift(by: CGPoint(x: 100, y: -50))
    #expect(workspace.filled?[a] == view.offsetBy(dx: 100, dy: -50))
    #expect(workspace.floating[a] == own.offsetBy(dx: 100, dy: -50))
  }

  @Test func theSameWindowUnderAnotherNumberStillFills() {
    var workspace = workspace()
    workspace.fill(a, at: view)
    workspace.renumber(a, as: WindowID(7))
    #expect(workspace.filled == [WindowID(7): view])
  }

  @Test func fillsAreSavedAndOneOfAWindowThatDoesNotFloatIsNotBelieved() throws {
    var workspace = workspace()
    workspace.fill(a, at: view)
    let data = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: data) == workspace)

    // A file written before fills existed.
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["filled"] = nil
    let old = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.filled == nil && old.floating == workspace.floating)

    // A file edited by hand: 9 is nowhere in the workspace, and no window was ever a million points wide.
    let saved = try #require((JSONSerialization.jsonObject(with: data) as? [String: Any])?["filled"] as? [String: Any])
    for (number, frame) in [("9", try #require(saved["1"])), ("2", [[0, 0], [9_000_000, 10]])] {
      object["filled"] = saved.merging([number: frame]) { $1 }
      let edited = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(edited.filledWindows == [a], "\(number)")
    }
    object["filled"] = "nonsense"
    let damaged = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(damaged.filled == nil && damaged.floating == workspace.floating)
  }

  // MARK: Undo

  @Test func undoTakesAFillBackAndRedoBringsItBack() {
    let before = workspace()
    var after = before
    after.fill(a, at: view)
    #expect(before.restored(over: after, since: after) == before)
    #expect(after.restored(over: before, since: before) == after)
  }

  @Test func aFillBegunSinceTheStepStaysAndOneEndedSinceStaysEnded() {
    // The step docked b.
    var before = workspace()
    before.fill(a, at: view)
    var after = before
    after.dock(b, at: .cameraEdge(.left))
    // Since then the fill of a has ended: by the key, or by a hand.
    var current = after
    current.endFill(of: a)
    #expect(!before.restored(over: current, since: after).isFilled(a))

    // The other way round: a was filled after the step.
    var plain = workspace()
    var docked = plain
    docked.dock(b, at: .cameraEdge(.left))
    var filledSince = docked
    filledSince.fill(a, at: view)
    #expect(plain.restored(over: filledSince, since: docked).filled == [a: view])
    plain.fill(b, at: view)
    #expect(plain.restored(over: filledSince, since: docked).filledWindows == [a, b], "b floats again, and filled the view then")
  }
}
