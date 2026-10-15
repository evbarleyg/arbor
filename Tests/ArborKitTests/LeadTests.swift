import ArborCore
import ArborTesting
import CoreGraphics
import Testing

// For `from` and `commandDisplayID`, which code inside ArborKit calls to ask.
@testable import ArborKit

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay

/// Keys follow the keyboard, gestures follow the pointer (docs/features/F56-keys-follow-the-keyboard.md).
@Suite @MainActor struct LeadTests {
  /// Two displays, each with two windows side by side and one of them framed:
  /// main [a | Desktop | b] framed on a, side [c | Desktop | d] framed on c.
  struct Desk {
    let h: Harness
    let a, b, c, d: WindowID

    @MainActor init(settings: Settings = Settings()) {
      h = Harness(displays: [main, side], settings: settings)
      a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
      b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 500, height: 400))
      c = h.system.open(app: "Mail", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
      d = h.system.open(app: "Terminal", frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
      h.start()
      for (window, edge) in [(a, "left"), (b, "right"), (c, "left"), (d, "right")] {
        h.run("dock \(window.rawValue) \(edge)")
      }
      h.run("zoom \(a.rawValue)")
      h.run("zoom \(c.rawValue)")
    }

    @MainActor func camera(_ display: DisplaySnapshot) -> NodeID { h.controller.workspaces[display.id]!.camera }
    @MainActor func root(_ display: DisplaySnapshot) -> NodeID { h.controller.workspaces[display.id]!.tree.root }
    @MainActor func leaf(_ window: WindowID, _ display: DisplaySnapshot) -> NodeID {
      h.controller.workspaces[display.id]!.tree.leaf(containing: window)!
    }

    /// The trap: the pointer is left on the main display, and then the user clicks into `window`
    /// on the side display… without the pointer, that is with ⌘Tab, and types.
    @MainActor func restPointerOnMainAndType(in window: WindowID) {
      h.system.cursor = CGPoint(x: 400, y: 400)
      h.scheduler.advance(by: 5)
      h.system.userFocus(window)
      h.scheduler.advance(by: 1)
      h.system.type()
      h.scheduler.advance(by: 0.3)
    }
  }

  // MARK: Which display (acceptance 1, 2 and 4)

