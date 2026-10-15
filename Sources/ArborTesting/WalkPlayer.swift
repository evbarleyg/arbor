import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The screen a walk begins on: the displays, and where each app's first window stands before Arbor is started.
public struct WalkScene: Equatable, Sendable {
  public var frame: CGRect
  public var visible: CGRect
  /// By the cast's names, in the order in which they are opened.
  public var windows: [(app: String, frame: CGRect)]
  /// From the window in front to the one at the back, when the person looks around: by their labels, an app's second window (`safari-2`) among them. Empty: as the
  /// opening and the setting of the scene leave them.
  public var pile: [String]
  /// Where the windows of a run stood when its person looked around, after macOS's tiling had been tried on one of them. Where a real window comes to lie when it is
  /// dragged off a tile of macOS's is not for a walk to find out: a playing that is compared with that run begins exactly where it began.
  public var atTheStart: [String: CGRect] = [:]
  /// The apps that have been in front, the last one first. Apps are opened in the background, so not all have been.
  public var recent: [String] = ["calendar", "textedit", "finder"]

  public static func == (a: WalkScene, b: WalkScene) -> Bool {
    a.frame == b.frame && a.visible == b.visible && a.pile == b.pile && a.atTheStart == b.atTheStart && a.recent == b.recent && a.windows.map(\.app) == b.windows.map(\.app)
      && a.windows.map(\.frame) == b.windows.map(\.frame)
  }

  /// As a hosted Mac was found. What it offers for `laptop` is 1600×900; its menu bar takes 31 points and its Dock 78.
  public init(_ setting: WalkSetting) {
    frame = CGRect(origin: .zero, size: setting.display == .desk ? CGSize(width: 1920, height: 1080) : CGSize(width: 1600, height: 900))
    visible = CGRect(x: 0, y: 31, width: frame.width, height: frame.height - 31 - 78)
    windows = setting.cast.members.map { ($0.word, $0.onAHostedMac ?? CGRect(origin: CGPoint(x: 200, y: 100), size: $0.opens)) }
    pile = ["calendar", "textedit", "mail", "preview", "settings", "notes", "terminal", "finder", "safari"]
    // Of the other casts no run has been seen.
    if setting.cast != .stock { (pile, recent) = ([], []) }
  }

  /// As a run found its Mac: from the samples it brought back, up to the step in which the person looks around. An app remembers its frame from the script
  /// before, so no two runs begin alike, and a playing that is to be compared with a run begins where the run began. Nil if the samples hold no such beginning.
  public init?(samples: String) {
    var (frames, labels, order): ([String: CGRect], [String: String], [String]) = ([:], [:], [])
    /// The window each name stands for: the one that was given it last. An app swaps the window it opened with for another, and the script labels that one.
    var ids: [String: String] = [:]
    var (display, between): (CGRect?, CGRect?)
    var opened: [String] = []
    var inFront: [String] = []
    /// The frames at the end of the step that opened the last app: before macOS's tiling is tried on one of them.
    var atTheOpening: [String: CGRect]?
    func rect(_ words: ArraySlice<Substring>) -> CGRect? {
      let numbers = words.compactMap { Double($0) }
      return numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]) : nil
    }
    for line in samples.split(separator: "\n") {
      let words = line.split(separator: " ")
      guard words.count >= 3 else { continue }
      switch words[1] {
      case "D": display = rect(words[2...])
      case "V": between = rect(words[2...])
      case "W" where words.count >= 10 && words[4] == "0": frames[String(words[2])] = rect(words[5..<9])
      case "G": frames[String(words[2])] = nil
      case "Z": order = words[2].split(separator: ",").map(String.init)
      case "A" where words.count == 4:
        guard let app = RealApp.all.first(where: { $0.bundleID == words[3] })?.word else { continue }
        inFront.removeAll { $0 == app }
        inFront.insert(app, at: 0)
      // `safari`, and `safari-2`, `finder-tab-behind`: what a cast has besides its apps' first windows.
      case "M" where words[2] == "label" && words.count == 5 && RealApp.named(String(words[4].prefix { $0 != "-" })) != nil:
        labels[String(words[3])] = String(words[4])
        ids[String(words[4])] = String(words[3])
        if RealApp.named(String(words[4])) != nil, !opened.contains(String(words[4])) { opened.append(String(words[4])) }
      case "M" where words[2] == "begin" && words.count == 5 && words[4] == "tiling-acts" && atTheOpening == nil: atTheOpening = frames
      case "M" where words[2] == "begin" && words.count == 5 && words[4] == "look-around":
        guard let display, let between, let atTheOpening else { return nil }
        (frame, visible) = (display, between)
        windows = opened.compactMap { app in ids[app].flatMap { atTheOpening[$0] }.map { (app, $0) } }
        pile = order.filter { ids[labels[$0] ?? ""] == $0 }.compactMap { labels[$0] }
        recent = inFront
        atTheStart = Dictionary(uniqueKeysWithValues: ids.compactMap { label, id in frames[id].map { (label, $0) } })
        return
      default: break
      }
    }
    return nil
  }
}

