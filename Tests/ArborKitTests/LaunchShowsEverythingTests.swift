import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// No surprises at start. A first start moves nothing. A later one brings back what was docked, one move per window, and
/// ends showing everything: whatever the view was when Arbor stopped, no window is out of view after a launch, and a
/// window that was never docked is not moved at all. The watchdog's restart, a second after an accident, keeps the view and moves
/// nothing. One sentence covers both (collab/QUESTIONS.md, Q16): starting Arbor takes no window out of view that is in view.
/// The end of a pause is no such start: it brings back the view that the pause interrupted.
@Suite @MainActor struct LaunchShowsEverythingTests {
  /// [editor | Desktop | browser], framed on the editor. The notes were never docked: they float, so they are out of view
  /// with the Desktop, as the browser is.
  func framedOnTheEditor(
    displays: [DisplaySnapshot] = [main], at origin: CGPoint = .zero
  ) -> (h: Harness, editor: WindowID, browser: WindowID, notes: WindowID) {
    func frame(_ x: CGFloat, _ y: CGFloat) -> CGRect { CGRect(x: origin.x + x, y: origin.y + y, width: 500, height: 400) }
    let h = Harness(displays: displays)
    let editor = h.system.open(app: "Editor", pid: 1001, frame: frame(60, 80))
    let browser = h.system.open(app: "Browser", pid: 1002, frame: frame(700, 120))
    let notes = h.system.open(app: "Notes", pid: 1003, frame: frame(420, 300))
    h.start()
    #expect(h.system.frameLog.isEmpty, "a first start moves nothing: \(h.system.frameLog)")
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    settle(h)
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    #expect(!h.system.isVisible(browser) && !h.system.isVisible(notes), "the view is on the editor alone")
    return (h, editor, browser, notes)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  /// A new Arbor process on the same Mac, whose moves are counted from here.
  func newProcess(after old: Harness, byTheWatchdog: Bool = false) -> Harness {
    let new = old.newProcess(byTheWatchdog: byTheWatchdog)
    new.system.clearFrameLog()
    return new
  }

  func moves(of window: WindowID, _ h: Harness) -> Int { h.system.frameLog.filter { $0.window == window }.count }

  func expectEverythingShows(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
    for (id, workspace) in h.controller.workspaces {
      #expect(workspace.camera == workspace.tree.root, "\(id)", sourceLocation: sourceLocation)
    }
    #expect(h.controller.parked.isEmpty, "\(h.controller.parked)", sourceLocation: sourceLocation)
    for window in h.system.allWindows() {
      #expect(h.system.isVisible(window.id), "\(window.id) at \(window.frame)", sourceLocation: sourceLocation)
    }
    expectWindowsMatchLayout(h, sourceLocation: sourceLocation)
  }

  // MARK: A person starts Arbor

  @Test func quitWhileFramedAndLaunchedAgainEverythingShows() {
    let (old, editor, browser, notes) = framedOnTheEditor()
    old.controller.shutdown()
    let place = old.frame(notes)
    let mark = old.system.moveLog.count

    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.workspace.isDocked(editor) && h.workspace.isDocked(browser), "what was docked is docked")
    #expect(h.frame(editor)!.maxX < h.frame(browser)!.minX)
    // Besides the question a new run has to put to each where the quit left it.
    #expect(movesWithoutWaste(h, of: editor, since: mark) == 1 && movesWithoutWaste(h, of: browser, since: mark) == 1, "one move each: \(h.system.frameLog)")
    #expect(moves(of: notes, h) == 0, "never docked, so not moved: \(h.system.frameLog)")
    #expect(h.frame(notes) == place)
  }

