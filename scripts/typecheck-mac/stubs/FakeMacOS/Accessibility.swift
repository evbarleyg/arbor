// The model of a Mac (FakeMac.swift): what apps answer to Accessibility calls, and what observers are told. Never shipped.
import Foundation

extension FakeMac {
  /// `AXError`'s raw values. The enum itself belongs to ApplicationServices' stand-in, which imports this module.
  public enum Answer: Int32, Sendable {
    case success = 0
    case failure = -25200, illegalArgument = -25201, invalidUIElement = -25202
    case cannotComplete = -25204, attributeUnsupported = -25205, actionUnsupported = -25206, notificationUnsupported = -25207
    case notificationAlreadyRegistered = -25209, notificationNotRegistered = -25210
    case apiDisabled = -25211, noValue = -25212
  }

  public enum Value: Equatable, Sendable {
    case string(String)
    case bool(Bool)
    case point(CGPoint)
    case size(CGSize)
    case element(Element)
    case elements([Element])
  }

  // MARK: Every call

  /// What every call that goes to an app's process begins with. Nil: the app is there and listens.
  ///
  /// - A process that is gone fails at once (docs/ARCHITECTURE.md, "an app can end without a word").
  /// - One that hangs makes the caller wait for the whole timeout, on the model's clock, unless it wakes before. The main thread does nothing else meanwhile, and what
  ///   falls due for it is delivered afterwards; the Mac and Arbor's other threads go on (Threads.swift). A call on a queue's thread waits likewise. Only a job of Swift's global
  ///   pool (`Task.detached`), which the pump runs on the main thread, cannot wait: its call fails at once, so that Arbor's question "are you back?" is asked every 0.5 s here
  ///   and every 1.5 s on a Mac.
  private func refusal(by pid: pid_t, timeout: TimeInterval?) -> Answer? {
    // A process that is no more asks nothing.
    guard !arborHasGone else { return .cannotComplete }
    calls += 1
    guard isTrusted else { return .apiDisabled }
    guard let app = app(pid), app.isAlive else { return .cannotComplete }
    if let left = app.hangsAfterCalls {
      app.hangsAfterCalls = left > 0 ? left - 1 : nil
      if left == 0 { hang(app) }
    }
    let isOnAThread = Worker.holder != nil
    if app.isHung {
      // A job of the global pool runs on the main thread here, which cannot wait in its stead.
      guard isOnAThread || !Pump.isOffTheMainThread else { return .cannotComplete }
      // A timeout of 0 means the default, not "do not wait": Apple's header says so; not measured.
      let wait = timeout.flatMap { $0 > 0 ? $0 : nil } ?? processTimeout
      self.wait(until: now + wait) { !app.isHung || !app.isAlive }
      guard app.isAlive else { return .cannotComplete }
      if app.isHung || hasEnded {
        if !isOnAThread {
          secondsWaitedInVain += wait
          app.secondsWaitedForInThisHang += wait
          longestWaitForOneHang = max(longestWaitForOneHang, app.secondsWaitedForInThisHang)
        }
        note("    (\(isOnAThread ? "a thread of Arbor's" : "Arbor") waited \(wait) s for pid \(pid), which hangs)")
        return .cannotComplete
      }
      // It woke in time, has seen to what was in its queue, and answers this call late.
    }
    let cost = app.answersIn ?? timing.answer
    if isOnAThread {
      Worker.holder?.wait(cost)
    } else if !Pump.isOffTheMainThread {
      now += cost
      secondsTheMainThreadWaited += cost
    }
    return nil
  }

  /// A timeout belongs to one element object, except that the system-wide element's is the whole process's.
  public func setProcessTimeout(_ seconds: TimeInterval) { processTimeout = seconds > 0 ? seconds : 6 }

  // MARK: Reading

  public func read(_ attribute: String, of element: Element, timeout: TimeInterval?) -> (answer: Answer, value: Value?) {
    guard let pid = element.pid else { return (isTrusted ? .attributeUnsupported : .apiDisabled, nil) }
    if let refusal = refusal(by: pid, timeout: timeout) { return (refusal, nil) }
    return answer(to: attribute, of: element)
  }

  /// What an app that listens says.
  private func answer(to attribute: String, of element: Element) -> (answer: Answer, value: Value?) {
    guard let pid = element.pid, let app = app(pid) else { return (.cannotComplete, nil) }
    func answer(_ value: Value?) -> (Answer, Value?) { value.map { (.success, $0) } ?? (.noValue, nil) }

    guard case .window = element else {
      switch attribute {
      case "AXRole": return answer(.string("AXApplication"))
      case "AXTitle": return answer(.string(app.name))
      case "AXWindows": return answer(.elements(listedWindows(of: app).map(\.element)))
      case "AXFocusedWindow": return answer(app.focused.map { .element($0.element) })
      case "AXMainWindow": return answer(app.main.map { .element($0.element) })
      case "AXHidden": return answer(.bool(app.isHidden))
      case "AXFrontmost": return answer(.bool(frontmost === app))
      case "AXEnhancedUserInterface": return answer(.bool(app.hasEnhancedUserInterface))
      default: return (.attributeUnsupported, nil)
      }
    }
    // A destroyed element answers nothing any more.
    guard let window = window(for: element), window.isOpen else { return (.invalidUIElement, nil) }
    switch attribute {
    case "AXRole": return answer(window.role.map { .string($0) })
    case "AXSubrole": return answer(subroleNow(of: window).map { .string($0) })
    case "AXTitle": return answer(.string(window.title))
    case "AXPosition": return answer(.point(window.frame.origin))
    case "AXSize": return answer(.size(window.frame.size))
    case "AXMinimized": return answer(.bool(window.isMinimized))
    case "AXFullScreen": return answer(.bool(window.isFullScreen))
    case "AXMain": return answer(.bool(app.main === window))
    case "AXFocused": return answer(.bool(app.focused === window))
    default: return (.attributeUnsupported, nil)
    }
  }

  /// macOS 26 reports AXDialog for every minimized window and every window of a hidden app, ordinary ones included, and AXStandardWindow again
  /// once they show (Sources/ArborCore/WindowKind.swift).
  func subroleNow(of window: Window) -> String? {
    guard now >= window.hasSubroleFrom else { return "AXUnknown" }
    if window.subrole == "AXStandardWindow", window.isMinimized || window.app.isHidden { return "AXDialog" }
    return window.subrole
  }

  /// What an app lists: its open windows on the Space that shows, front to back, minimized ones and those of a hidden app included. Of a native
  /// tab group only the tab in front.
  func listedWindows(of app: App) -> [Window] {
    if now < listsAreEmptyUntil { return [] }
    if let stale = app.staleList {
      if now < stale.until { return stale.windows }
      app.staleList = nil
    }
    return currentList(of: app)
  }

  private func currentList(of app: App) -> [Window] {
    stack.filter { $0.app === app && $0.isOpen && $0.isFrontTab && $0.space == activeSpace }
  }

  /// To be called before an app's list changes: with bad manners (ii) the old one is given out a while longer.
  func listWillChange(of app: App) {
    let lag = app.listLagsBy > 0 ? app.listLagsBy : manners.lag(upTo: manners.staleness)
    if lag > 0, app.staleList == nil { app.staleList = (now + lag, currentList(of: app)) }
  }

  /// `AXUIElementCopyMultipleAttributeValues`: one message, one wait. As many answers as questions; nil for an attribute the element has not got.
  public func read(_ attributes: [String], of element: Element, timeout: TimeInterval?) -> (answer: Answer, values: [Value?]) {
    guard let pid = element.pid else { return (isTrusted ? .illegalArgument : .apiDisabled, []) }
    if let refusal = refusal(by: pid, timeout: timeout) { return (refusal, []) }
    if case .window = element {
      guard let window = window(for: element), window.isOpen else { return (.invalidUIElement, []) }
    }
    return (.success, attributes.map { answer(to: $0, of: element).value })
  }

  public func isSettable(_ attribute: String, of element: Element, timeout: TimeInterval?) -> (answer: Answer, settable: Bool) {
    guard let pid = element.pid else { return (.illegalArgument, false) }
    if let refusal = refusal(by: pid, timeout: timeout) { return (refusal, false) }
    guard let window = window(for: element), window.isOpen else { return (.invalidUIElement, false) }
    switch attribute {
    case "AXSize": return (.success, window.isResizable)
    case "AXPosition", "AXMinimized", "AXMain", "AXFullScreen": return (.success, true)
    default: return (.success, false)
    }
  }

  /// The private call every window manager uses. Taken to be a call like any other: a destroyed element has no number any more
  /// (Sources/ArborKit/AX/AXWindowSystem.swift, "Observation model"). That it waits for a hung app is a guess.
  public func windowNumber(of element: Element, timeout: TimeInterval?) -> (answer: Answer, number: UInt32) {
    guard let pid = element.pid else { return (.illegalArgument, 0) }
    if let refusal = refusal(by: pid, timeout: timeout) { return (refusal, 0) }
    guard let window = window(for: element), window.isOpen else { return (.invalidUIElement, 0) }
    return (.success, window.number)
  }

  // MARK: Writing

  public func write(_ value: Value, to attribute: String, of element: Element, timeout: TimeInterval?) -> Answer {
    guard let pid = element.pid else { return .illegalArgument }
    if let app = app(pid), reaches(app) {
      // The message is in the app's queue from the moment it is sent, and is read when the app wakes, though the caller has given up by then. Not if the caller is no more (`arborIsGone`).
      var outcome: Answer?
      app.backlog.append(("what was asked of it while it hung: \(attribute) = \(value)", .waiting, { [self] in outcome = carryOut(value, attribute, element, app) }))
      return refusal(by: pid, timeout: timeout) ?? outcome ?? .cannotComplete
    }
    let refusal = refusal(by: pid, timeout: timeout)
    guard let app = app(pid), app.isAlive else { return refusal ?? .cannotComplete }
    if refusal == .cannotComplete, app.isHung, !arborHasGone {
      // It began to hang at this very call.
      app.backlog.append(("what was asked of it while it hung: \(attribute) = \(value)", app.hangsInTheMiddleOfThatCall ? .underWay : .waiting, { [self] in _ = carryOut(value, attribute, element, app) }))
    }
    if let refusal { return refusal }
    if case .window = element {
      guard let window = window(for: element), window.isOpen else { return .invalidUIElement }
      if attribute == "AXSize", !window.isResizable { return .failure }
    }
    let lag = max(manners.lag(upTo: manners.lateCalls), app.carriesOutAfter)
    // An app reads what it is sent in order: behind a call that still waits, the next waits too.
    if lag > 0 || app.callsStillToCarryOut > 0 {
      app.callsStillToCarryOut += 1
      appDoes(app, after: lag, "pid \(pid) carries out, late: \(attribute)") { [self] in
        app.callsStillToCarryOut -= 1
        _ = carryOut(value, attribute, element, app)
      }
      return .success
    }
    return carryOut(value, attribute, element, app)
  }

  /// Whether a message now would lie in the queue of an app that hangs.
  private func reaches(_ app: App) -> Bool {
    app.isAlive && app.isHung && isTrusted && !arborHasGone && !hasEnded && app.hangsAfterCalls == nil && (Worker.holder != nil || !Pump.isOffTheMainThread)
  }

  private func carryOut(_ value: Value, _ attribute: String, _ element: Element, _ app: App) -> Answer {
    guard case .window = element else {
      switch (attribute, value) {
      case ("AXEnhancedUserInterface", .bool(let on)): app.hasEnhancedUserInterface = on
      case ("AXFrontmost", .bool(true)): activate(app)
      case ("AXHidden", .bool(let hidden)): hidden ? hide(app) : unhide(app)
      default: return .attributeUnsupported
      }
      return .success
    }
    guard let window = window(for: element), window.isOpen else { return .invalidUIElement }
    switch (attribute, value) {
    case ("AXPosition", .point(let point)): setPosition(point, of: window)
    case ("AXSize", .size(let size)):
      if app.appliesSizeAfter > 0 {
        appDoes(app, after: app.appliesSizeAfter, "pid \(app.pid) applies the size it was given") { [self] in setSize(size, of: window) }
      } else {
        setSize(size, of: window)
      }
    case ("AXMinimized", .bool(let minimized)): minimized ? minimize(window) : restore(window)
    case ("AXMain", .bool(true)): makeKey(window)
    case ("AXFullScreen", .bool(let full)): full ? enterFullScreen(window) : leaveFullScreen(window)
    default: return .attributeUnsupported
    }
    return .success
  }

  public func perform(_ action: String, on element: Element, timeout: TimeInterval?) -> Answer {
    guard let pid = element.pid else { return .illegalArgument }
    if let app = app(pid), reaches(app), action == "AXRaise", let window = window(for: element) {
      app.backlog.append(("what was asked of it while it hung: AXRaise", .waiting, { [self] in raise(window) }))
      return refusal(by: pid, timeout: timeout) ?? .success
    }
    if let refusal = refusal(by: pid, timeout: timeout) {
      // It began to hang at this very call.
      if refusal == .cannotComplete, let app = app(pid), app.isHung, action == "AXRaise", let window = window(for: element) {
        app.backlog.append(("what was asked of it while it hung: AXRaise", app.hangsInTheMiddleOfThatCall ? .underWay : .waiting, { [self] in raise(window) }))
      }
      return refusal
    }
    guard let window = window(for: element), window.isOpen else { return .invalidUIElement }
    guard action == "AXRaise" else { return .actionUnsupported }
    raise(window)
    return .success
  }

  // MARK: Frames

  /// The display a window counts as being on: the one that holds its top-left corner, else the one nearest to it.
  func screen(of frame: CGRect) -> Screen {
    let corner = frame.origin
    if let holder = screens.first(where: { $0.frame.contains(corner) }) { return holder }
    func distance(_ screen: Screen) -> CGFloat {
      let dx = max(screen.frame.minX - corner.x, 0, corner.x - screen.frame.maxX)
      let dy = max(screen.frame.minY - corner.y, 0, corner.y - screen.frame.maxY)
      return dx * dx + dy * dy
    }
    return screens.min { distance($0) < distance($1) } ?? .hostedMac
  }

  /// Where a window ends up that was asked to go to `point`.
  /// - Whole points: 150.5 became 150, 261.5 became 261 (x), 46.5 became 47 (y) (traces/README.md, row 4).
  /// - A title bar never goes below the visible frame: asked for y 767 the test windows took 673, which is the visible frame's bottom less the
  ///   title bar (row 3). x is not limited.
  /// - Nor under the menu bar. Common knowledge about AppKit; not in a trace.
  func allowedOrigin(_ point: CGPoint, for window: Window) -> CGPoint {
    var origin = CGPoint(x: (point.x - 0.5).rounded(.up), y: (point.y + 0.5).rounded(.down))
    let visible = screen(of: CGRect(origin: origin, size: window.frame.size)).visibleFrame
    origin.y = min(max(origin.y, visible.minY), visible.maxY - window.titleBarHeight)
    return origin
  }

  /// The size a window takes that was asked for `size` where it is now: within its own limits, in whole points, and no larger than
  /// the visible frame of the display it is on (Sources/ArborCore/FramePlan.swift: "a large window is clamped").
  func allowedSize(_ size: CGSize, for window: Window, at origin: CGPoint) -> CGSize {
    let visible = screen(of: CGRect(origin: origin, size: size)).visibleFrame
    func fit(_ wanted: CGFloat, _ least: CGFloat, _ most: CGFloat, _ room: CGFloat) -> CGFloat {
      max(min(wanted.rounded(), most, max(room, least)), least)
    }
    return CGSize(
      width: fit(size.width, window.minimumSize.width, window.maximumSize.width, visible.width),
      height: fit(size.height, window.minimumSize.height, window.maximumSize.height, visible.height))
  }

  func setPosition(_ point: CGPoint, of window: Window) {
    window.timesAskedForAFrame += 1
    // macOS accepts a new frame for a full-screen window and does nothing.
    guard !window.isFullScreen else { return }
    let before = window.frame
    let origin = allowedOrigin(point, for: window)
    // On the way to a smaller display a large window is cut to what fits there.
    let size = allowedSize(before.size, for: window, at: origin)
    change(window, to: CGRect(origin: origin, size: size), goingBackTo: before)
  }

  func setSize(_ size: CGSize, of window: Window) {
    window.timesAskedForAFrame += 1
    guard !window.isFullScreen, window.isOpen, window.isResizable else { return }
    let before = window.frame
    change(window, to: CGRect(origin: before.origin, size: allowedSize(size, for: window, at: before.origin)), goingBackTo: before)
  }

  /// Gives a window a frame on behalf of somebody outside its app, at once or, with "enhanced user interface", in steps.
  private func change(_ window: Window, to frame: CGRect, goingBackTo before: CGRect) {
    guard frame != before else { return }
    if window.app.hasEnhancedUserInterface {
      for step in 1...3 {
        let part = CGFloat(step) / 3
        let stage = CGRect(
          x: (before.minX + (frame.minX - before.minX) * part).rounded(), y: (before.minY + (frame.minY - before.minY) * part).rounded(),
          width: (before.width + (frame.width - before.width) * part).rounded(),
          height: (before.height + (frame.height - before.height) * part).rounded())
        appDoes(window.app, after: timing.animation * Double(part), "w\(window.number) is animated on its way") { [self] in take(stage, window) }
      }
    } else {
      take(frame, window, listedAfter: serverListsACallAfter)
    }
    if let delay = window.goesBackAfter {
      appDoes(window.app, after: delay, "w\(window.number) goes back to where it was") { [self] in take(before, window) }
    }
  }

  /// The window has this frame now, and its app says so: "resized" if the size changed, "moved" if the place did.
  func take(_ frame: CGRect, _ window: Window, listedAfter lag: TimeInterval = 0) {
    guard window.isOpen else { return }
    let before = window.frame
    window.frame = frame
    if lag > 0 {
      send(after: lag, from: .system, "") { if window.frame == frame { window.bounds = frame } }
    } else {
      window.bounds = frame
    }
    if before.size != frame.size { report("AXResized", about: window) }
    if before.origin != frame.origin { report("AXMoved", about: window) }
  }

  // MARK: Observers

  public final class Observer {
    public let pid: pid_t
    let tell: (Element, String, UnsafeMutableRawPointer?) -> Void
    var registrations: [(element: Element, name: String, refcon: UnsafeMutableRawPointer?)] = []
    /// Nothing is delivered unless the observer's source is on a run loop.
    public var isOnRunLoop = false

    init(pid: pid_t, tell: @escaping (Element, String, UnsafeMutableRawPointer?) -> Void) {
      self.pid = pid
      self.tell = tell
    }
  }

  public func makeObserver(for pid: pid_t, tell: @escaping (Element, String, UnsafeMutableRawPointer?) -> Void) -> (answer: Answer, observer: Observer?) {
    guard isTrusted else { return (.apiDisabled, nil) }
    guard let app = app(pid), app.isAlive else { return (.failure, nil) }
    let observer = Observer(pid: pid, tell: tell)
    observers.append(observer)
    return (.success, observer)
  }

  /// Apps that are still launching refuse every subscription (scripts/mac-shell/apptool.swift). That they do so at once, with
  /// `cannotComplete`, is a guess.
  public func register(_ observer: Observer, for name: String, on element: Element, refcon: UnsafeMutableRawPointer?, timeout: TimeInterval?) -> Answer {
    if let refusal = refusal(by: observer.pid, timeout: timeout) { return refusal }
    guard let app = app(observer.pid), element.pid == observer.pid else { return .illegalArgument }
    if now < app.refusesObserversUntil { return .cannotComplete }
    if case .window = element {
      guard let window = window(for: element), window.isOpen else { return .invalidUIElement }
    }
    if observer.registrations.contains(where: { $0.element == element && $0.name == name }) { return .notificationAlreadyRegistered }
    observer.registrations.append((element, name, refcon))
    return .success
  }

  public func unregister(_ observer: Observer, from name: String, on element: Element) -> Answer {
    let before = observer.registrations.count
    observer.registrations.removeAll { $0.element == element && $0.name == name }
    return observer.registrations.count < before ? .success : .notificationNotRegistered
  }

  /// The observer's owner has let go of it.
  public func retire(_ observer: Observer) { observers.removeAll { $0 === observer } }

  /// Returns false if it was dropped.
  @discardableResult
  func report(_ name: String, about window: Window, after delay: TimeInterval = 0, mayBeDropped: Bool = false) -> Bool {
    report(name, about: window.element, of: window.app, shown: "w\(window.number)", after: delay, mayBeDropped: mayBeDropped)
  }

  func report(_ name: String, about app: App, after delay: TimeInterval = 0) {
    _ = report(name, about: .app(app.pid), of: app, shown: "", after: delay, mayBeDropped: false)
  }

  /// An app posts a notification. Who is told is settled now, by who has subscribed by now; the word is then on its way.
  /// A subscription on the app's element gets what is posted about any of its windows: that is how "created" and "focused window changed"
  /// are subscribed to, and why they carry no window's number.
  private func report(_ name: String, about element: Element, of app: App, shown: String, after delay: TimeInterval, mayBeDropped: Bool) -> Bool {
    guard app.isAlive else { return true }
    if app.isHung {
      // Its main thread would have posted it.
      app.backlog.append(("", .byNobody, { [self] in _ = report(name, about: element, of: app, shown: shown, after: delay, mayBeDropped: false) }))
      return true
    }
    if mayBeDropped, manners.chance(manners.drops) {
      note("(dropped: \(name) \(shown) of pid \(app.pid))")
      return false
    }
    let times = manners.chance(manners.repeats) ? 2 : 1
    for observer in observers where observer.pid == app.pid {
      for registration in observer.registrations where registration.name == name {
        guard registration.element == element || registration.element == .app(app.pid) else { continue }
        for _ in 0..<times {
          send(after: timing.report + app.reportsLateBy + delay, from: .accessibility(app.pid), "→ \(name) \(shown) (pid \(app.pid))") { [weak observer] in
            guard let observer, observer.isOnRunLoop else { return }
            observer.tell(element, name, registration.refcon)
          }
        }
      }
    }
    return true
  }

  /// With the window its subscriptions go.
  func forgetRegistrations(on window: Window) {
    for observer in observers { observer.registrations.removeAll { $0.element == window.element } }
  }

  /// Something an app does by itself a moment later. If it hangs by then, it does it when it wakes.
  func appDoes(_ app: App, after delay: TimeInterval, _ label: String, _ action: @escaping () -> Void) {
    send(after: delay, from: .app(app.pid), "") { [self] in
      guard app.isAlive else { return }
      if app.isHung {
        app.backlog.append((label, .byNobody, action))
      } else {
        if !label.isEmpty { note(label) }
        action()
      }
    }
  }
}
