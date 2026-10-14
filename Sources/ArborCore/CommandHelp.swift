/// What `help <command>`, "did you mean", and shell completions know about commands.
///
/// All of it is read out of `Command.helpText`, so a command that is in the help has these too, without a second list to
/// keep in step. The format they rely on: an entry is indented by two spaces and has its usage, two or more spaces,
/// and its description; alternatives in a usage are separated by ` | `; lines indented further continue the description.
extension Command {
  public struct HelpEntry: Equatable, Sendable {
    /// `["float [window]", "toggle-float [window]"]`
    public var usages: [String]
    public var description: String
    /// "Look", "Arrange", "Arbor itself".
    public var section: String

    public var verbs: [String] { usages.map { String($0.prefix { $0 != " " }) } }
  }

  public static let helpEntries: [HelpEntry] = {
    var entries: [HelpEntry] = []
    var section = ""
    let lines = helpText.split(separator: "\n", omittingEmptySubsequences: true)
    // Where descriptions begin: the column at which most lines go on after a wide gap. A usage that fills its column to the last
    // place is followed by one space only (`reset <key> | reset all | reset everything back to the defaults`).
    var votes: [Int: Int] = [:]
    for line in lines where line.hasPrefix("  ") && !line.hasPrefix("   ") {
      guard let gap = line.dropFirst(2).firstRange(of: "  ") else { continue }
      votes[line.distance(from: line.startIndex, to: line[gap.upperBound...].firstIndex { $0 != " " } ?? line.endIndex), default: 0] += 1
    }
    let column = votes.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key ?? Int.max
    for line in lines {
      let indent = line.prefix { $0 == " " }.count
      let content = line.dropFirst(indent)
      if indent == 0 {
        // `Settings (each change applies at once…)`
        var heading = content.prefix { $0 != ":" && $0 != "(" }
        while heading.last == " " { heading.removeLast() }
        section = String(heading)
      } else if indent == 2 {
        let (usage, description) = split(content, descriptionAt: column - indent)
        entries.append(HelpEntry(usages: alternatives(in: usage), description: description, section: section))
      } else if !entries.isEmpty {
        entries[entries.count - 1].description += (entries[entries.count - 1].description.isEmpty ? "" : " ") + content
      }
    }
    return entries
  }()

  /// A usage and its description: at the first wide gap, or failing that at the column where descriptions begin, if a word
  /// begins there.
  private static func split(_ text: Substring, descriptionAt column: Int) -> (String, String) {
    if let gap = text.firstRange(of: "  ") {
      return (String(text[..<gap.lowerBound]), String(text[gap.upperBound...].drop { $0 == " " }))
    }
    guard column > 0, text.count > column else { return (String(text), "") }
    let start = text.index(text.startIndex, offsetBy: column)
    guard text[text.index(before: start)] == " ", text[start] != " " else { return (String(text), "") }
    return (String(text[..<text.index(before: start)]), String(text[start...]))
  }

  /// Splits at ` | `, but not inside brackets: `layout [--titles | --ids]` is one usage.
  private static func alternatives(in usage: String) -> [String] {
    var result = [""]
    var depth = 0
    for word in usage.split(separator: " ") {
      if word == "|", depth == 0 {
        result.append("")
        continue
      }
      depth += word.filter { $0 == "[" || $0 == "<" }.count - word.filter { $0 == "]" || $0 == ">" }.count
      result[result.count - 1] += (result[result.count - 1].isEmpty ? "" : " ") + word
    }
    return result.filter { !$0.isEmpty }
  }

  /// Other words for a command, by the word the help uses. (The parser is where they work; a test holds the two together.)
  public static let aliases: [String: [String]] = [
    "ascii": ["draw"], "show-all": ["everything", "overview", "show-everything"], "out": ["step-out", "zoom-out"],
    "in": ["step-in", "zoom-in"], "neighbor": ["neighbour"], "zoom": ["frame"], "view": ["go-view"],
    "float": ["undock"], "bindings": ["shortcuts"], "resume": ["unpause"], "balance": ["equalize"], "find": ["go-to"],
    "check-setup": ["setup", "permissions"], "pass-through": ["passthrough"],
  ]

  /// Every command, as the help spells it, in the help's order, each once.
  public static let verbs: [String] = {
    var seen = Set<String>()
    return helpEntries.flatMap(\.verbs).filter { seen.insert($0).inserted }
  }()

  /// The help's word for `word`, which may be an alias. Nil if it is no command.
  public static func canonicalVerb(_ word: String) -> String? {
    let word = word.lowercased()
    if verbs.contains(word) { return word }
    return aliases.first { $0.value.contains(word) }?.key
  }

