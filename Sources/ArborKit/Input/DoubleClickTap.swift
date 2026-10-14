import AppKit
import ApplicationServices
import ArborCore
import os

/// Double-clicking a docked window's title bar frames the window, double-clicking bare Desktop focuses
/// the Desktop, and doing either again goes back. The second click of a double-click on a tile that opened on
/// the first goes nowhere (docs/features/F14-double-click-actions.md).
///
/// It takes an event tap because macOS has its own title-bar double-click (zoom or minimize), and only a
/// tap can keep a click from an app. Every decision is made in ArborCore: `DoubleClickZones` says what
/// a point means, `PointerCover` and `Hit.isBackground` whether the click would really land there, and
/// `DoubleClickGesture` which events to hide. This class installs the taps, keeps their copy of the
/// zones current and runs the command.
///
/// Two taps, both on the tap thread (`EventTapThread`): one on mouse-downs, which lets every click but the
/// second of a pair go at once; and one on what follows a second press that may be Arbor's, paused except
/// from that mouse-down until the button comes up or the pointer moves away. The press is held back meanwhile. A
/// click is hidden whole and runs its command; a drag is given back from its beginning, a moment late. The taps
/// are installed together, so that no other app's tap comes between them: one in between would see the
/// mouse-down of a hidden click and never its mouse-up, and the mouse-down of a drag twice. What they decide
/// from lives in a lock-protected box. The main actor swaps new zones in; a callback never waits for
/// the main actor.
@MainActor
final class DoubleClickTap {
  private struct TapState {
    var zones = DoubleClickZones()
    /// The windows of Arbor's own that take clicks (tiles, seam handles) rather than decorate.
    var ownClickable: Set<WindowID> = []
    /// The user's double-click time.
    var interval = DoubleClickZones.usualInterval
    var gesture = DoubleClickGesture()
    /// The mouse-down held back until it is known whether a drag follows.
    var heldDown: HeldEvent?
    /// The tap on what follows a press that may be Arbor's, paused the rest of the time.
    var releaseTap: EventTap?
    /// The main actor has been asked to publish again and has not done so yet.
    var refreshQueued = false
  }

  /// An event on its way from one callback to the next. Read only on the tap thread; the main actor at most lets go of it.
  private struct HeldEvent: @unchecked Sendable {
    let event: CGEvent
  }

  /// What the tap callbacks need: the state, and the three things that must happen on the main actor.
  private final class Context: Sendable {
    let state = OSAllocatedUnfairLock(initialState: TapState())
    let onCommand: @MainActor (Command) -> Void
    let onPress: @MainActor () -> Void
    let refresh: @MainActor () -> Void

    init(
      onCommand: @escaping @MainActor (Command) -> Void, onPress: @escaping @MainActor () -> Void,
      refresh: @escaping @MainActor () -> Void
    ) {
      self.onCommand = onCommand
      self.onPress = onPress
      self.refresh = refresh
    }
  }

  private let settings: @MainActor () -> Settings
  private var context: Context!
  private weak var controller: Controller?
  private var downTap: EventTap?

  /// - Parameter onPress: told of every press that is held back. Whoever listens for presses with an `NSEvent` monitor
  ///   hears nothing of those, unless and until they are given back.
  init(
    settings: @escaping @MainActor () -> Settings, onCommand: @escaping @MainActor (Command) -> Void,
    onPress: @escaping @MainActor () -> Void
  ) {
    self.settings = settings
    context = Context(
      onCommand: onCommand, onPress: onPress,
      refresh: { [weak self] in
        // People change macOS's own answer while Arbor runs. If it has changed, the taps hear of it from the controller.
        self?.controller?.lookAtMacTitleBarAction()
        self?.publish()
      })
  }

  /// Takes the zones from `controller` from now on, whenever something they depend on changes.
  func follow(_ controller: Controller) {
    self.controller = controller
    controller.observe { [weak self, weak controller] change in
      switch change {
      // None of them changes a zone the tap goes by: of floating windows it asks the window server.
      case .focus, .savedViews, .keyboard, .names, .windows: break
      // Dozens a second while a window is in somebody's hand, and what comes of it ends in a layout.
      case .frames where controller?.draggedWindow != nil || controller?.edgeResizedWindow != nil: break
      default: self?.publish()
      }
    }
    publish()
  }

