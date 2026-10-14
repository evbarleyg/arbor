/// Whether something an app lists as a window is a window Arbor arranges.
public enum WindowKind: Equatable, Sendable {
  /// An ordinary window.
  case window
  /// It may be one, but cannot be told from a dialog while it is out of sight. It can be remembered (it takes
  /// no space meanwhile) and must be looked at again when it shows.
  case unconfirmed
  /// A sheet, dialog, palette, popover, tooltip, or the stand-in macOS shows during a full-screen transition.
  case other

  /// macOS reports the subrole `AXDialog` for every minimized window and every window of a hidden app, ordinary
  /// ones included, and `AXStandardWindow` again once they show (seen on macOS 26; the title bar buttons are
  /// no help, dialogs have all three). Turning those away would mean that windows minimized or hidden when Arbor
  /// starts lose the place they were saved with.
  public static func classify(role: String?, subrole: String?, isMinimized: Bool, appIsHidden: Bool) -> WindowKind {
    guard role == "AXWindow" else { return .other }
    if subrole == "AXStandardWindow" { return .window }
    if subrole == "AXDialog", isMinimized || appIsHidden { return .unconfirmed }
    return .other
  }
}
