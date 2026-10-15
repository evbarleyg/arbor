import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// Decides what happens next. It looks at the world so that most actions make sense there (a docked
/// window is dragged onto another window's edge, a tile that exists is clicked), and now and then
/// picks something that does not (a window that closed, a node from another tree, a point in the void).
@MainActor
public struct ChaosGenerator {
  var random: ChaosRandom
  /// Steps already decided: the setup, and the rest of a gesture that takes several actions. Other
  /// actions slip in between them now and then, which is where the interesting orders come from.
  var planned: [ChaosAction] = []
  var nextWindow: UInt32 = 101
  /// Some runs have apps that fight back. They make rules about frames moot for their windows and
  /// keep timers alive, so most runs do without.
  private let allowsMisbehaviour: Bool
  /// `ARBOR_CHAOS_DESKS=1`: walks about displays. Ten times as many changes of displays, in the orders a Mac has; each display keeps
  /// its size, as a thing on a desk does; and after half the changes the commands that place floating windows again.
  private let desks = ProcessInfo.processInfo.environment["ARBOR_CHAOS_DESKS"] != nil
  private var sizesOnTheDesk: [String: CGSize] = [:]
  private let twoDisplays = ProcessInfo.processInfo.environment["ARBOR_CHAOS_TWO_DISPLAYS"] != nil
  /// `ARBOR_CHAOS_ORDINARY=1`: walks a person could take, on a real desk (ChaosGenerator+Ordinary.swift).
  /// What this walk draws its commands and settings from (ChaosGenerator+Vocabulary.swift).
  private let weightedKinds: [(weight: Int, value: CommandKind)]
  private let settingEntries: [SettingEntry]
  /// Whether this walk's seed lies beyond the frozen versions.
  let drawsFromEverything: Bool
  private let ordinary: Bool
  /// Of the ordinary walks, those of a person who knows the nine keys, the menu and the mouse (ChaosGenerator+Ordinary.swift).
  let light: Bool
  var desk: Desk

  public init(
    seed: UInt64, ordinary: Bool = ProcessInfo.processInfo.environment["ARBOR_CHAOS_ORDINARY"] != nil,
    light: Bool = ProcessInfo.processInfo.environment["ARBOR_CHAOS_ORDINARY"] == "light"
  ) {
    self.ordinary = ordinary || light
    weightedKinds = Self.vocabulary(for: seed, of: CommandKind.allCases, frozen: Self.frozenCommandKinds) { "\($0)" }.map { (Self.weight(of: $0), $0) }
    drawsFromEverything = seed / Self.seedsInAVersion >= UInt64(Self.frozenCommandKinds.count)
    settingEntries = Self.vocabulary(for: seed, of: SettingsSchema.entries, frozen: Self.frozenSettings, name: \.key)
    self.light = light
    random = ChaosRandom(seed: seed)
    allowsMisbehaviour = random.chance(30)
    // From a stream of its own, so that the other walks are what they were.
    var forTheDesk = ChaosRandom(seed: seed &+ 0x5EED)
    desk = Desk(&forTheDesk)
    if self.ordinary {
      startOrdinaryWalk()
      return
    }
    // A script starts from one standard display, no windows and Arbor not running.
    if random.chance(50) { planned.append(.displays(arrangement(), .never)) }
    if random.chance(30) { planned.append(.settings(settingsChange())) }
    // `ARBOR_CHAOS_TWO_DISPLAYS=1`: two displays that stay, two windows docked on one, two floating on the other; holds at eight times their weight.
    if twoDisplays {
      planned = [
        "displays main:0,0,1440,900:25,0,0,0* side:1440,-90,1920,1080:0,0,0,0 windows-never", "open 101 Safari pid 1000 at 100 100 700 500 min 574 240",
        "open 102 Notes pid 1001 at 300 200 720 420 min 709 300", "open 103 Terminal pid 1003 at 1700 100 585 400",
        "open 104 Mail pid 1002 at 2300 300 800 600 min 500 400", "launch", "dock 101 left", "dock 102 right", "settle",
      ].map { ChaosAction(text: $0) }
    }
    // Everything that ships switched off, switched on together (`ARBOR_CHAOS_ALL_ON=1`).
    if ProcessInfo.processInfo.environment["ARBOR_CHAOS_ALL_ON"] != nil {
      planned.append(
        .settings(
          "{\"tabsEnabled\":true,\"summonStays\":true,\"continuousZoom\":true,\"guardDesktopClicks\":true,"
            + "\"reflowWhileDragging\":true,\"soleFloatTakesDesktop\":true,\"windowPictures\":true,\"scrollOnDesktopZooms\":true,"
            + "\"holdStillWhileMicrophoneIsOn\":true,\"allowAllURLCommands\":true,\"newWindows\":\"dock\",\"pointerGestures\":true,\"floatingWindowsMakeWay\":true}"))
    }
  }

  // MARK: Commands

  /// One name per `Command` case, so that `allCases` can be walked.
  ///
  /// ADDED A COMMAND AND THE BUILD BROKE HERE? Add its name to this enum and to `kind(of:)`, then give
  /// `command(_:in:)` a line that builds one with random arguments, and `weight(of:)` a number.
  public enum CommandKind: CaseIterable, Sendable {
    case status, state, ascii, help, showAll, stepOut, stepIn, neighbor, back, forward, zoom, zoomNode, desktop
    case saveView, goToView, dock, dockBeside, float, toggleFloat, arrange, floatAll, resize, exclude, include
    case relayout, reloadSettings, quit, bindings, rules, frameRect
    case home, pause, resume, togglePause, floatAllHere, arrangeAll
    case passThrough
    case pin, unpin, togglePin
    case stats
    case version, checkForUpdates, launchAtLogin
    case settings
    case trace
    case summon
    case layout, printLayout
    case name, unname, goToSpace, spaces, askName
    case doctor, checkSetup, welcome, menuBar, menu
    case toggleAutoDock
    case focus, swap, swapWindows, equalize, rotate, mirror, grow, shrink, moveToDisplay, focusDisplay
    case hold, holdStill, release, toggleHold
    case undo, redo
    case watch, find, reveal, displays
    case showShortcuts
    case minimap
    case fixSetup
    case sideBySide
  }

