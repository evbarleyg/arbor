import ArborCore
import ArborKit
import CoreGraphics

/// An in-memory `WindowSystem`. Windows are plain values; the simulation
/// helpers (`open`, `close`, `userMove`, `drag`…) emit the same events macOS
/// would, so tests and arbor-sim exercise the real controller.
@MainActor
public final class FakeWindowSystem: WindowSystem {
  public weak var events: (any WindowSystemEvents)?

  public struct FakeWindow: Equatable {
    public var snapshot: WindowSnapshot {
      didSet {
        // Whatever moves a window, it is not Arbor, unless `setFrame` says so afterwards.
        guard snapshot.frame != oldValue.frame else { return }
        placeIsArborsDoing = false
        movesNotArbors += 1
        home = snapshot.frame
      }
    }
    /// The app refuses to make the window smaller than this.
    public var minimumSize: CGSize
    /// The app refuses to make the window larger than this.
    public var maximumSize: CGSize?
    /// The app sizes the window in steps of this (a terminal's character cells), see `setSizeStep`.
    public var sizeStep: CGSize?
    /// How the app treats the frames Arbor asks for (`FakeWindowSystem+Chaos.swift`).
    public var behaviour: Behaviour = .normal
    /// Where a window that snaps back returns to: the last frame it or the user chose.
    var home: CGRect?
    /// The last frame Arbor asked for, and the frame the window took.
    public internal(set) var lastRequest: (asked: CGRect, took: CGRect)?
    /// Where the window is now is Arbor's doing: Arbor put it there, or has heard of a change of
    /// displays since the user, the app or macOS did.
    public internal(set) var placeIsArborsDoing = false
    /// The displays have changed under it, with the window left at its old numbers, since Arbor last placed it.
    public internal(set) var groundHasShifted = false
    /// How often the user, the app or macOS has moved or resized it.
    public internal(set) var movesNotArbors = 0
    /// The app changed its ways since Arbor last asked it for anything.
    public internal(set) var changedItsWays = false

    public static func == (a: FakeWindow, b: FakeWindow) -> Bool {
      a.snapshot == b.snapshot && a.minimumSize == b.minimumSize && a.maximumSize == b.maximumSize
        && a.sizeStep == b.sizeStep && a.behaviour == b.behaviour
    }
  }

  public internal(set) var windows: [WindowID: FakeWindow] = [:]
  public var displayList: [DisplaySnapshot]
  public var focused: WindowID? {
    didSet {
      guard let focused else { return }
      keyboardOrder.removeAll { $0 == focused }
      keyboardOrder.insert(focused, at: 0)
    }
  }
  public var cursor: CGPoint = CGPoint(x: 720, y: 450) {
    didSet {
      pointerUsedAt = clock()
      if macClaim(at: cursor) != .menuBar { inMenuBarSince = nil } else if inMenuBarSince == nil { inMenuBarSince = clock() }
    }
  }
  /// Since when the pointer has been where macOS fills the screen, which it does only for a pointer that has rested there.
  private var inMenuBarSince: Double?
  public var mouseDown = false
  /// The window being resized by its edges until the mouse is released.
  public internal(set) var resizing: WindowID?
  public private(set) var started = false
  /// Every frame Arbor set, in order.
  public private(set) var frameLog: [(window: WindowID, frame: CGRect)] = []
  /// Where a person could have seen windows that Arbor or macOS moved, in order: the frame a window came out of full screen
  /// at (`leaveFullScreen`), and every frame Arbor gave a window that was in sight. A move nobody can see is not here.
  public fileprivate(set) var sightings: [(window: WindowID, frame: CGRect)] = []
  /// Windows that take only half of the next frame they are asked for (`leaveFullScreen`).
  fileprivate var hearHalfNext: Set<WindowID> = []
  /// Windows that are on the screen again after full screen, and that their apps do not list yet.
  fileprivate var inSightUnlisted: Set<WindowID> = []
  /// As on a Mac, `focus` takes effect only a moment later: at `finishSlowFocus()`.
  public var focusIsSlow = false
  public private(set) var slowFocus: WindowID?
  var nextID: UInt32 = 101
  /// Called before every frame Arbor sets takes effect, for apps whose answer depends on the question
  /// (change the window's minimum size here).
  public var willSetFrame: ((WindowID, CGRect) -> Void)?
  /// What macOS does without being asked (see "Echoes" below). A test that needs silence turns a switch off.
  public var echoes = Echoes()
  /// Called at the end of a helper that stands for several reports at once, so that work the controller put
  /// off until they are all in can run. `Harness` runs what is due now.
  public var afterEvents: (() -> Void)?
  /// Echoes that `deliverEchoes()` has not delivered yet.
  var undelivered: [Echo] = []
  /// With this on, echoes wait for `appsReact()` instead of arriving at the end of every helper and command, so
  /// that a script decides what else happens before they do.
  public var holdsEchoes = false
  /// Windows that had the keyboard, most recent first.
  fileprivate var keyboardOrder: [WindowID] = []
  fileprivate var framesBeforeFullScreen: [WindowID: CGRect] = [:]
  /// The last frame each of them, or its user, chose for itself.
  fileprivate var ownFramesBeforeFullScreen: [WindowID: CGRect] = [:]
  /// Windows whose app moves them back to a frame of its own a moment after anyone else moves them
  /// (`appsSettle()` is that moment).
  public var stubbornFrames: [WindowID: CGRect] = [:]
  /// Processes that do not answer: their windows cannot be moved.
  public private(set) var unresponsive: Set<Int32> = []
  /// Background tabs of native tab groups: alive, but not listed and not reported.
  public private(set) var backgroundTabs: [WindowID: FakeWindow] = [:]
  /// Accessibility permission has been taken away: nothing can be moved, focused or asked. Set it through
  /// `Harness.revokeAccessibility()`.
  public var isDenied = false
  /// How often Arbor tried to move or focus a window all the same.
  public private(set) var deniedCalls = 0
  /// `AXIsProcessTrusted()` goes on saying yes, as after Arbor was removed from the list with the − button.
  public var flagLags = false
  /// macOS refuses this process an event tap though it has the permission: the thorough way says no, everything else works.
  public var refusesTaps = false
  /// How often Arbor asked macOS for the permission, the dear way and the cheap way.
  public private(set) var questions = (thorough: 0, byTheFlag: 0)

