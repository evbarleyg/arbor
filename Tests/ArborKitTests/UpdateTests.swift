import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// `version`, `status`, `check-for-updates` and the automatic checks, through the real controller.
@Suite @MainActor struct UpdateTests {
  static let day: Double = 24 * 3600

  /// A harness for build 0.9.0 that records what the user would be shown.
  final class Fixture {
    let h: Harness
    var shown: [UpdateDecision] = []

    @MainActor init(automatic: Bool = false, start: Bool = true) {
      var settings = Settings()
      settings.automaticUpdateChecks = automatic
      h = Harness(settings: settings)
      h.controller.buildInfo = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")
      h.controller.onUpdateDecision = { [unowned self] in shown.append($0) }
      if start { h.start() }
    }
  }

  func available(_ version: String) throws -> UpdateDecision {
    .available(
      latest: try #require(SemanticVersion(version)),
      page: "https://github.com/evbarleyg/arbor/releases/tag/v\(version)")
  }

  // MARK: version and status

  @Test func versionAndStatusNameTheBuild() {
    let f = Fixture(start: false)
    #expect(f.h.run("version").ok)  // a query: it works before start, like `state`
    #expect(f.h.run("version").message == "Arbor 0.9.0 (build 214, 47a2ba9)")
    #expect(f.h.run("version").text == nil)  // one line until something has been asked about updates
    // What `arborctl status` prints: the status, which stays a line of its own for scripts, then the build.
    f.h.controller.accessibilityGranted = false
    var status = f.h.run("status")
    #expect(status.message.hasPrefix("waiting for Accessibility permission"))
    #expect(status.text == status.message + "\nArbor 0.9.0 (build 214, 47a2ba9)")
    f.h.controller.accessibilityGranted = true
    f.h.start()
    status = f.h.run("status")
    #expect(status.message.hasPrefix("running: 1 display"))
    #expect(status.text == status.message + "\nArbor 0.9.0 (build 214, 47a2ba9)")
  }

  @Test func aBinaryOutsideABundleIsADevelopmentBuild() {
    let h = Harness()
    #expect(h.run("version").message == "Arbor dev")
    #expect(h.run("status").text?.hasSuffix("\nArbor dev") == true)
  }

  // MARK: Checking by hand

  @Test func checkingByHandOffersANewerRelease() throws {
    let f = Fixture()
    f.h.releases.reply = .latest(tag: "v0.9.1")
    let result = f.h.run("check-for-updates")
    #expect(result.ok)
    #expect(result.message == "Arbor 0.9.1 is available: https://github.com/evbarleyg/arbor/releases/tag/v0.9.1")
    #expect(f.shown == [try available("0.9.1")])
    #expect(f.h.run("version").text?.hasSuffix("\nUpdates: \(result.message)") == true)
  }

  @Test func checkingByHandAlwaysGetsAnAnswerToShow() throws {
    let f = Fixture()
    f.h.releases.reply = .latest(tag: "v0.9.0")
    #expect(f.h.run("check-for-updates").message == "up to date (the latest release is 0.9.0)")
    f.h.releases.reply = .nothingPublished  // what GitHub says while the repository is private
    #expect(f.h.run("check-for-updates").ok)
    f.h.releases.reply = .failed("GitHub could not be reached: offline")
    #expect(f.h.run("check-for-updates").ok)
    #expect(
      f.shown == [
        .upToDate(latest: try #require(SemanticVersion("0.9.0"))),
        .noInformation("GitHub lists no published release"),
        .noInformation("GitHub could not be reached: offline"),
      ])
    #expect(f.h.releases.requests == 3)
  }

  @Test func checkingNeedsNoAccessibilityPermission() {
    let f = Fixture(start: false)
    f.h.controller.accessibilityGranted = false
    #expect(f.h.run("check-for-updates").ok)
    #expect(f.shown.count == 1)
  }

  @Test func withoutAFeedTheCommandSaysSo() {
    let f = Fixture()
    f.h.controller.releaseFeed = nil
    let result = f.h.run("check-for-updates")
    #expect(!result.ok)
    #expect(result.message == "this build cannot check for updates")
    #expect(f.shown.isEmpty)
  }

  @Test func checkingLeavesTheWindowsAlone() {
    let f = Fixture()
    let a = f.h.system.open(app: "Safari")
    f.h.run("dock \(a.rawValue) left")
    let (frame, workspace) = (f.h.frame(a), f.h.workspace)
    f.h.releases.reply = .latest(tag: "v1.0.0")
    f.h.run("check-for-updates")
    #expect(f.h.frame(a) == frame)
    #expect(f.h.workspace == workspace)
  }

  // MARK: Slow and misbehaving networks

