import Testing

@testable import ArborCore

@Suite struct TimingCurveTests {
  @Test func beginsAtNothingAndEndsAtAll() {
    for curve in [TimingCurve.motion, .linear, .systemDefault, .easeIn] {
      #expect(curve.progress(at: 0) == 0)
      #expect(curve.progress(at: 1) == 1)
      #expect(curve.progress(at: -3) == 0)
      #expect(curve.progress(at: 7) == 1)
      #expect(curve.progress(at: .nan) == 0)
      #expect(curve.progress(at: .infinity) == 1)
    }
  }

  @Test func aStraightLineIsTheTimeItself() {
    for step in 0...20 {
      let time = Double(step) / 20
      #expect(abs(TimingCurve.linear.progress(at: time) - time) < 1e-6)
    }
  }

  @Test func neverGoesBackAndNeverOvershoots() {
    for curve in [TimingCurve.motion, .systemDefault, .easeIn] {
      var last = 0.0
      for step in 0...600 {
        let value = curve.progress(at: Double(step) / 600)
        #expect(value >= last - 1e-9)
        #expect((0...1).contains(value))
        last = value
      }
    }
  }

  /// Each value lies on the curve: there is a t that gives both the time and the way covered.
  @Test func liesOnTheBézierCurve() {
    let curve = TimingCurve.motion
    for step in 1..<50 {
      let t = Double(step) / 50
      let u = 1 - t
      let x = 3 * u * u * t * curve.x1 + 3 * u * t * t * curve.x2 + t * t * t
      let y = 3 * u * u * t * curve.y1 + 3 * u * t * t * curve.y2 + t * t * t
      #expect(abs(curve.progress(at: x) - y) < 1e-6)
    }
  }

  /// A fast start and a gentle settle: seven tenths of the way are covered in the first third of the time.
  @Test func arborsMotionStartsFastAndSettlesGently() {
    #expect(TimingCurve.motion.progress(at: 1.0 / 3) > 0.7)
    #expect(TimingCurve.motion.progress(at: 0.5) > 0.85)
    #expect(TimingCurve.motion == TimingCurve(0.2, 0, 0, 1))
  }

  @Test func timeCannotRunBackwards() {
    let curve = TimingCurve(-2, 0.5, 9, .nan)
    #expect(curve.x1 == 0)
    #expect(curve.x2 == 1)
    #expect(curve.y2 == 1)
  }
}
