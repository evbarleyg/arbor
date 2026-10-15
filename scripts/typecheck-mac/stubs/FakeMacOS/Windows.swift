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

  /// A sheet comes down over `parent` and takes the keyboard. Seen on a hosted Mac on 2026-10-15, of a test window and of TextEdit's Save As…: the window
  /// server gives it a number of its own; its role is AXSheet and it has no subrole; its app names IT as the focused window and `parent` as the main
  /// one; it is not among the app's windows. "Focused window changed" is posted, and "main window changed" 44 ms later if `parent` was not the main window.
  /// Both gave that window as their AXParent and as their AXWindow. Not modelled: that it goes where its window goes.
  @discardableResult
  public func openSheet(on parent: Window, size: CGSize = CGSize(width: 220, height: 120)) -> Window {
    lastWindowNumber += 1
    windowsMade += 1
    let frame = CGRect(x: parent.frame.midX - size.width / 2, y: parent.frame.minY + parent.titleBarHeight, width: size.width, height: size.height)
    let sheet = Window(number: lastWindowNumber, serial: windowsMade, app: parent.app, title: "", frame: frame, space: parent.space)
    sheet.role = "AXSheet"
    sheet.subrole = nil
    sheet.sheetOf = parent
    windowsBySerial[sheet.serial] = sheet
    parent.app.windows.append(sheet)
    note("a sheet, w\(sheet.number), comes down over w\(parent.number)")
    stack.insert(sheet, at: stack.firstIndex { $0 === parent } ?? 0)
    let app = parent.app
    app.focused = sheet
    report("AXFocusedWindowChanged", about: sheet)
    if app.main !== parent {
      appDoes(app, after: 0.044, "") { [self] in
        app.main = parent
        report("AXMainWindowChanged", about: parent)
      }
    }
    return sheet
  }

  /// The sheet is answered and goes. Its window has the keyboard again. That "focused window changed" is posted is a GUESS, from what is posted when it comes.
  public func closeSheet(_ sheet: Window) {
    guard sheet.isOpen, let parent = sheet.sheetOf else { return }
    note("the sheet w\(sheet.number) is answered and goes")
    sheet.isOpen = false
    sheet.exists = false
    stack.removeAll { $0 === sheet }
    forgetRegistrations(on: sheet)
    if sheet.app.focused === sheet { makeKey(parent) }
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
    if app.dropsAClosingWindowAtOnce {
      listWillChange(of: app)
      // Who is told is settled now, while there is still somebody subscribed; the word takes its time.
      window.closedWithoutAWord = !announced || !report("AXUIElementDestroyed", about: window, after: 0.2, mayBeDropped: true)
      window.isOpen = false
      window.exists = putAway
      window.isMinimized = false
      forgetRegistrations(on: window)
      if !putAway { stack.removeAll { $0 === window } }
      if mouse.grab?.window === window { mouse.grab = nil }
      return
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

  /// ⌘`: the person asks the app in front for another of its windows. A key goes to the app like a call does: if the app hangs, the key lies in its queue, behind what
  /// was sent before, and is obeyed when it wakes (a guess: nobody has recorded it; it is what typing at an app that hangs is known to end in).
  public func personAsksAppInFront(for window: Window) {
    note("⌘`: the person asks \(window.app.name) for w\(window.number)")
    appDoes(window.app, after: 0.001, "the key it finds in its queue: w\(window.number) is to be its key window") { [self] in
      raise(window)
      makeKey(window)
    }
  }

  /// A window has another frame and nobody has heard: its app posts nothing, or the report is still on its way.
  public func changeSilently(_ window: Window, to frame: CGRect) {
    note("w\(window.number) has the frame \(frame), and nothing says so")
    window.frame = frame
    window.bounds = frame
  }

  // MARK: Minimizing

  /// The yellow button, ⌘M, or `AXMinimized`. Trace `minimize-restore`: "miniaturized" comes when the animation is over, 0.55 s later, and 15 to 20 ms
  /// after that Arbor's layer of the day said that the displays had changed, because the Dock had grown.
  ///
  /// THE FLIGHT, measured without Arbor by a probe on a hosted Mac (macOS 26.6.2, 2026-10-15; origin/mac-shell-out/probe.flight, 63 rounds that count). VARIED: plain AppKit test windows and TextEdit; ⌘M by a posted key,
  /// the yellow button by a posted click, `AXMinimized` set from another process; Reduce Motion on and off. NOT VARIED, so a guess wherever it matters: the app was always IN FRONT, always had TWO windows, the one that
  /// flew had the keyboard; the Dock at the bottom with the genie, windows not minimized into their app's icon; an idle Mac; no other app.
  /// - It takes 0.50 to 0.66 s, with Reduce Motion as without.
  /// - THE WHOLE APP IS DEAF MEANWHILE: a question about its OTHER window, asked in flight, is answered when the flight is over (after 474 to 743 ms). Here: the app hangs for as long (`App.windowsInFlight`).
  /// - At the end, in this order: "focused window changed" and "main window changed" of the next window, "miniaturized"; 0 to 32 ms from first to last, mostly 1 to 4 (6.6 in another recording: `Timing`).
  /// - From the first of these on the window answers `AXMinimized` = yes (20 of 20, within 2 ms).
  /// - The window server lists it on screen all the way, in a box that changes from 25 to 90 ms after the hand (twice later), and drops it within 30 ms or so of the first report (`boxInFlight`).
  /// - The call that sets `AXMinimized` returns at once (`write`); the flight follows. With ONE window left TextEdit posts no "focused window changed" before "miniaturized" (the same later probe).
  /// What waits in the app's queue is served after the landing: a GUESS as to the order.
  public func minimize(_ window: Window) {
    guard window.isOpen, !window.isMinimized, !window.isInFlight else { return }
    note("w\(window.number) is being minimized")
    fly(window, out: false) { [self] in
      guard window.isOpen, !window.isMinimized else { return }
      window.isMinimized = true
      let hadTheKeyboard = window.app.focused === window
      nextWindowBecomesKey(in: window.app, insteadOf: window)
      // Posted by the app a moment after the focus. Whatever takes its main thread in between holds it back.
      appDoes(window.app, after: hadTheKeyboard && window.app.focused != nil ? timing.focusBeforeMiniaturized : 0, "") { [self] in report("AXWindowMiniaturized", about: window) }
      dockChanged(by: 2)
    }
  }

  /// Its app brings it back, or, `byHand`, a click on it in the Dock, which brings the app forward as well (that it does so at the click, not at the end of the flight, is a GUESS). The focus is reported first,
  /// 4 to 8 ms before "deminiaturized" (`minimize-restore`, `app-minimize`: both the app's own call); 1 ms before it after `AXRaise` (the probe).
  ///
  /// The flight out was measured only as `AXRaise` sets it off (`perform`): 0.53 to 0.58 s, the boxes of the way in backwards from some 70 ms on. That the app is deaf on the way out too is taken from the call's not
  /// returning before the end. What was held back comes first: a raise between the focus report and "miniaturized" gave "main window changed" of the sibling, "miniaturized", then "focused", "main", "deminiaturized" of the
  /// window, all within 2 ms, at the end of the flight out (20 of 20).
  public func restore(_ window: Window, byHand: Bool = false) {
    guard window.isOpen, window.isMinimized, !window.isInFlight else { return }
    note("w\(window.number) is being restored")
    if byHand, frontmost !== window.app { activate(window.app) }
    fly(window, out: true) { [self] in
      guard window.isOpen, window.isMinimized else { return }
      window.isMinimized = false
      window.space = activeSpace
      raise(window)
      makeKey(window)
      appDoes(window.app, after: timing.focusBeforeDeminiaturized, "") { [self] in report("AXWindowDeminiaturized", about: window) }
      dockChanged(by: -2)
    }
  }

  /// A window is on its way to the Dock or out of it, and its app's main thread with it.
  private func fly(_ window: Window, out: Bool, landing: @escaping () -> Void) {
    let app = window.app
    window.isBusyUntil = now + timing.minimizing + 0.05
    window.isInFlight = true
    window.isFlyingOut = out
    app.windowsInFlight += 1
    let (first, step) = (out ? 0.07 : 0.045, 0.016)
    let steps = Int((timing.minimizing - first - 0.005) / step)
    for number in 0...steps {
      send(after: first + Double(number) * step, from: .system, "") { [self] in
        guard window.isOpen, window.isInFlight else { return }
        let part = Double(number) / Double(steps)
        window.bounds = boxInFlight(of: window.frame, part: out ? 1 - part : part)
      }
    }
    send(after: timing.minimizing, from: .system, "") { [self] in
      guard app.isAlive else { return }
      window.isInFlight = false
      window.isFlyingOut = false
      window.bounds = window.frame
      app.windowsInFlight = max(0, app.windowsInFlight - 1)
      if out { seeToTheQueue(of: app) }
      landing()
      seeToTheQueue(of: app)
    }
  }

  /// The box the window server gives for a window so far on its way into the Dock: the genie's. A sketch of what was measured for a window at 170,220 480×348 on a display of 1024×768: it stays where it is and widens towards
  /// the Dock's slot (to 712 points, two fifths of the way), then its far corner is at the slot's and its near corner follows (234,314 700×349; 629,503 322×243; 904,674 47×72; at last 916,717 35×29). Where the
  /// slot is with other windows in the Dock, or another Dock, nobody has measured.
  func boxInFlight(of frame: CGRect, part: Double) -> CGRect {
    let screen = screen(of: frame).frame
    let slot = CGRect(x: screen.maxX - 108, y: screen.maxY - 51, width: 35, height: 29)
    let widest = max(frame.width, (slot.maxX - frame.minX) * 0.91)
    guard part > 0.4 else { return CGRect(x: frame.minX, y: frame.minY, width: (frame.width + (widest - frame.width) * CGFloat(part / 0.4)).rounded(), height: frame.height) }
    let rest = CGFloat((part - 0.4) / 0.6)
    let (near, far) = (rest * rest, min(1, rest * 2))
    let origin = CGPoint(x: frame.minX + (slot.minX - frame.minX) * near, y: frame.minY + (slot.minY - frame.minY) * near)
    let corner = CGPoint(x: frame.minX + widest + (slot.maxX - frame.minX - widest) * far, y: frame.maxY + (slot.maxY - frame.maxY) * far)
    return CGRect(x: origin.x.rounded(), y: origin.y.rounded(), width: max(slot.width, (corner.x - origin.x).rounded()), height: max(slot.height, (corner.y - origin.y).rounded()))
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
