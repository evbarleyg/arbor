import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The settings window without the window: a model on a real controller, with a window docked on the left,
/// and three apps "running".
@MainActor
private final class Panel {
  let h: Harness
  let a: WindowID
  let model: SettingsPanelModel
  var commands: [String] = []
  var redraws = 0

  init(settings: Settings = Settings()) {
    let h = Harness(settings: settings)
    self.h = h
    a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    final class Box { weak var panel: Panel? }
    let box = Box()
    model = SettingsPanelModel(
      controller: h.controller,
      runningApps: {
        [
          .init(bundleID: "com.example.safari", name: "Safari"), .init(bundleID: "com.example.mail", name: "Mail"),
          .init(bundleID: "com.example.notes", name: "notes"),
        ]
      },
      run: { command in
        box.panel?.commands.append(command.text)
        return h.controller.perform(command)
      })
    box.panel = self
    model.onChange = { [unowned self] in redraws += 1 }
  }

  var settings: Settings { h.controller.settings }
  var inset: CGFloat { h.frame(a)!.minX - h.visibleFrame.minX }

  func row(_ key: String, in section: SettingsSection) -> SettingsPanelModel.Row? {
    (model.rows(in: section) + model.advancedRows(in: section)).first { $0.key == key }
  }

  func shortcut(_ command: String) -> SettingsPanelModel.ShortcutRow? {
    model.shortcutRows.first { $0.command.text == command }
  }

  /// Presses keys as the window's event monitor reports them.
  @discardableResult func press(_ text: String) throws -> Bool {
    let chord = try KeyChord(text: text)
    return model.keyPressed(code: chord.key.code, modifiers: chord.modifiers)
  }
}

@Suite @MainActor struct SettingsPanelPaneTests {
  @Test func theSidebarHasTheSectionsWithSomethingToShowThenTheLists() {
    let p = Panel()
    let titles = p.model.panes.map(\.title)
    #expect(titles.first == "General")
    #expect(titles.suffix(2) == ["Shortcuts", "Rules"] && titles.contains("Apps"))
    // In the schema's order, and only those with a control to show.
    let sections = p.model.panes.compactMap { pane -> SettingsSection? in
      if case .section(let section) = pane { section } else { nil }
    }
    #expect(sections == SettingsSection.allCases.filter { sections.contains($0) })
    for section in sections where section != .general {
      #expect(!(p.model.rows(in: section) + p.model.advancedRows(in: section)).isEmpty, "\(section)")
    }
    for section in SettingsSection.allCases where !sections.contains(section) {
      #expect((p.model.rows(in: section) + p.model.advancedRows(in: section)).isEmpty, "\(section)")
    }
    #expect(Set(p.model.panes.map(\.id)).count == p.model.panes.count)
    #expect(p.model.panes.allSatisfy { !$0.symbol.isEmpty })
    #expect(p.model.pane == .section(.general))
  }

  @Test func everySettingIsShownOnceAtItsLevelAndHiddenOnesNowhere() {
    let p = Panel()
    var shown: [String: SettingEntry.Level] = [:]
    for section in SettingsSection.allCases {
      for row in p.model.rows(in: section) {
        #expect(shown.updateValue(.normal, forKey: row.key) == nil)
      }
      for row in p.model.advancedRows(in: section) {
        #expect(shown.updateValue(.advanced, forKey: row.key) == nil)
      }
    }
    for entry in SettingsSchema.entries {
      if SettingsPane.editing(entry) != nil {
        #expect(shown[entry.key] == nil, "\(entry.key) has a pane to itself")
      } else if entry.level == .advanced, !SettingsSchema.windowEntries(in: entry.section).contains(where: { $0.level == .normal }) {
        #expect(shown[entry.key] == .normal, "\(entry.key) has nothing to stand behind")
      } else {
        #expect(shown[entry.key] == (entry.level == .hidden ? nil : entry.level), "\(entry.key)")
      }
    }
  }

  @Test func aSectionWithOnlyAdvancedSettingsShowsThemAtOnce() throws {
    let p = Panel()
    // Whichever section that is today. (Settings land every day: no test here counts on a section's whole list.)
    let section = try #require(
      SettingsSection.allCases.first { section in
        let entries = SettingsSchema.windowEntries(in: section)
        return !entries.isEmpty && entries.allSatisfy { $0.level == .advanced }
      })
    #expect(p.model.rows(in: section).map(\.key) == SettingsSchema.windowEntries(in: section).map(\.key))
    #expect(p.model.advancedRows(in: section).isEmpty)
    // Windows has both kinds.
    #expect(p.model.advancedRows(in: .windows).contains { $0.key == "arrangeDesktopWeight" })
    #expect(!p.model.rows(in: .windows).contains { $0.key == "arrangeDesktopWeight" })
  }

  @Test func aRowSaysWhatToDraw() throws {
    var settings = Settings()
    settings.gap = 30
    let p = Panel(settings: settings)
    let gap = try #require(p.row("gap", in: .windows))
    #expect(gap.label == "Gap" && gap.help.hasPrefix("Space between docked windows") && gap.isChanged && gap.error == nil)
    #expect(gap.control == .number(value: 30, range: 0...100, step: 1, unit: "pt"))
    #expect(p.row("focusRing", in: .appearance)?.control == .toggle(isOn: true))
    #expect(p.row("focusRing", in: .appearance)?.isChanged == false)
    #expect(p.row("frameRectangleModifier", in: .gestures)?.control == .text(value: "ctrl+opt", example: "shift+cmd"))
  }

  @Test func advancedOpensSectionBySection() {
    let p = Panel()
    #expect(p.model.openAdvanced.isEmpty)
    p.model.setAdvanced(true, in: .dragging)
    #expect(p.model.openAdvanced == [.dragging] && p.redraws == 1)
    p.model.setAdvanced(false, in: .dragging)
    #expect(p.model.openAdvanced.isEmpty)
  }

  @Test func theFootSaysWhichArborThisIs() {
    let p = Panel()
    #expect(p.model.version == "Arbor dev")
    p.h.controller.buildInfo = BuildInfo(version: "1.0", build: "214", commit: "47a2ba9")
    #expect(p.model.version == "Arbor 1.0 (build 214, 47a2ba9)")
  }
}

@Suite @MainActor struct SettingsPanelChangeTests {
  @Test func everyChangeIsASetCommandThatAppliesAtOnce() {
    let p = Panel()
    p.model.set("gap", to: 30.4)  // a slider let go of between two steps
    p.model.set("focusRing", to: false)
    p.model.set("frameRectangleModifier", to: "Control + Option")
    #expect(p.commands == ["set gap 30", "set focusRing false", "set frameRectangleModifier Control + Option"])
    #expect(p.inset == 30)
    #expect(!p.settings.focusRing && p.settings.frameRectangleModifier == "ctrl+opt")
    #expect(p.row("gap", in: .windows)?.control == .number(value: 30, range: 0...100, step: 1, unit: "pt"))
    #expect(p.model.errors.isEmpty)
  }

  @Test func aRefusalIsShownOnItsRowUntilTheNextChangeThere() {
    let p = Panel()
    p.model.set("gap", to: "500")
    #expect(p.row("gap", in: .windows)?.error == "Must be from 0 to 100 pt, got 500")
    #expect(p.row("minimumUsableWidth", in: .windows)?.error == nil)
    #expect(p.settings.gap == 12 && p.inset == 12)
    p.model.set("gap", to: "wide")
    #expect(p.row("gap", in: .windows)?.error == "Needs a number from 0 to 100 pt, got “wide”")
    p.model.set("gap", to: "20")
    #expect(p.row("gap", in: .windows)?.error == nil && p.settings.gap == 20)
    p.model.set("gap", to: "500")
    p.model.pane = .section(.windows)
    #expect(p.model.errors.isEmpty, "a refusal does not outlive a visit to another pane")
  }

  /// A reply is written for a terminal, where the key has to be named and code is marked as code. Under the control it
  /// is about, the key is noise, and nothing draws a backtick as anything but a backtick.
  @Test func aRefusalIsSaidInTheWindowsWordsNotTheTerminals() {
    let p = Panel()
    for (key, value) in [("gap", "500"), ("gap", "wide"), ("focusRingColour", "mauve"), ("frameRectangleModifier", "hyper")] {
      p.model.set(key, to: value)
      let error = p.model.errors[key] ?? ""
      #expect(!error.isEmpty && !error.contains("`") && !error.contains(key), "\(key) \(value): \(error)")
      #expect(error.first?.isUppercase == true, "\(error)")
    }
  }

