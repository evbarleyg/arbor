import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A doubt about the Accessibility permission that passes by itself ends nothing (docs/features/F63-permission-taken-away.md, criterion 7): what else
/// is going on, or is pressed, in that second. The plain cases are in `PermissionLossTests`. Nearly all of these were a reader's finds.
@Suite @MainActor struct ADoubtEndsNothingTests {
  func makeHarness(framed: Bool = true, settings: Settings = .withGestures)
    -> (Harness, safari: WindowID, mail: WindowID, notes: WindowID, chat: WindowID)
  {
    let h = Harness(settings: settings)
    h.watchAccessibility()
    let safari = h.system.open(app: "Safari")
    let mail = h.system.open(app: "Mail")
    let notes = h.system.open(app: "Notes")
    let chat = h.system.open(app: "Chat")
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) bottom")
    if framed { h.run("zoom \(notes.rawValue)") }
    return (h, safari, mail, notes, chat)
  }

  /// In an app Arbor pauses for.
  func inAGame(_ h: Harness) {
    h.run("set pauseForApps add com.example.game")
    h.system.userFocus(h.system.open(app: "Game", bundleID: "com.example.game"))
  }

  /// Noticed, and over within a second: the privacy daemon restarted, say.
  func doubt(_ h: Harness, meanwhile: () -> Void = {}) {
    h.revokeAccessibility()
    h.scheduler.advance(by: 2.6)
    #expect(h.controller.permissionLoss != nil, "or this proves nothing")
    meanwhile()
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.permissionLoss == nil && h.controller.accessibilityGranted)
  }

  func line(_ h: Harness) -> String? { h.overlays.headsUp[h.display]?.line }
  func keys(_ h: Harness) -> [String] { h.controller.activeBindings.map(\.command.text).sorted() }

  /// All that somebody outside the controller can see of it.
  func whatShows(_ h: Harness) -> [String: String] {
    [
      "status": h.run("status").message, "state": String(describing: h.run("state").state), "menu": h.controller.menuModel().text,
      "menu bar": String(describing: h.controller.menuBarModel()), "keys": keys(h).joined(separator: ","),
      "bindings": h.run("bindings").message, "doctor": h.run("doctor").text ?? "", "saved": String(describing: h.store.saved),
      "timers": h.scheduler.pendingKeys.filter { $0 != "accessibility" }.sorted().joined(separator: ","),
      "lines": String(describing: h.overlays.headsUp.mapValues(\.line)), "scenes": String(describing: h.overlays.scenes),
      "taps": String(describing: h.controller.inputSettings == h.controller.settings),
      "flags": "\(h.controller.isRunning) \(h.controller.isPaused) \(h.controller.isPausedForApp) \(h.controller.isInBusiness)",
      "spaces": h.run("spaces").text ?? "", "displays": h.run("displays").text ?? "",
    ]
  }

  // MARK: As before

  enum Pause: CaseIterable { case byHand, withAnEnd, forAnApp, arborsOwn }

  @Test(arguments: Pause.allCases) func allThatShowsOfAPauseIsAsBefore(_ pause: Pause) {
    let (h, _, _, _, _) = makeHarness()
    switch pause {
    case .byHand: h.run("pause")
    case .withAnEnd: h.run("pause 5")
    case .forAnApp: inAGame(h)
    case .arborsOwn: h.controller.sessionIsEnding()
    }
    h.scheduler.advance(by: 20)
    let (before, moves) = (whatShows(h), h.system.frameLog.count)
    doubt(h)
    let after = whatShows(h)
    for key in before.keys.sorted() { #expect(before[key] == after[key], "\(pause): \(key)") }
    #expect(h.system.frameLog.count == moves)
  }

  /// Nobody gave a key away at a logout, and a doubt is no reason to.
  @Test func arborsOwnPauseKeepsItsKeysAllTheWay() {
    let (h, _, _, _, _) = makeHarness()
    h.controller.sessionIsEnding()
    var held: Set<Int> = [h.controller.activeBindings.count]
    h.controller.observe { [controller = h.controller] _ in held.insert(controller.activeBindings.count) }
    doubt(h)
    #expect(held.count == 1, "\(held)")
    #expect(h.key("ctrl+opt+z")?.ok == false)
    #expect(line(h)?.hasPrefix("Arbor is paused") == true, "\(line(h) ?? "no line")")
    h.scheduler.advance(by: 120)
    #expect(h.controller.isRunning && !h.controller.isPaused, "the logout was called off: Arbor is back after its two minutes")
  }

  /// The icon and the keys follow these.
  @Test func whoeverLooksOnHearsOfTheLossAndOfTheReturn() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    h.scheduler.advance(by: 5)
    var heard: [String] = []
    h.controller.observe { [controller = h.controller] in heard.append("\($0) \(controller.isPaused) \(controller.accessibilityGranted)") }
    doubt(h)
    #expect(heard == ["lifecycle false false", "lifecycle true true"])
  }

  /// A floating window that docked windows had pushed aside: the pause takes it to where its person left it, the resume brings it back.
  @Test func theResumeUndoesWhatThePauseDidAsWithoutTheDoubt() {
    func play(withDoubt: Bool) -> [CGRect?] {
      let h = Harness(settings: .withGestures)
      h.watchAccessibility()
      let docked = h.system.open(app: "Safari")
      let floating = h.system.open(app: "Chat", frame: CGRect(x: 20, y: 60, width: 500, height: 400))
      h.start()
      // Whether floating windows make way is about to become a setting that ships off. Until it is one this is refused, and they do.
      h.run("set floatingWindowsMakeWay true")
      h.run("dock \(docked.rawValue) left")
      h.scheduler.advance(by: 1)
      var frames = [h.frame(floating)]
      h.run("pause")
      frames.append(h.frame(floating))
      if withDoubt { doubt(h) } else { h.scheduler.advance(by: 3.6) }
      h.run("resume")
      h.scheduler.advance(by: 1)
      return frames + [h.frame(floating)]
    }
    let plain = play(withDoubt: false)
    #expect(plain[0] != plain[1] && plain[0] == plain[2], "or this proves nothing: \(plain)")
    #expect(play(withDoubt: true) == plain)
  }

  @Test func noPauseOfOldIsDugOut() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    h.revokeAccessibility()
    h.scheduler.advance(by: 20)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning)
    doubt(h)
    #expect(h.controller.isRunning && !h.controller.isPaused)
    h.run("pause")
    doubt(h)
    doubt(h)
    #expect(h.controller.isPaused)
    h.run("resume")
    doubt(h)
    #expect(h.controller.isRunning && !h.controller.isPaused)
  }

  // MARK: What the pause still owed

  /// `LeftInFullScreenTests.leavingFullScreenDuringAPauseItComesIntoView`, with a doubt before the window leaves full screen.
  @Test func aWindowLeftInFullScreenIsStillLookedOutFor() {
    let h = Harness(settings: .withGestures)
    h.watchAccessibility()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.setFullScreen(b, true)
    h.run("pause")
    h.scheduler.advance(by: 5)
    doubt(h)
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 10)
    #expect(h.controller.isPaused)
    #expect(h.system.isVisible(b), "the pause promised every window in view: \(String(describing: h.system.frame(of: b)))")
  }

  /// `RealWindowHardeningTests.aWindowThatCouldNotComeBackAtThePauseComesBackWhenItsAppWakes`, with a doubt. Whether a try falls into the doubt
  /// depends on when it begins.
  @Test(arguments: [0.0, 0.5, 1.0, 2.0, 4.0, 10.0]) func aWindowOfAnAppThatHangsIsStillFetched(secondsIntoThePause: Double) {
    let h = Harness()
    h.watchAccessibility()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 2000, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.run("pause")
    #expect(!h.system.isVisible(b), "or this proves nothing")
    h.scheduler.advance(by: secondsIntoThePause)
    doubt(h)
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 60)
    #expect(h.controller.isPaused)
    #expect(h.system.isVisible(b))
  }

  // MARK: What is said

  /// Arbor's own pause holds every key, so any of them pressed in the doubt gets the line. Nothing starts when the doubt has passed, so nothing
  /// would take the line away by the way.
  @Test func theLineAKeyGotInTheDoubtGoesWithTheDoubt() {
    let (h, _, _, _, _) = makeHarness()
    h.controller.sessionIsEnding()
    h.scheduler.advance(by: 10)
    doubt(h) {
      h.key("ctrl+opt+z")
      #expect(line(h)?.hasPrefix("Arbor needs the Accessibility permission") == true)
    }
    #expect(h.controller.isPaused)
    #expect(line(h) == nil, "F63: the line goes when the permission comes")
  }

  /// The pause was taken with its key, so its own line is up for a few seconds. The doubt comes while it is.
  @Test func theLineThatSaysPausedGoesWhenItsTimeIsUp() {
    let (h, _, _, _, _) = makeHarness()
    h.key("ctrl+opt+escape")
    #expect(line(h)?.hasPrefix("Arbor is paused") == true, "\(line(h) ?? "no line")")
    doubt(h)
    h.scheduler.advance(by: 60)
    #expect(h.controller.isPaused)
    #expect(line(h) == nil)
  }

  // MARK: What the person says meanwhile

  /// One "no" of the daemon's at the very moment of the key that ends the pause: a command believes one no. They said so themselves, and that stands.
  @Test(arguments: ["key", "resume", "toggle-pause"]) func aResumeGivenInTheDoubtIsNotLost(_ way: String) {
    let (h, _, _, _, _) = makeHarness()
    let before = h.workspace
    h.run("pause")
    h.scheduler.advance(by: 20.5)
    h.revokeAccessibility()
    let reply = way == "key" ? h.key("ctrl+opt+escape") : h.run(way)
    #expect(reply?.ok == false, "Arbor can do nothing yet, and says so")
    #expect(keys(h).count > 1, "whoever wants Arbor back has taken the keys back")
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning && !h.controller.isPaused, "\(h.run("status").message)")
    #expect(h.workspace == before)
    #expect(line(h) == nil)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test(arguments: ["pause", "pause 5", "show-all", "home"]) func whateverElseIsAskedInTheDoubtChangesNothing(_ command: String) {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    h.scheduler.advance(by: 20)
    let moves = h.system.frameLog.count
    doubt(h) { #expect(!h.run(command).ok) }
    #expect(h.controller.isPaused)
    #expect(h.system.frameLog.count == moves)
    #expect(!h.scheduler.pendingKeys.contains("resume"))
  }

  // MARK: For an app

  @Test func theAppThePauseWasForLeavesTheFrontMeanwhile() {
    let (h, safari, _, _, _) = makeHarness()
    inAGame(h)
    #expect(h.controller.isPausedForApp)
    doubt(h) { h.system.userFocus(safari) }
    #expect(h.controller.isRunning && !h.controller.isPaused)
    h.scheduler.advance(by: 1)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theAppThePauseWasForIsTakenOffTheListMeanwhile() {
    let (h, _, _, _, _) = makeHarness()
    inAGame(h)
    doubt(h) { #expect(h.run("set pauseForApps remove com.example.game").ok) }
    #expect(h.controller.isRunning && !h.controller.isPaused, "\(h.run("status").message)")
  }

  /// The other way round: "someone who resumed by hand inside the app meant it" (`followFrontmostApp`). A doubt is no new way in.
  @Test func whoeverResumedByHandInsideSuchAnAppIsNotPausedAgain() {
    let (h, _, _, _, _) = makeHarness()
    inAGame(h)
    h.run("resume")
    #expect(h.controller.isRunning)
    let moves = h.system.frameLog.count
    doubt(h)
    #expect(h.controller.isRunning && !h.controller.isPaused, "\(h.run("status").message)")
    #expect(h.system.frameLog.count == moves)
  }

  // MARK: How long is a doubt

  /// Arbor hears of the loss late (two noes, up to two and a half seconds) and of the return late (a question a second). Whatever the moment:
  /// a loss shorter than three seconds ends nothing, and one of seven seconds is somebody's doing.
  @Test(arguments: [0.1, 0.5, 1.0, 1.5, 1.9]) func aLossShorterThanThreeSecondsEndsNothing(secondsBeforeAQuestion: Double) {
    for tenths in 6...80 {
      let length = Double(tenths) / 10
      let (h, _, _, _, _) = makeHarness()
      h.run("pause")  // the next question is due two seconds from here
      h.scheduler.advance(by: 2 - secondsBeforeAQuestion)
      h.revokeAccessibility()
      h.scheduler.advance(by: length)
      h.grantAccessibility()
      h.scheduler.advance(by: 1.1)
      if length < 3 { #expect(h.controller.isPaused, "gone for \(length) s") }
      if length >= 7 { #expect(h.controller.isRunning, "gone for \(length) s") }
    }
  }

  /// Believed at once, because something was asked of Arbor. Then what Arbor counts is the loss's own length.
  @Test(arguments: [0.5, 1.5, 2.1, 2.5, 2.9, 3.0, 3.1, 4.0]) func aLossThatIsBelievedAtOnceIsMeasuredToTheLastNo(length: Double) {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    h.scheduler.advance(by: 11)
    h.revokeAccessibility()
    h.run("show-all")
    #expect(h.controller.permissionLoss != nil)
    h.scheduler.advance(by: length)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.accessibilityGranted)
    #expect(h.controller.isPaused == (length < 3), "gone for \(length) s")
  }

  /// Timers stand still while a Mac sleeps, and the clock on the wall does not. One question later the permission was back: nobody mended anything.
  @Test func theMacSleepsInTheDoubt() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    doubt(h) {
      let now = h.controller.now
      h.controller.now = { now().addingTimeInterval(3600) }
    }
    #expect(h.controller.isPaused, "\(h.run("status").message)")
  }
}
