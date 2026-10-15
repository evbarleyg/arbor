import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import FakeMacOS
import Foundation

// The rude walk: a seeded random walk over what people and apps do on a Mac, under bad manners in general, with the real layer listening. After each step things
// settle, and what the layer has reported and what it answers is held against the model (../README.md, "The rude walk").
//
// Everything is a function of the manners, the seed and the script: no clock, no system randomness, no dictionary order.

// MARK: - Manners

/// Which of the four kinds of bad manners a walk is made under.
struct WalkManners: Equatable {
  var name: String
  var overtaking = false, stale = false, repeatsAndDrops = false, lateCalls = false

  static let all: [WalkManners] = [
    // The control: on a Mac that behaves, nothing may be found. A rule that fails here is a wrong rule, or a wrong model.
    WalkManners(name: "polite"),
    WalkManners(name: "overtaking", overtaking: true),
    WalkManners(name: "stale answers", stale: true),
    WalkManners(name: "twice or never", repeatsAndDrops: true),
    WalkManners(name: "late calls", lateCalls: true),
    WalkManners(name: "all four", overtaking: true, stale: true, repeatsAndDrops: true, lateCalls: true),
  ]

  func apply(to mac: FakeMac, seed: UInt64) {
    final class Dice { var random: ChaosRandom; init(_ seed: UInt64) { random = ChaosRandom(seed: seed) } }
    let dice = Dice(seed &* 0x9E37_79B9 &+ 17)
    mac.manners.dice = { dice.random.next() }
    // Within some milliseconds: the reports of one change were seen 0.6 to 12 ms apart.
    if overtaking { mac.manners.overtaking = 0.02 }
    if stale { mac.manners.staleness = 0.06 }
    if repeatsAndDrops {
      mac.manners.repeats = 0.15
      mac.manners.drops = 0.15
    }
    if lateCalls { mac.manners.lateCalls = 0.08 }
  }
}

// MARK: - Steps

/// One thing that happens. `a` and `b` pick whom it happens to and how, by remainder, among what is there at the time: a script stays a script when steps are
/// taken out of it.
struct WalkStep: Equatable {
  enum Kind: String, CaseIterable {
    case launch, quit, dies, open, dialog, close, putAway, reopen, click, activate, minimize, restore, hide, move, rename
    case drag, dragLost, resize, hang, wake, space, tab, chooseTab, arborMoves, arborFocuses, arborMinimizes
  }
  var kind: Kind
  var a: Int
  var b: Int
  /// Seconds until the next step. Nil: things settle, and the rules are checked.
  var gap: Double?

  var text: String { "\(kind.rawValue) \(a) \(b)" + (gap.map { " +\($0)" } ?? "") }

  /// Done by the person at the Mac. What happens by itself may coincide with anything; two acts of one pair of hands are a quarter of a second apart.
  var isByHand: Bool {
    switch kind {
    case .click, .activate, .minimize, .restore, .hide, .drag, .dragLost, .resize, .space, .tab, .chooseTab, .close, .putAway, .reopen, .launch, .quit: true
    case .dies, .open, .dialog, .move, .rename, .hang, .wake, .arborMoves, .arborFocuses, .arborMinimizes: false
    }
  }

  init(kind: Kind, a: Int, b: Int, gap: Double?) {
    self.kind = kind
    self.a = a
    self.b = b
    self.gap = gap
  }

  init?(text: String) {
    let words = text.split(separator: " ")
    guard words.count >= 3, let kind = Kind(rawValue: String(words[0])), let a = Int(words[1]), let b = Int(words[2]) else { return nil }
    self.init(kind: kind, a: a, b: b, gap: words.count > 3 ? Double(words[3].dropFirst()) : nil)
  }

