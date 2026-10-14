import ArborCore
import CoreGraphics
import Foundation

/// Double-clicks as quick camera moves (docs/features/F14-double-click-actions.md): a docked window's
/// title bar frames the window, bare Desktop focuses the Desktop, and doing either again goes back.
/// What a point means is decided by `DoubleClickZones` in ArborCore; this file only describes the current
/// layouts to it. Tiles take their own clicks and open on the first; what is left for here is the second click
/// of someone who double-clicks one.
extension Controller {
  /// Where double-clicks mean something right now. It changes only when a display is laid out, the
  /// camera moves, settings are applied or Arbor starts or stops, all of which observers hear about
  /// (`observe`), except for the floating windows, which come, go and move without a layout.
  public func doubleClickZones() -> DoubleClickZones {
    // What the tap follows, so that whatever takes the tap away takes the zones away with it.
    let settings = inputSettings
    guard isRunning, settings.wantsDoubleClickTap else { return DoubleClickZones() }
    let height = settings.effectiveTitleBarHeight
    return DoubleClickZones(
      displays: displays.compactMap { display -> DoubleClickZones.Display? in
        guard let workspace = workspaces[display.id], let layout = layouts[display.id],
          let view = treeView(display.id)
        else { return nil }
        var zones = DoubleClickZones.Display(id: display.id, frame: display.frame)
        if settings.titleBarDoubleClick {
          // Where each window came to rest, which is not always its slot: one that cannot grow sits in the middle of it.
          zones.titleBars = layout.windowFrames.sorted { $0.key < $1.key }.map {
            DoubleClickZones.TitleBar(window: $0.key, windowFrame: settled[$0.key] ?? $0.value, height: height)
          }
        }
        if settings.desktopDoubleClick { zones.desktop = layout.desktopFrame }
        zones.tiles = layout.tiles.map(\.frame)
        zones.floating = workspace.floating.keys.sorted().compactMap { window in
          guard let snapshot = windows[window], snapshot.isPresent, !parked.contains(window) else { return nil }
          return snapshot.frame
        }
        // Windows Arbor does not arrange (excluded apps, `ignore` rules) lie about like floating ones.
        zones.floating += windows.values.sorted { $0.id < $1.id }
          .filter { !filter.manages($0) && $0.isPresent && displayID(at: $0.frame.center) == display.id }.map(\.frame)

        // A split whose other children are minimized or hidden looks exactly like its one remaining
        // child, so what counts is what the view shows, not which node the camera is on.
        let shown = view.passThrough(layout.camera)
        if shown == workspace.tree.desktop {
          zones.framed = .desktop
        } else if let window = view.visibleWindow(of: shown) {
          zones.framed = .window(window)
        }
        zones.unframe = wayOut(of: workspace.camera, on: display.id)
        return zones
      },
      openedTile: openedTile)
  }

  @discardableResult
  public func doubleClicked(at point: CGPoint) -> Bool {
    guard let hit = doubleClickZones().hit(at: point, time: now().timeIntervalSinceReferenceDate) else { return false }
    // `back` and `out` name no display: it is the one under the pointer, as for any gesture (F56). Refused (a held
    // view) it is Arbor's all the same: the tap has hidden the click by the time the command runs.
    if let command = hit.command { perform(command, from: .gesture) }
    return true
  }

  /// Asks what macOS does itself at a double-click on a title bar: at every layout, because people change it while Arbor
  /// runs, and only while Arbor's own switch is on, because nothing else depends on it. `inputSettings` goes by the answer,
  /// so the taps and the zones follow.
  ///
  /// Also before `doctor` and the settings window say anything about it, and at the first click of a pair on a title bar, so
  /// that what they say and what the taps do is one answer. Returns why Arbor leaves title bars alone, if it does.
  ///
  /// The answer goes into a trace as a read. No window, view or layout depends on it: it decides which clicks the taps take, and
  /// what comes of those is a command, which is recorded.
  @discardableResult
  func lookAtMacTitleBarAction() -> String? {
    guard settings.titleBarDoubleClick else { return nil }
    let action = system.macTitleBarAction()
    let before = macTitleBarAction
    macTitleBarAction = action
    // Between Fill and Zoom nothing changes for Arbor.
    if action.makesTheWindowBig != before.makesTheWindowBig {
      Log.info(action.whyArborLeavesTitleBarsAlone ?? "macOS makes a window big at a double-click on its title bar: there Arbor frames docked windows instead")
      notify(.input)
    }
    return action.whyArborLeavesTitleBarsAlone
  }

  /// Remembers where and when a tile is about to open. Called before the camera moves,
  /// while the layout still has the tile, so that observers have it before the new layout and with it.
  func noteTileOpening(display: DisplayID, node: NodeID) {
    guard inputSettings.wantsDoubleClickTap, let tile = layouts[display]?.tiles.first(where: { $0.node == node }) else {
      return
    }
    openedTile = DoubleClickZones.OpenedTile(frame: tile.frame, time: now().timeIntervalSinceReferenceDate)
    // At once, not with the new layout: moving the windows takes a while, and the second click may be here before it is over.
    notify(.frames)
  }
}
