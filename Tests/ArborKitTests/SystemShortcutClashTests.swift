import ArborCore
import ArborTesting
import Testing

@testable import ArborKit

/// Shortcuts of Arbor's that macOS uses as well (Controller+SystemShortcuts.swift).
@Suite @MainActor struct SystemShortcutClashTests {
  typealias Shortcut = SystemShortcuts.Shortcut

  /// What a Mac has ticked as it comes, as far as these tests care.
  let asItComes = [
    Shortcut([.control], .space), Shortcut([.control, .option], .space), Shortcut([.command], .space),
    Shortcut([.control], .up), Shortcut([.control, .option, .command], .digit8, isEnabled: false),
  ]

  func makeHarness(_ shortcuts: [Shortcut]? = nil, inputSources: Int? = 2, settings: Settings = Settings()) -> Harness {
    let h = Harness(settings: settings)
    let system = SystemShortcuts(shortcuts: shortcuts ?? asItComes, inputSources: inputSources)
    h.controller.systemShortcuts = { system }
    return h
  }

  func settings(_ bindings: [String: String?]) -> Settings {
    var settings = Settings()
    settings.bindings = bindings
    return settings
  }

  let nextSource =
    "⌃⌥Space (`show-all`) is macOS's “Select next source in Input menu” as well, so one of the two does nothing. Change either: "
    + "System Settings → Keyboard → Keyboard Shortcuts → Input Sources, or `bindings` in settings.json. ⌃⌥0 shows everything too"

  @Test func withTwoKeyboardsShowEverythingIsAlsoNextInputSource() throws {
    let h = makeHarness()
    let clashes = h.controller.systemShortcutClashes
    #expect(clashes.map(\.sentence) == [nextSource])
    #expect(clashes.first?.binding.command == .showAll)
    #expect(clashes.first?.use.list == "Input Sources")
  }

  @Test func withOneKeyboardOrAnUnknownNumberNothingIsSaid() {
    #expect(makeHarness(inputSources: 1).controller.systemShortcutClashes.isEmpty)
    #expect(makeHarness(inputSources: nil).controller.systemShortcutClashes.isEmpty)
  }

  @Test func whereNobodyCanTellNothingIsSaid() {
    let h = Harness()
    #expect(h.controller.systemShortcutClashes.isEmpty)
    h.controller.systemShortcuts = { nil }
    #expect(h.controller.systemShortcutClashes.isEmpty)
    #expect(h.run("bindings").message == "\(h.controller.effectiveBindings.bindings.count) shortcuts")
  }

  @Test func bindingsListsThemAndCountsThemAlsoBeforeArborStarts() throws {
    let h = makeHarness()
    let result = h.run("bindings")
    #expect(result.ok)
    #expect(result.message.hasSuffix(" shortcuts, 1 also macOS's"))
    let lines = try #require(result.text).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    let index = try #require(lines.firstIndex(of: nextSource))
    #expect(lines[index - 1].isEmpty, "set apart from the list")
    #expect(lines.contains { $0.hasPrefix("ctrl+opt+space") && $0.hasSuffix("→ show-all") }, "and still in the list")
  }

  @Test func withNoneBindingsIsAsItWas() {
    let plain = Harness().run("bindings")
    let asked = makeHarness(inputSources: 1).run("bindings")
    #expect(asked.text == plain.text && asked.message == plain.message)
  }

  @Test func withArborsShortcutsOffNothingCollides() {
    var off = Settings()
    off.hotkeysEnabled = false
    #expect(makeHarness(settings: off).controller.systemShortcutClashes.isEmpty)
  }

  @Test func movingOrRemovingArborsShortcutEndsIt() {
    #expect(makeHarness(settings: settings(["ctrl+opt+space": nil])).controller.systemShortcutClashes.isEmpty)
    let moved = makeHarness(settings: settings(["ctrl+opt+space": nil, "ctrl+opt+cmd+space": "show-all"]))
    #expect(moved.controller.systemShortcutClashes.isEmpty)
  }

  @Test func aShortcutFromTheSettingsIsCheckedToo() {
    let h = makeHarness(inputSources: 1, settings: settings(["ctrl+up": "out", "cmd+space": "home"]))
    #expect(h.controller.systemShortcutClashes.map(\.binding.label) == ["⌘Space", "⌃↑"], "sorted by command, as the list is")
    #expect(h.controller.systemShortcutClashes.map(\.use.name) == ["Show Spotlight search", "Mission Control"])
    let before = makeHarness(settings: settings(["ctrl+up": "back"])).controller.systemShortcutClashes
    #expect(before.map(\.binding.command) == [.back, .showAll], "whichever table they come from")
    #expect(before.first?.sentence.contains("shows everything too") == false, "that is for Show Everything")
    let after = makeHarness(settings: settings(["ctrl+up": "zoom"])).controller.systemShortcutClashes
    #expect(after.map(\.binding.command) == [.showAll, .zoom(nil)])
  }

