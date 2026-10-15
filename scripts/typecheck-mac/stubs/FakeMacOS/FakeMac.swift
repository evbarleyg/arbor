// The model of a Mac behind the stand-ins (scripts/mac-on-linux/README.md). `make typecheck-mac` only compiles it; `make mac-on-linux` links it with
// Arbor's real Accessibility layer and runs them. Never shipped.
//
//   FakeMac.swift         what the Mac consists of, its clock, and what is on its way to Arbor
//   Pump.swift            runs Arbor's tasks on one thread until nothing is runnable
//   Accessibility.swift   what apps answer to Accessibility calls, and what observers are told
//   WindowServer.swift    the window server's list, the screens
//   Apps.swift            what apps and the people in front of them do: launch, quit, come forward, hide, hang
//   Windows.swift         open, close, minimize, full screen, tabs, Spaces
//   Mouse.swift           presses, drags, releases
//   Threads.swift         other threads than Arbor's main one, on the model's clock
//   DesktopShown.swift    macOS shows its desktop: the windows are listed at the sides
//
// Every delay and every order of reports here says where it was seen. "Guess" marks what nobody has measured.
import Foundation

/// One Mac: its apps, windows, window server, workspace, screens, mouse and clock. The stand-ins' functions ask `FakeMac.current`.
///
/// Everything happens on the main thread, one thing after the other (`Pump`), so nothing here is locked.
public final class FakeMac: @unchecked Sendable {
  /// The Mac the stand-ins ask. Each story makes its own.
  public nonisolated(unsafe) static var current = FakeMac()

  public init() {
    arbor = App(pid: Self.getpid(), name: "Arbor", bundleID: "com.evbarleyg.arbor", policy: .accessory)
    apps = [arbor]
  }

  // MARK: What it consists of

  /// Arbor itself. An accessory app, never in front unless a story says so.
  public let arbor: App
  /// The apps that run, in the order they were launched.
  public internal(set) var apps: [App]
  /// No two Macs have a process of the same number: what Arbor keeps for the whole of its own process, by pid, must not colour the next story.
  nonisolated(unsafe) static var lastPID: pid_t = 500
  var lastWindowNumber: UInt32 = 100
  var windowsMade = 0
  var windowsBySerial: [Int: Window] = [:]
  var tabGroupsMade = 0
  /// The helper windows macOS makes for a window in full screen, by that window's serial.
  var fullScreenHelpers: [Int: [Window]] = [:]

  /// Apps' windows as the window server stacks them, front to back: all that exist, also those that do not show.
  public internal(set) var stack: [Window] = []
  /// What else the window server lists (WindowServer.swift).
  public var furniture: [Furniture] = []
  /// The call for the list comes back with nothing. Seen: Sources/ArborKit/AX/AXWindowSystem.swift, `countWindows`.
  public var serverGivesNoList = false

  public internal(set) var activeSpace = 1
  var spacesMade = 1
  /// Until then apps list neither the old Space's windows nor the new one's.
  var listsAreEmptyUntil: TimeInterval = 0

  /// The app in front, as it is.
  public internal(set) var frontmost: App?
  /// The app in front as `NSWorkspace.shared.frontmostApplication` names it: a copy that is brought up to date by a message of its own.
  public internal(set) var frontmostByWorkspace: App?
  /// How long that copy goes on naming the old app after `didActivateApplication` has been delivered. Zero: it names the new one by then. On
  /// hosted Macs it still named the old one 27 times in three runs. How long it takes to catch up nobody has measured.
  public var frontmostLagsNoticeBy: TimeInterval = 0
  /// The next app that comes forward does so without `didActivateApplication`. A GUESS that this happens at all: switches of apps have gone unreported on hosted Macs (trace `app-switch-unreported`), and nobody has shown
  /// which of the words was missing. What Accessibility posts, and `frontmostApplication`, are as ever.
  public var losesTheNextActivationNotice = false
  /// The apps that were in front, latest first: who comes forward when the one in front goes.
  var activationHistory: [App] = []

