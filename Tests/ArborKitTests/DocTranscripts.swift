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
/// `arborctl <words>` goes to a real controller over fake windows, joined as arborctl joins them;
/// `open "arbor://…"` goes down the road URLs take. Comments set the scene:
///
/// - `<!-- windows: A, B "Title", C [bundle.id] -->` starts afresh with these windows open, floating, ids from 101;
/// - `<!-- displays: 2 -->`, before `windows`, adds a second display to the right of the first;
/// - `<!-- opens: A -->` opens another window; `<!-- focuses: 102 -->` is the user clicking a window.
///
/// A block marked `json` after `<!-- settings -->` must be a fragment of settings.json that loads, with
/// no shortcut or rule skipped.
///
/// Run the tests with `ARBOR_UPDATE_DOCS=1` to write what is really printed into the files.
@MainActor
struct DocTranscript {
  static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

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

  init(markdown: String) {
    let lines = markdown.components(separatedBy: "\n")
    var index = 0
    var expectSettings = false
    while index < lines.count {
      let line = lines[index]
      corrected.append(line)
      index += 1
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") {
        let directive = trimmed.dropFirst(4).dropLast(3).trimmingCharacters(in: .whitespaces)
        if directive == "settings" { expectSettings = true } else { follow(directive, line: index) }
        continue
      }
      guard trimmed.hasPrefix("```"), trimmed != "```" else { continue }
      var block: [String] = []
      let start = index
      while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces) != "```" {
        block.append(lines[index])
        index += 1
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
    guard let words = Self.shellWords(command), let program = words.first else {
      problems.append(Problem(line: line, description: "cannot split into words: \(command)"))
      return nil
    }
    switch program {
    case "arborctl":
      // What arborctl does with its arguments, and with the reply.
      let result = harness.run(words.dropFirst().joined(separator: " "))
      return result.text ?? result.message
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
  @Test(arguments: [("docs/LAYOUTS.md", 30), ("README.md", 3)])
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
