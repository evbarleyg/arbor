import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// **A frame a person gives a window while Arbor is paused, or not running, is its own from then on** (collab/QUESTIONS.md, the product
/// owner's note of 2026-10-15 on F48 and rule 5): the half of it that is about docked windows. `FoundAtAStartTests` has the floating ones.
///
/// What was docked is docked again, one move each (Q16). What changes is the frame the window goes back to when Arbor next lets go of it,
/// or when it floats again.
@Suite @MainActor struct DockedAsFoundTests {
  static let ownOfTheEditor = CGRect(x: 100, y: 100, width: 700, height: 500)
  static let ownOfTheBrowser = CGRect(x: 300, y: 150, width: 900, height: 600)
  static let chosen = CGRect(x: 500, y: 300, width: 640, height: 380)

  /// [editor | Desktop | browser], each of an app of its own.
  func twoDocked(editor own: CGRect = ownOfTheEditor) -> (h: Harness, editor: WindowID, browser: WindowID) {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001, frame: own)
    let browser = h.system.open(app: "Browser", pid: 1002, frame: Self.ownOfTheBrowser)
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    settle(h)
    return (h, editor, browser)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  func unheard(_ h: Harness, _ happens: () -> Void) {
    let listener = h.system.events
    h.system.events = nil
    happens()
    h.system.events = listener
  }

  /// How often `window` has been moved since the log was cleared, besides a question put to it where it stood (Controller+AskFirst.swift).
  func moves(of window: WindowID, _ h: Harness) -> Int {
    let log = h.system.moveLog[h.system.movesWhenTheFrameLogWasCleared...].filter { $0.window == window }
    return log.count - Budget.tally(log).questions
  }

  enum Away: String, CaseIterable { case pause, quit }

  /// Arbor lets go, `meanwhile` happens, and Arbor is back. The harness that comes back is a new one after a quit.
  /// Nothing of `meanwhile` is reported: the real window system stops observing when Arbor lets go.
  func away(_ how: Away, _ old: Harness, meanwhile: (Harness) -> Void) -> Harness {
    var h = old
    switch how {
    case .pause: h.run("pause")
    case .quit:
      h.controller.shutdown()
      h = h.newProcess()
    }
    unheard(h) { meanwhile(h) }
    h.system.clearFrameLog()
    if how == .pause { h.run("resume") } else { h.start() }
    settle(h)
    return h
  }

  // MARK: Somebody has touched it

  /// The product owner's play: dock, dock, pause, give one a frame, resume, pause.
  @Test(arguments: Away.allCases, ["pause", "float-all", "quit"])
  func theFrameItWasGivenIsTheOneItGoesBackTo(how: Away, lettingGo: String) {
    let (old, editor, browser) = twoDocked()
    let slots = [editor: old.frame(editor), browser: old.frame(browser)]
    let h = away(how, old) { $0.system.userMove(browser, to: Self.chosen) }
    // The arrangement comes back all the same, in one move each.
    #expect(h.workspace.isDocked(browser))
    #expect(h.frame(browser) == slots[browser])
    #expect(moves(of: browser, h) == 1, "\(h.system.frameLog)")
    #expect(moves(of: editor, h) == 1, "\(h.system.frameLog)")
    expectWindowsMatchLayout(h)
    if lettingGo == "quit" { h.controller.shutdown() } else { h.run(lettingGo) }
    #expect(h.frame(browser) == Self.chosen)
    #expect(h.frame(editor) == Self.ownOfTheEditor, "nobody touched this one")
  }

