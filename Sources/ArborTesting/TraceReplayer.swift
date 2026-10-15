import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// Replays a trace (docs/TRACES.md) against a real `Controller`.
///
/// The header becomes a world: a `Harness` whose fake window system holds the recorded windows and displays and
/// whose store holds the recorded workspaces. Then every stimulus in the trace (window events, commands, overlay
/// actions, scheduled work, settings) is delivered in order, with the clock moved to each line's time.
///
/// What the controller asks of the window system is answered from the trace where the trace has the same call,
/// so a recorded app that refused a size refuses it again; otherwise by the fake's own model, taught the
/// minimum and maximum sizes the trace shows.
///
/// - **strict**: the controller must make the calls that were recorded, in that order, and commands must give the
///   recorded results. For "behaviour did not change".
/// - **free**: the controller may do as it likes; only the invariants must hold (`ReplayInvariants`). For traces that
///   outlive changes to Arbor's behaviour, which is what the ones in `collab/evidence/traces` are for.
@MainActor
public final class TraceReplayer {
  public enum Mode: String, Sendable, CaseIterable {
    case strict, free
  }

  public struct Problem: Equatable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable {
      /// Strict mode: Arbor did not do what was recorded.
      case divergence
      /// Something that must always hold did not.
      case invariant
      /// A line of the trace's `.expect` file did not hold.
      case expectation
    }

    public var kind: Kind
    /// The line of the trace file where it showed.
    public var line: Int
    public var text: String

    public init(kind: Kind, line: Int, text: String) {
      self.kind = kind
      self.line = line
      self.text = text
    }

