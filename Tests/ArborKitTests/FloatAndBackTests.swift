import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// ⌃⌥F twice is a return: the window docks again where it was, if nothing has changed meanwhile.
@Suite @MainActor struct FloatAndBackTests {
  /// `[a | (b over c) | Desktop]`, with uneven shares. As Arbor ships, `b` took all that was left and the Desktop has no room.
  func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    let c = h.system.open(app: "Notes", pid: 13, frame: CGRect(x: 500, y: 300, width: 500, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("resize \(a.rawValue) right 80")
    h.run("resize \(b.rawValue) bottom 60")
    return (h, a, b, c)
  }

  @Test(arguments: [0, 1, 2]) func twiceIsAReturn(which: Int) {
    let (h, a, b, c) = makeHarness()
    let window = [a, b, c][which]
    let before = h.workspace
    let frames = [a, b, c].map { h.frame($0) }
    h.run("toggle-float \(window.rawValue)")
    #expect(h.workspace.isFloating(window))
    let result = h.run("toggle-float \(window.rawValue)")
    #expect(result.message == "docked \(window) where it was")
    #expect(h.workspace.tree == before.tree)
    #expect(h.workspace.camera == before.camera)
    #expect([a, b, c].map { h.frame($0) } == frames)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func framedOnItTheViewComesBackToo() {
    let (h, _, b, _) = makeHarness()
    h.run("zoom \(b.rawValue)")
    let before = h.workspace
    h.run("toggle-float \(b.rawValue)")
    #expect(h.workspace.camera != before.camera)
    h.run("toggle-float \(b.rawValue)")
    #expect(h.workspace.camera == before.camera)
    #expect(h.workspace.tree == before.tree)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aHeldViewIsNotMovedByTheWayBack() {
    // With a column for the Desktop: floated, it is shown with everything, a view that a dock at its edge leaves as it is.
    // (With no room for the Desktop it is the Desktop that is framed, and what is docked there gets a group around the two,
    // which is the view from then on.)
    let (h, _, b, _) = makeHarness(settings: .withDesktopColumn)
    h.run("zoom \(b.rawValue)")
    h.run("toggle-float \(b.rawValue)")
    let view = h.workspace.camera
    h.run("hold")
    h.run("toggle-float \(b.rawValue)")
    #expect(h.workspace.camera == view)
    #expect(h.workspace.isDocked(b), "docked at the right edge of the view, as any floating window")
  }

  @Test func inAHeldViewThatTheWayBackLeavesAloneItIsAReturn() {
    let (h, _, b, _) = makeHarness()
    let before = h.workspace
    h.run("toggle-float \(b.rawValue)")
    h.run("hold")
    #expect(h.run("toggle-float \(b.rawValue)").message == "docked \(b) where it was")
    #expect(h.workspace.tree == before.tree)
  }

  @Test func movedWhileItFloatedItStillReturnsAndFloatsThereNextTime() {
    let (h, _, b, _) = makeHarness()
    let before = h.workspace
    h.run("toggle-float \(b.rawValue)")
    let moved = CGRect(x: 900, y: 400, width: 400, height: 300)
    h.system.userMove(b, to: moved)
    h.run("toggle-float \(b.rawValue)")
    #expect(h.workspace.tree == before.tree)
    h.run("toggle-float \(b.rawValue)")
    #expect(h.frame(b)!.size == moved.size)
  }

  @Test func afterAChangeToTheArrangementItDocksAtTheRightEdge() {
    let (h, a, b, c) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.run("dock \(c.rawValue) left")
    let result = h.run("toggle-float \(b.rawValue)")
    #expect(result.message.hasPrefix("docked \(b) at the right edge"), "\(result.message)")
    #expect(h.frame(b)!.minX > h.frame(a)!.maxX)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func afterAMovedGapToo() {
    let (h, a, b, _) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.run("resize \(a.rawValue) right 40")
    #expect(h.run("toggle-float \(b.rawValue)").message.hasPrefix("docked \(b) at the right edge"))
  }

  @Test func afterTheViewMovedToo() {
    let (h, a, b, _) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.run("toggle-float \(b.rawValue)").message.hasPrefix("docked \(b) at the right edge"))
  }

  @Test func aNeighbourThatClosedMeanwhileDoesNotComeBack() {
    let (h, _, b, c) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.system.close(c)
    h.run("toggle-float \(b.rawValue)")
    #expect(!h.workspace.allWindows.contains(c))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func anotherWindowFloatedInBetweenEndsIt() {
    let (h, _, b, c) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.run("toggle-float \(c.rawValue)")
    #expect(h.run("toggle-float \(b.rawValue)").message.hasPrefix("docked \(b) at the right edge"))
  }

  @Test func aWindowThatOnlyEverFloatedDocksAtTheRightEdge() {
    let (h, _, _, _) = makeHarness()
    let f = h.system.open(app: "Calculator", pid: 14, frame: CGRect(x: 1000, y: 300, width: 300, height: 400))
    #expect(h.run("toggle-float \(f.rawValue)").message.hasPrefix("docked \(f) at the right edge"))
  }

  @Test func theThirdTimeFloatsAndTheFourthReturnsAgain() {
    let (h, _, b, _) = makeHarness()
    let before = h.workspace
    for _ in 0..<2 {
      h.run("toggle-float \(b.rawValue)")
      h.run("toggle-float \(b.rawValue)")
      #expect(h.workspace.tree == before.tree)
    }
  }

  @Test func pinnedMeanwhileItIsNoReturn() {
    let (h, _, b, _) = makeHarness()
    h.run("toggle-float \(b.rawValue)")
    h.run("pin \(b.rawValue)")
    #expect(h.run("toggle-float \(b.rawValue)").message.hasPrefix("docked \(b) at the right edge"))
    #expect(!h.workspace.isPinned(b))
  }
}
