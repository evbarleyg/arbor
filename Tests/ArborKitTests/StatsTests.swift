import ArborCore
import ArborKit
import ArborTesting
import Dispatch
import Foundation
import Testing

@Suite @MainActor struct StatsTests {
  @Test func commandsAndLayoutsAreCounted() throws {
    let w = Workload(windows: 4, grid: true)
    let h = w.harness
    #expect(h.run("stats reset").ok)
    #expect(h.run("stats").text?.contains("nothing recorded") == true)
    h.run("zoom \(w.docked[0].rawValue)")
    h.run("back")
    h.run("back")  // fails, and is counted: it took time too
    #expect(h.controller.stats["commands", "zoom"]?.count == 1)
    #expect(h.controller.stats["commands", "back"]?.count == 2)
    #expect(h.controller.stats["controller", "lay out a display"]?.count == 2)
    #expect(h.controller.stats["controller", "update overlays"]?.count == 2)
    let text = try #require(h.run("stats").text)
    #expect(text.contains("commands") && text.contains("  zoom") && text.contains("worst ms"))
    #expect(h.controller.stats["commands", "stats"] == nil, "asking does not change the answer")
  }

  @Test func itWorksBeforeArborRuns() {
    let h = Harness()
    #expect(h.run("stats").ok && h.run("stats reset").ok)
  }

  @Test func theTextFormRoundTrips() throws {
    #expect(try Command.parse("stats") == .stats(reset: false))
    #expect(try Command.parse("stats reset") == .stats(reset: true))
    #expect(try Command.parse(Command.stats(reset: true).text) == .stats(reset: true))
    #expect(throws: Command.ParseError.self) { try Command.parse("stats now") }
    #expect(Command.stats(reset: false).isQuery && Command.helpText.contains("stats [reset]"))
  }

  @Test func aGroupDoesNotGrowWithoutBound() {
    let stats = CallStats()
    for pid in 0..<(CallStats.namesPerGroup + 50) { stats.record("apps", "pid \(pid)", seconds: 1) }
    stats.record("apps", "pid 3", seconds: 1)
    #expect(stats["apps", "pid 3"]?.count == 2, "names that are known are still counted on their own")
    #expect(stats["apps", "pid \(CallStats.namesPerGroup + 7)"] == nil)
    // The name itself takes the place after the last.
    #expect(stats["apps", CallStats.others]?.count == 50)
    #expect(stats.report().split(separator: "\n").count < CallStats.namesPerGroup + 10)
  }

  @Test func entriesAddUpFromManyThreads() {
    let stats = CallStats()
    DispatchQueue.concurrentPerform(iterations: 8) { thread in
      for index in 0..<500 { stats.record("calls", "kind \(index % 2)", seconds: Double(thread + 1)) }
    }
    let entry = stats["calls", "kind 0"]
    #expect(entry?.count == 2000 && entry?.worst == 8 && entry?.total == 250 * 36)
    #expect(stats.time("calls", "timed") { 7 } == 7)
    #expect(stats["calls", "timed"]?.count == 1)
    // The costliest first.
    stats.record("calls", "cheap", seconds: 0.001)
    let lines = stats.report().split(separator: "\n").map(String.init)
    let cheap = try! #require(lines.firstIndex { $0.hasPrefix("  cheap") })
    let dear = try! #require(lines.firstIndex { $0.hasPrefix("  kind 0") })
    #expect(dear < cheap)
  }
}
