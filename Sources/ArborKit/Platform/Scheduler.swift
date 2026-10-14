/// Runs work later, keyed so a newer request replaces a pending one
/// (debouncing). Injected so tests can run pending work on demand.
@MainActor
public protocol Scheduler: AnyObject {
  func schedule(_ key: String, after seconds: Double, _ action: @escaping @MainActor () -> Void)
  func cancel(_ key: String)
}

@MainActor
public final class MainQueueScheduler: Scheduler {
  private var tasks: [String: Task<Void, Never>] = [:]

  public init() {}

  public func schedule(_ key: String, after seconds: Double, _ action: @escaping @MainActor () -> Void)
  {
    tasks[key]?.cancel()
    // Delays can come from settings.json. At most a day, because converting one that is huge or not
    // a number to a count of nanoseconds would trap.
    let delay = seconds > 0 ? min(seconds, 86_400) : 0
    tasks[key] = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      self?.tasks[key] = nil
      action()
    }
  }

  public func cancel(_ key: String) {
    tasks[key]?.cancel()
    tasks[key] = nil
  }
}
