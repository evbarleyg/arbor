import Foundation
import Testing

@testable import ArborCore

/// Only a `settings.json` that looks whole is taken for an early build's (collab/QUESTIONS.md, Q27, as ruled again on 2026-10-15).
///
/// Q27 was about a file Arbor wrote: every default in it, unasked. A file without the mark that holds a few keys is somebody's own. Until the
/// defaults changed nobody could see the difference. Then `{"focusRing": true}`, written by hand, held until the next launch and
/// went, because true is what the first build wrote down too; and a reload honoured what a launch stripped.
@Suite struct OnlyAWholeFileIsStrippedTests {
  /// The keys such files held, those whose defaults have changed since first, each with the value the first build wrote.
  static let written: [(key: String, value: String)] = {
    let table = try! JSONText(Settings.defaultsOfOldFiles)
    let first = ["focusRing", "animationDuration", "menuBarControls", "dimBehindArranged", "desktopEdge"]
    let keys = first + (table.keys(at: []) ?? []).filter { !first.contains($0) }
    return keys.map { ($0, table.elements(at: [$0])![0]) }
  }()

  /// A file without the mark that holds the first `count` of them, and `more`.
  static func file(of count: Int, and more: [String] = []) -> String {
    "{\n" + (written.prefix(count).map { "  \"\($0.key)\": \($0.value)" } + more).joined(separator: ",\n") + "\n}\n"
  }

  /// The numbers the settings' page and the ruling say. The tests below say them in so many words, so that a changed constant shows.
  @Test func sixteenOfTheKeysSuchFilesHeldMakeAFileWhole() throws {
    #expect(Self.written.count == 68)
    #expect(Settings.leastKeysOfAWholeFile == 16)
  }

  @Test(arguments: [1, 5, 15]) func aFileOfAFewKeysIsSomebodysOwn(count: Int) throws {
    let text = Self.file(of: count)
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(upgraded.stripped.isEmpty)
    #expect(try JSONText(upgraded.text).keys(at: []) == Self.written.prefix(count).map(\.key) + ["format"], "it only gets the mark")
    // What was written is what is in use, though every value is what an early build wrote too.
    let read = try Settings.read(upgraded.text)
    #expect(read.focusRing)
    if count >= 5 {
      #expect(read.animationDuration == 0.46 && read.menuBarControls && read.dimBehindArranged == 0.25 && read.desktopEdge == 0.05)
    }
    // A reload reads the file as it lies there, a launch as it is afterwards. They end the same.
    #expect(try Settings.read(text) == read)
    #expect(try Settings.upgradedFile(upgraded.text) == nil, "once")
  }

  /// Thirty: a file holds the keys of the build that first launched on that Mac, and an older build had fewer than the first one handed out.
  @Test(arguments: [16, 30, 68]) func aFileThatLooksWholeIsAnEarlyBuilds(count: Int) throws {
    let upgraded = try #require(try Settings.upgradedFile(Self.file(of: count)))
    #expect(upgraded.stripped == Self.written.prefix(count).map(\.key).sorted())
    #expect(try JSONText(upgraded.text).keys(at: []) == ["format"])
    #expect(try Settings.read(upgraded.text) == Settings(), "it follows the defaults of today")
  }

  /// The copy from before the upgrade, put back by hand, is whole: it is upgraded again. docs/SETTINGS.md says what to do instead.
  @Test func theWholeFileOfTheFirstBuildIsStrippedAsEver() throws {
    #expect(try Settings.upgradedFile(SettingsFileFormatTests.wholeFile)?.stripped.count == 68)
  }

  /// Somebody tidied a whole file by hand and changed a value or two. It is still Arbor's writing.
  @Test func aWholeFileWithSomeKeysTakenOutAndSomeChangedIsStillWhole() throws {
    let text = Self.file(of: 60).replacingOccurrences(of: "\"gap\": 12", with: "\"gap\": 20")
      .replacingOccurrences(of: "\"animationDuration\": 0.46", with: "\"animationDuration\": 0.8")
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(try JSONText(upgraded.text).keys(at: []) == ["animationDuration", "gap", "format"])
    let read = try Settings.read(upgraded.text)
    #expect(read.gap == 20 && read.animationDuration == 0.8 && !read.focusRing)
  }

  // MARK: What counts

  @Test func keysArborDoesNotKnowMakeNoFileWhole() throws {
    let notes = (1...40).map { "  \"note\($0)\": \($0)" }
    #expect(try Settings.upgradedFile(Self.file(of: 15, and: notes))?.stripped == [])
  }

  /// Nor do keys that came after the mark, which no such file can hold.
  @Test func keysThatCameLaterMakeNoFileWhole() throws {
    let known = Set(Self.written.map(\.key))
    let later = SettingsSchema.entries.map(\.key).filter { !known.contains($0) }
    try #require(!later.isEmpty, "or this proves nothing")
    let text = Self.file(of: 15, and: try later.map { "  \"\($0)\": \(try #require(try Settings.canonical(Settings()).value(at: [$0])))" })
    #expect(try Settings.upgradedFile(text)?.stripped == [])
  }

  @Test func aKeyWrittenTwiceCountsOnce() throws {
    let twice = Self.written.prefix(2).map { "  \"\($0.key)\": \($0.value)" }
    #expect(try Settings.upgradedFile(Self.file(of: 15, and: twice))?.stripped == [])
  }

