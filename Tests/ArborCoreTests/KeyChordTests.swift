import ArborCore
import Foundation
import Testing

@Suite struct KeyChordGlyphTests {
  @Test func theWayMenusWriteShortcutsIsReadToo() throws {
    #expect(try KeyChord(text: "⌃⌥Space") == KeyChord([.control, .option], .space))
    #expect(try KeyChord(text: "⌃⌥x") == KeyChord([.control, .option], .x))
    #expect(try KeyChord(text: "⌥⌃⇧1") == KeyChord([.control, .option, .shift], .digit1))
    #expect(try KeyChord(text: "⌃⌥⌘←") == KeyChord([.control, .option, .command], .left))
    #expect(try KeyChord(text: "⌃⌥↩") == KeyChord([.control, .option], .returnKey))
    #expect(try KeyChord(text: "⌃⌥⎋") == KeyChord([.control, .option], .escape))
    #expect(try KeyChord(text: "⌃⌥,") == KeyChord([.control, .option], .comma))
    // Mixed with the spelt-out form, in any order.
    #expect(try KeyChord(text: "⌃⌥+x") == KeyChord([.control, .option], .x))
    #expect(try KeyChord(text: "⌃ + ⌥shift + x") == KeyChord([.control, .option, .shift], .x))
    #expect(try KeyChord(text: "x+⌃⌥") == KeyChord([.control, .option], .x))
    #expect(try KeyChord(text: "ctrl+opt+esc") == KeyChord([.control, .option], .escape))
  }

  @Test func everyKeyRoundTripsThroughItsLabelWithEveryModifier() throws {
    for key in KeyChord.Key.allCases {
      for raw in UInt32(0)..<16 {
        let chord = KeyChord(KeyChord.Modifiers(rawValue: raw), key)
        #expect(try KeyChord(text: chord.label) == chord, "\(chord.label)")
        #expect(try KeyChord(text: chord.text) == chord, "\(chord.text)")
      }
    }
  }

  @Test func glyphsAloneAreStillNotAShortcut() {
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥") }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥+") }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥xy") }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "⌃⌥x+y") }
    #expect(throws: KeyChord.ParseError.self) { try KeyChord(text: "x⌃⌥") }
  }

  @Test func onAUSKeyboardAPressedKeyIsTheKeyOfThatCode() {
    for key in KeyChord.Key.allCases {
      for modifiers: KeyChord.Modifiers in [[], [.control, .option], [.control, .option, .shift], [.command]] {
        #expect(KeyChord(code: key.code, modifiers: modifiers, layout: .us) == KeyChord(modifiers, key), "\(key)")
      }
    }
    #expect(KeyChord(code: 10, modifiers: [.control, .option], layout: .us) == nil)  // only European keyboards have it
    #expect(KeyChord(code: 83, modifiers: [.control, .option], layout: .us) == nil)  // 1 on the numeric keypad
    #expect(KeyChord(code: 0xFFFF, modifiers: [.control, .option], layout: .us) == nil)
  }

  @Test func shortcutsOutsideArborsOwnGroundComeWithACaution() throws {
    #expect(try KeyChord(text: "ctrl+opt+x").caution == nil)
    #expect(try KeyChord(text: "ctrl+opt+shift+x").caution == nil)
    #expect(try KeyChord(text: "ctrl+opt+cmd+left").caution == nil)
    #expect(try KeyChord(text: "cmd+q").caution == "no app gets ⌘Q while Arbor runs")
    #expect(try KeyChord(text: "f5").caution == "no app gets F5 while Arbor runs")
    #expect(try KeyChord(text: "ctrl+a").caution != nil)
    #expect(try KeyChord(text: "ctrl+opt+cmd+8").caution?.hasPrefix("macOS uses ⌃⌥⌘8 itself") == true)
    // One line for each row of "Never bind by default" in docs/KEYBOARD.md.
    #expect(try KeyChord(text: "ctrl+opt+cmd+f").caution?.hasPrefix("Xcode uses ⌃⌥⌘ with letters") == true)
    #expect(try KeyChord(text: "ctrl+opt+cmd+return").caution?.hasPrefix("Xcode") == true)
    #expect(try KeyChord(text: "ctrl+opt+shift+cmd+a").caution?.contains("hyper key") == true)
    #expect(try KeyChord(text: "ctrl+opt+shift+cmd+left").caution?.contains("hyper key") == true)
    #expect(try KeyChord(text: "ctrl+opt+q").caution == "⌃⌥Q is one slipped finger from ⌘Q")
    #expect(try KeyChord(text: "ctrl+opt+w").caution == "⌃⌥W is one slipped finger from ⌘W")
    #expect(try KeyChord(text: "ctrl+opt+delete").caution == "⌃⌥⌫ reads as “delete”")
    #expect(try KeyChord(text: "ctrl+opt+h").caution?.hasPrefix("Figma") == true)
    #expect(try KeyChord(text: "ctrl+opt+v").caution?.hasPrefix("Figma") == true)
    for key in ["o", "i", "l"] { #expect(try KeyChord(text: "ctrl+opt+\(key)").caution?.hasPrefix("JetBrains") == true) }
    // ⌃⌥J and ⌃⌥K are left unbound for economy's sake; nothing is wrong with them.
    #expect(try KeyChord(text: "ctrl+opt+j").caution == nil)
  }
}