  /// One translator: what the line on screen does with a reply (`HeadsUpText`), the window does too.
  @Test func adviceForATerminalIsLeftOutAndCommandsAreCalledByTheirTitles() throws {
    let p = Panel()
    p.model.pane = .shortcuts
    p.model.startRecording(commandText: "frobnicate")
    #expect(p.model.errors[SettingsPanelModel.Pane.shortcuts.id] == "Unknown command “frobnicate”")
  }

  /// ⌃⌥` is written with the very sign that marks code.
  @Test func aBacktickThatIsAKeyStaysOne() {
    #expect(SettingsPanelModel.withoutCodeMarks("ctrl+opt+`: `state` is a query") == "ctrl+opt+`: “state” is a query")
    #expect(SettingsPanelModel.withoutCodeMarks("ctrl+opt+`: the same shortcut as ⌃⌥`") == "ctrl+opt+`: the same shortcut as ⌃⌥`")
    #expect(SettingsPanelModel.withoutCodeMarks("(`a` and `b`)") == "(“a” and “b”)")
    #expect(SettingsPanelModel.withoutCodeMarks("one ` alone") == "one ` alone")
  }

  @Test func changesMadeElsewhereShowUp() {
    let p = Panel()
    p.h.run("set gap 44")  // arborctl, a shortcut, or an edit to settings.json
    #expect(p.redraws == 1)
    #expect(p.row("gap", in: .windows)?.control == .number(value: 44, range: 0...100, step: 1, unit: "pt"))
    p.h.run("zoom \(p.a.rawValue)")
    #expect(p.redraws == 1, "nothing the window shows changed")
  }

  @Test(arguments: [
    (30.4, 0.0, 100.0, 1.0, 30.0), (30.5, 0, 100, 1, 31), (-5, 0, 100, 1, 0), (500, 0, 100, 1, 100),
    (0.30000000000000004, 0, 0.5, 0.05, 0.3), (0.32, 0, 0.5, 0.05, 0.3), (0.33, 0, 0.5, 0.05, 0.35),
    (0.07, 0.05, 2, 0.05, 0.05), (1.26, 1, 12, 0.5, 1.5), (2.9, 0.1, 3, 0.1, 2.9), (2.99, 0.1, 3, 0.1, 3),
    (38, 1, 1000, 10, 40), (3, 1, 1000, 10, 1), (6, 1, 1000, 10, 10), (999, 1, 1000, 10, 1000),
  ]) func slidersLandOnSteps(value: Double, low: Double, high: Double, step: Double, expected: Double) {
    #expect(SettingsPanelModel.snapped(value, in: low...high, step: step) == expected)
  }

  @Test func oddNumbersFromASliderAreHarmless() {
    #expect(SettingsPanelModel.snapped(.nan, in: 0...100, step: 1) == 0)
    #expect(SettingsPanelModel.snapped(.infinity, in: 0...100, step: 1) == 0)
    #expect(SettingsPanelModel.snapped(50, in: 0...100, step: 0) == 0)
    #expect(SettingsPanelModel.text(0.3) == "0.3" && SettingsPanelModel.text(12) == "12")
    let p = Panel()
    p.model.set("focusRing", to: 3.0)  // not a number: nothing to snap to
    p.model.set("nonsense", to: 3.0)
    #expect(p.commands.isEmpty)
  }

  /// 0.25 of what? A share of a whole is a number from 0 to 1 in settings.json, and so many per cent to a person.
  @Test func aShareOfTheWholeIsShownInPerCent() throws {
    let p = Panel()
    #expect(p.row("dimBehindArranged", in: .appearance)?.control == .number(value: 25, range: 0...100, step: 5, unit: "%"))
    #expect(p.row("windowEdgeFraction", in: .dragging)?.control == .number(value: 30, range: 0...50, step: 5, unit: "%"))
    // Not everything without a unit is one: this is so many times the width of the windows beside it.
    #expect(p.row("arrangeDesktopWeight", in: .windows)?.control == .number(value: 0.5, range: 0.1...3, step: 0.1, unit: ""))

    p.model.set("dimBehindArranged", to: 41.0)  // the slider
    #expect(p.commands.last == "set dimBehindArranged 0.4" && p.settings.dimBehindArranged == 0.4)
    p.model.set("dimBehindArranged", to: "55")  // the field
    #expect(p.commands.last == "set dimBehindArranged 0.55")
    #expect(p.row("dimBehindArranged", in: .appearance)?.control == .number(value: 55, range: 0...100, step: 5, unit: "%"))
    p.model.set("dimBehindArranged", to: " 7.5 % ")
    #expect(p.commands.last == "set dimBehindArranged 0.075")
    for odd in ["2 5", "5%5", "%", "1e400"] {
      p.model.set("dimBehindArranged", to: odd)
      #expect(p.model.errors["dimBehindArranged"]?.hasPrefix("Needs a number from 0 to 100 %") == true, "\(odd)")
    }
    p.model.set("dimBehindArranged", to: "7.5")

    // A refusal counts as the field does.
    let before = p.commands.count
    p.model.set("dimBehindArranged", to: "500")
    #expect(p.model.errors["dimBehindArranged"] == "Must be from 0 to 100 %, got 500")
    p.model.set("windowEdgeFraction", to: "60")
    #expect(p.model.errors["windowEdgeFraction"] == "Must be from 0 to 50 %, got 60")
    p.model.set("dimBehindArranged", to: "dark")
    #expect(p.model.errors["dimBehindArranged"] == "Needs a number from 0 to 100 %, got “dark”")
    #expect(p.commands.count == before && p.settings.dimBehindArranged == 0.075)
  }

  /// The help stands beside the field, and in docs/SETTINGS.md beside the file's numbers: it can name neither's.
  @Test func theHelpOfAShareNamesNoNumberButNought() {
    let p = Panel()
    for entry in SettingsSchema.entries where entry.level != .hidden {
      guard case .number(_, _, _, "%")? = p.model.row(for: entry)?.control else { continue }
      let words = entry.help.split { !($0.isLetter || $0.isNumber || $0 == ".") }
      #expect(!words.contains { Double($0) != nil && Double($0) != 0 }, "\(entry.key): \(entry.help)")
      #expect(!entry.help.contains("fraction"), "\(entry.key)")
    }
  }

  @Test func everySnappedValueOfEverySliderIsAccepted() {
    let p = Panel()
    for entry in SettingsSchema.entries {
      // As the slider counts.
      guard case .number(_, let range, let step, _)? = p.model.row(for: entry)?.control else { continue }
      var value = range.lowerBound
      while value <= range.upperBound + step {
        p.model.set(entry.key, to: value + step / 3)
        #expect(p.model.errors[entry.key] == nil, "\(entry.key) \(value)")
        value += max(step, (range.upperBound - range.lowerBound) / 25)
      }
    }
  }

  @Test func restoreDefaultsRestoresWhatTheSectionShows() {
    var settings = Settings()
    settings.focusRing = false  // normal
    settings.focusRingWidth = 6  // advanced
    settings.focusRingRadius = 10  // hidden
    settings.gap = 30  // another section
    let p = Panel(settings: settings)
    #expect(p.model.changedKeys(in: .appearance) == ["focusRing", "focusRingWidth"])
    p.model.restoreDefaults(in: .appearance)
    #expect(p.commands == ["reset focusRing", "reset focusRingWidth"])
    #expect(p.settings.focusRing && p.settings.focusRingWidth == 3)
    #expect(p.settings.focusRingRadius == 10 && p.settings.gap == 30)
    #expect(p.model.changedKeys(in: .appearance).isEmpty)
    p.model.restoreDefaults(in: .appearance)
    #expect(p.commands.count == 2)
    p.model.reset("gap")
    #expect(p.settings.gap == 12)
  }

  @Test func theLoginItemIsAskedNotRemembered() {
    let p = Panel()
    #expect(p.model.hasLoginItem && !p.model.opensAtLogin)
    p.model.setOpensAtLogin(true)
    #expect(p.commands == ["launch-at-login on"])
    #expect(p.h.loginItem.status == .enabled && p.model.opensAtLogin && p.model.errors["login"] == nil)
    p.h.loginItem.refuses = true
    p.model.setOpensAtLogin(false)
    #expect(p.model.opensAtLogin, "the switch shows what macOS has, not what was clicked")
    #expect(p.model.errors["login"] == "Arbor opens at login (macOS refused: operation not permitted)")
    // Switched off in System Settings behind Arbor's back: the switch is off, and switching it on says where to go.
    p.h.loginItem.status = .requiresApproval
    #expect(p.model.hasLoginItem && !p.model.opensAtLogin && p.model.loginItemNeedsApproval)
    p.model.setOpensAtLogin(true)
    #expect(p.model.errors["login"]?.contains("System Settings → General → Login Items") == true)
    p.h.loginItem.status = .disabled
    #expect(!p.model.loginItemNeedsApproval)
    // A copy that cannot be opened at login has no such line.
    p.h.loginItem.status = .unavailable("Arbor is not running from an app bundle")
    #expect(!p.model.hasLoginItem)
    p.h.controller.loginItem = nil
    #expect(!p.model.hasLoginItem)
  }
}

