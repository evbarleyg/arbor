import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Runs the examples in the documentation, so that what people copy from it works and prints what it says.
///
/// In a Markdown file, every fenced block marked `console` is a transcript:
///
///     <!-- windows: Safari, Mail "Inbox", Google Chrome [com.google.Chrome] -->
///     ```console
///     $ arborctl layout "Safari | Mail"
///     arranged 2 windows, floated 1
///     ```
///
/// Lines that begin with `$ ` are run, and the lines up to the next one must be exactly what is printed.
/// `arborctl <words>` is the real `Arborctl.run` talking to a real controller over fake windows, as seen in a terminal
/// (stdout and stderr together); `arborctl … | <rest>` hands its stdout to `sh -c '<rest>'`, as a pipe does; `echo $?` prints the
/// last exit code; `open "arbor://…"` goes down the road URLs take. A pipeline that needs `jq` is only run where `jq`
/// is installed. Comments set the scene:
///
/// - `<!-- windows: A, B "Title", C [bundle.id] -->` starts afresh with these windows open, floating, ids from 101;
/// - `<!-- displays: 2 -->`, before `windows`, adds a second display to the right of the first;
/// - `<!-- opens: A -->` opens another window; `<!-- focuses: 102 -->` is the user clicking a window.
///
/// A block marked `json` after `<!-- settings -->` must be a fragment of settings.json that loads, with
/// no shortcut or rule skipped. The block after `<!-- file: morning.arbor -->` is that file, which `arborctl - < morning.arbor` then reads.
///
/// Run the tests with `ARBOR_UPDATE_DOCS=1` to write what is really printed into the files.
@MainActor
struct DocTranscript {
  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  /// What may stand after a `|` in a transcript.
  static let filters: Set = ["cut", "jq", "head", "tail", "sort", "uniq", "wc", "grep", "tr", "sed", "awk", "column"]
  /// Which build Arbor and arborctl are in the examples.
  static let build = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")

  struct Problem: CustomStringConvertible {
    var line: Int
    var description: String
  }

  private(set) var problems: [Problem] = []
  private(set) var commandsRun = 0
  private(set) var settingsRead = 0
  /// The file with every transcript's output replaced by what was printed.
  private(set) var corrected: [String] = []

  private var harness: Harness?
  private var displays = 1
  private var lastExitCode: Int32 = 0
  /// The files the page has shown so far, by name.
  private var files: [String: [String]] = [:]

