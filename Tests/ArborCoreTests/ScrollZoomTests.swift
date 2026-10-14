import ArborCore
import CoreGraphics
import Foundation
import Testing

/// Zooming with a mouse (docs/features/F55-zoom-with-a-mouse.md): the arithmetic, then whose a scroll is.
@Suite struct ScrollZoomTests {
  // MARK: Steps

  @Test func oneNotchIsOneStepWhateverAccelerationMakesOfIt() {
    var zoom = ScrollZoom()
    #expect(zoom.notch(1) == 1)
    #expect(zoom.notch(17) == 1)
    #expect(zoom.notch(0.1) == 1)
    #expect(zoom.notch(-1) == -1)
    #expect(zoom.notch(-300) == -1)
    #expect(zoom.notch(0) == 0)
    #expect(zoom.notch(.nan) == 0)
    #expect(zoom.notch(.infinity) == 1)
  }

  @Test func travelStepsOncePerThreshold() {
    var zoom = ScrollZoom()
    #expect(zoom.move(by: 39) == 0)
    #expect(zoom.move(by: 1) == 1)
    #expect(zoom.travel == 0)
    #expect(zoom.move(by: 100) == 2)
    #expect(zoom.travel == 20)
    #expect(zoom.move(by: 20) == 1)
  }

  @Test func turningBackWorks() {
    var zoom = ScrollZoom()
    #expect(zoom.move(by: 30) == 0)
    #expect(zoom.move(by: -30) == 0)
    #expect(zoom.move(by: -40) == -1)
    #expect(zoom.move(by: -90) == -2)
    #expect(zoom.move(by: 50) == 1)
  }

  @Test func manySmallDeltasAddUp() {
    var zoom = ScrollZoom()
    var steps = 0
    for _ in 0..<100 { steps += zoom.move(by: 0.4) }
    #expect(steps == 1)
    var tenths = ScrollZoom(threshold: 1000.0 / 3)
    steps = 0
    for _ in 0..<10 { steps += tenths.move(by: 100.0 / 3) }
    #expect(steps == 1, "rounding does not eat the step")
  }

  @Test func travelIsNotCarriedFromOneScrollToTheNextNorPastANotch() {
    var zoom = ScrollZoom()
    _ = zoom.move(by: 39)
    zoom.reset()
    #expect(zoom.move(by: 1) == 0)
    _ = zoom.move(by: 38)
    _ = zoom.notch(1)
    #expect(zoom.move(by: 2) == 0)
  }

  @Test func absurdNumbersAreHarmless() {
    var zoom = ScrollZoom()
    #expect(zoom.move(by: .nan) == 0)
    #expect(zoom.move(by: .infinity) == 0)
    #expect(zoom.move(by: 1e300) == 8, "no event means more steps than that")
    #expect(zoom.travel == 0)
    #expect(zoom.move(by: -1e300) == -8)
    for threshold in [0, -5, Double.nan, .infinity] {
      #expect(ScrollZoom(threshold: threshold).effectiveThreshold == 40, "\(threshold)")
    }
    #expect(ScrollZoom(threshold: 0.001).effectiveThreshold == 4, "a resting finger does not step")
    #expect(ScrollZoom(threshold: 120).effectiveThreshold == 120)
  }

  // MARK: Whose a scroll is

  let here = CGPoint(x: 100, y: 200)

  func router(continuous: Bool = false, onDesktop: Bool = false) -> GestureRouter {
    var router = GestureRouter()
    router.zoomsWithScroll = true
    router.zoomsOnDesktop = onDesktop
    _ = router.setContinuous(continuous)
    return router
  }

  func up(_ points: CGFloat) -> CGSize { CGSize(width: 0, height: points) }

  @Test func aWheelWithTheKeysHeldStepsOncePerNotchTowardAndAway() {
    var router = router()
    #expect(router.scrollNeedsALook(keys: .arbors))
    let notch = { (router: inout GestureRouter, delta: CGFloat) in
      router.scroll(
        .none, pan: CGSize(width: 0, height: delta), at: CGPoint(x: 100, y: 200), keys: .arbors,
        hasNotches: true)
    }
    #expect(notch(&router, 1) == .init(swallow: true, commands: [.stepIn]))
    #expect(notch(&router, 12) == .init(swallow: true, commands: [.stepIn]))
    #expect(notch(&router, -1) == .init(swallow: true, commands: [.stepOut]))
    #expect(notch(&router, 0) == .init(swallow: true), "sideways: Arbor's, and nothing happens")
    #expect(router.drain().isEmpty)
  }

