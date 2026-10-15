import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The product's rules about what a person sees, as nets over random walks. Each asks what the window system saw, not what the
/// controller believes, and each has a control in `ChaosSevenRulesTests` that fails when the net is cut.
///
/// | Rule | Net |
/// |---|---|
/// | Nothing moves until the person docks something | `moved-before-any-dock`, `fetched-before-any-dock`, `moved-at-launch`, `moved-at-resume`, `start-took-out-of-view`, `launch-keyboard-in-a-tile`, `pause-and-resume-moved`, `there-and-back-moved`, `moved-unasked` |
/// | No jolts: a window moves once, to where it ends up | `moved-twice`, `moved-again`; both with `-sizing` where its app refused a size, `-sizing-again` where it had refused before |
/// | The window you switch to comes to the front and into view | `switched-to-out-of-view`, `app-switch-out-of-view`, `switched-to-partly-out`, `switched-to-behind` |
/// | Quitting, Float All and pause give windows their own earlier sizes back | `size-not-given-back` |
/// | After any way home no window is less than wholly in view | `home-not-whole`, `home-behind-the-dock`, `home-leaves-out` |
extension ChaosRunner {
  /// What the nets remember from step to step.
  struct SevenRules {
    var moveLogMark = 0
    var layoutsBefore: [DisplayID: Layout] = [:]
    var focusedBefore: WindowID?
    var pausedBefore = false
    var fullScreenBefore: Set<WindowID> = []
    /// Arbor's moves of each window that a person could see, since somebody last did something. Time passing is nobody.
    var seenSinceSomebodyActed: [WindowID: [FakeWindowSystem.Move]] = [:]
    /// The windows the last thing somebody did was about; nil is all of them. Timers finish that work.
    var concerned: Set<WindowID>? = []
    /// The size each window last had of its own: as its app opened it, or as somebody other than Arbor made it while it was not docked.
    var ownSizes: [WindowID: CGSize] = [:]
    /// The size it had of its own before its user asked Arbor for another with a key: which of the two Arbor takes for its own is not laid down.
    var earlierOwnSizes: [WindowID: CGSize] = [:]
    /// The last thing somebody did was to plug, unplug or rearrange displays, which has rules of its own (`left-its-place`, `moved-for-nothing`).
    var displaysChangedLast = false
    /// In the current step nobody does anything; and the last thing somebody did was a command that asks for everything.
    var timeOnly = false
    var askedForEverything = false
    /// Where every window was before the last thing somebody did, kept through a pause in which nobody does anything.
    var beforeThePause: [WindowID: CGRect]?
    /// Where everything was, at rest, before the last thing somebody did, and what that was.
    var there: (frames: [WindowID: CGRect], action: ChaosAction, views: [DisplayID: NodeID])?
    /// The last thing somebody did took the one before it back: where everything has to be again once it has come to rest.
    var backDue: (frames: [WindowID: CGRect], there: String, rule: String)?
    /// What the pause itself moved, to give it its own frame back: the resume may take it back to where it was.
    var movedByThePause: Set<WindowID> = []
    /// The window its user switched to last, until somebody does something else; and whether macOS said which window it was, or only
    /// that another app came forward.
    var switchedTo: WindowID?
    var onlyTheAppWasReported = false
    /// Windows whose app has refused to go below a size, or above one, in an earlier step: Arbor has had its chance to learn.
    var refusedLess: Set<WindowID> = []
    var refusedMore: Set<WindowID> = []
  }

