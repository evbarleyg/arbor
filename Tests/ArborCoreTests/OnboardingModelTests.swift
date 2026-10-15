import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The labels of the default shortcuts the window mentions.
private func defaults(_ command: Command) -> String? {
  switch command {
  case .zoom(nil): "⌃⌥↩"
  case .showAll: "⌃⌥Space"
  case .dock(nil, .left): "⌃⌥⌘←"
  case .dock(nil, .right): "⌃⌥⌘→"
  case .dock(nil, .top): "⌃⌥⌘↑"
  case .dock(nil, .bottom): "⌃⌥⌘↓"
  case .togglePause: "⌃⌥⎋"
  case .undo: "⌃⌥Z"
  default: nil
  }
}

/// A Mac fresh out of the box, and one where everything is as Arbor likes it.
private let fresh = SystemFacts(
  accessibility: false, screenRecording: false, switches: [.clickWallpaper, .screenEdges, .menuBar, .optionKey])
private let tuned = SystemFacts(accessibility: true, screenRecording: true, switches: [])

/// What the welcome window says (docs/features/F10-menu-bar-and-onboarding.md).
@Suite struct OnboardingModelTests {
  @Test func onlyAccessibilityKeepsArborFromBeingReady() {
    var facts = fresh
    facts.voiceOver = true
    facts.inputSources = 3
    facts.competingApps = ["Rectangle"]
    #expect(!OnboardingModel(facts, shortcut: defaults).isReady)
    facts.accessibility = true
    #expect(OnboardingModel(facts, shortcut: defaults).isReady)
    var missing = tuned
    missing.accessibility = false
    #expect(!OnboardingModel(missing).isReady)
  }

  @Test func aFreshMacNeedsOneThingAndIsOfferedTwoMore() {
    // Check Setup…, where every row is.
    let model = OnboardingModel(fresh, offersScreenRecording: true, shortcut: defaults)
    #expect(model.page == .setup && model.title == "Arbor needs one permission")
    #expect(model.summary == "What on this Mac matters to Arbor, and how it stands.")
    #expect(model.rows.map(\.id) == [.accessibility, .screenRecording, .desktopAndDock])
    #expect(model.rows.map(\.state) == [.required, .optional, .recommended])
    #expect(model.rows.map(\.importance) == ["Required", "Optional", "Recommended"])
    #expect(model.rows.map(\.status) == ["Not granted", "Not granted", "On"])
    #expect(model.rows.allSatisfy { !$0.isSatisfied && !$0.detail.isEmpty && $0.button != nil })
    var permitted = fresh
    permitted.accessibility = true
    #expect(OnboardingModel(permitted).title == "Ready, with one suggestion")
    // An ad-hoc build loses the permission while System Settings still shows the switch on.
    let alreadyOn = " Already on? Switch it off and on again: macOS asks anew after every update."
    #expect(model.row(.accessibility)?.detail.hasSuffix("This window comes back by itself." + alreadyOn) == true)
    // To a newcomer as well. Another build over an old grant looks like a first launch, the switch looks on, and Arbor waits: whoever meets
    // that finds nothing to flip. Arbor cannot tell the two apart, so the sentence is always there, short, last in the row.
    #expect(OnboardingModel(fresh, isNewcomer: true).row(.accessibility)?.detail.hasSuffix(alreadyOn) == true)
    // Where the permission went while Arbor ran nothing was updated: what to do, without that reason.
    #expect(OnboardingModel(fresh, windowsOutOfView: 3).row(.accessibility)?.detail.hasSuffix(" Already on? Switch it off and on again.") == true)
    #expect(model.row(.screenRecording)?.detail.contains("Nothing is recorded or stored") == true)
    #expect(model.row(.desktopAndDock)?.points.count == 3, "the click on the wallpaper is in nobody's way (Q24)")
  }

  @Test func everythingInOrderIsAllDone() {
    let model = OnboardingModel(tuned, offersScreenRecording: true, shortcut: defaults)
    #expect(model.title == "Arbor is ready")
    #expect(model.rows.map(\.id) == [.accessibility, .screenRecording, .desktopAndDock])
    #expect(model.rows.allSatisfy { $0.isSatisfied })
    #expect(model.rows.map(\.status) == ["Granted", "Granted", "Off"])
    // "Recommended" beside a tick would read as if there were still something to change.
    #expect(model.rows.map(\.importance) == ["Granted", "Granted", "Off"])
    // A tick says enough, and the window stays short. Nor is there anything to go to System Settings for.
    #expect(model.rows.allSatisfy { $0.detail.isEmpty && $0.points.isEmpty && $0.button == nil })
  }

  @Test func eachRowFollowsItsOwnFact() {
    let one = OnboardingModel(
      SystemFacts(accessibility: true, screenRecording: false, switches: [.menuBar]), offersScreenRecording: true)
    #expect(one.rows.map(\.isSatisfied) == [true, false, false])
    let other = OnboardingModel(
      SystemFacts(accessibility: false, screenRecording: true, switches: []), offersScreenRecording: true)
    #expect(other.rows.map(\.isSatisfied) == [false, true, true])
  }

  /// The first minute asks for the one permission and for nothing else (Q29, 11): what Arbor is for, the row, the keys, where it lives.
  @Test func theWelcomeAsksForThePermissionAndNothingElse() {
    func welcome(_ facts: SystemFacts, isNewcomer: Bool = true, isPaused: Bool = false, shortcut: (Command) -> String? = defaults) -> OnboardingModel {
      OnboardingModel(
        facts, flow: OnboardingFlow(isReady: facts.accessibility), offersScreenRecording: true, appsWithOwnShortcuts: ["Emacs"], canFixSetup: true,
        isNewcomer: isNewcomer, isPaused: isPaused, shortcut: shortcut)
    }
    var facts = fresh
    facts.inputSources = 3
    let model = welcome(facts)
    #expect(model.page == .permissions && model.rows.map(\.id) == [.accessibility])
    #expect(model.title == "Arbor keeps your windows arranged")
    #expect(
      model.summary
        == "Arrange windows side by side once. Fill the screen with any one, and one key brings the arrangement back. Your Mac’s own tiling forgets "
        + "an arrangement; Arbor keeps it.", "what it is for, and what it has over the tiling a Mac comes with")
    // The keys in a sentence, with the promise somebody wants who is about to let an app move their windows, made where it holds.
    let keys = "⌃⌥⌘← and ⌃⌥⌘→ put a window left or right. ⌃⌥↩ fills the screen with it, and brings both back."
    #expect(model.keysLine == "Nothing moves until you ask. " + keys)
    #expect(welcome(facts, isNewcomer: false).keysLine == keys)
    #expect(model.keysLegend == "⌃ is Control, ⌥ Option, ⌘ Command, ↩ Return.")
    #expect(welcome(facts, shortcut: { _ in nil }).keysLine.isEmpty && welcome(facts, shortcut: { _ in nil }).keysLegend.isEmpty)
    #expect(model.footnote == "Arbor lives in the menu bar, under this icon.")
    #expect(model.primaryButton == "Continue" && !model.isPrimaryEnabled && model.backButton == nil)