/// Fields hand over what was typed on Return and on losing the keyboard. The model sees to it that nothing typed is lost,
/// or lands in the wrong place, where no field is told anything.
@Suite @MainActor struct SettingsPanelDraftTests {
  @Test func whatIsTypedCountsOnlyWhenItIsHandedOver() {
    let p = Panel()
    p.model.type("3", into: .setting("gap"))
    p.model.type("30", into: .setting("gap"))
    #expect(p.commands.isEmpty && p.model.drafts == [.setting("gap"): "30"] && p.redraws == 2)
    p.model.handOver(.setting("gap"))
    #expect(p.commands == ["set gap 30"] && p.settings.gap == 30 && p.model.drafts.isEmpty)
    p.model.handOver(.setting("gap"))  // Return, and then the field loses the keyboard
    #expect(p.commands.count == 1)
  }

  @Test func typingWhatIsThereAlreadyRunsNothing() {
    let p = Panel()
    p.model.type("1", into: .setting("gap"))
    p.model.type("12", into: .setting("gap"))
    p.model.type("accent", into: .setting("focusRingColour"))
    p.model.handOverDrafts()
    #expect(p.commands.isEmpty && p.model.drafts.isEmpty)
  }

  @Test func aRefusalIsShownAndTheFieldGoesBackToTheSetting() {
    let p = Panel()
    p.model.type("500", into: .setting("gap"))
    p.model.handOver(.setting("gap"))
    #expect(p.settings.gap == 12 && p.model.drafts.isEmpty && p.model.errors["gap"] != nil)
  }

  @Test func closingTheWindowLeavingThePaneAndSearchingHandOverWhatWasTyped() {
    let p = Panel()
    p.model.go(to: .section(.windows))
    p.model.type("20", into: .setting("gap"))
    p.model.type("400", into: .setting("minimumUsableWidth"))
    p.model.handOverDrafts()  // what the window does as it closes
    #expect(p.settings.gap == 20 && p.settings.minimumUsableWidth == 400 && p.model.drafts.isEmpty)
    p.model.type("24", into: .setting("gap"))
    p.model.pane = .section(.appearance)  // a click in the sidebar, which does not take the keyboard
    #expect(p.settings.gap == 24 && p.model.drafts.isEmpty)
    p.model.type("#ff0000", into: .setting("focusRingColour"))
    p.model.search = "g"
    #expect(p.settings.focusRingColour.lowercased() == "#ff0000" && p.model.drafts.isEmpty)
  }

  @Test func theSliderAndRestoreOvertakeTheField() {
    let p = Panel()
    p.model.type("99", into: .setting("gap"))
    p.model.set("gap", to: 16.0)
    #expect(p.settings.gap == 16 && p.model.drafts.isEmpty)
    p.model.type("99", into: .setting("gap"))
    p.model.reset("gap")
    #expect(p.settings.gap == 12 && p.model.drafts.isEmpty)
    // The slider is taken hold of, and the field gives the keyboard up for it: nothing moves before the slider is let go of.
    p.model.type("99", into: .setting("gap"))
    p.model.forget(.setting("gap"))
    p.model.handOver(.setting("gap"))
    #expect(p.settings.gap == 12 && p.model.drafts.isEmpty && p.commands.last == "reset gap")
    // Restore Defaults is a button, which does not take the keyboard: what stands in a field of its pane goes with the rest.
    p.model.go(to: .section(.windows))
    p.model.set("gap", to: 16.0)
    p.model.type("99", into: .setting("gap"))
    p.model.restoreDefaults(in: .windows)
    #expect(p.settings.gap == 12 && p.model.drafts.isEmpty)
    p.model.handOverDrafts()
    #expect(p.settings.gap == 12)
  }

  /// Seen on a Mac: a field that has the keyboard says once more what stands in it after Return, also where that is what it was given to
  /// show after a refusal. Taken for typing, that stood in the field from then on, whatever became of the setting.
  @Test func whatAFieldWasGivenToShowIsNotTyping() {
    let p = Panel()
    p.model.type("12", into: .setting("gap"))
    #expect(p.model.drafts.isEmpty && p.redraws == 0)
    p.model.type("40", into: .setting("gap"))
    p.model.handOver(.setting("gap"))
    p.model.type("40", into: .setting("gap"))
    #expect(p.model.drafts.isEmpty && p.settings.gap == 40)
    p.model.type("500", into: .setting("gap"))
    p.model.handOver(.setting("gap"))
    p.model.type("40", into: .setting("gap"))
    #expect(p.model.drafts.isEmpty && p.settings.gap == 40 && p.model.errors["gap"] != nil)
    // Typed and taken back is not typing either.
    p.model.type("4", into: .setting("gap"))
    p.model.type("40", into: .setting("gap"))
    #expect(p.model.drafts.isEmpty)
    // As the window counts: a share stands in its field in per cent.
    p.model.type("25", into: .setting("dimBehindArranged"))
    #expect(p.model.drafts.isEmpty)
    p.model.type("0.25", into: .setting("dimBehindArranged"))
    #expect(p.model.drafts == [.setting("dimBehindArranged"): "0.25"])
    p.model.handOverDrafts()
    #expect(p.settings.dimBehindArranged == 0.0025)
    let q = rules()
    q.model.type("Inbox", into: q.model.ruleRows[0].titleField)
    q.model.type("", into: q.model.ruleRows[1].titleField)
    #expect(q.model.drafts.isEmpty && q.redraws == 0)
  }

  @Test func closingAdvancedHandsOverWhatWasTypedBehindIt() {
    let p = Panel()
    p.model.go(to: .section(.windows))
    p.model.setAdvanced(true, in: .windows)
    p.model.type("77", into: .setting("resizeStep"))
    p.model.setAdvanced(false, in: .windows)  // a click on the word, which does not take the keyboard
    #expect(p.settings.resizeStep == 77 && p.model.drafts.isEmpty)
  }

  @Test func replacingTheFileWithTheDefaultsTakesWhatStandsInAFieldAlong() {
    let p = Panel()
    p.model.type("99", into: .setting("gap"))
    p.model.replaceFileWithDefaults()
    p.model.answer(yes: true)
    #expect(p.model.drafts.isEmpty)
    p.model.handOverDrafts()
    #expect(p.settings.gap == 12)
  }

  /// "Inbox " is "Inbox": nothing is run, and the field goes back to what is so.
  @Test func aTitleThatComesToTheSameIsForgottenAndTheLineDrawnAgain() {
    let p = rules()
    p.model.type("Inbox ", into: p.model.ruleRows[0].titleField)
    let drawn = p.redraws
    #expect(!p.model.handOver(p.model.ruleRows[0].titleField))
    #expect(p.commands.isEmpty && p.model.drafts.isEmpty && p.redraws > drawn)
  }

  /// A field keeps the keyboard after its own Return and gives it up when its number changes by another hand, so it asks.
  @Test func handingOverSaysWhetherItChangedAnything() {
    let p = Panel()
    #expect(!p.model.handOver(.setting("gap")), "nothing was typed")
    p.model.type("30", into: .setting("gap"))
    #expect(p.model.handOver(.setting("gap")) && p.settings.gap == 30)
    p.model.type("500", into: .setting("gap"))
    #expect(!p.model.handOver(.setting("gap")), "refused")
    p.model.type("30.0", into: .setting("gap"))
    #expect(!p.model.handOver(.setting("gap")), "the same number")
    let q = rules()
    q.model.type("Sent", into: q.model.ruleRows[0].titleField)
    #expect(q.model.handOver(q.model.ruleRows[0].titleField) && q.settings.rules[0].title == "Sent")
  }

  /// Whoever changed a setting last is right. What stood in its field half typed was typed over another value: it would hide the
  /// new one, and undo it as the window closes.
  @Test func aChangeFromOutsideOvertakesTheField() {
    let p = Panel()
    p.model.type("99", into: .setting("gap"))
    p.model.type("300", into: .setting("minimumUsableWidth"))
    p.h.run("set gap 20")  // arborctl, a shortcut, or an edit to settings.json
    #expect(p.model.drafts == [.setting("minimumUsableWidth"): "300"], "the other field is about something else")
    p.model.handOverDrafts()
    #expect(p.settings.gap == 20 && p.settings.minimumUsableWidth == 300)
    // A switch of the window is clicked meanwhile, which does not take the keyboard: nothing to do with the field.
    p.model.type("30", into: .setting("gap"))
    p.model.set("makeRoom", to: false)
    #expect(p.model.drafts == [.setting("gap"): "30"])
  }

