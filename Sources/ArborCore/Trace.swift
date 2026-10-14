import CoreGraphics

// A trace is a recording of everything that crossed the seams between Arbor's logic and macOS: window
// events, the calls the controller made and what came back, commands, overlay actions and scheduled
// work. Whoever has a Mac records one (`arborctl trace on`); from then on anyone can replay it against the
// real controller, on any platform (`TraceReplayer` in ArborTesting, `arbor-sim replay`).
//
// This file is the format: one JSON object per line, a header and then entries. docs/TRACES.md describes
// it for readers of the files. Turning values into text and back needs Foundation, so that part is
// in ArborKit (`Trace/TraceFile.swift`).

/// What the `trace` command does.
public enum TraceCommand: Equatable, Sendable, Codable {
  /// Starts recording to `<Arbor home>/traces/<date>-<name>.jsonl`.
  case on(name: String?)
  case off
  case status
  /// Writes a remark into the trace being recorded, e.g. what the person is about to do.
  case note(String)

  /// Names become part of a file name, so they are letters, digits, dots, dashes and underscores.
  public static func isValidName(_ name: String) -> Bool {
    !name.isEmpty && name.count <= 40
      && name.unicodeScalars.allSatisfy { scalar in
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || ("0"..."9").contains(scalar)
          || scalar == "." || scalar == "-" || scalar == "_"
      }
  }
}

// MARK: Windows and displays

/// A window as a trace records it. The title is never the real one: see `TitleTokens`.
public struct TraceWindow: Equatable, Sendable {
  public var id: WindowID
  public var pid: Int32
  public var bundle: String?
  public var app: String
  public var title: String
  public var frame: CGRect
  public var minimized: Bool
  public var hidden: Bool
  /// On a Space that is not showing.
  public var offSpace: Bool
  /// In macOS's own full screen.
  public var fullScreen: Bool
  /// Its size cannot be changed at all.
  public var fixedSize: Bool

  public init(
    id: WindowID, pid: Int32, bundle: String?, app: String, title: String, frame: CGRect,
    minimized: Bool = false, hidden: Bool = false, offSpace: Bool = false, fullScreen: Bool = false,
    fixedSize: Bool = false
  ) {
    self.id = id
    self.pid = pid
    self.bundle = bundle
    self.app = app
    self.title = title
    self.frame = frame
    self.minimized = minimized
    self.hidden = hidden
    self.offSpace = offSpace
    self.fullScreen = fullScreen
    self.fixedSize = fixedSize
  }
}

extension TraceWindow: Codable {
  private enum CodingKeys: String, CodingKey {
    case id, pid, bundle, app, title, frame, minimized, hidden, offSpace, fullScreen, fixedSize
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(WindowID.self, forKey: .id)
    pid = try c.decode(Int32.self, forKey: .pid)
    bundle = try c.decodeIfPresent(String.self, forKey: .bundle)
    app = try c.decode(String.self, forKey: .app)
    title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    frame = try c.decode(TraceRect.self, forKey: .frame).rect
    minimized = try c.decodeIfPresent(Bool.self, forKey: .minimized) ?? false
    hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    offSpace = try c.decodeIfPresent(Bool.self, forKey: .offSpace) ?? false
    fullScreen = try c.decodeIfPresent(Bool.self, forKey: .fullScreen) ?? false
    fixedSize = try c.decodeIfPresent(Bool.self, forKey: .fixedSize) ?? false
  }

  /// Flags are written only when set: most lines are about ordinary windows.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(pid, forKey: .pid)
    try c.encodeIfPresent(bundle, forKey: .bundle)
    try c.encode(app, forKey: .app)
    try c.encode(title, forKey: .title)
    try c.encode(TraceRect(frame), forKey: .frame)
    if minimized { try c.encode(true, forKey: .minimized) }
    if hidden { try c.encode(true, forKey: .hidden) }
    if offSpace { try c.encode(true, forKey: .offSpace) }
    if fullScreen { try c.encode(true, forKey: .fullScreen) }
    if fixedSize { try c.encode(true, forKey: .fixedSize) }
  }
}

public struct TraceDisplay: Equatable, Sendable {
  public var id: DisplayID
  public var frame: CGRect
  public var visible: CGRect
  public var main: Bool
  /// Never the display's real name, which can be a person's ("Robin's iPad"): a stand-in, or nothing. `displays` in
  /// settings.json can go by a display's name.
  public var name: String
  public var builtIn: Bool

  /// Its picture is shown on another display as well. Arbor holds still meanwhile (K160), so a replay has to know.
  public var mirrored: Bool

  public init(
    id: DisplayID, frame: CGRect, visible: CGRect, main: Bool, name: String = "", builtIn: Bool = false, mirrored: Bool = false
  ) {
    self.id = id
    self.frame = frame
    self.visible = visible
    self.main = main
    self.name = name
    self.builtIn = builtIn
    self.mirrored = mirrored
  }
}

extension TraceDisplay: Codable {
  private enum CodingKeys: String, CodingKey { case id, frame, visible, main, name, builtIn, mirrored }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(DisplayID.self, forKey: .id)
    frame = try c.decode(TraceRect.self, forKey: .frame).rect
    visible = try c.decode(TraceRect.self, forKey: .visible).rect
    main = try c.decodeIfPresent(Bool.self, forKey: .main) ?? false
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    builtIn = try c.decodeIfPresent(Bool.self, forKey: .builtIn) ?? false
    mirrored = try c.decodeIfPresent(Bool.self, forKey: .mirrored) ?? false
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(TraceRect(frame), forKey: .frame)
    try c.encode(TraceRect(visible), forKey: .visible)
    if main { try c.encode(true, forKey: .main) }
    if !name.isEmpty { try c.encode(name, forKey: .name) }
    if builtIn { try c.encode(true, forKey: .builtIn) }
    if mirrored { try c.encode(true, forKey: .mirrored) }
  }
}

// MARK: Geometry

/// Hundredths of a point are far below anything a window can show, and keep lines short. A value that is
/// not finite cannot be written as JSON and means nothing on a screen.
private func traceNumber(_ value: CGFloat) -> Double {
  let value = Double(value)
  return value.isFinite ? (value * 100).rounded() / 100 : 0
}

/// A rectangle written as `[x, y, width, height]`.
struct TraceRect: Codable {
  var rect: CGRect

  init(_ rect: CGRect) { self.rect = rect }

  init(from decoder: any Decoder) throws {
    let numbers = try decoder.singleValueContainer().decode([Double].self)
    guard numbers.count == 4 else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "expected [x, y, width, height]"))
    }
    rect = CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    // Not minX and width: those standardise a null rectangle's infinite origin into more infinities.
    try container.encode([
      traceNumber(rect.origin.x), traceNumber(rect.origin.y), traceNumber(rect.size.width),
      traceNumber(rect.size.height),
    ])
  }
}

