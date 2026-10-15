import ArborCore
import Foundation

/// The keyboard handed across displays, and whose display the next key means.
///
/// The window with the keyboard goes, macOS picks one that Arbor keeps out of view, and nobody in view on that display can be the heir. So
/// a window on another display gets the keyboard (`aWindowInViewGetsTheKeyboard`, Controller+Focus.swift). That is a stopgap, and not the
/// person going there: their eyes are on the display of the going for a beat.
///
/// **The next key of Arbor's, once.** If it names no display and no window it still means that display (`focusedDisplayID`); one for the
/// focused window acts on the heir, where the heir is. That key ends it, whatever it did, so that nobody who uses only the keyboard is
/// locked out of a display. If it has brought into view, on the display of the going, a window that can be an heir, the want is over
/// and the stopgap with it: that window gets the keyboard, macOS's own pick first. From then on every key follows the keyboard.
///
/// It ends sooner when the person goes elsewhere or is seen to be there: the keyboard in another window, another app in front, the pointer
/// pressed, the heir going, the displays changing. A key typed into the heir is not reported: it is found in the count of presses, and from
/// then on nothing holds. And after thirty seconds: whoever comes back later sees the heir lit on
/// the other display and means that one. Not at what macOS says about the hand-over itself: the heir named again, its app coming
/// forward, or whom and whose app it named before while the keyboard is still on its way.
extension Controller {
  struct HandedAcross {
    /// The heir.
    var to: WindowID
    /// The display of the going.
    var from: DisplayID
    /// The window macOS picked.
    var insteadOf: WindowID
    /// The running count of key presses at the hand-over.
    var keyPresses: UInt32
    /// Who could be an heir and was in view on the display of the going before the key acted: nobody at the hand-over, or they would
    /// have the keyboard. A window that has opened there since is not what the key brings.
    var inViewBefore: Set<WindowID> = []
  }

  /// Longer than a beat: somebody who looks at an emptied display and wonders where everything went is whom this is for.
  public static let timeTheEyesStay: TimeInterval = 30

  /// Not among the looks at the keyboard (`cancelFocusLooks`): nothing is due to move when it runs out, and nothing is said.
  private static let handedAcrossLapses = "handed-across"

  /// Call after the asking, whose echoes come at once or later and are about the heir.
  func theKeyboardWasHandedAcross(from display: DisplayID, insteadOf pick: WindowID) {
    guard let heir = keyboardFocus() else { return }
    keyboardHandOver.handedAcross = HandedAcross(
      to: heir, from: display, insteadOf: pick, keyPresses: system.inputActivity().keyPresses)
    scheduler.schedule(Self.handedAcrossLapses, after: Self.timeTheEyesStay) { [weak self] in self?.keyboardHandOver.handedAcross = nil }
  }

  /// The press that runs a shortcut is one; more than that is typing, as for who leads (`InputLead`). What runs without a press (a
  /// script, a URL) has none to allow for.
  var handOverAcrossThatHolds: HandedAcross? {
    guard let across = keyboardHandOver.handedAcross, keyboardFocus() == across.to,
      system.inputActivity().keyPresses &- across.keyPresses <= (following.source == .shortcut ? 1 : 0)
    else { return nil }
    return across
  }

  /// For whoever is about to act as the next key.
  var handOverBeforeTheNextKey: HandedAcross? {
    guard var across = handOverAcrossThatHolds else { return nil }
    across.inViewBefore = Set(windowsInView(on: across.from, asHeirs: true).keys)
    return across
  }

  func theHandOverAcrossIsOver() {
    // A peek keeps what held when its key went down until the key is let go of, and a press of the pointer meanwhile ends that too.
    peeking?.handedAcross = nil
    guard keyboardHandOver.handedAcross != nil else { return }
    keyboardHandOver.handedAcross = nil
    scheduler.cancel(Self.handedAcrossLapses)
  }

  /// `held`: what `handOverBeforeTheNextKey` answered before the key acted.
  func theNextKeyHasActed(after held: HandedAcross?) {
    theHandOverAcrossIsOver()
    // Not if the key itself has sent the keyboard somewhere (`go`), or has stopped Arbor.
    guard isRunning, let held, keyboardFocus() == held.to else { return }
    let brought = Set(windowsInView(on: held.from, asHeirs: true).keys).subtracting(held.inViewBefore)
    if brought.contains(held.insteadOf), sendTheKeyboard(to: held.insteadOf) { return }
    if !brought.isEmpty { giveTheKeyboardToTheView(on: held.from, asAnHeir: true, notTo: [held.insteadOf]) }
  }
}
