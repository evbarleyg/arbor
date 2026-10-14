// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// Event taps, which run off the main actor, locks and Carbon.
import AppKit
import Carbon.HIToolbox
import os

struct ProbeTapState {
  var held: CGEvent?
}

enum ProbeInput {
  static let unchecked = OSAllocatedUnfairLock(uncheckedState: ProbeTapState())
  static let count = OSAllocatedUnfairLock(initialState: 0)
  // State that is not Sendable in a lock that wants it to be.
  static let checked = OSAllocatedUnfairLock(initialState: ProbeTapState())  // wrong

  static func onTheTapThread(_ event: CGEvent) -> Bool {
    let flags = event.flags
    _ = event.getIntegerValueField(.mouseEventClickState)
    _ = NSScreen.main  // wrong
    _ = flags.contains(.maskOption)  // wrong
    return flags.contains(.maskAlternate)
  }

  // Carbon's constants arrive as Int.
  static func hotKeys() {
    _ = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    _ = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: kEventHotKeyPressed)  // wrong
    let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
    _ = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    _ = TISGetInputSourceProperty(source, kTISPropertyKeyLayout)  // wrong
  }
}
