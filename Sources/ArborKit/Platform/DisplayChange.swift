import ArborCore
import CoreGraphics

/// When to tell the controller that the displays have changed.
///
/// macOS says "the screen parameters changed" far more often than anything changes that matters to Arbor: at every
/// minimize and restore (the Dock grows and shrinks), and several times in a row when a display comes or goes. On wake,
/// and when a laptop is docked, displays vanish and are back within a second or two; acting at once would evacuate
/// every window and bring it back, racing macOS's own restoration.
public enum DisplayChange {
  /// Long enough for a display that only blinked to be back.
  public static let comingAndGoing = 1.5
  /// The Dock or the menu bar changed size: nothing is at stake but a few points.
  public static let visibleFrameOnly = 0.3

  /// Seconds to wait before reporting `current`, given what was `reported` last, or nil if there is nothing to report.
  /// Whoever waits asks again afterwards: by then the displays may be as they were.
  public static func settleTime(from reported: [DisplaySnapshot], to current: [DisplaySnapshot]) -> Double? {
    func byID(_ displays: [DisplaySnapshot]) -> [DisplayID: DisplaySnapshot] {
      Dictionary(displays.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    let before = byID(reported)
    let after = byID(current)
    guard before != after else { return nil }
    let sameDisplays =
      before.keys == after.keys
      && before.allSatisfy { after[$0.key]?.frame == $0.value.frame && after[$0.key]?.isMain == $0.value.isMain }
    return sameDisplays ? visibleFrameOnly : comingAndGoing
  }
}
