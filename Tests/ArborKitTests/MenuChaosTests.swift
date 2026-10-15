import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

private func environment(_ name: String) -> Int? { ProcessInfo.processInfo.environment[name].flatMap { Int($0) } }

private let seeds: [UInt64] = {
  let first = UInt64(environment("ARBOR_CHAOS_FIRST") ?? 1)
  let walks = Array(first..<(first + UInt64(environment("ARBOR_CHAOS_SEEDS") ?? 30)))
  // 2221: Arrange Windows was offered where the only docked windows were places kept for windows that are not open yet.
  return environment("ARBOR_CHAOS_SEEDS") == nil && environment("ARBOR_CHAOS_FIRST") == nil ? walks + [2221] : walks
}()

/// "Greyed out, not hidden", and the other way round: what is not greyed out works (docs/MENU.md, rule 4). `MenuTests` holds the
/// menu to that in states written by hand. Here the chaos lab's random walks (docs/TESTING.md, "Chaos") bring Arbor into states nobody
/// wrote: several displays, windows kept in view, summoned, minimized, tiles, a held view. Every third step a row is chosen at
/// random, as `StatusMenu` would run it, and what happens is compared with how the row looked.
/// `ARBOR_CHAOS_SEEDS=2000 swift test --filter MenuChaos` hunts for longer, `ARBOR_CHAOS_FIRST=…` elsewhere. The same seed gives the same walk.
@Suite @MainActor struct MenuChaosTests {
  /// Never greyed out, so that nobody has to wonder why: the ways back (`MenuTests.theWaysBackAreAlwaysThere`).
  static let alwaysOffered: [Command] = [.showAll, .floatAll, .togglePause]
  /// Offered, and may fail: commands that find out only when it comes to it. **When the net names your row, let its `.enabled(…)` ask what the
  /// command itself goes by. If there is no time for that, add the command here with the feature and the reason: one line, and it stays on record.**
  static let findOutLate: [(command: Command, why: String)] = [
    (.undo, "F19: the step's window has closed since, or gone full screen; a closing that cannot be undone comes first"),
    (.redo, "F19: the same"),
    (.grow(nil), "F22: the window is as large as its app or its neighbours allow"),
    (.shrink(nil), "F22: the window is as small as its app allows"),
    (.equalize(all: false), "F22: the focused window is full screen"),
    (.rotate, "F22: rotated, a window would be too small to show"),
    (.moveToDisplay(.next, nil), "F22: the window's app hangs, which is found out by asking it"),
  ]
  /// They need something a test has not got (a window to open, GitHub), or end the walk.
  static let notTried: [Command] = [.quit, .checkSetup, .welcome, .settings(.showWindow()), .checkForUpdates, .reloadSettings, .togglePause]

  /// A shortcut held down is a look that is not over (Controller+Peek.swift): the view is on loan and Back and Forward are put away.
  /// Whatever is chosen then ends the look first, so how a row looked a moment before says nothing. The walk's own script tells.
  struct KeysDown {
    private var count = 0
    var any: Bool { count > 0 }
    mutating func note(_ action: ChaosAction) {
      if action.text.hasPrefix("key down ") { count += 1 }
      if action.text.hasPrefix("key up ") { count = max(count - 1, 0) }
      // A new process has no key of the old one's.
      if action == .launch { count = 0 }
    }
  }

  @Test(arguments: seeds) func aRowLooksTheWayItActs(seed: UInt64) {
    Log.silenced {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed)
      var random = ChaosRandom(seed: seed &* 7919)
      var keys = KeysDown()
      for step in 0..<150 {
        let action = generator.next(runner)
        _ = runner.step(action)
        keys.note(action)
        // Without a display there is no menu bar to open the menu from.
        guard step % 3 == 0, !keys.any, !runner.controller.displays.isEmpty else { continue }
        let menu = runner.controller.menuModel()
        // docs/MENU.md, rule 3, which `MenuHeightTests` holds the menu to in the states it lists.
        #expect(menu.height <= MenuModel.tallest, "seed \(seed), step \(step): \(menu.height) points high\n\(menu.text)")
        let rows = menu.allItems.filter { $0.command.map { !Self.notTried.contains($0) } ?? false }
        guard let row = random.pick(rows), let command = row.command else { continue }
        let before = runner.harness.run("status").message
        let result = runner.harness.run(command.text, from: .menu)
        let told = "seed \(seed), step \(step): “\(row.title)” (\(command.text)) answered “\(result.message)”; before it, \(before)"
        if row.isEnabled {
          // F58 refuses some moves of a window only when it comes to it: whether one would bring something into a held view.
          let refusedByTheHold = result.message.contains("the view is held")
          // A walk can stop with the button down. Nobody opens a menu then.
          let midDrag = result.message.contains("is being dragged")
          let findsOutLate = Self.findOutLate.contains { $0.command == command }
          // A command that changes a setting reads settings.json first. Edited a moment ago behind Arbor's back, it can say so already.
          let theFileWasAhead = result.message.hasSuffix(" already")
          #expect(
            result.ok || Self.alwaysOffered.contains(command) || refusedByTheHold || midDrag || findsOutLate || theFileWasAhead,
            "offered, and failed. \(told)")
        } else {
          // The row says float. On a window that floats the command behind it, which the shortcut shares, would dock it.
          #expect(!result.ok || command == .toggleFloat(nil), "greyed out, and would have worked. \(told)")
        }
      }
    }
  }

  /// The same of the menu bar item's buttons: a click on one that is not greyed out moves the view, and a greyed one has nowhere to go.
  @Test(arguments: seeds) func aButtonLooksTheWayItActs(seed: UInt64) {
    Log.silenced {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed)
      var random = ChaosRandom(seed: seed &* 104_729)
      var keys = KeysDown()
      for step in 0..<150 {
        let action = generator.next(runner)
        _ = runner.step(action)
        keys.note(action)
        guard step % 3 == 0, !keys.any else { continue }
        guard let button = random.pick(runner.controller.menuBarModel().buttons), let command = button.command else { continue }
        let before = runner.harness.run("status").message
        let result = runner.harness.run(command.text, from: .menu)
        let told = "seed \(seed), step \(step): “\(button.title)” (\(command.text)) answered “\(result.message)”; before it, \(before)"
        #expect(result.ok == button.isEnabled, "\(button.isEnabled ? "offered, and failed" : "greyed out, and would have worked"). \(told)")
      }
    }
  }
}
