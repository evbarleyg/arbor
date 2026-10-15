import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// `ARBOR_CHAOS_ORDINARY=1`: walks a person could take. The displays of a real desk, apps with the sizes real apps have, windows that open
/// wholly in view, keys that are bound and items that are in the menu, the mouse, and time between one thing and the next. No settings
/// edited by hand, no apps that fight back, no crash, no nonsense. **What such a walk finds is likely on a real desk**; what only the wild walks
/// find has to be looked at for how a person would get there.
///
/// `ARBOR_CHAOS_DESK=laptop|desk|both` chooses the displays (`both`: a laptop and an external display that comes and goes, in the orders a Mac
/// has), `ARBOR_CHAOS_DOCK=bottom|left|right|hidden` the side of the Dock, `ARBOR_CHAOS_TILING=on|off` whether macOS's own tiling is as a Mac comes or
/// switched off. Left out, the seed chooses: half the walks each way.
extension ChaosGenerator {
  struct Desk {
    enum Kind: String, CaseIterable { case laptop, desk, both }
    enum Plugged: CaseIterable { case both, laptopAlone, externalAlone }

    var kind: Kind
    var laptop: CGSize
    var notch: CGFloat
    var external: CGSize
    /// Where the external display stands as seen from the laptop, and how far it is shifted along that side.
    var side: Edge
    var shift: CGFloat
    var externalIsMain: Bool
    var dock: Edge?
    var dockSize: CGFloat
    var plugged: Plugged
    var macTiling: Bool

    init(_ random: inout ChaosRandom) {
      let environment = ProcessInfo.processInfo.environment
      kind = environment["ARBOR_CHAOS_DESK"].flatMap(Kind.init(rawValue:)) ?? random.pick(Kind.allCases)!
      (laptop, notch) = random.pick([
        (CGSize(width: 1440, height: 900), 25), (CGSize(width: 1512, height: 982), 37), (CGSize(width: 1728, height: 1117), 37),
        (CGSize(width: 1280, height: 800), 25),
      ])!
      external = random.pick([CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440), CGSize(width: 3008, height: 1692)])!
      side = random.pick([.left, .right, .right, .top])!
      shift = random.pick([0, 0, -200, 150, 323])!
      externalIsMain = random.chance(40)
      switch environment["ARBOR_CHAOS_DOCK"] {
      case "bottom": dock = .bottom
      case "left": dock = .left
      case "right": dock = .right
      case "hidden": dock = nil
      default: dock = random.pick([.bottom, .bottom, .left, .right, nil])!
      }
      dockSize = random.pick([48, 59, 70, 86])!
      plugged = kind == .laptop ? .laptopAlone : kind == .desk ? .externalAlone : .both
      // Drawn last, so that a seed's desk is what it was. Its walk is another all the same: half are taken without macOS's tiling now.
      let drawn = random.chance(50)
      macTiling = environment["ARBOR_CHAOS_TILING"].map { $0 != "off" } ?? drawn
    }

