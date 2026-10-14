import ArborCore
import Testing

/// macOS's own shortcuts against Arbor's (SystemShortcuts.swift).
@Suite struct SystemShortcutsTests {
  typealias Shortcut = SystemShortcuts.Shortcut
  let space = KeyChord.Key.space.code

  // MARK: Whether macOS uses a key

  @Test func aTickedShortcutOnTheSameKeyAndModifiersIsAUse() {
    let system = SystemShortcuts(shortcuts: [Shortcut([.control, .option, .command], .digit8)])
    #expect(system.use(ofKeyCode: KeyChord.Key.digit8.code, modifiers: [.control, .option, .command]) != nil)
  }

  @Test func anUntickedOneIsNot() {
    let system = SystemShortcuts(shortcuts: [Shortcut([.control, .option, .command], .digit8, isEnabled: false)])
    #expect(system.use(ofKeyCode: KeyChord.Key.digit8.code, modifiers: [.control, .option, .command]) == nil)
  }

  @Test func anotherKeyOrOtherModifiersAreNot() {
    let system = SystemShortcuts(shortcuts: [Shortcut([.control, .option, .command], .digit8)])
    #expect(system.use(ofKeyCode: KeyChord.Key.digit7.code, modifiers: [.control, .option, .command]) == nil)
    #expect(system.use(ofKeyCode: KeyChord.Key.digit8.code, modifiers: [.control, .option]) == nil)
    #expect(system.use(ofKeyCode: KeyChord.Key.digit8.code, modifiers: [.control, .option, .command, .shift]) == nil)
  }

  @Test func tickedOnceAndUntickedOnceIsAUse() {
    let system = SystemShortcuts(shortcuts: [
      Shortcut([.control], .up, isEnabled: false), Shortcut([.control], .up),
    ])
    #expect(system.use(ofKeyCode: KeyChord.Key.up.code, modifiers: [.control])?.name == "Mission Control")
  }

  @Test func withNoShortcutsNothingIsUsed() {
    #expect(SystemShortcuts(shortcuts: [], inputSources: 3).use(ofKeyCode: space, modifiers: [.control, .option]) == nil)
  }

  // MARK: Carbon's bits