  private func rules() -> Panel {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.left)), AppRule(app: "com.apple.finder", action: .ignore),
    ]
    return Panel(settings: settings)
  }

  @Test func aTitleIsHandedOverBeforeAnythingElseIsDoneToTheRules() {
    for act: (SettingsPanelModel) -> Void in [
      { $0.setKind(.float, of: $0.ruleRows[1]) }, { $0.moveRule($0.ruleRows[1], by: -1) },
      { $0.removeRule($0.ruleRows[0]) }, { $0.addRule(app: "com.example.notes") },
    ] {
      let p = rules()
      p.model.type("Downloads", into: p.model.ruleRows[1].titleField)
      act(p.model)
      #expect(p.model.drafts.isEmpty)
      #expect(p.settings.rules.first { $0.app == "com.apple.finder" }?.title == "Downloads", "\(p.commands)")
      #expect(p.settings.rules.filter { $0.title == "Downloads" }.count == 1)
    }
  }

  @Test func whatWasTypedForARuleThatIsGoneIsDropped() {
    let p = rules()
    p.model.type("Downloads", into: p.model.ruleRows[1].titleField)
    p.model.removeRule(p.model.ruleRows[1])
    #expect(p.commands == ["rule remove 2"] && p.model.drafts.isEmpty)
    // Another rule has come to its place behind the window's back.
    let q = rules()
    q.model.type("Sent", into: q.model.ruleRows[0].titleField)
    q.h.run("rule move 1 2")
    #expect(q.model.drafts[q.model.ruleRows[0].titleField] == nil, "the line that is there now shows its own title")
    q.model.handOverDrafts()
    #expect(q.commands.isEmpty && q.model.drafts.isEmpty && !q.settings.rules.contains { $0.title == "Sent" })
  }
}

@Suite @MainActor struct SettingsPanelSearchTests {
  @Test func aSearchFindsSettingsInEverySectionAdvancedOnesToo() {
    let p = Panel()
    #expect(!p.model.isSearching)
    p.model.search = "edge"
    #expect(p.model.isSearching && p.redraws == 1)
    let found = p.model.found
    func keys(in section: SettingsSection) -> [String] {
      found.sections.first { $0.section == section }?.rows.map(\.key) ?? []
    }
    #expect(keys(in: .windows).contains("gap"))  // "…and the screen edges"
    #expect(keys(in: .dragging).suffix(2) == ["screenEdgeBand", "windowEdgeFraction"])  // both advanced
    // What is found stands as it stands in its pane.
    for section in found.sections.map(\.section) {
      #expect(keys(in: section) == SettingsSchema.entries(in: section).map(\.key).filter { keys(in: section).contains($0) })
    }
    // In the order of the panes, and nothing that does not say the word.
    let order = found.sections.compactMap { SettingsSection.allCases.firstIndex(of: $0.section) }
    #expect(order == order.sorted())
    for row in found.sections.flatMap(\.rows) {
      var words = "\(row.key) \(row.label) \(row.help)"
      if case .choice(_, let choices) = row.control { words += choices.map(\.label).joined(separator: " ") }
      #expect(words.lowercased().contains("edge"), "\(row.key)")
    }
  }

  /// Seen in the window: "ring" also found the setting that holds still "during a call".
  @Test func aSearchBeginsAWordAndDoesNotEndOne() {
    let p = Panel()
    p.model.search = "ring"
    #expect(p.model.found.sections.flatMap(\.rows).map(\.key) == ["focusRing", "focusRingWidth", "focusRingColour"])
    p.model.search = "dock"
    #expect(p.model.found.sections.flatMap(\.rows).contains { $0.key == "dimBehindArranged" }, "“docked” begins so")
    // A key's words run together, and whoever types part of one knows it.
    p.model.search = "behindarr"
    #expect(p.model.found.sections.flatMap(\.rows).map(\.key).contains("dimBehindArranged"))
    // One field, one rule: the lines of the Shortcuts pane and the panes themselves are found the same way.
    p.model.search = "thing"
    #expect(p.model.found.shortcuts.isEmpty, "not Show Everything")
    p.model.search = "every"
    #expect(p.model.found.shortcuts.map(\.title) == ["Show Everything"])
    p.model.search = "cuts"
    #expect(p.model.found.panes.isEmpty, "not Shortcuts")
    p.model.search = "short"
    #expect(p.model.found.panes.contains(.shortcuts))
  }

  @Test func hiddenSettingsAreNotFound() {
    let p = Panel()
    p.model.search = "focus ring"
    let found = p.model.found.sections.flatMap(\.rows).map(\.key)
    #expect(found.starts(with: ["focusRing", "focusRingWidth", "focusRingColour"]) && !found.contains("focusRingRadius"))
    p.model.search = "focusRingRadius"
    #expect(p.model.found.isEmpty)
  }

  @Test func theListsAreFoundAsPanesToGoTo() {
    let p = Panel()
    p.model.search = "your shortcuts"
    #expect(p.model.found.panes == [.shortcuts])
    p.model.search = "shortcuts"
    #expect(p.model.found.panes == [.shortcuts])
    #expect(p.model.found.sections.flatMap(\.rows).map(\.key).contains("hotkeysEnabled"))
    p.model.search = "rul"
    #expect(p.model.found.panes == [.rules])
    p.model.go(to: .rules)
    #expect(p.model.pane == .rules && p.model.search.isEmpty && !p.model.isSearching)
    // A list of apps is a line like any other, found where it stands.
    p.model.search = " don't arrange "
    #expect(p.model.found.panes.isEmpty && p.model.found.sections.map(\.section) == [.apps])
    #expect(p.model.found.sections.first?.rows.map(\.key) == ["excludedBundleIDs"])
  }

  @Test func shortcutsAreFoundByCommandAndByKeys() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.search = "desktop"
    #expect(p.model.found.shortcuts.map(\.command.text) == ["desktop"])
    p.model.search = "⌃⌥d"
    #expect(p.model.found.shortcuts.map(\.command.text) == ["desktop"])
    p.model.search = "ctrl+opt+cmd"
    #expect(
      p.model.found.shortcuts.map(\.command.text) == ["dock left", "dock right", "dock top", "dock bottom", "grow", "shrink", "balance"])
    p.model.search = "dock left"
    #expect(p.model.found.shortcuts.map(\.command.text) == ["dock left"])
    // A line found works like the line in its pane.
    p.model.startRecording(try #require(p.model.found.shortcuts.first))
    try p.press("ctrl+opt+x")
    #expect(p.commands == ["bind ctrl+opt+x dock left", "unbind ctrl+opt+cmd+left"])
    #expect(p.model.found.shortcuts.first?.label == "⌃⌥X")
    p.model.search = "gap"
    #expect(p.model.found.shortcuts.isEmpty)
    // By what the line says, which is what the menu calls it.
    p.model.search = "step out"
    #expect(p.model.found.shortcuts.map(\.command.text) == ["out"])
    p.model.search = "everything"
    #expect(p.model.found.shortcuts.map(\.command.text) == ["show-all", "home"])
  }

  @Test func nothingFoundIsNothingFound() {
    let p = Panel()
    p.model.search = "volume"
    #expect(p.model.found.isEmpty)
    // One kind of find is enough not to say so.
    p.model.search = "smallest usable"
    #expect(!p.model.found.isEmpty && p.model.found.panes.isEmpty && p.model.found.shortcuts.isEmpty)
    p.model.search = "rules are checked"
    #expect(!p.model.found.isEmpty && p.model.found.sections.isEmpty && p.model.found.shortcuts.isEmpty)
    p.model.search = "toggle-float"
    #expect(!p.model.found.isEmpty && p.model.found.sections.isEmpty && p.model.found.panes.isEmpty)
    p.model.search = "   "
    #expect(!p.model.isSearching)
  }

  @Test func aFoundRowWorksLikeAnyOther() {
    let p = Panel()
    p.model.search = "gap"
    p.model.set("gap", to: "500")
    #expect(p.model.found.sections.first?.rows.first?.error != nil)
    p.model.set("gap", to: "20")
    #expect(p.model.found.sections.first?.rows.first?.control == .number(value: 20, range: 0...100, step: 1, unit: "pt"))
  }
}