  @Test func eachNotchIsOnItsOwnSoLettingGoOfTheKeysGivesTheWheelBack() {
    var router = router()
    #expect(router.scroll(.none, pan: up(1), at: here, keys: .arbors, hasNotches: true).swallow)
    #expect(!router.scrollNeedsALook(keys: .none))
    #expect(router.scroll(.none, pan: up(1), at: here, keys: .none, hasNotches: true) == .init(swallow: false))
  }

  @Test(arguments: [(true, false), (false, true), (false, false)])
  func withoutBothKeysNothingIsLookedAtOrSwallowed(option: Bool, control: Bool) {
    var router = router()
    #expect(!router.scrollNeedsALook(keys: .init(control: control, option: option)))
    for phase in [ScrollClaim.Phase.none, .mayBegin, .began, .changed, .ended] {
      let answer = router.scroll(phase, pan: up(500), at: here, keys: .init(control: control, option: option))
      #expect(answer == .init(swallow: false), "\(phase)")
    }
  }

  @Test func fingersStepOncePerThresholdOfTravel() {
    var router = router()
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .arbors) == .init(swallow: true))
    #expect(router.scroll(.changed, pan: up(30), at: here, keys: .arbors) == .init(swallow: true))
    #expect(
      router.scroll(.changed, pan: up(55), at: here, keys: .arbors)
        == .init(swallow: true, commands: [.stepIn, .stepIn]))
    #expect(
      router.scroll(.changed, pan: up(-50), at: here, keys: .arbors)
        == .init(swallow: true, commands: [.stepOut]))
    #expect(router.scroll(.ended, pan: up(0), at: here, keys: .arbors) == .init(swallow: true))
  }

  @Test func theThresholdIsTheSettings() {
    var router = router()
    router.scrollThreshold = 100
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scroll(.changed, pan: up(99), at: here, keys: .arbors).commands.isEmpty)
    #expect(router.scroll(.changed, pan: up(1), at: here, keys: .arbors).commands == [.stepIn])
  }

  @Test func aScrollClaimedAtItsStartStaysClaimedWhenTheKeysGoUp() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scrollNeedsALook(keys: .none))
    #expect(router.scroll(.changed, pan: up(40), at: here, keys: .none) == .init(swallow: true, commands: [.stepIn]))
    #expect(router.scroll(.ended, pan: up(0), at: here, keys: .none) == .init(swallow: true))
  }

  @Test func aScrollTheAppSawBeginStaysTheAppsWhenTheKeysGoDown() {
    var router = router()
    #expect(!router.scroll(.began, pan: up(0), at: here, keys: .none).swallow)
    #expect(router.scroll(.changed, pan: up(400), at: here, keys: .arbors) == .init(swallow: false))
    #expect(router.scroll(.ended, pan: up(0), at: here, keys: .arbors) == .init(swallow: false))
  }

  @Test func momentumGivesNoStepsAndDoesNotReachTheApp() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    _ = router.scroll(.ended, pan: up(10), at: here, keys: .arbors)
    #expect(router.scrollNeedsALook(keys: .none))
    for momentum in [ScrollClaim.Momentum.began, .continued, .continued, .ended] {
      #expect(router.scroll(.none, momentum: momentum, pan: up(300), at: here, keys: .none) == .init(swallow: true))
    }
    #expect(!router.scrollNeedsALook(keys: .none), "and then the scroll wheel is everybody's again")
  }

  @Test func theMomentumOfAnAppsScrollIsTheAppsEvenWithTheKeysHeld() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .none)
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    let answer = router.scroll(.none, momentum: .continued, pan: up(300), at: here, keys: .arbors)
    #expect(answer == .init(swallow: false))
  }

  @Test func travelIsNotCarriedFromOneScrollToTheNext() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    _ = router.scroll(.changed, pan: up(39), at: here, keys: .arbors)
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .arbors)
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scroll(.changed, pan: up(2), at: here, keys: .arbors).commands.isEmpty)
  }

  @Test func aCancelledScrollsLastMovementDoesNotCount() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scroll(.cancelled, pan: up(400), at: here, keys: .arbors) == .init(swallow: true))
  }

  /// Some drivers smooth a wheel into points of travel, without phases.
  @Test func travelWithoutPhasesStepsByTheThresholdWhileTheKeysAreHeld() {
    var router = router()
    #expect(router.scroll(.none, pan: up(25), at: here, keys: .arbors) == .init(swallow: true))
    #expect(router.scroll(.none, pan: up(25), at: here, keys: .arbors).commands == [.stepIn])
    #expect(router.scroll(.none, pan: up(25), at: here, keys: .none) == .init(swallow: false))
  }

  @Test func withTheSettingOffScrollsAreNobodysBusiness() {
    var router = GestureRouter()
    #expect(!router.scrollNeedsALook(keys: .arbors))
    #expect(router.scroll(.none, pan: up(1), at: here, keys: .arbors, hasNotches: true) == .init(swallow: false))
    #expect(router.scroll(.began, pan: up(1), at: here, keys: .arbors) == .init(swallow: false))
  }

  @Test func resettingForgetsTheScrollInProgress() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    _ = router.scroll(.changed, pan: up(39), at: here, keys: .arbors)
    let needsVisit = router.reset()
    #expect(!needsVisit, "nobody was listening")
    #expect(router.scroll(.changed, pan: up(40), at: here, keys: .arbors) == .init(swallow: false))
    #expect(!router.scrollNeedsALook(keys: .none))
  }

  // MARK: When the tap is switched on

  @Test(arguments: [false, true])
  func theTapIsWantedWithBothKeysDownAndNotWithOneOrNone(continuous: Bool) {
    let router = router(continuous: continuous)
    #expect(!router.scrollTapIsWanted(keys: .none))
    #expect(!router.scrollTapIsWanted(keys: .init(option: true)), "⌥ + scroll alone is never Arbor's")
    #expect(!router.scrollTapIsWanted(keys: .init(control: true)), "⌃ + scroll is macOS's own zoom")
    #expect(router.scrollTapIsWanted(keys: .arbors))
  }

  @Test func withNeitherSettingTheTapIsNeverWanted() {
    #expect(!GestureRouter().scrollTapIsWanted(keys: .arbors))
    #expect(!GestureRouter().scrollTapIsWanted(keys: .none))
  }

  /// Otherwise the app would get the tail of a scroll it never saw begin.
  @Test func lettingGoOfTheKeysDuringAScrollOrItsMomentumDoesNotSwitchTheTapOff() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scrollTapIsWanted(keys: .none), "fingers still down")
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    #expect(router.scrollTapIsWanted(keys: .none), "momentum may follow")
    _ = router.scroll(.none, momentum: .began, pan: up(9), at: here, keys: .none)
    _ = router.scroll(.none, momentum: .continued, pan: up(9), at: here, keys: .none)
    #expect(router.scrollTapIsWanted(keys: .none))
    _ = router.scroll(.none, momentum: .ended, pan: up(0), at: here, keys: .none)
    #expect(!router.scrollTapIsWanted(keys: .none), "over")
  }

  @Test func ifTheEndOfTheMomentumIsMissedTheNextTouchFreesTheTap() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    #expect(router.scrollTapIsWanted(keys: .none))
    #expect(!router.scroll(.mayBegin, pan: up(0), at: here, keys: .none).swallow)
    #expect(!router.scrollTapIsWanted(keys: .none))
  }

  @Test func anAppsScrollDoesNotKeepTheTapOn() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .init(option: true))
    #expect(!router.scrollTapIsWanted(keys: .none))
  }

  @Test func aWheelLeavesNothingBehind() {
    var router = router()
    _ = router.scroll(.none, pan: up(1), at: here, keys: .arbors, hasNotches: true)
    #expect(!router.scrollTapIsWanted(keys: .none))
  }

  @Test func zoomingOnTheDesktopNeedsTheTapAllTheTime() {
    #expect(router(onDesktop: true).scrollTapIsWanted(keys: .none))
    var off = router(onDesktop: true)
    off.zoomsWithScroll = false
    #expect(!off.scrollTapIsWanted(keys: .none), "not without scrollZoom itself")
  }

  @Test func withContinuousZoomAPinchOfArborsWantsTheTapWithoutTheKeys() {
    var router = GestureRouter()
    _ = router.setContinuous(true)
    #expect(!router.scrollTapIsWanted(keys: .none))
    #expect(router.scrollTapIsWanted(keys: .arbors))
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(router.scrollTapIsWanted(keys: .none))
    _ = router.pinch(.ended, magnification: 0, at: here)
    #expect(!router.scrollTapIsWanted(keys: .none))
    // Without continuousZoom a pinch claims no scroll.
    var stepping = self.router()
    _ = stepping.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(!stepping.scrollTapIsWanted(keys: .none))
  }

  /// Whatever has to be looked at can only be seen with the tap on.
  @Test func whatNeedsALookAlwaysWantsTheTap() {
    for continuous in [false, true] {
      for onDesktop in [false, true] {
        for zooms in [false, true] {
          var router = GestureRouter()
          router.zoomsWithScroll = zooms
          router.zoomsOnDesktop = onDesktop
          _ = router.setContinuous(continuous)
          for step in 0..<4 {
            for option in [false, true] {
              for control in [false, true] where router.scrollNeedsALook(keys: .init(control: control, option: option)) {
                #expect(router.scrollTapIsWanted(keys: .init(control: control, option: option)), "\(continuous) \(onDesktop) \(zooms) \(step) \(option) \(control)")
              }
            }
            switch step {
            case 0: _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
            case 1: _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
            default: _ = router.pinch(.began, magnification: 0, at: here, claim: true)
            }
          }
        }
      }
    }
  }

  // MARK: On the Desktop, without the keys

  @Test func onTheDesktopItZoomsWithoutTheKeysIfAskedTo() {
    var router = router(onDesktop: true)
    #expect(router.scrollNeedsALook(keys: .none), "every scroll has to be looked at then")
    #expect(
      router.scroll(.none, pan: up(1), at: here, keys: .none, hasNotches: true, overDesktop: true)
        == .init(swallow: true, commands: [.stepIn]))
    #expect(
      router.scroll(.none, pan: up(1), at: here, keys: .none, hasNotches: true, overDesktop: false)
        == .init(swallow: false))
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .none, overDesktop: true).swallow)
    // Decided when it began: the pointer may since have come over a window.
    #expect(router.scroll(.changed, pan: up(-40), at: here, keys: .none, overDesktop: false).commands == [.stepOut])
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    #expect(!router.scroll(.began, pan: up(0), at: here, keys: .none, overDesktop: false).swallow)
  }

  @Test func whatIsUnderThePointerIsAskedOnlyWhenItMatters() {
    var asked = 0
    func desktop() -> Bool {
      asked += 1
      return true
    }
    var plain = router()
    _ = plain.scroll(.began, pan: up(0), at: here, keys: .none, overDesktop: desktop())
    _ = plain.scroll(.none, pan: up(1), at: here, keys: .none, hasNotches: true, overDesktop: desktop())
    #expect(asked == 0, "the setting is off")
    var router = router(onDesktop: true)
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors, overDesktop: desktop())
    #expect(asked == 0, "the keys have decided already")
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .arbors, overDesktop: desktop())
    _ = router.scroll(.began, pan: up(0), at: here, keys: .none, overDesktop: desktop())
    for _ in 0..<20 { _ = router.scroll(.changed, pan: up(1), at: here, keys: .none, overDesktop: desktop()) }
    #expect(asked == 1, "once per scroll")
  }

  // MARK: With a view that follows the fingers (F16)

  @Test func withContinuousZoomTheSameScrollMovesAsFarAsAPinchThatWouldHaveSteppedAsOften() {
    var router = router(continuous: true)
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .arbors) == .init(swallow: true, needsVisit: true))
    #expect(router.scroll(.changed, pan: up(40), at: here, keys: .arbors) == .init(swallow: true))
    #expect(router.scroll(.changed, pan: up(20), at: here, keys: .arbors) == .init(swallow: true))
    #expect(router.scroll(.ended, pan: up(0), at: here, keys: .arbors) == .init(swallow: true))
    let updates = router.drain()
    #expect(updates.map(\.phase) == [.began, .ended])
    #expect(abs(updates[1].magnification - 0.375) < 1e-9, "one and a half steps of 0.25")
    #expect(updates[1].pan == .zero, "it zooms, it does not pan")
  }

  /// The product owner, 2026-10-14: ⌥ + scroll alone is never Arbor's, whatever `continuousZoom` says.
  @Test(arguments: [(true, false), (false, true), (false, false)])
  func withContinuousZoomTooAScrollWithoutBothKeysIsTheApps(option: Bool, control: Bool) {
    for zooms in [false, true] {
      var router = router(continuous: true)
      router.zoomsWithScroll = zooms
      #expect(!router.scrollNeedsALook(keys: .init(control: control, option: option)))
      for (phase, pan) in [(ScrollClaim.Phase.began, up(0)), (.changed, sideways(40)), (.changed, up(40)), (.ended, up(0))] {
        #expect(router.scroll(phase, pan: pan, at: here, keys: .init(control: control, option: option)) == .init(swallow: false))
      }
      #expect(router.drain().isEmpty)
    }
  }

  // MARK: Exactly ⌃⌥

  typealias Keys = GestureRouter.Keys
  let withShift = Keys(control: true, option: true, shift: true)
  let withCommand = Keys(control: true, option: true, command: true)
  let hyper = Keys(control: true, option: true, shift: true, command: true)

  /// The product owner, 2026-10-14: other chords stay with the apps, and the hyper key with people.
  @Test(arguments: [false, true])
  func fingersWithAnotherKeyBesidesAreTheApps(continuous: Bool) {
    for keys in [withShift, withCommand, hyper] {
      var router = router(continuous: continuous)
      for (phase, pan) in [(ScrollClaim.Phase.began, up(0)), (.changed, up(80)), (.changed, sideways(80)), (.ended, up(0))] {
        #expect(router.scroll(phase, pan: pan, at: here, keys: keys) == .init(swallow: false), "\(keys) \(phase)")
      }
      #expect(router.drain().isEmpty)
      #expect(!router.scrollTapIsWanted(keys: .none), "nothing is left behind")
    }
  }

  /// ⇧ is how macOS turns a wheel sideways.
  @Test func forAWheelShiftDoesNotCount() {
    var router = router()
    #expect(router.scroll(.none, pan: sideways(3), at: here, keys: withShift, hasNotches: true) == .init(swallow: true))
    #expect(router.scroll(.none, pan: up(1), at: here, keys: withShift, hasNotches: true) == .init(swallow: true, commands: [.stepIn]))
  }

  @Test func aWheelWithCommandBesidesIsTheApps() {
    var router = router()
    for keys in [withCommand, hyper] {
      #expect(router.scroll(.none, pan: up(1), at: here, keys: keys, hasNotches: true) == .init(swallow: false))
      #expect(router.scroll(.none, pan: up(50), at: here, keys: keys) == .init(swallow: false))
    }
  }

  @Test func theTapWakesForWhatCouldBeArborsAndNoMore() {
    for continuous in [false, true] {
      let router = router(continuous: continuous)
      #expect(router.scrollTapIsWanted(keys: .arbors))
      #expect(router.scrollTapIsWanted(keys: withShift), "a wheel may follow")
      #expect(!router.scrollTapIsWanted(keys: withCommand))
      #expect(!router.scrollTapIsWanted(keys: hyper))
      #expect(!router.scrollTapIsWanted(keys: Keys(shift: true)))
    }
    // Without scrollZoom a wheel does nothing, so ⇧ besides is one key too many.
    var sliding = router(continuous: true)
    sliding.zoomsWithScroll = false
    #expect(sliding.scrollTapIsWanted(keys: .arbors))
    #expect(!sliding.scrollTapIsWanted(keys: withShift))
  }

  @Test func aKeyThatGoesDownDuringAScrollOfArborsChangesNothing() {
    var router = router()
    _ = router.scroll(.began, pan: up(0), at: here, keys: .arbors)
    #expect(router.scroll(.changed, pan: up(40), at: here, keys: hyper) == .init(swallow: true, commands: [.stepIn]))
  }

  @Test func onTheDesktopWithoutTheKeysMeansWithoutAnyKey() {
    var router = router(onDesktop: true)
    for keys in [Keys(command: true), Keys(shift: true), Keys(option: true), Keys(control: true), withCommand] {
      #expect(router.scroll(.none, pan: up(1), at: here, keys: keys, hasNotches: true, overDesktop: true) == .init(swallow: false), "\(keys)")
      #expect(router.scroll(.began, pan: up(1), at: here, keys: keys, overDesktop: true) == .init(swallow: false), "\(keys)")
      _ = router.scroll(.ended, pan: up(0), at: here, keys: keys)
    }
    #expect(router.scroll(.began, pan: up(1), at: here, keys: .none, overDesktop: true).swallow)
  }

  // MARK: Up and down zooms, sideways slides

  func sideways(_ points: CGFloat) -> CGSize { CGSize(width: points, height: 0) }

  /// Feeds a whole scroll with ⌃⌥ held and returns what the listener is told at its end.
  func scrolled(_ router: inout GestureRouter, began: CGSize = .zero, _ moves: CGSize...) -> GestureUpdate? {
    #expect(router.scroll(.began, pan: began, at: here, keys: .arbors).swallow)
    for move in moves {
      #expect(router.scroll(.changed, pan: move, at: here, keys: .arbors).swallow)
    }
    #expect(router.scroll(.ended, pan: .zero, at: here, keys: .arbors).swallow)
    return router.drain().last
  }

  @Test func sidewaysWithTheKeysSlidesTheView() {
    var router = router(continuous: true)
    let end = scrolled(&router, sideways(30), sideways(12))
    #expect(end?.pan == sideways(42) && end?.magnification == 0)
  }

  @Test func theWayItFirstMovesDecidesForAllOfIt() {
    var router = router(continuous: true)
    // A slide that wanders is still a slide, in both directions.
    let slide = scrolled(&router, CGSize(width: -8, height: 3), up(100))
    #expect(slide?.pan == CGSize(width: -8, height: 103) && slide?.magnification == 0)
    // A zoom that wanders is still a zoom, and what goes sideways is lost.
    let zoom = scrolled(&router, CGSize(width: 3, height: 8), sideways(100), up(32))
    #expect(zoom?.pan == .zero)
    #expect(abs((zoom?.magnification ?? 0) - 0.25) < 1e-9, "40 points up: one step of 0.25")
  }

  @Test func eachScrollDecidesAnew() {
    var router = router(continuous: true)
    #expect(scrolled(&router, sideways(30))?.magnification == 0)
    #expect(scrolled(&router, up(40))?.pan == .zero)
    #expect(scrolled(&router, sideways(30))?.pan == sideways(30))
  }

  @Test func aDiagonalCountsAsUpOrDown() {
    var router = router(continuous: true)
    for move in [CGSize(width: 10, height: 10), CGSize(width: -10, height: 10), CGSize(width: 10, height: -10)] {
      let end = scrolled(&router, move)
      #expect(end?.pan == .zero && end?.magnification != 0, "\(move)")
    }
  }

  @Test func aBeginningThatMovesDecidesAtOnce() {
    var router = router(continuous: true)
    let slide = scrolled(&router, began: sideways(5), up(50))
    #expect(slide?.pan == up(50) && slide?.magnification == 0, "the beginning's own movement went with the beginning")
    let zoom = scrolled(&router, began: up(5), sideways(50), up(40))
    #expect(zoom?.pan == .zero && zoom?.magnification == 0.25)
  }

  /// Some drivers begin a scroll without movement, and go on without for a while.
  @Test func nothingIsDecidedUntilItMoves() {
    var router = router(continuous: true)
    #expect(scrolled(&router, .zero, .zero, sideways(-20))?.pan == sideways(-20))
    #expect(scrolled(&router, .zero, .zero, up(-40))?.magnification == -0.25)
  }

  @Test func aScrollThatNeverMovesIsArborsAndDoesNothing() {
    var router = router(continuous: true)
    #expect(scrolled(&router) == GestureUpdate(phase: .ended, location: here))
    #expect(router.scrollTapIsWanted(keys: .none), "its momentum could follow")
  }

  /// There is nothing to slide then, and a stroke that starts a little askew is still meant as a zoom.
  @Test func withoutContinuousZoomEveryScrollWithTheKeysIsAZoom() {
    var router = router()
    _ = router.scroll(.began, pan: sideways(9), at: here, keys: .arbors)
    #expect(router.scroll(.changed, pan: sideways(400), at: here, keys: .arbors) == .init(swallow: true))
    #expect(
      router.scroll(.changed, pan: CGSize(width: 90, height: 40), at: here, keys: .arbors)
        == .init(swallow: true, commands: [.stepIn]))
    #expect(router.drain().isEmpty)
  }

  @Test func withScrollZoomOffEveryScrollWithTheKeysSlides() {
    var router = router(continuous: true)
    router.zoomsWithScroll = false
    let end = scrolled(&router, up(40), sideways(2))
    #expect(end?.pan == CGSize(width: 2, height: 40) && end?.magnification == 0)
  }

  @Test func theFingersOfAPinchOfArborsSlideWhicheverWayTheyMove() {
    var router = router(continuous: true)
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .none).swallow)
    #expect(router.scroll(.changed, pan: up(30), at: here, keys: .none).swallow)
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    _ = router.pinch(.ended, magnification: 0, at: here)
    let end = router.drain().last
    #expect(end?.pan == up(30) && end?.magnification == 0)
  }

  @Test func withoutContinuousZoomAScrollDuringAPinchOfArborsIsTheApps() {
    var router = router()
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .none) == .init(swallow: false))
    #expect(router.scroll(.changed, pan: up(30), at: here, keys: .none) == .init(swallow: false))
  }

  @Test func onTheDesktopWithoutTheKeysItZoomsHoweverItStarts() {
    var router = router(continuous: true, onDesktop: true)
    #expect(router.scroll(.began, pan: up(0), at: here, keys: .none, overDesktop: true).swallow)
    _ = router.scroll(.changed, pan: sideways(30), at: here, keys: .none)
    _ = router.scroll(.changed, pan: up(40), at: here, keys: .none)
    _ = router.scroll(.ended, pan: up(0), at: here, keys: .none)
    let end = router.drain().last
    #expect(end?.pan == .zero && end?.magnification == 0.25)
  }

  @Test func aWheelTurnedSidewaysDoesNothingInEitherMode() {
    for continuous in [false, true] {
      var router = router(continuous: continuous)
      let answer = router.scroll(.none, pan: sideways(3), at: here, keys: .arbors, hasNotches: true)
      #expect(answer == .init(swallow: true), "⇧ turns a wheel sideways: Arbor's, and nothing happens")
      #expect(router.drain().isEmpty)
    }
  }

  @Test func withContinuousZoomANotchIsAWholeGestureWorthOneStep() {
    var router = router(continuous: true)
    let answer = router.scroll(.none, pan: up(-3), at: here, keys: .arbors, hasNotches: true)
    #expect(answer == .init(swallow: true, needsVisit: true))
    #expect(
      router.drain() == [
        GestureUpdate(phase: .began, location: here), GestureUpdate(phase: .ended, location: here, magnification: -0.25),
      ])
    // Several before the main actor comes by stay in pairs.
    for _ in 0..<3 { _ = router.scroll(.none, pan: up(1), at: here, keys: .arbors, hasNotches: true) }
    #expect(router.drain().map(\.phase) == [.began, .ended, .began, .ended, .began, .ended])
  }

  @Test func aNotchDuringAPinchOfArborsIsSwallowedAndAddsNothing() {
    var router = router(continuous: true)
    _ = router.pinch(.began, magnification: 0, at: here, claim: true)
    let answer = router.scroll(.none, pan: up(1), at: here, keys: .arbors, hasNotches: true)
    #expect(answer == .init(swallow: true))
    _ = router.pinch(.ended, magnification: 0, at: here)
    #expect(router.drain().map(\.phase) == [.began, .ended])
  }

  // MARK: Settings

  @Test func theSettingsHaveTheirDefaultsAndOldFilesLoad() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(old.scrollZoom && old.scrollZoomThreshold == 40 && !old.scrollOnDesktopZooms)
    var changed = Settings()
    changed.scrollZoom = false
    changed.scrollZoomThreshold = 25
    changed.scrollOnDesktopZooms = true
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(changed)) == changed)
  }
}
