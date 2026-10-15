import CoreGraphics

/// Where a gap's handle belongs among the windows.
///
/// The gap between two docked neighbours is the arrangement's. A floating window that lies behind both of them shows through
/// it, and would get the press that is meant for the gap: it would come to the front over both, and no gap would move. What
/// lies in front of either neighbour was put there by somebody, and keeps its clicks. So the handle lies just below the
/// rearmost of its neighbours: over whatever is behind them, under whatever is not.
extension Seam {
  /// A point's width of what lies along the gap, before it and after it.
  private var banks: (before: CGRect, after: CGRect) {
    axis == .horizontal
      ? (
        CGRect(x: frame.minX - 1, y: frame.minY, width: 1, height: frame.height),
        CGRect(x: frame.maxX, y: frame.minY, width: 1, height: frame.height)
      )
      : (
        CGRect(x: frame.minX, y: frame.minY - 1, width: frame.width, height: 1),
        CGRect(x: frame.minX, y: frame.maxY, width: frame.width, height: 1)
      )
  }

  /// The docked windows beside the gap: those whose slot touches it, before it and after it. A group has as many as reach the gap.
  /// By their slots: a window that is not in its slot (its app hangs, it is smaller than its slot) counts as if it were.
  public func neighbours(among slots: [WindowID: CGRect]) -> (leading: [WindowID], trailing: [WindowID]) {
    func touching(_ bank: CGRect) -> [WindowID] { slots.filter { $0.value.overlaps(bank) }.keys.sorted() }
    return (touching(banks.before), touching(banks.after))
  }

  /// The window the handle is to lie just below, going by how the windows are stacked, frontmost first.
  ///
  /// Nil sends it behind everything, where it was before there was such a rule. If there is no window on one side; if any of the
  /// `others` lies along the gap, be it for a part of one side (the Desktop, a tile, a place that waits for its window): all of these
  /// lie behind everything themselves, and what stands on them stands in plain view and is meant by whoever presses it; or if the
  /// order does not tell of every neighbour, so that nobody knows which is the rearmost.
  public func rearmostNeighbour(
    among slots: [WindowID: CGRect], besides others: [CGRect] = [], frontToBack order: [WindowID]
  ) -> WindowID? {
    let (leading, trailing) = neighbours(among: slots)
    guard !leading.isEmpty, !trailing.isEmpty else { return nil }
    guard !others.contains(where: { $0.overlaps(banks.before) || $0.overlaps(banks.after) }) else { return nil }
    var rearmost: (window: WindowID, place: Int)?
    for window in leading + trailing {
      guard let place = order.firstIndex(of: window) else { return nil }
      if place > rearmost?.place ?? -1 { rearmost = (window, place) }
    }
    return rearmost?.window
  }
}

extension Layout {
  /// The window that the handle of one of its gaps is to lie just below (`Seam.rearmostNeighbour`).
  public func windowOverTheHandle(of seam: Seam, frontToBack order: [WindowID]) -> WindowID? {
    var others = tiles.map(\.frame)
    others += openPlaces.values
    if let desktopFrame { others.append(desktopFrame) }
    return seam.rearmostNeighbour(among: windowFrames, besides: others, frontToBack: order)
  }
}
