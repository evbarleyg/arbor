import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// Writes a walk from a seed: what a person could do, in the proportions docs/VIABLE.md asks of the whole gate.
///
/// **It plays each word on the stand-ins as it writes.** lib-walk.sh leaves out an act that does not apply when its turn comes, so a walk may be written blind; but an act
/// that is left out is a Mac's time spent on nothing, and the gate counts what was played. So a word that does not apply here is not written, and the dice
/// are rolled again. What a Mac then leaves out all the same is no bad luck: it is a place where the stand-ins and the Mac differ.
///
/// The same seed, length and setting give the same walk on every platform: the random numbers are the chaos lab's, and nothing else has a say.
@MainActor
public struct WalkWriter {
  /// docs/VIABLE.md, section 1, `acts_min`: the fewest acts of each kind over a whole gate. The page decides; `WalkTests` holds this copy to it.
  public static let fewestInAGate: [WalkKind: Int] = [
    .switch: 480, .openClose: 300, .dockKey: 160, .drag: 240, .dragWhereMacOSTiles: 80, .view: 400, .resize: 80, .macOSOwn: 80, .wayOut: 60,
    .quitAndStart: 20, .displayChange: 20, .idle: 40, .tileClick: 10,
  ]
  /// `share_of_acts_from_walks_min` of them come from walks, of which a gate has about 22 of 110 acts.
  static let (shareFromWalks, actsFromWalks) = (0.5, 22.0 * 110)

  /// What the first version leaves to the days that are written by hand: changes of displays, hiding, native tabs, full screen and the rest of what is macOS's own.
  public static let kinds: [WalkKind] = [.switch, .openClose, .dockKey, .drag, .dragWhereMacOSTiles, .view, .resize, .wayOut, .idle, .tileClick]

  /// The fewest acts of a kind in one walk of that many, so that the walks of a gate bring their share of each. A drag where macOS tiles counts as a drag too.
  public static func fewest(of kind: WalkKind, in acts: Int) -> Int {
    guard kinds.contains(kind) || kind == .quitAndStart, let gate = fewestInAGate[kind] else { return 0 }
    return Int((Double(gate) * shareFromWalks * Double(acts) / actsFromWalks).rounded(.up))
  }

  /// Half a minute each, and a run has ten.
  static func mostIdle(in acts: Int) -> Int { min(max(acts / 55, 1), 4) }

