import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay
private let onMain = CGPoint(x: 700, y: 450)
private let onSide = CGPoint(x: 2000, y: 400)

/// Everything a user could tell apart: the workspaces, which windows are tucked away, and where
/// each of the others is.
private struct Picture: Equatable {
  var workspaces: [DisplayID: Workspace]
  var frames: [WindowID: CGRect]
  var parked: Set<WindowID>

  @MainActor init(_ h: Harness) {
    workspaces = h.controller.workspaces
    parked = h.controller.parked
    frames = [:]
    for window in h.system.allWindows() where !h.controller.parked.contains(window.id) {
      frames[window.id] = window.frame
    }
  }
}

/// What must hold whatever happened: every window Arbor arranges is in exactly one workspace, docked
/// or floating but not both; the trees are valid; the cameras exist; windows are where the layout says.
@MainActor
private func expectConsistent(_ h: Harness, _ note: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
  var seen: [WindowID: Int] = [:]
  for (display, workspace) in h.controller.workspaces {
    let problems = workspace.tree.invariantViolations()
    #expect(problems.isEmpty, "\(display): \(problems) \(note)", sourceLocation: sourceLocation)
    #expect(workspace.tree.contains(workspace.camera), "\(display): camera \(note)", sourceLocation: sourceLocation)
    for window in workspace.tree.allWindows + Array(workspace.floating.keys) { seen[window, default: 0] += 1 }
    guard let layout = h.controller.layouts[display] else {
      Issue.record("no layout for \(display) \(note)", sourceLocation: sourceLocation)
      continue
    }
    for (window, frame) in layout.windowFrames {
      // A window within a point of its slot is left alone. So is one that stops two points short of it: that is no refusal (`SeenSizes.slack`).
      // (Seed 22, as Arbor ships: a slot 448 points high for a window that goes no lower than 450.)
      let stops = h.system.windows[window]?.minimumSize ?? .zero
      let stopsJustShort =
        h.frame(window).map {
          $0.origin == frame.origin && $0.size == CGSize(width: max(frame.width, stops.width), height: max(frame.height, stops.height))
            && $0.width - frame.width <= 2 && $0.height - frame.height <= 2
        } == true
      #expect(
        h.frame(window)?.approximatelyEquals(frame, tolerance: 1) == true || stopsJustShort,
        "\(window) is not in its slot \(note): at \(String(describing: h.frame(window))), the slot is \(frame)",
        sourceLocation: sourceLocation)
      #expect(!h.controller.parked.contains(window), "\(window) counts as parked \(note)", sourceLocation: sourceLocation)
    }
    for window in layout.hiddenWindows {
      #expect(!h.system.isVisible(window), "\(window) should be out of view \(note)", sourceLocation: sourceLocation)
      #expect(h.controller.parked.contains(window), "\(window) is not parked \(note)", sourceLocation: sourceLocation)
    }
    // A floating window in view is on screen, unless the user left it hanging off the edge: a strip wide enough to see
    // and grab is a place, and stays one (`Controller.reach(of:for:on:)`, `leastStrip`).
    for (window, placed) in workspace.floating {
      guard h.controller.windows[window]?.isPresent == true, !h.controller.parked.contains(window) else { continue }
      let showsAStrip = h.system.displays().contains { display in
        let showing = h.frame(window)?.intersection(display.visibleFrame) ?? .zero
        return showing.width >= 24 && showing.height >= 24
      }
      #expect(
        h.system.isVisible(window) || h.frame(window) == placed || showsAStrip,
        "\(window) is lost at \(String(describing: h.frame(window))) \(note)", sourceLocation: sourceLocation)
    }
  }
  for window in h.system.allWindows() {
    #expect(seen[window.id] == 1, "\(window.id) is in \(seen[window.id] ?? 0) places \(note)", sourceLocation: sourceLocation)
  }
  #expect(seen.count == h.system.allWindows().count, "closed windows remain \(note)", sourceLocation: sourceLocation)
}

/// Undo and redo (docs/features/F19-undo.md).
@Suite @MainActor struct UndoTests {
  /// Three floating windows, started.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  /// [a / c | b], two halves, with d floating over the middle.
  func makeArrangement(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID, WindowID) {
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let d = h.system.open(app: "Terminal", frame: CGRect(x: 508, y: 77, width: 300, height: 200))
    return (h, a, b, c, d)
  }

  func undoLabels(_ h: Harness, on display: DisplayID? = nil) -> [String] {
    h.controller.undoHistory.steps(.undo, on: display ?? h.display).map(\.label)
  }

  func redoLabels(_ h: Harness, on display: DisplayID? = nil) -> [String] {
    h.controller.undoHistory.steps(.redo, on: display ?? h.display).map(\.label)
  }

  // MARK: The basics

  @Test func undoTakesBackADockAndRedoPutsItBack() {
    let (h, a, _, _) = makeHarness()
    let floating = Picture(h)
    #expect(h.run("dock \(a.rawValue) left").ok)
    let docked = Picture(h)
    #expect(docked != floating)

    let undone = h.run("undo")
    #expect(undone.ok)
    #expect(undone.message == "undid dock \(a) left")
    #expect(Picture(h) == floating)

    let redone = h.run("redo")
    #expect(redone.ok)
    #expect(redone.message == "redid dock \(a) left")
    #expect(Picture(h) == docked)

    #expect(h.run("undo").ok)
    #expect(Picture(h) == floating)
    expectConsistent(h)
  }

  @Test func theMessageNamesTheFocusedWindowACommandActedOn() {
    let (h, _, b, _) = makeHarness()
    h.system.focus(b)
    h.run("dock right")
    #expect(h.run("undo").message == "undid dock \(b) right")
  }

  @Test(arguments: [
    "dock 104 left", "dock 104 beside 102 top", "dock 101 right", "dock 103 right", "dock 102 beside 101 top",
    "float 101", "float 102", "toggle-float 103", "toggle-float 104", "arrange", "float-all",
    "resize 101 right 120", "resize 103 top -60", "resize 102 left 90",
  ])
  func everyChangeToTheArrangementIsOneStep(command: String) {
    let (h, _, _, _, _) = makeArrangement()
    let steps = undoLabels(h).count
    let before = Picture(h)
    #expect(h.run(command).ok, "\(command)")
    let after = Picture(h)
    #expect(after != before)
    #expect(undoLabels(h).count == steps + 1)

    #expect(h.run("undo").ok)
    #expect(Picture(h) == before, "undo \(command)")
    expectConsistent(h)
    #expect(h.run("redo").ok)
    #expect(Picture(h) == after, "redo \(command)")
    expectConsistent(h)
  }

  @Test func stepsAreTakenBackInReverseOrder() {
    let (h, a, b, c) = makeHarness()
    var pictures = [Picture(h)]
    for command in [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(a.rawValue) bottom",
      "resize \(a.rawValue) right 100", "float \(b.rawValue)", "arrange", "float-all",
    ] {
      #expect(h.run(command).ok)
      pictures.append(Picture(h))
    }
    for picture in pictures.dropLast().reversed() {
      #expect(h.run("undo").ok)
      #expect(Picture(h) == picture)
    }
    #expect(!h.run("undo").ok)
    for picture in pictures.dropFirst() {
      #expect(h.run("redo").ok)
      #expect(Picture(h) == picture)
    }
    #expect(!h.run("redo").ok)
  }

  @Test func withNothingToUndoOrRedoTheCommandsSaySo() {
    let (h, a, _, _) = makeHarness()
    let before = Picture(h)
    let undo = h.run("undo")
    #expect(!undo.ok)
    #expect(undo.message == "nothing to undo")
    let redo = h.run("redo")
    #expect(!redo.ok)
    #expect(redo.message == "nothing to redo")
    #expect(Picture(h) == before)

    h.run("dock \(a.rawValue) left")
    #expect(!h.run("redo").ok, "nothing was undone yet")
  }

