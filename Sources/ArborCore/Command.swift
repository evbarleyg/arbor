/// Every user-facing action. Hotkeys, the menu bar, `arborctl`, `arbor://`
/// URLs and tests all go through this one type, so adding an action means
/// adding a case here, its words in `parse`, `text` and `helpText`, and a handler in
/// `Controller.perform`.
///
/// Commands that take an optional window act on the focused window when it is nil.
public enum Command: Equatable, Sendable, Codable {
  // Queries
  case status
  case state(titles: Bool)
  case ascii
  case help

  // Camera
  case showAll
  case stepOut
  case stepIn
  case neighbor(Edge)
  case back
  case forward
  case zoom(WindowID?)
  case zoomNode(NodeID)
  case desktop
  case saveView(Int)
  case goToView(Int)

  // Arrangement
  case dock(WindowID?, Edge)
  case dockBeside(WindowID?, target: WindowID, Edge)
  case float(WindowID?)
  case toggleFloat(WindowID?)
  case arrange
  case floatAll
  case resize(WindowID?, Edge, Double)

  // App
  case exclude(bundleID: String?)
  case include(bundleID: String)
  case relayout
  case reloadSettings
  case quit

  /// Lists the keyboard shortcuts in effect (a query).
  case bindings
  /// A query: the per-app rules for new windows, and which one matches the focused window.
  case rules
  /// Frames what best fits a rectangle in global coordinates (see Controller+FrameRect.swift).
  case frameRect(x: Double, y: Double, width: Double, height: Double)
  /// Shows everything on every display: the way back from anywhere.
  case home
  /// Arbor returns every window to view and leaves windows, keys and gestures alone until `resume`,
  /// or for that many minutes (see Controller+Pause.swift).
  case pause(minutes: Double?)
  case resume
  case togglePause
  /// `float-all here`: only the display camera commands act on (F32, F56).
  case floatAllHere
  /// `arrange all`: every display that has windows (F32).
  case arrangeAll
  /// A query: one line per thing that can keep Arbor from working (see Controller+Doctor.swift).
  case doctor
  /// Opens the welcome window on its first page: permissions, macOS settings and other apps that matter, with
  /// whether each is in order. Works before Arbor has any permission.
  case checkSetup
  /// Opens the welcome window on its second page, three moves to try (or the first, while Arbor may not move windows).
  case welcome
  /// A query: the buttons the menu bar item shows and where each one is (see Controller+MenuBar.swift).
  case menuBar
  /// A query: Arbor's menu as it would open now, as text (see Controller+Menu.swift).
  case menu
  /// Puts an app on, or takes it off, the list of apps that keep their own ⌃⌥; without a bundle id,
  /// the frontmost app (see Controller+PassThrough.swift). Without `on` it toggles.
  case passThrough(bundleID: String?, on: Bool? = nil)
  /// Keeps a floating window in view wherever the camera goes (see Controller+Pin.swift).
  case pin(WindowID?)
  case unpin(WindowID?)
  case togglePin(WindowID?)
  /// A query: streams events to a client that stays connected (`arborctl watch`, docs/SCRIPTING.md).
  case watch(WatchOptions)
  /// A query: how often and how long Arbor ran commands and called other apps; `reset` starts counting afresh.
  case stats(reset: Bool)
  /// Keeps the view on every display exactly where it is until `release`, or for that many minutes:
  /// nothing moves it, not even the user's own keys (see Controller+Hold.swift and CommandHold.swift).
  case hold(minutes: Double?)
  /// `hold still`: Arbor moves the view only when the user asks, never by itself.
  case holdStill(minutes: Double?)
  case release
  case toggleHold
  /// A query: which build this is and what the last update check found (Controller+Updates.swift).
  case version
  /// Asks whether a newer release exists and offers its page. Never downloads or installs anything.
  case checkForUpdates
  /// Makes macOS open Arbor at login, or stops it; nil only asks (Controller+LoginItem.swift).
  case launchAtLogin(Bool?)
  /// Reads or changes settings: `set`, `get`, `settings`, `reset`, `bind`, `unbind`, `rule …`
  /// (SettingsCommand.swift).
  case settings(SettingsCommand)
  /// Opens "Go to…", the finder for windows, named spaces and saved views; with text, goes straight to the best match
  /// (see Controller+Finder.swift).
  case find(String?)
  /// Brings a window into view, whatever keeps it out of it, and focuses it.
  case reveal(WindowID?)
  /// Records what passes between Arbor and macOS, for replaying in tests (docs/TRACES.md).
  case trace(TraceCommand)
  /// Brings an app's window over the view, or sends it out of view again (see Controller+Summon.swift).
  /// The app is a bundle id or a name.
  case summon(app: String)
  /// Arranges a display as a line of text says: `layout Safari | (Mail / Notes)` (LayoutNotation.swift,
  /// Controller+LayoutNotation.swift). `display` is what followed `@`, nil the display under the
  /// pointer. With `open`, apps that have no window are opened and join when their window appears.
  case layout(LayoutNotation.Spec, display: String?, open: Bool)
  /// A query, `layout` on its own: a display's arrangement as such a line.
  case printLayout(display: String?, naming: LayoutNotation.Naming)
  /// Names the space in view (F20, Controller+NamedSpaces.swift). The text is a `SpaceName`.
  case name(String)
  /// Takes a name off: the given one, or that of the space in view.
  case unname(String?)
  /// `go <name>`: moves the view to the space of that name, or the only one that begins so.
  case goToSpace(String)
  /// A query: the names, what their spaces hold and where they are.
  case spaces
  /// Shows the field to type a name for the space in view into, or with `cancel` closes it.
  case askName(cancel: Bool)
  /// A command that names windows by app, `focused` or `pointer` instead of by number: `zoom Safari`. It holds the
  /// command with stand-in numbers, and the names in their order (WindowRef.swift).
  indirect case naming(Command, [WindowRef])
  /// The small queries (Queries.swift): the windows Arbor arranges, what each display's view shows (`where`), the saved
  /// views, the displays, and Arbor's version.
  case listWindows(titles: Bool)
  case listPlaces
  case listViews
  case listDisplays
  /// `help zoom`: one command's usage, other names and shortcuts (CommandHelp.swift).
  case helpOn(String)
  /// Switches the setting `newWindows` between `dock` and `float` (F23, Controller+AutoDock.swift).
  case toggleAutoDock
  /// Shows the shortcuts in effect in a panel on screen, or puts the panel away (Controller+CheatSheet.swift).
  case showShortcuts
  /// Shows the minimap on the display under the pointer, or puts it away (see Controller+Minimap.swift).
  case minimap
  /// Steps back and forward through the changes to one display's arrangement (see
  /// Controller+Undo.swift). Camera moves are `back` and `forward`.
  case undo
  case redo