  static func script(seed: UInt64, steps: Int) -> [WalkStep] {
    var random = ChaosRandom(seed: seed)
    let weights: [(weight: Int, value: Kind)] = [
      (3, .launch), (2, .quit), (1, .dies), (10, .open), (2, .dialog), (7, .close), (2, .putAway), (3, .reopen), (10, .click), (9, .activate), (5, .minimize),
      (6, .restore), (4, .hide), (5, .move), (2, .rename), (6, .drag), (2, .dragLost), (4, .resize), (3, .hang), (6, .wake), (6, .space), (3, .tab), (3, .chooseTab),
      (6, .arborMoves), (5, .arborFocuses), (2, .arborMinimizes),
    ]
    return (0..<steps).map { _ in
      WalkStep(
        kind: random.pick(weighted: weights) ?? .open, a: random.int(0...99), b: random.int(0...99),
        gap: random.chance(30) ? [0.002, 0.01, 0.05, 0.3][random.int(0...3)] : nil)
    }
  }
}

// MARK: - The rules

/// A rule that was broken.
struct Breach: Equatable {
  /// Which rule, in words that fit after "the rude walk (manners): ".
  var rule: String
  var detail: String
}

enum Rule {
  static let knowsAll = "Arbor knows every standard window that shows"
  static let noGhosts = "Arbor knows no window that has closed"
  // Faults that are known get rules of their own wherever the model can tell them apart, so that they hide nothing else.
  static let ghostWithoutAWord = "a window that closed without a word is found out"
  static let ghostOfASilentEnd = "the windows of an app that ended without a word are found out"
  static let falseTab = "no window is taken for a tab of another"
  static let tabAsWindow = "a tab is not announced as a window of its own"
  static let tabLeftBehind = "when the tab in front goes, Arbor knows the one that shows instead"
  static let focusDespiteWorkspace = "a window whose app came forward while NSWorkspace still named another is reported focused"
  static let focusAfterHang = "a window whose app hung as it came forward is reported focused once the app wakes"
  static let flags = "Arbor knows which windows are minimized, hidden, in full screen or on another Space"
  static let frames = "Arbor knows where every window is"
  static let once = "every window is announced once"
  static let asNew = "a window that has just opened is announced as new"
  static let noFalseDeath = "no window is reported gone that is still open"
  static let strangers = "nothing is reported about a window that was not announced or is gone"
  static let agrees = "what the layer has announced is what it lists"
  static let keyboard = "the layer's last word on the keyboard is right"
  static let focusReported = "the window that got the keyboard is reported focused"
  static let grabs = "no drag or resize is left open with the button up"
  static let grabOrder = "a drag or resize begins once and ends once"
  static let patience = "Arbor's main thread waits at most two seconds for one hang"

  static let all = [
    knowsAll, noGhosts, ghostWithoutAWord, ghostOfASilentEnd, falseTab, tabAsWindow, tabLeftBehind, flags, frames, once, asNew, noFalseDeath, strangers, agrees, keyboard, focusReported,
    focusDespiteWorkspace, focusAfterHang, grabs, grabOrder, patience,
  ]
  /// After a breach of one of these the layer's picture of the Mac is wrong, and whatever breaks next may be a consequence: the walk ends there.
  static let spoilTheRest: Set<String> = [knowsAll, noGhosts, ghostWithoutAWord, ghostOfASilentEnd, falseTab, tabAsWindow, tabLeftBehind, once, noFalseDeath, strangers, agrees]
}

/// Folds what the layer reports into what a listener believes, and notes what cannot be.
@MainActor
final class WalkLedger {
  private(set) var believed: Set<UInt32> = []
  private(set) var openGrab: Heard?
  private(set) var breaches: [Breach] = []
  /// Windows that opened, or opened again, while the layer ran and have not been announced since.
  var owedAsNew: Set<UInt32> = []
  let mac: FakeMac

  init(mac: FakeMac, atStart: [UInt32]) {
    self.mac = mac
    believed = Set(atStart)
  }

  private func breach(_ rule: String, _ detail: String) { breaches.append(Breach(rule: rule, detail: detail)) }
  func takeBreaches() -> [Breach] {
    defer { breaches.removeAll() }
    return breaches
  }

  private func announce(_ id: UInt32, _ event: Heard) {
    if !believed.insert(id).inserted { breach(Rule.once, "\(event.text), which was announced already") }
    owedAsNew.remove(id)
  }

