import ArborCore
import ArborTesting
import CoreGraphics
import Testing

@testable import ArborKit

/// F09, from an independent review: what a drag meets on a real Mac that `DragStormTests` leaves out.
@Suite @MainActor struct ReviewDragStormTests {
  typealias Random = DragStormTests.Random
  let storm = DragStormTests()

  /// Like `DragStormTests.arrangement`, but the windows belong to five apps, so that one of them can hang, hide or quit.
  func arrangement(_ random: inout Random, _ configure: (inout Settings) -> Void) -> (Harness, [WindowID]) {
    var settings = Settings()
    settings.tabsEnabled = Bool.random(using: &random)
    configure(&settings)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, DragStormTests.side], settings: settings)
    var windows: [WindowID] = []
    for (index, app) in ["Safari", "Notes", "Mail", "Mail", "Music", "Finder"].enumerated() {
      let onSide = index >= 4
      let frame = CGRect(
        x: Int.random(in: 40...700, using: &random) + (onSide ? 1440 : 0), y: Int.random(in: 60...400, using: &random),
        width: Int.random(in: 250...600, using: &random), height: Int.random(in: 150...380, using: &random))
      windows.append(h.system.open(app: app, pid: ["Safari": 2001, "Notes": 2002, "Mail": 2003, "Music": 2004, "Finder": 2005][app]!, frame: frame))
    }
    h.start()
    let edges = ["left", "right", "top", "bottom"]
    for window in windows where Int.random(in: 0..<3, using: &random) > 0 {
      h.system.cursor = h.frame(window)!.center
      let docked = h.controller.workspaces.values.flatMap(\.tree.allWindows).sorted()
      if let other = docked.randomElement(using: &random), Bool.random(using: &random) {
        h.run("dock \(window.rawValue) beside \(other.rawValue) \(edges.randomElement(using: &random)!)")
      } else {
        h.run("dock \(window.rawValue) \(edges.randomElement(using: &random)!)")
      }
    }
    h.system.cursor = CGPoint(x: 720, y: 450)
    if Bool.random(using: &random), let floating = h.workspace.floating.keys.sorted().randomElement(using: &random) {
      h.run("pin \(floating.rawValue)")
    }
    if Int.random(in: 0..<3, using: &random) == 0, let framed = h.workspace.tree.allWindows.randomElement(using: &random) {
      h.run("zoom \(framed.rawValue)")
      if Bool.random(using: &random) {
        windows.append(h.system.open(app: "Preview", pid: 2999, frame: CGRect(x: 500, y: 300, width: 300, height: 200)))
      }
    }
    h.scheduler.runPending()
    return (h, windows)
  }

  /// Full screen, hidden apps, Space switches, apps that hang or quit, pause and resume, pins, settings, native tabs,
  /// late echoes and every command that names a window, in the middle of drags that end in every way there is.
  @Test(arguments: [false, true]) func whateverMacOSDoesDuringADragNothingIsLostOrLeftBehind(reflow: Bool) {
    for seed in UInt64(1)...200 {
      var random = Random(seed: seed &+ 7000)
      let (h, opened) = arrangement(&random) { $0.reflowWhileDragging = reflow }
      var windows = opened
      var leftByTheUser: Set<WindowID> = []
      var trace: [String] = []
      // Nothing moves a window that is in the user's hand.
      h.system.willSetFrame = { [weak h] window, frame in
        if h?.controller.drag?.window == window {
          Issue.record("seed \(seed): \(window) was moved to \(frame) while it was being dragged; \(trace)")
        }
      }
      for _ in 0..<3 {
        guard let dragged = windows.filter({ !h.controller.parked.contains($0) }).randomElement(using: &random) else { break }
        leftByTheUser.insert(dragged)
        trace.append("drag \(dragged.rawValue)")
        h.system.beginDrag(dragged)
        for _ in 0..<Int.random(in: 1...4, using: &random) {
          storm.wander(&random, h)
          // Half the time it is about the window in the hand: that is the one with the keyboard.
          guard let other = Bool.random(using: &random) && windows.contains(dragged) ? dragged : windows.randomElement(using: &random),
            let pid = h.system.windows[other]?.snapshot.pid
          else { break }
          let edge = ["left", "right", "top", "bottom"].randomElement(using: &random)!
          let event = Int.random(in: 0..<27, using: &random)
          trace.append("\(event):\(other.rawValue)")
          switch event {
          case 0: h.system.setFullScreen(other, Bool.random(using: &random))
          case 1: h.system.setHidden(pid: pid, Bool.random(using: &random))
          case 2:
            // ⌃→ with a window in the hand: it comes along, the others stay behind.
            for window in windows where window != dragged { h.system.setOnActiveSpace(window, false) }
          case 3: for window in windows { h.system.setOnActiveSpace(window, true) }
          case 4: h.system.setUnresponsive(pid: pid, Bool.random(using: &random))
          case 5:
            h.system.quit(pid: pid)
            windows.removeAll { h.system.windows[$0] == nil }
          case 6:
            h.run("pause")
            h.run("resume")
          case 7: h.run("toggle-pin \(other.rawValue)")
          case 8: h.run("toggle-float \(other.rawValue)")
          case 9: h.system.deliverEchoes()
          case 10: h.scheduler.advance(by: [0.05, 0.5, 3].randomElement(using: &random)!)
          case 11:
            var settings = h.controller.settings
            settings.reflowWhileDragging.toggle()
            h.controller.apply(settings: settings)
          case 12:
            if let tab = h.system.openTab(in: other) {
              windows = windows.map { $0 == other ? tab : $0 }
              // It is where the window it took over from was.
              if leftByTheUser.contains(other) { leftByTheUser.insert(tab) }
            }
          case 13: h.run("neighbor \(edge)")
          case 14: h.run("desktop")
          case 15: h.run("relayout")
          case 16: h.run("dock \(other.rawValue) \(edge)")
          case 17: h.run("resize \(other.rawValue) \(edge) \([-80, 60].randomElement(using: &random)!)")
          case 18: h.run("zoom \(other.rawValue)")
          case 19: h.run(["arrange", "arrange all", "float-all", "float-all here", "home"].randomElement(using: &random)!)
          case 20: h.system.setMinimized(other, Bool.random(using: &random))
          case 21:
            h.run("exclude \(h.system.windows[other]!.snapshot.bundleID!)")
            if Bool.random(using: &random) { h.run("include \(h.system.windows[other]!.snapshot.bundleID!)") }
          case 22: h.system.setTitle(other, "another title")
          case 23: h.system.setDisplays([FakeWindowSystem.standardDisplay])
          case 24: h.system.setDisplays([FakeWindowSystem.standardDisplay, DragStormTests.side])
          case 25:
            // The lid is closed, or the one cable pulled: for a moment there is no display at all.
            h.system.setDisplays([])
            h.system.setDisplays(Bool.random(using: &random) ? [FakeWindowSystem.standardDisplay] : [FakeWindowSystem.standardDisplay, DragStormTests.side])
          default: h.system.userFocus(other)
          }
          if windows.isEmpty { break }
        }
        trace.append("end")
        if Bool.random(using: &random) { h.system.endDrag() } else { h.system.loseTheReleaseOfTheDrag() }
        h.system.heldModifiers = []
        // Everything macOS took away comes back, so that what is left can be judged.
        for window in windows {
          guard let snapshot = h.system.windows[window]?.snapshot else { continue }
          h.system.setUnresponsive(pid: snapshot.pid, false)
          h.system.setHidden(pid: snapshot.pid, false)
          h.system.setFullScreen(window, false)
          h.system.setOnActiveSpace(window, true)
          h.system.setMinimized(window, false)
          h.run("include \(snapshot.bundleID!)")
        }
        h.scheduler.runPending()
        h.system.deliverEchoes()
        h.scheduler.runPending()
        var troubles = storm.troubles(h, leftByTheUser: leftByTheUser)
        // What Arbor counts as out of view is out of view: it ignores what the user does with such a window, and sends
        // it back to the corner.
        for window in h.controller.parked.sorted() where h.system.isVisible(window) {
          troubles.append("\(window) shows at \(h.frame(window)!) and counts as out of view")
        }
        storm.expectNone(troubles, seed, " \(trace)")
        if windows.isEmpty { break }
      }
    }
  }
}

