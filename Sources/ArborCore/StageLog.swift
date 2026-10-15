import CoreGraphics

/// The stage's log of its own frames (docs/features/F02-animated-transitions.md, "How motion is measured").
///
/// Nobody who judges Arbor's motion need sit in front of it: while a trace is recorded, the stage writes down what it was
/// asked to play and, at every tick of the display, where each stand-in is. The lines travel as `raw` lines of the trace
/// (docs/TRACES.md), stamped with its time, which has tenths of a millisecond:
///
///     stage up dmain 0,0,1440,900 0.46 w7 12,37,464,851,1 12,37,1416,851,1 w9 488,37,940,851,1 1452,37,940,851,1
///     stage frame dmain w7 12,37,470.25,851,1 w9 494.2,37,940,851,1
///     stage retargeted dmain 0,0,1440,900 0.46 w7 12,37,900.5,851,1 12,37,464,851,1
///     stage lift dmain
///     stage down dmain
///
/// After `d` comes the display's id. `up` and `retargeted` go on with the stage's frame, the seconds the motion is to take, and
/// for each stand-in its window's number, where it starts and where it is to end: its road. A place is `x,y,width,height,opacity`
/// in global coordinates (origin top-left, y down), rounded to hundredths as everywhere in a trace, with `,cover` after it where the
/// stand-in shows as its app's colour and icon. A `frame` has each stand-in's number and the place it is drawn at.
///
/// Numbers and these few words are all there is: no title, no app, no name of a space can get in, because nothing here takes a text. The
/// one exception is the display's id, which stands in the trace's header as it is; of it only letters, digits, `-` and `_` are written. So
/// the lines need not be searched for titles and names as free text is, and are not (`TraceRecorder.stage`): a space named `1` would cost them their numbers.
public enum StageLog {
  /// Where a stand-in is, or is to be.
  public struct Place: Equatable, Sendable {
    /// Global coordinates.
    public var frame: CGRect
    public var opacity: Double
    /// Drawn as the app's colour and icon: the real window is not what it stands over.
    public var isCover: Bool

    public init(_ frame: CGRect, opacity: Double = 1, isCover: Bool = false) {
      self.frame = frame
      self.opacity = opacity
      self.isCover = isCover
    }
  }

  /// One stand-in's way through one motion.
  public struct Road: Equatable, Sendable {
    public var window: WindowID
    public var from: Place
    public var to: Place

    public init(_ window: WindowID, from: Place, to: Place) {
      self.window = window
      self.from = from
      self.to = to
    }
  }

  /// Where one stand-in was drawn at one tick.
  public struct Sample: Equatable, Sendable {
    public var window: WindowID
    public var place: Place

    public init(_ window: WindowID, _ frame: CGRect, opacity: Double = 1) {
      self.window = window
      place = Place(frame, opacity: opacity)
    }
  }

  /// What a stage was asked to play.
  public struct Plan: Equatable, Sendable {
    public var display: DisplayID
    /// The display's frame, which the stage covers.
    public var frame: CGRect
    /// Seconds.
    public var duration: Double
    public var roads: [Road]

    public init(display: DisplayID, frame: CGRect, duration: Double, roads: [Road]) {
      self.display = display
      self.frame = frame
      self.duration = duration
      self.roads = roads
    }
  }

  public enum Line: Equatable, Sendable {
    /// The stage covers its display and the stand-ins are on their way.
    case up(Plan)
    /// A stage that was up already has been given another motion. New roads begin where the stand-ins are.
    case retargeted(Plan)
    case frame(DisplayID, [Sample])
    /// The motion is over and the stage begins to fade.
    case lift(DisplayID)
    /// The stage is off the screen.
    case down(DisplayID)
  }

  /// Whether a `raw` line of a trace is meant to be one of the stage's, readable or not.
  public static func claims(_ text: String) -> Bool { text.hasPrefix("stage ") }
}

// MARK: Writing

extension StageLog.Line {
  /// The line for a motion that has just begun. `now` is nil for a stage that has just gone up. On one that was up already it is
  /// where the stand-ins are drawn at this moment, which is where they carry on from, whatever the plan took for their start.
  public static func began(_ transition: Transition, carryingOnFrom now: [StageLog.Sample]?) -> StageLog.Line {
    var drawn: [WindowID: StageLog.Place] = [:]
    for sample in now ?? [] { drawn[sample.window] = sample.place }
    // As the stage does: a frame that is not finite is not played.
    let roads = transition.items.filter { $0.from.isFinite && $0.to.isFinite }.map { item in
      var from = StageLog.Place(item.from, opacity: item.fromOpacity, isCover: item.fromLook == .cover)
      if let place = drawn[item.window] { (from.frame, from.opacity) = (place.frame, place.opacity) }
      return StageLog.Road(
        item.window, from: from, to: StageLog.Place(item.to, opacity: item.toOpacity, isCover: item.toLook == .cover))
    }
    let plan = StageLog.Plan(display: transition.display, frame: transition.frame, duration: transition.duration, roads: roads)
    return now == nil ? .up(plan) : .retargeted(plan)
  }