  /// People leave windows hanging over an edge on purpose.
  @Test(arguments: Away.allCases) func pushedOverAnEdgeItGoesBackThere(how: Away) {
    let (old, _, browser) = twoDocked()
    let hanging = Self.ownOfTheBrowser.offsetBy(dx: 400, dy: 0)
    #expect(hanging.maxX > FakeWindowSystem.standardDisplay.frame.maxX)
    let h = away(how, old) { $0.system.userMove(browser, to: hanging) }
    h.run("pause")
    #expect(h.frame(browser)?.origin == hanging.origin)
    // A window cannot grow past the screen where it stands, on a Mac and, since the cure of the short window, here: it comes back cut at the edge.
    withKnownIssue("board 0.22, first half: nobody takes the screen's answer for the window's") {
      #expect(h.frame(browser) == hanging)
    }
  }

  /// One window floats where it is, in its own size (F48), which is the new one.
  @Test(arguments: Away.allCases) func itFloatsInTheSizeItWasGiven(how: Away) {
    let (old, _, browser) = twoDocked()
    let h = away(how, old) { $0.system.userMove(browser, to: Self.chosen) }
    h.run("float \(browser.rawValue)")
    #expect(h.frame(browser)?.size == Self.chosen.size)
  }

  /// Docked for as long as Arbor has known it, it had no frame to go back to but its slot. Now it has.
  @Test func oneWithNothingRememberedHasAFrameOfItsOwnNow() throws {
    let (old, _, browser) = twoDocked()
    old.controller.shutdown()
    var state = try #require(old.store.saved)
    let data = try JSONEncoder().encode(state)
    var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    var workspaces = try #require(json["workspaces"] as? [String: Any])
    for (id, value) in workspaces {
      var workspace = try #require(value as? [String: Any])
      workspace["undockedFrames"] = nil
      workspaces[id] = workspace
    }
    json["workspaces"] = workspaces
    state = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
    old.store.saved = state
    let h = old.newProcess()
    h.system.place(browser, at: Self.chosen)
    h.start()
    settle(h)
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
  }

  // MARK: A move is not a resize

  /// Its app did not answer when Arbor let go, so it is left in the shape of its slot. Pushed aside like that, it has not become its person's
  /// idea of its size: it keeps its own, from where it is now.
  @Test(arguments: Away.allCases) func pushedAsideInTheShapeOfItsSlotItKeepsItsOwnSize(how: Away) throws {
    let (old, _, browser) = twoDocked()
    let slot = try #require(old.frame(browser))
    old.system.setUnresponsive(pid: 1002, true)
    let h = away(how, old) {
      #expect($0.frame(browser) == slot, "left as it was")
      $0.system.setUnresponsive(pid: 1002, false)
      $0.system.userMove(browser, to: slot.offsetBy(dx: -600, dy: 40))
    }
    #expect(h.workspace.undockedFrame(of: browser)?.size == Self.ownOfTheBrowser.size)
    h.run("pause")
    #expect(h.frame(browser) == CGRect(origin: slot.offsetBy(dx: -600, dy: 40).origin, size: Self.ownOfTheBrowser.size), "from where it was pushed to")
  }

  /// Its app gives it a few points less than it is asked for, as a terminal keeps to whole characters. Pushed over an edge by hand, it goes back there.
  @Test func anAppThatAnswersALittleOffDoesNotCostThePlace() throws {
    let h0 = Harness()
    let terminal = WindowID(101)
    h0.system.open(
      id: terminal, app: "Terminal", bundleID: "com.example.terminal", title: "Terminal", pid: 1001, frame: CGRect(x: 300, y: 150, width: 900, height: 600),
      maximumSize: CGSize(width: 896, height: 590))
    h0.start()
    h0.run("dock \(terminal.rawValue) left")
    settle(h0)
    let h = away(.pause, h0) {
      #expect($0.frame(terminal) == CGRect(x: 300, y: 150, width: 896, height: 590))
      $0.system.userMove(terminal, to: CGRect(x: 900, y: 150, width: 896, height: 590))
    }
    h.run("pause")
    #expect(h.frame(terminal) == CGRect(x: 900, y: 150, width: 896, height: 590))
  }