/// A point or a size written as `[x, y]` or `[width, height]`.
struct TracePair: Codable {
  var first: CGFloat
  var second: CGFloat

  init(_ point: CGPoint) {
    first = point.x
    second = point.y
  }

  init(_ size: CGSize) {
    first = size.width
    second = size.height
  }

  var point: CGPoint { CGPoint(x: first, y: second) }
  var size: CGSize { CGSize(width: first, height: second) }

  init(from decoder: any Decoder) throws {
    let numbers = try decoder.singleValueContainer().decode([Double].self)
    guard numbers.count == 2 else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "expected two numbers"))
    }
    first = CGFloat(numbers[0])
    second = CGFloat(numbers[1])
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode([traceNumber(first), traceNumber(second)])
  }
}

// MARK: Header

/// The first line of a trace: the world and what Arbor knew when recording started, enough to build
/// both again, so that a trace needs nothing but itself.
public struct TraceHeader: Equatable, Sendable {
  /// The newest format this code reads and the one it writes.
  public static let currentVersion = 1

  /// The format's version.
  public var trace: Int = TraceHeader.currentVersion
  public var name: String
  /// Arbor's version, or `dev` for a build that is not a bundle.
  public var arbor: String
  /// The operating system, as it describes itself.
  public var os: String
  /// When recording started (ISO 8601, UTC).
  public var recorded: String
  public var displays: [TraceDisplay]
  /// Every window the window system knew, arranged by Arbor or not.
  public var windows: [TraceWindow]
  /// The settings in effect, with the title patterns of rules replaced (`TitleTokens`).
  public var settings: Settings
  public var workspaces: [DisplayID: Workspace]
  /// Workspaces of displays that were not connected.
  public var dormant: [DisplayID: Workspace] = [:]
  public var parked: [WindowID] = []
  /// Sizes Arbor had learned that apps refuse to go below.
  public var minimumSizes: [WindowID: CGSize] = [:]
  /// How small and how large Arbor had seen each window, which decides whom it asks before it moves anybody.
  public var seenSizes: [WindowID: SeenSizes] = [:]
  /// Where their apps opened the windows that nobody has moved since: no place anybody chose, so Arbor may move them.
  public var appPlaced: [WindowID: CGRect] = [:]
  /// Most recently focused first.
  public var focusHistory: [WindowID] = []
  /// `ARBOR_ONLY_PIDS`, when Arbor was limited to some processes.
  public var onlyPIDs: [Int32]?
  /// Windows an `ignore` rule had matched.
  public var ignored: [WindowID] = []
  public var focused: WindowID?
  public var cursor: CGPoint
  public var mouseDown: Bool
  /// High-frequency lines closer together than this many seconds were thinned (docs/TRACES.md).
  public var thinning: Double

  public init(
    name: String, arbor: String, os: String, recorded: String, displays: [TraceDisplay],
    windows: [TraceWindow], settings: Settings, workspaces: [DisplayID: Workspace], focused: WindowID?,
    cursor: CGPoint, mouseDown: Bool, thinning: Double
  ) {
    self.name = name
    self.arbor = arbor
    self.os = os
    self.recorded = recorded
    self.displays = displays
    self.windows = windows
    self.settings = settings
    self.workspaces = workspaces
    self.focused = focused
    self.cursor = cursor
    self.mouseDown = mouseDown
    self.thinning = thinning
  }
}

extension TraceHeader: Codable {
  private enum CodingKeys: String, CodingKey {
    case trace, name, arbor, os, recorded, displays, windows, settings, workspaces, dormant, parked
    case minimumSizes, focusHistory, onlyPIDs, ignored, focused, cursor, mouseDown, thinning, appPlaced, seenSizes
  }

  /// Only what a replay cannot do without is required, so that hand-written traces can be short.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    trace = try c.decode(Int.self, forKey: .trace)
    name = try c.decodeIfPresent(String.self, forKey: .name) ?? "trace"
    arbor = try c.decodeIfPresent(String.self, forKey: .arbor) ?? "unknown"
    os = try c.decodeIfPresent(String.self, forKey: .os) ?? "unknown"
    recorded = try c.decodeIfPresent(String.self, forKey: .recorded) ?? ""
    displays = try c.decode([TraceDisplay].self, forKey: .displays)
    windows = try c.decodeIfPresent([TraceWindow].self, forKey: .windows) ?? []
    settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
    workspaces = try c.decodeIfPresent([DisplayID: Workspace].self, forKey: .workspaces) ?? [:]
    dormant = try c.decodeIfPresent([DisplayID: Workspace].self, forKey: .dormant) ?? [:]
    parked = try c.decodeIfPresent([WindowID].self, forKey: .parked) ?? []
    appPlaced = (try c.decodeIfPresent([WindowID: TraceRect].self, forKey: .appPlaced) ?? [:]).mapValues(\.rect)
    minimumSizes = (try c.decodeIfPresent([WindowID: TracePair].self, forKey: .minimumSizes) ?? [:])
      .mapValues(\.size)
    // The least, the most, where it stopped growing, the offer it came close to and what it took of that.
    seenSizes = (try c.decodeIfPresent([WindowID: [TracePair]].self, forKey: .seenSizes) ?? [:]).compactMapValues {
      guard $0.count == 5 else { return nil }
      return SeenSizes(least: $0[0].size, most: $0[1].size, stoppedAt: $0[2].size, closeOffer: $0[3].size, closeTook: $0[4].size)
    }
    focusHistory = try c.decodeIfPresent([WindowID].self, forKey: .focusHistory) ?? []
    onlyPIDs = try c.decodeIfPresent([Int32].self, forKey: .onlyPIDs)
    ignored = try c.decodeIfPresent([WindowID].self, forKey: .ignored) ?? []
    focused = try c.decodeIfPresent(WindowID.self, forKey: .focused)
    cursor = try c.decodeIfPresent(TracePair.self, forKey: .cursor)?.point ?? .zero
    mouseDown = try c.decodeIfPresent(Bool.self, forKey: .mouseDown) ?? false
    thinning = try c.decodeIfPresent(Double.self, forKey: .thinning) ?? 0
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(trace, forKey: .trace)
    try c.encode(name, forKey: .name)
    try c.encode(arbor, forKey: .arbor)
    try c.encode(os, forKey: .os)
    try c.encode(recorded, forKey: .recorded)
    try c.encode(displays, forKey: .displays)
    try c.encode(windows, forKey: .windows)
    try c.encode(settings, forKey: .settings)
    try c.encode(workspaces, forKey: .workspaces)
    if !dormant.isEmpty { try c.encode(dormant, forKey: .dormant) }
    if !parked.isEmpty { try c.encode(parked, forKey: .parked) }
    if !minimumSizes.isEmpty { try c.encode(minimumSizes.mapValues { TracePair($0) }, forKey: .minimumSizes) }
    if !seenSizes.isEmpty {
      try c.encode(
        seenSizes.mapValues { [$0.least, $0.most, $0.stoppedAt, $0.closeOffer, $0.closeTook].map { TracePair($0) } }, forKey: .seenSizes)
    }
    if !appPlaced.isEmpty { try c.encode(appPlaced.mapValues { TraceRect($0) }, forKey: .appPlaced) }
    if !focusHistory.isEmpty { try c.encode(focusHistory, forKey: .focusHistory) }
    try c.encodeIfPresent(onlyPIDs, forKey: .onlyPIDs)
    if !ignored.isEmpty { try c.encode(ignored, forKey: .ignored) }
    try c.encodeIfPresent(focused, forKey: .focused)
    try c.encode(TracePair(cursor), forKey: .cursor)
    try c.encode(mouseDown, forKey: .mouseDown)
    try c.encode(thinning, forKey: .thinning)
  }
}

