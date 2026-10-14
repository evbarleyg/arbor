import Foundation

/// When to try again to observe an app that does not accept observers yet.
///
/// An app that is not ready refuses at once, so trying costs nothing; what matters is to keep trying long
/// enough for a slow starter. Eight tries a quarter of a second apart gave up after two seconds.
public enum RetrySchedule {
  public static let attempts = 8

  /// Seconds to wait before retry number `attempt` (0 is the first retry), or nil to give up:
  /// 0.25, 0.5, 1, 2, 4, 8, 8, 8, about half a minute in all.
  public static func delay(beforeRetry attempt: Int) -> TimeInterval? {
    guard attempt >= 0, attempt < attempts else { return nil }
    return Swift.min(0.25 * Double(1 << Swift.min(attempt, 5)), 8)
  }
}
