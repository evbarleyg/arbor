import AppKit
import ArborCore

/// The pointer input that becomes commands: trackpad pinch (F03,
/// `GestureTap`) and the modifier-drag rectangle (F05, `RectangleFramer`).
/// Each has its own event taps, installed only while its setting turns it on
/// and while Arbor has Accessibility permission, and switched on only while its keys are down:
/// Arbor stands in the path of a person's input only while they hold its keys.
@MainActor
final class PointerInput {
  private let gestures: GestureTap
  private let framer: RectangleFramer
  private var isWatchingPermission = false
  /// Tell when modifier keys go down and up. Monitors, not a tap: they only listen, after the fact, on the main thread, and were seen to
  /// start nothing and to go on being served when their owner had lost the permission. If they hear nothing (secure keyboard
  /// entry, a busy main thread) the taps stay paused and the gesture is the app's. Two, because a global monitor does not hear
  /// what goes to a window of Arbor's own. Nothing is remembered from one event to the next: what was missed would make
  /// the memory wrong, and the next press would then be ignored.
  private var keyMonitors: [Any] = []
  /// True after Accessibility permission went away; the taps stay removed until it returns.
  private var suspended = false
  /// Called when macOS has told the taps' thread that the permission is gone, or back.
  var onPermissionChange: (@MainActor () -> Void)?

  init(
    settings: @escaping @MainActor () -> Settings, onCommand: @escaping @MainActor (Command) -> Void,
    onGesture: @escaping @MainActor (GestureUpdate) -> Void, onPress: @escaping @MainActor () -> Void
  ) {
    gestures = GestureTap(settings: settings, onCommand: onCommand, onGesture: onGesture)
    framer = RectangleFramer(settings: settings, onCommand: onCommand, onPress: onPress)
  }

  /// Applies the current settings: installs, removes or reconfigures the
  /// taps. Call at launch and after every settings change (`reload-settings`).
  func update() {
    watchPermission()
    guard !suspended else { return }
    gestures.update()
    framer.update()
    watchKeys()
  }

  /// Listens for the keys while there is a tap to switch, and not otherwise.
  private func watchKeys() {
    guard gestures.isInstalled || framer.isInstalled else {
      for monitor in keyMonitors { NSEvent.removeMonitor(monitor) }
      keyMonitors = []
      return
    }
    guard keyMonitors.isEmpty else { return }
    // Monitors are served on the main thread.
    let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      let flags = event.modifierFlags
      MainActor.assumeIsolated { self?.keysChanged(flags) }
    }
    let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      let flags = event.modifierFlags
      MainActor.assumeIsolated { self?.keysChanged(flags) }
      return event
    }
    keyMonitors = [global, local].compactMap { $0 }
  }

  private func keysChanged(_ flags: NSEvent.ModifierFlags) {
    gestures.keysChanged(flags)
    framer.keysChanged(flags)
  }

  /// The names of the taps installed now, for `doctor`.
  var installedTaps: [String] {
    gestures.installedTaps + (framer.isInstalled ? ["rectangle"] : [])
  }

  /// Where a plain click might land on bare Desktop (F60). Call after every change of the layout.
  func publish(_ zones: DesktopGuardZones) {
    framer.publish(zones)
  }

  func stop() {
    gestures.stop()
    framer.stop()
    watchKeys()
  }

  /// Users switch a misbehaving window manager off in System Settings, and macOS 26 drops all input at every event that the taps
  /// of a process ask for which has lost the right to them, until those taps are gone. So the taps' own thread watches
  /// over that, and removes them without waiting for this one (`TapPermission`, `EventTapThread`). Here, afterwards,
  /// the owners forget the taps that are gone, and install them again when the permission is back.
  private func watchPermission() {
    guard !isWatchingPermission else { return }
    isWatchingPermission = true
    EventTapThread.onPermissionChange.withLock {
      $0 = { [weak self] isGone, macOSSaidSo in
        DispatchQueue.main.async { self?.permissionChanged(isGone: isGone, macOSSaidSo: macOSSaidSo) }
      }
    }
  }

  private func permissionChanged(isGone: Bool, macOSSaidSo: Bool) {
    suspended = isGone
    if isGone {
      gestures.stop()
      framer.stop()
    } else {
      gestures.update()
      framer.update()
    }
    watchKeys()
    // Taps that went because macOS said nothing in time are no second opinion. Whoever listens would believe the next no at
    // once, which may be a daemon's that is just starting again, and would put the question that hangs on this thread.
    if macOSSaidSo { onPermissionChange?() }
  }
}
