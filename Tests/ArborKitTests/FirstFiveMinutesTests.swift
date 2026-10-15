import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The first five minutes, played through: a Mac as it comes, an Arbor that has never run, a person who reads the welcome window and does
/// what it says. The real controller and the real `OnboardingSession`; only AppKit is missing. `scripts/mac-shell/first-five-minutes.sh`
/// plays the same on a hosted Mac, and `arbor-sim first-launch` lets anybody play it by hand.
///
/// Issue #3, rules 1 and 2: nothing moves; before anything is arranged Arbor has looked for macOS's own tiling and the wallpaper
/// click, says what they do, and offers the fix in one step, with the way back; then the first dock is invited.
@Suite @MainActor struct FirstFiveMinutesTests {
  /// Three windows of the person's own, and what has been done to them.
  func makeDesk() -> (Harness, [WindowID], [CGRect?]) {
    let h = Harness()
    let windows = [
      h.system.open(app: "Safari", frame: CGRect(x: 200, y: 120, width: 800, height: 600)),
      h.system.open(app: "Mail", frame: CGRect(x: 420, y: 200, width: 700, height: 500)),
      h.system.open(app: "Notes", frame: CGRect(x: 640, y: 300, width: 500, height: 400)),
    ]
    return (h, windows, windows.map { h.frame($0) })
  }

  func nothingHasMoved(_ h: Harness, _ windows: [WindowID], _ found: [CGRect?]) -> Bool {
    windows.map { h.frame($0) } == found && h.system.frameLog.isEmpty
  }

