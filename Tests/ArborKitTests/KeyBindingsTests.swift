import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The default shortcuts and how settings.json's `bindings` change them.
@Suite struct KeyBindingsTests {
  func settings(_ bindings: [String: String?]) -> Settings {
    var settings = Settings()
    settings.bindings = bindings
    return settings
  }

  /// The command bound to `text` in `bindings`, if any.
  func command(at text: String, in bindings: [KeyBinding]) throws -> Command? {
    let chord = try KeyChord(text: text)
    return bindings.first { $0.chord == chord }?.command
  }

  @Test func everyDefaultRoundTripsThroughItsText() throws {
    for binding in KeyBindings.defaults {
      #expect(try KeyChord(text: binding.chord.text) == binding.chord, "\(binding.chord.text)")
    }
  }

  @Test func defaultChordsAreDistinct() {
    #expect(Set(KeyBindings.defaults.map(\.chord)).count == KeyBindings.defaults.count)
  }

  @Test func defaultLabelsAreTheOnesTheMenuAlwaysShowed() {
    #expect(KeyBindings.label(for: .showAll) == "⌃⌥Space")
    #expect(KeyBindings.label(for: .zoom(nil)) == "⌃⌥↩")
    #expect(KeyBindings.label(for: .back) == "⌃⌥[")
    #expect(KeyBindings.label(for: .arrange) == "⌃⌥A")
    // ⌃⌥⇧↑ was `neighbor up`. `focus up` does the same when no window lies that way in view (docs/KEYBOARD.md).
    #expect(KeyBindings.label(for: .focus(.direction(.top))) == "⌃⌥⇧↑")
    #expect(KeyBindings.label(for: .dock(nil, .left)) == "⌃⌥⌘←")
    #expect(KeyBindings.label(for: .goToView(9)) == "⌃⌥9")
    #expect(KeyBindings.label(for: .saveView(4)) == "⌃⌥⇧4")
  }

  @Test func withoutBindingsTheDefaultsApplyUnchanged() {
    let (bindings, problems) = KeyBindings.effective(settings: Settings())
    #expect(bindings == KeyBindings.defaults)
    #expect(problems.isEmpty)
  }

