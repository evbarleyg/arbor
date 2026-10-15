import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1000, height: 800),
  visibleFrame: CGRect(x: 1440, y: 25, width: 1000, height: 775), isMain: false)

/// The shortcuts on screen (docs/features/F43-say-what-happened.md): `show-shortcuts` as the controller runs it.
@Suite @MainActor struct CheatSheetControllerTests {
  private func makeHarness(_ change: (inout Settings) -> Void = { _ in }, displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay])
    -> Harness
  {
    var settings = Settings()
    change(&settings)
    let h = Harness(displays: displays, settings: settings)
    h.system.userFocus(h.system.open(app: "Safari"))
    h.start()
    return h
  }

  private func rows(_ h: Harness) -> [String] {
    h.overlays.cheatSheets.values.flatMap(\.sections).flatMap(\.rows).map { "\($0.keys) \($0.title)" }
  }

  @Test func theDefaultShortcutIsTheOneTheKeyboardMapSetsAside() throws {
    #expect(KeyBindings.label(for: .showShortcuts, in: KeyBindings.all) == "⌃⌥⇧/")
    #expect(KeyBindings.all.first { $0.command == .showShortcuts }?.chord == (try KeyChord(text: "ctrl+opt+shift+/")))
  }

  @Test func itShowsTheShortcutsInEffectOnTheDisplayUnderThePointer() {
    let h = makeHarness({ $0 = .withEveryKey }, displays: [FakeWindowSystem.standardDisplay, side])
    h.system.cursor = CGPoint(x: 2000, y: 300)

    let result = h.run("show-shortcuts", from: .shortcut)

    #expect(result.ok)
    #expect(Array(h.overlays.cheatSheets.keys) == [side.id])
    let model = h.overlays.cheatSheets[side.id]!
    #expect(model.area == side.visibleFrame)
    #expect(model.sections.map(\.title) == ["Look", "Arrange", "Arbor itself", "Pointer and trackpad"])
    #expect(rows(h).contains("⌃⌥Space Show Everything"))
    #expect(rows(h).contains("⌃⌥1–9 Go to a Saved View"))
    #expect(rows(h).contains("⌃⌥⇧/ Keyboard Shortcuts"))
    #expect(rows(h).contains("⌃⌥N Name This Space"))
    #expect(result.text == model.text, "and a terminal gets the same list")
    #expect(h.overlays.messages.isEmpty, "the panel is its own answer")
  }

  @Test func everyDefaultShortcutIsInThePanelUnderAHeadingOfTheHelp() {
    for binding in KeyBindings.all {
      #expect(binding.command.helpOrder < Int.max, "`\(binding.command.verb)` has a default shortcut but is not in the help")
      #expect(
        binding.command.listedTitle != nil,
        "`\(binding.command.text)` has a default shortcut: give it a title in CommandTitle.swift, in the words of docs/MENU.md")
    }
    let model = CheatSheetModel(shortcuts: KeyBindings.all.map { ($0.chord, $0.command) })
    // Four families (two of four arrows, two of nine digits) are a row each.
    #expect(model.sections.flatMap(\.rows).count == KeyBindings.all.count - 26 + 4)
    #expect(model.columns.count >= 2)
  }

  // Acceptance 4.
  @Test func theUsersOwnShortcutsStandInPlaceOfTheDefaults() {
    let h = makeHarness {
      $0 = .withEveryKey
      $0.bindings = ["ctrl+opt+e": "show-all", "ctrl+opt+space": nil, "ctrl+opt+d": nil, "ctrl+opt+cmd+h": "dock left"]
    }
    h.run("show-shortcuts")
    #expect(rows(h).contains("⌃⌥E Show Everything"))
    #expect(!rows(h).contains { $0.hasPrefix("⌃⌥Space ") })
    #expect(!rows(h).contains { $0.hasSuffix("Show the Desktop") }, "a removed shortcut is not listed")
    #expect(rows(h).contains("⌃⌥⌘H Dock Left"))
    #expect(rows(h).contains("⌃⌥⌘ + arrow Dock Focused Window, or Move It"), "the defaults it was added to are still there")
  }

  @Test func thePointersPartFollowsTheSettings() {
    let h = makeHarness {
      $0.pointerGestures = true
      $0.gesturesEnabled = false
      $0.frameRectangleModifier = "ctrl+opt"
    }
    h.run("show-shortcuts")
    #expect(rows(h).contains("Drag to a screen edge Dock"))
    #expect(rows(h).contains("⌃⌥ + drag Frame What Is Inside"))
    #expect(!rows(h).contains { $0.contains("pinch") })
  }

  @Test func theSameKeysPutItAway() {
    let h = makeHarness()
    h.run("show-shortcuts", from: .shortcut)
    #expect(h.run("show-shortcuts", from: .shortcut).ok)
    #expect(h.overlays.cheatSheets.isEmpty)
    h.run("show-shortcuts", from: .shortcut)
    #expect(h.overlays.cheatSheets.count == 1)
  }

  @Test func anyKeyOrClickPutsItAway() {
    let h = makeHarness()
    h.run("show-shortcuts")
    h.overlays.dismissCheatSheet()
    #expect(h.overlays.cheatSheets.isEmpty)
    h.overlays.dismissCheatSheet()  // a second key press finds nothing to do
    h.run("show-shortcuts")
    #expect(h.overlays.cheatSheets.count == 1, "and the next press of the shortcut shows it, rather than hiding what is hidden")
  }

  /// A press on one of Arbor's own panels that never take the keyboard (a gap handle, the Desktop's tile) is not a click in another
  /// app and takes the keyboard from nobody, so the panel hears of it in neither way. The window system reports every press of the left button.
  @Test func aPressOnOneOfArborsOwnPanelsPutsItAwayToo() {
    let h = makeHarness()
    h.run("show-shortcuts", from: .shortcut)
    #expect(h.overlays.cheatSheets.count == 1)

    h.controller.pointerPressed()

    #expect(h.overlays.cheatSheets.isEmpty)
    #expect(h.run("show-shortcuts", from: .shortcut).message.hasPrefix("showing"), "the controller knows that it is down")
  }

  @Test func anyCommandPutsItAwayButAQuestionDoesNot() {
    let h = makeHarness()
    h.run("show-shortcuts")
    for query in ["status", "state", "ascii", "help", "bindings", "rules"] { h.run(query) }
    #expect(h.overlays.cheatSheets.count == 1)
    h.run("dock left", from: .shortcut)
    #expect(h.overlays.cheatSheets.isEmpty)

    h.run("show-shortcuts")
    h.run("out", from: .shortcut)  // even one that fails
    #expect(h.overlays.cheatSheets.isEmpty)
  }

  @Test func thePanelAndTheNameFieldNeverHaveTheKeyboardTogether() {
    let h = makeHarness()
    h.run("arrange")
    h.run("ask-name", from: .shortcut)
    #expect(h.overlays.namePrompt != nil, "or this proves nothing")

    h.run("show-shortcuts", from: .shortcut)
    #expect(h.overlays.namePrompt == nil, "the field is closed before the panel takes the keyboard")
    // On a Mac the field now loses the keyboard. Were it still open it would cancel itself by command, which puts the panel away.
    h.overlays.cancelName()
    #expect(h.overlays.cheatSheets.count == 1)

    h.run("ask-name", from: .shortcut)
    #expect(h.overlays.cheatSheets.isEmpty)
    #expect(h.overlays.namePrompt != nil)
  }

  @Test func noTitleArborComesWithIsCut() {
    let model = CheatSheetModel(shortcuts: KeyBindings.all.map { ($0.chord, $0.command) })
    // A title that was cut has exactly 48 characters. ("Go to…" ends in dots of its own.)
    for row in model.sections.flatMap(\.rows) { #expect(row.title.count < 48, "\(row.title)") }
  }

  @Test func aShortcutThatAPeekTakesPutsItAwayToo() {
    let h = makeHarness { $0 = .withEveryKey }  // the panel has keys of its own only there
    h.run("show-shortcuts", from: .shortcut)
    h.keyDown("ctrl+opt+space")  // held: a peek, which runs no command
    #expect(h.overlays.cheatSheets.isEmpty)
    h.keyUp("ctrl+opt+space")

    h.key("ctrl+opt+shift+/")
    #expect(h.overlays.cheatSheets.count == 1, "its own keys show it")
    h.key("ctrl+opt+shift+/")
    #expect(h.overlays.cheatSheets.isEmpty, "and put it away, once")
  }

  @Test func itTakesTheLinesPlace() {
    let h = makeHarness()
    h.run("out", from: .shortcut)
    h.run("show-shortcuts", from: .shortcut)
    #expect(h.overlays.headsUp.isEmpty)
    #expect(!h.scheduler.pendingKeys.contains("heads-up"))
  }

  @Test func withShortcutsSwitchedOffOrAllRemovedItSaysSoInstead() {
    let off = makeHarness { $0.hotkeysEnabled = false }
    #expect(!off.run("show-shortcuts", from: .menu).ok)
    #expect(off.overlays.cheatSheets.isEmpty)
    #expect(off.overlays.messages.map(\.model.line) == ["Shortcuts are switched off: hotkeysEnabled is false in settings.json"])

    let none = makeHarness { settings in
      for binding in KeyBindings.all { settings.bindings.updateValue(nil, forKey: binding.chord.text) }
    }
    #expect(!none.run("show-shortcuts", from: .menu).ok)
    #expect(none.overlays.cheatSheets.isEmpty)
  }

  @Test func itNeedsArborToBeRunning() {
    let h = makeHarness()
    h.run("pause")
    #expect(!h.run("show-shortcuts").ok)
    #expect(h.overlays.cheatSheets.isEmpty)
  }
}