  /// The whole window, word for word, as every newcomer meets it. Whoever changes a word changes it here, and reads the page again.
  /// The first minute asks for the one permission and for nothing else (Q29, 11).
  @Test func theFirstThingANewcomerReads() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime()
    #expect(
      h.welcome.text == """
        Arbor keeps your windows arranged
        Arrange windows side by side once. Fill the screen with any one, and one key brings the arrangement back. Your Mac’s own tiling forgets an arrangement; Arbor keeps it.

        → Accessibility (Required)  [Open Settings…]
            macOS asks your permission before an app may move other apps’ windows. Arbor reads only each window’s position and title, and nothing leaves your Mac. Flip the switch next to Arbor in System Settings. This window comes back by itself.

        Nothing moves until you ask. ⌃⌥⌘← and ⌃⌥⌘→ put a window left or right. ⌃⌥↩ fills the screen with it, and brings both back.
        ⌃ is Control, ⌥ Option, ⌘ Command, ↩ Return.

        Arbor lives in the menu bar, under this icon.
        (Continue)
        """)
  }

  /// The way most will go: the permission, then the four moves as they are worded, on a Mac as it comes. Nothing of macOS's is touched or
  /// spoken of.
  @Test func thePermissionAndTheFourMoves() throws {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    #expect(h.welcome.isOpen && !h.controller.isRunning)
    #expect(nothingHasMoved(h, windows, found))

    // macOS asks with its own dialog, whose button opens the pane. Arbor opens nothing over it, or it would be left lying.
    #expect(h.welcome.click("Open Settings…"))
    h.scheduler.advance(by: 5)
    #expect(h.welcome.timesMacOSWasAsked == 1 && h.welcome.macOSsDialogIsOpen && h.welcome.panesOpened.isEmpty)
    h.welcome.clickOpenSystemSettingsInMacOSsDialog()
    #expect(h.welcome.panesOpened == [.accessibility] && !h.welcome.macOSsDialogIsOpen)
    // System Settings lies over the window; and back. There is nothing else to decide, so the window goes on.
    h.permissionArrives()
    #expect(h.welcome.timesComeForward == 1)
    #expect(h.welcome.model.page == .firstSteps)
    #expect(nothingHasMoved(h, windows, found), "no frame has been set")
    #expect(windows.allSatisfy { h.workspace.isFloating($0) })

    // The four moves, each made as it is worded.
    #expect(
      h.welcome.model.steps.map(\.lead) == [
        "Click a window and press ⌃⌥⌘←", "Click another and press ⌃⌥⌘→", "Then press ⌃⌥↩", "Press ⌃⌥↩ again",
      ])
    #expect(h.welcome.model.footnote == "Arbor lives in the menu bar, under this icon.", "during the moves, little but the moves")
    h.system.userFocus(windows[2])
    h.key("ctrl+opt+cmd+left")
    #expect(h.workspace.isDocked(windows[2]))
    #expect(h.welcome.model.steps.map(\.isDone) == [true, false, false, false])
    h.system.userFocus(windows[1])
    h.key("ctrl+opt+cmd+right")
    #expect(h.workspace.isDocked(windows[1]) && h.workspace.isFloating(windows[0]))
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, false, false])
    // The window keeps to the Desktop, which lies between the two, where the third window is. It follows at once.
    #expect(h.welcome.model.desktops == [h.layout?.desktopFrame])
    let arranged = windows.map { h.frame($0) }
    let framed = h.key("ctrl+opt+return")
    #expect(framed?.ok == true, "\(framed?.message ?? "no such shortcut")")
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, false])
    h.key("ctrl+opt+return")
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, true])
    #expect(windows.map { h.frame($0) } == arranged, "the arrangement is back")
    #expect(h.welcome.model.title == "That is all there is to it")
    #expect(h.welcome.model.summary == "The arrangement stays until you change it. ⌃⌥Z takes back the last change.")
    #expect(h.welcome.model.footnote.contains("Right-click it for all commands"), "the item is a row of buttons now")
    #expect(h.welcome.click("Done") && !h.welcome.isOpen)

    #expect(h.mac.writes.isEmpty && h.mac.before.isEmpty, "macOS's tiling is as its owner has it")
    #expect(h.controller.menuBarModel().icon == MenuBarModel.Icon())
    #expect(!h.controller.menuModel().text.contains("macOS"))
    // It has been seen, and does not open by itself again.
    #expect(h.controller.pageToWelcomeOn() == nil)
    h.scheduler.advance(by: 3600)
    #expect(!h.welcome.isOpen)
    expectWindowsMatchLayout(h)
  }

  /// The one way back the coach names does what it says.
  @Test func theWayBackTheCoachNames() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.welcome.click("Continue")
    #expect(h.welcome.model.wayBack == "⌃⌥⎋ pauses Arbor: every window is as it was. Quit does the same.")
    h.system.userFocus(windows[2])
    h.key("ctrl+opt+cmd+left")
    h.system.userFocus(windows[1])
    h.key("ctrl+opt+cmd+right")
    h.key("ctrl+opt+escape")
    #expect(h.controller.isPaused)
    #expect(windows.map { h.frame($0) } == found)
  }

  /// With the permission there already a newcomer is still told what Arbor is for first.
  @Test func withThePermissionThereTheFirstPageStillComesFirst() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    #expect(h.welcome.model.page == .permissions && h.welcome.model.title == "Arbor keeps your windows arranged")
    #expect(h.welcome.model.rows.map(\.id) == [.accessibility])
    #expect(h.welcome.buttons == ["Continue"])
    #expect(nothingHasMoved(h, windows, found))
  }

  /// What would make the keys of the four moves do two things at once is said all the same: no move is taught that cannot work.
  @Test func anotherWindowManagerIsNamedInTheFirstMinute() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    let facts = h.controller.systemFacts
    h.controller.systemFacts = {
      var facts = facts?() ?? SystemFacts(accessibility: true, screenRecording: false, switches: nil)
      facts.competingApps = ["Rectangle"]
      return facts
    }
    h.welcome.tick()
    #expect(h.welcome.model.rows.map(\.id) == [.accessibility, .competingApps])
  }

  // MARK: Check Setup…, for whoever asks

  /// A hand that drags to the edge of a Mac as it comes. macOS takes the window, Arbor stands aside and says who took it and where that can
  /// be changed; nothing is ticked that was not done. And there it can.
  @Test func whoeverDragsToTheEdgeIsToldWhoTookTheWindowAndWhereThatCanBeChanged() throws {
    let (h, windows, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.welcome.click("Continue")
    h.system.userFocus(windows[2])
    h.system.drag(windows[2], through: [CGPoint(x: 800, y: 310), CGPoint(x: 300, y: 350), CGPoint(x: 0, y: 400)])
    // It is said once macOS has moved the window.
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isFloating(windows[2]))
    #expect(h.welcome.model.steps.map(\.isDone) == [false, false, false, false])
    #expect(h.overlays.messages.last?.model.line == "macOS tiled this window; Arbor stood aside · ⌃⌥⌘← docks it · Check Setup… in the menu")

    h.run("check-setup")
    #expect(h.welcome.model.page == .setup && h.welcome.model.title == "Ready, with one suggestion")
    #expect(
      h.welcome.text?.contains(
        """
        * macOS tiling (Recommended)
            Your Mac tiles a window dragged to a screen edge, before Arbor gets it. Switch that off, only while Arbor runs, and Arbor has the edges.
            [Switch Off macOS Tiling] [Or do it yourself in Desktop & Dock…]
            Changes 3 settings in Desktop & Dock, nothing else: “Drag windows to left or right edge of screen to tile”, “Drag windows to menu bar to fill screen”, “Hold ⌥ key while dragging windows to tile”.
        """) == true)
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    #expect(h.mac.on == [.clickWallpaper], "the three, and nothing else")
    #expect(h.welcome.model.title == "Arbor is ready")
    #expect(h.welcome.text?.contains("✔ macOS tiling (Off)  [Put Them Back]") == true)
    #expect(h.welcome.text?.contains("While Arbor runs, 3 settings of macOS are off. Quit or pause Arbor, and your Mac is as it was.") == true)
    #expect(h.welcome.click("Done") && !h.welcome.isOpen)
    h.system.drag(windows[2], through: [CGPoint(x: 300, y: 40), CGPoint(x: 100, y: 350), CGPoint(x: 0, y: 400)])
    #expect(h.workspace.isDocked(windows[2]))
  }

  /// Without the permission the menu's only command is Check Setup…. It leads to the one thing there is to put right, and on from there.
  @Test func withoutThePermissionCheckSetupIsTheWelcome() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    h.run("check-setup")
    #expect(h.welcome.model.page == .permissions && h.welcome.model.rows.map(\.id) == [.accessibility])
    h.welcome.close()
    h.run("check-setup")
    #expect(h.welcome.isOpen && h.welcome.model.page == .permissions)
    h.permissionArrives()
    #expect(h.welcome.model.page == .firstSteps, "the four moves are not lost")
    #expect(nothingHasMoved(h, windows, found))
  }

  /// Taken from a terminal before the permission is there. Nothing of macOS's changes until Arbor may arrange windows, and the welcome does
  /// not speak of it.
  @Test func theStepTakenBeforeThePermissionWaitsForIt() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    let welcome = h.welcome.text
    #expect(h.run("fix-setup").message.hasPrefix("noted: "))
    #expect(h.mac.writes.isEmpty && h.welcome.text == welcome)
    h.permissionArrives()
    #expect(h.mac.on == [.clickWallpaper])
    #expect(h.welcome.model.page == .firstSteps)
    h.run("check-setup")
    #expect(h.welcome.text?.contains("✔ macOS tiling (Off)  [Put Them Back]") == true)
    #expect(nothingHasMoved(h, windows, found))
  }

  /// Arbor is opened again: the way in when the icon is hidden. A newcomer gets the welcome; whoever has used Arbor gets how things stand,
  /// which also has the way back from what Arbor did to this Mac.
  @Test func openingArborAgainShowsHowThingsStand() {
    let (h, windows, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.welcome.close()
    h.welcome.show(nil)
    #expect(h.welcome.model.page == .permissions, "nothing is docked yet: still a newcomer")
    h.welcome.close()
    h.run("fix-setup")
    h.run("dock \(windows[0].rawValue) left")
    h.welcome.show(nil)
    #expect(h.welcome.model.page == .setup && h.welcome.buttons.contains("Put Them Back"))
    // An open window stays as it is.
    h.run("welcome")
    h.welcome.show(nil)
    #expect(h.welcome.model.page == .firstSteps)
  }

  // MARK: The errand to System Settings

  /// macOS does not always ask. Then the button must not seem dead.
  @Test func whereMacOSDoesNotAskArborOpensThePane() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime()
    h.welcome.macOSAnswersWithItsDialog = false
    h.welcome.click("Open Settings…")
    #expect(h.welcome.panesOpened.isEmpty)
    h.scheduler.advance(by: 3)
    #expect(h.welcome.panesOpened == [.accessibility])
  }

  /// By then Arbor is in the list: the pane alone will do, and macOS is not made to ask again over it.
  @Test func aSecondClickOpensThePaneAndAsksNothing() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime()
    h.welcome.click("Open Settings…")
    h.welcome.click("Open Settings…")
    #expect(h.welcome.timesMacOSWasAsked == 1 && h.welcome.panesOpened == [.accessibility])
    h.scheduler.advance(by: 5)
    #expect(h.welcome.panesOpened == [.accessibility], "and not a second time by the clock")
  }

  /// Granted while macOS's second runs: nothing opens over whoever is at the four moves.
  @Test func grantedMeanwhileNothingOpens() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime()
    h.welcome.macOSAnswersWithItsDialog = false
    h.welcome.click("Open Settings…")
    h.permissionArrives()
    h.scheduler.advance(by: 5)
    #expect(h.welcome.panesOpened.isEmpty)
  }

  /// An Arbor that has had the permission is in the list: when it goes (F63) the pane is what is wanted, by Arbor's own word, whatever
  /// macOS's flag still says.
  @Test func anArborThatHadThePermissionIsSentStraightToThePane() {
    let (h, _, _) = makeDesk()
    h.watchAccessibility()
    h.launchForTheFirstTime(permitted: true)
    h.revokeAccessibility()
    h.scheduler.advance(by: 3)
    #expect(!h.controller.accessibilityGranted)
    h.controller.sendToAccessibilitySettings()
    #expect(h.welcome.timesMacOSWasAsked == 0 && h.welcome.panesOpened == [.accessibility])
  }

  /// A week later: the way back is where the window said it would be, and leaves the Mac as Arbor found it.
  @Test func theWayBackIsWhereItWasPromised() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.run("check-setup")
    h.welcome.click("Switch Off macOS Tiling")
    h.welcome.close()
    #expect(h.controller.menuModel().text.contains("Check Setup…"))
    h.run("check-setup")
    #expect(h.welcome.click("Put Them Back"))
    #expect(h.mac.values.isEmpty && h.mac.before.isEmpty)
    #expect(h.welcome.buttons.contains("Switch Off macOS Tiling"))
  }

  /// A step that fails is said beside the button, and not on a page it was not pressed on.
  @Test func aFailureIsSaidOnThePageItHappenedOn() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.run("check-setup")
    h.mac.managed = [.screenEdges]
    h.welcome.click("Switch Off macOS Tiling")
    #expect(h.welcome.model.row(.desktopAndDock)?.failure.hasPrefix("That did not work: ") == true)
    h.run("welcome")
    h.run("check-setup")
    #expect(h.welcome.model.row(.desktopAndDock)?.failure.isEmpty == true)
  }

  /// Closing it half-way blocks nothing (F46, acceptance 3), and quitting leaves every window as it was found.
  @Test func closedHalfWayAndQuit() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    h.permissionArrives()
    h.welcome.close()
    #expect(h.run("dock \(windows[0].rawValue) left").ok)
    h.controller.shutdown()
    #expect(windows.map { h.frame($0)?.size } == found.map { $0?.size }, "their own sizes")
  }

  /// Every button the window shows can be clicked, on every page it can be on, and none of them moves a window.
  @Test func noButtonOfTheWindowMovesAWindow() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    var clicked: Set<String> = []
    for page in ["welcome", "check-setup"] {
      for _ in 0..<12 {
        guard let next = h.welcome.buttons.first(where: { !clicked.contains($0) && $0 != "Done" }) else { break }
        clicked.insert(next)
        #expect(h.welcome.click(next), "\(next)")
      }
      h.run(page)
    }
    for _ in 0..<12 {
      guard let next = h.welcome.buttons.first(where: { !clicked.contains($0) && $0 != "Done" }) else { break }
      clicked.insert(next)
      #expect(h.welcome.click(next), "\(next)")
    }
    #expect(clicked.isSuperset(of: ["Switch Off macOS Tiling", "Put Them Back", "Or do it yourself in Desktop & Dock…", "Continue", "Back"]))
    #expect(nothingHasMoved(h, windows, found))
  }
}
