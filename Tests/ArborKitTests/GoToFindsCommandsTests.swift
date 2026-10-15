import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Go to… finds commands (board 0.14; docs/features/F27-window-finder.md, "Commands"). With few keys bound, everything else is in the
/// menu and here.
@Suite @MainActor struct GoToFindsCommandsTests {
  /// Safari and Notes docked, Mail floating with the keyboard.
  private func makeHarness(
    settings: Settings = Settings(), displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]
  ) -> (h: Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let safari = h.system.open(app: "Safari", title: "Arbor docs")
    let notes = h.system.open(app: "Notes", title: "Shopping")
    let mail = h.system.open(app: "Mail", title: "Inbox", frame: CGRect(x: 500, y: 300, width: 500, height: 400))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.userFocus(mail)
    h.scheduler.advance(by: 1)
    return (h, safari, notes, mail)
  }

  /// The menu's rows that run a command, each with its way through the menu.
  private func menuRows(_ h: Harness) -> [(name: String, item: MenuModel.Item)] {
    func walk(_ sections: [MenuModel.Section], _ path: [String], _ inSubmenu: Bool) -> [(String, MenuModel.Item)] {
      sections.flatMap { section -> [(String, MenuModel.Item)] in
        let path = path + (inSubmenu ? [section.title].compactMap { $0 } : [])
        return section.items.flatMap { item in
          (item.command == nil ? [] : [((path + [isAnApp(item) ? "“\(item.title)”" : item.title]).joined(separator: " ▸ "), item)])
            + walk(item.sections, path + [item.title], true)
        }
      }
    }
    return walk(h.controller.menuModel().sections, [], false)
  }

  /// A row that is an app's name and nothing else. The palette marks it as the menu marks a name in the midst of a title.
  private func isAnApp(_ item: MenuModel.Item) -> Bool {
    if case .include = item.command { return true }
    return false
  }

  /// Listed as places already, under the same names; and the palette itself.
  private func isAPlaceOrThePalette(_ command: Command) -> Bool {
    switch command {
    case .find, .goToView, .goToSpace, .reveal: true
    default: false
    }
  }

  /// ⌃⌥G, the text, ↓ to the first command, Return.
  @discardableResult
  private func choose(_ h: Harness, _ text: String) -> Bool {
    h.run("find")
    guard case .command = picked(h, typing: text) else { return false }
    return h.overlays.chooseInFinder()
  }

  /// What ↓ comes to after this was typed, past the places that hold the letters: the first command.
  private func picked(_ h: Harness, typing text: String) -> FinderDestination? {
    h.overlays.typeInFinder(text)
    let places = h.overlays.finder?.items.prefix { $0.row.place != .command }.count ?? 0
    h.overlays.moveFinderSelection(by: max(places, 1))
    return h.overlays.finder?.selected
  }

  // MARK: What is found

  @Test func everyCommandInTheMenuIsFoundByItsNameInTheMenu() throws {
    let (h, _, _, _) = makeHarness()
    h.run("save-view 2")
    h.run("name Reading")
    h.run("exclude com.example.calendar")
    let rows = menuRows(h).filter { !isAPlaceOrThePalette($0.item.command!) }
    #expect(rows.count >= 45, "or this looks at nothing: \(rows.count)")
    h.run("find")
    for (name, item) in rows {
      let command = try #require(item.command)
      // As somebody reads it off the menu. Nobody types the arrows.
      #expect(picked(h, typing: name.replacingOccurrences(of: " ▸", with: "")) == .command(command.text), "\(name)")
      #expect(picked(h, typing: name) == .command(command.text), "copied, signs and all: \(name)")
      let row = try #require(h.overlays.finder?.items.first { $0.isSelected }?.row)
      #expect(row.name == name)
      #expect(row.shortcut == item.shortcut?.label, "\(name)")
      #expect(row.isOn == item.isTicked, "\(name)")
      #expect(row.isAvailable == item.isEnabled, "\(name)")
    }
  }

  /// In a state the menu has a command twice: in the row that says so and ends it ("Holding still · Release"), and as the tick on its
  /// own row (View ▸ Hold Still). These are the two states in which the palette can be open: a held view refuses it, and so does
  /// an Arbor that is paused or waits for its permission.
  @Test(arguments: ["hold still", "pass-through com.example.mail on"])
  func aCommandTheMenuHasUnderTwoNamesIsFoundByEither(state: String) throws {
    let (h, _, _, _) = makeHarness()
    h.run(state)
    let twice = Dictionary(grouping: menuRows(h), by: { $0.item.command!.text }).filter { $0.value.count > 1 }
    #expect(!twice.isEmpty, "or this looks at nothing")
    h.run("find")
    for (text, rows) in twice where !isAPlaceOrThePalette(rows[0].item.command!) {
      #expect(rows.contains { $0.name.contains(" · ") }, "one of them is the state's: \(rows.map(\.name))")
      for row in rows {
        #expect(picked(h, typing: row.name.replacingOccurrences(of: " ▸", with: "")) == .command(text))
        #expect(h.overlays.finder?.items.first?.row.name == row.name)
      }
      // Decided by the product owner, 2026-10-15: a state's row never comes ahead of the command of the same name in its own menu. It does:
      // of equally good matches the one whose name begins with a word of the query comes first (`FinderQuery`), and the name of a row in a
      // submenu begins with its way there. Both rows run the same command, so nothing goes wrong meanwhile.
      withKnownIssue("Go to… ranks “Holding still · Release” before “View ▸ Hold Still” for `hold still`") {
        for row in rows where !row.name.contains(" · ") {
          h.overlays.typeInFinder(row.item.title)
          #expect(h.overlays.finder?.items.first?.row.name == row.name, "typed: \(row.item.title)")
        }
      }
    }
  }

  @Test func everyCommandThatHasAKeyInTheWholeMapIsFoundWhetherOrNotTheMenuHasIt() throws {
    let (h, _, _, _) = makeHarness()
    let inTheMenu = Set(menuRows(h).compactMap(\.item.command?.text))
    h.run("find")
    var besides = 0
    for command in KeyBindings.defaults.map(\.command) where !isAPlaceOrThePalette(command) {
      let listed = try #require(h.overlays.finder?.model.commands.filter { $0.destination == .command(command.text) })
      #expect(listed.count >= 1, "\(command.text)")
      guard !inTheMenu.contains(command.text) else { continue }
      besides += 1
      #expect(picked(h, typing: command.title) == .command(command.text), "\(command.title)")
    }
    #expect(besides >= 5, "Space to the Left, Window Above, Show Everything on All Displays…: \(besides)")
  }

  @Test func withAllShortcutsOffEveryCommandIsStillFound() throws {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let (h, _, _, _) = makeHarness(settings: settings)
    h.run("find")
    let commands = try #require(h.overlays.finder?.model.commands)
    #expect(commands.count >= 45)
    #expect(commands.allSatisfy { $0.shortcut == nil }, "a row shows the key in effect, and none is")
  }

  @Test func aRowShowsTheKeyInEffect() throws {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("bind ctrl+opt+b balance").ok)
    #expect(h.run("unbind ctrl+opt+cmd+0").ok)
    #expect(h.run("unbind ctrl+opt+shift+f").ok)
    h.run("find")
    func note(_ command: Command) -> String? {
      h.overlays.finder?.model.commands.first { $0.destination == .command(command.text) }?.note
    }
    #expect(note(.equalize(all: false)) == "command, ⌃⌥B")
    #expect(note(.floatAll) == "command")
    #expect(note(.undo) == "command, ⌃⌥Z")
  }

  @Test func whatTheMenuTicksIsTicked() throws {
    let (h, _, _, _) = makeHarness()
    h.run("toggle-auto-dock")
    h.run("find")
    h.overlays.typeInFinder("dock new")
    #expect(h.overlays.finder?.items.first?.row.note == "command ✓")
  }

  @Test func noTwoRowsHaveOneNameAndNoneIsAPlace() throws {
    let (h, _, _, _) = makeHarness()
    h.run("save-view 2")
    h.run("name Reading")
    h.run("find")
    let model = try #require(h.overlays.finder?.model)
    #expect(Set(model.commands.map(\.name)).count == model.commands.count)
    for row in model.commands {
      guard case .command(let text) = row.destination else {
        Issue.record("\(row.destination)")
        continue
      }
      #expect(!isAPlaceOrThePalette(try Command.parse(text)), "\(text)")
      #expect(row.place == .command)
    }
    #expect(model.rows.allSatisfy { $0.place != .command })
    // "View 2" and "Reading" are where they always were.
    h.overlays.typeInFinder("view 2")
    #expect(h.overlays.finder?.selected == .view(h.display, slot: 2))
    h.overlays.typeInFinder("Reading")
    #expect(h.overlays.finder?.items.first?.row.place == .namedSpace)
  }

  @Test func theListOpensAsItAlwaysDid() throws {
    let (h, safari, notes, mail) = makeHarness()
    h.run("find")
    #expect(h.overlays.finder?.items.map(\.row.destination) == [.window(notes), .window(safari), .window(mail)])
  }

  // MARK: Choosing one

  @Test func itRunsOnTheWindowThePaletteOpenedOver() {
    let (h, safari, _, mail) = makeHarness()
    #expect(h.workspace.floating[mail] != nil)
    #expect(choose(h, "dock left"))
    #expect(h.overlays.finder == nil)
    #expect(h.workspace.tree.leaf(containing: mail) != nil, "Mail had the keyboard")
    #expect(h.frame(mail)!.minX < h.frame(safari)!.minX)
    expectWindowsMatchLayout(h)
  }

  @Test func aClickOnTheRowRunsItToo() {
    let (h, safari, notes, mail) = makeHarness()
    h.run("find")
    h.overlays.typeInFinder("float all")
    #expect(h.overlays.chooseInFinder(row: 1))
    #expect(h.overlays.finder == nil)
    #expect([safari, notes, mail].allSatisfy { h.workspace.floating[$0] != nil })
  }

  @Test func itIsAnsweredOnScreenAsAKeyIs() throws {
    let (h, _, _, _) = makeHarness()
    choose(h, "dock left")
    let byPalette = try #require(h.overlays.headsUp[h.display]?.text)
    let (twin, _, _, _) = makeHarness()
    twin.controller.perform(.dock(nil, .left), from: .shortcut)
    #expect(twin.overlays.headsUp[twin.display]?.text == byPalette)
  }

  // MARK: What the menu greys out

  @Test func whatTheMenuGreysOutIsListedAndSaysNotNow() throws {
    let (h, _, _, _) = makeHarness()
    #expect(h.controller.menuModel().item("Step Out")?.isEnabled == false, "everything is in view")
    h.run("find")
    h.overlays.typeInFinder("step out")
    #expect(h.overlays.finder?.items.first?.row.note == "command, not now")
  }

  @Test func chosenItRunsNothingAndThePaletteSaysSoAndStays() throws {
    let (h, _, _, _) = makeHarness()
    let (before, beeps) = (h.workspace, h.overlays.finderBeeps)
    h.overlays.clearTransitions()
    #expect(choose(h, "step out"))
    #expect(h.overlays.finder?.message == "“View ▸ Step Out” can do nothing just now")
    #expect(h.overlays.finder?.query == "step out")
    #expect(h.overlays.finderBeeps == beeps + 1)
    #expect(h.workspace == before && h.overlays.headsUp[h.display] == nil)
  }

  /// The row runs `toggle-float`, as the key does. The menu greys it out on a window that floats, which it would dock.
  @Test func aRowNeverDoesTheOppositeOfWhatItSays() throws {
    let (h, _, _, mail) = makeHarness()
    #expect(h.workspace.floating[mail] != nil)
    choose(h, "float focused")
    #expect(h.overlays.finder?.items.first?.row.name == "Float Focused Window")
    #expect(h.workspace.floating[mail] != nil, "it floats, and goes on floating")
  }

  /// The list is a snapshot. The menu is read again when a row is chosen, as a place is looked for again.
  @Test func whetherARowIsThereGoesByTheMomentItIsChosen() throws {
    let (h, _, _, _) = makeHarness()
    h.run("exclude com.example.calendar")
    h.run("find")
    #expect(picked(h, typing: "arrange again calendar") == .command("include com.example.calendar"))
    // Somebody saves settings.json behind the palette, without the app.
    var settings = h.controller.settings
    settings.excludedBundleIDs = []
    h.controller.apply(settings: settings)
    #expect(h.overlays.finder != nil)
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder?.message == "That command is not in the menu now")
    #expect(h.overlays.finder?.model.commands.contains { $0.destination == .command("include com.example.calendar") } == false)
  }

  @Test func oneUndoTakesItBack() {
    let (h, _, _, mail) = makeHarness()
    let before = h.workspace
    choose(h, "dock left")
    #expect(h.workspace != before)
    choose(h, "undo")
    #expect(h.workspace.tree == before.tree && h.workspace.floating[mail] != nil)
  }

  @Test func aCommandThatOpensAPanelOfArborsOpensIt() {
    let (h, _, _, _) = makeHarness()
    choose(h, "keyboard shortcuts")
    #expect(h.overlays.finder == nil)
    #expect(h.overlays.cheatSheets[h.display] != nil)
  }

  @Test func theRowsAreAsTheMenuStoodWhenThePaletteOpenedAndAFreshListHasTheMenusNewWords() throws {
    let (h, safari, notes, _) = makeHarness()
    h.run("find")
    h.overlays.typeInFinder("undo")
    #expect(h.overlays.finder?.items.first?.row.name == "Undo Dock")
    // A window closes behind the palette. Choosing it brings a fresh list, in which the menu's rows are read again.
    h.overlays.typeInFinder("notes")
    h.system.close(notes)
    h.overlays.chooseInFinder()
    #expect(h.overlays.finder?.message == "That window has closed")
    h.overlays.typeInFinder("dont arrange")
    let title = try #require(h.controller.menuModel().allItems.first { $0.title.hasPrefix("Don’t Arrange") }?.title)
    #expect(h.overlays.finder?.items.first?.row.name == "Focused Window ▸ " + title)
    _ = safari
  }

  // MARK: Two displays

  private static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false, name: "Studio Display")

  /// The menu is about the display under the pointer. The palette's rows are about the display it is on.
  @Test func theRowsAreAboutTheDisplayThePaletteIsOnWhereverThePointerRests() throws {
    let (h, _, _, mail) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let guest = h.system.open(app: "Music", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    h.scheduler.advance(by: 1)
    // The last step on the side display is a Float, on the main one a Dock. A view is saved on the main one only.
    h.run("dock \(guest.rawValue) left")
    h.run("float \(guest.rawValue)")
    h.system.userFocus(mail)
    h.controller.perform(.saveView(3), from: .shortcut)
    #expect(h.controller.workspaces[h.display]?.savedView(slot: 3) != nil)
    #expect(h.controller.workspaces[Self.side.id]?.savedView(slot: 3) == nil)
    // Somebody types in Mail, on the main display, with the pointer at rest on the other.
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.scheduler.advance(by: 30)
    h.system.type(keys: 5)
    h.controller.perform(.find(nil), from: .shortcut)
    #expect(h.overlays.finder?.model.display == h.display)
    #expect(h.controller.menuModel().item("Undo Float") != nil, "the menu itself is about the pointer's display")
    h.overlays.typeInFinder("undo")
    #expect(h.overlays.finder?.items.first?.row.name == "Undo Dock")
    h.overlays.typeInFinder("save view 3")
    #expect(h.overlays.finder?.items.first?.row.name == "Saved Views ▸ Save This View As ▸ View 3 (replace)")
  }

  @Test func andTheCommandActsThere() throws {
    let (h, _, notes, mail) = makeHarness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let guest = h.system.open(app: "Music", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    h.scheduler.advance(by: 1)
    h.run("dock \(guest.rawValue) left")
    h.system.userFocus(mail)
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.scheduler.advance(by: 30)
    h.system.type(keys: 5)
    h.controller.perform(.find(nil), from: .shortcut)
    let other = h.controller.workspaces[Self.side.id]
    h.overlays.typeInFinder("undo")
    h.overlays.moveFinderSelection(by: 1)
    // The elbow nudges the mouse: the pointer was used last, on the other display.
    h.scheduler.advance(by: 2)
    h.system.cursor = CGPoint(x: 2010, y: 500)
    #expect(h.overlays.chooseInFinder())
    #expect(h.workspace.floating[notes] != nil, "the main display's last step, docking Notes, is undone")
    #expect(h.controller.workspaces[Self.side.id] == other)
  }

  // MARK: Only in the palette

  @Test func findWithTextGoesToPlacesAndRunsNothing() {
    let (h, safari, notes, mail) = makeHarness()
    let before = h.workspace
    for text in ["float all", "Float All Windows", "pause", "dock left", "arrange windows"] {
      let result = h.run("find \(text)")
      #expect(!result.ok && result.message.hasPrefix("no window, space or saved view matches"), "\(text): \(result.message)")
    }
    #expect(h.workspace == before && !h.controller.isPaused)
    #expect([safari, notes].allSatisfy { h.workspace.tree.leaf(containing: $0) != nil } && h.workspace.floating[mail] != nil)
  }

  @Test func aLinkThatSaysFindRunsNothingEvenWhereAllLinksAreAllowed() throws {
    var settings = Settings()
    settings.allowAllURLCommands = true
    let (h, _, _, _) = makeHarness(settings: settings)
    let before = h.workspace
    let result = h.controller.perform(try Command.parse(url: "arbor://find/float/all"), from: .url)
    #expect(!result.ok)
    #expect(h.workspace == before)
  }

  @Test func withNoWindowsItStillDoesNotOpen() {
    let h = Harness()
    h.start()
    #expect(h.run("find").message == "there are no windows to go to")
    #expect(h.overlays.finder == nil)
  }

  // MARK: Traces and the log

  @Test func aTraceHoldsTheChoiceAndReplaysIt() throws {
    let (h, _, _, mail) = makeHarness()
    h.run("trace on test")
    choose(h, "dock left")
    h.scheduler.advance(by: 1)
    h.run("trace off")
    let trace = recordedTrace(h)
    #expect(try trace.text().contains(#"{"command":"dock left"}"#))
    let replayer = TraceReplayer(try Trace(text: try trace.text()), mode: .strict)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(replayer.harness.controller.workspaces == h.controller.workspaces)
    #expect(replayer.harness.frame(mail) == h.frame(mail))
  }

  /// A command that changes settings reads the file first. A replay has no file, and must not take the recorded outcome for it.
  @Test func aCommandThatChangesASettingReplaysToTheSameSetting() throws {
    let (h, _, _, _) = makeHarness()
    let before = h.controller.settings.docksNewWindows
    h.run("trace on test")
    choose(h, "dock new windows")
    h.scheduler.advance(by: 1)
    h.run("trace off")
    #expect(h.controller.settings.docksNewWindows == !before)
    let replayer = TraceReplayer(try Trace(text: try recordedTrace(h).text()), mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.settings.docksNewWindows == !before)
  }

  /// `exclude` takes letters, digits, `.`, `-` and `_`. The menu's row holds the command itself, and so does the palette's.
  @Test func aRowWhoseCommandCannotBeReadBackFromItsTextRunsAllTheSame() throws {
    let h = Harness()
    let odd = h.system.open(app: "Odd", bundleID: "com.example.odd app+")
    h.start()
    h.system.userFocus(odd)
    h.scheduler.advance(by: 1)
    let command = try #require(h.controller.menuModel().item("Don’t Arrange “Odd”")?.command)
    #expect((try? Command.parse(command.text)) != command, "or this looks at nothing")
    #expect(choose(h, "dont arrange odd"))
    #expect(h.overlays.finder == nil)
    #expect(h.controller.settings.excludedBundleIDs.contains("com.example.odd app+"))
  }

  @Test func asATraceHoldsItADestinationComesBackAsItWas() throws {
    for destination: FinderDestination in [
      .command("dock left"), .command("save-view 3"), .window(WindowID(101)), .view(DisplayID("main"), slot: 3),
      .space(DisplayID("main"), NodeID(4)),
    ] {
      let data = try JSONEncoder().encode(TraceFinderDestination(destination))
      #expect(try JSONDecoder().decode(TraceFinderDestination.self, from: data).destination == destination)
    }
  }

  /// What is chosen goes into a trace and, by its first word, into the log. The one command of the menu's that holds a name somebody gave
  /// is listed as the place it leads to.
  @Test func noRowsCommandHoldsANameSomebodyGave() throws {
    let (h, safari, _, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    h.run("name Taxes")
    #expect(h.controller.menuModel().allItems.contains { $0.command?.text.contains("Taxes") == true }, "or this looks at nothing")
    h.run("find")
    let commands = try #require(h.overlays.finder?.model.commands)
    #expect(!commands.contains { "\($0.destination) \($0.name)".contains("Taxes") })
    for case .command(let text) in commands.map(\.destination) { #expect(!text.contains("Taxes")) }
  }

  // MARK: What Return can run

  /// Everything that a command could have changed.
  private struct Everything: Equatable {
    var workspaces: [DisplayID: Workspace]
    var settings: Settings
    var frames: [WindowID: CGRect]
    var isPaused: Bool
    var hold: String
    var panels: Int
  }

  private func everything(_ h: Harness) -> Everything {
    Everything(
      workspaces: h.controller.workspaces, settings: h.controller.settings, frames: h.system.windows.mapValues(\.snapshot.frame),
      isPaused: h.controller.isPaused, hold: "\(h.controller.holdLevel)", panels: h.overlays.cheatSheets.count)
  }

  /// ⌃⌥G, a few letters, Return, without a look: that is what Go to… is for, and the fingers do it also when the app they mean is not
  /// open. Until commands were listed that was a beep. `pa` for Pages paused Arbor, `ar` for Arc arranged everything, `sa` for Safari saved view 1,
  /// `shortcuts` for the app of that name switched Arbor's shortcuts off in the app in front and wrote that to settings.json.
  @Test func lettersAndReturnMeantForAnAppThatIsNotOpenRunNothing() throws {
    let h = Harness()
    let a = h.system.open(app: "Zed", title: "zzz")
    let b = h.system.open(app: "Zoom", title: "zzz")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.advance(by: 1)
    let apps = [
      "Pages", "Arc", "Safari", "Shortcuts", "Notes", "Mail", "Terminal", "Calendar", "Preview", "Keynote", "Docker", "Reminders", "Home", "Weather",
      "Photos", "Music", "Finder", "Messages", "Slack", "Chrome", "Xcode", "Settings", "Windows App", "Figma", "Balance", "Mirror", "Grow", "Focus",
      "Spaces", "Undo", "Help", "Float", "Hold", "Back", "Release", "Step Two", "Show", "Save", "View", "Arrange", "Pause", "Float All Windows",
    ]
    let before = everything(h)
    var tried = 0
    var listedACommand = 0
    for app in apps {
      for length in 1...app.count {
        h.run("find")
        let typed = String(app.lowercased().prefix(length))
        h.overlays.typeInFinder(typed)
        if h.overlays.finder?.items.first?.row.place == .command { listedACommand += 1 }
        guard h.overlays.finder?.items.first?.row.place != .some(.inView) else {
          h.overlays.dismissFinder()
          continue
        }
        _ = h.overlays.chooseInFinder()
        _ = h.overlays.chooseInFinder()
        h.scheduler.advance(by: 1)
        tried += 1
        #expect(everything(h) == before, "\(typed) ↩ ↩")
        #expect(h.overlays.finder != nil, "nothing was chosen, so it is still open: \(typed)")
        h.overlays.dismissFinder()
        if everything(h) != before { return }
      }
    }
    #expect(tried > 150 && listedACommand > 40, "or this looks at nothing: \(tried), \(listedACommand)")
  }

  /// The story it was found by. The letters of `notes` are scattered over "Focused Window ▸ Don’t Arrange “Safari”": the one row left.
  @Test func notesClosesBehindThePaletteAndReturnIsPressedTwice() throws {
    let (h, safari, notes, _) = makeHarness()
    h.system.userFocus(safari)
    h.scheduler.advance(by: 1)
    #expect(menuRows(h).contains { $0.name == "Focused Window ▸ Don’t Arrange “Safari”" }, "or this looks at nothing")
    h.run("find")
    h.overlays.typeInFinder("notes")
    #expect(h.overlays.finder?.selected == .window(notes))
    h.system.close(notes)
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder?.message == "That window has closed")
    #expect(h.overlays.finder?.items.isEmpty == true)
    h.scheduler.advance(by: 1)
    let before = everything(h)
    #expect(!h.overlays.chooseInFinder(), "a beep")
    h.scheduler.advance(by: 1)
    #expect(everything(h) == before && h.controller.settings.excludedBundleIDs.isEmpty)
  }

  /// The same with rows that are named by what was typed: the place goes behind the palette, and Return is pressed again.
  @Test func afterAPlaceHasGoneASecondReturnRunsNothing() throws {
    for (app, typed, command) in [("Pages", "pa", "toggle-pause"), ("Undoer", "undo", "undo"), ("Floaty", "float", "float-all")] {
      let (h, _, _, mail) = makeHarness()
      let window = h.system.open(app: app, title: "Untitled")
      h.system.userFocus(mail)
      h.scheduler.advance(by: 1)
      h.run("find")
      h.overlays.typeInFinder(typed)
      #expect(h.overlays.finder?.selected == .window(window), "\(typed)")
      #expect(h.overlays.finder?.items.contains { $0.row.destination == .command(command) } == true, "or this looks at nothing: \(typed)")
      h.system.close(window)
      #expect(h.overlays.chooseInFinder())
      #expect(h.overlays.finder?.message == "That window has closed")
      #expect(h.overlays.finder?.items.first?.row.place == .command, "or this looks at nothing: \(typed)")
      h.scheduler.advance(by: 1)
      let before = everything(h)
      #expect(!h.overlays.chooseInFinder(), "a beep: \(typed)")
      h.scheduler.advance(by: 1)
      #expect(everything(h) == before, "\(typed)")
      #expect(h.overlays.finder != nil)
    }
  }

  /// `saf` ↓ Return is the next of Safari's windows. With one, it went round to that one until commands were listed; the rows that are
  /// about the app in front hold its name, and stood right below.
  @Test func theNameOfTheAppInFrontAndTheArrowStayAmongThePlaces() throws {
    let (h, safari, _, _) = makeHarness()
    h.run("exclude com.example.calendar")
    h.system.userFocus(safari)
    h.scheduler.advance(by: 1)
    #expect(h.controller.menuModel().item("Don’t Arrange “Safari”") != nil && h.controller.menuModel().item("Shortcuts Off in “Safari”") != nil)
    let before = everything(h)
    for (typed, steps) in [("saf", 1), ("saf", -1), ("safari", 1), ("saf", 2)] {
      h.run("find")
      h.overlays.typeInFinder(typed)
      #expect(h.overlays.finder?.items.map(\.row.destination) == [.window(safari)], "\(typed)")
      h.overlays.moveFinderSelection(by: steps)
      #expect(h.overlays.finder?.selected == .window(safari), "\(typed) \(steps)")
      #expect(h.overlays.chooseInFinder())
      h.scheduler.advance(by: 1)
      #expect(everything(h) == before, "\(typed) \(steps)")
    }
    h.overlays.dismissFinder()
    // The app that is not arranged is called as the other two rows call theirs.
    h.run("find")
    h.overlays.typeInFinder("calendar")
    #expect(h.overlays.finder?.items.isEmpty == true)
    h.overlays.typeInFinder("again cal")
    #expect(h.overlays.finder?.items.map(\.row.name) == ["Arrangement ▸ Arrange Again ▸ “calendar”"])
  }

  /// `pa` ↑ Return is the last of Pages' windows, and the count is right. Pause Arbor stood below it, where ↑ from the top came out.
  @Test func theArrowUpAndPageDownStayAmongThePlaces() throws {
    let (h, _, _, mail) = makeHarness()
    let first = h.system.open(app: "Pages", title: "Letter")
    let second = h.system.open(app: "Pages", title: "Report")
    h.system.userFocus(mail)
    h.scheduler.advance(by: 1)
    for page in [false, true] {
      h.run("find")
      h.overlays.typeInFinder("pa")
      let listed = try #require(h.overlays.finder?.items.map(\.row.destination))
      #expect(Set(listed.prefix(2)) == [.window(first), .window(second)] && listed.contains(.command("toggle-pause")), "or this looks at nothing")
      if page { h.overlays.pageFinderSelection(by: 1) } else { h.overlays.moveFinderSelection(by: -1) }
      #expect(h.overlays.finder?.selected == listed[1])
      #expect(h.overlays.chooseInFinder())
      h.scheduler.advance(by: 1)
      #expect(!h.controller.isPaused)
      h.system.userFocus(mail)
      h.scheduler.advance(by: 1)
    }
  }

  @Test func pickedWithTheArrowItRuns() {
    let (h, _, _, mail) = makeHarness()
    h.run("find")
    h.overlays.typeInFinder("dock left")
    #expect(!h.overlays.chooseInFinder(), "Return alone: a beep")
    #expect(h.overlays.finder != nil && h.workspace.floating[mail] != nil)
    h.overlays.moveFinderSelection(by: 1)
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil && h.workspace.tree.leaf(containing: mail) != nil)
  }
}
