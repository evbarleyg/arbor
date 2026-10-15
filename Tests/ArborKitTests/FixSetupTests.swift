import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `fix-setup`: the one step that switches off what macOS as it comes does with the drags and clicks Arbor uses, and the
/// way back (docs/features/F42-setup-check.md, "Turn it off for me"). Through the real controller and a fake Mac.
@Suite @MainActor struct FixSetupTests {
  /// A harness whose facts about Desktop & Dock are what its fake Mac stores.
  func makeHarness(settings: Settings = Settings()) -> Harness {
    let h = Harness(settings: settings)
    h.controller.systemFacts = { [unowned h] in
      SystemFacts(
        accessibility: h.controller.accessibilityGranted, screenRecording: false, switches: h.mac.on, inputSources: 1)
    }
    return h
  }

  /// What is on as a Mac comes, and what of it the step is about: as little as possible (Q24: the click on the wallpaper is in nobody's way).
  static let asAMacComes: [MacSwitch] = [.clickWallpaper, .screenEdges, .menuBar, .optionKey]
  static let tiling: [MacSwitch] = [.screenEdges, .menuBar, .optionKey]

  @Test func oneStepSwitchesOffAllThatIsInTheWayAndOneStepPutsItBack() {
    let h = makeHarness()
    h.start()
    #expect(h.mac.on == Self.asAMacComes)

    let fixed = h.run("fix-setup")
    #expect(fixed.ok)
    #expect(
      fixed.message == "switched off 3 settings of macOS under Desktop & Dock; `fix-setup undo` puts them back as they were")
    #expect(h.mac.on == [.clickWallpaper], "which is left as its owner has it")
    #expect(h.mac.values == [.screenEdges: false, .menuBar: false, .optionKey: false])
    #expect(h.mac.before == Self.tiling.map { MacSwitchRecord($0, stored: nil) })