  /// No `default`, on purpose: a new `Command` case does not compile until it is listed here.
  public static func kind(of command: Command) -> CommandKind {
    switch command {
    case .status: .status
    case .state: .state
    case .ascii: .ascii
    case .help: .help
    case .showAll: .showAll
    case .stepOut: .stepOut
    case .stepIn: .stepIn
    case .neighbor: .neighbor
    case .back: .back
    case .forward: .forward
    case .zoom: .zoom
    case .zoomNode: .zoomNode
    case .desktop: .desktop
    case .saveView: .saveView
    case .goToView: .goToView
    case .dock: .dock
    case .dockBeside: .dockBeside
    case .float: .float
    case .toggleFloat: .toggleFloat
    case .arrange: .arrange
    case .floatAll: .floatAll
    case .resize: .resize
    case .exclude: .exclude
    case .include: .include
    case .relayout: .relayout
    case .reloadSettings: .reloadSettings
    case .quit: .quit
    case .bindings: .bindings
    case .rules: .rules
    case .frameRect: .frameRect
    case .home: .home
    case .pause: .pause
    case .resume: .resume
    case .togglePause: .togglePause
    case .floatAllHere: .floatAllHere
    case .arrangeAll: .arrangeAll
    case .passThrough: .passThrough
    case .pin: .pin
    case .unpin: .unpin
    case .togglePin: .togglePin
    case .stats: .stats
    case .version: .version
    case .checkForUpdates: .checkForUpdates
    case .launchAtLogin: .launchAtLogin
    case .settings: .settings
    case .trace: .trace
    case .summon: .summon
    case .layout: .layout
    case .printLayout: .printLayout
    case .name: .name
    case .unname: .unname
    case .goToSpace: .goToSpace
    case .spaces: .spaces
    case .askName: .askName
    case .doctor: .doctor
    case .checkSetup: .checkSetup
    case .welcome: .welcome
    case .menuBar: .menuBar
    case .menu: .menu
    case .toggleAutoDock: .toggleAutoDock
    case .focus: .focus
    case .swap: .swap
    case .swapWindows: .swapWindows
    case .equalize: .equalize
    case .rotate: .rotate
    case .mirror: .mirror
    case .grow: .grow
    case .shrink: .shrink
    case .moveToDisplay: .moveToDisplay
    case .focusDisplay: .focusDisplay
    case .fixSetup: .fixSetup
    case .hold: .hold
    case .holdStill: .holdStill
    case .release: .release
    case .toggleHold: .toggleHold
    case .undo: .undo
    case .redo: .redo
    case .watch: .watch
    case .find: .find
    case .reveal: .reveal
    case .displays: .displays
    case .showShortcuts: .showShortcuts
    case .minimap: .minimap
    case .sideBySide: .sideBySide
    }
  }

  /// A command of this kind with random arguments, mostly ones that exist.
  public mutating func command(_ kind: CommandKind, in world: ChaosRunner) -> Command {
    switch kind {
    case .status: return .status
    case .state: return .state(titles: false)
    case .ascii: return .ascii
    case .help: return .help
    case .showAll: return .showAll
    case .stepOut: return .stepOut
    case .stepIn: return .stepIn
    case .neighbor: return .neighbor(edge())
    case .back: return .back
    case .forward: return .forward
    case .zoom: return .zoom(optionalWindow(in: world))
    case .zoomNode: return .zoomNode(node(in: world))
    case .desktop: return .desktop
    case .saveView: return .saveView(random.int(1...9))
    case .goToView: return .goToView(random.int(1...9))
    case .dock: return .dock(optionalWindow(in: world), edge())
    case .dockBeside: return .dockBeside(optionalWindow(in: world), target: window(in: world, .docked), edge())
    case .float: return .float(optionalWindow(in: world, .docked))
    case .toggleFloat: return .toggleFloat(optionalWindow(in: world))
    case .arrange: return .arrange
    case .floatAll: return .floatAll
    case .resize:
      let amount =
        random.chance(10) ? Double(random.int(-20_000...20_000)) / 8
        : random.chance(5) ? Double(random.int(-1_000_000...1_000_000)) : Double(random.int(-400...400))
      return .resize(optionalWindow(in: world, .docked), edge(), amount)
    case .exclude: return .exclude(bundleID: random.chance(30) ? nil : bundleID(in: world))
    case .include: return .include(bundleID: random.pick(world.controller.settings.excludedBundleIDs) ?? bundleID(in: world))
    case .relayout: return .relayout
    case .reloadSettings: return .reloadSettings
    case .quit: return .quit
    case .bindings: return .bindings
    case .rules: return .rules
    case .frameRect:
      if random.chance(10) {
        let n = { (r: inout ChaosRandom) in Double(r.int(-1_000_000...1_000_000)) }
        return .frameRect(x: n(&random), y: n(&random), width: n(&random), height: n(&random))
      }
      let (a, b) = (point(in: world), point(in: world))
      return .frameRect(x: Double(a.x), y: Double(a.y), width: Double(b.x - a.x), height: Double(b.y - a.y))
    case .home: return .home
    case .pause: return .pause(minutes: random.pick([nil, nil, 0.001, 0.5, 1, 1440]) ?? nil)
    case .resume: return .resume
    case .togglePause: return .togglePause
    case .floatAllHere: return .floatAllHere
    case .arrangeAll: return .arrangeAll
    case .passThrough: return .passThrough(bundleID: random.chance(30) ? nil : bundleID(in: world))
    case .pin: return .pin(optionalWindow(in: world))
    case .unpin: return .unpin(optionalWindow(in: world))
    case .togglePin: return .togglePin(optionalWindow(in: world, .floating))
    case .stats: return .stats(reset: random.chance(30))
    case .version: return .version
    case .checkForUpdates: return .checkForUpdates
    case .launchAtLogin: return .launchAtLogin(random.pick([nil, true, false]) ?? nil)
    case .settings:
      // Parsing puts keys and values in their canonical spelling, which is what the text form gives back.
      return (try? Command.parse(Command.settings(settingsCommand(in: world)).text)) ?? .settings(.list(.text))
    case .summon:
      // By name or by bundle id; now and then an app that is not running or does not exist.
      let app = random.pick(Self.apps)!
      return .summon(app: random.chance(10) ? "Nobody" : random.chance(30) ? "com.example.\(app.lowercased())" : app)
    case .trace:
      // Recording must change nothing.
      return .trace(random.pick([.status, .on(name: "chaos"), .off, .note("chaos")]) ?? .status)
    case .layout:
      // Apps that may have no window, one or several; side by side, one above the other, nested.
      let (a, b, c) = (random.pick(Self.apps)!, random.pick(Self.apps)!, random.pick(Self.apps)!)
      let line = random.pick(["\(a)", "\(a) | \(b)", "\(a) / \(b)", "\(a) | \(b) | \(c)", "\(a) | (\(b) / \(c))"])!
      // Never with `--open`: launching apps is the window system's business.
      return (try? Command.parse("layout \(line)")) ?? (try! Command.parse("layout \(a)"))
    case .printLayout: return .printLayout(display: nil, naming: random.pick(LayoutNotation.Naming.allCases)!)
    case .name: return .name(random.pick(Self.spaceNames)!)
    case .unname: return .unname(random.chance(50) ? nil : random.pick(Self.spaceNames)!)
    case .goToSpace: return .goToSpace(random.pick(Self.spaceNames)!)
    case .spaces: return .spaces
    case .askName: return .askName(cancel: random.chance(50))
    case .doctor: return .doctor
    case .checkSetup: return .checkSetup
    case .welcome: return .welcome
    case .menuBar: return .menuBar
    case .menu: return .menu
    case .toggleAutoDock: return .toggleAutoDock
    case .focus:
      return .focus(random.chance(60) ? .direction(edge()) : random.chance(30) ? .window(window(in: world)) : random.chance(50) ? .next : .previous)
    case .swap: return .swap(optionalWindow(in: world, .docked), edge())
    case .swapWindows: return .swapWindows(window(in: world, .docked), window(in: world, .docked))
    case .equalize: return .equalize(all: random.chance(30))
    case .rotate: return .rotate
    case .mirror: return .mirror
    case .grow: return .grow(step())
    case .shrink: return .shrink(step())
    case .moveToDisplay: return .moveToDisplay(displayTarget(), optionalWindow(in: world))
    case .focusDisplay: return .focusDisplay(displayTarget())
    case .fixSetup: return .fixSetup(undo: random.pick([false, true]) ?? false)
    case .hold: return .hold(minutes: random.pick([nil, nil, 0.001, 0.5, 1, 1440]) ?? nil)
    case .holdStill: return .holdStill(minutes: random.pick([nil, nil, 0.001, 0.5, 1, 1440]) ?? nil)
    case .release: return .release
    case .toggleHold: return .toggleHold
    case .undo:
      // Half the time with `redo` straight after, which is what the rule "undo, redo is the identity" looks at.
      if random.chance(50) { planned.insert(.command("redo"), at: 0) }
      return .undo
    case .redo: return .redo
    // Without a connection to stream to it only says so.
    case .watch: return .watch(WatchOptions(kinds: [], titles: random.chance(50)))
    case .find:
      // The palette, opened or closed; or straight to an app's window, now and then one that is not there.
      return .find(random.chance(30) ? nil : random.chance(10) ? "Nobody" : random.pick(Self.apps)!)
    case .reveal: return .reveal(optionalWindow(in: world))
    case .displays: return .displays
    case .showShortcuts: return .showShortcuts
    case .minimap: return .minimap
    case .sideBySide:
      // Two to four, each once where there are that many: what Go to… can send.
      var picked: [WindowID] = []
      for _ in 0..<(random.int(2...4) * 3) where picked.count < 4 {
        let next = window(in: world)
        if !picked.contains(next) { picked.append(next) }
      }
      // On a desk with one window or none: numbers nobody has, which is refused in words like any other.
      while picked.count < 2 { picked.append(WindowID(nextWindow + 20 + UInt32(picked.count))) }
      return .sideBySide(Array(picked.prefix(random.int(2...4))))
    }
  }