  // Keyboard tiling tools (docs/features/F22-keyboard-tiling-tools.md; TilingCommands.swift has the argument types).
  case focus(FocusTarget)
  /// Trades places with the nearest docked window that way. The slots keep their sizes.
  case swap(WindowID?, Edge)
  case swapWindows(WindowID, WindowID)
  /// `balance`: equal shares for everything under the camera, or with `all` on the whole display.
  case equalize(all: Bool)
  /// Turns the group holding the focused window from a row into a column or back.
  case rotate
  /// Reverses the order of the group holding the focused window.
  case mirror
  /// Makes the focused window bigger or smaller by this many points, or by `resizeStep` when nil.
  case grow(Double?)
  case shrink(Double?)
  case moveToDisplay(DisplayTarget, WindowID?)
  case focusDisplay(DisplayTarget)

  /// Whether the command only reads state.
  public var isQuery: Bool {
    switch self {
    case .status, .state, .ascii, .help: true
    case .bindings: true
    case .rules: true
    case .watch: true
    case .doctor, .menuBar, .menu: true
    case .stats: true
    case .version: true
    case .launchAtLogin(let enabled): enabled == nil
    case .settings(let command): command.isQuery
    case .trace(.status): true
    case .printLayout: true
    case .spaces: true
    case .naming(let command, _): command.isQuery
    case .listWindows, .listPlaces, .listViews, .listDisplays, .helpOn: true
    default: false
    }
  }

  /// Whether the command ends a pause. Shortcuts for these stay registered while Arbor is paused;
  /// all the others are handed back to the apps.
  public var endsPause: Bool {
    switch self {
    case .resume, .togglePause: true
    case .naming(let command, _): command.endsPause
    default: false
    }
  }

  /// Whether a shortcut for the command stays registered while an app that keeps its own ⌃⌥ is frontmost.
  /// `toggle-pause` is the one key that answers wherever you are, and a key that turned pass-through on
  /// has to be there to turn it off.
  public var worksInPassThroughApps: Bool {
    switch self {
    case .togglePause, .passThrough: true
    default: false
    }
  }

  /// Whether the command is one of the ways home: what people reach for when a window is missing.
  public var bringsWindowsBack: Bool {
    switch self {
    case .showAll, .home, .floatAll, .floatAllHere, .pause, .togglePause: true
    default: false
    }
  }

  // MARK: Text form

  public struct ParseError: Error, CustomStringConvertible, Equatable {
    public let description: String
    /// Errors quote what was typed, are logged and travel back over the socket, so they stay short.
    init(_ description: String) {
      self.description = description.count > 200 ? String(description.prefix(200)) + "…" : description
    }
  }

  /// Parses the text form used by `arborctl`, `arbor://` URLs and arbor-sim,
  /// e.g. `dock left`, `dock 412 beside 388 bottom`, `zoom w412`, `view 2`.
  ///
  /// Words are separated by white space, or by slashes as in a URL path. Whichever comes first
  /// separates the whole text, so the other can be part of a word: `bind ctrl+opt+/ desktop`. White
  /// space around the words of a path does not count: `/ dock / left /`.
  public static func parse(_ text: String) throws -> Command {
    if let line = layoutLine(in: text) { return try parseLayout(line) }
    return try parse(words: words(of: text))
  }

