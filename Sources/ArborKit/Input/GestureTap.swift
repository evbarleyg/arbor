import AppKit
import ArborCore
import os

/// Trackpad pinch steps the camera (docs/features/F03-trackpad-gestures.md), or, with
/// `continuousZoom`, pinch and ⌃⌥-scroll are streamed to a view that follows the fingers
/// (docs/features/F16-continuous-zoom-and-pan.md).
///
/// A pinch is Arbor's when ⌥ is held as it begins, or, with `pinchOnDesktop`, when no app window is
/// under the pointer (the Desktop, a gap between windows, one of Arbor's
/// tiles). Arbor swallows its pinches, and the rotations that begin during
/// them, so the app under the pointer does not zoom or turn as well; every
/// other pinch goes to the app untouched. A scroll is Arbor's when ⌃⌥ is held as it begins, or a
/// pinch of Arbor's is in progress; up and down it zooms, also for Macs without a trackpad
/// (docs/features/F55-zoom-with-a-mouse.md). The decisions are made by `GestureRouter` and
/// `PointerSurface`; this class only reads events.
///
/// The taps' callbacks run on the tap thread (`EventTapThread`), so the
/// router lives in a lock-protected box that the callbacks and `update()`
/// share. Commands and updates hop to the main actor after the callback has
/// returned, which is as long as macOS holds the event back.
@MainActor
final class GestureTap {
  /// What the tap callbacks need: the router, and the two things that must happen on the main actor.
  private final class Context: Sendable {
    let router = OSAllocatedUnfairLock(initialState: GestureRouter())
    /// The taps, for the handlers, which switch them on and off.
    let pinchTap = OSAllocatedUnfairLock<EventTap?>(initialState: nil)
    let scrollTap = OSAllocatedUnfairLock<EventTap?>(initialState: nil)
    let onCommand: @MainActor (Command) -> Void
    let onGesture: @MainActor (GestureUpdate) -> Void

    init(
      onCommand: @escaping @MainActor (Command) -> Void, onGesture: @escaping @MainActor (GestureUpdate) -> Void
    ) {
      self.onCommand = onCommand
      self.onGesture = onGesture
    }
  }

  private let context: Context
  private let settings: @MainActor () -> Settings
  /// Paused except while a pinch could be Arbor's (`GestureRouter.pinchTapIsWanted`): switched on, every touch of the trackpad
  /// passes through it.
  private var tap: EventTap?
  /// Installed only with `continuousZoom` or `scrollZoom`, and paused except while a scroll could be Arbor's
  /// (`GestureRouter.scrollTapIsWanted`): switched on, every scroll on the Mac passes through it.
  private var scrollTap: EventTap?

  init(
    settings: @escaping @MainActor () -> Settings, onCommand: @escaping @MainActor (Command) -> Void,
    onGesture: @escaping @MainActor (GestureUpdate) -> Void
  ) {
    self.settings = settings
    context = Context(onCommand: onCommand, onGesture: onGesture)
  }

