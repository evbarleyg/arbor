import AppKit
import ApplicationServices
import ArborCore
import CoreGraphics

/// The real `WindowSystem`: finds, observes and moves other apps' windows
/// through the Accessibility API, and watches the mouse to detect title-bar
/// drags. Requires Accessibility permission.
///
/// Observation model:
/// - one `AXObserver` per app, subscribed to window creation, focus and hide/show;
/// - per window, subscriptions to destroy/move/resize/minimize/title, each
///   registered with the window number as its refcon so the callback knows
///   which window it is even after the element is destroyed.
///
/// No test reaches this code, so it decides as little as it can: what counts as a window, an echo, a drag, a
/// tab or a reason to try again is decided by pure types in ArborCore (`WindowKind`, `EchoFilter`, `WindowGrab`,
/// `NativeTabs`, `FramePlan`, `RetrySchedule`, `AppThatCameForward`). What macOS does in each case was written down by a
/// Mac: see collab/reports/2026-10-14-review-ax.md.
@MainActor
public final class AXWindowSystem: WindowSystem {
  public weak var events: (any WindowSystemEvents)?
  /// While a trace is recorded it also gets every notification and mouse event as it arrives, before anything is made
  /// of it: the events above say what Arbor understood, these what macOS said (docs/TRACES.md).
  public var recorder: TraceRecorder?

  private let onlyPIDs: Set<pid_t>?
  private var apps: [pid_t: ObservedApp] = [:]
  private var records: [WindowID: WindowRecord] = [:]
  private var echoes = EchoFilter()
  private var tokens: [NSObjectProtocol] = []
  private var mouseMonitor: Any?
  private var localMouseMonitor: Any?
  /// Where the mouse button went down, and on which window. Nil while it is up.
  private var press: Press?
  private var draggingWindow: WindowID?
  private var resizingWindow: WindowID?
  /// The modifier keys held when the mouse event being handled happened; nil between events.
  private var eventModifiers: NSEvent.ModifierFlags?
  /// Where the button went down or came up, while that event is being handled. A hand recoils, and Arbor can be some way behind:
  /// one point decides whether a window is let go at the very edge of the display, where it is macOS's (`MacTiling`).
  private var eventLocation: CGPoint?
  private var running = false
  /// Numbers the drags and resizes, so that the check on one does not outlive it.
  private var grabNumber = 0
  /// Apps a retry is scheduled for.
  private var waitingToObserve: Set<pid_t> = []
  /// Apps that let a call time out. Nothing is asked of them until they answer again.
  private var unresponsive: Set<pid_t> = []
  private var pendingDisplayChange: Task<Void, Never>?
  private var pendingRescan: Task<Void, Never>?
  /// The window last reported as focused, so that the two or three notifications macOS posts for one
  /// change are reported once. Forgotten whenever another app comes forward.
  private var lastReportedFocus: WindowID?
  /// Counts the apps that came forward, to see whether a request to activate one had any effect.
  private var activations = 0
  /// The next look at an app that came forward before macOS named it as the one in front.
  private var lookAtAppThatCameForward: Task<Void, Never>?
  /// The displays as the controller last heard of them.
  private var reportedDisplays: [DisplaySnapshot] = []
  /// Windows to be looked at again once Arbor's move of them has settled (`EchoFilter.Verdict.early`).
  private var secondLooks: [WindowID: Task<Void, Never>] = [:]
  /// Whether dialogs that open out of view are left there for now, the app whose dialogs are not, and the ones that
  /// are waiting (F58).
  private var leavesStrayDialogs = false
  private var appWhoseDialogsNeverWait: String?
  private var waitingDialogs: [(element: AXUIElement, id: WindowID, pid: pid_t)] = []
  /// Dialogs that were brought into view. Each is moved once.
  private var broughtIntoView: Set<WindowID> = []

  /// How long one Accessibility call waits for an app, in seconds.
  private static let messagingTimeout: Float = 1

  fileprivate static weak var current: AXWindowSystem?

  private struct ObservedApp {
    let pid: pid_t
    let element: AXUIElement
    let observer: AXObserver
    let bundleID: String?
    let name: String
  }

  private struct WindowRecord {
    let element: AXUIElement
    var snapshot: WindowSnapshot
    /// Taken on while out of sight, when it could not be told from a dialog (`WindowKind.unconfirmed`).
    var isUnconfirmed = false
    /// A tab of a native tab group that is not in front. The controller does not know about it.
    var isBackgroundTab = false
  }

  /// - Parameter onlyPIDs: when set, observe only these processes (of any
  ///   activation policy). The end-to-end runner uses it.
  public init(onlyPIDs: Set<pid_t>? = nil) {
    self.onlyPIDs = onlyPIDs
  }

  /// Seconds on a clock that never goes backwards.
  private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

  // MARK: WindowSystem

  public func start() {
    guard !running else { return }
    running = true
    AXWindowSystem.current = self
    // For every element of every app, those made on the fly included (F17, H3). Elements that are kept
    // get the same timeout of their own as well.
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)
    reportedDisplays = displays()

