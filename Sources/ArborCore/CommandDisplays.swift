extension Command {
  /// Whether the command is carried out while the displays are changing and Arbor has not heard what they have become
  /// (`Controller.refusalWhileTheDisplaysChange`): nothing it does lays out a display, moves a view or opens a way to either.
  ///
  /// **Whatever is not listed here is refused**, as with a held view (`isAllowedWhileHeld`): a key that does nothing and says why costs a
  /// moment, a window sent to a display that is gone is out of sight. Quitting and pausing look at the displays themselves.
  ///
  /// Not here though they seem to move nothing: a setting, a name, the apps that keep their keys and automatic docking, each of which
  /// lays out every display; a hold, which fences the layout that the report brings, so that one taken now ends otherwise than one
  /// taken a moment later; Go to…, the minimap and the field for a name, whose rows, tiles and ↩ go where a command would; a view saved,
  /// which is written into the arrangement of the display Arbor takes the person to be at, and that one may be about to go to sleep; the
  /// panel of shortcuts, which takes the keyboard and is placed on that same display.
  public var leavesWindowsAndViewsAlone: Bool {
    if isQuery { return true }
    switch self {
    case .quit, .pause, .resume, .togglePause: return true
    // Windows of Arbor's own that arrange nothing, and that macOS places.
    case .checkSetup, .welcome, .checkForUpdates, .settings(.showWindow), .settings(.closeWindow): return true
    // ⎋ in the field for a name. The field has gone by then, and would come up again at the next layout.
    case .askName(cancel: true): return true
    case .launchAtLogin, .trace: return true
    default: return false
    }
  }
}
