import ArborCore
import ArborKit
import CoreGraphics
import Foundation

// The chaos test: thousands of random commands and window events against the real controller, with
// every invariant checked after each one (docs/TESTING.md, "Chaos").
//
//   Chaos.swift            the random numbers, `ChaosAction` and its text form
//   ChaosGenerator.swift   which action comes next, given the state of the world
//   ChaosRunner.swift      applies actions, checks, replays and shrinks failing scripts
//   ChaosInvariants.swift  the rules that need the fakes' side of the story
//   ArborKit/Controller/Controller+Invariants.swift   the rules about the controller's own state
//
// Everything is a function of the seed: no clock, no system randomness, no dictionary order.

/// SplitMix64. The helpers are written out rather than taken from the standard library, so that a
/// seed means the same run on every platform and toolchain.
public struct ChaosRandom: Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    // The generator steps by a constant, so neighbouring seeds used as they are would give the same
    // numbers one place apart. Start from the seed's first output instead.
    state = seed
    state = next()
  }

  public mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }

  /// A whole number in `range`.
  public mutating func int(_ range: ClosedRange<Int>) -> Int {
    range.lowerBound + Int(next() % UInt64(range.upperBound - range.lowerBound + 1))
  }

  /// A whole number of points in `range` (bounds are rounded; an empty range gives its lower bound).
  public mutating func points(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
    let (a, b) = (Int(low.rounded()), Int(high.rounded()))
    return CGFloat(b > a ? int(a...b) : a)
  }

  /// True `percent` times out of a hundred.
  public mutating func chance(_ percent: Int) -> Bool { int(0...99) < percent }

  public mutating func pick<T>(_ items: [T]) -> T? {
    items.isEmpty ? nil : items[int(0...(items.count - 1))]
  }

  /// Picks by weight; entries with no weight are never picked.
  public mutating func pick<T>(weighted items: [(weight: Int, value: T)]) -> T? {
    let total = items.reduce(0) { $0 + max($1.weight, 0) }
    guard total > 0 else { return nil }
    var roll = int(0...(total - 1))
    for item in items where item.weight > 0 {
      if roll < item.weight { return item.value }
      roll -= item.weight
    }
    return nil
  }
}

/// One thing that happens to Arbor: something the user, an app, macOS or time does. Each has a
/// one-line text form, so a failing run prints a script that `arbor-sim replay` and
/// `ChaosRunner.replay` run again. Every action is safe in every state: one that names a window,
/// node or display that does not exist is simply what a late or confused event looks like.
///
/// To add one: a case here, its words in `text` and `init(text:)`, what it does in
/// `ChaosRunner.perform`, and a weight in `ChaosGenerator.next`. The compiler points at the first three.
public enum ChaosAction: Equatable, Sendable, CustomStringConvertible {
  // Apps and their windows
  case open(NewWindow)
  case close(WindowID)
  case quitApp(pid: Int32)
  case minimize(WindowID, Bool)
  case hide(pid: Int32, Bool)
  /// The window's Space goes out of view or comes back.
  case space(WindowID, showing: Bool)
  /// The green button: the window goes into macOS's own full screen, or leaves it.
  case fullScreen(WindowID, Bool)
  case title(WindowID, String)
  /// The app changes the sizes it accepts. A nil maximum is no limit.
  case limits(WindowID, minimum: CGSize, maximum: CGSize?)
  case behave(WindowID, FakeWindowSystem.Behaviour)
  /// The window moves or resizes without the mouse (the app, the keyboard, another tool).
  case move(WindowID, CGRect)
  /// What macOS reports a moment after Arbor acts: echoes of its moves, focus changes, apps snapping back.
  case react

