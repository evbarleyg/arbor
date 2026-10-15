// The model of a Mac (FakeMac.swift): the mouse, and what it does to windows. Never shipped.
import Foundation

extension FakeMac {
  public struct Mouse {
    /// Global coordinates, top-left origin.
    public internal(set) var location = CGPoint(x: 10, y: 10)
    public internal(set) var isDown = false
    /// What `NSEvent.pressedMouseButtons` says, which with bad manners (ii) lags.
    public internal(set) var isDownByAppKit = false
    /// `NSEvent.ModifierFlags`' raw value.
    public internal(set) var flags: UInt = 0
    /// What the button holds.
    var grab: Grab?
    /// When an event of each kind last happened, by `CGEventType`'s raw value, and how many there were.
    var lastEvent: [UInt32: TimeInterval] = [:]
    var eventCounts: [UInt32: UInt32] = [:]
    /// The keys that are down, by virtual key code.
    public var keysDown: Set<UInt16> = []
  }

  struct Grab {
    enum Kind { case titleBar, edge(left: Bool, right: Bool, top: Bool, bottom: Bool), content, arborsPanel, nothing }
    var kind: Kind
    var window: Window?
    var pressedAt: CGPoint
    var frameAtPress: CGRect
    var time: TimeInterval = 0
  }

  /// `NSEvent.EventType`'s raw values, which for these are `CGEventType`'s too.
  public enum MouseEvent: UInt, Sendable { case leftMouseDown = 1, leftMouseUp = 2, mouseMoved = 5, leftMouseDragged = 6, flagsChanged = 12 }

  final class Monitor {
    let number: Int
    let isGlobal: Bool
    let mask: UInt64
    let tell: (MouseEvent, UInt) -> Void
    init(number: Int, isGlobal: Bool, mask: UInt64, tell: @escaping (MouseEvent, UInt) -> Void) {
      self.number = number
      self.isGlobal = isGlobal
      self.mask = mask
      self.tell = tell
    }
  }

  // MARK: Monitors

  public func addMonitor(global: Bool, mask: UInt64, tell: @escaping (MouseEvent, UInt) -> Void) -> Int {
    monitorsMade += 1
    monitors.append(Monitor(number: monitorsMade, isGlobal: global, mask: mask, tell: tell))
    return monitorsMade
  }

  public func removeMonitor(_ number: Int) { monitors.removeAll { $0.number == number } }

