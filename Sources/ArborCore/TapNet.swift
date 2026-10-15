/// The net under the clock of `TapPermission`: says when that clock stands though taps are in.
///
/// If the taps' thread stands altogether, its taps do not answer either, and macOS switches them off by itself after about a
/// second. The case that nothing mends is a thread that goes on answering for its taps while its clock no longer beats: then
/// nobody asks whether Arbor still may, and taps that have outlived the right to them cost the Mac its input at every
/// event they ask for. So somebody outside that thread looks now and then whether the clock has beaten since the last look.
///
/// It counts looks and compares no times. A Mac that sleeps, and a process that is halted and goes on, stop the looks together
/// with the beats, so neither looks like a clock that stands.
public struct TapNet: Equatable, Sendable {
  /// From one look to the next, in seconds.
  public static let pause = 0.4
  /// At this many looks in a row without a beat the clock stands: after 0.8 to 1.2 s. The clock beats several times between two
  /// looks, and a thread that is kept from it for as long as that has let its taps time out already.
  public static let limit = 3

  private var looks = 0

  public init() {}

  /// The clock has beaten, or has just been started.
  public mutating func beat() { looks = 0 }

  /// Somebody looks. True: the clock stands, and the taps have to go, by whoever looks.
  public mutating func look(tapsAreIn: Bool) -> Bool {
    guard tapsAreIn else {
      looks = 0
      return false
    }
    looks += 1
    guard looks >= Self.limit else { return false }
    looks = 0
    return true
  }
}
