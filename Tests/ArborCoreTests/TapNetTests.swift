import Testing

@testable import ArborCore

/// The net under the taps' clock. Rule 6: input is never blocked.
@Suite struct TapNetTests {
  @Test func whileTheClockBeatsNothingHappens() {
    var net = TapNet()
    for _ in 0..<100 {
      net.beat()
      net.beat()
      #expect(net.look(tapsAreIn: true) == false)
    }
  }

  @Test func atTheThirdLookWithoutABeatTheClockStands() {
    var net = TapNet()
    net.beat()
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == true)
  }

  @Test func oneBeatInBetweenAndTheCountBeginsAgain() {
    // The thread was busy for a moment: a handler that read the window list, a Mac short of memory.
    var net = TapNet()
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == false)
    net.beat()
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == true)
  }

  @Test func withoutTapsThereIsNoClockAndNothingToSay() {
    var net = TapNet()
    for _ in 0..<10 { #expect(net.look(tapsAreIn: false) == false) }
    // Looks from before the taps came in do not count against them.
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: false) == false)
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == false)
    #expect(net.look(tapsAreIn: true) == true)
  }

  @Test func itSaysSoOnceAndThenCountsAfresh() {
    var net = TapNet()
    for _ in 1..<TapNet.limit { #expect(net.look(tapsAreIn: true) == false) }
    #expect(net.look(tapsAreIn: true) == true)
    #expect(net.look(tapsAreIn: true) == false, "whoever looked has taken the taps out; if some are in again, they have their time")
  }

  @Test func theTapsAreOutWithinOneAndAHalfSecondsOfTheLastBeatWheneverItWas() throws {
    // The mark: input back within 1.5 s with the timer stopped and the thread running. Looks every `pause`, in milliseconds.
    let pause = Int((TapNet.pause * 1000).rounded())
    for lastBeat in stride(from: 0, to: pause, by: 7) {
      var net = TapNet()
      var outAt: Int?
      for now in 0..<5000 where outAt == nil {
        if now <= lastBeat, now % 150 == 0 || now == lastBeat { net.beat() }
        if now % pause == pause - 1, net.look(tapsAreIn: true) { outAt = now }
      }
      let took = try #require(outAt) - lastBeat
      #expect(took <= 3 * pause && took >= 2 * pause, "the last beat at \(lastBeat): \(took) ms")
    }
  }

  @Test func aMacAsleepOrAProcessHaltedIsNoClockThatStands() {
    // Both stop the looks with the beats. Afterwards whichever comes first, one look or one beat, nothing happens.
    var net = TapNet()
    net.beat()
    #expect(net.look(tapsAreIn: true) == false)
    // … an hour passes, of which neither hears …
    #expect(net.look(tapsAreIn: true) == false, "the look came first")
    net.beat()
    #expect(net.look(tapsAreIn: true) == false)
  }
}