    // With the permission there: the same, and nothing holds anybody up.
    facts.accessibility = true
    #expect(welcome(facts).title == "Arbor keeps your windows arranged" && welcome(facts).isPrimaryEnabled && !welcome(facts).needsAttention)
    #expect(welcome(facts).pageToOpenOn == .permissions, "a newcomer is told what Arbor is for first")
    #expect(welcome(facts, isNewcomer: false).pageToOpenOn == .firstSteps)
    #expect(welcome(facts, isPaused: true).title == "Arbor is paused", "or Continue would lead to moves that do nothing")
    // What would make the keys of the four moves do two things at once is said all the same.
    facts.competingApps = ["Rectangle"]
    facts.voiceOver = true
    #expect(welcome(facts).rows.map(\.id) == [.accessibility, .competingApps, .voiceOver] && welcome(facts).needsAttention)
    // And so is Stage Manager, which moves windows itself. Of macOS's tiling, in the same row of Check Setup…, not a word.
    facts = fresh
    facts.accessibility = true
    facts.switches = [.screenEdges, .menuBar, .optionKey, .stageManager]
    let stage = welcome(facts)
    #expect(stage.rows.map(\.id) == [.accessibility, .desktopAndDock] && stage.needsAttention)
    #expect(stage.row(.desktopAndDock)?.title == "Stage Manager" && stage.row(.desktopAndDock)?.action == nil)
    #expect(stage.row(.desktopAndDock)?.detail == "Stage Manager moves windows itself: use one or the other.")
    // F63: the window that opens because the permission went is headed by that.
    facts = fresh
    #expect(
      OnboardingModel(facts, flow: OnboardingFlow(isReady: false), windowsOutOfView: 3, shortcut: defaults).title
        == "Arbor needs its permission back")
  }

  /// "Under this icon": the one that is in the menu bar at that moment, or the one time a newcomer looks for it, it is not what the window shows.
  @Test func theFootnoteShowsTheIconThatIsInTheMenuBarNow() {
    #expect(OnboardingModel(fresh).footnoteIcon == MenuBarModel.Icon(), "unless somebody says otherwise, Arbor's mark")
    for icon in [MenuBarModel.Icon.needsPermission, .paused, .held, .holdingStill] {
      let model = OnboardingModel(fresh, menuBarIcon: icon)
      #expect(model.footnoteIcon == icon)
      // Written out, by what VoiceOver reads of it.
      #expect(model.text.contains(model.footnote + " [\(icon.label)]"))
    }
    #expect(!OnboardingModel(fresh).text.contains(" [Arbor"))
  }

  @Test func theDesktopAndDockRowListsWhatIsStillInTheWay() throws {
    let all = try #require(OnboardingModel(fresh).row(.desktopAndDock))
    // What it does to a person, in words that need no learning. Then the switches by the names they have in System Settings, which say
    // in plain words what they do.
    #expect(all.title == "macOS tiling")
    #expect(all.detail == "Your Mac tiles a window dragged to a screen edge, before Arbor gets it.")
    #expect(
      all.points == [
        "“Drag windows to left or right edge of screen to tile”", "“Drag windows to menu bar to fill screen”",
        "“Hold ⌥ key while dragging windows to tile”",
      ])
    #expect(all.button == "Open Desktop & Dock…" && all.afterword.isEmpty)
    func detail(_ switches: [MacSwitch]) -> String? {
      var facts = fresh
      facts.switches = switches
      return OnboardingModel(facts).row(.desktopAndDock)?.detail
    }
    #expect(detail([.menuBar]) == "Your Mac tiles a window dragged to a screen edge, before Arbor gets it.")
    #expect(detail([.optionKey]) == "Your Mac tiles a window dragged with Option held, before Arbor gets it.")

    var facts = fresh
    facts.switches = [.optionKey]
    let one = try #require(OnboardingModel(facts).row(.desktopAndDock))
    #expect(one.state == .recommended)
    #expect(one.points == ["“Hold ⌥ key while dragging windows to tile”"] && one.afterword.isEmpty)

    facts.switches = [.stageManager]
    let stage = try #require(OnboardingModel(facts).row(.desktopAndDock))
    #expect(stage.title == "Stage Manager" && stage.detail == "Stage Manager moves windows itself: use one or the other." && stage.points.isEmpty)
  }

  // MARK: The one step

  /// Three switches to look for in System Settings are three steps. Before the one step is taken the row says what it touches, that it
  /// touches nothing else, that it can be undone, and where.
  @Test func theRowOffersToSwitchThemOffAndSaysHowToUndoIt() throws {
    let row = try #require(OnboardingModel(fresh, canFixSetup: true).row(.desktopAndDock))
    #expect(row.action == OnboardingModel.Row.Action("Switch Off macOS Tiling", .fixSetup(undo: false)))
    #expect(
      row.detail
        == "Your Mac tiles a window dragged to a screen edge, before Arbor gets it. Switch that off, only while Arbor runs, and Arbor has the edges.",
      "for how long makes it a small thing to ask: said in the text, not the small print")
    // By their names: without them "3 settings" made six readers of six uneasy.
    #expect(
      row.afterword == "Changes 3 settings in Desktop & Dock, nothing else: “Drag windows to left or right edge of screen to tile”, “Drag "
        + "windows to menu bar to fill screen”, “Hold ⌥ key while dragging windows to tile”.")
    #expect(row.button == "Or do it yourself in Desktop & Dock…", "whoever would rather do it by hand still can")
    #expect(row.points.isEmpty && row.state == .recommended, "the names are the small print")

    var facts = fresh
    facts.switches = [.menuBar]
    let one = try #require(OnboardingModel(facts, canFixSetup: true).row(.desktopAndDock))
    #expect(one.action?.title == "Switch Off macOS Tiling")
    #expect(one.afterword == "Changes 1 setting in Desktop & Dock, nothing else: “Drag windows to menu bar to fill screen”.")
  }

  @Test func whereArborCannotChangeThemTheRowOffersNothing() throws {
    let row = try #require(OnboardingModel(fresh).row(.desktopAndDock))
    #expect(row.action == nil && row.afterword.isEmpty && row.button != nil && !row.detail.contains("put it back"))
  }

  /// Whoever has Stage Manager on chose it.
  @Test func stageManagerIsNotPartOfTheStep() throws {
    var facts = fresh
    facts.switches = [.stageManager]
    let alone = try #require(OnboardingModel(facts, canFixSetup: true).row(.desktopAndDock))
    #expect(alone.action == nil && alone.afterword.isEmpty)
    facts.switches = [.screenEdges, .menuBar, .stageManager]
    let among = try #require(OnboardingModel(facts, canFixSetup: true).row(.desktopAndDock))
    #expect(among.action?.title == "Switch Off macOS Tiling")
    #expect(among.afterword.hasPrefix("Changes 2 settings in Desktop & Dock, nothing else: ") && !among.afterword.contains("Stage Manager"))
    #expect(among.detail.hasSuffix("Stage Manager moves windows itself: use one or the other."))
  }

  /// A tick says enough, except of what Arbor did to somebody's Mac: that is said for as long as it can be undone.
  @Test func afterTheStepTheRowSaysWhatWasDoneAndOffersTheWayBack() throws {
    let row = try #require(
      OnboardingModel(tuned, canFixSetup: true, switchesChangedByArbor: [.screenEdges, .menuBar]).row(.desktopAndDock))
    #expect(row.isSatisfied && row.importance == "Off")
    let two =
      "While Arbor runs, 2 settings of macOS are off. Quit or pause Arbor, and your Mac is as it was. To end that for good: here, or later "
      + "under Help → Check Setup… in Arbor’s menu."
    #expect(row.done == two + " A window dragged to a screen edge docks now.")
    #expect(row.undo == OnboardingModel.Row.Action("Put Them Back", .fixSetup(undo: true)) && row.action == nil)
    // What it was for is said only where it has come true: with the permission, without a pause, with every edge Arbor's.
    func done(_ facts: SystemFacts, isPaused: Bool = false) -> String? {
      OnboardingModel(facts, canFixSetup: true, switchesChangedByArbor: [.screenEdges, .menuBar], isPaused: isPaused)
        .row(.desktopAndDock)?.done
    }
    var facts = tuned
    #expect(done(facts, isPaused: true) == two)
    facts.switches = [.menuBar]
    #expect(
      done(facts) == two.replacingOccurrences(of: "2 settings of macOS are off", with: "1 setting of macOS is off"),
      "switched on again by hand: the top edge is macOS's, and that switch its owner's")
    facts = tuned
    facts.accessibility = false
    #expect(done(facts) == two, "nothing docks yet")
    let one = try #require(OnboardingModel(tuned, canFixSetup: true, switchesChangedByArbor: [.menuBar]).row(.desktopAndDock))
    #expect(one.done.hasPrefix("While Arbor runs, 1 setting of macOS is off. Quit or pause Arbor, and your Mac is as it was. "))
    #expect(one.undo?.title == "Put It Back")
    // In order by their owner's own hand: nothing to say.
    let own = try #require(OnboardingModel(tuned, canFixSetup: true).row(.desktopAndDock))
    #expect(own.action == nil && own.undo == nil && own.done.isEmpty && own.detail.isEmpty)
  }

  @Test func theDesktopAndDockRowIsLeftOutWhenTheSettingsCannotBeRead() {
    let model = OnboardingModel(SystemFacts(accessibility: false, screenRecording: false, switches: nil))
    #expect(model.rows.map(\.id) == [.accessibility])
  }

  /// Nobody is invited to grant a permission that Arbor does not yet make good use of.
  @Test func screenRecordingHasARowOnlyWhereItIsOffered() {
    #expect(OnboardingModel(fresh).rows.map(\.id) == [.accessibility, .desktopAndDock])
    #expect(OnboardingModel(tuned).rows.map(\.id) == [.accessibility, .desktopAndDock], "granted or not")
    #expect(OnboardingModel(fresh, offersScreenRecording: true).row(.screenRecording)?.state == .optional)
  }

  @Test func aPermissionTakenAwaySaysWhatIsOutOfViewAndHowToGetItBack() {
    let three = OnboardingModel(fresh, windowsOutOfView: 3)
    #expect(three.title == "Arbor needs its permission back")
    #expect(
      three.row(.accessibility)?.detail.hasPrefix(
        "3 windows are out of view, not closed. Grant the permission again to get them back. ") == true)
    #expect(
      OnboardingModel(fresh, windowsOutOfView: 1).row(.accessibility)?.detail.hasPrefix(
        "1 window is out of view, not closed. Grant the permission again to get it back. ") == true)
    #expect(OnboardingModel(fresh).row(.accessibility)?.detail.contains("out of view") == false)
    // Once it is back there is nothing left to say.
    #expect(OnboardingModel(tuned, windowsOutOfView: 3).title == "Arbor is ready")
  }

  /// macOS knows an ad-hoc build by its hash, so the next one has to ask again. Whoever is asked for the third time is told why,
  /// and whoever opens Check Setup while all is well is told before the next time comes.
  @Test func anAdHocSignatureIsNamedWithWhatItCosts() {
    func detail(_ facts: SystemFacts, _ signature: BuildInfo.Signature?) -> String? {
      OnboardingModel(facts, signature: signature).row(.accessibility)?.detail
    }
    // Not granted: what to do is said to everybody, with the reason wherever it may be true: ad hoc, and where nobody said.
    let whatToDo = " Already on? Switch it off and on again"
    for signature: BuildInfo.Signature? in [.adHoc, nil] {
      #expect(detail(fresh, signature)?.hasSuffix(whatToDo + ": macOS asks anew after every update.") == true)
    }
    // The next build signed with the same certificate inherits the permission, so of such a build the reason is not true.
    for signature: BuildInfo.Signature in [.local, .issued] {
      #expect(detail(fresh, signature)?.hasSuffix(whatToDo + ".") == true)
      #expect(detail(fresh, signature)?.contains("every update") == false)
    }
    // Where it went while Arbor ran nothing was updated, however the build is signed.
    #expect(OnboardingModel(fresh, windowsOutOfView: 3, signature: .adHoc).row(.accessibility)?.detail.hasSuffix(whatToDo + ".") == true)
    // Granted: whoever opens Check Setup is told before the next time comes.
    #expect(
      detail(tuned, .adHoc)
        == "macOS will ask for this permission again after each update of Arbor, because Arbor is not yet signed with an Apple "
        + "Developer ID.")
    // A download is signed so too, and "ad hoc" is a builder's word.
    #expect(detail(fresh, .adHoc)?.contains("ad hoc") == false && detail(tuned, .adHoc)?.contains("ad hoc") == false)
    // It is something to know, nothing to put right: the tick stays, and the window does not come up for it.
    let granted = OnboardingModel(tuned, signature: .adHoc)
    #expect(granted.row(.accessibility)?.state == .done)
    #expect(granted.isReady && granted.title == OnboardingModel(tuned).title)
    #expect(granted.pageToOpenOn == OnboardingModel(tuned).pageToOpenOn)
    // With a certificate, or where nobody said, a tick says enough.
    for signature: BuildInfo.Signature? in [.local, .issued, nil] { #expect(detail(tuned, signature) == "") }
    // So it does in the first minute: no update is near.
    #expect(OnboardingModel(tuned, isNewcomer: true, signature: .adHoc).row(.accessibility)?.detail == "")
  }

  @Test func otherWindowManagersAreNamed() throws {
    var facts = tuned
    facts.competingApps = ["Rectangle"]
    let one = try #require(OnboardingModel(facts).row(.competingApps))
    #expect(one.title == "Rectangle is running")
    #expect(one.state == .recommended && one.button == nil)
    #expect(one.detail.contains("Quit it"))
    #expect(one.detail.hasPrefix("It uses the same ⌃⌥ shortcuts or arranges windows as well"))

    facts.competingApps = ["Rectangle", "Magnet", "TrellisWM"]
    let three = try #require(OnboardingModel(facts).row(.competingApps))
    #expect(three.title == "Rectangle, Magnet and TrellisWM are running")
    #expect(three.detail.contains("Quit them"))
    #expect(three.detail.hasPrefix("They use the same ⌃⌥ shortcuts or arrange windows as well"))
  }

  @Test func voiceOverIsMentionedOnlyWhileShortcutsCanCollideWithIt() throws {
    var facts = tuned
    facts.voiceOver = true
    let row = try #require(OnboardingModel(facts, shortcut: defaults).row(.voiceOver))
    #expect(row.state == .recommended)
    #expect(row.detail.contains("Caps Lock") && row.detail.contains("hotkeysEnabled"))
    #expect(OnboardingModel(facts).row(.voiceOver) == nil, "Arbor's shortcuts are off")
    #expect(OnboardingModel(tuned, shortcut: defaults).row(.voiceOver) == nil)
  }

  @Test func severalInputSourcesPutShowEverythingInDoubt() throws {
    var facts = tuned
    facts.inputSources = 2
    let row = try #require(OnboardingModel(facts, shortcut: defaults).row(.inputSources))
    #expect(row.title == "2 input sources")
    #expect(row.state == .note, "there is nothing the user has to do")
    #expect(row.detail.contains("⌃⌥Space") && row.detail.contains("Select next source in Input menu"))
    // `home` does the same on another key.
    let withHome = OnboardingModel(facts) { $0 == .home ? "⌃⌥0" : defaults($0) }
    #expect(withHome.row(.inputSources)?.detail.hasSuffix(" ⌃⌥0 does the same.") == true)

    facts.inputSources = 1
    #expect(OnboardingModel(facts, shortcut: defaults).row(.inputSources) == nil)
    facts.inputSources = nil
    #expect(OnboardingModel(facts, shortcut: defaults).row(.inputSources) == nil)
    // Moved to another key, Show Everything has nothing to fear.
    facts.inputSources = 2
    let moved = OnboardingModel(facts) { $0 == .showAll ? "⌃⌥E" : defaults($0) }
    #expect(moved.row(.inputSources) == nil)
  }

  // MARK: The pages

  @Test func checkSetupSaysAllOfWhereArborLives() {
    let waiting = OnboardingModel(fresh, shortcut: defaults)
    #expect(waiting.page == .setup, "without a flow: how things stand")
    #expect(waiting.primaryButton == "Done" && waiting.isPrimaryEnabled && waiting.backButton == nil)
    let ready = OnboardingModel(tuned, shortcut: defaults)
    // The menu bar item can be hidden by a notch, and Arbor has no Dock icon.
    #expect(ready.footnote.contains("Can’t see the icon? Open Arbor again and this window returns."), "the only door then")
    #expect(ready.footnote.contains("Click it for all commands, including Quit Arbor"), "what somebody in a panic looks for")
    // Only what is true of the item as it is: with something docked it is a row of buttons, and a plain click runs one of them.
    #expect(
      OnboardingModel(tuned, menuBarIsOneIcon: false, shortcut: defaults).footnote.contains("Right-click it for all commands, including Quit Arbor"))
    #expect(ready.keysLine.isEmpty && ready.keysLegend.isEmpty)
  }

  /// Until Arbor may arrange windows there is one thing to put right, and the welcome has it: whoever asks for Check Setup… then (it is
  /// the menu's only command) is not shown offers the first minute keeps to itself, nor led into a page that goes nowhere.
  @Test func checkSetupIsForAnArborThatMayArrangeWindows() {
    var flow = OnboardingFlow(isReady: false)
    flow.go(to: .setup)
    #expect(flow.page == .permissions)
    flow.update(isReady: true, needsAttention: false)
    #expect(flow.page == .firstSteps, "and the window goes on as ever")
    flow.go(to: .setup)
    #expect(flow.page == .setup)
    flow.update(isReady: true, needsAttention: true)
    #expect(flow.page == .setup, "whoever is checking goes on checking")
    flow.update(isReady: false, needsAttention: true)
    #expect(flow.page == .permissions, "the permission went")
  }

  @Test func theWindowGoesOnToTheFirstStepsWhenThePermissionArrives() {
    var flow = OnboardingFlow(isReady: false)
    #expect(flow.page == .permissions)
    flow.update(isReady: false, needsAttention: false)
    #expect(flow.page == .permissions, "still waiting")
    flow.go(to: .firstSteps)
    #expect(flow.page == .permissions, "there is nothing to try before Arbor may move windows")

    flow.update(isReady: true, needsAttention: false)
    #expect(flow.page == .firstSteps, "not closed: a newcomer would be left looking at an unchanged screen")
    flow.update(isReady: true, needsAttention: false)
    flow.go(to: .permissions)
    flow.update(isReady: true, needsAttention: false)
    #expect(flow.page == .permissions, "Back is not undone by the next look at the facts")
    flow.go(to: .firstSteps)
    #expect(flow.page == .firstSteps)

    flow.update(isReady: false, needsAttention: false)
    #expect(flow.page == .permissions, "the permission was taken away")
  }

  @Test func itDoesNotGoOnPastWhatIsStillInTheWay() {
    var flow = OnboardingFlow(isReady: false)
    flow.update(isReady: true, needsAttention: true)
    #expect(flow.page == .permissions, "the first move would run into it")
    flow.update(isReady: true, needsAttention: false)
    #expect(flow.page == .permissions, "what was waited for was the permission; from here on the button turns the page")
    flow.go(to: .firstSteps)
    #expect(flow.page == .firstSteps, "it is advice, and can be passed by")
    flow.update(isReady: true, needsAttention: true)
    #expect(flow.page == .firstSteps, "nobody is called back from the moves")

    // The permission goes and comes back: whoever has passed the advice by is not held at it a second time.
    flow.update(isReady: false, needsAttention: true)
    #expect(flow.page == .permissions)
    flow.update(isReady: true, needsAttention: true)
    #expect(flow.page == .firstSteps)
  }

  /// The rest of the time nobody needs to know, and finding out means wording the whole window.
  @Test func whatIsInTheWayIsAskedOnlyWhenThePermissionArrives() {
    var asked = 0
    func ask() -> Bool {
      asked += 1
      return true
    }
    var flow = OnboardingFlow(isReady: false)
    flow.update(isReady: false, needsAttention: ask())
    #expect(asked == 0)
    flow.update(isReady: true, needsAttention: ask())
    #expect(asked == 1)
    flow.update(isReady: true, needsAttention: ask())
    flow.update(isReady: true, needsAttention: ask())
    #expect(asked == 1)
  }

  /// "Arbor is ready" over a warning sign says two things at once. The words hold for a newcomer and after a year.
  @Test func theTitleCountsWhatIsInTheWay() {
    var facts = tuned
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Arbor is ready")
    facts.switches = [.menuBar, .optionKey]
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Ready, with one suggestion", "a row, however many switches")
    facts.competingApps = ["Rectangle", "Magnet"]
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Ready, with two suggestions")
    facts.voiceOver = true
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Ready, with three suggestions")
    // What is only good to know does not count.
    facts = tuned
    facts.inputSources = 2
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Arbor is ready")
    #expect(OnboardingModel(facts, shortcut: defaults).pageToOpenOn == .firstSteps)
    facts.accessibility = false
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Arbor needs one permission")
    #expect(OnboardingModel(facts, shortcut: defaults).pageToOpenOn == .permissions)
  }

  /// Things are put right in System Settings, which lies over the window meanwhile, and Arbor has no Dock icon to click.
  @Test func goodNewsBringsTheWindowForward() {
    var granted = fresh
    granted.accessibility = true
    let (waiting, held, ready) = (OnboardingModel(fresh), OnboardingModel(granted), OnboardingModel(tuned))
    #expect(held.isWorthComingForward(after: waiting), "the permission arrived")
    #expect(ready.isWorthComingForward(after: held), "the last switch went off")
    #expect(ready.isWorthComingForward(after: waiting))
    #expect(!waiting.isWorthComingForward(after: waiting) && !held.isWorthComingForward(after: held))
    #expect(!ready.isWorthComingForward(after: ready))
    // One switch of several is a step on the way: whoever is at it is not interrupted.
    var fewer = granted
    fewer.switches = [.optionKey]
    #expect(!OnboardingModel(fewer).isWorthComingForward(after: held))
    // Bad news comes by other roads (F63 opens the window).
    #expect(!waiting.isWorthComingForward(after: ready) && !held.isWorthComingForward(after: ready))
  }

  @Test func openedWithThePermissionItStaysOnTheFirstPageUntilAsked() {
    var flow = OnboardingFlow(isReady: true)
    flow.update(isReady: true, needsAttention: false)
    #expect(flow.page == .permissions)
    flow.go(to: .firstSteps)
    #expect(flow.page == .firstSteps)
  }

  // MARK: The second page

  func secondPage(_ steps: FirstSteps = FirstSteps(), shortcut: (Command) -> String? = defaults) -> OnboardingModel {
    var flow = OnboardingFlow(isReady: true)
    flow.go(to: .firstSteps)
    flow.steps = steps
    return OnboardingModel(tuned, flow: flow, shortcut: shortcut)
  }

  @Test func theSecondPageAsksForFourMovesWithTheShortcutsInEffect() {
    let model = secondPage()
    #expect(model.page == .firstSteps)
    #expect(model.title == "Four moves to try")
    #expect(model.steps.map(\.id) == [.dock, .dockSecond, .frame, .showEverything])
    // All four by key (Q29, 11), and the fourth by the third's: one key to learn, not two.
    #expect(
      model.steps.map(\.lead) == [
        "Click a window and press ⌃⌥⌘←", "Click another and press ⌃⌥⌘→", "Then press ⌃⌥↩", "Press ⌃⌥↩ again",
      ])
    // What Arbor is for, which one docked window does not show. Nothing is said that the arrangement does not do.
    #expect(model.step(.dock)?.text == "It docks: it takes the left side of the screen and stays there.")
    #expect(model.step(.dockSecond)?.text == "It takes the other side.")
    #expect(
      model.step(.frame)?.text
        == "The window you are in fills the screen; the menu bar stays, and it is not macOS’s full screen. Your other windows are out of view, "
        + "not closed: ⌘Tab and the Dock still reach them.")
    #expect(model.step(.showEverything)?.text == "The arrangement is back.")
    // The window lies over the windows the moves are made on, so it is kept small: only the next move is explained.
    #expect(model.steps.map(\.isNext) == [true, false, false, false])
    #expect(OnboardingModel.width(of: .firstSteps) == 420 && OnboardingModel.width(of: .permissions) == 560 && OnboardingModel.width(of: .setup) == 560)
    #expect(model.summary == "On your own windows, one after the other. Each is ticked off here as you do it.", "one breath")
    #expect(model.steps.allSatisfy { !$0.isDone })
    #expect(model.keysLegend == "⌃ is Control, ⌥ Option, ⌘ Command, ↩ Return, ⎋ Escape.")
    // Those that are on the page, and no others.
    #expect(secondPage { $0 == .zoom(nil) ? "⌃⇧Z" : nil }.keysLegend == "⌃ is Control, ⇧ Shift.")
    #expect(model.primaryButton == "Done" && model.isPrimaryEnabled && model.backButton == "Back")
    // During the moves, nothing but the moves, the way back, and the one thing nobody can guess.
    #expect(model.footnote == "Arbor lives in the menu bar, under this icon.")
    #expect(model.opensAtLogin == nil && model.keysLine.isEmpty)
  }

  /// They follow the shortcuts in effect, so they read as the nine keys the day those are the default.
  @Test func theMovesAreWordedFromTheShortcutsInEffect() {
    let nine = secondPage { command in
      switch command {
      case .dock(nil, .left): "⌃⌥←"
      case .dock(nil, .right): "⌃⌥→"
      default: defaults(command)
      }
    }
    #expect(nine.steps.map(\.lead) == ["Click a window and press ⌃⌥←", "Click another and press ⌃⌥→", "Then press ⌃⌥↩", "Press ⌃⌥↩ again"])
    #expect(nine.keysLegend == "⌃ is Control, ⌥ Option, ↩ Return, ⎋ Escape.", "⌘ shows only with the third move, which speaks of ⌘Tab")
  }

  @Test func aMoveWithoutAShortcutIsExplainedByTheMenu() {
    let model = secondPage(shortcut: { _ in nil })
    #expect(
      model.steps.map(\.lead) == [
        "Click a window and choose Dock Focused Window → Left in Arbor’s menu",
        "Click another and choose Dock Focused Window → Right in Arbor’s menu",
        "Then choose Frame Focused Window in Arbor’s menu", "Then choose Show Everything in Arbor’s menu",
      ])
    #expect(model.wayBack == "Pause Arbor in its menu pauses it: every window is as it was. Quit does the same.", "by the item's own title")
    #expect(model.keysLegend.isEmpty, "no key is named, so none is explained")
  }

  /// A key works on every Mac as it is set: the first act of a newcomer is not the one act a fresh Mac takes away from Arbor.
  @Test func theMovesAreTheSameWhateverMacOSsSwitchesSay() {
    var flow = OnboardingFlow(isReady: true)
    flow.go(to: .firstSteps)
    var facts = tuned
    let off = OnboardingModel(facts, flow: flow, shortcut: defaults).steps
    for switches: [MacSwitch]? in [[.screenEdges, .menuBar, .optionKey], [.menuBar], nil] {
      facts.switches = switches
      #expect(OnboardingModel(facts, flow: flow, canFixSetup: true, shortcut: defaults).steps == off)
    }
  }

  /// "Three ways back" blurred: four readers of six could not tell them apart. One, which needs nothing learnt.
  @Test func itNamesOneWayBack() {
    #expect(secondPage().wayBack == "⌃⌥⎋ pauses Arbor: every window is as it was. Quit does the same.")
    // Once it has been taken, the same key is the way on.
    var flow = OnboardingFlow(isReady: true)
    flow.go(to: .firstSteps)
    let paused = OnboardingModel(tuned, flow: flow, isPaused: true, shortcut: defaults)
    #expect(paused.summary == "Arbor is paused and leaves windows and shortcuts alone. Resume it first.")
    #expect(paused.wayBack == "⌃⌥⎋ resumes Arbor.")
    #expect(OnboardingModel(tuned, flow: flow, isPaused: true).wayBack == "Resume in Arbor’s menu resumes it.")
  }

  /// What is not about the moves waits for the last tick: all of where Arbor lives, Open at Login, and the key that takes a change back.
  @Test func afterTheLastTickComesWhatHadToWait() throws {
    var workspace = Workspace()
    var steps = FirstSteps()
    workspace.dock(WindowID(1), at: .cameraEdge(.left))
    workspace.dock(WindowID(2), at: .cameraEdge(.right))
    workspace.moveCamera(to: try #require(workspace.tree.leaf(containing: WindowID(1))))
    steps.observe([DisplayID("main"): workspace])
    workspace.moveCamera(to: workspace.tree.root)
    steps.observe([DisplayID("main"): workspace])
    #expect(steps.isComplete)
    var flow = OnboardingFlow(isReady: true)
    flow.go(to: .firstSteps)
    flow.steps = steps
    var facts = tuned
    facts.opensAtLogin = false
    let done = OnboardingModel(facts, flow: flow, menuBarIsOneIcon: false, shortcut: defaults)
    #expect(done.title == "That is all there is to it")
    #expect(done.summary == "The arrangement stays until you change it. ⌃⌥Z takes back the last change.")
    #expect(done.footnote.contains("Right-click it for all commands") && done.opensAtLogin == false)
    #expect(done.steps.allSatisfy { $0.isDone && !$0.isNext })
    #expect(OnboardingModel(facts, flow: flow).summary == "The arrangement stays until you change it.")
  }

  @Test func theLoginBoxIsOfferedOnlyWhereArborCanOpenAtLogin() {
    #expect(secondPage().opensAtLogin == nil, "outside its bundle")
    var facts = tuned
    facts.opensAtLogin = false
    #expect(OnboardingModel(facts).opensAtLogin == false)
    facts.opensAtLogin = true
    #expect(OnboardingModel(facts).opensAtLogin == true)
    #expect(OnboardingModel(facts).loginTitle == "Open at Login")
  }

  /// A key that fingers know as Arbor's and that Arbor does not hear may do anything in the app in front.
  @Test func shortcutsThatArborDoesNotHoldAreInTheWay() throws {
    #expect(OnboardingModel(tuned, shortcut: defaults).row(.lostShortcuts) == nil)
    let one = OnboardingModel(tuned, lostShortcuts: ["⌃⌥A"], shortcut: defaults)
    let row = try #require(one.row(.lostShortcuts))
    #expect(row.title == "⌃⌥A is not Arbor’s")
    #expect(row.state == .recommended && row.needsAttention && !row.isSatisfied)
    #expect(row.importance == "Best changed" && row.status == "Not registered")
    #expect(row.detail.hasPrefix("Arbor does not hear it, so what you press there goes elsewhere, most likely to the app in front"))
    #expect(row.detail.hasSuffix("give the command another shortcut under Settings → Shortcuts."))
    #expect(row.button == nil, "no pane of System Settings helps")
    #expect(one.rows.last?.id == .lostShortcuts)
    #expect(one.page == .setup && one.title == "Ready, with one suggestion")
    #expect(one.isReady, "Arbor arranges windows all the same")
    // The welcome says little, but what would spoil the moves it teaches it does say, and they are keys.
    let welcome = OnboardingModel(tuned, flow: OnboardingFlow(isReady: true), lostShortcuts: ["⌃⌥A"], shortcut: defaults)
    #expect(welcome.page == .permissions && welcome.row(.lostShortcuts) == row)
    #expect(OnboardingModel(tuned, flow: OnboardingFlow(isReady: true), shortcut: defaults).row(.lostShortcuts) == nil)
    let three = OnboardingModel(tuned, lostShortcuts: ["⌃⌥A", "⌃⌥Z", "⌃⌥F"]).row(.lostShortcuts)
    #expect(three?.title == "⌃⌥A, ⌃⌥Z and ⌃⌥F are not Arbor’s")
    #expect(three?.detail.hasPrefix("Arbor does not hear them,") == true)
    #expect(three?.detail.hasSuffix("give the commands another shortcut under Settings → Shortcuts.") == true)
    // A title is one line.
    #expect(OnboardingModel(tuned, lostShortcuts: ["1", "2", "3", "4"]).row(.lostShortcuts)?.title == "4 shortcuts are not Arbor’s")
  }
}

