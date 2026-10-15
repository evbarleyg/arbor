import CoreGraphics

/// What the gesture taps ask for every trackpad event: whose it is, and what follows from it.
///
/// It puts together `GestureInterpreter` (whose a pinch is, and F03's steps), `ScrollClaim` (whose a
/// scroll is) and `GestureStream` (F16: what the main actor is told), so that the taps only read
/// events and do as they are answered.
///
/// With `continuousZoom` off, a pinch of Arbor's turns into `in` and `out` commands. With it on, a pinch and a
/// scroll of Arbor's are streamed as `GestureUpdate`s.
///
/// ⌃⌥ is Arbor, with the pointer too (docs/KEYBOARD.md). A scroll with ⌃⌥ held, up or down, zooms (F55, `ScrollZoom`):
/// steps with `continuousZoom` off, and with it on the same movement a pinch would have made. Sideways it slides the
/// view (F16). The way it first moves decides for all of it. Every other scroll is left alone, also one with ⌥ alone;
/// except that the fingers of a pinch of Arbor's slide the view as they move.
public struct GestureRouter: Equatable, Sendable {
  /// The modifier keys held during a scroll event.
  public struct Keys: Equatable, Sendable {
    public var control: Bool
    public var option: Bool
    public var shift: Bool
    public var command: Bool

    public init(control: Bool = false, option: Bool = false, shift: Bool = false, command: Bool = false) {
      self.control = control
      self.option = option
      self.shift = shift
      self.command = command
    }

    public static let none = Keys()
    /// ⌃⌥.
    public static let arbors = Keys(control: true, option: true)

    /// Exactly ⌃⌥, so that other chords stay with the apps, and ⌃⌥⇧⌘, the hyper key, with people (docs/KEYBOARD.md).
    var makeAScrollArbors: Bool { self == .arbors }
    /// ⇧ is how macOS turns a wheel sideways, so for a wheel it does not count.
    var makeANotchArbors: Bool { control && option && !command }
  }

  public struct Answer: Equatable, Sendable {
    /// The event is Arbor's: it must not reach the app under the pointer.
    public var swallow: Bool
    /// Commands to run, in order.
    public var commands: [Command]
    /// The main actor has to be asked to `drain`.
    public var needsVisit: Bool

    public init(swallow: Bool, commands: [Command] = [], needsVisit: Bool = false) {
      self.swallow = swallow
      self.commands = commands
      self.needsVisit = needsVisit
    }
  }

  private var interpreter = GestureInterpreter()
  private var scrollClaim = ScrollClaim()
  private var stream = GestureStream()
  public private(set) var isContinuous = false
  private var scrollZoom = ScrollZoom()
  private enum ScrollKind: Equatable, Sendable {
    /// It has not moved yet.
    case undecided
    case zoom, pan
  }
  /// What the scroll in progress does, if it is Arbor's.
  private var scrollKind = ScrollKind.undecided
  /// For a wheel on the Desktop, whose every notch would otherwise ask anew.
  private var surface = SurfaceMemo()
  /// Goes up whenever what is under the pointer may have changed. Whoever looks with the lock released takes it along and hands
  /// it back to `scroll`, which believes no finding from before the news.
  public private(set) var newsOfTheWindows = 0

  /// The setting `scrollZoom`: a scroll with ⌃⌥ held zooms.
  public var zoomsWithScroll = false
  /// The setting `scrollOnDesktopZooms`: so does one, without the keys, that `overDesktop` says yes to.
  public var zoomsOnDesktop = false

  public init() {}

  /// `scrollZoomThreshold`.
  public var scrollThreshold: Double {
    get { scrollZoom.threshold }
    set { scrollZoom.threshold = newValue }
  }

  /// `pinchThreshold`, for the steps.
  public var threshold: Double {
    get { interpreter.threshold }
    set { interpreter.threshold = newValue }
  }

  /// Follows the setting `continuousZoom`. A change ends the gesture in progress, which is not
  /// handed from one way of working to the other halfway. Returns true if the main actor has to be
  /// asked to `drain`.
  public mutating func setContinuous(_ continuous: Bool) -> Bool {
    guard continuous != isContinuous else { return false }
    isContinuous = continuous
    return reset()
  }

