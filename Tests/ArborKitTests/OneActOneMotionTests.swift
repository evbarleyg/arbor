import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What a person sees of an act ends when the motion was going to end, however long the apps took to answer. On a hosted
/// Mac nine windows took 0.65 s to answer a dock; the correction that followed started the 0.46 s again: 1.3 s in all.
@Suite @MainActor struct OneActOneMotionTests {
  /// [a | Desktop] and c, which takes the place it is given but never more than 300 points of the width: every dock of it
  /// has to be corrected. Each app takes `answer` seconds over a move, and as on a Mac no timer runs meanwhile.
  private func desk(answer: TimeInterval, settings: Settings = Settings()) -> (h: Harness, c: WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.system.setMaximumSize(c, CGSize(width: 300, height: 2000))
    h.overlays.clearTransitions()
    let clock = Clock()
    h.controller.now = { clock.now }
    h.system.willSetFrame = { _, _ in clock.now += answer }
    return (h, c)
  }

  private final class Clock: @unchecked Sendable {
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
  }

  @Test func aCorrectionGetsWhatIsLeftOfTheMotion() throws {
    let (h, c) = desk(answer: 0.05)
    h.run("dock \(c.rawValue) right")
    try #require(h.overlays.transitions.count == 2, "the plan, and what the app allowed")
    #expect(h.overlays.transitions[0].duration == 0.46)
    let left = h.overlays.transitions[1].duration
    #expect(left < 0.46 && left >= Transition.shortestCorrection, "\(left) s")
  }

  @Test func afterSlowAppsItIsShort() throws {
    let (h, c) = desk(answer: 0.3)
    h.run("dock \(c.rawValue) right")
    try #require(h.overlays.transitions.count == 2)
    #expect(h.overlays.transitions[1].duration == Transition.shortestCorrection)
  }

  @Test func appsThatAnswerAtOnceChangeNothing() throws {
    let (h, c) = desk(answer: 0)
    h.run("dock \(c.rawValue) right")
    try #require(h.overlays.transitions.count == 2)
    #expect(h.overlays.transitions[1].duration == 0.46)
  }

  /// The next act is a motion of its own.
  @Test func theNextActHasItsWholeTime() throws {
    let (h, c) = desk(answer: 0.3)
    h.run("dock \(c.rawValue) right")
    h.overlays.clearTransitions()
    h.run("zoom \(c.rawValue)")
    #expect(h.overlays.transitions.first?.duration == 0.46)
  }
}
