import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Every way Arbor can end, and what it finds when it starts again: no window may stay out of view.
@Suite @MainActor struct LifecycleTests {
  /// Three floating windows, started.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  /// A new Arbor process that finds the windows of `h` exactly where they are now, under the same
  /// numbers, as after a crash or `kill -9`.
  func relaunch(after h: Harness, saved: PersistedState?) -> Harness {
    let again = Harness(displays: h.system.displayList, settings: h.controller.settings, saved: saved)
    for window in h.system.allWindows() {
      let id = again.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
      #expect(id == window.id)
      if window.isMinimized { again.system.setMinimized(id, true) }
    }
    return again
  }

  // MARK: Quitting

  @Test func quittingBringsBackParkedWindowsThatAreMinimized() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    // Minimized from the Dock or by its app while out of view.
    h.system.setMinimized(b, true)
    h.controller.shutdown()
    #expect(h.system.isVisible(b), "it would come out of the Dock off screen: \(h.frame(b)!)")
  }

  @Test func quittingBringsBackParkedWindowsOnOtherSpaces() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    for window in [a, b, c] { h.system.setOnActiveSpace(window, false) }
    h.scheduler.runPending()
    h.controller.shutdown()
    for window in [a, b, c] { #expect(h.system.isVisible(window), "\(window) \(h.frame(window)!)") }
  }

  @Test func quittingBringsBackAWindowThatIsOutOfViewWhateverTheBookkeepingSays() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.second])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1800, y: 200, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    // Parked, then minimized; then its display goes and comes back, after which Arbor no longer
    // counts it as parked, and moves nothing because a minimized window takes no space.
    h.system.setMinimized(b, true)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.second])
    #expect(!h.system.isVisible(b))
    h.controller.shutdown()
    #expect(h.system.isVisible(b), "\(h.frame(b)!)")
  }

  // MARK: Stopping and starting again in one process

  @Test func arborCanStopAndStartAgainAndSeesWhatChangedMeanwhile() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.controller.shutdown()
    #expect(!h.controller.isRunning)
    // Nobody tells a stopped Arbor anything: Notes closes, Mail moves, Calendar opens.
    h.system.setListed(b, false)
    h.system.close(b)
    h.system.setListed(c, false)
    h.system.setListed(c, true)
    let d = h.system.open(app: "Calendar")

    h.start()
    #expect(h.controller.isRunning)
    #expect(h.controller.windows.keys.sorted() == [a, c, d], "no memory of the window that closed")
    #expect(h.workspace.camera == h.workspace.tree.root, "a start after a quit shows everything")
    #expect(h.layout?.windowFrames.keys.sorted() == [a])
    expectWindowsMatchLayout(h)
    #expect(h.workspace.isFloating(d))
    for window in [a, c, d] { #expect(h.system.isVisible(window), "\(window)") }
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.workspace.tree.allWindows == [a])
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  // MARK: Starting after an unclean exit

  @Test func floatingWindowsLeftParkedByACrashComeBackWhenTheDesktopIsInView() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.controller.saveNow()
    let saved = h.store.saved
    // The camera moves and Arbor dies before the save half a second later.
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(c))

    let again = relaunch(after: h, saved: saved)
    again.start()
    #expect(again.layout?.desktopFrame != nil)
    #expect(again.system.isVisible(c), "\(again.frame(c)!)")
  }

  @Test(arguments: [false, true]) func aCrashWhileZoomedInKeepsTheArrangement(makingWay: Bool) {
    let (h, a, b, c) = makeHarness(settings: makingWay ? .makingWay : Settings())
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.controller.saveNow()

    let again = relaunch(after: h, saved: h.store.saved)
    again.start()
    #expect(again.workspace.tree == h.workspace.tree)
    #expect(again.system.isVisible(a))
    again.run("show-all")
    for window in [a, b, c] { #expect(again.system.isVisible(window), "\(window)") }
    // Where it was, to the point; or, where floating windows make way, as near to that as the Desktop allows.
    let own = CGRect(x: 500, y: 300, width: 600, height: 400)
    #expect(again.frame(c) == (makingWay ? own.fitted(into: again.layout!.desktopFrame!) : own))
  }

  @Test func aCrashIsRecoveredFromEvenIfADisplayWentAwayMeanwhile() {
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, second])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1800, y: 200, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    h.controller.saveNow()
    let tree = h.controller.workspaces[second.id]!.tree

    // Arbor dies, the display is unplugged, the watchdog starts Arbor again. (macOS would move the windows onto the
    // display that is left; the fake leaves them where they were, which is the harder case.)
    h.system.displayList = [FakeWindowSystem.standardDisplay]
    let again = relaunch(after: h, saved: h.store.saved)
    again.controller.restartedAfterAccident = true
    again.start()
    for window in [a, b] { #expect(again.system.isVisible(window), "\(window) \(again.frame(window)!)") }

    // And the arrangement is still there when the display comes back.
    again.system.setDisplays([FakeWindowSystem.standardDisplay, second])
    #expect(again.controller.workspaces[second.id]?.tree == tree)
    #expect(again.system.isVisible(a))
    #expect(!again.system.isVisible(b), "the camera is on Safari, as it was")
  }

  // MARK: Launching at login, before the apps have restored their windows

  /// Safari docked on the left and Notes on the right, saved; then a reboot, so every window is gone.
  func savedPair() -> (saved: PersistedState, tree: LayoutTree, safari: WindowSnapshot, notes: WindowSnapshot) {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    return (h.store.saved!, h.workspace.tree, h.controller.windows[a]!, h.controller.windows[b]!)
  }

  func reopen(_ window: WindowSnapshot, in h: Harness, title: String? = nil) -> WindowID {
    h.system.open(
      app: window.appName, bundleID: window.bundleID, title: title ?? window.title,
      frame: CGRect(x: 200, y: 150, width: 500, height: 300))
  }

  @Test func windowsRestoredAfterArborStartsReturnToTheirSlots() {
    let (saved, _, safari, notes) = savedPair()
    let h = Harness(saved: saved)
    // Numbers restart after a reboot: unrelated windows take the old ones.
    for _ in 0..<4 { h.system.open(app: "Filler") }
    let newNotes = reopen(notes, in: h)
    h.start()
    h.scheduler.advance(by: 1)  // the save after starting
    #expect(h.layout?.windowFrames.keys.sorted() == [newNotes])

    h.scheduler.advance(by: 20)
    let newSafari = reopen(safari, in: h)
    #expect(h.workspace.isDocked(newSafari))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(h.frame(newSafari)!.maxX < h.frame(newNotes)!.minX, "Safari is back on the left")
    #expect(h.frame(newSafari)!.minX == h.visibleFrame.minX + 12)
    #expect(Set(h.workspace.tree.allWindows) == [newSafari, newNotes])
  }

  /// Two Safari windows docked left and right, saved; then a reboot.
  func savedPairOfOneApp() -> (saved: PersistedState, left: WindowSnapshot, right: WindowSnapshot) {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "News")
    let b = h.system.open(app: "Safari", title: "Weather")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    return (h.store.saved!, h.controller.windows[a]!, h.controller.windows[b]!)
  }

  @Test func aRestoredWindowThatGetsItsTitleLateStillReturnsToItsSlot() {
    let (saved, _, right) = savedPairOfOneApp()
    let h = Harness(saved: saved)
    h.start()
    let window = reopen(right, in: h, title: "")
    #expect(h.workspace.isFloating(window), "which of Safari's two slots is not known yet")
    h.system.setTitle(window, right.title)
    #expect(h.workspace.isDocked(window))
    #expect(!h.workspace.isFloating(window))
    #expect(h.frame(window)!.maxX == h.visibleFrame.maxX - 12, "the one on the right")
  }

  @Test func aRestoredWindowWithAnotherTitleTakesItsAppsOnlySlot() {
    // Mail counts messages in its title, a chat app marks what is unread: titles rarely survive a reboot.
    let (saved, _, safari, notes) = savedPair()
    let h = Harness(saved: saved)
    for _ in 0..<4 { h.system.open(app: "Filler") }  // so that nobody gets a saved number
    let newNotes = reopen(notes, in: h, title: "Notes, 3 unread")
    h.start()
    #expect(h.workspace.isDocked(newNotes), "found at launch")
    let newSafari = reopen(safari, in: h, title: "Another page")
    #expect(h.workspace.isDocked(newSafari), "appeared later")
    #expect(h.frame(newSafari)!.maxX < h.frame(newNotes)!.minX)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    // The slot is taken: the next window of the app is an ordinary new window.
    let third = reopen(safari, in: h, title: "A third page")
    #expect(h.workspace.isFloating(third))
  }

  @Test func windowsWithOtherTitlesAreNotGuessedAtWhenTheirAppHasSeveralSlotsOrSeveralWindows() {
    let (two, left, _) = savedPairOfOneApp()
    var h = Harness(saved: two)
    h.start()
    let sport = reopen(left, in: h, title: "Sport")
    #expect(h.workspace.isFloating(sport), "two slots, no telling which")

    let (one, _, safari, _) = savedPair()
    h = Harness(saved: one)
    for _ in 0..<4 { h.system.open(app: "Filler") }  // so that nobody gets a saved number
    let first = reopen(safari, in: h, title: "Sport")
    let second = reopen(safari, in: h, title: "Travel")
    h.start()
    #expect(h.workspace.isFloating(first) && h.workspace.isFloating(second), "two windows, no telling which")
    // The one with the saved title still gets it.
    let third = reopen(safari, in: h)
    #expect(h.workspace.isDocked(third))
  }

  @Test func slotsNobodyComesBackToAreDroppedAfterAWhile() {
    let (saved, _, safari, notes) = savedPair()
    let h = Harness(saved: saved)
    let newNotes = reopen(notes, in: h)
    h.start()
    #expect(h.workspace.tree.allWindows.count == 2, "Safari's slot is kept")
    #expect(h.layout?.windowFrames.count == 1, "with nobody in it")
    let moves = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    // It has kept its room (Q16), and nothing moves by a timer: it goes with the next layout somebody causes.
    #expect(h.system.moveLog.count == moves)
    h.run("relayout")
    h.scheduler.advance(by: 1)
    #expect(h.workspace.tree.allWindows == [newNotes])
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(h.store.saved?.workspaces[h.display]?.tree.allWindows == [newNotes])
    #expect(h.store.saved?.hints.count == 1)
    // Too late: it is an ordinary new window now.
    let late = reopen(safari, in: h)
    #expect(h.workspace.isFloating(late))
  }

  @Test func aNewWindowThatReusesAWaitingSlotsOldNumberDoesNotTakeTheSlot() {
    let (saved, _, safari, _) = savedPair()
    let h = Harness(saved: saved)
    h.start()
    // The fake numbers windows from 101, which is Safari's old number.
    let other = h.system.open(app: "Calendar")
    #expect(other == safari.id)
    #expect(h.workspace.isFloating(other))
    #expect(!h.workspace.isDocked(other))
    let newSafari = reopen(safari, in: h)
    #expect(h.workspace.isDocked(newSafari))
  }

  @Test func waitingSlotsSurviveQuittingAndSettingsChanges() {
    let (saved, _, safari, _) = savedPair()
    let h = Harness(saved: saved)
    h.start()
    h.run("exclude com.example.other")
    h.controller.shutdown()

    let again = Harness(saved: h.store.saved)
    again.start()
    let newSafari = reopen(safari, in: again)
    #expect(again.workspace.isDocked(newSafari))
    #expect(again.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aPauseSilencesTheWaitAndResumingTakesItUpAgain() {
    let (saved, _, safari, _) = savedPair()
    // With the gestures on, whose zones have a timer of their own.
    let h = Harness(settings: .withGestures, saved: saved)
    h.start()
    h.scheduler.advance(by: 1)
    #expect(h.run("pause").ok)
    #expect(h.scheduler.pendingKeys.isEmpty, "\(h.scheduler.pendingKeys)")
    #expect(h.run("resume").ok)
    let newSafari = reopen(safari, in: h)
    #expect(h.workspace.isDocked(newSafari))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func arrangingOrFloatingEverythingGivesUpTheWaitingSlots() {
    for command in ["arrange", "float-all"] {
      let (saved, _, safari, notes) = savedPair()
      let h = Harness(saved: saved)
      let newNotes = reopen(notes, in: h)
      h.start()
      #expect(h.run(command).ok)
      #expect(Set(h.workspace.allWindows) == [newNotes], "\(command)")
      let newSafari = reopen(safari, in: h)
      #expect(h.workspace.isFloating(newSafari), "\(command)")
    }
  }

  @Test func aSavedWindowThatIsThereButNoLongerArrangedLeavesNoSlotWaiting() {
    // Safari was excluded while Arbor was not running (settings.json edited). Its window is open, under
    // its old number: there is nothing to wait for, and Arbor must leave it alone.
    for unplugged in [false, true] {
      let first = Harness(displays: [FakeWindowSystem.standardDisplay, Self.second])
      let a = first.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
      let b = first.system.open(app: "Notes", frame: CGRect(x: 1800, y: 200, width: 600, height: 400))
      first.start()
      first.run("dock \(a.rawValue) left")
      first.run("dock \(b.rawValue) right")
      first.controller.shutdown()
      if unplugged { first.system.displayList = [FakeWindowSystem.standardDisplay] }

      var settings = Settings()
      settings.excludedBundleIDs = ["com.example.safari"]
      let h = Harness(displays: first.system.displayList, settings: settings, saved: first.store.saved)
      for window in first.system.allWindows() {
        h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, frame: window.frame)
      }
      h.start()
      let tree = unplugged ? h.controller.dormant[Self.second.id]?.workspace.tree : h.controller.workspaces[Self.second.id]?.tree
      #expect(tree?.allWindows == [b], "unplugged: \(unplugged)")
      #expect(!h.scheduler.pendingKeys.contains("pending-slots"), "unplugged: \(unplugged)")
    }
  }

  @Test func anIgnoreRuleWinsOverAWaitingSlot() throws {
    let (saved, _, safari, _) = savedPair()
    var settings = Settings()
    settings.rules = [AppRule(app: safari.bundleID!, action: .ignore)]
    let h = Harness(settings: settings, saved: saved)
    h.start()
    let newSafari = reopen(safari, in: h)
    #expect(!h.workspace.contains(newSafari))
  }

  // MARK: Launching at login with a display unplugged

  static let second = DisplaySnapshot(
    id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)

  /// Safari and Notes docked on the second display, saved; then a reboot.
  func savedPairOnTheSecondDisplay() -> (saved: PersistedState, safari: WindowSnapshot, notes: WindowSnapshot) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.second])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1800, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    return (h.store.saved!, h.controller.windows[a]!, h.controller.windows[b]!)
  }

  @Test func windowsRestoredLateReturnToADisplayThatIsPluggedInLater() {
    let (saved, safari, notes) = savedPairOnTheSecondDisplay()
    let h = Harness(saved: saved)
    for _ in 0..<4 { h.system.open(app: "Filler") }
    h.start()
    h.scheduler.advance(by: 10)
    let newSafari = reopen(safari, in: h)
    let newNotes = reopen(notes, in: h, title: "Notes, edited")
    #expect(h.workspace.isFloating(newSafari) && h.workspace.isFloating(newNotes), "their display is not here")
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)

    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.second])
    let tree = h.controller.workspaces[Self.second.id]!.tree
    #expect(Set(tree.allWindows) == [newSafari, newNotes])
    #expect(tree.invariantViolations().isEmpty)
    #expect(h.frame(newSafari)!.minX == Self.second.visibleFrame.minX + 12)
    #expect(h.frame(newNotes)!.maxX == Self.second.visibleFrame.maxX - 12)
    #expect(!h.workspace.contains(newSafari) && !h.workspace.contains(newNotes))
  }

  @Test func slotsOnAnUnpluggedDisplayThatNobodyComesBackToAreDropped() {
    let (saved, safari, _) = savedPairOnTheSecondDisplay()
    let h = Harness(saved: saved)
    h.start()
    #expect(h.controller.dormant[Self.second.id]?.workspace.tree.allWindows.count == 2)
    let newSafari = reopen(safari, in: h)
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.controller.dormant[Self.second.id]?.workspace.tree.allWindows == [newSafari])
    #expect(h.store.saved?.hints.keys.sorted() == [newSafari])

    let nobody = Harness(saved: saved)
    nobody.start()
    nobody.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(nobody.controller.dormant.isEmpty, "nothing is left to remember")
    #expect(nobody.scheduler.pendingKeys.isEmpty)
  }

  @Test func aWindowThatHasItsPlaceOnAnUnpluggedDisplayDoesNotTakeItsTwinsSlotToo() {
    // Two windows of one app with one title, docked on the second display. Arbor restarts with the
    // display unplugged; one of the two was closed meanwhile.
    let first = Harness(displays: [FakeWindowSystem.standardDisplay, Self.second])
    let a = first.system.open(app: "Terminal", title: "zsh", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let b = first.system.open(app: "Terminal", title: "zsh", frame: CGRect(x: 1800, y: 200, width: 600, height: 400))
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    first.controller.saveNow()
    first.system.close(b)
    first.system.displayList = [FakeWindowSystem.standardDisplay]

    let h = relaunch(after: first, saved: first.store.saved)
    h.start()
    h.system.setTitle(a, "vim")
    h.system.setTitle(a, "zsh")
    let tree = h.controller.dormant[Self.second.id]!.workspace.tree
    #expect(tree.invariantViolations().isEmpty)
    #expect(tree.allWindows.count == 2 && tree.allWindows.contains(a))
    let twin = h.system.open(app: "Terminal", title: "zsh")
    #expect(Set(h.controller.dormant[Self.second.id]!.workspace.tree.allWindows) == [a, twin])
  }

  @Test func slotsGoOnWaitingWhenTheirDisplayComesOrGoesMeanwhile() {
    let (saved, safari, notes) = savedPairOnTheSecondDisplay()
    let h = Harness(saved: saved)
    h.start()
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.second])
    #expect(h.controller.workspaces[Self.second.id]?.tree.allWindows.count == 2, "the slots came back with the display")
    #expect(h.workspace.allWindows.isEmpty)
    let newSafari = reopen(safari, in: h)
    #expect(h.controller.workspaces[Self.second.id]?.isDocked(newSafari) == true)

    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.workspace.allWindows == [newSafari], "only the window that exists moves to the display that is left")
    let newNotes = reopen(notes, in: h)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.second])
    #expect(Set(h.controller.workspaces[Self.second.id]!.tree.allWindows) == [newSafari, newNotes])
    #expect(h.controller.workspaces[Self.second.id]!.tree.invariantViolations().isEmpty)
    h.controller.shutdown()
    for window in [newSafari, newNotes] { #expect(h.system.isVisible(window)) }
  }

  // MARK: Launching while saved windows are on another Space

  /// Arbor restarts (the apps do not) while Safari is on a Space that is not showing: the
  /// Accessibility API does not list it, but the window server still knows its number.
  func relaunchWithSafariOnAnotherSpace() -> (h: Harness, safari: WindowID, notes: WindowID) {
    let (first, a, b, _) = makeHarness()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    first.controller.saveNow()
    let h = relaunch(after: first, saved: first.store.saved)
    h.system.setListed(a, false)
    h.start()
    return (h, a, b)
  }

  @Test func aWindowOnAnotherSpaceAtLaunchKeepsItsSlotForAsLongAsItExists() {
    let (h, safari, notes) = relaunchWithSafariOnAnotherSpace()
    #expect(h.layout?.windowFrames.keys.sorted() == [notes])
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 5)
    #expect(h.workspace.isDocked(safari), "an hour later is as good as a second later")
    // Renamed meanwhile: it is the number that says it is the same window.
    h.system.setTitle(safari, "Another page")
    h.system.setListed(safari, true)
    #expect(h.layout?.windowFrames.keys.sorted() == [safari, notes])
    #expect(h.frame(safari)!.maxX < h.frame(notes)!.minX)
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.workspace.isDocked(safari))
  }

  @Test func aWindowClosedOnAnotherSpaceGivesUpItsSlot() {
    let (h, safari, notes) = relaunchWithSafariOnAnotherSpace()
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.workspace.isDocked(safari))
    h.system.close(safari)
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.workspace.tree.allWindows == [notes])
    #expect(h.scheduler.pendingKeys.isEmpty, "nothing is left to wait for")
  }

  @Test func aNumberThatTurnsOutToBelongToAnotherAppDoesNotTakeTheSlot() {
    // After a reboot the saved number exists again, on another Space, as somebody else's window.
    let (saved, _, safari, _) = savedPair()
    let h = Harness(saved: saved)
    let impostor = h.system.open(app: "Calendar")
    #expect(impostor == safari.id)
    h.system.setListed(impostor, false)
    h.start()
    h.system.setListed(impostor, true)
    #expect(h.workspace.isFloating(impostor))
    let newSafari = reopen(safari, in: h)
    #expect(h.workspace.isDocked(newSafari), "the slot still waits for Safari")
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aWindowThatAppearsOutOfViewIsBroughtIntoView() {
    // Parked by a run that crashed, on a Space that was not showing when Arbor started again.
    let h = Harness()
    let lost = h.system.open(app: "Mail", frame: CGRect(x: 1439, y: 899, width: 600, height: 400))
    h.system.setListed(lost, false)
    h.start()
    h.system.setListed(lost, true)
    #expect(h.system.isVisible(lost), "\(h.frame(lost)!)")
  }

  @Test func aLateRuleDoesNotSendARescuedWindowBackOutOfView() {
    // Left in the corner by a run that crashed, and closed there. Its app opens it again where it was. It is
    // brought into view and docked by a rule; then its title arrives and a better rule floats or
    // ignores it, which puts a window back where it opened. (A window that was open all along, on a Space
    // that was not showing, is found rather than opened, and rules do not dock it: F23.)
    for better in [RuleAction.float, .ignore] {
      var settings = Settings()
      settings.rules = [
        AppRule(app: "com.example.safari", title: "Login", action: better),
        AppRule(app: "com.example.safari", action: .dock(.left)),
      ]
      let h = Harness(settings: settings)
      h.start()
      let lost = h.system.open(app: "Safari", title: "", frame: CGRect(x: 1439, y: 899, width: 600, height: 400))
      #expect(h.workspace.isDocked(lost))
      h.system.setTitle(lost, "Login")
      #expect(!h.workspace.isDocked(lost))
      #expect(h.system.isVisible(lost), "\(better): \(h.frame(lost)!)")
    }
  }

  // MARK: Displays changing under parked windows

  @Test func parkedWindowsStayOutOfViewWhenADisplayAppearsBesideThem() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    // A second display is attached to the right, where the parked windows hang over the edge.
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1440, height: 1800),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1440, height: 1775), isMain: false)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, second])
    #expect(!h.system.isVisible(b), "\(h.frame(b)!)")
  }
}
