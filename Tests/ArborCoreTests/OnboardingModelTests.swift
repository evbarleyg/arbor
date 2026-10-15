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
    let model = OnboardingModel(fresh, offersScreenRecording: true, shortcut: defaults)
    #expect(model.title == "Welcome to Arbor")
    #expect(model.rows.map(\.id) == [.accessibility, .screenRecording, .desktopAndDock])
    #expect(model.rows.map(\.state) == [.required, .optional, .recommended])
    #expect(model.rows.map(\.importance) == ["Required", "Optional", "Recommended"])
    #expect(model.rows.map(\.status) == ["Not granted", "Not granted", "On"])
    #expect(model.rows.allSatisfy { !$0.isSatisfied && !$0.detail.isEmpty && $0.button != nil })
    let what = "Put windows side by side (“dock” them), make any one fill the screen, then return to the side-by-side view."
    #expect(model.summary == what, "in words that need no glossary, teaching the one word the menu uses")
    // The promise somebody wants who is about to let an app move their windows, made where it holds.
    #expect(
      OnboardingModel(fresh, isNewcomer: true).summary
        == what + " Nothing moves until you dock a window.")
    // An ad-hoc build loses the permission while System Settings still shows the switch on.
    #expect(model.row(.accessibility)?.detail.contains("off and on again") == true)
    #expect(OnboardingModel(fresh, isNewcomer: true).row(.accessibility)?.detail.hasSuffix("This window comes back by itself.") == true, "it cannot be in the list yet")
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

  @Test func theDesktopAndDockRowListsWhatIsStillInTheWay() throws {
    let all = try #require(OnboardingModel(fresh).row(.desktopAndDock))
    // What each will do to them, in plain words: a list of chores says nothing to somebody who has not met the trouble yet.
    // What it is, what it does to a person, and what they get and lose either way. Then the switches by the names they have in System
    // Settings, which say in plain words what they do.
    #expect(all.title == "macOS tiling")
    #expect(
      all.detail == "Your Mac has window tiling of its own: drag a window to a screen edge, and macOS reacts before Arbor can. "
        + "Switch it off, and you dock with the mouse. Leave it on, and you dock with the keyboard.")
    #expect(
      all.points == [
        "“Drag windows to left or right edge of screen to tile”", "“Drag windows to menu bar to fill screen”",
        "“Hold ⌥ key while dragging windows to tile”",
      ])
    #expect(all.button == "Open Desktop & Dock…" && all.afterword.isEmpty)
    #expect(OnboardingModel(fresh, shortcut: defaults).row(.desktopAndDock)?.detail.hasSuffix("you dock with the keyboard (Control-Option-Command-←).") == true, "the key to the signs is on the next page")
    func detail(_ switches: [MacSwitch]) -> String? {
      var facts = fresh
      facts.switches = switches
      return OnboardingModel(facts).row(.desktopAndDock)?.detail
    }
    // The left and right edges are free: dragging there docks, so nothing is said about mouse and keyboard.
    #expect(detail([.menuBar]) == "Your Mac has window tiling of its own: drag a window to a screen edge, and macOS reacts before Arbor can.")
    #expect(detail([.optionKey]) == "Your Mac has window tiling of its own: drag a window with Option held, and macOS reacts before Arbor can.")

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
    #expect(row.detail.hasSuffix("You can put it back at any time."), "which makes it a small thing to ask: said in the text, not the small print")
    #expect(
      row.afterword == "Changes 3 settings in Desktop & Dock, nothing else: “Drag windows to left or right edge of screen to tile”, “Drag "
        + "windows to menu bar to fill screen”, “Hold ⌥ key while dragging windows to tile”. A Put Them Back button appears here afterwards.")
    #expect(row.button == "Or do it yourself in Desktop & Dock…", "whoever would rather do it by hand still can")
    #expect(row.points.isEmpty && row.state == .recommended, "the names are the small print")

    var facts = fresh
    facts.switches = [.menuBar]
    let one = try #require(OnboardingModel(facts, canFixSetup: true).row(.desktopAndDock))
    #expect(one.action?.title == "Switch Off macOS Tiling")
    #expect(
      one.afterword == "Changes 1 setting in Desktop & Dock, nothing else: “Drag windows to menu bar to fill screen”. A Put It Back button "
        + "appears here afterwards.")
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
      "Arbor switched off 2 settings of macOS for you. They stay off, even after you quit Arbor, until you put them back: here, or later "
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
    #expect(done(facts) == two, "switched on again by hand: the top edge is macOS's")
    facts = tuned
    facts.accessibility = false
    #expect(done(facts) == two, "nothing docks yet")
    let one = try #require(OnboardingModel(tuned, canFixSetup: true, switchesChangedByArbor: [.menuBar]).row(.desktopAndDock))
    #expect(one.done.hasPrefix("Arbor switched off 1 setting of macOS for you. It stays off, even after you quit Arbor, until you put it back: "))
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

  @Test func theFirstPageWaitsForThePermission() {
    let waiting = OnboardingModel(fresh, shortcut: defaults)
    #expect(waiting.page == .permissions)
    #expect(waiting.primaryButton == "Continue" && !waiting.isPrimaryEnabled)
    #expect(waiting.backButton == nil)
    #expect(waiting.footnote.isEmpty, "what to do, and that the window comes back, is said in the row")

    let ready = OnboardingModel(tuned, shortcut: defaults)
    #expect(ready.page == .permissions, "opened from the menu, it starts with how things stand")
    #expect(ready.isPrimaryEnabled)
    // The menu bar item can be hidden by a notch, and Arbor has no Dock icon.
    #expect(ready.footnote.contains("Can’t see the icon? Open Arbor again and this window returns."), "the only door then")
    // Nobody would guess the right click, so it is said from the start.
    #expect(ready.footnote.contains("Right-click it for all commands, including Quit Arbor"), "what somebody in a panic looks for")
    #expect(ready.footnoteShowsMark && !waiting.footnoteShowsMark)
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
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Welcome to Arbor")
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

  @Test func theSecondPageAsksForThreeMovesWithTheShortcutsInEffect() {
    let model = secondPage()
    #expect(model.page == .firstSteps)
    #expect(model.title == "Three moves to try")
    #expect(model.steps.map(\.id) == [.dock, .frame, .showEverything])
    #expect(model.steps.map(\.lead) == ["Drag a window to the left edge of the screen", "Then press ⌃⌥↩", "Then press ⌃⌥Space"])
    #expect(model.summary == "On your own windows, one after the other. Each is ticked off here as you do it.", "one breath")
    // What it is all for, which one docked window does not show.
    #expect(model.step(.showEverything)?.text == "Every window is back in view. Drag another to the right edge, and the two share the screen.")
    #expect(model.steps.allSatisfy { !$0.isDone })
    #expect(
      model.step(.dock)?.text
        == "A preview shows where it will land. Let go, and it docks: it takes that half of the screen and stays there.")
    #expect(model.keysLegend == "⌃ is Control, ⌥ Option, ⌘ Command, ↩ Return.")
    // Those that are on the page, and no others.
    #expect(secondPage { $0 == .floatAll ? "⌃⌥⇧F" : defaults($0) }.keysLegend == "⌃ is Control, ⌥ Option, ⇧ Shift, ⌘ Command, ↩ Return.")
    #expect(secondPage { $0 == .zoom(nil) ? "⌃⌘Z" : $0 == .showAll ? "⌃⌘X" : nil }.keysLegend == "⌃ is Control, ⌘ Command.")
    #expect(
      model.step(.frame)?.text
        == "The docked window fills the screen (it is “framed”). Your other windows are out of view, not closed: ⌘Tab and the Dock still "
        + "reach them.")
    #expect(model.primaryButton == "Done" && model.isPrimaryEnabled && model.backButton == "Back")
    #expect(model.footnote.contains("Right-click it for all commands") && model.footnoteShowsMark)
  }

  @Test func aMoveWithoutAShortcutIsExplainedByTheMenu() {
    let model = secondPage(shortcut: { _ in nil })
    #expect(
      model.steps.map(\.lead) == [
        "Drag a window to the left edge of the screen", "Then choose Frame Focused Window in Arbor’s menu",
        "Then choose Show Everything in Arbor’s menu",
      ])
    #expect(model.keysLegend == "⌘ is Command.", "⌘Tab is macOS's own, and is named whatever Arbor's keys are")
  }

  /// A hand that drags to a screen edge ends at the very edge, and there macOS, as it comes, takes the window. Whoever passed the advice by
  /// is not sent into that: the first move is one that works.
  @Test func whileMacOSTilesAtTheEdgesTheFirstMoveIsMadeWithTheKeys() throws {
    var flow = OnboardingFlow(isReady: true)
    flow.go(to: .firstSteps)
    var facts = tuned
    facts.switches = [.screenEdges, .menuBar]
    let dock = try #require(OnboardingModel(facts, flow: flow, shortcut: defaults).step(.dock))
    #expect(dock.lead == "Click a window and press ⌃⌥⌘←")
    #expect(
      dock.text == "It docks: it takes the left half of the screen and stays there. Prefer the mouse? Click Back and switch off macOS tiling; "
        + "then you just drag a window to the edge.")
    // Nor is the invitation to dock a second one.
    #expect(
      OnboardingModel(facts, flow: flow, shortcut: defaults).step(.showEverything)?.text
        == "Every window is back in view. Click another and press ⌃⌥⌘→, and the two share the screen.")
    #expect(
      OnboardingModel(facts, flow: flow).step(.dock)?.lead == "Click a window and choose Dock Focused Window → Left in Arbor’s menu")
    // The others leave the left and right edges alone.
    facts.switches = [.menuBar, .optionKey, .clickWallpaper]
    #expect(OnboardingModel(facts, flow: flow, shortcut: defaults).step(.dock)?.lead == "Drag a window to the left edge of the screen")
    facts.switches = nil
    #expect(OnboardingModel(facts, flow: flow, shortcut: defaults).step(.dock)?.lead == "Drag a window to the left edge of the screen")
  }

  @Test func itEndsOnTheThreeWaysBack() {
    #expect(
      secondPage().waysBack == [
        "Show Everything (⌃⌥Space)", "Float All Windows puts your Mac back to normal",
        "Quitting Arbor brings every window back into view",
      ])
    let withShortcut = secondPage { $0 == .floatAll ? "⌃⌥⇧F" : defaults($0) }
    #expect(withShortcut.waysBack[1] == "Float All Windows (⌃⌥⇧F) puts your Mac back to normal")
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
    #expect(steps.isComplete)
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
    #expect(steps.isComplete)
  }

  @Test func unpluggingThatDisplayBringsItsWindowsIntoViewToo() {
    var steps = FirstSteps()
    var framed = Workspace()
    framed.dock(safari, at: .cameraEdge(.left))
    framed.moveCamera(to: framed.tree.leaf(containing: safari)!)
    steps.observe([main: Workspace(), side: framed])
    steps.observe([main: Workspace()])
    #expect(steps.isComplete)
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
