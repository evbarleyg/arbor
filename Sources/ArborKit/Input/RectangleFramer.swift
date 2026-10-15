import AppKit
import ArborCore
import os

/// Hold the frame modifier (⌃⌥ by default, setting `frameRectangleModifier`)
/// and drag, or hold ⇧ alone and start on the bare Desktop inside Arbor's
/// view (setting `frameRectangleOnDesktop`): a rubber band follows the
/// pointer, and on release the camera frames what the rectangle covers,
/// through the `frame-rect` command (docs/features/F05-frame-a-rectangle.md).
///
/// The same taps keep a plain click on bare Desktop from macOS, which would sweep every window aside
/// (setting `guardDesktopClicks`, docs/features/F60-guard-the-wallpaper-click.md): it is the same question about
/// the same event, and two taps that each held presses back would see each other's.
///
/// Apps do not see the drag. A modifier-click without a drag still reaches
/// the app, a moment late. The decisions are made by `RectangleGesture` and
/// `PointerSurface`; this class only reads events, draws the band and sends
/// the command.
///
/// Two taps, both on the tap thread (`EventTapThread`): one on mouse-downs,
/// and one on drags and mouse-ups that is paused except while a modifier
/// press is being followed, so the stream of ordinary drag events never
/// passes through Arbor. They are installed together, so that no other
/// app's tap comes between them: one in between would see the mouse-down of a
/// rectangle and never its mouse-up, and a modifier-click's mouse-down twice.
/// The gesture state lives in a lock-protected box shared by the callbacks
/// and the main actor; the band is drawn and the command run on the main
/// actor after a callback has returned.
@MainActor
final class RectangleFramer {
  private struct TapState {
    var gesture = RectangleGesture()
    /// The mouse-down held back until we know whether a drag follows.
    var heldDown: CGEvent?
    /// Its mouse-up, if the click was over before Finder had said what is under it.
    var heldUp: CGEvent?
    /// The number of the press that was last asked about.
    var askedPress = 0

    /// Hands over what is held.
    mutating func takeHeld() -> [CGEvent] {
      defer { (heldDown, heldUp) = (nil, nil) }
      return [heldDown, heldUp].compactMap { $0 }
    }
    /// Where the band should be (nil: hidden); drawn after the callback returns.
    var bandFrame: CGRect?
    var bandUpdateQueued = false
    /// The tap on drags and mouse-ups, paused except while a press is being followed.
    var dragTap: EventTap?
    /// Where a press might land on bare Desktop, by the controller's latest word.
    var zones = DesktopGuardZones()
  }

  /// What the tap callbacks need: the state, and the three things that must
  /// happen on the main actor. The state is only ever touched under its lock.
  private final class Context: @unchecked Sendable {
    let state = OSAllocatedUnfairLock(uncheckedState: TapState())
    let onCommand: @MainActor (Command) -> Void
    let onPress: @MainActor () -> Void
    let draw: @MainActor () -> Void

    init(
      onCommand: @escaping @MainActor (Command) -> Void, onPress: @escaping @MainActor () -> Void,
      draw: @escaping @MainActor () -> Void
    ) {
      self.onCommand = onCommand
      self.onPress = onPress
      self.draw = draw
    }
  }

  private let settings: @MainActor () -> Settings
  private var context: Context!
  private var downTap: EventTap?
  private var band: RubberBandPanel?
  /// The last `frameRectangleModifier` that could not be read, so that it is logged once.
  private var unreadableModifier: String?

  /// - Parameter onPress: told of every press that is held back. Whoever listens for presses with an `NSEvent` monitor
  ///   hears nothing of those, unless and until they are given back.
  init(
    settings: @escaping @MainActor () -> Settings, onCommand: @escaping @MainActor (Command) -> Void,
    onPress: @escaping @MainActor () -> Void
  ) {
    self.settings = settings
    context = Context(onCommand: onCommand, onPress: onPress, draw: { [weak self] in self?.drawBand() })
  }

