import ArborCore
import ArborTesting
import Testing

/// What a menu shows can be typed into settings.json, on the keyboard layout that shows it.
@Suite struct ChordLabelTests {
  static let layouts = ["us", "german", "french", "dvorak", "russian"]

  @Test func whatAGermanMenuShowsForAPositionIsReadBack() throws {
    let german = try #require(SampleKeyLayouts.byName["german"])
    let chord = try KeyChord(text: "ctrl+opt+us:[")
    #expect(chord.label(in: german) == "⌃⌥Ü")
    for text in ["⌃⌥Ü", "⌃⌥ü", "⌃⌥ Ü", "ctrl+⌥ü", "⌃+⌥+ü", "ctrl+opt+ü"] {
      #expect(try KeyChord(text: text, layout: german) == chord, "\(text)")
    }
  }

  @Test func theKeyThatTypesAPlus() throws {
    // It also joins the parts.
    let german = try #require(SampleKeyLayouts.byName["german"])
    let chord = try KeyChord(text: "ctrl+opt+us:]")
    #expect(chord.label(in: german) == "⌃⌥+")
    for text in ["⌃⌥+", "ctrl+opt++", "⌃+⌥++", "⌃⌥ +"] {
      #expect(try KeyChord(text: text, layout: german) == chord, "\(text)")
    }
    for text in ["+", "++", "⌃⌥+++", "ctrl+opt+f+", "ctrl++opt"] {
      #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text, layout: german) }
    }
    // Where ⇧ is needed for it, a text that ends in + still lacks its key.
    let us = try #require(SampleKeyLayouts.byName["us"])
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥+", layout: us) }
  }

  @Test func whereNoKeyTypesItItIsStillRefused() throws {
    let us = try #require(SampleKeyLayouts.byName["us"])
    let german = try #require(SampleKeyLayouts.byName["german"])
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥Ü", layout: us) }
    for text in ["⌃⌥", "⌃⌥üü", "⌃⌥ü⌘", "ü⌃", "⌃⌥ü+ä", "⌃⌥ü+f"] {
      #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text, layout: german) }
    }
  }

  /// The limit. ⇧ with a sign means what ⇧ makes of that sign on a US keyboard (`KeyLayout.code(for:)`), so on a layout
  /// where the signs are elsewhere the label names another key than it is printed on.
  @Test func withShiftASignsLabelNeedNotComeBack() throws {
    let german = try #require(SampleKeyLayouts.byName["german"])
    let chord = try KeyChord(text: "ctrl+opt+shift+;")
    #expect(chord.label(in: german) == "⌃⌥⇧.")
    #expect(try KeyChord(text: "⌃⌥⇧.", layout: german).code(in: german) != chord.code(in: german))
  }

  @Test(arguments: layouts) func everyLabelTypedBackMeansTheSameKey(name: String) throws {
    let layout = try #require(SampleKeyLayouts.byName[name])
    for key in KeyChord.Key.allCases {
      let isSign = key.character.map { !$0.isLetter && !$0.isNumber } ?? false
      for positional in [false, true] {
        for modifiers: KeyChord.Modifiers in [[.control, .option], [.control, .option, .command], [.control, .option, .shift]] {
          // See `withShiftASignsLabelNeedNotComeBack`.
          if isSign, modifiers.contains(.shift) { continue }
          let chord = KeyChord(modifiers, key, positional: positional)
          let label = chord.label(in: layout)
          guard let back = try? KeyChord(text: label, layout: layout) else {
            Issue.record("\(chord.text) shows \(label), which cannot be read (key code \(chord.code(in: layout)))")
            continue
          }
          #expect(back.modifiers == modifiers, "\(chord.text) shows \(label)")
          #expect(back.code(in: layout) == chord.code(in: layout), "\(chord.text) shows \(label), read as \(back.text)")
        }
      }
    }
  }
}
