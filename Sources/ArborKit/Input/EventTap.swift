import ApplicationServices
import ArborCore
import CoreGraphics
import Foundation
import os

/// The thread every event tap runs on, with its own run loop.
///
/// macOS holds back every tapped event, system-wide, until the tap's callback
/// returns. Arbor's main thread waits on apps (one Accessibility call can take
/// a second), so a tap on the main run loop would make every click, drag and
/// pinch on the system wait with it. Taps live here instead; their callbacks
/// only update their state and decide, and anything slow (running a command,
/// drawing) hops to the main actor afterwards.
final class EventTapThread: @unchecked Sendable {
  static let shared = EventTapThread()

  static let name = "dev.arbor.event-taps"

  private let thread: Thread
  private let runLoop: CFRunLoop
  // Touched only on the tap thread.
  /// One for all the taps: see `TapHealth`.
  fileprivate var health = TapHealth()
  /// One for all the taps: see `TapPermission`.
  fileprivate var permission = TapPermission()
  fileprivate var taps: [EventTap] = []
  /// Beats as `TapPermission` needs it.
  private var clock: (timer: CFRunLoopTimer, interval: Double)?
  /// How many questions macOS has answered, and how long it took over them, in seconds: what the clock costs.
  private var answers = (count: 0, total: 0.0, slowest: 0.0)
  /// Where macOS is asked whether Arbor still may. Whoever waits for that answer answers for no event meanwhile.
  private let asker = DispatchQueue(label: "dev.arbor.event-taps.asker", qos: .userInteractive)

  private init() {
    let ready = DispatchSemaphore(value: 0)
    let box = RunLoopBox()
    let thread = Thread {
      let loop = CFRunLoopGetCurrent()!
      // A run loop with nothing to watch returns at once; a timer that never fires keeps it running.
      let keepAlive = CFRunLoopTimerCreateWithHandler(
        kCFAllocatorDefault, Date.distantFuture.timeIntervalSinceReferenceDate, 0, 0, 0) { _ in }
      CFRunLoopAddTimer(loop, keepAlive, .commonModes)
      box.runLoop = loop
      ready.signal()
      CFRunLoopRun()
    }
    thread.name = Self.name
    // Pointer events wait on this thread, so it must not queue behind background work.
    thread.qualityOfService = .userInteractive
    thread.start()
    ready.wait()
    self.thread = thread
    runLoop = box.runLoop!
  }

  /// Whether the caller is on the tap thread, as tap callbacks are.
  var isCurrent: Bool { Thread.current === thread }