  public func mayUseAccessibility(thoroughly: Bool) -> Bool {
    if thoroughly { questions.thorough += 1 } else { questions.byTheFlag += 1 }
    if thoroughly, refusesTaps { return false }
    return !isDenied || (flagLags && !thoroughly)
  }
  /// Windows that exist but are not listed, as on a Space that was not showing when Arbor started.
  public private(set) var unlisted: [WindowID: FakeWindow] = [:]
  /// The time in seconds, for `inputActivity()`. The harness points it at its scheduler's clock.
  public var clock: () -> Double = { 0 }
  private var pointerUsedAt = 0.0
  private var keyReleasedAt = -Double.infinity
  private var keyPresses: UInt32 = 0
  /// macOS's own tiling of dragged windows, which `endDrag` carries out as macOS does. On, as a Mac comes: what holds only with
  /// the switches off does not hold for most people.
  public var tiling = MacTiling.on
  /// The sizes windows had before macOS tiled them, which it gives back when they are dragged off their tiles.
  private var sizesBeforeTiles: [WindowID: CGSize] = [:]
  /// The modifier keys that are down. `hold` and `letGo` keep it; set it to let go of ⌃⌥ before the key.
  public var heldModifiers: KeyChord.Modifiers = []
  private var heldKeys: Set<KeyChord.Key> = []
  /// The app in front, as last announced by `activate`.
  public private(set) var frontmost: FrontmostApp?
  /// Windows that were brought to the front, most recently first (see `windowsFrontToBack`).
  var raised: [WindowID] = []
  /// Every window Arbor raised without focusing it, in order.
  public internal(set) var raiseLog: [WindowID] = []
  /// The window server does not answer: `windowsFrontToBack` is empty.
  public var stackingIsUnknown = false
  /// When each window that is flying out of the Dock lands (`Echoes.flightFromTheDock`).
  private var landings: [WindowID: Double] = [:]
  /// What `secondsSinceClickOrModifierKey()` answers. `userFocus` makes it 0 while it reports.
  public var secondsSinceInput = Double.infinity
  /// What Arbor last said about dialogs that open out of view.
  public private(set) var leavesStrayDialogs = false
  /// The apps that have a dialog waiting out of view, one entry each (`openStrayDialog`).
  public private(set) var strayDialogs: [String] = []
  /// The app Arbor said is in use, whose dialogs never wait.
  public private(set) var appWhoseDialogsNeverWait: String?
  fileprivate var nobodyTouchedAnything = false
  /// While macOS shows its desktop: where the window server lists each window that was swept aside
  /// (FakeWindowSystem+SweptAside.swift).
  var sweptAside: [WindowID: CGRect]?
  /// Makes `focus(_:)` take effect only at `settleFocus()`. On a real Mac the front app changes a moment after
  /// Arbor asks, and until then `focusedWindow()` gives the old answer.
  public var defersFocus = false
  /// Every window Arbor asked to give the keyboard to, in order.
  public private(set) var focusRequests: [WindowID] = []
  /// Windows the Accessibility layer does not report (a dialog, a panel, one of Arbor's own), in
  /// front of all the others, frontmost first.
  public var strangers: [StackedWindow] = []
  /// Every app Arbor asked to open, in order. Nothing opens by itself: call `open` for the window.
  public internal(set) var openRequests: [String] = []
  /// Apps that are not installed: `openApplication` refuses them.
  public var missingApps: Set<String> = []
  /// Every app Arbor asked to open, in order.
  public internal(set) var launchedApps: [String] = []
  /// Apps for which `launchApp` fails.
  public var unlaunchableApps: Set<String> = []
  /// With this on, a window that is un-minimized or unhidden says so only at `finishRestoring()`, as on
  /// macOS, where the report follows a moment after the request and other reports can overtake it.
  public var restoresLate = false
  var lateRestores: [WindowID] = []

  /// One `setFrame`, with where the window was before, so tests can tell moves that changed nothing.
  public struct Move: Equatable {
    public var window: WindowID
    public var requested: CGRect
    public var before: CGRect
    public var after: CGRect
    /// Announced with `moveTogether`, so its app worked beside the others.
    public var together: Bool
  }

  public struct Focus: Equatable {
    public var window: WindowID
    /// The window already had the keyboard focus.
    public var wasFocused: Bool
  }

  /// What Arbor asked of the window system, in order (Budget.swift counts it). On a Mac each move
  /// is several round trips to the window's app, each focus two and each read of the focus one or two.
  public private(set) var moveLog: [Move] = []
  public private(set) var focusLog: [Focus] = []
  public private(set) var focusedWindowReads = 0
  /// Lets simulated time pass while a drag rests at a point. `Harness` points it at its scheduler.
  public var passTime: ((Double) -> Void)?
  /// The window being dragged by its title bar, from `beginDrag` to `endDrag`: where it was and
  /// where on it the pointer took hold.
  var inHand: (window: WindowID, start: CGRect, grab: CGPoint)?
  /// A window system is free to ignore `moveTogether`. Nothing but the cost may differ.
  public var ignoresMoveTogether = false
  /// What came of the moves announced with `moveTogether`, until `setFrame` asks for it.
  public private(set) var answersAhead: [WindowID: (requested: CGRect, answer: CGRect?)] = [:]

