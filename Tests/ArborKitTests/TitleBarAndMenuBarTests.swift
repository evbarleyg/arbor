import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A title bar does not go under the menu bar: not in a hand, and not when a window opens. The stand-in stopped a window at the bottom, and one in a
/// hand by one of its two roads.
@Suite @MainActor struct TitleBarAndMenuBarTests {
  /// The two displays of the recordings, each visible from y 31, with a Dock below.
  static let wide = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1600, height: 900), visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791),
    isMain: true)
  static let small = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768), visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674),
    isMain: true)

  /// A recorded drag of Calendar's window into the menu bar, as far above its aim as there: the top goes 53, 38, and then stays at 31 while x goes on,
  /// down to the pointer's last wiggle of a point.
  @Test func aDraggedWindowStopsAtTheMenuBarAndGoesOnSideways() {
    let system = FakeWindowSystem(displays: [Self.wide])
    let window = system.open(app: "Calendar", frame: CGRect(x: 349, y: 205, width: 910, height: 603))
    system.beginDrag(window)
    // The stand-in takes hold in the middle of the title bar, ten points down: (804,215).
    var seen: [CGPoint] = []
    for (x, y) in [(894, 63), (902, 48), (911, 34), (920, 20), (924, 13), (928, 5), (933, 0), (934, 0), (933, 0)] as [(CGFloat, CGFloat)] {
      system.moveDrag(to: CGPoint(x: x, y: y))
      seen.append(system.frame(of: window)!.origin)
    }
    #expect(
      seen == [(439, 53), (447, 38), (456, 31), (465, 31), (469, 31), (473, 31), (478, 31), (479, 31), (478, 31)].map { CGPoint(x: $0.0, y: $0.1) })
  }

  /// A recorded throw, in its own numbers: a test window taken in the middle of its title bar, at x 503, and thrown to (512,0) with ⌘ held, let go within
  /// a twentieth of a second. macOS, with its tiling as it comes, left it where it was let go: under the menu bar, nine points further
  /// right. That is where Arbor has it, and it sets no frame.
  @Test func thrownAtTheMenuBarItRestsBelowIt() {
    let h = Harness(displays: [Self.small])
    let window = h.system.open(app: "Test", frame: CGRect(x: 262, y: 279, width: 482, height: 350))
    h.start()
    h.system.clearFrameLog()
    h.system.holdModifierKeys(.command)
    h.system.beginDrag(window)
    h.system.moveDrag(to: CGPoint(x: 512, y: 0))
    h.system.endDrag()
    h.system.holdModifierKeys([])
    h.scheduler.advance(by: 3)
    #expect(h.frame(window) == CGRect(x: 271, y: 31, width: 482, height: 350))
    #expect(h.workspace.floating[window] == CGRect(x: 271, y: 31, width: 482, height: 350))
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// One that lies under the menu bar already slides along it, as TextEdit's window did in 26 steps: y 31 in all, while x went on.
  @Test func aWindowThatLiesUnderTheMenuBarSlidesAlongIt() {
    let system = FakeWindowSystem(displays: [Self.wide])
    let window = system.open(app: "TextEdit", frame: CGRect(x: 800, y: 31, width: 800, height: 790))
    system.beginDrag(window)
    for step in 1...26 {
      system.moveDrag(to: CGPoint(x: 1200 - CGFloat(step) * 15, y: max(41 - CGFloat(step) * 2, 0)))
      #expect(system.frame(of: window)?.origin == CGPoint(x: 800 - CGFloat(step) * 15, y: 31))
    }
  }

  /// Nobody has recorded a window that lies higher being taken. The stand-in's choice: the press moves nothing, of which Arbor would hear nothing, and the
  /// pointer's first movement, which is reported, brings the window below the menu bar, as in the other stand-ins.
  @Test func takingAWindowThatLiesHigherMovesNothing() {
    let system = FakeWindowSystem(displays: [Self.wide])
    let window = system.open(app: "Notes", frame: CGRect(x: 300, y: 12, width: 400, height: 300))
    system.beginDrag(window)
    #expect(system.frame(of: window)?.origin == CGPoint(x: 300, y: 12))
    system.moveDrag(to: CGPoint(x: 520, y: 22))
    #expect(system.frame(of: window)?.origin == CGPoint(x: 320, y: 31))
  }

  /// The road on which the release is lost had arithmetic of its own, and no stop.
  @Test func soItIsWhenTheReleaseIsLost() {
    let system = FakeWindowSystem(displays: [Self.wide])
    let window = system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    system.dragAndLoseTheRelease(window, to: CGPoint(x: 520, y: 3))
    #expect(system.frame(of: window)?.origin == CGPoint(x: 320, y: 31))
  }

  static let above = DisplaySnapshot(
    id: DisplayID("above"), frame: CGRect(x: 0, y: -800, width: 1280, height: 800), visibleFrame: CGRect(x: 0, y: -769, width: 1280, height: 769),
    isMain: false)

  /// All that is on record of a display above is that two drags arrived there. So the way up is open; how a window passes the menu bar
  /// between the two is the stand-in's guess, and is not held to anything here.
  @Test func withADisplayAboveTheWayUpIsOpen() {
    let system = FakeWindowSystem(displays: [Self.wide, Self.above])
    let window = system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    system.beginDrag(window)
    system.moveDrag(to: CGPoint(x: 500, y: -300))
    #expect(system.frame(of: window)?.origin == CGPoint(x: 300, y: -310))
  }

  /// Nobody has recorded these either. The stand-in's choice: wherever the window was taken, the menu bar of the display the pointer is on stops it, and
  /// with the pointer on no display that of the nearest.
  @Test func whereverItWasTakenTheMenuBarUnderThePointerStopsIt() {
    let system = FakeWindowSystem(displays: [Self.wide, Self.above])
    let window = system.open(app: "Notes", frame: CGRect(x: 300, y: -500, width: 400, height: 300))
    system.beginDrag(window)
    system.moveDrag(to: CGPoint(x: 500, y: 5))
    #expect(system.frame(of: window)?.origin == CGPoint(x: 300, y: 31))
    system.moveDrag(to: CGPoint(x: 1700, y: 5))
    #expect(system.frame(of: window)?.origin == CGPoint(x: 1500, y: 31))
  }

  /// The sixth window of the test app, which asks for (420,20) on a display 768 points high, opened at the top of the visible frame with its x and
  /// its size. By every road a window opens by.
  @Test func aNewWindowOpensBelowTheMenuBar() {
    let system = FakeWindowSystem(displays: [Self.small])
    system.start()
    let asked = CGRect(x: 420, y: 20, width: 480, height: 348), opened = CGRect(x: 420, y: 31, width: 480, height: 348)
    #expect(system.frame(of: system.open(app: "Test", frame: asked)) == opened)
    system.open(id: WindowID(900), app: "Test", bundleID: nil, title: "", pid: 1000, frame: asked)
    #expect(system.frame(of: WindowID(900)) == opened)
    let elsewhere = system.openUnlisted(app: "Test", frame: asked)
    #expect(system.unlisted[elsewhere]?.snapshot.frame == opened)
    let lower = system.open(app: "Test", frame: asked.offsetBy(dx: 0, dy: 12))
    #expect(system.frame(of: lower) == asked.offsetBy(dx: 0, dy: 12))
  }

  /// Before the start a window is not opened but simply there, as after a restart or in full screen: it lies where the caller says. And the silent
  /// stand-in does nothing that a test did not ask for.
  @Test func aWindowThatIsSimplyThereLiesWhereItIsSaidTo() {
    let asked = CGRect(x: 0, y: 0, width: 1024, height: 768)
    let system = FakeWindowSystem(displays: [Self.small])
    #expect(system.frame(of: system.open(app: "Test", frame: asked)) == asked)
    system.start()
    system.echoes = .none
    #expect(system.frame(of: system.open(app: "Test", frame: asked)) == asked)
  }
}
