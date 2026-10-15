import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The stage's log of its frames (`StageLog`) as part of a trace: nothing of it is lost on the way into the file, a replay passes it
/// over, and the judge finds in the trace where the real windows were.
@MainActor
@Suite struct StageLogTraceTests {
  private func stageLines(_ trace: Trace) -> [(t: Double, text: String)] {
    trace.entries.compactMap { entry in
      if case .raw(let text) = entry.line, StageLog.claims(text) { return (entry.t, text) }
      return nil
    }
  }

  /// Eight windows side by side and one above the other, and the stage rehearsed while a trace is recorded.
  private func record(_ body: (Harness, [WindowID]) -> Void) -> (trace: Trace, harness: Harness) {
    let h = Harness()
    h.start()
    let windows = (0..<8).map { _ in h.system.open(app: "Notes") }
    h.scheduler.advance(by: 1)
    let stage = RehearsedStage(recorder: h.recorder, scheduler: h.scheduler, overlays: h.overlays)
    h.run("trace on stage")
    body(h, windows)
    h.scheduler.advance(by: 1.5)
    h.run("trace off")
    withExtendedLifetime(stage) {}
    return (recordedTrace(h), h)
  }

  /// A drag's lines come sixty a second too, and most are thinned away. Every frame of the stage counts: the judge measures the gaps.
  @Test func theStagesLinesAreNeverThinnedAndKeepTheirTime() {
    let h = Harness()
    h.start()
    let a = h.system.open(app: "Notes")
    h.run("trace on stage")
    let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let road = StageLog.Road(a, from: StageLog.Place(frame), to: StageLog.Place(frame.offsetBy(dx: 500, dy: 0)))
    h.recorder.stage(.up(StageLog.Plan(display: h.display, frame: h.system.displays()[0].frame, duration: 0.46, roads: [road])))
    for step in 1...200 {
      h.scheduler.advance(by: 0.001)
      h.recorder.stage(.frame(h.display, [StageLog.Sample(a, frame.offsetBy(dx: CGFloat(step), dy: 0))]))
    }
    // The control: lines as close together that may be thinned.
    for _ in 1...200 {
      h.scheduler.advance(by: 0.001)
      h.recorder.raw("AXWindowMoved \(a)", thinKey: "AXWindowMoved")
    }
    h.run("trace off")
    let trace = recordedTrace(h)
    #expect(trace.entries.filter { $0.line == .raw("AXWindowMoved \(a)") }.count < 10)
    let lines = stageLines(trace)
    #expect(lines.count == 201)
    #expect(lines.allSatisfy { StageLog.Line(text: $0.text) != nil })
    // A gap of 34 ms has to be told from one of 33: the times are good to a tenth of a millisecond.
    for (earlier, later) in zip(lines, lines.dropFirst()) { #expect(abs(later.t - earlier.t - 0.001) < 0.00011) }
  }

  @Test func aRehearsedMotionOfEightWindowsPassesTheJudge() {
    let (trace, h) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 1.5)
      h.run("zoom \(windows[2].rawValue)")
    }
    #expect(h.overlays.transitions.count >= 2)
    let reading = StageLog.read(trace)
    #expect(reading.problems == [])
    #expect(reading.motions.count == 2)
    #expect(StageJudge.judge(reading.motions[0]).standIns == 8)
    let report = StageJudge.report(on: trace)
    #expect(report.ok, "\(report.lines.joined(separator: "\n"))")
    #expect(report.lines.count == 3)
    #expect(report.lines.last == "2 motions, none with findings")
    // The roads are the controller's own.
    #expect(reading.motions[1].legs[0].plan == StageLog.Line.began(h.overlays.transitions.last!, carryingOnFrom: nil).plan.map(rounded))
  }

  /// As a line holds it.
  private func rounded(_ plan: StageLog.Plan) -> StageLog.Plan { StageLog.Line(text: StageLog.Line.up(plan).text)?.plan ?? plan }

  @Test func aSecondCommandInMidMotionIsARetargetedStage() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 1.5)
      h.run("zoom \(windows[2].rawValue)")
      h.scheduler.advance(by: 0.2)
      h.run("back")
    }
    let reading = StageLog.read(trace)
    #expect(reading.motions.map(\.legs.count) == [1, 2])
    let report = StageJudge.report(on: trace)
    #expect(report.ok, "\(report.lines.joined(separator: "\n"))")
    #expect(report.lines[1].contains("retargeted 1 time"))
  }

  /// The lines are for whoever judges the motion. To a replay they are what macOS sent: nothing to deliver, nothing to compare.
  @Test func aReplaySkipsTheStagesLines() throws {
    let (trace, original) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 0.2)
      h.run("zoom \(windows[2].rawValue)")
      h.scheduler.advance(by: 1)
      h.run("back")
      // Long enough for the window server's list to have the windows where `back` put them. Sooner, Arbor takes them for swept aside
      // and raises no stage (`theWindowServersListIsBehindForAMoment`).
      h.scheduler.advance(by: 0.2)
      h.run("float \(windows[0].rawValue)")
    }
    #expect(stageLines(trace).count > 60)
    var without = trace
    without.entries.removeAll { entry in
      if case .raw = entry.line { return true }
      return false
    }
    for mode in [TraceReplayer.Mode.strict, .free] {
      let replayer = TraceReplayer(trace, mode: mode)
      let report = replayer.run()
      #expect(report.ok, "\(report.problems)")
      let plain = TraceReplayer(try Trace(text: without.text()), mode: mode).run()
      #expect(report.delivered == plain.delivered)
      #expect(report.answeredFromTrace == plain.answeredFromTrace)
      #expect(report.answeredByModel == plain.answeredByModel)
      #expect(replayer.harness.controller.workspaces == original.controller.workspaces)
      for id in original.system.windows.keys { #expect(replayer.harness.frame(id) == original.frame(id)) }
      // Nor does a replay play them again: it has no stage.
      #expect(!report.story.contains { $0.contains("stage frame") })
    }
  }

  /// Where the real windows are is in the trace: in its header, in what was reported, and in the frames windows took.
  @Test func theJudgeHoldsStandInsAgainstTheRealWindowsOfTheTrace() {
    var (trace, h) = record { h, windows in h.run("dock \(windows[0].rawValue) left") }
    let window = h.system.windows.keys.min()!
    let motion = StageLog.read(trace).motions[0]
    #expect(motion.realAtStart[window] == trace.header.windows.first { $0.id == window }?.frame)
    #expect(motion.realAtEnd[window] == h.frame(window))
    #expect(motion.realAtStart[window] != motion.realAtEnd[window])
    // The command's own lines, which the main thread wrote between two frames.
    #expect(!motion.otherLines.isEmpty)
    #expect(StageJudge.report(on: trace).ok)

    // The app takes a width of its own, 40 points short of its slot. The stand-in went to the slot, so handing over shows.
    for index in trace.entries.indices {
      guard case .setFrame(window, let asked, var result?, let took) = trace.entries[index].line else { continue }
      result.size.width -= 40
      trace.entries[index].line = .setFrame(window, asked, result: result, took: took)
    }
    trace.entries.removeAll { entry in
      if case .changed(let changed, _) = entry.line { return changed.id == window }
      return false
    }
    let report = StageJudge.report(on: trace)
    #expect(!report.ok)
    #expect(report.lines.contains("  ✘ end: at its last frame \(window) is 40 pt from where its window is (limit 2 pt)"))
  }

  @Test func aTraceWithoutMotionDoesNotPass() {
    let h = Harness()
    h.start()
    h.run("trace on still")
    h.run("state")
    h.run("trace off")
    let report = StageJudge.report(on: recordedTrace(h))
    #expect(!report.ok)
    #expect(report.lines == ["✘ no motion: no stage went up while this trace was recorded"])
  }

  // MARK: The writer

  /// What `StageSampler` on a Mac and `RehearsedStage` here both leave to it: which lines, in which order, and when none.
  @Test func theWriterLogsAMotionFromItsBeginningToItsEnd() {
    let h = Harness()
    h.start()
    let writer = StageLogWriter(recorder: h.recorder)
    var x: CGFloat = 0
    var asked = 0
    func samples() -> [StageLog.Sample] {
      asked += 1
      return [StageLog.Sample(WindowID(7), CGRect(x: x, y: 0, width: 10, height: 10))]
    }
    let item = Transition.Item(window: WindowID(7), from: CGRect(x: 0, y: 0, width: 10, height: 10), to: CGRect(x: 90, y: 0, width: 10, height: 10))
    let transition = Transition(display: h.display, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), duration: 0.46, items: [item])

    // Nobody records: nothing is asked, nothing is kept.
    #expect(!writer.isWanted)
    writer.began(transition, retargeted: false, samples: samples)
    writer.tick()
    writer.lifting()
    writer.comingDown()
    #expect(!writer.isLogging && asked == 0)

    h.run("trace on writer")
    #expect(writer.isWanted && !writer.isLogging)
    // Of a stage that went up before, there is nothing to write until it is given something new to play.
    writer.tick()
    writer.lifting()
    writer.comingDown()
    writer.began(transition, retargeted: false, samples: samples)
    #expect(writer.isLogging)
    x = 40
    writer.tick()
    writer.began(transition, retargeted: true, samples: samples)
    x = 90
    writer.tick()
    writer.lifting()
    writer.comingDown()
    #expect(!writer.isLogging)
    writer.tick()
    writer.lifting()
    writer.comingDown()
    h.run("trace off")
    #expect(
      stageLines(recordedTrace(h)).map(\.text) == [
        "stage up dmain 0,0,1440,900 0.46 w7 0,0,10,10,1 90,0,10,10,1", "stage frame dmain w7 0,0,10,10,1", "stage frame dmain w7 40,0,10,10,1",
        "stage retargeted dmain 0,0,1440,900 0.46 w7 40,0,10,10,1 90,0,10,10,1", "stage frame dmain w7 40,0,10,10,1",
        "stage frame dmain w7 90,0,10,10,1", "stage lift dmain", "stage frame dmain w7 90,0,10,10,1", "stage down dmain",
      ])

    // The trace ends in mid-motion: the writer lets go of whatever it asks.
    h.run("trace on cut")
    writer.began(transition, retargeted: false, samples: samples)
    h.run("trace off")
    #expect(!writer.isLogging)
  }

  // MARK: What a review found

  /// A name of a space is replaced wherever it stands as a word of free text, however short. These lines are not free text.
  @Test func noNameAndNoTitleCanDamageALine() {
    let (trace, h) = record { h, windows in
      h.system.setTitle(windows[0], "stage")
      h.system.setTitle(windows[1], "frame")
      h.system.setTitle(windows[2], "main")
      h.run("arrange")
      h.scheduler.advance(by: 1.5)
      for (window, name) in zip(windows, ["1", "0", "46", "stage", "frame", "down", "cover", "851"]) {
        h.system.userFocus(window)
        h.run("name \(name)")
      }
      h.run("state")
      h.run("zoom \(windows[2].rawValue)")
    }
    #expect(!h.controller.workspaces.values.flatMap(\.names).isEmpty)
    let report = StageJudge.report(on: trace)
    #expect(report.ok, "\(report.lines.joined(separator: "\n"))")
    #expect(StageLog.read(trace).motions.count == 2)
    #expect(stageLines(trace).count > 60)
  }

  /// One trace ends and another begins between two ticks, with a stage up: of that motion the second has no beginning, so it gets none of it.
  @Test func aTraceBegunInMidMotionHoldsNothingOfThatMotion() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 0.2)
      h.run("trace off")
      h.run("trace on second")
      h.scheduler.advance(by: 1.5)
      h.run("zoom \(windows[2].rawValue)")
    }
    #expect(trace.header.name == "second")
    let reading = StageLog.read(trace)
    #expect(reading.problems == [])
    #expect(reading.motions.count == 1)
    #expect(StageJudge.report(on: trace).ok)
  }

  /// The same with a command in mid-motion: the new trace begins at the roads that begin in it.
  @Test func aMotionRetargetedInANewTraceBeginsThere() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 1.5)
      h.run("zoom \(windows[2].rawValue)")
      h.scheduler.advance(by: 0.1)
      h.run("trace off")
      h.run("trace on second")
      h.scheduler.advance(by: 0.1)
      h.run("back")
    }
    let reading = StageLog.read(trace)
    #expect(reading.problems == [])
    #expect(reading.motions.map(\.beganInMidMotion) == [true])
    #expect(StageJudge.report(on: trace).ok)
  }

  private func entries(_ roads: [StageLog.Road], on display: DisplayID, frame: CGRect, at start: Double) -> [TraceEntry] {
    func mix(_ a: CGRect, _ b: CGRect, _ p: Double) -> CGRect {
      CGRect(
        x: a.minX + (b.minX - a.minX) * p, y: a.minY + (b.minY - a.minY) * p, width: a.width + (b.width - a.width) * p,
        height: a.height + (b.height - a.height) * p)
    }
    var entries = [TraceEntry(t: start, line: .raw(StageLog.Line.up(StageLog.Plan(display: display, frame: frame, duration: 0.46, roads: roads)).text))]
    for tick in 0...32 {
      let p = Transition.progress(after: Double(tick) / 60 / 0.46)
      if tick == 28 { entries.append(TraceEntry(t: start + 0.46, line: .raw(StageLog.Line.lift(display).text))) }
      entries.append(
        TraceEntry(
          t: start + Double(tick) / 60,
          line: .raw(StageLog.Line.frame(display, roads.map { StageLog.Sample($0.window, mix($0.from.frame, $0.to.frame, p)) }).text)))
    }
    return entries + [TraceEntry(t: start + 0.54, line: .raw(StageLog.Line.down(display).text))]
  }

  /// The controller also learns where windows are from the lists it asks for (after a change of the displays, on resuming) and from windows
  /// that are found or replaced. A judge that does not would hold stand-ins against frames from before.
  @Test func theRealWindowsAreFollowedThroughEveryWayTheyAreReported() {
    let h = Harness()
    h.start()
    let ids = (0..<4).map { _ in h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 400, height: 300)) }
    h.run("trace on real")
    h.run("trace off")
    var trace = recordedTrace(h)
    let display = trace.header.displays[0]
    func window(_ id: WindowID, x: CGFloat) -> TraceWindow {
      TraceWindow(id: id, pid: 1, bundle: nil, app: "Notes", title: "", frame: CGRect(x: x, y: 100, width: 400, height: 300))
    }
    let replacement = WindowID(900)
    func roads(_ windows: [(WindowID, CGFloat)]) -> [StageLog.Road] {
      windows.map { id, x in
        let from = CGRect(x: x, y: 100, width: 400, height: 300)
        return StageLog.Road(id, from: StageLog.Place(from), to: StageLog.Place(from.offsetBy(dx: 0, dy: 200)))
      }
    }
    func moved(_ windows: [(WindowID, CGFloat)], at t: Double) -> [TraceEntry] {
      windows.map { id, x in
        let to = CGRect(x: x, y: 300, width: 400, height: 300)
        return TraceEntry(t: t, line: .setFrame(id, to, result: to, took: nil))
      }
    }
    let now: [(WindowID, CGFloat)] = [(ids[0], 300), (ids[1], 500), (replacement, 700)]
    trace.entries =
      [
        TraceEntry(t: 1, line: .allWindows([window(ids[0], x: 300), window(ids[2], x: 100)])),
        TraceEntry(t: 1.1, line: .other(.event, "windowFound", arguments: [TraceJSON(encoding: window(ids[1], x: 500))], result: nil)),
        TraceEntry(
          t: 1.2,
          line: .other(.event, "windowReplaced", arguments: [TraceJSON(encoding: ids[2]), TraceJSON(encoding: window(replacement, x: 700))], result: nil)),
      ] + entries(roads(now), on: display.id, frame: display.frame, at: 2)
    trace.entries.insert(contentsOf: moved(now, at: 2), at: 5)
    let motion = StageLog.read(trace).motions[0]
    #expect(motion.realAtStart[ids[0]]?.minX == 300)
    #expect(motion.realAtStart[ids[1]]?.minX == 500)
    #expect(motion.realAtStart[replacement]?.minX == 700)
    // Not in the list, so it is gone; replaced, so it no longer shows.
    #expect(motion.realAtStart[ids[3]] == nil)
    #expect(motion.realAtStart[ids[2]] == nil)
    let report = StageJudge.report(on: trace)
    #expect(report.ok, "\(report.lines.joined(separator: "\n"))")
  }

  /// macOS moves windows when the displays change, and says where to when it is asked. Until then nobody knows.
  @Test func afterAChangeOfTheDisplaysNothingOldIsBelieved() {
    let h = Harness()
    h.start()
    let a = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    h.run("trace on displays")
    h.run("trace off")
    var trace = recordedTrace(h)
    let display = trace.header.displays[0]
    let from = CGRect(x: 1000, y: 100, width: 400, height: 300)
    let road = StageLog.Road(a, from: StageLog.Place(from), to: StageLog.Place(from.offsetBy(dx: -500, dy: 0)))
    trace.entries = [TraceEntry(t: 1, line: .displaysChanged([display]))] + entries([road], on: display.id, frame: display.frame, at: 2)
    let motion = StageLog.read(trace).motions[0]
    #expect(motion.realAtStart[a] == nil)
    #expect(StageJudge.report(on: trace).ok)
  }

  // MARK: The rehearsed stage does what the real one does

  @Test func endingAllMotionTakesTheRehearsedStageDownAtOnce() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 0.205)
      h.overlays.finishAnimations()
    }
    let lines = stageLines(trace)
    #expect(lines.last?.text == "stage down dmain")
    #expect(abs((lines.last?.t ?? 0) - 0.205) < 0.0001)
    #expect(!lines.contains { $0.text == "stage lift dmain" })
  }

  /// As `StageDirector.play`: a transition that takes no time is no motion, and ends what is playing.
  @Test func aTransitionOfNoDurationTakesTheRehearsedStageDown() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 0.205)
      var none = h.overlays.transitions.last!
      none.duration = 0
      h.overlays.animate(none)
    }
    let lines = stageLines(trace)
    #expect(lines.last?.text == "stage down dmain")
    #expect(abs((lines.last?.t ?? 0) - 0.205) < 0.0001)
    #expect(lines.filter { $0.text.hasPrefix("stage up") }.count == 1)
  }

  /// The stage comes down whether or not anybody records it.
  @Test func aMotionAfterATraceThatEndedInMidMotionIsANewOne() {
    let (trace, _) = record { h, windows in
      h.run("arrange")
      h.scheduler.advance(by: 0.2)
      h.run("trace off")
      h.scheduler.advance(by: 2)
      h.run("trace on later")
      h.run("zoom \(windows[2].rawValue)")
    }
    #expect(stageLines(trace).first?.text.hasPrefix("stage up ") == true)
    #expect(StageJudge.report(on: trace).ok)
  }
}