  /// Pulled at one edge, it has been given a size.
  @Test(arguments: [CGSize(width: -120, height: 0), CGSize(width: 0, height: -120)]) func oneEdgeIsEnoughForAResize(by change: CGSize) throws {
    let (old, _, browser) = twoDocked()
    let slot = try #require(old.frame(browser))
    old.system.setUnresponsive(pid: 1002, true)
    let given = CGRect(x: slot.minX, y: slot.minY, width: slot.width + change.width, height: slot.height + change.height)
    let h = away(.pause, old) {
      $0.system.setUnresponsive(pid: 1002, false)
      $0.system.userMove(browser, to: given)
    }
    #expect(h.workspace.undockedFrame(of: browser) == given)
  }

  /// Wider than the slot it was left in, it does not come back over an edge.
  @Test func itsOwnSizeDoesNotComeBackOverAnEdge() throws {
    let wide = CGRect(x: 100, y: 100, width: 1000, height: 500)
    let (old, editor, _) = twoDocked(editor: wide)
    let slot = try #require(old.frame(editor))
    let visible = FakeWindowSystem.standardDisplay.visibleFrame
    #expect(slot.width < wide.width)
    old.system.setUnresponsive(pid: 1001, true)
    let h = away(.pause, old) {
      $0.system.setUnresponsive(pid: 1001, false)
      $0.system.userMove(editor, to: slot.offsetBy(dx: visible.maxX - slot.maxX, dy: 0))
    }
    let remembered = try #require(h.workspace.undockedFrame(of: editor))
    #expect(remembered.size == wide.size)
    #expect(remembered.maxX == visible.maxX, "\(remembered)")
  }

  // MARK: Nobody has, or nobody can tell

