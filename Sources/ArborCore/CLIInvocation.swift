/// What `arborctl` was asked to do, worked out from its arguments alone, so that tests can reach it.
/// `arborctl` itself only connects, prints and exits.
public struct CLIInvocation: Equatable, Sendable {
  public enum Action: Equatable, Sendable {
    /// Send each list of words as one command, one after the other: `arborctl zoom 412 , dock 413 right`.
    case commands([[String]])
    /// `-`: commands from standard input, one per line.
    case batch
    /// Answered by `arborctl` itself, so that it works when Arbor is not running.
    case help
    case version
    case completions(Shell)
  }

  public enum Shell: String, CaseIterable, Sendable {
    case zsh, bash, fish
  }

  public var action: Action
  /// Print Arbor's reply as it came, one line of JSON.
  public var rawJSON = false
  /// Seconds to wait for a reply.
  public var timeout = 5.0
  /// With several commands, carry on after one that failed.
  public var keepGoing = false
  /// Print neither answers nor refusals; the exit code says it all.
  public var quiet = false

  public init(
    action: Action, rawJSON: Bool = false, timeout: Double = 5, keepGoing: Bool = false, quiet: Bool = false
  ) {
    self.action = action
    self.rawJSON = rawJSON
    self.timeout = timeout
    self.keepGoing = keepGoing
    self.quiet = quiet
  }

  /// `arborctl`'s exit codes, for scripts. 64 is EX_USAGE of sysexits.h.
  public enum ExitCode: Int32, Sendable {
    case ok = 0
    /// Arbor answered that it would not or could not do it. Or, with a report: that it found something.
    case refused = 1
    /// Arbor is not running, or its socket cannot be reached.
    case unreachable = 2
    /// `watch` only: Arbor went away without saying that it was stopping.
    case lost = 3
    /// Arbor is there but did not answer in time.
    case timedOut = 4
    /// `arborctl` did not understand its own arguments. Nothing was sent.
    case usage = 64
  }

  public struct UsageError: Error, Equatable, CustomStringConvertible {
    public let description: String
  }

  public static let usage = """
    usage: arborctl [options] <command> [arguments] [, <command> [arguments]]…
           arborctl [options] -          run commands from standard input, one per line

    Several commands stop at the first that fails.

    options (anywhere on the line):
      --json           print Arbor's reply as it came: one line of JSON
      -q, --quiet      print neither answers nor refusals; the exit code says it all
      --timeout <s>    seconds to wait for each reply (default 5)
      --keep-going     with several commands: carry on after one that failed
      --help, -h       this text and Arbor's commands; works without Arbor running
      --version        this arborctl's version (`arborctl version` asks the running app)
      --               what follows belongs to the command, whatever it looks like

    arborctl completions zsh|bash|fish   print a completion script for that shell

    What was asked for goes to standard output, complaints to standard error.
    exit codes: 0 done, 1 Arbor refused (`doctor`: a row is ✘), 2 Arbor is not running, 3 `watch` lost Arbor,
                4 no answer in time (Arbor may still do it when it gets to it),
                64 arborctl did not understand its arguments
    """