  public internal(set) var screens: [Screen] = [Screen.hostedMac]
  public internal(set) var mouse = Mouse()
  /// A loaded Mac. The monitors hear of a mouse-down so much later than usual; what follows it queues up behind it.
  public var mouseDownIsLateBy: TimeInterval = 0
  /// A loaded Mac. The window server begins to move a window that is dragged so long after the press, and then catches up with the pointer.
  public var serverFollowsPointerAfter: TimeInterval = 0
  /// A loaded Mac. The window server has a dragged window where the pointer was so long ago, all through the drag. (A hosted Mac: 27 points at the first look, the
  /// window still in its place.)
  public var serverLagsPointerBy: TimeInterval = 0
  /// With the button down `NSEvent.mouseLocation` says where the pointer was one movement ago, so that a dragged window is a step ahead of the pointer as read. Guess.
  public var pointerIsReadOneStepLate = false
  /// The window server has a dragged window one movement further than the pointer has gone, and leaves it there. (A hosted Mac: the window ended 67 points further than
  /// the pointer travelled, which was one step of that drag. Why is not known.)
  public var serverRunsAStepAhead = false
  /// The window server lists a frame that was set through Accessibility so much later; Accessibility has it at once. On a hosted Mac (macOS 26, 2026-10-15; 615 calls that changed a frame) the list
  /// read right after the call still had the frame before it in 475, something older in 94; at the first later look, 60 ms or more, it had caught up in 165 of 170; 62 to 146 ms after calls back to back it
  /// had a half-way frame five times; from 200 ms on it was right, 170 of 170. So as a rule it is behind for less than some 60 ms, at worst for 146 to 200. Half-way frames are not played: after
  /// one move from 518,43 494×650 to 220,180 480×348 the list gave 518,43 480×348, the old place with the new size. What shows on screen meanwhile, and from which frame a drag begun
  /// meanwhile starts, nobody has looked at: here it starts from the listed one. GUESS.
  public var serverListsACallAfter: TimeInterval = 0
  /// While macOS shows its desktop: where the window server lists each window it swept aside, by number (DesktopShown.swift).
  public internal(set) var sweptTo: [UInt32: CGRect]?
  /// How long after the button went down on a strip the window server lists the windows where they are again, with the button still down. 27 ms on a hosted
  /// Mac at rest. What a loaded one takes nobody has measured.
  public var stripBringsBackAfter: TimeInterval = 0.027
  /// Whether the Dock's window at level 18 is listed during a sweep, as on macOS 26. Off: a macOS that has no such sign. Nobody has looked on 14 and 15.
  public var docksSignShows = true
  /// Whether Arbor has the Accessibility permission. Without it every call is refused with `apiDisabled`.
  public var isTrusted = true

  var observers: [Observer] = []
  var monitors: [Monitor] = []
  var monitorsMade = 0

  public var timing = Timing()
  public var manners = Manners()

  /// How long a call waits for an app whose element has no timeout of its own: what was set on the system-wide element, which a Mac showed to cover every element
  /// (docs/features/F17, H3). Else six seconds, which is a GUESS from Apple's header: the one measurement there is, of window elements without a timeout of their own, gave 1.55 s.
  var processTimeout: TimeInterval = 6
  /// How many Accessibility calls Arbor has made, and how long it waited in them for apps that did not answer.
  public internal(set) var calls = 0
  public internal(set) var secondsWaitedInVain: TimeInterval = 0
  /// The most it has waited in vain for one app in one hang.
  public internal(set) var longestWaitForOneHang: TimeInterval = 0
  /// How long Arbor's main thread has stood still in all: in calls to apps, answered or not, and waiting for its own other threads.
  public internal(set) var secondsTheMainThreadWaited: TimeInterval = 0
  var workers: [Worker] = []
  /// What is put on Arbor's main dispatch queue has its turn so much later. To the run loop the queue is one source among others.
  public var mainQueueIsLateBy: TimeInterval = 0

  // MARK: The clock

  /// Seconds since this Mac started. It moves only in `pass`, and inside an Accessibility call.
  public internal(set) var now: TimeInterval = 10_000
  /// When this Mac started. The same for every Mac, so that a story's times are the same to the last digit whatever was told before it.
  public let dawn: TimeInterval = 10_000

  /// What `ProcessInfo.processInfo.systemUptime` becomes in the copy of Arbor's sources (scripts/mac-on-linux/retime.py).
  public static var uptime: TimeInterval { current.now }

  // MARK: What is on its way

  /// Where something on its way comes from. What comes from one source arrives in the order it was sent; macOS promises nothing about two.
  public enum Source: Hashable, Sendable {
    /// What an app's Accessibility observer is told.
    case accessibility(pid_t)
    /// `NSWorkspace`'s notification centre.
    case workspace
    /// `NSWorkspace`'s own book-keeping (`frontmostApplication`).
    case workspaceCache
    /// `NSApplication`'s notifications about the screens.
    case screens
    /// The event monitors.
    case mouse
    /// What AppKit's class methods say about the mouse (`pressedMouseButtons`).
    case mouseCache
    /// What an app does by itself a moment later: an animation's end, a subrole that comes late, a call carried out late.
    case app(pid_t)
    /// The window server and the Dock.
    case system
    /// A task of Arbor's that sleeps. Each is a source of its own.
    case sleeper(Int)
    /// Arbor's main dispatch queue.
    case mainQueue
    /// A thread of Arbor's that is not the main one (Threads.swift).
    case thread(Int)
  }