  /// A 1440×900 display with a 25-point menu bar.
  public static let standardDisplay = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true, isBuiltIn: true)

  public init(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) {
    displayList = displays
  }

  // MARK: WindowSystem

  public func start() {
    started = true
    starts += 1
  }
  /// The real one lets go of every app, so what the apps were about to report of Arbor's last moves is never heard.
  public func stop() {
    started = false
    undelivered.removeAll()
  }
  /// How often it was started: each start of the real one asks every running app for its windows.
  public private(set) var starts = 0

  public func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? {
    guard windows[window]?.snapshot.pid == pid else { return nil }
    return setFrame(frame, of: window)
  }

  public func allWindows() -> [WindowSnapshot] {
    guard !isDenied else { return [] }
    return windows.values.map(\.snapshot).sorted { $0.id < $1.id }
  }

  public func displays() -> [DisplaySnapshot] { displayList }

  public func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? {
    if let ahead = answersAhead.removeValue(forKey: window), ahead.requested == frame { return ahead.answer }
    return move(window, to: frame, together: false)
  }

  public func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) {
    if ignoresMoveTogether { return }
    // Like the Accessibility layer: what nobody asked for is reported, so that nobody believes an old frame.
    let unclaimed = answersAhead.keys.sorted()
    answersAhead.removeAll()
    for window in unclaimed {
      if let snapshot = windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: false) }
    }
    for (window, frame) in frames { answersAhead[window] = (frame, move(window, to: frame, together: true)) }
  }

  private func move(_ window: WindowID, to frame: CGRect, together: Bool) -> CGRect? {
    willSetFrame?(window, frame)
    guard var fake = windows[window], !unresponsive.contains(fake.snapshot.pid) else { return nil }
    if isDenied {
      // Every call fails and the frame cannot be read back; the real window system has been known to answer
      // with the frame it was asked for, which is the worse of the two things it could say.
      deniedCalls += 1
      events?.accessibilityWasRefused()
      return frame
    }
    // macOS does not let a window in full screen be moved or resized.
    if fake.snapshot.isFullScreen {
      frameLog.append((window, fake.snapshot.frame))
      return fake.snapshot.frame
    }
    if let landing = landings[window], clock() < landing {
      frameLog.append((window, fake.snapshot.frame))
      return fake.snapshot.frame
    }
    var frame = frame
    // Its app places it between two of the calls a frame is set with: the size is taken, the position is the app's again.
    if hearHalfNext.remove(window) != nil { frame.origin = fake.snapshot.frame.origin }
    var applied = Self.accepted(frame, by: fake)
    if fake.behaviour != .frozen { applied = whereMacOSPuts(applied) }
    let changed = fake.snapshot.frame != applied
    moveLog.append(
      Move(window: window, requested: frame, before: fake.snapshot.frame, after: applied, together: together))
    let (home, moves) = (fake.home ?? fake.snapshot.frame, fake.movesNotArbors)
    fake.snapshot.frame = applied
    (fake.home, fake.movesNotArbors) = (home, moves)
    fake.lastRequest = (frame, applied)
    fake.placeIsArborsDoing = true
    fake.groundHasShifted = false
    fake.changedItsWays = false
    windows[window] = fake
    frameLog.append((window, applied))
    if changed, fake.snapshot.isPresent || inSightUnlisted.contains(window) { sightings.append((window, applied)) }
    if changed, echoes.frames, !undelivered.contains(.frame(window)) { undelivered.append(.frame(window)) }
    return applied
  }

  /// What macOS makes of a frame an app has agreed to (`echoes.titleBarStaysReachable`, `echoes.wholePoints`).
  public func whereMacOSPuts(_ frame: CGRect) -> CGRect {
    var applied = frame
    // The display the window's corner is on stops it. A point on a shared edge belongs to the display it is inside.
    if echoes.titleBarStaysReachable,
      let display = displayList.first(where: { $0.frame.contains(applied.origin) })
        ?? displayList.min(by: { $0.frame.distance(to: applied.origin) < $1.frame.distance(to: applied.origin) })
    {
      applied.origin.y = min(applied.minY, display.visibleFrame.maxY - 32)
    }
    if echoes.wholePoints {
      applied = CGRect(
        x: applied.minX.rounded(.down), y: applied.minY.rounded(.down), width: applied.width.rounded(.down),
        height: applied.height.rounded(.down))
    }
    return applied
  }

  public func focus(_ window: WindowID) {
    guard windows[window] != nil else { return }
    if isDenied {
      deniedCalls += 1
      events?.accessibilityWasRefused()
      return
    }
    focusLog.append(Focus(window: window, wasFocused: focused == window))
    focusRequests.append(window)
    guard !defersFocus else { return }
    if focusIsSlow {
      slowFocus = window
      return
    }
    // Its app comes forward, which brings back what macOS had swept aside.
    sweptAside = nil
    let moved = focused != window
    // macOS reports it two to four times when it crosses apps. Telling those apart is the Accessibility layer's job.
    if moved, echoes.focus { undelivered.append(.focus(window)) }
    focused = window
    bringToFront(window)
    // macOS reports the focus changes Arbor asks for like any other, a moment later.
    if moved { events?.keyboardFocusMoved() }
  }

  public func focusedWindow() -> WindowID? {
    focusedWindowReads += 1
    return isDenied ? nil : focused
  }

  public func cursorLocation() -> CGPoint { cursor }
  public func isMouseButtonDown() -> Bool { mouseDown }
  public func secondsSinceClickOrModifierKey() -> Double { secondsSinceInput }
  public func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) {
    leavesStrayDialogs = leave
    appWhoseDialogsNeverWait = leave ? inUse : nil
    strayDialogs.removeAll { !leave || $0 == inUse }
  }
  /// An app opens a dialog beside a window of its own that is out of view. Returns whether it waits there; otherwise it is
  /// in the middle of the display now (F47).
  @discardableResult
  public func openStrayDialog(ofApp bundleID: String) -> Bool {
    guard leavesStrayDialogs, bundleID != appWhoseDialogsNeverWait else { return false }
    strayDialogs.append(bundleID)
    return true
  }
  public func bringInStrayDialogs(ofApp bundleID: String?) { strayDialogs.removeAll { $0 == bundleID } }
  public func strayDialogsWaiting() -> Int { strayDialogs.count }
  public func modifierKeysDown() -> KeyChord.Modifiers { heldModifiers }
  public func macTiling() -> MacTiling { tiling }

  public func inputActivity() -> InputActivity {
    InputActivity(
      pointerIdle: clock() - pointerUsedAt, keyboardIdle: clock() - keyReleasedAt, keyPresses: keyPresses)
  }

  public func isHolding(_ chord: KeyChord) -> Bool {
    heldKeys.contains(chord.key) && heldModifiers.isSuperset(of: chord.modifiers)
  }

  // MARK: Simulation

  /// Opens a window and announces it (unless the system has not started, in
  /// which case it is simply there when the controller starts).
  @discardableResult
  public func open(
    app: String = "App", bundleID: String? = nil, title: String? = nil, pid: Int32 = 1000,
    frame: CGRect = CGRect(x: 300, y: 200, width: 640, height: 420), minimumSize: CGSize = .zero,
    isResizable: Bool = true
  ) -> WindowID {
    let id = WindowID(nextID)
    nextID += 1
    let snapshot = WindowSnapshot(
      id: id, pid: pid, bundleID: bundleID ?? "com.example.\(app.lowercased())", appName: app,
      title: title ?? "\(app) \(id.rawValue)", frame: frame, isResizable: isResizable)
    windows[id] = FakeWindow(
      snapshot: snapshot, minimumSize: isResizable ? minimumSize : frame.size, maximumSize: isResizable ? nil : frame.size)
    guard started else { return id }
    events?.windowAppeared(snapshot)
    // Created, then focused, in the same millisecond.
    if echoes.keyboard { giveKeyboard(to: id) }
    deliverEchoes()
    return id
  }

  public func close(_ window: WindowID) {
    // Nobody hears of a window that closes where the Accessibility API never saw it.
    if unlisted.removeValue(forKey: window) != nil { return }
    guard windows[window] != nil else { return }
    // The app's next window is reported focused before this one is reported gone.
    if focused == window { giveKeyboard(to: echoes.keyboard ? nextWindowOfApp(after: window) : nil) }
    windows[window] = nil
    keyboardOrder.removeAll { $0 == window }
    if inHand?.window == window { inHand = nil }
    events?.windowDestroyed(window)
    deliverEchoes()
  }

  public func setMinimized(_ window: WindowID, _ minimized: Bool) {
    guard windows[window] != nil else { return }
    // Either way the focus report comes first: of the app's next window, or of the window flying out of the Dock.
    if echoes.keyboard, started {
      if !minimized {
        giveKeyboard(to: window)
      } else if focused == window {
        giveKeyboard(to: nextWindowOfApp(after: window))
      }
    }
    windows[window]!.snapshot.isMinimized = minimized
    landings[window] = !minimized && echoes.flightFromTheDock > 0 ? clock() + echoes.flightFromTheDock : nil
    if restoresLate, !minimized { return lateRestores.append(window) }
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
    deliverEchoes()
  }

  public func setHidden(pid: Int32, _ hidden: Bool) {
    for id in windows.keys.sorted() where windows[id]!.snapshot.pid == pid {
      windows[id]!.snapshot.isHidden = hidden
      if restoresLate, !hidden {
        lateRestores.append(id)
        continue
      }
      events?.windowChanged(windows[id]!.snapshot, userInitiated: true)
    }
    // Another app comes forward, which is reported as its focused window taking the keyboard.
    if hidden, echoes.keyboard, let holder = focused, windows[holder]?.snapshot.pid == pid {
      giveKeyboard(to: keyboardOrder.first { canTakeKeyboard($0) && windows[$0]?.snapshot.pid != pid })
    }
    afterEvents?()
    deliverEchoes()
  }

  /// Moves a window's Space in or out of view, as switching Spaces does. Like
  /// the Accessibility layer, this reports the change without a user move.
  public func setOnActiveSpace(_ window: WindowID, _ onActiveSpace: Bool) {
    guard windows[window] != nil else { return }
    windows[window]!.snapshot.isOnActiveSpace = onActiveSpace
    events?.windowChanged(windows[window]!.snapshot, userInitiated: false)
  }

  public func setMinimumSize(_ window: WindowID, _ size: CGSize) {
    windows[window]?.minimumSize = size
  }

  /// The user (or another app) moves or resizes a window without Arbor.
  public func userMove(_ window: WindowID, to frame: CGRect) {
    guard windows[window] != nil else { return }
    windows[window]!.snapshot.frame = frame
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
  }

  /// The app changes a window's title, as browsers and editors do once a document has loaded.
  public func setTitle(_ window: WindowID, _ title: String) {
    unlisted[window]?.snapshot.title = title
    guard windows[window] != nil else { return }
    windows[window]!.snapshot.title = title
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
  }

  /// The user clicks a window or switches to it.
  public func userFocus(_ window: WindowID) {
    let before = secondsSinceInput
    if !nobodyTouchedAnything { secondsSinceInput = 0 }
    defer { secondsSinceInput = before }
    focused = window
    undelivered.removeAll { if case .focus = $0 { true } else { false } }
    activateApp(of: window)
    bringToFront(window)
    events?.windowFocused(window)
    deliverEchoes()
  }

  /// A key goes down, in whatever has the keyboard or as part of a shortcut.
  public func keyDown() { keyPresses &+= 1 }

  public func keyUp() { keyReleasedAt = clock() }

  /// The user presses a shortcut's modifiers and its key, and keeps them down.
  public func hold(_ chord: KeyChord) {
    heldModifiers.formUnion(chord.modifiers)
    heldKeys.insert(chord.key)
    keyDown()
  }

  /// The user lets go of the key, and of the modifiers too unless another key is still down with them
  /// or they are kept down for the next shortcut.
  public func letGo(_ chord: KeyChord, keepingModifiers: Bool = false) {
    guard heldKeys.remove(chord.key) != nil else { return }
    keyUp()
    if heldKeys.isEmpty, !keepingModifiers { heldModifiers = [] }
  }

  /// The user types a few characters into the focused window.
  public func type(keys: Int = 3) {
    for _ in 0..<max(keys, 0) {
      keyDown()
      keyUp()
    }
  }

  /// Drags a window by its title bar through `points` (global coordinates)
  /// and releases it at the last one. The window follows the pointer, which
  /// rests at each point for `seconds`: by default long enough for a drop
  /// target to activate (`dropDwell`). Pass 0 for a quick pass.
  public func drag(_ window: WindowID, through points: [CGPoint], holding seconds: Double = 0.3) {
    guard let first = points.first, windows[window] != nil else { return }
    beginDrag(window, at: first)
    for point in points.dropFirst() { moveDrag(to: point, holding: seconds) }
    endDrag()
  }

  /// The user brings an app to the front (⌘Tab, its Dock icon), whether or not it has a window. Like
  /// macOS, says nothing if the app is in front already.
  public func activate(bundleID: String?, name: String = "App") {
    let app = FrontmostApp(bundleID: bundleID, name: name)
    // Whoever comes forward, but for Finder with the desktop, brings back what macOS had swept aside.
    if bundleID != Self.finder { sweptAside = nil }
    guard app != frontmost else { return }
    frontmost = app
    events?.applicationActivated(app)
  }

  /// The window's app comes to the front, without a word about the window itself.
  public func activateApp(of window: WindowID) {
    guard let snapshot = windows[window]?.snapshot else { return }
    activate(bundleID: snapshot.bundleID, name: snapshot.appName)
  }

  public func setDisplays(_ displays: [DisplaySnapshot]) {
    displayList = displays
    for id in windows.keys { windows[id]!.placeIsArborsDoing = true }
    events?.displaysChanged()
  }

  // MARK: Inspection

  public func frame(of window: WindowID) -> CGRect? { windows[window]?.snapshot.frame }

  /// Whether at least half of the window is on some display.
  public func isVisible(_ window: WindowID) -> Bool {
    guard let frame = frame(of: window) else { return false }
    return displayList.contains { frame.fractionInside($0.frame) >= 0.5 }
  }

  public func clearFrameLog() { frameLog.removeAll() }
  public func clearSightings() { sightings.removeAll() }
  public func sightings(of window: WindowID) -> [CGRect] { sightings.filter { $0.window == window }.map(\.frame) }

  fileprivate func nextTabID() -> UInt32 {
    defer { nextID += 1 }
    return nextID
  }

  public func existingWindowIDs() -> Set<WindowID> { Set(windows.keys).union(unlisted.keys) }

  /// Takes a window off the list before Arbor starts (its Space is not showing), or puts it back
  /// (the user switched to its Space), which announces it as a window that was open all along.
  public func setListed(_ window: WindowID, _ listed: Bool) {
    if listed, let fake = unlisted.removeValue(forKey: window) {
      windows[window] = fake
      if started { events?.windowFound(fake.snapshot) }
    } else if !listed, let fake = windows.removeValue(forKey: window) {
      unlisted[window] = fake
    }
  }

  /// An app opens a window on a Space that is not showing: it exists, and nobody is told. `setListed(_:true)` is the
  /// user going there.
  @discardableResult
  public func openUnlisted(
    app: String = "App", bundleID: String? = nil, pid: Int32 = 1000,
    frame: CGRect = CGRect(x: 300, y: 200, width: 640, height: 420)
  ) -> WindowID {
    let id = WindowID(nextTabID())
    let snapshot = WindowSnapshot(
      id: id, pid: pid, bundleID: bundleID ?? "com.example.\(app.lowercased())", appName: app,
      title: "\(app) \(id.rawValue)", frame: frame)
    unlisted[id] = FakeWindow(snapshot: snapshot, minimumSize: .zero)
    return id
  }
}

