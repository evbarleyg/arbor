import CoreGraphics
import Foundation

/// What `arborctl watch` streams: one event per line, each a JSON object whose first key, `event`, names
/// its kind and whose other keys are the fields of that kind's payload below. docs/SCRIPTING.md
/// documents every field for script authors. Scripts depend on these names: add fields freely,
/// but never rename or remove one, or change what it means.
///
///     {"event":"view","apps":["Safari"],"canGoBack":true,"canGoForward":false,"depth":1,"displayID":"main","kind":"window","label":"Safari","node":1,"outOfView":2,"windows":[101]}
///
/// The names are the glossary's (docs/GLOSSARY.md), not the code's: the view, everything, out of view.
///
/// Window titles can hold anything a person is reading or writing, so they are left out unless
/// the client asked for them (`watch --titles`): see `Summary.withoutTitles`.
public enum ArborEvent: Equatable, Sendable {
  /// The first line of every connection: who is talking, and the state to start from.
  case hello(Hello)
  /// The displays changed: one came, went, or changed size.
  case displays([Display])
  /// A window came under Arbor's care, left it, or changed place or state.
  case window(WindowChange)
  /// A display was laid out differently.
  case layout(Arrangement)
  /// What a display shows changed: the view moved, or it holds other windows now.
  case view(View)
  /// Another window has the keyboard, or none Arbor knows.
  case focus(Focus)
  /// The settings changed: the names of the keys that did.
  case settings(changed: [String])
  /// Arbor began arranging windows. The state follows as ordinary events.
  case started
  /// Arbor is quitting. The last line of a connection.
  case quitting
  /// Arbor was paused: it has put every window back in view and lets go of them until `resumed`.
  case paused
  /// The pause is over. The state follows as ordinary events, as after `started`.
  case resumed

  public enum Kind: String, Codable, Sendable, CaseIterable, Comparable {
    case hello, displays, window, layout, view, focus, settings, started, quitting, paused, resumed

    /// Whether Arbor is there and listening at all is news for every client, whatever else it asked for: a status bar
    /// that watches only the view must not go on showing it through a pause.
    public var isAlwaysSent: Bool { [.hello, .quitting, .paused, .resumed].contains(self) }

    /// In the order they are declared.
    public static func < (a: Kind, b: Kind) -> Bool {
      (allCases.firstIndex(of: a) ?? 0) < (allCases.firstIndex(of: b) ?? 0)
    }
  }

  public var kind: Kind {
    switch self {
    case .hello: .hello
    case .displays: .displays
    case .window: .window
    case .layout: .layout
    case .view: .view
    case .focus: .focus
    case .settings: .settings
    case .started: .started
    case .quitting: .quitting
    case .paused: .paused
    case .resumed: .resumed
    }
  }

  // MARK: Payloads

  public struct Hello: Codable, Equatable, Sendable {
    /// Arbor's version, e.g. "0.1.0"; "dev" for a binary outside a bundle.
    public var version: String
    /// Goes up only if events ever change in a way that breaks scripts written for this one.
    public var `protocol`: Int
    /// Not `state`: in a `window` line that is a word, and one type must be able to read every line.
    public var snapshot: Summary

    public init(version: String, protocol: Int = ArborEvent.protocolVersion, snapshot: Summary) {
      self.version = version
      self.protocol = `protocol`
      self.snapshot = snapshot
    }
  }

