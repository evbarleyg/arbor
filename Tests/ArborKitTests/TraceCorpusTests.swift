import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// Every trace committed under `collab/evidence/traces` is a regression test: it is replayed in free mode, so Arbor may
/// change what it does, but with the windows and apps of that recording nothing may get lost, no tree may break, no fight
/// with an app may go on for ever, and windows must end up where Arbor put them. `<name>.expect` beside a trace
/// adds expectations about the end (docs/TRACES.md).
@MainActor
@Suite struct TraceCorpusTests {
  /// Found from this file's own path: resources would need a different arrangement on each platform.
  nonisolated static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("collab/evidence/traces")

  nonisolated static let names: [String] = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    .filter { $0.hasSuffix(".jsonl") }.map { String($0.dropLast(6)) }.sorted()

  private func text(_ name: String, _ suffix: String) -> String? {
    try? String(contentsOf: Self.folder.appendingPathComponent(name + suffix), encoding: .utf8)
  }

  @Test(arguments: names)
  func everyCommittedTraceReplays(name: String) throws {
    let trace = try Trace(text: try #require(text(name, ".jsonl")))
    let report = TraceReplayer(trace).run(expectations: text(name, ".expect"))
    #expect(
      report.problems == [],
      """
      See what happened with: make replay FILE=collab/evidence/traces/\(name).jsonl
      "No problem containing … was reported" is good news: your change fixed a known bug. Delete that `problem` line from \
      collab/evidence/traces/\(name).expect, and the trace holds your fix in place from now on.
      Lines below the mark in that file say what Arbor did when they were written. If it does something else now, and rightly: \
      scripts/trace-to-test.py --again \(name), and read what changed: each line is something a person at that Mac would have seen.
      """)
    #expect(!trace.entries.isEmpty)
  }

  /// A control: a test on a recording is worth what it says when the fault is there. `app-switch-unreported` was recorded with an `AXWindowSystem` that
  /// dropped the only sign of a switch of apps, and holds one line, added by hand, for what that layer reports since its cure. Without the line it
  /// is what the Mac's Arbor was told that day, and the window that has the keyboard stays out of view.
  @Test func withoutTheReportThatWasLostTheSwitchOfAppsFails() throws {
    var lines = try #require(text("app-switch-unreported", ".jsonl")).split(separator: "\n", omittingEmptySubsequences: false)
    let remark = try #require(lines.firstIndex { $0.hasPrefix("# The next line was added by hand") })
    let added = try #require(lines[remark...].firstIndex { !$0.hasPrefix("#") })
    #expect(lines[added].contains(#""event":"focused""#))
    lines.remove(at: added)
    let report = TraceReplayer(try Trace(text: lines.joined(separator: "\n"))).run(expectations: text("app-switch-unreported", ".expect"))
    let failed = report.problems.filter { $0.kind == .expectation }.map(\.text)
    for expectation in ["`visible 75`", "`camera 75`", "`moved 75 2 at "] {
      #expect(failed.contains { $0.hasPrefix(expectation) }, "\(expectation) holds without the report, so it does not tell: \(failed)")
    }
  }