  @Test func carbonsFourModifiersAreRead() {
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x0100).modifiers == [.command])
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x0200).modifiers == [.shift])
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x0800).modifiers == [.option])
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x1000).modifiers == [.control])
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x1B00).modifiers == [.command, .shift, .option, .control])
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0).modifiers == [])
  }

  @Test func writtenAsArborWritesThemTheyComeBackTheSame() {
    for modifiers: KeyChord.Modifiers in [[], [.control], [.control, .option], [.shift, .command], [.option, .command]] {
      #expect(Shortcut(modifiers, .k).modifiers == modifiers)
    }
    #expect(Shortcut([.control], .k).keyCode == KeyChord.Key.k.code)
  }

  /// fn Q opens a Quick Note. It is not Q.
  @Test func aShortcutWithTheGlobeKeyOnALetterIsNobodysBusiness() {
    let globe: UInt32 = 1 << 17
    let quickNote = Shortcut(keyCode: KeyChord.Key.q.code, carbonModifiers: globe)
    #expect(quickNote.modifiers == nil)
    #expect(SystemShortcuts(shortcuts: [quickNote]).use(ofKeyCode: KeyChord.Key.q.code, modifiers: []) == nil)
  }

  @Test func arrowAndFunctionKeysCarryThoseBitsAnyway() {
    let extra: UInt32 = 1 << 16 | 1 << 17
    #expect(Shortcut(keyCode: KeyChord.Key.up.code, carbonModifiers: 0x1000 | extra).modifiers == [.control])
    #expect(Shortcut(keyCode: KeyChord.Key.f11.code, carbonModifiers: extra).modifiers == [])
    let cocoas: UInt32 = 1 << 21 | 1 << 23
    #expect(Shortcut(keyCode: KeyChord.Key.left.code, carbonModifiers: 0x1000 | cocoas).modifiers == [.control], "if Cocoa's come through")
    #expect(Shortcut(keyCode: KeyChord.Key.q.code, carbonModifiers: 1 << 23).modifiers == nil, "on a letter it is the Globe key")
    let system = SystemShortcuts(shortcuts: [Shortcut(keyCode: KeyChord.Key.left.code, carbonModifiers: 0x1000 | 1 << 17)])
    #expect(system.use(ofKeyCode: KeyChord.Key.left.code, modifiers: [.control])?.name == "Move left a space")
  }

  /// “Left & Quarters” and its three siblings: Fn-Control-Option-Shift and an arrow, says Apple's help. Arbor's ⌃⌥⇧← is another key.
  @Test func macOSsTilingOnTheArrowsWithTheGlobeKeyIsNotTakenForArborsShortcuts() {
    let three: UInt32 = 0x1000 | 0x0800 | 0x0200
    for key in [KeyChord.Key.left, .right, .up, .down] {
      for globe: UInt32 in [1 << 17, 1 << 23, 1 << 16 | 1 << 17] {
        let system = SystemShortcuts(shortcuts: [Shortcut(keyCode: key.code, carbonModifiers: three | globe)])
        #expect(system.use(ofKeyCode: key.code, modifiers: [.control, .option, .shift]) == nil, "\(key) \(globe)")
      }
    }
  }

  @Test func withoutThatBitAShortcutOnAnArrowIsWhatItSays() {
    let plain = Shortcut([.control, .option, .shift], .left)
    #expect(SystemShortcuts(shortcuts: [plain]).use(ofKeyCode: KeyChord.Key.left.code, modifiers: [.control, .option, .shift]) == SystemShortcuts.Use(name: nil, list: nil))
    // One of each on the same key: the one that is certain counts.
    let both = SystemShortcuts(shortcuts: [Shortcut(keyCode: KeyChord.Key.left.code, carbonModifiers: 0x1A00 | 1 << 17), plain])
    #expect(both.use(ofKeyCode: KeyChord.Key.left.code, modifiers: [.control, .option, .shift]) != nil)
  }

  /// Every shortcut on an arrow has the bit. The ones macOS puts there by default without the Globe key are known by name.
  @Test func missionControlsOwnAreStillReported() {
    let system = SystemShortcuts(shortcuts: [Shortcut(keyCode: KeyChord.Key.up.code, carbonModifiers: 0x1000 | 1 << 17)])
    #expect(system.use(ofKeyCode: KeyChord.Key.up.code, modifiers: [.control])?.name == "Mission Control")
  }

  @Test func bitsNobodyKnowsAreNotGuessedAt() {
    #expect(Shortcut(keyCode: 0, carbonModifiers: 0x1000 | 1 << 10).modifiers == nil, "Caps Lock")
    #expect(Shortcut(keyCode: KeyChord.Key.up.code, carbonModifiers: 0x1000 | 1 << 20).modifiers == nil)
  }

  // MARK: Input sources

  @Test func nextInputSourceCountsOnlyWithTwoOrMoreToSwitchBetween() {
    var system = SystemShortcuts(shortcuts: [Shortcut([.control, .option], .space), Shortcut([.control], .space)])
    for count in [nil, 0, 1] as [Int?] {
      system.inputSources = count
      #expect(system.use(ofKeyCode: space, modifiers: [.control, .option]) == nil, "\(String(describing: count))")
      #expect(system.use(ofKeyCode: space, modifiers: [.control]) == nil)
    }
    for count in [2, 5] {
      system.inputSources = count
      let use = system.use(ofKeyCode: space, modifiers: [.control, .option])
      #expect(use == SystemShortcuts.Use(name: "Select next source in Input menu", list: "Input Sources"))
      #expect(system.use(ofKeyCode: space, modifiers: [.control])?.name == "Select the previous input source")
    }
  }

  @Test func theOthersDoNotCareHowManyKeyboardsThereAre() {
    let system = SystemShortcuts(shortcuts: [Shortcut([.command], .space)], inputSources: 1)
    #expect(system.use(ofKeyCode: space, modifiers: [.command])?.list == "Spotlight")
  }

  // MARK: Names and sentences

  @Test func aShortcutSomebodyMovedHasNoName() {
    let system = SystemShortcuts(shortcuts: [Shortcut([.control, .option], .z)], inputSources: 1)
    #expect(system.use(ofKeyCode: KeyChord.Key.z.code, modifiers: [.control, .option]) == SystemShortcuts.Use(name: nil, list: nil))
  }

  @Test func theSentenceNamesBothAndSaysWhereToChangeEither() {
    let use = SystemShortcuts.Use(name: "Select next source in Input menu", list: "Input Sources")
    #expect(
      use.sentence(label: "⌃⌥Space", command: "show-all")
        == "⌃⌥Space (`show-all`) is macOS's “Select next source in Input menu” as well, so one of the two does nothing. Change "
        + "either: System Settings → Keyboard → Keyboard Shortcuts → Input Sources, or `bindings` in settings.json")
  }

  @Test func withoutANameItStillSaysWhereToLook() {
    #expect(
      SystemShortcuts.Use(name: nil, list: nil).sentence(label: "⌃⌥Z", command: "undo")
        == "⌃⌥Z (`undo`) is a shortcut of macOS's as well, so one of the two does nothing. Change either: "
        + "System Settings → Keyboard → Keyboard Shortcuts, or `bindings` in settings.json")
  }
}