  struct Pending {
    var due: TimeInterval
    var order: Int
    var source: Source
    var label: String
    var run: () -> Void
  }

  var pending: [Pending] = []
  private var sent = 0
  private var lastDue: [Source: TimeInterval] = [:]

  /// What happened on this Mac and what was delivered to Arbor, with the times: a failing story prints it.
  public private(set) var journal: [String] = []
  public var keepsJournal = true

  public func note(_ text: @autoclosure () -> String) {
    guard keepsJournal else { return }
    journal.append(String(format: "%9.4f  ", now - dawn) + text())
  }

  /// Sends something on its way. With `manners.overtaking` it may be held up, so that what another source sent later arrives first.
  func send(after delay: TimeInterval, from source: Source, _ label: String, _ run: @escaping () -> Void) {
    var due = now + max(delay, 0)
    guard !hasEnded, !(arborHasGone && (isForTheMainThread(source) || { if case .thread = source { true } else { false } }())) else { return }
    var isArborsOwn = false
    switch source {
    case .sleeper, .thread: isArborsOwn = true
    default: break
    }
    if isArborsOwn {
      // Arbor's own timers and threads are not macOS's to delay.
    } else {
      if manners.overtaking > 0 { due += manners.fraction() * manners.overtaking }
      due = max(due, lastDue[source] ?? 0)
      lastDue[source] = due
    }
    sent += 1
    pending.append(Pending(due: due, order: sent, source: source, label: label, run: run))
  }

  /// `forTheMainThread: false`: the main thread is waiting, and what is meant for it stays where it is.
  func takeNext(until end: TimeInterval, forTheMainThread: Bool = true) -> Pending? {
    var best: (index: Int, key: (TimeInterval, Int, TimeInterval, Int))?
    for (index, item) in pending.enumerated() {
      if !forTheMainThread, isForTheMainThread(item.source) { continue }
      let key = turn(of: item)
      guard key.0 <= end else { continue }
      if let best, best.key <= key { continue }
      best = (index, key)
    }
    guard let best else { return nil }
    var item = pending.remove(at: best.index)
    item.due = best.key.0
    return item
  }

  // MARK: Arbor's main thread is busy

  /// In which order what has queued up is served when the main thread is free again. Each source is a port or a queue of its own to the run loop,
  /// which promises nothing about the order among them.
  public enum Backlog: Sendable { case byTime, accessibilityFirst, mouseFirst }
  private var arborIsBusyUntil: TimeInterval = 0
  private var backlogOrder = Backlog.byTime

  /// Arbor's main thread does something else for so long (a layout, a slow call, a loaded Mac that does not schedule it). The Mac goes on; whatever is
  /// meant for Arbor waits, its own timers included, and is served at the end, when the mouse and the windows are where they are by then.
  public func arborIsBusy(for seconds: TimeInterval, then order: Backlog = .byTime) {
    note("Arbor's main thread is busy for \(seconds) s")
    arborIsBusyUntil = now + seconds
    backlogOrder = order
  }

  private func isForTheMainThread(_ source: Source) -> Bool {
    switch source {
    case .accessibility, .mouse, .workspace, .screens, .sleeper, .mainQueue: true
    case .workspaceCache, .mouseCache, .app, .system, .thread: false
    }
  }

  /// When an item's turn comes, and among those whose turn comes at the same time, which goes first.
  private func turn(of item: Pending) -> (TimeInterval, Int, TimeInterval, Int) {
    let rank: Int
    switch item.source {
    case .accessibility: rank = backlogOrder == .accessibilityFirst ? 0 : 1
    case .mouse: rank = backlogOrder == .mouseFirst ? 0 : 1
    case .workspace, .screens, .sleeper, .mainQueue: rank = 1
    // The Mac's own business waits for nobody, nor do Arbor's other threads.
    case .workspaceCache, .mouseCache, .app, .system, .thread: return (item.due, 0, item.due, item.order)
    }
    guard item.due < arborIsBusyUntil else { return (item.due, 0, item.due, item.order) }
    return (arborIsBusyUntil, backlogOrder == .byTime ? 0 : rank, item.due, item.order)
  }

  /// Lets `seconds` go by: whatever falls due is delivered in order, and after each delivery Arbor's tasks run until none is runnable.
  /// A call that waits for a hung app moves the clock by itself; what fell due meanwhile is delivered afterwards, as to a busy main thread.
  public func pass(_ seconds: TimeInterval) {
    let end = now + seconds
    Pump.runTasks()
    while let item = takeNext(until: max(end, now)) {
      now = max(now, item.due)
      if !item.label.isEmpty { note(item.label) }
      item.run()
      Pump.runTasks()
    }
    now = max(now, end)
  }

