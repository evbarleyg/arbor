import AppKit
import ArborCore

extension AXWindowSystem {
  /// The window server's own list, which runs front to back. It holds every window on screen,
  /// Arbor's and the system's among them; callers pick out the ones they know.
  public func windowsFrontToBack() -> [WindowID] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
    return windows.compactMap { info in
      (info[kCGWindowNumber as String] as? Int).flatMap { UInt32(exactly: $0) }.map { WindowID($0) }
    }
  }
}