@Suite struct KeyChordTests {
  static let modifierSets: [KeyChord.Modifiers] = [
    [], [.control], [.option], [.command], [.shift], [.control, .option], [.control, .option, .command],
    [.control, .option, .shift], [.command, .shift], [.control, .option, .shift, .command],
  ]

  @Test(arguments: KeyChord.Key.allCases) func everyKeyRoundTripsThroughItsText(key: KeyChord.Key) throws {
    for modifiers in Self.modifierSets {
      let chord = KeyChord(modifiers, key)
      #expect(try KeyChord(text: chord.text) == chord, "\(chord.text)")
    }
  }

  @Test func aliasesCaseSpacesAndOrderDoNotMatter() throws {
    let expected = KeyChord([.control, .option], .space)
    let spellings = [
      "ctrl+opt+space", "opt+ctrl+Space", "Control+Option+SPACE", "⌃+⌥+space", "alt+ctrl+space",
      " ctrl + opt + space ", "ctrl+ctrl+opt+space", "space+ctrl+opt",
    ]
    for text in spellings {
      #expect(try KeyChord(text: text) == expected, "\(text)")
    }
    #expect(try KeyChord(text: "cmd+shift+enter") == KeyChord([.command, .shift], .returnKey))
    #expect(try KeyChord(text: "Command+⇧+⌘+F5") == KeyChord([.command, .shift], .f5))
  }

  @Test func theTextFormIsCanonical() throws {
    #expect(KeyChord([.command, .shift, .option, .control], .digit1).text == "ctrl+opt+shift+cmd+1")
    #expect(KeyChord([.control, .option, .command], .h).text == "ctrl+opt+cmd+h")
    #expect(KeyChord([], .f12).text == "f12")
    #expect(try KeyChord(text: "Opt+Ctrl+Enter").text == "ctrl+opt+return")
    #expect(try KeyChord(text: #"cmd+\"#).text == #"cmd+\"#)
  }

  @Test func labelsUseMenuGlyphs() {
    #expect(KeyChord([.control, .option], .space).label == "⌃⌥Space")
    #expect(KeyChord([.command, .control, .option], .left).label == "⌃⌥⌘←")
    #expect(KeyChord([.control, .option, .shift], .digit3).label == "⌃⌥⇧3")
    #expect(KeyChord([.control, .option], .returnKey).label == "⌃⌥↩")
    #expect(KeyChord([.option], .a).label == "⌥A")
    #expect(KeyChord([.command], .f5).label == "⌘F5")
    #expect(KeyChord([.control], .leftBracket).label == "⌃[")
  }

