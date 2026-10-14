import ArborCore
import Foundation
import Testing

/// `help <command>`, "did you mean" and completions, all of which are read out of the help text.
@Suite struct CommandHelpTests {
  @Test func everyEntryOfTheHelpIsRead() {
    #expect(Command.helpEntries.count > 20)
    for entry in Command.helpEntries {
      #expect(!entry.usages.isEmpty)
      #expect(["Look", "Arrange", "Arbor itself", "Settings"].contains(entry.section), "\(entry)")
      // A usage that swallowed its description would have prose in it. The help needs two spaces between them, or the description in its column.
      for usage in entry.usages { #expect(usage.split(separator: " ").count <= 7, "\(usage)") }
    }
    // A usage that fills its column to the last place, one that runs past it, and one with no description at all.
    let reset = Command.helpEntries.first { $0.verbs.contains("reset") }
    #expect(reset?.usages == ["reset <key>", "reset all", "reset everything"])
    #expect(reset?.description.hasPrefix("back to the defaults") == true)
    #expect(Command.helpEntries.first { $0.usages.first?.hasPrefix("rule add") == true }?.description.hasPrefix("add a rule; actions: float") == true)
    #expect(Command.helpEntries.first { $0.usages.first?.hasPrefix("rule change") == true }?.usages.count == 3)
    #expect(Command.helpEntries.first { $0.usages.contains("trace off") }?.description.hasPrefix("record what macOS and Arbor tell each other") == true)
    #expect(Command.helpEntries.first { $0.verbs == ["out", "in"] }?.description.hasPrefix("step out a level | step in") == true)
    #expect(Command.helpEntries.first { $0.verbs == ["save-view", "view"] }?.usages == ["save-view <1-9>", "view <1-9>"])
    #expect(Command.helpEntries.contains { $0.usages == ["layout [@display] [--titles | --ids]"] })
    #expect(Command.helpEntries.first { $0.verbs.contains("pause") }?.description.hasSuffix("for that many minutes") == true)
  }

  @Test func everyVerbInTheHelpIsACommand() {
    #expect(Set(Command.verbs).count == Command.verbs.count)
    for verb in Command.verbs {
      // It parses, or fails for want of arguments; what it must not be is unknown.
      do {
        _ = try Command.parse(verb)
      } catch {
        #expect(!"\(error)".hasPrefix("unknown command"), "\(verb): \(error)")
      }
    }
  }

  @Test func aliasesMeanWhatTheirCommandMeans() throws {
    for (verb, aliases) in Command.aliases {
      #expect(Command.verbs.contains(verb), "\(verb) is not in the help")
      for alias in aliases {
        #expect(!Command.verbs.contains(alias))
        var compared = 0
        for arguments in ["", " left", " 1", " 412"] {
          guard let expected = try? Command.parse(verb + arguments) else { continue }
          #expect(try Command.parse(alias + arguments) == expected, "\(alias)\(arguments)")
          compared += 1
        }
        #expect(compared > 0, "\(alias)")
        #expect(Command.canonicalVerb(alias) == verb)
        #expect(Command.canonicalVerb(alias.uppercased()) == verb)
      }
    }
    #expect(Command.canonicalVerb("zoom") == "zoom")
    #expect(Command.canonicalVerb("teleport") == nil)
  }

  /// Every other word the parser takes for a command is listed, or `arborctl help equalize` would call a working command unknown.
  @Test func everyOtherNameTheParserTakesIsListed() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("Sources/ArborCore/Command.swift"), encoding: .utf8)
    var found = 0
    for line in source.split(separator: "\n") {
      // `    case "zoom", "frame": …` in `parse(words:)`.
      guard line.hasPrefix("    case \""), let colon = line.firstIndex(of: ":") else { continue }
      let words = line[..<colon].dropFirst("    case ".count).split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }
      guard words.count > 1, words.allSatisfy({ $0.allSatisfy { $0.isLetter || $0 == "-" } }) else { continue }
      for word in words where !word.hasPrefix("-") {
        found += 1
        #expect(Command.canonicalVerb(word) != nil, "`\(word)` works and `help \(word)` does not know it")
      }
    }
    #expect(found > 25)
    for word in ["equalize", "go-to", "setup", "permissions", "passthrough"] { #expect(Command.help(on: word) != nil, "\(word)") }
  }

  @Test func helpOnACommandGivesItsUsageWhatItDoesAndItsOtherNames() {
    #expect(
      Command.help(on: "zoom") == """
        zoom [window]
          frame one window on its own; without a window, again to return
          also: frame
        """)
    #expect(Command.help(on: "FRAME") == Command.help(on: "zoom"))
    #expect(
      Command.help(on: "dock") == """
        dock [window] <edge>
          dock at that edge of the view, or move a docked window one place
        dock [window] beside <window> <edge>
          dock next to another window
        """)
    #expect(Command.help(on: "quit") == "relayout | reload-settings | quit")
    #expect(Command.help(on: "teleport") == nil)
    for verb in Command.verbs { #expect(Command.help(on: verb)?.contains(verb) == true) }
  }

  @Test func helpOnACommandIsACommand() throws {
    #expect(try Command.parse("help") == .help)
    #expect(try Command.parse("help zoom") == .helpOn("zoom"))
    #expect(try Command.parse("help Frame") == .helpOn("zoom"))
    #expect(try Command.parse("help zoom").text == "help zoom")
    #expect(try Command.parse("help zoom").isQuery)
    #expect(try !Command.parse("help zoom").isAllowedFromURL)
    // Arbor gives help whatever follows (`CommandTextTests.helpIsGivenWhateverFollows`): the whole of it, failing a command it knows.
    #expect(try Command.parse("help zoom dock") == .help && Command.parse("help zom") == .help)
    // arborctl, which reads the line first, can do better by a slip of the keyboard.
    guard case .answer(let output) = Arborctl.invocation(["help", "zom"]).action else { return #expect(Bool(false), "answered without Arbor") }
    #expect(output.code == 64 && output.err == "unknown command `zom`; did you mean `zoom`?")
  }

  // MARK: Did you mean

  @Test(arguments: [
    ("zom", "zoom"), ("zooom", "zoom"), ("zomo", "zoom"), ("doc", "dock"), ("dcok", "dock"), ("flaot", "float"), ("arange", "arrange"), ("arrnage", "arrange"),
    ("show-al", "show-all"), ("showall", "show-all"), ("hom", "home"), ("bakc", "back"), ("forwrad", "forward"), ("desktpo", "desktop"), ("layuot", "layout"), ("window", "windows"),
    ("were", "where"), ("neighbuor", "neighbor"), ("ou", "out"), ("undck", "undock"), ("und", "undo"), ("relay", "relayout"), ("reload", "reload-settings"), ("toggle-paus", "toggle-pause"), ("toggle-pi", "toggle-pin"), ("ZOM", "zoom"),
  ]) func aSlipOfTheKeyboardIsRecognised(typed: String, meant: String) {
    #expect(Command.suggestion(for: typed) == meant)
    let error = #expect(throws: Command.ParseError.self) { try Command.parse(typed) }
    #expect(error?.description == "unknown command `\(typed.lowercased())`; did you mean `\(meant)`?")
  }

  @Test(arguments: ["teleport", "x", "", "qqqq", "s", "to", "re", String(repeating: "z", count: 31), String(repeating: "zoom", count: 10_000), "🪟", "\u{0}"])
  func nothingIsSuggestedForWhatResemblesNothing(typed: String) {
    #expect(Command.suggestion(for: typed) == nil)
  }

  @Test func withoutASuggestionTheErrorPointsAtTheHelp() {
    let error = #expect(throws: Command.ParseError.self) { try Command.parse("teleport") }
    #expect(error?.description == "unknown command `teleport`; try `help`")
  }

  // MARK: Completions

  @Test(arguments: Command.Shell.allCases) func everyCommandIsCompleted(shell: Command.Shell) {
    let script = Command.completions(for: shell)
    for verb in Command.verbs + ["completions"] { #expect(script.contains(verb), "\(verb)") }
    #expect(script.contains("left right top bottom"))
    #expect(script.contains("arborctl windows"))
    #expect(!script.contains("\t"))
  }

  /// All of it, to be looked at: in the help a word to choose (`[all]`) and a place for something to type (`[points]`) look alike, and Tab
  /// fills in a word that is the only one offered. Whoever adds a command sees here what became of its usage.
  @Test func whatIsOfferedAfterEachCommand() {
    var offered: [String: String] = [:]
    for line in Command.completions(for: .bash).split(separator: "\n") {
      guard line.hasPrefix("    "), let close = line.firstRange(of: ") words=\""), line.hasSuffix("\" ;;") else { continue }
      var words = String(line[close.upperBound...].dropLast("\" ;;".count))
      if let windows = words.firstRange(of: " focused pointer $(") { words = words[..<windows.lowerBound] + " <windows>" }
      offered[line[..<close.lowerBound].trimmingCharacters(in: .whitespaces)] = words.trimmingCharacters(in: .whitespaces)
    }
    #expect(offered.removeValue(forKey: "help") == Command.verbs.joined(separator: " "))
    #expect(offered.removeValue(forKey: "watch") == (ArborEvent.Kind.allCases.map(\.rawValue) + ["--titles"]).joined(separator: " "))
    let expected = [
      "neighbor": "left right top bottom", "zoom": "<windows>", "save-view": "1 2 3 4 5 6 7 8 9", "view": "1 2 3 4 5 6 7 8 9", "ask-name": "cancel",
      "focus": "left right up down next previous <windows>", "focus-display": "next previous", "reveal": "<windows>", "dock": "left right top bottom beside <windows>",
      "float": "<windows>", "toggle-float": "<windows>", "arrange": "all", "float-all": "here", "resize": "left right top bottom <windows>", "pin": "<windows>",
      "unpin": "<windows>", "toggle-pin": "<windows>", "layout": "@1 @2 --open --titles --ids", "balance": "all", "swap": "left right up down <windows>",
      "move-to-display": "next previous <windows>", "hold": "still", "pass-through": "on off", "state": "--titles", "stats": "reset", "windows": "--titles", "launch-at-login": "on off",
      "settings-window": "close", "settings": "--json", "reset": "all everything", "rule": "add title change remove move", "trace": "on off status note",
      "completions": "zsh bash fish",
    ]
    for verb in Set(offered.keys).union(expected.keys).sorted() {
      #expect(offered[verb] == expected[verb], "after `\(verb)`: \(offered[verb] ?? "nothing"), expected \(expected[verb] ?? "nothing")")
    }
  }

  /// What bash offers after `words`, the last of which is being typed.
  func bashCompletions(_ words: [String]) throws -> [String] {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-completions-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Command.completions(for: .bash).write(to: folder.appendingPathComponent("completions.bash"), atomically: true, encoding: .utf8)
    // Stands in for the real one when the script asks which windows there are.
    let stub = "#!/bin/sh\nprintf '412\\tdocked\\tin-view\\t1\\tcom.apple.Safari\\tSafari\\n388\\tfloating\\tin-view\\t1\\t-\\tVisual Studio Code\\n'\n"
    try stub.write(to: folder.appendingPathComponent("arborctl"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.appendingPathComponent("arborctl").path)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    // Nothing of the person's own: the only `arborctl` it can find is the stand-in.
    process.environment = ["PATH": "/usr/bin:/bin", "HOME": folder.path]
    let list = words.map { "'\($0)'" }.joined(separator: " ")
    process.arguments = [
      "-c", "PATH=\"$1:$PATH\"; source \"$1/completions.bash\"; COMP_WORDS=(\(list)); COMP_CWORD=\(words.count - 1); _arborctl; printf '%s\\n' \"${COMPREPLY[@]}\"", "bash", folder.path,
    ]
    let output = Pipe()
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
    return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
  }

  @Test func bashCompletesCommandsEdgesAndApps() throws {
    #expect(try bashCompletions(["arborctl", "zo"]) == ["zoom", "zoom-node"])
    #expect(try bashCompletions(["arborctl", "lay"]) == ["layout"])
    #expect(try Set(bashCompletions(["arborctl", "neighbor", ""])) == ["left", "right", "top", "bottom"])
    #expect(try bashCompletions(["arborctl", "dock", "b"]) == ["bottom", "beside"])
    // Apps by name where that needs no quotes, and by bundle id.
    #expect(try bashCompletions(["arborctl", "zoom", "S"]) == ["Safari"])
    #expect(try bashCompletions(["arborctl", "zoom", "com"]) == ["com.apple.Safari"])
    #expect(try bashCompletions(["arborctl", "zoom", "V"]).isEmpty)
    #expect(try bashCompletions(["arborctl", "zoom", "f"]) == ["focused"])
    // The command's own options, then arborctl's, which count anywhere on the line.
    #expect(try bashCompletions(["arborctl", "layout", "--"]) == ["--open", "--titles", "--ids"] + Self.ownOptions)
    #expect(try bashCompletions(["arborctl", "--"]) == Self.ownOptions)
    #expect(try bashCompletions(["arborctl", "home", "--k"]) == ["--keep-going"])
    #expect(try bashCompletions(["arborctl", "dock", "l"]) == ["left"], "and are not offered unless a dash was typed")
    // So the command is the first word that is not one of them, after the last comma.
    #expect(try bashCompletions(["arborctl", "--json", "zo"]) == ["zoom", "zoom-node"])
    #expect(try bashCompletions(["arborctl", "--json", "-q", "neighbor", ""]) == ["left", "right", "top", "bottom"])
    #expect(try bashCompletions(["arborctl", "--timeout", "2", "neighbor", ""]) == ["left", "right", "top", "bottom"], "2 is not the command")
    #expect(try bashCompletions(["arborctl", "neighbor", "--json", "r"]) == ["right"])
    #expect(try bashCompletions(["arborctl", "home", ",", "zo"]) == ["zoom", "zoom-node"])
    #expect(try bashCompletions(["arborctl", "dock", "left", ",", "completions", ""]) == ["zsh", "bash", "fish"])
    #expect(try bashCompletions(["arborctl", "arrange", ""]) == ["all"])
    // Words to choose from, in whatever brackets; never a place for something to type, nor a word of the description.
    #expect(try bashCompletions(["arborctl", "launch-at-login", ""]) == ["on", "off"])
    #expect(try bashCompletions(["arborctl", "trace", ""]) == ["on", "off", "status", "note"])
    #expect(try bashCompletions(["arborctl", "reset", ""]) == ["all", "everything"])
    #expect(try bashCompletions(["arborctl", "stats", ""]) == ["reset"])
    #expect(try bashCompletions(["arborctl", "rule", ""]) == ["add", "title", "change", "remove", "move"])
    #expect(try bashCompletions(["arborctl", "set", ""]).isEmpty && bashCompletions(["arborctl", "bind", ""]).isEmpty)
    #expect(try bashCompletions(["arborctl", "completions", ""]) == ["zsh", "bash", "fish"])
    // Whatever begins so, in the order of the help: commands come and go.
    let toggles = Command.verbs.filter { $0.hasPrefix("toggle") }
    #expect(toggles.count >= 3 && toggles.contains("toggle-float") && toggles.contains("toggle-pause"))
    #expect(try bashCompletions(["arborctl", "help", "toggle"]) == toggles)
    // The events, by name.
    #expect(try bashCompletions(["arborctl", "watch", "v"]) == ["view"])
    #expect(try bashCompletions(["arborctl", "watch", "view", "f"]) == ["focus"])
    #expect(try Array(bashCompletions(["arborctl", "watch", "--"]).prefix(1)) == ["--titles"])
    #expect(try Set(bashCompletions(["arborctl", "watch", ""])).isSuperset(of: Set(ArborEvent.Kind.allCases.map(\.rawValue))))
    #expect(try bashCompletions(["arborctl", "home", ""]).isEmpty)
  }

  @Test func fishCompletesCommandsEdgesAndAppsWhereItIsInstalled() throws {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/fish") || FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/fish") else { return }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-completions-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Command.completions(for: .fish).write(to: folder.appendingPathComponent("arborctl.fish"), atomically: true, encoding: .utf8)
    let stub = "#!/bin/sh\nprintf '412\\tdocked\\tin-view\\t1\\tcom.apple.Safari\\tSafari\\n388\\tfloating\\tin-view\\t1\\t-\\tVisual Studio Code\\n'\n"
    try stub.write(to: folder.appendingPathComponent("arborctl"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.appendingPathComponent("arborctl").path)
    func complete(_ line: String) throws -> [String] {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      process.arguments = ["fish", "--no-config", "-c", "set -x PATH \(folder.path) $PATH; source \(folder.path)/arborctl.fish; complete -C'\(line)'"]
      process.environment = ["PATH": "/usr/bin:/bin:/opt/homebrew/bin", "HOME": folder.path]
      let output = Pipe()
      process.standardOutput = output
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      // Each line is a word, and after a tab its description.
      return String(decoding: data, as: UTF8.self).split(separator: "\n").map { String($0.prefix { $0 != "\t" }) }
    }
    #expect(try complete("arborctl zo") == ["zoom", "zoom-node"])
    #expect(try Set(complete("arborctl neighbor ")) == ["left", "right", "top", "bottom"])
    #expect(try complete("arborctl zoom S") == ["Safari"])
    #expect(try complete("arborctl zoom com") == ["com.apple.Safari"])
    #expect(try complete("arborctl zoom po") == ["pointer"])
    #expect(try complete("arborctl completions z") == ["zsh"])
    #expect(try complete("arborctl home ").isEmpty)
    #expect(try Set(complete("arborctl --")) == Set(Self.ownOptions))
    #expect(try complete("arborctl home --k") == ["--keep-going"])
    #expect(try Set(complete("arborctl -")).isSuperset(of: ["-q", "-h"]))
    #expect(try Set(complete("arborctl --json neighbor ")) == ["left", "right", "top", "bottom"])
    #expect(try complete("arborctl --json zo") == ["zoom", "zoom-node"])
  }

  @Test func zshOffersCommandsEdgesAndAppsWhereItIsInstalled() throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") || FileManager.default.isExecutableFile(atPath: "/usr/bin/zsh") else { return }
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-completions-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    try Command.completions(for: .zsh).write(to: folder.appendingPathComponent("_arborctl"), atomically: true, encoding: .utf8)
    let stub = "#!/bin/sh\nprintf '412\\tdocked\\tin-view\\t1\\tcom.apple.Safari\\tSafari\\n388\\tfloating\\tin-view\\t1\\t-\\tVisual Studio Code\\n'\n"
    try stub.write(to: folder.appendingPathComponent("arborctl"), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.appendingPathComponent("arborctl").path)
    /// What the function hands to the completion system, which is stood in for: it only works at a prompt.
    func offered(_ words: [String]) throws -> [String] {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
      let script = """
        compdef() { : }
        _describe() { print -l -- "${(@P)2}" }
        compadd() { shift; print -l -- "$@" }
        source \(folder.path)/_arborctl
        words=(\(words.map { "'\($0)'" }.joined(separator: " "))); CURRENT=\(words.count)
        _arborctl
        """
      process.arguments = ["zsh", "-f", "-c", script]
      process.environment = ["PATH": "\(folder.path):/usr/bin:/bin", "HOME": folder.path]
      let output = Pipe()
      process.standardOutput = output
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      #expect(process.terminationStatus == 0)
      return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }
    let commands = try offered(["arborctl", ""])
    #expect(commands.count == Command.verbs.count + 1)
    #expect(commands.contains { $0.hasPrefix("zoom:frame one window on its own") })
    #expect(try offered(["arborctl", "neighbor", ""]) == ["left", "right", "top", "bottom"])
    #expect(try offered(["arborctl", "zoom", ""]) == ["focused", "pointer", "Safari", "com.apple.Safari"])
    #expect(try offered(["arborctl", "dock", ""]) == ["left", "right", "top", "bottom", "beside", "focused", "pointer", "Safari", "com.apple.Safari"])
    #expect(try offered(["arborctl", "completions", ""]) == ["zsh", "bash", "fish"])
    #expect(try offered(["arborctl", "home", ""]).isEmpty)
    #expect(try offered(["arborctl", "home", "--"]) == Self.ownOptions)
    #expect(try Array(offered(["arborctl", "--"]).prefix(Self.ownOptions.count)) == Self.ownOptions)
    #expect(try offered(["arborctl", "--json", "-q", "neighbor", ""]) == ["left", "right", "top", "bottom"])
    #expect(try offered(["arborctl", "--timeout", "2", "neighbor", ""]) == ["left", "right", "top", "bottom"], "2 is not the command")
    #expect(try offered(["arborctl", "--json", ""]).count == Command.verbs.count + 1, "still waiting for the command")
    #expect(try offered(["arborctl", "home", ",", ""]).count == Command.verbs.count + 1, "and again after a comma")
    #expect(try offered(["arborctl", "dock", "left", ",", "completions", ""]) == ["zsh", "bash", "fish"])
  }

  static let ownOptions = ["--json", "--quiet", "--timeout", "--keep-going", "--help", "--version"]

  /// What is completed is what is read, and what is read is explained.
  @Test func itsOwnOptionsAreCompletedReadAndExplained() throws {
    let help = try #require(Arborctl.invocation([]).action == Arborctl.invocation(["--help"]).action ? Arborctl.invocation([]).action : nil)
    guard case .answer(let output) = help, let text = output.out else { return #expect(Bool(false), "the help is answered without Arbor") }
    for option in Self.ownOptions {
      let explained = text.split(separator: "\n").contains { line in
        // `  -q, --quiet       print nothing…`: what stands before the explanation, as whole words.
        line.hasPrefix("  -") && line.split(whereSeparator: { $0 == " " || $0 == "," }).prefix(2).contains(Substring(option))
      }
      #expect(explained, "\(option) is in the help")
      // Read as its own: it is not sent, and not taken for a mistake.
      let arguments = option == "--timeout" ? [option, "2", "home"] : [option, "home"]
      switch Arborctl.invocation(arguments).action {
      case .send(let lines): #expect(lines == ["home"], "\(option)")
      case .version: #expect(option == "--version")
      case .help: #expect(option == "--help")
      default: Issue.record("\(option) became \(Arborctl.invocation(arguments).action)")
      }
    }
  }

  @Test(arguments: [("zsh", Command.Shell.zsh), ("fish", .fish), ("bash", .bash)])
  func theScriptIsValidWhereItsShellIsInstalled(program: String, shell: Command.Shell) throws {
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/bin/sh")
    which.arguments = ["-c", "command -v \(program)"]
    which.standardOutput = FileHandle.nullDevice
    try which.run()
    which.waitUntilExit()
    guard which.terminationStatus == 0 else { return }
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-completions-\(UUID().uuidString).\(program)")
    try Command.completions(for: shell).write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    let check = Process()
    check.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    check.arguments = [program, "-n", file.path]
    try check.run()
    check.waitUntilExit()
    #expect(check.terminationStatus == 0)
  }
}
