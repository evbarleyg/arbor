/// Decides whether an event tap that macOS switched off goes straight back on.
///
/// macOS switches a tap off when its callback takes more than about a second over an event. Until
/// then that event, and every event behind it, waits. Once in a while that is harmless (the Mac was
/// waking, or short of memory) and the tap goes back on at once. If it keeps happening, every
/// switch-on buys another freeze of all input, for every app, so the taps are left off for a while
/// instead: Arbor loses a gesture, and the Mac stays usable.
///
/// One for all the taps of a thread. They are served one after the other, so when one is too slow it is the
/// thread that is, and the event that got past a tap that was switched off waits at the next. Counted
/// tap by tap, every tap on the same events would buy its own three freezes.
///
/// Times are seconds on any clock that does not go backwards.
public struct TapHealth: Equatable, Sendable {
  /// This many switch-offs within `window` seconds, and the taps rest for `rest` seconds.
  public static let limit = 3
  public static let window = 10.0
  public static let rest = 30.0

  /// What to do about a tap that is off.
  public enum Verdict: Equatable, Sendable {
    /// Switch it back on.
    case switchOn
    /// It keeps happening. Switch every tap of the thread off: a rest begins.
    case restAll
    /// The taps are resting. Leave it off.
    case stayOff
    /// The rest is over. Switch every tap of the thread back on now: one left for its own check to find
    /// would count as switched off again.
    case wakeAll
  }

  private var switchOffs: [Double] = []
  /// Since when the taps have been left off, if they have.
  public private(set) var restingSince: Double?

  public init() {}

  /// While this is true no tap of the thread may be switched on, whoever asks.
  public var isResting: Bool { restingSince != nil }

  /// macOS says that it switched a tap off.
  public mutating func switchedOff(at now: Double) -> Verdict {
    // It says so late, in place of the next event the tap would have had, which can be after a check found out.
    guard !isResting else { return .stayOff }
    switchOffs.removeAll { now - $0 >= Self.window }
    switchOffs.append(now)
    guard switchOffs.count >= Self.limit else { return .switchOn }
    switchOffs.removeAll()
    restingSince = now
    return .restAll
  }

  /// A regular check found a tap off that should be on: the taps are resting, or macOS switched it off
  /// without telling the callback, which counts like any other switch-off.
  public mutating func foundOff(at now: Double) -> Verdict {
    guard let restingSince else { return switchedOff(at: now) }
    guard now - restingSince >= Self.rest else { return .stayOff }
    self.restingSince = nil
    return .wakeAll
  }
}
