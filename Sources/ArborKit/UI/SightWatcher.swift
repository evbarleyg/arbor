import AppKit
import ArborCore

/// Tells a panel that takes the keyboard that its person no longer sees it, or has left the Space it came up on.
///
/// `resignKey` and the monitors of keys and clicks cover whatever takes the keyboard elsewhere, but for a look at Mission Control, of
/// which a panel hears nothing (`PanelSight`): macOS hid Go to… for as long and brought it back afterwards, with the keyboard.
@MainActor
final class SightWatcher {
  private var sight = PanelSight()
  private var watchers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []

  /// Call it before the panel is put on screen, so that nothing is missed. `lost` gets what happened, for the log.
  func begin(for panel: NSWindow, lost: @escaping @MainActor (String) -> Void) {
    end()
    sight = PanelSight()
    // A panel that is up already has shown, and may hear nothing more of it until it no longer does.
    _ = sight.isLost(shows: panel.occlusionState.contains(.visible))
    let windows = NotificationCenter.default
    let occlusion = windows.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: panel, queue: .main) {
      [weak self, weak panel] _ in
      MainActor.assumeIsolated {
        guard let self, let panel, !self.watchers.isEmpty else { return }
        if self.sight.isLost(shows: panel.occlusionState.contains(.visible)) { lost("going out of sight") }
      }
    }
    let workspace = NSWorkspace.shared.notificationCenter
    let space = workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, !self.watchers.isEmpty else { return }
        lost("another Space")
      }
    }
    watchers = [(windows, occlusion), (workspace, space)]
  }

  func end() {
    for watcher in watchers { watcher.center.removeObserver(watcher.token) }
    watchers.removeAll()
  }
}
