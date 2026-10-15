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
  /// Keys, not registrations: a key and its twin with fn are one.
  public var held: [KeyBinding] = []
  /// Asked for, and macOS said no.
  public var refused: [Refusal] = []
  /// No longer wanted, and macOS would not take it back: it is still taken from every app.
  public var stuck: [Refusal] = []
  /// Held, but macOS said no to its twin with fn: the key is Arbor's, and with fn down it is the app's in front.
  public var withoutTwin: [Refusal] = []

  public init(held: [KeyBinding] = [], refused: [Refusal] = [], stuck: [Refusal] = [], withoutTwin: [Refusal] = []) {
    self.held = held
    self.refused = refused
    self.stuck = stuck
    self.withoutTwin = withoutTwin
  }
}

/// Arbor's shortcuts as macOS has them: which are registered, under which number, for which command.
///
/// All that `HotKeyCenter` decides is decided here, where tests can run it. macOS comes in as two closures: one asks it for a
/// key, with fn or without, one gives a key back. `Ref` is what macOS hands out for a registered key.
///
/// **A key and its twin.** A key that has one (`KeyChord.hasFnTwin`) is registered twice, plainly and with fn, under two numbers
/// and one shortcut: whichever fires, the same command runs. The two come and go together: whoever is given the key gets it with fn
/// and without.
///
/// **One press, one command** (`heard`). Where macOS takes the two registrations for one, a press fires both: seen for arrows and their kin, and
/// to be expected of every key on a macOS that does not know the bit, since bits it does not know it ignores. macOS 15 and 26 know it; 14 has not been asked. So
/// it does not rest on who gets a twin alone: while a key is down under one number, what comes under the other is nobody's.
public struct HotKeyTable<Ref> {
  public typealias Status = HotKeyOutcome.Status
  public typealias Refusal = HotKeyOutcome.Refusal
  public typealias Outcome = HotKeyOutcome
  /// Asks macOS for the shortcut's key under this number, with fn (the last argument) or without.
  public typealias Ask = (KeyBinding, UInt32, Bool) -> (Ref?, Status)

  private struct Entry {
    let ref: Ref
    var binding: KeyBinding
    /// What macOS handed out for the twin, and its number.
    var twin: (ref: Ref, number: UInt32)?
    /// The number under which the key went down and has not come up.
    var down: UInt32?
    /// The number under which it went down besides, of which nobody was told.
    var muted: UInt32?
  }

  /// By the number of the plain registration.
  private var entries: [UInt32: Entry] = [:]
  /// The ones `setTemporary` added.
  private var temporary: [UInt32] = []
  /// Never used twice, so that the release of a shortcut that has been let go of meanwhile is nobody's, and a press still
  /// on its way then (another app came to the front) finds nothing rather than whichever command took over its number.
  /// A key that stays keeps its number: what is on its way runs the command the key has when it arrives, and a key
  /// that is down is heard coming up.
  private var lastIdentifier: UInt32 = 0

  public init() {}

  /// The shortcut registered under this number, a key's own or its twin's.
  public func binding(for identifier: UInt32) -> KeyBinding? { entry(of: identifier).flatMap { entries[$0]?.binding } }

  private func entry(of number: UInt32) -> UInt32? {
    entries[number] != nil ? number : entries.first { $0.value.twin?.number == number }?.key
  }

  /// macOS reports that the key registered under this number went down or came up. The shortcut to tell the controller of, or nil if
  /// there is nothing to tell: the number is nobody's any more, or the same press has been told of under the key's other number.
  ///
  /// As a Mac reported a press that fired both: down, down, up, up. Again under the same number is auto-repeat, and is passed on. A release
  /// that macOS never reports costs one press under the other number, and then all is well again.
  public mutating func heard(_ number: UInt32, _ phase: KeyPhase) -> KeyBinding? {
    guard let identifier = entry(of: number), let entry = entries[identifier] else { return nil }
    switch phase {
    case .pressed:
      if let down = entry.down, down != number {
        entries[identifier]?.muted = number
        return nil
      }
      entries[identifier]?.down = number
    case .released:
      entries[identifier]?.down = nil
      if entry.muted == number {
        entries[identifier]?.muted = nil
        return nil
      }
    }
    return entry.binding
  }

  /// How many keys macOS holds for Arbor, those for the time being included. A key and its twin are one.
  public var count: Int { entries.count }
  /// How many registrations that takes.
  public var registrations: Int { entries.count + entries.values.filter { $0.twin != nil }.count }

