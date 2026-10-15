import ArborCore
import Testing

/// One act is one motion: a correction gets what is left of the motion it corrects.
@Suite struct TransitionTimeLeftTests {
  @Test func aCorrectionEndsWhenTheMotionWasGoingTo() {
    #expect(Transition.timeLeft(of: 0.46, after: 0) == 0.46)
    #expect(abs(Transition.timeLeft(of: 0.46, after: 0.1) - 0.36) < 1e-9)
  }

  @Test func aLateOneIsShortButStillAMove() {
    #expect(Transition.timeLeft(of: 0.46, after: 0.4) == Transition.shortestCorrection)
    #expect(Transition.timeLeft(of: 0.46, after: 0.65) == Transition.shortestCorrection)
    #expect(Transition.timeLeft(of: 0.46, after: 3600) == Transition.shortestCorrection)
  }

  @Test func itIsNeverLongerThanTheMotionItself() {
    #expect(Transition.timeLeft(of: 0.1, after: 0.05) == 0.1)
    #expect(Transition.timeLeft(of: 0.1, after: 5) == 0.1)
    #expect(Transition.timeLeft(of: 0, after: 1) == 0)
    #expect(Transition.timeLeft(of: -1, after: 1) == 0)
  }

  @Test func aClockThatMakesNoSenseChangesNothing() {
    #expect(Transition.timeLeft(of: 0.46, after: -5) == 0.46, "set back meanwhile")
    #expect(Transition.timeLeft(of: 0.46, after: .nan) == 0.46)
    #expect(Transition.timeLeft(of: 0.46, after: .infinity) == 0.46)
  }
}
