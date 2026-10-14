import ArborCore
import ArborKit
import ArborTesting
import Foundation

// arbor-sim's chaos modes (docs/TESTING.md, "Chaos"):
//
//   arbor-sim chaos <seed> [steps]          one random run, printing the script as it goes
//   arbor-sim hunt <first seed> <count> [steps]   many runs; failures are shrunk and printed
//   arbor-sim replay [--quiet]              run a chaos script from standard input, drawing each step
//   arbor-sim shrink                        shrink a failing or crashing script from standard input
//   arbor-sim ways-back                     after a script from standard input: do float-all, quitting, or starting again fetch every window?
//
// Output goes straight to the file descriptor, so that nothing is lost in a buffer when a step crashes.

private func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }

private func readScript() -> [ChaosAction] {
  var lines: [String] = []
  while let line = readLine() { lines.append(line) }
  // Accepts a script as printed by a failure or by a trace: indented, or after "step N: ".
  return ChaosAction.script(
    lines.map { line in
      guard line.hasPrefix("chaos seed "), let colon = line.range(of: ": ") else { return line }
      return String(line[colon.upperBound...])
    }.joined(separator: "\n"))
}

/// Ends the process when one step takes longer than any step should: a loop that never ends is a failure like a
/// crash, and a hunt that waits for it finds nothing else. Prints `RULE hang`, as `replay` prints a broken rule.
private final class Watchdog: @unchecked Sendable {
  private let lock = NSLock()
  private var steps = 0
  private var step = ""

  func beat(_ text: String) {
    lock.lock()
    defer { lock.unlock() }
    steps += 1
    step = text
  }

  func start(patience seconds: UInt32 = 10) {
    Thread.detachNewThread { [self] in
      var seen = -1
      while true {
        sleep(seconds)
        lock.lock()
        let (now, text) = (steps, step)
        lock.unlock()
        if now == seen {
          say("RULE hang\n  [hang] `\(text)` has taken more than \(seconds) seconds")
          exit(4)
        }
        seen = now
      }
    }
  }
}

