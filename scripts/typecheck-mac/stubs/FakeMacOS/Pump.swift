// The pump of the model of a Mac (FakeMac.swift): runs Arbor's tasks on one thread until nothing is runnable. Never shipped.
import Foundation

/// Runs Swift's tasks on the calling thread, which must be the main one, until none is runnable.
///
/// Jobs for the main actor go to libdispatch's main queue, which is served the way CoreFoundation's run loop serves it: a file descriptor says
/// that there is work, a callback does it. Jobs for the global pool (`Task.detached`, a `nonisolated async` function) are caught by the
/// runtime's hook and run here too, in the order they were made, marked as being off the main thread.
public enum Pump {
  private typealias Enqueue = @convention(thin) (UnownedJob) -> Void
  private typealias Hook = @convention(thin) (UnownedJob, Enqueue) -> Void

  nonisolated(unsafe) private static var elsewhere: [UnownedJob] = []
  nonisolated(unsafe) private static var isRunning = false
  /// True while a job runs that on a Mac would be on another thread than the main one.
  nonisolated(unsafe) public private(set) static var isOffTheMainThread = false

  private final class OtherThread: SerialExecutor, @unchecked Sendable {
    func enqueue(_ job: consuming ExecutorJob) { Pump.elsewhere.append(UnownedJob(job)) }
    func asUnownedSerialExecutor() -> UnownedSerialExecutor { UnownedSerialExecutor(ordinary: self) }
  }
  private static let otherThread = OtherThread()

  private struct MainQueue: @unchecked Sendable {
    let handle: @convention(c) () -> Int32
    let drain: @convention(c) (UnsafeMutableRawPointer?) -> Void
  }

  private static func symbol(_ name: String) -> UnsafeMutableRawPointer {
    guard let found = dlsym(dlopen(nil, RTLD_LAZY), name) else {
      fatalError("this toolchain has no \(name): the pump of scripts/typecheck-mac/stubs/FakeMacOS/Pump.swift has to be looked at again")
    }
    return found
  }

  private static let mainQueue: MainQueue = {
    symbol("swift_task_enqueueGlobal_hook").assumingMemoryBound(to: Hook?.self).pointee = { job, _ in Pump.elsewhere.append(job) }
    return MainQueue(
      handle: unsafeBitCast(symbol("_dispatch_get_main_queue_handle_4CF"), to: (@convention(c) () -> Int32).self),
      drain: unsafeBitCast(symbol("_dispatch_main_queue_callback_4CF"), to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self))
  }()

  /// Must be called before the first task is made, or that task goes to a real thread pool.
  public static func install() { _ = mainQueue }

  private static func mainQueueHasWork() -> Bool {
    var question = pollfd(fd: mainQueue.handle(), events: Int16(POLLIN), revents: 0)
    guard poll(&question, 1, 0) > 0 else { return false }
    var count: UInt64 = 0
    _ = read(question.fd, &count, MemoryLayout<UInt64>.size)
    return true
  }

  public static func runTasks() {
    precondition(Thread.isMainThread && !isRunning, "the pump runs on the main thread, and not from inside a task")
    isRunning = true
    defer { isRunning = false }
    while true {
      if mainQueueHasWork() {
        mainQueue.drain(nil)
      } else if !elsewhere.isEmpty {
        isOffTheMainThread = true
        elsewhere.removeFirst().runSynchronously(on: otherThread.asUnownedSerialExecutor())
        isOffTheMainThread = false
      } else {
        return
      }
    }
  }
}
