import ArborCore
import ArborKit
import Foundation

// arbor-sim stage-judge [<file.jsonl>…] [<limit>=<value>…]
//
// Judges the motion in traces that were recorded while the real Arbor animated (docs/TRACES.md, "The stage's log"): one line per
// motion with everything that was measured, under it a line per finding (✘) and per note (·). Without a file the trace is read
// from standard input. The limits are `StageJudge.Limits`, in seconds and points: `gap=0.05`, `duration=1.2`, or `duration=planned` for a
// run with an `animationDuration` of its own. Exits with code 0 if every motion of every trace is as it should be, 1 if there is a
// finding or a trace without any motion, 2 if a trace cannot be read.

func runStageJudge(_ arguments: [String]) -> Never {
  let usage = "usage: arbor-sim stage-judge [<file.jsonl>…] [<limit>=<value>…]\nlimits: " + StageJudge.Limits.names.joined(separator: ", ")
  var limits = StageJudge.Limits()
  var paths: [String] = []
  for argument in arguments {
    let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
    if parts.count == 2, StageJudge.Limits.names.contains(parts[0]) {
      guard limits.set(parts[0], to: parts[1]) else {
        print("\(parts[0]) cannot be \(parts[1])\n\(usage)")
        exit(2)
      }
    } else {
      paths.append(argument)
    }
  }
  guard !paths.contains(where: { $0.hasPrefix("--") }) else {
    print(usage)
    exit(2)
  }
  var code: Int32 = 0
  for path in paths.isEmpty ? [nil] : paths.map(Optional.some) {
    if paths.count > 1, let path { print("\(path):") }
    do {
      let data = try path.map { try Data(contentsOf: URL(fileURLWithPath: $0)) } ?? FileHandle.standardInput.readDataToEndOfFile()
      let report = StageJudge.report(on: try Trace(text: String(decoding: data, as: UTF8.self)), limits: limits)
      print(report.lines.joined(separator: "\n"))
      if !report.ok { code = max(code, 1) }
    } catch {
      print("cannot read \(path ?? "standard input"): \(error)")
      code = 2
    }
  }
  exit(code)
}
