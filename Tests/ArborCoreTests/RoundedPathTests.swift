import ArborCore
import CoreGraphics
import Testing

@Suite struct RoundedPathTests {
  let box = CGRect(x: 10, y: 20, width: 200, height: 120)

  /// Where each element ends, in order.
  func stops(_ path: [PathElement]) -> [CGPoint] {
    path.compactMap { element in
      switch element {
      case .move(let point), .line(let point): return point
      case .curve(let point, _, _): return point
      case .close: return nil
      }
    }
  }

  func curveCount(_ path: [PathElement]) -> Int {
    path.filter { if case .curve = $0 { return true } else { return false } }.count
  }

  func holds(_ rect: CGRect, _ path: [PathElement]) -> Bool {
    path.points.allSatisfy {
      $0.x >= rect.minX - 1e-9 && $0.x <= rect.maxX + 1e-9 && $0.y >= rect.minY - 1e-9 && $0.y <= rect.maxY + 1e-9
    }
  }

  @Test(arguments: [RoundedPath.Curve.circular, .continuous])
  func aRoundedRectangleIsOneClosedOutlineThatFillsItsRectangle(curve: RoundedPath.Curve) {
    let path = RoundedPath.rect(box, radius: 12, curve: curve)
    guard case .move = path.first, path.last == .close else {
      Issue.record("the outline must start with a move and end closed")
      return
    }
    #expect(path.dropFirst().allSatisfy { if case .move = $0 { return false } else { return true } })
    #expect(curveCount(path) == (curve == .circular ? 4 : 12))
    #expect(holds(box, path))
    let xs = stops(path).map(\.x)
    let ys = stops(path).map(\.y)
    #expect(xs.min() == box.minX && xs.max() == box.maxX && ys.min() == box.minY && ys.max() == box.maxY)
  }

  @Test func aContinuousCornerStartsEarlierThanACircularOne() {
    // Both leave the top edge for the top-right corner; the first stop after the move is where.
    let circular = stops(RoundedPath.rect(box, radius: 12, curve: .circular))
    let continuous = stops(RoundedPath.rect(box, radius: 12, curve: .continuous))
    #expect(circular.contains(CGPoint(x: box.maxX - 12, y: box.minY)))
    #expect(continuous.contains { abs($0.x - (box.maxX - 12 * 1.528665)) < 1e-6 && $0.y == box.minY })
  }

  @Test func theFourCornersMirrorEachOther() {
    let points = RoundedPath.rect(box, radius: 12).points
    func has(_ point: CGPoint) -> Bool { points.contains { abs($0.x - point.x) < 1e-6 && abs($0.y - point.y) < 1e-6 } }
    for point in points {
      #expect(has(CGPoint(x: box.minX + box.maxX - point.x, y: point.y)))
      #expect(has(CGPoint(x: point.x, y: box.minY + box.maxY - point.y)))
    }
  }