@Suite @MainActor struct SettingsPanelFileTests {
  @Test func aFileThatCannotBeReadIsSaidAboveEverythingAndCanBeReplaced() {
    let p = Panel()
    var broken = true
    p.h.controller.loadSettings = {
      if broken { throw Settings.FileError("line 3, column 1: expected a key") }
      return Settings()
    }
    p.h.controller.replaceSettingsFile = { _ in
      broken = false
      return "settings.unreadable.json"
    }
    #expect(p.model.fileProblem == nil)
    p.h.controller.takeInSettingsFile()
    #expect(p.model.fileProblem == "line 3, column 1: expected a key")
    #expect(p.redraws == 1, "the window hears of it by itself")
    p.model.set("gap", to: "30")
    // The banner above has the reason and the two ways out, as buttons.
    #expect(p.row("gap", in: .windows)?.error == "Nothing was changed: settings.json cannot be read")
    // Not at one click.
    p.model.replaceFileWithDefaults()
    #expect(p.model.question == .replaceFile && p.commands.last != "reset everything")
    p.model.answer(yes: false)
    #expect(p.model.question == nil && p.model.fileProblem != nil && broken)
    p.model.replaceFileWithDefaults()
    p.model.answer(yes: true)
    #expect(p.model.question == nil && p.commands.last == "reset everything")
    #expect(p.model.fileProblem == nil && !broken)
    #expect(p.model.errors.isEmpty, "what was refused because of the file is not held against the file that replaced it")
    p.h.controller.loadSettings = nil
    p.model.set("gap", to: "30")
    #expect(p.settings.gap == 30)
  }

  /// The window is made when it is first opened, which may well be because Arbor beeped at the file.
  @Test func aWindowOpenedOnABrokenFileForgetsItsRefusalsToo() {
    let early = Panel()
    var broken = true
    early.h.controller.loadSettings = {
      if broken { throw Settings.FileError("line 3, column 1: expected `,` or `}` after the value of `gap`, found `rules`") }
      return Settings()
    }
    early.h.controller.takeInSettingsFile()
    let model = SettingsPanelModel(controller: early.h.controller) { early.h.controller.perform($0) }
    #expect(model.fileProblem == "line 3, column 1: expected “,” or “}” after the value of “gap”, found “rules”", "no code marks")
    model.set("gap", to: "30")
    #expect(model.errors["gap"] == "Nothing was changed: settings.json cannot be read")
    model.set("minimumUsableWidth", to: "-4")
    broken = false
    early.h.controller.takeInSettingsFile()
    #expect(model.fileProblem == nil && model.errors.isEmpty)
  }

