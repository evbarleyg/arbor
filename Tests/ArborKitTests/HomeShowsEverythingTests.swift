import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// "After ⌃⌥0 nothing is out of view, without exception" (the guide). Random sessions, and `home` every few steps.
@Suite @MainActor struct HomeShowsEverythingTests {
  struct Dice {
    var state: UInt64
    mutating func roll(_ sides: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(sides))
    }
    mutating func pick<T>(_ items: [T]) -> T? { items.isEmpty ? nil : items[roll(items.count)] }
  }

  func step(_ h: Harness, _ dice: inout Dice) -> String {
    let windows = h.system.allWindows().map(\.id).sorted()
    let id = dice.pick(windows)?.rawValue ?? 0
    let other = dice.pick(windows)?.rawValue ?? 0
    let edge = dice.pick(["left", "right", "top", "bottom"])!
    func run(_ command: String) -> String {
      h.run(command)
      return command
    }
    switch dice.roll(26) {
    case 0 where windows.count < 9:
      let size = CGSize(width: 200 + dice.roll(1200), height: 150 + dice.roll(700))
      let minimum = dice.roll(4) == 0 ? CGSize(width: size.width * 0.9, height: size.height * 0.9) : .zero
      let new = h.system.open(
        app: "App\(dice.roll(4))", pid: Int32(100 + dice.roll(4)),
        frame: CGRect(origin: CGPoint(x: dice.roll(900), y: 30 + dice.roll(500)), size: size), minimumSize: minimum)
      return "open \(new) \(size) min \(minimum)"
    case 1 where windows.count > 2:
      h.system.close(WindowID(id))
      return "close \(id)"
    case 2, 3: return run("dock \(id) \(edge)")
    case 4: return run("dock \(id) beside \(other) \(edge)")
    case 5, 6: return run("float \(id)")
    case 7, 8: return run("zoom \(id)")
    case 9: return run("out")
    case 10: return run("in")
    case 11: return run("neighbor \(edge)")
    case 12: return run("back")
    case 13: return run("desktop")
    case 14, 15: return run("resize \(id) \(edge) \(dice.roll(900) - 450)")
    case 16:
      let minimized = h.system.windows[WindowID(id)]?.snapshot.isMinimized ?? false
      h.system.setMinimized(WindowID(id), !minimized)
      return "\(minimized ? "restore" : "minimize") \(id)"
    case 17:
      let pid = Int32(100 + dice.roll(4))
      let hidden = h.system.allWindows().first { $0.pid == pid }?.isHidden ?? false
      h.system.setHidden(pid: pid, !hidden)
      return "\(hidden ? "unhide" : "hide") \(pid)"
    case 18: return run("arrange")
    case 19 where dice.roll(3) == 0: return run("float-all")
    case 20: return run("toggle-pin \(id)")
    case 21, 22:
      h.system.userFocus(WindowID(id))
      return "focus \(id)"
    case 23:
      h.run("pause")
      return run("resume")
    case 24:
      guard let frame = h.frame(WindowID(id)), h.system.isVisible(WindowID(id)) else { return "nothing" }
      h.system.userMove(WindowID(id), to: frame.offsetBy(dx: CGFloat(dice.roll(600) - 300), dy: CGFloat(dice.roll(300) - 150)))
      return "move \(id)"
    default:
      h.scheduler.advance(by: 1)
      return "wait"
    }
  }

  @Test(arguments: 1...40) func afterHomeNothingIsOutOfView(seed: UInt64) {
    let h = Harness()
    for index in 0..<4 {
      h.system.open(
        app: "App\(index)", pid: Int32(100 + index),
        frame: CGRect(x: 100 + index * 90, y: 100 + index * 60, width: 500, height: 350))
    }
    h.start()
    var dice = Dice(state: seed)
    var log: [String] = []
    for count in 0..<400 {
      log.append(step(h, &dice))
      guard count % 5 == 4 else { continue }
      h.scheduler.advance(by: 2)
      h.run("home")
      log.append("home")
      let state = h.controller.snapshot()
      let tiled = Set((h.layout?.tiles ?? []).flatMap(\.windows))
      for window in state.windows where window.managed && !window.minimized && !window.hidden && !window.fullScreen {
        // More than the line a window out of view leaves. The session's own moves can hang a window far over the edge.
        let showing = window.frame.intersection(h.system.displayList[0].frame)
        let shows = showing.width > 2 && showing.height > 2
        if window.docked {
          let behindATab = h.workspace.tree.leaf(containing: window.id).map { h.workspace.tree.activeWindow(of: $0) != window.id } ?? false
          #expect(shows || tiled.contains(window.id) || behindATab, "\(window.id) docked, out of view\n\(log.suffix(14).joined(separator: "\n"))\n\(h.ascii())")
        } else {
          #expect(shows, "\(window.id) floats at \(window.frame), out of view\nseed \(seed)\n\(log.suffix(14).joined(separator: "\n"))\n\(h.ascii())")
        }
        if !shows && !window.docked { return }
      }
    }
    h.controller.shutdown()
  }
}
