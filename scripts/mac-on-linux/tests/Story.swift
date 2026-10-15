import FakeMacOS
import Foundation

// Stories and their checks (../README.md). A story sets a Mac up, lets things happen on it and says what a person would see; each check is a
// line with ✔ or ✘, as in Sources/arbor-e2e.

/// What a run was asked for.
struct Options {
  var only: [String] = []
  var isVerbose = false
  var isQuiet = false
  /// For the self-test: the run succeeds if every one of these checks ("story: check") fails.
  var expectsRed: [String] = []
  var knownFailuresFile: String?
  var listsOnly = false
  var walkSeeds: ClosedRange<UInt64>?
  var walkSteps = 40
  var replay: String?
  /// The file of what the layer was heard to report, to be held against this run.
  var heardFile: String?
}

@MainActor
final class Book {
  var options = Options()
  private(set) var stories: [(name: String, tell: @MainActor (Story) -> Void)] = []
  /// "story: check" → why it is known to fail.
  private var known: [String: String] = [:]
  /// Those that fail only now and then: with other seeds than the usual ones.
  private var sometimes: Set<String> = []
  private var failed: Set<String> = []
  private var passed = 0
  private var newFailures: [String] = []
  private var knownFailuresSeen: [String] = []
  private var knownThatPassed: [String] = []
  private var checksSeen: Set<String> = []

  func story(_ name: String, _ tell: @escaping @MainActor (Story) -> Void) { stories.append((name, tell)) }

  // MARK: What was heard

  /// One JSON object to a line (collab/evidence/mac-on-linux/README.md).
  private var heardLines: [String] = []