  @Test func macOSIsAskedEachTimeSoAChangeInSystemSettingsShowsWithoutARestart() {
    let h = Harness()
    var ticked = true
    h.controller.systemShortcuts = {
      SystemShortcuts(shortcuts: [Shortcut([.control, .option], .space, isEnabled: ticked)], inputSources: 2)
    }
    #expect(h.controller.systemShortcutClashes.count == 1)
    ticked = false
    #expect(h.controller.systemShortcutClashes.isEmpty)
  }

  @Test func theOtherWayToEverythingIsNotOfferedIfItIsTakenOrGone() {
    let both = makeHarness(asItComes + [Shortcut([.control, .option], .digit0)])
    #expect(both.controller.systemShortcutClashes.count == 2)
    #expect(both.controller.systemShortcutClashes.allSatisfy { !$0.sentence.contains("shows everything too") })
    let gone = makeHarness(settings: settings(["ctrl+opt+0": nil]))
    #expect(gone.controller.systemShortcutClashes.map(\.sentence) == [nextSource.replacing(". ⌃⌥0 shows everything too", with: "")])
  }

  /// macOS says which key, not which letter, and so does what Arbor registers.
  @Test func onAnotherKeyboardLayoutItIsTheKeyThatCounts() {
    let z = settings(["ctrl+opt+z": "back"])
    let whereZIsInGermany = Shortcut(keyCode: 16, carbonModifiers: 0x1800)
    let whereZIsInAmerica = Shortcut(keyCode: 6, carbonModifiers: 0x1800)
    let german = makeHarness([whereZIsInGermany], settings: z)
    #expect(german.controller.systemShortcutClashes.isEmpty, "on a US keyboard that key is Y")
    german.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(german.controller.systemShortcutClashes.map(\.binding.label) == ["⌃⌥Z"])
    #expect(german.controller.systemShortcutClashes.first?.use.name == nil)
    let bracket = makeHarness([Shortcut([.control, .option], .leftBracket)])
    bracket.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(bracket.controller.systemShortcutClashes.first?.sentence.hasPrefix("⌃⌥Ü (`back`) is ") == true, "as the menu shows it")
    let other = makeHarness([whereZIsInAmerica], settings: z)
    #expect(other.controller.systemShortcutClashes.count == 1)
    other.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(other.controller.systemShortcutClashes.isEmpty)
  }

  @Test func aPauseOrAnAppThatKeepsItsKeysDoesNotHideThem() {
    let h = makeHarness()
    h.start()
    h.run("pause")
    #expect(h.controller.systemShortcutClashes.count == 1, "they are about the settings, not about this moment")
  }

  @Test func theLogHearsOfThemOnceAndMacOSIsAskedOnlyWhenTheShortcutsChange() {
    let h = Harness()
    var sources = 2
    var asked = 0
    h.controller.systemShortcuts = {
      asked += 1
      return SystemShortcuts(shortcuts: [Shortcut([.control, .option], .space)], inputSources: sources)
    }
    h.controller.logSystemShortcutClashes()
    #expect(h.controller.loggedSystemShortcutClashes == [nextSource] && asked == 1)
    // Registering again for a pause, or for an app that keeps its keys, does not ask macOS.
    h.start()
    h.run("pause")
    h.controller.logSystemShortcutClashes()
    h.run("resume")
    h.controller.logSystemShortcutClashes()
    #expect(asked == 1)
    // Other shortcuts, or another layout, do.
    sources = 1
    h.controller.apply(settings: settings(["ctrl+opt+z": "back"]))
    h.controller.logSystemShortcutClashes()
    #expect(h.controller.loggedSystemShortcutClashes.isEmpty && asked == 2)
    sources = 2
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    h.controller.logSystemShortcutClashes()
    #expect(h.controller.loggedSystemShortcutClashes == [nextSource] && asked == 3)
    var off = h.controller.settings
    off.hotkeysEnabled = false
    h.controller.apply(settings: off)
    h.controller.logSystemShortcutClashes()
    #expect(h.controller.loggedSystemShortcutClashes.isEmpty && asked == 3, "with the shortcuts off there is nothing to ask")
  }

  // MARK: The real thing

  #if os(macOS)
    /// Reads and changes nothing. Whatever somebody has ticked or moved on their Mac, macOS lists dozens, something sits on
    /// the space bar, nearly all can be read, and there is a keyboard.
    @Test func macOSListsItsOwnShortcuts() throws {
      let system = try #require(SystemShortcutReader.read())
      #expect(system.shortcuts.count > 20)
      #expect(system.shortcuts.contains { $0.keyCode == KeyChord.Key.space.code })
      let unread = system.shortcuts.filter { $0.modifiers == nil }
      #expect(unread.count * 2 < system.shortcuts.count, "\(unread)")
      let sources = try #require(system.inputSources)
      #expect(sources >= 1)
    }
  #else
    @Test(.disabled("macOS's shortcuts can be read only on macOS")) func macOSListsItsOwnShortcuts() {}
  #endif
}
