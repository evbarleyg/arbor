import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What real windows and real apps do to the controller: the review of the Accessibility layer
/// and F17.
@Suite @MainActor struct RealWindowHardeningTests {
  /// Safari docked on the left and Notes on the right, each in its own process.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 2000, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b)
  }

  // MARK: H2: apps that keep moving their own windows

  @Test func anAppThatKeepsMovingItsWindowBackIsLeftAloneAfterThreePutBacks() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    let own = CGRect(x: 200, y: 150, width: 500, height: 300)
    h.system.stubbornFrames[a] = own
    h.system.clearFrameLog()
    for _ in 0..<12 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    #expect(h.system.frameLog.filter { $0.window == a }.count == 3, "three put-backs, then peace")
    #expect(h.frame(a) == own)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") }, "\(h.scheduler.pendingKeys)")
    #expect(h.workspace.isDocked(a), "it keeps its place in the tree")

    // The next change of the layout is worth another try, and an app that has calmed down stays put.
    h.system.stubbornFrames[a] = nil
    h.run("float \(b.rawValue)")
    #expect(h.frame(a) == h.layout!.windowFrames[a])
    #expect(h.frame(a) != slot, "the slot grew when Notes left")
  }

  @Test func aWindowMovedNowAndThenIsAlwaysPutBack() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    for _ in 0..<8 {
      h.system.userMove(a, to: slot.offsetBy(dx: 60, dy: 40))
      h.scheduler.advance(by: 2)
      #expect(h.frame(a) == slot)
    }
  }

  @Test func givingUpOnOneWindowDoesNotStopTheOthersFromBeingPutBack() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(b)!
    h.system.stubbornFrames[a] = CGRect(x: 200, y: 150, width: 500, height: 300)
    for _ in 0..<8 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    h.system.userMove(b, to: slot.offsetBy(dx: -50, dy: 30))
    h.scheduler.advance(by: 0.3)
    #expect(h.frame(b) == slot)
  }

  /// Calculator or System Settings beside an app that fights. A window that cannot grow to its slot rests in the middle
  /// of it, which is not "out of place", so its neighbour's put-backs are none of its own.
  @Test func aWindowThatCannotFillItsSlotIsStillPutBackAfterItsNeighbourWasGivenUpOn() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Calculator", pid: 2000, frame: CGRect(x: 300, y: 200, width: 230, height: 400))
    h.system.setMaximumSize(b, CGSize(width: 230, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let rest = h.frame(b)!
    #expect(rest != h.layout!.windowFrames[b], "it is smaller than its slot")

    h.system.stubbornFrames[a] = CGRect(x: 200, y: 150, width: 500, height: 300)
    for _ in 0..<8 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    h.system.userMove(b, to: rest.offsetBy(dx: -50, dy: 30))
    h.scheduler.advance(by: 0.3)
    #expect(h.frame(b) == rest)
  }

  /// Found by the chaos lab. A window whose app hangs cannot reach its slot, which is not "keeps moving itself": the rounds a
  /// neighbour causes are none of its own, and when its app wakes it is placed.
  @Test func aHungAppsWindowIsNotGivenUpOnWhileItsNeighbourFights() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 2000, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("arrange")
    #expect(h.workspace.isDocked(b) && h.frame(b) != h.layout!.windowFrames[b], "it has a slot and cannot go there")
    h.system.stubbornFrames[a] = CGRect(x: 200, y: 150, width: 500, height: 300)
    for _ in 0..<8 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(h.frame(b) == h.layout!.windowFrames[b])
  }

  // MARK: Apps that hang

  @Test func aWindowWhoseAppDoesNotAnswerIsPlacedWhenItDoes() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    #expect(h.run("zoom \(a.rawValue)").ok)
    #expect(h.system.isVisible(b), "it could not be moved")
    #expect(!h.controller.parked.contains(b), "so it does not count as parked")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(!h.system.isVisible(b))
    h.run("back")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aHungAppsWindowGetsItsSlotWhenTheAppWakesUp() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.run("back")
    #expect(!h.system.isVisible(b))
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.system.isVisible(b))
  }

  /// The floating half of a layout takes a window out of view only when the camera moves, and the layout that follows
  /// an app's waking up is not such a move. The move is still owed.
  @Test func aHungAppsFloatingWindowGoesOutOfViewWhenTheAppWakesUp() {
    let (h, a, b) = makeHarness()
    let c = h.system.open(app: "Notes", pid: 2000, frame: CGRect(x: 400, y: 300, width: 300, height: 200))
    #expect(h.workspace.isFloating(c))
    h.system.setUnresponsive(pid: 2000, true)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.isVisible(b) && h.system.isVisible(c), "nothing can be asked of them")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(!h.system.isVisible(b))
    #expect(!h.system.isVisible(c), "it lay over the framed window until the camera next moved")
    // And it comes back as ever.
    h.run("back")
    #expect(h.system.isVisible(c))
  }

  /// What is owed is that one move. A floating window that was moved as asked is not touched by the same layout.
  @Test func anotherAppsFloatingWindowStaysWhereItsUserPutItWhenAHungAppWakesUp() {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 400, y: 300, width: 300, height: 200))
    h.system.setUnresponsive(pid: 2000, true)
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(c))
    // Its user fetches it, as with ⌘` or Mission Control, and puts it somewhere.
    let chosen = CGRect(x: 500, y: 350, width: 300, height: 200)
    h.system.userMove(c, to: chosen)
    h.scheduler.advance(by: 0.5)
    let settledAt = h.frame(c)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(h.frame(c) == settledAt)
  }

  // MARK: The Dock

  @Test func aLayoutUsesTheVisibleFrameAsItIsNow() {
    let (h, a, _) = makeHarness()
    // The Dock was made larger. macOS sends no notification for that.
    h.system.displayList[0].visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 795)
    h.run("relayout")
    #expect(h.frame(a)!.maxY == h.visibleFrame.maxY - 12)
    #expect(h.visibleFrame.maxY == 820)
  }

  // MARK: Drags whose end nobody saw

  @Test func aDragWhoseReleaseWasLostPutsADockedWindowBack() {
    let (h, a, _) = makeHarness()
    let slot = h.frame(a)!
    h.system.dragAndLoseTheRelease(a, to: CGPoint(x: 1438, y: 400))
    #expect(h.overlays.preview == nil, "no preview may stay on screen")
    #expect(h.frame(a) == slot)
    // Arbor is not left thinking that a drag is going on: focus is followed again.
    h.run("zoom \(a.rawValue)")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aDragWhoseReleaseWasLostLeavesAFloatingWindowWhereItIs() {
    let (h, _, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 600, y: 300, width: 200, height: 150))
    h.system.dragAndLoseTheRelease(c, to: CGPoint(x: 3, y: 400))
    #expect(h.overlays.preview == nil)
    #expect(h.workspace.isFloating(c), "the pointer was at the screen edge, but nobody saw a drop")
  }

  // MARK: Native tabs

  @Test func aNewTabTakesOverTheSlotOfTheWindowItCovers() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    let leaf = h.workspace.tree.leaf(containing: a)
    h.system.clearFrameLog()
    let tab = h.system.openTab(in: a)!
    #expect(h.workspace.tree.leaf(containing: tab) == leaf)
    #expect(!h.workspace.contains(a), "no ghost of the covered tab stays in the tree")
    #expect(h.frame(tab) == slot)
    #expect(h.system.frameLog.isEmpty, "nothing has to move")
    #expect(h.workspace.tree.allWindows.sorted() == [b, tab].sorted())
  }

  /// Terminal keeps its rows, so its window grows by the tab bar at the first ⌘T.
  @Test func aTabThatOpensTallerThanTheSlotIsFittedToIt() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    let neighbour = h.frame(b)!
    let tab = h.system.openTab(in: a, grownBy: 31)!
    #expect(h.workspace.isDocked(tab) && !h.workspace.contains(a))
    #expect(h.frame(tab) == slot)
    #expect(h.frame(b) == neighbour)
    #expect(h.layout?.tiles.isEmpty == true)
  }

  @Test func switchingBackAndForthBetweenTabsKeepsTheSlot() {
    let (h, a, _) = makeHarness()
    let leaf = h.workspace.tree.leaf(containing: a)
    let tab = h.system.openTab(in: a)!
    h.system.selectTab(a, insteadOf: tab)
    #expect(h.workspace.tree.leaf(containing: a) == leaf)
    #expect(!h.workspace.contains(tab))
    h.system.selectTab(tab, insteadOf: a)
    #expect(h.workspace.tree.leaf(containing: tab) == leaf)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func closingTheTabInFrontLeavesTheSlotToTheNextTab() {
    let (h, a, b) = makeHarness()
    let slot = h.frame(a)!
    let tab = h.system.openTab(in: a)!
    h.system.closeTab(tab, revealing: a)
    #expect(h.workspace.tree.allWindows.sorted() == [a, b].sorted())
    #expect(h.frame(a) == slot)
  }

  @Test func aTabOfAFloatingWindowFloatsInItsPlace() {
    let (h, _, _) = makeHarness()
    let c = h.system.open(app: "Finder", pid: 3000, frame: CGRect(x: 620, y: 300, width: 200, height: 150))
    let tab = h.system.openTab(in: c)!
    #expect(h.workspace.isFloating(tab) && !h.workspace.contains(c))
    #expect(h.workspace.floating[tab] == CGRect(x: 620, y: 300, width: 200, height: 150))
  }

  @Test func theCameraAndSavedViewsOnATabbedWindowSurviveATabSwitch() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    let tab = h.system.openTab(in: a)!
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: tab))
    #expect(h.frame(tab) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!h.system.isVisible(b))
    h.run("show-all")
    #expect(h.run("view 1").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: tab))
  }

  /// "Merge All Windows": a docked window becomes a tab behind another docked window, and is chosen later.
  @Test func aTabThatStillHadAPlaceOfItsOwnGivesItUp() {
    let (h, a, b) = makeHarness()
    // Notes' window was merged behind Safari's (never mind the apps) and left the list.
    h.system.setOnActiveSpace(b, false)
    h.scheduler.runPending()
    let leaf = h.workspace.tree.leaf(containing: a)
    var snapshot = h.controller.windows[b]!
    snapshot.isOnActiveSpace = true
    snapshot.frame = h.frame(a)!
    h.controller.windowReplaced(a, by: snapshot)
    #expect(h.workspace.tree.allWindows == [b])
    #expect(h.workspace.tree.leaf(containing: b) == leaf || h.workspace.tree.allWindows.count == 1)
  }

  // MARK: Odd orders and bad moments

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

  @Test func aTabChangeOnTheSecondDisplayStaysThere() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let a = h.system.open(app: "Terminal", pid: 1000, frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    let tab = h.system.openTab(in: a)!
    #expect(h.controller.workspaceID(containing: tab) == Self.side.id)
    #expect(h.controller.workspaces[Self.side.id]!.isDocked(tab))
    #expect(h.frame(tab) == slot)
    #expect(h.controller.workspaceID(containing: a) == nil)
  }

  @Test func aTabOfAnExcludedAppIsLeftAloneLikeItsWindow() {
    let (h, a, _) = makeHarness()
    h.run("exclude com.example.safari")
    h.system.clearFrameLog()
    let tab = h.system.openTab(in: a)!
    #expect(h.controller.workspaceID(containing: tab) == nil)
    #expect(h.system.frameLog.filter { $0.window == tab }.isEmpty)
  }

  @Test func aReplacementForAWindowArborNeverHeardOfIsANewWindow() {
    let (h, _, _) = makeHarness()
    let snapshot = WindowSnapshot(
      id: WindowID(900), pid: 4000, bundleID: "com.example.finder", appName: "Finder", title: "Downloads",
      frame: CGRect(x: 640, y: 300, width: 200, height: 150))
    h.controller.windowReplaced(WindowID(899), by: snapshot)
    #expect(h.workspace.isFloating(WindowID(900)))
    h.controller.windowReplaced(WindowID(900), by: snapshot)
    #expect(h.workspace.isFloating(WindowID(900)), "a window cannot replace itself")
  }

  @Test func aTabChangeBeforeArborHasStartedIsOnlyNoted() {
    let h = Harness()
    let a = h.system.open(app: "Terminal")
    let tab = h.system.openTab(in: a)!
    h.start()
    #expect(h.workspace.isFloating(tab))
    #expect(!h.workspace.contains(a))
  }

  @Test func aTabChangeInTheMiddleOfADragEndsTheDrag() {
    let (h, a, _) = makeHarness()
    h.controller.dragBegan(a, at: CGPoint(x: 300, y: 50))
    h.controller.dragMoved(a, to: CGPoint(x: 1438, y: 400))
    let tab = h.system.openTab(in: a)!
    #expect(h.overlays.preview == nil)
    h.controller.dragEnded(a, at: CGPoint(x: 1438, y: 400))
    #expect(h.workspace.isDocked(tab))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// `dock beside` rules go by which of an app's windows was focused last.
  @Test func whatIsRememberedAboutTheFocusFollowsTheTab() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.slack", action: .dockBeside(bundleID: "com.example.mail", .bottom))]
    let h = Harness(settings: settings)
    let first = h.system.open(app: "Mail")
    let second = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(first.rawValue) left")
    h.run("dock \(second.rawValue) right")
    h.system.userFocus(second)
    h.system.userFocus(first)
    let tab = h.system.openTab(in: first)!
    let slack = h.system.open(app: "Slack")
    #expect(abs(h.frame(slack)!.minX - h.frame(tab)!.minX) < 1, "beside the tab that took over, not the other window")
    #expect(h.frame(slack)!.minY > h.frame(tab)!.maxY)
  }

  @Test func cancellingADragThatIsNotGoingOnDoesNothing() {
    let (h, a, b) = makeHarness()
    h.system.clearFrameLog()
    h.controller.dragCancelled(a)
    h.controller.dragBegan(a, at: CGPoint(x: 300, y: 50))
    h.controller.dragCancelled(b)
    #expect(h.system.frameLog.isEmpty)
    h.system.close(a)
    h.controller.dragCancelled(a)
    #expect(h.workspace.tree.allWindows == [b])
  }

  @Test func aWindowThatClosesWhileItsAppHangsIsForgotten() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("zoom \(a.rawValue)")
    h.system.close(b)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.tree.allWindows == [a])
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func quittingWhileAnAppHangsDoesNotStopTheOthersFromComingBack() {
    let (h, a, b) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 620, y: 300, width: 200, height: 150))
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    h.system.setUnresponsive(pid: 2000, true)
    h.controller.shutdown()
    #expect(h.system.isVisible(a) && h.system.isVisible(c))
  }

  // MARK: A pause while an app hangs (K003, the half that Arbor lives to see)

  /// Safari framed, Notes out of view and hung, and then a pause.
  func pausedWithNotesHung() -> (Harness, WindowID, WindowID) {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.run("pause")
    return (h, a, b)
  }

  /// A pause promises every window in view, and Arbor stops listening: nobody would hear the app wake.
  @Test func aWindowThatCouldNotComeBackAtThePauseComesBackWhenItsAppWakes() {
    let (h, _, b) = pausedWithNotesHung()
    #expect(!h.system.isVisible(b), "nothing can be done about it yet")
    h.scheduler.advance(by: 5)
    #expect(!h.system.isVisible(b))
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 10)
    #expect(h.system.isVisible(b))
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "where it floated before it was docked")
    #expect(h.controller.isPaused && !h.system.started, "and the pause goes on")
  }

  /// An app that hangs carries out, when it wakes, what it was asked meanwhile, for as long as whoever asked is alive, which during a pause
  /// Arbor is. So the pause leaves word, and the window is back when its app wakes, not at the next try, which may be half a minute
  /// away.
  @Test func itIsBackTheMomentItsAppWakes() {
    let (h, _, b) = pausedWithNotesHung()
    h.scheduler.advance(by: 20)
    #expect(!h.system.isVisible(b))
    h.system.setUnresponsive(pid: 2000, false)
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "where it floated before it was docked, in its own size")
    h.scheduler.advance(by: 60)
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "and the tries that were still to come leave it there")
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
  }

  /// A window its person keeps most of the way over an edge, where a hand can still get hold of it, is theirs there, and a pause gives it back
  /// exactly there. So does the word: the first place that is asked for is the considered one, though less than half of it is in view.
  @Test(arguments: [0.0, 60.0]) func aWindowItsPersonKeepsOverAnEdgeIsBackExactlyThere(beforeTheResume: Double) throws {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    let aside = CGRect(x: 1312, y: 500, width: 400, height: 300)
    h.system.userMove(c, to: aside)
    h.scheduler.advance(by: 2)
    h.run("zoom \(a.rawValue)")
    try #require(h.frame(c) != aside, "out of view with the Desktop")
    h.system.setUnresponsive(pid: 3000, true)
    h.run("pause")
    h.scheduler.advance(by: 3)
    h.system.setUnresponsive(pid: 3000, false)
    #expect(h.frame(c) == aside, "the moment its app wakes")
    h.scheduler.advance(by: beforeTheResume)
    #expect(h.frame(c) == aside, "and no try takes it elsewhere")
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.floating[c] == aside)
  }

  /// A start takes a floating window that is found elsewhere than Arbor left it for one that somebody has touched
  /// (Controller+FoundAtAStart.swift), and the pause left this one in the corner. What the word then does is still the pause's doing,
  /// whether or not a try has looked at the window since. Pushed aside by hand to where nobody could get hold of it again (20 points show), so
  /// that where it is fetched to is not where it is remembered.
  @Test(arguments: [0.0, 60.0]) func whatTheWordBroughtBackIsNobodysDoing(beforeTheResume: Double) throws {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    let aside = CGRect(x: 1420, y: 500, width: 400, height: 300)
    h.system.userMove(c, to: aside)
    h.scheduler.advance(by: 2)
    try #require(h.workspace.floating[c] == aside)
    h.run("zoom \(a.rawValue)")
    try #require(!h.system.isVisible(c))
    h.system.setUnresponsive(pid: 3000, true)
    h.run("pause")
    h.scheduler.advance(by: 3)
    h.system.setUnresponsive(pid: 3000, false)
    try #require(h.system.isVisible(c) && h.frame(c) != aside, "fetched by the word, further in than it is remembered")
    h.scheduler.advance(by: beforeTheResume)
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.floating[c] == aside)
  }

  /// Nor does it pass for somebody's at the next launch, if Arbor is quit during the pause before a try has looked.
  @Test func whatTheWordBroughtBackIsNobodysDoingAfterAQuitEither() throws {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    let aside = CGRect(x: 1420, y: 500, width: 400, height: 300)
    h.system.userMove(c, to: aside)
    h.scheduler.advance(by: 2)
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 3000, true)
    h.run("pause")
    h.scheduler.advance(by: 3)
    h.system.setUnresponsive(pid: 3000, false)
    try #require(h.system.isVisible(c) && h.frame(c) != aside)
    h.controller.shutdown()
    let next = h.newProcess()
    next.start()
    next.scheduler.advance(by: 2)
    #expect(next.workspace.floating[c] == aside)
  }

  /// Somebody who moves it on from there has touched it.
  @Test(arguments: [0.0, 60.0]) func whatItsPersonMovedOnFromThereIsTheirs(beforeTheResume: Double) throws {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.system.userMove(c, to: CGRect(x: 1420, y: 500, width: 400, height: 300))
    h.scheduler.advance(by: 2)
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 3000, true)
    h.run("pause")
    h.scheduler.advance(by: 3)
    h.system.setUnresponsive(pid: 3000, false)
    let theirs = CGRect(x: 200, y: 150, width: 400, height: 300)
    h.system.userMove(c, to: theirs)
    h.scheduler.advance(by: beforeTheResume)
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.floating[c] == theirs)
  }

  /// Notes begins to hang a moment before the view leaves it out, so the move out of view is sent to it, and lies in its queue. Then a
  /// pause. The window server shows the window in view for as long as the app hangs, so the pause's tries strike it off their list; and
  /// when the app woke it went out of view, for the rest of the pause. The word left at the pause lies behind that move in the queue.
  @Test func aMoveOutOfViewThatLiesInAHungAppsQueueDoesNotOutlastThePause() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true, havingJustAnswered: true)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.isVisible(b), "nothing has come of it yet")
    #expect(h.system.askedInVain.map(\.window) == [b], "but it was sent")
    h.run("pause")
    h.scheduler.advance(by: 5)
    #expect(h.system.isVisible(b))
    h.system.setUnresponsive(pid: 2000, false)
    #expect(h.system.isVisible(b), "a pause promises every window in view")
    h.scheduler.advance(by: 120)
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "where it floated before it was docked")
    #expect(h.controller.isPaused && !h.system.started, "and the pause goes on")
  }

  /// The last thing that was asked of a hung app's window may have been to go out of view. That is never left as word.
  @Test func noWordIsLeftThatWouldSendAWindowOutOfView() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.isVisible(b), "it could not be sent out of view")
    h.run("pause")
    let screen = FakeWindowSystem.standardDisplay.frame
    let outOfView = h.system.askedInVain.filter { !screen.contains($0.frame) }
    #expect(outOfView.isEmpty, "\(outOfView)")
    h.system.setUnresponsive(pid: 2000, false)
    #expect(h.system.isVisible(b))
  }

  /// While Arbor runs it places the window itself when the app wakes, as ever: nothing happens behind its back.
  @Test func noWordIsLeftWhileArborRuns() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.run("back")
    h.run("zoom \(a.rawValue)")
    #expect(h.system.askedInVain.isEmpty, "\(h.system.askedInVain)")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(!h.system.isVisible(b), "the view frames Safari, whatever was asked of Notes in between")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Nor by the tries during the pause, each of which starts the window system and stops it again.
  @Test func theTriesLeaveNoFurtherWord() {
    let (h, _, b) = pausedWithNotesHung()
    #expect(h.system.askedInVain.map(\.window) == [b])
    h.scheduler.advance(by: 60)
    #expect(h.system.askedInVain.map(\.window) == [b], "\(h.system.askedInVain)")
  }

  @Test func whatWasAskedOfAWindowThatHasClosedSinceIsForgotten() {
    let (h, _, b) = pausedWithNotesHung()
    #expect(h.system.askedInVain.map(\.window) == [b])
    h.system.close(b)
    h.system.setUnresponsive(pid: 2000, false)
    #expect(h.system.askedInVain.isEmpty, "\(h.system.askedInVain)")
  }

  /// An app can beachball for minutes.
  @Test func anAppThatHangsForMinutesIsStillWaitedFor() {
    let (h, _, b) = pausedWithNotesHung()
    h.scheduler.advance(by: 240)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 40)
    #expect(h.system.isVisible(b))
  }

  /// Each try makes Arbor wait for the app, so they come further and further apart, and end.
  @Test func theTriesComeFurtherApartAndEnd() {
    let (h, _, b) = pausedWithNotesHung()
    var tries: [Double] = []
    let began = h.scheduler.now
    h.system.willSetFrame = { window, _ in if window == b { tries.append(h.scheduler.now - began) } }
    h.scheduler.advance(by: 60)
    #expect(tries.count >= 4 && tries.count <= 8, "\(tries)")
    #expect(zip(tries, tries.dropFirst()).allSatisfy { $1 - $0 >= 1 }, "\(tries)")
    h.scheduler.advance(by: 3600)
    let all = tries.count
    h.scheduler.advance(by: 3600)
    #expect(tries.count == all, "it gives up in the end: \(tries.count)")
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
  }

  @Test func resumingEndsTheWaitAndArrangesTheWindowAsEver() {
    let (h, _, b) = pausedWithNotesHung()
    h.run("resume")
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 2)
    expectWindowsMatchLayout(h, on: h.display)
    h.run("home")
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(b))
  }

  /// Mission Control, or the app itself on waking: it is in view, wherever, and that is all that was owed.
  @Test func aWindowSomebodyElseBroughtBackMeanwhileIsLeftWhereItIs() {
    let (h, _, b) = pausedWithNotesHung()
    h.system.setUnresponsive(pid: 2000, false)
    let chosen = CGRect(x: 700, y: 400, width: 500, height: 300)
    h.system.userMove(b, to: chosen)
    h.scheduler.advance(by: 60)
    #expect(h.frame(b) == chosen)
  }

  @Test func aWindowThatClosesWhileItIsWaitedForIsForgotten() {
    let (h, _, b) = pausedWithNotesHung()
    h.system.quit(pid: 2000)
    h.scheduler.advance(by: 5)
    #expect(h.system.frame(of: b) == nil)
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
  }

  /// With nothing owed a pause costs nothing: no timer runs.
  @Test func anOrdinaryPauseWaitsForNothing() {
    let (h, a, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("pause")
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("could-not-come-back") }, "\(h.scheduler.pendingKeys)")
  }

  // MARK: A quit while an app hangs (K003, the half that Arbor does not live to see: still open)

  /// macOS drops what a dead process asked (seen on a hosted Mac), so word left at a quit brings nothing back. None is left: it would
  /// cost two tenths of a second a window.
  @Test func aQuitLeavesNoWordBecauseNobodyWouldCarryItOut() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.controller.shutdown()
    #expect(h.system.askedInVain.isEmpty, "\(h.system.askedInVain)")
    h.system.arborsProcessEnded()
    h.system.setUnresponsive(pid: 2000, false)
    #expect(!h.system.isVisible(b), "the known problem: it is still out of view")
  }

  /// Nor does the word left at a pause outlive Arbor.
  @Test func aQuitDuringThePauseTakesTheWordWithIt() {
    let (h, _, b) = pausedWithNotesHung()
    h.controller.shutdown()
    h.system.arborsProcessEnded()
    h.system.setUnresponsive(pid: 2000, false)
    #expect(!h.system.isVisible(b), "the known problem: it is still out of view")
  }

  /// The good side of the same fact: a move out of view that lies in a hung app's queue when Arbor quits is never carried out. This pins what
  /// the stand-in says. On a Mac only calls that fetch were measured; that a move out of view is dropped like them is taken from that.
  @Test func aMoveOutOfViewThatLiesInAHungAppsQueueDiesWithArbor() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true, havingJustAnswered: true)
    h.run("zoom \(a.rawValue)")
    #expect(h.system.askedInVain.map(\.window) == [b])
    h.controller.shutdown()
    h.system.arborsProcessEnded()
    h.system.setUnresponsive(pid: 2000, false)
    #expect(h.system.isVisible(b))
  }

  /// The log used to say "all windows returned to view" whatever had happened.
  @Test func whatCouldNotComeBackIsSaid() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.controller.shutdown()
    #expect(h.controller.lastWords == "stopped; 1 window(s) could not be returned to view, their apps do not answer: \(b)")
    let (awake, c, _) = makeHarness()
    awake.run("zoom \(c.rawValue)")
    awake.controller.shutdown()
    #expect(awake.controller.lastWords == "stopped; all windows returned to view")
  }

  /// Arbor is gone when the app wakes. What the release notes say about it has to be true.
  @Test func afterAQuitWhileAnAppHungOpeningArborAgainFindsItsWindow() {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.controller.shutdown()
    h.system.setUnresponsive(pid: 2000, false)
    #expect(!h.system.isVisible(b), "the known problem: it is still out of view")
    h.start()
    h.scheduler.advance(by: 2)
    #expect(h.workspace.contains(b), "Arbor knows it again")
    h.run("home")
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(b))
    h.controller.shutdown()
    #expect(h.system.isVisible(a) && h.system.isVisible(b), "and this time a quit brings it back")
  }

  // MARK: A window that was to get its own frame back while its app did not answer

  /// Float All gives every window its own earlier frame back. One whose app hangs at that moment is in view, in the shape of its slot, and
  /// floats: no layout has a place for it, so nothing ever moved it again, and a second Float All said "nothing is docked".
  @Test func aWindowFloatedWhileItsAppHangsGetsItsOwnFrameBackWhenItWakes() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("float-all")
    #expect(h.frame(a) == CGRect(x: 100, y: 100, width: 600, height: 400))
    #expect(h.frame(b) != CGRect(x: 300, y: 200, width: 600, height: 400), "nothing can be done about it yet")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 2)
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "its own frame, as Float All promises")
  }

  /// Three windows of an app that takes longer over a move than Arbor waits: the first move goes on behind Arbor's back, the others find
  /// the app busy and are turned away.
  func threeDockedWindowsOfASlowApp() -> (Harness, [WindowID], [CGRect]) {
    let h = Harness()
    let own = (0..<3).map { CGRect(x: 100 + 60 * $0, y: 100 + 50 * $0, width: 500, height: 300) }
    let windows = own.map { h.system.open(app: "Notes", pid: 2000, frame: $0) }
    h.start()
    h.run("arrange")
    h.scheduler.advance(by: 1)
    h.system.slowApps = [2000]
    return (h, windows, own)
  }

  @Test(arguments: ["float-all", "undo"]) func theWindowsOfASlowAppAllGetTheirOwnFramesBack(_ way: String) {
    let (h, windows, own) = threeDockedWindowsOfASlowApp()
    h.run(way)
    for _ in 0..<8 {
      h.system.slowAppsFinish()
      h.scheduler.advance(by: 1)
    }
    #expect(windows.map { h.frame($0) } == own, "\(way)")
  }

  /// What is owed is the frame that was asked for then. Whoever has moved the window since has the last word.
  @Test func aWindowItsPersonHasMovedMeanwhileIsOwedNothing() {
    let (h, _, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("float-all")
    // The window server moves the window of an app that hangs, too.
    let chosen = CGRect(x: 640, y: 380, width: 464, height: 851).offsetBy(dx: 0, dy: -340)
    h.system.userMove(b, to: chosen)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 5)
    #expect(h.frame(b) == chosen)
  }

  /// The view has gone to a docked window meanwhile and leaves what floats out. What the window is owed then is the way out of view: paid its
  /// frame, it would show over the window that fills the view, unasked, and go away a moment later.
  @Test func whereTheViewLeavesFloatingWindowsOutTheFrameIsNotPaidOverIt() {
    let (h, a, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("float-all")
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.system.clearFrameLog()
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 3)
    #expect(!h.system.isVisible(b), "\(String(describing: h.frame(b)))")
    #expect(h.system.frameLog.filter { $0.window == b }.count == 1, "one move, out of view: \(h.system.frameLog.filter { $0.window == b })")
    h.run("show-all")
    h.scheduler.advance(by: 1)
    #expect(h.frame(b) == CGRect(x: 300, y: 200, width: 600, height: 400), "and it comes back to its own frame, not to the shape of its slot")
  }

  /// Nor is one that has been docked again.
  @Test func aWindowDockedAgainMeanwhileIsOwedNothing() {
    let (h, _, b) = makeHarness()
    h.system.setUnresponsive(pid: 2000, true)
    h.run("float-all")
    h.run("dock \(b.rawValue) left")
    let before = h.system.moveLog.count
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(b))
    expectWindowsMatchLayout(h, on: h.display)
    let own = CGRect(x: 300, y: 200, width: 600, height: 400)
    #expect(!h.system.moveLog[before...].contains { $0.window == b && $0.requested == own }, "not by way of the frame it floated in")
  }

  /// A move that is not answered is owed, whoever asked for it. Summon and pin took the window off the list of what is out of
  /// view before they knew that it had come back (bug bash 1).
  @Test func aWindowSummonedWhileItsAppHangsArrivesWhenItWakes() {
    let (h, a, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(c))
    h.system.setUnresponsive(pid: 3000, true)
    h.run("summon Mail")
    h.system.setUnresponsive(pid: 3000, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(c))
  }

  @Test func aCameraMoveGivesAStubbornWindowAnotherTry() {
    let (h, a, b) = makeHarness()
    h.system.stubbornFrames[a] = CGRect(x: 200, y: 150, width: 500, height: 300)
    for _ in 0..<8 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    h.system.stubbornFrames[a] = nil
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(a), "out of view like any other")
    h.run("back")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aStubbornWindowThatClosesLeavesNothingBehind() {
    let (h, a, b) = makeHarness()
    h.system.stubbornFrames[a] = CGRect(x: 200, y: 150, width: 500, height: 300)
    for _ in 0..<8 {
      h.system.appsSettle()
      h.scheduler.advance(by: 0.3)
    }
    h.system.stubbornFrames[a] = nil
    h.system.close(a)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.tree.allWindows == [b])
    expectWindowsMatchLayout(h, on: h.display)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce") })
  }

  @Test func aFloatingWindowThatMovesItselfIsNobodysBusiness() {
    let (h, _, _) = makeHarness()
    let c = h.system.open(app: "Mail", pid: 3000, frame: CGRect(x: 620, y: 300, width: 200, height: 150))
    h.system.clearFrameLog()
    for step in 0..<6 {
      h.system.userMove(c, to: CGRect(x: 620 + step * 4, y: 300, width: 200, height: 150))
      h.scheduler.advance(by: 0.3)
    }
    #expect(h.system.frameLog.isEmpty)
  }
}