  /// Whether nothing but Arbor's own sleeping tasks is still on its way.
  public var isQuiet: Bool {
    !pending.contains { if case .sleeper = $0.source { false } else { true } }
  }

  // MARK: Sleeping

  private var sleepers: [Int: UnsafeContinuation<Void, any Error>] = [:]
  private var sleepersMade = 0
  private(set) var hasEnded = false

  /// What `Task.sleep(nanoseconds:)` becomes in the copy. Like the real one it ends early, with an error, when its task is cancelled.
  public static func sleep(nanoseconds: UInt64) async throws { try await current.sleep(Double(nanoseconds) / 1e9) }
  public static func sleep(for duration: Duration) async throws {
    try await current.sleep(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
  }

  private func sleep(_ seconds: TimeInterval) async throws {
    sleepersMade += 1
    let number = sleepersMade
    try await withTaskCancellationHandler {
      try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, any Error>) in
        if Task.isCancelled { return continuation.resume(throwing: CancellationError()) }
        // Its Mac is no more: it sleeps for ever.
        if hasEnded { return }
        sleepers[number] = continuation
        send(after: seconds, from: .sleeper(number), "") { [self] in sleepers.removeValue(forKey: number)?.resume() }
      }
    } onCancel: {
      self.sleepers.removeValue(forKey: number)?.resume(throwing: CancellationError())
    }
  }

  // MARK: Arbor ends, the Mac goes on

  public private(set) var arborHasGone = false
  /// A call the app had begun to carry out when it hung (`hangsInTheMiddleOfThatCall`), and whose sender ends meanwhile. A GUESS, nobody has measured it: the app has read the message and is at work, so it goes
  /// through with it.
  public var appsFinishWhatTheyAreAtThoughItsSenderIsGone = true

  /// Arbor's process ends. Its threads, timers, observers and monitors go with it, and what was on its way to it reaches nobody.
  ///
  /// What it has asked of an app that hangs goes with it too. SEEN on a hosted Mac, macOS 26.6.2, 2026-10-15 (`scripts/mac-shell/check-hang.sh`, session 2): a place and a size were sent to each of two windows of
  /// an app that hung; Arbor's process ended half a second later; the app woke 18 s after that, and both windows were still where they had been. In session 3 the same four calls were sent at a pause, Arbor
  /// lived on, and both windows were in view at the first look, 2.5 s after the app woke, with no line in the log of the controller's having fetched them. Until then this model had it the other way round ("what is sent is sent"), and was wrong.
  public func arborIsGone() {
    note("Arbor is gone")
    arborHasGone = true
    for app in apps {
      let before = app.backlog.count
      app.backlog.removeAll { $0.asked == .waiting || ($0.asked == .underWay && !appsFinishWhatTheyAreAtThoughItsSenderIsGone) }
      if app.backlog.count < before { note("of what Arbor asked of pid \(app.pid), which hangs, \(before - app.backlog.count) calls are dropped unserved") }
    }
    pending.removeAll { item in
      if case .thread = item.source { return true }
      return isForTheMainThread(item.source)
    }
    sleepers.removeAll()
    for worker in workers { worker.finish() }
    workers.removeAll()
    observers.removeAll()
    monitors.removeAll()
  }

  /// Arbor is started again, a new process.
  public func arborIsBack() { arborHasGone = false }

  /// Something happens on this Mac so much later, whatever Arbor's main thread is doing by then.
  public func later(_ seconds: TimeInterval, _ action: @escaping () -> Void) { send(after: seconds, from: .system, "", action) }

  /// The story is over: nothing more is delivered, and whoever sleeps is never woken. Waking them would run what they were waiting to do, on a Mac
  /// that is no more, and a timer that winds itself up again would never let go.
  public func end() {
    Pump.runTasks()
    hasEnded = true
    pending.removeAll()
    sleepers.removeAll()
    for worker in workers { worker.finish() }
    workers.removeAll()
    Pump.runTasks()
  }

  // MARK: Which macOS

  /// What `ProcessInfo.processInfo.operatingSystemVersion` becomes in the copy. The hosted Macs the traces were recorded on.
  public var macOS = OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 2)
  public static var operatingSystemVersion: OperatingSystemVersion { current.macOS }

  // MARK: Processes

  // MARK: The person's settings

  /// What other processes' preferences hold, by domain and key. A key that is not there has never been touched: the setting is as a Mac comes.
  public var preferences: [String: [String: Any]] = [:]

  /// Desktop & Dock: "Drag windows to left or right edge of screen to tile", "Drag windows to menu bar to fill screen", "Hold ⌥ key while dragging windows to tile". On, as a Mac comes, since macOS 15. What macOS
  /// then does with a window that is let go: `macOSTakes` (Mouse.swift).
  public var macOSTilesDraggedWindows: Bool {
    get { preferences["com.apple.WindowManager"]?["EnableTilingByEdgeDrag"] as? Bool ?? true }
    set {
      for key in ["EnableTilingByEdgeDrag", "EnableTopTilingByEdgeDrag", "EnableTilingOptionAccelerator"] { preferences["com.apple.WindowManager", default: [:]][key] = newValue }
    }
  }

  /// What `UserDefaults(suiteName:)` becomes in the copy: another process's domain, on the model and not on this machine.
  public struct Defaults {
    let domain: String
    public func object(forKey key: String) -> Any? { FakeMac.current.preferences[domain]?[key] }
    /// A word counts as `NSString.boolValue` has it: yes for what begins with Y, y, T, t or a digit from 1 to 9.
    public func bool(forKey key: String) -> Bool {
      switch object(forKey: key) {
      case let value as Bool: return value
      case let value as Int: return value != 0
      case let value as String: return value.first.map { "YyTt123456789".contains($0) } ?? false
      default: return false
      }
    }
    public func set(_ value: Bool, forKey key: String) { FakeMac.current.preferences[domain, default: [:]][key] = value }
    public func removeObject(forKey key: String) { FakeMac.current.preferences[domain]?[key] = nil }
    /// What is written is there at once: macOS obeys these switches within a second, and nothing here is told at that grain.
    @discardableResult public func synchronize() -> Bool { true }
  }
  public static func defaults(suiteName: String) -> Defaults? { Defaults(domain: suiteName) }

  /// What `getpid()` becomes in the copy: Arbor's own number on the model. Not that of the process the test runs in, which in a fresh container may be any small number, one of the
  /// model's apps' among them.
  public static func getpid() -> pid_t { 400 }

  /// What `kill(pid, 0)` becomes in the copy: whether the process is there. The model's pids are nobody's on the machine the test runs on.
  public static func kill(_ pid: pid_t, _ signal: Int32) -> Int32 {
    precondition(signal == 0, "the model's processes can only be asked whether they are there")
    if current.app(pid)?.isAlive == true { return 0 }
    errno = ESRCH
    return -1
  }

  // MARK: What the stand-ins for AppKit put in

  /// Posts a notification of `NSWorkspace`'s about an app. The model knows neither `NSRunningApplication` nor the centre; AppKit's stand-in does.
  public nonisolated(unsafe) static var postsWorkspaceNotification: (_ name: String, _ pid: pid_t?) -> Void = { _, _ in }
}