    let undone = h.run("fix-setup undo")
    #expect(undone.ok)
    #expect(undone.message == "put 3 settings of macOS under Desktop & Dock back as they were")
    #expect(h.mac.values.isEmpty, "nothing was stored before, and nothing is now")
    #expect(h.mac.on == Self.asAMacComes)
    #expect(h.mac.before.isEmpty)
  }

  /// Never by itself: not at the start, not with the welcome window, not when `doctor` finds them.
  @Test func nothingIsChangedUnasked() {
    let h = makeHarness()
    h.controller.openWelcomeWindow = { _ in }
    let a = h.system.open(app: "Safari")
    h.start()
    h.scheduler.advance(by: 10)
    for command in ["doctor", "check-setup", "welcome", "menu", "status", "dock \(a.rawValue) left", "float-all", "pause", "resume"] {
      h.run(command)
    }
    h.controller.shutdown()
    #expect(h.mac.writes.isEmpty && h.mac.before.isEmpty)
  }

  @Test func onlyWhatIsInTheWayIsTouchedAndOnlyThatIsPutBack() {
    let h = makeHarness()
    // Their owner switched one off by hand, and wrote another down as on.
    h.mac.values = [.menuBar: false, .optionKey: true]
    h.start()
    #expect(h.run("fix-setup").message.hasPrefix("switched off 2 settings"))
    #expect(h.mac.writes.map(\.item) == [.screenEdges, .optionKey])
    #expect(h.run("fix-setup undo").message.hasPrefix("put 2 settings"))
    #expect(h.mac.values == [.menuBar: false, .optionKey: true], "exactly as it was")
  }

  @Test func oneSettingIsOneSetting() {
    let h = makeHarness()
    h.mac.values = [.menuBar: false, .optionKey: false]
    #expect(
      h.run("fix-setup").message == "switched off 1 setting of macOS under Desktop & Dock; `fix-setup undo` puts it back as it was")
    #expect(h.run("fix-setup undo").message == "put 1 setting of macOS under Desktop & Dock back as it was")
  }

  /// Stage Manager is off as a Mac comes: whoever has it on chose it, and switching it off rearranges their windows.
  @Test func stageManagerIsItsOwnersToSwitchOff() {
    let h = makeHarness()
    h.mac.values = [.stageManager: true, .screenEdges: false, .menuBar: false, .optionKey: false]
    let result = h.run("fix-setup")
    #expect(!result.ok)
    #expect(result.message == "Stage Manager is yours to switch off: System Settings → Desktop & Dock")
    #expect(h.mac.writes.isEmpty)

    h.mac.values[.menuBar] = nil
    let other = h.run("fix-setup")
    #expect(other.ok && other.message.hasPrefix("switched off 1 setting"))
    #expect(other.message.hasSuffix("Stage Manager is yours to switch off: System Settings → Desktop & Dock"))
    #expect(h.mac.values[.stageManager] == true)
  }

  @Test func withNothingInTheWayThereIsNothingToDo() {
    let h = makeHarness()
    h.mac.macOS = 13
    let result = h.run("fix-setup")
    #expect(result.ok && result.message == "no setting of macOS is in Arbor’s way")
    let undo = h.run("fix-setup undo")
    #expect(!undo.ok && undo.message == "Arbor has changed no setting of macOS")
    #expect(h.mac.writes.isEmpty)
  }

  /// "Unknown" is never "fine" (F42).
  @Test func whatCannotBeReadIsNotCalledInOrder() {
    let h = makeHarness()
    h.controller.systemFacts = { SystemFacts(accessibility: true, screenRecording: false, switches: nil) }
    let result = h.run("fix-setup")
    #expect(!result.ok && result.message == "how macOS’s settings stand cannot be read here; see System Settings → Desktop & Dock")
    h.controller.systemFacts = nil
    #expect(!h.run("fix-setup").ok)
    #expect(h.mac.writes.isEmpty)
  }

  /// As little as possible. On a Mac where the click on the wallpaper is all that is on, there is nothing to do.
  @Test func theClickOnTheWallpaperIsLeftAlone() {
    let h = makeHarness()
    h.mac.macOS = 14
    #expect(h.mac.on == [.clickWallpaper])
    let result = h.run("fix-setup")
    #expect(result.ok && result.message == "no setting of macOS is in Arbor’s way")
    #expect(h.mac.writes.isEmpty)
  }

  /// The first answer is the one that counts: how the Mac was before Arbor touched it.
  @Test func aSecondRoundKeepsWhatTheFirstOneWroteDown() {
    let h = makeHarness()
    h.run("fix-setup")
    // Switched on again in System Settings, which stores it.
    h.mac.values[.screenEdges] = true
    #expect(h.run("fix-setup").message.hasPrefix("switched off 1 setting"))
    #expect(h.mac.before.count == 3)
    h.run("fix-setup undo")
    #expect(h.mac.values.isEmpty)
  }

  /// A Mac on which somebody else manages one of the switches: what is written for it does not stay. Half a step would be harder to account
  /// for than none, so the others go back as they were, and what was written for the managed one is taken back too: a value that a profile
  /// only hides comes into force the day the profile goes.
  @Test func aMacThatDoesNotKeepTheChangeGetsAllOfItBack() {
    let h = makeHarness()
    h.mac.values = [.optionKey: true]
    h.mac.managed = [.screenEdges]
    let result = h.run("fix-setup")
    #expect(!result.ok)
    #expect(
      result.message
        == "macOS did not keep the change (is this Mac managed by somebody else?), so nothing was changed; try System Settings → Desktop & Dock")
    #expect(h.mac.values == [.optionKey: true], "as it was")
    #expect(h.mac.writes.suffix(3) == [
      MacSwitchRecord(.screenEdges, stored: nil), MacSwitchRecord(.menuBar, stored: nil), MacSwitchRecord(.optionKey, stored: true),
    ])
    #expect(h.mac.before.isEmpty, "nothing was changed, so there is nothing to put back")
  }

  /// A failed second round costs nothing of what the first one wrote down.
  @Test func aFailedRoundLeavesTheEarlierRecordAlone() {
    let h = makeHarness()
    h.run("fix-setup")
    let first = h.mac.before
    h.mac.values[.menuBar] = true
    h.mac.managed = [.menuBar]
    #expect(!h.run("fix-setup").ok)
    #expect(h.mac.before == first)
  }

  /// The way back is checked as the step is. What did not go back is still owed, and stays written down.
  @Test func whatMacOSDoesNotTakeBackStaysWrittenDown() {
    let h = makeHarness()
    h.run("fix-setup")
    h.mac.managed = [.menuBar]
    let result = h.run("fix-setup undo")
    #expect(!result.ok)
    #expect(
      result.message == "macOS did not take 1 of 3 settings back (is this Mac managed by somebody else?); they stay written down, and "
        + "System Settings → Desktop & Dock has the switches")
    #expect(h.mac.before == [MacSwitchRecord(.menuBar, stored: nil)])
    h.mac.managed = []
    #expect(h.run("fix-setup undo").message == "put 1 setting of macOS under Desktop & Dock back as it was")
    #expect(h.mac.values.isEmpty && h.mac.before.isEmpty)
  }

  /// A record that cannot be read is not "nothing is owed": nothing is written over it, and nobody is told that nothing was changed.
  @Test func aRecordThatCannotBeReadStopsBothWays() {
    let h = makeHarness()
    h.mac.cannotRead = true
    for command in ["fix-setup", "fix-setup undo"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(
        result.message == "what Arbor wrote down about macOS’s settings cannot be read (macos-settings-before.json), so nothing was changed; "
          + "see System Settings → Desktop & Dock")
    }
    #expect(h.mac.writes.isEmpty)
  }

  /// A full disk, say. Without a way back the step is not taken.
  @Test func whatCannotBeWrittenDownIsNotChanged() {
    let h = makeHarness()
    h.mac.cannotKeep = true
    let result = h.run("fix-setup")
    #expect(!result.ok)
    #expect(result.message == "could not write down how the settings are, so nothing was changed; try System Settings → Desktop & Dock")
    #expect(h.mac.writes.isEmpty && h.mac.on == Self.asAMacComes)
  }

  @Test func itNeedsNoPermissionAndNoRunningArbor() {
    let h = makeHarness()
    h.controller.accessibilityGranted = false
    #expect(h.run("fix-setup").ok)
    #expect(h.mac.on == [.clickWallpaper])
    h.controller.accessibilityGranted = true
    h.start()
    h.run("pause")
    #expect(h.run("fix-setup undo").ok)
  }

  @Test func whereNothingCanBeChangedItSaysWhereTo() {
    let h = makeHarness()
    h.controller.macSwitchboard = nil
    for command in ["fix-setup", "fix-setup undo"] {
      let result = h.run(command)
      #expect(!result.ok && result.message == "this Arbor cannot change settings of macOS; see System Settings → Desktop & Dock")
    }
  }

  /// What was written down outlasts Arbor: the way back is there at the next launch, whatever became of the saved arrangement.
  @Test func theWayBackOutlastsAQuit() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()

    let next = makeHarness()
    next.mac.values = h.mac.values
    next.mac.before = h.mac.before
    next.start()
    #expect(next.run("fix-setup undo").ok)
    #expect(next.mac.values.isEmpty)
  }

  /// Anything can open a URL, and this changes settings of the Mac's.
  @Test func noLinkCanDoIt() {
    #expect(!Command.fixSetup(undo: false).isAllowedFromURL)
    #expect(!Command.fixSetup(undo: true).isAllowedFromURL)
  }

  @Test func theCommandHasATextForm() throws {
    #expect(try Command.parse("fix-setup") == .fixSetup(undo: false))
    #expect(try Command.parse("fix-setup undo") == .fixSetup(undo: true))
    #expect(Command.fixSetup(undo: false).text == "fix-setup")
    #expect(Command.fixSetup(undo: true).text == "fix-setup undo")
    #expect(throws: (any Error).self) { try Command.parse("fix-setup now") }
  }

  // MARK: In the welcome window

  /// The whole of it as a newcomer meets it: the row, the button, the tick, the way back.
  @Test func theWelcomeWindowsButtonTakesTheStepAndThenOffersTheWayBack() throws {
    let h = makeHarness()
    let a = h.system.open(app: "Safari")
    let before = h.frame(a)
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    #expect(session.model.title == "Ready, with one suggestion")
    let step = try #require(session.model.row(.desktopAndDock)?.action)
    #expect(step.title == "Switch Off macOS Tiling")

    #expect(h.controller.perform(step.command, from: .menu).ok)
    session.refresh()
    #expect(session.model.title == "Arbor is ready")
    let row = try #require(session.model.row(.desktopAndDock))
    #expect(row.isSatisfied && row.action == nil)
    #expect(
      row.done == "Arbor switched off 3 settings of macOS for you. They stay off, even after you quit Arbor, until you put them back: here, or "
        + "later under Help → Check Setup… in Arbor’s menu. A window dragged to a screen edge docks now.")
    #expect(session.model.page == .permissions, "it stays, so that what was done can be read")

    let back = try #require(row.undo)
    #expect(back.title == "Put Them Back")
    #expect(h.controller.perform(back.command, from: .menu).ok)
    session.refresh()
    #expect(session.model.row(.desktopAndDock)?.action?.title == "Switch Off macOS Tiling")
    #expect(session.model.row(.desktopAndDock)?.undo == nil)
    #expect(h.mac.values.isEmpty)
    #expect(h.frame(a) == before && h.system.frameLog.isEmpty, "and no window has moved for any of it")
  }

  /// Before Arbor runs there is no display to say anything on, and a button that seems dead gets pressed again.
  @Test func aStepThatFailsIsSaidInTheWindow() throws {
    let h = makeHarness()
    h.controller.accessibilityGranted = false
    h.mac.managed = [.menuBar]
    var shown = 0
    let session = OnboardingSession(controller: h.controller) { _ in shown += 1 }
    session.begin()
    let step = try #require(session.model.row(.desktopAndDock)?.action)
    session.actionEnded(h.controller.perform(step.command, from: .menu))
    #expect(shown == 1)
    #expect(
      session.model.row(.desktopAndDock)?.failure
        == "That did not work: macOS did not keep the change (is this Mac managed by somebody else?), so nothing was changed; try "
        + "System Settings → Desktop & Dock.")
    // It goes with the next try that works, and with the window.
    h.mac.managed = []
    session.actionEnded(h.controller.perform(step.command, from: .menu))
    #expect(session.model.row(.desktopAndDock)?.failure.isEmpty == true)
    h.mac.managed = [.menuBar]
    session.actionEnded(h.run("fix-setup undo"))
    #expect(session.model.row(.desktopAndDock)?.failure.isEmpty == false)
    session.end()
    session.begin()
    #expect(session.model.row(.desktopAndDock)?.failure.isEmpty == true)
  }

  /// The row promised the way back "here". It is here whatever else the row has to say.
  @Test func theWayBackIsOfferedAlsoWhileSomethingIsInTheWay() throws {
    let h = makeHarness()
    h.mac.values = [.stageManager: true]
    h.run("fix-setup")
    var facts = try #require(h.controller.systemFacts?())
    #expect(facts.switches == [.clickWallpaper, .stageManager])
    var row = try #require(h.controller.onboardingModel(facts).row(.desktopAndDock))
    #expect(row.state == .recommended && row.action == nil)
    #expect(row.undo?.title == "Put Them Back")
    #expect(
      row.done == "Arbor switched off 3 settings of macOS for you. They stay off, even after you quit Arbor, until you put them back: here, or "
        + "later under Help → Check Setup… in Arbor’s menu. A window dragged to a screen edge docks now.")

    // One is switched on again by hand: the step for that one, and the way back for all.
    h.mac.values[.stageManager] = nil
    h.mac.values[.menuBar] = true
    facts = try #require(h.controller.systemFacts?())
    row = try #require(h.controller.onboardingModel(facts).row(.desktopAndDock))
    #expect(row.action?.title == "Switch Off macOS Tiling" && row.undo?.title == "Put Them Back")
  }

  /// Rule 2, said to whom it is true of: Arbor has never run here and nothing is docked.
  @Test func aNewcomerIsPromisedThatNothingMoves() throws {
    let promise = "Nothing moves until you “dock” a window: put it at a side of the screen."
    let h = makeHarness()
    let a = h.system.open(app: "Safari")
    func summary() throws -> String { h.controller.onboardingModel(try #require(h.controller.systemFacts?())).summary }
    #expect(try !summary().contains(promise), "a later start brings back what was docked")
    h.controller.isFirstLaunch = true
    #expect(try summary().hasSuffix(promise))
    h.start()
    #expect(try summary().hasSuffix(promise))
    h.run("dock \(a.rawValue) left")
    #expect(try !summary().contains(promise), "it has been kept, and is over")
  }

  /// An Arbor under test on somebody's Mac has no switchboard, and shows no button a script's click could land on.
  @Test func withoutASwitchboardTheWindowOffersNoButton() throws {
    let h = makeHarness()
    h.controller.macSwitchboard = nil
    let facts = try #require(h.controller.systemFacts?())
    let row = try #require(h.controller.onboardingModel(facts).row(.desktopAndDock))
    #expect(row.action == nil && row.state == .recommended)
  }

  /// The window looks at the Mac once a second, so the first move follows the switch.
  @Test func theFirstMoveBecomesTheDragOnceTheStepIsTaken() {
    let h = makeHarness()
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin(on: .firstSteps)
    #expect(session.model.step(.dock)?.lead == "Click a window and press ⌃⌥⌘←")
    h.run("fix-setup")
    session.refresh()
    #expect(session.model.step(.dock)?.lead == "Drag a window to the left edge of the screen")
  }

  // MARK: In the menu

  /// Whoever passed the offer by has declined it (Q23): neither the menu nor the icon reminds them. Check Setup… has it when they want it.
  @Test func decliningIsRespected() {
    let h = makeHarness()
    h.start()
    let withTilingOn = h.controller.menuModel()
    #expect(h.controller.menuBarModel().icon == MenuBarModel.Icon())
    h.run("fix-setup")
    #expect(h.controller.menuModel() == withTilingOn, "the menu is the same either way")
    #expect(withTilingOn.allItems.contains { $0.command == .checkSetup })
  }

  // MARK: What `doctor` says

  @Test func doctorNamesTheOneStepAndAfterwardsTheWayBack() throws {
    let h = makeHarness()
    h.start()
    let before = try #require(h.controller.doctorReport().check("Desktop & Dock settings"))
    #expect(before.mark == .problem)
    #expect(before.detail.contains("`fix-setup` switches them off"))
    #expect(before.notes.count == 4, "the three, and a note on the click on the wallpaper")

    h.run("fix-setup")
    let after = try #require(h.controller.doctorReport().check("Desktop & Dock settings"))
    #expect(after.mark == .ok)
    #expect(after.detail == "none in the way")
    #expect(after.notes.last == "Arbor switched off 3 of them; `fix-setup undo` puts them back as they were")

    h.run("fix-setup undo")
    #expect(h.controller.doctorReport().check("Desktop & Dock settings")?.mark == .problem)
  }
}
