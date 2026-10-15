import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A key that Arbor claims never reaches another app (collab/IDEAS.md, I16).
///
/// On a tester's Mac ⌃⌥A ran the ⌃⌥A of the app in front, and that could not be taken back. A hot key that is registered is taken from
/// every app, so the question is in which states Arbor, alive and with its item in the menu bar, holds none. Here each of them is played: a shortcut
/// of the map in effect is pressed, and the stand-in for macOS writes down what the app in front was given.
@Suite @MainActor struct ClaimedKeysTests {
  /// Every shortcut in effect, pressed once. Returns the ones the app in front got.
  func pressEverything(_ h: Harness) -> [String] {
    let before = h.system.keysTheAppInFrontGot.count
    for binding in h.controller.effectiveBindings.bindings {
      // Whatever ends the state that is being asked about proves nothing about it.
      if binding.command.endsPause || binding.command == .pause(minutes: nil) { continue }
      h.key(binding.chord.text)
    }
    return h.system.keysTheAppInFrontGot.dropFirst(before).map(\.text)
  }

  func line(_ h: Harness) -> String? { h.overlays.headsUp[h.display]?.line }

  // MARK: The control

  @Test func whileArborRunsTheAppGetsNoneOfItsKeysAndEveryOtherKey() {
    let h = Harness()
    h.system.open(app: "Chat")
    h.start()
    #expect(pressEverything(h) == [])
    h.key("ctrl+opt+shift+cmd+f12")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+shift+cmd+f12"], "the stand-in does hand a key over")
  }

  // MARK: Arbor cannot act, and takes the key all the same