/// Plays a walk against the stand-ins, word by word, as scripts/mac-shell/lib-walk.sh plays it against real apps. Each word looks at the state for itself: an act
/// that does not apply is left out, what a person would do first is done first as an act of its own, and each act says what it may move. **The conditions,
/// the slugs and the keys are lib-walk.sh's, function by function**, so that an act which is left out in one place and played in the other is a difference
/// between a stand-in and a Mac, not between two players.
///
/// Two judges look on. The chaos lab's nets ask after every event (`broken`). And what the screen showed is written down for jolts.py (`samples`).
@MainActor
public final class WalkPlayer {
  public let setting: WalkSetting
  public let scene: WalkScene
  /// The control: Arbor is never started, and its own acts are left out.
  public let withoutArbor: Bool
  public let runner = ChaosRunner()
  public let samples = WalkSamples()

  /// One thing a person did.
  public struct Act: Sendable {
    public var number: Int
    public var kind: WalkKind
    public var slug: String
    /// The scene is being set: no act of the walk's.
    public var isSetup = false
    /// What the chaos lab's nets caught during it, each rule once.
    public var broken: [InvariantViolation] = []
    /// What the script itself found out: `want` in lib-day.sh.
    public var findings: [String] = []
    /// What the person does could not be done (`must` in lib-day.sh): Arbor refused the command. Not judged, and the gate allows few of them.
    public var wasPerformed = true
  }

  public private(set) var acts: [Act] = []
  /// Why words, or parts of them, were not played: what lib-walk.sh prints after `-- left out:`.
  public private(set) var leftOut: [String] = []
  /// Words a Mac can play and the stand-ins cannot.
  public private(set) var notRehearsed: [String] = []
  /// What a person reading along is told, line by line.
  public private(set) var story: [String] = []
  /// Called with each line of the story as it is written.
  public var tell: ((String) -> Void)?

  // MARK: What lib-walk.sh remembers, under its names

  struct Member {
    var app: RealApp
    var window: WindowID?
    var pid: Int32?
  }
  /// WALK_CAST, W_<name>, P_<name>
  public internal(set) var cast: [String] = []
  var members: [String: Member] = [:]
  /// WALK_NEW, the newest first; WALK_MINIMIZED; WALK_HIDDEN
  var newWindows: [WindowID] = []
  var minimized: [String] = []
  var hidden: [String] = []
  var paused = false
  var beforePause: Int?
  var movedInPause: [WindowID] = []
  /// WALK_AT_PAUSE: the window that had the keyboard, and those that floated.
  var atPause: [WindowID] = []
  var fullScreen: (window: WindowID, step: Int)?
  var second = false
  var nextSize: CGSize?
  /// WALK_HOME
  var home: Int?
  /// WALK_LEFT_<name>
  var leftAt: [String: Int] = [:]
  /// DAY_STEP, WALK_ACTS, DAY_SINCE_START, DAY_DOCKED_BEFORE
  var step = 0
  var walkActs = 0
  var sinceStart = 0
  var dockedBefore: [WindowID] = []
  /// WALK_X, WALK_Y, WALK_W, WALK_H
  var screen: CGRect { system.displayList.first(where: \.isMain)?.frame ?? scene.frame }

  // MARK: What a Mac knows and a script does not have to

  /// The apps, from the one in front to the one that was in front longest ago: what ⌘Tab goes through.
  var recentApps: [String] = []
  public internal(set) var labels: [WindowID: String] = [:]
  private var nextWindow: UInt32 = 101
  private var nextPid: Int32 = 2000
  private var arborPid = 4241
  private var hasBegun = false
  private var hasEnded = false

  public init(_ setting: WalkSetting, scene: WalkScene? = nil, withoutArbor: Bool = false) {
    self.setting = setting
    self.scene = scene ?? WalkScene(setting)
    self.withoutArbor = withoutArbor
  }

  var system: FakeWindowSystem { runner.system }

  /// The events the walk has come to so far, for `arbor-sim replay` and `shrink`.
  public var script: [ChaosAction] { runner.script }

  /// How many things the script itself has found out so far, acts that could not be performed among them.
  public var findings: Int { acts.reduce(0) { $0 + $1.findings.count + ($1.wasPerformed ? 0 : 1) } }

  /// The acts of the walk itself, without the setting of the scene.
  public var played: [Act] { acts.filter { !$0.isSetup && $0.kind != .instrument } }

  /// The rules the nets caught, with the acts at which they did; those the chaos lab knows of apart.
  public func broken(known: Bool) -> [(act: Act, violation: InvariantViolation)] {
    acts.flatMap { act in act.broken.filter { ChaosRunner.knownRules.contains($0.rule) == known }.map { (act, $0) } }
  }