    public var description: String { "line \(line): \(kind.rawValue): \(text)" }
  }

  /// Something the replayed Arbor did to a window: what a person at that Mac would have seen, had today's Arbor been running there.
  public struct Deed: Equatable, Sendable, CustomStringConvertible {
    public enum What: Equatable, Sendable {
      /// `from` is where the window was, `took` where it is now. An app may take another frame than it was asked for, or none.
      case setFrame(WindowID, asked: CGRect, from: CGRect?, took: CGRect?)
      case focus(WindowID)
      /// Any other call that shows (`raise`, `setMinimized`, `unhideApp`…), as a trace writes it.
      case call(String)
    }

    public var what: What
    /// The last line of the trace file that had been replayed: the stimulus Arbor was reacting to, or, for scheduled work the trace does not have
    /// and that ran when its time came, the line before that time. After the last one: that line.
    public var line: Int
    /// When, in the trace's seconds.
    public var t: Double
    /// While the controller was starting on what the header says. A trace begins in the middle of a session, so this is the replay's doing.
    public var atStart: Bool

    public init(what: What, line: Int, t: Double = 0, atStart: Bool = false) {
      (self.what, self.line, self.t, self.atStart) = (what, line, t, atStart)
    }

    /// The window, if the deed moved it: it is somewhere else, or of another size, than before. A request that an app refused
    /// outright, or for the frame the window has, is work but no move.
    public var moved: WindowID? {
      guard case .setFrame(let id, _, let from?, let took?) = what, !took.approximatelyEquals(from, tolerance: 1) else { return nil }
      return id
    }

    public var description: String {
      switch what {
      case .setFrame(let id, let asked, let from, let took):
        "setFrame \(id) asked \(traceText(asked)) from \(from.map { traceText($0) } ?? "nowhere") took \(took.map { traceText($0) } ?? "nothing")"
      case .focus(let id): "focus \(id)"
      case .call(let text): text
      }
    }
  }

  public struct Report {
    public var problems: [Problem] = []
    /// What Arbor did to the windows, in order (`moved`, `asked-focus` in an `.expect` file; `arbor-sim replay --course`).
    public var deeds: [Deed] = []
    /// What happened, as text with drawings of the layout, for `arbor-sim replay`.
    public var story: [String] = []
    /// Stimuli delivered to the controller.
    public var delivered = 0
    /// Calls that change something, by who answered them.
    public var answeredFromTrace = 0
    public var answeredByModel = 0

    public var ok: Bool { problems.isEmpty }
  }

  public let trace: Trace
  public let mode: Mode
  public let harness: Harness
  public private(set) var report = Report()
  /// How to deliver events and overlay actions that `TraceLine` has no case for, by name (`TraceRecorder.event`, `action`). **A new
  /// requirement of `WindowSystemEvents` or `OverlayActions` gets its entry in `knownStimuli`.**
  public var otherStimuli: [String: @MainActor ([TraceJSON]) -> Void] = [:]
  /// Whether what is being replayed reads settings.json to find news in it (see `settingsFile`).
  private var readsNewSettings = true

  /// Requests this close to a recorded one count as the same (traces round to hundredths).
  private let tolerance: CGFloat = 1
  /// Scheduled work waits for the line that says it ran, if that line comes no later than this after it was
  /// due. A Mac's main thread can be held up for seconds by an app that does not answer.
  private let timerSlack = 5.0
  /// macOS reports a focus change Arbor asked for 5 to 20 ms later, now and then a few tenths of a second.
  private let focusAnswerWindow = 1.0
  /// This many put-backs in a row, with nothing in between but windows changing, is a fight with an app.
  private let enforcementLimit = 10
  /// Asking a window this often in a row for a frame it has just refused, and getting the same answer, is asking in vain. Each
  /// request is several round trips to the app.
  private let futileLimit = 5
  /// Enough to see what is wrong; a replay that has left the rails would report every line.
  private let problemLimit = 25

  private let verbose: Bool
  /// Only the state at the end is wanted: no sentence is made, no layout drawn and no invariant looked at on the way, which is most of what a
  /// replay costs. For whoever replays the same lines hundreds of times, after a replay that did look.
  private let silent: Bool
  private let bridge: ReplayWindowSystem
  private var entries: [TraceEntry] { trace.entries }
  private var fake: FakeWindowSystem { harness.system }

  private enum Phase {
    /// Starting the controller from the header. Nothing to compare with.
    case boot
    /// The controller is reacting to the stimulus before `response`.
    case reacting
    /// Scheduled work the trace does not mention is running because its time came.
    case clock(String)
    /// After the last line.
    case drain
  }

  private var phase = Phase.boot
  /// The entry being processed.
  private var current = 0
  /// The recorded lines that answer the stimulus being delivered: up to the next one.
  private var response = 0..<0
  private var consumed: [Bool]
  /// For each entry, the index of the next stimulus that is not nested.
  private var nextStimulus: [Int]
  private var timerLines: [String: [Int]] = [:]
  /// Every recorded `setFrame` that got an answer, by window.
  private var remembered: [WindowID: [(index: Int, request: CGRect, result: CGRect)]] = [:]
  private var minimumSizes: [WindowID: CGSize] = [:]
  private var maximumSizes: [WindowID: CGSize] = [:]
  /// Windows whose width or height comes in steps, as a terminal's does in character cells.
  private var widthSteps: [WindowID: SizeSteps] = [:]
  private var heightSteps: [WindowID: SizeSteps] = [:]
  /// Where each window was in the recording, as of the line being processed.
  private var recordedFrames: [WindowID: CGRect] = [:]
  /// The frame each window took the last time the replayed controller placed it.
  private var placed: [WindowID: CGRect] = [:]
  /// The window being dragged or resized with the mouse.
  private var gesture: WindowID?
  /// Windows the recorded Arbor focused and the replayed one did not, with the time until which macOS's answer is
  /// expected (`answersToFocus`).
  private var unaskedFocus: [WindowID: Double] = [:]
  /// Windows the replayed Arbor focused and the recorded one did not, waiting for macOS's answer.
  private var newlyAskedFocus: [WindowID] = []
  private var lastResult: CommandResult?
  private var seenPreviews = 0
  private var framesSetThisStimulus = 0
  private var enforcementStreaks: [String: Int] = [:]
  /// For each window, the last request it did not take as asked, what it took instead, and how often in a row.
  private var refusals: [WindowID: (request: CGRect, result: CGRect, count: Int)] = [:]
  private var lastDrawing = ""
  private var quietLines = 0

  public init(_ trace: Trace, mode: Mode = .free, verbose: Bool = false, silent: Bool = false) {
    self.trace = trace
    self.mode = mode
    self.verbose = verbose
    self.silent = silent
    let header = trace.header
    let entries = trace.entries
    consumed = Array(repeating: false, count: entries.count)

    nextStimulus = Array(repeating: entries.count, count: entries.count)
    var next = entries.count
    for index in entries.indices.reversed() {
      nextStimulus[index] = next
      if entries[index].line.isStimulus, !entries[index].nested { next = index }
    }

    minimumSizes = header.minimumSizes
    // Every size a window was seen at, and how far its answers were from what was asked.
    var widths: [WindowID: SizeSteps.Evidence] = [:]
    var heights: [WindowID: SizeSteps.Evidence] = [:]
    func saw(_ id: WindowID, _ size: CGSize) {
      widths[id, default: .init()].seen.insert(Int(size.width.rounded()))
      heights[id, default: .init()].seen.insert(Int(size.height.rounded()))
    }
    for window in header.windows { saw(window.id, window.frame.size) }
    for (index, entry) in entries.enumerated() {
      switch entry.line {
      case .timer(let key): timerLines[key, default: []].append(index)
      case .appeared(let window), .changed(let window, _): saw(window.id, window.frame.size)
      case .setFrame(let id, let request, let result?, _):
        remembered[id, default: []].append((index, request, result))
        saw(id, result.size)
        widths[id, default: .init()].misses.append(result.width - request.width)
        heights[id, default: .init()].misses.append(result.height - request.height)
      default: break
      }
    }
    widthSteps = widths.compactMapValues { SizeSteps($0) }
    heightSteps = heights.compactMapValues { SizeSteps($0) }
    // An app that gave more than was asked has a minimum size, one that gave less a maximum, unless its sizes come in
    // steps and it only rounded.
    let unlimited = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
    for (id, answers) in remembered {
      for (_, request, result) in answers {
        let over = CGSize(width: result.width - request.width, height: result.height - request.height)
        if widthSteps[id]?.explains(over.width) != true {
          if over.width > 2 { minimumSizes[id, default: .zero].width = result.width }
          if over.width < -2 { maximumSizes[id, default: unlimited].width = result.width }
        }
        if heightSteps[id]?.explains(over.height) != true {
          if over.height > 2 { minimumSizes[id, default: .zero].height = result.height }
          if over.height < -2 { maximumSizes[id, default: unlimited].height = result.height }
        }
      }
    }

    var hints: [WindowID: WindowHint] = [:]
    for window in header.windows { hints[window.id] = WindowHint(bundleID: window.bundle, title: window.title) }
    // The harness's clock starts here, so dormant workspaces are new.
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let bridge = ReplayWindowSystem()
    self.bridge = bridge
    harness = Harness(
      displays: header.displays.map { DisplaySnapshot($0) }, settings: header.settings,
      saved: PersistedState(
        workspaces: header.workspaces, hints: hints,
        dormant: header.dormant.mapValues { DormantWorkspace(workspace: $0, since: start) }
      ).written(with: header.displays.map { DisplaySnapshot($0) }),
      interpose: { fake in
        bridge.fake = fake
        fake.framePlan = header.framePlan
        return bridge
      })
    bridge.replayer = self
    otherStimuli = knownStimuli()
  }

  /// One entry per event or action recorded by name: take the arguments apart, bring the fake's world up to date, and call the
  /// method on `bridge.events` or `harness.overlays.actions`.
  ///
  private func knownStimuli() -> [String: @MainActor ([TraceJSON]) -> Void] {
    [
      "dragCancelled": { [unowned self] arguments in
        guard let id: WindowID = arguments.first?.decoded() else { return }
        resetEnforcement()
        gesture = nil
        fake.mouseDown = false
        bridge.events?.dragCancelled(id)
      },
      "windowReplaced": { [unowned self] arguments in
        guard arguments.count == 2, let old: WindowID = arguments[0].decoded(), let window: TraceWindow = arguments[1].decoded()
        else { return }
        resetEnforcement()
        // The old window still exists but is not shown, and nothing more is reported about it.
        fake.remove(old)
        recordedFrames[old] = nil
        recordedFrames[window.id] = window.frame
        let snapshot = WindowSnapshot(window)
        install(snapshot)
        bridge.events?.windowReplaced(old, by: snapshot)
      },
      "windowFound": { [unowned self] arguments in
        guard let window: TraceWindow = arguments.first?.decoded() else { return }
        resetEnforcement()
        recordedFrames[window.id] = window.frame
        let snapshot = WindowSnapshot(window)
        install(snapshot)
        bridge.events?.windowFound(snapshot)
      },
      "pointerPressed": { [bridge] _ in bridge.events?.pointerPressed() },
      "doubleClickReached": { [bridge] arguments in
        guard let id: WindowID = arguments.first?.decoded() else { return }
        bridge.events?.doubleClickReached(id)
      },
      // What follows depends on what macOS then said, which is in the trace as a read.
      "accessibilityWasRefused": { [bridge] _ in bridge.events?.accessibilityWasRefused() },
      "applicationActivated": { [unowned self] arguments in
        resetEnforcement()
        let name = arguments.count == 2 ? arguments[1].decoded(as: String.self) : nil
        bridge.events?.applicationActivated(name.map { FrontmostApp(bundleID: arguments[0].decoded(), name: $0) })
      },
      "shortcut": { [unowned self] arguments in
        let words = arguments.compactMap { $0.decoded(as: String.self) }
        guard words.count == 3, let chord = try? KeyChord(text: words[0]), let command = try? Command.parse(words[1]),
          let phase = KeyPhase(rawValue: words[2])
        else { return }
        resetEnforcement()
        if phase == .pressed { fake.hold(chord) } else { fake.letGo(chord) }
        // The command it runs, if any, follows as a nested line with its result.
        lastResult = harness.controller.shortcut(KeyBinding(chord, command), phase)
      },
      "settingsFileMayHaveChanged": { [unowned self] _ in harness.controller.settingsFileMayHaveChanged() },
      "callSignalsChanged": { [unowned self] arguments in
        let signals = arguments.compactMap { $0.decoded(as: Bool.self) }
        guard signals.count == 2 else { return }
        harness.controller.callSignalsChanged(CallSignals(cameraIsOn: signals[0], microphoneIsOn: signals[1]))
      },
      "finderChose": { [unowned self] arguments in
        guard let destination = arguments.first?.decoded(as: TraceFinderDestination.self)?.destination else { return }
        resetEnforcement()
        // The command a row runs follows as a nested line with its reply. Nobody hands this run's reply over, so the two are not held
        // against each other, and least of all the recorded one against the reply of the command before. What it did is.
        if case .command(let text) = destination {
          lastResult = nil
          // As for a command of the trace's own (`perform`): one that changes settings reads the file first, and finds what is in use.
          readsNewSettings = text == Command.reloadSettings.text
        }
        defer { readsNewSettings = true }
        harness.overlays.actions?.finderChose(destination)
      },
      "finderDismissed": { [unowned self] _ in harness.overlays.actions?.finderDismissed() },
      "peekOutlineClicked": { [unowned self] arguments in
        guard let display: DisplayID = arguments.first?.decoded() else { return }
        harness.overlays.actions?.peekOutlineClicked(display: display)
      },
      "cheatSheetDismissed": { [unowned self] _ in harness.overlays.actions?.cheatSheetDismissed() },
      "minimapClicked": { [unowned self] arguments in
        guard arguments.count == 3, let display: DisplayID = arguments[0].decoded(), let x: Double = arguments[1].decoded(),
          let y: Double = arguments[2].decoded()
        else { return }
        harness.overlays.actions?.minimapClicked(display: display, at: CGPoint(x: x, y: y))
      },
    ]
  }

  // MARK: Running

  /// Replays the whole trace. `expectations` is the text of the trace's `.expect` file, if it has one.
  @discardableResult
  public func run(expectations: String? = nil) -> Report {
    boot()
    for index in entries.indices { step(index) }
    finish()
    if let expectations { check(expectations) }
    return report
  }

  private func boot() {
    let header = trace.header
    for window in header.windows { install(WindowSnapshot(window)) }
    fake.focused = header.focused
    fake.cursor = header.cursor
    fake.mouseDown = header.mouseDown
    harness.controller.restore(from: header)
    harness.controller.loadSettings = { [weak self] in self?.settingsFile() ?? Settings() }
    // The Arbor that recorded this was watching its Accessibility permission (Controller+Permission.swift). The answers it got are in the trace.
    let wasWatching = entries.contains {
      if case .other(.read, "mayUseAccessibility", _, _) = $0.line { true } else { false }
    }
    if wasWatching {
      harness.controller.accessibilityProbe = { [weak self] _ in self?.answer(read: "mayUseAccessibility") ?? true }
    }
    harness.start()

    let seconds = entries.last.map { String(format: "%.1f", $0.t) } ?? "0"
    say("trace \(header.name): recorded \(header.recorded) by Arbor \(header.arbor) on \(header.os)")
    say("\(entries.count + 1) lines, \(seconds) s, replayed in \(mode.rawValue) mode")
    for warning in trace.warnings { say("warning: \(warning)") }
    for display in header.displays { say("display \(display)") }
    for window in header.windows {
      say("\(window.id) \(window)" + (harness.controller.filter.manages(WindowSnapshot(window)) ? "" : " (not arranged)"))
    }
    // Starting from the header should find everything where Arbor had left it.
    for window in header.windows {
      if let now = fake.frame(of: window.id), !now.approximatelyEquals(window.frame, tolerance: tolerance) {
        say("starting up moved \(window.id) from \(traceText(window.frame)) to \(traceText(now))")
      }
    }
    seenPreviews = harness.overlays.previewHistory.count
    draw()
    checkInvariants(atRest: false, line: 1)
  }

  private func step(_ index: Int) {
    let entry = entries[index]
    current = index
    advanceClock(to: entry.t)
    if entry.line.isStimulus, !entry.nested {
      draw()
      narrate(entry)
      deliver(entry, at: index)
    } else {
      narrate(entry)
      pass(entry)
    }
  }

  /// Runs scheduled work whose time has come, except work the trace says ran later.
  private func advanceClock(to time: Double) {
    phase = .reacting
    response = current..<current
    harness.scheduler.advance(
      to: time,
      holding: { [self] key, due in
        timerLines[key]?.contains { $0 >= current && entries[$0].t <= due + timerSlack } ?? false
      },
      willRun: { [self] key in
        if case .clock(let previous) = phase { endTimer(previous) }
        phase = .clock(key)
        framesSetThisStimulus = 0
        if verbose { say("                scheduled work `\(key)` runs by the clock; the trace does not have it") }
      })
    if case .clock(let last) = phase { endTimer(last) }
    phase = .reacting
  }

  // MARK: Delivering stimuli

  /// A real display's name never changes, so Arbor reads it when displays change and keeps it. What stands for it in a trace grows a mark
  /// when settings arrive with an entry of `displays` that goes by that name. The names Arbor was given during the reaction that is
  /// about to be replayed are put in place before it: until the settings are there, a mark more matches nothing more.
  private func adoptDisplayNames() {
    for index in response {
      guard case .displays(let recorded) = entries[index].line else { continue }
      var names: [DisplayID: String] = [:]
      for display in recorded where !display.name.isEmpty {
        guard let known = fake.displayList.firstIndex(where: { $0.id == display.id }) else { continue }
        fake.displayList[known].name = display.name
        names[display.id] = display.name
      }
      harness.controller.restoreDisplayNames(names)
    }
  }

  private func deliver(_ entry: TraceEntry, at index: Int) {
    phase = .reacting
    response = (index + 1)..<nextStimulus[index]
    framesSetThisStimulus = 0
    adoptDisplayNames()
    if case .focused(let id) = entry.line, let until = unaskedFocus[id], entry.t <= until {
      say("                not delivered: it answered a `focus \(id)` that Arbor no longer asks for")
      response = index..<index
      return
    }
    react(to: entry, at: index)
    // Events from inside a call the replayed Arbor no longer makes still happened.
    deliverNestedEvents(in: response)
    answerFocus()

    // Quitting is not a stimulus of its own: the app shuts the controller down after whatever made it quit. A pause has
    // stopped by itself, and shutting down after it would be quitting during the pause.
    if harness.controller.isRunning, response.contains(where: { entries[$0].line == .stop }) { harness.controller.shutdown() }

    comparePreviews()
    for missed in response where !consumed[missed] && isSystemEffect(entries[missed].line) {
      diverged(at: missed, "the recording has `\(entries[missed].line)`; Arbor no longer does that here")
    }
    if gesture == nil { checkInvariants(atRest: false, line: entry.number) }
  }

  /// macOS answers `focus(id)` with a focus event, unless the window had the focus already. That event is Arbor's own doing
  /// come back, as an echo is of `setFrame`, so it goes with the call and not with the clock: where the replayed Arbor no longer
  /// asks, the recorded answer is not delivered, and where it asks for something the recording does not have, the
  /// answer is made up. Otherwise a fix that consists of not focusing could never show in a replay, nor a new bug that
  /// consists of focusing.
  private func answerFocus() {
    for index in response where !consumed[index] {
      if case .focus(let id) = entries[index].line { unaskedFocus[id] = entries[index].t + focusAnswerWindow }
    }
    // Each answer can make Arbor ask again; it settles because a window that has the focus gets no answer.
    var rounds = 0
    while !newlyAskedFocus.isEmpty, rounds < 5 {
      rounds += 1
      let id = newlyAskedFocus.removeFirst()
      guard fake.frame(of: id) != nil else { continue }
      say("                macOS would answer the new `focus \(id)`: \(id) focused")
      bridge.events?.windowFocused(id)
    }
    newlyAskedFocus = []
  }

  /// Events that arrived while Arbor was inside a call (a window system may report from within `focus` or `setFrame`;
  /// the fakes do) are delivered from inside the same call of the replay, so that Arbor meets them in the same state.
  private func deliverNestedEvents(in range: Range<Int>) {
    for index in range.clamped(to: response) where !consumed[index] && entries[index].nested && entries[index].line.isEvent {
      consumed[index] = true
      react(to: entries[index], at: index)
    }
  }

  /// The nested events right after the line at `index`, each with whatever Arbor does about it.
  private func deliverNestedEvents(after index: Int) {
    var next = index + 1
    while next < response.upperBound {
      if consumed[next] {
        next += 1
      } else if entries[next].nested, entries[next].line.isEvent {
        consumed[next] = true
        react(to: entries[next], at: next)
        next += 1
      } else {
        return
      }
    }
  }

  private func react(to entry: TraceEntry, at index: Int) {
    report.delivered += 1
    let events = bridge.events

    switch entry.line {
    case .appeared(let window):
      resetEnforcement()
      recordedFrames[window.id] = window.frame
      let snapshot = WindowSnapshot(window)
      install(snapshot)
      events?.windowAppeared(snapshot)

    case .destroyed(let id):
      resetEnforcement()
      recordedFrames[id] = nil
      placed[id] = nil
      if gesture == id { gesture = nil }
      fake.remove(id)
      events?.windowDestroyed(id)

    case .changed(let window, let user):
      let snapshot = translated(window)
      install(snapshot)
      events?.windowChanged(snapshot, userInitiated: user)

    case .focused(let id):
      // The keyboard really went somewhere, so what was not asked for no longer matters.
      unaskedFocus = [:]
      fake.focused = id
      events?.windowFocused(id)

    case .dragBegan(let id, let point):
      gesture = id
      fake.cursor = point
      fake.mouseDown = true
      events?.dragBegan(id, at: point)

    case .dragMoved(let id, let point):
      fake.cursor = point
      events?.dragMoved(id, to: point)

    case .dragEnded(let id, let point):
      resetEnforcement()
      gesture = nil
      fake.cursor = point
      fake.mouseDown = false
      events?.dragEnded(id, at: point)

    case .resizeBegan(let id):
      gesture = id
      fake.mouseDown = true
      events?.resizeBegan(id)

    case .resizeEnded(let id):
      resetEnforcement()
      gesture = nil
      fake.mouseDown = false
      events?.resizeEnded(id)

    case .displaysChanged(let displays):
      resetEnforcement()
      fake.displayList = displays.map { DisplaySnapshot($0) }
      // macOS moves windows itself when the displays change, and when another display becomes the main one every window has new
      // coordinates. No app says so: Arbor reads every frame anew, and the recording has what it read. Carried over like any move
      // that came from outside Arbor (`translated`).
      let answers = entries[min(index + 1, response.upperBound)..<response.upperBound]
      if case .allWindows(let read)? = answers.first(where: { if case .allWindows = $0.line { true } else { false } })?.line {
        for window in read where fake.frame(of: window.id) != nil { fake.moveSilently(window.id, to: translated(window).frame) }
      }
      events?.displaysChanged()

    case .command(let text, let source):
      resetEnforcement()
      perform(text, from: source, at: index)

    case .tileActivated(let display, let node):
      resetEnforcement()
      harness.overlays.clickTile(node, on: display)

    case .seamDragged(let display, let seam, let delta):
      resetEnforcement()
      harness.overlays.dragSeam(seam, by: delta, on: display)

    case .timer(let key):
      let ran = harness.scheduler.fire(key)
      // Work that did nothing visible in the recording (a save, say) is not missed.
      if !ran, response.contains(where: { entries[$0].line.isEffect }) {
        diverged(at: index, "the recording ran scheduled work `\(key)` here; Arbor now has none under that name")
      }
      endTimer(key)

    case .settings(let settings):
      resetEnforcement()
      harness.controller.apply(settings: settings)

    case .keyboardFocusMoved:
      events?.keyboardFocusMoved()

    case .other(_, let name, let arguments, _):
      if let deliver = otherStimuli[name] {
        deliver(arguments)
      } else {
        report.delivered -= 1
        say("                not delivered: this Arbor does not know `\(name)`")
      }

    default:
      break
    }
  }

  /// Stands in for settings.json, which a replay does not have. What Arbor read from it and applied is a line of the reaction.
  private func settingsFile() -> Settings {
    if readsNewSettings {
      for line in response.map({ entries[$0].line }) {
        if case .settings(let settings) = line { return settings }
      }
    }
    return harness.controller.settings
  }

  private func perform(_ text: String, from source: CommandSource?, at index: Int) {
    let command: Command
    do {
      command = try Command.parse(text)
    } catch {
      lastResult = nil
      diverged(at: index, "Arbor no longer understands `\(text)`: \(error)")
      return
    }
    // Every command that changes settings reads the file first, and finds what is in use (what it then applies is
    // its own doing). `reload-settings` is there to find something else.
    readsNewSettings = command == .reloadSettings
    defer { readsNewSettings = true }
    lastResult = source.map { harness.controller.perform(command, from: $0) } ?? harness.controller.perform(command)
  }

  /// A recorded snapshot carries the frame the window had in the recording. If that is where it already was in
  /// the recording, the event is not about the window moving (it is an echo of a frame Arbor set, or a new
  /// title, or a flag), so in the replay the window stays where the replayed Arbor put it. Only moves that
  /// came from outside Arbor are carried over. Without a divergence the two frames are the same anyway.
  private func translated(_ window: TraceWindow) -> WindowSnapshot {
    var snapshot = WindowSnapshot(window)
    if let before = recordedFrames[window.id], before.approximatelyEquals(window.frame, tolerance: 0.5),
      let now = fake.frame(of: window.id)
    {
      snapshot.frame = now
    }
    recordedFrames[window.id] = window.frame
    return snapshot
  }

  private func install(_ snapshot: WindowSnapshot) {
    fake.install(snapshot)
    if recordedFrames[snapshot.id] == nil { recordedFrames[snapshot.id] = snapshot.frame }
    fake.setMinimumSize(snapshot.id, minimumSizes[snapshot.id] ?? .zero)
    fake.setMaximumSize(snapshot.id, maximumSizes[snapshot.id])
  }

  // MARK: Lines that are not delivered

  /// Keeps the picture of the recorded world up to date, which is also the model's fallback for reads.
  private func pass(_ entry: TraceEntry) {
    switch entry.line {
    case .setFrame(let id, _, let result?, _): recordedFrames[id] = result
    // Arbor no longer asks here. The windows moved all the same.
    case .allWindows(let recorded): if !consumed[current] { hear(ofAll: recorded) }
    case .cursorLocation(let point): fake.cursor = point
    case .isMouseButtonDown(let down): fake.mouseDown = down
    case .focusedWindow(let id): if !isUnasked(id) { fake.focused = id }
    case .raw(let text):
      // `leftMouseDown 360,92`: the button and the pointer, whether or not Arbor made anything of it.
      let words = text.split(separator: " ")
      guard words.count == 2, words[0].hasPrefix("leftMouse") else { break }
      fake.mouseDown = words[0] != "leftMouseUp"
      let numbers = words[1].split(separator: ",").compactMap { Double($0) }
      if numbers.count == 2 { fake.cursor = CGPoint(x: numbers[0], y: numbers[1]) }
    case .done(let text, let ok, let message):
      // What `doctor` finds is about the Mac it ran on (switches, taps, other apps), of which a trace holds nothing.
      guard let result = lastResult, mode == .strict, text != "doctor" else { break }
      if result.ok != ok || (result.message != message && !message.hasPrefix(TraceLine.aboutMark)) {
        diverged(
          at: current,
          "`\(text)` \(ok ? "succeeded" : "failed") with \"\(message)\" in the recording; "
            + "now it \(result.ok ? "succeeds" : "fails") with \"\(result.message)\"")
      }
    default: break
    }
  }

  // MARK: Answering the controller

  fileprivate func setFrame(_ frame: CGRect, of id: WindowID) -> CGRect? {
    let before = fake.frame(of: id)
    let result = answerSetFrame(frame, of: id)
    did(.setFrame(id, asked: frame, from: before, took: result))
    noteRefusal(of: frame, by: id, took: result)
    return result
  }

  private func did(_ what: Deed.What) {
    var (atStart, index) = (false, current)
    switch phase {
    case .boot: atStart = true
    // `current` is the line whose time the clock is being moved to. It has not happened yet.
    case .clock: index = current - 1
    case .reacting, .drain: break
    }
    report.deeds.append(
      Deed(what: what, line: entries.indices.contains(index) ? entries[index].number : 1, t: harness.scheduler.now, atStart: atStart))
  }

  /// An app may refuse a frame, and Arbor may try again when something has changed. Trying again and again with nothing changed
  /// costs time at every layout and can never work.
  private func noteRefusal(of request: CGRect, by id: WindowID, took result: CGRect?) {
    guard isReplaying, let result, !result.approximatelyEquals(request, tolerance: 2) else {
      refusals[id] = nil
      return
    }
    if let last = refusals[id], last.request.approximatelyEquals(request, tolerance: tolerance),
      last.result.approximatelyEquals(result, tolerance: tolerance)
    {
      refusals[id] = (request, result, last.count + 1)
    } else {
      refusals[id] = (request, result, 1)
    }
    if refusals[id]?.count == futileLimit {
      add(
        Problem(
          kind: .invariant, line: entries.indices.contains(current) ? entries[current].number : 1,
          text: "asking in vain: \(id) was asked for \(traceText(request)) \(futileLimit) times in a row and took \(traceText(result)) every time"))
    }
  }

  private func answerSetFrame(_ frame: CGRect, of id: WindowID) -> CGRect? {
    framesSetThisStimulus += 1
    let match = matchEffect("setFrame \(id) \(traceText(frame))") { [tolerance] line in
      if case .setFrame(id, let request, _, _) = line { return request.approximatelyEquals(frame, tolerance: tolerance) }
      return false
    }
    if let match, case .setFrame(_, _, let result, _) = entries[match].line {
      report.answeredFromTrace += 1
      guard let result, fake.frame(of: id) != nil else { return nil }
      let placed = place(id, at: result)
      // The line is written when the call returns, so what came from inside it stands before it.
      deliverNestedEvents(in: response.lowerBound..<match)
      return placed
    }
    guard fake.frame(of: id) != nil else { return nil }
    // The same request at another moment: an app's answer depends on the request far more than on the time.
    let same = remembered[id]?.filter { $0.request.approximatelyEquals(frame, tolerance: tolerance) }
    if let nearest = same?.min(by: { abs($0.index - current) < abs($1.index - current) }) {
      report.answeredFromTrace += 1
      return place(id, at: nearest.result)
    }
    // The same size somewhere else: how large an app lets a window be does not depend on where it stands.
    let sameSize = remembered[id]?.filter {
      abs($0.request.width - frame.width) <= tolerance && abs($0.request.height - frame.height) <= tolerance
    }
    if let nearest = sameSize?.min(by: { abs($0.index - current) < abs($1.index - current) }) {
      report.answeredFromTrace += 1
      let titleBar = fake.windows[id]?.titleBar ?? FakeWindowSystem.usualTitleBar
      return place(id, at: fake.whereMacOSPuts(CGRect(origin: frame.origin, size: nearest.result.size), titleBar: titleBar))
    }
    report.answeredByModel += 1
    var frame = frame
    if let steps = widthSteps[id] { frame.size.width = steps.nearest(to: frame.width) }
    if let steps = heightSteps[id] { frame.size.height = steps.nearest(to: frame.height) }
    let result = fake.setFrame(frame, of: id)
    placed[id] = result
    return result
  }

  private func place(_ id: WindowID, at frame: CGRect) -> CGRect {
    fake.place(id, at: frame)
    placed[id] = frame
    return frame
  }

  fileprivate func focus(_ id: WindowID) {
    did(.focus(id))
    let match = matchEffect("focus \(id)") { $0 == .focus(id) }
    if match == nil, fake.focused != id, isReplaying { newlyAskedFocus.append(id) }
    unaskedFocus[id] = nil
    fake.focus(id)
    // The line is written before the call is made, so what came from inside it stands after it.
    if let match { deliverNestedEvents(after: match) }
  }

  /// When displays change macOS moves windows without a notification for each, and Arbor reads every frame afresh. What it read then is the only sign
  /// of those moves, so the world is brought up to it before the question is answered. As with an event: a window that lies where it already lay in the
  /// recording stays where the replayed Arbor put it. A window no event has told of is not made up here.
  fileprivate func allWindows() -> [WindowSnapshot] {
    for index in unconsumedResponse() {
      if case .allWindows(let recorded) = entries[index].line {
        consumed[index] = true
        hear(ofAll: recorded)
        break
      }
    }
    return fake.allWindows()
  }

  private func hear(ofAll recorded: [TraceWindow]) {
    for window in recorded where fake.frame(of: window.id) != nil { install(translated(window)) }
  }

  fileprivate func focusedWindow() -> WindowID? {
    for index in unconsumedResponse() {
      if case .focusedWindow(let id) = entries[index].line {
        consumed[index] = true
        if !isUnasked(id) { fake.focused = id }
        break
      }
    }
    return fake.focused
  }

  /// macOS has other displays before Arbor is told of them (`DisplayChange` waits until they have settled), and Arbor asks in
  /// between: whether what apps say of their windows can be read yet, and before it lets go.
  fileprivate func displays() -> [DisplaySnapshot] {
    for index in unconsumedResponse() {
      if case .displays(let recorded) = entries[index].line {
        consumed[index] = true
        fake.displayList = recorded.map { DisplaySnapshot($0) }
        break
      }
    }
    return fake.displayList
  }

  fileprivate func cursorLocation() -> CGPoint {
    for index in unconsumedResponse() {
      if case .cursorLocation(let point) = entries[index].line {
        consumed[index] = true
        fake.cursor = point
        break
      }
    }
    return fake.cursor
  }

  fileprivate func isMouseButtonDown() -> Bool {
    for index in unconsumedResponse() {
      if case .isMouseButtonDown(let down) = entries[index].line {
        consumed[index] = true
        fake.mouseDown = down
        break
      }
    }
    return fake.mouseDown
  }

  /// The recording says this window has the focus, but only because the recorded Arbor asked for that.
  private func isUnasked(_ id: WindowID?) -> Bool {
    guard let id, let until = unaskedFocus[id] else { return false }
    return entries.indices.contains(current) && entries[current].t <= until
  }

  /// Between the start and the last line, where macOS's answers can still be delivered.
  private var isReplaying: Bool {
    switch phase {
    case .reacting, .clock: true
    case .boot, .drain: false
    }
  }

  /// For `ReplayWindowSystem`: the recorded answer to a question that `TraceLine` has no case for, or nil to ask the fake.
  ///
  ///     func isHolding(_ chord: KeyChord) -> Bool { replayer?.answer(read: "isHolding") ?? fake?.isHolding(chord) ?? true }
  ///
  /// With `about`, only an answer to the question with those arguments: of two windows asked after one stimulus each gets its own.
  public func answer<T: Decodable>(read name: String, about arguments: [any Encodable]? = nil, as type: T.Type = T.self) -> T? {
    let wanted = arguments?.map { TraceJSON(encoding: $0) }
    for index in unconsumedResponse() {
      if case .other(.read, name, let asked, let result?) = entries[index].line, wanted == nil || wanted == asked {
        consumed[index] = true
        return result.decoded()
      }
    }
    return nil
  }

  /// For `ReplayWindowSystem`: Arbor is making a call that `TraceLine` has no case for. Finds the recorded one (in strict mode it must be
  /// there, with the same arguments) and returns its result, if it has one.
  ///
  ///     func raise(_ window: WindowID) { replayer?.answer(call: "raise", [window]); fake?.raise(window) }
  ///     func launchApp(_ name: String) -> Bool { replayer?.answer(call: "launchApp", [name])?.decoded() ?? fake?.launchApp(name) ?? false }
  @discardableResult
  public func answer(call name: String, _ arguments: [any Encodable] = []) -> TraceJSON? {
    let arguments = arguments.map { TraceJSON(encoding: $0) }
    let line = TraceLine.other(.call, name, arguments: arguments)
    did(.call(line.description))
    let match = matchEffect(line.description) {
      if case .other(.call, name, arguments, _) = $0 { return true }
      return false
    }
    guard let match, case .other(_, _, _, let result) = entries[match].line else { return nil }
    // With a result the line was written when the call returned, without one before it was made.
    if result == nil { deliverNestedEvents(after: match) } else { deliverNestedEvents(in: response.lowerBound..<match) }
    return result
  }

  private func unconsumedResponse() -> [Int] {
    guard case .reacting = phase else { return [] }
    return response.filter { !consumed[$0] }
  }

  /// Previews go to the overlays, not the window system, and are compared separately.
  private func isSystemEffect(_ line: TraceLine) -> Bool {
    if case .showDropPreview = line { return false }
    return line.isEffect
  }

  /// Finds the recorded line for a call the controller is making, and marks it as used.
  private func matchEffect(_ text: String, _ isSame: (TraceLine) -> Bool) -> Int? {
    switch phase {
    case .boot, .drain:
      return nil
    case .clock(let key):
      diverged(at: current, "Arbor now does `\(text)` from scheduled work `\(key)`, which did not run here in the recording")
      return nil
    case .reacting:
      break
    }
    let open = response.filter { !consumed[$0] && isSystemEffect(entries[$0].line) }
    if let first = open.first, isSame(entries[first].line) {
      consumed[first] = true
      return first
    }
    if let later = open.first(where: { isSame(entries[$0].line) }) {
      diverged(at: later, "Arbor now does `\(text)` before `\(entries[open[0]].line)`; the recording has them the other way round")
      consumed[later] = true
      return later
    }
    if let first = open.first {
      diverged(at: first, "the recording has `\(entries[first].line)`; Arbor now does `\(text)`")
    } else {
      diverged(at: max(response.lowerBound - 1, 0), "Arbor now does `\(text)`; the recording has no such call here")
    }
    return nil
  }

  private func comparePreviews() {
    let shown = harness.overlays.previewHistory.dropFirst(seenPreviews)
    seenPreviews = harness.overlays.previewHistory.count
    guard mode == .strict else { return }
    let recorded = response.filter {
      if case .showDropPreview = entries[$0].line { return true }
      return false
    }
    for (index, frame) in zip(recorded, shown) {
      guard case .showDropPreview(let expected) = entries[index].line else { continue }
      let same =
        switch (expected, frame) {
        case (nil, nil): true
        case (let a?, let b?): a.approximatelyEquals(b, tolerance: tolerance)
        default: false
        }
      if !same {
        diverged(at: index, "the recording has `\(entries[index].line)`; Arbor now does `\(TraceLine.showDropPreview(frame))`")
      }
    }
    if recorded.count != shown.count {
      diverged(
        at: recorded.last ?? max(response.lowerBound - 1, 0),
        "the recording changes the drop preview \(recorded.count) time(s) here, Arbor now \(shown.count)")
    }
  }

  // MARK: Problems

  private func diverged(at index: Int, _ text: String) {
    guard mode == .strict else { return }
    add(Problem(kind: .divergence, line: entries.indices.contains(index) ? entries[index].number : 1, text: text))
  }

  private func add(_ problem: Problem) {
    guard report.problems.count < problemLimit, !report.problems.contains(problem) else { return }
    report.problems.append(problem)
    say("     ✘ \(problem)")
  }

  private func checkInvariants(atRest: Bool, line: Int) {
    guard !silent else { return }
    var broken = ReplayInvariants.always(harness)
    if atRest { broken += ReplayInvariants.atRest(harness, placed: placed) }
    for text in broken { add(Problem(kind: .invariant, line: line, text: text)) }
  }

  private func resetEnforcement() { enforcementStreaks = [:] }

  /// Scheduled work has run. Arbor puts back docked windows that something else moved; an app that moves its
  /// window again every time would keep that going for ever.
  private func endTimer(_ key: String) {
    guard key.hasPrefix("enforce-"), framesSetThisStimulus > 0 else { return }
    framesSetThisStimulus = 0
    enforcementStreaks[key, default: 0] += 1
    if enforcementStreaks[key] == enforcementLimit {
      add(
        Problem(
          kind: .invariant, line: entries.indices.contains(current) ? entries[current].number : 1,
          text: "endless enforcement: `\(key)` has put windows back \(enforcementLimit) times in a row with "
            + "nothing in between but windows changing"))
    }
  }

  // MARK: The end

  private func finish() {
    current = max(entries.count - 1, 0)
    draw()
    phase = .drain
    // Let what is still scheduled run (put-backs, saves), as it would have had recording gone on.
    harness.scheduler.advance(to: harness.scheduler.now + 2, holding: { _, _ in false })
    draw()
    let line = entries.last?.number ?? 1
    if let gesture {
      say("the trace ends while \(gesture) is being dragged or resized, so where windows ended up is not checked")
      checkInvariants(atRest: false, line: line)
    } else {
      checkInvariants(atRest: true, line: line)
    }
  }

  /// Checks the lines of an `.expect` file against the final state. They are arbor-sim's `expect` forms, with or
  /// without the word `expect`, and one form of their own: `problem <text>` says that the replay is known to
  /// report a problem containing that text. It takes those problems off the list, and fails once there
  /// are none, so that a trace of a bug nobody has fixed yet can be committed and says when it is fixed.
  private func check(_ expectations: String) {
    let line = entries.last?.number ?? 1
    guard !fake.displayList.isEmpty, harness.controller.workspaces[harness.display] != nil else {
      add(Problem(kind: .expectation, line: line, text: "the trace ends without a display, so there is nothing to expect anything of"))
      return
    }
    for raw in expectations.split(separator: "\n") {
      var words = raw.split(separator: " ").map(String.init)
      if words.first == "expect" { words.removeFirst() }
      guard let first = words.first, !first.hasPrefix("#") else { continue }
      if first == "problem" {
        let text = words.dropFirst().joined(separator: " ")
        let before = report.problems.count
        report.problems.removeAll { $0.description.contains(text) }
        if report.problems.count == before {
          add(Problem(kind: .expectation, line: line, text: "no problem containing \"\(text)\" was reported; if it is fixed, delete that line"))
        } else {
          say("known problem: \(text)")
        }
        continue
      }
      let failure =
        Self.courseVerbs.contains(first.lowercased())
        ? checkCourse(words) : ScenarioExpectation.check(words, harness: harness, lastCommandOK: lastResult?.ok ?? true)
      if let failure { add(Problem(kind: .expectation, line: line, text: "`\(words.joined(separator: " "))`: \(failure)")) }
    }
  }

  // MARK: What Arbor did on the way

  /// The forms of an `.expect` file that are about the course of a replay and not about its end (docs/TRACES.md, "Expectations").
  public static let courseForms =
    "moved <id> <n> [at <line>[?]…] [since <words of a remark>], frame <id> <x> <y> <w> <h>, asked-focus <id>…|none [since <words of a remark>]"
  static let courseVerbs: Set = ["moved", "frame", "asked-focus"]

  /// The deeds from the first remark that contains `words` on; all but those of the start if there are no words; nil if no remark does.
  private func deeds(since words: ArraySlice<String>) -> [Deed]? {
    let course = report.deeds.filter { !$0.atStart }
    guard !words.isEmpty else { return course }
    let sought = words.joined(separator: " ").lowercased()
    let remark = entries.first {
      if case .note(let text) = $0.line { text.lowercased().contains(sought) } else { false }
    }
    return remark.map { remark in course.filter { $0.line >= remark.number } }
  }

  /// Every time `id` changed on the screen, in order, and whether that was a question: a window Arbor does not know well enough is
  /// asked for a size where it stands and then goes to its place once (Controller+AskFirst.swift). As `Budget.tally` has it: a question
  /// leaves the window where it stands, comes before any move in answer to the same thing, and counts as one only if the window then
  /// goes somewhere. A resize that was all there was to do is a move like any other. "Where it stands" is to the tolerance the road is
  /// judged with: macOS nudges a window that grows in the parking place up by a few points.
  public static func changes(of id: WindowID, in course: [Deed]) -> [(deed: Deed, isQuestion: Bool)] {
    let seen = course.filter { $0.moved == id }
    var isQuestion = [Bool](repeating: false, count: seen.count)
    for index in seen.indices.dropLast() where seen[index + 1].line == seen[index].line {
      guard index == 0 || seen[index - 1].line != seen[index].line || isQuestion[index - 1] else { continue }
      guard case .setFrame(_, _, let from?, let took?) = seen[index].what else { continue }
      isQuestion[index] = FakeWindowSystem.changesOfPlace([from, took]) == 0
    }
    return zip(seen, isQuestion).map { ($0, $1) }
  }

  private static func atWords(_ changes: [(deed: Deed, isQuestion: Bool)]) -> [String] {
    changes.map { "\($0.deed.line)" + ($0.isQuestion ? "?" : "") }
  }

  /// `moved <id> <n> [at <line>[?]…]` held against a course. Apart from a replay, so that it can be tried on deeds that no controller of the day need do:
  /// when Arbor asks is its own business, and changes.
  public static func problem(withMoved own: [String], in course: [Deed]) -> String? {
    let usage = "cannot read `\(own.joined(separator: " "))`; the forms are: \(courseForms)"
    guard own.count == 3 || own.count >= 5 else { return usage }
    guard let id = WindowID(word: own[1]), let expected = Int(own[2]) else { return usage }
    let changes = Self.changes(of: id, in: course)
    let moves = changes.filter { !$0.isQuestion }
    guard moves.count == expected else {
      return "Arbor moved \(id) \(moves.count) time(s), not \(expected)" + changes.map { "; line \($0.deed.line): \($0.deed)" }.joined()
    }
    guard own.count > 3 else { return nil }
    // In answer to what: a window that is put in its place only after it has been seen somewhere else has also moved once.
    // Questions are no moves, and a person sees them all the same: the list holds them too, each with its mark.
    let lines = Array(own.dropFirst(4))
    guard own[3] == "at", lines.allSatisfy({ Int($0.hasSuffix("?") ? String($0.dropLast()) : $0) != nil }),
      lines.filter({ !$0.hasSuffix("?") }).count == expected
    else { return usage }
    if Self.atWords(changes) == lines { return nil }
    return "Arbor moved \(id) at line \(Self.atWords(changes).joined(separator: ", ")) of the trace, not at \(lines.joined(separator: ", "))"
  }

  private func checkCourse(_ words: [String]) -> String? {
    let usage = "cannot read `\(words.joined(separator: " "))`; the forms are: \(Self.courseForms)"
    let since = words.firstIndex(of: "since")
    let own = words[..<(since ?? words.endIndex)]
    guard let course = deeds(since: since.map { words[($0 + 1)...] } ?? []) else {
      return "no remark in the trace contains “\(words[(since! + 1)...].joined(separator: " "))”"
    }
    switch (own.first?.lowercased(), own.count) {
    case ("moved", 3), ("moved", 5...):
      return Self.problem(withMoved: Array(own), in: course)

    case ("frame", 6) where since == nil:
      let numbers = own.dropFirst(2).compactMap { Double($0) }
      guard let id = WindowID(word: own[1]), numbers.count == 4 else { return usage }
      let expected = CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
      guard let frame = fake.frame(of: id) else { return "there is no window \(id)" }
      return frame.approximatelyEquals(expected, tolerance: 1) ? nil : "\(id) is at \(traceText(frame)), not \(traceText(expected))"

    case ("asked-focus", 2...):
      let expected = own.dropFirst().map { $0.lowercased() } == ["none"] ? [] : own.dropFirst().map { WindowID(word: $0) }
      guard !expected.contains(nil) else { return usage }
      let asked = Self.focusAsked(in: course)
      if asked == expected.compactMap({ $0 }) { return nil }
      return "Arbor asked for the keyboard for \(asked.isEmpty ? "no window" : asked.map { "\($0)" }.joined(separator: " "))"

    default:
      return usage
    }
  }

  /// The windows Arbor asked the keyboard for, in order. Asking again for the one it asked for last is one wish.
  public static func focusAsked(in deeds: [Deed]) -> [WindowID] {
    var asked: [WindowID] = []
    for case .focus(let id) in deeds.map(\.what) where asked.last != id { asked.append(id) }
    return asked
  }

  /// Lines for an `.expect` file that say what Arbor did in this replay and how it ended: for every window it arranges how often it was
  /// moved, where it is and in what state; who was asked to take the keyboard and who has it; what the view is on. Call it after `run`.
  /// scripts/trace-to-test.py writes them beside a trace, where they hold today's behaviour in place.
  public func expectationsFromThisReplay() -> [String] {
    let controller = harness.controller
    guard !fake.displayList.isEmpty, let workspace = controller.workspaces[harness.display] else { return [] }
    let course = report.deeds.filter { !$0.atStart }
    var lines: [String] = []
    // After a pause or a quit, which end a trace, Arbor arranges nothing any more. Where it left the windows is the whole point.
    let isLooking = controller.isRunning
    let windows = fake.windows.values.map(\.snapshot).filter { controller.filter.manages($0) }.map(\.id).sorted()
    for id in windows where !isLooking || controller.workspaceID(containing: id) != nil {
      let changes = Self.changes(of: id, in: course)
      lines.append(
        "moved \(id.rawValue) \(changes.filter { !$0.isQuestion }.count)" + (changes.isEmpty ? "" : " at " + Self.atWords(changes).joined(separator: " ")))
      if gesture != id, let frame = fake.frame(of: id) {
        lines.append("frame \(id.rawValue) \([frame.minX, frame.minY, frame.width, frame.height].map { traceText($0) }.joined(separator: " "))")
      }
      guard isLooking else { continue }
      // Whichever of each pair holds: a window that is minimized is neither in view nor kept out of it.
      for words in [["docked"], ["floating"], ["visible"], ["hidden"], ["tile"], ["pinned"]].map({ $0 + ["\(id.rawValue)"] })
      where ScenarioExpectation.check(words, harness: harness, lastCommandOK: true) == nil {
        lines.append(words.joined(separator: " "))
      }
    }
    let asked = Self.focusAsked(in: course)
    lines.append("asked-focus " + (asked.isEmpty ? "none" : asked.map { "\($0.rawValue)" }.joined(separator: " ")))
    if let focused = fake.focused { lines.append("focused \(focused.rawValue)") }
    guard isLooking else { return lines }
    if workspace.camera == workspace.tree.root {
      lines.append("camera root")
    } else if workspace.camera == workspace.tree.desktop {
      lines.append("camera desktop")
    } else if let window = workspace.tree.allWindows.sorted().first(where: { workspace.tree.leaf(containing: $0) == workspace.camera }) {
      lines.append("camera \(window.rawValue)")
    }
    return lines
  }

  // MARK: The story

  private func say(_ text: @autoclosure () -> String) { if !silent { report.story.append(text()) } }

  /// Pointer moves, frames on the way and reads are most of a trace and little of its story.
  private func isQuiet(_ entry: TraceEntry) -> Bool {
    switch entry.line {
    case .dragMoved, .cursorLocation, .isMouseButtonDown, .focusedWindow, .raw, .other(.read, _, _, _): true
    case .changed(let window, _): window.id == gesture
    case .timer(let key): key == "save" || key == "accessibility"
    default: false
    }
  }

  private func narrate(_ entry: TraceEntry) {
    guard !silent else { return }
    if !verbose, isQuiet(entry) {
      quietLines += 1
      return
    }
    flushQuietLines()
    let stamp = String(format: "%5ld %8.3f  ", entry.number, entry.t)
    if case .note(let text) = entry.line {
      say(stamp + "# " + text)
    } else if entry.line.isStimulus, !entry.nested {
      say(stamp + entry.line.description)
    } else {
      say(stamp + "    " + entry.line.description)
    }
  }

  private func flushQuietLines() {
    if quietLines > 0 { say("                … \(quietLines) line(s): pointer moves, frames on the way, reads, saves, what macOS sent") }
    quietLines = 0
  }

  /// Draws the layout if it has changed since it was last drawn. Not in the middle of a drag, where
  /// every move would be a drawing.
  private func draw() {
    guard gesture == nil, !silent else { return }
    let drawing = harness.ascii(columns: 64, rows: 16)
    guard drawing != lastDrawing else { return }
    lastDrawing = drawing
    flushQuietLines()
    say(drawing)
  }
}

