import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The product's rules about what a person sees, as nets over random walks. Each asks what the window system saw, not what the
/// controller believes, and each has a control in `ChaosSevenRulesTests` that fails when the net is cut.
///
/// | Rule | Net |
/// |---|---|
/// | Nothing moves until the person docks something | `moved-before-any-dock`, `fetched-before-any-dock`, `moved-at-launch`, `moved-at-launch-after-a-crash`, `moved-at-resume`, `start-took-out-of-view`, `pause-and-resume-moved`, `there-and-back-moved`, `moved-out-of-its-zoom`, `moved-unasked` |
/// | No jolts: a window moves once, to where it ends up | `moved-twice`, `moved-again`; both with `-sizing` where its app refused a size, `-sizing-again` where it had refused before, `-floating` for a floating window; `moved-twice-floating-windows-first` (with `soleFloatTakesDesktop`, where macOS reported the window before the displays); `flashed-into-view`, `flashed-out-of-view`, `moved-over-and-over` |
/// | The window you switch to comes to the front and into view | `switched-to-out-of-view`, `app-switch-out-of-view`, `switched-to-partly-out`, `switched-to-behind` |
/// | After a person's own act macOS decides who has the keyboard | `keyboard-handed-on-unasked` |
/// | Quitting, Float All and pause give windows their own earlier sizes back | `size-not-given-back` |
/// | After any way home no window is less than wholly in view | `home-not-whole`, `home-behind-the-dock`, `home-leaves-out` |
extension ChaosRunner {
  /// What the nets remember from step to step.
  struct SevenRules {
    var moveLogMark = 0
    var layoutsBefore: [DisplayID: Layout] = [:]
    /// The windows that were where a double-click had put them.
    var letBeBefore: Set<WindowID> = []
    /// The last size Arbor gave each of them, which is its slot's as its app took it.
    var slotSizesOfThoseLetBe: [WindowID: CGSize] = [:]
    /// The size macOS gave a docked window at its person's asking, until it is known what became of it (Controller+AskedOfMacOS.swift).
    var givenByMacOSAtAsking: [WindowID: CGSize] = [:]
    var focusedBefore: WindowID?
    var pausedBefore = false
    var fullScreenBefore: Set<WindowID> = []
    /// Arbor's moves of each window that a person could see, since somebody last did something. Time passing is nobody.
    var seenSinceSomebodyActed: [WindowID: [FakeWindowSystem.Move]] = [:] {
      didSet { if seenSinceSomebodyActed.isEmpty { foundUnableToGrow = [] } }
    }
    /// The windows that turned out unable to grow among those moves, for the first time.
    var foundUnableToGrow: Set<WindowID> = []
    /// Whether an app has refused a size since then, also where that left its window as it was, or out of view.
    var aSizeWasRefused = false
    /// How many of those moves came in steps in which only time passed.
    var seenWhileOnlyTimePassed: [WindowID: Int] = [:]
    /// The windows the last thing somebody did was about; nil is all of them. Timers finish that work.
    var concerned: Set<WindowID>? = []
    /// The size each window last had of its own: as its app opened it, or as somebody other than Arbor made it while it was not docked.
    var ownSizes: [WindowID: CGSize] = [:]
    var ownSizesBeforeTheLastHand: [WindowID: CGSize] = [:]
    /// The size it had of its own before its user asked Arbor for another with a key: which of the two Arbor takes for its own is not laid down.
    var earlierOwnSizes: [WindowID: CGSize] = [:]
    /// The last thing somebody did was to plug, unplug or rearrange displays, which has rules of its own (`left-its-place`, `moved-for-nothing`).
    var displaysChangedLast = false
    /// How much of each window showed before the displays changed; before the first change, where several follow one another.
    var showedBeforeTheDisplaysChanged: [WindowID: CGFloat] = [:]
    var askedSinceTheDisplaysChanged = true
    /// Somebody has changed how the docked windows share a display and all has not come to rest yet; whether it was a gap dragged by hand; and, once it
    /// has, each display's view and where the docked windows in it then were.
    var arrangementIsDue = false
    var aGapWasDragged = false
    var framesBeforeTheGap: [WindowID: CGRect] = [:]
    var arrangements: [DisplayID: (view: NodeID, frames: [WindowID: CGRect])] = [:]
    /// The desks there have been since somebody last did anything but plug, unplug and wait: the displays, and where every window was at rest.
    var desks: [(displays: [DisplaySnapshot], frames: [WindowID: CGRect])] = []
    /// What floated when Arbor was last seen running.
    var floatedWhenLastSeen: Set<WindowID> = []
    var displaysWhenLastSeen: Set<DisplayID> = []
    /// Windows that macOS carried along at a change of displays and that Arbor has not moved since: what Arbor last asked of them went along, but where they
    /// are is macOS's doing.
    var carriedByMacOS: Set<WindowID> = []
    /// Arbor was quit, not killed, and has not been started since: it had its chance to bring everything back.
    var hasQuit = false
    /// The launch of this step came after a quit. After a run that did not quit Arbor cannot tell what its person has done since.
    var launchedAfterAQuit = false
    /// In the current step nobody does anything; and the last thing somebody did was a command that asks for everything.
    var timeOnly = false
    var askedForEverything = false
    var tookAWayHome = false
    /// Where every window was before the last thing somebody did, kept through a pause in which nobody does anything.
    var beforeThePause: [WindowID: CGRect]?
    /// Where everything was, at rest, before the last thing somebody did, and what that was.
    var there: (frames: [WindowID: CGRect], action: ChaosAction, views: [DisplayID: NodeID])?
    /// The last thing somebody did took the one before it back: where everything has to be again once it has come to rest.
    var backDue: (frames: [WindowID: CGRect], there: String, rule: String, views: [DisplayID: NodeID]?, about: Set<WindowID>)?
    /// What the pause itself moved, to give it its own frame back: the resume may take it back to where it was.
    var movedByThePause: Set<WindowID> = []
    var displaysAtThePause: [DisplaySnapshot] = []
    /// The window its user switched to last, until somebody does something else; and whether macOS said which window it was, or only
    /// that another app came forward.
    var switchedTo: WindowID?
    var onlyTheAppWasReported = false
    var arborMovedItSince = false
    /// The window that opened last, until somebody does something else.
    var arrived: WindowID?
    /// The windows there were when Arbor was last running, and whether this is a login after a restart of the Mac: Arbor has started among windows of which
    /// none was there then, and since then windows have opened and time has passed, and nothing else.
    var windowsWhenArborLeft: Set<WindowID> = []
    var isALogin = false
    /// How many times Arbor had asked for the keyboard to go somewhere when the step began, and whether the last thing somebody did was to ask Arbor
    /// for something.
    var focusLogMark = 0
    var somebodyAskedArbor = false
    /// The window in a plain drag, from the moment it is taken until somebody does something else, and whether it floated when it was taken.
    /// (As floating windows do: one that fills the view has Arbor's size, and comes out of that like a docked window out of its slot.)
    var dragged: WindowID?
    var draggedWasFloating = false
    var displayAtTheGrab: DisplayID?
    var frameAtTheGrab: CGRect?
    var undoStepsAtTheGrab = 0
    /// Windows whose app has refused to go below a size, or above one, in an earlier step: Arbor has had its chance to learn.
    var refusedLess: Set<WindowID> = []
    var refusedMore: Set<WindowID> = []
    /// The displays each window is at home on: where its app opened it, where somebody other than Arbor last put it, or where a command
    /// about it took it; more than one where it lies across a border. A change of the displays says nothing of that: macOS carries a
    /// window to whatever display is left.
    var homeDisplays: [WindowID: Set<DisplayID>] = [:]
    /// Every display somebody ever put it on.
    var everAtHomeOn: [WindowID: Set<DisplayID>] = [:]
    /// No display showed a window when last asked at rest: said once.
    var deskWasEmpty = false
    /// The displays have changed since a window was last seen in view at rest.
    var displaysChangedSinceSomethingShowed = false
    /// No window that Arbor knows had the keyboard when the step began, and this is how often Arbor had focused one.
    var nobodyBefore = false
    var focusCallsBefore = 0
  }

  /// The detector of docs/VIABLE.md, section 5, that a rule of the walks stands for: one vocabulary on Linux and on a Mac.
  public nonisolated static func detector(for rule: String) -> String? {
    let table: [(prefix: String, detector: String)] = [
      ("moved-twice", "jolt"), ("moved-again", "jolt"), ("sized-there-and-back", "jolt"), ("set-right-", "jolt"), ("strayed-between", "jolt"), ("eye-", "jolt"), ("flashed-", "flash"), ("flipped", "jolt"), ("moved-over-and-over", "stuck"), ("moved-", "moved-unasked"), ("fetched-", "moved-unasked"), ("there-and-back", "moved-unasked"), ("dragged-gap", "moved-unasked"), ("same-windows", "moved-unasked"), ("displays-out-and-back", "moved-unasked"), ("taken-", "moved-unasked"), ("floating-taken", "lost"), ("parked-before", "lost"), ("arrival-moved", "moved-unasked"), ("arrival-took", "lost"), ("dock-took", "lost"), ("keyboard-taken", "focus"), ("plain-drag", "moved-unasked"), ("nothing-in-view", "lost"), ("docked-at-a-start", "moved-unasked"),
      ("pause-and-resume", "moved-unasked"), ("left-its-place", "moved-unasked"), ("start-took", "lost"), ("quit-left", "lost"), ("displays-left", "lost"), ("displays-fetched", "moved-unasked"), ("switched-to-behind", "behind"),
      ("switched-to", "focus"), ("app-switch", "focus"), ("keyboard-", "focus"), ("size-", "size-lost"), ("home-", "lost"), ("lost", "lost"), ("out-of-reach", "lost"),
      ("placed-", "lost"), ("vanished", "lost"), ("parked-on-the-desktop", "lost"), ("restless", "stuck"), ("given-up", "stuck"),
    ]
    return table.first { rule.hasPrefix($0.prefix) }?.detector
  }

  /// How often each net asked its question, over every runner of the process: a net that never asks catches nothing.
  public nonisolated(unsafe) static var questionsAsked: [String: Int] = [:]

  private func asked(_ net: String) { Self.questionsAsked[net, default: 0] += 1 }

  // MARK: Before and after each step

  /// Whether nobody does anything in `action`: time passes, and macOS reports what Arbor itself did.
  func isOnlyTimePassing(_ action: ChaosAction) -> Bool {
    switch action {
    case .flush, .advance, .react, .save: true
    // It lets go of the mouse first.
    case .settle: system.dragging == nil && system.resizing == nil && !system.mouseDown
    default: false
    }
  }