// MARK: Lines

/// Any JSON value: the arguments and results of lines that have no case of their own.
public enum TraceJSON: Equatable, Sendable, Codable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([TraceJSON])
  case object([String: TraceJSON])

  public init(from decoder: any Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() {
      self = .null
    } else if let value = try? c.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? c.decode(Double.self) {
      self = .number(value)
    } else if let value = try? c.decode(String.self) {
      self = .string(value)
    } else if let value = try? c.decode([TraceJSON].self) {
      self = .array(value)
    } else {
      self = .object(try c.decode([String: TraceJSON].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .null: try c.encodeNil()
    case .bool(let value): try c.encode(value)
    case .number(let value): try c.encode(value.isFinite ? value : 0)
    case .string(let value): try c.encode(value)
    case .array(let value): try c.encode(value)
    case .object(let value): try c.encode(value)
    }
  }

  /// This value with `change` applied to every piece of text in it, keys excepted.
  public func mapStrings(_ change: (String) -> String) -> TraceJSON {
    switch self {
    case .string(let value): .string(change(value))
    case .array(let values): .array(values.map { $0.mapStrings(change) })
    case .object(let values): .object(values.mapValues { $0.mapStrings(change) })
    default: self
    }
  }
}

extension TraceJSON: CustomStringConvertible {
  public var description: String {
    switch self {
    case .null: "null"
    case .bool(let value): "\(value)"
    case .number(let value): traceText(CGFloat(value))
    case .string(let value): "\"\(value)\""
    case .array(let values): "[" + values.map(\.description).joined(separator: ", ") + "]"
    case .object(let values):
      "{" + values.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + "}"
    }
  }
}

/// One thing that crossed a seam.
public enum TraceLine: Equatable, Sendable {
  // What the window system told Arbor (`WindowSystemEvents`).
  case appeared(TraceWindow)
  case destroyed(WindowID)
  case changed(TraceWindow, user: Bool)
  case focused(WindowID)
  case dragBegan(WindowID, at: CGPoint)
  case dragMoved(WindowID, to: CGPoint)
  case dragEnded(WindowID, at: CGPoint)
  case resizeBegan(WindowID)
  case resizeEnded(WindowID)
  /// With the displays there are from now on.
  case displaysChanged([TraceDisplay])
  case keyboardFocusMoved

  // What Arbor asked of the window system (`WindowSystem`), and the answer.
  /// `took` is how long the call lasted in seconds, when that is a millisecond or more.
  case setFrame(WindowID, CGRect, result: CGRect?, took: Double?)
  case focus(WindowID)
  case focusedWindow(WindowID?)
  case cursorLocation(CGPoint)
  case isMouseButtonDown(Bool)
  case allWindows([TraceWindow])
  case displays([TraceDisplay])
  case start
  case stop
  /// A call on the overlays (`OverlayPresenter`). Scenes are not recorded.
  case showDropPreview(CGRect?)

  /// A command is about to be performed. `from` is where it came from, if whoever asked said so: a shortcut and a script
  /// can mean different displays by the same words (F56).
  case command(String, from: CommandSource? = nil)
  /// The command has been performed. A message that begins with `aboutMark` is what was said, but not what a replay will say.
  case done(String, ok: Bool, message: String)

  // What the user did with an overlay (`OverlayActions`).
  case tileActivated(display: DisplayID, node: NodeID)
  case seamDragged(display: DisplayID, seam: Seam, by: CGFloat)

  /// Work scheduled under this key is about to run (`Scheduler`).
  case timer(String)
  /// These settings are about to be applied.
  case settings(Settings)
  /// What macOS sent before the window system made events of it: an Accessibility notification with its window, or a
  /// mouse event with the pointer's place. For people; replays skip it.
  case raw(String)
  case note(String)
  /// The last line: why recording stopped, how many lines were written before this one and how many
  /// were thinned away.
  case end(reason: String, lines: Int, thinned: Int)
  /// Something that crossed a seam and has no case of its own above: a requirement added to a protocol since, recorded by name with
  /// its arguments and its result as plain JSON (`TraceRecorder.read`, `call`, `event`, `action`). Also what a line from a newer
  /// Arbor is read as, so nothing of it is lost.
  case other(Other, String, arguments: [TraceJSON] = [], result: TraceJSON? = nil)
  /// A line that says nothing about what kind it is. Replays skip it.
  case unknown(String)

  public enum Other: String, Sendable {
    /// The window system reported something.
    case event
    /// The user did something with an overlay.
    case action
    /// Arbor asked for something that changes what a person can see. A strict replay must make the same call.
    case call
    /// Arbor asked a question.
    case read
  }
}

extension TraceLine {
  /// Begins the message of a `done` line whose words a replay cannot give back, because what was typed had to be replaced by something
  /// that does not stand for quite the same. Strict replays then compare only whether the command succeeded.
  public static let aboutMark = "≈ "

  /// Something Arbor reacts to. A replay delivers these; everything else is Arbor's own doing or a remark.
  public var isStimulus: Bool {
    switch self {
    case .appeared, .destroyed, .changed, .focused, .dragBegan, .dragMoved, .dragEnded, .resizeBegan,
      .resizeEnded, .displaysChanged, .keyboardFocusMoved, .command, .tileActivated, .seamDragged, .timer, .settings:
      true
    case .other(let kind, _, _, _): kind == .event || kind == .action
    default: false
    }
  }

  /// Something the window system reported. Unlike other stimuli, one of these that arrives in the middle of Arbor's
  /// reaction to something else does not happen again by itself in a replay.
  public var isEvent: Bool {
    switch self {
    case .appeared, .destroyed, .changed, .focused, .dragBegan, .dragMoved, .dragEnded, .resizeBegan, .resizeEnded,
      .displaysChanged, .keyboardFocusMoved, .other(.event, _, _, _):
      true
    default: false
    }
  }

  /// A call that changes something a person can see. A strict replay must make the same ones.
  public var isEffect: Bool {
    switch self {
    case .setFrame, .focus, .showDropPreview, .other(.call, _, _, _): true
    default: false
    }
  }

  /// The window a line is about, if it is about one.
  public var window: WindowID? {
    switch self {
    case .appeared(let window), .changed(let window, _): window.id
    case .destroyed(let id), .focused(let id), .dragBegan(let id, _), .dragMoved(let id, _), .dragEnded(let id, _),
      .resizeBegan(let id), .resizeEnded(let id), .setFrame(let id, _, _, _), .focus(let id):
      id
    default: nil
    }
  }
}

extension TraceLine: Codable {
  /// All lines share one flat set of keys. Those in the first row say what kind of line it is.
  private enum CodingKeys: String, CodingKey {
    case event, call, read, command, done, action, timer, settings, raw, note, end
    case id, window, user, point, to, frame, result, took, ok, message, display, node, seam, by, lines, thinned, args, from
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    func id() throws -> WindowID { try c.decode(WindowID.self, forKey: .id) }
    func point() throws -> CGPoint { try c.decode(TracePair.self, forKey: .point).point }
    func other(_ kind: Other, _ name: String) throws -> TraceLine {
      .other(
        kind, name, arguments: try c.decodeIfPresent([TraceJSON].self, forKey: .args) ?? [],
        // A result of null is a result; no result at all is none.
        result: c.contains(.result) ? try c.decode(TraceJSON.self, forKey: .result) : nil)
    }

    if let event = try c.decodeIfPresent(String.self, forKey: .event) {
      switch event {
      case "appeared": self = .appeared(try c.decode(TraceWindow.self, forKey: .window))
      case "destroyed": self = .destroyed(try id())
      case "changed":
        self = .changed(try c.decode(TraceWindow.self, forKey: .window), user: try c.decode(Bool.self, forKey: .user))
      case "focused": self = .focused(try id())
      case "dragBegan": self = .dragBegan(try id(), at: try point())
      case "dragMoved": self = .dragMoved(try id(), to: try point())
      case "dragEnded": self = .dragEnded(try id(), at: try point())
      case "resizeBegan": self = .resizeBegan(try id())
      case "resizeEnded": self = .resizeEnded(try id())
      case "displaysChanged": self = .displaysChanged(try c.decode([TraceDisplay].self, forKey: .to))
      case "keyboardFocusMoved": self = .keyboardFocusMoved
      default: self = try other(.event, event)
      }
    } else if let call = try c.decodeIfPresent(String.self, forKey: .call) {
      switch call {
      case "setFrame":
        self = .setFrame(
          try id(), try c.decode(TraceRect.self, forKey: .frame).rect,
          result: try c.decodeIfPresent(TraceRect.self, forKey: .result)?.rect,
          took: try c.decodeIfPresent(Double.self, forKey: .took))
      case "focus": self = .focus(try id())
      case "focusedWindow": self = .focusedWindow(try c.decodeIfPresent(WindowID.self, forKey: .result))
      case "cursorLocation": self = .cursorLocation(try c.decode(TracePair.self, forKey: .result).point)
      case "isMouseButtonDown": self = .isMouseButtonDown(try c.decode(Bool.self, forKey: .result))
      case "allWindows": self = .allWindows(try c.decode([TraceWindow].self, forKey: .result))
      case "displays": self = .displays(try c.decode([TraceDisplay].self, forKey: .result))
      case "start": self = .start
      case "stop": self = .stop
      case "showDropPreview": self = .showDropPreview(try c.decodeIfPresent(TraceRect.self, forKey: .frame)?.rect)
      default: self = try other(.call, call)
      }
    } else if let name = try c.decodeIfPresent(String.self, forKey: .read) {
      self = try other(.read, name)
    } else if let text = try c.decodeIfPresent(String.self, forKey: .command) {
      self = .command(text, from: try c.decodeIfPresent(String.self, forKey: .from).flatMap(CommandSource.init(rawValue:)))
    } else if let text = try c.decodeIfPresent(String.self, forKey: .done) {
      self = .done(
        text, ok: try c.decode(Bool.self, forKey: .ok),
        message: try c.decodeIfPresent(String.self, forKey: .message) ?? "")
    } else if let action = try c.decodeIfPresent(String.self, forKey: .action) {
      switch action {
      case "tileActivated":
        self = .tileActivated(
          display: try c.decode(DisplayID.self, forKey: .display), node: try c.decode(NodeID.self, forKey: .node))
      case "seamDragged":
        self = .seamDragged(
          display: try c.decode(DisplayID.self, forKey: .display), seam: try c.decode(Seam.self, forKey: .seam),
          by: CGFloat(try c.decode(Double.self, forKey: .by)))
      default: self = try other(.action, action)
      }
    } else if let key = try c.decodeIfPresent(String.self, forKey: .timer) {
      self = .timer(key)
    } else if let settings = try c.decodeIfPresent(Settings.self, forKey: .settings) {
      self = .settings(settings)
    } else if let text = try c.decodeIfPresent(String.self, forKey: .raw) {
      self = .raw(text)
    } else if let text = try c.decodeIfPresent(String.self, forKey: .note) {
      self = .note(text)
    } else if let reason = try c.decodeIfPresent(String.self, forKey: .end) {
      self = .end(
        reason: reason, lines: try c.decodeIfPresent(Int.self, forKey: .lines) ?? 0,
        thinned: try c.decodeIfPresent(Int.self, forKey: .thinned) ?? 0)
    } else {
      self = .unknown("line")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    func event(_ name: String, _ id: WindowID? = nil, _ point: CGPoint? = nil) throws {
      try c.encode(name, forKey: .event)
      try c.encodeIfPresent(id, forKey: .id)
      try c.encodeIfPresent(point.map { TracePair($0) }, forKey: .point)
    }
    /// An answer of "nothing" is written as null, so that a reader sees it was given.
    func optional<T: Encodable>(_ value: T?, _ key: CodingKeys) throws {
      if let value { try c.encode(value, forKey: key) } else { try c.encodeNil(forKey: key) }
    }

    switch self {
    case .appeared(let window):
      try event("appeared")
      try c.encode(window, forKey: .window)
    case .destroyed(let id): try event("destroyed", id)
    case .changed(let window, let user):
      try event("changed")
      try c.encode(user, forKey: .user)
      try c.encode(window, forKey: .window)
    case .focused(let id): try event("focused", id)
    case .dragBegan(let id, let point): try event("dragBegan", id, point)
    case .dragMoved(let id, let point): try event("dragMoved", id, point)
    case .dragEnded(let id, let point): try event("dragEnded", id, point)
    case .resizeBegan(let id): try event("resizeBegan", id)
    case .resizeEnded(let id): try event("resizeEnded", id)
    case .displaysChanged(let displays):
      try event("displaysChanged")
      try c.encode(displays, forKey: .to)
    case .keyboardFocusMoved: try event("keyboardFocusMoved")

    case .setFrame(let id, let frame, let result, let took):
      try c.encode("setFrame", forKey: .call)
      try c.encode(id, forKey: .id)
      try c.encode(TraceRect(frame), forKey: .frame)
      try optional(result.map { TraceRect($0) }, .result)
      try c.encodeIfPresent(took, forKey: .took)
    case .focus(let id):
      try c.encode("focus", forKey: .call)
      try c.encode(id, forKey: .id)
    case .focusedWindow(let id):
      try c.encode("focusedWindow", forKey: .call)
      try optional(id, .result)
    case .cursorLocation(let point):
      try c.encode("cursorLocation", forKey: .call)
      try c.encode(TracePair(point), forKey: .result)
    case .isMouseButtonDown(let down):
      try c.encode("isMouseButtonDown", forKey: .call)
      try c.encode(down, forKey: .result)
    case .allWindows(let windows):
      try c.encode("allWindows", forKey: .call)
      try c.encode(windows, forKey: .result)
    case .displays(let displays):
      try c.encode("displays", forKey: .call)
      try c.encode(displays, forKey: .result)
    case .start: try c.encode("start", forKey: .call)
    case .stop: try c.encode("stop", forKey: .call)
    case .showDropPreview(let frame):
      try c.encode("showDropPreview", forKey: .call)
      try optional(frame.map { TraceRect($0) }, .frame)

    case .command(let text, let source):
      try c.encode(text, forKey: .command)
      try c.encodeIfPresent(source?.rawValue, forKey: .from)
    case .done(let text, let ok, let message):
      try c.encode(text, forKey: .done)
      try c.encode(ok, forKey: .ok)
      try c.encode(message, forKey: .message)

    case .tileActivated(let display, let node):
      try c.encode("tileActivated", forKey: .action)
      try c.encode(display, forKey: .display)
      try c.encode(node, forKey: .node)
    case .seamDragged(let display, let seam, let delta):
      try c.encode("seamDragged", forKey: .action)
      try c.encode(display, forKey: .display)
      try c.encode(seam, forKey: .seam)
      try c.encode(traceNumber(delta), forKey: .by)

    case .timer(let key): try c.encode(key, forKey: .timer)
    case .settings(let settings): try c.encode(settings, forKey: .settings)
    case .raw(let text): try c.encode(text, forKey: .raw)
    case .note(let text): try c.encode(text, forKey: .note)
    case .end(let reason, let lines, let thinned):
      try c.encode(reason, forKey: .end)
      try c.encode(lines, forKey: .lines)
      try c.encode(thinned, forKey: .thinned)
    case .other(let kind, let name, let arguments, let result):
      switch kind {
      case .event: try c.encode(name, forKey: .event)
      case .action: try c.encode(name, forKey: .action)
      case .call: try c.encode(name, forKey: .call)
      case .read: try c.encode(name, forKey: .read)
      }
      if !arguments.isEmpty { try c.encode(arguments, forKey: .args) }
      try c.encodeIfPresent(result, forKey: .result)
    case .unknown(let kind): try c.encode("unknown: \(kind)", forKey: .note)
    }
  }
}

/// A line with when it happened.
public struct TraceEntry: Equatable, Sendable, Codable {
  /// Seconds since recording started.
  public var t: Double
  public var line: TraceLine
  /// Arbor was in the middle of reacting to an earlier line when this stimulus arrived. A command, settings or
  /// scheduled work is then Arbor's own doing and happens again by itself in a replay; an event came from inside
  /// a call Arbor was making, and a replay delivers it from inside the same call.
  public var nested: Bool
  /// The line of the file this came from, counting from 1. Not part of the format.
  public var number: Int

  public init(t: Double, line: TraceLine, nested: Bool = false, number: Int = 0) {
    self.t = t
    self.line = line
    self.nested = nested
    self.number = number
  }

  private enum CodingKeys: String, CodingKey { case t, nested }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    t = try c.decode(Double.self, forKey: .t)
    nested = try c.decodeIfPresent(Bool.self, forKey: .nested) ?? false
    line = try TraceLine(from: decoder)
    number = 0
  }

  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(t, forKey: .t)
    if nested { try c.encode(true, forKey: .nested) }
    try line.encode(to: encoder)
  }
}

