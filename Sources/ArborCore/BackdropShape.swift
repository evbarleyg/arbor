import CoreGraphics

/// The surface behind docked windows, which Arbor can darken and blur so that the docked area reads
/// as one thing lying on the wallpaper (docs/features/F15-appearance-options.md).
///
/// Every slot grows by half the gap, so neighbours meet in the middle of the gap between them and the
/// surface stops half a gap short of the screen edges and of the Desktop. What is left is a
/// shape made of rectangles, with a hole wherever docked windows surround the Desktop.
public enum BackdropShape {
  /// The rectangles of everything docked and in view: the slots of visible windows, and tiles.
  ///
  /// A slot is its leaf's rectangle, not the window's. A window may sit a few points inside its slot (a
  /// terminal snaps to whole characters) or share it with a tab strip, and neither should leave a hole.
  public static func slots(of layout: Layout, in tree: LayoutTree) -> [CGRect] {
    var slots = layout.tiles.map(\.frame)
    for (window, frame) in layout.windowFrames {
      slots.append(tree.leaf(containing: window).flatMap { layout.nodeFrames[$0] } ?? frame)
    }
    return slots
  }

  /// How far a slot grows: half the gap, rounded up to a whole point. The layout rounds its
  /// boundaries, so with a gap of 12.6 neighbours are 12 or 13 points apart; rounding up makes
  /// them meet all the same, and keeps the surface's edges sharp on a display without Retina.
  public static func growth(forGap gap: CGFloat) -> CGFloat {
    guard gap.isFinite, gap > 0 else { return 0 }
    return (min(gap, 1000) / 2).rounded(.up)
  }

  /// The surface as rectangles that do not overlap: `slots` grown by `growth` and merged, cut off at
  /// `frame`, and never covering `desktop`.
  ///
  /// The result depends only on the area covered, not on how the slots divide it (bands from top to bottom,
  /// each as tall and then as wide as it can be). So two layouts with the same surface compare equal,
  /// and trading two windows' places or dragging the seam between them redraws nothing.
  public static func surface(
    slots: [CGRect], growth: CGFloat, within frame: CGRect, avoiding desktop: CGRect? = nil
  ) -> [CGRect] {
    guard RoundedPath.isDrawable(frame) else { return [] }
    let growth = growth.isFinite ? max(growth, 0) : 0
    let grown = slots.filter(RoundedPath.isDrawable).map { $0.insetBy(dx: -growth, dy: -growth).intersection(frame) }
    var grid = Grid(covering: grown, cutBy: desktop.map { [$0] } ?? [])
    if let desktop { grid.clear(desktop) }
    return grid.rectangles()
  }

  /// A corner of the surface's outline.
  public struct Corner: Equatable, Sendable {
    public var point: CGPoint
    /// True where the surface bulges (its outer corners), false where it turns inward (the inside of an
    /// L, the corners of a hole).
    public var isConvex: Bool
  }

  /// The outlines of the area `rects` cover, each a closed loop of corners with the surface on the right
  /// of the direction of travel: clockwise on screen around the outside, anticlockwise around a hole.
  /// Areas that touch only at a point get separate loops.
  public static func contours(of rects: [CGRect]) -> [[Corner]] {
    Grid(covering: rects, cutBy: []).contours()
  }

  /// The surface's outline with its corners rounded: `cornerRadius` where it bulges, `innerRadius`
  /// where it turns inward. Fill it with the non-zero or the even-odd rule; both leave holes open.
  public static func outline(of rects: [CGRect], cornerRadius: CGFloat, innerRadius: CGFloat) -> [PathElement] {
    contours(of: rects).flatMap { loop in
      RoundedPath.polygon(
        loop.map { RoundedPath.Corner(point: $0.point, radius: $0.isConvex ? cornerRadius : innerRadius) })
    }
  }

  /// The largest radius for an inward corner that keeps the rounding off the Desktop. The Desktop's own
  /// corner lies `growth` inside the hole's on both axes, and a fillet of radius r reaches
  /// (√2 − 1)·r along the diagonal, so r may be up to √2 / (√2 − 1) ≈ 3.4 times `growth`.
  public static func innerRadius(for cornerRadius: CGFloat, growth: CGFloat) -> CGFloat {
    min(cornerRadius, 3 * max(growth, 0))
  }
}

/// The plane cut along every edge of a set of rectangles, with each cell marked covered or not. There are
/// at most a few dozen slots, so the grid is small.
private struct Grid {
  var xs: [CGFloat]
  var ys: [CGFloat]
  /// Row by row; `columns * rows` cells.
  var covered: [Bool]

  var columns: Int { max(xs.count - 1, 0) }
  var rows: Int { max(ys.count - 1, 0) }

