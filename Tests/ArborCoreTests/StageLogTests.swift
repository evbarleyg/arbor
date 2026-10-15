import ArborCore
import CoreGraphics
import Testing

private let main = DisplayID("main")
private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
private typealias Timed = (t: Double, text: String)

private func between(_ a: CGRect, _ b: CGRect, _ p: Double) -> CGRect {
  func mix(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * CGFloat(p) }
  return CGRect(x: mix(a.minX, b.minX), y: mix(a.minY, b.minY), width: mix(a.width, b.width), height: mix(a.height, b.height))
}

private func plan(_ roads: [StageLog.Road], duration: Double = 0.46) -> StageLog.Plan {
  StageLog.Plan(display: main, frame: screen, duration: duration, roads: roads)
}

/// The frames a stage that does everything right logs for `roads`: one as the stand-ins set off at `start`, then sixty a second
/// `until` so many seconds later. The display does not wait for the stage: its first tick comes `phase` seconds after the start.
private func frames(
  _ roads: [StageLog.Road], from start: Double, duration: Double = 0.46, until: Double, hz: Double = 60, phase: Double = 0
) -> [Timed] {
  ([0] + stride(from: phase > 0 ? phase : 1 / hz, through: until, by: 1 / hz)).map { elapsed in
    let p = Transition.progress(after: elapsed / duration)
    return (start + elapsed, StageLog.Line.frame(main, roads.map { StageLog.Sample($0.window, between($0.from.frame, $0.to.frame, p)) }).text)
  }
}

/// A whole motion as a stage that does everything right logs it: up at 1 s, lifted when the time is up, down 0.08 s later.
private func goodMotion(_ roads: [StageLog.Road], duration: Double = 0.46, hz: Double = 60, phase: Double = 0) -> [Timed] {
  let all = frames(roads, from: 1, duration: duration, until: duration + 0.08, hz: hz, phase: phase)
  var log: [Timed] = [(1, StageLog.Line.up(plan(roads, duration: duration)).text)]
  log += all.filter { $0.t <= 1 + duration }
  log.append((1 + duration, "stage lift dmain"))
  log += all.filter { $0.t > 1 + duration }
  log.append((1 + duration + 0.08, "stage down dmain"))
  return log
}

/// The beginning of a motion: up at 1 s, and the frames of so many seconds.
private func motionBegun(_ roads: [StageLog.Road], until: Double) -> [Timed] {
  var log: [Timed] = [(1, StageLog.Line.up(plan(roads)).text)]
  log += frames(roads, from: 1, until: until)
  return log
}

private func road(_ window: UInt32, _ from: CGRect, _ to: CGRect) -> StageLog.Road {
  StageLog.Road(WindowID(window), from: StageLog.Place(from), to: StageLog.Place(to))
}

/// A window that grows to the right, and one that slides out past the right edge.
private let two = [
  road(7, CGRect(x: 12, y: 37, width: 464, height: 851), CGRect(x: 12, y: 37, width: 1416, height: 851)),
  road(9, CGRect(x: 488, y: 37, width: 940, height: 851), CGRect(x: 1452, y: 37, width: 940, height: 851)),
]

private func judged(_ log: [Timed], limits: StageJudge.Limits = StageJudge.Limits()) -> StageJudge.Verdict {
  let reading = StageLog.read(log)
  #expect(reading.problems == [])
  #expect(reading.motions.count == 1)
  return StageJudge.judge(reading.motions[0], limits: limits)
}

private func rows(_ verdict: StageJudge.Verdict) -> [StageJudge.Row] { verdict.findings.map(\.row) }

/// `log` with the `index`-th of its frames drawn somewhere else.
private func redrawn(_ log: [Timed], frame index: Int, _ samples: [StageLog.Sample]) -> [Timed] {
  var log = log
  let places = log.indices.filter { log[$0].text.hasPrefix("stage frame") }
  log[places[index]].text = StageLog.Line.frame(main, samples).text
  return log
}

@Suite struct StageLogTests {
  // MARK: The lines

