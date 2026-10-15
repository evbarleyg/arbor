import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A started harness with two windows docked left and right of the Desktop, which records what
/// is handed over to be saved and how often settings are applied.
@MainActor
private final class Fixture {
  let h: Harness
  let a: WindowID
  let b: WindowID
  var saved: [Settings] = []
  var applied = 0

  init(settings: Settings = Settings(), start: Bool = true) {
    h = Harness(settings: settings)
    a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.controller.saveSettings = { [unowned self] _, new in saved.append(new) }
    h.controller.onSettingsApplied = { [unowned self] _ in applied += 1 }
    guard start else { return }
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
  }

  var settings: Settings { h.controller.settings }
}

/// `set`, `get`, `settings` and `reset` through the real controller.
@Suite @MainActor struct SettingsCommandScenarioTests {
  @Test func setMovesTheWindowsAtOnceAndSaves() {
    let f = Fixture()
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 12)
    let result = f.h.run("set gap 30")
    #expect(result.ok && result.message == "gap = 30 (was 12)")
    // No reload, no relayout command, no scheduled work: the windows are already there.
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 30)
    #expect(f.h.frame(f.a)!.minY == f.h.visibleFrame.minY + 30)
    #expect(f.h.frame(f.b)!.maxX == f.h.visibleFrame.maxX - 30)
    #expect(f.h.layout!.desktopFrame!.minX - f.h.frame(f.a)!.maxX == 30)
    expectWindowsMatchLayout(f.h, on: f.h.display)
    #expect(f.saved.map(\.gap) == [30])
    #expect(f.saved.last == f.settings)
    #expect(f.h.run("get gap").text == "30")
  }

  @Test func aRefusedValueChangesNothing() {
    let f = Fixture()
    let frames = [f.h.frame(f.a), f.h.frame(f.b)]
    var changes: [Controller.Change] = []
    f.h.controller.observe { changes.append($0) }
    let moves = f.h.system.frameLog.count
    for text in [
      "set gap 500", "set gap -1", "set gap nan", "set gap wide", "set gpa 30", "set tabsEnabled perhaps",
      "set frameRectangleModifier banana", "set rules []", "reset gpa", "set gap",
    ] {
      #expect(!f.h.run(text).ok, "\(text)")
    }
    // The same, for a command that was built in code and so never went through the parser.
    #expect(!f.h.controller.perform(.settings(.set(key: "gap", value: "500"))).ok)
    #expect(!f.h.controller.perform(.settings(.set(key: "nonsense", value: "1"))).ok)
    #expect(!f.h.controller.perform(.settings(.reset(key: "nonsense"))).ok)
    #expect(!f.h.controller.perform(.settings(.get(key: "nonsense"))).ok)
    #expect(f.settings == Settings())
    #expect(f.saved.isEmpty && f.applied == 0 && changes.isEmpty)
    #expect(f.h.system.frameLog.count == moves)
    #expect([f.h.frame(f.a), f.h.frame(f.b)] == frames)
  }

  @Test func everyKindOfSettingCanBeSet() {
    let f = Fixture()
    #expect(f.h.run("set tabsEnabled on").message == "tabsEnabled = true (was false)")
    #expect(f.h.run("set windowEdgeFraction 0.25").ok)
    #expect(
      f.h.run("set frameRectangleModifier Command + Shift").message
        == "frameRectangleModifier = shift+cmd (was ctrl+opt)")
    #expect(
      f.settings.tabsEnabled && f.settings.windowEdgeFraction == 0.25
        && f.settings.frameRectangleModifier == "shift+cmd")
    #expect(f.saved.count == 3 && f.applied == 3)
  }

  @Test func settingTheValueItAlreadyHasDoesNothing() {
    let f = Fixture()
    let result = f.h.run("set gap 12")
    #expect(result.ok && result.message == "gap is already 12")
    #expect(f.h.run("reset gap").message == "gap is already the default, 12")
    #expect(f.h.run("reset all").message == "every setting is already the default")
    #expect(f.saved.isEmpty && f.applied == 0)
  }

  @Test func settingAKeyAnswersWhatWasWrongWithItInTheFile() throws {
    let json = #"{"gap": -500, "windowEdgeFraction": 7, "pinchThreshold": "far"}"#
    let f = Fixture(settings: try JSONDecoder().decode(Settings.self, from: Data(json.utf8)))
    #expect(f.settings.valueProblems.count == 3)
    f.h.run("set gap 20")
    #expect(f.settings.valueProblems.count == 2)
    f.h.run("reset pinchThreshold")  // the default is in use already, but the file says something else
    f.h.run("reset windowEdgeFraction")
    #expect(f.settings.valueProblems.isEmpty && f.saved.count == 3)
    #expect(f.h.run("settings").text?.contains("gap: -500") == false)
  }

  @Test func applyingKeepsTheSettingsExactlyAsGiven() throws {
    // Taking in settings.json relies on this: it compares the file with the settings in use, and if applying
    // changed them on the way in, an untouched file would look new, and be applied again, for ever.
    let f = Fixture()
    let json =
      #"{"gap": -500, "rules": [{"app": "x"}], "bindings": {"a": 1, "hyper+x": "quit"}, "excludedBundleIDs": ["b", "a", "b"]}"#
    let odd = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    f.h.controller.apply(settings: odd)
    #expect(f.settings == odd)
  }

  @Test func observersHearAboutASet() {
    let f = Fixture()
    var changes: [Controller.Change] = []
    f.h.controller.observe { changes.append($0) }
    f.h.run("set gap 20")
    #expect(changes == [.layout(f.h.display), .settings])
  }

  @Test func resetPutsOneSettingBack() {
    let f = Fixture()
    f.h.run("set gap 30")
    f.h.run("set tabsEnabled true")
    let result = f.h.run("reset gap")
    #expect(result.ok && result.message == "gap = 12, the default (was 30)")
    #expect(f.settings.gap == 12 && f.settings.tabsEnabled)
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 12)
    #expect(f.saved.last?.gap == 12)
  }

  func changedEverywhere() -> Settings {
    var settings = Settings()
    settings.gap = 30
    settings.pinchThreshold = 0.5
    settings.hotkeysEnabled = false
    settings.bindings = ["ctrl+opt+h": "dock left"]
    settings.rules = [AppRule(app: "com.apple.Terminal", action: .dock(.right))]
    settings.excludedBundleIDs = ["com.apple.Music"]
    return settings
  }

  @Test func resetAllKeepsShortcutsRulesAndExcludedApps() {
    let f = Fixture(settings: changedEverywhere())
    let result = f.h.run("reset all")
    #expect(
      result.message
        == "back to the default: hotkeysEnabled, gap, pinchThreshold; your 1 shortcut, 1 rule and 1 app under “Don't arrange” "
        + "are kept (`reset everything` resets those too)")
    // Said again when there is nothing else left to reset, so that it does not sound as if all were gone.
    #expect(
      f.h.run("reset all").message
        == "every setting is already the default; your 1 shortcut, 1 rule and 1 app under “Don't arrange” are kept "
        + "(`reset everything` resets those too)")
    var expected = Settings()
    expected.bindings = changedEverywhere().bindings
    expected.rules = changedEverywhere().rules
    expected.excludedBundleIDs = changedEverywhere().excludedBundleIDs
    #expect(f.settings == expected)
    #expect(f.saved == [expected] && f.applied == 1)
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 12)
  }

  @Test func resetEverythingEmptiesTheListsToo() {
    let f = Fixture(settings: changedEverywhere())
    #expect(f.h.run("reset everything").ok)
    #expect(f.settings == Settings())
    #expect(f.saved == [Settings()])
    #expect(f.h.controller.filter.excludedBundleIDs.isEmpty)
  }

  @Test func aListCanBeResetOnItsOwn() {
    let f = Fixture(settings: changedEverywhere())
    #expect(f.h.run("reset rules").message == "rules = none, the default (was 1 rule)")
    #expect(f.settings.rules.isEmpty && f.settings.bindings.count == 1 && f.settings.gap == 30)
  }

  @Test func getPrintsTheBareValue() {
    let f = Fixture(settings: changedEverywhere())
    #expect(f.h.run("get gap").text == "30")
    #expect(f.h.run("get GAP").message == "gap = 30")
    #expect(f.h.run("get hotkeysEnabled").text == "false")
    #expect(f.h.run("get frameRectangleModifier").text == "ctrl+opt")
    #expect(f.h.run("get excludedBundleIDs").text == #"["com.apple.Music"]"#)
    #expect(f.h.run("get bindings").text == #"{"ctrl+opt+h":"dock left"}"#)
    #expect(f.h.run("get rules").text == #"[{"action":"dock right","app":"com.apple.Terminal"}]"#)
    #expect(f.h.run("get rules").message == "rules = 1 entry")
  }

  @Test func settingsListsEverythingAndMarksWhatChanged() throws {
    let f = Fixture()
    f.h.run("set gap 30")
    let result = f.h.run("settings")
    #expect(
      result.ok && result.message == "\(SettingsSchema.entries.count) settings, 1 changed from the default")
    #expect(try #require(result.text) == SettingsSchema.report(f.settings))
    #expect(result.text?.contains("\n* gap = 30  (0 to 100 pt; default 12)\n") == true)
    #expect(f.h.run("settings --markdown").text == SettingsSchema.markdown())
  }

  @Test func settingsWindowAsksTheAppToOpenIt() throws {
    let f = Fixture()
    #expect(f.h.run("settings-window").message == "there is no settings window here")
    var opened: [SettingsPane?] = []
    f.h.controller.onShowSettingsWindow = { opened.append($0) }
    #expect(f.h.run("settings-window").message == "the settings window is open")
    #expect(f.h.run("settings-window shortcuts").message == "the settings window is open at Shortcuts")
    #expect(opened == [nil, .shortcuts] && f.saved.isEmpty && f.applied == 0)
    #expect(f.h.run("settings-window close").message == "there is no settings window here")
    var closed = 0
    f.h.controller.onCloseSettingsWindow = { closed += 1 }
    #expect(f.h.run("settings-window close").message == "the settings window is closed")
    #expect(closed == 1 && f.saved.isEmpty)
    // ⌃⌥, by default, since ⌘, cannot reach an app that is never the active one.
    let comma = try KeyChord(text: "⌃⌥,")
    #expect(KeyBindings.defaults.first { $0.chord == comma }?.command == .settings(.showWindow()))
  }

  @Test func theWindowOpensBeforeArborMayArrangeWindowsAndDuringAPause() throws {
    let waiting = Fixture(start: false)
    waiting.h.controller.accessibilityGranted = false
    var opened = 0
    waiting.h.controller.onShowSettingsWindow = { _ in opened += 1 }
    #expect(waiting.h.run("settings-window").ok && opened == 1)

    let paused = Fixture()
    paused.h.controller.onShowSettingsWindow = { _ in opened += 1 }
    #expect(paused.h.run("pause").ok)
    #expect(paused.h.run("settings-window rules").ok && opened == 2)
    // From the menu, that is: a pause gives every ⌃⌥ shortcut back but the ones that end it.
    #expect(!KeyBindings.whilePaused(KeyBindings.defaults).contains { $0.command == .settings(.showWindow()) })
  }

  @Test func noURLCanChangeASettingUnlessTheUserSaidSo() {
    let f = Fixture()
    for url in [
      "arbor://set/allowAllURLCommands/true", "arbor://set/gap/0", "arbor://reset/everything", "arbor://bind/f5/quit",
      "arbor://unbind/ctrl+opt+space", "arbor://rule/add/com.a/ignore", "arbor://settings-window", "arbor://get/gap",
    ] {
      guard case .failure = f.h.controller.admit(url: url) else {
        Issue.record("\(url) was admitted")
        continue
      }
    }
    f.h.run("set allowAllURLCommands true")
    guard case .success(.settings(.set(key: "gap", value: "0"))) = f.h.controller.admit(url: "arbor://set/gap/0") else {
      Issue.record("the user allowed it")
      return
    }
  }

  @Test func settingsCommandsWorkBeforeArborMayArrangeWindows() {
    // Waiting for Accessibility permission: the settings window can already be open.
    let f = Fixture(start: false)
    f.h.controller.accessibilityGranted = false
    #expect(!f.h.run("arrange").ok)
    #expect(f.h.run("get gap").text == "12")
    #expect(f.h.run("settings").ok)
    #expect(f.h.run("set gap 30").ok)
    #expect(f.h.run("bind ctrl+opt+h dock left").ok)
    #expect(f.h.run("rule add com.apple.Terminal dock right").ok)
    #expect(f.saved.count == 3 && f.saved.last == f.settings)
    #expect(f.h.system.frameLog.isEmpty)
    f.h.controller.accessibilityGranted = true
    f.h.start()
    f.h.run("dock \(f.a.rawValue) left")
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 30)
  }

  @Test func aSwitchCanBeFlipped() {
    let f = Fixture()
    #expect(f.h.run("set focusRing toggle").message == "focusRing = false (was true)")
    #expect(f.h.run("set focusRing toggle").message == "focusRing = true (was false)")
    #expect(f.saved.map(\.focusRing) == [false, true])
    // A command built in code, not parsed.
    #expect(!f.h.controller.perform(.settings(.set(key: "gap", value: "toggle"))).ok)
  }

  @Test func anAppGoesOnAListAndOffIt() {
    // Safari (docked) and Notes have windows open.
    let f = Fixture()
    #expect(f.h.run("set excludedBundleIDs add Safari").message == "no longer arranging Safari")
    #expect(f.settings.excludedBundleIDs == ["com.example.safari"] && f.saved.last == f.settings)
    #expect(!f.h.workspace.contains(f.a), "as after `exclude`")
    #expect(f.h.run("set dont-arrange add COM.EXAMPLE.SAFARI").message == "Safari is already under “Don't arrange”")
    #expect(
      f.h.run("set Don't arrange add com.apple.Music").message
        == "no longer arranging com.apple.Music; mind that no app with the id com.apple.Music has a window open: it may be a name, which never matches")
    #expect(f.h.run("set excludedBundleIDs remove com.APPLE.music").message == "arranging com.apple.Music again")
    #expect(f.h.run("set excludedBundleIDs remove com.apple.Music").message == "com.apple.Music was not under “Don't arrange”")
    #expect(f.h.run("set excludedBundleIDs remove safari").message == "arranging Safari again")
    #expect(f.settings.excludedBundleIDs.isEmpty && f.h.workspace.contains(f.a))
    #expect(f.h.run("set shortcuts off in add Notes").message == "shortcuts and gestures are off in Notes")
    #expect(f.h.run("set pause for add notes").message == "Arbor pauses while Notes is in front")
    #expect(f.h.run("set pauseForApps remove notes").message == "Arbor no longer pauses for Notes")
    #expect(f.h.run("set passThroughApps remove notes").message == "shortcuts and gestures work in Notes again")
    let refused = f.h.run("set excludedBundleIDs add Keynote")
    #expect(!refused.ok && refused.message.hasPrefix("`Keynote` is not a bundle id"))
    #expect(f.saved.count == 8)
  }

  @Test func switchingTheShortcutsOffNamesTheWayBack() {
    let f = Fixture()
    #expect(
      f.h.run("set hotkeysEnabled false").message
        == "hotkeysEnabled = false (was true); Settings… in Arbor's menu is the way back")
    #expect(f.h.run("set hotkeysEnabled true").message == "hotkeysEnabled = true (was false)")
    #expect(f.h.run("set hotkeysEnabled toggle").message.hasSuffix("is the way back"))
  }

  @Test func aNameWithADotIsNotTakenForAnIDInSilence() {
    let f = Fixture()
    #expect(
      f.h.run("rule add zoom.us pin").message
        == "rule 1: zoom.us → pin; mind that no app with the id zoom.us has a window open: it may be a name, which never matches")
    // With a window of the app open its name is enough, dot or no dot.
    f.h.system.open(app: "zoom.us")
    #expect(f.h.run("rule change 1 zoom.us pin").message == "rule 1: com.example.zoom.us → pin")
  }

  @Test func whatIsOnAListCanBeTakenOffWhateverItLooksLike() {
    var settings = Settings()
    settings.excludedBundleIDs = ["Keynote"]  // typed by hand
    let f = Fixture(settings: settings)
    #expect(f.h.run("set excludedBundleIDs remove keynote").message == "arranging Keynote again")
  }

  @Test func aShortcutCanChangeASetting() throws {
    let f = Fixture()
    #expect(f.h.run("bind ctrl+opt+x set gap 0").ok)
    let chord = try KeyChord(text: "ctrl+opt+x")
    let binding = try #require(KeyBindings.effective(settings: f.settings).bindings.first { $0.chord == chord })
    #expect(f.h.controller.perform(binding.command).ok)
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX)
  }

  @Test func aChangeDuringAPauseMovesNothingAndCountsFromResume() {
    let f = Fixture()
    #expect(f.h.run("pause").ok)
    let moves = f.h.system.frameLog.count
    #expect(f.h.run("set gap 40").ok)
    #expect(f.saved.last?.gap == 40)
    #expect(f.h.system.frameLog.count == moves)
    #expect(f.h.run("resume").ok)
    #expect(f.h.frame(f.a)!.minX == f.h.visibleFrame.minX + 40)
  }

  @Test func noCombinationOfWordsCrashesTheSettingsCommands() {
    let f = Fixture()
    let keys = SettingsSchema.entries.map(\.key)
    let meaningful = [
      "gap", "rules", "all", "everything", "add", "change", "remove", "move", "title", "float", "dock", "left", "true", "off",
      "none", "shift+cmd", "ctrl+opt+x", "f5", "ctrl+opt+/", "com.example.mail", "desktop", "--markdown",
    ]
    // In pairs, every third of the hostile words and none of the very long ones: the combinations are what
    // takes the time, and each word has had its turn alone by then.
    let hostile = HostileCommandTests.words
    let paired = meaningful + hostile.indices.filter { $0 % 3 == 0 }.map { hostile[$0] }.filter { $0.count < 100 }
    var parsed = 0
    func attempt(_ input: [String]) {
      guard let command = try? Command.parse(words: input) else { return }
      parsed += 1
      // What is shown in `bindings` and saved must survive a round trip.
      if (try? Command.parse(command.text)) != command { Issue.record("\(command) does not round-trip") }
      f.h.controller.perform(command)
      // Thousands of rules would only make the rest of the test slow.
      if f.settings.rules.count > 3 { f.h.run("reset rules") }
    }
    for first in meaningful + hostile {
      for verb in ["get", "reset", "unbind", "settings", "rule"] { attempt([verb, first]) }
      for key in keys { attempt(["set", key, first]) }
    }
    for first in paired {
      for second in paired {
        for verb in ["set", "bind", "rule"] { attempt([verb, first, second]) }
        attempt(["set", "frameRectangleModifier", first, second])
        attempt(["bind", "ctrl+opt+x", first, second])
        for verb in ["add", "change", "remove", "move"] { attempt(["rule", verb, first, second]) }
        attempt(["rule", "add", "com.example.mail", first, second])
        attempt(["rule", "add", "com.example.mail", "float", "title", first, second])
        attempt(["rule", "change", "1", "com.example.mail", "dock", first, "title", second])
        attempt(["rule", "add", first, "dock", "beside", second, "left"])
      }
    }
    #expect(parsed > 300)
    // Whatever got through, every value is one the schema allows, and what was saved reads back the same.
    var settings = f.settings
    #expect(SettingsSchema.sanitize(&settings).isEmpty)
    #expect(KeyBindings.effective(settings: settings).problems.isEmpty)
    let data = try? JSONEncoder().encode(settings)
    #expect(data.flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } == settings)
    expectWindowsMatchLayout(f.h, on: f.h.display)
  }

  @Test func setDuringADragLeavesTheDragWorking() {
    let f = Fixture()
    let c = f.h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 500, height: 300))
    let edge = CGPoint(x: 720, y: f.h.visibleFrame.maxY - 2)
    f.h.system.heldModifiers = DragDocks.key  // held by whoever means to dock, as Arbor ships
    f.h.controller.dragBegan(c, at: CGPoint(x: 700, y: 310))
    f.h.controller.dragMoved(c, to: edge)
    #expect(f.h.run("set gap 40").ok)
    f.h.controller.dragEnded(c, at: edge)
    f.h.scheduler.runPending()
    #expect(f.h.workspace.isDocked(c))
    expectWindowsMatchLayout(f.h, on: f.h.display)
    #expect(f.h.frame(c)!.maxY == f.h.visibleFrame.maxY - 40)
  }
}

