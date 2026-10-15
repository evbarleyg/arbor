import CoreGraphics

/// Follows a mouse drag made with the frame modifier held (⌃⌥ by default),
/// or with ⇧ alone where no app's window is under the pointer, which draws a
/// rectangle for Arbor to frame (docs/features/F05-frame-a-rectangle.md),
/// and says what to do with each mouse event.
///
/// The mouse-down is held back until the pointer moves. If the button comes
/// up first, it was a plain modifier-click (a click with ⌃ opens a contextual
/// menu, for example): the held mouse-down is sent on and the app gets its
/// click. Once the pointer moves more than `dragThreshold` points, the drag
/// is Arbor's and none of its events reach an app.
public struct RectangleGesture: Equatable, Sendable {
  /// Modifier keys, written in settings as `shift+cmd`, `Command + Shift` or `⇧⌘`.
  public struct Modifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let control = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let shift = Modifiers(rawValue: 1 << 2)
    public static let command = Modifiers(rawValue: 1 << 3)

    private static let names: [String: Modifiers] = [
      "ctrl": .control, "control": .control, "⌃": .control,
      "opt": .option, "option": .option, "alt": .option, "⌥": .option,
      "shift": .shift, "⇧": .shift,
      "cmd": .command, "command": .command, "⌘": .command,
    ]

    /// Parses modifier names or glyphs joined by `+`, ignoring case and
    /// spaces. `none` and `off` give the empty set. Nil if any part is not a
    /// modifier, or if nothing is named.
    public init?(text: String) {
      let compact = String(text.lowercased().filter { !$0.isWhitespace })
      if compact == "none" || compact == "off" {
        self = []
        return
      }
      var result: Modifiers = []
      for part in compact.split(separator: "+", omittingEmptySubsequences: false) {
        if let modifier = Self.names[String(part)] {
          result.insert(modifier)
          continue
        }
        // Glyphs may be run together, as in ⇧⌘.
        let glyphs = part.map { Self.names[String($0)] }
        guard !glyphs.isEmpty, !glyphs.contains(nil) else { return nil }
        for glyph in glyphs { result.insert(glyph!) }
      }
      guard !result.isEmpty else { return nil }
      self = result
    }

    /// The canonical text form, e.g. `shift+cmd`, or `none`.
    public var text: String {
      let words: [(Modifiers, String)] = [
        (.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd"),
      ]
      let held = words.filter { contains($0.0) }.map(\.1)
      return held.isEmpty ? "none" : held.joined(separator: "+")
    }
  }

  /// What to do with one mouse event.
  public enum Response: Equatable, Sendable {
    /// Let it through untouched.
    case pass
    /// Hide this mouse-down from apps but keep it: it may turn out to be a click.
    case hold
    /// Hide it from apps.
    case swallow
    /// Hide it from apps and draw the rubber band over this rectangle.
    case band(CGRect)
    /// Not Arbor's after all: send the held mouse-down on, then let this event through.
    case replay
    /// Hide this mouse-down from apps but keep it, and find out whether an item of the Desktop's
    /// (an icon, a widget) is under the pointer. The answer goes to `desktopAnswered`, with this number.
    case ask(press: Int)
    /// Hide it from apps and forget what is held: nobody gets this click.
    case drop
    /// Hide this mouse-up from apps but keep it, with the held mouse-down: the click is over before anybody has
    /// said what is under it. `desktopAnswered` or `giveUpWaiting` says what becomes of it.
    case holdClick
    /// Not Arbor's after all: send the held mouse-down and mouse-up on.
    case replayClick
    /// Hide it from apps, remove the rubber band, and frame this rectangle.
    case frame(CGRect)
    /// Hide it from apps, remove the rubber band, forget what is held, and frame nothing: it was called off.
    case cancel
  }

  /// How far (in points, along either axis) the pointer must move before a press becomes a drag.
  public static let dragThreshold: CGFloat = 4

  private enum State: Equatable, Sendable {
    case idle
    case pressed(start: CGPoint)
    case dragging(start: CGPoint)
    /// A press on the Desktop, held: a plain one (F60), or one that `draws` a rectangle if it
    /// becomes a drag. `isItem` is nil until Finder has said whether an icon or widget is under it.
    case asking(start: CGPoint, isItem: Bool?, draws: Bool)
    /// A plain click on the Desktop, both halves held, that Finder has not answered for yet.
    case waiting
  }