// MARK: Opening apps

extension FakeWindowSystem {
  /// Records the request. The test (or `open` in arbor-sim) plays the app and opens the window.
  public func launchApp(_ name: String) -> Bool {
    guard !unlaunchableApps.contains(name) else { return false }
    launchedApps.append(name)
    return true
  }
}

// MARK: Focus that takes a moment

extension FakeWindowSystem {
  /// With `focusIsSlow`, what macOS does a moment after Arbor asked for focus: the last window asked for has
  /// it, and says so.
  public func finishSlowFocus() {
    guard let window = slowFocus else { return }
    slowFocus = nil
    guard windows[window] != nil else { return }
    userFocus(window)
  }
}

// MARK: Edge resizes

extension FakeWindowSystem {
  public func setMaximumSize(_ window: WindowID, _ size: CGSize?) {
    windows[window]?.maximumSize = size
  }

  /// The user drags `window`'s edges with the mouse until it has `frame`.
  /// Emits what the AX layer does: `resizeBegan` with the first change, then
  /// `windowChanged` while the button is down. Like a real app, the window
  /// stays within its minimum and maximum size: the dragged edge stops and the
  /// opposite edge stays put. With `release: false` the button stays down
  /// (call again to keep dragging) until `releaseMouse()`.
  public func userResize(_ window: WindowID, to frame: CGRect, release: Bool = true) {
    guard let fake = windows[window] else { return }
    if !mouseDown { events?.pointerPressed() }
    mouseDown = true
    if resizing != window {
      resizing = window
      events?.resizeBegan(window)
    }
    windows[window]!.snapshot.frame = Self.appResized(fake, toward: frame)
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
    if release { releaseMouse() }
  }