  /// For each rule that is no known failure, the shortest script that still breaks it: the walk's own events up to where it broke, shrunk as the chaos lab shrinks
  /// its walks, past the failures it knows.
  public func shrunk() -> [ChaosFailure] {
    var seen = Set<String>()
    return firstBreaks.filter { !ChaosRunner.knownRules.contains($0.violation.rule) && seen.insert($0.violation.rule).inserted }.map { found in
      let failure = ChaosFailure(seed: nil, violations: [found.violation], script: Array(script.prefix(found.events)))
      return ChaosRunner.shrink(failure) { ChaosRunner.replay($0, excusing: ChaosRunner.knownRules.subtracting([found.violation.rule])) }
    }
  }
  /// What broke, and how many events the walk had come to.
  private var firstBreaks: [(violation: InvariantViolation, events: Int)] = []

  // MARK: Time

  private var elapsedBefore = 0.0
  private var lastNow = 0.0
  private var lastHarness: ObjectIdentifier?

  /// Seconds since the walk began. Each run of Arbor has a clock of its own, which begins at nought.
  var clock: Double {
    let harness = ObjectIdentifier(runner.harness)
    if harness != lastHarness {
      elapsedBefore += lastNow
      lastHarness = harness
    }
    lastNow = runner.harness.scheduler.now
    return elapsedBefore + lastNow
  }

  /// One event: it happens, the nets ask their questions, and what shows on the screen is written down.
  func does(_ action: ChaosAction) {
    let mark = system.frameLog.count
    let violations = runner.step(action)
    if !acts.isEmpty {
      for violation in violations where !acts[acts.count - 1].broken.contains(where: { $0.rule == violation.rule }) {
        acts[acts.count - 1].broken.append(violation)
        firstBreaks.append((violation, runner.script.count))
        say("  \(ChaosRunner.knownRules.contains(violation.rule) ? "known" : "RULE") \(violation)")
      }
    }
    samples.look(at: runner, moves: system.frameLog[min(mark, system.frameLog.count)...], time: clock)
    noteWhoIsInFront()
  }

  /// Time goes by, from one thing that falls due to the next, so that each is seen at its own moment. What macOS has to report comes a moment after its cause.
  func pass(_ seconds: Double) {
    var left = seconds
    while left > 0.0005 {
      var slice = left
      if system.hasHeldEchoes {
        slice = min(left, 0.02)
      } else if let due = runner.harness.scheduler.nextDue {
        slice = min(left, max(due - runner.harness.scheduler.now, 0.001))
      }
      slice = min(max((slice * 1000).rounded(.up) / 1000, 0.001), 60)
      let reports = system.hasHeldEchoes
      does(.advance(slice))
      if reports { does(.react) }
      left -= slice
    }
  }

  /// sampler.swift's `quiet 1000 8000`: until nothing has moved, come, gone or changed its place in the pile for a second; never sooner than 350 ms
  /// after the question; eight seconds at the most.
  private func quiet() -> String {
    let asked = clock
    while true {
      let now = clock
      let rest = max(samples.lastChange + 1, asked + 0.35) - now
      if rest <= 0.0005, !system.hasHeldEchoes { return "quiet:\(Int(((now - asked) * 1000).rounded()))" }
      if now - asked >= 8 { return "restless:\(Int(((now - asked) * 1000).rounded()))" }
      // One thing at a time: what it sets off moves the moment from which the second counts.
      var slice = max(rest, 0.02)
      if system.hasHeldEchoes {
        slice = 0.02
      } else if let due = runner.harness.scheduler.nextDue {
        slice = min(slice, max(due - runner.harness.scheduler.now, 0.001))
      }
      pass(slice)
    }
  }

  /// lib.sh's `eventually`: for up to three seconds.
  func eventually(_ holds: () -> Bool) -> Bool {
    for _ in 0..<30 {
      if holds() { return true }
      pass(0.1)
    }
    return holds()
  }

  // MARK: Steps (lib-day.sh)

  func say(_ line: String) {
    story.append(line)
    tell?(line)
  }

  func note(_ words: String) { samples.mark(words, at: clock) }

  func chapter(_ title: String) {
    say("")
    say("== \(title)")
    note("chapter \(title)")
  }

  func label(_ window: WindowID, _ name: String) {
    labels[window] = name
    note("label \(window.rawValue) \(name)")
    say("  w\(window.rawValue) is \(name)")
  }

  func act(_ kind: WalkKind, _ slug: String, _ text: String) {
    step += 1
    acts.append(Act(number: step, kind: kind, slug: slug))
    dockedBefore = ids().docked
    say("")
    say("-- \(step) \(slug): \(text)")
    note("begin \(step) \(slug)")
    note("text \(step) \(text)")
  }

  /// lib-walk.sh's `walk_act`.
  func walkAct(_ kind: WalkKind, _ slug: String, _ text: String) {
    walkActs += 1
    // During a pause, anything but these changes what there is to come back to. Of a switch `resume` asks where it led.
    if ![.idle, .drag, .wayOut, .switch].contains(kind) { beforePause = nil }
    act(kind, slug, text)
  }

  func want(_ what: String, _ holds: Bool) {
    guard !holds else { return }
    acts[acts.count - 1].findings.append(what)
    say("  ✘ not so: \(what)")
    note("finding \(step) - FAIL not so: \(what)")
  }

  static func list(_ windows: [WindowID]) -> String { windows.map { String($0.rawValue) }.joined(separator: ",") }