  /// `set`, `reset`, `bind`, `rule` and the rest. The schema lists every setting there is, with the values it takes, so a
  /// new setting is tried from the day it is listed there.
  private mutating func settingsCommand(in world: ChaosRunner) -> SettingsCommand {
    let entry = random.pick(settingEntries)!
    func rule(_ r: inout ChaosRandom) -> AppRule {
      let action = r.pick([
        RuleAction.float, .ignore, .pin, .dock(.left), .dock(.right), .dock(.top), .dockBeside(bundleID: "com.example.notes", .bottom),
      ])!
      return AppRule(app: "com.example.\(r.pick(Self.apps)!.lowercased())", title: r.chance(20) ? r.pick(Self.titles) : nil, action: action)
    }
    let rules = world.controller.settings.rules.count
    switch random.int(0...19) {
    case 0...11:
      switch entry.kind {
      case .toggle: return .set(key: entry.key, value: random.chance(50) ? "on" : "off")
      case .number(let range, let step, _):
        let steps = Int(((range.upperBound - range.lowerBound) / max(step, 1e-6)).rounded(.down))
        let value =
          random.chance(25) ? random.pick([range.lowerBound, range.upperBound])!
          : range.lowerBound + Double(random.int(0...min(max(steps, 1), 400))) * step
        return .set(key: entry.key, value: ChaosAction.format(min(value, range.upperBound)))
      case .choice(let choices): return .set(key: entry.key, value: random.pick(choices)!.value)
      case .text(let example): return .set(key: entry.key, value: example)
      case .list: return .get(key: entry.key)
      }
    case 12: return .get(key: entry.key)
    case 13: return .list(random.pick(SettingsCommand.ListFormat.allCases)!)
    case 14, 15: return .reset(key: entry.key)
    case 16: return .resetAll(everything: random.chance(30))
    case 17: return .addRule(rule(&random))
    case 18: return rules > 0 && random.chance(60) ? .changeRule(random.int(1...rules), rule(&random)) : .removeRule(random.int(1...max(rules, 1)))
    default: return .moveRule(random.int(1...max(rules, 1)), to: random.int(1...max(rules, 1)))
    }
  }


  static func weight(of kind: CommandKind) -> Int {
    switch kind {
    case .status, .help, .bindings, .rules: 1
    case .state, .ascii: 3
    case .showAll: 8
    case .stepOut, .stepIn: 10
    case .neighbor: 10
    case .back, .forward: 8
    case .zoom: 12
    case .zoomNode: 10
    case .desktop: 6
    case .saveView, .goToView: 6
    case .dock: 30
    case .dockBeside: 26
    case .float: 8
    case .toggleFloat: 8
    case .arrange: 4
    case .floatAll: 2
    case .resize: 12
    case .exclude: 3
    case .include: 4
    case .relayout, .reloadSettings: 2
    case .quit: 2
    case .frameRect: 8
    case .home: 5
    case .pause, .togglePause: 2
    case .resume: 1
    case .floatAllHere: 2
    case .arrangeAll: 3
    case .passThrough: 2
    case .pin: 6
    case .unpin: 2
    case .togglePin: 4
    case .stats: 1
    case .version, .checkForUpdates, .launchAtLogin: 1
    case .settings: 14
    case .trace: 2
    case .summon: 10
    case .layout: 6
    case .printLayout, .spaces: 1
    case .name: 6
    case .unname: 2
    case .goToSpace: 6
    case .askName: 1
    case .doctor, .checkSetup, .welcome, .menuBar, .menu: 1
    case .toggleAutoDock: 2
    case .focus: 12
    case .swap, .swapWindows: 8
    case .equalize: 4
    case .rotate, .mirror: 6
    case .grow, .shrink: 8
    case .moveToDisplay: 8
    case .focusDisplay: 4
    case .fixSetup: 1
    case .hold, .holdStill, .toggleHold: ProcessInfo.processInfo.environment["ARBOR_CHAOS_HOLDS"] == nil && ProcessInfo.processInfo.environment["ARBOR_CHAOS_TWO_DISPLAYS"] == nil ? 1 : 8
    case .release: ProcessInfo.processInfo.environment["ARBOR_CHAOS_HOLDS"] == nil && ProcessInfo.processInfo.environment["ARBOR_CHAOS_TWO_DISPLAYS"] == nil ? 1 : 6
    case .undo: 30
    case .redo: 8
    case .watch, .displays: 1
    case .find, .reveal: 8
    case .showShortcuts: 2
    case .minimap: 3
    case .sideBySide: 6
    }
  }

