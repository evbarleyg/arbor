import CoreGraphics

/// Measures one motion of a stage from its log (`StageLog`) and says where it falls short of what motion in Arbor is to be.
///
/// What it goes by is what the app saw: the places Core Animation gave for the stand-ins at the ticks of a display link on the main
/// thread. A gap here is a stretch in which the main thread did not get its tick. The window server, which draws the motion, may have
/// drawn every frame of it all the same; only a film of the screen says. So nothing is a finding that a busy main thread explains.
public enum StageJudge {
  public struct Limits: Equatable, Sendable {
    /// How long a motion is to last, in seconds: as long as Arbor's motions did while they shipped switched on, which is what
    /// docs/VIABLE.md's rubric is written for. Not the default, which is no motion at all.
    public var duration = Settings.usualMotionDuration
    /// Each motion is held to what its own plan says instead, for a run with another `animationDuration`.
    public var holdsToThePlan = false
    public var durationTolerance = 0.06
    /// How many points a stand-in may go back on its road. None, but places are rounded to hundredths.
    public var backwards = 0.1
    /// How many points a stand-in may go beyond the end of its road, or leave it sideways.
    public var overshoot = 2.0
    /// The longest time between two frames, in seconds: two ticks at 60 a second.
    public var gap = 0.034
    /// How many points a stand-in may be from where it starts at its first frame and from where it ends at its last; from its real
    /// window there, where it shows as that window and the trace says where that is; and, when it is retargeted, from where it was.
    public var handover = 2.0
    /// A stage that is up for less than this, in seconds, is a flash.
    public var shortestUp = 0.1
    /// How long after the end of the motion a stage may still be up, in seconds.
    public var longestAfter = 0.5

    public init() {}

    /// Every limit, by the name `arbor-sim stage-judge` takes for it.
    private static var table: [(name: String, limit: WritableKeyPath<Limits, Double>)] {
      [
        ("duration", \.duration), ("durationTolerance", \.durationTolerance), ("backwards", \.backwards), ("overshoot", \.overshoot),
        ("gap", \.gap), ("handover", \.handover), ("shortestUp", \.shortestUp), ("longestAfter", \.longestAfter),
      ]
    }

    public static var names: [String] { table.map(\.name) }

    /// Sets a limit by its name. `duration` also takes `planned`. False for a name or a value that means nothing.
    public mutating func set(_ name: String, to text: String) -> Bool {
      guard let limit = Self.table.first(where: { $0.name == name })?.limit else { return false }
      if name == "duration" { holdsToThePlan = text == "planned" }
      if holdsToThePlan, name == "duration" { return true }
      guard let value = Double(text), value.isFinite, value >= 0 else { return false }
      self[keyPath: limit] = value
      return true
    }
  }

  public enum Row: String, Equatable, Sendable {
    /// The motion took too long or was over too soon.
    case duration
    /// A stand-in went back on its road.
    case backwards
    /// A stand-in went beyond the end of its road, or off it.
    case overshoot
    /// Too long between two frames, with nothing in the trace that kept the main thread.
    case gap
    /// At its first frame a stand-in was not where it starts, or not where its window was.
    case start
    /// At its last frame a stand-in was not where it ends, or not where its window is.
    case end
    /// A stand-in that was given a new road did not carry on from where it was.
    case jump
    /// The stage was up too short a time to be anything but a flash.
    case flash
    /// The stage stayed up after the motion.
    case leftUp
    /// A road, or all of them, without a frame to judge by.
    case frames
  }

  public struct Finding: Equatable, Sendable, CustomStringConvertible {
    public var row: Row
    public var text: String

    public var description: String { "\(row.rawValue): \(text)" }
  }

  /// What was measured. Times in seconds, distances in points.
  public struct Verdict: Equatable, Sendable {
    public var standIns = 0
    public var legs = 0
    public var frames = 0
    /// What the last leg's plan says.
    public var planned = 0.0
    /// How long the last leg's motion lasts: no shorter than the one and no longer than the other (`timed`). Nil if it cannot be told.
    public var lasted: ClosedRange<Double>?
    /// The stage was taken down in mid-motion, as a click does. How long it lasts and where it ends are then not judged.
    public var cutShort = false
    public var largestGap = 0.0
    public var backwards = 0.0
    public var overshoot = 0.0
    public var startOff: Double?
    public var endOff: Double?
    public var up: Double?
    /// From the end of the motion to `down`.
    public var after: Double?
    public var findings: [Finding] = []
    /// What whoever reads the verdict should know and is no fault of the motion's, as far as the log can tell.
    public var notes: [String] = []