  /// The detector of docs/VIABLE.md, section 5, that a rule of the walks stands for: one vocabulary on Linux and on a Mac.
  public nonisolated static func detector(for rule: String) -> String? {
    let table: [(prefix: String, detector: String)] = [
      ("moved-twice", "jolt"), ("moved-again", "jolt"), ("moved-", "moved-unasked"), ("fetched-", "moved-unasked"), ("there-and-back", "moved-unasked"),
      ("pause-and-resume", "moved-unasked"), ("left-its-place", "moved-unasked"), ("start-took", "lost"), ("switched-to-behind", "behind"),
      ("switched-to", "focus"), ("app-switch", "focus"), ("size-", "size-lost"), ("home-", "lost"), ("lost", "lost"), ("out-of-reach", "lost"),
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
    seven.layoutsBefore = controller.layouts
    seven.focusedBefore = system.focused
    seven.pausedBefore = isPaused
    seven.fullScreenBefore = Set(system.windows.values.lazy.filter(\.snapshot.isFullScreen).map(\.snapshot.id))
    // Asked now: `settle` lets go of the mouse, and afterwards nothing shows that somebody held it.
    seven.timeOnly = isOnlyTimePassing(action)
    guard !seven.timeOnly else { return }
    // A key that comes up again belongs to its going down. (Show Everything is decided when it comes up: a tap, or the end of a look.)
    if case .key(let line, .released) = action, (try? Command.parse(line)) != .showAll { return }
    seven.seenSinceSomebodyActed = [:]
    seven.concerned = windowsConcerned(by: action)
    seven.askedForEverything = asksForEverything(action)
    seven.switchedTo = nil
    if case .displays = action { seven.displaysChangedLast = true } else { seven.displaysChangedLast = false }
    if case .key(_, .released) = action { return }
    seven.backDue = seven.there.flatMap { takesBack(action, $0.action) ? ($0.frames, $0.action.text, "there-and-back-moved") : nil }
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
    case .close, .quitApp, .focusNothing, .cursor, .press, .commandKey, .save, .flush, .advance, .react: return []
    case .minimize(let window, _), .space(let window, _), .fullScreen(let window, _), .title(let window, _), .limits(let window, _, _),
      .behave(let window, _), .move(let window, _), .focus(let window), .switchApp(let window), .backgroundFocus(let window),
      .listed(let window, _):
      return [window]
    case .grab(let window), .edge(let window, _, _): return inHand.union([window])
    case .carry, .release, .loseRelease, .settle: return inHand
    case .hide(let pid, _), .hang(let pid, _): return windows(of: pid)
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
      .moveToDisplay, .frameRect:
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
    case .launch, .crash: (seven.refusedLess, seven.refusedMore) = ([], [])
    // A native tab has the size of its group.
    case .openTab(let new, let front), .selectTab(let new, let front): if let size = seven.ownSizes[front] { seven.ownSizes[new] = size }
    case .closeTab(let front, let next): if let size = seven.ownSizes[front] { seven.ownSizes[next] = size }
    case .focus(let window): if system.windows[window] != nil { (seven.switchedTo, seven.onlyTheAppWasReported) = (window, false) }
    case .switchApp(let window):
      // Within one app macOS says which window has the keyboard.
      if let pid = system.windows[window]?.snapshot.pid, seven.focusedBefore.flatMap({ system.windows[$0]?.snapshot.pid }) != pid {
        (seven.switchedTo, seven.onlyTheAppWasReported) = (window, true)
      }
    case .limits(let window, _, _), .behave(let window, _):
      seven.refusedLess.remove(window)
      seven.refusedMore.remove(window)
    default: break
    }
    seven.ownSizes = seven.ownSizes.filter { system.windows[$0.key] != nil || system.backgroundTabs[$0.key] != nil }
    seven.earlierOwnSizes = seven.earlierOwnSizes.filter { system.windows[$0.key] != nil }
    for (id, fake) in system.windows {
      guard let known = seven.ownSizes[id] else {
        seven.ownSizes[id] = (fake.home ?? fake.snapshot.frame).size
        continue
      }
      // What macOS makes of a window to fit it onto the display that is left is nobody's wish.
      if case .displays = action { continue }
      // Full screen is no size of its own, and what macOS gives back afterwards is what the window had before.
      guard fake.movesNotArbors != movesBefore[id], let home = fake.home, let before = framesBefore[id], home.size != before.size,
        !fake.snapshot.isFullScreen, !seven.fullScreenBefore.contains(id)
      else { continue }
      // The edges of a docked window move the gaps between slots.
      let wasDocked = wasRunningBefore && workspacesBefore.values.contains { $0.isDocked(id) }
      if !wasDocked, home.size != known {
        seven.ownSizes[id] = home.size
        seven.earlierOwnSizes[id] = nil
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
        ["space-", "enforce-", "landed-", "displays-blinked", "focus", "back-from-full-screen", "summon-wait", "pending-slots", "sole-float-after-launch"]
          .contains { key.hasPrefix($0) }
      }
  }

  func sevenRulesViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    onceViolations(after: action, &problems)
    unaskedViolations(after: action, &problems)
    noteAPauseThatEnded()
    thereAndBackViolations(&problems)
    startViolations(after: action, &problems)
    switchedToViolations(&problems)
  }

  // MARK: No jolts: a window moves once, to where it ends up

