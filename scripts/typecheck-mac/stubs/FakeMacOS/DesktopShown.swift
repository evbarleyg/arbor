// The model of a Mac (FakeMac.swift): macOS shows its desktop. Never shipped.
import Foundation

/// Show Desktop's key, hot corner or gesture, and a click on the wallpaper as macOS 14 and later come, sweep every window to the side of its display.
///
/// SEEN, on a hosted Mac (macOS 26; collab/reports/2026-10-14-the-desktop-is-shown.md, trace `desktop-shown`, the ledger's cases on the sweep): it is a picture. The window server
/// lists the windows at the sides, from one moment to the next, and goes on listing them there with the sizes they had. The apps are not told: Accessibility has every window where it
/// is, and no "moved" is posted. A frame set meanwhile is taken and shows nowhere. A window that opens meanwhile is listed where it is. A press on a strip brings all back 27 ms
/// after the button went down, with the button still down, and macOS keeps the click: nothing is raised, nobody gets the keyboard. The key does what the click on the wallpaper does.
///
/// GUESS, or known to be otherwise:
/// - Which side a window goes to, and where along it: `whereItWaits` takes it straight out, the shorter way. A Mac also takes it along the edge: 687,43 went to 1012,-145; 12,43 to -353,-181;
///   518,53 to 591,-158 (`desktop-shown`). Nobody has worked out the rule, so that drift is NOT played, and a story that depends on a strip's exact place proves nothing about a Mac.
/// - That the key acts at once and brings nobody forward. (With Finder in front already nothing at all was reported; otherwise nobody has looked.)
/// - What a loaded Mac takes to bring the windows back (`stripBringsBackAfter`).
/// - `renumber` shifts the picture with the windows. Nobody has changed the main display during a sweep.
/// - A PRESS ON THE BARE DESKTOP LEAVES THE SWEEP AS IT IS HERE. On a Mac as it comes a click there ends it, some 70 ms after the button comes up; what a rubber band does nobody has
///   looked at. The stories that begin on the bare desktop ask only what Arbor makes of the press while the button is down.
/// - Not played at all: ⌘Tab and an app that comes forward, which end a sweep; so neither a press on a window that opened meanwhile.
extension FakeMac {
  /// The key: aside, or back.
  public func pressShowDesktopKey() {
    guard sweptTo == nil else { return theWindowsComeBack() }
    note("macOS shows its desktop")
    sweptTo = Dictionary(uniqueKeysWithValues: stack.filter { isShowing($0) }.map { ($0.number, whereItWaits($0.bounds)) })
  }

  func theWindowsComeBack() {
    guard sweptTo != nil else { return }
    note("the windows come back")
    sweptTo = nil
  }

  /// The window's frame as the window server lists it.
  public func listedBounds(of window: Window) -> CGRect { sweptTo?[window.number] ?? window.bounds }

  /// Whether what shows at the point is the strip of a window that was swept aside.
  func isStrip(at point: CGPoint) -> Bool { windowShowing(at: point, reach: 4).map { sweptTo?[$0.number] != nil } ?? false }

  /// macOS keeps the click: nothing is raised, nobody gets the keyboard, the button holds nothing.
  func pressOnAStrip(at point: CGPoint) {
    mouse.grab = Grab(kind: .nothing, window: nil, pressedAt: point, frameAtPress: .zero)
    send(after: stripBringsBackAfter, from: .system, "") { [self] in theWindowsComeBack() }
  }

  /// Away from the middle of its display until twelve points of it show: at the left, at the right, at the bottom, or below the menu bar. The twelve points were seen; the side is a
  /// guess, and the drift along the edge is left out (above).
  func whereItWaits(_ frame: CGRect) -> CGRect {
    let display = screen(of: frame)
    let x = (frame.midX - display.frame.midX) / display.frame.width
    let y = (frame.midY - display.frame.midY) / display.frame.height
    var swept = frame
    if abs(x) > abs(y) {
      swept.origin.x = x < 0 ? display.frame.minX - frame.width + 12 : display.frame.maxX - 12
    } else {
      swept.origin.y = y <= 0 ? display.visibleFrame.minY - frame.height + 12 : display.frame.maxY - 12
    }
    return swept
  }
}
