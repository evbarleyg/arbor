import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// A controller wired to fakes. Scenario tests and arbor-sim use it:
///
///     let h = Harness()
///     let a = h.system.open(app: "Safari")
///     h.start()
///     h.run("dock \(a.rawValue) left")
///     print(h.ascii())
@MainActor
public final class Harness {
  public let system: FakeWindowSystem
  public let overlays: FakeOverlays
  public let store: MemoryStateStore
  public let scheduler: ManualScheduler
  public let controller: Controller
  /// Answers `check-for-updates`: no published release, until a test says otherwise.
  public let releases = FakeReleaseFeed()
  public let loginItem = FakeLoginItem()
  /// The switches under Desktop & Dock, as a Mac comes.
  public let mac: FakeMacSwitchboard
  /// The welcome window. Made, and wired to the controller, when it is first asked for.
  public private(set) lazy var welcome = FakeWelcomeWindow(controller: controller)
  /// Records traces into memory (`trace on`, then `lastTrace`).
  public let recorder: TraceRecorder

  /// As Arbor ships. Two runs of the same tests say otherwise, in the environment, so that what has gone off is known to work still: every
  /// test that does not choose its settings then runs with it on.
  /// - `ARBOR_TEST_CLASSIC=1` (`make test-classic`): as the first build shipped (`Settings.classic`): arranged as it arranged, a column
  ///   for the Desktop and floating windows making way, with what it drew, moved and bound.
  /// - `ARBOR_TEST_MAKING_WAY=1` (`make test-making-way`): with `floatingWindowsMakeWay` on alone, as until Q20 (collab/QUESTIONS.md), when
  ///   floating windows were kept on the Desktop.
  /// A test of how Arbor ships gives its settings, `Settings()`, in so many words.
  public nonisolated static var settingsWhenNoneAreGiven: Settings {
    let environment = ProcessInfo.processInfo.environment
    var settings = environment["ARBOR_TEST_CLASSIC"] == "1" ? Settings.classic : Settings()
    if environment["ARBOR_TEST_MAKING_WAY"] == "1" { settings.floatingWindowsMakeWay = true }
    return settings
  }

  /// Every harness made while this is true has `windowsThatDoNotFit` at `tile`, whatever settings it is given: a docked window too large for
  /// its place goes out of view and a tile stands there, as until board 0.26 (docs/features/F69-what-cannot-fit-overlaps.md). The tests of tiles
  /// say so at their heads, `@Test(.withTiles)` or `@Suite(.withTiles)`, and need not know through how many helpers their harness is made.
  public nonisolated static var makesTiles: Bool { TilesForTests.areAskedFor }

  /// `interpose` puts a window system between the controller and the fake one; trace replays use it.
  /// - Parameter system: the windows and displays of an earlier harness, for a new run of Arbor
  ///   on the same Mac; `displays` is then ignored.
  /// - Parameter mac: that Mac's switches, and what Arbor wrote down about them.
  public init(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Harness.settingsWhenNoneAreGiven,
    saved: PersistedState? = nil, system: FakeWindowSystem? = nil, mac: FakeMacSwitchboard? = nil,
    interpose: ((FakeWindowSystem) -> any WindowSystem)? = nil
  ) {
    var settings = settings
    if Self.makesTiles { settings.windowsThatDoNotFit = "tile" }
    self.system = system ?? FakeWindowSystem(displays: displays)
    self.mac = mac ?? FakeMacSwitchboard()
    let mac = self.mac
    let system = self.system
    overlays = FakeOverlays()
    store = MemoryStateStore(saved: saved)
    scheduler = ManualScheduler()
    recorder = TraceRecorder()
    recorder.clock = { [scheduler] in scheduler.now }
    recorder.openSink = { MemoryTraceSink(location: $0) }
    recorder.arborVersion = "test"
    recorder.osVersion = "simulated"
    // The controller is wired through the recording decorators as it is in the app, so every test
    // also shows that they change nothing.
    controller = Controller(
      system: RecordingWindowSystem(wrapping: interpose?(system) ?? system, recorder: recorder),
      overlays: RecordingOverlays(wrapping: overlays, recorder: recorder), store: store,
      scheduler: RecordingScheduler(wrapping: scheduler, recorder: recorder), settings: settings,
      filter: WindowFilter(ownPID: 1))
    controller.stats = CallStats()
    // One clock: `scheduler.advance(by:)` also moves the time the controller reads.
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    controller.now = { [scheduler] in start.addingTimeInterval(scheduler.now) }
    scheduler.afterEach = { [system] in system.deliverEchoes() }
    scheduler.beforeEach = { [system] due in system.itIsAtLeast(due) }
    system.afterEvents = { [scheduler] in scheduler.advance(by: 0) }
    system.clock = { [scheduler] in scheduler.now }
    controller.releaseFeed = releases
    controller.loginItem = loginItem
    controller.macSwitchboard = mac
    // One Mac: what is stored for the switches is how its window server treats a dragged window.
    mac.didChange = { [unowned mac, unowned system] in system.tiling = MacTiling(mac.on) }
    // Time also passes while a simulated drag rests at a point.
    system.passTime = { [scheduler] in scheduler.advance(by: $0) }
    // Whoever drags a window to dock it holds what this Arbor asks for, as it is set at that moment (docs/TESTING.md).
    system.keysThatDock = { [weak controller] in
      controller.map { DragDocks(setting: $0.settings.dragDocks) } == .held ? DragDocks.key : []
    }
    firstMark = system.moveLog.count
  }