  /// Waits for quiet and ends the step. The keys are jolts.py's; `moves=docked` is whatever is docked before or after the step, `tiles=ok` the tiles there are.
  func acted(_ words: [String] = []) {
    let settled = quiet()
    let now = ids()
    var wants: [String] = []
    if !acts[acts.count - 1].wasPerformed {
      say("  ✘ the act was not performed: ctl")
      wants = ["judge=no", "performed=no", "undone=ctl"]
    }
    for var word in words {
      if word == "audit=no" { continue }
      if word == "moves=docked" || word.hasPrefix("moves=docked,") {
        word = "moves=\(Self.list(dockedBefore)),\(Self.list(now.docked)),\(word.dropFirst("moves=docked".count))"
      } else if word == "tiles=ok" {
        word = "tiles=\(now.tiles.map { "\($0.window.rawValue)@\($0.place)" }.joined(separator: ",")) keyboard=\(frontWindow.map { String($0.rawValue) } ?? "")"
      } else if ["front=", "comes=", "drags="].contains(word) {
        // Nothing would be checked, and it would look like a pass.
        acts[acts.count - 1].findings.append("the script could not tell which window \(word.dropLast()) is about")
        note("finding \(step) - FAIL the script could not tell which window \(word.dropLast()) is about")
        continue
      }
      wants.append(word)
      if word == "setup=1" { acts[acts.count - 1].isSetup = true }
    }
    if arborAnswers { wants += ["floating=\(Self.list(now.floating))", "docked=\(Self.list(now.docked))"] }
    let kind = acts[acts.count - 1].kind
    if [.dockKey, .view, .resize, .wayOut, .drag, .tileClick].contains(kind) {
      sinceStart += 1
      if sinceStart == 1 { wants.append("first=1") }
    }
    note((["end \(step) act=\(kind.rawValue) settled=\(settled)"] + wants).joined(separator: " "))
    say("  (\(settled) ms) \(wants.joined(separator: " "))")
    for (window, frame) in samples.pile { say("  = \(labels[window] ?? "w\(window.rawValue)") \(WalkSamples.text(frame))") }
  }

  func leaveOut(_ why: String) {
    leftOut.append(why)
    say("")
    say("-- left out: \(why)")
  }

  /// How much has been told so far, and taking back what was told since: for whoever tries a word out.
  var bookmarks: (leftOut: Int, notRehearsed: Int, story: Int) { (leftOut.count, notRehearsed.count, story.count) }
  func forget(since marks: (leftOut: Int, notRehearsed: Int, story: Int)) {
    leftOut.removeLast(leftOut.count - marks.leftOut)
    notRehearsed.removeLast(notRehearsed.count - marks.notRehearsed)
    story.removeLast(story.count - marks.story)
  }

  func cannotRehearse(_ why: String) {
    notRehearsed.append(why)
    say("")
    say("-- not rehearsed: \(why)")
  }

  // MARK: What the script asks Arbor (`arborctl state`)

  var withArbor: Bool { !withoutArbor }
  /// Its process lives: it runs, or it is paused.
  var arborAnswers: Bool { withArbor && (runner.isRunning || runner.isPaused) }
  var arborActs: Bool { arborAnswers && !paused && fullScreen == nil }

  private func known(_ window: WindowID) -> StateSnapshot.Window? {
    arborAnswers ? runner.controller.snapshot().windows.first { $0.id == window } : nil
  }
  func isManaged(_ window: WindowID) -> Bool { known(window)?.managed == true }
  public func isDocked(_ window: WindowID) -> Bool { known(window)?.docked == true }
  func isFloating(_ window: WindowID) -> Bool { known(window).map { $0.managed && !$0.docked } == true }
  /// Where Arbor last saw it, in whole points.
  func frameOf(_ window: WindowID) -> (x: Int, y: Int, w: Int, h: Int)? { known(window).map { Self.whole($0.frame) } }
  /// It has a slot in the layout that shows, and is not out of view.
  func inView(_ window: WindowID) -> Bool {
    guard arborAnswers, let state = known(window), !state.parked else { return false }
    return runner.controller.snapshot().displays.contains { $0.windowFrames[window] != nil }
  }

  /// lib-day.sh's `day_ids`.
  func ids() -> (docked: [WindowID], floating: [WindowID], tiles: [(window: WindowID, place: String, frame: CGRect, display: DisplayID, node: NodeID)]) {
    guard arborAnswers else { return ([], [], []) }
    let state = runner.controller.snapshot()
    let managed = state.windows.filter(\.managed)
    let tiles = state.displays.flatMap { display in
      display.tiles.flatMap { tile in
        tile.windows.map { window in
          let whole = Self.whole(tile.frame)
          return (window, "\(whole.x):\(whole.y):\(whole.w):\(whole.h)", tile.frame, display.id, tile.node)
        }
      }
    }
    return (managed.filter(\.docked).map(\.id), managed.filter { !$0.docked }.map(\.id), tiles)
  }

