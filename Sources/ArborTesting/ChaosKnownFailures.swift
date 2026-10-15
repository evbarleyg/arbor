import Foundation

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
      rule: "parked-beside-another-display-making-way", owner: "the controller",
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "Only with `floatingWindowsMakeWay` on, which ships off (F64). A window out of view beside one display is docked on another display, out of view there too. It stays where it was, where "
        + "part of it shows, though the other display has a better place.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        settings {"desktopColumn":true,"floatingWindowsMakeWay":true}
        launch
        mac-tiling off
        open 107 Xcode pid 1004 at 1201 365 2201 2311 min 2201 2311
        displays main:0,0,1920,1080:37,0,0,76* side:1920,-70,2560,1440:0,0,0,0 third:-60,1370,1512,982:0,0,0,88 windows-late
        dock 107 left
        carry 4328 1189
        layout Preview | Notes | Xcode
        """,
      """
        settings {"desktopColumn":true,"floatingWindowsMakeWay":true}
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
      rule: "left-its-place-making-way", owner: "the controller",
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "Only with `floatingWindowsMakeWay` on, which ships off (F64). With something docked, a display that comes or goes beside this one makes Arbor lay this one out again: a floating window that lay over a docked neighbour is moved "
        + "onto the Desktop's part, though nothing about its own display has changed.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        settings {"floatingWindowsMakeWay":true}
        launch
        open 102 Finder pid 1005 at -435 193 1915 2399 min 1915 2399
        dock left
        open 103 Xcode pid 1004 at -342 1241 673 673 max 786 1362
        displays main:0,0,1440,900:25,0,0,0* side:1440,33,1512,982:0,0,0,0 windows-late
        """,
      """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 108 Preview pid 1007 at 506 112 231 228 min 231 228 max 485 1084
        DOCK LEFT
        displays third:2720,158,1280,800:25,0,0,0 side:1440,-211,1280,800:0,0,0,0 main:0,0,1440,900:0,0,0,0* windows-late
        open 110 Terminal pid 1003 at 609 154 1688 1705 min 265 285
        displays main:0,0,1440,900:0,0,0,0* windows-late
        """),
    ChaosKnownFailure(
      rule: "sized-there-and-back", owner: "board 1.32: Arbor knows how small apps go", severity: 2,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "Two windows Arbor has never seen at their smallest cannot both fit. The newcomer refuses its slot, room is to be made from the other, "
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
        settings {"windowsThatDoNotFit":"tile"}
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
        via shortcut arrange
        """),
    ChaosKnownFailure(
      rule: "sized-there-and-back-let-be", owner: "board 1.32: Arbor knows how small apps go, and believes it of the window that is let be", severity: 3,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "Quit Arbor, click an app in the Dock, open Arbor. The window with the keyboard turns out to have no room, so it is let be where it stands "
        + "(Q16). Let be means that no frame is set, and after a pause none is, because what was learned is still known. A new process knows nobody's "
        + "smallest size: the window is asked where it stands, like anybody, becomes narrower, and gets its width back. It ends when a launch knows what the "
        + "last run knew; for this window the paper is then believed, unasked, as it is for a lender.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        launch
        open 101 Mail pid 1002 at 100 100 900 700 min 820 400
        focus 101
        dock 101 left
        open 102 Chat pid 1008 at 300 100 900 700 min 760 500
        focus 102
        dock 102 right
        quit
        focus 101
        launch
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        launch
        open 101 Xcode pid 1004 at 40 100 1350 700 min 1300 500
        focus 101
        dock 101 left
        open 102 Safari pid 1000 at 300 100 600 500
        dock 102 right
        quit
        focus 101
        launch
        """),
    ChaosKnownFailure(
      rule: "set-right-by-less-than-a-cell", owner: "board 1.62: Arbor knows a terminal's character cell", severity: 4,
      story: "A terminal takes whole character cells. Nobody in view is asked to grow where it stands, so how many cells go into a slot shows in the slot, and the "
        + "terminal is moved to the middle of it afterwards: less than half a cell, within the slot, at every size it has not been seen at. It ends when Arbor "
        + "knows the cell, and foretells the place for any slot.",
      script: """
        launch
        open 101 Terminal pid 1001 at 100 100 500 400
        behave 101 grid
        open 102 Mail pid 1002 at 800 300 500 400
        dock 102 left
        dock 101 beside 102 bottom
        float 102
        """),
    ChaosKnownFailure(
      rule: "sized-there-and-back-floating-making-way", owner: "rule 3: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). A floating window is squeezed onto the Desktop and given some of it back by the same command.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        settings {"arrangeDesktopWeight":1}
        launch
        open 106 Preview pid 1007 at -439 605 752 321 title Draft
        arrange
        open 109 Xcode pid 1004 at 874 45 848 418 title ~
        layout Xcode | Notes
        """,
      """
        settings {"floatingWindowsMakeWay":true}
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
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "Two layouts for one thing that happened, sizes apart. A window comes back out of the Dock: its neighbour goes into the slot that is left and is a tile a moment "
        + "later. A change of displays lays out more than once.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        displays main:0,0,1280,800:25,0,48,0* windows-never
        open 101 Finder pid 1005 at 148 53 975 358 min 501 300
        open 102 Music pid 1006 at 159 70 862 558 min 680 480
        launch
        via shortcut arrange
        minimize 101
        restore 101
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        launch
        displays main:0,0,1080,1920:37,0,0,0* windows-silent
        open 110 Terminal pid 1003 at 776 219 1155 642 min 1155 583
        dock bottom
        open 116 Preview pid 1007 at 309 1176 626 610 title Inbox
        via menu dock bottom
        displays main:0,0,1512,982:25,0,58,0* windows-silent
        """),
    ChaosKnownFailure(
      rule: "moved-twice-floating-windows-first-making-way", owner: "rule 3: a floating window's frame is its person's (board 0.22)", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). With `soleFloatTakesDesktop` on (it ships off), a display is unplugged, the one that stays loses its menu bar in the same breath, and "
        + "macOS says where it has moved the window before it says any of that. Arbor takes the move for a person's (`knowsTheDisplays` still "
        + "holds), lays out by the displays it believes in (`floatingWindowMoved`), and again when it hears: the window twitches by the "
        + "height of a menu bar that is no longer there.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        set soleFloatTakesDesktop true
        displays main:0,0,2560,1440:25,0,86,0* side:2560,-170,1280,800:0,0,0,0 windows-never
        open 101 Terminal pid 1003 at 2183 1137 147 131 title Inbox
        move 101 2572 -158 1257 781
        displays main:0,0,1440,900:0,0,92,0* windows-first
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "A window its person has left lower than macOS lets anybody put one cannot be asked where it stands, for it would not stay there. That it will not be "
        + "as narrow as its slot shows in the slot, and it is a tile a moment later. Once per window.",
      script: """
        settings {"desktopColumn":true}
        displays main:0,0,1512,982:37,0,0,70* side:0,-1440,2560,1440:25,0,0,0 windows-never
        open 101 Mail pid 1002 at 130 202 1298 700 min 760 400
        open 104 Safari pid 1000 at 17 209 1380 664 min 574 240
        launch
        grab 101
        carry 390 967
        release
        via shortcut arrange
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-floating-making-way", owner: "rule 3: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). A floating window is squeezed onto what is left of the Desktop, its app will not make it that small, and it is placed again. Every second ordinary walk meets it.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 102 Mail pid 1002 at 1406 650 1155 511 min 760 400
        open 103 Notes pid 1001 at 784 678 792 708 min 709 300
        key down dock left
        """,
      """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 101 Xcode pid 1004 at 66 293 1041 395 min 1041 378 title Inbox
        shrink 353
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-again", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "A window that cannot grow comes from the corner to the left of a display, where it cannot be asked for a size: corner of its slot, then middle. Also: a window "
        + "comes back out of the Dock, and its neighbour goes into the slot that is left and is a tile a moment later. Also: a window of one width first meets a slot "
        + "a few points wider, which is what a terminal's rounding looks like, so nobody calls that a limit; in view nobody is asked to grow where it stands, so "
        + "that it is one shows in the next, wider slot: corner, then middle, once.",
      script: """
        displays main:0,0,1512,982:37,0,0,0* windows-never
        launch
        open 104 Preview pid 1007 at 619 182 723 767 min 723 400 max 723 2000
        key down dock right
        key down dock top
        """,
      """
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
        via shortcut arrange
        key down rotate
        minimize 103
        restore 103
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-again-floating-making-way", owner: "rule 3: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). The same as `moved-twice-sizing-floating`, though its app has refused in the same way before.",
      script: """
        settings {"floatingWindowsMakeWay":true}
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
        settings {"floatingWindowsMakeWay":true}
        open 101 Music pid 1006 at 82 260 823 486 min 680 480
        open 103 Terminal pid 1003 at 656 52 851 544 min 177 60
        launch
        focus 103
        key down dock bottom
        key down desktop
        key down shrink
        """),
    ChaosKnownFailure(
      rule: "moved-again", owner: "rule 3: one thing that happens is one layout", severity: 4,
      story: "A window only just back out of the Dock is docked and will not be as narrow as its slot. Asked where it stands it keeps its size, which is also what one "
        + "that is not ready yet does, so nothing is concluded, and room is made for it when the moment is over: nine points, a second later.",
      script: """
        displays main:0,0,1512,982:37,0,0,48* side:1512,-200,3008,1692:25,0,0,0 windows-never
        open 101 Preview pid 1007 at 1697 691 723 501 min 723 400 max 723 2000
        launch
        restore 101
        grab 101
        carry 67 449
        release
        key down dock bottom
        key down undo
        minimize 101
        restore 101
        key down toggle-float
        advance 1
        """),
    ChaosKnownFailure(
      rule: "moved-again-floating-making-way", owner: "rule 3: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). As `moved-twice-floating`, in a layout that a timer runs.",
      script: """
        settings {"floatingWindowsMakeWay":true}
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
      rule: "moved-again-sizing-floating-making-way", owner: "rule 3: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). As `moved-twice-sizing-floating`, in a layout that a timer runs.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        hang 1000
        open 108 Safari pid 1000 at -254 915 758 429
        displays side:0,0,1440,900:25,0,0,0* windows-never
        wake 1000
        limits 108 min 1579 1480
        settle
        """),
    ChaosKnownFailure(
      rule: "moved-unasked-making-way", owner: "rule 2: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). A window opens over docked ones and stays there. The next thing that happens, which has nothing to do with it (a click on another title bar, another "
        + "window closing), shoves it onto the Desktop and shrinks it.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 102 Mail pid 1002 at 994 188 1320 686 min 760 400
        key down dock top
        open 104 Music pid 1006 at 1329 186 696 528 min 680 480
        grab 102
        release
        """,
      """
        settings {"floatingWindowsMakeWay":true}
        open 101 Mail pid 1002 at 50 292 803 497 min 760 400
        launch
        open 103 Finder pid 1005 at 44 151 929 510 min 501 300
        key down dock right
        open 105 Terminal pid 1003 at 826 338 798 514 min 177 60
        close 101
        """),
    ChaosKnownFailure(
      rule: "moved-before-any-dock-making-way", owner: "rule 2: a floating window's frame is its person's", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). Nothing is docked, and Arbor moves a window that its app opened hanging over an edge of the screen, more than half of it showing, wholly into view at "
        + "the next layout: at a key that moves the view, when another window closes. (One that was found hanging, or opened with under half showing, stays.) Or "
        + "one that a hand hung over an edge while something was docked: squeezed then, it gets its size back there, or is pulled in, once nothing is docked.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 108 Mail pid 1002 at 649 39 803 805 min 760 400
        key down desktop
        """),
    ChaosKnownFailure(
      rule: "size-not-given-back", owner: "rule 5: the displays come and go; carried to a smaller display by hand", severity: 3,
      story: "The display a window is on goes and comes back, and the window keeps what the other had room for. "
        + "Also: taller than the smaller display, carried there by hand, docked and floated again, a window is fitted with nothing noted, and "
        + "sent back it stays small (what `move-to-display`, `swap` or a dock takes there has its own size back).",
      script: """
        displays main:-1440,0,1440,900:25,0,0,0 side:0,0,1920,1080:25,0,59,0* windows-never
        open 101 Xcode pid 1004 at 392 95 1188 920 min 1188 685
        displays main:0,0,1440,900:25,0,59,0* windows-silent
        displays side:0,0,1920,1080:25,0,59,0* windows-first
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
      rule: "home-behind-the-dock", owner: "the ways home", severity: 4,
      story: "The Dock has come to this display since the window was last its person's: Float All gives the old frame back, part of it behind the Dock.",
      script: """
        displays main:0,1692,1728,1117:37,0,0,0 side:0,0,3008,1692:25,0,70,0* windows-never
        launch
        open 104 Xcode pid 1004 at 20 501 1188 784 min 1188 685
        grab 104
        carry 1653 2610
        release
        via menu toggle-pin
        key down dock right
        displays main:0,0,1728,1117:37,0,70,0* windows-first
        advance 0.3
        key down float-all
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
        key down desktop
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
      rule: "flashed-into-view", owner: "rule 3: one thing that happens is one layout", severity: 2,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "A window out of view shows and goes again for one thing that happened. A window closes, the display is laid out, the keyboard goes elsewhere and the view "
        + "follows. Also: a window kept to the LEFT of a display cannot be asked for a size there (what shows of it depends on its width), so it is offered its slot in view, and refuses.",
      script: """
        open 102 Finder pid 1005 at 1629 667 782 488 min 501 300
        launch
        open 103 Mail pid 1002 at 375 103 869 693 min 760 400
        key down dock top
        open 104 Mail pid 1002 at 200 28 1177 819 min 760 400
        key down desktop
        close 104
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
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
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "One command sends a window out of view and fetches it again. `rotate` turns the group, a window will not be as small as its new slot and is a tile, "
        + "and the command takes itself back: every window has gone there and back for \"not enough room\". Also: a docked window becomes a tile, and a moment "
        + "later the view follows the keyboard onto it.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        displays side:0,0,2560,1440:25,0,0,70* windows-never
        open 101 Safari pid 1000 at 861 153 972 864 min 574 240
        open 102 Notes pid 1001 at 157 794 819 516 min 709 300
        open 103 Xcode pid 1004 at 677 463 1188 744 min 1188 685
        launch
        via shortcut arrange
        key down rotate
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        open 102 Music pid 1006 at 858 56 882 708 min 680 480
        open 103 Xcode pid 1004 at 288 218 1188 856 min 1188 685
        launch
        focus 102
        key down dock top
        key down focus down
        key down dock right
        react
        """),
    ChaosKnownFailure(
      rule: "displays-left-mostly-out-making-way", owner: "displays: afterwards nothing is lost", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). The same story seen at rest; and: a display changes side and shrinks in one step and the windows' own reports come first: 7 % of a floating window "
        + "shows, Arbor makes no move, and ⌃⌥0, Show Everything and Float All do not fetch it.",
      script: """
        settings {"floatingWindowsMakeWay":true}
        displays main:0,0,1440,900:25,0,0,0* side:-2560,400,2560,1440:25,0,0,0 windows-late
        launch
        open 107 Finder pid 1005 at 100 100 500 400
        open 110 Music pid 1006 at -1332 709 700 400
        settle
        displays main:0,0,1440,900:25,0,0,0* side:1440,300,1280,720:25,0,0,0 windows-first
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
      rule: "moved-at-launch-after-a-crash-making-way", owner: "rule 2: nothing moves at a start, after a run that did not quit", severity: 4,
      story: "Only with `floatingWindowsMakeWay` on, which ships off (F64). Arbor is killed and nothing starts it again. Its person makes a window that is kept in view smaller, and starts Arbor: the window is blown up to the "
        + "size remembered for it. Only a quit and a pause write down where they left each window; after a crash Arbor cannot tell a size its person chose from "
        + "one it had squeezed the window to itself. (After a quit or a pause the size is learnt.)",
      script: """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 106 Xcode pid 1004 at 300 150 840 440
        pin 106
        settle
        crash
        edge 106 300 150 600 440
        launch
        settle
        """,
      """
        settings {"floatingWindowsMakeWay":true}
        launch
        open 116 Preview pid 1007 at 2059 599 822 562 min 369 88
        pin 116
        flush
        crash
        move 116 326 132 635 221
        launch
        """),
    ChaosKnownFailure(
      rule: "flipped-into-view", owner: "rule 3: one thing that happens is one layout", severity: 4,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "A window that is out of view shows and goes again at a key that turns to a neighbour, among five windows of which some are tiles.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        displays main:0,0,1728,1117:37,0,0,0* side:1728,323,3008,1692:25,0,0,0 windows-never
        open 101 Notes pid 1001 at 1912 1231 837 618 min 709 320
        open 102 Mail pid 1002 at 3312 834 871 833 min 871 236
        launch
        grab 101
        displays main:0,0,1728,1117:37,0,0,0* windows-silent
        settle
        open 104 Mail pid 1002 at 381 329 913 581 min 871 236
        open 105 Finder pid 1005 at 695 49 846 436 min 501 252
        open 106 Music pid 1006 at 534 405 1078 684 min 980 600
        open 108 Xcode pid 1004 at 265 270 1188 696 min 1188 685
        focus-nothing
        via shortcut arrange
        edge 101 915 583 957 522
        key down undo
        tile main 4
        key down focus right
        """),
    ChaosKnownFailure(
      rule: "flipped-out-of-view", owner: "rule 3: one thing that happens is one layout", severity: 3,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "A window leaves the screen and comes back for one thing that happened, and no app refused a size. ⌃⌥D with one docked window that has the keyboard: it goes, and a moment later the "
        + "view follows the keyboard and it is back. Move to Next Display: by way of the corner. Grow at the limit: out and in, twice.",
      script: """
        open 103 Mail pid 1002 at 1553 134 1155 658 min 760 400
        launch
        via shortcut arrange
        key down desktop
        react
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        displays main:-1280,0,1280,800:25,0,0,0 side:0,0,1920,1080:25,86,0,0* windows-never
        open 103 Notes pid 1001 at 367 327 972 654 min 709 300
        launch
        open 104 Xcode pid 1004 at 368 312 1188 696 min 1188 685
        via shortcut arrange
        focus 104
        via menu move-to-display next
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        launch
        open 103 Xcode pid 1004 at 85 62 1188 800 min 1188 685
        key down dock right
        open 104 Preview pid 1007 at 560 287 723 514 min 723 400 max 723 2000
        seam main 0 -187
        key down dock left
        key down grow
        """),
    ChaosKnownFailure(
      rule: "displays-out-and-back-moved", owner: "displays: a window's report is never judged by displays that are no more", severity: 3,
      story: "A window on the monitor. The lid is shut and opened, and each time the window speaks before macOS's list of displays has changed: it ends on the laptop. (That one window speaks so is "
        + "common on a Mac; that all do, as here, has not been recorded.)",
      script: """
        displays main:0,0,1440,900:25,0,70,0* side:1440,0,2560,1440:25,0,0,0 windows-never
        open 103 Mail pid 1002 at 1540 85 1100 700 min 760 400
        launch
        settle
        displays side:0,0,2560,1440:25,0,70,0* windows-first
        settle
        react
        advance 1
        react
        displays main:0,0,1440,900:25,0,70,0* side:1440,0,2560,1440:25,0,0,0 windows-first
        settle
        """),
    ChaosKnownFailure(
      rule: "taken-to-another-display", owner: "displays: a display claims only what is its own", severity: 2,
      story: "As `displays-out-and-back-moved`, asked at the move itself: when displays come and go Arbor takes a floating window to a display that it only visited, while the one "
        + "somebody put it on is there.",
      script: """
        displays main:-1512,0,1512,982:37,0,0,0 side:0,0,2560,1440:25,0,59,0* windows-never
        open 102 Finder pid 1005 at -1099 342 1067 467 min 501 252
        launch
        displays main:0,0,1512,982:37,0,59,0* windows-first
        displays main:-1512,0,1512,982:37,0,0,0 side:0,0,2560,1440:25,0,59,0* windows-late
        """,
      """
        displays main:0,0,1512,982:37,70,0,0* side:1512,323,1920,1080:25,0,0,0 windows-never
        open 104 Music pid 1006 at 1802 719 980 600 min 980 600
        launch
        toggle-pause
        toggle-pause
        displays side:0,0,1920,1080:25,70,0,0* windows-first
        displays main:0,0,1512,982:37,70,0,0* side:1512,323,1920,1080:25,0,0,0 windows-silent
        """),
    ChaosKnownFailure(
      rule: "taken-back-from-where-it-was-put", owner: "displays: a display claims only what is its own", severity: 3,
      story: "A display goes and its window lands on the one that stays. Its person docks it there and floats it again, with Arbor's own keys. The display returns, and Arbor takes the window back "
        + "to its old frame on it. (What a hand drags or sizes there stays, since a display that comes back fetches no guests.)",
      script: """
        launch
        displays side:0,0,3008,1692:25,0,0,0* windows-first
        open 105 Notes pid 1001 at 1682 530 972 558 min 709 320
        displays main:0,0,1728,1117:37,0,0,0* windows-silent
        key down dock top
        key down toggle-float
        displays main:0,0,1728,1117:37,0,0,0* side:1728,323,3008,1692:25,0,0,0 windows-late
        """,
      """
        displays main:0,0,1728,1117:37,0,70,0* side:-200,-1440,2560,1440:25,0,0,0 windows-never
        open 101 Terminal pid 1003 at 1351 -1337 921 514 min 177 64 cells 7 15 2 4
        launch
        displays main:0,0,1728,1117:37,0,70,0* windows-silent
        focus 101
        key down toggle-float
        key down float-all
        displays main:0,0,1728,1117:37,0,70,0* side:-200,-1440,2560,1440:25,0,0,0 windows-silent
        """),
    ChaosKnownFailure(
      rule: "taken-out-of-view-with-another-display", owner: "displays: a display claims only what is its own", severity: 2,
      story: "A browser window on the monitor, another arranged and framed on the laptop. The lid is shut and opened: the monitor's window is out of view, with the laptop's framed view, "
        + "and the monitor is empty.",
      script: """
        displays main:0,0,1512,982:37,0,48,0* side:-1920,-200,1920,1080:25,0,0,0 windows-never
        open 104 Safari pid 1000 at -1318 -171 1152 816 min 574 240
        open 103 Safari pid 1000 at 89 107 1416 784 min 574 240
        launch
        via shortcut arrange
        key down zoom
        displays side:0,0,1920,1080:25,0,48,0* windows-first
        displays main:0,0,1512,982:37,0,48,0* side:-1920,-200,1920,1080:25,0,0,0 windows-silent
        """),
    ChaosKnownFailure(
      rule: "taken-back-out-of-view-from-where-it-was-put", owner: "displays: a display claims only what is its own", severity: 2,
      story: "The monitor's view is framed on a browser, and the player that floated there is out of view. The monitor is unplugged, the player comes to the laptop, and its person drags it to "
        + "where they want it. The monitor comes back: the player goes from the laptop out of view.",
      script: """
        displays main:0,0,1512,982:37,0,59,0* side:323,-1440,2560,1440:25,0,0,0 windows-never
        launch
        open 101 Safari pid 1000 at 1394 -1241 1440 880 min 574 240
        key down dock bottom
        open 102 Music pid 1006 at 1297 -738 1137 702 min 680 480
        cursor 3110 4
        key down in
        displays main:0,0,1512,982:37,0,59,0* windows-silent
        grab 102
        carry 285 256
        release
        displays main:0,0,1512,982:37,0,59,0* side:323,-1440,2560,1440:25,0,0,0 windows-silent
        """,
      """
        displays main:-1280,-323,1280,800:25,0,0,0 side:0,0,1920,1080:25,0,0,59* windows-never
        open 103 Terminal pid 1003 at 228 315 693 539 min 177 60
        launch
        focus 103
        key down dock left
        open 105 Preview pid 1007 at 412 67 723 644 min 723 400 max 723 2000
        key down desktop
        displays main:0,0,1280,800:25,0,0,59* windows-late
        key down dock top
        focus 103
        key down float-all
        displays main:-1280,-323,1280,800:25,0,0,0 side:0,0,1920,1080:25,0,0,59* windows-silent
        """),
    ChaosKnownFailure(
      rule: "nothing-in-view-held-after-displays", owner: "a held view while displays come and go", severity: 3,
      story: "The view is held, and the display that showed the only window in view goes: the display that is left shows nothing, for as long as the view is held. Every way home fetches.",
      script: """
        displays main:-1728,0,1728,1117:37,0,0,0 side:0,0,2560,1440:25,0,0,0* windows-never
        launch
        open 105 Preview pid 1007 at 231 675 723 559 min 723 400 max 723 2000
        key down dock left
        key down zoom
        via menu hold
        displays main:0,0,1728,1117:37,0,0,0* windows-silent
        key down dock right
        displays side:0,0,2560,1440:25,0,0,0* windows-first
        settle
        """,
      """
        displays main:0,0,1440,900:25,0,48,0* side:-3008,150,3008,1692:25,0,0,0 windows-never
        launch
        open 103 Mail pid 1002 at -2199 517 1133 546 min 760 400
        grab 103
        carry 720 852
        release
        key down zoom
        key down desktop
        key down back
        via menu hold
        grab 103
        carry -3008 1842
        release
        displays main:0,0,1440,900:25,0,48,0* windows-late
        settle
        """),
    ChaosKnownFailure(
      rule: "plain-drag-showed-a-preview", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 2,
      story: "A floating window is dragged to the foot of the display with no key held, and Arbor shows where it would dock.",
      script: """
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        grab 101
        carry 700 896
        """),
    ChaosKnownFailure(
      rule: "plain-drag-docked", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 2,
      story: "It is let go there, and is docked.",
      script: """
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        grab 101
        carry 700 896
        release
        """),
    ChaosKnownFailure(
      rule: "plain-drag-moved-it", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 2,
      story: "Let go there, it is taken from where its person left it, to a slot.",
      script: """
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        grab 101
        carry 700 896
        release
        """),
    ChaosKnownFailure(
      rule: "own-frame-back", owner: "a floating window's frame is its person's: what macOS answers to \"back where it was\" is where it was", severity: 3,
      story: "A floating window is pushed down by hand until less than its title bar shows. It goes out of view with the view and comes back a little short, because macOS puts no window there "
        + "by request. The second time it comes back 140 points to the left and 319 up, fitted in: for the place it was stopped at no hand is on record. New since floating windows "
        + "make way for nobody; it goes when they are no longer taken out of view.",
      script: """
        displays main:0,0,1440,900:25,0,48,0* windows-never
        launch
        open 104 Finder pid 1005 at 248 440 745 371 min 501 252
        open 105 Notes pid 1001 at 381 133 760 560 min 709 300
        grab 104
        carry 1208 830
        release
        focus 105
        key down dock left
        key down zoom
        key down zoom
        key down zoom
        key down zoom
        """),
    ChaosKnownFailure(
      rule: "moved-twice-floating", owner: "less by default (Q29, board 0.5): Arbor never takes a floating window out of view", severity: 4,
      story: "The corner where windows wait out of view lies beside a monitor that reaches lower than the laptop: a strip would show there. So a floating window is sent to the laptop's bottom "
        + "right and, in the same breath, to its bottom left.",
      script: """
        displays main:0,0,1512,982:37,0,70,0* side:1512,-200,1920,1080:25,0,0,0 windows-never
        open 101 Finder pid 1005 at 317 65 810 493 min 501 252
        open 102 Finder pid 1005 at 61 67 1086 453 min 501 252
        launch
        focus 101
        key down dock right
        key down zoom
        """),
    ChaosKnownFailure(
      rule: "fetched-before-any-dock", owner: "what is found counts as left, in every state: out of the Dock it comes back where macOS puts it", severity: 3,
      story: "Nothing was ever docked. A window hangs at the foot of the monitor where a hand left it, its title bar in reach. Arbor is paused, the laptop goes, Arbor is resumed. ⌘M and back out "
        + "of the Dock: Arbor pulls it 595 points up.",
      script: """
        displays main:0,0,1512,982:37,0,59,0* side:-2560,323,2560,1440:25,0,0,0 windows-never
        open 102 Settings pid 1007 at -947 979 723 774 min 723 470 max 723 2000
        launch
        grab 102
        carry -1590 1535
        release
        toggle-pause
        displays side:0,0,2560,1440:25,0,59,0* windows-first
        toggle-pause
        minimize 102
        restore 102
        """),
    ChaosKnownFailure(
      rule: "home-not-whole", owner: "who takes a waiting place; and a size is given back whole where the window hangs over an edge (board 0.22)", severity: 3,
      story: "After a restart of the Mac a window takes the place that was kept, and at Quit or a pause it is given the frame that was saved for the window of before, over the edge where that one "
        + "hung: in the first script its own under another number, which macOS had cut at the edge; in the second a sibling with another title, which never was there.",
      script: """
        open 102 Terminal pid 1003 at 415 62 947 554 min 177 64 title Terminal-102 cells 7 15 2 4
        launch
        grab 102
        carry 1135 390
        release
        via menu arrange
        quit
        close 102
        open 107 Terminal pid 1003 at 661 380 779 559 min 177 64 title Terminal-102 cells 7 15 2 4
        way-back quit
        """,
      """
        displays main:0,0,1512,982:37,0,70,0* windows-never
        launch
        open 104 Settings pid 1007 at 688 280 723 572 min 723 470 max 723 2000 title Settings-104
        grab 104
        carry 1462 129
        release
        key down dock right
        key up dock right
        quit
        close 104
        open 108 Settings pid 1007 at -245.5 93 723 722 min 723 470 max 723 2000 title Settings-106
        way-back pause
        """),
    ChaosKnownFailure(
      rule: "plain-drag-moved-another", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 2,
      story: "Notes are docked at the right. A floating window is dragged to the foot of the display with no key held and let go: it docks, and the notes, which nobody touched, are made lower.",
      script: """
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        focus 101
        key down dock right
        grab 102
        carry 700 896
        release
        """),
    ChaosKnownFailure(
      rule: "plain-drag-moved-another-making-way", owner: "F18, with floating windows making way: both are options", severity: 4,
      story: "Two windows float beside a docked one. One is dragged to the other display with no key held: the one that is left, alone on its Desktop now, is stretched over it.",
      script: """
        displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-never
        launch
        settings {"floatingWindowsMakeWay":true,"soleFloatTakesDesktop":true}
        open 101 Safari pid 1000 at 100 100 600 400
        dock 101 left
        open 105 Terminal pid 1003 at 800 300 462 440
        open 106 Notes pid 1001 at 900 200 315 286
        settle
        grab 106
        carry 1800 300
        release
        settle
        """),
    ChaosKnownFailure(
      rule: "moved-before-any-dock", owner: "rule 2: the displays change during a pause", severity: 3,
      story: "Nothing was ever docked. A window is dragged to the foot of the monitor; Arbor is paused, the laptop goes, Arbor is resumed; ⌃⌥0 pulls the window up by 377 points.",
      script: """
        displays main:0,0,1280,800:25,0,48,0* side:1280,323,1920,1080:25,0,0,0 windows-never
        open 104 Finder pid 1005 at 45 108 791 410 min 501 252
        launch
        grab 104
        carry 2774 1332
        release
        toggle-pause
        displays side:0,0,1920,1080:25,0,48,0* windows-first
        toggle-pause
        key down home
        """),
    ChaosKnownFailure(
      rule: "plain-drag-started-a-timer", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 3,
      story: "A window is dragged over another with no key held, and Arbor begins to wait for it to rest there.",
      script: """
        settings {"desktopColumn":true}
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        dock 101 left
        dock 102 right
        settle
        grab 101
        carry 1000 450
        """),
    ChaosKnownFailure(
      rule: "plain-drag-left-it-docked", owner: "less by default (Q29, board 0.4): a plain drag docks nothing", severity: 2,
      story: "A docked window is dragged away with no key held and let go over its neighbour: it goes back into the arrangement. It should float, at its own size, where it was let go.",
      script: """
        launch
        open 101 Notes pid 1001 at 300 200 800 500 min 709 300
        open 102 Safari pid 1000 at 100 100 900 600 min 574 240
        dock 101 left
        dock 102 right
        settle
        grab 101
        carry 1000 450
        advance 0.3
        release
        settle
        """),
    ChaosKnownFailure(
      rule: "plain-drag-not-its-own-size", owner: "rule 5, as `size-not-given-back`: what a hand did while Arbor was not looking is undone; Undo", severity: 3,
      story: "A window is made larger by hand while Arbor is paused. Resumed, docked and dragged out again, it has the size from before the pause.",
      script: """
        displays main:0,0,1512,982:37,0,86,0* side:1512,-200,1920,1080:25,0,0,0 windows-never
        open 101 Music pid 1006 at 285 132 1088 672 min 680 480
        launch
        focus 101
        toggle-pause
        edge 101 2344 208 1092 809
        toggle-pause
        key down toggle-float
        grab 101
        carry 397 383
        release
        react
        """,
      """
        displays main:-1280,-150,1280,800:25,0,0,0 side:0,0,1920,1080:25,86,0,0* windows-never
        launch
        open 104 Music pid 1006 at 1052 70 706 660 min 680 480
        grab 104
        carry -950 320
        release
        edge 104 -1303 310 663 660
        key down undo
        key down dock right
        grab 104
        carry -490 108
        release
        react
        """),
    ChaosKnownFailure(
      rule: "switched-to-partly-out", owner: "follows from where Arbor placed it: the pin, a slot narrower than what shows", severity: 3,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69), where a window larger than the view by less than the gap around it stays on the display. "
        + "The window switched to hangs over an edge where Arbor put it, and the switch does not fetch it: a docked window that is pinned and will not be as small as the pin wants; "
        + "an editor alone on a small laptop with the Dock at the side, 6 points over the edge.",
      script: """
        launch
        open 106 Xcode pid 1004 at 147 126 1287 685 min 1188 685
        via shortcut arrange
        via menu toggle-pin
        react
        focus 106
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        displays main:0,0,1280,800:25,86,0,0* windows-never
        open 101 Xcode pid 1004 at 86 25 1188 775 min 1188 685
        launch
        via menu arrange all
        focus 101
        react
        """),
    ChaosKnownFailure(
      rule: "same-windows-other-frames", owner: "the arrangement is its person's: what is lent depends on the path", severity: 2,
      story: "An editor, a browser and a terminal on a desk 1920 wide, ⌃⌥A. The terminal is 604 wide. Lay Out Again, any window that opens and closes, or the browser into the Dock and "
        + "out: the terminal, which nobody touched, is 444 wide, for good. What is lent to a window that will not shrink is worked out otherwise by a fresh layout.",
      script: """
        settings {"desktopColumn":true}
        displays side:0,0,1920,1080:25,0,70,0* windows-never
        launch
        open 101 Xcode pid 1004 at 150 100 1300 800 min 1188 685
        focus 101
        open 102 Safari pid 1000 at 300 150 1200 800 min 574 240
        focus 102
        open 103 Terminal pid 1003 at 600 300 877 499 min 177 60
        focus 103
        react
        via shortcut arrange
        key up arrange
        react
        settle
        relayout
        react
        settle
        """),
    ChaosKnownFailure(
      rule: "leak-sharedItsSpace", owner: "the way out of full screen", severity: 4,
      story: "Nothing a person sees: a window in full screen closes during a pause, which Arbor never hears of, and stays on a list for ever.",
      script: """
        launch
        open 109 Safari pid 1000 at -185 784 716.5 443.25
        full-screen 109 on
        toggle-pause
        close 109
        resume
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
    ChaosKnownFailure(
      rule: "moved-unasked-out-of-view", owner: "nobody yet: found while board 0.26 was built, and as old as the rule", severity: 4,
      story: "A docked window is out of view because the view is on something else. Its app moves it, so that part of it shows. Arbor leaves it there, and sends it out of view "
        + "again at the next thing that happens, which is about another window. Right in the end and late: it was owed at the move.",
      script: """
        open 101 Preview pid 1007 at 602 842 311.5 510.25 min 203 303 title Untitled
        launch
        space 101 off
        open 106 Mail pid 1002 at -57 174 3183 2286 min 3183 2286 title main.swift
        open 108 Notes pid 1001 at -586 640 674 635 min 562 418
        dock bottom
        tile main 0
        toggle-float 101
        move 108 1297 38 720 735
        via gesture dock 101 left
        """,
      """
        displays main:0,0,2560,1440:25,0,86,0* side:2560,-170,1280,800:0,0,0,0 windows-never
        open 101 Preview pid 1007 at 611 684 1066 365 min 1066 365
        open 103 Mail pid 1002 at 2111 881 2285 2296 min 2285 2296 max 2285 2296
        cursor 3434 -160
        open 104 Mail pid 1002 at 2426 476 782 631 title Inbox
        launch
        layout Preview | Preview | Terminal
        tile side 0
        move 101 1839 381 788 546
        move-to-display next 103
        """),
    ChaosKnownFailure(
      rule: "moved-unasked", owner: "nobody yet: what is left of it since F64, none of it an ordinary floating window", severity: 3,
      story: "A window kept in view that is larger than its display, left hanging by hand, is pulled to the display's corner at the next thing "
        + "that happens: no display can show half of it, which passes for mostly out of view. And a docked window that a hand has nudged "
        + "three points out of its place is put back when another window's edge is dragged.",
      script: """
        displays side:0,0,1920,1080:25,0,0,0* windows-first
        launch
        settings {"rules":[{"app":"com.example.xcode","action":"dock right"},{"app":"com.example.xcode","action":""}]}
        open 114 Notes pid 1001 at 835 455 3224 1224 min 3224 1224
        toggle-pin
        open 116 Xcode pid 1004 at 1553 241 1597 1849 min 1597 1849 frozen
        grab 114
        carry 1566 603
        release
        grab 116
        release
        """,
      """
        launch
        open 101 Terminal pid 1003 at 614 1191 988 520 min 988 520 max 988 1251
        dock right
        open 102 Notes pid 1001 at 204 1336 720 203 min 386 140
        dock top
        seam main 0 374
        focus 101
        summon Notes
        displays main:0,0,1512,982:0,0,0,0* windows-silent
        open 106 Mail pid 1002 at -465 731 879 541
        dock right
        move 106 765 9 738 958
        edge 102 12 121 738 305
        """),
    ChaosKnownFailure(
      rule: "grown-while-hanging", owner: "the walks and F64: the rule is older than Q20", severity: 4,
      story: "A floating window goes back exactly where it was (an undo of a drag, Float All), and that is where its app had opened it or where "
        + "it was before the display changed: hanging over an edge, more than half of it showing. Since Q20 that is as it should be; the rule "
        + "asks that only a hand leaves a window hanging.",
      script: """
        launch
        open 106 Music pid 1006 at 639 501 347 476
        displays main:0,0,1280,800:25,0,0,0* windows-late
        grab 106
        carry 1272 426
        release
        undo
        """,
      """
        open 106 Finder pid 1005 at -202 490 1126 617 min 1126 617 max 1126 1926
        launch
        displays main:0,0,1512,982:25,83,0,0* windows-first
        grab 106
        cursor 1498 981
        way-back float-all
        """),
    ChaosKnownFailure(
      rule: "left-its-place", owner: "nobody yet (F64, a change of displays)", severity: 3,
      story: "A display moves or its menu bar changes, macOS takes a floating window along, and Arbor puts it some points beside where macOS had "
        + "it: where it reckons the window was on its display.",
      script: """
        displays side:0,0,1512,982:25,45,0,0* main:-1920,58,1920,1080:25,0,0,0 windows-never
        launch
        open 102 Terminal pid 1003 at -1562 457 436 481 title Übersicht
        displays main:0,0,1920,1080:25,0,0,0* windows-first
        """,
      """
        open 107 Notes pid 1001 at 324 420 712 580
        edge 107 12 12 1416 876 hold
        release
        displays side:1440,60,800,600:0,90,0,0 main:0,0,1440,900:37,0,0,0* windows-first
        launch
        displays main:0,0,1440,900:37,0,0,0* windows-silent
        """),
    ChaosKnownFailure(
      rule: "parked-beside-another-display", owner: "the controller", severity: 3,
      story: "Only with `windowsThatDoNotFit` at `tile`, which ships at `overlap` (F69): the script needs a window that becomes a tile. "
        + "A window out of view beside one display is docked on another display, out of view there too. It stays where it was, where part of "
        + "it shows, though the other display has a better place.",
      script: """
        settings {"windowsThatDoNotFit":"tile"}
        settings {"desktopColumn":true}
        launch
        displays main:0,0,800,600:25,0,0,0* side:-223,600,2560,1440:0,50,0,0 windows-first
        open 113 Notes pid 1001 at 1521 1197 1678 1696 min 1678 1696
        grab 113
        carry 395 590
        release
        carry 373 1301
        layout Finder | Notes | Preview
        """,
      """
        settings {"windowsThatDoNotFit":"tile"}
        settings {"desktopColumn":true}
        launch
        displays main:0,0,1280,800:25,0,97,0* side:-53,800,1440,900:0,0,0,0 windows-late
        open 105 Preview pid 1007 at 85 41 3955 1815 min 3955 1815 max 3955 1815
        cursor -53 1700
        displays side:0,0,1440,900:37,0,0,0* main:-242,900,1920,1080:0,0,0,0 third:-168,1980,1512,982:0,0,0,0 windows-silent
        dock left
        layout Preview / Safari
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-floating", owner: "rule 3: a refused size costs no second move; grow and shrink of a floating window", severity: 3,
      story: "What is left of it as Arbor ships (F64), nearly all of it: `shrink` or `grow` of a floating window whose app refuses part of the size. It is placed for the size that was "
        + "asked, and again for the size it has.",
      script: """
        open 103 Xcode pid 1004 at 100 60 1188 775 min 1188 685
        launch
        focus 103
        do shrink 40
        """),
    ChaosKnownFailure(
      rule: "moved-twice-sizing-again-floating", owner: "rule 3: a refused size costs no second move; grow and shrink of a floating window", severity: 3,
      story: "The same as `moved-twice-sizing-floating`, though its app has refused in the same way before.",
      script: """
        launch
        open 109 Preview pid 1007 at 1222 256 3257 1451 min 3257 1451
        displays main:0,0,2560,1440:25,0,0,50* side:130,1440,1920,1080:0,0,0,0 windows-late
        shrink 46
        """),
    ChaosKnownFailure(
      rule: "sized-there-and-back-floating", owner: "rule 3: a refused size costs no second move; grow and shrink of a floating window", severity: 3,
      story: "`shrink` of a floating window whose app stops short of the size asked for: it is centred for the one and then for the other.",
      script: """
        launch
        open 104 Xcode pid 1004 at -1093 624 1956 1742 min 528 350 max 556 1899
        shrink
        """),
    ChaosKnownFailure(
      rule: "own-frame-back-after-undo", owner: "nobody yet (F64)", severity: 4,
      story: "With two displays: a floating window is carried or sent from one to the other, and an undo or a redo takes that back while the "
        + "window, or the Desktop it goes to, is out of view. It is in view afterwards, wholly, but when it next goes out of view and "
        + "comes back it is at the frame remembered on that display, not where the undo had left it. About once in a thousand walks.",
      script: """
        displays third:1327,12,1920,1080:0,0,0,0 main:-113,1920,1440,900:25,0,63,0 side:0,0,1080,1920:25,77,0,0* windows-never
        launch
        settings {"desktopColumn":true,"rules":[{"app":"com.example.music","action":"dock beside com.example.safari right"}]}
        open 104 Music pid 1006 at 579 373 480 538 min 462 126
        open 105 Mail pid 1002 at -1202 644 356 460 no-bundle
        pinch began 0
        pinch changed 0.3
        open 111 Music pid 1006 at -734 567 2096 1634 min 2096 1634 title Untitled
        move-to-display previous 105
        undo
        focus 105
        """,
      """
        settings {"desktopColumn":true}
        open 107 Xcode pid 1004 at 897 515 899 718 min 696 718
        open 110 Terminal pid 1003 at 70 476 700 240 title main.swift
        launch
        arrange
        displays main:0,0,1080,1920:37,0,0,0* side:202,1920,1512,982:0,0,58,0 windows-late
        float 110
        edge 107 301 926 696 20
        grab 110
        carry 960 2169
        settle
        zoom 107
        cursor 540 961
        undo
        key down show-all
        """),
  ]

  public nonisolated static let knownRules = Set(knownFailures.map(\.rule))

  /// Numbers, not gates: `step` keeps these apart (`counted`), no walk, replay or test ends at them, and a hunt counts them beside the known failures.
  ///
  /// **By the eye**, for good: every change of a window that a person could see counts, however good the road was (`FakeWindowSystem.detour`). A change to
  /// the product that comes with a change to the net that judges it is measured by both, on both sides.
  ///
  /// **Not yet gates**: nets for what has been decided and is not built yet, which nearly every walk and many a strict test would break today. Each is to
  /// read 0; whoever brings one there takes it out of this set, and from then on it ends walks like any other rule.
  public nonisolated static let countedRules: Set<String> = [
    "eye-moved-twice", "eye-moved-twice-sizing", "eye-moved-again", "eye-moved-again-sizing",
    "floating-taken-out-of-view", "strayed-between", "displays-moved-the-untouched", "plain-drag-left-an-undo-step",
    "parked-before-any-dock", "arrival-moved-a-neighbour", "arrival-took-a-neighbour-out-of-view",
  ]

  /// The same without those that `ARBOR_CHAOS_GATES=rule,rule` makes gates for one run: they end walks there and are shrunk, which is how to read what is behind
  /// a number, and how to see that it is 0 before taking its name out of the set.
  nonisolated static let countedInThisRun = countedRules.subtracting(
    (ProcessInfo.processInfo.environment["ARBOR_CHAOS_GATES"] ?? "").split(separator: ",").map(String.init))
}