    public var ok: Bool { findings.isEmpty }
  }

  public static func judge(_ motion: StageLog.Motion, limits: Limits = Limits()) -> Verdict {
    var verdict = Verdict()
    guard let first = motion.legs.first, let last = motion.legs.last else { return verdict }
    func find(_ row: Row, _ text: String) { verdict.findings.append(Finding(row: row, text: text)) }
    verdict.legs = motion.legs.count
    verdict.standIns = Set(motion.legs.flatMap { $0.plan.roads.map(\.window) }).count
    verdict.planned = last.plan.duration
    verdict.cutShort = motion.down != nil && motion.lift == nil

    // The frames, whichever leg they belong to: a stage is looked at from going up to coming down.
    let ticks = motion.legs.flatMap(\.frames)
    verdict.frames = ticks.count
    var idle = (count: 0, longest: 0.0, began: 0.0)
    var busy = (count: 0, longest: 0.0, began: 0.0, lines: 0)
    for (earlier, later) in zip(ticks, ticks.dropFirst()) {
      let gap = later.t - earlier.t
      verdict.largestGap = max(verdict.largestGap, gap)
      // Times have tenths of a millisecond.
      guard gap > limits.gap + 0.00005 else { continue }
      // A call to a window is written down when it returns.
      let lines = motion.otherLines.filter { $0 > earlier.t && $0 <= later.t }.count
      if lines == 0 {
        idle.count += 1
        if gap > idle.longest { (idle.longest, idle.began) = (gap, earlier.t) }
      } else {
        busy.count += 1
        if gap > busy.longest { (busy.longest, busy.began, busy.lines) = (gap, earlier.t, lines) }
      }
    }
    func gaps(_ count: Int, _ longest: Double, _ began: Double) -> String {
      (count == 1 ? "" : "\(count) gaps, the longest ") + "\(ms(longest)) without a frame from \(seconds(began)) on (limit \(ms(limits.gap)))"
    }
    if idle.count > 0 { find(.gap, gaps(idle.count, idle.longest, idle.began)) }
    if busy.count > 0 {
      verdict.notes.append(
        "gap: \(gaps(busy.count, busy.longest, busy.began)), with \(busy.lines) other line\(busy.lines == 1 ? "" : "s") of the trace in it: "
          + "the main thread was at work, which need not show on the screen")
    }

    // Every road, edge by edge: each edge of a stand-in travels straight from where it starts to where it ends.
    for leg in motion.legs {
      if leg.frames.isEmpty {
        find(.frames, "no frame was logged of the roads that begin at \(seconds(leg.began))")
        continue
      }
      for road in leg.plan.roads {
        let (from, to) = (edges(road.from.frame), edges(road.to.frame))
        var worstBack = (points: 0.0, t: 0.0)
        var worstOver = (points: 0.0, t: 0.0)
        var before: [Double]?
        for (t, place) in drawn(road.window, in: leg) {
          let now = edges(place.frame)
          for edge in 0..<4 {
            let direction = to[edge] > from[edge] ? 1.0 : to[edge] < from[edge] ? -1.0 : 0
            let over = direction == 0 ? abs(now[edge] - to[edge]) : (now[edge] - to[edge]) * direction
            if over > worstOver.points { worstOver = (over, t) }
            // Coming back from beyond the end belongs to the overshoot, which has a limit of its own.
            func onTheRoad(_ value: Double) -> Double { direction > 0 ? min(value, to[edge]) : max(value, to[edge]) }
            if let before, (onTheRoad(before[edge]) - onTheRoad(now[edge])) * direction > worstBack.points {
              worstBack = ((onTheRoad(before[edge]) - onTheRoad(now[edge])) * direction, t)
            }
          }
          before = now
        }
        if before == nil { find(.frames, "\(road.window) has a road from \(seconds(leg.began)) on and is in no frame") }
        verdict.backwards = max(verdict.backwards, worstBack.points)
        verdict.overshoot = max(verdict.overshoot, worstOver.points)
        if worstBack.points > limits.backwards {
          find(.backwards, "\(road.window) went back \(points(worstBack.points)) at \(seconds(worstBack.t))")
        }
        if worstOver.points > limits.overshoot {
          find(
            .overshoot,
            "\(road.window) was \(points(worstOver.points)) beyond its road at \(seconds(worstOver.t)) (limit \(points(limits.overshoot)))")
        }
      }
    }

    // From one set of roads to the next.
    for (before, after) in zip(motion.legs, motion.legs.dropFirst()) {
      for road in after.plan.roads {
        guard let apart = jump(of: road, from: before, at: after.began), apart > limits.handover else { continue }
        find(.jump, "\(road.window) was \(points(apart)) from where it had got to when it was retargeted at \(seconds(after.began)) (limit \(points(limits.handover)))")
      }
    }

    // How long it lasts.
    verdict.lasted = timed(last)
    if let lasted = verdict.lasted, !verdict.cutShort {
      let wanted = limits.holdsToThePlan ? last.plan.duration : limits.duration
      // When it ended is known to lie between two ticks. Only if all of that span is outside is the motion at fault.
      if lasted.upperBound < wanted - limits.durationTolerance - 0.00005 || lasted.lowerBound > wanted + limits.durationTolerance + 0.00005 {
        find(.duration, "lasts \(span(lasted)), not \(ms(wanted)) ± \(ms(limits.durationTolerance))")
      }
    }

    // Taking over from the real windows, and handing back to them.
    verdict.startOff = handover(
      first, \.from, \.first, real: motion.beganInMidMotion ? [:] : motion.realAtStart, limit: limits.handover, "first", "starts", "was"
    ) { find(.start, $0) }
    if !verdict.cutShort {
      verdict.endOff = handover(last, \.to, \.last, real: motion.realAtEnd, limit: limits.handover, "last", "ends", "is") { find(.end, $0) }
    }

    // How long the stage was there. The later the motion may have ended, the less the stage has outstayed it.
    var motionEnded = last.began + last.plan.duration
    if let latest = verdict.lasted?.upperBound, latest.isFinite { motionEnded = last.began + latest }
    if verdict.cutShort, let down = motion.down { motionEnded = down }
    if let down = motion.down {
      verdict.up = down - motion.began
      verdict.after = max(down - motionEnded, 0)
      if down - motion.began < limits.shortestUp - 0.00005 {
        find(.flash, "up for \(ms(down - motion.began)) only (limit \(ms(limits.shortestUp)))")
      }
      if down - motionEnded > limits.longestAfter + 0.00005 {
        find(.leftUp, "came down \(ms(down - motionEnded)) after the motion (limit \(ms(limits.longestAfter)))")
      }
    } else {
      // Also when the log ends sooner than the limit: whoever records has to wait and see the stage come down.
      find(.leftUp, "still up when the log ends, \(ms(max(motion.logEnds - motionEnded, 0))) after the motion")
    }
    return verdict
  }

