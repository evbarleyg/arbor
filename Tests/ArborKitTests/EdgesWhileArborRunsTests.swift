import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What Arbor switched off in macOS for somebody is off only while Arbor runs (rule 5: leave things as you found them). It goes back at a
/// quit and at a pause, and whenever Arbor may not arrange windows; it goes off again at the next start, because the choice was made once.
/// Only the switches Arbor changed, and only while they stand as Arbor left them. So back to normal is one thing: Quit.
@Suite @MainActor struct EdgesWhileArborRunsTests {
  static let tiling: [MacSwitch] = [.screenEdges, .menuBar, .optionKey]
  static let asAMacComes: [MacSwitch] = [.clickWallpaper, .screenEdges, .menuBar, .optionKey]
  static let off: [MacSwitch: Bool] = [.screenEdges: false, .menuBar: false, .optionKey: false]

  func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven) -> Harness {
    let h = Harness(settings: settings)
    follow(h)
    return h
  }

  func follow(_ h: Harness) {
    h.controller.systemFacts = { [unowned h] in
      SystemFacts(accessibility: h.controller.accessibilityGranted, screenRecording: false, switches: h.mac.on, inputSources: 1)
    }
  }

  func model(_ h: Harness) throws -> OnboardingModel {
    let facts = try #require(h.controller.systemFacts?())
    return h.controller.onboardingModel(facts)
  }

  func tilingRow(_ h: Harness) throws -> OnboardingModel.Row {
    let model = try model(h)
    return try #require(model.row(.desktopAndDock))
  }

  func records(givenBack: Bool, stored: [MacSwitch: Bool] = [:]) -> [MacSwitchRecord] {
    Self.tiling.map { MacSwitchRecord($0, stored: stored[$0], isGivenBack: givenBack) }
  }

  @Test func aQuitLeavesTheMacAsItWasFoundAndTheNextStartTakesTheEdgesAgain() {
    let h = makeHarness()
    h.start()
    #expect(h.run("fix-setup").ok)
    #expect(h.mac.values == Self.off)

    h.controller.shutdown()
    #expect(h.mac.values.isEmpty && h.mac.on == Self.asAMacComes, "nothing was stored before, and nothing is now")
    #expect(h.mac.before == records(givenBack: true), "the choice stays on record")

    // Somebody starts Arbor again. Nobody is asked twice.
    h.controller.start()
    #expect(h.mac.values == Self.off)
    #expect(h.mac.before == records(givenBack: false))
  }

  @Test func whatWasStoredBeforeIsWhatComesBack() {
    let h = makeHarness()
    h.mac.values = [.menuBar: false, .optionKey: true]
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()
    #expect(h.mac.values == [.menuBar: false, .optionKey: true], "exactly as it was: one off by its owner's hand, one written down as on")
    h.controller.start()
    #expect(h.mac.values == [.screenEdges: false, .menuBar: false, .optionKey: false])
    #expect(h.mac.before.map(\.item) == [.screenEdges, .optionKey], "the one its owner switched off is none of Arbor's")
  }

  /// A pause is a quit that comes back.
  @Test func aPauseGivesThemBackAndResumingTakesThemAgain() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    #expect(h.run("pause").ok)
    #expect(h.mac.on == Self.asAMacComes)
    #expect(h.run("resume").ok)
    #expect(h.mac.values == Self.off)
    // Quit during a pause: they are back already, and stay back.
    h.run("pause")
    let writes = h.mac.writes.count
    h.controller.shutdown()
    #expect(h.mac.on == Self.asAMacComes && h.mac.writes.count == writes)
  }

  /// The welcome window offers the step before the permission is there. It is a choice, and nothing is touched until Arbor arranges windows.
  @Test func takenBeforeThePermissionItIsNotedAndActedOnWhenArborStarts() throws {
    let h = makeHarness()
    h.controller.accessibilityGranted = false
    let noted = h.run("fix-setup")
    #expect(noted.ok)
    #expect(
      noted.message
        == "noted: Arbor keeps 3 settings of macOS under Desktop & Dock off while it runs. It may not arrange windows now, so nothing has changed "
        + "yet; `fix-setup undo` takes that back")
    #expect(h.mac.writes.isEmpty && h.mac.before == records(givenBack: true))
    let row = try tilingRow(h)
    #expect(row.state == .note && row.action == nil)
    #expect(row.done == "Until Arbor may arrange windows, macOS keeps its tiling. Arbor switches it off when it starts, and only while it runs.")
    #expect(row.undo?.title == "Leave Them On")
    // Whoever quits now has nothing to get back.
    h.controller.shutdown()
    #expect(h.mac.writes.isEmpty)
    // The permission arrives.
    h.controller.accessibilityGranted = true
    h.start()
    #expect(h.mac.values == Self.off && h.mac.before == records(givenBack: false))
  }

  /// Without the permission Arbor docks nothing, so it has no use for the edges. Nobody tells it: it finds out, and finds out again.
  @Test func whileThePermissionIsGoneMacOSHasThemBack() {
    let h = makeHarness()
    h.watchAccessibility()
    h.start()
    h.run("fix-setup")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.isRunning && h.mac.on == Self.asAMacComes)
    h.grantAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.isRunning && h.mac.values == Self.off)
  }

  @Test func aTimedPauseEndsByItselfAndTakesThemAgain() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.run("pause 5")
    #expect(h.mac.on == Self.asAMacComes)
    h.scheduler.advance(by: 301)
    #expect(h.controller.isRunning && h.mac.values == Self.off)
  }

  /// A game Arbor pauses for has the Mac as it comes while it is in front.
  @Test func aPauseForAnAppGivesThemBackToo() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = makeHarness(settings: settings)
    h.start()
    h.run("fix-setup")
    h.system.activate(bundleID: "com.example.game", name: "Game")
    #expect(h.controller.isPaused && h.mac.on == Self.asAMacComes)
    h.system.activate(bundleID: "com.example.safari", name: "Safari")
    #expect(h.controller.isRunning && h.mac.values == Self.off)
  }

  /// Started behind such an app, Arbor takes nothing from it even for a moment.
  @Test func aStartBehindAnAppItPausesForTouchesNothing() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = makeHarness(settings: settings)
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()
    let next = h.newProcess()
    follow(next)
    // The app reports who is in front before it starts the controller.
    next.system.activate(bundleID: "com.example.game", name: "Game")
    let writes = next.mac.writes.count
    next.start()
    #expect(next.controller.isPaused)
    #expect(next.mac.writes.count == writes)
    #expect(next.mac.on == Self.asAMacComes)
  }

  // MARK: Only while they stand as Arbor left them

  @Test func aSwitchSomebodyFlippedWhileArborRanIsTheirs() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    // In System Settings: on again, by hand.
    h.mac.values[.menuBar] = true
    h.controller.shutdown()
    #expect(h.mac.values == [.menuBar: true], "the two that stood as Arbor set them went back; the third was not touched")
    #expect(h.mac.before.map(\.item) == [.screenEdges, .optionKey], "and is forgotten")
    h.controller.start()
    #expect(h.mac.values == [.screenEdges: false, .menuBar: true, .optionKey: false])
  }

  @Test func aSwitchSomebodyFlippedWhileArborWasQuitIsTheirs() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()
    // Off by hand: they want it off, with Arbor and without.
    h.mac.values[.screenEdges] = false
    h.controller.start()
    #expect(h.mac.before.map(\.item) == [.menuBar, .optionKey])
    h.controller.shutdown()
    #expect(h.mac.values == [.screenEdges: false], "Arbor does not switch on what somebody switched off")
  }

  // MARK: Accidents

  /// Arbor ended without quitting: the switches are off still, and the next start knows what it owes.
  @Test func afterACrashTheNextStartKnowsWhatItOwes() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    let next = h.newProcess()
    follow(next)
    #expect(next.mac.values == Self.off && next.mac.before == records(givenBack: false), "as the crash left them")
    next.start()
    #expect(next.mac.values == Self.off)
    next.controller.shutdown()
    #expect(next.mac.values.isEmpty)
  }

  /// It crashed just after a resume, with the pause still in the file. The watchdog's start comes back paused, and a paused Arbor has no use
  /// for them.
  @Test func anArborThatComesBackPausedGivesBackWhatTheCrashLeftOff() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.run("pause")
    // As a crash in the first half second of a resume leaves things: the file says paused, the switches are off and owed.
    h.mac.values = Self.off
    h.mac.before = records(givenBack: false)
    let next = h.newProcess(byTheWatchdog: true)
    follow(next)
    next.start()
    #expect(next.controller.isPaused && !next.controller.isRunning)
    #expect(next.mac.values.isEmpty && next.mac.before == records(givenBack: true))
    #expect(next.run("resume").ok && next.mac.values == Self.off)
  }

  /// A power cut, and at the next launch the permission is gone (a new build). What `ArborApp.waitForAccessibility` does.
  @Test func aLaunchWithoutThePermissionGivesBackWhatIsOwed() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    let next = h.newProcess()
    follow(next)
    next.controller.accessibilityGranted = false
    next.controller.giveMacSwitchesBack()
    #expect(next.mac.values.isEmpty && next.mac.before == records(givenBack: true))
  }

  /// Nothing is ever off that is not written down as owed, wherever Arbor ends.
  @Test func takingThemAgainIsWrittenDownFirst() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()
    // A full disk: what cannot be written down is not changed.
    h.mac.cannotKeep = true
    h.controller.start()
    #expect(h.mac.values.isEmpty)
    #expect(h.mac.before == records(givenBack: true))
    // Arbor runs, and macOS tiles: that is in the way like any, is called so, and the step can be asked for again.
    #expect(h.controller.macSwitchesLent.isEmpty)
    #expect(h.controller.doctorReport().check("Desktop & Dock settings")?.mark == .problem)
    h.mac.cannotKeep = false
    #expect(h.run("fix-setup").ok && h.mac.values == Self.off && h.mac.before == records(givenBack: false))
  }

  @Test func whatMacOSDoesNotTakeBackAtAQuitIsStillOwed() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.mac.managed = [.menuBar]
    h.controller.shutdown()
    #expect(h.mac.values == [.menuBar: false])
    #expect(h.mac.before.first { $0.item == .menuBar }?.isGivenBack == false)
    #expect(h.mac.before.filter(\.isGivenBack).map(\.item) == [.screenEdges, .optionKey])
  }

  @Test func whatMacOSDoesNotLetGoOfAgainStaysGivenBack() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.controller.shutdown()
    h.mac.managed = [.menuBar]
    h.controller.start()
    #expect(h.mac.values == [.screenEdges: false, .optionKey: false])
    #expect(h.mac.before.filter(\.isGivenBack).map(\.item) == [.menuBar])
    let check = h.controller.doctorReport().check("Desktop & Dock settings")
    #expect(check?.mark == .problem && check?.notes.first == MacSwitch.menuBar.advice)
    #expect(check?.notes.last?.hasPrefix("Arbor keeps 2 of them off while it runs") == true)
  }

  @Test func aRecordThatCannotBeReadIsLeftAlone() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.mac.cannotRead = true
    let writes = h.mac.writes.count
    h.controller.shutdown()
    h.controller.start()
    #expect(h.mac.writes.count == writes)
  }

  // MARK: Ending it

  @Test func undoEndsItForGood() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    #expect(h.run("fix-setup undo").message == "put 3 settings of macOS under Desktop & Dock back as they were")
    h.controller.shutdown()
    h.controller.start()
    #expect(h.mac.values.isEmpty && h.mac.before.isEmpty)
  }

  /// During a pause: nothing is owed, and the choice goes.
  @Test func undoDuringAPauseTouchesNothingAndForgetsTheChoice() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.run("pause")
    // Meanwhile somebody has made one of them their own.
    h.mac.values[.optionKey] = false
    let writes = h.mac.writes.count
    let undone = h.run("fix-setup undo")
    #expect(undone.ok)
    #expect(undone.message == "macOS has its settings under Desktop & Dock as they were already; from now on Arbor leaves them alone")
    #expect(h.mac.writes.count == writes && h.mac.before.isEmpty)
    h.run("resume")
    #expect(h.mac.values == [.optionKey: false])
  }

  /// It says how many it put back, not how many it once took.
  @Test func undoCountsWhatItPutsBack() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.mac.values[.menuBar] = true
    #expect(h.run("fix-setup undo").message == "put 2 settings of macOS under Desktop & Dock back as they were")
    #expect(h.mac.values == [.menuBar: true] && h.mac.before.isEmpty)
  }

  /// The step is about what is in the way and nothing else: what an earlier round wrote down about other switches is not touched.
  @Test func aLaterRoundLeavesOtherRecordsAsTheyAre() {
    let h = makeHarness()
    h.mac.values = [.optionKey: false]
    h.start()
    h.run("fix-setup")
    h.run("pause")
    // Their owner switches one off for good, and another on.
    h.mac.values[.screenEdges] = false
    h.mac.values[.optionKey] = true
    #expect(h.run("fix-setup").message.hasPrefix("noted: Arbor keeps 1 setting of macOS"))
    #expect(h.mac.before.map(\.item) == [.screenEdges, .menuBar, .optionKey] && h.mac.before.allSatisfy(\.isGivenBack))
    h.run("resume")
    #expect(h.mac.before.map(\.item) == [.menuBar, .optionKey], "the one switched off by hand is its owner's")
    h.controller.shutdown()
    #expect(h.mac.values == [.screenEdges: false, .optionKey: true], "Arbor does not switch on what somebody switched off")
  }

  // MARK: What is said

  @Test func theStepSaysForHowLong() {
    let h = makeHarness()
    h.start()
    #expect(
      h.run("fix-setup").message
        == "switched off 3 settings of macOS under Desktop & Dock for as long as Arbor runs; `fix-setup undo` puts them back as they were for good")
  }

  @Test func duringAPauseTheStepIsNotTakenASecondTime() {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    h.run("pause")
    let again = h.run("fix-setup")
    #expect(!again.ok)
    #expect(again.message == "macOS has its settings back while Arbor is paused; Arbor switches them off again when it starts")
    #expect(h.mac.on == Self.asAMacComes)
  }

  /// Asked for the first time during a pause, it is a choice like any, and Arbor leaves the Mac alone until it resumes.
  @Test func askedForDuringAPauseItIsNoted() {
    let h = makeHarness()
    h.start()
    h.run("pause")
    #expect(h.run("fix-setup").message.contains("It is paused now, so nothing has changed yet"))
    #expect(h.mac.writes.isEmpty && h.mac.before == records(givenBack: true))
    h.run("resume")
    #expect(h.mac.values == Self.off)
  }

  /// The window does not come forward over what Arbor did itself.
  @Test func theWindowDoesNotComeForwardOverAPauseAndAResume() {
    let h = makeHarness()
    h.system.open(app: "Safari")
    h.launchForTheFirstTime(permitted: true)
    h.run("check-setup")
    h.welcome.click("Switch Off macOS Tiling")
    let forward = h.welcome.timesComeForward
    h.run("pause")
    #expect(h.welcome.model.row(.desktopAndDock)?.state == .note)
    h.run("resume")
    #expect(h.welcome.model.row(.desktopAndDock)?.isSatisfied == true, "at once, not at the next look at the Mac")
    h.welcome.tick()
    #expect(h.welcome.timesComeForward == forward)
  }

  /// One that somebody has switched on again by hand is not counted among those Arbor keeps off.
  @Test func theWindowCountsOnlyWhatIsOff() throws {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    func row() throws -> OnboardingModel.Row { try tilingRow(h) }
    h.mac.values[.menuBar] = true
    #expect(try row().done.hasPrefix("While Arbor runs, 2 settings of macOS are off."))
    h.mac.values[.optionKey] = true
    #expect(try row().done.hasPrefix("While Arbor runs, 1 setting of macOS is off.") && row().undo?.title == "Put It Back")
    h.mac.values[.screenEdges] = true
    #expect(try row().done.isEmpty && row().undo == nil, "all three are their owner's again")
  }

  @Test func theWindowSaysWhatQuittingDoes() throws {
    let h = makeHarness()
    h.start()
    func model() throws -> OnboardingModel { try self.model(h) }
    var row = try tilingRow(h)
    #expect(row.detail.hasSuffix("Switch that off, only while Arbor runs, and Arbor has the edges."))

    h.run("fix-setup")
    row = try tilingRow(h)
    #expect(row.isSatisfied && row.undo?.title == "Put Them Back")
    #expect(
      row.done
        == "While Arbor runs, 3 settings of macOS are off. Quit or pause Arbor, and your Mac is as it was. To end that for good: here, or later "
        + "under Help → Check Setup… in Arbor’s menu. To dock a window there, hold ⌘ and drag it to a screen edge.")

    // Paused: neither a tick, which would say "off", nor advice. Arbor is keeping its word.
    h.run("pause")
    row = try tilingRow(h)
    #expect(row.state == .note && row.importance == "On for now" && row.action == nil && row.button == nil && row.detail.isEmpty)
    #expect(row.done == "Arbor is paused, so macOS has its tiling back. Arbor switches it off again when it resumes.")
    #expect(row.undo == OnboardingModel.Row.Action("Leave Them On", .fixSetup(undo: true)))
    #expect(try !model().needsAttention)
  }

  @Test func doctorCallsNothingAProblemThatArborDidItself() throws {
    let h = makeHarness()
    h.start()
    h.run("fix-setup")
    func check() throws -> DoctorReport.Check { try #require(h.controller.doctorReport().check("Desktop & Dock settings")) }
    #expect(
      try check().notes.last == "Arbor keeps 3 of them off while it runs, and gives them back at a quit and at a pause; `fix-setup undo` ends that")
    h.run("pause")
    #expect(try check().mark == .ok && check().detail == "none in the way")
    #expect(try check().notes.last == "macOS has 3 of them back until Arbor arranges windows again; `fix-setup undo` leaves them on")
  }

  /// The file says it in macOS's own names, and an older file reads as "off, and owed".
  @Test func theLedgerKeepsTheMark() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-ledger-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let ledger = MacSwitchLedger(file: folder.appendingPathComponent(MacSwitchLedger.fileName))
    let records = [MacSwitchRecord(.screenEdges, stored: nil, isGivenBack: true), MacSwitchRecord(.optionKey, stored: true)]
    #expect(ledger.write(records))
    #expect(ledger.read() == records)
    #expect(try String(contentsOf: ledger.file, encoding: .utf8).contains("\"givenBack\" : true"))
    try Data(#"[{"key": "EnableTilingByEdgeDrag"}]"#.utf8).write(to: ledger.file)
    #expect(ledger.read() == [MacSwitchRecord(.screenEdges, stored: nil)])
  }
}
