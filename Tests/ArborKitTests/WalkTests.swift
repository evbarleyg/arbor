import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Walks for a hosted Mac (`Walk.swift`): the words are lib-walk.sh's, the numbers docs/VIABLE.md's, a walk is a file that bash runs and nothing else, one seed is one
/// walk, and the playing on the stand-ins is the one that went with the writing.
///
/// What a seed's walk is depends on what Arbor does, since only acts that apply are written. So nothing here pins a walk down: a fix of Arbor's changes walks, rightly.
@Suite @MainActor struct WalkTests {
  private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  private static func file(_ path: String) throws -> String { try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) }

  private func written(_ seed: String, acts: Int = 60, display: WalkSetting.Display = .laptop, tiling: WalkSetting.Tiling = .defaults) -> WalkWriter {
    Log.silenced { WalkWriter(WalkSetting(display: display, tiling: tiling, seed: seed, commit: "0123456789abcdef"), acts: acts) }
  }

  private func rehearsed(_ walk: Walk, scene: WalkScene? = nil, withoutArbor: Bool = false) -> WalkPlayer {
    let player = WalkPlayer(walk.setting, scene: scene, withoutArbor: withoutArbor)
    Log.silenced { player.play(walk) }
    return player
  }

  // MARK: The contract

  /// The words of lib-walk.sh: the functions it defines that its header lists. There a word stands at the head of a column, after the margin, several spaces, a bar
  /// or a bracket; what stands in the middle of a sentence (a title bar "shows") is English.
  private func contract() throws -> Set<String> {
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    var spoken = Set<String>()
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).prefix(while: { $0.hasPrefix("#") }) {
      for column in line.dropFirst().replacingOccurrences(of: " | ", with: "   ").replacingOccurrences(of: " (", with: "   ").components(separatedBy: "  ") {
        spoken.insert(String(column.drop { $0 == " " }.prefix { $0.isLowercase || $0 == "_" }))
      }
    }
    let defined = text.split(separator: "\n").compactMap { line -> String? in
      guard let end = line.range(of: "() {"), line[..<end.lowerBound].allSatisfy({ $0.isLowercase || $0 == "_" }) else { return nil }
      return String(line[..<end.lowerBound])
    }
    return Set(defined).intersection(spoken)
  }

  @Test func everyWordOfLibWalksIsKnownHereAndEveryWordHereIsOneOfIts() throws {
    let theirs = try contract().subtracting(["walk_begin", "walk_end"])
    // `chapter` is lib-day.sh's, and the header says so.
    let ours = Set(WalkWord.oneOfEach.map(\.name)).subtracting(["chapter"])
    #expect(theirs.count > 40, "the header of lib-walk.sh was not read")
    #expect(theirs.subtracting(ours).sorted() == [], "lib-walk.sh has words that Walk.swift does not know: teach WalkWord and WalkPlayer")
    #expect(ours.subtracting(theirs).sorted() == [], "Walk.swift has words that lib-walk.sh does not play")
  }

  @Test func theCastIsLibWalks() throws {
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    for name in ["stock", "browsers", "awkward"] {
      let cast = try #require(RealApp.cast(name))
      for app in cast { #expect(text.contains("\(app.word)) echo \(app.bundleID) ;;"), "lib-walk.sh's bundle_of knows \(app.word) otherwise") }
      #expect(text.contains("\(name)) echo \(cast.map(\.word).joined(separator: " ")) ;;"), "the cast \(name) is another, or is opened in another order")
    }
    #expect(RealApp.cast("friends") == nil)
    #expect(text.contains("quicktime) echo \(try #require(RealApp.named("quicktime")).bundleID) ;;"))
    // In which apps ⌘N is a new window.
    let openers = try #require(try body(of: "open_new", in: text).range(of: "case \"$name\" in ").map { try body(of: "open_new", in: text)[$0.upperBound...].prefix { $0 != ")" } })
    #expect(Set(openers.components(separatedBy: " | ")) == Set(RealApp.all.filter(\.opensNewWindows).map(\.word)))
  }

  /// The body of a function of lib-walk.sh's.
  private func body(of function: String, in text: String) throws -> String {
    let start = try #require(text.range(of: "\n\(function)() {"), "lib-walk.sh has no \(function)")
    let end = try #require(text.range(of: "\n}", range: start.upperBound..<text.endIndex))
    // A function of one line ends on it.
    let line = text[start.upperBound...].prefix { $0 != "\n" }
    return line.hasSuffix("}") ? String(line) : String(text[start.upperBound..<end.lowerBound])
  }

  /// A key that is pressed on a Mac and the command that is played here are one thing only as long as the key is bound to the command. The command is what the player
  /// really plays; the chord is looked for in the word's own function, as a word of its own.
  @Test func theKeysLibWalkPressesAreBoundToTheCommandsPlayedHere() throws {
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    // The word, the function that presses its key, the chord as that function spells it, and the chord.
    let keys: [(word: WalkWord, function: String, written: String, chord: String)] = [
      (.dockKey(.left), "dock_key", "ctrl+opt+cmd+$1", "ctrl+opt+cmd+left"), (.dockKey(.right), "dock_key", "ctrl+opt+cmd+$1", "ctrl+opt+cmd+right"),
      (.dockKey(.up), "dock_key", "ctrl+opt+cmd+$1", "ctrl+opt+cmd+up"), (.dockKey(.down), "dock_key", "ctrl+opt+cmd+$1", "ctrl+opt+cmd+down"),
      (.focusKey(.left), "focus_key", "ctrl+opt+shift+$1", "ctrl+opt+shift+left"), (.focusKey(.right), "focus_key", "ctrl+opt+shift+$1", "ctrl+opt+shift+right"),
      (.focusKey(.up), "focus_key", "ctrl+opt+shift+$1", "ctrl+opt+shift+up"), (.focusKey(.down), "focus_key", "ctrl+opt+shift+$1", "ctrl+opt+shift+down"),
      (.rotate, "rotate", "ctrl+opt+r", "ctrl+opt+r"), (.mirror, "mirror", "ctrl+opt+shift+r", "ctrl+opt+shift+r"), (.resizeKey(.grow), "resize_key", "chord=ctrl+opt+cmd+=", "ctrl+opt+cmd+="),
      (.resizeKey(.shrink), "resize_key", "chord=ctrl+opt+cmd+-", "ctrl+opt+cmd+-"), (.resizeKey(.balance), "resize_key", "chord=ctrl+opt+cmd+0", "ctrl+opt+cmd+0"),
      (.view(.frame), "view", "chord=ctrl+opt+return", "ctrl+opt+return"), (.view(.out), "view", "chord=ctrl+opt+up", "ctrl+opt+up"), (.view(.in), "view", "chord=ctrl+opt+down", "ctrl+opt+down"),
      (.view(.left), "view", "chord=ctrl+opt+left", "ctrl+opt+left"), (.view(.right), "view", "chord=ctrl+opt+right", "ctrl+opt+right"), (.view(.back), "view", "ctrl+opt+[", "ctrl+opt+["),
      (.view(.forward), "view", "ctrl+opt+]", "ctrl+opt+]"), (.view(.desktop), "view", "chord=ctrl+opt+d", "ctrl+opt+d"), (.view(.all), "view", "chord=ctrl+opt+space", "ctrl+opt+space"),
      (.view(.home), "view", "chord=ctrl+opt+0", "ctrl+opt+0"), (.saveView(2), "save_view", "ctrl+opt+shift+$1", "ctrl+opt+shift+2"), (.viewN(2), "view_n", "ctrl+opt+$1", "ctrl+opt+2"),
      (.peek, "peek", "ctrl+opt+space", "ctrl+opt+space"), (.undo, "undo", "ctrl+opt+z", "ctrl+opt+z"), (.redo, "redo", "ctrl+opt+shift+z", "ctrl+opt+shift+z"),
      (.floatKey, "float_key", "ctrl+opt+f", "ctrl+opt+f"), (.arrangeKey, "arrange_key", "ctrl+opt+a", "ctrl+opt+a"), (.floatAll, "float_all", "ctrl+opt+shift+f", "ctrl+opt+shift+f"),
      (.pause, "pause", "ctrl+opt+escape", "ctrl+opt+escape"), (.resume, "resume", "ctrl+opt+escape", "ctrl+opt+escape"),
    ]
    let player = WalkPlayer(WalkSetting(seed: "keys"))
    Log.silenced {
      player.begin()
      for word in [WalkWord.switchDock("safari"), .dockKey(.left), .switchDock("notes"), .dockKey(.right)] { player.play(word) }
    }
    for key in keys {
      let mark = player.script.count
      // In a state in which it applies: everything in view, a docked window in front.
      Log.silenced {
        if key.word != .resume { for word in [WalkWord.view(.home), .switchDock("notes")] { player.play(word) } }
        if key.word == .floatKey || key.word == .resizeKey(.grow) { player.play(.dockKey(.right)) }
      }
      let before = player.script.count
      #expect(Log.silenced { player.play(key.word) }.acts == 1, "\(key.word) did not apply")
      let pressed = player.script[before...].compactMap { action -> String? in
        switch action {
        case .key(let command, .pressed): command
        // The one key the chaos lab plays as a command.
        case .command("toggle-pause"): "toggle-pause"
        default: nil
        }
      }
      let chord = try KeyChord(text: key.chord)
      let bound = try #require(KeyBindings.all.first { $0.chord == chord }, "\(key.chord) is bound to nothing").command.text
      #expect(pressed == [bound], "\(key.word): \(key.chord)")
      let spelt = try body(of: key.function, in: text).split { " \"\n;".contains($0) }.map(String.init)
      #expect(spelt.contains(key.written), "lib-walk.sh's \(key.function) does not press \(key.written)")
      _ = mark
    }
  }

  /// What is in Arbor's menu and on no key lib-walk.sh asks of `arborctl`, in the same words.
  @Test func whatLibWalkAsksOfArborctlIsAskedHere() throws {
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    let player = WalkPlayer(WalkSetting(display: .two, seed: "ctl"))
    Log.silenced {
      player.begin()
      for word in [WalkWord.display(.plug), .switchDock("safari"), .dockKey(.left)] { player.play(word) }
    }
    for (word, function, commands) in [
      (WalkWord.pin, "pin", ["toggle-pin"]), (.sendAcross, "send_across", ["move-to-display next"]), (.holdView, "hold_view", ["hold", "release"]), (.floatAllHere, "float_all_here", ["float-all here"]),
    ] {
      let before = player.script.count
      Log.silenced { _ = player.play(word) }
      #expect(player.script[before...].compactMap { if case .command(let line) = $0 { line } else { nil } } == commands, "\(word)")
      let asked = try body(of: function, in: text)
      for command in commands { #expect(asked.contains("must ctl \(command)"), "lib-walk.sh's \(function) does not ask for \(command)") }
    }
  }

  @Test func whatArborRefusesWasNotPerformedAndIsNotWritten() {
    // With nothing docked there is nothing to float, and `arborctl` fails.
    let player = rehearsed(Walk(setting: WalkSetting(seed: "1"), words: [.floatAllHere]))
    let act = player.played.first { $0.slug == "float-all-here" }
    #expect(act?.wasPerformed == false && player.findings == 1)
    #expect(player.samples.lines.contains { $0.contains(" act=way-out ") && $0.contains(" judge=no performed=no undone=ctl ") })
    for seed in 1...3 {
      let all = written("refused.\(seed)").player.played.allSatisfy { $0.wasPerformed }
      #expect(all, "a walk was written with an act that Arbor refuses")
    }
  }

  /// Every reason for which the player leaves an act out is lib-walk.sh's, word for word: read from the player's own source.
  @Test func everyReasonForLeavingAnActOutIsLibWalks() throws {
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    let source = try Self.file("Sources/ArborTesting/WalkPlayer+Words.swift")
    var reasons: [String] = []
    for piece in source.components(separatedBy: "leaveOut(\"").dropFirst() {
      let whole = piece.prefix { $0 != "\n" }
      let literal = try #require(whole.range(of: "\")", options: .backwards).map { String(whole[..<$0.lowerBound]) }, "\(whole)")
      // What follows the word and its arguments.
      reasons.append(String(try #require(literal.range(of: ": ", options: .backwards).map { literal[$0.upperBound...] }, "\(literal)")))
    }
    #expect(reasons.count > 55)
    for reason in reasons {
      // A name of the cast's in the middle of a sentence is `$1` or `$2` or `$name` there.
      let parts = reason.components(separatedBy: "\\(").flatMap { $0.split(separator: ")", maxSplits: 1).suffix(1) }.map(String.init).filter { $0.count > 3 }
      for part in parts.isEmpty ? [reason] : parts { #expect(text.contains(part.trimmingCharacters(in: .whitespaces)), "lib-walk.sh gives no such reason: \(reason)") }
    }
  }

  // MARK: The words as text

  @Test func aWordIsReadAsItIsWritten() {
    let more: [WalkWord] = [
      .restore("mail"), .unhide("notes"), .dragBy("finder", -190, 27, click: true), .fullScreen(false), .switchCmdTab(3), .resizeEdge("notes", .top, -30),
      .view(.in), .display(.smaller), .chapter("After lunch 2"),
    ]
    for word in WalkWord.oneOfEach + more { #expect(WalkWord(text: word.text) == word, "\(word.text)") }
    #expect(WalkWord(text: "switch_cmdtab") == .switchCmdTab(1))
    #expect(WalkWord(text: "tile_click") == .tileClick(1))
  }

  @Test func whatIsNoWordOfTheContractsIsNotRead() {
    for line in [
      "", "rm -rf /", "sleep 5", "arborctl set gap 30", "ctl quit", "switch_dock nobody", "switch_dock", "switch_dock safari notes", "view sideways", "dock_key top",
      "drag_by safari 1 2 clack", "drag_by safari 1", "drag_by safari $(id) 2", "save_view 0", "save_view 10", "quit_app", "chapter \"$(id)\"", "chapter \"a\"; id", "chapter noon",
      "key cmd+q", "idle_act 900", "walk_begin stock laptop defaults 1",
    ] { #expect(WalkWord(text: line) == nil, "`\(line)` was taken for a word") }
  }

  @Test func aWalkIsAFileThatBashRunsAndNothingElse() throws {
    let walk = Walk(
      setting: WalkSetting(display: .desk, tiling: .off, seed: "f1240ac3.7", commit: "f1240ac3"), words: [.switchDock("safari"), .dockKey(.left), .idleAct], head: ["A walk"],
      foot: ["3 acts"])
    #expect(try Walk(text: walk.text) == walk)
    #expect(walk.text.hasPrefix("#!/bin/bash\n# A walk\nsource \"$(dirname \"${BASH_SOURCE[0]}\")/lib-walk.sh\"\nwalk_begin stock desk off f1240ac3.7 f1240ac3\nswitch_dock safari\n"))
    #expect(walk.text.hasSuffix("idle_act\nwalk_end\n# 3 acts\n"))
    // lib-walk.sh's own example.
    let example = "#!/bin/bash\nsource \"$(dirname \"$0\")/lib-walk.sh\"\nwalk_begin stock laptop defaults 4711\nswitch_dock safari;  dock_key left\nview frame;  idle_act\nwalk_end\n"
    #expect(try Walk(text: example).words == [.switchDock("safari"), .dockKey(.left), .view(.frame), .idleAct])

    let head = "#!/bin/bash\n\(walk.text.split(separator: "\n")[2])\n"
    for (text, why) in [
      (head + "walk_begin stock laptop defaults 1\nsleep 5\nwalk_end\n", "a sleep of its own"),
      (head + "walk_begin stock laptop defaults 1\nidle_act && id\nwalk_end\n", "more shell on a line"),
      (head + "walk_begin stock laptop defaults 1\nidle_act\nwalk_end\nid\n", "a line after the end"),
      (head + "walk_begin stock laptop defaults 1\nidle_act\n", "no end"),
      (head + "idle_act\nwalk_end\n", "no beginning"),
      (head + "walk_begin stock laptop defaults $(id)\nwalk_end\n", "a seed that is shell"),
      (head + "walk_begin stock cinema defaults 1\nwalk_end\n", "no such display"),
      (head + "walk_begin friends laptop defaults 1\nwalk_end\n", "no such cast"),
      (head + "export WALK_LIMIT=9999\nwalk_begin stock laptop defaults 1\nwalk_end\n", "a variable"),
      ("#!/bin/bash\nwalk_begin stock laptop defaults 1\nwalk_end\n", "lib-walk.sh is not sourced"),
      ("#!/bin/bash\nsource /tmp/other.sh\nwalk_begin stock laptop defaults 1\nwalk_end\n", "something else is sourced"),
    ] { #expect(throws: Walk.Unreadable.self, "\(why) was taken") { try Walk(text: text) } }
  }

  // MARK: The numbers

  @Test func theMixtureIsThePages() throws {
    let page = try Self.file("docs/VIABLE.md")
    let start = try #require(page.range(of: "```json\n")), end = try #require(page.range(of: "\n```", range: start.upperBound..<page.endIndex))
    let gate = try #require(try JSONSerialization.jsonObject(with: Data(page[start.upperBound..<end.lowerBound].utf8)) as? [String: Any])
    let fewest = try #require(gate["acts_min"] as? [String: Int])
    #expect(fewest == Dictionary(uniqueKeysWithValues: WalkWriter.fewestInAGate.map { ($0.key.rawValue, $0.value) }), "docs/VIABLE.md's acts_min has changed: WalkWriter.fewestInAGate follows it")
    #expect(Set(fewest.keys) == Set(WalkKind.ofActs.map(\.rawValue)))
    #expect(gate["share_of_acts_from_walks_min"] as? Double == 0.5)
    // What one walk of 110 acts has to have, so that twenty-two of them bring half of each number.
    let inOneWalk: [WalkKind: Int] = [
      .switch: 11, .openClose: 7, .dockKey: 4, .drag: 6, .dragWhereMacOSTiles: 2, .view: 10, .resize: 2, .wayOut: 2, .quitAndStart: 1, .idle: 1, .tileClick: 1, .macOSOwn: 0, .displayChange: 0,
    ]
    for (kind, number) in inOneWalk { #expect(WalkWriter.fewest(of: kind, in: 110) == number, "\(kind.rawValue)") }
  }

  @Test func aFewWalksTogetherHaveTheirShareOfEveryKindAndHardlyAnActIsLeftOut() throws {
    let acts = 110
    let writers = (1...4).map { written("share.\($0)", acts: acts, display: $0 % 2 == 0 ? .desk : .laptop, tiling: $0 > 2 ? .off : .defaults) }
    var counts: [WalkKind: Int] = [:]
    for writer in writers { for (kind, number) in WalkWriter.counts(of: writer.player) { counts[kind, default: 0] += number } }
    counts[.drag, default: 0] += counts[.dragWhereMacOSTiles] ?? 0
    // A tile cannot be had for the asking.
    for kind in WalkWriter.kinds + [.quitAndStart] where kind != .tileClick {
      #expect(counts[kind] ?? 0 >= WalkWriter.fewest(of: kind, in: acts) * writers.count, "\(kind.rawValue): \(counts[kind] ?? 0) in \(writers.count) walks")
    }
    let played = writers.reduce(0) { $0 + $1.player.played.count }
    #expect(abs(played - acts * writers.count) <= 6 * writers.count, "\(played) acts in \(writers.count) walks of \(acts)")
    #expect(writers.reduce(0) { $0 + $1.player.leftOut.count } * 20 <= played, "more than one act in twenty was left out on the very stand-ins it was written on")
    #expect(writers.allSatisfy { $0.player.findings == 0 }, "a walk was written at which the script's own expectations do not hold")
    // A run has 600 seconds. On a hosted Mac the scene took 62, the four rounds of input 48, an act 2.1 and 0.6 until the next (a drag more: say 3), one in which nothing is done 31.
    for writer in writers {
      let idle = WalkWriter.counts(of: writer.player)[.idle] ?? 0
      #expect(62 + 48 + 3 * Double(writer.player.played.count - idle) + 31 * Double(idle) < 0.9 * 600)
    }
  }

  // MARK: One seed, one walk

  @Test func theSameSeedWritesTheSameWalkAndAnotherSeedAnother() {
    let one = written("f1240ac3.1")
    let (same, other) = (one.walk == written("f1240ac3.1").walk, one.walk.words != written("f1240ac3.2").walk.words)
    #expect(same && other)
    #expect(WalkWriter.number(for: "a") == 0xAF63_DC4C_8601_EC8C, "FNV-1a of `a`: a seed means the same number everywhere")
  }

  @Test func theFileIsReadBackAndPlayedAsItWasWhenItWasWritten() throws {
    for (seed, tiling) in [("round.1", WalkSetting.Tiling.defaults), ("round.2", .off)] {
      let writer = written(seed, tiling: tiling)
      let walk = try Walk(text: writer.walk.text)
      #expect(walk == writer.walk)
      let player = rehearsed(walk)
      // Words that were tried and did not apply have left nothing behind. (Compared first: `#expect` takes minutes to look into values this large.)
      let (sameEvents, sameSamples, sameStory) = (player.script == writer.player.script, player.samples.text == writer.player.samples.text, player.story == writer.player.story)
      #expect(sameEvents && player.script.count > 300, "the file is played otherwise than it was when it was written")
      #expect(sameSamples, "another screen was written down")
      #expect(sameStory, "another story was told")
      // And the events are a script of the chaos lab's, which reads them as they were.
      let readBack = ChaosAction.script(player.script.map(\.text).joined(separator: "\n")) == player.script
      #expect(readBack, "an event is not read as it is written")
    }
  }

  // MARK: What a walk does, and what it never does

  @Test func aWalkIsWhatAPersonCouldDoAndOfTheFirstVersionsWords() {
    let left: Set<String> = [
      "display", "send_across", "move_to_display", "hide", "unhide", "full_screen", "wallpaper_click", "title_double_click", "summon", "release_view", "chapter",
    ]
    for seed in 1...6 {
      let writer = written("person.\(seed)", acts: 110)
      let words = writer.walk.words
      #expect(Set(words.map(\.name)).isDisjoint(with: left))
      #expect(!words.contains(.quitApp("finder")), "⌘Q in the Finder")
      #expect(words.filter { $0 == .quitAndStart }.count == 1)
      #expect(words.filter { $0 == .idleAct }.count <= 4)
      // What belongs together stays near each other, and nothing is owed at the end.
      let slugs = writer.player.played.map(\.slug)
      for (opens, closes) in [("pause", "resume"), ("minimize-", "restore-"), ("quit-", "reopen-")] {
        var open: [String: Int] = [:]
        for (index, slug) in slugs.enumerated() {
          if slug.hasPrefix(opens) { open[String(slug.dropFirst(opens.count))] = index }
          if slug.hasPrefix(closes), let since = open.removeValue(forKey: String(slug.dropFirst(closes.count))) {
            #expect(index - since <= 16, "\(opens) at \(since), \(closes) only at \(index)")
          }
          // Quitting Arbor ends a pause.
          if slug == "quit" { open[""] = nil }
        }
        #expect(open.isEmpty, "\(opens)\(open.keys.sorted()) and never \(closes)")
      }
    }
  }

  // MARK: Somebody who does not know Arbor

  /// `collab/IDEAS.md`, I25: Arbor runs, and nothing is asked of it.
  @Test func aStrangerAsksNothingOfArbor() {
    let macOSsAndTheApps: Set<String> = [
      "switch_dock", "switch_click", "switch_to", "switch_cmdtab", "switch_backtick", "switch_menu", "open_new", "close_new", "minimize", "restore", "hide", "unhide", "quit_app", "reopen",
      "drag_by", "drag_edge", "title_double_click", "full_screen", "idle_act",
    ]
    var seen = Set<String>()
    for seed in 1...4 {
      let writer = Log.silenced { WalkWriter(WalkSetting(tiling: seed % 2 == 0 ? .off : .defaults, seed: "stranger.\(seed)"), acts: 90, walker: .stranger) }
      let names = Set(writer.walk.words.map(\.name))
      #expect(names.isSubset(of: macOSsAndTheApps), "\(names.subtracting(macOSsAndTheApps).sorted()) is asked of Arbor")
      seen.formUnion(names)
      // Arbor is started before the first act and quit after the last, and that is all anybody does to it.
      #expect(writer.player.played.filter { $0.kind == .quitAndStart }.map(\.slug) == ["launch", "quit"])
      #expect(writer.player.script.allSatisfy { action in
        switch action {
        case .key, .via, .url, .tile, .seam, .palette: false
        case .command(let line): line == "quit"
        default: true
        }
      }, "a key, a command or a click of Arbor's was played")
      #expect(writer.walk.head.contains { $0.hasSuffix("--stranger") })
      #expect(abs(writer.player.played.count - 90) <= 4)
    }
    // All of it comes up in a few walks.
    #expect(seen.isSuperset(of: ["drag_by", "drag_edge", "title_double_click", "full_screen", "hide", "minimize", "open_new", "quit_app", "switch_cmdtab"]), "\(seen.sorted())")
  }

  /// Somebody arranged two windows once. From then on nothing is asked of Arbor, and what is docked is double-clicked, minimized and hidden like anything else.
  @Test func aStrangerMayFindWindowsDocked() {
    var touched = false
    for seed in 1...3 {
      let writer = Log.silenced { WalkWriter(WalkSetting(seed: "docked.\(seed)"), acts: 80, walker: .stranger, docked: 2) }
      let keys = writer.walk.words.enumerated().filter { $0.element.name == "dock_key" }
      #expect(keys.map(\.element) == [.dockKey(.left), .dockKey(.right)] && keys.allSatisfy { $0.offset < 4 }, "\(writer.walk.words.prefix(5))")
      let arbors: Set<String> = ["float_key", "arrange_key", "undo", "redo", "view", "pause", "float_all", "drag_onto", "drag_out", "resize_gap", "resize_key", "tile_click", "quit_and_start", "pin"]
      #expect(Set(writer.walk.words.map(\.name)).isDisjoint(with: arbors))
      #expect(writer.walk.head.contains { $0.hasSuffix("--stranger --docked 2") })
      let docked = writer.walk.words.prefix(4).compactMap { word -> String? in if case .switchTo(let app) = word { app } else { nil } }
      if writer.walk.words.dropFirst(4).contains(where: { word in docked.contains { word == .titleDoubleClick($0) } }) { touched = true }
    }
    #expect(touched, "in three walks no docked window's title bar was double-clicked")
  }

  /// The control of a stranger's walk is the whole walk: there is nothing of Arbor's in it to leave out.
  @Test func withoutArborAStrangersWalkIsPlayedToo() {
    let writer = Log.silenced { WalkWriter(WalkSetting(seed: "stranger.control"), acts: 70, walker: .stranger) }
    let control = rehearsed(writer.walk, withoutArbor: true)
    #expect(!control.leftOut.contains { $0.hasSuffix("Arbor is not acting") || $0.hasSuffix("Arbor is not running") })
    // But Arbor's start, its Quit, and the calling up of every app that belongs to the Quit.
    let journey = writer.player.played.count - 2 - writer.player.cast.count
    #expect(control.played.count * 10 >= journey * 9 && control.played.count <= journey + 2, "\(control.played.count) of \(journey) acts were played without Arbor")
  }

  /// As hosted Macs were seen to: Calendar and Terminal fill the space between the menu bar and the Dock, a Finder window shrinks to what it holds, and the second double-click
  /// takes each back to the very frame.
  /// The act says which window macOS zooms. On a Mac the clicks go to the free point of the title bar that `apptool grab` finds; so they do here, and not to the middle of the
  /// bar, where whoever lies over it would get them and be zoomed.
  @Test func aDoubleClickReachesTheWindowItNamesWhereverItsTitleBarShows() throws {
    let player = WalkPlayer(WalkSetting(seed: "double"))
    Log.silenced { player.begin() }
    let (safari, notes) = (try #require(player.window(labelled: "safari")), try #require(player.window(labelled: "notes")))
    func frames() -> [WindowID: CGRect] { player.runner.system.windows.mapValues(\.snapshot.frame) }
    // Notes lies over the middle of Safari's title bar; to either side of it the bar shows.
    for line in ["move \(safari.rawValue) 100 100 1400 600", "move \(notes.rawValue) 450 60 709 320", "focus \(safari.rawValue)", "focus \(notes.rawValue)"] {
      _ = player.runner.step(ChaosAction(text: line))
    }
    let before = frames()
    let outcome = Log.silenced { player.play(.titleDoubleClick("safari")) }
    #expect(outcome.acts == 2 && !outcome.leftOut)
    #expect(player.samples.lines.filter { $0.contains(" zooms=\(safari.rawValue) ") }.count == 2)
    // There and back, and nobody else has stirred in between: Safari was seen as large as the screen, Notes never.
    #expect(frames() == before)
    #expect(player.samples.lines.contains { $0.contains(" W \(safari.rawValue) ") && $0.contains(" 0 31 1600 791 ") })
    #expect(!player.samples.lines.contains { $0.contains(" W \(notes.rawValue) ") && $0.contains(" 1600 791 ") })
    // The lab's own double-click, with the pointer elsewhere, goes to the middle as it did: there it is Notes that gets it.
    for line in ["focus \(notes.rawValue)", "cursor 20 880", "double-click \(safari.rawValue)"] { _ = player.runner.step(ChaosAction(text: line)) }
    #expect(frames()[safari] == before[safari] && frames()[notes] != before[notes])
  }

  @Test func macOSZoomsAWindowAtADoubleClickOnItsTitleBarAndTakesItBack() {
    let runner = ChaosRunner()
    for line in [
      "displays main:0,0,1600,900:31,0,78,0* windows-never", "open 101 Calendar pid 2001 at 386 118 680 599 min 680 503", "open 102 Terminal pid 2002 at 806 238 793 499 cells 7 15 2 4",
      "open 103 Finder pid 2003 at 806 31 794 297 min 501 252 ideal 551 252", "open 104 Calculator pid 2004 at 350 411 230 408 min 230 408 max 230 408",
      "open 105 Settings pid 2005 at 437 85 723 625 min 723 470 max 723 2000",
    ] { _ = runner.step(ChaosAction(text: line)) }
    func frame(_ id: UInt32) -> CGRect? { runner.system.frame(of: WindowID(id)) }
    for (window, before, zoomed) in [
      (101 as UInt32, CGRect(x: 386, y: 118, width: 680, height: 599), CGRect(x: 0, y: 31, width: 1600, height: 791)),
      (102, CGRect(x: 806, y: 238, width: 793, height: 499), CGRect(x: 0, y: 31, width: 1598, height: 784)),
      (103, CGRect(x: 806, y: 31, width: 794, height: 297), CGRect(x: 806, y: 31, width: 551, height: 252)),
    ] {
      #expect(frame(window) == before)
      runner.system.zoomAsMacOSDoes(WindowID(window))
      #expect(frame(window) == zoomed, "w\(window)")
      runner.system.zoomAsMacOSDoes(WindowID(window))
      #expect(frame(window) == before, "w\(window) is not taken back")
    }
    // Moved since, it is zoomed afresh, and goes back to where it was moved to.
    runner.system.zoomAsMacOSDoes(WindowID(101))
    _ = runner.step(ChaosAction(text: "move 101 100 100 700 600"))
    runner.system.zoomAsMacOSDoes(WindowID(101))
    #expect(frame(101) == CGRect(x: 0, y: 31, width: 1600, height: 791))
    runner.system.zoomAsMacOSDoes(WindowID(101))
    #expect(frame(101) == CGRect(x: 100, y: 100, width: 700, height: 600))
    // One size only: there is nothing to zoom to, and it stays where it is.
    runner.system.zoomAsMacOSDoes(WindowID(104))
    #expect(frame(104) == CGRect(x: 350, y: 411, width: 230, height: 408))
    // As wide as it is, whatever anybody asks: it grows where it stands, and does not jump to the corner.
    runner.system.zoomAsMacOSDoes(WindowID(105))
    #expect(frame(105) == CGRect(x: 437, y: 31, width: 723, height: 791))
    // Whole characters that fit, where the nearest would reach under the Dock: 52 rows are 784 points, 53 are 799, and there are 795.
    _ = runner.step(ChaosAction(text: "displays main:0,0,1600,900:31,0,74,0* windows-never"))
    runner.system.zoomAsMacOSDoes(WindowID(102))
    #expect(frame(102)?.height == 784)
    // Its app reports once.
    let heard = ChaosRunner()
    for line in ["open 101 Calendar pid 2001 at 386 118 680 599", "launch", "settle"] { _ = heard.step(ChaosAction(text: line)) }
    let moves = heard.system.windows[WindowID(101)]!.movesNotArbors
    _ = heard.step(.doubleClick(WindowID(101)))
    #expect(heard.system.windows[WindowID(101)]!.movesNotArbors == moves + 1)
    guard case .open(let finder) = ChaosAction(text: "open 103 Finder pid 2003 at 806 31 794 297 ideal 551 252") else {
      Issue.record("`ideal` is not read")
      return
    }
    #expect(finder.ideal == CGSize(width: 551, height: 252))
  }

  @Test func anActThatDoesNotApplyIsLeftOutForLibWalksReason() throws {
    let walk = Walk(
      setting: WalkSetting(seed: "1"),
      words: [
        .floatKey, .closeNew, .restore(nil), .resume, .dragOut("safari"), .dragOnto("mail", "mail", .left), .quitApp("finder"), .reopen("safari"), .tileClick(1), .display(.plug),
        .summon("notes"), .pause, .dockKey(.left), .view(.all), .resume,
      ])
    let player = rehearsed(walk)
    #expect(
      player.leftOut == [
        "float_key: the window in front is not docked", "close_new: no window that open_new opened is within reach", "restore: nothing is minimized",
        "resume: Arbor is not paused", "drag_out safari: it is not docked and in reach", "drag_onto mail mail left: nothing to take hold of",
        "quit_app finder: only apps whose document can be opened again", "reopen safari: it was not quit", "tile_click 1: no such tile stands in for a window",
        "display plug: this walk has one display", "summon notes: not played yet", "dock_key left: Arbor is not acting", "view all: Arbor is not acting",
      ])
    // Each of those sentences is lib-walk.sh's own.
    let text = try Self.file("scripts/mac-shell/lib-walk.sh")
    for reason in player.leftOut {
      let words = reason.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces)
      #expect(text.contains(words), "lib-walk.sh gives no such reason: \(words)")
    }
    #expect(player.played.map(\.slug) == ["launch", "pause", "resume", "quit"] + RealApp.stock.map { "dock-icon-\($0.word)" })
  }

  /// As two hosted Macs without Arbor had it, alike to the point.
  @Test func whatAnAppMakesOfANewWindowAndOfAZoomIsItsOwnToSay() throws {
    let walk = Walk(setting: WalkSetting(seed: "1"), words: [.switchDock("textedit"), .openNew, .switchDock("preview"), .titleDoubleClick("preview"), .switchDock("safari"), .openNew])
    let player = rehearsed(walk, withoutArbor: true)
    func frame(_ label: String) throws -> CGRect? { player.runner.system.frame(of: try #require(player.window(labelled: label), "\(label): \(player.played.map(\.slug))")) }
    let new = try #require(player.samples.text.split(separator: "\n").compactMap { line in line.split(separator: " ").last.flatMap { $0.hasPrefix("textedit-new-") ? String($0) : nil } }.first)
    // An empty document has its own size, a step down and to the right of the window in front.
    #expect(try frame("textedit") == CGRect(x: 165, y: 65, width: 673, height: 439))
    #expect(try frame(new) == CGRect(x: 194, y: 94, width: 603, height: 505))
    // Preview is as large as its picture wants it.
    #expect(player.played.map(\.slug).contains("double-click-preview"))
    #expect(try frame("preview") == CGRect(x: 4, y: 35, width: 708, height: 424))
    // A browser's is as large as the one in front.
    let safari = try #require(player.samples.text.split(separator: "\n").compactMap { line in line.split(separator: " ").last.flatMap { $0.hasPrefix("safari-new-") ? String($0) : nil } }.first)
    #expect(try frame(safari)?.size == CGSize(width: 1324, height: 791))
  }

  @Test func withoutArborItsOwnActsAreLeftOutAndTheRestIsPlayed() {
    let walk = Walk(setting: WalkSetting(seed: "1"), words: [.switchDock("safari"), .dockKey(.left), .view(.all), .dragBy("safari", 40, 60, click: false), .quitAndStart, .idleAct])
    let player = rehearsed(walk, withoutArbor: true)
    #expect(player.played.map(\.slug) == ["dock-icon-safari", "drag-safari-by", "leave-alone"])
    #expect(player.leftOut.count == 3)
    #expect(!player.samples.text.contains(" M arbor "))
    #expect(!player.script.contains(.launch))
  }

  @Test func theOtherCastsHaveWhatTheyAreThereFor() throws {
    let browsers = rehearsed(Walk(setting: WalkSetting(cast: .browsers, seed: "1"), words: [.switchDock("chrome"), .switchBacktick]))
    #expect(browsers.acts.filter(\.isSetup).map(\.slug).filter { $0.hasPrefix("second-window-") } == ["safari", "chrome", "firefox", "edge"].map { "second-window-\($0)" })
    #expect(browsers.played.contains { $0.slug == "cmd-backtick" }, "a browser has two windows")

    let words: [WalkWord] = [.switchDock("stickies"), .minimize, .switchDock("calculator"), .dockKey(.left), .switchDock("finder"), .switchBacktick]
    let awkward = rehearsed(Walk(setting: WalkSetting(cast: .awkward, seed: "1"), words: words))
    #expect(awkward.acts.filter(\.isSetup).map(\.slug).suffix(7).prefix(4) == ["tab-finder", "tab-terminal", "open-quicktime", "panel-textedit"])
    #expect(awkward.leftOut == ["minimize: stickies's window cannot be minimized"])
    // Two windows to Accessibility, one on the screen: ⌘` is pressed, and leads nowhere.
    #expect(awkward.played.contains { $0.slug == "cmd-backtick" })
    let marks = awkward.samples.text
    #expect(marks.contains(" finder-tab-behind\n") && marks.contains(" stickies-2\n"))
    // TextEdit has an open panel up there: the quiet half of a round of input is played in Safari.
    #expect(awkward.story.contains { $0.hasSuffix("the rest in safari") } && !awkward.story.contains { $0.hasSuffix("the rest in textedit") })
    #expect(browsers.story.contains { $0.hasSuffix("the rest in textedit") })
    // The tab that stands for Terminal from then on comes in characters like the window it opened in.
    let terminal = try #require(awkward.window(of: "terminal").flatMap { awkward.runner.system.windows[$0] })
    #expect(terminal.sizeStep == CGSize(width: 7, height: 15) && terminal.sizeMargin == CGSize(width: 2, height: 4))

    // One size only, whatever Arbor asks: while it is docked, with half a screen for a slot.
    let docked = WalkPlayer(WalkSetting(cast: .awkward, seed: "1"))
    Log.silenced {
      docked.begin()
      for word in [WalkWord.switchDock("calculator"), .dockKey(.left)] { docked.play(word) }
    }
    let calculator = try #require(docked.window(of: "calculator"))
    #expect(docked.isDocked(calculator) && docked.runner.system.frame(of: calculator)?.size == CGSize(width: 230, height: 408))

    // And TextEdit is left alone: no word of a walk names it.
    for seed in 1...3 {
      let written = Log.silenced { WalkWriter(WalkSetting(cast: .awkward, seed: "panel.\(seed)"), acts: 90) }.walk.words
      #expect(!written.contains { $0.text.contains("textedit") }, "\(written.filter { $0.text.contains("textedit") })")
    }
  }

  /// A click in the Dock brings all of an app's windows forward, not only the one that gets the keyboard.
  @Test func anAppComesForwardWithAllItsWindows() throws {
    let player = WalkPlayer(WalkSetting(cast: .browsers, seed: "1"))
    Log.silenced {
      player.begin()
      for word in [WalkWord.switchDock("finder"), .switchDock("chrome")] { player.play(word) }
    }
    let pile = player.runner.system.windowsFrontToBack().prefix(2).compactMap { player.labels[$0] }
    #expect(Set(pile) == ["chrome", "chrome-2"], "\(pile)")
    #expect(ChaosAction(text: "app-forward 2002") == .appForward(pid: 2002) && ChaosAction.appForward(pid: 2002).text == "app-forward 2002")
  }

  @Test func macOSsTilingIsSeenToActOrNotToBeforeAnythingCounts() {
    for (tiling, acts) in [(WalkSetting.Tiling.defaults, true), (.off, false)] {
      let player = rehearsed(Walk(setting: WalkSetting(tiling: tiling, seed: "1"), words: []))
      #expect(player.story.contains("macOS's tiling was seen to act: \(acts)"))
      #expect(player.samples.text.contains(" M tiling \(tiling.rawValue)\n"))
    }
  }

  // MARK: What is written down for the judge

  @Test func theSamplesAreInTheSamplersGrammarWithLibDaysMarks() throws {
    let player = written("grammar.1", acts: 80).player
    let lines = player.samples.lines.map { $0.split(separator: " ").map(String.init) }
    var (last, open, labelled, steps) = (0, nil as String?, Set<String>(), 0)
    for words in lines {
      let time = try #require(Int(words[0]))
      #expect(time >= last, "time goes backwards at \(words.joined(separator: " "))")
      last = time
      switch words[1] {
      case "W": #expect(words.count == 10 && words[2...8].allSatisfy { Double($0) != nil })
      case "G": #expect(words.count == 3)
      case "Z": #expect(words.count == 3 && words[2].split(separator: ",").allSatisfy { UInt32($0) != nil })
      case "A": #expect(words.count == 4 && words[3].hasPrefix("com.apple."))
      case "B": #expect(words.count == 5 && ["down", "up"].contains(words[2]))
      case "P": #expect(words.count == 4)
      case "K": #expect(words == [words[0], "K", "1"])
      case "D", "V": #expect(words.count == 6)
      case "S": #expect(words == lines.last)
      case "M":
        switch words[2] {
        case "label": labelled.insert(words[3])
        case "begin":
          #expect(open == nil)
          open = words[3]
          steps += 1
          #expect(words[3] == String(steps))
        case "end":
          #expect(open == words[3])
          open = nil
          #expect(WalkKind(rawValue: String(try #require(words.first { $0.hasPrefix("act=") }).dropFirst(4))) != nil)
          #expect(words.contains { $0.hasPrefix("settled=quiet:") || $0.hasPrefix("settled=restless:") })
          for word in words where ["front=", "drags=", "comes=", "own=", "restores="].contains(where: word.hasPrefix) {
            let value = word.split(separator: "=")[1]
            if value != "all" { #expect(value.split(separator: ",").allSatisfy { labelled.contains(String($0)) }, "\(word) names a window without a label") }
          }
        default: #expect(["text", "chapter", "tiling", "arbor", "finding"].contains(words[2]), "\(words[2]) is no mark that jolts.py reads")
        }
      default: Issue.record("\(words[1]) is no kind of line of the sampler's")
      }
    }
    #expect(open == nil && steps == player.acts.count)
    // Nothing is said to have been posted: there is no witness here to say that it arrived, and the judge would take it for held back.
    #expect(!player.samples.text.contains(" posted="))
    // Never a title: windows go by the cast's names.
    #expect(!player.samples.text.contains("Safari 1"))
  }

  @Test func aPlayingBeginsWhereARunOnAMacBegan() throws {
    let samples = """
      1000 A 10 com.apple.finder
      1000 D 0 0 1600 900
      1000 V 0 31 1600 780
      1000 W 6 339 20 0 0 1600 900 Dock
      1100 M begin 1 open-finder
      1200 W 433 10 0 340 120 920 436 Finder
      1200 Z 433
      1200 M label 433 finder
      1300 M end 1 act=open-close settled=quiet:100 setup=1
      1400 M begin 2 open-calendar
      1500 W 454 11 0 386 118 908 599 Calendar
      1500 Z 433,454
      1500 M label 454 calendar
      1600 M end 2 act=open-close settled=quiet:100 setup=1
      1700 M begin 3 tiling-acts
      1750 A 11 com.apple.iCal
      1800 W 454 11 0 0 31 1600 780 Calendar
      1800 Z 454,433
      1900 M end 3 act=drag-where-macos-tiles settled=quiet:100 setup=1
      2000 M begin 4 tiling-acts-back
      2100 W 454 11 0 415 115 909 600 Calendar
      2200 M end 4 act=drag-where-macos-tiles settled=quiet:100 setup=1
      2300 M begin 5 look-around
      2400 W 454 11 0 1 2 3 4 Calendar
      """
    let scene = try #require(WalkScene(samples: samples))
    #expect(scene.frame == CGRect(x: 0, y: 0, width: 1600, height: 900) && scene.visible == CGRect(x: 0, y: 31, width: 1600, height: 780))
    #expect(scene.windows.map(\.app) == ["finder", "calendar"])
    #expect(scene.windows.map(\.frame) == [CGRect(x: 340, y: 120, width: 920, height: 436), CGRect(x: 386, y: 118, width: 908, height: 599)])
    #expect(scene.atTheStart["calendar"] == CGRect(x: 415, y: 115, width: 909, height: 600))
    #expect(scene.pile == ["calendar", "finder"] && scene.recent == ["calendar", "finder"])
    // What a cast has besides its apps' first windows is read too.
    let second = samples.replacingOccurrences(of: "1700 M begin 3", with: "1650 W 480 10 0 60 70 400 300 Finder\n1650 Z 480,433,454\n1650 M label 480 finder-2\n1700 M begin 3")
    #expect(WalkScene(samples: second)?.atTheStart["finder-2"] == CGRect(x: 60, y: 70, width: 400, height: 300))
    #expect(WalkScene(samples: second)?.windows.map(\.app) == ["finder", "calendar"])
    #expect(WalkScene(samples: "1000 D 0 0 1600 900\n") == nil)
    // An app swaps the window it opened with for another, and the script gives that one the name.
    let swapped = samples.replacingOccurrences(of: "1700 M begin 3", with: "1650 G 433\n1650 W 470 10 0 30 40 500 300 Finder\n1650 Z 470,454\n1650 M label 470 finder\n1700 M begin 3")
    #expect(WalkScene(samples: swapped)?.windows.first?.frame == CGRect(x: 30, y: 40, width: 500, height: 300))

    let player = rehearsed(Walk(setting: WalkSetting(seed: "1"), words: []), scene: scene)
    #expect(player.cast == ["finder", "calendar"])
    let launch = try #require(player.samples.lines.firstIndex { $0.hasSuffix("M begin 7 launch") })
    #expect(player.samples.lines[..<launch].last { $0.contains(" W 102 ") }?.hasSuffix("0 415 115 909 600 Calendar") == true)
  }

  // MARK: What the chaos lab got with it

  @Test func theNewWordsOfAScriptAreReadAsTheyAreWritten() {
    for line in [
      "mac-tiling on", "mac-tiling off", "open 101 Safari pid 2001 at 138 31 1324 790 min 574 240 bundle com.apple.Safari",
      "open 104 Terminal pid 2004 at 97 238 877 499 min 177 64 bundle com.apple.Terminal cells 7 15 2 4",
    ] {
      #expect(ChaosAction(text: line).text == line)
    }
    #expect(ChaosAction(text: "mac-tiling off") == .macTiling(on: false))
    guard case .open(let terminal) = ChaosAction(text: "open 104 Terminal pid 2004 at 97 238 877 499 cells 7 15 2 4") else {
      Issue.record("`cells` is not read")
      return
    }
    #expect(terminal.cells == RealApp.Cells(step: CGSize(width: 7, height: 15), margin: CGSize(width: 2, height: 4)))
    guard case .open(let new) = ChaosAction(text: "open 101 Safari pid 2001 at 1 2 3 4 bundle com.apple.Safari") else {
      Issue.record("no window")
      return
    }
    #expect(new.bundleID == "com.apple.Safari")
    let runner = ChaosRunner()
    #expect(runner.system.tiling == .on)
    _ = runner.step(.macTiling(on: false))
    #expect(runner.system.tiling == .off)
  }

  /// What Terminal answered on hosted Macs, question by question.
  @Test func aTerminalsWindowComesInCharactersAndALittleBesides() {
    let runner = ChaosRunner()
    _ = runner.step(ChaosAction(text: "open 104 Terminal pid 2004 at 97 238 877 499 min 177 64 bundle com.apple.Terminal cells 7 15 2 4"))
    for (asked, answered) in [((242, 767), (240, 769)), ((245, 377), (247, 379)), ((250, 247), (247, 244)), ((369, 247), (366, 244)), ((403, 389), (401, 394)), ((331, 377), (331, 379)), ((877, 499), (877, 499))] {
      let took = runner.system.setFrame(CGRect(x: 100, y: 100, width: asked.0, height: asked.1), of: WindowID(104))
      #expect(took?.size == CGSize(width: answered.0, height: answered.1), "asked for \(asked)")
    }
    // It opens in whole characters, has them under a hand on its edge, and in a tile of macOS's.
    _ = runner.step(ChaosAction(text: "open 105 Terminal pid 2004 at 100 100 614 349 cells 7 15 2 4"))
    #expect(runner.system.frame(of: WindowID(105))?.size == CGSize(width: 611, height: 349))
    #expect(runner.system.frameAfterResizing(WindowID(105), toward: CGRect(x: 100, y: 100, width: 641, height: 349)) == CGRect(x: 100, y: 100, width: 639, height: 349))
    #expect(runner.system.frameAfterResizing(WindowID(105), toward: CGRect(x: 70, y: 100, width: 641, height: 349)) == CGRect(x: 72, y: 100, width: 639, height: 349))
    // A number that is taken opens nothing, and changes nothing about the window that has it.
    _ = runner.step(ChaosAction(text: "open 106 Safari pid 2002 at 100 100 600 400"))
    _ = runner.step(ChaosAction(text: "open 106 Terminal pid 2004 at 100 100 614 349 cells 7 15 2 4"))
    #expect(runner.system.windows[WindowID(106)]?.sizeStep == nil)
  }

  @Test func halfTheOrdinaryWalksAreTakenWithMacOSsTilingOff() {
    var off = 0
    for seed in 1...200 {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: UInt64(seed), ordinary: true)
      _ = generator.next(runner)
      if generator.next(runner) == .macTiling(on: false) { off += 1 }
    }
    #expect((70...130).contains(off), "\(off) of 200")
  }

  @Test func aDraggedWindowStaysBelowTheMenuBarIntoWhichThePointerGoes() {
    let h = Harness()
    let window = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    h.system.beginDrag(window)
    h.system.moveDrag(to: CGPoint(x: 700, y: 0))
    #expect(h.system.cursor == CGPoint(x: 700, y: 0))
    #expect(h.frame(window)?.minY == h.visibleFrame.minY)
    // Nor does it slip under the bar on the way up, with the pointer still below it.
    h.system.moveDrag(to: CGPoint(x: 700, y: h.visibleFrame.minY + 3))
    #expect(h.frame(window)?.minY == h.visibleFrame.minY)
    h.system.moveDrag(to: CGPoint(x: 700, y: 300))
    #expect(h.frame(window)?.minY == 290)
  }
}