  // MARK: The measures

  /// How long a leg's motion lasts, from the stand-in with the longest way to go.
  ///
  /// Not by when it stops moving. The curve settles so gently, and places are rounded, that a stand-in with a few points to go
  /// looks finished long before its time is up. What can be told is when it had all but the last of its road behind it: all but a
  /// hundredth, or but a twentieth of a point if that is more. The curve says after which share of the time that is due,
  /// and so how long the whole lasts. The moment lies between the last tick at which it was certainly not yet there and the first at which
  /// it certainly was, rounding allowed for, so the answer lies between two times; the second is infinite if the stand-in never
  /// got that far. Nil if no stand-in has a point to go.
  static func timed(_ leg: StageLog.Leg) -> ClosedRange<Double>? {
    var longest: (way: Double, from: Double, edge: Int, places: [(t: Double, place: StageLog.Place)])?
    for road in leg.plan.roads {
      let (from, to) = (edges(road.from.frame), edges(road.to.frame))
      for edge in 0..<4 where abs(to[edge] - from[edge]) > abs(longest?.way ?? 0) {
        let places = drawn(road.window, in: leg)
        if !places.isEmpty { longest = (to[edge] - from[edge], from[edge], edge, places) }
      }
    }
    guard let longest, abs(longest.way) >= 1 else { return nil }
    let mark = 1 - max(0.01, 0.05 / abs(longest.way))
    let due = Transition.share(ofProgress: mark)
    // The place, the start and the end are each half a hundredth of a point from what is written.
    let doubt = 0.015 / abs(longest.way)
    var notYet = leg.began
    for (t, place) in longest.places {
      let done = (edges(place.frame)[longest.edge] - longest.from) / longest.way
      if done - doubt >= mark { return range(max(notYet - leg.began, 0) / due, max(t - leg.began, 0) / due) }
      if done + doubt < mark { notYet = t }
    }
    return range(max(notYet - leg.began, 0) / due, .infinity)
  }

