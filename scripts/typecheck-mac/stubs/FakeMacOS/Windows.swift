// The model of a Mac (FakeMac.swift): what happens to windows. Never shipped.
import Foundation

extension FakeMac {
  // MARK: Opening and closing

  /// A window opens, in front of the others, and becomes its app's key window.
  ///
  /// What the app posts: "created", then "focused window changed" and "main window changed". With `reportsFocusBeforeCreated` the focus comes first, a
  /// millisecond ahead, as on hosted Macs for every window opened in an app that was already running.
  /// - `subrole`: AXStandardWindow, AXDialog, AXFloatingWindow, AXUnknown… `takesKeyboard: false` for helpers and tooltips.
  @discardableResult
  public func open(
    _ title: String, in app: App, frame: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300), subrole: String? = "AXStandardWindow",
    role: String? = "AXWindow", takesKeyboard: Bool = true
  ) -> Window {
    lastWindowNumber += 1
    windowsMade += 1
    let window = Window(number: lastWindowNumber, serial: windowsMade, app: app, title: title, frame: frame, space: activeSpace)
    window.role = role
    window.subrole = subrole
    window.canTakeKeyboard = takesKeyboard
    windowsBySerial[window.serial] = window
    app.windows.append(window)
    note("\(app.name) opens w\(window.number)\(subrole == "AXStandardWindow" ? "" : " (\(subrole ?? "no subrole"))")")
    show(window, takesKeyboard: takesKeyboard)
    return window
  }

  private func show(_ window: Window, takesKeyboard: Bool) {
    let app = window.app
    listWillChange(of: app)
    window.isOpen = true
    window.exists = true
    window.hasSubroleFrom = now + app.subroleComesAfter
    stack.removeAll { $0 === window }
    stack.insert(window, at: 0)
    func created(after delay: TimeInterval = 0) { if !app.doesNotReportCreated { report("AXWindowCreated", about: window, after: delay) } }
    guard takesKeyboard else { return created() }
    if app.reportsFocusBeforeCreated {
      makeKey(window)
      created(after: 0.001)
    } else {
      created()
      makeKey(window)
    }
  }

  /// A window closes (the red button, ⌘W). Trace `close`: the app's next window is reported focused 12 ms before this one is reported destroyed, and
  /// in between it still takes a frame.
  /// - `putAway`: apps with one window (Music, Notes, Calendar) only put it away: the window server keeps the number, and `reopen` shows the window
  ///   again under it.
  /// - `announced: false`: a window can close and the notification never comes (docs/ARCHITECTURE.md).
  public func close(_ window: Window, putAway: Bool = false, announced: Bool = true) {
    guard window.isOpen else { return }
    let app = window.app
    note("w\(window.number) closes\(putAway ? ", which is to say its app puts it away" : "")\(announced ? "" : ", and nothing says so")")
    if let group = window.tabGroup, window.isFrontTab, let successor = app.windows.last(where: { $0.tabGroup == group && $0 !== window && $0.isOpen }) {
      // macOS 26 reports the tab that takes over first, as a change of the main window.
      bringTabForward(successor, insteadOf: window)
    } else {
      nextWindowBecomesKey(in: app, insteadOf: window)
    }
    appDoes(app, after: timing.focusBeforeDestroyed, "") { [self] in
      listWillChange(of: app)
      // Posted while there is still somebody subscribed.
      window.closedWithoutAWord = !announced || !report("AXUIElementDestroyed", about: window, mayBeDropped: true)
      window.isOpen = false
      window.exists = putAway
      window.isMinimized = false
      forgetRegistrations(on: window)
      if !putAway { stack.removeAll { $0 === window } }
      if mouse.grab?.window === window { mouse.grab = nil }
    }
  }

  /// The app shows a window it had put away: the same number, and to everybody who looks a new window.
  public func reopen(_ window: Window) {
    guard !window.isOpen, window.exists, window.app.isAlive else { return }
    note("\(window.app.name) shows w\(window.number) again, under the same number")
    window.space = activeSpace
    window.closedWithoutAWord = false
    show(window, takesKeyboard: true)
  }

  // MARK: What an app does to its own windows

  public func rename(_ window: Window, _ title: String) {
    window.title = title
    report("AXTitleChanged", about: window)
  }

  /// The app moves or resizes its own window, without the mouse (trace `self-move`).
  public func appMoves(_ window: Window, to frame: CGRect) {
    note("\(window.app.name) gives w\(window.number) the frame \(frame)")
    take(frame, window)
  }

  /// The app makes another of its windows the key one, whether it is in front or not.
  public func appMakesKey(_ window: Window) {
    note("\(window.app.name) makes w\(window.number) its key window")
    makeKey(window)
  }

  /// A window has another frame and nobody has heard: its app posts nothing, or the report is still on its way.
  public func changeSilently(_ window: Window, to frame: CGRect) {
    note("w\(window.number) has the frame \(frame), and nothing says so")
    window.frame = frame
    window.bounds = frame
  }

  // MARK: Minimizing

  /// The yellow button, ⌘M, or `AXMinimized`. Trace `minimize-restore`: "miniaturized" comes when the animation is over, 0.55 s later, and 15 to 20 ms
  /// after that the screens' notice, because the Dock has grown.
  public func minimize(_ window: Window) {
    guard window.isOpen, !window.isMinimized else { return }
    note("w\(window.number) is being minimized")
    window.isBusyUntil = now + timing.minimizing + 0.05
    appDoes(window.app, after: timing.minimizing, "") { [self] in
      guard window.isOpen, !window.isMinimized else { return }
      window.isMinimized = true
      report("AXWindowMiniaturized", about: window)
      nextWindowBecomesKey(in: window.app, insteadOf: window)
      dockChanged(by: 2)
    }
  }

  /// A click on it in the Dock, or its app. The focus is reported first, 1 to 4 ms before "deminiaturized" (`minimize-restore`, `app-minimize`).
  public func restore(_ window: Window) {
    guard window.isOpen, window.isMinimized else { return }
    note("w\(window.number) is being restored")
    window.isBusyUntil = now + timing.minimizing + 0.05
    appDoes(window.app, after: timing.minimizing, "") { [self] in
      guard window.isOpen, window.isMinimized else { return }
      window.isMinimized = false
      window.space = activeSpace
      raise(window)
      makeKey(window)
      report("AXWindowDeminiaturized", about: window, after: timing.focusBeforeDeminiaturized)
      dockChanged(by: -2)
    }
  }

  // MARK: Spaces

  /// Whether apps list the right windows from the moment a Space switch begins. On a Mac they have been seen to list neither the old nor the new ones
  /// when the notice comes, in the middle of the transition.
  public enum ListsDuringTransition: Sendable { case right, neither }

  /// Another Space shows. The frontmost app with a window there comes forward, before or after the notice: nobody knows the order.
  public func switchSpace(to space: Int, lists: ListsDuringTransition = .right, appComesForwardFirst: Bool = true) {
    guard space != activeSpace else { return }
    note("the Space changes from \(activeSpace) to \(space)")
    for app in apps { listWillChange(of: app) }
    activeSpace = space
    spacesMade = max(spacesMade, space)
    if mouse.grab != nil { mouse.grab = nil }
    if lists == .neither { listsAreEmptyUntil = now + timing.spaceTransition }
    workspaceNotice("NSWorkspaceActiveSpaceDidChangeNotification", nil, after: timing.spaceNotice)
    send(after: timing.spaceNotice + (appComesForwardFirst ? -0.02 : 0.02), from: .system, "") { [self] in
      guard activeSpace == space, let top = stack.first(where: { isShowing($0) && $0.canTakeKeyboard }) else { return }
      // The window on top of the new Space gets the keyboard.
      makeKey(top)
      activate(top.app, raisingAll: false)
    }
  }

  /// Mission Control, "Assign To": a window goes to another Space without a switch, and nothing says so (docs/features/F08).
  public func send(_ window: Window, toSpace space: Int) {
    note("w\(window.number) is sent to Space \(space)")
    listWillChange(of: window.app)
    window.space = space
    window.homeSpace = space
    spacesMade = max(spacesMade, space)
    if space != activeSpace { nextWindowBecomesKey(in: window.app, insteadOf: window) }
  }

  // MARK: Full screen

  /// The green button. The window gets a Space to itself, which is switched to. What was seen on macOS 26.6 (docs/features/F30, docs/ARCHITECTURE.md):
  /// two helper windows of subrole AXUnknown are created on the way in, one of them listed at the top of the display, 30 points high; nothing is
  /// posted about full screen itself, but the size changes. `saysSoLate`: the "resized" reports arrive before `AXFullScreen` says yes.
  public func enterFullScreen(_ window: Window, saysSoLate: Bool = false, lists: ListsDuringTransition = .right) {
    guard window.isOpen, !window.isFullScreen, !window.isMinimized else { return }
    note("w\(window.number) enters full screen")
    window.isBusyUntil = now + timing.spaceTransition + 0.1
    let display = screen(of: window.frame).frame
    window.frameBeforeFullScreen = window.frame
    window.homeSpace = window.space
    spacesMade += 1
    let own = spacesMade
    for part in 0..<2 {
      let helper = open(
        "", in: window.app, frame: CGRect(x: display.minX, y: display.minY, width: display.width, height: 30), subrole: "AXUnknown", takesKeyboard: false)
      helper.space = own
      helper.alpha = part == 0 ? 1 : 0
      fullScreenHelpers[window.serial, default: []].append(helper)
    }
    appDoes(window.app, after: 0.1, "") { [self] in
      if !saysSoLate { window.isFullScreen = true }
      take(display, window)
      window.space = own
      switchSpace(to: own, lists: lists)
      if saysSoLate {
        appDoes(window.app, after: timing.spaceTransition - 0.1, "w\(window.number) says that it is in full screen") { [self] in
          window.isFullScreen = true
          // Whatever was done to it on the way, the transition ends with the window filling the display.
          take(display, window)
        }
      }
    }
  }

  public func leaveFullScreen(_ window: Window) {
    guard window.isOpen, window.isFullScreen || fullScreenHelpers[window.serial] != nil else { return }
    note("w\(window.number) leaves full screen")
    window.isBusyUntil = now + timing.spaceTransition + 0.1
    for helper in fullScreenHelpers.removeValue(forKey: window.serial) ?? [] { close(helper) }
    let wasShowing = window.space == activeSpace
    appDoes(window.app, after: 0.1, "") { [self] in
      window.isFullScreen = false
      listWillChange(of: window.app)
      window.space = window.homeSpace
      take(window.frameBeforeFullScreen, window)
      // One that leaves full screen while another Space shows changes Space, and no switch is reported.
      if wasShowing { switchSpace(to: window.homeSpace) }
    }
  }

  // MARK: Native tabs

  /// ⌘T. A new tab is a new window at the frame of the old one, which leaves the list without a word and stays alive. `grows`: Terminal keeps its
  /// rows, so the window grows by the tab bar's 31 points at the first ⌘T (Sources/ArborCore/NativeTabs.swift).
  @discardableResult
  public func newTab(of window: Window, title: String = "tab", grows: CGFloat = 0) -> Window {
    let app = window.app
    if window.tabGroup == nil {
      tabGroupsMade += 1
      window.tabGroup = tabGroupsMade
    }
    listWillChange(of: app)
    window.isFrontTab = false
    var frame = window.frame
    frame.size.height += grows
    let tab = open(title, in: app, frame: frame)
    tab.tabGroup = window.tabGroup
    tab.extraHeightAsTab = window.extraHeightAsTab + grows
    return tab
  }

  /// A click on a tab. It posts nothing but "main window changed".
  public func chooseTab(_ tab: Window) {
    guard tab.isOpen, !tab.isFrontTab, let front = tab.app.windows.first(where: { $0.tabGroup == tab.tabGroup && $0.isFrontTab && $0.isOpen }), isShowing(front)
    else { return }
    note("the tab w\(tab.number) is chosen")
    bringTabForward(tab, insteadOf: front)
  }

  private func bringTabForward(_ tab: Window, insteadOf front: Window) {
    listWillChange(of: tab.app)
    front.isFrontTab = false
    tab.isFrontTab = true
    // The group is one window to the eye: the tabs share its place.
    tab.frame = front.frame
    tab.frame.size.height += tab.extraHeightAsTab - front.extraHeightAsTab
    tab.bounds = tab.frame
    tab.space = front.space
    if let index = stack.firstIndex(where: { $0 === front }) {
      stack.removeAll { $0 === tab }
      stack.insert(tab, at: min(index, stack.count))
    }
    makeKey(tab, reportingFocus: false)
  }
}