  /// What `desktopTrigger` is when the setting `frameRectangleOnDesktop` is on.
  public static let desktopModifiers: Modifiers = [.shift]

  /// The modifiers that start a rectangle anywhere, matched exactly so other
  /// chords (⌃⌥⌘-drag) stay with the apps. Empty turns this off.
  public var trigger: Modifiers
  /// The modifiers that start a rectangle only where no app's window is under
  /// the pointer (the Desktop, a gap between windows, a tile), matched
  /// exactly. Over an app ⇧-drag extends a selection. Empty turns this off.
  public var desktopTrigger: Modifiers
  /// Keeps a plain click on bare Desktop from reaching macOS, which would sweep every window aside
  /// ("Click wallpaper to reveal desktop", on by default since macOS 14;
  /// docs/features/F60-guard-the-wallpaper-click.md). A drag is given back to Finder.
  public var guardsDesktopClicks = false
  /// How many presses have been asked about, so that a late answer is not taken for the next press's.
  private var presses = 0
  /// The modifiers the press in progress began with.
  private var keys: Modifiers = []
  private var state: State = .idle

  public init(
    trigger: Modifiers = [.control, .option], desktopTrigger: Modifiers = RectangleGesture.desktopModifiers
  ) {
    self.trigger = trigger
    self.desktopTrigger = desktopTrigger
  }

  /// Takes everything the settings say about this gesture, so that whoever turns settings off for a while
  /// (a pause, a pass-through app: `Controller.inputSettings`) is tested against what the tap really does.
  /// Returns false if `frameRectangleModifier` could not be read; the default is used then.
  @discardableResult
  public mutating func follow(_ settings: Settings) -> Bool {
    let parsed = Modifiers(text: settings.frameRectangleModifier)
    trigger = parsed ?? Modifiers(text: Settings().frameRectangleModifier) ?? [.control, .option]
    desktopTrigger = settings.frameRectangleOnDesktop ? Self.desktopModifiers : []
    guardsDesktopClicks = settings.guardDesktopClicks
    return parsed != nil
  }

  /// Whether any press can be Arbor's. If not, there is nothing to watch the mouse for.
  public var isEnabled: Bool { !trigger.isEmpty || !desktopTrigger.isEmpty || guardsDesktopClicks }

  /// Whether a press or drag is in progress.
  public var isTracking: Bool { state != .idle }

  /// Whether the tap on mouse-downs has to be switched on. While it is, every press on the Mac waits for Arbor, and if Arbor
  /// loses the right to its taps meanwhile, the next press costs the Mac its input (`TapPermission`). So it is installed but
  /// paused, and switched on only while a press could be Arbor's: exactly the keys of one of the two gestures are down, or a
  /// press is being followed, whatever the keys do meanwhile. With the guard of the wallpaper click any plain press could be.
  public func downTapIsWanted(modifiers: Modifiers) -> Bool {
    if guardsDesktopClicks || isTracking { return true }
    return !modifiers.isEmpty && (modifiers == trigger || modifiers == desktopTrigger)
  }

  /// Whether a press with these modifiers could be Arbor's on the Desktop and nowhere else (a plain one with the
  /// guard on, one with `desktopTrigger` held), so that it matters what is under the pointer. Finding that
  /// out is expensive, and must not be done for every click.
  public func asksAboutDesktop(modifiers: Modifiers) -> Bool {
    if !modifiers.isEmpty, modifiers == trigger { return false }
    return modifiers.isEmpty ? guardsDesktopClicks : modifiers == desktopTrigger
  }

  /// - Parameter onDesktop: whether the press is on the Desktop inside Arbor's view of a display with
  ///   something docked, where nobody else can want it. Evaluated only if `asksAboutDesktop`.
  public mutating func mouseDown(
    at point: CGPoint, modifiers: Modifiers, onDesktop: @autoclosure () -> Bool = false
  ) -> Response {
    // A mouse-down while tracking means the mouse-up was missed: start over.
    state = .idle
    keys = modifiers
    // No modifiers match an empty trigger, which means off.
    if !modifiers.isEmpty, modifiers == trigger {
      state = .pressed(start: point)
      return .hold
    }
    guard asksAboutDesktop(modifiers: modifiers), onDesktop() else { return .pass }
    presses += 1
    state = .asking(start: point, isItem: nil, draws: !modifiers.isEmpty)
    return .ask(press: presses)
  }

