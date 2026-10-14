import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay
private let onMain = CGPoint(x: 700, y: 450)
private let onSide = CGPoint(x: 2000, y: 400)

/// What must hold after anything at all: every window Arbor arranges is in exactly one place, what is in view is where
/// the layout says, nothing that shows counts as out of view, and nothing that should show is out of view.
@MainActor
private func expectSound(_ h: Harness, _ note: String, sourceLocation: SourceLocation = #_sourceLocation) {
  var places: [WindowID: Int] = [:]
  for (display, workspace) in h.controller.workspaces {
    let problems = workspace.tree.invariantViolations()
    #expect(problems.isEmpty, "\(display): \(problems) \(note)", sourceLocation: sourceLocation)
    #expect(workspace.tree.contains(workspace.camera), "\(display): the camera is nowhere \(note)", sourceLocation: sourceLocation)
    for node in workspace.back + workspace.forward + Array(workspace.savedViews.values) {
      #expect(workspace.tree.contains(node), "\(display): \(node) is remembered and gone \(note)", sourceLocation: sourceLocation)
    }
    for window in workspace.tree.allWindows + Array(workspace.floating.keys) { places[window, default: 0] += 1 }
    for window in workspace.pinned ?? [] {
      #expect(workspace.isFloating(window), "\(window) is pinned and does not float \(note)", sourceLocation: sourceLocation)
    }
    for (guest, host) in workspace.guests ?? [:] {
      #expect(workspace.isFloating(guest), "\(guest) is a guest and does not float \(note)", sourceLocation: sourceLocation)
      #expect(workspace.tree.contains(host), "\(guest)'s host is gone \(note)", sourceLocation: sourceLocation)
    }
    guard let layout = h.controller.layouts[display] else {
      Issue.record("no layout for \(display) \(note)", sourceLocation: sourceLocation)
      continue
    }
    for (window, frame) in layout.windowFrames {
      #expect(
        h.frame(window)?.approximatelyEquals(frame, tolerance: 2) == true,
        "\(window) is at \(String(describing: h.frame(window))), its slot is \(frame) \(note)", sourceLocation: sourceLocation)
      #expect(!h.controller.parked.contains(window), "\(window) shows and counts as out of view \(note)", sourceLocation: sourceLocation)
    }
    for window in layout.hiddenWindows {
      #expect(!h.system.isVisible(window), "\(window) should be out of view \(note)", sourceLocation: sourceLocation)
    }
    for window in workspace.floating.keys where h.controller.windows[window]?.isPresent == true {
      if h.controller.parked.contains(window) {
        #expect(!h.system.isVisible(window), "\(window) floats in view and counts as out of view \(note)", sourceLocation: sourceLocation)
        // With the Desktop in view every floating window is in view.
        #expect(layout.desktopFrame == nil, "\(window) is out of view with the Desktop in view \(note)", sourceLocation: sourceLocation)
      }
    }
  }
  for window in h.system.allWindows() {
    #expect(places[window.id] == 1, "\(window.id) is in \(places[window.id] ?? 0) places \(note)", sourceLocation: sourceLocation)
  }
  // A number without a window is a slot that waits for its window to come back (a window closed during a pause): a place
  // in a tree and nothing else.
  let gone = Set(places.keys).subtracting(h.system.allWindows().map(\.id))
  for window in gone {
    #expect(
      !h.controller.workspaces.values.contains { $0.isFloating(window) }, "\(window) is gone and floats \(note)",
      sourceLocation: sourceLocation)
  }
  for window in h.controller.parked {
    #expect(h.controller.windows[window] != nil, "\(window) is gone and counts as out of view \(note)", sourceLocation: sourceLocation)
  }
}

