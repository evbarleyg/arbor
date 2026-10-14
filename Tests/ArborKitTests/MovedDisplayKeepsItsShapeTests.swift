import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Where "a display whose corner moved takes its frames along" (K1811) meets "a frame chosen on a display of another shape is
/// not left hanging" (floating, round 3). A display that only moved has kept its shape.
@MainActor @Suite struct MovedDisplayKeepsItsShapeTests {
  private static func display(_ id: String, x: CGFloat, width: CGFloat, height: CGFloat, main: Bool) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID(id), frame: CGRect(x: x, y: 0, width: width, height: height),
      visibleFrame: CGRect(x: x, y: 25, width: width, height: height - 25), isMain: main)
  }

  @Test func aStripLeftOnPurposeIsStillAStripWhenItsDisplayOnlyMoved() {
    let laptop = Self.display("laptop", x: 0, width: 1440, height: 900, main: true)
    let big = Self.display("big", x: 1440, width: 2560, height: 1440, main: false)
    let h = Harness(displays: [laptop, big])
    let safari = h.system.open(app: "Safari", pid: 31, frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 32, frame: CGRect(x: 2000, y: 500, width: 700, height: 500))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("dock \(safari.rawValue) left").ok)
    // Pushed aside by hand: sixty points of it show at the far edge of the big display.
    h.system.userMove(notes, to: CGRect(x: 3940, y: 500, width: 700, height: 500))
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)?.minX == 3940)

    // The lid closes. macOS takes the windows along, says that the displays changed, and reports the windows late.
    h.system.moveSilently(notes, to: CGRect(x: 2500, y: 500, width: 700, height: 500))
    h.system.moveSilently(safari, to: h.frame(safari)!.offsetBy(dx: -1440, dy: 0))
    h.system.setDisplays([Self.display("big", x: 0, width: 2560, height: 1440, main: true)])
    h.system.report(notes, userInitiated: false)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)?.minX == 2500)

    #expect(h.run("zoom \(safari.rawValue)").ok)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(notes))
    for command in ["back", "home", "relayout"] {
      #expect(h.run(command).ok)
      h.scheduler.advance(by: 2)
      #expect(h.frame(notes)?.minX == 2500, "after \(command): still a strip, at the shifted place, not fitted onto the Desktop")
    }
  }
}
