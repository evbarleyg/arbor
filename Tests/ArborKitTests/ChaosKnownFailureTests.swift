import ArborTesting
import Testing

/// The bugs on `ChaosRunner.knownFailures` are still there. A test that fails here is good news: the bug is fixed, and
/// its entry in `Sources/ArborTesting/ChaosKnownFailures.swift` is to be deleted, so that the rule guards the fix from now on.
@Suite @MainActor struct ChaosKnownFailureTests {
  @Test(arguments: ChaosRunner.knownFailures.indices) func aKnownFailureStillFails(index: Int) {
    let known = ChaosRunner.knownFailures[index]
    // Some scripts pass another known failure on their way.
    let others = ChaosRunner.knownRules.subtracting([known.rule])
    let rules = known.scripts.flatMap { ChaosRunner.replay(ChaosAction.script($0), excusing: others)?.violations.map(\.rule) ?? [] }
    #expect(
      rules.contains(known.rule),
      """
      FIXED? No script of the known failure `\(known.rule)` (\(known.owner)) breaks that rule any more\
      \(rules.isEmpty ? "" : "; they break \(rules)"). Delete its entry in Sources/ArborTesting/ChaosKnownFailures.swift. If your change has \
      nothing to do with it, delete it all the same and tell the chaos lab, which hunts for a new script.
      """)
  }
}
