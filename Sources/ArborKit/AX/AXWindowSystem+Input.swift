import AppKit
import ArborCore
import CoreGraphics

extension AXWindowSystem {
  /// macOS keeps these figures for the login session and gives them to any app that asks: no permission,
  /// no event tap, nothing about which keys. "Combined" counts events posted by other software too (a remote
  /// desktop, a macro tool), which are as much the user's doing as a real key.
  public func inputActivity() -> InputActivity {
    func idle(_ type: CGEventType) -> Double {
      CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: type)
    }
    let pointer: [CGEventType] = [
      .mouseMoved, .leftMouseDown, .leftMouseDragged, .rightMouseDown, .rightMouseDragged, .otherMouseDown,
      .scrollWheel,
    ]
    return InputActivity(
      pointerIdle: pointer.map(idle).min() ?? .infinity, keyboardIdle: idle(.keyUp),
      keyPresses: CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown))
  }

  public func isHolding(_ chord: KeyChord) -> Bool {
    // Down by either table of keys. The session's has what other software posts as well. But to an Arbor that
    // was granted its permission while it waited for it, it said of a key that was down that it was up, with
    // another app having the keyboard, and a hold was a tap; the keyboard's own was right (hosted Macs,
    // 2026-10-15, a script's grant: 233 looks of 233 in one process). Both say up once the key is up.
    let code = CGKeyCode(truncatingIfNeeded: chord.key.code)
    guard CGEventSource.keyState(.hidSystemState, key: code) || CGEventSource.keyState(.combinedSessionState, key: code) else {
      return false
    }
    let (modifiers, flags) = (chord.modifiers, NSEvent.modifierFlags)
    if modifiers.contains(.command), !flags.contains(.command) { return false }
    if modifiers.contains(.shift), !flags.contains(.shift) { return false }
    if modifiers.contains(.option), !flags.contains(.option) { return false }
    if modifiers.contains(.control), !flags.contains(.control) { return false }
    return true
  }
}
