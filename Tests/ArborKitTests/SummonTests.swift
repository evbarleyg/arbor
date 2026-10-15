import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay

/// Summoning (docs/features/F53-summon.md).
@Suite @MainActor struct SummonTests {
  /// [editor | Desktop | browser], framed on the editor, which has the keyboard. The terminal floats, so it is
  /// out of view with the Desktop.
  func makeHarness(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()
  ) -> (Harness, editor: WindowID, browser: WindowID, terminal: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let terminal = h.system.open(
      app: "Terminal", bundleID: "com.apple.Terminal", pid: 1003, frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    h.system.clearFrameLog()
    return (h, editor, browser, terminal)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 1) }

  /// In the middle of the main display at the terminal's own size: where it is summoned the first time.
  var middle: CGRect {
    let visible = FakeWindowSystem.standardDisplay.visibleFrame
    return CGRect(x: visible.midX - 200, y: (visible.midY - 150).rounded(.down), width: 400, height: 300)
  }

  func isOutOfView(_ window: WindowID, _ h: Harness) -> Bool {
    h.controller.parked.contains(window) && !h.system.isVisible(window)
  }

  /// The same windows (numbers, apps, titles, frames) seen by a new Arbor process that loads what `old` saved.
  func relaunch(_ old: Harness, displays: [DisplaySnapshot]? = nil, byTheWatchdog: Bool = false) -> Harness {
    let new = Harness(displays: displays ?? old.system.displayList, saved: old.store.saved)
    for window in old.system.allWindows() {
      new.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    new.controller.restartedAfterAccident = byTheWatchdog
    new.start()
    return new
  }

  // MARK: 1. Over the view

  @Test func summoningBringsTheAppsWindowOverTheViewWithTheKeyboardInIt() {
    let (h, editor, browser, terminal) = makeHarness()
    #expect(isOutOfView(terminal, h))
    let camera = h.workspace.camera
    let others = [editor, browser].map { h.frame($0) }

    #expect(h.run("summon Terminal").message == "summoned Terminal (\(terminal))")
    #expect(h.frame(terminal) == middle, "the first time: centred, at its own size")
    #expect(!h.controller.parked.contains(terminal))
    #expect(h.system.focused == terminal)
    #expect(h.system.windowsFrontToBack().first == terminal)
    #expect(h.workspace.camera == camera, "the view does not move")
    #expect([editor, browser].map { h.frame($0) } == others, "nor does any other window")
    #expect(h.system.frameLog.map(\.window) == [terminal], "one move")
    #expect(h.workspace.isFloating(terminal))
  }

  @Test func theAppCanBeNamedByBundleIDOrNameInAnyCase() {
    for name in ["Terminal", "terminal", "com.apple.Terminal", "COM.APPLE.TERMINAL"] {
      let (h, _, _, terminal) = makeHarness()
      #expect(h.run("summon \(name)").ok, "\(name)")
      #expect(h.workspace.isSummoned(terminal), "\(name)")
    }
  }

  @Test func ofSeveralWindowsTheOneUsedLastComes() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("show-all")
    let second = h.system.open(app: "Terminal", bundleID: "com.apple.Terminal", pid: 1003)
    h.system.userFocus(second)
    h.system.userFocus(terminal)
    h.system.userFocus(editor)
    h.run("zoom \(editor.rawValue)")
    h.run("summon Terminal")
    #expect(h.workspace.isSummoned(terminal))
    #expect(isOutOfView(second, h))
  }

