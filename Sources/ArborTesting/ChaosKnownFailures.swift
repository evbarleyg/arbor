/// A bug the chaos test found that is not fixed yet: the rule it breaks, who has it, and the shrunk script.
public struct ChaosKnownFailure: Sendable {
  /// The rule the script breaks. Random runs carry on past this rule for as long as the entry is here, so a rule
  /// that is too broad hides other bugs: give the bug a rule name of its own where the rule can tell it apart.
  public var rule: String
  /// Who fixes it, and the pull request if there is one.
  public var owner: String
  /// 1: a window is lost and no ordinary way fetches it. 2: an ordinary day meets it and a person minds. 3: a nuisance. 4: hardly seen.
  /// The viable gate (docs/VIABLE.md) excuses no entry of severity 1 or 2.
  public var severity: Int
  /// What a person would see.
  public var story: String
  /// Scripts that show it, as `arbor-sim replay` takes them. More than one where hunts gave several: a script depends on much that has
  /// nothing to do with the bug, and an unrelated change can stop one from getting there.
  public var scripts: [String]

  public init(rule: String, owner: String, severity: Int = 3, story: String, script: String, _ more: String...) {
    (self.rule, self.owner, self.severity, self.story, self.scripts) = (rule, owner, severity, story, [script] + more)
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
        mac-tiling off
        open 107 Xcode pid 1004 at 1201 365 2201 2311 min 2201 2311
        displays main:0,0,1920,1080:37,0,0,76* side:1920,-70,2560,1440:0,0,0,0 third:-60,1370,1512,982:0,0,0,88 windows-late
        dock 107 left
        carry 4328 1189
        layout Preview | Notes | Xcode
        """,
      """
        launch
        mac-tiling off
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
        move 101 1245 330 480 618
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
        open 105 Xcode pid 1004 at 974 214 872 578 min 622 574 max 635 574
        displays main:0,0,800,600:25,73,0,0* windows-late
        launch
        focus 105
        key down dock right
        find Xcode
        """,
      """
        launch
        open 109 Notes pid 1001 at 227 418 585 517 min 585 517 max 585 1119 title ~
        space 109 off
        dock 109 bottom
        space 109 on
        flush
        """,
      """
        displays main:0,0,1280,800:25,86,0,0* windows-never
        launch
        open 107 Xcode pid 1004 at 86 25 1194 775 min 1188 685
        key down dock right
        quit
        launch
        """),
    ChaosKnownFailure(
      rule: "left-its-place", owner: "the controller",
      story: "With something docked, a display that comes or goes beside this one makes Arbor lay this one out again: a floating window that lay over a docked neighbour is moved "
        + "onto the Desktop's part, though nothing about its own display has changed.",
      script: """
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
    ChaosKnownFailure(
      rule: "sized-there-and-back", owner: "board 1.32: Arbor knows how small apps go", severity: 2,
      story: "Two windows Arbor has never seen at their smallest cannot both fit. The newcomer refuses its slot, room is to be made from the other, "
        + "which is asked where it stands and stops short of what is needed: the newcomer becomes a tile and the other gets its share back. It was never in a "
        + "wrong place, but narrower on the way than it ends up. `arrange` of several strangers has the same: a column is widened by one that refuses "
        + "after another in it has shrunk. Only asking tells how small a window goes, so it ends when Arbor knows beforehand.",
      script: """
        launch
        open 102 Finder pid 1005 at 1 54 1076 344 min 501 300
        key down dock left
        displays main:0,0,1280,800:25,0,48,0* windows-late
        key down in
        open 103 Mail pid 1002 at 50 235 1221 511 min 760 400
        key down toggle-float
        """,
      """
        displays main:0,0,1512,982:37,0,0,86* windows-never
        launch
        open 103 Xcode pid 1004 at 155 176 1188 685 min 1188 685
        key down toggle-float
        open 104 Mail pid 1002 at 170 68 1122 784 min 760 400
        key down dock top
        """,
      """
        open 102 Mail pid 1002 at 209 243 1023 819 min 760 400
        open 103 Notes pid 1001 at 838 122 801 648 min 709 300
        open 104 Notes pid 1001 at 351 78 709 714 min 709 300
        launch
        key down arrange
        """),
    ChaosKnownFailure(
      rule: "sized-there-and-back-floating", owner: "rule 3: a floating window's frame is its person's", severity: 3,
      story: "A floating window is squeezed onto the Desktop and given some of it back by the same command.",
      script: """
        settings {"arrangeDesktopWeight":1}
        launch
        open 106 Preview pid 1007 at -439 605 752 321 title Draft
        arrange
        open 109 Xcode pid 1004 at 874 45 848 418 title ~
        layout Xcode | Notes
        """,
      """
        displays main:0,0,1728,1117:37,86,0,0* side:1728,323,3008,1692:25,0,0,0 windows-never
        launch
        open 103 Preview pid 1007 at 953 480 723 624 min 723 400 max 723 2000
        key down toggle-float
        open 105 Notes pid 1001 at 3622 617 981 624 min 709 300
        via menu toggle-pin
        via menu move-to-display next
        """),
    ChaosKnownFailure(
      rule: "moved-twice", owner: "rule 3: one thing that happens is one layout", severity: 2,
      story: "Two layouts for one thing that happened, sizes apart. A window comes back out of the Dock: its neighbour goes into the slot that is left and is a tile a moment "
        + "later. A change of displays lays out more than once.",
      script: """
        displays main:0,0,1280,800:25,0,48,0* windows-never
        open 101 Finder pid 1005 at 148 53 975 358 min 501 300
        open 102 Music pid 1006 at 159 70 862 558 min 680 480
        launch
        key down arrange
        minimize 101
        restore 101
        """,
      """
        launch
        displays main:0,0,1080,1920:37,0,0,0* windows-silent
        open 110 Terminal pid 1003 at 776 219 1155 642 min 1155 583
        dock bottom
        open 116 Preview pid 1007 at 309 1176 626 610 title Inbox
        via menu dock bottom
        displays main:0,0,1512,982:25,0,58,0* windows-silent
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "A docked window goes to another display and turns out unable to grow there: corner, then middle. It is not asked where it stands, because macOS lets a "
        + "window be only as large as the display it is on allows. Once per window.",
      script: """
        displays main:0,0,1280,800:25,0,0,0* side:-3008,0,3008,1692:25,0,0,0 windows-never
        launch
        open 103 Preview pid 1007 at 48 115 723 663 min 723 400 max 723 2000
        key down toggle-float
        via menu move-to-display next
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-floating", owner: "rule 3: a floating window's frame is its person's", severity: 2,
      story: "A floating window is squeezed onto what is left of the Desktop, its app will not make it that small, and it is placed again. Every second ordinary walk meets it.",
      script: """
        launch
        open 102 Mail pid 1002 at 1406 650 1155 511 min 760 400
        open 103 Notes pid 1001 at 784 678 792 708 min 709 300
        key down dock left
        """,
      """
        launch
        open 101 Xcode pid 1004 at 66 293 1041 395 min 1041 378 title Inbox
        shrink 353
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-again", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "A window that cannot grow comes from the corner to the left of a display, where it cannot be asked for a size: corner of its slot, then middle. Also: a window "
        + "comes back out of the Dock, and its neighbour goes into the slot that is left and is a tile a moment later.",
      script: """
        displays main:-1512,-150,1512,982:37,0,0,0 side:0,0,1920,1080:25,70,0,0* windows-never
        launch
        open 107 Preview pid 1007 at -1371 -97 723 767 min 723 400 max 723 2000
        key down toggle-float
        seam main 0 48
        tile main 1
        """,
      """
        open 102 Preview pid 1007 at 606 305 723 585 min 723 400 max 723 2000
        open 103 Mail pid 1002 at 185 136 1100 798 min 760 400
        launch
        key down arrange
        key down rotate
        minimize 103
        restore 103
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-again-floating", owner: "rule 3: a floating window's frame is its person's", severity: 2,
      story: "The same as `moved-twice-sizing-floating`, though its app has refused in the same way before.",
      script: """
        open 101 Finder pid 1005 at 302 264 837 449 min 501 300
        launch
        focus 101
        key down dock right
        open 102 Xcode pid 1004 at 207 25 1188 827 min 1188 685
        open 103 Mail pid 1002 at 289 102 1078 539 min 760 400
        seam main 0 -199
        key down dock top
        """,
      """
        open 101 Music pid 1006 at 82 260 823 486 min 680 480
        open 103 Terminal pid 1003 at 656 52 851 544 min 177 60
        launch
        focus 103
        key down dock bottom
        key down desktop
        key down shrink
        """),
    ChaosKnownFailure(
      rule: "moved-again-floating", owner: "rule 3: a floating window's frame is its person's", severity: 3,
      story: "As `moved-twice-floating`, in a layout that a timer runs.",
      script: """
        open 109 Mail pid 1002 at 803 461 76 133
        renumber 109 110
        open 111 Preview pid 1007 at -83 282 1165 625 min 1165 625
        renumber 110 112
        launch
        displays third:0,0,800,600:25,0,0,0* windows-silent
        displays main:0,0,2560,1440:25,0,0,88* side:-1440,268,1440,900:0,0,42,0 third:-4000,282,2560,1440:0,0,0,41 windows-late
        space 111 off
        open 116 Music pid 1006 at -2827 594 634 283 grid
        displays main:0,0,800,600:25,0,0,0* windows-first
        arrange all
        dock 111 bottom
        focus 111
        undo
        dock 116 beside 112 right
        zoom-node 0
        space 111 on
        settle
        """),
    ChaosKnownFailure(
      rule: "moved-again-sizing", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "As `moved-twice-sizing`, in a layout that a timer runs: a window docked while its macOS Space was away comes back on other displays.",
      script: """
        launch
        displays side:0,0,1080,1920:37,57,0,0* main:-185,1920,1280,800:0,0,0,0 third:-1625,115,1440,900:0,0,0,0 windows-silent
        open 109 Safari pid 1000 at 265 1470 766 255 max 347 222
        space 109 off
        dock top
        displays main:0,0,1920,1080:37,0,0,0* windows-silent
        displays main:0,0,1080,1920:37,0,0,0* side:-8,1920,1280,800:37,0,0,0 windows-first
        space 109 on
        flush
        """),
    ChaosKnownFailure(
      rule: "moved-again-sizing-again", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "As `moved-twice-sizing-again`, in a layout that a timer runs: a window whose macOS Space was away comes back on other displays.",
      script: """
        displays main:0,0,2560,1440:25,0,0,0* side:-33,1440,800,600:0,0,0,0 windows-first
        launch
        open 106 Preview pid 1007 at 831 921 536 717 min 536 717
        toggle-float 106
        space 106 off
        displays side:44,1920,1280,800:25,0,0,0 main:0,0,1080,1920:25,0,0,0* windows-never
        space 106 on
        hide 1003
        advance 0.5
        """),
    ChaosKnownFailure(
      rule: "moved-again-sizing-floating", owner: "rule 3: a floating window's frame is its person's", severity: 3,
      story: "As `moved-twice-sizing-floating`, in a layout that a timer runs.",
      script: """
        launch
        hang 1000
        open 108 Safari pid 1000 at -254 915 758 429
        displays side:0,0,1440,900:25,0,0,0* windows-never
        wake 1000
        limits 108 min 1579 1480
        settle
        """),
    ChaosKnownFailure(
      rule: "moved-again-sizing-again-floating", owner: "rule 3: a floating window's frame is its person's", severity: 3,
      story: "The same, though its app has refused in the same way before.",
      script: """
        launch
        open 109 Mail pid 1002 at 864 572 1103 322 min 1103 322 title Übersicht
        arrange
        space 109 off
        displays third:0,0,2560,1440:25,63,0,0* windows-late
        open 112 Mail pid 1002 at 536 1243 2062 1095 min 2062 1095 max 2062 1847
        dock 112 top
        space 109 on
        flush
        """),
    ChaosKnownFailure(
      rule: "moved-unasked", owner: "rule 2: a floating window's frame is its person's", severity: 2,
      story: "A window opens over docked ones and stays there. The next thing that happens, which has nothing to do with it (a click on another title bar, another "
        + "window closing), shoves it onto the Desktop and shrinks it.",
      script: """
        launch
        open 102 Mail pid 1002 at 994 188 1320 686 min 760 400
        key down dock top
        open 104 Music pid 1006 at 1329 186 696 528 min 680 480
        grab 102
        release
        """,
      """
        open 101 Mail pid 1002 at 50 292 803 497 min 760 400
        launch
        open 103 Finder pid 1005 at 44 151 929 510 min 501 300
        key down dock right
        open 105 Terminal pid 1003 at 826 338 798 514 min 177 60
        close 101
        """),
    ChaosKnownFailure(
      rule: "moved-before-any-dock", owner: "rule 2: a floating window's frame is its person's", severity: 2,
      story: "Nothing is docked, and Arbor moves a window that hangs over an edge of the screen wholly into view: when another window closes, when it comes back out "
        + "of the Dock, at a key that moves the view.",
      script: """
        open 101 Finder pid 1005 at 112 32 1058 458 min 501 300
        grab 101
        carry 1303 40
        release
        launch
        open 104 Safari pid 1000 at 20 113 1068 656 min 574 240
        close 104
        """,
      """
        launch
        open 108 Mail pid 1002 at 649 39 803 805 min 760 400
        key down desktop
        """,
      """
        open 102 Preview pid 1007 at 184 55 723 455 min 723 400 max 723 2000
        grab 102
        carry 870 656
        release
        minimize 102
        launch
        restore 102
        """),
    ChaosKnownFailure(
      rule: "fetched-before-any-dock", owner: "rule 2: nothing moves at a start", severity: 4,
      story: "At a start, and when a window opens, one of which less than half shows is brought to the middle of the display: the rescue for what a crash left out "
        + "of view. Arbor cannot tell it from a window its person pushed aside.",
      script: """
        open 101 Mail pid 1002 at 956 751 877 388
        launch
        """),
    ChaosKnownFailure(
      rule: "size-not-given-back", owner: "rule 5: the displays come and go; Undo; carried to a smaller display by hand", severity: 3,
      story: "The display a window is on goes and comes back, and the window keeps what the other had room for. Also: Undo takes back a resize that a hand made, and "
        + "Float All leaves the older size. Also: taller than the smaller display, carried there by hand, docked and floated again, a window is fitted with nothing noted, and "
        + "sent back it stays small (what `move-to-display`, `swap` or a dock takes there has its own size back).",
      script: """
        displays main:-1440,0,1440,900:25,0,0,0 side:0,0,1920,1080:25,0,59,0* windows-never
        open 101 Xcode pid 1004 at 392 95 1188 920 min 1188 685
        displays main:0,0,1440,900:25,0,59,0* windows-silent
        displays side:0,0,1920,1080:25,0,59,0* windows-first
        way-back float-all
        """,
      """
        launch
        open 101 Mail pid 1002 at 368 293 957 595 min 760 400
        key down arrange
        key down float-all
        edge 101 368 293 1274 595
        key down undo
        key down undo
        way-back float-all
        """,
      """
        displays main:0,0,1280,800:25,0,0,0* side:150,-1080,1920,1080:25,0,0,0 windows-never
        launch
        open 107 Xcode pid 1004 at 414 -899 1188 896 min 1188 685
        grab 107
        carry 979 413
        settle
        key down toggle-float
        key down float-all
        via menu move-to-display next
        way-back float-all
        """),
    ChaosKnownFailure(
      rule: "home-not-whole", owner: "the ways home", severity: 3,
      story: "After a way home a window Arbor placed hangs over an edge further than anybody left it: old numbers given back on a smaller display; its own, larger "
        + "size given back at the corner a hand gave.",
      script: """
        displays main:0,0,1512,982:37,0,0,0* side:-2560,323,2560,1440:25,0,0,0 windows-never
        open 101 Finder pid 1005 at 45 657 708 305 min 501 300
        open 104 Finder pid 1005 at -1592 412 810 523 min 501 300
        launch
        key down arrange
        displays side:0,0,2560,1440:25,0,0,0* windows-first
        displays main:0,0,1512,982:37,0,0,0* windows-late
        way-back float-all
        """),
    ChaosKnownFailure(
      rule: "home-behind-the-dock", owner: "the ways home", severity: 4,
      story: "The Dock has come to this display since the window was last its person's: Float All gives the old frame back, part of it behind the Dock.",
      script: """
        displays main:0,0,1280,800:25,0,86,0* side:0,-1440,2560,1440:25,0,0,0 windows-never
        launch
        open 102 Mail pid 1002 at 136 -767 1122 693 min 760 400
        key down dock bottom
        displays main:0,0,1280,800:25,0,86,0* windows-silent
        displays side:0,0,2560,1440:25,0,86,0* windows-first
        way-back float-all
        """),
    ChaosKnownFailure(
      rule: "there-and-back-moved", owner: "rule 2: there and back is nothing", severity: 2,
      story: "Into the Dock and out again, or a look at one window and Back: a window is not where it was. One that hung over an edge is pulled in; one that lay "
        + "over docked windows is shoved; a view framed on the window that went does not come back.",
      script: """
        launch
        open 102 Terminal pid 1003 at 771 559 824 374 min 177 60
        advance 0.3
        minimize 102
        restore 102
        react
        advance 1
        """,
      """
        launch
        open 103 Notes pid 1001 at 784 678 792 708 min 709 300
        key down dock left
        open 104 Music pid 1006 at 246 836 745 558 min 680 480
        advance 5
        react
        key down zoom
        key down back
        react
        """,
      """
        open 101 Safari pid 1000 at 349 116 864 744 min 574 240
        launch
        open 102 Safari pid 1000 at 165 78 1116 824 min 574 240
        key down dock left
        key down zoom
        advance 5
        react
        minimize 102
        restore 102
        react
        advance 0.5
        """),
    ChaosKnownFailure(
      rule: "app-switch-out-of-view", owner: "rule 4: the window you switch to", severity: 3,
      story: "Another app comes forward and nobody says which of its windows has the keyboard (`keyboardFocusMoved` alone). The controller does not ask, and the "
        + "window stays out of view with the keyboard in it. The Accessibility layer is meant to say; where it misses, this is what a person sees.",
      script: """
        launch
        open 104 Music pid 1006 at 786 116 513 637
        open 105 Terminal pid 1003 at 842 40 354 368
        focus 104
        dock top
        zoom
        switch-app 105
        settle
        """),
    ChaosKnownFailure(
      rule: "launch-keyboard-in-a-tile", owner: "rule 2, a follow-up (decided, Q16): that window is let be where it stands, docked, its place kept, until the next layout somebody causes",
      severity: 3,
      story: "Arbor is started with the keyboard in a docked window that is a tile when everything shows, whatever room F61 finds for it. A "
        + "launch shows everything, and no key may go to a window out of view: so the view goes to that window, and every other one leaves it.",
      script: """
        open 101 Xcode pid 1004 at 393 391 518 528 min 518 528 max 628 539 title Untitled
        launch
        settings {"minimumUsableWidth":800,"minimumUsableHeight":0}
        open 106 Music pid 1006 at 636 440 1687 1775 max 561 347
        url arbor://toggle-float/106
        flush
        crash
        launch
        """,
      """
        launch
        open 101 Mail pid 1002 at 309 186 555 421 min 555 421 max 696 1933 title Übersicht
        open 103 Safari pid 1000 at -154 293 714 663 min 714 663 no-bundle
        tab-open 109 in 103
        via shortcut dock 109 bottom
        quit
        settings {"gap":1000000000}
        launch
        """),
    ChaosKnownFailure(
      rule: "flashed-into-view", owner: "rule 3: one thing that happens is one layout", severity: 2,
      story: "A window out of view shows and goes again for one thing that happened. A window closes, the display is laid out, the keyboard goes elsewhere and the view "
        + "follows. Also: a window kept to the LEFT of a display cannot be asked for a size there (what shows of it depends on its width), so it is offered its slot in view, and refuses.",
      script: """
        open 102 Finder pid 1005 at 1629 667 782 488 min 501 300
        launch
        open 103 Mail pid 1002 at 375 103 869 693 min 760 400
        key down dock top
        open 104 Mail pid 1002 at 200 28 1177 819 min 760 400
        key down zoom
        close 104
        """,
      """
        displays main:0,0,1280,800:25,0,0,0* side:1280,0,2560,1440:25,0,0,0 windows-never
        launch
        open 103 Xcode pid 1004 at 1287 404 1547 685 min 1188 685
        grab 103
        carry 1265 789
        release
        key down dock left
        """),
    ChaosKnownFailure(
      rule: "flashed-out-of-view", owner: "rule 3: one thing that happens is one layout", severity: 2,
      story: "One command sends a window out of view and fetches it again. `shrink` takes a docked window below what its app allows: it becomes a tile, the gaps are put back, "
        + "and the command tries again with what it has learnt. A docked window becomes a tile, and a moment later the view follows the keyboard onto it. A summoned window at the end of a pause.",
      script: """
        launch
        open 102 Xcode pid 1004 at 76 25 1248 875 min 1188 685
        open 103 Mail pid 1002 at 138 215 1166 511 min 760 400
        key down arrange
        key down dock top
        key down shrink
        """,
      """
        open 102 Music pid 1006 at 858 56 882 708 min 680 480
        open 103 Xcode pid 1004 at 288 218 1188 856 min 1188 685
        launch
        focus 102
        key down dock top
        key down focus down
        key down dock right
        react
        """,
      """
        open 103 Xcode pid 1004 at 120 658 1430 685 min 1188 685
        launch
        via shortcut summon Xcode
        toggle-pause
        toggle-pause
        """),
    ChaosKnownFailure(
      rule: "placed-mostly-out", owner: "displays: what macOS rescued is not sent back", severity: 1,
      story: "One display above another. A window is dragged so that its title bar is on the upper one and its body on the lower one, which then goes. macOS brings "
        + "the window wholly into view, and Arbor pushes it back down: a strip of 32 points shows. Nothing need be docked. ⌃⌥0, Show Everything, Float All, "
        + "turning to it and starting again do not fetch it; quit and pause do.",
      script: """
        displays main:0,0,2560,1440:25,0,0,0* side:524,1440,1512,982:0,0,0,0 windows-never
        launch
        open 101 Notes pid 1001 at 300 200 800 600 min 709 300
        settle
        grab 101
        carry 1200 1425
        release
        settle
        displays main:0,0,2560,1440:25,0,0,0* windows-late
        settle
        """,
      """
        displays main:0,0,2560,1440:25,0,0,0* side:524,1440,1512,982:0,0,0,0 windows-never
        launch
        open 101 Notes pid 1001 at 300 200 800 600 min 709 300
        settle
        grab 101
        carry 1200 1425
        release
        settle
        displays main:0,0,2560,1440:25,0,0,0* windows-silent
        settle
        """),
    ChaosKnownFailure(
      rule: "displays-left-mostly-out", owner: "displays: afterwards nothing is lost", severity: 2,
      story: "The same story seen at rest; and: a display changes side and shrinks in one step and the windows' own reports come first: 7 % of a floating window "
        + "shows, Arbor makes no move, and ⌃⌥0, Show Everything and Float All do not fetch it.",
      script: """
        displays main:0,0,1440,900:25,0,0,0* side:-2560,400,2560,1440:25,0,0,0 windows-late
        launch
        open 107 Finder pid 1005 at 100 100 500 400
        open 110 Music pid 1006 at -1332 709 700 400
        settle
        displays main:0,0,1440,900:25,0,0,0* side:1440,300,1280,720:25,0,0,0 windows-first
        settle
        """),
    ChaosKnownFailure(
      rule: "dragged-gap-did-not-last", owner: "the arrangement is its person's: a gap dragged by hand", severity: 2,
      story: "A docked window stands at its app's smallest size, on room lent to it. Its person drags the gap to make it larger. ⌃⌥0 at home, Show Everything, a "
        + "look elsewhere and back, any window opening and closing take the drag back.",
      script: """
        displays side:0,0,2560,1440:25,0,86,0* windows-never
        launch
        open 101 Mail pid 1002 at 932 442 913 595 min 760 400
        focus 101
        key down dock top
        key up dock top
        settle
        open 103 Music pid 1006 at 69 256 1117 564 min 680 480
        focus 103
        settle
        grab 103
        advance 0.5
        release
        settle
        key down dock bottom
        key up dock bottom
        settle
        seam side 0 -145
        settle
        key down home
        key up home
        settle
        """),
    ChaosKnownFailure(
      rule: "pause-and-resume-moved", owner: "rule 3: a resume is one move each, to the view there was", severity: 3,
      story: "The keyboard is in a window that is out of view. A pause and a resume with nothing between end with the view on that window: the resume lays the old "
        + "view out and then follows the keyboard, so every window moves twice as well.",
      script: """
        launch
        open 104 Safari pid 1000 at 10 25 1248 727 min 574 240
        key down dock bottom
        key down desktop
        advance 5
        react
        toggle-pause
        toggle-pause
        react
        advance 1
        """),
    ChaosKnownFailure(
      rule: "moved-at-launch", owner: "rule 2: nothing moves at a start", severity: 2,
      story: "Quit at the desk, started on the lap: the displays change while Arbor is away, its person puts a floating window where they want it, and the start "
        + "sends it to where it lay on this display the last time Arbor saw it.",
      script: """
        displays main:0,0,1512,982:37,0,0,0* windows-never
        launch
        open 101 Safari pid 1000 at 100 100 700 500 min 574 240
        open 102 Notes pid 1001 at 300 200 720 420 min 709 300
        dock 101 left
        settle
        displays side:0,0,2560,1440:25,0,0,0* windows-late
        settle
        move 102 1500 700 720 420
        settle
        quit
        displays main:0,0,1512,982:37,0,0,0* windows-first
        move 102 500 400 720 420
        launch
        settle
        """),
    ChaosKnownFailure(
      rule: "quit-left-out-of-reach", owner: "the ways home: quitting while an app hangs (K003)", severity: 1,
      story: "Arbor is quit while an app with a window out of view does not answer. The window is still past the corner when the app wakes, and Arbor is gone. "
        + "Opening Arbor again does not fetch it by itself; ⌃⌥0, Show Everything, Float All or turning to the window then do.",
      script: """
        launch
        open 101 Safari pid 1000 at 100 100 700 500
        open 102 Notes pid 2000 at 300 200 600 400
        dock 101 left
        zoom 101
        hang 2000
        quit
        wake 2000
        """),
  ]

  public nonisolated static let knownRules = Set(knownFailures.map(\.rule))
}
