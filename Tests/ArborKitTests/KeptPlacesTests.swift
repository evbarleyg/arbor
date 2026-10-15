import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What a person meets after an accident, a pause or a login: a pause that outlives a crash, and places kept
/// for windows that are not open yet, which the right window gets and which Arbor can tell about.
@Suite @MainActor struct KeptPlacesTests {
  let lifecycle = LifecycleTests()

  // MARK: A crash during a pause

  /// Safari and Notes docked, Safari zoomed in on (so Notes and Mail are out of view), then `pause`.
  func pausedHarness(_ pause: String = "pause") -> (h: Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let (h, a, b, c) = lifecycle.makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("zoom \(a.rawValue)").ok)
    #expect(h.controller.parked.contains(b))
    #expect(h.run(pause).ok)
    return (h, a, b, c)
  }

  /// The watchdog starts Arbor again `seconds` after the pause began.
  func restartAfterACrash(_ h: Harness, after seconds: Double = 0) -> Harness {
    let again = lifecycle.relaunch(after: h, saved: h.store.saved)
    let crashed = h.controller.now().addingTimeInterval(seconds)
    again.controller.now = { [scheduler = again.scheduler] in crashed.addingTimeInterval(scheduler.now) }
    again.controller.restartedAfterAccident = true
    return again
  }

  func frames(_ h: Harness) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
  }

  @Test func aCrashDuringAPauseComesBackPaused() {
    let (h, safari, notes, _) = pausedHarness()
    let before = frames(h)
    let again = restartAfterACrash(h)
    again.controller.apply(settings: .withGestures)  // which a pause switches off
    again.start()
    again.scheduler.advance(by: 5)
    #expect(again.controller.isPaused)
    #expect(!again.controller.isRunning)
    #expect(frames(again) == before, "the game, and everything else, stays where it is")
    #expect(again.run("status").message.hasPrefix("paused"))
    #expect(again.registeredShortcuts.allSatisfy { $0.command == .resume || $0.command == .togglePause })
    #expect(again.controller.inputSettings.gesturesEnabled == false)

    // And `resume` brings back what the pause interrupted.
    #expect(again.run("resume").ok)
    #expect(again.workspace.isDocked(safari) && again.workspace.isDocked(notes))
    #expect(again.controller.parked.contains(notes), "still zoomed in on Safari")
    #expect(again.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aPersonWhoStartsArborWantsItRunningWhateverTheFileSays() {
    let (h, safari, _, _) = pausedHarness()
    let again = lifecycle.relaunch(after: h, saved: h.store.saved)
    again.start()
    #expect(again.controller.isRunning)
    #expect(!again.controller.isPaused)
    #expect(again.workspace.isDocked(safari))
    again.controller.saveNow()
    #expect(again.store.saved?.pause == nil)
  }

  @Test func aTimedPauseEndsWhenItWasGoingToWhateverHappensMeanwhile() {
    let (h, _, notes, _) = pausedHarness("pause 10")
    let again = restartAfterACrash(h, after: 4 * 60)
    again.start()
    #expect(again.controller.isPaused)
    again.scheduler.advance(by: 5 * 60)
    #expect(again.controller.isPaused, "nine of the ten minutes")
    again.scheduler.advance(by: 61)
    #expect(again.controller.isRunning)
    #expect(again.controller.parked.contains(notes))

    // The Mac slept, or the watchdog was slow: the pause is over by the time Arbor is back.
    let late = restartAfterACrash(h, after: 11 * 60)
    late.start()
    #expect(late.controller.isRunning)
    #expect(!late.controller.isPaused)
  }

  @Test func aClockSetBackDoesNotStretchAPauseBeyondADay() {
    let (h, _, _, _) = pausedHarness("pause 10")
    let again = restartAfterACrash(h, after: -30 * 24 * 60 * 60)
    again.start()
    #expect(again.controller.isPaused)
    again.scheduler.advance(by: 24 * 60 * 60 + 1)
    #expect(again.controller.isRunning)
  }

  @Test func aSecondPauseReplacesTheSavedEndToo() {
    let (h, _, _, _) = pausedHarness("pause 10")
    #expect(h.store.saved?.pause?.until == h.controller.now().addingTimeInterval(600))
    #expect(h.run("pause").ok)
    #expect(h.store.saved?.pause != nil)
    #expect(h.store.saved?.pause?.until == nil, "until `resume`")
    #expect(h.run("pause 1").ok)
    #expect(h.store.saved?.pause?.until == h.controller.now().addingTimeInterval(60))
  }

  @Test func resumingAndQuittingLeaveNoPauseBehind() {
    let (h, _, _, _) = pausedHarness()
    #expect(h.store.saved?.pause != nil)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    #expect(h.store.saved?.pause == nil)
    // A crash a while later is an ordinary crash.
    let again = restartAfterACrash(h)
    again.start()
    #expect(again.controller.isRunning)
  }

  @Test func onlyTheFirstStartOfTheProcessFollowsTheSavedPause() {
    let (h, _, _, _) = pausedHarness()
    let again = restartAfterACrash(h)
    again.start()
    #expect(again.run("resume").ok)
    #expect(again.run("pause").ok)
    #expect(again.run("resume").ok, "`resume` starts Arbor, and must not read the pause it is ending")
    #expect(again.controller.isRunning)
  }

  @Test func aPauseForAnAppComesBackAsThatAppsPause() throws {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    let safari = h.system.open(app: "Safari")
    let game = h.system.open(app: "Game", bundleID: "com.example.game")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.system.userFocus(game)
    #expect(h.controller.isPausedForApp)
    #expect(h.store.saved?.pause == PersistedState.Pause(until: nil, forApp: true))

    func restart() -> Harness {
      let again = Harness(settings: settings, saved: h.store.saved)
      for window in h.system.allWindows() {
        again.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, frame: window.frame)
      }
      again.controller.restartedAfterAccident = true
      return again
    }
    // Still in the game: the app reports who is in front before it starts the controller.
    var again = restart()
    again.system.userFocus(game)
    again.start()
    #expect(again.controller.isPausedForApp)
    again.system.userFocus(safari)
    #expect(again.controller.isRunning, "leaving the game ends it, as ever")
    #expect(again.workspace.isDocked(safari))

    // The game went down with Arbor, or was left meanwhile.
    again = restart()
    again.system.userFocus(safari)
    again.start()
    #expect(again.controller.isRunning)
    #expect(!again.controller.isPaused)
  }

  @Test func aTimedPauseThatBecomesAnAppsPauseIsSavedAsOne() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    let game = h.system.open(app: "Game", bundleID: "com.example.game")
    h.start()
    h.system.userFocus(game)
    #expect(h.run("pause 1").ok)
    #expect(h.store.saved?.pause?.forApp == false)
    h.scheduler.advance(by: 61)
    #expect(h.controller.isPausedForApp)
    #expect(h.store.saved?.pause == PersistedState.Pause(until: nil, forApp: true))
  }

  @Test func logoutBringsEveryWindowIntoViewAndACancelledLogoutBringsArborBack() {
    let (h, a, b, _) = lifecycle.makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked.contains(b))
    h.controller.sessionIsEnding()
    #expect(h.controller.isPaused)
    for window in h.system.allWindows() { #expect(h.visibleFrame.contains(window.frame), "\(window.id)") }
    // Some app asked "save changes?", and the answer was Cancel.
    h.scheduler.advance(by: 121)
    #expect(h.controller.isRunning)
    #expect(h.controller.parked.contains(b))

    // It does not shorten a pause that someone asked for.
    #expect(h.run("pause").ok)
    h.controller.sessionIsEnding()
    h.scheduler.advance(by: 600)
    #expect(h.controller.isPaused)
  }

  /// Where "a logout is a pause" met F48 (a pause did not touch what is in view then): apps save their windows' frames as they
  /// quit, and would have saved the shapes of slots.
  @Test func atLogoutEveryWindowIsAsAQuitWouldLeaveIt() {
    func desk() -> (Harness, [WindowID]) {
      let (h, a, b, c) = lifecycle.makeHarness()
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) right")
      return (h, [a, b, c])
    }
    let (h, windows) = desk()
    let (twin, _) = desk()
    h.controller.sessionIsEnding()
    twin.controller.shutdown()
    for window in windows { #expect(h.frame(window) == twin.frame(window), "\(window)") }
    #expect(h.frame(windows[0]) == CGRect(x: 100, y: 100, width: 600, height: 400), "its own size, where it floated")
    // macOS's request to quit follows, and finds nothing left to do.
    let moves = h.system.moveLog.count
    h.controller.shutdown()
    #expect(h.system.moveLog.count == moves)

    // Cancelled: the arrangement comes back.
    let (again, all) = desk()
    let docked = all.prefix(2)
    let before = docked.map { again.frame($0) }
    again.controller.sessionIsEnding()
    again.scheduler.advance(by: 121)
    #expect(again.controller.isRunning)
    #expect(docked.map { again.frame($0) } == before)
    #expect(again.system.isVisible(all[2]), "what floats is where a launch would find it")
  }

  @Test func filesFromBeforePausesWereSavedStillLoad() throws {
    let (h, _, _, _) = pausedHarness("pause 10")
    let saved = try #require(h.store.saved)
    let data = try JSONEncoder().encode(saved)
    #expect(try JSONDecoder().decode(PersistedState.self, from: data) == saved)
    var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object.removeValue(forKey: "pause") != nil)
    let old = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.pause == nil)
    #expect(old.workspaces == saved.workspaces)
  }

  // MARK: Who gets a kept place

  /// After a reboot, with Notes already back and Safari's place waiting.
  func waitingForSafari() -> (h: Harness, safari: WindowSnapshot, notes: WindowID) {
    let (saved, _, safari, notes) = lifecycle.savedPair()
    let h = Harness(saved: saved)
    for _ in 0..<4 { h.system.open(app: "Filler") }  // so that nobody gets a saved number
    let newNotes = lifecycle.reopen(notes, in: h)
    h.start()
    h.scheduler.advance(by: 1)
    return (h, safari, newNotes)
  }

  @Test func theWindowWithTheSavedTitleTakesThePlaceOverFromTheOneThatCameFirst() {
    let (h, safari, notes) = waitingForSafari()
    // "Welcome to Xcode", a sign-in sheet, a what's-new window: what an app shows first is often not
    // what it was showing.
    let welcome = lifecycle.reopen(safari, in: h, title: "Welcome")
    #expect(h.workspace.isDocked(welcome), "the app's only window takes its only place, for now")
    h.scheduler.advance(by: 3)
    let real = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isDocked(real))
    #expect(h.frame(real)!.maxX < h.frame(notes)!.minX, "on the left, where it was")
    #expect(h.workspace.isFloating(welcome))
    #expect(!h.workspace.isDocked(welcome))
    #expect(h.frame(welcome) == CGRect(x: 200, y: 150, width: 500, height: 300), "back where it opened")
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(Set(h.workspace.tree.allWindows) == [real, notes])
    // Once only.
    let twin = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isFloating(twin))
    #expect(h.workspace.isDocked(real))
  }

  @Test func aWindowThatIsRenamedToTheSavedTitleTakesThePlaceOverToo() {
    let (h, safari, _) = waitingForSafari()
    let welcome = lifecycle.reopen(safari, in: h, title: "Welcome")
    let real = lifecycle.reopen(safari, in: h, title: "")
    #expect(h.workspace.isFloating(real))
    h.system.setTitle(real, safari.title)
    #expect(h.workspace.isDocked(real))
    #expect(h.workspace.isFloating(welcome))
  }

  @Test func theFirstWindowKeepsThePlaceOnceItHasTheSavedTitleOrTheWaitIsOver() {
    var (h, safari, _) = waitingForSafari()
    var first = lifecycle.reopen(safari, in: h, title: "Loading")
    h.system.setTitle(first, safari.title)
    var second = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isDocked(first), "it was the right window all along")
    #expect(h.workspace.isFloating(second))

    (h, safari, _) = waitingForSafari()
    first = lifecycle.reopen(safari, in: h, title: "Another page")
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    second = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isDocked(first), "minutes later, a window with that title is a new window")
    #expect(h.workspace.isFloating(second))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
  }

  @Test func aPlaceTheUserHasSinceDecidedAboutIsNotTakenOver() {
    var (h, safari, _) = waitingForSafari()
    var first = lifecycle.reopen(safari, in: h, title: "Another page")
    #expect(h.run("float \(first.rawValue)").ok)
    var second = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isFloating(first) && h.workspace.isFloating(second), "the place is gone")

    (h, safari, _) = waitingForSafari()
    first = lifecycle.reopen(safari, in: h, title: "Another page")
    #expect(h.run("arrange").ok)
    second = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isDocked(first) && h.workspace.isFloating(second))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func thePlaceWaitsAgainIfTheWindowThatCameFirstCloses() {
    // A welcome window often closes just before the real one opens.
    let (h, safari, notes) = waitingForSafari()
    let welcome = lifecycle.reopen(safari, in: h, title: "Welcome")
    #expect(h.workspace.isDocked(welcome))
    h.system.close(welcome)
    #expect(h.layout?.windowFrames.keys.sorted() == [notes], "a waiting place takes no space")
    #expect(h.run("status").message.contains("1 place kept"))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    let real = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isDocked(real))
    #expect(h.frame(real)!.maxX < h.frame(notes)!.minX)

    // But no longer than it would have waited anyway.
    let (late, _, _) = waitingForSafari()
    let other = lifecycle.reopen(safari, in: late, title: "Welcome")
    late.scheduler.advance(by: 100)
    late.system.close(other)
    late.scheduler.advance(by: 100)
    #expect(late.controller.snapshot().waiting.isEmpty)
    #expect(!late.scheduler.pendingKeys.contains("pending-slots"))
  }

  @Test func aPlaceOnAnUnpluggedDisplayIsTakenOverAsWell() {
    let (saved, safari, _) = lifecycle.savedPairOnTheSecondDisplay()
    let h = Harness(saved: saved)
    for _ in 0..<4 { h.system.open(app: "Filler") }
    h.start()
    let welcome = lifecycle.reopen(safari, in: h, title: "Welcome")
    let real = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isFloating(welcome) && h.workspace.isFloating(real))
    let remembered = h.controller.dormant.values.flatMap(\.workspace.tree.allWindows)
    #expect(remembered.contains(real))
    #expect(!remembered.contains(welcome))
  }

  // MARK: Nothing moves by a timer

  /// The product owner's rule, from a day in a user's shoes: three minutes after login a place expired, Arbor laid out, and the
  /// floating window being typed in went somewhere else with nobody touching anything.
  @Test func aPlaceThatExpiresMovesNothing() {
    let (h, _, notes) = waitingForSafari()
    // Over docked space, where the app put it; a layout for a change of structure would push it onto the Desktop.
    let typing = h.system.open(app: "Xcode", frame: CGRect(x: 900, y: 40, width: 500, height: 600))
    h.scheduler.advance(by: 5)
    #expect(h.frame(typing) == CGRect(x: 900, y: 40, width: 500, height: 600), "a new window stays where its app put it")
    let frames = Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
    let (moves, focuses) = (h.system.moveLog.count, h.system.focusLog.count)
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.system.moveLog.count == moves)
    #expect(h.system.focusLog.count == focuses)
    #expect(Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) }) == frames)
    // It took no space, so it could go all the same.
    #expect(h.workspace.tree.allWindows == [notes])
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  /// `[ a | visitor | b | Desktop ]`: the visitor's room goes back to whoever gave it, which is not how an absent window's room
  /// is shared out. Its place cannot go without the others moving, so it goes with the next layout somebody causes.
  @Test func aPlaceWhoseGoingWouldMoveAWindowGoesWithTheNextLayoutSomebodyCauses() throws {
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let first = Harness(displays: [wide])
    let (a, b, v) = (first.system.open(app: "A"), first.system.open(app: "B"), first.system.open(app: "Visitor"))
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) beside \(a.rawValue) right")
    first.run("resize \(a.rawValue) right 200")
    first.run("dock \(v.rawValue) beside \(a.rawValue) right")
    first.controller.saveNow()

    let h = Harness(displays: [wide], saved: first.store.saved)
    h.system.open(app: "A")
    h.system.open(app: "B")
    h.start()
    h.scheduler.advance(by: 5)
    let frames = [h.frame(a), h.frame(b)]
    let moves = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 3)
    #expect(h.system.moveLog.count == moves, "nothing moves by a timer")
    #expect([h.frame(a), h.frame(b)] == frames)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    // Whichever it was: gone already, or waiting for this.
    h.run("show-all")
    h.run("relayout")
    #expect(Set(h.workspace.tree.allWindows) == [a, b])
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  // MARK: One window, one place

  /// Found by the chaos lab: after displays came and went around a crash, the file had a window docked on one display and
  /// still in the other's tree. Listed windows are guarded against that; one on a Space that is not showing was not.
  enum Twice: CaseIterable {
    /// In the trees of two displays, both connected.
    case onTwoDisplays
    /// On a display, and in what is remembered of one that is not connected.
    case rememberedElsewhere
    /// The same, and that display is connected again at launch.
    case rememberedOnADisplayThatIsBack
  }

  @Test(arguments: Twice.allCases) func aWindowOnAnotherSpaceThatTheFileHasTwiceKeepsOnePlace(how: Twice) throws {
    let both = [FakeWindowSystem.standardDisplay, LifecycleTests.second]
    let first = Harness(displays: both)
    let safari = first.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    first.start()
    first.run("dock \(safari.rawValue) left")
    first.controller.saveNow()
    var saved = try #require(first.store.saved)
    let (main, side) = (both[0].id, both[1].id)
    let twice = try #require(saved.workspaces[main])
    if how == .onTwoDisplays {
      saved.workspaces[side] = twice
    } else {
      saved.workspaces[side] = nil
      saved.dormant[side] = DormantWorkspace(workspace: twice, since: first.controller.now())
    }

    let h = Harness(displays: how == .rememberedElsewhere ? [both[0]] : both, saved: saved)
    #expect(h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400)) == safari)
    h.system.setListed(safari, false)
    h.start()
    func places() -> Int {
      (h.controller.workspaces.values.map(\.tree) + h.controller.dormant.values.map(\.workspace.tree))
        .filter { $0.allWindows.contains(safari) }.count
    }
    #expect(places() == 1)
    #expect(h.controller.snapshot().waiting.map(\.bundleID) == ["com.example.safari"], "and it still knows whom it waits for")
    h.system.setListed(safari, true)
    #expect(places() == 1)
    #expect(h.controller.workspaces[main]?.isDocked(safari) == true, "the first place keeps it")
    for workspace in h.controller.workspaces.values { #expect(workspace.tree.invariantViolations().isEmpty) }
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"), "nothing is left to wait for")
  }

  // MARK: After `resume`

  @Test func noPlaceIsKeptForAWindowClosedDuringAPause() {
    let (h, a, b, _) = lifecycle.makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let safari = h.controller.windows[a]!
    #expect(h.run("pause").ok)
    h.system.close(a)
    #expect(h.run("resume").ok)
    #expect(h.workspace.tree.allWindows == [b], "the arrangement, minus whatever was closed meanwhile")
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    let again = lifecycle.reopen(safari, in: h)
    #expect(h.workspace.isFloating(again), "a new window")
  }

  @Test func aWindowOnAnotherSpaceWhenThePauseEndsKeepsItsPlace() {
    let (h, a, b, _) = lifecycle.makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("pause").ok)
    h.system.setListed(a, false)
    #expect(h.run("resume").ok)
    #expect(h.workspace.isDocked(a))
    h.system.setListed(a, true)
    #expect(h.frame(a)!.maxX < h.frame(b)!.minX)
  }

  // MARK: Telling about it

  @Test func statusAndStateSayWhichPlacesAreKept() throws {
    let (h, safari, notes) = waitingForSafari()
    #expect(h.run("status").message.contains("1 place kept for a window that is not open yet"))
    // docs/MENU.md, state 8. A tooltip only where it says more than the line.
    let line = h.controller.menuModel().sections.first?.items.first
    #expect(line?.title == "1 place kept for a window that is not open yet" && line?.isEnabled == false && line?.help == nil)
    let state = h.controller.snapshot()
    #expect(state.waiting.count == 1)
    let slot = try #require(state.waiting.first)
    #expect(slot.bundleID == safari.bundleID)
    #expect(h.workspace.isDocked(slot.id))
    #expect(slot.display == h.system.displayList[0].id)
    #expect(!state.windows.contains { $0.id == slot.id })

    let decoded = try JSONDecoder().decode(StateSnapshot.self, from: JSONEncoder().encode(state))
    #expect(decoded.waiting == state.waiting)
    // The title the window had is told only to whoever asks for titles.
    #expect(slot.title == safari.title)
    #expect(h.run("state --titles").state?.waiting == state.waiting)
    #expect(h.run("state").state?.waiting.map(\.title) == [nil])

    _ = lifecycle.reopen(safari, in: h)
    #expect(!h.run("status").message.contains("kept for"))
    #expect(h.controller.snapshot().waiting.isEmpty)
    #expect(h.workspace.isDocked(notes))
  }

  @Test func statusCountsSeveralKeptPlaces() {
    let (saved, _, _) = lifecycle.savedPairOfOneApp()
    let h = Harness(saved: saved)
    h.start()
    #expect(h.run("status").message.contains("2 places kept for windows that are not open yet"))
  }
}
