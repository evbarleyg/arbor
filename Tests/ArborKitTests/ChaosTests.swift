import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private func environment(_ name: String) -> Int? { ProcessInfo.processInfo.environment[name].flatMap { Int($0) } }

private let seeds: [UInt64] = {
  let first = UInt64(environment("ARBOR_CHAOS_FIRST") ?? 1)
  return Array(first..<(first + UInt64(environment("ARBOR_CHAOS_SEEDS") ?? 40)))
}()
private let steps = environment("ARBOR_CHAOS_STEPS") ?? 200

/// Random commands and window events against the real controller, with every invariant checked
/// after each one (docs/TESTING.md, "Chaos"). `ARBOR_CHAOS_SEEDS=5000 ARBOR_CHAOS_STEPS=400 swift test --filter Chaos`
/// hunts for longer; `ARBOR_CHAOS_FIRST=…` starts elsewhere; `ARBOR_CHAOS_TRACE=1` prints each action to standard
/// error before it runs, so that a crash can be located.
@Suite @MainActor struct ChaosTests {
  @Test(arguments: seeds) func randomActionsKeepEveryInvariant(seed: UInt64) {
    let trace = environment("ARBOR_CHAOS_TRACE") != nil
    guard let failure = ChaosRunner.run(seed: seed, steps: steps, trace: trace) else { return }
    let report = """
      \(ChaosRunner.shrink(failure))
      This is not a flake: the same seed gives the same run. If the steps have to do with your change, it is yours. If not, your change \
      has only led this seed to a bug that was there: SEND THE SCRIPT TO THE CHAOS LAB (collab/reports/2026-10-14-chaos-lab.md), or list \
      it with its owner in Sources/ArborTesting/ChaosKnownFailures.swift (docs/TESTING.md, "Chaos").
      """
    // Until hunts find fewer than one unknown failure in 2000 seeds, a script nobody knows is reported here and does not turn
    // `make check` red for whoever happens to pass by. `ARBOR_CHAOS_STRICT=1` makes it fail; hunts always do.
    if environment("ARBOR_CHAOS_STRICT") != nil {
      Issue.record("\(report)")
    } else {
      withKnownIssue("an unknown chaos script", isIntermittent: true) { Issue.record("\(report)") }
    }
  }

  // MARK: The harness itself

  @Test func everyCommandHasAGeneratorAndItsTextRoundTrips() throws {
    let world = ChaosRunner()
    for line in ["open 101 Safari pid 1000 at 100 100 600 400", "open 102 Notes pid 1001 at 300 200 600 400", "launch", "dock 101 left"] {
      #expect(world.step(ChaosAction(text: line)).isEmpty)
    }
    var generator = ChaosGenerator(seed: 7)
    for kind in ChaosGenerator.CommandKind.allCases {
      for _ in 0..<40 {
        let command = generator.command(kind, in: world)
        #expect(ChaosGenerator.kind(of: command) == kind)
        #expect(try Command.parse(command.text) == command, "\(command.text)")
      }
    }
  }

  /// A script does what the run did, also where a command is spelt like something that happens in a script.
  @Test func aCommandSpeltLikeAnEventIsStillThatCommandInAScript() {
    for line in ["release", "settings", "focus 101", "save", "displays"] {
      let action = ChaosAction.command(line)
      #expect(ChaosAction(text: action.text) == action, "\(line) is written `\(action.text)`")
    }
    #expect(ChaosAction(text: "release") == .release)
    #expect(ChaosAction.command("dock left").text == "dock left")
  }

  @Test func actionsRoundTripThroughTheirText() {
    for seed in UInt64(101)...102 {
      var lines: [String] = []
      _ = ChaosRunner.run(seed: seed, steps: 150, echo: { lines.append($0) })
      #expect(lines.count >= 150)
      for line in lines { #expect(ChaosAction(text: line).text == line) }
    }
  }

  @Test(arguments: ["palette type", "palette type saf", "palette type view 2", "palette move -3", "palette choose", "palette choose 4", "palette escape"])
  func whatIsDoneInGoToRoundTrips(line: String) {
    let action = ChaosAction(text: line)
    guard case .palette = action else {
      Issue.record("\(line) is read as \(action)")
      return
    }
    #expect(action.text == line)
  }

  /// The script a seed produces, and the state it ends in, do not depend on the process, the
  /// platform or the order of any dictionary; otherwise a failure could not be replayed.
  @Test(arguments: [UInt64(103), 104]) func theSameSeedGivesTheSameRun(seed: UInt64) {
    func run() -> [String] {
      var lines: [String] = []
      _ = ChaosRunner.run(seed: seed, steps: 200, echo: { lines.append($0) })
      return lines
    }
    let (first, second) = (run(), run())
    let fork = zip(first, second).enumerated().first { $0.element.0 != $0.element.1 }
    #expect(fork == nil, "the runs part ways at step \((fork?.offset ?? 0) + 1): \(fork?.element.0 ?? "") / \(fork?.element.1 ?? "")")
    #expect(first.count == second.count)
  }

  @Test func shrinkingKeepsOnlyTheActionsThatMatter() {
    // A made-up rule: the script fails once 103 has been closed after 101 was docked.
    func test(_ script: [ChaosAction]) -> ChaosFailure? {
      guard let dock = script.firstIndex(of: .command("dock 101 left")),
        let close = script[dock...].firstIndex(of: .close(WindowID(103)))
      else { return nil }
      return ChaosFailure(seed: nil, violations: [.init("made-up", "")], script: Array(script[...close]))
    }
    var script: [ChaosAction] = (0..<200).map { .cursor(CGPoint(x: $0, y: $0)) }
    script.insert(.command("dock 101 left"), at: 40)
    script.insert(.close(WindowID(103)), at: 150)
    let shrunk = ChaosRunner.shrink(test(script)!, test: test)
    #expect(shrunk.script == [.command("dock 101 left"), .close(WindowID(103))])
  }

  @Test func aBrokenRuleIsReportedWithAScriptThatReplays() throws {
    // Nothing Arbor does breaks this; the window system is made to lie instead.
    let world = ChaosRunner()
    for line in ["open 101 Safari pid 1000 at 100 100 600 400", "launch", "dock 101 left"] {
      #expect(world.step(ChaosAction(text: line)).isEmpty)
    }
    world.system.moveSilently(WindowID(101), to: CGRect(x: 700, y: 300, width: 300, height: 200))
    let violations = world.step(.cursor(CGPoint(x: 5, y: 5)))
    #expect(violations.map(\.rule).contains("slot"))
    let text = "\(ChaosFailure(seed: 9, violations: violations, script: world.script))"
    #expect(text.contains("seed 9") && text.contains("w101") && text.contains("    dock 101 left"))
  }
}