  /// `arborctl`'s own options count anywhere on the line, because people append `--json`. Any other option is the
  /// command's if it follows the command's first word (`watch --titles`), and a mistake if it comes before.
  public static func parse(_ arguments: [String]) throws -> CLIInvocation {
    var invocation = CLIInvocation(action: .help)
    var words: [String] = []
    var wantsHelp = false
    var wantsVersion = false
    func seconds(_ text: String?) throws -> Double {
      // At most ten minutes: beyond that it is a hang by another name, and the number has to fit a timeval.
      guard let text, let seconds = Double(text), seconds >= 0.1, seconds <= 600 else {
        throw UsageError(description: "--timeout takes a number of seconds from 0.1 to 600")
      }
      return seconds
    }
    var rest = arguments[...]
    while let argument = rest.popFirst() {
      switch argument {
      case "--":
        words += rest
        rest = []
      case "--json": invocation.rawJSON = true
      case "-q", "--quiet": invocation.quiet = true
      case "--keep-going": invocation.keepGoing = true
      case "--help", "-h": wantsHelp = true
      case "--version": wantsVersion = true
      case "--timeout": invocation.timeout = try seconds(rest.popFirst())
      case _ where argument.hasPrefix("--timeout="): invocation.timeout = try seconds(String(argument.dropFirst(10)))
      default:
        if words.isEmpty || words.last == ",", argument.hasPrefix("-"), argument != "-" {
          throw UsageError(description: "unknown option \(argument), see arborctl --help")
        }
        words.append(argument)
      }
    }
    if wantsHelp { return CLIInvocation(action: .help) }
    if wantsVersion { return CLIInvocation(action: .version) }
    guard let verb = words.first else { return invocation }  // no command: help
    switch verb.lowercased() {
    case "-":
      guard words.count == 1 else { throw UsageError(description: "- takes commands from standard input, not arguments") }
      invocation.action = .batch
    case "help":
      invocation.action = .help
    case "completions":
      guard words.count == 2, let shell = Shell(rawValue: words[1].lowercased()) else {
        throw UsageError(description: "usage: arborctl completions " + Shell.allCases.map(\.rawValue).joined(separator: "|"))
      }
      invocation.action = .completions(shell)
    default:
      // The protocol is one line per request: a line break inside an argument would cut the command short.
      guard !words.contains(where: { $0.contains(where: \.isNewline) }) else {
        throw UsageError(description: "a command cannot contain a line break")
      }
      let commands = words.split(separator: ",", omittingEmptySubsequences: false).map(Array.init)
      if let empty = commands.firstIndex(of: []) {
        throw UsageError(description: "there is no command \(empty == 0 ? "before" : "after") the comma")
      }
      // It ends when Arbor does, so nothing can follow it, and what came before it belongs in a line of its own.
      guard commands.count == 1 || !commands.contains(where: { Self.verb(of: $0.joined(separator: " ")) == "watch" }) else {
        throw UsageError(description: "watch cannot be one of several commands")
      }
      invocation.action = .commands(commands)
    }
    return invocation
  }

  /// The first word of a command as it is sent. Not the first argument: `arborctl "watch view"` is one argument.
  public static func verb(of line: String) -> String? {
    line.split(whereSeparator: \.isWhitespace).first?.lowercased()
  }

  /// The commands in a batch, with their line numbers for complaints. Blank lines and lines that start
  /// with `#` are skipped, so a batch can be a commented file.
  public static func batch(_ text: String) -> [(number: Int, command: String)] {
    var result: [(number: Int, command: String)] = []
    for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
      let words = line.split(whereSeparator: \.isWhitespace)
      guard let first = words.first, !first.hasPrefix("#") else { continue }
      result.append((index + 1, words.joined(separator: " ")))
    }
    return result
  }

  /// What `arborctl` makes of a reply.
  public struct Printed: Equatable, Sendable {
    /// For standard output.
    public var answer: String?
    /// For standard error, behind the tool's name.
    public var complaint: String?
    public var exitCode: ExitCode

    public init(answer: String?, complaint: String?, exitCode: ExitCode) {
      self.answer = answer
      self.complaint = complaint
      self.exitCode = exitCode
    }
  }

  /// A refusal is a complaint: on standard output it would end up in the variable or the pipe that
  /// expected the answer. A report (a reply with a `text`) is the answer whatever it found: `doctor`
  /// with a ✘ among its rows goes where `doctor > file` and `doctor | less` look for it, whole, and
  /// the exit code alone says how it came out.
  ///
  /// - Parameter place: nil for a command that stands alone. Among others it goes before a complaint
  ///   ("line 2: " in a batch, nothing in a list), and a report that found something is followed by
  ///   its `message` as one: it stops the rest, or decides the exit code, and that has to be said.
  public static func printed(ok: Bool, message: String, text: String?, place: String? = nil) -> Printed {
    if ok { return Printed(answer: text ?? message, complaint: nil, exitCode: .ok) }
    guard let text else { return Printed(answer: nil, complaint: (place ?? "") + message, exitCode: .refused) }
    return Printed(answer: text, complaint: place.map { $0 + message }, exitCode: .refused)
  }
}

