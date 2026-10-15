import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A person starts Arbor with the keyboard in a docked window for which there is no room when everything shows
/// (`collab/QUESTIONS.md`, Q16; `Controller+LetBe.swift`). The view used to go to it, and every other window left.
@Suite @MainActor struct LaunchLetsBeTests {
  /// `[player | Desktop | browser / mail]` and loose notes. Somebody has squeezed the player's slot to under what
  /// Arbor uses, and has switched off that Arbor makes room: the player is a tile wherever it is not alone, and no
  /// room can be made for it. Arbor has quit, so every window is in view at its own frame, and somebody has clicked
  /// the player since.
  func quitWithTheKeyboardInThePlayer() -> (Harness, player: WindowID, browser: WindowID, notes: WindowID, mail: WindowID) {
    var settings = Settings()
    settings.makeRoom = false
    let old = Harness(settings: settings)
    let player = old.system.open(app: "Music", pid: 11, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    let browser = old.system.open(app: "Safari", pid: 12, frame: CGRect(x: 200, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 13, frame: CGRect(x: 620, y: 420, width: 300, height: 260))
    let mail = old.system.open(app: "Mail", pid: 14, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    old.start()
    old.run("dock \(player.rawValue) left")
    old.run("dock \(browser.rawValue) right")
    old.run("dock \(mail.rawValue) beside \(browser.rawValue) bottom")
    old.run("resize \(player.rawValue) right -300")
    settle(old)
    #expect(old.layout?.hiddenWindows == [player] && old.layout?.windowFrames[browser] != nil, "\(old.ascii())")
    old.controller.shutdown()
    old.system.userFocus(player)
    let h = old.newProcess()
    h.system.clearFrameLog()
    h.system.clearRaiseLog()
    return (h, player, browser, notes, mail)
  }

  /// The windows Arbor has focused since `mark`. The log is the Mac's, and goes on from one process to the next.
  func focused(_ h: Harness, since mark: Int) -> [WindowID] { h.system.focusLog.dropFirst(mark).map(\.window) }

  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  func moves(of window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// How often it has been moved since the log was cleared, besides a question put to it where it stood
  /// (Controller+AskFirst.swift). Nil if something was done twice or for nothing.
  func moveCount(of window: WindowID, _ h: Harness) -> Int? {
    movesWithoutWaste(h, of: window, since: h.system.movesWhenTheFrameLogWasCleared)
  }

  /// Started, and come to rest.
  func launched() -> (Harness, player: WindowID, browser: WindowID, notes: WindowID, stood: CGRect) {
    let (h, player, browser, notes, _) = quitWithTheKeyboardInThePlayer()
    let stood = h.frame(player)!
    h.start()
    settle(h)
    return (h, player, browser, notes, stood)
  }

  func expectLetBe(_ h: Harness, _ player: WindowID, at stood: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(h.controller.windowLetBe == player, sourceLocation: sourceLocation)
    #expect(h.frame(player) == stood, sourceLocation: sourceLocation)
    #expect(moves(of: player, h) == [], sourceLocation: sourceLocation)
    #expect(h.workspace.isDocked(player), "it is docked, and its tile keeps its place", sourceLocation: sourceLocation)
    #expect(h.layout?.tiles.contains { $0.windows.contains(player) } == true, sourceLocation: sourceLocation)
    #expect(h.workspace.camera == h.workspace.tree.root, sourceLocation: sourceLocation)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())", sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, sourceLocation: sourceLocation)
  }

  // MARK: The launch

  @Test func itGetsNoFrameTheViewStaysAndNobodyLeaves() {
    let (h, player, browser, notes, _) = quitWithTheKeyboardInThePlayer()
    let (stood, mark) = (h.frame(player)!, h.system.focusLog.count)
    h.start()
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.system.focusedWindow() == player, "the keyboard stays in it")
    #expect(focused(h, since: mark) == [])
    #expect(h.system.isVisible(browser) && h.system.isVisible(notes))
    #expect(moveCount(of: browser, h) == 1, "what was docked goes to its place, in one move: \(moves(of: browser, h))")
    #expect(moves(of: notes, h) == [], "never docked, so not moved")
    #expect(h.system.raiseLog.isEmpty, "nothing is raised over it: \(h.system.raiseLog)")
  }

  /// `[editor | Desktop | browser]` and loose notes. The editor goes no narrower than 1200 points, which beside
  /// anything is more than the display has: it is a tile. Arbor has quit, and somebody has clicked it since.
  func quitWithTheKeyboardInAWindowThatIsTooWide(on side: String = "left") -> (Harness, tooWide: WindowID, others: [WindowID]) {
    let old = Harness()
    old.start()
    let editor = old.system.open(app: "Xcode", pid: 11, frame: CGRect(x: 100, y: 100, width: 1200, height: 600))
    old.system.setMinimumSize(editor, CGSize(width: 1200, height: 500))
    let browser = old.system.open(app: "Safari", pid: 12, frame: CGRect(x: 700, y: 100, width: 600, height: 500))
    let notes = old.system.open(app: "Notes", pid: 13, frame: CGRect(x: 300, y: 300, width: 500, height: 400))
    old.run("dock \(editor.rawValue) \(side)")
    old.run("dock \(browser.rawValue) \(side == "left" ? "right" : "left")")
    settle(old)
    let tiles = old.layout?.hiddenWindows ?? []
    #expect(tiles.count == 1, "\(old.ascii())")
    let tooWide = tiles.first ?? editor
    old.controller.shutdown()
    old.system.userFocus(tooWide)
    let h = old.newProcess()
    h.system.clearFrameLog()
    return (h, tooWide, [editor, browser, notes].filter { $0 != tooWide })
  }

  /// Real apps say how small they go only when asked, and a new process has never asked. So the window is asked, where it
  /// stands, to be as narrow as its place (Controller+AskFirst.swift), keeps its size, and has not left. (Offered the place itself it was
  /// wherever that left it: with a slot on the right, mostly off the display. Preview, with eight windows docked, on a hosted Mac.)
  @Test(arguments: ["left", "right"]) func oneThatTurnsOutToBeATileOnlyWhenAskedEndsWhereItStood(side: String) {
    let (h, tooWide, others) = quitWithTheKeyboardInAWindowThatIsTooWide(on: side)
    // In a home that has not met the app. One that has knows how small it goes, and sets it no frame at all (`HowSmallAppsGoTests`).
    h.store.saved?.appSizes = nil
    let (stood, mark) = (h.frame(tooWide)!, h.system.focusLog.count)
    h.start()
    settle(h)
    #expect(h.controller.windowLetBe == tooWide, "\(h.ascii())")
    #expect(h.frame(tooWide) == stood)
    #expect(moves(of: tooWide, h) == [stood], "asked once, and it never left")
    for window in others { #expect(h.system.isVisible(window), "\(window)") }
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.focusedWindow() == tooWide && focused(h, since: mark) == [])
    expectWindowsMatchLayout(h)
  }

  /// With room for it, it is a docked window like any other.
  @Test func oneThatHasRoomGoesToItsPlace() {
    let old = Harness()
    let a = old.system.open(app: "Safari", pid: 11)
    let b = old.system.open(app: "Notes", pid: 12)
    old.start()
    old.run("dock \(a.rawValue) left")
    old.run("dock \(b.rawValue) right")
    old.controller.shutdown()
    old.system.userFocus(a)
    let h = old.newProcess()
    h.system.clearFrameLog()
    h.start()
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(moveCount(of: a, h) == 1 && h.layout?.windowFrames[a] == h.frame(a))
    expectWindowsMatchLayout(h)
  }

  // MARK: What nobody asked for leaves it alone

  @Test func anotherWindowComingAndGoingMovesTheOthersOnly() {
    let (h, player, browser, _, mail) = quitWithTheKeyboardInThePlayer()
    let stood = h.frame(player)!
    h.start()
    settle(h)
    let place = h.frame(browser)!
    let radio = h.system.open(app: "Radio", pid: 15, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.system.userFocus(player)
    settle(h)
    expectLetBe(h, player, at: stood)
    h.system.setMinimized(mail, true)
    settle(h)
    #expect(h.frame(browser)!.height > place.height, "the browser takes the room")
    expectLetBe(h, player, at: stood)
    h.system.setMinimized(mail, false)
    h.system.userFocus(player)
    settle(h)
    #expect(h.frame(browser) == place)
    expectLetBe(h, player, at: stood)
    h.system.close(radio)
    h.system.close(mail)
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.system.raiseLog.isEmpty, "nothing is raised over it: \(h.system.raiseLog)")
  }

  /// Something pushes a docked neighbour about, and a quarter of a second later Arbor puts it back.
  @Test func aPuttingBackLeavesItAlone() {
    let (h, player, browser, _, stood) = launched()
    let place = h.frame(browser)!
    h.system.userMove(browser, to: place.offsetBy(dx: -60, dy: 40))
    settle(h)
    #expect(h.frame(browser) == place)
    expectLetBe(h, player, at: stood)
  }

  /// The Dock grows, the menu bar shows: macOS reports the displays, and everything is laid out.
  @Test func aReportOfTheDisplaysLeavesItAlone() {
    let (h, player, browser, _, stood) = launched()
    var display = FakeWindowSystem.standardDisplay
    display.visibleFrame = CGRect(x: 0, y: 40, width: 1440, height: 800)
    h.system.setDisplays([display])
    settle(h)
    #expect(h.frame(browser)!.minY > 40, "the others are laid out")
    expectLetBe(h, player, at: stood)
    #expect(h.system.focusedWindow() == player)
  }

  /// To another Space and back, which is laid out by a timer once all the reports are in.
  @Test func anotherSpaceAndBackLeavesItAlone() {
    let (h, player, _, _, stood) = launched()
    let all = h.system.allWindows().map(\.id)
    for window in all { h.system.setOnActiveSpace(window, false) }
    settle(h)
    for window in all { h.system.setOnActiveSpace(window, true) }
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.system.focusedWindow() == player)
  }

  /// It is in plain sight, so a held view does not turn the keyboard away from it.
  @Test(arguments: ["hold", "hold still"]) func aHoldTakesItForWhatItIsInView(hold: String) {
    let (h, player, browser, _, stood) = launched()
    #expect(h.run(hold).ok)
    h.system.userFocus(browser)
    settle(h)
    let mark = h.system.focusLog.count
    h.system.userFocus(player)
    settle(h)
    #expect(focused(h, since: mark) == [] && h.system.focusedWindow() == player)
    expectLetBe(h, player, at: stood)
  }

  /// A key pressed on another Space lays out, but the window is not there to go into its tile. Sent off by the
  /// timer's layout once it is back, it would have the keyboard in the corner.
  @Test func aCommandGivenOnAnotherSpaceDoesNotEndIt() {
    let (h, player, _, _, stood) = launched()
    let all = h.system.allWindows().map(\.id)
    for window in all { h.system.setOnActiveSpace(window, false) }
    settle(h)
    #expect(h.run("relayout").ok)
    settle(h)
    for window in all { h.system.setOnActiveSpace(window, true) }
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.system.focusedWindow() == player)
  }

  /// Nor one given while its app does not answer: it cannot be moved now, and nobody asks when the app wakes.
  @Test func aCommandGivenWhileItsAppHangsDoesNotEndIt() {
    let (h, player, _, _, stood) = launched()
    h.system.setUnresponsive(pid: 11, true)
    #expect(h.run("relayout").ok)
    settle(h)
    h.system.setUnresponsive(pid: 11, false)
    settle(h)
    #expect(h.frame(player) == stood && h.system.isVisible(player))
    #expect(h.system.focusedWindow() == player)
  }

  /// Taken by its title bar and let go of over another window or over its own tile: it is where the hand put it. (Let go
  /// of over the Desktop it floats, like any docked window.)
  @Test func takenByItsTitleBarItStaysWhereTheHandPutsIt() {
    for point in [CGPoint(x: 1200, y: 300), CGPoint(x: 60, y: 400)] {
      let (h, player, browser, _, stood) = launched()
      let place = h.frame(browser)
      h.system.drag(player, through: [CGPoint(x: stood.midX, y: stood.minY + 10), point], holding: 0)
      settle(h)
      #expect(h.system.isVisible(player), "\(point): \(moves(of: player, h))")
      #expect(moves(of: player, h) == [], "\(point)")
      #expect(h.system.focusedWindow() == player, "\(point)")
      #expect(h.frame(browser) == place, "\(point)")
      #expect(h.controller.invariantViolations().isEmpty, "\(point): \(h.controller.invariantViolations())")
    }
  }

  /// As with a window that macOS zoomed (Q22): it lies over the arrangement until somebody asks.
  @Test func theKeyboardLeavingItChangesNothingAndNeitherDoesItsComingBack() {
    let (h, player, browser, notes, stood) = launched()
    for window in [browser, notes, player] {
      h.system.userFocus(window)
      settle(h)
      expectLetBe(h, player, at: stood)
    }
  }

  // MARK: What a person asks for ends it

  /// Then it is a window like any other: into its tile, in one move.
  @Test(arguments: ["show-all", "relayout", "float $browser", "dock $notes bottom", "desktop", "zoom $browser"])
  func aCommandThatLaysOutOrMovesTheViewEndsIt(command: String) {
    let (h, player, browser, notes, _) = launched()
    let line = command.replacingOccurrences(of: "$browser", with: "\(browser.rawValue)")
      .replacingOccurrences(of: "$notes", with: "\(notes.rawValue)")
    #expect(h.run(line).ok, "\(line)")
    settle(h)
    #expect(h.controller.windowLetBe == nil, "\(line)")
    #expect(moves(of: player, h).count == 1, "\(line): \(moves(of: player, h))")
    #expect(!h.system.isVisible(player), "\(line)")
    #expect(h.system.focusedWindow().map { h.system.isVisible($0) } != false, "\(line): no key goes to a window out of view")
    expectWindowsMatchLayout(h)
  }

  /// One hand-over of the keyboard at most, and after the command has had its own say.
  @Test func theKeyboardIsHandedOnOnce() {
    for line in ["relayout", "dock 103 bottom", "show-all", "float 102"] {
      let (h, player, _, _, _) = launched()
      let mark = h.system.focusLog.count
      #expect(h.run(line).ok, "\(line)")
      settle(h)
      #expect(focused(h, since: mark).count == 1, "\(line): \(focused(h, since: mark))")
      #expect(h.system.focusedWindow() != player)
    }
  }

  /// Across apps a Mac moves the keyboard only after the call has returned. The command's own choice still stands.
  @Test func theCommandsOwnChoiceStandsAlsoWhenMacOSTakesAMoment() {
    let (h, _, _, notes, _) = launched()
    let mark = h.system.focusLog.count
    h.system.focusIsSlow = true
    #expect(h.run("dock \(notes.rawValue) bottom").ok)
    #expect(focused(h, since: mark) == [notes])
    h.system.finishSlowFocus()
    settle(h)
    #expect(h.system.focusedWindow() == notes)
  }

  /// Asked for by name it gets the keyboard where it stands, as with ⌘Tab; and its tile is no stop beside it.
  @Test func askedForByNameOrDirectionItIsAWindowInView() {
    let (h, player, browser, _, stood) = launched()
    h.system.userFocus(browser)
    settle(h)
    #expect(h.run("summon com.example.music").ok)
    settle(h)
    #expect(h.system.focusedWindow() == player)
    expectLetBe(h, player, at: stood)
    _ = h.run("focus left")
    settle(h)
    #expect(h.workspace.camera == h.workspace.tree.root, "its own tile is not entered")
    #expect(h.system.isVisible(browser))
  }

  /// A keyboard that was not in it is nobody's to hand on: it is with Finder, and somebody drags a gap.
  @Test func aGapInTheHandEndsItAndAKeyboardElsewhereStaysThere() throws {
    let (h, player, _, _, _) = launched()
    h.system.userFocusesNothing()
    settle(h)
    let mark = h.system.focusLog.count
    h.overlays.dragSeam(try #require(h.layout?.seams.last), by: -20)
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(moves(of: player, h).count == 1 && !h.system.isVisible(player))
    #expect(focused(h, since: mark) == [])
    expectWindowsMatchLayout(h)
  }

  /// Framed if that is what is asked for: by command, or by a click on its own tile, which is what the tile says it
  /// does.
  @Test(arguments: [false, true]) func askedForItIsFramedInOneMove(byItsTile: Bool) {
    let (h, player, browser, _, _) = launched()
    if byItsTile {
      h.overlays.clickTile(h.workspace.tree.leaf(containing: player)!)
    } else {
      #expect(h.run("zoom \(player.rawValue)").ok)
    }
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: player))
    #expect(h.system.isVisible(player) && !h.system.isVisible(browser))
    #expect(moveCount(of: player, h) == 1, "\(moves(of: player, h))")
    #expect(h.system.focusedWindow() == player)
    expectWindowsMatchLayout(h)
  }