  @Test func theViewOfLastTimeIsOneStepBackAndWhatWasKeptIsKept() {
    let (old, editor, browser, _) = framedOnTheEditor()
    old.run("save-view 1")
    old.run("name writing")
    old.run("zoom \(browser.rawValue)")
    settle(old)
    let (views, names, framed) = (old.workspace.savedViews, old.workspace.names, old.workspace.camera)
    let earlier = old.workspace.back
    old.controller.shutdown()

    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.workspace.savedViews == views && !views.isEmpty)
    #expect(h.workspace.names == names && !names.isEmpty)
    #expect(h.workspace.back == earlier + [framed], "history stays, and goes on with the view Arbor was quit in")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == framed)
    #expect(h.layout?.windowFrames.keys.sorted() == [browser])
    #expect(h.run("view 1").ok)
    #expect(h.layout?.windowFrames.keys.sorted() == [editor])
  }

  /// Killed, both processes, or the power went: nothing was put back, and the browser and the notes are past the corner.
  @Test func startedByAPersonAfterItDiedEverythingShows() {
    let (old, editor, browser, notes) = framedOnTheEditor()
    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    for window in [editor, browser, notes] { #expect(moves(of: window, h) == 1, "\(window): \(h.system.frameLog)") }
  }

  /// A quit during a pause leaves the file of the pause, with the view that `resume` would have brought back.
  @Test func quitDuringAPauseAndLaunchedAgainEverythingShows() {
    let (old, _, _, notes) = framedOnTheEditor()
    #expect(old.run("pause").ok)
    old.controller.shutdown()
    let place = old.frame(notes)

    let h = newProcess(after: old)
    h.start()
    settle(h)
    #expect(h.controller.isRunning)
    expectEverythingShows(h)
    #expect(h.frame(notes) == place && moves(of: notes, h) == 0)
  }

  /// Quitting brings a window that `summon` had sent away into view like every other, and a launch leaves it there.
  @Test func aWindowThatWasSentAwayIsAnOrdinaryWindowAfterALaunch() {
    let (old, editor, _, notes) = framedOnTheEditor()
    #expect(old.run("summon Notes").ok)
    old.system.userFocus(editor)
    settle(old)
    #expect(old.controller.role(of: notes) == .stashed && !old.system.isVisible(notes))
    old.controller.shutdown()
    let place = old.frame(notes)

    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.controller.role(of: notes) == nil)
    #expect(h.frame(notes) == place && moves(of: notes, h) == 0)
    // It can be summoned as before, and comes where it was summoned last.
    #expect(h.run("zoom \(editor.rawValue)").ok)
    #expect(h.run("summon Notes").ok)
    #expect(h.system.isVisible(notes) && h.system.focused == notes)
  }

  // MARK: Login

  /// Arbor starts at login before the apps have brought their windows back, which have new numbers.
  @Test func windowsThatTheirAppsRestoreLateComeIntoViewToo() {
    let (old, editor, browser, _) = framedOnTheEditor()
    let (wasEditor, wasBrowser) = (old.controller.windows[editor]!, old.controller.windows[browser]!)
    old.controller.shutdown()

    let h = Harness(saved: old.store.saved)
    for _ in 0..<6 { h.system.open(app: "Filler", frame: CGRect(x: 500, y: 300, width: 300, height: 200)) }
    h.start()
    settle(h)
    #expect(h.system.frameLog.isEmpty, "nothing that is open was ever docked: \(h.system.frameLog)")
    func reopen(_ window: WindowSnapshot) -> WindowID {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid,
        frame: CGRect(x: 200, y: 150, width: 500, height: 300))
    }
    // The one the saved view left out comes first.
    let newBrowser = reopen(wasBrowser)
    settle(h)
    expectEverythingShows(h)
    #expect(h.workspace.isDocked(newBrowser))
    let newEditor = reopen(wasEditor)
    settle(h)
    expectEverythingShows(h)
    #expect(h.workspace.isDocked(newEditor) && h.frame(newEditor)!.maxX < h.frame(newBrowser)!.minX)
  }

  // MARK: Displays

  /// Quit at the desk framed on the second display, started on the sofa, back at the desk.
  @Test func anArrangementWhoseDisplayIsGoneAtLaunchComesBackShowingEverything() {
    let (old, editor, browser, _) = framedOnTheEditor(displays: [main, side], at: side.frame.origin)
    #expect(old.controller.workspaces[side.id]?.isDocked(editor) == true)
    old.controller.shutdown()
    // macOS brings the windows of a display that goes over to the one that stays.
    old.system.setDisplays([main])

    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    h.system.setDisplays([main, side])
    settle(h)
    expectEverythingShows(h)
    #expect(h.controller.workspaces[side.id]?.isDocked(editor) == true)
    #expect(h.controller.workspaces[side.id]?.isDocked(browser) == true)
  }

  /// Unplugged while framed, quit on the sofa, started at the desk.
  @Test func anArrangementWhoseDisplayIsBackAtLaunchComesBackShowingEverything() {
    let (old, editor, browser, _) = framedOnTheEditor(displays: [main, side], at: side.frame.origin)
    old.system.setDisplays([main])
    settle(old)
    #expect(old.controller.dormant[side.id] != nil)
    old.controller.shutdown()
    old.system.setDisplays([main, side])

    let h = newProcess(after: old)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.controller.workspaces[side.id]?.isDocked(editor) == true)
    #expect(h.controller.workspaces[side.id]?.isDocked(browser) == true)
  }

  // MARK: Nobody quit

  /// The watchdog starts Arbor again a second after it died. The person was in the middle of something.
  @Test func startedAgainByTheWatchdogNothingMovesAndTheViewStays() {
    let (old, editor, _, _) = framedOnTheEditor()
    let camera = old.workspace.camera
    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    settle(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.workspace.camera == camera)
    #expect(h.layout?.windowFrames.keys.sorted() == [editor])
    expectWindowsMatchLayout(h)
  }

  /// The file is written half a second after a change. ⌃⌥0, and Arbor dies before that: the file has the view on the editor,
  /// and everything is in view.
  @Test func startedAgainByTheWatchdogWithAFileThatIsBehindNothingGoesOutOfView() {
    let (old, _, _, _) = framedOnTheEditor()
    old.controller.saveNow()
    let behind = old.store.saved
    old.run("show-all")
    old.store.saved = behind
    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.system.frameLog.isEmpty, "everything is where it belongs: \(h.system.frameLog)")
  }

  /// Only the notes: somebody fetched them from Mission Control, or their app brought them forward.
  @Test func startedAgainByTheWatchdogWithAFloatingWindowBackInViewNothingGoesOutOfView() {
    let (old, _, _, notes) = framedOnTheEditor()
    let place = CGRect(x: 420, y: 300, width: 500, height: 400)
    let h = newProcess(after: old, byTheWatchdog: true)
    h.system.userMove(notes, to: place)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.frame(notes) == place && moves(of: notes, h) == 0)
  }

  /// Everything shows, in the file too, which still has the notes as sent away: ⌃⌥0 fetched them, and Arbor died before the save.
  @Test func startedAgainByTheWatchdogWithAFileThatStillHasAWindowAsSentAwayItStaysInView() {
    let (old, editor, _, notes) = framedOnTheEditor()
    old.run("show-all")
    #expect(old.run("summon Notes").ok)
    old.system.userFocus(editor)
    settle(old)
    #expect(old.controller.role(of: notes) == .stashed && !old.system.isVisible(notes))
    old.controller.saveNow()
    let behind = old.store.saved
    old.run("home")
    #expect(old.system.isVisible(notes))
    let place = old.frame(notes)
    old.store.saved = behind

    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    settle(h)
    expectEverythingShows(h)
    #expect(h.controller.role(of: notes) == nil)
    #expect(h.frame(notes) == place && moves(of: notes, h) == 0)
  }

  @Test func theEndOfAPauseBringsTheViewBack() {
    let (h, editor, _, _) = framedOnTheEditor()
    let camera = h.workspace.camera
    #expect(h.run("pause").ok)
    #expect(h.run("resume").ok)
    settle(h)
    #expect(h.workspace.camera == camera)
    #expect(h.layout?.windowFrames.keys.sorted() == [editor])
  }
}
