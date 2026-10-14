import CoreGraphics

/// Finding what lies in a direction from a rectangle, judged by geometry. `focus <direction>` and
/// `swap <direction>` use it for windows and tiles, and `focus` again for displays
/// (docs/features/F22-keyboard-tiling-tools.md).
public enum DirectionalSearch {
  public struct Candidate<ID: Hashable & Sendable>: Equatable, Sendable {
    public var id: ID
    public var frame: CGRect
    /// How long ago it had keyboard focus: 0 is the most recent, `Int.max` never.
    public var recency: Int

    public init(id: ID, frame: CGRect, recency: Int = .max) {
      self.id = id
      self.frame = frame
      self.recency = recency
    }
  }

  /// A candidate is beside the origin, rather than diagonal to it, when the span they share across
  /// the direction of travel is at least this share of the shorter of the two.
  public static let alignedShare: CGFloat = 0.25
  /// Distances and overlaps this close count as equal. Slots across one seam can differ by a point of rounding.
  public static let tolerance: CGFloat = 2

  /// The candidate to go to from `origin` toward `direction`, or nil if none lies that way.
  ///
  /// A candidate lies that way when its centre is past the origin's edge on that side, so a floating
  /// window that overlaps the origin still counts. One that lies over the origin, or under it, also counts the way its
  /// centre lies from the origin's centre: a small window inside a large one is past none of its edges.
  /// Candidates beside the origin (`alignedShare`) come
  /// before diagonal ones. Among those the nearest wins, so nothing in between is jumped over; then the
  /// one sharing the longest span with the origin; then the most recently focused; then the topmost,
  /// the leftmost, and the earliest in `candidates`.
  public static func nearest<ID>(
    from origin: CGRect, toward direction: Edge, among candidates: [Candidate<ID>]
  ) -> Candidate<ID>? {
    var measured: [Measured<ID>] = []
    for candidate in candidates {
      let frame = candidate.frame
      guard frame.width > 0, frame.height > 0 else { continue }
      let liesOver = frame.overlaps(origin)
      let along: CGFloat
      switch direction {
      case .left:
        guard frame.midX <= origin.minX || (liesOver && frame.midX < origin.midX - tolerance) else { continue }
        along = origin.minX - frame.maxX
      case .right:
        guard frame.midX >= origin.maxX || (liesOver && frame.midX > origin.midX + tolerance) else { continue }
        along = frame.minX - origin.maxX
      case .top:
        guard frame.midY <= origin.minY || (liesOver && frame.midY < origin.midY - tolerance) else { continue }
        along = origin.minY - frame.maxY
      case .bottom:
        guard frame.midY >= origin.maxY || (liesOver && frame.midY > origin.midY + tolerance) else { continue }
        along = frame.minY - origin.maxY
      }
      let shared: CGFloat
      let shorter: CGFloat
      if direction.axis == .horizontal {
        shared = min(origin.maxY, frame.maxY) - max(origin.minY, frame.minY)
        shorter = min(origin.height, frame.height)
      } else {
        shared = min(origin.maxX, frame.maxX) - max(origin.minX, frame.minX)
        shorter = min(origin.width, frame.width)
      }
      // The gap between the rectangles: straight across for one beside the origin, corner to corner otherwise.
      let gapAlong = max(along, 0)
      let gapAcross = max(-shared, 0)
      measured.append(
        Measured(
          candidate: candidate, distance: (gapAlong * gapAlong + gapAcross * gapAcross).squareRoot(),
          overlap: max(shared, 0), isAligned: shared > 0 && shared >= alignedShare * shorter))
    }

    var pool = measured.contains(where: \.isAligned) ? measured.filter(\.isAligned) : measured
    guard let least = pool.map(\.distance).min() else { return nil }
    pool = pool.filter { $0.distance <= least + tolerance }
    let most = pool.map(\.overlap).max() ?? 0
    pool = pool.filter { $0.overlap >= most - tolerance }
    let latest = pool.map(\.candidate.recency).min() ?? .max
    pool = pool.filter { $0.candidate.recency == latest }
    return pool.min { a, b in
      (a.candidate.frame.minY, a.candidate.frame.minX) < (b.candidate.frame.minY, b.candidate.frame.minX)
    }?.candidate
  }

  private struct Measured<ID: Hashable & Sendable> {
    var candidate: Candidate<ID>
    var distance: CGFloat
    var overlap: CGFloat
    var isAligned: Bool
  }

  /// `frame` slid along the direction of travel until it touches `view` from outside, on the side one
  /// enters from. Searching from there finds what is nearest the edge one came through, level with
  /// where one was.
  public static func approaching(_ view: CGRect, from frame: CGRect, toward direction: Edge) -> CGRect {
    var start = frame
    switch direction {
    case .left: start.origin.x = view.maxX
    case .right: start.origin.x = view.minX - frame.width
    case .top: start.origin.y = view.maxY
    case .bottom: start.origin.y = view.minY - frame.height
    }
    return start
  }

  /// The edge of `destination` that faces `source`: where something sent from one display to another arrives.
  public static func facingEdge(of destination: CGRect, from source: CGRect) -> Edge {
    let dx = destination.midX - source.midX
    let dy = destination.midY - source.midY
    if abs(dx) >= abs(dy) { return dx >= 0 ? .left : .right }
    return dy >= 0 ? .top : .bottom
  }
}