  @Test func theLinesAreWrittenAsTheDocumentationSays() {
    let transition = Transition(
      display: main, frame: screen, duration: 0.46,
      items: [
        Transition.Item(
          window: WindowID(7), from: CGRect(x: 12, y: 37, width: 464, height: 851),
          to: CGRect(x: 12, y: 37, width: 1416.004, height: 851), pid: 412, bundleID: "com.example.secret"),
        Transition.Item(
          window: WindowID(9), from: CGRect(x: -488.5, y: 37.25, width: 940, height: 851),
          to: CGRect(x: 100, y: 700, width: 120, height: 90.129), fromLook: .picture, toLook: .cover, fromOpacity: 0, toOpacity: 1),
        // The stage does not play what is not finite, so the log does not plan it.
        Transition.Item(window: WindowID(11), from: CGRect(x: CGFloat.infinity, y: 0, width: 1, height: 1), to: .zero),
      ])
    #expect(
      StageLog.Line.began(transition, carryingOnFrom: nil).text
        == "stage up dmain 0,0,1440,900 0.46 w7 12,37,464,851,1 12,37,1416,851,1 w9 -488.5,37.25,940,851,0 100,700,120,90.13,1,cover")
    // On a stage that is up, a stand-in carries on from where it is drawn. One that is new starts where the plan says.
    let now = [StageLog.Sample(WindowID(7), CGRect(x: 12, y: 37, width: 900.5, height: 851), opacity: 0.5)]
    #expect(
      StageLog.Line.began(transition, carryingOnFrom: now).text
        == "stage retargeted dmain 0,0,1440,900 0.46 w7 12,37,900.5,851,0.5 12,37,1416,851,1 "
        + "w9 -488.5,37.25,940,851,0 100,700,120,90.13,1,cover")
    #expect(StageLog.Line.frame(main, now).text == "stage frame dmain w7 12,37,900.5,851,0.5")
    #expect(StageLog.Line.frame(main, []).text == "stage frame dmain")
    #expect(StageLog.Line.lift(main).text == "stage lift dmain")
    #expect(StageLog.Line.down(DisplayID("9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21")).text == "stage down d9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21")
  }

  @Test func numbersAreRoundedToHundredths() {
    func written(_ value: CGFloat) -> String {
      String(StageLog.Line.frame(main, [StageLog.Sample(WindowID(1), CGRect(x: value, y: 0, width: 1, height: 1))]).text.dropFirst(21).prefix { $0 != "," })
    }
    #expect(written(12) == "12")
    #expect(written(12.5) == "12.5")
    #expect(written(12.05) == "12.05")
    #expect(written(12.996) == "13")
    #expect(written(-0.25) == "-0.25")
    #expect(written(-0.001) == "0")
    #expect(written(.nan) == "0")
    #expect(written(-.infinity) == "0")
  }

  @Test func everyLineReadsBackAsItWasWritten() {
    let cover = StageLog.Road(
      WindowID(4_294_967_295), from: StageLog.Place(CGRect(x: -3000.25, y: 0.5, width: 10, height: 20), opacity: 0.25, isCover: true),
      to: StageLog.Place(CGRect(x: 0, y: 0, width: 0, height: 0), opacity: 0))
    let lines: [StageLog.Line] = [
      .up(plan(two + [cover])), .up(plan([])), .retargeted(plan(two, duration: 1.2)),
      .frame(main, [StageLog.Sample(WindowID(7), CGRect(x: 1.01, y: -2.5, width: 3, height: 4), opacity: 0.33)]), .frame(main, []),
      .lift(DisplayID("display-69734662")), .down(main),
    ]
    for line in lines { #expect(StageLog.Line(text: line.text) == line, "\(line.text)") }
  }

  @Test func whatIsNotOneOfTheLinesIsNotRead() {
    for text in [
      "", "stage", "stage up", "stage up dmain", "stage up dmain 0,0,1440,900", "stage up d 0,0,1440,900 0.46", "stage up main 0,0,1440,900 0.46",
      "stage up dmain 0,0,1440 0.46", "stage up dmain 0,0,1440,900 soon", "stage up dmain 0,0,1440,900 0.46 w7",
      "stage up dmain 0,0,1440,900 0.46 w7 1,2,3,4,1", "stage up dmain 0,0,1440,900 0.46 7 1,2,3,4,1 1,2,3,4,1",
      "stage up dmain 0,0,1440,900 0.46 w7 1,2,3,4 1,2,3,4,1", "stage up dmain 0,0,1440,900 0.46 w7 1,2,3,4,1,card 1,2,3,4,1",
      "stage frame dmain w7", "stage frame dmain w7 1,2,3,4,", "stage frame dmain w7 1,2,3,nan,1", "stage frame dmain w7 1,2,3,4,1,cover",
      "stage frame dmain  w7 1,2,3,4,1", "stage frame dmain wx 1,2,3,4,1", "stage lift dmain now", "stage down", "stage sideways dmain",
      "AXWindowMoved w7", "leftMouseDown 360,92",
    ] {
      #expect(StageLog.Line(text: text) == nil, "\(text)")
    }
    #expect(StageLog.claims("stage sideways dmain"))
    #expect(!StageLog.claims("AXWindowMoved w7"))
  }

  /// A trace never holds a title, and these lines not even the name of an app: there is nothing in them but a few fixed words, the
  /// display's id, numbers of windows and numbers.
  @Test func theLinesHoldNumbersAndFixedWordsOnly() {
    let allowed = /stage (up|retargeted) d[-0-9A-Za-z]+ [-0-9.,]+ [0-9.]+( w[0-9]+ [-0-9.,]+(,cover)? [-0-9.,]+(,cover)?)*/
    let item = Transition.Item(
      window: WindowID(7), from: two[0].from.frame, to: two[0].to.frame, fromLook: .cover, toLook: .cover, pid: 412,
      bundleID: "com.example.secret")
    let transition = Transition(display: main, frame: screen, duration: 0.46, items: [item, item])
    for now in [nil, [StageLog.Sample(WindowID(7), two[0].from.frame)]] {
      let text = StageLog.Line.began(transition, carryingOnFrom: now).text
      #expect(text.wholeMatch(of: allowed) != nil, "\(text)")
    }
    for line in goodMotion(two).dropFirst() {
      #expect(line.text.wholeMatch(of: /stage (frame|lift|down) d[-0-9A-Za-z]+( w[0-9]+ [-0-9.,]+)*/) != nil, "\(line.text)")
    }
  }

  /// Why the lines may go into a trace without being searched for titles and names: there is no text in a line for them to be in. Whoever
  /// gives `StageLog.Line` something that holds a `String` finds out here.
  @Test func aLineHasNoRoomForWords() {
    func strings(in value: Any) -> [String] {
      if let text = value as? String { return [text] }
      return Mirror(reflecting: value).children.flatMap { strings(in: $0.value) }
    }
    let cover = StageLog.Road(WindowID(7), from: StageLog.Place(screen, opacity: 0.5, isCover: true), to: StageLog.Place(screen))
    let lines: [StageLog.Line] = [
      .up(plan([cover])), .retargeted(plan([cover])), .frame(main, [StageLog.Sample(WindowID(7), screen)]), .lift(main), .down(main),
    ]
    for line in lines {
      // The compiler asks for a case that is added here, and so for a line of it above.
      switch line {
      case .up, .retargeted, .frame, .lift, .down: #expect(strings(in: line) == ["main"], "\(line)")
      }
    }
  }

  /// The display's id is in the trace's header as it is. macOS's are UUIDs. Whatever else one is made to hold stays one word, of letters and digits.
  @Test func theDisplaysIdStaysOneWord() {
    for (id, written) in [
      ("main", "dmain"), ("9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21", "d9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21"), ("display-69734662", "ddisplay-69734662"),
      ("", "d_"), ("two words", "dtwo_words"), ("w7 1,2,3,4,1", "dw7_1_2_3_4_1"), ("é\n\"", "d___"),
    ] {
      let line = StageLog.Line.frame(DisplayID(id), [StageLog.Sample(WindowID(7), screen)])
      #expect(line.text == "stage frame \(written) w7 0,0,1440,900,1")
      #expect(StageLog.Line(text: line.text) == .frame(DisplayID(String(written.dropFirst())), [StageLog.Sample(WindowID(7), screen)]))
    }
  }

  /// A fast start and a gentle settle, without overshoot.
  @Test func theCurveGoesFromNoughtToOneAndNeverBack() {
    #expect(Transition.progress(after: -1) == 0)
    #expect(Transition.progress(after: 0) == 0)
    #expect(Transition.progress(after: 1) == 1)
    #expect(Transition.progress(after: 2) == 1)
    let steps = (0...100).map { Transition.progress(after: Double($0) / 100) }
    for (earlier, later) in zip(steps, steps.dropFirst()) { #expect(later > earlier) }
    // Where the parameter is a half: 0.6 · ⅛ + ⅛ of the time, and half of the way.
    #expect(abs(Transition.progress(after: 0.2) - 0.5) < 0.000001)
    // And back.
    #expect(Transition.share(ofProgress: -1) == 0 && Transition.share(ofProgress: 0) == 0)
    #expect(Transition.share(ofProgress: 1) == 1 && Transition.share(ofProgress: 2) == 1)
    for step in 1..<100 { #expect(abs(Transition.share(ofProgress: steps[step]) - Double(step) / 100) < 0.000001) }
    #expect(steps[50] > 0.85)
  }

  // MARK: Motions

  @Test func theStagesOfTwoDisplaysAreToldApart() {
    let reading = StageLog.read([
      (1.0, "stage up dmain 0,0,1440,900 0.46 w7 0,0,100,100,1 200,0,100,100,1"),
      (1.001, "stage up dsecond 1440,0,1280,800 0.46 w9 1500,0,100,100,1 1600,0,100,100,1"),
      (1.002, "stage frame dmain w7 0,0,100,100,1"),
      (1.003, "stage frame dsecond w9 1500,0,100,100,1"),
      (1.46, "stage lift dsecond"),
      (1.47, "stage lift dmain"),
      (1.54, "stage down dmain"),
      (1.55, "stage down dsecond"),
      (2.0, "stage up dmain 0,0,1440,900 0.46 w7 200,0,100,100,1 0,0,100,100,1"),
    ])
    #expect(reading.problems == [])
    #expect(reading.motions.map(\.display) == [main, DisplayID("second"), main])
    #expect(reading.motions.map(\.number) == [1, 2, 9])
    #expect(reading.motions.map(\.lift) == [1.47, 1.46, nil])
    #expect(reading.motions.map(\.down) == [1.54, 1.55, nil])
    #expect(reading.motions.map { $0.legs[0].frames.count } == [1, 1, 0])
    #expect(reading.motions.allSatisfy { $0.logEnds == 2 })
  }

  @Test func whatCannotBeUsedIsSaidAndNotPassedOver() {
    let reading = StageLog.read([
      (0.5, "stage frame dmain w7 0,0,100,100,1"),
      (0.6, "stage down dmain"),
      (1.0, "stage up dmain 0,0,1440,900 0.46 w7 0,0,100,100,1 200,0,100,100,1"),
      (1.1, "stage frame dmain w7 title[1]"),
      (1.2, "stage lift dsecond"),
    ])
    #expect(
      reading.problems == [
        "line 1: no stage is up on that display", "line 2: no stage is up on that display", "line 4: cannot be read",
        "line 5: no stage is up on that display",
      ])
    #expect(reading.motions.count == 1)
  }

  /// Recording began while a stage was up: what is there of its motion is judged from there.
  @Test func aLogThatBeginsInMidMotionBeginsAtTheNextOne() {
    var log = goodMotion(two)
    log[0].text = StageLog.Line.retargeted(plan(two)).text
    let reading = StageLog.read(log)
    #expect(reading.problems == [])
    #expect(reading.motions.count == 1)
    #expect(StageJudge.judge(reading.motions[0]).ok)
    // Its stand-ins start in mid-flight, and the real windows have long been where they end.
    var motion = reading.motions[0]
    motion.realAtStart = [WindowID(7): two[0].to.frame, WindowID(9): two[1].to.frame]
    #expect(StageJudge.judge(motion).ok)
  }
}

@Suite struct StageJudgeTests {
  @Test func aGoodMotionOfEightWindowsHasNoFindings() {
    let eight = (0..<8).map { index in
      let x = CGFloat(index % 4) * 357 + 12
      let y = CGFloat(index / 4) * 431 + 37
      return road(UInt32(101 + index), CGRect(x: x, y: y, width: 345, height: 419), CGRect(x: 1428 - x - 345, y: 468 - y + 37, width: 345, height: 419))
    }
    let verdict = judged(goodMotion(eight))
    #expect(verdict.findings == [])
    #expect(verdict.standIns == 8)
    #expect(verdict.legs == 1)
    #expect(verdict.planned == 0.46)
    // Between two times a tick apart, give or take what the curve makes of a tick.
    #expect(verdict.lasted?.contains(0.46) == true)
    #expect((verdict.lasted.map { $0.upperBound - $0.lowerBound } ?? 1) < 0.021)
    #expect(abs(verdict.largestGap - 1.0 / 60) < 0.001)
    #expect(verdict.backwards == 0)
    #expect(verdict.overshoot == 0)
    #expect(verdict.startOff == 0)
    #expect((verdict.endOff ?? 1) < 0.01)
    #expect(abs((verdict.up ?? 0) - 0.54) < 0.0001)
    #expect((verdict.after ?? 1) < 0.12)
    #expect(!verdict.cutShort)
  }

  /// Written by hand, so that the format is pinned by more than its own writer. A tenth of a second, to keep it short.
  @Test func aLogWrittenByHandIsJudged() {
    var limits = StageJudge.Limits()
    limits.holdsToThePlan = true
    limits.durationTolerance = 0.02
    let verdict = judged(
      [
        (3.2140, "stage up dmain 0,0,1440,900 0.1 w7 0,25,700,875,1 740,25,700,875,1 w9 740,25,700,875,1 1440,25,700,875,1"),
        (3.2141, "stage frame dmain w7 0,25,700,875,1 w9 740,25,700,875,1"),
        (3.2307, "stage frame dmain w7 210.5,25,700,875,1 w9 939.12,25,700,875,1"),
        (3.2474, "stage frame dmain w7 520,25,700,875,1 w9 1231.9,25,700,875,1"),
        (3.2641, "stage frame dmain w7 668.25,25,700,875,1 w9 1372.13,25,700,875,1"),
        (3.2807, "stage frame dmain w7 722,25,700,875,1 w9 1422.97,25,700,875,1"),
        (3.2974, "stage frame dmain w7 738.4,25,700,875,1 w9 1438.49,25,700,875,1"),
        (3.3141, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3145, "stage lift dmain"),
        (3.3307, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3474, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3641, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3807, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3950, "stage frame dmain w7 740,25,700,875,1 w9 1440,25,700,875,1"),
        (3.3951, "stage down dmain"),
      ], limits: limits)
    #expect(verdict.findings == [])
    // w7 has 99 % of its 740 points behind it between the fifth frame and the sixth, which the curve has due after 83.5 % of the time.
    #expect(abs((verdict.lasted?.lowerBound ?? 0) - 0.0667 / 0.8353) < 0.0001)
    #expect(abs((verdict.lasted?.upperBound ?? 0) - 0.0834 / 0.8353) < 0.0001)
    #expect(abs(verdict.largestGap - 0.0167) < 0.00001)
    #expect(abs((verdict.up ?? 0) - 0.1811) < 0.00001)
    #expect(abs((verdict.after ?? 0) - (0.1811 - 0.0834 / 0.8353)) < 0.0001)
  }

  @Test func aStandInThatGoesBackIsFound() {
    // The tenth frame shows w9 where it was three frames earlier.
    let good = goodMotion(two)
    guard case .frame(_, let earlier)? = StageLog.Line(text: good[7].text), case .frame(_, let now)? = StageLog.Line(text: good[10].text)
    else {
      Issue.record("the fixture has changed")
      return
    }
    let verdict = judged(redrawn(good, frame: 9, [now[0], earlier[1]]))
    #expect(rows(verdict) == [.backwards])
    #expect(verdict.findings[0].text.hasPrefix("w9 went back "))
    #expect(verdict.backwards > 100)
  }

  @Test func roundingIsNotGoingBack() {
    let still = road(7, CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 300, y: 0, width: 100, height: 100))
    let good = goodMotion([still])
    let last = StageLog.Sample(WindowID(7), CGRect(x: 299.95, y: 0, width: 100, height: 100))
    #expect(judged(redrawn(good, frame: 28, [last])).ok)
  }

  @Test func overshootingByThreePointsIsFoundAndByTwoIsNot() {
    let good = goodMotion(two)
    func beyond(_ points: CGFloat) -> [StageLog.Sample] {
      [StageLog.Sample(WindowID(7), two[0].to.frame), StageLog.Sample(WindowID(9), two[1].to.frame.offsetBy(dx: points, dy: 0))]
    }
    let verdict = judged(redrawn(good, frame: 28, beyond(3)))
    // Coming back from beyond the end is part of the overshoot. It is not going back on the road.
    #expect(rows(verdict) == [.overshoot])
    #expect(verdict.overshoot == 3)
    #expect(verdict.findings[0].text.hasPrefix("w9 was 3 pt beyond its road at 1.467 s"))
    #expect(judged(redrawn(good, frame: 28, beyond(2))).ok)
  }

  /// An edge that has nowhere to go stays where it is: w7 only grows to the right.
  @Test func leavingTheRoadSidewaysIsFound() {
    let good = goodMotion(two)
    guard case .frame(_, var samples)? = StageLog.Line(text: good[10].text) else { return }
    samples[0].place.frame = samples[0].place.frame.offsetBy(dx: 0, dy: -5)
    let verdict = judged(redrawn(good, frame: 9, samples))
    #expect(rows(verdict) == [.overshoot])
    #expect(verdict.overshoot == 5)
  }

  @Test func aGapOfFiftyMillisecondsIsFound() {
    var log = goodMotion(two)
    log.removeSubrange(11...12)
    let verdict = judged(log)
    #expect(rows(verdict) == [.gap])
    #expect(abs(verdict.largestGap - 0.05) < 0.0001)
    #expect(verdict.findings[0].text == "50 ms without a frame from 1.150 s on (limit 34 ms)")
    // The frames are logged on the main thread. What else the trace holds for that time says what kept it.
    var motion = StageLog.read(log).motions[0]
    motion.otherLines = [1.1, 1.16, 1.17, 1.19, 1.3]
    #expect(StageJudge.judge(motion).findings == [])
    #expect(
      StageJudge.judge(motion).notes == [
        "gap: 50 ms without a frame from 1.150 s on (limit 34 ms), with 3 other lines of the trace in it: "
          + "the main thread was at work, which need not show on the screen"
      ])
    // Two ticks at sixty a second are within the limit.
    log = goodMotion(two)
    log.remove(at: 11)
    #expect(judged(log).ok)
  }

  /// A second command in mid-motion sends the stand-ins back where they came from. That is a new road, which begins where they are.
  @Test func beingRetargetedInMidMotionIsNotGoingBack() {
    let out = frames(two, from: 1, until: 0.2)
    guard case .frame(_, let reached)? = StageLog.Line(text: out[out.count - 1].text) else { return }
    let home = zip(two, reached).map { StageLog.Road($0.window, from: $1.place, to: $0.from) }
    let turned = 1.205
    var log = motionBegun(two, until: 0.2)
    log.append((turned, StageLog.Line.retargeted(plan(home)).text))
    log += frames(home, from: turned, until: 0.46)
    log.append((turned + 0.46, "stage lift dmain"))
    log.append((turned + 0.54, "stage down dmain"))
    var verdict = judged(log)
    #expect(verdict.findings == [])
    #expect(verdict.legs == 2)
    #expect(verdict.backwards == 0)
    // The time that counts is the last road's.
    #expect(verdict.lasted?.contains(0.46) == true)
    #expect(abs((verdict.up ?? 0) - 0.745) < 0.0001)

    // The same frames without the line that says so are a stand-in going back.
    verdict = judged(log.filter { !$0.text.hasPrefix("stage retargeted") })
    #expect(rows(verdict).contains(.backwards))
  }

  @Test func aStageLeftUpIsFound() {
    // It never comes down, and goes on logging frames for a second.
    var log = motionBegun(two, until: 1.5)
    var verdict = judged(log)
    #expect(rows(verdict) == [.leftUp])
    #expect(verdict.up == nil)
    #expect(verdict.findings[0].text.hasPrefix("still up when the log ends, 10"))

    // It comes down, but late.
    log.append((2.51, "stage lift dmain"))
    log.append((2.52, "stage down dmain"))
    verdict = judged(log)
    #expect(rows(verdict) == [.leftUp])
    #expect(verdict.findings[0].text.hasPrefix("came down 10"))

    // The log ends too soon to tell: whoever recorded it did not wait for the stage to come down.
    log = Array(goodMotion(two).prefix { !$0.text.hasPrefix("stage down") })
    #expect(rows(judged(log)) == [.leftUp])
  }

  /// A click takes the stage down at once. How long it would have lasted and where it ended say nothing then.
  @Test func aMotionCutShortIsNotJudgedByItsEnd() {
    let log = motionBegun(two, until: 0.19) + [(1.201, "stage down dmain")]
    let verdict = judged(log)
    #expect(verdict.findings == [])
    #expect(verdict.cutShort)
    #expect(verdict.endOff == nil)
    #expect(verdict.after == 0)
  }

  @Test func aStageThatOnlyFlashesIsFound() {
    let log = motionBegun(two, until: 0.05) + [(1.06, "stage down dmain")]
    let verdict = judged(log)
    #expect(rows(verdict) == [.flash])
    #expect(verdict.findings[0].text == "up for 60 ms only (limit 100 ms)")
  }

  @Test func aMotionThatTakesTooLongOrIsOverTooSoonIsFound() {
    #expect(rows(judged(goodMotion(two, duration: 0.6))) == [.duration])
    #expect(rows(judged(goodMotion(two, duration: 0.3))) == [.duration])
    #expect(judged(goodMotion(two, duration: 0.5)).ok)
    // A run that plays everything slowly is held to what it planned.
    var limits = StageJudge.Limits()
    limits.holdsToThePlan = true
    #expect(judged(goodMotion(two, duration: 1.2), limits: limits).ok)
    // Planned at 0.46 s and played in 0.3.
    var log = goodMotion(two, duration: 0.3)
    log[0].text = StageLog.Line.up(plan(two)).text
    #expect(rows(judged(log, limits: limits)) == [.duration])
  }

  @Test func aFirstOrLastFrameAwayFromTheRoadsEndsIsFound() {
    let good = goodMotion(two)
    let count = good.filter { $0.text.hasPrefix("stage frame") }.count
    func shifted(_ end: KeyPath<StageLog.Road, StageLog.Place>, by points: CGFloat) -> [StageLog.Sample] {
      two.map { StageLog.Sample($0.window, $0[keyPath: end].frame.offsetBy(dx: $0.window == WindowID(9) ? -points : 0, dy: 0)) }
    }
    var verdict = judged(redrawn(good, frame: 0, shifted(\.from, by: 5)))
    #expect(rows(verdict) == [.start])
    #expect(verdict.startOff == 5)
    #expect(verdict.findings[0].text == "at its first frame w9 is 5 pt from where it starts (limit 2 pt)")
    #expect(judged(redrawn(good, frame: 0, shifted(\.from, by: 2))).ok)

    // It stops short of its end, and stays there.
    var short = good
    for index in (count - 8)..<count { short = redrawn(short, frame: index, shifted(\.to, by: 4)) }
    verdict = judged(short)
    #expect(rows(verdict).contains(.end))
    #expect(verdict.endOff == 4)
  }

  /// With a whole trace to go by, the stand-ins are also held against the real windows they take over from and hand over to.
  @Test func aStandInAwayFromItsRealWindowIsFound() {
    var motion = StageLog.read(goodMotion(two)).motions[0]
    motion.realAtStart = [WindowID(7): two[0].from.frame, WindowID(9): two[1].from.frame]
    // w9 ends beyond the display, where no window is: Arbor keeps the real one in its corner.
    motion.realAtEnd = [WindowID(7): two[0].to.frame, WindowID(9): CGRect(x: 1439, y: 899, width: 940, height: 851)]
    #expect(StageJudge.judge(motion).ok)

    // The app did not take the width it was given.
    motion.realAtEnd[WindowID(7)] = CGRect(x: 12, y: 37, width: 1200, height: 851)
    var verdict = StageJudge.judge(motion)
    #expect(rows(verdict) == [.end])
    #expect(verdict.findings[0].text == "at its last frame w7 is 216 pt from where its window is (limit 2 pt)")

    motion.realAtEnd[WindowID(7)] = two[0].to.frame
    motion.realAtStart[WindowID(9)] = two[1].from.frame.offsetBy(dx: 0, dy: 3)
    verdict = StageJudge.judge(motion)
    #expect(rows(verdict) == [.start])
    #expect(verdict.findings[0].text == "at its first frame w9 is 3 pt from where its window was (limit 2 pt)")
  }

  /// A cover stands for a window inside a tile, and a stand-in that cannot be seen for one behind another: the real ones are elsewhere.
  @Test func coversAndWhatCannotBeSeenStandOverNoWindow() {
    let frame = CGRect(x: 100, y: 100, width: 300, height: 200)
    let roads = [
      StageLog.Road(WindowID(7), from: StageLog.Place(frame), to: StageLog.Place(frame.offsetBy(dx: 400, dy: 0), isCover: true)),
      StageLog.Road(WindowID(9), from: StageLog.Place(frame), to: StageLog.Place(frame.offsetBy(dx: 0, dy: 300), opacity: 0)),
    ]
    var motion = StageLog.read(goodMotion(roads)).motions[0]
    motion.realAtEnd = [WindowID(7): CGRect(x: 1439, y: 899, width: 300, height: 200), WindowID(9): frame]
    #expect(StageJudge.judge(motion).ok)
  }

  @Test func aLogWithoutFramesProvesNothing() {
    let verdict = judged([
      (1, StageLog.Line.up(plan(two)).text), (1.46, "stage lift dmain"), (1.54, "stage down dmain"),
    ])
    #expect(rows(verdict) == [.frames])
    #expect(verdict.lasted == nil)
  }

  /// A window that closed in mid-motion is no longer part of the plan. Its stand-in fades away where it is, and is nobody's road.
  @Test func aStandInWithoutARoadIsLeftAlone() {
    let log = goodMotion(two).map { line -> Timed in
      line.text.hasPrefix("stage frame") ? (line.t, line.text + " w5 \(Int(line.t * 1000)),0,10,10,0.5") : line
    }
    let verdict = judged(log)
    #expect(verdict.findings == [])
    #expect(verdict.standIns == 2)
  }

  @Test func everyLimitCanBeSetByItsName() {
    var limits = StageJudge.Limits()
    func set(_ name: String, to text: String) -> Bool { limits.set(name, to: text) }
    for (index, name) in StageJudge.Limits.names.enumerated() { #expect(set(name, to: "\(index + 1)"), "\(name)") }
    var expected = StageJudge.Limits()
    (expected.duration, expected.durationTolerance, expected.backwards, expected.overshoot, expected.gap) = (1, 2, 3, 4, 5)
    (expected.handover, expected.shortestUp, expected.longestAfter) = (6, 7, 8)
    #expect(limits == expected)
    #expect(!set("patience", to: "1"))
    #expect(!set("gap", to: "planned"))
    #expect(!set("gap", to: "-1"))
    #expect(!set("gap", to: "nan"))
    #expect(limits == expected)
    #expect(set("duration", to: "planned"))
    #expect(limits.holdsToThePlan)
    #expect(set("duration", to: "0.3"))
    #expect(!limits.holdsToThePlan && limits.duration == 0.3)
  }

  /// The numbers motion is held to, where a change to them shows.
  @Test func theLimitsAreTheOnesThatWereSet() {
    let limits = StageJudge.Limits()
    #expect(limits.duration == 0.46)
    #expect(limits.duration == Settings.usualMotionDuration)
    #expect(!limits.holdsToThePlan)
    #expect(limits.durationTolerance == 0.06)
    #expect(limits.overshoot == 2)
    #expect(limits.gap == 0.034)
    #expect(limits.handover == 2)
    #expect(limits.shortestUp == 0.1)
    #expect(limits.longestAfter == 0.5)
  }

  @Test func theSummaryIsOneLine() {
    let motion = StageLog.read(goodMotion(two)).motions[0]
    let summary = StageJudge.judge(motion).summary(of: motion)
    #expect(!summary.contains("\n"))
    #expect(summary.hasPrefix("line 1, 1.000 s, dmain: 2 stand-ins, lasts 4"))
    #expect(summary.contains(" ms, 460 ms planned, 33 frames, largest gap 16.7 ms, back 0 pt, beyond 0 pt, first frame 0 pt off, last frame 0 pt off, up 540 ms, down "))
    #expect(summary.hasSuffix(" after the motion: ok"))
  }
}

