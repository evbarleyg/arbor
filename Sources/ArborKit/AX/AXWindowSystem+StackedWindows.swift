import AppKit
import ArborCore

extension AXWindowSystem {
  /// From the window server's own list, which runs front to back and holds every window on screen.
  public func stackedWindows() -> [StackedWindow] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
    let ownPID = Int(getpid())
    return windows.compactMap { info -> StackedWindow? in
      guard (info[kCGWindowLayer as String] as? Int) == 0,
        let number = info[kCGWindowNumber as String] as? Int, let id = UInt32(exactly: number),
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
      else { return nil }
      // Some tools lay an invisible window over the whole screen.
      if let alpha = info[kCGWindowAlpha as String] as? Double, alpha == 0 { return nil }
      // Tiles, gap handles and the focus ring are drawn for a display at rest. They are not windows to anyone.
      // What tells them from Arbor's real windows is that they never take the keyboard.
      if (info[kCGWindowOwnerPID as String] as? Int) == ownPID,
        NSApp.window(withWindowNumber: number)?.canBecomeKey == false
      {
        return nil
      }
      return StackedWindow(id: WindowID(id), frame: frame)
    }
  }
}
