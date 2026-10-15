import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// A run that broke a rule: which rule, at which step, and the script that gets there.
public struct ChaosFailure: Sendable, CustomStringConvertible {
  /// The seed of the run, or nil for a replayed script.
  public var seed: UInt64?
  /// Every rule the last action of `script` broke; the first names the failure.
  public var violations: [InvariantViolation]
  /// The actions up to and including the one that broke the rule.
  public var script: [ChaosAction]

  public init(seed: UInt64?, violations: [InvariantViolation], script: [ChaosAction]) {
    self.seed = seed
    self.violations = violations
    self.script = script
  }

  public var rule: String { violations.first?.rule ?? "none" }

  public var description: String {
    var lines = ["chaos: \(seed.map { "seed \($0)" } ?? "script") broke a rule at step \(script.count):"]
    lines += violations.prefix(6).map { "  \($0)" }
    if violations.count > 6 { lines.append("  … and \(violations.count - 6) more") }
    lines.append("replay with `arbor-sim replay` (the script on standard input) or `ChaosRunner.replay(\"\"\"…\"\"\")`:")
    lines += script.map { "    \($0.text)" }
    return lines.joined(separator: "\n")
  }
}

/// A Mac with Arbor on it: windows, displays, settings.json and state.json that outlive Arbor's
/// process, and the process itself (a `Harness`), which can quit, crash and be launched again.
/// `step` applies one action and checks every invariant.
@MainActor
public final class ChaosRunner {
  /// The windows and displays. They stay when Arbor's process goes.
  public let system = FakeWindowSystem()
  /// The current run of Arbor, or the last one while `isRunning` is false.
  public private(set) var harness: Harness
  public var controller: Controller { harness.controller }
  /// What the last `palette choose` chose, for the rule about it.
  var chosenInThePalette: FinderDestination?
  public var isRunning: Bool { controller.isRunning }
  /// Between `pause` and `resume`: the process lives, but observes nothing and arranges nothing.
  public var isPaused: Bool { controller.isPaused }
  /// The actions applied so far.
  public private(set) var script: [ChaosAction] = []
  /// Whether `state` and state.json are read back after every step, rather than now and then.
  public var checksFilesAtEveryStep = false
  /// Called with every action of every runner before it is applied. arbor-sim's watchdog listens.
  public static var beforeEachStep: ((ChaosAction) -> Void)?

  /// settings.json, as the object in the file. A walk begins with the gestures switched on, though they ship off: the net over the zones of
  /// the Desktop (`guard-zones`) catches nothing where nobody asks for zones. `set pointerGestures` is among a walk's steps.
  /// And with the whole map of shortcuts, though nine ship: a walk presses the key of a command (`key down home`), and a command without
  /// a key is a step in which nothing happens and no net catches anything. `set shortcuts` is among a walk's steps too.
  private var settingsFile: [String: Any] = ["pointerGestures": true, "shortcuts": "all"]
  /// state.json, and what was written to it, as of the last save.
  private var stateFile: Data?
  private var stateWritten: PersistedState?
  /// `corrupt` has been at state.json since Arbor wrote it.
  private var stateFileIsDamaged = false
  /// Seconds that passed before the current run of Arbor started.
  private var elapsed: Double = 0
  /// Every display id seen so far: timers are keyed by display.
  var displayIDsSeen: Set<DisplayID> = []
  /// Windows renumbered since Arbor last ran, new number by old.
  var renumbered: [WindowID: WindowID] = [:]
  /// Rules broken while the action itself ran (after a shutdown or a launch), for `check`.
  var found: [InvariantViolation] = []
  /// Which windows Arbor arranged, and how long `frameLog` was, before the current action.
  var filterBefore = WindowFilter()
  var frameLogMark = 0
  /// The windows Arbor still owed a place in view before the current action (`Controller.windowsOwedAPlace`).
  var owedAPlaceBefore: Set<WindowID> = []
  /// What was out of view, where the cameras were and which run of Arbor it was, before the current action.
  var parkedBefore: Set<WindowID> = []
  /// `Controller.windowsOfTheAwaitedGroup` when the step began.
  var awaitedGroupBefore: Set<WindowID> = []
  /// `Controller.everybodyOfTheAwaitedGroup` when the step began.
  var everybodyAwaitedBefore: Set<WindowID> = []
  /// Where every window stood at the beginning of the last step at which nobody was awaited: before the `side-by-side` that awaits.
  var framesBeforeAnybodyWasAwaited: [WindowID: CGRect] = [:]
  /// Windows whose app did not answer when they were to be moved: the move comes when it does, whatever else happens then.
  var owedAMoveBefore: Set<WindowID> = []
  /// Where macOS put each floating window that was wholly on a display when that display moved without changing, and how often
  /// somebody other than Arbor had moved it by then. Forgotten with the next step that may well move a floating window.
  var restingPlaces: [WindowID: (frame: CGRect, moves: Int)] = [:]
  var displaysBeforeTheChange: Set<DisplayID> = []
  var userPlaces: [WindowID: [UserPlace]] = [:]
  var inHandBefore: WindowID?
  /// For the harness's own tests: something done as part of the next step, as if Arbor had done it.
  public var beforeTheNextCheck: ((ChaosRunner) -> Void)?
  /// What the last step broke of `countedRules`.
  public private(set) var counted: [InvariantViolation] = []
  /// Windows that somebody other than Arbor has ever left across the edge of a display: hanging over it, or straddling two.
  var leftAcrossAnEdge: Set<WindowID> = []
  var theChangeChangedNothing = false
  /// What the nets for the product's seven rules remember (ChaosInvariants+SevenRules.swift).
  var seven = SevenRules()
  /// How many windows had been raised when the step began (ChaosInvariants+Raises.swift).
  var raiseLogMark = 0
  /// The displays there were last, for as long as there are none.
  private var lastDisplays: [DisplaySnapshot] = []
  var owedTheWayBackBefore: Set<WindowID> = []
  var workspacesBefore: [DisplayID: Workspace] = [:]
  /// What each display really showed: wider than its camera while the space the camera is on had nothing to show.
  var viewsBefore: [DisplayID: NodeID] = [:]
  var displaysBefore: [DisplaySnapshot] = []
  var framesBefore: [WindowID: CGRect] = [:]
  var presentBefore: Set<WindowID> = []
  var timersBefore: [String] = []
  /// A layout has been out of date since a window was dropped (a known failure).
  var staleSinceADrop = false
  /// Whether the last command succeeded, and what was true before the `undo` that was the last action.
  var lastCommandSucceeded = false
  /// What Arbor answered to the commands of the current step that it refused. A script whose `hold` was refused says nothing about holds.
  public private(set) var refusals: [String] = []
  var beforeUndo: (workspaces: [DisplayID: Workspace], parked: Set<WindowID>, slots: [DisplayID: [WindowID: CGRect]])?
  var holdBefore: HoldLevel?
  var staleSinceAPeek = false
  var wasPeekingBefore = false
  /// For each background tab of a native tab group, the window that stands for the group.
  public private(set) var frontOfTab: [WindowID: WindowID] = [:]
  /// Windows that came back into sight while the Desktop of their display was out of view, and have not followed it yet.
  var cameBack: Set<WindowID> = []
  var wasRunningBefore = false
  /// Before the current action the windows were trying out a drop (F09, `reflowWhileDragging`).
  var wasTryingOutADrop = false
  /// Where the floating windows that are out of view were when they left (ChaosInvariants+OwnFrames.swift), and before the current
  /// action whether floating windows made way.
  var departures: [WindowID: Departure] = [:]
  var leftByHand: [WindowID: HandNote] = [:]
  var movedByUndo: Set<WindowID> = []
  var madeWayBefore = false
  /// `desktopGuardZones()` as the mouse-down tap has it: a copy, refreshed as ArborApp refreshes it.
  var guardZonesCopy = DesktopGuardZones()