  func noteBeforeTheSevenRules(_ action: ChaosAction) {
    seven.moveLogMark = system.moveLog.count
    seven.focusLogMark = system.focusLog.count
    seven.layoutsBefore = controller.layouts
    seven.letBeBefore = controller.windowsLeftWhereADoubleClickPutThem
    seven.slotSizesOfThoseLetBe = seven.letBeBefore.reduce(into: [:]) { $0[$1] = system.windows[$1]?.lastRequest?.took.size }
    seven.focusedBefore = system.focused
    seven.focusCallsBefore = system.focusLog.count
    seven.nobodyBefore = system.focused == nil
    seven.pausedBefore = isPaused
    seven.fullScreenBefore = Set(system.windows.values.lazy.filter(\.snapshot.isFullScreen).map(\.snapshot.id))
    // Asked now: `settle` lets go of the mouse, and afterwards nothing shows that somebody held it.
    seven.timeOnly = isOnlyTimePassing(action)
    guard !seven.timeOnly else { return }
    // A key that comes up again belongs to its going down. (Show Everything is decided when it comes up: a tap, or the end of a look.)
    if case .key(let line, .released) = action, (try? Command.parse(line)) != .showAll { return }
    (seven.seenSinceSomebodyActed, seven.aSizeWasRefused, seven.seenWhileOnlyTimePassed) = ([:], false, [:])
    seven.concerned = windowsConcerned(by: action)
    seven.askedForEverything = asksForEverything(action)
    seven.tookAWayHome = action.parsedCommand.map { $0.bringsWindowsBack && !isPaused || $0 == .quit || $0 == .relayout } ?? false
    seven.switchedTo = nil
    switch action {
    case .open(let new): seven.arrived = new.id
    case .title(let window, _): seven.arrived = window
    default: seven.arrived = nil
    }
    if isRunning { seven.windowsWhenArborLeft = Set(system.windows.keys) }
    switch action {
    case .launch: seven.isALogin = !isRunning && !isPaused && !seven.windowsWhenArborLeft.isEmpty && seven.windowsWhenArborLeft.isDisjoint(with: system.windows.keys)
    // A window that says who it is belongs to its arrival.
    case .open, .title: break
    default: seven.isALogin = false
    }
    switch action {
    case .tile, .palette, .pinch, .activate, .launch: seven.somebodyAskedArbor = true
    default: seven.somebodyAskedArbor = action.isACommand
    }
    switch action {
    // `grab 101` is by a hand that means to dock, which holds what Arbor is set to ask for. And where every drag docks, none is plain.
    // A window kept in view or summoned lives by rules of its own.
    case .grabPlainly(let window) where !aDragIsOfferedPlaces && !controller.workspaces.values.contains { $0.role(of: window) != nil }:
      (seven.dragged, seven.draggedWasFloating) = (isRunning && system.windows[window] != nil ? window : nil, controller.workspaces.values.contains { $0.isFloating(window) && !$0.isFilled(window) })
      seven.frameAtTheGrab = system.windows[window]?.snapshot.frame
      seven.displayAtTheGrab = controller.workspaceID(containing: window)
      seven.undoStepsAtTheGrab = undoSteps
    case .carry, .release, .cursor, .settle: break
    default: seven.dragged = nil
    }
    if case .displays = action {
      if !seven.displaysChangedLast { seven.showedBeforeTheDisplaysChanged = system.windows.mapValues { Self.area(of: $0.snapshot.frame, showingOn: system.displayList) } }
      (seven.displaysChangedLast, seven.askedSinceTheDisplaysChanged) = (true, false)
    } else {
      seven.displaysChangedLast = false
    }
    if case .key(_, .released) = action { return }
    if case .displays = action {
      // At rest, and with Arbor looking: where everything was on this desk.
      if isRunning, !isWaitingForALayout(), system.dragging == nil, system.resizing == nil, !system.displayList.isEmpty,
        !seven.desks.contains(where: { $0.displays == system.displayList })
      {
        seven.desks.append((system.displayList, framesBefore))
      }
    } else {
      seven.desks = []
    }
    if !leavesTheArrangementAlone(action) {
      (seven.arrangementIsDue, seven.arrangements) = (true, [:])
      if case .seam = action { (seven.aGapWasDragged, seven.framesBeforeTheGap) = (true, framesBefore) } else { seven.aGapWasDragged = false }
    }
    // macOS gives a window the keyboard whenever it comes back: that report belongs to its coming back.
    if let due = seven.backDue, case .focus(let window) = action, due.about.contains(window) { return }
    // On a Mac it comes a millisecond or two before the word that the window is back.
    if let there = seven.there, case .focus(let window) = action {
      switch there.action {
      case .hide(let pid, true) where system.windows[window]?.snapshot.pid == pid: return
      case .minimize(window, true): return
      default: break
      }
    }
    seven.backDue = seven.there.flatMap { takesBack(action, $0.action) ? ($0.frames, $0.action.text, "there-and-back-moved", action.parsedCommand == .back ? $0.views : nil, seven.concerned ?? []) : nil }
    let atRest = isRunning && !isWaitingForALayout() && system.dragging == nil && system.resizing == nil && !system.mouseDown
    seven.there = atRest ? (framesBefore, action, controller.workspaces.mapValues(\.camera)) : nil
    if isRunning, !isWaitingForALayout(), system.dragging == nil, system.resizing == nil {
      seven.beforeThePause = framesBefore
    } else if !isPaused || action.parsedCommand?.endsPause != true {
      // Something was done during the pause, or there is none.
      seven.beforeThePause = nil
    }
  }

  /// The windows `action` is about. Nil where it is about all of them, or where that cannot be told from its words.
  private func windowsConcerned(by action: ChaosAction) -> Set<WindowID>? {
    func windows(of pid: Int32) -> Set<WindowID> { Set(system.windows.values.lazy.filter { $0.snapshot.pid == pid }.map(\.snapshot.id)) }
    let inHand = Set([system.dragging, system.resizing].compactMap { $0 })
    switch action {
    case .open(let new): return [new.id]
    case .close, .quitApp, .focusNothing, .press, .commandKey, .macTiling, .save, .flush, .advance, .react: return []
    case .minimize(let window, _), .space(let window, _), .fullScreen(let window, _), .title(let window, _), .limits(let window, _, _),
      .behave(let window, _), .move(let window, _), .focus(let window), .switchApp(let window), .backgroundFocus(let window),
      .listed(let window, _), .doubleClick(let window), .askMacOS(let window, _):
      return [window]
    case .grab(let window), .grabPlainly(let window), .edge(let window, _, _): return inHand.union([window])
    // The pointer does not leave a window it is holding behind.
    case .carry, .cursor, .release, .loseRelease, .settle: return inHand
    case .hide(let pid, _), .hang(let pid, _), .appForward(let pid): return windows(of: pid)
    case .activate(let bundleID): return Set(system.windows.values.lazy.filter { $0.snapshot.bundleID == bundleID }.map(\.snapshot.id))
    case .openTab(let a, let b), .selectTab(let a, let b), .closeTab(let a, let b), .renumber(let a, let b): return [a, b]
    case .command, .via, .key, .url: return windowsConcerned(byCommand: action.parsedCommand)
    case .tile, .palette, .seam, .pinch, .displays, .settings, .wayBack, .crash, .launch, .sleep, .corrupt: return nil
    }
  }

  /// The windows a command names, and the one that has the keyboard, which it means when it names none.
  private func windowsConcerned(byCommand command: Command?) -> Set<WindowID>? {
    guard let command else { return [] }
    if command.isQuery { return [] }
    switch command {
    case .dock, .dockBeside, .float, .toggleFloat, .resize, .pin, .unpin, .togglePin, .zoom, .reveal, .swap, .swapWindows, .grow, .shrink,
      .moveToDisplay, .frameRect, .sideBySide:
      let named = command.text.split(separator: " ").compactMap { UInt32($0) }.map { WindowID($0) }
      return Set(named + [system.focused].compactMap { $0 })
    case .saveView, .name, .unname, .askName, .showShortcuts, .minimap, .checkForUpdates, .welcome, .checkSetup, .hold, .holdStill, .trace,
      .launchAtLogin, .passThrough, .focusDisplay:
      return []
    default: return nil
    }
  }

  /// After the action, before the rules are asked: whose size is whose.
  func noteAfterTheSevenRules(_ action: ChaosAction, movesBefore: [WindowID: Int]) {
    switch action {
    case .renumber(let old, let new):
      if system.windows[new] != nil, seven.ownSizes[new] == nil {
        (seven.ownSizes[new], seven.earlierOwnSizes[new]) = (seven.ownSizes[old], seven.earlierOwnSizes[old])
      }
    // What Arbor learnt about sizes it learnt in a process that is gone.
    case .launch, .crash:
      seven.launchedAfterAQuit = action == .launch && seven.hasQuit
      (seven.refusedLess, seven.refusedMore) = ([], [])
      // A `crash` while Arbor is not running ends nothing: it has still quit.
      if action == .launch || wasRunningBefore || seven.pausedBefore { seven.hasQuit = false }
    // A native tab has the size of its group.
    case .openTab(let new, let front): if framesBefore[new] == nil, let size = seven.ownSizes[front] { seven.ownSizes[new] = size }
    case .selectTab(let new, let front): if let size = seven.ownSizes[front] { seven.ownSizes[new] = size }
    case .closeTab(let front, let next): if let size = seven.ownSizes[front] { seven.ownSizes[next] = size }
    case .focus(let window):
      if system.windows[window] != nil { (seven.switchedTo, seven.onlyTheAppWasReported, seven.arborMovedItSince) = (window, false, false) }
    case .switchApp(let window):
      // Within one app macOS says which window has the keyboard.
      if let pid = system.windows[window]?.snapshot.pid, seven.focusedBefore.flatMap({ system.windows[$0]?.snapshot.pid }) != pid {
        (seven.switchedTo, seven.onlyTheAppWasReported, seven.arborMovedItSince) = (window, true, false)
      }
    case .limits(let window, _, _), .behave(let window, _):
      seven.refusedLess.remove(window)
      seven.refusedMore.remove(window)
    // It is told to forget where each window stopped growing, and offers everybody the whole slot again.
    case _ where action.parsedCommand == .relayout: seven.refusedMore = []
    default: break
    }
    if case .displays = action {
      seven.carriedByMacOS.formUnion(system.windows.filter { $0.value.movesNotArbors != movesBefore[$0.key] }.keys)
    }
    seven.carriedByMacOS.subtract(movesSeenInThisStep.map(\.window))
    seven.carriedByMacOS = seven.carriedByMacOS.filter { system.windows[$0] != nil }
    seven.ownSizes = seven.ownSizes.filter { system.windows[$0.key] != nil || system.backgroundTabs[$0.key] != nil }
    seven.earlierOwnSizes = seven.earlierOwnSizes.filter { system.windows[$0.key] != nil }
    noteWhichDisplayEachWindowIsAtHomeOn(after: action, movesBefore: movesBefore)
    for (id, fake) in system.windows {
      guard let known = seven.ownSizes[id] else {
        seven.ownSizes[id] = (fake.home ?? fake.snapshot.frame).size
        continue
      }
      // What macOS makes of a window to fit it onto the display that is left is nobody's wish.
      if case .displays = action {
        // But with Arbor away a window that had its own size has no other than the one Arbor is going to find.
        if !isRunning, !isPaused, framesBefore[id]?.size == known { (seven.ownSizes[id], seven.earlierOwnSizes[id]) = (fake.snapshot.frame.size, nil) }
        // And what macOS does to a FLOATING window at a change of displays is macOS's, its size too (decided 2026-10-15): Arbor need not set it back, and may. Only
        // where macOS gave it that size: an Arbor that shrinks a floating window itself is not let off.
        if isRunning, wasRunningBefore, fake.movesNotArbors != movesBefore[id], let home = fake.home, home.size != known, framesBefore[id]?.size == known,
          !movesSeenInThisStep.contains(where: { $0.window == id }), workspacesBefore.values.contains(where: { $0.isFloating(id) && !$0.isStashed(id) }),
          !parkedBefore.contains(id), controller.workspaces.values.contains(where: { $0.isFloating(id) })
        {
          (seven.ownSizes[id], seven.earlierOwnSizes[id]) = (home.size, known)
        }
        continue
      }
      // Full screen is no size of its own, and what macOS gives back afterwards is what the window had before.
      guard fake.movesNotArbors != movesBefore[id], let home = fake.home, let before = framesBefore[id], home.size != before.size,
        !fake.snapshot.isFullScreen, !seven.fullScreenBefore.contains(id)
      else { continue }
      // The edges of a docked window move the gaps between slots. But one that is dragged out and let go where macOS itself tiles has the size
      // its person asked macOS for.
      let tiledByMacOS = inHandBefore == id && system.dragging != id && !fake.placeIsArborsDoing && !controller.workspaces.values.contains { $0.isDocked(id) }
      let wasDocked = wasRunningBefore && workspacesBefore.values.contains { $0.isDocked(id) }
      // Nor those of a window that is let be, which is in no slot (Controller+LetBe.swift).
      if home.size != known, !wasDocked || tiledByMacOS || controller.saidToBeLetBeInATile.contains(id) {
        // Back at what Arbor had made of it (macOS's zoom at a double-click, and again): nobody chose that size. The account is the lab's own, and never
        // goes by what Arbor has written down.
        if let given = fake.lastRequest?.took.size, abs(home.width - given.width) <= 1.5, abs(home.height - given.height) <= 1.5,
          let before = seven.ownSizesBeforeTheLastHand[id], abs(given.width - before.width) > 1.5 || abs(given.height - before.height) > 1.5
        {
          seven.ownSizes[id] = before
          continue
        }
        seven.ownSizesBeforeTheLastHand[id] = known
        seven.ownSizes[id] = home.size
        seven.earlierOwnSizes[id] = nil
      }
    }
    // What macOS gave a docked window at its person's asking is its own once it has left the arrangement with it: one of macOS's tiles. (Let be, it
    // is docked still, and back in its slot it has the own size it had.)
    if case .askMacOS(let id, _) = action, wasRunningBefore, workspacesBefore.values.contains(where: { $0.isDocked(id) }),
      let now = system.windows[id]?.snapshot.frame.size, let before = framesBefore[id]?.size, now != before
    {
      seven.givenByMacOSAtAsking[id] = now
    }
    for (id, size) in seven.givenByMacOSAtAsking {
      guard let fake = system.windows[id], fake.snapshot.frame.size == size, isRunning else {
        seven.givenByMacOSAtAsking[id] = nil
        continue
      }
      if controller.workspaces.values.contains(where: { $0.isFloating(id) }) {
        (seven.ownSizes[id], seven.earlierOwnSizes[id], seven.givenByMacOSAtAsking[id]) = (size, nil, nil)
      }
    }
    // A size its user asked Arbor for is its own as well.
    if let command = action.parsedCommand {
      switch command {
      case .grow, .shrink, .resize, .frameRect:
        for window in Set(movesSeenInThisStep.map(\.window)) where controller.workspaces.values.contains(where: { $0.isFloating(window) }) {
          if seven.concerned?.contains(window) == true, let frame = system.windows[window]?.snapshot.frame {
            if seven.earlierOwnSizes[window] == nil { seven.earlierOwnSizes[window] = seven.ownSizes[window] }
            seven.ownSizes[window] = frame.size
          }
        }
      default: break
      }
    }
  }

