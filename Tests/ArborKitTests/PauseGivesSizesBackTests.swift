import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// "Quitting, Float All and pause give windows back their own earlier sizes, not just a visible position."
///
/// The desk is the one a day with real apps on a hosted Mac had reached when it pressed ⌃⌥⎋: a display of 1600 × 900,
/// two docked windows with the Desktop between them, and seven floating windows, four of them squeezed to stay on it.
@Suite @MainActor struct PauseGivesSizesBackTests {
  static let display = DisplaySnapshot(
    id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1600, height: 900),
    visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791), isMain: true)

  @MainActor struct Desk {
    let h: Harness
    let finder, safari, terminal, notes, mail, textEdit, calendar, settings, preview: WindowID
    /// Where each window was, and how large, before Arbor touched it.
    let own: [WindowID: CGRect]
    var all: [WindowID] { own.keys.sorted() }
    /// The windows Arbor has moved or resized.
    var touched: [WindowID] { all.filter { h.frame($0) != own[$0] } }
    func frames() -> [WindowID: CGRect] { Dictionary(uniqueKeysWithValues: all.map { ($0, h.frame($0)!) }) }
    /// How often each window has been moved since the log was cleared.
    func moves() -> [WindowID: Int] { h.system.frameLog.reduce(into: [:]) { $0[$1.window, default: 0] += 1 } }
  }

  func makeDesk(settings: Settings = Settings(), watchingThePermission: Bool = false) -> Desk {
    let h = Harness(displays: [Self.display], settings: settings)
    if watchingThePermission { h.watchAccessibility() }
    var own: [WindowID: CGRect] = [:]
    func open(_ app: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, atLeast: CGFloat = 0) -> WindowID {
      let frame = CGRect(x: x, y: y, width: width, height: height)
      let window = h.system.open(
        app: app, pid: Int32(2000 + own.count), frame: frame, minimumSize: CGSize(width: atLeast, height: 0))
      own[window] = frame
      return window
    }
    let finder = open("Finder", 340, 120, 920, 436)
    let safari = open("Safari", 138, 31, 1324, 791)
    let terminal = open("Terminal", 40, 51, 877, 499)
    let notes = open("Notes", 300, 105, 1000, 660, atLeast: 709)
    let mail = open("Mail", 240, 72, 1120, 630, atLeast: 871)
    let textEdit = open("TextEdit", 165, 65, 673, 439)
    let calendar = open("Calendar", 431, 86, 680, 598, atLeast: 680)
    let settingsWindow = open("System Settings", 410, 85, 723, 625, atLeast: 723)
    let preview = open("Preview", 417, 35, 708, 424, atLeast: 708)
    h.start()
    h.run("dock \(finder.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    // By then the gap between the Desktop and Safari had been moved.
    h.overlays.dragSeam(h.overlays.seams[h.display]![1], by: -57)
    h.system.userFocus(safari)
    return Desk(
      h: h, finder: finder, safari: safari, terminal: terminal, notes: notes, mail: mail, textEdit: textEdit,
      calendar: calendar, settings: settingsWindow, preview: preview, own: own)
  }

  /// To the point, but for Terminal, which was four points narrower there: it is as wide as whole letters.
  @Test func theDeskIsTheOneTheDayHadReached() {
    let desk = makeDesk()
    #expect(desk.h.workspace.isDocked(desk.finder) && desk.h.workspace.isDocked(desk.safari))
    #expect(desk.h.frame(desk.finder) == CGRect(x: 12, y: 43, width: 517, height: 767))
    #expect(desk.h.frame(desk.safari) == CGRect(x: 1014, y: 43, width: 574, height: 767))
    #expect(desk.h.frame(desk.terminal) == CGRect(x: 541, y: 51, width: 461, height: 499))
    #expect(desk.h.frame(desk.notes) == CGRect(x: 417, y: 105, width: 709, height: 660))
    #expect(desk.h.frame(desk.mail) == CGRect(x: 336, y: 72, width: 871, height: 630))
    #expect(desk.h.frame(desk.textEdit) == CGRect(x: 541, y: 65, width: 461, height: 439))
    expectWindowsMatchLayout(desk.h)
  }

  @Test func aPauseGivesEveryWindowItsOwnFrameBackInOneMove() {
    let desk = makeDesk()
    let touched = desk.touched
    desk.h.system.clearFrameLog()

    #expect(desk.h.press("toggle-pause").ok)
    for window in desk.all {
      #expect(desk.h.frame(window) == desk.own[window], "\(window)")
      #expect(desk.h.frame(window)!.fractionInside(Self.display.frame) > 0.99, "\(window) is in view")
    }
    #expect(desk.moves() == Dictionary(uniqueKeysWithValues: touched.map { ($0, 1) }), "one move each, and none for the rest")
  }

  @Test func aPauseRaisesNothingAndLeavesTheKeyboardWhereItIs() {
    let desk = makeDesk()
    let raised = desk.h.system.raiseLog.count
    desk.h.press("toggle-pause")
    #expect(desk.h.system.raiseLog.count == raised)
    #expect(desk.h.system.focused == desk.safari)
  }

  @Test func resumingBringsTheArrangementAndTheViewBackInOneMove() {
    let desk = makeDesk()
    let (arranged, frames, touched) = (desk.h.workspace, desk.frames(), desk.touched)
    desk.h.press("toggle-pause")
    desk.h.system.clearFrameLog()

    #expect(desk.h.press("toggle-pause").ok)
    #expect(desk.h.workspace == arranged)
    #expect(desk.frames() == frames)
    #expect(desk.moves() == Dictionary(uniqueKeysWithValues: touched.map { ($0, 1) }), "one move each, and none for the rest")
    expectWindowsMatchLayout(desk.h)
  }

  @Test func framedOnAWindowAPauseGivesThatOneItsSizeBackToo() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let (arranged, framed) = (desk.h.workspace, desk.h.frame(desk.safari))
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")

    desk.h.system.clearFrameLog()
    desk.h.press("toggle-pause")
    #expect(desk.h.workspace == arranged)
    #expect(desk.h.frame(desk.safari) == framed)
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    for window in desk.all where window != desk.safari { #expect(!desk.h.system.isVisible(window), "\(window)") }
    expectWindowsMatchLayout(desk.h)
  }

  // MARK: The keyboard went elsewhere meanwhile

  /// A resume ends with the focused window in view. The view is worked out first and everything is laid out once: not
  /// the view of before the pause, and then the one that shows the window.
  @Test(arguments: ["docked", "floating"])
  func aResumeWithTheKeyboardOutsideTheViewStillMovesEachWindowOnce(_ kind: String) {
    let desk = makeDesk()
    let window = kind == "docked" ? desk.finder : desk.textEdit
    desk.h.run("zoom \(desk.safari.rawValue)")
    #expect(!desk.h.system.isVisible(window))
    desk.h.press("toggle-pause")
    desk.h.system.userFocus(window)
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    #expect(desk.h.system.isVisible(window), "it has the keyboard")
    #expect(desk.h.system.focused == window)
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    #expect(desk.h.run("back").ok && desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.safari), "the way back is kept")
    expectWindowsMatchLayout(desk.h)
  }

  @Test func aGuestWithTheKeyboardBringsItsHostsViewBackInOneLayout() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let guest = desk.h.system.open(app: "Dialog", pid: 2100, frame: CGRect(x: 400, y: 300, width: 500, height: 300))
    #expect(desk.h.workspace.guests?[guest] != nil)
    desk.h.run("zoom \(desk.finder.rawValue)")
    #expect(!desk.h.system.isVisible(guest))
    desk.h.press("toggle-pause")
    desk.h.system.userFocus(guest)
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.safari))
    #expect(desk.h.system.isVisible(guest) && desk.h.system.focused == guest)
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    expectWindowsMatchLayout(desk.h)
  }

  /// A pause ends a summon and leaves the window where it is. With the keyboard still in it at the resume it is summoned again, there.
  @Test func aSummonedWindowIsNotSentToItsCornerAndFetchedAgain() throws {
    let desk = makeDesk()
    desk.h.run("summon Terminal")
    let summoned = try #require(desk.h.frame(desk.terminal))
    #expect(desk.h.workspace.summoned?.window == desk.terminal && desk.h.system.focused == desk.terminal)
    desk.h.press("toggle-pause")
    #expect(desk.h.frame(desk.terminal) == summoned)
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    #expect(desk.h.workspace.summoned?.window == desk.terminal)
    #expect(desk.h.frame(desk.terminal) == summoned)
    #expect(!desk.h.system.frameLog.contains { $0.window == desk.terminal && $0.frame != summoned }, "\(desk.h.system.frameLog.filter { $0.window == desk.terminal })")
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    expectWindowsMatchLayout(desk.h)
  }

  /// The view was on a group without the Desktop, and goes out until the Desktop is part of it. A Desktop that comes into view
  /// gathers what floats, a window that opened during the pause too, though no layout ever showed the view that was left.
  @Test func aDesktopThatComesIntoViewGathersWhatOpenedDuringThePause() throws {
    let desk = makeDesk()
    desk.h.run("dock \(desk.terminal.rawValue) beside \(desk.safari.rawValue) bottom")
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("out")
    #expect(desk.h.layout?.desktopFrame == nil && desk.h.layout?.windowFrames.count == 2)
    desk.h.press("toggle-pause")
    let new = desk.h.system.open(app: "Keynote", pid: 2100, frame: CGRect(x: 60, y: 300, width: 400, height: 300))
    desk.h.system.userFocus(desk.textEdit)
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    let desktop = try #require(desk.h.layout?.desktopFrame)
    #expect(desk.h.system.isVisible(desk.textEdit))
    #expect(desktop.insetBy(dx: -1, dy: -1).contains(try #require(desk.h.frame(new))), "\(String(describing: desk.h.frame(new)))")
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    expectWindowsMatchLayout(desk.h)
  }

  /// What opened during the pause was to stay over the view that was left. That view is not shown, so it waits there with it.
  @Test func whatOpenedDuringThePauseGoesWithTheViewThatWasLeft() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.press("toggle-pause")
    let new = desk.h.system.open(app: "Keynote", pid: 2100, frame: CGRect(x: 400, y: 300, width: 500, height: 300))
    desk.h.system.userFocus(desk.finder)
    desk.h.press("toggle-pause")
    #expect(desk.h.system.isVisible(desk.finder) && !desk.h.system.isVisible(new))
    desk.h.run("back")
    #expect(desk.h.system.isVisible(desk.safari) && desk.h.system.isVisible(new))
    expectWindowsMatchLayout(desk.h)
  }

  /// Found by playing walks on a build with the one layout and on one with the two. Music floats where the Desktop that comes into view
  /// has it, so the one layout has nothing to move; the two had sent it away and fetched it. Either way it is where Arbor has it,
  /// and makes way at a later change to the arrangement. Whether the click came before ⌃⌥⎋ or after it cannot be told.
  @Test func whetherTheClickCameBeforeTheResumeOrAfterItCannotBeToldLater() {
    func music(_ end: [String]) -> CGRect? {
      let runner = ChaosRunner()
      let lines =
        [
          "open 101 Music pid 1006 at 113 26 853 480 min 680 480", "open 102 Xcode pid 1004 at 12 38 1326 685 min 1188 685", "launch",
          "open 103 Terminal pid 1003 at 376 57 772 454 min 177 60", "dock 103 left", "zoom 103", "pause",
        ] + end + ["dock 102 left", "edge 102 -219 547 1248 685"]
      for line in lines { _ = runner.step(ChaosAction(text: line)) }
      return runner.system.frame(of: WindowID(101))
    }
    #expect(music(["focus 102", "resume"]) == music(["resume", "focus 102"]))
  }

  /// A view that followed the keyboard is taken back if the window that had it goes in the same moment: then macOS handed the keyboard
  /// on, and nobody asked to see the other window (Controller+Focus.swift). The record of that is kept here as well.
  @Test func aViewThatFollowedTheKeyboardAtAResumeCanBeTakenBackLikeAnyOther() {
    func whereTheOtherNotesWindowEnds(_ end: [String]) -> CGRect? {
      let runner = ChaosRunner()
      let lines =
        [
          "open 101 Mail pid 1002 at 263 111 600 500", "open 102 Notes pid 1001 at 70 211 600 500", "open 103 Notes pid 1001 at 130 71 600 500", "launch",
          "dock 101 left", "dock 102 beside 101 bottom", "dock 103 right", "zoom 101", "out", "focus 102", "settle", "pause",
        ] + end + ["minimize 102"]
      for line in lines { _ = runner.step(ChaosAction(text: line)) }
      return runner.system.frame(of: WindowID(103))
    }
    let before = whereTheOtherNotesWindowEnds(["focus 103", "resume"])
    #expect(before == whereTheOtherNotesWindowEnds(["resume", "focus 103"]))
    #expect(before.map { FakeWindowSystem.standardDisplay.frame.contains($0) } == false, "out of view again: \(String(describing: before))")
  }

  // What is left as it was: each of these ends as it did when the view followed only after the first layout.

  /// Holding still, the view does not follow a window nobody asked for. Whether somebody did is the hold's to say, once it is on again.
  @Test func duringACallTheHoldDecidesAsBefore() {
    var settings = Settings()
    settings.holdStillFor = ["com.example.calendar"]
    let desk = makeDesk(settings: settings)
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("pause")
    desk.h.system.userFocus(desk.finder)
    desk.h.run("resume")
    #expect(desk.h.controller.holdLevel == .still)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.safari))
    #expect(!desk.h.system.isVisible(desk.finder))
    #expect(desk.h.system.focused == desk.safari, "the keyboard goes back to what is in view")
    expectWindowsMatchLayout(desk.h)
  }

  @Test func aWindowInTheSavedViewLeavesTheViewAlone() {
    let desk = makeDesk()
    let (view, frames) = (desk.h.workspace.camera, desk.frames())
    desk.h.press("toggle-pause")
    desk.h.system.userFocus(desk.finder)
    desk.h.press("toggle-pause")
    #expect(desk.h.workspace.camera == view && desk.h.workspace.back.isEmpty)
    #expect(desk.frames() == frames)
  }

  /// The framed window is in the Dock, so what shows is the group around it, and the window with the keyboard is part of that.
  @Test func whatCountsIsWhatTheSavedViewReallyShows() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.system.setMinimized(desk.safari, true)
    desk.h.system.userFocus(desk.finder)
    #expect(desk.h.system.isVisible(desk.finder))
    let arranged = desk.h.workspace
    desk.h.press("toggle-pause")
    desk.h.press("toggle-pause")
    #expect(desk.h.workspace == arranged, "the view and the way back are as they were")
    #expect(desk.h.system.isVisible(desk.finder))
  }

  /// With guests switched off, a window that opened during the pause stays over the view until that next moves.
  @Test func aWindowThatOpenedDuringThePauseAndStaysInViewDoesNotMoveTheView() {
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let desk = makeDesk(settings: settings)
    desk.h.run("zoom \(desk.safari.rawValue)")
    let view = desk.h.workspace.camera
    desk.h.press("toggle-pause")
    let new = desk.h.system.open(app: "Keynote", pid: 2100, frame: CGRect(x: 400, y: 300, width: 500, height: 300))
    desk.h.system.userFocus(new)
    desk.h.press("toggle-pause")
    #expect(desk.h.workspace.camera == view)
    #expect(desk.h.system.isVisible(new) && desk.h.system.isVisible(desk.safari))
  }

  /// Arbor starts and pauses at once for the app in front: the view that was saved is the one that comes back after the game.
  @Test func aStartThatPausesAtOnceKeepsTheSavedView() {
    let desk = makeDesk(watchingThePermission: true)
    desk.h.run("zoom \(desk.safari.rawValue)")
    let arranged = desk.h.workspace
    desk.h.revokeAccessibility()
    desk.h.scheduler.advance(by: 10)
    #expect(!desk.h.controller.isRunning)
    #expect(desk.h.run("set pauseForApps add com.example.finder").ok)
    desk.h.system.userFocus(desk.finder)
    desk.h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.finder", name: "Finder"))
    desk.h.grantAccessibility()
    desk.h.scheduler.advance(by: 10)
    #expect(desk.h.controller.isPausedForApp)
    #expect(desk.h.workspace.camera == arranged.camera && desk.h.workspace.back == arranged.back)
  }

  /// A window of the view that is too small to show there: whether it shows depends on how the layout turns out.
  @Test func aTileWithTheKeyboardIsFramedAsBefore() {
    let desk = makeDesk()
    let wide = desk.h.system.open(
      app: "Xcode", pid: 2100, frame: CGRect(x: 100, y: 100, width: 1500, height: 700), minimumSize: CGSize(width: 1500, height: 700))
    desk.h.run("dock \(wide.rawValue) beside \(desk.safari.rawValue) bottom")
    desk.h.run("show-all")
    #expect(desk.h.layout?.tiles.contains { $0.windows == [wide] } == true)
    desk.h.press("toggle-pause")
    desk.h.system.userFocus(wide)
    desk.h.press("toggle-pause")
    #expect(desk.h.system.isVisible(wide) && desk.h.system.focused == wide)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: wide))
    expectWindowsMatchLayout(desk.h)
  }

  /// One road: whatever is mended on it is mended for both.
  @Test func aPauseLeavesTheWindowsWhereAQuitWould() {
    let (paused, quit) = (makeDesk(), makeDesk())
    paused.h.run("pause")
    quit.h.controller.shutdown()
    #expect(paused.frames() == quit.frames())
  }

  @Test func aPauseWithAnEndDoesTheSame() {
    let desk = makeDesk()
    let frames = desk.frames()
    desk.h.run("pause 5")
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }
    desk.h.scheduler.advance(by: 5 * 60)
    #expect(desk.frames() == frames)
  }

  @Test func soDoesThePauseArborBeginsForAnApp() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let desk = makeDesk(settings: settings)
    let frames = desk.frames()

    desk.h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.game", name: "Game"))
    #expect(desk.h.controller.isPausedForApp)
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }

    desk.h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.safari", name: "Safari"))
    #expect(desk.h.controller.isRunning)
    #expect(desk.frames() == frames)
  }

  @Test func aQuitDuringThePauseHasNothingLeftToDo() {
    let desk = makeDesk()
    desk.h.run("pause")
    let saved = desk.h.store.saved
    desk.h.system.clearFrameLog()
    desk.h.controller.shutdown()
    #expect(desk.h.system.frameLog.isEmpty, "\(desk.h.system.frameLog)")
    #expect(!desk.h.system.started)
    #expect(desk.h.store.saved == saved, "the arrangement is still there for the next launch")
  }

  @Test func stateListsNoWindowDuringThePause() {
    let desk = makeDesk()
    desk.h.run("pause")
    #expect(desk.h.run("state").state?.windows.isEmpty == true, "Arbor is not looking, and does not pass off old frames as current")
  }

  // MARK: An app that does not answer when the pause begins

  /// Finder (docked) and Notes (squeezed) hang, and then a pause.
  func pausedWithFinderAndNotesHung() -> (Desk, slot: CGRect, squeezed: CGRect) {
    let desk = makeDesk()
    let (slot, squeezed) = (desk.h.frame(desk.finder)!, desk.h.frame(desk.notes)!)
    for window in [desk.finder, desk.notes] { desk.h.system.setUnresponsive(pid: desk.h.controller.windows[window]!.pid, true) }
    desk.h.run("pause")
    for pid in desk.h.system.unresponsive { desk.h.system.setUnresponsive(pid: pid, false) }
    return (desk, slot, squeezed)
  }

  /// As after a quit while an app hangs. Starting to look again, at a logout for one, would mean waiting for that very app.
  @Test func aQuitDuringThePauseAsksNoAppAgain() {
    let (desk, slot, squeezed) = pausedWithFinderAndNotesHung()
    #expect(desk.h.frame(desk.finder) == slot && desk.h.frame(desk.notes) == squeezed, "nothing could be done about them")
    let starts = desk.h.system.starts
    desk.h.system.clearFrameLog()
    desk.h.controller.shutdown()
    #expect(desk.h.system.frameLog.isEmpty && desk.h.system.starts == starts)
  }

  @Test func aResumeFindsThemWhereTheyWereAndMovesNeither() {
    let (desk, slot, squeezed) = pausedWithFinderAndNotesHung()
    desk.h.system.clearFrameLog()
    desk.h.run("resume")
    #expect(desk.h.frame(desk.finder) == slot && desk.h.frame(desk.notes) == squeezed)
    #expect(desk.moves()[desk.finder] == nil && desk.moves()[desk.notes] == nil, "\(desk.moves())")
    expectWindowsMatchLayout(desk.h)
  }

  /// What somebody does with a window during the pause is theirs for as long as it lasts; the arrangement comes back all the same.
  @Test func aDockedWindowResizedDuringThePauseGoesBackToItsSlotAndStillRemembersItsOwnSize() {
    let desk = makeDesk()
    let slot = desk.h.frame(desk.finder)
    desk.h.run("pause")
    desk.h.system.userMove(desk.finder, to: CGRect(x: 60, y: 60, width: 500, height: 333))
    desk.h.run("resume")
    #expect(desk.h.frame(desk.finder) == slot)
    #expect(desk.h.workspace.undockedFrame(of: desk.finder) == desk.own[desk.finder])
  }
}
