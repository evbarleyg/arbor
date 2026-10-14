/// Turns a trackpad pinch into camera steps (docs/features/F03-trackpad-gestures.md).
///
/// Feed it every magnify event of a gesture: its phase and its magnification
/// delta. Spreading two fingers (positive magnification, the direction that
/// zooms in in Maps or Photos) steps in; pinching them together steps out.
/// There is one step for every `threshold` of travel since the last step, so a
/// long pinch steps several levels and reversing direction mid-gesture works.
/// Travel is never carried from one gesture to the next.
///
/// Whether a gesture belongs to Arbor is decided once, when it begins, and
/// holds until it ends. An app that saw the start of a pinch sees all of it,
/// and a pinch Arbor took never reaches the app halfway through.
public struct GestureInterpreter: Equatable, Sendable {
  public enum Phase: Equatable, Sendable {
    case began, changed, ended, cancelled
  }

  /// What to do with one event.
  public struct Outcome: Equatable, Sendable {
    /// The gesture belongs to Arbor: the event must not reach the app under the pointer.
    public var handled: Bool
    /// Camera commands to run, in order.
    public var commands: [Command]

    public init(handled: Bool, commands: [Command] = []) {
      self.handled = handled
      self.commands = commands
    }

    public static let ignored = Outcome(handled: false)
  }

  public static let defaultThreshold = 0.25
  /// Smaller thresholds are raised to this, so one event cannot produce dozens of steps.
  public static let minimumThreshold = 0.05

  /// Magnification needed for one step. Values that are not positive numbers
  /// use `defaultThreshold`.
  public var threshold: Double
  /// Whether the gesture in progress belongs to Arbor.
  public private(set) var isClaimed = false
  /// Travel since the last step, or since the gesture began.
  public private(set) var travel = 0.0
  /// Whether the rotation in progress is kept from the app (see `feedRotation`).
  public private(set) var isRotationClaimed = false

  public init(threshold: Double = GestureInterpreter.defaultThreshold) {
    self.threshold = threshold
  }

  /// The threshold actually used.
  public var effectiveThreshold: Double {
    guard threshold.isFinite, threshold > 0 else { return Self.defaultThreshold }
    return max(threshold, Self.minimumThreshold)
  }

  /// Feeds one magnify event.
  ///
  /// - Parameter claim: whether Arbor should take a gesture that is beginning
  ///   (⌥ is held, or no app window is under the pointer). It is evaluated
  ///   only for `.began`, so an expensive check runs once per gesture.
  public mutating func feed(
    _ phase: Phase, magnification: Double, claim: @autoclosure () -> Bool = true
  ) -> Outcome {
    switch phase {
    case .began:
      travel = 0
      isClaimed = claim()
      return isClaimed ? Outcome(handled: true, commands: move(by: magnification)) : .ignored
    case .changed:
      return isClaimed ? Outcome(handled: true, commands: move(by: magnification)) : .ignored
    case .ended, .cancelled:
      guard isClaimed else { return .ignored }
      // An ended event can still carry the last bit of movement; a cancelled one does not count.
      let commands = phase == .ended ? move(by: magnification) : []
      isClaimed = false
      travel = 0
      return Outcome(handled: true, commands: commands)
    }
  }

  /// Feeds one rotate event and returns whether to keep it from the app.
  ///
  /// Two fingers that pinch also turn a little, which macOS reports as a gesture of its own, so an
  /// ⌥-pinch over a picture would turn the picture. A rotation that begins during a pinch of Arbor's
  /// is Arbor's as well, until it ends, even if the pinch ends first. One that began earlier
  /// stays with the app that saw it begin.
  public mutating func feedRotation(_ phase: Phase) -> Bool {
    switch phase {
    case .began:
      isRotationClaimed = isClaimed
      return isRotationClaimed
    case .changed:
      return isRotationClaimed
    case .ended, .cancelled:
      defer { isRotationClaimed = false }
      return isRotationClaimed
    }
  }

  /// Forgets the gesture in progress, for when events may have been missed.
  public mutating func reset() {
    isClaimed = false
    travel = 0
    isRotationClaimed = false
  }

  private mutating func move(by delta: Double) -> [Command] {
    guard delta.isFinite else { return [] }
    let step = effectiveThreshold
    // Allows for rounding, so that five deltas of 0.05 make one step of 0.25.
    let tolerance = 1e-9
    // No event means more steps than this. Without a bound a delta of 1e17 would never finish:
    // taking one step away from it no longer changes it.
    let limit = step * 32
    travel = min(max(travel + delta, -limit), limit)
    var commands: [Command] = []
    while travel >= step - tolerance {
      commands.append(.stepIn)
      travel -= step
    }
    while travel <= -step + tolerance {
      commands.append(.stepOut)
      travel += step
    }
    return commands
  }
}
