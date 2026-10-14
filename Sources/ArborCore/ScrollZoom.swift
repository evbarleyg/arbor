/// Turns scrolling into camera steps, for Macs without a trackpad (docs/features/F55-zoom-with-a-mouse.md).
///
/// A wheel turns in notches, and one notch is one step, whatever macOS's acceleration makes of it. A Magic Mouse, a
/// trackpad and the drivers that smooth a wheel report points of travel instead: one step for every `threshold` of them
/// since the last step, so a long stroke steps several levels and turning back works. Scrolling up steps in.
///
/// Answers are numbers of steps, positive for in: `GestureRouter` makes commands of them, or movement for a view that
/// follows the fingers.
public struct ScrollZoom: Equatable, Sendable {
  public static let defaultThreshold = 40.0
  /// Smaller thresholds are raised to this, so that a resting finger does not step.
  public static let minimumThreshold = 4.0
  /// No event means more steps than this.
  static let maximumSteps = 8

  /// Points of travel for one step. Values that are not positive numbers use `defaultThreshold`.
  public var threshold: Double
  /// Travel since the last step, or since the scroll began.
  public private(set) var travel = 0.0

  public init(threshold: Double = ScrollZoom.defaultThreshold) {
    self.threshold = threshold
  }

  /// The threshold actually used.
  public var effectiveThreshold: Double {
    guard threshold.isFinite, threshold > 0 else { return Self.defaultThreshold }
    return max(threshold, Self.minimumThreshold)
  }

  /// One notch of a wheel. Only the direction counts.
  public mutating func notch(_ delta: Double) -> Int {
    travel = 0
    return delta > 0 ? 1 : delta < 0 ? -1 : 0
  }

  /// So many points of travel.
  public mutating func move(by points: Double) -> Int {
    guard points.isFinite else { return 0 }
    let step = effectiveThreshold
    let limit = step * Double(Self.maximumSteps)
    travel = min(max(travel + points, -limit), limit)
    // Allows for rounding, so that ten deltas of a tenth of the threshold make one step.
    let steps = Int((abs(travel) + 1e-9) / step) * (travel < 0 ? -1 : 1)
    travel -= Double(steps) * step
    return steps
  }

  /// Travel is never carried from one scroll to the next.
  public mutating func reset() {
    travel = 0
  }
}