  /// Runs `block` on the tap thread and waits for its result; on the tap
  /// thread already, runs it in place.
  func sync<T>(_ block: () -> T) -> T {
    if isCurrent { return block() }
    let done = DispatchSemaphore(value: 0)
    let result = ResultBox<T>()
    withoutActuallyEscaping(block) { block in
      // The run loop holds the block it is given for a moment after `signal`, when the caller may
      // already be leaving `withoutActuallyEscaping`, which traps if anything still refers to the closure.
      // So the block refers to a box, and the box has let go of the closure before the signal.
      let work = WorkBox(block)
      CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue) {
        result.value = work.run()
        done.signal()
      }
      CFRunLoopWakeUp(runLoop)
      done.wait()
    }
    return result.value!
  }

  /// Runs `block` on the tap thread once it is free, after the callback in
  /// progress if there is one.
  func async(_ block: @escaping @Sendable () -> Void) {
    CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
    CFRunLoopWakeUp(runLoop)
  }

  /// Called on the tap thread after it removed the taps because the permission went, and when it is back. It says which:
  /// whoever hears of it later, on a thread that was busy, hears of every turn in order. And whether macOS said so, or
  /// said nothing in time. Not a property of the thread: to say who listens must not start it. Until a tap is
  /// installed there is no thread, no clock and no question.
  static let onPermissionChange = OSAllocatedUnfairLock<(@Sendable (_ isGone: Bool, _ macOSSaidSo: Bool) -> Void)?>(
    initialState: nil)

  fileprivate static func now() -> Double { ProcessInfo.processInfo.systemUptime }

  /// Starts the clock, stops it or changes its beat. On the tap thread, after whatever changes which taps there are.
  fileprivate func keepTheClock() {
    let interval = permission.clock(tapsAreIn: !taps.isEmpty)
    guard interval != clock?.interval else { return }
    if let clock { CFRunLoopTimerInvalidate(clock.timer) }
    clock = interval.map { interval in
      // No tolerance: for how long all input can be lost is counted in these beats.
      let timer = CFRunLoopTimerCreateWithHandler(
        kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + interval, interval, 0, 0
      ) { [unowned self] _ in
        obey(permission.beat(at: Self.now(), tapsAreIn: !taps.isEmpty))
      }
      CFRunLoopAddTimer(runLoop, timer, .commonModes)
      return (timer!, interval)
    }
  }

  /// Does as `TapPermission` says. On the tap thread, and not from a tap's callback unless the order is to ask: a tap must
  /// not be invalidated from inside its own.
  fileprivate func obey(_ order: TapPermission.Order) {
    // A copy: what the owners do on a reset may install and remove taps.
    let all = taps
    switch order {
    case .nothing:
      break
    case .ask:
      asker.async { [self] in
        let began = Self.now()
        let answer = EventTap.answer()
        let took = Self.now() - began
        async { [self] in
          answers = (answers.count + 1, answers.total + took, max(answers.slowest, took))
          // How near answers come to being too late, on a day on which none is.
          if took > TapPermission.beat / 4 { TapLog.info("macOS took \(Int(took * 1000)) ms to say whether Arbor still may") }
          obey(permission.heard(answer, at: Self.now(), tapsAreIn: !taps.isEmpty))
        }
      }
    case .lookAfter:
      for tap in all { tap.reviveIfSwitchedOff() }
    case .removeAll(let answer):
      for tap in all { tap.remove() }
      // No event waits for this thread now, so it may write to the log itself. The main thread, which writes `TapLog`'s
      // lines, may be busy, and the time on this line is what a probe goes by.
      Log.info("Accessibility permission is gone (\(answer.words)): removed the pinch and rectangle event taps")
      Log.info(
        "macOS was asked \(answers.count) times, and took \(Int(answers.total / Double(max(answers.count, 1)) * 1e6)) µs on "
          + "average and \(Int(answers.slowest * 1e6)) µs at worst")
      // After the taps have gone: an owner gives back a press it holds, and posting an event can take long just now.
      for tap in all { tap.onReset?() }
      Self.onPermissionChange.withLock { $0 }?(true, answer != .nothing)
    case .comeBack(let after, let wentFor):
      // One line that says how long and why, so that a day's log can be asked how many alarms were false.
      Log.info(
        "Accessibility permission is back after \(Int((after * 1000).rounded())) ms (\(wentFor.words)): "
          + "installing the pinch and rectangle event taps")
      Self.onPermissionChange.withLock { $0 }?(false, true)
    }
    keepTheClock()
  }

  private final class RunLoopBox: @unchecked Sendable {
    var runLoop: CFRunLoop?
  }

  private final class ResultBox<T>: @unchecked Sendable {
    var value: T?
  }

  /// Holds a closure until it has run once.
  private final class WorkBox<T>: @unchecked Sendable {
    private var work: (() -> T)?

    init(_ work: @escaping () -> T) {
      self.work = work
    }

    /// Runs the closure. When this returns, nothing here refers to it any more.
    func run() -> T? {
      let work = self.work
      self.work = nil
      return work?()
    }
  }
}

/// `Log` for the tap thread. `Log` writes to a file under a lock, and no event may wait for a disk,
/// so the line is written from the main queue a moment later.
enum TapLog {
  static func info(_ message: String) {
    DispatchQueue.main.async { Log.info(message) }
  }

  static func error(_ message: String) {
    DispatchQueue.main.async { Log.error(message) }
  }

  static func debug(_ message: @autoclosure () -> String) {
    guard Log.debugEnabled else { return }
    let text = message()
    DispatchQueue.main.async { Log.debug(text) }
  }
}

/// A session-level event tap on the tap thread (`EventTapThread`): it sees
/// the events in `mask` before any app does, and lets each one through
/// unchanged unless the handler returns true, which swallows it.
/// `GestureTap` and `RectangleFramer` are built on it.
///
/// The handler runs on the tap thread, never on the main actor, so it may
/// only use state made for that (a lock-protected box) and thread-safe
/// APIs; running a command or drawing goes to `DispatchQueue.main`. macOS
/// switches off a tap whose callback is too slow; when that happens the tap
/// is switched back on at once, unless it keeps happening, to this tap or
/// another: then all of them rest (`TapHealth`). `onReset` tells the owner
/// that events were missed.
/// docs/ARCHITECTURE.md, "Writing an event tap", has the rules for handlers.
///
/// An active tap needs the Accessibility permission Arbor already has. While a process has taps and not the permission,
/// macOS 26 drops all input at every event they ask for, so the thread keeps asking, and all taps go the moment the answer
/// is no (`TapPermission`).
final class EventTap: @unchecked Sendable {
  /// Runs on the tap thread. Returns true to swallow the event. The proxy is
  /// for `CGEvent.tapPostEvent`.
  typealias Handler = @Sendable (_ event: CGEvent, _ proxy: CGEventTapProxy) -> Bool