  @Test func aSecondCheckWhileOneIsRunningDoesNotAskTwice() throws {
    let f = Fixture()
    f.h.releases.reply = nil
    #expect(f.h.run("check-for-updates").message == "checking for updates; `version` shows the answer")
    #expect(f.h.run("version").text?.hasSuffix("\nUpdates: checking") == true)
    #expect(f.h.run("check-for-updates").message == "already checking for updates")
    #expect(f.h.releases.requests == 1)
    #expect(f.shown.isEmpty)
    f.h.releases.answer(.latest(tag: "v0.9.1"))
    #expect(f.shown == [try available("0.9.1")])
  }

  @Test func aFeedThatNeverAnswersDoesNotBlockLaterChecks() {
    let f = Fixture()
    f.h.releases.reply = nil
    f.h.run("check-for-updates")
    f.h.scheduler.advance(by: 29)
    #expect(f.shown.isEmpty)
    f.h.scheduler.advance(by: 2)
    #expect(f.shown == [.noInformation("no answer")])
    f.h.releases.reply = .nothingPublished
    #expect(f.h.run("check-for-updates").message.hasPrefix("no update information"))
    #expect(f.h.releases.requests == 2)
  }

  @Test func lateAndRepeatedAnswersAreIgnored() throws {
    let f = Fixture()
    f.h.releases.reply = nil
    f.h.run("check-for-updates")
    f.h.releases.answer(.latest(tag: "v0.9.1"), keep: true)
    f.h.releases.answer(.latest(tag: "v0.9.2"), keep: true)  // the same lookup answering again
    #expect(f.shown == [try available("0.9.1")])
    // A new check is not finished by the old lookup's answer either.
    f.h.run("check-for-updates")
    #expect(f.h.run("version").text?.hasSuffix("checking") == true)
    f.h.scheduler.advance(by: 31)
    #expect(f.shown.count == 2)
    f.h.releases.answer(.latest(tag: "v0.9.3"))
    #expect(f.shown.count == 2)
    #expect(!f.h.scheduler.pendingKeys.contains("update-check-timeout"))
  }

  // MARK: Automatic checks

  @Test func nothingIsAskedUnlessTheSettingIsOn() {
    let f = Fixture()
    f.h.scheduler.advance(by: 60 * Self.day)
    #expect(f.h.releases.requests == 0)
    #expect(f.h.controller.updates.nextAutomaticCheck == nil)
    #expect(!f.h.scheduler.pendingKeys.contains("update-check"))
  }

  @Test func withTheSettingOnArborAsksAfterLaunchAndThenWeekly() {
    let f = Fixture(automatic: true)
    #expect(f.h.releases.requests == 0)  // not in the way of starting up
    f.h.scheduler.advance(by: 59)
    #expect(f.h.releases.requests == 0)
    f.h.scheduler.advance(by: 2)
    #expect(f.h.releases.requests == 1)
    f.h.scheduler.advance(by: 6.9 * Self.day)
    #expect(f.h.releases.requests == 1)
    f.h.scheduler.advance(by: 0.2 * Self.day)
    #expect(f.h.releases.requests == 2)
    f.h.scheduler.advance(by: 21 * Self.day)
    #expect(f.h.releases.requests == 5)
  }

  /// The user may be in a call or sharing the screen: nothing appears that nobody asked for.
  @Test func automaticChecksNeverShowAnythingWhateverTheyFind() {
    let f = Fixture(automatic: true)
    for reply in [ReleaseLookup.nothingPublished, .latest(tag: "v0.9.0"), .failed("offline"), .latest(tag: "v0.9.1"), .latest(tag: "v1.0.0")] {
      f.h.releases.reply = reply
      f.h.scheduler.advance(by: 7 * Self.day + 61)
    }
    #expect(f.h.releases.requests >= 5)
    #expect(f.shown.isEmpty)
  }

  @Test func whatAnAutomaticCheckFoundWaitsInTheMenuAndInVersion() throws {
    let f = Fixture(automatic: true)
    #expect(f.h.controller.updateMenuTitle == "Check for Updates…")
    f.h.scheduler.advance(by: 61)  // no published release
    #expect(f.h.controller.updateMenuTitle == "Check for Updates…")
    #expect(f.h.run("version").text?.hasSuffix("\nUpdates: no update information (GitHub lists no published release)") == true)

    f.h.releases.reply = .latest(tag: "v0.9.1")
    f.h.scheduler.advance(by: 7 * Self.day)
    #expect(f.h.controller.updateMenuTitle == "Update Available…")
    #expect(f.h.run("version").text?.contains("Arbor 0.9.1 is available") == true)
    #expect(f.shown.isEmpty)
    // Choosing it asks again, and now the answer is shown.
    f.h.run("check-for-updates")
    #expect(f.shown == [try available("0.9.1")])

    // Being offline for a moment does not take the news back, though asking then says what is so.
    f.h.releases.reply = .failed("offline")
    f.h.scheduler.advance(by: 7 * Self.day)
    f.h.run("check-for-updates")
    #expect(f.shown.last == .noInformation("offline"))
    #expect(f.h.controller.updateMenuTitle == "Update Available…")

    f.h.releases.reply = .latest(tag: "v0.9.0")  // the release was withdrawn
    f.h.scheduler.advance(by: 7 * Self.day)
    #expect(f.h.controller.updateMenuTitle == "Check for Updates…")
  }