  /// How far the start of a new road is from where its stand-in can have been at that moment: between where the last frame of the roads
  /// before shows it and where the curve takes it from there in the time since. Nil for a stand-in that is new or was not drawn.
  static func jump(of road: StageLog.Road, from before: StageLog.Leg, at t: Double) -> Double? {
    guard let old = before.plan.roads.first(where: { $0.window == road.window }), let last = drawn(road.window, in: before).last
    else { return nil }
    let (from, to, seen, next) = (edges(old.from.frame), edges(old.to.frame), edges(last.place.frame), edges(road.from.frame))
    let longest = (0..<4).max { abs(to[$0] - from[$0]) < abs(to[$1] - from[$1]) } ?? 0
    let way = to[longest] - from[longest]
    let done = way == 0 ? 1 : (seen[longest] - from[longest]) / way
    let due = Transition.progress(after: Transition.share(ofProgress: done) + max(t - last.t, 0) / before.plan.duration)
    return (0..<4).map { edge in
      let furthest = from[edge] + (to[edge] - from[edge]) * due
      return max(min(seen[edge], furthest) - next[edge], next[edge] - max(seen[edge], furthest), 0)
    }.max()
  }

  /// How far the stand-ins are from one end of their roads at the frame nearest to it, and from their real windows where they show as
  /// those. The greatest distance, or nil without a frame.
  private static func handover(
    _ leg: StageLog.Leg, _ end: KeyPath<StageLog.Road, StageLog.Place>, _ nearest: KeyPath<[(t: Double, place: StageLog.Place)], (t: Double, place: StageLog.Place)?>,
    real: [WindowID: CGRect], limit: Double, _ which: String, _ verb: String, _ be: String, find: (String) -> Void
  ) -> Double? {
    var worst: Double?
    for road in leg.plan.roads {
      // One that is in no frame has been found already.
      guard let sample = drawn(road.window, in: leg)[keyPath: nearest] else { continue }
      let place = road[keyPath: end]
      let drawn = edges(sample.place.frame)
      let off = distance(drawn, edges(place.frame))
      worst = max(worst ?? 0, off)
      if off > limit { find("at its \(which) frame \(road.window) is \(points(off)) from where it \(verb) (limit \(points(limit)))") }
      // A cover, a stand-in that cannot be seen and one beyond the display stand over no window.
      guard !place.isCover, place.opacity > 0.995, place.frame.overlaps(leg.plan.frame), let window = real[road.window] else { continue }
      let apart = distance(drawn, edges(window))
      worst = max(worst ?? 0, apart)
      if apart > limit {
        find("at its \(which) frame \(road.window) is \(points(apart)) from where its window \(be) (limit \(points(limit)))")
      }
    }
    return worst
  }

  /// Where and when a leg's frames show one stand-in.
  private static func drawn(_ window: WindowID, in leg: StageLog.Leg) -> [(t: Double, place: StageLog.Place)] {
    leg.frames.compactMap { tick in tick.samples.first { $0.window == window }.map { (tick.t, $0.place) } }
  }

  private static func edges(_ rect: CGRect) -> [Double] { [rect.minX, rect.minY, rect.maxX, rect.maxY].map { Double($0) } }

  /// How far the edge that is furthest off is off.
  private static func distance(_ a: [Double], _ b: [Double]) -> Double { zip(a, b).map { abs($0 - $1) }.max() ?? 0 }

  /// A damaged trace can have times in any order, and `a...b` traps unless a ≤ b.
  private static func range(_ a: Double, _ b: Double) -> ClosedRange<Double>? { a <= b ? a...b : nil }

  // MARK: In words