  init(markdown: String) {
    let lines = markdown.components(separatedBy: "\n")
    var index = 0
    var expectSettings = false
    var expectFile: String?
    while index < lines.count {
      let line = lines[index]
      corrected.append(line)
      index += 1
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") {
        let directive = trimmed.dropFirst(4).dropLast(3).trimmingCharacters(in: .whitespaces)
        if directive == "settings" {
          expectSettings = true
        } else if directive.hasPrefix("file:") {
          expectFile = directive.dropFirst(5).trimmingCharacters(in: .whitespaces)
        } else {
          follow(directive, line: index)
        }
        continue
      }
      guard trimmed.hasPrefix("```"), trimmed != "```" else { continue }
      var block: [String] = []
      let start = index
      while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces) != "```" {
        block.append(lines[index])
        index += 1
      }
      if let name = expectFile {
        files[name] = block
        expectFile = nil
        corrected += block
        continue
      }
      switch trimmed.dropFirst(3) {
      case "console":
        corrected += run(block, firstLine: start + 1)
      case "json" where expectSettings:
        read(settings: block.joined(separator: "\n"), line: start + 1)
        expectSettings = false
        corrected += block
      default:
        corrected += block
      }
    }
  }

  // MARK: Setting the scene

  private mutating func follow(_ directive: String, line: Int) {
    guard let colon = directive.firstIndex(of: ":") else { return }
    let value = directive[directive.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    switch directive[..<colon] {
    case "displays":
      displays = Int(value) ?? 1
    case "windows":
      var list = [FakeWindowSystem.standardDisplay]
      if displays > 1 {
        let frame = CGRect(x: 1440, y: 0, width: 1280, height: 800)
        list.append(DisplaySnapshot(id: DisplayID("side"), frame: frame, visibleFrame: frame, isMain: false))
      }
      let h = Harness(displays: list)
      // What a reader's own Arbor would say, rather than the `dev` of a build that is in no bundle.
      h.controller.buildInfo = Self.build
      for item in value.components(separatedBy: ",") where !item.trimmingCharacters(in: .whitespaces).isEmpty { open(item, in: h) }
      h.start()
      harness = h
      displays = 1
    case "opens":
      guard let harness else { return problems.append(Problem(line: line, description: "`opens` before `windows`")) }
      for item in value.components(separatedBy: ",") { open(item, in: harness) }
    case "focuses":
      guard let harness, let id = WindowID(word: value) else {
        return problems.append(Problem(line: line, description: "`focuses` needs a window number, after `windows`"))
      }
      harness.system.userFocus(id)
    default:
      break
    }
  }

  /// `Safari`, `Mail "Inbox"`, `Google Chrome [com.google.Chrome]`.
  private func open(_ item: String, in h: Harness) {
    var name = item
    func cut(_ opening: Character, _ closing: Character) -> String? {
      guard let start = name.firstIndex(of: opening), let end = name.lastIndex(of: closing), start < end else { return nil }
      let inner = String(name[name.index(after: start)..<end])
      name.removeSubrange(start...end)
      return inner
    }
    let title = cut("\"", "\"")
    let bundle = cut("[", "]")
    h.system.open(app: name.trimmingCharacters(in: .whitespaces), bundleID: bundle, title: title)
  }

  // MARK: Transcripts

  /// Returns the block as it should read.
  private mutating func run(_ block: [String], firstLine: Int) -> [String] {
    var result: [String] = []
    var index = 0
    while index < block.count {
      let line = block[index]
      result.append(line)
      index += 1
      guard line.hasPrefix("$ ") else {
        problems.append(Problem(line: firstLine + index - 1, description: "output without a command: \(line)"))
        continue
      }
      var expected: [String] = []
      while index < block.count, !block[index].hasPrefix("$ ") {
        expected.append(block[index])
        index += 1
      }
      guard let printed = execute(String(line.dropFirst(2)), line: firstLine + index - expected.count - 1) else {
        result += expected
        continue
      }
      commandsRun += 1
      let actual = printed.isEmpty ? [] : printed.components(separatedBy: "\n")
      result += actual
      if actual != expected {
        problems.append(
          Problem(
            line: firstLine + index - expected.count - 1,
            description: "\(line)\n--- the file says\n\(expected.joined(separator: "\n"))\n--- Arbor prints\n\(printed)"))
      }
    }
    return result
  }

  /// What the command prints, or nil (with a problem noted) if it cannot be run here.
  private mutating func execute(_ command: String, line: Int) -> String? {
    guard let harness else {
      problems.append(Problem(line: line, description: "a transcript before any `<!-- windows: … -->`"))
      return nil
    }
    let (first, rest) = Self.splitAtPipe(command)
    guard var words = Self.shellWords(first), let program = words.first else {
      problems.append(Problem(line: line, description: "cannot split into words: \(command)"))
      return nil
    }
    // `… < morning.arbor`
    var input: [String] = []
    if words.count >= 2, words[words.count - 2] == "<" {
      guard let file = files[words[words.count - 1]] else {
        problems.append(Problem(line: line, description: "no `<!-- file: \(words[words.count - 1]) -->` before this"))
        return nil
      }
      input = file
      words.removeLast(2)
    }
    switch program {
    case "echo" where words == ["echo", "$?"]:
      return String(lastExitCode)
    case "arborctl":
      var out: [String] = []
      var err: [String] = []
      var printed: [String] = []
      lastExitCode = Arborctl.run(
        Array(words.dropFirst()), terminal: rest == nil, own: Self.build,
        readLine: { input.isEmpty ? nil : input.removeFirst() },
        send: { line, _ in
          // What the app does with a line from the socket.
          let encoder = JSONEncoder()
          encoder.outputFormatting = [.sortedKeys]
          return String(decoding: try encoder.encode(harness.run(line)), as: UTF8.self)
        },
        emit: { output in
          if let text = output.out { out.append(text) }
          if let text = output.err { err.append("arborctl: \(text)") }
          printed += [output.out, output.err.map { "arborctl: \($0)" }].compactMap { $0 }
        })
      guard let rest else { return printed.joined(separator: "\n") }
      // These tests also run on a person's own Mac, where `arborctl` is the installed one and talks to the Arbor that is running.
      // Nothing that could reach it, or write anywhere, follows a pipe: only filters do.
      var stages: String? = rest
      while let (stage, following) = stages.map(Self.splitAtPipe) {
        let program = stage.split(separator: " ").first.map(String.init) ?? ""
        guard Self.filters.contains(program) else {
          problems.append(Problem(line: line, description: "only filters can follow a pipe (\(Self.filters.sorted().joined(separator: ", "))), not `\(program)`"))
          return nil
        }
        stages = following
      }
      if rest.contains("jq "), !Self.isInstalled("jq") { return nil }
      guard let piped = Self.shell(rest, input: out.joined(separator: "\n") + (out.isEmpty ? "" : "\n")) else {
        problems.append(Problem(line: line, description: "could not run: \(rest)"))
        return nil
      }
      return (err + (piped.isEmpty ? [] : [piped])).joined(separator: "\n")
    case "open" where words.count == 2:
      switch harness.controller.admit(url: words[1]) {
      case .success(let command):
        let result = harness.controller.perform(command)
        if !result.ok { problems.append(Problem(line: line, description: "\(words[1]) failed: \(result.message)")) }
      case .failure(let error):
        problems.append(Problem(line: line, description: "\(words[1]) was refused: \(error)"))
      }
      return ""
    default:
      problems.append(Problem(line: line, description: "only `arborctl …` and `open \"arbor://…\"` can be run: \(command)"))
      return nil
    }
  }

  /// `a "x | y" | b | c` is `a "x | y"` and `b | c`.
  static func splitAtPipe(_ command: String) -> (String, String?) {
    var quote: Character?
    for index in command.indices {
      let character = command[index]
      if let open = quote {
        if character == open { quote = nil }
      } else if character == "'" || character == "\"" {
        quote = character
      } else if character == "|" {
        return (String(command[..<index]), command[command.index(after: index)...].trimmingCharacters(in: .whitespaces))
      }
    }
    return (command, nil)
  }

  static func isInstalled(_ tool: String) -> Bool { shell("command -v \(tool)", input: "")?.isEmpty == false }

  /// What `sh -c command` prints, given `input`, without the last line break. Nil if it cannot be run.
  static func shell(_ command: String, input: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", command]
    process.environment = ["PATH": "/usr/bin:/bin:/opt/homebrew/bin"]
    let (stdin, stdout) = (Pipe(), Pipe())
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = stdout
    guard (try? process.run()) != nil else { return nil }
    stdin.fileHandleForWriting.write(Data(input.utf8))
    try? stdin.fileHandleForWriting.close()
    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    var text = String(decoding: data, as: UTF8.self)
    if text.hasSuffix("\n") { text.removeLast() }
    return text
  }

  /// Splits as a shell does, for what the documentation uses: spaces, '…', "…" with \" and \\ inside, and a
  /// comment from ` #` to the end. Nil for a quote that is not closed.
  static func shellWords(_ command: String) -> [String]? {
    var words: [String] = []
    var current: String?
    var quote: Character?
    var characters = Array(command)[...]
    while let character = characters.popFirst() {
      if let open = quote {
        if character == open {
          quote = nil
        } else if character == "\\", open == "\"", let next = characters.first, next == "\"" || next == "\\" {
          current?.append(characters.removeFirst())
        } else {
          current?.append(character)
        }
      } else if character == "'" || character == "\"" {
        quote = character
        current = current ?? ""
      } else if character == " " {
        if let word = current { words.append(word) }
        current = nil
      } else if character == "#", current == nil {
        break
      } else {
        current = (current ?? "") + String(character)
      }
    }
    guard quote == nil else { return nil }
    if let word = current { words.append(word) }
    return words
  }

  // MARK: Settings

  private mutating func read(settings fragment: String, line: Int) {
    let text = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
    let json = text.hasPrefix("{") ? text : "{\(text)}"
    do {
      let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
      settingsRead += 1
      for problem in KeyBindings.effective(settings: settings).problems + settings.skippedRules {
        problems.append(Problem(line: line, description: "skipped: \(problem)"))
      }
    } catch {
      problems.append(Problem(line: line, description: "these settings do not load: \(error)"))
    }
  }
}

