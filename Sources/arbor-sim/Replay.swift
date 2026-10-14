import ArborCore
import ArborKit
import ArborTesting
import Foundation

// arbor-sim replay <file.jsonl> [--strict] [--verbose]
//
// Replays a trace recorded with `arborctl trace on` (docs/TRACES.md) against the real controller and tells
// the story: what macOS reported, what Arbor did, and drawings of the layout whenever it changed. If
// `<file>.expect` exists beside the trace, its lines are checked at the end. Exits with code 1 if the replay
// found a problem, 2 if the trace cannot be read.

@MainActor
func runReplay(_ arguments: [String]) -> Never {
  let usage = "usage: arbor-sim replay <file.jsonl> [--strict] [--verbose]"
  let flags = arguments.filter { $0.hasPrefix("--") }
  let paths = arguments.filter { !$0.hasPrefix("--") }
  guard paths.count == 1, Set(flags).isSubset(of: ["--strict", "--verbose"]) else {
    print(usage)
    exit(2)
  }
  let url = URL(fileURLWithPath: paths[0])
  let trace: Trace
  do {
    trace = try Trace(contentsOf: url)
  } catch {
    print("cannot read \(paths[0]): \(error)")
    exit(2)
  }
  let expectations = try? String(contentsOf: url.deletingPathExtension().appendingPathExtension("expect"), encoding: .utf8)
  let replayer = TraceReplayer(
    trace, mode: flags.contains("--strict") ? .strict : .free, verbose: flags.contains("--verbose"))
  let report = replayer.run(expectations: expectations)
  print(report.story.joined(separator: "\n"))
  print("")
  print(
    "\(report.delivered) events, commands and timers replayed; Arbor's calls answered from the trace: "
      + "\(report.answeredFromTrace), by the model: \(report.answeredByModel)")
  if report.ok {
    print("no problems" + (expectations == nil ? "" : "; the expectations hold"))
    exit(0)
  }
  print("\(report.problems.count) problem(s):")
  for problem in report.problems { print("  \(problem)") }
  exit(1)
}
