import ArborCore
import ArborTesting
import Testing

@testable import ArborKit

/// Shortcuts on real keyboard layouts (docs/features/F44-shortcuts-follow-the-keyboard-layout.md).
@Suite @MainActor struct LayoutShortcutTests {
  func chord(_ text: String) throws -> KeyChord { try KeyChord(text: text) }

  /// On the whole map, for its signs, digits and ⇧, where layouts differ. `NineKeysTests` has the nine on every keyboard.
  func settings(_ bindings: [String: String?], follow: Bool = true) -> Settings {
    var settings = Settings.withEveryKey
    settings.bindings = bindings
    settings.shortcutsFollowLayout = follow
    return settings
  }

  func binding(_ text: String, in bindings: [KeyBinding]) throws -> KeyBinding? {
    let chord = try KeyChord(text: text)
    return bindings.first { $0.chord == chord }
  }

  // MARK: The layouts

  @Test func qwertz() throws {
    let german = SampleKeyLayouts.german
    #expect(try chord("ctrl+opt+z").code(in: german) == 16)
    #expect(try chord("ctrl+opt+z").label(in: german) == "⌃⌥Z")
    #expect(try chord("ctrl+opt+y").code(in: german) == 6)
    #expect(try chord("ctrl+opt+[").code(in: german) == 33)
    #expect(try chord("ctrl+opt+[").label(in: german) == "⌃⌥Ü")
    #expect(try chord("ctrl+opt+]").code(in: german) == 30)
    #expect(try chord("ctrl+opt+]").label(in: german) == "⌃⌥+")
    #expect(try chord("ctrl+opt+-").code(in: german) == 44, "the key right of the full stop types it")
    #expect(try chord("ctrl+opt+-").label(in: german) == "⌃⌥-")
    #expect(try chord("ctrl+opt+,").code(in: german) == 43)
    #expect(try chord("ctrl+opt+shift+3").label(in: german) == "⌃⌥⇧3")
    #expect(try chord("ctrl+opt+;").label(in: german) == "⌃⌥Ö")
    #expect(try chord("ctrl+opt+=").label(in: german) == "⌃⌥´", "a dead key shows its accent")
  }

  @Test func azerty() throws {
    let french = SampleKeyLayouts.french
    #expect(try chord("ctrl+opt+a").code(in: french) == 12)
    #expect(try chord("ctrl+opt+q").code(in: french) == 0)
    #expect(try chord("ctrl+opt+z").code(in: french) == 13)
    #expect(try chord("ctrl+opt+w").code(in: french) == 6)
    #expect(try chord("ctrl+opt+m").code(in: french) == 41)
    #expect(try chord("ctrl+opt+,").code(in: french) == 46)
    for (digit, key) in zip(1...9, KeyChord.Key.digits) {
      #expect(try chord("ctrl+opt+\(digit)").code(in: french) == key.code, "digits stay in their places")
      #expect(try chord("ctrl+opt+\(digit)").label(in: french) == "⌃⌥\(digit)", "and are printed on those keys")
      #expect(try chord("ctrl+opt+shift+\(digit)").label(in: french) == "⌃⌥⇧\(digit)")
    }
    #expect(try chord("ctrl+opt+0").code(in: french) == 29)
    #expect(try chord("ctrl+opt+-").code(in: french) == 24)
    #expect(try chord("ctrl+opt+=").code(in: french) == 44)
    #expect(try chord("ctrl+opt+[").label(in: french) == "⌃⌥^")
  }

