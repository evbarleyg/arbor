import ArborCore
import CoreGraphics

/// The road a window takes when Arbor moves it. A window moves once, to where it ends up. One Arbor does not know yet is
/// asked for a size where it stands and goes to its place afterwards, which is also how the Accessibility layer moves any
/// window: the size, then the position. So counting requests says little. What a person sees is the road.
extension FakeWindowSystem {
  /// Every frame `window` had from entry `mark` of `moveLog` on, wherever Arbor changed it, beginning with the frame it had
  /// before. Where somebody else moved it in between, the frame Arbor found it at is part of the road. Empty if Arbor changed
  /// nothing about it.
  public func road(of window: WindowID, since mark: Int = 0) -> [CGRect] {
    var road: [CGRect] = []
    for move in moveLog[min(mark, moveLog.count)...] where move.window == window && move.before != move.after {
      if road.last != move.before { road.append(move.before) }
      road.append(move.after)
    }
    return road
  }

  /// How far off its road a window may be before anybody would call it a jolt. macOS has a hand in every frame: it rounds
  /// to whole points and keeps title bars within reach, also of a window that was only asked for a size.
  public nonisolated static let roadTolerance: CGFloat = 6

  /// How often a window changed place on a road.
  public nonisolated static func changesOfPlace(_ road: [CGRect]) -> Int {
    zip(road, road.dropFirst()).filter { abs($0.minX - $1.minX) > roadTolerance || abs($0.minY - $1.minY) > roadTolerance }.count
  }

  /// What is wrong with a road, or nil. A window changes place once at most, and its left edge, its top edge, its width and
  /// its height each go one way only: never past where they end up and back.
  public nonisolated static func detour(_ road: [CGRect]) -> String? {
    // Nothing was changed about it.
    guard road.count > 1 else { return nil }
    let steps = Array(zip(road, road.dropFirst()))
    let told = road.map { "(\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))×\(Int($0.height)))" }.joined(separator: " → ")
    let places = changesOfPlace(road)
    if places > 1 { return "changed place \(places) times: \(told)" }
    let coordinates: [(String, (CGRect) -> CGFloat)] = [
      ("left edge", { $0.minX }), ("top edge", { $0.minY }), ("width", { $0.width }), ("height", { $0.height }),
    ]
    for (name, value) in coordinates {
      // As the detector on a Mac measures it (scripts/mac-shell/jolts.py, `measure`): what it travelled beyond the straight way, which
      // is there and back again.
      let travelled = steps.map { abs(value($1) - value($0)) }.reduce(0, +)
      let excess = travelled - abs(value(road[road.count - 1]) - value(road[0]))
      if excess > roadTolerance { return "its \(name) went \(Int(excess)) points out of its way: \(told)" }
    }
    return nil
  }
}
