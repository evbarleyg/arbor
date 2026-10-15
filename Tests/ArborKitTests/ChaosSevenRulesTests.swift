import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(101)
private let b = WindowID(102)

/// The nets for the product's seven rules (`ChaosInvariants+SevenRules.swift`) catch what they are for. Each test is a control: a fault is
/// done to the world as if Arbor had done it, and the net has to speak; beside it the same story without the fault, where it has to be silent.
@Suite @MainActor struct ChaosSevenRulesTests {
  /// Plays `lines`, whatever rules they break, then `last` with `fault` done as part of it, then `later`. Returns the nets that spoke from
  /// `last` on.
  private func nets(
    after lines: [String], then last: String, _ later: String..., fault: ((FakeWindowSystem) -> Void)? = nil
  ) -> Set<String> {
    let runner = ChaosRunner()
    for line in lines { _ = runner.step(ChaosAction(text: line)) }
    if let fault { runner.beforeTheNextCheck = { fault($0.system) } }
    let prefixes = ["flashed-", "moved-", "sized-", "set-right-", "fetched-", "switched-to-", "app-switch-", "size-", "home-", "there-and-back-", "start-", "pause-and-", "quit-", "displays-", "dragged-"]
    return Set(([last] + later).flatMap { runner.step(ChaosAction(text: $0)) }.map(\.rule).filter { rule in prefixes.contains { rule.hasPrefix($0) } })
  }

  private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect { CGRect(x: x, y: y, width: width, height: height) }

  private let twoFloating = ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400", "settle"]
  private let oneDocked = [
    "launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400", "dock 101 left", "settle",
  ]

  // MARK: No jolts

  @Test func aWindowMovedTwiceForOneThingIsAJolt() {
    #expect(nets(after: oneDocked, then: "dock 102 right").isEmpty)
    // There and on, in the step of the command that was about it.
    let twice = nets(after: oneDocked, then: "dock 102 right") {
      _ = $0.setFrame(self.rect(700, 100, 500, 400), of: b)
      _ = $0.setFrame(self.rect(726, 37, 702, 851), of: b)
    }
    #expect(twice.contains("moved-twice"))
  }

  @Test func aWindowMovedAgainAMomentLaterWithNobodyTouchingAnythingIsAJolt() {
    let moved = oneDocked + ["dock 102 right"]
    #expect(nets(after: moved, then: "flush").isEmpty)
    #expect(nets(after: moved, then: "flush") { _ = $0.setFrame(self.rect(726, 60, 702, 800), of: b) }.contains("moved-again"))
    // Once somebody has done something else it is a first move again. (That it was not asked for is another net's business.)
    #expect(!nets(after: moved + ["cursor 10 10"], then: "flush") { _ = $0.setFrame(self.rect(726, 60, 702, 800), of: b) }.contains("moved-again"))
  }

  /// A key that comes up belongs to its going down, and seconds in which something does move are not seconds of rest.
  @Test func aMoveAfterAKeyHasComeUpOrEarlyInALongWaitIsStillTheSameStory() {
    let pressed = oneDocked + ["focus 102", "react", "key down dock right", "key up dock right"]
    #expect(nets(after: pressed, then: "flush") { _ = $0.setFrame(self.rect(726, 60, 702, 800), of: b) }.contains("moved-again"))
    #expect(nets(after: pressed, then: "advance 5") { _ = $0.setFrame(self.rect(726, 60, 702, 800), of: b) }.contains("moved-again"))
    #expect(!nets(after: pressed + ["advance 5"], then: "flush") { _ = $0.setFrame(self.rect(726, 60, 702, 800), of: b) }.contains("moved-again"))
  }

  @Test(arguments: ["quit", "pause"]) func aWindowMovedTwiceOnTheWayOutIsAJolt(way: String) {
    #expect(!nets(after: oneDocked, then: way).contains("moved-twice"))
    let twice = nets(after: oneDocked, then: way) {
      _ = $0.setFrame(self.rect(60, 60, 500, 400), of: a)
      _ = $0.setFrame(self.rect(100, 100, 500, 400), of: a)
    }
    #expect(twice.contains("moved-twice"))
  }

