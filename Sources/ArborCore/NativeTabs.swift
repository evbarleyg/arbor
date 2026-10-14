import CoreGraphics

/// macOS's own window tabs (Finder, Terminal, Xcode, "Merge All Windows").
///
/// Each tab is a window of its own, but only the one in front is listed by its app; the others drop off the
/// list without a word and stay alive. Choosing another tab swaps which window is listed, in the same place.
/// To a person the tab group is one window, so in Arbor the window in front stands for the group: when it
/// changes, the newcomer takes over the place of the one that left.
public enum NativeTabs {
  public struct Candidate: Equatable, Sendable {
    public var id: WindowID
    public var frame: CGRect
    /// Arbor saw this window leave the list as a tab before.
    public var wasBackgroundTab: Bool

    public init(id: WindowID, frame: CGRect, wasBackgroundTab: Bool) {
      self.id = id
      self.frame = frame
      self.wasBackgroundTab = wasBackgroundTab
    }
  }

  /// How much the heights of two tabs of a group may differ. Most apps give all tabs one frame to the point (Finder). Terminal
  /// keeps its rows instead: the window grows by the height of the tab bar, 31 points, when the bar first shows, and its
  /// tabs go on differing by about as much.
  public static let heightSlack: CGFloat = 40

  /// The window that took the place of one that left its app's list while still alive.
  ///
  /// A window leaving the list alive while another of the same app joins it in the same place is evidence
  /// enough: the same top left corner and width, and nearly the same height. The newcomer's tab bar is not asked for: the
  /// last tab left of a group has none, and a group that is just being made may not show its bar yet.
  ///
  /// - Parameters:
  ///   - frame: the frame of the window that left.
  ///   - candidates: ordinary windows of the same app that joined the list at the same time: new ones, and
  ///     known background tabs. Windows coming back with their Space are not candidates.
  public static func successor(toWindowAt frame: CGRect, among candidates: [Candidate]) -> WindowID? {
    let inPlace = candidates.filter {
      abs($0.frame.minX - frame.minX) <= 1 && abs($0.frame.minY - frame.minY) <= 1
        && abs($0.frame.width - frame.width) <= 1 && abs($0.frame.height - frame.height) <= heightSlack
    }
    // A known tab before a newcomer, then the nearest in height, then the older window.
    return inPlace.min { a, b in
      let left = (a.wasBackgroundTab ? 0 : 1, abs(a.frame.height - frame.height), a.id.rawValue)
      let right = (b.wasBackgroundTab ? 0 : 1, abs(b.frame.height - frame.height), b.id.rawValue)
      return left < right
    }?.id
  }
}