  /// Releases the mouse button. A resize in progress ends as the AX layer
  /// ends it: the window's final frame, then `resizeEnded`.
  public func releaseMouse() {
    mouseDown = false
    guard let window = resizing else { return }
    resizing = nil
    guard let snapshot = windows[window]?.snapshot else { return }
    events?.windowChanged(snapshot, userInitiated: true)
    events?.resizeEnded(window)
  }

  /// The frame an app gives a window whose edges are dragged toward `requested`.
  static func appResized(_ fake: FakeWindow, toward requested: CGRect) -> CGRect {
    let current = fake.snapshot.frame
    let maximum = fake.maximumSize ?? CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
    var frame = requested
    let width = min(max(requested.width, fake.minimumSize.width), maximum.width)
    if width != requested.width {
      // The edge that moved further is the one being dragged; the other stays.
      let leftDragged = abs(requested.minX - current.minX) > abs(requested.maxX - current.maxX)
      frame.origin.x = leftDragged ? requested.maxX - width : requested.minX
      frame.size.width = width
    }
    let height = min(max(requested.height, fake.minimumSize.height), maximum.height)
    if height != requested.height {
      let topDragged = abs(requested.minY - current.minY) > abs(requested.maxY - current.maxY)
      frame.origin.y = topDragged ? requested.maxY - height : requested.minY
      frame.size.height = height
    }
    return frame
  }
}

// MARK: Echoes

extension FakeWindowSystem {
  /// What macOS does without being asked, in the order it was recorded on macOS 26 (`collab/evidence/ax-events.txt`).
  /// Everything is on by default, so that every scenario meets it. What answers a call of Arbor's is queued and
  /// delivered after the call has returned, as from the run loop: `Harness.run` delivers after every
  /// command, the scheduler after each piece of work, the simulation helpers at their end. After a bare
  /// `controller.perform` or `overlays.clickTile`, call `deliverEchoes()` yourself.
  public struct Echoes: Sendable {
    /// Arbor's `focus(_:)` of a window that did not have the keyboard comes back as a focus report.
    public var focus = true
    /// Arbor's `setFrame` comes back as a change that nobody made by hand.
    public var frames = true
    /// The keyboard goes where macOS sends it: to a new window, to the app's next window when the focused one is
    /// closed or minimized, to another app when the focused one is hidden, to a window leaving the Dock.
    public var keyboard = true
    /// Frames are cut to whole points (150.5 becomes 150).
    public var wholePoints = true
    /// A window cannot be moved so low that its title bar is under the Dock or below the display: asked for
    /// 1023,767 on a display whose visible frame ends at 705, it stops at 1023,673.
    public var titleBarStaysReachable = true
    /// For this many seconds after a window leaves the Dock it is still flying: asked for a frame, it answers with the
    /// one it has and keeps it. 0, the default: not seen on a Mac so far (the report of the un-minimize seems to come
    /// when the flight is over), but nobody has looked at a slow Mac or with ⇧ held.
    public var flightFromTheDock = 0.0
    /// The same for the way back from full screen, which takes macOS longer. All the way it has not been seen either: see
    /// `leaveFullScreen`, which plays what has.
    public var flightFromFullScreen = 0.0

    public init() {}
    /// Nothing happens that a test did not ask for.
    public static var none: Echoes {
      var echoes = Echoes()
      (echoes.focus, echoes.frames, echoes.keyboard, echoes.wholePoints) = (false, false, false, false)
      echoes.titleBarStaysReachable = false
      return echoes
    }
  }

  enum Echo: Equatable {
    case focus(WindowID)
    case frame(WindowID)
  }

  /// Delivers what is queued, and what Arbor's reactions queue meanwhile. Returns how many focus reports
  /// there were: more than a few would be Arbor chasing its own tail.
  @discardableResult
  public func deliverEchoes() -> Int {
    guard !holdsEchoes else { return 0 }
    var focusReports = 0
    var rounds = 0
    while !undelivered.isEmpty, rounds < 100 {
      rounds += 1
      switch undelivered.removeFirst() {
      case .focus(let window):
        // Also when the keyboard has moved on since: macOS does not take a report back.
        guard windows[window] != nil else { continue }
        focusReports += 1
        // `focus` activates the window's app as well.
        if focused == window { activateApp(of: window) }
        events?.windowFocused(window)
      case .frame(let window):
        // Like the Accessibility layer, this reads the frame when the report arrives, not when it was sent.
        if let snapshot = windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: false) }
      }
    }
    return focusReports
  }

  /// The name this had when focus was the only echo.
  @discardableResult
  public func reportFocus() -> Int { deliverEchoes() }

  fileprivate func canTakeKeyboard(_ window: WindowID) -> Bool { windows[window]?.snapshot.isPresent == true }

  /// The window of the same app that macOS makes key when `window` goes: the one used last, or the newest.
  fileprivate func nextWindowOfApp(after window: WindowID) -> WindowID? {
    guard let pid = windows[window]?.snapshot.pid else { return nil }
    func fits(_ id: WindowID) -> Bool { id != window && windows[id]?.snapshot.pid == pid && canTakeKeyboard(id) }
    return keyboardOrder.first(where: fits) ?? windows.keys.sorted().last(where: fits)
  }

  /// macOS moves the keyboard and reports it at once. With nil the app stays in front with no window.
  func giveKeyboard(to window: WindowID?) {
    focused = window
    if let window { bringToFront(window) }
    if let window { events?.windowFocused(window) } else { events?.keyboardFocusMoved() }
  }

  /// An app that is not frontmost changes which of its windows is focused (a chat window opened
  /// by a notification, say). The Accessibility layer reports it like any focus change, but the
  /// keyboard stays where it was.
  public func backgroundFocus(_ window: WindowID) {
    guard windows[window] != nil else { return }
    events?.windowFocused(window)
    deliverEchoes()
  }
}

