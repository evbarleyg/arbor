import ArborCore
import Foundation
import Testing

/// `KeyLayout`'s rules on small tables, and the `us:` spelling of a shortcut
/// (docs/features/F44-shortcuts-follow-the-keyboard-layout.md). Whole layouts: ArborKitTests/LayoutShortcutTests.
@Suite struct KeyLayoutTests {
  typealias Key = KeyChord.Key

  @Test(arguments: Key.allCases) func onAUSKeyboardEveryKeyIsWhereItsNameSays(key: Key) {
    #expect(KeyLayout.us.code(for: key) == key.code)
    #expect(KeyLayout.us.code(for: key, positional: true) == key.code)
    #expect(KeyLayout.us.label(for: key) == key.label)
    #expect(KeyLayout.us.label(for: key, positional: true) == key.label)
    #expect(!KeyLayout.us.fallsBack(key))
  }

  @Test func aCharacterMeansTheKeyThatTypesIt() {
    let layout = KeyLayout(name: "swapped", plain: [6: "y", 16: "z"])
    #expect(layout.code(for: .z) == 16)
    #expect(layout.code(for: .y) == 6)
    #expect(layout.label(for: .z) == "Z")
    #expect(!layout.fallsBack(.z))
  }

  @Test func keysThatArePositionsEverywhereNeverMove() {
    // A table that claims otherwise: macOS reports control characters for these keys, and some layout might not.
    let layout = KeyLayout(name: "odd", plain: [0: " ", 1: "\r", 2: "\t", 3: "\u{1B}", 49: "a", 36: "b"])
    for key in Key.allCases where key.character == nil {
      #expect(layout.code(for: key) == key.code, "\(key.name)")
      #expect(layout.label(for: key) == key.label, "\(key.name)")
      #expect(!layout.fallsBack(key))
    }
    #expect(layout.character(at: 0) == nil, "a key that types nothing visible types nothing")
  }

  @Test func aCharacterTheLayoutCannotTypeAloneFallsBackToItsUSPositionAndShowsWhatIsPrintedThere() {
    let layout = KeyLayout(name: "umlauts", plain: [33: "ü", 30: "+", 27: "ß"], shifted: [33: "Ü", 30: "*", 27: "?"])
    #expect(layout.fallsBack(.leftBracket))
    #expect(layout.code(for: .leftBracket) == 33)
    #expect(layout.label(for: .leftBracket) == "Ü")
    #expect(layout.label(for: .rightBracket) == "+")
    #expect(layout.label(for: .minus) == "ß", "no capital that is one letter")
  }

  @Test func aCharacterTypedWithShiftAtItsUSPositionIsPrintedThereToo() {
    let layout = KeyLayout(name: "digits on shift", plain: [18: "&", 19: "é"], shifted: [18: "1", 19: "2"])
    #expect(layout.fallsBack(.digit1))
    #expect(layout.code(for: .digit1) == 18)
    #expect(layout.label(for: .digit1) == "1")
    #expect(layout.label(for: .digit2) == "2")
  }

  @Test func aKeyTheTableSaysNothingAboutKeepsItsUSLabel() {
    let layout = KeyLayout(name: "empty", plain: [:])
    for key in Key.allCases {
      #expect(layout.code(for: key) == key.code)
      #expect(layout.label(for: key) == key.label)
    }
  }

