// The model of a Mac (FakeMac.swift): other threads than Arbor's main one, on the model's clock. Never shipped.
//
// Code that talks to apps off the main thread (a serial queue for each app, the main thread waiting on a semaphore for so long and no longer) is written against Dispatch. In the copy
// of the sources `DispatchQueue(label:)`, `DispatchSemaphore`, `DispatchGroup`, `DispatchTime` and `DispatchQueue.main.async` become the types here (scripts/mac-on-linux/retime.py).
//
// Each queue has a real thread, because what runs on it is ordinary code that calls and waits in the middle of a function. But ONE BATON goes round: a thread runs only while it holds it, and
// gives it back when its block is done or when it waits for an app, which takes the model's time. So nothing runs beside anything else, every run is the same, and a call on a queue to an
// app that hangs takes a second of the model's time during which the main thread, the other queues and the Mac go on.
import Foundation

/// One thread that is not the main one.
final class Worker: @unchecked Sendable {
  nonisolated(unsafe) private static var made = 0
  /// The main thread waits here while a worker has the baton.
  private static let back = DispatchSemaphore(value: 0)
  /// Who has the baton, if not the main thread.
  nonisolated(unsafe) static var holder: Worker?

  let number: Int
  private let go = DispatchSemaphore(value: 0)
  private var blocks: [() -> Void] = []
  /// It has a block under way, or has been told that there is one.
  private var isBusy = false
  private var quits = false
  private var hasThread = false
  unowned let mac: FakeMac

  init(mac: FakeMac) {
    Self.made += 1
    number = Self.made
    self.mac = mac
  }

  /// By whoever has the baton.
  func add(_ block: @escaping () -> Void) {
    blocks.append(block)
    guard !isBusy else { return }
    isBusy = true
    // A thread takes a moment to wake. Guess.
    mac.send(after: 0.00005, from: .thread(number), "") { [self] in takeTheBaton() }
  }

  /// On the main thread: hands the baton over, and waits until it comes back.
  private func takeTheBaton() {
    precondition(Self.holder == nil && Thread.isMainThread, "only the main thread hands the baton out")
    if !hasThread {
      hasThread = true
      let thread = Thread { [self] in work() }
      thread.stackSize = 1 << 20
      thread.start()
    }
    Self.holder = self
    go.signal()
    Self.back.wait()
    Self.holder = nil
  }

  private func work() {
    while true {
      go.wait()
      if quits {
        Self.back.signal()
        return
      }
      while !blocks.isEmpty { blocks.removeFirst()() }
      isBusy = false
      Self.back.signal()
    }
  }

  /// On this thread: the model's time passes, for everybody else too.
  func wait(_ seconds: TimeInterval) {
    // Its Mac is no more: nothing takes time any longer, so that what is under way comes to its end.
    guard !mac.hasEnded, !mac.arborHasGone else { return }
    mac.send(after: seconds, from: .thread(number), "") { [self] in takeTheBaton() }
    Self.back.signal()
    go.wait()
  }

  /// The story is over. What is under way runs to its end, every call failing at once, and the thread goes.
  func finish() {
    while isBusy { takeTheBaton() }
    guard hasThread else { return }
    quits = true
    takeTheBaton()
  }
}

extension FakeMac {
  /// The calling thread waits until `deadline` or until `isOver`, in the model's time. While the MAIN thread waits nothing is delivered to it: notifications, events, its own timers and tasks queue up,
  /// and are served afterwards. The Mac, the apps and the other threads go on.
  func wait(until deadline: TimeInterval, orUntil isOver: () -> Bool = { false }) {
    if let worker = Worker.holder {
      // It looks every few milliseconds, which costs nothing here and spares a list of who waits for what.
      while !isOver(), now < deadline, !hasEnded, !arborHasGone { worker.wait(min(0.005, deadline - now)) }
      return
    }
    let began = now
    while !isOver() {
      guard !hasEnded, let item = takeNext(until: deadline, forTheMainThread: false) else {
        precondition(deadline < .infinity || hasEnded, "the main thread waits for ever for something that nothing on this Mac will bring about")
        now = max(now, min(deadline, now + 86_400))
        break
      }
      now = max(now, item.due)
      if !item.label.isEmpty { note(item.label) }
      item.run()
    }
    secondsTheMainThreadWaited += now - began
  }

  /// What `DispatchQueue.main.async` becomes in the copy. To the run loop the main queue is one more source, with no promise about its turn among the others.
  public static func mainAsync(_ work: @escaping @MainActor @Sendable () -> Void) {
    let mac = current
    mac.send(after: mac.mainQueueIsLateBy, from: .mainQueue, "") { MainActor.assumeIsolated(work) }
  }
}

public struct FakeDispatchTime: Comparable, Sendable {
  public let uptimeNanoseconds: UInt64
  public init(uptimeNanoseconds: UInt64) { self.uptimeNanoseconds = uptimeNanoseconds }
  public static func now() -> FakeDispatchTime { FakeDispatchTime(uptimeNanoseconds: UInt64(FakeMac.current.now * 1e9)) }
  public static let distantFuture = FakeDispatchTime(uptimeNanoseconds: .max)
  public static func + (time: FakeDispatchTime, seconds: Double) -> FakeDispatchTime {
    time == distantFuture ? time : FakeDispatchTime(uptimeNanoseconds: UInt64(max(Double(time.uptimeNanoseconds) + seconds * 1e9, 0)))
  }
  public static func < (a: FakeDispatchTime, b: FakeDispatchTime) -> Bool { a.uptimeNanoseconds < b.uptimeNanoseconds }
  var seconds: TimeInterval { self == .distantFuture ? .infinity : Double(uptimeNanoseconds) / 1e9 }
}

/// A serial queue.
public final class FakeDispatchQueue: @unchecked Sendable {
  public let label: String
  private let worker: Worker

  public init(label: String, qos: DispatchQoS = .unspecified) {
    self.label = label
    worker = Worker(mac: FakeMac.current)
    FakeMac.current.workers.append(worker)
  }

  public func async(group: FakeDispatchGroup? = nil, execute work: @escaping @Sendable () -> Void) {
    group?.enter()
    worker.add {
      work()
      group?.leave()
    }
  }
}

public final class FakeDispatchSemaphore: @unchecked Sendable {
  private var value: Int
  public init(value: Int) { self.value = value }

  @discardableResult
  public func signal() -> Int {
    value += 1
    return 0
  }

  public func wait(timeout: FakeDispatchTime) -> DispatchTimeoutResult {
    FakeMac.current.wait(until: timeout.seconds) { self.value > 0 }
    guard value > 0 else { return .timedOut }
    value -= 1
    return .success
  }

  public func wait() { _ = wait(timeout: .distantFuture) }
}

public final class FakeDispatchGroup: @unchecked Sendable {
  private var count = 0
  public init() {}
  public func enter() { count += 1 }
  public func leave() { count -= 1 }
  public func wait(timeout: FakeDispatchTime) -> DispatchTimeoutResult {
    FakeMac.current.wait(until: timeout.seconds) { self.count == 0 }
    return count == 0 ? .success : .timedOut
  }
  public func wait() { _ = wait(timeout: .distantFuture) }
}