  @Test func inViewWithTheKeyboardInItItIsSummonedWhereItIs() {
    // Someone is typing in it. The first press must not make it jump, over a docked window at that.
    let (h, _, _, terminal) = makeHarness()
    h.run("show-all")
    let place = CGRect(x: 530, y: 500, width: 400, height: 300)
    h.system.userMove(terminal, to: place)
    h.system.userFocus(terminal)
    h.system.clearFrameLog()
    #expect(h.run("summon Terminal").ok)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == place)
    #expect(h.workspace.summonFrames?["com.apple.Terminal"] == place, "and that is where it comes next time")
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == place)
  }

  @Test func aNewWindowWithTheKeyboardStaysWhereItsAppOpenedItUnlessTheAppHasAPlace() {
    let (h, _, _, terminal) = makeHarness()
    let opened = CGRect(x: 100, y: 100, width: 300, height: 400)
    let notes = h.system.open(app: "Notes", pid: 1004, frame: opened)
    #expect(h.system.focused == notes)
    h.run("summon Notes")
    #expect(h.frame(notes) == opened, "nothing is remembered, so there is no reason to move it")

    // Terminal has a place. Its next window goes there, wherever the app opens it.
    h.run("summon Terminal")
    h.system.close(terminal)
    let next = h.system.open(app: "Terminal", bundleID: "com.apple.Terminal", pid: 2003, frame: opened)
    #expect(h.system.focused == next)
    h.run("summon Terminal")
    #expect(h.frame(next) == middle)
  }

  @Test func inViewWithoutTheKeyboardItComesToItsPlace() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("show-all")
    h.system.userMove(terminal, to: CGRect(x: 530, y: 500, width: 400, height: 300))
    h.system.userFocus(editor)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle)
  }

  // MARK: 2. Again

  @Test func summoningAgainSendsItOutOfViewAndTheKeyboardBack() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let camera = h.workspace.camera
    #expect(h.run("summon Terminal").message == "sent Terminal away; summon it again, or ⌘Tab to it")
    #expect(isOutOfView(terminal, h))
    #expect(h.system.focused == editor)
    #expect(h.workspace.camera == camera)
    #expect(h.frame(editor) == h.visibleFrame.insetBy(dx: 12, dy: 12))

    // And so on.
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle && h.system.focused == terminal)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h) && h.system.focused == editor)
  }

  @Test func itGoesOutOfViewEvenWhereTheDesktopIsInView() {
    // Or the shortcut would do nothing the second time in any view that includes the Desktop.
    let (h, _, _, terminal) = makeHarness()
    for view in ["show-all", "desktop"] {
      h.run(view)
      h.run("summon Terminal")
      #expect(h.system.isVisible(terminal), "\(view)")
      h.run("summon Terminal")
      #expect(isOutOfView(terminal, h), "\(view)")
    }
  }

  @Test func sentAwayItStaysOutOfViewWhateverTheCameraShows() {
    let (h, editor, browser, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    for step in ["show-all", "desktop", "back", "zoom \(browser.rawValue)", "out", "relayout", "float \(editor.rawValue)"] {
      #expect(h.run(step).ok, "\(step)")
      settle(h)
      #expect(isOutOfView(terminal, h), "after \(step)")
    }
    #expect(h.run("status").message.contains("1 out of view"), "and is counted, so that it is not taken for lost")
  }

  @Test func pulledOutOfItsCornerItGoesBackWithTheNextMoveOfTheViewAndNotWhileThatIsPlanned() {
    let (h, _, browser, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    settle(h)
    // macOS sometimes pulls a window that is mostly off screen back onto it.
    h.system.userMove(terminal, to: CGRect(x: 520, y: 300, width: 400, height: 300))
    let moved = h.system.frameLog.count
    var movedByThen: Int?
    h.overlays.onAnimate = { _ in movedByThen = movedByThen ?? h.system.frameLog.count }
    h.run("zoom \(browser.rawValue)")
    // The motion is planned from where the windows are (F02), so making the plan moves nothing.
    #expect(movedByThen == moved)
    #expect(isOutOfView(terminal, h))
    #expect(h.system.frameLog.dropFirst(moved).filter { $0.window == terminal }.count == 1, "and it is moved once")
  }

  @Test func homeBringsItBackToTheDesktopAsAnOrdinaryWindow() {
    // "A window is gone: ⌃⌥0" has no exception.
    let (h, editor, _, terminal) = makeHarness(displays: [main, side])
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 1600, y: 100, width: 300, height: 400))
    // A new window takes the keyboard, and commands act on the display that has it (F56): back to the main one.
    h.system.userFocus(editor)
    h.run("summon Terminal")
    h.run("summon Terminal")
    #expect(h.controller.workspaces[main.id]!.isStashed(terminal))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Notes")
    h.run("summon Notes")
    #expect(h.controller.workspaces[side.id]!.isStashed(notes))
    #expect(isOutOfView(terminal, h) && isOutOfView(notes, h))

    #expect(h.run("home").ok)
    for window in [terminal, notes] {
      #expect(h.system.isVisible(window) && !h.controller.parked.contains(window), "\(window)")
      #expect(h.controller.role(of: window) == nil, "\(window)")
    }
    #expect(h.layout!.desktopFrame!.contains(h.frame(terminal)!), "on the Desktop, like any floating window")

    // It leaves with the Desktop again, and can be summoned again, to the place it had.
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("zoom \(editor.rawValue)")
    #expect(isOutOfView(terminal, h))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle)
  }

  @Test func homeWorksWhenEverythingIsShowingAlready() {
    let (h, _, _, terminal) = makeHarness()
    h.run("show-all")
    h.run("summon Terminal")
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    h.run("home")
    #expect(h.system.isVisible(terminal))
  }

  @Test func homeMakesTheSummonedWindowAnOrdinaryWindowToo() {
    // The keyboard goes along with the view, which would send it away: after ⌃⌥0 nothing may be out of view.
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("home")
    settle(h)
    #expect(h.workspace.role(of: terminal) == nil)
    #expect(h.system.isVisible(terminal) && h.controller.parked.isEmpty)
  }

  @Test func pulledBackIntoViewByMacOSItGoesOutOfViewAgain() {
    // Seen on real windows: when a window leaves full screen, macOS moves its app's windows that are off screen onto it.
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    h.system.userMove(terminal, to: CGRect(x: 300, y: 300, width: 400, height: 300))
    settle(h)
    #expect(isOutOfView(terminal, h))
    #expect(h.workspace.summonFrames?["com.apple.Terminal"] == middle, "and that is not taken for the user's choice of place")
  }

  @Test func ifTheWindowThatHadTheKeyboardIsGoneAWindowInViewGetsIt() {
    let (h, editor, browser, _) = makeHarness()
    h.run("summon Terminal")
    h.system.close(editor)
    h.run("summon Terminal")
    #expect(h.system.focused == browser)
  }

  @Test func summonedWhileItHadTheKeyboardOnTheDesktopTheKeyboardGoesToTheWindowBeforeIt() {
    let (h, _, browser, terminal) = makeHarness()
    h.run("show-all")
    // Not the window a camera move would choose (the one nearest the top left corner): this is memory, not luck.
    h.system.userFocus(browser)
    h.system.userFocus(terminal)
    h.run("summon Terminal")
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    #expect(h.system.focused == browser)
  }

  // MARK: 3. Turning to something else

  @Test func turningToAnotherWindowSendsItAway() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.userFocus(editor)
    #expect(isOutOfView(terminal, h))
    #expect(h.workspace.isStashed(terminal))
    #expect(h.system.focused == editor, "the keyboard stays where the user put it")
  }

  @Test func switchingToAWindowThatIsOutOfViewSendsItAwayAndMovesTheCameraAsEver() {
    let (h, _, browser, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.userFocus(browser)
    #expect(isOutOfView(terminal, h))
    #expect(h.system.isVisible(browser))
  }

  @Test func withSummonStaysItStaysUntilSummonedAway() {
    var settings = Settings()
    settings.summonStays = true
    let (h, editor, browser, terminal) = makeHarness(settings: settings)
    h.run("summon Terminal")
    h.system.userFocus(editor)
    settle(h)
    #expect(h.frame(terminal) == middle)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.system.windowsFrontToBack().first == terminal, "and is not buried by the click, like a pinned window")
    #expect(h.system.focused == editor)

    // Through camera moves as well.
    for step in ["neighbor right", "neighbor right", "show-all", "zoom \(browser.rawValue)"] {
      h.run(step)
      settle(h)
      #expect(h.frame(terminal) == middle, "after \(step)")
    }
    let keyboard = h.system.focused
    #expect(h.run("summon Terminal").ok)
    #expect(isOutOfView(terminal, h))
    #expect(h.system.focused == keyboard, "the keyboard was elsewhere already")
  }

  @Test func withSummonStaysAClickInTheWindowThatAlreadyHasTheKeyboardDoesNotBuryIt() {
    // Every click in the editor one is working in: it comes to the front, and macOS reports no change of focus.
    var settings = Settings()
    settings.summonStays = true
    let (h, editor, _, terminal) = makeHarness(settings: settings)
    h.run("summon Terminal")
    h.system.userFocus(editor)
    settle(h)
    h.system.clearRaiseLog()
    h.system.userClick(editor)
    #expect(h.system.windowsFrontToBack().first == editor)
    settle(h)
    #expect(h.system.windowsFrontToBack().first == terminal)
    #expect(h.system.raiseLog == [terminal], "once")
    #expect(h.system.focused == editor)
    #expect(h.workspace.isSummoned(terminal))
  }

  @Test func summonedAwayWhileTheKeyboardIsElsewhereTheKeyboardStaysThere() {
    var settings = Settings()
    settings.summonStays = true
    let (h, _, browser, terminal) = makeHarness(settings: settings)
    h.run("show-all")
    h.run("summon Terminal")
    h.system.userFocus(browser)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    #expect(h.system.focused == browser, "not back in the editor, which had it before and is in view")
  }

  @Test func ifTheWindowThatHadTheKeyboardIsOutOfViewByThenAWindowInViewGetsItAndTheViewStays() {
    var settings = Settings()
    settings.summonStays = true
    let (h, _, browser, terminal) = makeHarness(settings: settings)
    h.run("summon Terminal")
    h.run("neighbor right")
    h.run("neighbor right")
    h.system.userFocus(terminal)
    let camera = h.workspace.camera
    h.run("summon Terminal")
    #expect(h.system.focused == browser)
    #expect(h.workspace.camera == camera, "giving it to the editor would bring the editor into view")
  }

  @Test func aCommandThatMovesTheViewTakesTheKeyboardAlongWhichSendsItAway() {
    // As for a pinned window: a command that moves the view says where the attention goes.
    let (h, _, browser, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("neighbor right")
    #expect(h.workspace.isSummoned(terminal) && h.system.focused == terminal, "nothing has arrived on the empty Desktop")
    h.run("neighbor right")
    #expect(h.system.focused == browser)
    #expect(isOutOfView(terminal, h))
  }

  @Test func theFrameShortcutInASummonedWindowUnframesWhatIsBeneath() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    #expect(h.run("zoom \(terminal.rawValue)").message == "\(terminal) is summoned; dock it to give it a place")
    #expect(h.run("zoom").ok)
    #expect(h.workspace.camera == h.workspace.tree.root, "not the Desktop, where it does not live")
  }

  @Test func anotherWindowOfTheSameAppDoesNotSendItAway() {
    // Its settings, a second terminal window, a dialog that is a window of its own: still the same visit.
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let settings = h.system.open(app: "Terminal", bundleID: "com.apple.Terminal", title: "Settings", pid: 1003)
    h.system.userFocus(settings)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
  }

  @Test func aFocusReportFromTheBackgroundDoesNotSendItAway() {
    let (h, _, browser, terminal) = makeHarness()
    h.run("summon Terminal")
    h.controller.windowFocused(browser)
    #expect(h.system.focused == terminal)
    #expect(h.workspace.isSummoned(terminal))
  }

  @Test func summoningAnotherAppReplacesItAndTheKeyboardGoesBackToWhereItWasBeforeBoth() {
    let (h, _, browser, terminal) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 100, y: 100, width: 300, height: 400))
    h.run("show-all")
    h.system.userFocus(browser)
    h.run("summon Terminal")
    h.run("summon Notes")
    #expect(isOutOfView(terminal, h))
    #expect(h.workspace.isSummoned(notes) && h.workspace.isStashed(terminal))
    #expect(h.system.focused == notes)
    h.run("summon Notes")
    #expect(isOutOfView(notes, h))
    #expect(h.system.focused == browser)
  }

  // MARK: 4. It remembers where it was

  @Test func movedOrResizedWhileSummonedItReturnsToThatFrame() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let chosen = CGRect(x: 40, y: 500, width: 900, height: 350)
    h.system.userMove(terminal, to: chosen)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == chosen)

    // Sent away by a click, and dragged by its title bar, it is the same.
    h.system.drag(terminal, through: [CGPoint(x: 490, y: 510), CGPoint(x: 600, y: 300), CGPoint(x: 700, y: 110)])
    let dropped = h.frame(terminal)!
    h.system.userFocus(editor)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == dropped)
  }

  @Test func theFrameIsRememberedAcrossARestartAndForTheAppsNextWindow() throws {
    let (old, _, _, terminal) = makeHarness()
    old.run("summon Terminal")
    let chosen = CGRect(x: 40, y: 500, width: 900, height: 350)
    old.system.userMove(terminal, to: chosen)
    old.run("summon Terminal")
    old.controller.shutdown()

    // Through the file, not only through memory.
    let data = try JSONEncoder().encode(try #require(old.store.saved))
    old.store.saved = try JSONDecoder().decode(PersistedState.self, from: data)
    let h = relaunch(old)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == chosen)

    // The app restarted: another window, another number, the same place.
    h.system.close(terminal)
    let next = h.system.open(app: "Terminal", bundleID: "com.apple.Terminal", pid: 2003)
    h.run("summon Terminal")
    #expect(h.frame(next) == chosen)
  }

  @Test func aRememberedFrameThatNoLongerFitsIsFittedIntoTheDisplay() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.userMove(terminal, to: CGRect(x: 900, y: 500, width: 500, height: 350))
    h.run("summon Terminal")
    let small = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)
    h.system.setDisplays([small])
    h.run("summon Terminal")
    #expect(h.frame(terminal)!.fractionInside(small.visibleFrame) > 0.99)
  }

  @Test func whatTheAppMakesOfTheFrameIsWhatIsRemembered() {
    let (h, _, _, terminal) = makeHarness()
    h.system.setMinimumSize(terminal, CGSize(width: 600, height: 400))
    h.run("summon Terminal")
    #expect(h.frame(terminal)!.size == CGSize(width: 600, height: 400))
    #expect(h.workspace.summonFrames?["com.apple.Terminal"] == h.frame(terminal))
  }

  // MARK: 5. No window yet

  @Test func anAppWithoutAWindowIsAskedToOpenAndItsWindowIsSummonedWhenItAppears() {
    let (h, editor, _, _) = makeHarness()
    let camera = h.workspace.camera
    #expect(h.run("summon Notes").message == "opening Notes")
    #expect(h.system.openRequests == ["Notes"])
    #expect(h.system.focused == editor, "nothing has happened yet")

    h.scheduler.advance(by: 4.9)
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 10, y: 30, width: 300, height: 400))
    #expect(h.workspace.isSummoned(notes))
    #expect(abs(h.frame(notes)!.midX - h.visibleFrame.midX) <= 1 && abs(h.frame(notes)!.midY - h.visibleFrame.midY) <= 1)
    #expect(h.system.focused == notes)
    #expect(h.workspace.camera == camera)
    h.run("summon Notes")
    #expect(isOutOfView(notes, h))
    #expect(h.system.focused == editor)
  }

  @Test func aWindowThatComesTooLateIsAnOrdinaryNewWindow() {
    let (h, _, _, _) = makeHarness()
    h.run("summon Notes")
    h.scheduler.advance(by: 5.1)
    let frame = CGRect(x: 10, y: 30, width: 300, height: 400)
    let notes = h.system.open(app: "Notes", pid: 1004, frame: frame)
    #expect(h.workspace.role(of: notes) == nil)
    #expect(h.frame(notes) == frame)
  }

  @Test func anotherAppsNewWindowIsNotTakenForIt() {
    let (h, _, _, _) = makeHarness()
    h.run("summon Notes")
    let mail = h.system.open(app: "Mail", pid: 1005)
    #expect(h.workspace.role(of: mail) == nil)
    let notes = h.system.open(app: "Notes", pid: 1004)
    #expect(h.workspace.isSummoned(notes))
  }

  @Test func anAppThatIsNotInstalledIsAFailureThatSaysSo() {
    let (h, _, _, _) = makeHarness()
    h.system.missingApps = ["Nothing"]
    #expect(h.run("summon Nothing").message == "no app called Nothing: use its name as the Dock shows it, or its bundle id")
    #expect(!h.scheduler.pendingKeys.contains("summon-wait"))
  }

  @Test func aMinimizedWindowIsAskedForAndSummonedWhenItIsBack() {
    let (h, _, _, terminal) = makeHarness()
    h.system.setMinimized(terminal, true)
    #expect(h.run("summon Terminal").message == "opening Terminal")
    #expect(h.system.openRequests == ["Terminal"])
    h.run("relayout")
    #expect(h.workspace.summoned == nil, "not while it is still in the Dock")
    h.system.setMinimized(terminal, false)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
    #expect(h.system.focused == terminal)
  }

  @Test func aHiddenAppIsAskedForAndItsWindowSummonedWhenItShows() {
    let (h, _, _, terminal) = makeHarness()
    h.system.setHidden(pid: 1003, true)
    #expect(h.run("summon Terminal").message == "opening Terminal")
    h.system.setHidden(pid: 1003, false)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
  }

  @Test func aRuleThatDocksTheNewWindowWins() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.notes", action: .dock(.right))]
    let (h, _, _, _) = makeHarness(settings: settings)
    h.run("summon Notes")
    let notes = h.system.open(app: "Notes", pid: 1004)
    #expect(h.workspace.isDocked(notes))
    #expect(h.workspace.summoned == nil)
    #expect(h.system.focused == notes)
    #expect(h.layout?.windowFrames[notes] != nil, "it is in view")
  }

  // MARK: Docked, pinned, not arranged

  @Test func aDockedWindowHasAPlaceAndThePlaceWins() {
    let (h, _, browser, _) = makeHarness()
    #expect(h.run("summon Browser").message == "Browser is docked: showing it where it is")
    #expect(h.workspace.isDocked(browser))
    #expect(h.layout?.windowFrames[browser] != nil, "the view moved to it, as ⌘Tab would have it")
    #expect(h.system.focused == browser)
    #expect(h.workspace.summoned == nil)
  }

  @Test func goingToADockedOrPinnedWindowThatWaySendsTheSummonedOneAway() {
    let (h, _, _, terminal) = makeHarness()
    let call = h.system.open(app: "Zoom", pid: 1005, frame: CGRect(x: 1090, y: 50, width: 320, height: 240))
    h.run("pin \(call.rawValue)")
    for app in ["Browser", "Zoom"] {
      h.run("summon Terminal")
      #expect(h.workspace.isSummoned(terminal))
      h.run("summon \(app)")
      #expect(isOutOfView(terminal, h), "\(app)")
    }
  }

  @Test func aPinnedWindowOnlyGetsTheKeyboard() {
    let (h, _, _, terminal) = makeHarness()
    h.run("pin \(terminal.rawValue)")
    let frame = h.frame(terminal)
    #expect(h.run("summon Terminal").message == "Terminal is kept in view already")
    #expect(h.system.focused == terminal)
    #expect(h.frame(terminal) == frame)
    #expect(h.controller.isPinned(terminal))
  }

  @Test func anAppArborDoesNotArrangeIsAFailureThatSaysSo() {
    let (h, _, _, _) = makeHarness()
    h.run("exclude com.apple.Terminal")
    let result = h.run("summon Terminal")
    #expect(result.message == "Arbor does not arrange Terminal (`include com.apple.Terminal` if it is excluded)")
    #expect(h.system.openRequests.isEmpty)
  }

  @Test func dockingOrPinningItMakesItAnOrdinaryWindowOfThatKind() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    #expect(h.run("dock \(terminal.rawValue) right").message.contains("and it no longer comes and goes with `summon`"))
    #expect(h.workspace.isDocked(terminal) && h.workspace.summoned == nil && h.workspace.stashed == nil)
    h.run("float \(terminal.rawValue)")
    #expect(h.workspace.role(of: terminal) == nil)

    h.run("summon Terminal")
    h.run("pin \(terminal.rawValue)")
    #expect(h.workspace.role(of: terminal) == .pinned)
    h.system.userFocus(editor)
    #expect(h.system.isVisible(terminal), "a pin does not end by itself")
  }

  @Test func draggingItMovesItAndNeverDocksIt() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.drag(terminal, through: [middle.center, CGPoint(x: 300, y: 300), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil })
  }

  @Test func aNewTabInTheSummonedWindowIsStillTheSummonedWindow() {
    // ⌘T in Terminal: macOS's own window tabs are windows with numbers of their own (F17).
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let tab = try! #require(h.system.openTab(in: terminal))
    #expect(h.workspace.isSummoned(tab))
    #expect(h.frame(tab) == middle)
    h.run("summon Terminal")
    #expect(isOutOfView(tab, h) && h.workspace.isStashed(tab))
    #expect(h.system.focused == editor)
    h.run("summon Terminal")
    #expect(h.frame(tab) == middle)
  }

  @Test func aWindowThatOpenedOverAFramedOneStopsBelongingToThatSpaceOnceItIsSummoned() {
    let (h, editor, _, _) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 100, y: 100, width: 300, height: 400))
    #expect(h.workspace.guests?[notes] != nil, "a guest of the editor (F57)")
    h.system.userFocus(editor)
    h.run("summon Notes")
    #expect(h.workspace.guests == nil)
    h.run("summon Notes")
    #expect(isOutOfView(notes, h), "though the editor, its host until then, is in view")
    h.run("home")
    h.run("zoom \(editor.rawValue)")
    #expect(isOutOfView(notes, h), "an ordinary floating window now")
  }

  @Test func framingAWindowThatWasSentAwaySummonsIt() {
    // It does not live on the Desktop, so the view has nowhere to go. Go to… takes this path.
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    let camera = h.workspace.camera
    #expect(h.run("zoom \(terminal.rawValue)").message == "summoned Terminal (\(terminal))")
    #expect(h.workspace.isSummoned(terminal) && h.frame(terminal) == middle)
    #expect(h.system.focused == terminal)
    #expect(h.workspace.camera == camera)
    h.run("summon Terminal")
    #expect(h.system.focused == editor)
  }

  @Test func floatMakesItAnOrdinaryFloatingWindowAgain() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    let reply = "\(terminal) floats on the Desktop again and no longer comes and goes with `summon`"
    #expect(h.run("float \(terminal.rawValue)").message == reply)
    #expect(h.workspace.role(of: terminal) == nil)
    #expect(isOutOfView(terminal, h), "with the Desktop, which is not in view")
    h.run("show-all")
    #expect(h.system.isVisible(terminal))
    #expect(h.run("float \(terminal.rawValue)").message == "\(terminal) is already floating")

    // While it is summoned, and with the Desktop in view, the same.
    h.run("summon Terminal")
    #expect(h.run("float").message == reply)
    #expect(h.workspace.role(of: terminal) == nil && h.system.isVisible(terminal))
    h.system.userFocus(editor)
    #expect(h.system.isVisible(terminal), "turning away no longer sends it away")
  }

  // MARK: Reached some other way

  @Test func switchingToAWindowThatWasSentAwaySummonsIt() {
    // ⌘Tab, or a click on its Dock icon. It is not on the Desktop, so the camera has nowhere to go.
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    let camera = h.workspace.camera
    h.system.userFocus(terminal)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
    #expect(h.workspace.camera == camera)
    h.run("summon Terminal")
    #expect(h.system.focused == editor)
  }

  @Test func aFocusReportFromTheBackgroundDoesNotSummonIt() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    let camera = h.workspace.camera
    h.controller.windowFocused(terminal)
    #expect(h.system.focused == editor)
    #expect(h.workspace.isStashed(terminal) && isOutOfView(terminal, h))
    #expect(h.workspace.camera == camera, "and the camera does not go looking for it on the Desktop")
  }

  // MARK: Tiles

  @Test func withTheDesktopSqueezedIntoATileItComesAndGoesAllTheSame() {
    let (h, editor, browser, terminal) = makeHarness()
    h.run("show-all")
    h.run("resize \(editor.rawValue) right 150")
    h.run("resize \(browser.rawValue) left 150")
    #expect(h.layout!.desktopFrame == nil)
    h.run("summon Terminal")
    // At the size the shrinking Desktop left it with.
    let shown = h.frame(terminal)!
    #expect(abs(shown.midX - h.visibleFrame.midX) <= 1 && abs(shown.midY - h.visibleFrame.midY) <= 1)
    h.run("relayout")
    #expect(h.frame(terminal) == shown)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
  }

  // MARK: Two displays

  @Test func itComesToTheDisplayUnderThePointerAndEachDisplayRemembersItsOwnPlace() {
    let (h, _, _, terminal) = makeHarness(displays: [main, side])
    h.run("summon Terminal")
    let here = CGRect(x: 40, y: 500, width: 600, height: 300)
    h.system.userMove(terminal, to: here)
    h.run("summon Terminal")

    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    #expect(h.controller.workspaces[side.id]!.isSummoned(terminal))
    #expect(h.controller.workspaces[main.id]!.role(of: terminal) == nil)
    #expect(!h.controller.workspaces[main.id]!.isFloating(terminal))
    #expect(h.frame(terminal)!.center == side.visibleFrame.center, "the first time there")
    #expect(h.frame(terminal)!.size == here.size)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))

    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == here)
  }

  @Test func itComesToTheDisplayThatHasTheKeyboardWhenThePointerHasNotMovedSince() {
    // Like every command that names no display (F56): typing on one display with the pointer resting on the other.
    let (h, _, _, terminal) = makeHarness(displays: [main, side])
    let mail = h.system.open(app: "Mail", pid: 1005, frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    #expect(h.system.focused == mail && main.frame.contains(h.system.cursor))
    h.run("summon Terminal")
    #expect(h.controller.workspaces[side.id]!.isSummoned(terminal))
    #expect(side.visibleFrame.contains(h.frame(terminal)!))
  }

  @Test func sentAwayWhereNothingElseIsInViewTheKeyboardGoesToAWindowOnAnotherDisplay() {
    // Rather than stay in a window that is out of view, where typing goes nowhere anyone can see.
    let (h, editor, _, terminal) = makeHarness(displays: [main, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    h.system.close(editor)
    h.system.userFocus(terminal)
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    let keyboard = try! #require(h.system.focused)
    #expect(keyboard != terminal && h.system.isVisible(keyboard))
  }

  @Test func movedToTheOtherDisplayWhileSummonedItIsSummonedThere() {
    let (h, editor, _, terminal) = makeHarness(displays: [main, side])
    h.run("summon Terminal")
    let there = CGRect(x: 1600, y: 100, width: 500, height: 300)
    h.system.userMove(terminal, to: there)
    #expect(h.controller.workspaces[side.id]!.isSummoned(terminal))
    #expect(h.controller.workspaces[main.id]!.summoned == nil)
    h.system.userFocus(editor)
    #expect(isOutOfView(terminal, h))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == there)
  }

  // MARK: A display is unplugged

  @Test func sentAwayOnADisplayThatIsUnpluggedItStaysOutOfViewAndCanBeSummonedOnTheOther() {
    let (h, _, _, terminal) = makeHarness(displays: [main, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    let there = h.frame(terminal)!
    h.run("summon Terminal")
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("show-all")

    // macOS moves the windows of a display that goes away onto the ones that remain.
    h.system.userMove(terminal, to: CGRect(x: 300, y: 300, width: 400, height: 300))
    h.system.setDisplays([main])
    #expect(h.controller.workspaces[main.id]!.isStashed(terminal))
    #expect(isOutOfView(terminal, h), "though the Desktop is in view")
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle)
    h.run("summon Terminal")

    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isStashed(terminal))
    #expect(isOutOfView(terminal, h))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    #expect(h.frame(terminal) == there)
  }

  @Test func summonedOnADisplayThatIsUnpluggedItComesIntoViewOnTheOther() {
    let (h, _, _, terminal) = makeHarness(displays: [main, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("summon Terminal")
    h.system.setDisplays([main])
    #expect(h.controller.workspaces[main.id]!.isSummoned(terminal))
    #expect(h.frame(terminal)!.fractionInside(main.visibleFrame) > 0.99)
    #expect(!h.controller.parked.contains(terminal))

    // In use here, it is not pulled away when the display comes back.
    let here = h.frame(terminal)
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[main.id]!.isSummoned(terminal))
    #expect(h.frame(terminal) == here)
  }

  @Test func aMomentWithoutAnyDisplayChangesNothing() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    h.system.setDisplays([])
    h.system.setDisplays([main])
    #expect(h.workspace.isStashed(terminal))
    #expect(isOutOfView(terminal, h))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle)
  }

  // MARK: Minimized, hidden, closed

  @Test func minimizedWhileSummonedItIsLeftAloneAndComesBackSummoned() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.clearFrameLog()
    h.system.setMinimized(terminal, true)
    h.system.userFocus(editor)
    #expect(h.system.frameLog.isEmpty, "a window in the Dock is not moved")
    #expect(h.workspace.isStashed(terminal))

    // Out of the Dock again, with the keyboard, as macOS does it.
    h.system.setMinimized(terminal, false)
    h.system.userFocus(terminal)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
  }

  @Test func minimizedWhileSummonedOnePressBringsItBack() {
    // Not "sent Terminal away" for a window nobody can see, and a second press to get it.
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.setMinimized(terminal, true)
    #expect(h.run("summon Terminal").message == "opening Terminal")
    #expect(h.system.openRequests == ["Terminal"])
    h.system.setMinimized(terminal, false)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
  }

  @Test func hidingItsAppWhileSummonedAndShowingItAgain() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.setHidden(pid: 1003, true)
    h.system.userFocus(editor)
    #expect(h.workspace.isStashed(terminal))
    h.system.setHidden(pid: 1003, false)
    #expect(isOutOfView(terminal, h), "shown without the keyboard, it stays away")
    // Later, so that this is the user's doing and not macOS handing the keyboard on after the app was hidden.
    h.scheduler.advance(by: 5)
    h.system.userFocus(terminal)
    #expect(h.frame(terminal) == middle)
  }

  @Test func closingItEndsEverythingButTheRememberedFrame() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.close(terminal)
    #expect(h.workspace.summoned == nil && h.workspace.stashed == nil)
    #expect(h.workspace.summonFrames?["com.apple.Terminal"] == middle)
    #expect(h.run("summon Terminal").message == "opening Terminal")
  }

  @Test func closingItWhileItIsAwayIsHarmless() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    h.system.close(terminal)
    #expect(h.workspace.stashed == nil)
    #expect(h.controller.parked.isDisjoint(with: [terminal]))
  }

  // MARK: Float all, arrange, pause, quit, relaunch

  @Test func floatAllMakesThemOrdinaryWindowsInView() {
    let (h, _, _, terminal) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 100, y: 100, width: 300, height: 400))
    h.run("summon Notes")
    h.run("summon Terminal")
    #expect(h.run("float-all").ok)
    #expect(h.workspace.summoned == nil && h.workspace.stashed == nil)
    #expect(h.frame(terminal) == middle, "the summoned one stays where it is")
    #expect(h.system.isVisible(notes), "the one that was away comes back")
    #expect(h.controller.parked.isEmpty)
  }

  @Test func floatAllBringsThemBackEvenWithNothingDocked() {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal")
    let notes = h.system.open(app: "Notes", pid: 1004)
    h.start()
    h.system.userFocus(notes)
    h.run("summon Terminal")
    h.run("summon Terminal")
    #expect(isOutOfView(terminal, h))
    #expect(h.run("float-all").ok, "back to a normal Mac")
    #expect(h.system.isVisible(terminal))
    #expect(!h.run("float-all").ok, "nothing is left to do")
  }

  @Test func arrangeLeavesThemOut() {
    let (h, editor, browser, terminal) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1004)
    h.run("summon Notes")
    h.run("summon Terminal")
    #expect(h.run("arrange").message == "arranged 2 windows")
    #expect(Set(h.workspace.tree.allWindows) == [editor, browser])
    #expect(h.workspace.isSummoned(terminal) && h.workspace.isStashed(notes))
    #expect(h.frame(terminal) == middle)
    #expect(isOutOfView(notes, h))
  }

  @Test func pausingLeavesItInViewAndEndsTheSummon() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.clearFrameLog()
    #expect(h.run("pause").ok)
    #expect(h.frame(terminal) == middle)
    #expect(!h.system.frameLog.contains { $0.window == terminal }, "it is not touched")
    #expect(h.store.saved?.workspaces[h.display]?.isStashed(terminal) == true, "the summon is over")

    // The keyboard went elsewhere during the pause, which Arbor did not see.
    h.system.userFocus(editor)
    #expect(h.run("resume").ok)
    #expect(h.workspace.isStashed(terminal))
    #expect(isOutOfView(terminal, h))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle, "nothing that matters was forgotten")
  }

  @Test func resumedWithTheKeyboardStillInItItIsSummonedAgainWhereItIs() {
    // A resume ends with the focused window in view, and for a window that was sent away that means summoned,
    // as when it is switched to. Whoever paused while using it goes on using it.
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("pause")
    h.system.clearFrameLog()
    #expect(h.run("resume").ok)
    #expect(h.system.focused == terminal)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: editor), "and the view is the one that was paused")
    h.system.userFocus(editor)
    #expect(isOutOfView(terminal, h))
  }

  @Test func pausingBringsAWindowThatWasSentAwayIntoView() {
    let (h, _, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.run("summon Terminal")
    h.run("pause")
    #expect(h.frame(terminal) == middle)
    h.run("resume")
    #expect(isOutOfView(terminal, h))
  }

  @Test func pausingStopsWaitingForAWindow() {
    let (h, _, _, _) = makeHarness()
    h.run("summon Notes")
    h.run("pause")
    #expect(!h.scheduler.pendingKeys.contains("summon-wait"))
    h.run("resume")
    let notes = h.system.open(app: "Notes", pid: 1004)
    #expect(h.workspace.role(of: notes) == nil)
  }

  @Test func quittingLeavesEveryWindowInViewAndSoDoesTheNextLaunch() {
    let (old, _, _, terminal) = makeHarness()
    let notes = old.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 100, y: 100, width: 300, height: 400))
    old.run("summon Notes")
    old.run("summon Terminal")
    old.controller.shutdown()
    #expect(old.frame(terminal) == middle)
    #expect(old.system.isVisible(notes))

    // No start takes a window out of view: they are ordinary floating windows now. Where each was summoned is remembered.
    let h = relaunch(old)
    #expect(h.workspace.role(of: terminal) == nil && h.workspace.role(of: notes) == nil)
    #expect(h.system.frameLog.allSatisfy { $0.window != terminal && $0.window != notes }, "\(h.system.frameLog)")
    #expect(h.system.isVisible(terminal) && h.system.isVisible(notes))
    h.system.userMove(terminal, to: CGRect(x: 40, y: 60, width: 400, height: 300))
    h.run("summon Terminal")
    #expect(h.frame(terminal) == middle)
  }

  @Test func killedWhileSummonedItIsStillSummonedWhenTheWatchdogHasStartedArborAgain() {
    let (old, editor, _, terminal) = makeHarness()
    old.run("summon Terminal")
    old.controller.saveNow()

    let h = relaunch(old, byTheWatchdog: true)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal) == middle)
    h.system.userFocus(editor)
    #expect(isOutOfView(terminal, h))
  }

  @Test func aStateFileFromBeforeSummoningLoadsAndTheNewOneRoundTrips() throws {
    let (h, _, _, terminal) = makeHarness()
    let notes = h.system.open(app: "Notes", pid: 1004)
    h.run("summon Notes")
    h.run("summon Terminal")
    h.controller.saveNow()
    let saved = try #require(h.store.saved)
    let data = try JSONEncoder().encode(saved)
    let again = try JSONDecoder().decode(PersistedState.self, from: data)
    #expect(again == saved)
    #expect(again.workspaces[h.display]?.summoned == Summon(window: terminal, app: "com.apple.Terminal"))
    #expect(again.workspaces[h.display]?.stashed == [notes])

    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var workspaces = try #require(object["workspaces"] as? [String: [String: Any]])
    for key in workspaces.keys {
      for field in ["summoned", "stashed", "summonFrames"] { #expect(workspaces[key]?.removeValue(forKey: field) != nil) }
    }
    object["workspaces"] = workspaces
    let old = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.workspaces[h.display]?.role(of: terminal) == nil)
    #expect(old.workspaces[h.display]?.isFloating(terminal) == true)
  }

  // MARK: What scripts and people see

  @Test func stateAndTheDrawingShowIt() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    var window = h.run("state").state?.window(terminal)
    #expect(window?.summoned == true && window?.stashed == false && window?.parked == false)
    #expect(h.ascii().contains("\(terminal) summoned"))
    h.run("summon Terminal")
    window = h.run("state").state?.window(terminal)
    #expect(window?.summoned == false && window?.stashed == true && window?.parked == true)
    #expect(h.run("state").state?.window(editor)?.stashed == false)
  }

  @Test func scenariosCanExpectIt() {
    let (h, editor, _, terminal) = makeHarness()
    func expect(_ line: String) -> String? {
      ScenarioExpectation.check(line.split(separator: " ").map(String.init), harness: h, lastCommandOK: true)
    }
    #expect(expect("summoned \(terminal.rawValue)") == "\(terminal) is not summoned")
    h.run("summon Terminal")
    #expect(expect("summoned \(terminal.rawValue)") == nil)
    #expect(expect("summoned \(editor.rawValue)") == "\(editor) is not summoned")
    #expect(expect("summoned 999") == "there is no window w999")
  }

  @Test func aURLCannotSummonUnlessEveryCommandIsAllowed() {
    // It can launch any app on the Mac, and any web page can open a URL.
    let (h, _, _, _) = makeHarness()
    guard case .failure = h.controller.admit(url: "arbor://summon/Terminal") else {
      Issue.record("accepted")
      return
    }
    var settings = Settings()
    settings.allowAllURLCommands = true
    h.controller.apply(settings: settings)
    #expect(h.controller.admit(url: "arbor://summon/Visual/Studio/Code") == .success(.summon(app: "Visual Studio Code")))
  }

  @Test func whilePausedItSaysWhyItDoesNothing() {
    let (h, _, _, _) = makeHarness()
    h.run("pause")
    #expect(!h.run("summon Terminal").ok)
    #expect(h.system.openRequests.isEmpty)
  }

  @Test func theReadmesRecipeBindsTheKeys() throws {
    let json = #"{"bindings": {"ctrl+opt+`": "summon com.apple.Terminal", "ctrl+opt+'": "summon Notes"}, "summonStays": true}"#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(settings.summonStays)
    let bindings = KeyBindings.effective(settings: settings)
    #expect(bindings.problems.isEmpty)
    #expect(bindings.bindings.contains { $0.command == .summon(app: "com.apple.Terminal") })
    #expect(bindings.bindings.contains { $0.command == .summon(app: "Notes") })
  }

  // MARK: A docked window: there and back

  /// [safari | terminal], framed on Safari, which has the keyboard.
  func makeHarnessWithTheTerminalDocked() -> (Harness, safari: WindowID, terminal: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1001)
    let terminal = h.system.open(app: "Terminal", pid: 1002)
    h.start()
    #expect(h.run("dock \(safari.rawValue) left").ok && h.run("dock \(terminal.rawValue) right").ok)
    #expect(h.run("zoom \(safari.rawValue)").ok)
    settle(h)
    #expect(h.system.focused == safari && isOutOfView(terminal, h))
    return (h, safari, terminal)
  }

  @Test func summoningADockedWindowAgainGoesBackWhereYouWere() {
    // One key for an app, wherever its window lives: the first press goes to it as ⌘Tab would, the second goes back.
    let (h, safari, terminal) = makeHarnessWithTheTerminalDocked()
    let before = h.workspace.camera
    for round in 1...2 {
      #expect(h.run("summon Terminal").ok)
      settle(h)
      #expect(h.system.focused == terminal && h.system.isVisible(terminal) && h.workspace.camera != before, "round \(round)")
      #expect(h.workspace.isDocked(terminal))
      #expect(h.run("summon Terminal").ok)
      settle(h)
      #expect(h.workspace.camera == before, "round \(round)")
      #expect(h.system.focused == safari && isOutOfView(terminal, h), "round \(round)")
    }
  }

  @Test func inViewAlreadyOnlyTheKeyboardGoesThereAndBack() {
    let (h, safari, terminal) = makeHarnessWithTheTerminalDocked()
    h.run("show-all")
    h.system.userFocus(safari)
    settle(h)
    let (camera, frames) = (h.workspace.camera, [h.frame(safari), h.frame(terminal)])
    h.run("summon Terminal")
    settle(h)
    #expect(h.system.focused == terminal)
    h.run("summon Terminal")
    settle(h)
    #expect(h.system.focused == safari)
    #expect(h.workspace.camera == camera && [h.frame(safari), h.frame(terminal)] == frames)
  }

  @Test func onceTheViewHasMovedThereIsNoBack() {
    let (h, _, terminal) = makeHarnessWithTheTerminalDocked()
    h.run("summon Terminal")
    settle(h)
    let there = h.workspace.camera
    // Away and to the same place again, with the keyboard in the terminal all the while.
    h.run("show-all")
    h.run("zoom \(terminal.rawValue)")
    settle(h)
    #expect(h.workspace.camera == there && h.system.focused == terminal)
    #expect(h.run("summon Terminal").message.contains("docked"))
    settle(h)
    #expect(h.workspace.camera == there && h.system.focused == terminal)
  }

  @Test func onceTheKeyboardHasBeenElsewhereThereIsNoBack() {
    let (h, safari, terminal) = makeHarnessWithTheTerminalDocked()
    h.run("show-all")
    h.system.userFocus(safari)
    settle(h)
    let camera = h.workspace.camera
    h.run("summon Terminal")
    settle(h)
    // To Safari and to the terminal again by hand; the view never moves.
    h.system.userFocus(safari)
    h.system.userFocus(terminal)
    settle(h)
    #expect(h.workspace.camera == camera)
    #expect(h.run("summon Terminal").message.contains("docked"))
    settle(h)
    #expect(h.system.focused == terminal)
  }

  @Test func withTheKeyboardInItAlreadyThereIsNowhereToGoBackTo() {
    let (h, _, terminal) = makeHarnessWithTheTerminalDocked()
    h.run("zoom \(terminal.rawValue)")
    settle(h)
    let there = h.workspace.camera
    for _ in 1...2 {
      #expect(h.run("summon Terminal").message.contains("docked"), "not \"back from\": nobody came from anywhere")
      settle(h)
      #expect(h.workspace.camera == there && h.system.focused == terminal)
    }
  }

  /// [(safari / mail / …) | terminal], framed on the column, with the keyboard in Safari; then `summon Terminal`.
  func makeHarnessGoneToTheTerminalFromAColumn(of others: [String]) -> (Harness, safari: WindowID, terminal: WindowID, column: NodeID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1001)
    let terminal = h.system.open(app: "Terminal", pid: 1002)
    h.start()
    #expect(h.run("dock \(safari.rawValue) left").ok && h.run("dock \(terminal.rawValue) right").ok)
    for (index, app) in others.enumerated() {
      let window = h.system.open(app: app, pid: Int32(1003 + index))
      #expect(h.run("dock \(window.rawValue) beside \(safari.rawValue) bottom").ok)
    }
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: safari)!)!
    #expect(h.run("zoom-node \(column.rawValue)").ok)
    h.system.userFocus(safari)
    settle(h)
    #expect(h.run("summon Terminal").ok)
    settle(h)
    #expect(h.system.focused == terminal && h.workspace.camera != column)
    return (h, safari, terminal, column)
  }

  @Test func theWindowYouCameFromHasClosedTheViewStillGoesBack() {
    let (h, safari, terminal, column) = makeHarnessGoneToTheTerminalFromAColumn(of: ["Mail", "Notes"])
    h.system.close(safari)
    settle(h)
    #expect(h.system.focused == terminal && h.workspace.tree.contains(column))
    #expect(h.run("summon Terminal").ok)
    settle(h)
    #expect(h.workspace.camera == column)
    #expect(h.system.focused != terminal && h.system.focused.map { h.system.isVisible($0) } == true, "what is in view there has it")
  }

  @Test func thePlaceYouCameFromIsGoneSoThePressStays() {
    let (h, safari, terminal, column) = makeHarnessGoneToTheTerminalFromAColumn(of: ["Mail"])
    h.system.close(safari)
    settle(h)
    #expect(!h.workspace.tree.contains(column))
    let there = h.workspace.camera
    #expect(h.run("summon Terminal").ok)
    settle(h)
    #expect(h.workspace.camera == there && h.system.isVisible(terminal))
  }

  /// The terminal summoned on the main display and the notes on the side display, which has the keyboard.
  func makeHarnessWithASummonOnEachDisplay() -> (Harness, terminal: WindowID, notes: WindowID) {
    var settings = Settings()
    settings.summonStays = true
    let (h, _, _, terminal) = makeHarness(displays: [main, side], settings: settings)
    #expect(h.run("summon Terminal").ok)
    let notes = h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 1600, y: 100, width: 300, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("summon Notes").ok)
    settle(h)
    #expect(h.controller.workspaces[main.id]!.isSummoned(terminal) && h.controller.workspaces[side.id]!.isSummoned(notes))
    return (h, terminal, notes)
  }

  @Test func carriedByHandToADisplayWithASummonedWindowOfItsOwnItTakesItsPlace() {
    // Sent away where its user has just put it, it would vanish from under their hand at the next layout.
    let (h, terminal, notes) = makeHarnessWithASummonOnEachDisplay()
    let put = CGRect(x: 1900, y: 300, width: 400, height: 300)
    h.system.userFocus(terminal)
    h.system.userMove(terminal, to: put)
    settle(h)
    #expect(h.controller.workspaces[side.id]!.isSummoned(terminal))
    #expect(h.frame(terminal) == put)
    #expect(h.controller.workspaces[side.id]!.isStashed(notes) && isOutOfView(notes, h), "one at a time, as after `summon`")
    #expect(h.controller.workspaces[main.id]!.summoned == nil)
  }

  @Test func anOrdinaryWindowCarriedThereLeavesTheSummonedOneAlone() {
    let (h, _, notes) = makeHarnessWithASummonOnEachDisplay()
    let mail = h.system.open(app: "Mail", pid: 1005, frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    settle(h)
    #expect(h.controller.workspaces[main.id]!.role(of: mail) == nil && h.controller.workspaces[side.id]!.isSummoned(notes))
    h.system.userMove(mail, to: CGRect(x: 2200, y: 500, width: 300, height: 200))
    settle(h)
    #expect(h.controller.workspaces[side.id]!.isFloating(mail))
    #expect(h.controller.workspaces[side.id]!.isSummoned(notes), "with `summonStays`, until it is summoned away")
  }

  @Test func draggedToADisplayWithASummonedWindowOfItsOwnItTakesItsPlace() {
    let (h, terminal, notes) = makeHarnessWithASummonOnEachDisplay()
    let frame = h.frame(terminal)!
    h.system.userFocus(terminal)
    h.system.drag(terminal, through: [CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: 2100, y: 310)])
    settle(h)
    #expect(h.controller.workspaces[side.id]!.isSummoned(terminal))
    #expect(h.system.isVisible(terminal) && side.frame.contains(h.frame(terminal)!.center))
    #expect(h.controller.workspaces[side.id]!.isStashed(notes) && isOutOfView(notes, h))
  }

  @Test func aWindowTheDesktopSqueezedIsSummonedAtItsOwnSize() {
    // Found by the real-window suite: "the first time: centred, its own size".
    let h = Harness()
    // Not pid 1, which the harness takes for Arbor's own.
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002)
    let term = h.system.open(app: "Term", pid: 1003, frame: CGRect(x: 200, y: 200, width: 900, height: 400))
    h.start()
    #expect(h.run("dock \(a.rawValue) left").ok && h.run("dock \(b.rawValue) right").ok)
    #expect(h.frame(term)!.width < 900, "the Desktop between them is narrower than it")
    #expect(h.run("zoom \(a.rawValue)").ok)
    settle(h)
    #expect(isOutOfView(term, h))
    #expect(h.run("summon Term").ok)
    settle(h)
    #expect(h.frame(term)!.size == CGSize(width: 900, height: 400))
    h.run("summon Term")
    h.run("summon Term")
    settle(h)
    #expect(h.frame(term)!.size == CGSize(width: 900, height: 400), "and that is what is remembered")
  }

  @Test func squeezedInViewWithTheKeyboardInItItIsSummonedThereAtItsOwnSize() {
    // Summoned where it is, so that it does not jump; but as small as the Desktop made it is not its size.
    let h = Harness()
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002)
    let term = h.system.open(app: "Term", pid: 1003, frame: CGRect(x: 200, y: 200, width: 900, height: 400))
    h.start()
    #expect(h.run("dock \(a.rawValue) left").ok && h.run("dock \(b.rawValue) right").ok)
    h.system.userFocus(term)
    settle(h)
    let squeezed = h.frame(term)!
    #expect(squeezed.width < 900 && h.system.isVisible(term))
    #expect(h.run("summon Term").ok)
    settle(h)
    #expect(h.workspace.isSummoned(term))
    #expect(h.frame(term)!.size == CGSize(width: 900, height: 400))
    #expect(abs(h.frame(term)!.midX - squeezed.midX) <= 1 && h.frame(term)!.minY == squeezed.minY, "around where it was")
    h.run("float \(term.rawValue)")
    h.run("float-all")
    settle(h)
    #expect(h.frame(term)!.size == CGSize(width: 900, height: 400), "and the size is not lost")
  }

  // MARK: With a floating window alone on the Desktop taking all of it (F18)

  /// [editor | Desktop | browser], everything in view, the editor has the keyboard, and the terminal, alone on the
  /// Desktop, fills it.
  func makeHarnessWhereTheTerminalFillsTheDesktop() -> (Harness, editor: WindowID, terminal: WindowID, own: CGSize) {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let (h, editor, _, terminal) = makeHarness(settings: settings)
    h.run("show-all")
    settle(h)
    return (h, editor, terminal, CGSize(width: 400, height: 300))
  }

  @Test func aWindowThatFilledTheDesktopIsSummonedAtItsOwnSize() {
    let (h, _, terminal, own) = makeHarnessWhereTheTerminalFillsTheDesktop()
    #expect(h.frame(terminal)!.size != own, "it fills the Desktop")
    h.run("summon Terminal")
    settle(h)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal)!.size == own, "as large as Arbor happened to make it is not its size")
    h.run("summon Terminal")
    h.run("summon Terminal")
    settle(h)
    #expect(h.frame(terminal)!.size == own, "nor the next time")
  }

  @Test func summonedWhileItFillsTheDesktopWithTheKeyboardInItItIsItsOwnSizeToo() {
    // In view with the keyboard in it a window is summoned where it is, but all over the Desktop is not where anybody put it.
    let (h, _, terminal, own) = makeHarnessWhereTheTerminalFillsTheDesktop()
    h.system.userFocus(terminal)
    settle(h)
    #expect(h.frame(terminal)!.size != own)
    h.run("summon Terminal")
    settle(h)
    #expect(h.workspace.isSummoned(terminal))
    #expect(h.frame(terminal)!.size == own)
  }

  @Test func theWindowLeftAloneOnTheDesktopTakesItAndGivesItBack() {
    let (h, editor, terminal, _) = makeHarnessWhereTheTerminalFillsTheDesktop()
    let spot = CGRect(x: 560, y: 500, width: 300, height: 200)
    let notes = h.system.open(app: "Notes", pid: 1004, frame: spot)
    h.system.userFocus(editor)
    settle(h)
    let together = h.frame(notes)!
    #expect(together.size == spot.size, "two on the Desktop: each its own size")

    h.run("summon Terminal")
    settle(h)
    #expect(h.frame(notes)!.size != spot.size, "the terminal has left the Desktop, so the notes have it to themselves")
    let alone = h.frame(notes)!
    h.run("summon Terminal")
    settle(h)
    #expect(h.frame(notes) == alone, "sent away it is not on the Desktop either")
    h.run("float \(terminal.rawValue)")
    settle(h)
    #expect(h.frame(notes)!.size == spot.size, "back on the Desktop, it is company again")
  }
}