  // The user's hands
  case cursor(CGPoint)
  case focus(WindowID)
  /// ⌘Tab or a click brings another app to the front: no app's own focused window changes.
  case switchApp(WindowID)
  /// The keyboard goes to the desktop, a sheet, a panel: nothing Arbor knows.
  case focusNothing
  /// An app that is not in front changes which of its windows is focused.
  case backgroundFocus(WindowID)
  case press
  /// Presses the mouse on a window's title bar; `carry` moves it, `release` drops it.
  case grab(WindowID)
  case carry(CGPoint)
  case release
  /// Double-clicks a window's title bar, and macOS zooms the window, or returns it to where it was before.
  case doubleClick(WindowID)
  /// The button comes up and nobody sees it: the drag ends without a drop.
  case loseRelease
  /// ⌘ goes down, or comes up. Held during a drag, it turns docking off (F09).
  case commandKey(held: Bool)
  /// macOS's own tiling of dragged windows is switched on, as a Mac comes and every walk begins, or off. With it on the left, right and
  /// top edges of the screen are macOS's (`MacTiling`).
  case macTiling(on: Bool)
  /// Drags a window's edges until it has this frame; with `hold` the button stays down.
  case edge(WindowID, CGRect, hold: Bool)
  case tile(DisplayID, NodeID)
  /// What the user does in Go to…, which `find` opens. Nothing happens while it is closed.
  case palette(PaletteKey)
  /// Drags the index-th seam handle on a display.
  case seam(DisplayID, index: Int, delta: Double)
  /// A line for `Command.parse`, valid or not: a hotkey, the menu, `arborctl`, a URL.
  case command(String)
  /// An `arbor://` URL that something asks macOS to open.
  case url(String)
  /// A command from a shortcut, the menu or a gesture, which say whose display it is about (F56).
  case via(CommandSource, String)
  /// The key of the shortcut that runs this command goes down or comes up (F51).
  case key(String, KeyPhase)
  /// A piece of a pinch (F16).
  case pinch(GestureUpdate.Phase, Double)
  /// An app comes to the front, with or without a window (F41).
  case activate(String)
  /// An app stops answering, or answers again (F17).
  case hang(pid: Int32, Bool)
  /// A new native tab opens in front of a window; a background tab is chosen; the tab in front closes (F17).
  case openTab(WindowID, in: WindowID)
  case selectTab(WindowID, insteadOf: WindowID)
  case closeTab(WindowID, revealing: WindowID)

  // The world
  case displays([DisplaySnapshot], WindowsFollow)
  /// Merges a JSON object into settings.json and runs `reload-settings`.
  case settings(String)
  case flush
  case advance(Double)
  /// Lets go of the mouse and lets apps and timers run until nothing is pending.
  case settle

  /// What a person does when a window is gone, in one go, and then the question whether every window is within reach.
  case wayBack(ChaosRunner.WayBack)

  // Arbor's own life
  case save
  /// The process dies where it stands: nothing is saved or put back.
  case crash
  case launch
  /// While Arbor is not running: an app restarted and its window has a new number.
  case renumber(WindowID, WindowID)
  /// While Arbor is not running: a window's Space stops showing, so it is not listed at launch. Any time: it shows again.
  case listed(WindowID, Bool)
  /// While Arbor is not running: days go by.
  case sleep(days: Double)
  /// While Arbor is not running: state.json is damaged, in a way that follows from the number.
  case corrupt(UInt64)
  /// All of an app's windows come to lie in front of the others', as at a click on its icon in the Dock. `focus` says which gets the keyboard.
  case appForward(pid: Int32)

  public struct NewWindow: Equatable, Sendable {
    public var id: WindowID
    public var app: String
    public var pid: Int32
    public var frame: CGRect
    public var minimum: CGSize = .zero
    public var maximum: CGSize?
    /// Nil is "<app> <id>", which is unique.
    public var title: String?
    public var hasBundleID = true
    public var behaviour: FakeWindowSystem.Behaviour = .normal
    /// The bundle id of a real app, for walks that are also taken on a Mac. Nil is one made up from the app's name.
    public var bundle: String?
    /// Its size comes in steps, with so much besides: a terminal's characters.
    public var cells: RealApp.Cells?

    public init(id: WindowID, app: String, pid: Int32, frame: CGRect) {
      self.id = id
      self.app = app
      self.pid = pid
      self.frame = frame
    }

    public var bundleID: String? { hasBundleID ? bundle ?? "com.example.\(app.lowercased())" : nil }
  }

  public enum PaletteKey: Equatable, Sendable {
    /// Replaces the text in the field.
    case type(String)
    /// ↓, or negative ↑, that many times.
    case move(Int)
    /// Return, or ⌘ and the number of a row that shows.
    case choose(Int?)
    case escape
  }

