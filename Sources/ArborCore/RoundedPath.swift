import CoreGraphics

/// One step of an outline. The core describes every shape Arbor draws this way, so the shapes can be
/// tested; the UI copies the steps into an `NSBezierPath` or a `CGPath`.
public enum PathElement: Equatable, Sendable {
  case move(to: CGPoint)
  case line(to: CGPoint)
  case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
  case close
}

extension Array where Element == PathElement {
  /// The same outline with every point passed through `transform`, e.g. to move it into a view's coordinates.
  public func mapPoints(_ transform: (CGPoint) -> CGPoint) -> [PathElement] {
    map { element in
      switch element {
      case .move(let point): return .move(to: transform(point))
      case .line(let point): return .line(to: transform(point))
      case .curve(let point, let control1, let control2):
        return .curve(to: transform(point), control1: transform(control1), control2: transform(control2))
      case .close: return .close
      }
    }
  }

  /// Every point the outline passes through or is pulled toward. A curve stays inside the hull of its
  /// four points, so a rectangle that holds all of these holds the outline.
  public var points: [CGPoint] {
    flatMap { element -> [CGPoint] in
      switch element {
      case .move(let point), .line(let point): return [point]
      case .curve(let point, let control1, let control2): return [control1, control2, point]
      case .close: return []
      }
    }
  }
}

/// Outlines with rounded corners.
public enum RoundedPath {
  public enum Curve: Equatable, Sendable {
    /// A quarter circle: curvature jumps where it meets the straight edge.
    case circular
    /// The corner macOS and iOS use for windows and icons: it starts earlier and eases into the
    /// curve, so the eye finds no point where the edge ends and the corner begins.
    case continuous

    /// How far along each edge a corner of radius 1 reaches.
    var reach: CGFloat { self == .circular ? 1 : 1.528665 }
  }

  public struct Corner: Equatable, Sendable {
    public var point: CGPoint
    public var radius: CGFloat

    public init(point: CGPoint, radius: CGFloat) {
      self.point = point
      self.radius = radius
    }
  }

  /// A rounded rectangle. Empty for a rectangle without area or with coordinates that are not numbers.
  public static func rect(_ rect: CGRect, radius: CGFloat, curve: Curve = .continuous) -> [PathElement] {
    guard isDrawable(rect) else { return [] }
    let corners = [
      CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
      CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
    ]
    return polygon(corners.map { Corner(point: $0, radius: radius) }, curve: curve)
  }

  /// A rectangle whose short sides are half circles.
  public static func capsule(_ rect: CGRect) -> [PathElement] {
    self.rect(rect, radius: min(rect.width, rect.height) / 2, curve: .circular)
  }

  /// A closed outline through `corners`, each rounded by its own radius whichever way it turns. A
  /// corner never takes more than half of either edge it sits between, so neighbours cannot collide.
  public static func polygon(_ corners: [Corner], curve: Curve = .continuous) -> [PathElement] {
    // A repeated point has no direction to round between.
    var distinct: [Corner] = []
    for corner in corners where corner.point.x.isFinite && corner.point.y.isFinite {
      if distinct.last?.point != corner.point { distinct.append(corner) }
    }
    if distinct.count > 1, distinct.first?.point == distinct.last?.point { distinct.removeLast() }
    guard distinct.count >= 3 else { return [] }

    var elements: [PathElement] = []
    for (index, corner) in distinct.enumerated() {
      let point = corner.point
      let previous = distinct[(index + distinct.count - 1) % distinct.count].point
      let next = distinct[(index + 1) % distinct.count].point
      let (back, backLength) = direction(from: point, to: previous)
      let (ahead, aheadLength) = direction(from: point, to: next)
      let limit = min(backLength, aheadLength) / 2 / curve.reach
      let radius = min(corner.radius.isFinite ? max(corner.radius, 0) : 0, limit)

      /// The point `s` radii back along the incoming edge and `t` radii along the outgoing one.
      func at(_ s: CGFloat, _ t: CGFloat) -> CGPoint {
        CGPoint(
          x: point.x + (back.x * s + ahead.x * t) * radius, y: point.y + (back.y * s + ahead.y * t) * radius)
      }
      let start = radius > 0 ? at(curve.reach, 0) : point
      elements.append(index == 0 ? .move(to: start) : .line(to: start))
      guard radius > 0 else { continue }
      switch curve {
      case .circular:
        let handle: CGFloat = 1 - 0.5522847498  // The usual cubic stand-in for a quarter circle.
        elements.append(.curve(to: at(0, 1), control1: at(handle, 0), control2: at(0, handle)))
      case .continuous:
        elements.append(
          .curve(to: at(0.63149379, 0.07491139), control1: at(1.08849296, 0), control2: at(0.86840694, 0)))
        elements.append(
          .curve(
            to: at(0.07491139, 0.63149379), control1: at(0.37282383, 0.16905956),
            control2: at(0.16905956, 0.37282383)))
        elements.append(
          .curve(to: at(0, curve.reach), control1: at(0, 0.86840694), control2: at(0, 1.08849296)))
      }
    }
    elements.append(.close)
    return elements
  }

  static func isDrawable(_ rect: CGRect) -> Bool {
    rect.minX.isFinite && rect.minY.isFinite && rect.maxX.isFinite && rect.maxY.isFinite && rect.width > 0
      && rect.height > 0
  }

  private static func direction(from a: CGPoint, to b: CGPoint) -> (unit: CGPoint, length: CGFloat) {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let length = (dx * dx + dy * dy).squareRoot()
    guard length > 0, length.isFinite else { return (.zero, 0) }
    return (CGPoint(x: dx / length, y: dy / length), length)
  }
}
