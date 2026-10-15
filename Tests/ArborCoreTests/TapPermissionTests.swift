import Testing

@testable import ArborCore

/// When the event taps let go because Arbor may no longer have them. Rule 6: input is never blocked.
@Suite struct TapPermissionTests {
  typealias Order = TapPermission.Order
  static let beat = TapPermission.beat
  /// The same in the model's milliseconds.
  static let beatMs = Int((TapPermission.beat * 1000).rounded())
  /// How long an answer to a question put at a beat has, with a clock that is on time.
  static let patience = Double(TapPermission.patience) * TapPermission.beat
  static let patienceMs = TapPermission.patience * beatMs

  // MARK: The orders, one by one

  @Test func whileATapIsWantedOnMacOSIsAskedAtEveryBeat() {
    var permission = TapPermission()
    for beat in 0..<8 {
      let now = 100 + Double(beat) * Self.beat
      #expect(permission.beat(at: now, tapsAreWantedOn: true) == .ask)
      #expect(permission.heard(.yes, at: now + 0.001) == .lookAfter)
    }
    #expect(permission.mayInstall)
  }

  @Test func withNoTapWantedOnNobodyIsAskedAndTheClockMayStop() {
    // None of Arbor's keys is down, or every gesture is switched off: no clock and no question.
    var permission = TapPermission()
    #expect(permission.clock(tapsAreWantedOn: false) == nil)
    for beat in 0..<8 { #expect(permission.beat(at: 100 + Double(beat) * Self.beat, tapsAreWantedOn: false) == .nothing) }
    #expect(permission.clock(tapsAreWantedOn: true) == Self.beat)
  }

  @Test(arguments: [TapPermission.Answer.flagSaysNo, .tapRefused]) func oneNoAndAllTapsGo(no: TapPermission.Answer) {
    // `.tapRefused`: the flag says yes but a tap is refused, which is how a loss that nobody announced showed on hosted Macs.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.heard(no, at: 100.001) == .removeAll(no))
    #expect(permission.isGone)
    #expect(!permission.mayInstall, "whoever asks: the main thread may not have heard yet")
  }

  @Test func toldThatATapIsOffMacOSIsAskedAtOnceAndAtANoAllGo() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
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
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.toldOff(at: 100.01) == .nothing)
    #expect(permission.toldOff(at: 100.02) == .nothing)
    #expect(permission.heard(.yes, at: 100.03) == .lookAfter)
    #expect(permission.heard(.flagSaysNo, at: 100.04) == .nothing, "an answer nobody asked for")
    #expect(!permission.isGone)
  }

  @Test func noAnswerInTimeIsANo() {
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true) == .nothing, "it has its time")
    #expect(permission.beat(at: 100 + Self.patience, tapsAreWantedOn: true) == .removeAll(.nothing))
    #expect(!permission.mayInstall)
    // For five seconds nothing comes. No second question is sent after one that hangs.
    for second in 1...5 { #expect(permission.beat(at: 100 + Self.patience + Double(second), tapsAreWantedOn: false) == .nothing) }
    #expect(permission.clock(tapsAreWantedOn: false) == TapPermission.beatWhileGone)
  }

  @Test func ifTheLateAnswerIsYesTheTapsComeBackWithItAndTheOrderSaysThatTheAlarmWasFalse() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreWantedOn: true)
    _ = permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true)
    #expect(permission.beat(at: 100 + Self.patience, tapsAreWantedOn: true) == .removeAll(.nothing))
    #expect(permission.heard(.yes, at: 100.5) == .comeBack(after: 100.5 - (100 + Self.patience), wentFor: .nothing))
    #expect(permission.mayInstall)
  }

  @Test func ifTheLateAnswerIsNoTheyStayAway() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreWantedOn: true)
    _ = permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true)
    #expect(permission.beat(at: 100 + Self.patience, tapsAreWantedOn: true) == .removeAll(.nothing))
    #expect(permission.heard(.flagSaysNo, at: 103) == .nothing)
    #expect(permission.isGone)
    #expect(permission.beat(at: 103.5, tapsAreWantedOn: false) == .ask, "and from now on macOS is asked whether it is back")
    // The loss was real, and is not counted among the false alarms when it is over.
    #expect(permission.heard(.yes, at: 193.5) == .comeBack(after: 193.5 - (100 + Self.patience), wentFor: .flagSaysNo))
  }

  @Test func aNoWhenTheLastTapHasGoneMeanwhileRemovesNothingAndStartsNothing() {
    // A pause, or a setting, took the taps out while the question was out. No line in the log about taps that were not there,
    // and no clock that asks for the sake of taps nobody wants.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.heard(.tapRefused, at: 100.001, tapsAreIn: false) == .nothing)
    #expect(!permission.isGone)
    #expect(permission.clock(tapsAreWantedOn: false) == nil)
  }

  @Test func aBeatThatIsLateDoesNotShortenTheTimeAnAnswerHasBelowABeat() {
    // A handler took its time, so the question went out late. The timer keeps its grid.
    var permission = TapPermission()
    #expect(permission.beat(at: 100 + Self.beat * 0.6, tapsAreWantedOn: true) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true) == .nothing)
    #expect(permission.beat(at: 100 + 2 * Self.beat, tapsAreWantedOn: true) == .removeAll(.nothing), "1.4 beats old")
  }

  @Test func aHaltOrASleepUsesUpNoneOfTheTimeAnAnswerHas() {
    // The process is halted, or the Mac sleeps, with a question out. Whoever asks stands still too. By the clock the first beat afterwards
    // finds a question that is an hour old; it has had no time at all.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.beat(at: 3700, tapsAreWantedOn: true) == .nothing)
    #expect(permission.heard(.yes, at: 3700.0004) == .lookAfter)
    #expect(permission.wantsOn(at: 3700.001) == .ask, "and that yes is as old as its question: nothing goes on by it")
  }

  @Test func theWordsThatScriptsOnMacsRead() {
    #expect(TapPermission.Answer.flagSaysNo.words == "AXIsProcessTrusted says no")
    #expect(TapPermission.Answer.tapRefused.words == "AXIsProcessTrusted says yes, but macOS refused a tap")
    #expect(TapPermission.Answer.nothing.words == "macOS has not said in time whether Arbor still may")
  }

  @Test func aQuestionPutJustBeforeABeatHasAWholeBeatAtTheLeast() {
    // Otherwise a word from macOS a millisecond before a beat would be a false alarm.
    var permission = TapPermission()
    #expect(permission.toldOff(at: 100 + Self.beat - 0.001) == .ask)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true) == .nothing)
    #expect(permission.beat(at: 100 + 2 * Self.beat, tapsAreWantedOn: true) == .removeAll(.nothing))
  }

  @Test func theCountBeginsAgainWithEveryQuestion() {
    var permission = TapPermission()
    for round in 0..<5 {
      let now = 100 + Double(round) * 2 * Self.beat
      #expect(permission.beat(at: now, tapsAreWantedOn: true) == .ask)
      #expect(permission.beat(at: now + Self.beat, tapsAreWantedOn: true) == .nothing, "slow, and in time")
      #expect(permission.heard(.yes, at: now + Self.beat * 1.5) == .lookAfter)
    }
  }

  // MARK: No tap goes on but by a fresh yes

  @Test func whoeverWantsATapOnAsksFirstAndItGoesOnAtTheYes() {
    // ⌃⌥ go down after an hour in which nobody asked anything.
    var permission = TapPermission()
    #expect(permission.wantsOn(at: 3700) == .ask)
    #expect(permission.heard(.yes, at: 3700.0004) == .lookAfter)
  }

  @Test func atANoItNeverGoesOnAndAllTapsGo() {
    // The right went while every tap was off, and nobody noticed, because nobody needed to.
    var permission = TapPermission()
    #expect(permission.wantsOn(at: 3700) == .ask)
    #expect(permission.heard(.tapRefused, at: 3700.0004) == .removeAll(.tapRefused))
    #expect(permission.wantsOn(at: 3700.1) == .nothing, "and whoever asks again while it is gone gets nothing")
  }

  @Test func withAYesOfAMomentAgoItGoesOnAtOnce() {
    // The tap on drags and mouse-ups is wanted from inside the callback of the tap on mouse-downs, and has to be on before the next
    // event. That tap is on, so the clock beats, so the yes is fresh.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.heard(.yes, at: 100.001) == .lookAfter)
    #expect(permission.wantsOn(at: 100 + Self.beat * 0.9) == .lookAfter)
    #expect(permission.wantsOn(at: 100 + TapPermission.freshness) == .lookAfter)
    #expect(permission.wantsOn(at: 100 + TapPermission.freshness + 0.001) == .ask, "too old")
  }

  @Test func aYesIsAsOldAsItsQuestion() {
    // The answer says how things were at some moment since the question was put. The earliest counts.
    var permission = TapPermission()
    #expect(permission.beat(at: 100, tapsAreWantedOn: true) == .ask)
    #expect(permission.heard(.yes, at: 100 + Self.patience * 0.9) == .lookAfter)
    #expect(permission.wantsOn(at: 100 + TapPermission.freshness + 0.001) == .ask)
  }

  @Test func aTapThatMacOSHasJustLetInMayGoOn() {
    // To install one is the very thing the question tries.
    var permission = TapPermission()
    permission.installed(at: 100)
    #expect(permission.wantsOn(at: 100.0001) == .lookAfter)
  }

  @Test func wantedWhileAQuestionIsOutItWaitsForThatAnswer() {
    var permission = TapPermission()
    #expect(permission.toldOff(at: 100) == .ask)
    #expect(permission.wantsOn(at: 100.0001) == .nothing, "there is never more than one question")
    #expect(permission.heard(.yes, at: 100.0005) == .lookAfter)
  }

  @Test func wantedAndNoAnswerComesAllTapsGo() {
    // It is wanted on, so the clock beats, though it is not on yet.
    var permission = TapPermission()
    #expect(permission.wantsOn(at: 100) == .ask)
    #expect(permission.clock(tapsAreWantedOn: true) == Self.beat)
    #expect(permission.beat(at: 100 + Self.beat, tapsAreWantedOn: true) == .nothing)
    #expect(permission.beat(at: 100 + 2 * Self.beat, tapsAreWantedOn: true) == .removeAll(.nothing))
  }

  @Test func whileItIsGoneMacOSIsAskedOnceASecondAndAYesBringsTheTapsBack() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreWantedOn: true)
    _ = permission.heard(.flagSaysNo, at: 100)
    // There are no taps, and somebody has to notice that they may return. Nobody waits for it, perhaps for days: a slow clock.
    #expect(permission.clock(tapsAreWantedOn: false) == TapPermission.beatWhileGone)
    for second in 1...10 {
      #expect(permission.beat(at: 100 + Double(second), tapsAreWantedOn: false) == .ask)
      #expect(permission.heard(.flagSaysNo, at: 100 + Double(second)) == .nothing)
    }
    #expect(permission.beat(at: 111, tapsAreWantedOn: false) == .ask)
    #expect(permission.heard(.yes, at: 111) == .comeBack(after: 11, wentFor: .flagSaysNo))
    #expect(permission.mayInstall)
    #expect(permission.clock(tapsAreWantedOn: false) == nil, "until the owners have installed something")
  }

  @Test func whileItIsGoneAWordAboutATapIsNothing() {
    var permission = TapPermission()
    _ = permission.beat(at: 100, tapsAreWantedOn: true)
    _ = permission.heard(.tapRefused, at: 100)
    #expect(permission.toldOff(at: 100.1) == .nothing)
  }

  @Test func losingItAgainAndAgainIsHarmless() {
    var permission = TapPermission()
    var now = 100.0
    for _ in 0..<5 {
      #expect(permission.beat(at: now, tapsAreWantedOn: true) == .ask)
      #expect(permission.heard(.flagSaysNo, at: now) == .removeAll(.flagSaysNo))
      now += 1
      #expect(permission.beat(at: now, tapsAreWantedOn: false) == .ask)
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
    /// False: as it was, for a control.
    var asksBeforeSwitchingOn = true
    /// Which of four taps are in.
    var isIn = [true, true, true, true]
    /// Which of them somebody wants on (`!EventTap.isPaused`): Arbor's keys are down, a press is being followed. Unless a test
    /// says otherwise the keys are down all the time.
    var isWanted = [true, true, true, true]
    /// Which of them are switched on, by the window server's list.
    var isOn = [true, true, true, true]
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
    /// For how many milliseconds a tap was switched on though its owner had lost the right to it: for as long as that any event it
    /// asks for costs the Mac its input. One that is in but off starts nothing.
    var exposed = 0
    /// How often a tap was switched on after the right had gone, which starts the drop that instant.
    var switchedOnWithoutTheRight = 0
    var questions = 0
    var falseAlarms: [Double] = []

    func isLost(_ now: Int) -> Bool { now >= lostAt && now < backAt }
    func answer(_ now: Int) -> TapPermission.Answer { !isLost(now) ? .yes : isAnnounced ? .flagSaysNo : .tapRefused }
    var tapsAreIn: Bool { isIn.contains(true) }
    var tapsAreWantedOn: Bool { isIn.indices.contains { isIn[$0] && isWanted[$0] } }
    var tapsAreOn: Bool { isIn.indices.contains { isIn[$0] && isOn[$0] } }

    /// `EventTap.install`, which anybody may ask for at any time.
    mutating func install(_ tap: Int, at now: Int) {
      // `CGEvent.tapCreate` is refused once the right is withdrawn, whatever Arbor believes.
      guard permission.mayInstall, !isLost(now) else { return }
      isIn[tap] = true
      isOn[tap] = false
      permission.installed(at: Double(now) / 1000)
      if isWanted[tap] { obey(permission.wantsOn(at: Double(now) / 1000), at: now) }
      keepTheClock(at: now)
    }

    /// `EventTap.resume` and `pause`: a key monitor on the main thread, or a handler on the taps' own.
    mutating func want(_ tap: Int, _ on: Bool, at now: Int) {
      guard isIn[tap], isWanted[tap] != on else { return }
      isWanted[tap] = on
      if !on {
        isOn[tap] = false
      } else if asksBeforeSwitchingOn {
        obey(permission.wantsOn(at: Double(now) / 1000), at: now)
      } else {
        isOn[tap] = true
        if isLost(now) { switchedOnWithoutTheRight += 1 }
      }
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
      let interval = permission.clock(tapsAreWantedOn: tapsAreWantedOn).map { Int(($0 * 1000).rounded()) }
      guard interval != clock?.interval else { return }
      clock = interval.map { ($0, now + $0) }
    }

    /// `EventTapThread.obey`.
    mutating func obey(_ order: Order, at now: Int) {
      switch order {
      case .nothing:
        break
      case .lookAfter:
        // `CGEvent.tapEnable` goes through whether or not the right is there.
        for tap in isIn.indices where isIn[tap] && isWanted[tap] && !isOn[tap] {
          isOn[tap] = true
          if isLost(now) { switchedOnWithoutTheRight += 1 }
        }
      case .ask:
        ask(at: now)
      case .removeAll:
        isIn = isIn.map { _ in false }
        isOn = isOn.map { _ in false }
        mainQueue.append(true)
      case .comeBack(let after, let wentFor):
        if wentFor == .nothing { falseAlarms.append(after) }
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
            obey(permission.beat(at: seconds, tapsAreWantedOn: tapsAreWantedOn), at: now)
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
              if answer(now) != .yes { (isIn, isOn) = (isIn.map { _ in false }, isOn.map { _ in false }) }
            }
          } else if now % 1000 == 0 || timerIsLate, tapsAreIn {
            timerIsLate = mainIsBusy.contains(now)
            if !timerIsLate { ask(at: now) }
          }
        }
        each(&self, now)
        if isLost(now), tapsAreOn { exposed += 1 }
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

  @Test(arguments: [10, 30, 60, 90]) func anAnswerThatIsSlowAndOldKeepsTheTapsOnUntilTheNextBeatAndForItsOwnTime(takes: Int) {
    // The yes to a question put just before the loss comes after it, and is believed: it is the next question that tells.
    for lostAt in stride(from: 1000, to: 1000 + Self.beatMs + 10, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.answersAreOld = true
      mac.answerTakes = { _ in takes }
      mac.pass(0..<3000)
      #expect(!mac.tapsAreIn)
      // No question is put while one is out, so the next goes out at the first beat after the answer.
      #expect(mac.exposed <= (takes / Self.beatMs + 1) * Self.beatMs + takes, "lost at \(lostAt)")
      #expect(mac.falseAlarms.isEmpty)
    }
  }

  @Test func answersThatTakeNearlyAsLongAsTheyMayAreNoAlarmOnAnOrdinaryDay() {
    var mac = Mac()
    mac.answerTakes = { _ in Self.patienceMs - 10 }
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

  @Test func theWorstCaseWithoutAnAnswerIsFourBeats() {
    // A word from macOS has a question put between two beats; the answer is a yes, old, and comes as late as it may; the loss comes right
    // behind the question; and the next question hangs. Searched for, not worked out.
    var worst = 0
    for toldAt in stride(from: 1000, to: 1000 + Self.beatMs, by: 3) {
      for takes in stride(from: Self.patienceMs - 20, to: Self.patienceMs + Self.beatMs + 10, by: 3) {
        var mac = Mac()
        mac.lostAt = toldAt + 1
        mac.answersAreOld = true
        mac.answerTakes = { $0 == toldAt ? takes : $0 > toldAt ? 5000 : 1 }
        mac.pass(0..<toldAt)
        guard mac.answerDue == nil else { continue }
        mac.tell(at: toldAt)
        mac.pass(toldAt..<1800)
        #expect(!mac.tapsAreOn)
        worst = max(worst, mac.exposed)
      }
    }
    #expect(worst <= 4 * Self.beatMs)
    #expect(worst > 3 * Self.beatMs, "so the bound is not three beats, and nobody should say so")
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

  @Test func aQuestionThatHangsForFiveSecondsKeepsNoTapOnBeyondThreeBeats() {
    // The privacy daemon is away just when it is asked. Whoever asks waits; the taps do not.
    for lostAt in stride(from: 1000, to: 1000 + Self.beatMs + 10, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.answerTakes = { $0 >= lostAt ? 5000 : 1 }
      mac.pass(0..<2000)
      #expect(!mac.tapsAreIn)
      #expect(mac.exposed <= Self.beatMs + Self.patienceMs, "lost at \(lostAt)")
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
    #expect(abs(mac.falseAlarms[0] - Double(2000 - Self.patienceMs) / 1000) < 0.001, "with how long it lasted")
    #expect(mac.mainHeardAt == [hangsAt + Self.patienceMs, hangsAt + 2000])
    #expect(mac.isOn.allSatisfy { $0 }, "the keys are still down")
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

  @Test func aQuestionAtEveryBeatWhileATapIsWantedOnAndNoneOtherwise() {
    var mac = Mac()
    mac.pass(0..<10_000)
    #expect(mac.questions == (10_000 - 1) / Self.beatMs + 1)
    var none = Mac()
    (none.isIn, none.isWanted, none.isOn, none.ownerHas) = ([], [], [], [])
    none.pass(0..<10_000)
    #expect(none.questions == 0)
    var idle = Mac.withTheKeysUp
    idle.pass(0..<10_000)
    #expect(idle.questions == 0, "four taps in, none of Arbor's keys down")
    #expect(idle.clock == nil)
  }

  // MARK: Only while Arbor's keys are down

  @Test func theKeysGoDownAndTheTapIsOnAMillisecondLater() {
    var mac = Mac.withTheKeysUp
    mac.pass(0..<1000)
    mac.want(0, true, at: 1000)
    #expect(!mac.isOn[0], "not before macOS has said yes")
    mac.pass(1000..<1002)
    #expect(mac.isOn == [true, false, false, false])
    #expect(mac.clock?.interval == Self.beatMs)
    mac.pass(1002..<3000)
    mac.want(0, false, at: 3000)
    #expect(!mac.tapsAreOn)
    #expect(mac.clock == nil)
    let questions = mac.questions
    mac.pass(3000..<60_000)
    #expect(mac.questions == questions, "the keys are up: nobody is asked anything")
  }

  @Test func theRightGoesWhileTheKeysAreUpAndNoTapIsEverOnWithoutIt() {
    var mac = Mac.withTheKeysUp
    mac.lostAt = 1000
    mac.pass(0..<5000)
    #expect(mac.questions == 0 && mac.tapsAreIn, "nobody has noticed, and nobody needed to: taps that are off start nothing")
    mac.want(0, true, at: 5000)
    mac.pass(5000..<5100)
    #expect(!mac.tapsAreIn, "the question that goes before every switching on was answered no")
    #expect(mac.switchedOnWithoutTheRight == 0)
    #expect(mac.exposed == 0)
  }

  @Test func theControlSwitchedOnWithoutAskingTheDropBeginsThatInstant() {
    // As it was: `resume` switched the tap on there and then. On a hosted Mac that went through, and 430 events were lost.
    var mac = Mac.withTheKeysUp
    mac.asksBeforeSwitchingOn = false
    mac.lostAt = 1000
    mac.pass(0..<5000)
    mac.want(0, true, at: 5000)
    mac.pass(5000..<5100)
    #expect(mac.switchedOnWithoutTheRight == 1)
    #expect(mac.exposed > 0)
  }

  @Test func aYesOfAMomentAgoCanBeOvertakenAndThenTheClockIsTheNet() {
    // The keys come up, the right goes, the keys go down again, all within two beats. The one way a tap goes on without the right.
    for lostAt in stride(from: 1001, to: 1000 + 2 * Self.beatMs, by: 7) {
      var mac = Mac()
      mac.lostAt = lostAt
      mac.pass(0..<1000)
      for tap in mac.isIn.indices { mac.want(tap, false, at: 1000) }
      mac.pass(1000..<(lostAt + 1))
      mac.want(0, true, at: lostAt + 1)
      mac.pass((lostAt + 1)..<2000)
      #expect(!mac.tapsAreIn)
      #expect(mac.exposed <= Self.beatMs + 1, "lost at \(lostAt)")
    }
  }

  @Test func aTapWantedFromTheCallbackOfOneThatIsOnIsOnBeforeTheNextEvent() {
    // A ⌃⌥ press is held back, and the tap on drags and mouse-ups has to see its release, which a script posts in the same millisecond.
    var mac = Mac.withTheKeysUp
    mac.want(0, true, at: 0)
    mac.pass(0..<1234)
    mac.want(1, true, at: 1234)
    #expect(mac.isOn[1], "at once: the clock beats, so the yes is fresh")
  }
}

extension TapPermissionTests.Mac {
  /// Four taps in, none wanted on, none on: an ordinary moment of an ordinary day.
  static var withTheKeysUp: Self {
    var mac = Self()
    mac.isWanted = mac.isWanted.map { _ in false }
    mac.isOn = mac.isOn.map { _ in false }
    return mac
  }
}

extension TapPermission {
  /// With taps in, as nearly always.
  fileprivate mutating func heard(_ answer: Answer, at now: Double) -> Order { heard(answer, at: now, tapsAreIn: true) }
}