  func writeDown(_ object: [String: Any]) {
    guard options.heardFile != nil, let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) else { return }
    heardLines.append(String(decoding: data, as: UTF8.self))
  }

  /// Only a run of everything, with the usual seeds, says what the file should hold.
  var isWholeRun: Bool { options.only.isEmpty && options.walkSeeds == nil && options.expectsRed.isEmpty && !options.listsOnly }

  /// Holds the file against this run. If it is out of date it is rewritten, and the run fails this once.
  private func heardFileIsCurrent() -> Bool {
    guard let path = options.heardFile, isWholeRun else { return true }
    let text = heardLines.joined(separator: "\n") + "\n"
    if (try? String(contentsOfFile: path, encoding: .utf8)) == text { return true }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? text.write(toFile: path, atomically: true, encoding: .utf8)
    print("  ✘ what the layer reports has changed, or the stories have: collab/evidence/mac-on-linux/heard.jsonl was out of date and has been rewritten. Look at the difference, and commit it")
    return false
  }

  /// One failure to a line: `story: check`, then ` # ` and a word on it.
  func readKnownFailures() {
    guard let path = options.knownFailuresFile, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
    for line in text.split(separator: "\n") where !line.hasPrefix("#") && !line.allSatisfy(\.isWhitespace) {
      let parts = line.components(separatedBy: " # ")
      var key = parts[0].trimmingCharacters(in: .whitespaces)
      if key.hasPrefix("sometimes: ") {
        key.removeFirst("sometimes: ".count)
        sometimes.insert(key)
      }
      known[key] = parts.dropFirst().joined(separator: " # ")
    }
  }

  private func say(_ text: String) {
    guard !options.isQuiet else { return }
    print(text)
    // Into a pipe output is kept back, and a crash would take with it what led up to it.
    fflush(nil)
  }

  func record(_ story: Story, _ what: String, _ ok: Bool, _ detail: String) {
    let key = "\(story.name): \(what)"
    checksSeen.insert(key)
    if !ok { failed.insert(key) }
    switch (ok, known[key]) {
    case (true, nil):
      passed += 1
      say("  ✔ \(what)")
    // The list is written for the usual seeds. With others a walk may miss what it usually finds.
    case (true, .some) where sometimes.contains(key) || (options.walkSeeds != nil && story.name.hasPrefix("the rude walk")):
      passed += 1
      say("  ✔ \(what)")
    case (true, .some):
      knownThatPassed.append(key)
      say("  ✔ \(what)   ← LISTED AS A KNOWN FAILURE, AND IT PASSES: delete its line in known-failures.txt")
    case (false, let word?):
      knownFailuresSeen.append(key)
      say("  ✘ \(what)\(detail.isEmpty ? "" : "  (\(detail))")   ← known: \(word)")
    case (false, nil):
      newFailures.append(key)
      say("  ✘ \(what)\(detail.isEmpty ? "" : "  (\(detail))")")
      story.hasNewFailure = true
    }
  }

  /// Whether a failure of this check would be news.
  func isNew(_ story: Story, _ what: String) -> Bool { known["\(story.name): \(what)"] == nil }

  /// Tells the chosen stories. Returns the exit code.
  func tellAll() -> Int32 {
    let chosen = stories.filter { story in options.only.isEmpty || options.only.contains { story.name.localizedCaseInsensitiveContains($0) } }
    if options.listsOnly {
      for story in chosen { print(story.name) }
      return 0
    }
    for entry in chosen {
      say("\n\(entry.name)")
      let story = Story(name: entry.name, book: self)
      entry.tell(story)
      story.finish()
      if (story.hasNewFailure && options.expectsRed.isEmpty) || options.isVerbose { say(story.account()) }
    }
    if !options.expectsRed.isEmpty {
      let green = options.expectsRed.filter { !failed.contains($0) }
      for key in green { print("    \(checksSeen.contains(key) ? "stays green" : "there is no such check"): \(key)") }
      return green.isEmpty ? 0 : 1
    }

    // A line nobody meets any more protects nothing and hides a slip of the pen.
    let unmet = options.only.isEmpty ? known.keys.filter { !checksSeen.contains($0) }.sorted() : []
    print("\n\(chosen.count) stories, \(passed) ✔, \(knownFailuresSeen.count) ✘ known, \(newFailures.count) ✘ new")
    for key in newFailures { print("  ✘ NEW: \(key)") }
    for key in knownThatPassed { print("  ✔ listed as a known failure, and it passes; delete its line: \(key)") }
    for key in unmet { print("  ? listed as a known failure, and no story has such a check: \(key)") }
    let isCurrent = heardFileIsCurrent()
    return newFailures.isEmpty && knownThatPassed.isEmpty && unmet.isEmpty && isCurrent ? 0 : 1
  }
}

/// One story while it is told.
@MainActor
final class Story {
  let name: String
  private let book: Book
  var hasNewFailure = false
  /// What has to be put away when the story is over, latest first.
  private var endings: [@MainActor () -> Void] = []
  /// What a failing story prints: who has an account to give.
  private var accounts: [@MainActor () -> String] = []

  init(name: String, book: Book) {
    self.name = name
    self.book = book
  }

  /// `what` says what a person would see, or what Arbor must have understood for them to see it.
  func check(_ what: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") { book.record(self, what, ok, ok ? "" : detail()) }

  /// What this listener hears from now on goes into the file of what was heard.
  func listens(_ listener: Listener, storey: Int, from start: TimeInterval) {
    endings.append { [book, name] in
      book.writeDown([
        "story": name, "storey": storey, "manners": "as told", "heard": listener.everything.map(\.event.word),
        "ms": listener.everything.map { Int((($0.time - start) * 1000 + 0.0001).rounded(.down)) },
      ])
    }
  }

  func atTheEnd(_ ending: @escaping @MainActor () -> Void) { endings.append(ending) }
  func onFailure(_ account: @escaping @MainActor () -> String) { accounts.append(account) }
  func account() -> String { accounts.map { $0() }.joined(separator: "\n") }
  func finish() {
    // The account is asked for after the end.
    let texts = accounts.map { $0() }
    accounts = texts.map { text in { text } }
    for ending in endings.reversed() { ending() }
    endings.removeAll()
  }
}