/// Faults a review found in the judge: each would have given a false verdict on a faultless run, or passed a faulty one.
@Suite struct StageJudgeReviewTests {
  private func slide(_ points: CGFloat) -> [StageLog.Road] {
    [road(7, CGRect(x: 100, y: 100, width: 400, height: 300), CGRect(x: 100 + points, y: 100, width: 400, height: 300))]
  }

  /// The curve settles gently and places are rounded, so a short road looks finished long before its time is up. A stage goes up for
  /// anything over a point.
  @Test(arguments: [60.0, 120.0]) func aPerfectMotionOnAShortRoadIsNotOverTooSoon(hz: Double) {
    for points in [1.2, 1.5, 2, 3, 5, 8, 13, 40, 200, 1400] as [CGFloat] {
      for phase in [0, 0.001, 0.004, 0.007] {
        // Also at the edges of what is allowed.
        for duration in [0.4, 0.46, 0.52] {
          let verdict = judged(goodMotion(slide(points), duration: duration, hz: hz, phase: phase))
          #expect(verdict.findings == [], "\(points) pt in \(duration) s at \(hz) Hz, first tick after \(phase) s")
          #expect(verdict.lasted?.contains(duration) == true, "\(points) pt in \(duration) s at \(hz) Hz, first tick after \(phase) s: \(String(describing: verdict.lasted))")
        }
      }
    }
  }