  /// Installs the taps while `titleBarDoubleClick` or `desktopDoubleClick` is on, and removes them
  /// otherwise. Runs at launch and whenever settings are applied.
  func update() {
    guard settings().wantsDoubleClickTap else {
      stop()
      return
    }
    guard downTap == nil else { return }
    let context = self.context!
    let tap = EventTap(name: "double-click", mask: 1 << CGEventType.leftMouseDown.rawValue) { event, _ in
      Self.handleDown(event, context: context)
    }
    tap.onReset = { Self.reset(context) }
    // Mouse-downs too: one that arrives while a mouse-up is awaited says that the mouse-up was missed,
    // and noticing it here keeps the mouse-down tap's way out for ordinary clicks short.
    let releaseMask = [CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp].reduce(CGEventMask(0)) {
      $0 | (1 << $1.rawValue)
    }
    let releaseTap = EventTap(name: "double-click release", mask: releaseMask) { event, proxy in
      Self.handleRelease(event, proxy: proxy, context: context)
    }
    releaseTap.onReset = { Self.reset(context) }
    guard tap.start() else { return }
    guard releaseTap.start(paused: true) else {
      tap.stop()
      return
    }
    context.state.withLock { $0.releaseTap = releaseTap }
    downTap = tap
    Log.info("double-click event taps installed")
    // Until now there were no zones, so a double-click that arrived meanwhile was let through.
    publish()
  }

  func stop() {
    guard let downTap else { return }
    downTap.stop()
    self.downTap = nil
    Self.reset(context)
    let releaseTap = context.state.withLock { state -> EventTap? in
      defer { state.releaseTap = nil }
      // Nobody keeps them current while the taps are away, and the next taps must not start from these.
      state.zones = DoubleClickZones()
      state.refreshQueued = false
      return state.releaseTap
    }
    releaseTap?.stop()
    Log.info("double-click event taps removed")
  }

  /// See `EventTap.reviveIfSwitchedOff`.
  func revive() {
    downTap?.reviveIfSwitchedOff()
    context.state.withLock { $0.releaseTap }?.reviveIfSwitchedOff()
  }

  var isInstalled: Bool { downTap != nil }

  /// Hands the callbacks what they decide from. Nobody reads it while the tap is off.
  private func publish() {
    guard downTap != nil, let controller else { return }
    let zones = controller.doubleClickZones()
    // Which of Arbor's panels take clicks is known to AppKit alone. Observers hear of a layout after its
    // panels are up, so tiles and handles are in it. What comes up without a layout (a picker, a settings
    // window) gets in at the first click of a pair: see `prepare`.
    let clickable = Set(
      NSApp.windows.filter { $0.isVisible && !$0.ignoresMouseEvents }
        .compactMap { UInt32(exactly: $0.windowNumber) }.map { WindowID($0) })
    let interval = NSEvent.doubleClickInterval
    context.state.withLock {
      $0.zones = zones
      $0.ownClickable = clickable
      $0.interval = interval
      $0.refreshQueued = false
    }
  }

  // MARK: On the tap thread

  /// Returns true to swallow the event.
  private nonisolated static func handleDown(_ event: CGEvent, context: Context) -> Bool {
    // Every click on the Mac waits for this callback, and all but the second of a pair leave here.
    let clicks = Int(event.getIntegerValueField(.mouseEventClickState))
    let point = event.location
    guard DoubleClickGesture.isDoubleClick(clicks: clicks) else {
      prepare(for: point, context)
      return false
    }
    guard event.getIntegerValueField(.eventSourceUserData) != EventTap.replayMark else { return false }

    let modifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    let (zones, ownClickable, interval) = context.state.withLock { ($0.zones, $0.ownClickable, $0.interval) }
    // Not under the lock: `confirm` asks the window server and an app, and the main actor must not wait for them.
    var gesture = DoubleClickGesture()
    let response = gesture.mouseDown(
      at: point, clicks: clicks, modifiersHeld: !event.flags.isDisjoint(with: modifiers),
      hit: zones.hit(
        at: point, time: Date().timeIntervalSinceReferenceDate, interval: interval, floatingWindowsCover: false),
      confirm: { hit in
        PointerProbe.confirms(hit, at: point, displays: zones.displays.map(\.frame), ownClickable: ownClickable)
      })
    switch response {
    case .hold:
      // Hold the press back only if it can be given back: with nothing to send on, or nothing watching
      // for what follows, the app gets all of it.
      guard let copy = event.copy(), follow(gesture, holding: HeldEvent(event: copy), context) else { return false }
      DispatchQueue.main.async { context.onPress() }
      return true
    case .watch:
      // Without the tap that sees the mouse-up nothing runs.
      _ = follow(gesture, holding: nil, context)
      return false
    default:
      return false
    }
  }

  /// The first click of what may become a pair. If it falls where a second one would be Arbor's, the main actor
  /// publishes again meanwhile, so that the second is judged by what is on screen now: a panel of Arbor's own that
  /// came up over a title bar since the last layout keeps its double-clicks. One lock and a few rectangles.
  private nonisolated static func prepare(for point: CGPoint, _ context: Context) {
    let isWorthIt = context.state.withLock { state -> Bool in
      guard !state.refreshQueued, state.zones.hit(at: point, floatingWindowsCover: false) != nil else { return false }
      state.refreshQueued = true
      return true
    }
    if isWorthIt { DispatchQueue.main.async { context.refresh() } }
  }

