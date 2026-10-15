import ArborTesting
import Testing

/// The bugs on `ChaosRunner.knownFailures` are still there. A test that fails here is good news: the bug is fixed, and
/// its entry in `Sources/ArborTesting/ChaosKnownFailures.swift` is to be deleted, so that the rule guards the fix from now on.
@Suite @MainActor struct ChaosKnownFailureTests {
  @Test(arguments: ChaosRunner.knownFailures.indices) func aKnownFailureStillFails(index: Int) {
    let known = ChaosRunner.knownFailures[index]
    let broken = known.scripts.map { ChaosRunner.replayToTheEnd(ChaosAction.script($0)) }
    #expect(
      broken.contains { $0.contains { $0.rule == known.rule } },
      """
      FIXED? No script of the known failure `\(known.rule)` (\(known.owner)) breaks that rule any more. Delete its entry in \
      Sources/ArborTesting/ChaosKnownFailures.swift. If your change has nothing to do with it, delete it all the same and tell the chaos \
      lab, which hunts for a new script.
      """)
    // Some scripts pass another known failure on their way. A rule on no list is another matter, and says nothing about this one.
    for (script, all) in broken.enumerated() {
      // What breaks together with the rule is the same fault seen by another net.
      let reached = all.first { $0.rule == known.rule }?.step ?? .max
      guard let new = all.first(where: { $0.step < reached && !ChaosRunner.knownRules.contains($0.rule) }) else { continue }
      Issue.record(
        """
        A NEW FAULT? Script \(script + 1) of the known failure `\(known.rule)` breaks `\(new.rule)`, which is on no list, at step \(new.step), \
        `\(new.act.text)`. `\(known.rule)` itself is \(reached < .max ? "still broken, at step \(reached)" : "not broken after that"). \
        Play it with `arbor-sim replay --go-on`; it was not so when the script was listed, so look at what has landed since.
        """)
    }
  }
}
