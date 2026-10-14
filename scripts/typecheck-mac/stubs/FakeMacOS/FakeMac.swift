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
    arbor = App(pid: getpid(), name: "Arbor", bundleID: "com.evbarleyg.arbor", policy: .accessory)
    apps = [arbor]
  }

  // MARK: What it consists of

  /// Arbor itself: the process that runs the test. An accessory app, never in front unless a story says so.
  public let arbor: App
  /// The apps that run, in the order they were launched.
  public internal(set) var apps: [App]
  var lastPID: pid_t = 500
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
  /// The apps that were in front, latest first: who comes forward when the one in front goes.
  var activationHistory: [App] = []

  public internal(set) var screens: [Screen] = [Screen.hostedMac]
  public internal(set) var mouse = Mouse()
  /// Whether Arbor has the Accessibility permission. Without it every call is refused with `apiDisabled`.
  public var isTrusted = true

  var observers: [Observer] = []
  var monitors: [Monitor] = []
  var monitorsMade = 0

  public var timing = Timing()
  public var manners = Manners()

  /// How long a call waits for an app whose element has no timeout of its own: what was set on the system-wide element, else six seconds.
  var processTimeout: TimeInterval = 6
  /// How many Accessibility calls Arbor has made, and how long it waited in them for apps that did not answer.
  public internal(set) var calls = 0
  public internal(set) var secondsWaitedInVain: TimeInterval = 0

  // MARK: The clock

  /// Seconds since this Mac started. It moves only in `pass`, and inside an Accessibility call.
  public internal(set) var now: TimeInterval = FakeMac.dawn
  static let dawn: TimeInterval = 10_000

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
    journal.append(String(format: "%9.4f  ", now - Self.dawn) + text())
  }

  /// Sends something on its way. With `manners.overtaking` it may be held up, so that what another source sent later arrives first.
  func send(after delay: TimeInterval, from source: Source, _ label: String, _ run: @escaping () -> Void) {
    var due = now + max(delay, 0)
    if case .sleeper = source {
      // Arbor's own timers are not macOS's to delay.
    } else {
      if manners.overtaking > 0 { due += manners.fraction() * manners.overtaking }
      due = max(due, lastDue[source] ?? 0)
      lastDue[source] = due
    }
    sent += 1
    pending.append(Pending(due: due, order: sent, source: source, label: label, run: run))
  }

  private func takeNext(until end: TimeInterval) -> Pending? {
    var best: Int?
    for (index, item) in pending.enumerated() where item.due <= end {
      if let current = best, (pending[current].due, pending[current].order) <= (item.due, item.order) { continue }
      best = index
    }
    return best.map { pending.remove(at: $0) }
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
  private var hasEnded = false

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
        if Task.isCancelled || hasEnded { return continuation.resume(throwing: CancellationError()) }
        sleepers[number] = continuation
        send(after: seconds, from: .sleeper(number), "") { [self] in sleepers.removeValue(forKey: number)?.resume() }
      }
    } onCancel: {
      self.sleepers.removeValue(forKey: number)?.resume(throwing: CancellationError())
    }
  }

  /// The story is over: nothing more is delivered, and every sleeping task wakes to find that out.
  public func end() {
    hasEnded = true
    pending.removeAll()
    Pump.runTasks()
    while !sleepers.isEmpty {
      for number in sleepers.keys.sorted() { sleepers.removeValue(forKey: number)?.resume(throwing: CancellationError()) }
      Pump.runTasks()
    }
  }

  // MARK: Processes

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
    /// From an app's posting a notification to Arbor's observer. Echoes come 2 to 15 ms after the call (traces/README.md, row 1).
    public var report: TimeInterval = 0.002
    /// Between two notifications an app posts for one change. `minimize-restore`: 0.1 to 0.4 ms between echoes.
    public var betweenReports: TimeInterval = 0.0003
    /// From an app's coming forward to `didActivateApplication`. Guess; only what follows was measured.
    public var activationNotice: TimeInterval = 0.004
    /// `AXApplicationDeactivated` came 0.6 ms after `didActivateApplication`, `AXApplicationActivated` 8 ms after it (hosted Macs, 2026-10-14).
    public var deactivatedAfterNotice: TimeInterval = 0.0006
    public var activatedAfterNotice: TimeInterval = 0.008
    /// From an event to the monitors. Guess.
    public var mouseEvent: TimeInterval = 0.001
    /// The second mouse-up: `click-title-bar` 15 ms after the first, `flick-to-edge` 33 ms.
    public var secondMouseUp: TimeInterval = 0.015
    /// `minimize-restore`: "miniaturized" 0.55 s after the click, "deminiaturized" 0.54 s after the app's call.
    public var minimizing: TimeInterval = 0.55
    /// `minimize-restore`: the screens' notice 15 to 20 ms after "miniaturized".
    public var dockAfterMinimizing: TimeInterval = 0.018
    /// `minimize-restore`: "focused window changed" 4 ms before "deminiaturized"; `app-minimize` 1 to 2 ms.
    public var focusBeforeDeminiaturized: TimeInterval = 0.002
    /// `close`: "focused window changed" to the next window 12 ms before "destroyed".
    public var focusBeforeDestroyed: TimeInterval = 0.012
    /// `app-quits`: the window was reported gone 36 ms after the note that the app was told to quit.
    public var terminationNotice: TimeInterval = 0.036
    /// Guess.
    public var launchNotice: TimeInterval = 0.05
    /// The app learns of a drag about a tenth of a second after the window server (`drag-to-edge`: first "moved" 0.1 s after the first
    /// mouse-dragged), and posts eight to ten "moved" a second (0.11 to 0.2 s apart there).
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
    /// Its main thread is stuck: it answers no call and posts nothing.
    public internal(set) var isHung = false
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
    /// New windows get their subrole so long after they are created.
    public var subroleComesAfter: TimeInterval = 0
    /// A new size is applied so long after the call returned.
    public var appliesSizeAfter: TimeInterval = 0
    /// Posts no "moved" while a window is dragged, only one at the end.
    public var isSilentDuringDrags = false
    /// Takes no notice of `activate()`: since macOS 14 that is only a request.
    public var ignoresActivation = false

    /// What was asked of it, and what it would have posted, while it hung.
    var backlog: [(label: String, run: () -> Void)] = []
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
    var lastMovedReport: TimeInterval = 0
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
