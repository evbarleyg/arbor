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
    guard CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(truncatingIfNeeded: chord.key.code)) else {
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