private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { state = (seed ^ 0x1234_5678_9ABC) &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

/// An independent review of undo and redo (F19): an old arrangement put back into a world that has moved on. Written against
/// an early head; three tests follow decisions taken since (what the note about a closing says, no undo in a window
/// that is full screen, a view that steps out).
@Suite @MainActor struct ReviewUndoTests {
  func labels(_ h: Harness, _ direction: UndoHistory.Direction = .undo, on display: DisplayID? = nil) -> [String] {
    h.controller.undoHistory.steps(direction, on: display ?? h.display).map(\.label)
  }

  /// Three floating windows of three apps, started.
  func makeHarness(displays: [DisplaySnapshot]? = nil) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: displays ?? [main])
    let a = h.system.open(app: "Safari", pid: 2001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 2002, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 2003, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  // MARK: What counts as one step

  /// The timer that closes a step of quick resizes finds Arbor paused and does nothing. The step must not stay
  /// open: the same shortcut minutes later is another adjustment.
  @Test func aResizeLongAfterAPauseIsAStepOfItsOwn() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("resize \(a.rawValue) right 20")
    h.run("pause")
    h.scheduler.advance(by: 60)
    h.run("resume")
    h.scheduler.advance(by: 60)
    let between = h.frame(a)
    h.run("resize \(a.rawValue) right 20")
    #expect(labels(h) == ["dock \(a) left", "resize \(a) right", "resize \(a) right"])
    #expect(h.run("undo").ok)
    #expect(h.frame(a) == between, "one undo takes back the last resize only")
  }

  /// The same for a gap that was in the hand when the pause began.
  @Test func aGapDraggedAgainLongAfterAPauseIsAStepOfItsOwn() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    h.run("pause")
    h.system.mouseDown = false
    h.scheduler.advance(by: 60)
    h.run("resume")
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    h.system.mouseDown = false
    h.scheduler.advance(by: 1)
    #expect(labels(h).count == 3)
  }

  @Test func thousandsOfChangesKeepFiftySteps() {
    let (h, a, b, _) = makeHarness(displays: [main, side])
    for round in 0..<1500 {
      h.run("dock \((round % 2 == 0 ? a : b).rawValue) \(["left", "right", "top", "bottom"][round % 4])")
      if round % 7 == 0 { h.run("undo") }
    }
    for display in [main.id, side.id] {
      #expect(labels(h, .undo, on: display).count <= UndoHistory.limit)
      #expect(labels(h, .redo, on: display).count <= UndoHistory.limit)
    }
    expectSound(h, "")
  }

  /// What cannot be undone on one display has nothing to do with the next change on another: saying so here
  /// must not use up the step there.
  @Test func sayingThatAClosingCannotBeUndoneLeavesTheOtherDisplaysStepsAlone() {
    let (h, a, b, _) = makeHarness(displays: [main, side])
    h.system.cursor = onMain
    h.run("dock \(a.rawValue) left")
    h.system.close(a)
    h.system.userMove(b, to: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.system.cursor = onSide
    h.run("dock \(b.rawValue) left")
    #expect(labels(h, on: side.id) == ["dock \(b) left"])
    h.system.cursor = onMain
    #expect(h.run("undo", from: .menu).message.hasPrefix("cannot undo the closing of a window of Safari"))
    #expect(labels(h, on: side.id) == ["dock \(b) left"])
    h.system.cursor = onSide
    #expect(h.run("undo", from: .menu).message == "undid dock \(b) left")
    expectSound(h, "")
  }

  // MARK: What is restored besides the tree

  /// The view's space is gone from the restored arrangement, so the view goes back to where it was before the change,
  /// which can be the place the history kept since ends with. `back` must still go somewhere.
  @Test func historyDoesNotEndWhereTheViewIsPutBack() {
    let (h, a, _, _) = makeHarness()
    h.run("arrange")
    h.run("desktop")
    h.run("zoom \(a.rawValue)")
    #expect(h.run("undo").message == "undid arrange")
    #expect(h.workspace.back.last != h.workspace.camera, "back \(h.workspace.back), camera \(h.workspace.camera)")
    #expect(h.workspace.forward.last != h.workspace.camera)
    expectSound(h, "")
  }

  // MARK: The orders macOS really sends (collab/evidence/ax-events.txt)

  /// Focus moves to the next window before the closing of the focused one is reported.
  @Test func focusThatArrivesBeforeTheClosingDoesNotConfuseUndo() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(b)
    h.controller.windowFocused(a)
    h.system.close(b)
    let first = h.run("undo")
    #expect(
      !first.ok && first.message == "cannot undo the closing of a window of Notes; undo again to take back dock \(a) left")
    #expect(h.run("undo").message == "undid dock \(a) left")
    expectSound(h, "")
  }

  // MARK: A world that has moved on

  @Test func aWindowThatWentFullScreenSinceIsNotTouchedAndKeepsItsPlace() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.setFullScreen(b, true)
    // In the full-screen window itself undo is refused, as `dock` is. The keyboard is in another window.
    h.system.userFocus(a)
    h.system.clearFrameLog()
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(!h.system.frameLog.contains { $0.window == b }, "a full-screen window is never moved")
    #expect(h.workspace.isFloating(b))
    #expect(h.run("redo").ok)
    #expect(!h.system.frameLog.contains { $0.window == b })
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(b))
    expectSound(h, "")
  }

  /// `setFrame` fails for every window of an app that hangs. Nothing may end up out of view for good.
  @Test func anAppThatHangsDuringTheUndoGetsItsWindowsBackWhenItAnswers() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2002, true)
    h.system.setUnresponsive(pid: 2003, true)
    #expect(h.run("undo").ok)
    #expect(h.run("undo").ok)
    h.system.setUnresponsive(pid: 2002, false)
    h.system.setUnresponsive(pid: 2003, false)
    h.scheduler.advance(by: 5)
    h.run("show-all")
    h.scheduler.advance(by: 5)
    for window in [a, b, c] { #expect(h.system.isVisible(window), "\(window) is at \(String(describing: h.frame(window)))") }
    expectSound(h, "")
  }

  @Test func quitAndRelaunchStartsWithNoHistoryAndTheArrangementTheUndoLeft() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    h.controller.saveNow()
    let again = Harness(saved: h.store.saved)
    for window in h.system.allWindows() { again.system.open(app: window.appName, title: window.title, pid: window.pid, frame: window.frame) }
    again.start()
    #expect(again.workspace.tree.allWindows.count == 1)
    #expect(!again.run("undo").ok && !again.run("redo").ok)
    expectSound(again, "")
  }

  // MARK: Commands

  @Test func theCommandsRoundTripAndTakeNoArguments() throws {
    for (text, command) in [("undo", Command.undo), ("redo", Command.redo)] {
      #expect(try Command.parse(text) == command)
      #expect(command.text == text)
      #expect(Command.helpText.contains(text))
      #expect(command.isAllowedFromURL)
      #expect(!command.isQuery)
      #expect(throws: (any Error).self) { try Command.parse("\(text) 2") }
    }
  }

  /// Several apps with their own pids and several windows each, two displays, and everything that can happen to a window
  /// between a change and its undo: full screen, other Spaces, hidden, hung and quitting apps, pauses, minimum sizes.
  @Test(arguments: Array<UInt64>(1...40)) func aWorldThatMovesOnNeverLosesAWindow(seed: UInt64) {
    var random = SplitMix(seed: seed)
    var settings = Settings()
    settings.tabsEnabled = seed % 3 != 0
    let h = Harness(displays: [main, side], settings: settings)
    let apps: [(String, Int32)] = [("Safari", 2001), ("Mail", 2002), ("Terminal", 2003), ("Notes", 2004)]
    func open(_ index: Int) {
      let (app, pid) = apps[index % apps.count]
      let minimum = index % 5 == 4 ? CGSize(width: 700, height: 500) : .zero
      let size = index % 5 == 4 ? minimum : CGSize(width: 420, height: 320)
      h.system.open(
        app: app, pid: pid, frame: CGRect(origin: CGPoint(x: 80 + 430 * (index % 6), y: 100 + 20 * index), size: size),
        minimumSize: minimum)
    }
    for index in 0..<6 { open(index) }
    h.start()
    func pick() -> WindowID? { h.system.allWindows().map(\.id).sorted().randomElement(using: &random) }
    let edges = ["left", "right", "top", "bottom"]
    var hung: Int32?
    var opened = 6

    for step in 0..<220 {
      h.system.cursor = Bool.random(using: &random) ? onMain : onSide
      var did = ""
      switch Int.random(in: 0..<34, using: &random) {
      case 0...3: did = "undo"
      case 4...5: did = "redo"
      case 6 where hung == nil:
        let (workspaces, parked) = (h.controller.workspaces, h.controller.parked)
        let slots = h.controller.layouts.mapValues(\.windowFrames)
        if h.run("undo").ok {
          expectSound(h, "after step \(step): undo, seed \(seed)")
          let redone = h.run("redo")
          #expect(redone.ok, "redo after undo at step \(step), seed \(seed): \(redone.message)")
          for (display, now) in h.controller.workspaces {
            guard var then = workspaces[display] else { continue }
            // A redo that would show nothing from where the view is steps out to show it, like an undo; `back` returns.
            if now.camera != then.camera, now.back.last == then.camera { then.moveCamera(to: now.camera) }
            #expect(now == then, "undo, redo at step \(step) on \(display), seed \(seed)")
          }
          for (display, now) in h.controller.workspaces {
            guard let then = workspaces[display] else { continue }
            let (mine, note) = (Set(now.allWindows), "undo, redo at step \(step) on \(display), seed \(seed)")
            if now.camera == then.camera {
              #expect(h.controller.parked.intersection(mine) == parked.intersection(mine), "\(note)")
              #expect(h.controller.layouts[display]?.windowFrames == slots[display], "\(note)")
            } else {
              // The view stepped out: it holds what it held, more is in view than was, and nothing less.
              #expect(now.tree.subtree(now.camera, contains: then.camera), "\(note)")
              #expect(h.controller.parked.intersection(mine).isSubset(of: parked), "\(note)")
            }
          }
          did = "(undo, redo)"
        }
      case 7...9: if let w = pick() { did = "dock \(w.rawValue) \(edges.randomElement(using: &random)!)" }
      case 10...11:
        if let w = pick(), let t = pick() { did = "dock \(w.rawValue) beside \(t.rawValue) \(edges.randomElement(using: &random)!)" }
      case 12: if let w = pick() { did = "toggle-float \(w.rawValue)" }
      case 13: did = ["arrange", "arrange all", "float-all", "float-all here"].randomElement(using: &random)!
      case 14:
        if let w = pick() { did = "resize \(w.rawValue) \(edges.randomElement(using: &random)!) \(Int.random(in: -120...120, using: &random))" }
      case 15: if let w = pick() { did = "zoom \(w.rawValue)" }
      case 16: did = ["back", "forward", "show-all", "out", "desktop", "home"].randomElement(using: &random)!
      case 17: did = ["save-view 1", "save-view 2", "view 1", "view 2"].randomElement(using: &random)!
      case 18:
        if h.system.allWindows().count < 9 {
          open(opened)
          opened += 1
          did = "(open)"
        }
      case 19:
        if h.system.allWindows().count > 2, let w = pick() {
          h.system.close(w)
          did = "(close \(w))"
        }
      case 20:
        if let w = pick(), let window = h.controller.windows[w] {
          h.system.setMinimized(w, !window.isMinimized)
          did = "(minimize \(w))"
        }
      case 21:
        if let w = pick(), let window = h.controller.windows[w], !window.isMinimized {
          h.system.setFullScreen(w, !window.isFullScreen)
          did = "(full screen \(w))"
        }
      case 22:
        if let w = pick(), let window = h.controller.windows[w] {
          h.system.setOnActiveSpace(w, !window.isOnActiveSpace)
          did = "(other Space \(w))"
        }
      case 23:
        let (_, pid) = apps.randomElement(using: &random)!
        let hidden = h.system.allWindows().first { $0.pid == pid }?.isHidden ?? false
        h.system.setHidden(pid: pid, !hidden)
        did = "(hide \(pid))"
      case 24:
        if let pid = hung {
          h.system.setUnresponsive(pid: pid, false)
          hung = nil
          did = "(\(pid) answers again)"
        } else {
          hung = apps.randomElement(using: &random)!.1
          h.system.setUnresponsive(pid: hung!, true)
          did = "(\(hung!) hangs)"
        }
      case 25:
        let (_, pid) = apps.randomElement(using: &random)!
        if h.system.allWindows().filter({ $0.pid != pid }).count >= 2, Int.random(in: 0..<3, using: &random) == 0 {
          h.system.quit(pid: pid)
          did = "(quit \(pid))"
        }
      case 26:
        if let w = pick(), let frame = h.frame(w), h.system.isVisible(w), h.controller.windows[w]?.isPresent == true {
          let point = CGPoint(x: CGFloat.random(in: 2...2700, using: &random), y: CGFloat.random(in: 30...780, using: &random))
          h.system.drag(w, through: [CGPoint(x: frame.midX, y: frame.minY + 10), point])
          did = "(drag \(w) to \(point))"
        }
      case 27:
        if Int.random(in: 0..<3, using: &random) == 0 {
          let connected = h.system.displayList.count == 2
          h.system.setDisplays(connected ? [main] : [main, side])
          did = connected ? "(unplug)" : "(plug in)"
        }
      case 28: if let w = pick() { did = "toggle-pin \(w.rawValue)" }
      case 29:
        h.run("pause")
        if Bool.random(using: &random), h.system.allWindows().count > 2, let w = pick() { h.system.close(w) }
        if Bool.random(using: &random), let w = pick(), let frame = h.frame(w) {
          h.system.userMove(w, to: frame.offsetBy(dx: 40, dy: 30))
        }
        h.run("resume")
        did = "(pause and resume)"
      case 30:
        if let w = pick(), let slot = h.controller.layouts.values.compactMap({ $0.windowFrames[w] }).first {
          var frame = slot
          frame.size.width += CGFloat(Int.random(in: -80...80, using: &random))
          h.system.userResize(w, to: frame)
          did = "(resize \(w) by its edge)"
        }
      case 31:
        if let w = pick(), h.controller.workspaces.values.contains(where: { $0.isFloating(w) }), h.system.isVisible(w),
          let frame = h.frame(w)
        {
          h.system.userMove(w, to: frame.offsetBy(dx: CGFloat.random(in: -200...200, using: &random), dy: 25))
          did = "(move \(w))"
        }
      case 32: if let w = pick() { h.system.userFocus(w); did = "(focus \(w))" }
      default:
        let display = Bool.random(using: &random) ? main.id : side.id
        if let seam = h.overlays.seams[display]?.randomElement(using: &random) {
          h.overlays.dragSeam(seam, by: CGFloat.random(in: -60...60, using: &random), on: display)
          did = "(seam)"
        }
      }
      if !did.isEmpty, !did.hasPrefix("(") { h.run(did) }
      // A hung app's windows cannot be moved: what is where is checked when it answers again.
      if hung != nil { continue }
      h.scheduler.advance(by: 2)
      expectSound(h, "after step \(step): \(did), seed \(seed)")
      // Moving the view is never a step, whatever a layout does on the way.
      for display in [main.id, side.id] {
        let views = (labels(h, .undo, on: display) + labels(h, .redo, on: display)).filter { label in
          ["zoom", "back", "forward", "show-all", "out", "desktop", "home", "view", "save-view"].contains { label.hasPrefix($0) }
        }
        #expect(views.isEmpty, "\(views) after step \(step): \(did), seed \(seed)")
      }
    }
    if let hung { h.system.setUnresponsive(pid: hung, false) }
    h.scheduler.advance(by: 2)
    for cursor in [onMain, onSide] {
      h.system.cursor = cursor
      for verb in ["undo", "redo"] {
        for _ in 0..<300 {
          let result = h.run(verb)
          if !result.ok, result.message.hasPrefix("nothing to") { break }
          h.scheduler.advance(by: 2)
          expectSound(h, "\(verb) all the way, seed \(seed)")
        }
      }
    }
  }
}