  /// To a person a tab group is one window. One of its tabs may be announced by itself only if Arbor knows none of the others.
  private func announceAlone(_ id: UInt32, _ event: Heard) {
    if let window = mac.window(id), let group = window.tabGroup,
      let other = window.app.windows.first(where: { $0 !== window && $0.tabGroup == group && $0.isOpen && believed.contains($0.number) })
    {
      breach(Rule.tabAsWindow, "\(event.text), which is a tab of the group of w\(other.number)")
    }
    announce(id, event)
  }

  func hear(_ event: Heard) {
    switch event {
    case .appeared(let id): announceAlone(id, event)
    case .found(let id):
      if owedAsNew.contains(id) { breach(Rule.asNew, event.text) }
      announceAlone(id, event)
    case .replaced(let old, let new):
      if believed.remove(old) == nil { breach(Rule.strangers, event.text) }
      if let group = mac.windowThatEverWas(new)?.tabGroup, mac.windowThatEverWas(old)?.tabGroup == group {} else { breach(Rule.falseTab, event.text) }
      announce(new, event)
      endGrab(of: old)
    case .destroyed(let id):
      if believed.remove(id) == nil { breach(Rule.strangers, event.text) }
      if let window = mac.window(id), window.isOpen, window.isStandard, window.app.isAlive { breach(Rule.noFalseDeath, event.text) }
      endGrab(of: id)
    case .changed(let id, _):
      if !believed.contains(id) { breach(Rule.strangers, event.text) }
    case .focused(let id):
      if !believed.contains(id) { breach(Rule.strangers, event.text) }
    case .dragBegan(let id), .resizeBegan(let id):
      if !believed.contains(id) { breach(Rule.strangers, event.text) }
      if let openGrab { breach(Rule.grabOrder, "\(event.text) while \(openGrab.text) is open") }
      openGrab = event
    case .dragMoved(let id):
      if openGrab != .dragBegan(id) { breach(Rule.grabOrder, "\(event.text) with no drag of it open") }
    case .dragEnded(let id), .dragCancelled(let id):
      if openGrab != .dragBegan(id) { breach(Rule.grabOrder, "\(event.text) with no drag of it open") }
      openGrab = nil
    case .resizeEnded(let id):
      if openGrab != .resizeBegan(id) { breach(Rule.grabOrder, "\(event.text) with no resize of it open") }
      openGrab = nil
    case .keyboardMoved, .pressed, .displaysChanged, .refused:
      break
    }
  }

  /// The listener clears its own side when it hears that the window is gone.
  private func endGrab(of id: UInt32) { if openGrab?.window == id { openGrab = nil } }
}

// MARK: - One walk

@MainActor
final class Walk {
  let mac = FakeMac()
  let layer = AXWindowSystem()
  let heard = Listener()
  let ledger: WalkLedger
  private let keyAtStart: UInt32?
  private var endedWithoutAWord: Set<pid_t> = []
  /// The model forgets a window that has closed; whether it went without a word is asked while it goes.
  private var closing: [FakeMac.Window] = []
  private var closedWithoutAWord: Set<UInt32> { Set(closing.filter { !$0.isOpen && $0.closedWithoutAWord }.map(\.number)) }
  private var hangs = 0

  init(manners: WalkManners, seed: UInt64, keepsJournal: Bool) {
    FakeMac.current = mac
    mac.keepsJournal = keepsJournal
    // A Mac in use: two apps, three windows.
    let first = mac.launch("App1")
    mac.open("a", in: first, frame: CGRect(x: 40, y: 60, width: 420, height: 320))
    mac.open("b", in: first, frame: CGRect(x: 520, y: 80, width: 380, height: 300))
    mac.open("c", in: mac.launch("App2"), frame: CGRect(x: 200, y: 330, width: 460, height: 300))
    mac.pass(1)
    manners.apply(to: mac, seed: seed)
    heard.mac = mac
    layer.events = heard
    mac.note("Arbor starts")
    layer.start()
    ledger = WalkLedger(mac: mac, atStart: layer.allWindows().map(\.id.rawValue))
    heard.onEvent = { [ledger] in ledger.hear($0) }
    mac.pass(1)
    keyAtStart = mac.keyWindow?.number
  }