/// A display goes away or comes back while a window is in the hand.
@Suite @MainActor struct ReviewDragDisplayTests {
  static let main = FakeWindowSystem.standardDisplay
  static let side = DragStormTests.side

  /// Safari docked on the main display; Mail on the side display, docked or floating.
  func scene(reflow: Bool, docked: Bool, framed: Bool) -> (h: Harness, safari: WindowID, mail: WindowID) {
    var settings = Settings()
    settings.reflowWhileDragging = reflow
    let h = Harness(displays: [Self.main, Self.side], settings: settings)
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 1700, y: 200, width: 500, height: 300))
    h.start()
    h.run("dock \(safari.rawValue) left")
    if docked { h.run("dock \(mail.rawValue) left") }
    // With Safari framed the Desktop of the main display, where windows that lose their display go, is out of view.
    if framed { h.run("zoom \(safari.rawValue)") }
    h.scheduler.runPending()
    return (h, safari, mail)
  }

  @Test(arguments: [false, true], [false, true])
  func aWindowWhoseDisplayGoesAwayStaysInTheHand(docked: Bool, framed: Bool) throws {
    for reflow in [false, true] { try aWindowWhoseDisplayGoesAwayStaysInTheHand(reflow: reflow, docked: docked, framed: framed) }
  }

  func aWindowWhoseDisplayGoesAwayStaysInTheHand(reflow: Bool, docked: Bool, framed: Bool) throws {
    let (h, _, mail) = scene(reflow: reflow, docked: docked, framed: framed)
    h.system.beginDrag(mail)
    h.system.moveDrag(to: CGPoint(x: 1500, y: 400), holding: 0.3)
    let held = try #require(h.frame(mail))

    h.system.setDisplays([Self.main])
    #expect(h.frame(mail) == held, "it was taken out of the hand")
    #expect(!h.controller.parked.contains(mail), "what is in the hand is in view")

    // Carried on to the display that is left and let go there, it stays there like any window that is let go.
    h.system.moveDrag(to: CGPoint(x: 900, y: 400), holding: 0.3)
    let dropped = try #require(h.frame(mail))
    h.system.endDrag()
    h.scheduler.runPending()
    #expect(h.workspace.isFloating(mail))
    #expect(!h.controller.parked.contains(mail))
    #expect(h.frame(mail)?.origin == dropped.origin)
    // Nor is it thrown out of view by the first thing that happens afterwards.
    h.system.userMove(mail, to: try #require(h.frame(mail)).offsetBy(dx: 10, dy: 0))
    h.scheduler.runPending()
    #expect(h.system.isVisible(mail))
    #expect(!h.controller.parked.contains(mail))
    #expect(h.overlays.preview == nil)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") })
  }

  @Test(arguments: [false, true], [false, true])
  func aWindowWhoseDisplayComesBackStaysInTheHand(reflow: Bool, docked: Bool) throws {
    let (h, _, mail) = scene(reflow: reflow, docked: docked, framed: false)
    h.system.setDisplays([Self.main])
    h.scheduler.runPending()
    h.system.beginDrag(mail)
    h.system.moveDrag(to: CGPoint(x: 900, y: 400), holding: 0.3)
    let held = try #require(h.frame(mail))

    h.system.setDisplays([Self.main, Self.side])
    #expect(h.frame(mail) == held, "it was taken out of the hand")
    #expect(!h.controller.parked.contains(mail))

    h.system.loseTheReleaseOfTheDrag()
    h.scheduler.runPending()
    #expect(h.system.isVisible(mail))
    #expect(!h.controller.parked.contains(mail))
    #expect(h.controller.workspaces.values.filter { $0.contains(mail) }.count == 1)
    for display in h.controller.workspaces.keys { expectWindowsMatchLayout(h, on: display) }
  }
}

