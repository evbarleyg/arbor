import AppKit
import ArborCore
import Carbon.HIToolbox

/// The parts of `SystemFacts` that take more than a call to read. What they mean is decided in
/// ArborCore (`MacSwitch`, `CompetingApp`); this only asks macOS.
@MainActor
enum MacFacts {
  /// The settings under Desktop & Dock that are in Arbor's way as they stand, or nil if they cannot be read.
  static var switches: [MacSwitch]? {
    // A new object each time: this is another process's domain, and the user is changing it meanwhile.
    guard let defaults = UserDefaults(suiteName: "com.apple.WindowManager") else { return nil }
    return MacSwitch.inTheWay(macOS: ProcessInfo.processInfo.operatingSystemVersion.majorVersion) { key in
      defaults.object(forKey: key) as? Bool
    }
  }

  /// macOS's own tiling of dragged windows as it stands. Settings that cannot be read count as this macOS comes: standing
  /// aside for nobody costs the last point of a screen edge, and not standing aside costs a fight over the window.
  static var tiling: MacTiling {
    let macOS = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    return MacTiling(switches ?? MacSwitch.inTheWay(macOS: macOS) { _ in nil })
  }

  /// How many keyboard layouts and input methods the Input menu switches between.
  static var inputSources: Int? {
    let wanted: [String: Any] = [
      kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
      kTISPropertyInputSourceIsSelectCapable as String: true,
    ]
    guard let list = TISCreateInputSourceList(wanted as CFDictionary, false)?.takeRetainedValue() else { return nil }
    let count = CFArrayGetCount(list)
    return count > 0 ? count : nil
  }

  /// The running apps that get in Arbor's way, by name. The first thing asked about a running app, be it only its number, is a
  /// round trip to Launch Services, and there are dozens of them. So nothing is asked of any until there are more or fewer than
  /// there were, and twice a minute all the same: one may have come as another went, or not have had its name yet.
  static var competingApps: [String] {
    let running = NSWorkspace.shared.runningApplications
    let halfMinute = Int(ProcessInfo.processInfo.systemUptime / 30)
    return keptCompetingApps.value(for: [running.count, halfMinute]) { competingApps(among: running) }
  }

  private static var keptCompetingApps = KeptFact<[Int], [String]>()

  private static func competingApps(among running: [NSRunningApplication]) -> [String] {
    var names: [String] = []
    for app in running {
      let name = CompetingApp.name(
        bundleID: app.bundleIdentifier, appName: app.localizedName, executable: app.executableURL?.lastPathComponent)
      if let name, !names.contains(name) {
        names.append(name)
      }
    }
    return names.sorted()
  }

  /// What Finder calls the app with this bundle id, or nil if it is not installed.
  static func name(ofApp bundleID: String) -> String? {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
    let name = FileManager.default.displayName(atPath: url.path)
    // Finder can be told to show extensions.
    return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
  }
}