  /// Lines no well-behaved client sends. `Command.parse` has to turn every one of them down politely.
  private static let nonsense = [
    "", " ", "/", "//", "dock", "dock 101", "dock sideways", "dock 101 beside", "dock 101 beside 101 left",
    "dock 101 beside 99999999999999999999 left", "dock -1 left", "zoom -1", "zoom w", "zoom 4294967296", "zoom 1e3",
    "zoom-node", "zoom-node n", "zoom-node 9223372036854775808", "zoom-node -9223372036854775808", "view 0", "view 10",
    "view -1", "save-view", "save-view 1.5", "resize", "resize left", "resize 101 left", "resize 101 left ten",
    "resize right 1e300", "resize right -1e308", "resize right nan", "resize right inf", "resize right -inf", "resize right 1000001",
    "frame-rect", "frame-rect 1 2 3", "frame-rect nan 0 100 100", "frame-rect inf 0 100 100", "frame-rect 1e9 0 1 1",
    "frame-rect 0 0 -100 -100", "frame-rect 0 0 0 0", "include", "exclude a b c", "neighbor", "neighbor in", "help me",
    "quit now", "état", "🪟", "DOCK LEFT", "show-all show-all", "pause 0", "pause -1", "pause 1441", "pause nan", "pause 1 2",
    "arrange some", "float-all there", "exclude com.example.a/b", "exclude é", "include ..", "dock\tleft",
  ]

  /// What a web page might ask macOS to open.
  private static let hostileURLs = [
    "arbor://", "arbor:", "arbor", "http://dock/left", "arbor://quit", "arbor://pause", "arbor://exclude/com.example.safari",
    "arbor://float-all", "arbor://dock/left?x=1#y", "arbor://dock%20left", "arbor://dock/%", "arbor://dock/%zz", "arbor://dock/%ff",
    "arbor://zoom/%31%30%31", "ARBOR://SHOW-ALL", "arbor:///show-all///", "arbor://state", "arbor://zoom/99999999999",
  ]

  // MARK: The next action

