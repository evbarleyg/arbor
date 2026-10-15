import ArborTesting
import Foundation

// arbor-sim's lid sweep (docs/TESTING.md, "The lid sweep"):
//
//   arbor-sim sweep [right|left|above…] [--stride <points>] [--examples <n>] [--strict]
//       every column of those sides (all three), one line each; exit code 1 if a window was hidden or out of reach anywhere,
//       with --strict also if one jumped; 2 if the lab refused a step, so that the sweep was not the one it says it was
//   arbor-sim sweep story <side> <x> <y> [untouched]
//       one window through the lid, in every order of reports, stage by stage

private func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }

@MainActor
func runSweep(_ arguments: [String]) -> Int32 {
  func number(after flag: String, default fallback: Int) -> Int {
    arguments.firstIndex(of: flag).flatMap { $0 + 1 < arguments.count ? Int(arguments[$0 + 1]) : nil } ?? fallback
  }
  if arguments.first == "story" {
    guard arguments.count >= 4, let side = LidSweep.Side(rawValue: arguments[1]), let x = Int(arguments[2]), let y = Int(arguments[3]) else {
      say("usage: arbor-sim sweep story <right|left|above> <x> <y> [untouched]")
      return 2
    }
    for order in ChaosAction.WindowsFollow.allCases {
      let column = LidSweep.Column(side: side, byHand: !arguments.contains("untouched"), order: order)
      say("\(column):")
      for line in LidSweep(column).story(x: x, y: y) { say("  \(line)") }
    }
    return 0
  }
  let sides = arguments.compactMap { LidSweep.Side(rawValue: $0) }
  let (examples, strict) = (number(after: "--examples", default: 1), arguments.contains("--strict"))
  var (bad, refused) = (false, false)
  for column in LidSweep.Column.all(sides.isEmpty ? LidSweep.Side.allCases : sides) {
    var sweep = LidSweep(column)
    sweep.stride = max(1, number(after: "--stride", default: sweep.stride))
    let tally = sweep.run()
    // At which change: the lid closes + opens + closes again. (What moved as soon as the hand let go is in none of them.)
    func split(_ counts: [Int]) -> String { counts.allSatisfy { $0 == 0 } ? "" : " (" + counts.map(String.init).joined(separator: " + ") + ")" }
    say(
      "\(column): \(tally.places) places, hidden \(tally.hidden.count), out of reach \(tally.outOfReach.count), "
        + "jumped \(tally.jumped.count)\(split(tally.jumpedAtEachChange)), fitted \(tally.fitted.count)\(split(tally.fittedAtEachChange)), home on the laptop \(tally.homeOnTheLaptop), where the hand left it \(tally.whereTheHandLeftIt)"
        + (tally.movedAtTheStart > 0 ? "; not looked at: \(tally.movedAtTheStart) that Arbor moved at its start" : "")
        + (tally.outOfAHandsReach > 0 ? "; \(tally.outOfAHandsReach) where no hand could put it" : ""))
    for line in Set(tally.trouble).sorted().prefix(5) { say("  REFUSED: \(line)") }
    if !tally.trouble.isEmpty { refused = true }
    for (kind, places) in [("HIDDEN", tally.hidden), ("OUT OF REACH", tally.outOfReach), ("jumped", tally.jumped), ("fitted", tally.fitted)] {
      for place in places.prefix(examples) { say("  \(kind): \(place)") }
    }
    if tally.isLost || (strict && !tally.jumped.isEmpty) { bad = true }
  }
  return refused ? 2 : bad ? 1 : 0
}
