/// Decides when the event taps go because Arbor may no longer have them.
///
/// Seen on hosted Macs (macOS 26): once macOS has withdrawn the right to tap from a process that has active event taps, the first
/// event that a switched-on tap asks for is dropped, **and with it every event of the whole Mac** for about a second: also
/// keys, which no tap of Arbor's asks for, and the wheel, whose tap was switched off. Then input flows until the next such
/// event. With one more often than once a second nothing arrives at all, until the taps are removed. With the same Arbor without
/// taps, and with no Arbor, nothing was lost. A bare tool with one tap that never let go was told late and wrongly ("switched off
/// by timeout", seconds after, in place of the next event that got through, while its tap stayed switched on and swallowed the
/// next press too). So removal gives the Mac back, the hole is as long as Arbor takes to find out by asking, and finding out may
/// depend on nothing that can be busy.
///
/// - **No tap is switched on but by a fresh yes.** A tap that is in but switched off starts nothing, in four rounds of four; one
///   that was switched on after the right had gone started the drop that instant. So whoever wants a tap on asks first
///   (`wantsOn`), which takes a third of a millisecond, unless macOS has said yes within the last two beats.
/// - The clock beats on the taps' own thread while a tap is wanted on, and not otherwise: taps that are off need nobody to watch
///   over them. Not on the main thread, which waits for apps.
/// - The question is not put on that thread either: it goes to the window server and the privacy daemon, and whoever
///   waits for them answers for no event meanwhile. Another thread asks and reports back. The question took 0.3 to 2 ms on
///   average on a hosted Mac, 54 ms at the worst, and four seconds once the daemon had been killed.
/// - **No answer in time is a no.** If it was a yes after all, the taps come back with it.
/// - At a no all taps are removed, in one turn. A tap that is in but switched off was seen not to start the drop; whether
///   switching off ends one that has begun nobody has tried.
/// - While the permission is gone no tap is installed, whoever asks: the main thread may not have heard yet.
///
/// For how long a tap can be on without the right to it: a beat and the time the answer takes, which is a fraction of a beat; if no
/// answer comes, three beats; at the very worst, behind a yes that was slow and old, four. Longer only if the taps' thread
/// itself does not run.
///
/// A value: beats, words and answers in, orders out. `EventTapThread` carries them out. Beside `TapHealth`, which decides about
/// taps that are too slow.
///
/// Times are seconds on any clock that does not go backwards.
public struct TapPermission: Sendable {
  /// From one beat of the clock to the next while a tap is wanted on. The price is a question to the window server at every
  /// beat, a third of a millisecond, for the seconds of a day in which Arbor's keys are down.
  public static let beat = 0.05
  /// How long an answer may take, in beats: at the second beat that finds the question still out, the time is up. So an answer has
  /// 0.05 to 0.1 s; of ten thousand on hosted Macs the slowest took 24 ms, and 81 ms after the privacy daemon had been killed.
  /// Counted and not timed, because a Mac that sleeps and a process that is halted stop whoever asks together with the
  /// beats: by the clock the first beat afterwards would find a question that is hours old, and has had no time at all.
  public static let patience = 2
  /// How old a yes may be for a tap to be switched on by it, counted from when the question was put.
  public static let freshness = 2 * beat
  /// The same while the permission is gone, when macOS is asked whether it is back. Nothing waits for that.
  public static let beatWhileGone = 1.0

  /// What macOS said when asked whether this process may have an active event tap.
  public enum Answer: Equatable, Sendable {
    case yes
    /// The flag, which turns when the loss is announced (the distributed notification `com.apple.accessibility.api`).
    case flagSaysNo
    /// The flag says yes, and a tap made for the purpose was refused: a loss that nobody announced (a reset of the
    /// privacy database). The flag was seen to stay as it was for seconds, and once beyond the half minute a probe waited.
    case tapRefused
    /// Nothing, in time.
    case nothing

    /// For the log. Scripts that run on Macs read these words.
    public var words: String {
      switch self {
      case .yes: "it is there"
      case .flagSaysNo: "AXIsProcessTrusted says no"
      case .tapRefused: "AXIsProcessTrusted says yes, but macOS refused a tap"
      case .nothing: "macOS has not said in time whether Arbor still may"
      }
    }
  }

