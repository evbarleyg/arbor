import ArborCore
import Foundation
import Testing

private typealias Output = Arborctl.Output

/// arborctl's manners (F50, part 4): what its arguments ask for, what it prints where, and how it exits.
@Suite struct ArborctlTests {
  /// Plays Arbor: answers each line from `replies`, in order, and notes what was sent. Nil is "not running", `late` an answer
  /// that does not come in time. `input` is what standard input holds.
  final class Stage {
    static let late = "<late>"
    var replies: [String?]
    var input: [String] = []
    var sent: [String] = []
    var timeouts: [Double] = []
    /// What had been sent when each line of input was asked for.
    var sentWhenReading: [Int] = []
    var out: [String] = []
    var err: [String] = []

    init(_ replies: [String?]) { self.replies = replies }

    struct NotRunning: Error, CustomStringConvertible { let description = "Arbor is not running" }

    func run(_ arguments: String..., unchecked: Bool = false, terminal: Bool = false) -> Int32 {
      Arborctl.run(
        arguments, unchecked: unchecked, terminal: terminal,
        readLine: {
          sentWhenReading.append(sent.count)
          return input.isEmpty ? nil : input.removeFirst()
        },
        send: { line, timeout in
          sent.append(line)
          timeouts.append(timeout)
          guard !replies.isEmpty, let reply = replies.removeFirst() else { throw NotRunning() }
          guard reply != Self.late else { throw Arborctl.TimedOut(description: "Arbor did not answer within \(timeout) s") }
          return reply
        },
        emit: { output in
          if let text = output.out { out.append(text) }
          if let text = output.err { err.append(text) }
        })
    }
  }

  static let done = #"{"message":"docked w412 at the left edge","ok":true}"#
  static let refused = #"{"message":"no window of Safari; `windows` lists them","ok":false}"#
  static let table = #"{"json":[{"app":"Safari","id":412}],"message":"2 windows","ok":true,"text":"412\tdocked\tSafari\n7\tfloating\tMail"}"#

  // MARK: Exit codes, stdout and stderr

  @Test func doneIsZeroAndTheReplyIsOnStdout() {
    let stage = Stage([Self.done])
    #expect(stage.run("dock", "left") == 0)
    #expect(stage.sent == ["dock left"])
    #expect(stage.out == ["docked w412 at the left edge"] && stage.err.isEmpty)
  }

  @Test func arborSayingNoIsOneAndTheReasonIsOnStderr() {
    let stage = Stage([Self.refused])
    #expect(stage.run("zoom", "Safari") == 1)
    #expect(stage.out.isEmpty)
    #expect(stage.err == ["no window of Safari; `windows` lists them"])
  }

  @Test func notReachingArborIsTwo() {
    let stage = Stage([nil])
    #expect(stage.run("dock", "left") == 2)
    #expect(stage.out.isEmpty && stage.err == ["Arbor is not running"])
  }

