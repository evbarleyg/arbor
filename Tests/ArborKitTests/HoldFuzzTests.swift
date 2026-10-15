import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The promise of `hold`, tried against whatever comes: while the view is held, no window that was out of view when
/// the hold began shows on any display, whatever commands, keys, clicks, drags and window events arrive, and in whatever
/// order. Nor when the hold ends, unless a view had nothing left in it and has to go somewhere.
@Suite @MainActor struct HoldFuzzTests {
  /// Small, seeded and the same on every platform.
  struct Dice {
    var state: UInt64
    mutating func roll(_ sides: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(sides))
    }
    mutating func pick<T>(_ items: [T]) -> T { items[roll(items.count)] }
  }

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)

  /// 320 walks, about two seconds. Raise the 40s to look harder: 8000 walks were clean when this was written.
  @Test(arguments: 0..<8) func nothingThatWasOutOfViewEverShowsWhileTheViewIsHeld(block: Int) {
    for seed in (block * 40)..<(block * 40 + 40) { walk(seed: UInt64(seed)) }
  }

  func walk(seed: UInt64) {
    var dice = Dice(state: seed &* 2_654_435_761 &+ 1)
    var settings = Settings()
    settings.tabsEnabled = dice.roll(2) == 0
    // It moves windows during a drag without a layout, so past the fence.
    settings.reflowWhileDragging = dice.roll(2) == 0
    // It docks what waited when the hold ends, on its own word that it takes no place that changes what the view shows.
    if dice.roll(3) == 0 { settings.newWindows = "dock" }
    settings.rules = [
      AppRule(app: "com.example.terminal", action: .dock(dice.pick(Edge.allCases))),
      AppRule(app: "com.example.console", action: .dockBeside(bundleID: "com.example.app1", dice.pick(Edge.allCases))),
    ]
    let two = dice.roll(3) == 0
    let h = Harness(displays: two ? [FakeWindowSystem.standardDisplay, Self.side] : [FakeWindowSystem.standardDisplay], settings: settings)
    h.start()
    var trail: [String] = []
    func run(_ text: String) {
      trail.append(text)
      h.run(text)
    }

    // Some arrangement, and a view somewhere in it.
    for index in 0..<(3 + dice.roll(5)) {
      let onSide = two && dice.roll(2) == 0
      let id = h.system.open(
        app: "App\(index)", pid: Int32(2000 + index % 4),
        frame: CGRect(x: (onSide ? 1700 : 200) + index * 20, y: 150 + index * 20, width: 500, height: 350))
      let docked = h.controller.workspaces.values.flatMap(\.tree.allWindows)
      switch dice.roll(4) {
      case 0: break
      case 1 where !docked.isEmpty: run("dock \(id.rawValue) beside \(dice.pick(docked).rawValue) \(dice.pick(Edge.allCases).rawValue)")
      default: run("dock \(id.rawValue) \(dice.pick(Edge.allCases).rawValue)")
      }
    }
    for _ in 0..<dice.roll(4) {
      h.system.cursor = two && dice.roll(2) == 0 ? CGPoint(x: 2000, y: 500) : CGPoint(x: 700, y: 400)
      run(dice.pick(["in", "out", "neighbor left", "neighbor right", "neighbor up", "desktop", "show-all"]))
    }
    let all = h.system.windows.keys.sorted()
    run("zoom \(dice.pick(all).rawValue)")
    if dice.roll(2) == 0 { run("out") }
    if let shown = all.first(where: { h.system.isVisible($0) }) { h.system.userFocus(shown) }

    run("hold")
    guard h.controller.holdLevel == .view else { return }
    // Outside the spaces the views are on. Inside them a window can be too small to show (a tile) or behind
    // another tab, and show later: that is laying out what is held.
    func outside() -> Set<WindowID> {
      var held = Set<WindowID>()
      for workspace in h.controller.workspaces.values {
        held.formUnion(workspace.tree.windows(under: workspace.camera))
        if workspace.tree.subtree(workspace.camera, contains: workspace.tree.desktop) { held.formUnion(workspace.floating.keys) }
      }
      return Set(h.system.windows.keys.filter { !h.system.isVisible($0) }).subtracting(held)
    }
    var outOfView = outside()
    func showing(exceptOn displays: Set<DisplayID> = []) -> [WindowID] {
      outOfView.filter {
        h.system.windows[$0]?.snapshot.isPresent == true && h.system.isVisible($0)
          && h.controller.workspaceID(containing: $0).map(displays.contains) != true
      }.sorted()
    }
    func report(_ leaked: [WindowID], _ when: String) {
      Issue.record("seed \(seed): \(leaked) came into view \(when)\n\(trail.joined(separator: "\n"))\n\(h.ascii(columns: 48, rows: 10))")
    }

    for _ in 0..<40 {
      let windows = h.system.windows.keys.sorted()
      guard !windows.isEmpty else { return }
      let empty = h.controller.displaysHeldEmpty
      let any = dice.pick(windows)
      let shown = windows.filter { h.system.isVisible($0) && h.system.windows[$0]!.snapshot.isPresent }
      let edge = dice.pick(Edge.allCases).rawValue
      let point = CGPoint(x: dice.pick([2, 300, 720, 1100, 1438, 1445, 2400, 3358]), y: dice.pick([27, 200, 450, 700, 898]))
      h.system.cursor = point
      switch dice.roll(26) {
      case 0: run("dock \(any.rawValue) \(edge)")
      case 1: run("dock \(any.rawValue) beside \(dice.pick(windows).rawValue) \(edge)")
      case 2: run("float \(any.rawValue)")
      case 3: run("toggle-float \(any.rawValue)")
      case 4: run("resize \(any.rawValue) \(edge) \(dice.pick([-200, -40, 40, 200]))")
      case 5: run(dice.pick(["dock \(edge)", "float", "toggle-float", "relayout", "save-view 2"]))
      case 6:
        run(dice.pick([
          "show-all", "home", "out", "in", "neighbor \(edge)", "back", "forward", "zoom", "zoom \(any.rawValue)", "desktop",
          "view 2", "arrange", "arrange all", "frame-rect 0 0 1440 900", "exclude com.example.app1", "reload-settings",
          "zoom-node \(dice.roll(12))", "hold", "hold 5",
        ]))
      case 7:
        trail.append("focus \(any)")
        h.system.userFocus(any)
      case 8:
        trail.append("comes-forward \(any)")
        h.system.comesForward(any)
      case 9:
        trail.append("close \(any)")
        h.system.close(any)
        // Its number may come round again, for a window that is another.
        outOfView.remove(any)
      case 10:
        trail.append("minimize \(any)")
        h.system.setMinimized(any, true)
      case 11:
        trail.append("restore \(any)")
        h.system.setMinimized(any, false)
      case 12:
        let pid = h.system.windows[any]!.snapshot.pid
        let hide = dice.roll(2) == 0
        trail.append("\(hide ? "hide" : "unhide") pid \(pid)")
        h.system.setHidden(pid: pid, hide)
      case 13, 14, 15:
        // Only what can be seen can be grabbed.
        guard !shown.isEmpty else { continue }
        let window = dice.pick(shown)
        trail.append("drag \(window) \(point)")
        // An audience watches the drag as well as its end.
        h.system.beginDrag(window, at: h.frame(window)!.center)
        for stop in [CGPoint(x: 700, y: 450), point] {
          h.system.moveDrag(to: stop, holding: 0.3)
          let leaked = showing()
          guard leaked.isEmpty else { return report(leaked, "during the drag, at \(stop)") }
        }
        h.system.endDrag()
      case 16:
        let display = dice.pick(h.overlays.seams.keys.sorted())
        guard let seams = h.overlays.seams[display], !seams.isEmpty else { continue }
        trail.append("seam")
        h.overlays.dragSeam(dice.pick(seams), by: CGFloat(dice.pick([-300, -50, 50, 300])), on: display)
      case 17:
        let display = dice.pick(h.overlays.tiles.keys.sorted())
        guard let tiles = h.overlays.tiles[display], !tiles.isEmpty else { continue }
        trail.append("tile")
        h.overlays.clickTile(dice.pick(tiles).node, on: display)
      case 18:
        let app = dice.pick(["Terminal", "Console", "Other", "App0", "App1", "App2"])
        // Where its app likes: in view, or beside its own window, which is in the corner.
        let offScreen = dice.roll(3) == 0
        trail.append("open \(app)\(offScreen ? " off screen" : "")")
        // Beside a window of its own that is out of view it is something from out of view. Otherwise it is a new window like any other.
        let hasASiblingOutOfView = windows.contains {
          let sibling = h.system.windows[$0]!.snapshot
          // Put there by Arbor: one that its user has dragged over the edge of the display is where they want it.
          return sibling.appName == app && sibling.isPresent && h.controller.parked.contains($0)
        }
        let id = h.system.open(
          app: app, frame: CGRect(x: offScreen ? 1300 : 250, y: offScreen ? 850 : 180, width: 480, height: 320))
        if offScreen, !two, hasASiblingOutOfView { outOfView.insert(id) }
      case 19:
        guard !shown.isEmpty else { continue }
        let window = dice.pick(shown)
        trail.append("pull \(window)")
        h.system.userResize(window, to: h.frame(window)!.insetBy(dx: CGFloat(dice.pick([-60, 40])), dy: 0))
      case 20:
        // To another macOS Space and back. All of a Space's windows go and come together.
        trail.append("another Space and back")
        for away in [false, true] {
          for window in windows { h.system.setOnActiveSpace(window, away) }
          h.scheduler.runPending()
        }
      case 21:
        let on = dice.roll(2) == 0
        trail.append("full screen \(on ? "on" : "off") \(any)")
        h.system.setFullScreen(any, on)
      case 22:
        // A slip. The last one is rare, because it ends the walk.
        let key = dice.pick(["ctrl+opt+shift+f", "ctrl+opt+space", "ctrl+opt+0", "ctrl+opt+shift+f", "ctrl+opt+up", "ctrl+opt+escape"])
        trail.append("key \(key)")
        h.key(key)
      case 23, 24:
        // The keyboard's tiling tools (F22): most are let through.
        run(dice.pick([
          "focus \(edge)", "focus \(edge)", "focus next", "focus previous", "focus \(any.rawValue)", "focus-display next",
          "swap \(edge)", "swap \(any.rawValue) \(edge)", "swap \(any.rawValue) \(dice.pick(windows).rawValue)", "grow", "shrink", "grow 300",
          "shrink 300", "balance", "balance all", "rotate", "mirror", "move-to-display next", "move-to-display next \(any.rawValue)",
        ]))
      default:
        trail.append("flush")
        h.scheduler.runPending()
      }

      for (display, workspace) in h.controller.workspaces {
        let problems = workspace.tree.invariantViolations()
        #expect(problems.isEmpty, "seed \(seed), \(display): \(problems)\n\(trail.joined(separator: "\n"))")
      }
      // The time was up, or the key that pauses let go of it.
      guard h.controller.holdLevel == .view else {
        #expect(!h.controller.isPaused, "seed \(seed)\n\(trail.joined(separator: "\n"))")
        let leaked = showing(exceptOn: empty)
        if !leaked.isEmpty { report(leaked, "when the hold ended") }
        return
      }
      let leaked = showing()
      guard leaked.isEmpty else { return report(leaked, "while the view was held") }
    }
    let empty = h.controller.displaysHeldEmpty
    run("release")
    let leaked = showing(exceptOn: empty)
    if !leaked.isEmpty { report(leaked, "on release") }
  }
}