    /// The main display has its corner at 0,0, the menu bar is on both, the Dock on the main one.
    var displays: [DisplaySnapshot] {
      func display(_ id: String, _ frame: CGRect, bar: CGFloat, isMain: Bool) -> DisplaySnapshot {
        var (leading, below, trailing): (CGFloat, CGFloat, CGFloat) = (0, 0, 0)
        if isMain {
          switch dock {
          case .bottom: below = dockSize
          case .left: leading = dockSize
          case .right: trailing = dockSize
          default: break
          }
        }
        return DisplaySnapshot(
          id: DisplayID(id), frame: frame,
          visibleFrame: CGRect(
            x: frame.minX + leading, y: frame.minY + bar, width: frame.width - leading - trailing, height: frame.height - bar - below),
          isMain: isMain)
      }
      switch plugged {
      case .laptopAlone: return [display("main", CGRect(origin: .zero, size: laptop), bar: notch, isMain: true)]
      case .externalAlone: return [display("side", CGRect(origin: .zero, size: external), bar: 25, isMain: true)]
      case .both:
        // As seen from the laptop's corner.
        let offset: CGPoint =
          switch side {
          case .left: CGPoint(x: -external.width, y: shift)
          case .right: CGPoint(x: laptop.width, y: shift)
          default: CGPoint(x: shift, y: -external.height)
          }
        let origin = externalIsMain ? CGPoint(x: -offset.x, y: -offset.y) : .zero
        return [
          display("main", CGRect(origin: origin, size: laptop), bar: notch, isMain: !externalIsMain),
          display("side", CGRect(x: origin.x + offset.x, y: origin.y + offset.y, width: external.width, height: external.height), bar: 25, isMain: externalIsMain),
        ]
      }
    }
  }

  /// What real apps refuse to go below, and about how large they open.
  private static let realApps = RealApp.ordinary

  /// The keys a person presses, by how often.
  private static let keys: [(weight: Int, value: String)] = [
    (12, "dock left"), (12, "dock right"), (6, "dock top"), (8, "dock bottom"), (12, "toggle-float"), (5, "arrange"), (4, "float-all"),
    (12, "zoom"), (8, "out"), (6, "in"), (6, "neighbor left"), (6, "neighbor right"), (10, "home"), (10, "show-all"), (6, "desktop"),
    (6, "back"), (3, "forward"), (4, "focus left"), (4, "focus right"), (3, "focus up"), (3, "focus down"), (4, "grow"), (4, "shrink"),
    (2, "balance"), (2, "rotate"), (2, "mirror"), (10, "undo"), (3, "redo"), (2, "save-view 1"), (3, "view 1"), (1, "save-view 2"),
    (2, "view 2"), (1, "minimap"),
  ]

  /// What is in the menu and on no key, or is refused as a key by the harness.
  private static let menu: [(weight: Int, value: String)] = [
    (4, "toggle-pin"), (3, "toggle-pause"), (2, "hold"), (2, "release"), (6, "move-to-display next"), (2, "float-all here"), (1, "quit"),
    (2, "arrange all"),
  ]

  mutating func startOrdinaryWalk() {
    planned = [.displays(desk.displays, .never), .macTiling(desk.macTiling)]
    let before = random.int(0...4)
    for _ in 0..<before { planned.append(.open(ordinaryWindow(on: desk.displays))) }
    planned.append(.launch)
    planned.append(.settle)
  }

  private mutating func ordinaryWindow(on displays: [DisplaySnapshot]) -> ChaosAction.NewWindow {
    let index = random.int(0...(Self.realApps.count - 1))
    let app = Self.realApps[index]
    let visible = (random.pick(displays) ?? FakeWindowSystem.standardDisplay).visibleFrame
    var size = CGSize(
      width: (app.opens.width * CGFloat(random.int(70...120)) / 100).rounded(), height: (app.opens.height * CGFloat(random.int(70...120)) / 100).rounded())
    size.width = min(max(size.width, app.minimum.width), max(visible.width, app.minimum.width))
    size.height = min(max(size.height, app.minimum.height), max(visible.height, app.minimum.height))
    if let most = app.maximum { size = CGSize(width: min(size.width, most.width), height: min(size.height, most.height)) }
    let origin = CGPoint(
      x: random.points(visible.minX, max(visible.minX, visible.maxX - size.width)), y: random.points(visible.minY, max(visible.minY, visible.maxY - size.height)))
    var new = ChaosAction.NewWindow(id: WindowID(nextWindow), app: app.name, pid: Int32(1000 + index), frame: CGRect(origin: origin, size: size))
    nextWindow += 1
    (new.minimum, new.maximum) = (app.minimum, app.maximum)
    return new
  }

  /// A moment goes by, as it does between two things a person does: macOS reports, short timers run.
  private mutating func thenAMoment(_ actions: [ChaosAction] = []) {
    var rest = actions
    if random.chance(85) { rest += [.react, .advance(random.pick([0.3, 0.5, 1, 1, 5])!), .react] }
    planned.insert(contentsOf: rest, at: 0)
  }

  private mutating func existing(_ world: ChaosRunner, _ preference: Preference = .any) -> WindowID? {
    let controller = world.controller
    let all = world.system.windows.keys.sorted()
    switch preference {
    case .inView: return random.pick(all.filter { !controller.parked.contains($0) && world.system.windows[$0]!.snapshot.isPresent })
    default: return random.pick(all)
    }
  }

  mutating func ordinaryNext(_ world: ChaosRunner) -> ChaosAction {
    if !planned.isEmpty { return planned.removeFirst() }
    let system = world.system
    guard world.isRunning else {
      if !world.isPaused { return .launch }
      // Paused, a person goes on working for a while.
      switch random.int(0...5) {
      case 0, 1: return .command("toggle-pause")
      case 2: return existing(world).map { .focus($0) } ?? .flush
      case 3: return .open(ordinaryWindow(on: system.displayList))
      default: return .advance(1)
      }
    }
    enum Kind { case open, close, minimize, hide, click, commandTab, drag, edge, seam, tile, key, hold, menu, time, fullScreen, displays, cursor, summon }
    let windows = system.windows.count
    let tiles = world.harness.overlays.tiles.values.reduce(0) { $0 + $1.count }
    let seams = world.harness.overlays.seams.values.reduce(0) { $0 + $1.count }
    let kind =
      random.pick(weighted: [
        (windows < 3 ? 100 : windows < 7 ? 30 : 4, Kind.open), (windows > 2 ? 14 : 2, .close), (14, .minimize), (5, .hide), (50, .click),
        (30, .commandTab), (40, .drag), (14, .edge), (seams > 0 ? 12 : 0, .seam), (tiles > 0 ? 24 : 0, .tile), (300, .key), (10, .hold),
        (30, .menu), (30, .time), (4, .fullScreen), (desk.kind == .both ? 10 : 0, .displays), (16, .cursor), (6, .summon),
      ]) ?? .time
    switch kind {
    case .open:
      let new = ordinaryWindow(on: system.displayList)
      thenAMoment([.focus(new.id)])
      return .open(new)
    case .close:
      guard let window = existing(world, .inView) else { return .flush }
      thenAMoment()
      return .close(window)
    case .minimize:
      guard let window = existing(world) else { return .flush }
      let minimized = system.windows[window]!.snapshot.isMinimized
      // Half the time straight back out of the Dock.
      if !minimized, random.chance(50) { thenAMoment([.react, .advance(1), .react, .minimize(window, false)]) } else { thenAMoment() }
      return .minimize(window, !minimized)
    case .hide:
      guard let window = existing(world) else { return .flush }
      let snapshot = system.windows[window]!.snapshot
      if !snapshot.isHidden, random.chance(50) { thenAMoment([.react, .advance(1), .react, .hide(pid: snapshot.pid, false)]) } else { thenAMoment() }
      return .hide(pid: snapshot.pid, !snapshot.isHidden)
    case .click:
      guard let window = existing(world, .inView) else { return .flush }
      thenAMoment()
      return .focus(window)
    case .commandTab:
      // Onto any window of any app, in view or not, that is not in the Dock or hidden with its app.
      guard let window = random.pick(system.windows.keys.sorted().filter { !system.windows[$0]!.snapshot.isMinimized && !system.windows[$0]!.snapshot.isHidden })
      else { return .flush }
      thenAMoment()
      // The Accessibility layer says which window of the app that came forward has the keyboard.
      return .focus(window)
    case .drag:
      guard let window = existing(world, .inView) else { return .flush }
      var gesture: [ChaosAction] = []
      for _ in 0..<random.int(1...3) { gesture.append(.carry(point(in: world, dragging: window))) }
      if random.chance(80) { gesture.append(.advance(random.pick([0.2, 0.3, 0.5])!)) }
      thenAMoment(gesture + [.release])
      return .grab(window)
    case .edge:
      guard let window = existing(world, .inView), let frame = system.windows[window]?.snapshot.frame else { return .flush }
      var resized = frame
      let delta = random.points(-300, 300)
      switch random.int(0...2) {
      case 0: resized.size.width = max(frame.width + delta, 100)
      case 1: resized.size.height = max(frame.height + delta, 80)
      default: resized = CGRect(x: frame.minX + delta, y: frame.minY, width: max(frame.width - delta, 100), height: frame.height)
      }
      thenAMoment()
      return .edge(window, resized, hold: false)
    case .seam:
      guard let display = random.pick(world.harness.overlays.seams.filter { !$0.value.isEmpty }.keys.sorted()) else { return .flush }
      thenAMoment()
      return .seam(display, index: random.int(0...(world.harness.overlays.seams[display]!.count - 1)), delta: Double(random.int(-300...300)))
    case .tile:
      guard let tile = random.pick(world.harness.overlays.tiles.sorted(by: { $0.key < $1.key }).flatMap(\.value)) else { return .flush }
      thenAMoment()
      return .tile(tile.display, tile.node)
    case .key:
      // Down and up again.
      let line = random.pick(weighted: Self.keys)!
      // A look elsewhere and straight back.
      let andBack: [ChaosAction] =
        ["zoom", "out", "in", "home", "desktop", "neighbor left", "neighbor right"].contains(line) && random.chance(30)
        ? [.react, .advance(1), .react, .key("back", .pressed), .key("back", .released)] : []
      thenAMoment([.key(line, .released)] + andBack)
      return .key(line, .pressed)
    case .hold:
      // Show Everything kept down is a look around.
      thenAMoment([.advance(0.5), .advance(0.5), .key("show-all", .released)])
      return .key("show-all", .pressed)
    case .menu:
      let line = random.pick(weighted: Self.menu)!
      // A pause that is over before anything else has happened.
      if line == "toggle-pause", random.chance(40) { thenAMoment([.react, .advance(1), .command("toggle-pause")]) } else { thenAMoment() }
      return ["quit", "toggle-pause"].contains(line) ? .command(line) : .via(.menu, line)
    case .summon:
      thenAMoment()
      return .via(.shortcut, "summon \(random.pick(Self.realApps)!.name)")
    case .time: return random.chance(50) ? .settle : .advance(random.pick([1, 5, 31])!)
    case .fullScreen:
      // Out of it again first, if one is in it.
      if let full = system.windows.keys.sorted().first(where: { system.windows[$0]!.snapshot.isFullScreen }) {
        thenAMoment()
        return .fullScreen(full, false)
      }
      guard let window = existing(world, .inView) else { return .flush }
      if random.chance(50) { thenAMoment([.react, .advance(1), .react, .fullScreen(window, false)]) } else { thenAMoment() }
      return .fullScreen(window, true)
    case .displays:
      desk.plugged = random.pick(Desk.Plugged.allCases.filter { $0 != desk.plugged })!
      thenAMoment([.settle])
      return .displays(desk.displays, random.pick([.late, .silent, .first])!)
    case .cursor: return .cursor(point(in: world))
    }
  }
}
