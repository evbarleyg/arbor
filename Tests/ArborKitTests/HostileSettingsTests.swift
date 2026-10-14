import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// settings.json is edited by hand. Whatever numbers it holds, Arbor must start, run and quit.
@Suite @MainActor struct HostileSettingsTests {
  nonisolated static let numbers: [Double] = [0, -1, -0.5, 0.5, 1, 1e-300, 1e9, -1e9, 1e300, -1e300, .greatestFiniteMagnitude]
  /// Every setting that is a number, read off the defaults as they are written to a file: a list kept by hand had seven
  /// of them when there were already three times as many.
  nonisolated static let keys: [String] = {
    guard let data = try? JSONEncoder().encode(Settings()),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [] }
    // In JSON as Foundation reads it a Bool is an NSNumber too.
    return object.filter { $0.value is NSNumber && !($0.value is Bool) }.keys.sorted()
  }()

  @Test func theListIsNotEmpty() {
    #expect(Self.keys.count >= 15, "\(Self.keys)")
    for key in ["gap", "minimumUsableWidth", "pinchThreshold", "arrangeDesktopWeight"] { #expect(Self.keys.contains(key)) }
  }

  @Test(arguments: keys) func anyNumberInAnyKeyIsSurvivable(key: String) throws {
    for number in Self.numbers {
      let data = try JSONSerialization.data(withJSONObject: [key: number])
      let settings = try JSONDecoder().decode(Settings.self, from: data)
      let h = Harness(settings: settings)
      // Like real windows, these refuse to vanish: a gap that takes all the room leaves slots of no size.
      let smallest = CGSize(width: 120, height: 80)
      let a = h.system.open(app: "Safari", minimumSize: smallest)
      let b = h.system.open(app: "Notes", minimumSize: smallest)
      let c = h.system.open(app: "Mail", minimumSize: smallest)
      h.start()
      for command in [
        "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(a.rawValue) bottom", "ascii", "state",
        "zoom \(a.rawValue)", "back", "in", "out", "resize \(a.rawValue) right 50", "arrange", "ascii", "desktop", "show-all",
        "frame-rect 0 0 700 800", "hold 1", "release", "summon Mail", "pin \(c.rawValue)", "pause 1", "resume", "float-all",
      ] { h.run(command) }
      h.system.drag(a, through: [CGPoint(x: 400, y: 300), CGPoint(x: 5, y: 400)])
      h.scheduler.runPending()
      _ = try JSONEncoder().encode(h.controller.snapshot())
      h.controller.shutdown()
      for window in [a, b, c] { #expect(h.system.isVisible(window), "\(key) = \(number): \(window) at \(h.frame(window)!)") }
    }
  }

  /// The same numbers where a display has them for itself (F25).
  @Test(arguments: ["gap", "minimumUsableWidth", "minimumUsableHeight", "screenEdgeBand"])
  func anyNumberForOneDisplayIsSurvivable(key: String) throws {
    for number in Self.numbers {
      for match in [">=1", "builtin", "", "<=0", ">=1e300"] {
        let data = try JSONSerialization.data(withJSONObject: ["displays": [["match": match, key: number]]])
        guard let settings = try? JSONDecoder().decode(Settings.self, from: data) else { continue }
        let h = Harness(settings: settings)
        let smallest = CGSize(width: 120, height: 80)
        let a = h.system.open(app: "Safari", minimumSize: smallest)
        let b = h.system.open(app: "Notes", minimumSize: smallest)
        h.start()
        for command in [
          "dock \(a.rawValue) left", "dock \(b.rawValue) right", "ascii", "state", "displays", "zoom \(a.rawValue)", "back",
          "resize \(a.rawValue) right 50", "arrange", "desktop", "show-all", "settings", "doctor", "float-all",
        ] { h.run(command) }
        h.system.drag(a, through: [CGPoint(x: 400, y: 300), CGPoint(x: 5, y: 400)])
        h.scheduler.runPending()
        _ = try JSONEncoder().encode(h.controller.snapshot())
        h.controller.shutdown()
        for window in [a, b] { #expect(h.system.isVisible(window), "\(match) \(key) = \(number): \(window) at \(h.frame(window)!)") }
      }
    }
  }
}