  func onceViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    if !seven.pausedBefore, isPaused { seven.movedByThePause = Set(movesSeenInThisStep.map(\.window)) }
    // Several things done in one step.
    if case .wayBack = action {
      seven.seenSinceSomebodyActed = [:]
      return
    }
    let timeOnly = seven.timeOnly
    // A pause or a hold whose time was up: what follows is its own story, however long ago the last one was.
    if timeOnly, seven.pausedBefore != isPaused || (isRunning && holdBefore != controller.holdLevel) { seven.seenSinceSomebodyActed = [:] }
    let seen = movesSeenInThisStep
    guard !seen.isEmpty else {
      // So is anything that comes after seconds in which nothing moved.
      if case .advance(let seconds) = action, seconds >= 2 { seven.seenSinceSomebodyActed = [:] }
      return
    }
    for move in seen { seven.seenSinceSomebodyActed[move.window, default: []].append(move) }
    for window in Set(seen.map(\.window)).sorted() {
      guard isFairGame(window) != nil, presentBefore.contains(window), let moves = seven.seenSinceSomebodyActed[window] else { continue }
      asked("once")
      guard moves.count > 1 else { continue }
      // Its app would not take a size. The first time Arbor could not have known.
      let less = moves.contains { $0.after.width > $0.requested.width + 1 || $0.after.height > $0.requested.height + 1 }
      let more = moves.contains { $0.after.width < $0.requested.width - 1 || $0.after.height < $0.requested.height - 1 }
      let refused = less || more
      let knew = (less && seven.refusedLess.contains(window)) || (more && seven.refusedMore.contains(window))
      let path = ([moves[0].before] + moves.map(\.after)).map(\.brief).joined(separator: " → ")
      problems.append(
        .init(
          (timeOnly ? "moved-again" : "moved-twice") + (knew ? "-sizing-again" : refused ? "-sizing" : ""),
          "Arbor moved \(window) \(moves.count) times for one thing that happened: \(path)"))
    }
    for move in seen {
      if move.after.width > move.requested.width + 1 || move.after.height > move.requested.height + 1 { seven.refusedLess.insert(move.window) }
      if move.after.width < move.requested.width - 1 || move.after.height < move.requested.height - 1 { seven.refusedMore.insert(move.window) }
    }
  }

  // MARK: Nothing moves that was not asked to

  private static func nothingIsArranged(_ workspaces: [DisplayID: Workspace], _ parked: Set<WindowID>) -> Bool {
    parked.isEmpty
      && workspaces.values.allSatisfy {
        $0.tree.allWindows.isEmpty && $0.stashedWindows.isEmpty && $0.pinnedWindows.isEmpty && $0.summoned == nil
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
      guard let fake = isFairGame(window), let before = framesBefore[window], before != fake.snapshot.frame else { continue }
      let named = seven.concerned?.contains(window) == true
      let whatHappened = "Arbor moved \(window) from \(before.brief) to \(fake.snapshot.frame.brief)"
      let showedBefore = Self.area(of: before, showingOn: system.displayList)
      if untouched {
        // A command that names a window is somebody asking, and so is one that asks for everything.
        // Timers finish what it began.
        if action.isACommand || seven.timeOnly, named || seven.askedForEverything { continue }
        if seven.displaysChangedLast { continue }
        problems.append(
          .init(
            showedBefore < 0.5 * before.area ? "fetched-before-any-dock" : "moved-before-any-dock",
            "\(whatHappened), and nothing has been docked, pinned or summoned"))
        continue
      }
      guard let display = controller.workspaceID(containing: window), let workspace = controller.workspaces[display] else { continue }
      // What a crash left out of view is fetched. What was wholly in view and is not docked stays where it is.
      if action == .launch || resumed {
        asked("launch-or-resume")
        // The view that comes back may not include the Desktop: then what floats goes out of view with it.
        if workspace.isFloating(window), !workspace.isStashed(window), showedBefore >= 0.995 * before.area, !parkedBefore.contains(window),
          !controller.parked.contains(window), !(resumed && seven.movedByThePause.contains(window))
        {
          problems.append(.init(action == .launch ? "moved-at-launch" : "moved-at-resume", "\(whatHappened), where it floats as it did"))
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
      problems.append(.init("moved-unasked", "\(whatHappened); what happened was not about it, and \(display) is laid out as it was"))
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
    asked(due.rule == "there-and-back-moved" ? "there-and-back" : "pause-and-resume")
    for (window, frame) in due.frames.sorted(by: { $0.key < $1.key }) {
      guard let fake = isFairGame(window), !fake.snapshot.frame.approximatelyEquals(frame, tolerance: 1),
        isInView(frame) || isInView(fake.snapshot.frame), fake.placeIsArborsDoing
      else { continue }
      problems.append(
        .init(due.rule, "\(window) was at \(frame.brief) before `\(due.there)`, which has been taken back, and is at \(fake.snapshot.frame.brief)"))
    }
  }

  /// A start takes no window out of view that is in view when Arbor starts, but for what Show Everything itself has out of view: windows
  /// in tiles, and tabs behind the one in front (collab/QUESTIONS.md, Q16).
  func startViolations(after action: ChaosAction, _ problems: inout [InvariantViolation]) {
    guard action == .launch, isRunning, !wasRunningBefore, !seven.pausedBefore, !system.displayList.isEmpty else { return }
    asked("start")
    let behind = controller.workspaces.keys.reduce(into: Set<WindowID>()) {
      $0.formUnion(controller.layoutOfEverything(on: $1)?.hiddenWindows ?? [])
    }
    // If one of those has the keyboard the view of its display goes to it, which is a bug of its own.
    let taken = system.focused.flatMap { behind.contains($0) ? controller.workspaceID(containing: $0) : nil }
    for window in system.windows.keys.sorted() where !behind.contains(window) {
      guard let fake = isFairGame(window), presentBefore.contains(window), let before = framesBefore[window],
        Self.area(of: before, showingOn: system.displayList) >= 0.5 * before.area, !isInView(fake.snapshot.frame) || controller.parked.contains(window)
      else { continue }
      let rule = taken != nil && controller.workspaceID(containing: window) == taken ? "launch-keyboard-in-a-tile" : "start-took-out-of-view"
      problems.append(.init(rule, "\(window) was in view at \(before.brief) when Arbor started, and Arbor has put it at \(fake.snapshot.frame.brief)"))
    }
  }

  /// A pause that ends with nothing done meanwhile cannot be seen afterwards (F40): everything is where it was before it. Asked, like every
  /// way there and back, once all has come to rest.
  func noteAPauseThatEnded() {
    guard seven.pausedBefore, isRunning, let before = seven.beforeThePause else { return }
    seven.backDue = (before, "pause", "pause-and-resume-moved")
  }

  // MARK: The window you switch to comes to the front and into view

  func switchedToViolations(_ problems: inout [InvariantViolation]) {
    guard let window = seven.switchedTo, system.focused == window, let fake = isFairGame(window), fake.snapshot.isOnActiveSpace,
      !system.displayList.isEmpty, system.dragging == nil, system.resizing == nil, !isWaitingForALayout(),
      // A held view turns the keyboard away, which is what it is for (F58).
      controller.holdLevel == nil, holdBefore == nil, !controller.aPeekIsUnderWay,
      !controller.windowsOwedAMove.contains(window)
    else { return }
    asked("switched-to")
    let frame = fake.snapshot.frame
    let showing = Self.area(of: frame, showingOn: system.displayList)
    let arborPutItThere = fake.placeIsArborsDoing && fake.lastRequest?.took == frame && !fake.groundHasShifted
    if controller.parked.contains(window)
      || (arborPutItThere && showing < 0.5 * min(frame.area, system.displayList.map(\.visibleFrame.area).max() ?? 0)
        && !(userPlaces[window] ?? []).contains { place in system.displayList.contains { place.allows(frame, on: $0) } })
    {
      problems.append(
        .init(
          seven.onlyTheAppWasReported ? "app-switch-out-of-view" : "switched-to-out-of-view",
          "its user switched to \(window), which has the keyboard and is at \(frame.brief), out of view"))
    } else if showing < 0.995 * frame.area, arborPutItThere,
      let display = Self.display(showingMostOf: frame, among: system.displayList),
      fake.minimumSize.width <= display.visibleFrame.width, fake.minimumSize.height <= display.visibleFrame.height,
      !(userPlaces[window] ?? []).contains(where: { $0.allows(frame, on: display) })
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
        let isATile = controller.layouts.values.contains { $0.tiles.contains { $0.windows.contains(window) } }
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
        if fits, fake.lastRequest?.took == frame, !(userPlaces[window] ?? []).contains(where: { $0.allows(frame, on: display) }) {
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
