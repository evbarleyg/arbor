import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// Seeded journeys through everything a person, an app or a script can do to the controller, for tests that hold a property
/// rather than a scenario.
@MainActor enum RandomJourney {
  /// Numbers that are the same in every run with the same seed.
  struct Dice {
    var state: UInt64

    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }

    mutating func roll(_ sides: Int) -> Int { Int(next() % UInt64(max(sides, 1))) }
    mutating func pick<Element>(_ list: [Element]) -> Element? { list.isEmpty ? nil : list[roll(list.count)] }
  }

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false, name: "Side Display")

  /// The defaults, but that a camera and a window of Terminal's count as a call: both ship off, and the steps about them would do nothing.
  static var settings: Settings {
    var settings = Settings()
    settings.holdStillWhileCameraIsOn = true
    settings.holdStillFor = ["com.example.terminal"]
    return settings
  }

  static let apps = ["Safari", "Mail", "Notes", "Terminal", "Xcode"]
  /// Each app is a process of its own, or quitting one would close every window and hiding one would hide them all.
  static func pid(of app: String) -> Int32 { 1000 + Int32(apps.firstIndex(of: app) ?? apps.count) }

  /// One thing a person, an app or a script does. Returns what it was, for the message of a failure.
  /// - Parameter settings: false leaves the gap as it is. (Which apps are arranged is a setting too, and changes all the same.)
  static func step(_ h: Harness, _ dice: inout Dice, settings: Bool = true) -> String {
    let windows = h.system.allWindows().map(\.id).sorted()
    let window = dice.pick(windows)?.rawValue ?? 0
    let other = dice.pick(windows)?.rawValue ?? 0
    let edge = dice.pick(["left", "right", "top", "bottom"])!
    func run(_ text: String) -> String {
      h.run(text)
      return text
    }
    func open() -> String {
      let app = dice.pick(apps)!
      let x = CGFloat(dice.roll(h.system.displays().count > 1 ? 2800 : 900))
      h.system.open(app: app, pid: pid(of: app), frame: CGRect(x: x, y: CGFloat(60 + dice.roll(300)), width: 500, height: 400))
      return "open \(app) at \(x)"
    }
    // Left to the dice below, a pause lasts some 65 steps and a screen without a window some 30: most of a journey, with nothing to see.
    if h.controller.isPaused, dice.roll(4) == 0 { return run("resume") }
    if windows.isEmpty, dice.roll(2) == 0 { return open() }
    // With a window in hand a person carries it on or lets it go; apps go on doing what they do. (Commands for the very window
    // that is being dragged leave the controller's books in a state of their own: K1830 in collab/BACKLOG.md.)
    let busy = [47, 47, 47, 48, 49, 49, 0, 2, 31, 34, 38, 42, 58]
    switch h.system.isMouseButtonDown() ? dice.pick(busy)! : dice.roll(65) {
    case 0, 1:
      guard windows.count < 9 else { return run("show-all") }
      return open()
    case 2:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.close(id)
      return "close \(id)"
    case 3, 4, 5: return run("dock \(window) \(edge)")
    case 6: return run("dock \(window) beside \(other) \(edge)")
    case 7: return run("float \(window)")
    case 8, 9: return run("zoom \(window)")
    case 10: return run("out")
    case 11: return run("in")
    case 12: return run("show-all")
    case 13: return run("back")
    case 14: return run("forward")
    case 15: return run("desktop")
    case 16: return run("neighbor \(edge == "top" ? "up" : edge == "bottom" ? "down" : edge)")
    case 17: return run("arrange")
    case 18: return run("float-all")
    case 19: return run("toggle-pin \(window)")
    case 20: return run("summon \(dice.pick(apps)!)")
    case 21: return run("name Space\(dice.roll(3))")
    case 22: return run("unname")
    case 23: return run("save-view \(1 + dice.roll(3))")
    case 24: return run("view \(1 + dice.roll(3))")
    case 25: return run("home")
    case 26: return run(h.controller.isPaused ? "resume" : "pause")
    case 27: return run("exclude com.example.\(dice.pick(apps)!.lowercased())")
    case 28: return run("include com.example.\(dice.pick(apps)!.lowercased())")
    case 29: return settings ? run("set gap \(4 + dice.roll(30))") : run("relayout")
    case 30: return run("resize \(window) \(edge) \(dice.roll(200) - 100)")
    case 31:
      guard let id = dice.pick(windows), let snapshot = h.system.allWindows().first(where: { $0.id == id }) else { return "nothing" }
      h.system.setMinimized(id, !snapshot.isMinimized)
      return "minimize or restore \(id)"
    case 32:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.setHidden(pid: snapshot.pid, !snapshot.isHidden)
      return "hide or show pid \(snapshot.pid)"
    case 33:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.setFullScreen(snapshot.id, !snapshot.isFullScreen)
      return "full screen on or off \(snapshot.id)"
    case 34:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.setOnActiveSpace(snapshot.id, !snapshot.isOnActiveSpace)
      return "another Space, or back \(snapshot.id)"
    case 35, 36:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.userFocus(id)
      return "click \(id)"
    case 37:
      h.system.userFocusesNothing()
      return "click the wallpaper"
    case 38:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.setTitle(id, "Title \(dice.roll(5))")
      return "a new title for \(id)"
    case 39:
      let two = h.system.displays().count > 1
      h.system.setDisplays(two ? [FakeWindowSystem.standardDisplay] : [FakeWindowSystem.standardDisplay, Self.side])
      return two ? "unplug" : "plug in"
    case 40:
      guard let id = dice.pick(windows), let frame = h.frame(id) else { return "nothing" }
      let wide = h.system.displays().count > 1 ? 3300 : 1400
      let point = CGPoint(x: CGFloat(20 + dice.roll(wide)), y: CGFloat(40 + dice.roll(800)))
      h.system.drag(id, through: [CGPoint(x: frame.midX, y: frame.minY + 10), frame.center, point])
      return "drag \(id) to \(point)"
    case 41:
      guard let snapshot = dice.pick(h.system.allWindows()) else { return "nothing" }
      h.system.quit(pid: snapshot.pid)
      return "quit pid \(snapshot.pid)"
    case 42:
      guard let id = dice.pick(windows) else { return "nothing" }
      h.system.backgroundFocus(id)
      return "a report from the background, \(id)"
    case 43:
      guard let id = dice.pick(windows) else { return "nothing" }
      let size = CGSize(width: CGFloat(200 + dice.roll(700)), height: CGFloat(150 + dice.roll(500)))
      h.system.setMinimumSize(id, size)
      return "\(id) refuses to be smaller than \(size)"
    case 44, 45: return run("dock \(edge)")
    case 46:
      // A drag in three steps, so that whoever compares something after every step sees it under way.
      guard !h.system.isMouseButtonDown(), let id = dice.pick(windows) else { return "nothing" }
      h.system.beginDrag(id)
      return "take \(id) by its title bar"
    case 47, 48:
      guard h.system.isMouseButtonDown() else { return "nothing" }
      let wide = h.system.displays().count > 1 ? 3300 : 1400
      let point = CGPoint(x: CGFloat(20 + dice.roll(wide)), y: CGFloat(40 + dice.roll(800)))
      h.system.moveDrag(to: point, holding: Double(dice.roll(8)) / 10)
      return "carry it to \(point)"
    case 49:
      guard h.system.isMouseButtonDown() else { return "nothing" }
      h.system.endDrag()
      return "let it go"
    case 50:
      let tiles = h.overlays.tiles.sorted { $0.key < $1.key }.flatMap { display, tiles in tiles.map { (display, $0.node) } }
      guard let (display, node) = dice.pick(tiles) else { return "nothing" }
      h.controller.tileActivated(display: display, node: node)
      return "click the tile of \(node) on \(display)"
    case 52:
      let names = Array(Set(h.system.allWindows().map(\.appName))).sorted()
      guard names.count > 1 else { return "nothing" }
      return run("layout " + names.prefix(2 + dice.roll(3)).joined(separator: dice.roll(2) == 0 ? " | " : " / "))
    case 51: return run(dice.pick(["grow", "shrink", "grow 120", "shrink 120", "balance", "rotate"])!)
    case 54: return run("hold")
    case 55: return run("hold still")
    case 56, 57: return run("release")
    case 62: return run("minimap")
    case 63: return run("show-shortcuts")
    case 64: return run("find")
    case 60:
      h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
      return "a camera goes on"
    case 61:
      h.controller.callSignalsChanged(CallSignals())
      return "the camera goes off"
    case 53:
      // Longer than anything Arbor puts off, tiles that are asked again included.
      h.scheduler.advance(by: 700)
      return "a long time passes"
    default:
      h.scheduler.advance(by: Double(dice.roll(30)) / 10)
      return "time passes"
    }
  }
}
