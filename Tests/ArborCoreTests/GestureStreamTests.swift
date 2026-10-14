import ArborCore
import CoreGraphics
import Foundation
import Testing

// F16's input half: a pinch and an ⌥-scroll, streamed to the main actor one value per burst of events.

@Suite struct GestureStreamTests {
  typealias Update = GestureUpdate
  let here = CGPoint(x: 100, y: 200)
  let there = CGPoint(x: 140, y: 260)

  func update(
    _ phase: Update.Phase, at location: CGPoint? = nil, magnification: Double = 0, pan: CGSize = .zero
  ) -> Update {
    Update(phase: phase, location: location ?? here, magnification: magnification, pan: pan)
  }

  @Test func aPinchArrivesAsBeganChangedEnded() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    #expect(stream.drain() == [update(.began)])
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.1)
    #expect(stream.drain() == [update(.changed, magnification: 0.1)])
    _ = stream.feed(.pinch, .ended, at: here)
    #expect(stream.drain() == [update(.ended)])
    #expect(!stream.isActive)
    #expect(stream.drain().isEmpty)
  }

  @Test func aBurstOfEventsIsOneUpdateWithTheirSum() {
    // The main thread is busy for a few frames: what it finds afterwards is where the fingers are
    // now, not every place they have been.
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.drain()
    for _ in 1...8 { _ = stream.feed(.pinch, .changed, at: here, magnification: 0.125) }
    _ = stream.feed(.pinch, .changed, at: there, magnification: -0.25)
    #expect(stream.drain() == [update(.changed, at: there, magnification: 0.75)])
  }

  @Test func onlyTheFirstEventOfABurstAsksForADelivery() {
    var stream = GestureStream()
    #expect(stream.feed(.pinch, .began, at: here) == true)
    #expect(stream.feed(.pinch, .changed, at: here, magnification: 0.1) == false)
    #expect(stream.feed(.pinch, .ended, at: here) == false)
    _ = stream.drain()
    #expect(stream.feed(.pinch, .began, at: here) == true, "after a delivery the next event asks again")
  }

  @Test func theBeginningIsNeverMergedAway() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here, magnification: 0.05)
    _ = stream.feed(.pinch, .changed, at: there, magnification: 0.1)
    _ = stream.feed(.pinch, .changed, at: there, magnification: 0.1)
    #expect(stream.drain() == [update(.began, magnification: 0.05), update(.changed, at: there, magnification: 0.2)])
  }

  @Test func theEndIsNeverLostAndBringsWhatWasStillWaiting() {
    // A whole pinch while the main thread was stuck.
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.3)
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.3)
    _ = stream.feed(.pinch, .ended, at: there, magnification: 0.1)
    #expect(stream.drain() == [update(.began), update(.ended, at: there, magnification: 0.7)])
  }

  @Test func aCancelledPinchEndsAsCancelledAndItsLastMovementDoesNotCount() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.3)
    _ = stream.feed(.pinch, .cancelled, at: here, magnification: 0.5)
    #expect(stream.drain() == [update(.began), update(.cancelled, magnification: 0.3)])
  }

  @Test func aScrollPans() {
    var stream = GestureStream()
    _ = stream.feed(.scroll, .began, at: here, pan: CGSize(width: 1, height: -2))
    _ = stream.feed(.scroll, .changed, at: here, pan: CGSize(width: 10, height: 5))
    _ = stream.feed(.scroll, .changed, at: here, pan: CGSize(width: -4, height: 5))
    _ = stream.feed(.scroll, .ended, at: here)
    #expect(
      stream.drain() == [
        update(.began, pan: CGSize(width: 1, height: -2)), update(.ended, pan: CGSize(width: 6, height: 10)),
      ])
  }

  @Test func aPinchAndAScrollTogetherAreOneGesture() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.scroll, .began, at: here, pan: CGSize(width: 3, height: 0))
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.2)
    #expect(stream.drain() == [update(.began), update(.changed, magnification: 0.2, pan: CGSize(width: 3, height: 0))])
    // The pinch ends first; the fingers go on panning.
    _ = stream.feed(.pinch, .ended, at: here, magnification: 0.1)
    #expect(stream.isActive)
    _ = stream.feed(.scroll, .changed, at: here, pan: CGSize(width: 0, height: 7))
    #expect(stream.drain() == [update(.changed, magnification: 0.1, pan: CGSize(width: 0, height: 7))])
    _ = stream.feed(.scroll, .ended, at: here)
    #expect(stream.drain() == [update(.ended)])
    #expect(!stream.isActive)
  }

  @Test func oneHalfCancelledDoesNotCancelTheOther() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.scroll, .began, at: here)
    _ = stream.feed(.scroll, .cancelled, at: here)
    _ = stream.feed(.pinch, .ended, at: here)
    #expect(stream.drain().map(\.phase) == [.began, .ended])
  }

  @Test func eventsOfAHalfThatNeverBeganAreIgnored() {
    var stream = GestureStream()
    #expect(stream.feed(.pinch, .changed, at: here, magnification: 0.4) == false)
    #expect(stream.feed(.scroll, .ended, at: here) == false)
    #expect(stream.drain().isEmpty)
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.scroll, .changed, at: here, pan: CGSize(width: 50, height: 50))
    #expect(stream.drain() == [update(.began)])
  }

  @Test func aBeginningWithoutTheLastEndClosesTheOldGestureFirst() {
    // The end was missed. Whoever listens must still see began and an end in pairs.
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.2)
    _ = stream.feed(.pinch, .began, at: there)
    #expect(stream.drain() == [update(.began), update(.cancelled, magnification: 0.2), update(.began, at: there)])
  }

  @Test func cancelEndsWhateverIsGoingOn() {
    // macOS switched the tap off, Arbor was paused, the setting changed, permission went away.
    var stream = GestureStream()
    #expect(stream.cancel() == false, "nothing to cancel, nothing to deliver")
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.scroll, .began, at: there)
    _ = stream.drain()
    #expect(stream.cancel() == true)
    #expect(stream.drain() == [update(.cancelled, at: there)])
    #expect(!stream.isActive)
    #expect(stream.feed(.pinch, .changed, at: here, magnification: 0.2) == false, "the gesture is over")
    #expect(stream.cancel() == false)
  }

  @Test func everyBeginningHasExactlyOneEndWhateverTheOrderOfEvents() {
    // Seeded, so a failure can be repeated.
    var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
    func next(_ bound: Int) -> Int {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((seed >> 33) % UInt64(bound))
    }
    let parts: [GestureStream.Part] = [.pinch, .scroll]
    let phases: [Update.Phase] = [.began, .changed, .changed, .changed, .ended, .cancelled]
    var stream = GestureStream()
    var delivered: [Update] = []
    for _ in 1...20_000 {
      switch next(12) {
      case 0: delivered += stream.drain()
      case 1: _ = stream.cancel()
      default: _ = stream.feed(parts[next(2)], phases[next(6)], at: here, magnification: 0.01, pan: CGSize(width: 1, height: 1))
      }
    }
    _ = stream.cancel()
    delivered += stream.drain()
    var open = false
    for update in delivered {
      switch update.phase {
      case .began:
        #expect(!open, "began twice")
        open = true
      case .changed:
        #expect(open, "changed outside a gesture")
      case .ended, .cancelled:
        #expect(open, "an end without a beginning")
        open = false
      }
    }
    #expect(!open)
    #expect(delivered.count > 1000)
  }

  @Test(arguments: [Double.nan, .infinity, -.infinity]) func numbersThatAreNotNumbersCountAsNothing(bad: Double) {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here, magnification: bad, pan: CGSize(width: bad, height: bad))
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.25)
    _ = stream.feed(.pinch, .changed, at: here, magnification: bad, pan: CGSize(width: 1, height: bad))
    #expect(stream.drain() == [update(.began), update(.changed, magnification: 0.25, pan: CGSize(width: 1, height: 0))])
  }

  @Test func aPlaceThatIsNotAPlaceKeepsTheLastOne() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.pinch, .changed, at: CGPoint(x: CGFloat.nan, y: 5), magnification: 0.1)
    #expect(stream.drain().last?.location == here)
  }

  @Test func oneEventCanOnlyMoveSoFar() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    _ = stream.feed(.scroll, .began, at: here)
    _ = stream.drain()
    _ = stream.feed(.pinch, .changed, at: here, magnification: 1e300)
    _ = stream.feed(.scroll, .changed, at: here, pan: CGSize(width: -1e300, height: 1e300))
    let limit = GestureStream.maximumPan
    #expect(
      stream.drain() == [
        update(.changed, magnification: GestureStream.maximumMagnification, pan: CGSize(width: -limit, height: limit))
      ])
  }

  @Test func gesturesNobodyCollectsDoNotPileUp() {
    // The main thread is stuck and some tool posts thousands of tiny pinches.
    var stream = GestureStream()
    for _ in 1...10_000 {
      _ = stream.feed(.pinch, .began, at: here)
      _ = stream.feed(.pinch, .changed, at: here, magnification: 0.1)
      _ = stream.feed(.pinch, .ended, at: here)
    }
    let delivered = stream.drain()
    #expect(delivered.count <= GestureStream.maximumWaiting + 2)
    // What is left is still whole gestures.
    #expect(delivered.first?.phase == .began)
    #expect(delivered.last?.phase == .ended)
    #expect(delivered.filter { $0.phase == .began }.count == delivered.filter { $0.phase == .ended }.count)
  }
}

