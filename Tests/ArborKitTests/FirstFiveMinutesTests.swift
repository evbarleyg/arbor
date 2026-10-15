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
  @Test func theFirstThingANewcomerReads() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime()
    #expect(
      h.welcome.text == """
        Arbor keeps your windows arranged
        Arrange windows side by side once. Fill the screen with any one, and one key brings the arrangement back. Your Mac’s own tiling forgets an arrangement; Arbor keeps it. Nothing moves until you “dock” a window: put it at a side of the screen.

        → Accessibility (Required)  [Open Settings…]
            macOS asks your permission before an app may move other apps’ windows. Arbor reads only each window’s position and title, and nothing leaves your Mac. Flip the switch next to Arbor in System Settings. This window comes back by itself.
        * macOS tiling (Recommended)
            Your Mac has window tiling of its own: drag a window to a screen edge, and macOS reacts before Arbor can. Switch it off, and you dock with the mouse. Leave it on, and you dock with the keyboard. It is off only while Arbor runs: quit Arbor, and your Mac is as it was.
            [Switch Off macOS Tiling] [Or do it yourself in Desktop & Dock…]
            Changes 3 settings in Desktop & Dock, nothing else: “Drag windows to left or right edge of screen to tile”, “Drag windows to menu bar to fill screen”, “Hold ⌥ key while dragging windows to tile”. A Put Them Back button appears here afterwards.

        (Continue)
        """)
  }

  /// The way most will go: the permission, the one step, the four moves as they are worded.
  @Test func thePermissionTheOneStepAndTheFourMoves() throws {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    #expect(h.welcome.isOpen && !h.controller.isRunning)
    #expect(nothingHasMoved(h, windows, found))

    // Off to System Settings, which lies over the window, and back.
    #expect(h.welcome.click("Open Settings…"))
    #expect(h.welcome.panesOpened == [.accessibility])
    h.permissionArrives()
    #expect(h.welcome.timesComeForward == 1)
    #expect(h.welcome.model.title == "Arbor keeps your windows arranged" && h.welcome.model.page == .permissions)
    #expect(h.welcome.text?.contains("* macOS tiling (Recommended)") == true, "how it stands is in the rows")
    #expect(nothingHasMoved(h, windows, found), "the findings are on show, and no frame has been set")
    #expect(windows.allSatisfy { h.workspace.isFloating($0) })

    // One click.
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    #expect(h.mac.on == [.clickWallpaper], "the three, and nothing else")
    #expect(h.welcome.text?.contains("✔ macOS tiling (Off)  [Put Them Back]") == true)
    #expect(h.welcome.text?.contains("While Arbor runs, 3 settings of macOS are off. Quit or pause Arbor, and your Mac is as it was.") == true)
    #expect(h.welcome.text?.contains("A window dragged to a screen edge docks now.") == true)
    #expect(nothingHasMoved(h, windows, found))

    // The four moves, each made as it is worded.
    #expect(h.welcome.click("Continue"))
    #expect(
      h.welcome.model.steps.map(\.lead) == [
        "Drag a window to the left edge of the screen", "Drag another to the right edge", "Then press ⌃⌥↩", "Then press ⌃⌥Space",
      ])
    #expect(h.welcome.model.footnote == "Arbor lives in the menu bar, under this icon.", "during the moves, little but the moves")
    // The press on a title bar brings the window forward, which the stand-in's drag leaves to its caller.
    h.system.userFocus(windows[2])
    h.system.drag(windows[2], through: [CGPoint(x: 800, y: 310), CGPoint(x: 300, y: 350), CGPoint(x: 0, y: 400)])
    #expect(h.workspace.isDocked(windows[2]))
    #expect(h.welcome.model.steps.map(\.isDone) == [true, false, false, false])
    h.system.userFocus(windows[1])
    h.system.drag(windows[1], through: [CGPoint(x: 700, y: 210), CGPoint(x: 1200, y: 350), CGPoint(x: 1439, y: 400)])
    #expect(h.workspace.isDocked(windows[1]) && h.workspace.isFloating(windows[0]))
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, false, false])
    // The window keeps to the Desktop, which lies between the two, where the third window is. It follows at once.
    #expect(h.welcome.model.desktops == [h.layout?.desktopFrame])
    let framed = h.key("ctrl+opt+return")
    #expect(framed?.ok == true, "\(framed?.message ?? "no such shortcut")")
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, false])
    h.key("ctrl+opt+space")
    #expect(h.welcome.model.title == "That is all there is to it")
    #expect(h.welcome.model.footnote.contains("Right-click it for all commands"), "the item is a row of buttons now")
    // The way back is at hand where the moves end, too.
    #expect(h.welcome.text?.contains("macOS tiling is off while Arbor runs: drag a window to a screen edge, and it docks. [Put Them Back]") == true)

    // One more, for whoever likes: the window that was left lying.
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, true, false])
    #expect(h.welcome.model.steps.last?.lead == "One more, if you like: drag a third onto the edge of a docked one")
    let docked = try #require(h.frame(windows[2]))
    h.system.userFocus(windows[0])
    h.system.drag(windows[0], through: [CGPoint(x: 600, y: 130), CGPoint(x: docked.midX, y: 700), CGPoint(x: docked.midX, y: docked.maxY - 20)])
    #expect(h.workspace.isDocked(windows[0]))
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, true, true])
    #expect(h.welcome.click("Done") && !h.welcome.isOpen)

    // It has been seen, and does not open by itself again.
    #expect(h.controller.pageToWelcomeOn() == nil)
    expectWindowsMatchLayout(h)
  }

  /// Somebody who takes the step first and grants the permission second. Nothing of macOS's changes until Arbor may arrange windows.
  @Test func theStepTakenBeforeThePermissionWaitsForIt() {
    let (h, windows, found) = makeDesk()
    h.launchForTheFirstTime()
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    #expect(h.mac.writes.isEmpty)
    #expect(h.welcome.text?.contains("i macOS tiling (On for now)") == true)
    #expect(
      h.welcome.text?.contains(
        "Until Arbor may arrange windows, macOS keeps its tiling. Arbor switches it off when it starts, and only while it runs. [Leave Them On]")
        == true)
    h.permissionArrives()
    #expect(h.mac.on == [.clickWallpaper])
    #expect(h.welcome.model.page == .firstSteps, "nothing is left to decide on the first page")
    #expect(h.welcome.model.step(.dock)?.lead == "Drag a window to the left edge of the screen")
    #expect(nothingHasMoved(h, windows, found))
  }

  /// Somebody who passes the offer by. No move is taught that cannot work on this Mac as it is set (Q23), and nothing reminds them.
  @Test func whoeverDeclinesIsTaughtMovesThatWorkAndIsLeftInPeace() throws {
    let (h, windows, _) = makeDesk()
    h.launchForTheFirstTime()
    h.permissionArrives()
    #expect(h.welcome.click("Continue"))
    #expect(
      h.welcome.model.steps.map(\.lead) == [
        "Click a window and press ⌃⌥⌘←", "Click another and press ⌃⌥⌘→", "Then press ⌃⌥↩", "Then press ⌃⌥Space",
      ])
    h.system.userFocus(windows[0])
    h.key("ctrl+opt+cmd+left")
    h.system.userFocus(windows[1])
    h.key("ctrl+opt+cmd+right")
    h.key("ctrl+opt+return")
    #expect(h.welcome.model.offer == nil, "not in the middle of the moves")
    h.key("ctrl+opt+space")
    #expect(h.welcome.model.steps.map(\.isDone) == [true, true, true, true, false])
    // The offer once more, where it is understood. It is passed by again.
    #expect(
      h.welcome.text?.contains("Want to dock with the mouse too? Only while Arbor runs: quit, and your Mac is as it was. [Switch Off macOS Tiling]")
        == true)
    #expect(h.welcome.click("Done"))

    #expect(h.mac.writes.isEmpty, "declined is declined")
    #expect(h.controller.menuBarModel().icon == MenuBarModel.Icon())
    #expect(!h.controller.menuModel().text.contains("macOS"))
    h.scheduler.advance(by: 3600)
    #expect(!h.welcome.isOpen)
    // The offer is where it was said to be.
    #expect(h.run("check-setup").ok)
    #expect(h.welcome.buttons.contains("Switch Off macOS Tiling"))
  }

  /// Somebody who made the moves with the keys and now knows what the edges are for.
  @Test func afterTheMovesTheOfferCanBeTakenWhereItStands() throws {
    let (h, windows, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.welcome.click("Continue")
    h.system.userFocus(windows[0])
    h.key("ctrl+opt+cmd+left")
    h.system.userFocus(windows[1])
    h.key("ctrl+opt+cmd+right")
    h.key("ctrl+opt+return")
    h.key("ctrl+opt+space")
    let before = windows.map { h.frame($0) }
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    #expect(h.mac.on == [.clickWallpaper])
    #expect(h.welcome.model.page == .firstSteps, "it stays where it was clicked")
    #expect(h.welcome.text?.contains("macOS tiling is off while Arbor runs: drag a window to a screen edge, and it docks. [Put Them Back]") == true)
    #expect(h.welcome.click("Put Them Back"))
    #expect(h.mac.values.isEmpty && h.mac.before.isEmpty)
    #expect(h.welcome.text?.contains("Want to dock with the mouse too?") == true)
    #expect(windows.map { h.frame($0) } == before, "no window moves for either")
    // A step that fails is said beside the button.
    h.mac.managed = [.screenEdges]
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    #expect(h.welcome.model.offer?.failure.hasPrefix("That did not work: ") == true)
    // Beside the button that was pressed, and not on the page it was not pressed on.
    h.welcome.click("Back")
    #expect(h.welcome.model.row(.desktopAndDock)?.failure.isEmpty == true)
  }

  /// The other way round: a step that failed on the first page is not held against an offer nobody has taken.
  @Test func aFailureOnTheFirstPageIsNotShownUnderTheOfferAfterTheMoves() {
    let (h, windows, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.mac.managed = [.screenEdges]
    h.welcome.click("Switch Off macOS Tiling")
    #expect(h.welcome.model.row(.desktopAndDock)?.failure.isEmpty == false)
    h.welcome.click("Continue")
    h.system.userFocus(windows[0])
    h.key("ctrl+opt+cmd+left")
    h.system.userFocus(windows[1])
    h.key("ctrl+opt+cmd+right")
    h.key("ctrl+opt+return")
    h.key("ctrl+opt+space")
    #expect(h.welcome.model.offer?.text == "Want to dock with the mouse too? Only while Arbor runs: quit, and your Mac is as it was.")
    #expect(h.welcome.model.offer?.failure.isEmpty == true)
  }

  /// A hand that has read nothing drags to the edge all the same. macOS takes the window, Arbor stands aside and says who took it and where
  /// that can be changed; nothing is ticked that was not done.
  @Test func whoeverDragsToTheEdgeAllTheSameIsToldWhoTookTheWindow() throws {
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
    // And there it can.
    h.run("check-setup")
    #expect(h.welcome.click("Switch Off macOS Tiling"))
    h.welcome.click("Continue")
    h.system.drag(windows[2], through: [CGPoint(x: 300, y: 40), CGPoint(x: 100, y: 350), CGPoint(x: 0, y: 400)])
    #expect(h.workspace.isDocked(windows[2]))
    #expect(h.welcome.model.step(.dock)?.isDone == true)
  }

  /// The words follow the switch on a window that is showing, whoever flips it, without a restart.
  @Test func theFirstMoveFollowsTheSwitchWhileItIsShowing() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    #expect(h.welcome.model.page == .permissions, "with the permission there already, the offer still comes first")
    h.welcome.click("Continue")
    #expect(h.welcome.model.step(.dock)?.lead == "Click a window and press ⌃⌥⌘←")
    // In System Settings.
    h.mac.values[.screenEdges] = false
    h.welcome.tick()
    #expect(h.welcome.model.step(.dock)?.lead == "Drag a window to the left edge of the screen")
    h.mac.values[.screenEdges] = nil
    h.welcome.tick()
    #expect(h.welcome.model.step(.dock)?.lead == "Click a window and press ⌃⌥⌘←")
  }

  /// A week later: the way back is where the window said it would be, and leaves the Mac as Arbor found it.
  @Test func theWayBackIsWhereItWasPromised() {
    let (h, _, _) = makeDesk()
    h.launchForTheFirstTime(permitted: true)
    h.welcome.click("Switch Off macOS Tiling")
    h.welcome.close()
    #expect(h.controller.menuModel().text.contains("Check Setup…"))
    h.run("check-setup")
    #expect(h.welcome.click("Put Them Back"))
    #expect(h.mac.values.isEmpty && h.mac.before.isEmpty)
    #expect(h.welcome.buttons.contains("Switch Off macOS Tiling"))
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
    for _ in 0..<12 {
      guard let next = h.welcome.buttons.first(where: { !clicked.contains($0) && $0 != "Done" }) else { break }
      clicked.insert(next)
      #expect(h.welcome.click(next), "\(next)")
    }
    #expect(clicked.isSuperset(of: ["Switch Off macOS Tiling", "Put Them Back", "Or do it yourself in Desktop & Dock…", "Continue", "Back"]))
    #expect(nothingHasMoved(h, windows, found))
  }
}
