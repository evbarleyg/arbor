import ArborCore
import ArborKit
import Foundation
import Testing

/// The file in which Arbor writes down how macOS's switches were (`macos-settings-before.json`). It is all the way back there is.
@Suite struct MacSwitchLedgerTests {
  func makeLedger() throws -> MacSwitchLedger {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-ledger-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return MacSwitchLedger(file: folder.appendingPathComponent(MacSwitchLedger.fileName))
  }

  func text(_ ledger: MacSwitchLedger) throws -> String { try String(contentsOf: ledger.file, encoding: .utf8) }

  @Test func whatIsWrittenComesBack() throws {
    let ledger = try makeLedger()
    #expect(ledger.read() == [], "no file: nothing is owed")
    let records = [
      MacSwitchRecord(.clickWallpaper, stored: nil), MacSwitchRecord(.screenEdges, stored: true), MacSwitchRecord(.menuBar, stored: false),
    ]
    #expect(ledger.write(records))
    #expect(ledger.read() == records)
    // Another process, another day.
    #expect(MacSwitchLedger(file: ledger.file).read() == records)
  }

  /// By macOS's own names, so that whoever finds the file can put things back by hand.
  @Test func theFileSpeaksOfMacOSsOwnKeys() throws {
    let ledger = try makeLedger()
    #expect(ledger.write([MacSwitchRecord(.screenEdges, stored: nil), MacSwitchRecord(.optionKey, stored: true)]))
    let list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: ledger.file)) as? [[String: Any]])
    #expect(list.map { $0["key"] as? String } == ["EnableTilingByEdgeDrag", "EnableTilingOptionAccelerator"])
    #expect(list[0]["stored"] == nil && list[1]["stored"] as? Bool == true)
  }

  @Test func withNothingOwedThereIsNoFile() throws {
    let ledger = try makeLedger()
    #expect(ledger.write([MacSwitchRecord(.menuBar, stored: nil)]))
    #expect(ledger.write([]))
    #expect(!FileManager.default.fileExists(atPath: ledger.file.path))
    #expect(ledger.write([]), "nor is that a failure a second time")
  }

  /// Cut short, or edited by a hand that slipped. It says that something is owed, if not what: it is neither read as nothing nor written over.
  @Test(arguments: ["", "[{\"key\": \"EnableTil", "{}", "[1, 2]", "[{\"stored\": true}]", "null"])
  func aFileThatCannotBeReadIsNotNothingAndIsNotWrittenOver(damaged: String) throws {
    let ledger = try makeLedger()
    try damaged.write(to: ledger.file, atomically: true, encoding: .utf8)
    #expect(ledger.read() == nil)
    #expect(!ledger.write([MacSwitchRecord(.menuBar, stored: nil)]))
    #expect(!ledger.write([]))
    #expect(try text(ledger) == damaged)
  }

  /// A key that only another build of Arbor knows is that build's to put back.
  @Test func aKeyThisBuildDoesNotKnowStaysInTheFile() throws {
    let ledger = try makeLedger()
    try #"[{"key": "EnableSomethingNew", "stored": true}, {"key": "EnableTopTilingByEdgeDrag"}]"#
      .write(to: ledger.file, atomically: true, encoding: .utf8)
    #expect(ledger.read() == [MacSwitchRecord(.menuBar, stored: nil)])
    #expect(ledger.write([MacSwitchRecord(.menuBar, stored: nil), MacSwitchRecord(.optionKey, stored: nil)]))
    #expect(try text(ledger).contains("EnableSomethingNew"))
    #expect(ledger.read()?.count == 2)
    #expect(ledger.write([]))
    #expect(try text(ledger).contains("EnableSomethingNew"), "so the file stays")
    #expect(ledger.read() == [])
  }

  @Test func whereNothingCanBeWrittenItSaysSo() throws {
    let ledger = MacSwitchLedger(file: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/\(MacSwitchLedger.fileName)"))
    #expect(ledger.read() == [])
    #expect(!ledger.write([MacSwitchRecord(.menuBar, stored: nil)]))
  }
}