  /// FNV-1a: any word is a seed, and the same word the same seed everywhere.
  public static func number(for seed: String) -> UInt64 {
    seed.utf8.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01B3 }
  }

  public private(set) var walk: Walk
  /// The playing that went with the writing.
  public private(set) var player: WalkPlayer

  private var random: ChaosRandom
  private var words: [WalkWord] = []
  /// How many words have been tried, and which of them are not to be tried again.
  private var tried = 0
  private var struckOut: Set<Int> = []
  private var embarrassment: Int?
  private static let patience = 24
  /// So many words were struck out that the walk was written with what it met after them: it holds an act at which an expectation of the script's does not hold.
  public private(set) var isResigned = false
  /// What belongs together stays near each other: what is minimized is restored a few acts later, a pause is resumed, an app that quit is opened again. A walk
  /// that puts every app away in its first minute has nothing left to walk through, and while Arbor is paused its own acts are left out.
  private var owed: [(turns: Int, word: WalkWord)] = []

  public init(_ setting: WalkSetting, acts: Int, scene: WalkScene? = nil) {
    random = ChaosRandom(seed: Self.number(for: setting.seed))
    player = WalkPlayer(setting, scene: scene)
    walk = Walk(setting: setting, words: [])
    // lib-walk.sh expects of some acts what Arbor does not always do, and rightly: a window dropped where there is no room for it floats where it was let go, and "it is
    // docked" is not so. On a Mac that is a finding, and the gate allows none. What is played cannot be taken back, so the walk is written again from the same
    // seed without that one word: the dice fall as they fell up to there. `arbor-sim walk --many` counts what was struck out, so that nothing is hushed up.
    while true {
      player.begin()
      write(acts)
      player.end()
      guard let word = embarrassment else { break }
      // There has to be an end to it. The last writing goes on past whatever it meets, so that the walk is whole, and says so.
      if struckOut.count < Self.patience { struckOut.insert(word) } else { isResigned = true }
      random = ChaosRandom(seed: Self.number(for: setting.seed))
      player = WalkPlayer(setting, scene: scene)
      (words, owed, tried, embarrassment) = ([], [], 0, nil)
    }
    let counts = Self.counts(of: player)
    let command = "arbor-sim walk \(setting.seed) \(acts) --for-a-mac \(setting.cast.rawValue) \(setting.display.rawValue) \(setting.tiling.rawValue) \(setting.commit)"
    walk = Walk(
      setting: setting, words: words,
      head: ["A walk from the seed \(setting.seed): \(command.trimmingCharacters(in: .whitespaces))", "Written by a program. Change the program, not this file."],
      foot: [
        "\(player.played.count) acts on the stand-ins: " + WalkKind.ofActs.compactMap { kind in counts[kind].map { "\(kind.rawValue) \($0)" } }.joined(separator: ", ")
      ])
  }

  /// How many words were struck out because the script's own expectations did not hold on the stand-ins.
  public var wordsStruckOut: Int { struckOut.count }

  /// How many acts of each kind a playing had, the setting of the scene apart.
  public static func counts(of player: WalkPlayer) -> [WalkKind: Int] {
    player.played.reduce(into: [:]) { $0[$1.kind, default: 0] += 1 }
  }

  private var apps: [String] { player.cast }
  /// TextEdit has an open panel up in that cast, and takes nothing else meanwhile.
  private var free: [String] { apps.filter { !(player.setting.cast == .awkward && $0 == "textedit") } }
  private mutating func app() -> String { random.pick(free) ?? "finder" }

  /// Writes the word if it is played, and says whether it was.
  @discardableResult
  private mutating func say(_ word: WalkWord) -> Bool {
    tried += 1
    guard !struckOut.contains(tried), player.isWorthTrying(word) else { return false }
    let findings = player.findings
    guard player.playIfItApplies(word).acts > 0 else { return false }
    words.append(word)
    if player.findings > findings, embarrassment == nil, !isResigned { embarrassment = tried }
    return true
  }

  private mutating func later(_ word: WalkWord) { owed.append((random.int(1...4), word)) }

  /// What the end of every walk adds: what is owed, the quit, and every app called up once more.
  private var stillToCome: Int { owed.count + 1 + apps.count }

  private mutating func write(_ acts: Int) {
    var restarted = false
    // A turn that finds nothing to do costs nothing, but there has to be an end to it.
    var turns = 0
    while player.played.count + stillToCome < acts, turns < acts * 4, embarrassment == nil {
      turns += 1
      for index in owed.indices { owed[index].turns -= 1 }
      if let due = owed.firstIndex(where: { $0.turns <= 0 }) {
        say(owed.remove(at: due).word)
        continue
      }
      if !restarted, player.played.count >= acts / 2, owed.isEmpty {
        restarted = true
        say(.quitAndStart)
        continue
      }
      // What the walk still lacks cannot always be had as things stand: everything is out of view but one window, say. Then something else is done, which changes them.
      if !take(kind(of: acts, lacking: true)) { _ = take(kind(of: acts, lacking: false)) }
    }
    for debt in owed { say(debt.word) }
    owed = []
  }

  /// Which kind of thing is done next: by the gate's own proportions, until what is left of the walk is needed for what it still lacks.
  private mutating func kind(of acts: Int, lacking mayInsist: Bool) -> WalkKind {
    var counts = Self.counts(of: player)
    counts[.drag, default: 0] += counts[.dragWhereMacOSTiles] ?? 0
    let idleIsSpent = (counts[.idle] ?? 0) >= Self.mostIdle(in: acts)
    // A tile stands only where everything is shown and did not fit: it cannot be had for the asking.
    let lacking = Self.kinds.filter { $0 != .tileClick }.map { (weight: max(Self.fewest(of: $0, in: acts) - (counts[$0] ?? 0), 0), value: $0) }
    let left = acts - player.played.count - stillToCome
    // Four times over, since a word does not always apply when it is wanted, and some bring a switch or a dock of their own along.
    if mayInsist, lacking.reduce(0, { $0 + $1.weight }) * 4 >= left, let kind = random.pick(weighted: lacking) { return kind }
    // The last few are short things: a resize may begin with a look at everything, two docks and a switch, and the walk would be that much longer than asked for.
    if left <= 3 { return random.chance(50) ? .switch : .view }
    // Otherwise by how far each kind is behind its share. Many a word brings a switch of its own along (a window is brought forward before it is docked, dragged,
    // closed), so by fixed weights half of a walk would be switches.
    counts[.drag, default: 0] -= counts[.dragWhereMacOSTiles] ?? 0
    func share(_ kind: WalkKind) -> Double {
      // Rare in the gate's numbers, hard to come by, and worth more than the numbers say: it is the one place where a detector takes Arbor's word.
      if kind == .tileClick { return 30 }
      return Double(Self.fewestInAGate[kind]! - (kind == .drag ? Self.fewestInAGate[.dragWhereMacOSTiles]! : 0))
    }
    let whole = Self.kinds.reduce(0) { $0 + share($1) }
    let weights = Self.kinds.map { kind -> (weight: Int, value: WalkKind) in
      if kind == .idle, idleIsSpent { return (0, kind) }
      return (max(Int((share(kind) / whole * Double(acts) - Double(counts[kind] ?? 0)) * 10), 1), kind)
    }
    return random.pick(weighted: weights) ?? .switch
  }

  /// What is to be resized, dragged onto or dragged out has to be docked first.
  private mutating func dockSomething() -> Bool {
    say(.switchTo(app()))
    return say(.dockKey(random.pick(WalkWord.Arrow.allCases)!))
  }

  /// Rolls words of that kind until one applies. The weights within a kind are those of scripts/mac-shell/walk.py, which served before.
  private mutating func take(_ kind: WalkKind) -> Bool {
    for _ in 0..<12 { if attempt(kind) { return true } }
    return false
  }

  private mutating func attempt(_ kind: WalkKind) -> Bool {
    let (app, other) = (app(), app())
    switch kind {
    case .switch:
      // ⌘Tab once. Where more presses lead depends on how quick the Mac is (`appBehindCmdTab`), and a walk that cannot be foretold parts from its rehearsal there.
      let word = random.pick(weighted: [
        (4, WalkWord.switchDock(app)), (4, .switchClick(app)), (3, .switchCmdTab(1)), (1, .switchBacktick), (2, .focusKey(random.pick(WalkWord.Arrow.allCases)!)),
        (1, .switchMenu(random.pick(free.filter { RealApp.named($0)?.opensNewWindows == true }) ?? "finder")),
      ])!
      // Onto an app without a window nobody could say which window should be in front.
      if case .switchCmdTab(let times) = word, player.appBehindCmdTab(times).map({ player.present($0) }) != true { return false }
      return say(word)
    case .tileClick:
      // A tile stands only where everything is shown and did not fit: with most of the cast docked.
      guard player.arborActs else { return false }
      if player.ids().docked.count < 5 { say(.arrangeKey) }
      guard say(.view(.all)) else { return false }
      say(.tileClick(random.int(1...2)))
      return true
    case .openClose:
      switch random.int(0...3) {
      case 0:
        let opener = random.pick(free.filter { RealApp.named($0)?.opensNewWindows == true }) ?? "finder"
        if player.frontApp != opener, !say(.switchDock(opener)) { return false }
        if say(.openNew) { later(.closeNew) }
        return true
      case 1:
        guard say(.switchTo(app)) else { return false }
        if say(.minimize) { later(.restore(app)) }
        return true
      case 2:
        let quits = random.pick(["textedit", "preview", "safari"].filter(free.contains)) ?? "safari"
        guard say(.quitApp(quits)) else { return false }
        later(.reopen(quits))
        return true
      default: return say(.closeNew)
      }
    case .dockKey:
      let word = random.pick(weighted: [
        (8, WalkWord.dockKey(random.pick(WalkWord.Arrow.allCases)!)), (2, .floatKey), (1, .arrangeKey), (2, .undo), (1, .redo), (1, .rotate), (1, .mirror), (1, .pin),
      ])!
      // Mostly another window than the one that happens to be in front.
      if random.chance(50) { say(.switchTo(app)) }
      return say(word)
    case .drag:
      let (across, down) = (random.int(-200...200), random.int(-120...120))
      let docked = player.appsDockedInView
      if player.arborActs, docked.isEmpty, random.chance(50) { return dockSomething() }
      return say(
        random.pick(weighted: [
          (3, WalkWord.dragOnto(app, random.pick(docked) ?? other, random.pick(WalkWord.Part.allCases)!)), (2, .dragOut(random.pick(docked) ?? app)),
          // Every other time an impatient hand clicks right after the drop.
          (2, .dragBy(app, across, down, click: (across + down) % 2 == 0)),
        ])!)
    case .dragWhereMacOSTiles: return say(.dragEdge(app, random.pick(WalkWord.ScreenEdge.allCases)!))
    case .view:
      let number = random.int(1...3)
      return say(
        random.pick(weighted: [
          (4, WalkWord.view(.frame)), (4, .view(.all)), (2, .view(.out)), (2, .view(.in)), (2, .view(.left)), (2, .view(.right)), (2, .view(.back)),
          (1, .view(.forward)), (1, .view(.desktop)), (1, .view(.home)), (1, .peek), (1, .saveView(number)), (1, .viewN(number)),
        ])!)
    case .resize:
      // A gap is between two docked windows that show. Where there are none, a person who wants one makes them first.
      guard player.arborActs else { return false }
      let before = words.count
      if player.appsDockedInView.count < 2, player.ids().docked.count >= 2 { say(.view(.home)) }
      for _ in 0..<4 where player.appsDockedInView.count < 2 { _ = dockSomething() }
      let docked = player.appsDockedInView
      guard docked.count >= 2 else { return words.count > before }
      let resized = random.pick(docked) ?? app
      let word = random.pick(weighted: [
        (2, WalkWord.resizeGap(resized, random.pick([-80, -40, 40, 80])!)), (3, .resizeKey(random.pick(WalkWord.Size.allCases)!)),
        (2, .resizeEdge(resized, random.pick(WalkWord.Part.allCases)!, random.pick([-60, -30, 30, 60])!)),
      ])!
      // The keys are about the window in front.
      if case .resizeKey = word, player.frontApp.map(docked.contains) != true { say(.switchTo(resized)) }
      return say(word) || words.count > before
    case .wayOut:
      switch random.int(0...4) {
      case 0, 1:
        guard say(.pause) else { return false }
        later(.resume)
        return true
      case 2: return say(.holdView)
      default: return say(random.pick([.floatAll, .floatAll, .floatAllHere])!)
      }
    case .idle: return say(.idleAct)
    case .macOSOwn, .quitAndStart, .displayChange, .instrument: return false
    }
  }
}

extension WalkPlayer {
  /// Plays the word. If no act came of it, nothing is left of the attempt: not on the screen, where nothing happened, and not in the story.
  public func playIfItApplies(_ word: WalkWord) -> Outcome {
    let marks = bookmarks
    let outcome = play(word)
    if outcome.acts == 0 { forget(since: marks) }
    return outcome
  }
}
