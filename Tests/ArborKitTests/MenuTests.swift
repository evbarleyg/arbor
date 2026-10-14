import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What Arbor's menu offers, against the real controller (Controller+Menu.swift).
@Suite @MainActor struct MenuTests {
  /// [Safari | Desktop | Notes] with Mail floating, started, showing everything, Safari focused.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    return (h, a, b, c)
  }

  // MARK: The whole of it

  /// The menu, written out in the order docs/MENU.md decides. **Whoever adds an item adds its line here, in the place
  /// its row has there**: an item appended anywhere else fails this test.
  @Test func theWholeMenu() {
    let (h, _, _, _) = makeHarness()
    h.loginItem.status = .enabled
    h.run("save-view 2")
    h.run("exclude com.apple.Music")
    #expect(
      h.run("menu").text == """
        View
          ✓ Show Everything  ⌃⌥Space
            Show the Desktop  ⌃⌥D
            Frame Focused Window  ⌃⌥↩
            Step Out  ⌃⌥↑  (grey)
            Step In  ⌃⌥↓
            Back  ⌃⌥[  (grey)
            Forward  ⌃⌥]  (grey)
            Go to…  ⌃⌥G
            Saved Views ▸
                Go To
                  ✓ View 2: everything  ⌃⌥2
                Save This View As
                    View 1  ⌃⌥⇧1
                    View 2 (replace)  ⌃⌥⇧2
                    View 3  ⌃⌥⇧3
                    View 4  ⌃⌥⇧4
                    View 5  ⌃⌥⇧5
                    View 6  ⌃⌥⇧6
                    View 7  ⌃⌥⇧7
                    View 8  ⌃⌥⇧8
                    View 9  ⌃⌥⇧9
                -----
                    Name This Space…  ⌃⌥N
            Show Minimap  ⌃⌥M
        Focused Window
            Dock Focused Window ▸
                Left  ⌃⌥⌘←  (grey)
                Right  ⌃⌥⌘→
                Top  ⌃⌥⌘↑
                Bottom  ⌃⌥⌘↓
            Float Focused Window  ⌃⌥F
            Keep This Window in View
            Don’t Arrange “Safari”
            Shortcuts Off in “Safari”
        Arrangement
            Undo Dock  ⌃⌥Z
            Redo  ⌃⌥⇧Z  (grey)
            Arrange Windows  ⌃⌥A
            Float All Windows  ⌃⌥⇧F
            Adjust ▸
                Grow  ⌃⌥⌘=
                Shrink  ⌃⌥⌘-
                Balance Sizes  ⌃⌥⌘0
            -----
                Rotate Group  ⌃⌥R
                Mirror Group  ⌃⌥⇧R
            -----
                Lay Out Again
            Dock New Windows
            Arrange Again ▸
                Music
        Arbor
            Hold This View
            Hold Still
            Settings…  ⌃⌥,
            Keyboard Shortcuts…  ⌃⌥⇧/
            Help ▸
                Welcome…
                Check Setup…
            -----
                Settings File…
                Reload Settings
                Show Log
            -----
                Check for Updates…
                About Arbor
        -----
            Pause Arbor  ⌃⌥⎋
            Quit Arbor  ⌘Q
        """)
  }

  /// A state comes first, in plain words, with the command that ends it right under it.
  @Test func aPausedArborOffersOnlyTheWaysOut() {
    let (h, _, _, _) = makeHarness()
    h.run("pause")
    #expect(
      h.run("menu").text == """
            Arbor is paused: it leaves windows and shortcuts alone  (grey)
            Resume  ⌃⌥⎋
        -----
            Settings…
            Help ▸
                Welcome…
                Check Setup…
            -----
                Settings File…
                Reload Settings  (grey)
                Show Log
            -----
                Check for Updates…
                About Arbor
        -----
            Quit Arbor  ⌘Q
        """)
    // Choosing Resume does what it says.
    let resume = h.controller.menuModel().item("Resume")?.command
    #expect(resume.map { h.controller.perform($0).ok } == true)
    #expect(h.controller.isRunning)
    #expect(h.controller.menuModel().item("Pause Arbor") != nil)
  }

  @Test func withoutThePermissionTheMenuLeadsToIt() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let top = h.controller.menuModel().sections.map { $0.items.map(\.title) }
    #expect(top == [["Arbor needs Accessibility permission", "Check Setup…"], ["Settings…", "Help"], ["Quit Arbor"]])
    // Paused as well, by whatever route: the permission is what is wanted first.
    let (paused, _, _, _) = makeHarness()
    paused.run("pause")
    paused.controller.accessibilityGranted = false
    #expect(paused.controller.menuModel().sections.first?.items.map(\.title) == top[0])
  }

  @Test func betweenThePermissionAndTheFirstLayoutItSaysSo() {
    let top = Harness().controller.menuModel().sections.map { $0.items.map(\.title) }
    #expect(top == [["Arbor is starting…"], ["Settings…", "Help"], ["Quit Arbor"]])
  }

  /// docs/MENU.md, rule 1: always at the top level, always in the same place, never greyed out while Arbor runs.
  @Test(arguments: ["everything", "framed", "floating", "nothing docked", "no windows"])
  func theWaysBackAreAlwaysThere(state: String) {
    let menu = harness(in: state).controller.menuModel()
    #expect(menu.sections.first?.items.first?.title == "Show Everything", "the first command in the menu")
    #expect(menu.sections.last?.items.map(\.title) == ["Pause Arbor", "Quit Arbor"], "the last two rows")
    #expect(menu.section("Arrangement")?.items.contains { $0.title == "Float All Windows" } == true)
    for title in ["Show Everything", "Float All Windows", "Pause Arbor", "Quit Arbor"] {
      #expect(menu.item(title)?.isEnabled == true, "\(title)")
    }
  }

  /// docs/MENU.md, rule 4: a row that cannot act now keeps its place.
  @Test func rowsAreGreyedOutNotLeftOut() {
    func rows(_ state: String) -> [[String]] {
      harness(in: state).controller.menuModel().sections.map { section in
        // Without the name of the app, or of the step, a row is about.
        section.items.map { item in
          ["Keep", "Don’t Arrange", "Shortcuts Off", "Undo", "Redo"].first { item.title.hasPrefix($0 + " ") } ?? item.title
        }
      }
    }
    let usual = rows("everything")
    for state in ["framed", "floating", "nothing docked", "no windows"] { #expect(rows(state) == usual, "\(state)") }
    let empty = harness(in: "no windows").controller.menuModel()
    #expect(empty.section("Focused Window")?.items.allSatisfy { !$0.isEnabled || !$0.sections.isEmpty } == true)
    #expect(empty.item("Dock Focused Window")?.sections.flatMap(\.items).contains { $0.isEnabled } == false)
  }

  /// A started harness in one of the states a menu can open in.
  func harness(in state: String) -> Harness {
    if state == "no windows" {
      let h = Harness()
      h.start()
      h.run("exclude com.apple.Music")
      return h
    }
    let (h, a, b, c) = makeHarness()
    h.run("save-view 1")
    h.run("exclude com.apple.Music")
    switch state {
    case "framed": h.run("zoom \(a.rawValue)")
    case "floating": h.system.userFocus(c)
    case "nothing docked":
      h.run("float \(a.rawValue)")
      h.run("float \(b.rawValue)")
    default: break
    }
    return h
  }

  // MARK: Rules that hold for every item, whoever adds it

  /// Every state the menu has, so that the rules below see every item.
  func everyMenu() -> [MenuModel] {
    let (h, a, _, _) = makeHarness()
    h.controller.systemFacts = {
      SystemFacts(accessibility: true, screenRecording: true, switches: [], opensAtLogin: false)
    }
    h.run("save-view 1")
    h.run("exclude com.apple.Music")
    var menus = [h.controller.menuModel()]
    h.run("zoom \(a.rawValue)")
    menus.append(h.controller.menuModel())
    h.run("pause")
    menus.append(h.controller.menuModel())
    let waiting = Harness()
    waiting.controller.accessibilityGranted = false
    menus.append(waiting.controller.menuModel())
    return menus
  }

  @Test func titlesTakeTheirWordsFromTheGlossary() {
    // The right-hand column of docs/GLOSSARY.md, as far as a menu could be tempted.
    let banned = [
      "hidden", "parked", "off-screen", "hotkey", "binding", "monitor", "screen", "stack", "seam", "camera", "node",
      "workspace", "undock", "snap", "maximi", "manage", "disable", "suspend", "bookmark", "overview",
    ]
    for item in everyMenu().flatMap(\.allItems) {
      // A display is never a screen, but what people do in a call is share their screen: macOS and every call app say so.
      let words = (item.title + " " + (item.help ?? "")).lowercased().replacingOccurrences(of: "a shared screen", with: "")
      for word in banned { #expect(!words.contains(word), "“\(item.title)” says “\(word)”") }
      #expect(!item.title.contains("..."), "“\(item.title)”: an ellipsis is one character")
      #expect(!item.title.contains("\""), "“\(item.title)”: curly quotes around names")
      #expect(item.title == item.title.trimmingCharacters(in: .whitespaces) && !item.title.isEmpty)
    }
  }

  @Test func noTitleComesTwiceWhereItCouldBeTakenForTheOther() {
    func check(_ sections: [MenuModel.Section]) {
      // The command that ends a state may be a row that also has a place of its own: the same title doing the same thing.
      var seen: [String: MenuModel.Item.Action] = [:]
      for item in sections.flatMap(\.items) {
        if let other = seen[item.title] { #expect(other == item.action, "“\(item.title)” twice in one menu, for two things") }
        seen[item.title] = item.action
      }
      for item in sections.flatMap(\.items) { check(item.sections) }
    }
    for menu in everyMenu() { check(menu.sections) }
  }

  @Test func everyCommandHasATextFormSoThatTheMenuDoesNothingAScriptCannot() throws {
    for command in everyMenu().flatMap(\.allItems).compactMap(\.command) {
      #expect(try Command.parse(command.text) == command)
    }
  }

  @Test func everyItemShowsTheShortcutThatIsRegisteredForItAndNoOther() {
    let (h, _, _, _) = makeHarness()
    // macOS refused ⌃⌥D: another app holds it.
    h.controller.registeredBindings = KeyBindings.effective(settings: Settings()).bindings.filter { $0.command != .desktop }
    let menu = h.controller.menuModel()
    #expect(menu.item("Show the Desktop")?.shortcut == nil)
    for item in menu.allItems {
      guard let command = item.command else { continue }
      #expect(item.shortcut == h.controller.shortcut(for: command), "\(item.title)")
    }
  }

  @Test func withShortcutsOffTheMenuShowsNoneOfArbors() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let (h, _, _, _) = makeHarness(settings: settings)
    #expect(h.controller.menuModel().allItems.compactMap(\.shortcut?.label) == ["⌘Q"])
  }

  /// What is not greyed out works, in the state the menu was built for: a menu item that only beeps is a riddle.
  @Test(arguments: ["everything", "framed", "floating", "nothing docked", "no windows"])
  func whatCanBeChosenDoesNotFail(state: String) {
    // Tried elsewhere: there is no window to open here, and a pause ends the state. Float All Windows is a way back,
    // which is never greyed out, whether or not there is anything to float.
    let elsewhere: [Command] = [.togglePause, .welcome, .checkSetup, .settings(.showWindow()), .floatAll]
    for item in harness(in: state).controller.menuModel().allItems where item.isEnabled {
      guard let command = item.command, !elsewhere.contains(command) else { continue }
      let result = harness(in: state).controller.perform(command, from: .menu)
      #expect(result.ok, "\(item.title): \(result.message)")
    }
  }

  // MARK: Items that depend on something

  @Test func goToIsGreyedOutWhenThereIsNowhereToGo() {
    #expect(harness(in: "no windows").controller.menuModel().item("Go to…")?.isEnabled == false)
    #expect(harness(in: "everything").controller.menuModel().item("Go to…")?.isEnabled == true)
  }

  @Test func placesAreTickedAndGreyedOutAsTheButtonsAre() {
    let (h, a, _, _) = makeHarness()
    #expect(h.controller.menuModel().item("Show Everything")?.isTicked == true)
    #expect(h.controller.menuModel().item("Back")?.isEnabled == false)
    h.run("zoom \(a.rawValue)")
    let menu = h.controller.menuModel()
    #expect(menu.item("Show Everything")?.isTicked == false)
    #expect(menu.item("Back")?.isEnabled == true)
    #expect(menu.item("Forward")?.isEnabled == false)
  }

  /// The settings may take buttons out of the menu bar; the menu is where everything still is.
  @Test func theMenuIsCompleteWhateverTheMenuBarShows() {
    var settings = Settings()
    settings.menuBarControls = false
    settings.historyButtons = false
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.menuModel().item("Back")?.isEnabled == true)
  }

  /// With nothing docked the Desktop is everything. True, and odd to read as two ticks.
  @Test func withNothingDockedOnlyShowEverythingIsTicked() {
    let menu = harness(in: "nothing docked").controller.menuModel()
    #expect(menu.item("Show Everything")?.isTicked == true)
    #expect(menu.item("Show the Desktop")?.isTicked == false)
    let (h, _, _, _) = makeHarness()
    h.run("desktop")
    #expect(h.controller.menuModel().item("Show the Desktop")?.isTicked == true)
    #expect(h.controller.menuModel().item("Show Everything")?.isTicked == false)
  }

  @Test func floatIsForADockedWindow() {
    let (h, a, _, c) = makeHarness()
    let float = h.controller.menuModel().item("Float Focused Window")
    #expect(float?.isEnabled == true)
    #expect(float?.shortcut?.label == "⌃⌥F", "the row runs what the shortcut runs")
    #expect(float?.command.map { h.controller.perform($0).ok } == true)
    #expect(h.workspace.isDocked(a) == false)
    h.system.userFocus(c)
    let menu = h.controller.menuModel()
    #expect(menu.item("Float Focused Window")?.isEnabled == false, "Mail floats already")
    #expect(menu.item("Don’t Arrange “Mail”")?.command == .exclude(bundleID: "com.example.mail"))
  }

  @Test func theFramedWindowIsTicked() {
    let (h, a, _, c) = makeHarness()
    #expect(h.controller.menuModel().item("Frame Focused Window")?.isTicked == false)
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.menuModel().item("Frame Focused Window")?.isTicked == true)
    // Chosen again it un-frames, as the key does.
    #expect(h.controller.perform(.zoom(nil)).ok)
    #expect(h.controller.menuModel().item("Frame Focused Window")?.isTicked == false)
    h.system.userFocus(c)
    h.run("desktop")
    #expect(h.controller.menuModel().item("Frame Focused Window")?.isTicked == false, "a floating window is never framed")
  }

  @Test func aWindowKeptInViewIsTicked() {
    let (h, _, _, c) = makeHarness()
    h.system.userFocus(c)
    let row = h.controller.menuModel().item("Keep This Window in View")
    #expect(row?.isTicked == false && row?.help != nil)
    #expect(row?.command.map { h.controller.perform($0, from: .menu).ok } == true)
    #expect(h.controller.menuModel().item("Keep This Window in View")?.isTicked == true)
  }

  /// docs/MENU.md, state 6: a line says so, the row that ends it carries the tick, and no row shows a shortcut that is off.
  @Test func anAppThatKeepsItsOwnShortcutsIsSaidAndTicked() {
    let (h, _, _, _) = makeHarness()
    let row = h.controller.menuModel().item("Shortcuts Off in “Safari”")
    #expect(row?.isTicked == false && row?.shortcut == nil)
    #expect(row?.command.map { h.controller.perform($0, from: .menu).ok } == true)
    let menu = h.controller.menuModel()
    #expect(menu.sections.first?.items.map(\.title) == ["Shortcuts are off in “Safari”"])
    #expect(menu.sections.dropFirst().first?.items.first?.title == "Show Everything", "and the rest is where it was")
    #expect(menu.item("Shortcuts Off in “Safari”")?.isTicked == true)
    #expect(menu.allItems.compactMap(\.shortcut?.label) == ["⌃⌥⎋", "⌘Q"], "the one that still works, and the menu's own")
  }

  @Test func aPauseBegunForAnAppNamesIt() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let (h, _, _, _) = makeHarness(settings: settings)
    h.system.activate(bundleID: "com.example.game", name: "Game")
    #expect(h.controller.isPaused)
    #expect(
      h.controller.menuModel().sections.first?.items.map(\.title) == ["Arbor is paused for “Game”", "Resume"])
  }

  /// Back is ⌃⌥[ where a keyboard has that key, and the key in its place elsewhere (F44).
  @Test func shortcutsAreShownAsTheKeyboardHasThem() {
    let (h, _, _, _) = makeHarness()
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    let menu = h.controller.menuModel()
    #expect(menu.item("Back")?.shortcut?.label == "⌃⌥Ü")
    #expect(menu.item("Back")?.shortcut?.keyEquivalent == "ü", "what AppKit draws as Ü")
    #expect(menu.item("Arrange Windows")?.shortcut?.keyEquivalent == "a")
    #expect(menu.item("Show Everything")?.shortcut?.keyEquivalent == " ")
    #expect(menu.item("Quit Arbor")?.shortcut?.keyEquivalent == "q")
  }

  /// What AppKit draws beside a row and what Arbor says the shortcut is are one and the same, on every keyboard.
  @Test func theKeyAppKitDrawsIsTheKeyInTheLabel() {
    for (name, layout) in SampleKeyLayouts.byName.sorted(by: { $0.key < $1.key }) {
      for key in KeyChord.Key.allCases where key.character != nil {
        for modifiers: KeyChord.Modifiers in [[.control, .option], [.control, .option, .shift]] {
          let shortcut = MenuModel.Shortcut(KeyChord(modifiers, key), layout: layout)
          #expect(
            // In lower case: a capital ß is two letters.
            shortcut.label.lowercased().hasSuffix(shortcut.keyEquivalent),
            "\(name): \(shortcut.label) is drawn as \(shortcut.keyEquivalent)")
        }
      }
    }
  }

  /// Never a bundle id where a name can be had.
  @Test func appsToArrangeAgainAreListedByName() {
    let (h, _, _, _) = makeHarness()
    #expect(h.controller.menuModel().item("Arrange Again") == nil, "every app is arranged")
    h.controller.nameOfApp = { $0 == "us.zoom.xos" ? "zoom.us" : nil }
    for bundle in ["us.zoom.xos", "com.apple.Music", "com.example.mail"] { h.run("exclude \(bundle)") }
    let apps = h.controller.menuModel().item("Arrange Again")?.sections.flatMap(\.items) ?? []
    #expect(apps.map(\.title) == ["Mail", "Music", "zoom.us"], "from its open window, from its id for want of better, from macOS")
    #expect(apps.map(\.command) == ["com.example.mail", "com.apple.Music", "us.zoom.xos"].map { .include(bundleID: $0) })
  }

  @Test func savedViewsSayWhatTheyHold() {
    let (h, a, _, _) = makeHarness()
    #expect(h.controller.menuModel().item("Saved Views")?.sections.map(\.title) == ["Save This View As", nil], "none yet")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 3")
    let menu = h.controller.menuModel()
    #expect(menu.item("Saved Views")?.sections.map(\.title) == ["Go To", "Save This View As", nil])
    #expect(menu.item("View 3: Safari")?.command == .goToView(3))
    #expect(menu.item("View 3: Safari")?.isTicked == true)
    #expect(menu.item("View 3 (replace)")?.command == .saveView(3))
  }

  /// docs/MENU.md: named spaces are listed under Go To, after the numbers; the row that names one comes last (F20).
  @Test func namedSpacesComeAfterTheNumbers() {
    let (h, a, _, _) = makeHarness()
    h.run("save-view 2")
    h.run("zoom \(a.rawValue)")
    h.run("name Reading")
    let sections = h.controller.menuModel().item("Saved Views")?.sections ?? []
    #expect(sections.first?.items.map(\.title) == ["View 2: everything", "Reading"])
    #expect(sections.first?.items.last?.isTicked == true, "it is the view")
    #expect(sections.last?.items.map(\.title) == ["Name This Space…"])
    h.run("show-all")
    let row = h.controller.menuModel().item("Reading")
    #expect(row?.isTicked == false)
    #expect(row?.command.map { h.controller.perform($0, from: .menu).ok } == true)
    #expect(h.controller.menuModel().item("Reading")?.isTicked == true)
  }

  /// An automatic check opens no window: the row's title is the one sign of what it found (F13).
  @Test func theUpdateRowTakesItsTitleFromTheController() {
    let (h, _, _, _) = makeHarness()
    let row = h.controller.menuModel().item(h.controller.updateMenuTitle)
    #expect(row?.title == "Check for Updates…" && row?.command == .checkForUpdates && row?.shortcut == nil)
  }

  /// docs/MENU.md, state 7, and "at most two states".
  @Test func aSettingsFileThatCannotBeReadIsAStateWithTheFileUnderIt() throws {
    struct Broken: Error, CustomStringConvertible { let description = "line 3, column 3: expected `,` or `}`" }
    let (h, _, _, _) = makeHarness()
    h.controller.loadSettings = { throw Broken() }
    #expect(!h.run("reload-settings").ok)
    let problem = try #require(h.controller.settingsFileProblem)
    let line = "Settings.json has a mistake: " + String(problem.split(separator: ":", maxSplits: 1)[0])
    #expect(h.controller.menuModel().sections.first?.items.map(\.title) == [line, "Settings File…"])
    #expect(h.controller.menuModel().sections.dropFirst().first?.items.first?.title == "Show Everything")

    // After another state it is the second…
    let (other, _, _, _) = makeHarness()
    other.run("pass-through com.example.safari on")
    other.controller.loadSettings = { throw Broken() }
    other.run("reload-settings")
    #expect(
      other.controller.menuModel().sections.first?.items.map(\.title)
        == ["Shortcuts are off in “Safari”", line, "Settings File…"])
    // …and so it is during a pause, when shortcuts are off everywhere and that line has nothing to add.
    other.run("pause")
    #expect(
      other.controller.menuModel().sections.first?.items.map(\.title)
        == ["Arbor is paused: it leaves windows and shortcuts alone", "Resume", line, "Settings File…"])
  }

  /// docs/MENU.md, state 3: a pause with an end says when.
  @Test func aPauseWithAnEndSaysWhen() throws {
    let (h, _, _, _) = makeHarness()
    let begun = Date(timeIntervalSince1970: 1_800_000_000)
    h.controller.now = { begun }
    h.run("pause 60")
    let line = try #require(h.controller.menuModel().sections.first?.items.first?.title)
    #expect(line == "Arbor is paused until \(begun.addingTimeInterval(3600).formatted(date: .omitted, time: .shortened))")
    #expect(line != "Arbor is paused until \(begun.formatted(date: .omitted, time: .shortened))" && line.contains { $0.isNumber })
    // A plain pause replaces it, and has no end to tell.
    h.run("pause")
    #expect(h.controller.menuModel().sections.first?.items.first?.title == "Arbor is paused: it leaves windows and shortcuts alone")
  }

  /// docs/MENU.md, state 8: what no command ends comes last, in a line short enough for a menu.
  @Test func whatBecameOfTheSavedArrangementIsTheLastState() {
    let h = Harness()
    h.system.open(app: "Safari")
    h.store.repairs = ["workspaces: skipped `side`"]
    h.store.keptCopy = "state.before-repair.json"
    h.start()
    let news = "The saved arrangement needed 1 repair when it was read"
    let lines = h.controller.menuModel().sections.first?.items
    #expect(lines?.map(\.title) == [news])
    #expect(lines?.first?.isEnabled == false)
    #expect(lines?.first?.help == h.controller.notices[0] && lines?.first?.help?.contains("state.before-repair.json") == true)
    #expect(h.controller.menuModel().sections.dropFirst().first?.items.first?.title == "Show Everything")
    h.run("pause")
    #expect(
      h.controller.menuModel().sections.first?.items.map(\.title)
        == ["Arbor is paused: it leaves windows and shortcuts alone", "Resume", news])
  }

  /// Found by `MenuChaosTests`. A window kept in view has no place to frame: the key un-frames what lies beneath it, if that is framed.
  @Test func frameIsGreyForAWindowKeptInViewUnlessSomethingBeneathItIsFramed() {
    let (h, a, _, c) = makeHarness()
    func frame() -> MenuModel.Item? { h.controller.menuModel().item("Frame Focused Window") }
    h.run("pin \(c.rawValue)")
    h.system.userFocus(c)
    #expect(frame()?.isEnabled == false)
    #expect(!h.run("zoom", from: .menu).ok, "as the command says")
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(c)
    #expect(frame()?.isEnabled == true)
    #expect(h.run("zoom", from: .menu).ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    // An ordinary floating window lives on the Desktop, which can be shown.
    h.run("unpin \(c.rawValue)")
    #expect(frame()?.isEnabled == true)
  }

  /// Found by `MenuChaosTests`. Windows kept in view accompany the arrangement; `arrange` does not take them.
  @Test func arrangeIsGreyWhenOnlyWindowsKeptInViewAreThere() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    func arrange() -> MenuModel.Item? { h.controller.menuModel().item("Arrange Windows") }
    #expect(arrange()?.isEnabled == true)
    h.run("pin \(a.rawValue)")
    #expect(arrange()?.isEnabled == false)
    #expect(!h.run("arrange", from: .menu).ok, "as the command says")
    h.run("unpin \(a.rawValue)")
    #expect(arrange()?.isEnabled == true)
  }

  /// Found by `MenuChaosTests`.
  @Test func keyboardShortcutsIsGreyWhenThereAreNone() {
    var off = Settings()
    off.hotkeysEnabled = false
    let (h, _, _, _) = makeHarness(settings: off)
    #expect(h.controller.menuModel().item("Keyboard Shortcuts…")?.isEnabled == false)
    #expect(!h.run("show-shortcuts", from: .menu).ok, "as the command says")
    #expect(makeHarness().0.controller.menuModel().item("Keyboard Shortcuts…")?.isEnabled == true)
  }

  /// Found by `MenuChaosTests`. Out of a tab group that fills the view a window can still go.
  @Test func dockIsOfferedOutOfATabGroupThatFillsTheView() {
    let (h, a, b, _) = makeHarness()
    h.run("layout [\(a.rawValue) \(b.rawValue)] | Desktop")
    h.system.userFocus(a)
    h.run("zoom \(a.rawValue)")
    let right = h.controller.menuModel().item("Right")
    #expect(right?.isEnabled == h.run("dock right", from: .menu).ok)
    #expect(right?.isEnabled == true)
  }

  /// The product owner, 2026-10-14: it pins a window, so the row names no app. One row, greyed out when there is no window.
  @Test func keepThisWindowInViewNamesNoApp() {
    let (h, _, _, _) = makeHarness()
    #expect(h.controller.menuModel().item("Keep This Window in View")?.isEnabled == true)
    #expect(!h.controller.menuModel().allItems.contains { $0.title.hasPrefix("Keep “") })
    h.system.userFocusesNothing()
    let row = h.controller.menuModel().item("Keep This Window in View")
    #expect(row?.isEnabled == false && row?.isTicked == false && row?.command == .togglePin(nil))
  }

  /// A list edited by hand can name an app twice, in other capitals too.
  @Test func arrangeAgainListsAnAppOnce() {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.mail", "com.example.Mail", "com.example.mail", "com.example.zoom"]
    let (h, _, _, _) = makeHarness(settings: settings)
    #expect(h.controller.menuModel().item("Arrange Again")?.sections.flatMap(\.items).count == 2)
  }

  /// Before the app has registered any shortcut, each asking reads the whole of the settings' bindings again: once per menu, not per row.
  @Test func theShortcutsAreTheSameWhetherAskedOneByOneOrForTheWholeMenu() {
    let (h, _, _, _) = makeHarness()
    h.controller.registeredBindings = nil
    for item in h.controller.menuModel().allItems where item.showsShortcut && item.title != "Quit Arbor" {
      guard let command = item.command else { continue }
      #expect(item.shortcut == h.controller.shortcut(for: command), "\(item.title)")
    }
  }

  @Test func menuIsAQuery() throws {
    #expect(try Command.parse("menu") == .menu)
    #expect(Command.menu.isQuery)
    #expect(!Command.menu.isAllowedFromURL)
  }
}
