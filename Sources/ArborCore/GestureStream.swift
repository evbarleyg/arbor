import CoreGraphics

/// What the fingers have done since the last update, for a view that follows them
/// (docs/features/F16-continuous-zoom-and-pan.md).
///
/// Whoever listens gets exactly one `began`, then any number of `changed`, then exactly one `ended`
/// or `cancelled`. Every update, the first and the last included, can carry movement.
public struct GestureUpdate: Equatable, Sendable {
  public enum Phase: Equatable, Sendable {
    case began, changed, ended, cancelled
  }

  public var phase: Phase
  /// Where the pointer was at the latest event (global, top-left origin).
  public var location: CGPoint
  /// The sum of the pinch's deltas since the last update. Spreading two fingers is positive.
  public var magnification: Double
  /// The sum of the scroll's deltas since the last update, in points as macOS reports them.
  public var pan: CGSize

  public init(phase: Phase, location: CGPoint, magnification: Double = 0, pan: CGSize = .zero) {
    self.phase = phase
    self.location = location
    self.magnification = magnification
    self.pan = pan
  }
}

/// Collects the events of a pinch and a scroll between two visits of the main actor.
///
/// A trackpad sends about a hundred events a second, on the thread every trackpad event on the Mac
/// waits for. The main actor comes by when it can. One block per event would queue up behind a busy main
/// thread and replay stale motion when it wakes, so events are added up here: `feed` says whether a
/// visit has to be asked for, and `drain` hands over what has gathered, as few updates as will do.
///
/// A pinch and a scroll that overlap are one gesture, from the first beginning to the last end.
public struct GestureStream: Equatable, Sendable {
  public enum Part: Equatable, Sendable {
    case pinch, scroll
  }

  /// The most one event can move. Larger deltas do not come from fingers.
  public static let maximumMagnification = 2.0
  public static let maximumPan: CGFloat = 2000
  /// With this many updates waiting, a new gesture replaces the whole gestures among them. Nobody
  /// has seen those begin, and they were made faster than hands can while the main thread was stuck.
  public static let maximumWaiting = 30

  private var pinchIsActive = false
  private var scrollIsActive = false
  private var location = CGPoint.zero
  private var waiting: [GestureUpdate] = []
  private var isVisitAskedFor = false
  /// Whether the last update handed over left a gesture open, so that its end is owed.
  private var listenerIsMidGesture = false

  public init() {}

  /// Whether a gesture is in progress.
  public var isActive: Bool { pinchIsActive || scrollIsActive }

  /// Takes one event of a pinch or scroll that is Arbor's. Returns true if the main actor has to be
  /// asked to `drain`; false if there is nothing new, or it has been asked already.
  public mutating func feed(
    _ part: Part, _ phase: GestureUpdate.Phase, at point: CGPoint, magnification: Double = 0, pan: CGSize = .zero
  ) -> Bool {
    let wasActive = part == .pinch ? pinchIsActive : scrollIsActive
    // A cancelled event's own movement does not count.
    let counts = phase != .cancelled
    let magnification = counts ? Self.bounded(magnification, Self.maximumMagnification) : 0
    let pan =
      counts
      ? CGSize(
        width: CGFloat(Self.bounded(Double(pan.width), Double(Self.maximumPan))),
        height: CGFloat(Self.bounded(Double(pan.height), Double(Self.maximumPan))))
      : .zero

    switch phase {
    case .began:
      // The last end was missed: close that gesture, so that beginnings and ends stay in pairs.
      if wasActive { finish(part, as: .cancelled) }
      note(point)
      let isFirst = !isActive
      setActive(part, true)
      if isFirst {
        if waiting.count >= Self.maximumWaiting { dropWholeGestures() }
        waiting.append(GestureUpdate(phase: .began, location: location, magnification: magnification, pan: pan))
      } else {
        move(magnification, pan)
      }
    case .changed:
      guard wasActive else { return false }
      note(point)
      move(magnification, pan)
    case .ended, .cancelled:
      guard wasActive else { return false }
      note(point)
      move(magnification, pan)
      finish(part, as: phase)
    }
    return askForAVisit()
  }

  /// Ends whatever is in progress, for when events may have been missed or Arbor stops listening.
  /// Returns true if the main actor has to be asked to `drain`.
  public mutating func cancel() -> Bool {
    guard isActive else { return false }
    pinchIsActive = false
    scrollIsActive = false
    close(as: .cancelled)
    return askForAVisit()
  }

  /// Hands over what has gathered, in order.
  public mutating func drain() -> [GestureUpdate] {
    isVisitAskedFor = false
    defer { waiting.removeAll() }
    if let last = waiting.last { listenerIsMidGesture = last.phase == .began || last.phase == .changed }
    return waiting
  }

  /// Called between gestures, so everything waiting is whole gestures, except that the first
  /// updates may be the rest of one the listener has seen begin. Those stay.
  private mutating func dropWholeGestures() {
    guard listenerIsMidGesture, let end = waiting.firstIndex(where: { $0.phase == .ended || $0.phase == .cancelled })
    else {
      waiting.removeAll()
      return
    }
    waiting.removeSubrange((end + 1)...)
  }