  @Test func everyKeyNameInTheSpecIsAccepted() throws {
    let names =
      "abcdefghijklmnopqrstuvwxyz0123456789".map(String.init)
      + ["space", "return", "enter", "left", "right", "up", "down", "tab", "escape", "delete"]
      + ["[", "]", "-", "=", ",", ".", "/", ";", "'", "`", #"\"#] + (1...12).map { "f\($0)" }
    for name in names {
      let key = try #require(KeyChord.Key(name: name), "\(name)")
      #expect(try KeyChord(text: "ctrl+opt+\(name)").key == key)
      #expect(try KeyChord(text: "ctrl+opt+\(name.uppercased())").key == key)
    }
    // And nothing else: every key Arbor knows is one of those names.
    #expect(Set(names.compactMap(KeyChord.Key.init(name:))) == Set(KeyChord.Key.allCases))
  }

  @Test func keyCodesAreDistinct() {
    #expect(Set(KeyChord.Key.allCases.map(\.code)).count == KeyChord.Key.allCases.count)
  }

  // What the menu, the README and docs/KEYBOARD.md show can be pasted into settings.json.

  @Test(arguments: KeyChord.Key.allCases) func everyKeysLabelIsReadBack(key: KeyChord.Key) throws {
    for modifiers: KeyChord.Modifiers in [[.control, .option], [.control, .option, .shift, .command], [.command]] {
      let chord = KeyChord(modifiers, key)
      #expect(try KeyChord(text: chord.label) == chord, "\(chord.label)")
    }
  }

  /// The one thing a label loses: a menu shows what the key types, not that its position was meant.
  @Test func aLabelDoesNotSayThatAPositionWasMeant() throws {
    let byPosition = try KeyChord(text: "ctrl+opt+us:z")
    #expect(byPosition.label == "⌃⌥Z")
    #expect(try KeyChord(text: byPosition.label) == KeyChord([.control, .option], .z))
    #expect(try KeyChord(text: byPosition.text) == byPosition, "the text form keeps it")
  }

  @Test func glyphsMayBeRunTogetherAndOntoTheKey() throws {
    #expect(try KeyChord(text: "⌃⌥Space") == KeyChord([.control, .option], .space))
    #expect(try KeyChord(text: "⌃⌥⌘←") == KeyChord([.control, .option, .command], .left))
    #expect(try KeyChord(text: "⌃⌥⇧1") == KeyChord([.control, .option, .shift], .digit1))
    #expect(try KeyChord(text: "⌃⌥↩") == KeyChord([.control, .option], .returnKey))
    #expect(try KeyChord(text: "⌃⌥[") == KeyChord([.control, .option], .leftBracket))
    #expect(try KeyChord(text: "⌃⌥⎋") == KeyChord([.control, .option], .escape))
    #expect(try KeyChord(text: "⌥⌃ d") == KeyChord([.control, .option], .d), "any order, any case, spaces")
  }

  @Test func glyphsAndNamesMix() throws {
    #expect(try KeyChord(text: "⌃⌥+space") == KeyChord([.control, .option], .space))
    #expect(try KeyChord(text: "ctrl+⌥d") == KeyChord([.control, .option], .d))
    #expect(try KeyChord(text: "⌃+⌥+⇧+↑") == KeyChord([.control, .option, .shift], .up))
    #expect(try KeyChord(text: "ctrl+opt+←") == KeyChord([.control, .option], .left))
    #expect(try KeyChord(text: "⌃⌥us:z") == KeyChord([.control, .option], .z, positional: true))
  }

  @Test func glyphsDoNotMakeNonsenseReadable() {
    for text in ["⌃⌥", "⌃⌥+", "⌃⌥xy", "⌃⌥d⌘", "⌃⌥←→", "d⌃", "⌃⌥spacebar", "⌃⌥d+f"] {
      #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text) }
    }
  }

  @Test func theReasonsStayTheSame() {
    func reason(_ text: String) -> String {
      do {
        _ = try KeyChord(text: text)
        return "accepted"
      } catch { return "\(error)" }
    }
    #expect(reason("⌃⌥").hasPrefix("no key, only modifiers"))
    #expect(reason("⌃⌥notakey").hasPrefix("unknown key `notakey`"), "the glyphs that were understood are not part of the complaint")
    #expect(reason("⌃⌥d+f").hasPrefix("two keys"))
  }

  @Test func invalidTextIsRejectedWithAReason() {
    let cases: [(text: String, reason: String)] = [
      ("ctrl+", "missing key after the last +"),
      ("hyper+x", "unknown modifier `hyper`"),
      ("ctrl+opt+notakey", "unknown key `notakey`"),
      ("", "empty shortcut"),
      ("   ", "empty shortcut"),
      ("ctrl+opt", "no key"),
      ("ctrl+a+b", "two keys"),
      ("ctrl++a", "missing modifier"),
      ("x+hyper", "unknown modifier `hyper`"),
    ]
    for (text, reason) in cases {
      let error = #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text) }
      #expect(error?.description.contains(reason) == true, "\(text): \(error?.description ?? "no error")")
    }
  }

  @Test func onlyFunctionKeysMayGoWithoutCtrlOptOrCmd() {
    #expect(KeyChord([], .a).interferesWithTyping)
    #expect(KeyChord([.shift], .space).interferesWithTyping)
    #expect(KeyChord([], .escape).interferesWithTyping)
    #expect(!KeyChord([], .f5).interferesWithTyping)
    #expect(!KeyChord([.shift], .f12).interferesWithTyping)
    #expect(!KeyChord([.option], .a).interferesWithTyping)
    #expect(!KeyChord([.command, .shift], .digit1).interferesWithTyping)
  }
}

@Suite struct BindingsSettingsTests {
  func decode(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  @Test func anOldSettingsFileWithoutBindingsStillLoads() throws {
    let settings = try decode(
      #"""
      {"gap": 20, "minimumUsableWidth": 300, "minimumUsableHeight": 200, "screenEdgeBand": 10,
       "windowEdgeFraction": 0.25, "tabsEnabled": true, "excludedBundleIDs": ["com.apple.Music"],
       "hotkeysEnabled": false, "arrangeDesktopWeight": 0.4}
      """#)
    #expect(settings.bindings.isEmpty)
    #expect(settings.unreadableBindings.isEmpty)
    #expect(settings.gap == 20 && settings.excludedBundleIDs == ["com.apple.Music"])
    #expect(!settings.hotkeysEnabled)
    #expect(Settings().bindings.isEmpty)
  }

  @Test func aNullCommandKeepsItsEntry() throws {
    let settings = try decode(#"{"bindings": {"ctrl+opt+h": "dock left", "ctrl+opt+z": null}}"#)
    #expect(settings.bindings.count == 2)
    #expect(settings.bindings["ctrl+opt+h"] == "dock left")
    #expect(settings.bindings["ctrl+opt+z"] == .some(nil))
    #expect(try decode(#"{"bindings": null}"#).bindings.isEmpty)
  }

  @Test func bindingsRoundTripIncludingNulls() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+h": "dock left", "ctrl+opt+z": nil]
    let data = try JSONEncoder().encode(settings)
    #expect(String(decoding: data, as: UTF8.self).contains(#""ctrl+opt+z":null"#))
    #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
  }

  @Test func aValueOfTheWrongTypeIsSetAsideInsteadOfFailingTheFile() throws {
    let settings = try decode(
      #"{"gap": 20, "bindings": {"ctrl+opt+x": 5, "ctrl+opt+y": false, "ctrl+opt+h": "dock left"}}"#)
    #expect(settings.gap == 20)
    #expect(settings.bindings == ["ctrl+opt+h": "dock left"])
    #expect(settings.unreadableBindings == ["ctrl+opt+x", "ctrl+opt+y"])
  }

  @Test func bindingsIsAQueryWithATextForm() throws {
    #expect(try Command.parse("bindings") == .bindings)
    #expect(try Command.parse(Command.bindings.text) == .bindings)
    #expect(try Command.parse("Bindings") == .bindings)
    #expect(Command.bindings.isQuery)
    #expect(throws: Command.ParseError.self) { try Command.parse("bindings now") }
    #expect(Command.helpText.contains("bindings"))
  }
}