  /// A key is there whatever stands behind it: a value Arbor cannot use is somebody's slip in a file that is Arbor's writing all the same.
  @Test func aKeyWithAValueArborCannotUseCounts() throws {
    let text = Self.file(of: 16).replacingOccurrences(of: "\"focusRing\": true", with: "\"focusRing\": \"yes\"")
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(try JSONText(upgraded.text).keys(at: []) == ["focusRing", "format"], "and stays for whoever wrote it")
  }

  // MARK: A command writes into it

  /// Found by a reader who played it: `{"focusRing": true}` put there while Arbor runs, then `set` after `set`. The file grew, without
  /// the mark, until it looked whole, and the next launch took five keys out of it again, each asked for by command.
  @Test func theFirstCommandThatWritesIntoSomebodysOwnFileMarksIt() throws {
    var (text, settings) = (#"{"focusRing": true}"#, try Settings.read(#"{"focusRing": true}"#))
    for (key, value) in Self.written.dropFirst() {
      var next = settings
      let entry = try SettingsSchema.entry(named: key)
      guard let parsed = try? entry.parse(value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))) else { continue }
      try entry.set(parsed, in: &next)
      text = try Settings.rewriteAndMark(text, from: settings, to: next)
      settings = next
    }
    #expect(try JSONText(text).keys(at: [])?.contains("format") == true)
    #expect(try Settings.upgradedFile(text) == nil, "so a launch takes nothing out of it")
    let read = try Settings.read(text)
    #expect(read.focusRing && read.animationDuration == 0.46 && read.menuBarControls && read.dimBehindArranged == 0.25)
  }

  /// Fifteen keys are somebody's own, and the command writes the sixteenth. Judged by what the command left, the file would look whole.
  @Test func itGoesByTheFileAsItWasLeft() throws {
    let text = Self.file(of: 15)
    let old = try Settings.read(text)
    let few = Self.written.prefix(15).map(\.key)
    #expect(!few.contains("makeRoom") && Self.written.contains { $0.key == "makeRoom" } && old.makeRoom, "or the line below writes no sixteenth")
    var new = old
    new.makeRoom = false
    let written = try Settings.rewriteAndMark(text, from: old, to: new)
    #expect(try JSONText(written).keys(at: []).map(Set.init) == Set(few + ["makeRoom", "format"]), "nothing went")
    #expect(try Settings.upgradedFile(written) == nil, "and nothing goes at the next launch")
    let read = try Settings.read(written)
    #expect(read.focusRing && read.animationDuration == 0.46 && !read.makeRoom)
  }

  /// The mark is laid out like what is there, also where the command takes the only member out.
  @Test func theMarkIsWrittenAsTheFileIsWritten() throws {
    let ring = try Settings.read(#"{"focusRing": true}"#)
    #expect(try Settings.rewriteAndMark(#"{"focusRing": true}"#, from: ring, to: Settings()) == #"{"format": 2}"#)
    #expect(try Settings.rewriteAndMark("{\n    \"focusRing\" :true\n}\n", from: ring, to: Settings()) == "{\n    \"format\" :2\n}\n")
    var wider = ring
    wider.gap = 21
    #expect(
      try Settings.rewriteAndMark(#"{"focusRing": true}"#, from: ring, to: wider) == #"{"focusRing": true, "format": 2, "gap": 21}"#)
  }

  @Test func aWholeFileOfAnEarlyBuildStaysForTheNextLaunch() throws {
    let text = SettingsFileFormatTests.wholeFile
    let old = try Settings.read(text)
    var new = old
    new.gap = 21
    let written = try Settings.rewriteAndMark(text, from: old, to: new)
    #expect(try JSONText(written).keys(at: [])?.contains("format") == false)
    #expect(try Settings.upgradedFile(written).map { try JSONText($0.text).keys(at: []) } == ["gap", "format"])
  }

  @Test func aCommandThatChangesNothingWritesNothing() throws {
    let text = #"{"focusRing": true}"#
    let settings = try Settings.read(text)
    #expect(try Settings.rewriteAndMark(text, from: settings, to: settings) == text)
  }

  // MARK: However it is written

  /// The tests of how a file is stripped show it on files of a few lines, with the rule set aside. Here by the rule, on the file as the
  /// first build left it, saved again by an editor on another system.
  @Test func aWholeFileWithAByteOrderMarkAndOtherLineEndsIsStrippedAllTheSame() throws {
    let text = "\u{FEFF}" + SettingsFileFormatTests.wholeFile.replacingOccurrences(of: "\n", with: "\r\n")
    let upgraded = try #require(try Settings.upgradedFile(text))
    #expect(upgraded.stripped.count == Self.written.count)
    #expect(upgraded.text.hasPrefix("\u{FEFF}{\r\n") && !upgraded.text.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    #expect(try JSONText(upgraded.text).keys(at: []) == ["format"])
  }

  // MARK: What stays as it was

  @Test func anEmptyFileGetsTheMark() throws {
    let upgraded = try #require(try Settings.upgradedFile("{}"))
    #expect(try JSONText(upgraded.text).keys(at: []) == ["format"] && upgraded.stripped.isEmpty)
  }

  @Test func aSmallFileStaysByteForByte() throws {
    let text = "{\n    \"focusRing\" :true,\n  \"theirs\": [1,  2]\n}\n"
    #expect(try Settings.upgradedFile(text)?.text == "{\n    \"focusRing\" :true,\n  \"theirs\": [1,  2],\n    \"format\" :2\n}\n")
  }

  @Test func aSmallFileArborCannotReadIsLeftAlone() throws {
    #expect(throws: Settings.FileError.self) { try Settings.upgradedFile(#"{"focusRing": true,, "gap": 12}"#) }
  }
}