// MARK: - Delays

extension FakeMac {
  /// How long things take on a Mac that behaves. From the traces in collab/evidence/traces (macOS 26.6 on a hosted Mac) where one is named.
  public struct Timing {
    /// From an app's posting a notification to Arbor's observer. Echoes usually come 2 to 15 ms after the call, but 246 ms after it in `stubborn-slow`, and 0.3 to 0.55 s for
    /// Finder and Terminal (traces/README.md, row 1): `App.reportsLateBy`.
    public var report: TimeInterval = 0.002
    /// Between two notifications an app posts for one change. `minimize-restore`: 0.1 to 0.4 ms between echoes.
    public var betweenReports: TimeInterval = 0.0003
    /// From an app's coming forward to `didActivateApplication`. Guess; only what follows was measured.
    public var activationNotice: TimeInterval = 0.004
    /// `app-switch-unreported`, its second switch (an app brings itself forward, its focused window unchanged): `AXApplicationDeactivated` 0.6 ms after `didActivateApplication`,
    /// `AXApplicationActivated` 7.8 ms after it. Its first switch, where Arbor had asked for another window of the app, is another matter: `App.reportsFocusTwiceAndLate`.
    public var deactivatedAfterNotice: TimeInterval = 0.0006
    public var activatedAfterNotice: TimeInterval = 0.008
    /// From an event to the monitors. Guess.
    public var mouseEvent: TimeInterval = 0.001
    /// The second mouse-up: `click-title-bar` 15 ms after the first, `flick-to-edge` 33 ms.
    public var secondMouseUp: TimeInterval = 0.015
    /// `minimize-restore`: "miniaturized" 0.55 s after the click, "deminiaturized" 0.54 s after the app's call.
    /// At the end of the flight, if the window had its app's keyboard, the next window's focus is reported first: "focused window changed", "main window changed" 5.4 ms later, "miniaturized" 6.6 ms
    /// after the first; nothing in the 0.67 s before (a recording of a hosted Mac: origin/mac-shell-out/sweep.proof, sweep.jsonl, "s6 the control").
    public var focusBeforeMiniaturized: TimeInterval = 0.0066
    public var minimizing: TimeInterval = 0.55
    /// What was seen is Arbor's own `displaysChanged`, of a layer that passed every notice on at once: 20.4 and 15.3 ms after "miniaturized", 13.6 and 24.4 ms after
    /// "deminiaturized" (`minimize-restore`, `app-minimize`). The notice itself is in no trace.
    public var dockAfterMinimizing: TimeInterval = 0.018
    /// "Focused window changed" before "deminiaturized", raw line to raw line: 4.1 ms (`minimize-restore`), 8.3 ms (`app-minimize`).
    public var focusBeforeDeminiaturized: TimeInterval = 0.004
    /// `close` (plain AppKit windows): "focused window changed" to the next window 12 ms before "destroyed". Safari and Finder are otherwise: `App.dropsAClosingWindowAtOnce`.
    public var focusBeforeDestroyed: TimeInterval = 0.012
    /// `app-quits`: the window was reported gone 36 ms after the note that the app was told to quit.
    public var terminationNotice: TimeInterval = 0.036
    /// Guess.
    public var launchNotice: TimeInterval = 0.05
    /// The app learns of a drag about a tenth of a second after the window server (`drag-to-edge`: first "moved" 0.1 s after the first
    /// mouse-dragged), and posts five to nine "moved" a second: 0.113 to 0.201 s apart there, 6.6 a second on average. This is the least gap.
    public var dragReachesApp: TimeInterval = 0.1
    public var betweenMovedReports: TimeInterval = 0.11
    /// A Space transition, and where in it the notice comes ("in the middle": docs/ARCHITECTURE.md). The lengths are guesses.
    public var spaceTransition: TimeInterval = 0.7
    public var spaceNotice: TimeInterval = 0.35
    /// An animated frame change ("enhanced user interface"). Guess.
    public var animation: TimeInterval = 0.25
    /// One call that is answered. `took` in the traces: 2 ms for a `setFrame` of six or seven calls.
    public var answer: TimeInterval = 0.0003
  }

