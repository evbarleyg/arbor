/// Whether a panel that takes the keyboard has gone out of its person's sight.
///
/// Such a panel goes when the keyboard goes elsewhere, and hears of that in many ways. Mission Control is the one that tells it
/// nothing: no key status is lost, no app comes forward, the Space is not left, and ⌃↑ reaches no monitor. macOS hides the panel for
/// as long and brings it back afterwards, with the keyboard, over whatever its person went on to. What AppKit does say is that the
/// panel no longer shows.
///
/// It says the same of a panel that is only just being put on screen, so "does not show" counts once the panel has shown.
public struct PanelSight: Equatable, Sendable {
  private var hasShown = false

  public init() {}

  /// Takes in what AppKit says of the panel now. Returns whether the panel was in sight and no longer is: it is to go.
  public mutating func isLost(shows: Bool) -> Bool {
    if shows { hasShown = true }
    return hasShown && !shows
  }
}
