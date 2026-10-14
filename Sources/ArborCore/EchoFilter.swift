import CoreGraphics
import Foundation

/// Tells Arbor's own moves, echoing back as Accessibility notifications, from moves by the user or the app.
///
/// Every frame Arbor sets comes back a moment later as "moved" and "resized" notifications, often several,
/// some with frames from half way (position and size are set one after the other). So for a short while
/// after a move every report about that window is an echo, and for a while longer a report of the
/// frame the window was given is one too.
///
/// Times are seconds on a clock that never goes backwards (the system's uptime), not the time of day: with
/// the clock set back an hour, an expectation would otherwise stay fresh for an hour and the user's
/// own moves would be ignored.
public struct EchoFilter: Sendable {
  /// Any report this soon after a move is an echo.
  public static let blanket: TimeInterval = 0.15
  /// A report of the expected frame is an echo for this long.
  public static let memory: TimeInterval = 1
  public static let tolerance: CGFloat = 2

  private struct Expectation: Sendable {
    var frame: CGRect
    var time: TimeInterval
  }

  private var expectations: [WindowID: Expectation] = [:]

  public init() {}

  /// Arbor has just given `window` this frame (the one it actually took).
  public mutating func expect(_ frame: CGRect, for window: WindowID, at time: TimeInterval) {
    expectations[window] = Expectation(frame: frame, time: time)
  }

  public enum Verdict: Equatable, Sendable {
    /// The frame Arbor gave the window.
    case echo
    /// Another frame, so soon after Arbor's move that it may be a stage of it. It may also be the app's own answer to
    /// the move (real traces show windows resizing themselves 0.1 s after being docked), which nothing would ever
    /// put right if it were ignored for good. Treat it as an echo now, and compare the window with `expectedFrame`
    /// once `settleTime` has passed.
    case early
    /// Somebody else's move.
    case other
  }

  /// How long after an `early` report to look at the window again.
  public static let settleTime: TimeInterval = 0.3

  public mutating func judge(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> Verdict {
    guard let expectation = expectations[window] else { return .other }
    let age = time - expectation.time
    guard age >= 0, age <= Self.memory else {
      expectations[window] = nil
      return .other
    }
    if expectation.frame.approximatelyEquals(frame, tolerance: Self.tolerance) { return .echo }
    return age < Self.blanket ? .early : .other
  }

  public mutating func isEcho(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> Bool {
    judge(frame, of: window, at: time) != .other
  }

  /// Whether a window that was reported `early` has ended up somewhere else than Arbor put it.
  public func hasStrayed(_ window: WindowID, now frame: CGRect) -> Bool {
    guard let expectation = expectations[window] else { return false }
    return !expectation.frame.approximatelyEquals(frame, tolerance: Self.tolerance)
  }

  public mutating func forget(_ window: WindowID) {
    expectations[window] = nil
  }

  /// How many windows are being waited for. Entries go when they are asked about after `memory`, and
  /// with their window.
  public var count: Int { expectations.count }
}
