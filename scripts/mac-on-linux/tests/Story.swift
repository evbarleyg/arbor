import FakeMacOS
import Foundation

// Stories and their checks (../README.md). A story sets a Mac up, lets things happen on it and says what a person would see; each check is a
// line with ✔ or ✘, as in Sources/arbor-e2e.

/// What a run was asked for.
struct Options {
  var only: [String] = []
  var isVerbose = false
  var isQuiet = false
  /// For the self-test: the run succeeds if every one of these checks ("story: check") fails, and the list of known failures does not excuse it.
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
  /// Those that only other seeds than the usual ones show. With the usual seeds, where every run is the same and they pass, they excuse nothing.
  private var sometimes: Set<String> = []
  /// In how many of the usual seeds a rule of the walk is known to break ("8 of 40 seeds"). Another number is news.
  private var knownCounts: [String: String] = [:]
  /// What is to be said at the end whatever else is said.
  private var remarks: [String] = []
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

  /// A line of the file without what changes under people who never touched the layer: its milliseconds, and at storey two, where the controller decides what is asked of the layer, all that was heard.
  private static func reports(in line: Substring) -> String {
    guard var object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else { return String(line) }
    object["ms"] = nil
    if object["storey"] as? Int == 2 { object["heard"] = nil }
    return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? String(line)
  }

  /// Holds the file against this run. If it is out of date it is rewritten, and the run fails this once. It goes out of date by what was REPORTED at storey one and on the walk, and by the stories themselves. The milliseconds
  /// are there to tell one burst from the next, and move with every change to the controller's timing; what is heard at storey two moves with every change to what the controller asks for. Both are made by people who never
  /// touched the layer: for them alone the file is left as it is, or everybody's working tree would have it changed, each a little differently, and a run would be red for whoever comes next.
  private func heardFileIsCurrent() -> Bool {
    guard let path = options.heardFile, isWholeRun else { return true }
    let text = heardLines.joined(separator: "\n") + "\n"
    let kept = try? String(contentsOfFile: path, encoding: .utf8)
    if kept == text { return true }
    if let kept, kept.split(separator: "\n").map(Self.reports) == text.split(separator: "\n").map(Self.reports) {
      let moved = zip(kept.split(separator: "\n"), text.split(separator: "\n")).filter { $0 != $1 }.count
      print("  in collab/evidence/mac-on-linux/heard.jsonl storey one's reports and the walk's are those of this run; \(moved) lines have other milliseconds, or other reports at storey two: the file is left as it is (to refresh it, delete it and run again)")
      return true
    }
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try? text.write(toFile: path, atomically: true, encoding: .utf8)
    print("  ✘ what the layer reports has changed, or the stories have: collab/evidence/mac-on-linux/heard.jsonl was out of date and has been rewritten. Look at the difference, and commit it")
    return false
  }

  func remark(_ text: String) {
    say("  \(text)")
    remarks.append(text)
  }

  /// One failure to a line: `story: check`, then ` # ` and a word on it. A rule of the walk has ` [8 of 40 seeds]` behind it.
  func readKnownFailures() {
    guard let path = options.knownFailuresFile, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
    for line in text.split(separator: "\n") where !line.hasPrefix("#") && !line.allSatisfy(\.isWhitespace) {
      let parts = line.components(separatedBy: " # ")
      var key = parts[0].trimmingCharacters(in: .whitespaces)
      if key.hasPrefix("sometimes: ") {
        key.removeFirst("sometimes: ".count)
        sometimes.insert(key)
      }
      if key.hasSuffix("]"), let open = key.range(of: " [", options: .backwards) {
        knownCounts[String(key[..<open.lowerBound])] = String(key[open.upperBound...].dropLast())
        key = String(key[..<open.lowerBound])
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

  /// `count`: for a rule of the walk that breaks, in how many seeds.
  func record(_ story: Story, _ what: String, _ ok: Bool, _ detail: String, count: String? = nil) {
    let key = "\(story.name): \(what)"
    func isNews(_ why: String = "") {
      newFailures.append(key + why)
      say("  ✘ \(what)\(detail.isEmpty ? "" : "  (\(detail))")\(why)")
      story.hasNewFailure = true
    }
    // One listed line would excuse both.
    guard checksSeen.insert(key).inserted else { return isNews("   ← TWO CHECKS OF ONE NAME IN ONE STORY: give them names of their own") }
    // The list is written for the usual seeds, with which every run is the same. With others a walk may miss what it usually finds, and find what it usually misses.
    let seedsAreTheUsual = options.walkSeeds == nil
    let isOfTheWalk = story.name.hasPrefix("the rude walk")
    switch (ok, known[key]) {
    case (true, nil):
      passed += 1
      say("  ✔ \(what)")
    case (true, .some) where sometimes.contains(key) || (isOfTheWalk && !seedsAreTheUsual):
      passed += 1
      say("  ✔ \(what)")
    case (true, .some):
      knownThatPassed.append(key)
      say("  ✔ \(what)   ← LISTED AS A KNOWN FAILURE, AND IT PASSES: delete its line in known-failures.txt")
    case (false, .some) where sometimes.contains(key) && seedsAreTheUsual:
      isNews("   ← listed as showing with other seeds only; with the usual ones it is news")
    case (false, .some) where isOfTheWalk && seedsAreTheUsual && knownCounts[key] != count:
      isNews("   ← listed with [\(knownCounts[key] ?? "no count")], and it is [\(count ?? "?")] now: better or worse, it is not the same fault any more")
    case (false, let word?):
      knownFailuresSeen.append(key)
      say("  ✘ \(what)\(detail.isEmpty ? "" : "  (\(detail))")   ← known: \(word)")
    case (false, nil):
      isNews()
    }
  }

  /// Whether a failure of this check would be news.
  func isNew(_ story: Story, _ what: String) -> Bool { known["\(story.name): \(what)"] == nil }

  /// Tells the chosen stories. Returns the exit code.
  func tellAll() -> Int32 {
    let chosen = stories.filter { story in options.only.isEmpty || options.only.contains { story.name.localizedCaseInsensitiveContains($0) } }
    // A run that was asked for nothing has shown nothing.
    guard !chosen.isEmpty else {
      print("no story's name contains \(options.only.map { "\"\($0)\"" }.joined(separator: " or ")) (--list)")
      return 2
    }
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
      // Red, and news: a check that the list of known failures excuses would let the same fault through in an ordinary run.
      let unnoticed = options.expectsRed.filter { key in !newFailures.contains { $0 == key || $0.hasPrefix(key + "   ←") } }
      for key in unnoticed {
        print("    \(knownFailuresSeen.contains(key) ? "goes red, and the list of known failures excuses it" : checksSeen.contains(key) ? "stays green" : "there is no such check"): \(key)")
      }
      return unnoticed.isEmpty ? 0 : 1
    }

    // A line nobody meets any more protects nothing and hides a slip of the pen.
    let unmet = options.only.isEmpty ? known.keys.filter { !checksSeen.contains($0) }.sorted() : []
    print("\n\(chosen.count) stories, \(passed) ✔, \(knownFailuresSeen.count) ✘ known, \(newFailures.count) ✘ new")
    for remark in remarks { print("  \(remark)") }
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
  func check(_ what: String, _ ok: Bool, _ detail: @autoclosure () -> String = "", count: String? = nil) {
    book.record(self, what, ok, ok ? "" : detail(), count: count)
  }

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