  public mutating func next(_ world: ChaosRunner) -> ChaosAction {
    if ordinary { return ordinaryNext(world) }
    if !planned.isEmpty, twoDisplays || random.chance(80) { return planned.removeFirst() }
    guard world.isRunning else { return world.isPaused ? whilePaused(world) : whileStopped(world) }

    let system = world.system
    let windows = system.windows.count
    let holding = system.dragging != nil
    let resizing = system.resizing != nil
    let down = system.mouseDown
    let tiles = world.harness.overlays.tiles.values.reduce(0) { $0 + $1.count }
    let seams = world.harness.overlays.seams.values.reduce(0) { $0 + $1.count }

    enum Kind {
      case open, close, quitApp, minimize, hide, space, spaceSwitch, fullScreen, title, limits, behave, move, react
      case cursor, focus, switchApp, focusNothing, backgroundFocus, press, drag, carry, release, edge, tile, palette, seam, command, nonsense, url
      case displays, settings, flush, advance, settle, save, crash
      case loseRelease, via, key, pinch, activate, hang, openTab, selectTab, closeTab, list, doubleClick
    }
    let tabs = system.backgroundTabs.count
    let kind =
      random.pick(weighted: [
        (windows < 4 ? 120 : windows < 10 ? 40 : 4, Kind.open),
        (windows > 2 ? 22 : 4, .close),
        (3, .quitApp),
        (28, .minimize),
        (12, .hide),
        (14, .space),
        (8, .spaceSwitch),
        (10, .fullScreen),
        (4, .title),
        (8, .limits),
        (allowsMisbehaviour ? 5 : 0, .behave),
        (36, .move),
        (system.hasHeldEchoes ? 90 : 2, .react),
        (36, .cursor),
        (44, .focus),
        (12, .switchApp),
        (6, .focusNothing),
        (8, .backgroundFocus),
        (down ? 0 : 4, .press),
        (down ? 0 : 50, .drag),
        (holding ? 160 : 0, .carry),
        (down ? 110 : 2, .release),
        (holding ? 0 : resizing ? 90 : down ? 0 : 36, .edge),
        (tiles > 0 ? 30 : 3, .tile),
        (world.harness.overlays.finder != nil ? 1500 : 1, .palette),
        (seams > 0 ? 28 : 1, .seam),
        (380, .command),
        (10, .nonsense),
        (12, .url),
        (twoDisplays ? 0 : desks ? 160 : 16, .displays),
        (16, .settings),
        (60, .flush),
        (36, .advance),
        (30, .settle),
        (4, .save),
        (4, .crash),
        (holding ? 12 : 0, .loseRelease),
        (60, .via),
        (24, .key),
        (10, .pinch),
        (8, .activate),
        (system.unresponsive.isEmpty ? (allowsMisbehaviour ? 5 : 0) : 30, .hang),
        (windows > 0 && tabs < 3 ? 8 : 0, .openTab),
        (tabs > 0 ? 12 : 0, .selectTab),
        (tabs > 0 ? 8 : 0, .closeTab),
        (system.unlisted.isEmpty ? 0 : 20, .list),
        (down ? 0 : 16, .doubleClick),
      ]) ?? .flush

    switch kind {
    case .open:
      let new = newWindow(in: world)
      // A new window usually takes the focus.
      if random.chance(70) { planned.insert(.focus(new.id), at: 0) }
      return .open(new)
    case .loseRelease: return .loseRelease
    case .doubleClick: return .doubleClick(window(in: world, random.chance(90) ? .inView : .any))
    case .via:
      return .via(random.pick([.shortcut, .shortcut, .menu, .gesture])!, command(random.pick(weighted: weightedKinds)!, in: world).text)
    case .key:
      // Held for a while, with whatever else happens meanwhile, then let go. Show Everything held is a peek.
      let bindings = world.controller.activeBindings + world.controller.temporaryShortcuts
      guard let binding = random.chance(40) ? bindings.first(where: { $0.command == .showAll }) : random.pick(bindings) else { return .flush }
      var rest: [ChaosAction] = []
      for _ in 0..<random.int(0...3) { rest.append(.advance(random.pick([0.05, 0.1, 0.3, 0.5])!)) }
      planned.insert(contentsOf: rest + [.key(binding.command.text, .released)], at: 0)
      return .key(binding.command.text, .pressed)
    case .pinch:
      var rest: [ChaosAction] = []
      for _ in 0..<random.int(0...4) { rest.append(.pinch(.changed, Double(random.int(-60...60)) / 100)) }
      planned.insert(contentsOf: rest + [.pinch(random.chance(85) ? .ended : .cancelled, 0)], at: 0)
      return .pinch(.began, 0)
    case .activate: return .activate(bundleID(in: world))
    case .hang:
      // An app that hangs wakes up sooner or later.
      if let hung = system.unresponsive.sorted().first, random.chance(70) { return .hang(pid: hung, false) }
      return .hang(pid: pid(in: world), true)
    case .openTab:
      nextWindow += 1
      return .openTab(WindowID(nextWindow - 1), in: window(in: world))
    case .selectTab, .closeTab:
      guard let tab = random.pick(world.frontOfTab.keys.sorted()), let front = world.frontOfTab[tab] else { return .flush }
      return kind == .selectTab ? .selectTab(tab, insteadOf: front) : .closeTab(front, revealing: tab)
    case .list: return .listed(random.pick(system.unlisted.keys.sorted())!, true)
    case .close: return .close(window(in: world))
    case .quitApp: return .quitApp(pid: pid(in: world))
    case .minimize:
      let id = window(in: world)
      return .minimize(id, !(system.windows[id]?.snapshot.isMinimized ?? random.chance(50)))
    case .hide:
      let pid = pid(in: world)
      let hidden = system.windows.values.contains { $0.snapshot.pid == pid && $0.snapshot.isHidden }
      return .hide(pid: pid, !hidden)
    case .space:
      let id = window(in: world)
      return .space(id, showing: !(system.windows[id]?.snapshot.isOnActiveSpace ?? random.chance(50)))
    case .spaceSwitch:
      // As AXWindowSystem reports a switch: the windows that left, the windows that came, then the timer.
      let all = system.windows.keys.sorted()
      let leaving = all.filter { system.windows[$0]!.snapshot.isOnActiveSpace && random.chance(40) }
      let coming = all.filter { !system.windows[$0]!.snapshot.isOnActiveSpace && random.chance(70) }
      planned.insert(
        contentsOf: leaving.map { .space($0, showing: false) } + coming.map { .space($0, showing: true) } + [.flush], at: 0)
      return planned.removeFirst()
    case .fullScreen:
      let id = window(in: world)
      return .fullScreen(id, !(system.windows[id]?.snapshot.isFullScreen ?? random.chance(50)))
    case .title: return .title(window(in: world), random.pick(Self.titles)!)
    case .limits:
      let (minimum, maximum) = limits()
      return .limits(window(in: world), minimum: minimum, maximum: maximum)
    case .behave: return .behave(window(in: world), random.pick(FakeWindowSystem.Behaviour.allCases)!)
    case .move:
      let id = window(in: world, random.chance(60) ? .inView : .any)
      return .move(id, movedFrame(of: id, in: world))
    case .react: return .react
    case .cursor: return .cursor(point(in: world))
    case .focus: return .focus(window(in: world))
    case .switchApp: return .switchApp(window(in: world))
    case .focusNothing: return .focusNothing
    case .backgroundFocus: return .backgroundFocus(window(in: world))
    case .press: return .press
    case .drag:
      // Pick it up, carry it through a few places, drop it. A drop with no carry is a click.
      let id = window(in: world, random.chance(90) ? .inView : .any)
      var gesture: [ChaosAction] = []
      for _ in 0..<random.int(0...3) { gesture.append(.carry(point(in: world, dragging: id))) }
      // A target counts once the pointer has rested on it (F09).
      if random.chance(60) { gesture.append(.advance(random.pick([0.1, 0.2, 0.3])!)) }
      // ⌘ goes down somewhere on the way.
      if random.chance(15) { gesture.insert(.commandKey(held: true), at: random.int(0...gesture.count)) }
      gesture.append(.release)
      if gesture.contains(.commandKey(held: true)) { gesture.append(.commandKey(held: false)) }
      planned.insert(contentsOf: gesture, at: 0)
      return .grab(id)
    case .carry: return .carry(point(in: world, dragging: system.dragging))
    case .release: return .release
    case .edge:
      let id = system.resizing ?? window(in: world, random.chance(90) ? .inView : .any)
      let hold = random.chance(35)
      if hold { planned.insert(.release, at: 0) }
      return .edge(id, resizedFrame(of: id, in: world), hold: hold)
    case .tile:
      let all = world.harness.overlays.tiles.sorted(by: { $0.key < $1.key }).flatMap(\.value)
      if let tile = random.pick(all), random.chance(90) { return .tile(tile.display, tile.node) }
      return .tile(displayID(in: world), node(in: world))
    case .palette:
      switch random.pick(weighted: [(30, 0), (20, 1), (40, 2), (10, 3)]) ?? 0 {
      case 0:
        // The beginning of a word, as someone who types sees the list narrow. A script is split at spaces, so none at the end.
        let word = random.chance(20) ? "" : random.pick(Self.apps + ["v1", "view 2", "zzz", "é /"])!
        return .palette(.type(word.prefix(random.int(1...6)).trimmingCharacters(in: .whitespaces)))
      case 1: return .palette(.move(random.int(-12...12)))
      case 2: return .palette(.choose(random.chance(60) ? nil : random.int(0...10)))
      default: return .palette(.escape)
      }
    case .seam:
      let display = displayID(in: world)
      let count = world.harness.overlays.seams[display]?.count ?? 0
      let delta = random.chance(10) ? random.int(-5000...5000) : random.int(-400...400)
      return .seam(display, index: random.int(0...max(count, 1)), delta: Double(delta))
    case .command:
      return .command(command(random.pick(weighted: weightedKinds)!, in: world).text)
    case .nonsense: return .command(random.pick(Self.nonsense)!)
    case .url:
      if random.chance(30) { return .url(random.pick(Self.hostileURLs)!) }
      let words = command(random.pick(weighted: weightedKinds)!, in: world).text.split(separator: " ")
      return .url("arbor://" + words.joined(separator: "/"))
    case .displays:
      guard desks else {
        // `ARBOR_CHAOS_WINDOWS_FIRST=1`: mostly the order in which the windows speak before the displays do.
        let mostlyFirst = ProcessInfo.processInfo.environment["ARBOR_CHAOS_WINDOWS_FIRST"] != nil
        let change = ChaosAction.displays(
          arrangement(), random.pick(weighted: [(mostlyFirst ? 12 : 2, .first), (5, .late), (5, .silent), (1, .never)])!)
        // Half the time a window has spoken of its place a while before: what Arbor believes for some seconds is tried at every age.
        if mostlyFirst, random.chance(50), !world.system.windows.isEmpty {
          planned.insert(contentsOf: [.advance(Double(random.int(1...40))), change], at: 0)
          let id = window(in: world, .inView)
          return .move(id, movedFrame(of: id, in: world))
        }
        return change
      }
      // A frame remembered in the old coordinates is applied by the next layout that places floating windows.
      if random.chance(50) { planned.insert(contentsOf: ["home", "relayout", "desktop", "home"].map { .command($0) }, at: 0) }
      return .displays(arrangement(), random.chance(50) ? .late : .silent)
    case .settings: return .settings(settingsChange())
    case .flush: return .flush
    case .advance: return .advance(random.pick([0, 0.1, 0.25, 0.3, 0.5, 1, 5])!)
    case .settle: return .settle
    case .save: return .save
    case .crash: return .crash
    }
  }