/// A whole trace.
public struct Trace: Equatable, Sendable {
  public var header: TraceHeader
  public var entries: [TraceEntry]
  /// What a reader should know about the file: a cut-off last line, kinds of line that were skipped.
  public var warnings: [String]

  public init(header: TraceHeader, entries: [TraceEntry], warnings: [String] = []) {
    self.header = header
    self.entries = entries
    self.warnings = warnings
  }
}

// MARK: Reading a line

extension TraceLine: CustomStringConvertible {
  /// The line as a person would say it. Used for `arbor-sim replay` and for reporting divergences.
  public var description: String {
    switch self {
    case .appeared(let window): "\(window.id) appeared: \(window)"
    case .destroyed(let id): "\(id) closed"
    case .changed(let window, let user): "\(window.id) changed (\(user ? "not by Arbor" : "echo")): \(window)"
    case .focused(let id): "\(id) focused"
    case .dragBegan(let id, let point): "drag of \(id) began at \(traceText(point))"
    case .dragMoved(let id, let point): "drag of \(id) moved to \(traceText(point))"
    case .dragEnded(let id, let point): "drag of \(id) ended at \(traceText(point))"
    case .resizeBegan(let id): "edge resize of \(id) began"
    case .resizeEnded(let id): "edge resize of \(id) ended"
    case .displaysChanged(let displays): "displays changed: " + displays.map(\.description).joined(separator: "; ")
    case .keyboardFocusMoved: "the keyboard focus moved"
    case .setFrame(let id, let frame, let result, let took):
      "setFrame \(id) \(traceText(frame))"
        + (result.map { $0.approximatelyEquals(frame, tolerance: 0.5) ? " (taken)" : ", took \(traceText($0))" }
          ?? ", no such window")
        + (took.map { " in \(traceText(CGFloat(($0 * 1000).rounded()))) ms" } ?? "")
    case .focus(let id): "focus \(id)"
    case .focusedWindow(let id): "focusedWindow is \(id.map(\.description) ?? "none")"
    case .cursorLocation(let point): "cursorLocation is \(traceText(point))"
    case .isMouseButtonDown(let down): "isMouseButtonDown is \(down)"
    case .allWindows(let windows): "allWindows is \(windows.map(\.id.description).joined(separator: " "))"
    case .displays(let displays): "displays is " + displays.map(\.description).joined(separator: "; ")
    case .start: "start"
    case .stop: "stop"
    case .showDropPreview(let frame): "showDropPreview \(frame.map(traceText) ?? "off")"
    case .command(let text, let source): "command `\(text)`" + (source.map { " (\($0.rawValue))" } ?? "")
    case .done(let text, let ok, let message): "`\(text)` \(ok ? "succeeded" : "failed"): \(message)"
    case .tileActivated(let display, let node): "tile \(node) clicked on \(display)"
    case .seamDragged(let display, let seam, let delta):
      "seam between \(seam.leading) and \(seam.trailing) dragged by \(traceText(delta)) on \(display)"
    case .timer(let key): "scheduled work `\(key)` runs"
    case .settings: "settings applied"
    case .raw(let text): "macOS: \(text)"
    case .note(let text): text
    case .end(let reason, let lines, let thinned): "recording ended: \(reason) (\(lines) lines, \(thinned) thinned away)"
    case .other(_, let name, let arguments, let result):
      name + (arguments.isEmpty ? "" : " " + arguments.map(\.description).joined(separator: " "))
        + (result.map { " is \($0)" } ?? "")
    case .unknown(let kind): "unknown \(kind)"
    }
  }
}

