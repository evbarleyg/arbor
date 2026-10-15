extension Transition {
  /// The least a correction takes. Shorter, and it is a jump.
  public static let shortestCorrection = 0.15

  /// How long a motion takes that corrects one under way: what is left of that one.
  ///
  /// The stand-ins set off before the real windows are asked, for where the windows are expected to end. Apps have the
  /// last word, and it comes when the last of them has answered: half a second after the key with nine windows on a
  /// slow Mac. Starting the clock again there made one act take the apps' time and the whole motion on top, 1.3 s
  /// where 0.5 s was meant. One act is one motion, and it ends when it was going to, or as soon after as a correction
  /// can be seen to be a move.
  public static func timeLeft(of duration: Double, after elapsed: Double) -> Double {
    guard duration > 0, elapsed.isFinite else { return max(duration, 0) }
    // A clock that was set back meanwhile makes nothing longer.
    return min(duration, max(duration - max(elapsed, 0), shortestCorrection))
  }
}
