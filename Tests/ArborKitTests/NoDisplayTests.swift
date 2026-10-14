import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Every display gone (a monitor switched off, a KVM, a lid), with windows out of view at that moment. More of
/// what `OutOfViewTests` begins: pausing, excluding, minimized windows, commands, a second display.
@MainActor @Suite struct NoDisplayTests {
  private static let main = FakeWindowSystem.standardDisplay
  /// Not a display Arbor has seen before, and not where the old one was.
  private static let other = DisplaySnapshot(
    id: DisplayID("other"), frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)

  /// `[ a | b | Desktop ]` with `f` floating, and the view on `a`: `b` and `f` are out of view.
  private func zoomedIn() -> (h: Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness()
    let (a, b) = (h.system.open(app: "A"), h.system.open(app: "B"))
    let f = h.system.open(app: "F", frame: CGRect(x: 900, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b) && !h.system.isVisible(f))
    return (h, a, b, f)
  }

  /// Every window is somebody's, and one that is out of view is so because its workspace says so.
  private func expectNothingIsLost(
    _ h: Harness, _ comment: Comment, at location: SourceLocation = #_sourceLocation
  ) {
    for snapshot in h.system.allWindows() {
      let window = snapshot.id
      let home = h.controller.workspaceID(containing: window)
      #expect(home != nil, "\(window) is in no workspace: \(comment)", sourceLocation: location)
      guard let home, !h.system.isVisible(window), snapshot.isPresent else { continue }
      let workspace = h.controller.workspaces[home]!, layout = h.controller.layouts[home]
      let hidden = workspace.isDocked(window) ? layout?.windowFrames[window] == nil : layout?.desktopFrame == nil
      #expect(
        hidden, "\(window) is out of view at \(snapshot.frame) for no reason: \(comment)", sourceLocation: location)
    }
  }

  @Test func theSameDisplayComesBack() {
    let (h, a, _, _) = zoomedIn()
    let before = h.workspace
    h.system.setDisplays([])
    h.system.setDisplays([Self.main])
    #expect(h.workspace == before && h.system.isVisible(a))
    expectNothingIsLost(h, "back on the same display")
    h.run("home")
    for window in h.system.allWindows() { #expect(h.system.isVisible(window.id), "\(window.id)") }
  }

  @Test(arguments: [true, false]) func aWindowMinimizedOutOfViewComesBackInView(sameDisplay: Bool) {
    let (h, _, b, f) = zoomedIn()
    h.system.setMinimized(b, true)
    h.system.setMinimized(f, true)
    h.system.setDisplays([])
    h.system.setDisplays([sameDisplay ? Self.main : Self.other])
    h.run("home")
    h.system.setMinimized(b, false)
    h.system.setMinimized(f, false)
    expectNothingIsLost(h, "restored from the Dock")
    #expect(h.system.isVisible(b) && h.system.isVisible(f), "\(h.frame(b)!) \(h.frame(f)!)")
  }

  @Test func aWindowThatClosesInTheDarkIsForgotten() {
    let (h, _, b, _) = zoomedIn()
    h.system.setDisplays([])
    h.system.close(b)
    h.system.setDisplays([Self.main])
    expectNothingIsLost(h, "closed with no display")
    #expect(!h.workspace.contains(b) && h.workspace.tree.invariantViolations() == [])
  }

  /// Nothing can be in view with no display. What matters is where the windows are when there is one
  /// again and Arbor is not there to put them right.
  @Test(arguments: [true, false]) func quittingInTheDarkLeavesNothingInTheCorner(sameDisplay: Bool) {
    let (h, _, _, _) = zoomedIn()
    h.system.setDisplays([])
    h.controller.shutdown()
    h.system.setDisplays([sameDisplay ? Self.main : Self.other])
    for window in h.system.allWindows() { #expect(h.system.isVisible(window.id), "\(window.id) at \(window.frame)") }
  }

  /// A docked window has the size of its slot. What it was before it was docked is remembered (F48), with the arrangement of
  /// the display that went.
  @Test func aDockedWindowLetGoOfInTheDarkHasItsOwnSizeAndPlaceAgain() {
    let h = Harness()
    let a = h.system.open(app: "A")
    let own = CGRect(x: 420, y: 260, width: 500, height: 350)
    let b = h.system.open(app: "B", frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b) && h.frame(b)!.size != own.size, "out of view, in the shape of its slot")
    h.system.setDisplays([])
    h.controller.shutdown()
    #expect(h.frame(b) == own, "it used to slide in from the corner as tall and narrow as its slot")
  }

  @Test func soHasOneThatFindsAnotherDisplayWhenTheLightComesBack() {
    let h = Harness()
    let a = h.system.open(app: "A")
    let own = CGRect(x: 420, y: 260, width: 500, height: 350)
    let b = h.system.open(app: "B", frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.setDisplays([])
    h.system.setDisplays([Self.other])
    #expect(h.controller.workspaces[Self.other.id]?.isFloating(b) == true)
    #expect(h.frame(b) == own, "it used to go to the middle, in the shape of its slot")
  }

  @Test func pausingInTheDarkLeavesNothingInTheCorner() {
    let (h, _, _, _) = zoomedIn()
    h.system.setDisplays([])
    h.run("pause")
    h.system.setDisplays([Self.main])
    for window in h.system.allWindows() { #expect(h.system.isVisible(window.id), "\(window.id) at \(window.frame)") }
  }

  @Test func aPauseInTheDarkLeavesWhatWasInViewAloneAndResumingBringsTheArrangementBack() {
    let (h, a, _, _) = zoomedIn()
    let (before, slot) = (h.workspace, h.frame(a)!)
    h.system.setDisplays([])
    let moves = h.system.frameLog.count
    h.run("pause")
    #expect(h.frame(a) == slot)
    #expect(!h.system.frameLog.dropFirst(moves).contains { $0.window == a }, "it was in view, and is not touched")
    h.system.setDisplays([Self.main])
    h.run("resume")
    #expect(h.workspace.tree == before.tree && h.workspace.camera == before.camera)
    expectNothingIsLost(h, "resumed")
  }

  /// Out of view on a second display is a long way from where the main one was. What was in view there is
  /// not Arbor's to move: macOS brings the windows of a display that is gone to one that is there.
  @Test func whatWasOutOfViewOnASecondDisplayComesToWhereTheMainOneWas() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [Self.main, side])
    let a = h.system.open(app: "A", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 1700, y: 150, width: 500, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    h.system.setDisplays([])
    h.controller.shutdown()
    h.system.setDisplays([Self.main])
    #expect(h.system.isVisible(b), "\(h.frame(b)!)")
  }

  @Test func commandsInTheDarkDoNoHarm() {
    let (h, a, b, f) = zoomedIn()
    h.system.setDisplays([])
    for command in [
      "home", "out", "in", "back", "float-all", "arrange", "dock \(f.rawValue) left", "float \(b.rawValue)",
      "zoom \(b.rawValue)", "dock \(b.rawValue) beside \(a.rawValue) left", "save-view 1", "view 1", "state",
    ] {
      h.run(command)
    }
    h.system.userFocus(b)
    h.system.setDisplays([Self.main])
    expectNothingIsLost(h, "after commands with no display")
  }

  @Test func anAppExcludedInTheDarkGetsItsWindowBack() {
    let (h, _, b, _) = zoomedIn()
    h.system.setDisplays([])
    let app = h.system.allWindows().first { $0.id == b }!.bundleID!
    #expect(h.run("exclude \(app)").ok)
    #expect(!h.controller.parked.contains(b))
    h.system.setDisplays([Self.main])
    #expect(h.system.isVisible(b), "\(h.frame(b)!)")
  }
}
