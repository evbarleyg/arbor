import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A couple of thousand random steps, and after each one the promises every transition has to keep,
/// whatever led to it.
@Suite @MainActor struct TransitionInvariantTests {
  /// Small, fast and the same on every platform.
  struct Random {
    var state: UInt64
    mutating func next() -> UInt64 {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return state >> 33
    }
    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }
    mutating func pick<T>(_ items: [T]) -> T? { items.isEmpty ? nil : items[below(items.count)] }
  }

  /// The windows that show as themselves on the display right now.
  func showing(_ h: Harness) -> [WindowID: CGRect] {
    let screen = h.system.displayList[0].frame
    var frames: [WindowID: CGRect] = [:]
    for (id, window) in h.controller.windows
    where window.isPresent && !h.controller.parked.contains(id) && window.frame.overlaps(screen) {
      frames[id] = window.frame
    }
    return frames
  }

  func step(_ h: Harness, _ random: inout Random) -> String {
    let windows = h.system.allWindows().map(\.id)
    let edges = ["left", "right", "up", "down"]
    let window = random.pick(windows)?.rawValue ?? 0
    let other = random.pick(windows)?.rawValue ?? 0
    let edge = random.pick(edges)!
    switch random.below(24) {
    case 0:
      guard windows.count < 9 else { return "nothing" }
      let minimum = random.below(5) == 0 ? CGSize(width: 900, height: 600) : .zero
      let id = h.system.open(
        app: "App\(random.below(4))",
        frame: CGRect(x: 50 + random.below(800), y: 60 + random.below(400), width: 300 + random.below(400), height: 200 + random.below(300)),
        minimumSize: minimum)
      if random.below(4) == 0 { h.system.setMaximumSize(id, CGSize(width: 320, height: 260)) }
      return "open \(id)"
    case 1:
      guard windows.count > 1, let id = random.pick(windows) else { return "nothing" }
      h.system.close(id)
      return "close \(id)"
    case 2, 3, 4: return run(h, "dock \(window) \(edge)")
    case 5, 6: return run(h, "dock \(window) beside \(other) \(edge)")
    case 7: return run(h, "float \(window)")
    case 8, 9, 10: return run(h, "zoom \(window)")
    case 11: return run(h, "back")
    case 12: return run(h, "forward")
    case 13: return run(h, "neighbor \(edge)")
    case 14: return run(h, "out")
    case 15:
      h.system.cursor = CGPoint(x: random.below(1440), y: random.below(900))
      return run(h, "in")
    case 16: return run(h, "show-all")
    case 17: return run(h, "desktop")
    case 18:
      guard let id = random.pick(windows) else { return "nothing" }
      let minimized = h.controller.windows[id]?.isMinimized ?? false
      h.system.setMinimized(id, !minimized)
      return "\(minimized ? "restore" : "minimize") \(id)"
    case 19: return run(h, "resize \(window) \(edge) \(random.below(200) - 100)")
    case 20: return run(h, random.below(3) == 0 ? "arrange" : "float-all")
    case 21:
      guard let tile = random.pick(h.layout?.tiles ?? []) else { return "nothing" }
      h.overlays.clickTile(tile.node)
      return "tile \(tile.node)"
    case 22:
      guard let id = random.pick(windows) else { return "nothing" }
      h.system.userFocus(id)
      return "focus \(id)"
    default:
      guard let id = random.pick(windows), let frame = h.frame(id), showing(h)[id] != nil else { return "nothing" }
      h.system.drag(
        id,
        through: [
          CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: 700, y: 400),
          CGPoint(x: random.below(1440), y: 30 + random.below(860)),
        ])
      return "drag \(id)"
    }
  }

  func run(_ h: Harness, _ command: String) -> String {
    h.run(command)
    return command
  }

  @Test(arguments: [1, 2, 3, 4]) func everyTransitionKeepsItsPromises(seed: UInt64) {
    var settings = Settings.withMotion
    settings.tabsEnabled = seed % 2 == 0
    let h = Harness(settings: settings)
    for index in 0..<4 { h.system.open(app: "App\(index)", frame: CGRect(x: 100 + index * 90, y: 100 + index * 60, width: 500, height: 350)) }
    h.start()
    let screen = h.system.displayList[0].frame
    var random = Random(state: seed)
    var played = 0
    // One step can be several reports: macOS names the next window to have the keyboard before it says that the
    // one that had it has closed. So a transition is judged by what is known as it arrives.
    var drawnThoughGone: [WindowID] = []
    h.overlays.onAnimate = { transition in
      drawnThoughGone += transition.items.map(\.window).filter { h.controller.windows[$0]?.isPresent != true }
    }

    for count in 0..<500 {
      let before = showing(h)
      let inTheDock = Set(h.system.windows.filter(\.value.snapshot.isMinimized).keys)
      h.overlays.clearTransitions()
      drawnThoughGone = []
      let what = step(h, &random)
      let after = showing(h)
      guard let first = h.overlays.transitions.first, let last = h.overlays.transitions.last else { continue }
      played += 1
      let context = "seed \(seed), step \(count): \(what)\n\(last)"

      for transition in h.overlays.transitions {
        #expect(Set(transition.items.map(\.window)).count == transition.items.count, "a window is drawn twice\n\(context)")
        for item in transition.items {
          #expect(item.from.isFinite && item.to.isFinite, "\(context)")
          #expect(item.fromOpacity > 0 || item.toOpacity > 0, "\(item.window) is never seen\n\(context)")
        }
      }
      #expect(drawnThoughGone.isEmpty, "drawn although gone\n\(context)")
      // Not the window the step itself takes away: the view may have followed the focus to its app's next window
      // while it was still there (`drawnThoughGone` judges that transition), and nothing more may have moved after.
      for item in last.items where what != "minimize \(item.window)" && what != "close \(item.window)" {
        #expect(h.controller.windows[item.window]?.isPresent == true, "\(item.window) is gone\n\(context)")
      }
      #expect(first.hasMotion, "a stage for nothing\n\(context)")

      // The stage hides every real window, so whatever shows at either end is drawn, where it is.
      // (One step can be several relayouts; the first starts from what was there before the step.)
      for (window, frame) in before where h.controller.windows[window]?.isPresent == true {
        guard what.hasPrefix("drag") == false else { break }  // the user moved it first
        #expect(first[window]?.from == frame, "\(window) does not start where it is\n\(context)")
        #expect(first[window]?.fromOpacity == 1 && first[window]?.fromLook == .picture, "\(context)")
      }
      // Not a window the step fetched out of the Dock: a command that names a minimized window gives it the keyboard, and it comes back when
      // the command's own motion is over. That is a second thing, like a step that restores it, which may need no stage.
      for (window, frame) in after where !inTheDock.contains(window) || what == "restore \(window)" {
        #expect(last[window]?.to.approximatelyEquals(frame, tolerance: 1) == true, "\(window) does not end where it is\n\(context)")
        #expect(last[window]?.toOpacity == 1 && last[window]?.toLook == .picture, "\(context)")
      }
      // Whatever does not show at the end is a cover in a tile, off the display, or faded out.
      let tiled = Set((h.layout?.tiles ?? []).flatMap(\.windows))
      // (Again not the window the step itself takes away, which was still there when the view followed the focus.)
      for item in last.items
      where after[item.window] == nil && what != "minimize \(item.window)" && what != "close \(item.window)" {
        if item.toLook == .cover, item.toOpacity == 1, tiled.contains(item.window), item.to.overlaps(screen) { continue }
        #expect(item.toOpacity == 0 || !item.to.overlaps(screen), "\(item.window) is left in sight\n\(context)")
      }
    }
    // That the walk is not idle. Most seeds play 140 and more; the leanest of sixty played 102, and any change of behaviour shifts that a little.
    // (Since nothing is kept for the Desktop, `desktop` from an arrangement that fills the display has no rectangle to fly to, and plays none: 80.)
    #expect(played > 70)
    h.controller.shutdown()
  }
}