extension TraceWindow: CustomStringConvertible {
  public var description: String {
    var text = "\(app) \(traceText(frame))"
    if minimized { text += " minimized" }
    if hidden { text += " hidden" }
    if offSpace { text += " on another Space" }
    if fullScreen { text += " full screen" }
    if fixedSize { text += " of a fixed size" }
    return text
  }
}

extension TraceDisplay: CustomStringConvertible {
  public var description: String {
    "\(id) \(traceText(frame)), visible \(traceText(visible))" + (main ? ", main" : "") + (mirrored ? ", mirrored" : "")
  }
}

/// `12` or `12.5`: whole numbers without a fraction, others to a tenth.
public func traceText(_ value: CGFloat) -> String {
  let tenths = (Double(value) * 10).rounded() / 10
  guard tenths.isFinite, abs(tenths) < 1e9 else { return "\(tenths)" }
  return tenths == tenths.rounded() ? String(Int(tenths)) : String(tenths)
}

public func traceText(_ point: CGPoint) -> String { "\(traceText(point.x)),\(traceText(point.y))" }

/// `12,43 325×650`
public func traceText(_ rect: CGRect) -> String {
  "\(traceText(rect.origin.x)),\(traceText(rect.origin.y)) \(traceText(rect.size.width))×\(traceText(rect.size.height))"
}