/// The live ticks of the second page.
@Suite struct FirstStepsTests {
  let main = DisplayID("main")
  let side = DisplayID("side")
  let safari = WindowID(1)
  let notes = WindowID(2)

  func ticks(_ steps: FirstSteps) -> [Bool] { [steps.docked, steps.framed, steps.showedEverything] }

  @Test func theMovesAreTickedOffAsTheyHappen() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.floating[safari] = .zero
    steps.observe([main: workspace])
    #expect(ticks(steps) == [false, false, false], "showing everything from the start is not the third move")

    workspace.dock(safari, at: .cameraEdge(.left))
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, false])

    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, true, false])
    #expect(!steps.isComplete)

    workspace.moveCamera(to: workspace.tree.root)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, true, true])
    #expect(!steps.dockedTwo && !steps.isComplete, "two side by side are what Arbor is for, and have not been seen")

    workspace.dock(notes, at: .cameraEdge(.right))
    steps.observe([main: workspace])
    #expect(steps.dockedTwo && steps.isComplete)
  }

  /// Side by side is something to see, so it counts on one display.
  @Test func twoDockedWindowsCountOnOneDisplay() {
    var steps = FirstSteps()
    var one = Workspace()
    one.dock(safari, at: .cameraEdge(.left))
    var other = Workspace()
    other.dock(notes, at: .cameraEdge(.left))
    steps.observe([main: one, side: other])
    #expect(steps.docked && !steps.dockedTwo)
    one.dock(WindowID(3), at: .cameraEdge(.right))
    steps.observe([main: one, side: other])
    #expect(steps.dockedTwo)
    // A tick stays.
    one.undock(safari, floatingAt: .zero)
    steps.observe([main: one, side: other])
    #expect(steps.dockedTwo)
  }

  /// A dock touches only what is docked, so the other windows lie where they lay, and what shows of them shows in the free part of the
  /// display. The window keeps out of their way: in the bottom corner on that side, farthest from what has been docked.
  @Test func duringTheMovesTheWindowWaitsInTheCornerAwayFromWhatIsDocked() {
    let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
    let width = OnboardingModel.width(of: .firstSteps)
    func place(_ desktops: [CGRect], height: CGFloat = 400, in visible: CGRect = visible) -> CGPoint {
      // From the first page, in the middle of the display.
      OnboardingModel.placement(
        page: .firstSteps, previous: .permissions, staysPut: false, old: CGRect(x: 1, y: 2, width: 3, height: 4),
        size: CGSize(width: width, height: height), visible: visible, desktops: desktops
      ).frame.origin
    }
    #expect(width == 420)
    #expect(place([]).x == 1008, "a gap's width from the right while nothing is docked: the first move goes to the left")
    let atTheRight = CGRect(x: 726, y: 37, width: 702, height: 851), between = CGRect(x: 488, y: 37, width: 464, height: 851)
    #expect(place([atTheRight]).x == 1008, "the first window is docked at the left")
    let atTheLeft = CGRect(x: 12, y: 37, width: 702, height: 851)
    #expect(place([atTheLeft]).x == 12, "whoever docks at the right first")
    // By the free part of its own display, whichever comes first.
    let elsewhere = CGRect(x: 1452, y: 37, width: 200, height: 851)
    #expect(place([elsewhere]).x == 1008)
    #expect(place([elsewhere, atTheLeft]).x == 12)

    // It crosses the display only for that: a free part that reaches one side of the display and not the other. Between two docked windows,
    // however far off the middle (apps have smallest widths), with the Desktop out of view (a window fills the screen), and with no
    // Desktop at all, it stays on the side where it is.
    func journey(_ steps: [[CGRect]]) -> [CGFloat] {
      var old = CGRect(x: 440, y: 127, width: 560, height: 500)
      var previous = OnboardingFlow.Page.permissions
      return steps.map { desktops in
        old = OnboardingModel.placement(
          page: .firstSteps, previous: previous, staysPut: false, old: old, size: CGSize(width: width, height: 400), visible: visible,
          desktops: desktops
        ).frame
        previous = .firstSteps
        return old.minX
      }
    }
    let offTheMiddle = CGRect(x: 525, y: 37, width: 317, height: 851), toTheRight = CGRect(x: 600, y: 37, width: 400, height: 851)
    #expect(journey([[], [atTheRight], [between], [], [between]]) == [1008, 1008, 1008, 1008, 1008], "the four moves")
    #expect(journey([[], [atTheRight], [offTheMiddle], [], [offTheMiddle]]) == [1008, 1008, 1008, 1008, 1008])
    #expect(journey([[], [atTheLeft], [between], [], [toTheRight], []]) == [1008, 12, 12, 12, 12, 12], "the right first")
    #expect(journey([[], [atTheRight], [], [atTheLeft]]) == [1008, 1008, 1008, 12], "undocked, and docked at the other side")
    #expect(journey([[CGRect(x: 12, y: 37, width: 1416, height: 851)]]) == [1008], "nothing docked: the Desktop is the whole display")
    // The line that says what a move did is centred at the bottom. Where it could reach the window, the window gives way upward,
    let line = HeadsUpModel(kind: .hint, text: "Docked").placed(in: visible)
    #expect(line.anchor.x + line.maximumWidth / 2 > 1008)
    #expect(place([]).y + 400 <= line.anchor.y - 40, "its lower edge, and the top of a line of one row")
    // and where it cannot, the window is in the very corner.
    let wide = CGRect(x: 0, y: 25, width: 2560, height: 1415)
    #expect(place([], in: wide) == CGPoint(x: 2560 - 12 - 420, y: 1440 - 12 - 400))
    #expect(place([], height: 2000).y == visible.minY, "taller than the display: its title bar stays in reach")
    // On the smallest display: 37 points further from the docked window than the middle of the free half.
    let small = CGRect(x: 0, y: 31, width: 1024, height: 677)
    #expect(place([CGRect(x: 518, y: 43, width: 494, height: 653)], height: 364, in: small) == CGPoint(x: 592, y: 240))
    // On whole points, whatever the window's height.
    let odd = place([], height: 331.5, in: CGRect(x: 0, y: 25, width: 1024.5, height: 673))
    #expect(odd == CGPoint(x: odd.x.rounded(), y: odd.y.rounded()))
  }

  /// Where the window goes whenever it has something else to show.
  @Test func theWindowGoesWhereItIsLeastInTheWayAndStaysWhereItIsPut() {
    let visible = CGRect(x: 0, y: 25, width: 1440, height: 805)
    let first = CGSize(width: 560, height: 500), moves = CGSize(width: 420, height: 400)
    func placement(
      _ page: OnboardingFlow.Page, after previous: OnboardingFlow.Page?, staysPut: Bool = false, old: CGRect, size: CGSize
    ) -> OnboardingModel.Placement {
      OnboardingModel.placement(page: page, previous: previous, staysPut: staysPut, old: old, size: size, visible: visible, desktops: [])
    }
    // It opens where macOS centres a window, at once.
    let opened = placement(.permissions, after: nil, old: .zero, size: first)
    #expect(opened == .init(frame: CGRect(x: 440, y: 127, width: 560, height: 500), glides: false))
    // A row loses its text: the title bar stays where it is.
    let shorter = placement(.permissions, after: .permissions, old: opened.frame, size: CGSize(width: 560, height: 420))
    #expect(shorter == .init(frame: CGRect(x: 440, y: 127, width: 560, height: 420), glides: false))
    // Growing does not push the buttons under the Dock.
    let low = CGRect(x: 440, y: 500, width: 560, height: 300)
    #expect(placement(.permissions, after: .permissions, old: low, size: first).frame.maxY == visible.maxY)
    // Continue: it glides to where it rests. Opened on the moves, it is there at once.
    let resting = placement(.firstSteps, after: .permissions, old: opened.frame, size: moves)
    #expect(resting.glides && resting.frame == CGRect(x: 1008, y: 326, width: 420, height: 400))
    #expect(placement(.firstSteps, after: nil, old: .zero, size: moves) == .init(frame: resting.frame, glides: false))
    // Back: to the middle again.
    #expect(placement(.permissions, after: .firstSteps, old: resting.frame, size: first) == opened)

    // Somebody has pushed it half off the display, to see their windows. There it stays, whatever is ticked.
    let pushed = CGRect(x: 1300, y: 700, width: 420, height: 400)
    #expect(placement(.firstSteps, after: .firstSteps, staysPut: true, old: pushed, size: moves) == .init(frame: pushed, glides: false))
    let smaller = placement(.firstSteps, after: .firstSteps, staysPut: true, old: pushed, size: CGSize(width: 420, height: 380))
    #expect(smaller.frame.origin == pushed.origin)
    // Only what it grows by is kept on the display, so that Back and Done stay in reach.
    let back = placement(.permissions, after: .firstSteps, staysPut: true, old: pushed, size: first)
    #expect(back.frame.maxX == visible.maxX && back.frame.maxY == visible.maxY && !back.glides)
  }

  /// Nobody reads a list from the top (F46, acceptance 1): each move is ticked when it is made.
  @Test func theMovesAreTickedInWhateverOrderTheyAreMade() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.dock(safari, at: .cameraEdge(.left))
    steps.observe([main: workspace])
    // To the Desktop and back: that is Show Everything, before anything was framed.
    workspace.moveCamera(to: workspace.tree.desktop)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, false])
    workspace.moveCamera(to: workspace.tree.root)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, true])
    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, true, true])
  }

  @Test func ticksStay() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.dock(safari, at: .cameraEdge(.left))
    steps.observe([main: workspace])
    workspace.undock(safari, floatingAt: .zero)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, false])
  }

  @Test func otherPlacesAreNotAFramedWindow() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.dock(safari, at: .cameraEdge(.left))
    workspace.dock(notes, at: .beside(workspace.tree.leaf(containing: safari)!, .bottom))
    workspace.moveCamera(to: workspace.tree.desktop)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, false], "the Desktop")
    workspace.moveCamera(to: workspace.tree.parent(of: workspace.tree.leaf(containing: safari)!)!)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, false, false], "a group")
  }

  @Test func steppingOutHalfWayIsNotShowingEverything() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.dock(safari, at: .cameraEdge(.left))
    workspace.dock(notes, at: .beside(workspace.tree.leaf(containing: safari)!, .bottom))
    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    steps.observe([main: workspace])
    workspace.moveCamera(to: workspace.tree.parent(of: workspace.tree.leaf(containing: safari)!)!)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, true, false])
  }

  @Test func whatIsAlreadySoIsTickedAtTheFirstLook() {
    var steps = FirstSteps()
    var workspace = Workspace()
    workspace.dock(safari, at: .cameraEdge(.left))
    workspace.moveCamera(to: workspace.tree.leaf(containing: safari)!)
    steps.observe([main: workspace])
    #expect(ticks(steps) == [true, true, false])
  }

  @Test func showEverythingCountsOnTheDisplayWhereTheWindowWasFramed() {
    var steps = FirstSteps()
    var framed = Workspace()
    framed.dock(safari, at: .cameraEdge(.left))
    framed.moveCamera(to: framed.tree.leaf(containing: safari)!)
    var other = Workspace()
    other.dock(notes, at: .cameraEdge(.left))
    steps.observe([main: other, side: framed])
    steps.observe([main: other, side: framed])
    #expect(ticks(steps) == [true, true, false], "the other display has shown everything all along")
    framed.moveCamera(to: framed.tree.root)
    steps.observe([main: other, side: framed])
    #expect(steps.showedEverything)
  }

  @Test func unpluggingThatDisplayBringsItsWindowsIntoViewToo() {
    var steps = FirstSteps()
    var framed = Workspace()
    framed.dock(safari, at: .cameraEdge(.left))
    framed.moveCamera(to: framed.tree.leaf(containing: safari)!)
    steps.observe([main: Workspace(), side: framed])
    steps.observe([main: Workspace()])
    #expect(steps.showedEverything)
  }
}

