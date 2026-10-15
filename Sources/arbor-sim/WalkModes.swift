import ArborCore
import ArborKit
import ArborTesting
import Foundation

// arbor-sim's walks for a hosted Mac (docs/TESTING.md, "Walks for a hosted Mac"):
//
//   arbor-sim walk <seed> <acts> --for-a-mac <cast> <display> <tiling> [commit]
//                                      writes a walk in the words of scripts/mac-shell/lib-walk.sh: a file that bash runs on a hosted Mac as it stands
//   arbor-sim walk <seed> <acts> --words <cast> <display> <tiling>
//                                      only its words, one a line: what scripts/mac-shell/gate.py hands to gate.sh
//   arbor-sim walk --rehearse [options] < file
//                                      plays such a file, whoever wrote it, against the stand-ins. Exit code 1 when a rule broke that is no known failure
//       --samples <file>               writes what the screen showed, for `scripts/mac-shell/jolts.py report <file>` and `walk-diff.py`
//       --scene <samples of a run>     begins where that run on a Mac began: its display, its windows' frames, its pile
//       --script                       prints the events instead of the story: a script for `arbor-sim replay` and `shrink`
//       --shrink                       for each rule that broke and is no known failure: the shortest script that still breaks it
//       --without-arbor                the control: Arbor is never started
//       --quiet                        only the last lines
//   arbor-sim walk --many <first> <count> <acts> [display] [tiling] [cast]
//                                      writes and plays that many walks, from the seeds <first>, <first> + 1, …, and adds up what came of them

private func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }
private func complain(_ line: String) { FileHandle.standardError.write(Data(("arbor-sim walk: " + line + "\n").utf8)) }

@MainActor
private func summary(of player: WalkPlayer) -> [String] {
  let counts = WalkWriter.counts(of: player)
  var lines = [
    "\(player.played.count) acts: " + WalkKind.ofActs.compactMap { kind in counts[kind].map { "\(kind.rawValue) \($0)" } }.joined(separator: ", "),
    "\(player.leftOut.count) left out because they did not apply, \(player.notRehearsed.count) that the stand-ins cannot play",
  ]
  let findings = player.acts.flatMap { act in act.findings.map { "\(act.number) \(act.slug): \($0)" } }
  lines += findings.map { "FINDING \($0)" }
  lines += player.broken(known: false).map { "RULE \($0.violation.rule) at \($0.act.number) \($0.act.slug): \($0.violation)" }
  let known = Dictionary(grouping: player.broken(known: true), by: \.violation.rule).mapValues(\.count)
  lines += known.sorted { $0.key < $1.key }.map { "known: \($0.key) at \($0.value) acts" }
  return lines
}

