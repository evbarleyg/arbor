import Foundation

/// Everything `arborctl` decides, as pure functions: what its arguments ask for, and what to print and how to exit for each
/// reply (F50, part 4). `Sources/arborctl/main.swift` only connects, writes and exits, so the manners are tested without
/// a socket or a process.
///
///     arborctl [options] <command…> [, <command…>]…
///     arborctl [options] -                            commands from standard input, one per line
///
/// Exit codes: 0 done; 1 Arbor said no (the reason on stderr, so `$(…)` stays clean); 2 Arbor cannot be reached; 3 `watch` was cut
/// off; 4 Arbor is there but did not answer in time; 64 the command cannot be read (found out here, and nothing was sent).
public enum Arborctl {
  public enum ExitCode {
    public static let done: Int32 = 0
    public static let refused: Int32 = 1
    public static let unreachable: Int32 = 2
    /// `watch` only: Arbor went away without saying that it was stopping.
    public static let lost: Int32 = 3
    /// Arbor is there but did not answer in time. It may still do it when it gets to it.
    public static let timedOut: Int32 = 4
    /// EX_USAGE of sysexits.h.
    public static let usage: Int32 = 64
  }

  public struct Output: Equatable, Sendable {
    /// Without the line break at the end. Nil prints nothing.
    public var out: String?
    public var err: String?
    public var code: Int32

    public init(out: String? = nil, err: String? = nil, code: Int32 = ExitCode.done) {
      self.out = out
      self.err = err
      self.code = code
    }
  }

  /// What `send` throws when Arbor is there but did not answer in time. Anything else it throws means Arbor cannot be reached.
  public struct TimedOut: Error, Equatable, CustomStringConvertible {
    public let description: String
    public init(description: String) { self.description = description }
  }

