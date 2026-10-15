import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The welcome window opens by itself once (docs/features/F46-first-run-coach.md, acceptance 2).
@Suite @MainActor struct FirstLaunchTests {
  static let healthy = SystemFacts(accessibility: true, screenRecording: true, switches: [], inputSources: 1)

  func makeHarness(saved: PersistedState? = nil, facts: SystemFacts = healthy) -> Harness {
    let h = Harness(saved: saved)
    h.controller.systemFacts = { facts }
    return h
  }

  /// With the permission already there nothing on the display changes at launch, and the icon may be behind a notch.
  @Test func aNewcomerWhoHasThePermissionIsWelcomedOnce() {
    let h = makeHarness()
    h.start()
    #expect(h.controller.pageToWelcomeOn() == .firstSteps, "nothing to put right, so straight to the four moves")
    #expect(h.controller.pageToWelcomeOn() == .firstSteps, "asking is not showing")
    h.controller.noteWelcomed()
    #expect(h.controller.pageToWelcomeOn() == nil)
    h.scheduler.advance(by: 1)
    #expect(h.store.saved?.welcomed == true)

    // The next launch, and every one after it.
    let next = makeHarness(saved: h.store.saved)
    next.start()
    #expect(next.controller.pageToWelcomeOn() == nil)
  }

  @Test func withSomethingToPutRightItOpensOnHowThingsStand() {
    var facts = Self.healthy
    facts.competingApps = ["Rectangle"]
    let h = makeHarness(facts: facts)
    h.start()
    #expect(h.controller.pageToWelcomeOn() == .permissions)
    // What is only optional, or good to know, is no reason to hold a newcomer up.
    facts = Self.healthy
    facts.screenRecording = false
    facts.inputSources = 2
    let other = makeHarness(facts: facts)
    other.start()
    #expect(other.controller.pageToWelcomeOn() == .firstSteps)
  }

  /// A Mac comes with macOS's own tiling and the wallpaper click switched on. A newcomer hears of it before anything is
  /// arranged: nothing has moved by then, and nothing moves until they dock a window.
  @Test func onAMacAsItComesTheFirstThingShownIsWhatMacOSWantsForItself() throws {
    var facts = Self.healthy
    facts.switches = MacSwitch.inTheWay(macOS: 26) { _ in nil }
    let h = makeHarness(facts: facts)
    let windows = [h.system.open(app: "Safari"), h.system.open(app: "Mail")]
    let before = windows.map { h.frame($0) }
    h.start()
    h.scheduler.advance(by: 5)
    #expect(h.controller.pageToWelcomeOn() == .permissions)
    let row = try #require(h.controller.onboardingModel(facts).row(.desktopAndDock))
    #expect(row.state == .recommended)
    for tiling in [MacSwitch.screenEdges, .menuBar, .optionKey] { #expect(row.afterword.contains(tiling.named)) }
    #expect(windows.map { h.frame($0) } == before)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(windows.allSatisfy { h.workspace.isFloating($0) })
  }

  /// Whoever used Arbor before there was a welcome window has not seen it, and loses nothing by it.
  @Test func anOlderStateFileCountsAsNotWelcomedAndKeepsItsArrangement() throws {
    let before = Harness()
    let a = before.system.open(app: "Safari")
    before.start()
    before.run("dock \(a.rawValue) left")
    before.scheduler.advance(by: 1)
    let state = try #require(before.store.saved)
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    #expect(json["welcomed"] as? Bool == false)
    json["welcomed"] = nil
    let old = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(!old.welcomed)
    #expect(old.workspaces == before.store.saved?.workspaces)

    // A value nobody can read costs only itself.
    json["welcomed"] = "yes"
    let odd = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(!odd.welcomed)
    #expect(odd.workspaces == before.store.saved?.workspaces)
  }

  /// A launch without the permission shows the window before Arbor has read what it saved. Writing the flag down then
  /// would write an empty arrangement over the saved one.
  @Test func beingWelcomedBeforeArborStartsSavesNothingUntilItRuns() throws {
    let before = Harness()
    let a = before.system.open(app: "Safari", title: "Start Page")
    before.start()
    before.run("dock \(a.rawValue) left")
    before.scheduler.advance(by: 1)
    let saved = try #require(before.store.saved)
    #expect(saved.workspaces.values.contains { !$0.tree.allWindows.isEmpty })

    let h = makeHarness(saved: saved)
    h.system.open(app: "Safari", title: "Start Page")
    h.controller.accessibilityGranted = false
    h.controller.noteWelcomed()
    h.scheduler.runPending()
    #expect(h.store.saveCount == 0)
    #expect(h.store.saved == saved)

    // The permission arrives.
    h.controller.accessibilityGranted = true
    h.start()
    #expect(h.controller.pageToWelcomeOn() == nil, "they have just been looking at it")
    h.scheduler.advance(by: 1)
    #expect(h.store.saved?.welcomed == true)
    #expect(h.store.saved?.workspaces.values.contains { !$0.tree.allWindows.isEmpty } == true, "and the arrangement is there")
  }

  /// However the window came to be seen.
  @Test(arguments: ["welcome", "check-setup"])
  func openingItByHandCounts(command: String) {
    let h = makeHarness()
    h.controller.openWelcomeWindow = { _ in }
    h.start()
    #expect(h.run(command).ok)
    #expect(h.controller.pageToWelcomeOn() == nil)
  }

  @Test func aCommandThatCouldOpenNoWindowDoesNotCount() {
    let h = makeHarness()
    h.start()
    #expect(!h.run("welcome").ok)
    #expect(h.controller.pageToWelcomeOn() != nil)
  }

  @Test func aPauseChangesNothingAboutIt() {
    let h = makeHarness()
    h.start()
    h.controller.noteWelcomed()
    h.run("pause")
    h.run("resume")
    #expect(h.controller.pageToWelcomeOn() == nil)
    let fresh = makeHarness()
    fresh.start()
    fresh.run("pause")
    #expect(fresh.controller.pageToWelcomeOn() == nil, "nothing opens by itself during a pause")
    fresh.run("resume")
    #expect(fresh.controller.pageToWelcomeOn() == .firstSteps)
  }
}