  /// Takes what the settings say about the gesture and installs the taps, or
  /// removes them when the settings leave no press that could be Arbor's. Runs
  /// at launch and whenever settings are applied.
  func update() {
    let settings = settings()
    let (isReadable, isEnabled) = context.state.withLockUnchecked { state -> (Bool, Bool) in
      let isReadable = state.gesture.follow(settings)
      return (isReadable, state.gesture.isEnabled)
    }
    // Once: settings are applied again on every `exclude`.
    if !isReadable, unreadableModifier != settings.frameRectangleModifier {
      unreadableModifier = settings.frameRectangleModifier
      Log.error(
        "frameRectangleModifier \"\(settings.frameRectangleModifier)\" is not like \"ctrl+opt\" or \"none\"; "
          + "using \(Settings().frameRectangleModifier)")
    }
    guard isEnabled else {
      stop()
      return
    }
    guard downTap == nil else { return }
    let context = self.context!
    let tap = EventTap(name: "rectangle", mask: 1 << CGEventType.leftMouseDown.rawValue) { event, proxy in
      Self.handleDown(event, proxy: proxy, context: context)
    }
    tap.onReset = { Self.reset(context) }
    let dragMask = [CGEventType.leftMouseDragged, .leftMouseUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
    let dragTap = EventTap(name: "rectangle drag", mask: dragMask) { event, proxy in
      Self.handleDrag(event, proxy: proxy, context: context)
    }
    dragTap.onReset = { Self.reset(context) }
    guard tap.start() else { return }
    guard dragTap.start(paused: true) else {
      tap.stop()
      return
    }
    // A press that arrives before this line finds no drag tap and is let through.
    context.state.withLockUnchecked { $0.dragTap = dragTap }
    downTap = tap
    Log.info("rectangle event taps installed")
  }

  func stop() {
    downTap?.stop()
    downTap = nil
    Self.reset(context)
    let dragTap = context.state.withLockUnchecked { state -> EventTap? in
      defer { state.dragTap = nil }
      return state.dragTap
    }
    dragTap?.stop()
  }

  /// Hands the callbacks the controller's latest word on where bare Desktop might be.
  func publish(_ zones: DesktopGuardZones) {
    context.state.withLockUnchecked { $0.zones = zones }
  }

  var isInstalled: Bool { downTap != nil }

  // MARK: On the tap thread

  /// Returns true to swallow the event.
  private nonisolated static func handleDown(_ event: CGEvent, proxy: CGEventTapProxy, context: Context) -> Bool {
    // The mouse-down sent on by `.replay` comes past this tap again: it must not be held twice.
    if event.getIntegerValueField(.eventSourceUserData) == EventTap.replayMark { return false }
    // A band still showing belongs to a drag whose mouse-up was missed.
    showBand(nil, context)
    // A click that still waits for Finder's answer goes ahead of this press: events arrive in the order they were made.
    // Half a click still held belongs to a press whose mouse-up was missed, and is forgotten.
    let waiting = context.state.withLockUnchecked { state -> [CGEvent] in
      let held = state.takeHeld()
      return state.gesture.giveUpWaiting() ? held : []
    }
    sendOn(waiting, proxy: proxy)
    let point = event.location
    let held = modifiers(of: event.flags)
    let (asks, zones) = context.state.withLockUnchecked { ($0.gesture.asksAboutDesktop(modifiers: held), $0.zones) }
    var surface = PointerSurface.Surface.taken
    // The window list is read only for a plain press or one with ⇧ alone, and only where Arbor knows of no
    // window. Every other click leaves at once. Not under the lock: the main actor must not wait for the window server.
    if asks, zones.mayBeBare(point, throughPanels: !held.isEmpty) {
      surface = WindowList.under(point, mayVanish: held.isEmpty)
    }
    let isOnDesktop = surface != .taken
    let response = context.state.withLockUnchecked {
      $0.gesture.mouseDown(at: point, modifiers: held, onDesktop: isOnDesktop)
    }
    switch response {
    case .ask(let press):
      guard let copy = event.copy(), case .bare(let desktopOwner) = surface, followDrag(context) else {
        reset(context)
        return false
      }
      context.state.withLockUnchecked {
        $0.heldDown = copy
        $0.askedPress = press
      }
      DispatchQueue.main.async { context.onPress() }
      guard let desktopOwner else {
        // Nobody draws icons here, so it is the wallpaper.
        context.state.withLockUnchecked { _ = $0.gesture.desktopAnswered(isItem: false, press: press) }
        return true
      }
      // Not from here: all input would wait for Finder. The answer is needed when the button comes up.
      DesktopProbe.ask(
        pid: desktopOwner, at: point, mayVanish: held.isEmpty,
        isWanted: { context.state.withLockUnchecked { $0.gesture.isWaitingForAnswer(press: press) } },
        answer: { isItem in
          // The click may be over by now, and waiting whole.
          let (verdict, held) = context.state.withLockUnchecked { state -> (RectangleGesture.Response, [CGEvent]) in
            let verdict = state.gesture.desktopAnswered(isItem: isItem, press: press)
            return (verdict, verdict == .pass ? [] : state.takeHeld())
          }
          if verdict == .replayClick { sendOn(held, proxy: nil) }
        })
      return true
    case .hold:
      // Hold the press back only if it can be given back: with nothing to send on, or nothing
      // watching for the mouse-up, the app would lose the click.
      guard let copy = event.copy(), followDrag(context) else {
        reset(context)
        return false
      }
      context.state.withLockUnchecked { $0.heldDown = copy }
      DispatchQueue.main.async { context.onPress() }
      return true
    default:
      // A mouse-down starts the gesture over, so a drag tap still following
      // a press whose mouse-up was missed has nothing to follow.
      stopFollowing(context)
      return false
    }
  }

  /// Returns true to swallow the event.
  private nonisolated static func handleDrag(_ event: CGEvent, proxy: CGEventTapProxy, context: Context) -> Bool {
    let point = event.location
    let isUp = event.type == .leftMouseUp
    // Made before the lock is taken. A click that is held whole must be in the state, both halves, by the time the lock
    // is free: from then on Finder's answer, on another thread, may take it out again.
    let copy = isUp ? event.copy() : nil
    let held = modifiers(of: event.flags)
    let (response, press) = context.state.withLockUnchecked { state -> (RectangleGesture.Response, Int) in
      guard isUp else { return (state.gesture.mouseDragged(to: point), 0) }
      var response = state.gesture.mouseUp(at: point, modifiers: held)
      if response == .holdClick {
        state.heldUp = copy
        // It cannot be kept, so the click is given back now.
        if copy == nil, state.gesture.giveUpWaiting() { response = .replay }
      }
      return (response, state.askedPress)
    }
    switch response {
    case .pass:
      stopFollowing(context)
      return false
    case .hold, .swallow, .ask:
      return true
    case .drop:
      // A click on bare Desktop: nobody gets it, so macOS sweeps nothing aside.
      context.state.withLockUnchecked { _ = $0.takeHeld() }
      stopFollowing(context)
      return true
    case .holdClick:
      stopFollowing(context)
      // The answer always comes, but behind a Finder that is stuck it may be long in coming.
      DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + longestWait) {
        sendOn(context.state.withLockUnchecked { $0.gesture.giveUpWaiting(press: press) ? $0.takeHeld() : [] }, proxy: nil)
      }
      return true
    case .replayClick:
      // Only `desktopAnswered` says this.
      return false
    case .band(let rect):
      context.state.withLockUnchecked { $0.heldDown = nil }
      showBand(rect, context)
      return true
    case .replay:
      // Not Arbor's after all (a modifier-click; on the Desktop, a drag or a click on an icon): the app
      // gets the mouse-down it missed, then this event.
      sendOn(context.state.withLockUnchecked { $0.takeHeld() }, proxy: proxy)
      stopFollowing(context)
      return false
    case .cancel:
      context.state.withLockUnchecked { _ = $0.takeHeld() }
      showBand(nil, context)
      stopFollowing(context)
      return true
    case .frame(let rect):
      // Mostly gone since the first band. Not if the answer about the Desktop came after the last drag.
      context.state.withLockUnchecked { _ = $0.takeHeld() }
      showBand(nil, context)
      stopFollowing(context)
      let command = Command.frameRect(
        x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height))
      // On the main actor after the callback returns: the controller moves windows, which takes a while.
      DispatchQueue.main.async { context.onCommand(command) }
      return true
    }
  }

  /// How long a click that is held whole waits for Finder's answer before it is given back.
  private nonisolated static let longestWait = 0.3

  /// Gives back what was held, in order, marked so that Arbor's own taps let it pass.
  /// - Parameter proxy: a callback's. The events then enter right behind its tap, ahead of the event it has in hand.
  ///   Without one (not in a callback) they enter where all events of the session do.
  private nonisolated static func sendOn(_ events: [CGEvent], proxy: CGEventTapProxy?) {
    for event in events {
      event.setIntegerValueField(.eventSourceUserData, value: EventTap.replayMark)
      if let proxy { event.tapPostEvent(proxy) } else { event.post(tap: .cgSessionEventTap) }
    }
  }

  /// Lets drags and mouse-ups through the drag tap for the press just held. On the tap thread,
  /// so they come from the next event on. Returns false if there is no tap to follow with.
  private nonisolated static func followDrag(_ context: Context) -> Bool {
    context.state.withLockUnchecked { $0.dragTap }?.resume() ?? false
  }

  private nonisolated static func stopFollowing(_ context: Context) {
    context.state.withLockUnchecked { $0.dragTap }?.pause()
  }

  /// Forgets the press or drag in progress, for when events may have been
  /// missed, and for `stop()`.
  private nonisolated static func reset(_ context: Context) {
    // A whole click that was waiting is given back: nobody missed any of its events. So is a press whose button is still
    // down: its mouse-up is yet to come, and will reach the app. If the button is up, the mouse-up was among the events
    // that were missed, and a press sent on now would leave the app in a drag.
    let (held, isWhole) = context.state.withLockUnchecked { state -> ([CGEvent], Bool) in
      defer { state.gesture.reset() }
      return (state.takeHeld(), state.gesture.giveUpWaiting())
    }
    if isWhole || CGEventSource.buttonState(.combinedSessionState, button: .left) { sendOn(held, proxy: nil) }
    showBand(nil, context)
    stopFollowing(context)
  }

  private nonisolated static func modifiers(of flags: CGEventFlags) -> RectangleGesture.Modifiers {
    var modifiers: RectangleGesture.Modifiers = []
    if flags.contains(.maskControl) { modifiers.insert(.control) }
    if flags.contains(.maskAlternate) { modifiers.insert(.option) }
    if flags.contains(.maskShift) { modifiers.insert(.shift) }
    if flags.contains(.maskCommand) { modifiers.insert(.command) }
    return modifiers
  }

  /// Moves the band (nil hides it) on the main actor once the callback has
  /// returned, so a burst of drag events costs one redraw.
  private nonisolated static func showBand(_ frame: CGRect?, _ context: Context) {
    let queue = context.state.withLockUnchecked { state -> Bool in
      guard state.bandFrame != frame else { return false }
      state.bandFrame = frame
      guard !state.bandUpdateQueued else { return false }
      state.bandUpdateQueued = true
      return true
    }
    if queue { DispatchQueue.main.async { context.draw() } }
  }

  // MARK: On the main actor

  private func drawBand() {
    let frame = context.state.withLockUnchecked { state -> CGRect? in
      state.bandUpdateQueued = false
      return state.bandFrame
    }
    guard let frame else {
      band?.orderOut(nil)
      return
    }
    let panel = band ?? RubberBandPanel()
    band = panel
    panel.show(frame)
  }
}

/// The translucent rectangle drawn while dragging. It ignores the mouse.
final class RubberBandPanel: OverlayPanel {
  override init() {
    super.init()
    level = .floating
    ignoresMouseEvents = true
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    contentView = RubberBandView()
  }

  func show(_ frame: CGRect) {
    setFrame(ScreenGeometry.appKit(fromGlobal: frame), display: true)
    orderFrontRegardless()
  }
}

private final class RubberBandView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    AccentInk.mark(bounds, radius: 0, fill: 0.15, width: 1)
  }
}
