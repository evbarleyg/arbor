import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Random walks with `soleFloatTakesDesktop` on. Whatever happens, the frame remembered as a window's own is never the one
/// Arbor stretched it to, no window is lost, and letting go gives every floating window its own size back.
@Suite @MainActor struct SoleFloatFuzzTests {
  struct Random {
    var state: UInt64
    mutating func below(_ n: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(n))
    }
  }

  @Test(arguments: Array(1...200).map { UInt64($0) }) func theWindowsOwnFrameSurvives(seed: UInt64) {
    var random = Random(state: seed)
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    var ids: [WindowID] = []
    for index in 0..<4 {
      let origin = CGPoint(x: 100 + index * 150, y: 80 + index * 70)
      let size = CGSize(width: 330 + index * 17, height: 230 + index * 13)
      ids.append(h.system.open(app: "App\(index)", pid: Int32(100 + index), frame: CGRect(origin: origin, size: size)))
    }
    h.start()
    var log: [String] = []
    func run(_ command: String) {
      log.append(command)
      h.run(command)
    }
    for _ in 0..<60 {
      guard let window = ids.isEmpty ? nil : ids[random.below(ids.count)] else { break }
      let other = ids[random.below(ids.count)]
      let edge = ["left", "right", "top", "bottom"][random.below(4)]
      switch random.below(16) {
      case 0, 1: run("dock \(window.rawValue) \(edge)")
      case 2: run("dock \(window.rawValue) beside \(other.rawValue) \(edge)")
      case 3, 4: run("float \(window.rawValue)")
      case 5: run("zoom \(window.rawValue)")
      case 6: run("back")
      case 7: run("show-all")
      case 8: run("desktop")
      case 9:
        let minimized = h.controller.windows[window]?.isMinimized ?? false
        log.append("\(minimized ? "restore" : "minimize") \(window)")
        h.system.setMinimized(window, !minimized)
      case 10: run("resize \(window.rawValue) \(edge) \(random.below(300) - 150)")
      case 11:
        guard ids.count < 7 else { continue }
        let origin = CGPoint(x: 60 + random.below(900), y: 60 + random.below(500))
        let size = CGSize(width: 311 + random.below(90), height: 207 + random.below(90))
        let id = h.system.open(app: "New", pid: Int32(200 + ids.count), frame: CGRect(origin: origin, size: size))
        log.append("open \(id)")
        ids.append(id)
      case 12:
        guard ids.count > 2 else { continue }
        log.append("close \(window)")
        h.system.close(window)
        ids.removeAll { $0 == window }
      case 13: run(random.below(2) == 0 ? "pin \(window.rawValue)" : "unpin \(window.rawValue)")
      case 14: run(random.below(3) == 0 ? "float-all" : "toggle-pause")
      default:
        guard h.controller.isRunning, let frame = h.frame(window), h.system.isVisible(window),
          h.controller.windows[window]?.isPresent == true
        else { continue }
        log.append("drag \(window)")
        h.system.drag(
          window,
          through: [
            CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: 700, y: 400),
            CGPoint(x: 20 + random.below(1400), y: 40 + random.below(800)),
          ])
      }
      h.scheduler.advance(by: 0.6)
      guard h.controller.isRunning else { continue }
      let context = "seed \(seed): \(log.joined(separator: " ; "))\n\(h.ascii())"
      // Nobody in this walk ever gives a window the Desktop's size by hand (a drag off the Desktop ends at its own size).
      if let desktop = h.layout?.desktopFrame, !h.workspace.tree.allWindows.isEmpty {
        for (window, own) in h.workspace.floating {
          #expect(own.size != desktop.size, "\(window)'s own frame is the Desktop's\n\(context)")
        }
      }
      for window in ids where h.controller.windows[window]?.isPresent == true {
        // A drag can leave most of a window beyond the edge; that is its user's business. Lost is what hardly shows at all.
        let showing = h.frame(window)!.intersection(h.system.displayList[0].frame)
        #expect(
          showing.width * showing.height > 2000 || h.controller.parked.contains(window),
          "\(window) is lost at \(h.frame(window)!)\n\(context)")
      }
    }
    if h.controller.isPaused { run("resume") }
    let context = "seed \(seed): \(log.joined(separator: " ; "))"
    let owns = h.workspace.floating
    h.controller.shutdown()
    for (window, own) in owns where h.system.windows[window] != nil {
      let size = h.frame(window)!.size
      #expect(
        size.width <= own.width + 1 && size.height <= own.height + 1, "\(window) is left at \(h.frame(window)!), its own is \(own)\n\(context)")
      #expect(h.system.isVisible(window), "\(window) is left out of view\n\(context)")
    }
  }
}