  /// As Python's `round` and awk's `+ 0.5` make whole numbers of a frame: the arithmetic after it is the shell's, in whole numbers.
  static func whole(_ frame: CGRect) -> (x: Int, y: Int, w: Int, h: Int) {
    (Int(frame.minX.rounded()), Int(frame.minY.rounded()), Int(frame.width.rounded()), Int(frame.height.rounded()))
  }

  // MARK: What the script asks the Mac (apptool, pointer)

  public func window(of app: String) -> WindowID? { members[app]?.window }
  /// The window that was given that label last and is still there.
  func window(labelled label: String) -> WindowID? { labels.filter { $0.value == label && system.windows[$0.key] != nil }.keys.max() }
  func pid(of app: String) -> Int32? { members[app]?.pid }
  func name(ofPid pid: Int32?) -> String? { pid.flatMap { pid in cast.first { members[$0]?.pid == pid } } }

  /// The app in front: whose window has the keyboard. (When Arbor gives a window the keyboard macOS brings its app forward; the stand-in says nothing of the app
  /// then.) An app without a window can be in front too.
  public var frontApp: String? {
    if let name = name(ofPid: system.focused.flatMap { system.windows[$0]?.snapshot.pid }) { return name }
    return system.frontmost?.bundleID.flatMap { bundle in members.values.first { $0.app.bundleID == bundle && $0.pid != nil }?.app.word }
  }
  var frontPid: Int32? { frontApp.flatMap { pid(of: $0) } }
  /// The window with the keyboard.
  var frontWindow: WindowID? { system.focused }

  /// Every standard window of an app as Accessibility lists them: minimized or not, and the native tabs that are behind the one that shows.
  func windows(ofPid pid: Int32?) -> [WindowID] {
    (Array(system.windows.filter { $0.value.snapshot.pid == pid }.keys) + Array(system.backgroundTabs.filter { $0.value.snapshot.pid == pid }.keys)).sorted()
  }

  /// The window of that app that has, or would have, the keyboard.
  func mainWindow(ofPid pid: Int32?) -> WindowID? {
    system.windowsFrontToBack().first { id in
      guard let snapshot = system.windows[id]?.snapshot else { return false }
      return snapshot.pid == pid && !snapshot.isMinimized
    }
  }

  /// A member of the cast whose window is there to be seen or to be brought into view.
  func present(_ app: String) -> Bool {
    cast.contains(app) && window(of: app) != nil && pid(of: app) != nil && !minimized.contains(app) && !hidden.contains(app)
  }

  /// At least nine tenths of it are on one display.
  func shows(_ window: WindowID) -> Bool {
    guard let frame = system.windows[window]?.snapshot.frame, frame.area > 0 else { return false }
    return system.displayList.contains { frame.intersection($0.frame).area / frame.area >= 0.895 }
  }

  /// What shows at a point: a window, or behind all of them a tile of Arbor's.
  func top(at point: CGPoint) -> (window: WindowID?, isArbors: Bool) {
    let window = system.windowsFrontToBack().first { id in
      guard let snapshot = system.windows[id]?.snapshot else { return false }
      return !snapshot.isMinimized && !snapshot.isHidden && snapshot.isOnActiveSpace && snapshot.frame.contains(point)
    }
    if let window { return (window, false) }
    return (nil, runner.isRunning && runner.harness.overlays.tiles.values.contains { $0.contains { $0.frame.contains(point) } })
  }

  /// `apptool grab`: along the top of the window, from the middle outwards, a point that this window shows, with nothing in front all round it. What a real
  /// title bar has besides (an address field, a search field, tabs, which take the press for themselves) the stand-ins do not have.
  func grab(_ window: WindowID?) -> CGPoint? {
    guard let window, let snapshot = system.windows[window]?.snapshot, !snapshot.isMinimized, !snapshot.isHidden else { return nil }
    let frame = snapshot.frame
    var columns: [CGFloat] = []
    var x = frame.minX + 84
    while x < frame.maxX - 20 {
      columns.append(x)
      x += 14
    }
    if columns.isEmpty { columns = [frame.midX] }
    // A stable order, whatever the sort: two columns are as far from the middle as each other.
    columns = columns.enumerated().sorted { (abs($0.element - frame.midX), $0.offset) < (abs($1.element - frame.midX), $1.offset) }.map(\.element)
    for offset in [12, 20, 7] as [CGFloat] {
      for column in columns {
        let point = CGPoint(x: column.rounded(), y: (frame.minY + offset).rounded())
        guard system.displayList.contains(where: { $0.frame.contains(point) }) else { continue }
        let around = [(0, 0), (-10, 0), (10, 0), (0, 8)].map { CGPoint(x: point.x + CGFloat($0.0), y: point.y + CGFloat($0.1)) }
        if around.allSatisfy({ top(at: $0).window == window }) { return point }
      }
    }
    return nil
  }

  // MARK: What a person's hands do

  /// A shortcut of Arbor's, pressed and let go.
  func key(_ command: String) {
    samples.key(at: clock)
    does(.key(command, .pressed))
    pass(0.05)
    does(.key(command, .released))
  }

