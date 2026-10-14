import ArborCore
import ArborKit
import Foundation
import Testing

/// Window titles and the names people give are never logged. These are the roads by which what was typed could get there.
@Suite struct LogPrivacyTests {
  /// A shortcut in settings.json that cannot be read is logged at every start. The reason quotes the line, and the line can hold part of
  /// a window title or a name a person gave.
  @Test func aShortcutThatCannotBeReadLeavesNoPrivateWordInTheLog() {
    var settings = Settings()
    settings.bindings = [
      "ctrl+opt+1": "layout Safari~Zebra | |", "ctrl+opt+2": "layout Safari~Zebra --zebra | Mail", "ctrl+opt+3": "rule add com.x nonsense title Zebra",
      "ctrl+opt+4": "bind ctrl+opt+9 layout Safari~Zebra | |", "ctrl+opt+5": "/layout/Safari~Zebra | |", "ctrl+opt+6": "LAYOUT Safari~Zebra (",
      "ctrl+opt+7": "zom", "ctrl+opt+8": "bindings", "zebra+1": "home",
    ]
    let problems = KeyBindings.effective(settings: settings).problems
    #expect(problems.count == 9, "\(problems)")
    // This is the road: a person is told everything, in `bindings`.
    #expect(problems.filter { $0.localizedCaseInsensitiveContains("zebra") }.count >= 5, "\(problems)")
    let logged = KeyBindings.problemsForTheLog(problems, settings: settings)
    #expect(logged.count == 9)
    for line in logged where !line.hasPrefix("zebra+1") { #expect(!line.localizedCaseInsensitiveContains("zebra"), "\(line)") }
    for (shortcut, verb) in [("1", "layout"), ("2", "layout"), ("3", "rule"), ("4", "bind"), ("5", "layout"), ("6", "layout")] {
      #expect(logged.contains("ctrl+opt+\(shortcut): its `\(verb)` command; `bindings` says why"), "\(logged)")
    }
    // The others are as helpful as they were. A shortcut's own text is no secret.
    for prefix in ["ctrl+opt+7: ", "ctrl+opt+8: ", "zebra+1: "] {
      #expect(logged.first { $0.hasPrefix(prefix) } == problems.first { $0.hasPrefix(prefix) }, "\(prefix)")
    }
  }

  /// One list, for URLs that are refused and for shortcuts that cannot be read.
  @Test func theCommandsThatCanHoldPrivateWords() {
    for verb in ["rule", "bind", "layout", "name", "unname", "go", "Layout", "GO"] { #expect(Command.mayHoldPrivateWords(verb: verb), "\(verb)") }
    for verb in ["zoom", "dock", "summon", "bindings", "", "layouts"] { #expect(!Command.mayHoldPrivateWords(verb: verb), "\(verb)") }
  }
}