  /// Arbor is paused: it is not looking, whatever happens, until it is told to resume or the time is up.
  private mutating func whilePaused(_ world: ChaosRunner) -> ChaosAction {
    enum Kind { case resume, open, close, move, minimize, focus, displays, settings, time, command, crash }
    let kind =
      random.pick(weighted: [
        (24, Kind.resume), (12, .open), (8, .close), (10, .move), (6, .minimize), (6, .focus), (5, .displays), (3, .settings),
        (12, .time), (12, .command), (2, .crash),
      ]) ?? .resume
    switch kind {
    case .resume: return .command(random.chance(60) ? "resume" : "toggle-pause")
    case .open: return .open(newWindow(in: world))
    case .close: return .close(window(in: world))
    case .move:
      let id = window(in: world)
      return .move(id, movedFrame(of: id, in: world))
    case .minimize: return .minimize(window(in: world), random.chance(50))
    case .focus: return .focus(window(in: world))
    case .displays: return .displays(arrangement(), random.chance(80) ? .first : .never)
    case .settings: return .settings(settingsChange())
    case .time: return random.chance(50) ? .flush : .advance(random.pick([0.1, 1, 31, 60])!)
    case .command: return .command(command(random.pick(weighted: weightedKinds)!, in: world).text)
    case .crash: return .crash
    }
  }

  /// Arbor is not running: apps and displays come and go, time passes, and sooner or later it is launched.
  private mutating func whileStopped(_ world: ChaosRunner) -> ChaosAction {
    let windows = world.system.windows.count
    enum Kind { case launch, open, close, quitApp, renumber, move, minimize, displays, settings, sleep, command, corrupt, unlist }
    let kind =
      random.pick(weighted: [
        (30, Kind.launch), (windows < 5 ? 30 : 6, .open), (8, .close), (2, .quitApp), (14, .renumber), (6, .move),
        (6, .minimize), (6, .displays), (4, .settings), (3, .sleep), (3, .command), (5, .corrupt), (windows > 0 ? 4 : 0, .unlist),
      ]) ?? .launch
    switch kind {
    case .launch: return .launch
    case .open: return .open(newWindow(in: world))
    case .close: return .close(window(in: world))
    case .quitApp: return .quitApp(pid: pid(in: world))
    case .renumber:
      nextWindow += 1
      return .renumber(window(in: world), WindowID(nextWindow - 1))
    case .move:
      let id = window(in: world)
      return .move(id, movedFrame(of: id, in: world))
    case .minimize: return .minimize(window(in: world), random.chance(50))
    case .displays: return .displays(arrangement(), random.chance(80) ? .first : .never)
    case .settings: return .settings(settingsChange())
    case .sleep: return .sleep(days: random.pick([0.5, 1, 29, 31, 400])!)
    case .command: return .command(command(random.pick(weightedKinds.map(\.value))!, in: world).text)
    case .corrupt: return .corrupt(random.next() % 1_000_000)
    case .unlist: return .listed(window(in: world), false)
    }
  }

  // MARK: Windows

  private static let spaceNames = ["work", "mail", "music"]
  private static let apps = ["Safari", "Notes", "Mail", "Terminal", "Xcode", "Finder", "Music", "Preview"]
  private static let titles = ["Inbox", "Untitled", "Untitled", "Draft", "main.swift", "~", "Übersicht"]

  enum Preference { case any, docked, floating, inView }

  /// A window, mostly one that exists and fits the preference.
  mutating func window(in world: ChaosRunner, _ preference: Preference = .any) -> WindowID {
    if random.chance(4) { return WindowID(random.pick([0, 1, 99, 100, nextWindow, nextWindow + 7, UInt32.max])!) }
    let controller = world.controller
    let all = world.system.windows.keys.sorted()
    let preferred: [WindowID]
    switch preference {
    case .any: preferred = all
    case .docked: preferred = all.filter { id in controller.workspaces.values.contains { $0.isDocked(id) } }
    case .floating: preferred = all.filter { id in controller.workspaces.values.contains { $0.isFloating(id) } }
    case .inView: preferred = all.filter { !controller.parked.contains($0) && world.system.windows[$0]!.snapshot.isPresent }
    }
    return random.pick(preferred) ?? random.pick(all) ?? WindowID(nextWindow)
  }

  /// Nil (the focused window) a third of the time.
  private mutating func optionalWindow(in world: ChaosRunner, _ preference: Preference = .any) -> WindowID? {
    random.chance(33) ? nil : window(in: world, preference)
  }

  private mutating func pid(in world: ChaosRunner) -> Int32 {
    if random.chance(5) { return Int32(random.int(0...3000)) }
    return random.pick(world.system.windows.keys.sorted()).map { world.system.windows[$0]!.snapshot.pid } ?? 1000
  }

  private mutating func bundleID(in world: ChaosRunner) -> String {
    if random.chance(10) { return random.pick(["com.example.nobody", "x", "com.apple.finder", "COM.EXAMPLE.SAFARI"])! }
    return "com.example.\(random.pick(Self.apps)!.lowercased())"
  }

  private mutating func limits() -> (CGSize, CGSize?) {
    let minimum: CGSize =
      switch random.int(0...9) {
      case 0...4: .zero
      case 5, 6: CGSize(width: random.int(100...500), height: random.int(80...400))
      case 7, 8: CGSize(width: random.int(500...1200), height: random.int(300...800))
      default: CGSize(width: random.int(1500...4000), height: random.int(900...2500))  // larger than many displays
      }
    guard random.chance(20) else { return (minimum, nil) }
    return (
      minimum,
      CGSize(width: max(minimum.width, CGFloat(random.int(200...900))), height: max(minimum.height, CGFloat(random.int(150...2000))))
    )
  }

  private mutating func newWindow(in world: ChaosRunner) -> ChaosAction.NewWindow {
    let index = random.int(0...(Self.apps.count - 1))
    var new = ChaosAction.NewWindow(
      id: WindowID(nextWindow), app: Self.apps[index], pid: Int32(1000 + index), frame: frame(in: world))
    nextWindow += 1
    (new.minimum, new.maximum) = limits()
    new.frame.size.width = max(new.frame.width, new.minimum.width)
    new.frame.size.height = max(new.frame.height, new.minimum.height)
    if random.chance(25) { new.title = random.pick(Self.titles) }
    if random.chance(3) { new.hasBundleID = false }
    if random.chance(2) {
      // One of Arbor's own windows (the harness's filter takes pid 1 for Arbor).
      new.app = "Arbor"
      new.pid = 1
    }
    if allowsMisbehaviour, random.chance(25) { new.behaviour = random.pick(FakeWindowSystem.Behaviour.allCases)! }
    return new
  }

  // MARK: Geometry

  private mutating func edge() -> Edge { random.pick(Edge.allCases)! }

  /// What `grow` and `shrink` take: nothing, a step a person would ask for, now and then a fraction or far too much.
  private mutating func step() -> Double? {
    if random.chance(40) { return nil }
    return random.chance(10) ? Double(random.int(1...20_000)) / 8 : random.chance(5) ? Double(random.int(1...1_000_000)) : Double(random.int(1...400))
  }

  private mutating func displayTarget() -> DisplayTarget {
    random.chance(50) ? .next : random.chance(40) ? .previous : .number(random.int(1...(random.chance(10) ? DisplayTarget.highestNumber : 3)))
  }

  private mutating func displayID(in world: ChaosRunner) -> DisplayID {
    if random.chance(5) { return DisplayID(random.pick(["main", "side", "third", "nowhere"])!) }
    return random.pick(world.system.displayList)?.id ?? DisplayID("main")
  }