  /// - Parameter claim: whether Arbor should take a pinch that is beginning (⌥ is held, or no
  ///   app's window is under the pointer). Evaluated only then.
  public mutating func pinch(
    _ phase: GestureInterpreter.Phase, magnification: Double, at point: CGPoint,
    claim: @autoclosure () -> Bool = true
  ) -> Answer {
    let outcome = interpreter.feed(phase, magnification: magnification, claim: claim())
    guard isContinuous else { return Answer(swallow: outcome.handled, commands: outcome.commands) }
    guard outcome.handled else {
      // An app's pinch begins although Arbor's never ended: that end was missed.
      let needsVisit = phase == .began && stream.feed(.pinch, .cancelled, at: point)
      return Answer(swallow: false, needsVisit: needsVisit)
    }
    let needsVisit = stream.feed(.pinch, Self.streamed(phase), at: point, magnification: magnification)
    return Answer(swallow: true, needsVisit: needsVisit)
  }

  /// Returns whether to keep a rotate event from the app (`GestureInterpreter.feedRotation`).
  public mutating func rotation(_ phase: GestureInterpreter.Phase) -> Bool {
    interpreter.feedRotation(phase)
  }

  /// Whether these settings ask for a scroll tap at all. The tap and `doctor` both go by this.
  public static func listensToScrolls(_ settings: Settings) -> Bool {
    settings.gesturesEnabled && (settings.scrollZoom || settings.continuousZoom)
  }

  /// Whether the scroll tap has to be switched on. A trackpad sends a hundred scroll events a second for as long as
  /// anybody scrolls anything, and each would wake Arbor, so the tap is installed but paused, and switched on only
  /// while a scroll could be Arbor's: ⌃⌥ is down, a scroll of Arbor's or its momentum is in progress, whatever
  /// the keys do meanwhile, or a pinch of Arbor's is, which claims a scroll that begins during it.
  public func scrollTapIsWanted(keys: Keys) -> Bool {
    if scrollClaim.isBusy { return true }
    // What comes may be a wheel's notch.
    if zoomsWithScroll, zoomsOnDesktop || keys.makeANotchArbors { return true }
    return isContinuous && (keys.makeAScrollArbors || interpreter.isClaimed || stream.isActive)
  }

  /// Whether a scroll event has to be shown to `scroll` at all. The same question, asked of each event's own keys: the
  /// tap may be on for a moment longer than it is wanted, and every scroll on the Mac then waits for the answer.
  public func scrollNeedsALook(keys: Keys) -> Bool {
    scrollTapIsWanted(keys: keys)
  }

  /// Whether it matters for this event what is under the pointer: only with `scrollOnDesktopZooms`, without any key, and
  /// when a scroll begins or has no phases.
  private func surfaceMatters(_ phase: ScrollClaim.Phase, momentum: ScrollClaim.Momentum, keys: Keys) -> Bool {
    guard zoomsWithScroll, zoomsOnDesktop, keys == .none else { return false }
    return phase == .began || (phase == .none && momentum == .none)
  }

  /// Whether `scroll` would have to find out what is under the pointer for this event. Finding out takes
  /// milliseconds, so whoever holds this value under a lock asks first, finds out with the lock released, and hands
  /// `scroll` the answer.
  ///
  /// A scroll that begins always asks. An answer out of date costs a wheel one notch; it would cost fingers the whole scroll
  /// and its coasting, swallowed over an app's window. And beginnings come a few a second at most.
  public func scrollAsksWhatIsUnder(
    _ phase: ScrollClaim.Phase, momentum: ScrollClaim.Momentum = .none, at point: CGPoint, keys: Keys, now: Double
  ) -> Bool {
    surfaceMatters(phase, momentum: momentum, keys: keys) && (phase != .none || surface.isBare(at: point, now: now) == nil)
  }

  /// The windows have moved, Arbor's own step among the reasons: what was found under the pointer may no longer be there.
  public mutating func forgetWhatIsUnder() {
    surface.forget()
    newsOfTheWindows &+= 1
  }