/// Runs a chaos mode if the arguments ask for one, and returns the exit code; nil otherwise.
@MainActor
func runChaosMode(_ arguments: [String]) -> Int32? {
  func number(_ index: Int, default fallback: UInt64) -> UInt64 {
    arguments.count > index ? UInt64(arguments[index]) ?? fallback : fallback
  }
  if ["chaos", "hunt", "replay", "ways-back"].contains(arguments.first) {
    let watchdog = Watchdog()
    ChaosRunner.beforeEachStep = { watchdog.beat($0.text) }
    watchdog.start()
  }
  // `--known` reports the known failures like any other; `--known=rule,rule` only those.
  var excused = ChaosRunner.knownRules
  for argument in arguments where argument.hasPrefix("--known") {
    let named = argument.dropFirst("--known".count).drop { $0 == "=" }.split(separator: ",").map(String.init)
    excused = named.isEmpty ? [] : excused.subtracting(named)
  }
  switch arguments.first {
  case "chaos":
    guard arguments.count >= 2 else {
      say("usage: arbor-sim chaos <seed> [steps]")
      return 2
    }
    guard
      let failure = ChaosRunner.run(
        seed: number(1, default: 1), steps: Int(number(2, default: 250)), excusing: excused, echo: say)
    else {
      say("# every invariant held")
      return 0
    }
    say("")
    say("\(ChaosRunner.shrink(failure))")
    return 1

  case "hunt":
    let (first, count, steps) = (number(1, default: 1), number(2, default: 100), Int(number(3, default: 250)))
    var byRule: [String: Int] = [:]
    var known: [String: Int] = [:]
    for seed in first..<(first + count) {
      // If a step crashes, the last line on standard error says which seed to run with `chaos`.
      FileHandle.standardError.write(Data("seed \(seed)\n".utf8))
      guard
        let failure = ChaosRunner.run(seed: seed, steps: steps, excusing: excused, known: { known[$0, default: 0] += 1 })
      else { continue }
      byRule[failure.rule, default: 0] += 1
      // A few shrunk scripts per rule are enough to work on; the rest are counted.
      if byRule[failure.rule]! <= 3 {
        say("\(ChaosRunner.shrink(failure))\n")
      } else {
        say("seed \(seed): \(failure.violations[0])")
      }
    }
    say("\(count) seeds × \(steps) steps: " + (byRule.isEmpty ? "every invariant held" : "\(byRule.sorted { $0.key < $1.key })"))
    for (rule, seeds) in known.sorted(by: { $0.key < $1.key }) { say("known: \(rule) in \(seeds) seeds") }
    return byRule.isEmpty ? 0 : 1

  case "replay":
    let quiet = arguments.contains("--quiet")
    let runner = ChaosRunner()
    runner.checksFilesAtEveryStep = true
    for (index, action) in readScript().enumerated() {
      say(quiet ? "STEP \(index + 1)" : "> \(action.text)")
      let mark = runner.system.frameLog.count
      let violations = runner.step(action)
      if !quiet { say(runner.harness.ascii(columns: 64, rows: 16) + "\n") }
      if arguments.contains("--frames") {
        // Who moved what: Arbor's own moves in this step, in order, then where every window is.
        for move in runner.system.frameLog[min(mark, runner.system.frameLog.count)...] { say("  arbor: \(move.window) to \(move.frame.brief)") }
        for (id, fake) in runner.system.windows.sorted(by: { $0.key < $1.key }) { say("  \(id) at \(fake.snapshot.frame.brief)") }
      }
      if let first = violations.first {
        say("RULE \(first.rule)")
        for violation in violations { say("  \(violation)") }
        return 1
      }
    }
    if !quiet { say("# every invariant held") }
    return 0

  case "ways-back":
    // For a script that ends with a window gone: which of the things a person would try brings it back?
    let script = readScript()
    func names(_ windows: [WindowID]) -> String { windows.isEmpty ? "every window is within reach" : "OUT OF REACH: \(windows)" }
    say("at the end of the script: \(names(ChaosRunner.windowsOutOfReach(after: script, then: nil)))")
    var worked = false
    for way in ChaosRunner.WayBack.allCases {
      let left = ChaosRunner.windowsOutOfReach(after: script, then: way)
      if left.isEmpty { worked = true }
      say("after \(way.rawValue): \(names(left))")
    }
    return worked ? 0 : 1

  case "shrink":
    let script = readScript()
    guard let failure = replayInChild(script) else {
      say("# the script neither crashes nor breaks a rule")
      return 0
    }
    say("\(ChaosRunner.shrink(failure, test: replayInChild))")
    return 1

  default:
    return nil
  }
}

/// Replays a script in a child process, so that a crash counts as a failure (rule `crash`) like any other.
@MainActor
private func replayInChild(_ script: [ChaosAction]) -> ChaosFailure? {
  let child = Process()
  child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
  child.arguments = ["replay", "--quiet"]
  let (input, output) = (Pipe(), Pipe())
  child.standardInput = input
  child.standardOutput = output
  child.standardError = FileHandle.nullDevice
  do { try child.run() } catch { return nil }
  input.fileHandleForWriting.write(Data((script.map(\.text).joined(separator: "\n") + "\n").utf8))
  try? input.fileHandleForWriting.close()
  let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  child.waitUntilExit()
  guard child.terminationReason == .uncaughtSignal || child.terminationStatus != 0 else { return nil }

  let lines = text.split(separator: "\n").map(String.init)
  let step = lines.last { $0.hasPrefix("STEP ") }.flatMap { Int($0.dropFirst(5)) } ?? script.count
  let rule = lines.last { $0.hasPrefix("RULE ") }.map { String($0.dropFirst(5)) } ?? "crash"
  let message = rule == "crash" ? "the process died in `\(script[step - 1].text)`" : lines.last ?? ""
  return ChaosFailure(seed: nil, violations: [InvariantViolation(rule, message)], script: Array(script.prefix(step)))
}
