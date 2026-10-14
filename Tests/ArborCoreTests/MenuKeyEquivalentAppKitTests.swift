import ArborCore
import Testing

#if canImport(AppKit)
  import AppKit
#endif

/// KeyChord (ArborCore) cannot import AppKit, so check the key equivalents it gives menus against AppKit's
/// constants here. AppKit exists only on macOS; elsewhere the test is skipped, and the words "only on
/// macOS" in the reason are what make `scripts/parity.py` accept that.
@Suite struct MenuKeyEquivalentAppKitTests {
  #if canImport(AppKit)
    @Test func menuKeyEquivalentsMatchAppKit() {
      let appKit: [KeyChord.Key: Int] = [
        .up: NSUpArrowFunctionKey, .down: NSDownArrowFunctionKey, .left: NSLeftArrowFunctionKey,
        .right: NSRightArrowFunctionKey,
        .f1: NSF1FunctionKey, .f2: NSF2FunctionKey, .f3: NSF3FunctionKey, .f4: NSF4FunctionKey,
        .f5: NSF5FunctionKey, .f6: NSF6FunctionKey, .f7: NSF7FunctionKey, .f8: NSF8FunctionKey,
        .f9: NSF9FunctionKey, .f10: NSF10FunctionKey, .f11: NSF11FunctionKey, .f12: NSF12FunctionKey,
        .delete: NSBackspaceCharacter, .returnKey: NSCarriageReturnCharacter, .tab: NSTabCharacter,
      ]
      for (key, code) in appKit {
        #expect(key.menuKeyEquivalent.unicodeScalars.map(\.value) == [UInt32(code)], "\(key.name)")
      }
    }
  #else
    @Test(.disabled("AppKit exists only on macOS")) func menuKeyEquivalentsMatchAppKit() {}
  #endif
}
