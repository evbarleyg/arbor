import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay

/// Random walks through everything a person and macOS can do, with windows pinned (F49) and summoned (F53) along the way.
/// Whatever happens: a window that is kept in view is in view, one that was sent away is not, no window plays two
/// parts, and when Arbor lets go every window is back.
@Suite @MainActor struct PinSummonWalkTests {
  struct Random {
    var state: UInt64
    mutating func below(_ n: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(n))
    }
  }

  @Test(arguments: Array(1...300).map { UInt64($0) }) func everyWindowPlaysItsPart(seed: UInt64) {
    var random = Random(state: seed)
    var settings = Settings()
    settings.summonStays = random.below(2) == 0
    settings.soleFloatTakesDesktop = random.below(2) == 0
    var h = Harness(displays: [main, side], settings: settings)
    var ids: [WindowID] = []
    for index in 0..<5 {
      let origin = CGPoint(x: 100 + index * 260, y: 80 + index * 60)
      let size = CGSize(width: 330 + index * 17, height: 230 + index * 13)
      ids.append(h.system.open(app: "App\(index)", pid: Int32(100 + index), frame: CGRect(origin: origin, size: size)))
    }
    h.start()
    var log: [String] = []
    var sideIsPlugged = true
    /// Apps that have not answered at some time: Arbor cannot move their windows, so they are where they are.
    var hung: Set<Int32> = []
    /// Windows their user left mostly off the screen by hand. There they stay, until something brings them back.
    var leftOutByHand: Set<WindowID> = []
    /// The size each window opened at. Nobody in this walk resizes a floating window by hand, so it is its own size.
    var own: [WindowID: CGSize] = [:]
    for window in ids { own[window] = h.frame(window)!.size }
    func isArborsToPlace(_ window: WindowID) -> Bool {
      !leftOutByHand.contains(window) && h.controller.windows[window].map { !hung.contains($0.pid) } == true
    }
    func run(_ command: String) {
      log.append(command)
      h.run(command)
    }
    func note(_ event: String) { log.append("(\(event))") }

    func check(_ sourceLocation: SourceLocation = #_sourceLocation) -> Bool {
      var faults: [String] = []
      leftOutByHand = leftOutByHand.filter { !h.system.isVisible($0) }
      var homes: [WindowID: Int] = [:]
      for (display, workspace) in h.controller.workspaces.sorted(by: { $0.key < $1.key }) {
        for window in Set(workspace.tree.allWindows).union(workspace.floating.keys) { homes[window, default: 0] += 1 }
        let pinned = Set(workspace.pinnedWindows)
        let stashed = Set(workspace.stashedWindows)
        let summoned = Set([workspace.summoned?.window].compactMap { $0 })
        let floating = Set(workspace.floating.keys)
        if !pinned.union(stashed).union(summoned).isSubset(of: floating) { faults.append("a part without a floating window on \(display)") }
        if pinned.count + stashed.count + summoned.count != pinned.union(stashed).union(summoned).count {
          faults.append("a window plays two parts on \(display)")
        }
        for window in floating {
          guard let snapshot = h.controller.windows[window], snapshot.isPresent, h.controller.isRunning,
            isArborsToPlace(window)
          else { continue }
          // As much of its own size as its display has room for.
          let room = h.system.displayList.first { $0.id == display }?.visibleFrame.size ?? .zero
          if workspace.role(of: window) != nil,
            let size = own[window].map({ CGSize(width: min($0.width, room.width), height: min($0.height, room.height)) }),
            snapshot.frame.size != size
          {
            faults.append("\(window) plays a part at \(Int(snapshot.frame.width))x\(Int(snapshot.frame.height)), not its own \(Int(size.width))x\(Int(size.height))")
          }
          if workspace.staysInView(window) {
            if h.controller.parked.contains(window) { faults.append("\(window) stays in view but counts as out of view") }
            if !h.system.isVisible(window) { faults.append("\(window) stays in view but is at \(snapshot.frame)") }
          }
          if workspace.isStashed(window), h.system.isVisible(window) {
            faults.append("\(window) was sent away but is in view at \(snapshot.frame)")
          }
        }
      }
      for (window, count) in homes where count > 1 { faults.append("\(window) is in \(count) workspaces") }
      if !h.controller.isRunning {
        // Those Arbor arranges: an excluded app's windows are nobody's but their user's.
        for window in h.system.allWindows() where window.isPresent && homes[window.id] != nil && isArborsToPlace(window.id) && !h.system.isVisible(window.id) {
          faults.append("paused, and \(window.id) is out of view at \(window.frame)")
        }
      }
      guard !faults.isEmpty else { return true }
      Issue.record(
        "seed \(seed): \(faults.joined(separator: "; "))\n  \(log.joined(separator: " | "))", sourceLocation: sourceLocation)
      return false
    }

    for _ in 0..<70 {
      guard let window = ids.isEmpty ? nil : ids[random.below(ids.count)] else { break }
      let other = ids[random.below(ids.count)]
      let edge = ["left", "right", "top", "bottom"][random.below(4)]
      let app = h.controller.windows[window]?.appName ?? "App0"
      let floated = h.controller.workspaces.values.contains { $0.isFloating(window) }
      switch random.below(55) {
      case 0, 1: run("dock \(window.rawValue) \(edge)")
      case 2: run("dock \(window.rawValue) beside \(other.rawValue) \(edge)")
      case 3: run("float \(window.rawValue)")
      case 4: run("toggle-float \(window.rawValue)")
      case 5, 6: run("zoom \(window.rawValue)")
      case 7: run(["back", "forward", "out", "in"][random.below(4)])
      case 8: run("show-all")
      case 9: run("desktop")
      case 10: run("home")
      case 11: run("neighbor \(edge)")
      case 12: run(random.below(2) == 0 ? "arrange" : "arrange all")
      case 13: run(random.below(2) == 0 ? "float-all" : "float-all here")
      case 14: run("resize \(window.rawValue) \(edge) \(random.below(300) - 150)")
      case 15, 16, 17: run("pin \(window.rawValue)")
      case 18: run("unpin \(window.rawValue)")
      case 19: run("toggle-pin \(window.rawValue)")
      case 20, 21, 22, 23: run("summon \(app)")
      case 24: run("toggle-pause")
      case 25: run("relayout")
      case 26: run("set summonStays toggle")
      case 27:
        let minimized = h.controller.windows[window]?.isMinimized ?? false
        note("\(minimized ? "restore" : "minimize") \(window)")
        h.system.setMinimized(window, !minimized)
      case 28:
        guard let snapshot = h.controller.windows[window] else { continue }
        note("\(snapshot.isHidden ? "show" : "hide") \(app)")
        h.system.setHidden(pid: snapshot.pid, !snapshot.isHidden)
      case 29:
        guard ids.count < 8 else { continue }
        let origin = CGPoint(x: 60 + random.below(sideIsPlugged ? 2200 : 1000), y: 60 + random.below(450))
        let id = h.system.open(app: "New\(ids.count)", pid: Int32(200 + ids.count), frame: CGRect(origin: origin, size: CGSize(width: 320, height: 220)))
        note("open \(id)")
        ids.append(id)
        own[id] = CGSize(width: 320, height: 220)
      case 30:
        guard ids.count > 2 else { continue }
        note("close \(window)")
        h.system.close(window)
        ids.removeAll { $0 == window }
      case 31, 32:
        guard h.controller.windows[window]?.isPresent == true else { continue }
        note("focus \(window)")
        h.system.userFocus(window)
      case 33:
        guard h.controller.windows[window]?.isPresent == true, h.system.isVisible(window) else { continue }
        note("click \(window)")
        h.system.userClick(window)
      case 34:
        // While Arbor is paused the windows of a display that goes are macOS's to move, which the fake does not do.
        guard h.controller.isRunning else { continue }
        sideIsPlugged.toggle()
        note(sideIsPlugged ? "plug in" : "unplug")
        h.system.setDisplays(sideIsPlugged ? [main, side] : [main])
      case 35:
        guard let snapshot = h.controller.windows[window] else { continue }
        note("\(window) \(snapshot.isOnActiveSpace ? "leaves" : "returns to") the Space")
        h.system.setOnActiveSpace(window, !snapshot.isOnActiveSpace)
      case 36:
        guard h.controller.windows[window]?.isPresent == true, h.system.isVisible(window), let frame = h.frame(window) else { continue }
        let to = CGRect(x: CGFloat(40 + random.below(sideIsPlugged ? 2300 : 1000)), y: CGFloat(40 + random.below(450)), width: frame.width, height: frame.height)
        note("move \(window) to \(Int(to.minX)),\(Int(to.minY))")
        h.system.userMove(window, to: to)
        if !h.system.isVisible(window) { leftOutByHand.insert(window) }
        // Taken in hand at a size Arbor gave it (squeezed, or all over the Desktop): which size is its own from then on is
        // not for this walk to say. (Moved to another display while it fills the Desktop it loses its own: sent to F18.)
        if floated, let size = own[window], h.frame(window)!.size != size { own[window] = nil }
      case 37:
        guard h.controller.isRunning, h.controller.windows[window]?.isPresent == true, h.system.isVisible(window) else { continue }
        // Not so low that most of it hangs below the screen: where its user leaves a window, there it stays.
        let to = CGPoint(x: 30 + random.below(sideIsPlugged ? 2600 : 1380), y: 40 + random.below(480))
        note("drag \(window) to \(Int(to.x)),\(Int(to.y))")
        // From its title bar: a drag that begins elsewhere would jump there without a word.
        let frame = h.frame(window)!
        h.system.drag(window, through: [CGPoint(x: frame.midX, y: frame.minY + 10), to])
        if !h.system.isVisible(window) { leftOutByHand.insert(window) }
        // Taken in hand at a size Arbor gave it (squeezed, or all over the Desktop): which size is its own from then on is
        // not for this walk to say. (Moved to another display while it fills the Desktop it loses its own: sent to F18.)
        if floated, let size = own[window], h.frame(window)!.size != size { own[window] = nil }
      case 38:
        guard let bundle = h.controller.windows[window]?.bundleID else { continue }
        run(random.below(2) == 0 ? "exclude \(bundle)" : "include \(bundle)")
      case 39:
        let names = ids.compactMap { h.controller.windows[$0]?.appName }
        guard names.count >= 2 else { continue }
        let (a, b) = (names[random.below(names.count)], names[random.below(names.count)])
        // A window docked by a line does not get its size back yet (sent to the owners of F54 and F48).
        for id in ids where [a, b].contains(h.controller.windows[id]?.appName ?? "") { own[id] = nil }
        run(["layout \(a) | Desktop | \(b)", "layout \(a) / \(b)", "layout Desktop | [\(a) \(b)]", "layout (\(a) / \(b)) | Desktop"][random.below(4)])
      case 40:
        guard let snapshot = h.controller.windows[window], snapshot.isPresent || snapshot.isFullScreen else { continue }
        note("\(window) \(snapshot.isFullScreen ? "leaves" : "enters") full screen")
        h.system.setFullScreen(window, !snapshot.isFullScreen)
        own[window] = nil
      case 41:
        guard h.controller.windows[window]?.isPresent == true else { continue }
        note("switch to \(app)")
        h.system.userSwitchesApp(to: window)
      case 42:
        guard h.controller.windows[window]?.isPresent == true else { continue }
        note("background focus \(window)")
        h.system.backgroundFocus(window)
      case 43:
        guard ids.count > 3, let pid = h.controller.windows[window]?.pid else { continue }
        note("quit \(app)")
        h.system.quit(pid: pid)
        ids.removeAll { h.system.frame(of: $0) == nil }
      case 44:
        guard let pid = h.controller.windows[window]?.pid else { continue }
        let hangs = random.below(2) == 0
        note("\(app) \(hangs ? "hangs" : "answers")")
        h.system.setUnresponsive(pid: pid, hangs)
        if hangs { hung.insert(pid) }
      case 45:
        guard ids.count < 9, h.controller.windows[window]?.isPresent == true, let tab = h.system.openTab(in: window) else { continue }
        note("tab \(tab) in \(window)")
        ids.removeAll { $0 == window }
        ids.append(tab)
      case 47:
        // The same windows seen by a new Arbor process that loads what the old one saved.
        let killed = random.below(2) == 0
        note(killed ? "killed, started again by the watchdog" : "quit, launched again")
        h.scheduler.advance(by: 5)
        let pinned = Set(h.controller.workspaces.values.flatMap(\.pinnedWindows))
        let away = Set(h.controller.workspaces.values.flatMap(\.stashedWindows))
        if !killed {
          h.controller.shutdown()
          for window in h.system.allWindows()
          where window.isPresent && isArborsToPlace(window.id) && !h.system.isVisible(window.id)
            && h.controller.workspaces.values.contains(where: { $0.isFloating(window.id) || $0.isDocked(window.id) })
          {
            Issue.record("seed \(seed): quit, and \(window.id) is out of view at \(window.frame)\n  \(log.joined(separator: " | "))")
            return
          }
        }
        // Through JSON, as through state.json.
        let saved = h.store.saved.flatMap { try? JSONDecoder().decode(PersistedState.self, from: JSONEncoder().encode($0)) }
        if (saved == nil) != (h.store.saved == nil) {
          Issue.record("seed \(seed): what was saved cannot be read back\n  \(log.joined(separator: " | "))")
          return
        }
        h = Harness(settings: h.controller.settings, saved: saved, system: h.system)
        h.controller.restartedAfterAccident = killed
        h.start()
        h.scheduler.advance(by: 3)
        let still = Set(h.controller.workspaces.values.flatMap(\.pinnedWindows))
        let lost = pinned.subtracting(still).filter { h.controller.windows[$0] != nil }
        if !lost.isEmpty {
          Issue.record("seed \(seed): launched again, \(lost.sorted()) are no longer pinned\n  \(log.joined(separator: " | "))")
          return
        }
        // Nobody quit: what was sent away still is. One that has the keyboard is summoned at once, as after ⌘Tab.
        let back = away.filter { id in
          h.controller.windows[id] != nil && !h.controller.workspaces.values.contains { $0.isStashed(id) || $0.isSummoned(id) }
        }
        // Unless the view would have taken a window out of view, and everything shows instead.
        let shown = back.filter { id in h.controller.workspaces.values.contains { $0.isFloating(id) && $0.camera == $0.tree.root } }
        if killed, back != shown {
          Issue.record("seed \(seed): started again, \(back.sorted()) are no longer sent away\n  \(log.joined(separator: " | "))")
          return
        }
        // The quit brought them into view, and a launch takes nothing out of it.
        if !killed, back != away.filter({ h.controller.windows[$0] != nil }) {
          Issue.record("seed \(seed): launched again, \(away.subtracting(back).sorted()) are sent away again\n  \(log.joined(separator: " | "))")
          return
        }
      case 50, 51: run("reveal \(window.rawValue)")
      case 52: run("find \(app)")
      case 53: run("toggle-auto-dock")
      // Not `hold` yet: whether a pinned window may come into a held view is with the product owner.
      case 54: run(["minimap", "show-shortcuts", "doctor", "displays"][random.below(4)])
      case 46:
        run(["name work", "go work", "unname work", "save-view 1", "view 1"][random.below(5)])
      default:
        h.system.cursor = CGPoint(x: 100 + random.below(sideIsPlugged ? 2500 : 1300), y: 100 + random.below(600))
        note("pointer to \(Int(h.system.cursor.x))")
      }
      h.scheduler.advance(by: 2)
      guard check() else { return }
    }
    if !h.controller.isRunning { run("resume") }
    run("float-all")
    h.scheduler.advance(by: 2)
    leftOutByHand = leftOutByHand.filter { !h.system.isVisible($0) }
    for window in h.system.allWindows()
    where window.isPresent && isArborsToPlace(window.id) && h.controller.workspaces.values.contains(where: { $0.isFloating(window.id) }) {
      #expect(h.system.isVisible(window.id), "seed \(seed): after float-all \(window.id) is at \(window.frame)\n  \(log.joined(separator: " | "))")
    }
  }
}