  /// Under a point there is nothing to time, and the line says so.
  @Test func aMotionInWhichNothingHasAPointToGoIsNotTimed() {
    let log = goodMotion(slide(0.6))
    let verdict = judged(log)
    #expect(verdict.findings == [])
    #expect(verdict.lasted == nil)
    #expect(verdict.summary(of: StageLog.read(log).motions[0]).contains("no road long enough to time, 460 ms planned"))
  }

  @Test(arguments: [60.0, 120.0]) func aShortRoadTakenTooFastOrTooSlowlyIsStillFound(hz: Double) {
    for points in [2, 5, 40, 1400] as [CGFloat] {
      for duration in [0.3, 0.62] {
        let verdict = judged(goodMotion(slide(points), duration: duration, hz: hz))
        #expect(verdict.findings.map(\.row.rawValue) == ["duration"], "\(points) pt in \(duration) s at \(hz) Hz")
      }
    }
  }

  /// Real traces hold single calls to windows of 50 and 117 ms. While one lasts, the main thread logs no frame; the window server draws on.
  @Test func aGapWhileTheMainThreadWasAtWorkIsNoFinding() {
    var log = goodMotion(two)
    log.removeSubrange(2...8)
    var motion = StageLog.read(log).motions[0]
    #expect(!StageJudge.judge(motion).ok)
    motion.otherLines = [1.117]
    #expect(StageJudge.judge(motion).ok)
    // Work before or after the gap does not excuse it.
    motion.otherLines = [1.0, 1.14]
    #expect(StageJudge.judge(motion).findings.map(\.row.rawValue) == ["gap"])
  }