  public func start() { controller.start() }

  /// What the app does when it is launched (`ArborApp.applicationDidFinishLaunching`): with the Accessibility permission Arbor starts. Without, which
  /// is every first launch, and every launch of a new build whose signature an old grant does not fit, it waits, with its item in the menu bar,
  /// looks once a second, and starts by itself.
  public func launch() {
    // `FrontmostAppWatcher.start` reports at once, before the first registration.
    controller.applicationActivated(system.frontmost)
    guard system.isDenied else { return start() }
    controller.accessibilityGranted = false
    scheduler.schedule("the app waits for the permission", after: 1) { [weak self] in
      guard let self else { return }
      if !self.system.isDenied { self.controller.accessibilityGranted = true }
      self.launch()
    }
  }

  /// A new run of Arbor on the same Mac, not started yet: the windows and displays as they are now, the settings in use, what this run
  /// saved, and a clock that goes on. It knows nothing else of this run, which has quit (`controller.shutdown()`) or counts
  /// as killed, and must not be used any more.
  /// - Parameter byTheWatchdog: the watchdog does the starting, a second after an accident; otherwise a person, or a login.
  public func newProcess(byTheWatchdog: Bool = false) -> Harness {
    system.events = nil
    system.stop()
    system.forgetSession()
    let (new, ended) = (Harness(settings: controller.settings, saved: store.saved, system: system, mac: mac), controller.now())
    new.controller.now = { [scheduler = new.scheduler] in ended.addingTimeInterval(scheduler.now) }
    new.controller.restartedAfterAccident = byTheWatchdog
    return new
  }

  /// Lets the controller ask whether it still has Accessibility permission, as the app does. Call before `start()`.
  /// Not the default: the question comes round every two seconds, which most tests do not want in their schedule.
  public func watchAccessibility() {
    controller.accessibilityProbe = { [system] thoroughly in system.mayUseAccessibility(thoroughly: thoroughly) }
  }

  /// The user switches Arbor off under Privacy & Security → Accessibility. Nobody tells Arbor.
  public func revokeAccessibility() { system.isDenied = true }
  public func grantAccessibility() { system.isDenied = false }

  /// Parses and performs a command (same text as `arborctl`).
  @discardableResult
  public func run(_ text: String) -> CommandResult {
    do {
      let result = controller.perform(try Command.parse(text))
      system.deliverEchoes()
      return result
    } catch {
      return .failure("\(error)")
    }
  }

  /// The same, saying where the command came from.
  @discardableResult
  public func run(_ text: String, from source: CommandSource) -> CommandResult {
    do {
      let result = controller.perform(try Command.parse(text), from: source)
      system.reportFocus()
      return result
    } catch {
      return .failure("\(error)")
    }
  }