/// `bind` and `unbind`.
@Suite @MainActor struct BindCommandTests {
  private func command(_ chord: String, _ f: Fixture) throws -> Command? {
    let chord = try KeyChord(text: chord)
    return KeyBindings.effective(settings: f.settings).bindings.first { $0.chord == chord }?.command
  }

  @Test func bindAddsAShortcutAndSavesIt() throws {
    let f = Fixture()
    let result = f.h.run("bind Cmd+Opt+Ctrl+H dock left")
    #expect(result.ok && result.message.hasPrefix("ctrl+opt+cmd+h runs `dock left`; mind that Xcode uses ⌃⌥⌘ with letters"))
    #expect(f.settings.bindings == ["ctrl+opt+cmd+h": "dock left"])
    #expect(try command("ctrl+opt+cmd+h", f) == .dock(nil, .left))
    #expect(f.saved.last == f.settings && f.applied == 1)  // applying is what makes the app register it
    #expect(KeyBindings.effective(settings: f.settings).problems.isEmpty)
  }

  @Test func bindReplacesWhatTheShortcutRan() throws {
    let f = Fixture()
    #expect(
      f.h.run("bind ctrl+opt+space arrange").message == "ctrl+opt+space runs `arrange` (it ran `show-all`)")
    #expect(try command("ctrl+opt+space", f) == .arrange)
    #expect(
      f.h.run("bind ctrl+opt+space desktop").message == "ctrl+opt+space runs `desktop` (it ran `arrange`)")
    #expect(f.settings.bindings == ["ctrl+opt+space": "desktop"])
  }

  @Test func bindingADefaultAgainNeedsNoEntry() throws {
    let f = Fixture()
    f.h.run("bind ctrl+opt+space arrange")
    #expect(f.h.run("bind ctrl+opt+space show-all").ok)
    #expect(f.settings.bindings.isEmpty)
    #expect(try command("ctrl+opt+space", f) == .showAll)
    let saves = f.saved.count
    #expect(f.h.run("bind ctrl+opt+space show-all").message == "ctrl+opt+space already runs `show-all`")
    #expect(f.saved.count == saves)
  }

  @Test func otherSpellingsOfTheShortcutInTheFileAreReplaced() throws {
    var settings = Settings()
    settings.bindings = ["opt+ctrl+Space": "arrange", "⌃+⌥+d": nil, "ctrl+opt+x": "float-all"]
    let f = Fixture(settings: settings)
    #expect(f.h.run("bind ctrl+opt+space desktop").ok)
    #expect(f.h.run("bind ctrl+opt+d arrange").ok)
    #expect(
      f.settings.bindings == ["ctrl+opt+space": "desktop", "ctrl+opt+d": "arrange", "ctrl+opt+x": "float-all"])
    #expect(KeyBindings.effective(settings: f.settings).problems.isEmpty)
  }

  @Test func bindMendsAnEntryThatCouldNotBeRead() throws {
    let json = #"{"bindings": {"ctrl+opt+q": 5, "Opt+Ctrl+W": "teleport", "ctrl+opt+e": false}}"#
    let f = Fixture(settings: try JSONDecoder().decode(Settings.self, from: Data(json.utf8)))
    #expect(KeyBindings.effective(settings: f.settings).problems.count == 3)
    #expect(f.h.run("bind ctrl+opt+q desktop").ok)
    #expect(f.h.run("bind ctrl+opt+w arrange").ok)
    #expect(try command("ctrl+opt+q", f) == .desktop)
    #expect(try command("ctrl+opt+w", f) == .arrange)
    // The one nobody mended is still reported.
    #expect(KeyBindings.effective(settings: f.settings).problems.map { $0.prefix(10) } == ["ctrl+opt+e"])
  }

  @Test func unbindRemovesADefaultWithNull() throws {
    let f = Fixture()
    #expect(f.h.run("unbind ctrl+opt+d").message == "ctrl+opt+d no longer runs `desktop`; no shortcut does now")
    #expect(f.settings.bindings == ["ctrl+opt+d": nil])
    #expect(try command("ctrl+opt+d", f) == nil)
    #expect(f.h.run("unbind ctrl+opt+d").message == "ctrl+opt+d already runs nothing")
    // Binding its default command again is how it comes back.
    #expect(f.h.run("bind ctrl+opt+d desktop").ok)
    #expect(f.settings.bindings.isEmpty)
  }

  @Test func unbindDropsAShortcutOfTheUsersOwn() throws {
    let f = Fixture()
    f.h.run("bind ctrl+opt+cmd+h dock left")
    #expect(f.h.run("unbind ctrl+opt+cmd+h").ok)
    #expect(f.settings.bindings.isEmpty)
  }

  @Test func unbindSilencesAReboundDefaultAltogether() throws {
    let f = Fixture()
    f.h.run("bind ctrl+opt+space arrange")
    #expect(
      f.h.run("unbind ctrl+opt+space").message == "ctrl+opt+space no longer runs `arrange`; ctrl+opt+a still does")
    #expect(try command("ctrl+opt+space", f) == nil)
  }

  @Test func bindRefusesWhatSettingsJSONMayNotBindEither() {
    let f = Fixture()
    #expect(
      f.h.run("bind ctrl+opt+q state").message
        == "ctrl+opt+q: `state` is a query, and a shortcut has nowhere to show its answer")
    #expect(f.h.run("bind shift+a desktop").message.hasPrefix("shift+a: needs ctrl, opt or cmd"))
    #expect(!f.h.run("bind ctrl+opt+q get gap").ok)
    #expect(f.h.run("bind f5 desktop").ok)
    #expect(f.settings.bindings == ["f5": "desktop"])
    #expect(f.saved.count == 1)
    #expect(!f.h.controller.perform(.settings(.bind(chord: "hyper+x", command: "desktop"))).ok)
    #expect(!f.h.controller.perform(.settings(.bind(chord: "ctrl+opt+x", command: "teleport"))).ok)
    #expect(!f.h.controller.perform(.settings(.unbind(chord: ""))).ok)
  }

  @Test func aShortcutThatAppsNeedIsBoundWithAWordOfCaution() {
    let f = Fixture()
    #expect(f.h.run("bind cmd+q quit").message == "cmd+q runs `quit`; mind that no app gets ⌘Q while Arbor runs")
    #expect(f.h.run("bind ctrl+opt+cmd+8 desktop").message.contains("; mind that macOS uses ⌃⌥⌘8 itself"))
    #expect(f.h.run("bind ⌃⌥X desktop").message == "ctrl+opt+x runs `desktop`")
  }

  @Test func resetBindingsBringsEveryDefaultBack() {
    let f = Fixture()
    f.h.run("bind ctrl+opt+space arrange")
    f.h.run("unbind ctrl+opt+d")
    #expect(f.h.run("reset bindings").ok)
    #expect(KeyBindings.effective(settings: f.settings).bindings == KeyBindings.defaults)
  }
}

