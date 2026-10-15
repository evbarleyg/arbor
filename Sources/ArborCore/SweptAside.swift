import CoreGraphics

/// Tells when macOS is showing its desktop.
///
/// A click on the wallpaper (as macOS 14 and later come), Show Desktop's key, hot corner or gesture sweeps every
/// window to the side of its display, with a strip of it left showing, until something brings them back. It is a
/// picture: the window server lists the windows at the sides, and goes on listing them as they were then. The apps
/// are not told, so Accessibility has every window where it is and reports no move
/// (`collab/reports/2026-10-14-the-desktop-is-shown.md`). What tells a sweep is that the two disagree.
///
/// A person who moves a window moves one, with the button down, and Accessibility follows within a moment. A sweep
/// takes all that is in view out of view at once, and the two go on disagreeing for as long as it lasts.
public enum SweptAside {
  /// A window is in view with at least this much of it on one display.
  static let inView: CGFloat = 0.5
  /// It is listed off that display with less than this much of it left there. On a Mac 2 to 12 % were.
  static let aside: CGFloat = 0.25

  /// The level of the window, as large as the display, that the Dock has on screen for as long as a sweep lasts. Seen on
  /// macOS 26; nobody has looked on 14 and 15, so it is one sign of two.
  static let dockLevel = 18

  /// Whether something that the window server lists is that window of the Dock's. It tells a sweep where the frames
  /// cannot: with as many windows opened since as were swept.
  public static func isTheDocksSign(level: Int, frame: CGRect, displays: [CGRect]) -> Bool {
    level == dockLevel && displays.contains(frame)
  }

  /// - Parameters:
  ///   - believed: where Accessibility last had the windows that show (not minimized, hidden or on another Space).
  ///   - listed: the windows on screen as the window server has them. What is in only one of the two is not judged.
  ///   - displays: every display's whole frame.
  public static func isSwept(believed: [WindowID: CGRect], listed: [StackedWindow], displays: [CGRect]) -> Bool {
    var swept = 0
    var inPlace = 0
    for window in listed {
      // What Arbor itself keeps out of view says nothing either way.
      guard let frame = believed[window.id],
        let display = displays.max(by: { frame.fractionInside($0) < frame.fractionInside($1) }),
        frame.fractionInside(display) >= inView
      else { continue }
      if window.frame.fractionInside(display) < aside { swept += 1 } else { inPlace += 1 }
    }
    // A window that opened since is listed where it is, so not all need be aside. One that an app or a tool took out
    // of view without a word, among others that stayed, is no sweep.
    return swept > inPlace
  }
}