  /// A rectangle in global coordinates (points, origin at the main display's top-left corner, y down), with
  /// a name for each number: `.frame.width` reads better in a script than `.frame[1][0]`, which is
  /// what `CGRect` encodes to.
  public struct Rect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(_ rect: CGRect) {
      x = Double(rect.minX)
      y = Double(rect.minY)
      width = Double(rect.width)
      height = Double(rect.height)
    }
  }

  /// On the wire a display's UUID is `displayID`, here and in every other payload: `display` is kept for the
  /// display's number (1 is the main one), which is what commands take.
  public struct Display: Codable, Equatable, Sendable {
    public var display: DisplayID
    /// The display with the menu bar.
    public var main: Bool
    /// Its full bounds.
    public var frame: Rect
    /// What macOS calls it ("Studio Display"); left out if that is not known.
    public var name: String?
    /// A laptop's or an iMac's own display.
    public var builtIn: Bool

    public init(display: DisplayID, main: Bool, frame: CGRect, name: String? = nil, builtIn: Bool = false) {
      self.display = display
      self.main = main
      self.frame = Rect(frame)
      self.name = name
      self.builtIn = builtIn
    }

    private enum CodingKeys: String, CodingKey {
      case display = "displayID"
      case main, frame, name, builtIn
    }
  }

  /// A window Arbor arranges.
  public struct Window: Codable, Equatable, Sendable {
    /// Where the window is, as its user would say it.
    public enum State: String, Codable, Sendable {
      case inView = "in-view"
      /// Outside the view, or behind the front tab of its tab group.
      case outOfView = "out-of-view"
      /// In view, but too small to use: a tile stands in for it.
      case tile
      case minimized
      /// Its app is hidden (⌘H).
      case hidden
      /// In macOS's own full screen (the green button).
      case fullScreen = "full-screen"
      /// On another of macOS's Spaces.
      case otherSpace = "other-space"
    }

    public var id: WindowID
    public var app: String
    public var bundleID: String?
    /// The display whose arrangement holds it.
    public var display: DisplayID
    /// Docked in the arrangement, as opposed to floating on the Desktop.
    public var docked: Bool
    public var state: State
    /// Only for clients that asked for titles.
    public var title: String?

    public init(
      id: WindowID, app: String, bundleID: String?, display: DisplayID, docked: Bool, state: State = .inView,
      title: String? = nil
    ) {
      self.id = id
      self.app = app
      self.bundleID = bundleID
      self.display = display
      self.docked = docked
      self.state = state
      self.title = title
    }

    private enum CodingKeys: String, CodingKey {
      case id = "window"
      case display = "displayID"
      case app, bundleID, docked, state, title
    }
  }

  /// The window's fields as they are after the change (for `closed` and `released`: as they last were), and `change`.
  public struct WindowChange: Codable, Equatable, Sendable {
    public enum Change: String, Codable, Sendable {
      /// It opened, and Arbor arranges it.
      case opened
      /// It closed, or its app quit.
      case closed
      /// It was there before, and Arbor arranges it from now on: Arbor started or resumed, or its app is arranged again.
      case adopted
      /// It is still there, and Arbor no longer arranges it: Don't Arrange was chosen for its app.
      case released
      /// It is docked now, on `displayID`.
      case docked
      /// It floats now, on `displayID`.
      case floated
      /// Its `state` changed.
      case state
      /// Its title changed. Only for clients that asked for titles.
      case title
    }

    public var change: Change
    public var window: Window

    public init(_ change: Change, _ window: Window) {
      self.change = change
      self.window = window
    }

    private enum CodingKeys: String, CodingKey { case change }

    public init(from decoder: any Decoder) throws {
      change = try decoder.container(keyedBy: CodingKeys.self).decode(Change.self, forKey: .change)
      window = try Window(from: decoder)
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(change, forKey: .change)
      try window.encode(to: encoder)
    }
  }

  /// The `layout` event.
  public struct Arrangement: Codable, Equatable, Sendable {
    public var display: DisplayID
    /// Windows docked on the display, in view or not.
    public var docked: Int
    /// Windows floating on its Desktop, in view or not.
    public var floating: Int
    /// Tiles showing: spaces too small to use, standing in for their windows.
    public var tiles: Int
    /// Where each docked window in view is, by window id.
    public var frames: [WindowID: Rect]

    public init(display: DisplayID, docked: Int, floating: Int, tiles: Int, frames: [WindowID: CGRect]) {
      self.display = display
      self.docked = docked
      self.floating = floating
      self.tiles = tiles
      self.frames = frames.mapValues(Rect.init)
    }

    private enum CodingKeys: String, CodingKey {
      case display = "displayID"
      // Counts say so: in a `window` line `docked` is true or false.
      case docked = "dockedCount"
      case floating = "floatingCount"
      case tiles = "tileCount"
      case frames
    }
  }

  public struct View: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
      /// Everything on the display, as after Show Everything.
      case everything
      case desktop
      /// One docked window (or tab group), framed.
      case window
      /// A space of several.
      case group
    }

    public var display: DisplayID
    /// The number of the space that fills the view; `zoom-node` takes it.
    public var node: NodeID
    public var kind: Kind
    /// The space in the words Arbor's replies use: "everything", "the Desktop", "Safari", "Safari and Mail".
    public var label: String
    /// How many steps out it takes to see everything; 0 when everything is in view.
    public var depth: Int
    /// The docked windows in view, in tree order (left to right, top to bottom).
    public var windows: [WindowID]
    /// Their apps' names, in the same order.
    public var apps: [String]
    /// How many of the display's windows are out of view.
    public var outOfView: Int
    public var canGoBack: Bool
    public var canGoForward: Bool
    /// The lowest number of a saved view that leads here, if any does.
    public var savedView: Int?
    /// The space's own name, if it was given one.
    public var name: String?

    public init(
      display: DisplayID, node: NodeID, kind: Kind, label: String, depth: Int, windows: [WindowID], apps: [String],
      outOfView: Int, canGoBack: Bool, canGoForward: Bool, savedView: Int? = nil, name: String? = nil
    ) {
      self.display = display
      self.node = node
      self.kind = kind
      self.label = label
      self.depth = depth
      self.windows = windows
      self.apps = apps
      self.outOfView = outOfView
      self.canGoBack = canGoBack
      self.canGoForward = canGoForward
      self.savedView = savedView
      self.name = name
    }

    private enum CodingKeys: String, CodingKey {
      case display = "displayID"
      case node, kind, label, depth, windows, apps, outOfView, canGoBack, canGoForward, savedView, name
    }
  }

  /// Every field is missing when no window Arbor knows has the keyboard.
  public struct Focus: Codable, Equatable, Sendable {
    public var window: WindowID?
    public var app: String?
    public var bundleID: String?
    /// The display whose arrangement holds the window; missing for a window Arbor does not arrange.
    public var display: DisplayID?
    /// Only for clients that asked for titles.
    public var title: String?

    public init(
      window: WindowID? = nil, app: String? = nil, bundleID: String? = nil, display: DisplayID? = nil,
      title: String? = nil
    ) {
      self.window = window
      self.app = app
      self.bundleID = bundleID
      self.display = display
      self.title = title
    }

    private enum CodingKeys: String, CodingKey {
      case display = "displayID"
      case window, app, bundleID, title
    }
  }

  // MARK: The state behind the events

  /// Everything events report, at one moment: `hello` carries it, and the difference between two of
  /// them is the events in between. Each entry has the fields of the event of the same name.
  public struct Summary: Codable, Equatable, Sendable {
    /// Arbor is arranging windows. While it is not, the lists below are empty.
    public var running: Bool
    /// Arbor has Accessibility permission.
    public var accessibility: Bool
    /// Not running because it was paused, as opposed to not started yet or stopped.
    public var paused = false
    public var displays: [Display] = []
    /// Sorted by id.
    public var windows: [Window] = []
    /// Windows Arbor sees and leaves alone (Don't Arrange, an `ignore` rule), sorted.
    public var notArranged: [WindowID] = []
    /// One per display, in the order of `displays`.
    public var layouts: [Arrangement] = []
    /// One per display, in the order of `displays`.
    public var views: [View] = []
    public var focus = Focus()

    public init(running: Bool, accessibility: Bool) {
      self.running = running
      self.accessibility = accessibility
    }

    /// The same without any window title: all that a client that did not ask for titles may learn.
    public var withoutTitles: Summary {
      var copy = self
      copy.focus.title = nil
      for index in copy.windows.indices { copy.windows[index].title = nil }
      return copy
    }
  }

  /// The events that bring a client that knows `old` up to `new`; none if they are equal. Windows
  /// come before the layouts and views that mention them.
  ///
  /// `quitting` is never among them: that the controller stopped does not say that Arbor is quitting. Whoever
  /// knows that it is says so (`EventFeed.stop`).
  public static func changes(from old: Summary, to new: Summary) -> [ArborEvent] {
    guard new.running else { return old.running && new.paused ? [.paused] : [] }
    var events: [ArborEvent] = old.running ? [] : [old.paused ? .resumed : .started]
    if old.displays != new.displays { events.append(.displays(new.displays)) }

    let before = Dictionary(old.windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let after = Set(new.windows.map(\.id))
    for window in old.windows where !after.contains(window.id) {
      events.append(.window(WindowChange(new.notArranged.contains(window.id) ? .released : .closed, window)))
    }
    for window in new.windows {
      guard let known = before[window.id] else {
        // Only a window that appeared while Arbor was looking is known to have opened.
        let wasThere = !old.running || old.notArranged.contains(window.id)
        events.append(.window(WindowChange(wasThere ? .adopted : .opened, window)))
        // A new window is taken to float, so one that is docked already (by a rule, from last time) is reported as that too.
        if window.docked { events.append(.window(WindowChange(.docked, window))) }
        continue
      }
      if known.docked != window.docked || known.display != window.display {
        events.append(.window(WindowChange(window.docked ? .docked : .floated, window)))
      }
      if known.state != window.state { events.append(.window(WindowChange(.state, window))) }
      if known.title != window.title { events.append(.window(WindowChange(.title, window))) }
    }

    for layout in new.layouts where !old.layouts.contains(layout) { events.append(.layout(layout)) }
    for view in new.views where !old.views.contains(view) { events.append(.view(view)) }
    if old.focus != new.focus { events.append(.focus(new.focus)) }
    return events
  }

  // MARK: Lines

  public static let protocolVersion = 1

  /// The event as its line of JSON, without the newline. `event` comes first, so that
  /// `grep '^{"event":"view"'` works where `jq` is not at hand; the other keys are sorted.
  public var line: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let head = "{\"event\":\"\(kind.rawValue)\""
    guard let payload, let data = try? encoder.encode(payload) else { return head + "}" }
    let fields = String(decoding: data, as: UTF8.self).dropFirst()
    return fields == "}" ? head + "}" : head + "," + fields
  }

  /// The fields beside `event`, as something that encodes to a JSON object.
  private var payload: (any Encodable)? {
    switch self {
    case .hello(let hello): hello
    case .displays(let displays): DisplayList(displays: displays)
    case .window(let change): change
    case .layout(let arrangement): arrangement
    case .view(let view): view
    case .focus(let focus): focus
    case .settings(let changed): ChangedKeys(changed: changed)
    case .started, .quitting, .paused, .resumed: nil
    }
  }

  private struct DisplayList: Codable {
    var displays: [Display]
  }

  private struct ChangedKeys: Codable {
    var changed: [String]
  }

  /// Reads a line back; for clients written in Swift, such as the end-to-end runner.
  public init(line: String) throws {
    self = try JSONDecoder().decode(ArborEvent.self, from: Data(line.utf8))
  }
}