  /// A global monitor hears only what goes to other apps, a local one only what goes to Arbor's own windows.
  private func tellMonitors(_ event: MouseEvent, toArbor: Bool, after delay: TimeInterval = 0, mayBeDropped: Bool = false) {
    happened(UInt32(event.rawValue))
    if mayBeDropped, manners.chance(manners.drops) { return note("(swallowed: \(event))") }
    let flags = mouse.flags
    let place = "\(Int(mouse.location.x)),\(Int(mouse.location.y))"
    let times = event != .leftMouseDragged && manners.chance(manners.repeats) ? 2 : 1
    for _ in 0..<times {
      send(after: timing.mouseEvent + delay, from: .mouse, "→ \(event) \(place)\(toArbor ? " (to a panel of Arbor's)" : "")") { [self] in
        for monitor in monitors where monitor.isGlobal != toArbor && monitor.mask & (1 << UInt64(event.rawValue)) != 0 { monitor.tell(event, flags) }
      }
    }
  }

  private func happened(_ type: UInt32) {
    mouse.lastEvent[type] = now
    mouse.eventCounts[type, default: 0] += 1
  }

  public func secondsSinceLastEvent(_ type: UInt32) -> TimeInterval { now - (mouse.lastEvent[type] ?? Self.dawn - 3600) }
  public func eventCount(_ type: UInt32) -> UInt32 { mouse.eventCounts[type] ?? 0 }

  private func setButton(_ down: Bool) {
    mouse.isDown = down
    let lag = manners.lag(upTo: manners.staleness)
    // Behind what is still on its way, or the button would end up as it was before.
    if lag > 0 || pending.contains(where: { $0.source == .mouseCache }) {
      send(after: lag, from: .mouseCache, "") { [self] in mouse.isDownByAppKit = down }
    } else {
      mouse.isDownByAppKit = down
    }
  }

  // MARK: What a hand does

  /// A modifier key goes down or comes up.
  public func setModifierFlags(_ flags: UInt) {
    guard flags != mouse.flags else { return }
    mouse.flags = flags
    tellMonitors(.flagsChanged, toArbor: false)
  }

  /// The button goes down. On a window that has not got the keyboard this gives it the keyboard, and brings its app forward, before anything else:
  /// the focus report comes about when the press does (`drag-onto-window`: 0.4 ms before it).
  /// `onArborsPanel`: on a tile, a gap handle or the menu of Arbor's, which lie over the windows and which only a local monitor hears of.
  public func press(at point: CGPoint, onArborsPanel: Bool = false) {
    mouse.location = point
    note("the button goes down at \(Int(point.x)),\(Int(point.y))")
    setButton(true)
    if onArborsPanel {
      mouse.grab = Grab(kind: .arborsPanel, window: nil, pressedAt: point, frameAtPress: .zero)
      return tellMonitors(.leftMouseDown, toArbor: true)
    }
    tellMonitors(.leftMouseDown, toArbor: false, after: mouseDownIsLateBy)
    // The resize area reaches a few points outside the frame.
    guard let window = windowShowing(at: point, reach: 4) else {
      mouse.grab = Grab(kind: .nothing, window: nil, pressedAt: point, frameAtPress: .zero)
      return
    }
    raise(window)
    if !window.app.isHung { makeKey(window) }
    activate(window.app, raisingAll: false)
    let frame = window.bounds
    let inner = frame.insetBy(dx: 4, dy: 4)
    let kind: Grab.Kind
    if !inner.contains(point), window.isResizable, !window.isFullScreen {
      kind = .edge(left: point.x < inner.minX, right: point.x > inner.maxX, top: point.y < inner.minY, bottom: point.y > inner.maxY)
    } else if point.y < frame.minY + window.titleBarHeight, !window.isFullScreen {
      kind = .titleBar
    } else {
      kind = .content
    }
    mouse.grab = Grab(kind: kind, window: window, pressedAt: point, frameAtPress: frame, time: now)
    if case .titleBar = kind, serverFollowsPointerAfter > 0 {
      let time = now
      send(after: serverFollowsPointerAfter, from: .system, "") { [self] in
        if let grab = mouse.grab, grab.time == time, grab.window === window { serverFollowsPointer(grab, window) }
      }
    }
  }

  /// The window server puts a window that is held by its title bar where the pointer has taken it.
  private func serverFollowsPointer(_ grab: Grab, _ window: Window) {
    guard now >= grab.time + serverFollowsPointerAfter else { return }
    let point = mouse.location
    var origin = CGPoint(x: grab.frameAtPress.minX + point.x - grab.pressedAt.x, y: grab.frameAtPress.minY + point.y - grab.pressedAt.y)
    origin.y = max(origin.y, screen(of: CGRect(origin: point, size: .zero)).visibleFrame.minY)
    guard window.bounds.origin != origin else { return }
    window.bounds.origin = origin
    guard !window.app.isSilentDuringDrags else { return }
    let bounds = window.bounds
    appDoes(window.app, after: timing.dragReachesApp, "") { [self] in
      guard window.isOpen, window.frame != bounds else { return }
      window.frame = bounds
      reportMoved(window)
    }
  }

  /// The pointer moves.
  ///
  /// By its title bar the window server moves a window itself, at once. The app learns of it about a tenth of a second later and posts eight to ten "moved"
  /// a second; some apps post none until the drag is over. An app that hangs learns nothing, and its window moves all the same.
  /// By an edge it is the app that follows the pointer, so a hung app's window does not change.
  public func moveMouse(to point: CGPoint) {
    mouse.location = point
    guard mouse.isDown, let grab = mouse.grab else { return happened(UInt32(MouseEvent.mouseMoved.rawValue)) }
    if case .arborsPanel = grab.kind { return happened(UInt32(MouseEvent.leftMouseDragged.rawValue)) }
    tellMonitors(.leftMouseDragged, toArbor: false)
    guard let window = grab.window, window.isOpen else { return }
    let (dx, dy) = (point.x - grab.pressedAt.x, point.y - grab.pressedAt.y)
    switch grab.kind {
    case .titleBar: serverFollowsPointer(grab, window)
    case .edge(let left, let right, let top, let bottom):
      guard !window.app.isHung else { return }
      var frame = grab.frameAtPress
      if right { frame.size.width += dx }
      if bottom { frame.size.height += dy }
      if left { frame.size.width -= dx }
      if top { frame.size.height -= dy }
      frame.size.width = min(max(frame.width, window.minimumSize.width), window.maximumSize.width)
      frame.size.height = min(max(frame.height, window.minimumSize.height), window.maximumSize.height)
      if left { frame.origin.x = grab.frameAtPress.maxX - frame.width }
      if top { frame.origin.y = grab.frameAtPress.maxY - frame.height }
      take(frame, window)
    case .content, .arborsPanel, .nothing:
      break
    }
  }

  public enum Release: Sendable {
    /// The monitor hears of it.
    case seen
    /// And hears of it again 15 to 33 ms later (`click-title-bar`, `flick-to-edge`): the usual thing on the hosted Macs.
    case seenTwice
    /// Another tool's event tap swallowed it, or it went to a window of Arbor's.
    case lost
  }

  /// The button comes up. The app may not have heard yet where its window was left: after a quick flick the last frame it reported was 170 points
  /// behind (`flick-to-edge`).
  public func release(_ release: Release = .seen) {
    guard mouse.isDown else { return }
    note("the button comes up at \(Int(mouse.location.x)),\(Int(mouse.location.y))\(release == .lost ? ", and no monitor hears of it" : "")")
    setButton(false)
    let grab = mouse.grab
    // However late it began, the window server leaves the window where the pointer let go of it.
    if case .titleBar? = grab?.kind, let grab, let window = grab.window, window.isOpen {
      var caughtUp = grab
      caughtUp.time = -.infinity
      serverFollowsPointer(caughtUp, window)
    }
    mouse.grab = nil
    var toArbor = false
    if case .arborsPanel? = grab?.kind { toArbor = true }
    if release == .lost {
      happened(UInt32(MouseEvent.leftMouseUp.rawValue))
    } else {
      tellMonitors(.leftMouseUp, toArbor: toArbor, mayBeDropped: true)
      if release == .seenTwice { tellMonitors(.leftMouseUp, toArbor: toArbor, after: timing.secondMouseUp) }
    }
    if case .titleBar? = grab?.kind, let window = grab?.window {
      appDoes(window.app, after: timing.dragReachesApp, "") { [self] in
        guard window.isOpen, window.frame != window.bounds, mouse.grab?.window !== window else { return }
        window.frame = window.bounds
        reportMoved(window)
      }
    }
  }

  /// Eight to ten "moved" a second, however often the window moves; but the last place is always reported in the end (`flick-to-edge`: one more 30 ms after
  /// the release).
  private func reportMoved(_ window: Window) {
    // The one that is owed will tell of this move too.
    guard !window.owesMovedReport else { return }
    let wait = window.lastMovedReport + timing.betweenMovedReports - now
    if wait <= 0 {
      window.lastMovedReport = now
      report("AXMoved", about: window, mayBeDropped: mouse.grab?.window === window)
    } else if !window.owesMovedReport {
      window.owesMovedReport = true
      appDoes(window.app, after: wait, "") { [self] in
        window.owesMovedReport = false
        guard window.isOpen else { return }
        window.lastMovedReport = now
        report("AXMoved", about: window, mayBeDropped: mouse.grab?.window === window)
      }
    }
  }

  // MARK: Whole gestures

  /// A click in the middle of a window, where it takes the keyboard and nothing else happens. If something covers the middle, that gets the click.
  public func click(_ window: Window) {
    press(at: CGPoint(x: window.bounds.midX, y: window.bounds.midY))
    pass(0.08)
    release()
  }

  /// Presses at `start`, rests for `rest`, moves to `end` in `steps` steps `interval` apart, and holds. The traces' pointer rested 0.18 to 0.23 s and moved
  /// every 0.05 to 0.1 s.
  public func drag(from start: CGPoint, to end: CGPoint, steps: Int = 10, interval: TimeInterval = 0.08, rest: TimeInterval = 0.15) {
    press(at: start)
    pass(rest)
    for step in 1...max(steps, 1) {
      let part = CGFloat(step) / CGFloat(max(steps, 1))
      moveMouse(to: CGPoint(x: start.x + (end.x - start.x) * part, y: start.y + (end.y - start.y) * part))
      pass(interval)
    }
  }
}