  func end() {
    layer.stop()
    mac.end()
  }

  // Whom a step happens to.
  private var apps: [FakeMac.App] { mac.apps.filter { $0 !== mac.arbor } }
  private var awake: [FakeMac.App] { apps.filter { !$0.isHung } }
  private func pick<T>(_ items: [T], _ index: Int) -> T? { items.isEmpty ? nil : items[index % items.count] }
  /// Nobody can get hold of a window in the middle of an animation.
  private var openWindows: [FakeMac.Window] { mac.stack.filter { $0.isOpen && !$0.app.isHung && $0.isBusyUntil <= mac.now }.sorted { $0.number < $1.number } }
  private var showing: [FakeMac.Window] { openWindows.filter { mac.isShowing($0) } }
  private func frame(_ b: Int) -> CGRect {
    CGRect(x: 20 + CGFloat(b % 6) * 110, y: 40 + CGFloat(b / 6 % 5) * 70, width: 260 + CGFloat(b % 4) * 60, height: 200 + CGFloat(b % 3) * 50)
  }

  func take(_ step: WalkStep) {
    let (a, b) = (step.a, step.b)
    switch step.kind {
    case .launch:
      guard apps.count < 5 else { return }
      let app = mac.launch("App\(mac.apps.count + a)")
      mac.pass(0.2)
      ledger.owedAsNew.insert(mac.open("w", in: app, frame: frame(b)).number)
    case .quit: if let app = pick(apps, a) { mac.quit(app) }
    // That nothing says so is bad manners of the third kind.
    case .dies:
      guard let app = pick(apps, a) else { return }
      if mac.manners.drops > 0 { endedWithoutAWord.insert(app.pid) }
      mac.quit(app, announced: mac.manners.drops == 0)
    case .open:
      guard mac.stack.count < 12, let app = pick(awake.filter { !$0.isHidden }, a) else { return }
      app.reportsFocusBeforeCreated = b % 2 == 1
      ledger.owedAsNew.insert(mac.open("w", in: app, frame: frame(b)).number)
    case .dialog:
      guard mac.stack.count < 12, let app = pick(awake.filter { !$0.isHidden }, a) else { return }
      mac.open("d", in: app, frame: frame(b), subrole: "AXDialog")
    case .close:
      guard let window = pick(openWindows, a) else { return }
      closing.append(window)
      mac.close(window)
    case .putAway:
      guard let window = pick(openWindows.filter { $0.tabGroup == nil }, a) else { return }
      closing.append(window)
      mac.close(window, putAway: true)
    case .reopen:
      guard let window = pick(mac.stack.filter { !$0.isOpen && $0.exists && !$0.app.isHung && !$0.app.isHidden }, a) else { return }
      mac.reopen(window)
      if window.isStandard { ledger.owedAsNew.insert(window.number) }
    case .click: if let window = pick(showing, a) { mac.click(window) }
    case .activate: if let app = pick(apps, a) { mac.activate(app) }
    case .minimize: if let window = pick(showing.filter { !$0.isFullScreen }, a) { mac.minimize(window) }
    case .restore: if let window = pick(openWindows.filter(\.isMinimized), a) { mac.restore(window) }
    case .hide: if let app = pick(awake, a) { mac.hide(app) }
    case .move: if let window = pick(showing, a) { mac.appMoves(window, to: frame(b)) }
    case .rename: if let window = pick(openWindows, a) { mac.rename(window, "t\(b)") }
    case .drag, .dragLost:
      guard let window = pick(mac.stack.filter { mac.isShowing($0) && $0.isBusyUntil <= mac.now }, a) else { return }
      let start = CGPoint(x: window.bounds.midX, y: window.bounds.minY + 12)
      mac.drag(from: start, to: CGPoint(x: start.x + CGFloat(b % 7 - 3) * 40, y: start.y + CGFloat(b % 5) * 30), steps: 3 + b % 5, interval: b % 2 == 0 ? 0.08 : 0.03)
      mac.release(step.kind == .dragLost && mac.manners.drops > 0 ? .lost : b % 3 == 0 && mac.manners.repeats > 0 ? .seenTwice : .seen)
    case .resize:
      guard let window = pick(showing, a) else { return }
      let start = CGPoint(x: window.bounds.maxX, y: window.bounds.midY)
      mac.drag(from: start, to: CGPoint(x: start.x + CGFloat(b % 9 - 4) * 15, y: start.y), steps: 4)
      mac.release()
    case .hang:
      guard let app = pick(awake, a) else { return }
      mac.hang(app)
      hangs += 1
    case .wake: if let app = pick(apps.filter(\.isHung), a) { mac.wake(app) }
    case .space: mac.switchSpace(to: 1 + a % 3, lists: mac.manners.staleness > 0 && b % 2 == 0 ? .neither : .right, appComesForwardFirst: b % 3 != 0)
    case .tab:
      guard mac.stack.count < 12, let window = pick(showing.filter { $0.isStandard && !$0.isFullScreen }, a) else { return }
      mac.newTab(of: window, grows: b % 2 == 0 ? 0 : 31)
    case .chooseTab: if let tab = pick(openWindows.filter { !$0.isFrontTab }, a) { mac.chooseTab(tab) }
    case .arborMoves: if let id = pick(layer.allWindows().map(\.id), a) { _ = layer.setFrame(frame(b), of: id) }
    case .arborFocuses: if let id = pick(layer.allWindows().filter(\.isPresent).map(\.id), a) { layer.focus(id) }
    case .arborMinimizes: if let window = pick(layer.allWindows(), a) { layer.setMinimized(window.id, !window.isMinimized) }
    }
  }