  /// Bundle ids end up in settings.json, the menu and the log, so only what Apple allows in one
  /// (and the underscore some apps use anyway) gets in. Other apps can be excluded while focused.
  static func bundleID(_ word: String) throws -> String {
    let allowed = word.utf8.allSatisfy { byte in
      switch byte {
      case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"): true
      case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "_"): true
      default: false
      }
    }
    guard allowed, !word.isEmpty, word.utf8.count <= 255 else {
      throw ParseError("expected a bundle id like com.apple.Safari")
    }
    return word
  }

  public static func parse(words input: [String]) throws -> Command {
    var names: [WindowRef] = []
    let command = try parse(words: input, names: &names)
    return names.isEmpty ? command : try wrapped(command, naming: names)
  }

  /// `names` collects the windows that were named rather than numbered (WindowRef.swift).
  private static func parse(words typed: [String], names: inout [WindowRef]) throws -> Command {
    // Quotes hold a word together: `summon "Visual Studio Code"`, `bind "ctrl+opt+/" desktop`, `rule add … title "My Page"`. They come off
    // here, once, for every command alike. Only `window` asks whether they were there, because they also say that a word is a
    // name and nothing else (`"left"`, `"412"`); and a command inside a command (`bind`, `layout`'s line) is read later, so it keeps them.
    let input = typed.map { unquoted($0) ?? $0 }
    let words = input.map { $0.lowercased() }
    guard let verb = words.first else { throw ParseError("empty command; try `help`") }
    let args = Array(words.dropFirst())
    let originalArgs = Array(input.dropFirst())
    let typedArgs = Array(typed.dropFirst())

    func edge(_ word: String?) throws -> Edge {
      guard let word, let edge = Edge(word: word) else {
        throw ParseError("expected left, right, up or down, got \(word ?? "nothing")")
      }
      return edge
    }
    /// Every command reads its windows through this, which is how all of them take names as well. By its place among the arguments,
    /// because the word is wanted as it was typed, with its quotes, if it had any, and its capitals: in `dock "left" left` only the first is a name.
    func window(_ index: Int) throws -> WindowID {
      let typed = typedArgs[index]
      if unquoted(typed) == nil, let id = WindowID(word: args[index]) { return id }
      guard names.count < mostNames else { throw ParseError("too many windows") }
      names.append(try WindowRef(word: typed))
      return standIn(names.count - 1)
    }
    func slot(_ word: String?) throws -> Int {
      guard let word, let n = Int(word), (1...9).contains(n) else {
        throw ParseError("expected a view number 1-9, got \(word ?? "nothing")")
      }
      return n
    }
    func optionalWindow() throws -> WindowID? {
      guard !args.isEmpty else { return nil }
      guard args.count == 1 else { throw ParseError("`\(verb)` takes one window at most") }
      return try window(0)
    }
    /// A distance or a coordinate. The bound is larger than any arrangement of displays, and keeps
    /// infinity and numbers that are not numbers away from everything that computes with them.
    func points(_ word: String) throws -> Double {
      guard let value = Double(word), abs(value) <= 1_000_000 else {
        throw ParseError("expected a number of points, at most ±1000000, got \(word)")
      }
      return value
    }
    func noArgs(_ command: Command) throws -> Command {
      guard args.isEmpty else { throw ParseError("`\(verb)` takes no arguments") }
      return command
    }
    /// The rest of the line as the name of a space, with its capitals.
    func spaceName() throws -> String {
      do {
        return try SpaceName.tidied(originalArgs.joined(separator: " "))
      } catch {
        throw ParseError("\(error)")
      }
    }
    /// A word that is not understood is a mistake somebody made, and doing the rest anyway hides it.
    func oneArgument(orNone: Bool = false) throws {
      guard args.count <= 1 else {
        throw ParseError("`\(verb)` takes one argument\(orNone ? " at most" : ""), got \(args.count)")
      }
    }

    switch verb {
    case "status": return try noArgs(.status)
    case "state":
      guard args.allSatisfy({ $0 == "--titles" }) else { throw ParseError("usage: state [--titles]") }
      return .state(titles: !args.isEmpty)
    case "ascii", "draw": return try noArgs(.ascii)
    case "help", "--help", "-h":
      // Help is given whatever follows: on the command that was named, or else the whole of it, which has what they are after.
      guard args.count == 1, let known = canonicalVerb(args[0]) else { return .help }
      return .helpOn(known)
    case "show-all", "everything", "overview", "show-everything": return try noArgs(.showAll)
    case "out", "step-out", "zoom-out": return try noArgs(.stepOut)
    case "in", "step-in", "zoom-in": return try noArgs(.stepIn)
    case "neighbor", "neighbour":
      try oneArgument()
      return .neighbor(try edge(args.first))
    case "go":
      // A direction means the neighbour, which is why no space can be named after one.
      if args.count == 1, let edge = Edge(word: args[0]) { return .neighbor(edge) }
      guard !args.isEmpty else { throw ParseError("usage: go <edge> | go <name of a space> (`spaces` lists the names)") }
      return .goToSpace(try spaceName())
    case "back": return try noArgs(.back)
    case "forward": return try noArgs(.forward)
    case "zoom", "frame": return .zoom(try optionalWindow())
    case "zoom-node":
      try oneArgument()
      guard let word = args.first, let node = NodeID(word: word) else {
        throw ParseError("expected a node id, e.g. zoom-node 3")
      }
      return .zoomNode(node)
    case "desktop": return try noArgs(.desktop)
    case "save-view":
      try oneArgument()
      return .saveView(try slot(args.first))
    case "view", "go-view":
      try oneArgument()
      return .goToView(try slot(args.first))
    case "dock":
      switch args.count {
      case 1: return .dock(nil, try edge(args[0]))
      case 2: return .dock(try window(0), try edge(args[1]))
      case 3 where args[0] == "beside":
        return .dockBeside(nil, target: try window(1), try edge(args[2]))
      case 4 where args[1] == "beside":
        return .dockBeside(try window(0), target: try window(2), try edge(args[3]))
      default:
        throw ParseError("usage: dock [window] <edge> | dock [window] beside <window> <edge>")
      }
    case "float", "undock": return .float(try optionalWindow())
    case "toggle-float": return .toggleFloat(try optionalWindow())
    case "arrange":
      if args == ["all"] { return .arrangeAll }
      guard args.isEmpty else { throw ParseError("usage: arrange [all] (this display, or every display)") }
      return .arrange
    case "float-all":
      if args == ["here"] { return .floatAllHere }
      guard args.isEmpty else { throw ParseError("usage: float-all [here] (every display, or only this one)") }
      return .floatAll
    case "resize":
      switch args.count {
      case 2:
        return .resize(nil, try edge(args[0]), try points(args[1]))
      case 3:
        return .resize(try window(0), try edge(args[1]), try points(args[2]))
      default:
        throw ParseError("usage: resize [window] <edge> <points> (negative shrinks)")
      }
    case "exclude":
      try oneArgument(orNone: true)
      return .exclude(bundleID: try originalArgs.first.map(bundleID))
    case "include":
      try oneArgument()
      guard let bundle = originalArgs.first else { throw ParseError("usage: include <bundle id>") }
      return .include(bundleID: try bundleID(bundle))
    case "relayout": return try noArgs(.relayout)
    case "reload-settings": return try noArgs(.reloadSettings)
    case "quit": return try noArgs(.quit)
    case "bindings", "shortcuts": return try noArgs(.bindings)
    case "rules": return try noArgs(.rules)
    case "frame-rect":
      guard args.count == 4 else {
        throw ParseError("usage: frame-rect <x> <y> <width> <height> (global points, origin top-left)")
      }
      let numbers = try args.map(points)
      return .frameRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    case "home": return try noArgs(.home)
    case "stats":
      guard args.isEmpty || args == ["reset"] else { throw ParseError("usage: stats [reset]") }
      return .stats(reset: !args.isEmpty)
    case "pause":
      guard let word = args.first else { return .pause(minutes: nil) }
      // A day is longer than any meeting, and keeps `text` printable.
      guard args.count == 1, let minutes = Double(word), minutes > 0, minutes <= 1440 else {
        throw ParseError("usage: pause [minutes] (up to 1440; without a number, until `resume`)")
      }
      return .pause(minutes: minutes)
    case "resume", "unpause": return try noArgs(.resume)
    case "toggle-pause": return try noArgs(.togglePause)
    case "doctor": return try noArgs(.doctor)
    case "check-setup", "setup", "permissions": return try noArgs(.checkSetup)
    case "welcome": return try noArgs(.welcome)
    case "menu-bar": return try noArgs(.menuBar)
    case "menu": return try noArgs(.menu)
    case "pass-through", "passthrough":
      // `on` and `off` are for files that must say which, however often they are run.
      let on: Bool? = args.last == "on" ? true : args.last == "off" ? false : nil
      let names = on == nil ? originalArgs : Array(originalArgs.dropLast())
      guard names.count <= 1, !["on", "off"].contains(names.first?.lowercased() ?? "") else {
        throw ParseError("usage: pass-through [bundle id] [on|off] (without a bundle id, the app in front)")
      }
      return .passThrough(bundleID: try names.first.map(bundleID), on: on)
    case "pin", "unpin", "toggle-pin":
      guard args.count <= 1 else { throw ParseError("usage: \(verb) [window] (one window at a time)") }
      let window = try optionalWindow()
      return verb == "pin" ? .pin(window) : verb == "unpin" ? .unpin(window) : .togglePin(window)
    case "hold":
      let still = args.first == "still"
      let rest = still ? Array(args.dropFirst()) : args
      guard let word = rest.first else { return still ? .holdStill(minutes: nil) : .hold(minutes: nil) }
      // Bounded as `pause` is.
      guard rest.count == 1, let minutes = Double(word), minutes > 0, minutes <= 1440 else {
        throw ParseError("usage: hold [still] [minutes] (up to 1440; without a number, until `release`)")
      }
      return still ? .holdStill(minutes: minutes) : .hold(minutes: minutes)
    case "release": return try noArgs(.release)
    case "toggle-hold": return try noArgs(.toggleHold)
    case "version", "--version": return try noArgs(.version)
    case "check-for-updates": return try noArgs(.checkForUpdates)
    case "launch-at-login":
      switch args {
      case []: return .launchAtLogin(nil)
      case ["on"]: return .launchAtLogin(true)
      case ["off"]: return .launchAtLogin(false)
      default: throw ParseError("usage: launch-at-login [on|off]")
      }
    case _ where SettingsCommand.verbs.contains(verb):
      // What a shortcut is to run is a command of its own, read when it is bound.
      return .settings(try SettingsCommand.parse(verb: verb, args: verb == "bind" ? Array(originalArgs.prefix(1)) + Array(typedArgs.dropFirst()) : originalArgs))
    case "find", "go-to":
      // As typed: the finder ignores case by itself. A URL's words may hold spaces and slashes, which divide words
      // in a command's text; the finder takes them for the same, and so the text parses back to this command.
      let sought = originalArgs.flatMap { $0.split(whereSeparator: { $0 == "/" || $0.isWhitespace }) }
      return .find(sought.isEmpty ? nil : sought.joined(separator: " "))
    case "reveal": return .reveal(try optionalWindow())
    case "trace":
      let usage = "usage: trace on [name] | trace off | trace status | trace note <text>"
      switch (args.first, args.count) {
      case (nil, _), ("status", 1): return .trace(.status)
      case ("off", 1): return .trace(.off)
      case ("on", 1): return .trace(.on(name: nil))
      case ("on", 2):
        guard TraceCommand.isValidName(originalArgs[1]) else {
          throw ParseError("a trace's name is up to 40 letters, digits, dots, dashes and underscores")
        }
        return .trace(.on(name: originalArgs[1]))
      case ("note", 2...): return .trace(.note(originalArgs.dropFirst().joined(separator: " ")))
      default: throw ParseError(usage)
      }
    case "summon":
      // A name can have spaces ("Visual Studio Code"). It ends up in replies, the log and, to find an app that
      // is not running, in a file name, so only what app names and bundle ids are made of gets in.
      let app = originalArgs.joined(separator: " ")
      let allowed = app.unicodeScalars.allSatisfy { scalar in
        scalar.properties.isAlphabetic || scalar.properties.numericType != nil || " .-_&+'()".unicodeScalars.contains(scalar)
      }
      guard !app.isEmpty, allowed, !app.hasPrefix("."), app.utf8.count <= 255 else {
        throw ParseError("usage: summon <app> (its name, like Terminal, or its bundle id, like com.apple.Terminal)")
      }
      return .summon(app: app)
    case "layout": return try parseLayout(typedArgs.joined(separator: " "))
    case "name": return args.isEmpty ? .unname(nil) : .name(try spaceName())
    case "unname": return .unname(args.isEmpty ? nil : try spaceName())
    case "spaces": return try noArgs(.spaces)
    case "ask-name":
      if args == ["cancel"] { return .askName(cancel: true) }
      guard args.isEmpty else { throw ParseError("usage: ask-name [cancel]") }
      return .askName(cancel: false)
    case "windows":
      guard args.isEmpty || args == ["--titles"] else { throw ParseError("usage: windows [--titles]") }
      return .listWindows(titles: !args.isEmpty)
    case "where": return try noArgs(.listPlaces)
    case "views": return try noArgs(.listViews)
    case "displays": return try noArgs(.listDisplays)
    case "focus":
      guard args.count == 1 else {
        throw ParseError("usage: focus <left|right|up|down> | focus next | focus previous | focus <window>")
      }
      // In quotes it is an app's name, whatever it says: `focus "next"`.
      if unquoted(typedArgs[0]) == nil, let target = FocusTarget(word: args[0]) { return .focus(target) }
      return .focus(.window(try window(0)))
    case "swap":
      switch args.count {
      case 1: return .swap(nil, try edge(args[0]))
      case 2:
        // In quotes it is an app's name, as after `focus`.
        if unquoted(typedArgs[1]) == nil, let direction = Edge(word: args[1]) { return .swap(try window(0), direction) }
        return .swapWindows(try window(0), try window(1))
      default:
        throw ParseError("usage: swap [window] <left|right|up|down> | swap <window> <window>")
      }
    case "equalize", "balance":
      guard args.isEmpty || args == ["all"] else { throw ParseError("usage: balance [all]") }
      return .equalize(all: !args.isEmpty)
    case "rotate": return try noArgs(.rotate)
    case "mirror": return try noArgs(.mirror)
    case "grow", "shrink":
      var amount: Double?
      if let word = args.first {
        // Positive, because the verb already says which way.
        guard args.count == 1, let value = try? points(word), value > 0 else {
          throw ParseError("usage: \(verb) [points] (a positive number, at most 1000000)")
        }
        amount = value
      }
      return verb == "grow" ? .grow(amount) : .shrink(amount)
    case "move-to-display":
      guard (1...2).contains(args.count), let target = DisplayTarget(word: args[0]) else {
        throw ParseError("usage: move-to-display <next|previous|number> [window]")
      }
      return .moveToDisplay(target, args.count == 2 ? try window(1) : nil)
    case "focus-display":
      guard args.count == 1, let target = DisplayTarget(word: args[0]) else {
        throw ParseError("usage: focus-display <next|previous|number>")
      }
      return .focusDisplay(target)
    case "watch":
      var kinds: [ArborEvent.Kind] = []
      for word in args where word != "--titles" {
        guard let kind = ArborEvent.Kind(rawValue: word) else {
          let names = ArborEvent.Kind.allCases.map(\.rawValue).joined(separator: ", ")
          throw ParseError("unknown event `\(word)`; the events are \(names), and --titles adds window titles")
        }
        kinds.append(kind)
      }
      return .watch(WatchOptions(kinds: kinds, titles: args.contains("--titles")))
    case "toggle-auto-dock": return try noArgs(.toggleAutoDock)
    case "show-shortcuts": return try noArgs(.showShortcuts)
    case "minimap": return try noArgs(.minimap)
    case "undo": return try noArgs(.undo)
    case "redo": return try noArgs(.redo)
    default:
      throw ParseError(unknown(verb))
    }
  }

  /// The canonical text form; `parse(text)` round-trips it for every command `parse` can produce.
  public var text: String {
    func w(_ window: WindowID?) -> String { window.map { " \($0.rawValue)" } ?? "" }
    switch self {
    case .status: return "status"
    case .state(let titles): return titles ? "state --titles" : "state"
    case .ascii: return "ascii"
    case .help: return "help"
    case .showAll: return "show-all"
    case .stepOut: return "out"
    case .stepIn: return "in"
    case .neighbor(let edge): return "neighbor \(edge.rawValue)"
    case .back: return "back"
    case .forward: return "forward"
    case .zoom(let window): return "zoom" + w(window)
    case .zoomNode(let node): return "zoom-node \(node.rawValue)"
    case .desktop: return "desktop"
    case .saveView(let slot): return "save-view \(slot)"
    case .goToView(let slot): return "view \(slot)"
    case .dock(let window, let edge): return "dock" + w(window) + " \(edge.rawValue)"
    case .dockBeside(let window, let target, let edge):
      return "dock" + w(window) + " beside \(target.rawValue) \(edge.rawValue)"
    case .float(let window): return "float" + w(window)
    case .toggleFloat(let window): return "toggle-float" + w(window)
    case .arrange: return "arrange"
    case .floatAll: return "float-all"
    case .resize(let window, let edge, let amount):
      return "resize" + w(window) + " \(edge.rawValue) \(Self.format(amount))"
    case .exclude(let bundle): return "exclude" + (bundle.map { " \($0)" } ?? "")
    case .include(let bundle): return "include \(bundle)"
    case .relayout: return "relayout"
    case .reloadSettings: return "reload-settings"
    case .quit: return "quit"
    case .bindings: return "bindings"
    case .rules: return "rules"
    case .frameRect(let x, let y, let width, let height):
      return "frame-rect \(Self.format(x)) \(Self.format(y)) \(Self.format(width)) \(Self.format(height))"
    case .home: return "home"
    case .pause(let minutes): return "pause" + (minutes.map { " \(Self.format($0))" } ?? "")
    case .resume: return "resume"
    case .togglePause: return "toggle-pause"
    case .floatAllHere: return "float-all here"
    case .arrangeAll: return "arrange all"
    case .doctor: return "doctor"
    case .checkSetup: return "check-setup"
    case .welcome: return "welcome"
    case .menuBar: return "menu-bar"
    case .menu: return "menu"
    case .passThrough(let bundle, let on):
      return "pass-through" + (bundle.map { " \($0)" } ?? "") + (on.map { $0 ? " on" : " off" } ?? "")
    case .pin(let window): return "pin" + w(window)
    case .unpin(let window): return "unpin" + w(window)
    case .togglePin(let window): return "toggle-pin" + w(window)
    case .watch(let options):
      return "watch" + options.kinds.map { " \($0.rawValue)" }.joined() + (options.titles ? " --titles" : "")
    case .stats(let reset): return reset ? "stats reset" : "stats"
    case .hold(let minutes): return "hold" + (minutes.map { " \(Self.format($0))" } ?? "")
    case .holdStill(let minutes): return "hold still" + (minutes.map { " \(Self.format($0))" } ?? "")
    case .release: return "release"
    case .toggleHold: return "toggle-hold"
    case .version: return "version"
    case .checkForUpdates: return "check-for-updates"
    case .launchAtLogin(let enabled): return "launch-at-login" + (enabled.map { $0 ? " on" : " off" } ?? "")
    case .settings(let command): return command.text
    case .find(let text): return "find" + (text.map { " \($0)" } ?? "")
    case .reveal(let window): return "reveal" + w(window)
    case .trace(.on(let name)): return "trace on" + (name.map { " \($0)" } ?? "")
    case .trace(.off): return "trace off"
    case .trace(.status): return "trace status"
    case .trace(.note(let text)): return "trace note \(text)"
    case .summon(let app): return "summon \(app)"
    case .layout(let spec, let display, let open):
      return Self.layoutText(display: display, options: open ? ["open"] : [], line: spec.text)
    case .printLayout(let display, let naming):
      return Self.layoutText(display: display, options: naming == .apps ? [] : [naming.rawValue], line: nil)
    case .name(let name): return "name \(name)"
    case .unname(let name): return "unname" + (name.map { " \($0)" } ?? "")
    case .goToSpace(let name): return "go \(name)"
    case .spaces: return "spaces"
    case .askName(let cancel): return cancel ? "ask-name cancel" : "ask-name"
    case .focus(let target): return "focus \(target.text)"
    case .swap(let window, let direction): return "swap" + w(window) + " \(direction.directionWord)"
    case .swapWindows(let first, let second): return "swap \(first.rawValue) \(second.rawValue)"
    case .equalize(let all): return all ? "balance all" : "balance"
    case .rotate: return "rotate"
    case .mirror: return "mirror"
    case .grow(let points): return "grow" + (points.map { " \(Self.format($0))" } ?? "")
    case .shrink(let points): return "shrink" + (points.map { " \(Self.format($0))" } ?? "")
    case .moveToDisplay(let target, let window): return "move-to-display \(target.text)" + w(window)
    case .focusDisplay(let target): return "focus-display \(target.text)"
    case .naming(let command, let names):
      return Self.text(of: command, names: names.count) { names[$0].text }
    case .listWindows(let titles): return titles ? "windows --titles" : "windows"
    case .listPlaces: return "where"
    case .listViews: return "views"
    case .listDisplays: return "displays"
    case .helpOn(let topic): return "help \(topic)"
    case .toggleAutoDock: return "toggle-auto-dock"
    case .showShortcuts: return "show-shortcuts"
    case .minimap: return "minimap"
    case .undo: return "undo"
    case .redo: return "redo"
    }
  }

  /// Whole numbers without the ".0". Safe for any double: `Int(_:)` traps on one that is too large,
  /// infinite or not a number.
  private static func format(_ value: Double) -> String {
    Int(exactly: value).map(String.init) ?? String(value)
  }

  public static let helpText = """
    Arbor commands. Use them as `arborctl dock left`, as the URL arbor://dock/left, or in settings.json's `bindings`.
    [window] is an app's name or bundle id (its most recently focused window), a number from `windows`, `focused` or
    `pointer`; leave it out to act on the focused window.
    <edge> is left, right, top or bottom (up and down work too); <direction> is left, right, up or down.
    "This display" is the focused window's, or the pointer's if the pointer moved last (setting: stepInToward).

    Look: change the view; the arrangement stays as it is
      show-all                     show everything on this display
      home                         show everything on every display: the way back from anywhere
      out | in                     step out a level | step in, toward the focused window or the pointer,
                                   whichever you touched last (also zoom-out, zoom-in)
      neighbor <edge>              move to the neighbouring space
      back | forward               where the view has been
      zoom [window]                frame one window on its own; without a window, again to return
      zoom-node <node>             frame a space by its node number from `state`
      desktop                      show the Desktop, where floating windows live
      save-view <1-9> | view <1-9>  save where you are looking | go back there
      frame-rect <x> <y> <w> <h>   frame what best fits a rectangle (what ⌃⌥-drag does)
      go <name>                    go to the space of that name, or the only one that begins so (go <edge>: neighbor)
      name <text> | unname [name]  name the space in view | take the name off it, or off the space of that name
      ask-name [cancel]            show a field to type the name into | close it
      focus <direction>            focus the nearest window that way; with none in view, go to the neighbouring
                                   space, and past the last space to the next display
      focus next | focus previous  go through the windows in view
      focus <window>               focus a window and bring it into view
      focus-display <next|previous|n>  focus the window that display had in focus last
      find [text…]                 open Go to…, or go to the window, space or saved view that matches best
      reveal [window]              bring a window into view, un-minimised and unhidden, and focus it
      minimap                      the whole arrangement in small, with the view marked; click a window in it to
                                   frame it; again to put it away

    Arrange: change where windows sit
      dock [window] <edge>                     dock at that edge of the view, or move a docked window one place
      dock [window] beside <window> <edge>     dock next to another window
      float [window] | toggle-float [window]   undock: the window floats on the Desktop
      arrange [all]                            dock every window on this display, or on all, in a grid
      float-all [here]                         undock everything: back to a normal Mac (here: this display only)
      resize [window] <edge> <points>          move the window's edge (negative shrinks)
      pin [window] | unpin | toggle-pin        keep a window in view wherever the view goes (a docked one floats first)
      summon <app>                             bring that app's window over the view; again, or turning to another
                                               window, sends it out of view (<app>: a name or a bundle id)
      layout [@display] [--open] <line>        arrange by a line of text: layout "Safari | Desktop | (Mail / Notes)"
                                               | side by side, / one above the other, ( ) group, [ ] tab group,
                                               :2 twice the size, Safari* all its other windows (docs/LAYOUTS.md)
      layout [@display] [--titles | --ids]     print the arrangement as such a line
      undo | redo                              take back the last change to this display's arrangement | put it back
      grow [points] | shrink [points]          make the focused window bigger or smaller (by `resizeStep`, 40, if not given)
      balance [all]                            equal sizes for everything in view, or on the whole display (also equalize)
      swap [window] <direction>                trade places with the nearest docked window that way; the places keep their sizes
      swap <window> <window>                   trade the places of two docked windows
      rotate | mirror                          turn the focused window's group from a row into a column, and back | reverse its order
      move-to-display <next|previous|n> [window]  send a window to another display, docked or floating as it was

    Arbor itself
      pause [minutes] | resume | toggle-pause    bring every window into view and leave windows, shortcuts and
                                                 gestures alone, until `resume` or for that many minutes
      hold [minutes] | release | toggle-hold     for a shared screen: keep the view exactly where it is, whatever
                                                 happens and whichever key is pressed; windows out of view stay there.
                                                 The key that pauses releases it, and pauses when pressed again
      hold still [minutes]                       for a call: the view moves when you ask, not by itself
      exclude [bundle-id] | include <bundle-id>  stop or resume arranging an app
      pass-through [bundle-id] [on|off]          shortcuts and gestures off in that app, for apps that need ⌃⌥
                                                 themselves; again, or `off`, to have them back
      relayout | reload-settings | quit
      status | state | ascii | help [command]    one line | everything as JSON | the layout as text | this
      state --titles                             with windows' titles and spaces' names, which `state` leaves out
      bindings                                   list the keyboard shortcuts in effect
      rules                                      per-app rules and which one the focused window matches
      watch [events…] [--titles]                 stream changes as lines of JSON (docs/SCRIPTING.md)
      doctor                                     check permissions, macOS settings, shortcuts and settings.json
      check-setup | welcome                      open the welcome window: what matters on this Mac | three moves to try
      menu-bar | menu                            the buttons the menu bar item shows, and where each is | its menu, as text
      stats [reset]                              what commands and calls to other apps cost | start counting afresh
      spaces                                     the named spaces, what they hold and where they are
      windows [--titles]                         the windows Arbor arranges, most recently focused first
      where | views                              what each display's view shows | the saved views
      toggle-auto-dock                           new windows dock beside the focused window | float, as usual
      version                                    this build, and what the last update check found
      check-for-updates                          ask GitHub for a newer release and offer its page
      launch-at-login [on|off]                   open Arbor at login, or not; without a word, answer on or off
      show-shortcuts                             the shortcuts in effect, on screen; any key or click puts them away

    Settings (each change applies at once and is saved; docs/SETTINGS.md)
      settings-window [pane | close]             open the settings window (at shortcuts, rules, appearance, …), or close it
      settings [--json]                          every setting: value, range, default and meaning
      set <key> <value> | get <key>              change or print one setting, e.g. set gap 16; set <key> toggle flips a switch
      reset <key> | reset all | reset everything back to the defaults (`all` keeps shortcuts, rules, lists of apps)
      bind <shortcut> <command>                  make a shortcut run a command, e.g. bind ctrl+opt+h dock left
      unbind <shortcut>                          make a shortcut do nothing
      set <list> add <app> | set <list> remove <app>   put an app on a list of apps, or take it off, e.g. set dont-arrange add Music
      rule add <bundle-id> <action> [title <text>]   add a rule; actions: float, ignore, pin, dock auto, dock <edge>,
                                                 dock beside <bundle-id> <edge>; `*` is any app
      rule change <n> <bundle-id> <action> [title <text>] | rule remove <n> | rule move <n> <place>
      trace on [name] | trace off | trace status record what macOS and Arbor tell each other (docs/TRACES.md)
      trace note <text>                          write a remark into the trace being recorded
      displays                                   the displays, and the options in effect on each
    """
}

/// The reply to a command, as sent over the control socket.
public struct CommandResult: Codable, Sendable, Equatable {
  public var ok: Bool
  public var message: String
  public var state: StateSnapshot?
  public var text: String?
  /// A query's answer for scripts; `text` is the same for people. `arborctl --json` prints it.
  public var json: JSONValue?
  /// What a person should hear beside the answer, which stays a table or JSON. `arborctl` prints it on stderr; the command has still worked.
  public var warning: String?

  public init(
    ok: Bool, message: String, state: StateSnapshot? = nil, text: String? = nil, json: JSONValue? = nil, warning: String? = nil
  ) {
    self.ok = ok
    self.message = message
    self.state = state
    self.text = text
    self.json = json
    self.warning = warning
  }

  public static func success(_ message: String) -> CommandResult { .init(ok: true, message: message) }
  public static func failure(_ message: String) -> CommandResult { .init(ok: false, message: message) }
}
