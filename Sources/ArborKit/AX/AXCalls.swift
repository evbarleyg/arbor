import ApplicationServices
import Dispatch
import Foundation

/// Every Accessibility call goes through `timed`, so the `stats` command can say what the calls cost, by kind,
/// by app, and on which thread. A call is a message to the other app and a wait for its answer: a fraction
/// of a millisecond from an idle app, and up to `timeout` from a busy one. Safe from any thread.
enum AXCalls {
  /// How long a call waits for an app, in seconds.
  static let timeout: Float = 1

  static func timed<Result>(_ kind: String, _ element: AXUIElement, _ call: () -> Result) -> Result {
    let start = DispatchTime.now()
    let result = call()
    let seconds = CallStats.seconds(since: start)
    let stats = CallStats.shared
    stats.record("accessibility calls", kind, seconds: seconds)
    stats.record("accessibility calls by thread", Thread.isMainThread ? "main thread" : "lanes", seconds: seconds)
    var pid: pid_t = 0
    if AXUIElementGetPid(element, &pid) == .success {
      stats.record("accessibility calls by app", names.name(of: pid), seconds: seconds)
    }
    return result
  }

  /// Whether `call` went unanswered: the app took the whole timeout. An app that is gone, or that refuses what
  /// was asked, can report the same error, but does so at once.
  static func wentUnanswered(_ call: () -> AXError) -> Bool {
    let start = DispatchTime.now()
    return call() == .cannotComplete && CallStats.seconds(since: start) > Double(timeout) / 2
  }

  static let names = Names()

  /// What to call each app in the statistics: its bundle id, which may be logged.
  final class Names: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [pid_t: String] = [:]

    func set(_ name: String?, for pid: pid_t) {
      lock.lock()
      defer { lock.unlock() }
      names[pid] = name
    }

    func name(of pid: pid_t) -> String {
      lock.lock()
      defer { lock.unlock() }
      return names[pid] ?? "pid \(pid)"
    }
  }
}

/// Whether each app has "enhanced user interface" on, which assistive tools set and which makes the app
/// animate every frame change. Asked once for all the moves of a moment instead of before every one. Safe from any thread.
///
/// It hardly ever changes, and is remembered for a second only all the same, because the question is also a guard. An app that
/// hangs carries out, when it wakes, whatever was sent to it meanwhile, perhaps with Arbor gone: a window told to go out of view
/// would go there with nobody left to fetch it. So the first call to an app that has not been heard of for a second asks
/// something and sets nothing, and one that hangs by then gets nothing to carry out.
final class AXEnhancedUI: @unchecked Sendable {
  static let shared = AXEnhancedUI()

  private let lock = NSLock()
  private var known: [pid_t: (isOn: Bool, asked: DispatchTime)] = [:]

  /// Nil if the app did not answer, which is not remembered.
  func isOn(for pid: pid_t, app: AXUIElement) -> Bool? {
    lock.lock()
    let entry = known[pid]
    lock.unlock()
    if let entry, CallStats.seconds(since: entry.asked) < 1 { return entry.isOn }
    var isOn = false
    let unanswered = AXCalls.wentUnanswered {
      let answer = app.read("AXEnhancedUserInterface")
      isOn = AXUIElement.bool(answer.value) ?? false
      return answer.error
    }
    if unanswered { return nil }
    lock.lock()
    known[pid] = (isOn, .now())
    lock.unlock()
    return isOn
  }

  func forget(_ pid: pid_t) {
    lock.lock()
    defer { lock.unlock() }
    known[pid] = nil
  }
}