  @Test func aNewChangeClearsRedo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    #expect(redoLabels(h) == ["dock \(b) right"])
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    #expect(redoLabels(h).isEmpty)
    #expect(!h.run("redo").ok)
    #expect(undoLabels(h) == ["dock \(a) left", "dock \(b) beside \(a) bottom"])
  }

  @Test func cameraMovesDoNotClearRedo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("save-view 1")
    #expect(h.run("redo").ok)
    #expect(h.workspace.isDocked(b))
  }

  @Test func onlyFiftyStepsAreKept() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    for _ in 0..<30 {
      h.run("resize \(a.rawValue) right 10")
      h.scheduler.advance(by: 2)  // apart, or they would be one adjustment
      h.run("resize \(a.rawValue) right -10")
      h.scheduler.advance(by: 2)
    }
    #expect(undoLabels(h).count == UndoHistory.limit)
    var undone = 0
    while h.run("undo").ok { undone += 1 }
    #expect(undone == UndoHistory.limit)
    #expect(h.workspace.isDocked(a), "the dock is too long ago")
    #expect(redoLabels(h).count == UndoHistory.limit)
  }

  @Test func quickResizesOfOneEdgeAreOneStep() {
    // A shortcut that moves an edge a little, tapped a dozen times, must not fill the history.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let before = Picture(h)
    for _ in 0..<12 {
      #expect(h.run("resize \(a.rawValue) right 10").ok)
      h.scheduler.advance(by: 0.3)
    }
    let after = Picture(h)
    #expect(abs(h.frame(a)!.width - (before.frames[a]!.width + 120)) <= 1)
    #expect(undoLabels(h) == ["dock \(a) left", "resize \(a) right"])
    #expect(h.run("undo").message == "undid resize \(a) right")
    #expect(Picture(h) == before)
    #expect(h.run("redo").ok)
    #expect(Picture(h) == after)
  }

  @Test func aPauseAnotherEdgeOrAnotherChangeStartsANewResize() {
    let (h, a, b, c, _) = makeArrangement()
    let steps = undoLabels(h).count
    h.run("resize \(a.rawValue) right 10")
    h.run("resize \(a.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 1)
    h.scheduler.advance(by: Controller.undoMergePause + 0.1)
    h.run("resize \(a.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 2, "after a pause")
    h.run("resize \(a.rawValue) bottom 10")
    #expect(undoLabels(h).count == steps + 3, "another edge")
    h.run("resize \(c.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 4, "another window")
    h.run("resize \(c.rawValue) right 10")
    h.run("float \(b.rawValue)")
    h.run("resize \(c.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 6, "another change in between")
    h.run("undo")
    h.run("resize \(c.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 6, "an undo in between")
    h.system.focus(a)
    h.run("resize right 10")
    h.run("resize \(a.rawValue) right 10")
    #expect(undoLabels(h).count == steps + 7, "the focused window, named or not")
  }

  @Test func whatChangesNothingIsNotAStep() {
    let (h, a, b, _, d) = makeArrangement()
    let steps = undoLabels(h)
    for command in [
      "dock \(b.rawValue) right",  // already at the edge
      "float \(d.rawValue)",  // already floating
      "resize \(a.rawValue) left 50",  // nothing on that side
      "dock 999 left", "relayout", "reload-settings", "state", "ascii", "status", "bindings", "rules",
      "zoom \(b.rawValue)", "back", "forward", "show-all", "desktop", "out", "in", "neighbor left",
      "save-view 1", "view 1", "frame-rect 12 37 472 400",
    ] {
      h.run(command)
      #expect(undoLabels(h) == steps, "\(command)")
    }
  }

  @Test func theMenuNamesTheStepInAWordOrTwo() throws {
    let (h, a, b, c) = makeHarness()
    func titles() -> [String?] { [h.controller.nextStepTitle(.undo), h.controller.nextStepTitle(.redo)] }
    #expect(titles() == [nil, nil])
    for (command, title) in [
      ("dock \(a.rawValue) left", "Dock"), ("dock \(b.rawValue) beside \(a.rawValue) bottom", "Dock"),
      ("resize \(a.rawValue) right 40", "Resize"), ("float \(b.rawValue)", "Float"), ("toggle-float \(b.rawValue)", "Dock"),
      ("toggle-float \(b.rawValue)", "Float"), ("pin \(a.rawValue)", "Keep in View"), ("arrange", "Arrange"),
      ("arrange all", "Arrange"), ("float-all", "Float All"), ("dock \(c.rawValue) right", "Dock"), ("float-all here", "Float All"),
    ] {
      // (`arrange all` straight after `arrange` changes nothing, and the step before it stays the newest.)
      h.run(command)
      #expect(titles() == [title, nil], "\(command)")
    }
    h.run("undo")
    #expect(titles() == ["Dock", "Float All"], "a step keeps its name on the way back")

    h.run("dock \(a.rawValue) left")
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    #expect(titles()[0] == "Resize")
    let frame = try #require(h.frame(b))
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(b, through: [CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: 1437, y: 450)])
    #expect(h.workspace.isDocked(b))
    #expect(titles()[0] == "Dock")
  }

  @Test func undoIsRefusedInAWindowThatIsFullScreen() {
    // Its arrangement is on another of the macOS Spaces, where nobody would see it change. `dock` is refused as well.
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    h.system.userFocus(a)
    h.system.setFullScreen(a, true)
    for verb in ["undo", "redo"] {
      let result = h.run(verb)
      #expect(!result.ok)
      #expect(result.message == "\(a) is full screen")
    }
    h.system.setFullScreen(a, false)
    #expect(h.run("redo").ok)
    #expect(h.run("undo").ok)
  }

  @Test func undoWaitsWhileTheViewIsHeld() {
    // It can move the view, which `hold` promises will not happen (F58). The history is there after `release`.
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    #expect(h.run("hold").ok)
    for verb in ["undo", "redo"] {
      let result = h.run(verb)
      #expect(!result.ok)
      #expect(result.message.contains("held"), "\(result.message)")
    }
    #expect(h.run("release").ok)
    #expect(h.run("redo").message == "redid dock \(b) right")
    #expect(h.run("undo").ok)
  }

  @Test func theDefaultKeysAreControlOptionZ() {
    #expect(KeyBindings.label(for: .undo, in: KeyBindings.all) == "⌃⌥Z")
    #expect(KeyBindings.label(for: .redo, in: KeyBindings.all) == "⌃⌥⇧Z")
  }

  @Test func stateSaysWhatUndoAndRedoWouldDo() throws {
    let (h, a, b, _) = makeHarness()
    var display = try #require(h.run("state").state?.displays.first)
    #expect(display.undo == nil && display.redo == nil)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    display = try #require(h.run("state").state?.displays.first)
    #expect(display.undo == "dock \(a) left")
    #expect(display.redo == "dock \(b) right")
    #expect(h.controller.nextStepLabel(.undo) == "dock \(a) left")
    #expect(h.controller.nextStepLabel(.redo) == "dock \(b) right")
    // Through JSON, as `arborctl state` sends it.
    let decoded = try JSONDecoder().decode(StateSnapshot.Display.self, from: JSONEncoder().encode(display))
    #expect(decoded == display)
  }

  @Test func observersHearAboutARestoredArrangement() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    var changes: [Controller.Change] = []
    h.controller.observe { changes.append($0) }
    h.run("undo")
    #expect(changes == [.layout(h.display), .camera(h.display), .savedViews(h.display), .names(h.display)])
  }

  @Test func undoIsSavedLikeAnyOtherChange() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.isDocked(a) == true)
    h.run("undo")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.isFloating(a) == true)
  }

  @Test func theHistoryDoesNotSurviveARestart() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.controller.saveNow()
    let again = Harness(saved: h.store.saved)
    for window in h.system.allWindows() {
      again.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    again.start()
    #expect(again.workspace.isDocked(a))
    #expect(!again.run("undo").ok)
  }

  @Test func theHistorySurvivesAPause() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    #expect(h.run("pause").ok)
    let paused = h.run("undo")
    #expect(!paused.ok)
    #expect(paused.message.contains("paused"))
    #expect(h.run("resume").ok)
    #expect(h.workspace.isDocked(a))
    #expect(h.run("redo").message == "redid dock \(b) right")
    #expect(h.run("undo").ok)
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.workspace.tree.allWindows.isEmpty)
    expectConsistent(h)
  }

  @Test func windowsClosedDuringAPauseDoNotComeBack() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("float-all")
    h.run("pause")
    h.system.close(b)
    h.run("resume")
    #expect(h.run("undo").message == "undid float-all")
    #expect(h.workspace.tree.allWindows == [a])
    expectConsistent(h)
  }

  @Test func aPauseInTheMiddleOfAGapDragLeavesNoTimerRunning() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    #expect(h.scheduler.pendingKeys.contains { $0.hasPrefix("undo-continuation") })
    h.run("pause")
    h.scheduler.advance(by: 1)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("undo-continuation") })
  }

  @Test func undoExplainsItselfBeforeStarting() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let result = h.run("undo")
    #expect(!result.ok)
    #expect(result.message.contains("Accessibility"))
  }

  // MARK: The camera

  @Test func cameraMovesAreNotUndone() {
    let (h, a, b, _, _) = makeArrangement()
    let height = h.frame(a)!.height
    h.run("resize \(a.rawValue) bottom 60")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    let share = h.frame(a)!.height / h.visibleFrame.height
    #expect(h.run("undo").message == "undid resize \(a) bottom")
    #expect(h.workspace.camera == column, "still looking at the column, where the change shows")
    #expect(h.frame(a)!.height / h.visibleFrame.height < share)
    #expect(!h.system.isVisible(b))
    #expect(h.run("back").ok, "history is still there")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.frame(a)!.height == height)
    expectConsistent(h)
  }

  @Test func whenNothingInViewWouldChangeTheViewStepsOutToShowWhatDid() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    // a would go on filling the view, and the user would press again.
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.workspace.isFloating(b))
    #expect(h.system.isVisible(b))
    #expect(h.run("back").ok, "the way back to the framed window")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    expectConsistent(h)

    // Redo straight after an undo puts the view back with everything else.
    h.run("show-all")
    h.run("redo")
    h.run("zoom \(a.rawValue)")
    let framed = Picture(h)
    h.run("undo")
    h.run("redo")
    #expect(Picture(h).frames == framed.frames)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func theViewStepsOutOnlyAsFarAsItMust() {
    // [a | Desktop | b / (c | e)], framed on c.
    let (h, a, b, c) = makeHarness()
    let e = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 400, height: 300))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("dock \(e.rawValue) beside \(c.rawValue) right")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: b)!)!
    h.run("resize \(b.rawValue) bottom 60")
    h.run("zoom \(c.rawValue)")
    #expect(h.run("undo").message == "undid resize \(b) bottom")
    #expect(h.workspace.camera == column, "the column shows the gap under b; everything is not needed")
    #expect(h.system.isVisible(b) && h.system.isVisible(c) && h.system.isVisible(e))
    #expect(!h.system.isVisible(a))
    expectConsistent(h)
  }

  @Test(arguments: ["float", "pin"])
  func theViewStepsOutUntilTheWindowThatIsDockedAgainIsInView(command: String) {
    // [a | Desktop | b] over c. c leaves the arrangement, and a is framed.
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) bottom")
    h.run("\(command) \(c.rawValue)")
    h.run("zoom \(a.rawValue)")
    #expect(h.run("undo").message == "undid \(command) \(c)")
    // The row above c already looks different, c having left the Desktop. But where did it go?
    #expect(h.workspace.isDocked(c))
    #expect(h.system.isVisible(c), "the window the undo was about")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    expectConsistent(h)
  }

  @Test(arguments: [false, true]) func theViewStepsOutUntilTheWindowThatFloatsAgainIsInView(makingWay: Bool) {
    // [a | b / (c | e)], framed on c.
    let (h, a, b, c) = makeHarness(settings: makingWay ? .makingWay : Settings())
    let e = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 400, height: 300))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("dock \(e.rawValue) beside \(c.rawValue) right")
    h.run("zoom \(c.rawValue)")
    #expect(h.run("undo").message == "undid dock \(e) beside \(c) right")
    // The column b / c would show that e has left. It floats again, which shows where the Desktop is part of the view.
    #expect(h.workspace.isFloating(e))
    #expect(h.system.isVisible(e))
    #expect(h.workspace.camera == h.workspace.tree.root)
    // (Nothing is left over, so that it has nowhere to make way to either.)
    #expect(h.frame(e) == CGRect(x: 600, y: 300, width: 400, height: 300), "exactly where it floated before it was docked")
    expectConsistent(h)
  }

  @Test func aChangeThatShowsFromNowhereLeavesTheViewAlone() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("resize \(b.rawValue) bottom 50")
    h.system.setMinimized(b, true)
    h.system.setMinimized(c, true)
    h.run("zoom \(a.rawValue)")
    #expect(h.run("undo").message == "undid resize \(b) bottom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aCameraWhoseNodeIsGoneGoesBackToWhereItWasBeforeTheChange() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    #expect(h.run("undo").ok)
    #expect(h.workspace.camera == h.workspace.tree.root, "b's leaf is gone; the camera was on everything")
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
    expectConsistent(h)
  }

  @Test func theHistoryOfTheViewNeverEndsWhereTheViewIs() throws {
    // b is framed, and the undo takes its space away: the view goes back to everything, where Back would lead as well.
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.workspace.back.last != h.workspace.camera && h.workspace.forward.last != h.workspace.camera)
    let state = try #require(h.run("state").state?.displays.first)
    #expect(state.canGoBack == h.run("back").ok, "what `state` promises, `back` does")
    let saved = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(h.workspace))
    #expect(saved == h.workspace, "and what is saved reads back the same")
  }

  @Test func aChangeThatMovedTheCameraIsUndoneWithIt() {
    // Floating the framed window throws the camera out to its parent.
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let framed = Picture(h)
    #expect(h.run("toggle-float \(a.rawValue)").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == framed, "a fills the view again")
  }

  @Test func undoingArrangeBringsBackTheCameraHistoryAndSavedViews() {
    let (h, a, b, _, _) = makeArrangement()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 2")
    h.run("zoom \(b.rawValue)")
    let before = Picture(h)
    #expect(h.run("arrange").ok)
    #expect(h.workspace.savedViews.isEmpty && h.workspace.back.isEmpty)
    #expect(h.run("undo").message == "undid arrange")
    #expect(Picture(h) == before)
    #expect(h.run("view 2").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func afterArrangeACameraMovedSinceDoesNotLandOnAnUnrelatedNode() throws {
    let (h, a, b, c, d) = makeArrangement()
    h.run("zoom \(b.rawValue)")
    let before = h.workspace
    h.run("arrange")
    // The new tree numbers its nodes from 1 again. Frame a window whose leaf has a number that
    // means something else in the old tree.
    let arranged = h.workspace.tree
    let window = try #require(
      [a, b, c, d].first { window in
        let leaf = arranged.leaf(containing: window)!
        return before.tree.contains(leaf) && before.tree.leaf(containing: window) != leaf
      })
    h.run("zoom \(window.rawValue)")
    h.run("undo")
    #expect(h.workspace.camera == before.camera)
    #expect(h.workspace.tree == before.tree)
    expectConsistent(h)
  }

  @Test func floatAllFromAFramedWindowIsUndoneWithTheView() {
    let (h, a, b, c, d) = makeArrangement()
    h.run("zoom \(a.rawValue)")
    let before = Picture(h)
    #expect(before.parked == [b, c, d])
    #expect(h.run("float-all").ok)
    #expect(h.controller.parked.isEmpty)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == before)
    expectConsistent(h)
  }

  @Test func aViewSavedSinceSurvivesTheUndo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 4")
    h.run("show-all")
    h.run("undo")
    #expect(h.workspace.isFloating(b))
    #expect(h.run("view 4").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func focusMovesOffAWindowTheUndoPutOutOfView() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    // Docking widens the camera to show b; undoing narrows it again and b leaves with the Desktop.
    h.run("dock \(b.rawValue) right")
    #expect(h.system.focused == b)
    h.run("undo")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.controller.parked.contains(b))
    #expect(h.system.focused == a)
  }

  // MARK: Changes that are not commands

  @Test func aDropIsAStep() {
    let (h, a, b, _) = makeHarness()
    let before = Picture(h)
    let start = h.frame(a)!
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 200, y: 400), CGPoint(x: 3, y: 450)])
    #expect(h.workspace.isDocked(a))
    #expect(undoLabels(h) == ["drag \(a) to the left edge"])
    #expect(h.run("undo").message == "undid drag \(a) to the left edge")
    #expect(Picture(h) == before, "a floats where it was picked up")

    h.run("redo")
    let target = h.frame(a)!
    let grabbed = h.frame(b)!
    h.system.drag(b, through: [CGPoint(x: grabbed.midX, y: grabbed.minY + 10), CGPoint(x: target.midX, y: target.maxY - 20)])
    #expect(h.workspace.isDocked(b))
    #expect(undoLabels(h).last == "drag \(b) to the bottom of Safari (\(h.workspace.tree.leaf(containing: a)!))")
    h.run("undo")
    #expect(h.workspace.isFloating(b))
    #expect(h.frame(b) == grabbed)
    expectConsistent(h)
  }

  @Test func draggingADockedWindowOutIsAStep() {
    // [a | Desktop]: a docked window is dragged out onto a Desktop that has room.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let before = Picture(h)
    let slot = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), h.layout!.desktopFrame!.center])
    #expect(h.workspace.isFloating(a))
    #expect(h.run("undo").message == "undid drag \(a) to the Desktop")
    #expect(Picture(h) == before)
  }

  @Test func dropsThatRearrangeNothingAreNotSteps() {
    let (h, a, b, _, d) = makeArrangement()
    let steps = undoLabels(h)
    let slot = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: slot.midX + 30, y: slot.midY)])
    #expect(h.frame(a) == slot, "dropped on its own slot")
    let floating = h.frame(d)!
    h.system.drag(d, through: [CGPoint(x: floating.midX, y: floating.minY + 10), h.frame(b)!.center])
    #expect(h.frame(d) != floating && h.workspace.isFloating(d), "moved: over the middle of a docked window it goes on floating")
    #expect(undoLabels(h) == steps)
  }

  @Test func aSeamDragIsOneStepHoweverManyMovesItTakes() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let before = Picture(h)
    func seam() throws -> Seam { try #require(h.overlays.seams[h.display]?.first) }

    h.system.mouseDown = true
    for _ in 0..<5 { h.overlays.dragSeam(try seam(), by: 20) }
    h.scheduler.advance(by: 1)  // held still for a while
    for _ in 0..<3 { h.overlays.dragSeam(try seam(), by: -10) }
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.3)
    let dragged = Picture(h)
    #expect(abs(h.frame(a)!.width - (before.frames[a]!.width + 70)) <= 1)
    #expect(undoLabels(h).count == 2)

    // A second drag of the same seam is a second step.
    h.system.mouseDown = true
    h.overlays.dragSeam(try seam(), by: 50)
    h.overlays.dragSeam(try seam(), by: 50)
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.3)
    #expect(undoLabels(h).count == 3)

    #expect(h.run("undo").message == "undid drag the gap between Safari (\(h.workspace.tree.leaf(containing: a)!)) and the Desktop")
    #expect(Picture(h) == dragged)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == before)
    #expect(h.run("redo").ok)
    #expect(Picture(h) == dragged)
  }

  @Test func draggingAnotherSeamOrDoingSomethingElseStartsANewStep() throws {
    let (h, a, b, c) = makeHarness()
    let e = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 400, height: 300))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(e.rawValue) right")  // [a | b | e]: two gaps
    let steps = undoLabels(h).count
    let seams = try #require(h.overlays.seams[h.display])
    #expect(seams.count == 2)
    h.system.mouseDown = true
    h.overlays.dragSeam(seams[0], by: 20)
    h.overlays.dragSeam(seams[1], by: 20)
    #expect(undoLabels(h).count == steps + 2)
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display])[1], by: 20)
    #expect(undoLabels(h).count == steps + 2)
    // A shortcut pressed in the middle of the drag.
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let same = try #require(h.overlays.seams[h.display]?.first { $0.leading == seams[1].leading && $0.trailing == seams[1].trailing })
    h.overlays.dragSeam(same, by: 20)
    #expect(undoLabels(h).count == steps + 4)
  }

  @Test func undoInTheMiddleOfASeamDragEndsTheStep() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let before = Picture(h)
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == before)
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 25)
    #expect(undoLabels(h).count == 2)
    #expect(redoLabels(h).isEmpty)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == before)
  }

  @Test func seamMovesWithoutTheMouseAreSeparateSteps() throws {
    // arbor-sim's `seam` and tests move seams without pressing the button.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    #expect(undoLabels(h).count == 3)
  }

  @Test func anEdgeResizeIsOneStep() {
    let (h, a, _, _, _) = makeArrangement()
    let before = Picture(h)
    let steps = undoLabels(h).count
    var frame = h.frame(a)!
    for _ in 0..<4 {
      frame.size.width += 25
      h.system.userResize(a, to: frame, release: false)
    }
    #expect(undoLabels(h).count == steps, "nothing is recorded until the button is up")
    h.system.releaseMouse()
    #expect(abs(h.frame(a)!.width - (before.frames[a]!.width + 100)) <= 1)
    #expect(undoLabels(h).count == steps + 1)
    #expect(h.run("undo").message == "undid resize \(a) by its edges")
    #expect(Picture(h) == before)
  }

  @Test func anEdgeResizeThatIsPutBackIsNotAStep() {
    let (h, a, _, _, _) = makeArrangement()
    let steps = undoLabels(h)
    var frame = h.frame(a)!
    frame.origin.x -= 8
    frame.size.width += 8
    h.system.userResize(a, to: frame)  // the left edge is against the screen
    #expect(undoLabels(h) == steps)
  }

  @Test func stackingIsAStepAndSwitchingTabsIsNot() {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    let single = Picture(h)
    let grabbed = h.frame(b)!
    h.system.drag(b, through: [CGPoint(x: grabbed.midX, y: grabbed.minY + 10), h.frame(a)!.center])
    let stack = h.workspace.tree.leaf(containing: a)!
    #expect(h.workspace.tree.leaf(containing: b) == stack)
    #expect(undoLabels(h).last == "drag \(b) onto Safari (\(stack)) as a tab")
    let steps = undoLabels(h)

    h.system.userFocus(a)
    // The windows of this file are one process, and within one app the view follows a moment later.
    h.scheduler.advance(by: Controller.timeForAGoing)
    #expect(h.workspace.tree.activeWindow(of: stack) == a)
    #expect(undoLabels(h) == steps, "switching tabs rearranges nothing")

    // A later change is undone without switching the tab back.
    h.run("resize \(a.rawValue) right 80")
    h.run("undo")
    #expect(h.workspace.tree.activeWindow(of: stack) == a)
    h.system.userFocus(b)
    h.scheduler.advance(by: Controller.timeForAGoing)
    h.run("redo")
    #expect(h.workspace.tree.activeWindow(of: stack) == b)
    h.run("undo")

    #expect(h.run("undo").message == "undid drag \(b) onto Safari (\(stack)) as a tab")
    #expect(Picture(h) == single)
    expectConsistent(h)
  }

  @Test(arguments: [false, true]) func aWindowDockedByARuleCanBeUndocked(makingWay: Bool) {
    var settings = makingWay ? Settings.makingWay : Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    let spot = CGRect(x: 600, y: 300, width: 500, height: 300)
    let fresh = h.system.open(app: "Terminal", frame: spot)
    #expect(h.workspace.isDocked(fresh))
    #expect(h.run("undo").message == "undid dock \(fresh) as it opened")
    #expect(h.workspace.isFloating(fresh))
    #expect(h.workspace.floating[fresh] == spot, "where its app opened it")
    if makingWay { #expect(h.layout!.desktopFrame!.contains(h.frame(fresh)!)) } else { #expect(h.frame(fresh) == spot) }
    #expect(h.run("redo").ok)
    #expect(h.workspace.isDocked(fresh))
    expectConsistent(h)
  }

  // MARK: What happened to the windows since

  @Test func undoSaysOnceThatAClosedWindowCannotComeBack() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.close(b)
    let before = Picture(h)
    // Not silently on to an older change, as if that had been the last thing that happened.
    let first = h.run("undo")
    #expect(!first.ok)
    #expect(first.message == "cannot undo the closing of a window of Notes; undo again to take back dock \(a) left")
    #expect(Picture(h) == before)
    // Taking back "dock b" would change nothing any more, so it is passed over.
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.workspace.isFloating(a))
    #expect(!h.run("undo").ok)
    #expect(redoLabels(h) == ["dock \(a) left"], "the steps passed over are gone for good")
    expectConsistent(h)
  }

  @Test func aFloatingWindowClosingIsNoObstacle() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.close(c)
    #expect(h.run("undo").message == "undid dock \(a) left")
  }

  @Test func anAppThatQuitsIsOneObstacle() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.system.close(b)
    h.system.close(c)
    #expect(h.run("undo").message == "cannot undo the closing of a window of Mail; undo again to take back dock \(a) left")
    #expect(h.run("undo").message == "undid dock \(a) left")
  }

  @Test func aClosedWindowDoesNotStandInTheWayOfRedo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    h.system.close(a)
    #expect(h.run("redo").message == "redid dock \(b) right")
    #expect(h.workspace.tree.allWindows == [b])
    expectConsistent(h)
  }

  @Test func whatUndoWouldDoLeavesOutWhatItWouldPassOver() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.close(b)
    #expect(h.controller.nextStepLabel(.undo) == "dock \(a) left")
    #expect(try #require(h.run("state").state?.displays.first).undo == "dock \(a) left")
    h.system.close(a)
    #expect(h.controller.nextStepLabel(.undo) == nil, "the menu item is greyed out")
  }

  @Test func whenEveryStepIsAboutClosedWindowsThereIsNothingToUndo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.close(a)
    h.system.close(b)
    #expect(h.run("undo").message == "cannot undo the closing of a window of Notes")
    let result = h.run("undo")
    #expect(!result.ok)
    #expect(result.message == "nothing to undo")
    expectConsistent(h)
  }

  @Test func windowsThatClosedSinceLeaveTheRestoredTree() {
    let (h, a, b, c, _) = makeArrangement()
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    h.run("save-view 1")
    h.run("float-all")
    h.system.close(c)
    #expect(h.run("undo").message == "undid float-all")
    let tree = h.workspace.tree
    #expect(tree.allWindows == [a, b])
    // The column [a / c] collapsed into a; the camera and the saved view follow, as when a window closes.
    #expect(h.workspace.camera == tree.leaf(containing: a))
    #expect(h.workspace.savedView(slot: 1) == tree.leaf(containing: a))
    expectConsistent(h)
  }

  @Test func windowsThatOpenedSinceStayFloating() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let spot = CGRect(x: 498, y: 47, width: 200, height: 150)
    let fresh = h.system.open(app: "Terminal", frame: spot)
    h.run("undo")
    h.run("undo")
    #expect(h.workspace.isFloating(fresh))
    #expect(h.frame(fresh) == spot)
    #expect(h.workspace.tree.allWindows.isEmpty)
    expectConsistent(h)
  }

  @Test func aWindowThatOpenedAndWasDockedSinceFloatsWhenAnOlderStepIsRestored() {
    // The step that docked it was recorded, then dropped by the limit or skipped; here it is simply older.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let fresh = h.system.open(app: "Terminal", frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    h.run("dock \(fresh.rawValue) right")
    h.run("undo")
    h.run("undo")
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(h.workspace.isFloating(fresh) && h.workspace.isFloating(a))
    h.run("redo")
    h.run("redo")
    #expect(h.workspace.isDocked(fresh) && h.workspace.isDocked(a))
    expectConsistent(h)
  }

  @Test func minimizedWindowsKeepTheirSlotAndTakeNoSpace() {
    let (h, a, b, c, _) = makeArrangement()
    let before = Picture(h)
    h.run("float-all")
    h.system.setMinimized(c, true)
    h.run("undo")
    #expect(h.workspace.tree == before.workspaces[h.display]!.tree, "c has its slot")
    #expect(h.frame(a)!.height == h.visibleFrame.insetBy(dx: 12, dy: 12).height, "a has the column to itself")
    h.system.setMinimized(c, false)
    #expect(h.frame(a) == before.frames[a])
    #expect(h.frame(c) == before.frames[c])
    _ = b
    expectConsistent(h)
  }

  @Test func windowsOnAnotherSpaceKeepTheirSlotAndAreNotMoved() {
    let (h, a, _, c, _) = makeArrangement()
    let before = Picture(h)
    h.run("float-all")
    h.system.setOnActiveSpace(c, false)
    h.scheduler.runPending()
    h.system.clearFrameLog()
    h.run("undo")
    #expect(h.workspace.tree == before.workspaces[h.display]!.tree)
    #expect(!h.system.frameLog.contains { $0.window == c }, "a window on another Space is left alone")
    #expect(h.frame(a)!.height == h.visibleFrame.insetBy(dx: 12, dy: 12).height)
    h.system.setOnActiveSpace(c, true)
    h.scheduler.runPending()
    #expect(h.frame(c) == before.frames[c])
    expectConsistent(h)
  }

  @Test func windowsOfAHiddenAppKeepTheirSlots() {
    let (h, a, _, c, _) = makeArrangement()
    let before = Picture(h)
    h.run("float-all")
    h.system.setHidden(pid: 1000, true)  // every window in these tests belongs to one process
    h.run("undo")
    #expect(h.workspace.tree == before.workspaces[h.display]!.tree)
    h.system.setHidden(pid: 1000, false)
    #expect(h.frame(a) == before.frames[a])
    #expect(h.frame(c) == before.frames[c])
    expectConsistent(h)
  }

  @Test func theRoomArborMadeForAWindowIsUndoneWithTheDockThatNeededIt() {
    let (h, a, b, _) = makeHarness()
    let big = h.system.open(
      app: "Xcode", frame: CGRect(x: 400, y: 200, width: 900, height: 600), minimumSize: CGSize(width: 900, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = Picture(h)
    // Its slot is too small for it, so Arbor moves the gaps around it (F61), in the same breath.
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let docked = Picture(h)
    #expect(h.layout?.windowFrames[big] != nil, "room was made")
    #expect(undoLabels(h).count == 3)
    h.run("undo")
    #expect(Picture(h) == before, "the gaps are back as well")
    h.run("redo")
    #expect(Picture(h) == docked)
    expectConsistent(h)
  }

  @Test func roomThatArborMakesWhenTheViewMovesIsNotAStep() {
    let (h, a, b, _) = makeHarness()
    let big = h.system.open(
      app: "Xcode", frame: CGRect(x: 400, y: 200, width: 900, height: 500), minimumSize: CGSize(width: 900, height: 300))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    // With b framed there is width enough for both.
    h.run("dock \(big.rawValue) bottom")
    #expect(h.layout?.windowFrames[big] != nil)
    let labels = undoLabels(h)
    let gaps = h.workspace.tree
    // From further out their column is too narrow for it, and Arbor widens the column.
    h.run("show-all")
    #expect(!h.workspace.tree.hasSameArrangement(as: gaps), "room was made")
    #expect(h.layout?.windowFrames[big] != nil)
    #expect(undoLabels(h) == labels, "nobody rearranged anything: the view moved")
    #expect(h.run("undo").message == "undid dock \(big) bottom")
    expectConsistent(h)
  }

  @Test(.withTiles) func aWindowThatBecameATileGoesBackAndForth() {
    var settings = Settings()
    settings.makeRoom = false
    let (h, a, b, _) = makeHarness(settings: settings)
    let spot = CGRect(x: 400, y: 200, width: 900, height: 600)
    let big = h.system.open(app: "Xcode", frame: spot, minimumSize: CGSize(width: 900, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = Picture(h)
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let tiled = Picture(h)
    #expect(h.overlays.tiles[h.display]?.first?.items.first?.window == big)
    #expect(h.controller.parked.contains(big))

    h.run("undo")
    #expect(Picture(h) == before)
    #expect(h.overlays.tiles[h.display]?.isEmpty == true)
    #expect(h.system.isVisible(big))
    h.run("redo")
    #expect(Picture(h) == tiled)
    #expect(h.overlays.tiles[h.display]?.first?.items.first?.window == big)
    expectConsistent(h)
  }

  @Test func windowsOfAnAppExcludedSinceDoNotComeBack() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("float-all")
    let steps = undoLabels(h)
    h.run("exclude com.example.notes")
    #expect(undoLabels(h) == steps, "excluding an app is not a step: undo could not take it back")
    let left = h.frame(b)
    h.run("undo")
    #expect(h.workspace.tree.allWindows == [a])
    #expect(!h.workspace.contains(b))
    #expect(h.frame(b) == left, "Arbor does not touch it")
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func excludingADockedAppCannotBeUndoneAndUndoSaysSo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("exclude com.example.notes")
    #expect(!h.workspace.contains(b))
    h.run("include com.example.notes")
    #expect(h.workspace.isFloating(b))
    let first = h.run("undo")
    #expect(!first.ok)
    #expect(
      first.message
        == "cannot undo exclude com.example.notes (`include com.example.notes`, or Arrangement → Arrange Again in the menu, takes that back); "
        + "undo again to take back dock \(a) left")
    #expect(h.workspace.isDocked(a) && h.workspace.isFloating(b))
    #expect(h.run("undo").message == "undid dock \(a) left")
  }

  // MARK: Floating windows

  @Test func floatingWindowsGoBackToTheirFrames() {
    let (h, a, b, c) = makeHarness()
    let before = Picture(h)
    h.run("arrange")
    for window in [a, b, c] { #expect(h.frame(window) != before.frames[window]) }
    h.run("undo")
    #expect(Picture(h) == before)
  }

  /// Floating windows make way here, as until Q20 (`floatingWindowsMakeWay`).
  @Test func floatingWindowsThatWerePushedAsideGoBack() {
    // With a column for the Desktop: it has room beside two docked windows too, less of it, and what floats is kept on it.
    let (h, a, b, c) = makeHarness(settings: .makingWay.withDesktopColumn)
    let spot = CGRect(x: 420, y: 300, width: 500, height: 300)
    h.system.userMove(c, to: spot)
    h.run("dock \(a.rawValue) left")
    let pushed = h.frame(c)
    #expect(pushed != spot, "docking pushed it onto the Desktop")
    // Pushed further, and back only as far as it was.
    h.run("dock \(b.rawValue) left")
    #expect(h.frame(c) != pushed)
    h.run("undo")
    #expect(h.frame(c) == pushed)
    h.run("undo")
    #expect(h.frame(c) == spot)
    h.run("redo")
    #expect(h.frame(c) == pushed)
  }

  @Test func aFloatingWindowMovedSinceStaysWhereItWasPut() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let desktop = h.layout!.desktopFrame!
    let placed = CGRect(x: desktop.minX + 30, y: desktop.minY + 30, width: 320, height: 240)
    h.system.userMove(c, to: placed)
    h.run("undo")
    #expect(h.frame(c) == placed)
    #expect(h.workspace.floating[c] == placed)
    h.run("redo")
    #expect(h.frame(c) == placed)
  }

  @Test(arguments: [false, true]) func floatingAWindowWhileTheDesktopIsOutOfViewGoesBackAndForthExactly(makingWay: Bool) {
    let (h, a, _, c, _) = makeArrangement(settings: makingWay ? .makingWay : Settings())
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    let before = Picture(h)
    h.run("float \(c.rawValue)")
    let after = Picture(h)
    h.run("undo")
    #expect(Picture(h) == before)
    h.run("redo")
    #expect(Picture(h) == after)
    h.run("show-all")
    #expect(h.frame(c) == after.frames[c], "over the two halves now, where it came to float")
    expectConsistent(h)
  }

  @Test func aNewWindowThatWasInViewComesBackIntoView() {
    // New windows stay in view over a framed window until the camera moves. Docking one widens the
    // camera; undoing that must not make the window vanish with the Desktop.
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let spot = CGRect(x: 600, y: 300, width: 500, height: 300)
    let fresh = h.system.open(app: "Terminal", frame: spot)
    #expect(h.system.isVisible(fresh))
    let before = Picture(h)
    #expect(h.run("dock \(fresh.rawValue) right").ok)
    #expect(h.run("undo").ok)
    #expect(Picture(h) == before)
    #expect(h.frame(fresh) == spot)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  @Test func aNewWindowInViewIsLeftAloneByAnUndoThatDoesNotMoveTheCamera() {
    let (h, a, _, _, _) = makeArrangement()
    h.run("resize \(a.rawValue) bottom 60")
    let column = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(column.rawValue)")
    let spot = CGRect(x: 600, y: 300, width: 500, height: 300)
    let fresh = h.system.open(app: "Preview", frame: spot)
    #expect(h.run("undo").message == "undid resize \(a) bottom")
    #expect(h.workspace.camera == column)
    #expect(h.frame(fresh) == spot)
    #expect(!h.controller.parked.contains(fresh))
  }

  @Test func floatingWindowsDoNotGoBackToAPlaceThatIsNoLongerOnTheDisplay() {
    let (h, a, _, c) = makeHarness()
    h.system.userMove(c, to: CGRect(x: 1030, y: 500, width: 400, height: 300))
    h.run("dock \(a.rawValue) left")
    var smaller = main
    smaller.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
    smaller.visibleFrame = CGRect(x: 0, y: 25, width: 1024, height: 743)
    h.system.setDisplays([smaller])
    // Until 2026-10-14 the step could be undone, and a place beyond the smaller display altogether was fitted. But a place
    // of which a strip still showed stayed, out of reach (UndoAcrossDisplaysTests). The product owner's decision: another
    // frame of a display that stays ends the history: losing fifty steps is nothing beside losing a window.
    #expect(!h.run("undo").ok)
    #expect(smaller.visibleFrame.contains(h.frame(c)!))
    #expect(smaller.visibleFrame.contains(h.frame(a)!))
    expectConsistent(h)
  }

  // MARK: What other features keep in a workspace

  @Test func aWindowThatOpenedOverAFramedWindowSinceStaysItsGuest() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("resize \(a.rawValue) right 60")
    h.run("zoom \(a.rawValue)")
    let host = h.workspace.camera
    let spot = CGRect(x: 600, y: 300, width: 500, height: 300)
    let guest = h.system.open(app: "Terminal", frame: spot)
    #expect(h.workspace.guests == [guest: host])

    // Nothing of the resize shows while a is framed, so the view steps out, and the Desktop comes into view.
    #expect(h.run("undo").message == "undid resize \(a) right")
    #expect(h.workspace.guests == [guest: host], "an undo of something else does not end the visit")
    #expect(h.system.isVisible(guest))
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(guest))
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(guest) == spot, "it comes back with its host, where it was")
    expectConsistent(h)
  }

  @Test func aGuestWhoseHostTheUndoTakesAwayIsAnOrdinaryFloatingWindow() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    let guest = h.system.open(app: "Terminal", frame: CGRect(x: 600, y: 300, width: 500, height: 300))
    #expect(h.workspace.guests?[guest] != nil)
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.workspace.guests == nil)
    #expect(h.workspace.isFloating(guest) && h.system.isVisible(guest))
    #expect(h.run("redo").ok)
    expectConsistent(h)
  }

  @Test func aGuestInViewIsNotTouchedWhenTheViewStepsOutAndItsHostStaysInView() {
    let (h, a, _, _, _) = makeArrangement()
    h.run("resize \(a.rawValue) bottom 60")
    h.run("zoom \(a.rawValue)")
    let spot = CGRect(x: 100, y: 200, width: 400, height: 300)
    let guest = h.system.open(app: "Preview", frame: spot)
    #expect(h.workspace.guests?[guest] == h.workspace.camera)
    h.system.clearFrameLog()
    // The gap under a does not show while a is framed: the view steps out to the column, without the Desktop.
    #expect(h.run("undo").message == "undid resize \(a) bottom")
    #expect(h.workspace.camera == h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!))
    #expect(h.layout?.desktopFrame == nil)
    #expect(h.frame(guest) == spot)
    #expect(!h.system.frameLog.contains { $0.window == guest }, "not to a corner and back either")
  }

  @Test func pinningAFloatingWindowIsNotAStepAndSurvivesTheUndoOfSomethingOlder() {
    let (h, a, b, c) = makeHarness()
    // In the half that is left over after the first dock: neither dock moves it, so taking one back has nothing to put back.
    h.system.userMove(c, to: CGRect(x: 780, y: 300, width: 600, height: 400))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("pin \(c.rawValue)").ok)
    #expect(undoLabels(h).last == "dock \(b) right")
    let place = h.frame(c)
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.isPinned(c), "pinned since")
    #expect(h.frame(c) == place)
    #expect(h.run("unpin \(c.rawValue)").ok)
    #expect(h.run("redo").ok)
    #expect(!h.workspace.isPinned(c), "unpinned since")
    expectConsistent(h)
  }

  @Test func aPinnedWindowKeepsItsPlaceWhenAnUndoMovesTheView() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("pin \(c.rawValue)")
    let place = h.frame(c)
    // Docking b widens the view; undoing that frames a again, with the Desktop out of view.
    h.run("dock \(b.rawValue) right")
    h.system.clearFrameLog()
    #expect(h.run("undo").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.frame(c) == place && !h.controller.parked.contains(c))
    #expect(!h.system.frameLog.contains { $0.window == c })
    expectConsistent(h)
  }

  @Test func aWindowPinnedSinceIsNotTouchedWhenAnUndoMovesTheView() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked.contains(c), "out of view with the Desktop")
    h.run("dock \(b.rawValue) right")
    // When b was docked, c was out of view: the step knows no place for it.
    h.run("pin \(c.rawValue)")
    let place = h.frame(c)
    h.system.clearFrameLog()
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.layout?.desktopFrame == nil)
    #expect(h.frame(c) == place && !h.controller.parked.contains(c))
    #expect(!h.system.frameLog.contains { $0.window == c }, "not to a corner and back either")
  }

  @Test func summoningIsNotAStepAndAnUndoLeavesTheVisitorAlone() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("summon Mail").ok)
    #expect(h.workspace.isSummoned(c))
    #expect(undoLabels(h).last == "dock \(b) right")
    let place = h.frame(c)
    h.system.clearFrameLog()
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.isSummoned(c), "summoned since")
    #expect(h.frame(c) == place)
    #expect(!h.system.frameLog.contains { $0.window == c })
    expectConsistent(h)
  }

  @Test func aWindowSentAwaySinceStaysOutOfViewThoughTheDesktopIsInView() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("summon Mail")
    h.run("summon Mail")
    #expect(h.workspace.isStashed(c) && h.controller.parked.contains(c))
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.layout?.desktopFrame != nil)
    #expect(h.workspace.isStashed(c) && h.controller.parked.contains(c))
    #expect(h.run("redo").ok)
    #expect(h.workspace.isStashed(c) && h.controller.parked.contains(c))
    expectConsistent(h)
  }

  @Test func summoningFromAnotherDisplayIsNotAStepEither() {
    let (h, a, _, c) = makeTwoDisplays()
    h.system.cursor = onMain
    h.run("dock \(a.rawValue) left")
    #expect(h.controller.workspaceID(containing: c) == side.id)
    let app = h.controller.windows[c]!.appName
    #expect(h.run("summon \(app)").ok)
    #expect(h.controller.workspaceID(containing: c) == main.id, "brought over")
    #expect(undoLabels(h, on: main.id) == ["dock \(a) left"] && undoLabels(h, on: side.id).isEmpty)
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.controller.workspaceID(containing: c) == main.id, "and it stays where it was summoned to")
    expectConsistent(h)
  }

  @Test func pinningADockedWindowIsAStep() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = Picture(h)
    #expect(h.run("pin \(b.rawValue)").ok)
    let pinned = Picture(h)
    #expect(h.workspace.isPinned(b))
    #expect(h.run("undo").message == "undid pin \(b)")
    #expect(Picture(h) == before)
    #expect(h.run("redo").message == "redid pin \(b)")
    #expect(Picture(h) == pinned)
  }

  @Test func undoingTheDockOfAPinnedWindowPinsItAgainWhereItWas() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    // Over the docked window, where only a pinned window stays.
    let place = CGRect(x: 200, y: 300, width: 400, height: 300)
    h.system.userMove(c, to: place)
    h.run("pin \(c.rawValue)")
    let before = Picture(h)
    #expect(h.run("dock \(c.rawValue) right").ok)
    #expect(!h.workspace.isPinned(c))
    #expect(h.run("undo").ok)
    #expect(h.workspace.isPinned(c))
    #expect(h.frame(c) == place)
    #expect(Picture(h) == before)
  }

  /// A second life after `[a | Desktop | b]`, in which b's app has not reopened its window yet, so b's slot waits
  /// (Controller+PendingSlots.swift). `reopen` opens the window the slot waits for.
  func makeLateLaunch() throws -> (Harness, a: WindowID, c: WindowID, slot: WindowID, reopen: () -> WindowID) {
    let (first, a, b, c) = makeHarness()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) right")
    first.controller.saveNow()
    let late = try #require(first.controller.windows[b])

    let h = Harness(saved: first.store.saved)
    var reopened: [WindowID] = []
    for id in [a, c] {
      let window = try #require(first.controller.windows[id])
      reopened.append(h.system.open(app: window.appName, title: window.title, frame: window.frame))
    }
    h.start()
    let slot = try #require(h.workspace.tree.allWindows.first { h.controller.windows[$0] == nil })
    return (h, reopened[0], reopened[1], slot, { h.system.open(app: late.appName, title: late.title, frame: late.frame) })
  }

  @Test func aSlotThatWaitsForItsWindowGoesOnWaitingThroughUndoAndRedo() throws {
    let (h, a, c, slot, reopen) = try makeLateLaunch()
    #expect(h.run("dock \(c.rawValue) beside \(a.rawValue) bottom").ok)
    #expect(h.run("undo").ok)
    #expect(h.workspace.isDocked(slot) && h.workspace.isFloating(c))
    #expect(h.run("redo").ok)
    #expect(h.workspace.isDocked(slot) && h.workspace.isDocked(c))
    #expect(h.run("undo").ok)
    let place = h.workspace.tree.leaf(containing: slot)
    let late = reopen()
    #expect(h.workspace.tree.leaf(containing: late) == place, "the window still finds its slot")
    expectConsistent(h)
  }

  @Test func aWindowThatTookItsWaitingSlotSinceKeepsItWhenOlderChangesAreUndoneAndRedone() throws {
    let (h, a, c, slot, reopen) = try makeLateLaunch()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let place = h.workspace.tree.leaf(containing: slot)
    let late = reopen()
    #expect(h.workspace.tree.leaf(containing: late) == place)
    #expect(h.run("undo").message == "undid dock \(c) beside \(a) bottom")
    #expect(h.workspace.tree.leaf(containing: late) == place, "the step was saved when the slot had a stand-in's number")
    #expect(h.workspace.isFloating(c))
    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.allWindows.sorted() == [a, c, late].sorted())
    expectConsistent(h)
  }

  @Test func theStepsFollowASlotThatIsHandedOnToTheWindowItWaitedFor() throws {
    let (h, a, c, slot, reopen) = try makeLateLaunch()
    let place = h.workspace.tree.leaf(containing: slot)
    // A welcome window of the app comes first and holds the slot, being the app's only window.
    let welcome = h.system.open(app: "Notes", title: "Welcome", frame: CGRect(x: 300, y: 200, width: 500, height: 300))
    #expect(h.workspace.tree.leaf(containing: welcome) == place)
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    // Then the window with the title the slot was kept for.
    let late = reopen()
    #expect(h.workspace.tree.leaf(containing: late) == place)
    #expect(h.workspace.isFloating(welcome))
    #expect(h.run("undo").message == "undid dock \(c) beside \(a) bottom")
    #expect(h.workspace.tree.leaf(containing: late) == place, "the step was saved when the welcome window held the slot")
    #expect(h.workspace.isFloating(welcome) && h.workspace.isFloating(c))
    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.allWindows.sorted() == [a, c, late].sorted())
    expectConsistent(h)
  }

  @Test func noWaitingSlotEverFloats() throws {
    let (h, a, _, slot, _) = try makeLateLaunch()
    let place = h.workspace.tree.leaf(containing: slot)
    // A welcome window holds the slot for now. It is floated, and docked again by an undo.
    let welcome = h.system.open(app: "Notes", title: "Welcome", frame: CGRect(x: 300, y: 200, width: 500, height: 300))
    h.run("float \(welcome.rawValue)")
    h.run("undo")
    #expect(h.workspace.tree.leaf(containing: welcome) == place)
    // It closes, as welcome windows do, and the slot waits again, under a stand-in's number. So the step that `redo` would
    // put back now speaks of a stand-in that floats, and there is no window that could.
    h.system.close(welcome)
    #expect(h.workspace.tree.allWindows.count == 2, "a, and the slot that waits")
    #expect(undoLabels(h).isEmpty, "the slot is where it was: nothing to undo, and nothing to say")
    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.allWindows == [a])
    #expect(h.workspace.floating.keys.allSatisfy { h.controller.windows[$0] != nil })
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"), "nothing waits any more")
    expectConsistent(h)
  }

  @Test func aSlotThatWaitsAgainGoesOnWaitingWhenSomethingElseIsUndone() throws {
    let (h, a, c, slot, reopen) = try makeLateLaunch()
    let place = h.workspace.tree.leaf(containing: slot)
    let welcome = h.system.open(app: "Notes", title: "Welcome", frame: CGRect(x: 300, y: 200, width: 500, height: 300))
    #expect(h.workspace.tree.leaf(containing: welcome) == place)
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.system.close(welcome)
    // The step was saved when the welcome window held the slot. It now means the stand-in that keeps it.
    #expect(h.run("undo").message == "undid dock \(c) beside \(a) bottom")
    #expect(h.workspace.tree.allWindows.count == 2, "a, and the slot that waits")
    let late = reopen()
    #expect(h.workspace.tree.leaf(containing: late) == place)
    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.allWindows.sorted() == [a, c, late].sorted())
    expectConsistent(h)
  }

  @Test func aWindowWhoseAppRestartedDuringAPauseKeepsItsSlotWhenSomethingElseIsUndone() throws {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let place = h.workspace.tree.leaf(containing: b)
    let title = try #require(h.controller.windows[b]?.title)
    h.run("pause")
    h.system.close(b)
    let again = h.system.open(app: "Notes", title: title, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.run("resume")
    #expect(h.workspace.tree.leaf(containing: again) == place, "matched by app and title, as at any start")
    #expect(h.run("undo").message == "undid dock \(c) beside \(a) bottom")
    #expect(h.workspace.tree.leaf(containing: again) == place)
    #expect(h.run("undo").ok, "and the step that docked it under its old number undocks it")
    #expect(h.workspace.isFloating(again))
    expectConsistent(h)
  }

  @Test func aNativeTabThatCameToTheFrontSinceKeepsTheSlot() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let place = h.workspace.tree.leaf(containing: a)
    // To macOS each tab of a window is a window of its own, and the one in front is the only one listed.
    let tab = try #require(h.system.openTab(in: a))
    #expect(h.workspace.tree.leaf(containing: tab) == place)
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.tree.leaf(containing: tab) == place)
    #expect(h.workspace.isFloating(b))
    expectConsistent(h)

    h.system.selectTab(a, insteadOf: tab)
    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.leaf(containing: a) == place)
    #expect(h.run("undo").ok)
    #expect(h.run("undo").ok, "and the step that docked the window undocks whichever tab is in front")
    #expect(h.workspace.isFloating(a) && h.workspace.tree.allWindows.isEmpty)
    expectConsistent(h)
  }

  @Test func aRuleThatDocksANewWindowLeavesRedoAlone() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let (h, a, b, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("undo")
    // Nobody did anything: an app opened a window.
    let fresh = h.system.open(app: "Terminal", frame: CGRect(x: 800, y: 300, width: 500, height: 300))
    #expect(h.workspace.isDocked(fresh))
    #expect(redoLabels(h) == ["dock \(b) beside \(a) bottom"])
    #expect(h.run("redo").ok)
    #expect(h.workspace.isDocked(b))
    #expect(h.system.isVisible(fresh))
    expectConsistent(h)
    #expect(h.run("undo").ok)
    #expect(h.workspace.isDocked(fresh) && h.workspace.isFloating(b))
    #expect(h.run("undo").message == "undid dock \(fresh) as it opened")
    expectConsistent(h)
  }

  // MARK: Several displays

  func makeTwoDisplays() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: [main, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let s = h.system.open(app: "Mail", frame: CGRect(x: 1700, y: 150, width: 500, height: 400))
    h.start()
    return (h, a, b, s)
  }

  @Test func eachDisplayHasItsOwnHistoryAndThePointerPicksIt() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(s.rawValue) right")
    #expect(undoLabels(h, on: main.id) == ["dock \(a) left"])
    #expect(undoLabels(h, on: side.id) == ["dock \(s) right"])

    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.controller.workspaces[side.id]!.isDocked(s), "the other display is untouched")
    #expect(!h.run("undo").ok)

    h.system.cursor = onSide
    #expect(!h.run("redo").ok)
    #expect(h.run("undo").message == "undid dock \(s) right")
    h.system.cursor = onMain
    #expect(h.run("redo").message == "redid dock \(a) left")
    expectConsistent(h)
  }

  @Test func aShortcutUndoesWhereTheKeyboardIsAndTheMenuWhereThePointerIs() {
    let (h, a, _, c) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) right")
    #expect(undoLabels(h, on: main.id) == ["dock \(a) left"] && undoLabels(h, on: side.id) == ["dock \(c) right"])
    // The pointer is left on the main display; the user switches to c on the other one with ⌘Tab, and types.
    h.system.cursor = onMain
    h.scheduler.advance(by: 5)
    h.system.userFocus(c)
    h.scheduler.advance(by: 1)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.controller.nextStepLabel(.undo, from: .shortcut) == "dock \(c) right")
    #expect(h.controller.nextStepLabel(.undo, from: .menu) == "dock \(a) left")
    #expect(h.press("undo").message == "undid dock \(c) right")
    #expect(h.press("undo").message == "nothing to undo on the focused window's display")
    #expect(h.run("undo", from: .menu).message == "undid dock \(a) left")
    expectConsistent(h)
  }

  @Test(arguments: [onMain, onSide])
  func aWindowSentToAnotherDisplayComesBackInOneStep(pointer: CGPoint) {
    let (h, a, b, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(s.rawValue) left")
    let before = Picture(h)
    #expect(h.run("dock \(b.rawValue) beside \(s.rawValue) bottom").ok)
    let after = Picture(h)
    #expect(h.controller.workspaces[side.id]!.isDocked(b))

    // From either display: the change was made to both.
    h.system.cursor = pointer
    #expect(h.run("undo").message == "undid dock \(b) beside \(s) bottom")
    #expect(Picture(h) == before)
    expectConsistent(h)
    #expect(h.run("redo").ok)
    #expect(Picture(h) == after)
    expectConsistent(h)
    #expect(redoLabels(h, on: main.id).isEmpty && redoLabels(h, on: side.id).isEmpty)
  }

  @Test func aWindowDraggedToAnotherDisplayComesBackInOneStep() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(s.rawValue) left")
    let before = Picture(h)
    let slot = h.frame(a)!
    let target = h.frame(s)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: target.midX, y: target.maxY - 20)])
    #expect(h.controller.workspaces[side.id]!.isDocked(a))
    #expect(h.run("undo").ok, "the pointer is where the window was dropped")
    #expect(Picture(h) == before)
    expectConsistent(h)
  }

  @Test(arguments: [onMain, onSide])
  func floatAllOnEveryDisplayIsUndoneOnEveryDisplayAtOnce(pointer: CGPoint) {
    let (h, a, b, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(s.rawValue) left")
    h.system.cursor = onSide
    h.run("zoom \(s.rawValue)")
    let before = Picture(h)
    #expect(h.run("float-all").ok)
    let after = Picture(h)
    #expect(h.controller.workspaces.values.allSatisfy { $0.tree.allWindows.isEmpty })
    #expect(undoLabels(h, on: main.id).last == "float-all" && undoLabels(h, on: side.id).last == "float-all")

    // One slip, one undo, wherever the pointer is.
    h.system.cursor = pointer
    #expect(h.run("undo").message == "undid float-all")
    #expect(Picture(h) == before)
    #expect(undoLabels(h, on: main.id).last != "float-all" && undoLabels(h, on: side.id).last != "float-all")
    expectConsistent(h)
    #expect(h.run("redo").message == "redid float-all")
    #expect(Picture(h) == after)
    expectConsistent(h)
  }

  @Test func arrangeAllIsUndoneOnEveryDisplayAtOnce() {
    let (h, a, _, _) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    let before = Picture(h)
    #expect(h.run("arrange all").ok)
    #expect(h.controller.workspaces.values.allSatisfy { $0.floating.isEmpty })
    h.system.cursor = onSide
    #expect(h.run("undo").message == "undid arrange all")
    #expect(Picture(h) == before)
    expectConsistent(h)
  }

  @Test func floatAllHereIsAStepOnThisDisplayOnly() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(s.rawValue) left")
    h.system.cursor = onMain
    #expect(h.run("float-all here").ok)
    #expect(undoLabels(h, on: main.id).last == "float-all here")
    #expect(undoLabels(h, on: side.id) == ["dock \(s) left"])
    #expect(h.run("undo").ok)
    #expect(h.workspace.isDocked(a))
  }

  @Test func aDisplayThatMovedOnAfterFloatAllKeepsItsHalf() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(s.rawValue) left")
    h.run("float-all")
    h.run("dock \(s.rawValue) right")  // the side display moves on
    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid float-all")
    #expect(h.workspace.isDocked(a))
    #expect(undoLabels(h, on: side.id) == ["dock \(s) left", "float-all", "dock \(s) right"])
    h.system.cursor = onSide
    #expect(h.run("undo").message == "undid dock \(s) right")
    #expect(h.run("undo").message == "undid float-all")
    #expect(h.controller.workspaces[side.id]!.isDocked(s))
    #expect(h.workspace.isDocked(a), "the main display is not touched again")
    expectConsistent(h)
  }

  @Test func whenTheOtherDisplayHasChangedSinceOnlyThisOneGoesBack() {
    let (h, a, b, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(s.rawValue) left")
    h.run("dock \(b.rawValue) beside \(s.rawValue) bottom")
    h.run("resize \(a.rawValue) right 100")  // the main display moves on

    h.system.cursor = onSide
    #expect(h.run("undo").message == "undid dock \(b) beside \(s) bottom")
    let sideWorkspace = h.controller.workspaces[side.id]!
    #expect(sideWorkspace.tree.allWindows == [s])
    #expect(sideWorkspace.isFloating(b), "b has nowhere to go back to yet, so it floats here")
    #expect(!h.workspace.contains(b))
    expectConsistent(h)

    // The main display gets to its half in its own time, and takes b back.
    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid resize \(a) right")
    #expect(h.run("undo").message == "undid dock \(b) beside \(s) bottom")
    #expect(h.workspace.isDocked(b))
    #expect(!h.controller.workspaces[side.id]!.contains(b))
    expectConsistent(h)

    // And forward again: b leaves the main display for where it was, floating on the side display.
    #expect(h.run("redo").ok)
    #expect(!h.workspace.contains(b))
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    expectConsistent(h)
  }

  @Test func aWindowDockedOnAnotherDisplaySinceStaysThere() {
    let (h, a, b, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("float-all")
    // b wanders to the side display by hand and is docked there.
    h.system.userMove(b, to: CGRect(x: 1600, y: 100, width: 500, height: 400))
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    h.run("dock \(b.rawValue) left")
    let slot = h.frame(b)

    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid float-all")
    #expect(h.workspace.tree.allWindows == [a])
    #expect(!h.workspace.contains(b))
    #expect(h.controller.workspaces[side.id]!.isDocked(b))
    #expect(h.frame(b) == slot)
    _ = s
    expectConsistent(h)
  }

  @Test func aWindowFloatingOnAnotherDisplayNowComesBackToItsSlot() {
    let (h, a, b, _) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = Picture(h)
    h.run("float \(b.rawValue)")
    let wandered = CGRect(x: 1600, y: 100, width: 500, height: 400)
    h.system.userMove(b, to: wandered)
    #expect(h.controller.workspaces[side.id]!.isFloating(b))

    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid float \(b)")
    #expect(Picture(h) == before)
    expectConsistent(h)
    // Redo puts it back where it had wandered to.
    #expect(h.run("redo").ok)
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    #expect(h.frame(b) == wandered)
    expectConsistent(h)
  }

  @Test func aFloatingWindowMovedToAnotherDisplaySinceStaysThere() {
    let (h, a, b, _) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    let wandered = CGRect(x: 1600, y: 100, width: 500, height: 400)
    h.system.userMove(b, to: wandered)
    #expect(h.controller.workspaces[side.id]!.isFloating(b))

    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.workspace.isFloating(a))
    #expect(h.controller.workspaces[side.id]!.isFloating(b), "it floated then and floats now; only the place differs")
    #expect(h.frame(b) == wandered)
    expectConsistent(h)
  }

  @Test func floatingWindowsThatWentHomeWithAReconnectedDisplayStayThere() {
    let (h, a, _, s) = makeTwoDisplays()
    let home = h.frame(s)!
    h.system.setDisplays([main])
    #expect(h.workspace.isFloating(s), "waiting on the main display")
    h.system.cursor = onMain
    h.run("dock \(a.rawValue) left")
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isFloating(s))
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.controller.workspaces[side.id]!.isFloating(s))
    #expect(h.frame(s) == home)
    expectConsistent(h)
  }

  @Test func aFloatingWindowDraggedToAnotherDisplayComesBackInOneStep() {
    let (h, _, b, _) = makeTwoDisplays()
    let before = Picture(h)
    let start = h.frame(b)!
    h.system.drag(b, through: [CGPoint(x: start.midX, y: start.minY + 10), CGPoint(x: 2000, y: 300)])
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    #expect(h.run("undo").message == "undid drag \(b) to the Desktop")
    #expect(Picture(h) == before)
    #expect(h.run("redo").ok)
    #expect(h.controller.workspaces[side.id]!.isFloating(b))
    expectConsistent(h)
  }

  @Test func aDisconnectedDisplayLosesItsHistory() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(s.rawValue) right")
    h.system.cursor = onSide
    h.run("resize \(s.rawValue) left 50")
    h.run("undo")
    h.system.setDisplays([main])
    #expect(undoLabels(h, on: side.id).isEmpty && redoLabels(h, on: side.id).isEmpty)
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isDocked(s), "the arrangement itself comes back")
    #expect(!h.run("undo").ok)
    #expect(!h.run("redo").ok)
    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid dock \(a) left", "the other display keeps its history")
    expectConsistent(h)
  }

  @Test func windowsEvacuatedFromADisconnectedDisplayAreNotDraggedIntoAnUndo() {
    let (h, a, _, s) = makeTwoDisplays()
    h.run("dock \(s.rawValue) right")
    h.run("dock \(a.rawValue) left")
    h.system.setDisplays([main])
    #expect(h.workspace.isFloating(s))
    h.system.cursor = onMain
    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.workspace.isFloating(s), "it arrived since, so it stays floating")
    h.system.setDisplays([main, side])
    #expect(h.controller.workspaces[side.id]!.isDocked(s))
    expectConsistent(h)
  }

  @Test func halfAStepWhoseOtherDisplayIsGoneStillWorks() {
    let (h, a, b, s) = makeTwoDisplays()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(s.rawValue) left")
    h.run("dock \(b.rawValue) beside \(s.rawValue) bottom")
    h.system.setDisplays([main])
    h.system.cursor = onMain
    #expect(h.workspace.isFloating(b))
    #expect(h.run("undo").message == "undid dock \(b) beside \(s) bottom")
    #expect(h.workspace.isDocked(b))
    expectConsistent(h)
  }

  // MARK: In the middle of something

  @Test func undoWaitsForADragToEnd() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let start = h.frame(b)!
    h.system.mouseDown = true
    h.controller.dragBegan(b, at: CGPoint(x: start.midX, y: start.minY + 10))
    let result = h.run("undo")
    #expect(!result.ok)
    #expect(result.message == "cannot undo while a window is being dragged")
    #expect(h.workspace.isDocked(a))
    h.system.mouseDown = false
    h.controller.dragEnded(b, at: CGPoint(x: start.midX, y: start.minY + 10))
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(a))
  }

  @Test func undoWaitsForAnEdgeResizeToEnd() {
    let (h, a, _, _, _) = makeArrangement()
    var frame = h.frame(a)!
    frame.size.width += 60
    h.system.userResize(a, to: frame, release: false)
    #expect(!h.run("undo").ok)
    #expect(!h.run("redo").ok)
    h.system.releaseMouse()
    #expect(h.run("undo").message == "undid resize \(a) by its edges")
  }

  @Test func aDragWhoseEndWasLostDoesNotBlockUndoForever() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.mouseDown = true
    h.controller.dragBegan(b, at: h.frame(b)!.center)
    h.system.mouseDown = false  // the mouse-up never reached Arbor
    #expect(h.run("undo").ok)
  }

  @Test func echoesOfArborsOwnActionsDoNotDisturbTheHistory() {
    // macOS reports Arbor's own focus and frame changes back a moment later.
    let (h, a, b, _) = makeHarness()
    func echo() {
      if let focused = h.system.focused { h.controller.windowFocused(focused) }
      for window in h.system.allWindows() { h.controller.windowChanged(window, userInitiated: false) }
    }
    let floating = Picture(h)
    h.run("dock \(a.rawValue) left")
    echo()
    let one = Picture(h)
    h.run("dock \(b.rawValue) right")
    echo()
    let two = Picture(h)
    #expect(undoLabels(h).count == 2)
    h.run("undo")
    echo()
    #expect(Picture(h) == one)
    h.run("undo")
    echo()
    #expect(Picture(h) == floating)
    h.run("redo")
    echo()
    h.run("redo")
    echo()
    #expect(Picture(h) == two)
    #expect(undoLabels(h).count == 2 && redoLabels(h).isEmpty)
  }

  // MARK: Everything at once

  /// Random commands, drags, closings and undos on two displays must never lose or duplicate a window.
  @Test(arguments: Array<UInt64>(1...60)) func randomWalksStayConsistent(seed: UInt64) {
    var random = SplitMix(seed: seed)
    var settings = Settings()
    settings.tabsEnabled = seed % 2 == 0
    let h = Harness(displays: [main, side], settings: settings)
    for index in 0..<4 {
      h.system.open(app: "App\(index)", frame: CGRect(x: 100 + 500 * index, y: 120, width: 420, height: 320))
    }
    h.start()
    func pick() -> WindowID? { h.system.allWindows().map(\.id).randomElement(using: &random) }
    let edges = ["left", "right", "top", "bottom"]
    /// Native tabs: the window in front, and the one behind it.
    var tabs: [WindowID: WindowID] = [:]

    for step in 0..<200 {
      h.system.cursor = Bool.random(using: &random) ? onMain : onSide
      var did = ""
      switch Int.random(in: 0..<26, using: &random) {
      case 0...2: did = "undo"
      case 3:
        // Undo and then redo is no change: the same workspaces to the last field, the same windows out of view, every
        // docked window where it was. (Floating windows nobody placed may have been moved onto the Desktop.) But for the
        // view: where it stayed put and would not have shown what the redo moved, it has stepped out, and Back returns.
        let before = Picture(h)
        let slots = h.controller.layouts.mapValues(\.windowFrames)
        if h.run("undo").ok {
          expectConsistent(h, "after step \(step): undo, seed \(seed)")
          #expect(h.run("redo").ok, "after step \(step), seed \(seed)")
          let after = Picture(h)
          var steppedOut = false
          for (display, old) in before.workspaces {
            guard let new = after.workspaces[display] else { continue }
            if new.camera == old.camera {
              #expect(new == old, "undo and redo on \(display) at step \(step), seed \(seed)")
            } else {
              steppedOut = true
              #expect(new.hasSameArrangement(as: old), "undo and redo on \(display) at step \(step), seed \(seed)")
              #expect(new.tree.subtree(new.camera, contains: old.camera), "stepped out at step \(step), seed \(seed)")
              #expect(new.back.last == old.camera, "Back returns at step \(step), seed \(seed)")
            }
          }
          if !steppedOut {
            // Nothing has gone out of view. A floating window may have come into view: on the way the Desktop was more than
            // a tile, and no change of the arrangement takes a floating window out of view again.
            #expect(after.parked.isSubset(of: before.parked), "undo and redo at step \(step), seed \(seed)")
            for window in before.parked.subtracting(after.parked) {
              #expect(h.controller.workspaces.values.contains { $0.isFloating(window) }, "undo and redo at step \(step), seed \(seed)")
            }
            #expect(h.controller.layouts.mapValues(\.windowFrames) == slots, "undo and redo at step \(step), seed \(seed)")
          }
          did = "(undo, redo)"
        }
      case 4...5: did = "redo"
      case 6...8: if let w = pick() { did = "dock \(w.rawValue) \(edges.randomElement(using: &random)!)" }
      case 9...10:
        if let w = pick(), let t = pick() { did = "dock \(w.rawValue) beside \(t.rawValue) \(edges.randomElement(using: &random)!)" }
      case 11: if let w = pick() { did = "toggle-float \(w.rawValue)" }
      case 12: did = "arrange"
      case 13: did = "float-all"
      case 14: if let w = pick() { did = "resize \(w.rawValue) \(edges.randomElement(using: &random)!) \(Int.random(in: -90...90, using: &random))" }
      case 15: if let w = pick() { did = "zoom \(w.rawValue)" }
      case 16: did = ["back", "show-all", "out", "desktop"].randomElement(using: &random)!
      case 17:
        if h.system.allWindows().count < 8 {
          let x = Bool.random(using: &random) ? 200 : 1700
          // Every third one will not go below a size that many slots are too small for, so that Arbor makes room or a tile.
          let stubborn = step % 3 == 0
          h.system.open(
            app: "New\(step)", frame: CGRect(x: x, y: 200, width: stubborn ? 700 : 400, height: stubborn ? 450 : 300),
            minimumSize: stubborn ? CGSize(width: 700, height: 450) : .zero)
          did = "(open)"
        }
      case 18:
        if h.system.allWindows().count > 2, let w = pick() {
          h.system.close(w)
          did = "(close \(w))"
        }
      case 19:
        // (Not the stubborn ones: Arbor waits a while before it judges a window that is only just back and does not fit.)
        if let w = pick(), let window = h.controller.windows[w], window.frame.width < 700 {
          h.system.setMinimized(w, !window.isMinimized)
          did = "(minimize \(w))"
        }
      case 20:
        if let w = pick(), let frame = h.frame(w), h.system.isVisible(w), h.controller.windows[w]?.isPresent == true {
          let x = CGFloat.random(in: 2...2700, using: &random)
          let y = CGFloat.random(in: 30...780, using: &random)
          h.system.drag(w, through: [CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: x, y: y)])
          did = "(drag \(w) to \(Int(x)),\(Int(y)))"
        }
      case 21:
        if Int.random(in: 0..<3, using: &random) == 0 {
          let connected = h.system.displayList.count == 2
          h.system.setDisplays(connected ? [main] : [main, side])
          did = connected ? "(unplug)" : "(plug in)"
        }
      case 24:
        if let w = pick() {
          did = Bool.random(using: &random) ? "toggle-pin \(w.rawValue)" : "summon \(h.controller.windows[w]?.appName ?? "App0")"
        }
      case 22:
        if let w = pick(), h.system.allWindows().count < 8, let tab = h.system.openTab(in: w) {
          tabs[tab] = w
          did = "(new tab \(tab) in \(w))"
        }
      case 23:
        // (Sorted: a dictionary's order differs from run to run, and a walk has to be the same every time.)
        if let (front, behind) = tabs.sorted(by: { $0.key < $1.key }).first(where: { h.controller.windows[$0.key] != nil }) {
          h.system.selectTab(behind, insteadOf: front)
          tabs[front] = nil
          tabs[behind] = front
          did = "(tab \(behind) in front of \(front))"
        }
      default:
        if let seams = h.overlays.seams[main.id], let seam = seams.randomElement(using: &random) {
          h.overlays.dragSeam(seam, by: CGFloat.random(in: -60...60, using: &random), on: main.id)
          did = "(seam)"
        }
      }
      if !did.isEmpty, !did.hasPrefix("(") { h.run(did) }
      h.scheduler.runPending()
      expectConsistent(h, "after step \(step): \(did), seed \(seed)")
    }
    // Walk all the way back and forward again on both displays.
    for cursor in [onMain, onSide] {
      h.system.cursor = cursor
      for verb in ["undo", "redo"] {
        for _ in 0..<300 {
          // A failure can also be "cannot undo the closing of…", after which there is more.
          let result = h.run(verb)
          if !result.ok, result.message.hasPrefix("nothing to") { break }
          expectConsistent(h, "\(verb) all the way, seed \(seed)")
        }
      }
    }
  }
}

