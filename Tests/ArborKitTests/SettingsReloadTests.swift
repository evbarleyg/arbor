import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A controller wired to a real settings.json in a temporary folder the way `ArborApp` wires it, with
/// one window docked on the left. `edit` saves the file as an editor would and tells the controller
/// what the folder watcher would tell it.
@MainActor
private final class FileFixture {
  let h: Harness
  let a: WindowID
  let folder: URL
  let file: URL
  var applied = 0

  init(_ contents: String? = "{}") throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "arbor-settings-\(UUID().uuidString)")
    file = folder.appendingPathComponent("settings.json")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if let contents { try Data(contents.utf8).write(to: file) }
    h = Harness(settings: (try? SettingsFile.read(from: file)) ?? Settings())
    a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let file = file
    h.controller.loadSettings = { try SettingsFile.read(from: file) }
    h.controller.saveSettings = { try SettingsFile.update(from: $0, to: $1, at: file) }
    h.controller.replaceSettingsFile = { try SettingsFile.replace(with: $0, at: file) }
    h.controller.keepCopyOfSettingsFile = { try SettingsFile.keepCopy(of: file) }
    h.controller.takeInSettingsFile()  // as at launch
    h.controller.onSettingsApplied = { [unowned self] _ in applied += 1 }
    h.start()
    h.run("dock \(a.rawValue) left")
  }

  deinit { try? FileManager.default.removeItem(at: folder) }

  func write(_ contents: String) throws { try Data(contents.utf8).write(to: file) }

  /// Saves `contents`, lets the watcher report it, and waits out the pause.
  func edit(_ contents: String) throws {
    try write(contents)
    h.controller.settingsFileMayHaveChanged()
    h.scheduler.advance(by: 0.3)
  }

  var contents: String { (try? String(contentsOf: file, encoding: .utf8)) ?? "" }
  var inset: CGFloat { h.frame(a)!.minX - h.visibleFrame.minX }
  var settings: Settings { h.controller.settings }
}

