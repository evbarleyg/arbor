import Foundation

/// What to do when Arbor ends without quitting (a crash, a trap, `kill -9`, Force Quit) while windows
/// may be parked out of view. `Watchdog` (macOS only) notices and acts; this decides.
///
/// Starting again is the best repair: the apps did not restart, so every window still has its
/// number, and `reconcile()` puts the whole arrangement back. But something that crashes Arbor at
/// launch would then crash it for ever, so the third start within `window` seconds is a rescue: Arbor
/// sets state.json aside, brings every window into view and quits.
public enum RestartPolicy {
  public enum Decision: Equatable, Sendable {
    case restart
    case rescue
    case giveUp
  }

  /// Restarts further apart than this are unrelated accidents.
  public static let window: Double = 120

  /// - Parameter history: when Arbor was started again before, in seconds since 1970.
  public static func decide(history: [Double], now: Double) -> Decision {
    switch recent(history, now: now).count {
    case 0, 1: .restart
    case 2: .rescue
    default: .giveUp
    }
  }

  /// A clock set back must not make an old restart look recent for ever, nor a recent one old.
  public static func recent(_ history: [Double], now: Double) -> [Double] {
    history.filter { abs(now - $0) < window }
  }

  // The history travels from each Arbor to the next in the environment variable ARBOR_RESTARTS.

  public static func history(from text: String?) -> [Double] {
    (text ?? "").split(separator: ",").compactMap { Double($0) }.filter(\.isFinite).suffix(8).map { $0 }
  }

  public static func text(for history: [Double]) -> String {
    history.map { String(Int64($0.rounded())) }.joined(separator: ",")
  }
}
