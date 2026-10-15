import ApplicationServices
import ArborCore
import CoreGraphics
import Foundation

/// Giving one window a frame, as far as that is a conversation with its app: what is asked, in which order, and what came of it.
///
/// It touches nothing but the two elements it is handed, keeps no books and tells nobody, so it does not matter which thread it runs
/// on. That is what lets several apps be asked side by side (`AXWindowSystem.moveTogether`): a real app takes 5 to 150 ms to lay
/// out its content for a new size, and nine of them, waited for one after the other, were seen to arrive over half a second.
/// Whatever has to be remembered or reported afterwards is `AXWindowSystem.book`'s, on the main thread.
struct AXFrameJob: @unchecked Sendable {
  let window: WindowID
  let pid: pid_t
  let element: AXUIElement
  /// The window's app, if there is something to ask it first.
  let app: AXUIElement?
  /// What to set, in which order. Made by whoever makes the job, on the main thread: a plan looks at the displays.
  let steps: [FramePlan.Step]
  let target: CGRect

  enum Outcome: Equatable, Sendable {
    /// The frame read back afterwards. A refusal (a window with a fixed size, say) is an answer: this shows what came of it.
    case took(CGRect)
    /// A call came back without an answer. Nothing is known about a window whose frame cannot be read back: saying that it took the
    /// frame would keep Arbor from ever trying again.
    case silent
    /// Not the app's silence: Arbor's permission is gone (Controller+Permission.swift). `atOnce`: at the first question, before
    /// anything was asked of the window.
    case refused(atOnce: Bool)
  }

  func run() -> Outcome {
    // Apps with "enhanced user interface" on (set by assistive tools) animate
    // every frame change; turn it off while we move the window.
    var enhanced = false
    if let answer = app?.read("AXEnhancedUserInterface") {
      // An app that is silent now will be silent for the five calls to come. One wait is enough.
      if answer.error == .cannotComplete { return .silent }
      // The calls to come would be refused as well.
      if answer.error == .apiDisabled { return .refused(atOnce: true) }
      if let value = answer.value, CFGetTypeID(value) == CFBooleanGetTypeID() {
        enhanced = CFBooleanGetValue((value as! CFBoolean))
      }
    }
    if enhanced { app?.setBool("AXEnhancedUserInterface", false) }

    var wasRefused = false
    var result = perform(steps, wasRefused: &wasRefused)
    if let taken = result, let more = FramePlan.makingUp(for: steps, result: taken, target: target) {
      result = perform(more, wasRefused: &wasRefused)
    }

    // Also when the app fell silent half way: a call that times out is still delivered when the app wakes up.
    if enhanced { app?.setBool("AXEnhancedUserInterface", true) }
    if let result { return .took(result) }
    return wasRefused ? .refused(atOnce: false) : .silent
  }

  /// Sets the attributes a plan names and reads the frame back. Nil if the app did not answer, or Arbor may not ask.
  private func perform(_ steps: [FramePlan.Step], wasRefused: inout Bool) -> CGRect? {
    for step in steps {
      let error =
        switch step {
        case .size(let size): element.setSize(size)
        case .position(let origin): element.setPosition(origin)
        }
      if error == .cannotComplete { return nil }
      if error == .apiDisabled {
        wasRefused = true
        return nil
      }
    }
    return element.frame
  }
}

/// What came of a batch, app by app. Each queue writes to its own app's list; the main thread reads when all are done.
final class BatchResults: @unchecked Sendable {
  typealias Entry = (job: AXFrameJob, outcome: AXFrameJob.Outcome, waited: TimeInterval)
  private let lock = NSLock()
  private var byApp: [[Entry]]

  init(apps: Int) { byApp = Array(repeating: [], count: apps) }

  func add(_ entry: Entry, app: Int) {
    lock.lock()
    defer { lock.unlock() }
    byApp[app].append(entry)
  }

  func all() -> [Entry] {
    lock.lock()
    defer { lock.unlock() }
    return byApp.flatMap { $0 }
  }
}
