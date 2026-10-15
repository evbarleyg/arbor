import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// On a display of scale 1 the window server keeps whole points. Which way half a point goes was in the ledger as a riddle: 150.5 became 150 "but"
/// 46.5 became 47. The one is an x and the other a y.
@Suite @MainActor struct HalfPointsTests {
  /// Asked and answered on a hosted Mac.
  @Test(arguments: [
    (CGRect(x: 596.5, y: 68, width: 337, height: 600), CGRect(x: 596, y: 68, width: 337, height: 600)),
    (CGRect(x: 12, y: 55.5, width: 494, height: 625), CGRect(x: 12, y: 56, width: 494, height: 625)),
  ])
  func halfAPointOfXGoesDownAndOfYGoesUp(asked: CGRect, answered: CGRect) {
    let system = FakeWindowSystem(displays: [
      DisplaySnapshot(
        id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768), visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674),
        isMain: true)
    ])
    let window = system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    #expect(system.setFrame(asked, of: window) == answered)
    #expect(system.frame(of: window) == answered)
  }

  /// Every frame with a fraction in its place that Arbor asked for in a recording of real windows, against what the stand-in makes of it.
  @Test func theRecordingsBearItOut() throws {
    let differential = TraceCorpusTests.folder.deletingLastPathComponent().appendingPathComponent("reality-mac/traces")
    let others = ((try? FileManager.default.contentsOfDirectory(atPath: differential.path)) ?? []).filter { $0.hasSuffix(".jsonl") }.sorted()
    let files = TraceCorpusTests.names.map { TraceCorpusTests.folder.appendingPathComponent($0 + ".jsonl") } + others.map { differential.appendingPathComponent($0) }
    var (read, differing) = (0, [String]())
    for file in files {
      let trace = try Trace(contentsOf: file)
      guard trace.header.os != "simulated" else { continue }
      let system = FakeWindowSystem(displays: trace.header.displays.map { DisplaySnapshot($0) })
      for entry in trace.entries {
        guard case .setFrame(_, let asked, let took?, _) = entry.line, asked.minX != asked.minX.rounded() || asked.minY != asked.minY.rounded()
        else { continue }
        read += 1
        // No title bar: how low a window may go is another matter.
        if system.whereMacOSPuts(asked, titleBar: 0).origin != took.origin { differing.append("\(file.lastPathComponent): \(asked) became \(took)") }
      }
    }
    #expect(read >= 5, "the recordings are there and were read")
    #expect(differing.isEmpty, "\(differing)")
  }
}