  /// Takes the threshold and `continuousZoom` from the settings and installs or removes the taps
  /// to match them and `gesturesEnabled`. Runs at launch and whenever settings are applied.
  func update() {
    let settings = settings()
    let threshold = settings.pinchThreshold
    let isContinuous = settings.continuousZoom
    let (scrollZoom, scrollThreshold, onDesktop, pinchOnDesktop) =
      (settings.scrollZoom, settings.scrollZoomThreshold, settings.scrollOnDesktopZooms, settings.pinchOnDesktop)
    let needsVisit = context.router.withLock { router -> Bool in
      router.threshold = threshold
      router.zoomsWithScroll = scrollZoom
      router.scrollThreshold = scrollThreshold
      router.zoomsOnDesktop = onDesktop
      router.pinchesOnDesktop = pinchOnDesktop
      return router.setContinuous(isContinuous)
    }
    if needsVisit { Self.visit(context) }
    guard settings.gesturesEnabled else {
      stop()
      return
    }
    let context = self.context
    if tap == nil {
      // Event taps see every trackpad gesture as CG event type 29 (the same
      // number as NSEvent's `.gesture`); NSEvent then tells a magnify apart from
      // touches, rotations and swipes. NSEvent's `.magnify` number, 30, is a
      // different event type to CG (Dock control), so it is deliberately not in the mask.
      let mask = NSEvent.EventTypeMask.gesture.rawValue
      let tap = EventTap(name: "pinch", mask: mask) { event, _ in Self.handle(event, context: context) }
      tap.onReset = { Self.reset(context) }
      let keys = Keys(NSEvent.modifierFlags)
      if tap.start(paused: !context.router.withLock({ $0.pinchTapIsWanted(keys: keys) })) {
        self.tap = tap
        context.pinchTap.withLock { $0 = tap }
        Log.info("pinch event tap installed")
      }
    }
    let wantsScrolls = GestureRouter.listensToScrolls(settings)
    if wantsScrolls, scrollTap == nil {
      let tap = EventTap(name: "scroll", mask: 1 << CGEventType.scrollWheel.rawValue) { event, _ in
        Self.handleScroll(event, context: context)
      }
      tap.onReset = { Self.reset(context) }
      let keys = Keys(NSEvent.modifierFlags)
      let isWanted = context.router.withLock { $0.scrollTapIsWanted(keys: keys) }
      if tap.start(paused: !isWanted) {
        scrollTap = tap
        context.scrollTap.withLock { $0 = tap }
        Log.info("scroll event tap installed")
      }
    } else if !wantsScrolls {
      removeScrollTap()
    }
    // The settings may have changed what is wanted.
    keysChanged(NSEvent.modifierFlags)
  }

  /// A modifier key went down or up (`PointerInput.watchKeys`): switches each tap on or off as the router wants it. A few events a
  /// second at most, and switching a tap to what it already is costs nothing.
  func keysChanged(_ flags: NSEvent.ModifierFlags) {
    Self.switchTaps(context, Keys(flags))
  }

  func stop() {
    context.pinchTap.withLock { $0 = nil }
    tap?.stop()
    tap = nil
    removeScrollTap()
    Self.reset(context)
  }

  private func removeScrollTap() {
    context.scrollTap.withLock { $0 = nil }
    scrollTap?.stop()
    scrollTap = nil
  }

  var isInstalled: Bool { tap != nil || scrollTap != nil }

  /// The names of the taps installed now, for `doctor`.
  var installedTaps: [String] { (tap != nil ? ["pinch"] : []) + (scrollTap != nil ? ["scroll"] : []) }

  // MARK: On the tap thread

  private typealias Keys = GestureRouter.Keys

  /// Switches each tap on or off as the router wants it. From any thread; a handler may do it to its own tap.
  private nonisolated static func switchTaps(_ context: Context, _ keys: Keys) {
    let (pinch, scroll) = context.router.withLock { ($0.pinchTapIsWanted(keys: keys), $0.scrollTapIsWanted(keys: keys)) }
    for (tap, isWanted) in [(context.pinchTap.withLock { $0 }, pinch), (context.scrollTap.withLock { $0 }, scroll)] {
      if isWanted { tap?.resume() } else { tap?.pause() }
    }
  }

  /// The keys as the event has them and as they are held now: gesture events may not carry modifier flags.
  private nonisolated static func keys(_ flags: CGEventFlags) -> Keys {
    Keys(flags.union(CGEventSource.flagsState(.combinedSessionState)))
  }

  /// Returns true to swallow the event.
  private nonisolated static func handle(_ event: CGEvent, context: Context) -> Bool {
    // While the tap is on every touch of the trackpad waits for this callback.
    let held = keys(event.flags)
    guard context.router.withLock({ $0.pinchTapIsWanted(keys: held) }) else {
      // On for nothing: the monitors missed a key going up.
      switchTaps(context, held)
      return false
    }
    guard let nsEvent = NSEvent(cgEvent: event) else { return false }
    // Check the type first: reading `magnification` of any other event raises an exception.
    switch nsEvent.type {
    case .magnify:
      break
    case .rotate:
      guard let phase = phase(of: nsEvent) else { return false }
      return context.router.withLock { $0.rotation(phase) }
    default:
      return false
    }
    guard let phase = phase(of: nsEvent) else {
      TapLog.debug("pinch event without a phase (\(nsEvent.phase.rawValue)); left to the app")
      return false
    }
    // The event's location is in global top-left coordinates, like the window list's bounds.
    let pointer = event.location
    let flags = event.flags
    let magnification = Double(nsEvent.magnification)
    let answer = context.router.withLock {
      let onDesktop = $0.pinchesOnDesktop
      // The claim is worked out only when a pinch begins.
      return $0.pinch(
        phase, magnification: magnification, at: pointer,
        claim: optionIsHeld(flags) || (onDesktop && !WindowList.appWindowIsUnder(pointer)))
    }
    if phase != .changed {
      TapLog.debug(
        "pinch \(phase) (NSEvent phase \(nsEvent.phase.rawValue)): \(answer.swallow ? "Arbor's" : "the app's")")
      // A pinch of Arbor's claims the scrolls that begin during it, keys or no keys. And with the keys up this tap stays on only
      // until the pinch is over.
      switchTaps(context, keys(flags))
    }
    act(on: answer, context)
    return answer.swallow
  }