// MARK: Full screen

extension FakeWindowSystem {
  /// The user clicks the green button. Entering, the window grows to cover its display, on a Space
  /// of its own: switch the other windows' Space out of view with `setOnActiveSpace`. Leaving,
  /// it goes back to the frame it had. Both are reported as resizes nobody asked Arbor for.
  ///
  /// This is the report alone, and kinder than a Mac about the frame. `leaveFullScreen` plays the whole way out as one was seen to.
  public func setFullScreen(_ window: WindowID, _ fullScreen: Bool) {
    guard let fake = windows[window], fake.snapshot.isFullScreen != fullScreen else { return }
    if fullScreen {
      framesBeforeFullScreen[window] = fake.snapshot.frame
      ownFramesBeforeFullScreen[window] = fake.home ?? fake.snapshot.frame
      let center = CGPoint(x: fake.snapshot.frame.midX, y: fake.snapshot.frame.midY)
      let display = displayList.first { $0.frame.contains(center) } ?? displayList[0]
      windows[window]!.snapshot.frame = display.frame
    } else if let frame = framesBeforeFullScreen.removeValue(forKey: window) {
      ownFramesBeforeFullScreen[window] = nil
      windows[window]!.snapshot.frame = frame
    }
    windows[window]!.snapshot.isFullScreen = fullScreen
    landings[window] = !fullScreen && echoes.flightFromFullScreen > 0 ? clock() + echoes.flightFromFullScreen : nil
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
  }

  /// The way into full screen as a hosted Mac played it (⌃⌘F in Safari and TextEdit, ten rounds), `others` being the windows of the Space
  /// it leaves:
  ///
  ///     0 ms            macOS puts a stand-in on the app's list, which shows the animation. The window is off the list
  ///     1 to 4 ms       the window reports a resize: in full screen, as large as the display
  ///     470 to 620 ms   the Space is reported to have changed: the others are off their apps' lists, the window is on its app's again
  ///
  /// Until then the others are in plain view, under the animation.
  public func enterFullScreen(_ window: WindowID, leaving others: [WindowID]) {
    guard windows[window]?.snapshot.isFullScreen == false else { return }
    setOnActiveSpace(window, false)
    afterEvents?()
    passTime?(0.002)
    setFullScreen(window, true)
    afterEvents?()
    deliverEchoes()
    passTime?(0.5)
    for id in others.sorted() { setOnActiveSpace(id, false) }
    setOnActiveSpace(window, true)
    // As in `leaveFullScreen`.
    afterEvents?()
    if echoes.keyboard { giveKeyboard(to: window) }
    afterEvents?()
    deliverEchoes()
  }

  /// The way out of full screen as a hosted Mac played it with a docked Safari window (⌃⌘F, 2026-10-14), `others` being the
  /// windows of the Space that comes back:
  ///
  ///     0 ms    macOS puts a stand-in on the app's list, which shows the animation. The window is off the list, and off the screen.
  ///     2 ms    the window reports a resize: no longer in full screen, and already at the frame macOS gives it back. That is
  ///             not the one it had last, its slot: it is the one it had before Arbor ever moved it
  ///     690 ms  the stand-in goes, and the apps list their windows again, this one too
  ///     720 ms  the window is on the screen
  ///     830 ms  the Space is reported to have changed, which is when Arbor read the lists
  ///
  /// So "it has left" comes when the way out begins, and "it is back" a tenth of a second after everybody has seen it. (Since then the
  /// Accessibility layer reads the lists when the stand-in goes. The order stays: seen first, reported afterwards.)
  ///
  /// `whereItWas`: it lands at the frame it had last after all, be it a corner out of view. Nobody has seen a Mac do that, and
  /// nobody has seen that it never does; what Arbor does about it (Controller+LeftInFullScreen.swift) is tried with this.
  ///
  /// `deafFor`: asked for a frame in the first moments of its way out, it says yes and stays where it is. That is Safari, which places
  /// the window itself once more 0.06 to 0.17 s after the report; asked after that it takes the frame and keeps it. A frame is set
  /// with several calls, and Safari's own placing fell between them in three rounds of four: it had the new size at the old place, or
  /// the new place at the old size, and landed so. So the first frame that is heard here is heard by half. 0 is TextEdit, which
  /// takes it at once. Both land where they were last put. (`echoes.flightFromFullScreen`, deaf all the way, was a prediction,
  /// and has not been seen.)
  ///
  /// `othersFirst`: the change of Space is reported while the stand-in is still on the list, so the others are reported back 0.13 to
  /// 0.19 s before the window (Safari, five rounds of eight). Otherwise all at once (TextEdit).
  public func leaveFullScreen(
    _ window: WindowID, with others: [WindowID], whereItWas: Bool = false, deafFor: Double = 0.15, othersFirst: Bool = true
  ) {
    guard windows[window]?.snapshot.isFullScreen == true else { return }
    setOnActiveSpace(window, false)
    if !whereItWas, let own = ownFramesBeforeFullScreen[window] { framesBeforeFullScreen[window] = own }
    // Before the report: Arbor may answer it with a question.
    let flight = echoes.flightFromFullScreen
    echoes.flightFromFullScreen = max(flight, deafFor)
    if deafFor > 0 { hearHalfNext.insert(window) }
    setFullScreen(window, false)
    echoes.flightFromFullScreen = flight
    afterEvents?()
    deliverEchoes()
    passTime?(0.6)
    if othersFirst {
      for id in others.sorted() { setOnActiveSpace(id, true) }
      afterEvents?()
      deliverEchoes()
    }
    passTime?(0.12)
    hearHalfNext.remove(window)
    inSightUnlisted.insert(window)
    sightings.append((window, windows[window]!.snapshot.frame))
    passTime?(othersFirst ? 0.03 : 0.11)
    inSightUnlisted.remove(window)
    // One list after the other, in the order of the Accessibility layer's scan.
    for id in ((othersFirst ? [] : others) + [window]).sorted() { setOnActiveSpace(id, true) }
    // On a Mac the focus report comes in the same breath, before the layout that was put off. Not here: a strict replay runs what
    // is due between two reports of the same instant, and would part from the recording (docs/TRACES.md).
    afterEvents?()
    if echoes.keyboard { giveKeyboard(to: window) }
    afterEvents?()
    deliverEchoes()
  }
}