  /// Holds the layer against the model, now that things have settled.
  func check() -> [Breach] {
    var breaches = ledger.takeBreaches()
    func breach(_ rule: String, _ detail: String) { breaches.append(Breach(rule: rule, detail: detail)) }
    let listed = layer.allWindows()
    let known = Dictionary(uniqueKeysWithValues: listed.map { ($0.id.rawValue, $0) })

    if Set(known.keys) != ledger.believed {
      breach(Rule.agrees, "announced and not listed: \(ledger.believed.subtracting(known.keys).sorted()); listed and not announced: \(Set(known.keys).subtracting(ledger.believed).sorted())")
    }
    // Nothing can be known about the windows of an app that hangs.
    let standard = mac.standardWindows.filter { !$0.app.isHung }
    for window in standard where mac.isShowing(window) && known[window.number] == nil {
      breach(window.tabGroup == nil ? Rule.knowsAll : Rule.tabLeftBehind, "w\(window.number)")
    }
    for (id, snapshot) in known.sorted(by: { $0.key < $1.key }) {
      guard let window = mac.window(id), window.isOpen, window.app.isAlive else {
        let wasSilent = endedWithoutAWord.contains(snapshot.pid)
        breach(wasSilent ? Rule.ghostOfASilentEnd : closedWithoutAWord.contains(id) ? Rule.ghostWithoutAWord : Rule.noGhosts, "w\(id)")
        continue
      }
      guard !window.app.isHung else { continue }
      guard window.isStandard else {
        // Taken on while it could not be told from a window, and looked at again when it shows.
        if mac.isShowing(window) { breach(Rule.noGhosts, "w\(id), which is a \(window.subrole ?? "nothing")") }
        continue
      }
      guard window.isFrontTab else {
        breach(Rule.agrees, "w\(id) is listed, and is behind another tab")
        continue
      }
      var wrong: [String] = []
      if snapshot.isMinimized != window.isMinimized { wrong.append("minimized \(snapshot.isMinimized)") }
      if snapshot.isHidden != window.app.isHidden { wrong.append("hidden \(snapshot.isHidden)") }
      if snapshot.isFullScreen != window.isFullScreen { wrong.append("full screen \(snapshot.isFullScreen)") }
      if snapshot.isOnActiveSpace != (window.space == mac.activeSpace) { wrong.append("on the Space that shows \(snapshot.isOnActiveSpace)") }
      if !wrong.isEmpty { breach(Rule.flags, "w\(id): Arbor has \(wrong.joined(separator: ", "))") }
      if mac.isShowing(window), snapshot.frame != window.frame { breach(Rule.frames, "w\(id) is at \(window.frame.text), Arbor has \(snapshot.frame.text)") }
    }

    // The keyboard. Only a window Arbor can know of and see counts, on either side.
    if let key = mac.keyWindow, key.isStandard, mac.isShowing(key), !key.app.isHung, key.app.policy == .regular {
      var word: UInt32?
      search: for event in heard.all.reversed() {
        switch event {
        case .focused(let id):
          word = id
          break search
        case .keyboardMoved:
          word = layer.focusedWindow()?.rawValue
          break search
        default: continue
        }
      }
      if heard.all.contains(where: { $0 == .keyboardMoved || { if case .focused = $0 { true } else { false } }($0) }), word != key.number {
        breach(Rule.keyboard, "w\(key.number) has it; the layer's last word is \(word.map { "w\($0)" } ?? "nobody")")
      }
      // "The keyboard may be somewhere else, ask me" does not move the view. Whoever got the keyboard last must be the last to have been reported focused.
      let reported = heard.all.last { if case .focused = $0 { true } else { false } }
      if reported != .focused(key.number), !(reported == nil && key.number == keyAtStart) {
        // An app that hung as it came forward is lost for that reason, whatever NSWorkspace said.
        let rule = key.app.hasHungInFront ? Rule.focusAfterHang : key.app.noticeOutranTheProperty ? Rule.focusDespiteWorkspace : Rule.focusReported
        breach(rule, "w\(key.number) has it; the last to be reported focused is \(reported?.window.map { "w\($0)" } ?? "nobody")")
      }
    }

    if !mac.mouse.isDown, let grab = ledger.openGrab { breach(Rule.grabs, grab.text) }
    if mac.secondsWaitedInVain > 2 * Double(max(hangs, 0)) { breach(Rule.patience, "\(mac.secondsWaitedInVain) s for \(hangs) hang(s)") }
    return breaches
  }
}