  @Test func valuesThatCouldNotBeUsedAreListed() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": -500}"#.utf8))
    #expect(Panel(settings: settings).model.valueProblems == ["gap: -500 is outside 0 to 100 pt; using 0"])
    let mauve = try JSONDecoder().decode(Settings.self, from: Data(#"{"focusRingColour": "mauve"}"#.utf8))
    #expect(
      Panel(settings: mauve).model.valueProblems == ["focusRingColour: “mauve” is not accent, #RRGGBB or #RRGGBBAA; using the default, accent"])
    let perDisplay = try JSONDecoder().decode(Settings.self, from: Data(#"{"displays": {"main": {"gap": 4}}}"#.utf8))
    #expect(Panel(settings: perDisplay).model.valueProblems == ["displays: “displays” must be a list of entries; none were loaded"])
  }
}

@Suite @MainActor struct SettingsPanelShortcutTests {
  /// What ships. The tests below that need a line only the whole map has (`desktop`, mostly) ask for that map.
  @Test func asItShipsThePageHasTheNineAndTheChoiceAboveThem() throws {
    let p = Panel()
    #expect(p.model.shortcutRows.map(\.command) == KeyBindings.core.map(\.command))
    #expect(p.model.shortcutRows.compactMap(\.chord) == KeyBindings.core.map(\.chord))
    #expect(p.model.shortcutRows.allSatisfy { $0.chord == $0.standard && !$0.isChanged })
    guard case .choice(let value, let choices)? = p.model.shortcutsMapRow?.control else {
      throw Settings.FileError("no such line")
    }
    #expect(value == "core" && choices.map(\.value) == ["core", "all"])
    // It decides the lines under it, at once.
    p.model.set("shortcuts", to: "all")
    #expect(p.commands == ["set shortcuts all"] && p.model.errors.isEmpty)
    #expect(p.model.shortcutRows.map(\.command) == KeyBindings.all.map(\.command))
    #expect(p.model.shortcutRows.compactMap(\.chord) == KeyBindings.all.map(\.chord))
    #expect(p.model.shortcutRows.allSatisfy { $0.chord == $0.standard && !$0.isChanged })
  }

  @Test func theTableHasEveryDefaultInOrderThenTheUsersOwn() {
    var settings = Settings.withEveryKey
    settings.bindings = ["ctrl+opt+x": "float-all", "ctrl+opt+cmd+h": "dock left"]
    let p = Panel(settings: settings)
    let rows = p.model.shortcutRows
    #expect(rows.prefix(KeyBindings.all.count).map(\.command) == KeyBindings.all.map(\.command))
    #expect(rows.prefix(KeyBindings.all.count).allSatisfy { $0.chord == $0.standard && !$0.isChanged })
    #expect(rows.suffix(2).map(\.command.text) == ["dock left", "float-all"])
    #expect(rows.suffix(2).allSatisfy { $0.standard == nil && $0.isChanged })
    #expect(Set(rows.map(\.id)).count == rows.count)
    #expect(p.model.shortcutsAreChanged && !Panel().model.shortcutsAreChanged)
  }

  /// `out`, `in` and `neighbor left` are what a script types. A person knows them from the menu and the panel of shortcuts.
  @Test func aLineIsCalledWhatTheMenuCallsIt() throws {
    let p = Panel(settings: .withEveryKey)
    #expect(p.shortcut("out")?.title == "Step Out" && p.shortcut("show-all")?.title == "Show Everything")
    #expect(p.shortcut("toggle-float")?.title == "Float or Dock Focused Window")
    for row in p.model.shortcutRows {
      #expect(row.command.listedTitle != nil, "\(row.command.text) has only the title made from its text")
    }
    // One of the user's own, for a command nobody chose a title for, still says what runs.
    p.h.run("bind ctrl+opt+x set gap 0")
    #expect(p.shortcut("set gap 0")?.title == "Set Gap 0")
  }

  /// Fifty lines in a row are a wall. The panel of shortcuts and docs/KEYBOARD.md have three groups.
  @Test func theLinesStandInTheGroupsOfThePanelOfShortcuts() throws {
    let p = Panel(settings: .withEveryKey)
    #expect(p.model.shortcutSections.map(\.title) == ["Look", "Arrange", "Arbor itself"])
    #expect(p.model.shortcutSections.flatMap(\.rows).map(\.id).sorted() == p.model.shortcutRows.map(\.id).sorted(), "each once")
    let look = try #require(p.model.shortcutSections.first)
    #expect(look.rows.prefix(3).map(\.title) == ["Show Everything", "Step Out", "Step In"], "in the table's order")
    #expect(look.rows.allSatisfy { $0.command.group == .look })
    // The user's own have a group to themselves, whatever they run: that is where one looks for them.
    p.h.run("bind ctrl+opt+x set gap 0")
    p.h.run("bind ctrl+opt+y desktop")
    #expect(p.model.shortcutSections.map(\.title) == ["Look", "Arrange", "Arbor itself", "Your own"])
    #expect(p.model.shortcutSections.last?.rows.map(\.command.text) == ["desktop", "set gap 0"])
  }

  @Test func aShortcutThatTakesKeysFromEveryAppSaysSoOnItsLine() throws {
    let p = Panel(settings: .withEveryKey)
    #expect(p.model.shortcutRows.allSatisfy { $0.caution == nil }, "no default needs a warning")
    p.model.startRecording(try #require(p.shortcut("show-all")))
    try p.press("cmd+w")
    #expect(p.shortcut("show-all")?.caution == "no app gets ⌘W while Arbor runs")
  }

  @Test func whateverIsRecordedIsRegisteredOnTheKeyThatWasPressed() {
    let modifierSets: [KeyChord.Modifiers] = [
      [.control, .option], [.control, .option, .shift], [.control, .option, .command], [.command], [.command, .shift],
    ]
    for (name, layout) in SampleKeyLayouts.byName {
      for code in UInt32(0)..<128 {
        for modifiers in modifierSets {
          guard let chord = KeyChord(code: code, modifiers: modifiers, layout: layout) else { continue }
          #expect(chord.code(in: layout) == code && chord.modifiers == modifiers, "\(name) \(code): \(chord.text)")
          // And it survives being written into settings.json.
          #expect((try? KeyChord(text: chord.text)) == chord, "\(name) \(code): \(chord.text)")
        }
      }
      // Every key of the four rows can be recorded, whatever it types.
      for code in SampleKeyLayouts.rows.joined() {
        #expect(KeyChord(code: code, modifiers: [.control, .option], layout: layout) != nil, "\(name) \(code)")
      }
      // Pressing a default shortcut as it is registered gives that shortcut back under its own name.
      for binding in KeyBindings.effective(settings: .withEveryKey, layout: layout).bindings {
        let recorded = KeyChord(code: binding.keyCode, modifiers: binding.modifiers, layout: layout)
        #expect(recorded == binding.chord, "\(name): \(binding.chord.text) came back as \(recorded?.text ?? "nothing")")
      }
    }
  }

  @Test func aDefaultShortcutRecordedAgainLeavesNothingChanged() throws {
    for (name, layout) in SampleKeyLayouts.byName {
      let p = Panel(settings: .withEveryKey)
      p.h.controller.keyboardLayoutChanged(layout)
      for binding in p.h.controller.effectiveBindings.bindings {
        let row = try #require(p.model.shortcutRows.first { $0.standard == binding.chord })
        p.model.startRecording(row)
        try p.press("ctrl+opt+shift+f9")
        p.model.startRecording(try #require(p.model.shortcutRows.first { $0.standard == binding.chord }))
        #expect(p.model.keyPressed(code: binding.keyCode, modifiers: binding.modifiers))
        let after = try #require(p.model.shortcutRows.first { $0.standard == binding.chord })
        #expect(!after.isChanged && p.model.clash == nil, "\(name): \(binding.chord.text) is now \(after.chord?.text ?? "nothing")")
      }
      #expect(p.settings.bindings.isEmpty, "\(name): \(p.settings.bindings)")
    }
  }

  @Test func aKeyIsCalledWhatItTypes() {
    let german = SampleKeyLayouts.german
    let base: KeyChord.Modifiers = [.control, .option]
    #expect(KeyChord(code: 6, modifiers: base, layout: german)?.text == "ctrl+opt+y")  // left of X
    #expect(KeyChord(code: 16, modifiers: base, layout: german)?.text == "ctrl+opt+z")
    #expect(KeyChord(code: 33, modifiers: base, layout: german)?.text == "ctrl+opt+[")  // Ü, where a US keyboard has [
    #expect(KeyChord(code: 33, modifiers: base, layout: german)?.label(in: german) == "⌃⌥Ü")
    #expect(KeyChord(code: 27, modifiers: [.control, .option, .shift], layout: german)?.text == "ctrl+opt+shift+/")  // ⇧ß types ?
    // - is beside the right ⇧ in Germany, so the key that has it on a US keyboard needs saying so.
    #expect(KeyChord(code: 27, modifiers: base, layout: german)?.text == "ctrl+opt+us:-")
    #expect(KeyChord(code: 12, modifiers: base, layout: SampleKeyLayouts.french)?.text == "ctrl+opt+a")
    #expect(KeyChord(code: 49, modifiers: base, layout: german)?.text == "ctrl+opt+space")
  }

  @Test func theTableAndTheRecorderFollowTheKeyboardLayout() throws {
    let p = Panel(settings: .withEveryKey)
    p.h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(p.shortcut("back")?.label == "⌃⌥Ü" && p.shortcut("back")?.isChanged == false)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    #expect(p.model.keyPressed(code: 6, modifiers: [.control, .option]))  // the key labelled Y
    #expect(p.commands == ["bind ctrl+opt+y desktop", "unbind ctrl+opt+d"])
    #expect(p.shortcut("desktop")?.label == "⌃⌥Y")
    // With the setting off, keys go by their place on a US keyboard.
    p.h.run("set shortcutsFollowLayout false")
    // ⌃⌥Z is Undo's by default (F19): free here, so that the recorder has nothing to ask.
    p.h.run("unbind ctrl+opt+z")
    p.model.startRecording(try #require(p.shortcut("desktop")))
    #expect(p.model.keyPressed(code: 6, modifiers: [.control, .option]))
    #expect(p.commands.suffix(2) == ["bind ctrl+opt+z desktop", "unbind ctrl+opt+y"])
  }

  @Test func twoNamesForOneKeyClash() throws {
    var settings = Settings.withEveryKey
    settings.bindings = ["ctrl+opt+us:z": "float-all"]  // the key labelled Y in Germany
    let p = Panel(settings: settings)
    p.h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    #expect(p.model.keyPressed(code: 6, modifiers: [.control, .option]))
    let clash = try #require(p.model.clash)
    #expect(clash.holder == .floatAll && clash.chord.text == "ctrl+opt+y" && clash.label == "⌃⌥Y")
    p.model.replaceHolder()
    #expect(p.commands == ["bind ctrl+opt+y desktop", "unbind ctrl+opt+us:z", "unbind ctrl+opt+d"])
    #expect(p.h.controller.effectiveBindings.problems.isEmpty)
    #expect(p.h.controller.effectiveBindings.bindings.filter { $0.keyCode == 6 }.map(\.command) == [.desktop])
  }

  @Test func arborHoldsNoShortcutWhileOneIsRecorded() throws {
    let p = Panel(settings: .withEveryKey)
    var changes: [Controller.Change] = []
    p.h.controller.observe { changes.append($0) }
    #expect(!p.h.controller.activeBindings.isEmpty)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    #expect(p.h.controller.activeBindings.isEmpty && changes == [.input], "or pressing one would run it")
    p.model.cancelRecording()
    #expect(!p.h.controller.activeBindings.isEmpty && changes == [.input, .input])
    // However the recording ends.
    p.model.startRecording(try #require(p.shortcut("desktop")))
    try p.press("ctrl+opt+x")
    #expect(p.h.controller.activeBindings.contains { $0.chord.text == "ctrl+opt+x" })
    p.model.startRecording(try #require(p.shortcut("desktop")))
    p.model.pane = .rules
    #expect(!p.h.controller.isRecordingShortcut)
  }

  @Test func recordingGivesACommandNewKeysOnTheSameLine() throws {
    let p = Panel(settings: .withEveryKey)
    var recordings: [Bool] = []
    p.model.onRecordingChanged = { recordings.append($0) }
    let row = try #require(p.shortcut("desktop"))
    p.model.startRecording(row)
    #expect(p.model.recording == row && recordings == [true])
    #expect(try p.press("ctrl+opt+y"))
    #expect(p.model.recording == nil && recordings == [true, false])
    #expect(p.commands == ["bind ctrl+opt+y desktop", "unbind ctrl+opt+d"])
    let after = try #require(p.shortcut("desktop"))
    #expect(after.chord?.text == "ctrl+opt+y" && after.standard?.text == "ctrl+opt+d" && after.isChanged)
    #expect(after.id == row.id, "the line stays where it was")
    #expect(p.model.shortcutRows.count == KeyBindings.all.count)
  }

  @Test func keysPressedWhenNothingIsRecordingAreNotTheWindowsBusiness() throws {
    let p = Panel()
    #expect(try !p.press("ctrl+opt+y"))
    #expect(p.commands.isEmpty)
  }

  @Test func escapeAloneCancels() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    #expect(p.redraws == 1, "the button asks for keys")
    #expect(try p.press("escape"))
    #expect(p.model.recording == nil && p.commands.isEmpty)
    #expect(p.redraws == 2, "and shows the old ones again")
    // With modifiers it is a shortcut like any other.
    p.model.startRecording(try #require(p.shortcut("desktop")))
    try p.press("ctrl+opt+shift+escape")
    #expect(p.shortcut("desktop")?.chord?.text == "ctrl+opt+shift+escape")
  }

  @Test func theSameKeysAgainChangeNothing() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    try p.press("ctrl+opt+d")
    #expect(p.model.recording == nil && p.commands.isEmpty && p.model.clash == nil)
  }

  @Test func keysAnotherCommandHasAreFlaggedAndTakenOnlyOnRequest() throws {
    let p = Panel(settings: .withEveryKey)
    let row = try #require(p.shortcut("desktop"))
    p.model.startRecording(row)
    try p.press("ctrl+opt+r")
    let clash = try #require(p.model.clash)
    #expect(clash.row == row && clash.chord.text == "ctrl+opt+r" && clash.holder == .rotate)
    #expect(clash.message == "⌃⌥R runs Rotate Group now.")
    #expect(p.commands.isEmpty && p.model.recording == nil)
    p.model.cancelRecording()
    #expect(p.model.clash == nil && p.commands.isEmpty)

    // Turning to another line drops the question too.
    p.model.startRecording(row)
    try p.press("ctrl+opt+r")
    p.model.startRecording(try #require(p.shortcut("back")))
    #expect(p.model.clash == nil && p.model.recording?.command == .back)
    p.model.replaceHolder()
    #expect(p.commands.isEmpty)
    p.model.cancelRecording()

    p.model.startRecording(row)
    try p.press("ctrl+opt+r")
    p.model.replaceHolder()
    #expect(p.model.clash == nil)
    #expect(p.shortcut("desktop")?.chord?.text == "ctrl+opt+r")
    let loser = try #require(p.shortcut("rotate"))
    #expect(loser.chord == nil && loser.standard?.text == "ctrl+opt+r" && loser.isChanged)
  }

  @Test func keysThatCannotBeAShortcutAreRefusedOnTheLineAndTheOldOnesStay() throws {
    let p = Panel(settings: .withEveryKey)
    let row = try #require(p.shortcut("desktop"))
    p.model.startRecording(row)
    try p.press("shift+a")
    #expect(p.model.errors[row.id]?.hasPrefix("shift+a: needs ctrl, opt or cmd") == true)
    #expect(p.shortcut("desktop")?.chord?.text == "ctrl+opt+d", "the old shortcut goes only after the new one took")
    // A key Arbor has no name for leaves the recording going.
    p.model.startRecording(row)
    #expect(p.model.keyPressed(code: 10, modifiers: [.control, .option]))
    #expect(p.model.errors[row.id] == "That key cannot be part of a shortcut" && p.model.recording == row)
  }

  @Test func removeLeavesTheLineWithoutKeysAndRestoreBringsThemBack() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.removeShortcut(try #require(p.shortcut("desktop")))
    let removed = try #require(p.shortcut("desktop"))
    #expect(removed.chord == nil && removed.isChanged)
    p.model.removeShortcut(removed)  // nothing left to remove
    #expect(p.commands == ["unbind ctrl+opt+d"])
    p.model.restoreShortcut(removed)
    #expect(p.shortcut("desktop")?.isChanged == false && p.settings.bindings.isEmpty)
  }

  @Test func restoreUndoesAMove() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.startRecording(try #require(p.shortcut("desktop")))
    try p.press("ctrl+opt+y")
    p.model.restoreShortcut(try #require(p.shortcut("desktop")))
    #expect(p.settings.bindings.isEmpty)
    #expect(p.model.shortcutRows.allSatisfy { !$0.isChanged })
  }

  @Test func aShortcutOfTheUsersOwnGoesWhenRemovedOrRestored() throws {
    for restore in [false, true] {
      let p = Panel()
      p.h.run("bind ctrl+opt+x float-all here")
      let row = try #require(p.shortcut("float-all here"))
      if restore { p.model.restoreShortcut(row) } else { p.model.removeShortcut(row) }
      #expect(p.shortcut("float-all here") == nil && p.settings.bindings.isEmpty)
    }
  }

  @Test func aCommandThatHasNoLineYetCanBeTyped() throws {
    let p = Panel()
    p.model.pane = .shortcuts
    p.model.startRecording(commandText: "teleport")
    #expect(p.model.errors["Shortcuts"] == "Unknown command “teleport”" && p.model.recording == nil)
    p.model.startRecording(commandText: "set gap 0")
    #expect(p.model.recording?.isNew == true && p.model.errors.isEmpty)
    try p.press("ctrl+opt+x")
    #expect(p.shortcut("set gap 0")?.chord?.text == "ctrl+opt+x")
    // What `bind` refuses has no line to be shown on, so the pane shows it.
    p.model.startRecording(commandText: "state")
    try p.press("ctrl+opt+y")
    #expect(p.model.errors["Shortcuts"]?.contains("is a query") == true)
  }

  @Test func leavingThePaneEndsTheRecording() throws {
    let p = Panel(settings: .withEveryKey)
    p.model.pane = .shortcuts
    var recordings: [Bool] = []
    p.model.onRecordingChanged = { recordings.append($0) }
    p.model.startRecording(try #require(p.shortcut("desktop")))
    p.model.pane = .rules
    #expect(p.model.recording == nil && recordings == [true, false])
  }

  @Test func restoreAllAndTheProblemsOfTheFile() throws {
    let json = #"{"bindings": {"hyper+x": "desktop", "ctrl+opt+x": "arrange"}, "hotkeysEnabled": false}"#
    let p = Panel(settings: try JSONDecoder().decode(Settings.self, from: Data(json.utf8)))
    #expect(p.model.shortcutProblems.count == 1 && p.model.shortcutProblems[0].hasPrefix("hyper+x: "))
    #expect(p.model.shortcutsAreOff)
    // Not at one click: it says how much would go, and where a copy stays.
    p.model.restoreAllShortcuts()
    #expect(p.model.question == .restoreAllShortcuts(count: 2) && p.commands.isEmpty)
    #expect(p.model.question?.text.hasPrefix("Give up all 2 of your changes to the shortcuts?") == true)
    #expect(p.model.question?.text.contains("settings.before-reset.json") == true)
    p.model.answer(yes: false)
    #expect(p.model.question == nil && p.commands.isEmpty && p.model.shortcutsAreChanged)
    p.model.restoreAllShortcuts()
    p.model.pane = .rules
    #expect(p.model.question == nil, "walking away is a no")
    p.model.pane = .shortcuts
    p.model.answer(yes: true)
    #expect(p.commands.isEmpty, "there is nothing to say yes to")
    p.model.restoreAllShortcuts()
    p.model.answer(yes: true)
    #expect(p.commands == ["reset bindings"] && p.model.shortcutProblems.isEmpty && !p.model.shortcutsAreChanged)
    // With nothing changed there is nothing to ask.
    p.model.restoreAllShortcuts()
    #expect(p.model.question == nil)
  }
}

@Suite @MainActor struct SettingsPanelRuleTests {
  private func panel() -> Panel {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.left)),
      AppRule(app: "com.apple.finder", action: .ignore),
      AppRule(app: "com.example.notes", action: .dockBeside(bundleID: "com.example.mail", .bottom)),
    ]
    return Panel(settings: settings)
  }

  @Test func theLinesAreTheRulesInOrderWithNamesWhereKnown() {
    let rows = panel().model.ruleRows
    #expect(rows.map(\.number) == [1, 2, 3])
    #expect(rows.map(\.appName) == ["Mail", "com.apple.finder", "notes"])
    #expect(rows.map(\.kind) == [.dock, .ignore, .dockBeside])
    #expect(rows.map(\.edge) == [.left, nil, .bottom])
    #expect(rows.map(\.neighbour) == [nil, nil, "com.example.mail"])
  }

  @Test func aTitleHandedOverJustBeforeAMenuActsIsKept() {
    // Menus do not take the keyboard, so the window hands over what is in the title field, then acts, both
    // with the line as it was drawn.
    let p = panel()
    let drawn = p.model.ruleRows[1]
    p.model.setTitle("Downloads", of: drawn)
    p.model.setKind(.float, of: drawn)
    #expect(p.settings.rules[1] == AppRule(app: "com.apple.finder", title: "Downloads", action: .float))
    let first = p.model.ruleRows[0]
    p.model.setTitle("Sent", of: first)
    p.model.setEdge(.top, of: first)
    #expect(p.settings.rules[0] == AppRule(app: "com.example.mail", title: "Sent", action: .dock(.top)))
  }

  @Test func aLineWhoseRuleIsGoneChangesNothing() {
    let p = panel()
    let last = p.model.ruleRows[2]
    p.h.run("rule remove 3")
    let before = p.settings.rules
    p.model.setKind(.float, of: last)
    p.model.setTitle("x", of: last)
    #expect(p.settings.rules == before)
  }

  @Test func addRemoveAndMove() {
    let p = panel()
    p.model.addRule(app: "com.example.safari")
    #expect(p.settings.rules.last == AppRule(app: "com.example.safari", action: .dock(.right)))
    p.model.moveRule(p.model.ruleRows[3], by: -1)
    #expect(p.settings.rules.map(\.app)[2] == "com.example.safari")
    p.model.moveRule(p.model.ruleRows[0], by: 1)
    #expect(p.settings.rules.map(\.app).prefix(2) == ["com.apple.finder", "com.example.mail"])
    p.model.removeRule(p.model.ruleRows[0])
    #expect(p.settings.rules.map(\.app) == ["com.example.mail", "com.example.safari", "com.example.notes"])
    #expect(
      p.commands == ["rule add com.example.safari dock right", "rule move 4 3", "rule move 1 2", "rule remove 1"])
  }

  @Test func theEndsOfTheListCannotBeMovedPast() {
    let p = panel()
    #expect(!p.model.canMove(p.model.ruleRows[0], by: -1) && p.model.canMove(p.model.ruleRows[0], by: 1))
    #expect(p.model.canMove(p.model.ruleRows[2], by: -1) && !p.model.canMove(p.model.ruleRows[2], by: 1))
    p.model.moveRule(p.model.ruleRows[0], by: -1)
    p.model.moveRule(p.model.ruleRows[2], by: 1)
    #expect(p.commands.isEmpty)
  }

  @Test func theMenusOfALineChangeTheRuleInPlace() {
    let p = panel()
    p.model.setEdge(.top, of: p.model.ruleRows[0])
    #expect(p.settings.rules[0] == AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.top)))
    p.model.setKind(.dockBeside, of: p.model.ruleRows[0])
    // The edge is kept; the neighbour is the first running app that is not the rule's own.
    #expect(p.settings.rules[0].action == .dockBeside(bundleID: "com.example.notes", .top))
    p.model.setNeighbour("com.example.safari", of: p.model.ruleRows[0])
    #expect(p.settings.rules[0].action == .dockBeside(bundleID: "com.example.safari", .top))
    p.model.setKind(.float, of: p.model.ruleRows[0])
    #expect(p.settings.rules[0] == AppRule(app: "com.example.mail", title: "Inbox", action: .float))
    p.model.setKind(.dock, of: p.model.ruleRows[0])
    #expect(p.settings.rules[0].action == .dock(.right))
    p.model.setKind(.dock, of: p.model.ruleRows[2])
    #expect(p.settings.rules[2].action == .dock(.bottom))
    #expect(p.settings.rules[1] == AppRule(app: "com.apple.finder", action: .ignore))
  }

  @Test func whatChangesNothingRunsNothing() {
    let p = panel()
    p.model.setEdge(.left, of: p.model.ruleRows[0])
    p.model.setKind(.dock, of: p.model.ruleRows[0])
    p.model.setEdge(.left, of: p.model.ruleRows[1])  // it does not dock
    p.model.setNeighbour("com.example.safari", of: p.model.ruleRows[0])  // it docks beside nothing
    p.model.setTitle(" Inbox ", of: p.model.ruleRows[0])
    #expect(p.commands.isEmpty)
  }

  @Test func theTitleCanBeSetChangedAndCleared() {
    let p = panel()
    p.model.setTitle("Build  log / today", of: p.model.ruleRows[1])
    #expect(p.settings.rules[1].title == "Build log / today")
    p.model.setTitle("   ", of: p.model.ruleRows[1])
    #expect(p.settings.rules[1].title == nil)
  }

  @Test func entriesThatCouldNotBeReadAreListed() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"rules": [{"app": "com.a"}]}"#.utf8))
    #expect(Panel(settings: settings).model.skippedRules == ["entry 1 (com.a): “action” is missing"])
  }
}

@Suite @MainActor struct SettingsPanelAppListTests {
  private typealias App = SettingsPanelModel.AppChoice

  /// The apps on "Don't arrange", and the ones its menu offers.
  private func dontArrange(_ p: Panel) throws -> (listed: [App], candidates: [App]) {
    guard case .apps(let listed, let candidates)? = p.row("excludedBundleIDs", in: .apps)?.control else {
      throw Settings.FileError("no such line")
    }
    return (listed, candidates)
  }

  @Test func theAppsPaneHasEveryListOfAppsAtItsLevel() {
    let p = Panel()
    #expect(p.model.panes.contains(.section(.apps)))
    #expect(p.model.rows(in: .apps).first?.label == "Don't arrange")
    let shown = (p.model.rows(in: .apps) + p.model.advancedRows(in: .apps)).map(\.key)
    #expect(shown == SettingsSchema.entries.filter { $0.isAppList && $0.level != .hidden }.map(\.key))
    #expect(p.model.advancedRows(in: .apps).map(\.key) == ["pauseForApps"])
  }

  @Test func appsAreAddedFromTheOnesRunningAndTakenOffAgain() throws {
    let p = Panel()
    #expect(try dontArrange(p).listed.isEmpty)
    #expect(try dontArrange(p).candidates.map(\.name) == ["Mail", "notes", "Safari"])  // by name, whatever the case
    p.model.add("com.example.safari", to: "excludedBundleIDs")
    #expect(p.commands == ["set excludedBundleIDs add com.example.safari"])
    #expect(try dontArrange(p).listed == [.init(bundleID: "com.example.safari", name: "Safari")])
    #expect(try dontArrange(p).candidates.map(\.name) == ["Mail", "notes"])
    #expect(!p.h.workspace.contains(p.a), "its window is let go at once")
    p.model.remove("com.example.safari", from: "excludedBundleIDs")
    #expect(try dontArrange(p).listed.isEmpty && p.h.workspace.contains(p.a))
  }

  @Test func whatAHandEditedFileCanHoldIsShownOnceAndCanBeTakenOff() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.music", "COM.example.Music", "", "com.example.music", " "]
    let p = Panel(settings: settings)
    #expect(try dontArrange(p).listed.map(\.bundleID) == ["com.example.music", "", " "])
    #expect(try dontArrange(p).listed.map(\.name) == ["com.example.music", "(an empty entry)", "(an empty entry)"])
    #expect(Set(try dontArrange(p).listed.map(\.id)).count == 3, "lines are told apart")
    p.model.remove("com.example.music", from: "excludedBundleIDs")
    #expect(p.settings.excludedBundleIDs == ["", " "])
    p.model.remove("", from: "excludedBundleIDs")
    p.model.remove(" ", from: "excludedBundleIDs")
    #expect(p.settings.excludedBundleIDs.isEmpty, "\(p.model.errors)")
  }

  @Test func eachListHasItsOwnApps() throws {
    let p = Panel()
    p.model.add("com.example.mail", to: "passThroughApps")
    p.model.add("com.example.notes", to: "pauseForApps")
    #expect(p.settings.passThroughApps == ["com.example.mail"] && p.settings.pauseForApps == ["com.example.notes"])
    #expect(try dontArrange(p).listed.isEmpty && dontArrange(p).candidates.count == 3)
  }

  @Test func lookingAgainAtWhatRunsRedraws() {
    let p = Panel()
    p.model.refreshApps()
    #expect(p.redraws == 1, "apps have come and gone while the window was away")
  }

  @Test func anAppThatIsNotRunningIsShownByItsBundleID() throws {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.apple.Music"]
    #expect(try dontArrange(Panel(settings: settings)).listed == [.init(bundleID: "com.apple.Music", name: "com.apple.Music")])
  }

  @Test func aRefusalIsShownOnTheList() throws {
    let p = Panel()
    p.h.controller.loadSettings = { throw Settings.FileError("line 1, column 1: expected `{`") }
    p.model.add("com.example.safari", to: "excludedBundleIDs")
    #expect(p.row("excludedBundleIDs", in: .apps)?.error == "Nothing was changed: settings.json cannot be read")
    #expect(try dontArrange(p).listed.isEmpty)
  }

  @Test func theListsCanBeChangedDuringAPause() throws {
    let p = Panel()
    p.h.run("pause")
    p.model.add("com.example.safari", to: "excludedBundleIDs")
    #expect(p.row("excludedBundleIDs", in: .apps)?.error == nil)
    #expect(try dontArrange(p).listed.count == 1)
  }

  @Test func restoreDefaultsLeavesListsAlone() {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.apple.Music"]
    let p = Panel(settings: settings)
    #expect(p.model.changedKeys(in: .apps).isEmpty && !p.model.canRestoreDefaults(in: .apps))
    #expect(p.model.canRestoreDefaults(in: .windows))
    p.model.restoreDefaults(in: .apps)
    #expect(p.settings.excludedBundleIDs == ["com.apple.Music"] && p.commands.isEmpty)
  }

  @Test func aListWithoutAnEditorIsALineThatSaysHowLongItIs() throws {
    // None is in the schema today; `displays` will be.
    let entry = SettingEntry.list(
      "rules", \.rules, shape: "a list", editedWith: "a text editor", "Options per display", "Other values for some displays.")
    var settings = Settings()
    settings.rules = [AppRule(app: "a.b", action: .float), AppRule(app: "c.d", action: .float)]
    let row = try #require(Panel(settings: settings).model.row(for: entry))
    #expect(row.control == .list(summary: "2 entries") && row.label == "Options per display" && row.isChanged)
  }
}