  public init() {
    system.holdsEchoes = true
    harness = Harness(settings: Settings(), system: system)
    system.events = nil  // nothing is observed until `launch`
    displayIDsSeen = Set(system.displayList.map(\.id))
  }

  // MARK: Running

  /// Runs `steps` random actions from `seed`, then settles and quits. Returns the first failure.
  /// With `trace`, each action is printed to standard error before it runs, so that a crash
  /// (which takes the process with it) can be located and replayed.
  /// The run carries on past the rules in `excusing`, by default those of `knownFailures` (ChaosKnownFailures.swift), and
  /// `known` is told once about each of them that broke.
  public static func run(
    seed: UInt64, steps: Int, trace: Bool = false, excusing excused: Set<String> = knownRules, echo: ((String) -> Void)? = nil,
    known: ((String) -> Void)? = nil
  ) -> ChaosFailure? {
    Log.silenced {
      loggedRun(seed: seed, steps: steps, trace: trace, excused: excused, echo: echo, known: known)
    }
  }

  private static func loggedRun(
    seed: UInt64, steps: Int, trace: Bool, excused: Set<String>, echo: ((String) -> Void)?, known: ((String) -> Void)?
  ) -> ChaosFailure? {
    let runner = ChaosRunner()
    var generator = ChaosGenerator(seed: seed)
    var told = Set<String>()
    func step(_ action: ChaosAction) -> ChaosFailure? {
      if trace { FileHandle.standardError.write(Data("chaos seed \(seed) step \(runner.script.count + 1): \(action.text)\n".utf8)) }
      echo?(action.text)
      var violations = runner.step(action)
      for violation in runner.counted where told.insert(violation.rule).inserted { known?(violation.rule) }
      if !violations.isEmpty, !excused.isEmpty {
        for violation in violations where excused.contains(violation.rule) && told.insert(violation.rule).inserted {
          known?(violation.rule)
        }
        violations.removeAll { excused.contains($0.rule) }
      }
      return violations.isEmpty ? nil : ChaosFailure(seed: seed, violations: violations, script: runner.script)
    }
    for _ in 0..<steps {
      if let failure = step(generator.next(runner)) { return failure }
    }
    // Whatever happened, the three things a person tries when a window is gone each bring every window within reach.
    // Each comes first in its share of the walks, from the state the walk ended in: held, framed, paused, in the middle of a drag.
    let ways = WayBack.allCases
    let first = Int(seed % UInt64(ways.count))
    for action in (ways[first...] + ways[..<first]).map({ ChaosAction.wayBack($0) }) {
      if let failure = step(action) { return failure }
    }
    return nil
  }

  /// Runs a script from a fresh start. Returns the first failure, with the script cut off there. Carries on
  /// past the rules in `excusing`.
  public static func replay(_ script: [ChaosAction], excusing excused: Set<String> = []) -> ChaosFailure? {
    Log.silenced {
      let runner = ChaosRunner()
      runner.checksFilesAtEveryStep = true
      for action in script {
        var violations = runner.step(action)
        if !violations.isEmpty, !excused.isEmpty { violations.removeAll { excused.contains($0.rule) } }
        if !violations.isEmpty { return ChaosFailure(seed: nil, violations: violations, script: runner.script) }
      }
      return nil
    }
  }

  public static func replay(_ text: String) -> ChaosFailure? { replay(ChaosAction.script(text)) }

  /// Plays a script to its end whatever breaks, as `arbor-sim replay --go-on` does, and says what broke at which step (from 1).
  public static func replayToTheEnd(_ script: [ChaosAction]) -> [(step: Int, act: ChaosAction, rule: String)] {
    Log.silenced {
      let runner = ChaosRunner()
      runner.checksFilesAtEveryStep = true
      return script.enumerated().flatMap { index, action in runner.step(action).map { (index + 1, action, $0.rule) } }
    }
  }

  /// Applies one action and returns the rules that do not hold afterwards.
  public func step(_ done: ChaosAction) -> [InvariantViolation] {
    Self.beforeEachStep?(done)
    script.append(done)
    // A row of Go to… that runs a command is that command, asked for as by its key: the rules judge it as such.
    var action = done
    if case .palette(.choose(let row)) = done, let session = harness.overlays.finder,
      case .command(let text)? = row.map({ $0 >= 1 ? session.destination(atVisible: $0 - 1) : nil }) ?? session.selected
    {
      action = .via(.shortcut, text)
    }
    found = []
    refusals = []
    filterBefore = controller.filter
    frameLogMark = system.frameLog.count
    owedAPlaceBefore = controller.windowsOwedAPlace
    owedTheWayBackBefore = controller.windowsOwedTheWayBack
    (awaitedGroupBefore, everybodyAwaitedBefore) = (controller.windowsOfTheAwaitedGroup, controller.everybodyOfTheAwaitedGroup)
    (parkedBefore, workspacesBefore, displaysBefore, wasRunningBefore) = (
      controller.parked, controller.workspaces, controller.displays, isRunning
    )
    viewsBefore = controller.layouts.mapValues(\.camera)
    framesBefore = system.windows.mapValues(\.snapshot.frame)
    if everybodyAwaitedBefore.isEmpty { framesBeforeAnybodyWasAwaited = framesBefore }
    presentBefore = Set(system.windows.values.lazy.filter(\.snapshot.isPresent).map(\.snapshot.id))
    timersBefore = harness.scheduler.pendingKeys
    wasTryingOutADrop = controller.draggedWindow != nil && controller.settings.reflowWhileDragging
    holdBefore = isRunning ? controller.holdLevel : nil
    owedAMoveBefore = controller.windowsOwedAMove
    wasPeekingBefore = timersBefore.contains("peek")
    let movesBefore = system.windows.mapValues(\.movesNotArbors)
    inHandBefore = system.dragging ?? system.resizing
    noteBeforeTheSevenRules(action)
    raiseLogMark = system.raiseLog.count
    madeWayBefore = controller.settings.floatingWindowsMakeWay
    perform(done)
    listen()
    beforeTheNextCheck?(self)
    beforeTheNextCheck = nil
    noteWhereItsUserLeftEachWindow(after: action, movesBefore: movesBefore)
    noteAfterTheSevenRules(action, movesBefore: movesBefore)
    let all =
      found + wayHomeViolations(after: action) + raiseViolations(after: action) + undoneViolations(after: action) + check(after: action)
    // Numbers, not gates: no walk, replay or test ends at them.
    counted = all.filter { Self.countedInThisRun.contains($0.rule) }
    return counted.isEmpty ? all : all.filter { !Self.countedInThisRun.contains($0.rule) }
  }