// MARK: Titles

/// Window titles say what people are reading and writing, so a trace never holds one. Each distinct
/// title becomes `title[1]`, `title[2]`… in the order they were first seen, which keeps what Arbor does with
/// titles replayable: the same title gets the same token, so re-matching windows by title works.
///
/// Rules can ask for text in a title (`AppRule.title`), and that text is part of a title too. Each
/// distinct pattern becomes `[p1]`, `[p2]`…, and a title's token ends with the marks of the patterns it
/// contains (`title[3][p1]`), so a replayed rule matches exactly the windows the real one matched.
public struct TitleTokens: Sendable {
  private var titles: [String: Int] = [:]
  /// Lower-cased, as rules compare them.
  private var patterns: [(text: String, mark: String)] = []
  /// The numbers of the names of spaces, by `SpaceName.key`, and of every way they have been written.
  private var names: [String: Int] = [:]
  private var spellings: [String: Int] = [:]

  public init() {}

  /// An empty title gives nothing away and stays empty.
  public mutating func token(for title: String) -> String {
    guard !title.isEmpty else { return "" }
    let number: Int
    if let known = titles[title] {
      number = known
    } else {
      number = titles.count + 1
      titles[title] = number
    }
    let lowercased = title.lowercased()
    // The comparison `AppRule.matches` makes.
    let marks = patterns.filter { lowercased.firstRange(of: $0.text) != nil }.map(\.mark)
    // The number is closed in, like a mark's, so that no token is contained in another (`title-1` was in `title-10`).
    return "title[\(number)]" + marks.joined()
  }

  /// `settings` with the title pattern of every rule replaced by its mark, and that of every entry of `holdStillFor`, which
  /// matches as a rule does (`HoldPattern`). Those are `[h1]`, `[h2]`…, so that the rules' are numbered as they always were.
  public mutating func sanitised(_ settings: Settings) -> Settings {
    var settings = settings
    settings.rules = settings.rules.map { rule in
      guard let title = rule.title, !title.isEmpty else { return rule }
      return AppRule(app: rule.app, title: mark(for: title.lowercased()), action: rule.action)
    }
    settings.holdStillFor = settings.holdStillFor.map { entry in
      let pattern = HoldPattern(entry)
      guard let title = pattern.title else { return entry }
      return "\(pattern.app) \(mark(for: title.lowercased(), "h"))"
    }
    // A shortcut for `find Inbox` names part of a title as well. A replay does not need it: the line of a shortcut that
    // was pressed says what it ran.
    settings.bindings = settings.bindings.mapValues { text in
      text.map { (try? Command.parse($0))?.textForLog ?? Self.unreadable($0) }
    }
    // An entry of `displays` can go by a part of a display's name, and that can be a person's ("Robin's iPad"). One that goes by a
    // display's id stays: ids are in the trace anyway, and a replay matches by them.
    settings.displays = settings.displays.map { entry in
      guard case .named(let text) = entry.match, !displayIDs.contains(text.lowercased()) else { return entry }
      var entry = entry
      entry.match = .named(displayMark(for: text.lowercased()))
      return entry
    }
    return settings
  }

  /// The ids of the displays there are or have been, lower-cased. Say so before `sanitised`.
  public var displayIDs: Set<String> = []
  private var displayPatterns: [String] = []

  /// The numbers of the names of displays.
  private var displayNames: [String: Int] = [:]

