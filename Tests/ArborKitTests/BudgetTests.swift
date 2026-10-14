import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What everyday commands may ask of the window system. On a Mac every move and focus is several round
/// trips to another process while the main thread waits, so these counts are the latency people feel. The
/// cases are `BenchmarkCase.all`, which `arbor-sim bench` prints.
@Suite @MainActor struct BudgetTests {
  nonisolated static let sizes = [4, 10, 30]

  /// Work that changes nothing and is still asked for, and why it is still here. The test fails when an entry
  /// no longer wastes anything, so the list cannot outlive its reasons.
  static let knownWaste: [String: String] = [
    "zoom": "the framed window is focused although it has the focus",
    "zoom again": "the same",
    "grid: zoom": "the same",
    "dock focused": "the docked window is focused although it has the focus",
    "shutdown": "windows that are in place are placed again",
    "quit app": "a layout per window that closes, so a window that stays can move more than once",
  ]

  @Test(arguments: sizes) func nothingIsDoneTwiceOrForNothing(windows: Int) {
    for benchmark in BenchmarkCase.all where Self.knownWaste[benchmark.name] == nil {
      let budget = benchmark.run(windows: windows).budget
      #expect(budget.waste == 0, "\(benchmark.name) with \(windows) windows: \(budget)")
    }
  }

  @Test func theListOfKnownWasteIsCurrent() {
    for name in Self.knownWaste.keys.sorted() {
      let budgets = Self.sizes.map { BenchmarkCase.named(name).run(windows: $0).budget }
      #expect(budgets.contains { $0.waste > 0 }, "\(name) wastes nothing any more; take it off the list: \(budgets)")
    }
  }

  /// `stackedWindows`, `windowsFrontToBack` and `existingWindowIDs` each have the window server list every window on the
  /// Mac, Arbor's or not: milliseconds, on the main thread. The stage needs one list for a motion. Nothing needs two.
  @Test(arguments: sizes) func aCommandHasTheWindowServerListItsWindowsOnceAtMost(windows: Int) {
    // An app that quits is a layout, and a motion, per window that closes. A start asks what still exists, twice, and ends with
    // the focused window in view: on a big desk that window is inside a tile, so the view goes to it, which is a motion.
    let more = ["quit app": 2, "restart": 3]
    for benchmark in BenchmarkCase.all {
      let budget = benchmark.run(windows: windows).budget
      #expect(budget.windowLists <= more[benchmark.name, default: 1], "\(benchmark.name) with \(windows) windows: \(budget)")
    }
    for name in ["seam step", "grid: seam step", "focus in view", "put back", "relayout", "echoes", "zoom again"] {
      #expect(BenchmarkCase.named(name).run(windows: windows).budget.windowLists == 0, "\(name)")
    }
  }