  /// What is to be played, for a line that begins a motion.
  public var plan: StageLog.Plan? {
    switch self {
    case .up(let plan), .retargeted(let plan): plan
    default: nil
    }
  }

  public var text: String {
    func began(_ word: String, _ plan: StageLog.Plan) -> String {
      (["stage \(word) \(StageLog.text(plan.display)) \(StageLog.text(plan.frame)) \(StageLog.text(plan.duration))"]
        + plan.roads.map { "\($0.window) \($0.from.text) \($0.to.text)" }).joined(separator: " ")
    }
    switch self {
    case .up(let plan): return began("up", plan)
    case .retargeted(let plan): return began("retargeted", plan)
    case .frame(let display, let samples):
      return (["stage frame \(StageLog.text(display))"] + samples.map { "\($0.window) \($0.place.text)" }).joined(separator: " ")
    case .lift(let display): return "stage lift \(StageLog.text(display))"
    case .down(let display): return "stage down \(StageLog.text(display))"
    }
  }
}

extension StageLog.Place {
  var text: String { "\(StageLog.text(frame)),\(StageLog.text(opacity))" + (isCover ? ",cover" : "") }
}

extension StageLog {
  /// `d` and the id. macOS's ids are UUIDs; whatever else a `DisplayID` may be made to hold does not become words in a line.
  static func text(_ display: DisplayID) -> String {
    let id = display.rawValue.isEmpty ? "_" : display.rawValue
    return "d" + String(id.map { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") ? $0 : "_" })
  }

  static func text(_ rect: CGRect) -> String {
    [rect.minX, rect.minY, rect.width, rect.height].map { text(Double($0)) }.joined(separator: ",")
  }

  /// Hundredths, without zeros at the end: `12`, `12.5`, `-0.25`. What is not finite means nothing on a screen.
  static func text(_ value: Double) -> String {
    guard value.isFinite, abs(value) < 1e15 else { return "0" }
    let hundredths = Int((abs(value) * 100).rounded())
    var text = String(hundredths / 100)
    if hundredths % 100 != 0 {
      let fraction = hundredths % 100
      text += "." + (fraction % 10 == 0 ? String(fraction / 10) : (fraction < 10 ? "0" : "") + String(fraction))
    }
    return value < 0 && hundredths != 0 ? "-" + text : text
  }
}

// MARK: Reading

extension StageLog.Line {
  /// Nil for whatever is not exactly one of the lines above.
  public init?(text: String) {
    let words = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    guard words.count >= 3, words[0] == "stage", words[2].hasPrefix("d"), words[2].count > 1 else { return nil }
    let display = DisplayID(String(words[2].dropFirst()))
    let rest = Array(words.dropFirst(3))
    switch words[1] {
    case "up", "retargeted":
      guard rest.count >= 2, (rest.count - 2) % 3 == 0, let frame = StageLog.numbers(rest[0], count: 4),
        let duration = Double(rest[1]), (0...StageLog.longestDuration).contains(duration)
      else { return nil }
      var roads: [StageLog.Road] = []
      for index in stride(from: 2, to: rest.count, by: 3) {
        guard let window = StageLog.window(rest[index]), let from = StageLog.Place(text: rest[index + 1]),
          let to = StageLog.Place(text: rest[index + 2])
        else { return nil }
        roads.append(StageLog.Road(window, from: from, to: to))
      }
      let plan = StageLog.Plan(
        display: display, frame: CGRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3]), duration: duration,
        roads: roads)
      self = words[1] == "up" ? .up(plan) : .retargeted(plan)
    case "frame":
      guard rest.count % 2 == 0 else { return nil }
      var samples: [StageLog.Sample] = []
      for index in stride(from: 0, to: rest.count, by: 2) {
        guard let window = StageLog.window(rest[index]), let place = StageLog.Place(text: rest[index + 1]), !place.isCover
        else { return nil }
        samples.append(StageLog.Sample(window, place.frame, opacity: place.opacity))
      }
      self = .frame(display, samples)
    case "lift" where rest.isEmpty: self = .lift(display)
    case "down" where rest.isEmpty: self = .down(display)
    default: return nil
    }
  }
}

