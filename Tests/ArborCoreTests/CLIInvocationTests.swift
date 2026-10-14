import ArborCore
import Testing

@Suite struct CLIInvocationTests {
  func parse(_ arguments: String...) throws -> CLIInvocation { try CLIInvocation.parse(arguments) }

  func one(_ words: String...) -> CLIInvocation.Action { .commands([words]) }

  @Test func arborctlsOwnOptionsCountAnywhereOnTheLine() throws {
    #expect(try parse("dock", "left") == CLIInvocation(action: one("dock", "left")))
    #expect(try parse("--json", "zoom", "412") == CLIInvocation(action: one("zoom", "412"), rawJSON: true))
    // People append them.
    #expect(try parse("zoom", "412", "--json") == CLIInvocation(action: one("zoom", "412"), rawJSON: true))
    #expect(try parse("zoom", "--json", "412") == CLIInvocation(action: one("zoom", "412"), rawJSON: true))
    #expect(try parse("state", "--timeout", "0.5", "--json") == CLIInvocation(action: one("state"), rawJSON: true, timeout: 0.5))
    #expect(try parse("--timeout=2", "state") == CLIInvocation(action: one("state"), timeout: 2))
    #expect(try parse("zoom", "412", "-q") == CLIInvocation(action: one("zoom", "412"), quiet: true))
    #expect(try parse("--quiet", "zoom", "412") == CLIInvocation(action: one("zoom", "412"), quiet: true))
    // Harmless with one command, so a script can always pass it.
    #expect(try parse("dock", "left", "--keep-going") == CLIInvocation(action: one("dock", "left"), keepGoing: true))
  }

  @Test func anyOtherOptionIsTheCommandsIfItFollowsTheCommandsFirstWord() throws {
    #expect(try parse("watch", "camera", "--titles") == CLIInvocation(action: one("watch", "camera", "--titles")))
    #expect(try parse("resize", "left", "-40") == CLIInvocation(action: one("resize", "left", "-40")))
    #expect(throws: CLIInvocation.UsageError.self) { try parse("--titles", "watch", "camera") }
    #expect(throws: CLIInvocation.UsageError.self) { try parse("show-all", ",", "--titles", "watch") }
    // After `--` nothing is arborctl's.
    #expect(try parse("--", "--odd") == CLIInvocation(action: one("--odd")))
    #expect(try parse("--json", "--", "state", "--json", "-q") == CLIInvocation(action: one("state", "--json", "-q"), rawJSON: true))
  }

