import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The shortcuts as Arbor ships: nine, each ⌃⌥ and one key (collab/IDEAS.md, I22). `shortcuts` set to `all` brings the whole
/// map back.
@MainActor @Suite struct NineKeysTests {
  /// Arbor as it ships, with three windows open and the first in front.
  func shipped(_ change: (inout Settings) -> Void = { _ in }) -> (h: Harness, windows: [WindowID]) {
    var settings = Settings()
    change(&settings)
    let h = Harness(settings: settings)
    let windows = ["Safari", "Mail", "Notes"].map { h.system.open(app: $0) }
    h.start()
    h.system.userFocus(windows[0])
    return (h, windows)
  }

  func decoded(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  func table(_ bindings: [KeyBinding]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: bindings.map { ($0.chord.text, $0.command.text) })
  }

  static let nine = [
    "ctrl+opt+left": "dock left", "ctrl+opt+right": "dock right", "ctrl+opt+return": "zoom", "ctrl+opt+space": "show-all",
    "ctrl+opt+[": "back", "ctrl+opt+z": "undo", "ctrl+opt+f": "toggle-float", "ctrl+opt+g": "find",
    "ctrl+opt+escape": "toggle-pause",
  ]

  // MARK: The map

  @Test func asItShipsArborTakesNineKeys() {
    #expect(Settings().shortcuts == "core")
    #expect(table(KeyBindings.effective(settings: Settings()).bindings) == Self.nine)
    #expect(table(shipped().h.controller.activeBindings) == Self.nine)
  }

  /// It reached a chat app in front and archived the conversation there (collab/IDEAS.md, I16).
  @Test func controlOptionAIsInNeitherMap() throws {
    let chord = try KeyChord(text: "ctrl+opt+a")
    #expect(!KeyBindings.core.contains { $0.chord == chord })
    #expect(!KeyBindings.all.contains { $0.chord == chord })
    // Whoever wants it says so.
    var settings = Settings()
    settings.bindings = ["ctrl+opt+a": "arrange"]
    #expect(KeyBindings.effective(settings: settings).bindings.first { $0.chord == chord }?.command == .arrange)
  }

  @Test func oneSettingBringsTheWholeMapBack() throws {
    let (h, _) = shipped()
    #expect(h.run("set shortcuts all").ok)
    #expect(h.controller.activeBindings == KeyBindings.all)
    #expect(h.controller.activeBindings.count > 40)
    // There the arrows look, and ⌘ moves, as they did.
    #expect(table(h.controller.activeBindings)["ctrl+opt+left"] == "neighbor left")
    #expect(table(h.controller.activeBindings)["ctrl+opt+cmd+left"] == "dock left")
    #expect(h.run("set shortcuts core").ok)
    #expect(table(h.controller.activeBindings) == Self.nine)
    #expect(!h.run("set shortcuts some").ok)
  }