  /// A command's usage, what it does and its other names. Nil if `topic` is no command.
  public static func help(on topic: String) -> String? {
    guard let verb = canonicalVerb(topic) else { return nil }
    var lines: [String] = []
    for entry in helpEntries where entry.verbs.contains(verb) {
      lines.append(entry.usages.joined(separator: " | "))
      if !entry.description.isEmpty { lines.append("  " + entry.description) }
    }
    if let others = aliases[verb] { lines.append("  also: " + others.joined(separator: ", ")) }
    return lines.joined(separator: "\n")
  }

  // MARK: Did you mean

  /// The command nearest to a word that is none: one or two slips of the keyboard away, or the only one that begins with it.
  public static func suggestion(for word: String) -> String? {
    let word = word.lowercased()
    guard (2...30).contains(word.count) else { return nil }
    let candidates = verbs + verbs.flatMap { aliases[$0] ?? [] }
    // Half of a word of two letters is not a slip.
    let allowed = word.count <= 2 ? 0 : word.count <= 3 ? 1 : 2
    var best: (verb: String, distance: Int)?
    for candidate in candidates {
      let distance = editDistance(Array(word), Array(candidate), limit: allowed)
      if distance <= allowed, distance < best?.distance ?? .max { best = (candidate, distance) }
    }
    if let best { return best.verb }
    let beginning = candidates.filter { $0.hasPrefix(word) }
    return beginning.count == 1 ? beginning[0] : nil
  }