@Suite @MainActor struct DocTranscriptTests {
  /// The files with transcripts, and how many commands each runs at least (so that a change of
  /// format cannot quietly turn the check off).
  /// These tests run on a person's own Mac too. Nothing in a transcript may reach the installed arborctl, or write anywhere.
  @Test(arguments: [
    "arborctl windows | xargs -n1 arborctl close", "arborctl windows | pbcopy", "arborctl windows | tee /tmp/x", "arborctl windows | cut -f1 | sh",
    "arborctl windows | cut -f1 | xargs rm", "arborctl windows | arborctl -", "arborctl windows |",
  ]) func onlyFiltersFollowAPipe(command: String) {
    let transcript = DocTranscript(markdown: "<!-- windows: Safari -->\n```console\n$ \(command)\n```\n")
    #expect(transcript.commandsRun == 0)
    #expect(transcript.problems.count == 1 && transcript.problems[0].description.hasPrefix("only filters can follow a pipe"), "\(transcript.problems)")
  }

  @Test func aBarInsideQuotesIsNoPipe() {
    let transcript = DocTranscript(markdown: "<!-- windows: Safari -->\n```console\n$ arborctl windows | grep -cE 'nothing|Safari' | tr -d ' '\n1\n```\n")
    #expect(transcript.problems.isEmpty && transcript.commandsRun == 1, "\(transcript.problems)")
  }

