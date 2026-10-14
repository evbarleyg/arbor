import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

private let terminal = "com.apple.Terminal"
private let zoom = "us.zoom.xos"
private let cameraCommands = [
  "show-all", "home", "out", "in", "neighbor right", "neighbor left", "back", "forward", "zoom", "desktop", "view 1",
  "frame-rect 0 0 1440 900", "arrange", "arrange all",
]

/// Holding the view (docs/features/F58-hold-the-view.md), as the person sharing their screen meets it: nothing may
/// jump, appear or change size unless they asked for it.
@Suite @MainActor struct HoldTests {
  /// [keynote | Desktop | mail / slack] with notes floating on the Desktop, framed on keynote, which has the
  /// keyboard: mail, slack and notes are out of view.
  struct Stage {
    let h: Harness
    let keynote, mail, slack, notes: WindowID
  }

  func stage(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], configure: (inout Settings) -> Void = { _ in }
  ) -> Stage {
    var settings = Settings()
    // Both ship off (`outOfTheBoxNothingStartsAHoldByItself`). The tests about calls are about someone who has switched them on.
    settings.holdStillWhileCameraIsOn = true
    settings.holdStillFor = ["us.zoom.xos Zoom Meeting"]
    configure(&settings)
    let h = Harness(displays: displays, settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    let slack = h.system.open(app: "Slack")
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(slack.rawValue) beside \(mail.rawValue) bottom")
    h.run("zoom \(keynote.rawValue)")
    h.system.userFocus(keynote)
    return Stage(h: h, keynote: keynote, mail: mail, slack: slack, notes: notes)
  }

  /// Everything an audience could notice.
  struct Picture: Equatable {
    var frames: [WindowID: CGRect] = [:]
    var workspaces: [DisplayID: Workspace]
    var scenes: [DisplayID: OverlayScene]
    var preview: CGRect?
  }

  func picture(_ h: Harness) -> Picture {
    var picture = Picture(workspaces: h.controller.workspaces, scenes: h.overlays.scenes, preview: h.overlays.preview)
    for id in h.system.windows.keys { picture.frames[id] = h.frame(id) }
    return picture
  }

  // MARK: 1. A window out of view that takes the keyboard

  @Test func aWindowOutOfViewThatTakesTheKeyboardStaysThereAndTheKeyboardGoesBack() {
    let s = stage()
    #expect(s.h.run("hold").ok)
    let before = picture(s.h)
    s.h.system.clearFrameLog()

    // However it came about: hold does not try to tell ⌘Tab from an app that pushes itself forward.
    s.h.system.userFocus(s.slack)
    #expect(s.h.system.focused == s.keynote)
    s.h.system.comesForward(s.mail)
    #expect(s.h.system.focused == s.keynote)
    s.h.system.comesForward(s.notes)
    #expect(s.h.system.focused == s.keynote, "a floating window out of view is turned away as well")

    s.h.scheduler.advance(by: 2)
    #expect(picture(s.h) == before)
    #expect(s.h.system.frameLog.isEmpty, "no window was moved, not even to where it already was")
  }

  @Test func theKeyboardGoesBackToTheWindowThatHadItNotJustAnyWindowInView() {
    let s = stage()
    s.h.run("zoom \(s.mail.rawValue)")
    s.h.run("out")  // mail above slack
    s.h.system.userFocus(s.slack)
    s.h.run("hold")
    s.h.system.comesForward(s.keynote)
    #expect(s.h.system.focused == s.slack, "not mail, which is the top-left one")
    s.h.system.userFocus(s.mail)
    s.h.system.comesForward(s.keynote)
    #expect(s.h.system.focused == s.mail, "clicking another window in view makes that one the one to return to")
  }

  @Test func theKeyboardGoesBackToAWindowArborDoesNotArrange() {
    let s = stage { $0.excludedBundleIDs = ["com.example.chat"] }
    let chat = s.h.system.open(app: "Chat")
    s.h.run("hold")
    s.h.system.userFocus(chat)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == chat, "typing in the call's own chat is not interrupted either")
  }

  @Test func withNobodyToGiveTheKeyboardBackToItGoesToTheTopLeftWindowInView() {
    let s = stage()
    s.h.system.focused = nil
    s.h.run("hold")
    s.h.system.cursor = CGPoint(x: 5, y: 5)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote)
  }

  @Test func anAppThatInsistsIsLeftWithTheKeyboardButStaysOutOfView() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    for _ in 1...3 {
      s.h.system.comesForward(s.slack)
      #expect(s.h.system.focused == s.keynote)
      s.h.scheduler.advance(by: 0.5)
    }
    #expect(picture(s.h) == before)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.slack, "Arbor does not fight an app for the keyboard for ever")
    #expect(picture(s.h).frames == before.frames)
    #expect(picture(s.h).workspaces == before.workspaces)

    s.h.scheduler.advance(by: 6)
    s.h.system.userFocus(s.keynote)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote, "later it is a new attempt")
  }

  /// As on a real Mac (collab/evidence/ax-events.txt): the window, its app and the window again report within
  /// milliseconds, and the keyboard changes hands a moment after Arbor asks.
  @Test func oneArrivalReportedThreeTimesIsOneArrival() {
    let s = stage()
    s.h.run("hold")
    s.h.system.defersFocus = true
    for attempt in 1...3 {
      let asked = s.h.system.focusRequests.count
      for _ in 1...3 { s.h.system.comesForward(s.slack) }
      #expect(s.h.system.focusRequests.count == asked + 1, "asked once, attempt \(attempt)")
      s.h.system.settleFocus()
      #expect(s.h.system.focused == s.keynote, "attempt \(attempt)")
      s.h.scheduler.advance(by: 1)
    }
  }

  @Test func theLineAroundTheFocusedWindowDoesNotBlinkWhenAWindowIsTurnedAway() {
    let s = stage()
    s.h.run("hold")
    #expect(s.h.overlays.scenes[s.h.display]?.focusRing?.window == s.keynote)
    let before = picture(s.h)
    s.h.system.defersFocus = true
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.slack, "macOS has not given the keyboard back yet")
    #expect(picture(s.h) == before)
    s.h.system.settleFocus()
    s.h.scheduler.advance(by: 1)
    #expect(picture(s.h) == before)
  }

  @Test func aTabBehindAnotherStaysBehind() {
    let s = stage { $0.tabsEnabled = true }
    let h = s.h
    h.run("show-all")
    let leaf = h.workspace.tree.leaf(containing: s.keynote)!
    h.system.drag(s.notes, through: [CGPoint(x: 700, y: 300), h.layout!.nodeFrames[leaf]!.center])
    #expect(h.workspace.tree.leaf(containing: s.notes) == leaf, "notes is a tab of keynote's group")
    h.system.userFocus(s.keynote)
    h.run("zoom \(s.keynote.rawValue)")
    h.run("hold")
    let before = picture(h)
    h.system.comesForward(s.notes)
    #expect(h.system.focused == s.keynote)
    #expect(picture(h) == before)
  }

  // MARK: 2. Nothing moves the view

  @Test(arguments: cameraCommands) func everyCameraCommandFailsAndChangesNothing(text: String) {
    let s = stage()
    s.h.run("save-view 1")
    s.h.run("show-all")
    s.h.run("zoom \(s.keynote.rawValue)")
    s.h.run("hold")
    let before = picture(s.h)
    s.h.system.clearFrameLog()

    let result = s.h.run(text)
    #expect(!result.ok)
    #expect(result.message.contains("the view is held"), "\(result.message)")
    #expect(result.message.contains("release"), "the way out is named")
    #expect(picture(s.h) == before)
    #expect(s.h.system.frameLog.isEmpty)
  }

  @Test(arguments: cameraCommands) func releaseRestoresEveryCameraCommand(text: String) {
    // From a group, so that each of them has somewhere to go.
    let s = stage()
    s.h.run("save-view 1")
    s.h.run("zoom \(s.mail.rawValue)")
    s.h.run("back")
    s.h.run("out")
    s.h.run("hold")
    #expect(!s.h.run(text).ok)
    #expect(s.h.run("release").ok)
    let result = s.h.run(text)
    #expect(result.ok || !result.message.contains("held"), "\(result.message)")
  }

  /// F51: ⌃⌥Space held down shows everything for as long as it is held, with an outline to come back to.
  @Test func holdingShowEverythingDownDoesNotPeekPastAHeldView() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    let reply = s.h.keyDown("ctrl+opt+space")
    #expect(reply?.ok == false, "the key is not swallowed")
    #expect(reply?.message.contains("the view is held") == true)
    #expect(!s.h.controller.isPeeking)
    s.h.scheduler.advance(by: 2)
    #expect(picture(s.h) == before, "no outline either")
    s.h.keyUp("ctrl+opt+space")
    s.h.scheduler.advance(by: 2)
    #expect(picture(s.h) == before)

    s.h.run("hold still")
    #expect(s.h.keyDown("ctrl+opt+space") == nil, "holding still, a peek is something the person asked for")
    #expect(s.h.workspace.camera == s.h.workspace.tree.root)
    s.h.keyUp("ctrl+opt+space")
  }

  @Test func zoomingOnANodeOrAnotherWindowFails() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    #expect(!s.h.run("zoom \(s.mail.rawValue)").ok)
    #expect(!s.h.run("zoom-node \(s.h.workspace.tree.root.rawValue)").ok)
    #expect(picture(s.h) == before)
  }

  @Test func aClickOnATileDoesNothing() throws {
    let s = stage { $0.minimumUsableWidth = 500 }
    let h = s.h
    h.run("show-all")
    let tile = try #require(h.layout?.tiles.first, "at 500 points something is too narrow to show")
    h.run("hold")
    let before = picture(h)
    let said = h.overlays.messages.count
    h.overlays.clickTile(tile.node)
    #expect(picture(h) == before)
    // The tile took the click, so it is told why nothing came of it, in the words a key is.
    #expect(h.overlays.messages.count == said + 1)
    #expect(h.overlays.messages.last?.model.kind == .problem)
    #expect(h.overlays.messages.last?.model.line.lowercased().contains("the view is held") == true)
    h.run("release")
    h.overlays.clickTile(tile.node)
    #expect(h.workspace.camera == tile.node)
  }

  @Test func pinchAndRectangleAreSwitchedOffSoNoBandIsDrawnOnASharedScreen() {
    let s = stage()
    #expect(s.h.controller.inputSettings.gesturesEnabled)
    s.h.run("hold")
    #expect(!s.h.controller.inputSettings.gesturesEnabled)
    #expect(s.h.controller.inputSettings.frameRectangleModifier == "none")
    #expect(s.h.controller.settings.gesturesEnabled, "the user's own settings are untouched")
    s.h.run("release")
    #expect(s.h.controller.inputSettings == s.h.controller.settings)
  }

  @Test func aPinchThatIsUnderWayWhenTheHoldBeginsMovesNothingMore() {
    let s = stage()
    let middle = CGPoint(x: 700, y: 400)
    s.h.controller.gesture(GestureUpdate(phase: .began, location: middle))
    s.h.run("hold")
    let before = picture(s.h)
    s.h.controller.gesture(GestureUpdate(phase: .changed, location: middle, magnification: -3))
    s.h.controller.gesture(GestureUpdate(phase: .ended, location: middle))
    #expect(picture(s.h) == before)
    #expect(!s.h.controller.inputSettings.frameRectangleOnDesktop, "⇧-drag on the Desktop draws a band as well")
  }

  @Test func shortcutsStayRegisteredSoThatASlipDoesNotTypeIntoTheSharedWindow() {
    // Unlike a pause, which hands ⌃⌥ back to the apps.
    let bindings = KeyBindings.effective(settings: Settings()).bindings
    #expect(KeyBindings.whilePaused(bindings).count < bindings.count)
    #expect(!bindings.contains { [.hold(minutes: nil), .release, .toggleHold].contains($0.command) }, "no default shortcut")
  }

  @Test func settingsWaitUntilRelease() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    // Would bring Slack's window back into the middle of the view.
    #expect(!s.h.run("exclude com.example.slack").ok)
    #expect(!s.h.run("reload-settings").ok)
    #expect(picture(s.h) == before)
  }

  /// These are answered whether or not Arbor is running, so before most refusals are thought of (F12, F13).
  @Test func commandsThatNeedNoRunningArborAreRefusedAsWell() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    let settings = s.h.controller.settings
    for text in [
      "set gap 40", "reset gap", "reset all", "bind ctrl+opt+j show-all", "unbind ctrl+opt+space",
      "rule add com.example.notes dock left", "check-for-updates",
    ] {
      let result = s.h.run(text)
      #expect(!result.ok, "\(text)")
      #expect(result.message.hasPrefix("the view is held"), "\(text): \(result.message)")
    }
    #expect(s.h.controller.settings == settings)
    #expect(picture(s.h) == before)
    for text in ["get gap", "settings", "version", "launch-at-login", "bindings", "rules"] { #expect(s.h.run(text).ok, "\(text)") }
    s.h.run("release")
    #expect(s.h.run("set gap 40").ok)
  }

  /// How a hold that misbehaves on somebody's Mac is found out. Nothing of a recording shows.
  @Test func aTraceCanBeStartedAndEndedOnAHeldView() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    #expect(s.h.run("trace on held").ok)
    s.h.system.comesForward(s.slack)
    #expect(s.h.run("trace off").ok)
    #expect(picture(s.h) == before)
    #expect(s.h.controller.holdLevel == .view)
  }

  /// F12 reads settings.json as soon as it is saved. A new gap resizes everything that is being shown.
  @Test func aSettingsFileSavedWhileTheViewIsHeldIsReadOnRelease() {
    let s = stage()
    var onDisk = s.h.controller.settings
    s.h.controller.loadSettings = { onDisk }
    s.h.run("hold")
    let before = picture(s.h)
    onDisk.gap = 40
    s.h.controller.settingsFileMayHaveChanged()
    s.h.scheduler.advance(by: 1)
    #expect(s.h.controller.settings.gap != 40)
    #expect(picture(s.h) == before)
    s.h.run("release")
    s.h.scheduler.advance(by: 1)
    #expect(s.h.controller.settings.gap == 40)
    #expect(s.h.frame(s.keynote) == s.h.visibleFrame.insetBy(dx: 40, dy: 40))
  }

  @Test func theSameWhenAPauseEndsTheHoldAndHoldingStillItIsReadAtOnce() {
    let s = stage()
    var onDisk = s.h.controller.settings
    s.h.controller.loadSettings = { onDisk }
    s.h.run("hold")
    onDisk.gap = 40
    s.h.controller.settingsFileMayHaveChanged()
    s.h.scheduler.advance(by: 1)
    s.h.run("pause")
    s.h.scheduler.advance(by: 1)
    #expect(s.h.controller.settings.gap == 40)
    s.h.run("resume")

    s.h.run("hold still")
    onDisk.gap = 20
    s.h.controller.settingsFileMayHaveChanged()
    s.h.scheduler.advance(by: 1)
    #expect(s.h.controller.settings.gap == 20, "saving a file is the user's own doing")
  }

  @Test func whereTheViewIsCanBeSavedWhileHeld() {
    let s = stage()
    s.h.run("hold")
    #expect(s.h.run("save-view 3").ok)
    #expect(s.h.workspace.savedView(slot: 3) == s.h.workspace.camera)
  }

  /// F45 asks a window that once refused its slot again, out of view, during some later layout.
  @Test func aTileDoesNotTurnIntoItsWindowByItself() {
    // With F61 its neighbours would make room, and it would be no tile to begin with.
    let s = stage { $0.makeRoom = false }
    let h = s.h
    h.run("show-all")
    let chat = h.system.open(app: "Messages", minimumSize: CGSize(width: 900, height: 200))
    h.run("dock \(chat.rawValue) beside \(s.keynote.rawValue) bottom")
    #expect(h.layout!.tiles.contains { $0.windows.contains(chat) }, "too wide for its slot")
    h.system.setMinimumSize(chat, .zero)  // the sheet that kept it wide has closed
    h.run("hold")
    h.scheduler.advance(by: 11 * 60)
    h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 4)
    #expect(h.layout!.tiles.contains { $0.windows.contains(chat) }, "an icon stays an icon in front of an audience")
    h.run("release")
    h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: -4)
    #expect(h.layout!.windowFrames[chat] != nil)
  }

  // MARK: 3. Rules wait

  @Test func aDockRulesWindowFloatsWhileHeldAndDocksOnRelease() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    let h = s.h
    h.run("hold")
    let framed = h.frame(s.keynote)
    let place = CGRect(x: 200, y: 150, width: 500, height: 300)
    let t = h.system.open(app: "Terminal", bundleID: terminal, frame: place)
    #expect(h.workspace.isFloating(t))
    #expect(h.frame(t) == place, "it floats where its app put it, as any new window does")
    #expect(h.frame(s.keynote) == framed, "and the window being shown keeps its size")

    #expect(h.run("release").ok)
    #expect(h.workspace.isDocked(t))
    #expect(h.frame(s.keynote)!.maxX <= h.frame(t)!.minX, "at the right edge of the view")
    #expect(Set(h.layout!.windowFrames.keys) == [s.keynote, t], "and releasing shows nothing else (F62)")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func rulesThatWaitedApplyInTheOrderTheWindowsOpenedAndOnlyToThoseStillFloating() {
    let s = stage {
      $0.rules = [
        AppRule(app: terminal, action: .dock(.right)),
        AppRule(app: "com.apple.mail", action: .dockBeside(bundleID: terminal, .bottom)),
        AppRule(app: "com.apple.Console", action: .dock(.left)),
      ]
    }
    let h = s.h
    h.run("hold")
    let first = h.system.open(app: "Terminal", bundleID: terminal)
    let compose = h.system.open(app: "Mail", bundleID: "com.apple.mail")
    let closed = h.system.open(app: "Terminal", bundleID: terminal)
    let byHand = h.system.open(app: "Console", bundleID: "com.apple.Console")
    h.system.close(closed)
    #expect(h.run("dock \(byHand.rawValue) top").ok, "a window in view can be docked by hand while held")
    let placeByHand = h.workspace.tree.leaf(containing: byHand)

    h.run("release")
    #expect(h.workspace.isDocked(first))
    #expect(h.workspace.tree.leaf(containing: byHand) == placeByHand, "docked by hand: the rule has nothing left to do")
    #expect(
      h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: compose)!)
        == h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: first)!),
      "the terminal was docked first, so the mail rule found it")
    #expect(h.controller.windows[closed] == nil)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// `"newWindows": "dock"` is short for one more rule at the end of the list (F23), so it waits like any rule that docks.
  /// On release it docks: F23 takes no place that would change what the view shows, and lets the window float otherwise (its owner's word).
  @Test func dockNewWindowsWaitsLikeAnyRuleThatDocks() {
    let s = stage { $0.newWindows = "dock" }
    let h = s.h
    let opening = CGRect(x: 300, y: 200, width: 640, height: 420)
    h.run("show-all")
    h.system.userFocus(s.keynote)
    h.run("hold")
    let arrangement = h.workspace.tree
    let t = h.system.open(app: "Terminal", bundleID: terminal, frame: opening)
    #expect(h.workspace.isFloating(t), "it floats where its app put it")
    #expect(h.workspace.tree == arrangement)
    let inView = Set(h.layout!.windowFrames.keys)
    #expect(h.run("release").message == "released")
    #expect(h.workspace.isDocked(t))
    #expect(Set(h.layout!.windowFrames.keys) == inView.union([t]), "what was in view, and the new window")
    // The control: the same steps with no hold on, and the window docks.
    let free = stage { $0.newWindows = "dock" }
    free.h.run("show-all")
    free.h.system.userFocus(free.keynote)
    let docked = free.h.system.open(app: "Terminal", bundleID: terminal, frame: opening)
    #expect(free.h.workspace.isDocked(docked))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Browsers and editors give a window its real title a moment after it opens (F11's `ruleTitleWait`).
  @Test func aRuleThatMatchesOnlyOnceTheTitleHasArrivedWaitsAsWell() {
    let s = stage {
      $0.rules = [AppRule(app: terminal, title: "logs", action: .dock(.top)), AppRule(app: terminal, action: .dock(.bottom))]
    }
    let h = s.h
    h.run("hold")
    let framed = h.frame(s.keynote)
    let t = h.system.open(app: "Terminal", bundleID: terminal, title: "")
    h.system.setTitle(t, "logs")
    #expect(h.workspace.isFloating(t))
    #expect(h.frame(s.keynote) == framed)
    h.run("release")
    #expect(h.workspace.isDocked(t))
    #expect(h.frame(t)!.maxY <= h.frame(s.keynote)!.minY, "by the better rule, and only by that one")
  }

  @Test func holdingStillAWindowTheUserOpenedIsDockedWhenItsTitleArrives() {
    let s = stage { $0.rules = [AppRule(app: terminal, title: "logs", action: .dock(.top))] }
    s.h.run("hold still")
    s.h.system.secondsSinceInput = 0.2  // ⌘N
    let t = s.h.system.open(app: "Terminal", bundleID: terminal, title: "")
    s.h.system.secondsSinceInput = 1.2
    s.h.system.setTitle(t, "logs")
    #expect(s.h.workspace.isDocked(t), "it is still the window they opened")
  }

  @Test func rulesThatDoNotDockApplyAtOnce() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .ignore)] }
    s.h.run("hold")
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.controller.workspaceID(containing: t) == nil, "ignored, as without a hold")
  }

  // MARK: The end of a hold moves the view no more than the hold did

  /// The guide's own recipe: a terminal goes under the mail. Mail is out of view.
  func stageWithARuleThatDocksOutOfView() -> Stage {
    stage { $0.rules = [AppRule(app: terminal, action: .dockBeside(bundleID: "com.example.mail", .bottom))] }
  }

  @Test func aRuleThatWouldMoveTheViewIsNotAppliedOnReleaseAndTheReplySaysSo() {
    let s = stageWithARuleThatDocksOutOfView()
    let h = s.h
    h.run("hold")
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    h.system.userFocus(s.keynote)
    let before = picture(h)
    let result = h.run("release")
    #expect(result.message == "released; Terminal was left floating")
    #expect(picture(h) == before, "nothing an audience could notice")
    #expect(h.workspace.isFloating(t))
    for window in [s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window)") }
    // It is not kept for later either.
    h.run("hold")
    #expect(h.run("release").message == "released")
    #expect(h.workspace.isFloating(t))
  }

  @Test func theSameWhenTheTimeIsUpWithNobodyTouchingAnything() {
    let s = stageWithARuleThatDocksOutOfView()
    s.h.run("hold 5")
    s.h.system.open(app: "Terminal", bundleID: terminal)
    s.h.system.userFocus(s.keynote)
    let before = picture(s.h)
    s.h.scheduler.advance(by: 301)
    #expect(s.h.controller.holdLevel == nil)
    #expect(picture(s.h) == before)
  }

  @Test func theSameWhenTheCallIsOver() {
    let s = stageWithARuleThatDocksOutOfView()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.controller.holdLevel == .still)
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isFloating(t))
    let before = picture(s.h)
    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 6)
    #expect(s.h.controller.holdLevel == nil)
    #expect(picture(s.h) == before)
  }

  /// Found by `HoldFuzzTests`. With every window away, what the view shows is nothing, before and after.
  @Test func theSameWhenTheTimeIsUpWhileAnotherMacOSSpaceShows() {
    let s = stageWithARuleThatDocksOutOfView()
    let h = s.h
    h.run("hold 5")
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    h.system.userFocus(s.keynote)
    h.scheduler.advance(by: 1)
    let before = picture(h)
    let all = [s.keynote, s.mail, s.slack, s.notes, t]
    for window in all { h.system.setOnActiveSpace(window, false) }
    h.scheduler.advance(by: 301)
    #expect(h.controller.holdLevel == nil)
    for window in all { h.system.setOnActiveSpace(window, true) }
    h.scheduler.runPending()
    #expect(h.workspace.isFloating(t))
    #expect(picture(h) == before)
  }

  /// Holding still, the framed window was minimized, so what is around it shows. Docked beside it, the terminal
  /// would be all there is to see: the view would be where it was and show something else.
  @Test func aRuleThatWouldNarrowWhatShowsIsNotAppliedEither() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    let h = s.h
    h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    h.system.setMinimized(s.keynote, true)
    h.scheduler.runPending()
    #expect(h.system.isVisible(s.mail))
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    h.scheduler.advance(by: 1)
    let before = picture(h)
    h.controller.callSignalsChanged(CallSignals())
    h.scheduler.advance(by: 6)
    #expect(h.controller.holdLevel == nil)
    #expect(h.workspace.isFloating(t))
    #expect(picture(h) == before)
  }

  @Test func aWindowTheUserHasMovedMeanwhileStaysWhereTheyPutIt() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    let h = s.h
    h.run("hold")
    let t = h.system.open(app: "Terminal", bundleID: terminal, frame: CGRect(x: 200, y: 150, width: 500, height: 300))
    let chosen = CGRect(x: 640, y: 420, width: 500, height: 300)
    h.system.userMove(t, to: chosen)
    let framed = h.frame(s.keynote)
    #expect(h.run("release").message == "released; Terminal was left floating")
    #expect(h.workspace.isFloating(t))
    #expect(h.frame(t) == chosen)
    #expect(h.frame(s.keynote) == framed)
  }

  @Test func theReplyCountsAndNamesWhatWasLeftFloating() {
    let s = stage {
      $0.rules = [
        AppRule(app: terminal, action: .dockBeside(bundleID: "com.example.mail", .bottom)),
        AppRule(app: "com.apple.Console", action: .dockBeside(bundleID: "com.example.slack", .top)),
        AppRule(app: "com.apple.Safari", action: .dockBeside(bundleID: "com.example.slack", .top)),
      ]
    }
    s.h.run("hold")
    s.h.system.open(app: "Terminal", bundleID: terminal)
    s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.run("release").message == "released; 2 Terminal windows were left floating")
    s.h.run("hold")
    s.h.system.open(app: "Terminal", bundleID: terminal)
    s.h.system.open(app: "Console", bundleID: "com.apple.Console")
    s.h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    #expect(s.h.run("release").message == "released; Terminal, Console and Safari were left floating")
  }

  // MARK: 4. A held view never widens by itself

  /// ⌘W, pressed without a thought. The wallpaper gives nothing away.
  @Test func whenTheOnlyWindowInViewClosesTheViewStaysHeldAndEmpty() {
    let s = stage()
    let h = s.h
    h.run("hold")
    let others = [s.mail, s.slack, s.notes].map { h.frame($0) }
    h.system.clearFrameLog()
    h.system.close(s.keynote)
    h.scheduler.runPending()
    #expect(h.controller.holdLevel == .view)
    #expect(h.system.frameLog.isEmpty, "no window is moved")
    #expect([s.mail, s.slack, s.notes].map { h.frame($0) } == others)
    #expect(h.controller.displaysHeldEmpty == [h.display])
    #expect(h.layout?.windowFrames.isEmpty == true)
    // How long tiles would fade (F36) is in every scene.
    var nothing = OverlayScene()
    nothing.tileFade = h.controller.settings.appearanceOptions.tileFade
    #expect(h.overlays.scenes[h.display] == nothing, "and Arbor draws nothing")
    #expect(h.controller.holdMenu.first?.title == "The view is held: nothing is in it")
    for text in cameraCommands { #expect(!h.run(text).ok, "\(text)") }
    h.system.comesForward(s.mail)
    #expect(!h.system.isVisible(s.mail))

    #expect(h.run("release").ok)
    #expect(h.controller.displaysHeldEmpty.isEmpty)
    #expect(h.system.isVisible(s.mail), "asked for, the view goes to what is around it")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// ⌘M, and a click in the Dock to get it back.
  @Test func aMinimizedWindowIsAwayAndComesBackToTheSameView() {
    let s = stage()
    let h = s.h
    h.run("hold")
    h.scheduler.advance(by: 1)  // or the line around the window flashes, as it does right after a command
    let before = picture(h)
    h.system.setMinimized(s.keynote, true)
    h.scheduler.runPending()
    #expect(h.controller.holdLevel == .view)
    for window in [s.mail, s.slack, s.notes] { #expect(h.frame(window) == before.frames[window], "\(window)") }
    #expect(h.controller.holdMenu.first?.title == "The view is held: nothing is in it")
    h.system.setMinimized(s.keynote, false)
    h.system.userFocus(s.keynote)
    h.scheduler.runPending()
    #expect(picture(h) == before)
    #expect(h.controller.displaysHeldEmpty.isEmpty)
    #expect(h.controller.holdMenu.first?.title == "The view is held: nothing moves it")
  }

  /// #152's question, "was a layout forgotten?", has an answer on a held display too: it should look empty, and does.
  @Test func anEmptyHeldViewIsLaidOutAsItShouldBeAtEveryStep() {
    let s = stage()
    let h = s.h
    h.run("hold")
    #expect(h.staleLayouts() == [])
    h.system.setMinimized(s.keynote, true)
    #expect(h.staleLayouts() == [])
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames.isEmpty == true)
    h.run("show-all")
    #expect(h.staleLayouts() == [], "refused, and nothing is out of date")
    // What is out of view changes behind it, and the Dock changes size.
    h.system.close(s.slack)
    #expect(h.staleLayouts() == [])
    h.system.setMinimized(s.keynote, false)
    #expect(h.staleLayouts() == [])
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames.keys.sorted() == [s.keynote])
    h.system.close(s.keynote)
    #expect(h.staleLayouts() == [])
    h.run("release")
    #expect(h.staleLayouts() == [])
    #expect(h.controller.freshLayout(of: h.display)?.windowFrames[s.mail] != nil)
  }

  /// Found by the chaos lab's walks. The framed window was minimized before the hold began, so what is around it shows, and that is
  /// the view the person asks Arbor to hold. The fence was around the window that is away: the next layout changed the picture.
  @Test func whatIsSeenIsWhatIsHeldThoughTheViewIsOnAWindowThatIsAway() {
    let s = stage()
    let h = s.h
    h.system.setMinimized(s.keynote, true)
    h.scheduler.runPending()
    #expect(h.system.isVisible(s.mail) && h.system.isVisible(s.slack))
    #expect(h.run("hold").ok, "there is something in view to hold")
    h.scheduler.advance(by: 1)
    let before = picture(h)
    #expect(h.staleLayouts() == [])
    #expect(h.controller.displaysHeldEmpty.isEmpty)
    h.run("relayout")
    h.system.comesForward(s.slack)
    h.scheduler.advance(by: 5)
    #expect(picture(h).frames == before.frames, "whatever lays the display out again")
    #expect(h.staleLayouts() == [])
    #expect(!h.run("show-all").ok)
  }

  /// ⌘H.
  @Test func aHiddenAppIsAwayAsWell() {
    let h = Harness()
    let keynote = h.system.open(app: "Keynote", pid: 2001)
    let mail = h.system.open(app: "Mail", pid: 2002)
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(keynote.rawValue)")
    h.run("hold")
    let (framed, corner) = (h.frame(keynote), h.frame(mail))
    h.system.setHidden(pid: 2001, true)
    h.scheduler.runPending()
    #expect(h.controller.holdLevel == .view)
    #expect(h.frame(mail) == corner)
    h.system.setHidden(pid: 2001, false)
    h.scheduler.runPending()
    #expect(h.frame(keynote) == framed)
    #expect(h.frame(mail) == corner)
  }

  @Test func aNewWindowFloatsOverAnEmptyViewAndDockingItBringsNothingElseIn() {
    let s = stage()
    let h = s.h
    h.run("hold")
    h.system.close(s.keynote)
    let t = h.system.open(app: "Terminal")
    #expect(h.workspace.isFloating(t))
    #expect(h.system.isVisible(t))
    h.run("dock \(t.rawValue) left")
    h.system.drag(t, through: [h.frame(t)!.center, CGPoint(x: 700, y: 450), CGPoint(x: 1438, y: 450)])
    h.scheduler.runPending()
    for window in [s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window)") }
    #expect(h.controller.holdLevel == .view)
  }

  @Test func releasingWhileTheWindowIsAwayLaysOutWhatIsThere() {
    let s = stage()
    s.h.run("hold")
    s.h.system.setMinimized(s.keynote, true)
    #expect(s.h.run("release").ok)
    #expect(s.h.system.isVisible(s.mail))
    expectWindowsMatchLayout(s.h, on: s.h.display)
  }

  /// The green button, or a slideshow. It has a macOS Space to itself meanwhile, and comes back.
  @Test func aHeldWindowThatGoesFullScreenIsAwayNotGone() {
    let s = stage()
    s.h.run("hold")
    let others = [s.mail, s.slack, s.notes].map { s.h.frame($0) }
    s.h.system.setFullScreen(s.keynote, true)
    s.h.scheduler.runPending()
    #expect(s.h.controller.holdLevel == .view)
    #expect([s.mail, s.slack, s.notes].map { s.h.frame($0) } == others, "its surroundings do not come into view behind it")
    s.h.system.setFullScreen(s.keynote, false)
    s.h.scheduler.runPending()
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.frame(s.keynote) == s.h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect([s.mail, s.slack, s.notes].map { s.h.frame($0) } == others, "so there is nothing to send off again when it returns")
  }

  @Test func closingOneOfSeveralLaysOutWhatRemainsInsideTheHeldSpace() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    #expect(Set(h.layout!.windowFrames.keys) == [s.mail, s.slack])
    h.run("hold")
    h.system.close(s.slack)
    #expect(h.controller.holdLevel == .view)
    #expect(Set(h.layout!.windowFrames.keys) == [s.mail])
    #expect(h.frame(s.mail) == h.visibleFrame.insetBy(dx: 12, dy: 12), "mail takes the room")
    #expect(!h.system.isVisible(s.keynote), "and nothing else comes into view")
    #expect(!h.run("out").ok)
  }

  @Test func aSwitchOfMacOSSpacesAndBackDoesNotEndTheHold() {
    let s = stage()
    s.h.run("hold")
    // Safari is docked in the same arrangement and lives on the other Space.
    let safari = s.h.system.open(app: "Safari")
    s.h.system.clearFrameLog()
    for window in [s.keynote, s.mail, s.slack, s.notes] { s.h.system.setOnActiveSpace(window, false) }
    s.h.scheduler.runPending()
    #expect(s.h.system.frameLog.isEmpty, "nothing moves on the Space that shows meanwhile")
    s.h.system.close(safari)
    for window in [s.keynote, s.mail, s.slack, s.notes] { s.h.system.setOnActiveSpace(window, true) }
    s.h.scheduler.runPending()
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.frame(s.keynote) == s.h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!s.h.system.isVisible(s.mail))
  }

  @Test func thereMustBeSomethingToHold() {
    let h = Harness()
    h.start()
    let result = h.run("hold")
    #expect(!result.ok)
    #expect(h.controller.holdLevel == nil)
  }

  @Test func theDesktopWithItsFloatingWindowsCanBeHeld() {
    let s = stage()
    let h = s.h
    h.run("desktop")
    #expect(h.run("hold").ok)
    h.system.comesForward(s.mail)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    h.system.close(s.notes)
    #expect(h.controller.holdLevel == .view)
    #expect(h.workspace.camera == h.workspace.tree.desktop, "an empty Desktop is a view like any other")
    #expect(h.controller.displaysHeldEmpty.isEmpty)
    for window in [s.keynote, s.mail, s.slack] { #expect(!h.system.isVisible(window), "\(window)") }
  }

  // MARK: The one window the view depends on cannot be taken away by a slip

  /// Mail above Slack, in a row with Keynote and the Desktop. Side by side they stay a group of their own (F62), so
  /// the view goes on showing the two of them.
  @Test func aHeldGroupCanBeTurnedTheOtherWayAndNothingElseComesIn() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    h.system.userFocus(s.mail)
    h.run("hold")
    func onlyTheTwo(_ comment: Comment) {
      #expect(Set(h.layout!.windowFrames.keys) == [s.mail, s.slack], comment)
      #expect(!h.system.isVisible(s.keynote) && !h.system.isVisible(s.notes), comment)
      #expect(h.controller.holdLevel == .view, comment)
    }
    #expect(h.run("dock \(s.slack.rawValue) left").ok)
    #expect(h.frame(s.slack)!.maxX <= h.frame(s.mail)!.minX)
    onlyTheTwo("docked at the left edge of the view")
    #expect(h.run("dock \(s.slack.rawValue) right").ok)
    #expect(h.frame(s.mail)!.maxX <= h.frame(s.slack)!.minX)
    onlyTheTwo("moved one place to the right")
    h.system.drag(s.slack, through: [h.frame(s.slack)!.center, CGPoint(x: 300, y: 500), CGPoint(x: 2, y: 500)])
    #expect(h.frame(s.slack)!.maxX <= h.frame(s.mail)!.minX)
    onlyTheTwo("dragged to the left edge")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// `dock A beside B` takes A out first. A group of two used to be no group then, B joined the row around it and A after
  /// it, so the view could only have been on the whole row, and the command was refused. Since the core's second
  /// round (#154) the group keeps its place through that: allowed, and nothing else comes in.
  @Test func dockingOneOfTwoBesideTheOtherStaysInsideTheHeldView() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")
    h.run("dock \(s.slack.rawValue) left")  // slack | mail, a group of their own in Keynote's row
    h.system.userFocus(s.mail)
    h.run("hold")
    let result = h.run("dock \(s.slack.rawValue) beside \(s.mail.rawValue) right")
    #expect(result.ok, "\(result.message)")
    #expect(h.frame(s.mail)!.maxX <= h.frame(s.slack)!.minX)
    #expect(Set(h.layout!.windowFrames.keys) == [s.mail, s.slack])
    #expect(!h.system.isVisible(s.keynote) && !h.system.isVisible(s.notes))
    #expect(h.controller.holdLevel == .view)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aNewWindowCanBeDockedAtAnyEdgeOfAHeldViewAndNothingElseComesIn() {
    let s = stage()
    let h = s.h
    h.run("hold")
    let t = h.system.open(app: "Terminal")
    // Keynote is in a row with the Desktop and Mail. Beside it the two are a group of their own (F62).
    h.system.drag(t, through: [CGPoint(x: 620, y: 210), CGPoint(x: 1438, y: 500)])
    #expect(h.workspace.isDocked(t))
    #expect(h.frame(s.keynote)!.maxX <= h.frame(t)!.minX)
    #expect(Set(h.layout!.windowFrames.keys) == [s.keynote, t])
    #expect(!h.system.isVisible(s.mail) && !h.system.isVisible(s.notes))
    h.system.drag(t, through: [h.frame(t)!.center, CGPoint(x: 700, y: 898)])
    #expect(h.frame(s.keynote)!.maxY <= h.frame(t)!.minY)
    #expect(Set(h.layout!.windowFrames.keys) == [s.keynote, t])
    #expect(!h.system.isVisible(s.mail) && !h.system.isVisible(s.notes))
    #expect(h.controller.holdLevel == .view)
  }

  /// [keynote | Desktop | (mail / (slack | xcode))], held on the last column. When Mail closes, Slack and Xcode stay a
  /// group of their own instead of joining Keynote's row (F62), and the view stays on them.
  @Test func aWindowThatClosesNeverWidensTheView() {
    let s = stage()
    let h = s.h
    let xcode = h.system.open(app: "Xcode")
    h.run("show-all")
    h.run("dock \(xcode.rawValue) beside \(s.slack.rawValue) right")
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")
    #expect(Set(h.layout!.windowFrames.keys) == [s.mail, s.slack, xcode])
    h.system.userFocus(xcode)
    h.run("hold")

    h.system.close(s.mail)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(!h.system.isVisible(s.keynote), "nothing that was out of view comes in")
    #expect(!h.system.isVisible(s.notes))
    #expect(Set(h.layout!.windowFrames.keys) == [s.slack, xcode], "and nothing that was in view goes")
    #expect(h.controller.holdLevel == .view)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// Found by HoldFuzzTests. What is left of the space is a minimized window, which takes no room, so the layout
  /// would show what surrounds it.
  @Test func theLastWindowShowingCannotBeTakenOutWhileItsNeighbourIsMinimized() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    h.system.userFocus(s.slack)
    h.run("hold")
    h.system.setMinimized(s.mail, true)
    #expect(h.controller.holdLevel == .view)
    let before = picture(h)
    #expect(!h.run("float").ok)
    #expect(!h.run("toggle-float \(s.slack.rawValue)").ok)
    #expect(picture(h) == before)
    #expect(!h.system.isVisible(s.keynote))
  }

  /// Found by HoldFuzzTests. [keynote | Desktop] is held inside a taller arrangement; when Keynote closes the Desktop
  /// is what remains of it.
  @Test func whenTheDockedWindowsOfAHeldSpaceCloseTheDesktopThatWasPartOfItRemains() {
    let h = Harness()
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) top")
    h.run("zoom \(keynote.rawValue)")
    h.run("out")
    #expect(h.layout?.desktopFrame != nil && h.layout?.windowFrames[mail] == nil, "keynote and the Desktop, without mail")
    h.system.userFocus(notes)
    h.run("hold")
    h.system.close(keynote)
    #expect(h.controller.holdLevel == .view, "notes is still there, on the Desktop")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.system.isVisible(notes))
    #expect(!h.system.isVisible(mail))
  }

  @Test func theOnlyWindowInViewCannotBeFloatedOrDraggedOutFromUnderTheView() {
    let s = stage()
    let h = s.h
    h.run("hold")
    let before = picture(h)
    for text in ["float", "toggle-float", "float \(s.keynote.rawValue)", "dock \(s.keynote.rawValue) left"] {
      let result = h.run(text)
      #expect(!result.ok, "\(text)")
      #expect(picture(h) == before, "\(text)")
    }
    // To the left screen edge, where it would dock beside everything else; and just a nudge.
    h.system.drag(s.keynote, through: [CGPoint(x: 700, y: 50), CGPoint(x: 300, y: 300), CGPoint(x: 2, y: 400)])
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil }, "no preview promises what will not happen")
    #expect(picture(h) == before, "it goes back")
    h.system.drag(s.keynote, through: [CGPoint(x: 700, y: 50), CGPoint(x: 712, y: 58)])
    #expect(picture(h) == before)
    #expect(h.controller.holdLevel == .view)
  }

  /// F09's live reflow shows, during a drag, what letting go would give, and a window that has left its slot counts as out of the
  /// arrangement meanwhile. It moves windows without a layout, so past the fence.
  @Test func draggingTheWindowBeingShownBringsNothingIntoViewMeanwhile() {
    let s = stage { $0.reflowWhileDragging = true }
    let h = s.h
    h.run("hold")
    h.system.beginDrag(s.keynote)
    for point in [CGPoint(x: 700, y: 300), CGPoint(x: 900, y: 500), CGPoint(x: 1438, y: 450), CGPoint(x: 2, y: 450)] {
      h.system.moveDrag(to: point, holding: 0.5)
      for window in [s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window) at \(point)") }
    }
    h.system.endDrag()
    h.scheduler.runPending()
    for window in [s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window)") }
    #expect(h.frame(s.keynote) == h.visibleFrame.insetBy(dx: 12, dy: 12), "and it goes back to its place")
  }

  /// Among the windows in view it goes on showing what a drop would give.
  @Test func liveReflowStillWorksInsideAHeldView() {
    let s = stage { $0.reflowWhileDragging = true }
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    h.run("hold")
    let before = h.frame(s.slack)
    h.system.beginDrag(s.mail)
    h.system.moveDrag(to: CGPoint(x: 700, y: 880), holding: 0.5)
    #expect(h.frame(s.slack) != before, "slack makes way")
    #expect(!h.system.isVisible(s.keynote))
    h.system.endDrag()
    h.scheduler.runPending()
    #expect(!h.system.isVisible(s.keynote))
  }

  @Test func windowsInViewCanStillBeRearrangedAmongThemselves() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    h.system.userFocus(s.mail)
    h.run("hold")
    #expect(h.run("dock \(s.mail.rawValue) bottom").ok)
    #expect(h.frame(s.slack)!.maxY <= h.frame(s.mail)!.minY)
    #expect(h.run("resize \(s.mail.rawValue) top 60").ok)
    let seam = h.overlays.seams[h.display]![0]
    h.overlays.dragSeam(seam, by: -30)
    h.system.drag(s.slack, through: [h.frame(s.slack)!.center, CGPoint(x: 700, y: 898)])
    #expect(h.frame(s.mail)!.maxY <= h.frame(s.slack)!.minY, "dragged to the bottom edge of the view")
    #expect(h.run("float \(s.slack.rawValue)").ok)
    #expect(h.system.isVisible(s.slack), "it floats over the view")
    #expect(Set(h.layout!.windowFrames.keys) == [s.mail])
    #expect(!h.system.isVisible(s.keynote))
    #expect(!h.system.isVisible(s.notes))
    #expect(h.controller.holdLevel == .view)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func windowsOutOfViewCannotBeBroughtInByArrangingThem() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    for text in [
      "dock \(s.mail.rawValue) left", "float \(s.mail.rawValue)", "toggle-float \(s.notes.rawValue)",
      "dock \(s.notes.rawValue) right", "dock \(s.mail.rawValue) beside \(s.keynote.rawValue) left",
      "resize \(s.mail.rawValue) left 20",
    ] {
      let result = s.h.run(text)
      #expect(!result.ok, "\(text)")
      #expect(result.message.contains("out of view") && result.message.contains("held"), "\(result.message)")
    }
    #expect(picture(s.h) == before)
  }

  // MARK: 5. The ways out

  @Test func pauseWorksWhileHeldAndEndsTheHold() {
    let s = stage()
    s.h.run("hold 30")
    #expect(s.h.run("pause").ok)
    #expect(s.h.controller.holdLevel == nil)
    for window in [s.keynote, s.mail, s.slack, s.notes] {
      #expect(s.h.frame(window)!.fractionInside(s.h.visibleFrame) > 0.99)
    }
    #expect(s.h.run("resume").ok)
    #expect(s.h.controller.holdLevel == nil, "resuming does not bring the hold back")
    #expect(!s.h.scheduler.pendingKeys.contains("release"))
    #expect(s.h.run("show-all").ok)
  }

  /// F41's `pauseForApps`: Arbor pauses by itself while such an app is frontmost.
  @Test func anAppArborPausesForDoesNotPauseItOnAHeldView() {
    let s = stage { $0.pauseForApps = ["com.example.game"] }
    s.h.run("hold")
    let before = picture(s.h)
    s.h.system.activate(bundleID: "com.example.game", name: "Game")
    #expect(!s.h.controller.isPaused)
    #expect(s.h.controller.holdLevel == .view)
    #expect(picture(s.h) == before, "every window in view is the last thing wanted in front of an audience")
    s.h.run("release")
    #expect(s.h.controller.isPaused, "it was only put off")
  }

  @Test(arguments: ["float-all", "float-all here"]) func floatAllWorksWhileHeldAndEndsTheHold(text: String) {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    s.h.run("hold")
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.run(text).ok)
    #expect(s.h.controller.holdLevel == nil)
    #expect(s.h.workspace.tree.allWindows.isEmpty)
    #expect(s.h.workspace.isFloating(t), "back to a normal Mac: the rule that was waiting is dropped")
    for window in [s.keynote, s.mail, s.slack, s.notes] { #expect(s.h.system.isVisible(window)) }
  }

  // MARK: A slip on a key is not a way out

  /// ⌃⌥⎋ answers everywhere. Held, it lets go of the hold first, and of everything at the next press.
  @Test func theKeyThatPausesReleasesAHeldViewAndMovesNothing() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    let result = s.h.key("ctrl+opt+escape")
    #expect(result?.message == "released; the same key again pauses Arbor")
    #expect(s.h.controller.holdLevel == nil)
    #expect(!s.h.controller.isPaused)
    #expect(picture(s.h) == before)
    #expect(s.h.key("ctrl+opt+escape")?.ok == true)
    #expect(s.h.controller.isPaused)
  }

  /// A slip can last. Whether macOS repeats a shortcut that is kept down or not, one press is one press.
  @Test(arguments: ["ctrl+opt+escape", "ctrl+opt+p"]) func keptDownTheKeyDoesNotGoOnToPause(key: String) {
    let s = stage { $0.bindings = ["ctrl+opt+p": "pause 60"] }
    s.h.run("hold")
    let before = picture(s.h)
    s.h.keyDown(key)
    #expect(s.h.controller.holdLevel == nil)
    for _ in 0..<5 {
      s.h.scheduler.advance(by: 0.3)
      s.h.keyRepeat(key)
    }
    #expect(!s.h.controller.isPaused)
    #expect(picture(s.h) == before)
    s.h.keyUp(key)
    s.h.key(key)
    #expect(s.h.controller.isPaused, "let go and pressed again, it is meant")
  }

  /// macOS does not report every key that comes up. That must not cost the one key that answers everywhere.
  @Test func aKeyWhoseReleaseWasNeverReportedStillPausesWhenPressedAgain() {
    let s = stage()
    s.h.run("hold")
    s.h.keyDown("ctrl+opt+escape")
    s.h.keyUp("ctrl+opt+escape", reported: false)
    s.h.key("ctrl+opt+escape")
    s.h.key("ctrl+opt+escape")
    #expect(s.h.controller.isPaused, "at the second press at the latest")
  }

  @Test func duringACallTheKeyFallsBackToHoldingStillLikeRelease() {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    s.h.run("hold")
    let result = s.h.key("ctrl+opt+escape")
    #expect(result?.message == "released; still holding still while the camera is on (`release` again ends that too)")
    #expect(s.h.controller.holdLevel == .still)
    #expect(!s.h.controller.isPaused)
  }

  @Test func theKeyThatFloatsEverythingIsRefusedLikeTheOthers() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    let result = s.h.key("ctrl+opt+shift+f")
    #expect(result?.ok == false)
    #expect(result?.message.hasPrefix("the view is held; release it with ⌃⌥⎋") == true)
    #expect(s.h.controller.holdLevel == .view)
    #expect(picture(s.h) == before)
    #expect(s.h.press("float-all here").ok == false, "whichever key the user gave it")
  }

  /// Chosen from a menu or typed, they are meant.
  @Test(arguments: [CommandSource.menu, .script]) func fromTheMenuAndTheTerminalBothAreStillWaysOut(source: CommandSource) {
    for text in ["pause", "toggle-pause", "float-all"] {
      let s = stage()
      s.h.run("hold")
      #expect(s.h.run(text, from: source).ok, "\(text)")
      #expect(s.h.controller.holdLevel == nil, "\(text)")
      for window in [s.keynote, s.mail, s.slack, s.notes] { #expect(s.h.system.isVisible(window), "\(text): \(window)") }
    }
  }

  /// There the user's own keys work as ever.
  @Test func holdingStillTheKeyPausesAtOnce() {
    let s = stage()
    s.h.run("hold still")
    s.h.key("ctrl+opt+escape")
    #expect(s.h.controller.isPaused)
  }

  @Test func quittingWorksWhileHeldAndTheHoldIsNotKept() {
    let s = stage()
    s.h.run("hold 10")
    s.h.controller.shutdown()
    for window in [s.keynote, s.mail, s.slack, s.notes] {
      #expect(s.h.frame(window)!.fractionInside(s.h.visibleFrame) > 0.99)
    }
    #expect(s.h.controller.holdLevel == nil)
    #expect(!s.h.scheduler.pendingKeys.contains("release"))

    let next = Harness(saved: s.h.store.saved)
    next.start()
    #expect(next.controller.holdLevel == nil, "not kept across a relaunch")
  }

  @Test func toggleHoldDoesWhicheverApplies() {
    let s = stage()
    #expect(s.h.run("toggle-hold").ok)
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.run("toggle-hold").ok)
    #expect(s.h.controller.holdLevel == nil)
    #expect(!s.h.run("release").ok, "there is nothing to release")
  }

  // MARK: hold <minutes>

  @Test func aTimedHoldReleasesByItself() {
    let s = stage()
    #expect(s.h.run("hold 30").message.contains("30 minutes"))
    s.h.scheduler.advance(by: 29 * 60)
    #expect(s.h.controller.holdLevel == .view)
    s.h.scheduler.advance(by: 61)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func aSecondHoldReplacesTheFirstOnesEnd() {
    let s = stage()
    s.h.run("hold 1")
    s.h.run("hold 10")
    s.h.scheduler.advance(by: 5 * 60)
    #expect(s.h.controller.holdLevel == .view)
    s.h.run("hold")
    s.h.scheduler.advance(by: 24 * 60 * 60)
    #expect(s.h.controller.holdLevel == .view, "without a number there is no end")
    s.h.run("hold 1")
    s.h.run("release")
    s.h.run("hold")
    s.h.scheduler.advance(by: 120)
    #expect(s.h.controller.holdLevel == .view, "a released hold's timer does not end the next one")
  }

  // MARK: Every display

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)

  /// The stage on the main display; xcode | safari on the side display, framed on xcode.
  func twoDisplays(configure: (inout Settings) -> Void = { _ in }) -> (Stage, xcode: WindowID, safari: WindowID) {
    let s = stage(displays: [FakeWindowSystem.standardDisplay, Self.side], configure: configure)
    let place = CGRect(x: 1700, y: 200, width: 640, height: 420)
    let xcode = s.h.system.open(app: "Xcode", frame: place)
    let safari = s.h.system.open(app: "Safari", frame: place)
    s.h.run("dock \(xcode.rawValue) left")
    s.h.run("dock \(safari.rawValue) right")
    s.h.run("zoom \(xcode.rawValue)")
    s.h.system.userFocus(s.keynote)
    return (s, xcode, safari)
  }

  /// Found by HoldFuzzTests, in words: carried over to another display, the framed window has left its own arrangement for the length
  /// of the trial that live reflow shows, and its own display laid out what was around it. On one display nothing of the kind
  /// happens, because the slot the window left is kept open.
  @Test func carryingTheFramedWindowToAnotherDisplayShowsNothingOfItsOwnMeanwhile() {
    let (s, xcode, safari) = twoDisplays { $0.reflowWhileDragging = true }
    let h = s.h
    h.run("hold")
    h.system.beginDrag(xcode)
    for point in [CGPoint(x: 1500, y: 450), CGPoint(x: 700, y: 450), CGPoint(x: 300, y: 450), CGPoint(x: 2, y: 450)] {
      h.system.moveDrag(to: point, holding: 0.5)
      for window in [safari, s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window) at \(point)") }
    }
    h.system.endDrag()
    h.scheduler.runPending()
    for window in [safari, s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window)") }
  }

  // MARK: A display goes while its window is being typed in

  /// The laptop's view is on one window, so its Desktop is not in view; he types on the big display and pulls the cable. What arrives from a
  /// display that went counts as out of view, and here it is. Holding still took it for an app that had pushed itself forward: it stayed
  /// out of view and his next words landed in the window in view. It has had the keyboard all along: the view follows it, as without a hold.
  @Test(arguments: [nil, "hold still"], [false, true]) func holdingStillTheViewFollowsTheWindowBeingTypedInWhenItsDisplayGoes(hold: String?, docked: Bool) {
    let (s, xcode, _) = twoDisplays()
    let h = s.h
    if !docked { h.run("float \(xcode.rawValue)") }
    h.system.userFocus(xcode)
    if let hold { #expect(h.run(hold).ok) }
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 3)
    #expect(h.system.focused == xcode, "not \(s.keynote), which was in view on the laptop")
    #expect(h.system.isVisible(xcode))
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Self.side])
    h.scheduler.advance(by: 3)
    #expect(h.system.focused == xcode, "and when the display is back")
    #expect(h.system.isVisible(xcode))
  }

  /// A held view does not move. The window arrives out of it, and the keyboard must not stay where nobody can see it.
  @Test func onAHeldViewTheKeyboardComesBackIntoItInstead() {
    let (s, xcode, _) = twoDisplays()
    let h = s.h
    h.system.userFocus(xcode)
    h.run("hold")
    let view = h.workspace.camera
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 3)
    #expect(h.workspace.camera == view)
    #expect(!h.system.isVisible(xcode))
    #expect(h.system.focused == s.keynote)
  }

  /// Triage's caution. One that TOOK the keyboard unasked, out of view, a moment before the cable goes is not the window being typed in.
  @Test func anAppThatHadJustPushedItselfForwardIsNotLetInWhenTheDisplayGoes() {
    let (s, xcode, safari) = twoDisplays()
    let h = s.h
    h.system.userFocus(xcode)
    h.run("hold still")
    h.system.defersFocus = true  // asked back, and macOS has not done it yet
    h.system.comesForward(safari)
    #expect(h.system.focused == safari)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.system.defersFocus = false
    h.scheduler.advance(by: 3)
    #expect(!h.system.isVisible(safari), "it is turned away as ever")
    #expect(h.system.focused != safari)
  }

  @Test func theViewIsHeldOnEveryDisplay() {
    let (s, _, safari) = twoDisplays()
    s.h.run("hold")
    let before = picture(s.h)
    for cursor in [CGPoint(x: 700, y: 400), CGPoint(x: 2000, y: 400)] {
      s.h.system.cursor = cursor
      for text in ["show-all", "out", "home", "neighbor right"] { #expect(!s.h.run(text).ok) }
    }
    s.h.system.comesForward(safari)
    #expect(s.h.system.focused == s.keynote, "back to the window that had the keyboard, on the other display")
    #expect(picture(s.h) == before)
  }

  @Test func eachDisplaysViewStaysHeldWhenItEmpties() {
    let (s, xcode, safari) = twoDisplays()
    s.h.run("hold")
    s.h.system.close(xcode)
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.controller.displaysHeldEmpty == [Self.side.id])
    #expect(!s.h.system.isVisible(safari), "which display is being shared is not for Arbor to know")
    #expect(s.h.controller.holdMenu.first?.title == "The view is held: nothing moves it", "the other one still shows what it showed")
    s.h.system.comesForward(s.slack)
    #expect(s.h.workspace.camera == s.h.workspace.tree.leaf(containing: s.keynote))
    s.h.system.close(s.keynote)
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.controller.holdMenu.first?.title == "The view is held: nothing is in it")
    for window in [safari, s.mail, s.slack, s.notes] { #expect(!s.h.system.isVisible(window), "\(window)") }
  }

  @Test func aFloatingWindowCanBeDockedOnAnotherDisplaysHeldViewAndNothingElseComesIn() {
    let (s, xcode, safari) = twoDisplays()
    let h = s.h
    h.run("hold")
    let t = h.system.open(app: "Terminal")
    #expect(h.controller.workspaceID(containing: t) == h.display)
    // The right edge of the side display, where the view is on Xcode, which is in a row with Safari.
    h.system.drag(t, through: [CGPoint(x: 620, y: 210), CGPoint(x: 2000, y: 500), CGPoint(x: 3358, y: 500)])
    #expect(h.controller.workspaceID(containing: t) == Self.side.id, "it belongs to the display it is on")
    #expect(h.controller.workspaces[h.display]?.contains(t) == false)
    #expect(!h.system.isVisible(safari))
    #expect(h.controller.layouts[Self.side.id]?.windowFrames.keys.sorted() == [xcode, t].sorted())
  }

  @Test func unpluggingADisplayBringsNothingIntoTheHeldView() {
    let (s, xcode, safari) = twoDisplays()
    s.h.run("hold")
    let framed = s.h.frame(s.keynote)
    s.h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(s.h.controller.holdLevel == .view)
    #expect(s.h.frame(s.keynote) == framed)
    for window in [xcode, safari, s.mail, s.slack, s.notes] { #expect(!s.h.system.isVisible(window), "\(window)") }
    s.h.system.close(s.keynote)
    #expect(s.h.controller.holdLevel == .view)
    for window in [xcode, safari, s.mail, s.slack, s.notes] { #expect(!s.h.system.isVisible(window), "\(window)") }
    #expect(s.h.run("release").ok)
    expectWindowsMatchLayout(s.h, on: s.h.display)
  }

  // MARK: hold still

  @Test func holdingStillTheUsersOwnMovesWork() {
    let s = stage()
    #expect(s.h.run("hold still").ok)
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.run("show-all").ok)
    #expect(s.h.workspace.camera == s.h.workspace.tree.root)
    #expect(s.h.run("zoom \(s.mail.rawValue)").ok)
    #expect(s.h.run("back").ok)
    #expect(s.h.run("arrange").ok)
    #expect(s.h.controller.inputSettings == s.h.controller.settings, "pinches and rectangles are asked for, too")
    #expect(s.h.controller.holdLevel == .still)
  }

  @Test func holdingStillAnAppThatComesForwardByItselfStaysOutOfView() {
    let s = stage()
    s.h.run("hold still")
    let before = picture(s.h)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote)
    #expect(picture(s.h) == before)
  }

  @Test func holdingStillTheViewFollowsAWindowTheUserSwitchedTo() {
    let s = stage()
    s.h.run("hold still")
    // ⌘Tab, a click in the Dock or on a notification.
    s.h.system.userFocus(s.slack)
    #expect(s.h.system.focused == s.slack)
    #expect(s.h.system.isVisible(s.slack))
  }

  @Test(arguments: [(0.0, true), (0.4, true), (0.6, false), (30.0, false)])
  func onlyAFocusChangeRightAfterAClickOrAModifierKeyCountsAsAsked(seconds: Double, follows: Bool) {
    let s = stage()
    s.h.run("hold still")
    s.h.system.secondsSinceInput = seconds
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.isVisible(s.slack) == follows)
    #expect(s.h.system.focused == (follows ? s.slack : s.keynote))
  }

  /// The report of a window reached by ⌘Tab comes before the view has followed it (the product owner's finding 8).
  @Test func holdingStillTheKeyboardGoesBackToTheWindowJustSwitchedTo() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.mail.rawValue)")
    h.run("out")  // mail above slack
    h.system.userFocus(s.mail)
    h.run("zoom \(s.keynote.rawValue)")
    h.system.userFocus(s.keynote)
    h.run("hold still")
    h.run("back")  // mail above slack again; the keyboard goes to one of them
    h.system.userFocus(s.mail)
    h.run("zoom \(s.mail.rawValue)")
    h.system.userFocus(s.slack)  // ⌘Tab: out of view, and the view follows
    #expect(h.system.isVisible(s.slack))
    h.system.comesForward(s.keynote)
    #expect(!h.system.isVisible(s.keynote))
    #expect(h.system.focused == s.slack)
  }

  /// The same with F53, where it was found: losing the keyboard sends a summoned window away.
  @Test func holdingStillASummonedWindowReachedByCommandTabIsNotSentAway() {
    let s = stage()
    let h = s.h
    h.run("hold still")
    h.run("summon Notes")
    h.run("summon Notes")
    h.system.userFocus(s.notes)
    #expect(h.system.isVisible(s.notes))
    h.system.comesForward(s.slack)
    #expect(!h.system.isVisible(s.slack))
    #expect(h.system.focused == s.notes)
    #expect(h.system.isVisible(s.notes))
  }

  @Test func summoningIsRefusedOnAHeldView() {
    let s = stage()
    s.h.run("hold")
    let before = picture(s.h)
    #expect(!s.h.run("summon Notes").ok)
    #expect(picture(s.h) == before)
  }

  /// With Dock New Windows on and the view framed, where there is no room: F23 lets it float, and nothing else comes into view.
  @Test func dockNewWindowsBringsNothingIntoViewWhenTheHoldEnds() {
    let s = stage { $0.newWindows = "dock" }
    let h = s.h
    h.run("hold")
    let t = h.system.open(app: "Terminal", bundleID: terminal)
    h.system.userFocus(s.keynote)
    h.run("release")
    for window in [s.mail, s.slack, s.notes] { #expect(!h.system.isVisible(window), "\(window)") }
    #expect(h.system.isVisible(t))
    #expect(h.system.isVisible(s.keynote))
  }

  /// Go to… only gives such a window the keyboard: macOS slides over to its Space and reports the keyboard most of a second after Return,
  /// with nobody having clicked anything, and before it reports which windows show now. Turned away, the keyboard would be asked back to
  /// a window on the Space the person has just left, and macOS would slide back there.
  @Test func holdingStillGoToReachesAWindowOnAnotherMacOSSpace() {
    let s = stage()
    let h = s.h
    h.system.setOnActiveSpace(s.mail, false)
    h.scheduler.runPending()
    h.run("hold still")
    h.system.defersFocus = true
    #expect(h.run("reveal \(s.mail.rawValue)").ok)
    let asked = h.system.focusRequests.count
    #expect(h.system.focusRequests.last == s.mail)
    // Something else has the keyboard on the way: whatever had it on that Space before.
    h.scheduler.advance(by: 0.4)
    h.system.comesForward(s.notes)
    h.scheduler.advance(by: 0.4)
    h.system.comesForward(s.mail)
    #expect(!h.system.focusRequests.dropFirst(asked).contains(s.keynote), "nobody is pulled back to the Space they left")
    for window in [s.keynote, s.slack, s.notes] { h.system.setOnActiveSpace(window, false) }
    h.system.setOnActiveSpace(s.mail, true)
    h.scheduler.advance(by: 2)
    #expect(!h.system.focusRequests.dropFirst(asked).contains(s.keynote))
    #expect(h.system.focused == s.mail)
    #expect(h.system.isVisible(s.mail), "asked for by name")
    #expect(h.controller.holdLevel == .still)
  }

  /// There the view is on another window of that Space, so it has to move for the window to be seen.
  @Test func andTheViewFollowsItThere() {
    let s = stage()
    let h = s.h
    h.run("zoom \(s.slack.rawValue)")
    // Over to the Space where Keynote lives; Mail and Slack stay behind.
    for window in [s.mail, s.slack] { h.system.setOnActiveSpace(window, false) }
    h.scheduler.runPending()
    h.system.userFocus(s.keynote)
    h.run("hold still")
    h.system.defersFocus = true
    #expect(h.run("reveal \(s.mail.rawValue)").ok)
    h.scheduler.advance(by: 0.4)
    h.system.comesForward(s.slack)  // it had the keyboard there last
    for window in [s.keynote, s.notes] { h.system.setOnActiveSpace(window, false) }
    for window in [s.mail, s.slack] { h.system.setOnActiveSpace(window, true) }
    h.scheduler.advance(by: 0.4)
    h.system.comesForward(s.mail)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(s.mail), "asked for by name")
    #expect(h.system.focused == s.mail)
  }

  /// The control: the same report with nobody having asked, and one that comes long after the asking.
  @Test(arguments: [false, true]) func butNotOneThatComesForwardThereByItself(askedLongAgo: Bool) {
    let s = stage()
    let h = s.h
    h.run("hold still")
    if askedLongAgo {
      h.system.defersFocus = true
      h.system.setOnActiveSpace(s.mail, false)
      h.scheduler.runPending()
      h.run("reveal \(s.mail.rawValue)")
      h.system.setOnActiveSpace(s.mail, true)
      h.system.defersFocus = false
      h.scheduler.advance(by: 10)
    }
    h.system.comesForward(s.mail)
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(s.mail))
    #expect(h.system.focused == s.keynote)
  }

  @Test func holdingStillRulesWaitAsWell() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    s.h.run("hold still")
    let framed = s.h.frame(s.keynote)
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isFloating(t))
    #expect(s.h.frame(s.keynote) == framed)
    s.h.run("release")
    #expect(s.h.workspace.isDocked(t))
  }

  @Test func holdingStillDoesNotEndWhenTheViewEmpties() {
    let s = stage()
    s.h.run("hold still")
    s.h.system.close(s.keynote)
    #expect(s.h.controller.holdLevel == .still, "the call goes on")
  }

  @Test func oneStrengthReplacesTheOther() {
    let s = stage()
    s.h.run("hold still")
    s.h.run("hold")
    #expect(s.h.controller.holdLevel == .view)
    #expect(!s.h.run("out").ok)
    s.h.run("hold still")
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.run("out").ok)
    s.h.run("toggle-hold")
    #expect(s.h.controller.holdLevel == .view, "from holding still, the toggle holds the view")
    s.h.run("release")
    #expect(s.h.controller.holdLevel == nil)
  }

  // MARK: Calls (`holdStillFor`)

  @Test func arborHoldsStillWhileACallsWindowIsOpen() {
    let s = stage()
    #expect(s.h.controller.holdLevel == nil)
    let main = s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Workplace")
    #expect(s.h.controller.holdLevel == nil, "Zoom being open is not a call")
    let meeting = s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(s.h.controller.holdLevel == .still)
    s.h.system.userFocus(s.keynote)
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote)
    #expect(!s.h.system.isVisible(s.slack))

    s.h.system.setMinimized(meeting, true)
    #expect(s.h.controller.holdLevel == .still, "minimized, the call goes on")
    s.h.system.close(meeting)
    #expect(s.h.controller.holdLevel == nil)
    s.h.system.close(main)
  }

  @Test func aCallIsRecognisedWhenTheTitleArrivesLateAndInAnAppArborDoesNotArrange() {
    let s = stage { $0.excludedBundleIDs = [zoom] }
    let window = s.h.system.open(app: "Zoom", bundleID: zoom, title: "")
    #expect(s.h.controller.holdLevel == nil)
    s.h.system.setTitle(window, "Zoom Meeting")
    #expect(s.h.controller.holdLevel == .still)
    s.h.system.setTitle(window, "Zoom Workplace")
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func aCallAlreadyGoingOnAtLaunchCounts() {
    var settings = Settings()
    settings.holdStillFor = ["us.zoom.xos Zoom Meeting"]
    let h = Harness(settings: settings)
    h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    h.start()
    #expect(h.controller.holdLevel == .still)
  }

  /// No app's being open is a call out of the box. Listed without title text, any window of it would do, minimized ones too, all day.
  @Test func faceTimeBeingOpenIsNoCall() {
    let h = Harness()
    h.system.open(app: "FaceTime", bundleID: "com.apple.FaceTime")
    h.start()
    #expect(h.controller.holdLevel == nil)
  }

  @Test func releaseDuringACallLastsUntilTheCallIsOver() {
    let s = stage()
    let meeting = s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(s.h.run("release").ok)
    #expect(s.h.controller.holdLevel == nil)
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    s.h.system.setTitle(meeting, "Zoom Meeting 2")
    #expect(s.h.controller.holdLevel == nil, "Arbor does not start again behind the user's back")
    for window in s.h.system.windows.keys.sorted() where s.h.system.windows[window]!.snapshot.bundleID == zoom {
      s.h.system.close(window)
    }
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(s.h.controller.holdLevel == .still, "the next call is a new one")
  }

  @Test func releasingAHeldViewDuringACallFallsBackToHoldingStill() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    s.h.system.userFocus(s.keynote)
    s.h.run("hold")
    #expect(s.h.controller.holdLevel == .view)
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    let result = s.h.run("release")
    #expect(result.ok)
    #expect(result.message.contains("Zoom"), "\(result.message)")
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.workspace.isFloating(t), "rules go on waiting")
    s.h.run("release")
    #expect(s.h.controller.holdLevel == nil)
    #expect(s.h.workspace.isDocked(t))
  }

  @Test func theListCanBeChangedAndEmptiedWhileRunning() {
    let s = stage()
    s.h.system.open(app: "Chrome", bundleID: "com.google.Chrome", title: "Meet - abc-defg-hij")
    #expect(s.h.controller.holdLevel == nil)
    var settings = s.h.controller.settings
    settings.holdStillFor = ["com.google.Chrome Meet - "]
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == .still)
    settings.holdStillFor = []
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func aCallThatEndsWhilePausedIsNoticedOnResume() {
    let s = stage()
    let meeting = s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    s.h.run("pause")
    #expect(s.h.controller.holdLevel == nil)
    s.h.run("resume")
    #expect(s.h.controller.holdLevel == .still)
    s.h.run("pause")
    s.h.system.close(meeting)
    s.h.run("resume")
    #expect(s.h.controller.holdLevel == nil)
  }

  // MARK: Calls (a camera or a microphone that is on)

  /// A camera that is on is not a screen that is shared, and the sensor has not been seen at work on a Mac.
  @Test func outOfTheBoxNothingStartsAHoldByItself() {
    let h = Harness()
    h.system.open(app: "Keynote")
    h.start()
    h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    h.system.open(app: "zoom.us", bundleID: "us.zoom.xos", title: "Zoom Meeting")
    #expect(h.controller.holdLevel == nil)
    #expect(h.run("hold still").ok, "it is there to be chosen")
  }

  // MARK: What holding still turns away is said

  /// A launcher, `open` in a terminal, a link whose browser takes more than half a second: the person's own doing, which looks like an app
  /// pushing itself forward. Turned away in silence, the second try would end the same and nothing would say why.
  @Test func whatHoldingStillTurnsAwayIsSaidOnceForEachAppAndHold() {
    let s = stage()
    let h = s.h
    h.run("hold still")
    let said = h.overlays.messages.count
    h.system.comesForward(s.slack)
    #expect(h.overlays.messages.count == said + 1)
    #expect(h.overlays.messages.last?.model.line == "Slack is out of view: holding still · ⌘Tab or ⌃⌥G goes there")
    #expect(h.overlays.messages.last?.model.kind == .problem)
    h.scheduler.advance(by: 10)
    h.system.comesForward(s.slack)
    #expect(h.overlays.messages.count == said + 1, "once")
    h.scheduler.advance(by: 10)
    h.system.comesForward(s.mail)
    #expect(h.overlays.messages.count == said + 2, "for each app")
    h.run("release")
    h.run("hold still")
    h.scheduler.advance(by: 10)
    let again = h.overlays.messages.count
    h.system.comesForward(s.slack)
    #expect(h.overlays.messages.count == again + 1, "and hold")
  }

  @Test func theLineNamesTheKeysThatWork() {
    let s = stage { $0.bindings = ["ctrl+opt+g": nil] }
    s.h.run("hold still")
    s.h.system.comesForward(s.slack)
    #expect(s.h.overlays.messages.last?.model.line == "Slack is out of view: holding still · ⌘Tab goes there")
  }

  /// There nothing of Arbor's appears but the reason why a key did nothing. And whoever has switched the lines off has.
  @Test func notOnAHeldViewNorWithTheLinesSwitchedOff() {
    let s = stage()
    s.h.run("hold")
    let said = s.h.overlays.messages.count
    s.h.system.comesForward(s.slack)
    #expect(s.h.overlays.messages.count == said)

    let quiet = stage { $0.messages = "off" }
    quiet.h.run("hold still")
    quiet.h.system.comesForward(quiet.slack)
    #expect(quiet.h.overlays.messages.isEmpty)
  }

  /// Read, not run, by the minimap's owner, and true. macOS's answer to "who has the keyboard" can lag behind its report, and then the view
  /// follows a moment later. A report from an app in the background in between unsaid that the window had been asked for. Here it is
  /// a pinned call's: raising it can make its app report it, and that leaves the look that is due at the other window alone.
  @Test func aReportFromTheBackgroundDoesNotUnsayWhatWasAskedFor() {
    let s = stage()
    let h = s.h
    h.run("pin \(s.notes.rawValue)")
    h.system.userFocus(s.keynote)
    h.run("hold still")
    h.system.secondsSinceInput = 0.1  // ⌘ has just come up
    h.system.backgroundFocus(s.mail)  // the report, ahead of the answer
    h.system.secondsSinceInput = 0.7
    h.system.backgroundFocus(s.notes)
    h.system.userSwitchesApp(to: s.mail)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(s.mail), "⌘Tab is followed")
    #expect(h.system.focused == s.mail)
  }

  @Test func arborHoldsStillWhileACameraIsOnWhicheverAppTheCallIsIn() {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the camera is on")
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote)
    #expect(!s.h.system.isVisible(s.slack))
    #expect(s.h.run("show-all").ok, "the user's own keys work")

    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 6)
    #expect(s.h.controller.holdLevel == nil)
  }

  /// Until it has been seen on a Mac that "Hey Siri" and dictation are no call and that muting ends none (docs/TESTING.md).
  @Test func aMicrophoneDoesNotCountUnlessSwitchedOn() {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    #expect(s.h.controller.holdLevel == nil)
  }

  /// The camera is switched off and on again with the microphone on all the while, which does not count.
  @Test func aMicrophoneThatDoesNotCountDoesNotCutTheWaitShort() {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.holdLevel == .still)
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    s.h.scheduler.advance(by: 60)
    #expect(s.h.controller.holdLevel == .still)
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    s.h.scheduler.advance(by: 6)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func theSameForAMicrophone() {
    let s = stage { $0.holdStillWhileMicrophoneIsOn = true }
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the microphone is on")
  }

  @Test func eachCanBeSwitchedOffAlsoInTheMiddleOfACall() {
    let s = stage {
      $0.holdStillWhileCameraIsOn = false
      $0.holdStillWhileMicrophoneIsOn = false
    }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    #expect(s.h.controller.holdLevel == nil)
    var settings = s.h.controller.settings
    settings.holdStillWhileMicrophoneIsOn = true
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the microphone is on")
    settings.holdStillWhileMicrophoneIsOn = false
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func changingDevicesInTheMiddleOfACallDoesNotEndIt() {
    let s = stage {
      $0.rules = [AppRule(app: terminal, action: .dock(.right))]
      $0.holdStillWhileMicrophoneIsOn = true
    }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    var changes = 0
    s.h.controller.observe { if $0 == .hold { changes += 1 } }
    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 3)
    #expect(s.h.controller.holdLevel == .still)
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    s.h.scheduler.advance(by: 60)
    #expect(s.h.controller.holdLevel == .still)
    #expect(changes == 0)
    #expect(s.h.workspace.isFloating(t), "and the rule goes on waiting")
  }

  @Test func releaseLastsForTheWholeCallThoughItsSignsChange() {
    let s = stage { $0.holdStillWhileMicrophoneIsOn = true }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true, microphoneIsOn: true))
    s.h.run("release")
    #expect(s.h.controller.holdLevel == nil)
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))  // the camera is switched off
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func aCallThatBeganDuringAPauseIsNoticedOnResume() {
    let s = stage()
    s.h.run("pause")
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.controller.holdLevel == nil)
    s.h.run("resume")
    #expect(s.h.controller.holdLevel == .still)
    s.h.run("pause")
    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 10)
    s.h.run("resume")
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func theWindowIsNamedRatherThanTheCamera() {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while Zoom is open")
  }

  /// What makes a false alarm (a microphone some app never lets go of) nearly harmless.
  @Test func holdingStillAWindowTheUserOpenedIsDockedByItsRuleAtOnce() {
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.bottom))] }
    s.h.run("hold still")
    s.h.system.secondsSinceInput = 0.2  // ⌘N
    let mine = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isDocked(mine))
    s.h.system.secondsSinceInput = 40
    let itsOwn = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isFloating(itsOwn))

    s.h.run("hold")
    s.h.system.secondsSinceInput = 0.2
    let held = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isFloating(held), "a held view makes room for nobody")
  }

  // MARK: What the user is told

  @Test func statusStateAndTheMenuSayHowTheViewIsHeld() {
    let s = stage()
    func ticks() -> [String] { s.h.controller.holdMenu.filter(\.isOn).map(\.title) }
    #expect(s.h.run("state").state?.held == nil)
    #expect(ticks().isEmpty)
    #expect(s.h.controller.holdMenu.map(\.command) == [.hold(minutes: nil), .holdStill(minutes: nil)])

    s.h.run("hold")
    #expect(s.h.run("status").message.contains("the view is held"))
    #expect(s.h.run("state").state?.held == .view)
    #expect(ticks() == ["Hold This View"])
    // docs/MENU.md: a line of plain words, then the command that ends it.
    #expect(s.h.controller.holdMenu.map(\.title) == ["The view is held: nothing moves it", "Release", "Hold This View", "Hold Still"])
    #expect(s.h.controller.holdMenu.map(\.command) == [nil, .release, .release, .holdStill(minutes: nil)], "the ticked one releases too")

    s.h.run("hold still")
    #expect(s.h.run("status").message.contains("holding still"))
    #expect(s.h.run("state").state?.held == .still)
    #expect(ticks() == ["Hold Still"])
    #expect(
      s.h.controller.holdMenu.map(\.title) == ["Holding still: the view moves only when you ask", "Release", "Hold This View", "Hold Still"])

    s.h.run("release")
    #expect(!s.h.run("status").message.contains("held"))
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(ticks() == ["Hold Still"])
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while Zoom is open", "and why")
    #expect(s.h.controller.holdMenu.first?.command == nil, "a remark, not something to choose")
  }

  @Test func whyAndForHowLongArborHoldsStillCanAlwaysBeFoundOut() {
    let s = stage { $0.holdStillWhileMicrophoneIsOn = true }
    s.h.controller.callSignalsChanged(CallSignals(microphoneIsOn: true))
    #expect(s.h.run("status").message.hasSuffix("; holding still while the microphone is on: the view moves only when you ask"))
    s.h.scheduler.advance(by: 12 * 60 + 30)
    #expect(s.h.run("status").message.contains("holding still (12 minutes so far) while the microphone is on"))
    s.h.run("hold")
    #expect(s.h.run("status").message.contains("the view is held (12 minutes so far) until `release`"), "held one way or the other since then")
    s.h.run("hold still")
    #expect(!s.h.run("status").message.contains("microphone"), "chosen: no other reason is needed")
  }

  /// "For 5 minutes" could be since or until. `status` says both, each in its own words.
  @Test func aHoldThatEndsByItselfSaysWhen() {
    let s = stage()
    #expect(s.h.run("hold 5").message == "holding this view for 5 minutes")
    #expect(s.h.run("status").message.hasSuffix("; the view is held for 5 minutes more"))
    s.h.scheduler.advance(by: 2 * 60 + 10)
    #expect(s.h.run("status").message.hasSuffix("; the view is held (2 minutes so far) for 3 minutes more"))
    s.h.scheduler.advance(by: 2 * 60 + 40)
    #expect(s.h.run("status").message.hasSuffix("; the view is held (4 minutes so far) for 1 minute more"))
    s.h.run("hold")
    #expect(s.h.run("status").message.hasSuffix("; the view is held (4 minutes so far) until `release`"), "the second hold replaces the end")
    s.h.run("hold still 10")
    #expect(s.h.run("status").message.hasSuffix("; holding still (4 minutes so far) for 10 minutes more: the view moves only when you ask"))
    s.h.run("release")
    s.h.run("hold")
    #expect(s.h.run("status").message.hasSuffix("; the view is held until `release`"), "nothing is left of the last one")
  }

  @Test func aRefusalNamesTheWayOutForSomeoneAtTheMac() {
    let s = stage()
    s.h.run("hold")
    #expect(s.h.run("out").message == "the view is held; release it with ⌃⌥⎋, from Arbor's menu or with `release`")

    let bound = stage { $0.bindings = ["ctrl+opt+h": "toggle-hold"] }
    bound.h.run("hold")
    #expect(bound.h.run("out").message == "the view is held; release it with ⌃⌥H, from Arbor's menu or with `release`", "their own key first")

    let moved = stage { $0.bindings = ["ctrl+opt+escape": "none", "ctrl+opt+p": "toggle-pause"] }
    moved.h.run("hold")
    #expect(moved.h.run("out").message == "the view is held; release it with ⌃⌥P, from Arbor's menu or with `release`")
    #expect(moved.h.key("ctrl+opt+p")?.message.hasPrefix("released") == true, "and it does")

    let none = stage { $0.hotkeysEnabled = false }
    none.h.run("hold")
    #expect(none.h.run("out").message == "the view is held; release it from Arbor's menu or with `release`")
  }

  /// "Step out first" is advice that would be refused.
  @Test func adviceThatCannotBeFollowedWhileHeldIsNotGiven() {
    let s = stage()
    #expect(s.h.run("resize \(s.keynote.rawValue) right 40").message == "that edge is not in view; step out first")
    #expect(s.h.run("dock \(s.keynote.rawValue) right").message.hasSuffix("fills the view; step out first"))
    s.h.run("hold")
    for text in ["resize \(s.keynote.rawValue) right 40", "dock \(s.keynote.rawValue) right"] {
      let message = s.h.run(text).message
      #expect(!message.contains("step out"), "\(text)")
      #expect(message.hasSuffix(", and the view is held; release it with ⌃⌥⎋, from Arbor's menu or with `release`"), "\(text): \(message)")
    }
  }

  /// docs/MENU.md, state 4: the line and the command that ends it come first; what would be refused is grey.
  @Test func theMenuOfAHeldView() throws {
    let s = stage()
    s.h.run("hold")
    let menu = s.h.controller.menuModel()
    #expect(menu.sections[0].items.map(\.title) == ["The view is held: nothing moves it", "Release"])
    #expect(menu.sections[0].items.map(\.isEnabled) == [false, true])
    #expect(try #require(menu.item("Release")).shortcut == s.h.controller.shortcut(for: .togglePause), "the key that pauses releases first")
    for title in ["Show Everything", "Step Out", "Back", "Arrange Windows", "Reload Settings", "Check for Updates…"] {
      #expect(try #require(menu.item(title), "\(title)").isEnabled == false, "\(title)")
    }
    #expect(try #require(menu.item("Hold This View")).isTicked)
    #expect(try #require(menu.item("Hold This View")).command == .release)
    // Ways out from here, and no promise about their keys, which do something else now.
    for title in ["Pause Arbor", "Float All Windows"] {
      let item = try #require(menu.item(title), "\(title)")
      #expect(item.isEnabled, "\(title)")
      #expect(item.shortcut == nil, "\(title)")
    }
    #expect(try #require(menu.item("Quit Arbor")).isEnabled)

    s.h.system.setMinimized(s.keynote, true)
    #expect(s.h.controller.menuModel().sections[0].items.first?.title == "The view is held: nothing is in it")
    s.h.run("release")
    let after = s.h.controller.menuModel()
    #expect(after.item("Release") == nil)
    #expect(try #require(after.item("Pause Arbor")).shortcut != nil)
    #expect(try #require(after.item("Show Everything")).isEnabled)
  }

  /// The menu's own rule, on a held view: what is not greyed out works.
  @Test func whatCanBeChosenOnAHeldViewDoesNotFail() throws {
    let s = stage()
    s.h.run("hold")
    let menu = s.h.controller.menuModel()
    for item in menu.allItems where item.isEnabled {
      guard let command = item.command else { continue }
      // Each on a stage of its own: some of them end the hold.
      let fresh = stage()
      fresh.h.run("hold")
      let result = fresh.h.controller.perform(command, from: .menu)
      #expect(result.ok, "\(item.title): \(result.message)")
    }
    #expect(try #require(menu.item("Float Focused Window")).isEnabled == false, "the only window in view cannot be taken out of it")
    for title in ["About Arbor", "Show Log", "Settings File…"] {
      #expect(try #require(menu.item(title), "\(title)").isEnabled == false, "\(title) opens a window over what is being shown")
    }
    #expect(try #require(menu.item("Quit Arbor")).isEnabled)
  }

  /// Found on the frozen trunk. The minimap draws the whole arrangement, what is out of view with it.
  @Test(arguments: ["hold", "hold still"]) func aMinimapThatIsUpComesDownWhenAHoldBegins(text: String) {
    let s = stage()
    s.h.run("minimap")
    #expect(s.h.overlays.minimaps[s.h.display] != nil)
    s.h.run(text)
    #expect(s.h.overlays.minimaps[s.h.display] == nil)
  }

  /// ⌃⌥N puts a field in the middle of the display.
  @Test func theFieldForANameIsClosedWhenTheViewIsHeld() {
    let s = stage()
    s.h.run("ask-name")
    #expect(s.h.overlays.scenes[s.h.display]?.namePrompt != nil)
    s.h.run("hold", from: .menu)
    #expect(s.h.overlays.scenes[s.h.display]?.namePrompt == nil)
  }

  @Test func soDoesItWhenACallBegins() {
    let s = stage()
    s.h.run("minimap")
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.overlays.minimaps[s.h.display] == nil)
  }

  /// A menu item that only beeps is a riddle.
  @Test func withNothingInViewHoldThisViewIsGrey() throws {
    let h = Harness()
    h.start()
    #expect(try #require(h.controller.menuModel().item("Hold This View")).isEnabled == false)
    #expect(try #require(h.controller.menuModel().item("Hold Still")).isEnabled)
    h.system.open(app: "Notes")
    #expect(try #require(h.controller.menuModel().item("Hold This View")).isEnabled)
  }

  /// State 5. Nothing is grey: the person's own commands work.
  @Test func theMenuWhileHoldingStill() throws {
    let s = stage()
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    let menu = s.h.controller.menuModel()
    #expect(menu.sections[0].items.map(\.title) == ["Holding still while the camera is on", "Release"])
    #expect(try #require(menu.item("Hold Still")).isTicked)
    #expect(try #require(menu.item("Show Everything")).isEnabled)
    #expect(try #require(menu.item("Pause Arbor")).shortcut != nil)
    #expect(try #require(menu.item("Release")).shortcut == nil, "here that key pauses")
  }

  /// Every button in the menu bar moves the view. With the menu closed a lock says why none is there, and opens the menu.
  @Test func theMenuBarItemIsALockWhileTheViewIsHeld() {
    let s = stage()
    #expect(!s.h.controller.menuBarModel().buttons.isEmpty)
    s.h.run("hold")
    #expect(s.h.controller.menuBarModel().buttons.isEmpty)
    #expect(s.h.controller.menuBarModel().icon == .held)
    #expect(s.h.run("menu-bar").message == "a single icon that opens the menu: the view is held")
    s.h.run("hold still")
    #expect(!s.h.controller.menuBarModel().buttons.isEmpty, "they work as ever")
    s.h.run("release")
    #expect(s.h.controller.menuBarModel().icon == MenuBarModel.Icon())

    let plain = stage { $0.menuBarControls = false }
    plain.h.run("hold still")
    #expect(plain.h.controller.menuBarModel().icon == .holdingStill)
    plain.h.run("hold")
    #expect(plain.h.controller.menuBarModel().icon == .held)
  }

  /// They go to different places in the menu (docs/MENU.md).
  @Test func theStateAndTheRowsCanBeHadApart() {
    let s = stage()
    #expect(s.h.controller.holdState.isEmpty)
    #expect(s.h.controller.holdRows.map(\.title) == ["Hold This View", "Hold Still"])
    s.h.run("hold")
    #expect(s.h.controller.holdState.map(\.title) == ["The view is held: nothing moves it", "Release"])
    #expect(s.h.controller.holdRows.map(\.isOn) == [true, false])
    #expect(s.h.controller.holdMenu == s.h.controller.holdState + s.h.controller.holdRows)
  }

  @Test func theTwoMenuItemsSayWhatTheyDo() {
    let help = stage().h.controller.holdMenu.map(\.help)
    #expect(help.count == 2)
    #expect(help[0] == "Nothing moves the view, not even your own keys. For a shared screen.")
    #expect(help[1] == "Arbor moves nothing by itself; your keys, gestures and ⌘Tab still work. Starts by itself during calls.")
  }

  @Test func whatOthersAskBeforePuttingSomethingOfArborsOnScreen() {
    let s = stage()
    #expect(s.h.controller.mayShowUnasked && s.h.controller.mayShowPanels)
    s.h.run("hold still")
    #expect(!s.h.controller.mayShowUnasked, "nothing by itself during a call")
    #expect(s.h.controller.mayShowPanels, "what the person asks for, yes")
    s.h.run("hold")
    #expect(!s.h.controller.mayShowUnasked && !s.h.controller.mayShowPanels)
    s.h.run("release")
    #expect(s.h.controller.mayShowUnasked && s.h.controller.mayShowPanels)
  }

  @Test func observersHearWhenTheHoldChangesAndOnlyThen() {
    let s = stage()
    var changes = 0
    s.h.controller.observe { if $0 == .hold { changes += 1 } }
    s.h.run("hold")
    #expect(changes == 1)
    s.h.run("hold 5")
    #expect(changes == 1, "held as before")
    s.h.run("hold still")
    #expect(changes == 2)
    s.h.system.open(app: "Zoom", bundleID: zoom, title: "Zoom Meeting")
    #expect(changes == 2, "holding still already")
    s.h.run("release")
    #expect(changes == 2, "and still, for the call")
    s.h.run("release")
    #expect(changes == 3)
  }

  @Test func holdNeedsArborRunning() {
    let s = stage()
    s.h.run("pause")
    #expect(!s.h.run("hold").ok)
    #expect(!s.h.run("release").ok)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func urlsCanNeitherHoldNorRelease() {
    let s = stage()
    for url in ["arbor://hold", "arbor://hold/still", "arbor://release", "arbor://toggle-hold"] {
      guard case .failure = s.h.controller.admit(url: url) else {
        Issue.record("\(url) was admitted")
        continue
      }
    }
  }
}