  /// Bad manners in general, for the random walk. Each is off at zero. Stories use the switches on apps and windows instead, which say
  /// exactly what happens.
  public struct Manners {
    /// (i) What is on its way may be held up by as much, so that different sources overtake each other.
    public var overtaking: TimeInterval = 0
    /// (ii) A cached answer (the app in front by NSWorkspace, an app's list of windows, the mouse button) may lag a change by as much.
    public var staleness: TimeInterval = 0
    /// (iii) The chance, of 1, that a notification comes twice; and that one macOS is known to drop is dropped.
    public var repeats: Double = 0
    public var drops: Double = 0
    /// (iv) A call may be carried out as much after it returned.
    public var lateCalls: TimeInterval = 0
    /// Where chance comes from. The walk puts its seeded generator here.
    public var dice: () -> UInt64 = { 0 }

    public init() {}

    /// A number from 0 up to 1.
    func fraction() -> Double { Double(dice() >> 11) / Double(1 << 53) }
    func chance(_ probability: Double) -> Bool { probability > 0 && fraction() < probability }
    /// Half the time none at all: a Mac is not rude all the time.
    func lag(upTo limit: TimeInterval) -> TimeInterval { limit > 0 && chance(0.5) ? fraction() * limit : 0 }
  }
}

// MARK: - Apps, windows, screens

extension FakeMac {
  public enum Policy: Int, Sendable { case regular = 0, accessory = 1, prohibited = 2 }

  public final class App {
    public let pid: pid_t
    public var name: String
    public var bundleID: String?
    /// May change while the app runs, and nothing says so (docs/ARCHITECTURE.md, "What counts as a window").
    public var policy: Policy
    public internal(set) var isAlive = true
    public internal(set) var isHidden = false
    /// Its main thread is taken: it answers no call and posts nothing. Over something of its own (`hang`), or because one of its windows is on its way to the Dock or out of it (`minimize`).
    public var isHung: Bool { hangsByItself || windowsInFlight > 0 }
    public internal(set) var hangsByItself = false
    public internal(set) var windowsInFlight = 0
    /// Every window it has, in the order they were made, those it has put away included.
    public internal(set) var windows: [Window] = []
    /// Its key window: where the keyboard is while the app is in front.
    public internal(set) var focused: Window?
    public internal(set) var main: Window?
    /// Set by assistive tools: every frame change is animated.
    public var hasEnhancedUserInterface = false

    // How it behaves.