  /// Arbor sets this as the `.eventSourceUserData` of every event it posts itself. Such an event
  /// passes Arbor's own taps again, and each of them must let it through without acting on it.
  static let replayMark: Int64 = 0x4152_424F  // 'ARBO'

  let name: String
  /// Called on the tap thread after macOS switched the tap off, when the taps go to rest, when they are
  /// switched back on and when the thread has removed them: events were missed.
  var onReset: (@Sendable () -> Void)?

  private let mask: CGEventMask
  private let handler: Handler
  // Touched only on the tap thread.
  private var port: CFMachPort?
  private var source: CFRunLoopSource?
  private var isPaused = false
  /// Keeps this object alive while macOS holds a pointer to it.
  private var retainedSelf: Unmanaged<EventTap>?
  private let installed = OSAllocatedUnfairLock(initialState: false)

  init(name: String, mask: CGEventMask, handler: @escaping Handler) {
    self.name = name
    self.mask = mask
    self.handler = handler
  }

  var isInstalled: Bool { installed.withLock { $0 } }

  /// Installs the tap, paused if asked. Returns false if macOS refused (no Accessibility permission).
  @discardableResult
  func start(paused: Bool = false) -> Bool {
    EventTapThread.shared.sync { install(paused: paused) }
  }

  func stop() {
    EventTapThread.shared.sync { remove() }
  }

  /// Stops events from coming, at no cost to anyone, until `resume()`. The tap keeps its place among
  /// the taps of every app, which installing it afresh would not: see `RectangleFramer`.
  /// A handler may pause or resume any tap, its own included; it takes effect before the next event.
  func pause() {
    _ = EventTapThread.shared.sync { setPaused(true) }
  }

  /// Returns false if the tap is not installed.
  @discardableResult
  func resume() -> Bool {
    EventTapThread.shared.sync { setPaused(false) }
  }

  private func setPaused(_ paused: Bool) -> Bool {
    guard let port else { return false }
    // Pausing a paused tap is free, so a handler can do it on every event, just in case.
    if paused, isPaused { return true }
    isPaused = paused
    switchOn(port, !paused)
    return true
  }

  /// No tap goes on while the taps rest, whoever asks. The end of the rest switches on all that are not paused.
  private func switchOn(_ port: CFMachPort, _ enable: Bool) {
    CGEvent.tapEnable(tap: port, enable: enable && !EventTapThread.shared.health.isResting)
  }

  /// Removes the tap once the callback in progress has returned. A tap must
  /// not be invalidated from inside its own callback.
  func stopAfterCurrentEvent() {
    EventTapThread.shared.async { [self] in remove() }
  }

  /// Switches the tap back on if it is off: the taps' rest is over (`TapHealth`), or macOS switched it off
  /// and has not told the callback yet. It tells it in place of the next event the tap would have
  /// had, so without this the first gesture after a stall is lost. On the tap thread, after every yes to its clock's question.
  func reviveIfSwitchedOff() {
    // A paused tap too may find that the rest is over: there may be no other, and it could never be resumed.
    let isResting = EventTapThread.shared.health.isResting
    guard let port, isResting || (!isPaused && !CGEvent.tapIsEnabled(tap: port)) else { return }
    act(on: EventTapThread.shared.health.foundOff(at: Self.now()), port, found: "the \(name) event tap was off")
  }

  /// Does as `TapHealth` says about this tap, which is off though it should be on. On the tap thread.
  private func act(on verdict: TapHealth.Verdict, _ port: CFMachPort, found: String) {
    // A copy: what the owners do on a reset may install and remove taps.
    let all = EventTapThread.shared.taps
    switch verdict {
    case .switchOn:
      CGEvent.tapEnable(tap: port, enable: true)
      TapLog.info("\(found); switched it back on")
      onReset?()
    case .stayOff:
      break
    case .restAll:
      for tap in all {
        if let port = tap.port { CGEvent.tapEnable(tap: port, enable: false) }
      }
      TapLog.error(
        "\(found), and that keeps happening; leaving all \(all.count) event taps off for "
          + "\(Int(TapHealth.rest)) seconds")
      for tap in all { tap.onReset?() }
    case .wakeAll:
      for tap in all where !tap.isPaused {
        if let port = tap.port { CGEvent.tapEnable(tap: port, enable: true) }
      }
      TapLog.info("the event taps have rested; switched them back on")
      for tap in all { tap.onReset?() }
    }
  }