  @Test(arguments: Away.allCases) func untouchedItKeepsWhatWasRemembered(how: Away) {
    let (old, editor, browser) = twoDocked()
    let h = away(how, old) { _ in }
    #expect(h.workspace.undockedFrame(of: editor) == Self.ownOfTheEditor)
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// Left in the shape of its slot and not touched, that shape is nobody's wish.
  @Test(arguments: Away.allCases) func leftInTheShapeOfItsSlotAndNotTouchedItKeepsWhatWasRemembered(how: Away) {
    let (old, _, browser) = twoDocked()
    old.system.setUnresponsive(pid: 1002, true)
    let h = away(how, old) { $0.system.setUnresponsive(pid: 1002, false) }
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// After a run that did not quit the windows are found in their slots, or wherever: nothing says where Arbor left them.
  @Test func afterARunThatDidNotQuitNobodyCanTell() {
    let (old, _, browser) = twoDocked()
    old.controller.saveNow()
    let h = old.newProcess()
    h.system.place(browser, at: Self.chosen)
    h.start()
    settle(h)
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// After a reboot the numbers start again. The browser is known again by its app and its title, under a number that was another window's when
  /// Arbor quit: one it does not arrange, but knew of. Where that one was left says nothing of this one.
  @Test func whereAnotherWindowOfThatNumberWasLeftSaysNothing() {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.panel"]
    let old = Harness(settings: settings)
    let browser = old.system.open(app: "Browser", pid: 1002, frame: Self.ownOfTheBrowser)
    let panel = old.system.open(app: "Panel", bundleID: "com.example.panel", pid: 1003, frame: CGRect(x: 520, y: 200, width: 400, height: 300))
    old.start()
    old.run("dock \(browser.rawValue) right")
    settle(old)
    old.controller.shutdown()
    let h = old.newProcess()
    h.system.close(panel)
    h.system.renumber(browser, as: panel)
    // Its app opens it where it sees fit.
    h.system.place(panel, at: CGRect(x: 200, y: 100, width: 800, height: 550))
    h.start()
    settle(h)
    #expect(h.workspace.isDocked(panel), "the browser, under its new number")
    #expect(h.workspace.undockedFrame(of: panel) == Self.ownOfTheBrowser)
  }

  /// The whole display is not its frame: macOS gives it its own again when it leaves full screen.
  @Test func fullScreenIsNoFrameOfItsOwn() {
    let (old, _, browser) = twoDocked()
    let h = away(.pause, old) { $0.system.setFullScreen(browser, true) }
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// Where nobody can see it, nobody chose to have it.
  @Test(arguments: Away.allCases) func outOfViewIsNoPlaceAnybodyChose(how: Away) {
    let (old, _, browser) = twoDocked()
    let display = FakeWindowSystem.standardDisplay.frame
    let h = away(how, old) {
      $0.system.place(browser, at: CGRect(x: display.maxX - 1, y: display.maxY - 1, width: 640, height: 380))
    }
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// A game takes the display to a resolution of its own, macOS fits every window onto it, and does not undo that when the game ends. Nobody tells
  /// Arbor, which is not listening. `pauseForApps` is for such apps, so a pause for an app writes nothing down: nobody can tell.
  @Test func whatMacOSMakesOfItDuringAPauseForAnAppIsNobodysWish() throws {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    let browser = h.system.open(app: "Browser", pid: 1002, frame: Self.ownOfTheBrowser)
    let game = h.system.open(app: "Game", bundleID: "com.example.game", pid: 1003, frame: CGRect(x: 0, y: 25, width: 400, height: 300))
    h.start()
    h.run("dock \(browser.rawValue) right")
    settle(h)
    h.system.userFocus(game)
    settle(h)
    try #require(h.controller.isPaused)
    #expect(h.frame(browser) == Self.ownOfTheBrowser)
    let usual = FakeWindowSystem.standardDisplay
    unheard(h) {
      h.system.setDisplays([
        DisplaySnapshot(
          id: usual.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 640), visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 615), isMain: true,
          isBuiltIn: true)
      ])
      h.system.place(browser, at: CGRect(x: 124, y: 25, width: 900, height: 600))
      h.system.setDisplays([usual])
    }
    h.system.userFocus(browser)
    settle(h)
    try #require(!h.controller.isPaused)
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// The scaling is changed during the pause, and stays. macOS fits the windows onto what there is now.
  @Test func withADisplayOfAnotherShapeThanArborLeftNobodyCanTell() {
    let (old, _, browser) = twoDocked()
    let usual = FakeWindowSystem.standardDisplay
    let h = away(.pause, old) {
      $0.system.setDisplays([
        DisplaySnapshot(
          id: usual.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 640), visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 615), isMain: true,
          isBuiltIn: true)
      ])
      $0.system.place(browser, at: CGRect(x: 124, y: 25, width: 900, height: 600))
    }
    #expect(h.workspace.undockedFrame(of: browser) == Self.ownOfTheBrowser)
  }

  /// A pause that outlives the process is a pause: what was given during it is learnt, as the file says where Arbor left the windows.
  @Test func givenDuringAPauseThatOutlivesTheProcessItIsLearnt() throws {
    let (old, _, browser) = twoDocked()
    old.run("pause")
    old.system.place(browser, at: Self.chosen)
    let h = old.newProcess(byTheWatchdog: true)
    h.start()
    try #require(h.controller.isPaused)
    h.run("resume")
    settle(h)
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
  }

  /// The Dock moves during the pause. macOS moves no window for that, and the displays are the ones Arbor left.
  @Test func theDockAndTheMenuBarAreNoPartOfADisplaysShape() {
    let (old, _, browser) = twoDocked()
    let usual = FakeWindowSystem.standardDisplay
    let h = away(.pause, old) {
      $0.system.setDisplays([
        DisplaySnapshot(id: usual.id, frame: usual.frame, visibleFrame: CGRect(x: 60, y: 25, width: 1380, height: 875), isMain: true, isBuiltIn: true)
      ])
      $0.system.userMove(browser, to: Self.chosen)
    }
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
  }

  /// Docked at the desk. The display is unplugged, and Arbor is quit on the lap. Back at the desk macOS puts the window on the display that is back, as it
  /// was there: in the shape of its slot. Arbor starts, and docks it again. The displays are not the ones Arbor left: nobody can tell.
  @Test func whatMacOSPutsBackOnADisplayThatReturnsIsNobodysWish() throws {
    let lap = DisplaySnapshot(
      id: DisplayID("lap"), frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 37, width: 1512, height: 945), isMain: true)
    let desk = DisplaySnapshot(
      id: DisplayID("desk"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415),
      isMain: true)
    let old = Harness(displays: [desk])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: Self.ownOfTheEditor)
    old.start()
    old.run("dock \(editor.rawValue) left")
    settle(old)
    let slot = try #require(old.frame(editor))
    old.system.setDisplays([lap])
    settle(old)
    old.controller.shutdown()
    let h = old.newProcess()
    h.system.setDisplays([desk])
    h.system.place(editor, at: slot)
    h.start()
    settle(h)
    try #require(h.controller.workspaces[desk.id]?.isDocked(editor) == true)
    #expect(h.controller.workspaces[desk.id]?.undockedFrame(of: editor) == Self.ownOfTheEditor)
  }

