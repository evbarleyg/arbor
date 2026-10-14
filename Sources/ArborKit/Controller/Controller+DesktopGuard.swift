import ArborCore
import CoreGraphics

extension Controller {
  /// Where a press might land on bare Desktop inside Arbor's view, for the guard of the Desktop
  /// (docs/features/F60-guard-the-wallpaper-click.md) and for ⇧-drag (F05), which ask the same question: on every
  /// display with something docked, the part Arbor lays out, less where the windows it knows to be in view really
  /// are. Empty before the start, while paused, and wherever else `inputSettings` turns both off.
  ///
  /// The windows' real frames, not their slots: a window that cannot grow to its slot has wallpaper around it. They
  /// change without a new layout (the user drags a floating window about), which observers hear of as `.frames`.
  /// A frame gone stale all the same errs on the safe side: the press goes where it would without Arbor.
  public func desktopGuardZones() -> DesktopGuardZones {
    let settings = inputSettings
    guard isRunning, settings.guardDesktopClicks || settings.frameRectangleOnDesktop else { return DesktopGuardZones() }
    let inView = windows.values.filter { $0.isPresent && !parked.contains($0.id) }.map(\.frame)
    return DesktopGuardZones(
      displays: displays.compactMap { display -> DesktopGuardZones.Display? in
        guard let layout = layouts[display.id], let workspace = workspaces[display.id],
          !workspace.tree.allWindows.isEmpty
        else { return nil }
        // With `gapHandles` off no panel lies in the gaps, so a press there would reach the wallpaper.
        let handles = settings.appearanceOptions.gapHandles == .off ? [] : layout.seams.map(\.frame)
        // Sorted, so that two answers about the same state are equal.
        return DesktopGuardZones.Display(
          view: layout.frame, windows: Self.sorted(inView.filter { $0.overlaps(layout.frame) }),
          panels: Self.sorted(
            layout.tiles.map(\.frame) + handles + [minimapClickFrame(on: display.id)].compactMap { $0 }))
      })
  }

  /// Called whenever `windows` or `parked` changes, whoever changes them. The zones are made of them, and a dozen features
  /// move, hide and bring back windows, not all of them with a layout or a word to observers; the next one will
  /// not know of the zones either. So once the command or event under way is over, the zones are compared with what
  /// observers last heard of, and if they differ, observers hear of it (`.frames`).
  ///
  /// Nearly always a word to observers follows in the same command or event. Then nothing is left to look at, and nothing
  /// stays scheduled (`desktopGuardZonesAreAnnounced`).
  func desktopGuardZonesMayHaveChanged() {
    // Before the start and during a pause there are no zones, whatever the windows do.
    guard !guardZonesCheckIsQueued, isRunning || !announcedGuardZones.isEmpty else { return }
    guardZonesCheckIsQueued = true
    scheduler.schedule("desktop-guard-zones", after: 0) { [weak self] in
      guard let self else { return }
      self.guardZonesCheckIsQueued = false
      if self.desktopGuardZones() != self.announcedGuardZones { self.notify(.frames) }
    }
  }

  /// Observers are about to hear of a change after which they look at the zones again.
  func desktopGuardZonesAreAnnounced() {
    announcedGuardZones = desktopGuardZones()
    guard guardZonesCheckIsQueued else { return }
    guardZonesCheckIsQueued = false
    scheduler.cancel("desktop-guard-zones")
  }

  private static func sorted(_ frames: [CGRect]) -> [CGRect] {
    frames.sorted { ($0.minX, $0.minY, $0.width, $0.height) < ($1.minX, $1.minY, $1.width, $1.height) }
  }
}

extension Controller.Change {
  /// Whether `desktopGuardZones()` may answer differently after this change. Whoever keeps a copy of the zones
  /// asks this, and so do the tests that every change of the zones announces itself.
  public var mayChangeDesktopGuardZones: Bool {
    switch self {
    case .focus, .savedViews: false
    default: true
    }
  }
}
