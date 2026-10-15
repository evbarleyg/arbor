import ArborCore
import CoreGraphics
import Testing

/// What is under the pointer, kept for a moment (SurfaceMemo.swift), and what the router makes of it.
@Suite struct SurfaceMemoTests {
  let here = CGPoint(x: 100, y: 200)

  // MARK: The memo

  @Test func atFirstNothingIsKnown() {
    #expect(SurfaceMemo().isBare(at: here, now: 0) == nil)
    #expect(SurfaceMemo().isBare(at: .zero, now: 0) == nil, "not even at the origin")
  }

  @Test(arguments: [true, false])
  func anAnswerHoldsForAMomentWhileThePointerRests(isBare: Bool) {
    var memo = SurfaceMemo()
    memo.remember(isBare, at: here, now: 10)
    #expect(memo.isBare(at: here, now: 10) == isBare)
    #expect(memo.isBare(at: here, now: 10.29) == isBare)
    #expect(memo.isBare(at: here, now: 10.3) == nil)
    #expect(memo.isBare(at: here, now: 100) == nil)
    memo.remember(isBare, at: here, now: 0)
    #expect(memo.isBare(at: here, now: SurfaceMemo.lifetime) == nil, "to the moment")
  }

  @Test func aNudgeIsNoMoveAndAMoveEndsIt() {
    var memo = SurfaceMemo()
    memo.remember(true, at: here, now: 10)
    for (dx, dy) in [(2.0, 0.0), (-2, 0), (0, 2), (0, -2), (2, -2)] {
      #expect(memo.isBare(at: CGPoint(x: here.x + dx, y: here.y + dy), now: 10.1) == true, "\(dx) \(dy)")
    }
    for (dx, dy) in [(2.5, 0.0), (-3, 0), (0, 2.5), (0, -40)] {
      #expect(memo.isBare(at: CGPoint(x: here.x + dx, y: here.y + dy), now: 10.1) == nil, "\(dx) \(dy)")
    }
  }

  @Test func aClockThatWentBackwardsIsNotTrusted() {
    var memo = SurfaceMemo()
    memo.remember(true, at: here, now: 10)
    #expect(memo.isBare(at: here, now: 9.9) == nil)
  }

  @Test func forgettingForgets() {
    var memo = SurfaceMemo()
    memo.remember(true, at: here, now: 10)
    memo.forget()
    #expect(memo.isBare(at: here, now: 10) == nil)
    #expect(memo == SurfaceMemo())
  }

  // MARK: A wheel on the Desktop

  func router(onDesktop: Bool = true) -> GestureRouter {
    var router = GestureRouter()
    router.zoomsWithScroll = true
    router.zoomsOnDesktop = onDesktop
    return router
  }

  let notch = CGSize(width: 0, height: 1)

  /// A free-spinning wheel, or a driver that smooths one: a hundred or two events a second.
  @Test func aSpinningWheelAsksAFewTimesASecondNotWithEveryNotch() {
    var router = router()
    var asked = 0
    func desktop() -> Bool {
      asked += 1
      return true
    }
    for index in 0..<200 {
      let answer = router.scroll(
        .none, pan: notch, at: here, keys: .none, hasNotches: true, now: 50 + Double(index) * 0.005, overDesktop: desktop())
      #expect(answer == .init(swallow: true, commands: [.stepIn]))
    }
    #expect(asked == 4, "one second of it, an answer being good for 0.3 s")
  }

  @Test func theAnswerThatAnAppsWindowIsThereIsKeptAsWell() {
    var router = router()
    var asked = 0
    func window() -> Bool {
      asked += 1
      return false
    }
    for index in 0..<20 {
      let answer = router.scroll(
        .none, pan: notch, at: here, keys: .none, hasNotches: true, now: 50 + Double(index) * 0.01, overDesktop: window())
      #expect(answer == .init(swallow: false))
    }
    #expect(asked == 1)
  }