  /// Docked on the display that stays. The one beside it is unplugged, Arbor is quit, and the display is plugged in again: macOS gives the windows the
  /// frames they had the last time these displays were connected, when this one was in its slot.
  @Test func whatMacOSMakesOfItWhenADisplayComesBackBesideItIsNobodysWish() throws {
    let usual = FakeWindowSystem.standardDisplay
    let beside = DisplaySnapshot(
      id: DisplayID("beside"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      isMain: false)
    let old = Harness(displays: [usual, beside])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: Self.ownOfTheEditor)
    old.start()
    old.run("dock \(editor.rawValue) left")
    settle(old)
    let slot = try #require(old.frame(editor))
    old.system.setDisplays([usual])
    settle(old)
    old.controller.shutdown()
    let h = old.newProcess()
    h.system.setDisplays([usual, beside])
    h.system.place(editor, at: slot)
    h.start()
    settle(h)
    try #require(h.workspace.isDocked(editor))
    #expect(h.workspace.undockedFrame(of: editor) == Self.ownOfTheEditor)
  }

  // MARK: From then on

  /// Undo takes back a step in the arrangement. What its person gave the window meanwhile is no part of that.
  @Test func takingAStepBackDoesNotTakeTheFrameBack() {
    let (old, editor, browser) = twoDocked()
    old.run("swap \(editor.rawValue) \(browser.rawValue)")
    settle(old)
    let h = away(.pause, old) { $0.system.userMove(browser, to: Self.chosen) }
    #expect(h.run("undo").ok)
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
    #expect(h.run("redo").ok)
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
    h.run("pause")
    #expect(h.frame(browser) == Self.chosen)
  }

  /// From the chaos lab's list of known failures, which it leaves: arranged, floated, made wider by hand, and both steps taken back.
  @Test func undoDoesNotTakeBackAResizeThatAHandMade() {
    let found = ChaosRunner.replay(
      ChaosAction.script(
        """
        launch
        open 101 Mail pid 1002 at 368 293 957 595 min 760 400
        key down arrange
        key down float-all
        edge 101 368 293 1274 595
        key down undo
        key down undo
        way-back float-all
        """), excusing: ChaosRunner.knownRules.subtracting(["size-not-given-back"]))
    #expect(found == nil, "\(String(describing: found?.violations))")
  }

  /// Learnt once. What the start found is nothing a later start may go by.
  @Test func theNextTimeItIsUntouchedItKeepsTheFrameItWasGiven() {
    let (old, _, browser) = twoDocked()
    var h = away(.pause, old) { $0.system.userMove(browser, to: Self.chosen) }
    h = away(.quit, h) { _ in }
    h = away(.pause, h) { _ in }
    #expect(h.workspace.undockedFrame(of: browser) == Self.chosen)
    #expect(h.controller.invariantViolations().isEmpty)
  }
}
