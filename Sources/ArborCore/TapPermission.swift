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
/// - The clock beats on the taps' own thread while taps are in. Not on the main thread, which waits for apps.
/// - The question is not put on that thread either: it goes to the window server and the privacy daemon, and whoever
///   waits for them answers for no event meanwhile. Another thread asks and reports back. Nobody has seen the question
///   wait, but posting an event was seen to wait two seconds for a daemon that had been killed.
/// - **No answer in time is a no.** If it was a yes after all, the taps come back with it.
/// - At a no all taps are removed, in one turn. A tap that is in but switched off was seen not to start the drop; whether
///   switching off ends one that has begun nobody has tried.
/// - While the permission is gone no tap is installed, whoever asks: the main thread may not have heard yet.
///
/// For how long a tap can be in without the permission: a beat and the time the answer takes; if no answer comes, two and a half
/// beats (`beat(at:tapsAreIn:)`). Longer only if the taps' thread itself does not run.
///
/// A value: beats, words and answers in, orders out. `EventTapThread` carries them out. Beside `TapHealth`, which decides about
/// taps that are too slow.
///
/// Times are seconds on any clock that does not go backwards.
public struct TapPermission: Sendable {
  /// From one beat of the clock to the next while taps are in. The price is a question to the window server at every beat.
  public static let beat = 0.15
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
    /// All is well. See whether macOS left a tap off without a word (`TapHealth.foundOff`).
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
  /// Since when the permission has been gone, and by which answer: from the no until the next yes. There are no taps meanwhile.
  private var loss: (since: Double, answer: Answer)?
  public var isGone: Bool { loss != nil }

  public init() {}

  /// While this is false no tap may be installed, whoever asks.
  public var mayInstall: Bool { !isGone }

  /// From one beat to the next as things are, or nil: without taps, and with none to bring back, nobody is asked anything and
  /// the clock stops. (Taps that the settings no longer ask for count as taps to bring back until the permission returns.)
  public func clock(tapsAreIn: Bool) -> Double? { isGone ? Self.beatWhileGone : tapsAreIn ? Self.beat : nil }

  /// The clock beats.
  public mutating func beat(at now: Double, tapsAreIn: Bool) -> Order {
    guard let askedAt else {
      guard isGone || tapsAreIn else { return .nothing }
      self.askedAt = now
      return .ask
    }
    // An answer has from half a beat to a beat and a half. Half a beat of slack, because a beat can be late, after a handler that
    // took its time, and the next one on time; and a question put between two beats, at macOS's word, is not a beat old at the first.
    guard !isGone, tapsAreIn, now - askedAt > Self.beat / 2 else { return .nothing }
    return lose(.nothing, at: now)
  }

  /// macOS tells a callback that it switched a tap off. It does that to a tap that is too slow, and, late, to one that has
  /// outlived the right to it. Nothing is believed of the word: the question is put now and does not wait for the clock.
  public mutating func toldOff(at now: Double) -> Order {
    guard !isGone, askedAt == nil else { return .nothing }
    askedAt = now
    return .ask
  }

  /// The answer to the question that was out.
  public mutating func heard(_ answer: Answer, at now: Double, tapsAreIn: Bool) -> Order {
    guard askedAt != nil else { return .nothing }
    askedAt = nil
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