  /// lib-day.sh's `must ctl …`: what is in Arbor's menu and on no key is asked of `arborctl`, which fails when Arbor refuses.
  @discardableResult
  func mustCtl(_ command: String) -> Bool {
    does(.command(command))
    guard !runner.refusals.isEmpty else { return true }
    acts[acts.count - 1].wasPerformed = false
    return false
  }

  /// A key that is an app's or macOS's.
  func otherKey() { samples.key(at: clock) }

  /// Somewhere in the Dock. Where an icon is nobody here knows, and nothing depends on it.
  func clickInTheDock() {
    let point = CGPoint(x: screen.midX, y: screen.maxY - 30)
    does(.cursor(point))
    samples.click(point, at: clock)
    pass(0.05)
    does(.cursor(CGPoint(x: point.x, y: point.y - 200)))
  }

  func click(_ point: CGPoint, on window: WindowID?) {
    does(.cursor(point))
    samples.click(point, at: clock)
    if let window { does(.focus(window)) }
    pass(0.05)
  }

  /// lib-day.sh's `click_window`.
  func clickTitleBar(of window: WindowID, at point: CGPoint) {
    click(point, on: window)
    does(.cursor(CGPoint(x: point.x, y: point.y + 120)))
  }

  /// An app comes forward, with all its windows: the one that would have the keyboard gets it. Without a window only the app is reported.
  func comesForward(_ app: String) {
    if let pid = pid(of: app), windows(ofPid: pid).filter({ system.windows[$0] != nil }).count > 1 { does(.appForward(pid: pid)) }
    if let window = mainWindow(ofPid: pid(of: app)) { does(.focus(window)) } else if let member = members[app] { does(.activate(member.app.bundleID)) }
  }

  /// lib-day.sh's `drag_window`: pressed on the title bar, carried there in 0.6 s, held, let go. The stand-in takes hold in the middle of the title bar, ten
  /// points down, whichever point a Mac would find free: `by` moves the window that far, `to` takes the pointer there.
  func drag(_ window: WindowID, to target: CGPoint? = nil, by offset: CGSize? = nil, hold: Double = 0.2) {
    guard let frame = system.windows[window]?.snapshot.frame else { return }
    let start = CGPoint(x: frame.midX, y: frame.minY + 10)
    let end = target ?? CGPoint(x: start.x + (offset?.width ?? 0), y: start.y + (offset?.height ?? 0))
    does(.cursor(start))
    // The press makes it the window with the keyboard, in front of the others, before it has moved a point.
    if system.focused != window { does(.focus(window)) }
    does(.grab(window))
    for piece in 1...6 {
      pass(0.1)
      let share = CGFloat(piece) / 6
      // `cursor`, which goes wherever a pointer can: `carry` stops short of the menu bar, and that is where macOS fills the screen.
      does(.cursor(CGPoint(x: (start.x + (end.x - start.x) * share).rounded(), y: (start.y + (end.y - start.y) * share).rounded())))
    }
    // What the script does between the last move and the release takes a moment too.
    pass(hold + 0.1)
    does(.release)
  }

  // MARK: Windows that come

  func newWindow(of app: RealApp, pid: Int32, frame: CGRect) -> ChaosAction.NewWindow {
    var new = ChaosAction.NewWindow(id: WindowID(nextWindow), app: app.name, pid: pid, frame: frame)
    nextWindow += 1
    (new.minimum, new.maximum, new.bundle, new.cells, new.ideal) = (app.minimum, app.maximum, app.bundleID, app.cells, app.zoomsTo)
    return new
  }

  func newPid() -> Int32 {
    nextPid += 1
    return nextPid
  }

  /// After every event: who is in front now was in front last.
  func noteWhoIsInFront() {
    guard let app = frontApp, recentApps.first != app else { return }
    recentApps.removeAll { $0 == app }
    recentApps.insert(app, at: 0)
  }

  // MARK: The beginning and the end

  var displays: [DisplaySnapshot] {
    var all = [DisplaySnapshot(id: DisplayID("main"), frame: scene.frame, visibleFrame: scene.visible, isMain: true)]
    if second {
      let size = secondSize
      let x = secondIsOnTheLeft ? scene.frame.minX - size.width : scene.frame.maxX
      let frame = CGRect(x: x, y: scene.frame.minY, width: size.width, height: size.height)
      all.append(
        DisplaySnapshot(
          id: DisplayID("side"), frame: frame, visibleFrame: CGRect(x: frame.minX, y: frame.minY + 31, width: frame.width, height: frame.height - 31), isMain: false))
    }
    return all
  }
  var secondSize = CGSize(width: 1920, height: 1080)
  var secondIsOnTheLeft = false