    /// Until then it refuses observers: it is still launching.
    public var refusesObserversUntil: TimeInterval = 0
    /// "The focus is on it" is posted before "it was created". Seen on hosted Macs, a millisecond apart, for every window opened in a running app.
    public var reportsFocusBeforeCreated = false
    /// Posts no "created" for its new windows. Nobody has seen such an app; the layer must not depend on there being none.
    public var doesNotReportCreated = false
    /// A window that closes is off its list, and its element no longer valid, by the time the next window's focus is reported; "destroyed" comes a good while after. Safari and Finder, ⌘W on a
    /// second window, in recordings of hosted Macs (origin/mac-shell-out/test-an-ordinary-day.day and others): the layer, looking through the app's windows at the focus report, missed the closing
    /// one and said `destroyed` 4 to 13 ms, once 91 ms, BEFORE `focused`; the raw "destroyed" arrived only after both.
    public var dropsAClosingWindowAtOnce = false
    /// One call that it answers takes so long, instead of `Timing.answer`. With Safari and Finder the layer's work for one focus report took 100 to 190 ms (the same recordings).
    public var answersIn: TimeInterval?
    /// Everything it posts reaches Arbor so much later than usual (`Timing.report`).
    public var reportsLateBy: TimeInterval = 0
    /// A change of its focused window is posted twice over, and late: as in the first switch of `app-switch-unreported`, where Arbor had asked for a window of an app in the background. After
    /// `didActivateApplication`: "deactivated" of the other app 4.5 ms, "focused window changed" 8.5, "main window changed" 26.6, "focused" again 34.5, "main" again 41.3, "activated" 44.3 ms.
    public var reportsFocusTwiceAndLate = false
    /// New windows get their subrole so long after they are created.
    public var subroleComesAfter: TimeInterval = 0
    /// Its list of windows is so long behind every change. A window in plain view has been seen missing from its app's list (AXWindowSystem.swift, `rescan`); for
    /// how long nobody has measured.
    public var listLagsBy: TimeInterval = 0
    /// Whatever it is asked to set it says yes to at once, and carries out so much later: a read in between gets the old answer. Seen of Safari on its way out of full screen ("answers success to all three calls, reads back the
    /// old frame", docs/REALITY.md); in general, and for how long, a GUESS.
    public var carriesOutAfter: TimeInterval = 0
    /// A new size is applied so long after the call returned.
    public var appliesSizeAfter: TimeInterval = 0
    /// Posts no "moved" while a window is dragged, only one at the end.
    public var isSilentDuringDrags = false
    /// Takes no notice of `activate()`: since macOS 14 that is only a request.
    public var ignoresActivation = false
    /// It answers so many more calls and then hangs: in the middle of what Arbor is asking of it.
    public var hangsAfterCalls: Int?
    /// It hangs over the call itself, which it has taken from its queue (a window that takes seconds to lay itself out anew). Otherwise it hangs over something of its own a moment before, and the call waits in the
    /// queue like all that follow. The difference shows only if Arbor's process ends before the app wakes.
    public var hangsInTheMiddleOfThatCall = false

    // What has happened to it, for those who want to tell one cause of a fault from another.

    /// It has hung at some time since it last came forward, or came forward hanging or just woken.
    public internal(set) var hasHungInFront = false
    var wokeAt: TimeInterval = 0
    /// When the notice that it came forward was delivered, `NSWorkspace` still named another app.
    public internal(set) var noticeOutranTheProperty = false

    /// Calls it has answered and not carried out yet (`Manners.lateCalls`).
    var callsStillToCarryOut = 0
    /// How long Arbor's main thread has waited for it in vain since it last began to hang.
    public internal(set) var secondsWaitedForInThisHang: TimeInterval = 0

    /// What was asked of it, and what it would have posted, while it hung.
    /// `asked`: by Arbor, and whether the app was already at it when it began to hang, or had it still waiting in its queue.
    var backlog: [(label: String, asked: Asked, run: () -> Void)] = []
    enum Asked { case byNobody, waiting, underWay }
    /// The list of windows it still gives out although it has changed.
    var staleList: (until: TimeInterval, windows: [Window])?

    init(pid: pid_t, name: String, bundleID: String?, policy: Policy) {
      self.pid = pid
      self.name = name
      self.bundleID = bundleID
      self.policy = policy
    }
  }