  // MARK: What all the nets ask of a window

  /// Decided (the product owner, 2026-10-15; what is found counts as left): a window that has its own size, at the corner a hand gave it, with no less showing than
  /// was left showing, is where its person left it, however far it hangs over an edge. Arbor may put it there, and no switch fetches it from there.
  func isWhereAHandLeftIt(_ window: WindowID, _ frame: CGRect) -> Bool {
    guard let home = system.windows[window]?.home, abs(home.minX - frame.minX) <= 1, abs(home.minY - frame.minY) <= 1, let own = seven.ownSizes[window],
      abs(own.width - frame.width) <= 1.5, abs(own.height - frame.height) <= 1.5
    else { return false }
    let showing = Self.area(of: frame, showingOn: system.displayList)
    return (userPlaces[window] ?? []).contains { $0.showing <= showing + 1 }
  }

  /// Arbor arranges it, its app does as it is asked, and a person can see it.
  private func isFairGame(_ window: WindowID) -> FakeWindowSystem.FakeWindow? {
    guard let fake = system.windows[window], fake.snapshot.isPresent, !fake.snapshot.isFullScreen, cooperates(fake),
      controller.filter.manages(fake.snapshot), window != system.dragging, window != system.resizing, window != inHandBefore,
      AppRule.firstMatch(in: controller.settings.rules, bundleID: fake.snapshot.bundleID, title: fake.snapshot.title)?.action != .ignore
    else { return nil }
    return fake
  }

  /// Arbor's moves in this step that changed what a person sees: not one that left the window as it was, nor one from out of view to out of view.
  private var movesSeenInThisStep: [FakeWindowSystem.Move] {
    guard seven.moveLogMark < system.moveLog.count else { return [] }
    return system.moveLog[seven.moveLogMark...].filter { $0.before != $0.after && (isInView($0.before) || isInView($0.after)) }
  }

  /// Whether something is still to come that may move windows: a timer that lays out, or (`orReports`) what macOS has still to report.
  private func isWaitingForALayout(orReports: Bool = true) -> Bool {
    (orReports && system.hasHeldEchoes)
      || harness.scheduler.pendingKeys.contains { key in
        // Not the focus ring's own timers, which are pending after most acts and lay nothing out.
        if key.hasPrefix("focus-ring") { return false }
        return ["space-", "enforce-", "landed-", "asked-of-macos", "displays-blinked", "focus", "back-from-full-screen", "summon-wait", "pending-slots", "sole-float-after-launch", "meet-",
          "fill-in-hand-", "awaited-back", "awaited-landed"]
          .contains { key.hasPrefix($0) }
      }
  }

