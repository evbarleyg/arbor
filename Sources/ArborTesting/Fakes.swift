import ArborCore
import ArborKit
import CoreGraphics

/// Records overlays instead of drawing them, and lets tests click tiles and
/// drag seams.
@MainActor
public final class FakeOverlays: OverlayPresenter {
  public weak var actions: (any OverlayActions)?
  public private(set) var preview: CGRect?
  public private(set) var previewHistory: [CGRect?] = []
  /// The scene last shown on each display.
  public private(set) var scenes: [DisplayID: OverlayScene] = [:]
  public var tiles: [DisplayID: [TileModel]] { scenes.mapValues(\.tiles) }
  public var seams: [DisplayID: [Seam]] { scenes.mapValues(\.seams) }
  /// Every transition the controller asked for, oldest first.
  public private(set) var transitions: [Transition] = []
  /// How many times the controller dropped the stages.
  public private(set) var finishedAnimations = 0
  /// Every `rehearse`, oldest first.
  public private(set) var rehearsals: [Rehearsal] = []
  private var readyDisplays: Set<DisplayID> = []
  private var readyApps: Set<Rehearsal.App> = []
  /// What a motion needed that no rehearsal and no earlier motion had got ready. On a Mac a stage is time between the key
  /// and the first move, and a costume that is missing a window that travels as a plain card.
  public private(set) var madeInTheMotion: [String] = []
  /// Called with each transition as it arrives, for tests that care what has happened by then.
  public var onAnimate: ((Transition) -> Void)?
  /// The field for typing a space's name, if a display shows it.
  public var namePrompt: NamePromptModel? { scenes.sorted { $0.key < $1.key }.compactMap(\.value.namePrompt).first }
  /// The heads-up line showing now, by display.
  public private(set) var headsUp: [DisplayID: HeadsUpModel] = [:]
  /// Every heads-up line shown so far, oldest first.
  public private(set) var messages: [(display: DisplayID, model: HeadsUpModel)] = []
  /// The panel of shortcuts showing now, by display.
  public private(set) var cheatSheets: [DisplayID: CheatSheetModel] = [:]
  /// The minimap showing now, by display.
  public private(set) var minimaps: [DisplayID: MinimapModel] = [:]
  /// Every call of `showMinimap` so far, oldest first; nil took it away.
  public private(set) var minimapHistory: [(display: DisplayID, model: MinimapModel?)] = []

  public struct Update: Equatable {
    public var display: DisplayID
    /// False when the scene was the one already showing.
    public var changed: Bool
  }

  /// Every `update`, in order. On a Mac each one moves and reorders a panel per tile and seam.
  public private(set) var updateLog: [Update] = []

  /// One call of the controller's.
  public enum Call {
    case dropPreview(CGRect?)
    case update(DisplayID, OverlayScene)
    case removeAll
    case animate(Transition)
    case finishAnimations
    case headsUp(HeadsUpModel?, DisplayID)
    case cheatSheet(CheatSheetModel?, DisplayID)
    case minimap(MinimapModel?, DisplayID)
  }

  /// Hears of every call that has a moment to it, in order, once it is recorded: for whoever plays them back in time, as the
  /// panels on a Mac do with their fades and glides (`OverlayPlayback`).
  public var onCall: ((Call) -> Void)?

  public init() {}

  public func showDropPreview(_ frame: CGRect?) {
    preview = frame
    previewHistory.append(frame)
    onCall?(.dropPreview(frame))
  }

  public func update(display: DisplayID, scene: OverlayScene) {
    updateLog.append(Update(display: display, changed: (scenes[display] ?? OverlayScene()) != scene))
    scenes[display] = scene
    onCall?(.update(display, scene))
  }

  public func removeAll() {
    preview = nil
    scenes.removeAll()
    dismissFinder()
    headsUp.removeAll()
    cheatSheets.removeAll()
    minimaps.removeAll()
    onCall?(.removeAll)
  }

  public func clickTile(_ node: NodeID, on display: DisplayID = FakeWindowSystem.standardDisplay.id) {
    actions?.tileActivated(display: display, node: node)
  }