  /// A node, mostly one in the tree of the display under the pointer.
  private mutating func node(in world: ChaosRunner) -> NodeID {
    if random.chance(8) { return NodeID(random.pick([-1, 0, 1, 2, 500, Int.max, Int.min])!) }
    let display =
      world.system.displayList.first { $0.frame.contains(world.system.cursor) } ?? random.pick(world.system.displayList)
    let nodes = display.flatMap { world.controller.workspaces[$0.id]?.tree.preorder() } ?? []
    return random.pick(nodes) ?? NodeID(0)
  }

  /// Where an app or the user might put a window: enough of it on a display to get hold of.
  private mutating func frame(in world: ChaosRunner, size: CGSize? = nil) -> CGRect {
    let size =
      size
      ?? random.pick(weighted: [
        (10, CGSize(width: random.int(300...900), height: random.int(200...700))),
        (2, CGSize(width: random.int(40...200), height: random.int(30...150))),
        (1, CGSize(width: random.int(1500...3000), height: random.int(900...2000))),
        (1, CGSize(width: CGFloat(random.int(300...900)) + 0.5, height: CGFloat(random.int(200...700)) + 0.25)),
      ])!
    guard let display = random.pick(world.system.displayList) else {
      return CGRect(origin: CGPoint(x: random.int(-500...2000), y: random.int(0...1000)), size: size)
    }
    let (f, v) = (display.frame, display.visibleFrame)
    let grip = min(60, size.width)
    return CGRect(
      x: random.points(f.minX - size.width + grip, f.maxX - grip), y: random.points(v.minY, max(v.minY, f.maxY - 40)),
      width: size.width, height: size.height)
  }

  /// A move without the mouse: a nudge, a new place, or a new place and size.
  private mutating func movedFrame(of id: WindowID, in world: ChaosRunner) -> CGRect {
    guard let current = world.system.windows[id]?.snapshot.frame else { return frame(in: world) }
    switch random.int(0...5) {
    case 0:
      let nudged = current.offsetBy(dx: random.points(-4, 4), dy: random.points(-4, 4))  // within the tolerance
      return isReachable(nudged, in: world) ? nudged : current
    case 1:
      var nudged = current
      nudged.size.width = max(nudged.width + random.points(-6, 6), 1)
      nudged.size.height = max(nudged.height + random.points(-6, 6), 1)
      return isReachable(nudged, in: world) ? nudged : current
    case 2, 3: return frame(in: world, size: current.size)
    default: return frame(in: world)
    }
  }

  /// The frame after dragging one or two of a window's edges.
  private mutating func resizedFrame(of id: WindowID, in world: ChaosRunner) -> CGRect {
    guard let current = world.system.windows[id]?.snapshot.frame else { return frame(in: world) }
    var (minX, minY, maxX, maxY) = (current.minX, current.minY, current.maxX, current.maxY)
    for _ in 0..<random.int(1...2) {
      let delta = random.chance(15) ? random.points(-5, 5) : random.chance(10) ? random.points(-1500, 1500) : random.points(-300, 300)
      switch edge() {
      case .left: minX += delta
      case .right: maxX += delta
      case .top: minY += delta
      case .bottom: maxY += delta
      }
    }
    let resized = CGRect(
      x: min(minX, maxX - 20), y: min(minY, maxY - 20), width: max(maxX - minX, 20), height: max(maxY - minY, 20))
    // The pointer holds the edge and cannot leave the displays, so part of the window stays on one.
    return isReachable(resized, in: world) ? resized : current
  }

  private func isReachable(_ frame: CGRect, in world: ChaosRunner) -> Bool { world.isReachable(frame) }

  /// Somewhere the pointer might be: the places that mean something to Arbor, and anywhere else.
  mutating func point(in world: ChaosRunner, dragging: WindowID? = nil) -> CGPoint {
    guard let display = random.pick(world.system.displayList) else {
      return CGPoint(x: random.int(-100...3000), y: random.int(-100...2000))
    }
    let (f, v) = (display.frame, display.visibleFrame)
    let layout = world.controller.layouts[display.id]
    func inside(_ rect: CGRect, _ r: inout ChaosRandom) -> CGPoint {
      CGPoint(x: r.points(rect.minX, rect.maxX - 1), y: r.points(rect.minY, rect.maxY - 1))
    }
    switch random.int(0...15) {
    case 0, 1:
      // In the band along a screen edge.
      let depth = random.points(0, 14)
      switch edge() {
      case .left: return CGPoint(x: v.minX + depth, y: random.points(v.minY, v.maxY - 1))
      case .right: return CGPoint(x: v.maxX - 1 - depth, y: random.points(v.minY, v.maxY - 1))
      case .top: return CGPoint(x: random.points(v.minX, v.maxX - 1), y: v.minY + depth)
      case .bottom: return CGPoint(x: random.points(v.minX, v.maxX - 1), y: v.maxY - 1 - depth)
      }
    case 2:
      // Exactly on a corner or a boundary, where off-by-ones live.
      return CGPoint(x: random.pick([f.minX, f.maxX - 1, f.maxX, v.minX, v.maxX, f.midX])!, y: random.pick([f.minY, f.maxY - 1, f.maxY, v.minY, v.maxY, f.midY])!)
    case 3...7:
      // On a docked window or a tile: along one of its edges, or in the middle.
      var rects = (layout?.windowFrames ?? [:]).sorted(by: { $0.key < $1.key }).map(\.value)
      rects += layout?.tiles.map(\.frame) ?? []
      guard let rect = random.pick(rects), rect.width >= 4, rect.height >= 4 else { return inside(f, &random) }
      if random.chance(35) { return inside(rect.insetBy(dx: rect.width * 0.35, dy: rect.height * 0.35), &random) }
      let depth = CGFloat(random.int(1...28)) / 100
      switch edge() {
      case .left: return CGPoint(x: (rect.minX + rect.width * depth).rounded(), y: rect.midY.rounded())
      case .right: return CGPoint(x: (rect.maxX - rect.width * depth).rounded(), y: rect.midY.rounded())
      case .top: return CGPoint(x: rect.midX.rounded(), y: (rect.minY + rect.height * depth).rounded())
      case .bottom: return CGPoint(x: rect.midX.rounded(), y: (rect.maxY - rect.height * depth).rounded())
      }
    case 8:
      if let desktop = layout?.desktopFrame, desktop.width >= 2, desktop.height >= 2 { return inside(desktop, &random) }
      return inside(f, &random)
    case 9:
      if let seam = random.pick(layout?.seams ?? []) { return seam.frame.center }
      return inside(f, &random)
    case 10:
      // Back where it came from.
      if let dragging, let slot = layout?.windowFrames[dragging], slot.width >= 2, slot.height >= 2 { return inside(slot, &random) }
      return inside(f, &random)
    case 11:
      // Just outside every display, where the pointer cannot be but a late event might say it is.
      return random.chance(30) ? CGPoint(x: f.maxX + random.points(0, 300), y: f.maxY + random.points(0, 300)) : inside(f, &random)
    default:
      return inside(f, &random)
    }
  }