/// The window leaves the screen while it is in the hand: ⌘M, ⌘H and ⌃⌘F all work with the button down.
@Suite @MainActor struct ReviewDragOfAWindowThatLeavesTests {
  enum Leaving: CaseIterable { case minimized, hidden, fullScreen }

  func set(_ leaving: Leaving, _ on: Bool, _ window: WindowID, _ h: Harness) {
    switch leaving {
    case .minimized: h.system.setMinimized(window, on)
    case .hidden: h.system.setHidden(pid: h.system.windows[window]!.snapshot.pid, on)
    case .fullScreen: h.system.setFullScreen(window, on)
    }
  }

  /// [(Safari / Notes) | Desktop], Mail floating on the Desktop, each an app of its own.
  func scene(reflow: Bool) -> (h: Harness, safari: WindowID, mail: WindowID) {
    var settings = Settings()
    settings.reflowWhileDragging = reflow
    let h = Harness(settings: settings)
    let safari = h.system.open(app: "Safari", pid: 2001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 2002, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let mail = h.system.open(app: "Mail", pid: 2003, frame: CGRect(x: 520, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(safari.rawValue) bottom")
    h.scheduler.runPending()
    return (h, safari, mail)
  }

  /// What is not on screen is under no pointer, so letting go of the button drops it nowhere. As built, a docked window
  /// was undocked, and one in full screen was remembered as floating at the size of the display.
  @Test(arguments: Leaving.allCases, [false, true]) func itIsNotDroppedAnywhere(leaving: Leaving, docked: Bool) throws {
    for reflow in [false, true] {
      let (h, safari, mail) = scene(reflow: reflow)
      let window = docked ? safari : mail
      let before = h.controller.workspaces
      let size = try #require(h.frame(window)).size
      h.system.beginDrag(window)
      h.system.moveDrag(to: CGPoint(x: 1000, y: 500), holding: 0.3)  // over the Desktop
      set(leaving, true, window, h)
      h.system.endDrag()
      h.scheduler.runPending()
      #expect(h.controller.workspaces == before, "\(leaving), reflow \(reflow)")
      #expect(h.overlays.preview == nil)
      #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("drag") })

      set(leaving, false, window, h)
      h.scheduler.runPending()
      #expect(h.controller.workspaces == before, "\(leaving), reflow \(reflow)")
      #expect(h.frame(window)?.size == size, "\(leaving), reflow \(reflow)")
      #expect(h.system.isVisible(window))
      expectWindowsMatchLayout(h, on: h.display)
    }
  }

  /// ⌃→ with a window in the hand takes it along. Its app's list of windows can be behind, so that for a moment it is
  /// reported on the Space that went away; it is in the hand all the same, and is dropped where it is let go.
  @Test(arguments: [false, true]) func carriedToAnotherSpaceItIsDroppedThere(docked: Bool) throws {
    let (h, safari, mail) = scene(reflow: false)
    let window = docked ? safari : mail
    h.system.beginDrag(window)
    h.system.moveDrag(to: CGPoint(x: 1000, y: 500), holding: 0.3)  // over the Desktop
    for other in h.system.allWindows() { h.system.setOnActiveSpace(other.id, false) }
    h.system.moveDrag(to: CGPoint(x: 1040, y: 520), holding: 0.3)
    h.system.endDrag()
    h.system.setOnActiveSpace(window, true)
    h.scheduler.runPending()
    #expect(h.workspace.isFloating(window))
    #expect(h.workspace.floating[window] == h.frame(window))
    #expect(try #require(h.frame(window)).insetBy(dx: -1, dy: -1).contains(CGPoint(x: 1040, y: 520)), "under the pointer")
  }
}

/// What live reflow asks of other apps. Every move is several round trips to another process while the main thread,
/// and with it the drag, waits (`BudgetTests`).
@Suite @MainActor struct ReviewReflowBudgetTests {
  /// Six docked windows in a row and two columns, one floating, and at the end of the row a column for the Desktop: where the
  /// window in the hand is taken in these tests, for the others to close up.
  func scene() -> (h: Harness, docked: [WindowID]) {
    var settings = Settings.withDesktopColumn
    settings.reflowWhileDragging = true
    let h = Harness(settings: settings)
    let windows = (0..<7).map { h.system.open(app: "App\($0)", frame: CGRect(x: 500 + $0 * 10, y: 300, width: 300, height: 200)) }
    h.start()
    for window in windows[0..<4] { h.run("dock \(window.rawValue) left") }
    h.run("dock \(windows[4].rawValue) beside \(windows[0].rawValue) bottom")
    h.run("dock \(windows[5].rawValue) beside \(windows[1].rawValue) bottom")
    h.scheduler.runPending()
    return (h, Array(windows[0..<6]))
  }

  /// The moves `body` caused: how many, how many of a window that had been moved already, how many that changed nothing.
  func moves(_ h: Harness, _ body: () -> Void) -> (all: Int, repeated: Int, idle: Int) {
    let start = h.system.moveLog.count
    body()
    let budget = Budget.tally(h.system.moveLog[start...])
    return (budget.moves, budget.repeatMoves, budget.idleMoves)
  }

  @Test func onlyAChangeOfTargetMovesAnything() throws {
    let (h, docked) = scene()
    let desktop = try #require(h.layout?.desktopFrame)
    h.system.beginDrag(docked[0])
    let leaving = moves(h) { h.system.moveDrag(to: desktop.center, holding: 0.3) }
    #expect(leaving.all > 0 && leaving.repeated == 0 && leaving.idle == 0, "\(leaving)")
    // A hand is never still. Two hundred reports of the pointer on the same target ask nothing of anybody.
    let resting = moves(h) {
      for step in 0..<200 { h.system.moveDrag(to: CGPoint(x: desktop.midX + CGFloat(step % 9), y: desktop.midY + CGFloat(step % 7))) }
    }
    #expect(resting.all == 0, "\(resting)")
    let updates = h.overlays.updateLog.count
    h.system.moveDrag(to: CGPoint(x: desktop.midX + 20, y: desktop.midY), holding: 1)
    #expect(h.overlays.updateLog.count == updates)
    h.system.endDrag()
  }

  /// Sweeping over windows without stopping moves nothing either: a target that has not been held opens no gap.
  @Test func aSweepOverTheOtherWindowsMovesNothing() throws {
    let (h, docked) = scene()
    let desktop = try #require(h.layout?.desktopFrame)
    h.system.beginDrag(docked[0])
    h.system.moveDrag(to: desktop.center, holding: 0.3)
    let sweep = moves(h) {
      // Along the bottom, past its own old slot at the top, which opens at once.
      for x in stride(from: desktop.midX, to: 20, by: -15) { h.system.moveDrag(to: CGPoint(x: x, y: 700), holding: 0.01) }
    }
    #expect(sweep.all == 0, "\(sweep)")
    h.system.loseTheReleaseOfTheDrag()
  }

  /// Each new arrangement is reached in one move per window that has to move, and so is the way back.
  @Test func everyTrialAndTheEndMoveEachWindowOnce() throws {
    let (h, docked) = scene()
    let before = Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
    let desktop = try #require(h.layout?.desktopFrame)
    h.system.beginDrag(docked[0])
    var points = [desktop.center, CGPoint(x: 3, y: 450), desktop.center, CGPoint(x: 720, y: 897)]
    points.append(CGPoint(x: try #require(h.frame(docked[3])).midX, y: 60))
    for point in points {
      // Two arrangements: the last gap closes when the pointer leaves it, the next opens when the hold is over.
      for trial in [moves(h) { h.system.moveDrag(to: point) }, moves(h) { h.system.holdDrag(for: 0.3) }] {
        #expect(trial.repeated == 0 && trial.idle == 0, "\(point): \(trial)")
      }
    }
    let end = moves(h) { h.system.loseTheReleaseOfTheDrag() }
    #expect(end.repeated == 0 && end.idle == 0, "\(end)")
    #expect(Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) }) == before)
  }
}

/// Commands that name the window in the hand: with the keyboard on it, every shortcut does.
@Suite @MainActor struct ReviewCommandsOnTheDraggedWindowTests {
  /// `pin` floats a docked window first, at its own size where its slot was. In the hand it stays there, like one
  /// that `float` undocks, and takes that size when it is let go.
  @Test(arguments: [false, true]) func pinningADockedWindowInTheHandLeavesItThere(reflow: Bool) {
    let s = DragScene { $0.reflowWhileDragging = reflow }
    let gap = s.inTheGap
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: gap, holding: 0.3)
    let held = s.frame(s.a)
    s.h.run("pin \(s.a.rawValue)")
    #expect(s.frame(s.a) == held, "it was taken out of the hand")
    s.h.system.moveDrag(to: CGPoint(x: gap.x, y: gap.y + 40), holding: 0.3)
    s.h.system.endDrag()
    #expect(s.h.workspace.isPinned(s.a))
    #expect(s.frame(s.a).size == CGSize(width: 600, height: 400), "the size it floated at before it was docked")
    #expect(s.frame(s.a).insetBy(dx: -1, dy: -1).contains(s.h.system.cursor), "under the pointer")
    #expect(s.h.workspace.floating[s.a] == s.frame(s.a))
    s.expectNothingLeftBehind()
  }

  /// A window Arbor starts to arrange is brought into view if most of it is off the screen. Not out of the hand: carried
  /// along the bottom of the screen, most of any window is.
  @Test(arguments: [false, true]) func aWindowTakenOnWhileInTheHandIsNotFetched(docked: Bool) {
    let s = DragScene()
    let window = docked ? s.a : s.c
    s.h.system.beginDrag(window)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 880), holding: 0.3)
    let held = s.frame(window)
    let app = s.h.system.windows[window]!.snapshot.bundleID!
    s.h.run("exclude \(app)")
    s.h.run("include \(app)")
    #expect(s.frame(window) == held, "it was taken out of the hand")
    s.h.system.moveDrag(to: s.inTheGap, holding: 0.3)
    s.h.system.endDrag()
    #expect(s.h.workspace.isFloating(window))
    #expect(s.h.system.isVisible(window))
    s.expectNothingLeftBehind()
  }
}
