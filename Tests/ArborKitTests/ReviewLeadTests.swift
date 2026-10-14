import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
/// To the right of the main display.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
/// To the left of the main display and above it: negative coordinates.
private let far = DisplaySnapshot(
  id: DisplayID("far"), frame: CGRect(x: -1920, y: -300, width: 1920, height: 1080),
  visibleFrame: CGRect(x: -1920, y: -300, width: 1920, height: 1080), isMain: false)

/// F56 as a reviewer meets it: three displays, and the orders in which macOS really reports things
/// (collab/evidence/ax-events.txt).
@Suite @MainActor struct ReviewLeadTests {
  /// Two windows side by side on each display, the left one framed.
  struct Desk {
    let h: Harness
    let displays: [DisplaySnapshot]
    /// The left and the right window of each display, in the order of `displays`.
    var left: [WindowID] = []
    var right: [WindowID] = []

    @MainActor init(_ displays: [DisplaySnapshot], settings: Settings = Settings()) {
      self.displays = displays
      h = Harness(displays: displays, settings: settings)
      for (index, display) in displays.enumerated() {
        let origin = display.frame.origin
        left.append(
          h.system.open(app: "Left\(index)", frame: CGRect(x: origin.x + 100, y: origin.y + 100, width: 400, height: 400)))
        right.append(
          h.system.open(app: "Right\(index)", frame: CGRect(x: origin.x + 700, y: origin.y + 100, width: 400, height: 400)))
      }
      h.start()
      for index in displays.indices {
        h.run("dock \(left[index].rawValue) left")
        h.run("dock \(right[index].rawValue) right")
        h.run("zoom \(left[index].rawValue)")
      }
    }

    @MainActor func isFramed(_ index: Int) -> Bool {
      let workspace = h.controller.workspaces[displays[index].id]!
      return workspace.camera == workspace.tree.leaf(containing: left[index])
    }

    @MainActor var framed: [Bool] { displays.indices.map(isFramed) }

    @MainActor func point(_ index: Int) {
      h.system.cursor = CGPoint(x: displays[index].frame.minX + 300, y: displays[index].frame.minY + 300)
    }

    /// The pointer is left on one display; ⌘Tab to a window of another, and type.
    @MainActor func restPointer(on pointer: Int, typeIn window: WindowID) {
      point(pointer)
      h.scheduler.advance(by: 5)
      h.system.userFocus(window)
      h.scheduler.advance(by: 1)
      h.system.type()
      h.scheduler.advance(by: 0.3)
    }
  }

  // MARK: Three displays

