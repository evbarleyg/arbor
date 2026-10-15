import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = sideDisplay
/// A 1440×900 display above the standard one.
private let above = DisplaySnapshot(
  id: DisplayID("above"), frame: CGRect(x: 0, y: -900, width: 1440, height: 900),
  visibleFrame: CGRect(x: 0, y: -900, width: 1440, height: 900), isMain: false)

/// Scenario tests for `move-to-display` and `focus-display` (docs/features/F22-keyboard-tiling-tools.md).
@Suite @MainActor struct DisplayCommandTests {
  /// Main: [ a | Desktop | b ] and a floating f. Side: [ Desktop | c ]. The pointer is on the main display.
  func makeHarness(
    displays: [DisplaySnapshot]? = nil, settings: Settings = Harness.settingsWhenNoneAreGiven
  ) -> (Harness, a: WindowID, b: WindowID, c: WindowID, f: WindowID) {
    let h = Harness(displays: displays ?? [main, side], settings: settings)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "C", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    let f = h.system.open(app: "F", frame: CGRect(x: 560, y: 300, width: 320, height: 240))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) right"] { runOK(h, command) }
    return (h, a, b, c, f)
  }

  func workspace(_ h: Harness, _ display: DisplaySnapshot) -> Workspace { h.controller.workspaces[display.id]! }

  func columns(_ h: Harness, _ display: DisplaySnapshot) -> [[WindowID]] {
    let tree = workspace(h, display).tree
    return tree.children(of: tree.root).map { tree.windows(under: $0) }
  }

  // MARK: move-to-display

  @Test func aDockedWindowDocksAtTheEdgeFacingWhereItCameFrom() {
    let (h, a, b, c, _) = makeHarness()
    h.system.userFocus(b)
    #expect(runOK(h, "move-to-display next").message == "moved \(b) to display 2")
    #expect(columns(h, main) == [[a], []], "the room it left goes to the others")
    #expect(columns(h, side) == [[b], [], [c]], "it came from the left")
    #expect(h.frame(b)!.minX == side.visibleFrame.minX + 12)
    #expect(h.system.focused == b)
    expectSound(h)

    runOK(h, "move-to-display previous")
    #expect(columns(h, main) == [[a], [], [b]], "and back from the right")
    #expect(columns(h, side) == [[], [c]])
    expectSound(h)
  }

  @Test func aFloatingWindowFloatsInTheMiddleOfTheDesktop() {
    let (h, _, _, _, f) = makeHarness()
    h.system.userFocus(f)
    runOK(h, "move-to-display 2")
    #expect(workspace(h, side).isFloating(f) && !h.workspace.contains(f))
    let desktop = h.controller.layouts[side.id]!.desktopFrame!
    #expect(h.frame(f)!.size == CGSize(width: 320, height: 240), "its size is kept")
    #expect(abs(h.frame(f)!.midX - desktop.midX) <= 1 && abs(h.frame(f)!.midY - desktop.midY) <= 1)
    #expect(workspace(h, side).floating[f] == h.frame(f))
    #expect(h.system.focused == f)
    expectSound(h)
  }

  @Test(arguments: [false, true]) func aFloatingWindowTooBigForTheOtherDisplayIsFittedToIt(makingWay: Bool) {
    let (h, _, _, c, f) = makeHarness(settings: makingWay ? .makingWay : Settings())
    h.system.userMove(f, to: CGRect(x: 0, y: 25, width: 1440, height: 875))
    runOK(h, "move-to-display 2 \(f.rawValue)")
    if makingWay {
      // The Desktop, out to the edges of the display where nothing is docked beside it.
      #expect(side.visibleFrame.contains(h.frame(f)!) && !h.frame(f)!.overlaps(h.frame(c)!))
    } else {
      #expect(h.frame(f) == side.visibleFrame, "as much of its own size as the display has, over what is docked there")
    }
    #expect(h.frame(f)!.contains(h.controller.layouts[side.id]!.desktopFrame!))
  }

  /// Found by the chaos test: the window had not moved, and Arbor took it to be on the other display.
  @Test func aFloatingWindowWhoseAppDoesNotAnswerStaysAndIsKnownToStay() {
    let (h, _, _, _, f) = makeHarness()
    let (before, frame) = (h.controller.workspaces, h.frame(f))
    h.system.setUnresponsive(pid: h.system.windows[f]!.snapshot.pid, true)
    #expect(h.run("move-to-display 2 \(f.rawValue)").message == "\(f) stays where it is: its app does not answer")
    #expect(h.controller.workspaces == before && h.frame(f) == frame && h.controller.windows[f]?.frame == frame)
    h.system.setUnresponsive(pid: h.system.windows[f]!.snapshot.pid, false)
    runOK(h, "move-to-display 2 \(f.rawValue)")
    #expect(workspace(h, side).isFloating(f) && side.frame.contains(h.frame(f)!))
    expectSound(h)
  }

  /// Found by the random run: fitted to a small Desktop in the far corner, a window whose app keeps it larger hung off the display.
  /// Where floating windows do not make way it is not fitted to the Desktop, and must not hang off the display either.
  @Test(arguments: [false, true]) func aFloatingWindowThatCannotShrinkToTheDesktopThereStaysOnTheDisplay(makingWay: Bool) {
    let (h, _, _, c, _) = makeHarness(settings: makingWay ? .makingWay : Settings())
    let big = h.system.open(
      app: "Big", frame: CGRect(x: 300, y: 150, width: 720, height: 520), minimumSize: CGSize(width: 700, height: 500))
    // Side: [ d | [ c / Desktop ] ]: the Desktop is a small corner at the bottom right. (c goes up first: a second window in the
    // Desktop's row would take all that is left.)
    let d = h.system.open(app: "D", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    runOK(h, "dock \(c.rawValue) up")
    runOK(h, "dock \(d.rawValue) left")
    let desktop = h.controller.layouts[side.id]!.desktopFrame!
    #expect(desktop.width < 700 && desktop.height < 500 && desktop.maxX > side.frame.maxX - 20 && desktop.maxY > side.frame.maxY - 20)
    runOK(h, "move-to-display 2 \(big.rawValue)")
    #expect(side.visibleFrame.contains(h.frame(big)!), "over its docked neighbours rather than off the display")
    if makingWay {
      #expect(h.frame(big)!.size == CGSize(width: 700, height: 500))
    } else {
      #expect(h.frame(big) == workspace(h, side).floating[big], "nobody asked it to shrink: it is where it floats, at its own size")
    }
    #expect(workspace(h, side).floating[big]!.size == CGSize(width: 720, height: 520), "the size it gets back when there is room")
    expectSound(h)
  }

  @Test func withTheDesktopOutOfViewAFloatingWindowStillArrivesInView() {
    let (h, _, _, c, f) = makeHarness()
    runOK(h, "zoom \(c.rawValue)")
    h.system.userFocus(f)
    runOK(h, "move-to-display next")
    #expect(workspace(h, side).isFloating(f))
    #expect(workspace(h, side).camera == workspace(h, side).tree.leaf(containing: c), "the view there stays")
    #expect(h.system.isVisible(f) && !h.controller.parked.contains(f))
    #expect(abs(h.frame(f)!.midX - side.visibleFrame.midX) <= 1 && abs(h.frame(f)!.midY - side.visibleFrame.midY) <= 1)
  }

  /// F57: a floating window that arrives over a framed window would be gone at the next move of the view, and Back would
  /// not bring it back. It stays with that view, as one that opened there does.
  @Test func aFloatingWindowSentOverAFramedWindowStaysWithThatView() {
    let (h, _, _, c, f) = makeHarness()
    let d = h.system.open(app: "D", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    runOK(h, "dock \(d.rawValue) left")
    runOK(h, "zoom \(c.rawValue)")
    h.system.userFocus(f)
    runOK(h, "move-to-display next")
    #expect(workspace(h, side).guests?[f] == workspace(h, side).tree.leaf(containing: c))
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(d.rawValue)")
    #expect(!h.system.isVisible(f))
    #expect(h.press("back").ok, "on the display the keyboard is on")
    #expect(h.system.isVisible(f))
    // And it is nobody's guest any more once it has left.
    runOK(h, "move-to-display previous \(f.rawValue)")
    #expect(workspace(h, side).guests == nil && h.workspace.guests == nil)
    expectSound(h)
  }

  /// As for every `dock` command: a call or a note on a narrow Desktop does not end up over a tile. That is for the sake of
  /// windows that are kept on the Desktop: where floating windows make way, as until Q20.
  @Test func theDesktopThereStaysUsableWhileSomethingFloatsOnIt() {
    let (h, a, _, c, _) = makeHarness(settings: .makingWay.withDesktopColumn)
    let others = (0..<3).map { h.system.open(app: "D\($0)", frame: CGRect(x: 1700 + 20 * CGFloat($0), y: 200, width: 500, height: 400)) }
    h.system.cursor = side.visibleFrame.center
    runOK(h, "arrange")
    let call = h.system.open(app: "Call", frame: CGRect(x: 2500, y: 300, width: 200, height: 200))
    #expect(h.controller.layouts[side.id]!.desktopFrame?.contains(h.frame(call)!) == true)
    runOK(h, "move-to-display 2 \(a.rawValue)")
    #expect(h.controller.layouts[side.id]!.desktopFrame != nil, "not a tile")
    #expect(h.system.isVisible(call) && h.system.isVisible(a) && h.system.isVisible(c) && others.allSatisfy(h.system.isVisible))
    expectSound(h)
  }

  /// F18, which is off by default: who floats alone fills the Desktop, and sending a window away changes who is alone. It takes
  /// `floatingWindowsMakeWay` as well since Q20.
  @Test func theWindowLeftAloneOnTheDesktopTakesIt() {
    var settings = Settings.makingWay
    settings.soleFloatTakesDesktop = true
    let h = Harness(displays: [main, side], settings: settings)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let f = h.system.open(app: "F", frame: CGRect(x: 800, y: 300, width: 320, height: 240))
    let g = h.system.open(app: "G", frame: CGRect(x: 900, y: 400, width: 320, height: 240))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    #expect(h.frame(f)!.width == 320 && h.frame(g)!.width == 320)
    runOK(h, "move-to-display next \(g.rawValue)")
    #expect(h.frame(f)!.width > 600, "alone now")
    #expect(h.frame(g)!.size == CGSize(width: 320, height: 240))
    expectSound(h)
  }

  @Test func aFloatingWindowThatWasTuckedAwayArrivesInViewToo() {
    let (h, a, _, c, f) = makeHarness()
    runOK(h, "zoom \(a.rawValue)")
    runOK(h, "zoom \(c.rawValue)")
    #expect(h.controller.parked.contains(f))
    runOK(h, "move-to-display next \(f.rawValue)")
    #expect(h.system.isVisible(f) && !h.controller.parked.contains(f))
    #expect(side.visibleFrame.contains(h.frame(f)!))
    #expect(workspace(h, side).camera == workspace(h, side).tree.leaf(containing: c), "the view there stays")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "and the view it left")
  }

  @Test func aDockedWindowJoinsTheViewTheOtherDisplayIsShowing() {
    let (h, a, _, c, _) = makeHarness()
    let d = h.system.open(app: "D", frame: CGRect(x: 1700, y: 200, width: 500, height: 400))
    runOK(h, "dock \(d.rawValue) beside \(c.rawValue) bottom")
    runOK(h, "zoom \(c.rawValue)")
    runOK(h, "move-to-display 2 \(a.rawValue)")
    // The view was c alone; now it is c with the newcomer on its left, as for any window docked at the edge of a view.
    let there = workspace(h, side)
    #expect(there.tree.children(of: there.camera) == [there.tree.leaf(containing: a)!, there.tree.leaf(containing: c)!])
    #expect(h.system.isVisible(a) && h.system.isVisible(c) && !h.system.isVisible(d))
    expectSound(h)
  }

  @Test func aNamedWindowOutOfViewCanBeSent() {
    let (h, a, b, c, f) = makeHarness()
    runOK(h, "zoom \(a.rawValue)")
    #expect(h.controller.parked.isSuperset(of: [b, f]))
    runOK(h, "move-to-display next \(b.rawValue)")
    runOK(h, "move-to-display next \(f.rawValue)")
    #expect(columns(h, side) == [[b], [], [c]])
    #expect(h.system.isVisible(b) && h.system.isVisible(f))
    #expect(side.visibleFrame.contains(h.frame(b)!) && side.visibleFrame.contains(h.frame(f)!))
    #expect(h.frame(f)!.size == CGSize(width: 320, height: 240))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    expectSound(h)
  }

  @Test func sendingTheFramedWindowAwayLeavesAViewBehind() {
    let (h, a, b, _, _) = makeHarness()
    runOK(h, "zoom \(b.rawValue)")
    runOK(h, "move-to-display next")
    #expect(h.workspace.tree.contains(h.workspace.camera))
    #expect(h.system.isVisible(a))
    expectSound(h)
  }

  @Test func oneTabLeavesItsGroup() {
    var settings = Settings()
    settings.tabsEnabled = true
    let h = Harness(displays: [main, side], settings: settings)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "B", frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    h.system.drag(b, through: [CGPoint(x: 1050, y: 210), h.frame(a)!.center])
    #expect(columns(h, main) == [[a, b], []])
    h.system.userFocus(b)
    runOK(h, "move-to-display next")
    #expect(columns(h, main) == [[a], []])
    #expect(columns(h, side) == [[b], []])
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
    expectSound(h)
  }

  @Test(.withTiles) func aWindowTooBigForItsNewSlotIsFramedRatherThanLeftAsATile() {
    let (h, _, _, _, _) = makeHarness()
    // Too wide for the side display beside anything at all, even c as a tile (1244 points less 80; with a column for the Desktop, two
    // tiles: 1232 less 160). With less, the window with the keyboard would be served at its neighbours' cost (F61) and need no frame.
    let big = h.system.open(
      app: "Xcode", frame: CGRect(x: 100, y: 100, width: 1200, height: 700), minimumSize: CGSize(width: 1200, height: 700))
    runOK(h, "dock \(big.rawValue) left")
    h.system.userFocus(big)
    runOK(h, "move-to-display next")
    #expect(workspace(h, side).isDocked(big))
    #expect(h.system.isVisible(big), "it has focus, so it must show")
    #expect(workspace(h, side).camera == workspace(h, side).tree.leaf(containing: big))
    expectSound(h)
  }

  @Test func aMinimizedWindowMovesWithoutTakingFocus() {
    let (h, a, b, c, _) = makeHarness()
    h.system.setMinimized(b, true)
    h.system.userFocus(a)
    runOK(h, "move-to-display next \(b.rawValue)")
    #expect(workspace(h, side).isDocked(b))
    #expect(h.system.focused == a)
    h.system.setMinimized(b, false)
    #expect(columns(h, side) == [[b], [], [c]])
    #expect(side.visibleFrame.contains(h.frame(b)!))
    expectSound(h)
  }

  @Test func displaysAreCountedLeftToRightThenTopToBottom() {
    // Listed in another order than they are counted in: above (0,-900) is 1, main (0,0) is 2, side (1440,0) is 3.
    let (h, a, _, _, _) = makeHarness(displays: [main, side, above])
    #expect(runOK(h, "move-to-display 1 \(a.rawValue)").message == "moved \(a) to display 1")
    #expect(workspace(h, above).isDocked(a))
    #expect(h.frame(a)!.maxY == above.visibleFrame.maxY - 12, "it came from below")
    #expect(h.frame(a)!.width == above.visibleFrame.width - 24)
    #expect(runOK(h, "move-to-display next").message == "moved \(a) to display 2")
    #expect(h.frame(a)!.minY == main.visibleFrame.minY + 12, "and back from above")
    #expect(runOK(h, "move-to-display next").message == "moved \(a) to display 3")
    #expect(runOK(h, "move-to-display next").message == "moved \(a) to display 1", "wrapping around")
    #expect(runOK(h, "move-to-display previous").message == "moved \(a) to display 3")
    expectSound(h)
  }

  @Test func moveToDisplayRefusesWhatItCannotDo() {
    let (h, a, _, _, _) = makeHarness()
    let before = h.controller.workspaces
    h.system.userFocus(a)
    #expect(h.run("move-to-display 1").message == "\(a) is already on display 1")
    #expect(h.run("move-to-display 3").message == "no display 3; 2 connected")
    #expect(!h.run("move-to-display next 999").ok)
    h.system.focused = nil
    #expect(!h.run("move-to-display next").ok, "no window has the keyboard")
    #expect(h.controller.workspaces == before)

    let (single, w) = tilingScenario(["A"], ["dock $0 left"])
    single.system.userFocus(w[0])
    for target in ["next", "previous", "1"] {
      #expect(single.run("move-to-display \(target)").message == "there is only one display", "\(target)")
    }
    #expect(single.run("move-to-display 2").message == "no display 2; 1 connected")
  }

  /// Between displays a window leaves one arrangement and joins another, and must not end up in neither.
  @Test func aWindowRefusedOnTheOtherDisplayStaysDockedOnItsOwn() {
    let h = Harness(displays: [main, side])
    // A hundred windows, each docked inside the one before, which is as deep as groups nest; the view on the last.
    let windows = (0..<100).map { h.system.open(app: "App\($0)") }
    let visitor = h.system.open(app: "Visitor", frame: CGRect(x: 1600, y: 200, width: 500, height: 400))
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    for index in 1..<windows.count {
      h.run("dock \(windows[index].rawValue) beside \(windows[index - 1].rawValue) \(index % 2 == 1 ? "bottom" : "right")")
    }
    runOK(h, "zoom \(windows.last!.rawValue)")
    runOK(h, "dock \(visitor.rawValue) left")
    let (before, slot) = (h.controller.workspaces, h.frame(visitor))
    let refused = h.run("move-to-display 1 \(visitor.rawValue)")
    #expect(!refused.ok && refused.message.contains("100"), "\(refused.message)")
    #expect(h.controller.workspaces == before && h.frame(visitor) == slot)
  }

  /// F48: it has its own size back when it floats again, also after a journey.
  @Test func aDockedWindowSentAcrossStillKnowsTheSizeItFloatedAt() {
    let (h, _, b, _, _) = makeHarness()
    runOK(h, "move-to-display next \(b.rawValue)")
    runOK(h, "float \(b.rawValue)")
    #expect(h.frame(b)!.size == CGSize(width: 500, height: 400))
    #expect(side.visibleFrame.contains(h.frame(b)!))
    expectSound(h)
  }

  /// docs/MENU.md: hidden when the thing it is about does not exist.
  @Test func theMenuOffersTheOtherDisplayOnlyWhereThereIsOne() {
    let (h, a, _, _, _) = makeHarness(settings: Settings())
    h.system.userFocus(a)
    #expect(h.run("menu").text?.contains("Bottom\n    -----\n        Move to Next Display\n") == true)
    let (single, w) = tilingScenario(["A"], ["dock $0 left"])
    single.system.userFocus(w[0])
    #expect(single.run("menu").text?.contains("Move to Next Display") == false)
  }

  @Test func theMoveIsSaved() {
    let (h, _, b, _, _) = makeHarness()
    h.scheduler.runPending()
    runOK(h, "move-to-display next \(b.rawValue)")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[side.id]?.isDocked(b) == true)
    #expect(h.store.saved?.workspaces[main.id]?.contains(b) == false)
  }

  // MARK: focus-display

  @Test func focusDisplayFocusesTheLastFocusedWindowInViewThere() {
    let (h, a, b, c, _) = makeHarness()
    let d = h.system.open(app: "D", frame: CGRect(x: 1700, y: 200, width: 400, height: 300))
    h.system.userFocus(c)
    h.system.userFocus(d)
    h.system.userFocus(b)
    h.system.userFocus(a)
    let pointer = h.system.cursor
    #expect(runOK(h, "focus-display next").message == "focused \(d) on display 2", "the last one in focus, not the first in order")
    h.system.userFocus(c)
    h.system.userFocus(a)
    #expect(runOK(h, "focus-display next").message == "focused \(c) on display 2")
    #expect(h.system.focused == c)
    // Shortcuts follow the keyboard (F56), so they act there now. The pointer is where the hand left it.
    h.scheduler.advance(by: 1)
    #expect(h.press("focus-display 2").ok)
    #expect(h.press("zoom-node \(workspace(h, side).tree.leaf(containing: c)!.rawValue)").ok)
    #expect(h.system.cursor == pointer)
    #expect(workspace(h, side).camera == workspace(h, side).tree.leaf(containing: c))
    #expect(h.workspace.camera == h.workspace.tree.root)

    #expect(runOK(h, "focus-display previous").message == "focused \(a) on display 1")
    // d has gone out of view with the Desktop.
    #expect(!h.system.isVisible(d))
    #expect(runOK(h, "focus-display 2").message == "focused \(c) on display 2")
    expectSound(h)
  }

  @Test func withoutAFocusHistoryTheTopLeftWindowGetsFocus() {
    // Just launched, with the keyboard on the Desktop: nothing has had focus since.
    let h = Harness(displays: [main, side])
    h.system.open(app: "Low", frame: CGRect(x: 100, y: 500, width: 400, height: 300))
    let top = h.system.open(app: "Top", frame: CGRect(x: 700, y: 100, width: 400, height: 300))
    h.system.userFocusesNothing()
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(runOK(h, "focus-display next").message == "focused \(top) on display 1", "counting from the pointer's display")
  }

  @Test func aDisplayWithNothingInViewHasNothingToFocus() {
    let (h, a, _, c, _) = makeHarness()
    h.system.close(c)
    h.system.userFocus(a)
    #expect(h.run("focus-display 2").message == "no window is in view on display 2")
    #expect(h.system.focused == a)
  }

  /// With three displays the third could be reached only backwards or by its number (the reviewer's note).
  @Test func nextAndPreviousPassOverADisplayWithNothingInView() {
    let third = DisplaySnapshot(
      id: DisplayID("third"), frame: CGRect(x: 2720, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 2720, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [main, side, third])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    let z = h.system.open(app: "Z", frame: CGRect(x: 2900, y: 100, width: 400, height: 300))
    h.start()
    h.system.userFocus(a)
    #expect(runOK(h, "focus-display next").message == "focused \(z) on display 3")
    #expect(runOK(h, "focus-display next").message == "focused \(a) on display 1")
    #expect(runOK(h, "focus-display previous").message == "focused \(z) on display 3")
    #expect(runOK(h, "focus-display previous").message == "focused \(a) on display 1")
    #expect(h.run("focus-display 2").message == "no window is in view on display 2", "a number means that display")
    h.system.close(z)
    #expect(h.run("focus-display next").message == "no window is in view on another display")
    #expect(h.system.focused == a)
  }

  @Test func namingTheDisplayOneIsOnFocusesItsLastWindow() {
    let (h, a, b, _, _) = makeHarness()
    h.system.userFocus(b)
    h.system.userFocus(a)
    h.system.focused = nil
    #expect(runOK(h, "focus-display 1").message == "focused \(a) on display 1")
  }

  @Test func focusDisplayRefusesWhatItCannotDo() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("focus-display 3").message == "no display 3; 2 connected")
    let (single, _) = tilingScenario(["A"])
    #expect(single.run("focus-display next").message == "there is only one display")
    #expect(single.run("focus-display previous").message == "there is only one display")
    #expect(single.run("focus-display 2").message == "no display 2; 1 connected")
  }

  @Test func aWindowOnAnotherDisplayCanBeNamed() {
    let (h, a, _, c, _) = makeHarness()
    h.system.userFocus(a)
    runOK(h, "focus \(c.rawValue)")
    #expect(h.system.focused == c)
    runOK(h, "focus \(c.rawValue)")
    #expect(h.system.focused == c)
  }

  @Test func aDisplayThatGoesAwayIsNoLongerCounted() {
    let (h, a, _, _, _) = makeHarness()
    h.system.setDisplays([main])
    h.system.userFocus(a)
    #expect(h.run("focus-display next").message == "there is only one display")
    #expect(h.run("move-to-display 2").message == "no display 2; 1 connected")
  }
}

