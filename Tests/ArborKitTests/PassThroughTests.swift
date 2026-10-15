import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Apps that keep their own ⌃⌥, and apps Arbor pauses for (docs/features/F41-pass-through-apps.md).
@Suite @MainActor struct PassThroughTests {
  static let emacsID = "com.example.emacs"
  static let gameID = "com.example.game"

  /// [Emacs | Desktop | Safari], Game floating, Safari in front.
  /// `apart`: each app is a process of its own, as a story about ⌘Tab needs. Otherwise they are one, and a switch among them is ⌘`.
  func makeHarness(passThrough: [String] = [emacsID], pauseFor: [String] = [gameID], apart: Bool = false)
    -> (Harness, emacs: WindowID, safari: WindowID, game: WindowID)
  {
    var settings = Settings.withGestures  // what a listed app takes away
    settings.passThroughApps = passThrough
    settings.pauseForApps = pauseFor
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs", pid: apart ? 11 : 1000)
    let safari = h.system.open(app: "Safari", pid: apart ? 12 : 1000)
    let game = h.system.open(app: "Game", pid: apart ? 13 : 1000)
    h.start()
    h.run("dock \(emacs.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(safari)
    return (h, emacs, safari, game)
  }

  /// Counts the times observers are told that what Arbor holds has changed.
  func countInputChanges(_ h: Harness) -> () -> Int {
    final class Box { var count = 0 }
    let box = Box()
    h.controller.observe { change in if change == .input { box.count += 1 } }
    return { box.count }
  }

  // MARK: Pass-through

  @Test func aListedAppInFrontTakesTheShortcutsAndGesturesAndGivesThemBack() {
    let (h, emacs, safari, _) = makeHarness()
    #expect(h.controller.activeBindings == KeyBindings.core)
    #expect(h.controller.inputSettings == h.controller.settings)

    h.system.userFocus(emacs)
    #expect(h.controller.isPassingThrough)
    #expect(h.controller.activeBindings.map(\.chord.text) == ["ctrl+opt+escape"], "only the key that always answers")
    #expect(!h.controller.inputSettings.gesturesEnabled)
    #expect(h.controller.inputSettings.frameRectangleModifier == "none")
    #expect(h.controller.settings.gesturesEnabled, "the user's own settings are untouched")
    #expect(h.controller.isRunning && !h.controller.isPaused)

    h.system.userFocus(safari)
    #expect(!h.controller.isPassingThrough)
    #expect(h.controller.activeBindings == KeyBindings.core)
    #expect(h.controller.inputSettings == h.controller.settings)
  }

  /// No event may pass through Arbor, so every way to draw a rectangle must be off for the taps to go.
  @Test func aListedAppInFrontLeavesNoWayToDrawARectangle() {
    let (h, emacs, safari, _) = makeHarness()
    h.system.userFocus(emacs)
    // As the tap takes them, so that a new reason to hold presses cannot go unnoticed here.
    var gesture = RectangleGesture()
    gesture.follow(h.controller.inputSettings)
    #expect(!gesture.isEnabled)
    h.system.userFocus(safari)
    #expect(h.controller.inputSettings.frameRectangleOnDesktop)
  }

  @Test func theAppIsToldOnlyWhenTheAnswerChanges() {
    let (h, emacs, safari, _) = makeHarness(pauseFor: [])
    let changes = countInputChanges(h)
    let mail = h.system.open(app: "Mail")
    h.system.userFocus(mail)
    h.system.userFocus(safari)
    h.system.activate(bundleID: "com.apple.finder", name: "Finder")
    h.system.activate(bundleID: nil, name: "a.out")
    #expect(changes() == 0, "switching between ordinary apps costs nothing")

    h.system.userFocus(emacs)
    #expect(changes() == 1)
    h.system.userFocus(emacs)
    h.controller.applicationActivated(FrontmostApp(bundleID: Self.emacsID, name: "Emacs"))
    h.run("relayout")
    h.run("exclude com.example.mail")
    #expect(changes() == 1, "nothing changed for the keys")
    h.system.userFocus(safari)
    #expect(changes() == 2)
  }

  @Test func anAppWithoutAWindowCounts() {
    let (h, _, _, _) = makeHarness(passThrough: ["com.microsoft.rdc.macos"])
    h.system.activate(bundleID: "com.microsoft.rdc.macos", name: "Windows App")
    #expect(h.controller.isPassingThrough)
    h.system.activate(bundleID: nil, name: "a.out")
    #expect(!h.controller.isPassingThrough)
    h.system.activate(bundleID: "com.microsoft.rdc.macos", name: "Windows App")
    h.controller.applicationActivated(nil)
    #expect(!h.controller.isPassingThrough, "when nobody knows who is in front, Arbor keeps its keys")
  }

  @Test func itsWindowsAreStillDockedMovedOutOfViewAndRevealed() {
    let (h, emacs, safari, _) = makeHarness(apart: true)
    h.system.userFocus(emacs)
    #expect(h.workspace.isDocked(emacs))

    // From arborctl or the menu, which still work.
    #expect(h.run("zoom \(safari.rawValue)").ok)
    #expect(!h.system.isVisible(emacs), "out of view like any other window")
    h.system.userFocus(safari)
    h.system.userFocus(emacs)
    #expect(h.system.isVisible(emacs), "⌘Tab to it moves the view")
    expectWindowsMatchLayout(h, on: h.display)

    #expect(h.run("float \(emacs.rawValue)").ok)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(emacs, through: [CGPoint(x: 700, y: 400), CGPoint(x: 400, y: 400), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isDocked(emacs), "dragging to an edge docks while the app is in front")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A known limit, pinned so that it changes only on purpose: Arbor's own shortcut can hand the keyboard to a
  /// listed app, and from then on the keys are that app's.
  @Test func walkingOntoAListedAppWithTheKeyboardHandsItTheKeys() {
    let (h, emacs, safari, _) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    #expect(!h.controller.isPassingThrough)
    h.run("zoom \(emacs.rawValue)")
    #expect(h.system.focused == emacs, "the window that went out of view cannot keep the keyboard")
    #expect(h.controller.isPassingThrough)
    #expect(h.controller.activeBindings.map(\.command) == [.togglePause])
  }

  @Test func aShortcutGivenToTheToggleSurvivesSoThatItCanTurnItOff() {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+k": "pass-through", "ctrl+opt+escape": nil]
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    h.start()
    h.system.userFocus(emacs)
    #expect(h.run("pass-through").ok)
    #expect(h.controller.activeBindings.map(\.chord.text) == ["ctrl+opt+k"])
    #expect(h.controller.perform(h.controller.activeBindings[0].command).ok)
    #expect(!h.controller.isPassingThrough)
    #expect(h.controller.activeBindings.count == KeyBindings.core.count)
  }

  @Test func shortcutsSwitchedOffAltogetherStayOff() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    settings.passThroughApps = [Self.emacsID]
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    h.start()
    #expect(h.controller.activeBindings.isEmpty)
    h.system.userFocus(emacs)
    #expect(h.controller.activeBindings.isEmpty)
  }

  @Test func pausingByHandInAListedAppKeepsTheWaysOutOfThePause() {
    var settings = Settings()
    settings.passThroughApps = [Self.emacsID]
    settings.bindings = ["ctrl+opt+cmd+r": "resume"]
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    h.start()
    h.system.userFocus(emacs)
    h.run("toggle-pause")
    #expect(h.controller.activeBindings.map(\.command.text).sorted() == ["resume", "toggle-pause"])
    h.run("toggle-pause")
    #expect(h.controller.activeBindings.map(\.command) == [.togglePause], "still in Emacs")
  }

  // MARK: The command

  @Test func theCommandTogglesTheFrontmostAppSavesAndAppliesAtOnce() {
    let (h, emacs, _, _) = makeHarness(passThrough: [])
    var saved: [Settings] = []
    h.controller.saveSettings = { _, new in saved.append(new) }
    let changes = countInputChanges(h)
    h.system.userFocus(emacs)

    let on = h.run("pass-through")
    #expect(on.ok)
    #expect(on.message == "shortcuts and gestures are off in Emacs, except ⌃⌥⎋")
    #expect(saved.last?.passThroughApps == [Self.emacsID])
    #expect(h.controller.isPassingThrough)
    #expect(changes() == 1)

    let off = h.run("pass-through")
    #expect(off.message == "shortcuts and gestures work in Emacs again")
    #expect(saved.last?.passThroughApps == [])
    #expect(!h.controller.isPassingThrough)
    #expect(changes() == 2)
  }

  /// The settings in use are what settings.json says (Controller+Settings.swift).
  @Test func aListThatCannotBeSavedChangesNothingAndTheReplySaysSo() {
    struct Full: Error, CustomStringConvertible { let description = "the disk is full" }
    let (h, emacs, _, _) = makeHarness(passThrough: [])
    h.controller.saveSettings = { _, _ in throw Full() }
    h.system.userFocus(emacs)
    let result = h.run("pass-through")
    #expect(result == .failure("settings.json could not be saved, so nothing was changed: the disk is full"))
    #expect(!h.controller.isPassingThrough && h.controller.settings.passThroughApps.isEmpty)
  }

  @Test func theCommandTakesAnAppThatIsNotInFront() {
    let (h, emacs, _, _) = makeHarness(passThrough: [])
    #expect(h.run("pass-through \(Self.emacsID)").message.contains("off in Emacs"))
    #expect(!h.controller.isPassingThrough, "Safari is in front")
    h.system.userFocus(emacs)
    #expect(h.controller.isPassingThrough)
    // An app Arbor has never met goes by its bundle id, and another spelling takes it off again.
    #expect(h.run("pass-through com.vmware.fusion").message.contains("off in com.vmware.fusion"))
    #expect(h.run("pass-through com.VMware.Fusion").message == "shortcuts and gestures work in com.VMware.Fusion again")
    #expect(h.controller.settings.passThroughApps == [Self.emacsID])
  }

  /// For files that must say which, however often they are run.
  @Test func onAndOffSayWhichAndCanBeRepeated() {
    let (h, emacs, _, _) = makeHarness(passThrough: [])
    var saves = 0
    h.controller.saveSettings = { _, _ in saves += 1 }
    #expect(h.run("pass-through \(Self.emacsID) on").message == "shortcuts and gestures are off in Emacs, except ⌃⌥⎋")
    let again = h.run("pass-through \(Self.emacsID) on")
    #expect(again.ok && again.message == "shortcuts and gestures are already off in Emacs")
    #expect(h.controller.settings.passThroughApps == [Self.emacsID] && saves == 1)
    h.system.userFocus(emacs)
    #expect(h.run("pass-through off").message == "shortcuts and gestures work in Emacs again")
    #expect(h.run("pass-through OFF").message == "shortcuts and gestures already work in Emacs")
    #expect(h.controller.settings.passThroughApps.isEmpty && saves == 2)
    #expect(h.run("pass-through on").ok && h.controller.isPassingThrough)
  }

  @Test func theMenuSaysFirstThatTheShortcutsAreOffHere() {
    let (h, emacs, safari, _) = makeHarness()
    #expect(h.controller.passThroughNotice == nil)
    // Walking there with the keyboard: nothing else on screen would say so.
    h.run("zoom \(safari.rawValue)")
    h.run("zoom \(emacs.rawValue)")
    #expect(h.controller.passThroughNotice == "Shortcuts are off in “Emacs”")
    h.run("pause")
    #expect(h.controller.passThroughNotice == nil, "the pause has a line of its own")
    h.run("resume")
    h.system.userFocus(safari)
    #expect(h.controller.passThroughNotice == nil)
  }

  /// ⌃⌥⎋ is the one key left in a listed app, and must not lead back to where one was stuck.
  @Test func aResumeAlwaysEndsWithTheFocusedWindowInView() {
    let (h, emacs, safari, _) = makeHarness()
    h.system.userFocus(emacs)
    h.run("zoom")
    #expect(!h.system.isVisible(safari))
    h.run("toggle-pause")
    h.system.userFocus(safari)
    h.run("toggle-pause")
    #expect(h.system.isVisible(safari), "it has the keyboard")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theCommandSaysWhyItCannotListTheFrontmostApp() {
    let h = Harness()
    h.start()
    #expect(h.run("pass-through").message == "no bundle id given and no app in front")
    h.system.activate(bundleID: nil, name: "a.out")
    let result = h.run("pass-through")
    #expect(!result.ok)
    #expect(result.message == "a.out has no bundle id to list it by")
    #expect(h.controller.settings.passThroughApps.isEmpty)
  }

  @Test func reloadingSettingsAppliesAnEditedList() {
    let (h, emacs, _, _) = makeHarness(passThrough: [])
    h.system.userFocus(emacs)
    var edited = h.controller.settings
    edited.passThroughApps = ["COM.example.EMACS"]
    h.controller.loadSettings = { edited }
    let changes = countInputChanges(h)
    h.run("reload-settings")
    #expect(h.controller.isPassingThrough)
    #expect(changes() == 1)
  }

  @Test func bindingsAndStatusSayThatTheShortcutsAreOffAndWhy() {
    let (h, emacs, safari, _) = makeHarness()
    let count = KeyBindings.core.count
    #expect(h.run("bindings").message == "\(count) shortcuts")
    #expect(h.run("bindings").text?.contains("Right now") == false)
    #expect(!h.run("status").message.contains("off"))
    h.system.userFocus(emacs)
    #expect(h.run("bindings").message == "\(count) shortcuts, all but 1 off in Emacs")
    #expect(h.run("bindings").text?.hasSuffix("\n\nRight now: all but 1 off in Emacs.") == true, "what arborctl prints")
    #expect(h.run("status").message.hasSuffix("; shortcuts and gestures are off in Emacs"))
    h.system.userFocus(safari)
    h.run("pause")
    #expect(h.run("bindings").message == "\(count) shortcuts, all but 1 off while Arbor is paused")
  }

  @Test func bindingsSuggestsTheListForAppsKnownToNeedTheirKeys() {
    let h = Harness()
    h.system.open(app: "Emacs", bundleID: "org.gnu.Emacs")
    h.system.open(app: "Emacs", bundleID: "org.gnu.Emacs")
    h.system.open(app: "PyCharm", bundleID: "com.jetbrains.pycharm")
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.start()
    #expect(h.controller.passThroughSuggestions.map(\.bundleID) == ["org.gnu.Emacs", "com.jetbrains.pycharm"])
    #expect(h.run("bindings").text?.contains("Emacs uses ⌃⌥ itself: `pass-through org.gnu.Emacs on`") == true)
    #expect(h.controller.settings.passThroughApps.isEmpty, "suggested, never added")
    h.run("pass-through org.gnu.Emacs")
    #expect(h.controller.passThroughSuggestions.map(\.name) == ["PyCharm"])
  }

  @Test func scenariosCanAskWhetherArborHoldsAShortcut() {
    let (h, emacs, _, _) = makeHarness()
    func expect(_ line: String) -> String? {
      ScenarioExpectation.check(line.split(separator: " ").map(String.init), harness: h, lastCommandOK: true)
    }
    #expect(expect("shortcut ctrl+opt+space on") == nil)
    #expect(expect("shortcut opt+ctrl+Space off") == "Arbor holds ctrl+opt+space")
    #expect(expect("shortcut ctrl+opt+q off") == nil, "never bound")
    h.system.userFocus(emacs)
    #expect(expect("shortcut ctrl+opt+space off") == nil)
    #expect(expect("shortcut ctrl+opt+space on") == "Arbor does not hold ctrl+opt+space: the app in front gets it")
    #expect(expect("shortcut ctrl+opt+escape on") == nil)
    #expect(expect("shortcut ctrl+opt+space perhaps")?.hasPrefix("cannot read") == true)
    #expect(expect("shortcut hyper+x on")?.hasPrefix("cannot read") == true)
  }

  // MARK: Pausing for an app

  @Test func aListedAppInFrontPausesArborAndLeavingItResumes() {
    let (h, emacs, safari, game) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let before = h.workspace
    #expect(!h.system.isVisible(emacs))

    h.system.userFocus(game)
    #expect(h.controller.isPaused && h.controller.isPausedForApp)
    #expect(h.frame(emacs)!.fractionInside(h.visibleFrame) > 0.99, "as with `pause`, every window is in view")
    #expect(h.controller.activeBindings.map(\.command) == [.togglePause])
    #expect(!h.controller.inputSettings.gesturesEnabled)
    #expect(h.run("status").message.hasPrefix("paused for Game: "))

    h.system.userFocus(safari)
    #expect(h.controller.isRunning && !h.controller.isPaused && !h.controller.isPausedForApp)
    #expect(h.workspace == before)
    #expect(!h.system.isVisible(emacs))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// That an app has come to the front and that one of its windows has the keyboard reach Arbor by different roads, in either order.
  /// With the window first Arbor was still running: the view went off to show it, and then came the pause, which shows
  /// everything anyway. Afterwards all looked as before, but `back` led to the Desktop.
  @Test func alsoWhenItsWindowSpeaksBeforeTheAppIsSaidToBeInFront() {
    let (h, emacs, safari, game) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    let before = h.workspace
    h.system.clearFrameLog()

    h.system.focused = game
    h.controller.windowFocused(game)
    #expect(h.workspace == before, "the view waits for the word that is on its way")
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    h.system.activateApp(of: game)
    #expect(h.controller.isPaused && h.controller.isPausedForApp)
    #expect(h.frame(emacs)!.fractionInside(h.visibleFrame) > 0.99)
    h.scheduler.advance(by: 2)
    #expect(h.controller.isPausedForApp)

    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
    #expect(h.workspace == before)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Nothing says that the word must come. A window that has the keyboard is not left out of view for it.
  @Test func ifNobodyEverSaysThatTheAppIsInFrontItsWindowComesIntoViewAllTheSame() {
    let (h, _, safari, game) = makeHarness()
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(game))
    h.system.focused = game
    h.controller.windowFocused(game)
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning)
    #expect(h.system.isVisible(game))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Whoever resumed by hand inside the app meant it: there Arbor is as it is in any app, and waits for no pause.
  @Test func resumedByHandInsideTheAppItsWindowsComeIntoViewWithoutThatWait() {
    let (h, _, _, game) = makeHarness()
    h.system.userFocus(game)
    #expect(h.controller.isPausedForApp)
    h.run("resume")
    // All within the app, which stays in front: one of its windows is framed, the other floats and goes out of view.
    let lobby = h.system.open(app: "Game")
    h.system.userFocus(game)
    h.run("dock \(game.rawValue) top")
    h.run("zoom \(game.rawValue)")
    #expect(h.controller.isRunning && !h.system.isVisible(lobby))
    h.system.focused = lobby
    h.controller.windowFocused(lobby)
    // Well before the look that a pause on its way would be given. (Not "at once": the view may take a moment of its own to follow the
    // keyboard from one window of an app to another.)
    h.scheduler.advance(by: 0.1)
    #expect(h.system.isVisible(lobby))
  }

  /// The real window system is stopped during a pause, so the switch that ends the pause is reported
  /// only as an app coming to the front, never as a window taking the focus.
  @Test func theWindowSwitchedToIsInViewAfterThePauseEnds() {
    let (h, emacs, safari, game) = makeHarness(passThrough: [])
    h.run("zoom \(safari.rawValue)")
    h.system.userFocus(game)
    h.system.focused = emacs
    h.system.activateApp(of: emacs)
    #expect(h.controller.isRunning)
    #expect(h.system.isVisible(emacs), "the view moved to show the window that has the keyboard")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aPauseStartedByHandBeforehandIsLeftAlone() {
    let (h, _, safari, game) = makeHarness()
    h.run("pause")
    h.system.userFocus(game)
    #expect(h.controller.isPaused && !h.controller.isPausedForApp)
    h.system.userFocus(safari)
    #expect(h.controller.isPaused, "only `resume` ends it")
    #expect(h.run("resume").ok)
  }

  @Test func aPauseAskedForByHandDuringTheAppsPauseOutlivesIt() {
    let (h, _, safari, game) = makeHarness()
    h.system.userFocus(game)
    #expect(h.run("pause").ok)
    #expect(!h.controller.isPausedForApp)
    h.system.userFocus(safari)
    #expect(h.controller.isPaused)
  }

  @Test func resumingByHandInsideTheAppHoldsUntilItComesToTheFrontAgain() {
    let (h, _, safari, game) = makeHarness()
    h.system.userFocus(game)
    #expect(h.run("toggle-pause").ok)
    #expect(h.controller.isRunning)
    h.run("exclude com.example.mail")
    h.run("reload-settings")
    #expect(h.controller.isRunning, "a change of settings does not pause behind the user's back")
    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
    h.system.userFocus(game)
    #expect(h.controller.isPausedForApp)
  }

  @Test func goingFromOneListedAppToAnotherStaysPaused() {
    let (h, _, safari, game) = makeHarness(pauseFor: [Self.gameID, "com.example.other"])
    h.system.userFocus(game)
    let moves = h.system.frameLog.count
    h.system.activate(bundleID: "com.example.other", name: "Other")
    #expect(h.controller.isPausedForApp)
    #expect(h.system.frameLog.count == moves, "no resuming and pausing again in between")
    #expect(h.run("status").message.hasPrefix("paused for Other: "))
    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
  }

  @Test func resumingByHandInOneListedAppDoesNotCoverTheNext() {
    let (h, _, _, game) = makeHarness(pauseFor: [Self.gameID, "com.example.other"])
    h.system.userFocus(game)
    h.run("resume")
    h.system.activate(bundleID: "com.example.other", name: "Other")
    #expect(h.controller.isPausedForApp)
  }

  /// macOS reports the window first and the app second; the fake does it the other way round.
  @Test func theOrderOfTheTwoReportsDoesNotMatter() {
    let (h, emacs, safari, game) = makeHarness(apart: true)
    h.run("zoom \(safari.rawValue)")
    h.system.focused = emacs
    h.controller.windowFocused(emacs)
    h.system.activateApp(of: emacs)
    #expect(h.controller.isPassingThrough)
    #expect(h.system.isVisible(emacs))
    h.system.focused = game
    h.controller.windowFocused(game)
    h.system.activateApp(of: game)
    #expect(h.controller.isPausedForApp)
    #expect(h.controller.activeBindings.map(\.command) == [.togglePause])
  }

  @Test func aTimedPauseThatEndsInsideAListedAppGoesOnAsThatAppsPause() {
    let (h, _, safari, game) = makeHarness()
    h.run("pause 10")
    h.system.userFocus(game)
    h.scheduler.advance(by: 601)
    #expect(h.controller.isPaused && h.controller.isPausedForApp)
    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
  }

  @Test func aTimedPauseStillEndsByItselfElsewhere() {
    let (h, _, _, _) = makeHarness()
    h.run("pause 10")
    h.scheduler.advance(by: 601)
    #expect(h.controller.isRunning)
  }

  @Test func puttingTheFrontmostAppOnTheListPausesAndTakingItOffResumes() {
    let (h, emacs, _, _) = makeHarness(passThrough: [], pauseFor: [])
    h.system.userFocus(emacs)
    var edited = h.controller.settings
    edited.pauseForApps = [Self.emacsID]
    h.controller.apply(settings: edited)
    #expect(h.controller.isPausedForApp)
    edited.pauseForApps = []
    h.controller.apply(settings: edited)
    #expect(h.controller.isRunning)
  }

  @Test func anAppOnBothListsPauses() {
    let (h, emacs, safari, _) = makeHarness(passThrough: [Self.emacsID], pauseFor: [Self.emacsID])
    h.system.userFocus(emacs)
    #expect(h.controller.isPausedForApp)
    #expect(h.controller.activeBindings.map(\.command) == [.togglePause])
    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
    #expect(h.controller.activeBindings == KeyBindings.core)
  }

  @Test func quittingDuringAnAppsPauseIsSafeAndTheArrangementSurvives() {
    let (h, emacs, _, game) = makeHarness()
    h.system.userFocus(game)
    h.controller.shutdown()
    #expect(h.store.saved?.workspaces[h.display]?.isDocked(emacs) == true)
    #expect(h.frame(emacs)!.fractionInside(h.visibleFrame) > 0.99)
  }

  /// The app reports who is in front before it starts the controller.
  @Test func launchingBehindAListedAppHoldsNothingFromTheStart() {
    var settings = Settings()
    settings.passThroughApps = [Self.emacsID]
    let h = Harness(settings: settings)
    h.system.open(app: "Emacs")
    var held: [Int] = []
    h.controller.observe { [weak controller = h.controller] change in
      if change == .lifecycle || change == .input, let controller, controller.isRunning {
        held.append(controller.activeBindings.count)
      }
    }
    h.system.activate(bundleID: Self.emacsID, name: "Emacs")
    h.start()
    #expect(held == [1], "never the whole set")
  }

  @Test func launchingBehindAnAppArborPausesForPausesAtOnce() {
    var settings = Settings()
    settings.pauseForApps = [Self.gameID]
    let h = Harness(settings: settings)
    let game = h.system.open(app: "Game")
    let safari = h.system.open(app: "Safari")
    h.system.activateApp(of: game)
    h.start()
    #expect(h.controller.isPausedForApp)
    h.system.userFocus(safari)
    #expect(h.controller.isRunning)
  }

  /// Before Accessibility is granted Arbor neither runs nor is paused: there is nothing to let go of.
  @Test func nothingHappensBeforeArborHasStarted() {
    var settings = Settings()
    settings.pauseForApps = [Self.gameID]
    let h = Harness(settings: settings)
    h.system.activate(bundleID: Self.gameID, name: "Game")
    #expect(!h.controller.isPaused && !h.controller.isRunning)
    h.system.activate(bundleID: "com.apple.finder", name: "Finder")
    #expect(!h.controller.isPaused && !h.controller.isRunning)
  }
}