  /// A long gap that is excused must not hide a shorter one that is not.
  @Test func anExcusedGapDoesNotHideAnother() {
    var log = goodMotion(two)
    log.removeSubrange(15...17)
    log.removeSubrange(2...8)
    var motion = StageLog.read(log).motions[0]
    motion.otherLines = [1.117]
    #expect(StageJudge.judge(motion).findings.map(\.row.rawValue) == ["gap"])
  }

  /// When the motion ended is only known to lie between two ticks. If the main thread stalls across the end, that is a long while.
  @Test func aStallAcrossTheEndOfTheMotionIsNoFalseDuration() {
    var log = frames(two, from: 1, until: 0.7).filter { $0.t < 1.37 || $0.t > 1.56 }
    log.insert((1, StageLog.Line.up(plan(two)).text), at: 0)
    log.append((1.701, "stage lift dmain"))
    log.append((1.781, "stage down dmain"))
    var motion = StageLog.read(log).motions[0]
    motion.otherLines = [1.55]
    #expect(StageJudge.judge(motion).findings == [])
  }

  /// The fault retargeting is most likely to have: the stand-in does not carry on from where it is, but snaps to where it was going.
  @Test func aStandInThatJumpsAtARetargetIsFound() {
    var log = motionBegun(two, until: 0.1)
    let home = two.map { StageLog.Road($0.window, from: $0.to, to: $0.from) }
    log.append((1.105, StageLog.Line.retargeted(plan(home)).text))
    log += frames(home, from: 1.105, until: 0.54)
    log.append((1.565, "stage lift dmain"))
    log.append((1.645, "stage down dmain"))
    log.sort { $0.t < $1.t }
    let verdict = judged(log)
    #expect(Set(verdict.findings.map(\.row.rawValue)) == ["jump"])
    #expect(verdict.findings.count == 2)
  }