  /// The user presses and releases a shortcut bound to this command. As on a Mac, the command runs
  /// while the key is still down.
  @discardableResult
  public func press(_ text: String) -> CommandResult {
    system.keyDown()
    defer { system.keyUp() }
    return run(text, from: .shortcut)
  }

  /// The shortcuts the app would have registered now.
  public var registeredShortcuts: [KeyBinding] {
    controller.temporaryShortcuts + controller.activeBindings
  }

  /// The user presses a shortcut, written as in settings.json (`ctrl+opt+space`), and keeps it down. Returns
  /// the reply of the command it ran, if it ran one.
  @discardableResult
  public func keyDown(_ text: String) -> CommandResult? {
    guard let chord = try? KeyChord(text: text) else { return .failure("cannot read the shortcut \(text)") }
    system.hold(chord)
    guard let binding = registeredShortcuts.first(where: { $0.chord == chord }) else {
      system.giveToTheAppInFront(chord)
      return nil
    }
    defer { system.reportFocus() }
    return controller.shortcut(binding, .pressed)
  }

  /// A key that is held sends its press again and again.
  public func keyRepeat(_ text: String) {
    guard let chord = try? KeyChord(text: text) else { return }
    system.keyDown()
    guard let binding = registeredShortcuts.first(where: { $0.chord == chord }) else { return system.giveToTheAppInFront(chord) }
    controller.shortcut(binding, .pressed)
  }

  /// The user lets go of it, or with `keepingModifiers` only of its key. With `reported: false` macOS never says so.
  public func keyUp(_ text: String, reported: Bool = true, keepingModifiers: Bool = false) {
    guard let chord = try? KeyChord(text: text) else { return }
    // Looked up first: letting go can end what registered it.
    let binding = registeredShortcuts.first { $0.chord == chord }
    system.letGo(chord, keepingModifiers: keepingModifiers)
    if reported, let binding { controller.shortcut(binding, .released) }
    system.reportFocus()
  }

  /// Down and up.
  @discardableResult
  public func key(_ text: String) -> CommandResult? {
    let result = keyDown(text)
    keyUp(text)
    return result
  }

  public var display: DisplayID { system.displayList[0].id }
  public var workspace: Workspace { controller.workspaces[display]! }
  public var layout: Layout? { controller.layouts[display] }
  public var visibleFrame: CGRect { system.displayList[0].visibleFrame }

  public func frame(_ window: WindowID) -> CGRect? { system.frame(of: window) }

  public func ascii(columns: Int = 72, rows: Int = 22) -> String {
    controller.asciiDrawing(columns: columns, rows: rows)
  }

  /// How long the fake's `moveLog` was when the step that is being judged began. Nil until somebody says where a step begins.
  public private(set) var stepMark: Int?
  /// Where this harness found the log: a window system taken over from an earlier run of Arbor has that run's moves in it.
  private var firstMark = 0

  /// Call before a step whose moves are to be judged: `expect still`, `expect moved-once` and `jolts` look at what came after.
  public func beginStep() { stepMark = system.moveLog.count }

  /// How often Arbor has really moved each window since `beginStep()`, or since this harness was made. A request that left
  /// the window where it was is no move, nor is a question put to it where it stood before it went anywhere (`Budget.questions`).
  public var movesInStep: [WindowID: Int] {
    var moves: [WindowID: [FakeWindowSystem.Move]] = [:]
    for move in system.moveLog[min(stepMark ?? firstMark, system.moveLog.count)...] where move.before != move.after {
      moves[move.window, default: []].append(move)
    }
    return moves.mapValues { $0.count - Budget.tally($0).questions }
  }

  /// The windows Arbor has moved twice since then where once would have done (Jolts.swift). Those `whileLearning` are
  /// among them: whoever asks whether Arbor changed its mind for nothing leaves them out.
  public var jolts: [Jolt] { system.jolts(since: stepMark ?? firstMark) }

  /// The text of the trace being recorded or last recorded.
  public var lastTrace: String? { (recorder.sink as? MemoryTraceSink)?.text }
}

/// What `Harness.makesTiles` reads. On its own, outside the main actor's class: Swift 6.2 lets no task-local value be nonisolated inside one.
public enum TilesForTests {
  @TaskLocal public static var areAskedFor = false
}
