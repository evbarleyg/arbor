import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A window is let be where it stood when Arbor started (`Controller+LetBe.swift`), its app stops answering, and somebody asks for a
/// layout. It cannot be moved now, so it goes on being let be, unless the layout they asked for has a place for it.
@Suite @MainActor struct LetBeWhileItsAppHangsTests {
  let fixtures = LaunchLetsBeTests()

  /// Found by a walk: it stayed on record as let be, which is for a window the layout hides, and would never have got its place.
  @Test func givenAPlaceItIsAWindowLikeAnyOtherAndGoesThereWhenItsAppWakes() throws {
    let (h, player, _, _, stood) = fixtures.launched()
    h.system.setUnresponsive(pid: 11, true)
    #expect(h.run("resize \(player.rawValue) right 300").ok)
    fixtures.settle(h)
    let place = try #require(h.layout?.windowFrames[player], "the fixture: there is room for it now: \(h.ascii())")
    #expect(h.controller.windowLetBe == nil)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(h.frame(player) == stood, "it does not answer")
    h.system.setUnresponsive(pid: 11, false)
    fixtures.settle(h)
    #expect(h.frame(player) == place)
    #expect(h.system.focusedWindow() == player, "the keyboard stays in it")
    expectWindowsMatchLayout(h)
  }
}
