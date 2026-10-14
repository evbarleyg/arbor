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
