// The model of a Mac (FakeMac.swift): what apps, and the people in front of them, do. Never shipped.
import Foundation

extension FakeMac {
  // MARK: Coming and going

  /// An app starts. `announced: false`: one that is started from a shell, or is no regular app yet: no launch notice.
  /// `readyAfter`: for so long it refuses observers.
  @discardableResult
  public func launch(
    _ name: String, bundleID: String? = nil, policy: Policy = .regular, announced: Bool = true, readyAfter: TimeInterval = 0, comesForward: Bool = true
  ) -> App {
    lastPID += 1
    let app = App(pid: lastPID, name: name, bundleID: bundleID ?? "test.\(name.lowercased())", policy: policy)
    app.refusesObserversUntil = now + readyAfter
    apps.append(app)
    note("\(name) is launched, pid \(app.pid)")
    if announced { workspaceNotice("NSWorkspaceDidLaunchApplicationNotification", app, after: timing.launchNotice) }
    if comesForward, policy == .regular { activate(app) }
    return app
  }

  /// An app ends. `announced: false`: nothing reports the end of an accessory app or of a process started from a shell
  /// (docs/ARCHITECTURE.md). No window is reported destroyed either way: the trace `app-quits` has no such line.
  public func quit(_ app: App, announced: Bool = true) {
    guard app.isAlive else { return }
    note("\(app.name) (pid \(app.pid)) ends\(announced ? "" : ", and nothing says so")")
    app.isAlive = false
    app.isHung = false
    app.backlog.removeAll()
    for window in app.windows {
      window.isOpen = false
      window.exists = false
    }
    stack.removeAll { $0.app === app }
    apps.removeAll { $0 === app }
    activationHistory.removeAll { $0 === app }
    observers.removeAll { $0.pid == app.pid }
    if mouse.grab?.window?.app === app { mouse.grab = nil }
    if announced { workspaceNotice("NSWorkspaceDidTerminateApplicationNotification", app, after: timing.terminationNotice) }
    if frontmost === app { someoneElseComesForward() }
  }

  /// The app in front has gone or hidden: the one that was in front before it comes forward. If there is none, nobody is in front
  /// (on a Mac it would be Finder, which a story can launch).
  private func someoneElseComesForward() {
    if let next = activationHistory.first(where: { $0.isAlive && !$0.isHidden && $0 !== frontmost }) {
      activate(next)
    } else {
      frontmost = nil
      send(after: 0, from: .workspaceCache, "") { [self] in frontmostByWorkspace = nil }
    }
  }

  func workspaceNotice(_ name: String, _ app: App?, after delay: TimeInterval, first: @escaping () -> Void = {}) {
    let short = name.replacingOccurrences(of: "NSWorkspace", with: "").replacingOccurrences(of: "Notification", with: "")
    send(after: delay, from: .workspace, "→ \(short)\(app.map { " pid \($0.pid)" } ?? "")") {
      first()
      Self.postsWorkspaceNotification(name, app?.pid)
    }
  }

  // MARK: Coming forward

  /// An app comes forward: ⌘Tab, the Dock, `activate()`. Its focused window stays what it was, so Accessibility posts no "focused window
  /// changed". What macOS says, as it was seen on hosted Macs on 2026-10-14: `didActivateApplication`; `AXApplicationDeactivated` of the other app 0.6 ms
  /// later; `AXApplicationActivated` 8 ms later; and nothing more.
  public func activate(_ app: App, raisingAll: Bool = true) {
    guard app.isAlive, frontmost !== app else { return }
    note("\(app.name) (pid \(app.pid)) comes forward")
    if app.isHidden { unhide(app) }
    let old = frontmost
    frontmost = app
    activationHistory.removeAll { $0 === app }
    activationHistory.insert(app, at: 0)
    if raisingAll { raiseAll(of: app) }
    // Arbor asks an app that fell silent whether it is back every half second here, every second and a half on a Mac.
    app.hasHungInFront = app.isHung || now - app.wokeAt < 2
    app.noticeOutranTheProperty = false

    let lag = frontmostLagsNoticeBy > 0 ? frontmostLagsNoticeBy : manners.lag(upTo: manners.staleness)
    let notice = timing.activationNotice
    send(after: lag > 0 ? notice + lag : notice / 2, from: .workspaceCache, lag > 0 ? "(NSWorkspace's frontmostApplication catches up: pid \(app.pid))" : "") {
      [self] in frontmostByWorkspace = app
    }
    workspaceNotice("NSWorkspaceDidActivateApplicationNotification", app, after: notice) { [self] in
      if frontmost === app, frontmostByWorkspace !== app { app.noticeOutranTheProperty = true }
    }
    if let old, old.isAlive { report("AXApplicationDeactivated", about: old, after: notice + timing.deactivatedAfterNotice - timing.report) }
    report("AXApplicationActivated", about: app, after: notice + timing.activatedAfterNotice - timing.report)
  }