// MARK: - Many walks

@MainActor
enum Walker {
  struct Finding {
    var manners: WalkManners
    var seed: UInt64
    var script: [WalkStep]
    var breach: Breach
  }

  /// Runs a script. Returns the first breach of a rule that is not in `ignoring`, and after how many steps it showed.
  static func run(
    _ script: [WalkStep], manners: WalkManners, seed: UInt64, ignoring: Set<String>, journal: Bool = false, toTheEnd: Bool = false, seen: ((Breach) -> Void)? = nil,
    atTheEnd: (([String]) -> Void)? = nil
  ) -> (breach: Breach, after: Int, journal: [String])? {
    let walk = Walk(manners: manners, seed: seed, keepsJournal: journal)
    defer {
      atTheEnd?(walk.mac.journal)
      walk.end()
    }
    /// Two seconds in which Arbor's main thread was not held up: what it waited for a hung app is no time to settle in.
    func settle(_ seconds: TimeInterval) {
      var waited: TimeInterval
      repeat {
        waited = walk.mac.secondsWaitedInVain
        walk.mac.pass(seconds)
      } while walk.mac.secondsWaitedInVain != waited
    }
    func look(_ index: Int) -> (Breach, Int, [String])? {
      for breach in walk.check() {
        seen?(breach)
        if !ignoring.contains(breach.rule) { return (breach, index + 1, walk.mac.journal) }
        // What else is wrong now may follow from it.
        if Rule.spoilTheRest.contains(breach.rule), !toTheEnd {
          isSpoilt = true
          return nil
        }
      }
      return nil
    }
    var isSpoilt = false
    for (index, step) in script.enumerated() {
      walk.mac.note("STEP \(step.text)")
      walk.take(step)
      if let gap = step.gap {
        let next = index + 1 < script.count ? script[index + 1] : nil
        walk.mac.pass(step.isByHand && next?.isByHand == true ? max(gap, 0.25) : gap)
      } else {
        settle(2)
        if let found = look(index) { return found }
        if isSpoilt { return nil }
      }
    }
    // The end: everybody wakes, the button comes up, things settle.
    walk.mac.note("THE END")
    for app in walk.mac.apps where app.isHung { walk.mac.wake(app) }
    walk.mac.release()
    settle(3)
    return look(script.count - 1)
  }