extension GestureStreamTests {
  @Test func theEndOfAGestureTheListenerSawBeginSurvivesThePileUp() {
    var stream = GestureStream()
    _ = stream.feed(.pinch, .began, at: here)
    #expect(stream.drain().map(\.phase) == [.began])
    // Now the main thread sticks. That pinch ends, and thousands more come and go.
    _ = stream.feed(.pinch, .changed, at: here, magnification: 0.4)
    _ = stream.feed(.pinch, .ended, at: here)
    for _ in 1...10_000 {
      _ = stream.feed(.pinch, .began, at: there)
      _ = stream.feed(.pinch, .ended, at: there)
    }
    let delivered = stream.drain()
    #expect(delivered.first == update(.ended, magnification: 0.4), "the listener is owed this one")
    #expect(delivered.count <= GestureStream.maximumWaiting + 3)
    #expect(delivered.dropFirst().filter { $0.phase == .began }.count == delivered.dropFirst().filter { $0.phase == .ended }.count)
  }
}

@Suite struct ScrollClaimTests {
  typealias Verdict = ScrollClaim.Verdict

  @Test func aScrollWithOptionHeldAsItBeginsIsArborsToTheEnd() {
    var claim = ScrollClaim()
    #expect(claim.feed(.began, claim: true) == .deliver(.began))
    // Letting go of ⌥ halfway changes nothing.
    #expect(claim.feed(.changed, claim: false) == .deliver(.changed))
    #expect(claim.feed(.ended, claim: false) == .deliver(.ended))
    #expect(!claim.isClaimed)
  }