  @Test func withThreeDisplaysOnlyTheOneBeingTypedOnChanges() {
    let desk = Desk([main, side, far])
    desk.restPointer(on: 1, typeIn: desk.left[2])
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [true, true, false])
    // Pointing at the main display, the third of the three.
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [false, true, false])
    #expect(desk.h.run("out", from: .gesture).ok == false, "the pointer's display already shows everything")
    #expect(desk.framed == [false, true, false])
  }

  // MARK: Scripts

  /// What a script that calls `arborctl show-all` gets: today's behaviour after pointing or with the
  /// setting, the focused window's display after typing (the command line it was typed on, say).
  @Test func aScriptKeepsThePointersDisplayAfterPointingOrWithTheSetting() {
    let pointed = Desk([main, side])
    pointed.restPointer(on: 1, typeIn: pointed.left[1])
    pointed.h.scheduler.advance(by: 1)
    pointed.point(0)
    pointed.h.scheduler.advance(by: 30)
    #expect(pointed.h.run("show-all", from: .script).ok)
    #expect(pointed.framed == [false, true])

    var settings = Settings()
    settings.stepInToward = "pointer"
    let fixed = Desk([main, side], settings: settings)
    fixed.restPointer(on: 0, typeIn: fixed.left[1])
    #expect(fixed.h.run("show-all", from: .script).ok)
    #expect(fixed.framed == [false, true])

    let typed = Desk([main, side])
    typed.restPointer(on: 0, typeIn: typed.left[1])
    #expect(typed.h.run("show-all", from: .script).ok)
    #expect(typed.framed == [true, false])
  }

  // MARK: What macOS reports, and when

  /// An app in the background reports a focus change (a chat window opened by a notification). The keyboard
  /// did not move, so somebody who has just pointed at a display still means that display.
  @Test func aFocusReportFromTheBackgroundDoesNotTakeTheLeadFromThePointer() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 0.2)
    desk.h.system.backgroundFocus(desk.right[1])
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [false, true])
  }

  /// The same report between two shortcuts: the second goes on where the first went.
  @Test func aFocusReportFromTheBackgroundDoesNotSplitTwoShortcuts() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.press("out").ok)
    desk.h.scheduler.advance(by: 0.5)
    desk.h.system.backgroundFocus(desk.right[1])
    desk.h.scheduler.advance(by: 0.5)
    #expect(desk.h.press("in").ok)
    #expect(desk.framed == [true, true])
  }

  /// Another app comes forward by itself after the pointer stopped, and its own focused window is the one it
  /// had: macOS sends no "focused window changed". The keyboard is there now, and nobody has pointed since.
  /// With or without the focus ring, which listens to the same events.
  @Test(arguments: [true, false]) func anAppThatComesForwardByItselfTakesTheLead(ring: Bool) {
    var settings = Settings()
    settings.focusRing = ring
    let desk = Desk([main, side], settings: settings)
    desk.restPointer(on: 0, typeIn: desk.left[0])
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 3)
    desk.h.system.userSwitchesApp(to: desk.left[1])
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [true, false])
  }

  /// Shortcuts stay with the first one's choice only while nothing else happens: the keyboard going elsewhere ends it.
  @Test func aFocusChangeBetweenTwoShortcutsGivesTheLeadToTheKeyboard() {
    let desk = Desk([main, side, far])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [false, true, true])
    desk.h.scheduler.advance(by: 1)
    desk.h.system.userSwitchesApp(to: desk.left[2])
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [false, true, false])
  }

  /// Across apps the report can come first and the app come forward a moment later (ax-events.txt, "a person clicks
  /// 32"): at the report the keyboard is still where it was.
  @Test func aReportThatComesBeforeItsAppIsInFrontStillCounts() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[0])
    desk.h.scheduler.advance(by: 2)
    desk.point(0)
    desk.h.scheduler.advance(by: 3)
    desk.h.system.backgroundFocus(desk.left[1])
    desk.h.scheduler.advance(by: 0.08)
    desk.h.system.userSwitchesApp(to: desk.left[1])
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.press("out").ok)
    #expect(desk.framed == [true, false])
  }

  /// The focused window closes and the keyboard goes to a window on another display.
  @Test func whenTheFocusedWindowClosesTheShortcutFollowsTheKeyboardToItsNewDisplay() {
    let desk = Desk([main, side, far])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.system.close(desk.left[1])
    desk.h.system.userSwitchesApp(to: desk.left[2])
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.press("out").ok)
    #expect(desk.isFramed(0))
    #expect(!desk.isFramed(2))
  }

  /// Focus arrives before "un-minimized" (ax-events.txt). A shortcut in between must not crash or act on nothing.
  @Test func aFocusedWindowThatIsStillMinimizedIsSurvived() {
    let desk = Desk([main, side])
    desk.h.run("show-all", from: .script)
    desk.restPointer(on: 0, typeIn: desk.right[1])
    desk.h.system.setMinimized(desk.left[1], true)
    desk.h.system.userFocus(desk.left[1])
    for command in ["in", "out", "show-all", "back", "forward", "neighbor left", "desktop", "arrange", "float-all here"] {
      _ = desk.h.press(command)
    }
    desk.h.system.setMinimized(desk.left[1], false)
    desk.h.scheduler.advance(by: 2)
    #expect(desk.h.press("show-all").ok)
  }

  /// A full-screen window has a macOS Space to itself: Arbor arranges nothing there.
  @Test func aFullScreenFocusedWindowIsSurvived() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.system.setFullScreen(desk.left[1], true)
    desk.h.system.setOnActiveSpace(desk.right[1], false)
    desk.h.scheduler.advance(by: 1)
    desk.h.system.type()
    for command in ["in", "out", "show-all", "back", "neighbor right", "desktop", "arrange"] { _ = desk.h.press(command) }
    desk.h.system.setFullScreen(desk.left[1], false)
    desk.h.system.setOnActiveSpace(desk.right[1], true)
    desk.h.scheduler.advance(by: 2)
    #expect(desk.h.press("show-all").ok)
  }

  /// The display goes while the keyboard is on it, and macOS says so late: shortcuts in between find a display.
  @Test func shortcutsBeforeAndAfterTheFocusedDisplayIsUnpluggedFindADisplay() {
    let desk = Desk([main, side, far])
    desk.restPointer(on: 0, typeIn: desk.left[2])
    desk.h.system.displayList = [main, side]  // gone, not reported yet
    #expect(desk.h.press("out").ok)
    desk.h.system.setDisplays([main, side])
    desk.h.scheduler.advance(by: 1)
    desk.h.system.type()
    desk.h.scheduler.advance(by: 0.2)
    // Its windows float on the main display now, out of view behind the framed window or on the Desktop.
    #expect(desk.h.press("show-all").ok)
    #expect(!desk.isFramed(0))
    #expect(desk.isFramed(1))
  }

  /// Arbor's own `focus` calls echo back from macOS. `press` plays the echo as `run` does.
  @Test func theEchoOfArborsOwnFocusChangeKeepsShortcutsOnOneDisplay() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    // Past the Desktop. The framed window goes out of view, so Arbor hands the keyboard to its neighbour.
    #expect(desk.h.press("neighbor right").ok)
    #expect(desk.h.press("neighbor right").ok)
    #expect(desk.h.system.focused == desk.right[1])
    #expect(desk.h.system.reportFocus() == 0, "the echo has been played")
    desk.h.scheduler.advance(by: 0.5)
    #expect(desk.h.press("out").ok)
    let workspace = desk.h.controller.workspaces[side.id]!
    #expect(workspace.camera == workspace.tree.root)
    #expect(desk.isFramed(0))
  }

  // MARK: Pause, drags

  @Test func whilePausedNothingIsChosenAndAfterwardsTheRuleHolds() {
    let desk = Desk([main, side])
    desk.restPointer(on: 0, typeIn: desk.left[1])
    desk.h.press("pause")
    #expect(!desk.h.press("out").ok)
    desk.h.scheduler.advance(by: 5)
    desk.h.press("resume")
    desk.h.scheduler.advance(by: 1)
    desk.h.system.userFocus(desk.left[1])
    desk.h.system.type()
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.press("desktop").ok)
    let typedOn = desk.h.controller.workspaces[side.id]!
    let pointedAt = desk.h.controller.workspaces[main.id]!
    #expect(typedOn.camera == typedOn.tree.desktop)
    #expect(pointedAt.camera != pointedAt.tree.desktop)
  }

  @Test func duringAPauseAFocusChangeAsksNothingOfTheWindowSystem() {
    let desk = Desk([main, side])
    desk.h.press("pause")
    let before = desk.h.system.focusedWindowReads
    desk.h.system.userFocus(desk.right[1])
    desk.h.system.userFocusesNothing()
    desk.h.system.userFocus(desk.left[0])
    #expect(desk.h.system.focusedWindowReads == before)
  }
}