  /// `walk_begin`: the Mac, the apps, macOS seen to tile or not to, Arbor started.
  public func begin() {
    guard !hasBegun else { return }
    hasBegun = true
    _ = clock
    does(.displays(displays, .never))
    does(.macTiling(on: setting.tiling == .defaults))
    note("tiling \(setting.tiling.rawValue)")

    chapter("Before Arbor: the apps are open already")
    for (word, frame) in scene.windows {
      guard let app = RealApp.named(word) else { continue }
      act(.openClose, "open-\(word)", "opens \(word)")
      let new = newWindow(of: app, pid: newPid(), frame: frame)
      does(.open(new))
      does(.focus(new.id))
      members[word] = Member(app: app, window: new.id, pid: new.pid)
      label(new.id, word)
      if let second = app.secondWindow {
        let other = newWindow(of: app, pid: new.pid, frame: second)
        does(.open(other))
        label(other.id, "\(word)-2")
        does(.focus(new.id))
      }
      cast.append(word)
      acted(["setup=1"])
      noteWhoIsInFront()
    }
    setTheScene()
    // The pile as it was found: apps are opened in the background, and come to lie as macOS pleases.
    for label in scene.pile.reversed() { if let window = window(labelled: label) { does(.focus(window)) } }
    // So with who was in front. Those that never were come after those that were, the one opened last first.
    if !scene.recent.isEmpty {
      let never = (cast + (members["quicktime"] == nil ? [] : ["quicktime"])).reversed().filter { !scene.recent.contains($0) }
      recentApps = scene.recent.filter(cast.contains) + never
    }
    say("the cast: \(cast.joined(separator: " "))")

    // A switch that is written and not obeyed proves nothing: before anything counts, macOS is seen to fill the screen, or not to.
    if let probe = window(of: "calendar") ?? window(of: "textedit") ?? cast.last.flatMap({ window(of: $0) }), let owner = name(ofPid: system.windows[probe]?.snapshot.pid) {
      var seen = false
      for attempt in 1...3 {
        act(.dragWhereMacOSTiles, "tiling-acts", "without Arbor: drags a window by its title bar against the menu bar and lets go")
        clickInTheDock()
        comesForward(owner)
        pass(0.5)
        drag(probe, to: CGPoint(x: screen.minX + (screen.width / 2).rounded(.down), y: screen.minY), hold: 1)
        acted(["setup=1"])
        if eventually({ fillsTheDisplay(probe) }) { seen = true }
        act(.dragWhereMacOSTiles, "tiling-acts-back", "drags it away again, a hand's breadth down")
        drag(probe, to: CGPoint(x: screen.minX + (screen.width / 2).rounded(.down), y: screen.minY + 130))
        acted(["setup=1"])
        if seen || (setting.tiling == .off && attempt >= 2) { break }
      }
      say("macOS's tiling was seen to act: \(seen)")
      noteWhoIsInFront()
    }
    act(.idle, "look-around", "looks at the screen")
    for (label, frame) in scene.atTheStart.sorted(by: { $0.key < $1.key }) { if let window = window(labelled: label) { does(.move(window, frame)) } }
    pass(2)
    acted(["setup=1", "own=all"])

    inputRound("before")
    chapter("The walk")
    if withArbor {
      start()
      inputRound("started")
    }
    atHome()
  }

  /// `walk_scene`: what a cast has besides its apps' first windows. All of it before anything counts.
  private func setTheScene() {
    switch setting.cast {
    case .stock: break
    case .browsers:
      // Several windows each.
      for name in cast where RealApp.named(name)?.isABrowser == true && present(name) {
        guard let member = members[name], let pid = member.pid, let front = mainWindow(ofPid: pid).flatMap({ system.windows[$0]?.snapshot.frame }) else { continue }
        act(.openClose, "second-window-\(name)", "brings \(name) forward and presses ⌘N")
        clickInTheDock()
        comesForward(name)
        pass(0.5)
        otherKey()
        let new = newWindow(of: member.app, pid: pid, frame: cascaded(from: front, size: front.size))
        does(.open(new))
        does(.focus(new.id))
        label(new.id, "\(name)-2")
        acted(["setup=1"])
      }
    case .awkward:
      // Native tabs: two windows to Accessibility, one on the screen.
      for name in ["finder", "terminal"] where present(name) {
        guard let member = members[name], let pid = member.pid, let old = member.window, let frame = system.windows[old]?.snapshot.frame else { continue }
        act(.openClose, "tab-\(name)", "brings \(name) forward and presses ⌘T")
        clickInTheDock()
        comesForward(name)
        pass(0.5)
        otherKey()
        let tab = newWindow(of: member.app, pid: pid, frame: frame).id
        does(.openTab(tab, in: old))
        pass(1)
        // The tab that shows is the app's window from now on: the one it opened with is listed still, and is on no screen.
        if system.windows[tab] != nil {
          label(old, "\(name)-tab-behind")
          members[name]?.window = tab
          label(tab, name)
        }
        acted(["setup=1"])
      }
      // An app with no window at all: it has a place in the Dock and under ⌘Tab, and nothing to arrange.
      act(.openClose, "open-quicktime", "opens QuickTime Player, which puts up no window")
      members["quicktime"] = Member(app: RealApp.named("quicktime")!, window: nil, pid: newPid())
      recentApps.append("quicktime")
      acted(["setup=1"])
      // An open panel, which belongs to its app and to no window. The stand-ins have no such thing: TextEdit comes forward, and that is all.
      if present("textedit") {
        act(.openClose, "panel-textedit", "brings TextEdit forward and presses ⌘O")
        clickInTheDock()
        comesForward("textedit")
        pass(0.5)
        otherKey()
        pass(1)
        acted(["setup=1"])
      }
    }
  }

