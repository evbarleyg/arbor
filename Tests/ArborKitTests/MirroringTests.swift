import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// K160: Arbor knows when a display is mirrored, and holds still meanwhile (F58).
@Suite @MainActor struct MirroringTests {
  func makeHarness() -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(mail.rawValue)")
    return (h, safari, mail)
  }

  @Test func arborHearsWhenMirroringBeginsAndEnds() {
    let (h, _, _) = makeHarness()
    #expect(!h.controller.isMirroring)
    h.system.setMirroring(true)
    #expect(h.controller.isMirroring)
    h.system.setMirroring(false)
    #expect(!h.controller.isMirroring)
  }

  @Test func itIsKnownFromTheStartIfTheMacIsAlreadyMirrored() {
    let h = Harness()
    h.system.setMirroring(true)
    h.start()
    #expect(h.controller.isMirroring)
  }

  @Test func stateSaysWhichDisplay() throws {
    let (h, _, _) = makeHarness()
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    #expect(try #require(h.run("state").state).displays.allSatisfy { !$0.mirrored })
    h.system.setMirroring(true)
    let displays = try #require(h.run("state").state).displays
    #expect(displays.filter(\.mirrored).map(\.id) == [FakeWindowSystem.standardDisplay.id])
  }

  /// Nothing may jump as the audience begins to look.
  @Test func theViewAndTheWindowsStayAsTheyAre() {
    let (h, safari, mail) = makeHarness()
    let workspace = h.workspace
    let frames = [safari, mail].map { h.frame($0) }
    h.system.setMirroring(true)
    #expect(h.workspace == workspace)
    #expect([safari, mail].map { h.frame($0) } == frames)
    h.system.setMirroring(false)
    #expect(h.workspace == workspace)
    #expect([safari, mail].map { h.frame($0) } == frames)
  }

  @Test func aPausedArborLearnsOfItWhenItResumes() {
    let (h, _, _) = makeHarness()
    h.run("pause")
    h.system.setMirroring(true)
    h.run("resume")
    #expect(h.controller.isMirroring)
  }

  // MARK: Holding still meanwhile

  /// [Keynote | Mail / Slack], framed on Keynote, which has the keyboard. The setting is on, which it is not out of the box.
  func stage(configure: (inout Settings) -> Void = { _ in }) -> (h: Harness, keynote: WindowID, slack: WindowID) {
    var settings = Settings()
    settings.holdStillWhileMirroring = true
    configure(&settings)
    let h = Harness(settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    let slack = h.system.open(app: "Slack")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(slack.rawValue) beside \(mail.rawValue) bottom")
    h.run("zoom \(keynote.rawValue)")
    h.system.userFocus(keynote)
    return (h, keynote, slack)
  }

  @Test func arborHoldsStillWhileTheDisplayIsMirroredAndNoLonger() {
    let s = stage()
    s.h.system.setMirroring(true)
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the display is mirrored")
    #expect(s.h.run("status").message.contains("while the display is mirrored"))
    // An app that brings itself forward is not shown to the audience.
    s.h.system.comesForward(s.slack)
    #expect(s.h.system.focused == s.keynote)
    #expect(!s.h.system.isVisible(s.slack))
    // Someone presenting still walks their windows.
    #expect(s.h.run("show-all").ok)
    #expect(s.h.system.isVisible(s.slack))
    s.h.system.setMirroring(false)
    #expect(s.h.controller.holdLevel == nil)
  }

  /// Out of the box Arbor holds only when asked: no sign starts a hold until it has been seen at work on a Mac.
  @Test func outOfTheBoxAMirroredDisplayHoldsNothing() {
    let h = Harness()
    h.system.open(app: "Keynote")
    h.start()
    h.system.setMirroring(true)
    #expect(h.controller.isMirroring && h.controller.holdLevel == nil)
    #expect(h.run("set holdStillWhileMirroring true").ok)
    #expect(h.controller.holdLevel == .still)
  }

  @Test func withTheSettingOffNothingIsHeld() {
    let s = stage { $0.holdStillWhileMirroring = false }
    s.h.system.setMirroring(true)
    #expect(s.h.controller.isMirroring && s.h.controller.holdLevel == nil)
    // Switched on while mirrored, it holds at once; switched off, it lets go.
    var settings = s.h.controller.settings
    settings.holdStillWhileMirroring = true
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == .still)
    settings.holdStillWhileMirroring = false
    s.h.controller.apply(settings: settings)
    #expect(s.h.controller.holdLevel == nil)
  }

  @Test func aHoldThePersonMadeIsNeitherReplacedNorEnded() {
    for command in ["hold", "hold still"] {
      let s = stage()
      s.h.run(command)
      let level = s.h.controller.holdLevel
      s.h.system.setMirroring(true)
      #expect(s.h.controller.holdLevel == level, "\(command): not replaced")
      s.h.system.setMirroring(false)
      #expect(s.h.controller.holdLevel == level, "\(command): not ended")
      // Nor one made during it.
      let during = stage()
      during.h.system.setMirroring(true)
      during.h.run(command)
      during.h.system.setMirroring(false)
      #expect(during.h.controller.holdLevel == level, "\(command), made meanwhile")
    }
  }

  @Test func releasedByHandItStaysReleasedUntilTheMirroringIsOver() {
    let s = stage()
    s.h.system.setMirroring(true)
    #expect(s.h.run("release").ok)
    #expect(s.h.controller.holdLevel == nil)
    // Another display change in the meantime, the Dock growing for one, does not begin it again.
    var displays = s.h.system.displays()
    displays[0].visibleFrame.size.height -= 20
    s.h.system.setDisplays(displays)
    #expect(s.h.controller.isMirroring && s.h.controller.holdLevel == nil)
    s.h.system.setMirroring(false)
    s.h.system.setMirroring(true)
    #expect(s.h.controller.holdLevel == .still, "the next time is a new time")
  }

  /// A release lasts for the occasion it was made on.
  @Test func aCallAndAnAudienceAreTwoOccasions() {
    // Released in front of the audience; then a call begins.
    var s = stage { $0.holdStillWhileCameraIsOn = true }
    s.h.system.setMirroring(true)
    #expect(s.h.run("release").ok && s.h.controller.holdLevel == nil)
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.controller.holdLevel == .still, "the call is new")
    // Released during the call, which goes on; then the Mac is plugged into a projector.
    s = stage { $0.holdStillWhileCameraIsOn = true }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.run("release").ok && s.h.controller.holdLevel == nil)
    s.h.system.setMirroring(true)
    #expect(s.h.controller.holdLevel == .still, "the audience is new")
    // Released again, with both: the call ends and the audience stays.
    #expect(s.h.run("release").ok && s.h.controller.holdLevel == nil)
    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 6)
    #expect(s.h.controller.holdLevel == .still, "what was released was called a call")
    // With the setting off a projector is no occasion at all.
    s = stage {
      $0.holdStillWhileCameraIsOn = true
      $0.holdStillWhileMirroring = false
    }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.run("release").ok)
    s.h.system.setMirroring(true)
    #expect(s.h.controller.holdLevel == nil)
  }

  /// A dock is unplugged in the middle of a call: the camera goes with it, another comes on a moment later, and the displays change
  /// in between. Whatever the setting says.
  @Test(arguments: [true, false]) func anotherChangeOfTheDisplaysDoesNotCutShortTheMomentACallIsGiven(setting: Bool) {
    let s = stage {
      $0.holdStillWhileCameraIsOn = true
      $0.holdStillWhileMirroring = setting
    }
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    var changes = 0
    s.h.controller.observe { if $0 == .hold { changes += 1 } }
    s.h.controller.callSignalsChanged(CallSignals())
    s.h.scheduler.advance(by: 1)
    var displays = s.h.system.displays()
    displays[0].visibleFrame.size.height -= 20
    s.h.system.setDisplays(displays)
    #expect(s.h.controller.holdLevel == .still)
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    s.h.scheduler.advance(by: 60)
    #expect(s.h.controller.holdLevel == .still && changes == 0)
  }

  /// From mirroring to a desktop that extends over both, with the Mac's own display no longer at the origin.
  @Test func whatWaitedForTheEndOfTheHoldComesInOnceTheDisplaysAreDealtWith() {
    let terminal = "com.apple.Terminal"
    let s = stage { $0.rules = [AppRule(app: terminal, action: .dock(.right))] }
    s.h.system.setMirroring(true)
    let t = s.h.system.open(app: "Terminal", bundleID: terminal)
    #expect(s.h.workspace.isFloating(t), "the rule waits")
    var own = FakeWindowSystem.standardDisplay
    own.frame.origin.x = 1920
    own.visibleFrame.origin.x = 1920
    own.isMain = false
    let external = DisplaySnapshot(
      id: DisplayID("external"), frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    s.h.system.setDisplays([external, own])
    #expect(s.h.controller.holdLevel == nil)
    #expect(s.h.controller.workspaces.values.contains { $0.isDocked(t) }, "and is applied")
    #expect(s.h.controller.invariantViolations().isEmpty)
    expectWindowsMatchLayout(s.h)
  }

  @Test func aPauseThePersonMadeIsLeftAlone() {
    let s = stage()
    s.h.run("pause")
    s.h.system.setMirroring(true)
    #expect(s.h.controller.isPaused && s.h.controller.holdLevel == nil)
    s.h.system.setMirroring(false)
    #expect(s.h.controller.isPaused)
    s.h.system.setMirroring(true)
    s.h.run("resume")
    #expect(s.h.controller.holdLevel == .still, "still mirrored when Arbor looks again")
  }

  @Test func alreadyMirroredAtLaunchItHoldsFromTheStart() {
    var settings = Settings()
    settings.holdStillWhileMirroring = true
    let h = Harness(settings: settings)
    h.system.open(app: "Keynote")
    h.system.setMirroring(true)
    h.start()
    #expect(h.controller.holdLevel == .still)
  }

  @Test func aCallThatGoesOnAfterTheMirroringKeepsHolding() {
    let s = stage { $0.holdStillWhileCameraIsOn = true }
    s.h.system.setMirroring(true)
    s.h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the camera is on", "the call is named first")
    s.h.system.setMirroring(false)
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.controller.holdMenu.first?.title == "Holding still while the camera is on")
  }

  /// A second display that becomes the mirror goes away as a display. Its windows have to come over; the view does not move.
  @Test func whenASecondDisplayBecomesTheMirrorTheViewOfTheFirstStays() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let s = stage()
    s.h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    let camera = s.h.workspace.camera
    let frame = s.h.frame(s.keynote)
    var mirrored = FakeWindowSystem.standardDisplay
    mirrored.isMirrored = true
    s.h.system.setDisplays([mirrored])
    #expect(s.h.controller.holdLevel == .still)
    #expect(s.h.workspace.camera == camera && s.h.frame(s.keynote) == frame)
    #expect(!s.h.system.isVisible(s.slack))
  }

  @Test func theSettingHasItsDefaultAndOldFilesLoad() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(!old.holdStillWhileMirroring)
    var changed = Settings()
    changed.holdStillWhileMirroring = true
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(changed)) == changed)
  }
}