/// `rule add`, `rule change`, `rule remove` and `rule move`.
@Suite @MainActor struct RuleCommandTests {
  let terminal = AppRule(app: "com.example.terminal", action: .dock(.right))
  let mail = AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.left))
  let finder = AppRule(app: "com.example.finder", action: .ignore)

  private func fixture() -> Fixture {
    var settings = Settings()
    settings.rules = [terminal, mail, finder]
    return Fixture(settings: settings)
  }

  @Test func anAddedRuleAppliesToTheNextWindow() {
    let f = Fixture()
    let result = f.h.run("rule add com.example.terminal dock bottom")
    #expect(result.ok && result.message.hasPrefix("rule 1: com.example.terminal → dock bottom; mind that no app with the id"))
    #expect(f.saved.last?.rules == [AppRule(app: "com.example.terminal", action: .dock(.bottom))])
    let window = f.h.system.open(app: "Terminal")
    #expect(f.h.workspace.isDocked(window))
    #expect(f.h.frame(window)!.maxY == f.h.visibleFrame.maxY - 12)
  }

  @Test func anAppCanBeNamedAsPeopleKnowIt() {
    // Safari and Notes have windows open.
    let f = Fixture()
    #expect(f.h.run("rule add Safari dock left").message == "rule 1: com.example.safari → dock left")
    #expect(f.h.run("rule add COM.EXAMPLE.NOTES float").message == "rule 2: com.example.notes → float")
    #expect(
      f.h.run("rule add com.example.mail dock beside safari bottom").message
        == "rule 3: com.example.mail → dock beside com.example.safari bottom"
        + "; mind that no app with the id com.example.mail has a window open: it may be a name, which never matches")
    #expect(f.h.run("rule change 2 notes ignore").message == "rule 2: com.example.notes → ignore")
    let refused = f.h.run("rule add Keynote dock left")
    #expect(!refused.ok && refused.message.hasPrefix("`Keynote` is not a bundle id (they look like com.apple.Safari)"))
    #expect(!f.h.run("rule add com.example.mail dock beside Keynote left").ok)
    #expect(f.settings.rules.count == 3)
  }

  @Test func aRuleMatchesWhateverTheCaseOfItsBundleID() {
    let f = Fixture()
    #expect(f.h.run("rule add com.Example.TERMINAL dock bottom").ok)
    let window = f.h.system.open(app: "Terminal")
    #expect(f.h.workspace.isDocked(window))
  }

  @Test func rulesAreAddedAfterTheOthers() {
    let f = fixture()
    #expect(
      f.h.run("rule add com.example.notes float title To do").message
        == "rule 4: com.example.notes, title contains \"To do\" → float")
    #expect(
      f.settings.rules == [
        terminal, mail, finder, AppRule(app: "com.example.notes", title: "To do", action: .float),
      ])
  }

  @Test func changeReplacesARuleInPlace() {
    let f = fixture()
    #expect(f.h.run("rule change 2 com.example.mail float").message.hasPrefix("rule 2: com.example.mail → float; mind"))
    #expect(f.settings.rules == [terminal, AppRule(app: "com.example.mail", action: .float), finder])
    #expect(f.saved.count == 1)
    #expect(f.h.run("rule change 2 com.example.mail float").message == "that changes nothing")
    #expect(f.saved.count == 1)
  }

  @Test func removeTakesOneOut() {
    let f = fixture()
    #expect(f.h.run("rule remove 1").message == "removed rule 1; 2 left")
    #expect(f.settings.rules == [mail, finder])
  }

  @Test(arguments: [
    (1, 3, [1, 2, 0]), (3, 1, [2, 0, 1]), (1, 2, [1, 0, 2]), (2, 3, [0, 2, 1]), (3, 2, [0, 2, 1]),
  ])
  func moveTakesARuleToThatPlace(from: Int, to: Int, order: [Int]) {
    let f = fixture()
    let rules = [terminal, mail, finder]
    #expect(f.h.run("rule move \(from) \(to)").message == "rule \(from) is now rule \(to)")
    #expect(f.settings.rules == order.map { rules[$0] })
    #expect(f.settings.rules[to - 1] == rules[from - 1])
  }

  @Test func movingARuleToWhereItIsDoesNothing() {
    let f = fixture()
    #expect(f.h.run("rule move 2 2").ok)
    #expect(f.saved.isEmpty)
  }

  @Test func numbersOutsideTheListAreRefused() {
    let f = fixture()
    for text in [
      "rule remove 4", "rule move 4 1", "rule move 1 4", "rule change 4 com.a float", "rule remove 1000000",
    ] {
      let result = f.h.run(text)
      #expect(!result.ok && result.message.hasPrefix("there is no rule "), "\(text)")
    }
    // Numbers the parser would not let through.
    for command: SettingsCommand in [
      .removeRule(0), .removeRule(-1), .moveRule(0, to: 1), .moveRule(1, to: 0), .moveRule(.min, to: .max),
      .changeRule(0, terminal),
    ] {
      #expect(!f.h.controller.perform(.settings(command)).ok, "\(command)")
    }
    #expect(f.settings.rules == [terminal, mail, finder] && f.saved.isEmpty)
    #expect(Fixture().h.run("rule remove 1").message == "there are no rules")
  }

  @Test func theRulesQueryShowsTheResult() throws {
    let f = fixture()
    f.h.run("rule move 3 1")
    let text = try #require(f.h.run("rules").text)
    #expect(text.contains("  1. com.example.finder → ignore\n  2. com.example.terminal → dock right\n"))
  }
}

