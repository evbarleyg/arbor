import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import Foundation
import Testing

/// A word that occurs nowhere else is put wherever a person can write words of their own, in every shape such words can have, and is then
/// looked for in what people pass on: the trace and the log.
///
/// The other tests of traces know how the words are hidden, and hold each way of hiding to its promise. This one knows nothing. It is
/// for the fault nobody thought of: a trace hides the words in a command by reading the command's text again, so a limit that only the
/// reader of text has (a title may be 200 characters long, say) opens the hiding place for a command that was built in code, as the
/// settings window builds them, and never went through that reader.
@MainActor @Suite struct CanaryTests {
  nonisolated static let canary = "zqxcanary"

  /// What people's words can look like. Each holds the canary once at least, as a word of its own.
  nonisolated static let shapes: [String] = [
    canary,
    "\(canary) and more",
    "before \(canary)",
    canary.uppercased(),
    String(repeating: "filler ", count: 28) + canary,  // 205 characters
    canary + String(repeating: " filler", count: 31),  // 226
    String(repeating: "filler ", count: 150) + canary,  // over a thousand
    canary + String(repeating: " filler", count: 1500),  // over ten thousand
    String(repeating: "x", count: 300) + " " + canary,
    "\"\(canary)\"", "'\(canary)'", "\(canary) \"half", "\\\(canary)\\", "\(canary)\\",
    "\(canary)\nsecond line", "first line\n\(canary)", "\(canary)\ttab", "\(canary)\r\n",
    "-\(canary)", "--\(canary)", "title \(canary)", "\(canary) title", "title title \(canary)",
    "\(canary) | \(canary)", "\(canary) / x", "x~\(canary)", "x:\(canary)", "(\(canary))", "[\(canary)]", "\(canary)*2", "#\(canary)",
    "\(canary) é ü 漢字 🪟", "\u{200B}\(canary)", "\(canary)\u{00A0}x", "\u{202E}\(canary)",
    " \(canary) ", "  \(canary)", "\(canary)  twice  spaced",
    "title[1] \(canary)", "name-1 \(canary)", "[p1] \(canary)", "… \(canary)",
  ]

  /// Every command that carries a person's words, built in code around `words`. `TraceWordsTests` sees to it that this list is whole:
  /// a new command that takes words fails there until somebody has looked at it, and whoever does adds it here.
  static func commands(around words: String) -> [Command] {
    let rule = AppRule(app: "com.example.safari", title: words, action: .float)
    let slot = LayoutNotation.Space(.windows([WindowSlot(.app("Safari"), title: words)]))
    return [
      .name(words), .goToSpace(words), .unname(words), .find(words),
      .layout(LayoutNotation.Spec(root: slot), display: nil, open: false),
      .settings(.addRule(rule)), .settings(.changeRule(1, rule)),
      .settings(.bind(chord: "ctrl+opt+j", command: Command.goToSpace(words).text)),
      .settings(.bind(chord: "ctrl+opt+k", command: Command.find(words).text)),
      .settings(.bind(chord: "ctrl+opt+l", command: Command.settings(.addRule(rule)).text)),
      .settings(.bind(chord: "ctrl+opt+m", command: "go \(words)")),
      .settings(.bind(chord: "ctrl+opt+n", command: words)),
    ]
  }

  private func desk() -> Harness {
    let h = Harness()
    let safari = h.system.open(app: "Safari", title: "Something else")
    let notes = h.system.open(app: "Notes", title: "Shopping")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("rule add com.example.notes float")
    h.run("trace on canary")
    return h
  }

  private func log() throws -> String {
    ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + ((try? String(contentsOf: ArborPaths.logFile, encoding: .utf8)) ?? "")
  }

  @Test(arguments: shapes) func wordsInACommandBuiltInCodeReachNeitherTheTraceNorTheLog(words: String) throws {
    for (index, command) in Self.commands(around: words).enumerated() {
      for source in [CommandSource.script, .menu] {
        let h = desk()
        _ = h.controller.perform(command, from: source)
        // What has been set is also shown, listed, pressed and taken back.
        for line in ["rules", "bindings", "spaces", "settings", "doctor", "status", "undo", "redo", "key ctrl+opt+j", "key ctrl+opt+k", "key ctrl+opt+m"] { h.run(line) }
        h.run("trace off")
        let trace = try #require(h.lastTrace)
        #expect(!trace.lowercased().contains(Self.canary), "command \(index) from \(source), words \(words.prefix(60).debugDescription): \(Self.lines(of: trace))")
      }
    }
    #expect(!(try log()).lowercased().contains(Self.canary), "in arbor.log, words \(words.prefix(60).debugDescription)")
  }

  /// The same words as the title of a window and the name of a display, which no command carries.
  @Test(arguments: shapes) func wordsOfAWindowsTitleReachNeitherTheTraceNorTheLog(words: String) throws {
    let h = desk()
    let window = h.system.open(app: "Mail", title: words)
    h.run("dock \(window.rawValue) right")
    for line in ["state", "ascii", "layout --titles", "find", "menu", "zoom \(window.rawValue)", "show-all", "float \(window.rawValue)", "close \(window.rawValue)"] { h.run(line) }
    h.run("trace off")
    let trace = try #require(h.lastTrace)
    #expect(!trace.lowercased().contains(Self.canary), "words \(words.prefix(60).debugDescription): \(Self.lines(of: trace))")
    #expect(!(try log()).lowercased().contains(Self.canary), "in arbor.log, words \(words.prefix(60).debugDescription)")
  }

  /// The lines that hold it, cut short.
  private static func lines(of trace: String) -> [String] {
    trace.split(separator: "\n").filter { $0.lowercased().contains(canary) }.prefix(3).map { String($0.prefix(200)) }
  }
}