  /// What macOS does with the windows when the displays change. It moves them along with their
  /// display (or onto the main one if theirs is gone) in the same instant; only the order in
  /// which Arbor hears about it varies.
  public enum WindowsFollow: String, Sendable, CaseIterable {
    /// Arbor hears about the windows first, then about the displays.
    case first
    /// Arbor hears about the displays first.
    case late
    /// The windows have moved with their displays by the time Arbor hears about the displays, and no app ever says so.
    case silent
    /// The windows stay at their old coordinates, which no Mac does; Arbor must cope anyway.
    case never
  }

  // MARK: Text form

  public var description: String { text }

  public var text: String {
    func n(_ value: CGFloat) -> String { Self.format(Double(value)) }
    func size(_ value: CGSize) -> String { "\(n(value.width)) \(n(value.height))" }
    func rect(_ value: CGRect) -> String {
      "\(n(value.origin.x)) \(n(value.origin.y)) \(n(value.size.width)) \(n(value.size.height))"
    }
    switch self {
    case .open(let window):
      var words = ["open", "\(window.id.rawValue)", window.app, "pid", "\(window.pid)", "at", rect(window.frame)]
      if window.minimum != .zero { words += ["min", size(window.minimum)] }
      if let maximum = window.maximum { words += ["max", size(maximum)] }
      if let title = window.title { words += ["title", title] }
      if !window.hasBundleID { words.append("no-bundle") }
      if let bundle = window.bundle { words += ["bundle", bundle] }
      if let cells = window.cells { words += ["cells", size(cells.step), size(cells.margin)] }
      if window.behaviour != .normal { words.append(window.behaviour.rawValue) }
      return words.joined(separator: " ")
    case .close(let window): return "close \(window.rawValue)"
    case .quitApp(let pid): return "quit-app \(pid)"
    case .minimize(let window, let minimized): return "\(minimized ? "minimize" : "restore") \(window.rawValue)"
    case .hide(let pid, let hidden): return "\(hidden ? "hide" : "show") \(pid)"
    case .space(let window, let showing): return "space \(window.rawValue) \(showing ? "on" : "off")"
    case .fullScreen(let window, let on): return "full-screen \(window.rawValue) \(on ? "on" : "off")"
    case .title(let window, let title): return "title \(window.rawValue) \(title)"
    case .limits(let window, let minimum, let maximum):
      return "limits \(window.rawValue) min \(size(minimum))" + (maximum.map { " max \(size($0))" } ?? "")
    case .behave(let window, let behaviour): return "behave \(window.rawValue) \(behaviour.rawValue)"
    case .move(let window, let frame): return "move \(window.rawValue) \(rect(frame))"
    case .react: return "react"
    case .cursor(let point): return "cursor \(n(point.x)) \(n(point.y))"
    case .focus(let window): return "focus \(window.rawValue)"
    case .switchApp(let window): return "switch-app \(window.rawValue)"
    case .focusNothing: return "focus-nothing"
    case .backgroundFocus(let window): return "background-focus \(window.rawValue)"
    case .press: return "press"
    case .grab(let window): return "grab \(window.rawValue)"
    case .doubleClick(let window): return "double-click \(window.rawValue)"
    case .carry(let point): return "carry \(n(point.x)) \(n(point.y))"
    case .release: return "release"
    case .loseRelease: return "lose-release"
    case .commandKey(held: let held): return held ? "cmd down" : "cmd up"
    case .macTiling(on: let on): return on ? "mac-tiling on" : "mac-tiling off"
    case .via(let source, let line): return "via \(source.rawValue) \(line)"
    case .key(let line, let phase): return "key \(phase == .pressed ? "down" : "up") \(line)"
    case .pinch(let phase, let magnification): return "pinch \(Self.word(for: phase)) \(Self.format(magnification))"
    case .activate(let bundleID): return "activate \(bundleID)"
    case .hang(let pid, let hung): return "\(hung ? "hang" : "wake") \(pid)"
    case .openTab(let new, let front): return "tab-open \(new.rawValue) in \(front.rawValue)"
    case .selectTab(let tab, let front): return "tab-select \(tab.rawValue) for \(front.rawValue)"
    case .closeTab(let front, let next): return "tab-close \(front.rawValue) for \(next.rawValue)"
    case .listed(let window, let listed): return "\(listed ? "list" : "unlist") \(window.rawValue)"
    case .edge(let window, let frame, let hold):
      return "edge \(window.rawValue) \(rect(frame))" + (hold ? " hold" : "")
    case .tile(let display, let node): return "tile \(display.rawValue) \(node.rawValue)"
    case .palette(.type(let text)): return text.isEmpty ? "palette type" : "palette type \(text)"
    case .palette(.move(let rows)): return "palette move \(rows)"
    case .palette(.choose(let row)): return row.map { "palette choose \($0)" } ?? "palette choose"
    case .palette(.escape): return "palette escape"
    case .seam(let display, let index, let delta): return "seam \(display.rawValue) \(index) \(Self.format(delta))"
    // `release` lets go of the mouse and is also a command (F58): where the words mean something else in a script, `do` says which.
    case .command(let line): return Self.parse(line.split(separator: " ").map(String.init)) == nil ? line : "do \(line)"
    case .url(let url): return "url \(url)"
    case .displays(let displays, let follow):
      let words = displays.map { display -> String in
        let (f, v) = (display.frame, display.visibleFrame)
        let insets = [v.minY - f.minY, v.minX - f.minX, f.maxY - v.maxY, f.maxX - v.maxX].map(n)
        let frame = [f.minX, f.minY, f.width, f.height].map(n)
        return "\(display.id.rawValue):\(frame.joined(separator: ",")):\(insets.joined(separator: ","))"
          + (display.isMain ? "*" : "")
      }
      return (["displays"] + words + ["windows-\(follow.rawValue)"]).joined(separator: " ")
    case .settings(let json): return "settings \(json)"
    case .flush: return "flush"
    case .advance(let seconds): return "advance \(Self.format(seconds))"
    case .settle: return "settle"
    case .wayBack(let way): return "way-back \(way.rawValue)"
    case .save: return "save"
    case .crash: return "crash"
    case .launch: return "launch"
    case .renumber(let old, let new): return "renumber \(old.rawValue) \(new.rawValue)"
    case .sleep(let days): return "sleep \(Self.format(days))"
    case .corrupt(let how): return "corrupt \(how)"
    case .appForward(let pid): return "app-forward \(pid)"
    }
  }

