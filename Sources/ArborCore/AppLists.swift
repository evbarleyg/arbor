/// The lists of apps in settings.json that change what Arbor holds while the app is frontmost
/// (docs/features/F41-pass-through-apps.md).
extension Settings {
  /// Whether `bundleID` is on `list`. Case is ignored: these lists are also typed by hand, and
  /// `org.gnu.emacs` for `org.gnu.Emacs` would otherwise do nothing, without a word.
  public static func list(_ list: [String], contains bundleID: String?) -> Bool {
    guard let wanted = bundleID?.lowercased() else { return false }
    return list.contains { $0.lowercased() == wanted }
  }

  public func passesThrough(_ bundleID: String?) -> Bool { Self.list(passThroughApps, contains: bundleID) }
  public func pausesFor(_ bundleID: String?) -> Bool { Self.list(pauseForApps, contains: bundleID) }
}

/// Apps known to use ⌃⌥ for themselves, which Arbor's shortcuts take away from them (docs/KEYBOARD.md,
/// "Conflicts we accept"). Arbor only ever suggests `pass-through` for them: someone who frames a virtual
/// machine still wants ⌃⌥Space to get out of it.
public enum ControlOptionApps {
  /// Remote desktops and virtual machines (⌃⌥ is AltGr on a Windows guest and switches workspaces on a
  /// Linux one), and Emacs (every ⌃⌥ + letter is C-M-letter).
  static let bundleIDs: Set<String> = [
    "com.microsoft.rdc.macos", "com.apple.screensharing", "com.vmware.fusion", "com.parallels.desktop.console",
    "com.utmapp.utm", "org.virtualbox.app.virtualboxvm", "org.gnu.emacs", "org.gnu.aquamacs",
    "com.google.android.studio",
  ]
  /// Every JetBrains IDE has its own bundle id under this one.
  static let prefixes = ["com.jetbrains."]

  public static func contains(_ bundleID: String?) -> Bool {
    guard let id = bundleID?.lowercased() else { return false }
    return bundleIDs.contains(id) || prefixes.contains { id.hasPrefix($0) }
  }
}