  public mutating func mouseDragged(to point: CGPoint) -> Response {
    switch state {
    case .idle:
      return .pass
    case .pressed(let start):
      let moved = max(abs(point.x - start.x), abs(point.y - start.y))
      guard moved > Self.dragThreshold else { return .swallow }
      state = .dragging(start: start)
      return .band(Self.rectangle(from: start, to: point))
    case .dragging(let start):
      return .band(Self.rectangle(from: start, to: point))
    case .asking(let start, let isItem, let draws):
      let moved = max(abs(point.x - start.x), abs(point.y - start.y))
      guard moved > Self.dragThreshold else { return .swallow }
      // The hand is often faster than Finder. The answer always comes (`desktopAnswered`), so wait for it.
      if draws, isItem == nil { return .swallow }
      // Only a drag known to start on the wallpaper draws a rectangle: taking one from an icon is
      // the worse mistake. Every other drag on the Desktop is Finder's: its selection rectangle, or
      // an icon on its way.
      guard draws, isItem == false else {
        state = .idle
        return .replay
      }
      state = .dragging(start: start)
      return .band(Self.rectangle(from: start, to: point))
    case .waiting:
      return .pass
    }
  }

  /// Whether the answer to `.ask(press:)` is still of any use.
  public func isWaitingForAnswer(press: Int) -> Bool {
    guard press == presses else { return false }
    if case .asking(_, nil, _) = state { return true }
    return state == .waiting
  }

  /// Finder's answer to `.ask(press:)`: whether an item of the Desktop's is under the pointer. Whoever asks must
  /// answer in the end, with true if Finder did not say: a drag with ⇧ is kept waiting for it.
  ///
  /// Returns what to do now: nothing (`.pass`) while the button is down, and for a click that was waiting whole,
  /// `.drop` or `.replayClick`.
  @discardableResult
  public mutating func desktopAnswered(isItem: Bool, press: Int) -> Response {
    guard press == presses else { return .pass }
    switch state {
    case .asking(let start, _, let draws):
      state = .asking(start: start, isItem: isItem, draws: draws)
      return .pass
    case .waiting:
      state = .idle
      return isItem ? .replayClick : .drop
    default:
      return .pass
    }
  }

  /// Stops waiting for an answer about a click that is held whole. Returns true if there was one: it must then be
  /// sent on. Call it before `mouseDown`, so that events arrive in the order they were made, before `reset`,
  /// and when the answer has taken too long.
  /// - Parameter press: only if it is this press's click that waits.
  public mutating func giveUpWaiting(press: Int? = nil) -> Bool {
    guard state == .waiting, press == nil || press == presses else { return false }
    state = .idle
    return true
  }

  /// - Parameter modifiers: the keys that are down now, if known. A rectangle once begun is called off by letting go of its
  ///   keys before the button: the way out of one that was not meant, with no key to be watched during a drag.
  public mutating func mouseUp(at point: CGPoint, modifiers: Modifiers? = nil) -> Response {
    let finished = state
    state = .idle
    let isCalledOff = modifiers.map { !$0.isSuperset(of: keys) } ?? false
    switch finished {
    case .idle: return .pass
    case .waiting:
      state = .waiting
      return .pass
    // The button is often up before Finder has answered: tap to click, a quick finger. Given back now, the click
    // would sweep the windows aside for exactly those people.
    case .asking(_, nil, false):
      state = .waiting
      return .holdClick
    case .pressed: return .replay
    case .dragging(let start): return isCalledOff ? .cancel : .frame(Self.rectangle(from: start, to: point))
    // Finder answered while the hand was at rest, so that no drag came after the answer to draw a band for. It is known
    // to have started on the wallpaper, and it has gone somewhere: it is a rectangle like any other.
    case .asking(let start, false, true) where max(abs(point.x - start.x), abs(point.y - start.y)) > Self.dragThreshold:
      return isCalledOff ? .cancel : .frame(Self.rectangle(from: start, to: point))
    // Only a plain click known to be on the wallpaper is kept back. One that sweeps the windows aside
    // can be undone with another; one an icon never got cannot. A click with ⇧ sweeps nothing.
    case .asking(_, let isItem, let draws): return !draws && isItem == false ? .drop : .replay
    }
  }

  /// Forgets the press or drag in progress, for when events may have been missed.
  public mutating func reset() {
    state = .idle
  }

  /// The rectangle with corners `a` and `b`, whichever way the drag went.
  public static func rectangle(from a: CGPoint, to b: CGPoint) -> CGRect {
    CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
  }
}