  /// Returns true to swallow the event.
  private nonisolated static func handleRelease(_ event: CGEvent, proxy: CGEventTapProxy, context: Context) -> Bool {
    // What Arbor posts itself is nobody's click.
    if event.getIntegerValueField(.eventSourceUserData) == EventTap.replayMark { return false }
    let type = event.type
    let point = event.location
    let (response, held, isOver) = context.state.withLock {
      state -> (DoubleClickGesture.Response, HeldEvent?, Bool) in
      let response: DoubleClickGesture.Response
      switch type {
      case .leftMouseDragged: response = state.gesture.mouseDragged(to: point)
      case .leftMouseUp: response = state.gesture.mouseUp()
      default:
        // Another mouse-down: the mouse-up was missed, and the next one belongs to this press.
        state.gesture.reset()
        response = .pass
      }
      guard !state.gesture.isFollowing else { return (response, nil, false) }
      defer { state.heldDown = nil }
      return (response, state.heldDown, true)
    }
    switch response {
    case .replay:
      // The app gets the mouse-down it missed, then this drag.
      if let held {
        held.event.setIntegerValueField(.eventSourceUserData, value: EventTap.replayMark)
        held.event.tapPostEvent(proxy)
      }
    case .run(let command, _):
      // On the main actor after the callback returns: the controller moves windows, which takes a while.
      DispatchQueue.main.async { context.onCommand(command) }
    case .swallow:
      if isOver { TapLog.debug("swallowed a second click that had nothing to run") }
    case .pass, .watch, .hold:
      break
    }
    if isOver { stopFollowing(context) }
    return response.swallows
  }

  /// Lets the release tap see what follows the press `gesture` has just taken note of. On the tap thread, so it
  /// sees the very next event. Returns false if there is no tap to follow with.
  private nonisolated static func follow(
    _ gesture: DoubleClickGesture, holding held: HeldEvent?, _ context: Context
  ) -> Bool {
    guard let tap = context.state.withLock({ $0.releaseTap }), tap.resume() else { return false }
    context.state.withLock {
      $0.gesture = gesture
      $0.heldDown = held
    }
    return true
  }

  private nonisolated static func stopFollowing(_ context: Context) {
    context.state.withLock { $0.releaseTap }?.pause()
  }

  /// Forgets the click in progress, for when events may have been missed, and for `stop()`. A press that is held back
  /// while the button is still down goes to the app after all, as in `RectangleFramer`: `DoubleClickGesture.reset`.
  private nonisolated static func reset(_ context: Context) {
    let isDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
    let held = context.state.withLock { state -> HeldEvent? in
      defer { state.heldDown = nil }
      return state.gesture.reset(buttonIsDown: isDown) == .replay ? state.heldDown : nil
    }
    if let held {
      // Not in a callback, so it enters where all events of the session do, and passes Arbor's taps by its mark.
      held.event.setIntegerValueField(.eventSourceUserData, value: EventTap.replayMark)
      held.event.post(tap: .cgSessionEventTap)
    }
    stopFollowing(context)
  }
}

/// Asks macOS what is under the pointer. It runs only for the second click of a double-click inside a
/// zone, touches none of Arbor's state, and may run on any thread.
enum PointerProbe {
  /// How long the window server and the app may take over all their answers together. All input on the Mac waits meanwhile,
  /// everybody's, so this is the ceiling of the wait and not a mark to aim for (the product owner's number): an app that is hung
  /// or busy has not settled it by then, and when in doubt the click is not Arbor's. macOS also switches off a tap that is silent
  /// for too long (docs/ARCHITECTURE.md, "Writing an event tap").
  static let patience = 0.05

  /// Doles out the time that is left. Asked before every call that can wait for another process.
  struct TimeLeft {
    let deadline = DispatchTime.now() + PointerProbe.patience

    /// How long the next call may take; nil when time is up.
    var nextWait: Float? {
      let now = DispatchTime.now()
      guard now < deadline else { return nil }
      let left = Double(deadline.uptimeNanoseconds - now.uptimeNanoseconds) / 1_000_000_000
      // Never 0, which to the Accessibility API means "the default", six seconds.
      return Float(max(left, 0.005))
    }

    /// Lets `element` take only that long over its next answer. False when time is up.
    func allows(_ element: AXUIElement) -> Bool {
      guard let nextWait else { return false }
      AXUIElementSetMessagingTimeout(element, nextWait)
      return true
    }
  }

  /// How many levels of the Accessibility tree to look at, from the element under the pointer up.
  static let depth = 4