  @Test func theNumericKeypadIsNeverMeant() {
    // As macOS reports a US keyboard: the keypad types digits and signs as well, some on lower key codes.
    var plain: [UInt32: String] = [:]
    for key in Key.allCases { if let character = key.character { plain[key.code] = String(character) } }
    let keypad: [UInt32: String] = [
      65: ".", 67: "*", 69: "+", 75: "/", 78: "-", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5", 88: "6",
      89: "7", 91: "8", 92: "9",
    ]
    let layout = KeyLayout(name: "with keypad", plain: plain.merging(keypad) { main, _ in main })
    for key in Key.allCases { #expect(layout.code(for: key) == key.code, "\(key.name)") }
    // Even when the main block does not type the digit at all.
    let french = KeyLayout(name: "digits on shift", plain: keypad.merging([18: "&"]) { $1 }, shifted: [18: "1"])
    #expect(french.code(for: .digit1) == 18)
  }

  @Test func ofTwoKeysThatTypeOneCharacterTheUSOneWinsAndOtherwiseTheLowerCode() {
    #expect(KeyLayout(name: "twice", plain: [10: "`", 50: "`"]).code(for: .grave) == 50)
    #expect(KeyLayout(name: "twice", plain: [10: "z", 30: "z"]).code(for: .z) == 10)
  }

  @Test func capitalsLongTextAndInvisibleCharactersInATableAreHarmless() {
    let layout = KeyLayout(name: "rough", plain: [6: "Y", 16: "zz", 7: "", 8: "\u{F704}", 9: "\u{200B}", 11: "\u{10}"])
    #expect(layout.code(for: .y) == 6)
    #expect(layout.code(for: .z) == 6, "a key that types two characters types no single one: back to the US position")
    for code: UInt32 in [16, 7, 8, 9, 11] { #expect(layout.character(at: code) == nil, "\(code)") }
  }

  @Test func layoutsCompareByWhatTheyTypeAndTheirName() {
    #expect(KeyLayout(name: "a", plain: [6: "y"]) == KeyLayout(name: "a", plain: [6: "Y", 82: "0"]))
    #expect(KeyLayout(name: "a", plain: [6: "y"]) != KeyLayout(name: "a", plain: [6: "z"]))
    #expect(KeyLayout(name: "a", plain: [6: "y"]) != KeyLayout(name: "b", plain: [6: "y"]))
  }

  // MARK: us:

  @Test func aPositionCanBeAskedForOutright() throws {
    let chord = try KeyChord(text: "ctrl+opt+us:z")
    #expect(chord == KeyChord([.control, .option], .z, positional: true))
    #expect(chord != KeyChord([.control, .option], .z), "another shortcut than ctrl+opt+z")
    #expect(chord.text == "ctrl+opt+us:z")
    let swapped = KeyLayout(name: "swapped", plain: [6: "y", 16: "z"])
    #expect(chord.code(in: swapped) == 6)
    #expect(chord.label(in: swapped) == "⌃⌥Y", "what is printed on that key")
    #expect(chord.code(in: .us) == 6)
    #expect(chord.label == "⌃⌥Z")
    #expect(try KeyChord(text: "ctrl+opt+z").code(in: swapped) == 16)
  }

  @Test(arguments: Key.allCases) func everyKeyRoundTripsWithThePrefix(key: Key) throws {
    let chord = KeyChord([.control, .option], key, positional: true)
    #expect(try KeyChord(text: chord.text) == chord, "\(chord.text)")
    #expect(try KeyChord(text: "Opt + Ctrl + US:\(key.name.uppercased())") == chord)
    #expect(chord.isPositional == (key.character != nil))
  }

  @Test func forKeysThatArePositionsAnywayThePrefixChangesNothing() throws {
    #expect(try KeyChord(text: "ctrl+opt+us:space") == KeyChord(text: "ctrl+opt+space"))
    #expect(try KeyChord(text: "ctrl+opt+us:left").text == "ctrl+opt+left")
    #expect(try KeyChord(text: "us:f5").text == "f5")
  }

  @Test func mistakesWithThePrefixAreExplained() {
    let cases: [(text: String, reason: String)] = [
      ("ctrl+opt+us:", "unknown key `us:`"),
      ("ctrl+opt+us:zz", "unknown key `us:zz`"),
      ("ctrl+opt+de:z", "unknown key `de:z`"),
      ("ctrl+us:ctrl+z", "unknown modifier `us:ctrl`"),
      ("ctrl+us:a+b", "two keys"),
    ]
    for (text, reason) in cases {
      let error = #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text) }
      #expect(error?.description.contains(reason) == true, "\(text): \(error?.description ?? "no error")")
    }
  }

  @Test func theSettingDefaultsToOnAndOldFilesLoad() throws {
    #expect(Settings().shortcutsFollowLayout)
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8)).shortcutsFollowLayout)
    let off = try JSONDecoder().decode(Settings.self, from: Data(#"{"shortcutsFollowLayout": false}"#.utf8))
    #expect(!off.shortcutsFollowLayout)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(off)) == off)
  }
}
