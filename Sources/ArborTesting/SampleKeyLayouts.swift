import ArborCore

/// Apple's keyboard layouts as tables, for tests and arbor-sim (`keyboard german`): what each key types
/// alone and with ⇧, row by row as the keys sit on the keyboard. Written by hand; they agree with Unicode CLDR's
/// record of Apple's layouts (release 42, keyboards/osx), and on a Mac `theSampleLayoutsAreWhatMacOSHas`
/// compares them with the layouts macOS ships.
public enum SampleKeyLayouts {
  /// The key codes of the four rows of a keyboard, left to right, starting at 1, Q, A and Z on a US one.
  public static let rows: [[UInt32]] = [
    [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24],
    [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30],
    [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 42],
    [6, 7, 8, 9, 11, 45, 46, 43, 47, 44],
  ]

  /// - Parameters:
  ///   - plain, shifted: one string per row of `rows`, one character per key.
  ///   - extra: the keys that differ between keyboards: 50 (left of 1 on a US keyboard, beside the left ⇧ on a
  ///     European one) and 10 (only on European keyboards, left of 1), each alone and with ⇧.
  static func layout(
    _ name: String, plain: [String], shifted: [String], extra: [UInt32: (plain: String, shifted: String)]
  ) -> KeyLayout {
    func table(_ texts: [String]) -> [UInt32: String] {
      var table: [UInt32: String] = [:]
      for (codes, text) in zip(rows, texts) {
        for (code, character) in zip(codes, text) { table[code] = String(character) }
      }
      return table
    }
    var alone = table(plain)
    var withShift = table(shifted)
    for (code, characters) in extra {
      alone[code] = characters.plain
      withShift[code] = characters.shifted
    }
    return KeyLayout(name: name, plain: alone, shifted: withShift)
  }

  /// com.apple.keylayout.US
  public static let us = layout(
    "U.S.",
    plain: ["1234567890-=", "qwertyuiop[]", "asdfghjkl;'\\", "zxcvbnm,./"],
    shifted: ["!@#$%^&*()_+", "QWERTYUIOP{}", "ASDFGHJKL:\"|", "ZXCVBNM<>?"],
    extra: [50: ("`", "~"), 10: ("§", "±")])

  /// com.apple.keylayout.German: QWERTZ. ´ and ^ are dead keys.
  public static let german = layout(
    "German",
    plain: ["1234567890ß´", "qwertzuiopü+", "asdfghjklöä#", "yxcvbnm,.-"],
    shifted: ["!\"§$%&/()=?`", "QWERTZUIOPÜ*", "ASDFGHJKLÖÄ'", "YXCVBNM;:_"],
    extra: [50: ("<", ">"), 10: ("^", "°")])

  /// com.apple.keylayout.French: AZERTY, with the digits on ⇧. ^ and ` are dead keys.
  public static let french = layout(
    "French",
    plain: ["&é\"'(§è!çà)-", "azertyuiop^$", "qsdfghjklmù`", "wxcvbn,;:="],
    shifted: ["1234567890°_", "AZERTYUIOP¨*", "QSDFGHJKLM%£", "WXCVBN?./+"],
    extra: [50: ("<", ">"), 10: ("@", "#")])

  /// com.apple.keylayout.Dvorak
  public static let dvorak = layout(
    "Dvorak",
    plain: ["1234567890[]", "',.pyfgcrl/=", "aoeuidhtns-\\", ";qjkxbmwvz"],
    shifted: ["!@#$%^&*(){}", "\"<>PYFGCRL?+", "AOEUIDHTNS_|", ":QJKXBMWVZ"],
    extra: [50: ("`", "~"), 10: ("§", "±")])

  /// com.apple.keylayout.Russian: no Latin letter on any key. macOS never hands Arbor such a layout (it
  /// pairs it with a Latin one, as for ⌘-shortcuts); this is for testing what happens if it did.
  public static let russian = layout(
    "Russian",
    plain: ["1234567890-=", "йцукенгшщзхъ", "фывапролджэё", "ячсмитьбю/"],
    shifted: ["!\"№%:,.;()_+", "ЙЦУКЕНГШЩЗХЪ", "ФЫВАПРОЛДЖЭЁ", "ЯЧСМИТЬБЮ?"],
    extra: [50: ("]", "["), 10: (">", "<")])

  /// By the names arbor-sim's `keyboard` takes.
  public static let byName: [String: KeyLayout] = [
    "us": us, "german": german, "french": french, "dvorak": dvorak, "russian": russian,
  ]
}
