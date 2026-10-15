import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// `moveTogether` foretells the `setFrame` calls of a layout, so that apps work side by side. It may change what the
/// calls cost and nothing else.
@Suite @MainActor struct MoveTogetherTests {
  @Test(arguments: [4, 10, 30]) func aCameraMoveMakesNoDockedWindowWaitForAnother(windows: Int) {
    for name in ["grid: zoom", "grid: back"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.moves == windows && budget.movesAlone == 0, "\(name) with \(windows) windows: \(budget)")
    }
    // On a desk with floating windows, those follow the Desktop one at a time. A single move needs no company.
    let floating = Workload(windows: windows).floating.count
    for name in ["zoom", "back", "show-all", "zoom group", "neighbor", "focus out of view"] {
      let budget = BenchmarkCase.named(name).run(windows: windows).budget
      #expect(budget.movesAlone <= floating + 1, "\(name) with \(windows) windows: \(budget)")
    }
  }

  @Test(arguments: [4, 10, 30]) func nothingForetoldGoesUnclaimed(windows: Int) {
    for benchmark in BenchmarkCase.all {
      let budget = benchmark.run(windows: windows).budget
      #expect(budget.unclaimedMoves == 0, "\(benchmark.name) with \(windows) windows: \(budget)")
    }
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
      #expect(a.system.answersAhead.isEmpty, "unclaimed after: \(name)")
      // What Arbor believes is what is so.
      for window in a.system.allWindows() where a.controller.isRunning {
        #expect(a.controller.windows[window.id]?.frame == window.frame, "\(window.id) after: \(name)")
      }
    }
    #expect(a.system.moveLog.contains { $0.together } && !b.system.moveLog.contains { $0.together })
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

/// An app that takes longer over a move than Arbor waits (`FakeWindowSystem.slowApps`).
@Suite @MainActor struct SlowAppTests {
  func makeDesk() -> (Harness, slow: WindowID, other: WindowID) {
    let h = Harness()
    let slow = h.system.open(app: "Xcode", pid: 3001)
    let other = h.system.open(app: "Notes", pid: 3002)
    h.start()
    h.run("dock \(slow.rawValue) left")
    h.run("dock \(other.rawValue) right")
    h.system.userFocus(other)
    return (h, slow, other)
  }

  func isInView(_ window: WindowID, _ h: Harness) -> Bool {
    h.system.frame(of: window)!.fractionInside(FakeWindowSystem.standardDisplay.frame) > 0.9
  }

