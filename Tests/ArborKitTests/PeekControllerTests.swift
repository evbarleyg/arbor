import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let space = "ctrl+opt+space"

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay

/// Peek: hold to look, let go to land (docs/features/F51-peek.md), with the real controller and keys that go
/// down and come up.
@Suite @MainActor struct PeekControllerTests {
  /// [a / c | Desktop | b] with a framed and focused, after a little history: everything, b, a; and
  /// `back` then `forward` so that neither list is empty… the last move was `back` from c to a.
  struct Desk {
    let h: Harness
    let a, b, c: WindowID
    /// What `onTemporaryShortcuts` was told, in order.
    let asked = Box()

    final class Box { var calls: [[KeyBinding]] = [] }

    @MainActor init(settings: Settings = Settings()) {
      h = Harness(settings: settings)
      a = h.system.open(app: "Safari")
      b = h.system.open(app: "Notes")
      c = h.system.open(app: "Mail")
      h.start()
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) right")
      h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
      h.run("zoom \(b.rawValue)")
      h.run("zoom \(a.rawValue)")
      h.run("zoom \(c.rawValue)")
      h.run("back")
      h.system.userFocus(a)
      h.system.cursor = CGPoint(x: 720, y: 450)
      h.controller.onTemporaryShortcuts = { [asked] in asked.calls.append($0) }
    }

    @MainActor func leaf(_ window: WindowID) -> NodeID { h.workspace.tree.leaf(containing: window)! }
    @MainActor var root: NodeID { h.workspace.tree.root }
    @MainActor var outline: CGRect? { h.overlays.scenes[h.display]?.peekOutline }
    /// Where a window sits when everything shows.
    @MainActor func place(_ window: WindowID) -> CGRect {
      LayoutEngine.layout(
        h.workspace.tree, camera: root, in: h.visibleFrame, options: h.controller.settings.layoutOptions,
        isPresent: { _ in true }
      ).windowFrames[window]!
    }

    /// Presses ⌃⌥Space and keeps it down until the outline shows.
    @MainActor func hold() {
      h.keyDown(space)
      h.scheduler.advance(by: 0.4)
    }

    @MainActor func point(at window: WindowID) {
      h.system.cursor = place(window).center
      h.scheduler.advance(by: 0.1)
    }