  fileprivate static func ms(_ seconds: Double) -> String { number(seconds * 1000, decimals: 1) + " ms" }
  /// `3.214 s`: a time as `arbor-sim replay` prints it, so that it can be found there.
  fileprivate static func seconds(_ t: Double) -> String { number(t, decimals: 3, all: true) + " s" }
  fileprivate static func points(_ value: Double) -> String { number(value, decimals: 2) + " pt" }

  fileprivate static func span(_ range: ClosedRange<Double>) -> String {
    range.upperBound.isFinite ? "\(number(range.lowerBound * 1000, decimals: 1)) to \(ms(range.upperBound))" : "over \(ms(range.lowerBound))"
  }

  /// With so many decimals, `all` of them or without zeros at the end. The times of a damaged trace can be anything, and a number too large
  /// for an `Int` must not end the judge.
  private static func number(_ value: Double, decimals: Int, all: Bool = false) -> String {
    let scale = [1.0, 10, 100, 1000][decimals]
    guard abs(value) < 1e12 else { return "\(value)" }
    let scaled = Int((abs(value) * scale).rounded())
    var fraction = String(scaled % Int(scale))
    fraction = String(repeating: "0", count: decimals - fraction.count) + fraction
    if !all { while fraction.hasSuffix("0") { fraction.removeLast() } }
    return (value < 0 && scaled != 0 ? "-" : "") + String(scaled / Int(scale)) + (fraction.isEmpty ? "" : "." + fraction)
  }
}

extension StageJudge.Verdict {
  /// Everything that was measured in one line, ending in `ok` or in the number of findings, and in the number of notes if there are any.
  public func summary(of motion: StageLog.Motion) -> String {
    var parts = ["\(standIns) stand-in\(standIns == 1 ? "" : "s")"]
    if legs > 1 { parts.append("retargeted \(legs - 1) time\(legs == 2 ? "" : "s")") }
    if cutShort {
      parts.append("cut short")
    } else {
      parts.append((lasted.map { "lasts \(StageJudge.span($0))" } ?? "no road long enough to time") + ", \(StageJudge.ms(planned)) planned")
    }
    parts.append("\(frames) frames")
    parts.append("largest gap \(StageJudge.ms(largestGap))")
    parts.append("back \(StageJudge.points(backwards))")
    parts.append("beyond \(StageJudge.points(overshoot))")
    if let startOff { parts.append("first frame \(StageJudge.points(startOff)) off") }
    if let endOff { parts.append("last frame \(StageJudge.points(endOff)) off") }
    if let up { parts.append("up \(StageJudge.ms(up))") }
    if let after { parts.append("down \(StageJudge.ms(after)) after the motion") }
    return "line \(motion.number), \(StageJudge.seconds(motion.began)), \(StageLog.text(motion.display)): " + parts.joined(separator: ", ") + ": "
      + (ok ? "ok" : "\(findings.count) finding\(findings.count == 1 ? "" : "s")")
      + (notes.isEmpty ? "" : ", \(notes.count) note\(notes.count == 1 ? "" : "s")")
  }
}

extension StageJudge {
  /// Every motion in a trace, judged: one line each, its findings and notes under it, and a last line that sums up. Not `ok` either if a
  /// line of the stage's cannot be used, or if there is no motion at all: a run that was to show motion and shows none has not passed.
  public static func report(on trace: Trace, limits: Limits = Limits()) -> (lines: [String], ok: Bool) {
    let reading = StageLog.read(trace)
    var lines: [String] = []
    var (faulty, notes) = (0, 0)
    for motion in reading.motions {
      let verdict = judge(motion, limits: limits)
      lines.append(verdict.summary(of: motion))
      lines += verdict.findings.map { "  ✘ \($0)" } + verdict.notes.map { "  · \($0)" }
      if !verdict.ok { faulty += 1 }
      notes += verdict.notes.count
    }
    lines += reading.problems.map { "✘ \($0)" }
    guard !reading.motions.isEmpty else {
      return (lines + ["✘ no motion: no stage went up while this trace was recorded"], false)
    }
    let count = reading.motions.count
    lines.append(
      "\(count) motion\(count == 1 ? "" : "s"), \(faulty == 0 ? "none" : String(faulty)) with findings"
        + (notes == 0 ? "" : ", \(notes) note\(notes == 1 ? "" : "s")"))
    return (lines, faulty == 0 && reading.problems.isEmpty)
  }
}
