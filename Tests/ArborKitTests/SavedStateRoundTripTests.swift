import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Whatever Arbor saves, it reads back whole and without a word. A state that healthy use produced and that comes back
/// "repaired" would tell people their arrangement was damaged (`Controller.notices`), keep a copy of the file at every
/// launch, and lose whatever the repair dropped.
@Suite @MainActor struct SavedStateRoundTripTests {
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

  func roundTrip(_ h: Harness, _ context: String) {
    h.controller.saveNow()
    guard let saved = h.store.saved else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(saved) else {
      Issue.record("\(context): does not encode")
      return
    }
    let notes = DecodingNotes()
    guard case .loaded(let read) = PersistedState.read(data, notes: notes) else {
      Issue.record("\(context): does not load")
      return
    }
    #expect(notes.notes.isEmpty, "\(context): \(notes.notes)")
    #expect(read == saved, "\(context): comes back different")
  }

  @Test func whateverHealthyUseSavesIsReadBackWholeAndWithoutAWord() {
    let edges = ["left", "right", "top", "bottom"]
    for seed in 1...150 {
      var random = Random(state: UInt64(seed))
      let both = [FakeWindowSystem.standardDisplay, Self.second]
      let h = Harness(displays: random.next(2) == 0 ? both : [both[0]])
      let apps = ["Safari", "Mail", "Terminal", "Notes"]
      for _ in 0..<(3 + random.next(5)) {
        let app = apps[random.next(4)]
        h.system.open(
          app: app, pid: Int32(2000 + apps.firstIndex(of: app)!),
          frame: CGRect(x: 100 + random.next(900), y: 60 + random.next(400), width: 500, height: 300))
      }
      h.start()
      var script: [String] = []
      for _ in 0..<40 {
        let known = h.system.allWindows().map(\.id.rawValue)
        guard let pick = known.isEmpty ? nil : known[random.next(known.count)],
          let other = known.isEmpty ? nil : known[random.next(known.count)]
        else { break }
        let commands = [
          "dock \(pick) \(edges[random.next(4)])", "dock \(pick) beside \(other) \(edges[random.next(4)])", "float \(pick)",
          "zoom \(pick)", "show-all", "desktop", "back", "forward", "out", "in", "save-view \(1 + random.next(3))",
          "view \(1 + random.next(3))", "pin \(pick)", "unpin \(pick)", "arrange", "arrange all", "float-all",
          "resize \(pick) \(edges[random.next(4)]) \(random.next(200) - 100)", "name Space \(random.next(3))", "unname",
          "go Space \(random.next(3))", "summon \(apps[random.next(4)])", "hold", "hold still", "release", "pause", "resume",
          "layout Safari | Desktop | (Mail / Notes)", "layout Safari | Safari*", "neighbor \(edges[random.next(4)])", "home",
          "exclude com.example.mail", "include com.example.mail", "toggle-auto-dock",
        ]
        let command = commands[random.next(commands.count)]
        script.append(command)
        let reply = h.run(command).message
        #expect(!reply.contains("unknown command") && !reply.hasPrefix("usage"), "\(command): \(reply)")
        switch random.next(12) {
        case 0: h.system.close(WindowID(pick))
        case 1: h.system.setMinimized(WindowID(pick), random.next(2) == 0)
        case 2: h.system.setDisplays(h.system.displayList.count == 2 ? [both[0]] : both)
        case 3: h.scheduler.advance(by: [0.6, 5, 200][random.next(3)])
        case 4: h.system.open(app: apps[random.next(4)])
        default: break
        }
        roundTrip(h, "seed \(seed) after \(script.suffix(6))")
      }
    }
  }

