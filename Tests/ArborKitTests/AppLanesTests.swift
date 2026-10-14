import ArborKit
import Foundation
import Testing

/// `AppLanes` with jobs that sleep in place of apps that answer slowly. The times are generous: they tell
/// "side by side" from "one after the other" and "did not wait" from "waited", not milliseconds.
@Suite struct AppLanesTests {
  /// Collects values from several threads.
  final class Box<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []
    func append(_ value: Value) { lock.withLock { stored.append(value) } }
    var values: [Value] { lock.withLock { stored } }
  }

  func seconds(_ body: () -> Void) -> Double {
    let elapsed = ContinuousClock().measure(body)
    return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
  }

  func job(app: Int32, id: UInt32, sleeping time: Double = 0, log: Box<UInt32>? = nil) -> AppLanes<UInt32>.Job {
    .init(app: app, id: id) {
      Thread.sleep(forTimeInterval: time)
      log?.append(id)
      return id * 10
    }
  }

  @Test func appsAnswerSideBySideAndEachAppInOrder() {
    let lanes = AppLanes<UInt32>()
    let log = Box<UInt32>()
    // Eight apps with three windows each, 20 ms a window: 480 ms one after the other, 60 ms side by side.
    let jobs = (0..<24).map { job(app: Int32($0 % 8), id: UInt32($0), sleeping: 0.02, log: log) }
    var outputs: [UInt32: UInt32] = [:]
    let elapsed = seconds { outputs = lanes.run(jobs, patience: 5).outputs }
    #expect(outputs.count == 24 && outputs[7] == 70)
    #expect(elapsed < 0.3, "took \(elapsed) s")
    for app in 0..<8 {
      #expect(log.values.filter { $0 % 8 == UInt32(app) } == [0, 8, 16].map { UInt32($0 + app) })
    }
  }

  @Test func aSlowAppCostsPatienceOnceAndFinishesInTheBackground() {
    let calls = Box<Bool>()
    let lanes = AppLanes<UInt32>(late: { calls.append(true) })
    var outputs: [UInt32: UInt32] = [:]
    let first = seconds {
      outputs = lanes.run(
        [job(app: 1, id: 1), job(app: 2, id: 2, sleeping: 0.4), job(app: 2, id: 3), job(app: 3, id: 4)], patience: 0.05
      ).outputs
    }
    #expect(outputs == [1: 10, 4: 40], "the others are done")
    #expect(first < 0.3, "waited \(first) s")
    #expect(lanes.isBusy(2) && !lanes.isBusy(1))

    // While it is busy its jobs are turned away without waiting, and the others' are not held up.
    let second = seconds { outputs = lanes.run([job(app: 2, id: 5), job(app: 1, id: 6)], patience: 5).outputs }
    #expect(outputs == [6: 60])
    #expect(second < 0.2, "waited \(second) s")

    #expect(lanes.takeLate().isEmpty, "nothing yet")
    #expect(lanes.waitUntilIdle(timeout: 5))
    #expect(calls.values == [true] && !lanes.isBusy(2))
    let late = lanes.takeLate()
    #expect(late.map(\.app) == [2] && late.first?.result.outputs == [2: 20, 3: 30], "what it was asked first still happened")
    #expect(lanes.takeLate().isEmpty, "handed out once")
    #expect(lanes.run([job(app: 2, id: 7)], patience: 5).outputs == [7: 70])
  }

  @Test func anAppThatDoesNotAnswerIsNamedAndTheRestOfItsBatchDropped() {
    let lanes = AppLanes<UInt32>()
    let asked = Box<UInt32>()
    func silence(_ id: UInt32) -> AppLanes<UInt32>.Job {
      .init(app: 9, id: id) {
        asked.append(id)
        return nil
      }
    }
    let result = lanes.run([job(app: 9, id: 1), silence(2), silence(3), job(app: 8, id: 4)], patience: 5)
    #expect(result.outputs == [1: 10, 4: 40] && result.silent == [9])
    #expect(asked.values == [2])
    #expect(!lanes.isBusy(9), "what to make of it is the caller's business")
  }

  @Test func silenceAfterPatienceRanOutIsReportedLate() {
    let lanes = AppLanes<UInt32>()
    let result = lanes.run(
      [
        .init(app: 9, id: 1) {
          Thread.sleep(forTimeInterval: 0.1)
          return nil
        }
      ], patience: 0.01)
    #expect(result.outputs.isEmpty && result.silent.isEmpty)
    lanes.waitUntilIdle(timeout: 5)
    #expect(lanes.takeLate().map(\.result.silent) == [[9]])
  }

  /// When there will be no next time: nothing is turned away, and everything happens in the order it was asked.
  @Test func jobsForABusyLaneWaitTheirTurnWhenAsked() {
    let lanes = AppLanes<UInt32>()
    #expect(lanes.run([job(app: 2, id: 1, sleeping: 0.2)], patience: 0.01).outputs.isEmpty)
    let waited = seconds {
      #expect(lanes.run([job(app: 2, id: 2)], patience: 0.01, queueing: true).outputs.isEmpty, "not in time")
      #expect(lanes.run([job(app: 2, id: 3)], patience: 0.01, queueing: true).outputs.isEmpty)
    }
    #expect(waited < 0.15, "waited \(waited) s")
    #expect(lanes.isBusy(2))
    #expect(lanes.waitUntilIdle(timeout: 5) && !lanes.isBusy(2))
    #expect(lanes.takeLate().map(\.result.outputs) == [[1: 10], [2: 20], [3: 30]])
    // A lane that is free answers within the caller's patience as always.
    #expect(lanes.run([job(app: 2, id: 4)], patience: 5, queueing: true).outputs == [4: 40])
  }

  /// A hung app would make each of them wait the whole timeout.
  @Test func whatWaitsBehindAJobThatWentUnansweredIsNotTried() {
    let lanes = AppLanes<UInt32>()
    let asked = Box<UInt32>()
    func silence(_ id: UInt32, after seconds: Double) -> AppLanes<UInt32>.Job {
      .init(app: 9, id: id) {
        asked.append(id)
        Thread.sleep(forTimeInterval: seconds)
        return nil
      }
    }
    _ = lanes.run([silence(1, after: 0.2)], patience: 0.01)
    _ = lanes.run([silence(2, after: 0.2)], patience: 0.01, queueing: true)
    _ = lanes.run([silence(3, after: 0.2)], patience: 0.01, queueing: true)
    #expect(lanes.waitUntilIdle(timeout: 5))
    #expect(asked.values == [1])
    #expect(lanes.takeLate().map(\.result.silent) == [[9], [9], [9]])
    // Once the lane has come to rest the app gets another chance.
    #expect(lanes.run([job(app: 9, id: 4)], patience: 5).outputs == [4: 40])
  }

  @Test func forgettingABusyAppIsSafe() {
    let lanes = AppLanes<UInt32>()
    #expect(lanes.run([job(app: 5, id: 1, sleeping: 0.1)], patience: 0.01).outputs.isEmpty)
    lanes.forget(5)
    #expect(lanes.waitUntilIdle(timeout: 5))
    #expect(!lanes.isBusy(5))
    #expect(lanes.run([job(app: 5, id: 2)], patience: 5).outputs == [2: 20], "a new app may get the same number")
  }

  /// The old lane's end must not free the lane of the app that got its number, nor speak in its name.
  @Test func anAppThatGetsTheNumberOfOneThatQuitHasALaneOfItsOwn() {
    let lanes = AppLanes<UInt32>()
    _ = lanes.run([job(app: 5, id: 1, sleeping: 0.1)], patience: 0.01)
    lanes.forget(5)
    _ = lanes.run([job(app: 5, id: 2, sleeping: 0.4)], patience: 0.01)
    Thread.sleep(forTimeInterval: 0.2)
    #expect(lanes.isBusy(5), "the old job has ended, the new one has not")
    #expect(lanes.run([job(app: 5, id: 3)], patience: 0.01).outputs.isEmpty, "turned away")
    #expect(lanes.waitUntilIdle(timeout: 5) && !lanes.isBusy(5))
    #expect(lanes.takeLate().map(\.result.outputs) == [[2: 20]])
  }

  @Test func nothingToDoReturnsAtOnce() {
    let lanes = AppLanes<UInt32>()
    var outputs: [UInt32: UInt32] = [1: 1]
    #expect(seconds { outputs = lanes.run([], patience: 5).outputs } < 0.1)
    #expect(outputs.isEmpty)
    #expect(lanes.waitUntilIdle(timeout: 0))
  }
}