extension StageLog.Place {
  init?(text: String) {
    let isCover = text.hasSuffix(",cover")
    guard let n = StageLog.numbers(isCover ? String(text.dropLast(6)) : text, count: 5) else { return nil }
    self.init(CGRect(x: n[0], y: n[1], width: n[2], height: n[3]), opacity: n[4], isCover: isCover)
  }
}

extension StageLog {
  /// What no screen and no motion has is damage, and is not read: nobody has to reckon with it afterwards.
  fileprivate static let largestNumber = 1e7
  fileprivate static let longestDuration = 3600.0

  fileprivate static func numbers(_ text: String, count: Int) -> [Double]? {
    let numbers = text.split(separator: ",", omittingEmptySubsequences: false).compactMap { Double($0) }.filter { abs($0) <= largestNumber }
    return numbers.count == count && text.filter { $0 == "," }.count == count - 1 ? numbers : nil
  }

  /// `w7`, and only that: `WindowID(word:)` also takes a bare number.
  fileprivate static func window(_ word: String) -> WindowID? { word.hasPrefix("w") ? WindowID(word: word) : nil }
}

// MARK: Motions

extension StageLog {
  /// One set of roads: from `up` or `retargeted` to the next `retargeted`, or to the end.
  public struct Leg: Equatable, Sendable {
    /// When its line was written, which is when the stand-ins set off. Seconds, as all times here.
    public var began: Double
    public var plan: Plan
    public var frames: [Tick]
  }

  public struct Tick: Equatable, Sendable {
    public var t: Double
    public var samples: [Sample]
  }

  /// Everything one stage did between going up and coming down.
  public struct Motion: Equatable, Sendable {
    public var display: DisplayID
    /// The line of the file it begins on, or 0.
    public var number: Int
    /// The log has no `up` for it: recording began while the stage was up, and its first roads begin in mid-flight.
    public var beganInMidMotion = false
    public var legs: [Leg]
    public var lift: Double?
    /// Nil: the log ends with the stage up.
    public var down: Double?
    /// The time of the last line of the log, of whatever kind.
    public var logEnds: Double
    /// Where the trace says the real windows were when the stage went up and when it came down. Empty for a log that is not part of a trace.
    public var realAtStart: [WindowID: CGRect] = [:]
    public var realAtEnd: [WindowID: CGRect] = [:]
    /// When the trace's other lines were written while the stage was up: what else the main thread, which also logs the frames, was doing.
    public var otherLines: [Double] = []

    public var began: Double { legs.first?.began ?? 0 }
  }

  public struct Reading: Equatable, Sendable {
    public var motions: [Motion] = []
    /// What begins with `stage` and could not be used, each with the reason: a line that cannot be read, a frame of a stage that is not up.
    public var problems: [String] = []
  }

  /// The motions in a trace, in the order they began. Beside the stage's own lines it follows where the real windows are, through every way
  /// the controller learns it: the header, what the window system reported, the lists Arbor asked for, and the frames windows took when
  /// it moved them. Where the trace cannot tell, it knows nothing rather than something old.
  public static func read(_ trace: Trace) -> Reading {
    var real: [WindowID: CGRect] = [:]
    /// A window that is minimized, hidden or on another Space is nowhere on the screen.
    func note(_ window: TraceWindow) { real[window.id] = window.minimized || window.hidden || window.offSpace ? nil : window.frame }
    trace.header.windows.forEach(note)
    var reader = Reader()
    for entry in trace.entries {
      switch entry.line {
      case .raw(let text) where claims(text):
        reader.take(text, t: entry.t, number: entry.number, real: real)
        continue
      case .appeared(let window), .changed(let window, _): note(window)
      case .destroyed(let id): real[id] = nil
      // Without a result there is no such window.
      case .setFrame(let id, _, let result, _): real[id] = result
      // Every window there is.
      case .allWindows(let windows):
        real = [:]
        windows.forEach(note)
      // macOS moves windows when the displays change. Where to, the list says that Arbor asks for next.
      case .displaysChanged: real = [:]
      case .other(.event, "windowFound", let arguments, _):
        if let window = arguments.first.flatMap(traceWindow) { note(window) }
      case .other(.event, "windowReplaced", let arguments, _):
        // The old one still exists but no longer shows.
        if case .number(let old)? = arguments.first, let id = UInt32(exactly: old) { real[WindowID(id)] = nil }
        if let window = arguments.dropFirst().first.flatMap(traceWindow) { note(window) }
      default: break
      }
      for index in reader.open.values { reader.reading.motions[index].otherLines.append(entry.t) }
    }
    return reader.finish(at: trace.entries.last?.t ?? 0, real: real)
  }

