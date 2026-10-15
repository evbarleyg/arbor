import ArborCore
import CoreGraphics
import Foundation
import Testing

/// `CGRect` comes from CoreGraphics on macOS and from Foundation on Linux, and the two disagree at
/// the boundaries. These tests run on both and pin what Arbor relies on.
@Suite struct GeometryTests {
  let square = CGRect(x: 0, y: 0, width: 10, height: 10)

  @Test func overlappingNeedsSharedArea() {
    #expect(square.overlaps(CGRect(x: 9, y: 9, width: 10, height: 10)))
    #expect(square.overlaps(CGRect(x: 2, y: 2, width: 3, height: 3)))
    #expect(CGRect(x: 2, y: 2, width: 3, height: 3).overlaps(square))
    #expect(square.overlaps(square))
    #expect(!square.overlaps(CGRect(x: 11, y: 0, width: 10, height: 10)))
  }

  @Test func touchingRectanglesDoNotOverlap() {
    #expect(!square.overlaps(CGRect(x: 10, y: 0, width: 10, height: 10)))
    #expect(!square.overlaps(CGRect(x: -10, y: 0, width: 10, height: 10)))
    #expect(!square.overlaps(CGRect(x: 0, y: 10, width: 10, height: 10)))
    #expect(!square.overlaps(CGRect(x: 10, y: 10, width: 10, height: 10)))
  }

  @Test func rectanglesWithoutAreaOverlapNothing() {
    #expect(!square.overlaps(CGRect(x: 5, y: 0, width: 0, height: 10)))
    #expect(!square.overlaps(CGRect(x: 5, y: 5, width: 0, height: 0)))
    #expect(!square.overlaps(.null))
    #expect(!CGRect.null.overlaps(square))
    #expect(!square.overlaps(.zero))
  }

  @Test func touchingRectanglesShareNoArea() {
    let beside = CGRect(x: 10, y: 0, width: 10, height: 10)
    #expect(square.fractionInside(beside) == 0)
    #expect(square.intersectionOverUnion(beside) == 0)
    #expect(square.fractionInside(CGRect(x: 5, y: 0, width: 10, height: 10)) == 0.5)
  }

  // MARK: How much of a window shows