  @Test func aScrollTheAppSawBeginStaysTheApps() {
    var claim = ScrollClaim()
    #expect(claim.feed(.began, claim: false) == .pass)
    #expect(claim.feed(.changed, claim: true) == .pass, "pressing ⌥ halfway does not take it")
    #expect(claim.feed(.ended, claim: true) == .pass)
    #expect(claim.feed(.none, momentum: .began, claim: true) == .pass)
    #expect(claim.feed(.none, momentum: .ended, claim: true) == .pass)
  }

  @Test func theMomentumOfArborsScrollReachesNobody() {
    // The app never saw the scroll, so it must not coast on it; and Arbor's view settles when the
    // fingers lift, which coasting would fight.
    var claim = ScrollClaim()
    _ = claim.feed(.began, claim: true)
    _ = claim.feed(.ended, claim: true)
    #expect(claim.feed(.none, momentum: .began) == .swallow)
    #expect(claim.feed(.none, momentum: .continued) == .swallow)
    #expect(claim.feed(.none, momentum: .ended) == .swallow)
    #expect(claim.feed(.none, momentum: .continued) == .pass, "that momentum is over")
  }

  @Test func aNewTouchEndsTheMomentum() {
    var claim = ScrollClaim()
    _ = claim.feed(.began, claim: true)
    _ = claim.feed(.ended, claim: true)
    _ = claim.feed(.none, momentum: .began)
    // Fingers back on the trackpad, without ⌥: this scroll and its momentum are the app's.
    #expect(claim.feed(.mayBegin, claim: false) == .pass)
    #expect(claim.feed(.began, claim: false) == .pass)
    #expect(claim.feed(.ended, claim: false) == .pass)
    #expect(claim.feed(.none, momentum: .began) == .pass)
  }

