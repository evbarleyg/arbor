import ArborCore
import Foundation

/// The pointer input that becomes commands: trackpad pinch (F03,
/// `GestureTap`), the modifier-drag rectangle (F05, `RectangleFramer`) and
/// double-clicks on title bars and the Desktop (F14, `DoubleClickTap`).
/// Each has its own event tap, installed only while its setting turns it on
/// and while Arbor has Accessibility permission.
@MainActor
final class PointerInput {
  private let gestures: GestureTap
  private let framer: RectangleFramer
  private let doubleClicks: DoubleClickTap
  private var permissionCheck: Timer?
  /// True after Accessibility permission went away; the taps stay removed until it returns.
  private var suspended = false
  /// Called when the watchdog finds the permission gone, or back.
  var onPermissionChange: (@MainActor () -> Void)?

  init(
    settings: @escaping @MainActor () -> Settings, onCommand: @escaping @MainActor (Command) -> Void,
    onGesture: @escaping @MainActor (GestureUpdate) -> Void, onPress: @escaping @MainActor () -> Void
  ) {
    gestures = GestureTap(settings: settings, onCommand: onCommand, onGesture: onGesture)
    framer = RectangleFramer(settings: settings, onCommand: onCommand, onPress: onPress)
    doubleClicks = DoubleClickTap(settings: settings, onCommand: onCommand, onPress: onPress)
  }

  /// Double-clicks mean different things in different places, so their tap follows the controller's layouts.
  func follow(_ controller: Controller) {
    doubleClicks.follow(controller)
  }

  /// Applies the current settings: installs, removes or reconfigures the
  /// taps. Call at launch and after every settings change (`reload-settings`).
  func update() {
    watchPermission()
    guard !suspended else { return }
    gestures.update()
    framer.update()
    doubleClicks.update()
  }

  /// The names of the taps installed now, for `doctor`.
  var installedTaps: [String] {
    gestures.installedTaps + (framer.isInstalled ? ["rectangle"] : [])
      + (doubleClicks.isInstalled ? ["double-click"] : [])
  }

  /// Where a plain click might land on bare Desktop (F60). Call after every change of the layout.
  func publish(_ zones: DesktopGuardZones) {
    framer.publish(zones)
  }

  func stop() {
    permissionCheck?.invalidate()
    permissionCheck = nil
    gestures.stop()
    framer.stop()
    doubleClicks.stop()
  }

  /// Users switch a misbehaving window manager off in System Settings, and
  /// macOS has been reported to stop all input when a process loses
  /// Accessibility permission while it has an active event tap. So once a
  /// second, while a tap is installed, Arbor checks that it still may, and
  /// removes its taps at once if not; they come back when permission does.
  /// The same check switches a tap back on that macOS left off.
  private func watchPermission() {
    guard permissionCheck == nil else { return }
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.checkPermission() }
    }
    // Lets macOS fire it together with other timers instead of waking the Mac just for this.
    timer.tolerance = 0.2
    RunLoop.main.add(timer, forMode: .common)
    permissionCheck = timer
  }

  private func checkPermission() {
    guard suspended || gestures.isInstalled || framer.isInstalled || doubleClicks.isInstalled else { return }
    let refusal = EventTap.refusal()
    let permitted = refusal == nil
    if !permitted, !suspended {
      suspended = true
      gestures.stop()
      framer.stop()
      doubleClicks.stop()
      Log.info(
        "Accessibility permission is gone (\(refusal ?? "")): removed the pinch, rectangle and double-click event taps")
      onPermissionChange?()
    } else if permitted, suspended {
      suspended = false
      Log.info("Accessibility permission is back: installing the pinch, rectangle and double-click event taps")
      gestures.update()
      framer.update()
      doubleClicks.update()
      onPermissionChange?()
    } else if permitted {
      gestures.revive()
      framer.revive()
      doubleClicks.revive()
    }
  }
}