  @Test func dvorakTypesEverythingSoNothingFallsBack() throws {
    let dvorak = SampleKeyLayouts.dvorak
    for key in KeyChord.Key.allCases { #expect(!dvorak.fallsBack(key), "\(key.name)") }
    #expect(try chord("ctrl+opt+a").code(in: dvorak) == 0)
    #expect(try chord("ctrl+opt+z").code(in: dvorak) == 44)
    #expect(try chord("ctrl+opt+f").code(in: dvorak) == 16)
    #expect(try chord("ctrl+opt+d").code(in: dvorak) == 4)
    #expect(try chord("ctrl+opt+[").code(in: dvorak) == 27)
    #expect(try chord("ctrl+opt+]").code(in: dvorak) == 24)
    #expect(try chord("ctrl+opt+[").label(in: dvorak) == "⌃⌥[")
    // hjkl by position, for people who want the home row whatever it types.
    #expect(try chord("ctrl+opt+us:h").code(in: dvorak) == 4)
    #expect(try chord("ctrl+opt+us:h").label(in: dvorak) == "⌃⌥D")
  }

  @Test func theUSLayoutAsMacOSReportsItChangesNothing() {
    for binding in KeyBindings.effective(settings: .withEveryKey, layout: SampleKeyLayouts.us).bindings {
      #expect(binding.keyCode == binding.chord.key.code, "\(binding.chord.text)")
      #expect(binding.label == binding.chord.label, "\(binding.chord.text)")
    }
  }

  /// macOS pairs such a layout with a Latin one before Arbor sees it. If it ever did not: US positions.
  @Test func aLayoutWithoutLatinLettersFallsBackToUSPositions() throws {
    let russian = SampleKeyLayouts.russian
    for key in KeyChord.Key.allCases where key.character?.isLetter == true {
      #expect(russian.code(for: key) == key.code, "\(key.name)")
    }
    #expect(try chord("ctrl+opt+z").label(in: russian) == "⌃⌥Я")
    let (bindings, problems) = KeyBindings.effective(settings: .withEveryKey, layout: russian)
    #expect(problems.isEmpty)
    #expect(bindings.count == KeyBindings.all.count)
  }

  @Test(arguments: ["us", "german", "french", "dvorak", "russian"])
  func everyDefaultShortcutWorksOnEveryLayoutAndNoTwoShareAKey(name: String) throws {
    let layout = try #require(SampleKeyLayouts.byName[name])
    let (bindings, problems) = KeyBindings.effective(settings: .withEveryKey, layout: layout)
    #expect(problems.isEmpty, "\(problems)")
    #expect(bindings.map(\.chord) == KeyBindings.all.map(\.chord))
    #expect(Set(bindings.map { "\($0.keyCode) \($0.modifiers.rawValue)" }).count == bindings.count)
    #expect(Set(bindings.map(\.label)).count == bindings.count, "no two look alike in the menu")
  }

  // MARK: A sign with ⇧

  /// ⌃⌥⇧/ is written ⌃⌥? and pressed as it is typed. In Germany / is ⇧7, and ⌃⌥⇧7 saves view 7.
  @Test func aSignWithShiftIsTheKeyThatTypesWhatShiftMakesOfIt() throws {
    let help = try chord("ctrl+opt+shift+/")
    #expect(help.code(in: SampleKeyLayouts.german) == 27, "? is ⇧ß")
    #expect(help.label(in: SampleKeyLayouts.german) == "⌃⌥⇧ß")
    #expect(help.code(in: SampleKeyLayouts.french) == 46, "? is ⇧,")
    #expect(help.label(in: SampleKeyLayouts.french) == "⌃⌥⇧,")
    #expect(help.code(in: SampleKeyLayouts.dvorak) == 33)
    #expect(help.label(in: SampleKeyLayouts.dvorak) == "⌃⌥⇧/")
    for us in [KeyLayout.us, SampleKeyLayouts.us] {
      #expect(help.code(in: us) == 44)
      #expect(help.label(in: us) == "⌃⌥⇧/")
    }
    // Without ⇧ nothing changes.
    #expect(try chord("ctrl+opt+/").code(in: SampleKeyLayouts.german) == 44)
  }

  @Test func whereTheLayoutDoesNotTypeThatWithShiftTheSignIsResolvedAsEver() throws {
    // < has a key of its own in Germany, so ⌃⌥⇧, stays on the comma.
    #expect(try chord("ctrl+opt+shift+,").code(in: SampleKeyLayouts.german) == 43)
    #expect(try chord("ctrl+opt+shift+,").label(in: SampleKeyLayouts.german) == "⌃⌥⇧,")
    // { is ⌥8: back to the US position, shown as printed there.
    #expect(try chord("ctrl+opt+shift+[").code(in: SampleKeyLayouts.german) == 33)
    #expect(try chord("ctrl+opt+shift+[").label(in: SampleKeyLayouts.german) == "⌃⌥⇧Ü")
    // A position is a position.
    #expect(try chord("ctrl+opt+shift+us:/").code(in: SampleKeyLayouts.german) == 44)
  }

  @Test(arguments: ["us", "german", "french", "dvorak", "russian"])
  func digitsAndLettersWithShiftStayWhereTheyAreWithoutIt(name: String) throws {
    let layout = try #require(SampleKeyLayouts.byName[name])
    for key in KeyChord.Key.allCases where key.character?.isLetter == true || key.character?.isNumber == true {
      #expect(layout.code(for: key, withShift: true) == layout.code(for: key), "\(key.name)")
      #expect(layout.label(for: key, withShift: true) == layout.label(for: key), "\(key.name)")
    }
  }

  @Test(arguments: ["german", "french", "dvorak", "russian"])
  func theHelpShortcutCollidesWithNoDefault(name: String) throws {
    let layout = try #require(SampleKeyLayouts.byName[name])
    // ⌃⌥⇧/ is a default since F43.
    #expect(KeyBindings.all.contains { $0.command == .showShortcuts })
    let (bindings, problems) = KeyBindings.effective(settings: .withEveryKey, layout: layout)
    #expect(problems.isEmpty, "\(problems)")
    #expect(bindings.count == KeyBindings.all.count)
  }

  // MARK: Keys named by what they type

  @Test func anyCharacterTheLayoutTypesAloneCanNameItsKey() throws {
    let german = SampleKeyLayouts.german
    let chord = try KeyChord(text: "ctrl+opt+ü", layout: german)
    #expect(chord == KeyChord([.control, .option], .leftBracket, positional: true))
    #expect(chord.code(in: german) == 33 && chord.label(in: german) == "⌃⌥Ü")
    #expect(try KeyChord(text: "Opt + Ctrl + Ü", layout: german) == chord)
    #expect(try KeyChord(text: "ctrl+opt+ß", layout: german).code(in: german) == 27)
    #expect(try KeyChord(text: "ctrl+opt+#", layout: german).code(in: german) == 42)
    #expect(try KeyChord(text: "ctrl+opt+é", layout: SampleKeyLayouts.french).code(in: SampleKeyLayouts.french) == 19)
    #expect(try KeyChord(text: "ctrl+opt+я", layout: SampleKeyLayouts.russian).code(in: SampleKeyLayouts.russian) == 6)
    // What `init(text:)` reads is read the same.
    #expect(try KeyChord(text: "ctrl+opt+z", layout: german) == KeyChord(text: "ctrl+opt+z"))
    #expect(try KeyChord(text: "ctrl+opt+space", layout: german) == KeyChord(text: "ctrl+opt+space"))
  }

  @Test func whatTheLayoutDoesNotTypeAloneIsStillAnUnknownKey() {
    let cases: [(text: String, layout: KeyLayout, reason: String)] = [
      ("ctrl+opt+ü", .us, "unknown key `ü`"),
      ("ctrl+opt+ü", SampleKeyLayouts.french, "unknown key `ü`"),
      ("ctrl+opt+?", SampleKeyLayouts.german, "unknown key `?`"),
      ("ctrl+opt+üü", SampleKeyLayouts.german, "unknown key `üü`"),
      ("ctrl+ü+ö", SampleKeyLayouts.german, "unknown modifier `ü`"),
      ("ctrl+opt+^", SampleKeyLayouts.german, "on a key that only some keyboards have"),
      ("ctrl+opt", SampleKeyLayouts.german, "no key"),
    ]
    for (text, layout, reason) in cases {
      let error = #expect(throws: KeyChord.ParseError.self, "\(text)") { try KeyChord(text: text, layout: layout) }
      #expect(error?.description.contains(reason) == true, "\(text): \(error?.description ?? "no error")")
    }
  }

  @Test func aGermanCanBindAndFreeTheirOwnKeys() throws {
    let german = SampleKeyLayouts.german
    let bound = KeyBindings.effective(settings: settings(["ctrl+opt+ö": "desktop"]), layout: german)
    #expect(bound.problems.isEmpty)
    #expect(bound.bindings.first?.keyCode == 41 && bound.bindings.first?.label == "⌃⌥Ö")

    // Back is shown as ⌃⌥Ü, so that is what people write to change it or to be rid of it.
    let replaced = KeyBindings.effective(settings: settings(["ctrl+opt+ü": "arrange"]), layout: german)
    #expect(replaced.problems.isEmpty, "\(replaced.problems)")
    #expect(!replaced.bindings.contains { $0.command == .back })
    #expect(replaced.bindings.first { $0.keyCode == 33 }?.command == .arrange)
    #expect(replaced.bindings.count == KeyBindings.all.count)
    let freed = KeyBindings.effective(settings: settings(["ctrl+opt+ü": nil]), layout: german)
    #expect(freed.problems.isEmpty)
    #expect(!freed.bindings.contains { $0.keyCode == 33 })
    #expect(freed.bindings.count == KeyBindings.all.count - 1)

    // On another layout the entry cannot be read, is reported, and Back is back.
    let elsewhere = KeyBindings.effective(settings: settings(["ctrl+opt+ü": nil]), layout: SampleKeyLayouts.us)
    #expect(elsewhere.problems.count == 1 && elsewhere.problems[0].hasPrefix("ctrl+opt+ü: unknown key `ü`"))
    #expect(elsewhere.bindings.count == KeyBindings.all.count)
  }

  // MARK: Two shortcuts on one key

  @Test func aCollisionAfterFallingBackIsReportedAndTheOthersStillWork() throws {
    // On a German keyboard / is ⇧7, so it falls back to its US position, where - is printed and typed.
    let (bindings, problems) = KeyBindings.effective(
      settings: settings(["ctrl+opt+-": "out", "ctrl+opt+/": "in"]), layout: SampleKeyLayouts.german)
    #expect(
      problems == [
        "ctrl+opt+/: the same key as ctrl+opt+- on the German keyboard layout (⌃⌥-), which is used instead"
      ])
    #expect(try binding("ctrl+opt+-", in: bindings)?.command == .stepOut)
    #expect(try binding("ctrl+opt+/", in: bindings) == nil)
    #expect(bindings.count == KeyBindings.all.count + 1)
    // The same settings on a US keyboard are fine.
    #expect(KeyBindings.effective(settings: settings(["ctrl+opt+-": "out", "ctrl+opt+/": "in"])).problems.isEmpty)
  }

