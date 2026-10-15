/// How a motion or a fade is spread over its time: a cubic Bézier curve from (0, 0) to (1, 1), time along x and the way
/// covered along y, as Core Animation and CSS have it. On a Mac Core Animation works it out; whoever plays Arbor's motions
/// without a screen (`arbor-sim film`) asks here, so that a stand-in is at the same place at the same moment.
public struct TimingCurve: Equatable, Sendable {
  public var x1: Double
  public var y1: Double
  public var x2: Double
  public var y2: Double

  /// The control points' x are kept within 0...1: beyond that, time would run backwards.
  public init(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
    func bounded(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
    self.x1 = bounded(x1)
    self.y1 = y1.isFinite ? y1 : 0
    self.x2 = bounded(x2)
    self.y2 = y2.isFinite ? y2 : 1
  }

  /// The curve of every motion in Arbor (`Transition.curve`).
  public static let motion = TimingCurve(Transition.curve.x1, Transition.curve.y1, Transition.curve.x2, Transition.curve.y2)
  public static let linear = TimingCurve(0, 0, 1, 1)
  /// Core Animation's `default`, which an animation gets that asks for nothing else.
  public static let systemDefault = TimingCurve(0.25, 0.1, 0.25, 1)
  /// Core Animation's `easeIn`.
  public static let easeIn = TimingCurve(0.42, 0, 1, 1)

  /// How much of the way is covered when `fraction` of the time has passed: 0 before the beginning, 1 after the end.
  public func progress(at fraction: Double) -> Double {
    guard fraction > 0 else { return 0 }  // Also what is not a number.
    guard fraction < 1 else { return 1 }
    func along(_ a: Double, _ b: Double, _ t: Double) -> Double {
      let u = 1 - t
      return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
    }
    // x grows with t, so halving the interval always finds the t of this moment. 40 halvings are finer than a Double's digits need.
    var low = 0.0
    var high = 1.0
    var t = fraction
    for _ in 0..<40 {
      let x = along(x1, x2, t)
      if abs(x - fraction) < 1e-10 { break }
      if x < fraction { low = t } else { high = t }
      t = (low + high) / 2
    }
    return along(y1, y2, t)
  }
}