  init(covering rects: [CGRect], cutBy others: [CGRect]) {
    let rects = rects.filter(RoundedPath.isDrawable)
    let cuts = rects + others.filter(RoundedPath.isDrawable)
    xs = Array(Set(cuts.flatMap { [$0.minX, $0.maxX] })).sorted()
    ys = Array(Set(cuts.flatMap { [$0.minY, $0.maxY] })).sorted()
    covered = []
    covered = [Bool](repeating: false, count: columns * rows)
    for rect in rects { mark(rect, true) }
  }

  mutating func clear(_ rect: CGRect) {
    if RoundedPath.isDrawable(rect) { mark(rect, false) }
  }

  /// `rect`'s edges are all among `xs` and `ys`.
  private mutating func mark(_ rect: CGRect, _ value: Bool) {
    guard let left = xs.firstIndex(of: rect.minX), let right = xs.firstIndex(of: rect.maxX),
      let top = ys.firstIndex(of: rect.minY), let bottom = ys.firstIndex(of: rect.maxY)
    else { return }
    for row in top..<bottom {
      for column in left..<right { covered[row * columns + column] = value }
    }
  }

  func isCovered(_ column: Int, _ row: Int) -> Bool {
    column >= 0 && column < columns && row >= 0 && row < rows && covered[row * columns + column]
  }

  // MARK: Rectangles

  private struct Span: Hashable {
    var left: Int
    var right: Int
  }

  func rectangles() -> [CGRect] {
    var result: [CGRect] = []
    /// The spans of the row above, and which rectangle each belongs to.
    var open: [Span: Int] = [:]
    for row in 0..<rows {
      var next: [Span: Int] = [:]
      var column = 0
      while column < columns {
        guard isCovered(column, row) else {
          column += 1
          continue
        }
        var end = column
        while isCovered(end, row) { end += 1 }
        let span = Span(left: column, right: end)
        if let index = open[span] {
          result[index].size.height = ys[row + 1] - result[index].minY
          next[span] = index
        } else {
          next[span] = result.count
          result.append(
            CGRect(x: xs[column], y: ys[row], width: xs[end] - xs[column], height: ys[row + 1] - ys[row]))
        }
        column = end
      }
      open = next
    }
    return result
  }

  // MARK: Outlines

  /// In clockwise order on screen (y grows downward).
  private enum Heading: Int {
    case east, south, west, north

    var right: Heading {
      switch self {
      case .east: .south
      case .south: .west
      case .west: .north
      case .north: .east
      }
    }

    var left: Heading { right.right.right }
  }

  func contours() -> [[BackdropShape.Corner]] {
    let width = columns + 1
    /// For every grid point and heading: whether an edge of the outline sets out from there.
    var pending = [Bool](repeating: false, count: width * (rows + 1) * 4)
    func slot(_ column: Int, _ row: Int, _ heading: Heading) -> Int {
      (row * width + column) * 4 + heading.rawValue
    }
    // Walk around each covered cell clockwise, keeping the sides that face an uncovered one.
    for row in 0..<rows {
      for column in 0..<columns where isCovered(column, row) {
        if !isCovered(column, row - 1) { pending[slot(column, row, .east)] = true }
        if !isCovered(column + 1, row) { pending[slot(column + 1, row, .south)] = true }
        if !isCovered(column, row + 1) { pending[slot(column + 1, row + 1, .west)] = true }
        if !isCovered(column - 1, row) { pending[slot(column, row + 1, .north)] = true }
      }
    }

    var loops: [[BackdropShape.Corner]] = []
    for startRow in 0...rows {
      for startColumn in 0...columns {
        for start in [Heading.east, .south, .west, .north] where pending[slot(startColumn, startRow, start)] {
          var corners: [BackdropShape.Corner] = []
          var (column, row, heading) = (startColumn, startRow, start)
          repeat {
            pending[slot(column, row, heading)] = false
            switch heading {
            case .east: column += 1
            case .south: row += 1
            case .west: column -= 1
            case .north: row -= 1
            }
            // Where two areas touch at a point two edges leave; turning right stays with this one.
            guard
              let next = [heading.right, heading, heading.left].first(where: {
                pending[slot(column, row, $0)] || (column == startColumn && row == startRow && $0 == start)
              })
            else { break }  // Cannot happen: every edge that arrives at a point has one that leaves.
            if next != heading {
              corners.append(
                BackdropShape.Corner(point: CGPoint(x: xs[column], y: ys[row]), isConvex: next == heading.right))
            }
            heading = next
          } while !(column == startColumn && row == startRow && heading == start)
          if corners.count >= 4 { loops.append(corners) }
        }
      }
    }
    return loops
  }
}