/// Values no sensible person writes, which a slip of the finger does. Each file goes the way a real one
/// does: decoded, handed to the controller, and used.
@Suite @MainActor struct WildSettingsFileTests {
  @Test(arguments: [
    #"{"gap": -500}"#, #"{"gap": 5000}"#, #"{"gap": 1e308}"#, #"{"gap": 1e999}"#,
    #"{"minimumUsableWidth": 1e9}"#,
    #"{"minimumUsableWidth": -1e9, "minimumUsableHeight": -1}"#, #"{"windowEdgeFraction": 7}"#,
    #"{"windowEdgeFraction": -7}"#,
    #"{"screenEdgeBand": 1e9}"#, #"{"screenEdgeBand": -1e9}"#, #"{"arrangeDesktopWeight": -3}"#,
    #"{"arrangeDesktopWeight": 0}"#,
    #"{"arrangeDesktopWeight": 1e308}"#, #"{"pinchThreshold": -1}"#,
    #"{"gap": 100, "minimumUsableWidth": 0, "minimumUsableHeight": 0}"#,
  ]) func nothingInTheFileCanCrashOrWedgeArbor(json: String) throws {
    // A number too large for a Double makes the whole file invalid on some platforms; then nothing of it is used.
    let settings = (try? JSONDecoder().decode(Settings.self, from: Data(json.utf8))) ?? Settings()
    let h = Harness(settings: settings)
    let windows = (1...5).map {
      h.system.open(app: "App\($0)", frame: CGRect(x: 100 + 40 * $0, y: 100, width: 500, height: 300))
    }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok)
    #expect(h.run("dock \(windows[1].rawValue) right").ok)
    #expect(h.run("dock \(windows[2].rawValue) beside \(windows[0].rawValue) bottom").ok)
    h.system.drag(
      windows[3],
      through: [CGPoint(x: 400, y: 110), CGPoint(x: 700, y: 400), CGPoint(x: h.visibleFrame.maxX - 1, y: 400)])
    for command in [
      "ascii", "state", "zoom \(windows[0].rawValue)", "out", "show-all", "arrange", "ascii", "float-all",
      "arrange",
    ] {
      #expect(h.run(command).ok, "\(command)")
      h.scheduler.runPending()
    }
    // Everything is docked, in view, inside the display and large enough to see.
    #expect(Set(h.workspace.tree.allWindows) == Set(windows))
    expectWindowsMatchLayout(h, on: h.display)
    let layout = try #require(h.layout)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    for rectangle in Array(layout.nodeFrames.values) + layout.tiles.map(\.frame) + layout.seams.map(\.frame) {
      #expect(!rectangle.isNull && rectangle.minX.isFinite && rectangle.minY.isFinite)
      #expect(h.visibleFrame.insetBy(dx: -1, dy: -1).contains(rectangle), "\(rectangle)")
    }
    // A tile still opens, so no window is out of reach whatever the smallest usable size.
    #expect(h.run("zoom \(windows[4].rawValue)").ok)
    let frame = try #require(h.frame(windows[4]))
    #expect(h.visibleFrame.contains(frame) && frame.width > 200 && frame.height > 200, "\(frame)")
    h.controller.shutdown()
    for window in windows { #expect(h.system.isVisible(window)) }
  }
}