/// Sizes that come in steps: a terminal is as wide as its margins and a whole number of characters, and takes the size nearest to the
/// one it is asked for, which half the time is the larger one. Read as "it has a minimum size", that would make a replayed
/// terminal refuse every smaller request too, which a real one does not.
///
/// The step is not recorded anywhere, but every size the window was ever seen at lies on the same grid, so it is the greatest
/// common divisor of their differences.
struct SizeSteps {
  struct Evidence {
    var seen: Set<Int> = []
    /// What the window took minus what it was asked for, each time.
    var misses: [CGFloat] = []
  }

  /// No step is larger than this: character cells at a very large font.
  static let largest = Int(Cells.largest)

  var base: Int
  var step: Int

  /// Nil unless the window missed a request by a little at least once, and its sizes do lie on a grid coarser than two
  /// points. Windows that take what they are asked for are seen at all sorts of sizes, which have no such divisor.
  init?(_ evidence: Evidence) {
    guard evidence.misses.contains(where: { abs($0) > 2 && abs($0) <= CGFloat(Self.largest) }), let base = evidence.seen.min()
    else { return nil }
    var divisor = 0
    for size in evidence.seen {
      var (a, b) = (divisor, size - base)
      while b != 0 { (a, b) = (b, a % b) }
      divisor = a
    }
    guard (3...Self.largest).contains(divisor) else { return nil }
    self.base = base
    step = divisor
  }

