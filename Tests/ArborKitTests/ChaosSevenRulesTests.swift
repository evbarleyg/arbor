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
    let prefixes = ["moved-", "fetched-", "switched-to-", "app-switch-", "size-", "home-", "there-and-back-", "start-", "pause-and-"]
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
    // Into the corner of its slot, and from there to its middle.
    #expect(nets(after: narrow, then: "dock 101 left").contains("moved-twice-sizing"))
    #expect(nets(after: narrow + ["dock 101 left", "settle", "float 101", "settle"], then: "dock 101 right").contains("moved-twice-sizing-again"))
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
    let paused = oneDocked + ["pause"]
    #expect(nets(after: paused, then: "resume").isEmpty)
    #expect(nets(after: paused, then: "resume") { _ = $0.setFrame(self.rect(820, 300, 500, 400), of: b) }.contains("moved-at-resume"))
  }

  @Test func aStartTakesNothingOutOfView() {
    let again = oneDocked + ["quit"]
    #expect(!nets(after: again, then: "launch").contains("start-took-out-of-view"))
    #expect(nets(after: again, then: "launch") { _ = $0.setFrame(self.rect(1439, 868, 500, 400), of: b) }.contains("start-took-out-of-view"))
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
    #expect(nets(after: overlapping + ["focus 101", "react"], then: "settle") { $0.raise(b) }.contains("switched-to-behind"))
  }

  // MARK: The ways home

  @Test(arguments: ["float-all", "quit"]) func aWayOutGivesEveryWindowItsOwnSizeBack(way: String) {
    #expect(nets(after: oneDocked, then: way).isEmpty)
    #expect(nets(after: oneDocked, then: way) { _ = $0.setFrame(self.rect(100, 100, 702, 400), of: a) }.contains("size-not-given-back"))
  }

  @Test func theSizeItsUserGaveItLastIsItsOwn() {
    // Made larger by hand while it floated, then docked.
    let resized = twoFloating + ["move 101 100 100 640 480", "dock 101 left", "settle"]
    #expect(nets(after: resized, then: "float-all").isEmpty)
    #expect(nets(after: resized, then: "float-all") { _ = $0.setFrame(self.rect(100, 100, 500, 400), of: a) }.contains("size-not-given-back"))
  }

  /// F40 leaves what is in view as it is, so that a pause cannot be seen; the product's fifth rule says a pause gives sizes back. Until that is
  /// decided the net says so under a name of its own.
  @Test func whatAPauseLeavesInItsSlotHasANameOfItsOwn() {
    #expect(nets(after: oneDocked, then: "pause") == ["size-kept-through-a-pause"])
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