  /// A first launch, and every launch of a new build whose signature the old grant does not fit: the item is in the menu bar.
  @Test func whileItWaitsForThePermissionNoKeyOfItsReachesTheApp() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.revokeAccessibility()
    h.controller.accessibilityGranted = false
    #expect(pressEverything(h) == [])
    let reply = h.key("ctrl+opt+z")
    #expect(reply?.ok == false)
    #expect(line(h) == "Arbor needs the Accessibility permission · System Settings → Privacy & Security → Accessibility")
    #expect(h.system.frameLog.isEmpty, "and nothing has moved")
  }

  @Test func afterThePermissionWasTakenAwayNoKeyOfItsReachesTheApp() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.start()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.permissionLoss?.windows == 0, "nothing is out of view: the case in which Arbor held nothing at all")
    #expect(pressEverything(h) == [])
    #expect(line(h) == "Arbor needs the Accessibility permission · System Settings → Privacy & Security → Accessibility")
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning)
    #expect(pressEverything(h) == [])
  }

  /// A second's doubt about the permission is a state like the others: nobody said anything.
  @Test func aFalseAlarmLetsGoOfNothing() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.start()
    var held: [Int] = []
    h.controller.observe { [controller = h.controller] change in
      if change == .lifecycle || change == .input { held.append(controller.activeBindings.count) }
    }
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning && !held.isEmpty)
    #expect(Set(held) == [KeyBindings.defaults.count], "whenever the app is told to look again, the answer is the same: \(held)")
  }

  /// Only someone who misses a window is led to System Settings. Everybody else stays in the app they are in.
  @Test func onlyAWayHomeWithWindowsOutOfViewLeadsToSystemSettings() {
    let h = Harness()
    h.watchAccessibility()
    let chat = h.system.open(app: "Chat"), notes = h.system.open(app: "Notes")
    h.start()
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.shouldOpenAccessibilitySettings(after: .showAll), "nothing is out of view")
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    h.run("dock \(chat.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("zoom \(chat.rawValue)")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.permissionLoss?.windows == 1)
    #expect(!h.controller.shouldOpenAccessibilitySettings(after: .undo))
    #expect(h.controller.shouldOpenAccessibilitySettings(after: .showAll))
  }

  // MARK: The person said so themselves: the keys are the app's

  /// A pause lets go of the keys as well as of the windows: that is what the first person to use Arbor took it to mean. So it says so.
  @Test func aPauseByThePersonGivesTheKeysBackAndSaysSo() {
    let h = Harness()
    let chat = h.system.open(app: "Chat")
    h.start()
    h.run("dock \(chat.rawValue) left")
    h.key("ctrl+opt+escape")
    #expect(h.controller.isPaused)
    #expect(line(h) == "Arbor is paused: its keys are the apps’ again · ⌃⌥⎋ resumes")
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
    h.key("ctrl+opt+escape")
    #expect(h.controller.isRunning, "the one key that stays")
    #expect(pressEverything(h) == [])
  }

  @Test func aPauseWithAnEndSaysForHowLong() {
    let h = Harness()
    h.system.open(app: "Chat")
    h.start()
    h.run("pause 5", from: .menu)
    #expect(line(h) == "Arbor is paused for 5 minutes: its keys are the apps’ again · ⌃⌥⎋ resumes")
  }

  @Test func anAppOnThePersonsOwnListGetsTheKeys() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.chat"]
    let h = Harness(settings: settings)
    let chat = h.system.open(app: "Chat", bundleID: "com.example.chat")
    h.start()
    h.system.userFocus(chat)
    #expect(h.controller.isPassingThrough)
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  @Test func anAppArborPausesForGetsTheKeys() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    let game = h.system.open(app: "Game", bundleID: "com.example.game")
    h.start()
    h.system.userFocus(game)
    #expect(h.controller.isPaused)
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  /// Its list holds while Arbor cannot act, too: an editor's C-M- must not go dead because a permission is missing.
  @Test func anAppOnTheListGetsTheKeysWhileArborWaitsForThePermission() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.chat"]
    let h = Harness(settings: settings)
    h.watchAccessibility()
    h.revokeAccessibility()
    h.controller.accessibilityGranted = false
    h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.chat", name: "Chat"))
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  @Test func withShortcutsSwitchedOffArborClaimsNothing() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let h = Harness(settings: settings)
    h.system.open(app: "Chat")
    h.start()
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  // MARK: What an adversarial reader found

  /// A logout has begun, and Arbor lets go of the windows for two minutes. Any app can cancel a logout: the session goes on, the item is there, and
  /// nobody paused anything.
  @Test func thePauseArborTakesAtALogoutGivesNoKeyAway() {
    let h = Harness()
    h.system.open(app: "Chat")
    h.start()
    h.controller.sessionIsEnding()
    #expect(h.controller.isPaused)
    #expect(pressEverything(h) == [])
    #expect(line(h) == "Arbor is paused · ⌃⌥⎋ resumes")
    h.key("ctrl+opt+escape")
    #expect(h.controller.isRunning)
    // A pause the person then takes is theirs.
    h.key("ctrl+opt+escape")
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  /// `pauseForApps` is the person's word as much as `passThroughApps` is, also while Arbor cannot pause for anybody.
  @Test func anAppArborPausesForGetsTheKeysWhileArborCannotAct() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    h.watchAccessibility()
    let notes = h.system.open(app: "Notes"), game = h.system.open(app: "Game", bundleID: "com.example.game")
    h.start()
    h.system.userFocus(notes)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.isEmpty, "Notes is on no list")
    h.system.userFocus(game)
    h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.game", name: "Game"))
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  @Test func theLossThatStrikesDuringAPauseForAnAppLeavesItTheKeys() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let h = Harness(settings: settings)
    h.watchAccessibility()
    let game = h.system.open(app: "Game", bundleID: "com.example.game")
    h.start()
    h.system.userFocus(game)
    #expect(h.controller.isPaused)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.permissionLoss != nil)
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  /// The person paused Arbor, and then the permission goes, or is doubted for a second. The pause is over by F63; the keys they gave away are not
  /// taken back behind their back while nothing can be done with them.
  @Test func theLossThatStrikesDuringAPauseByHandTakesNoKeyBack() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.start()
    h.key("ctrl+opt+escape")
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(h.controller.permissionLoss != nil)
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning, "granting it again means wanting Arbor")
    #expect(pressEverything(h) == [])
  }

  /// `start()` compares the displays with what they were when Arbor stopped, and ends the undo history if one changed. A key pressed meanwhile
  /// must not make it forget what they were.
  @Test func aKeyPressedDuringTheLossDoesNotHideThatADisplayChanged() {
    func play(pressing: Bool) -> String {
      let h = Harness()
      h.watchAccessibility()
      let chat = h.system.open(app: "Chat")
      h.start()
      h.run("dock \(chat.rawValue) left")
      h.revokeAccessibility()
      h.scheduler.advance(by: 3)
      let display = h.system.displayList[0]
      h.system.setDisplays([
        DisplaySnapshot(
          id: display.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 640), visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 615), isMain: true)
      ])
      if pressing { h.key("ctrl+opt+left") }
      h.grantAccessibility()
      h.scheduler.advance(by: 3)
      return h.run("undo").message
    }
    #expect(play(pressing: true) == play(pressing: false))
  }

  /// The line is about the permission. Whatever else goes wrong meanwhile has a reason of its own.
  @Test func anotherFailureWithoutThePermissionKeepsItsOwnWords() {
    let h = Harness()
    h.watchAccessibility()
    h.revokeAccessibility()
    h.controller.accessibilityGranted = false
    let reply = h.run("trace off", from: .menu)
    #expect(!reply.ok)
    #expect(line(h)?.hasPrefix("Arbor needs the Accessibility permission") != true, "\(reply.message): \(line(h) ?? "no line")")
  }

  @Test func theLineGoesWhenThePermissionComes() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.revokeAccessibility()
    h.launch()
    h.key("ctrl+opt+z")
    #expect(line(h) != nil)
    h.grantAccessibility()
    h.scheduler.advance(by: 1)
    #expect(h.controller.isRunning)
    #expect(line(h) == nil, "it is no longer true")
  }

  /// A launch reports the app in front before the first registration, as `FrontmostAppWatcher.start` does.
  @Test func aLaunchBehindAnAppOnTheListTakesNothingFromIt() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.chat"]
    let h = Harness(settings: settings)
    h.watchAccessibility()
    let chat = h.system.open(app: "Chat", bundleID: "com.example.chat")
    h.system.userFocus(chat)
    h.revokeAccessibility()
    h.launch()
    h.key("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }

  /// Taken, and nothing comes of it: no panel that would take the keyboard from the app, no overlay, no timer but the line's own.
  @Test func withoutThePermissionNoKeyOpensAnything() {
    let h = Harness()
    h.watchAccessibility()
    h.system.open(app: "Chat")
    h.revokeAccessibility()
    h.launch()
    #expect(pressEverything(h) == [])
    #expect(h.overlays.cheatSheets.isEmpty && h.overlays.minimaps.isEmpty && h.overlays.scenes.isEmpty)
    #expect(h.overlays.namePrompt == nil && h.overlays.finder == nil)
    h.scheduler.advance(by: 0.5)
    #expect(Set(h.scheduler.pendingKeys).subtracting(["heads-up", "the app waits for the permission"]) == [])
  }

  /// A key that stays down while its shortcut goes away sends its repeats to the app.
  @Test func theRepeatsOfAKeyNobodyHoldsAnyMoreGoToTheApp() {
    let h = Harness()
    h.system.open(app: "Chat")
    h.start()
    h.keyDown("ctrl+opt+escape")
    #expect(h.controller.isPaused)
    h.keyRepeat("ctrl+opt+z")
    #expect(h.system.keysTheAppInFrontGot.map(\.text) == ["ctrl+opt+z"])
  }
}
