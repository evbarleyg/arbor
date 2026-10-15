import ArborCore
import Foundation

/// The pointer input that becomes commands: trackpad pinch (F03,
/// `GestureTap`) and the modifier-drag rectangle (F05, `RectangleFramer`).
/// Each has its own event tap, installed only while its setting turns it on
/// and while Arbor has Accessibility permission.
@MainActor
final class PointerInput {
  private let gestures: GestureTap
  private let framer: RectangleFramer
  private var isWatchingPermission = false
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
    // Taps that went because macOS said nothing in time are no second opinion. Whoever listens would believe the next no at
    // once, which may be a daemon's that is just starting again, and would put the question that hangs on this thread.
    if macOSSaidSo { onPermissionChange?() }
  }
}