  /// All that the nine run has a key in the whole map too, so that nothing learnt on the nine but the two arrows is unlearnt.
  @Test func theWholeMapKeepsSevenOfTheNineWhereTheyAre() {
    let whole = table(KeyBindings.all)
    for (chord, command) in Self.nine where !["ctrl+opt+left", "ctrl+opt+right"].contains(chord) {
      #expect(whole[chord] == command, "\(chord)")
    }
    for binding in KeyBindings.core { #expect(KeyBindings.all.contains { $0.command == binding.command }) }
  }

  // MARK: Each of the nine acts

  @Test func theArrowsDockTheFocusedWindow() {
    let (h, w) = shipped()
    #expect(h.key("ctrl+opt+left")?.ok == true)
    h.system.userFocus(w[1])
    #expect(h.key("ctrl+opt+right")?.ok == true)
    let (left, right) = (h.frame(w[0])!, h.frame(w[1])!)
    #expect(h.workspace.tree.leaf(containing: w[0]) != nil && h.workspace.tree.leaf(containing: w[1]) != nil)
    #expect(left.maxX <= right.minX)
    #expect(h.workspace.tree.leaf(containing: w[2]) == nil, "nobody asked for the third")
    expectWindowsMatchLayout(h)
  }

  @Test func returnFillsAndGoesBackSpaceShowsEverythingAndTheBracketGoesBack() {
    let (h, w) = shipped()
    h.key("ctrl+opt+left")
    h.system.userFocus(w[1])
    h.key("ctrl+opt+right")
    let half = h.frame(w[1])!
    #expect(h.key("ctrl+opt+return")?.ok == true)
    #expect(h.frame(w[1])!.width > half.width * 1.5)
    #expect(h.key("ctrl+opt+return")?.ok == true)
    #expect(h.frame(w[1]) == half)
    h.key("ctrl+opt+return")
    h.key("ctrl+opt+space")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.key("ctrl+opt+[")?.ok == true)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w[1]))
    expectWindowsMatchLayout(h)
  }

  @Test func undoFloatGoToAndPause() {
    let (h, w) = shipped()
    let own = h.frame(w[0])!
    h.key("ctrl+opt+left")
    #expect(h.key("ctrl+opt+z")?.ok == true)
    #expect(h.workspace.tree.leaf(containing: w[0]) == nil && h.frame(w[0]) == own)
    h.key("ctrl+opt+left")
    #expect(h.key("ctrl+opt+f")?.ok == true)
    #expect(h.workspace.tree.leaf(containing: w[0]) == nil)
    #expect(h.key("ctrl+opt+g")?.ok == true)
    #expect(h.overlays.finder != nil)
    #expect(h.key("ctrl+opt+g")?.ok == true, "again puts it away")
    #expect(h.overlays.finder == nil)
    #expect(h.key("ctrl+opt+escape")?.ok == true)
    #expect(h.controller.isPaused)
    // The one key that answers in a pause.
    #expect(h.controller.activeBindings.map(\.chord.text) == ["ctrl+opt+escape"])
    #expect(h.key("ctrl+opt+escape")?.ok == true)
    #expect(!h.controller.isPaused)
  }

  /// What is not Arbor's stays with the app in front: `key` returns nil for a chord nobody registered.
  @Test func whatTheWholeMapBoundIsTheAppsAgain() {
    let (h, w) = shipped()
    h.key("ctrl+opt+left")
    let before = (h.workspace, w.map { h.frame($0) })
    let nine = Set(Self.nine.keys)
    for binding in KeyBindings.all where !nine.contains(binding.chord.text) {
      #expect(h.key(binding.chord.text) == nil, "\(binding.chord.text)")
    }
    #expect(h.key("ctrl+opt+a") == nil)
    #expect(h.workspace == before.0 && w.map { h.frame($0) } == before.1)
  }

  // MARK: A peek

  /// Held, ⌃⌥Space peeks, and the arrows are the peek's for as long: all four, though two are bound to docking and two to nothing.
  @Test func whileSpaceIsHeldTheArrowsMoveTheOutlineAndDockNothing() {
    let (h, w) = shipped()
    h.key("ctrl+opt+left")
    h.system.userFocus(w[1])
    h.key("ctrl+opt+right")
    h.key("ctrl+opt+return")
    let tree = h.workspace.tree
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.5)
    let held = Set(h.registeredShortcuts.map(\.chord.text))
    #expect(held.isSuperset(of: ["ctrl+opt+left", "ctrl+opt+right", "ctrl+opt+up", "ctrl+opt+down", "ctrl+opt+escape"]))
    // Over the Desktop, which lies between the two.
    h.key("ctrl+opt+left")
    h.key("ctrl+opt+left")
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.tree == tree, "an arrow in a peek arranges nothing")
    #expect(h.workspace.camera == tree.leaf(containing: w[0]))
    #expect(!h.registeredShortcuts.contains { $0.chord.text == "ctrl+opt+up" }, "given back with the peek")
  }

  /// [Safari | Desktop | Mail], framed on Mail, which has the keyboard.
  func framedOnTheSecond() -> (h: Harness, windows: [WindowID]) {
    let (h, w) = shipped()
    h.key("ctrl+opt+left")
    h.system.userFocus(w[1])
    h.key("ctrl+opt+right")
    h.key("ctrl+opt+return")
    return (h, w)
  }

  /// In the whole map an arrow pressed before the hold counts looks about, which harms nothing. Here it would dock, with everything showing and
  /// the key down: so it begins the hold.
  @Test func anArrowInTheFirstMomentOfAHoldBeginsThePeekAndDocksNothing() {
    let (h, w) = framedOnTheSecond()
    let tree = h.workspace.tree
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.1)
    #expect(!h.controller.isPeeking, "the control: too early to tell")
    #expect(h.key("ctrl+opt+left") == nil, "no command ran")
    #expect(h.controller.isPeeking)
    #expect(h.workspace.tree == tree)
    h.key("ctrl+opt+left")
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.tree == tree)
    #expect(h.workspace.camera == tree.leaf(containing: w[0]), "two to the left, over the Desktop")
    expectWindowsMatchLayout(h)
  }

  /// ⎋ has decided the peek, or another command has, and the key is still down: everything looks as it did a moment ago.
  @Test(arguments: ["ctrl+opt+escape", "ctrl+opt+f"]) func onceAPeekIsDecidedTheArrowsDoNothingUntilItsKeyComesUp(ending: String) {
    let (h, _) = framedOnTheSecond()
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.5)
    h.key(ending)
    #expect(!h.controller.isPeeking && !h.controller.isPaused)
    let (tree, camera) = (h.workspace.tree, h.workspace.camera)
    #expect(h.key("ctrl+opt+left") == nil)
    #expect(h.key("ctrl+opt+right") == nil)
    #expect(h.workspace.tree == tree && h.workspace.camera == camera)
    h.keyUp("ctrl+opt+space")
    #expect(h.workspace.tree == tree && h.workspace.camera == camera)
    // And then they are what they were.
    h.key("ctrl+opt+space")
    #expect(h.key("ctrl+opt+left")?.ok == true)
    #expect(h.workspace.tree != tree)
    expectWindowsMatchLayout(h)
  }

  // MARK: A person's own file

  @Test func aPersonsOwnBindingsStandOnTopOfEitherMap() throws {
    let own = #""bindings": {"ctrl+opt+h": "dock left", "ctrl+opt+g": null, "ctrl+opt+space": "home"}"#
    for (map, count) in [("core", KeyBindings.core.count), ("all", KeyBindings.all.count)] {
      let (bindings, problems) = KeyBindings.effective(settings: try decoded(#"{"shortcuts": "\#(map)", \#(own)}"#))
      #expect(problems.isEmpty)
      #expect(bindings.count == count, "\(map): one added, one removed, one replaced")
      #expect(table(bindings)["ctrl+opt+h"] == "dock left")
      #expect(table(bindings)["ctrl+opt+g"] == nil)
      #expect(table(bindings)["ctrl+opt+space"] == "home")
    }
  }

  /// A file from before the key existed, with and without changes of its owner's: it loads, and gets the nine.
  @Test func anOlderFileLoadsAndGetsTheNine() throws {
    #expect(try decoded("{}").shortcuts == "core")
    let old = try decoded(#"{"gap": 20, "hotkeysEnabled": true, "bindings": {"ctrl+opt+d": null, "ctrl+opt+1": "view 1"}}"#)
    #expect(old.valueProblems.isEmpty && old.gap == 20)
    let (bindings, problems) = KeyBindings.effective(settings: old)
    #expect(problems.isEmpty, "removing what is not bound any more is nothing to complain of")
    var expected = Self.nine
    expected["ctrl+opt+1"] = "view 1"
    #expect(table(bindings) == expected)
  }

  @Test func aValueThatIsNoMapCostsOnlyItsOwnKey() throws {
    let settings = try decoded(#"{"shortcuts": "most", "gap": 20}"#)
    #expect(settings.shortcuts == "core" && settings.gap == 20)
    #expect(settings.valueProblems.count == 1)
    #expect(try decoded(#"{"shortcuts": 9}"#).shortcuts == "core")
  }

  /// `bind` writes nothing down that the map in use says already, and `unbind` leaves a null only where that map has a key.
  @Test func bindAndUnbindGoByTheMapInUse() {
    let (h, _) = shipped()
    #expect(h.run("bind ctrl+opt+left neighbor left").ok)
    #expect(h.controller.settings.bindings == ["ctrl+opt+left": "neighbor left"], "in the nine that is a change")
    #expect(h.run("bind ctrl+opt+left dock left").ok)
    #expect(h.controller.settings.bindings.isEmpty, "and this is the nine's own")
    #expect(h.run("unbind ctrl+opt+d").message == "ctrl+opt+d already runs nothing")
    #expect(h.controller.settings.bindings.isEmpty)
    #expect(h.run("unbind ctrl+opt+g").ok)
    #expect(h.controller.settings.bindings == ["ctrl+opt+g": nil])
  }

  /// Keys somebody has freed stay free when the map changes, whichever map had them.
  @Test func keysThatWereFreedStayFreeInTheOtherMap() {
    let (h, _) = shipped { $0 = $0.withEveryKey }
    h.run("unbind ctrl+opt+d")
    h.run("set shortcuts core")
    h.run("bind ctrl+opt+d desktop")
    h.run("unbind ctrl+opt+d")
    #expect(h.controller.settings.bindings == ["ctrl+opt+d": nil])
    h.run("set shortcuts all")
    #expect(h.key("ctrl+opt+d") == nil)
  }

  /// An entry goes by the keys alone, and ⌃⌥← runs one command among the nine and another in the whole map. A file from the days of the whole map
  /// in which Look Left was moved to other keys leaves `dock left` without a key: it is honoured, and it is said.
  @Test func bindingsSaysWhichOfArborsOwnCommandsAnEntryLeavesWithoutAKey() throws {
    let old = try decoded(#"{"bindings": {"ctrl+opt+h": "neighbor left", "ctrl+opt+left": null}}"#)
    let h = Harness(settings: old)
    h.start()
    #expect(h.key("ctrl+opt+left") == nil, "they freed those keys")
    #expect(h.run("bindings").text?.contains("no shortcut runs `dock left`: your `bindings` take ctrl+opt+left from it") == true)
    #expect(shipped().h.run("bindings").text?.contains("no shortcut runs") == false)
    // Moved to other keys it has a shortcut, and there is nothing to say.
    let moved = Harness(settings: try decoded(#"{"bindings": {"ctrl+opt+h": "dock left", "ctrl+opt+left": null}}"#))
    #expect(moved.run("bindings").text?.contains("no shortcut runs") == false)
  }

  // MARK: What people read

  @Test func bindingsListsTheNineAndSaysHowToGetMore() throws {
    let (h, _) = shipped()
    let result = h.run("bindings")
    #expect(result.message == "9 shortcuts")
    let text = try #require(result.text)
    #expect(text.split(separator: "\n").filter { $0.contains(" → ") }.count == 9)
    #expect(text.contains("`set shortcuts all`"))
    h.run("set shortcuts all")
    #expect(h.run("bindings").text?.contains("set shortcuts") == false)
  }

  @Test func thePanelOfShortcutsHasNineRowsAndALineOnTheRest() throws {
    let (h, _) = shipped()
    #expect(h.run("show-shortcuts").ok, "from the menu: it has no key of its own among the nine")
    let model = try #require(h.overlays.cheatSheets[h.display])
    let keys = model.sections.filter { $0.title != "Pointer and trackpad" }.flatMap(\.rows)
    #expect(keys.count == 9)
    #expect(keys.allSatisfy { $0.keys.hasPrefix("⌃⌥") && !$0.keys.contains("⇧") && !$0.keys.contains("⌘") })
    #expect(model.footer.contains("menu") && model.footer.contains("Settings…"))
    h.run("show-shortcuts")
    h.run("set shortcuts all")
    h.run("show-shortcuts")
    #expect(h.overlays.cheatSheets[h.display]?.footer == "Press any key to close")
  }

  /// A command without a key shows none; one of the nine shows its own.
  @Test func theMenuShowsAKeyOnlyWhereThereIsOne() {
    let (h, _) = shipped()
    h.key("ctrl+opt+left")
    let items = h.controller.menuModel().allItems
    func shortcut(_ command: Command) -> String?? { items.first { $0.command == command }.map(\.shortcut?.label) }
    #expect(shortcut(.showAll) == "⌃⌥Space")
    #expect(shortcut(.undo) == "⌃⌥Z")
    #expect(shortcut(.togglePause) == "⌃⌥⎋")
    #expect(shortcut(.arrange) == .some(nil))
    #expect(shortcut(.showShortcuts) == .some(nil))
    // ⌘Q is the menu's own, while it is open.
    let shown = Set(items.compactMap(\.shortcut?.label)).subtracting(["⌘Q"])
    #expect(shown == Set(KeyBindings.core.map(\.label)), "each of the nine is in the menu, with its key: \(shown)")
  }

  /// The first of the welcome window's moves names the keys that dock, and a dock that cannot be says which key leads out.
  @Test func theWelcomeWindowAndTheRefusalNameTheKeysInEffect() {
    let (h, _) = shipped()
    let facts = SystemFacts(
      accessibility: true, screenRecording: true, switches: [], separateSpaces: true, voiceOver: false, inputSources: 1, eventTaps: [])
    let welcome = h.controller.onboardingModel(facts)
    #expect(welcome.step(.dock)?.lead == "Click a window and press ⌃⌥←")
    #expect(welcome.step(.dockSecond)?.lead == "Click another and press ⌃⌥→")
    #expect(welcome.step(.frame)?.lead == "Then press ⌃⌥↩")
    h.key("ctrl+opt+left")
    h.key("ctrl+opt+return")
    #expect(h.key("ctrl+opt+right")?.ok == false)
    #expect(h.overlays.messages.last?.model.line == "Safari fills the view; ⌃⌥Space first")
  }

  /// The menu is the way to whatever lost its key. Three kinds of command have no row: they walk from where one is, or do on every display what
  /// Show Everything does on this one, and are nothing without a key. Whoever gives one a row takes it off this list.
  @Test func whatHasNoKeyIsInTheMenu() {
    let (h, _) = shipped()
    h.key("ctrl+opt+left")
    for slot in 1...9 { h.run("save-view \(slot)") }
    let rows = h.controller.menuModel().allItems.compactMap(\.command)
    let without = KeyBindings.all.map(\.command).filter { command in !rows.contains(command) }
    #expect(
      without.map(\.text).sorted() == [
        "focus down", "focus left", "focus right", "focus up", "home", "neighbor left", "neighbor right",
      ])
    #expect(rows.contains(.arrange))
  }

  // MARK: Other keyboards

  /// `[` is not one key in Europe. It stays where a US keyboard has it and is shown as what is printed there (F44); the other eight are
  /// letters, arrows and keys that are the same everywhere. No two land on one key.
  @Test func theNineWorkOnEveryKeyboard() throws {
    let back = try KeyChord(text: "ctrl+opt+[")
    for layout in [SampleKeyLayouts.german, SampleKeyLayouts.french, SampleKeyLayouts.dvorak, SampleKeyLayouts.russian] {
      let (bindings, problems) = KeyBindings.effective(settings: Settings(), layout: layout)
      #expect(problems.isEmpty, "\(layout.name): \(problems)")
      #expect(bindings.count == 9)
      #expect(Set(bindings.map(\.keyCode)).count == 9, "\(layout.name)")
    }
    let german = KeyBindings.effective(settings: Settings(), layout: SampleKeyLayouts.german).bindings
    #expect(german.first { $0.chord == back }?.label == "⌃⌥Ü")
    #expect(german.first { $0.chord == back }?.keyCode == KeyBinding(back, .back).keyCode)
    #expect(german.first { $0.command == .undo }?.label == "⌃⌥Z", "the key that types Z, which is where Y is on a US keyboard")
  }
}