  /// Where somebody other than Arbor last put each window, as seen from the corner of the display that shows most of it, and
  /// what that display was like. macOS carrying a window along with its display is nobody putting it anywhere.
  private func noteWhereItsUserLeftEachWindow(after action: ChaosAction, movesBefore: [WindowID: Int]) {
    // A native tab is where its group is. Before what is known of windows that are gone is forgotten: the tab in front until now is one.
    if case .openTab(let new, let front) = action, userPlaces[new] == nil {
      userPlaces[new] = userPlaces[front]
      if leftAcrossAnEdge.contains(front) { leftAcrossAnEdge.insert(new) }
    }
    if case .selectTab(let tab, let front) = action, userPlaces[tab] == nil {
      userPlaces[tab] = userPlaces[front]
      if leftAcrossAnEdge.contains(front) { leftAcrossAnEdge.insert(tab) }
    }
    userPlaces = userPlaces.filter { system.windows[$0.key] != nil }
    leftAcrossAnEdge = leftAcrossAnEdge.filter { system.windows[$0] != nil }
    if case .displays = action { return }
    if case .wayBack = action { return }
    func note(_ id: WindowID, _ frame: CGRect) {
      if !system.displayList.contains(where: { $0.frame.contains(frame) }) { leftAcrossAnEdge.insert(id) }
      guard let display = Self.display(showingMostOf: frame, among: system.displayList) else { return }
      // Every place it was given on a display that is still as it was counts: `float-all` takes a window back to an earlier one.
      var place = UserPlace(
        overhang: UserPlace.overhang(of: frame, on: display), showing: Self.area(of: frame, showingOn: system.displayList), display: display)
      if let index = userPlaces[id, default: []].firstIndex(where: { $0.isOn(display) }) {
        let known = userPlaces[id]!.remove(at: index)
        place.overhang = zip(known.overhang, place.overhang).map(max)
        place.showing = min(known.showing, place.showing)
      }
      userPlaces[id, default: []].append(place)
    }
    // A native tab, or a window under a new number, is where its group or its old number was left. First of all: what follows notes under the new number.
    switch action {
    case .openTab(let new, let old), .selectTab(let new, let old), .renumber(let old, let new):
      if userPlaces[new] == nil, movesBefore[new] == nil { userPlaces[new] = userPlaces[old] }
      if leftAcrossAnEdge.contains(old) { leftAcrossAnEdge.insert(new) }
    default: break
    }
    // Also where Arbor has moved it on in the same step: `home` is the last frame that was not Arbor's.
    for (id, fake) in system.windows where fake.movesNotArbors != movesBefore[id] && movesBefore[id] != nil { if let home = fake.home { note(id, home) } }
    // Where its app opened it, or where it is when Arbor starts, counts as a place given it, if more than half of it shows there or 24 points of
    // its title bar are within reach: what is found counts as left (the product owner). What shows less is fetched.
    if case .open(let new) = action {
      let frame = Self.within(system.whereItOpens(new.frame), minimum: new.minimum, maximum: new.maximum)
      if Self.area(of: frame, showingOn: system.displayList) > 0.5 * frame.area || titleBarIsWithinReach(frame) {
        note(new.id, frame)
      } else {
        leftAcrossAnEdge.insert(new.id)
      }
    }
    // Where a window is let go of is where its user put it, whatever size Arbor gives it there (F48).
    if let dropped = inHandBefore, system.dragging != dropped, let fake = system.windows[dropped], !controller.parked.contains(dropped),
      controller.workspaces.values.contains(where: { $0.isFloating(dropped) })
    {
      note(dropped, fake.snapshot.frame)
    }
  }

  struct UserPlace {
    /// By how many points it hung over the display's left, top, right and bottom edge there, at most.
    var overhang: [CGFloat]
    /// How much of it showed there, in square points, at least.
    var showing: CGFloat
    var display: DisplaySnapshot

    static func overhang(of frame: CGRect, on display: DisplaySnapshot) -> [CGFloat] {
      [display.frame.minX - frame.minX, display.frame.minY - frame.minY, frame.maxX - display.frame.maxX, frame.maxY - display.frame.maxY]
        .map { max($0, 0) }
    }

    func allows(_ frame: CGRect, on now: DisplaySnapshot) -> Bool {
      isOn(now) && zip(Self.overhang(of: frame, on: now), overhang).allSatisfy { $0 <= $1 + 1 }
    }

    /// The same display, as large as it was. It may stand elsewhere among the displays, and its Dock and menu bar may have come or gone:
    /// an overhang is over the display's edge, not over theirs.
    func isOn(_ now: DisplaySnapshot) -> Bool { now.id == display.id && now.frame.size == display.frame.size }
  }

  static func display(showingMostOf frame: CGRect, among displays: [DisplaySnapshot]) -> DisplaySnapshot? {
    displays.max { frame.intersection($0.frame).area < frame.intersection($1.frame).area }
      .flatMap { frame.overlaps($0.frame) ? $0 : nil }
  }

  /// Tabs are opened, chosen and closed in a window that can be seen and that nobody is holding.
  private func canChangeTabs(of front: WindowID) -> Bool {
    system.dragging != front && system.resizing != front && system.windows[front]?.snapshot.isPresent == true
  }

  private func bringToFront(_ tab: WindowID, insteadOf front: WindowID) {
    for (other, its) in frontOfTab where its == front { frontOfTab[other] = tab }
    frontOfTab[front] = tab
    frontOfTab[tab] = nil
  }

