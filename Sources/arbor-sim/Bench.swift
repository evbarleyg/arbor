import ArborTesting
import Foundation

// arbor-sim bench [sizes…]: what everyday commands cost, counted and timed on desks of 4, 10 and 30
// windows (or the sizes given), then the pure parts on nested trees of 10, 50 and 150.
//
// The counts are what makes a command slow on a Mac, where each move is several round trips to the
// window's app; the times are Arbor's own work, since the fake window system answers at once.
// Build with `swift build -c release` for times worth quoting.

@MainActor
func runBenchmarks(_ arguments: [String]) {
  let given = arguments.compactMap(Int.init).filter { $0 >= 4 && $0 <= 1000 }
  let desks = given.isEmpty ? [4, 10, 30] : given
  let trees = given.isEmpty ? [10, 50, 150] : given

  func pad(_ text: String, _ width: Int) -> String {
    text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
  }
  func microseconds(_ seconds: Double) -> String { String(Int((seconds * 1_000_000).rounded())) }

  for size in desks {
    print("\(size) windows")
    print(
      "  \("command".padding(toLength: 24, withPad: " ", startingAt: 0))"
        + "  moves  asked   idle repeat  alone  focus   idle  reads  overl   idle  saves      µs")
    for benchmark in BenchmarkCase.all {
      let result = benchmark.run(windows: size, repetitions: 5)
      let b = result.budget
      let columns = [
        b.moves, b.questions, b.idleMoves, b.repeatMoves, b.movesAlone, b.focuses, b.idleFocuses, b.focusReads, b.overlayUpdates,
        b.idleOverlayUpdates, b.saves,
      ]
      print(
        "  \(result.name.padding(toLength: 24, withPad: " ", startingAt: 0))"
          + columns.map { pad(String($0), 7) }.joined() + pad(microseconds(result.seconds), 8))
    }
    print("")
  }

  let names = [
    "stackedWindows", "windowsFrontToBack", "existingWindowIDs", "allWindows", "displays", "inputActivity",
    "cursorLocation", "isMouseButtonDown", "modifierKeysDown",
  ]
  print("what else is asked, 10 windows (the first three have the window server list every window)")
  print("  \("command".padding(toLength: 24, withPad: " ", startingAt: 0))" + names.map { pad(String($0.prefix(9)), 10) }.joined())
  for benchmark in BenchmarkCase.all {
    let questions = benchmark.run(windows: 10, repetitions: 1).budget.asked
    print(
      "  \(benchmark.name.padding(toLength: 24, withPad: " ", startingAt: 0))"
        + names.map { pad(String(questions[$0, default: 0]), 10) }.joined())
  }
  print("")

  print("the pure parts, µs" + trees.map { pad("\($0)", 9) }.joined())
  let columns = trees.map { CoreBenchmark.run(windows: $0) }
  for row in columns[0].indices {
    print(
      "  \(columns[0][row].name.padding(toLength: 46, withPad: " ", startingAt: 0))"
        + columns.map { pad(microseconds($0[row].seconds), 9) }.joined())
  }
}
