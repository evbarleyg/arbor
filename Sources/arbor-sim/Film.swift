import ArborCore
import ArborKit
import ArborTesting
import Foundation

// arbor-sim film <script.txt> [--out <frames.jsonl>] [--fps <n>]
//
// Plays a film script against the real controller and writes down, frame by frame, where every window is, what Arbor
// draws, where the pointer is and which keys are down: one line of JSON per frame (docs/FILM.md). Whoever paints or judges the
// film needs nothing else. Besides the film's own lines (`wait`, `glide`, `click`, `tap`, `type`, `caption`…) a script can use every line
// arbor-sim knows, `expect` included. Without `--out` the frames go to standard output and the story to standard error.
//
// Exits with code 1 if a line failed that `expect fail` does not answer for, or an expectation did not hold: a film shows what
// Arbor does, so a script Arbor refuses makes no film. 2 if the script or the output cannot be opened.

@MainActor
func runFilm(_ arguments: [String]) -> Never {
  let usage = "usage: arbor-sim film <script.txt> [--out <frames.jsonl>] [--fps <frames a second>]"
  var paths: [String] = []
  var out: String?
  var fps = 60
  var index = 0
  while index < arguments.count {
    switch arguments[index] {
    case "--out" where index + 1 < arguments.count:
      out = arguments[index + 1]
      index += 2
    case "--fps" where index + 1 < arguments.count && (1...240).contains(Int(arguments[index + 1]) ?? 0):
      fps = Int(arguments[index + 1])!
      index += 2
    case let word where !word.hasPrefix("--"):
      paths.append(word)
      index += 1
    default:
      print(usage)
      exit(2)
    }
  }
  guard paths.count == 1, let script = try? String(contentsOfFile: paths[0], encoding: .utf8) else {
    print(paths.count == 1 ? "cannot read \(paths[0])" : usage)
    exit(2)
  }

  var sink = FileHandle.standardOutput
  if let out {
    guard FileManager.default.createFile(atPath: out, contents: nil), let file = FileHandle(forWritingAtPath: out) else {
      print("cannot write \(out)")
      exit(2)
    }
    sink = file
  }
  func tell(_ text: String) {
    if out == nil { FileHandle.standardError.write(Data((text + "\n").utf8)) } else { print(text) }
  }

  let director = FilmDirector(fps: fps)
  director.folder = URL(fileURLWithPath: paths[0]).deletingLastPathComponent()
  let harness = director.harness
  harness.recorder.limits.seconds = .infinity
  // Written in pieces of about a megabyte: a film has thousands of lines.
  var waiting = Data()
  director.write = { line in
    waiting.append(contentsOf: line.utf8)
    waiting.append(10)
    if waiting.count > 1 << 20 {
      sink.write(waiting)
      waiting.removeAll(keepingCapacity: true)
    }
  }
  var printLayout = false
  director.otherwise = { words in simulate(words, harness: harness, printLayout: &printLayout) }

  var lastOK = true
  var unanswered: String?
  var failures = 0
  var said = 0
  func settleFailure() {
    guard let line = unanswered else { return }
    unanswered = nil
    failures += 1
    tell("LINE FAILED: `\(line)` (follow it with `expect fail` if it is meant to)")
  }

  for raw in script.split(separator: "\n", omittingEmptySubsequences: false) {
    let line = raw.trimmingCharacters(in: .whitespaces)
    if line.isEmpty || line.hasPrefix("#") { continue }
    let words = line.split(separator: " ").map(String.init)
    if words[0] == "expect" {
      if words.count == 2, words[1].lowercased() == "fail" { unanswered = nil }
      if let problem = ScenarioExpectation.check(Array(words.dropFirst()), harness: harness, lastCommandOK: lastOK) {
        failures += 1
        tell("EXPECTATION FAILED after frame \(director.frames): \(line): \(problem)")
      }
      continue
    }
    settleFailure()
    let (message, ok) = director.run(line)
    lastOK = ok
    if !ok { unanswered = line }
    tell(String(format: "%7.2f  > %@", Double(director.frames) / Double(fps), line))
    if !message.isEmpty, !ok || !["caption", "shot", "mark", "wait"].contains(words[0]) { tell("         \(message)") }
    for line in harness.overlays.messages.dropFirst(said) { tell("         on screen: \(line.model.line)") }
    said = harness.overlays.messages.count
    if harness.controller.isRunning, !harness.scheduler.pendingKeys.contains(where: { $0.hasPrefix("space-") }) {
      for problem in harness.staleLayouts() {
        failures += 1
        tell("LAYOUT OUT OF DATE: \(problem)")
      }
    }
  }
  settleFailure()
  director.finish()
  sink.write(waiting)
  try? sink.close()
  tell(String(format: "%d frames, %.2f s at %d frames a second", director.frames, Double(director.frames) / Double(fps), fps))
  if failures > 0 { tell("\(failures) problem(s)") }
  exit(failures > 0 ? 1 : 0)
}