  @Test func withoutARadiusTheCornersArePlain() {
    #expect(
      RoundedPath.rect(box, radius: 0) == [
        .move(to: CGPoint(x: 10, y: 20)), .line(to: CGPoint(x: 210, y: 20)), .line(to: CGPoint(x: 210, y: 140)),
        .line(to: CGPoint(x: 10, y: 140)), .close,
      ])
    #expect(RoundedPath.rect(box, radius: -5) == RoundedPath.rect(box, radius: 0))
    #expect(RoundedPath.rect(box, radius: .nan) == RoundedPath.rect(box, radius: 0))
  }

  @Test(arguments: [RoundedPath.Curve.circular, .continuous])
  func aRadiusTooLargeForTheSidesIsCutDown(curve: RoundedPath.Curve) {
    let small = CGRect(x: 0, y: 0, width: 30, height: 10)
    let path = RoundedPath.rect(small, radius: 500, curve: curve)
    #expect(holds(small, path))
    // Along the top edge the left corner ends before the right one begins.
    let top = stops(path).filter { $0.y == 0 }.map(\.x)
    #expect(top.count >= 2 && top.min()! <= 15 && top.max()! >= 15)
    // On the short sides the two corners meet in the middle and go no further.
    let left = stops(path).filter { $0.x == 0 }.map(\.y)
    #expect(left.allSatisfy { abs($0 - 5) < 1e-9 })
  }

  @Test func aCapsuleEndsInHalfCircles() {
    let pill = CGRect(x: 4, y: 100, width: 4, height: 36)
    let path = RoundedPath.capsule(pill)
    #expect(holds(pill, path))
    #expect(curveCount(path) == 4)
    let points = stops(path)
    // The curves take two points at each end, leaving straight sides of 32.
    #expect(points.contains(CGPoint(x: 4, y: 102)) && points.contains(CGPoint(x: 4, y: 134)))
    #expect(points.contains(CGPoint(x: 8, y: 102)) && points.contains(CGPoint(x: 8, y: 134)))
    #expect(points.contains(CGPoint(x: 6, y: 100)) && points.contains(CGPoint(x: 6, y: 136)))
  }

  @Test func cornersThatTurnInwardAreRoundedToo() {
    // An L: the corner at (100, 100) turns inward.
    let corners = [(0, 0), (200, 0), (200, 100), (100, 100), (100, 200), (0, 200)].map {
      RoundedPath.Corner(point: CGPoint(x: $0.0, y: $0.1), radius: 10)
    }
    let path = RoundedPath.polygon(corners, curve: .circular)
    #expect(curveCount(path) == 6)
    let points = stops(path)
    #expect(points.contains(CGPoint(x: 110, y: 100)) && points.contains(CGPoint(x: 100, y: 110)))
    #expect(!points.contains(CGPoint(x: 100, y: 100)))
  }

  @Test func eachCornerHasItsOwnRadius() {
    let corners = [
      RoundedPath.Corner(point: CGPoint(x: 0, y: 0), radius: 0),
      RoundedPath.Corner(point: CGPoint(x: 100, y: 0), radius: 20),
      RoundedPath.Corner(point: CGPoint(x: 100, y: 100), radius: 0),
      RoundedPath.Corner(point: CGPoint(x: 0, y: 100), radius: 5),
    ]
    let points = stops(RoundedPath.polygon(corners, curve: .circular))
    #expect(points.contains(CGPoint(x: 0, y: 0)) && points.contains(CGPoint(x: 100, y: 100)))
    #expect(points.contains(CGPoint(x: 80, y: 0)) && points.contains(CGPoint(x: 100, y: 20)))
    #expect(points.contains(CGPoint(x: 5, y: 100)) && points.contains(CGPoint(x: 0, y: 95)))
  }

  @Test func shapesThatCannotBeDrawnGiveNothing() {
    #expect(RoundedPath.rect(.zero, radius: 4).isEmpty)
    #expect(RoundedPath.rect(.null, radius: 4).isEmpty)
    #expect(RoundedPath.rect(CGRect(x: 0, y: 0, width: 10, height: 0), radius: 4).isEmpty)
    #expect(RoundedPath.rect(CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10), radius: 4).isEmpty)
    #expect(RoundedPath.rect(CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10), radius: 4).isEmpty)
    #expect(RoundedPath.capsule(.zero).isEmpty)
    #expect(RoundedPath.polygon([]).isEmpty)
    let point = RoundedPath.Corner(point: CGPoint(x: 1, y: 1), radius: 3)
    #expect(RoundedPath.polygon([point, point, point, point]).isEmpty, "the same point four times is no outline")
  }

  @Test func pointsCanBeMovedIntoAnotherCoordinateSpace() {
    let path = RoundedPath.rect(box, radius: 12)
    let moved = path.mapPoints { CGPoint(x: $0.x - 10, y: 140 - $0.y) }
    #expect(moved.count == path.count)
    #expect(holds(CGRect(x: 0, y: 0, width: 200, height: 120), moved))
    #expect(
      [PathElement.move(to: CGPoint(x: 1, y: 2)), .curve(to: .zero, control1: CGPoint(x: 3, y: 4), control2: .zero), .close]
        .mapPoints { CGPoint(x: $0.x * 2, y: -$0.y) } == [
          .move(to: CGPoint(x: 2, y: -2)), .curve(to: .zero, control1: CGPoint(x: 6, y: -4), control2: .zero), .close,
        ])
  }
}