  /// The shortest script this can get by taking steps out, one at a time, for as long as the same rule breaks.
  static func shrink(_ script: [WalkStep], manners: WalkManners, seed: UInt64, rule: String, ignoring: Set<String>) -> [WalkStep] {
    var best = script
    var changed = true
    while changed {
      changed = false
      var index = best.count - 1
      while index >= 0 {
        var shorter = best
        shorter.remove(at: index)
        if run(shorter, manners: manners, seed: seed, ignoring: ignoring)?.breach.rule == rule {
          best = shorter
          changed = true
        }
        index -= 1
      }
    }
    // A step that is followed by a rest is easier to read than one that is followed by the next.
    for index in best.indices where best[index].gap != nil {
      var calmer = best
      calmer[index].gap = nil
      if run(calmer, manners: manners, seed: seed, ignoring: ignoring)?.breach.rule == rule { best = calmer }
    }
    return best
  }
}

/// Each kind of manners is a story, each rule a check: it holds if no seed breaks it.
@MainActor
func tellOfTheWalk(_ book: Book) {
  let rules = Rule.all
  for manners in WalkManners.all {
    book.story("the rude walk (\(manners.name))") { story in
      let seeds = book.options.walkSeeds ?? 1...40
      var first: [String: Walker.Finding] = [:]
      var counts: [String: Int] = [:]
      for seed in seeds {
        let script = WalkStep.script(seed: seed, steps: book.options.walkSteps)
        // A rule that has broken is left out from then on, so that the walk goes on and the others get their turn.
        var broken: Set<String> = []
        while let found = Walker.run(script, manners: manners, seed: seed, ignoring: broken) {
          broken.insert(found.breach.rule)
          counts[found.breach.rule, default: 0] += 1
          if first[found.breach.rule] == nil {
            first[found.breach.rule] = Walker.Finding(manners: manners, seed: seed, script: Array(script.prefix(found.after)), breach: found.breach)
          }
        }
      }
      for rule in rules {
        guard let finding = first[rule] else {
          story.check(rule, true)
          continue
        }
        let others = Set(rules).subtracting([rule])
        let short = Walker.shrink(finding.script, manners: manners, seed: finding.seed, rule: rule, ignoring: others)
        let text = short.map(\.text).joined(separator: "; ")
        let again = Walker.run(short, manners: manners, seed: finding.seed, ignoring: others, journal: true)
        story.check(rule, false, "\(counts[rule] ?? 0) of \(seeds.count) seeds; first seed \(finding.seed): \(again?.breach.detail ?? finding.breach.detail)\n      --replay '\(manners.name)|\(finding.seed)|\(text)'")
        if book.options.isVerbose || book.isNew(story, rule) {
          story.onFailure { "    \(rule): seed \(finding.seed), \(short.count) steps of \(finding.script.count)\n" + (again?.journal ?? []).map { "      " + $0 }.joined(separator: "\n") }
        }
      }
    }
  }
}

/// `--replay 'manners|seed|step; step; …'`: one script, with everything that happened.
@MainActor
func replayWalk(_ text: String) -> Int32 {
  let parts = text.components(separatedBy: "|")
  guard parts.count == 3, let manners = WalkManners.all.first(where: { $0.name == parts[0] }), let seed = UInt64(parts[1]) else {
    print("--replay wants 'manners|seed|step; step; …', as a failing walk prints it")
    return 2
  }
  let script = parts[2].components(separatedBy: ";").compactMap { WalkStep(text: $0.trimmingCharacters(in: .whitespaces)) }
  var all: [Breach] = []
  _ = Walker.run(script, manners: manners, seed: seed, ignoring: Set(Rule.all), journal: true, toTheEnd: true, seen: { all.append($0) }) { for line in $0 { print(line) } }
  if all.isEmpty { print("no rule is broken") }
  for breach in all { print("✘ \(breach.rule): \(breach.detail)") }
  return all.isEmpty ? 0 : 1
}
