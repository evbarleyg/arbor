import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Random launches: a saved arrangement, then windows that come back late, under other numbers and titles, on
/// other Spaces, while displays come and go and the user carries on. Whatever the order, no trap, every
/// tree stays valid, no window is in two places, and quitting leaves every window in view.
@Suite @MainActor struct PendingSlotChaosTests {
  struct Random {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
  }

  static let second = DisplaySnapshot(
    id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
  static let apps = ["Safari", "Mail", "Terminal"]
  static let titles = ["one", "two", ""]

  func check(_ h: Harness, _ context: String) {
    var seen = Set<WindowID>()
    for (id, workspace) in h.controller.workspaces {
      #expect(workspace.tree.invariantViolations().isEmpty, "\(context): \(id)")
      #expect(workspace.tree.contains(workspace.camera), "\(context): \(id)")
      for window in workspace.allWindows { #expect(seen.insert(window).inserted, "\(context): \(window) is in two places") }
    }
    for (id, entry) in h.controller.dormant {
      #expect(entry.workspace.tree.invariantViolations().isEmpty, "\(context): remembered \(id)")
    }
    // Every display has been laid out since it last changed, and the windows are where that puts them.
    if h.controller.isRunning { #expect(h.layoutProblems() == [], "\(context)") }
  }

  @Test func anyOrderOfEventsAfterALaunchIsSurvivable() {
    for seed in 1...250 {
      var random = Random(state: UInt64(seed))
      let both = [FakeWindowSystem.standardDisplay, Self.second]

      // A first life: some windows, docked here and there, on one or two displays.
      let first = Harness(displays: random.next(2) == 0 ? both : [both[0]])
      for _ in 0..<(2 + random.next(5)) {
        first.system.open(
          app: Self.apps[random.next(3)], title: Self.titles[random.next(3)],
          frame: CGRect(x: 100 + random.next(2500), y: 60 + random.next(500), width: 500, height: 300))
      }
      first.start()
      for window in first.system.allWindows() where random.next(4) > 0 {
        first.system.cursor = window.frame.center
        first.run("dock \(window.id.rawValue) \(["left", "right", "up", "down"][random.next(4)])")
      }
      if random.next(2) == 0, let window = first.system.allWindows().first { first.run("zoom \(window.id.rawValue)") }
      first.controller.saveNow()

      // A second life. After a reboot nothing is left; after a restart of Arbor some windows are.
      let h = Harness(displays: random.next(2) == 0 ? both : [both[0]], saved: first.store.saved)
      let rebooted = random.next(2) == 0
      for window in first.system.allWindows() {
        let id = h.system.open(
          app: rebooted ? Self.apps[random.next(3)] : window.appName, title: rebooted ? Self.titles[random.next(3)] : window.title,
          frame: window.frame)
        switch random.next(4) {
        case 0: h.system.setListed(id, false)
        case 1:
          h.system.setListed(id, false)
          h.system.close(id)
        default: break
        }
      }
      h.start()
      check(h, "seed \(seed) at launch")

      for step in 0..<40 {
        let known = h.system.allWindows().map(\.id)
        let pick = known.isEmpty ? nil : known[random.next(known.count)]
        switch random.next(14) {
        case 0, 1:
          // Apps open windows on a display that is there.
          let width = h.system.displayList.count == 2 ? 2500 : 800
          h.system.open(
            app: Self.apps[random.next(3)], title: Self.titles[random.next(3)],
            frame: CGRect(x: 100 + random.next(width), y: 60 + random.next(500), width: 500, height: 300))
        case 2: if let pick { h.system.setTitle(pick, Self.titles[random.next(3)]) }
        case 3: if let pick { h.system.close(pick) }
        case 4: if let hidden = h.system.unlisted.keys.sorted().first { h.system.setListed(hidden, true) }
        case 5: if let hidden = h.system.unlisted.keys.sorted().last { h.system.close(hidden) }
        case 6: h.system.setDisplays(h.system.displayList.count == 2 ? [both[0]] : both)
        case 7: h.scheduler.advance(by: [0.6, 30, Controller.pendingSlotLifetime][random.next(3)])
        case 8: h.run(["arrange", "float-all", "arrange all", "show-all", "desktop", "back"][random.next(6)])
        case 9:
          h.run("pause")
          if random.next(2) == 0, let pick { h.system.close(pick) }
          h.run("resume")
        case 10: if let pick { h.run("dock \(pick.rawValue) \(["left", "right", "up", "down"][random.next(4)])") }
        case 11: if let pick { h.run(["zoom", "float", "toggle-float"][random.next(3)] + " \(pick.rawValue)") }
        case 12: if let pick { h.system.setMinimized(pick, random.next(2) == 0) }
        default: h.run("exclude com.example.\(Self.apps[random.next(3)].lowercased())")
        }
        check(h, "seed \(seed) step \(step)")
      }

      h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
      // Nothing moves by a timer: a slot whose going would move a window goes with the next layout somebody causes.
      h.run("relayout")
      let existing = h.system.existingWindowIDs()
      for workspace in h.controller.workspaces.values {
        for window in workspace.tree.allWindows { #expect(existing.contains(window), "seed \(seed): \(window) waits for ever") }
      }
      let managed = h.system.allWindows().filter(h.controller.filter.manages)
      h.controller.shutdown()
      // (macOS itself moves the windows Arbor does not arrange off a display that goes away; the fake does not.)
      for window in managed {
        #expect(h.system.isVisible(window.id), "seed \(seed): \(window.id) at \(h.frame(window.id)!)")
      }
    }
  }
}