extension UndoTests {
  /// Launches after which windows come back late, under other numbers, while the user docks, undoes and redoes
  /// (compare `PendingSlotChaosTests`). A slot that waits is a place in a tree: it never floats, is never in two
  /// places, and does not wait for ever.
  @Test(arguments: Array<UInt64>(1...40)) func launchesWithLateWindowsSurviveUndo(seed: UInt64) {
    var random = SplitMix(seed: seed)
    let apps = ["Safari", "Mail", "Terminal"]
    let first = Harness()
    for index in 0..<5 {
      first.system.open(
        app: apps[index % 3], title: "t\(index)", frame: CGRect(x: 60 + 150 * index, y: 80 + 40 * index, width: 500, height: 300))
    }
    first.start()
    for window in first.system.allWindows() where Int.random(in: 0..<4, using: &random) > 0 {
      first.run("dock \(window.id.rawValue) \(["left", "right", "top", "bottom"].randomElement(using: &random)!)")
    }
    first.controller.saveNow()

    let h = Harness(saved: first.store.saved)
    var late: [WindowSnapshot] = []
    for window in first.system.allWindows() {
      if Bool.random(using: &random) {
        late.append(window)
      } else {
        h.system.open(app: window.appName, title: window.title, frame: window.frame)
      }
    }
    h.start()

    func check(_ note: String) {
      var seen = Set<WindowID>()
      for workspace in h.controller.workspaces.values {
        #expect(workspace.tree.invariantViolations().isEmpty, "\(note)")
        #expect(workspace.tree.contains(workspace.camera), "\(note)")
        for window in workspace.allWindows { #expect(seen.insert(window).inserted, "\(window) is in two places \(note)") }
        for window in workspace.floating.keys {
          #expect(h.controller.windows[window] != nil, "\(window) floats and does not exist \(note)")
        }
      }
      for window in h.system.allWindows() { #expect(seen.contains(window.id), "\(window.id) is nowhere \(note)") }
    }
    check("at launch, seed \(seed)")

    for step in 0..<60 {
      let pick = h.system.allWindows().map(\.id).randomElement(using: &random)
      var did = ""
      switch Int.random(in: 0..<12, using: &random) {
      case 0...2: did = "undo"
      case 3: did = "redo"
      case 4...5:
        if let pick { did = "dock \(pick.rawValue) \(["left", "right", "top", "bottom"].randomElement(using: &random)!)" }
      case 6: if let pick { did = "toggle-float \(pick.rawValue)" }
      case 7: if let pick { did = "zoom \(pick.rawValue)" }
      case 8...9:
        if let window = late.popLast() {
          h.system.open(app: window.appName, title: window.title, frame: window.frame)
          did = "(late window)"
        }
      case 10:
        h.run("pause")
        if let pick, h.system.allWindows().count > 1 {
          if let closed = h.controller.windows[pick] { late.append(closed) }
          h.system.close(pick)
        }
        h.run("resume")
        did = "(pause, close, resume)"
      default:
        h.scheduler.advance(by: [0.6, 30, Controller.pendingSlotLifetime].randomElement(using: &random)!)
        did = "(time passes)"
      }
      if !did.isEmpty, !did.hasPrefix("(") { h.run(did) }
      check("after step \(step): \(did), seed \(seed)")
    }
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    expectConsistent(h, "in the end, seed \(seed)")
  }
}

/// SplitMix64, so random tests are reproducible.
private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  // Not a multiple of the step below, or each seed would give the previous one's sequence shifted by one.
  init(seed: UInt64) { state = (seed ^ 0x5_DEEC_E66D) &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

extension UndoTests {
  /// Found by the chaos lab. People leave windows hanging over the edge of the screen, and undo puts them back there. But an app
  /// has the last word on its window's size: one that stays narrower than it was can end up beyond the edge altogether.
  @Test func aWindowThatComesBackNarrowerIsNotLeftBeyondTheEdgeItHungOver() {
    let h = Harness()
    let a = h.system.open(app: "Finder", frame: CGRect(x: 200, y: 133, width: 853, height: 206))
    h.start()
    h.system.userMove(a, to: CGRect(x: -386, y: 133, width: 853, height: 206))
    #expect(h.system.isVisible(a), "more than half of it shows")
    #expect(h.run("dock \(a.rawValue) right").ok)
    h.system.setMaximumSize(a, CGSize(width: 252, height: 869))
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(a))
    #expect(h.system.isVisible(a), "it is at \(h.frame(a)!)")
    #expect(h.visibleFrame.contains(h.frame(a)!))

    // The same way out of the arrangement without undo.
    h.run("redo")
    #expect(h.run("float \(a.rawValue)").ok)
    #expect(h.system.isVisible(a), "it is at \(h.frame(a)!)")
  }
}

extension UndoTests {
  /// Found by the chaos lab: `undo` succeeded and `redo` straight after it did not.
  @Test func redoFollowsAnUndoAlsoAfterTheGapWasChangedInTheSettings() {
    let h = Harness()
    h.start()
    let a = h.system.open(
      app: "Notes", frame: CGRect(x: 261, y: 2365, width: 1551, height: 1075), minimumSize: CGSize(width: 663, height: 490))
    #expect(h.run("dock \(a.rawValue) right").ok)
    var settings = Settings()
    settings.gap = 24
    h.controller.apply(settings: settings)
    let before = h.workspace
    #expect(h.run("undo").message == "undid dock \(a) right")
    #expect(h.run("redo").message == "redid dock \(a) right")
    #expect(h.workspace.hasSameArrangement(as: before))
    expectConsistent(h)
  }
}