  /// Carrying on from where it is, whenever the second command comes and however long after the last frame.
  @Test func anHonestRetargetIsNoJump() {
    for turned in stride(from: 0.004, through: 0.5, by: 0.007) {
      for stall in [0.0, 0.12] where stall < turned {
        var log = motionBegun(two, until: turned - stall)
        let p = Transition.progress(after: turned / 0.46)
        let home = two.map { StageLog.Road($0.window, from: StageLog.Place(between($0.from.frame, $0.to.frame, p)), to: $0.from) }
        log.append((1 + turned, StageLog.Line.retargeted(plan(home)).text))
        log += frames(home, from: 1 + turned, until: 0.46)
        log.append((1 + turned + 0.46, "stage lift dmain"))
        log.append((1 + turned + 0.54, "stage down dmain"))
        var motion = StageLog.read(log).motions[0]
        motion.otherLines = [1 + turned - 0.001]
        #expect(StageJudge.judge(motion).findings == [], "turned after \(turned) s, \(stall) s after the last frame")
      }
    }
  }

  @Test func aRoadThatIsNeverDrawnIsFound() {
    let log = goodMotion(two).map { line -> Timed in
      guard case .frame(let display, let samples)? = StageLog.Line(text: line.text) else { return line }
      return (line.t, StageLog.Line.frame(display, samples.filter { $0.window == WindowID(7) }).text)
    }
    let verdict = judged(log)
    #expect(verdict.findings.map(\.row.rawValue) == ["frames"])
    #expect(verdict.findings.first?.text.contains("w9") == true)
  }

