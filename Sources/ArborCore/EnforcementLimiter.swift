import Foundation

/// Keeps Arbor from fighting an app that moves its own windows (F17, H2).
///
/// A docked window that something else moved is put back. An app that answers every move with one
/// of its own would make that a loop without end, with both windows flickering and both processes
/// busy. So the put-backs of each window are counted: after `limit` of them within `span` seconds
/// Arbor gives up on that window and leaves it where its app wants it, until `reset` says that
/// the layout has changed and it is worth trying again.
public struct EnforcementLimiter: Sendable, Equatable {
  public var limit: Int
  public var span: TimeInterval
  private var putBacks: [WindowID: [TimeInterval]] = [:]
  public private(set) var givenUp: Set<WindowID> = []
  /// Those of `givenUp` that never fought: see `leave`.
  public private(set) var leftAlone: Set<WindowID> = []

  public init(limit: Int = 3, span: TimeInterval = 3) {
    self.limit = limit
    self.span = span
  }

  /// Whether `window`, found out of place at `time`, may be put back. Counts the put-back when the
  /// answer is yes. The first no for a window is the moment Arbor gives up on it.
  public mutating func allowsPuttingBack(_ window: WindowID, at time: TimeInterval) -> Bool {
    guard !givenUp.contains(window) else { return false }
    // A clock that went backwards must not keep old entries alive for ever.
    let recent = (putBacks[window] ?? []).filter { $0 <= time && time - $0 <= span }
    guard recent.count < limit else {
      givenUp.insert(window)
      putBacks[window] = nil
      return false
    }
    putBacks[window] = recent + [time]
    return true
  }

  /// Leaves `window` where it is from here on, as if Arbor had given up on it, without counting anything: what
  /// moved it was asked for (`AppsDoubleClick`).
  public mutating func leave(_ window: WindowID) {
    givenUp.insert(window)
    leftAlone.insert(window)
    putBacks[window] = nil
  }

  /// The layout these windows belong to has changed, so each gets a fresh start.
  public mutating func reset<Windows: Sequence>(_ windows: Windows) where Windows.Element == WindowID {
    for window in windows {
      putBacks[window] = nil
      givenUp.remove(window)
      leftAlone.remove(window)
    }
  }
}
