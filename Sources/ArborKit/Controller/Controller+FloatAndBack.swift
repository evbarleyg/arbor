import ArborCore

/// ⌃⌥F twice is a return: the window floats, and docks again where it was (`Workspace.docking(_:backAsIn:floatedAs:)`).
/// Only if nothing has changed in between; otherwise it docks at the right edge of the view, as any floating window does.
extension Controller {
  struct FloatedOut {
    var window: WindowID
    var display: DisplayID
    var before: Workspace
    var after: Workspace
  }

  func floatRememberingItsPlace(_ window: WindowID, on display: DisplayID) -> CommandResult {
    let before = workspaces[display]
    let result = float(window)
    floatedOut = nil
    if result.ok, let before, let after = workspaces[display] {
      floatedOut = FloatedOut(window: window, display: display, before: before, after: after)
    }
    return result
  }

  /// Nil if the window was not floated with ⌃⌥F last, or something has changed since.
  func dockWhereItWas(_ window: WindowID, on display: DisplayID) -> CommandResult? {
    defer { floatedOut = nil }
    guard let memo = floatedOut, memo.window == window, memo.display == display, let now = workspaces[display],
      let restored = now.docking(window, backAsIn: memo.before, floatedAs: memo.after),
      // The way back can lead to another view (it was framed). A held view stays where it is (Controller+Hold.swift).
      holdLevel != .view || restored.camera == now.camera
    else { return nil }
    let shown = windowsShown(on: display)
    workspaces[display] = restored
    relayout(display, reason: .structure)
    focusIfShown(window, on: display)
    if restored.camera != now.camera { notify(.camera(display)) }
    scheduleSave()
    return .success("docked \(window) where it was" + tileNote(window, on: display, since: shown))
  }
}
