/// Decides from a series of answers to "may Arbor still use Accessibility?" when the permission is gone and
/// when it is back (docs/features/F63-permission-taken-away.md).
///
/// One "no" out of the blue is not believed: the daemon that answers restarts now and then. It is asked again
/// soon, and the second "no" counts. A "no" that something else bears out (a command is about to pretend, the event
/// taps' watchdog found the same) counts at once. One "yes" is enough to come back: starting for nothing moves nothing.
public struct PermissionWatch: Equatable, Sendable {
  public enum Change: Equatable, Sendable {
    case none, lost, returned
  }

  public private(set) var isGranted = true
  /// How many times in a row the answer was "no" while the permission was still believed to be there.
  private var doubts = 0

  public init() {}

  /// Takes in an answer. `beyondDoubt`: there is a second reason to believe a "no".
  public mutating func heard(_ granted: Bool, beyondDoubt: Bool = false) -> Change {
    if granted {
      doubts = 0
      guard !isGranted else { return .none }
      isGranted = true
      return .returned
    }
    guard isGranted else { return .none }
    doubts += 1
    guard beyondDoubt || doubts >= 2 else { return .none }
    doubts = 0
    isGranted = false
    return .lost
  }

  /// Seconds until the next question: unhurried while all is well, soon after a first "no", and often enough
  /// while the permission is gone that flipping the switch feels immediate.
  public var secondsToNextQuestion: Double {
    if !isGranted { return 1 }
    return doubts > 0 ? 0.5 : 2
  }
}