  /// Holds `wanted`, and besides only what is there for the time being. What is held and stays wanted is not let go of
  /// meanwhile (`HotKeyChanges`). What a peek added stays the peek's to take away, unless the key is wanted for good now.
  public mutating func hold(_ wanted: [KeyBinding], ask: Ask, giveBack: (Ref) -> Status) -> Outcome {
    let wantedKeys = Set(wanted.map(HotKey.init))
    temporary.removeAll { identifier in entries[identifier].map { wantedKeys.contains(HotKey($0.binding)) } ?? true }
    let besides = temporary.compactMap { entries[$0]?.binding }
    let changes = HotKeyChanges(from: entries.values.map(\.binding), to: wanted + besides)
    var outcome = Outcome()
    for binding in changes.dropped {
      if let refusal = remove(binding, giveBack) { outcome.stuck.append(refusal) }
    }
    for binding in changes.kept {
      guard let identifier = identifier(of: binding) else { continue }
      entries[identifier]?.binding = binding
      // One that macOS refused the last time is tried again. The key itself is not touched for it.
      if let refusal = seeToTheTwin(of: identifier, ask, giveBack) { outcome.withoutTwin.append(refusal) }
    }
    for binding in changes.added { add(binding, ask, giveBack, into: &outcome) }
    let refused = outcome.refused.map(\.binding)
    outcome.held = wanted.filter { !refused.contains($0) } + outcome.stuck.map(\.binding)
    return outcome
  }

  /// Holds these on top of the others, in place of the ones the last call added. The others stay as they are, and so does
  /// one that both calls name. A key that Arbor holds anyway is not asked for twice: macOS gives an app each key once.
  public mutating func setTemporary(_ bindings: [KeyBinding], ask: Ask, giveBack: (Ref) -> Status) -> Outcome {
    let keys = Set(bindings.map(HotKey.init))
    var outcome = Outcome()
    for identifier in temporary {
      guard let binding = entries[identifier]?.binding, !keys.contains(HotKey(binding)) else { continue }
      if let refusal = remove(binding, giveBack) { outcome.stuck.append(refusal) }
    }
    // One that macOS would not take back is still there, and still to be taken away.
    temporary.removeAll { entries[$0] == nil }
    for binding in bindings where identifier(of: binding) == nil {
      if let identifier = add(binding, ask, giveBack, into: &outcome) { temporary.append(identifier) }
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

  @discardableResult
  private mutating func add(
    _ binding: KeyBinding, _ ask: Ask, _ giveBack: (Ref) -> Status, into outcome: inout Outcome
  ) -> UInt32? {
    lastIdentifier &+= 1
    let identifier = lastIdentifier
    let (ref, status) = ask(binding, identifier, false)
    guard status == 0, let ref else {
      outcome.refused.append(Refusal(binding, status))
      return nil
    }
    entries[identifier] = Entry(ref: ref, binding: binding)
    if let refusal = seeToTheTwin(of: identifier, ask, giveBack) { outcome.withoutTwin.append(refusal) }
    return identifier
  }

  /// Gives the key its twin if it is to have one and has none. By the key's name and by its code, which is what macOS goes by: a keyboard
  /// layout of somebody's own making could put a letter where an arrow is.
  private mutating func seeToTheTwin(of identifier: UInt32, _ ask: Ask, _ giveBack: (Ref) -> Status) -> Refusal? {
    guard let entry = entries[identifier] else { return nil }
    guard entry.binding.chord.hasFnTwin, !HotKey(entry.binding).carriesFn else {
      // The same key can come to mean something else on another layout. If macOS keeps the twin, `heard` sees to it that nothing runs twice.
      if let twin = entry.twin, giveBack(twin.ref) == 0 { entries[identifier]?.twin = nil }
      return nil
    }
    guard entry.twin == nil else { return nil }
    lastIdentifier &+= 1
    let (ref, status) = ask(entry.binding, lastIdentifier, true)
    guard status == 0, let ref else { return Refusal(entry.binding, status) }
    entries[identifier]?.twin = (ref, lastIdentifier)
    return nil
  }

  /// The twin first, and the key only once that has gone: a key is never given away while Arbor still takes it with fn.
  ///
  /// If macOS will not take one back the entry stays: the key is still taken from every app, so it had better still be
  /// known, do what it did, and be given back at the next occasion.
  private mutating func remove(_ binding: KeyBinding, _ giveBack: (Ref) -> Status) -> Refusal? {
    guard let identifier = identifier(of: binding), let entry = entries[identifier] else { return nil }
    if let twin = entry.twin {
      let status = giveBack(twin.ref)
      guard status == 0 else { return Refusal(entry.binding, status) }
      entries[identifier]?.twin = nil
    }
    let status = giveBack(entry.ref)
    guard status == 0 else { return Refusal(entry.binding, status) }
    entries[identifier] = nil
    return nil
  }
}
