import Dispatch
import Foundation

/// Talks to many apps at once without ever waiting long for any of them.
///
/// A request to another app (an Accessibility call) blocks until the app answers, and a busy app answers
/// late or not at all. Each app gets a lane: its jobs run one after the other, in order, off the main
/// thread, while other apps' lanes run beside it. The caller waits for all of them, but only so long
/// (`patience`), so a batch costs what the slowest app costs rather than the sum, and a slow app costs
/// its share of patience once: a lane that is still working when patience runs out finishes in the
/// background and leaves what it got for `takeLate`, and until it has finished, new jobs for that app
/// are turned away at once. That is right while somebody is waiting for the screen to change and there will be a next
/// time. When there will not, the jobs can wait their turn on the lane instead (`queueing`).
///
/// A job that was turned away, not answered, or not finished in time has no entry in the result. What to do
/// about an app that does not answer is the caller's business. Nothing here knows about Accessibility, so
/// the tests run everywhere.
public final class AppLanes<Output: Sendable>: @unchecked Sendable {
  public struct Job: Sendable {
    public var app: Int32
    /// Names the job in the result, e.g. a window number. Unique within a batch.
    public var id: UInt32
    /// Runs on the app's lane. Returns nil if the app did not answer; the rest of the app's batch is dropped.
    public var work: @Sendable () -> Output?

    public init(app: Int32, id: UInt32, work: @escaping @Sendable () -> Output?) {
      self.app = app
      self.id = id
      self.work = work
    }
  }

  public struct Result: Sendable {
    /// What the jobs returned, by job id.
    public var outputs: [UInt32: Output] = [:]
    /// Apps one of whose jobs returned nil.
    public var silent: Set<Int32> = []
  }

  private struct Lane {
    let queue: DispatchQueue
    /// Batches on the lane: the one at work and those that wait their turn.
    var batches = 0
    /// The app let a job go unanswered. What waits behind it would only wait as long again, each of them.
    var wentSilent = false
  }

  /// One call of `run`. Guarded by the lanes' lock.
  private final class Batch: @unchecked Sendable {
    var result = Result()
    var lanesAwaited = 0
    var isClosed = false
    let done = DispatchSemaphore(value: 0)
  }

  private let lock = NSLock()
  private var lanes: [Int32: Lane] = [:]
  private let working = DispatchGroup()
  private var tardy: [(app: Int32, result: Result)] = []
  private let late: @Sendable () -> Void

  /// - Parameter late: says that there is something for `takeLate`. Called on a lane, when that lane is free again.
  public init(late: @escaping @Sendable () -> Void = {}) {
    self.late = late
  }

  /// Runs the jobs and returns what came back within `patience` seconds. With `queueing`, jobs for a lane that is
  /// busy are not turned away: they run when it is free, however long the caller waits.
  public func run(_ jobs: [Job], patience: Double, queueing: Bool = false) -> Result {
    var order: [Int32] = []
    var byApp: [Int32: [Job]] = [:]
    for job in jobs {
      if byApp[job.app] == nil { order.append(job.app) }
      byApp[job.app, default: []].append(job)
    }

    let batch = Batch()
    lock.lock()
    for app in order {
      var lane = lanes[app] ?? Lane(queue: DispatchQueue(label: "dev.arbor.lane.\(app)", qos: .userInteractive))
      if lane.batches > 0, !queueing { continue }
      lane.batches += 1
      lanes[app] = lane
      batch.lanesAwaited += 1
      let jobs = byApp[app]!
      let queue = lane.queue
      working.enter()
      queue.async { [self] in
        work(through: jobs, of: app, on: queue, for: batch)
        working.leave()
      }
    }
    let waits = batch.lanesAwaited > 0
    lock.unlock()

    if waits { _ = batch.done.wait(timeout: .now() + max(patience, 0)) }
    lock.lock()
    defer { lock.unlock() }
    batch.isClosed = true
    return batch.result
  }

  private func work(through jobs: [Job], of app: Int32, on queue: DispatchQueue, for batch: Batch) {
    // The app may quit while its lane works (`forget`), and a new app may get its number and a lane of its own, which is
    // none of this one's business. Call with the lock held.
    func isStillItsLane() -> Bool { lanes[app]?.queue === queue }
    var tardy = Result()
    for job in jobs {
      lock.lock()
      let skips = isStillItsLane() && lanes[app]!.wentSilent
      lock.unlock()
      let output = skips ? nil : job.work()
      lock.lock()
      if let output {
        if batch.isClosed { tardy.outputs[job.id] = output } else { batch.result.outputs[job.id] = output }
      } else {
        if batch.isClosed { tardy.silent.insert(app) } else { batch.result.silent.insert(app) }
        if isStillItsLane() { lanes[app]!.wentSilent = true }
      }
      lock.unlock()
      if output == nil { break }
    }
    lock.lock()
    let isCurrent = isStillItsLane()
    if isCurrent {
      lanes[app]!.batches -= 1
      if lanes[app]!.batches == 0 { lanes[app]!.wentSilent = false }
    }
    let wasClosed = batch.isClosed
    if !wasClosed {
      batch.lanesAwaited -= 1
      if batch.lanesAwaited == 0 { batch.done.signal() }
    }
    // Also with nothing to show: whoever was turned away meanwhile can come again now.
    let reports = wasClosed && isCurrent
    if reports { self.tardy.append((app, tardy)) }
    lock.unlock()
    if reports { late() }
  }

  /// What lanes got after their callers stopped waiting, in the order they finished. Each is handed out once. After
  /// `waitUntilIdle` has returned true everything there will ever be is here, whether or not `late` has been heard.
  public func takeLate() -> [(app: Int32, result: Result)] {
    lock.lock()
    defer { lock.unlock() }
    defer { tardy.removeAll() }
    return tardy
  }

  /// Whether jobs for `app` would be turned away now: it is still busy with earlier ones. Callers on the main
  /// thread use it to spare themselves a wait.
  public func isBusy(_ app: Int32) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return (lanes[app]?.batches ?? 0) > 0
  }

  /// Forgets an app that quit.
  public func forget(_ app: Int32) {
    lock.lock()
    defer { lock.unlock() }
    lanes[app] = nil
  }

  /// Waits until every lane has finished, or `timeout` seconds. Returns whether they all have.
  @discardableResult
  public func waitUntilIdle(timeout: Double) -> Bool {
    working.wait(timeout: .now() + max(timeout, 0)) == .success
  }
}