  private mutating func askForAVisit() -> Bool {
    guard !isVisitAskedFor, !waiting.isEmpty else { return false }
    isVisitAskedFor = true
    return true
  }

  private mutating func setActive(_ part: Part, _ active: Bool) {
    switch part {
    case .pinch: pinchIsActive = active
    case .scroll: scrollIsActive = active
    }
  }

  private mutating func note(_ point: CGPoint) {
    if point.x.isFinite, point.y.isFinite { location = point }
  }

  /// Adds movement to the `changed` that is waiting, or starts one.
  private mutating func move(_ magnification: Double, _ pan: CGSize) {
    if let last = waiting.indices.last, waiting[last].phase == .changed {
      waiting[last].location = location
      waiting[last].magnification += magnification
      waiting[last].pan.width += pan.width
      waiting[last].pan.height += pan.height
    } else {
      waiting.append(GestureUpdate(phase: .changed, location: location, magnification: magnification, pan: pan))
    }
  }

  /// One half is over. The gesture is when both are, and ends the way its last half did.
  private mutating func finish(_ part: Part, as phase: GestureUpdate.Phase) {
    setActive(part, false)
    if !isActive { close(as: phase) }
  }

  /// The `changed` that is waiting becomes the end, so the end brings its movement along.
  private mutating func close(as phase: GestureUpdate.Phase) {
    if let last = waiting.indices.last, waiting[last].phase == .changed {
      waiting[last].phase = phase
      waiting[last].location = location
    } else {
      waiting.append(GestureUpdate(phase: phase, location: location))
    }
  }

  private static func bounded(_ value: Double, _ limit: Double) -> Double {
    guard value.isFinite else { return 0 }
    return max(-limit, min(limit, value))
  }
}

/// Decides whose a two-finger scroll is, once, when it begins, and holds to it until it ends.
public struct ScrollClaim: Equatable, Sendable {
  /// A scroll event's phase, while fingers are on the trackpad. `none` during momentum, and
  /// always for a wheel mouse.
  public enum Phase: Equatable, Sendable {
    case none, mayBegin, began, changed, ended, cancelled

    /// From the event's `scrollWheelEventScrollPhase` (a `CGScrollPhase`).
    public init(scrollPhase: Int64) {
      switch scrollPhase {
      case 1: self = .began
      case 2: self = .changed
      case 4: self = .ended
      case 8: self = .cancelled
      case 128: self = .mayBegin
      default: self = .none
      }
    }
  }

  /// The phase of the coasting after the fingers have lifted.
  public enum Momentum: Equatable, Sendable {
    case none, began, continued, ended

    /// From the event's `scrollWheelEventMomentumPhase` (a `CGMomentumScrollPhase`).
    public init(momentumPhase: Int64) {
      switch momentumPhase {
      case 1: self = .began
      case 2: self = .continued
      case 3: self = .ended
      default: self = .none
      }
    }
  }

  public enum Verdict: Equatable, Sendable {
    /// The app's: let it through.
    case pass
    /// Arbor's, and of no further use: hide it from the app.
    case swallow
    /// Arbor's: hide it from the app and pass its movement on with this phase.
    case deliver(GestureUpdate.Phase)
  }

  /// Whether the scroll in progress is Arbor's.
  public private(set) var isClaimed = false
  /// After a scroll of Arbor's, until its momentum is over or fingers touch the trackpad again.
  private var ownsMomentum = false

  public init() {}

  /// Whether an event could be Arbor's whatever keys are held. If not, and nothing speaks for
  /// claiming a new scroll either, the event need not be looked at.
  public var isBusy: Bool { isClaimed || ownsMomentum }

  /// - Parameter claim: whether Arbor should take a scroll that is beginning. Evaluated only then.
  public mutating func feed(
    _ phase: Phase, momentum: Momentum = .none, claim: @autoclosure () -> Bool = false
  ) -> Verdict {
    switch phase {
    case .mayBegin:
      // Fingers on the trackpad stop the coasting. Whose the scroll is gets decided if it begins.
      ownsMomentum = false
      return .pass
    case .began:
      ownsMomentum = false
      isClaimed = claim()
      return isClaimed ? .deliver(.began) : .pass
    case .changed:
      return isClaimed ? .deliver(.changed) : .pass
    case .ended:
      guard isClaimed else { return .pass }
      isClaimed = false
      ownsMomentum = true
      return .deliver(.ended)
    case .cancelled:
      guard isClaimed else { return .pass }
      isClaimed = false
      return .deliver(.cancelled)
    case .none:
      guard ownsMomentum, momentum != .none else { return .pass }
      if momentum == .ended { ownsMomentum = false }
      return .swallow
    }
  }

  /// Forgets the scroll in progress, for when events may have been missed.
  public mutating func reset() {
    isClaimed = false
    ownsMomentum = false
  }
}