  @Test func aCheckThatGotNoAnswerIsTriedAgainTheSameDay() {
    let f = Fixture(automatic: true)
    f.h.releases.reply = .failed("offline")  // the Mac logged in before the network was up
    f.h.scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
    f.h.releases.reply = .nothingPublished
    f.h.scheduler.advance(by: 6 * 3600 + 1)
    #expect(f.h.releases.requests == 2)
    f.h.scheduler.advance(by: 6.9 * Self.day)
    #expect(f.h.releases.requests == 2)
  }

  @Test func aCheckByHandPutsOffTheNextAutomaticOne() {
    let f = Fixture(automatic: true)
    f.h.scheduler.advance(by: 61)
    f.h.scheduler.advance(by: 5 * Self.day)
    f.h.run("check-for-updates")
    #expect(f.h.releases.requests == 2)
    f.h.scheduler.advance(by: 6.9 * Self.day)
    #expect(f.h.releases.requests == 2)
    f.h.scheduler.advance(by: 0.2 * Self.day)
    #expect(f.h.releases.requests == 3)
  }

  @Test func askingByHandDuringAnAutomaticCheckShowsItsAnswer() {
    let f = Fixture(automatic: true)
    f.h.releases.reply = nil
    f.h.scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
    #expect(f.h.run("check-for-updates").message == "already checking for updates")
    f.h.releases.answer(.nothingPublished)
    #expect(f.shown == [.noInformation("GitHub lists no published release")])
  }

  @Test func reloadingSettingsStartsAndStopsTheChecks() {
    let f = Fixture()
    var edited = Settings()
    edited.automaticUpdateChecks = true
    f.h.controller.loadSettings = { edited }
    f.h.run("reload-settings")
    f.h.scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
    // Settings changes that have nothing to do with updates do not restart the week.
    f.h.scheduler.advance(by: 6 * Self.day)
    f.h.run("exclude com.example.notes")
    f.h.scheduler.advance(by: 1 * Self.day)
    #expect(f.h.releases.requests == 2)

    edited.automaticUpdateChecks = false
    f.h.run("reload-settings")
    f.h.scheduler.advance(by: 30 * Self.day)
    #expect(f.h.releases.requests == 2)
    #expect(!f.h.scheduler.pendingKeys.contains("update-check"))
  }

  /// Scheduled delays stand still while a Mac sleeps; the clock does not.
  @Test func aWeekSpentMostlyAsleepIsStillAWeek() {
    let f = Fixture(automatic: true)
    let scheduler = f.h.scheduler
    let start = f.h.controller.now()
    var asleep: TimeInterval = 0
    f.h.controller.now = { start.addingTimeInterval(scheduler.now + asleep) }
    scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
    // Awake for a few hours in all, during which Arbor looks at the clock at least once.
    asleep = 6.9 * Self.day
    scheduler.advance(by: 0.3 * Self.day)
    #expect(f.h.releases.requests == 2)
  }

  @Test func runningEverythingPendingDoesNotCheckEarly() {
    let f = Fixture(automatic: true)
    f.h.scheduler.runPending()  // what tests and arbor-sim's `flush` do to run saves
    f.h.scheduler.runPending()
    #expect(f.h.releases.requests == 0)
    f.h.scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
  }

  @Test func aPauseHoldsTheChecksAndDoesNotBringTheNextOneForward() throws {
    let f = Fixture(automatic: true)
    f.h.scheduler.advance(by: 61)
    #expect(f.h.releases.requests == 1)
    f.h.scheduler.advance(by: 6 * Self.day)
    f.h.run("pause")
    #expect(!f.h.scheduler.pendingKeys.contains("update-check"))  // a pause silences every timer
    f.h.scheduler.advance(by: 3 * Self.day)
    #expect(f.h.releases.requests == 1)
    f.h.run("resume")
    // It fell due during the pause, so it comes now, and not a minute after a "launch".
    f.h.scheduler.advance(by: 2)
    #expect(f.h.releases.requests == 2)

    f.h.run("pause")
    f.h.run("resume")
    f.h.scheduler.advance(by: 6.9 * Self.day)
    #expect(f.h.releases.requests == 2)
  }

  @Test func aCheckByHandWorksDuringAPause() throws {
    let f = Fixture(automatic: true)
    f.h.run("pause")
    f.h.releases.reply = .latest(tag: "v0.9.1")
    #expect(f.h.run("check-for-updates").ok)
    #expect(f.shown == [try available("0.9.1")])
    #expect(!f.h.scheduler.pendingKeys.contains("update-check"))  // and does not wake the timer
  }

  @Test func noChecksAfterArborStops() {
    let f = Fixture(automatic: true)
    f.h.controller.shutdown()
    f.h.scheduler.advance(by: 30 * Self.day)
    #expect(f.h.releases.requests == 0)
  }
}
