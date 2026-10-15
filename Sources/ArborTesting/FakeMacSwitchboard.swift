import ArborCore
import ArborKit

/// The switches under Desktop & Dock, in memory. As a Mac comes: nothing is stored.
@MainActor
public final class FakeMacSwitchboard: MacSwitchboard {
  public var values: [MacSwitch: Bool] = [:] {
    didSet { didChange?() }
  }
  /// macOS goes by what is stored at once, with nothing restarted. `Harness` has the fake window system follow.
  public var didChange: (() -> Void)?
  /// What Arbor has written down.
  public var before: [MacSwitchRecord] = []
  /// The major version of this Mac's macOS.
  public var macOS = 26
  /// The switches that somebody else manages on this Mac: what is written for them does not stay.
  public var managed: Set<MacSwitch> = []
  /// A disk that is full: nothing can be written down.
  public var cannotKeep = false
  /// What is written down cannot be read.
  public var cannotRead = false
  /// Every write, in order.
  public private(set) var writes: [MacSwitchRecord] = []

  public init() {}

  public func stored(_ item: MacSwitch) -> Bool? { values[item] }

  public func store(_ value: Bool?, for item: MacSwitch) {
    writes.append(MacSwitchRecord(item, stored: value))
    if !managed.contains(item) { values[item] = value }
  }

  public func records() -> [MacSwitchRecord]? { cannotRead ? nil : before }

  public func keep(_ records: [MacSwitchRecord]) -> Bool {
    guard !cannotKeep, !cannotRead else { return false }
    before = records
    return true
  }

  /// What `SystemFacts.switches` says on this Mac.
  public var on: [MacSwitch] {
    MacSwitch.inTheWay(macOS: macOS) { key in
      MacSwitch.allCases.first { $0.defaultsKey == key }.flatMap { self.values[$0] }
    }
  }
}
