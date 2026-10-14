import ArborCore
import Testing

#if canImport(Carbon)
  import Carbon.HIToolbox
#endif

/// KeyChord (ArborCore) cannot import Carbon, so check its key codes against Carbon's here. Carbon
/// exists only on macOS; elsewhere the test is skipped, and the words "only on macOS" in the reason
/// are what make `scripts/parity.py` accept that.
@Suite struct CarbonKeyCodeTests {
  #if canImport(Carbon)
    @Test func keyCodesMatchCarbon() {
      let carbon: [KeyChord.Key: Int] = [
        .a: kVK_ANSI_A, .b: kVK_ANSI_B, .c: kVK_ANSI_C, .d: kVK_ANSI_D, .e: kVK_ANSI_E, .f: kVK_ANSI_F,
        .g: kVK_ANSI_G, .h: kVK_ANSI_H, .i: kVK_ANSI_I, .j: kVK_ANSI_J, .k: kVK_ANSI_K, .l: kVK_ANSI_L,
        .m: kVK_ANSI_M, .n: kVK_ANSI_N, .o: kVK_ANSI_O, .p: kVK_ANSI_P, .q: kVK_ANSI_Q, .r: kVK_ANSI_R,
        .s: kVK_ANSI_S, .t: kVK_ANSI_T, .u: kVK_ANSI_U, .v: kVK_ANSI_V, .w: kVK_ANSI_W, .x: kVK_ANSI_X,
        .y: kVK_ANSI_Y, .z: kVK_ANSI_Z,
        .digit0: kVK_ANSI_0, .digit1: kVK_ANSI_1, .digit2: kVK_ANSI_2, .digit3: kVK_ANSI_3,
        .digit4: kVK_ANSI_4, .digit5: kVK_ANSI_5, .digit6: kVK_ANSI_6, .digit7: kVK_ANSI_7,
        .digit8: kVK_ANSI_8, .digit9: kVK_ANSI_9,
        .space: kVK_Space, .returnKey: kVK_Return, .tab: kVK_Tab, .escape: kVK_Escape, .delete: kVK_Delete,
        .left: kVK_LeftArrow, .right: kVK_RightArrow, .up: kVK_UpArrow, .down: kVK_DownArrow,
        .leftBracket: kVK_ANSI_LeftBracket, .rightBracket: kVK_ANSI_RightBracket, .minus: kVK_ANSI_Minus,
        .equals: kVK_ANSI_Equal, .comma: kVK_ANSI_Comma, .period: kVK_ANSI_Period, .slash: kVK_ANSI_Slash,
        .semicolon: kVK_ANSI_Semicolon, .quote: kVK_ANSI_Quote, .grave: kVK_ANSI_Grave,
        .backslash: kVK_ANSI_Backslash,
        .f1: kVK_F1, .f2: kVK_F2, .f3: kVK_F3, .f4: kVK_F4, .f5: kVK_F5, .f6: kVK_F6, .f7: kVK_F7,
        .f8: kVK_F8, .f9: kVK_F9, .f10: kVK_F10, .f11: kVK_F11, .f12: kVK_F12,
      ]
      #expect(carbon.count == KeyChord.Key.allCases.count)
      for key in KeyChord.Key.allCases {
        #expect(carbon[key].map(UInt32.init) == key.code, "\(key.name)")
      }
    }
  #else
    @Test(.disabled("Carbon exists only on macOS")) func keyCodesMatchCarbon() {}
  #endif
}