  /// Insertions, deletions, replacements and swaps of neighbours. Anything above `limit` is reported as `limit + 1`.
  static func editDistance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
    guard abs(a.count - b.count) <= limit else { return limit + 1 }
    var beforeLast = [Int](repeating: 0, count: b.count + 1)
    var last = Array(0...b.count)
    for i in 1...max(a.count, 1) where !a.isEmpty {
      var current = [i] + [Int](repeating: 0, count: b.count)
      for j in 1...max(b.count, 1) where !b.isEmpty {
        let cost = a[i - 1] == b[j - 1] ? 0 : 1
        current[j] = min(last[j] + 1, current[j - 1] + 1, last[j - 1] + cost)
        if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] { current[j] = min(current[j], beforeLast[j - 2] + 1) }
      }
      (beforeLast, last) = (last, current)
    }
    return min(last[b.count], limit + 1)
  }

  // MARK: Completions

  public enum Shell: String, CaseIterable, Sendable { case zsh, bash, fish }

  /// Words of a usage that stand for something to type. In square brackets they look like words to choose (`[points]`, `[all]`), so they
  /// are listed; `whatIsOfferedAfterEachCommand` shows a new one to whoever adds it.
  private static let placeholders: Set<Substring> = ["minutes", "bundle-id", "name", "points", "text…", "pane", "command", "events…", "n"]

  /// What can follow a command, read from its usages: words to offer, and whether windows can be named.
  static func completionWords(for verb: String) -> (words: [String], windows: Bool) {
    var words: [String] = []
    var windows = false
    for usage in helpEntries.flatMap(\.usages) where usage.prefix(while: { $0 != " " }) == verb {
      for token in usage.split(separator: " ").dropFirst() {
        let bare = token.trimmingPrefix { "[<".contains($0) }.prefix { !"]>".contains($0) }
        switch bare {
        case "|": continue
        case "window": windows = true
        case "edge": words += ["left", "right", "top", "bottom"]
        case "direction": words += ["left", "right", "up", "down"]
        case "1-9": words += (1...9).map(String.init)
        case "@display": words += ["@1", "@2"]
        // Something to type, not to choose; but `<next|previous|n>` is a choice.
        case _ where token.hasPrefix("<") && !bare.contains("|"): continue
        // `[on|off]`
        default: words += bare.split(separator: "|").filter { !placeholders.contains($0) }.map(String.init)
        }
      }
    }
    var seen = Set<String>()
    return (words.filter { seen.insert($0).inserted }, windows)
  }

  /// A completion script for `arborctl`. Install it as `arborctl help completions` says.
  public static func completions(for shell: Shell) -> String {
    // Of arborctl's own making, beside Arbor's commands.
    let extra = [("completions", "print a completion script: zsh, bash or fish")]
    let described = verbs.map { verb in (verb, helpEntries.first { $0.verbs.contains(verb) }?.description ?? "") } + extra
    func following(_ verb: String) -> (words: [String], windows: Bool) {
      switch verb {
      case "completions": (Shell.allCases.map(\.rawValue), false)
      case "help": (verbs, false)
      // A key comes first, and `add` and `remove` only after the name of a list.
      case "set": ([], false)
      case "watch": (ArborEvent.Kind.allCases.map(\.rawValue) + ["--titles"], false)
      // The help says `[window]` once for the three.
      case "unpin", "toggle-pin": completionWords(for: "pin")
      default: completionWords(for: verb)
      }
    }
    let withMore = described.map(\.0).filter { !following($0).words.isEmpty || following($0).windows }
    // Names without spaces, and bundle ids: what can be typed without quotes.
    let apps = "arborctl windows 2>/dev/null | cut -f5,6 | tr '\\t' '\\n' | grep -v ' ' | grep -vx -e - | sort -u"
    func short(_ text: String) -> String { String(text.prefix(60)) }
    // arborctl's own options count anywhere on the line, so the command is the first word that is not one, after the last comma.
    let own = Arborctl.options.map { "--\($0.name)" }.joined(separator: " ")

    switch shell {
    case .bash:
      // For the bash 3.2 of macOS too.
      var lines = [
        "# arborctl completion for bash. In ~/.bashrc: source <(arborctl completions bash)", "_arborctl() {",
        "  local cur=${COMP_WORDS[COMP_CWORD]} verb= words= i", "  for ((i = 1; i < COMP_CWORD; i++)); do", "    case \"${COMP_WORDS[i]}\" in",
        "      ,) verb= ;;", "      --timeout) ((i++)) ;;", "      -*) ;;", "      *) [ -n \"$verb\" ] || verb=${COMP_WORDS[i]} ;;", "    esac", "  done",
        "  if [ -z \"$verb\" ]; then",
        "    COMPREPLY=($(compgen -W \"\(described.map(\.0).joined(separator: " ")) \(own)\" -- \"$cur\"))", "    return", "  fi",
        "  case \"$verb\" in",
      ]
      for verb in withMore {
        let (words, windows) = following(verb)
        lines.append("    \(verb)) words=\"\(words.joined(separator: " "))\(windows ? " focused pointer $(\(apps))" : "")\" ;;")
      }
      lines += [
        "  esac", "  case \"$cur\" in -*) words=\"$words \(own)\" ;; esac", "  COMPREPLY=($(compgen -W \"$words\" -- \"$cur\"))", "}",
        "complete -F _arborctl arborctl",
      ]
      return lines.joined(separator: "\n")
    case .zsh:
      func quoted(_ text: String) -> String { text.replacing("'", with: "'\\''").replacing(":", with: "\\:") }
      var lines = [
        "#compdef arborctl", "# arborctl completion for zsh. Save as _arborctl in a folder of $fpath, or: source <(arborctl completions zsh)",
        "_arborctl() {", "  local -a commands", "  commands=(",
      ]
      lines += described.map { "    '\($0.0):\(quoted(short($0.1)))'" }
      lines += [
        "  )", "  local verb= i", "  for (( i = 2; i < CURRENT; i++ )); do", "    case $words[i] in", "      ,) verb= ;;", "      --timeout) (( i++ )) ;;",
        "      -*) ;;", "      *) [[ -n $verb ]] || verb=$words[i] ;;", "    esac", "  done",
        "  [[ $words[CURRENT] == -* ]] && compadd -- \(own)", "  if [[ -z $verb ]]; then", "    _describe 'command' commands", "    return", "  fi",
        "  case $verb in",
      ]
      for verb in withMore {
        let (words, windows) = following(verb)
        lines.append("    \(verb)) compadd -- \(words.joined(separator: " "))\(windows ? " focused pointer ${(f)\"$(\(apps))\"}" : "") ;;")
      }
      lines += ["  esac", "}", "if [ \"$funcstack[1]\" = _arborctl ]; then _arborctl \"$@\"; else compdef _arborctl arborctl; fi"]
      return lines.joined(separator: "\n")
    case .fish:
      func quoted(_ text: String) -> String { text.replacing("\\", with: "\\\\").replacing("'", with: "\\'") }
      var lines = ["# arborctl completion for fish. Save as ~/.config/fish/completions/arborctl.fish", "complete -c arborctl -f"]
      lines += Arborctl.options.map { option in
        "complete -c arborctl -l \(option.name)\(option.short.map { " -s \($0)" } ?? "")\(option.takesValue ? " -x" : "") -d '\(quoted(short(option.description)))'"
      }
      lines += described.map { "complete -c arborctl -n __fish_use_subcommand -a \($0.0) -d '\(quoted(short($0.1)))'" }
      for verb in withMore {
        let (words, windows) = following(verb)
        let condition = "complete -c arborctl -n '__fish_seen_subcommand_from \(verb)'"
        if !words.isEmpty { lines.append("\(condition) -a '\(words.joined(separator: " "))'") }
        if windows { lines.append("\(condition) -a 'focused pointer (\(quoted(apps)))'") }
      }
      return lines.joined(separator: "\n")
    }
  }
}
