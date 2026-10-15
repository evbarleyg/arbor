import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import Foundation
import Testing

private let handEdited = """
  {
    "format": 2,
    "gap": 8.0,
    "myNote": "ask Sam about the gap",
    "excludedBundleIDs": ["com.apple.Music"],
    "rules": [
      { "app": "com.apple.Terminal", "action": "dock sideways" },
      { "app": "com.apple.Notes", "action": "float" }
    ],
    "bindings": { "ctrl+opt+x": 5, "ctrl+opt+h": "dock left" }
  }

  """

/// B1 and F12: `settings.json` on disk, through the commands that write and read it.
@Suite @MainActor struct SettingsFileTests {
  /// A folder of its own for each test, removed when the test ends.
  final class Folder {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "arbor-settings-\(UUID().uuidString)")
    var file: URL { url.appendingPathComponent("settings.json") }

    init() throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    deinit { try? FileManager.default.removeItem(at: url) }

    func write(_ text: String) throws { try Data(text.utf8).write(to: file) }
    func read() throws -> String { String(decoding: try Data(contentsOf: file), as: UTF8.self) }
    /// Changes whenever the file is written: an atomic write puts a new file in its place.
    func fileNumber() throws -> Int {
      try #require(try FileManager.default.attributesOfItem(atPath: file.path)[.systemFileNumber] as? Int)
    }
  }

  /// A controller wired to the file the way `ArborApp` wires it.
  func harness(_ folder: Folder) -> Harness {
    let file = folder.file
    let h = Harness(settings: SettingsFile.load(from: file))
    h.controller.saveSettings = { try SettingsFile.update(from: $0, to: $1, at: file) }
    h.controller.loadSettings = { try SettingsFile.read(from: file) }
    h.controller.replaceSettingsFile = { try SettingsFile.replace(with: $0, at: file) }
    h.controller.takeInSettingsFile()
    h.start()
    return h
  }

  /// The board's test.
  @Test func excludeAndIncludeChangeOnlyTheirKeyInTheFile() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)

    let excluded = h.run("exclude com.apple.Notes")
    #expect(excluded.ok && excluded.message == "no longer arranging com.apple.Notes")
    #expect(
      try folder.read()
        == handEdited.replacingOccurrences(
          of: #"["com.apple.Music"]"#, with: #"["com.apple.Music", "com.apple.Notes"]"#))

    let included = h.run("include com.apple.Notes")
    #expect(included.ok && included.message == "arranging com.apple.Notes again")
    #expect(try folder.read() == handEdited, "back to the file as it was, byte for byte")
  }

  @Test func aCommandThatChangesNothingDoesNotWrite() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    let before = try folder.fileNumber()
    #expect(h.run("exclude com.apple.Music") == .failure("Arbor does not arrange com.apple.Music already"))
    #expect(h.run("include com.example.never-excluded") == .failure("Arbor arranges com.example.never-excluded already"))
    #expect(try folder.fileNumber() == before)
    #expect(h.run("exclude com.apple.Notes").ok)
    #expect(try folder.fileNumber() != before)
  }

  @Test func aFileWithATypoIsLeftAloneAndTheReplySaysSo() throws {
    let folder = try Folder()
    let typo = handEdited.replacingOccurrences(of: #""gap": 8.0,"#, with: #""gap": 8.0"#)
    try folder.write(typo)
    let h = harness(folder)
    #expect(h.controller.settings == Settings(), "a file that cannot be read means the defaults at launch")
    let window = h.system.open(app: "Notes", bundleID: "com.apple.Notes")
    #expect(h.workspace.contains(window))

    let result = h.run("exclude com.apple.Notes")
    #expect(!result.ok, "so that arborctl exits with an error and the menu beeps")
    #expect(
      result.message
        == "settings.json cannot be read, so nothing was changed: "
        + "line 4, column 3: expected `,` or `}` after the value of `gap`, found `\"`. "
        + "Mend the file, or run `reset everything` to replace it with the defaults")
    #expect(h.workspace.contains(window) && h.controller.settings == Settings())
    #expect(try folder.read() == typo)

    // With the typo fixed, the same command works, and builds on what the file says.
    try folder.write(handEdited)
    #expect(h.run("exclude com.apple.Notes") == .success("no longer arranging Notes"))
    #expect(try folder.read().contains(#"["com.apple.Music", "com.apple.Notes"]"#))
    #expect(!h.workspace.contains(window) && h.controller.settings.gap == 8)
  }

  @Test func includeTakesOutWhatOnlyTheFileHas() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    try folder.write(
      handEdited.replacingOccurrences(
        of: #"["com.apple.Music"]"#, with: #"["com.apple.Music", "com.apple.mail"]"#))
    #expect(h.run("include com.apple.mail").ok)
    #expect(try folder.read() == handEdited)
  }

  @Test func reloadingAFileWithATypoKeepsTheSettingsInUse() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    let loaded = h.controller.settings
    #expect(loaded.gap == 8 && loaded.excludedBundleIDs == ["com.apple.Music"])

    try folder.write(handEdited.replacingOccurrences(of: "8.0", with: "wide"))
    let failed = h.run("reload-settings")
    #expect(!failed.ok)
    #expect(
      failed.message
        == "settings.json cannot be read, keeping the settings in use: line 3, column 10: expected a value, found `wide`"
    )
    #expect(h.controller.settings == loaded)

    // A value of the wrong kind is not a typo in the JSON: it costs its own key and nothing else.
    try folder.write(handEdited.replacingOccurrences(of: "8.0", with: #""wide""#))
    #expect(h.run("reload-settings").message == "settings reloaded; 2 problem(s), see `settings` and `rules`")
    #expect(h.controller.settings.gap == 12 && h.controller.settings.excludedBundleIDs == ["com.apple.Music"])

    try folder.write(handEdited.replacingOccurrences(of: "8.0", with: "20"))
    #expect(h.run("reload-settings").ok)
    #expect(h.controller.settings.gap == 20)
  }

  @Test func anEditThatWasNotReloadedSurvivesACommand() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    let edited = handEdited.replacingOccurrences(of: "8.0", with: "30")
      .replacingOccurrences(of: #"["com.apple.Music"]"#, with: #"["com.apple.Music", "com.apple.mail"]"#)
    try folder.write(edited)
    #expect(h.run("exclude com.apple.Notes").ok)
    #expect(
      try folder.read()
        == edited.replacingOccurrences(
          of: #""com.apple.mail"]"#, with: #""com.apple.mail", "com.apple.Notes"]"#))
  }

  @Test func withoutAFileOneIsWrittenThatHoldsOnlyWhatDiffersFromTheDefaults() throws {
    let folder = try Folder()
    #expect(SettingsFile.load(from: folder.file) == Settings())
    #expect(try folder.read() == "{\n  \"format\": 2\n}\n", "a file to edit, and no default in it (Q27)")

    try FileManager.default.removeItem(at: folder.file)
    var changed = Settings()
    changed.excludedBundleIDs = ["com.apple.Music"]
    try SettingsFile.update(from: Settings(), to: changed, at: folder.file)
    #expect(try SettingsFile.read(from: folder.file) == changed)
    #expect(try folder.read() == (try changed.fileText))
  }

  /// Somebody emptied it to start again, or a write was cut short.
  @Test(arguments: ["", "\n", "  \r\n\t"]) func aBlankFileCountsAsNoFile(blank: String) throws {
    let folder = try Folder()
    try folder.write(blank)
    #expect(SettingsFile.load(from: folder.file) == Settings())
    #expect(try folder.read() == (try Settings().fileText))

    try folder.write(blank)
    var changed = Settings()
    changed.gap = 3
    try SettingsFile.update(from: Settings(), to: changed, at: folder.file)
    #expect(try folder.read() == (try changed.fileText))
  }

  @Test func createLeavesAFileThatIsThereAlone() throws {
    let folder = try Folder()
    for text in [handEdited, "not json"] {
      try folder.write(text)
      SettingsFile.create(Settings(), at: folder.file)
      #expect(try folder.read() == text)
    }
  }

  @Test func aByteOrderMarkStays() throws {
    let folder = try Folder()
    try folder.write("\u{FEFF}" + handEdited)
    #expect(harness(folder).run("exclude com.apple.Notes").ok)
    let data = try Data(contentsOf: folder.file)
    #expect(data.starts(with: [0xEF, 0xBB, 0xBF, 0x7B]))
    #expect(
      try SettingsFile.read(from: folder.file).excludedBundleIDs == ["com.apple.Music", "com.apple.Notes"])
  }

  /// `JSONDecoder` reads UTF-16, so such a file always loaded. Arbor edits bytes, so it cannot change it.
  @Test func aFileInUTF16LoadsButIsNotChanged() throws {
    let folder = try Folder()
    let data = try #require(handEdited.data(using: .utf16))
    try data.write(to: folder.file)
    let h = harness(folder)
    #expect(h.controller.settings.gap == 8)
    let before = h.controller.settings
    #expect(
      h.run("exclude com.apple.Notes")
        == .failure(
          "settings.json could not be saved, so nothing was changed: "
            + "the file is not UTF-8 text, so Arbor cannot change it"))
    #expect(!h.run("set gap 20").ok)
    #expect(try Data(contentsOf: folder.file) == data)
    #expect(h.controller.settings == before, "what is in use is what the file says")
  }

  @Test func aLinkToNothingIsCalledThat() throws {
    let folder = try Folder()
    try FileManager.default.createSymbolicLink(
      at: folder.file, withDestinationURL: folder.url.appendingPathComponent("gone.json"))
    #expect(throws: Settings.FileError("it is a link to a file that does not exist")) {
      try SettingsFile.read(from: folder.file)
    }
    #expect(throws: Settings.FileError.self) {
      try SettingsFile.update(from: Settings(), to: Settings(), at: folder.file)
    }
  }

  /// Nothing is out of bounds to root, which is who runs the tests in the Linux container.
  @Test(.enabled(if: getuid() != 0)) func aFolderThatCannotBeWrittenToIsReportedInWords() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.url.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.url.path)
    }
    let message = harness(folder).run("exclude com.apple.Notes").message
    #expect(message.contains("so nothing was changed: the file cannot be written ("), "\(message)")
    #expect(!message.contains("Error Domain"), "\(message)")
  }

  @Test func theFolderIsMadeIfNeeded() throws {
    let folder = try Folder()
    let deep = folder.url.appendingPathComponent("a/b/settings.json")
    #expect(SettingsFile.load(from: deep) == Settings())
    #expect(FileManager.default.fileExists(atPath: deep.path))
  }

  /// Dotfile managers keep the real file elsewhere and put a link in its place.
  @Test func aLinkToTheFileStaysALink() throws {
    let folder = try Folder()
    let real = folder.url.appendingPathComponent("dotfiles-settings.json")
    try Data(handEdited.utf8).write(to: real)
    try FileManager.default.createSymbolicLink(at: folder.file, withDestinationURL: real)
    let h = harness(folder)
    #expect(h.controller.settings.gap == 8)
    #expect(h.run("exclude com.apple.Notes").ok)
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: folder.file.path) == real.path)
    #expect(
      String(decoding: try Data(contentsOf: real), as: UTF8.self).contains(
        #""com.apple.Music", "com.apple.Notes""#))
  }

  @Test func theFileKeepsItsPermissions() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: folder.file.path)
    #expect(harness(folder).run("exclude com.apple.Notes").message == "no longer arranging com.apple.Notes")
    #expect(try folder.read().contains("com.apple.Notes"))
    #expect(
      try FileManager.default.attributesOfItem(atPath: folder.file.path)[.posixPermissions] as? Int == 0o600)
  }

  /// Nothing is read-only to root, which is who runs the tests in the Linux container.
  @Test(.enabled(if: getuid() != 0)) func aReadOnlyFileIsRespected() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: folder.file.path)
    let h = harness(folder)
    #expect(
      h.run("exclude com.apple.Notes")
        == .failure("settings.json could not be saved, so nothing was changed: the file is read-only"))
    #expect(try folder.read() == handEdited)
    #expect(h.controller.settings.excludedBundleIDs == ["com.apple.Music"])
  }

  @Test func aFileThatIsNotTextIsLeftAlone() throws {
    let folder = try Folder()
    let bytes = Data([0x7B, 0xFF, 0xFE, 0x7D])
    try bytes.write(to: folder.file)
    #expect(throws: Settings.FileError("the file is not UTF-8 text")) {
      try SettingsFile.read(from: folder.file)
    }
    #expect(SettingsFile.load(from: folder.file) == Settings())
    var changed = Settings()
    changed.gap = 1
    #expect(throws: Settings.FileError.self) {
      try SettingsFile.update(from: Settings(), to: changed, at: folder.file)
    }
    #expect(try Data(contentsOf: folder.file) == bytes)
  }

  /// A folder stands in for a file that exists but cannot be opened.
  @Test func somethingThatCannotBeOpenedIsNotReplacedByTheDefaults() throws {
    let folder = try Folder()
    try FileManager.default.createDirectory(at: folder.file, withIntermediateDirectories: true)
    #expect(throws: Settings.FileError.self) { try SettingsFile.read(from: folder.file) }
    #expect(SettingsFile.load(from: folder.file) == Settings())
    var isDirectory: ObjCBool = false
    #expect(
      FileManager.default.fileExists(atPath: folder.file.path, isDirectory: &isDirectory)
        && isDirectory.boolValue)
  }

  // MARK: The settings commands (F12, criterion 1)

  /// Each command with what it does to the text of the file. Everything else stays, byte for byte.
  @Test(arguments: [
    ("set gap 20", #""gap": 8.0,"#, #""gap": 20,"#),
    ("set tabsEnabled on", "\"dock left\" }\n", "\"dock left\" },\n  \"tabsEnabled\": true\n"),
    ("reset gap", "\"gap\": 8.0,\n  ", ""),  // the file holds only what differs from the defaults (Q27)
    ("bind ctrl+opt+j dock right", #""dock left" }"#, #""dock left", "ctrl+opt+j": "dock right" }"#),
    ("bind ctrl+opt+h dock right", #""ctrl+opt+h": "dock left""#, #""ctrl+opt+h": "dock right""#),
    ("unbind ctrl+opt+h", #"{ "ctrl+opt+x": 5, "ctrl+opt+h": "dock left" }"#, #"{ "ctrl+opt+x": 5 }"#),
    ("unbind ctrl+opt+g", #""dock left" }"#, #""dock left", "ctrl+opt+g": null }"#),
    (
      "rule add com.apple.mail dock left title Inbox", "\"action\": \"float\" }\n",
      "\"action\": \"float\" },\n    { \"app\": \"com.apple.mail\", \"title\": \"Inbox\", \"action\": \"dock left\" }\n"
    ),
    ("rule change 1 com.apple.Notes ignore", #""com.apple.Notes", "action": "float""#, #""com.apple.Notes", "action": "ignore""#),
    ("rule remove 1", "\"dock sideways\" },\n    { \"app\": \"com.apple.Notes\", \"action\": \"float\" }\n", "\"dock sideways\" }\n"),
    ("exclude com.apple.Notes", #"["com.apple.Music"]"#, #"["com.apple.Music", "com.apple.Notes"]"#),
    ("include com.apple.Music", #"["com.apple.Music"]"#, "[]"),
  ]) func aCommandChangesOnlyWhatItIsAbout(command: String, before: String, after: String) throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    let result = h.run(command)
    #expect(result.ok, "\(result.message)")
    #expect(handEdited.components(separatedBy: before).count == 2, "the test's own text")
    #expect(try folder.read() == handEdited.replacingOccurrences(of: before, with: after))
    #expect(h.controller.takeInSettingsFile() == .unchanged, "what is in use is what the file says")
  }

  @Test func reportsOnWhatCouldNotBeReadFollowTheFile() throws {
    let folder = try Folder()
    try folder.write(
      #"{"format": 2, "rules": [{"app": "com.a", "action": "float"}, {"app": "com.b", "action": "dock sideways"}]}"#)
    let h = harness(folder)
    #expect(h.controller.settings.skippedRules.first?.hasPrefix("entry 2 (com.b): ") == true)
    #expect(h.run("rule remove 1").ok)
    #expect(try folder.read() == #"{"format": 2, "rules": [{"app": "com.b", "action": "dock sideways"}]}"#)
    #expect(h.controller.settings.skippedRules.first?.hasPrefix("entry 1 (com.b): ") == true)
    #expect(h.controller.takeInSettingsFile() == .unchanged)
  }

  @Test func resettingKeepsWhatArborDoesNotKnow() throws {
    let folder = try Folder()
    try folder.write(handEdited)
    let h = harness(folder)
    #expect(h.run("reset all").ok)
    #expect(try folder.read() == handEdited.replacingOccurrences(of: "\"gap\": 8.0,\n  ", with: ""))
    #expect(h.run("reset everything").ok)
    #expect(
      try folder.read() == """
        {
          "format": 2,
          "myNote": "ask Sam about the gap",
          "excludedBundleIDs": [],
          "rules": [
            { "app": "com.apple.Terminal", "action": "dock sideways" }
          ],
          "bindings": { "ctrl+opt+x": 5 }
        }

        """)
    #expect(!FileManager.default.fileExists(atPath: folder.url.appendingPathComponent("settings.unreadable.json").path))
  }

  @Test func resettingAlsoPutsRightWhatArborCouldNotUse() throws {
    let folder = try Folder()
    try folder.write(
      #"{"format": 2, "gap": "wide", "tabsEnabled": 1, "focusRingRadius": 99, "excludedBundleIDs": ["a", 5], "myNote": 1}"#)
    let h = harness(folder)
    #expect(h.controller.settings.valueProblems.count == 4)
    #expect(h.run("reset all") == .success("back to the default: gap, tabsEnabled, focusRingRadius"))
    #expect(try folder.read() == #"{"format": 2, "excludedBundleIDs": ["a", 5], "myNote": 1}"#)
    #expect(h.run("reset all") == .success("every setting is already the default"))
    #expect(h.run("exclude com.b").message.hasSuffix("is not a list Arbor can read, so it cannot be changed; fix it first"))
    #expect(h.run("reset everything") == .success("back to the default: excludedBundleIDs"))
    #expect(try folder.read() == #"{"format": 2, "excludedBundleIDs": [], "myNote": 1}"#)
    #expect(h.controller.settings == Settings())
    #expect(h.run("exclude com.b").ok)
  }

  @Test func anEntryIsNotWrittenIntoShortcutsArborCouldNotRead() throws {
    let folder = try Folder()
    let text = #"{"format": 2, "bindings": {"\x": "desktop", "ctrl+opt+h": "dock left"}}"#
    try folder.write(text)
    let h = harness(folder)
    #expect(
      h.run("bind ctrl+opt+j dock right")
        == .failure(
          "settings.json could not be saved, so nothing was changed: "
            + "`bindings` is not an object Arbor can read, so it cannot be changed; fix it first"))
    #expect(try folder.read() == text)
    #expect(h.run("reset bindings").ok)
    #expect(try folder.read() == #"{"format": 2, "bindings": {}}"#)
    #expect(h.run("bind ctrl+opt+j dock right").ok && h.run("get bindings").text == #"{"ctrl+opt+j":"dock right"}"#)
  }

  // MARK: The way out

  /// It loads, so nothing says it cannot be read; but no command can change it.
  @Test func resetEverythingAlsoReplacesAFileThatCannotBeChanged() throws {
    let folder = try Folder()
    let data = try #require(handEdited.data(using: .utf16))
    try data.write(to: folder.file)
    let h = harness(folder)
    #expect(!h.run("reset all").ok && h.controller.settings.gap == 8)
    #expect(h.run("reset everything").ok)
    #expect(try folder.read() == (try Settings().fileText))
    #expect(try Data(contentsOf: folder.url.appendingPathComponent("settings.unreadable.json")) == data)
    #expect(h.controller.settings == Settings() && h.run("set gap 20").ok)
  }

  @Test func resetEverythingMendsALinkToNothing() throws {
    let folder = try Folder()
    let gone = folder.url.appendingPathComponent("dotfiles/gone.json")
    try FileManager.default.createSymbolicLink(at: folder.file, withDestinationURL: gone)
    let h = harness(folder)
    #expect(h.run("set gap 20").message.contains("it is a link to a file that does not exist. Mend the file, or run `reset everything`"))
    #expect(h.run("reset everything") == .success("replaced settings.json with the defaults"))
    #expect(try FileManager.default.destinationOfSymbolicLink(atPath: folder.file.path) == gone.path)
    #expect(try String(contentsOf: gone, encoding: .utf8) == (try Settings().fileText))
    #expect(h.run("set gap 20").ok)
  }

  /// Through a link too, the copy is where the README says: beside settings.json, under that name.
  @Test func theCopyOfALinkedFileIsBesideTheLink() throws {
    let folder = try Folder()
    let real = folder.url.appendingPathComponent("dotfiles/arbor.json")
    try FileManager.default.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: real)
    try FileManager.default.createSymbolicLink(at: folder.file, withDestinationURL: real)
    #expect(harness(folder).run("reset everything").ok)
    #expect(try String(contentsOf: folder.url.appendingPathComponent("settings.unreadable.json"), encoding: .utf8) == "not json")
    #expect(try FileManager.default.contentsOfDirectory(atPath: real.deletingLastPathComponent().path) == ["arbor.json"])
  }

  /// A folder stands in for a file that cannot be written, which root can always do.
  @Test func aReplacementThatFailsCostsNeitherTheFileNorTheEarlierCopy() throws {
    let folder = try Folder()
    try folder.write("my only copy")
    let h = harness(folder)
    #expect(h.run("reset everything").ok)
    let aside = folder.url.appendingPathComponent("settings.unreadable.json")
    #expect(try String(contentsOf: aside, encoding: .utf8) == "my only copy")

    try FileManager.default.removeItem(at: folder.file)
    try FileManager.default.createDirectory(at: folder.file.appendingPathComponent("inside"), withIntermediateDirectories: true)
    #expect(!h.run("reset everything").ok)
    #expect(try String(contentsOf: aside, encoding: .utf8) == "my only copy")
    #expect(
      try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted()
        == ["settings.json", "settings.unreadable.json"])
  }

  // MARK: The log

  /// A rule's `title` is part of a window title, and titles are never logged. The marker is unlike anything
  /// another test logs meanwhile.
  @Test func noPartOfATitleReachesTheLog() throws {
    let marker = "Payroll\(UUID().uuidString.prefix(8))"
    let folder = try Folder()
    try folder.write("{}")
    let h = harness(folder)
    #expect(h.run("rule add com.apple.mail float title \(marker)").ok)
    #expect(h.run("bind ctrl+opt+j rule add com.apple.mail float title \(marker)").ok)
    for url in [
      "arbor://rule/add/com.apple.mail/float/title/\(marker)", "arbor://rule/add/com.apple.mail/\(marker)",
      "arbor://bind/ctrl+opt+x/rule/add/com.apple.mail/float/title/\(marker)", "ARBOR:RULE/\(marker)",
    ] {
      guard case .failure = h.controller.admit(url: url) else {
        Issue.record("\(url) was admitted")
        continue
      }
    }
    // A typo inside the title, met at launch, by the watcher, by `reload-settings` and by a command.
    try folder.write(#"{"rules": [{"app": "com.a", "title": "Salaries "\#(marker)" 2026", "action": "float"}]}"#)
    #expect(SettingsFile.load(from: folder.file) == Settings())
    #expect(h.controller.takeInSettingsFile() != .unchanged)
    for command in ["reload-settings", "exclude com.b", "set gap 20", "pass-through com.b"] {
      let result = h.run(command)
      #expect(!result.ok && result.message.contains(marker), "the reply goes to whoever wrote the file: \(command)")
    }
    // Every test writes to this log at once, and at 2 MB it becomes arbor.log.1 and a new one is started. So what was
    // written a moment ago is in one of the two. In this order: a line that moves between the two reads is read twice,
    // not missed. Decoded leniently, because the last line may still be in the writing.
    let log = [ArborPaths.logFile, ArborPaths.logFile.appendingPathExtension("1")]
      .compactMap { try? Data(contentsOf: $0) }.map { String(decoding: $0, as: UTF8.self) }.joined()
    #expect(log.contains("settings.json cannot be read, keeping the settings in use: line 1, column 49"))
    #expect(!log.contains(marker))
  }

  /// The same for a trace, which people send to others as they paste the log: it records replies.
  @Test func whatAReplyQuotesFromAFileThatCannotBeReadNeverReachesATrace() throws {
    let folder = try Folder()
    try folder.write(#"{"bindings": {"ctrl+opt+j": "set gap 30"}}"#)
    let h = harness(folder)
    h.system.open(app: "Safari")
    h.run("trace on typo")
    try folder.write(#"{"rules": [{"app": "com.a", "title": "Salaries "Redundancies" 2026", "action": "float"}]}"#)
    h.controller.settingsFileMayHaveChanged()
    var replies: [String] = []
    for command in ["reload-settings", "exclude com.b", "set gap 20", "pass-through com.b", "status"] { replies.append(h.run(command).message) }
    replies.append(h.key("ctrl+opt+j")?.message ?? "")
    h.scheduler.runPending()
    h.run("trace off")
    #expect(replies.filter { $0.contains("found `Redundancies`") }.count >= 5, "the premise: \(replies)")

    let text = h.lastTrace ?? ""
    for secret in ["Redundancies", "Salaries"] { #expect(!text.contains(secret), "\(secret)") }
    let done = try Trace(text: text).entries.compactMap { entry -> String? in
      if case .done("reload-settings", false, let message) = entry.line { message } else { nil }
    }
    // Where the typo is stays, and the mark says that a replay will say something else.
    #expect(done == ["≈ settings.json cannot be read, keeping the settings in use: line 1, column 49"])
  }

  @Test func aFileThatIsReplacedIsKeptBesideTheNewOne() throws {
    let folder = try Folder()
    let typo = handEdited.replacingOccurrences(of: #""gap": 8.0,"#, with: #""gap": 8.0"#)
    try folder.write(typo)
    let h = harness(folder)
    #expect(
      h.run("reset everything")
        == .success("replaced settings.json with the defaults; the file as it was is kept as settings.unreadable.json"))
    #expect(try folder.read() == (try Settings().fileText))
    let aside = folder.url.appendingPathComponent("settings.unreadable.json")
    #expect(try String(contentsOf: aside, encoding: .utf8) == typo)
    // The next one takes its place.
    try folder.write("not json")
    #expect(h.run("reset everything").ok)
    #expect(try String(contentsOf: aside, encoding: .utf8) == "not json")
  }

  @Test func aValueArborCouldNotUseStaysUntilItsKeyIsSet() throws {
    let folder = try Folder()
    let slip = handEdited.replacingOccurrences(of: "8.0", with: #""wide""#)
    try folder.write(slip)
    let h = harness(folder)
    #expect(h.controller.settings.valueProblems == ["gap: not a number; using the default, 12"])
    #expect(h.run("set tabsEnabled on").ok)
    #expect(try folder.read().contains(#""gap": "wide","#))
    #expect(h.run("set gap 20").ok)
    #expect(try folder.read().contains(#""gap": 20,"#))
    #expect(h.controller.settings.valueProblems.isEmpty)
  }

  /// "gap is already 12" would leave the slip in the file and the complaint in `settings`.
  @Test(arguments: [
    (#""wide""#, "set gap 12", nil), ("500", "set gap 100", "100"), (#""wide""#, "reset gap", nil), ("-3", "set gap 0", "0"),
  ]) func givingAKeyTheValueInUsePutsTheFileRight(written: String, command: String, saved: String?) throws {
    let folder = try Folder()
    try folder.write(handEdited.replacingOccurrences(of: "8.0", with: written))
    let h = harness(folder)
    #expect(h.controller.settings.valueProblems.count == 1)
    #expect(h.run(command).ok)
    // Nil: it is the default, which the file does not hold.
    let expected = saved.map { handEdited.replacingOccurrences(of: "8.0", with: $0) }
    #expect(try folder.read() == expected ?? handEdited.replacingOccurrences(of: "\"gap\": 8.0,\n  ", with: ""))
    #expect(h.controller.settings.valueProblems.isEmpty)
    // Now there is nothing left to put right.
    let number = try folder.fileNumber()
    #expect(h.run(command).message.contains("already"))
    #expect(try folder.fileNumber() == number)
  }

  @Test func withoutAnythingToSaveToCommandsStillWork() {
    let h = Harness()
    h.start()
    #expect(h.run("exclude com.apple.Notes").message == "no longer arranging com.apple.Notes")
    #expect(h.run("reload-settings").ok)
    #expect(h.controller.settings.excludedBundleIDs == ["com.apple.Notes"])
  }
}
