import ArborKit
import Foundation
import Testing

@Suite struct LogTests {
  // MARK: What may be written

  @Test func ordinaryMessagesAreLeftAlone() {
    for message in ["dock 101 left: docked w101 at the left edge", "shortcuts in use: ⌃⌥Space ⌃⌥↩", "café 窓 🪟", ""] {
      #expect(Log.sanitized(message) == message)
    }
  }

  @Test func textFromOutsideCannotForgeLinesOrDriveATerminal() {
    #expect(Log.sanitized("a\nb") == "a\\u{A}b")
    #expect(Log.sanitized("a\r\n2026-10-14T00:00:00Z INFO  all is well") == "a\\u{D}\\u{A}2026-10-14T00:00:00Z INFO  all is well")
    #expect(Log.sanitized("\u{1B}[2J\u{7}\u{0}\u{7F}\u{9B}") == "\\u{1B}[2J\\u{7}\\u{0}\\u{7F}\\u{9B}")
    #expect(Log.sanitized("x\u{2028}y\u{2029}z\u{202E}w") == "x\\u{2028}y\\u{2029}z\\u{202E}w")
  }

  @Test func longMessagesAreCutAndSaySo() {
    let cut = Log.sanitized(String(repeating: "a", count: 70_000))
    #expect(cut.count < 1100)
    #expect(cut.hasSuffix("… (69000 more)"))
  }

  // MARK: The file

  func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  func size(_ url: URL) -> Int { (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0 }

  @Test func theLogIsRotatedWhileRunningAndKeepsOneOldFile() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("arbor.log")
    let log = LogFile(url: url, limit: 4096)
    for index in 0..<1000 { log.append("INFO  line \(index)") }
    #expect(size(url) <= 4096)
    #expect(size(log.previousURL) <= 4096 && size(log.previousURL) > 2048)
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == ["arbor.log", "arbor.log.1"])
    let recent = try String(contentsOf: log.previousURL, encoding: .utf8) + String(contentsOf: url, encoding: .utf8)
    #expect(recent.hasSuffix("line 999\n"))
    let numbers = recent.split(separator: "\n").compactMap { Int($0.split(separator: " ").last ?? "") }
    #expect(numbers == Array((1000 - numbers.count)..<1000), "no line is lost or split at the change of file")
  }

  @Test func aLogLeftOverTheLimitByAnEarlierRunIsRotatedAtTheFirstLine() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("arbor.log")
    try Data(repeating: UInt8(ascii: "x"), count: 10_000).write(to: url)
    let log = LogFile(url: url, limit: 4096)
    log.append("INFO  hello")
    #expect(size(url) < 100)
    #expect(size(log.previousURL) == 10_000)
  }

  @Test func twoWritersAppendRatherThanOverwrite() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("arbor.log")
    let (first, second) = (LogFile(url: url), LogFile(url: url))
    for index in 0..<50 {
      first.append("INFO  first \(index)")
      second.append("INFO  second \(index)")
    }
    #expect(try String(contentsOf: url, encoding: .utf8).split(separator: "\n").count == 100)
  }

  @Test func onlyTheOwnerCanReadTheLog() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("arbor.log")
    LogFile(url: url).append("INFO  hello")
    let mode = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
    #expect(mode & 0o077 == 0, "mode \(String(mode, radix: 8))")
  }

  @Test func aFolderThatCannotBeWrittenAFullDiskOrASymbolicLinkLosesLinesAndNothingElse() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    // A file where the folder should be.
    let blocked = folder.appendingPathComponent("file")
    try Data().write(to: blocked)
    LogFile(url: blocked.appendingPathComponent("arbor.log")).append("INFO  nowhere to go")

    // /dev/full fails every write with "no space left on device" (Linux only).
    if FileManager.default.fileExists(atPath: "/dev/full") {
      let full = LogFile(url: URL(fileURLWithPath: "/dev/full"))
      for _ in 0..<3 { full.append("INFO  the disk is full") }
    }

    let target = folder.appendingPathComponent("victim")
    try Data("precious".utf8).write(to: target)
    let link = folder.appendingPathComponent("arbor.log")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    LogFile(url: link).append("INFO  through the link")
    #expect(try String(contentsOf: target, encoding: .utf8) == "precious")
  }
}
