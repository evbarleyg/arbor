import CoreGraphics

/// What was last found under the pointer, kept for a moment.
///
/// Finding out means reading the window server's list: a quarter of a millisecond on a good day, three while an app
/// hangs, with an event waiting all the while. A wheel has no beginning at which to ask once: a free-spinning one, or a
/// driver that smooths one, sends a hundred or two events a second, each on its own. They are about the same
/// place, so one answer serves them for as long as the pointer rests, but not for long: windows come and go, and
/// Arbor's own steps move them.
public struct SurfaceMemo: Equatable, Sendable {
  /// Seconds an answer is good for, counted from when it was given: more events do not keep it alive.
  public static let lifetime = 0.3
  /// How far, in points along either axis, a hand on a wheel may nudge the pointer.
  public static let slack: CGFloat = 2

  private var point = CGPoint.zero
  private var time = -Double.infinity
  private var isBare = false

  public init() {}

  /// The answer, if there is one that still holds. Times are seconds on any clock that does not go backwards.
  public func isBare(at point: CGPoint, now: Double) -> Bool? {
    guard now >= time, now - time < Self.lifetime,
      max(abs(point.x - self.point.x), abs(point.y - self.point.y)) <= Self.slack
    else { return nil }
    return isBare
  }

  public mutating func remember(_ isBare: Bool, at point: CGPoint, now: Double) {
    self.isBare = isBare
    self.point = point
    time = now
  }

  public mutating func forget() {
    self = SurfaceMemo()
  }
}
