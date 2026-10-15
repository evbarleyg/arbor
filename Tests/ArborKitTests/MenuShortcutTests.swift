import ArborCore
import ArborTesting
import Testing

/// What Accessibility says of a menu item's shortcut, and what has to be pressed for it. The rows are as hosted Macs gave them (macOS 26, 2026-10-15;
/// collab/evidence/menu-keys), or made in their likeness where no app has the very keys.
@Suite struct MenuShortcutTests {
  typealias Press = MenuShortcut.Press
  let us = SampleKeyLayouts.us

  @Test func aLetterComesInCapitalsAndMeansTheKeyAlone() {
    // ⌘Q, ⇧⌘Q and ⌃⌥⌘S.
    #expect(MenuShortcut(modifiers: 0, character: "Q").press(on: us) == Press(keyCode: 12, modifiers: [.command]))
    #expect(MenuShortcut(modifiers: 1, character: "Q").press(on: us) == Press(keyCode: 12, modifiers: [.command, .shift]))
    #expect(MenuShortcut(modifiers: 6, character: "S").press(on: us) == Press(keyCode: 1, modifiers: [.command, .control, .option]))
  }

  @Test func eachBitIsItsOwnKeyAndEightMeansWithoutCommand() {
    #expect(MenuShortcut(modifiers: 8, character: "A").press(on: us) == Press(keyCode: 0, modifiers: []))
    #expect(MenuShortcut(modifiers: 9, character: "A").press(on: us) == Press(keyCode: 0, modifiers: [.shift]))
    #expect(MenuShortcut(modifiers: 10, character: "A").press(on: us) == Press(keyCode: 0, modifiers: [.option]))
    #expect(MenuShortcut(modifiers: 12, character: "A").press(on: us) == Press(keyCode: 0, modifiers: [.control]))
    #expect(MenuShortcut(modifiers: 14, character: "A").press(on: us) == Press(keyCode: 0, modifiers: [.control, .option]))
  }

  /// An editor's ⌃⌥; and ⌃⌥: come as 14 with `;` and 14 with `:`. One app writes ⇧⌘= where others write ⌘+. The same fingers.
  @Test func whatShiftMakesOfAKeyComesEitherWay() {
    #expect(MenuShortcut(modifiers: 14, character: ";").press(on: us) == Press(keyCode: 41, modifiers: [.control, .option]))
    #expect(MenuShortcut(modifiers: 14, character: ":").press(on: us) == Press(keyCode: 41, modifiers: [.control, .option, .shift]))
    #expect(MenuShortcut(modifiers: 0, character: "?").press(on: us) == Press(keyCode: 44, modifiers: [.command, .shift]))
    #expect(MenuShortcut(modifiers: 1, character: "=").press(on: us) == MenuShortcut(modifiers: 0, character: "+").press(on: us))
    // ⌘* is ⇧⌘8.
    for (sign, digit) in zip("!@#$%^&*()", "1234567890") {
      #expect(
        MenuShortcut(modifiers: 14, character: String(sign)).press(on: us) == MenuShortcut(modifiers: 15, character: String(digit)).press(on: us),
        "\(sign)")
    }
  }

  /// Arrows come with a character from the private-use area beside the key code, and macOS's own Move & Resize with the code alone.
  @Test func aVirtualKeyIsTheKeyWhateverTheCharacterSays() {
    #expect(
      MenuShortcut(modifiers: 6, character: "\u{F702}", virtualKey: 123).press(on: us)
        == Press(keyCode: 123, modifiers: [.command, .control, .option]))
    #expect(MenuShortcut(modifiers: 12, virtualKey: 36).press(on: us) == Press(keyCode: 36, modifiers: [.control]))
    #expect(MenuShortcut(modifiers: 2, character: "\u{238B}", virtualKey: 53).press(on: us) == Press(keyCode: 53, modifiers: [.command, .option]))
  }

  /// 16 is fn, which no header mentions. fn⌃← is not ⌃←: a reading that went by the header took the one for the other.
  @Test func whatNeedsTheGlobeKeyIsAnotherPress() {
    let reading = MenuBarReading(
      app: "com.example.editor", shortcuts: [MenuShortcut(modifiers: 28, virtualKey: 123), MenuShortcut(modifiers: 12, virtualKey: 124)])
    #expect(reading.presses(on: us) == [Press(keyCode: 124, modifiers: [.control])])
    #expect(reading.presses(on: us, withFn: true) == [Press(keyCode: 123, modifiers: [.control])])
  }

  @Test func whatCannotBeToldIsLeftOut() {
    #expect(MenuShortcut(modifiers: 0).press(on: us) == nil)
    #expect(MenuShortcut(modifiers: 0, character: "").press(on: us) == nil)
    #expect(MenuShortcut(modifiers: 0, character: "AB").press(on: us) == nil)
    #expect(MenuShortcut(modifiers: 0, character: "ü").press(on: us) == nil, "this keyboard does not type it")
    #expect(MenuShortcut(modifiers: 0, virtualKey: -3).press(on: us) == nil)
    // The tool writes -1 for an item that does not say; and a sixth bit would be as new as the fifth was.
    #expect(MenuShortcut(modifiers: -1, character: "A").press(on: us) == nil)
    #expect(MenuShortcut(modifiers: 32, character: "A").press(on: us) == nil)
  }

  /// A menu's letter means the key that types it, as a shortcut of Arbor's does (F44).
  @Test func theLetterFollowsTheKeyboardLayout() {
    let german = KeyLayout(name: "German", plain: [6: "y", 16: "z", 41: "ö", 43: ","], shifted: [43: ";"])
    #expect(MenuShortcut(modifiers: 14, character: "Z").press(on: german) == Press(keyCode: 16, modifiers: [.control, .option]))
    #expect(MenuShortcut(modifiers: 14, character: ";").press(on: german) == Press(keyCode: 43, modifiers: [.control, .option, .shift]))
    #expect(MenuShortcut(modifiers: 14, character: ":").press(on: german) == nil, "nothing is guessed from a US keyboard on another")
  }
}