extension ArborEvent: Codable {
  private enum CodingKeys: String, CodingKey { case event }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(kind, forKey: .event)
    try payload?.encode(to: encoder)
  }

  public init(from decoder: any Decoder) throws {
    switch try decoder.container(keyedBy: CodingKeys.self).decode(Kind.self, forKey: .event) {
    case .hello: self = .hello(try Hello(from: decoder))
    case .displays: self = .displays(try DisplayList(from: decoder).displays)
    case .window: self = .window(try WindowChange(from: decoder))
    case .layout: self = .layout(try Arrangement(from: decoder))
    case .view: self = .view(try View(from: decoder))
    case .focus: self = .focus(try Focus(from: decoder))
    case .settings: self = .settings(changed: try ChangedKeys(from: decoder).changed)
    case .started: self = .started
    case .quitting: self = .quitting
    case .paused: self = .paused
    case .resumed: self = .resumed
    }
  }
}

extension Settings {
  /// The names of the keys of settings.json whose values differ between `self` and `other`, sorted.
  public func keysThatDiffer(from other: Settings) -> [String] {
    func values(_ settings: Settings) -> [String: Data] {
      guard let data = try? JSONEncoder().encode(settings),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
      else { return [:] }
      // Each value as canonical JSON, wrapped because a bare number is not a document everywhere.
      return object.compactMapValues { try? JSONSerialization.data(withJSONObject: [$0], options: [.sortedKeys]) }
    }
    let (mine, theirs) = (values(self), values(other))
    return Set(mine.keys).union(theirs.keys).filter { mine[$0] != theirs[$0] }.sorted()
  }
}

/// What a client of `watch` asked for.
public struct WatchOptions: Codable, Equatable, Sendable {
  /// The kinds of event to send, in `Kind`'s order and without repeats; empty means all of them.
  public private(set) var kinds: [ArborEvent.Kind]
  /// Whether events may carry window titles.
  public var titles: Bool

  public init(kinds: [ArborEvent.Kind] = [], titles: Bool = false) {
    self.kinds = Set(kinds).sorted()
    self.titles = titles
  }

  public func includes(_ kind: ArborEvent.Kind) -> Bool {
    kinds.isEmpty || kind.isAlwaysSent || kinds.contains(kind)
  }
}