// MARK: Focus outside the known windows

extension FakeWindowSystem {
  /// The user clicks the desktop, or switches to something that is not one of these windows (a sheet, a
  /// panel, an app that is not observed).
  public func userFocusesNothing() {
    focused = nil
    events?.keyboardFocusMoved()
  }

  /// The user switches to another app with ⌘Tab or a click. The app's own focused window stays the
  /// same, so macOS sends no `windowFocused`.
  public func userSwitchesApp(to window: WindowID) {
    guard windows[window] != nil else { return }
    focused = window
    activateApp(of: window)
    bringToFront(window)
    events?.keyboardFocusMoved()
  }
}

// MARK: What else real apps do

extension FakeWindowSystem {
  /// A moment passes: apps that insist on a frame of their own move their windows back to it.
  public func appsSettle() {
    for (window, frame) in stubbornFrames.sorted(by: { $0.key < $1.key })
    where windows[window] != nil && windows[window]!.snapshot.frame != frame {
      userMove(window, to: frame)
    }
  }

  /// The process stops answering, or answers again. Like a real app, one that wakes up has something to
  /// report about its windows.
  public func setUnresponsive(pid: Int32, _ hung: Bool) {
    if hung {
      unresponsive.insert(pid)
    } else if unresponsive.remove(pid) != nil {
      for id in windows.keys.sorted() where windows[id]!.snapshot.pid == pid {
        events?.windowChanged(windows[id]!.snapshot, userInitiated: true)
      }
    }
  }

  /// Opens a new tab in `window`'s native tab group, in front: a new window at the same frame, while
  /// `window` stops being listed. Returns the new window. Terminal's windows grow by the height of the tab bar
  /// (`grownBy: 31`) when it first shows.
  @discardableResult
  public func openTab(in window: WindowID, title: String? = nil, grownBy growth: CGFloat = 0) -> WindowID? {
    guard let front = windows[window] else { return nil }
    let id = WindowID(nextTabID())
    var snapshot = front.snapshot
    snapshot.id = id
    snapshot.frame.size.height += growth
    snapshot.title = title ?? "\(front.snapshot.appName) \(id.rawValue)"
    backgroundTabs[window] = windows.removeValue(forKey: window)
    windows[id] = FakeWindow(snapshot: snapshot, minimumSize: front.minimumSize, maximumSize: front.maximumSize)
    if focused == window { focused = id }
    events?.windowReplaced(window, by: snapshot)
    return id
  }

  /// Brings the background tab `tab` to the front of the group `front` stands for.
  public func selectTab(_ tab: WindowID, insteadOf front: WindowID) {
    guard var fake = backgroundTabs.removeValue(forKey: tab), let old = windows.removeValue(forKey: front) else { return }
    fake.snapshot.frame = old.snapshot.frame
    backgroundTabs[front] = old
    windows[tab] = fake
    if focused == front { focused = tab }
    events?.windowReplaced(front, by: fake.snapshot)
  }

  /// Closes the tab in front. The tab `next` takes its place first, then the closed one is reported gone,
  /// the order seen on macOS 26.
  public func closeTab(_ front: WindowID, revealing next: WindowID) {
    selectTab(next, insteadOf: front)
    backgroundTabs[front] = nil
    events?.windowDestroyed(front)
  }

  /// The user is dragging `window` and the button's release is never seen.
  public func dragAndLoseTheRelease(_ window: WindowID, to point: CGPoint) {
    guard let start = windows[window]?.snapshot.frame else { return }
    mouseDown = true
    cursor = point
    events?.pointerPressed()
    events?.dragBegan(window, at: CGPoint(x: start.midX, y: start.minY + 10))
    windows[window]!.snapshot.frame.origin = CGPoint(x: point.x - start.width / 2, y: point.y - 10)
    events?.windowChanged(windows[window]!.snapshot, userInitiated: true)
    events?.dragMoved(window, to: point)
    mouseDown = false
    // macOS sees every release.
    if let letGo = windows[window]?.snapshot.frame { letMacOSTile(window, letGoAt: letGo) }
    events?.dragCancelled(window)
  }
}

// MARK: Sizes in steps

extension FakeWindowSystem {
  /// Makes `window` take only sizes that are whole steps, as Terminal does with its character cells. Like
  /// Terminal, it takes the size nearest to the one it is asked for, which can be the larger one.
  public func setSizeStep(_ window: WindowID, _ step: CGSize?) {
    windows[window]?.sizeStep = step
  }

  static func rounded(_ size: CGSize, toStepsOf step: CGSize) -> CGSize {
    CGSize(
      width: max(1, (size.width / step.width).rounded()) * step.width,
      height: max(1, (size.height / step.height).rounded()) * step.height)
  }
}

// MARK: Apps

extension FakeWindowSystem {
  /// The app quits: like the Accessibility layer, this reports each of its windows destroyed, in order.
  public func quit(pid: Int32) {
    for id in windows.keys.sorted() where windows[id]?.snapshot.pid == pid { close(id) }
  }
}

// MARK: Apps that come forward by themselves

extension FakeWindowSystem {
  /// An app brings itself forward (a calendar alert, a finished build, a chat mention): its window has the
  /// keyboard now, and the user touched nothing.
  public func comesForward(_ window: WindowID) {
    guard windows[window] != nil else { return }
    nobodyTouchedAnything = true
    defer { nobodyTouchedAnything = false }
    userFocus(window)
  }

  /// With `defersFocus`: the last window Arbor asked for gets the keyboard now, and macOS reports it.
  public func settleFocus() {
    guard let window = focusRequests.last, focused != window else { return }
    comesForward(window)
  }
}

// MARK: What the stage has to reckon with

extension FakeWindowSystem {
  public func stackedWindows() -> [StackedWindow] {
    strangers
      + windowsFrontToBack().compactMap { id in
        guard let snapshot = windows[id]?.snapshot, snapshot.isPresent else { return nil }
        return StackedWindow(id: id, frame: sweptAside?[id] ?? snapshot.frame)
      }
  }

  /// The user clicks somewhere: in a window's content, on anything that starts no drag.
  public func click() {
    events?.pointerPressed()
  }
}

// MARK: Traces

/// For trace replays, which deliver the recorded events themselves: these change the world and tell nobody.
extension FakeWindowSystem {
  /// Adds a window as a trace recorded it, with its own id, or replaces what is known about it.
  public func install(_ snapshot: WindowSnapshot) {
    if windows[snapshot.id] != nil {
      windows[snapshot.id]!.snapshot = snapshot
    } else {
      windows[snapshot.id] = FakeWindow(snapshot: snapshot, minimumSize: .zero)
    }
  }