  @Test(arguments: sizes) func commandsThatChangeNothingMoveAndSaveNothing(windows: Int) {
    for name in ["zoom again", "show-all again", "relayout", "displays: no change"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.moves == 0 && budget.saves == 0, "\(name) with \(windows) windows: \(budget)")
      #expect(budget.overlayUpdates == budget.idleOverlayUpdates, "\(name) with \(windows) windows: \(budget)")
    }
  }

  /// A camera move touches each window that comes into or goes out of view once, and nothing else.
  @Test(arguments: sizes) func aCameraMoveTouchesEachWindowOnce(windows: Int) {
    for name in ["grid: zoom", "grid: back"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.moves == windows && budget.idleMoves == 0 && budget.repeatMoves == 0, "\(name): \(budget)")
      #expect(budget.overlayUpdates == 1 && budget.saves == 1, "\(name): \(budget)")
    }
  }

  /// Only what borders the change moves, however many windows there are.
  @Test(arguments: sizes) func aSeamStepMovesOnlyWhatBordersTheSeam(windows: Int) {
    let step = BenchmarkCase.named("seam step").run(windows: windows).budget
    #expect(step.moves - step.questions == 2, "\(step)")
    // They grow further than they have been seen to, so each is asked first whether it can.
    let minimize = BenchmarkCase.named("minimize").run(windows: windows).budget
    #expect(minimize.moves - minimize.questions == 2, "\(minimize)")
    #expect(BenchmarkCase.named("put back").run(windows: windows).budget.moves == 1)
  }

  /// A change on one display leaves the windows and overlays of the other alone.
  @Test(arguments: sizes) func aChangeOnOneDisplayLeavesTheOtherAlone(windows: Int) {
    let budget = BenchmarkCase.named("displays: Dock grows").run(windows: windows).budget
    #expect(budget.moves - budget.questions == 3 && budget.overlayUpdates - budget.idleOverlayUpdates == 1, "\(budget)")
  }

  @Test func terminalsThatRoundTheirSizeAreNotAskedAgain() {
    let w = Workload(windows: 6, grid: true)
    let h = w.harness
    for window in w.docked { h.system.setSizeStep(window, CGSize(width: 7, height: 15)) }
    h.run("zoom \(w.docked[0].rawValue)")
    h.run("back")
    let rounded = h.frame(w.docked[1])!
    #expect(rounded.size != h.layout!.windowFrames[w.docked[1]]!.size, "the fake rounds")
    #expect(h.measure { h.run("show-all") }.moves == 0)
    #expect(h.measure { h.system.close(w.docked[5]) }.idleMoves == 0)

    // It is still put back when something else moves it.
    h.system.userMove(w.docked[1], to: rounded.offsetBy(dx: 60, dy: 40))
    _ = h.measure {}
    #expect(h.frame(w.docked[1]) == rounded)
  }

  /// Finding out that a window will not shrink costs one move too many, once.
  @Test func aWindowThatRefusesItsSlotIsAskedOnce() {
    let h = Harness()
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    let stubborn = h.system.open(
      app: "Settings", frame: CGRect(x: 800, y: 100, width: 600, height: 700),
      minimumSize: CGSize(width: 600, height: 700))
    h.start()
    // Half the display is room enough for it to float in, so nothing is known about it yet.
    h.run("dock \(a.rawValue) left")
    let first = h.measure { h.run("dock \(stubborn.rawValue) beside \(a.rawValue) bottom") }
    #expect(h.layout!.tiles.contains { $0.windows == [stubborn] })
    #expect(first.repeatMoves <= 1 && first.idleMoves == 0, "into the slot, then out of view, at most: \(first)")
    #expect(first.overlayUpdates - first.idleOverlayUpdates <= 2, "the layout, and the focus ring: \(first)")
    // From now on Arbor knows.
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    let back = h.measure { h.run("back") }
    #expect(back.waste == 0 && !h.system.moveLog.suffix(back.moves).contains { $0.window == stubborn }, "\(back)")
  }

  /// An app with five windows hides and shows: each is one happening, so one layout (`scheduleSpaceRelayout`).
  @Test func anAppWithManyWindowsHidesAndShowsInOneLayout() {
    let h = Harness(displays: [Workload.largeDisplay])
    let mine = (0..<5).map { _ in h.system.open(app: "Editor", pid: 2001) }
    let others = (0..<4).map { h.system.open(app: "Other\($0)", pid: Int32(2100 + $0)) }
    h.start()
    h.run("arrange")
    let arranged = others.map { h.frame($0)! }
    // Another app has the focus. Hiding the focused one also moves the focus and the ring, which is not counted here.
    h.system.userFocus(others[0])

    var layouts = 0
    h.controller.observe { if case .layout = $0 { layouts += 1 } }
    let hide = h.measure { h.system.setHidden(pid: 2001, true) }
    #expect(layouts == 1 && hide.repeatMoves == 0 && hide.overlayUpdates == 1, "\(hide)")
    #expect(hide.moves - hide.questions <= others.count, "only the windows that stay move: \(hide)")
    expectWindowsMatchLayout(h, on: h.display)

    layouts = 0
    let show = h.measure { h.system.setHidden(pid: 2001, false) }
    #expect(layouts == 1 && show.repeatMoves == 0, "\(show)")
    #expect(others.map { h.frame($0)! } == arranged)

    // Quitting is a layout per window: what follows each (who gets the keyboard, where the camera goes) looks at it.
    h.system.quit(pid: 2001)
    #expect(h.workspace.tree.allWindows.sorted() == others)
    #expect(mine.allSatisfy { h.controller.windows[$0] == nil })
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func theStateIsWrittenOnlyWhenItChanged() {
    let w = Workload(windows: 4)
    let h = w.harness
    #expect(h.measure { h.run("show-all") }.saves == 0)
    #expect(h.measure { h.run("zoom \(w.docked[0].rawValue)") }.saves == 1)
    #expect(h.measure { h.controller.saveNow() }.saves == 0)
    // What is saved is what a new run finds.
    #expect(h.store.saved?.workspaces[h.display]?.camera == h.workspace.camera)
  }

  /// Resuming starts from memory; what is on disk is still what was saved last. The pause itself is on
  /// disk too, so that it outlives a crash: one write going in, one coming out.
  @Test func pausingAndResumingSavesWhatChangedAndNoMore() {
    let w = Workload(windows: 4)
    let h = w.harness
    h.run("zoom \(w.docked[0].rawValue)")
    _ = h.measure {}
    let round = h.measure {
      h.run("pause")
      h.run("resume")
    }
    #expect(round.saves == 2, "\(round)")
    // The same with an end, which `measure` runs into.
    #expect(h.measure { h.run("pause 5") }.saves == 2)
    #expect(h.controller.isRunning)
    #expect(h.measure { h.run("show-all") }.saves == 1)
    #expect(h.store.saved?.workspaces[h.display]?.camera == h.workspace.camera)
  }
}

/// Arbor's own work, timed. The limits are some twenty times what a debug build needs on a slow machine: they
/// are there to catch work that grows with the square or the cube of the number of windows, not to measure.
/// `arbor-sim bench` (release) gives numbers worth quoting.
@Suite(.serialized) @MainActor struct TimingTests {
  @Test(arguments: [10, 50, 150]) func everyCommandIsQuickOnABigDesk(windows: Int) {
    for benchmark in BenchmarkCase.all {
      let result = benchmark.run(windows: windows)
      #expect(result.seconds < 0.5, "\(benchmark.name) with \(windows) windows took \(result.seconds) s")
    }
  }

  @Test(arguments: [10, 50, 150]) func thePurePartsAreQuickOnABigTree(windows: Int) {
    for result in CoreBenchmark.run(windows: windows, repetitions: 2) {
      #expect(result.seconds < 0.25, "\(result.name) with \(windows) windows took \(result.seconds) s")
    }
  }
}
