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
      rule: "parked-beside-another-display", owner: "the controller",
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
      rule: "parked-not-put-back", owner: "the controller",
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
      rule: "leak-chosenOnShape", owner: "the controller (K2005)",
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
    ChaosKnownFailure(
      rule: "placed-partly-out", owner: "the controller",
      story: "A floating window gets old numbers back: it was wholly in view, was docked, the display became smaller, and Float All (or undo, `layout`, `dock`) "
        + "gives it its old frame, which hangs over the edge now. More than half shows as a rule; ⌃⌥0 fetches it. Also: its y from a tall display is used on a short one.",
      script: """
        launch
        open 113 Xcode pid 1004 at 800 10 692 359 max 825 1525
        arrange
        displays main:0,0,1280,800:0,0,72,0* windows-late
        float-all
        """,
      """
        open 109 Notes pid 1001 at 1098 493 700 455 max 763 1054
        open 111 Music pid 1006 at 657 744 512 745 min 512 745
        open 112 Xcode pid 1004 at 822 548 370 590
        launch
        displays main:0,0,1512,982:25,84,0,0* side:1512,-104,800,600:25,0,0,0 third:-294,982,1080,1920:25,0,0,0 windows-late
        move 112 1418 453 370 590
        grab 112
        release
        layout Music | Notes
        zoom-node 1
        """),
    ChaosKnownFailure(
      rule: "grown-while-hanging", owner: "the controller",
      story: "Its user leaves a floating window hanging over an edge and makes it smaller; the next layout that places floating windows gives it its remembered, larger size "
        + "at the same corner. As much shows as its user left showing.",
      script: """
        launch
        open 101 Terminal pid 1003 at 671 613 738 618
        open 102 Music pid 1006 at -194 842 716 615
        open 103 Terminal pid 1003 at -546 784 760 249
        layout Terminal | Finder
        move 101 1245 330 468 618
        close 102
        """,
      """
        open 101 Safari pid 1000 at 920 616 441 606 min 399 282
        renumber 101 102
        renumber 102 103
        launch
        open 106 Finder pid 1005 at -1037 63 1674 1034 max 735 631
        dock 103 top
        move 106 1208 777 735 431
        undo
        """),
    ChaosKnownFailure(
      rule: "docked-partly-out", owner: "F61 and the core",
      story: "A docked window that will not shrink to its slot keeps its size at the slot's corner and hangs out of the display: it should be a tile or get room (F61).",
      script: """
        launch
        open 101 Finder pid 1005 at 2376 698 772 533 min 506 533
        space 101 off
        dock 101 bottom
        space 101 on
        key down show-all
        """),
    ChaosKnownFailure(
      rule: "left-its-place", owner: "the controller",
      story: "With something docked, a display that comes or goes beside this one makes Arbor lay this one out again: a floating window that lay over a docked neighbour is moved "
        + "onto the Desktop's part, or by the width of the gap, though nothing about its own display has changed.",
      script: """
        open 104 Music pid 1006 at 638 248 352 519 max 310 1909 title main.swift
        launch
        open 113 Mail pid 1002 at -1019 232 732 742 min 732 742 title Untitled
        layout Preview | (Safari / Music)
        displays side:-1440,109,1440,900:0,0,0,43 main:0,0,1440,900:25,0,0,0* windows-late
        """,
      """
        launch
        open 102 Finder pid 1005 at -435 193 1915 2399 min 1915 2399
        dock left
        open 103 Xcode pid 1004 at -342 1241 673 673 max 786 1362
        displays main:0,0,1440,900:25,0,0,0* side:1440,33,1512,982:0,0,0,0 windows-late
        """,
      """
        launch
        open 108 Preview pid 1007 at 506 112 231 228 min 231 228 max 485 1084
        DOCK LEFT
        displays third:2720,158,1280,800:25,0,0,0 side:1440,-211,1280,800:0,0,0,0 main:0,0,1440,900:0,0,0,0* windows-late
        open 110 Terminal pid 1003 at 609 154 1688 1705 min 265 285
        displays main:0,0,1440,900:0,0,0,0* windows-late
        """),
  ]

  public nonisolated static let knownRules = Set(knownFailures.map(\.rule))
}
