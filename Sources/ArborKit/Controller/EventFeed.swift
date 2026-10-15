import ArborCore

/// Turns the controller's changes into the lines of `arborctl watch` (docs/features/F24-events.md).
///
/// The controller only says that something changed. The feed waits for the burst to end (one command can
/// lay a display out three times), takes one `ArborEvent.Summary` of the state, and sends the
/// difference from the summary before. So a relayout that changed nothing sends nothing, a window that
/// was docked and floated again within one burst is never mentioned, and no client can be told something that
/// is not so. While nobody is watching, a change costs one function call.
@MainActor
public final class EventFeed {
  /// Enough for a status bar item per display and a few scripts, and few enough that a script that
  /// starts watchers and forgets them is refused before it costs anything.
  public static let maximumSubscribers = 16

  private struct Subscriber {
    var options: WatchOptions
    var sink: (String) -> Void
  }

  private let controller: Controller
  /// `stop` was called: everyone has heard `quitting`, which is the last thing anyone hears.
  private var hasStopped = false
  private var subscribers: [Int: Subscriber] = [:]
  private var nextSubscriberID = 1
  /// What every subscriber has been told.
  private var known: ArborEvent.Summary
  private var knownSettings: Settings
  /// The window that has the keyboard, as far as is known. Asking the system after every change would mean
  /// waiting for the frontmost app each time, for up to a second if it is busy, so it is asked only when
  /// something was reported that may have moved the keyboard.
  private var focused: WindowID?
  private var focusMayHaveMoved = false
  private var flushIsScheduled = false
  /// macOS does not change everything at once when the keyboard moves: a report can arrive before the system's
  /// answer has changed. So the answer is asked for once more, this much later.
  static let secondLookAtFocus = 0.25
  /// How long to leave the controller alone while it has a layout put off.
  static let waitForLayout = 0.05

  public init(controller: Controller) {
    self.controller = controller
    known = ArborEvent.Summary(running: false, accessibility: controller.accessibilityGranted)
    knownSettings = controller.settings
    controller.observe { [weak self] change in self?.controllerChanged(change) }
  }

  public var subscriberCount: Int { subscribers.count }
  public var hasRoom: Bool { subscribers.count < Self.maximumSubscribers && !hasStopped }

  /// Starts sending lines (without newlines) to `sink`, beginning with `hello`, now. Returns the
  /// number to `unsubscribe` with, or nil if there is no room.
  public func subscribe(_ options: WatchOptions, sink: @escaping (String) -> Void) -> Int? {
    guard hasRoom else { return nil }
    // Worth asking once per client, as `state` does: `hello` is then right even if a change of focus was missed.
    focusMayHaveMoved = true
    // Afterwards `known` is the state now, and what everyone else has been told as well. While a layout is put off the others are
    // told nothing, so the newcomer hears what they know, and the rest together with them.
    if subscribers.isEmpty || controller.postponedRelayouts.isEmpty {
      flush()
    } else if !flushIsScheduled {
      scheduleFlush(after: Self.waitForLayout)
    }
    let id = nextSubscriberID
    nextSubscriberID += 1
    subscribers[id] = Subscriber(options: options, sink: sink)
    let state = options.titles ? known : known.withoutTitles
    sink(ArborEvent.hello(ArborEvent.Hello(version: controller.buildInfo.version, snapshot: state)).line)
    return id
  }

  public func unsubscribe(_ id: Int) {
    subscribers[id] = nil
  }

  /// Arbor is quitting: sends what is still to be said, then `quitting`, now. Only the app knows that it is
  /// quitting; a controller that stops may be pausing, or be started again.
  public func stop() {
    guard !hasStopped else { return }
    flush()
    send { _ in [.quitting] }
    hasStopped = true
  }

  // MARK: From changes to lines

  private func controllerChanged(_ change: Controller.Change) {
    switch change {
    case .focus, .keyboard:
      // A report says that some app's focused window changed, perhaps in the background; who has the keyboard is
      // for the system to say.
      focusMayHaveMoved = true
      if !subscribers.isEmpty {
        controller.scheduler.schedule("events-focus", after: Self.secondLookAtFocus) { [weak self] in
          self?.focusMayHaveMoved = true
          self?.flushWhenSettled()
        }
      }
    case .lifecycle:
      guard controller.isRunning else {
        // Paused, or stopping. A pause is news at once: nothing else will bring the main loop round for a while.
        flush()
        return
      }
      focusMayHaveMoved = true
    case .frames:
      // Events carry the frames of layouts, which are announced as such. This comes with every step of a drag.
      return
    default:
      break
    }
    guard !subscribers.isEmpty, !flushIsScheduled else { return }
    // No delay: as soon as whatever is changing things has returned to the main loop.
    scheduleFlush(after: 0)
  }

  private func scheduleFlush(after seconds: Double) {
    flushIsScheduled = true
    controller.scheduler.schedule("events", after: seconds) { [weak self] in self?.flushWhenSettled() }
  }

  /// macOS reports a switch of its Spaces window by window, and the controller lays out once it has heard them all.
  /// Until then the layout is of windows that have left, so look again in a moment. (Not at once: the layout waits
  /// for as long as a window is being dragged, and this must not keep the main loop busy meanwhile.)
  private func flushWhenSettled() {
    // With nobody left to tell there is nothing to wait for. Whoever comes next makes the feed look.
    guard controller.postponedRelayouts.isEmpty || subscribers.isEmpty else { return scheduleFlush(after: Self.waitForLayout) }
    flush()
  }

  /// Sends whatever has changed since the last time.
  public func flush() {
    flushIsScheduled = false
    guard !hasStopped else { return }
    if focusMayHaveMoved, controller.isRunning {
      focusMayHaveMoved = false
      focused = controller.system.focusedWindow()
    }
    let previous = known
    let changedKeys = controller.settings == knownSettings ? [] : controller.settings.keysThatDiffer(from: knownSettings)
    known = controller.eventSummary(focused: focused)
    knownSettings = controller.settings
    guard previous != known || !changedKeys.isEmpty else { return }
    let current = known
    send { titles in
      (changedKeys.isEmpty ? [] : [.settings(changed: changedKeys)])
        + (titles
          ? ArborEvent.changes(from: previous, to: current)
          : ArborEvent.changes(from: previous.withoutTitles, to: current.withoutTitles))
    }
  }

  /// Sends each subscriber the events it asked for out of `events(titles)`, which is worked out and
  /// turned into lines once for those who may see titles and once for those who may not.
  private func send(_ events: (_ titles: Bool) -> [ArborEvent]) {
    var batches: [Bool: [(kind: ArborEvent.Kind, line: String)]] = [:]
    for id in subscribers.keys.sorted() {
      guard let subscriber = subscribers[id] else { continue }
      let titles = subscriber.options.titles
      let batch = batches[titles] ?? events(titles).map { ($0.kind, $0.line) }
      batches[titles] = batch
      for (kind, line) in batch where subscriber.options.includes(kind) {
        // A sink that finds its client gone unsubscribes, from inside the call.
        guard subscribers[id] != nil else { break }
        subscriber.sink(line)
      }
    }
  }
}