  /// Arbor keeps windows out of view, so whatever state it is in there must be a way back to a Mac with every window in sight. Each
  /// trace is cut wherever something may have changed, also in the middle of drags, which gives some thousand states that real apps and a real
  /// pointer brought about, and from each one every way back is tried.
  @Test(arguments: names)
  func everyWayBackReturnsEveryWindowFromEveryStateOfATrace(name: String) throws {
    let text = try #require(text(name, ".jsonl"))
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    // Before every stimulus since the last of which something may have changed: where a window is, or what Arbor knows or has done. In a trace of real
    // apps two stimuli in three are a timer that looked and did nothing or a report that moved nothing, and the state after it is the state before it.
    let whole = try Trace(text: text)
    var cuts: [Int] = []
    var somethingHappened = true
    for entry in whole.entries {
      if entry.line.isStimulus, !entry.nested {
        if somethingHappened { cuts.append(entry.number) }
        switch entry.line {
        case .timer, .keyboardFocusMoved, .other(.event, "pointerPressed", _, _), .other(.event, "settingsFileMayHaveChanged", _, _): somethingHappened = false
        default: somethingHappened = true
        }
      } else if entry.line.isEffect || entry.line.isStimulus {
        somethingHappened = true
      }
    }
    cuts.append(lines.count + 1)
    var states = 0
    for cut in cuts where cut > 2 {
      // Read once: reading the first lines anew for every cut took longer than replaying them.
      let prefix = Trace(header: whole.header, entries: whole.entries.filter { $0.number < cut })
      // A window that is being dragged is where the hand holds it, which can be half off the screen. Nobody misses it, and no way
      // back takes it out of the hand: a quit gives back what Arbor took and touches nothing else, and the next start finds it
      // there. Exactly there: moved anywhere else out of view, it is lost.
      var inHand: WindowID?
      // Not every drag is reported as one (`day-11-drags-to-the-edges`: Notes goes to the left edge with the button down, and all Arbor hears is that it
      // moved). Let go of there, macOS tiles it, which takes a third of a second of further reports. Until they have stopped for half a second it is in macOS's hand.
      var buttonIsDown = false
      var carried: (window: WindowID, at: Double)?
      for entry in prefix.entries {
        switch entry.line {
        case .dragBegan(let id, _): inHand = id
        case .dragEnded, .other(.event, "dragCancelled", _, _): inHand = nil
        case .raw(let text) where text.hasPrefix("leftMouse"): buttonIsDown = !text.hasPrefix("leftMouseUp")
        case .changed(let window, true):
          if buttonIsDown || (carried?.window == window.id && entry.t - carried!.at < 0.5) { carried = (window.id, entry.t) }
        default: break
        }
      }
      // Only while it floats: where a floating window lies is its person's business, where a docked one lies is Arbor's.
      var inMacOSsHand: WindowID?
      if inHand == nil, let carried, let last = prefix.entries.last, last.t - carried.at < 0.5 { inMacOSsHand = carried.window }
      for way in ["float-all", "quit", "quit, start again, float-all"] {
        let replayer = TraceReplayer(prefix, silent: true)
        replayer.run()
        let h = replayer.harness
        // A trace ends when Arbor pauses or quits.
        guard h.controller.isRunning else { continue }
        states += 1
        let held = inHand.flatMap { h.system.frame(of: $0) }
        let wasFloating = inMacOSsHand.map { id in h.controller.workspaces.values.contains { $0.isFloating(id) } } ?? false
        let carriedTo = inMacOSsHand.flatMap { h.system.frame(of: $0) }
        // "Nothing is docked" is an answer too. What counts is what can be seen afterwards.
        if way == "float-all" { h.run("float-all") }
        if way != "float-all" { h.controller.shutdown() }
        if way.hasSuffix("start again, float-all") {
          h.controller.start()
          h.scheduler.runPending()
          h.run("float-all")
        }
        h.scheduler.runPending()
        let lost = h.system.windows.values.map(\.snapshot)
          .filter { $0.isPresent && !h.system.isVisible($0.id) && !($0.id == inHand && (way == "float-all" || $0.frame == held)) }
          .filter { window in
            !(window.id == inMacOSsHand && wasFloating && (way == "float-all" || window.frame == carriedTo))
          }
          .map { "\($0.id) \($0.appName) at \(traceText($0.frame))" }.sorted()
        #expect(
          lost == [],
          """
          After the first \(cut - 1) lines of \(name).jsonl, `\(way)` leaves windows out of view. See the state with: \
          head -\(cut - 1) collab/evidence/traces/\(name).jsonl > /tmp/cut.jsonl && make replay FILE=/tmp/cut.jsonl
          """)
      }
    }
    #expect(states > 0 || cuts.count <= 1)
  }

  @Test(arguments: names)
  func committedTracesHoldOnlyTokensForTitles(name: String) throws {
    let trace = try Trace(text: try #require(text(name, ".jsonl")))
    var titles = trace.header.windows.map(\.title)
    for entry in trace.entries {
      switch entry.line {
      case .appeared(let window), .changed(let window, _): titles.append(window.title)
      case .allWindows(let windows): titles += windows.map(\.title)
      default: break
      }
    }
    // `title-3` in the traces recorded before the number was closed in.
    let token = /(title(-[0-9]+|\[[0-9]+\])(\[[a-z][0-9]+\])*)?/
    for title in Set(titles) { #expect(title.wholeMatch(of: token) != nil, "\(title)") }
    for rule in trace.header.settings.rules {
      if let pattern = rule.title { #expect(pattern.wholeMatch(of: /\[p[0-9]+\]/) != nil, "\(pattern)") }
    }
  }

  @Test func committedTracesAreSmallAndDescribed() throws {
    #expect(!Self.names.isEmpty)
    let readme = try #require(text("README", ".md"))
    for name in Self.names {
      #expect(readme.contains("`\(name)`"), "say what \(name) shows in collab/evidence/traces/README.md")
      #expect((text(name, ".jsonl") ?? "").utf8.count < 200_000, "\(name) is too big to live in the repository")
    }
  }
}