  @Test func itsWindowsFollowWhenItIsDone() {
    let (h, slow, other) = makeDesk()
    h.system.slowApps = [3001]
    h.run("zoom \(other.rawValue)")
    #expect(isInView(slow, h), "still on its way out")
    h.system.slowAppsFinish()
    h.scheduler.runPending()
    #expect(!isInView(slow, h))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// The window that grows is the likeliest to be slow, and the one the keyboard is meant for.
  @Test func theKeyboardFollowsIntoTheWindowThatWasFramed() {
    let (h, slow, _) = makeDesk()
    h.system.slowApps = [3001]
    h.run("zoom \(slow.rawValue)")
    h.system.slowAppsFinish()
    h.scheduler.runPending()
    #expect(h.system.focused == slow)
    #expect(h.frame(slow) == h.layout!.windowFrames[slow])
  }

  /// `zoom` and `quit` in one breath: the window is still on its way out of view when Arbor lets go of everything.
  @Test func quittingRightAfterACameraMoveLeavesNothingOutOfView() {
    let (h, slow, other) = makeDesk()
    h.system.slowApps = [3001]
    h.run("zoom \(other.rawValue)")
    h.controller.shutdown()
    #expect(isInView(slow, h) && isInView(other, h))
  }

  /// So slow that it is not done when Arbor has waited for it: the window would arrive out of view with Arbor gone, while
  /// everybody believed it in view.
  @Test(arguments: [false, true], [false, true])
  func aMoveOutOfViewThatOutlastsTheWaitIsFetchedBack(paused: Bool, floating: Bool) {
    let (h, slow, other) = makeDesk()
    // A docked window is asked to go somewhere at a quit in any case; a floating one that is taken to be in view is not.
    if floating { h.run("float \(slow.rawValue)") }
    h.system.slowApps = [3001]
    h.system.slowAppsOutlastTheWait = true
    h.run("zoom \(other.rawValue)")
    #expect(isInView(slow, h), "still on its way out")
    if paused { h.run("pause") } else { h.controller.shutdown() }
    h.system.slowAppsFinish()
    #expect(isInView(slow, h) && isInView(other, h))
  }

  /// While it is busy with one move the next is turned away. Nobody may count on that one.
  @Test func whatABusyAppWasAskedMeanwhileIsMadeUpForWhenItIsDone() {
    let (h, slow, other) = makeDesk()
    h.system.slowApps = [3001]
    h.run("zoom \(other.rawValue)")
    h.run("back")
    h.system.slowAppsFinish()
    h.scheduler.runPending()
    h.system.slowAppsFinish()
    h.scheduler.runPending()
    #expect(isInView(slow, h) && isInView(other, h))
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// A window that refuses its slot's width has the layout reckoned again, which Arbor learns from what the app made of the frame it
  /// was asked to take. From an app that is always late that answer never comes in time.
  ///
  /// Not to the point the same arrangement as from an app that answers in time: there the refusal is learnt within `arrange`, which shares
  /// the width out afresh; here at a later layout, which makes room. What counts is that room is made.
  @Test(arguments: [false, true]) func whatABusyAppMakesOfTheSizeIsLearntWhenItIsDone(busy: Bool) {
    do {
      let h = Harness()
      let wide = h.system.open(
        app: "Xcode", pid: 3001, frame: CGRect(x: 100, y: 100, width: 900, height: 400), minimumSize: CGSize(width: 800, height: 300))
      let second = h.system.open(app: "Notes", pid: 3002, frame: CGRect(x: 200, y: 160, width: 500, height: 400))
      let third = h.system.open(app: "Mail", pid: 3003, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
      h.start()
      if busy { h.system.slowApps = [3001] }
      h.run("arrange")
      for _ in 0..<12 {
        h.system.slowAppsFinish()
        h.scheduler.advance(by: 0.25)
      }
      let frames = [wide, second, third].map { h.system.frame(of: $0)! }
      #expect(frames[0].width == 800, "it has its way")
      for (index, frame) in frames.enumerated() {
        for other in frames.dropFirst(index + 1) { #expect(!frame.overlaps(other), "\(frame) and \(other)") }
      }
      expectWindowsMatchLayout(h, on: h.display)
    }
  }

  /// No odd timing needed, only a slow app at quit: its first window is on its way when the second is asked for.
  @Test func quittingLeavesNeitherOfASlowAppsTwoWindowsOutOfView() {
    let h = Harness()
    let first = h.system.open(app: "Xcode", pid: 3001)
    let second = h.system.open(app: "Xcode", pid: 3001)
    let other = h.system.open(app: "Notes", pid: 3002)
    h.start()
    h.run("dock \(first.rawValue) left")
    h.run("dock \(second.rawValue) left")
    h.run("dock \(other.rawValue) right")
    h.run("zoom \(other.rawValue)")
    h.scheduler.runPending()
    #expect(!isInView(first, h) && !isInView(second, h))
    h.system.slowApps = [3001]
    h.controller.shutdown()
    #expect(isInView(first, h))
    #expect(isInView(second, h))
  }

  /// In view is not enough: each goes back to where it floated, in its own size.
  @Test(arguments: [false, true]) func aSlowAppsWindowsEndWhereAQuickAppsDo(paused: Bool) {
    func quit(slow: Bool) -> [CGRect] {
      let h = Harness()
      let first = h.system.open(app: "Xcode", pid: 3001, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
      let second = h.system.open(app: "Xcode", pid: 3001, frame: CGRect(x: 200, y: 160, width: 520, height: 420))
      let other = h.system.open(app: "Notes", pid: 3002, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
      h.start()
      h.run("dock \(first.rawValue) left")
      h.run("dock \(second.rawValue) left")
      h.run("dock \(other.rawValue) right")
      // A pause leaves what is in view in the shape of its slot, and a quit during it undoes that.
      h.run(paused ? "pause" : "zoom \(other.rawValue)")
      h.scheduler.runPending()
      if slow { h.system.slowApps = [3001] }
      h.controller.shutdown()
      return [first, second, other].map { h.system.frame(of: $0)! }
    }
    #expect(quit(slow: true) == quit(slow: false))
  }
}