  /// `NSRunningApplication.activate()`, which since macOS 14 is only a request.
  public func askToActivate(_ pid: pid_t) -> Bool {
    guard let app = app(pid), app.isAlive else { return false }
    guard !app.ignoresActivation else {
      note("pid \(pid) is asked to come forward and takes no notice")
      return true
    }
    send(after: 0.001, from: .system, "") { [self] in activate(app, raisingAll: false) }
    return true
  }

  // MARK: Hiding

  /// ⌘H. Trace `hide-unhide`: "application hidden", and nothing about the windows.
  public func hide(_ app: App) {
    guard app.isAlive, !app.isHidden else { return }
    note("\(app.name) (pid \(app.pid)) is hidden")
    app.isHidden = true
    report("AXApplicationHidden", about: app)
    if frontmost === app { someoneElseComesForward() }
  }

  /// Before "application shown", macOS brings windows that were nearly off screen back into view: 1023,673 became 24,55 for a window of
  /// 1000 × 650, which is as far as it takes to show all of it (trace `hide-unhide`). Which windows count as nearly off screen is a guess.
  public func unhide(_ app: App) {
    guard app.isAlive, app.isHidden else { return }
    note("\(app.name) (pid \(app.pid)) is shown again")
    for window in app.windows where window.isOpen && !window.isMinimized && !window.isFullScreen {
      let visible = screen(of: window.frame).visibleFrame
      let showing = window.frame.intersection(visible)
      guard showing.isNull || showing.width < 40 || showing.height < 40 else { continue }
      let origin = CGPoint(
        x: max(min(window.frame.minX, visible.maxX - window.frame.width), visible.minX),
        y: max(min(window.frame.minY, visible.maxY - window.frame.height), visible.minY))
      take(CGRect(origin: origin, size: window.frame.size), window)
    }
    app.isHidden = false
    report("AXApplicationShown", about: app, after: timing.betweenReports)
  }

  // MARK: Hanging

  /// The app's main thread is stuck. It answers no call and posts nothing; the window server goes on showing and moving its windows.
  public func hang(_ app: App) {
    guard app.isAlive, !app.isHung else { return }
    note("\(app.name) (pid \(app.pid)) hangs")
    app.isHung = true
    if frontmost === app { app.hasHungInFront = true }
  }

  /// It goes on where it was: the calls that timed out are still in its queue and are carried out now, in order, each with its reports.
  public func wake(_ app: App) {
    guard app.isAlive, app.isHung else { return }
    note("\(app.name) (pid \(app.pid)) wakes")
    app.isHung = false
    app.wokeAt = now
    let backlog = app.backlog
    app.backlog.removeAll()
    for item in backlog {
      if !item.label.isEmpty { note(item.label) }
      item.run()
    }
  }

  // MARK: The keyboard inside an app

  /// A window becomes its app's key and main window. Whether the keyboard is there depends on whether the app is in front.
  /// The order of the two reports is a guess (AppKit makes a window key before it makes it main).
  func makeKey(_ window: Window, reportingFocus: Bool = true) {
    let app = window.app
    guard window.isOpen else { return }
    let (focusChanges, mainChanges) = (app.focused !== window, app.main !== window)
    app.focused = window
    app.main = window
    if focusChanges, reportingFocus { report("AXFocusedWindowChanged", about: window) }
    if mainChanges { report("AXMainWindowChanged", about: window, after: timing.betweenReports) }
  }

  /// The app's key window is gone, minimized or behind another tab: the frontmost of its others that show takes over. With none left the app
  /// has no key window, and posts nothing about that (AppKit reports a window that becomes key, not one that stops being it).
  func nextWindowBecomesKey(in app: App, insteadOf old: Window) {
    guard app.focused === old || app.main === old else { return }
    if let next = stack.first(where: { $0.app === app && $0 !== old && isShowing($0) && $0.canTakeKeyboard }) {
      makeKey(next)
    } else {
      app.focused = nil
      app.main = nil
    }
  }
}
