import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// A laptop and a monitor, as a person uses them.
@Suite @MainActor struct TwoDisplayTests {
  /// Main: `[a | Desktop]`. Side: `[Desktop | b]` with `f` floating on it.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 1500, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, f)
  }

  func workspace(_ h: Harness, _ display: DisplaySnapshot) -> Workspace { h.controller.workspaces[display.id]! }

  @Test func aFloatingWindowEvacuatedWhileParkedKeepsItsSizeAndIsNotPiledInACorner() {
    let (h, _, b, f) = makeHarness()
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(f))
    h.system.setDisplays([main])
    #expect(h.system.isVisible(f))
    #expect(h.frame(f)!.size == CGSize(width: 320, height: 300))
    // It was 60 points in from the left and 300 down from the top of what its own display shows.
    #expect(h.controller.workspaces[main.id]!.floating[f] == CGRect(x: 60, y: 325, width: 320, height: 300))
  }

  /// macOS itself brings the windows of a display that went onto one that is left, those in the Dock too.
  func unplugSide(_ h: Harness, macOSMoves window: WindowID) {
    h.system.setDisplays([main])
    h.system.userMove(window, to: CGRect(origin: CGPoint(x: 200, y: 300), size: h.frame(window)!.size))
  }

  /// It was in the Dock when its display went, so it was never put in a corner, whatever Arbor noted about it.
  @Test func aWindowMinimizedWhileItsDisplayWentIsNotTakenForOneOutOfView() {
    let (h, a, _, f) = makeHarness()
    h.system.setMinimized(f, true)
    unplugSide(h, macOSMoves: f)
    h.run("dock \(f.rawValue) right")
    h.run("zoom \(a.rawValue)")
    // Something other than the user brings it back, so the view stays on Safari.
    h.system.echoes.keyboard = false
    h.system.setMinimized(f, false)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(!h.system.isVisible(f), "\(h.frame(f)!) lies over the framed window")
    h.run("show-all")
    expectWindowsMatchLayout(h, on: main.id)
  }

  @Test func theSameWindowStillFloatingWaitsOutOfViewForTheDesktop() {
    let (h, a, _, f) = makeHarness()
    h.system.setMinimized(f, true)
    unplugSide(h, macOSMoves: f)
    h.run("zoom \(a.rawValue)")
    h.system.echoes.keyboard = false
    h.system.setMinimized(f, false)
    #expect(!h.system.isVisible(f), "\(h.frame(f)!) lies over the framed window")
    h.run("show-all")
    #expect(h.layout!.desktopFrame!.contains(h.frame(f)!), "\(h.ascii())")
  }

  @Test func theLidClosesAndOpens() {
    let (h, a, b, f) = makeHarness()
    let before = (h.frame(a)!, h.frame(b)!, h.frame(f)!)
    var alone = side
    alone.isMain = true
    alone.frame.origin = .zero
    alone.visibleFrame = CGRect(x: 0, y: 25, width: 1280, height: 775)
    h.system.setDisplays([alone])
    #expect(h.system.isVisible(a) && h.system.isVisible(b) && h.system.isVisible(f))
    #expect(workspace(h, side).isDocked(b))
    #expect(workspace(h, side).isFloating(a))
    expectWindowsMatchLayout(h, on: side.id)
    h.system.setDisplays([main, side])
    #expect(h.frame(a) == before.0)
    #expect(h.frame(b) == before.1)
    #expect(h.frame(f) == before.2)
  }

  @Test func draggingADockedWindowToTheOtherDisplayJoinsItsArrangement() {
    let (h, a, b, _) = makeHarness()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [h.frame(a)!.center, CGPoint(x: 1445, y: 400)])
    #expect(workspace(h, side).isDocked(a))
    #expect(!workspace(h, main).contains(a))
    #expect(h.frame(a)!.maxX < h.frame(b)!.minX)
    expectWindowsMatchLayout(h, on: side.id)
    #expect(workspace(h, main).tree.allWindows.isEmpty)
  }

  @Test func aFloatingWindowMovedToADisplayThatIsZoomedInStaysInViewUntilItsCameraMoves() {
    let (h, a, _, f) = makeHarness()
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("zoom \(a.rawValue)")
    h.system.userMove(f, to: CGRect(x: 500, y: 300, width: 320, height: 300))
    #expect(workspace(h, main).isFloating(f))
    #expect(!workspace(h, side).contains(f))
    #expect(h.system.isVisible(f))
    h.run("back")
    #expect(h.system.isVisible(f))
    #expect(h.controller.layouts[main.id]!.desktopFrame!.contains(h.frame(f)!))
  }

  @Test func cameraCommandsThatFailSayWhichDisplayTheyMeant() {
    let (h, _, b, _) = makeHarness()
    // The keyboard is on the side display, the pointer rests on the main one.
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.system.userFocus(b)
    h.run("zoom")
    #expect(workspace(h, side).camera == workspace(h, side).tree.leaf(containing: b))
    let result = h.run("back")
    #expect(!result.ok)
    #expect(result.message.contains("pointer"), "\(result.message)")
  }
}
