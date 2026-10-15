import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// macOS's own full screen is left to macOS (T63), also for a window Arbor already arranges.
@Suite @MainActor struct FullScreenTests {
  /// `[a | Desktop | b]` with `f` floating.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, f)
  }

  /// Where `a` was before Arbor moved it, which is where macOS lands it.
  let own = CGRect(x: 100, y: 100, width: 600, height: 400)

  /// The green button on `window`: it fills the display on a new Space, which slides into view.
  func enterFullScreen(_ h: Harness, _ window: WindowID, others: [WindowID]) {
    h.system.setFullScreen(window, true)
    for other in others { h.system.setOnActiveSpace(other, false) }
    h.scheduler.advance(by: 2)
  }

  func leaveFullScreen(_ h: Harness, _ window: WindowID, others: [WindowID]) {
    h.system.setFullScreen(window, false)
    for other in others { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
  }

  @Test func aDockedWindowThatGoesFullScreenIsLeftAlone() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    h.system.clearFrameLog()
    enterFullScreen(h, a, others: [b, f])
    #expect(h.frame(a) == FakeWindowSystem.standardDisplay.frame)
    #expect(!h.system.frameLog.contains { $0.window == a }, "Arbor must not try to move it")
    #expect(h.overlays.tiles[h.display]?.isEmpty == true, "nothing of Arbor's may cover a full-screen window")
    #expect(h.overlays.seams[h.display]?.isEmpty == true)
    #expect(!h.controller.parked.contains(a))
    #expect(h.workspace.isDocked(a), "it keeps its slot")

    leaveFullScreen(h, a, others: [b, f])
    #expect(h.frame(a) == slot)
    #expect(h.layout!.tiles.isEmpty, "and is not taken for a window that refuses to shrink")
    #expect(h.system.isVisible(b) && h.system.isVisible(f))
  }

  @Test func theNeighboursOfAFullScreenWindowTakeItsSpaceOnTheirOwnSpace() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    // Back to the first Space with a swipe; Safari stays full screen on its own.
    h.system.setOnActiveSpace(a, false)
    for other in [b, f] { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[a] == nil)
    #expect(h.layout!.windowFrames[b] != nil)
    #expect(h.layout!.desktopFrame!.minX == h.visibleFrame.minX + 12, "the Desktop has Safari's space")
  }

  @Test func aFloatingWindowThatGoesFullScreenKeepsTheFrameTheUserGaveIt() {
    let (h, a, b, f) = makeHarness()
    let chosen = h.frame(f)!
    enterFullScreen(h, f, others: [a, b])
    #expect(h.workspace.floating[f] == chosen)
    leaveFullScreen(h, f, others: [a, b])
    #expect(h.frame(f) == chosen)
  }

  @Test func commandsOnAFullScreenWindowAreRefused() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.system.focused = a
    let tree = h.workspace.tree
    for command in ["dock right", "float", "toggle-float", "zoom", "resize right 50", "dock \(a.rawValue) left"] {
      let result = h.run(command)
      #expect(!result.ok, "\(command)")
      #expect(result.message.contains("full screen"), "\(command): \(result.message)")
    }
    #expect(h.workspace.tree == tree)
    #expect(h.workspace.camera == tree.root)
  }

  /// "A window moves once, to where it ends up." On a Mac the window landed where macOS put it, in plain view, and went to its
  /// slot 282 ms later: Arbor had known for 0.7 s that it was coming, and waited to hear that it was back.
  @Test func aDockedWindowThatLeavesFullScreenIsSeenInItsSlotAndNowhereElse() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    enterFullScreen(h, a, others: [b, f])
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [b, f])
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: a) == [slot], "\(h.system.sightings(of: a))")
    #expect(h.layout!.tiles.isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// TextEdit. (The way out as it is played unless a test says otherwise is Safari's, which hears nothing at first.)
  @Test func anAppThatTakesTheFrameAtOnceIsAskedOnce() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    enterFullScreen(h, a, others: [b, f])
    h.system.clearSightings()
    h.system.clearFrameLog()
    h.system.leaveFullScreen(a, with: [b, f], deafFor: 0)
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: a) == [slot], "\(h.system.sightings(of: a))")
    #expect(h.system.frameLog.filter { $0.window == a }.count == 1)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("meet") }, "and Arbor stops looking")
  }

  @Test func anAppTooBusyToAnswerAtFirstIsAskedAgain() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    let pid = h.system.windows[a]!.snapshot.pid
    enterFullScreen(h, a, others: [b, f])
    h.system.setUnresponsive(pid: pid, true)
    // It answers again a quarter of a second into its way out.
    var asked = 0
    h.system.willSetFrame = { [system = h.system] window, _ in
      guard window == a else { return }
      asked += 1
      if asked == 3 { system.setUnresponsive(pid: pid, false) }
    }
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [b, f], deafFor: 0)
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: a) == [slot], "\(h.system.sightings(of: a))")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func anAppThatMakesSomethingElseOfTheFrameIsNotAskedAgainAndAgain() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    // Its neighbour closes meanwhile, so the slot is new to it, and it sizes itself in steps.
    h.system.close(b)
    h.system.setSizeStep(a, CGSize(width: 7, height: 15))
    h.system.clearFrameLog()
    h.system.leaveFullScreen(a, with: [f], deafFor: 0)
    // Twice ahead of its landing; the layout then takes two to fit it into a slot that is new to it: the slot, and a cell less. It
    // stays in the corner, so there is no third.
    #expect(h.system.frameLog.filter { $0.window == a }.count == 4, "\(h.system.frameLog)")
    h.scheduler.advance(by: 2)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  @Test func itsSlotIsTheOneItWillHaveNotTheOneItHad() {
    let (h, a, b, f) = makeHarness()
    let before = h.frame(a)!
    enterFullScreen(h, a, others: [b, f])
    // Its neighbour closes meanwhile, on the Space that does not show.
    h.system.close(b)
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [f])
    h.scheduler.advance(by: 2)
    #expect(h.frame(a) != before)
    #expect(h.system.sightings(of: a) == [h.frame(a)!], "\(h.system.sightings(of: a))")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func whatIsDockedOnAThirdSpaceDoesNotCountAsBack() {
    let (h, a, b, f) = makeHarness()
    let c = h.system.open(app: "Mail", frame: CGRect(x: 200, y: 150, width: 600, height: 400))
    h.run("dock \(c.rawValue) beside \(a.rawValue) right")
    // Mail lives on another desktop, so Safari has its room here.
    h.system.setOnActiveSpace(c, false)
    h.scheduler.advance(by: 2)
    let slot = h.frame(a)!
    enterFullScreen(h, a, others: [b, f])
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [b, f])
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: a) == [slot], "\(h.system.sightings(of: a))")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowThatClosesInFullScreenIsForgotten() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.system.close(a)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  @Test func oneThatTakesNoFrameOnItsWayOutStillEndsInItsSlot() {
    let (h, a, b, f) = makeHarness()
    let slot = h.frame(a)!
    h.system.echoes.flightFromFullScreen = 0.9
    enterFullScreen(h, a, others: [b, f])
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [b, f])
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: a) == [own, slot], "two moves, as before: there is nothing Arbor can do")
    #expect(h.layout!.tiles.isEmpty, "what it answered on its way says nothing about its sizes")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aFloatingWindowOnItsWayOutIsLeftToMacOS() {
    let (h, a, b, f) = makeHarness()
    let chosen = h.frame(f)!
    enterFullScreen(h, f, others: [a, b])
    h.system.clearSightings()
    h.system.leaveFullScreen(f, with: [a, b])
    h.scheduler.advance(by: 2)
    #expect(h.system.sightings(of: f) == [chosen], "\(h.system.sightings(of: f))")
    #expect(h.workspace.floating[f] == chosen)
  }

  @Test func duringAPauseAWindowOnItsWayOutIsNotArborsToMove() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.run("pause")
    h.system.clearFrameLog()
    h.system.leaveFullScreen(a, with: [b, f])
    h.scheduler.advance(by: 2)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  @Test func oneWhoseSlotIsOutOfViewIsNotFetchedAhead() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    // Back on the first Space with a swipe, the view goes to the neighbour; then back to Safari's Space and out of full screen.
    h.system.setOnActiveSpace(a, false)
    for other in [b, f] { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
    h.run("zoom \(b.rawValue)")
    for other in [b, f] { h.system.setOnActiveSpace(other, false) }
    h.system.setOnActiveSpace(a, true)
    h.scheduler.advance(by: 2)
    h.system.clearSightings()
    h.system.leaveFullScreen(a, with: [b, f])
    h.scheduler.advance(by: 2)
    // It has the keyboard when it is back, so the view goes to it afterwards. That it then moves more than once is another matter.
    #expect(h.system.sightings(of: a).first == own, "\(h.system.sightings(of: a))")
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: The neighbours

  /// `[a | c | Desktop]` with `f` floating: with `a` away `c` and the Desktop would have its room.
  func makeRow() -> (Harness, a: WindowID, others: [WindowID]) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: own)
    let c = h.system.open(app: "Mail", frame: CGRect(x: 200, y: 150, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 1000, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) right")
    #expect(h.layout!.tiles.isEmpty)
    return (h, a, [c, f])
  }

  /// On a Mac they took its room while the way in played over them, and gave it back when it had returned: two moves each, for nothing.
  @Test func intoFullScreenAndStraightBackNothingButTheWindowMoves() {
    let (h, a, others) = makeRow()
    let before = others.map { h.frame($0)! }
    h.system.clearSightings()
    h.system.enterFullScreen(a, leaving: others)
    h.scheduler.advance(by: 3)
    h.system.leaveFullScreen(a, with: others)
    h.scheduler.advance(by: 3)
    #expect(h.system.sightings.filter { $0.window != a }.isEmpty, "\(h.system.sightings)")
    #expect(others.map { h.frame($0)! } == before)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// TextEdit's order: all of them are reported back at once.
  @Test func norWhenAllAreReportedBackTogether() {
    let (h, a, others) = makeRow()
    h.system.clearSightings()
    h.system.enterFullScreen(a, leaving: others)
    h.scheduler.advance(by: 3)
    h.system.leaveFullScreen(a, with: others, deafFor: 0, othersFirst: false)
    h.scheduler.advance(by: 3)
    #expect(h.system.sightings.filter { $0.window != a }.isEmpty, "\(h.system.sightings)")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aFocusReportWhileTheWayInPlaysDoesNotEndTheWait() {
    let (h, a, others) = makeRow()
    h.system.clearSightings()
    h.system.setOnActiveSpace(a, false)
    h.system.setFullScreen(a, true)
    h.scheduler.advance(by: 0.15)
    // A chat window in the background, say.
    h.system.backgroundFocus(others[0])
    h.scheduler.advance(by: 0.3)
    #expect(h.system.sightings.isEmpty, "\(h.system.sightings)")
  }

  @Test func heardOfWhenTheSpaceHasGoneThereIsNothingToWaitFor() {
    let (h, a, others) = makeRow()
    for other in others { h.system.setOnActiveSpace(other, false) }
    h.system.setFullScreen(a, true)
    h.scheduler.advance(by: 0.2)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("space") })
    #expect(h.layout!.windowFrames[a] == nil)
  }

  @Test func aFloatingWindowKeepsItsFrameInTheOrderOfAMacToo() {
    let (h, a, others) = makeRow()
    let f = others[1]
    let chosen = h.workspace.floating[f]
    h.system.enterFullScreen(f, leaving: [a, others[0]])
    h.scheduler.advance(by: 3)
    #expect(h.workspace.floating[f] == chosen, "not the display's")
    h.system.leaveFullScreen(f, with: [a, others[0]])
    h.scheduler.advance(by: 3)
    #expect(h.workspace.floating[f] == chosen)
  }

  @Test func whoeverComesBackToTheirSpaceWithoutItFindsThemClosingUpOnce() {
    let (h, a, others) = makeRow()
    h.system.enterFullScreen(a, leaving: others)
    h.scheduler.advance(by: 3)
    h.system.clearSightings()
    // A swipe back; Safari stays in full screen on its own Space.
    h.system.setOnActiveSpace(a, false)
    for other in others { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[a] == nil)
    for other in others { #expect(h.system.sightings(of: other).count <= 1, "\(h.system.sightings(of: other))") }
    #expect(!h.system.sightings.isEmpty, "they have its room")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func closedInFullScreenItsNeighboursCloseUpOnce() {
    let (h, a, others) = makeRow()
    h.system.enterFullScreen(a, leaving: others)
    h.scheduler.advance(by: 3)
    h.system.clearSightings()
    // Its Space goes with it, and macOS shows the one it came from.
    h.system.close(a)
    for other in others { h.system.setOnActiveSpace(other, true) }
    h.scheduler.advance(by: 2)
    for other in others { #expect(h.system.sightings(of: other).count <= 1, "\(h.system.sightings(of: other))") }
    #expect(!h.system.sightings.isEmpty, "they have its room")
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aSpaceThatNeverGoesAwayIsLaidOutAllTheSame() {
    let (h, a, others) = makeRow()
    // Only the report that it is in full screen: whatever became of the rest.
    h.system.setFullScreen(a, true)
    h.scheduler.advance(by: 1)
    #expect(h.layout!.windowFrames[a] != nil, "still waiting")
    h.scheduler.advance(by: 1)
    #expect(h.layout!.windowFrames[a] == nil)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("space") })
    _ = others
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func quittingLeavesAFullScreenWindowAlone() {
    let (h, a, b, f) = makeHarness()
    enterFullScreen(h, a, others: [b, f])
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(!h.system.frameLog.contains { $0.window == a })
  }
}
