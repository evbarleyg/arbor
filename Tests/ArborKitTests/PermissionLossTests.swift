import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Accessibility permission taken away while Arbor runs (docs/features/F63-permission-taken-away.md).
@Suite @MainActor struct PermissionLossTests {
  /// [Safari | Desktop | Mail / Notes] with Slack floating on the Desktop. Framed on Notes unless `framed` is
  /// false: Safari, Mail and Slack are then out of view.
  func makeHarness(framed: Bool = true, settings: Settings = .withGestures)  // whose taps go with the permission
    -> (Harness, safari: WindowID, mail: WindowID, notes: WindowID, slack: WindowID)
  {
    let h = Harness(settings: settings)
    h.watchAccessibility()
    let safari = h.system.open(app: "Safari")
    let mail = h.system.open(app: "Mail")
    let notes = h.system.open(app: "Notes")
    let slack = h.system.open(app: "Slack")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) bottom")
    if framed { h.run("zoom \(notes.rawValue)") }
    return (h, safari, mail, notes, slack)
  }

  var sentence: String {
    "Arbor's Accessibility permission was taken away, so it cannot move windows. 3 windows (Mail, Safari and Slack) are out "
      + "of view and come back as soon as it is granted again: System Settings → Privacy & Security → Accessibility"
  }

  // MARK: Noticing

  @Test func itIsNoticedWithinThreeSecondsWithoutAnybodyDoingAnything() {
    let (h, _, _, _, _) = makeHarness()
    h.scheduler.advance(by: 10)
    #expect(h.controller.isRunning, "nothing happens while the answer is yes")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning)
    #expect(!h.controller.accessibilityGranted)
    #expect(h.controller.permissionLoss?.windows == 3)
  }

  /// Arbor's probe can be ahead of macOS's own flag. The welcome window that opens because the permission went must not show a tick
  /// under a menu that says it is missing, and it says how many windows wait for it.
  @Test func theWelcomeWindowGoesByArborsWordAsWellAsByTheFlag() throws {
    let (h, _, _, _, _) = makeHarness()
    // The flag still says yes.
    h.controller.systemFacts = { SystemFacts(accessibility: true, screenRecording: false, switches: []) }
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin(on: .firstSteps)
    #expect(session.model.page == .firstSteps && session.model.row(.accessibility)?.state == .done)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    session.refresh()
    #expect(session.model.page == .permissions, "there is nothing to try without it")
    let row = try #require(session.model.row(.accessibility))
    #expect(row.state == .required)
    #expect(row.detail.hasPrefix("3 windows are out of view, not closed. Grant the permission again to get them back."))
    #expect(h.controller.menuModel().item("Check Setup…") != nil)
    h.grantAccessibility()
    h.scheduler.advance(by: 3)
    session.refresh()
    #expect(session.model.row(.accessibility)?.state == .done)
    #expect(session.model.row(.accessibility)?.detail.isEmpty == true)
  }

  @Test func oneNoFollowedByYesChangesNothingAtAll() {
    let (h, _, _, _, _) = makeHarness()
    var changes = 0
    h.controller.observe { _ in changes += 1 }
    let moves = h.system.frameLog.count
    let before = h.workspace
    h.revokeAccessibility()
    h.scheduler.advance(by: 2)  // the question that is due, and no more
    h.grantAccessibility()
    h.scheduler.advance(by: 10)
    #expect(h.controller.isRunning && h.controller.accessibilityGranted)
    #expect(changes == 0)
    #expect(h.system.frameLog.count == moves && h.system.deniedCalls == 0)
    #expect(h.workspace == before)
  }

  @Test func aCommandGivenAfterwardsFailsTheFirstTimeAndMovesNothing() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    let result = h.run("show-all")
    #expect(!result.ok)
    #expect(result.message == sentence)
    #expect(h.system.deniedCalls == 0, "it did not even try")
    #expect(!h.controller.isRunning)
  }

  /// Holding ⌃⌥Space peeks without going through `perform`. It is the key a person who misses a window presses.
  @Test func theShowEverythingKeyPressedAfterwardsFailsTheFirstTimeTooInsteadOfPeeking() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    let result = h.keyDown("ctrl+opt+space")
    #expect(result?.ok == false)
    #expect(result?.message == sentence, "counted before anything pretended to bring them into view")
    #expect(h.system.deniedCalls == 0, "it did not even try")
    #expect(!h.controller.isPeeking && !h.scheduler.pendingKeys.contains("peek"))
    h.keyUp("ctrl+opt+space")
    #expect(h.controller.permissionLoss?.windows == 3)
  }

  @Test func aPeekInProgressEndsWithTheLoss() {
    let (h, _, _, _, _) = makeHarness()
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.controller.isPeeking)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning)
    #expect(!h.controller.isPeeking && !h.scheduler.pendingKeys.contains("peek") && h.controller.temporaryShortcuts.isEmpty)
    #expect(h.controller.permissionLoss?.windows == 0, "everything was in view")
    let moves = h.system.frameLog.count
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.count == moves && h.system.deniedCalls == 0)
    h.grantAccessibility()
    h.scheduler.advance(by: 2)
    #expect(h.controller.isRunning && !h.controller.isPeeking)
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A held shortcut, the steps of a pinch: the thorough question costs a visit to the window server each time.
  @Test func commandsInQuickSuccessionAskThoroughlyOnceASecondAndOtherwiseReadTheFlag() {
    let (h, _, _, _, _) = makeHarness()
    h.scheduler.advance(by: 11.5)  // the timer asked a second and a half ago
    let before = h.system.questions
    for _ in 0..<30 { h.run("in") }
    #expect(h.system.questions.thorough - before.thorough == 1)
    #expect(h.system.questions.byTheFlag - before.byTheFlag == 29)
    h.scheduler.advance(by: 1)
    let later = h.system.questions.thorough
    h.run("out")
    #expect(h.system.questions.thorough == later + 1, "a second later it is asked thoroughly again")
  }

  @Test func theFlagAloneIsEnoughForANo() {
    let (h, _, _, _, _) = makeHarness()
    h.run("relayout")
    h.revokeAccessibility()
    let thorough = h.system.questions.thorough
    #expect(h.run("show-all").message == sentence)
    #expect(h.system.questions.thorough == thorough && h.system.deniedCalls == 0)
  }

  /// Removed from the list with the − button: the flag can go on saying yes.
  @Test func ifTheFlagLagsTheRefusedCallsTellTheTruthAndTheyAreBelievedThoroughly() {
    let (h, _, _, _, _) = makeHarness()
    h.run("relayout")
    h.system.flagLags = true
    h.revokeAccessibility()
    h.run("show-all")
    #expect(h.system.deniedCalls > 0, "it tried, within the second in which it trusts the flag")
    h.scheduler.advance(by: 0)
    #expect(!h.controller.isRunning && !h.controller.accessibilityGranted)
    // And while it is gone the flag's yes brings nothing back.
    let result = h.run("show-all")
    #expect(!result.ok && !h.controller.isRunning)
    h.scheduler.advance(by: 5)
    #expect(!h.controller.isRunning)
  }

  @Test func theTimersQuestionIsAlwaysThorough() {
    let (h, _, _, _, _) = makeHarness()
    h.system.flagLags = true
    h.scheduler.advance(by: 1.9)
    h.run("relayout")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning, "a command just before does not make the timer content with the flag")
  }

  /// Stopping without moving is for the stop alone.
  @Test func afterwardsWindowsAreLetGoOfAsEver() {
    let (h, safari, mail, notes, slack) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 10)
    h.grantAccessibility()
    h.scheduler.advance(by: 2)
    h.run("zoom \(notes.rawValue)")
    #expect(!h.system.isVisible(safari))
    #expect(h.run("float-all").ok)
    for window in [safari, mail, notes, slack] { #expect(h.system.isVisible(window), "\(window)") }
  }

  /// So a replay need not know about permissions: what it is given ends where Arbor stopped looking (docs/TRACES.md).
  @Test func aTraceBeingRecordedEndsWithTheLoss() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("trace on loss").ok)
    #expect(h.recorder.isRecording)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning && !h.recorder.isRecording)
  }

  @Test func theTapsWatchdogCountsAsASecondOpinion() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.controller.askAboutAccessibility(beyondDoubt: true)
    #expect(!h.controller.accessibilityGranted)
    // And if the watchdog was wrong, macOS's "yes" stands.
    let (other, _, _, _, _) = makeHarness()
    other.controller.askAboutAccessibility(beyondDoubt: true)
    #expect(other.controller.isRunning)
  }

  /// Not everything that moves windows is a command: a drop, a window that closes, a gap that is dragged.
  @Test func aRefusedCallIsASecondOpinionTooAndIsActedOnOnceTheCallerHasReturned() {
    let (h, _, _, _, slack) = makeHarness(framed: false)
    h.revokeAccessibility()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(slack, through: [CGPoint(x: 700, y: 400), CGPoint(x: 400, y: 400), CGPoint(x: 2, y: 400)])
    #expect(h.system.deniedCalls > 0, "it tried, as it had no way of knowing")
    #expect(h.controller.isRunning, "and finished what it was doing")
    h.scheduler.advance(by: 0)
    #expect(!h.controller.isRunning && !h.controller.accessibilityGranted)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    let tried = h.system.deniedCalls
    h.scheduler.advance(by: 30)
    #expect(h.system.deniedCalls == tried)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isDocked(slack), "what was asked for while nobody knew is done when it can be")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aRefusalThatMacOSDoesNotConfirmChangesNothing() {
    let (h, _, _, _, _) = makeHarness()
    h.controller.accessibilityWasRefused()
    h.scheduler.advance(by: 0)
    #expect(h.controller.isRunning)
  }

  @Test func queriesDoNotAskAndDoNotLie() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    #expect(h.run("status").message.hasPrefix("running"), "nobody has asked yet")
    h.scheduler.advance(by: 3)
    #expect(h.run("status").message == sentence)
    #expect(h.run("help").ok && h.run("bindings").ok && h.run("rules").ok)
    let state = h.run("state").state!
    #expect(!state.accessibility && !state.running)
    #expect(state.windows.isEmpty && state.displays[0].windowFrames.isEmpty, "no stale frames")
    #expect(state.displays[0].tree.allWindows.count == 3, "the arrangement that will come back is still listed")
  }

  @Test func withoutAProbeNobodyAsks() {
    let h = Harness()
    h.start()
    #expect(!h.scheduler.pendingKeys.contains("accessibility"))
    h.revokeAccessibility()
    h.controller.askAboutAccessibility(beyondDoubt: true)
    #expect(h.controller.isRunning)
  }

  /// Until the first start the app waits for the first grant by itself.
  @Test func beforeTheFirstStartNobodyAsks() {
    let h = Harness()
    h.watchAccessibility()
    h.controller.accessibilityGranted = false
    h.revokeAccessibility()
    h.controller.askAboutAccessibility(beyondDoubt: true)
    #expect(h.controller.permissionLoss == nil)
    #expect(h.run("show-all").message.hasPrefix("waiting for Accessibility permission"))
    h.grantAccessibility()
    #expect(!h.run("show-all").ok, "and nothing starts behind the app's back")
    #expect(!h.controller.isRunning)
  }

  // MARK: Stopping

  @Test func nothingIsMovedAndEveryOverlayGoes() {
    let (h, safari, _, _, _) = makeHarness()
    let where_ = h.frame(safari)
    let moves = h.system.frameLog.count
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.system.frameLog.count == moves && h.system.deniedCalls == 0)
    #expect(h.frame(safari) == where_, "still out of view: Arbor cannot help it")
    #expect(h.overlays.scenes.isEmpty && h.overlays.preview == nil)
    #expect(!h.system.started, "it has stopped observing")
  }

  @Test func whileItIsGoneArborReactsToNothing() {
    let (h, safari, mail, notes, _) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.system.userMove(safari, to: CGRect(x: 40, y: 60, width: 300, height: 200))
    h.system.drag(notes, through: [CGPoint(x: 700, y: 400), CGPoint(x: 2, y: 400)])
    h.system.setMinimized(mail, true)
    h.system.userFocus(safari)
    h.system.close(h.system.open(app: "Keynote"))
    h.system.setDisplays(h.system.displayList)
    h.scheduler.advance(by: 30)
    #expect(h.system.deniedCalls == 0)
    #expect(h.overlays.scenes.isEmpty && h.overlays.preview == nil)
  }

  @Test func aDragInProgressIsForgotten() {
    let (h, _, _, _, slack) = makeHarness(framed: false)
    h.system.mouseDown = true
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.controller.dragBegan(slack, at: CGPoint(x: 700, y: 400))
    h.controller.dragMoved(slack, to: CGPoint(x: 2, y: 400))
    #expect(h.overlays.preview != nil)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.overlays.preview == nil)
    h.controller.dragEnded(slack, at: CGPoint(x: 2, y: 400))
    #expect(h.system.deniedCalls == 0)
  }

  @Test func theArrangementIsSavedAtOnce() {
    let (h, _, _, notes, _) = makeHarness()
    let before = h.workspace
    h.revokeAccessibility()
    h.run("home")
    #expect(h.store.saved?.workspaces[h.display] == before)
    #expect(h.store.saved?.workspaces[h.display]?.camera == before.tree.leaf(containing: notes))
  }

  // MARK: The first minute

  /// The first act with any new build: reset the permission, launch, grant. Until the first `start()` the app waits by
  /// itself (`ArborApp.waitForAccessibility`: a timer on `AXIsProcessTrusted()`, F10's welcome window), as it did before
  /// F63, and nothing here is in its way. Then the switch goes off with windows out of view, and on again.
  @Test func launchedWithoutThePermissionThenGrantedThenRevokedThenGrantedAgain() {
    let h = Harness()
    h.watchAccessibility()
    let safari = h.system.open(app: "Safari"), mail = h.system.open(app: "Mail")
    let before = [safari, mail].map { h.system.frame(of: $0) }
    // Launched without: what `applicationDidFinishLaunching` does.
    h.revokeAccessibility()
    h.controller.accessibilityGranted = false
    h.scheduler.advance(by: 30)
    #expect(h.system.questions.thorough == 0 && h.system.questions.byTheFlag == 0, "the controller does not watch yet")
    #expect(h.controller.permissionLoss == nil && !h.controller.isInBusiness && h.controller.activeBindings.isEmpty)
    #expect(h.run("status").message.hasPrefix("waiting for Accessibility permission"))
    #expect(h.controller.menuModel().sections.first?.items.map(\.title) == ["Arbor needs Accessibility permission", "Check Setup…"])
    #expect(h.controller.quitTitle == "Quit Arbor")
    let refused = h.run("show-all")
    #expect(!refused.ok && refused.message.hasPrefix("waiting for Accessibility permission"), "\(refused.message)")
    h.controller.accessibilityWasRefused()
    h.scheduler.advance(by: 5)
    #expect(h.system.questions.thorough == 0 && h.controller.permissionLoss == nil, "whatever reaches it meanwhile")

    // Granted: what the app's timer does when the flag turns (`startController`).
    h.grantAccessibility()
    h.controller.accessibilityGranted = true
    h.start()
    #expect(h.controller.isRunning && h.controller.permissionLoss == nil)
    h.scheduler.advance(by: 30)
    #expect(h.controller.isRunning && h.system.questions.thorough > 0, "from now on the controller watches")
    #expect([safari, mail].map { h.system.frame(of: $0) } == before && h.system.frameLog.isEmpty, "nothing moves until asked")
    #expect(h.controller.activeBindings == h.controller.effectiveBindings.bindings)

    // Revoked with a window out of view, and granted again.
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning && h.controller.permissionLoss?.windows == 1)
    #expect(h.run("status").message.hasPrefix("Arbor's Accessibility permission was taken away"))
    h.scheduler.advance(by: 5)
    h.grantAccessibility()
    h.scheduler.advance(by: 2)
    #expect(h.controller.isRunning && h.controller.permissionLoss == nil)
    for window in [safari, mail] { #expect(h.system.isVisible(window)) }
    expectWindowsMatchLayout(h)
  }

  /// Nobody has seen whether macOS lets a process make an event tap that was given the permission while it ran. If not, the taps
  /// stay away until the next launch, as before F63, and Arbor arranges windows all the same.
  @Test func ifMacOSRefusesTapsFromTheFirstMinuteArborBelievesTheFlagAndGoesOn() {
    let h = Harness()
    h.watchAccessibility()
    h.system.refusesTaps = true
    let safari = h.system.open(app: "Safari")
    h.start()
    h.scheduler.advance(by: 30)
    h.controller.askAboutAccessibility(beyondDoubt: true)  // the taps' watchdog, which found that it may not make one
    #expect(h.controller.isRunning && h.controller.permissionLoss == nil)
    #expect(h.run("dock \(safari.rawValue) left").ok)
    // The switch is still noticed, by the flag.
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning && h.controller.permissionLoss != nil)
    h.grantAccessibility()
    h.scheduler.advance(by: 2)
    #expect(h.controller.isRunning)
  }

  /// Removed from the list with the − button, the flag goes on saying yes. That is what the thorough way is for.
  @Test func onceTheThoroughWayHasWorkedItsNoIsBelievedAgainstTheFlag() {
    let (h, _, _, _, _) = makeHarness()
    h.scheduler.advance(by: 5)
    h.system.flagLags = true
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning && h.controller.permissionLoss != nil)
  }

  // MARK: Saying so

  @Test func theSentenceCountsWindowsAndNamesAppsNeverTitles() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    #expect(h.run("arrange").message == sentence)
    for title in ["Safari 101", "Mail 102", "Slack 104"] { #expect(!sentence.contains(title)) }
    #expect(
      h.controller.permissionMenuLines == [
        "Arbor’s Accessibility permission was taken away, so it cannot move windows",
        "3 windows (Mail, Safari and Slack) are out of view",
        "They come back as soon as you grant it again",
      ])
    #expect(h.controller.quitTitle == "Quit Arbor (3 windows stay out of view)")
  }

  /// State 1 in docs/MENU.md. The menu is a model since F10; this is the whole of it while the permission is missing.
  @Test func theMenuSaysWhatHappenedLeadsToTheSetupAndItsQuitSaysWhatQuittingLeavesBehind() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(
      h.controller.menuModel().sections.map { $0.items.map(\.title) } == [
        [
          "Arbor’s Accessibility permission was taken away, so it cannot move windows",
          "3 windows (Mail, Safari and Slack) are out of view",
          "They come back as soon as you grant it again",
          "Check Setup…",
        ],
        ["Settings…", "Help"],
        ["Quit Arbor (3 windows stay out of view)"],
      ])
    #expect(h.controller.menuBarModel().icon == .needsPermission)
    h.grantAccessibility()
    h.scheduler.advance(by: 2)
    #expect(h.controller.menuModel().item("Quit Arbor") != nil)
    #expect(h.controller.menuModel().item("Check Setup…")?.isEnabled != nil)
    #expect(h.controller.menuBarModel().icon != .needsPermission)
  }

  @Test func theWelcomeWindowCountsTheWindowsThatAreOutOfView() {
    let (h, _, _, _, _) = makeHarness()
    let facts = SystemFacts(accessibility: false, screenRecording: false, switches: [])
    #expect(h.controller.onboardingModel(facts).title == "Welcome to Arbor")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.onboardingModel(facts).title == "Arbor needs its permission back")
  }

  @Test func withNothingOutOfViewItLeavesThemOut() {
    let (h, _, _, _, _) = makeHarness(framed: false)
    h.revokeAccessibility()
    #expect(
      h.run("arrange").message
        == "Arbor's Accessibility permission was taken away, so it cannot move windows. Grant it again under "
        + "System Settings → Privacy & Security → Accessibility")
    #expect(h.controller.permissionMenuLines == ["Arbor’s Accessibility permission was taken away, so it cannot move windows"])
    #expect(h.controller.quitTitle == "Quit Arbor")
  }

  @Test func oneWindowAndManyAppsReadWell() {
    let h = Harness()
    h.watchAccessibility()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.revokeAccessibility()
    #expect(h.run("home").message.contains("1 window (Mail) is out of view and comes back as soon as"))
    #expect(h.controller.permissionMenuLines.last == "It comes back as soon as you grant it again")
    #expect(h.controller.quitTitle == "Quit Arbor (1 window stays out of view)")

    let many = Harness()
    many.watchAccessibility()
    let first = many.system.open(app: "Zed")
    for app in ["Mail", "Notes", "Safari", "Slack", "Music", "Mail"] { many.system.open(app: app) }
    many.start()
    many.run("arrange")
    many.run("zoom \(first.rawValue)")
    many.revokeAccessibility()
    #expect(many.run("home").message.contains("6 windows (Mail, Music, Notes and 2 other apps) are out of view"))
  }

  @Test func whileAllIsWellThereIsNothingToSay() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.controller.permissionLoss == nil)
    #expect(h.controller.permissionMenuLines.isEmpty)
    #expect(h.controller.quitTitle == "Quit Arbor")
  }

  @Test func observersHearOfBothEnds() {
    let (h, _, _, _, _) = makeHarness()
    var seen: [Bool] = []
    h.controller.observe { [weak controller = h.controller] change in
      if change == .lifecycle, let controller { seen.append(controller.accessibilityGranted) }
    }
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(seen == [false, true])
  }

  @Test func arborSpeaksUpByItselfOnceAndOnlyIfWindowsAreOutOfView() {
    let (h, _, _, notes, _) = makeHarness()
    var requests = 0
    h.controller.askForAccessibility = { requests += 1 }
    h.revokeAccessibility()
    h.scheduler.advance(by: 30)
    h.run("home")
    h.run("show-all")
    #expect(requests == 1)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(requests == 1)
    h.run("zoom \(notes.rawValue)")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(requests == 2, "a new loss is a new occasion")

    let (quiet, _, _, _, _) = makeHarness(framed: false)
    quiet.controller.askForAccessibility = { requests += 100 }
    quiet.revokeAccessibility()
    quiet.scheduler.advance(by: 30)
    #expect(requests == 2, "whoever switched Arbor off on purpose is not nagged")
  }

  @Test func theAppFollowsTheControllerFromTheFirstStartUntilItQuits() {
    let h = Harness()
    h.watchAccessibility()
    #expect(!h.controller.isInBusiness)
    h.start()
    #expect(h.controller.isInBusiness)
    h.run("pause")
    #expect(h.controller.isInBusiness)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.isInBusiness)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    h.controller.shutdown()
    #expect(!h.controller.isInBusiness)
  }

  // MARK: Keys and taps

  @Test func withWindowsOutOfViewOnlyTheWaysHomeAreHeld() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(
      h.controller.activeBindings.map(\.command.text).sorted() == ["float-all", "home", "show-all", "toggle-pause"])
    #expect(!h.controller.inputSettings.gesturesEnabled)
    #expect(h.controller.inputSettings.frameRectangleModifier == "none")
    #expect(h.run("bindings").message.hasSuffix(", all but 4 off without Accessibility permission"))
    for binding in h.controller.activeBindings {
      let result = h.controller.perform(binding.command)
      #expect(!result.ok && result.message == sentence, "\(binding.command.text)")
    }
  }

  @Test func withNothingOutOfViewNoShortcutIsHeld() {
    let (h, _, _, _, _) = makeHarness(framed: false)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.activeBindings.isEmpty)
    #expect(!h.controller.inputSettings.gesturesEnabled)
    #expect(h.run("bindings").message.hasSuffix(", all off without Accessibility permission"))
  }

  @Test func everythingIsHeldAgainAfterwards() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.activeBindings == KeyBindings.defaults)
    #expect(h.controller.inputSettings == h.controller.settings)
  }

  // MARK: Recovering

  @Test func itComesBackWithinASecondWithEverythingInViewAndTheOldViewOneBackAway() {
    let (h, safari, mail, notes, slack) = makeHarness()
    let before = h.workspace
    h.revokeAccessibility()
    h.scheduler.advance(by: 20)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)

    #expect(h.controller.isRunning && h.controller.accessibilityGranted)
    #expect(h.controller.permissionLoss == nil)
    #expect(h.workspace.tree == before.tree && h.workspace.savedViews == before.savedViews)
    for window in [safari, mail, notes, slack] { #expect(h.system.isVisible(window), "\(window) is in view") }
    #expect(h.workspace.camera == h.workspace.tree.root)
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == before.camera, "the view it had")
    #expect(h.run("back").ok, "and the history before that")
  }

  /// A false alarm that survives two questions is over at the next one, a second later. Nobody read a promise.
  @Test func aLossThatIsOverInAMomentLeavesTheViewAsItWas() {
    let (h, safari, _, notes, _) = makeHarness()
    let before = h.workspace
    let frame = h.frame(notes)
    h.revokeAccessibility()
    h.controller.askAboutAccessibility(beyondDoubt: true)
    #expect(!h.controller.isRunning)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning)
    #expect(h.workspace == before)
    #expect(h.frame(notes) == frame && !h.system.isVisible(safari))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func howeverShortTheLossTheFocusedWindowIsInViewAfterwards() {
    let (h, safari, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.controller.askAboutAccessibility(beyondDoubt: true)
    h.system.events = nil
    h.system.userFocus(safari)
    h.system.events = h.controller
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(safari), "it has the keyboard")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theFirstSentenceIsTheSameInRepliesAndInTheMenu() {
    let (h, _, _, _, _) = makeHarness()
    h.revokeAccessibility()
    let first = h.run("home").message.components(separatedBy: ". ")[0]
    #expect(h.run("status").message.hasPrefix(first + ". "))
    #expect(h.controller.permissionMenuLines[0].replacingOccurrences(of: "’", with: "'") == first)
  }

  @Test func theWaysHomeLeadToTheSettingsAtMostOnceInTenSeconds() {
    let (h, _, _, _, _) = makeHarness()
    #expect(!h.controller.shouldOpenAccessibilitySettings(), "nothing is wrong")
    h.revokeAccessibility()
    h.run("show-all")
    #expect(h.controller.shouldOpenAccessibilitySettings())
    for _ in 0..<20 {
      h.run("show-all")
      #expect(!h.controller.shouldOpenAccessibilitySettings(), "hammering")
    }
    h.scheduler.advance(by: 9)
    #expect(!h.controller.shouldOpenAccessibilitySettings())
    h.scheduler.advance(by: 1)
    #expect(h.controller.shouldOpenAccessibilitySettings())
    // A new loss is a new occasion, however soon.
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(!h.controller.shouldOpenAccessibilitySettings())
    h.revokeAccessibility()
    h.run("show-all")
    #expect(h.controller.shouldOpenAccessibilitySettings())
  }

  @Test func withNothingOutOfViewTheViewIsAsItWas() {
    let (h, safari, _, _, _) = makeHarness(framed: false)
    h.run("save-view 3")
    let before = h.workspace
    let frame = h.frame(safari)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.workspace == before)
    #expect(h.frame(safari) == frame)
  }

  @Test func aCommandGivenAfterItIsBackRunsAtOnce() {
    let (h, safari, _, _, _) = makeHarness()
    h.revokeAccessibility()
    h.run("home")
    h.grantAccessibility()
    #expect(h.run("zoom \(safari.rawValue)").ok)
    #expect(h.system.isVisible(safari))
  }

  @Test func itCopesWithWhatChangedMeanwhile() {
    let (h, safari, mail, notes, _) = makeHarness()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    // Nobody reports anything: the observers are gone.
    h.system.events = nil
    h.system.close(mail)
    let keynote = h.system.open(app: "Keynote")
    h.system.userMove(notes, to: CGRect(x: 40, y: 60, width: 300, height: 200))
    h.system.events = h.controller
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(!h.workspace.contains(mail))
    #expect(h.workspace.isFloating(keynote))
    #expect(h.workspace.isDocked(safari) && h.workspace.isDocked(notes))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func twoDisplaysBothShowEverythingAfterwards() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1440, height: 875), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.watchAccessibility()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let c = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 200, width: 500, height: 400))
    let d = h.system.open(app: "Slack", frame: CGRect(x: 2000, y: 200, width: 500, height: 400))
    h.start()
    h.run("arrange all")
    h.run("zoom \(a.rawValue)")
    h.run("zoom \(c.rawValue)")
    h.revokeAccessibility()
    #expect(h.run("home").message.contains("2 windows (Mail and Slack)"))
    h.scheduler.advance(by: 20)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    for window in [a, b, c, d] { #expect(h.system.isVisible(window), "\(window)") }
  }

  @Test func losingItAgainAndAgainIsHarmless() {
    let (h, safari, _, notes, _) = makeHarness()
    let tree = h.workspace.tree
    for _ in 0..<3 {
      h.run("zoom \(notes.rawValue)")
      h.revokeAccessibility()
      h.scheduler.advance(by: 3)
      h.controller.askAboutAccessibility(beyondDoubt: true)
      h.scheduler.advance(by: 5)
      #expect(h.controller.permissionLoss?.windows == 3)
      h.grantAccessibility()
      h.scheduler.advance(by: 1)
      h.controller.askAboutAccessibility(beyondDoubt: true)
      #expect(h.controller.isRunning)
      #expect(h.workspace.tree == tree)
      #expect(h.system.isVisible(safari))
    }
    #expect(h.system.deniedCalls == 0)
  }

  // MARK: Pauses

  @Test func aPauseEndsWithTheLossAndDoesNotComeBack() {
    let (h, _, _, _, _) = makeHarness()
    let before = h.workspace
    h.run("pause")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isPaused && !h.controller.isRunning)
    #expect(h.controller.permissionLoss?.windows == 0, "a pause had brought everything into view")
    #expect(h.run("resume").message.hasPrefix("Arbor's Accessibility permission was taken away"))
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning && !h.controller.isPaused)
    #expect(h.workspace == before, "the arrangement and the view the pause had kept")
  }

  @Test func aTimedPauseDoesNotResumeIntoTheLoss() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause 1")
    h.revokeAccessibility()
    h.scheduler.advance(by: 120)
    #expect(!h.controller.isRunning && !h.controller.isPaused)
    #expect(h.system.deniedCalls == 0)
  }

  @Test func aPauseForAnAppEndsTooAndBeginsAgainAfterwardsIfTheAppIsStillInFront() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.slack"]
    let (h, _, _, _, slack) = makeHarness(framed: false, settings: settings)
    h.system.userFocus(slack)
    #expect(h.controller.isPausedForApp)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isPaused && !h.controller.isPausedForApp)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.accessibilityGranted)
    #expect(h.controller.isPausedForApp)
  }

  // MARK: Quitting

  @Test func quittingWithoutItIsSafeAndTheNextLaunchBringsTheWindowsBack() {
    let (h, safari, mail, notes, slack) = makeHarness()
    let tree = h.workspace.tree
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.controller.shutdown()
    #expect(h.system.deniedCalls == 0)
    #expect(!h.system.isVisible(safari), "left where it was")

    // The next launch, with the permission, over the same windows.
    h.grantAccessibility()
    let next = Controller(
      system: h.system, overlays: h.overlays, store: h.store, scheduler: h.scheduler, filter: WindowFilter(ownPID: 1))
    next.start()
    #expect(next.workspaces[h.display]?.tree == tree)
    _ = next.perform(.home)
    for window in [safari, mail, notes, slack] { #expect(h.system.isVisible(window), "\(window)") }
  }
}