@Suite struct SystemFactsTests {
  @Test func appsThatCompeteAreRecognisedByBundleIDOrName() {
    #expect(CompetingApp.name(bundleID: "com.knollsoft.Rectangle", appName: "Rectangle") == "Rectangle")
    #expect(CompetingApp.name(bundleID: "com.knollsoft.Hookshot", appName: "Rectangle Pro") == "Rectangle Pro")
    #expect(CompetingApp.name(bundleID: "com.crowdcafe.windowmagnet", appName: "Magnet") == "Magnet")
    #expect(CompetingApp.name(bundleID: "app.example.TrellisWM", appName: nil) == "TrellisWM")
    #expect(CompetingApp.name(bundleID: nil, appName: "TrellisWM") == "TrellisWM")
    #expect(CompetingApp.name(bundleID: "com.apple.Safari", appName: "Safari") == nil)
    #expect(CompetingApp.name(bundleID: "com.evbarleyg.arbor", appName: "Arbor") == nil)
    #expect(CompetingApp.name(bundleID: nil, appName: nil) == nil)
    // No app, so no bundle id: known by the file that runs.
    #expect(CompetingApp.name(bundleID: nil, appName: nil, executable: "yabai") == "yabai")
    #expect(CompetingApp.name(bundleID: nil, appName: "yabai") == "yabai")
    #expect(CompetingApp.name(bundleID: "com.apple.Safari", appName: "Safari", executable: "Safari") == nil)
  }

