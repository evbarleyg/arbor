import Foundation

/// What to make of macOS's word that an app has become the active one.
///
/// Switching apps posts no "focused window changed": the app's focused window is the one it was. That word is the only
/// sign of ⌘Tab or a click in the Dock, and the app's focused window is reported on the strength of it. Only of the app
/// in front, because apps in the background change their focused windows too.
///
/// macOS says on another channel which app is in front, and that one can be behind: by 5 ms, for most switches, on
/// macOS 26.6 (collab/evidence/traces/app-switch-unreported.jsonl). Taken for an app in the background, the app was
/// dropped, nothing else ever told of the switch, and its window had the keyboard out of view. So it is asked about
/// again until macOS names it. Nothing is reported before that: whoever hears of a focused window asks who has the
/// keyboard, and must get this window for an answer.
public enum AppThatCameForward {
  public enum Verdict: Equatable, Sendable {
    /// macOS names it as the app in front: its focused window has the keyboard.
    case report
    /// Not yet. Look again after this many seconds.
    case lookAgain(after: TimeInterval)
    /// Another app has overtaken it without a word.
    case giveUp
  }

  /// Half a second in all, a hundred times what was measured.
  public static let looks = 50

  /// `earlierLooks`: how often it has been asked about before.
  public static func verdict(isNamedInFront: Bool, earlierLooks: Int) -> Verdict {
    if isNamedInFront { return .report }
    return earlierLooks < looks ? .lookAgain(after: 0.01) : .giveUp
  }
}
