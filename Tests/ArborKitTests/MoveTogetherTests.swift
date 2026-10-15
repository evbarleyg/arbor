import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `moveTogether` foretells the `setFrame` calls of a layout, so that apps work side by side. It may change what the
/// calls cost and nothing else.
@Suite @MainActor struct MoveTogetherTests {
  @Test(arguments: [4, 10, 30]) func aCameraMoveMakesNoDockedWindowWaitForAnother(windows: Int) {
    for name in ["grid: zoom", "grid: back"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.moves == windows && budget.movesAlone == 0, "\(name) with \(windows) windows: \(budget)")
    }
    // On a desk with floating windows, those follow the Desktop in a breath of their own. A single move needs no company, nor
    // does a single question (whether the window can grow as far as it has never been).
    for name in ["zoom", "back", "show-all", "zoom group", "neighbor", "focus out of view"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.movesAlone <= 1 + min(budget.questions, 1), "\(name) with \(windows) windows: \(budget)")
    }
  }

  @Test(arguments: [4, 10, 30]) func nothingForetoldGoesUnclaimed(windows: Int) {
    for benchmark in BenchmarkCase.all {
      let budget = benchmark.run(windows: windows).budget
      #expect(budget.unclaimedMoves == 0, "\(benchmark.name) with \(windows) windows: \(budget)")
    }
  }

  /// With `shrinkOutOfView` a window goes out of view at another size than it has, docked or floating. A forecast at the size
  /// it has would be a move that nobody asks for: the window would go to the corner twice, large and then small.
  @Test(arguments: [4, 10, 30]) func nothingForetoldGoesUnclaimedWhereWindowsShrinkOutOfView(windows: Int) {
    var settings = Settings()
    settings.shrinkOutOfView = true
    let desk = Workload(windows: windows, settings: settings)
    let h = desk.harness
    for command in ["zoom \(desk.groups[0][0].rawValue)", "back", "zoom-node \(desk.node(ofGroup: 0).rawValue)", "show-all"] {
      let budget = h.measure { h.run(command) }
      #expect(budget.unclaimedMoves == 0 && budget.repeatMoves == 0, "\(command) with \(windows) windows: \(budget)")
      #expect(budget.moves > 0, "\(command) moves something, or this says nothing")
    }
  }

  /// Floating windows are placed last, after the rounds in which a window that refuses its slot has the layout reckoned again, and
  /// the Desktop may be elsewhere by then. Foretold from the layout as it was first reckoned, they went where the final plan never
  /// sent them: twice on their way at best, and left there at worst, if the final plan had nothing to ask of them.
  @Test func aLayoutReckonedAgainSendsNoFloatingWindowAnywhereTwice() throws {
    func desk(ignoring: Bool) -> (Harness, floating: [WindowID], stubborn: WindowID) {
      let h = Harness()
      h.system.ignoresMoveTogether = ignoring
      let a = h.system.open(app: "A")
      let floating = (0..<3).map {
        h.system.open(app: "Note\($0)", frame: CGRect(x: 760 + $0 * 60, y: 120 + $0 * 60, width: 300, height: 240))
      }
      // Half the display is room enough for it to float in, so nothing is known about it until it is docked.
      let stubborn = h.system.open(
        app: "Settings", frame: CGRect(x: 800, y: 100, width: 600, height: 700), minimumSize: CGSize(width: 600, height: 700))
      h.start()
      h.run("dock \(a.rawValue) left")
      return (h, floating, stubborn)
    }
    let (h, floating, stubborn) = desk(ignoring: false)
    let log = h.system.moveLog.count
    let budget = h.measure { h.run("dock \(stubborn.rawValue) right") }
    #expect(h.system.moveLog[log...].filter { $0.window == stubborn }.count > 1, "it refuses, or this says nothing: \(budget)")
    for window in floating {
      #expect(h.system.moveLog[log...].filter { $0.window == window }.count <= 1, "\(window): \(budget)")
    }
    #expect(budget.unclaimedMoves == 0, "\(budget)")
    // And they are where a window system that ignores the hint has them.
    let (plain, _, _) = desk(ignoring: true)
    plain.run("dock \(stubborn.rawValue) right")
    for window in floating { #expect(h.frame(window) == plain.frame(window), "\(window)") }
  }

  /// While a drop is only tried out (`reflowWhileDragging`), the trial and its layout are lent to `placeFloatingWindows` in place of
  /// the real ones. A forecast begins with the window system reporting what was left of the one before, and whoever heard that
  /// then would lay out, or save, a drop that was never made. So a trial foretells nothing, and what was left waits.
  @Test func aDropThatIsOnlyTriedOutForetellsNothing() throws {
    var settings = Settings()
    settings.reflowWhileDragging = true
    let h = Harness(settings: settings)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    let docked = h.system.open(app: "A")
    let floating = (0..<3).map {
      h.system.open(app: "Note\($0)", frame: CGRect(x: 760 + $0 * 60, y: 120 + $0 * 60, width: 300, height: 240))
    }
    let carried = h.system.open(app: "B", frame: CGRect(x: 800, y: 500, width: 400, height: 300))
    h.start()
    h.run("dock \(docked.rawValue) left")
    // Something is left of a forecast, as if one had been wrong.
    let elsewhere = try #require(h.frame(floating[0])).offsetBy(dx: 30, dy: 20)
    h.system.moveTogether([(floating[0], elsewhere)])
    let believed = h.controller.windows[floating[0]]?.frame

    let log = h.system.moveLog.count
    h.system.beginDrag(carried)
    h.system.moveDrag(to: CGPoint(x: h.system.displayList[0].frame.maxX - 2, y: 450), holding: 1)
    let moves = h.system.moveLog[log...].filter { floating.contains($0.window) }
    #expect(moves.count > 1, "the trial pushes floating windows aside, or this says nothing: \(moves)")
    #expect(!moves.contains { $0.together }, "\(moves)")
    #expect(h.system.forecastsNobodyClaimed.filter { $0 == floating[0] }.count <= 1 && believed != elsewhere)
    h.system.endDrag()
    h.scheduler.runPending()
    expectWindowsMatchLayout(h)
  }

  /// A long walk through everything a desk goes through, once with a window system that takes the hint and once with
  /// one that ignores it. After every step both desks must be the same.
  @Test func takingTheHintChangesNothingButTheCost() {
    func makeDesk(ignoring: Bool) -> (Harness, [WindowID]) {
      let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
      h.system.ignoresMoveTogether = ignoring
      var ids: [WindowID] = []
      for index in 0..<9 {
        ids.append(
          h.system.open(
            app: "App\(index % 4)", pid: Int32(2000 + index % 4),
            frame: CGRect(x: 150 + index * 45, y: 90 + index * 35, width: 600, height: 400),
            // One that will not shrink, one that cannot grow, one that rounds.
            minimumSize: index == 2 ? CGSize(width: 700, height: 500) : .zero))
      }
      h.system.setMaximumSize(ids[4], CGSize(width: 300, height: 220))
      h.system.setSizeStep(ids[6], CGSize(width: 7, height: 15))
      h.start()
      return (h, ids)
    }
    let (a, ids) = makeDesk(ignoring: false)
    let (b, _) = makeDesk(ignoring: true)
    let w = ids.map(\.rawValue)

    let steps: [(String, (Harness) -> Void)] = [
      ("dock 0", { $0.run("dock \(w[0]) left") }), ("dock 1", { $0.run("dock \(w[1]) right") }),
      ("dock the stubborn one", { $0.run("dock \(w[2]) beside \(w[0]) bottom") }),
      ("dock 3", { $0.run("dock \(w[3]) beside \(w[1]) bottom") }),
      ("dock the small one", { $0.run("dock \(w[4]) beside \(w[3]) right") }),
      ("dock the terminal", { $0.run("dock \(w[6]) beside \(w[0]) right") }),
      ("zoom", { $0.run("zoom \(w[1])") }), ("back", { $0.run("back") }), ("zoom the tile", { $0.run("zoom \(w[2])") }),
      ("show all", { $0.run("show-all") }), ("desktop", { $0.run("desktop") }), ("home", { $0.run("home") }),
      ("float", { $0.run("float \(w[3])") }), ("resize", { $0.run("resize \(w[0]) right 60") }),
      ("minimize", { $0.system.setMinimized(ids[1], true) }), ("restore", { $0.system.setMinimized(ids[1], false) }),
      ("hide an app", { $0.system.setHidden(pid: 2000, true) }), ("show it", { $0.system.setHidden(pid: 2000, false) }),
      ("someone moves a docked window", { $0.system.userMove(ids[0], to: CGRect(x: 400, y: 300, width: 500, height: 300)) }),
      ("another Space", { h in for id in ids.prefix(3) { h.system.setOnActiveSpace(id, false) } }),
      ("and back", { h in for id in ids.prefix(3) { h.system.setOnActiveSpace(id, true) } }),
      ("unplug", { $0.system.setDisplays([FakeWindowSystem.standardDisplay]) }),
      ("plug in", { $0.system.setDisplays([FakeWindowSystem.standardDisplay, Workload.secondDisplay]) }),
      ("arrange", { $0.run("arrange") }), ("zoom again", { $0.run("zoom \(w[5])") }), ("close it", { $0.system.close(ids[5]) }),
      ("quit an app", { $0.system.quit(pid: 2001) }), ("relayout", { $0.run("relayout") }), ("pause", { $0.run("pause") }),
      ("resume", { $0.run("resume") }), ("float all", { $0.run("float-all") }), ("stop", { $0.controller.shutdown() }),
    ]
    for (name, step) in steps {
      for h in [a, b] {
        step(h)
        for _ in 0..<3 { h.scheduler.runPending() }
      }
      #expect(a.system.allWindows() == b.system.allWindows(), "windows differ after: \(name)")
      #expect(a.controller.windows == b.controller.windows, "what Arbor believes differs after: \(name)")
      #expect(a.controller.workspaces == b.controller.workspaces && a.controller.parked == b.controller.parked, "\(name)")
      #expect(a.controller.layouts == b.controller.layouts, "layouts differ after: \(name)")
      // What the last forecast left, and what an earlier one had left when the next came: a layout makes two.
      #expect(a.system.answersAhead.isEmpty && a.system.forecastsNobodyClaimed.isEmpty, "unclaimed after: \(name)")
      // What Arbor believes is what is so.
      for window in a.system.allWindows() where a.controller.isRunning {
        #expect(a.controller.windows[window.id]?.frame == window.frame, "\(window.id) after: \(name)")
      }
    }
    #expect(a.system.moveLog.contains { $0.together } && !b.system.moveLog.contains { $0.together })
  }

  /// The same where nobody thought of looking: random walks (docs/TESTING.md, "Chaos") through pins, summoned windows, guests, drags
  /// that try out a drop, apps that hang or refuse, every setting. One Mac takes the hint, its twin ignores it, and both are done
  /// the same things to. `ARBOR_CHAOS_SEEDS`, `ARBOR_CHAOS_FIRST` and `ARBOR_CHAOS_STEPS` make it a hunt, or one walk, as for `ChaosTests`.
  ///
  /// Unlike an unknown script of the chaos test, a failure here fails `make check`: thousands of walks found none, and what it finds is
  /// what `movesInSight` was not told.
  @Test func onRandomWalksTakingTheHintChangesNothingEither() {
    func environment(_ name: String) -> Int? { ProcessInfo.processInfo.environment[name].flatMap { Int($0) } }
    let first = UInt64(environment("ARBOR_CHAOS_FIRST") ?? 1)
    var foretold = (docked: 0, floating: 0)
    var failed = false
    for seed in first..<(first + UInt64(environment("ARBOR_CHAOS_SEEDS") ?? 40)) {
      Log.silenced {
        let (a, b) = (ChaosRunner(), ChaosRunner())
        b.system.ignoresMoveTogether = true
        var generator = ChaosGenerator(seed: seed)
        for _ in 0..<(environment("ARBOR_CHAOS_STEPS") ?? 200) {
          let (action, log) = (generator.next(a), a.system.moveLog.count)
          let unclaimed = a.step(action).filter { $0.rule == "forecast" }
          _ = b.step(action)
          let same =
            a.system.allWindows() == b.system.allWindows() && a.controller.windows == b.controller.windows
            && a.controller.workspaces == b.controller.workspaces && a.controller.parked == b.controller.parked
            && a.controller.layouts == b.controller.layouts
          guard same, unclaimed.isEmpty else {
            let script = a.script.map(\.text).joined(separator: "\n")
            Issue.record("seed \(seed): \(same ? "\(unclaimed)" : "the twins differ") after:\n\(script)")
            failed = true
            return
          }
          for move in a.system.moveLog[log...] where move.together {
            if a.controller.workspaces.values.contains(where: { $0.isFloating(move.window) }) {
              foretold.floating += 1
            } else {
              foretold.docked += 1
            }
          }
        }
      }
    }
    // Of the walks as they come. A walk cut short, or a few chosen ones, foretell what they foretell.
    if !failed, ["ARBOR_CHAOS_FIRST", "ARBOR_CHAOS_SEEDS", "ARBOR_CHAOS_STEPS"].allSatisfy({ environment($0) == nil }) {
      #expect(foretold.docked > 50 && foretold.floating > 50, "little was foretold, so this says little: \(foretold)")
    }
  }

  /// If a forecast is ever wrong, the window system says where the window went, so Arbor's picture stays true.
  @Test func anAnswerNobodyAsksForIsReportedAtTheNextForecast() {
    let h = Harness()
    let a = h.system.open(app: "A")
    h.start()
    let elsewhere = CGRect(x: 40, y: 60, width: 300, height: 200)
    h.system.moveTogether([(a, elsewhere)])
    #expect(h.frame(a) == elsewhere && h.controller.windows[a]?.frame != elsewhere)
    h.system.moveTogether([])
    #expect(h.controller.windows[a]?.frame == elsewhere && h.system.answersAhead.isEmpty)
  }

  @Test func aCallWithAnotherFrameMovesTheWindowAsAlways() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", minimumSize: CGSize(width: 400, height: 300))
    let foretold = CGRect(x: 10, y: 40, width: 200, height: 100)
    system.moveTogether([(a, foretold)])
    #expect(system.setFrame(foretold, of: a) == CGRect(x: 10, y: 40, width: 400, height: 300), "the answer that was kept")
    #expect(system.moveLog.count == 1)
    #expect(system.setFrame(foretold, of: a) != nil && system.moveLog.count == 2, "kept for one call only")
    system.moveTogether([(a, foretold)])
    let other = CGRect(x: 500, y: 40, width: 600, height: 400)
    #expect(system.setFrame(other, of: a) == other && system.frame(of: a) == other)
    #expect(system.answersAhead.isEmpty)
  }
}