  private static let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)
  private static let monitor = CGRect(x: 1512, y: -200, width: 2560, height: 1440)

  /// Across two displays and below the laptop's lower edge: 36.8 % here, 42.3 % there.
  @Test func whatSeveralScreensShowAddsUp() {
    let window = CGRect(x: 1050, y: 600, width: 800, height: 600)
    #expect(window.areaShowing(on: [Self.laptop]) == CGFloat(462 * 382))
    #expect(window.areaShowing(on: [Self.monitor]) == CGFloat(338 * 600))
    #expect(window.areaShowing(on: [Self.laptop, Self.monitor]) == CGFloat(462 * 382 + 338 * 600))
    #expect(window.showsLessThanHalf(on: [Self.laptop]) && window.showsLessThanHalf(on: [Self.monitor]))
    #expect(!window.showsLessThanHalf(on: [Self.laptop, Self.monitor]))
    #expect(!window.showsLessThanHalf(on: [Self.monitor, Self.laptop]), "in whatever order")
  }

  @Test func halfIsNotLessThanHalf() {
    #expect(!square.showsLessThanHalf(on: [CGRect(x: 5, y: 0, width: 10, height: 10)]))
    #expect(square.showsLessThanHalf(on: [CGRect(x: 5.1, y: 0, width: 10, height: 10)]))
    // A quarter and a quarter.
    let quarters = [CGRect(x: -10, y: -10, width: 15, height: 15), CGRect(x: 5, y: 5, width: 15, height: 15)]
    #expect(square.areaShowing(on: quarters) == 50)
    #expect(!square.showsLessThanHalf(on: quarters))
  }

  @Test func whereThereIsNothingToShowItOnNothingShows() {
    #expect(square.areaShowing(on: []) == 0)
    #expect(square.showsLessThanHalf(on: []))
    #expect(square.areaShowing(on: [CGRect(x: 10, y: 0, width: 10, height: 10)]) == 0, "touching is not showing")
    #expect(square.areaShowing(on: [.null, .zero]) == 0)
    #expect(CGRect.zero.areaShowing(on: [square]) == 0)
    #expect(CGRect.zero.showsLessThanHalf(on: [square]), "a window without area is not in view")
    #expect(CGRect.null.showsLessThanHalf(on: [square]))
  }

  /// Displays do not overlap. Should two ever be reported that do (mirrored, or half way through a change), a third of a
  /// window shown twice is still a third.
  @Test func whatTwoScreensBothShowCountsOnce() {
    let third = CGRect(x: 0, y: 0, width: 10, height: 3)
    #expect(square.areaShowing(on: [third, third]) == 30)
    #expect(square.showsLessThanHalf(on: [third, third]))
    let staggered = [CGRect(x: -5, y: 0, width: 9, height: 10), CGRect(x: 2, y: 0, width: 4, height: 20), CGRect(x: 3, y: 5, width: 1, height: 1)]
    #expect(square.areaShowing(on: staggered) == 60)
    #expect(square.areaShowing(on: [square, square.insetBy(dx: -5, dy: -5)]) == square.area, "never more than all of it")
  }

  // MARK: Whether a hand could get hold of it

  @Test func twentyFourPointsOfTheTitleBarAreWithinReachAndTwentyThreeAreNot() {
    func window(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(x: x, y: y, width: 800, height: 600) }
    #expect(window(300, 200).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(window(1512 - 24, 200).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!window(1512 - 23, 200).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(window(24 - 800, 200).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!window(23 - 800, 200).titleBarIsWithinReach(on: [Self.laptop]))
    // Half of the strip's height is enough to hit: at the bottom, and at the top.
    #expect(window(300, 982 - 12).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!window(300, 982 - 11).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(window(300, -12).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!window(300, -13).titleBarIsWithinReach(on: [Self.laptop]), "nearly all of it shows, and nobody can move it")
    #expect(!window(300, 200).titleBarIsWithinReach(on: []))
  }

  @Test func anyScreenWillDoForTheTitleBarButTheyDoNotAddUp() {
    let window = CGRect(x: 1400, y: -100, width: 800, height: 600)
    #expect(!window.titleBarIsWithinReach(on: [Self.laptop]), "above the laptop's display")
    #expect(window.titleBarIsWithinReach(on: [Self.laptop, Self.monitor]), "and within reach on the one next to it")
    // Twelve points here and twelve there are nothing to take hold of.
    let ends = [CGRect(x: 0, y: 0, width: 12, height: 100), CGRect(x: 788, y: 0, width: 100, height: 100)]
    #expect(!CGRect(x: 0, y: 0, width: 800, height: 600).titleBarIsWithinReach(on: ends))
  }

  @Test func allOfAWindowNarrowerOrLowerThanThatIsEnough() {
    #expect(CGRect(x: 100, y: 100, width: 10, height: 600).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!CGRect(x: -1, y: 100, width: 10, height: 600).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(CGRect(x: 100, y: 100, width: 600, height: 10).titleBarIsWithinReach(on: [Self.laptop]))
    // A window without area that is on a screen is not for ever out of reach.
    #expect(CGRect(x: 100, y: 100, width: 0, height: 0).titleBarIsWithinReach(on: [Self.laptop]))
    #expect(!CGRect(x: -100, y: 100, width: 0, height: 0).titleBarIsWithinReach(on: [Self.laptop]))
  }

  @Test func aRectangleHoldsItsNearEdgesButNotItsFarOnes() {
    #expect(square.contains(CGPoint(x: 0, y: 0)))
    #expect(square.contains(CGPoint(x: 9.5, y: 9.5)))
    #expect(!square.contains(CGPoint(x: 10, y: 5)))
    #expect(!square.contains(CGPoint(x: 5, y: 10)))
    #expect(square.contains(square))
    #expect(!square.contains(CGRect(x: 1, y: 1, width: 10, height: 5)))
  }

  /// Why `LayoutEngine` does not use `insetBy` for its margins: an inset larger than the rectangle
  /// gives the null rectangle, whose origin is infinite.
  @Test func insettingBeyondTheMiddleGivesTheNullRectangle() {
    let inset = square.insetBy(dx: 6, dy: 1)
    #expect(inset.isNull)
    #expect(inset.minX == .infinity)
    #expect(!square.insetBy(dx: 5, dy: 5).isNull)
  }

  @Test func aNegativeSizeReachesBackFromTheOrigin() {
    let backwards = CGRect(x: 10, y: 10, width: -4, height: -6)
    #expect(backwards.width == 4 && backwards.height == 6)
    #expect(backwards.minX == 6 && backwards.maxX == 10 && backwards.minY == 4 && backwards.maxY == 10)
    #expect(backwards.standardized == CGRect(x: 6, y: 4, width: 4, height: 6))
    #expect(CGRect.null.standardized.isNull)
  }

  @Test func roundingGoesAwayFromZeroAtAHalf() {
    #expect((0.5 as CGFloat).rounded() == 1 && (-0.5 as CGFloat).rounded() == -1)
    #expect(CGRect(x: -0.5, y: 0.5, width: 1, height: 1).integralRounded == CGRect(x: -1, y: 1, width: 2, height: 1))
  }

  /// Weights and frames are saved as JSON numbers and must come back as the very same numbers.
  @Test func numbersSurviveJSONExactly() throws {
    var random = SeededRandom(seed: 9)
    var numbers: [Double] = [0.1 + 0.2, 1.0 / 3, 1e-6, 1e15 + 0.5, 1e-300, 1e300, -0.0]
    for _ in 0..<500 { numbers.append(Double.random(in: 0...2, using: &random)) }
    #expect(try JSONDecoder().decode([Double].self, from: JSONEncoder().encode(numbers)) == numbers)
    #expect(throws: EncodingError.self) { try JSONEncoder().encode([Double.nan]) }
    #expect(throws: EncodingError.self) { try JSONEncoder().encode([CGRect.null]) }
  }

  /// `state.json`, `arborctl state` and recorded traces hold frames, so the form must not depend on
  /// where they were written.
  @Test func framesEncodeTheSameEverywhere() throws {
    let frame = CGRect(x: 1.5, y: -2, width: 640, height: 420)
    let json = String(decoding: try JSONEncoder().encode(frame), as: UTF8.self)
    #expect(json == "[[1.5,-2],[640,420]]")
    #expect(try JSONDecoder().decode(CGRect.self, from: Data(json.utf8)) == frame)
  }
}
