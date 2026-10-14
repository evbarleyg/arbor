/// A bug the chaos test found that is not fixed yet: the rule it breaks, who has it, and the shrunk script.
public struct ChaosKnownFailure: Sendable {
  /// The rule the script breaks. Random runs carry on past this rule for as long as the entry is here, so a rule
  /// that is too broad hides other bugs: give the bug a rule name of its own where the rule can tell it apart.
  public var rule: String
  /// Who fixes it, and the pull request if there is one.
  public var owner: String
  /// What a person would see.
  public var story: String
  /// Scripts that show it, as `arbor-sim replay` takes them. More than one where hunts gave several: a script depends on much that has
  /// nothing to do with the bug, and an unrelated change can stop one from getting there.
  public var scripts: [String]

  public init(rule: String, owner: String, story: String, script: String, _ more: String...) {
    (self.rule, self.owner, self.story, self.scripts) = (rule, owner, story, [script] + more)
  }
}

extension ChaosRunner {
  /// Rules that are red on the trunk for a reason that has a name and an owner, so that `make check` stays green while
  /// the harness and the fixes merge in any order. `ChaosKnownFailureTests` replays every script: **when none of an entry's scripts
  /// breaks its rule any more the test fails, and the entry is to be deleted** in the same pull request as the fix. `arbor-sim replay`, `shrink`
  /// and `chaos`, `hunt --known` and `ChaosRunner.replay` report these rules like any other.
  public nonisolated static let knownFailures: [ChaosKnownFailure] = [
    ChaosKnownFailure(
      rule: "parked-beside-another-display", owner: "R5",
      story: "A window out of view beside one display is docked on another display, out of view there too. It stays where it was, where "
        + "part of it shows, though the other display has a better place.",
      script: """
        launch
        open 107 Xcode pid 1004 at 1201 365 2201 2311 min 2201 2311
        displays main:0,0,1920,1080:37,0,0,76* side:1920,-70,2560,1440:0,0,0,0 third:-60,1370,1512,982:0,0,0,88 windows-late
        grab 107
        release
        carry 4328 1189
        layout Preview | Notes | Xcode
        """,
      """
        launch
        open 103 Mail pid 1002 at -3344 467 2048 1725 min 192 328
        displays main:0,0,1280,800:0,0,0,0* side:-1512,270,1512,982:25,0,49,0 windows-never
        dock right
        open 107 Music pid 1006 at 586 355 2411 2035 min 2411 2035
        grab 107
        carry -342 258
        release
        displays side:0,0,1440,900:25,0,0,0* main:1440,-260,1920,1080:0,0,43,0 third:-278,900,2560,1440:0,98,0,0 windows-first
        flush
        dock 107 beside 103 right
        """),
    ChaosKnownFailure(
      rule: "parked-not-put-back", owner: "R5",
      story: "The app of a window that is out of view makes it larger. Its corner stays where it was, which is all `hasLeftItsCorner` "
        + "looks at, so the part that now reaches into view stays in view.",
      script: """
        launch
        open 101 Notes pid 1001 at 66 824 786 414 max 789 1410
        displays main:0,0,1920,1080:37,0,88,0* side:1920,125,1920,1080:0,0,0,0 windows-never
        arrange
        tile main 0
        limits 101 min 3439 2261 max 3439 2261
        """),
    ChaosKnownFailure(
      rule: "leak-chosenOnShape", owner: "R5 (K2005)",
      story: "Nothing a person sees. A window closes while it is in the hand: its entry is cleared, then the drag is called off, which notes "
        + "where its user left it while the workspace still knows the window. One entry for a window that is gone stays until Arbor starts again.",
      script: """
        launch
        open 102 Mail pid 1002 at 242 461 451 687 min 129 129
        grab 102
        close 102
        """,
      """
        open 107 Notes pid 1001 at 300 200 600 400
        launch
        grab 107
        close 107
        """),
  ]

  public nonisolated static let knownRules = Set(knownFailures.map(\.rule))
}