extension Command {
  /// Every verb in `helpText`, in its order. Read from the help, so that a command that is documented
  /// is completed, and `CLIInvocationTests` fails for a line of help that names no command.
  private static func isCommandWord(_ word: String) -> Bool {
    guard word.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }), word.first != "-" else { return false }
    do {
      _ = try parse(words: [word])
      return true
    } catch {
      // It may want arguments, but it must not be unknown.
      return !"\(error)".contains("unknown command")
    }
  }

  public static var documentedVerbs: [String] {
    var verbs: [String] = []
    // Commands are indented by two spaces; headings are not, and continuation lines by much more.
    // Each run of command lines is a table: syntax on the left, what it does from a fixed column on.
    var table: [Substring] = []
    func finishTable() {
      // The column is where most lines start again after a run of spaces. Taken from the table rather than
      // from each line, because a syntax that fills its column is followed by a single space.
      var votes: [Int: Int] = [:]
      for line in table {
        let characters = Array(line)
        if let gap = characters.indices.dropFirst(2).first(where: { characters[$0] == " " && characters[$0 - 1] == " " }),
          let start = characters[gap...].firstIndex(where: { $0 != " " })
        {
          votes[start, default: 0] += 1
        }
      }
      let column = votes.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key ?? Int.max
      for line in table {
        // A bar by itself separates commands. Inside a word (`[on|off]`) or inside brackets (`[--titles | --ids]`) it
        // separates values, and so it does after a command that takes words of its own (`trace on | off | status`),
        // which only the parser can tell: what it does not know as a command is not offered as one.
        var depth = 0
        var startsCommand = true
        for word in line.prefix(column).split(separator: " ") {
          if word == "|", depth == 0 {
            startsCommand = true
            continue
          }
          if startsCommand, !verbs.contains(String(word)), isCommandWord(String(word)) { verbs.append(String(word)) }
          startsCommand = false
          depth += word.filter { $0 == "[" }.count - word.filter { $0 == "]" }.count
        }
      }
      table = []
    }
    for line in helpText.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      if line.hasPrefix("  "), !line.hasPrefix("   ") { table.append(line) } else if !line.hasPrefix("   ") { finishTable() }
    }
    finishTable()
    return verbs
  }
}

/// Completion scripts for `arborctl`: the verbs, then edges where a command takes one.
public enum ShellCompletions {
  static let edges = ["left", "right", "top", "bottom"]
  static let verbsTakingEdges = ["dock", "neighbor", "resize"]

  public static func script(for shell: CLIInvocation.Shell, verbs: [String] = Command.documentedVerbs) -> String {
    let all = verbs.joined(separator: " ")
    let edgeVerbs = verbsTakingEdges.filter(verbs.contains)
    let edgeWords = edges.joined(separator: " ")
    switch shell {
    case .zsh:
      return """
        #compdef arborctl
        # Save as _arborctl in a folder on $fpath, or: source <(arborctl completions zsh)
        _arborctl() {
          if (( CURRENT == 2 )); then
            compadd -- \(all)
          else
            case ${words[2]} in
              \(edgeVerbs.joined(separator: "|"))) compadd -- \(edgeWords) beside ;;
              completions) compadd -- zsh bash fish ;;
            esac
          fi
        }
        # From $fpath this file is the function's body, run at the first Tab: complete now. Sourced, it registers.
        if [ "$funcstack[1]" = "_arborctl" ]; then _arborctl "$@"; else compdef _arborctl arborctl; fi
        """
    case .bash:
      return """
        # source <(arborctl completions bash)
        _arborctl() {
          local current=${COMP_WORDS[COMP_CWORD]}
          if [ "$COMP_CWORD" -eq 1 ]; then
            COMPREPLY=($(compgen -W "\(all)" -- "$current"))
          else
            case ${COMP_WORDS[1]} in
              \(edgeVerbs.joined(separator: "|"))) COMPREPLY=($(compgen -W "\(edgeWords) beside" -- "$current")) ;;
              completions) COMPREPLY=($(compgen -W "zsh bash fish" -- "$current")) ;;
            esac
          fi
        }
        complete -F _arborctl arborctl
        """
    case .fish:
      return """
        # arborctl completions fish > ~/.config/fish/completions/arborctl.fish
        complete -c arborctl -f
        complete -c arborctl -n __fish_use_subcommand -a "\(all)"
        complete -c arborctl -n "__fish_seen_subcommand_from \(edgeVerbs.joined(separator: " "))" -a "\(edgeWords) beside"
        complete -c arborctl -n "__fish_seen_subcommand_from completions" -a "zsh bash fish"
        """
    }
  }
}
