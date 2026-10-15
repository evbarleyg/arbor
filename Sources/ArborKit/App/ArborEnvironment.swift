import Foundation

/// Launch options read from environment variables. The end-to-end runner and
/// agents use these to run Arbor in isolation.
///
/// - `ARBOR_HOME`, `ARBOR_SOCKET`: see `ArborPaths`.
/// - `ARBOR_ONLY_PIDS=123,456`: arrange only these processes' windows.
/// - `ARBOR_NO_HOTKEYS=1`: do not register global shortcuts or install the
///   pinch and rectangle event taps.
/// - `ARBOR_NO_STATUS_ITEM=1`: no menu bar item.
/// - `ARBOR_NO_PROMPT=1`: do not open the welcome window at launch when Accessibility permission is
///   missing. (`check-setup` and `welcome` still open it.)
/// - `ARBOR_DEBUG=1`: debug logging.
/// - `ARBOR_NO_WATCHDOG=1`: do not start Arbor again if it ends without quitting (`Watchdog`).
/// - `ARBOR_RESCUE=1`: set state.json aside, bring every window into view, and quit. The watchdog
///   asks for this when Arbor keeps crashing; it also works by hand.
/// - `ARBOR_RESTARTS`: the watchdog's note to the next one (`RestartPolicy`). It also tells Arbor that no person
///   started it, so a pause that was on goes on.
/// - `ARBOR_APPEARANCE=dark` or `light`: draw Arbor's own windows, panels and menu that way whatever the system's
///   appearance, so that both can be looked at without changing a setting of somebody's Mac.
/// - `ARBOR_NO_PICTURES=1`: take no pictures of windows, as without Screen Recording permission.
/// - `ARBOR_RELEASES_URL=http://127.0.0.1:8000/latest.json`: ask there instead of GitHub's releases API.
/// - `ARBOR_NO_OPENING=1`: open no app (`summon` with no window to bring). An Arbor under test on somebody's Mac knows only
///   its test windows, so to it every app of theirs is one that has to be opened.
/// - `ARBOR_NO_REHEARSAL=1`: get nothing ready for the first motion ahead of time, to measure what that saves.
public struct ArborEnvironment: Sendable {
  public var onlyPIDs: Set<Int32>?
  public var noHotkeys: Bool
  public var noStatusItem: Bool
  public var noPrompt: Bool
  public var noWatchdog: Bool
  public var rescue: Bool
  /// Nil follows the system.
  public var darkAppearance: Bool?
  public var noPictures: Bool
  public var releasesURL: String?
  public var restarted: Bool
  public var noOpening: Bool
  public var noRehearsal: Bool

  public static var current: ArborEnvironment {
    let env = ProcessInfo.processInfo.environment
    func flag(_ name: String) -> Bool {
      guard let value = env[name]?.lowercased() else { return false }
      return !["", "0", "false", "no"].contains(value)
    }
    let pids = env["ARBOR_ONLY_PIDS"].map { list in
      Set(list.split(separator: ",").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) })
    }
    return ArborEnvironment(
      onlyPIDs: pids, noHotkeys: flag("ARBOR_NO_HOTKEYS"), noStatusItem: flag("ARBOR_NO_STATUS_ITEM"),
      noPrompt: flag("ARBOR_NO_PROMPT"), noWatchdog: flag("ARBOR_NO_WATCHDOG"), rescue: flag("ARBOR_RESCUE"),
      darkAppearance: ["dark": true, "light": false][env["ARBOR_APPEARANCE"]?.lowercased() ?? ""],
      noPictures: flag("ARBOR_NO_PICTURES"),
      releasesURL: env["ARBOR_RELEASES_URL"].flatMap { $0.isEmpty ? nil : $0 },
      restarted: !(env["ARBOR_RESTARTS"] ?? "").isEmpty, noOpening: flag("ARBOR_NO_OPENING"),
      noRehearsal: flag("ARBOR_NO_REHEARSAL"))
  }
}
