import ArborCore

extension Controller {
  /// Something an observer may want to redraw or report. Observers read the details from the
  /// controller (`workspaces`, `layouts`, `snapshot()`); a change only says where to look.
  public enum Change: Equatable, Sendable {
    /// A display was laid out again: frames, tiles or the set of docked windows may differ.
    case layout(DisplayID)
    /// The camera moved, so history changed as well.
    case camera(DisplayID)
    /// A view was saved.
    case savedViews(DisplayID)
    case focus(WindowID)
    case settings
    /// Arbor started or stopped arranging windows.
    case lifecycle
    /// Which shortcuts and pointer gestures Arbor holds has changed (`activeBindings`, `inputSettings`)
    /// for a reason other than the two above: an app that keeps its own ⌃⌥ came to the front or left it,
    /// or another keyboard layout was selected.
    case input
    /// The view is held, held differently, or released (`holdLevel`).
    case hold
    /// A window Arbor knows moved or changed size, with or without a new layout; or a panel of Arbor's own that takes
    /// clicks and is not part of a layout (the minimap) came, went or moved.
    case frames
    /// A space was named or lost its name by command. (A name that goes with its last window comes as `layout`.)
    case names(DisplayID)
    /// Something about the windows changed that no layout shows: Arbor began arranging one (new
    /// windows float where they are), a floating one went to another display, or one changed its title.
    case windows
    /// The keyboard may be with another window now, or with none Arbor knows: an app was switched to or away from, a
    /// sheet or a panel took it, the wallpaper was clicked. Ask `system.focusedWindow()`.
    case keyboard
  }

  /// Calls `observer` after every change, on the main actor, for as long as the controller lives.
  /// Observers must not run commands from inside the call; schedule them instead.
  public func observe(_ observer: @escaping @MainActor (Change) -> Void) {
    observers.append(observer)
  }

  func notify(_ change: Change) {
    if change.mayChangeDesktopGuardZones { desktopGuardZonesAreAnnounced() }
    summonNotices(change)
    headsUpNoticed(change)
    for observer in observers { observer(change) }
    if case .layout = change { summonKeysMayHaveChanged() }
  }
}