  /// What the taps' thread is to do.
  public enum Order: Equatable, Sendable {
    case nothing
    /// Have another thread ask macOS, and hand the answer to `heard`.
    case ask
    /// macOS has just said yes. Switch on whatever waits for that, and see whether macOS left a tap off without a word
    /// (`TapHealth.foundOff`).
    case lookAfter
    /// Remove every tap, and then tell their owners. After `.nothing` nobody has said no: it is no second opinion for
    /// whoever else wants to know about the permission.
    case removeAll(Answer)
    /// The permission is back: tell the owners, who install what the settings ask for. For how long the taps were away,
    /// and what had sent them: after `.nothing` it was a false alarm, which may have cost a pinch or a rectangle in progress.
    case comeBack(after: Double, wentFor: Answer)
  }

  /// When the question was put that has not been answered yet. There is never more than one.
  private var askedAt: Double?
  /// How many beats have found it out.
  private var beatsWaited = 0
  /// When the question was put to which macOS last said yes.
  private var lastYes = -Double.infinity
  /// Since when the permission has been gone, and by which answer: from the no until the next yes. There are no taps meanwhile.
  private var loss: (since: Double, answer: Answer)?
  public var isGone: Bool { loss != nil }

  public init() {}

  /// While this is false no tap may be installed, whoever asks.
  public var mayInstall: Bool { !isGone }

  /// From one beat to the next as things are, or nil: with no tap wanted on, and none to bring back, nobody is asked anything
  /// and the clock stops. (Taps that the settings no longer ask for count as taps to bring back until the permission returns.)
  public func clock(tapsAreWantedOn: Bool) -> Double? { isGone ? Self.beatWhileGone : tapsAreWantedOn ? Self.beat : nil }

  /// The clock beats.
  public mutating func beat(at now: Double, tapsAreWantedOn: Bool) -> Order {
    guard askedAt != nil else {
      guard isGone || tapsAreWantedOn else { return .nothing }
      return ask(at: now)
    }
    beatsWaited += 1
    guard !isGone, beatsWaited >= Self.patience else { return .nothing }
    return lose(.nothing, at: now)
  }

  private mutating func ask(at now: Double) -> Order {
    askedAt = now
    beatsWaited = 0
    return .ask
  }

  /// Somebody wants a tap switched on: a key of Arbor's went down, a press is to be followed. It goes on at `.lookAfter`, which
  /// is now if macOS has said yes a moment ago, and otherwise when it has answered.
  public mutating func wantsOn(at now: Double) -> Order {
    guard !isGone else { return .nothing }
    if now - lastYes <= Self.freshness { return .lookAfter }
    // The answer that is on its way will do.
    return askedAt == nil ? ask(at: now) : .nothing
  }

  /// macOS has let Arbor install a tap, which is the very thing the question tries.
  public mutating func installed(at now: Double) { lastYes = now }

  /// macOS tells a callback that it switched a tap off. It does that to a tap that is too slow, and, late, to one that has
  /// outlived the right to it. Nothing is believed of the word: the question is put now and does not wait for the clock.
  public mutating func toldOff(at now: Double) -> Order {
    !isGone && askedAt == nil ? ask(at: now) : .nothing
  }

  /// The answer to the question that was out.
  public mutating func heard(_ answer: Answer, at now: Double, tapsAreIn: Bool) -> Order {
    guard let askedAt else { return .nothing }
    self.askedAt = nil
    if answer == .yes { lastYes = askedAt }
    guard let loss else {
      guard answer != .yes else { return .lookAfter }
      // The last tap went while the question was out: there is nothing to remove, and nothing to bring back.
      return tapsAreIn ? lose(answer, at: now) : .nothing
    }
    guard answer == .yes else {
      // If the taps went for want of an answer, this is the answer: the alarm was not false.
      self.loss?.answer = answer
      return .nothing
    }
    self.loss = nil
    return .comeBack(after: now - loss.since, wentFor: loss.answer)
  }

  private mutating func lose(_ answer: Answer, at now: Double) -> Order {
    loss = (now, answer)
    return .removeAll(answer)
  }
}