  @Test func userBindingsReplaceRemoveAndAdd() throws {
    let (bindings, problems) = KeyBindings.effective(
      settings: settings([
        "opt+ctrl+Space": "arrange",  // replaces show-all (another spelling of the default chord)
        "ctrl+opt+d": nil,  // removes desktop
        "ctrl+opt+cmd+h": "dock left",  // adds a second chord for dock left
        "ctrl+opt+cmd+f12": nil,  // not bound by default: nothing to remove
      ]))
    #expect(problems.isEmpty)
    #expect(bindings.count == KeyBindings.defaults.count)  // one removed, one added
    #expect(try command(at: "ctrl+opt+space", in: bindings) == .arrange)
    #expect(try command(at: "ctrl+opt+d", in: bindings) == nil)
    #expect(try command(at: "ctrl+opt+cmd+h", in: bindings) == .dock(nil, .left))
    #expect(try command(at: "ctrl+opt+cmd+left", in: bindings) == .dock(nil, .left))
    #expect(try command(at: "ctrl+opt+a", in: bindings) == .arrange)
    // Every other default is untouched.
    let changed = try ["ctrl+opt+space", "ctrl+opt+d"].map { try KeyChord(text: $0) }
    #expect(
      bindings.filter { !["ctrl+opt+space", "ctrl+opt+cmd+h"].contains($0.chord.text) }
        == KeyBindings.defaults.filter { !changed.contains($0.chord) })
    // Menu labels prefer the user's own chord for a command.
    #expect(KeyBindings.label(for: .arrange, in: bindings) == "⌃⌥Space")
    #expect(KeyBindings.label(for: .dock(nil, .left), in: bindings) == "⌃⌥⌘H")
    #expect(KeyBindings.label(for: .desktop, in: bindings) == nil)
    #expect(KeyBindings.label(for: .showAll, in: bindings) == nil)
  }

  @Test func unusableEntriesAreReportedAndTheRestStillApply() throws {
    let json = #"""
      {"bindings": {
        "ctrl+": "show-all",
        "hyper+x": "show-all",
        "ctrl+opt+notakey": "show-all",
        "ctrl+opt+q": "teleport",
        "ctrl+opt+space": "dock sideways",
        "ctrl+opt+a": "float-all",
        "opt+ctrl+a": "desktop",
        "ctrl+opt+s": "state",
        "a": "show-all",
        "ctrl+opt+x": 5,
        "ctrl+opt+cmd+h": "dock left"
      }}
      """#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    let skipped = ["ctrl+", "hyper+x", "ctrl+opt+notakey", "ctrl+opt+q", "ctrl+opt+space", "opt+ctrl+a",
      "ctrl+opt+s", "a", "ctrl+opt+x"]
    #expect(problems.count == skipped.count)
    for text in skipped {
      #expect(problems.contains { $0.hasPrefix("\(text): ") }, "\(text) is not reported")
    }
    #expect(problems.contains("hyper+x: unknown modifier `hyper`; use ctrl, opt, cmd or shift"))
    #expect(problems.contains("ctrl+opt+q: unknown command `teleport`; try `help`"))
    // The good entries apply; a bad command for a default chord leaves the default in place.
    #expect(try command(at: "ctrl+opt+cmd+h", in: bindings) == .dock(nil, .left))
    #expect(try command(at: "ctrl+opt+a", in: bindings) == .floatAll)
    #expect(try command(at: "ctrl+opt+space", in: bindings) == .showAll)
    #expect(try command(at: "ctrl+opt+s", in: bindings) == nil)
    #expect(try command(at: "a", in: bindings) == nil)
  }

  @Test func onlyAnEntryThatTookEffectBlocksAnotherSpellingOfItsChord() throws {
    let (bindings, problems) = KeyBindings.effective(
      settings: settings(["ctrl+opt+a": "teleport", "opt+ctrl+a": "desktop", "⌥+⌃+a": "float-all"]))
    // Entries run in sorted order: the bad first spelling is reported for its own reason and does
    // not claim the chord, the second takes effect, and the third repeats the second.
    #expect(try command(at: "ctrl+opt+a", in: bindings) == .desktop)
    #expect(
      problems == [
        "ctrl+opt+a: unknown command `teleport`; try `help`",
        "⌥+⌃+a: the same shortcut as opt+ctrl+a, which is used instead",
      ])
  }

  @Test func anOldSettingsFileOnDiskStillLoadsWithEveryDefault() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let old = #"{"gap": 8, "excludedBundleIDs": ["com.apple.Music"], "hotkeysEnabled": true}"#
    try Data(old.utf8).write(to: url)
    let settings = SettingsFile.load(from: url)
    #expect(settings.gap == 8)
    #expect(settings.bindings.isEmpty)
    #expect(KeyBindings.effective(settings: settings).bindings == KeyBindings.defaults)
  }
}

/// The `bindings` query and settings reloads, through the real controller.
@Suite @MainActor struct BindingsCommandTests {
  func rows(_ text: String) -> [[String]] {
    text.split(separator: "\n").map { line in
      line.components(separatedBy: " → ").map { $0.trimmingCharacters(in: .whitespaces) }
    }
  }

  @Test func bindingsListsTheEffectiveTableSortedByCommand() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+cmd+h": "dock left", "ctrl+opt+d": nil, "hyper+x": "show-all"]
    let h = Harness(settings: settings)
    let result = h.run("bindings")  // a query: it works before start, like `state`
    #expect(result.ok)
    #expect(result.message == "\(KeyBindings.defaults.count) shortcuts, 1 skipped")
    let sections = try #require(result.text).components(separatedBy: "\n\n")
    #expect(sections.count == 2)
    let table = rows(sections[0])
    #expect(table.count == KeyBindings.defaults.count)
    #expect(table.allSatisfy { $0.count == 2 })
    #expect(table.map { $0[1] } == table.map { $0[1] }.sorted())
    #expect(table.contains(["ctrl+opt+cmd+h", "dock left"]))
    #expect(table.contains(["ctrl+opt+cmd+left", "dock left"]))
    #expect(table.contains(["ctrl+opt+space", "show-all"]))
    #expect(table.contains(["ctrl+opt+shift+3", "save-view 3"]))
    #expect(!table.contains { $0[0] == "ctrl+opt+d" })
    #expect(sections[1] == "skipped hyper+x: unknown modifier `hyper`; use ctrl, opt, cmd or shift")
  }

  @Test func bindingsSaysWhenShortcutsAreOff() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let h = Harness(settings: settings)
    h.start()
    let result = h.run("bindings")
    #expect(result.ok)
    #expect(result.message.contains("hotkeysEnabled is false"))
    // The whole table all the same, and then, in what `arborctl` prints, why none of it works.
    #expect(result.text?.split(separator: "\n").filter { $0.contains(" → ") }.count == KeyBindings.defaults.count)
    #expect(result.text?.hasSuffix("\n\nRight now: all off because hotkeysEnabled is false.") == true)
  }

  @Test func reloadSettingsHandsTheNewBindingsToTheApp() throws {
    let h = Harness()
    h.start()
    var applied: [Settings] = []
    h.controller.onSettingsApplied = { applied.append($0) }
    var edited = Settings()
    edited.bindings = ["ctrl+opt+cmd+h": "dock left", "ctrl+opt+space": nil]
    h.controller.loadSettings = { edited }
    #expect(h.run("reload-settings").ok)
    #expect(applied == [edited])
    let table = rows(try #require(h.run("bindings").text))
    #expect(table.contains(["ctrl+opt+cmd+h", "dock left"]))
    #expect(!table.contains { $0[0] == "ctrl+opt+space" })
  }

  @Test func excludeAndIncludeAlsoReportAppliedSettings() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    var applied = 0
    h.controller.onSettingsApplied = { _ in applied += 1 }
    let bundle = h.controller.windows[a]!.bundleID!
    h.run("exclude \(bundle)")
    h.run("include \(bundle)")
    #expect(applied == 2)
  }

  @Test func aReboundShortcutRunsItsNewCommand() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+space": "arrange"]
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    // What the hot key center does when the chord is pressed: perform the command bound to it.
    let chord = try KeyChord(text: "ctrl+opt+space")
    let pressed = KeyBindings.effective(settings: h.controller.settings).bindings.first { $0.chord == chord }
    let binding = try #require(pressed)
    #expect(h.controller.perform(binding.command).ok)
    #expect(Set(h.workspace.tree.allWindows) == [a, b])
  }
}
