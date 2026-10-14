/// Wraps any `Scheduler` and records the moment scheduled work runs. On a real Mac that moment depends on
/// what else the main thread is doing: work due in 0.25 s can run before or after an event that arrives
/// about then, and work due "at once" runs after the events already waiting. A replay that
/// went by the clock alone would get those orders wrong.
@MainActor
public final class RecordingScheduler: Scheduler {
  public let inner: any Scheduler
  public let recorder: TraceRecorder

  public init(wrapping inner: any Scheduler, recorder: TraceRecorder) {
    self.inner = inner
    self.recorder = recorder
  }

  public func schedule(_ key: String, after seconds: Double, _ action: @escaping @MainActor () -> Void) {
    inner.schedule(key, after: seconds) { [recorder] in
      guard recorder.isRecording else { return action() }
      recorder.stimulus(.timer(key), action)
    }
  }

  public func cancel(_ key: String) { inner.cancel(key) }
}