  public final class Window {
    /// The window server's number.
    public let number: UInt32
    /// Which of the model's windows this is: what an Accessibility element holds on to.
    let serial: Int
    public unowned let app: App
    public var role: String? = "AXWindow"
    /// What it is when it shows. What Accessibility says depends on more (`subroleNow`).
    public var subrole: String? = "AXStandardWindow"
    var hasSubroleFrom: TimeInterval = 0
    public var title: String
    /// Where its app has it, which is what Accessibility answers.
    public internal(set) var frame: CGRect
    /// Where the window server has it. Ahead of `frame` during a drag.
    public internal(set) var bounds: CGRect
    public var minimumSize = CGSize(width: 120, height: 80)
    public var maximumSize = CGSize(width: 20_000, height: 20_000)
    public var isResizable = true
    /// traces/README.md, row 3: 32 for the test windows, 26 to 47 for real apps.
    public var titleBarHeight: CGFloat = 32
    /// On screen or in the Dock. False once it has closed.
    public internal(set) var isOpen = true
    /// The window server still has its number: true for as long as it is open, and after that for one that was only put away.
    public internal(set) var exists = true
    public internal(set) var isMinimized = false
    public internal(set) var isFullScreen = false
    public internal(set) var space: Int
    /// The Space it goes back to when it leaves full screen.
    var homeSpace: Int
    var frameBeforeFullScreen: CGRect = .zero
    /// Windows with the same number here are tabs of one native tab group. Only `isFrontTab` shows and is listed.
    public internal(set) var tabGroup: Int?
    public internal(set) var isFrontTab = true
    public var alpha = 1.0
    /// False for tooltips and macOS's helpers, which never become anybody's key window.
    public var canTakeKeyboard = true
    /// How often somebody outside its app has asked it for a place or a size.
    public internal(set) var timesAskedForAFrame = 0
    var lastMovedReport: TimeInterval = 0
    var owesMovedReport = false
    /// Until then it is in the middle of an animation (into the Dock, out of it, into full screen), and nobody can get hold of it.
    public internal(set) var isBusyUntil: TimeInterval = 0
    /// On its way to the Dock, or out of it (`minimize`).
    public internal(set) var isInFlight = false
    var isFlyingOut = false
    /// It has closed, and "destroyed" was never posted or got lost.
    public internal(set) var closedWithoutAWord = false
    /// By how much it is taller than the other tabs of its group (Terminal's first tab and its later ones differ by the tab bar).
    var extraHeightAsTab: CGFloat = 0
    /// Goes back to the frame it had so long after every move from outside (traces `stubborn-fast`, `stubborn-slow`).
    public var goesBackAfter: TimeInterval?

    init(number: UInt32, serial: Int, app: App, title: String, frame: CGRect, space: Int) {
      self.number = number
      self.serial = serial
      self.app = app
      self.title = title
      self.frame = frame
      self.bounds = frame
      self.space = space
      self.homeSpace = space
    }

    public var element: Element { .window(app.pid, serial) }
    /// A window of the kind Arbor arranges.
    public var isStandard: Bool { role == "AXWindow" && subrole == "AXStandardWindow" }
  }

  public struct Screen: Equatable, Sendable {
    public var id: UInt32
    public var name: String
    /// Global coordinates, top-left origin, like everything in the model. AppKit's stand-in turns them upside down.
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var isBuiltIn: Bool

    public init(id: UInt32, name: String, frame: CGRect, visibleFrame: CGRect, isBuiltIn: Bool = false) {
      self.id = id
      self.name = name
      self.frame = frame
      self.visibleFrame = visibleFrame
      self.isBuiltIn = isBuiltIn
    }

    /// The display of the hosted Macs the traces were recorded on.
    public static let hostedMac = Screen(
      id: 1, name: "Display", frame: CGRect(x: 0, y: 0, width: 1024, height: 768), visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674))
  }

  /// What an Accessibility element stands for.
  public enum Element: Hashable, Sendable {
    case nothing
    case systemWide
    case app(pid_t)
    case window(pid_t, Int)

    public var pid: pid_t? {
      switch self {
      case .app(let pid), .window(let pid, _): pid
      case .nothing, .systemWide: nil
      }
    }
  }

  public func app(_ pid: pid_t) -> App? { apps.first { $0.pid == pid } }
  public func window(_ number: UInt32) -> Window? { stack.first { $0.number == number } }
  /// Also one that has closed and is forgotten by everybody else.
  public func windowThatEverWas(_ number: UInt32) -> Window? { windowsBySerial.values.first { $0.number == number } }
  func window(for element: Element) -> Window? {
    if case .window(_, let serial) = element { windowsBySerial[serial] } else { nil }
  }

  // MARK: The truth, for those who check Arbor against it

  /// The windows Arbor should know: open, of the standard kind, of a regular app that runs, and not behind another tab.
  public var standardWindows: [Window] {
    stack.filter { $0.isOpen && $0.isStandard && $0.isFrontTab && $0.app.isAlive && $0.app.policy == .regular && $0.hasSubroleFrom <= now }
      .sorted { $0.number < $1.number }
  }

  /// The window with the keyboard.
  public var keyWindow: Window? { frontmost?.focused }

  public func isShowing(_ window: Window) -> Bool {
    window.isOpen && window.isFrontTab && !window.isMinimized && !window.app.isHidden && window.space == activeSpace
  }
}