  /// A scroll is Arbor's if, as it begins, ⌃⌥ and nothing else is held or, with `continuousZoom`, a pinch of Arbor's is in
  /// progress. A wheel has no beginning: each notch is on its own, and only zooms.
  ///
  /// - Parameters:
  ///   - hasNotches: the event is one notch of a wheel, not points of travel.
  ///   - now: the time, in seconds on a clock of the caller's own that does not go backwards. Never the event's time stamp,
  ///     which is whatever the event's maker wrote there. Without it nothing is remembered from one notch to the next
  ///     about what is under the pointer.
  ///   - news: `newsOfTheWindows` as it was when `scrollAsksWhatIsUnder` was asked. If it has gone up since, `overDesktop` is from
  ///     before the news, or nobody looked because an answer was still there: the scroll is the app's, and nothing is kept.
  ///   - overDesktop: whether no app's window is under the pointer. Evaluated only if `scrollAsksWhatIsUnder`: with
  ///     `zoomsOnDesktop`, without the keys, and when a scroll begins or has no phases.
  public mutating func scroll(
    _ phase: ScrollClaim.Phase, momentum: ScrollClaim.Momentum = .none, pan: CGSize, at point: CGPoint,
    keys: Keys, hasNotches: Bool = false, now: Double? = nil, asOf news: Int? = nil,
    overDesktop: @autoclosure () -> Bool = false
  ) -> Answer {
    let height = Double(pan.height)
    var isOverDesktop = false
    if surfaceMatters(phase, momentum: momentum, keys: keys) {
      if phase == .none, let now, let remembered = surface.isBare(at: point, now: now) {
        isOverDesktop = remembered
      } else if let news, news != newsOfTheWindows {
        isOverDesktop = false
      } else {
        isOverDesktop = overDesktop()
        // Kept from when it was found out, not from when it was last of use.
        if phase == .none, let now { surface.remember(isOverDesktop, at: point, now: now) }
      }
    }
    if phase == .none, momentum == .none {
      // A wheel, or a driver that smooths one: no beginning, no end, no momentum.
      guard zoomsWithScroll, keys.makeANotchArbors || isOverDesktop else {
        return Answer(swallow: false)
      }
      let steps = hasNotches ? scrollZoom.notch(height) : scrollZoom.move(by: height)
      guard isContinuous else { return Answer(swallow: true, commands: Self.commands(for: steps)) }
      guard steps != 0, !stream.isActive else { return Answer(swallow: true) }
      // A whole gesture of its own, worth so many steps of a pinch.
      let first = stream.feed(.scroll, .began, at: point)
      let movement = Double(steps) * interpreter.effectiveThreshold
      return Answer(swallow: true, needsVisit: stream.feed(.scroll, .ended, at: point, magnification: movement) || first)
    }
    var claim = false
    if phase == .began {
      scrollZoom.reset()
      if keys.makeAScrollArbors {
        // Where only one of the two can be had there is nothing to decide.
        scrollKind = !zoomsWithScroll ? .pan : !isContinuous ? .zoom : .undecided
        claim = zoomsWithScroll || isContinuous
      } else if isOverDesktop {
        scrollKind = .zoom
        claim = true
      } else {
        scrollKind = .pan
        claim = isContinuous && interpreter.isClaimed
      }
    }
    switch scrollClaim.feed(phase, momentum: momentum, claim: claim) {
    case .pass:
      // An app's scroll begins although Arbor's never ended: that end was missed.
      return Answer(swallow: false, needsVisit: phase == .began && stream.feed(.scroll, .cancelled, at: point))
    case .swallow:
      return Answer(swallow: true)
    case .deliver(let streamed):
      // Some drivers begin a scroll without movement. A diagonal counts as up or down: zooming is what the keys are known for.
      if scrollKind == .undecided, pan != .zero { scrollKind = abs(pan.height) >= abs(pan.width) ? .zoom : .pan }
      guard scrollKind != .undecided else {
        return Answer(swallow: true, needsVisit: stream.feed(.scroll, streamed, at: point))
      }
      guard scrollKind == .zoom else {
        return Answer(swallow: true, needsVisit: stream.feed(.scroll, streamed, at: point, pan: pan))
      }
      guard isContinuous else {
        // A cancelled event's own movement does not count.
        let steps = streamed == .cancelled ? 0 : scrollZoom.move(by: height)
        return Answer(swallow: true, commands: Self.commands(for: steps))
      }
      // As far as a pinch that would have stepped as often.
      let movement = height.isFinite ? height / scrollZoom.effectiveThreshold * interpreter.effectiveThreshold : 0
      return Answer(swallow: true, needsVisit: stream.feed(.scroll, streamed, at: point, magnification: movement))
    }
  }

  private static func commands(for steps: Int) -> [Command] {
    Array(repeating: steps > 0 ? .stepIn : .stepOut, count: abs(steps))
  }

  /// Forgets everything in progress, for when events may have been missed or Arbor stops listening.
  /// A gesture the listener saw begin ends as cancelled. Returns true if the main actor has to be
  /// asked to `drain`.
  public mutating func reset() -> Bool {
    interpreter.reset()
    scrollClaim.reset()
    scrollZoom.reset()
    scrollKind = .undecided
    forgetWhatIsUnder()
    return stream.cancel()
  }

  /// Hands over what has gathered for the listener, in order.
  public mutating func drain() -> [GestureUpdate] {
    stream.drain()
  }

  private static func streamed(_ phase: GestureInterpreter.Phase) -> GestureUpdate.Phase {
    switch phase {
    case .began: .began
    case .changed: .changed
    case .ended: .ended
    case .cancelled: .cancelled
    }
  }
}