  @Test func aCancelledScrollHasNoMomentum() {
    var claim = ScrollClaim()
    _ = claim.feed(.began, claim: true)
    #expect(claim.feed(.cancelled) == .deliver(.cancelled))
    #expect(claim.feed(.none, momentum: .began) == .pass)
  }

  @Test func aWheelMouseHasNoPhasesAndIsLeftAlone() {
    // ⌥ + wheel means something in many apps, and clicks of a wheel are not a gesture with an end.
    var claim = ScrollClaim()
    #expect(claim.feed(.none, claim: true) == .pass)
    #expect(!claim.isClaimed)
  }

  @Test func theClaimIsWorkedOutOnlyWhenAScrollBegins() {
    var claim = ScrollClaim()
    var checks = 0
    func check() -> Bool {
      checks += 1
      return true
    }
    _ = claim.feed(.mayBegin, claim: check())
    #expect(checks == 0)
    _ = claim.feed(.began, claim: check())
    _ = claim.feed(.changed, claim: check())
    _ = claim.feed(.ended, claim: check())
    _ = claim.feed(.none, momentum: .began, claim: check())
    #expect(checks == 1)
  }

  @Test func aNewScrollDecidesAgainEvenIfTheLastOneNeverEnded() {
    var claim = ScrollClaim()
    _ = claim.feed(.began, claim: true)
    #expect(claim.feed(.began, claim: false) == .pass)
    #expect(claim.feed(.changed) == .pass)
  }

  @Test func resetForgetsTheScrollAndItsMomentum() {
    var claim = ScrollClaim()
    _ = claim.feed(.began, claim: true)
    claim.reset()
    #expect(claim.feed(.changed) == .pass)
    _ = claim.feed(.began, claim: true)
    _ = claim.feed(.ended)
    claim.reset()
    #expect(claim.feed(.none, momentum: .began) == .pass)
  }

  @Test func whetherAnythingIsGoingOnIsCheapToAsk() {
    // The tap leaves at once for a scroll without ⌥ unless this says it must look closer.
    var claim = ScrollClaim()
    #expect(!claim.isBusy)
    _ = claim.feed(.began, claim: true)
    #expect(claim.isBusy)
    _ = claim.feed(.ended)
    #expect(claim.isBusy, "the momentum is still to come")
    _ = claim.feed(.none, momentum: .began)
    _ = claim.feed(.none, momentum: .ended)
    #expect(!claim.isBusy)
  }

  @Test func thePhaseNumbersAreCoreGraphics() {
    // CGScrollPhase and CGMomentumScrollPhase; the Mac-only test ScrollPhaseNumberTests compares them with the SDK's.
    #expect(ScrollClaim.Phase(scrollPhase: 0) == .none)
    #expect(ScrollClaim.Phase(scrollPhase: 1) == .began)
    #expect(ScrollClaim.Phase(scrollPhase: 2) == .changed)
    #expect(ScrollClaim.Phase(scrollPhase: 4) == .ended)
    #expect(ScrollClaim.Phase(scrollPhase: 8) == .cancelled)
    #expect(ScrollClaim.Phase(scrollPhase: 128) == .mayBegin)
    #expect(ScrollClaim.Momentum(momentumPhase: 0) == .none)
    #expect(ScrollClaim.Momentum(momentumPhase: 1) == .began)
    #expect(ScrollClaim.Momentum(momentumPhase: 2) == .continued)
    #expect(ScrollClaim.Momentum(momentumPhase: 3) == .ended)
  }

  @Test(arguments: [Int64(-1), 3, 5, 16, 64, 129, 1 << 40, .max, .min]) func aNumberNobodyKnowsIsNoPhase(number: Int64) {
    // Such an event is treated like a wheel mouse's: left to the app.
    #expect(ScrollClaim.Phase(scrollPhase: number) == .none)
    if number != 3 { #expect(ScrollClaim.Momentum(momentumPhase: number) == .none) }
  }
}

@Suite struct ContinuousZoomSettingsTests {
  @Test func oldSettingsFilesKeepTheSteps() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(!settings.continuousZoom)
  }

  @Test func theSettingDecodesAndRoundTrips() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"continuousZoom": true}"#.utf8))
    #expect(settings.continuousZoom)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }
}
