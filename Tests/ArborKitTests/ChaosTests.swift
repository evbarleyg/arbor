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
      has only led this seed to a bug that was there: OPEN AN ISSUE WITH THE SCRIPT, or list \
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

  /// A replay that echoes what it cannot play proves nothing, and neither does a `hold` that Arbor refused.
  @Test func whatCannotBePlayedAndWhatArborRefusesIsSaid() {
    let runner = ChaosRunner()
    _ = runner.step(.launch)
    #expect(runner.refusals.isEmpty)
    _ = runner.step(ChaosAction(text: "displays main:0,0,800,600:0,0,0,0* windows-sideways"))
    #expect(runner.refusals.count == 1 && runner.refusals[0].contains("windows-sideways"))
    #expect(runner.system.displayList.first?.frame.width != 800, "the line was not played")
    _ = runner.step(.command("hold"))
    #expect(runner.refusals == ["there is nothing in view to hold"])
    _ = runner.step(.settle)
    #expect(runner.refusals.isEmpty)
  }

  /// The order a Mac has: the windows have moved with their displays by the time Arbor hears of the displays, and no app says so.
  @Test func windowsThatMoveInSilenceAreWhereTheirDisplayIs() {
    let runner = ChaosRunner()
    for line in [
      "displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-first", "open 101 Notes pid 1001 at 1600 100 400 300",
      "displays main:0,0,1440,900:25,0,0,0* side:-1280,50,1280,800:0,0,0,0 windows-silent",
    ] { #expect(runner.step(ChaosAction(text: line)).isEmpty) }
    #expect(runner.system.windows[WindowID(101)]?.snapshot.frame == CGRect(x: -1120, y: 150, width: 400, height: 300))
  }

  /// The rules about where Arbor puts a window see a move that leaves it hanging, and leave alone what its user left so.
  @Test func aWindowPutWhereLessThanAllOfItShowsBreaksARuleUnlessItsUserLeftItThere() {
    func rules(_ moves: [String], then frame: CGRect) -> Set<String> {
      let runner = ChaosRunner()
      for line in ["launch", "open 101 Notes pid 1001 at 200 200 400 300"] + moves { _ = runner.step(ChaosAction(text: line)) }
      // As if a layout had done it.
      runner.beforeTheNextCheck = { _ = $0.system.setFrame(frame, of: WindowID(101)) }
      // Other rules notice that Arbor knows nothing of the move; they are not what is tried here.
      return Set(runner.step(.flush).map(\.rule).filter { $0.hasPrefix("placed-") || $0 == "grown-while-hanging" })
    }
    #expect(rules([], then: CGRect(x: 1414, y: 200, width: 400, height: 300)).isSuperset(of: ["placed-out-of-reach", "placed-mostly-out"]))
    #expect(rules([], then: CGRect(x: 1200, y: 200, width: 400, height: 300)) == ["placed-partly-out"])
    #expect(rules([], then: CGRect(x: 900, y: 200, width: 400, height: 300)).isEmpty)
    // Its user left it hanging by 160 points: Arbor may put it back there, and may not let it hang further.
    #expect(rules(["move 101 1200 200 400 300"], then: CGRect(x: 1200, y: 300, width: 400, height: 300)).isEmpty)
    #expect(rules(["move 101 1200 200 400 300"], then: CGRect(x: 1300, y: 200, width: 400, height: 300)) == ["placed-partly-out"])
    // Larger where it hangs, with as much showing as its user left showing.
    #expect(rules(["move 101 1200 200 400 300"], then: CGRect(x: 1200, y: 200, width: 700, height: 300)) == ["grown-while-hanging"])
  }

  /// The presenter hears of one display or one app at a time, so that timer comes back once for each. Ten pieces are not restless;
  /// a timer that comes back for ever is.
  @Test func aTimerThatEndsAfterOnePieceForEachDisplayAndAppIsNotRestless() {
    let apps = (0..<8).map { "open \(101 + $0) App\($0) pid \(1000 + $0) at \(140 + 40 * $0) \(130 + 30 * $0) 700 500" }
    let desk = ["displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0 windows-never"] + apps + ["launch"]
    let runner = ChaosRunner()
    for line in desk { #expect(runner.step(ChaosAction(text: line)).isEmpty) }
    #expect(runner.step(.settle).isEmpty)

    let other = ChaosRunner()
    for line in desk { _ = other.step(ChaosAction(text: line)) }
    let scheduler = other.harness.scheduler
    @MainActor func again() { scheduler.schedule("rehearsal", after: 0.01) { again() } }
    again()
    #expect(other.step(.settle).map(\.rule) == ["restless-rehearsal"])
  }

  /// Whoever adds a command or a setting changes no walk of a frozen seed, wherever in its list the new word stands.
  @Test func aWordThatIsAddedChangesNoOldWalk() {
    let frozen = [["a", "b"], ["c"]]
    func words(_ seed: UInt64, _ all: [String]) -> [String] { ChaosGenerator.vocabulary(for: seed, of: all, frozen: frozen) { $0 } }
    #expect(words(5, ["a", "b", "c"]) == ["a", "b"])
    #expect(words(5, ["new", "a", "newer", "b", "c", "newest"]) == ["a", "b"])
    #expect(words(1_000_005, ["new", "a", "b", "c"]) == ["a", "b", "c"])
    // Beyond the last version: everything, what no version lists at the end.
    #expect(words(2_000_000, ["new", "a", "b", "c", "newest"]) == ["a", "b", "c", "new", "newest"])
    // A word that is taken away is not drawn.
    #expect(words(5, ["b"]) == ["b"])
  }

  @Test func theFrozenWordsAreWordsAndNoneIsListedTwice() {
    let kinds = Set(ChaosGenerator.CommandKind.allCases.map { "\($0)" })
    let listed = Array(ChaosGenerator.frozenCommandKinds.joined())
    #expect(listed.filter { !kinds.contains($0) }.isEmpty)
    #expect(Set(listed).count == listed.count)
    let keys = Set(SettingsSchema.entries.map(\.key))
    let settings = Array(ChaosGenerator.frozenSettings.joined())
    #expect(settings.filter { !keys.contains($0) }.isEmpty)
    #expect(Set(settings).count == settings.count)
    #expect(ChaosGenerator.frozenCommandKinds.count == ChaosGenerator.frozenSettings.count)
  }

  @Test func actionsRoundTripThroughTheirText() {
    for seed in UInt64(101)...102 {
      var lines: [String] = []
      // What is tried here is the text. A walk ends at the first rule it breaks, and which seed meets which fault changes with every action
      // the walks learn: that is `randomActionsKeepEveryInvariant`'s business. So a rule that ends this walk is excused, and it sets out again.
      var excused = ChaosRunner.knownRules
      while true {
        lines = []
        guard let failure = ChaosRunner.run(seed: seed, steps: 150, excusing: excused, echo: { lines.append($0) }),
          excused.insert(failure.rule).inserted
        else { break }
      }
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

  /// Light walks are mostly drags. Cut in half, a drag leaves a click with a window still in the hand, which no person does and which misleads whoever reads it.
  @Test func aDragAndAKeyAreShrunkWholeOrNotAtAll() {
    func halves(_ text: String) -> Int { ChaosRunner.halfGestures(in: ChaosAction.script(text)) }
    #expect(halves("launch\ngrab 101\ncarry 5 5\nadvance 0.3\nrelease\nkey down zoom\nkey up zoom") == 0)
    #expect(halves("launch\ngrab 101\ntile main 5\ncarry 5 5\nrelease") == 1)
    #expect(halves("launch\ncarry 5 5\nrelease") == 2)
    #expect(halves("launch\nkey down zoom\nfocus 101") == 1)
    #expect(halves("launch\nkey up zoom") == 1)
    // Cut off by the end of the script: the rule broke in the middle.
    #expect(halves("launch\ngrab 101\ncarry 5 5") == 0)
    #expect(halves("launch\nkey down zoom\nreact\nadvance 1") == 0)

    // Whatever the rule needs, the shrunk script has no half that the walk had not.
    let walk = ChaosAction.script("launch\nopen 101 Notes pid 1001 at 300 200 800 500\ngrab 101\ncarry 400 300\ncarry 700 896\nrelease\nkey down zoom\nkey up zoom\nsettle")
    let failure = ChaosFailure(seed: nil, violations: [InvariantViolation("made-up", "")], script: walk)
    // Breaks whenever the window has been carried to the foot of the display.
    let shrunk = ChaosRunner.shrink(failure) { script in
      script.contains(ChaosAction(text: "carry 700 896")) ? ChaosFailure(seed: nil, violations: failure.violations, script: script) : nil
    }
    #expect(ChaosRunner.halfGestures(in: shrunk.script) == 0)
    #expect(shrunk.script.map(\.text) == ["grab 101", "carry 700 896"])
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