  /// What an app says is under the pointer, as `Hit.isBackground` takes it.
  struct Finding: Sendable {
    var roles: [String] = []
    var windowHasButtons: Bool?
    /// Why there are no roles, for the log.
    var problem: String?
  }

  /// Whether a double-click at `point` would land on what `hit` says is there, and on nothing there
  /// that has a use for it.
  static func confirms(
    _ hit: DoubleClickZones.Hit, at point: CGPoint, displays: [CGRect], ownClickable: Set<WindowID>
  ) -> Bool {
    let started = DispatchTime.now()
    let time = TimeLeft()
    // Without the list, leave the click to whatever is there.
    guard let windows = windowsOnScreen() else { return false }
    let cover = PointerCover.at(
      point, windows: windows, ownPID: getpid(), ownClickable: ownClickable, displays: displays)
    var finding = Finding()
    var isConfirmed = false
    if hit.lands(on: cover) {
      var isTitleBar = false
      if case .titleBar = hit.target { isTitleBar = true }
      if let pid = cover.owner {
        finding = inspect(point, pid: pid, lookForButtons: isTitleBar, time: time) { hit.canStillBeBackground(rolesSoFar: $0) }
      }
      isConfirmed = hit.isBackground(roles: finding.roles, windowHasButtons: finding.windowHasButtons)
    }
    let milliseconds = (DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
    let buttons = finding.windowHasButtons.map { $0 ? "with" : "without" } ?? "maybe with"
    TapLog.debug(
      "double-click on \(hit.target): \(cover) under the pointer, roles \(finding.problem ?? "\(finding.roles)"), a window "
        + "\(buttons) buttons: \(isConfirmed ? hit.command?.text ?? "swallowed" : "left alone") (asked for \(milliseconds) ms)")
    return isConfirmed
  }

  /// Every window on screen, front to back, Desktop elements included.
  static func windowsOnScreen() -> [ListedWindow]? {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
      return nil
    }
    return list.compactMap { info in
      guard let number = (info[kCGWindowNumber as String] as? Int).flatMap({ UInt32(exactly: $0) }),
        let pid = (info[kCGWindowOwnerPID as String] as? Int).flatMap({ Int32(exactly: $0) }),
        let layer = info[kCGWindowLayer as String] as? Int,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
      else { return nil }
      return ListedWindow(
        id: WindowID(number), pid: pid, layer: layer, frame: frame,
        alpha: info[kCGWindowAlpha as String] as? Double ?? 1)
    }
  }

  /// What the app `pid` says is at `point`: the role of the Accessibility element there, then its
  /// parent's, and so on up to the window or `depth` levels; and, if asked, whether that window has any of the
  /// three title-bar buttons. All of the roles or none: half an answer could hide the button the text is in. Unless the roles
  /// so far settle it (`worthAskingOn` says no): then they are the answer, and the click waits no longer.
  ///
  /// It asks the app rather than the system-wide element, because a timeout set on that one applies to
  /// every Accessibility call Arbor makes. A timeout belongs to one element object, so each gets its own.
  static func inspect(
    _ point: CGPoint, pid: pid_t, lookForButtons: Bool, time: TimeLeft, worthAskingOn: ([String]) -> Bool = { _ in true }
  ) -> Finding {
    let app = AXUIElementCreateApplication(pid)
    guard time.allows(app) else { return Finding(problem: "none (no time left to ask)") }
    var found: AXUIElement?
    let error = AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &found)
    guard error == .success, let hit = found else { return Finding(problem: "none (error \(error.rawValue))") }

    var roles: [String] = []
    var window: AXUIElement?
    var element = hit
    while true {
      guard time.allows(element), let role = element.string(kAXRoleAttribute) else {
        return Finding(problem: "none (no role after \(roles))")
      }
      roles.append(role)
      guard worthAskingOn(roles) else { return Finding(roles: roles) }
      if role == kAXWindowRole { window = element }
      if role == kAXWindowRole || role == kAXApplicationRole || roles.count == depth { break }
      guard time.allows(element), let parent = element.element(kAXParentAttribute) else {
        return Finding(problem: "none (no parent after \(roles))")
      }
      element = parent
    }
    guard lookForButtons else { return Finding(roles: roles) }

    if window == nil, time.allows(hit) { window = hit.element(kAXWindowAttribute) }
    guard let window else { return Finding(roles: roles) }
    for button in [kAXCloseButtonAttribute, kAXZoomButtonAttribute, kAXMinimizeButtonAttribute] {
      guard time.allows(window) else { return Finding(roles: roles) }
      var value: CFTypeRef?
      switch AXUIElementCopyAttributeValue(window, button as CFString, &value) {
      case .success: return Finding(roles: roles, windowHasButtons: true)
      case .cannotComplete: return Finding(roles: roles)
      default: continue
      }
    }
    return Finding(roles: roles, windowHasButtons: false)
  }
}