  /// Only a running Arbor observes the window system (`AXWindowSystem.stop()` removes its observers).
  private func listen() { system.events = isRunning ? controller : nil }

  // MARK: Actions

  func perform(_ action: ChaosAction) {
    switch action {
    case .open(let window):
      system.open(
        id: window.id, app: window.app, bundleID: window.bundleID,
        title: window.title ?? "\(window.app) \(window.id.rawValue)", pid: window.pid,
        frame: Self.within(window.frame, minimum: window.minimum, maximum: window.maximum),
        minimumSize: window.minimum, maximumSize: window.maximum, behaviour: window.behaviour, cells: window.cells,
        idealSize: window.ideal)
    case .close(let window): system.close(window)
    case .quitApp(let pid): system.quitApp(pid: pid)
    case .minimize(let window, let minimized): system.setMinimized(window, minimized)
    case .hide(let pid, let hidden): system.setHidden(pid: pid, hidden)
    case .space(let window, let showing): system.setOnActiveSpace(window, showing)
    case .fullScreen(let window, let on):
      if !system.displayList.isEmpty { system.setFullScreen(window, on) }
    case .title(let window, let title): system.setTitle(window, title)
    case .limits(let window, let minimum, let maximum):
      // An app whose window no longer fits its own limits resizes it itself, and not to where nobody could get hold of it.
      let frame = system.windows[window]?.snapshot.frame
      let fitting = frame.map { Self.within($0, minimum: minimum, maximum: maximum) }
      if let fitting, fitting != frame, !isReachable(fitting), controller.parked.contains(window) == false { return }
      system.setMinimumSize(window, minimum)
      system.setMaximumSize(window, maximum)
      if let fitting, fitting != frame { system.userMove(window, to: fitting) }
    case .behave(let window, let behaviour): system.setBehaviour(window, behaviour)
    case .move(let window, let frame):
      guard let fake = system.windows[window] else { return }
      let frame = Self.within(frame, minimum: fake.minimumSize, maximum: fake.maximumSize)
      // Nobody moves, picks up or resizes a window while no display is plugged in.
      if isReachable(frame), !system.displayList.isEmpty { system.userMove(window, to: frame) }
    case .react: system.appsReact()

    case .cursor(let point):
      // The pointer cannot leave a window it is holding behind.
      if system.dragging == nil { system.cursor = onADisplay(point) } else { system.carry(to: onADisplay(point)) }
    case .focus(let window):
      if system.windows[window] != nil { system.userFocus(window) }
    case .switchApp(let window): system.userSwitchesApp(to: window)
    case .focusNothing: system.userFocusesNothing()
    case .backgroundFocus(let window): system.backgroundFocus(window)
    case .press:
      if system.dragging == nil, system.resizing == nil { system.mouseDown = true }
    case .grab(let window):
      // Only a window that can be seen can be picked up.
      if let snapshot = system.windows[window]?.snapshot, snapshot.isPresent, isReachable(snapshot.frame), !system.displayList.isEmpty {
        system.grab(window)
      }
    case .doubleClick(let window):
      // Only a title bar that can be seen, and only with a button that is up.
      if !system.mouseDown, let snapshot = system.windows[window]?.snapshot, snapshot.isPresent, !snapshot.isFullScreen,
        isReachable(snapshot.frame), !system.displayList.isEmpty
      {
        // Where the pointer is, if it is on that title bar already: whoever aimed at a part of it that shows gets the window they aimed at.
        let bar = CGRect(x: snapshot.frame.minX, y: snapshot.frame.minY, width: snapshot.frame.width, height: system.windows[window]!.titleBar)
        system.doubleClickTitleBar(of: window, at: bar.contains(system.cursor) ? system.cursor : nil)
      }
    case .askMacOS(let window, let what):
      // Of the window in front, which can be seen, with a button that is up.
      if !system.mouseDown, system.dragging == nil, system.resizing == nil, let snapshot = system.windows[window]?.snapshot, snapshot.isPresent,
        !snapshot.isFullScreen, isReachable(snapshot.frame), !system.displayList.isEmpty
      {
        system.askMacOS(for: what, about: window)
      }
    case .carry(let point):
      // macOS does not let a title bar be dragged above the top of a display, under the menu bar.
      var point = onADisplay(point)
      if let top = system.displayList.first(where: { $0.frame.contains(point) })?.visibleFrame.minY { point.y = max(point.y, top + 10) }
      system.carry(to: point)
    case .release: system.letGo()
    case .loseRelease: system.loseTheRelease()
    case .commandKey(held: let held): system.holdModifierKeys(held ? .command : [])
    case .macTiling(on: let on): system.tiling = on ? .on : .off
    case .via(let source, let line):
      // `quit`, `pause` and the like have their promises checked in `run`.
      if let command = try? Command.parse(line), isRunning, ![.quit, .pause(minutes: nil), .togglePause].contains(command) {
        let reply = controller.perform(command, from: source)
        if !reply.ok { refusals.append(reply.message) }
      }
    case .key(let line, let phase):
      guard isRunning, let command = try? Command.parse(line),
        let binding = (controller.activeBindings + controller.temporaryShortcuts).first(where: { $0.command == command }),
        ![.quit, .togglePause].contains(command)
      else { return }
      controller.shortcut(binding, phase)
    case .pinch(let phase, let magnification):
      controller.gesture(GestureUpdate(phase: phase, location: system.cursor, magnification: magnification))
    case .activate(let bundleID): system.activate(bundleID: bundleID, name: bundleID.split(separator: ".").last.map(String.init) ?? bundleID)
    case .hang(let pid, let hung):
      // An app that wakes up has something to report about its windows, and Arbor then places what it could not.
      system.setUnresponsive(pid: pid, hung)
    case .openTab(let new, let front):
      guard canChangeTabs(of: front), !system.existingWindowIDs().contains(new), system.backgroundTabs[new] == nil else { return }
      system.openTab(id: new, in: front)
      bringToFront(new, insteadOf: front)
    case .selectTab(let tab, let front):
      guard canChangeTabs(of: front), frontOfTab[tab] == front, system.backgroundTabs[tab] != nil else { return }
      let old = system.windows[front]
      system.selectTab(tab, insteadOf: front)
      system.inherit(old, by: tab)
      bringToFront(tab, insteadOf: front)
    case .closeTab(let front, let next):
      guard canChangeTabs(of: front), frontOfTab[next] == front, system.backgroundTabs[next] != nil else { return }
      let old = system.windows[front]
      system.closeTab(front, revealing: next)
      system.inherit(old, by: next)
      bringToFront(next, insteadOf: front)
      frontOfTab[front] = nil
    case .listed(let window, let listed):
      // The Accessibility API stops listing a window only between two looks of Arbor's.
      if listed || (!isRunning && !isPaused) { system.setListed(window, listed) }
      // The displays may have changed while it was away.
      if listed { system.windows[window]?.groundHasShifted = true }
    case .edge(let window, let frame, let hold):
      // One window is dragged or resized at a time, and only from a fresh press of the button.
      guard !system.displayList.isEmpty, system.dragging == nil, system.resizing == nil ? !system.mouseDown : system.resizing == window,
        let current = system.windows[window]?.snapshot, current.isPresent, isReachable(current.frame),
        let result = system.frameAfterResizing(window, toward: frame), isReachable(result)
      else { return }
      system.userResize(window, to: frame, release: !hold)
    case .tile(let display, let node): harness.overlays.clickTile(node, on: display)
    case .palette(.type(let text)): harness.overlays.typeInFinder(text)
    case .palette(.move(let rows)): harness.overlays.moveFinderSelection(by: rows)
    case .palette(.choose(let row)):
      let session = harness.overlays.finder
      chosenInThePalette = if let row { row >= 1 ? session?.destination(atVisible: row - 1) : nil } else { session?.selected }
      harness.overlays.chooseInFinder(row: row)
    case .palette(.escape): harness.overlays.dismissFinder()
    case .seam(let display, let index, let delta):
      guard let seams = harness.overlays.seams[display], seams.indices.contains(index) else { return }
      harness.overlays.dragSeam(seams[index], by: CGFloat(delta), on: display)
    case .command(let line):
      if let command = try? Command.parse(line) {
        run(command)
      } else {
        refusals.append("`\(line)` is no command and no event that this harness knows")
        harness.run(line)
      }
    case .url(let url):
      // As ArborApp does.
      if case .success(let command) = controller.admit(url: url) { run(command) }

    case .displays(let displays, let follow): change(displays: displays, follow: follow)
    case .settings(let json):
      guard let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return }
      // An empty object: the file holds nothing, which is Arbor as it ships. At a script's head it makes a walk at the switches that ship.
      if object.isEmpty { settingsFile = [:] } else { settingsFile.merge(object) { $1 } }
      harness.run("reload-settings")
    case .flush: harness.scheduler.runPending()
    case .advance(let seconds): harness.scheduler.advance(by: min(max(seconds, 0), 60))
    case .settle: settle()

    case .wayBack(let way):
      // In one step, so that shrinking cannot take the way apart and ask the question in the middle of it.
      var broken: [InvariantViolation] = []
      for action in way.actions {
        perform(action)
        listen()
        broken += found
        found = []
      }
      found = broken
      let gone = windowsOutOfReach()
      if !gone.isEmpty {
        let frames = gone.map { "\($0) at \(system.windows[$0]!.snapshot.frame.brief)" }.joined(separator: ", ")
        found.append(.init("out-of-reach", "after \(way.rawValue) nobody can get hold of \(frames)"))
      }
      found += wayHomeViolations(way.rawValue, on: way.isAboutOneDisplay ? displaysAtHome : nil, givesSizesBack: way.givesSizesBack)
    case .save: if isRunning { controller.saveNow() }
    case .crash: if isRunning || isPaused { endProcess() }
    case .launch: if !isRunning, !isPaused { launch() }
    case .renumber(let old, let new):
      guard !isRunning, !isPaused, system.windows[old] != nil, system.windows[new] == nil else { return }
      system.renumber(old, as: new)
      renumbered[old] = new
      // It is the same window, where it was left.
      userPlaces[new] = userPlaces.removeValue(forKey: old)
      if leftAcrossAnEdge.remove(old) != nil { leftAcrossAnEdge.insert(new) }
    case .sleep(let days): if !isRunning, !isPaused { elapsed += min(max(days, 0), 400) * 86_400 }
    case .corrupt(let how): if !isRunning, !isPaused { damageStateFile(how) }
    case .appForward(let pid): system.bringForward(pid: pid)
    }
  }

  // What a user cannot do is not done, whatever the script says. Shrinking deletes the steps that made an
  // action sensible (the display it happened on, say), and must not end up with an impossible story.

  /// The pointer cannot leave the displays.
  private func onADisplay(_ point: CGPoint) -> CGPoint {
    let displays = system.displayList
    guard !displays.contains(where: { $0.frame.contains(point) }),
      let nearest = displays.min(by: { $0.frame.distance(to: point) < $1.frame.distance(to: point) })?.frame
    else { return point }
    return CGPoint(x: min(max(point.x, nearest.minX), nearest.maxX - 1), y: min(max(point.y, nearest.minY), nearest.maxY - 1))
  }

  /// No window is smaller or larger than its app allows.
  private static func within(_ frame: CGRect, minimum: CGSize, maximum: CGSize?) -> CGRect {
    var size = CGSize(width: max(frame.width, minimum.width), height: max(frame.height, minimum.height))
    if let maximum { size = CGSize(width: min(size.width, maximum.width), height: min(size.height, maximum.height)) }
    return CGRect(origin: frame.origin, size: size)
  }

  /// Nobody moves or resizes a window to where they could not get hold of it again.
  func isReachable(_ frame: CGRect) -> Bool { Self.isReachable(frame, on: system.displayList) }

  private static func isReachable(_ frame: CGRect, on displays: [DisplaySnapshot]) -> Bool {
    displays.isEmpty
      || displays.contains { display in
        // Forty points of title bar, or half of a window narrower than that, and enough of its height to hit.
        let bar = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: min(frame.height, 28))
        let showing = bar.intersection(display.frame)
        return !showing.isNull && showing.width >= min(frame.width / 2, 40) && showing.height >= min(bar.height, 12)
      }
  }

  /// The least that counts when a window is found or opens, by Arbor's own measure: a hand puts no window where so little is left to
  /// take hold of, but what is there stays.
  func titleBarIsWithinReach(_ frame: CGRect) -> Bool {
    system.displayList.isEmpty || frame.titleBarIsWithinReach(on: system.displayList.map(\.frame))
  }

  /// Lets go of the mouse, then lets apps react and timers fire until nothing is left to do. An app
  /// that fights back never lets that happen, so the rounds are limited.
  private func settle() {
    system.letGo()
    // The presenter is told of one display or one app at a time (Controller+Rehearsal.swift): a timer that comes back once for each
    // and then ends is not restless.
    let pieces = system.displayList.count + Set(system.windows.values.map(\.snapshot.pid)).count
    // So is the look at a window on its way out of full screen, a dozen times (Controller+OnTheWayBack.swift), with what each look sets going.
    for round in 0..<(8 + pieces + 16) {
      system.appsReact()
      harness.scheduler.runPending()
      let pending = harness.scheduler.pendingKeys
      if !system.hasHeldEchoes, pending.isEmpty { break }
      if round >= 7, !pending.contains(where: { $0 == "rehearsal" || $0.hasPrefix("meet-") }) { break }
    }
  }

  /// macOS moves every window along with its display, or onto the main display if its own is gone.
  private func change(displays: [DisplaySnapshot], follow: ChaosAction.WindowsFollow) {
    displayIDsSeen.formUnion(displays.map(\.id))
    // With every display unplugged macOS still knows which one each window was on, and goes by that when displays come back.
    if !system.displayList.isEmpty { lastDisplays = system.displayList }
    let old = lastDisplays
    var moves: [(window: WindowID, frame: CGRect)] = []
    var resting: [WindowID: CGRect] = [:]
    if follow != .never, let main = displays.first(where: \.isMain) ?? displays.first {
      for (id, fake) in system.windows.sorted(by: { $0.key < $1.key }) {
        let frame = fake.snapshot.frame
        // A window belongs to the display that shows most of it, or else the nearest.
        guard
          let home = old.max(by: { frame.intersection($0.frame).area < frame.intersection($1.frame).area })
            .flatMap({ frame.overlaps($0.frame) ? $0 : nil })
            ?? old.min(by: { $0.frame.distance(to: frame.center) < $1.frame.distance(to: frame.center) })
        else { continue }
        let destination = displays.first { $0.id == home.id } ?? main
        var moved = frame.offsetBy(dx: destination.frame.minX - home.frame.minX, dy: destination.frame.minY - home.frame.minY)
        // It does not leave a window where nobody could get hold of it, on a display that shrank, say.
        if destination.id != home.id || !Self.isReachable(moved, on: displays) { moved = moved.fitted(into: destination.visibleFrame) }
        if moved != frame { moves.append((id, moved)) }
        // On a display that is as large as it was, only elsewhere, the window is where it was on it, and there it stays.
        if destination.id == home.id, destination.frame.size == home.frame.size,
          destination.visibleFrame.offsetBy(dx: -destination.frame.minX, dy: -destination.frame.minY)
            == home.visibleFrame.offsetBy(dx: -home.frame.minX, dy: -home.frame.minY),
          home.frame.contains(frame), !controller.parked.contains(id), id != system.dragging, id != system.resizing
        {
          resting[id] = moved
        }
      }
    }
    switch follow {
    case .never:
      // The same numbers mean another place now: nothing is "where Arbor put it" any more.
      for id in system.windows.keys { system.windows[id]!.groundHasShifted = true }
      system.setDisplays(displays)
    case .recorded:
      // macOS takes the pointer off a display that goes at once, and Arbor's timers run before this step is over.
      if system.dragging == nil, let nearest = displays.min(by: { $0.frame.distance(to: system.cursor) < $1.frame.distance(to: system.cursor) })?.frame {
        system.cursor = CGPoint(x: min(max(system.cursor.x, nearest.minX), nearest.maxX - 1), y: min(max(system.cursor.y, nearest.minY), nearest.maxY - 1))
      }
      if old.first(where: \.isMain)?.id == displays.first(where: \.isMain)?.id {
        system.changeDisplaysAsAMacDoes(displays, moving: moves)
      } else {
        // Another main display has never been recorded. Of the shift of every coordinate that goes with it no app says a word here, and the
        // wait is the layer's rule.
        for move in moves { system.moveSilently(move.window, to: move.frame) }
        system.changeDisplaysAsAMacDoes(displays)
      }
      // What is not worth a word to the layer (another order of the list, say), and what nobody listened to, the lab says all the same, as in
      // its other orders: its mirror holds Arbor to the very list.
      if system.displaysLastTold != displays { system.setDisplays(displays) }
    case .first:
      for move in moves {
        // As in the other orders what Arbor last asked of it goes along with it: a window in the middle of its slot is there afterwards too.
        system.moveSilently(move.window, to: move.frame)
        system.report(move.window, userInitiated: true)
      }
      system.setDisplays(displays)
    case .between:
      system.displayList = displays
      for move in moves {
        system.moveSilently(move.window, to: move.frame)
        system.report(move.window, userInitiated: true)
      }
      system.setDisplays(displays)
    case .silent:
      for move in moves { system.moveSilently(move.window, to: move.frame) }
      system.setDisplays(displays)
    case .late:
      for move in moves { system.moveSilently(move.window, to: move.frame) }
      let mark = system.frameLog.count
      system.setDisplays(displays)
      // A late notification carries the frame the window has by then; if Arbor has placed the
      // window meanwhile, that is Arbor's own frame echoing back.
      let placed = Set(system.frameLog[mark...].map(\.window))
      for move in moves { system.report(move.window, userInitiated: !placed.contains(move.window)) }
    }
    // While Arbor is away nothing it once asked for says where a window is on the new displays.
    if !isRunning { for id in system.windows.keys { system.windows[id]!.groundHasShifted = true } }
    restingPlaces = [:]
    (displaysBeforeTheChange, theChangeChangedNothing) = (Set(old.map(\.id)), old == displays)
    for (id, frame) in resting { if let fake = system.windows[id] { restingPlaces[id] = (frame, fake.movesNotArbors) } }
    // The pointer cannot stay where there is no display any more, and the window it holds goes with it.
    if system.dragging != nil, !displays.isEmpty { perform(.carry(system.cursor)) } else { system.cursor = onADisplay(system.cursor) }
  }

  // MARK: Arbor's process

  private func settings() -> Settings {
    // As SettingsFile.load does: a file that cannot be read gives the defaults.
    guard let data = try? JSONSerialization.data(withJSONObject: settingsFile),
      var settings = try? JSONDecoder().decode(Settings.self, from: data)
    else { return Settings() }
    // A test of tiles has them whatever the walk writes into the file (`Harness.makesTiles`).
    if Harness.makesTiles { settings.windowsThatDoNotFit = "tile" }
    return settings
  }

  private func launch() {
    // As FileStateStore.load does: a file that cannot be read means a fresh start.
    let saved = stateFile.flatMap { try? JSONDecoder().decode(PersistedState.self, from: $0) }
    if !stateFileIsDamaged {
      if let stateWritten, let saved {
        if let problem = Self.readBackViolation(written: stateWritten, read: saved) { found.append(problem) }
      } else if (saved == nil) != (stateWritten == nil) {
        found.append(.init("codable", "state.json cannot be read back"))
      }
    }
    harness = Harness(settings: settings(), saved: saved, system: system)
    let (controller, scheduler, before) = (harness.controller, harness.scheduler, elapsed)
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    controller.now = { start.addingTimeInterval(before + scheduler.now) }
    controller.loadSettings = { [unowned self] in self.settings() }
    controller.saveSettings = { [unowned self] _, settings in
      // What reading the file SettingsFile.update leaves would give. (That file holds only what differs from the defaults; this one all of it.)
      guard let data = try? JSONEncoder().encode(settings),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return }
      self.settingsFile = object
    }
    // Also when a timer ends a pause in the middle of a step.
    controller.observe { [unowned self] change in if case .lifecycle = change { self.listen() } }
    controller.observe { [unowned self] change in
      if change.mayChangeDesktopGuardZones { self.guardZonesCopy = self.controller.desktopGuardZones() }
    }
    let expected = stateFileIsDamaged ? [:] : saved.map { expectedShapes(from: $0) } ?? [:]
    harness.start()
    guardZonesCopy = controller.desktopGuardZones()
    found += shapeViolations(expected: expected)
    renumbered = [:]
  }

  /// Performs a command as ArborApp does: `quit` replies, then the app terminates, which shuts the
  /// controller down. Quitting and pausing both promise every window back in view.
  private func run(_ command: Command) {
    let wasRunning = isRunning
    // The windows Arbor has put somewhere: parked, or docked and taking up space.
    let placed = controller.parked.union(
      controller.workspaces.values.flatMap(\.tree.allWindows).filter { controller.windows[$0]?.isPresent == true })
    // Not while a layout is still to come, which would be taken for the work of undo and redo.
    // Nor during a peek: undo ends it, and leaves the view on everything by design (`back` returns).
    if command == .undo, isRunning, !controller.aPeekIsUnderWay,
      !harness.scheduler.pendingKeys.contains(where: { $0.hasPrefix("space-") || $0.hasPrefix("enforce-") })
    {
      beforeUndo = (controller.workspaces, controller.parked, controller.layouts.mapValues(\.windowFrames))
    }
    let reply = controller.perform(command)
    lastCommandSucceeded = reply.ok
    if !reply.ok { refusals.append(reply.message) }
    if command == .quit { controller.shutdown() }
    if wasRunning, !isRunning {
      // What a test has Arbor do wrong on its way out is there for the rule about the way out to see.
      beforeTheNextCheck?(self)
      beforeTheNextCheck = nil
      found += shutdownViolations(placed: placed)
    }
    if command == .quit, wasRunning || isPaused { endProcess() }
  }

  /// The process is gone: nobody listens to the window system, and the mouse and whatever macOS had
  /// still to report belong to the past.
  private func endProcess() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    stateWritten = harness.store.saved
    stateFile = stateWritten.flatMap { try? encoder.encode($0) }
    stateFileIsDamaged = false
    elapsed += harness.scheduler.now
    system.events = nil
    system.stop()
    system.forgetSession()
    if isRunning || isPaused {
      // This controller must never act again. A fresh one stands in until `launch`.
      harness = Harness(settings: settings(), system: system)
      system.events = nil
    }
  }

  // MARK: Damage to state.json

  /// Cuts the file short, or changes one value somewhere in it: what a slip in a text editor, a full disk or
  /// another version of Arbor might leave. Arbor has to start from whatever it finds without
  /// crashing and with every invariant intact; how much of the arrangement survives is up to it.
  private func damageStateFile(_ how: UInt64) {
    guard let data = stateFile, let object = try? JSONSerialization.jsonObject(with: data) else { return }
    stateFileIsDamaged = true
    var random = ChaosRandom(seed: how)
    if random.chance(8) {
      stateFile = data.prefix(random.int(0...data.count))
      return
    }
    var target = random.int(0...(Self.countValues(in: object) - 1))
    let damaged = Self.damaged(object, at: &target, &random)
    stateFile = (try? JSONSerialization.data(withJSONObject: damaged, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
  }

  private static func countValues(in value: Any) -> Int {
    if let object = value as? [String: Any] { return object.values.reduce(1) { $0 + countValues(in: $1) } }
    if let array = value as? [Any] { return array.reduce(1) { $0 + countValues(in: $1) } }
    return 1
  }

  /// `value` with the `target`-th value inside it (counting depth first, keys in order) replaced.
  private static func damaged(_ value: Any, at target: inout Int, _ random: inout ChaosRandom) -> Any {
    target -= 1
    if target == -1 { return replacement(for: value, &random) }
    if let object = value as? [String: Any] {
      var copy = object
      for key in object.keys.sorted() { copy[key] = damaged(object[key]!, at: &target, &random) }
      return copy
    }
    if let array = value as? [Any] { return array.map { damaged($0, at: &target, &random) } }
    return value
  }

  private static func replacement(for value: Any, _ random: inout ChaosRandom) -> Any {
    let anything: [Any] = [NSNull(), 0, -1, 1, 2, 3, 7, 101, 102, 0.5, 1e300, -1e300, Int.max, Int.min, "", "x", "vertical", [Any](), [String: Any]()]
    if var object = value as? [String: Any], !object.isEmpty, random.chance(70) {
      let keys = object.keys.sorted()
      let key = random.pick(keys)!
      // A key goes missing, or two entries end up the same.
      if random.chance(50) { object[key] = nil } else { object[key] = object[random.pick(keys)!] }
      return object
    }
    if var array = value as? [Any], !array.isEmpty, random.chance(70) {
      let index = random.int(0...(array.count - 1))
      switch random.int(0...3) {
      case 0: array.remove(at: index)
      case 1: array.append(array[index])
      case 2: array.reverse()
      default: array = []
      }
      return array
    }
    return random.pick(anything)!
  }

  // MARK: The ways back

  /// What a person does when a window is gone: float everything, quit Arbor, or (after whatever ended it) start it again.
  public enum WayBack: String, CaseIterable, Sendable {
    case home
    case showAll = "show-all"
    case pause
    case floatAll = "float-all"
    case startAgain = "start-again"
    case quit

    var actions: [ChaosAction] {
      switch self {
      case .home: [.release, .command("resume"), .launch, .command("release"), .command("home"), .settle]
      case .showAll: [.release, .command("resume"), .launch, .command("release"), .command("show-all"), .settle]
      case .pause: [.release, .command("resume"), .launch, .settle, .command("pause")]
      case .floatAll: [.release, .command("resume"), .launch, .command("float-all"), .settle]
      case .quit: [.release, .launch, .command("quit")]
      case .startAgain: [.release, .crash, .launch, .settle]
      }
    }

    /// Quitting, Float All and pause give every window the size it had of its own (F48).
    var givesSizesBack: Bool { [.pause, .floatAll, .quit].contains(self) }
    /// ⌃⌥0 and ⌃⌥Space are about the display they are pressed on, and a start brings back the view there was.
    var isAboutOneDisplay: Bool { [.home, .showAll, .startAgain].contains(self) }
  }

  /// The displays whose view is on everything.
  var displaysAtHome: Set<DisplayID> { Set(controller.workspaces.filter { $0.value.camera == $0.value.tree.root }.keys) }

  /// Windows nobody could get hold of: present or not, none of their title bar is within reach on any display. Windows that Arbor does
  /// not arrange, whose apps do not do as they are asked, and that their own app or the user put where they are, are not Arbor's to fetch.
  public func windowsOutOfReach() -> [WindowID] {
    guard !system.displayList.isEmpty else { return [] }
    let (filter, rules) = (controller.filter, controller.settings.rules)
    return system.windows.keys.sorted().filter { id in
      let fake = system.windows[id]!
      // What a running Arbor counts as out of view it can show again: a tile to click, a view to go to. What is minimized, hidden or
      // on another Space it places when it comes back. Once Arbor has quit, nobody does either.
      return !isReachable(fake.snapshot.frame) && cooperates(fake) && !fake.snapshot.isFullScreen
        // Arbor itself put it exactly there. (`lost` also asks about windows that a change of displays left behind.)
        && fake.lastRequest?.took == fake.snapshot.frame && !fake.groundHasShifted
        && filter.manages(fake.snapshot) && !(isRunning && (controller.parked.contains(id) || !fake.snapshot.isPresent))
        && AppRule.firstMatch(in: rules, bundleID: fake.snapshot.bundleID, title: fake.snapshot.title)?.action != .ignore
    }
  }

  /// Runs `script` to its end, whatever rules it breaks, then takes a way back. Returns the windows still out of reach.
  public static func windowsOutOfReach(after script: [ChaosAction], then way: WayBack?) -> [WindowID] {
    Log.silenced {
      let runner = ChaosRunner()
      for action in script + (way.map { [.wayBack($0)] } ?? []) { _ = runner.step(action) }
      return runner.windowsOutOfReach()
    }
  }

  // MARK: Shrinking

  /// How many things in `script` are half a gesture: something done with a window still in the hand, a hand that moves or lets go of nothing, a key that
  /// goes down and never comes up, or comes up without having gone down. A gesture that the script's end cuts off is whole: the rule broke in the middle of it.
  public static func halfGestures(in script: [ChaosAction]) -> Int {
    var (count, inHand, down) = (0, false, [String]())
    for action in script {
      switch action {
      case .grab, .edge(_, _, hold: true):
        if inHand { count += 1 }
        inHand = true
      case .carry: if !inHand { count += 1 }
      case .release, .loseRelease:
        if !inHand { count += 1 }
        inHand = false
      case .settle: inHand = false
      case .cursor, .advance, .react, .flush, .commandKey, .save: break
      case .key(let line, .pressed):
        if inHand { count += 1 }
        down.append(line)
      case .key(let line, .released):
        if let index = down.lastIndex(of: line) { down.remove(at: index) } else { count += 1 }
      default: if inHand { count += 1 }
      }
    }
    // The last key may still be down: the rule broke at the press, or in the moments after it.
    let afterTheLastPress = script.lastIndex { if case .key(_, .pressed) = $0 { true } else { false } }.map { script[($0 + 1)...] } ?? []
    let cutOff = afterTheLastPress.allSatisfy { action in
      switch action {
      case .advance, .react, .flush, .settle, .save: true
      default: false
      }
    }
    return count + max(down.count - (cutOff ? 1 : 0), 0)
  }

  /// Deletes actions from a failing script for as long as the same rule still breaks (delta
  /// debugging: halves first, then smaller and smaller pieces, then single actions until none can
  /// go). `test` runs a script and returns the failure, if any; the default replays it in this
  /// process, past the known failures the random run went past, and arbor-sim replays in a child process so that
  /// crashes can be shrunk too.
  public static func shrink(
    _ failure: ChaosFailure, budget: Int = 1500, test: (([ChaosAction]) -> ChaosFailure?)? = nil
  ) -> ChaosFailure {
    let test = test ?? { replay($0, excusing: knownRules.subtracting([failure.rule])) }
    var best = failure
    var runs = 0
    // A drag and a key go whole or not at all, where they were whole in the walk: a click with a window still in the hand is what no person does.
    let halves = halfGestures(in: failure.script)
    func attempt(_ candidate: [ChaosAction]) -> Bool {
      guard runs < budget, halfGestures(in: candidate) <= halves else { return false }
      runs += 1
      guard let result = test(candidate), result.rule == failure.rule else { return false }
      best = ChaosFailure(seed: failure.seed, violations: result.violations, script: result.script)
      return true
    }
    var chunk = max(best.script.count / 2, 1)
    while runs < budget {
      var removedAny = false
      var start = 0
      while start < best.script.count {
        var candidate = best.script
        candidate.removeSubrange(start..<min(start + chunk, candidate.count))
        if attempt(candidate) {
          removedAny = true  // the next piece has moved into this place
        } else {
          start += chunk
        }
      }
      if chunk > 1 {
        chunk = max(chunk / 2, 1)
        continue
      }
      // Piece by piece a gesture cannot go: without its beginning or its end it is half a gesture. So each is tried as a whole.
      var index = 0
      while index < best.script.count {
        let gesture = Self.gesture(beginningAt: index, in: best.script)
        if !gesture.isEmpty, attempt(best.script.enumerated().filter { !gesture.contains($0.offset) }.map(\.element)) {
          removedAny = true
        } else {
          index += 1
        }
      }
      if !removedAny { break }
    }
    return best
  }

  /// The places in `script` of the gesture that begins at `index`: a drag from the hand's taking hold to its letting go, with all between; a key's going down and
  /// its coming up. Empty if none begins there, or it has no end.
  private static func gesture(beginningAt index: Int, in script: [ChaosAction]) -> Set<Int> {
    switch script[index] {
    case .grab, .edge(_, _, hold: true):
      guard
        let end = script[(index + 1)...].firstIndex(where: { action in
          switch action {
          case .release, .loseRelease, .settle: true
          default: false
          }
        })
      else { return [] }
      return Set(index...end)
    case .key(let line, .pressed):
      guard let end = script[(index + 1)...].firstIndex(of: .key(line, .released)) else { return [] }
      return [index, end]
    default: return []
    }
  }
}
