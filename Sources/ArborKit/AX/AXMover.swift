import ApplicationServices
import ArborCore
import CoreGraphics

/// One window to move, with all a lane needs to do it away from the main thread. The elements are
/// references to things in another process; the calls that take them are messages to that process
/// and may be made from any thread, which is what makes the box safe to send.
struct AXMove: @unchecked Sendable {
  var window: AXUIElement
  var app: AXUIElement?
  var pid: pid_t
  /// Where Arbor last saw the window.
  var known: CGRect
  var target: CGRect
  /// Where on each display a window can grow whole (`FramePlan.room`).
  var rooms: [CGRect]
}

struct AXMoveOutcome: Sendable {
  /// The frame the window has now, or nil if it could not be read (the window is gone).
  var frame: CGRect?
  /// macOS refused the call because Accessibility is disabled for Arbor (F63). Not the app's doing, and the calls to come
  /// would be refused as well.
  var refused = false
}

/// Moves one window with as few calls as will do (`FramePlan`). Runs on the window's app's lane (`AppLanes`);
/// touches nothing but the elements it is given.
enum AXMover {
  /// Returns nil if the app did not answer. One wait is enough: an app that is silent now will be silent for
  /// the calls to come.
  static func perform(_ move: AXMove) -> AXMoveOutcome? {
    // Apps with "enhanced user interface" on (set by assistive tools) animate
    // every frame change; turn it off while we move the window.
    var animates = false
    if let app = move.app {
      guard let answer = AXEnhancedUI.shared.isOn(for: move.pid, app: app) else { return nil }
      animates = answer
    }
    // Also when the app falls silent, at the very call that turns it off or half way: a call that times out is still delivered
    // when the app wakes up, and "off" must not be the last word it gets.
    defer { if animates { move.app?.setBool("AXEnhancedUserInterface", true) } }
    if animates, let app = move.app, AXCalls.wentUnanswered({ app.setBool("AXEnhancedUserInterface", false) }) {
      return nil
    }

    let steps = FramePlan.steps(from: move.known, to: move.target, rooms: move.rooms)
    guard var reading = take(steps, move) else { return nil }
    if let result = reading.frame, let more = FramePlan.makingUp(for: steps, result: result, target: move.target) {
      guard let second = take(more, move) else { return nil }
      reading = second
    }
    return reading
  }

  /// Sets the attributes a plan names and reads the frame back. Nil if the app did not answer. A refusal
  /// (a window with a fixed size, say) is an answer: the frame read back shows what came of it.
  static func take(_ steps: [FramePlan.Step], _ move: AXMove) -> AXMoveOutcome? {
    for step in steps {
      var error = AXError.success
      let unanswered = AXCalls.wentUnanswered {
        switch step {
        case .position(let origin): error = move.window.setPosition(origin)
        case .size(let size): error = move.window.setSize(size)
        }
        return error
      }
      if unanswered { return nil }
      if error == .apiDisabled { return AXMoveOutcome(frame: nil, refused: true) }
    }
    let reading = move.window.readFrame()
    return reading.unanswered ? nil : AXMoveOutcome(frame: reading.frame)
  }
}