  private static func now() -> Double { EventTapThread.now() }

  private func install(paused: Bool) -> Bool {
    guard port == nil else { return true }
    // The main thread may not have heard yet. The owners are told when the permission is back.
    guard EventTapThread.shared.permission.mayInstall else { return false }
    let reference = Unmanaged.passRetained(self)
    guard
      let port = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
        eventsOfInterest: mask, callback: eventTapCallback, userInfo: reference.toOpaque())
    else {
      reference.release()
      TapLog.error("could not install the \(name) event tap; is Accessibility permission granted?")
      return false
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    // Common modes, so events are not held up while a menu is open.
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
    switchOn(port, !paused)
    isPaused = paused
    self.port = port
    self.source = source
    retainedSelf = reference
    EventTapThread.shared.taps.append(self)
    installed.withLock { $0 = true }
    EventTapThread.shared.keepTheClock()
    TapLog.debug("\(name) event tap installed")
    return true
  }

  fileprivate func remove() {
    guard let port else { return }
    CGEvent.tapEnable(tap: port, enable: false)
    if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
    CFMachPortInvalidate(port)
    self.port = nil
    source = nil
    EventTapThread.shared.taps.removeAll { $0 === self }
    installed.withLock { $0 = false }
    EventTapThread.shared.keepTheClock()
    // Last, because it may drop the final reference to this object.
    let reference = retainedSelf
    retainedSelf = nil
    reference?.release()
  }

  /// Whether macOS lets this process install an active tap right now.
  /// `AXIsProcessTrusted()` can keep saying yes after Arbor is removed from
  /// the Accessibility list, so this also creates a tap and throws it away.
  ///
  /// A tap is born switched on, and nothing serves this one, so an event that arrived before it is
  /// thrown away would wait for an answer that never comes. It therefore watches only for a
  /// drawing tablet's pen coming near, not for anything a mouse or a trackpad sends.
  static func isPermitted() -> Bool { answer() == .yes }

  /// The same, and which of the two said no. From any thread but the one that events wait for.
  static func answer() -> TapPermission.Answer {
    guard AXIsProcessTrusted() else { return .flagSaysNo }
    let mask = CGEventMask(1) << CGEventType.tabletProximity.rawValue
    guard
      let probe = CGEvent.tapCreate(
        tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap,
        eventsOfInterest: mask, callback: eventTapCallback, userInfo: nil)
    else { return .tapRefused }
    CGEvent.tapEnable(tap: probe, enable: false)
    CFMachPortInvalidate(probe)
    return .yes
  }

  /// Returns true to swallow the event.
  fileprivate func handle(_ type: CGEventType, _ event: CGEvent, proxy: CGEventTapProxy) -> Bool {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      let reason = type == .tapDisabledByTimeout ? "it was too slow" : "of user input"
      // Every such word is written down, also those that are not acted on below. One that finds its tap switched on is what a
      // bare tool heard, seconds late, after it had lost the right to tap. So macOS is asked at once; the word itself is not believed.
      TapLog.info("macOS says that it switched the \(name) event tap off because \(reason)")
      EventTapThread.shared.obey(EventTapThread.shared.permission.toldOff(at: Self.now()))
      // In case macOS reports Arbor's own pause this way: a paused tap stays off. And macOS says it late, in place of the
      // next event: a word that finds the tap on is about a switch-off the regular check has counted and mended
      // already. Counted again, one freeze would be two, and stale words after a rest could begin another.
      guard !isPaused, let port, !CGEvent.tapIsEnabled(tap: port) else { return false }
      act(
        on: EventTapThread.shared.health.switchedOff(at: Self.now()), port,
        found: "macOS switched the \(name) event tap off because \(reason)")
      return false
    default:
      return handler(event, proxy)
    }
  }
}

/// The tap's run loop source is on the tap thread's run loop, so this runs there.
private func eventTapCallback(
  _ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
  return tap.handle(type, event, proxy: proxy) ? nil : Unmanaged.passUnretained(event)
}
