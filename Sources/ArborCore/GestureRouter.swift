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

  /// The setting `scrollZoom`: a scroll with ⌃⌥ held zooms.
  public var zoomsWithScroll = false
  /// The setting `scrollOnDesktopZooms`: so does one, without the keys, that no app's window is under.
  public var zoomsOnDesktop = false
  /// The setting `pinchOnDesktop`: a pinch without ⌥ that no app's window is under is Arbor's too.
  public var pinchesOnDesktop = false

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

  /// Whether the pinch tap has to be switched on. While it is, every touch of the trackpad passes through Arbor. So it is
  /// installed but paused, like the scroll tap, and switched on only while a pinch could be Arbor's: ⌥ is down, whatever else is,
  /// or a pinch of Arbor's or a rotation that began during one is in progress, whatever the keys do meanwhile. With
  /// `pinchesOnDesktop` any pinch could be.
  public func pinchTapIsWanted(keys: Keys) -> Bool {
    pinchesOnDesktop || keys.option || interpreter.isClaimed || interpreter.isRotationClaimed || stream.isActive
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

  /// A scroll is Arbor's if, as it begins, ⌃⌥ and nothing else is held or, with `continuousZoom`, a pinch of Arbor's is in
  /// progress. A wheel has no beginning: each notch is on its own, and only zooms.
  ///
  /// - Parameters:
  ///   - hasNotches: the event is one notch of a wheel, not points of travel.
  ///   - overDesktop: whether no app's window is under the pointer. Evaluated only with `zoomsOnDesktop`, without
  ///     the keys, and when a scroll begins or has no phases.
  public mutating func scroll(
    _ phase: ScrollClaim.Phase, momentum: ScrollClaim.Momentum = .none, pan: CGSize, at point: CGPoint,
    keys: Keys, hasNotches: Bool = false, overDesktop: @autoclosure () -> Bool = false
  ) -> Answer {
    let height = Double(pan.height)
    if phase == .none, momentum == .none {
      // A wheel, or a driver that smooths one: no beginning, no end, no momentum.
      guard zoomsWithScroll, keys.makeANotchArbors || (keys == .none && zoomsOnDesktop && overDesktop()) else {
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
      } else if keys == .none, zoomsWithScroll, zoomsOnDesktop, overDesktop() {
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
