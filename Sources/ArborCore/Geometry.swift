import CoreGraphics

// Arbor works in global screen coordinates with the origin at the top-left
// corner of the primary display and y growing downward. That is the space the
// Accessibility API and CGWindowList use. Conversions to AppKit's bottom-left
// space happen only inside ArborKit's UI code.

/// The direction a split lays out its children.
public enum Axis: String, Codable, Sendable, CaseIterable {
  /// Children run left to right.
  case horizontal
  /// Children run top to bottom.
  case vertical

  public var perpendicular: Axis { self == .horizontal ? .vertical : .horizontal }
}

/// A side of a rectangle. Also used as a direction (top = up, bottom = down).
public enum Edge: String, Codable, Sendable, CaseIterable {
  case left, right, top, bottom

  /// The axis an edge moves along: left/right are horizontal, top/bottom vertical.
  public var axis: Axis { self == .left || self == .right ? .horizontal : .vertical }

  /// True for the edge nearer the origin (left, top).
  public var isLeading: Bool { self == .left || self == .top }

  public var opposite: Edge {
    switch self {
    case .left: .right
    case .right: .left
    case .top: .bottom
    case .bottom: .top
    }
  }

  /// Parses user-facing words such as "left", "up" or "down".
  public init?(word: String) {
    switch word.lowercased() {
    case "left", "l", "west": self = .left
    case "right", "r", "east": self = .right
    case "top", "up", "u", "north": self = .top
    case "bottom", "down", "d", "south": self = .bottom
    default: return nil
    }
  }
}

extension CGRect {
  public var center: CGPoint { CGPoint(x: midX, y: midY) }

  public var area: CGFloat { isNull || isEmpty ? 0 : width * height }

  public func length(along axis: Axis) -> CGFloat { axis == .horizontal ? width : height }

  /// The fraction of this rectangle's area that lies inside `other`, from 0 to 1.
  public func fractionInside(_ other: CGRect) -> CGFloat {
    guard area > 0 else { return 0 }
    let overlap = intersection(other)
    return overlap.isNull ? 0 : overlap.area / area
  }

  /// Intersection area divided by union area, from 0 to 1.
  public func intersectionOverUnion(_ other: CGRect) -> CGFloat {
    let overlap = intersection(other)
    guard !overlap.isNull else { return 0 }
    let union = area + other.area - overlap.area
    return union > 0 ? overlap.area / union : 0
  }

  /// Whether the rectangles share any area; touching edges or corners do not count. Use this
  /// instead of `intersects`, which counts touching rectangles on Linux but not on macOS.
  public func overlaps(_ other: CGRect) -> Bool {
    Swift.min(maxX, other.maxX) > Swift.max(minX, other.minX)
      && Swift.min(maxY, other.maxY) > Swift.max(minY, other.minY)
  }

  /// Shrinks this rectangle to fit inside `container` if needed, then moves it
  /// the shortest distance that puts it fully inside.
  public func fitted(into container: CGRect) -> CGRect {
    var r = self
    r.size.width = Swift.min(r.width, container.width)
    r.size.height = Swift.min(r.height, container.height)
    r.origin.x = Swift.min(Swift.max(r.minX, container.minX), container.maxX - r.width)
    r.origin.y = Swift.min(Swift.max(r.minY, container.minY), container.maxY - r.height)
    return r
  }

  public func approximatelyEquals(_ other: CGRect, tolerance: CGFloat = 1) -> Bool {
    abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance
      && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
  }

  /// Distance from `point` to the nearest point of this rectangle (0 if inside).
  public func distance(to point: CGPoint) -> CGFloat {
    let dx = Swift.max(minX - point.x, 0, point.x - maxX)
    let dy = Swift.max(minY - point.y, 0, point.y - maxY)
    return (dx * dx + dy * dy).squareRoot()
  }

  /// This rectangle with every edge rounded to whole points.
  public var integralRounded: CGRect {
    let x0 = minX.rounded(), y0 = minY.rounded()
    let x1 = maxX.rounded(), y1 = maxY.rounded()
    return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
  }
}
