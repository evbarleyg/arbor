import AppKit
import Foundation

extension AXWindowSystem {
  /// Through `open`, which finds every app Launch Services knows by name, wherever it is installed.
  /// `-g` keeps it in the background: several apps opening at once would otherwise take the keyboard
  /// from the user, and from each other, as each becomes ready.
  public func launchApp(_ name: String) -> Bool {
    // A path would open whatever bundle lies there; apps are named, not pointed at.
    guard !name.isEmpty, !name.contains("/") else { return false }
    let isBundleID = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) != nil
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", isBundleID ? "-b" : "-a", name]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    process.terminationHandler = { finished in
      // Without the name: what is no app's name is a word somebody typed.
      if finished.terminationStatus != 0 { Log.error("macOS found no app of the name it was given to open") }
    }
    do {
      try process.run()
      return true
    } catch {
      Log.error("could not open an app: \(error)")
      return false
    }
  }
}
