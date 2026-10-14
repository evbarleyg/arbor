import ArborIPC
import ArborKit
import Foundation
import Testing

func temporaryFolder() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-tests-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

@Suite struct InstanceLockTests {
  @Test func theSecondArborIsRefusedAndToldWhoHoldsTheLock() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("arbor.lock").path
    let (first, second) = (InstanceLock(path: path), InstanceLock(path: path))
    #expect(first.acquire() == .acquired)
    #expect(first.acquire() == .acquired, "asking again changes nothing")
    #expect(second.acquire() == .held(by: getpid()))
    #expect(second.acquire(attempts: 2) == .held(by: getpid()))
  }

  @Test func theLockIsFreeAgainWhenItsHolderIsGoneAndAStaleFileMeansNothing() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("arbor.lock").path
    // Left by a process that was killed.
    try Data("99999\n".utf8).write(to: URL(fileURLWithPath: path))
    let first = InstanceLock(path: path)
    #expect(first.acquire() == .acquired)
    first.release()
    #expect(FileManager.default.fileExists(atPath: path), "deleting the file would let two processes lock two files")
    // Several attempts: a child that another test is starting at this moment shares every open
    // descriptor until it calls exec, which is when close-on-exec takes effect.
    do {
      let second = InstanceLock(path: path)
      #expect(second.acquire(attempts: 20) == .acquired)
    }
    #expect(InstanceLock(path: path).acquire(attempts: 20) == .acquired, "letting go of the object lets go of the lock")
  }

  @Test func aChildProcessDoesNotInheritTheLock() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("arbor.lock").path
    let first = InstanceLock(path: path)
    #expect(first.acquire() == .acquired)
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sleep")
    child.arguments = ["5"]
    try child.run()
    defer { child.terminate() }
    first.release()
    #expect(InstanceLock(path: path).acquire(attempts: 20) == .acquired)
  }

  @Test func aFolderThatCannotHoldALockDoesNotStopArbor() throws {
    guard case .unavailable = InstanceLock(path: "/nonexistent-\(UUID().uuidString)/arbor.lock").acquire() else {
      Issue.record("expected unavailable")
      return
    }
  }
}

@Suite struct RestartPolicyTests {
  @Test func twoRestartsThenARescueThenNothing() {
    #expect(RestartPolicy.decide(history: [], now: 1000) == .restart)
    #expect(RestartPolicy.decide(history: [990], now: 1000) == .restart)
    #expect(RestartPolicy.decide(history: [980, 990], now: 1000) == .rescue)
    #expect(RestartPolicy.decide(history: [970, 980, 990], now: 1000) == .giveUp)
  }

  @Test func accidentsFarApartAreUnrelated() {
    #expect(RestartPolicy.decide(history: [100, 200, 300], now: 100_000) == .restart)
    #expect(RestartPolicy.decide(history: [100, 200, 99_990], now: 100_000) == .restart)
    #expect(RestartPolicy.recent([100, 99_990], now: 100_000) == [99_990])
  }

  @Test func aClockSetBackOrForwardDoesNotCountOldRestartsForEver() {
    #expect(RestartPolicy.decide(history: [5000, 5010], now: 1000) == .restart)
    #expect(RestartPolicy.decide(history: [1010, 1020], now: 1000) == .rescue, "a few seconds back is still now")
  }

  @Test func theHistorySurvivesTheEnvironmentWhateverIsInIt() {
    #expect(RestartPolicy.history(from: RestartPolicy.text(for: [1_790_000_000.4, 1_790_000_060])) == [1_790_000_000, 1_790_000_060])
    #expect(RestartPolicy.history(from: nil).isEmpty)
    #expect(RestartPolicy.history(from: "").isEmpty)
    #expect(RestartPolicy.history(from: "banana,,nan,inf,12,-") == [12])
    #expect(RestartPolicy.history(from: String(repeating: "1,", count: 10_000)).count == 8)
    #expect(RestartPolicy.text(for: []) == "")
  }
}

@Suite struct HomeFolderTests {
  /// `~/Library/Application Support/Arbor`, or what Linux has for it.
  let thePersonsFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Arbor", isDirectory: true)

  @Test func onlyTheAppAndItsClientFindThePersonsFolderByThemselves() {
    for program in ["Arbor", "arborctl"] {
      #expect(ArborPaths.home(environment: [:], program: program) == thePersonsFolder)
      #expect(ArborPaths.home(environment: ["ARBOR_HOME": ""], program: program) == thePersonsFolder)
    }
    for guest in ["xctest", "swiftpm-testing-helper", "arborPackageTests.xctest", "arbor-sim", "arbor-e2e", "arbor", ""] {
      let home = ArborPaths.home(environment: [:], program: guest)
      #expect(home.path.hasPrefix(FileManager.default.temporaryDirectory.path), "\(guest) would use \(home.path)")
      #expect(ArborPaths.home(environment: ["ARBOR_HOME": ""], program: guest) == home)
    }
  }

  @Test func whoeverIsToldAFolderUsesIt() {
    for program in ["Arbor", "arborctl", "xctest", "arbor-sim"] {
      #expect(ArborPaths.home(environment: ["ARBOR_HOME": "/tmp/arbor-told"], program: program).path == "/tmp/arbor-told")
    }
  }

  /// What the rule is for: this very process logs tens of thousands of lines.
  @Test func theseTestsAreGuests() {
    guard (ProcessInfo.processInfo.environment["ARBOR_HOME"] ?? "").isEmpty else { return }
    #expect(ArborPaths.home != thePersonsFolder)
    #expect(!ArborPaths.logFile.path.hasPrefix(thePersonsFolder.path))
  }

  func mode(_ url: URL) throws -> Int {
    try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
  }

  @Test func theFolderIsMadeForItsOwnerOnly() throws {
    let parent = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: parent) }
    let home = parent.appendingPathComponent("a/b/Arbor")
    try ArborPaths.secure(folder: home)
    #expect(try mode(home) == 0o700)
  }

  @Test func anExistingFolderOpenToOthersIsClosed() throws {
    let home = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.setAttributes([.posixPermissions: 0o777], ofItemAtPath: home.path)
    try ArborPaths.secure(folder: home)
    #expect(try mode(home) == 0o700)
  }

  @Test func aFolderSomebodyElseMadeIsRefused() throws {
    let home = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: home) }
    // Only root can give a folder away; elsewhere use one that is root's already.
    let foreign = geteuid() == 0 ? home : URL(fileURLWithPath: "/")
    if geteuid() == 0 { #expect(chown(home.path, 12345, 12345) == 0) }
    #expect(throws: ArborPaths.Problem.self) { try ArborPaths.secure(folder: foreign) }
  }
}