  /// What asks a question, or changes nothing on its display, is no such asking.
  @Test(arguments: ["state", "layout", "save-view 1", "hold still"]) func aCommandThatLaysNothingOutDoesNot(command: String) {
    let (h, player, _, _, stood) = launched()
    #expect(h.run(command).ok, "\(command)")
    settle(h)
    expectLetBe(h, player, at: stood)
  }

  @Test func aWindowDroppedIntoTheArrangementEndsIt() {
    let (h, player, _, notes, _) = launched()
    h.system.drag(notes, through: [h.frame(notes)!.center, CGPoint(x: 700, y: 896)])
    settle(h)
    #expect(h.workspace.isDocked(notes), "\(h.ascii())")
    #expect(h.controller.windowLetBe == nil)
    #expect(moves(of: player, h).count == 1 && !h.system.isVisible(player))
    expectWindowsMatchLayout(h)
  }

  // MARK: It ends with nothing moved

  @Test(arguments: ["close", "minimize", "hide"]) func whenItGoesNothingIsMovedForIt(way: String) {
    let (h, player, _, _, _) = launched()
    switch way {
    case "close": h.system.close(player)
    case "minimize": h.system.setMinimized(player, true)
    default: h.system.setHidden(pid: 11, true)
    }
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(moves(of: player, h) == [])
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// Undocked it floats where it stands, not in the middle of its tile.
  @Test(arguments: ["float", "toggle-float", "pin"]) func undockedItStaysWhereItStands(command: String) {
    let (h, player, _, _, stood) = launched()
    #expect(h.run("\(command) \(player.rawValue)").ok)
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(!h.workspace.isDocked(player))
    #expect(h.frame(player) == stood, "\(moves(of: player, h))")
    #expect(h.system.focusedWindow() == player)
    expectWindowsMatchLayout(h)
  }

  @Test func whenArborArrangesItsAppNoLongerNothingIsOnRecord() {
    let (h, player, _, _, stood) = launched()
    #expect(h.run("exclude com.example.music").ok)
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(h.frame(player) == stood)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  /// Nothing puts it back where its person moves it, so that is its own frame from then on.
  @Test(arguments: ["quit", "pause", "float-all"]) func whereItsPersonPutsItIsWhereTheWaysOutLeaveIt(way: String) {
    let (h, player, _, _, _) = launched()
    let put = CGRect(x: 200, y: 480, width: 520, height: 340)
    h.system.userMove(player, to: put)
    settle(h)
    #expect(h.controller.windowLetBe == player && h.frame(player) == put)
    if way == "quit" { h.controller.shutdown() } else { #expect(h.run(way).ok) }
    settle(h)
    #expect(h.frame(player) == put, "\(moves(of: player, h))")
  }

  /// Moved while Arbor was not running: where it stands at the start is its own frame, too.
  @Test func whereItWasPutBetweenTheQuitAndTheLaunchIsWhereAQuitLeavesIt() {
    let (h, player, _, _, _) = quitWithTheKeyboardInThePlayer()
    let put = CGRect(x: 100, y: 500, width: 400, height: 300)
    h.system.userMove(player, to: put)
    h.system.clearFrameLog()
    h.start()
    settle(h)
    expectLetBe(h, player, at: put)
    h.controller.shutdown()
    #expect(h.frame(player) == put, "\(moves(of: player, h))")
  }

  /// A layout that has room for it after all puts it there, whoever caused that layout: that is what docked means.
  /// Here its app lets it shrink at last, and it is seen smaller than it said it could be.
  @Test func whenThereIsRoomAfterAllItGoesToItsPlaceInOneMove() {
    let (h, tooWide, _) = quitWithTheKeyboardInAWindowThatIsTooWide()
    h.start()
    settle(h)
    #expect(h.controller.windowLetBe == tooWide)
    h.system.clearFrameLog()
    h.system.setMinimumSize(tooWide, CGSize(width: 200, height: 200))
    var smaller = h.frame(tooWide)!
    smaller.size.width = 240
    h.system.userMove(tooWide, to: smaller)
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(h.layout?.windowFrames[tooWide] == h.frame(tooWide), "\(h.ascii())")
    #expect(moves(of: tooWide, h).count == 1, "\(moves(of: tooWide, h))")
    expectWindowsMatchLayout(h)
  }

  @Test func quittingAgainLeavesItWhereItStands() {
    let (h, player, _, _, stood) = launched()
    h.controller.shutdown()
    #expect(h.frame(player) == stood)
    #expect(moves(of: player, h) == [])
  }

  // MARK: The other starts

  /// They keep their view, which is on everything here, and go by the same rule: otherwise a pause and a resume would
  /// bring the fault back.
  @Test func aPauseAndAResumeLetItBeAgain() {
    let (h, player, browser, notes, stood) = launched()
    let place = h.frame(browser)
    #expect(h.run("pause").ok)
    #expect(h.frame(player) == stood)
    #expect(h.run("resume").ok)
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.frame(browser) == place && h.system.isVisible(notes))
    #expect(h.system.focusedWindow() == player)
  }

  /// Nobody quit, and every window is where it was: no frame is set.
  @Test func theWatchdogsRestartLetsItBeAgainAndSetsNoFrame() {
    let (first, player, _, _, stood) = launched()
    first.scheduler.advance(by: 1)
    let h = first.newProcess(byTheWatchdog: true)
    h.system.clearFrameLog()
    h.start()
    settle(h)
    expectLetBe(h, player, at: stood)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// A view that is somewhere else has it out of view like everything it leaves out, and follows the keyboard as it
  /// always did.
  @Test func aResumeIntoAViewElsewhereFollowsTheKeyboardAsBefore() {
    let (h, player, browser, _, _) = launched()
    #expect(h.run("zoom \(browser.rawValue)").ok)
    settle(h)
    #expect(h.run("pause").ok)
    h.system.userFocus(player)
    #expect(h.run("resume").ok)
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(h.system.focusedWindow() == player && h.system.isVisible(player))
    expectWindowsMatchLayout(h)
  }

  // MARK: What the walks found

  /// The scripts of the known failure `launch-keyboard-in-a-tile`, which this cured. (They break other rules on their
  /// way.)
  @Test(arguments: [
    """
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
    """,
  ]) func theStartsOfTheWalksTakeNothingOutOfView(script: String) {
    let runner = ChaosRunner()
    let broken = ChaosAction.script(script).flatMap { runner.step($0) }.map(\.rule)
    #expect(!broken.contains("start-took-out-of-view") && !broken.contains("let-be"), "\(broken)")
  }

  // MARK: After a crash it is out of view

  /// "Let be where it stands" is for a window a person sees. Killed with the keyboard in a tile's window, which is in
  /// the corner: everything shows, it stays behind its tile with no frame set, and the keyboard goes to a window in
  /// view, chosen as Show Everything chooses when it puts the focused window into a tile. (Which was used last died
  /// with the process.)
  @Test func leftInTheCornerByACrashItStaysThereAndAWindowInViewGetsTheKeyboard() {
    let (first, player, browser, notes, _) = launched()
    first.system.userFocus(browser)
    first.system.userFocus(notes)
    #expect(first.run("show-all").ok)
    settle(first)
    #expect(!first.system.isVisible(player))
    // What board 1.12 is about: the keyboard in a window that shows as a tile.
    first.system.focused = player

    let h = first.newProcess()
    h.system.clearFrameLog()
    h.start()
    settle(h)
    #expect(h.controller.windowLetBe == nil)
    #expect(moves(of: player, h) == [] && !h.system.isVisible(player))
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(browser) && h.system.isVisible(notes))
    let heir = h.system.focusedWindow()
    #expect(heir != nil && heir != player && heir.map { h.system.isVisible($0) } == true, "\(String(describing: heir))")
    expectWindowsMatchLayout(h)
  }

  /// With nothing in view to take the keyboard the view follows it, which then takes nothing away.
  @Test func withNothingInViewToTakeTheKeyboardTheViewFollowsIt() {
    var settings = Settings()
    settings.makeRoom = false
    let first = Harness(settings: settings)
    let player = first.system.open(app: "Music", pid: 11, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    first.start()
    first.run("dock \(player.rawValue) left")
    first.run("resize \(player.rawValue) right -500")
    settle(first)
    #expect(!first.system.isVisible(player), "\(first.ascii())")
    first.system.focused = player

    let h = first.newProcess()
    h.start()
    settle(h)
    #expect(h.system.focusedWindow() == player && h.system.isVisible(player), "typing into a window out of view is worse")
    expectWindowsMatchLayout(h)
  }
}