  /// A window among the arguments of an event recorded by name. Of what a `TraceWindow` holds, only what `read` goes by.
  private static func traceWindow(_ json: TraceJSON) -> TraceWindow? {
    guard case .object(let fields) = json, case .number(let number)? = fields["id"], let id = UInt32(exactly: number),
      case .array(let values)? = fields["frame"], values.count == 4
    else { return nil }
    let n = values.compactMap { value -> Double? in
      if case .number(let number) = value { return number }
      return nil
    }
    guard n.count == 4 else { return nil }
    return TraceWindow(
      id: WindowID(id), pid: 0, bundle: nil, app: "", title: "", frame: CGRect(x: n[0], y: n[1], width: n[2], height: n[3]),
      minimized: fields["minimized"] == .bool(true), hidden: fields["hidden"] == .bool(true), offSpace: fields["offSpace"] == .bool(true))
  }

  /// The motions in a log written by hand: times and lines.
  public static func read(_ lines: [(t: Double, text: String)]) -> Reading {
    var reader = Reader()
    for (index, line) in lines.enumerated() { reader.take(line.text, t: line.t, number: index + 1, real: [:]) }
    return reader.finish(at: lines.last?.t ?? 0, real: [:])
  }

  private struct Reader {
    var reading = Reading()
    /// The index in `reading.motions` of each display's stage that is up.
    var open: [DisplayID: Int] = [:]

    mutating func take(_ text: String, t: Double, number: Int, real: [WindowID: CGRect]) {
      guard let line = Line(text: text) else {
        reading.problems.append("line \(number): cannot be read")
        return
      }
      switch line {
      case .up(let plan):
        // The one before stays as it is, without a `down`: that is what the log says.
        begin(plan, t: t, number: number, real: real)
      case .retargeted(let plan):
        // Without an `up`, recording began while the stage was up.
        guard let index = open[plan.display] else {
          begin(plan, t: t, number: number, real: real)
          reading.motions[reading.motions.count - 1].beganInMidMotion = true
          return
        }
        reading.motions[index].legs.append(Leg(began: t, plan: plan, frames: []))
        // A stage that was fading is in full view again.
        reading.motions[index].lift = nil
      case .frame(let display, let samples):
        guard let index = open[display] else { return orphan(number) }
        reading.motions[index].legs[reading.motions[index].legs.count - 1].frames.append(Tick(t: t, samples: samples))
      case .lift(let display):
        guard let index = open[display] else { return orphan(number) }
        reading.motions[index].lift = t
      case .down(let display):
        guard let index = open.removeValue(forKey: display) else { return orphan(number) }
        reading.motions[index].down = t
        reading.motions[index].realAtEnd = real
      }
    }

    private mutating func begin(_ plan: Plan, t: Double, number: Int, real: [WindowID: CGRect]) {
      open[plan.display] = reading.motions.count
      reading.motions.append(
        Motion(
          display: plan.display, number: number, legs: [Leg(began: t, plan: plan, frames: [])], logEnds: t, realAtStart: real))
    }

    private mutating func orphan(_ number: Int) { reading.problems.append("line \(number): no stage is up on that display") }

    mutating func finish(at end: Double, real: [WindowID: CGRect]) -> Reading {
      for index in reading.motions.indices {
        reading.motions[index].logEnds = end
        if reading.motions[index].down == nil { reading.motions[index].realAtEnd = real }
      }
      return reading
    }
  }
}

// MARK: The curve

extension Transition {
  /// How much of its road a stand-in has behind it when `share` of the time has passed, both from 0 to 1, on `curve`.
  public static func progress(after share: Double) -> Double {
    guard share > 0 else { return 0 }
    guard share < 1 else { return 1 }
    func bezier(_ s: Double, _ a: Double, _ b: Double) -> Double { 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s }
    // The time grows with the curve's parameter, so halving the span finds it.
    var (low, high) = (0.0, 1.0)
    for _ in 0..<40 {
      let middle = (low + high) / 2
      if bezier(middle, curve.x1, curve.x2) < share { low = middle } else { high = middle }
    }
    return bezier((low + high) / 2, curve.y1, curve.y2)
  }

  /// The other way round: the share of the time after which a stand-in has `progress` of its road behind it.
  public static func share(ofProgress progress: Double) -> Double {
    guard progress > 0 else { return 0 }
    guard progress < 1 else { return 1 }
    var (low, high) = (0.0, 1.0)
    for _ in 0..<40 {
      let middle = (low + high) / 2
      if self.progress(after: middle) < progress { low = middle } else { high = middle }
    }
    return (low + high) / 2
  }
}
