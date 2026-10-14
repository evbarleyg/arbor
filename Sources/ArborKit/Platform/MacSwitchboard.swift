import ArborCore
import Foundation

/// How a switch of macOS's was stored before Arbor changed it, so that it can be put back exactly.
public struct MacSwitchRecord: Equatable, Sendable {
  public var item: MacSwitch
  /// Nil: nothing was stored, as on a Mac whose owner never touched the switch, and macOS went by its default.
  public var stored: Bool?

  public init(_ item: MacSwitch, stored: Bool?) {
    self.item = item
    self.stored = stored
  }
}

/// macOS's own switches under System Settings → Desktop & Dock, for the one step Arbor offers to take for a person
/// (`fix-setup`, Controller+FixSetup.swift) and for the way back. Which switches, when, and what is said about it is
/// decided in the controller; this only reads and writes. `SystemMacSwitchboard` is the real one, `FakeMacSwitchboard`
/// stands in for it in tests.
@MainActor
public protocol MacSwitchboard: AnyObject {
  /// What is stored for a switch. Nil: nothing is, and macOS goes by its default.
  func stored(_ item: MacSwitch) -> Bool?
  /// Stores a value for a switch; nil removes what is stored. macOS goes by it within a second, with nothing restarted (see
  /// `SystemMacSwitchboard`). Whether it kept the value is found out by asking again.
  func store(_ value: Bool?, for item: MacSwitch)
  /// How the switches that Arbor changed were before; empty when it owes nothing. Nil: something is written down that cannot be
  /// read, which is not the same as nothing.
  func records() -> [MacSwitchRecord]?
  /// Writes that down in place of what was there. False if it could not be. Kept apart from the saved arrangement and the settings
  /// (`MacSwitchLedger`): it has to outlast a quit, `reset everything` and a state file that was set aside, or there would be no way back.
  func keep(_ records: [MacSwitchRecord]) -> Bool
}

/// The file in which Arbor writes down how macOS's switches were before it changed them: `macos-settings-before.json`, beside the
/// settings and the saved arrangement and part of neither.
///
/// A list of `{"key": "EnableTilingByEdgeDrag", "stored": true}`, without `stored` where nothing was stored: by macOS's own names, so
/// that whoever finds the file can put things back by hand (`defaults delete com.apple.WindowManager <key>`). No file: nothing is owed.
public struct MacSwitchLedger: Sendable {
  public static let fileName = "macos-settings-before.json"
  public let file: URL

  public init(file: URL) { self.file = file }

  /// Nil if there is a file that cannot be read as such a list: what it says is owed all the same.
  public func read() -> [MacSwitchRecord]? {
    entries()?.compactMap { entry in
      Self.item(of: entry).map { MacSwitchRecord($0, stored: entry["stored"] as? Bool) }
    }
  }

  /// False if it could not be written, or if what is there cannot be read and so must not be written over.
  public func write(_ records: [MacSwitchRecord]) -> Bool {
    guard let old = entries() else { return false }
    // A key that only another build of Arbor knows is that build's to put back. It stays.
    let list =
      old.filter { Self.item(of: $0) == nil }
      + records.map { record in
        var entry: [String: Any] = ["key": record.item.defaultsKey]
        if let stored = record.stored { entry["stored"] = stored }
        return entry
      }
    do {
      if list.isEmpty {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
      } else {
        try JSONSerialization.data(withJSONObject: list, options: [.prettyPrinted, .sortedKeys]).write(to: file, options: .atomic)
      }
      return true
    } catch {
      return false
    }
  }

  private func entries() -> [[String: Any]]? {
    guard FileManager.default.fileExists(atPath: file.path) else { return [] }
    guard let data = try? Data(contentsOf: file), let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
      list.allSatisfy({ $0["key"] is String })
    else { return nil }
    return list
  }

  private static func item(of entry: [String: Any]) -> MacSwitch? {
    MacSwitch.allCases.first { $0.defaultsKey == entry["key"] as? String }
  }
}
