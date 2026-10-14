import Dispatch
import Foundation

/// Counts and times what Arbor does: commands, layouts, and every call to another app. The `stats` command
/// prints it, so "Arbor feels slow" can be answered with which app is slow and which call. Always on: an
/// entry costs a lock and a dictionary update, a thousandth of the cheapest call it measures. Safe from any thread.
public final class CallStats: @unchecked Sendable {
  /// What the running app records into. Tests make their own.
  public static let shared = CallStats()

  public struct Entry: Equatable, Sendable {
    public var count = 0
    /// Seconds.
    public var total = 0.0
    public var worst = 0.0
  }

  /// Arbor runs for weeks, and some names come from outside (an app without a bundle id goes by its process
  /// number). A group that is full counts newcomers together, under this name.
  public static let others = "(others)"
  public static let namesPerGroup = 200

  private let lock = NSLock()
  private var groups: [String: [String: Entry]] = [:]
  private var since = DispatchTime.now()

  public init() {}

  public func record(_ group: String, _ name: String, seconds: Double) {
    lock.lock()
    defer { lock.unlock() }
    var name = name
    if let known = groups[group], known[name] == nil, known.count >= Self.namesPerGroup { name = Self.others }
    var entry = groups[group]?[name] ?? Entry()
    entry.count += 1
    entry.total += seconds
    entry.worst = max(entry.worst, seconds)
    groups[group, default: [:]][name] = entry
  }

  /// Runs `body` and records how long it took.
  public func time<Result>(_ group: String, _ name: String, _ body: () throws -> Result) rethrows -> Result {
    let start = DispatchTime.now()
    defer { record(group, name, seconds: Self.seconds(since: start)) }
    return try body()
  }

  public static func seconds(since start: DispatchTime) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1e9
  }

  public subscript(group: String, name: String) -> Entry? {
    lock.lock()
    defer { lock.unlock() }
    return groups[group]?[name]
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    groups.removeAll()
    since = .now()
  }

  /// A table per group, the costliest entry first. Times are in milliseconds.
  public func report() -> String {
    lock.lock()
    let groups = self.groups
    let age = Self.seconds(since: since)
    lock.unlock()

    func pad(_ text: String, _ width: Int) -> String {
      String(repeating: " ", count: max(width - text.count, 0)) + text
    }
    func milliseconds(_ seconds: Double) -> String { pad(String(format: "%.2f", seconds * 1000), 11) }
    var lines = [String(format: "the last %.1f s", age)]
    for group in groups.keys.sorted() {
      lines.append("")
      lines.append(group.padding(toLength: 40, withPad: " ", startingAt: 0) + "  count   total ms    mean ms   worst ms")
      let entries = groups[group]!.sorted { ($1.value.total, $0.key) < ($0.value.total, $1.key) }
      for (name, entry) in entries {
        lines.append(
          ("  " + name).padding(toLength: 40, withPad: " ", startingAt: 0) + pad(String(entry.count), 7)
            + milliseconds(entry.total) + milliseconds(entry.total / Double(entry.count)) + milliseconds(entry.worst))
      }
    }
    if groups.isEmpty { lines.append("nothing recorded") }
    return lines.joined(separator: "\n")
  }
}
