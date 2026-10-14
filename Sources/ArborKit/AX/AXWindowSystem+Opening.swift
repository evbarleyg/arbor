import AppKit
import ArborCore
import Foundation

extension AXWindowSystem {
  public func openApplication(_ app: String) -> Bool {
    guard !ArborEnvironment.current.noOpening else {
      Log.info("ARBOR_NO_OPENING: no app is opened")
      return false
    }
    guard let url = Self.applicationURL(for: app) else { return false }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    // Opening an app that is running is what a click on its Dock icon does: it comes to the front, is
    // shown if it was hidden, and is asked to reopen, at which most apps with no window make one.
    NSWorkspace.shared.openApplication(at: url, configuration: configuration, completionHandler: nil)
    return true
  }

  /// A bundle id first; then, by name, an app that is running; then the folders apps are installed in.
  private static func applicationURL(for app: String) -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app) { return url }
    let running = NSWorkspace.shared.runningApplications.first {
      $0.activationPolicy == .regular && $0.localizedName?.caseInsensitiveCompare(app) == .orderedSame
    }
    if let url = running?.bundleURL { return url }
    // `Command.parse` lets no slash through; this is for callers that do not come that way.
    guard !app.contains("/"), !app.hasPrefix(".") else { return nil }
    let folders = [
      "/Applications", "/System/Applications", "/System/Applications/Utilities", "/Applications/Utilities",
      NSHomeDirectory() + "/Applications",
    ]
    for folder in folders {
      let url = URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent(app + ".app", isDirectory: true)
      if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    return nil
  }
}