  /// Whether a window that missed a request by this much only rounded.
  func explains(_ miss: CGFloat) -> Bool { abs(miss) <= CGFloat(step) }

  func nearest(to length: CGFloat) -> CGFloat {
    CGFloat(base) + ((length - CGFloat(base)) / CGFloat(step)).rounded() * CGFloat(step)
  }
}

/// Stands between the controller and the fake window system during a replay and lets the replayer answer. The
/// fake gets no `events`, so it stays silent: every event in a replay comes from the trace.
@MainActor
private final class ReplayWindowSystem: WindowSystem {
  weak var events: (any WindowSystemEvents)?
  var fake: FakeWindowSystem?
  weak var replayer: TraceReplayer?

  func start() { fake?.start() }
  func stop() { fake?.stop() }
  func allWindows() -> [WindowSnapshot] { replayer?.allWindows() ?? fake?.allWindows() ?? [] }
  func displays() -> [DisplaySnapshot] { replayer?.displays() ?? [] }
  func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? { replayer?.setFrame(frame, of: window) }
  func focus(_ window: WindowID) { replayer?.focus(window) }
  func focusedWindow() -> WindowID? { replayer?.focusedWindow() }
  func cursorLocation() -> CGPoint { replayer?.cursorLocation() ?? .zero }
  func isMouseButtonDown() -> Bool { replayer?.isMouseButtonDown() ?? false }
  func existingWindowIDs() -> Set<WindowID> {
    replayer?.answer(read: "existingWindowIDs", as: [WindowID].self).map(Set.init) ?? fake?.existingWindowIDs() ?? []
  }
  func inputActivity() -> InputActivity {
    replayer?.answer(read: "inputActivity", as: TraceInputActivity.self)?.activity ?? fake?.inputActivity()
      ?? InputActivity(pointerIdle: 0, keyboardIdle: .infinity, keyPresses: 0)
  }
  func isHolding(_ chord: KeyChord) -> Bool { replayer?.answer(read: "isHolding") ?? fake?.isHolding(chord) ?? true }
  func secondsSinceClickOrModifierKey() -> Double {
    replayer?.answer(read: "secondsSinceClickOrModifierKey") ?? fake?.secondsSinceClickOrModifierKey() ?? .infinity
  }
  func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) {
    replayer?.answer(call: "leaveStrayDialogs", [leave, inUse])
    fake?.leaveStrayDialogs(leave, exceptOfApp: inUse)
  }
  func bringInStrayDialogs(ofApp bundleID: String?) {
    replayer?.answer(call: "bringInStrayDialogs", [bundleID])
    fake?.bringInStrayDialogs(ofApp: bundleID)
  }
  func strayDialogsWaiting() -> Int { replayer?.answer(read: "strayDialogsWaiting") ?? fake?.strayDialogsWaiting() ?? 0 }
  func raise(_ window: WindowID) {
    replayer?.answer(call: "raise", [window])
    fake?.raise(window)
  }
  func windowsFrontToBack() -> [WindowID] { replayer?.answer(read: "windowsFrontToBack") ?? fake?.windowsFrontToBack() ?? [] }
  func stackedWindows() -> [StackedWindow] { replayer?.answer(read: "stackedWindows") ?? fake?.stackedWindows() ?? [] }
  func modifierKeysDown() -> KeyChord.Modifiers { replayer?.answer(read: "modifierKeysDown") ?? fake?.modifierKeysDown() ?? [] }
  /// A trace without the answer was recorded by an Arbor that did not ask, and stood aside for nobody.
  func macTiling() -> MacTiling { replayer?.answer(read: "macTiling") ?? .off }
  func whereabouts(of window: WindowID) -> Whereabouts {
    replayer?.answer(read: "whereabouts", about: [window]) ?? fake?.whereabouts(of: window) ?? .unknown
  }
  func openApplication(_ app: String) -> Bool {
    replayer?.answer(call: "openApplication", [app])?.decoded() ?? fake?.openApplication(app) ?? false
  }
  func launchApp(_ name: String) -> Bool {
    replayer?.answer(call: "launchApp", [name])?.decoded() ?? fake?.launchApp(name) ?? false
  }
  // The world first: what the trace says came of it has the last word.
  func setMinimized(_ window: WindowID, _ minimized: Bool) {
    fake?.setMinimized(window, minimized)
    replayer?.answer(call: "setMinimized", [window, minimized])
  }
  func unhideApp(pid: Int32) {
    fake?.unhideApp(pid: pid)
    replayer?.answer(call: "unhideApp", [pid])
  }
  /// A hint that may be ignored: the `setFrame` calls it foretells are answered from the recording one by one.
  func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) {}
  func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? { setFrame(frame, of: window) }
}