  @Test func theUsersShortcutBeatsADefaultThatLandsOnTheSameKey() throws {
    // ' is typed by the key that has 4 on it on a French keyboard.
    let (bindings, problems) = KeyBindings.effective(
      settings: settings(["ctrl+opt+'": "arrange"]), layout: SampleKeyLayouts.french)
    #expect(try binding("ctrl+opt+'", in: bindings)?.keyCode == 21)
    #expect(try binding("ctrl+opt+4", in: bindings) == nil)
    #expect(problems == ["ctrl+opt+4: the same key as ctrl+opt+' on the French keyboard layout (⌃⌥'), which is used instead"])
  }

  @Test func aPositionAndTheCharacterTypedThereAreOneKey() throws {
    let both = settings(["ctrl+opt+us:y": "arrange", "ctrl+opt+z": "desktop"])
    let german = KeyBindings.effective(settings: both, layout: SampleKeyLayouts.german)
    #expect(german.problems.count == 1)
    #expect(german.problems[0].hasPrefix("ctrl+opt+z: the same key as ctrl+opt+us:y on the German keyboard layout (⌃⌥Z)"))
    #expect(KeyBindings.effective(settings: both).problems.isEmpty, "two keys on a US keyboard")
    let same = KeyBindings.effective(settings: settings(["ctrl+opt+us:k": "arrange", "ctrl+opt+k": "desktop"]))
    #expect(same.problems.count == 1, "one key on a US keyboard")
  }