  public struct Invocation: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
      /// Answered without Arbor.
      case answer(Output)
      /// Lines to send one after the other, stopping at the first that fails.
      case send([String])
      /// `-`: lines from standard input, likewise.
      case batch
      /// `watch …`: one line of JSON per event until Arbor quits. Its answer is a stream, not a reply.
      case watch(String)
      /// Ask Arbor, which knows the shortcuts in effect; if it is not running, `fallback` will do.
      case help(line: String, fallback: String)
      /// arborctl's own version, and whether the Arbor that is running is of the same build.
      case version
    }

    public var action: Action
    /// Print a reply's JSON rather than its text.
    public var json = false
    /// Print nothing; the exit code says it all.
    public var quiet = false
    /// Seconds to wait for each reply, if it was said.
    public var timeout: Double?
    /// With several commands, carry on after one that failed.
    public var keepGoing = false
  }

  /// Seconds to wait for a reply, and for one that `arborctl` can do without (`--version`, `help dock`).
  public static let patience = 5.0
  public static let patienceForExtras = 1.0

  /// How several commands end, from one line with commas or from standard input.
  struct Tally {
    var keepGoing: Bool
    /// The first thing that went wrong is what the whole reports.
    var code = ExitCode.done

    /// False when it is time to stop.
    mutating func carriesOn(after code: Int32) -> Bool {
      guard code != ExitCode.done else { return true }
      if self.code == ExitCode.done { self.code = code }
      // With nobody there, the commands that follow would only say so again.
      return keepGoing && code != ExitCode.unreachable
    }
  }

  // MARK: The whole of it

  /// What `arborctl` does with its arguments, given a way to reach Arbor and a way to print. Returns the exit code.
  ///
  /// - Parameters:
  ///   - own: which build this arborctl is, for `--version`.
  ///   - readLine: the next line of standard input, nil at its end. Asked for one at a time, because the other end may be a program
  ///     that waits for each answer.
  ///   - watch: sends a `watch` line, waits so many seconds for its first line, prints the events as they come, and returns the exit code
  ///     when the stream ends (0 Arbor quit in good order or the reader left, 1 refused, 2 not running, 3 cut off, 4 no first line in time).
  ///   - send: sends one line to Arbor, waits so many seconds and returns its reply. Throws `TimedOut` if none came in time, and
  ///     anything else if Arbor cannot be reached.
  ///   - emit: prints `out` to stdout and `err` to stderr, as each command is answered.
  public static func run(
    _ arguments: [String], unchecked: Bool = false, terminal: Bool = false, own: BuildInfo = .development,
    readLine: () -> String? = { nil }, watch: (String, Double) -> Int32 = { _, _ in ExitCode.unreachable },
    send: (String, Double) throws -> String, emit: (Output) -> Void
  ) -> Int32 {
    let invocation = invocation(arguments, unchecked: unchecked)
    func finish(_ output: Output) -> Int32 {
      emit(silenced(output, invocation.quiet))
      return output.code
    }
    switch invocation.action {
    case .answer(let output):
      return finish(output)
    case .help(let line, let fallback):
      // Also when the Arbor that is running refuses the question.
      guard let reply = try? send(line, invocation.timeout ?? patienceForExtras),
        case let answer = output(reply: reply, terminal: terminal),
        answer.code == ExitCode.done
      else { return finish(Output(out: fallback)) }
      return finish(answer)
    case .version:
      return finish(versionOutput(own: own, reply: try? send("version", invocation.timeout ?? patienceForExtras)))
    case .send(let lines):
      var tally = Tally(keepGoing: invocation.keepGoing)
      for line in lines {
        guard tally.carriesOn(after: finish(ask(line))) else { break }
      }
      return tally.code
    case .watch(let line):
      return watch(line, invocation.timeout ?? patience)
    case .batch:
      var tally = Tally(keepGoing: invocation.keepGoing)
      var number = 0
      reading: while let text = readLine() {
        number += 1
        // Usually one: whoever reads lines may end them at fewer characters than count as line breaks (not at a lone carriage return).
        for line in commands(inBatch: text) {
          var answer: Output
          if verb(of: line) == "watch" {
            // It ends when Arbor does.
            answer = Output(err: "watch cannot be part of a batch", code: ExitCode.usage)
          } else if let complaint = unchecked ? nil : complaint(about: line) {
            answer = Output(err: complaint, code: ExitCode.usage)
          } else {
            answer = ask(line)
          }
          answer.err = answer.err.map { "line \(number): \($0)" }
          guard tally.carriesOn(after: finish(answer)) else { break reading }
        }
      }
      return tally.code
    }

    func ask(_ line: String) -> Output {
      do {
        return output(reply: try send(line, invocation.timeout ?? patience), json: invocation.json, terminal: terminal)
      } catch let late as TimedOut {
        return Output(err: late.description, code: ExitCode.timedOut)
      } catch {
        return Output(err: "\(error)", code: ExitCode.unreachable)
      }
    }
  }

  /// The commands in a line of a batch. Blank lines and lines that start with `#` are skipped, so a batch can be a commented file.
  static func commands(inBatch text: String) -> [String] {
    text.split(whereSeparator: \.isNewline).compactMap { line in
      let line = line.trimmingCharacters(in: .whitespaces)
      return line.isEmpty || line.hasPrefix("#") ? nil : line
    }
  }

  /// The first word of a command as it is sent. Not the first argument: `arborctl "watch view"` is one argument.
  /// Read as Arbor reads it, so quotes around it come off.
  static func verb(of line: String) -> String? {
    Command.words(of: line).first.map { (Command.unquoted($0) ?? $0).lowercased() }
  }

  /// Why `line` cannot be sent, if it cannot.
  static func complaint(about line: String) -> String? {
    do {
      _ = try Command.parse(line)
      return nil
    } catch {
      return "\(error)"
    }
  }

  // MARK: Arguments

  /// - Parameter unchecked: send lines without reading them first (`ARBOR_UNCHECKED=1`): for talking to a newer Arbor, or
  ///   to `arbor-sim --serve`, which has words of its own.
  public static func invocation(_ arguments: [String], unchecked: Bool = false) -> Invocation {
    var invocation = Invocation(action: .send([]))
    invocation.quiet = arguments.prefix { $0 != "--" }.contains { $0 == "-q" || $0 == "--quiet" }
    func usage(_ message: String) -> Invocation {
      invocation.action = .answer(Output(err: message, code: ExitCode.usage))
      return invocation
    }
    func seconds(_ text: String?) -> Double? {
      // At most ten minutes: beyond that it is a hang by another name, and the number has to fit a timeval.
      guard let text, let seconds = Double(text), seconds >= 0.1, seconds <= 600 else { return nil }
      return seconds
    }
    let timeoutHelp = "--timeout takes a number of seconds from 0.1 to 600"
    var wantsHelp = false
    var wantsVersion = false
    var rest: [String] = []
    var left = arguments[...]
    while let argument = left.popFirst() {
      // arborctl's own count anywhere on the line, because people append `--json`. Any other option is the command's if it follows
      // the command's first word (`layout --open`, `windows --titles`, `resize right -100`), and a mistake if it comes before.
      switch argument {
      case "--":
        rest += left
        left = []
      case "--json": invocation.json = true
      case "-q", "--quiet": break
      case "--keep-going": invocation.keepGoing = true
      case "--help", "-h": wantsHelp = true
      case "--version": wantsVersion = true
      case "--timeout":
        guard let seconds = seconds(left.popFirst()) else { return usage(timeoutHelp) }
        invocation.timeout = seconds
      case _ where argument.hasPrefix("--timeout="):
        guard let seconds = seconds(String(argument.dropFirst("--timeout=".count))) else { return usage(timeoutHelp) }
        invocation.timeout = seconds
      default:
        if rest.isEmpty || rest.last == ",", argument.hasPrefix("-"), argument != "-" {
          return usage("unknown option \(argument); `arborctl --help` lists them")
        }
        rest.append(argument)
      }
    }

    if rest.first?.lowercased() == "help" {
      wantsHelp = true
      rest.removeFirst()
    }
    if wantsHelp || (rest.isEmpty && !wantsVersion) {
      guard let topic = rest.first else {
        // Answered here, because people read the help before they have Arbor running.
        invocation.action = .answer(Output(out: Command.helpText + "\n\n" + ownHelp))
        return invocation
      }
      if topic.lowercased() == "completions" {
        invocation.action = .answer(Output(out: completionsHelp))
        return invocation
      }
      guard let fallback = Command.help(on: topic) else { return usage(Command.unknown(topic)) }
      invocation.action = .help(line: "help \(topic.lowercased())", fallback: fallback)
      return invocation
    }
    if wantsVersion {
      invocation.action = .version
      return invocation
    }
    if rest[0] == "-" {
      guard rest.count == 1 else { return usage("- takes commands from standard input, not arguments") }
      invocation.action = .batch
      return invocation
    }
    if rest[0].lowercased() == "completions" {
      // A complaint is one line. Where to put the script is in `help completions`.
      guard rest.count == 2, let shell = Command.Shell(rawValue: rest[1].lowercased()) else {
        return usage("usage: arborctl completions zsh|bash|fish (`arborctl help completions` says where to put the script)")
      }
      invocation.action = .answer(Output(out: Command.completions(for: shell)))
      return invocation
    }

    // The protocol is one line per request: a line break inside an argument would cut the command short, or start another.
    guard !rest.contains(where: { $0.contains(where: \.isNewline) }) else { return usage("a command cannot contain a line break") }
    var lines: [String] = []
    for words in rest.split(separator: ",", omittingEmptySubsequences: false) {
      guard !words.isEmpty else { return usage("there is no command \(lines.isEmpty ? "before" : "after") the comma") }
      let line = line(from: Array(words))
      // All of them before any is sent.
      if let complaint = unchecked ? nil : complaint(about: line) { return usage(complaint) }
      lines.append(line)
    }
    if lines.contains(where: { verb(of: $0) == "watch" }) {
      // It ends when Arbor does, so nothing can follow it, and what came before it belongs in a line of its own.
      guard lines.count == 1 else { return usage("watch cannot be one of several commands") }
      invocation.action = .watch(lines[0])
      return invocation
    }
    invocation.action = .send(lines)
    return invocation
  }

  /// The shell has taken the quotes off, so an argument with a space in it is put back in quotes: `zoom "Visual Studio Code"`
  /// arrives as one name. Three exceptions. The first argument is left as it is, so `arborctl "dock left"` still
  /// works; so is a whole command handed to `bind` as one argument (`arborctl bind ctrl+opt+h "dock left"`). And what follows
  /// `layout` is a line in a notation of its own, quoted as a whole only for the shell's sake.
  public static func line(from arguments: [String]) -> String {
    guard let verb = arguments.first else { return "" }
    guard verb.lowercased() != "layout" else { return arguments.joined(separator: " ") }
    if verb.lowercased() == "bind", arguments.count == 3 { return [verb, quotedIfNeeded(arguments[1]), arguments[2]].joined(separator: " ") }
    return ([verb] + arguments.dropFirst().map(quotedIfNeeded)).joined(separator: " ")
  }

  private static func quotedIfNeeded(_ argument: String) -> String {
    let needsQuotes = argument.isEmpty || argument.first == "\"" || argument.first == "'"
      || argument.contains { $0.isWhitespace || $0 == "/" }
    guard needsQuotes else { return argument }
    return "\"" + argument.replacing("\"", with: "\"\"") + "\""
  }

  /// Its own options, for the completion scripts. `invocation` reads them and `ownHelp` explains them; a test holds the three together.
  static let options: [(name: String, short: Character?, takesValue: Bool, description: String)] = [
    ("json", nil, false, "print the answer as JSON"), ("quiet", "q", false, "print nothing; the exit code says it all"),
    ("timeout", nil, true, "seconds to wait for each reply"), ("keep-going", nil, false, "carry on after a command that failed"),
    ("help", "h", false, "the help, or a command's usage"), ("version", nil, false, "this arborctl's version"),
  ]

  static let ownHelp = """
    arborctl itself
      arborctl [options] <command> [, <command>]…   several commands stop at the first that fails
      arborctl [options] -         commands from standard input, one per line; # starts a comment
      arborctl watch [event…]      one line of JSON per event, until Arbor quits (docs/SCRIPTING.md)
      help <command>               a command's usage, other names and shortcuts
      completions zsh|bash|fish    print a completion script
    options, anywhere on the line
      --json                       print the answer as JSON (docs/SCRIPTING.md)
      -q, --quiet                  print neither answers nor refusals; the exit code says it all
      --timeout <seconds>          how long to wait for each reply (5)
      --keep-going                 with several commands: carry on after one that failed
      --help, -h                   this text, or with a command its usage; works without Arbor running
      --version                    this arborctl's version (`arborctl version` asks the running Arbor)
      --                           what follows belongs to the command, whatever it looks like
    It exits with 0 when the command worked, 1 when Arbor said no (the reason is on stderr), 2 when Arbor is not running,
    3 when `watch` was cut off, 4 when no answer came in time, and 64 when the command cannot be read: then nothing
    was sent, and it is said even with -q. Of several commands, it is the first failure's. 4 does not mean "not done": Arbor
    has the command and runs it when it gets to it, so trying again can undo a toggle.
    """

  static let completionsHelp = """
    usage: arborctl completions zsh|bash|fish
      zsh    arborctl completions zsh > ~/.zfunc/_arborctl    (with ~/.zfunc in $fpath, before compinit)
      bash   echo 'source <(arborctl completions bash)' >> ~/.bashrc
      fish   arborctl completions fish > ~/.config/fish/completions/arborctl.fish
    """

  // MARK: Replies

  /// What to do with one of Arbor's replies.
  ///
  /// - Parameter terminal: a person is looking at stdout, so the columns of a table are lined up. Into a pipe or a file they
  ///   stay separated by tabs, for `cut`.
  static func output(reply: String, json: Bool = false, terminal: Bool = false) -> Output {
    guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(reply.utf8)), case .bool(let ok)? = value["ok"] else {
      return Output(err: "Arbor's reply cannot be read: \(reply.prefix(200))", code: ExitCode.unreachable)
    }
    func string(_ key: String) -> String? {
      if case .string(let text)? = value[key] { return text }
      return nil
    }
    guard ok else { return Output(err: string("message") ?? "Arbor said no", code: ExitCode.refused) }
    let out: String?
    if let answer = value["json"], json {
      out = answer.text
    } else if json || value["state"] != nil {
      // The whole reply: `arborctl state | jq .state`.
      out = reply
    } else {
      let text = string("text") ?? string("message") ?? ""
      // A table without rows is no line at all, not an empty one: `arborctl views | wc -l` is 0.
      out = text.isEmpty ? nil : terminal ? aligned(text) : text
    }
    return Output(out: out, err: string("warning"))
  }

  /// `--version` is this arborctl's own; `arborctl version` asks the running app. `reply` is Arbor's to `version`, nil if it cannot be
  /// reached, which is no failure: people ask before they have Arbor running. After an update the Arbor that is running
  /// may still be the old one, and commands may not mean the same to both, so that is said.
  public static func versionOutput(own: BuildInfo, reply: String?) -> Output {
    let mine = "arborctl \(own.text)"
    // Its `message` is the version alone; its `text` may go on about updates.
    guard let reply, let value = try? JSONDecoder().decode(JSONValue.self, from: Data(reply.utf8)), value["ok"] == .bool(true),
      case .string(let running)? = value["message"], running != "Arbor \(own.text)"
    else { return Output(out: mine) }
    return Output(out: mine + "\nThe Arbor that is running is another build, \(running): quit it and open Arbor again")
  }

  /// `-q` keeps quiet about what Arbor answers. A command that cannot be read is a mistake in the script, which silence would hide: in
  /// `arborctl -q zom Safari || open -a Safari` the second half would run for ever after.
  private static func silenced(_ output: Output, _ quiet: Bool) -> Output {
    guard quiet else { return output }
    return Output(err: output.code == ExitCode.usage ? output.err : nil, code: output.code)
  }

  /// Lines whose fields are separated by tabs, as columns two spaces apart. Text without tabs is left as it is.
  public static func aligned(_ text: String) -> String {
    guard text.contains("\t") else { return text }
    let rows = text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
    var widths: [Int] = []
    for row in rows {
      for (index, field) in row.enumerated() {
        if index == widths.count { widths.append(0) }
        widths[index] = max(widths[index], field.count)
      }
    }
    return rows.map { row in
      row.enumerated().map { index, field in
        index == row.count - 1 ? String(field) : field + String(repeating: " ", count: widths[index] - field.count + 2)
      }.joined()
    }.joined(separator: "\n")
  }
}

extension Command {
  /// "unknown command `zom`; did you mean `zoom`?"
  static func unknown(_ verb: String) -> String {
    "unknown command `\(verb)`; " + (suggestion(for: verb).map { "did you mean `\($0)`?" } ?? "try `help`")
  }
}