  func sevenRulesViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    onceViolations(after: action, &problems)
    unaskedViolations(after: action, &problems)
    zoomViolations(after: action, &problems)
    noteAPauseThatEnded()
    thereAndBackViolations(&problems)
    startViolations(after: action, &problems)
    afterDisplaysViolations(&problems)
    outAndBackViolations(&problems)
    dockedAtAStartViolations(after: action, &problems)
    sameWindowsSameFramesViolations(&problems)
    switchedToViolations(&problems)
    homeDisplayViolations(after: action, &problems)
    emptyDeskViolations(after: action, &problems)
    floatingViolations(&problems)
    arrivalViolations(after: action, &problems)
    parkedViolations(&problems)
    dockViolations(after: action, &problems)
    untouchedByTheChangeViolations(after: action, &problems)
    fetchedAtAChangeViolations(after: action, &problems)
    keyboardViolations(after: action, &problems)
    plainDragViolations(&problems)
    handedOnViolations(after: action, &problems)
  }

  // MARK: No jolts: a window moves once, to where it ends up

  func onceViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if !seven.pausedBefore, isPaused { (seven.movedByThePause, seven.displaysAtThePause) = (Set(movesSeenInThisStep.map(\.window)), system.displayList) }
    // Several things done in one step.
    if case .wayBack = action {
      (seven.seenSinceSomebodyActed, seven.aSizeWasRefused, seven.seenWhileOnlyTimePassed) = ([:], false, [:])
      return
    }
    let timeOnly = seven.timeOnly
    // A pause or a hold whose time was up: what follows is its own story, however long ago the last one was.
    if timeOnly, seven.pausedBefore != isPaused || (isRunning && holdBefore != controller.holdLevel) { (seven.seenSinceSomebodyActed, seven.aSizeWasRefused, seven.seenWhileOnlyTimePassed) = ([:], false, [:]) }
    if seven.moveLogMark < system.moveLog.count,
      system.moveLog[seven.moveLogMark...].contains(where: { abs($0.after.width - $0.requested.width) > 1 || abs($0.after.height - $0.requested.height) > 1 })
    {
      seven.aSizeWasRefused = true
    }
    let seen = movesSeenInThisStep
    guard !seen.isEmpty else {
      // So is anything that comes after seconds in which nothing moved.
      if case .advance(let seconds) = action, seconds >= 2 { (seven.seenSinceSomebodyActed, seven.aSizeWasRefused, seven.seenWhileOnlyTimePassed) = ([:], false, [:]) }
      return
    }
    for move in seen {
      seven.seenSinceSomebodyActed[move.window, default: []].append(move)
      if timeOnly { seven.seenWhileOnlyTimePassed[move.window, default: 0] += 1 }
    }
    let somebodyRefused = seven.aSizeWasRefused
    for window in Set(seen.map(\.window)).sorted() {
      guard isFairGame(window) != nil, presentBefore.contains(window), let moves = seven.seenSinceSomebodyActed[window] else { continue }
      // Its Space is away: a window in full screen has the keyboard on that display, and nobody sees what moves behind it.
      if timeOnly, let last = moves.last?.after, isBehindFullScreen(last) { continue }
      asked("once")
      // A window Arbor does not know is asked for a size where it stands and goes to its place afterwards, so requests are not
      // what is counted. What a person sees is the road (`FakeWindowSystem.detour`).
      // Floating windows are placed by other code, with another owner.
      let floats = controller.workspaces.values.contains { $0.isFloating(window) } ? "-floating" : ""
      // Nobody in view is asked to grow where it stands: a window grows in its slot. That it cannot shows there, and it goes on to the
      // middle of the slot, at the size it took. Once: from then on Arbor knows. That hop is left out of the road.
      var mayLearn = floats.isEmpty && (!seven.refusedMore.contains(window) || seven.foundUnableToGrow.contains(window))
      // Nor can anybody grow into a frame that hangs over the edge of the screen: it is sized where the size fits, and then only moved.
      var mayBeSizedElsewhere = true
      let road = Self.road(of: moves) { move, next in
        if mayBeSizedElsewhere, system.isSizedWhereItFits(move, then: next) {
          mayBeSizedElsewhere = false
          return true
        }
        guard mayLearn, Self.isTheWayToTheMiddle(next, after: move) else { return false }
        mayLearn = false
        return true
      }
      if floats.isEmpty, !mayLearn, !seven.refusedMore.contains(window) { seven.foundUnableToGrow.insert(window) }
      let path = road.map(\.brief).joined(separator: " → ")
      // By the eye: a number beside the road's verdict (`countedRules`).
      if moves.count > 1 {
        let wouldNot = moves.contains { abs($0.after.width - $0.requested.width) > 1 || abs($0.after.height - $0.requested.height) > 1 }
        problems.append(
          .init((timeOnly ? "eye-moved-again" : "eye-moved-twice") + (wouldNot ? "-sizing" : ""), "\(window) was seen to change \(moves.count) times for one thing that happened: \(path)"))
      }
      // Whatever the number of requests: on the way a window covers nothing in view that neither its old nor its new frame covers.
      // But for one that grows into a frame that lies within no display: macOS cuts what grows at a display's edge, so that one is sized first.
      let (old, new) = (road[0], road[road.count - 1])
      let growsOverAnEdge = (new.width > old.width + 1 || new.height > old.height + 1) && !system.displayList.contains { $0.frame.contains(new) }
      if road.count > 2, !growsOverAnEdge, let stray = road.dropFirst().dropLast().map({ strayed($0, between: old, and: new) }).max(), stray > 400 {
        problems.append(
          .init("strayed-between", "on its way \(window) covered \(Int(stray)) square points in view that neither its old nor its new frame covers: \(path)"))
      }
      // More than three times with nobody acting: Arbor and the window are stuck with each other, by however little.
      if timeOnly, let late = seven.seenWhileOnlyTimePassed[window], late > 3 {
        problems.append(.init("moved-over-and-over", "Arbor moved \(window) \(late) times with nobody touching anything: \(path)"))
        continue
      }
      guard moves.count > 1, FakeWindowSystem.detour(road) != nil else { continue }
      // A `side-by-side` is all or nothing. A window that can only be asked in its slot may refuse there, when the others have gone to
      // theirs: all of it is then taken back at once, "and there and back is nothing" (the product owner, 2026-10-15).
      if case .sideBySide(let named)? = action.parsedCommand, !refusals.isEmpty, named.contains(window),
        road[0].approximatelyEquals(road[road.count - 1], tolerance: 1)
      {
        continue
      }
      // The same a step later, for one that was in the Dock and could not be asked at all: it lands, does not fit, and all is taken back.
      // Back is where it stood before the command, not where this road begins: an act may have come between, and begun a new one.
      if everybodyAwaitedBefore.contains(window), controller.everybodyOfTheAwaitedGroup.isEmpty,
        let home = framesBeforeAnybodyWasAwaited[window], home.approximatelyEquals(road[road.count - 1], tolerance: 1)
      {
        continue
      }
      // A terminal takes whole character cells. How many go into a slot shows in the slot, at every size it has not been seen at, and it is
      // set right by less than half a cell. Nothing else is wrong with this road.
      let cell = system.windows[window].map { $0.sizeStep ?? ($0.behaviour == .grid ? CGSize(width: 20, height: 20) : .zero) } ?? .zero
      let setRight = Self.road(of: moves) { refusal, next in
        Self.isTheWayToTheMiddle(next, after: refusal) && refusal.requested.width - refusal.after.width < cell.width
          && refusal.requested.height - refusal.after.height < cell.height
      }
      if floats.isEmpty, FakeWindowSystem.detour(setRight) == nil {
        problems.append(.init("set-right-by-less-than-a-cell", "Arbor put \(window) into its slot and set it right afterwards: \(path)"))
        continue
      }
      // Its app would not take a size. The first time Arbor could not have known.
      let less = moves.contains { $0.after.width > $0.requested.width + 1 || $0.after.height > $0.requested.height + 1 }
      let more = moves.contains { $0.after.width < $0.requested.width - 1 || $0.after.height < $0.requested.height - 1 }
      let refused = less || more
      let knew = (less && seven.refusedLess.contains(window)) || (more && seven.refusedMore.contains(window))
      // Out of view at both ends and in view between, or the other way round: a flash.
      let (first, last) = (isInView(road[0]), isInView(road[road.count - 1]))
      if first == last, road.dropFirst().dropLast().contains(where: { isInView($0) != first }) {
        problems.append(
          .init(
            // Where no app refused anything in this step it was not a layout finding out about sizes: the view flew somewhere and was taken back.
            (somebodyRefused ? "flashed" : "flipped") + (first ? "-out-of-view" : "-into-view"),
            "\(window) \(first ? "left the screen and came back" : "showed and went again") for one thing that happened: \(path)"))
        continue
      }
      // In view all the way, nothing refused, and back where it began: the view flew somewhere and was taken back.
      if !somebodyRefused, floats.isEmpty, road[road.count - 1].approximatelyEquals(road[0], tolerance: 1) {
        problems.append(.init("flipped", "\(window) went and came back for one thing that happened, and no app refused a size: \(path)"))
        continue
      }
      // Never in a wrong place, but smaller or larger on the way than it ends up.
      guard FakeWindowSystem.changesOfPlace(road) > 1 else {
        // The window that is let be is to be set no frame at all. One bug, with a name of its own.
        let letBe = controller.windowLetBe == window ? "-let-be" : ""
        problems.append(.init("sized-there-and-back" + floats + letBe, "Arbor made \(window) smaller or larger than it ends up, for one thing that happened: \(path)"))
        continue
      }
      var rule = (timeOnly ? "moved-again" : "moved-twice") + (knew ? "-sizing-again" : refused ? "-sizing" : "") + floats
      // macOS said where it had moved the window before it said that a display had gone, and a lone window fills the Desktop. One bug, with
      // a name of its own, so that the rule goes on binding everywhere else.
      if rule == "moved-twice-floating", controller.settings.soleFloatTakesDesktop, case .displays(_, .first) = action {
        rule += "-windows-first"
      }
      problems.append(.init(rule, "Arbor moved \(window) \(moves.count) times for one thing that happened: \(path)"))
    }
    for move in seen {
      if move.after.width > move.requested.width + 1 || move.after.height > move.requested.height + 1 { seven.refusedLess.insert(move.window) }
      if move.after.width < move.requested.width - 1 || move.after.height < move.requested.height - 1 { seven.refusedMore.insert(move.window) }
    }
  }

  /// Whether `refusal` is a window that took less than the frame it was asked for, and no more on either side, and `next` only moves it,
  /// as it is, within that frame.
  static func isTheWayToTheMiddle(_ next: FakeWindowSystem.Move, after refusal: FakeWindowSystem.Move) -> Bool {
    let (asked, took) = (refusal.requested, refusal.after)
    return (took.width < asked.width - 1 || took.height < asked.height - 1) && took.width <= asked.width + 1 && took.height <= asked.height + 1
      && next.before == took && abs(next.after.width - took.width) <= 1 && abs(next.after.height - took.height) <= 1
      && asked.insetBy(dx: -1, dy: -1).contains(next.after)
  }

  /// Every frame a window had on the way of `moves`, but for where a move left it that `leavingOut` names, with the move after it.
  static func road(
    of moves: [FakeWindowSystem.Move], leavingOut: (_ move: FakeWindowSystem.Move, _ next: FakeWindowSystem.Move) -> Bool
  ) -> [CGRect] {
    var road = [moves[0].before]
    var leftOut: CGRect?
    for (move, next) in zip(moves, moves.dropFirst().map(Optional.some) + [nil]) {
      if road.last != move.before, leftOut != move.before { road.append(move.before) }
      leftOut = nil
      if let next, leavingOut(move, next) { leftOut = move.after } else { road.append(move.after) }
    }
    return road
  }

  /// Whether the display that shows most of `frame` is showing the Space of a window in full screen that has the keyboard.
  private func isBehindFullScreen(_ frame: CGRect) -> Bool {
    guard let focused = system.focused, let full = system.windows[focused]?.snapshot, full.isFullScreen,
      let display = Self.display(showingMostOf: frame, among: system.displayList)
    else { return false }
    return Self.display(showingMostOf: full.frame, among: system.displayList)?.id == display.id
  }

  /// How much of what the displays show `frame` covers that neither `old` nor `new` covers, in square points.
  private func strayed(_ frame: CGRect, between old: CGRect, and new: CGRect) -> CGFloat {
    system.displayList.reduce(0) { sum, display in
      // To whole points: macOS's own tile lies at half a point, and half a point along 1,500 is more than anybody sees.
      let seen = frame.integral.intersection(display.frame)
      guard !seen.isNull else { return sum }
      let (inOld, inNew) = (seen.intersection(old.integral), seen.intersection(new.integral))
      return sum + seen.area - inOld.area - inNew.area + inOld.intersection(inNew).area
    }
  }

  /// Whether no coordinate of the frames turns back on the way: left edge, top edge, width and height each only grow or only shrink.
  public static func goesOneWayOnly(_ road: [CGRect]) -> Bool {
    for coordinate in [\CGRect.minX, \CGRect.minY, \CGRect.width, \CGRect.height] {
      let steps = zip(road, road.dropFirst()).map { $1[keyPath: coordinate] - $0[keyPath: coordinate] }.filter { abs($0) > 1 }
      if steps.contains(where: { $0 > 0 }), steps.contains(where: { $0 < 0 }) { return false }
    }
    return true
  }

  // MARK: Nothing moves that was not asked to

  private static func nothingIsArranged(_ workspaces: [DisplayID: Workspace], _ parked: Set<WindowID>) -> Bool {
    parked.isEmpty
      && workspaces.values.allSatisfy {
        $0.tree.allWindows.isEmpty && $0.stashedWindows.isEmpty && $0.pinnedWindows.isEmpty && $0.summoned == nil && $0.filled == nil
      }
  }

  /// After a restart of the Mac the windows come back one by one, and each has its place kept with its room. One that takes its place moves alone: its neighbours
  /// are where they will be, however many are still to come. (In the login in which the arrangement was saved, whoever is missing was closed: its place waits
  /// without room, and its neighbours make room when it comes after all. And whoever changes the arrangement has taken it in hand.)
  func arrivalViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard seven.isALogin, let arrived = seven.arrived, isRunning, wasRunningBefore, controller.workspaces.values.contains(where: { $0.isDocked(arrived) }),
      controller.settings.newWindows == Settings().newWindows, controller.settings.rules.isEmpty
    else { return }
    asked("arrival")
    for window in Set(movesSeenInThisStep.map(\.window)).sorted() where window != arrived && isFairGame(window) != nil {
      // Where the two cannot both fit no room could be kept, and the one that was there first leaves: a name of its own.
      let left = controller.parked.contains(window) && !parkedBefore.contains(window)
      problems.append(
        .init(
          left ? "arrival-took-a-neighbour-out-of-view" : "arrival-moved-a-neighbour",
          "\(arrived) opened and took the place that was kept for it, and Arbor \(left ? "took \(window) out of view" : "moved \(window)")"))
    }
  }

  /// With nothing docked, kept in view, summoned or sent away there is no view that could leave a window out: none counts as out of view. (While one does, the
  /// nets for "before any dock" are not asked, so this fault used to switch off the very nets that should have seen it.)
  func parkedViolations(_ problems: inout [InvariantViolation]) {
    guard isRunning, wasRunningBefore, Self.nothingIsArranged(workspacesBefore, []), Self.nothingIsArranged(controller.workspaces, []) else { return }
    asked("parked-before-any-dock")
    for window in controller.parked.subtracting(parkedBefore).sorted() where system.windows[window] != nil {
      problems.append(.init("parked-before-any-dock", "nothing is docked, kept in view or summoned, and Arbor counts \(window) as out of view"))
    }
  }

  /// The ways home, and the commands that lay everything out afresh or take an arrangement back.
  private func asksForEverything(_ action: ChaosAction) -> Bool {
    guard let command = action.parsedCommand else { return false }
    switch command {
    case .relayout, .resume, .quit, .undo, .redo, .arrange, .arrangeAll, .layout: return true
    default: return command.bringsWindowsBack
    }
  }

  func unaskedViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if case .wayBack = action { return }
    let seen = movesSeenInThisStep
    let untouched = Self.nothingIsArranged(workspacesBefore, parkedBefore) && Self.nothingIsArranged(controller.workspaces, controller.parked)
    // Each step in which the net would have spoken, had anything moved.
    asked(untouched ? "before-any-dock" : seven.concerned != nil && wasRunningBefore ? "unasked" : "anything-may-move")
    guard !seen.isEmpty else { return }
    let resumed = seven.pausedBefore && !isPaused
    for window in Set(seen.map(\.window)).sorted() {
      // One that opened in this step was, before Arbor's first move, where its app opened it.
      guard let fake = isFairGame(window), let before = framesBefore[window] ?? seen.first(where: { $0.window == window })?.before,
        before != fake.snapshot.frame
      else { continue }
      let named = seven.concerned?.contains(window) == true
      let whatHappened = "Arbor moved \(window) from \(before.brief) to \(fake.snapshot.frame.brief)"
      let showedBefore = Self.area(of: before, showingOn: system.displayList)
      if untouched {
        // A command that names a window is somebody asking, and so is one that asks for everything.
        // Timers finish what it began.
        // But with nothing arranged there is nothing to lay out or to give back.
        // Undo, redo and a resume take back what was done, which is another matter.
        // And what is found counts as left: only what nobody could get hold of is fetched.
        if action.isACommand || seven.timeOnly, named || (seven.askedForEverything && (!seven.tookAWayHome || !titleBarIsWithinReach(before))) { continue }
        if seven.displaysChangedLast { continue }
        // What is found counts as left. The one thing Arbor may fetch is what nobody could get hold of: no 24 points of its title bar
        // are on any display (docs/VIABLE.md, section 6). Where most of it shows it may not be fetched, wherever its title bar is.
        if showedBefore < 0.5 * before.area, !titleBarIsWithinReach(before) { continue }
        // And what is there because of Arbor: apps open a window beside the one they have, and one that no display shows Arbor takes for
        // one that it put out of view itself, in a run that was killed.
        if showedBefore < 0.5 * before.area,
          system.windows.values.contains(where: { other in
            other.snapshot.id != window && !isInView(framesBefore[other.snapshot.id] ?? other.snapshot.frame)
              && (fake.snapshot.bundleID != nil ? other.snapshot.bundleID == fake.snapshot.bundleID : other.snapshot.pid == fake.snapshot.pid)
          })
        {
          continue
        }
        // Fetched is what is taken elsewhere as Arbor takes it into its books or lets go of it: Arbor starts in this step (a launch, the end of
        // a pause) or stops (a quit, a pause), or the window opens or comes to a Space that shows. What a layout in between does to a window
        // that hangs is the other story, however little showed: floating windows that are kept on the Desktop, and given their sizes back
        // at the corner they have.
        let isTakenInOrLetGo = !wasRunningBefore || !isRunning || framesBefore[window] == nil || !presentBefore.contains(window)
        let isFetched = showedBefore < 0.5 * before.area && isTakenInOrLetGo && before.origin != fake.snapshot.frame.origin
        problems.append(
          .init(
            isFetched ? "fetched-before-any-dock" : "moved-before-any-dock",
            "\(whatHappened), and nothing has been docked, pinned, summoned or made to fill the screen"))
        continue
      }
      guard let display = controller.workspaceID(containing: window), let workspace = controller.workspaces[display] else { continue }
      // What a crash left out of view is fetched. What was wholly in view and is not docked stays where it is.
      if action == .launch || resumed {
        asked("launch-or-resume")
        // The view that comes back may not include the Desktop: then what floats goes out of view with it.
        if workspace.isFloating(window), !workspace.isStashed(window), showedBefore >= 0.995 * before.area, !parkedBefore.contains(window),
          !controller.parked.contains(window), !(resumed && seven.movedByThePause.contains(window) && seven.displaysAtThePause == system.displayList)
        {
          let launch = seven.launchedAfterAQuit ? "moved-at-launch" : "moved-at-launch-after-a-crash"
          problems.append(.init(action == .launch ? launch : "moved-at-resume", "\(whatHappened), where it floats as it did"))
        }
        continue
      }
      guard let concerned = seven.concerned, !concerned.contains(window), wasRunningBefore, presentBefore.contains(window),
        controller.displays == displaysBefore, let earlier = workspacesBefore[display],
        // The display looks as it looked, and the window is what it was on it.
        seven.layoutsBefore[display] == controller.layouts[display], earlier.isDocked(window) == workspace.isDocked(window),
        earlier.isFloating(window) == workspace.isFloating(window), earlier.isStashed(window) == workspace.isStashed(window),
        parkedBefore.contains(window) == controller.parked.contains(window),
        // Nothing was owed it.
        !owedAMoveBefore.contains(window), !owedAPlaceBefore.contains(window), !owedTheWayBackBefore.contains(window)
      else { continue }
      // A docked window that somebody had moved out of its slot is put back.
      if workspace.isDocked(window), let slot = seven.layoutsBefore[display]?.windowFrames[window],
        !before.approximatelyEquals(slot, tolerance: Self.slotTolerance), fake.snapshot.frame.approximatelyEquals(slot, tolerance: Self.slotTolerance)
      {
        continue
      }
      // A rule name of its own for a known failure (ChaosKnownFailures.swift): out of view before and after, nobody sees it.
      let rule = parkedBefore.contains(window) ? "moved-unasked-out-of-view" : "moved-unasked"
      problems.append(.init(rule, "\(whatHappened); what happened was not about it, and \(display) is laid out as it was"))
    }
  }

  /// A window that macOS zoomed at its person's double-click is let be through whatever nobody asked of Arbor (collab/QUESTIONS.md,
  /// Q22): windows that open, close, hide and come forward, and time. It may go out of view with the rest, and is fetched from where
  /// nobody could reach it.
  func zoomViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard !seven.letBeBefore.isEmpty, wasRunningBefore, isRunning, controller.displays == displaysBefore, inHandBefore == nil else { return }
    switch action {
    case .open, .close, .quitApp, .minimize, .space, .hide, .title, .focus, .switchApp, .backgroundFocus, .focusNothing, .activate, .openTab,
      .selectTab, .closeTab, .renumber, .listed, .cursor, .save, .flush, .advance, .react, .settle:
      break
    default: return
    }
    asked("let-be")
    for window in seven.letBeBefore.intersection(movesSeenInThisStep.map(\.window)).sorted() {
      guard let fake = isFairGame(window), let before = framesBefore[window], before != fake.snapshot.frame, !controller.parked.contains(window),
        // Taken to another display by macOS it leaves the arrangement, and a slot's size is never a window's own: it gets its own there.
        !(controller.workspaces.contains { $0.value.isFloating(window) && workspacesBefore[$0.key]?.isDocked(window) != true }
          && seven.slotSizesOfThoseLetBe[window].map { abs($0.width - before.width) <= 4 && abs($0.height - before.height) <= 4 } == true),
        // Nothing is let be where nobody can reach it: less than half of it showed, and it covered less than half a display.
        system.displayList.contains(where: { display in
          let showing = before.intersection(display.frame)
          return !showing.isNull && showing.area >= 0.5 * min(before.area, display.frame.area)
        }),
        // Nor with its title bar under the menu bar.
        system.displayList.first(where: { $0.frame.contains(CGPoint(x: before.midX, y: before.minY + 1)) }).map({ before.minY >= $0.visibleFrame.minY - 1 })
          ?? true
      else { continue }
      problems.append(
        .init(
          "moved-out-of-its-zoom",
          "Arbor moved \(window) from \(before.brief), where a double-click had put it, to \(fake.snapshot.frame.brief), and nobody had asked Arbor for anything"))
    }
  }

  /// Whether `back` undoes `there` as a person understands it: out of the Dock again, shown again, out of full screen again, the view back
  /// where it was.
  private func takesBack(_ back: ChaosAction, _ there: ChaosAction) -> Bool {
    switch (there, back) {
    case (.minimize(let a, true), .minimize(let b, false)), (.fullScreen(let a, true), .fullScreen(let b, false)),
      (.space(let a, false), .space(let b, true)):
      return a == b
    case (.hide(let a, true), .hide(let b, false)): return a == b
    // macOS zooms a window at a double-click on its title bar, and takes it back at the next.
    case (.doubleClick(let a), .doubleClick(let b)): return a == b
    default:
      // A key goes down and comes up: the command runs once.
      guard let first = there.parsedCommand, back.parsedCommand == .back, controller.holdLevel == nil
      else { return false }
      switch first {
      case .zoom, .stepIn, .stepOut, .neighbor, .home, .showAll, .desktop, .goToView:
        // It did move a view, and only that.
        return seven.there.map { $0.views != controller.workspaces.mapValues(\.camera) } == true
      default: return false
      }
    }
  }

  /// There and back is nothing: into the Dock and out, hidden and shown, full screen and back, a move of the view and Back. Every window is
  /// where it was.
  func thereAndBackViolations(_ problems: inout [InvariantViolation]) {
    guard let due = seven.backDue, isRunning, !isWaitingForALayout(), system.dragging == nil else { return }
    seven.backDue = nil
    // The key for a frame pressed twice steps out again and leaves nothing for Back to lead to: the views are not what they were.
    if let views = due.views, views != controller.workspaces.mapValues(\.camera) { return }
    // Out of the Dock is a switch to that window: if it was out of view before it went, the view goes to it now (rule 4).
    if due.rule == "there-and-back-moved", due.about.contains(where: { due.frames[$0].map { !isInView($0) } ?? false }) { return }
    asked(due.rule == "there-and-back-moved" ? "there-and-back" : "pause-and-resume")
    for (window, frame) in due.frames.sorted(by: { $0.key < $1.key }) {
      guard let fake = isFairGame(window), !fake.snapshot.frame.approximatelyEquals(frame, tolerance: 1),
        isInView(frame) || isInView(fake.snapshot.frame), fake.placeIsArborsDoing
      else { continue }
      problems.append(
        .init(due.rule, "\(window) was at \(frame.brief) before `\(due.there)`, which has been taken back, and is at \(fake.snapshot.frame.brief)"))
    }
  }

  /// Once Arbor has quit nobody fetches anything: no window is where Arbor put it and nobody can get hold of it. Asked at every step after the
  /// quit, because an app that hung at that moment wakes up later.
  func afterQuitViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if action.parsedCommand == .quit, wasRunningBefore || seven.pausedBefore, !isRunning, !isPaused { seven.hasQuit = true }
    guard seven.hasQuit, !isRunning, !isPaused else { return }
    asked("after-quit")
    for window in windowsOutOfReach() {
      problems.append(
        .init("quit-left-out-of-reach", "Arbor has quit and \(window) is at \(system.windows[window]!.snapshot.frame.brief), where Arbor put it and nobody can get hold of it"))
    }
  }

  /// Looking elsewhere and back, switching windows, a floating window that comes or goes: none of it is about how the docked windows share the display.
  private func leavesTheArrangementAlone(_ action: ChaosAction) -> Bool {
    switch action {
    case .focus, .switchApp, .focusNothing, .backgroundFocus, .activate, .cursor, .open: return true
    case .close(let window), .minimize(let window, _): return controller.workspaces.values.contains { $0.isFloating(window) }
    default:
      guard let command = action.parsedCommand else { return false }
      switch command {
      case .home, .showAll, .zoom, .back, .forward, .stepIn, .stepOut, .neighbor, .desktop, .goToView, .saveView, .focus, .relayout: return true
      default: return command.isQuery
      }
    }
  }

  /// The same windows in the same view have the same frames, for as long as nobody changes how they share the display: a look elsewhere and back, a
  /// floating window that comes and goes, Lay Out Again are nothing. Under a name of its own where what was changed last was a gap dragged by hand.
  func sameWindowsSameFramesViolations(_ problems: inout [InvariantViolation]) {
    guard isRunning, !isWaitingForALayout(), system.dragging == nil, system.resizing == nil, !controller.aPeekIsUnderWay, controller.holdLevel == nil
    else { return }
    if seven.arrangementIsDue {
      seven.arrangementIsDue = false
      for (display, layout) in controller.layouts where !layout.windowFrames.isEmpty {
        // Only where Arbor put them: a docked window that macOS has zoomed, or a hand has taken, is not how the arrangement shares the display, and the way back
        // to its slot is no fault. With one such window there is nothing to compare until the arrangement changes again.
        seven.arrangements[display] = (
          layout.camera, layout.windowFrames.keys.reduce(into: [:]) { $0[$1] = system.windows[$1].flatMap { $0.placeIsArborsDoing ? $0.snapshot.frame : nil } }
        )
      }
      // A gap at its limit moves nothing, and a gap that did not move settles nothing.
      if seven.aGapWasDragged, seven.arrangements.values.allSatisfy({ $0.frames.allSatisfy { seven.framesBeforeTheGap[$0.key] == $0.value } }) {
        seven.aGapWasDragged = false
      }
      return
    }
    guard controller.displays == displaysBefore else { return seven.arrangements = [:] }
    for (display, left) in seven.arrangements.sorted(by: { $0.key < $1.key }) {
      guard let layout = controller.layouts[display], layout.camera == left.view else { continue }
      guard Set(layout.windowFrames.keys) == Set(left.frames.keys) else {
        // Somebody else shares the view now: a window that a rule docked, a tile that got room.
        seven.arrangements[display] = nil
        continue
      }
      asked("same-windows")
      for (window, frame) in left.frames.sorted(by: { $0.key < $1.key }) {
        guard let fake = isFairGame(window), !fake.snapshot.frame.approximatelyEquals(frame, tolerance: 1), fake.placeIsArborsDoing else { continue }
        seven.arrangements[display] = nil
        problems.append(
          .init(
            seven.aGapWasDragged ? "dragged-gap-did-not-last" : "same-windows-other-frames",
            "\(window) was at \(frame.brief) when \(seven.aGapWasDragged ? "its person had dragged the gap" : "the arrangement was last changed"), the same windows share the same view, and it is at \(fake.snapshot.frame.brief)"))
      }
    }
  }

  /// Displays go and come back, and nothing else is done: on a desk that is as it was, Arbor has put no window elsewhere than it was.
  func outAndBackViolations(_ problems: inout [InvariantViolation]) {
    guard seven.displaysChangedLast, isRunning, !isWaitingForALayout(), system.dragging == nil, system.resizing == nil, controller.holdLevel == nil,
      let desk = seven.desks.first(where: { $0.displays == system.displayList })
    else { return }
    seven.desks.removeAll { $0.displays == system.displayList }
    asked("out-and-back")
    for (window, frame) in desk.frames.sorted(by: { $0.key < $1.key }) {
      // Where macOS left it is macOS's business; this is about Arbor's own moves.
      guard let fake = isFairGame(window), !fake.groundHasShifted, fake.lastRequest?.took == fake.snapshot.frame,
        !fake.snapshot.frame.approximatelyEquals(frame, tolerance: 1), isInView(frame) || isInView(fake.snapshot.frame)
      else { continue }
      problems.append(
        .init("displays-out-and-back-moved", "\(window) was at \(frame.brief) on this desk, displays have gone and come back and nothing else was done, and Arbor has put it at \(fake.snapshot.frame.brief)"))
    }
  }

  /// A start docks nothing that floated when Arbor was last there, unless a rule or a setting says so.
  func dockedAtAStartViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    defer {
      if isRunning {
        (seven.floatedWhenLastSeen, seven.displaysWhenLastSeen) = (Set(controller.workspaces.values.flatMap(\.floating.keys)), Set(system.displayList.map(\.id)))
      }
    }
    guard action == .launch, isRunning, !wasRunningBefore, !seven.pausedBefore, controller.settings.newWindows == Settings().newWindows,
      controller.settings.rules.isEmpty
    else { return }
    asked("docked-at-a-start")
    for window in seven.floatedWhenLastSeen.sorted() where controller.workspaces.values.contains(where: { $0.isDocked(window) }) {
      guard isFairGame(window) != nil || controller.parked.contains(window) else { continue }
      // Its slot is on a display that was away then and is back: somebody did dock it, there.
      if let home = controller.workspaces.first(where: { $0.value.isDocked(window) })?.key, !seven.displaysWhenLastSeen.contains(home) { continue }
      problems.append(.init("docked-at-a-start", "\(window) floated when Arbor was last running, nobody has docked it, and the start has docked it"))
    }
  }

  /// A display comes, goes, moves or changes size: afterwards nothing is lost. Whoever left it there, macOS or Arbor, a window that is meant to be
  /// in view shows at least half of itself once all has come to rest, unless its person left it hanging so on this display as it is.
  func afterDisplaysViolations(_ problems: inout [InvariantViolation]) {
    guard seven.displaysChangedLast, !seven.askedSinceTheDisplaysChanged, isRunning, !isWaitingForALayout(), !system.displayList.isEmpty,
      system.dragging == nil, system.resizing == nil, controller.holdLevel == nil
    else { return }
    seven.askedSinceTheDisplaysChanged = true
    asked("after-displays")
    let largest = system.displayList.map(\.visibleFrame.area).max() ?? 0
    for window in system.windows.keys.sorted() {
      // The same numbers on other displays is what no Mac does.
      guard let fake = isFairGame(window), !fake.groundHasShifted, !controller.parked.contains(window), !controller.windowsOwedAMove.contains(window)
      else { continue }
      let frame = fake.snapshot.frame
      let showing = Self.area(of: frame, showingOn: system.displayList)
      guard showing < 0.5 * min(frame.area, largest),
        !(userPlaces[window] ?? []).contains(where: { place in system.displayList.contains { place.allows(frame, on: $0) } }),
        // What the change took nothing from stays as it is (Q20).
        showing < (seven.showedBeforeTheDisplaysChanged[window] ?? .infinity) - 0.01 * frame.area
      else { continue }
      problems.append(
        .init(
          "displays-left-mostly-out",
          "the displays have changed and \(window) is at \(frame.brief), \(Int((100 * showing / frame.area).rounded())) % in view, and does not count as out of view"))
    }
  }

  /// A start takes no window out of view that is in view when Arbor starts, but for what Show Everything itself has out of view: windows
  /// in tiles, and tabs behind the one in front (collab/QUESTIONS.md, Q16). The window that has the keyboard stays in view even then.
  func startViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard action == .launch && !wasRunningBefore && !seven.pausedBefore || action == .wayBack(.startAgain), isRunning, !system.displayList.isEmpty
    else { return }
    asked("start")
    let behind = controller.workspaces.keys.reduce(into: Set<WindowID>()) {
      $0.formUnion(controller.layoutOfEverything(on: $1)?.hiddenWindows ?? [])
    }
    for window in system.windows.keys.sorted() where !behind.contains(window) || window == seven.focusedBefore {
      guard let fake = isFairGame(window), presentBefore.contains(window), let before = framesBefore[window],
        Self.area(of: before, showingOn: system.displayList) >= 0.5 * before.area, !isInView(fake.snapshot.frame) || controller.parked.contains(window)
      else { continue }
      problems.append(.init("start-took-out-of-view", "\(window) was in view at \(before.brief) when Arbor started, and Arbor has put it at \(fake.snapshot.frame.brief)"))
    }
  }

  /// A pause that ends with nothing done meanwhile cannot be seen afterwards (F40): everything is where it was before it. Asked, like every
  /// way there and back, once all has come to rest.
  func noteAPauseThatEnded() {
    guard seven.pausedBefore, isRunning, let before = seven.beforeThePause else { return }
    seven.backDue = (before, "pause", "pause-and-resume-moved", nil, [])
  }

  // MARK: After a person's own act macOS decides

  /// A window closes, goes into the Dock, is hidden or quit, somebody clicks the desktop, time passes: nobody asks Arbor for anything. Where
  /// no window that Arbor knows has the keyboard then, macOS has decided so (the app stays in front with its menu bar; Finder has it),
  /// and Arbor gives it to nobody. Where macOS picked a window that Arbor keeps out of view, that is Arbor's doing, and another story.
  func handedOnViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    switch action {
    case .focusNothing, .close, .quitApp, .minimize(_, true), .hide(_, true), .cursor, .title, .backgroundFocus: break
    default: guard seven.timeOnly else { return }
    }
    guard isRunning, wasRunningBefore, seven.nobodyBefore else { return }
    asked("handed-on")
    // A summon that waited for its app's window is somebody's asking, answered late (F53).
    let summonedBefore = Set(workspacesBefore.values.compactMap { $0.summoned?.window })
    let summoned = Set(controller.workspaces.values.compactMap { $0.summoned?.window }).subtracting(summonedBefore)
    for focus in system.focusLog.dropFirst(seven.focusCallsBefore) where !summoned.contains(focus.window) {
      problems.append(.init("keyboard-handed-on-unasked", "nobody Arbor knows had the keyboard, nobody asked for anything, and Arbor focused \(focus.window)"))
    }
  }

  // MARK: The window you switch to comes to the front and into view

  func switchedToViolations(_ problems: inout [InvariantViolation]) {
    if movesSeenInThisStep.contains(where: { $0.window == seven.switchedTo }) { seven.arborMovedItSince = true }
    guard let window = seven.switchedTo, system.focused == window, let fake = isFairGame(window), fake.snapshot.isOnActiveSpace,
      !system.displayList.isEmpty, system.dragging == nil, system.resizing == nil, !isWaitingForALayout(),
      // A held view turns the keyboard away, which is what it is for (F58).
      controller.holdLevel == nil, holdBefore == nil, !controller.aPeekIsUnderWay,
      !controller.windowsOwedAMove.contains(window)
    else { return }
    asked("switched-to")
    let frame = fake.snapshot.frame
    let showing = Self.area(of: frame, showingOn: system.displayList)
    let arborPutItThere =
      fake.placeIsArborsDoing && fake.lastRequest?.took == frame && !fake.groundHasShifted && !seven.carriedByMacOS.contains(window) && !isWhereAHandLeftIt(window, frame)
    if controller.parked.contains(window)
      || (arborPutItThere && showing < 0.5 * min(frame.area, Self.display(showingMostOf: frame, among: system.displayList)?.visibleFrame.area ?? 0)
        && !(userPlaces[window] ?? []).contains { place in system.displayList.contains { place.allows(frame, on: $0) } })
    {
      problems.append(
        .init(
          seven.onlyTheAppWasReported ? "app-switch-out-of-view" : controller.parked.contains(window) ? "switched-to-and-sent-away"
            // A floating window's frame is its person's, so no switch fetches it, or takes it anywhere but to the corner where its person left it: the
            // fault was to put it there, or to make it larger there, and has a net of its own.
            : (!seven.arborMovedItSince || fake.home?.origin == frame.origin) && controller.workspaces.values.contains { $0.isFloating(window) } ? "switched-to-mostly-out"
            : "switched-to-out-of-view",
          "its user switched to \(window), which has the keyboard and is at \(frame.brief), out of view"))
    } else if showing < 0.995 * frame.area, arborPutItThere,
      let display = Self.display(showingMostOf: frame, among: system.displayList),
      fake.minimumSize.width <= display.visibleFrame.width, fake.minimumSize.height <= display.visibleFrame.height,
      !(userPlaces[window] ?? []).contains(where: { place in system.displayList.contains { place.allows(frame, on: $0) } })
    {
      problems.append(
        .init(
          "switched-to-partly-out",
          "its user switched to \(window), which has the keyboard, and Arbor has it at \(frame.brief), \(Int((100 * showing / frame.area).rounded())) % in view"))
    }
    // Whatever Arbor raised since lies over it. A pinned or summoned window is meant to.
    let above = system.windowsFrontToBack().prefix { $0 != window }
    for other in above {
      guard let cover = system.windows[other], cover.snapshot.isPresent, cover.snapshot.frame.insetBy(dx: 2, dy: 2).overlaps(frame),
        !controller.workspaces.values.contains(where: { $0.staysInView(other) })
      else { continue }
      problems.append(.init("switched-to-behind", "its user switched to \(window), and \(other) at \(cover.snapshot.frame.brief) lies in front of it"))
    }
  }

  // MARK: Less by default (collab/QUESTIONS.md, Q29)

  /// Arbor never takes a floating window out of view: not to fill the screen with another, not at a start, a resume or a change of displays, not when a
  /// window closes. An app's windows that were summoned go when they are sent away, which names them.
  func floatingViolations(_ problems: inout [InvariantViolation]) {
    for move in movesSeenInThisStep {
      let window = move.window
      guard isFairGame(window) != nil, presentBefore.contains(window),
        wasRunningBefore, workspacesBefore.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) && !$0.isSummoned(window) }),
        controller.workspaces.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) })
      else { continue }
      asked("floating")
      if isInView(move.before), !isInView(move.after), system.windows[window].map({ !isInView($0.snapshot.frame) }) ?? false {
        problems.append(.init("floating-taken-out-of-view", "\(window) floats, and Arbor took it out of view: from \(move.before.brief) to \(move.after.brief)"))
      }
    }
  }

  /// What stays at a change of displays is a window the change did not touch (Q20): a floating window of which as much shows on the new displays, where it
  /// lies, as showed on the old ones, and which macOS has not carried anywhere, is not moved by Arbor either.
  func untouchedByTheChangeViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard belongsToAChangeOfDisplays(action), isRunning, wasRunningBefore, !system.displayList.isEmpty else { return }
    var told = Set<WindowID>()
    for move in movesSeenInThisStep where told.insert(move.window).inserted {
      let window = move.window
      guard isFairGame(window) != nil, let showed = seven.showedBeforeTheDisplaysChanged[window], !seven.carriedByMacOS.contains(window),
        framesBefore[window] == move.before,
        workspacesBefore.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) }), !parkedBefore.contains(window),
        controller.workspaces.values.contains(where: { $0.isFloating(window) })
      else { continue }
      asked("untouched-by-the-change")
      if Self.area(of: move.before, showingOn: system.displayList) >= showed - 0.01 * move.before.area, showed > 0 {
        problems.append(
          .init(
            "displays-moved-the-untouched",
            "the displays changed and took nothing from \(window) at \(move.before.brief), and Arbor moved it to \(system.windows[window]!.snapshot.frame.brief)"))
      }
    }
  }

  /// At a change of displays Arbor fits only what the change took out of reach (decided 2026-10-15): a floating window that nobody named, whose title bar is
  /// within reach where macOS left it, is not set by Arbor at all, however little of it shows. Whoever misses it has a key.
  func fetchedAtAChangeViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard belongsToAChangeOfDisplays(action), isRunning, wasRunningBefore, !system.displayList.isEmpty, !controller.settings.floatingWindowsMakeWay else { return }
    var told = Set<WindowID>()
    // The first move Arbor makes: where the window was then is where macOS had left it.
    for move in movesSeenInThisStep where told.insert(move.window).inserted {
      let window = move.window
      guard isFairGame(window) != nil, workspacesBefore.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) && $0.role(of: window) == nil }),
        !parkedBefore.contains(window), controller.workspaces.values.contains(where: { $0.isFloating(window) })
      else { continue }
      asked("fetched-at-a-change")
      if titleBarIsWithinReach(move.before) {
        problems.append(
          .init(
            "displays-fetched-what-was-in-reach",
            "the displays changed, \(window) was at \(move.before.brief) with its title bar within reach, and Arbor moved it to \(system.windows[window]!.snapshot.frame.brief)"))
      }
    }
  }

  /// With nothing docked, kept in view or summoned, and nothing asked of it, Arbor sends the keyboard nowhere: a window that goes into the Dock, is
  /// closed or hidden leaves the keyboard where macOS leaves it.
  func keyboardViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if case .wayBack = action { return }
    guard isRunning, wasRunningBefore, !seven.somebodyAskedArbor, Self.nothingIsArranged(workspacesBefore, parkedBefore),
      Self.nothingIsArranged(controller.workspaces, controller.parked)
    else { return }
    asked("keyboard")
    for focus in system.focusLog.dropFirst(seven.focusLogMark) {
      problems.append(.init("keyboard-taken-unasked", "nothing is docked and nobody asked Arbor for anything, and Arbor sent the keyboard to \(focus.window)"))
    }
  }

  /// How many steps Undo could take back, on all displays.
  private var undoSteps: Int { controller.workspaces.keys.reduce(0) { $0 + controller.undoHistory.steps(.undo, on: $1).count } }

  /// A key that docks takes no window out of view that was in view (Q29, 8): not the one it names, which would have the keyboard, and not one that was docked
  /// before, which becomes a tile for want of room.
  func dockViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    switch action.parsedCommand {
    case .dock, .dockBeside, .toggleFloat, .arrange, .arrangeAll: break
    default: return
    }
    if case .key(_, .released) = action { return }
    guard isRunning, wasRunningBefore, controller.holdLevel == nil else { return }
    asked("dock")
    for window in Set(movesSeenInThisStep.map(\.window)).sorted() {
      guard let fake = isFairGame(window), presentBefore.contains(window), let before = framesBefore[window], isInView(before), !parkedBefore.contains(window),
        !isInView(fake.snapshot.frame), controller.workspaces.values.contains(where: { $0.isDocked(window) })
      else { continue }
      problems.append(.init("dock-took-out-of-view", "`\(action.text)` took \(window), which is docked, out of view: from \(before.brief) to \(fake.snapshot.frame.brief)"))
    }
  }

  /// With Arbor running, a plain drag of a floating window is what it is without Arbor: nothing shows, nothing else moves, Arbor sets no frame, and
  /// letting go docks nothing. A docked window dragged plainly comes out and its place closes, which moves what is docked and nothing else.
  /// Whether a window dragged at this moment is offered anywhere to dock: how Arbor is set, and what is held.
  var aDragIsOfferedPlaces: Bool { DragDocks(setting: controller.settings.dragDocks).docks(holding: system.modifierKeysDown()) }

  func plainDragViolations(_ problems: inout [InvariantViolation]) {
    guard let dragged = seven.dragged, isRunning, let fake = system.windows[dragged], cooperates(fake), controller.filter.manages(fake.snapshot) else { return }
    asked("plain-drag")
    for move in movesSeenInThisStep {
      if move.window == dragged {
        if seven.draggedWasFloating {
          problems.append(.init("plain-drag-moved-it", "\(dragged) floated and was dragged, and Arbor moved it from \(move.before.brief) to \(move.after.brief)"))
        }
      } else if !seven.draggedWasFloating, !isInView(move.before), isInView(move.after) {
        // The view was on the docked window that has left it. What it kept out of view is back: that is the view's doing
        // (`floating-taken-out-of-view` counts the way out).
      } else if seven.draggedWasFloating || workspacesBefore.values.contains(where: { $0.isFloating(move.window) }) {
        // Carried to another display it leaves one Desktop and comes to another: a fault of its own, older than this net (`knownFailures`).
        let crossed = controller.workspaceID(containing: dragged) != seven.displayAtTheGrab
        problems.append(
          .init(
            crossed ? "plain-drag-across-displays-moved-another" : "plain-drag-moved-another",
            "\(dragged) was dragged, and Arbor moved \(move.window) from \(move.before.brief) to \(move.after.brief)"))
      }
    }
    if system.dragging == dragged, harness.overlays.preview != nil {
      problems.append(.init("plain-drag-showed-a-preview", "\(dragged) is being dragged with no key held, and Arbor shows where it would dock"))
    }
    // Nothing is left for Undo to take back: ⌃⌥Z after it takes back what was asked of Arbor before, not the hand's drag.
    if seven.dragged != nil, seven.draggedWasFloating, system.dragging == nil, undoSteps > seven.undoStepsAtTheGrab {
      problems.append(.init("plain-drag-left-an-undo-step", "\(dragged) floated, was dragged with no key held and let go, and Undo now has a step for that"))
      seven.undoStepsAtTheGrab = undoSteps
    }
    if system.dragging == nil, seven.draggedWasFloating, controller.workspaces.values.contains(where: { $0.isDocked(dragged) }) {
      problems.append(.init("plain-drag-docked", "\(dragged) floated, was dragged with no key held and let go, and is docked"))
      // Said once.
      seven.dragged = nil
    }
    // Nothing waits over a target, and nothing waits to see what macOS makes of the drop.
    let started = Set(harness.scheduler.pendingKeys).subtracting(timersBefore).filter { $0.hasPrefix("drag-dwell") || $0.hasPrefix("left-to-macos") }
    if !started.isEmpty {
      problems.append(.init("plain-drag-started-a-timer", "\(dragged) is dragged with no key held, and Arbor has started \(started.sorted())"))
    }
    // A docked window comes out: it floats, at its own size. Under 24 points was a slip of the hand.
    guard seven.dragged != nil, !seven.draggedWasFloating, system.dragging == nil, !system.mouseDown, !isWaitingForALayout(), let from = seven.frameAtTheGrab,
      workspacesBefore.values.contains(where: { $0.isDocked(dragged) }) || controller.workspaces.values.contains(where: { $0.isFloating(dragged) })
    else { return }
    seven.dragged = nil
    let letGo = fake.home ?? fake.snapshot.frame
    // Both the window and the hand, which took it by the middle of its title bar: a window that its app had not yet brought to its slot when
    // it was taken ends somewhere else without having been carried anywhere.
    guard hypot(letGo.minX - from.minX, letGo.minY - from.minY) >= 24, hypot(system.cursor.x - from.midX, system.cursor.y - (from.minY + 10)) >= 24,
      fake.snapshot.isPresent, !fake.snapshot.isFullScreen
    else { return }
    asked("dragged-out")
    if controller.workspaces.values.contains(where: { $0.isDocked(dragged) }) {
      problems.append(.init("plain-drag-left-it-docked", "\(dragged) was docked, was dragged away with no key held and let go, and is docked"))
    } else if let own = seven.ownSizes[dragged] {
      var due = CGSize(width: max(own.width, fake.minimumSize.width), height: max(own.height, fake.minimumSize.height))
      if let most = fake.maximumSize { due = CGSize(width: min(due.width, most.width), height: min(due.height, most.height)) }
      let size = fake.snapshot.frame.size
      // What the display it was let go on has room for.
      guard let visible = Self.display(showingMostOf: fake.snapshot.frame, among: system.displayList)?.visibleFrame, due.width <= visible.width,
        due.height <= visible.height
      else { return }
      if let earlier = seven.earlierOwnSizes[dragged], abs(size.width - earlier.width) <= 1.5, abs(size.height - earlier.height) <= 1.5 { return }
      if abs(size.width - due.width) > 1.5 || abs(size.height - due.height) > 1.5 {
        problems.append(
          .init(
            "plain-drag-not-its-own-size",
            "\(dragged) was docked and was dragged out; it is \(Int(size.width))×\(Int(size.height)), and its own size was \(Int(due.width))×\(Int(due.height))"))
      }
    }
  }

  // MARK: A change of the displays takes no window to a display that nobody put it on

  /// Whether `action` is a change of the displays, or time passing after one.
  private func belongsToAChangeOfDisplays(_ action: ChaosAction) -> Bool {
    if case .displays = action { return true }
    return seven.displaysChangedLast && seven.timeOnly
  }

  func noteWhichDisplayEachWindowIsAtHomeOn(after action: ChaosAction, movesBefore: [WindowID: Int]) {
    seven.homeDisplays = seven.homeDisplays.filter { system.windows[$0.key] != nil }
    seven.everAtHomeOn = seven.everAtHomeOn.filter { system.windows[$0.key] != nil }
    let aboutAChange = belongsToAChangeOfDisplays(action)
    var summons = false
    if case .summon = action.parsedCommand { summons = true }
    for (id, fake) in system.windows {
      // A guest that nobody touches stays a guest, whatever the view does with it meanwhile.
      let somebodyPutIt = fake.movesNotArbors != movesBefore[id]
      let askedFor = action.isACommand && framesBefore[id] != fake.snapshot.frame && (summons || seven.concerned?.contains(id) == true)
      guard seven.homeDisplays[id] == nil || (!aboutAChange && (somebodyPutIt || askedFor)), isInView(fake.snapshot.frame) else { continue }
      let frame = fake.snapshot.frame
      seven.homeDisplays[id] = Set(system.displayList.filter { frame.intersection($0.frame).area > 0.1 * frame.area }.map(\.id))
      seven.everAtHomeOn[id, default: []].formUnion(seven.homeDisplays[id]!)
    }
  }

  /// A floating window goes along with its display, and to another one only while its own is away (F08). When displays come and go, Arbor takes
  /// none to a display that it only visited, or never saw, while the one somebody put it on is there.
  func homeDisplayViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard belongsToAChangeOfDisplays(action), !system.displayList.isEmpty else { return }
    for window in Set(movesSeenInThisStep.map(\.window)).sorted() {
      guard let fake = isFairGame(window), let homes = seven.homeDisplays[window], system.displayList.contains(where: { homes.contains($0.id) }),
        controller.workspaces.values.contains(where: { $0.isFloating(window) && !$0.isStashed(window) })
      else { continue }
      asked("home-display")
      let frame = fake.snapshot.frame
      let home = homes.sorted().map(\.rawValue).joined(separator: " and ")
      if isInView(frame), !controller.parked.contains(window) {
        guard let now = Self.display(showingMostOf: frame, among: system.displayList), !homes.contains(now.id) else { continue }
        problems.append(
          .init(seven.everAtHomeOn[window]?.contains(now.id) == true ? "taken-back-from-where-it-was-put" : "taken-to-another-display", "the displays changed, and Arbor has put \(window) at \(frame.brief) on \(now.id); somebody had put it on \(home), which is there"))
      } else if let counted = controller.workspaceID(containing: window), !homes.contains(counted) {
        // Out of view there is nothing to see of where it belongs: here alone the controller is asked.
        problems.append(
          .init(seven.everAtHomeOn[window]?.contains(counted) == true ? "taken-back-out-of-view-from-where-it-was-put" : "taken-out-of-view-with-another-display", "the displays changed, and Arbor has put \(window) out of view at \(frame.brief) with \(counted); somebody had put it on \(home), which is there"))
      }
    }
  }

  // MARK: Something is always in view

  /// At rest, with windows that Arbor arranges and a person could see, no display shows any of them: all are out of view. Asked at the step
  /// in which the last one went. `-held` where a hold keeps them out (F58 lets a held view show the wallpaper; it does not speak of a display that goes).
  func emptyDeskViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if case .displays = action {
      // By the displays as they were: a desk that showed nothing before the change was not emptied by it.
      let showed = framesBefore.contains { window, frame in
        presentBefore.contains(window)
          && displaysBefore.contains {
            let showing = frame.intersection($0.frame)
            return !showing.isNull && showing.width > 2 && showing.height > 2
          }
      }
      if showed { seven.displaysChangedSinceSomethingShowed = true } else { seven.deskWasEmpty = true }
    }
    guard isRunning, wasRunningBefore, !system.displayList.isEmpty, !isWaitingForALayout(), system.dragging == nil, system.resizing == nil,
      !controller.aPeekIsUnderWay
    else { return }
    let fair = system.windows.keys.sorted().filter { isFairGame($0) != nil }
    guard !fair.isEmpty else { return }
    asked("empty-desk")
    // Any window at all that shows counts: one in full screen, one Arbor does not arrange. So does a tile, which is there to be seen and clicked.
    guard !system.windows.values.contains(where: { $0.snapshot.isPresent && isInView($0.snapshot.frame) }),
      harness.overlays.tiles.values.allSatisfy(\.isEmpty)
    else {
      (seven.deskWasEmpty, seven.displaysChangedSinceSomethingShowed) = (false, false)
      return
    }
    let wasEmpty = seven.deskWasEmpty
    seven.deskWasEmpty = true
    // Without a change of displays it is what its person asked for: the Desktop's key with nothing floating, say.
    // So is a held view that empties: it shows the wallpaper until its window is back or the hold is let go (F58).
    // And so is whatever somebody has done SINCE the change: a script need not rest between the two, so the flag alone does not tell.
    guard !wasEmpty, seven.displaysChangedSinceSomethingShowed, belongsToAChangeOfDisplays(action) else { return }
    let changed = seven.displaysChangedSinceSomethingShowed ? "-after-displays" : ""
    problems.append(
      .init("nothing-in-view" + (controller.holdLevel != nil ? "-held" : "") + changed, "no display shows a window, and \(fair) are out of view"))
  }

  // MARK: The ways home

  /// What a way home promises, asked once it has been taken and everything has come to rest. `displays` are the ones it was about;
  /// nil is all of them.
  func wayHomeViolations(_ name: String, on displays: Set<DisplayID>?, givesSizesBack: Bool) -> [InvariantViolation] {
    guard !system.displayList.isEmpty else { return [] }
    var problems: [InvariantViolation] = []
    let movedNow = Set(movesSeenInThisStep.map(\.window))
    for window in system.windows.keys.sorted() {
      guard let fake = isFairGame(window), !fake.groundHasShifted else { continue }
      let frame = fake.snapshot.frame
      let home = controller.workspaceID(containing: window)
      if let displays, isRunning { guard let home, displays.contains(home) else { continue } }
      guard let display = Self.display(showingMostOf: frame, among: system.displayList) ?? system.displayList.first(where: { $0.id == home })
      else { continue }
      let visible = display.visibleFrame
      asked("way-home")
      // Sent away on purpose, it comes when it is summoned (F53).
      let stashed = isRunning && controller.workspaces.values.contains { $0.isStashed(window) }
      if isRunning, controller.parked.contains(window) {
        // A window too large for its slot shows as a tile, which is there to be seen and clicked.
        // So does a tab behind the one in front: what Show Everything itself has out of view.
        let isATile =
          controller.layouts.values.contains { $0.tiles.contains { $0.windows.contains(window) } }
          || controller.workspaces.keys.contains { controller.layoutOfEverything(on: $0)?.hiddenWindows.contains(window) == true }
        if !stashed, !isATile, !controller.windowsOwedAMove.contains(window) {
          problems.append(.init("home-leaves-out", "after \(name), \(window) is still out of view, at \(frame.brief)"))
        }
        continue
      }
      let fits =
        fake.minimumSize.width <= visible.width && fake.minimumSize.height <= visible.height && frame.width <= visible.width + 1
        && frame.height <= visible.height + 1
      let showsAll = Self.area(of: frame, showingOn: system.displayList) >= 0.995 * frame.area
      func overhang() -> String {
        "hangs \(Self.overhang(of: frame, over: visible).map { Int($0.rounded()) }) points over the left, top, right and bottom of what \(display.id) shows, \(visible.brief)"
      }
      if !showsAll {
        // Where somebody left it hanging over an edge, it may go on hanging as far. And where Arbor never put it, it is its person's or macOS's.
        if fits, fake.lastRequest?.took == frame, !isWhereAHandLeftIt(window, frame),
          !(userPlaces[window] ?? []).contains(where: { place in system.displayList.contains { place.allows(frame, on: $0) } })
        {
          problems.append(.init("home-not-whole", "after \(name), \(window) is at \(frame.brief) and \(overhang())"))
        }
      } else if fits, movedNow.contains(window), fake.lastRequest?.took == frame, display.frame.contains(frame),
        !visible.insetBy(dx: -1, dy: -1).contains(frame),
        // Not where somebody left it as far behind them.
        !(fake.home.map { zip(Self.overhang(of: frame, over: visible), Self.overhang(of: $0, over: visible)).allSatisfy { $0 <= $1 + 1 } } ?? false)
      {
        // What Arbor has just placed is clear of the Dock and the menu bar as well.
        problems.append(.init("home-behind-the-dock", "after \(name), Arbor has put \(window) at \(frame.brief), where it \(overhang())"))
      }
      guard givesSizesBack, let own = seven.ownSizes[window] else { continue }
      // A pause and Quit give back what Arbor took. What its person had macOS zoom is left as it is (Q22); Float All names every window.
      // In a size macOS or its app gave it. A slot's size is never a window's own: in the last size Arbor gave it, it is asked for its own like the rest.
      if !isRunning, seven.letBeBefore.contains(window),
        let was = framesBefore[window]?.size, let given = seven.slotSizesOfThoseLetBe[window],
        abs(was.width - given.width) > 4 || abs(was.height - given.height) > 4
      {
        if let before = framesBefore[window], before != frame, movedNow.contains(window) {
          problems.append(.init("moved-out-of-its-zoom", "\(name) moved \(window) from \(before.brief), where a double-click had put it, to \(frame.brief)"))
        }
        continue
      }
      asked("sizes")
      if let earlier = seven.earlierOwnSizes[window], abs(frame.width - earlier.width) <= 1.5, abs(frame.height - earlier.height) <= 1.5 { continue }
      // What its app allows today, and what the display has room for.
      var due = CGSize(width: max(own.width, fake.minimumSize.width), height: max(own.height, fake.minimumSize.height))
      if let most = fake.maximumSize { due = CGSize(width: min(due.width, most.width), height: min(due.height, most.height)) }
      guard due.width <= visible.width, due.height <= visible.height else { continue }
      let step = fake.sizeStep ?? (fake.behaviour == .grid ? CGSize(width: 20, height: 20) : .zero)
      if abs(frame.width - due.width) > max(step.width, 1.5) || abs(frame.height - due.height) > max(step.height, 1.5) {
        problems.append(
          .init(
            "size-not-given-back",
            "after \(name), \(window) is \(Int(frame.width))×\(Int(frame.height)); its own size was \(Int(due.width))×\(Int(due.height))"))
      }
    }
    return problems
  }

  /// By how many points `frame` hangs over the left, top, right and bottom of `bounds`.
  private static func overhang(of frame: CGRect, over bounds: CGRect) -> [CGFloat] {
    [bounds.minX - frame.minX, bounds.minY - frame.minY, frame.maxX - bounds.maxX, frame.maxY - bounds.maxY].map { max($0, 0) }
  }

  /// A way home taken as a plain command in the middle of a walk: typed, from the menu, by link, or with its key.
  func wayHomeViolations(after action: ChaosAction) -> [InvariantViolation] {
    guard let command = action.parsedCommand else { return [] }
    // A key acts when it goes down, but for Show Everything, which may become a look around.
    if case .key(_, let phase) = action, phase != (command == .showAll ? .released : .pressed) { return [] }
    let line = command.text
    // The echoes of the moves the command has just made are still to come, and change nothing.
    guard refusals.isEmpty, wasRunningBefore, holdBefore == nil, !isWaitingForALayout(orReports: false), !controller.aPeekIsUnderWay,
      system.dragging == nil, system.resizing == nil, inHandBefore == nil
    else { return [] }
    let atHome = displaysAtHome
    switch command {
    case .quit: return isRunning ? [] : wayHomeViolations(line, on: nil, givesSizesBack: true)
    case .pause, .togglePause: return isPaused ? wayHomeViolations(line, on: nil, givesSizesBack: true) : []
    // A key says nothing of whether it was obeyed.
    case .floatAll:
      return controller.workspaces.values.allSatisfy(\.tree.allWindows.isEmpty) ? wayHomeViolations(line, on: nil, givesSizesBack: true) : []
    case .floatAllHere:
      let emptied = Set(controller.workspaces.filter { $0.value.tree.allWindows.isEmpty && workspacesBefore[$0.key]?.tree.allWindows.isEmpty == false }.keys)
      return wayHomeViolations(line, on: emptied, givesSizesBack: true)
    case .home, .showAll:
      let moved = atHome.filter { workspacesBefore[$0]?.camera != controller.workspaces[$0]?.camera || seven.layoutsBefore[$0] != controller.layouts[$0] }
      return wayHomeViolations(line, on: moved, givesSizesBack: false)
    default: return []
    }
  }
}

extension ChaosAction {
  /// The command, if it is one that Arbor can read.
  var parsedCommand: Command? {
    switch self {
    case .command(let text), .via(_, let text), .key(let text, _): try? Command.parse(text)
    case .url(let url): try? Command.parse(url: url)
    default: nil
    }
  }

  /// Somebody asked Arbor for something in words: a shortcut, the menu, the command line, a link.
  var isACommand: Bool {
    switch self {
    case .command, .via, .key, .url: true
    default: false
    }
  }
}
