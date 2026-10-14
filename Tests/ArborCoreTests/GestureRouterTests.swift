import ArborCore
import CoreGraphics
import Testing

// What the gesture taps ask for every event: whose it is, and what follows from it.

@Suite struct GestureRouterTests {
  let here = CGPoint(x: 100, y: 200)

  func continuous() -> GestureRouter {
    var router = GestureRouter()
    _ = router.setContinuous(true)
    return router
  }

  @Test func withoutContinuousZoomAPinchStepsAsItAlwaysDid() {
    var router = GestureRouter()
    #expect(router.pinch(.began, magnification: 0, at: here, claim: true) == .init(swallow: true))
    #expect(router.pinch(.changed, magnification: 0.3, at: here) == .init(swallow: true, commands: [.stepIn]))
    #expect(router.pinch(.ended, magnification: 0, at: here) == .init(swallow: true))
    #expect(router.drain().isEmpty)
  }

  @Test func withoutContinuousZoomScrollsAreNobodysBusiness() {
    var router = GestureRouter()
    #expect(!router.scrollNeedsALook(keys: .arbors))
    #expect(router.scroll(.began, pan: CGSize(width: 1, height: 1), at: here, keys: .arbors) == .init(swallow: false))
    #expect(router.drain().isEmpty)
  }

  @Test func withContinuousZoomAPinchIsStreamedInsteadOfStepping() {
    var router = continuous()
    #expect(router.pinch(.began, magnification: 0, at: here, claim: true) == .init(swallow: true, needsVisit: true))
    #expect(router.pinch(.changed, magnification: 0.6, at: here) == .init(swallow: true))
    #expect(router.pinch(.ended, magnification: 0, at: here) == .init(swallow: true))
    #expect(
      router.drain() == [
        GestureUpdate(phase: .began, location: here), GestureUpdate(phase: .ended, location: here, magnification: 0.6),
      ])
  }

  @Test func aPinchThatIsTheAppsIsNeitherSwallowedNorStreamed() {
    var router = continuous()
    #expect(router.pinch(.began, magnification: 0, at: here, claim: false) == .init(swallow: false))
    #expect(router.pinch(.changed, magnification: 0.6, at: here) == .init(swallow: false))
    #expect(router.drain().isEmpty)
  }

  @Test func aScrollWithTheKeysPans() {
    var router = continuous()
    #expect(router.scrollNeedsALook(keys: .arbors))
    let began = router.scroll(.began, pan: .zero, at: here, keys: .arbors)
    #expect(began == .init(swallow: true, needsVisit: true))
    #expect(router.scroll(.changed, pan: CGSize(width: 4, height: -3), at: here, keys: .none).swallow)
    #expect(router.scroll(.ended, pan: .zero, at: here, keys: .none).swallow)
    #expect(router.drain().last == GestureUpdate(phase: .ended, location: here, pan: CGSize(width: 4, height: -3)))
    // Its momentum reaches neither the app nor the listener.
    #expect(router.scrollNeedsALook(keys: .none))
    #expect(router.scroll(.none, momentum: .began, pan: CGSize(width: 9, height: 9), at: here, keys: .none) == .init(swallow: true))
    #expect(router.scroll(.none, momentum: .ended, pan: .zero, at: here, keys: .none) == .init(swallow: true))
    #expect(router.drain().isEmpty)
    #expect(!router.scrollNeedsALook(keys: .none))
  }

  @Test func aPlainScrollIsNotEvenLookedAt() {
    let router = continuous()
    #expect(!router.scrollNeedsALook(keys: .none))
  }

  @Test func aScrollThatBeginsDuringArborsPinchIsArborsWithoutTheKeys() {
    // A pinch on the wallpaper needs no ⌥, and the fingers that pinch also move.
    var router = continuous()
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(router.scrollNeedsALook(keys: .none))
    #expect(router.scroll(.began, pan: CGSize(width: 2, height: 0), at: here, keys: .none).swallow)
    _ = router.pinch(.ended, magnification: 0, at: here)
    #expect(router.scroll(.ended, pan: .zero, at: here, keys: .none).swallow)
    #expect(router.drain().map(\.phase) == [.began, .ended])
  }

  @Test func aScrollDuringAnAppsPinchIsTheApps() {
    var router = continuous()
    _ = router.pinch(.began, magnification: 0, at: here, claim: false)
    #expect(!router.scroll(.began, pan: .zero, at: here, keys: .none).swallow)
  }

  @Test func aRotationDuringArborsPinchIsKeptFromTheAppInBothModes() {
    for isContinuous in [false, true] {
      var router = GestureRouter()
      _ = router.setContinuous(isContinuous)
      _ = router.pinch(.began, magnification: 0, at: here, claim: true)
      #expect(router.rotation(.began) == true)
      _ = router.pinch(.ended, magnification: 0, at: here)
      #expect(router.rotation(.ended) == true)
      #expect(router.rotation(.began) == false)
    }
  }

  @Test func anAppsPinchAfterAMissedEndClosesTheOldGesture() {
    var router = continuous()
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    _ = router.drain()
    // The end was missed; the next pinch starts over an app's window.
    #expect(router.pinch(.began, magnification: 0, at: here, claim: false) == .init(swallow: false, needsVisit: true))
    #expect(router.drain().map(\.phase) == [.cancelled])
  }

  @Test func anAppsScrollAfterAMissedEndClosesTheOldGesture() {
    var router = continuous()
    _ = router.scroll(.began, pan: .zero, at: here, keys: .arbors)
    _ = router.drain()
    #expect(router.scroll(.began, pan: .zero, at: here, keys: .none) == .init(swallow: false, needsVisit: true))
    #expect(router.drain().map(\.phase) == [.cancelled])
  }

  @Test func resetCancelsWhatTheListenerSawBegin() {
    var router = continuous()
    #expect(router.reset() == false)
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    _ = router.scroll(.began, pan: .zero, at: here, keys: .none)
    _ = router.rotation(.began)
    _ = router.drain()
    #expect(router.reset() == true)
    #expect(router.drain().map(\.phase) == [.cancelled])
    #expect(router.pinch(.changed, magnification: 0.5, at: here) == .init(swallow: false))
    #expect(router.scroll(.changed, pan: .zero, at: here, keys: .arbors) == .init(swallow: false))
    #expect(router.rotation(.changed) == false)
  }

  @Test func switchingTheSettingInTheMiddleOfAGestureEndsIt() {
    var router = continuous()
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    _ = router.drain()
    #expect(router.setContinuous(true) == false, "no change, nothing happens")
    #expect(router.setContinuous(false) == true)
    #expect(router.drain().map(\.phase) == [.cancelled])
    // The rest of that pinch is not turned into steps halfway.
    #expect(router.pinch(.changed, magnification: 0.6, at: here) == .init(swallow: false))
  }

  @Test func theThresholdIsTheInterpreters() {
    var router = GestureRouter()
    router.threshold = 0.5
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(router.pinch(.changed, magnification: 0.3, at: here).commands.isEmpty)
    #expect(router.pinch(.changed, magnification: 0.3, at: here).commands == [.stepIn])
  }

  @Test func theClaimIsWorkedOutOnlyWhenAPinchBegins() {
    var router = continuous()
    var checks = 0
    func check() -> Bool {
      checks += 1
      return true
    }
    _ = router.pinch(.began, magnification: 0, at: here, claim: check())
    _ = router.pinch(.changed, magnification: 0.1, at: here, claim: check())
    _ = router.pinch(.ended, magnification: 0, at: here, claim: check())
    #expect(checks == 1)
  }
}