  /// Puts a window at exactly `frame`, whatever its minimum and maximum size.
  public func place(_ window: WindowID, at frame: CGRect) {
    windows[window]?.snapshot.frame = frame
  }

  public func remove(_ window: WindowID) {
    windows[window] = nil
    if focused == window { focused = nil }
  }
}

// MARK: Drags, step by step

extension FakeWindowSystem {
  /// Presses the mouse on `window`'s title bar (10 points below its top, centred) and starts
  /// dragging it with the pointer at `point`, or where it took hold.
  public func beginDrag(_ window: WindowID, at point: CGPoint? = nil) {
    guard var start = windows[window]?.snapshot.frame else { return }
    let ownSize = takeSizeBeforeTile(of: window)
    if let ownSize {
      start = CGRect(x: (start.midX - ownSize.width / 2).rounded(), y: start.minY, width: ownSize.width, height: ownSize.height)
      windows[window]?.snapshot.frame = start
    }
    let grab = CGPoint(x: start.midX, y: start.minY + 10)
    inHand = (window, start, grab)
    mouseDown = true
    events?.pointerPressed()
    follow(point ?? grab)
    events?.dragBegan(window, at: point ?? grab)
    // Its app reports the size it has again, a moment after the window server has shown that it is being dragged.
    if ownSize != nil, let snapshot = windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: true) }
  }

  /// Moves the pointer, and the dragged window with it, to `point` and rests there for `seconds`.
  public func moveDrag(to point: CGPoint, holding seconds: Double = 0) {
    guard let window = inHand?.window else { return }
    follow(point)
    if let snapshot = windows[window]?.snapshot { events?.windowChanged(snapshot, userInitiated: true) }
    events?.dragMoved(window, to: point)
    holdDrag(for: seconds)
  }

  /// Keeps the pointer where it is for `seconds`.
  public func holdDrag(for seconds: Double) {
    if seconds > 0 { passTime?(seconds) }
  }

  /// Presses and releases modifier keys until exactly `keys` are held. During a drag the AX layer
  /// reports that as a move to the same point.
  public func holdModifierKeys(_ keys: KeyChord.Modifiers) {
    heldModifiers = keys
    if let window = inHand?.window { events?.dragMoved(window, to: cursor) }
  }

  /// Releases the mouse where the pointer is.
  public func endDrag() {
    mouseDown = false
    guard let window = inHand?.window else { return }
    inHand = nil
    let letGo = windows[window]?.snapshot.frame
    events?.dragEnded(window, at: cursor)
    if let letGo { letMacOSTile(window, letGoAt: letGo) }
  }

  /// Where macOS puts a window that is let go with the pointer at `point`, or nil where it leaves it alone. The
  /// halves, the quarters and the whole of the visible frame, where they were seen on a Mac (`MacTiling`).
  public func macTile(at point: CGPoint) -> CGRect? {
    guard let display = displayList.first(where: { $0.frame.contains(point) }), let claim = macClaim(at: point) else {
      return nil
    }
    let (frame, visible) = (display.frame, display.visibleFrame)
    guard claim != .menuBar else { return visible }
    var tile = visible
    tile.size.width = visible.width / 2
    if point.x >= visible.midX { tile.origin.x = visible.midX }
    guard claim == .side else { return tile }
    if point.y < visible.minY + 1 {
      tile.size.height = visible.height / 2
    } else if point.y >= frame.maxY - 1 {
      tile.size.height = visible.height / 2
      tile.origin.y = visible.midY
    }
    return tile
  }

  private func macClaim(at point: CGPoint) -> MacTiling.Claim? {
    guard let display = displayList.first(where: { $0.frame.contains(point) }) else { return nil }
    return tiling.claim(
      onWindowLetGoAt: point, on: display.frame, visibleFrame: display.visibleFrame,
      optionHeld: heldModifiers.contains(.option))
  }

  /// The size macOS gives back to a window that is dragged off the tile it put it in, once. Nil if it is in none.
  public func takeSizeBeforeTile(of window: WindowID) -> CGSize? { sizesBeforeTiles.removeValue(forKey: window) }

  /// What macOS does about a window that had the frame `start` when it was let go with the pointer where it is now. As seen on
  /// a Mac: Arbor hears of the release first and does what it does. Then macOS grows the window from where it was let go
  /// to the tile, over a third of a second, whatever has become of it meanwhile, and its app reports every step.
  ///
  /// Thrown into the menu bar and let go at once, the window is left alone (`MacTiling.menuBarRest`); at the sides macOS waits for
  /// nothing. A window that cannot take the tile's size keeps the nearest it can: one too small lies against the side of the
  /// screen, or in the middle of a screen it should have filled, half way up; one too large begins where the tile does.
  /// ⌥ means nothing for a window of a fixed size.
  public func letMacOSTile(_ window: WindowID, letGoAt start: CGRect) {
    guard var tile = macTile(at: cursor), let claim = macClaim(at: cursor), let fake = windows[window] else { return }
    if claim == .menuBar, clock() - (inMenuBarSince ?? clock()) < MacTiling.menuBarRest { return }
    if claim == .optionKey, fake.maximumSize == fake.minimumSize { return }
    let largest = fake.maximumSize ?? tile.size
    let size = CGSize(
      width: max(min(tile.width, largest.width), fake.minimumSize.width),
      height: max(min(tile.height, largest.height), fake.minimumSize.height))
    if size.width < tile.width {
      tile.origin.x = claim == .menuBar ? (tile.midX - size.width / 2).rounded() : tile.minX > start.midX ? tile.maxX - size.width : tile.minX
    }
    if size.height < tile.height { tile.origin.y = (tile.midY - size.height / 2).rounded() }
    tile.size = size
    sizesBeforeTiles[window] = start.size
    let halfway = CGRect(
      x: (start.minX + tile.minX) / 2, y: (start.minY + tile.minY) / 2, width: (start.width + tile.width) / 2,
      height: (start.height + tile.height) / 2
    ).integral
    for step in [halfway, tile] {
      passTime?(0.15)
      userMove(window, to: step)
    }
  }

  /// The button comes up and nobody sees it, until the AX layer finds it up and calls the drag off.
  public func loseTheReleaseOfTheDrag() {
    mouseDown = false
    guard let window = inHand?.window else { return }
    inHand = nil
    // macOS sees every release.
    if let letGo = windows[window]?.snapshot.frame { letMacOSTile(window, letGoAt: letGo) }
    events?.dragCancelled(window)
  }

  private func follow(_ point: CGPoint) {
    cursor = point
    guard let (window, start, grab) = inHand, windows[window] != nil else { return }
    windows[window]!.snapshot.frame.origin = CGPoint(
      x: start.minX + point.x - grab.x, y: start.minY + point.y - grab.y)
  }
}