  @Test func moreWindowManagersAreKnown() {
    for (bundleID, name) in [
      ("com.manytricks.Moom", "Moom"), ("com.hegenberg.BetterSnapTool", "BetterSnapTool"), ("com.MrKai77.Loop", "Loop"),
      ("co.highlyopinionated.swish", "Swish"), ("com.amethyst.Amethyst", "Amethyst"), ("bobko.aerospace", "AeroSpace"),
    ] {
      #expect(CompetingApp.name(bundleID: bundleID, appName: nil) == name)
    }
  }

  @Test func theSwitchesAreReadFromTheWindowManagersDefaults() {
    #expect(
      MacSwitch.allCases.map(\.defaultsKey) == [
        "EnableStandardClickToShowDesktop", "EnableTilingByEdgeDrag", "EnableTopTilingByEdgeDrag",
        "EnableTilingOptionAccelerator", "GloballyEnabled",
      ])
  }

  @Test func aMissingKeyMeansTheSettingIsAsAppleShipsIt() {
    // A fresh Mac has none of the keys: everything but Stage Manager is on.
    #expect(MacSwitch.inTheWay(macOS: 26) { _ in nil } == [.clickWallpaper, .screenEdges, .menuBar, .optionKey])
    #expect(MacSwitch.inTheWay(macOS: 15) { _ in nil } == [.clickWallpaper, .screenEdges, .menuBar, .optionKey])
    // macOS 14 has the wallpaper click but no tiling.
    #expect(MacSwitch.inTheWay(macOS: 14) { _ in nil } == [.clickWallpaper])
    #expect(MacSwitch.inTheWay(macOS: 13) { _ in nil }.isEmpty)
  }

  @Test func eachSwitchFollowsItsOwnKey() {
    #expect(MacSwitch.inTheWay(macOS: 26) { _ in false }.isEmpty)
    #expect(MacSwitch.inTheWay(macOS: 26) { _ in true } == MacSwitch.allCases)
    for one in MacSwitch.allCases {
      #expect(MacSwitch.inTheWay(macOS: 26) { $0 == one.defaultsKey } == [one])
    }
  }
}
