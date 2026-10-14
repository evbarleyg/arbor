import ArborKit
import Foundation
import Testing

@Suite @MainActor struct MainQueueSchedulerTests {
  /// Delays can come from settings.json. Turning one of these into nanoseconds used to trap.
  @Test(arguments: [1e300, Double.infinity, Double.greatestFiniteMagnitude])
  func aHugeDelayWaitsInsteadOfCrashing(delay: Double) async throws {
    let scheduler = MainQueueScheduler()
    var ran = false
    scheduler.schedule("later", after: delay) { ran = true }
    try await Task.sleep(nanoseconds: 20_000_000)
    #expect(!ran)
    scheduler.cancel("later")
  }

  @Test(arguments: [0, -1, -1e300, -Double.infinity, Double.nan])
  func aDelayThatMakesNoSenseIsNoDelay(delay: Double) async throws {
    let scheduler = MainQueueScheduler()
    var ran = false
    scheduler.schedule("now", after: delay) { ran = true }
    for _ in 0..<200 where !ran { try await Task.sleep(nanoseconds: 5_000_000) }
    #expect(ran)
  }

  @Test func aNewerRequestReplacesAPendingOne() async throws {
    let scheduler = MainQueueScheduler()
    var ran: [String] = []
    scheduler.schedule("key", after: 0.01) { ran.append("first") }
    scheduler.schedule("key", after: 0.01) { ran.append("second") }
    for _ in 0..<200 where ran.isEmpty { try await Task.sleep(nanoseconds: 5_000_000) }
    try await Task.sleep(nanoseconds: 30_000_000)
    #expect(ran == ["second"])
  }
}