  @Test func aCommaSeparatesCommands() throws {
    #expect(
      try parse("zoom", "412", ",", "dock", "413", "right")
        == CLIInvocation(action: .commands([["zoom", "412"], ["dock", "413", "right"]])))
    #expect(
      try parse("a", ",", "b", "--keep-going", ",", "c", "--json")
        == CLIInvocation(action: .commands([["a"], ["b"], ["c"]]), rawJSON: true, keepGoing: true))
    // Only by itself: inside a word it is the command's.
    #expect(try parse("exclude", "a,b") == CLIInvocation(action: one("exclude", "a,b")))
  }

  @Test func helpNeedsNoArbor() throws {
    for arguments in [
      [], ["--help"], ["-h"], ["help"], ["HELP"], ["--json"], ["--json", "--help"], ["help", "dock"], ["dock", "--help"],
      ["dock", "left", "-h"],
    ] {
      #expect(try CLIInvocation.parse(arguments).action == .help, "\(arguments)")
    }
    #expect(try parse("--version").action == .version)
    #expect(try parse("--json", "--version").action == .version)
    // `version` without the dashes asks the running app.
    #expect(try parse("version").action == one("version"))
  }

  @Test func aLoneDashReadsStandardInput() throws {
    #expect(try parse("-") == CLIInvocation(action: .batch))
    #expect(try parse("--keep-going", "--timeout", "2", "-") == CLIInvocation(action: .batch, timeout: 2, keepGoing: true))
    #expect(try parse("-", "--keep-going", "-q") == CLIInvocation(action: .batch, keepGoing: true, quiet: true))
  }

  @Test(arguments: [
    ["--bogus"], ["-x", "dock"], ["--timeout"], ["--timeout", "soon", "state"], ["--timeout", "0", "state"],
    ["--timeout", "-1", "state"], ["--timeout", "1e9", "state"], ["--timeout", "nan", "state"], ["--timeout", "inf", "state"],
    ["state", "--timeout"], ["state", "--timeout="], ["--timeout=soon", "state"],
    ["-", "dock"], ["completions"], ["completions", "powershell"],
    ["completions", "zsh", "more"], ["exclude", "a\nquit"], ["dock\r\nquit"], ["dock", "left\u{2028}quit"],
    ["show-all", ",", "watch view"], ["show-all", ",", " WATCH"],
    [","], [",", "dock"], ["dock", ","], ["dock", ",", ",", "float"], ["show-all", ",", "watch"], ["watch", ",", "show-all"],
  ]) func whatItDoesNotUnderstandIsNotSent(arguments: [String]) {
    #expect(throws: CLIInvocation.UsageError.self) { try CLIInvocation.parse(arguments) }
  }

  @Test func aBatchIsAFileOfCommandsWithCommentsAndBlankLines() {
    let batch = CLIInvocation.batch("# morning\ndock 101 left\n\n   \n  dock\t102   right  \r\n#quit\nzoom 101")
    #expect(batch.map(\.number) == [2, 5, 7])
    #expect(batch.map(\.command) == ["dock 101 left", "dock 102 right", "zoom 101"])
    #expect(CLIInvocation.batch("").isEmpty)
    #expect(CLIInvocation.batch("\n\n#\n").isEmpty)
    #expect(CLIInvocation.batch("status").map(\.command) == ["status"], "no line break at the end")
  }

  @Test func theVerbIsTheFirstWordOfTheLineNotTheFirstArgument() {
    #expect(CLIInvocation.verb(of: "watch view") == "watch")
    #expect(CLIInvocation.verb(of: "  State\t") == "state")
    #expect(CLIInvocation.verb(of: "") == nil)
  }

  @Test func aLineThatHoldsSeveralLineBreaksOfOtherKindsIsSeveralCommands() {
    // What `readLine` hands over as one line.
    #expect(CLIInvocation.batch("dock 101 left\rdock 102 right\rstatus\r").map(\.command) == ["dock 101 left", "dock 102 right", "status"])
    #expect(CLIInvocation.batch("a\u{2028}b\u{0C}c").map(\.command) == ["a", "b", "c"])
  }

  @Test func refusalsAreComplaints() {
    #expect(CLIInvocation.outcome(ok: true) == (false, .ok))
    #expect(CLIInvocation.outcome(ok: false) == (true, .refused))
    #expect(CLIInvocation.ExitCode.usage.rawValue == 64)
  }

  @Test func theUsageTextNamesEveryOptionAndExitCode() {
    for option in ["--json", "-q", "--timeout", "--keep-going", "--help", "--version", "completions"] {
      #expect(CLIInvocation.usage.contains(option))
    }
    for code in [0, 1, 2, 3, 4, 64] { #expect(CLIInvocation.usage.contains("\(code) ")) }
  }

  // MARK: Completions

  @Test func everyVerbInTheHelpIsACommand() {
    let verbs = Command.documentedVerbs
    #expect(verbs.count >= 30, "\(verbs)")
    for verb in [
      "show-all", "out", "in", "dock", "float", "toggle-float", "save-view", "view", "quit", "status", "help", "rules", "resume",
      "toggle-pause", "include", "get",
    ] {
      #expect(verbs.contains(verb), "\(verb) is missing from \(verbs)")
    }
    for verb in verbs {
      // It may want arguments, but it must not be unknown.
      do {
        _ = try Command.parse(words: [verb])
      } catch {
        #expect(!"\(error)".contains("unknown command"), "\(verb): \(error)")
      }
    }
    #expect(Set(verbs).count == verbs.count)
    // Words of the descriptions, some of which happen to be aliases of commands.
    for word in ["save", "step", "one", "undock", "stop", "the", "list", "on", "off", "off]", "--ids]", "all", "remove"] { #expect(!verbs.contains(word), "\(word)") }
  }

  @Test(arguments: CLIInvocation.Shell.allCases) func completionScriptsOfferEveryVerbAndTheEdges(shell: CLIInvocation.Shell) {
    let script = ShellCompletions.script(for: shell)
    for verb in Command.documentedVerbs { #expect(script.contains(verb)) }
    #expect(script.contains("left right top bottom"))
    // Saved on $fpath, the file is run at the first Tab and has to complete there and then.
    if shell == .zsh { #expect(script.contains("_arborctl \"$@\"")) }
    // Verbs come from the help text. Nothing in them may be able to end a quoted string or start a command.
    for verb in Command.documentedVerbs {
      #expect(verb.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }, "\(verb)")
    }
  }
}