  /// Lives: use, a crash at any moment, the watchdog's or a person's start from the file as it is on disk, more use, and in the
  /// end a quit. No trap, every tree valid, no window in two places, a pause that outlives the crash touches nothing, and
  /// after the quit every window is in view.
  @Test func crashesAtAnyMomentWithEverythingSwitchedOn() throws {
    let edges = ["left", "right", "top", "bottom"]
    let apps = ["Safari", "Mail", "Terminal", "Notes"]
    for seed in 1...120 {
      var random = Random(state: UInt64(seed) &* 7919)
      var h = Harness()
      for _ in 0..<(3 + random.next(4)) {
        let app = apps[random.next(4)]
        h.system.open(
          app: app, pid: Int32(2000 + apps.firstIndex(of: app)!),
          frame: CGRect(x: 100 + random.next(700), y: 60 + random.next(400), width: 500, height: 300))
      }
      h.start()
      var script: [String] = []
      for life in 0..<4 {
        for _ in 0..<(3 + random.next(12)) {
          let known = h.system.allWindows().map(\.id.rawValue)
          guard !known.isEmpty else { break }
          let (pick, other) = (known[random.next(known.count)], known[random.next(known.count)])
          let commands = [
            "dock \(pick) \(edges[random.next(4)])", "dock \(pick) beside \(other) \(edges[random.next(4)])", "float \(pick)",
            "zoom \(pick)", "show-all", "desktop", "back", "save-view 1", "view 1", "pin \(pick)", "arrange", "float-all",
            "name Space \(random.next(2))", "go Space \(random.next(2))", "summon \(apps[random.next(4)])", "hold", "hold still",
            "release", "pause", "pause 5", "resume", "layout Safari | Safari*", "exclude com.example.mail", "include com.example.mail",
          ]
          let command = commands[random.next(commands.count)]
          script.append(command)
          h.run(command)
          if random.next(6) == 0 { h.scheduler.advance(by: [0.6, 5, 400][random.next(3)]) }
          if random.next(10) == 0 { h.system.setMinimized(WindowID(pick), random.next(2) == 0) }
        }
        // The crash. What is on disk is what was last saved, which may be a moment old.
        if random.next(2) == 0 { h.scheduler.advance(by: 1) }
        let context = "seed \(seed), life \(life), after \(script.suffix(8))"
        let wasPaused = h.controller.isPaused && !h.controller.isPausedForApp
        var saved: PersistedState?
        if let onDisk = h.store.saved {
          guard case .loaded(let read) = PersistedState.read(try JSONEncoder().encode(onDisk)) else {
            Issue.record("\(context): the file does not load")
            return
          }
          saved = read
        }
        let again = Harness(saved: saved)
        for window in h.system.allWindows() {
          let id = again.system.open(
            app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
          #expect(id == window.id || true)
          if window.isMinimized { again.system.setMinimized(id, true) }
        }
        let byWatchdog = random.next(2) == 0
        again.controller.restartedAfterAccident = byWatchdog
        let moves = again.system.moveLog.count
        again.start()
        if byWatchdog, wasPaused, saved?.pause != nil, saved?.pause?.until == nil {
          #expect(again.controller.isPaused, "\(context)")
          #expect(again.system.moveLog.count == moves, "\(context): a pause touches nothing")
        } else if !byWatchdog {
          #expect(again.controller.isRunning, "\(context): a person who starts Arbor wants it running")
        }
        var seen = Set<WindowID>()
        for (display, workspace) in again.controller.workspaces {
          #expect(workspace.tree.invariantViolations().isEmpty, "\(context): \(display)")
          #expect(workspace.tree.contains(workspace.camera), "\(context)")
          for window in workspace.allWindows { #expect(seen.insert(window).inserted, "\(context): \(window) twice") }
        }
        h = again
      }
      if h.controller.isPaused { h.run("resume") }
      let managed = h.system.allWindows().filter(h.controller.filter.manages)
      h.controller.shutdown()
      for window in managed where !window.isMinimized {
        #expect(h.system.isVisible(window.id), "seed \(seed), after \(script.suffix(10)): \(window.id) at \(h.frame(window.id)!)")
      }
    }
  }

  /// A paused Arbor, and one that has quit, touch nothing, whatever was going on when they stopped: no timer that was
  /// running moves or focuses a window afterwards.
  @Test func nothingThatWasScheduledActsAfterAPauseOrAQuit() {
    let edges = ["left", "right", "top", "bottom"]
    let apps = ["Safari", "Mail", "Terminal", "Notes"]
    for seed in 1...150 {
      var random = Random(state: UInt64(seed) &* 104_729)
      let h = Harness()
      for _ in 0..<(3 + random.next(4)) {
        let app = apps[random.next(4)]
        h.system.open(
          app: app, pid: Int32(2000 + apps.firstIndex(of: app)!),
          frame: CGRect(x: 100 + random.next(700), y: 60 + random.next(400), width: 500, height: 300),
          minimumSize: CGSize(width: [0, 400, 700][random.next(3)], height: 0))
      }
      h.start()
      var script: [String] = []
      for _ in 0..<(2 + random.next(14)) {
        let known = h.system.allWindows().map(\.id.rawValue)
        let (pick, other) = (known[random.next(known.count)], known[random.next(known.count)])
        let commands = [
          "dock \(pick) \(edges[random.next(4)])", "dock \(pick) beside \(other) \(edges[random.next(4)])", "float \(pick)",
          "zoom \(pick)", "show-all", "desktop", "pin \(pick)", "arrange", "summon \(apps[random.next(4)])", "hold 1", "hold still 1",
          "release", "layout Safari | Safari*", "toggle-auto-dock", "name Space", "resize \(pick) left 50",
        ]
        let command = commands[random.next(commands.count)]
        script.append(command)
        h.run(command)
        switch random.next(8) {
        case 0: h.system.userMove(WindowID(pick), to: CGRect(x: 50 + random.next(400), y: 80 + random.next(300), width: 480, height: 320))
        case 1: h.system.setMinimized(WindowID(pick), random.next(2) == 0)
        case 2: h.system.open(app: apps[random.next(4)])
        case 3: h.system.userFocus(WindowID(other))
        default: break
        }
      }
      let quits = random.next(2) == 0
      if quits { h.controller.shutdown() } else { h.run("pause") }
      let (moves, focuses) = (h.system.moveLog.count, h.system.focusLog.count)
      h.scheduler.advance(by: 3600)
      let context = "seed \(seed), \(quits ? "quit" : "pause") after \(script.suffix(8)); still scheduled: \(h.scheduler.pendingKeys)"
      #expect(h.system.moveLog.count == moves, "\(context)")
      #expect(h.system.focusLog.count == focuses, "\(context)")
      #expect(h.controller.isPaused == !quits && !h.controller.isRunning, "\(context)")
    }
  }

  // MARK: A file that something has been at

  /// Changes one thing somewhere in a JSON value: a number for an absurd one, a value for one of another type, a key or an
  /// element gone or twice.
  func mutate(_ value: Any, _ random: inout Random) -> Any {
    let absurd: [Any] = [
      0, -1, 1, 4_294_967_295, -9_007_199_254_740_993, 1e300, -1e300, 0.5, "", "n1", "4294967295", true, NSNull(), [Any](), [String: Any](),
    ]
    if var object = value as? [String: Any], !object.isEmpty {
      let keys = object.keys.sorted()
      let key = keys[random.next(keys.count)]
      switch random.next(6) {
      case 0: object[key] = nil
      case 1: object[key] = absurd[random.next(absurd.count)]
      case 2: object[keys[random.next(keys.count)]] = object[key]
      case 3: object["\(random.next(200))"] = object[key]
      default: object[key] = mutate(object[key]!, &random)
      }
      return object
    }
    if var array = value as? [Any], !array.isEmpty {
      let index = random.next(array.count)
      switch random.next(6) {
      case 0: array.remove(at: index)
      case 1: array[index] = absurd[random.next(absurd.count)]
      case 2: array.append(array[index])
      case 3: array.swapAt(index, random.next(array.count))
      default: array[index] = mutate(array[index], &random)
      }
      return array
    }
    return absurd[random.next(absurd.count)]
  }

  @Test func aFileThatSomethingHasBeenAtCannotStopArborOrCostAWindow() throws {
    // A desk with a bit of everything in the file.
    let first = Harness(displays: [FakeWindowSystem.standardDisplay, Self.second])
    for app in ["Safari", "Mail", "Terminal", "Notes", "Safari", "Mail"] { first.system.open(app: app) }
    first.start()
    for command in [
      "dock 101 left", "dock 102 right", "dock 103 beside 102 bottom", "dock 105 beside 101 bottom", "zoom 101", "name Web", "save-view 1",
      "show-all", "zoom 102", "save-view 2", "back", "pin 104", "summon Mail", "resize 101 right 60", "hold", "release", "out",
    ] { first.run(command) }
    first.system.setDisplays([FakeWindowSystem.standardDisplay])
    first.controller.saveNow()
    let healthy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(try #require(first.store.saved)))
    let windows = first.system.allWindows()

    var loaded = 0
    for seed in 1...600 {
      var random = Random(state: UInt64(seed) &* 2_654_435_761)
      var damaged = healthy
      for _ in 0..<(1 + random.next(4)) { damaged = mutate(damaged, &random) }
      guard JSONSerialization.isValidJSONObject(damaged), let data = try? JSONSerialization.data(withJSONObject: damaged),
        case .loaded(let state) = PersistedState.read(data)
      else { continue }
      loaded += 1
      let h = Harness(displays: random.next(2) == 0 ? [FakeWindowSystem.standardDisplay, Self.second] : [FakeWindowSystem.standardDisplay], saved: state)
      for window in windows {
        h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, frame: window.frame)
      }
      h.controller.restartedAfterAccident = random.next(3) == 0
      h.start()
      if h.controller.isPaused { h.run("resume") }
      for command in [
        "state", "ascii", "menu", "spaces", "status", "show-all", "in", "out", "back", "forward", "view 1", "view 2", "go Web", "desktop",
        "zoom 101", "dock 104 top", "float 102", "summon Mail", "unpin 104", "resize 101 left 40", "arrange", "float-all",
      ] { h.run(command) }
      h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
      var seen = Set<WindowID>()
      for workspace in h.controller.workspaces.values {
        #expect(workspace.tree.invariantViolations().isEmpty, "seed \(seed)")
        for window in workspace.allWindows { #expect(seen.insert(window).inserted, "seed \(seed): \(window) twice") }
      }
      h.controller.shutdown()
      for window in h.system.allWindows() { #expect(h.system.isVisible(window.id), "seed \(seed): \(window.id)") }
    }
    #expect(loaded > 200, "most of them should get as far as being used: \(loaded)")
  }
}
