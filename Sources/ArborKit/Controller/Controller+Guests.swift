import ArborCore
import CoreGraphics

/// New windows that open over a view without the Desktop (docs/features/F57-new-windows-while-framed.md).
///
/// Such a window floats over the docked ones, which looks right. But floating windows live on the Desktop, so at the
/// next move of the view it was gone, and Back did not bring it back. As a guest it belongs to the space it
/// opened over: it is in view whenever that space is, at the frame it has there, and with the Desktop in view
/// it sits on the Desktop like any floating window. Docking it, closing its host, `arrange` and
/// `float-all` end the visit.
extension Controller {
  /// Called for a window that has just begun to float in view and that no rule claimed: a new one, or one found at
  /// launch or after a pause. It becomes a guest of the view, unless that shows the Desktop.
  func receiveAsGuestOfTheView(_ id: WindowID) {
    // Anything but "float" means a guest: "tab", the spec's later default, needs tab strips (F04).
    guard settings.newWindowsWhileFramed != "float", let display = workspaceID(containing: id),
      let workspace = workspaces[display], workspace.isFloating(id), !parked.contains(id),
      let layout = layout(of: display), !workspace.tree.subtree(layout.camera, contains: workspace.tree.desktop)
    else { return }
    workspaces[display]!.receive(id, asGuestOf: workspace.camera)
    Log.info("\(id) floats over \(workspace.camera) and stays with it")
  }

  /// Called at launch and on resume for a window the saved arrangement does not know: it opened while Arbor was not
  /// looking. Floating windows go out of view with the Desktop, so with the view on something else the first layout would
  /// sweep away a window somebody has just opened, perhaps to work in. It is treated as if Arbor had seen it open over
  /// that view: it stays where it is, as a guest, or (if the setting says so) until the view next moves.
  func receiveWhatOpenedUnseen(_ id: WindowID) {
    guard let display = workspaceID(containing: id), workspaces[display]?.isFloating(id) == true,
      windows[id]?.isPresent == true, layout(of: display)?.desktopFrame == nil
    else { return }
    // `start()` lifts this after the first layout.
    placedOnPurpose.insert(id)
    stayWithTheView(id, on: display)
    Log.info("\(id) opened while Arbor was not looking and stays in view")
  }

  /// The space `window` is a guest of, if that space is in view in `layout`.
  func hostInView(of window: WindowID, in workspace: Workspace, layout: Layout) -> NodeID? {
    guard let host = workspace.guests?[window], workspace.tree.subtree(layout.camera, contains: host) else {
      return nil
    }
    return host
  }

  /// The window to focus when `id`'s space has been framed: `id`, or a guest of that space that was used after it.
  /// Focusing raises, and a framed window fills the display: raised over a guest that was in front of it when the
  /// view left, it would hide the guest.
  func inFront(of id: WindowID, on display: DisplayID) -> WindowID {
    guard let workspace = workspaces[display], let space = workspace.tree.leaf(containing: id) else { return id }
    let guests = (workspace.guests ?? [:]).filter {
      $0.value == space && !parked.contains($0.key) && windows[$0.key]?.isPresent == true
    }
    return focusHistory.first { $0 == id || guests[$0] != nil } ?? id
  }
}
