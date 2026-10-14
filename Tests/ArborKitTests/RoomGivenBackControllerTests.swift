import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@MainActor @Suite struct RoomGivenBackControllerTests {
  /// `[ a | b | Desktop ]` on the standard display: one more beside `a` and both are tiles.
  private func pair() -> (h: Harness, a: WindowID, b: WindowID) {
    let h = Harness()
    let (a, b) = (h.system.open(app: "A"), h.system.open(app: "B"))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    return (h, a, b)
  }

  @Test func aWindowThatOpensBesideAnotherAndClosesLeavesItAsWideAsItWas() {
    let (h, a, b) = pair()
    let before = [h.frame(a), h.frame(b), h.layout!.desktopFrame]
    #expect(!before.contains(nil))
    for visit in 1...5 {
      let visitor = h.system.open(app: "Visitor")
      h.run("dock \(visitor.rawValue) beside \(a.rawValue) right")
      h.system.close(visitor)
      #expect([h.frame(a), h.frame(b), h.layout!.desktopFrame] == before, "visit \(visit)")
      #expect(h.layout!.tiles.isEmpty)
    }
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func soDoesOneThatIsFloatedOrDraggedOutAgain() {
    let (h, a, b) = pair()
    let before = [h.frame(a), h.frame(b), h.layout!.desktopFrame]
    let visitor = h.system.open(app: "Visitor")
    h.run("dock \(visitor.rawValue) beside \(b.rawValue) left")
    h.run("float \(visitor.rawValue)")
    #expect([h.frame(a), h.frame(b), h.layout!.desktopFrame] == before)
  }

  @Test func itHoldsAcrossARestart() {
    let (h, a, b) = pair()
    let before = [h.frame(a), h.frame(b), h.layout!.desktopFrame]
    let visitor = h.system.open(app: "Visitor")
    h.run("dock \(visitor.rawValue) beside \(a.rawValue) right")
    h.controller.saveNow()

    let again = Harness(saved: h.store.saved)
    for app in ["A", "B", "Visitor"] { again.system.open(app: app) }
    again.start()
    #expect(again.workspace.tree == h.workspace.tree)
    again.system.close(visitor)
    #expect([again.frame(a), again.frame(b), again.layout!.desktopFrame] == before)
  }
}
