import ArborCore
import CoreGraphics
import Testing

/// `Workspace.docking(_:backAsIn:floatedAs:)`: floating a window and docking it again ends where it began.
@Suite struct FloatAndBackModelTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let c = WindowID(3)
  let f = WindowID(4)
  let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

  /// `[a | b over c | Desktop]`, `f` floating; and the same with `b` floated out.
  func beforeAndAfter() -> (before: Workspace, after: Workspace) {
    var before = Workspace()
    for window in [a, b, c, f] { before.floating[window] = frame }
    before.dock(a, at: .cameraEdge(.left))
    before.dock(b, at: .beside(before.tree.leaf(containing: a)!, .right))
    before.dock(c, at: .beside(before.tree.leaf(containing: b)!, .bottom))
    var after = before
    after.undock(b, floatingAt: frame)
    return (before, after)
  }

  @Test func untouchedItIsAsBefore() {
    let (before, after) = beforeAndAfter()
    #expect(after.docking(b, backAsIn: before, floatedAs: after) == before)
  }

  @Test func whereFloatingWindowsAreDoesNotMatterAndIsKept() {
    let (before, after) = beforeAndAfter()
    var now = after
    let moved = frame.offsetBy(dx: 50, dy: 60)
    now.floating[b] = moved
    now.floating[f] = moved
    let back = now.docking(b, backAsIn: before, floatedAs: after)
    #expect(back?.tree == before.tree)
    #expect(back?.floating == [f: moved])
    #expect(back?.undockedFrame(of: b) == moved, "it floats next time where it floated last")
  }

  @Test func anyOtherChangeEndsIt() {
    let (before, after) = beforeAndAfter()
    var docked = after
    docked.dock(f, at: .cameraEdge(.right))
    var closed = after
    closed.forget(c)
    var opened = after
    opened.floating[WindowID(9)] = frame
    var framed = after
    framed.moveCamera(to: after.tree.leaf(containing: a)!)
    var pinned = after
    pinned.pin(b)
    for now in [docked, closed, opened, framed, pinned] {
      #expect(now.docking(b, backAsIn: before, floatedAs: after) == nil)
    }
  }

  @Test func onlyTheWindowThatWasFloatedOut() {
    let (before, after) = beforeAndAfter()
    #expect(after.docking(f, backAsIn: before, floatedAs: after) == nil, "it was not docked before")
    #expect(after.docking(a, backAsIn: before, floatedAs: after) == nil, "it does not float")
  }
}
