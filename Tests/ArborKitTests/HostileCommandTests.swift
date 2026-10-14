import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Command text from the socket, URLs and settings.json is whatever its author typed. None of it
/// may crash Arbor: it holds people's windows.
@Suite @MainActor struct HostileCommandTests {
  static let verbs = [
    "status", "state", "ascii", "help", "show-all", "out", "in", "neighbor", "back", "forward", "zoom", "zoom-node",
    "desktop", "save-view", "view", "dock", "float", "toggle-float", "arrange", "float-all", "resize", "exclude",
    "include", "relayout", "reload-settings", "quit", "bindings", "rules", "frame-rect",
    "focus", "swap", "equalize", "balance", "rotate", "mirror", "grow", "shrink", "move-to-display", "focus-display",
  ]

  static let words = [
    "", "0", "-0", "-1", "1", "9", "10", "101", "102", "w101", "n0", "n1", "n-1", "w", "n", "left", "right", "up", "down",
    "beside", "4294967295", "4294967296", "9223372036854775807", "9223372036854775808", "-9223372036854775808",
    "1e308", "-1e308", "1e-320", "inf", "-inf", "nan", "infinity", "0x10", "1_000", "+5", "１２", "٣", "1.5", ".5", "5.",
    "\u{0}", "\n", "\r\n", "\t", "\u{1B}[2J", "\u{202E}", "é", "🪟", "%s%n", "../..", "\"", "\\", "`", "$(quit)", "--help", "-h",
    String(repeating: "9", count: 400), String(repeating: "a", count: 70_000),
  ]

  @Test func noCombinationOfWordsCrashesParsingPrintingOrRunning() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    var parsed = 0
    func attempt(_ input: [String]) {
      guard let command = try? Command.parse(words: input) else { return }
      parsed += 1
      // What is logged, shown in `bindings` and saved must survive a round trip.
      #expect((try? Command.parse(command.text)) == command, "\(command)")
      h.controller.perform(command)
    }
    for verb in Self.verbs {
      attempt([verb])
      for first in Self.words {
        attempt([verb, first])
        attempt([verb, first, first, first, first])
        for second in Self.words.prefix(36) where second != first {
          attempt([verb, first, second])
          attempt([verb, first, "beside", second, "left"])
        }
      }
    }
    #expect(parsed > 500)
    for workspace in h.controller.workspaces.values { #expect(workspace.tree.invariantViolations().isEmpty) }
  }

  @Test func textIsSplitTheSameWayWhateverSeparatesTheWords() throws {
    #expect(throws: Command.ParseError.self) { try Command.parse("   ") }
    #expect(throws: Command.ParseError.self) { try Command.parse("///") }
    #expect(try Command.parse("  dock   left  ") == .dock(nil, .left))
    #expect(try Command.parse("dock\tleft") == .dock(nil, .left))
    #expect(try Command.parse("status\r") == .status)
  }
}