  @Test(arguments: [("docs/LAYOUTS.md", 30), ("docs/SCRIPTING.md", 45), ("README.md", 3)])
  func theExamplesInTheDocumentationDoWhatTheySay(path: String, atLeast: Int) throws {
    let url = DocTranscript.root.appendingPathComponent(path)
    let markdown = try String(contentsOf: url, encoding: .utf8)
    let transcript = DocTranscript(markdown: markdown)
    if ProcessInfo.processInfo.environment["ARBOR_UPDATE_DOCS"] == "1" {
      try transcript.corrected.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
      return
    }
    for problem in transcript.problems { Issue.record("\(path):\(problem.line): \(problem)") }
    #expect(transcript.commandsRun >= atLeast)
    #expect(transcript.corrected.joined(separator: "\n") == markdown)
  }

  @Test func aTranscriptThatIsWrongIsCaught() {
    let transcript = DocTranscript(
      markdown: """
        <!-- windows: Safari, Mail "Inbox", Google Chrome [com.google.Chrome] -->
        ```console
        $ arborctl layout "Safari | Chrome"   # a comment
        arranged 3 windows
        $ arborctl layout --titles
        Safari~"Safari 101" | "Google Chrome"~"Google Chrome 103" | Desktop:0.5
        $ open "arbor://quit"
        $ rm -rf /
        ```
        """)
    #expect(transcript.commandsRun == 3)
    #expect(transcript.problems.map(\.line) == [3, 7, 8])
    #expect(transcript.problems[0].description.contains("arranged 2 windows"))
    #expect(transcript.corrected[3] == "arranged 2 windows")
  }

  @Test func settingsThatWouldBeSkippedAreCaught() {
    let transcript = DocTranscript(
      markdown: """
        <!-- settings -->
        ```json
        "bindings": { "ctrl+opt+1": "layout Safari | Mail / Notes", "ctrl+opt+2": "layout Safari | Mail" }
        ```
        ```json
        not checked: no comment before it
        ```
        """)
    #expect(transcript.settingsRead == 1)
    #expect(transcript.problems.count == 1)
  }

  @Test func wordsAreSplitAsAShellSplitsThem() {
    #expect(DocTranscript.shellWords("arborctl layout \"Safari | 'Visual Studio Code'\"") == ["arborctl", "layout", "Safari | 'Visual Studio Code'"])
    #expect(DocTranscript.shellWords("a 'b \"c\" d'  e\\f \"g \\\"h\\\"\" ''") == ["a", "b \"c\" d", "e\\f", "g \"h\"", ""])
    #expect(DocTranscript.shellWords("a b # c") == ["a", "b"])
    #expect(DocTranscript.shellWords("a b#c") == ["a", "b#c"])
    #expect(DocTranscript.shellWords("a \"b") == nil)
  }
}