/// Reading settings.json from disk.
@Suite struct SettingsFileReadingTests {
  func temporaryFile(_ contents: String?) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-\(UUID().uuidString).json")
    if let contents { try Data(contents.utf8).write(to: url) }
    return url
  }

  @Test func readGivesTheSettingsInTheFile() throws {
    let url = try temporaryFile(#"{"gap": 20, "somethingNew": [1, 2]}"#)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(try SettingsFile.read(from: url).gap == 20)
  }

  @Test func readSaysWhenThereIsNoFile() throws {
    let url = try temporaryFile(nil)
    #expect(throws: SettingsFile.Missing()) { try SettingsFile.read(from: url) }
    #expect(!FileManager.default.fileExists(atPath: url.path), "reading must not create the file")
  }

  /// An editor that empties the file before it writes leaves such a moment.
  @Test(arguments: ["", "   ", "\n"]) func aBlankFileIsNoFile(contents: String) throws {
    let url = try temporaryFile(contents)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: SettingsFile.Missing()) { try SettingsFile.read(from: url) }
    #expect(try String(contentsOf: url, encoding: .utf8) == contents, "reading must not write the file")
  }

  @Test(arguments: [#"{"gap": 20"#, #"{"gap": }"#, "{gap: 20}", "nonsense"])
  func readRefusesWhatIsNotJSONAndSaysWhere(contents: String) throws {
    let url = try temporaryFile(contents)
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      _ = try SettingsFile.read(from: url)
      Issue.record("\(contents) was read")
    } catch {
      #expect(error is Settings.FileError)
      #expect("\(error)".hasPrefix("line 1, column "), "\(error)")
    }
  }

  @Test(arguments: ["[1, 2]", #"["gap"]"#]) func readRefusesJSONThatIsNotAnObject(contents: String) throws {
    let url = try temporaryFile(contents)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: Settings.FileError("the settings must be inside { and }")) {
      try SettingsFile.read(from: url)
    }
  }

  @Test func atLaunchAMissingFileIsWrittenAndABrokenOneIsLeftAlone() throws {
    let missing = try temporaryFile(nil)
    let broken = try temporaryFile(#"{"gap": 20,, "rules": []}"#)
    defer {
      try? FileManager.default.removeItem(at: missing)
      try? FileManager.default.removeItem(at: broken)
    }
    #expect(SettingsFile.load(from: missing) == Settings())
    #expect(try SettingsFile.read(from: missing) == Settings())
    #expect(SettingsFile.load(from: broken) == Settings())
    #expect(try String(contentsOf: broken, encoding: .utf8) == #"{"gap": 20,, "rules": []}"#)
  }
}

/// Edits to settings.json apply by themselves.
@Suite @MainActor struct SettingsReloadTests {
  @Test func aHandEditAppliesWithoutReloadSettings() throws {
    let f = try FileFixture(#"{"gap": 12}"#)
    #expect(f.inset == 12)
    try f.edit(#"{"gap": 40, "tabsEnabled": true}"#)
    #expect(f.inset == 40)
    #expect(f.settings.tabsEnabled)
    #expect(f.applied == 1)
    expectWindowsMatchLayout(f.h, on: f.h.display)
  }

  @Test func savesInQuickSuccessionAreTakenInOnceWhenTheyStop() throws {
    let f = try FileFixture()
    for gap in [20, 30, 40] {
      try f.write("{\"gap\": \(gap)}")
      f.h.controller.settingsFileMayHaveChanged()
      f.h.scheduler.advance(by: 0.2)
      #expect(f.inset == 12, "still waiting for quiet")
    }
    f.h.scheduler.advance(by: 0.1)
    #expect(f.inset == 40)
    #expect(f.applied == 1)
  }

  @Test func arborsOwnWritesAreNotReadBackIn() throws {
    let f = try FileFixture()
    #expect(f.h.run("set gap 30").ok)
    #expect(try SettingsFile.read(from: f.file).gap == 30, "set saves to the file")
    #expect(f.applied == 1)
    // The watcher sees the write like any other.
    f.h.controller.settingsFileMayHaveChanged()
    f.h.scheduler.advance(by: 0.3)
    #expect(f.applied == 1)
    #expect(f.h.controller.takeInSettingsFile() == .unchanged)
  }

  @Test func otherFilesChangingInTheFolderCostNothing() throws {
    // state.json is saved into the same folder after nearly every command.
    let f = try FileFixture(#"{"gap": 20}"#)
    let moves = f.h.system.frameLog.count
    for _ in 1...5 {
      f.h.controller.settingsFileMayHaveChanged()
      f.h.scheduler.advance(by: 0.3)
    }
    #expect(f.applied == 0 && f.h.system.frameLog.count == moves)
  }

  @Test func anEditThatChangesNothingThatCountsIsIgnored() throws {
    let f = try FileFixture(#"{"gap": 20, "tabsEnabled": true}"#)
    try f.edit(
      "{\n  \"tabsEnabled\" : true,\n\n  \"gap\" : 20.0,\n  \"noteToSelf\" : \"hello\", \"pinchThreshold\": 0.25\n}\n"
    )
    #expect(f.applied == 0)
  }

  @Test func aFileThatDoesNotParseKeepsTheSettingsInUse() throws {
    let f = try FileFixture(#"{"gap": 40, "rules": [{"app": "com.example.terminal", "action": "dock right"}]}"#)
    let before = f.settings
    try f.edit(#"{"gap": 60, "rules": [{"app": "#)  // saved half-way through a line
    #expect(f.settings == before, "not the defaults, and not half of the new file")
    #expect(f.inset == 40 && f.applied == 0)
    #expect(f.h.controller.settingsFileProblem?.hasPrefix("line 1, column 31: ") == true)
    // The command says so as well, where it used to fall back to the defaults without a word.
    let result = f.h.run("reload-settings")
    #expect(
      !result.ok
        && result.message.hasPrefix(
          "settings.json cannot be read, keeping the settings in use: line 1, column 31: ")
    )
    #expect(f.settings == before)
    // Mended, it applies like any other edit.
    try f.edit(#"{"gap": 60}"#)
    #expect(f.inset == 60 && f.settings.rules.isEmpty)
    #expect(f.h.controller.settingsFileProblem == nil)
  }

  @Test func aBrokenFileIsTheFirstThingSettingsAndStatusSay() throws {
    let f = try FileFixture(#"{"gap": 40}"#)
    var changes: [Controller.Change] = []
    f.h.controller.observe { changes.append($0) }
    try f.edit("[]")
    #expect(changes == [.settings], "whatever shows settings hears that they can no longer be read")
    let reason = try #require(f.h.controller.settingsFileProblem)
    #expect(f.h.run("settings").text?.hasPrefix("settings.json cannot be read: \(reason).\nArbor keeps") == true)
    #expect(f.h.run("status").message.hasSuffix(". settings.json cannot be read: \(reason)"))
    // The forms for scripts and for the document keep their shape.
    #expect(f.h.run("settings --json").text?.hasPrefix("[") == true)
    changes.removeAll()
    try f.edit(#"{"gap": 40}"#)
    #expect(changes == [.settings])
    #expect(f.h.run("settings").text?.hasPrefix("Change a setting with") == true)
    #expect(!f.h.run("status").message.contains("settings.json"))
  }

  @Test func theSameMistakeIsReportedOnce() throws {
    let f = try FileFixture()
    try f.write(#"{"gap": "#)
    guard case .invalid(let reason, isNews: true) = f.h.controller.takeInSettingsFile() else {
      Issue.record("the first look should be news")
      return
    }
    #expect(f.h.controller.takeInSettingsFile() == .invalid(reason: reason, isNews: false))
    #expect(f.h.controller.takeInSettingsFile() == .invalid(reason: reason, isNews: false))
    // Another mistake is news again, and so is the same one after the file was fine in between.
    try f.write("[]")
    #expect(
      f.h.controller.takeInSettingsFile() == .invalid(reason: "the settings must be inside { and }", isNews: true))
    try f.write("{}")
    #expect(f.h.controller.takeInSettingsFile() == .unchanged)
    try f.write("[]")
    #expect(
      f.h.controller.takeInSettingsFile() == .invalid(reason: "the settings must be inside { and }", isNews: true))
  }

  @Test func whileTheFileIsBrokenNothingIsSavedOverIt() throws {
    let broken = #"{"gap": 40, "rules": [{"app": "com.example.terminal", "action": "dock right"}],}}"#
    let f = try FileFixture("{}")
    try f.edit(broken)
    for command in [
      "set gap 30", "reset all", "bind ctrl+opt+h dock left", "unbind ctrl+opt+d", "rule add com.a float",
      "reset gap", "exclude com.a", "include com.a",
    ] {
      let result = f.h.run(command)
      #expect(
        !result.ok && result.message.hasPrefix("settings.json cannot be read, so nothing was changed: "),
        "\(command)")
    }
    #expect(f.contents == broken, "the user's unfinished edit is still there")
    #expect(f.settings == Settings() && f.applied == 0)
    // Reading still works.
    #expect(f.h.run("get gap").text == "12")
    #expect(f.h.run("settings").ok)
  }

  @Test func aFileBrokenAtLaunchIsNotReplacedByTheDefaults() throws {
    let broken = #"{"gap": 40,, "bindings": {"ctrl+opt+h": "dock left"}}"#
    let f = try FileFixture(broken)
    #expect(f.settings == Settings())
    #expect(!f.h.run("set tabsEnabled true").ok)
    #expect(f.contents == broken)
  }

  @Test func aMendedFileIsReadBeforeTheNextChangeBuildsOnIt() throws {
    let f = try FileFixture("{}")
    try f.edit(#"{"gap": "#)
    // Mended, but the watcher has not said so yet.
    try f.write(#"{"gap": 40, "rules": [{"app": "com.example.terminal", "action": "dock right"}]}"#)
    #expect(f.h.run("rule add com.example.mail float").message.hasPrefix("rule 2: com.example.mail → float"))
    let saved = try SettingsFile.read(from: f.file)
    #expect(saved.gap == 40 && saved.rules.map(\.app) == ["com.example.terminal", "com.example.mail"])
    #expect(f.inset == 40)
  }

  @Test func aResetThatEmptiesAListOrEverythingKeepsACopyAndNamesIt() throws {
    let written = #"{"gap": 40, "bindings": {"ctrl+opt+x": "desktop"}, "rules": [{"app": "a.b", "action": "float"}], "mine": 1}"#
    let f = try FileFixture(written)
    let copy = f.folder.appendingPathComponent("settings.before-reset.json")
    func kept() -> String? { try? String(contentsOf: copy, encoding: .utf8) }
    // One number is put back with one command, and needs no copy.
    #expect(f.h.run("reset gap").message == "gap = 12, the default (was 40)")
    #expect(kept() == nil)
    let afterGap = f.contents
    #expect(
      f.h.run("reset bindings").message
        == "bindings = none, the default (was 1 shortcut); the file as it was is kept as settings.before-reset.json")
    #expect(kept() == afterGap && f.settings.bindings.isEmpty)
    // The next copy takes its place.
    let afterBindings = f.contents
    #expect(f.h.run("reset everything").message.hasSuffix("; the file as it was is kept as settings.before-reset.json"))
    #expect(kept() == afterBindings && f.settings.rules.isEmpty)
    // `reset all` leaves the lists alone, so there is nothing to keep a copy for.
    f.h.run("set gap 30")
    #expect(!f.h.run("reset all").message.contains("kept as"))
    #expect(kept() == afterBindings)
  }

  @Test func withoutACopyNothingIsReset() throws {
    let f = try FileFixture(#"{"rules": [{"app": "a.b", "action": "float"}]}"#)
    f.h.controller.keepCopyOfSettingsFile = { throw Settings.FileError("no copy could be kept as settings.before-reset.json (disk full)") }
    let before = f.contents
    let result = f.h.run("reset rules")
    #expect(result == .failure("nothing was reset: no copy could be kept as settings.before-reset.json (disk full)"))
    #expect(f.contents == before && f.settings.rules.count == 1)
    #expect(!f.h.run("reset everything").ok && f.settings.rules.count == 1)
  }

  @Test func resetEverythingIsTheWayOutOfABrokenFile() throws {
    let f = try FileFixture(#"{"gap": 40,,}"#)
    let result = f.h.run("reset everything")
    #expect(
      result.ok
        && result.message == "replaced settings.json with the defaults; the file as it was is kept as settings.unreadable.json")
    #expect(try SettingsFile.read(from: f.file) == Settings())
    #expect(f.h.controller.settingsFileProblem == nil)
    #expect(f.h.run("set gap 30").ok)
  }

  @Test func aMissingFileIsLeftAloneUntilSomethingIsSaved() throws {
    let f = try FileFixture(#"{"gap": 40}"#)
    try FileManager.default.removeItem(at: f.file)
    // An editor replacing the file can leave a moment without one.
    f.h.controller.settingsFileMayHaveChanged()
    f.h.scheduler.advance(by: 0.3)
    #expect(f.inset == 40 && f.applied == 0)
    #expect(!FileManager.default.fileExists(atPath: f.file.path))
    #expect(f.h.run("set tabsEnabled true").ok)
    let saved = try SettingsFile.read(from: f.file)
    #expect(saved.gap == 40 && saved.tabsEnabled)
  }

  @Test func throwingABrokenFileAwayIsAWayOutToo() throws {
    let f = try FileFixture(#"{"gap": 40}"#)
    try f.edit(#"{"gap": 40,,}"#)
    #expect(f.h.controller.settingsFileProblem != nil && !f.h.run("set gap 30").ok)
    try FileManager.default.removeItem(at: f.file)
    f.h.controller.settingsFileMayHaveChanged()
    f.h.scheduler.advance(by: 0.3)
    // Nothing is left to complain about or to save over.
    #expect(f.h.controller.settingsFileProblem == nil)
    #expect(f.h.run("set gap 30").ok && f.inset == 30)
    #expect(try SettingsFile.read(from: f.file).gap == 30)
  }

  @Test func reloadSettingsWithoutAFileStartsFromTheDefaultsAsALaunchDoes() throws {
    let f = try FileFixture(#"{"gap": 40}"#)
    try FileManager.default.removeItem(at: f.file)
    #expect(f.h.run("reload-settings").message == "there was no settings.json; wrote one with the defaults")
    #expect(f.settings == Settings() && f.inset == 12)
    #expect(try SettingsFile.read(from: f.file) == Settings())
  }

  @Test func reloadSettingsAppliesEvenWhatHasNotChanged() throws {
    // It is also how shortcuts that another app held are tried again.
    let f = try FileFixture(#"{"gap": 40}"#)
    #expect(f.h.run("reload-settings").message == "settings reloaded")
    #expect(f.applied == 1)
  }

  @Test func valuesOutOfRangeInAnEditAreSetRightAndShown() throws {
    let f = try FileFixture()
    try f.edit(#"{"gap": -500, "windowEdgeFraction": "wide", "rules": [{"app": "com.a"}]}"#)
    #expect(f.inset == 0)
    #expect(
      f.settings.valueProblems == [
        "windowEdgeFraction: not a number; using the default, 0.3", "gap: -500 is outside 0 to 100 pt; using 0",
      ])
    #expect(f.h.run("settings").text?.contains("  gap: -500 is outside 0 to 100 pt; using 0") == true)
    #expect(f.h.run("reload-settings").message == "settings reloaded; 3 problem(s), see `settings` and `rules`")
  }

  @Test func anEditedListOfExcludedAppsReleasesTheirWindows() throws {
    let f = try FileFixture()
    let bundle = try #require(f.h.controller.windows[f.a]?.bundleID)
    try f.edit("{\"excludedBundleIDs\": [\"\(bundle)\"]}")
    #expect(!f.h.workspace.contains(f.a))
  }

  @Test func nothingHappensAfterArborStops() throws {
    let f = try FileFixture()
    try f.write(#"{"gap": 40}"#)
    f.h.controller.settingsFileMayHaveChanged()
    f.h.controller.shutdown()
    let moves = f.h.system.frameLog.count
    f.h.scheduler.advance(by: 1)
    #expect(f.h.system.frameLog.count == moves, "no window is moved after they were all put back")
  }
}
