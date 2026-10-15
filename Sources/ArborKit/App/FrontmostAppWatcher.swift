import AppKit
import ArborCore

/// Reports which app is frontmost: once when started, then every time another app comes to the front.
///
/// Not part of `AXWindowSystem`, which stops observing during a pause: a pause for an app
/// (`pauseForApps`) ends when that app leaves the front, so somebody has to be looking. It also sees
/// every app, including those Arbor does not arrange.
///
/// An app is reported once macOS names it as the one in front, which can be up to 50 ms after its word that the app is
/// active (`AppThatCameForward`). Whoever hears of it asks who has the keyboard: a resume ends with that question, and
/// asked in between it was answered with a window of the app that had just been left. Arbor showed that one, and the window
/// that was switched to stayed out of view with the keyboard in it, for good: `AXWindowSystem` starts to listen in the
/// course of that resume, too late to hear of the switch.
@MainActor
final class FrontmostAppWatcher {
  private var token: (any NSObjectProtocol)?
  private let onChange: @MainActor (FrontmostApp?) -> Void
  /// The next look at an app that is active and not named as the one in front yet.
  private var nextLook: Task<Void, Never>?

  init(onChange: @escaping @MainActor (FrontmostApp?) -> Void) {
    self.onChange = onChange
  }

  func start() {
    guard token == nil else { return }
    token = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      let (pid, named) = (app?.processIdentifier, app.map { FrontmostApp($0) })
      MainActor.assumeIsolated { self?.cameForward(named, pid: pid, earlierLooks: 0) }
    }
    onChange(NSWorkspace.shared.frontmostApplication.map { FrontmostApp($0) })
  }

  func stop() {
    if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    token = nil
    nextLook?.cancel()
  }

  private func cameForward(_ app: FrontmostApp?, pid: pid_t?, earlierLooks: Int) {
    // Whoever came forward before has been overtaken.
    nextLook?.cancel()
    let isNamed = pid == nil || NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    guard case .lookAgain(let seconds) = AppThatCameForward.verdict(isNamedInFront: isNamed, earlierLooks: earlierLooks)
    else {
      // Named, or never named in half a second: a pause must not outlast the app it is for because macOS kept silent.
      return onChange(app)
    }
    if earlierLooks == 0 {
      Log.debug("pid \(pid ?? -1) is active, and macOS still names another app as the one in front: that waits")
    }
    nextLook = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      guard !Task.isCancelled, let self, self.token != nil else { return }
      self.cameForward(app, pid: pid, earlierLooks: earlierLooks + 1)
    }
  }
}

extension FrontmostApp {
  init(_ app: NSRunningApplication) {
    self.init(
      bundleID: app.bundleIdentifier,
      name: app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)")
  }
}
