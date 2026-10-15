import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// Q27 on disk: a `settings.json` from the days when the first launch wrote every default down is put right once, at a launch. What is
/// taken out and what stays is `SettingsFileFormatTests`' business; here it is the file, its copy, and the commands afterwards.
@Suite @MainActor struct SettingsFileUpgradeTests {
  typealias Folder = SettingsFileTests.Folder

  /// Out of such a file: three defaults of its day, one choice, one key Arbor does not know.
  static let old = """
    {
      "animationDuration" : 0.46,
      "gap" : 20,
      "gesturesEnabled" : true,
      "mine" : "a note",
      "pointerGestures" : false
    }

    """
  static let upgraded = """
    {
      "gap" : 20,
      "mine" : "a note",
      "format" : 2
    }

    """

  func copy(in folder: Folder) -> URL { folder.url.appendingPathComponent("settings.before-format-2.json") }

  /// A started harness whose commands read and write the file, as the app's do.
  func harness(_ folder: Folder) -> Harness {
    let file = folder.file
    let h = Harness(settings: SettingsFile.load(from: file))
    h.controller.saveSettings = { try SettingsFile.update(from: $0, to: $1, at: file) }
    h.controller.loadSettings = { try SettingsFile.read(from: file) }
    h.start()
    return h
  }

  @Test func atALaunchAnOldFileIsStrippedAndMarkedAndACopyIsKept() throws {
    let folder = try Folder()
    try folder.write(Self.old)
    var expected = Settings()
    expected.gap = 20
    #expect(SettingsFile.load(from: folder.file) == expected)
    #expect(try folder.read() == Self.upgraded)
    #expect(try String(contentsOf: copy(in: folder), encoding: .utf8) == Self.old)
  }

  @Test func theNextLaunchTouchesNothing() throws {
    let folder = try Folder()
    try folder.write(Self.old)
    _ = SettingsFile.load(from: folder.file)
    let number = try folder.fileNumber()
    try FileManager.default.removeItem(at: copy(in: folder))
    _ = SettingsFile.load(from: folder.file)
    #expect(try folder.fileNumber() == number, "not written again")
    #expect(!FileManager.default.fileExists(atPath: copy(in: folder).path), "and nothing to keep a copy of")
  }

  @Test func theFirstCopyStays() throws {
    // It is the one with the whole old file. Somebody who later puts a file without the mark in its place has that one upgraded too.
    let folder = try Folder()
    try folder.write(Self.old)
    _ = SettingsFile.load(from: folder.file)
    try folder.write(#"{"gap": 12, "peek": false}"#)
    #expect(!SettingsFile.load(from: folder.file).peek)
    #expect(try folder.read() == #"{"peek": false, "format": 2}"#)
    #expect(try String(contentsOf: copy(in: folder), encoding: .utf8) == Self.old)
  }

  @Test func theFileKeepsItsPermissions() throws {
    let folder = try Folder()
    try folder.write(Self.old)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: folder.file.path)
    _ = SettingsFile.load(from: folder.file)
    #expect(try folder.read() == Self.upgraded)
    #expect(try FileManager.default.attributesOfItem(atPath: folder.file.path)[.posixPermissions] as? Int == 0o600)
  }

  /// Nothing is read-only to root, which is who runs the tests in the Linux container.
  @Test(.enabled(if: getuid() != 0)) func whereNoCopyCanBeKeptNothingIsWritten() throws {
    let folder = try Folder()
    try folder.write(Self.old)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: folder.url.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.url.path) }
    #expect(SettingsFile.load(from: folder.file).gap == 20)
    #expect(try folder.read() == Self.old)
  }

  @Test func aReloadUpgradesNothing() throws {
    // Only a launch does: nobody's file changes under their hands while they edit it.
    let folder = try Folder()
    let h = harness(folder)
    try folder.write(Self.old)
    #expect(h.run("reload-settings").ok)
    #expect(h.controller.settings.gap == 20)
    #expect(try folder.read() == Self.old)
  }

  @Test(arguments: ["{\"gap\": 12,, }", "not json", "[1]"]) func aFileThatCannotBeReadIsLeftAsItIsWithoutACopy(text: String) throws {
    let folder = try Folder()
    try folder.write(text)
    #expect(SettingsFile.load(from: folder.file) == Settings())
    #expect(try folder.read() == text)
    #expect(!FileManager.default.fileExists(atPath: copy(in: folder).path))
  }

  /// Nothing is read-only to root, which is who runs the tests in the Linux container.
  @Test(.enabled(if: getuid() != 0)) func aFileThatMayNotBeWrittenIsReadAsItIs() throws {
    let folder = try Folder()
    try folder.write(Self.old)
    try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: folder.file.path)
    #expect(SettingsFile.load(from: folder.file).gap == 20)
    #expect(try folder.read() == Self.old)
    #expect(!FileManager.default.fileExists(atPath: copy(in: folder).path), "or there would be a new copy at every launch")
  }

  @Test func aLinkStaysALink() throws {
    // Dotfile managers keep the real file elsewhere.
    let folder = try Folder()
    let real = folder.url.appendingPathComponent("elsewhere.json")
    try Data(Self.old.utf8).write(to: real)
    try FileManager.default.createSymbolicLink(at: folder.file, withDestinationURL: real)
    _ = SettingsFile.load(from: folder.file)
    #expect(try String(contentsOf: real, encoding: .utf8) == Self.upgraded)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: folder.file.path)) != nil)
  }

  // MARK: Commands, on either kind of file

  @Test func setWritesOneKeyAndResetTakesItOutAgain() throws {
    let folder = try Folder()
    let h = harness(folder)
    #expect(try folder.read() == "{\n  \"format\": 2\n}\n")
    #expect(h.run("set gap 16").ok)
    #expect(try folder.read() == "{\n  \"format\": 2,\n  \"gap\": 16\n}\n")
    #expect(h.run("set pointerGestures \(!Settings().pointerGestures)").ok)
    #expect(try JSONText(try folder.read()).keys(at: []) == ["format", "gap", "pointerGestures"])
    #expect(h.run("reset gap").ok)
    #expect(h.run("reset pointerGestures").ok)
    #expect(try folder.read() == "{\n  \"format\": 2\n}\n")
  }

  @Test func setToTheVeryDefaultTakesTheKeyOutToo() throws {
    let folder = try Folder()
    try folder.write(Self.upgraded)
    let h = harness(folder)
    #expect(h.run("set gap \(Int(Settings().gap))").ok)
    #expect(try JSONText(try folder.read()).keys(at: []) == ["mine", "format"])
  }

  @Test func aDefaultThatHasChangedSinceReachesAnOldFile() throws {
    // The point of it all, on the one key whose default has changed since whole files were written: ⇧⌘ were the rectangle's keys.
    let folder = try Folder()
    try folder.write(#"{"frameRectangleModifier": "shift+cmd", "gap": 20}"#)
    let settings = SettingsFile.load(from: folder.file)
    #expect(settings.frameRectangleModifier == Settings().frameRectangleModifier && settings.gap == 20)
    #expect(try folder.read() == #"{"gap": 20, "format": 2}"#)
  }
}