  @Test func aShortcutActsOnTheFocusedWindowsDisplayWhileThePointerRestsOnTheOther() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side), "the display being typed on zooms out")
    #expect(desk.camera(main) == desk.leaf(desk.a, main), "the display under the pointer stays")
  }

  @Test func aGestureActsOnThePointersDisplay() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.run("out", from: .gesture).ok)
    #expect(desk.camera(main) == desk.root(main))
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
  }

  @Test func theMenuActsOnThePointersDisplay() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.run("out", from: .menu).ok)
    #expect(desk.camera(main) == desk.root(main))
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
  }

  @Test func scriptsAndURLsActLikeShortcuts() {
    for source in [CommandSource.script, .url] {
      let desk = Desk()
      desk.restPointerOnMainAndType(in: desk.c)
      #expect(desk.h.run("out", from: source).ok)
      #expect(desk.camera(side) == desk.root(side), "\(source)")
      #expect(desk.camera(main) == desk.leaf(desk.a, main), "\(source)")
    }
  }

  @Test func aCommandThatDoesNotSayWhereItCameFromIsTakenForAScript() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.run("out").ok)
    #expect(desk.camera(side) == desk.root(side))
  }

  /// The way the pointer usually gets there: click into a window, push the mouse aside, type.
  @Test func aPointerPushedAsideBeforeTypingDoesNotLead() {
    let desk = Desk()
    desk.h.system.cursor = desk.h.frame(desk.c)!.center
    desk.h.system.userFocus(desk.c)
    desk.h.scheduler.advance(by: 1)
    desk.h.system.cursor = CGPoint(x: 400, y: 400)
    desk.h.scheduler.advance(by: 1)
    desk.h.system.type(keys: 40)
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side))
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
  }

  @Test func aPointerThatMovedSinceActsOnItsOwnDisplay() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 420, y: 380)
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main), "someone who points at a display means it")
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
  }

  @Test func shortcutsPressedOneAfterAnotherStayOnOneDisplay() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)  // over a, framed or not
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.press("out").ok)
    desk.h.scheduler.advance(by: 3)
    #expect(desk.h.press("in").ok)
    #expect(desk.camera(main) == desk.leaf(desk.a, main), "out and in again, both on the main display")
    #expect(desk.camera(side) == desk.leaf(desk.c, side), "the other display never moved")
    // Back to typing, without a click: the keyboard never left c.
    desk.h.scheduler.advance(by: 2)
    desk.h.system.type(keys: 12)
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side))
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
  }

  @Test func everyCameraCommandFollowsTheKeyboard() {
    // Each of these leaves a trace on the display it acted on.
    for command in ["show-all", "out", "neighbor right", "desktop", "back", "save-view 3", "arrange", "float-all here"] {
      let desk = Desk()
      let before = desk.h.controller.workspaces
      desk.restPointerOnMainAndType(in: desk.c)
      #expect(desk.h.press(command).ok, "\(command)")
      #expect(desk.h.controller.workspaces[main.id] == before[main.id], "\(command) left the pointer's display alone")
      #expect(desk.h.controller.workspaces[side.id] != before[side.id], "\(command) acted where the keyboard is")
    }
  }

  @Test func aCommandThatFailsSaysWhichDisplayItChose() {
    let desk = Desk()
    desk.h.run("home")
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").message == "already showing everything on the focused window's display")
    desk.h.scheduler.advance(by: 1)
    desk.h.system.cursor = CGPoint(x: 420, y: 380)
    #expect(desk.h.press("out").message == "already showing everything on the display under the pointer")
  }

  @Test func withNoFocusedWindowThePointerDecides() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.system.focused = nil
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main))
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
  }

  /// The guide's recipe for calls is Don't Arrange “zoom.us”. Whoever types into the call's chat is looking at the
  /// display the call is on (the product owner's note on F56).
  @Test func aFocusedWindowArborDoesNotArrangeStillSaysWhichDisplay() {
    var settings = Settings()
    settings.excludedBundleIDs = ["us.zoom.xos"]
    let desk = Desk(settings: settings)
    let call = desk.h.system.open(
      app: "zoom.us", bundleID: "us.zoom.xos", frame: CGRect(x: 1600, y: 200, width: 400, height: 300))
    desk.restPointerOnMainAndType(in: call)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side), "the display the call sits on")
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
    // `in` has no arranged window to step toward there, so the pointer, which is on the other display, cannot
    // help either: it takes the first space, and says so by moving.
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.press("out").message == "already showing everything on the focused window's display")
  }

  @Test func aTypoInTheSettingMeansAutoAndIsReportedOnce() {
    var settings = Settings()
    settings.stepInToward = "mouse"
    let desk = Desk(settings: settings)
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side), "as with auto")
  }

  @Test func aFloatingFocusedWindowCountsToo() {
    let desk = Desk()
    let note = desk.h.system.open(app: "Stickies", frame: CGRect(x: 1900, y: 300, width: 300, height: 200))
    desk.restPointerOnMainAndType(in: note)
    #expect(desk.h.press("show-all").ok)
    #expect(desk.camera(side) == desk.root(side))
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
  }

  // MARK: Which way `in` steps (acceptance 2 and 3)

  @Test func inFromAShortcutStepsTowardTheFocusedWindowWhileThePointerRests() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.cursor = h.frame(a)!.center
    h.scheduler.advance(by: 5)
    h.system.userFocus(b)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
  }

  @Test func inFromAShortcutStepsTowardAPointerThatMovedSince() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(b)
    h.system.type()
    h.scheduler.advance(by: 2)
    h.system.cursor = h.frame(a)!.center
    h.scheduler.advance(by: 0.3)
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func inFromAGestureStepsTowardThePointer() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.cursor = h.frame(a)!.center
    h.scheduler.advance(by: 5)
    h.system.userFocus(b)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.run("in", from: .gesture).ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func inFromTheMenuStepsTowardTheFocusedWindowOnThePointersDisplay() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.advance(by: 2)
    // The menu bar item is at the top right, above b.
    h.system.cursor = CGPoint(x: 1300, y: 60)
    #expect(h.run("in", from: .menu).ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func inStepsThroughGroupsTowardTheFocusedWindow() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.system.cursor = h.frame(a)!.center
    h.scheduler.advance(by: 5)
    h.system.userFocus(c)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    let tree = h.workspace.tree
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == tree.parent(of: tree.leaf(containing: c)!))
    h.scheduler.advance(by: 0.5)
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == tree.leaf(containing: c))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func inStepsTowardTheDesktopWhenTheFocusedWindowFloats() {
    // [a | Desktop]: the Desktop has the half that is left over, and is a place to step into.
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let note = h.system.open(app: "Stickies", frame: CGRect(x: 1000, y: 300, width: 140, height: 120))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.system.cursor = h.frame(a)!.center
    h.scheduler.advance(by: 5)
    h.system.userFocus(note)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == h.workspace.tree.desktop)
  }

  @Test func inFallsBackToThePointerWhenTheFocusedWindowIsOutsideTheView() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    let tree = h.workspace.tree
    h.run("zoom-node \(tree.parent(of: tree.leaf(containing: b)!)!.rawValue)")
    h.system.cursor = h.frame(c)!.center
    h.scheduler.advance(by: 5)
    // An app can hold the keyboard with a window Arbor has out of view for a moment.
    h.system.focused = a
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.press("in").ok)
    #expect(h.workspace.camera == tree.leaf(containing: c))
  }

  // MARK: The setting

  @Test func stepInTowardPointerIsHowItWasBefore() {
    var settings = Settings()
    settings.stepInToward = "pointer"
    let desk = Desk(settings: settings)
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main))
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
    desk.h.system.cursor = desk.h.frame(desk.b)!.center
    desk.h.scheduler.advance(by: 5)
    desk.h.system.type()
    #expect(desk.h.press("in").ok)
    #expect(desk.camera(main) == desk.leaf(desk.b, main))
  }

  @Test func stepInTowardFocusIgnoresAPointerThatJustMoved() {
    var settings = Settings()
    settings.stepInToward = "focus"
    let desk = Desk(settings: settings)
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 420, y: 380)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side))
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
    desk.h.system.userFocus(desk.d)
    desk.h.system.cursor = desk.h.frame(desk.c)!.center
    #expect(desk.h.press("in").ok)
    #expect(desk.camera(side) == desk.leaf(desk.d, side))
    // A pinch still means what is under the pointer.
    desk.h.system.cursor = CGPoint(x: 420, y: 380)
    #expect(desk.h.run("out", from: .gesture).ok)
    #expect(desk.camera(main) == desk.root(main))
  }

  // MARK: What macOS does around a command

  /// macOS reports Arbor's own `focus` calls back. The echo of a window that already has the keyboard
  /// is no focus change, so it does not take the lead from a pointer that is being followed.
  @Test func anEchoOfTheFocusThatWasThereChangesNothing() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)  // over a, framed or not
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.press("out").ok)
    desk.h.scheduler.advance(by: 0.1)
    desk.h.system.userFocus(desk.c)
    desk.h.scheduler.advance(by: 2)
    #expect(desk.h.press("in").ok)
    #expect(desk.camera(main) == desk.leaf(desk.a, main))
    #expect(desk.camera(side) == desk.leaf(desk.c, side))
  }

  /// A window takes the keyboard by itself (a new window, an app that activates): nothing was typed and the
  /// pointer did not move, yet the person is looking there now.
  @Test func aWindowThatTakesTheKeyboardTakesTheLeadFromAPointerThatWasFollowed() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main))
    desk.h.scheduler.advance(by: 1)
    desk.h.system.userFocus(desk.d)
    desk.h.scheduler.advance(by: 1)
    // A command that changes either display, whatever the view did when d took the keyboard.
    let mainBefore = desk.h.controller.workspaces[main.id]
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(side) == desk.h.controller.workspaces[side.id]!.tree.desktop)
    #expect(desk.h.controller.workspaces[main.id] == mainBefore)
  }

  // MARK: Asking changes nothing

  @Test func aMenuThatAsksWhichDisplayDoesNotTurnTheNextShortcutTowardThePointer() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side))
    // The menu is opened without a click that macOS counts, say with the keyboard, and names the display its items act on.
    #expect(desk.h.controller.displayForCommands(from: .menu) == main.id)
    #expect(desk.h.controller.displayForCommands(from: .gesture) == main.id)
    let mainBefore = desk.h.controller.workspaces[main.id]
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(side) == desk.h.controller.workspaces[side.id]!.tree.desktop, "it goes on where the last one went")
    #expect(desk.h.controller.workspaces[main.id] == mainBefore)
  }

  /// What a menu model, a caption or a list of rows inside ArborKit is apt to write.
  private func askAsAMenuDoes(_ desk: Desk) -> DisplayID? {
    desk.h.controller.from(.menu) { desk.h.controller.commandDisplayID() }
  }

  @Test func codeThatAsksWithTheCommandsOwnFunctionsChangesNothingEither() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(side) == desk.root(side))
    #expect(askAsAMenuDoes(desk) == main.id)
    let mainBefore = desk.h.controller.workspaces[main.id]
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(side) == desk.h.controller.workspaces[side.id]!.tree.desktop)
    #expect(desk.h.controller.workspaces[main.id] == mainBefore)
  }

  @Test func norAfterATapOfShowEverythingWhichPerformsNoCommand() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.keyDown("ctrl+opt+space")
    desk.h.scheduler.advance(by: 0.1)
    desk.h.keyUp("ctrl+opt+space")
    #expect(desk.camera(side) == desk.root(side))
    #expect(askAsAMenuDoes(desk) == main.id)
    let mainBefore = desk.h.controller.workspaces[main.id]
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(side) == desk.h.controller.workspaces[side.id]!.tree.desktop)
    #expect(desk.h.controller.workspaces[main.id] == mainBefore)
  }

  @Test func aTapOfShowEverythingIsFollowedLikeAnyShortcut() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)
    desk.h.scheduler.advance(by: 0.4)
    desk.h.keyDown("ctrl+opt+space")
    desk.h.scheduler.advance(by: 0.1)
    desk.h.keyUp("ctrl+opt+space")
    #expect(desk.camera(main) == desk.root(main), "the pointer moved last")
    // Its own key has come up since, which is later than the pointer's last move.
    desk.h.scheduler.advance(by: 3)
    let sideBefore = desk.h.controller.workspaces[side.id]
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(main) == desk.h.controller.workspaces[main.id]!.tree.desktop, "it goes on where the tap went")
    #expect(desk.h.controller.workspaces[side.id] == sideBefore)
  }

  @Test func whoeverAsksIsToldWhatTheNextCommandWillDo() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.controller.displayForCommands(from: .shortcut) == side.id)
    #expect(desk.h.controller.displayForCommands(from: .script) == side.id)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.controller.displayForCommands(from: .shortcut) == main.id, "the pointer moved last")
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main))
    // Asked over and over, as a caption that is redrawn does: the shortcuts that follow still go on where the first went.
    desk.h.scheduler.advance(by: 3)
    for _ in 0..<5 { #expect(desk.h.controller.displayForCommands(from: .shortcut) == main.id) }
    #expect(desk.h.press("desktop").ok)
    #expect(desk.camera(main) == desk.h.controller.workspaces[main.id]!.tree.desktop)
  }

  @Test func queriesDoNotCountAsCommands() {
    // Something polls `state` (a status bar widget, the test harness) between the pointing and the key.
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.cursor = CGPoint(x: 420, y: 380)
    desk.h.run("state")
    desk.h.run("status")
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.press("out").ok)
    #expect(desk.camera(main) == desk.root(main))
  }

  @Test func theSourceLastsOnlyAsLongAsItsCommand() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    #expect(desk.h.run("out", from: .gesture).ok)
    #expect(desk.camera(main) == desk.root(main))
    desk.h.scheduler.advance(by: 1)
    desk.h.system.type(keys: 5)
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.run("out").ok)
    #expect(desk.camera(side) == desk.root(side), "the next command is not taken for a gesture")
  }

  @Test func unpluggingTheFocusedWindowsDisplayLeavesNothingBehind() {
    let desk = Desk()
    desk.restPointerOnMainAndType(in: desk.c)
    desk.h.system.setDisplays([main])
    desk.h.scheduler.advance(by: 1)
    desk.h.system.type()
    #expect(desk.h.press("show-all").ok)
    #expect(desk.camera(main) == desk.root(main))
  }
}