  /// More notches do not keep an answer alive: Arbor's own steps move windows under the pointer.
  @Test func anAnswerIsNotKeptAliveByBeingUsed() {
    var router = router()
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true).swallow)
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1.25, overDesktop: false).swallow)
    #expect(!router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1.31, overDesktop: false).swallow)
  }

  @Test func elsewhereItIsAskedAgain() {
    var router = router()
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true).swallow)
    let there = CGPoint(x: 400, y: 200)
    #expect(!router.scroll(.none, pan: notch, at: there, keys: .none, hasNotches: true, now: 1.01, overDesktop: false).swallow)
  }

  // MARK: Asking first, with the lock released

  /// `scroll` evaluates `overDesktop` exactly when `scrollAsksWhatIsUnder` says it would.
  @Test func askingFirstAgreesWithWhatScrollDoes() {
    let phases: [(ScrollClaim.Phase, ScrollClaim.Momentum)] = [
      (.none, .none), (.mayBegin, .none), (.began, .none), (.changed, .none), (.ended, .none), (.none, .began),
      (.none, .continued), (.none, .ended), (.none, .none), (.began, .none),
    ]
    let allKeys: [GestureRouter.Keys] = [.none, .arbors, .init(shift: true), .init(command: true), .init(option: true)]
    for onDesktop in [false, true] {
      for zooms in [false, true] {
        for keys in allKeys {
          var router = router(onDesktop: onDesktop)
          router.zoomsWithScroll = zooms
          var now = 5.0
          for (phase, momentum) in phases {
            for step in [0.0, 0.1, 0.4] {
              now += step
              let foretold = router.scrollAsksWhatIsUnder(phase, momentum: momentum, at: here, keys: keys, now: now)
              var asked = false
              func desktop() -> Bool {
                asked = true
                return true
              }
              _ = router.scroll(phase, momentum: momentum, pan: notch, at: here, keys: keys, now: now, overDesktop: desktop())
              #expect(asked == foretold, "\(onDesktop) \(zooms) \(keys) \(phase) \(momentum) \(now)")
            }
          }
        }
      }
    }
  }

  @Test func withTheSettingOffOrAKeyHeldNothingIsAsked() {
    #expect(!router(onDesktop: false).scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1))
    #expect(!router().scrollAsksWhatIsUnder(.none, at: here, keys: .arbors, now: 1))
    #expect(!router().scrollAsksWhatIsUnder(.changed, at: here, keys: .none, now: 1))
    for momentum in [ScrollClaim.Momentum.began, .continued, .ended] {
      #expect(!router().scrollAsksWhatIsUnder(.none, momentum: momentum, at: here, keys: .none, now: 1), "coasting is decided already")
    }
    var withoutScrollZoom = router()
    withoutScrollZoom.zoomsWithScroll = false
    #expect(!withoutScrollZoom.scrollAsksWhatIsUnder(.began, at: here, keys: .none, now: 1))
    #expect(withoutScrollZoom.scroll(.began, pan: notch, at: here, keys: .none, now: 1, overDesktop: true) == .init(swallow: false))
    #expect(router().scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1))
    #expect(router().scrollAsksWhatIsUnder(.began, at: here, keys: .none, now: 1))
  }

  @Test func resettingForgetsTheAnswer() {
    var router = router()
    _ = router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true)
    #expect(!router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.1))
    _ = router.reset()
    #expect(router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.1))
  }

  @Test func withoutAClockNothingIsKept() {
    var router = router()
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, overDesktop: true).swallow)
    #expect(!router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, overDesktop: false).swallow)
  }

  // MARK: What a stale answer may cost

  /// A notch taken by mistake is one notch. A beginning taken by mistake is the whole scroll and its coasting.
  @Test func aScrollThatBeginsAlwaysAsks() {
    var router = router()
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true).swallow)
    // Arbor's step has put a window under the pointer.
    #expect(router.scrollAsksWhatIsUnder(.began, at: here, keys: .none, now: 1.1))
    #expect(!router.scroll(.began, pan: .zero, at: here, keys: .none, now: 1.1, overDesktop: false).swallow)
    #expect(!router.scroll(.changed, pan: CGSize(width: 0, height: 50), at: here, keys: .none, now: 1.12).swallow)
  }

  @Test func theSecondOfTwoQuickStrokesIsJudgedOnItsOwn() {
    var router = router()
    #expect(router.scroll(.began, pan: .zero, at: here, keys: .none, now: 1, overDesktop: true).swallow)
    #expect(router.scroll(.changed, pan: CGSize(width: 0, height: 50), at: here, keys: .none, now: 1.05).commands == [.stepIn])
    #expect(router.scroll(.ended, pan: .zero, at: here, keys: .none, now: 1.1).swallow)
    _ = router.scroll(.mayBegin, pan: .zero, at: here, keys: .none, now: 1.2)
    #expect(!router.scroll(.began, pan: .zero, at: here, keys: .none, now: 1.25, overDesktop: false).swallow, "a window is there now")
  }

  /// What a beginning found out is not kept for the wheel either: nothing is kept that was not asked for a notch.
  @Test func aBeginningLeavesNothingBehindForAWheel() {
    var router = router()
    #expect(router.scroll(.began, pan: .zero, at: here, keys: .none, now: 1, overDesktop: true).swallow)
    _ = router.scroll(.ended, pan: .zero, at: here, keys: .none, now: 1.05)
    #expect(router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.1))
  }

  /// Arbor's own step has moved the windows, and the controller has said where they are now.
  @Test func newsOfTheWindowsEndsTheAnswer() {
    var router = router()
    #expect(router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true).swallow)
    #expect(!router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.01))
    router.forgetWhatIsUnder()
    #expect(router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.01))
    #expect(!router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1.01, overDesktop: false).swallow)
  }

  /// The tap did not look, because an answer was there; then the news came. The no it hands over is nobody's finding.
  @Test func anAnswerNobodyLookedForIsNotKept() {
    var router = router()
    _ = router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 0, overDesktop: true)
    let news = router.newsOfTheWindows
    #expect(!router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 0.1))
    router.forgetWhatIsUnder()  // the main actor, between the tap's two visits
    #expect(
      !router.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 0.1, asOf: news, overDesktop: false).swallow)
    #expect(router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 0.15))
  }

  /// The tap looked and found the Desktop bare; while it looked a window came there, and the controller said so.
  @Test func whatWasFoundBeforeTheNewsIsNeitherBelievedNorKept() {
    for phase in [ScrollClaim.Phase.none, .began] {
      var router = router()
      let news = router.newsOfTheWindows
      #expect(router.scrollAsksWhatIsUnder(phase, at: here, keys: .none, now: 1))
      router.forgetWhatIsUnder()
      #expect(
        !router.scroll(phase, pan: notch, at: here, keys: .none, hasNotches: phase == .none, now: 1, asOf: news, overDesktop: true).swallow,
        "\(phase)")
      #expect(router.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.01))
    }
  }

  /// The tap asks, reads the list with the lock released, and comes back. Whatever the main actor did meanwhile, the app gets it.
  @Test func whateverHappensBetweenAskingAndScrollingTheAppGetsIt() {
    var kept = router()
    _ = kept.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true)
    #expect(!kept.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1.1))
    _ = kept.reset()  // the taps were stopped, or macOS switched one off
    #expect(!kept.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1.1, overDesktop: false).swallow)
    var switchedOn = router(onDesktop: false)
    #expect(!switchedOn.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1))
    switchedOn.zoomsOnDesktop = true
    #expect(!switchedOn.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: false).swallow)
    var switchedOff = router()
    #expect(switchedOff.scrollAsksWhatIsUnder(.none, at: here, keys: .none, now: 1))
    switchedOff.zoomsOnDesktop = false
    #expect(!switchedOff.scroll(.none, pan: notch, at: here, keys: .none, hasNotches: true, now: 1, overDesktop: true).swallow)
  }
}
