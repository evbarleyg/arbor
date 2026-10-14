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
    #expect(model.rows.map(\.importance) == ["Required", "Optional", "Best changed"])
    #expect(model.rows.map(\.status) == ["Not granted", "Not granted", "In the way"])
    #expect(model.rows.allSatisfy { !$0.isSatisfied && !$0.detail.isEmpty && $0.button != nil })
    // An ad-hoc build loses the permission while System Settings still shows the switch on.
    #expect(model.row(.accessibility)?.detail.contains("off and on again") == true)
    #expect(model.row(.screenRecording)?.detail.contains("Nothing is recorded or stored") == true)
    #expect(model.row(.desktopAndDock)?.points.count == 4)
  }

  @Test func everythingInOrderIsAllDone() {
    let model = OnboardingModel(tuned, offersScreenRecording: true, shortcut: defaults)
    #expect(model.title == "Arbor is ready")
    #expect(model.rows.map(\.id) == [.accessibility, .screenRecording, .desktopAndDock])
    #expect(model.rows.allSatisfy { $0.isSatisfied })
    #expect(model.rows.map(\.status) == ["Granted", "Granted", "In order"])
    // "Best changed" beside a tick would read as if there were still something to change.
    #expect(model.rows.map(\.importance) == ["Granted", "Granted", "In order"])
    // A tick says enough, and the window stays short.
    #expect(model.rows.allSatisfy { $0.detail.isEmpty && $0.points.isEmpty })
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
    #expect(
      all.points == [
        "“Click wallpaper to reveal desktop”: choose “Only in Stage Manager”. Otherwise a click on the Desktop sends every "
          + "window away",
        "“Drag windows to left or right edge of screen to tile”: switch it off",
        "“Drag windows to menu bar to fill screen”: switch it off",
        "“Hold ⌥ key while dragging windows to tile”: switch it off",
      ])

    var facts = fresh
    facts.switches = [.optionKey]
    let one = try #require(OnboardingModel(facts).row(.desktopAndDock))
    #expect(one.state == .recommended)
    #expect(one.points == ["“Hold ⌥ key while dragging windows to tile”: switch it off"])

    facts.switches = [.stageManager]
    #expect(OnboardingModel(facts).row(.desktopAndDock)?.points.first?.contains("use one or the other") == true)
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
    #expect(waiting.footnote == "Arbor notices by itself when the permission arrives.", "true whatever the window does then")

    let ready = OnboardingModel(tuned, shortcut: defaults)
    #expect(ready.page == .permissions, "opened from the menu, it starts with how things stand")
    #expect(ready.isPrimaryEnabled)
    // The menu bar item can be hidden by a notch, and Arbor has no Dock icon.
    #expect(ready.footnote.contains("If a full menu bar or the notch hides it, open Arbor again"), "the only door then")
    #expect(ready.footnote.contains("Help → Welcome…"), "where the menu has it")
    // Nobody would guess the right click, so it is said from the start.
    #expect(ready.footnote.contains("Right-click it for every command"))
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
    #expect(OnboardingModel(facts, shortcut: defaults).title == "One thing is in the way", "a row, however many switches")
    facts.competingApps = ["Rectangle", "Magnet"]
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Two things are in the way")
    facts.voiceOver = true
    #expect(OnboardingModel(facts, shortcut: defaults).title == "Three things are in the way")
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
    #expect(model.steps.map(\.lead) == ["Drag a window to a screen edge", "Press ⌃⌥↩", "Press ⌃⌥Space"])
    #expect(model.steps.allSatisfy { !$0.isDone })
    #expect(model.step(.dock)?.text.contains("Holding ⌃⌥⌘ and pressing an arrow key") == true)
    #expect(model.step(.frame)?.text.contains("out of view, not closed") == true)
    #expect(model.primaryButton == "Done" && model.isPrimaryEnabled && model.backButton == "Back")
    #expect(model.footnote.contains("Right-click it for every command") && model.footnoteShowsMark)
  }

  @Test func aMoveWithoutAShortcutIsExplainedByTheMenu() {
    let model = secondPage(shortcut: { _ in nil })
    #expect(
      model.steps.map(\.lead) == [
        "Drag a window to a screen edge", "Choose Frame Focused Window in Arbor’s menu",
        "Choose Show Everything in Arbor’s menu",
      ])
    #expect(model.step(.dock)?.text == "It docks there, beside everything in view.")

    // One of the four arrows was rebound, so "an arrow key" would no longer be true.
    let rebound = secondPage { $0 == .dock(nil, .left) ? "⌃⌥⌘H" : defaults($0) }
    #expect(rebound.step(.dock)?.text == "It docks there, beside everything in view.")
    let mixed = secondPage { $0 == .dock(nil, .top) ? "⌃⌘↑" : defaults($0) }
    #expect(mixed.step(.dock)?.text == "It docks there, beside everything in view.")
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