  static let phases: [GestureUpdate.Phase] = [.began, .changed, .ended, .cancelled]

  static func word(for phase: GestureUpdate.Phase) -> String {
    switch phase {
    case .began: "began"
    case .changed: "changed"
    case .ended: "ended"
    case .cancelled: "cancelled"
    }
  }

  /// Reads one line of a script. A line that is not one of the forms above is a command for
  /// `Command.parse`, so this never fails: `focus 101` is the user clicking a window, and a future
  /// `focus left` would be a command.
  public init(text line: String) {
    let words = line.split(separator: " ").map(String.init)
    self = Self.parse(words) ?? .command(line)
  }

  /// A script, one action per line. Blank lines and lines starting with `#` are skipped.
  public static func script(_ text: String) -> [ChaosAction] {
    text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }.map { ChaosAction(text: $0) }
  }

  private static func parse(_ words: [String]) -> ChaosAction? {
    guard let verb = words.first else { return nil }
    let count = words.count
    func window(_ index: Int) -> WindowID? { index < count ? UInt32(words[index]).map { WindowID($0) } : nil }
    func number(_ index: Int) -> CGFloat? {
      guard index < count, let value = Double(words[index]), value.isFinite else { return nil }
      return CGFloat(value)
    }
    func pid(_ index: Int) -> Int32? { index < count ? Int32(words[index]) : nil }
    func size(_ index: Int) -> CGSize? {
      guard let width = number(index), let height = number(index + 1) else { return nil }
      return CGSize(width: width, height: height)
    }
    func point(_ index: Int) -> CGPoint? { size(index).map { CGPoint(x: $0.width, y: $0.height) } }
    func rect(_ index: Int) -> CGRect? {
      guard let origin = point(index), let size = size(index + 2) else { return nil }
      return CGRect(origin: origin, size: size)
    }

    switch (verb, count) {
    case ("open", 10...):
      guard let id = window(1), words[3] == "pid", let pid = pid(4), words[5] == "at", let frame = rect(6) else {
        return nil
      }
      var new = NewWindow(id: id, app: words[2], pid: pid, frame: frame)
      var index = 10
      while index < count {
        switch words[index] {
        case "min":
          guard let value = size(index + 1) else { return nil }
          new.minimum = value
          index += 3
        case "max":
          guard let value = size(index + 1) else { return nil }
          new.maximum = value
          index += 3
        case "title":
          guard index + 1 < count else { return nil }
          new.title = words[index + 1]
          index += 2
        case "no-bundle":
          new.hasBundleID = false
          index += 1
        case "bundle":
          guard index + 1 < count else { return nil }
          new.bundle = words[index + 1]
          index += 2
        case "cells":
          guard let step = size(index + 1), let margin = size(index + 3), step.width >= 1, step.height >= 1 else { return nil }
          new.cells = RealApp.Cells(step: step, margin: margin)
          index += 5
        default:
          guard let behaviour = FakeWindowSystem.Behaviour(rawValue: words[index]) else { return nil }
          new.behaviour = behaviour
          index += 1
        }
      }
      return .open(new)
    case ("close", 2): return window(1).map { .close($0) }
    case ("quit-app", 2): return pid(1).map { .quitApp(pid: $0) }
    case ("minimize", 2): return window(1).map { .minimize($0, true) }
    case ("restore", 2): return window(1).map { .minimize($0, false) }
    case ("hide", 2): return pid(1).map { .hide(pid: $0, true) }
    case ("show", 2): return pid(1).map { .hide(pid: $0, false) }
    case ("space", 3):
      guard let id = window(1), ["on", "off"].contains(words[2]) else { return nil }
      return .space(id, showing: words[2] == "on")
    case ("full-screen", 3):
      guard let id = window(1), ["on", "off"].contains(words[2]) else { return nil }
      return .fullScreen(id, words[2] == "on")
    case ("title", 3): return window(1).map { .title($0, words[2]) }
    case ("limits", 5), ("limits", 8):
      guard let id = window(1), words[2] == "min", let minimum = size(3) else { return nil }
      if count == 5 { return .limits(id, minimum: minimum, maximum: nil) }
      guard words[5] == "max", let maximum = size(6) else { return nil }
      return .limits(id, minimum: minimum, maximum: maximum)
    case ("behave", 3):
      guard let id = window(1), let behaviour = FakeWindowSystem.Behaviour(rawValue: words[2]) else { return nil }
      return .behave(id, behaviour)
    case ("move", 6):
      guard let id = window(1), let frame = rect(2) else { return nil }
      return .move(id, frame)
    case ("react", 1): return .react
    case ("cursor", 3): return point(1).map { .cursor($0) }
    case ("focus", 2): return window(1).map { .focus($0) }
    case ("switch-app", 2): return window(1).map { .switchApp($0) }
    case ("double-click", 2): return window(1).map { .doubleClick($0) }
    case ("focus-nothing", 1): return .focusNothing
    case ("background-focus", 2): return window(1).map { .backgroundFocus($0) }
    case ("press", 1): return .press
    case ("grab", 2): return window(1).map { .grab($0) }
    case ("carry", 3): return point(1).map { .carry($0) }
    case ("release", 1): return .release
    case ("do", 2...): return .command(words.dropFirst().joined(separator: " "))
    case ("way-back", 2): return ChaosRunner.WayBack(rawValue: words[1]).map { .wayBack($0) }
    case ("lose-release", 1): return .loseRelease
    case ("cmd", 2) where words[1] == "down" || words[1] == "up": return .commandKey(held: words[1] == "down")
    case ("mac-tiling", 2) where words[1] == "on" || words[1] == "off": return .macTiling(on: words[1] == "on")
    case ("via", 3...): return CommandSource(rawValue: words[1]).map { .via($0, words.dropFirst(2).joined(separator: " ")) }
    case ("key", 3...) where words[1] == "down" || words[1] == "up":
      return .key(words.dropFirst(2).joined(separator: " "), words[1] == "down" ? .pressed : .released)
    case ("pinch", 3):
      guard let phase = phases.first(where: { word(for: $0) == words[1] }), let magnification = Double(words[2]) else { return nil }
      return .pinch(phase, magnification)
    case ("activate", 2): return .activate(words[1])
    case ("hang", 2), ("wake", 2): return pid(1).map { .hang(pid: $0, verb == "hang") }
    case ("tab-open", 4) where words[2] == "in":
      guard let new = window(1), let front = window(3) else { return nil }
      return .openTab(new, in: front)
    case ("tab-select", 4) where words[2] == "for":
      guard let tab = window(1), let front = window(3) else { return nil }
      return .selectTab(tab, insteadOf: front)
    case ("tab-close", 4) where words[2] == "for":
      guard let front = window(1), let next = window(3) else { return nil }
      return .closeTab(front, revealing: next)
    case ("list", 2), ("unlist", 2): return window(1).map { .listed($0, verb == "list") }
    case ("edge", 6), ("edge", 7):
      guard let id = window(1), let frame = rect(2), count == 6 || words[6] == "hold" else { return nil }
      return .edge(id, frame, hold: count == 7)
    case ("tile", 3):
      guard let node = Int(words[2]) else { return nil }
      return .tile(DisplayID(words[1]), NodeID(node))
    case ("palette", 2...):
      switch (words[1], count) {
      case ("type", _): return .palette(.type(words.dropFirst(2).joined(separator: " ")))
      case ("move", 3): return Int(words[2]).map { .palette(.move($0)) }
      case ("choose", 2): return .palette(.choose(nil))
      case ("choose", 3): return Int(words[2]).map { .palette(.choose($0)) }
      case ("escape", 2): return .palette(.escape)
      default: return nil
      }
    case ("seam", 4):
      guard let index = Int(words[2]), let delta = number(3) else { return nil }
      return .seam(DisplayID(words[1]), index: index, delta: Double(delta))
    case ("url", 2): return .url(words[1])
    case ("displays", 2...):
      guard let last = words.last, last.hasPrefix("windows-"),
        let follow = WindowsFollow(rawValue: String(last.dropFirst("windows-".count)))
      else { return nil }
      var displays: [DisplaySnapshot] = []
      for word in words[1..<(count - 1)] {
        let isMain = word.hasSuffix("*")
        let parts = (isMain ? String(word.dropLast()) : word).split(separator: ":").map(String.init)
        guard parts.count == 3 else { return nil }
        let f = parts[1].split(separator: ",").compactMap { Double($0) }.map { CGFloat($0) }
        let i = parts[2].split(separator: ",").compactMap { Double($0) }.map { CGFloat($0) }
        guard f.count == 4, i.count == 4 else { return nil }
        displays.append(
          DisplaySnapshot(
            id: DisplayID(parts[0]), frame: CGRect(x: f[0], y: f[1], width: f[2], height: f[3]),
            visibleFrame: CGRect(x: f[0] + i[1], y: f[1] + i[0], width: f[2] - i[1] - i[3], height: f[3] - i[0] - i[2]),
            isMain: isMain))
      }
      return .displays(displays, follow)
    // `settings {…}` edits the file; `settings` and `settings --markdown` are commands.
    case ("settings", 2...) where words[1].hasPrefix("{"): return .settings(words.dropFirst().joined(separator: " "))
    case ("flush", 1): return .flush
    case ("advance", 2): return number(1).map { .advance(Double($0)) }
    case ("settle", 1): return .settle
    case ("save", 1): return .save
    case ("crash", 1): return .crash
    case ("launch", 1): return .launch
    case ("renumber", 3):
      guard let old = window(1), let new = window(2) else { return nil }
      return .renumber(old, new)
    case ("sleep", 2): return number(1).map { .sleep(days: Double($0)) }
    case ("corrupt", 2): return UInt64(words[1]).map { .corrupt($0) }
    case ("app-forward", 2): return pid(1).map { .appForward(pid: $0) }
    default: return nil
    }
  }

  static func format(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
  }
}
