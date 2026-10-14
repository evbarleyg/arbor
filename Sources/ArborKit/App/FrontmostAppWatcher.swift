import AppKit

/// Reports which app is frontmost: once when started, then every time another app comes to the front.
///
/// Not part of `AXWindowSystem`, which stops observing during a pause: a pause for an app
/// (`pauseForApps`) ends when that app leaves the front, so somebody has to be looking. It also sees
/// every app, including those Arbor does not arrange.
@MainActor
final class FrontmostAppWatcher {
  private var token: (any NSObjectProtocol)?
  private let onChange: @MainActor (FrontmostApp?) -> Void

  init(onChange: @escaping @MainActor (FrontmostApp?) -> Void) {
    self.onChange = onChange
  }

  func start() {
    guard token == nil else { return }
    token = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] note in
      let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication).map { FrontmostApp($0) }
      MainActor.assumeIsolated { self?.onChange(app) }
    }
    onChange(NSWorkspace.shared.frontmostApplication.map { FrontmostApp($0) })
  }

  func stop() {
    if let token { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    token = nil
  }
}

extension FrontmostApp {
  init(_ app: NSRunningApplication) {
    self.init(
      bundleID: app.bundleIdentifier,
      name: app.localizedName ?? app.bundleIdentifier ?? "pid \(app.processIdentifier)")
  }
}