    countWindows()
    for app in NSWorkspace.shared.runningApplications {
      observe(pid: app.processIdentifier, announce: false)
    }

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    tokens.append(
      workspaceCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) {
        [weak self] note in
        guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        else { return }
        MainActor.assumeIsolated { self?.observe(pid: pid, announce: true, attempt: 0) }
      })
    tokens.append(
      workspaceCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) {
        [weak self] note in
        guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        else { return }
        MainActor.assumeIsolated { self?.forget(pid: pid) }
      })
    tokens.append(
      workspaceCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) {
        [weak self] note in
        guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        else { return }
        MainActor.assumeIsolated { self?.appCameForward(pid) }
      })
    tokens.append(
      workspaceCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.spaceChanged() }
      })
    tokens.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.screensChanged() }
      })

    mouseMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .flagsChanged]
    ) {
      [weak self] event in
      let type = event.type
      let modifiers = event.modifierFlags
      let location = event.cgEvent?.location
      MainActor.assumeIsolated { self?.handleMouse(type, modifiers: modifiers, at: location) }
    }
    // Global monitors do not see events that go to Arbor's own panels (seams, tiles, the menu).
    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      MainActor.assumeIsolated { self?.pressLandedOnArbor() }
      return event
    }
  }

  public func stop() {
    guard running else { return }
    running = false
    for token in tokens {
      NSWorkspace.shared.notificationCenter.removeObserver(token)
      NotificationCenter.default.removeObserver(token)
    }
    tokens.removeAll()
    if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    mouseMonitor = nil
    if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
    localMouseMonitor = nil
    pendingRescan?.cancel()
    pendingDisplayChange?.cancel()
    pendingDisplayChange = nil
    screensWritten = nil
    screenFramesSeen = []
    lookAtAppThatCameForward?.cancel()
    for look in secondLooks.values { look.cancel() }
    secondLooks.removeAll()
    broughtIntoView.removeAll()
    waitingDialogs.removeAll()
    leavesStrayDialogs = false
    appWhoseDialogsNeverWait = nil
    reportedCreated.removeAll()
    standIns.removeAll()
    counted.removeAll()
    putAway.removeAll()
    press = nil
    draggingWindow = nil
    resizingWindow = nil
    grabNumber += 1
    lastReportedFocus = nil
    for pid in Array(apps.keys) { forget(pid: pid, announce: false) }
    // `pause` stops and `resume` starts again: nothing of this run may colour the next.
    waitingToObserve.removeAll()
    unresponsive.removeAll()
  }

  public func allWindows() -> [WindowSnapshot] {
    records.values.filter { !$0.isBackgroundTab }.map(\.snapshot).sorted { $0.id < $1.id }
  }

  /// The numbers of all apps' windows the window server has, on whichever Space. The Accessibility API lists only what
  /// shows, so this is how a saved window on another Space is told from one that has closed.
  public func existingWindowIDs() -> Set<WindowID> {
    guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else { return [] }
    var existing = Set<WindowID>()
    for info in list where (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0 {
      if let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value { existing.insert(WindowID(number)) }
    }
    return existing
  }

  public func displays() -> [DisplaySnapshot] {
    let screens = NSScreen.screens
    return screens.enumerated().map { index, screen in
      DisplaySnapshot(
        id: ScreenGeometry.displayID(for: screen),
        frame: ScreenGeometry.global(fromAppKit: screen.frame),
        visibleFrame: ScreenGeometry.global(fromAppKit: screen.visibleFrame),
        isMain: index == 0, name: screen.localizedName, isBuiltIn: ScreenGeometry.isBuiltIn(screen))
    }
  }

  public func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? {
    guard let record = records[window], answers(record.snapshot.pid) else { return nil }
    // macOS accepts a new size for a full-screen window and does nothing.
    guard !record.snapshot.isFullScreen else { return record.snapshot.frame }
    let element = record.element
    let appElement = apps[record.snapshot.pid]?.element
    let began = uptime

    // Apps with "enhanced user interface" on (set by assistive tools) animate
    // every frame change; turn it off while we move the window.
    var enhanced = false
    if let answer = appElement?.read("AXEnhancedUserInterface") {
      // An app that is silent now will be silent for the five calls to come. One wait is enough.
      if answer.error == .cannotComplete { return gaveUp(on: record.snapshot.pid, since: began) }
      // Not the app's silence: Arbor's permission is gone (Controller+Permission.swift). The calls to come would be
      // refused as well.
      if answer.error == .apiDisabled {
        events?.accessibilityWasRefused()
        return nil
      }
      if let value = answer.value, CFGetTypeID(value) == CFBooleanGetTypeID() {
        enhanced = CFBooleanGetValue((value as! CFBoolean))
      }
    }
    if enhanced { appElement?.setBool("AXEnhancedUserInterface", false) }

    var steps = FramePlan.steps(from: record.snapshot.frame, to: frame)
    var result = perform(steps, toward: frame, on: element)
    if let taken = result, FramePlan.needsFullPlan(after: steps, result: taken, target: frame) {
      steps = FramePlan.full
      result = perform(steps, toward: frame, on: element)
    }

    // Also when the app fell silent half way: a call that times out is still delivered when the app wakes up.
    if enhanced { appElement?.setBool("AXEnhancedUserInterface", true) }

    // Nothing is known about a window whose frame cannot be read back. Saying that it took the frame would
    // keep Arbor from ever trying again.
    guard let actual = result else { return gaveUp(on: record.snapshot.pid, since: began) }
    echoes.expect(actual, for: window, at: uptime)
    records[window]?.snapshot.frame = actual
    return actual
  }

  /// Sets the attributes a plan names and reads the frame back. Nil if the app did not answer. A refusal
  /// (a window with a fixed size, say) is an answer: the frame read back shows what came of it.
  private func perform(_ steps: [FramePlan.Step], toward frame: CGRect, on element: AXUIElement) -> CGRect? {
    for step in steps {
      let error = step == .size ? element.setSize(frame.size) : element.setPosition(frame.origin)
      if error == .cannotComplete { return nil }
      if error == .apiDisabled {
        events?.accessibilityWasRefused()
        return nil
      }
    }
    return element.frame
  }

  public func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? {
    guard !running else { return setFrame(frame, of: window) }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, Self.messagingTimeout)
    guard let element = app.elements(kAXWindowsAttribute).first(where: { $0.windowID == window }) else {
      // The long way round, which asks every app.
      start()
      defer { stop() }
      return setFrame(frame, of: window)
    }
    AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    // macOS accepts a new size for a full-screen window and does nothing.
    guard element.bool("AXFullScreen") != true else { return element.frame }
    return perform(FramePlan.full, toward: frame, on: element)
  }

  public func focus(_ window: WindowID) {
    guard let record = records[window], answers(record.snapshot.pid) else { return }
    let pid = record.snapshot.pid
    let began = uptime
    let answer = record.element.setBool(kAXMainAttribute, true)
    if answer == .apiDisabled {
      events?.accessibilityWasRefused()
      return
    }
    guard answer != .cannotComplete else {
      noteSilence(of: pid, since: began)
      return
    }
    AXUIElementPerformAction(record.element, kAXRaiseAction as CFString)
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier != pid else { return }
    NSRunningApplication(processIdentifier: pid)?.activate()

    // Since macOS 14 activation is cooperative, and a request from an app in the background may be ignored. It has
    // not been seen to be (macOS 26), but if no app at all has come forward a moment later, the app is asked
    // to bring itself forward, which is what System Events' `set frontmost` does.
    let before = activations
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard let self, self.running, self.activations == before, self.answers(pid), let app = self.apps[pid],
        NSWorkspace.shared.frontmostApplication?.processIdentifier != pid
      else { return }
      Log.debug("pid \(pid) did not come forward when activated; asking it through Accessibility")
      app.element.setBool(kAXFrontmostAttribute, true)
    }
  }

  public func raise(_ window: WindowID) {
    guard let record = records[window] else { return }
    AXUIElementPerformAction(record.element, kAXRaiseAction as CFString)
  }

  public func focusedWindow() -> WindowID? {
    // An app that is not observed has no window Arbor knows, and Arbor itself would be asking its own busy main
    // thread. One that hangs is not asked either.
    guard let front = NSWorkspace.shared.frontmostApplication, let app = apps[front.processIdentifier],
      answers(front.processIdentifier)
    else { return nil }
    return app.element.element(kAXFocusedWindowAttribute)?.windowID
  }

  public func cursorLocation() -> CGPoint {
    eventLocation ?? ScreenGeometry.global(fromAppKit: NSEvent.mouseLocation)
  }

  public func isMouseButtonDown() -> Bool {
    NSEvent.pressedMouseButtons & 1 != 0
  }

  /// The window server keeps these times for every process; asking needs no permission and taps nothing.
  public func secondsSinceClickOrModifierKey() -> Double {
    let kinds: [CGEventType] = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .flagsChanged]
    return kinds.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? .infinity
  }

  public func setMinimized(_ window: WindowID, _ minimized: Bool) {
    guard let record = records[window], answers(record.snapshot.pid) else { return }
    let began = uptime
    if record.element.setBool(kAXMinimizedAttribute, minimized) == .cannotComplete {
      noteSilence(of: record.snapshot.pid, since: began)
    }
  }

  public func unhideApp(pid: Int32) {
    NSRunningApplication(processIdentifier: pid)?.unhide()
  }

  public func macTiling() -> MacTiling { MacFacts.tiling }

  public func modifierKeysDown() -> KeyChord.Modifiers {
    // People let go of the key and the button together, and by the time Arbor hears of the
    // mouse-up the key can be up as well. What counts is what was held when it happened.
    let flags = eventModifiers ?? NSEvent.modifierFlags
    var held: KeyChord.Modifiers = []
    if flags.contains(.command) { held.insert(.command) }
    if flags.contains(.shift) { held.insert(.shift) }
    if flags.contains(.option) { held.insert(.option) }
    if flags.contains(.control) { held.insert(.control) }
    return held
  }

  // MARK: Apps

  private func shouldObserve(_ app: NSRunningApplication) -> Bool {
    if app.processIdentifier == getpid() { return false }
    if let onlyPIDs { return onlyPIDs.contains(app.processIdentifier) }
    return app.activationPolicy == .regular
  }

  /// Starts observing an app. Apps that just launched may not accept
  /// observers yet, so registration is retried (`RetrySchedule`). `wasRunning`: the app has not just been launched, so
  /// the windows it turns out to have were open all along.
  private func observe(pid: pid_t, announce: Bool, wasRunning: Bool = false, attempt: Int = 0) {
    guard running, apps[pid] == nil, let app = NSRunningApplication(processIdentifier: pid),
      shouldObserve(app)
    else { return }

    let element = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    var observerRef: AXObserver?
    guard AXObserverCreate(pid, axObserverCallback, &observerRef) == .success, let observer = observerRef else {
      retryObserve(pid: pid, announce: announce, wasRunning: wasRunning, attempt: attempt)
      return
    }

    // Without these two there is nothing to go by.
    for name in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification] {
      let result = AXObserverAddNotification(observer, element, name as CFString, nil)
      // The first refusal says it all; an app that hangs would make each further try wait as long.
      guard result == .success || result == .notificationAlreadyRegistered else {
        retryObserve(pid: pid, announce: announce, wasRunning: wasRunning, attempt: attempt)
        return
      }
    }
    // An app that does not know one of these is still worth observing. Choosing a native tab posts nothing
    // but "main window changed".
    for name in [
      kAXMainWindowChangedNotification, kAXApplicationHiddenNotification, kAXApplicationShownNotification,
      kAXApplicationActivatedNotification, kAXApplicationDeactivatedNotification,
    ] {
      AXObserverAddNotification(observer, element, name as CFString, nil)
    }
    // Common modes: in the default mode alone, notifications would wait while Arbor's menu is open.
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    apps[pid] = ObservedApp(
      pid: pid, element: element, observer: observer, bundleID: app.bundleIdentifier,
      name: app.localizedName ?? app.bundleIdentifier ?? "App")

    for window in element.elements(kAXWindowsAttribute) {
      addWindow(window, pid: pid, announce: announce, wasOpenBefore: wasRunning)
    }
  }

  private func retryObserve(pid: pid_t, announce: Bool, wasRunning: Bool, attempt: Int) {
    guard let delay = RetrySchedule.delay(beforeRetry: attempt) else {
      Log.debug("gave up observing pid \(pid); it gets another chance when it comes forward")
      return
    }
    guard waitingToObserve.insert(pid).inserted else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      self?.waitingToObserve.remove(pid)
      // The controller read the list of windows long ago, so whatever turns up now has to be announced,
      // also when the first try was part of the start. Then the app was running before Arbor was.
      self?.observe(pid: pid, announce: true, wasRunning: wasRunning || !announce, attempt: attempt + 1)
    }
  }

  private func forget(pid: pid_t, announce: Bool = true) {
    unresponsive.remove(pid)
    waitingDialogs.removeAll { $0.pid == pid }
    guard let app = apps.removeValue(forKey: pid) else { return }
    CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(app.observer), .commonModes)
    let gone = windowIDs(of: pid)
    for window in gone {
      let known = records.removeValue(forKey: window)?.isBackgroundTab == false
      echoes.forget(window)
      forgetGrab(of: window)
      if announce, known { events?.windowDestroyed(window) }
    }
  }

  private func windowIDs(of pid: pid_t) -> [WindowID] {
    records.filter { $0.value.snapshot.pid == pid }.map(\.key).sorted()
  }

  /// An app became the active one. Switching apps posts no "focused window changed" (the app's focused window is
  /// the one it was), so this is the only sign that the user went to another window with ⌘Tab, the Dock or a
  /// click. It is also a second chance to observe an app: one that became a regular app only after launch, for
  /// which no launch notification is posted, or one that was too slow for the retries. Only the focused window
  /// counts, not the main one: a click on the wallpaper activates Finder without asking for its last window.
  private func appCameForward(_ pid: pid_t) {
    // The only sign of ⌘Tab, and it comes before or after what Accessibility says about the focus.
    recorder?.raw("didActivateApplication pid \(pid)")
    activations += 1
    lastReportedFocus = nil
    if apps[pid] == nil, !waitingToObserve.contains(pid) { observe(pid: pid, announce: true, wasRunning: true) }
    // Whoever came forward before has been overtaken.
    lookAtAppThatCameForward?.cancel()
    reportFocus(ofAppThatCameForward: pid, earlierLooks: 0)
  }

  /// Reports the focused window of `pid` as soon as macOS names it as the app in front (`AppThatCameForward`).
  private func reportFocus(ofAppThatCameForward pid: pid_t, earlierLooks: Int) {
    let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
    switch AppThatCameForward.verdict(isNamedInFront: front == pid, earlierLooks: earlierLooks) {
    case .report:
      if earlierLooks > 0 { recorder?.raw("frontmostApplication names pid \(pid)") }
      reportFocus(of: pid)
    case .lookAgain(let seconds):
      if earlierLooks == 0 {
        recorder?.raw("frontmostApplication still names pid \(front ?? -1)")
        Log.debug("pid \(pid) came forward, and macOS still names another app as the one in front")
      }
      lookAtAppThatCameForward = Task { @MainActor [weak self] in
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        guard !Task.isCancelled, let self, self.running else { return }
        self.reportFocus(ofAppThatCameForward: pid, earlierLooks: earlierLooks + 1)
      }
    case .giveUp:
      Log.debug("pid \(pid) came forward and was never named as the app in front: nothing is reported")
    }
  }

  // MARK: Apps that do not answer

  /// Every call is synchronous, on the main thread, and waits up to `messagingTimeout` for the app. Moving one
  /// window takes six calls, so a hung app with three docked windows used to stop Arbor for some twenty seconds
  /// at every layout. Now the first call that times out ends the conversation: nothing more is asked of the app
  /// until it answers a call made off the main thread, or posts a notification.
  private func answers(_ pid: pid_t) -> Bool { !unresponsive.contains(pid) }

  private func gaveUp(on pid: pid_t, since began: TimeInterval) -> CGRect? {
    noteSilence(of: pid, since: began)
    return nil
  }

  /// Called when a call came back without an answer. A process that made Arbor wait is hung. One that is gone fails at
  /// once; its end is usually reported, but not that of an accessory app or one started from a shell, whose windows
  /// would stay in the tree as ghosts.
  private func noteSilence(of pid: pid_t, since began: TimeInterval) {
    guard uptime - began >= TimeInterval(Self.messagingTimeout) / 2 else {
      if kill(pid, 0) != 0, errno == ESRCH {
        // Not from here: the caller may be the controller, in the middle of a layout.
        Task { @MainActor [weak self] in
          guard let self, self.apps[pid] != nil else { return }
          Log.info("pid \(pid) is gone without a word; forgetting its windows")
          self.forget(pid: pid)
        }
      }
      return
    }
    guard unresponsive.insert(pid).inserted else { return }
    Log.info("pid \(pid) does not answer; leaving its windows alone until it does")

    // The task alone uses this element.
    let element = MainActorBox(value: AXUIElementCreateApplication(pid))
    Task.detached { [weak self] in
      // About a minute and a half. After that Arbor finds out for itself, at the price of one more wait.
      var tries = 0
      var answered = false
      while !answered, tries < 60 {
        tries += 1
        try? await Task.sleep(nanoseconds: 500_000_000)
        var value: CFTypeRef?
        answered = AXUIElementCopyAttributeValue(element.value, kAXRoleAttribute as CFString, &value) != .cannotComplete
      }
      await self?.answersAgain(pid)
    }
  }

  /// The app is talking again. What was asked of it in vain has to be made up for: reporting its windows
  /// makes the controller place the ones it could not move.
  private func answersAgain(_ pid: pid_t) {
    guard unresponsive.remove(pid) != nil, running, apps[pid] != nil else { return }
    Log.info("pid \(pid) answers again")
    for window in windowIDs(of: pid) { refresh(window, userInitiated: true) }
    rescan([pid], afterSpaceSwitch: false)
  }

  // MARK: Displays

  /// For a trace: the displays as AppKit shows them at this moment, whenever they are not as they were last written. Arbor is told of a
  /// change of displays only once it has settled (`DisplayChange`), and until then takes no window's move for the person's. So when
  /// a lid closes it matters in which order AppKit's own list and the windows' moves change, to the millisecond, and only a Mac can say.
  /// Ids and frames, no names.
  private func noteScreens(_ recorder: TraceRecorder) {
    // It is looked at with every notification, sixty times a second in a drag, and `displays()` asks for ids and names. AppKit's own frames
    // are relative to the primary display, so they change whenever the set, a size, a corner or the primary display does.
    let frames = NSScreen.screens.map(\.frame)
    guard frames != screenFramesSeen else { return }
    screenFramesSeen = frames
    let screens = displays().map { display in
      "\(display.id.rawValue) \(Int(display.frame.minX)),\(Int(display.frame.minY)) \(Int(display.frame.width))x\(Int(display.frame.height))"
    }.joined(separator: "; ")
    guard screens != screensWritten else { return }
    screensWritten = screens
    recorder.raw("screens \(screens)")
  }
  private var screensWritten: String?
  private var screenFramesSeen: [CGRect] = []

  /// macOS posts this at every minimize, and several times in a row when a display comes or goes. `DisplayChange` says
  /// whether there is anything to report and how long to wait; if the displays are by then as they were (a display that
  /// blinked on wake), nothing is reported at all.
  private func screensChanged() {
    recorder?.raw("didChangeScreenParameters")
    if let recorder, recorder.isRecording { noteScreens(recorder) }
    pendingDisplayChange?.cancel()
    pendingDisplayChange = nil
    guard let delay = DisplayChange.settleTime(from: reportedDisplays, to: displays()) else { return }
    pendingDisplayChange = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled, let self, self.running else { return }
      // Not cancelled, so this is the one that is pending, and from here it runs to its end in one go. (Not in a `defer`: a cancelled one that
      // wakes up would take away the one that replaced it.) `handle` goes by this to tell whether the displays are unsettled.
      self.pendingDisplayChange = nil
      let current = self.displays()
      guard DisplayChange.settleTime(from: self.reportedDisplays, to: current) != nil else { return }
      self.reportedDisplays = current
      self.refreshFrames()
      self.events?.displaysChanged()
    }
  }

  /// Reads every window's frame again. When the primary display changes, so do the coordinates of every window, and
  /// apps post nothing about it.
  private func refreshFrames() {
    for window in records.keys.sorted() {
      guard let record = records[window], answers(record.snapshot.pid) else { continue }
      let began = uptime
      if let frame = record.element.frame {
        records[window]?.snapshot.frame = frame
      } else {
        noteSilence(of: record.snapshot.pid, since: began)
      }
    }
  }

  // MARK: What the apps list

  /// Brings the window list up to date after a Space switch (entering and leaving full screen is one too). The
  /// notification comes in the middle of the transition, when apps have been seen to list neither the old windows
  /// nor the new ones, so the lists are read now, for a prompt layout, and once more when the transition is over.
  private func spaceChanged() {
    recorder?.raw("activeSpaceDidChange")
    rescan(Array(apps.keys), afterSpaceSwitch: true)
    rescanSoon()
  }

  private func rescanSoon() {
    pendingRescan?.cancel()
    pendingRescan = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      guard !Task.isCancelled, let self, self.running else { return }
      self.rescan(Array(self.apps.keys), afterSpaceSwitch: true)
    }
  }

  /// Asks these apps which windows they list now. The Accessibility API lists
  /// only the windows on the Spaces that are showing, so a known window that
  /// is no longer listed has gone out of view with its Space, not closed: it
  /// is marked off the active Space (it keeps its place in the tree but takes
  /// no space) until it is listed again.
  ///
  /// The other way to leave the list alive is to become a background tab of a native tab group (`NativeTabs`): then
  /// another window of the app joins the list at the same moment, in the same place, and takes over. That is not
  /// looked for after a Space switch, when windows come and go for another reason and two that fill
  /// the same slot on different Spaces would be taken for tabs.
  ///
  /// A window found on a list for the first time has usually been open all along, on a Space that did not show or hidden
  /// with its app, and is reported as found. `aWindowOpened` says that an app has just reported a new window: it may
  /// have opened several at once, and the reports of the others are still on their way.
  private func rescan(_ pids: [pid_t], afterSpaceSwitch: Bool, aWindowOpened: Bool = false) {
    // What the Space brings into sight exists already.
    if afterSpaceSwitch { countWindows() }
    var listed: [(pid: pid_t, id: WindowID, element: AXUIElement)] = []
    var listedIDs = Set<WindowID>()
    var answered = Set<pid_t>()
    for pid in pids.sorted() {
      guard let app = apps[pid], answers(pid) else { continue }
      let began = uptime
      // An app that does not answer in time says nothing about its windows.
      guard let elements = app.element.elementsIfAnswered(kAXWindowsAttribute) else {
        noteSilence(of: pid, since: began)
        continue
      }
      answered.insert(pid)
      for element in elements {
        guard let id = element.windowID else { continue }
        listed.append((pid, id, element))
        listedIDs.insert(id)
      }
    }
    // Windows leave the layout before others join it, so no window is moved
    // to make room for one whose Space is no longer showing.
    let known = records.filter { answered.contains($0.value.snapshot.pid) }.keys.sorted()
    for id in known where !listedIDs.contains(id) {
      guard let record = records[id], !record.isBackgroundTab, record.snapshot.isOnActiveSpace else { continue }
      // The tab comes first: when the tab in front is closed, the next one must inherit its place, not find it gone.
      if !afterSpaceSwitch, let successor = tabInFront(insteadOf: record, among: listed) {
        records[id]?.isBackgroundTab = true
        if lastReportedFocus == id { lastReportedFocus = nil }
        forgetGrab(of: id)
        Log.debug("\(id) went behind its tab \(successor.id)")
        events?.windowReplaced(id, by: successor)
      } else if record.element.isInvalid {
        // It closed, and the notification has not come, or never will.
        Log.debug("\(id) is gone from its app's list and no longer valid")
        drop(id)
      } else if !afterSpaceSwitch, Self.isOnScreen(id) {
        // The window server still shows it, so it has gone nowhere: the app's list is behind, or in flux. Lists
        // are read at every change of focus, and taking a window in plain view out of the layout would be worse
        // than hearing late that one has left.
        Log.debug("\(id) is not listed by its app but is on screen")
      } else {
        setOnActiveSpace(id, false)
      }
    }
    for id in known where listedIDs.contains(id) {
      guard let record = records[id] else { continue }
      if record.isBackgroundTab {
        // A tab that was dragged out of its group, or whose group is back without the window Arbor knew.
        records[id]?.isBackgroundTab = false
        records[id]?.snapshot.isOnActiveSpace = true
        if let app = apps[record.snapshot.pid], let snapshot = makeSnapshot(id: id, element: record.element, app: app) {
          records[id]?.snapshot = snapshot
        }
        if let snapshot = records[id]?.snapshot { events?.windowAppeared(snapshot) }
      } else if !record.snapshot.isOnActiveSpace {
        setOnActiveSpace(id, true)
      }
    }
    // Full screen comes with a Space switch, and the resize reports can arrive before the window says
    // it is in full screen.
    for id in known where listedIDs.contains(id) {
      guard let record = records[id] else { continue }
      if (record.element.bool("AXFullScreen") ?? record.snapshot.isFullScreen) != record.snapshot.isFullScreen {
        refresh(id, userInitiated: true)
      }
    }
    for entry in listed {
      // Without second looks: palettes and the like stay on the list, and are looked at with every scan anyway.
      addWindow(
        entry.element, pid: entry.pid, announce: true, wasOpenBefore: !aWindowOpened, attempt: Self.lastAttempt)
    }
    if afterSpaceSwitch, let front = NSWorkspace.shared.frontmostApplication { reportFocus(of: front.processIdentifier) }
  }

  /// The listed window that has taken the place of `record`'s window as the tab in front, made ready to be
  /// reported: a record exists for it and it no longer counts as a background tab.
  private func tabInFront(
    insteadOf record: WindowRecord, among listed: [(pid: pid_t, id: WindowID, element: AXUIElement)]
  ) -> WindowSnapshot? {
    let pid = record.snapshot.pid
    guard let app = apps[pid] else { return nil }
    var elements: [WindowID: AXUIElement] = [:]
    var candidates: [NativeTabs.Candidate] = []
    for entry in listed where entry.pid == pid {
      let known = records[entry.id]
      // Windows the controller knows as windows of their own are not candidates.
      guard known == nil || known?.isBackgroundTab == true, let frame = entry.element.frame else { continue }
      elements[entry.id] = entry.element
      candidates.append(NativeTabs.Candidate(id: entry.id, frame: frame, wasBackgroundTab: known != nil))
    }
    guard let id = NativeTabs.successor(toWindowAt: record.snapshot.frame, among: candidates),
      let element = elements[id]
    else { return nil }

    if records[id] == nil {
      // Not every newcomer is a window: macOS puts a stand-in on the list during a full-screen transition.
      guard let fresh = makeRecord(id: id, element: element, app: app) else { return nil }
      records[id] = fresh
    } else {
      records[id]?.isBackgroundTab = false
      records[id]?.snapshot.isOnActiveSpace = true
      if let kept = records[id], let snapshot = makeSnapshot(id: id, element: kept.element, app: app) {
        records[id]?.snapshot = snapshot
      }
    }
    return records[id]?.snapshot
  }

  /// Marks a window on or off the active Space and reports it. This is not a
  /// user move, so the change is reported with `userInitiated: false`.
  private func setOnActiveSpace(_ window: WindowID, _ onActiveSpace: Bool) {
    guard var record = records[window], let app = apps[record.snapshot.pid] else { return }
    if onActiveSpace, let snapshot = makeSnapshot(id: window, element: record.element, app: app) {
      // Read it again: it may have moved, been minimized or renamed while away.
      record.snapshot = snapshot
    }
    record.snapshot.isOnActiveSpace = onActiveSpace
    records[window] = record
    Log.debug("\(window) is \(onActiveSpace ? "listed again" : "no longer listed")")
    events?.windowChanged(record.snapshot, userInitiated: false)
  }

  // MARK: Windows

  /// How many second looks a new element gets before it is taken not to be a window.
  private static let lastAttempt = 2

  /// Windows their apps have reported as created and Arbor has not announced yet: some are not ready to be looked at
  /// at once, and may be found on a list before the second look.
  private var reportedCreated: Set<WindowID> = []

  /// The windows the window server had, on whichever Space, when Arbor last counted them (at the start and after every
  /// Space switch), and those seen since. One that is seen for the first time and is not among them has opened since.
  ///
  /// Apps keep to no order in what they report: "the focus is on it" was seen on a Mac to come a millisecond before "it was
  /// created", so whoever sees a window first cannot go by what its app has said so far.
  private var counted: Set<WindowID> = []
  /// Windows that have closed as far as anybody can see, and that the window server may have all the same: apps with one window
  /// (Music, Notes, Calendar) put it away and show it again under the same number. Opened again, it is new.
  private var putAway: Set<WindowID> = []

  private func countWindows() {
    let existing = existingWindowIDs()
    // No answer is not "there are none".
    guard !existing.isEmpty else { return }
    putAway.formIntersection(existing)
    counted = existing.subtracting(putAway)
  }

  /// `wasOpenBefore`: as far as the caller knows the window is only seen for the first time. If its app has reported it as
  /// created, or the window server did not have it at the last count, it is new all the same.
  private func addWindow(
    _ element: AXUIElement, pid: pid_t, announce: Bool, wasOpenBefore: Bool = false, attempt: Int = 0
  ) {
    guard let app = apps[pid], answers(pid), let id = element.windowID, records[id] == nil else { return }
    guard let record = makeRecord(id: id, element: element, app: app) else {
      // Some apps give new windows their subrole a moment after creating them.
      if attempt < Self.lastAttempt {
        let box = MainActorBox(value: element)
        Task { @MainActor [weak self] in
          try? await Task.sleep(nanoseconds: 300_000_000)
          // Whoever asked at the start has read the list of windows by now.
          self?.addWindow(box.value, pid: pid, announce: true, wasOpenBefore: wasOpenBefore, attempt: attempt + 1)
        }
      } else {
        bringIntoViewIfDialog(element, id: id, app: app)
      }
      return
    }
    records[id] = record
    let wasReportedCreated = reportedCreated.remove(id) != nil
    let hasOpenedSince = counted.insert(id).inserted
    putAway.remove(id)
    guard announce else { return }
    if wasOpenBefore, !wasReportedCreated, !hasOpenedSince {
      Log.debug("\(id) is seen for the first time and did not just open")
      events?.windowFound(record.snapshot)
    } else {
      events?.windowAppeared(record.snapshot)
    }
  }

  public func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) {
    leavesStrayDialogs = leave
    appWhoseDialogsNeverWait = leave ? inUse : nil
    if leave {
      if let inUse { bringInStrayDialogs(ofApp: inUse) }
    } else {
      bringIn(waitingDialogs)
    }
  }

  /// With nil: of every app that has no bundle id, and the queue is rid of those of apps that are gone.
  public func bringInStrayDialogs(ofApp bundleID: String?) {
    bringIn(waitingDialogs.filter { apps[$0.pid]?.bundleID == bundleID })
  }

  /// This runs on the main thread just before the view moves, and reads two or three attributes of each. One of an app that
  /// does not answer is dropped rather than waited for: when the app wakes, the scan that follows finds it again.
  /// One that has closed meanwhile has no subrole any more, and one its app has moved into view needs no help.
  private func bringIn(_ dialogs: [(element: AXUIElement, id: WindowID, pid: pid_t)]) {
    waitingDialogs.removeAll { waiting in dialogs.contains { $0.id == waiting.id } }
    for dialog in dialogs {
      if let app = apps[dialog.pid], answers(dialog.pid) {
        bringIntoViewIfDialog(dialog.element, id: dialog.id, app: app, mayWait: false)
      }
    }
  }

  public func strayDialogsWaiting() -> Int {
    // One that has closed has no subrole any more. Nor has one whose app does not answer, which is not asked.
    waitingDialogs.removeAll { answers($0.pid) && $0.element.string(kAXSubroleAttribute) == nil }
    return waitingDialogs.count
  }

  /// A dialog that opened over a window of its app that is out of view is out of view too, where nobody finds it (F47).
  /// It is moved to the middle of the display, once, and not looked after any further.
  private func bringIntoViewIfDialog(_ element: AXUIElement, id: WindowID, app: ObservedApp, mayWait: Bool = true) {
    guard !broughtIntoView.contains(id), let subrole = element.string(kAXSubroleAttribute),
      subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole, let frame = element.frame,
      let home = StrayDialog.home(
        for: frame, siblings: windowIDs(of: app.pid).compactMap { records[$0]?.snapshot.frame },
        displays: displays().map { StrayDialog.Display(frame: $0.frame, visibleFrame: $0.visibleFrame) })
    else { return }
    let isInUse = appWhoseDialogsNeverWait != nil && app.bundleID == appWhoseDialogsNeverWait
    guard !(leavesStrayDialogs && mayWait && !isInUse) else {
      // Every scan of the app comes by here, so once.
      if !waitingDialogs.contains(where: { $0.id == id }) {
        waitingDialogs.append((element, id, app.pid))
        Log.info("\(id), a dialog, opened out of view; the view is held, so it waits there")
      }
      return
    }
    broughtIntoView.insert(id)
    let owner = app.bundleID ?? "pid \(app.pid)"
    Log.info("\(id), a dialog of \(owner), opened out of view; moving it to the middle of the display")
    element.setPosition(home)
  }

  /// Looks at an element an app lists as a window and, if Arbor arranges such windows, subscribes to it. A window
  /// in full screen is one: it takes no space, and keeps the place it was saved with.
  private func makeRecord(id: WindowID, element: AXUIElement, app: ObservedApp) -> WindowRecord? {
    // Window elements do not go by their app element's timeout (F17, H3).
    AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    let subrole = element.string(kAXSubroleAttribute)
    // Only what claims to be a dialog needs the second look.
    let mayBeOutOfSight = subrole == kAXDialogSubrole
    let kind = WindowKind.classify(
      role: element.string(kAXRoleAttribute), subrole: subrole,
      isMinimized: mayBeOutOfSight && element.bool(kAXMinimizedAttribute) == true,
      appIsHidden: mayBeOutOfSight && app.element.bool(kAXHiddenAttribute) == true)
    guard kind != .other, let snapshot = makeSnapshot(id: id, element: element, app: app) else { return nil }

    let refcon = UnsafeMutableRawPointer(bitPattern: UInt(id.rawValue))
    for name in [
      kAXUIElementDestroyedNotification, kAXMovedNotification, kAXResizedNotification,
      kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXTitleChangedNotification,
    ] {
      AXObserverAddNotification(app.observer, element, name as CFString, refcon)
    }
    return WindowRecord(element: element, snapshot: snapshot, isUnconfirmed: kind == .unconfirmed)
  }

  /// Reads a window's state. Nil if its app does not answer.
  private func makeSnapshot(id: WindowID, element: AXUIElement, app: ObservedApp) -> WindowSnapshot? {
    let began = uptime
    let title = element.read(kAXTitleAttribute)
    guard title.error != .cannotComplete else {
      noteSilence(of: app.pid, since: began)
      return nil
    }
    return WindowSnapshot(
      id: id, pid: app.pid, bundleID: app.bundleID, appName: app.name,
      title: title.value as? String ?? "", frame: element.frame ?? records[id]?.snapshot.frame ?? .zero,
      isMinimized: element.bool(kAXMinimizedAttribute) ?? false,
      isHidden: app.element.bool(kAXHiddenAttribute) ?? false,
      // Only `rescan` changes this.
      isOnActiveSpace: records[id]?.snapshot.isOnActiveSpace ?? true,
      isFullScreen: element.bool("AXFullScreen") ?? false,
      // Asked once: it matters when the window opens, and this runs for every new title.
      isResizable: records[id]?.snapshot.isResizable ?? element.isSettable(kAXSizeAttribute) ?? true)
  }

  private func refresh(_ window: WindowID, userInitiated: Bool) {
    guard var record = records[window], let app = apps[record.snapshot.pid], answers(app.pid),
      let snapshot = makeSnapshot(id: window, element: record.element, app: app)
    else { return }
    record.snapshot = snapshot
    records[window] = record
    if !record.isBackgroundTab { events?.windowChanged(record.snapshot, userInitiated: userInitiated) }
  }

  /// Forgets a window and reports it gone.
  private func drop(_ window: WindowID) {
    guard let record = records.removeValue(forKey: window) else { return }
    counted.remove(window)
    putAway.insert(window)
    echoes.forget(window)
    secondLooks.removeValue(forKey: window)?.cancel()
    forgetGrab(of: window)
    if lastReportedFocus == window { lastReportedFocus = nil }
    if !record.isBackgroundTab { events?.windowDestroyed(window) }
  }

  /// Windows taken on while they could not be told from dialogs show what they are once they are in view. The look
  /// waits a moment, until the app has finished showing them.
  private func confirmSoon(_ pid: pid_t) {
    guard windowIDs(of: pid).contains(where: { records[$0]?.isUnconfirmed == true }) else { return }
    Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: 600_000_000)
      guard let self, self.running, self.answers(pid) else { return }
      for window in self.windowIDs(of: pid) {
        guard let record = self.records[window], record.isUnconfirmed, !record.snapshot.isMinimized,
          !record.snapshot.isHidden
        else { continue }
        let subrole = record.element.read(kAXSubroleAttribute)
        guard subrole.error == .success else { continue }
        if subrole.value as? String == kAXStandardWindowSubrole {
          self.records[window]?.isUnconfirmed = false
        } else {
          Log.debug("\(window) turned out not to be an ordinary window")
          self.drop(window)
        }
      }
    }
  }

  /// Reports the focused window of `pid`, if that app is the one in front. An app in the background changes its
  /// focused window too (it opens or closes a window, or Arbor raises one before activating the app), and
  /// reporting that would move the camera away from what the user is doing. If the app then comes forward,
  /// `appCameForward` reports its focused window.
  private func reportFocus(of pid: pid_t) {
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
    guard let app = apps[pid], answers(pid), let element = app.element.element(kAXFocusedWindowAttribute),
      let window = element.windowID
    else {
      // Finder after a click on the wallpaper, an app that is not observed: the keyboard left the known windows.
      keyboardLeftTheKnownWindows()
      return
    }
    if records[window] == nil { addWindow(element, pid: pid, announce: true, wasOpenBefore: true) }
    guard let record = records[window], !record.isBackgroundTab else {
      // A sheet, a dialog or a panel.
      keyboardLeftTheKnownWindows()
      return
    }
    // Switching Spaces activates an app too, before or after `rescan` has found out which windows show now. A
    // window still taken to be on another Space is left for `rescan` to report.
    guard record.snapshot.isOnActiveSpace else {
      keyboardLeftTheKnownWindows()
      return
    }
    guard lastReportedFocus != window else { return }
    lastReportedFocus = window
    Log.debug("focus is on \(window)")
    events?.windowFocused(window)
  }

  private func keyboardLeftTheKnownWindows() {
    // The window that had it is reported again when it gets it back.
    lastReportedFocus = nil
    events?.keyboardFocusMoved()
  }

  private func geometryChanged(_ window: WindowID, resized: Bool) {
    guard var record = records[window], let frame = record.element.frame else { return }
    let previous = record.snapshot.frame
    record.snapshot.frame = frame
    // Entering and leaving full screen (the green button) arrive as resizes.
    let wasFullScreen = record.snapshot.isFullScreen
    if resized { record.snapshot.isFullScreen = record.element.bool("AXFullScreen") ?? wasFullScreen }
    records[window] = record
    guard !record.isBackgroundTab else { return }
    if record.snapshot.isFullScreen != wasFullScreen {
      Log.debug("\(window) \(wasFullScreen ? "left" : "entered") full screen")
      events?.windowChanged(record.snapshot, userInitiated: true)
      // A window that leaves full screen from afar changes Space without a Space switch.
      rescan([record.snapshot.pid], afterSpaceSwitch: true)
      rescanSoon()
      return
    }
    let verdict = echoes.judge(frame, of: window, at: uptime)
    if verdict == .early { lookAgain(at: window) }
    let programmatic = verdict != .other

    if !programmatic, isMouseButtonDown() { noteMoveWhilePressed(window, from: previous, to: frame) }
    events?.windowChanged(record.snapshot, userInitiated: !programmatic)
  }

  /// macOS's stand-ins for windows on their way out of full screen.
  ///
  /// The stand-in shows the animation and is on the app's list in the window's place. When it goes, the window is on the screen
  /// and all apps list the windows of the Space that has come back (16 rounds of 16 on a hosted Mac, macOS 26.6). The change of
  /// Space is reported about then: 0.14 s later in one run, and in two rounds of four a moment EARLIER, when the window was not
  /// listed yet, so that Arbor heard of it from the second look, a second after everybody had seen it.
  private var standIns: Set<WindowID> = []

  private func watchIfItStandsInOnTheWayOutOfFullScreen(_ element: AXUIElement, pid: pid_t) {
    // As large as the window: in full screen apps make and drop smaller helpers all the time (the toolbar that slides in).
    guard let app = apps[pid], let id = element.windowID, records[id] == nil,
      let leaving = records.values.first(where: { $0.snapshot.pid == pid && $0.snapshot.isFullScreen }),
      element.string(kAXSubroleAttribute) == kAXUnknownSubrole, element.frame?.size == leaving.snapshot.frame.size
    else { return }
    if standIns.count > 20 { standIns.removeAll() }
    standIns.insert(id)
    let refcon = UnsafeMutableRawPointer(bitPattern: UInt(id.rawValue))
    AXObserverAddNotification(app.observer, element, kAXUIElementDestroyedNotification as CFString, refcon)
  }

  /// A report came so soon after Arbor's move that it was taken for a stage of it, though the frame was another. If the
  /// window is still not where Arbor put it when things have settled, that was its app's answer, and is reported as such.
  private func lookAgain(at window: WindowID) {
    secondLooks[window]?.cancel()
    secondLooks[window] = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(EchoFilter.settleTime * 1_000_000_000))
      guard !Task.isCancelled, let self, self.running else { return }
      self.secondLooks[window] = nil
      guard var record = self.records[window], !record.isBackgroundTab, self.answers(record.snapshot.pid),
        let frame = record.element.frame, self.echoes.hasStrayed(window, now: frame)
      else { return }
      Log.debug("\(window) did not stay where it was put")
      record.snapshot.frame = frame
      self.records[window] = record
      self.events?.windowChanged(record.snapshot, userInitiated: true)
    }
  }

  // MARK: Notifications

  fileprivate func handle(_ notification: String, element: AXUIElement, window raw: UInt32?) {
    guard running else { return }
    // Before anything looks at the app's list (`answersAgain` does), where the new window may already be. Helpers that
    // never become windows (tooltips, full-screen scaffolding) are reported too and never announced.
    // This one is registered on the app, without a window's number: the element is the new window.
    if notification == kAXWindowCreatedNotification, let id = raw.map({ WindowID($0) }) ?? element.windowID {
      if reportedCreated.count > 200 { reportedCreated.removeAll() }
      reportedCreated.insert(id)
    }
    // A trace shows what macOS said before what Arbor made of it.
    if let recorder, recorder.isRecording {
      noteScreens(recorder)
      let moving = notification == kAXMovedNotification || notification == kAXResizedNotification
      // Thinned by name, which keeps the first and the last of a burst whichever windows they are of. Not while the displays are unsettled: which
      // windows their apps report, after macOS has shifted them, is just what a trace of a closing lid is for.
      recorder.raw(raw.map { "\(notification) w\($0)" } ?? notification, thinKey: moving && pendingDisplayChange == nil ? notification : nil)
    }
    // Whoever posts a notification is awake.
    if let pid = element.pid, !answers(pid) { answersAgain(pid) }

    switch notification {
    case kAXWindowCreatedNotification:
      guard let pid = element.pid else { return }
      // Before the list is read, which takes the window that is leaving full screen for one on another Space.
      watchIfItStandsInOnTheWayOutOfFullScreen(element, pid: pid)
      // A new tab is a new window that pushes another off the list, so the list comes first.
      rescan([pid], afterSpaceSwitch: false, aWindowOpened: true)
      addWindow(element, pid: pid, announce: true)

    case kAXUIElementDestroyedNotification:
      if let raw, standIns.remove(WindowID(raw)) != nil {
        Log.debug("the stand-in \(WindowID(raw)) is gone: the way out of full screen is over")
        rescan(Array(apps.keys), afterSpaceSwitch: true)
        return
      }
      guard let raw, let record = records[WindowID(raw)] else { return }
      // If it was the tab in front of others, one of them is taking its place. macOS 26 reports that first, as a
      // change of the main window; should the order ever be the other way round, the list says so already.
      let pid = record.snapshot.pid
      if !record.isBackgroundTab, windowIDs(of: pid).contains(where: { records[$0]?.isBackgroundTab == true }) {
        rescan([pid], afterSpaceSwitch: false)
      }
      drop(WindowID(raw))

    case kAXMovedNotification, kAXResizedNotification:
      guard let raw else { return }
      geometryChanged(WindowID(raw), resized: notification == kAXResizedNotification)

    case kAXTitleChangedNotification:
      // Terminals and browsers change titles all the time. Nothing else needs reading, and nobody moved anything.
      guard let raw, var record = records[WindowID(raw)], let title = record.element.string(kAXTitleAttribute) else {
        return
      }
      record.snapshot.title = title
      records[WindowID(raw)] = record
      if !record.isBackgroundTab { events?.windowChanged(record.snapshot, userInitiated: false) }

    case kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification:
      guard let raw else { return }
      refresh(WindowID(raw), userInitiated: true)
      // An un-minimized window shows on some Space: ask which windows the app lists now.
      if notification == kAXWindowDeminiaturizedNotification, let pid = records[WindowID(raw)]?.snapshot.pid {
        rescan([pid], afterSpaceSwitch: false)
        confirmSoon(pid)
      }

    case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
      guard let pid = element.pid else { return }
      // Choosing another native tab shows up as "main window changed" and nothing else; the tab takes its place
      // before it is reported as focused.
      rescan([pid], afterSpaceSwitch: false)
      reportFocus(of: pid)

    case kAXApplicationActivatedNotification, kAXApplicationDeactivatedNotification:
      events?.keyboardFocusMoved()

    case kAXApplicationHiddenNotification, kAXApplicationShownNotification:
      guard let pid = element.pid else { return }
      let hidden = notification == kAXApplicationHiddenNotification
      for window in windowIDs(of: pid) {
        guard var record = records[window], record.snapshot.isHidden != hidden else { continue }
        record.snapshot.isHidden = hidden
        records[window] = record
        if !record.isBackgroundTab { events?.windowChanged(record.snapshot, userInitiated: false) }
      }
      if !hidden {
        // Windows that were hidden when Arbor started may be seen for the first time.
        rescan([pid], afterSpaceSwitch: false)
        confirmSoon(pid)
      }

    default:
      break
    }
  }

  // MARK: Mouse

  // Telling what the mouse is doing to a window: dragging it by its title bar, resizing it by its edges, or neither.
  //
  // Two signs are watched, and whichever comes first wins (F17, H1). From the press on, the frame of the window under
  // the pointer is read from the window server with every movement; and the app's own "moved" and "resized"
  // notifications are looked at as before. The window server moves a dragged window itself and knows its place at once,
  // without the app having a say; the app learns of it about a tenth of a second later, posts at most a few
  // notifications a second, and some apps post none until the drag is over. Asking the window server also cannot hang.
  // Neither sign is ever switched off while the button is down: a pointer that has gone far over a window that stands still
  // is most likely selecting text, so the window server is then asked ten times a second and not with every movement, but a
  // window that starts late is still a window in hand (`WindowGrab.judge`).

  private struct Press {
    let point: CGPoint
    /// The window under the pointer, if it is one Arbor knows.
    var window: WindowID?
    /// That window's frame at the time, by the window server.
    var frame: CGRect = .zero
    /// It is settled that this press is not about a window Arbor knows.
    var isSettled = false
    /// What `WindowGrab.judge` remembers between two looks. Once the pointer has gone far while the window stood still, the
    /// window server is asked less often; what the window's app reports is heard as before.
    var memory = WindowGrab.Memory()
    /// When the window server was last asked.
    var lookedAt: TimeInterval = 0
  }

  /// How long the window server is left alone between two looks at a window that stood still: a selection in a long text
  /// is thousands of movements.
  private static let restBetweenLooks: TimeInterval = 0.1

  /// How far outside a window's frame a press still belongs to it: macOS's resize area.
  private static let reach: CGFloat = 4

  private func handleMouse(_ type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags, at location: CGPoint?) {
    eventModifiers = modifiers
    // Not for movements: of those the newest place is the one to show a preview for.
    if type == .leftMouseDown || type == .leftMouseUp { eventLocation = location }
    defer {
      eventModifiers = nil
      eventLocation = nil
    }
    if let recorder, recorder.isRecording {
      switch type {
      case .leftMouseDown: recorder.raw("leftMouseDown \(traceText(cursorLocation()))")
      case .leftMouseUp: recorder.raw("leftMouseUp \(traceText(cursorLocation()))")
      case .leftMouseDragged: recorder.raw("leftMouseDragged \(traceText(cursorLocation()))", thinKey: "leftMouseDragged")
      case .flagsChanged: recorder.raw("flagsChanged")
      default: break
      }
    }
    switch type {
    case .leftMouseDown:
      // A button cannot go down twice: the release of whatever was going on was lost.
      releaseWasLost()
      press = makePress(at: cursorLocation())
      events?.pointerPressed()
    case .leftMouseDragged:
      if let window = draggingWindow {
        events?.dragMoved(window, to: cursorLocation())
      } else if resizingWindow == nil {
        lookAtPressedWindow()
      }
    case .flagsChanged:
      // A modifier going down or up counts as a move, so ⌘ takes effect while the pointer rests.
      if let window = draggingWindow { events?.dragMoved(window, to: cursorLocation()) }
    case .leftMouseUp:
      noteAGrabThatWasMissed()
      press = nil
      endGrab()
    default:
      break
    }
  }

  /// The button went down on one of Arbor's own panels. Windows that move from here on are moved by Arbor.
  private func pressLandedOnArbor() {
    recorder?.raw("leftMouseDown on a tile or a handle of Arbor's")
    releaseWasLost()
    press = nil
    events?.pointerPressed()
  }

  // MARK: The press

  /// Finds the window under the pointer: the first ordinary window, front to back, that the point belongs to.
  private func makePress(at point: CGPoint) -> Press {
    var press = Press(point: point)
    guard
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]]
    else { return press }
    let own = getpid()
    for info in list {
      // Layer 0 is where apps' windows are; the menu bar, the Dock and overlays are above. Arbor's own panels
      // either let clicks through or get them without this code hearing of it.
      guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != own,
        let bounds = Self.bounds(in: info), bounds.insetBy(dx: -Self.reach, dy: -Self.reach).contains(point)
      else { continue }
      if let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
        let record = records[WindowID(number)], !record.isBackgroundTab,
        // macOS is showing its desktop, and this is the strip of a window it swept aside.
        !WindowGrab.isListedElsewhere(bounds, than: record.snapshot.frame)
      {
        press.window = WindowID(number)
        press.frame = bounds
      } else {
        press.isSettled = true
      }
      break
    }
    return press
  }

  private static func bounds(in info: [String: Any]) -> CGRect? {
    guard let dictionary = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
    return CGRect(dictionaryRepresentation: dictionary as CFDictionary)
  }

  /// Whether the window server is showing the window: not on another Space, minimized, hidden or behind its tab.
  private static func isOnScreen(_ window: WindowID) -> Bool {
    guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.rawValue) as? [[String: Any]],
      let info = list.first
    else { return false }
    return (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
  }

  /// The window's frame as the window server has it, in the same coordinates as the Accessibility API's.
  private static func serverBounds(of window: WindowID) -> CGRect? {
    guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], window.rawValue) as? [[String: Any]],
      let info = list.first
    else { return nil }
    return bounds(in: info)
  }

  // MARK: The two signs

  /// The pointer moved with the button down and nothing is decided yet.
  private func lookAtPressedWindow() {
    guard let press, !press.isSettled, let window = press.window, records[window] != nil,
      !press.memory.stoodStill || uptime - press.lookedAt >= Self.restBetweenLooks,
      let bounds = Self.serverBounds(of: window)
    else { return }
    self.press?.lookedAt = uptime
    if echoes.isEcho(bounds, of: window, at: uptime) {
      // Arbor moved it itself after the press. Start from there.
      self.press?.frame = bounds
      return
    }
    decide(window, from: press.frame, to: bounds, pressedAt: press.point)
    if draggingWindow == window { events?.dragMoved(window, to: cursorLocation()) }
  }

  /// An app reported that a window moved or changed size, not by Arbor's doing, while the button is down.
  private func noteMoveWhilePressed(_ window: WindowID, from previous: CGRect, to frame: CGRect) {
    guard let press, !press.isSettled, draggingWindow == nil, resizingWindow == nil else { return }
    if press.window == window {
      decide(window, from: press.frame, to: frame, pressedAt: press.point)
    } else if press.window == nil, previous.insetBy(dx: -Self.reach, dy: -Self.reach).contains(press.point) {
      // The window server's list was no help; go by where the window was.
      decide(window, from: previous, to: frame, pressedAt: press.point)
    }
  }

  /// The button comes up on a press that was taken for nothing, and the window is not where it was. Nothing can be done about it
  /// now; a line in the log is what tells a run, or whoever reads a report, that it happened at all.
  private func noteAGrabThatWasMissed() {
    guard Log.debugEnabled, let press, !press.isSettled, draggingWindow == nil, resizingWindow == nil, let window = press.window,
      let bounds = Self.serverBounds(of: window), !echoes.isEcho(bounds, of: window, at: uptime),
      abs(bounds.minX - press.frame.minX) >= 1 || abs(bounds.minY - press.frame.minY) >= 1 || bounds.size != press.frame.size
    else { return }
    Log.debug("\(window) was moved or resized while the button was down, and it was taken for neither a drag nor a resize")
  }

  private func decide(_ window: WindowID, from before: CGRect, to now: CGRect, pressedAt point: CGPoint) {
    var memory = press?.memory ?? WindowGrab.Memory()
    let late = memory.stoodStill
    let verdict = WindowGrab.judge(
      pressedAt: point, frameAtPress: before, frameNow: now, pointerNow: cursorLocation(), memory: &memory)
    if memory.stoodStill, !late { Log.debug("the press on \(window) has moved nothing so far: looking less often") }
    press?.memory = memory
    switch verdict {
    case .undecided, .neither:
      break
    case .drag:
      draggingWindow = window
      watchForLostRelease()
      Log.debug("\(window) is being dragged" + (late ? ", which began late" : ""))
      events?.dragBegan(window, at: cursorLocation())
    case .resize:
      resizingWindow = window
      watchForLostRelease()
      Log.debug("\(window) is being resized by its edges" + (late ? ", which began late" : ""))
      events?.resizeBegan(window)
    }
  }

  // MARK: The end

  /// The button came up.
  private func endGrab() {
    grabNumber += 1
    if let window = draggingWindow {
      draggingWindow = nil
      // The app may not have heard yet where its window was left.
      if let bounds = Self.serverBounds(of: window), var record = records[window] {
        record.snapshot.frame = bounds
        records[window] = record
        events?.windowChanged(record.snapshot, userInitiated: true)
      }
      events?.dragEnded(window, at: cursorLocation())
    }
    endResize()
  }

  private func endResize() {
    guard let window = resizingWindow else { return }
    resizingWindow = nil
    // Let the controller re-check the window now that the resize is over.
    refresh(window, userInitiated: true)
    events?.resizeEnded(window)
  }

  /// The button is up, or down again, and its release was never seen: another tool's event tap swallowed it, or it
  /// went to a window of Arbor's. Without this the controller would wait for the drop for ever, with the preview on
  /// screen. A resize can be finished all the same, since the window's frame says how it ended. A drag cannot: where
  /// the pointer is by now says nothing about where the window was meant to go.
  private func releaseWasLost() {
    grabNumber += 1
    if let window = draggingWindow {
      draggingWindow = nil
      Log.debug("the end of the drag of \(window) was not seen")
      refresh(window, userInitiated: true)
      events?.dragCancelled(window)
    }
    endResize()
  }

  /// While a window is held, checks twice a second that the button is still down. Two checks in a row must find it
  /// up, so that a release that is only waiting its turn on a busy main thread is not taken for lost.
  private func watchForLostRelease() {
    grabNumber += 1
    let number = grabNumber
    Task { @MainActor [weak self] in
      var timesUp = 0
      while true {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard let self, self.running, self.grabNumber == number else { return }
        timesUp = self.isMouseButtonDown() ? 0 : timesUp + 1
        if timesUp >= 2 {
          self.press = nil
          self.releaseWasLost()
          return
        }
      }
    }
  }

  /// The window is gone, so there is nothing left to drag or resize. The controller clears its own side when it
  /// hears that the window is gone.
  private func forgetGrab(of window: WindowID) {
    if draggingWindow == window { draggingWindow = nil }
    if resizingWindow == window { resizingWindow = nil }
    if press?.window == window { press = nil }
  }
}

/// AX observer callbacks arrive on the main run loop (where the observer's
/// source is installed), so hopping onto the main actor is safe.
private func axObserverCallback(
  _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  let name = notification as String
  let raw = refcon.map { UInt32(truncatingIfNeeded: UInt(bitPattern: $0)) }
  let box = MainActorBox(value: element)
  MainActor.assumeIsolated {
    AXWindowSystem.current?.handle(name, element: box.value, window: raw)
  }
}