  // MARK: Displays

  /// One to three displays side by side or stacked, never overlapping, the main one at the origin as
  /// on a Mac; rarely none at all (the lid is shut and the cable is out).
  private mutating func arrangement() -> [DisplaySnapshot] {
    if random.chance(4) { return [] }
    let sizes = [
      CGSize(width: 1440, height: 900), CGSize(width: 1440, height: 900), CGSize(width: 1280, height: 800),
      CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440), CGSize(width: 800, height: 600),
      CGSize(width: 1080, height: 1920), CGSize(width: 1512, height: 982),
    ]
    var ids = ["main", "side", "third"]
    // Which displays are connected, and which of them is the main one, both change.
    if random.chance(30) { ids.swapAt(0, random.int(1...2)) }
    let count = random.pick(weighted: [(5, 1), (5, 2), (2, 3)])!
    var displays: [DisplaySnapshot] = []
    // Each display goes just outside the box around the ones before it, so none overlap.
    var box = CGRect.zero
    for (index, id) in ids.prefix(count).enumerated() {
      var size = random.pick(sizes)!
      if desks {
        if let own = sizesOnTheDesk[id], !random.chance(10) { size = own }
        sizesOnTheDesk[id] = size
      }
      var origin = CGPoint.zero
      if index > 0 {
        switch random.int(0...2) {
        case 0: origin = CGPoint(x: box.maxX, y: random.points(-300, 300))
        case 1: origin = CGPoint(x: box.minX - size.width, y: random.points(-300, 300))
        default: origin = CGPoint(x: random.points(-300, 300), y: box.maxY)
        }
      }
      let frame = CGRect(origin: origin, size: size)
      box = index == 0 ? frame : box.union(frame)
      // The menu bar, and a Dock on one side some of the time.
      var (top, leading, below, trailing): (CGFloat, CGFloat, CGFloat, CGFloat) = (random.pick([25, 25, 37, 0])!, 0, 0, 0)
      if index > 0, random.chance(50) { top = 0 }
      switch random.int(0...5) {
      case 0: below = random.points(40, 100)
      case 1: leading = random.points(40, 100)
      case 2: trailing = random.points(40, 100)
      default: break
      }
      displays.append(
        DisplaySnapshot(
          id: DisplayID(id), frame: frame,
          visibleFrame: CGRect(
            x: frame.minX + leading, y: frame.minY + top, width: frame.width - leading - trailing,
            height: frame.height - top - below),
          isMain: index == 0))
    }
    return random.chance(30) ? displays.reversed() : displays
  }

  // MARK: Settings

  /// A JSON object to merge into settings.json: mostly sensible values, sometimes what a slip of
  /// the hand in a text editor leaves behind.
  private mutating func settingsChange() -> String {
    func number(_ sensible: [Double], _ odd: [Double], _ r: inout ChaosRandom) -> String {
      ChaosAction.format(r.pick(r.chance(80) ? sensible : odd)!)
    }
    switch random.int(0...14) {
    case 11:
      // How things look (F15, F36). None of it may move a window.
      let amounts = ["dimBehindArranged", "blurBehindArranged", "tintBehindArranged", "desktopEdge", "appColourAmount", "tileFade"]
      let amount = "\"\(random.pick(amounts)!)\":\(number([0, 0.05, 0.25, 1], [-1, 7, 1e300], &random))"
      let handles = random.pick(["shown", "hidden", "off", "", "OFF"])!
      let style = random.pick(["icon", "name", "plain", "fancy"])!
      return "{\(amount),\"gapHandles\":\"\(handles)\",\"tileStyle\":\"\(style)\",\"appColours\":\(random.chance(70))}"
    case 12, 13:
      // How a drag behaves (F09).
      let dwell = number([0, 0.1, 0.15, 0.3], [-1, 2, 50, 1e300], &random)
      return "{\"reflowWhileDragging\":\(random.chance(70)),\"keepPushed\":\(random.chance(50)),\"dropDwell\":\(dwell),\"previewDrags\":\(random.chance(70))}"
    case 14:
      // What a dropped or leaving window meets.
      let framed = random.pick(["guest", "float"])!
      let new = random.pick(["float", "dock"])!
      // Floating windows that make way (as until Q20) are what F18 needs, and what most rules about floating windows were written for.
      return "{\"soleFloatTakesDesktop\":\(random.chance(50)),\"makeRoom\":\(random.chance(60)),\"newWindows\":\"\(new)\",\"newWindowsWhileFramed\":\"\(framed)\","
        + "\"floatingWindowsMakeWay\":\(random.chance(40))}"
    case 10:
      let width = number([1, 3, 12], [0, -3, 500, 1e300], &random)
      let radius = number([0, 10, 17], [-1, 1e300], &random)
      let colour = random.pick(["accent", "#FF8800", "#ff880080", "red", ""])!
      return "{\"focusRing\":\(random.chance(75)),\"focusRingWidth\":\(width),\"focusRingRadius\":\(radius),\"focusRingColour\":\"\(colour)\"}"
    case 0, 1: return "{\"gap\":\(number([0, 1, 4, 8, 12, 24, 40, 60], [-12, 0.5, 400, 5000, 1e9], &random))}"
    case 2:
      let width = number([0, 1, 120, 240, 400, 800], [-1, 5000, 1e12], &random)
      let height = number([0, 1, 80, 160, 300, 600], [-1, 5000, 1e12], &random)
      return "{\"minimumUsableWidth\":\(width),\"minimumUsableHeight\":\(height)}"
    case 3: return "{\"tabsEnabled\":\(random.chance(70))}"
    case 4: return "{\"screenEdgeBand\":\(number([0, 4, 12, 40], [-5, 3000], &random))}"
    case 5: return "{\"windowEdgeFraction\":\(number([0.1, 0.3, 0.5], [0, -1, 1, 7], &random))}"
    case 6: return "{\"arrangeDesktopWeight\":\(number([0.25, 0.5, 1, 2], [0, -1, 1e-12, 1e12], &random))}"
    case 7:
      let excluded = Self.apps.filter { _ in random.chance(12) }.map { "\"com.example.\($0.lowercased())\"" }
      return "{\"excludedBundleIDs\":[\(excluded.joined(separator: ","))]}"
    default:
      var rules: [String] = []
      for _ in 0..<random.int(0...4) {
        let app = "com.example.\(random.pick(Self.apps)!.lowercased())"
        let other = "com.example.\(random.pick(Self.apps)!.lowercased())"
        let side = edge().rawValue
        let action = random.pick(weighted: [
          (2, "float"), (3, "ignore"), (6, "dock \(side)"), (6, "dock beside \(other) \(side)"), (1, "dock nowhere"), (1, ""),
        ])!
        let title = random.chance(25) ? ",\"title\":\"\(random.pick(Self.titles)!)\"" : ""
        rules.append("{\"app\":\"\(app)\"\(title),\"action\":\"\(action)\"}")
      }
      return "{\"rules\":[\(rules.joined(separator: ","))]}"
    }
  }
}
