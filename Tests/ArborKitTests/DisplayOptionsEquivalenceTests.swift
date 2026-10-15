import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Per-display options (docs/features/F25-per-display-options.md): a value a display has from an entry of `displays` must do
/// exactly what the same value does as a general setting. `nothingInTheControllerReadsAPerDisplayOptionFromTheGeneralSettings` reads the
/// controller's sources for readers that go past `options(for:)`; this finds them by what they do, as far as the journeys go there.
@Suite @MainActor struct DisplayOptionsEquivalenceTests {
  func harness(_ settings: Settings, _ dice: inout RandomJourney.Dice) -> Harness {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, RandomJourney.side], settings: settings)
    for app in ["Safari", "Mail", "Notes", "Terminal"] {
      h.system.open(app: app, pid: RandomJourney.pid(of: app), frame: CGRect(x: 100 + CGFloat(dice.roll(2600)), y: 100, width: 500, height: 400))
    }
    h.start()
    return h
  }

  @Test(arguments: 1...40)
  func aValueFromAnEntryDoesWhatTheGeneralSettingDoes(seed: Int) throws {
    // An odd seed has gaps thinner than the focus ring, an even one wide gaps.
    let gap: Double = seed.isMultiple(of: 2) ? 26 : 2
    var general = RandomJourney.settings
    general.reflowWhileDragging = true
    general.gap = gap
    general.minimumUsableWidth = 420
    general.minimumUsableHeight = 300
    general.screenEdgeBand = 44
    // The same values, from two entries that between them match every display; the general ones stay the defaults.
    var byEntry = RandomJourney.settings
    byEntry.reflowWhileDragging = true
    // Every third seed docks new windows by itself, which asks for room by the display's own sizes.
    if seed.isMultiple(of: 3) { (general.newWindows, byEntry.newWindows) = ("dock", "dock") }
    byEntry.displays = [
      DisplayOptions(match: .main, gap: gap, minimumUsableWidth: 420),
      DisplayOptions(match: .named("Side"), gap: gap, screenEdgeBand: 44),
      DisplayOptions(match: .width(.atLeast, 100), minimumUsableWidth: 420, minimumUsableHeight: 300, screenEdgeBand: 44),
    ]
    var first = RandomJourney.Dice(state: UInt64(seed) &* 104_729)
    var second = first
    let a = harness(general, &first)
    let b = harness(byEntry, &second)
    var history: [String] = []
    for step in 1...121 {
      if step <= 120 {
        history.append(RandomJourney.step(a, &first, settings: false))
        _ = RandomJourney.step(b, &second, settings: false)
      } else {
        // Quitting puts windows back: where they floated, or in their slots by the display's own gap where that is not known.
        history.append("quit")
        a.controller.shutdown()
        b.controller.shutdown()
      }
      a.scheduler.advance(by: 1)
      b.scheduler.advance(by: 1)
      let framesA = Dictionary(uniqueKeysWithValues: a.system.allWindows().map { ($0.id, $0.frame) })
      let framesB = Dictionary(uniqueKeysWithValues: b.system.allWindows().map { ($0.id, $0.frame) })
      guard framesA == framesB, a.controller.workspaces == b.controller.workspaces, a.overlays.scenes == b.overlays.scenes,
        a.overlays.preview == b.overlays.preview, a.overlays.transitions == b.overlays.transitions
      else {
        let differing = framesA.keys.sorted().filter { framesA[$0] != framesB[$0] }
        Issue.record(
          """
          seed \(seed), step \(step): after \(history.suffix(5).joined(separator: "; "))
          \(differing.map { "\($0): \(framesA[$0]!) as a general setting, \(framesB[$0].map { "\($0)" } ?? "gone") from an entry" }.joined(separator: "\n"))
          \(a.controller.workspaces == b.controller.workspaces ? "" : "the arrangements differ")
          \(a.overlays.scenes == b.overlays.scenes ? "" : "what is drawn at rest differs")
          \(a.overlays.preview == b.overlays.preview ? "" : "the drop preview differs: \(a.overlays.preview as Any), \(b.overlays.preview as Any)")
          \(a.overlays.transitions == b.overlays.transitions ? "" : "the motions differ")
          """)
        return
      }
    }
  }
}