  /// Without a frame of the first roads nobody knows how the stage took over from the windows.
  @Test func aFirstLegWithoutAFrameIsFound() {
    var log = goodMotion(two)
    log[0].text = StageLog.Line.retargeted(plan(two)).text
    log.insert((0.9, StageLog.Line.up(plan(two)).text), at: 0)
    #expect(judged(log).findings.map(\.row.rawValue) == ["frames"])
  }

  /// A damaged trace ends in a finding or in a line that cannot be read, never in a crash.
  @Test func absurdNumbersDoNotCrashTheReaderOrTheJudge() {
    let numbers = ["0", "-1", "1e22", "-1e22", "1e308", "-1e308", "1e-320", "9223372036854775807", "nan", "inf", "", "0x1p1000"]
    let times = [0, -1, 1e22, -1e22, 1e308, -1e308, 5e-324, .greatestFiniteMagnitude]
    var judgedMotions = 0
    for (index, n) in numbers.enumerated() {
      for t in times {
        let other = numbers[(index + 5) % numbers.count]
        let reading = StageLog.read([
          (t, "stage up dmain \(n),0,1440,\(other) \(n) w7 \(n),0,\(other),10,1 0,\(n),10,\(other),\(n)"),
          (t, "stage frame dmain w7 \(n),\(other),10,10,1"),
          (t + 0.1, "stage up dmain 0,0,1440,900 \(n) w7 0,0,10,10,1 500,0,10,10,1"),
          (t * 2, "stage frame dmain w7 \(n),0,10,10,\(other)"),
          (-t, "stage retargeted dmain 0,0,1440,900 0.46 w7 \(other),0,10,10,1 \(n),0,10,10,1"),
          (t, "stage frame dmain w7 \(other),0,\(n),10,1"),
          (t, "stage lift dmain"),
          (t / 3, "stage down dmain"),
          // Lines that can be read, at times that cannot be meant.
          (t, "stage up dsecond 0,0,1440,900 0.46 w7 0,0,10,10,1 500,0,10,10,1 w9 0,0,10,10,1 0,0,10,10,1"),
          (t * 2, "stage frame dsecond w7 100,0,10,10,1 w9 0,0,10,10,1"),
          (-t, "stage frame dsecond w7 499,0,10,10,1 w9 0,0,10,10,1"),
          (t / 2, "stage retargeted dsecond 0,0,1440,900 0 w7 499,0,10,10,1 0,0,10,10,1"),
          (t, "stage frame dsecond w7 0,0,10,10,1"),
          (-t * 3, "stage lift dsecond"),
          (t + 1, "stage down dsecond"),
        ])
        for motion in reading.motions {
          let verdict = StageJudge.judge(motion)
          #expect(!verdict.summary(of: motion).isEmpty)
          #expect(!verdict.findings.map(\.description).contains(""))
          judgedMotions += 1
        }
      }
    }
    #expect(judgedMotions >= numbers.count * times.count)
    #expect(StageLog.read([]).motions.isEmpty)
    // What no screen has is not read at all.
    #expect(StageLog.Line(text: "stage frame dmain w7 1e22,0,10,10,1") == nil)
    #expect(StageLog.Line(text: "stage up dmain 0,0,1440,900 -1") == nil)
    #expect(StageLog.Line(text: "stage up dmain 0,0,1440,900 1e9") == nil)
  }
}