/// What must hold whatever else is going on.
@Suite @MainActor struct TilingRobustnessTests {
  /// Every F22 command, in every order a seeded generator comes up with, mixed with windows opening, closing,
  /// minimizing, hiding, going full screen and being clicked, with saved views, pauses, time passing, and title bars and
  /// edges held by the mouse meanwhile, on two displays: trees stay sound, windows stay where the layouts say,
  /// nothing refers to a space that is gone, no floating window vanishes, no command crashes.
  ///
  /// A seed stops at its first problem and prints the steps that led there, each of which arbor-sim or a test can repeat.
  @Test(arguments: Array<UInt64>(1...60)) func randomTilingCommandsKeepEverythingSound(seed: UInt64) {
    var random = SplitMix(seed: seed)
    var settings = Settings()
    settings.tabsEnabled = seed % 2 == 0
    settings.makeRoom = seed % 3 != 0
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay], settings: settings)
    h.start()
    var open: [WindowID] = []
    var steps: [String] = []
    /// The window whose title bar the mouse is holding.
    var dragged: WindowID?
    /// Where the hand let go of windows. One that is still there is where its user wants it, half off the display or not.
    var dropped: [WindowID: CGRect] = [:]
    func pick() -> UInt32 { open.isEmpty ? 999 : open[Int.random(in: 0..<open.count, using: &random)].rawValue }
    func pickOpen() -> WindowID? { open.isEmpty ? nil : open[Int.random(in: 0..<open.count, using: &random)] }
    func isPresent(_ window: WindowID) -> Bool { h.system.windows[window]?.snapshot.isPresent == true }
    func point() -> CGPoint {
      CGPoint(x: CGFloat(Int.random(in: 0..<2720, using: &random)), y: CGFloat(Int.random(in: 0..<800, using: &random)))
    }
    let directions = ["left", "right", "up", "down"]
    func direction() -> String { directions[Int.random(in: 0..<4, using: &random)] }
    let tilingVerbs: Set<String> = [
      "focus", "swap", "equalize", "rotate", "mirror", "grow", "shrink", "move-to-display", "focus-display",
    ]

    /// The first thing that is wrong, if anything is.
    func problem() -> String? {
      for (display, workspace) in h.controller.workspaces.sorted(by: { $0.key < $1.key }) {
        let problems = workspace.tree.invariantViolations()
        if !problems.isEmpty { return "\(display): \(problems)" }
        if !workspace.tree.contains(workspace.camera) { return "\(display): the view is on \(workspace.camera), which is gone" }
        for node in Array(workspace.savedViews.values) + Array((workspace.guests ?? [:]).values)
        where !workspace.tree.contains(node) {
          return "\(display): a saved view or a guest refers to \(node), which is gone"
        }
        // While the mouse holds a window, that window is where the mouse has it, and put-backs wait for the button.
        // And an app being hidden or shown is laid out once all its windows have been heard of.
        // So is a window that something else moved put back a moment later, and one that has just come back judged.
        let waiting = ["space-\(display.rawValue)", "enforce-\(display.rawValue)", "landed-\(display.rawValue)"]
        guard dragged == nil, h.system.resizing == nil, !h.scheduler.pendingKeys.contains(where: waiting.contains) else {
          continue
        }
        // Within two points: Arbor leaves a window alone when it is a point from its slot, and lets one hang over by two.
        for (window, frame) in (h.controller.layouts[display]?.windowFrames ?? [:]).sorted(by: { $0.key < $1.key })
        where h.frame(window)?.approximatelyEquals(frame, tolerance: 2) != true && !h.isShortForNow(window, in: frame) {
          return "\(display): \(window) is at \(String(describing: h.frame(window))), its slot at \(frame)"
        }
        for window in (h.controller.layouts[display]?.hiddenWindows ?? []).sorted() where h.system.isVisible(window) {
          return "\(display): \(window) should be out of view"
        }
      }
      // Each window is in exactly one place.
      let places = h.controller.workspaces.values.flatMap(\.allWindows)
      if Set(places).count != places.count { return "a window is in two places: \(places.sorted())" }
      // (A window that closed during a pause leaves its slot waiting for a while: Controller+PendingSlots.swift.)
      let known = Set(places.filter { h.system.windows[$0] != nil })
      if known != Set(open) { return "arranged: \(known.sorted()), open: \(open.sorted())" }
      return nil
    }

    for _ in 0..<250 {
      var line = ""
      switch Int.random(in: 0..<39, using: &random) {
      case 0, 1:
        let onSide = Bool.random(using: &random)
        let minimum = Int.random(in: 0..<4, using: &random) == 0 ? CGSize(width: 700, height: 500) : .zero
        let app = "App\(Int.random(in: 0..<5, using: &random))"
        let id = h.system.open(
          app: app, frame: CGRect(x: onSide ? 1700 : 300, y: 150, width: 720, height: 520), minimumSize: minimum)
        open.append(id)
        steps.append("(open \(id) of \(app) on \(onSide ? "side" : "main"), minimum \(minimum.width))")
      case 2:
        guard !open.isEmpty else { continue }
        let closed = open.remove(at: Int.random(in: 0..<open.count, using: &random))
        if dragged == closed {
          dragged = nil
          h.system.mouseDown = false
        }
        steps.append("(close \(closed))")
        h.system.close(closed)
      case 3:
        guard let id = pickOpen() else { continue }
        let minimized = Bool.random(using: &random)
        steps.append("(minimize \(id): \(minimized))")
        h.system.setMinimized(id, minimized)
      case 4:
        guard let id = pickOpen(), isPresent(id) else { continue }
        steps.append("(click \(id))")
        h.system.userFocus(id)
      case 29:
        guard let id = pickOpen(), let pid = h.system.windows[id]?.snapshot.pid else { continue }
        let hidden = Bool.random(using: &random)
        steps.append("(hide the app of \(id): \(hidden))")
        h.system.setHidden(pid: pid, hidden)
      case 30:
        guard let id = pickOpen(), id != dragged, h.system.resizing != id else { continue }
        let fullScreen = Bool.random(using: &random)
        // The green button of a window out of view cannot be clicked.
        guard !fullScreen || (isPresent(id) && h.system.isVisible(id)) else { continue }
        steps.append("(full screen \(id): \(fullScreen))")
        h.system.setFullScreen(id, fullScreen)
      case 31:
        // The mouse takes a title bar, or lets go of the one it holds. Commands run in between.
        if let held = dragged {
          dragged = nil
          h.system.mouseDown = false
          steps.append("(let go of \(held) at \(h.system.cursor))")
          dropped[held] = h.frame(held)
          h.controller.dragEnded(held, at: h.system.cursor)
        } else if h.system.resizing == nil, h.controller.isRunning, let id = pickOpen(), isPresent(id),
          h.system.isVisible(id), let frame = h.frame(id)
        {
          dragged = id
          h.system.mouseDown = true
          h.system.cursor = CGPoint(x: frame.midX, y: frame.minY + 10)
          h.system.heldModifiers = DragDocks.key
          h.controller.dragBegan(id, at: h.system.cursor)
          let target = point()
          steps.append("(drag \(id) to \(target) and hold)")
          h.system.cursor = target
          h.system.userMove(id, to: CGRect(x: target.x - frame.width / 2, y: target.y - 10, width: frame.width, height: frame.height))
          h.controller.dragMoved(id, to: target)
        }
      case 32:
        // The same with an edge.
        if h.system.resizing != nil {
          steps.append("(let go of the edge)")
          h.system.releaseMouse()
        } else if dragged == nil, let id = pickOpen(), isPresent(id), h.system.isVisible(id), let frame = h.frame(id) {
          // Four points or less count as the app's own rounding and are left alone.
          let by = CGFloat(Int.random(in: 10...60, using: &random)) * (Bool.random(using: &random) ? 1 : -1)
          steps.append("(pull both sides of \(id) by \(-by) and hold)")
          h.system.userResize(id, to: frame.insetBy(dx: by, dy: 0), release: false)
        }
      case 33:
        let seconds = [0.1, 0.3, 1, 5][Int.random(in: 0..<4, using: &random)]
        steps.append("(\(seconds) s pass)")
        h.scheduler.advance(by: seconds)
      case 34:
        h.system.cursor = point()
        steps.append("(pointer to \(h.system.cursor))")
        // A window in the hand comes along.
        if let held = dragged, let frame = h.frame(held) {
          let target = h.system.cursor
          h.system.userMove(held, to: CGRect(x: target.x - frame.width / 2, y: target.y - 10, width: frame.width, height: frame.height))
          h.controller.dragMoved(held, to: target)
        }
      case 35:
        line = (Bool.random(using: &random) ? "save-view " : "view ") + String(Int.random(in: 1...3, using: &random))
      case 36: line = Int.random(in: 0..<3, using: &random) == 0 ? "toggle-pause" : "resume"
      case 37:
        h.system.focusIsSlow.toggle()
        steps.append("(focus is slow: \(h.system.focusIsSlow))")
        h.system.finishSlowFocus()
      case 38: line = "toggle-pin \(pick())"
      case 5, 24, 25, 26: line = "dock \(pick()) \(direction())"
      case 27: line = "arrange"
      case 28: line = "float \(pick())"
      case 6: line = "dock \(pick()) beside \(pick()) \(direction())"
      case 7: line = ["show-all", "out", "in", "back", "desktop", "zoom \(pick())"][Int.random(in: 0..<6, using: &random)]
      case 8, 9, 10: line = "focus \(direction())"
      case 11: line = Bool.random(using: &random) ? "focus next" : "focus previous"
      case 12: line = "focus \(pick())"
      case 13, 14: line = "swap \(direction())"
      case 15: line = "swap \(pick()) \(pick())"
      case 16: line = Bool.random(using: &random) ? "equalize" : "equalize all"
      case 17: line = "rotate"
      case 18: line = "mirror"
      case 19: line = "grow \(Int.random(in: 1...400, using: &random))"
      case 20: line = "shrink \(Int.random(in: 1...400, using: &random))"
      case 21: line = "move-to-display \(["next", "previous", "1", "2", "3"][Int.random(in: 0..<5, using: &random)])"
      case 22: line = "move-to-display next \(pick())"
      default: line = "focus-display \(["next", "previous", "1", "2", "3"][Int.random(in: 0..<5, using: &random)])"
      }
      // What a tiling command must leave in view: the floating windows of every display whose view it does not move.
      let cameras = h.controller.workspaces.mapValues(\.camera)
      let floatingInView = h.controller.workspaces.mapValues { workspace in
        workspace.floating.keys.filter { isPresent($0) && h.system.isVisible($0) }.sorted()
      }
      let keyboardWasInView = h.system.focused.map { !h.controller.parked.contains($0) } ?? true
      var found: String?
      if !line.isEmpty {
        let result = h.run(line)
        steps.append(line + (result.ok ? "" : "   -> " + result.message))
        if h.controller.isRunning, let verb = line.split(separator: " ").first, tilingVerbs.contains(String(verb)) {
          if result.ok, keyboardWasInView, dragged == nil, !h.system.focusIsSlow, let focused = h.system.focused,
            h.controller.parked.contains(focused), let home = h.controller.workspaces.first(where: { $0.value.contains(focused) }),
            // On an empty Desktop there is nothing else to give it to, and a pinned window is never given it unasked.
            home.value.allWindows.contains(where: {
              isPresent($0) && !h.controller.parked.contains($0) && !home.value.isPinned($0)
            })
          {
            found = "\(focused) has the keyboard but is out of view"
          }
          for (display, windows) in floatingInView where h.controller.workspaces[display]?.camera == cameras[display] {
            for window in windows where window != dragged && !h.system.isVisible(window) {
              found = "floating \(window) vanished though the view of \(display) stayed"
            }
          }
        }
      }
      guard h.controller.isRunning else { continue }
      if let found = found ?? problem() {
        let picture = h.controller.perform(.ascii).text ?? ""
        Issue.record("seed \(seed): \(found)\n  \(steps.joined(separator: "\n  "))\n\(picture)")
        return
      }
    }
    h.controller.shutdown()
    // Where a hand let go of it a window is its person's, also when Arbor has given it its own size back there: no less of it shows.
    func shown(_ frame: CGRect?) -> CGFloat { frame.flatMap { frame in h.system.displayList.map { frame.fractionInside($0.frame) }.max() } ?? 0 }
    for window in open
    where isPresent(window) && !h.system.isVisible(window) && window != dragged
      && (dropped[window].map { shown(h.frame(window)) < shown($0) - 0.001 } ?? true)
    {
      Issue.record("seed \(seed): \(window) is lost after quitting, at \(String(describing: h.frame(window)))\n  \(steps.joined(separator: "\n  "))")
    }
  }
}

/// SplitMix64, so the random test is reproducible.
private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  /// Not a multiple of the step `next()` takes: with that, seed n + 1 gives the numbers of seed n from the second on,
  /// and a hundred seeds are one run looked at a hundred times.
  init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