  /// `display-1`, `display-2`… in the order the names were first seen, followed by the marks of the entries of `displays` that go by a part
  /// of this name, as a title's token is by the marks of the rules: `display-1[d1]`. In a replay the display *has* this for a name, so
  /// the same entries match it, and replies that call it by its name come out the same. No name stays no name.
  public mutating func displayToken(for name: String?) -> String {
    guard let name, !name.isEmpty else { return "" }
    displayNames[name] = displayNames[name] ?? displayNames.count + 1
    return displayStandIn(for: name)
  }

  private func displayStandIn(for name: String) -> String {
    let lowercased = name.lowercased()
    // The comparison `DisplayMatch.matches` makes.
    let marks = displayPatterns.indices.filter { lowercased.firstRange(of: displayPatterns[$0]) != nil }.map { "[d\($0 + 1)]" }
    return "display-\(displayNames[name] ?? 0)" + marks.joined()
  }

  private mutating func displayMark(for pattern: String) -> String {
    if let known = displayPatterns.firstIndex(of: pattern) { return "[d\(known + 1)]" }
    displayPatterns.append(pattern)
    return "[d\(displayPatterns.count)]"
  }

  /// `text` with every title seen so far replaced by its token. Commands, their replies and remarks are free text, and nothing
  /// stops a command from taking a title or a reply from quoting one. Titles of fewer than four characters are left: they give
  /// nothing away and are parts of ordinary words. So are the names in `keeping` (the apps'), which many windows have for a title, and
  /// titles that look like tokens, which would be taken for the tokens already put in.
  public func scrubbed(_ text: String, keeping: Set<String> = []) -> String {
    var text = text
    // Longest first, so that a title that contains another goes as a whole.
    for (title, number) in titles.sorted(by: { ($0.key.count, $0.key) > ($1.key.count, $1.key) })
    where title.count >= 4 && !keeping.contains(title) && !title.hasPrefix("title[") && !title.hasPrefix("title-") {
      // The whole token, marks and all: that is the window's title in a replay, so it is what a reply quotes there.
      let lowercased = title.lowercased()
      let token = "title[\(number)]" + patterns.filter { lowercased.firstRange(of: $0.text) != nil }.map(\.mark).joined()
      var scrubbed = ""
      var rest = text[...]
      while let range = rest.firstRange(of: title) {
        scrubbed += rest[..<range.lowerBound] + token
        rest = rest[range.upperBound...]
      }
      text = scrubbed + rest
    }
    return text
  }

  private mutating func mark(for pattern: String, _ letter: String = "p") -> String {
    let alike = patterns.filter { $0.mark.hasPrefix("[" + letter) }
    if let known = alike.first(where: { $0.text == pattern }) { return known.mark }
    let mark = "[\(letter)\(alike.count + 1)]"
    patterns.append((pattern, mark))
    return mark
  }

  /// `settings` without the words people put into the commands of their own shortcuts: `go Clients`, `layout Mail~Payslip | Notes`. A
  /// replay does not need them: the line of a shortcut that was pressed says what it ran. But it reads them, and counts those it cannot
  /// read (`bindings`), so what is written is a command still.
  public mutating func sanitisedBindings(_ settings: Settings) -> Settings {
    var settings = settings
    for (chord, text) in settings.bindings.sorted(by: { $0.key < $1.key }) {
      guard let text else { continue }
      guard let command = try? Command.parse(text) else {
        // A slip of the keyboard in any of the above. The verb is enough to see which.
        settings.bindings.updateValue(Self.unreadable(text), forKey: chord)
        continue
      }
      let shown: String
      switch command {
      // A shortcut can be made to change settings, with the words that takes.
      case .settings(.addRule(let rule)) where rule.title?.isEmpty == false:
        shown = Command.settings(.addRule(AppRule(app: rule.app, title: mark(for: rule.title!.lowercased()), action: rule.action))).text
      case .settings(.changeRule(let number, let rule)) where rule.title?.isEmpty == false:
        shown = Command.settings(.changeRule(number, AppRule(app: rule.app, title: mark(for: rule.title!.lowercased()), action: rule.action))).text
      case .settings(.bind(let inner, let text)):
        // The shortcut it would make, as if it were made.
        var made = Settings()
        made.bindings = ["made": text]
        // (Whatever it is filed under by then: "made" is no shortcut. And never the text itself, should nothing come back.)
        shown = Command.settings(.bind(chord: inner, command: (sanitisedBindings(made).bindings.values.first ?? nil) ?? Self.unreadable(text))).text
      case .find(.some): shown = command.textForLog
      case .name(let name): shown = Command.name(nameToken(for: name)).text
      case .goToSpace(let name): shown = Command.goToSpace(nameToken(for: name)).text
      case .unname(let name?): shown = Command.unname(nameToken(for: name)).text
      // Not `logText`, whose `Mail~…` is for people and cannot be read back.
      case .layout(let spec, let display, let open):
        shown = Command.layout(LayoutNotation.Spec(root: Self.withoutTitles(spec.root)), display: display, open: open).text
      default: continue
      }
      settings.bindings.updateValue(shown, forKey: chord)
    }
    // What stands where the keys should is somebody's slip too. A replay counts the shortcuts it cannot read, so each stays one.
    for (number, chord) in settings.bindings.keys.filter({ (try? KeyChord(text: $0)) == nil }).sorted().enumerated() {
      if let command = settings.bindings.removeValue(forKey: chord) { settings.bindings.updateValue(command, forKey: "…\(number + 1)") }
    }
    return settings
  }

  private static func withoutTitles(_ space: LayoutNotation.Space) -> LayoutNotation.Space {
    switch space.kind {
    case .desktop: space
    case .group(let axis, let members): LayoutNotation.Space(.group(axis, members.map(withoutTitles)), size: space.size)
    case .windows(let slots): LayoutNotation.Space(.windows(slots.map { WindowSlot($0.owner, takesAll: $0.takesAll) }), size: space.size)
    }
  }

  // MARK: The names of spaces (F20)

  /// `name-1`, `name-2`… in the order the names were first seen. A name is a client, a project, a person's own word for something.
  /// Names that differ only in capitals are one name to Arbor and have one token. In a replay the spaces *have* the tokens
  /// for names, so `go name-1` finds the same space.
  public mutating func nameToken(for name: String) -> String {
    let key = SpaceName.key(name)
    let number = names[key] ?? names.count + 1
    names[key] = number
    spellings[name] = number
    return "name-\(number)"
  }

