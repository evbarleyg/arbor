import ArborKit
import Testing

/// The scheduler the app runs on. The controller relies on: a newer request under the same key
/// replaces the pending one, cancelled work never runs, and work never runs inside the call that
/// scheduled it.
@Suite @MainActor struct SchedulerGuaranteeTests {
  @Test func aNewerRequestReplacesThePendingOneAndCancelledWorkNeverRuns() async throws {
    let scheduler = MainQueueScheduler()
    var ran: [String] = []
    scheduler.schedule("a", after: 0) { ran.append("first a") }
    scheduler.schedule("a", after: 0) { ran.append("second a") }
    scheduler.schedule("b", after: 0) { ran.append("b") }
    scheduler.cancel("b")
    scheduler.schedule("c", after: 0.01) {
      ran.append("c")
      // Scheduling the same key from inside its own work must stick.
      scheduler.schedule("c", after: 0) { ran.append("c again") }
    }
    #expect(ran.isEmpty, "nothing runs inside the call that scheduled it, even with no delay")
    // Other suites keep the main actor busy for seconds at a time, so wait for the last piece of
    // work rather than for a fixed time; whatever was replaced or cancelled was due before it.
    for _ in 0..<600 where !ran.contains("c again") { try await Task.sleep(nanoseconds: 50_000_000) }
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(ran.sorted() == ["c", "c again", "second a"])
  }
}
