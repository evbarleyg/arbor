import ArborCore

/// How a change of what macOS holds for Arbor went.
public struct HotKeyOutcome: Equatable, Sendable {
  /// macOS's answer, an `OSStatus`. 0 is yes.
  public typealias Status = Int32

  public struct Refusal: Equatable, Sendable {
    public let binding: KeyBinding
    public let status: Status

    public init(_ binding: KeyBinding, _ status: Status) {
      self.binding = binding
      self.status = status
    }

    /// For the log: the number, and no guess at a reason.
    public var text: String { "\(binding.label) (error \(status))" }
  }

  /// What macOS holds for Arbor now, but for what is only there for the time being: in the order asked for, then `stuck`.
  public var held: [KeyBinding] = []
  /// Asked for, and macOS said no.
  public var refused: [Refusal] = []
  /// No longer wanted, and macOS would not take it back: it is still taken from every app.
  public var stuck: [Refusal] = []

  public init(held: [KeyBinding] = [], refused: [Refusal] = [], stuck: [Refusal] = []) {
    self.held = held
    self.refused = refused
    self.stuck = stuck
  }
}

/// Arbor's shortcuts as macOS has them: which are registered, under which number, for which command.
///
/// All that `HotKeyCenter` decides is decided here, where tests can run it. macOS comes in as two closures: one asks it for a
/// key, one gives a key back. `Ref` is what macOS hands out for a registered key.
public struct HotKeyTable<Ref> {
  public typealias Status = HotKeyOutcome.Status
  public typealias Refusal = HotKeyOutcome.Refusal
  public typealias Outcome = HotKeyOutcome

  private var entries: [UInt32: (ref: Ref, binding: KeyBinding)] = [:]
  /// The ones `setTemporary` added.
  private var temporary: [UInt32] = []
  /// Never used twice, so that the release of a shortcut that has been let go of meanwhile is nobody's, and a press still
  /// on its way then (another app came to the front) finds nothing rather than whichever command took over its number.
  /// A key that stays keeps its number: what is on its way runs the command the key has when it arrives, and a key
  /// that is down is heard coming up.
  private var lastIdentifier: UInt32 = 0

  public init() {}

  /// The shortcut registered under this number.
  public func binding(for identifier: UInt32) -> KeyBinding? { entries[identifier]?.binding }

  /// How many keys macOS holds for Arbor, those for the time being included.
  public var count: Int { entries.count }

  /// Holds `wanted`, and besides only what is there for the time being. What is held and stays wanted is not let go of
  /// meanwhile (`HotKeyChanges`). What a peek added stays the peek's to take away, unless the key is wanted for good now.
  public mutating func hold(
    _ wanted: [KeyBinding], ask: (KeyBinding, UInt32) -> (Ref?, Status), giveBack: (Ref) -> Status
  ) -> Outcome {
    let wantedKeys = Set(wanted.map(HotKey.init))
    temporary.removeAll { identifier in entries[identifier].map { wantedKeys.contains(HotKey($0.binding)) } ?? true }
    let besides = temporary.compactMap { entries[$0]?.binding }
    let changes = HotKeyChanges(from: entries.values.map(\.binding), to: wanted + besides)
    var outcome = Outcome()
    for binding in changes.dropped {
      if let refusal = remove(binding, giveBack) { outcome.stuck.append(refusal) }
    }
    for binding in changes.kept {
      if let identifier = identifier(of: binding) { entries[identifier]?.binding = binding }
    }
    for binding in changes.added {
      if let refusal = add(binding, ask).refusal { outcome.refused.append(refusal) }
    }
    let refused = outcome.refused.map(\.binding)
    outcome.held = wanted.filter { !refused.contains($0) } + outcome.stuck.map(\.binding)
    return outcome
  }

  /// Holds these on top of the others, in place of the ones the last call added. The others stay as they are, and so does
  /// one that both calls name. A key that Arbor holds anyway is not asked for twice: macOS gives an app each key once.
  public mutating func setTemporary(
    _ bindings: [KeyBinding], ask: (KeyBinding, UInt32) -> (Ref?, Status), giveBack: (Ref) -> Status
  ) -> Outcome {
    let keys = Set(bindings.map(HotKey.init))
    var outcome = Outcome()
    for identifier in temporary {
      guard let binding = entries[identifier]?.binding, !keys.contains(HotKey(binding)) else { continue }
      if let refusal = remove(binding, giveBack) { outcome.stuck.append(refusal) }
    }
    // One that macOS would not take back is still there, and still to be taken away.
    temporary.removeAll { entries[$0] == nil }
    for binding in bindings where identifier(of: binding) == nil {
      let (identifier, refusal) = add(binding, ask)
      if let identifier { temporary.append(identifier) }
      if let refusal { outcome.refused.append(refusal) }
    }
    return outcome
  }

  /// Gives everything back, at Quit.
  public mutating func giveAllBack(_ giveBack: (Ref) -> Status) -> Outcome {
    var outcome = Outcome()
    for binding in entries.values.map(\.binding) {
      if let refusal = remove(binding, giveBack) { outcome.stuck.append(refusal) }
    }
    temporary.removeAll { entries[$0] == nil }
    outcome.held = outcome.stuck.map(\.binding)
    return outcome
  }

  private func identifier(of binding: KeyBinding) -> UInt32? {
    entries.first { HotKey($0.value.binding) == HotKey(binding) }?.key
  }

  private mutating func add(
    _ binding: KeyBinding, _ ask: (KeyBinding, UInt32) -> (Ref?, Status)
  ) -> (identifier: UInt32?, refusal: Refusal?) {
    lastIdentifier &+= 1
    let (ref, status) = ask(binding, lastIdentifier)
    guard status == 0, let ref else { return (nil, Refusal(binding, status)) }
    entries[lastIdentifier] = (ref, binding)
    return (lastIdentifier, nil)
  }

  /// If macOS will not take it back the entry stays: the key is still taken from every app, so it had better still be
  /// known, do what it did, and be given back at the next occasion.
  private mutating func remove(_ binding: KeyBinding, _ giveBack: (Ref) -> Status) -> Refusal? {
    guard let identifier = identifier(of: binding), let entry = entries[identifier] else { return nil }
    let status = giveBack(entry.ref)
    guard status == 0 else { return Refusal(entry.binding, status) }
    entries[identifier] = nil
    return nil
  }
}