  /// Clicks the outline of a peek, if one shows. The click is over before any timer looks.
  @discardableResult
  public func clickOutline(on display: DisplayID = FakeWindowSystem.standardDisplay.id) -> Bool {
    guard scenes[display]?.peekOutline != nil else { return false }
    actions?.peekOutlineClicked(display: display)
    return true
  }

  public func dragSeam(_ seam: Seam, by delta: CGFloat, on display: DisplayID = FakeWindowSystem.standardDisplay.id) {
    actions?.seamDragged(display: display, seam: seam, by: delta)
  }

  public func animate(_ transition: Transition) {
    // As on a Mac: what nobody got ready is made for this motion, or missed in it, and kept from then on.
    if readyDisplays.insert(transition.display).inserted { madeInTheMotion.append("the stage of \(transition.display)") }
    for app in transition.items.map(\.app) where readyApps.insert(app).inserted {
      madeInTheMotion.append("the costume of \(app.bundleID ?? "pid \(app.pid)")")
    }
    transitions.append(transition)
    onAnimate?(transition)
    onCall?(.animate(transition))
  }

  public func rehearse(_ rehearsal: Rehearsal) {
    rehearsals.append(rehearsal)
    readyDisplays.formUnion(rehearsal.displays)
    readyApps.formUnion(rehearsal.apps)
  }

  public func finishAnimations() {
    finishedAnimations += 1
    onCall?(.finishAnimations)
  }

  /// Forgets the transitions recorded so far, so a test can look at one step's.
  public func clearTransitions() { transitions.removeAll() }

  public func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID) {
    headsUp[display] = model
    if let model { messages.append((display, model)) }
    onCall?(.headsUp(model, display))
  }

  public func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID) {
    cheatSheets[display] = model
    onCall?(.cheatSheet(model, display))
  }

  /// Presses a key, or clicks, while the panel of shortcuts is up.
  public func dismissCheatSheet() { actions?.cheatSheetDismissed() }

  /// Types `text` into the name field and presses ↩, as `NamePanel` does. Returns nil if the field is
  /// not showing, or does not take the text and stays open.
  @discardableResult
  public func submitName(_ text: String) -> CommandResult? {
    guard let command = namePrompt?.answer(to: text).command else { return nil }
    return actions?.perform(command)
  }

  /// Presses ⎋ in the name field.
  public func cancelName() {
    if namePrompt != nil { actions?.perform(.askName(cancel: true)) }
  }

  // MARK: The finder

  /// The finder's palette while it is open: the same `FinderSession` the real palette draws.
  public private(set) var finder: FinderSession?
  /// How often the palette beeped: once for every list that came with a notice.
  public private(set) var finderBeeps = 0

  public func showFinder(_ model: FinderModel?) {
    guard let model else {
      finder = nil
      return
    }
    if model.notice != nil { finderBeeps += 1 }
    if finder == nil {
      finder = FinderSession(model: model)
    } else {
      finder?.replace(model: model)
    }
  }

  /// The user replaces the text in the field.
  public func typeInFinder(_ text: String) { finder?.type(text) }

  /// ↓ and ⇥ (positive) or ↑ and ⇧⇥ (negative).
  public func moveFinderSelection(by rows: Int) { finder?.moveSelection(by: rows) }

  /// Return, or with `row` a click on that row or ⌘ and its number, counted from 1 at the top of the
  /// palette. Returns false if there is nothing there to choose.
  @discardableResult
  public func chooseInFinder(row: Int? = nil) -> Bool {
    guard let finder else { return false }
    let destination = if let row { row >= 1 ? finder.destination(atVisible: row - 1) : nil } else { finder.selected }
    guard let destination else { return false }
    actions?.finderChose(destination)
    return true
  }

  /// Escape, or a click on another window.
  public func dismissFinder() {
    guard finder != nil else { return }
    finder = nil
    actions?.finderDismissed()
  }

  public func showMinimap(_ model: MinimapModel?, on display: DisplayID) {
    minimaps[display] = model
    minimapHistory.append((display, model))
    onCall?(.minimap(model, display))
  }

  /// Clicks at `point`, in the panel's coordinates. As on screen, a minimap that is not there or does not take clicks
  /// lets the click through, and nobody hears of it.
  public func clickMinimap(at point: CGPoint, on display: DisplayID = FakeWindowSystem.standardDisplay.id) {
    guard minimaps[display]?.takesClicks == true else { return }
    actions?.minimapClicked(display: display, at: point)
  }
}

