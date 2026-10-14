import ArborCore
import ArborKit

/// Answers update checks from memory, at once or when the test says so.
@MainActor
public final class FakeReleaseFeed: ReleaseFeed {
  /// What a lookup answers. Nil keeps it waiting, like a slow network, until `answer(_:)`.
  public var reply: ReleaseLookup? = .nothingPublished
  /// How many lookups were made.
  public private(set) var requests = 0
  private var waiting: [@MainActor @Sendable (ReleaseLookup) -> Void] = []

  public init() {}

  public func latestRelease(_ completion: @escaping @MainActor @Sendable (ReleaseLookup) -> Void) {
    requests += 1
    if let reply { completion(reply) } else { waiting.append(completion) }
  }

  /// Answers every lookup that is waiting. With `keep`, they can be answered again, as a
  /// misbehaving feed would.
  public func answer(_ lookup: ReleaseLookup, keep: Bool = false) {
    let completions = waiting
    if !keep { waiting.removeAll() }
    for completion in completions { completion(lookup) }
  }
}