  @Test func differentModifiersOnOneKeyAreDifferentShortcuts() {
    let (_, problems) = KeyBindings.effective(
      settings: settings(["ctrl+opt+-": "out", "ctrl+opt+shift+/": "in"]), layout: SampleKeyLayouts.german)
    #expect(problems.isEmpty)
  }

  // MARK: The controller

  @Test func selectingALayoutMovesTheShortcutsAndTellsTheApp() throws {
    let h = Harness(settings: settings(["ctrl+opt+z": "arrange"]))
    h.start()
    var changes = 0
    h.controller.observe { if $0 == .input { changes += 1 } }
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.keyCode == 6)

    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(changes == 1)
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.keyCode == 16)
    #expect(KeyBindings.label(for: .back, in: h.controller.activeBindings) == "⌃⌥Ü", "what the menu shows")
    #expect(KeyBindings.label(for: .arrange, in: h.controller.activeBindings) == "⌃⌥Z")

    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(changes == 1, "the same layout again")
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.us)
    #expect(changes == 2)
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.keyCode == 6)
  }

  @Test func aLayoutThatLeavesEveryShortcutWhereItIsCostsNothing() {
    let h = Harness(settings: .withEveryKey)
    h.start()
    var changes = 0
    h.controller.observe { if $0 == .input { changes += 1 } }
    // What the app reports at launch on a US keyboard, which is more than `KeyLayout.us` knows.
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.us)
    #expect(changes == 0)
    #expect(h.controller.activeBindings == KeyBindings.all)
  }

  @Test func withTheSettingOffShortcutsArePositionsWithTheirUSLabels() throws {
    let h = Harness(settings: settings(["ctrl+opt+z": "arrange"], follow: false))
    h.start()
    var changes = 0
    h.controller.observe { if $0 == .input { changes += 1 } }
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(changes == 0)
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.keyCode == 6)
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.label == "⌃⌥Z")
    #expect(KeyBindings.label(for: .back, in: h.controller.activeBindings) == "⌃⌥[")
    #expect(h.run("bindings").text?.contains("their places on a US keyboard, because shortcutsFollowLayout is false") == true)

    // Switched on, it applies at once: `apply(settings:)` already makes the app register again.
    h.controller.apply(settings: settings(["ctrl+opt+z": "arrange"]))
    #expect(try binding("ctrl+opt+z", in: h.controller.activeBindings)?.keyCode == 16)
  }

  @Test func bindingsShowsWhatIsPrintedOnTheKeyAndNamesTheLayout() throws {
    let h = Harness(settings: settings(["ctrl+opt+-": "out", "ctrl+opt+/": "in"]))
    let before = try #require(h.run("bindings").text)
    #expect(!before.contains("keyboard layout"), "nothing to say until a layout was reported")
    #expect(before.contains("ctrl+opt+[ "))

    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    let result = h.run("bindings")
    let text = try #require(result.text)
    #expect(text.contains("ctrl+opt+[ (⌃⌥Ü)"))
    #expect(text.contains("ctrl+opt+] (⌃⌥+)"))
    #expect(text.contains("ctrl+opt+d  "), "a letter is itself")
    #expect(text.contains("skipped ctrl+opt+/: the same key as ctrl+opt+- on the German keyboard layout"))
    #expect(text.contains("mean the keys that type them on the German keyboard layout."))
    #expect(result.message.hasSuffix(", 1 skipped"))
  }

  @Test func pausesAndPassThroughAppsKeepTheRightKeyOnAnyLayout() throws {
    var settings = settings(["ctrl+opt+y": "toggle-pause", "ctrl+opt+escape": nil])
    settings.passThroughApps = ["com.example.emacs"]
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    h.start()
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    h.system.userFocus(emacs)
    #expect(h.controller.activeBindings.map(\.keyCode) == [6])
    h.run("pause")
    #expect(h.controller.activeBindings.map(\.keyCode) == [6])
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.us)
    #expect(h.controller.activeBindings.map(\.keyCode) == [16], "also while paused")
  }

  @Test func scenariosCanAskWhereAShortcutIsAndHowItShows() {
    let h = Harness(settings: .withEveryKey)
    h.start()
    func expect(_ line: String) -> String? {
      ScenarioExpectation.check(line.split(separator: " ").map(String.init), harness: h, lastCommandOK: true)
    }
    #expect(expect("shortcut ctrl+opt+[ shows ⌃⌥[") == nil)
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(expect("shortcut ctrl+opt+[ shows ⌃⌥Ü") == nil)
    #expect(expect("shortcut ctrl+opt+[ shows ⌃⌥[") == "ctrl+opt+[ shows as ⌃⌥Ü, not ⌃⌥[")
    #expect(expect("shortcut ctrl+opt+[ key 33") == nil)
    #expect(expect("shortcut ctrl+opt+d key 4") == "ctrl+opt+d is key 2, not 4")
    #expect(expect("shortcut ctrl+opt+q key 12") == "ctrl+opt+q is not a shortcut in effect")
    #expect(expect("shortcut ctrl+opt+d key twelve")?.hasPrefix("cannot read") == true)
    #expect(expect("shortcut ctrl+opt+d smells nice")?.hasPrefix("cannot read") == true)
  }

  // MARK: Against macOS

  #if canImport(Carbon)
    /// The tables above were written by hand. 10 and 50 are left out: which of the two keys is which depends on
    /// the keyboard attached.
    @Test(arguments: [
      ("us", "com.apple.keylayout.US"), ("german", "com.apple.keylayout.German"),
      ("french", "com.apple.keylayout.French"), ("dvorak", "com.apple.keylayout.Dvorak"),
    ])
    func theSampleLayoutsAreWhatMacOSHas(name: String, id: String) throws {
      let sample = try #require(SampleKeyLayouts.byName[name])
      let real = try #require(KeyboardLayoutReader.installed(id: id), "macOS has no layout \(id)")
      for code in SampleKeyLayouts.rows.joined() {
        #expect(real.character(at: code) == sample.character(at: code), "\(name): key \(code)")
        #expect(real.character(at: code, shifted: true) == sample.character(at: code, shifted: true), "\(name): ⇧ key \(code)")
      }
      for key in KeyChord.Key.allCases where key != .grave {
        #expect(real.code(for: key) == sample.code(for: key), "\(name): \(key.name)")
        #expect(real.label(for: key) == sample.label(for: key), "\(name): \(key.name)")
      }
    }

    @Test func macOSHasALayoutSelectedThatTypesLatinLetters() throws {
      let layout = try #require(KeyboardLayoutReader.current())
      for key in KeyChord.Key.allCases where key.character?.isLetter == true {
        #expect(!layout.fallsBack(key), "\(layout.name): \(key.name)")
      }
    }
  #else
    @Test(.disabled("keyboard layouts can be read only on macOS")) func theSampleLayoutsAreWhatMacOSHas() {}
    @Test(.disabled("keyboard layouts can be read only on macOS")) func macOSHasALayoutSelectedThatTypesLatinLetters() {}
  #endif
}