  /// Where ⌘N puts a window, as Safari was seen to: as large as the one in front, 29 points further right and down, and from the left or the top
  /// again where that would reach beyond the screen.
  func cascaded(from frame: CGRect, size: CGSize) -> CGRect {
    let visible = system.displayList.first { $0.frame.contains(frame.center) }?.visibleFrame ?? scene.visible
    var origin = CGPoint(x: frame.minX + 29, y: frame.minY + 29)
    if origin.x + size.width > visible.maxX { origin.x = visible.minX }
    if origin.y + size.height > visible.maxY { origin.y = visible.minY }
    return CGRect(origin: origin, size: size)
  }

  /// `input_round`: an instrument, not an act. The same presses, keys, a scroll and a drag inside a window, four times in a journey, so that the gate can tell who holds input
  /// back. How late a press arrives no stand-in knows. What is played here is what the round leaves behind: it moves no window, but who is in front, and the pile, are others after it.
  func inputRound(_ name: String) {
    // TextEdit has an open panel up in that cast, and takes nothing else meanwhile.
    let desk = setting.cast == .awkward ? "safari" : "textedit"
    act(.instrument, "input-\(name)", "a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window")
    var pressed = 0
    for _ in 1...4 {
      for each in cast where pressed < 14 {
        // Mail's window has a sheet, which answers for it.
        guard each != "mail", each != desk, present(each), frontPid != pid(of: each), let window = window(of: each), let point = grab(window) else { continue }
        click(point, on: window)
        pressed += 1
        pass(0.1)
      }
    }
    guard present(desk), let window = window(of: desk), let point = grab(window) else {
      say("  \(pressed) presses on windows behind; \(desk) shows no free point of its title bar, so that is all")
      return acted(["round=\(name)"])
    }
    click(point, on: window)
    pass(0.3)
    for _ in 1...12 {
      samples.click(point, at: clock)
      pass(0.1)
    }
    for _ in 1...12 { otherKey() }
    pass(1)
    say("  \(pressed) presses on windows behind; the rest in \(desk)")
    // Without lib-walk.sh's `posted=`: it is held against what a witness at the far end of the event taps saw arrive, and here is no witness. jolts.py would take all of it for lost.
    acted(["round=\(name)", "front=\(window.rawValue)"])
  }

  private func fillsTheDisplay(_ window: WindowID) -> Bool {
    guard let frame = system.windows[window]?.snapshot.frame else { return false }
    return frame.width >= screen.width - 40 && frame.height >= screen.height - 160
  }

  /// `walk_end`: whatever is still owed is paid, Arbor is quit if it runs, every window is reached.
  public func end() {
    guard hasBegun, !hasEnded else { return }
    hasEnded = true
    if fullScreen != nil { play(.fullScreen(false)) }
    if second { play(.display(.unplug)) }
    if paused { play(.resume) }
    while !hidden.isEmpty { play(.unhide(nil)) }
    while !minimized.isEmpty { play(.restore(nil)) }
    if arborAnswers {
      chapter("The end")
      inputRound("last")
      quit()
      inputRound("after")
      rollCall()
    } else {
      inputRound("after")
    }
    say("")
    say("\(walkActs) acts, \(leftOut.count) left out because they did not apply")
    samples.stop(at: clock)
  }

  /// `walk_start`.
  func start() {
    walkAct(.quitAndStart, "launch", "starts Arbor")
    does(.launch)
    arborPid += 1
    samples.arbor = arborPid
    note("arbor \(arborPid)")
    sinceStart = 0
    // What was docked when it stopped may go back. No window that is in view goes out of view.
    acted(["moves=docked", "everything=1"])
    // lib-walk.sh closes Arbor's welcome here if it is up. As the harness starts Arbor none has been, in any run on a hosted Mac so far, and the stand-ins have none.
    changed()
  }

  /// `walk_quit`.
  func quit() {
    walkAct(.quitAndStart, "quit", "chooses Quit Arbor in Arbor's menu")
    samples.click(CGPoint(x: screen.maxX - 200, y: screen.minY + 12), at: clock)
    pass(0.3)
    does(.command("quit"))
    samples.arbor = nil
    note("arbor gone")
    (paused, beforePause) = (false, nil)
    acted(["moves=any", "restores=all", "places=1", "everything=1"])
  }

  /// After Quit every app still comes when it is called. `rollCall(every: 3)`: every third one, and not the same ones each time.
  func rollCall(every: Int = 1) {
    var at = walkActs
    for app in cast {
      at += 1
      if at % every == 0 { play(.switchDock(app)) }
    }
  }

  // MARK: There and back

  func changed() { home = nil }
  func atHome() { home = step }
  var backHome: [String] { home.map { ["returns=\($0)"] } ?? [] }
  func leaving(_ app: String) { leftAt[app] = step }
  func cameBack(_ app: String) -> [String] {
    let left = leftAt[app] ?? 0
    return left == step - 1 ? ["returns=\(left - 1)"] : []
  }
}