  /// Returns true to swallow the event.
  private nonisolated static func handleScroll(_ event: CGEvent, context: Context) -> Bool {
    let keys = Keys(event.flags)
    // While the tap is on every scroll on the Mac waits for this callback.
    guard context.router.withLock({ $0.scrollNeedsALook(keys: keys) }) else {
      // On for nothing: the monitors missed a key going up.
      switchTaps(context, keys)
      return false
    }
    let phase = ScrollClaim.Phase(scrollPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase))
    let momentum = ScrollClaim.Momentum(momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase))
    // A wheel turns in notches, counted in lines; of those only the direction is used.
    let hasNotches = event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0
    // Axis 1 is vertical.
    let points = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
    let lines = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let pan = CGSize(
      width: event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2),
      height: hasNotches && points == 0 ? lines : points)
    let pointer = event.location
    let answer = context.router.withLock {
      $0.scroll(
        phase, momentum: momentum, pan: pan, at: pointer, keys: keys,
        hasNotches: hasNotches, overDesktop: !WindowList.appWindowIsUnder(pointer))
    }
    if phase != .changed, phase != .none {
      TapLog.debug("scroll \(phase): \(answer.swallow ? "Arbor's" : "the app's")")
    }
    // With the keys up the tap stays on only until the scroll and its momentum are over.
    if keys != .arbors, phase != .changed { switchTaps(context, keys) }
    act(on: answer, context)
    return answer.swallow
  }

  /// On the main actor after the callback returns: the event is held back only until then.
  private nonisolated static func act(on answer: GestureRouter.Answer, _ context: Context) {
    for command in answer.commands {
      DispatchQueue.main.async { context.onCommand(command) }
    }
    if answer.needsVisit { visit(context) }
  }

  /// Has the main actor collect what the router has gathered. The router asks for this once per
  /// burst of events, however many there are.
  private nonisolated static func visit(_ context: Context) {
    DispatchQueue.main.async {
      for update in context.router.withLock({ $0.drain() }) { context.onGesture(update) }
    }
  }

  /// Forgets the gesture in progress, for when events may have been missed, and for `stop()`.
  /// Whoever saw it begin is told that it was cancelled.
  private nonisolated static func reset(_ context: Context) {
    if context.router.withLock({ $0.reset() }) { visit(context) }
    // What was on only for the gesture's sake goes off.
    switchTaps(context, keys([]))
  }

  private nonisolated static func phase(of event: NSEvent) -> GestureInterpreter.Phase? {
    let phase = event.phase
    if phase.contains(.began) { return .began }
    if phase.contains(.changed) || phase.contains(.stationary) { return .changed }
    if phase.contains(.ended) { return .ended }
    if phase.contains(.cancelled) { return .cancelled }
    return nil
  }

  /// Gesture events may not carry modifier flags, so this asks for the keys held now as well.
  private nonisolated static func optionIsHeld(_ flags: CGEventFlags) -> Bool {
    flags.contains(.maskAlternate) || CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
  }
}

extension GestureRouter.Keys {
  fileprivate init(_ flags: NSEvent.ModifierFlags) {
    self.init(
      control: flags.contains(.control), option: flags.contains(.option), shift: flags.contains(.shift),
      command: flags.contains(.command))
  }

  fileprivate init(_ flags: CGEventFlags) {
    self.init(
      control: flags.contains(.maskControl), option: flags.contains(.maskAlternate), shift: flags.contains(.maskShift),
      command: flags.contains(.maskCommand))
  }
}
