import Testing

@testable import ArborCore

/// When the event taps let go because Arbor may no longer have them. Rule 6: input is never blocked.
@Suite struct TapPermissionTests {
  typealias Order = TapPermission.Order
  static let beat = TapPermission.beat
  /// The same in the model's milliseconds.
  static let beatMs = Int((TapPermission.beat * 1000).rounded())

  // MARK: The orders, one by one

  @Test func whileTapsAreInMacOSIsAskedAtEveryBeat() {
    var permission = TapPermission()
    for beat in 0..<8 {
      let now = 100 + Double(beat) * Self.beat
      #expect(permission.beat(at: now, tapsAreIn: true) == .ask)
      #expect(permission.heard(.yes, at: now + 0.001) == .lookAfter)
    }
    #expect(permission.mayInstall)
  }

  @Test func withoutTapsNobodyIsAskedAndTheClockMayStop() {
    // Every gesture switched off: no tap, so no clock and no question.
    var permission = TapPermission()
    #expect(permission.clock(tapsAreIn: false) == nil)
    for beat in 0..<8 { #expect(permission.beat(at: 100 + Double(beat) * Self.beat, tapsAreIn: false) == .nothing) }
    #expect(permission.clock(tapsAreIn: true) == Self.beat)
  }

  @Test(arguments: [TapPermission.Answer.flagSaysNo, .tapRefused]) func oneNoAndAllTapsGo(no: TapPermission.Answer) {
    // `.tapRefused`: the flag says yes but a tap is refused, which is how a loss that nobody announced showed on hosted Macs.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.heard(no, at: 100.001) == .removeAll(no))
    #expect(permission.isGone)
    #expect(!permission.mayInstall, "whoever asks: the main thread may not have heard yet")
  }

  @Test func toldThatATapIsOffMacOSIsAskedAtOnceAndAtANoAllGo() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.heard(.yes, at: 100.001) == .lookAfter)
    #expect(permission.toldOff(at: 100.1) == .ask, "not at the next beat")
    #expect(permission.heard(.tapRefused, at: 100.101) == .removeAll(.tapRefused))
  }

  @Test func toldThatATapIsOffAndMacOSSaysYesNothingGoes() {
    // The usual case: the Mac was waking, or short of memory. What becomes of the tap is `TapHealth`'s to say.
    var permission = TapPermission()
    #expect(permission.toldOff(at: 100.1) == .ask)
    #expect(permission.heard(.yes, at: 100.101) == .lookAfter)
    #expect(!permission.isGone)
  }

  @Test func thereIsNeverMoreThanOneQuestion() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.toldOff(at: 100.01) == .nothing)
    #expect(permission.toldOff(at: 100.02) == .nothing)
    #expect(permission.heard(.yes, at: 100.03) == .lookAfter)
    #expect(permission.heard(.flagSaysNo, at: 100.04) == .nothing, "an answer nobody asked for")
    #expect(!permission.isGone)
  }

  @Test func noAnswerByTheNextBeatIsANo() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreIn: true) == .removeAll(.nothing))
    #expect(!permission.mayInstall)
    // For five seconds nothing comes. No second question is sent after one that hangs.
    for second in 1...5 { #expect(permission.beat(at: 100 + Self.beat + Double(second), tapsAreIn: false) == .nothing) }
    #expect(permission.clock(tapsAreIn: false) == TapPermission.beatWhileGone)
  }

  @Test func ifTheLateAnswerIsYesTheTapsComeBackWithItAndTheOrderSaysThatTheAlarmWasFalse() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreIn: true)
    _ = permission.beat(at: 100 + Self.beat, tapsAreIn: true)
    #expect(permission.heard(.yes, at: 100.5) == .comeBack(after: 100.5 - (100 + Self.beat), wentFor: .nothing))
    #expect(permission.mayInstall)
  }

  @Test func ifTheLateAnswerIsNoTheyStayAway() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreIn: true)
    _ = permission.beat(at: 100 + Self.beat, tapsAreIn: true)
    #expect(permission.heard(.flagSaysNo, at: 103) == .nothing)
    #expect(permission.isGone)
    #expect(permission.beat(at: 103.5, tapsAreIn: false) == .ask, "and from now on macOS is asked whether it is back")
    // The loss was real, and is not counted among the false alarms when it is over.
    #expect(permission.heard(.yes, at: 193.5) == .comeBack(after: 193.5 - (100 + Self.beat), wentFor: .flagSaysNo))
  }

  @Test func aNoWhenTheLastTapHasGoneMeanwhileRemovesNothingAndStartsNothing() {
    // A pause, or a setting, took the taps out while the question was out. No line in the log about taps that were not there,
    // and no clock that asks for the sake of taps nobody wants.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.heard(.tapRefused, at: 100.001, tapsAreIn: false) == .nothing)
    #expect(!permission.isGone)
    #expect(permission.clock(tapsAreIn: false) == nil)
  }

  @Test func aBeatThatIsLateAndTheNextOnTimeAreNoFalseAlarmIfTheAnswerComesWithinHalfABeat() {
    // A handler took its time, so the question went out late. The timer keeps its grid.
    var permission = TapPermission()
    #expect(permission.beat(at: 100 + Self.beat * 0.6, tapsAreIn: true) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreIn: true) == .nothing, "0.4 of a beat old")
    #expect(permission.beat(at: 100 + 2 * Self.beat, tapsAreIn: true) == .removeAll(.nothing))
  }

  @Test func whenTheNetFindsTheClockStandingTheThreadForgetsTheTapsAndANewClockAsksWhetherTheyMayReturn() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.heard(.yes, at: 100.001) == .lookAfter)
    #expect(permission.clockStood(at: 101.2) == .removeAll(.clockStood))
    #expect(!permission.mayInstall)
    #expect(permission.clock(tapsAreIn: false) == TapPermission.beatWhileGone, "another beat, so another timer")
    #expect(permission.beat(at: 102.2, tapsAreIn: false) == .ask)
    #expect(permission.heard(.yes, at: 102.25) == .comeBack(after: 102.25 - 101.2, wentFor: .clockStood))
  }

  @Test func ifThePermissionHadGoneWhileTheClockStoodTheTapsStayAwayAndTheLogSaysWhy() {
    var permission = TapPermission()
    #expect(permission.clockStood(at: 101.2) == .removeAll(.clockStood))
    #expect(permission.beat(at: 102.2, tapsAreIn: false) == .ask)
    #expect(permission.heard(.tapRefused, at: 102.25) == .nothing)
    #expect(permission.beat(at: 103.2, tapsAreIn: false) == .ask)
    #expect(permission.heard(.yes, at: 103.25) == .comeBack(after: 103.25 - 101.2, wentFor: .tapRefused))
  }

  @Test func aClockFoundStandingWhileThePermissionIsGoneIsNothing() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreIn: true)
    _ = permission.heard(.flagSaysNo, at: 100)
    #expect(permission.clockStood(at: 101.2) == .nothing)
  }

  @Test func onlyWhatMacOSSaidIsANo() {
    // Whoever else wants to know about the permission hears of these two and of nothing else.
    #expect(TapPermission.Answer.flagSaysNo.isANo && TapPermission.Answer.tapRefused.isANo)
    #expect(!TapPermission.Answer.nothing.isANo && !TapPermission.Answer.clockStood.isANo && !TapPermission.Answer.yes.isANo)
  }

  @Test func theWordsThatScriptsOnMacsRead() {
    #expect(TapPermission.Answer.flagSaysNo.words == "AXIsProcessTrusted says no")
    #expect(TapPermission.Answer.tapRefused.words == "AXIsProcessTrusted says yes, but macOS refused a tap")
    #expect(TapPermission.Answer.nothing.words == "macOS has not said in time whether Arbor still may")
  }

  @Test func aQuestionPutJustBeforeABeatHasUntilTheNext() {
    // Otherwise a word from macOS a millisecond before a beat would be a false alarm.
    var permission = TapPermission()
    #expect(permission.toldOff(at: 100 + Self.beat - 0.001) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreIn: true) == .nothing)
    #expect(permission.beat(at: 100 + 2 * Self.beat, tapsAreIn: true) == .removeAll(.nothing))
  }

  @Test func aClockThatIsALittleEarlyOrLateChangesNothing() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(permission.beat(at: 100 + Self.beat - 0.01, tapsAreIn: true) == .removeAll(.nothing))
    var late = TapPermission()
    #expect(late.beat(at: 100, tapsAreIn: true) == .ask)
    #expect(late.heard(.yes, at: 100 + Self.beat - 0.01) == .lookAfter)
    #expect(late.beat(at: 100 + Self.beat + 0.06, tapsAreIn: true) == .ask)
  }

  @Test func whileItIsGoneMacOSIsAskedOnceASecondAndAYesBringsTheTapsBack() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreIn: true)
    _ = permission.heard(.flagSaysNo, at: 100)
    // There are no taps, and somebody has to notice that they may return. Nobody waits for it, perhaps for days: a slow clock.
    #expect(permission.clock(tapsAreIn: false) == TapPermission.beatWhileGone)
    for second in 1...10 {
      #expect(permission.beat(at: 100 + Double(second), tapsAreIn: false) == .ask)
      #expect(permission.heard(.flagSaysNo, at: 100 + Double(second)) == .nothing)
    }
    #expect(permission.beat(at: 111, tapsAreIn: false) == .ask)
    #expect(permission.heard(.yes, at: 111) == .comeBack(after: 11, wentFor: .flagSaysNo))
    #expect(permission.mayInstall)
    #expect(permission.clock(tapsAreIn: false) == nil, "until the owners have installed something")
  }

  @Test func whileItIsGoneAWordAboutATapIsNothing() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreIn: true)
    _ = permission.heard(.tapRefused, at: 100)
    #expect(permission.toldOff(at: 100.1) == .nothing)
  }

  @Test func losingItAgainAndAgainIsHarmless() {
    var permission = TapPermission()
    var now = 100.0
    for _ in 0..<5 {
      #expect(permission.beat(at: now, tapsAreIn: true) == .ask)
      #expect(permission.heard(.flagSaysNo, at: now) == .removeAll(.flagSaysNo))
      now += 1
      #expect(permission.beat(at: now, tapsAreIn: false) == .ask)
      #expect(permission.heard(.yes, at: now) == .comeBack(after: 1, wentFor: .flagSaysNo))
      now += Self.beat
    }
  }

  // MARK: A Mac, a millisecond at a time

  /// The taps' thread as `EventTapThread` keeps it, the thread that asks, the main thread, and a macOS that takes the
  /// permission away. Time is counted in whole milliseconds.
  struct Mac {
    /// Who watches over the permission.
    enum Watch {
      /// `TapPermission`, on the taps' own thread.
      case tapThread
      /// As it was: the main thread asks once a second, and waits for the answer.
      case mainThreadOnceASecond
    }

    var watch = Watch.tapThread
    /// Which of four taps are in. Whether one is switched on does not matter: hosted Macs lost keys, which no tap asks for.
    var isIn = [true, true, true, true]
    /// Which of them their owners, on the main thread, believe they have: `GestureTap.tap`, `RectangleFramer.downTap`. An owner
    /// installs only what it believes it has not.
    var ownerHas = [true, true, true, true]
    var permission = TapPermission()
    /// `EventTapThread.clock`: from beat to beat, and when the next is due.
    var clock: (interval: Int, next: Int)?

    // macOS
    var lostAt = Int.max
    var backAt = Int.max
    /// A loss that nobody announces: the flag stays, and a tap is refused.
    var isAnnounced = true
    /// How long a question takes that is put at this time.
    var answerTakes: @Sendable (Int) -> Int = { _ in 1 }
    /// Whether an answer says how things were when the question was put. Otherwise, how they are when it comes.
    var answersAreOld = false
    /// When the answer to the question that is out will be there, and when it was asked for.
    var answerDue: Int?
    var askedAt = 0
    /// By how much the beat due at this time is late: a handler took its time.
    var beatIsLate: @Sendable (Int) -> Int = { _ in 0 }

    // The main thread
    var mainIsBusy: Range<Int> = 0..<0
    var timerIsLate = false
    /// What the tap thread has sent it: the permission is gone (true), or back.
    var mainQueue: [Bool] = []
    var mainThinksItIsGone = false
    var mainHeardAt: [Int] = []

    // What is measured
    /// For how many milliseconds a tap was in though its owner had lost the permission: for as long as that, macOS drops all input.
    var exposed = 0
    var questions = 0
    var falseAlarms: [Double] = []

    func isLost(_ now: Int) -> Bool { now >= lostAt && now < backAt }
    func answer(_ now: Int) -> TapPermission.Answer { !isLost(now) ? .yes : isAnnounced ? .flagSaysNo : .tapRefused }
    var tapsAreIn: Bool { isIn.contains(true) }

    /// `EventTap.install`, which anybody may ask for at any time.
    mutating func install(_ tap: Int, at now: Int) {
      // `CGEvent.tapCreate` is refused once the right is withdrawn, whatever Arbor believes.
      guard permission.mayInstall, !isLost(now) else { return }
      isIn[tap] = true
      keepTheClock(at: now)
    }

    /// `GestureTap.update`, `RectangleFramer.update`: on the main thread.
    mutating func ownersUpdate(at now: Int) {
      for tap in isIn.indices where !ownerHas[tap] {
        install(tap, at: now)
        ownerHas[tap] = isIn[tap]
      }
    }

    /// `EventTapThread.keepTheClock`.
    mutating func keepTheClock(at now: Int) {
      let interval = permission.clock(tapsAreIn: tapsAreIn).map { Int(($0 * 1000).rounded()) }
      guard interval != clock?.interval else { return }
      clock = interval.map { ($0, now + $0) }
    }

    /// `EventTapThread.obey`.
    mutating func obey(_ order: Order, at now: Int) {
      switch order {
      case .nothing, .lookAfter:
        break
      case .ask:
        ask(at: now)
      case .removeAll:
        isIn = isIn.map { _ in false }
        mainQueue.append(true)
      case .comeBack(let after, let wentFor):
        if !wentFor.isANo { falseAlarms.append(after) }
        mainQueue.append(false)
      }
      keepTheClock(at: now)
    }

    mutating func ask(at now: Int) {
      questions += 1
      askedAt = now
      answerDue = now + answerTakes(now)
    }

    /// macOS tells a callback that it switched a tap off.
    mutating func tell(at now: Int) {
      obey(permission.toldOff(at: Double(now) / 1000), at: now)
    }

    mutating func pass(_ range: Range<Int>, each: (inout Mac, Int) -> Void = { _, _ in }) {
      for now in range {
        let seconds = Double(now) / 1000
        switch watch {
        case .tapThread:
          if now == 0 { keepTheClock(at: -TapPermissionTests.beatMs) }
          if answerDue == now {
            answerDue = nil
            obey(permission.heard(answer(answersAreOld ? askedAt : now), at: seconds, tapsAreIn: tapsAreIn), at: now)
          }
          if let (interval, due) = clock, now >= due + beatIsLate(due) {
            // The timer keeps its grid, however late a beat was.
            clock = (interval, due + interval)
            obey(permission.beat(at: seconds, tapsAreIn: tapsAreIn), at: now)
          }
          if !mainIsBusy.contains(now) {
            for isGone in mainQueue {
              mainThinksItIsGone = isGone
              mainHeardAt.append(now)
              // `PointerInput.permissionChanged`: the owners forget what is gone, or install what the settings ask for.
              if isGone { ownerHas = ownerHas.map { _ in false } } else { ownersUpdate(at: now) }
            }
            mainQueue = []
          }
        case .mainThreadOnceASecond:
          // The timer fires when the thread is free, and the thread waits for the answer.
          if let due = answerDue {
            if due == now {
              answerDue = nil
              if answer(now) != .yes { isIn = isIn.map { _ in false } }
            }
          } else if now % 1000 == 0 || timerIsLate, tapsAreIn {
            timerIsLate = mainIsBusy.contains(now)
            if !timerIsLate { ask(at: now) }
          }
        }
        each(&self, now)
        if isLost(now), tapsAreIn { exposed += 1 }
      }
    }
  }

  @Test(arguments: [true, false]) func wheneverTheLossComesTheTapsAreOutWithinABeat(isAnnounced: Bool) {
    for lostAt in stride(from: 1000, to: 1000 + Self.beatMs + 10, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.isAnnounced = isAnnounced
      mac.pass(0..<3000)
      #expect(!mac.tapsAreIn)
      #expect(mac.exposed <= Self.beatMs + 1, "lost at \(lostAt): a beat, and the millisecond the answer takes")
    }
  }

  @Test func theControlAsItWasTheHoleWasTheWaitForTheTickOfASecond() {
    // What hosted Macs showed: 85 to 1,046 ms in nine rounds. Without this the net above might hold for any arrangement.
    var worst = 0
    for lostAt in stride(from: 1000, to: 2000, by: 7) {
      var mac = Mac()
      mac.watch = .mainThreadOnceASecond
      mac.lostAt = lostAt
      mac.pass(0..<4000)
      #expect(!mac.tapsAreIn)
      worst = max(worst, mac.exposed)
    }
    #expect(worst > 900)
  }

  @Test func theMainThreadBusyForFiveSecondsKeepsNoTapIn() {
    // It waits for apps: one call can take a second, and a layout is many calls.
    var mac = Mac()
    mac.lostAt = 1010
    mac.mainIsBusy = 1000..<6000
    mac.pass(0..<1300)
    #expect(!mac.tapsAreIn, "gone, and the main thread has not run since before the loss")
    #expect(mac.exposed <= Self.beatMs + 1)
    #expect(!mac.mainThinksItIsGone)
    // Whatever the main thread does with its old idea of things, no tap goes in.
    mac.pass(1300..<5000) { mac, now in if now % 100 == 0 { for tap in mac.isIn.indices { mac.install(tap, at: now) } } }
    #expect(!mac.tapsAreIn)
    #expect(mac.exposed <= Self.beatMs + 1)
    mac.pass(5000..<6100)
    #expect(mac.mainHeardAt == [6000], "it hears as soon as it is free")
    #expect(mac.mainThinksItIsGone)
  }

  @Test func theControlAsItWasTheTapsStayedInForAsLongAsTheMainThreadWasBusy() {
    var mac = Mac()
    mac.watch = .mainThreadOnceASecond
    mac.lostAt = 1010
    mac.mainIsBusy = 1000..<6000
    mac.pass(0..<7000)
    #expect(!mac.tapsAreIn)
    #expect(mac.exposed > 4900)
  }

  @Test(arguments: [20, 60, 100, 140]) func anAnswerThatIsSlowAndOldKeepsTheTapsInForABeatAndItsOwnTime(takes: Int) {
    // The yes to a question put just before the loss comes after it, and is believed: it is the next question that tells.
    for lostAt in stride(from: 1000, to: 1000 + Self.beatMs + 10, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.answersAreOld = true
      mac.answerTakes = { _ in takes }
      mac.pass(0..<3000)
      #expect(!mac.tapsAreIn)
      #expect(mac.exposed <= Self.beatMs + takes, "lost at \(lostAt)")
      #expect(mac.falseAlarms.isEmpty)
    }
  }

  @Test func answersThatTakeNearlyABeatAreNoAlarmOnAnOrdinaryDay() {
    var mac = Mac()
    mac.answerTakes = { _ in Self.beatMs - 10 }
    mac.pass(0..<60_000)
    #expect(mac.isIn.allSatisfy { $0 })
    #expect(mac.mainHeardAt.isEmpty)
  }

  @Test func beatsThatAreLateAreNoAlarmOnAnOrdinaryDay() {
    // Every third beat comes 0.4 of a beat late, and macOS takes a third of a beat to answer.
    var mac = Mac()
    mac.beatIsLate = { ($0 / Self.beatMs) % 3 == 0 ? Self.beatMs * 2 / 5 : 0 }
    mac.answerTakes = { _ in Self.beatMs / 3 }
    mac.pass(0..<60_000)
    #expect(mac.isIn.allSatisfy { $0 })
    #expect(mac.mainHeardAt.isEmpty)
  }

  @Test func theWorstCaseWithoutAnAnswerIsTwoAndAHalfBeats() {
    // A word from macOS has a question put just after the middle between two beats; it is a yes, old, and comes just before the beat after
    // next; the loss comes right behind the question; and the next question hangs.
    var worst = 0
    for toldAt in stride(from: 1000, to: 1000 + Self.beatMs, by: 3) {
      var mac = Mac()
      mac.lostAt = toldAt + 1
      mac.answersAreOld = true
      mac.answerTakes = { $0 == toldAt ? 1000 + 2 * Self.beatMs - 1 - toldAt : $0 > toldAt ? 5000 : 1 }
      mac.pass(0..<toldAt)
      mac.tell(at: toldAt)
      mac.pass(toldAt..<4000)
      #expect(!mac.tapsAreIn)
      worst = max(worst, mac.exposed)
    }
    #expect(worst <= Self.beatMs * 5 / 2)
    #expect(worst > 2 * Self.beatMs, "so the bound is not two beats, and nobody should say so")
  }

  @Test func toldAtTheLossTheTapsAreOutAtOnce() {
    // No Mac has been seen to tell. If one does, the hole is the time the answer takes.
    var mac = Mac()
    mac.lostAt = 1010
    mac.pass(0..<1010)
    mac.tell(at: 1010)
    mac.pass(1010..<2000)
    #expect(mac.exposed <= 1)
  }

  @Test func aQuestionThatHangsForFiveSecondsKeepsNoTapInBeyondTwoBeats() {
    // The privacy daemon is away just when it is asked. Whoever asks waits; the taps do not.
    for lostAt in stride(from: 1000, to: 1000 + Self.beatMs + 10, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.answerTakes = { $0 >= lostAt ? 5000 : 1 }
      mac.pass(0..<2000)
      #expect(!mac.tapsAreIn)
      #expect(mac.exposed <= 2 * Self.beatMs, "lost at \(lostAt)")
      let questions = mac.questions
      mac.pass(2000..<6000)
      #expect(mac.questions == questions, "no second question is sent after one that hangs")
      mac.pass(6000..<9000)
      #expect(!mac.tapsAreIn, "the answer was no")
      #expect(mac.questions > questions, "and from then on macOS is asked whether it is back")
      #expect(mac.falseAlarms.isEmpty)
    }
  }

  @Test func theControlAsItWasAQuestionThatHangsKeptTheTapsInUntilItReturned() {
    var mac = Mac()
    mac.watch = .mainThreadOnceASecond
    mac.lostAt = 1010
    mac.answerTakes = { $0 >= 1010 ? 5000 : 1 }
    mac.pass(0..<8000)
    #expect(mac.exposed > 5000)
  }

  @Test func aQuestionThatHangsWhileThePermissionIsThereIsAFalseAlarmThatMendsItself() {
    // The daemon restarts now and then. The taps are away until it answers, and not a moment longer.
    var mac = Mac()
    let hangsAt = 7 * Self.beatMs
    mac.answerTakes = { $0 == hangsAt ? 2000 : 1 }
    mac.pass(0..<(hangsAt + 1999))
    #expect(!mac.tapsAreIn)
    mac.pass((hangsAt + 1999)..<(hangsAt + 2002))
    #expect(mac.isIn.allSatisfy { $0 }, "back with the answer, not at the next question")
    #expect(mac.falseAlarms.count == 1, "and it can be counted")
    #expect(abs(mac.falseAlarms[0] - Double(hangsAt + 2000 - (hangsAt + Self.beatMs)) / 1000) < 0.001, "with how long it lasted")
    #expect(mac.mainHeardAt == [hangsAt + Self.beatMs, hangsAt + 2000])
    #expect(mac.exposed == 0)
  }

  @Test func itComesBackWithinASecondOfThePermissionAndInOrderHoweverLateTheMainThreadHears() {
    var mac = Mac()
    mac.lostAt = 1010
    mac.backAt = 3010
    mac.mainIsBusy = 1000..<6000
    mac.pass(0..<6100)
    #expect(mac.mainHeardAt == [6000, 6000], "gone, then back")
    #expect(!mac.mainThinksItIsGone)
    #expect(mac.isIn.allSatisfy { $0 })
    #expect(mac.exposed <= Self.beatMs + 1)
    #expect(mac.falseAlarms.isEmpty, "that loss was real")
  }

  @Test func aQuestionAtEveryBeatWhileTapsAreInAndNoneWithout() {
    var mac = Mac()
    mac.pass(0..<10_000)
    #expect(mac.questions == (10_000 - 1) / Self.beatMs + 1)
    var none = Mac()
    none.isIn = []
    none.ownerHas = []
    none.pass(0..<10_000)
    #expect(none.questions == 0)
  }
}

extension TapPermission {
  /// With taps in, as nearly always.
  fileprivate mutating func heard(_ answer: Answer, at now: Double) -> Order { heard(answer, at: now, tapsAreIn: true) }
}