  @Test func aWindowThatShowsAndGoesAgainOrGoesAndComesBackIsAFlash() {
    let framed = oneDocked + ["zoom 101", "settle"]
    let shown = nets(after: framed, then: "cursor 10 10") {
      _ = $0.setFrame(self.rect(800, 300, 500, 400), of: b)
      _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b)
    }
    #expect(shown.contains("flashed-into-view") && !shown.contains("moved-twice"))
    let gone = nets(after: oneDocked, then: "cursor 10 10") {
      _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b)
      _ = $0.setFrame(self.rect(800, 300, 500, 400), of: b)
    }
    #expect(gone.contains("flashed-out-of-view"))
  }

  @Test func aWindowMovedOverAndOverWithNobodyActingIsStuck() {
    let stuck = nets(after: oneDocked + ["dock 102 right", "react"], then: "flush") {
      for x in [730, 726, 730, 726] as [CGFloat] { _ = $0.setFrame(self.rect(x, 37, 702, 851), of: b) }
    }
    #expect(stuck.contains("moved-over-and-over"))
  }

  /// Sized where it stands, then moved once: two moves, and nothing turns back.
  @Test func aFirstMeetingInWhichEachCoordinateGoesOneWayOnlyIsNoJolt() {
    #expect(ChaosRunner.goesOneWayOnly([rect(300, 200, 500, 455), rect(300, 200, 500, 851), rect(113, 37, 500, 851)]))
    #expect(!ChaosRunner.goesOneWayOnly([rect(300, 200, 500, 455), rect(12, 37, 500, 851), rect(113, 37, 500, 851)]))
  }

  @Test func whatNobodyCanSeeIsNoJolt() {
    // Framed on 101, 102 is out of view, and is moved about there.
    let framed = oneDocked + ["zoom 101", "settle"]
    let unseen = nets(after: framed, then: "cursor 10 10") {
      _ = $0.setFrame(self.rect(1439, 2000, 500, 400), of: b)
      _ = $0.setFrame(self.rect(1439, 2100, 500, 400), of: b)
    }
    #expect(!unseen.contains("moved-twice"))
  }

  @Test func anAppThatRefusesASizeIsToldApartAndOnlyTheFirstTimeIsNews() {
    let narrow = ["launch", "open 101 Notes pid 1001 at 100 100 500 400 max 500 2000", "open 102 Mail pid 1002 at 800 300 500 400", "settle"]
    #expect(nets(after: narrow, then: "dock 101 left").isEmpty, "it grows in its slot; that it cannot shows there, the first time")
    // Into the corner of its slot, and from there to its middle.
    let byWayOfTheCorner: (CGFloat) -> (FakeWindowSystem) -> Void = { x in
      {
        _ = $0.setFrame(self.rect(x, 37, 702, 851), of: a)
        _ = $0.setFrame(self.rect(x + 101, 37, 500, 851), of: a)
      }
    }
    #expect(nets(after: narrow, then: "dock 101 left", fault: byWayOfTheCorner(12)).contains("moved-twice-sizing"))
    let again = narrow + ["dock 101 left", "settle", "float 101", "settle"]
    #expect(nets(after: again, then: "dock 101 right").isEmpty)
    #expect(nets(after: again, then: "dock 101 right", fault: byWayOfTheCorner(726)).contains("moved-twice-sizing-again"))
  }

  /// A window grows in its slot. The first time it turns out unable to, it goes on to the middle of the slot as it is, and only that is let pass.
  @Test func onlyTheWayToTheMiddleOfWhatItWasOfferedIsLetPass() {
    // Docked, and unable to grow since. Nobody has met that yet.
    let limited = oneDocked + ["limits 101 min 100 100 max 500 2000"]
    func hop(to second: CGRect) -> (FakeWindowSystem) -> Void {
      {
        _ = $0.setFrame(self.rect(726, 37, 702, 851), of: a)
        _ = $0.setFrame(second, of: a)
      }
    }
    func jolts(_ fault: @escaping (FakeWindowSystem) -> Void) -> Set<String> {
      nets(after: limited, then: "cursor 10 10", fault: fault).filter { $0.hasPrefix("moved-twice") || $0.hasPrefix("sized-") || $0.hasPrefix("set-right-") }
    }
    #expect(jolts(hop(to: rect(827, 37, 500, 851))).isEmpty, "the hop itself")
    #expect(jolts(hop(to: rect(400, 37, 500, 851))) == ["moved-twice-sizing"], "out of what it was offered")
    #expect(jolts(hop(to: rect(827, 37, 400, 851))) == ["moved-twice-sizing"], "at another size")
    #expect(
      jolts {
        hop(to: self.rect(827, 37, 500, 851))($0)
        hop(to: self.rect(827, 37, 500, 851))($0)
      } == ["moved-twice-sizing"], "twice")
    // A floating window has no slot.
    let floating = twoFloating + ["limits 101 min 100 100 max 500 2000"]
    #expect(nets(after: floating, then: "cursor 10 10", fault: hop(to: rect(827, 37, 500, 851))).contains("moved-twice-sizing-floating"))
  }

  /// A terminal is a few points short of any slot, and that it is set right in it has a name and an owner of its own.
  @Test func aTerminalSetRightInItsSlotHasAName() {
    let terminal = ["launch", "open 101 Terminal pid 1001 at 100 100 500 400", "behave 101 grid", "open 102 Mail pid 1002 at 800 300 500 400", "settle"]
    let below = terminal + ["dock 102 left", "settle"]
    #expect(nets(after: below, then: "dock 101 beside 102 bottom").isEmpty, "the first time nobody could know")
    // It grows to a height it has not been seen at.
    #expect(nets(after: below + ["dock 101 beside 102 bottom", "settle"], then: "float 102") == ["set-right-by-less-than-a-cell"])
    // A window that stops a few points short of its slot for another reason is not a terminal.
    let short = ["launch", "open 101 Notes pid 1001 at 100 100 500 400 max 680 2000", "open 102 Mail pid 1002 at 800 300 500 400", "dock 101 left", "settle", "float 101", "settle"]
    #expect(
      nets(after: short, then: "dock 101 right") {
        _ = $0.setFrame(self.rect(726, 37, 702, 851), of: a)
        _ = $0.setFrame(self.rect(737, 37, 680, 851), of: a)
      }.contains("moved-twice-sizing-again"))
  }

  /// A window Arbor does not know is asked for a size where it stands, and goes to its place afterwards. That is two requests and
  /// one road. Smaller on the way than it ends up is a jolt with a name of its own, and a floating window's has another owner.
  @Test func whatIsJudgedIsTheRoadNotTheNumberOfRequests() {
    #expect(
      nets(after: oneDocked, then: "cursor 10 10") {
        _ = $0.setFrame(self.rect(12, 37, 600, 851), of: a)
        _ = $0.setFrame(self.rect(300, 37, 600, 851), of: a)
      }.allSatisfy { !$0.hasPrefix("moved-twice") && !$0.hasPrefix("sized-") })
    #expect(
      nets(after: oneDocked, then: "cursor 10 10") {
        _ = $0.setFrame(self.rect(12, 37, 400, 851), of: a)
        _ = $0.setFrame(self.rect(12, 37, 600, 851), of: a)
      }.contains("sized-there-and-back"))
    #expect(
      nets(after: oneDocked, then: "cursor 10 10") {
        _ = $0.setFrame(self.rect(900, 300, 500, 400), of: b)
        _ = $0.setFrame(self.rect(850, 300, 500, 400), of: b)
      }.contains("moved-twice-floating"))
  }

  /// One known bug has a name of its own, and nothing else goes by it: not the same jolt without the setting, nor in another order.
  @Test func theNameForWindowsFirstIsOnlyThatBugs() {
    let jolt: (FakeWindowSystem) -> Void = {
      _ = $0.setFrame(self.rect(900, 300, 500, 400), of: b)
      _ = $0.setFrame(self.rect(850, 300, 500, 400), of: b)
    }
    let (filling, displays) = (oneDocked + ["set soleFloatTakesDesktop true", "settle"], "displays main:0,0,1440,900:25,0,0,0* ")
    #expect(nets(after: filling, then: displays + "windows-first", fault: jolt).contains("moved-twice-floating-windows-first"))
    #expect(nets(after: oneDocked, then: displays + "windows-first", fault: jolt).contains("moved-twice-floating"))
    #expect(nets(after: filling, then: displays + "windows-late", fault: jolt).contains("moved-twice-floating"))
    #expect(nets(after: filling, then: "cursor 10 10", fault: jolt).contains("moved-twice-floating"))
  }

  // MARK: Nothing moves that was not asked to

  @Test func nothingMovesBeforeAnythingIsDocked() {
    #expect(nets(after: twoFloating, then: "focus 101").isEmpty)
    #expect(nets(after: twoFloating, then: "focus 101") { _ = $0.setFrame(self.rect(120, 100, 500, 400), of: a) } == ["moved-before-any-dock"])
    #expect(nets(after: ["open 101 Notes pid 1001 at 100 100 500 400"], then: "launch").isEmpty)
    #expect(
      nets(after: ["open 101 Notes pid 1001 at 100 100 500 400"], then: "launch") { _ = $0.setFrame(self.rect(120, 100, 500, 400), of: a) }
        == ["moved-before-any-dock"])
  }

  /// What is found counts as left: a window parked a quarter in view is nobody's to fetch, at a start or when it opens. One that nobody
  /// could get hold of is, and the net has nothing to say to that.
  @Test func whatIsParkedOverTheEdgeIsNotFetchedAndWhatIsOutOfReachMayBe() {
    let parked = "open 101 Notes pid 1001 at 1290 300 600 400"
    #expect(nets(after: [parked], then: "launch").isEmpty)
    #expect(nets(after: [parked], then: "launch") { _ = $0.setFrame(self.rect(420, 262, 600, 400), of: a) } == ["fetched-before-any-dock"])
    #expect(nets(after: ["launch"], then: parked).isEmpty)
    #expect(nets(after: ["launch"], then: parked) { _ = $0.setFrame(self.rect(420, 262, 600, 400), of: a) } == ["fetched-before-any-dock"])
    // 24 points of its title bar are the least that counts, and 23 are not enough.
    #expect(
      nets(after: ["open 101 Notes pid 1001 at 1416 300 600 400"], then: "launch") { _ = $0.setFrame(self.rect(420, 262, 600, 400), of: a) }
        == ["fetched-before-any-dock"])
    #expect(nets(after: ["open 101 Notes pid 1001 at 1417 300 600 400"], then: "launch").isEmpty, "Arbor fetches it, and may")
    #expect(nets(after: ["launch"], then: "open 101 Notes pid 1001 at 1439 868 600 400").isEmpty, "Arbor fetches it, and may")
  }

  /// A window its person dragged two thirds over the bottom edge goes out with the view. On the way out of Arbor it is given back exactly
  /// there, and the rule about a quit has nothing to say. Left anywhere else with as little showing, it is lost.
  @Test(arguments: ["quit", "pause"]) func whatWentOutWithTheViewMayComeBackAsFarOverTheEdgeAsItWasLeftAndNoFurther(way: String) {
    let story = [
      "open 101 Notes pid 1001 at 30 26 738 624", "launch", "grab 101", "carry 426 689", "release", "open 102 Mail pid 1002 at 27 47 1196 685",
      "dock 102 top", "zoom 102", "settle",
    ]
    func rules(fault: ((FakeWindowSystem) -> Void)? = nil) -> [String] {
      let runner = ChaosRunner()
      for line in story { _ = runner.step(ChaosAction(text: line)) }
      #expect(runner.controller.parked.contains(a), "or this proves nothing")
      if let fault { runner.beforeTheNextCheck = { fault($0.system) } }
      return runner.step(ChaosAction(text: way)).map(\.rule)
    }
    #expect(!rules().contains("shutdown"))
    #expect(rules { _ = $0.setFrame(self.rect(900, 679, 738, 624), of: a) }.contains("shutdown"))
  }

  /// Two scripts that stood under the known failure `moved-before-any-dock` until what is found counted as left. That rule is still excused
  /// by name for what is left of it, so they are held to it here.
  @Test(arguments: [
    """
    open 101 Finder pid 1005 at 112 32 1058 458 min 501 300
    grab 101
    carry 1303 40
    release
    launch
    open 104 Safari pid 1000 at 20 113 1068 656 min 574 240
    close 104
    """,
    """
    open 102 Preview pid 1007 at 184 55 723 455 min 723 400 max 723 2000
    grab 102
    carry 870 656
    release
    minimize 102
    launch
    restore 102
    """,
  ]) func whatWasHungOverAnEdgeBeforeTheLaunchIsNotPulledInLater(script: String) {
    let others = ChaosRunner.knownRules.subtracting(["moved-before-any-dock"])
    #expect(ChaosRunner.replay(ChaosAction.script(script), excusing: others)?.violations.map(\.rule) == nil)
  }

  @Test func aWindowTheStepWasNotAboutStaysWhereItIs() {
    #expect(nets(after: oneDocked, then: "focus 101").isEmpty)
    #expect(nets(after: oneDocked, then: "focus 101") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-unasked"))
    // The one it was about is another matter.
    #expect(!nets(after: oneDocked, then: "focus 102") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-unasked"))
  }

  @Test func whatFloatsInViewStaysWhereItIsAtLaunchAndWhenAPauseEnds() {
    let again = oneDocked + ["quit"]
    #expect(nets(after: again, then: "launch").isEmpty)
    #expect(nets(after: again, then: "launch") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-at-launch"))
    // After a run that did not quit it has a name of its own, so that what is known of the one does not excuse the other.
    #expect(nets(after: again + ["crash"], then: "launch") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-at-launch"), "nothing was running that could crash")
    let killed = oneDocked + ["crash"]
    #expect(nets(after: killed, then: "launch").isEmpty)
    #expect(nets(after: killed, then: "launch") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-at-launch-after-a-crash"))
    let paused = oneDocked + ["pause"]
    #expect(nets(after: paused, then: "resume").isEmpty)
    #expect(nets(after: paused, then: "resume") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-at-resume"))
  }

  @Test func aStartTakesNothingOutOfView() {
    let again = oneDocked + ["quit"]
    #expect(!nets(after: again, then: "launch").contains("start-took-out-of-view"))
    #expect(nets(after: again, then: "launch") { _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b) }.contains("start-took-out-of-view"))
    // What Show Everything itself has out of view may go, but for the window that has the keyboard.
    let aTile = [
      "launch", "settings {\"makeRoom\":false}", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400",
      "dock 101 left", "dock 102 right", "resize 101 right -300", "settle", "quit",
    ]
    #expect(!nets(after: aTile + ["focus 102"], then: "launch").contains("start-took-out-of-view"))
    #expect(!nets(after: aTile + ["focus 101"], then: "launch").contains("start-took-out-of-view"))
    #expect(nets(after: aTile + ["focus 101"], then: "launch") { _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: a) }.contains("start-took-out-of-view"))
  }

  @Test func aQuitLeavesNothingWhereNobodyCanGetHoldOfIt() {
    let framed = oneDocked + ["zoom 101", "settle"]
    #expect(nets(after: framed, then: "quit", "advance 1").isEmpty)
    #expect(nets(after: framed, then: "quit", "advance 1") { _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b) }.contains("quit-left-out-of-reach"))
    // A process that was killed had no chance.
    #expect(!nets(after: framed, then: "crash", "advance 1").contains("quit-left-out-of-reach"))
  }

  @Test func afterAChangeOfDisplaysNothingIsMostlyOutOfView() {
    let two = ["displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0 windows-never"] + twoFloating + ["move 102 1600 300 500 400", "settle"]
    let unplug = "displays main:0,0,1440,900:25,0,0,0* windows-late"
    #expect(!nets(after: two, then: unplug, "react", "settle").contains("displays-left-mostly-out"))
    #expect(
      nets(after: two, then: unplug, "react", "settle") { _ = $0.setFrame(self.rect(1380, 300, 500, 400), of: b) }.contains("displays-left-mostly-out"))
  }

  @Test func aGapItsPersonDraggedLasts() {
    let dragged = oneDocked + ["dock 102 right", "settle", "seam main 0 -100", "react", "settle"]
    #expect(!nets(after: dragged, then: "key down home", "key up home", "react", "settle").contains("dragged-gap-did-not-last"))
    #expect(
      nets(after: dragged, then: "key down home", "key up home", "react", "settle") { system in
        let frame = system.frame(of: a)!
        _ = system.setFrame(CGRect(x: frame.minX, y: frame.minY, width: frame.width + 60, height: frame.height), of: a)
      }.contains("dragged-gap-did-not-last"))
    // Once the arrangement is changed on purpose there is nothing to hold it to.
    #expect(
      !nets(after: dragged + ["balance", "settle"], then: "key down home", "key up home", "react", "settle") { system in
        let frame = system.frame(of: a)!
        _ = system.setFrame(CGRect(x: frame.minX, y: frame.minY, width: frame.width + 60, height: frame.height), of: a)
      }.contains("dragged-gap-did-not-last"))
  }

  @Test func thereAndBackIsNothing() {
    for (there, back) in [("minimize 102", "restore 102"), ("hide 1002", "show 1002"), ("zoom 101", "back")] {
      let gone = oneDocked + [there, "react", "advance 1", "react"]
      #expect(nets(after: gone, then: back, "react", "settle").isEmpty, "\(there)")
      #expect(
        nets(after: gone, then: back, "react", "settle") { _ = $0.setFrame(self.rect(820, 320, 500, 400), of: b) }.contains("there-and-back-moved"),
        "\(there)")
    }
    // With something else done between the two there is nothing to compare.
    #expect(
      !nets(after: oneDocked + ["minimize 102", "focus 101", "react"], then: "restore 102", "react", "settle") {
        _ = $0.setFrame(self.rect(820, 320, 500, 400), of: b)
      }.contains("there-and-back-moved"))
  }

  @Test func aPauseInWhichNothingHappensCannotBeSeenAfterwards() {
    let paused = oneDocked + ["pause"]
    #expect(!nets(after: paused, then: "resume", "react", "settle").contains("pause-and-resume-moved"))
    #expect(
      nets(after: paused, then: "resume", "react", "settle") { _ = $0.setFrame(self.rect(820, 320, 500, 400), of: b) }.contains("pause-and-resume-moved"))
  }

  // MARK: The window you switch to

  @Test func theWindowSwitchedToIsInView() {
    let framed = oneDocked + ["zoom 101", "settle"]
    #expect(nets(after: framed + ["focus 102", "react"], then: "settle").isEmpty)
    // Sent out again behind its user's back.
    #expect(
      nets(after: framed + ["focus 102", "react", "settle"], then: "flush", "react") { _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b) }
        .contains("switched-to-out-of-view"))
  }

  @Test func theWindowSwitchedToIsInFront() {
    let overlapping = ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 300 200 500 400", "settle"]
    #expect(nets(after: overlapping + ["focus 101", "react"], then: "settle").isEmpty)
    #expect(nets(after: overlapping + ["focus 101", "react"], then: "settle") { $0.bringToFront(b) }.contains("switched-to-behind"))
  }

  // MARK: The ways home

  @Test(arguments: ["float-all", "quit", "pause"]) func aWayOutGivesEveryWindowItsOwnSizeBack(way: String) {
    #expect(nets(after: oneDocked, then: way).isEmpty)
    #expect(nets(after: oneDocked, then: way) { _ = $0.setFrame(self.rect(100, 100, 702, 400), of: a) }.contains("size-not-given-back"))
  }

  @Test func theSizeItsUserGaveItLastIsItsOwn() {
    // Made larger by hand while it floated, then docked.
    let resized = twoFloating + ["move 101 100 100 640 480", "dock 101 left", "settle"]
    #expect(nets(after: resized, then: "float-all").isEmpty)
    #expect(nets(after: resized, then: "float-all") { _ = $0.setFrame(self.rect(100, 100, 500, 400), of: a) }.contains("size-not-given-back"))
  }

  /// Dragged out of its slot to the side of the display, where macOS tiles: half the display is what its person asked macOS for.
  @Test func theSizeMacOSGaveItAtItsPersonsDragIsItsOwn() {
    let tiled = oneDocked + ["grab 101", "carry 1439 400", "advance 0.5", "release", "react", "settle"]
    #expect(!nets(after: tiled, then: "quit").contains("size-not-given-back"))
  }

  @Test func afterAWayHomeEveryWindowIsWhollyInView() {
    let framed = oneDocked + ["zoom 101", "settle"]
    #expect(nets(after: framed, then: "home").isEmpty)
    #expect(nets(after: framed, then: "home") { _ = $0.setFrame(self.rect(1200, 300, 500, 400), of: b) }.contains("home-not-whole"))
    // Where its user left it hanging, it may hang.
    let hanging = ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400", "dock 101 left", "move 102 1200 300 500 400", "zoom 101", "settle"]
    #expect(!nets(after: hanging, then: "home").contains("home-not-whole"))
  }

  /// People press keys: the question is asked after ⌃⌥0 as after `home`.
  @Test func aWayHomeTakenWithItsKeyIsAskedTheSame() {
    let framed = oneDocked + ["zoom 101", "settle"]
    #expect(nets(after: framed, then: "key down home").isEmpty)
    #expect(nets(after: framed, then: "key down home") { _ = $0.setFrame(self.rect(1200, 300, 500, 400), of: b) }.contains("home-not-whole"))
    #expect(nets(after: oneDocked, then: "key down float-all") { _ = $0.setFrame(self.rect(100, 100, 702, 400), of: a) }.contains("size-not-given-back"))
  }

  @Test func whatArborPlacesOnTheWayHomeIsClearOfTheDock() {
    let withADock = ["displays main:0,0,1440,900:25,0,70,0* windows-never"] + oneDocked + ["zoom 101", "settle"]
    #expect(nets(after: withADock, then: "home").isEmpty)
    #expect(nets(after: withADock, then: "home") { _ = $0.setFrame(self.rect(800, 480, 500, 400), of: b) }.contains("home-behind-the-dock"))
  }

  // MARK: The nets are cast

  /// A net that never asks its question catches nothing. The floors are about half of what forty ordinary walks gave when this was written.
  @Test func ordinaryWalksReachEveryQuestion() {
    let before = ChaosRunner.questionsAsked
    // Past every rule: what is counted is how far the walks get, not what they find.
    for seed in UInt64(1)...40 {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed, ordinary: true)
      for _ in 0..<200 { _ = runner.step(generator.next(runner)) }
      for way in ChaosRunner.WayBack.allCases { _ = runner.step(.wayBack(way)) }
    }
    func asked(_ net: String) -> Int { (ChaosRunner.questionsAsked[net] ?? 0) - (before[net] ?? 0) }
    for (net, floor) in Self.floors { #expect(asked(net) >= floor, "\(net) was asked \(asked(net)) times") }
  }

  private static let floors = [
    "once": 500, "before-any-dock": 1000, "unasked": 1800, "launch-or-resume": 8, "switched-to": 280, "way-home": 400, "sizes": 220, "start": 20,
    "there-and-back": 20, "pause-and-resume": 1,
  ]
}