@MainActor
public final class MemoryStateStore: StateStore {
  public var saved: PersistedState?
  public private(set) var saveCount = 0
  /// What a test wants `load()` to have found wrong.
  public var repairs: [String] = []
  public var keptCopy: String?
  /// Follows from the two above unless a test says otherwise.
  public var loadProblem: StateLoadProblem? {
    get { statedProblem ?? (!repairs.isEmpty ? .repaired : keptCopy != nil ? .unreadable : nil) }
    set { statedProblem = newValue }
  }
  private var statedProblem: StateLoadProblem?

  public init(saved: PersistedState? = nil) { self.saved = saved }

  public func load() -> PersistedState? { saved }

  public func save(_ state: PersistedState) {
    saved = state
    saveCount += 1
  }
}

/// Holds scheduled work so tests control time: `runPending()` runs everything whatever its delay,
/// `advance(by:)` moves the clock and runs only what has fallen due.
@MainActor
public final class ManualScheduler: Scheduler {
  private struct Item {
    var due: Double
    var action: @MainActor () -> Void
  }

  private var pending: [String: Item] = [:]
  private var order: [String] = []
  /// Called after each piece of work. `Harness` delivers the fake window system's echoes here.
  public var afterEach: (@MainActor () -> Void)?
  /// Seconds since the scheduler was made. Only `advance(by:)` moves it.
  public private(set) var now: Double = 0

  public init() {}

  public func schedule(_ key: String, after seconds: Double, _ action: @escaping @MainActor () -> Void) {
    if pending[key] == nil { order.append(key) }
    pending[key] = Item(due: now + max(seconds, 0), action: action)
  }

  public func cancel(_ key: String) {
    pending[key] = nil
    order.removeAll { $0 == key }
  }

  public var pendingKeys: [String] { order }

  /// Runs everything scheduled so far (work scheduled while running waits for the next call).
  public func runPending() {
    let keys = order
    let items = pending
    order.removeAll()
    pending.removeAll()
    for key in keys {
      guard let item = items[key] else { continue }
      item.action()
      afterEach?()
    }
  }

  /// Moves the clock forward by `seconds`, running work as it falls due, earliest first,
  /// including work that this work schedules within the same span.
  public func advance(by seconds: Double) {
    let end = now + max(seconds, 0)
    while let key = order.filter({ pending[$0]!.due <= end }).min(by: { pending[$0]!.due < pending[$1]!.due }),
      let item = pending[key]
    {
      now = max(now, item.due)
      cancel(key)
      item.action()
      afterEach?()
    }
    now = end
  }
}

// MARK: Traces

extension ManualScheduler {
  /// Runs the work scheduled under `key` now, whatever its delay. False if there is none.
  @discardableResult
  public func fire(_ key: String) -> Bool {
    guard let item = pending[key] else { return false }
    cancel(key)
    item.action()
    return true
  }

  /// Like `advance(by:)` up to the time `end`, except that work for which `hold` says true stays scheduled: a trace
  /// replay runs it when the trace says it ran. `willRun` hears of each piece of work before it runs.
  public func advance(
    to end: Double, holding hold: (_ key: String, _ due: Double) -> Bool, willRun: (String) -> Void = { _ in }
  ) {
    while let key = order.filter({ pending[$0]!.due <= end && !hold($0, pending[$0]!.due) })
      .min(by: { pending[$0]!.due < pending[$1]!.due }), let item = pending[key]
    {
      now = max(now, item.due)
      cancel(key)
      willRun(key)
      item.action()
    }
    now = max(now, end)
  }
}

/// Keeps a trace's lines in memory.
@MainActor
public final class MemoryTraceSink: TraceSink {
  public let location: String
  public private(set) var lines: [String] = []
  public private(set) var isClosed = false
  /// Set to make the next writes fail, as a full disk would.
  public var failure: (any Error)?

  public init(location: String) { self.location = location }

  public var text: String { lines.map { $0 + "\n" }.joined() }

  public func write(_ line: String) throws {
    if let failure { throw failure }
    lines.append(line)
  }

  public func close() { isClosed = true }
}
