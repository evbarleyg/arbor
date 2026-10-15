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

  /// How much of this rectangle `screens` show, all together, in square points. **The one measure of how much of a window
  /// shows**, for Arbor, the lab's nets and the stand-ins alike. A window across the border of two displays shows on both, so
  /// no display is asked by itself: 37 % here and 42 % there are 79 % in view, not "less than half".
  ///
  /// `screens` are the displays' whole frames. What lies behind the menu bar or the Dock is where macOS lets a person put a
  /// window, and counts as showing (QUESTIONS, 2026-10-15). What two screens both show, should they ever overlap, counts once.
  public func areaShowing(on screens: [CGRect]) -> CGFloat {
    let parts = screens.map { intersection($0) }.filter { $0.area > 0 }
    guard parts.count > 1 else { return parts.first?.area ?? 0 }
    let columns = Set(parts.flatMap { [$0.minX, $0.maxX] }).sorted()
    let rows = Set(parts.flatMap { [$0.minY, $0.maxY] }).sorted()
    var showing: CGFloat = 0
    for (left, right) in zip(columns, columns.dropFirst()) {
      for (top, bottom) in zip(rows, rows.dropFirst())
      where parts.contains(where: { $0.contains(CGPoint(x: (left + right) / 2, y: (top + bottom) / 2)) }) {
        showing += (right - left) * (bottom - top)
      }
    }
    return showing
  }

  /// Less than half of it shows, on all of `screens` together: a window that is as good as out of view.
  public func showsLessThanHalf(on screens: [CGRect]) -> Bool { area <= 0 || areaShowing(on: screens) * 2 < area }

  /// Where a window that is here now may have been before the screens changed. What a change of displays took from a window is
  /// what it had there and has no more: its title bar within reach, so much of it showing.
  ///
  /// Worked out afterwards, from the screens alone. Not noted beforehand: an app may say where its window is now before
  /// anybody can know that the displays are changing, or say nothing, and new numbers on old screens read as all or as nothing.
  ///
  /// macOS takes a window along with its display: the one that shows most of it. Which one that was cannot be read off afterwards:
  /// the one that shows most of it now may be a neighbour it was carried onto, or that has moved under it. So each screen that is
  /// there before and after is asked: had the window been yours, it was where it is, moved back as far as your corner has
  /// moved; did you show most of it there? All that did are answers. Not a screen that has gone: its windows have been
  /// taken elsewhere. And nobody may have taken it anywhere, if its app hangs for one: where it is is always an answer.
  public func whereItMayHaveBeen<ID: Hashable>(on earlier: [ID: CGRect], whichAreNow now: [ID: CGRect]) -> [CGRect] {
    [self]
      + earlier.compactMap { id, old -> CGRect? in
        guard let new = now[id], new.origin != old.origin else { return nil }
        let there = offsetBy(dx: old.minX - new.minX, dy: old.minY - new.minY)
        let own = there.areaShowing(on: [old])
        return own > 0 && earlier.values.allSatisfy({ there.areaShowing(on: [$0]) <= own }) ? there : nil
      }
  }

  /// Whether a hand could get hold of a window with this frame: the other question, with a measure of its own. However much
  /// of a window shows, nobody moves it but by its title bar, and that has to be on one screen: parts do not add up.
  ///
  /// 24 points of the title bar's length, or all of a window narrower than that. The strip asked about is the window's top
  /// 24 points, less than the lowest title bar there is (28, 32 and 52 points were measured), so nobody needs to know how
  /// high this one's is; half of that is enough to hit.
  ///
  /// `screens` are the whole frames here too. By what the menu bar and the Dock leave, a window some apps open at the very top
  /// would be out of reach at every start, and so would one parked over the edge above or below a Dock at the side, which a
  /// hand can take. In doubt Arbor moves less (QUESTIONS, 2026-10-15).
  public func titleBarIsWithinReach(on screens: [CGRect]) -> Bool {
    let bar = CGRect(x: minX, y: minY, width: width, height: Swift.min(height, Self.titleBarToHold))
    return screens.contains {
      let showing = bar.intersection($0)
      return !showing.isNull && showing.width >= Swift.min(bar.width, Self.titleBarToHold) && showing.height >= bar.height / 2
    }
  }

  /// The least of a title bar that a hand can take hold of, in points.
  public static let titleBarToHold: CGFloat = 24

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