  @Test func whatDoesNotParseIsSixtyFourWithoutARoundTrip() {
    for arguments in [["zom"], ["dock"], ["dock", "sideways"], ["layout", "A | B / C"], ["view", "0"], ["zoom", "--fast"], ["dock", "left", ",", "zom"]] {
      let stage = Stage([Self.done, Self.done])
      let code = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return Self.done }, emit: { stage.err.append($0.err ?? ""); stage.out.append($0.out ?? "") })
      #expect(code == 64, "\(arguments)")
      #expect(stage.sent.isEmpty, "\(arguments)")
      #expect(stage.out == [""] && stage.err.count == 1 && !stage.err[0].isEmpty, "\(arguments)")
    }
    let stage = Stage([])
    #expect(stage.run("zom") == 64)
    #expect(stage.err == ["unknown command `zom`; did you mean `zoom`?"])
  }

  @Test func aReplyThatCannotBeReadIsTwo() {
    for reply in ["", "nonsense", "[]", "{}", #"{"ok":"yes"}"#, #"{"message":"x"}"#] {
      let stage = Stage([reply])
      #expect(stage.run("dock", "left") == 2, "\(reply)")
      #expect(stage.out.isEmpty && stage.err.count == 1)
    }
  }

  @Test func uncheckedSendsWhateverItIsGiven() {
    let stage = Stage([Self.done])
    #expect(stage.run("open", "Safari", unchecked: true) == 0)
    #expect(stage.sent == ["open Safari"])
  }

  // MARK: Options

  @Test func quietPrintsNothingAndKeepsTheExitCode() {
    for (reply, code) in [(Self.done, 0), (Self.refused, 1), (nil, 2)] as [(String?, Int32)] {
      for arguments in [["-q", "dock", "left"], ["dock", "-q", "left"], ["dock", "left", "--quiet"]] {
        let stage = Stage([reply])
        let result = Arborctl.run(
          arguments, send: { _, _ in if let reply { return reply } else { throw Stage.NotRunning() } },
          emit: { stage.out.append($0.out ?? "-"); stage.err.append($0.err ?? "-") })
        #expect(result == code)
        #expect(stage.out == ["-"] && stage.err == ["-"])
      }
    }
    // All but a mistake in the script: `quietDoesNotHideAMistakeInTheScript`.
    let stage = Stage([])
    #expect(stage.run("-q", "zom") == 64)
    #expect(stage.out.isEmpty && stage.err == ["unknown command `zom`; did you mean `zoom`?"])
  }

  @Test func jsonGoesAnywhereOnTheLine() {
    for arguments in [["--json", "windows"], ["windows", "--json"], ["windows", "--json", "--titles"]] {
      let stage = Stage([Self.table])
      _ = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return Self.table }, emit: { stage.out.append($0.out ?? "") })
      #expect(stage.out == [#"[{"app":"Safari","id":412}]"#], "\(arguments)")
      #expect(!stage.sent[0].contains("--json"))
    }
  }

  @Test func withoutAnAnswerOfItsOwnJSONIsTheWholeReply() {
    let stage = Stage([Self.done])
    #expect(stage.run("--json", "dock", "left") == 0)
    #expect(stage.out == [Self.done])
  }

  @Test func withJSONARefusalIsStillOnStderrAlone() {
    let stage = Stage([Self.refused])
    #expect(stage.run("--json", "zoom", "Safari") == 1)
    #expect(stage.out.isEmpty && stage.err.count == 1)
  }

  @Test func stateIsTheWholeReplyAsItAlwaysWas() {
    let reply = #"{"message":"running","ok":true,"state":{"schema":2}}"#
    let stage = Stage([reply])
    #expect(stage.run("state") == 0)
    #expect(stage.out == [reply])
  }

  @Test func optionsOfTheCommandsPassThrough() {
    let stage = Stage([Self.done, Self.done, Self.done])
    _ = stage.run("layout", "--open", "Safari | Mail")
    _ = stage.run("windows", "--titles")
    _ = stage.run("layout", "--ids", "@2")
    #expect(stage.sent == ["layout --open Safari | Mail", "windows --titles", "layout --ids @2"])
  }

  // MARK: Tables

  @Test func aTableIsLinedUpForAPersonAndKeepsItsTabsInAPipe() {
    var stage = Stage([Self.table])
    _ = stage.run("windows", terminal: true)
    #expect(stage.out == ["412  docked    Safari\n7    floating  Mail"])
    stage = Stage([Self.table])
    _ = stage.run("windows", terminal: false)
    #expect(stage.out == ["412\tdocked\tSafari\n7\tfloating\tMail"])
  }

  /// "One line per item": with no item there is no line, not an empty one, so `arborctl views | wc -l` is 0 and a loop over the lines runs never.
  @Test func anAnswerWithoutRowsPrintsNothing() {
    let empty = #"{"json":[],"message":"0 saved views","ok":true,"text":""}"#
    for terminal in [false, true] {
      let stage = Stage([empty])
      #expect(stage.run("views", terminal: terminal) == 0)
      #expect(stage.out.isEmpty && stage.err.isEmpty)
    }
    let stage = Stage([empty])
    #expect(stage.run("views", "--json") == 0 && stage.out == ["[]"])
  }

  /// What a person should hear beside the answer is on stderr, so that the table stays a table and the JSON stays JSON. It is no failure.
  @Test func aWarningGoesToStderrBesideTheAnswer() {
    let reply = #"{"json":[{"display":1}],"message":"1 display","ok":true,"text":"1\tmain","warning":"skipped entries of \"displays\" in settings.json:\n  entry 2"}"#
    var stage = Stage([reply])
    #expect(stage.run("displays") == 0)
    #expect(stage.out == ["1\tmain"] && stage.err == ["skipped entries of \"displays\" in settings.json:\n  entry 2"])
    stage = Stage([reply])
    #expect(stage.run("displays", "--json") == 0 && stage.out == [#"[{"display":1}]"#] && stage.err.count == 1)
    stage = Stage([reply])
    #expect(stage.run("-q", "displays") == 0 && stage.out.isEmpty && stage.err.isEmpty)
  }

  @Test func liningUpCopesWithRowsOfAnyShape() {
    #expect(Arborctl.aligned("no tabs\nat all") == "no tabs\nat all")
    #expect(Arborctl.aligned("a\tb\nlonger\tc\td\n\nx") == "a       b\nlonger  c  d\n\nx")
    #expect(Arborctl.aligned("\t\t") == "    ")
    #expect(Arborctl.aligned("é\tb\n微信\tc") == "é   b\n微信  c")
    #expect(Arborctl.aligned("") == "")
  }

  // MARK: Several commands

  @Test func severalCommandsRunInOrder() {
    let stage = Stage([Self.done, Self.done, #"{"message":"showing everything","ok":true}"#])
    #expect(stage.run("dock", "Safari", "left", ",", "dock", "Mail", "right", ",", "home") == 0)
    #expect(stage.sent == ["dock Safari left", "dock Mail right", "home"])
    #expect(stage.out.count == 3)
  }

  @Test func theyStopAtTheFirstFailure() {
    var stage = Stage([Self.done, Self.refused, Self.done])
    #expect(stage.run("dock", "left", ",", "zoom", "Safari", ",", "home") == 1)
    #expect(stage.sent == ["dock left", "zoom Safari"])
    #expect(stage.out.count == 1 && stage.err.count == 1)
    stage = Stage([Self.done, nil])
    #expect(stage.run("dock", "left", ",", "home", ",", "back") == 2)
    #expect(stage.sent == ["dock left", "home"])
  }

  @Test func allOfThemAreReadBeforeAnyIsSent() {
    let stage = Stage([Self.done])
    #expect(stage.run("dock", "left", ",", "hoem") == 64)
    #expect(stage.sent.isEmpty)
  }

  @Test(arguments: [[","], ["dock", "left", ","], [",", "dock", "left"], ["dock", "left", ",", ",", "home"]])
  func aCommaNeedsACommandOnEitherSide(arguments: [String]) {
    guard case .answer(let output) = Arborctl.invocation(arguments).action else {
      Issue.record("\(arguments) was accepted")
      return
    }
    #expect(output.code == 64)
    #expect(output.err?.contains("the comma") == true)
  }

  @Test func aCommaInsideAnArgumentIsNotASeparator() {
    #expect(Arborctl.invocation(["zoom", "a,b"]).action == .send(["zoom a,b"]))
  }

  // MARK: Quotes

  struct NotSent: Error, CustomStringConvertible { let description: String }

  /// The shell takes the quotes off and `line(from:)` puts them back round an argument with a space or a slash in it. There is one reader
  /// of a command line, and it takes them off again for every word that is not a window's name.
  @Test func whatTheShellHeldTogetherArrivesAsOneWordWithoutQuotes() throws {
    func sent(_ arguments: String...) throws -> Command {
      guard case .send(let lines) = Arborctl.invocation(arguments).action else {
        throw NotSent(description: "\(arguments) was not sent: \(Arborctl.invocation(arguments).action)")
      }
      #expect(lines.count == 1)
      return try Command.parse(lines[0])
    }
    // The three that the re-quoting broke.
    #expect(try sent("bind", "ctrl+opt+/", "desktop") == Command.parse("bind ctrl+opt+/ desktop"))
    #expect(try sent("bind", "ctrl+opt+/", "desktop").text == "bind ctrl+opt+/ desktop")
    #expect(try sent("rule", "add", "com.example.safari", "float", "title", "My Page") == Command.parse("rule add com.example.safari float title My Page"))
    #expect(try !sent("rule", "add", "com.example.safari", "float", "title", "My Page").text.contains("\""), "a title with quotes in it would never match")
    #expect(try sent("summon", "Visual Studio Code") == .summon(app: "Visual Studio Code"))
    // Names of spaces are words of a person's own as well.
    #expect(try sent("name", "Writing Desk") == .name("Writing Desk"))
    #expect(try sent("go", "Writing Desk") == .goToSpace("Writing Desk"))
    #expect(try sent("trace", "note", "the seam / the gap") == .trace(.note("the seam / the gap")))
    // And typed with quotes where no shell takes them off: a shortcut in settings.json, a line of a batch.
    #expect(try Command.parse("summon \"Visual Studio Code\"") == .summon(app: "Visual Studio Code"))
    #expect(try Command.parse("bind \"ctrl+opt+/\" desktop") == Command.parse("bind ctrl+opt+/ desktop"))
    // Where an edge stands they come off like anywhere else, as a shell would have taken them off; `WindowRefTests` has where a window stands.
    #expect(try Command.parse("dock \"LEFT\"") == Command.parse("dock left"))
  }

  /// What a shortcut is to run is read when it is bound, so its quotes have to be there still.
  @Test func aCommandInsideACommandKeepsItsQuotes() throws {
    guard case .send(let lines) = Arborctl.invocation(["bind", "ctrl+opt+1", "zoom", "Visual Studio Code"]).action else {
      Issue.record("not sent")
      return
    }
    #expect(try Command.parse(lines[0]).text == "bind ctrl+opt+1 zoom \"Visual Studio Code\"")
    #expect(try Command.parse("bind ctrl+opt+1 dock \"left\" left").text == "bind ctrl+opt+1 dock \"left\" left")
    #expect(try Command.parse("bind ctrl+opt+1 layout \"Visual Studio Code\" | Mail").text == "bind ctrl+opt+1 layout \"Visual Studio Code\" | Mail")
    #expect(try Command.parse(words: ["layout", "\"Visual Studio Code\"", "|", "Mail"]) == Command.parse("layout \"Visual Studio Code\" | Mail"))
  }

  /// `arborctl bind ctrl+opt+h "dock left"`: a whole command as one argument, as after `arborctl` itself.
  @Test func bindTakesItsCommandAsOneArgumentOrAsSeveral() throws {
    func bound(_ arguments: String...) throws -> String {
      guard case .send(let lines) = Arborctl.invocation(arguments).action else { throw NotSent(description: "\(Arborctl.invocation(arguments).action)") }
      return try Command.parse(lines[0]).text
    }
    #expect(try bound("bind", "ctrl+opt+h", "dock left") == "bind ctrl+opt+h dock left")
    #expect(try bound("bind", "ctrl+opt+h", "dock", "left") == "bind ctrl+opt+h dock left")
    #expect(try bound("bind", "ctrl+opt+h", "desktop") == "bind ctrl+opt+h desktop")
    #expect(try bound("bind", "ctrl+opt+3", "layout Safari | Mail") == "bind ctrl+opt+3 layout Safari | Mail")
    #expect(try bound("bind", "ctrl+opt+1", "zoom \"Visual Studio Code\"") == "bind ctrl+opt+1 zoom \"Visual Studio Code\"")
    #expect(try bound("bind", "ctrl+opt+1", "zoom", "Visual Studio Code") == "bind ctrl+opt+1 zoom \"Visual Studio Code\"")
    #expect(try bound("bind", "ctrl+opt+/", "dock left") == "bind ctrl+opt+/ dock left")
  }

  // MARK: From arguments to a line

  @Test func argumentsWithSpacesGoBackInQuotes() throws {
    #expect(Arborctl.line(from: ["zoom", "Visual Studio Code"]) == "zoom \"Visual Studio Code\"")
    #expect(Arborctl.line(from: ["dock", "Google Chrome", "beside", "Visual Studio Code", "left"]) == "dock \"Google Chrome\" beside \"Visual Studio Code\" left")
    #expect(Arborctl.line(from: ["zoom", "say \"hi\" now"]) == "zoom \"say \"\"hi\"\" now\"")
    #expect(Arborctl.line(from: ["zoom", "a/b"]) == "zoom \"a/b\"")
    #expect(Arborctl.line(from: ["zoom", "'x'"]) == "zoom \"'x'\"")
    #expect(Arborctl.line(from: ["zoom", ""]) == "zoom \"\"")
    #expect(Arborctl.line(from: ["dock", "left"]) == "dock left")
    #expect(Arborctl.line(from: []) == "")
    // Whatever the name, the command that arrives names exactly it.
    for name in ["Visual Studio Code", "say \"hi\" now", "a/b", "'x'", "it's", "\"", "a  b", "left right", "C++"] {
      #expect(try Command.parse(Arborctl.line(from: ["zoom", name])) == .naming(.zoom(WindowID(.max)), [.app(name)]), "\(name)")
    }
  }

  @Test func theFirstArgumentMayHoldTheWholeCommand() {
    #expect(Arborctl.invocation(["dock left"]).action == .send(["dock left"]))
  }

  @Test func whatFollowsLayoutIsLeftAsItIs() {
    #expect(Arborctl.line(from: ["layout", "Safari | (Mail / 'Visual Studio Code')"]) == "layout Safari | (Mail / 'Visual Studio Code')")
    #expect(Arborctl.line(from: ["LAYOUT", "@2", "--open", "A | B"]) == "LAYOUT @2 --open A | B")
    #expect(Arborctl.line(from: ["layout", "Safari", "|", "Mail"]) == "layout Safari | Mail")
  }

  // MARK: Help, completions, version

  @Test func helpIsAnsweredWithoutArbor() {
    for arguments in [[], ["help"], ["--help"], ["-h"], ["HELP"]] {
      guard case .answer(let output) = Arborctl.invocation(arguments).action else {
        Issue.record("\(arguments)")
        continue
      }
      #expect(output.code == 0 && output.err == nil)
      #expect(output.out?.hasPrefix(Command.helpText) == true)
      #expect(output.out?.contains("64 when the command cannot be read") == true)
    }
  }

  @Test func helpOnACommandAsksArborForTheShortcuts() {
    let reply = #"{"message":"help on zoom","ok":true,"text":"zoom [window]\n  shortcut: ⌃⌥↩ zoom"}"#
    for arguments in [["help", "zoom"], ["zoom", "--help"], ["-h", "zoom"], ["help", "frame"], ["zoom", "412", "--help"]] {
      let stage = Stage([reply])
      let code = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return reply }, emit: { stage.out.append($0.out ?? "") })
      #expect(code == 0)
      #expect(stage.sent == ["help \(arguments.contains("frame") ? "frame" : "zoom")"], "\(arguments)")
      #expect(stage.out == ["zoom [window]\n  shortcut: ⌃⌥↩ zoom"])
    }
  }

  @Test func withoutArborItStillKnowsTheUsage() {
    let stage = Stage([nil])
    #expect(stage.run("help", "zoom") == 0)
    #expect(stage.out == [Command.help(on: "zoom")!] && stage.err.isEmpty)
  }

  @Test func anOlderArborThatDoesNotKnowTheQuestionIsNoObstacle() {
    let stage = Stage([#"{"message":"`help` takes no arguments","ok":false}"#])
    #expect(stage.run("help", "zoom") == 0)
    #expect(stage.out == [Command.help(on: "zoom")!] && stage.err.isEmpty)
  }

  @Test func helpOnWhatIsNoCommandSuggestsOne() {
    let stage = Stage([])
    #expect(stage.run("help", "zom") == 64)
    #expect(stage.err == ["unknown command `zom`; did you mean `zoom`?"])
  }

  @Test func completionsArePrintedWithoutArbor() {
    for shell in Command.Shell.allCases {
      let stage = Stage([])
      #expect(stage.run("completions", shell.rawValue) == 0)
      #expect(stage.out == [Command.completions(for: shell)] && stage.sent.isEmpty)
    }
    for arguments in [["completions"], ["completions", "tcsh"], ["completions", "zsh", "bash"]] {
      guard case .answer(let output) = Arborctl.invocation(arguments).action else {
        Issue.record("\(arguments)")
        continue
      }
      #expect(output.code == 64 && output.err?.hasPrefix("usage: arborctl completions zsh|bash|fish") == true)
    }
    let stage = Stage([])
    #expect(stage.run("help", "completions") == 0)
    #expect(stage.out.first?.contains("~/.config/fish/completions/arborctl.fish") == true)
  }

  @Test func versionIsItsOwnAndSaysWhenArborIsAnotherBuild() {
    // The tests' arborctl is in no bundle.
    var stage = Stage([#"{"message":"Arbor dev","ok":true}"#])
    #expect(stage.run("--version") == 0)
    #expect(stage.sent == ["version"])
    #expect(stage.out == ["arborctl dev"] && stage.err.isEmpty)

    let own = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")
    func output(_ reply: String?) -> Arborctl.Output { Arborctl.versionOutput(own: own, reply: reply) }
    #expect(output(#"{"message":"Arbor 0.9.0 (build 214, 47a2ba9)","ok":true}"#) == Arborctl.Output(out: "arborctl 0.9.0 (build 214, 47a2ba9)"))
    // What it has to say about updates is not a difference.
    #expect(
      output(#"{"message":"Arbor 0.9.0 (build 214, 47a2ba9)","ok":true,"text":"Arbor 0.9.0 (build 214, 47a2ba9)\nUpdates: checking"}"#).out
        == "arborctl 0.9.0 (build 214, 47a2ba9)")
    let other = output(#"{"message":"Arbor 0.8.0 (build 190, 1c2d3e4)","ok":true}"#)
    #expect(other.code == 0 && other.err == nil)
    #expect(
      other.out
        == "arborctl 0.9.0 (build 214, 47a2ba9)\nThe Arbor that is running is another build, Arbor 0.8.0 (build 190, 1c2d3e4): quit it and open Arbor again")
  }

  /// People ask for the version before they have Arbor running, of an Arbor too old to know the question, and of things that are not Arbor.
  @Test(arguments: [nil, "", "not JSON", "{}", "[]", #"{"ok":false,"message":"unknown command `version`"}"#, #"{"ok":true}"#, #"{"ok":true,"message":7}"#])
  func versionNeedsNoAnswer(reply: String?) {
    #expect(Arborctl.versionOutput(own: .development, reply: reply) == Arborctl.Output(out: "arborctl dev"))
    var stage = Stage([reply])
    #expect(stage.run("--version") == 0)
    #expect(stage.out == ["arborctl dev"] && stage.err.isEmpty)
  }

  /// Nothing about the version is compiled in: the bundle's Info.plist says it, to the app and to arborctl alike.
  @Test func theVersionIsTheBundles() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Resources/Info.plist"))
    let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    let info = BuildInfo(infoDictionary: plist)
    #expect(info != .development, "Resources/Info.plist has a CFBundleShortVersionString")
    #expect(info.version == plist["CFBundleShortVersionString"] as? String)
    #expect(info.version.split(separator: ".").allSatisfy { Int($0) != nil }, "\(info.version)")
    #expect(Query.Version(info).version == info.version && Query.Version(info).build == info.build)
    #expect(BuildInfo(infoDictionary: nil) == .development && BuildInfo(infoDictionary: [:]) == .development)
  }

  // MARK: Options

  /// arborctl's own count anywhere on the line, because people append them.
  @Test(arguments: [
    ["--json", "windows"], ["windows", "--json"], ["--timeout", "2", "windows", "--json"], ["windows", "--json", "--timeout=2"],
    ["--keep-going", "--json", "windows"], ["windows", "--keep-going", "--json"],
  ]) func itsOwnOptionsCountAnywhere(arguments: [String]) {
    let invocation = Arborctl.invocation(arguments)
    #expect(invocation.action == .send(["windows"]), "\(arguments)")
    #expect(invocation.json)
  }

  /// Before the command's first word nothing else can be meant; after it, it is the command's.
  @Test func anyOtherOptionBelongsToTheCommandOrIsAMistake() {
    for arguments in [["--jsno", "windows"], ["-x", "dock", "left"], ["--titles", "windows"], ["--open", "layout", "Safari"], ["-1"], ["out", ",", "--titles", "windows"]] {
      let stage = Stage([Self.done, Self.done])
      let code = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return Self.done }, emit: { stage.err.append($0.err ?? "") })
      #expect(code == 64 && stage.sent.isEmpty, "\(arguments)")
      let option = arguments.first { $0.hasPrefix("-") }!
      #expect(stage.err == ["unknown option \(option); `arborctl --help` lists them"], "\(arguments)")
    }
    #expect(Arborctl.invocation(["windows", "--titles"]).action == .send(["windows --titles"]))
    #expect(Arborctl.invocation(["layout", "--open", "Safari | Mail"]).action == .send(["layout --open Safari | Mail"]))
    #expect(Arborctl.invocation(["resize", "right", "-100"]).action == .send(["resize right -100"]))
    #expect(Arborctl.invocation(["out", ",", "windows", "--titles"]).action == .send(["out", "windows --titles"]))
  }

  /// Each of these is a whole request, with nothing else on the line, and help wins when both are asked for.
  @Test func helpAndVersionNeedNoCommand() {
    #expect(Arborctl.invocation(["--version"]).action == .version)
    #expect(Arborctl.invocation(["-q", "--version"]).action == .version)
    #expect(Arborctl.invocation(["windows", "--version"]).action == .version, "anywhere on the line")
    let help = Arborctl.invocation([]).action
    for arguments in [["--help"], ["-h"], ["help"], ["--version", "--help"], ["--help", "--version"], ["--json"], ["--keep-going"], ["--timeout", "2"]] {
      #expect(Arborctl.invocation(arguments).action == help, "\(arguments)")
    }
    #expect(help != .version)
  }

  @Test func twoDashesEndItsOwnOptions() {
    // What follows is the command's, whatever it looks like: here Arbor is asked, and says what it thinks of it.
    #expect(Arborctl.invocation(["--", "windows"]).action == .send(["windows"]))
    let before = Arborctl.invocation(["-q", "--", "windows", "--titles"])
    #expect(before.action == .send(["windows --titles"]) && before.quiet)
    let after = Arborctl.invocation(["windows", "--", "--json", "-q"], unchecked: true)
    #expect(after.action == .send(["windows --json -q"]) && !after.json && !after.quiet)
    #expect(Arborctl.invocation(["windows", "--", "--timeout"], unchecked: true).action == .send(["windows --timeout"]))
    #expect(Arborctl.invocation(["--"]).action == Arborctl.invocation([]).action, "nothing was asked: the help")
  }

  @Test func timeoutIsSecondsForEachReply() {
    var stage = Stage([Self.done, Self.done])
    #expect(stage.run("out", ",", "out") == 0)
    #expect(stage.timeouts == [5, 5], "the default")
    stage = Stage([Self.done, Self.done])
    #expect(stage.run("--timeout", "1.5", "out", ",", "out") == 0)
    #expect(stage.timeouts == [1.5, 1.5] && stage.sent == ["out", "out"])
    for arguments in [["out", "--timeout=0.1"], ["out", "--timeout", "600"], ["--timeout=30", "out"]] {
      #expect(Arborctl.invocation(arguments).action == .send(["out"]) && Arborctl.invocation(arguments).timeout != nil, "\(arguments)")
    }
    // What arborctl can do without is not waited for as long, unless that was asked for.
    stage = Stage([nil])
    _ = stage.run("--version")
    #expect(stage.timeouts == [1])
    stage = Stage([nil])
    _ = stage.run("help", "dock")
    #expect(stage.timeouts == [1])
    stage = Stage([nil])
    _ = stage.run("--version", "--timeout", "3")
    #expect(stage.timeouts == [3])
  }

  @Test(arguments: ["0", "0.09", "-1", "601", "1e9", "nan", "inf", "-inf", "", " ", "five", "1s", "0x", "١", "1,5", "--json", ","])
  func aTimeoutThatIsNoneIsRefused(text: String) {
    for arguments in [["--timeout", text, "out"], ["out", "--timeout", text], ["--timeout=\(text)", "out"]] {
      let stage = Stage([Self.done])
      let code = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return Self.done }, emit: { stage.err.append($0.err ?? "") })
      #expect(code == 64 && stage.sent.isEmpty, "\(arguments)")
      #expect(stage.err == ["--timeout takes a number of seconds from 0.1 to 600"], "\(arguments)")
    }
    #expect(Stage([]).run("out", "--timeout") == 64, "nothing follows it")
  }

  @Test func noAnswerInTimeIsFour() {
    let stage = Stage([Stage.late])
    #expect(stage.run("dock", "left", "--timeout", "2") == 4)
    #expect(stage.out.isEmpty && stage.err == ["Arbor did not answer within 2.0 s"])
    #expect(Stage([Stage.late]).run("-q", "dock", "left") == 4)
    // Not the same as nobody being there.
    #expect(Stage([nil]).run("dock", "left") == 2)
  }

  /// It keeps quiet about what Arbor answers. What cannot be read is a mistake in the script, and silence would hide it.
  @Test func quietDoesNotHideAMistakeInTheScript() {
    for arguments in [["--bogus", "-q"], ["-q", "--bogus"], ["--timeout", "x", "--quiet"], ["zom", "-q"], ["-q", "-", "x"], ["-q", "out", ",", "zom"]] {
      var emitted: [Output] = []
      #expect(Arborctl.run(arguments, send: { _, _ in Self.done }, emit: { emitted.append($0) }) == 64, "\(arguments)")
      #expect(emitted.count == 1 && emitted[0].out == nil && emitted[0].err?.isEmpty == false, "\(arguments): \(emitted)")
    }
    let stage = Stage([Self.done, Self.refused])
    stage.input = ["out", "zom", "zoom Safari"]
    #expect(stage.run("-q", "--keep-going", "-") == 64)
    #expect(stage.out.isEmpty && stage.err == ["line 2: unknown command `zom`; did you mean `zoom`?"], "and Arbor's refusal of line 3 is kept quiet about")
  }

  // MARK: Several commands

  @Test func theFirstFailureStopsAndIsWhatIsReported() {
    let stage = Stage([Self.done, Self.refused, Self.done])
    #expect(stage.run("out", ",", "zoom", "Safari", ",", "desktop") == 1)
    #expect(stage.sent == ["out", "zoom Safari"])
  }

  @Test func keepGoingCarriesOnAndStillReportsTheFirstFailure() {
    var stage = Stage([Self.done, Self.refused, Stage.late, Self.done])
    #expect(stage.run("--keep-going", "out", ",", "zoom", "Safari", ",", "home", ",", "desktop") == 1, "the first, not the worst or the last")
    #expect(stage.sent == ["out", "zoom Safari", "home", "desktop"])
    #expect(stage.out.count == 2 && stage.err.count == 2)
    stage = Stage([Stage.late, Self.refused, Self.done])
    #expect(stage.run("out", ",", "zoom", "Safari", ",", "desktop", "--keep-going") == 4)
    #expect(stage.sent.count == 3)
    #expect(Stage([Self.done, Self.done]).run("--keep-going", "out", ",", "out") == 0)
  }

  /// With nobody there, the commands that follow would only say so again.
  @Test func keepGoingStopsWhenArborIsNotThere() {
    let stage = Stage([Self.done, nil, Self.done])
    #expect(stage.run("--keep-going", "out", ",", "home", ",", "desktop") == 2)
    #expect(stage.sent == ["out", "home"] && stage.err == ["Arbor is not running"])
  }

  /// On one line, all are read before any is sent, with or without `--keep-going`.
  @Test func aLineThatCannotBeReadSendsNothing() {
    for arguments in [["out", ",", "zom"], ["--keep-going", "out", ",", "zom", ",", "home"]] {
      let stage = Stage([Self.done, Self.done, Self.done])
      let code = Arborctl.run(arguments, send: { line, _ in stage.sent.append(line); return Self.done }, emit: { _ in })
      #expect(code == 64 && stage.sent.isEmpty, "\(arguments)")
    }
  }

  // MARK: A batch

  @Test func aBatchIsOneCommandPerLine() {
    let stage = Stage([Self.done, Self.done, Self.done])
    stage.input = ["# the morning", "", "  dock Safari left  ", "\t# indented comment", "zoom \"Visual  Studio Code\"", "layout Safari | (Mail / Notes)"]
    #expect(stage.run("-") == 0)
    #expect(stage.sent == ["dock Safari left", "zoom \"Visual  Studio Code\"", "layout Safari | (Mail / Notes)"], "as they were written, quotes and all")
    #expect(stage.out.count == 3 && stage.err.isEmpty)
  }

  @Test func anEmptyBatchIsDone() {
    let stage = Stage([])
    #expect(stage.run("-") == 0)
    #expect(stage.sent.isEmpty && stage.out.isEmpty && stage.err.isEmpty)
    stage.input = ["", "#", "   "]
    #expect(stage.run("-") == 0 && stage.sent.isEmpty)
  }

  /// The other end may be a program that waits for each answer before it writes the next line.
  @Test func aBatchIsReadLineByLineAsItIsAnswered() {
    let stage = Stage([Self.done, Self.done])
    stage.input = ["out", "home"]
    #expect(stage.run("-") == 0)
    #expect(stage.sentWhenReading == [0, 1, 2], "each line was asked for only when the one before had been answered")
  }

  @Test func aBatchStopsAtTheFirstFailureAndSaysWhichLine() {
    var stage = Stage([Self.done, Self.refused, Self.done])
    stage.input = ["# comment", "out", "", "zoom Safari", "desktop"]
    #expect(stage.run("-") == 1)
    #expect(stage.sent == ["out", "zoom Safari"])
    #expect(stage.err == ["line 4: no window of Safari; `windows` lists them"], "lines are counted as an editor counts them")
    #expect(stage.input == ["desktop"], "and the rest is not even read")

    stage = Stage([Stage.late])
    stage.input = ["out"]
    #expect(stage.run("-", "--timeout", "1") == 4 && stage.err == ["line 1: Arbor did not answer within 1.0 s"])
    stage = Stage([nil])
    stage.input = ["out", "home"]
    #expect(stage.run("-") == 2 && stage.err == ["line 1: Arbor is not running"] && stage.sent == ["out"])
  }

  /// What came before it has been done by then: a batch is read as it arrives. The line itself is not sent.
  @Test func aLineOfABatchThatCannotBeReadIsNotSent() {
    var stage = Stage([Self.done, Self.done])
    stage.input = ["out", "zom", "home"]
    #expect(stage.run("-") == 64)
    #expect(stage.sent == ["out"])
    #expect(stage.err == ["line 2: unknown command `zom`; did you mean `zoom`?"])
    // Unchecked, it is for Arbor to say.
    stage = Stage([Self.done, Self.done, Self.done])
    stage.input = ["out", "zom", "home"]
    #expect(stage.run("-", unchecked: true) == 0)
    #expect(stage.sent == ["out", "zom", "home"])
  }

  @Test func keepGoingIsForBatchesToo() {
    var stage = Stage([Self.done, Self.refused, Self.done])
    stage.input = ["out", "zom", "zoom Safari", "desktop"]
    #expect(stage.run("-", "--keep-going") == 64, "the first failure's")
    #expect(stage.sent == ["out", "zoom Safari", "desktop"])
    #expect(stage.err == ["line 2: unknown command `zom`; did you mean `zoom`?", "line 3: no window of Safari; `windows` lists them"])
    stage = Stage([Self.done, nil, Self.done])
    stage.input = ["out", "home", "desktop"]
    #expect(stage.run("--keep-going", "-") == 2 && stage.sent == ["out", "home"], "nobody is there")
  }

  @Test func aBatchTakesTheOtherOptionsAndNoArguments() {
    var stage = Stage([Self.table])
    stage.input = ["windows"]
    #expect(stage.run("-", "--json") == 0 && stage.out == [#"[{"app":"Safari","id":412}]"#])
    stage = Stage([Self.refused])
    stage.input = ["zoom Safari"]
    #expect(stage.run("-q", "-") == 1 && stage.out.isEmpty && stage.err.isEmpty)
    for arguments in [["-", "out"], ["-", ",", "out"], ["-", "-"]] {
      var errors: [String] = []
      #expect(Arborctl.run(arguments, send: { _, _ in Self.done }, emit: { errors.append($0.err ?? "") }) == 64, "\(arguments)")
      #expect(errors == ["- takes commands from standard input, not arguments"], "\(arguments)")
    }
  }

  /// Whoever reads lines may end them at fewer characters than count as line breaks.
  @Test func aLineOfInputNeverBecomesALineWithABreakInIt() {
    let stage = Stage([Self.done, Self.done, Self.done])
    stage.input = ["out\rhome", "desktop\u{2028}"]
    #expect(stage.run("-") == 0)
    #expect(stage.sent == ["out", "home", "desktop"])
  }

  // MARK: watch

  /// Its answer is a stream, not a reply: it is handed over whole, and its exit code is arborctl's.
  @Test func watchIsHandedOverWithItsLineAndItsTime() {
    func run(_ arguments: [String], ending code: Int32 = 0) -> (code: Int32, asked: [String], times: [Double], sent: Int) {
      var (asked, times, sent): ([String], [Double], Int) = ([], [], 0)
      let result = Arborctl.run(
        arguments, watch: { line, time in asked.append(line); times.append(time); return code },
        send: { _, _ in sent += 1; return Self.done }, emit: { _ in })
      return (result, asked, times, sent)
    }
    #expect(run(["watch"]).asked == ["watch"] && run(["watch"]).times == [5] && run(["watch"]).sent == 0)
    #expect(run(["watch", "view", "focus", "--titles"]).asked == ["watch view focus --titles"])
    #expect(run(["--timeout", "2", "watch", "view"]).times == [2] && run(["watch", "view", "--timeout=2"]).asked == ["watch view"])
    // The verb is the first word of the line, not the first argument.
    #expect(run(["watch view"]).asked == ["watch view"] && run(["WATCH", "view"]).asked.count == 1)
    for code: Int32 in [0, 1, 2, 3, 4] { #expect(run(["watch"], ending: code).code == code) }
  }

  /// It ends when Arbor does, so nothing can follow it, and what came before it belongs in a line of its own.
  @Test func watchStandsAlone() {
    for arguments in [["watch", ",", "home"], ["home", ",", "watch", "view"], ["--keep-going", "home", ",", "watch"], ["watch view", ",", "home"]] {
      var (watched, sent, errors): (Int, Int, [String]) = (0, 0, [])
      let code = Arborctl.run(
        arguments, watch: { _, _ in watched += 1; return 0 }, send: { _, _ in sent += 1; return Self.done }, emit: { errors.append($0.err ?? "") })
      #expect(code == 64 && watched == 0 && sent == 0 && errors == ["watch cannot be one of several commands"], "\(arguments)")
    }
    var stage = Stage([Self.done, Self.done])
    stage.input = ["home", "watch view", "desktop"]
    #expect(stage.run("-") == 64 && stage.sent == ["home"] && stage.err == ["line 2: watch cannot be part of a batch"])
    stage = Stage([Self.done, Self.done])
    stage.input = ["home", "  WATCH  ", "desktop"]
    #expect(stage.run("-", "--keep-going", unchecked: true) == 64 && stage.sent == ["home", "desktop"], "unchecked as well: it would never end")
    // The verb is read as Arbor reads it: quotes around it come off.
    for arguments in [["\"watch\" view"], ["'watch'"], ["/watch/view"]] {
      var (watched, sent): (Int, Int) = (0, 0)
      _ = Arborctl.run(arguments, watch: { _, _ in watched += 1; return 0 }, send: { _, _ in sent += 1; return Self.done }, emit: { _ in })
      #expect(watched == 1 && sent == 0, "\(arguments)")
    }
  }

  @Test func anEventThatDoesNotExistIsFoundOutHere() {
    var watched = 0
    var errors: [String] = []
    #expect(Arborctl.run(["watch", "nonsense"], watch: { _, _ in watched += 1; return 0 }, send: { _, _ in Self.done }, emit: { errors.append($0.err ?? "") }) == 64)
    #expect(watched == 0 && errors.first?.hasPrefix("unknown event `nonsense`; the events are hello") == true, "\(errors)")
  }

  /// A script goes by these numbers.
  @Test func theHelpNamesEveryExitCode() throws {
    guard case .answer(let output) = Arborctl.invocation(["--help"]).action, let text = output.out else { return #expect(Bool(false), "answered without Arbor") }
    let codes = text[try #require(text.range(of: "It exits with")).lowerBound...]
    for code in ["0 when", "1 when", "2 when", "3 when", "4 when", "64 when"] { #expect(codes.contains(code), "\(code)") }
    #expect([Arborctl.ExitCode.done, Arborctl.ExitCode.refused, Arborctl.ExitCode.unreachable, Arborctl.ExitCode.lost, Arborctl.ExitCode.timedOut, Arborctl.ExitCode.usage] == [0, 1, 2, 3, 4, 64])
  }

  // MARK: Hostile input

  /// The protocol is one line per request, so a line break in an argument could cut a command short, or start another.
  @Test(arguments: ["\n", "\r", "\r\n", "\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}"])
  func aLineBreakInAnArgumentIsRefused(lineBreak: String) {
    for arguments in [["dock left\(lineBreak)quit"], ["zoom", "Safari\(lineBreak)quit"], ["out", ",", "zoom", "a\(lineBreak)"], ["layout", "Safari |\(lineBreak) Mail"], ["--", "out\(lineBreak)"]] {
      for unchecked in [false, true] {
        var (sent, errors): ([String], [String]) = ([], [])
        let code = Arborctl.run(arguments, unchecked: unchecked, send: { line, _ in sent.append(line); return Self.done }, emit: { errors.append($0.err ?? "") })
        #expect(code == 64 && sent.isEmpty, "\(arguments.debugDescription) unchecked \(unchecked)")
        #expect(errors == ["a command cannot contain a line break"], "\(arguments.debugDescription)")
      }
    }
  }

  @Test func noArgumentsCrashIt() {
    var random = NotationRandom(seed: 64)
    let pieces = LayoutNotationTests.pieces + [
      ",", "--json", "-q", "--help", "--version", "help", "completions", "zsh", "layout", "zoom", "dock", "left", "windows", "Safari", "a b", "-", "--",
      "--timeout", "--timeout=", "--timeout=2", "2", "--keep-going", "--quiet", "-x", "a\nb", "\r", "#", "out",
    ]
    let lines = pieces + ["out", "# note", "", "zoom Safari", "zom", "a\rb", "dock left , out"]
    for _ in 0..<12000 {
      let arguments = (0..<Int.random(in: 0...6, using: &random)).map { _ in pieces.randomElement(using: &random)! }
      var input = (0..<Int.random(in: 0...4, using: &random)).map { _ in lines.randomElement(using: &random)! }
      var emitted = 0
      var sent = 0
      let code = Arborctl.run(
        arguments, unchecked: Bool.random(using: &random), terminal: Bool.random(using: &random),
        readLine: { input.isEmpty ? nil : input.removeFirst() },
        send: { line, timeout in
          sent += 1
          let broken = line.contains { $0.isNewline }
          #expect(!broken, "\(arguments.debugDescription) sent \(line.debugDescription)")
          #expect((0.1...600).contains(timeout))
          switch Int.random(in: 0...5, using: &random) {
          case 0: throw Stage.NotRunning()
          case 1: throw Arborctl.TimedOut(description: "late")
          default: return [Self.done, Self.refused, Self.table, "junk"].randomElement(using: &random)!
          }
        }, emit: { _ in emitted += 1 })
      #expect([0, 1, 2, 4, 64].contains(code), "\(arguments.debugDescription) exited with \(code)")
      // Only a batch with nothing in it has nothing to say.
      #expect(emitted > 0 || (code == 0 && sent == 0 && arguments.contains("-")), "\(arguments.debugDescription)")
    }
  }
}