  /// `text` with every name seen so far replaced by its token, where it stands as a word of its own: replies call spaces by
  /// their names and quote what was typed. In one pass from left to right, the longest first, so that "Mail" takes no bite out of
  /// "Mail Room" and a space called "name" none out of a token.
  public func withNameTokens(_ text: String) -> String {
    guard !spellings.isEmpty || !displayNames.isEmpty else { return text }
    let standIns = spellings.map { ($0.key, "name-\($0.value)") } + displayNames.keys.map { ($0, displayStandIn(for: $0)) }
    let known = standIns.sorted { ($0.0.count, $0.0) > ($1.0.count, $1.0) }.map { (Array($0.0), $0.1) }
    let characters = Array(text)
    func isPartOfAWord(_ index: Int) -> Bool {
      characters.indices.contains(index) && (characters[index].isLetter || characters[index].isNumber)
    }
    var result = ""
    var index = 0
    scan: while index < characters.count {
      if !isPartOfAWord(index - 1) {
        for (name, standIn) in known where index + name.count <= characters.count {
          if characters[index..<(index + name.count)].elementsEqual(name), !isPartOfAWord(index + name.count) {
            result += standIn
            index += name.count
            continue scan
          }
        }
      }
      result.append(characters[index])
      index += 1
    }
    return result
  }
}

// MARK: Parts of titles, and typed words, in free text

extension TitleTokens {
  /// A part of a title that a command brings (`rule add … title Payslip`), as `sanitised` meets those that settings bring: it has a mark
  /// from now on, and the token of every title that contains it ends with the mark.
  public mutating func notePartOfATitle(_ part: String) {
    if !part.isEmpty { _ = mark(for: part.lowercased()) }
  }

  /// The text of a command that holds `part`, with the part's mark in its place. Here it is known where the part is from, so it is
  /// taken out as it stands: `withMarks` looks for whole words and never inside a token, and somebody's words can look like one
  /// ("title[1] and more"), which would then shield the rest.
  public mutating func withMark(forPart part: String, inCommand text: String) -> String {
    part.isEmpty ? text : text.replacing(part, with: mark(for: part.lowercased()))
  }

  /// `text` with the parts of titles that rules and `holdStillFor` go by, and the parts of names that `displays` goes by, replaced by their
  /// marks: replies quote them ("title contains "Payslip""). A replay's settings hold the marks, so there the reply comes out the same.
  public func withMarks(_ text: String) -> String {
    let marks = patterns.map { ($0.text, $0.mark) } + displayPatterns.enumerated().map { ($0.element, "[d\($0.offset + 1)]") }
    // Not out of a bundle id, which is no title and is in the trace anyway: `rule add com.apple.[p1] …` would be no command.
    return Self.replacing(marks, in: text, sparingWhatIsWrittenWithDots: true)
  }

  /// What a trace holds of a text that cannot be read as a command. The words in a command are hidden by reading it, each kind in its own
  /// way; what cannot be read cannot be hidden that way, so none of it is written but the verb, if it is one of Arbor's. That a text
  /// cannot be read does not mean that nobody meant it: a name longer than the reader allows, typed into the name field, is a command
  /// built in code, which never went through the reader. What is written is no command either (`name …` would be one, so there the `…`
  /// comes first): a replay stops at it as it stopped at the text itself, and does nothing in its place.
  public static func unreadable(_ text: String) -> String {
    guard let verb = text.split(whereSeparator: \.isWhitespace).first.map({ $0.lowercased() }), Command.isVerb(verb) else { return "…" }
    return (try? Command.parse("\(verb) …")) == nil ? "\(verb) …" : "… \(verb)"
  }

  /// `text` without `words`, whatever their capitals: `…` stands for each.
  public static func without(_ words: Set<String>, in text: String) -> String {
    replacing(words.map { ($0.lowercased(), "…") }, in: text)
  }

  /// The words of `text`: what stands between spaces and punctuation. Numbers are not words.
  public static func words(in text: String) -> Set<String> {
    Set(text.split { !($0.isLetter || $0.isNumber) }.filter { $0.contains(where: \.isLetter) }.map { $0.lowercased() })
  }

  /// Whole words only, the longest first, in one pass, so that nothing put in is searched again; and never inside a token, which is made
  /// of ordinary words itself. `found` is lower-cased.
  private static func replacing(_ found: [(String, String)], in text: String, sparingWhatIsWrittenWithDots: Bool = false) -> String {
    let known = found.filter { !$0.0.isEmpty }.sorted { ($0.0.count, $0.0) > ($1.0.count, $1.0) }.map { (Array($0.0), $0.1) }
    guard !known.isEmpty else { return text }
    let characters = Array(text)
    // One for one, so that places stay places: a letter whose small form is several keeps its own.
    let small = characters.map { character -> Character in
      let lowercased = String(character).lowercased()
      return lowercased.count == 1 ? lowercased.first! : character
    }
    func isPartOfAWord(_ index: Int) -> Bool { characters.indices.contains(index) && (characters[index].isLetter || characters[index].isNumber) }
    /// Whether a dot at `index` joins what is on its `side` (-1 or 1) to a word there: `com.apple.mail`. The full stop of a sentence does not.
    func isJoinedByADot(at index: Int, _ side: Int) -> Bool {
      sparingWhatIsWrittenWithDots && characters.indices.contains(index) && characters[index] == "." && isPartOfAWord(index + side)
    }
    /// Where the token that begins at `index` ends: `title[3][p1][h2]`, `name-4`, `display-1[d1]`; and `title-3[p1]`, as they were.
    func endOfToken(at index: Int) -> Int? {
      for word in ["title[", "title-", "name-", "display-"] where index + word.count < characters.count {
        guard characters[index..<(index + word.count)].elementsEqual(word), characters[index + word.count].isNumber else { continue }
        var end = index + word.count
        while end < characters.count, characters[end].isNumber { end += 1 }
        if word.hasSuffix("[") {
          guard end < characters.count, characters[end] == "]" else { continue }
          end += 1
        }
        while end < characters.count, characters[end] == "[", let close = characters[end...].firstIndex(of: "]"), close - end <= 6 { end = close + 1 }
        return end
      }
      return nil
    }
    var result = ""
    var index = 0
    scan: while index < characters.count {
      if !isPartOfAWord(index - 1), !isJoinedByADot(at: index - 1, -1) {
        if let end = endOfToken(at: index) {
          result += String(characters[index..<end])
          index = end
          continue scan
        }
        for (word, standIn) in known where index + word.count <= characters.count {
          if small[index..<(index + word.count)].elementsEqual(word), !isPartOfAWord(index + word.count), !isJoinedByADot(at: index + word.count, 1) {
            result += standIn
            index += word.count
            continue scan
          }
        }
      }
      result.append(characters[index])
      index += 1
    }
    return result
  }
}