    /// Nothing of a peek is left: no outline, no temporary shortcuts, no timer.
    @MainActor func expectNoTrace(sourceLocation: SourceLocation = #_sourceLocation) {
      #expect(!h.controller.isPeeking, sourceLocation: sourceLocation)
      #expect(outline == nil, sourceLocation: sourceLocation)
      #expect(h.controller.temporaryShortcuts.isEmpty, sourceLocation: sourceLocation)
      #expect(asked.calls.last?.isEmpty != false, "the app was told to give them back", sourceLocation: sourceLocation)
      #expect(!h.scheduler.pendingKeys.contains("peek"), sourceLocation: sourceLocation)
    }
  }

  // MARK: Acceptance 1: a tap

  @Test func aTapShowsEverythingAndHistoryGetsOneEntry() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.h.keyDown(space)
    #expect(desk.h.workspace.camera == desk.root, "everything shows as soon as the key goes down")
    desk.h.scheduler.advance(by: 0.1)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root)
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)])
    #expect(desk.h.workspace.forward.isEmpty)
    desk.expectNoTrace()
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.workspace.camera == desk.root, "and stays")
    #expect(desk.h.run("back").ok)
    #expect(desk.h.workspace.camera == desk.leaf(desk.a))
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  @Test func theEndOfATapTellsWhoeverShowsHistoryAndSavesIt() {
    let desk = Desk()
    desk.h.keyDown(space)
    desk.h.scheduler.runPending()  // the save of the move to everything, and one look of the timer
    let saves = desk.h.store.saveCount
    var changes: [Controller.Change] = []
    desk.h.controller.observe { changes.append($0) }
    desk.h.keyUp(space)
    #expect(changes.contains(.camera(desk.h.display)), "Back has something to go back to only now")
    desk.h.scheduler.runPending()
    // What was written with the key down was this already (`whatIsSavedWhileTheKeysAreDownIsAStay`), so there is nothing to write again.
    #expect(desk.h.store.saveCount == saves)
    #expect(desk.h.store.saved?.workspaces[desk.h.display] == desk.h.workspace)
    #expect(desk.h.store.saved?.workspaces[desk.h.display]?.back.last == desk.leaf(desk.a))
  }

  @Test func aTapIsExactlyWhatTheCommandDoes() {
    let (tapped, commanded) = (Desk(), Desk())
    tapped.h.key(space)
    commanded.h.run("show-all")
    #expect(tapped.h.workspace == commanded.h.workspace)
    #expect(tapped.h.system.allWindows() == commanded.h.system.allWindows())
  }

  /// The product owner's script: "keydown ctrl+opt+space" "wait 0.35" "keyup" from a framed view.
  @Test func aSlowPressStaysOnEverything() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.h.keyDown(space)
    desk.h.scheduler.advance(by: 0.35)
    #expect(desk.outline == desk.place(desk.a), "the outline shows: it may yet become a peek")
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root, "the first way home does not spring back")
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)], "as a tap records it")
    desk.expectNoTrace()
    desk.h.scheduler.advance(by: 2)
    #expect(desk.h.workspace.camera == desk.root)
  }

  @Test func noOutlineShowsBeforeTheThreshold() {
    let desk = Desk()
    desk.h.keyDown(space)
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.outline == nil)
    #expect(!desk.h.controller.isPeeking)
    desk.h.scheduler.advance(by: 0.2)
    #expect(desk.h.controller.isPeeking)
    #expect(desk.outline == desk.place(desk.a), "the view that was left is outlined")
  }

  // MARK: Acceptance 2: hold, point, let go

  @Test func lettingGoFramesTheWindowUnderThePointerAndBackReturnsToTheViewBeforeThePeek() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.hold()
    desk.point(at: desk.b)
    #expect(desk.outline == desk.place(desk.b))
    #expect(desk.h.workspace.camera == desk.root)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.b))
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)], "one move: from a to b")
    #expect(desk.h.workspace.forward.isEmpty)
    #expect(desk.h.system.focused == desk.b, "the keyboard goes where the view went")
    desk.expectNoTrace()
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
    #expect(desk.h.run("back").ok)
    #expect(desk.h.workspace.camera == desk.leaf(desk.a))
  }

  /// The product owner's answer: the peek stood in for Show Everything, and ⌃⌥[ is there for where one came from.
  @Test func afterLandingTheFrameShortcutGoesToEverything() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.c)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.c))
    #expect(desk.h.key("ctrl+opt+return")?.message == "showing everything")
    #expect(desk.h.workspace.camera == desk.root, "not the column that c shares with a")
    #expect(desk.h.run("back").ok)
    #expect(desk.h.workspace.camera == desk.leaf(desk.c))
    #expect(desk.h.run("back").ok)
    #expect(desk.h.workspace.camera == desk.leaf(desk.a), "where the peek began")
  }

  @Test func onlyTheLandingItselfLeadsToEverything() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.c)
    desk.h.keyUp(space)
    // Walk away and come back by another road: the ordinary rule holds again.
    #expect(desk.h.run("neighbor up").ok)
    #expect(desk.h.run("neighbor down").ok)
    #expect(desk.h.workspace.camera == desk.leaf(desk.c))
    desk.h.system.userFocus(desk.c)
    #expect(desk.h.key("ctrl+opt+return")?.ok == true)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.parent(of: desk.leaf(desk.c)), "one level out")
  }

  @Test func pointingAtAWindowKeptInViewChoosesNothingUnderneath() {
    let desk = Desk()
    let call = desk.h.system.open(app: "zoom.us", frame: CGRect(x: 1150, y: 500, width: 240, height: 180))
    #expect(desk.h.run("pin \(call.rawValue)").ok)
    desk.h.system.userFocus(desk.a)
    desk.hold()
    desk.point(at: desk.c)
    #expect(desk.outline == desk.place(desk.c))
    let frame = desk.h.frame(call)!
    #expect(desk.place(desk.b).contains(frame.center), "the call lies over b")
    desk.h.system.cursor = frame.center
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.outline == desk.place(desk.c), "not b, which cannot be seen there")
    desk.h.key("ctrl+opt+escape")
    desk.h.keyUp(space)
  }

  @Test func theOutlineFollowsThePointerFromWindowToWindow() {
    let desk = Desk()
    desk.hold()
    for window in [desk.b, desk.c, desk.a, desk.b] {
      desk.point(at: window)
      #expect(desk.outline == desk.place(window))
    }
    desk.h.system.cursor = desk.h.layout!.desktopFrame!.center
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.outline == desk.h.layout!.desktopFrame)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.desktop)
  }

  // MARK: Acceptance 3: back where you came from

  @Test func lettingGoWithoutMovingReturnsToTheOriginalViewWithNoHistoryEntry() {
    let desk = Desk()
    let before = desk.h.workspace
    #expect(!before.back.isEmpty && !before.forward.isEmpty)
    desk.hold()
    desk.h.scheduler.advance(by: 2)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == before, "the camera, back and forward are all as they were")
    #expect(desk.h.system.focused == desk.a)
    // The windows too, not only the books.
    #expect(desk.h.layout?.camera == desk.leaf(desk.a))
    #expect(desk.h.frame(desk.a) == desk.h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(!desk.h.system.isVisible(desk.b) && !desk.h.system.isVisible(desk.c))
    desk.expectNoTrace()
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  @Test func escapeReturnsToTheOriginalViewWithNoHistoryEntryAndDoesNotPause() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.hold()
    desk.point(at: desk.b)
    desk.h.key("ctrl+opt+escape")
    #expect(desk.h.workspace == before)
    #expect(!desk.h.controller.isPaused, "⌃⌥⎋ means the peek while one is on")
    #expect(desk.outline == nil)
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
    // The keys are still down; the pointer wanders; they come up, and with them what was held for the peek alone (`expectNoTrace`).
    desk.point(at: desk.c)
    #expect(desk.outline == nil)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == before)
    desk.expectNoTrace()
    // And ⌃⌥⎋ means pause again.
    desk.h.key("ctrl+opt+escape")
    #expect(desk.h.controller.isPaused)
  }

  @Test func pointingBackAtTheWindowYouCameFromReturnsWithNoHistoryEntry() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.hold()
    desk.point(at: desk.b)
    desk.point(at: desk.a)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == before)
  }

  // MARK: The arrow keys

  @Test func theArrowKeysMoveTheOutlineInsteadOfTheView() {
    let desk = Desk(settings: .withEveryKey)
    let before = desk.h.workspace
    desk.hold()
    desk.h.key("ctrl+opt+down")
    #expect(desk.outline == desk.place(desk.c))
    #expect(desk.h.workspace.camera == desk.root, "⌃⌥↓ did not step in")
    desk.h.key("ctrl+opt+right")
    #expect(desk.outline == desk.h.layout!.desktopFrame)
    desk.h.key("ctrl+opt+right")
    #expect(desk.outline == desk.place(desk.b))
    desk.h.key("ctrl+opt+right")
    #expect(desk.outline == desk.place(desk.b), "nothing lies further right")
    desk.h.scheduler.advance(by: 0.5)
    #expect(desk.outline == desk.place(desk.b), "the pointer, at rest somewhere else, does not take it back")
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.b))
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)])
    #expect(desk.h.system.focused == desk.b)
    desk.expectNoTrace()
    // The arrows have their own meaning back.
    #expect(desk.h.key("ctrl+opt+up")?.ok == true)
    #expect(desk.h.workspace.camera == desk.root)
  }

  @Test func everyArrowGoesItsOwnWay() {
    let desk = Desk()
    desk.hold()
    desk.h.key("ctrl+opt+down")
    #expect(desk.outline == desk.place(desk.c))
    desk.h.key("ctrl+opt+up")
    #expect(desk.outline == desk.place(desk.a))
    desk.h.key("ctrl+opt+right")
    desk.h.key("ctrl+opt+right")
    #expect(desk.outline == desk.place(desk.b))
    desk.h.key("ctrl+opt+left")
    #expect(desk.outline == desk.h.layout!.desktopFrame)
    desk.h.key("ctrl+opt+escape")
    desk.h.keyUp(space)
  }

  @Test func anArrowWithinTheFirstMomentDoesWhatItAlwaysDid() {
    // ⌃⌥Space ⌃⌥↓ rolled off the fingers, the second key down before the first is up.
    let desk = Desk(settings: .withEveryKey)
    let before = desk.h.workspace
    desk.h.keyDown(space)
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.h.keyDown("ctrl+opt+down")?.ok == true)
    #expect(desk.h.workspace.camera != desk.root, "it stepped in")
    let after = desk.h.workspace
    #expect(after.back == before.back + [desk.leaf(desk.a), desk.root], "as show-all and in record")
    desk.h.keyUp(space)
    desk.h.keyUp("ctrl+opt+down")
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.workspace == after, "and the release of ⌃⌥Space changes nothing")
    desk.expectNoTrace()
  }

  // MARK: A click

  @Test func aClickFramesWhatWasClickedAtOnce() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.hold()
    desk.point(at: desk.b)
    desk.h.system.mouseDown = true
    desk.h.system.userFocus(desk.b)
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.h.workspace.camera == desk.root)
    desk.h.system.mouseDown = false
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.h.workspace.camera == desk.leaf(desk.b), "with the keys still down")
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)])
    #expect(desk.outline == nil)
    let landed = desk.h.workspace
    desk.h.system.cursor = CGPoint(x: 100, y: 100)
    desk.h.scheduler.advance(by: 0.5)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == landed)
    desk.expectNoTrace()
  }

  @Test func aQuickClickOnTheOutlineLandsToo() {
    // A tap on a trackpad is down and up between two looks of the timer; the outline's panel reports it.
    let desk = Desk()
    let before = desk.h.workspace
    #expect(!desk.h.overlays.clickOutline(), "nothing to click")
    desk.hold()
    desk.point(at: desk.b)
    #expect(desk.h.overlays.clickOutline())
    #expect(desk.h.workspace.camera == desk.leaf(desk.b))
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a)])
    #expect(desk.h.system.focused == desk.b, "the click never reached the window, so Arbor gives it the keyboard")
    #expect(desk.outline == nil)
    let landed = desk.h.workspace
    desk.h.keyUp(space)
    #expect(desk.h.workspace == landed)
    desk.expectNoTrace()
  }

  @Test func aClickReportedForAnotherDisplayIsNotThisPeeks() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    desk.h.controller.peekOutlineClicked(display: side.id)
    #expect(desk.h.controller.isPeeking)
    #expect(desk.h.workspace.camera == desk.root)
    desk.h.key("ctrl+opt+escape")
    desk.h.keyUp(space)
  }

  @Test func landingOnAGroupGivesTheKeyboardToTheWindowUsedLastThere() {
    // Too narrow for the column's windows when everything shows: the column [a / c] is one tile.
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let desk = Desk(settings: settings)
    desk.h.system.userFocus(desk.c)
    desk.h.system.userFocus(desk.a)
    desk.h.run("zoom \(desk.b.rawValue)")
    desk.h.system.userFocus(desk.b)
    desk.hold()
    let tile = desk.h.overlays.tiles[desk.h.display]!.first { $0.items.contains { $0.window == desk.c } }!
    #expect(tile.items.count == 2)
    // Low in the tile, which is low in the view once the group fills it: over c. The tile was chosen, not c.
    desk.h.system.cursor = CGPoint(x: tile.frame.midX, y: tile.frame.maxY - 40)
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.outline == tile.frame)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == tile.node)
    #expect(desk.h.frame(desk.c)!.contains(desk.h.system.cursor))
    #expect(desk.h.system.focused == desk.a)
  }

  @Test func aWindowThatHasTheKeyboardAndIsLandedOnIsNotAskedToTakeIt() {
    // Focusing raises, so asking for nothing is not nothing.
    let desk = Desk()
    desk.h.run("show-all")
    desk.h.system.userFocus(desk.c)
    desk.hold()
    desk.point(at: desk.c)
    let asked = desk.h.system.focusLog.count
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.c))
    #expect(desk.h.system.focused == desk.c)
    #expect(desk.h.system.focusLog.count == asked)
  }

  // MARK: Back leads to everything, which is where a peek looks (found by rehearsing check-F51.sh)

  /// [ a | Desktop | b ], framed on a straight from everything: Back holds everything and nothing else.
  private func framedFromEverything() -> (h: Harness, a: WindowID, b: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("show-all")
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(a)
    h.system.cursor = CGPoint(x: 720, y: 450)
    #expect(h.workspace.back == [h.workspace.tree.root])
    return (h, a, b)
  }

  @Test func aPeekThatGoesBackLeavesBackItsWayToEverything() {
    let (h, _, _) = framedFromEverything()
    let before = h.workspace
    h.keyDown(space)
    h.scheduler.advance(by: 1.5)
    h.keyUp(space)
    #expect(h.workspace == before, "the camera, back and forward are all as they were")
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func soDoesEscape() {
    let (h, _, _) = framedFromEverything()
    let before = h.workspace
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    h.key("ctrl+opt+escape")
    h.keyUp(space)
    #expect(h.workspace == before)
  }

  @Test func aLandingAddsOneEntryOnTopOfIt() {
    let (h, a, b) = framedFromEverything()
    let (root, from, to) = (h.workspace.tree.root, h.workspace.tree.leaf(containing: a)!, h.workspace.tree.leaf(containing: b)!)
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    h.system.cursor = h.frame(b)!.center
    h.scheduler.advance(by: 0.1)
    h.keyUp(space)
    #expect(h.workspace.camera == to)
    #expect(h.workspace.back == [root, from])
  }

  @Test func aTapAddsOneEntryOnTopOfIt() {
    let (h, a, _) = framedFromEverything()
    let (root, from) = (h.workspace.tree.root, h.workspace.tree.leaf(containing: a)!)
    h.keyDown(space)
    h.scheduler.advance(by: 0.1)
    h.keyUp(space)
    #expect(h.workspace.camera == root)
    #expect(h.workspace.back == [root, from])
  }

  @Test func aClickedTileAddsOneEntryOnTopOfIt() {
    // The move is not the peek's own: `moveCamera` is told to yield first.
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let desk = Desk(settings: settings)
    desk.h.run("show-all")
    desk.h.run("zoom \(desk.a.rawValue)")
    let before = desk.h.workspace
    #expect(before.back.last == desk.root)
    desk.hold()
    let tile = desk.h.overlays.tiles[desk.h.display]!.first { $0.items.contains { $0.window == desk.b } }!
    desk.h.overlays.clickTile(tile.node)
    #expect(desk.h.workspace.camera == tile.node)
    #expect(desk.h.workspace.back == before.back + [before.camera])
    desk.h.keyUp(space)
    #expect(desk.h.workspace.back == before.back + [before.camera])
  }

  @Test func forwardSurvivesAPeekToo() {
    let (h, _, _) = framedFromEverything()
    #expect(h.run("show-all").ok)
    #expect(h.run("back").ok)
    // Framed on a, with everything both behind and ahead.
    let before = h.workspace
    #expect(before.back == [before.tree.root] && before.forward == [before.tree.root])
    h.keyDown(space)
    h.scheduler.advance(by: 1.5)
    h.keyUp(space)
    #expect(h.workspace == before)
    #expect(h.run("forward").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func aWindowThatClosesDuringTheHoldReachesBackAsItAlwaysDoes() {
    // [ a | Desktop | (b / c) ]; c, the group, a: Back leads to the group.
    func go(peeking: Bool) -> Harness {
      let h = Harness()
      let a = h.system.open(app: "Safari"), b = h.system.open(app: "Notes"), c = h.system.open(app: "Mail")
      h.start()
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) right")
      h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
      h.run("show-all")
      h.run("zoom \(c.rawValue)")
      h.run("out")
      h.run("zoom \(a.rawValue)")
      h.system.userFocus(a)
      h.system.cursor = CGPoint(x: 720, y: 450)
      if peeking {
        h.keyDown(space)
        h.scheduler.advance(by: 1.5)
      }
      h.system.close(c)
      h.scheduler.advance(by: 0.2)
      if peeking { h.keyUp(space) }
      return h
    }
    let (plain, peeked) = (go(peeking: false), go(peeking: true))
    #expect(peeked.workspace == plain.workspace)
    #expect(peeked.run("back").message == plain.run("back").message)
    #expect(peeked.workspace.camera != peeked.workspace.tree.root, "to b, which took the group's place")
  }

  // MARK: The arrangement changes while the keys are down (found by the chaos lab)

  /// Nothing is docked, ⌃⌥Space is down for `held` seconds, and a rule docks the window that opens: a new root.
  private func aRuleDocksTheFirstWindow(held: Double) -> (Harness, WindowID) {
    let h = Harness()
    h.start()
    #expect(h.run("rule add com.example.mail dock left").ok)
    let desktop = h.workspace.tree.root
    h.keyDown(space)
    h.scheduler.advance(by: held)
    let mail = h.system.open(app: "Mail")
    h.scheduler.advance(by: 0.05)
    #expect(h.workspace.tree.leaf(containing: mail) != nil)
    #expect(h.workspace.tree.root != desktop && h.workspace.tree.desktop == desktop, "the old number is the Desktop now")
    return (h, mail)
  }

  @Test(arguments: [0.05, 0.5, 1.5]) func theViewIsOnEverythingAfterARuleDockedTheFirstWindow(held: Double) {
    let (h, mail) = aRuleDocksTheFirstWindow(held: held)
    h.keyUp(space)
    h.scheduler.advance(by: 0.1)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.layout?.camera == h.workspace.camera, "what shows is what the books say")
    #expect(h.layout?.windowFrames[mail] != nil)
    expectWindowsMatchLayout(h)
    #expect(h.workspace.back.isEmpty, "everything was left for everything")
  }

  @Test func escapeLeavesTheViewOnEverythingToo() {
    let (h, _) = aRuleDocksTheFirstWindow(held: 0.5)
    h.key("ctrl+opt+escape")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.layout?.camera == h.workspace.camera)
    h.keyUp(space)
    #expect(h.workspace.camera == h.workspace.tree.root)
    expectWindowsMatchLayout(h)
  }

  @Test func aCommandThatSaysNotWhereItCameFromEndsAPeekBeforeItChangesAnything() {
    let h = Harness()
    let mail = h.system.open(app: "Mail")
    h.start()
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    #expect(h.controller.isPeeking)
    #expect(h.controller.perform(.dock(mail, .left)).ok)
    #expect(!h.controller.isPeeking)
    h.scheduler.advance(by: 0.05)
    h.keyUp(space)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.layout?.camera == h.workspace.camera)
    expectWindowsMatchLayout(h)
  }

  @Test func aClickedTileIsALandingToo() {
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let desk = Desk(settings: settings)
    let before = desk.h.workspace
    desk.hold()
    let tile = desk.h.overlays.tiles[desk.h.display]!.first { $0.items.contains { $0.window == desk.b } }!
    desk.h.overlays.clickTile(tile.node)
    #expect(desk.h.workspace.camera == tile.node)
    #expect(desk.h.workspace.back == before.back + [before.camera], "one move, from the view before the peek")
    #expect(desk.outline == nil)
    let landed = desk.h.workspace
    desk.h.keyUp(space)
    #expect(desk.h.workspace == landed)
    desk.expectNoTrace()
  }

  // MARK: Acceptance 4: temporary shortcuts

  @Test func withTheWholeMapNoneAreNeeded() {
    let desk = Desk(settings: .withEveryKey)
    desk.hold()
    #expect(desk.h.controller.temporaryShortcuts.isEmpty, "⌃⌥ + arrows and ⌃⌥⎋ are registered anyway")
    #expect(desk.asked.calls.isEmpty)
    desk.h.keyUp(space)
  }

  /// Someone who has given ⌃⌥← and ⌃⌥⎋ back to their apps still gets them during a hold.
  private var sparse: Settings {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+left": nil, "ctrl+opt+escape": nil]
    return settings
  }

  @Test func chordsBoundToNothingAreRegisteredForAsLongAsTheKeyIsDown() {
    let desk = Desk(settings: sparse.withEveryKey)
    #expect(desk.h.key("ctrl+opt+left") == nil, "not Arbor's")
    desk.h.keyDown(space)
    #expect(desk.h.controller.temporaryShortcuts.map(\.chord.text) == ["ctrl+opt+left", "ctrl+opt+escape"], "from the press on")
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.controller.temporaryShortcuts.map(\.chord.text) == ["ctrl+opt+left", "ctrl+opt+escape"])
    #expect(desk.asked.calls.count == 1)
    desk.point(at: desk.b)
    desk.h.key("ctrl+opt+left")
    #expect(desk.outline == desk.h.layout!.desktopFrame)
    desk.h.keyUp(space)
    desk.expectNoTrace()
    #expect(desk.asked.calls.count == 2)
    #expect(desk.h.key("ctrl+opt+left") == nil, "not Arbor's any more")
  }

  @Test func temporaryShortcutsAreGoneAfterEveryEnding() {
    let endings: [(String, @MainActor (Desk) -> Void)] = [
      ("letting go", { $0.h.keyUp(space) }),
      ("landing", { $0.point(at: $0.b); $0.h.keyUp(space) }),
      ("escape", { $0.h.key("ctrl+opt+escape") }),
      ("a modifier going up first", { $0.h.system.heldModifiers = [.control]; $0.h.scheduler.advance(by: 0.1) }),
      ("a release that is never reported", { $0.h.keyUp(space, reported: false); $0.h.scheduler.advance(by: 0.1) }),
      (
        "a click",
        {
          $0.point(at: $0.b)
          $0.h.system.mouseDown = true
          $0.h.scheduler.advance(by: 0.1)
          $0.h.system.mouseDown = false
          $0.h.scheduler.advance(by: 0.1)
        }
      ),
      ("another shortcut", { $0.h.key("ctrl+opt+return") }),
      ("a command from a script", { $0.h.run("desktop", from: .script) }),
      ("a pinch", { $0.h.run("in", from: .gesture) }),
      ("pausing", { $0.h.run("pause", from: .menu) }),
      ("pausing behind its back", { $0.h.run("pause") }),
      ("quitting", { $0.h.controller.shutdown() }),
      ("the display going away", { $0.h.system.setDisplays([side]); $0.h.scheduler.advance(by: 0.1) }),
      (
        "a drag",
        {
          $0.h.system.mouseDown = true
          $0.h.controller.dragBegan($0.b, at: CGPoint(x: 1200, y: 60))
          $0.h.scheduler.advance(by: 0.1)
          $0.h.system.mouseDown = false
          $0.h.controller.dragEnded($0.b, at: CGPoint(x: 1200, y: 60))
        }
      ),
      ("the outlined window closing", { $0.point(at: $0.b); $0.h.system.close($0.b); $0.h.keyUp(space) }),
      ("every window closing", { for w in [$0.a, $0.b, $0.c] { $0.h.system.close(w) }; $0.h.keyUp(space) }),
    ]
    for (name, end) in endings {
      let desk = Desk(settings: sparse)
      desk.hold()
      #expect(!desk.h.controller.temporaryShortcuts.isEmpty, "\(name)")
      end(desk)
      #expect(desk.outline == nil, "after \(name)")
      // Whatever is still down comes up. Until then the keys are kept from the app in front (`PeekKeysFromThePressTests`), unless Arbor has stopped.
      if !desk.h.controller.isRunning || !desk.h.system.isHolding(try! KeyChord(text: space)) {
        #expect(desk.h.controller.temporaryShortcuts.isEmpty, "at once after \(name)")
        #expect(desk.asked.calls.last == [], "at once after \(name) the app was told")
      }
      desk.h.keyUp(space)
      #expect(desk.h.controller.temporaryShortcuts.isEmpty, "after \(name)")
      #expect(desk.asked.calls.last == [], "after \(name) the app was told")
      // Nor does any workspace, here or of a display that is away, go on believing that its view is only visiting.
      #expect(desk.h.controller.invariantViolations().filter { $0.rule == "leak" } == [], "after \(name)")
      #expect(desk.h.controller.workspaces.values.allSatisfy { $0.lookingFrom == nil }, "after \(name)")
      desk.h.scheduler.advance(by: 0.2)
      #expect(!desk.h.scheduler.pendingKeys.contains("peek"), "after \(name) the timer has stopped")
      #expect(desk.asked.calls.count == 2, "after \(name): asked once, given back once")
    }
  }

  // MARK: What is saved with the keys down

  /// Whoever reads it finds nobody peeking. So it is what the look would become: everything shows, which is what is on the screen,
  /// and Back leads to where its user was. The peek itself goes on as if nothing had been written.
  @Test func whatIsSavedWhileTheKeysAreDownIsAStay() throws {
    let desk = Desk()
    let (origin, history) = (desk.h.workspace.camera, desk.h.workspace.back)
    desk.hold()
    desk.h.controller.saveNow()
    let saved = try #require(desk.h.store.saved?.workspaces[desk.h.display])
    #expect(saved.lookingFrom == nil && saved.camera == saved.tree.root)
    #expect(saved.back == history + [origin])
    let read = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(saved))
    #expect(read == saved, "and it reads back as it was written")
    #expect(desk.h.workspace.lookingFrom == origin && desk.h.controller.isPeeking)
    // Held for long enough to be no tap, and let go where it began.
    desk.h.scheduler.advance(by: 1.2)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == origin && desk.h.workspace.back == history)
    desk.expectNoTrace()
    desk.h.controller.saveNow()
    #expect(desk.h.store.saved?.workspaces[desk.h.display] == desk.h.workspace, "and the file follows")
  }

  /// A crash in the middle of a peek, or a log-out. Back has not forgotten.
  @Test(arguments: [true, false]) func anArborThatStartsAfterOneThatEndedInMidPeekKnowsTheWayBack(byTheWatchdog: Bool) {
    let desk = Desk()
    let (origin, history) = (desk.h.workspace.camera, desk.h.workspace.back)
    desk.hold()
    desk.h.controller.saveNow()
    let h = desk.h.newProcess(byTheWatchdog: byTheWatchdog)
    h.start()
    #expect(h.workspace.lookingFrom == nil && !h.controller.isPeeking)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.workspace.back == history + [origin])
    #expect(h.controller.invariantViolations() == [])
    #expect(h.run("back").ok && h.workspace.camera == origin)
    expectWindowsMatchLayout(h)
  }

  /// A pause that asks nobody (the session ends, a game comes to the front) keeps what it will go on from. That is a stay too.
  @Test func aPauseThatComesInMidPeekGoesOnFromAStay() {
    let desk = Desk()
    let (origin, history) = (desk.h.workspace.camera, desk.h.workspace.back)
    desk.hold()
    desk.h.controller.sessionIsEnding()
    #expect(desk.h.controller.invariantViolations().filter { $0.rule == "leak" } == [])
    #expect(desk.h.run("resume").ok)
    #expect(desk.h.workspace.lookingFrom == nil && desk.h.workspace.camera == desk.root)
    #expect(desk.h.workspace.back == history + [origin])
    #expect(desk.h.controller.invariantViolations() == [])
  }

  // MARK: Windows that close

  @Test func whenTheOutlinedWindowClosesTheOutlineReturnsToWhereYouCameFrom() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    desk.h.system.close(desk.b)
    #expect(desk.h.controller.isPeeking, "the keys are still down")
    #expect(desk.outline == desk.h.layout!.windowFrames[desk.a])
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.a))
    desk.expectNoTrace()
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  @Test func whenTheWindowYouCameFromClosesLettingGoStaysOnEverything() {
    let desk = Desk()
    desk.hold()
    desk.h.system.close(desk.a)
    #expect(desk.outline == nil)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root)
    desk.expectNoTrace()
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  // MARK: Keys as macOS delivers them

  @Test func autoRepeatOfTheHeldKeyChangesNothing() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.h.keyDown(space)
    for _ in 0..<30 {
      desk.h.scheduler.advance(by: 0.05)
      desk.h.keyRepeat(space)
    }
    #expect(desk.h.controller.isPeeking)
    #expect(desk.outline == desk.place(desk.a))
    desk.h.keyUp(space)
    #expect(desk.h.workspace == before)
    desk.expectNoTrace()
  }

  @Test func autoRepeatAfterEscapeDoesNotStartAnotherPeek() {
    let desk = Desk()
    let before = desk.h.workspace
    desk.hold()
    desk.h.key("ctrl+opt+escape")
    for _ in 0..<10 {
      desk.h.scheduler.advance(by: 0.05)
      desk.h.keyRepeat(space)
    }
    #expect(desk.h.workspace == before)
    #expect(!desk.h.controller.isPeeking)
    desk.h.keyUp(space)
    desk.expectNoTrace()
    // A fresh press works.
    desk.hold()
    #expect(desk.h.controller.isPeeking)
    desk.h.keyUp(space)
  }

  @Test func aModifierGoingUpFirstLands() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    desk.h.system.heldModifiers = [.control]
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.h.workspace.camera == desk.leaf(desk.b))
    let landed = desk.h.workspace
    desk.h.keyUp(space)
    #expect(desk.h.workspace == landed)
    desk.expectNoTrace()
  }

  /// macOS reports Arbor's own `focus` call back a moment after the landing.
  @Test func theEchoOfTheLandingsFocusChangesNothing() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    desk.h.system.heldModifiers = []
    // The harness delivers echoes after each piece of scheduled work. Not here: the landing is looked at first.
    desk.h.scheduler.afterEach = nil
    desk.h.scheduler.advance(by: 0.1)
    let landed = desk.h.workspace
    #expect(landed.camera == desk.leaf(desk.b))
    #expect(desk.h.system.reportFocus() == 1)
    #expect(desk.h.workspace == landed)
    #expect(desk.h.system.focused == desk.b)
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  @Test func aReleaseThatIsNeverReportedStillEndsThePeek() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    desk.h.keyUp(space, reported: false)
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.h.workspace.camera == desk.leaf(desk.b))
    desk.expectNoTrace()
  }

  /// ⌃⌥ kept down between shortcuts, as people do: Space is tapped, the overview is looked at, ⌃⌥ come up later.
  @Test func aTapWithTheModifiersKeptDownStaysOnEverything() {
    for reported in [true, false] {
      let desk = Desk()
      desk.h.keyDown(space)
      desk.h.scheduler.advance(by: 0.1)
      desk.h.keyUp(space, reported: reported, keepingModifiers: true)
      desk.h.scheduler.advance(by: 2)
      #expect(desk.h.workspace.camera == desk.root, "reported: \(reported)")
      #expect(desk.outline == nil)
      desk.point(at: desk.b)
      desk.h.system.heldModifiers = []
      desk.h.scheduler.advance(by: 1)
      #expect(desk.h.workspace.camera == desk.root, "Show Everything never springs back after a tap (reported: \(reported))")
      desk.expectNoTrace()
    }
  }

  @Test func aTapHeardLateBecauseTheLayoutTookLongIsStillATap() {
    // The clock starts when everything shows, so time spent moving windows does not count. Here that
    // takes no time; what is pinned is that a release right after the press is a tap.
    let desk = Desk()
    desk.h.keyDown(space)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root)
    desk.expectNoTrace()
  }

  // MARK: Things that get in the way

  @Test func anotherShortcutDuringTheHoldRunsFromEverythingAndTheReleaseDoesNothing() {
    let desk = Desk(settings: .withEveryKey)
    let before = desk.h.workspace
    desk.hold()
    desk.point(at: desk.b)
    #expect(desk.h.key("ctrl+opt+d")?.ok == true)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.desktop)
    #expect(desk.h.workspace.back == before.back + [desk.leaf(desk.a), desk.root])
    let after = desk.h.workspace
    desk.h.scheduler.advance(by: 0.5)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == after)
    desk.expectNoTrace()
  }

  @Test func arrangingDuringTheHoldKeepsEverythingInView() {
    let desk = Desk(settings: .withEveryKey)
    desk.hold()
    #expect(desk.h.key("ctrl+opt+cmd+right")?.ok == true)
    #expect(desk.h.workspace.camera == desk.root)
    desk.h.keyUp(space)
    desk.h.scheduler.advance(by: 0.5)
    #expect(desk.h.workspace.camera == desk.root, "nothing jumps when the keys come up")
    desk.expectNoTrace()
    expectWindowsMatchLayout(desk.h, on: desk.h.display)
  }

  @Test func queriesDoNotDisturbAPeek() {
    let desk = Desk()
    desk.hold()
    desk.h.run("state", from: .script)
    desk.h.run("status", from: .script)
    #expect(desk.h.controller.isPeeking)
    desk.h.keyUp(space)
  }

  @Test func pausingDuringTheHoldLeavesNothingBehindAndResumingWorks() {
    let desk = Desk()
    desk.hold()
    desk.point(at: desk.b)
    #expect(desk.h.run("pause", from: .script).ok)
    desk.expectNoTrace()
    desk.h.keyUp(space)
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.controller.isPaused)
    #expect(desk.h.run("resume", from: .script).ok)
    #expect(desk.h.workspace.camera == desk.root)
    desk.hold()
    #expect(desk.h.controller.isPeeking)
    desk.h.keyUp(space)
    desk.expectNoTrace()
  }

  @Test func aPressWhileAWindowIsBeingDraggedIsAPlainShowEverything() {
    let desk = Desk()
    desk.h.run("show-all")
    desk.h.run("zoom \(desk.a.rawValue)")
    desk.h.system.mouseDown = true
    desk.h.controller.dragBegan(desk.a, at: CGPoint(x: 700, y: 40))
    #expect(desk.h.keyDown(space)?.ok == true, "the command ran")
    desk.h.scheduler.advance(by: 0.5)
    #expect(!desk.h.controller.isPeeking)
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root)
  }

  // MARK: From everything

  @Test func heldWithEverythingAlreadyShowingNothingIsOutlinedUntilSomethingIsChosen() {
    let desk = Desk()
    desk.h.run("show-all")
    let before = desk.h.workspace
    desk.hold()
    #expect(desk.h.controller.isPeeking)
    #expect(desk.outline == nil)
    desk.h.keyUp(space)
    #expect(desk.h.workspace == before)
    desk.hold()
    desk.h.key("ctrl+opt+down")
    #expect(desk.outline == desk.place(desk.c), "the arrows start from the focused window")
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.leaf(desk.c))
    #expect(desk.h.workspace.back == before.back + [desk.root])
  }

  // MARK: Settings

  @Test func withPeekOffHoldingIsTheSameAsTapping() {
    var settings = Settings()
    settings.peek = false
    let desk = Desk(settings: settings)
    #expect(desk.h.keyDown(space)?.ok == true)
    desk.h.scheduler.advance(by: 1)
    desk.point(at: desk.b)
    #expect(!desk.h.controller.isPeeking)
    #expect(desk.outline == nil)
    #expect(desk.h.key("ctrl+opt+right")?.ok == true, "the arrows keep their meaning")
    desk.h.run("show-all")
    desk.h.keyUp(space)
    #expect(desk.h.workspace.camera == desk.root)
    desk.expectNoTrace()
  }

  @Test func peekFollowsShowEverythingToWhateverShortcutItIsBoundTo() {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+space": nil, "ctrl+cmd+e": "show-all"]
    let desk = Desk(settings: settings)
    desk.h.keyDown("ctrl+cmd+e")
    desk.h.scheduler.advance(by: 0.4)
    #expect(desk.h.controller.isPeeking)
    #expect(
      desk.h.controller.temporaryShortcuts.map(\.chord.text) == [
        "ctrl+cmd+left", "ctrl+cmd+right", "ctrl+cmd+up", "ctrl+cmd+down", "ctrl+cmd+escape",
      ], "the arrows arrive with the modifiers that are held")
    desk.h.key("ctrl+cmd+down")
    #expect(desk.outline == desk.place(desk.c))
    #expect(desk.h.key("ctrl+opt+right")?.ok == true, "other modifiers: another shortcut, which gets in the way")
    #expect(!desk.h.controller.isPeeking)
    desk.h.keyUp("ctrl+cmd+e")
    desk.expectNoTrace()
  }

  @Test func onlyShowEverythingPeeks() {
    let desk = Desk(settings: .withEveryKey)
    #expect(desk.h.keyDown("ctrl+opt+0")?.ok == true)
    desk.h.scheduler.advance(by: 1)
    #expect(!desk.h.controller.isPeeking)
    desk.h.keyUp("ctrl+opt+0")
    #expect(desk.h.workspace.camera == desk.root)
  }

  // MARK: Two displays (with F56)

  /// Pointed at the other display, so the peek is there, while the keyboard stays in a window that never leaves view.
  @Test func landingTakesTheKeyboardAlongFromAnotherDisplay() {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    h.start()
    for (window, edge) in [(a, "left"), (b, "right"), (c, "left")] { h.run("dock \(window.rawValue) \(edge)") }
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(c)
    h.system.type()
    h.scheduler.advance(by: 2)
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.scheduler.advance(by: 0.2)
    h.keyDown(space)
    h.scheduler.advance(by: 0.4)
    #expect(h.overlays.scenes[main.id]?.peekOutline != nil, "the pointer moved last, so the peek is on its display")
    h.system.cursor = h.frame(b)!.center
    h.scheduler.advance(by: 0.1)
    h.keyUp(space)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b))
    #expect(h.system.focused == b, "c is still in view on its display, so nothing else would have moved the keyboard")
  }

  /// main: [ column [a / x] | Desktop | b ], the column too narrow to show as windows; side: c, which has the keyboard.
  /// The view on main is on b, the pointer moved last and lies at `pointer`, and ⌃⌥Space is held. `used` had the
  /// keyboard before, in that order. The windows were open before Arbor started, so it has seen no other use of them.
  private func peekBesideTheKeyboard(
    pointer: CGPoint, used: (_ a: WindowID, _ x: WindowID) -> [WindowID]
  ) -> (h: Harness, a: WindowID, x: WindowID, tile: TileModel) {
    var settings = Settings()
    settings.minimumUsableWidth = 500
    let h = Harness(displays: [main, side], settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 500, height: 400))
    let x = h.system.open(app: "Music", frame: CGRect(x: 100, y: 500, width: 500, height: 300))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    h.start()
    for (window, edge) in [(a, "left"), (b, "right"), (c, "left")] { h.run("dock \(window.rawValue) \(edge)") }
    h.run("dock \(x.rawValue) beside \(a.rawValue) bottom")
    for window in used(a, x) { h.system.userFocus(window) }
    h.run("zoom \(b.rawValue)")
    h.system.userFocus(c)
    h.system.type()
    h.scheduler.advance(by: 2)
    h.system.cursor = pointer
    h.scheduler.advance(by: 0.2)
    h.keyDown(space)
    h.scheduler.advance(by: 0.4)
    let tile = h.overlays.tiles[main.id]!.first { $0.items.contains { $0.window == x } }!
    #expect(tile.items.count == 2)
    #expect(h.system.focused == c)
    return (h, a, x, tile)
  }

  /// Low in the tile, which is low in the view once the group fills it: over x, the second of the two.
  private func pointLow(in tile: TileModel, _ h: Harness) {
    h.system.cursor = CGPoint(x: tile.frame.midX, y: tile.frame.maxY - 40)
    h.scheduler.advance(by: 0.1)
  }

  @Test func landingOnAGroupFromAnotherDisplayGivesTheKeyboardToTheWindowUsedLastThere() {
    let (h, a, x, tile) = peekBesideTheKeyboard(pointer: CGPoint(x: 400, y: 400)) { a, x in [x, a] }
    pointLow(in: tile, h)
    h.keyUp(space)
    #expect(h.workspace.camera == tile.node)
    #expect(h.frame(x)!.contains(h.system.cursor))
    #expect(h.system.focused == a, "c is still in view on its display, so only the landing moves the keyboard")
  }

  @Test func aPeekHappensOnTheDisplayThatHasTheKeyboard() {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    let d = h.system.open(app: "Terminal", frame: CGRect(x: 2100, y: 100, width: 500, height: 400))
    h.start()
    for (window, edge) in [(a, "left"), (b, "right"), (c, "left"), (d, "right")] { h.run("dock \(window.rawValue) \(edge)") }
    h.run("zoom \(a.rawValue)")
    h.run("zoom \(c.rawValue)")
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.scheduler.advance(by: 5)
    h.system.userFocus(c)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    let mainBefore = h.controller.workspaces[main.id]
    h.keyDown(space)
    h.scheduler.advance(by: 0.4)
    #expect(h.controller.workspaces[side.id]!.camera == h.controller.workspaces[side.id]!.tree.root)
    #expect(h.overlays.scenes[side.id]?.peekOutline != nil)
    #expect(h.overlays.scenes[main.id]?.peekOutline == nil)
    // The pointer wanders on the other display: nothing there can be chosen.
    h.system.cursor = CGPoint(x: 900, y: 500)
    h.scheduler.advance(by: 0.1)
    h.key("ctrl+opt+right")
    h.key("ctrl+opt+right")
    h.keyUp(space)
    #expect(h.controller.workspaces[side.id]!.camera == h.controller.workspaces[side.id]!.tree.leaf(containing: d))
    #expect(h.controller.workspaces[main.id] == mainBefore)
    #expect(h.system.focused == d)
  }

  // MARK: One frame at a time

  /// Seen on a hosted Mac: the line round the focused window and peek's outline, both in the accent colour, round two windows at
  /// once. Each exists to answer "which of these is the one?".
  @Test func whileAnOutlineShowsThereIsNoLineRoundTheFocusedWindow() {
    let desk = Desk()
    let rings = { desk.h.overlays.scenes.values.compactMap(\.focusRing) }
    #expect(rings().map(\.window) == [desk.a])
    desk.h.keyDown(space)
    desk.h.scheduler.advance(by: 0.1)
    #expect(desk.outline == nil && rings().map(\.window) == [desk.a], "a key that may yet be a tap takes nothing away")
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.outline != nil)
    #expect(rings().isEmpty)
    desk.point(at: desk.b)
    #expect(desk.outline == desk.place(desk.b))
    #expect(rings().isEmpty)
    // What would bring it back at any other time.
    desk.h.controller.keyboardFocusMoved()
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.outline != nil && rings().isEmpty)
  }

  @Test func itComesBackWithTheEndOfThePeekRoundWhoeverHasTheKeyboardThen() {
    let desk = Desk()
    let rings = { desk.h.overlays.scenes.values.compactMap(\.focusRing) }
    desk.hold()
    desk.point(at: desk.b)
    desk.h.keyUp(space)
    desk.h.scheduler.advance(by: 0.5)
    desk.expectNoTrace()
    #expect(desk.h.system.focused == desk.b)
    #expect(rings().map(\.window) == [desk.b])
    #expect(rings().first?.frame == desk.h.frame(desk.b))
  }

  @Test func afterAPeekThatGoesBackItIsWhereItWasAndDoesNotFlash() throws {
    let desk = Desk()
    let ring = { desk.h.overlays.scenes[desk.h.display]?.focusRing }
    let before = try #require(ring())
    desk.hold()
    desk.h.scheduler.advance(by: 2)
    #expect(ring() == nil)
    desk.h.keyUp(space)
    desk.h.scheduler.advance(by: 0.5)
    desk.expectNoTrace()
    #expect(desk.h.workspace.camera == desk.leaf(desk.a))
    #expect(ring() == before, "the same window, the same place, no pulse")
  }

  @Test func aLineOnAnotherDisplayGoesToo() {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 500, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    h.start()
    for (window, edge) in [(a, "left"), (b, "right"), (c, "left")] { h.run("dock \(window.rawValue) \(edge)") }
    h.run("zoom \(a.rawValue)")
    // The keyboard is on the side display, and the pointer, which says where a peek looks, on the main one.
    h.system.userFocus(c)
    h.scheduler.advance(by: 5)
    h.system.cursor = CGPoint(x: 400, y: 400)
    #expect(h.overlays.scenes[side.id]?.focusRing?.window == c)
    h.keyDown(space)
    h.scheduler.advance(by: 0.4)
    let outlines = h.overlays.scenes.values.compactMap(\.peekOutline)
    #expect(outlines.count == 1)
    #expect(h.overlays.scenes.values.compactMap(\.focusRing).isEmpty)
    h.keyUp(space)
    h.scheduler.advance(by: 0.5)
    #expect(h.overlays.scenes.values.compactMap(\.peekOutline).isEmpty)
    #expect(h.overlays.scenes.values.compactMap(\.focusRing).count == 1)
  }
}
