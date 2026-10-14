import ArborCore
import CoreGraphics
import Foundation

/// The window server's list of what is on screen, read for `PointerSurface`, which decides.
///
/// Safe on any thread. Reading the list takes a few milliseconds, so a tap's handler asks only for
/// the rare event that needs it (a pinch beginning), never for every event.
enum WindowList {
  /// Whether an app's window is under `point` (global, top-left origin, like the list's bounds).
  static func appWindowIsUnder(_ point: CGPoint) -> Bool {
    // The wallpaper and the icons on it are left out.
    guard let windows = read([.optionOnScreenOnly, .excludeDesktopElements]) else {
      return true  // Without the list, leave the event to the app.
    }
    return PointerSurface.appWindowIsUnder(point, windows: windows, display: displayFrame(at: point))
  }

  /// What a press at `point` would meet, and on the Desktop, whose the icons are. See `PointerSurface.under`.
  static func under(_ point: CGPoint, mayVanish: Bool) -> PointerSurface.Surface {
    guard let windows = read([.optionOnScreenOnly]) else { return .taken }
    let displays = displayFrames()
    // Which levels the passing things of macOS use has been measured for few of them. This is how to find out.
    if mayVanish, Log.debugEnabled, let window = PointerSurface.whatMayBeWaiting(windows, displays: displays) {
      TapLog.debug(
        "a press on the Desktop is left alone: a window at level \(window.layer) of pid \(window.pid), "
          + "\(Int(window.frame.width)) by \(Int(window.frame.height)), may be waiting for it")
    }
    return PointerSurface.under(point, windows: windows, displays: displays, mayVanish: mayVanish)
  }

  /// Front to back, as the list is.
  private static func read(_ options: CGWindowListOption) -> [PointerSurface.Window]? {
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
    let ownPID = Int(getpid())
    return list.compactMap { info -> PointerSurface.Window? in
      guard let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
      else { return nil }
      // A window of Arbor's with a title is an ordinary one (settings, say), where ⇧-drag selects text as
      // in any app. Its panels have none. The list has the titles of the asking process's own windows.
      let isPanel = (info[kCGWindowName as String] as? String ?? "").isEmpty
      let pid = info[kCGWindowOwnerPID as String] as? Int
      return PointerSurface.Window(
        frame: frame, layer: info[kCGWindowLayer as String] as? Int ?? 0,
        alpha: info[kCGWindowAlpha as String] as? Double ?? 1, isOwn: isPanel && pid == ownPID,
        pid: pid.flatMap { Int32(exactly: $0) } ?? 0)
    }
  }

  private static func displayFrames() -> [CGRect] {
    var displays = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success else { return [] }
    return displays.prefix(Int(count)).map { CGDisplayBounds($0) }
  }

  private static func displayFrame(at point: CGPoint) -> CGRect? {
    var display = CGDirectDisplayID()
    var count: UInt32 = 0
    guard CGGetDisplaysWithPoint(point, 1, &display, &count) == .success, count > 0 else { return nil }
    return CGDisplayBounds(display)
  }
}
