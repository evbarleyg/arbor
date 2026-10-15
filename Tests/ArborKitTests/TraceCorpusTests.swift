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
      """)
    #expect(!trace.entries.isEmpty)
  }

  /// Arbor keeps windows out of view, so whatever state it is in there must be a way back to a Mac with every window in sight. Each
  /// trace is cut before every stimulus, also in the middle of drags, which gives some thousand states that real apps and a real pointer
  /// brought about, and from each one every way back is tried.
  @Test(arguments: names)
  func everyWayBackReturnsEveryWindowFromEveryStateOfATrace(name: String) throws {
    let text = try #require(text(name, ".jsonl"))
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let cuts = try Trace(text: text).entries.filter { $0.line.isStimulus && !$0.nested }.map(\.number) + [lines.count + 1]
    var states = 0
    for cut in cuts where cut > 2 {
      let prefix = try Trace(text: lines.prefix(cut - 1).joined(separator: "\n"))
      // A window that is being dragged is where the hand holds it, which can be half off the screen. Nobody misses it, and no way
      // back takes it out of the hand: a quit gives back what Arbor took and touches nothing else, and the next start finds it
      // there. Exactly there: moved anywhere else out of view, it is lost.
      var inHand: WindowID?
      for entry in prefix.entries {
        switch entry.line {
        case .dragBegan(let id, _): inHand = id
        case .dragEnded, .other(.event, "dragCancelled", _, _): inHand = nil
        default: break
        }
      }
      for way in ["float-all", "quit", "quit, start again, float-all"] {
        let replayer = TraceReplayer(prefix)
        replayer.run()
        let h = replayer.harness
        // A trace ends when Arbor pauses or quits.
        guard h.controller.isRunning else { continue }
        states += 1
        let held = inHand.flatMap { h.system.frame(of: $0) }
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