/// Runs a walk mode if the arguments ask for one, and returns the exit code; nil otherwise.
@MainActor
func runWalkMode(_ arguments: [String]) -> Int32? {
  guard arguments.first == "walk" else { return nil }
  let rest = Array(arguments.dropFirst())
  func option(_ name: String) -> String? { rest.firstIndex(of: name).flatMap { rest.indices.contains($0 + 1) ? rest[$0 + 1] : nil } }
  func setting(_ words: ArraySlice<String>, seed: String) -> WalkSetting? {
    let words = Array(words)
    guard words.count >= 3, let cast = WalkSetting.Cast(rawValue: words[0]), let display = WalkSetting.Display(rawValue: words[1]), let tiling = WalkSetting.Tiling(rawValue: words[2]) else {
      complain("stock, browsers or awkward, then laptop, desk or two, then defaults or off")
      return nil
    }
    // Both go into a file that bash runs as it stands.
    guard words.count <= 4, words.count < 4 || WalkSetting.isAPlainWord(words[3]) else {
      complain("a commit is letters and digits, and nothing comes after it")
      return nil
    }
    return WalkSetting(cast: cast, display: display, tiling: tiling, seed: seed, commit: words.count > 3 ? words[3] : "")
  }

  if rest.contains("--rehearse") {
    var text = ""
    while let line = readLine(strippingNewline: false) { text += line }
    let walk: Walk
    do { walk = try Walk(text: text) } catch {
      complain("\(error)")
      return 64
    }
    var scene: WalkScene?
    if let path = option("--scene") {
      guard let samples = try? String(contentsOfFile: path, encoding: .utf8), let found = WalkScene(samples: samples) else {
        complain("\(path) holds no beginning of a walk")
        return 64
      }
      scene = found
    }
    let player = WalkPlayer(walk.setting, scene: scene, withoutArbor: rest.contains("--without-arbor"))
    let (quiet, script) = (rest.contains("--quiet"), rest.contains("--script"))
    if !quiet, !script { player.tell = say }
    Log.silenced { player.play(walk) }
    if script { for action in player.script { say(action.text) } }
    if let path = option("--samples") {
      do { try player.samples.text.write(toFile: path, atomically: true, encoding: .utf8) } catch {
        complain("cannot write \(path)")
        return 74
      }
    }
    if !script { for line in summary(of: player) { say(line) } }
    if rest.contains("--shrink") { for failure in Log.silenced({ player.shrunk() }) { say("\n\(failure)") } }
    return player.broken(known: false).isEmpty ? 0 : 1
  }

  if rest.first == "--many" {
    guard rest.count >= 4, let first = UInt64(rest[1]), let count = UInt64(rest[2]), let acts = Int(rest[3]) else {
      complain("--many <first> <count> <acts> [display] [tiling] [cast]")
      return 64
    }
    guard let base = setting([rest.count > 6 ? rest[6] : "stock", rest.count > 4 ? rest[4] : "laptop", rest.count > 5 ? rest[5] : "defaults"], seed: "") else { return 64 }
    var (played, leftOut, findings, struckOut) = (0, 0, 0, 0)
    var (kinds, rules, known, short): ([WalkKind: Int], [String: Int], [String: Int], [String: Int]) = ([:], [:], [:], [:])
    for seed in first..<(first + count) {
      var one = base
      one.seed = String(seed)
      let writer = Log.silenced { WalkWriter(one, acts: acts) }
      let counts = WalkWriter.counts(of: writer.player)
      played += writer.player.played.count
      leftOut += writer.player.leftOut.count
      findings += writer.player.findings
      struckOut += writer.wordsStruckOut
      for (kind, number) in counts { kinds[kind, default: 0] += number }
      for kind in WalkWriter.kinds where kind != .tileClick {
        let has = (counts[kind] ?? 0) + (kind == .drag ? counts[.dragWhereMacOSTiles] ?? 0 : 0)
        if has < WalkWriter.fewest(of: kind, in: acts) { short[kind.rawValue, default: 0] += 1 }
      }
      for rule in Set(writer.player.broken(known: false).map(\.violation.rule)).sorted() {
        rules[rule, default: 0] += 1
        if rules[rule]! <= 2, let found = writer.player.broken(known: false).first(where: { $0.violation.rule == rule }) {
          say("seed \(seed), act \(found.act.number) \(found.act.slug): \(found.violation)")
        }
      }
      for rule in Set(writer.player.broken(known: true).map(\.violation.rule)) { known[rule, default: 0] += 1 }
    }
    say("\(count) walks, \(played) acts, \(leftOut) left out, \(findings) findings of the script's own, \(struckOut) words struck out for one")
    say(WalkKind.ofActs.compactMap { kind in kinds[kind].map { "\(kind.rawValue) \($0)" } }.joined(separator: ", "))
    for (kind, walks) in short.sorted(by: { $0.key < $1.key }) { say("short of \(kind): \(walks) walks") }
    for (rule, walks) in rules.sorted(by: { $0.key < $1.key }) { say("RULE \(rule) in \(walks) walks") }
    for (rule, walks) in known.sorted(by: { $0.key < $1.key }) { say("known: \(rule) in \(walks) walks") }
    return rules.isEmpty ? 0 : 1
  }

  guard rest.count >= 6, let acts = Int(rest[1]), (20...400).contains(acts), ["--for-a-mac", "--words"].contains(rest[2]) else {
    complain("walk <seed> <acts, 20 to 400> --for-a-mac <cast> <display> <tiling> [commit]; or --words; or --rehearse; or --many")
    return 64
  }
  guard WalkSetting.isAPlainWord(rest[0]) else {
    complain("a seed is letters, digits, dots, dashes")
    return 64
  }
  guard let chosen = setting(rest[3...], seed: rest[0]) else { return 64 }
  let writer = Log.silenced { WalkWriter(chosen, acts: acts) }
  if writer.isResigned { complain("this walk holds an act at which an expectation of lib-walk.sh's does not hold on the stand-ins: too many had to be struck out") }
  if rest[2] == "--words" { for word in writer.walk.words { say(word.text) } } else { FileHandle.standardOutput.write(Data(writer.walk.text.utf8)) }
  return 0
}
