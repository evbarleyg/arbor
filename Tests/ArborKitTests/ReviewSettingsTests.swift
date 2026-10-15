import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// An independent review of F12: every key of the schema, whatever a person, a sync tool or an older Arbor
/// has written for it, while Arbor holds windows on two displays.
@Suite @MainActor struct ReviewSettingsTests {
  nonisolated static let keys = SettingsSchema.entries.map(\.key)

  static let twoDisplays = [
    FakeWindowSystem.standardDisplay,
    DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false, isBuiltIn: false),
  ]

  /// JSON a hand, a merge or another program can leave as the value of any key.
  nonisolated static let hostileJSON: [String] = [
    "0", "-1", "0.5", "1e-300", "1e300", "-1e300", "1e999", "true", "null", "\"\"", "\"NaN\"", "\"12\"", "\"none\"",
    "\"" + String(repeating: "x", count: 20_000) + "\"", "[]", "{}", "[1]", "[null]", "[{}]", "{\"a\":1}", "{\"ctrl+opt+h\":\"quit\"}",
    "[\"com.example.safari\"]", "[\"*\"]", "[{\"app\":\"*\",\"action\":\"dock auto\"}]", "[{\"match\":\"main\",\"gap\":1e300}]",
    "[{\"match\":\"main\",\"gap\":100,\"minimumUsableWidth\":1000}]",
  ]

  /// A few windows on two displays, docked, zoomed, dragged, floated; then Arbor quits. Returns the windows.
  @discardableResult
  static func journey(_ h: Harness, _ label: String) throws -> [WindowID] {
    let smallest = CGSize(width: 120, height: 80)
    let a = h.system.open(app: "Safari", pid: 1001, minimumSize: smallest)
    let b = h.system.open(app: "Notes", pid: 1002, minimumSize: smallest)
    let c = h.system.open(app: "Mail", pid: 1003, minimumSize: smallest)
    let d = h.system.open(
      app: "Xcode", pid: 1004, frame: CGRect(x: 1700, y: 200, width: 800, height: 600), minimumSize: smallest)
    if !h.controller.isRunning { h.start() }
    let e = h.system.open(app: "Terminal", pid: 1005, minimumSize: smallest)
    for command in [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(a.rawValue) bottom",
      "dock \(d.rawValue) left", "ascii", "state", "status", "settings", "settings --json", "displays", "rules", "bindings",
      "zoom \(a.rawValue)", "back", "in", "out", "resize \(a.rawValue) right 50", "minimap", "show-all", "desktop",
      "frame-rect 0 0 700 800", "pause", "resume", "hold still", "hold still off", "arrange", "relayout", "float \(b.rawValue)",
      "summon \(e.rawValue)", "pin \(c.rawValue)", "reload-settings",
    ] {
      h.run(command)
      h.scheduler.advance(by: 0.05)
    }
    h.system.drag(a, through: [CGPoint(x: 400, y: 300), CGPoint(x: 1000, y: 400), CGPoint(x: 5, y: 400)])
    h.system.drag(b, through: [CGPoint(x: 400, y: 300), CGPoint(x: 2000, y: 400)])
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    h.keyUp("ctrl+opt+space")
    h.system.setMinimized(c, true)
    h.system.setMinimized(c, false)
    h.scheduler.advance(by: 700)
    h.scheduler.runPending()
    _ = try JSONEncoder().encode(h.controller.snapshot())
    _ = try JSONEncoder().encode(h.controller.settings)
    h.controller.shutdown()
    for window in [a, b, c, d, e] {
      let frame = try #require(h.frame(window))
      #expect(h.system.isVisible(window), "\(label): \(window) is left at \(frame)")
      #expect(frame.width.isFinite && frame.height.isFinite && frame.width > 0 && frame.height > 0, "\(label): \(frame)")
    }
    return [a, b, c, d, e]
  }

  /// What is in use is something `set` would accept, for every key.
  static func expectEveryValueIsValid(_ settings: Settings, _ label: String) {
    for entry in SettingsSchema.entries {
      if case .list = entry.kind { continue }
      #expect(throws: Never.self, "\(label): \(entry.key) is in use as \(entry.value(in: settings).summary.prefix(60))") {
        _ = try entry.validated(entry.value(in: settings))
      }
    }
  }

  // MARK: Every key, by hand

  @Test(arguments: keys) func anyJSONInAnyKeyCostsOnlyThatKey(key: String) throws {
    let entry = try SettingsSchema.entry(named: key)
    var values = Self.hostileJSON
    if case .number(let range, let step, _) = entry.kind {
      values += [
        range.lowerBound, range.upperBound, range.lowerBound - step, range.upperBound + step,
        range.lowerBound.nextDown, range.upperBound.nextUp,
      ].map { "\($0)" }
    }
    try Log.silenced {
      for value in values {
        let label = "\"\(key)\": \(value.prefix(50))"
        // Other people's keys around it, before and after.
        let witness = key == "gap" ? "screenEdgeBand" : "gap"
        let text = "{ \"\(witness)\": 7, \"\(key)\": \(value), \"focusRingWidth\": \(key == "focusRingWidth" ? value : "5") }"
        let settings: Settings
        do {
          settings = try Settings.read(text)
        } catch {
          Issue.record("\(label) makes the whole file unreadable: \(error)")
          continue
        }
        #expect(try SettingsSchema.entry(named: witness).value(in: settings) == .number(7), "\(label)")
        if key != "focusRingWidth" { #expect(settings.focusRingWidth == 5, "\(label)") }
        Self.expectEveryValueIsValid(settings, label)
        // What fell back to the default makes the journey every other test makes.
        if !entry.isDefault(in: settings) {
          try Self.journey(Harness(displays: Self.twoDisplays, settings: settings), label)
        }
      }
    }
  }

  // MARK: Every key, by command

  nonisolated static let hostileWords: [String] = [
    "0", "-1", "0.5", "1e300", "-1e300", "1e999", "nan", "-inf", "infinity", "0x10", "١٢", "1,5", "true", "toggle", "null", "[]", "{}",
    "\"\"", "none", "#GGGGGG", "*", "add", "add x", "remove x", "add com.example.safari", String(repeating: "x", count: 20_000), "a b c",
    "\u{0}", "%@",
  ]

  @Test(arguments: keys) func setTakesAValueOrRefusesItByName(key: String) throws {
    let entry = try SettingsSchema.entry(named: key)
    var words = Self.hostileWords + [entry.defaultValue.text]
    if case .number(let range, let step, _) = entry.kind {
      words += [
        range.lowerBound, range.upperBound, range.lowerBound - step, range.upperBound + step,
        range.lowerBound.nextDown, range.upperBound.nextUp,
      ].map { "\($0)" }
    }
    if case .choice(let choices) = entry.kind { words += choices.map(\.value) + choices.map { $0.value.uppercased() } }
    try Log.silenced {
      var spare: Harness?
      for word in words {
        let label = "set \(key) \(word.prefix(50))"
        let h = spare ?? Harness(displays: Self.twoDisplays)
        if spare == nil { h.start() }
        spare = h
        let before = h.controller.settings
        let reply = h.run("set \(key) \(word)")
        #expect(reply.message.count < 600, "\(label): a reply of \(reply.message.count) characters")
        if reply.ok {
          var others = h.controller.settings
          entry.reset(in: &others)
          var rest = before
          entry.reset(in: &rest)
          #expect(others == rest, "\(label) changed another setting")
        } else {
          #expect(h.controller.settings == before, "\(label) was refused and changed something")
          // A word that is no app is named itself: `x` is not a bundle id.
          #expect(
            reply.message.contains(key) || (entry.isAppList && reply.message.contains("is not a bundle id")),
            "\(label) is refused without naming the key: \(reply.message)")
        }
        Self.expectEveryValueIsValid(h.controller.settings, label)
        if reply.ok, h.controller.settings != before {
          try Self.journey(h, label)
          spare = nil
        }
      }
    }
  }

  // MARK: The nets

  /// A stored property of `Settings` that is in no `CodingKeys` is never saved, never read and in no list, and no other
  /// test would notice: they all start from the keys that are encoded.
  @Test func everyStoredPropertyIsSavedReadAndDescribed() throws {
    let reports: Set = ["unreadableBindings", "skippedRules", "valueProblems", "skippedDisplays", "skippedDisplayNumbers"]
    let stored = Set(Mirror(reflecting: Settings()).children.compactMap(\.label)).subtracting(reports)
    let described = Set(SettingsSchema.entries.map(\.key))
    #expect(stored.subtracting(described).isEmpty, "not in the schema")
    #expect(described.subtracting(stored).isEmpty)
    let encoded = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any])
    #expect(Set(encoded.keys) == stored, "not in CodingKeys: \(stored.subtracting(encoded.keys).sorted())")
    let document = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("docs/SETTINGS.md"), encoding: .utf8)
    for key in stored { #expect(document.contains("| `\(key)` |"), "\(key) is not in docs/SETTINGS.md") }
  }

  /// A key with no line in `init(from:)` would be written and never read.
  @Test func everyKeyComesBackFromTheFile() throws {
    for entry in SettingsSchema.entries {
      var settings = Settings()
      switch entry.kind {
      case .toggle:
        guard case .bool(let flag) = entry.defaultValue else { continue }
        try entry.set(.bool(!flag), in: &settings)
      case .number(let range, _, _):
        let other = entry.defaultValue == .number(range.upperBound) ? range.lowerBound : range.upperBound
        try entry.set(.number(other), in: &settings)
      case .choice(let choices):
        try entry.set(.text(try #require(choices.first { .text($0.value) != entry.defaultValue }).value), in: &settings)
      case .text(let example):
        try entry.set(.text(example), in: &settings)
      case .list:
        continue
      }
      #expect(!entry.isDefault(in: settings), "\(entry.key)")
      #expect(try Settings.read(try settings.fileText) == settings, "\(entry.key) does not come back from the file")
      // Alone in a file, as somebody who writes only what they change has it.
      let alone = try Settings.read("{\"\(entry.key)\": \(entry.kind == .toggle || entry.value(in: settings).text.first!.isNumber ? entry.value(in: settings).text : "\"\(entry.value(in: settings).text)\"")}")
      #expect(alone == settings, "\(entry.key)")
    }
  }

  // MARK: Everything at once

  static func everySwitch(_ on: Bool) throws -> Settings {
    var settings = Settings()
    for entry in SettingsSchema.entries where entry.kind == .toggle { try entry.set(.bool(on), in: &settings) }
    return settings
  }

  @Test(arguments: [true, false]) func everySwitchTogether(on: Bool) throws {
    try Log.silenced {
      var settings = try Self.everySwitch(on)
      try Self.journey(Harness(displays: Self.twoDisplays, settings: settings), "every switch \(on)")
      // And every number at either end.
      for upper in [true, false] {
        for entry in SettingsSchema.entries {
          if case .number(let range, _, _) = entry.kind {
            try entry.set(.number(upper ? range.upperBound : range.lowerBound), in: &settings)
          }
        }
        settings.newWindows = on ? "dock" : "float"
        try Self.journey(
          Harness(displays: Self.twoDisplays, settings: settings), "every switch \(on), every number at its \(upper ? "upper" : "lower") end")
      }
    }
  }

  @Test(arguments: [true, false], [UInt64(1)]) func aRandomWalkWithEverySwitch(on: Bool, seed: UInt64) throws {
    let failure: ChaosFailure? = Log.silenced {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed &* 7919)
      var actions: [ChaosAction] = [.launch]
      for entry in SettingsSchema.entries where entry.kind == .toggle { actions.append(.command("set \(entry.key) \(on)")) }
      if on { actions += [.command("set newWindows dock"), .command("set minimapDuration 1"), .command("set messages all")] }
      for action in actions {
        let broken = runner.step(action).filter { !ChaosRunner.knownRules.contains($0.rule) }
        if !broken.isEmpty { return ChaosFailure(seed: seed, violations: broken, script: runner.script) }
      }
      for _ in 0..<250 {
        let broken = runner.step(generator.next(runner)).filter { !ChaosRunner.knownRules.contains($0.rule) }
        if !broken.isEmpty { return ChaosFailure(seed: seed, violations: broken, script: runner.script) }
      }
      return nil
    }
    #expect(failure == nil, "\(failure.map { "\($0)" } ?? "")")
  }
}

/// Settings that change while something is going on.
@Suite @MainActor struct ReviewSettingsLiveTests {
  /// Three windows: two docked left and right of the Desktop, one floating.
  func desk(_ settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: ReviewSettingsTests.twoDisplays, settings: settings)
    let a = h.system.open(app: "Safari", pid: 1001)
    let b = h.system.open(app: "Notes", pid: 1002)
    let c = h.system.open(app: "Mail", pid: 1003)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 2)
    return (h, a, b, c)
  }

  func expectAllInView(_ h: Harness, _ windows: [WindowID], _ label: String) {
    for window in windows { #expect(h.system.isVisible(window), "\(label): \(window) at \(String(describing: h.frame(window)))") }
  }

  // MARK: During a drag

  @Test func aSettingChangedDuringADragDoesNotTakeTheWindowOutOfTheHand() throws {
    let (h, a, b, c) = desk()
    h.system.grab(a)
    h.system.carry(to: CGPoint(x: 700, y: 400))
    let held = try #require(h.frame(a))
    #expect(h.run("set gap 40").ok)
    h.scheduler.advance(by: 0.1)
    #expect(h.frame(a) == held, "the window in the hand was moved to \(String(describing: h.frame(a)))")
    h.system.carry(to: CGPoint(x: 720, y: 420))
    h.system.letGo()
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c], "after the drop")
    expectWindowsMatchLayout(h)
  }

  @Test func theDraggedWindowsAppGoesOnTheDontArrangeList() throws {
    let (h, a, b, c) = desk()
    h.system.grab(a)
    h.system.carry(to: CGPoint(x: 700, y: 400))
    #expect(h.run("set excludedBundleIDs add com.example.safari").ok)
    h.system.carry(to: h.frame(b)!.center)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.preview == nil, "a window Arbor does not arrange is offered a place")
    h.system.letGo()
    h.scheduler.advance(by: 2)
    #expect(h.overlays.preview == nil, "a drop preview is left on screen")
    #expect(!h.workspace.contains(a))
    expectAllInView(h, [a, b, c], "after the drop")
  }

  @Test func previewsAreSwitchedOffDuringADrag() throws {
    let (h, a, _, c) = desk()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.grab(c)
    h.system.carry(to: CGPoint(x: 5, y: 400))
    h.scheduler.advance(by: 1)
    #expect(h.overlays.preview != nil)
    #expect(h.run("set previewDrags false").ok)
    h.scheduler.advance(by: 0.5)
    #expect(h.overlays.preview == nil, "the preview stays after it was switched off")
    h.system.letGo()
    h.scheduler.advance(by: 2)
    #expect(h.overlays.preview == nil)
    _ = a
  }

  @Test func reflowIsSwitchedOffDuringADrag() throws {
    var settings = Settings()
    settings.reflowWhileDragging = true
    let (h, a, b, c) = desk(settings)
    h.system.grab(a)
    h.system.carry(to: CGPoint(x: 700, y: 400))
    h.scheduler.advance(by: 1)
    #expect(h.run("set reflowWhileDragging false").ok)
    h.scheduler.advance(by: 1)
    h.system.carry(to: CGPoint(x: 710, y: 410))
    h.system.letGo()
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c], "after the drop")
    expectWindowsMatchLayout(h)
  }

  // MARK: Panels

  @Test func switchingThingsOffTakesThemOffTheScreen() throws {
    var settings = Settings.withRing.withBackdrop
    settings.minimapDuration = 10
    settings.messages = "all"
    let (h, a, _, _) = desk(settings)
    h.system.userFocus(a)
    h.press("zoom \(a.rawValue)")
    h.scheduler.advance(by: 0.6)
    #expect(h.overlays.scenes[h.display]?.focusRing != nil)
    #expect(h.overlays.minimaps[h.display] != nil)
    #expect(h.run("set focusRing false").ok)
    #expect(h.overlays.scenes[h.display]?.focusRing == nil, "the ring stays")
    #expect(h.run("set minimapDuration 0").ok)
    h.press("back")
    #expect(h.overlays.headsUp[h.display] != nil)
    #expect(h.run("set messages off").ok)
    // What is on screen at that moment stays for the time it was given, and nothing follows it.
    h.scheduler.advance(by: 10)
    #expect(h.overlays.minimaps[h.display] == nil)
    #expect(h.overlays.headsUp[h.display] == nil)
    h.press("zoom \(a.rawValue)")
    h.press("back")
    h.scheduler.advance(by: 0.6)
    #expect(h.overlays.minimaps[h.display] == nil, "the minimap shows by itself after that was switched off")
    #expect(h.overlays.headsUp[h.display] == nil, "a message shows after messages were switched off")
    #expect((h.overlays.scenes[h.display]?.backdrop?.dim ?? 0) > 0)
    #expect(h.run("set dimBehindArranged 0").ok)
    #expect((h.overlays.scenes[h.display]?.backdrop?.dim ?? 0) == 0)
    #expect(h.overlays.scenes[h.display]?.seams.isEmpty == false)
    #expect(h.run("set gapHandles off").ok)
    #expect(h.overlays.scenes[h.display]?.seams.isEmpty == true, "gaps can still be dragged")
  }

  // MARK: A peek

  @Test(arguments: ["set peek false", "set hotkeysEnabled false", "set gap 30", "unbind ctrl+opt+space", "reset all"])
  func aSettingChangedDuringAPeekEndsItCleanly(command: String) throws {
    let (h, a, b, c) = desk()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 1)
    let camera = h.workspace.camera
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.run(command).ok)
    h.scheduler.advance(by: 1)
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 2)
    #expect(h.overlays.scenes[h.display]?.peekOutline == nil, "\(command): the outline of the peek stays")
    #expect(h.controller.temporaryShortcuts.isEmpty, "\(command): \(h.controller.temporaryShortcuts)")
    _ = camera
    h.run("show-all")
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c], command)
    expectWindowsMatchLayout(h)
  }

  // MARK: A pause

  @Test func settingsChangedDuringAPauseMoveNothingAndCountAfterwards() throws {
    let (h, a, b, c) = desk(.withRing.withBackdrop)
    #expect(h.overlays.scenes.values.contains { $0.focusRing != nil && $0.backdrop != nil }, "there is something for the pause to take away")
    h.run("pause")
    h.scheduler.advance(by: 1)
    let frames = [a, b, c].map { h.frame($0) }
    h.system.clearFrameLog()
    #expect(h.run("set gap 40").ok)
    #expect(h.run("set excludedBundleIDs add com.example.notes").ok)
    #expect(h.run("set minimapDuration 5").ok)
    #expect(h.run("set soleFloatTakesDesktop true").ok)
    h.scheduler.advance(by: 5)
    #expect(h.system.frameLog.isEmpty, "a window was moved during a pause")
    #expect([a, b, c].map { h.frame($0) } == frames)
    #expect(h.overlays.scenes.values.allSatisfy { $0.tiles.isEmpty && $0.seams.isEmpty && $0.focusRing == nil && $0.backdrop == nil })
    #expect(h.controller.isPaused)
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect(h.controller.settings.gap == 40)
    #expect(!h.workspace.contains(b))
    expectAllInView(h, [a, b, c], "after the pause")
    expectWindowsMatchLayout(h)
  }

  @Test func theAppInFrontGoesOnAndOffPauseFor() throws {
    let (h, a, b, c) = desk()
    h.system.activateApp(of: a)
    #expect(h.run("set pauseForApps add com.example.safari").ok)
    h.scheduler.advance(by: 1)
    #expect(h.controller.isPaused)
    #expect(h.run("set pauseForApps remove com.example.safari").ok)
    h.scheduler.advance(by: 1)
    #expect(!h.controller.isPaused, "Arbor stays paused for an app that is no longer on the list")
    #expect(h.controller.isRunning)
    expectAllInView(h, [a, b, c], "after")
  }

  // MARK: Out of view

  /// Everything that can be out of view, when its app goes on the Don't arrange list.
  @Test func windowsOutOfViewComeBackWhenTheirAppIsNoLongerArranged() throws {
    let (h, a, b, c) = desk()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    #expect(h.run("set excludedBundleIDs add com.example.notes").ok)
    #expect(h.run("set excludedBundleIDs add com.example.mail").ok)
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c], "excluded")
    // And the one in view.
    #expect(h.run("set excludedBundleIDs add com.example.safari").ok)
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c], "excluded")
    #expect(h.workspace.allWindows.isEmpty)
    h.controller.shutdown()
    expectAllInView(h, [a, b, c], "quit")
  }

  @Test func theSameByHandInTheFileWhileMotionRuns() throws {
    let (h, a, b, c) = desk(.withMotion)
    var file = Settings.withMotion
    h.controller.loadSettings = { file }
    h.overlays.clearTransitions()
    h.run("zoom \(a.rawValue)")
    #expect(!h.overlays.transitions.isEmpty, "there is a motion to be in the middle of")
    h.scheduler.advance(by: 0.1)  // the motion takes 0.46 s
    file.excludedBundleIDs = ["com.example.notes", "com.example.mail", "com.example.safari"]
    file.animationDuration = 0
    h.controller.settingsFileMayHaveChanged()
    h.scheduler.advance(by: 0.31)
    h.scheduler.advance(by: 3)
    expectAllInView(h, [a, b, c], "excluded in the middle of a motion")
    #expect(h.workspace.allWindows.isEmpty)
  }

  /// F18 takes `floatingWindowsMakeWay` as well since Q20. Whichever of the two goes off, the window has its own frame back.
  @Test(arguments: ["soleFloatTakesDesktop", "floatingWindowsMakeWay"])
  func aLoneWindowGetsItsOwnFrameBackWhenTheSettingGoesOff(key: String) throws {
    var settings = Settings.makingWay
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 1001)
    let own = CGRect(x: 900, y: 300, width: 400, height: 300)
    let c = h.system.open(app: "Mail", pid: 1003, frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 2)
    #expect(h.frame(c) != own)
    #expect(h.run("set \(key) false").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(c) == own, "it stays at \(String(describing: h.frame(c)))")
  }

  @Test func guestsStayReachableWhenTheSettingChanges() throws {
    let (h, a, b, c) = desk()
    h.run("zoom \(a.rawValue)")
    h.scheduler.advance(by: 2)
    let guest = h.system.open(app: "Preview", pid: 1009)
    h.scheduler.advance(by: 2)
    #expect(h.run("set newWindowsWhileFramed float").ok)
    h.scheduler.advance(by: 1)
    h.run("desktop")
    h.scheduler.advance(by: 2)
    h.run("show-all")
    h.scheduler.advance(by: 2)
    expectAllInView(h, [a, b, c, guest], "show-all")
    h.controller.shutdown()
    expectAllInView(h, [a, b, c, guest], "quit")
  }

  @Test func tabGroupsSurviveTabsBeingSwitchedOff() throws {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b, c) = desk(settings)
    h.system.drag(c, through: [CGPoint(x: 700, y: 300), h.frame(a)!.center])
    h.scheduler.advance(by: 2)
    #expect(h.run("set tabsEnabled false").ok)
    h.scheduler.advance(by: 2)
    for command in ["show-all", "zoom \(c.rawValue)", "zoom \(a.rawValue)", "show-all", "float-all"] {
      h.run(command)
      h.scheduler.advance(by: 2)
    }
    expectAllInView(h, [a, b, c], "float-all")
  }

  // MARK: Rules

  @Test func rulesChangedWhileATitleIsAwaited() throws {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.chrome", title: "Inbox", action: .dock(.left))]
    settings.ruleTitleWait = 5
    let h = Harness(settings: settings)
    h.start()
    let w = h.system.open(app: "Chrome", title: "Loading", pid: 1010)
    h.scheduler.advance(by: 0.5)
    #expect(h.run("rule remove 1").ok)
    h.system.setTitle(w, "Inbox (3)")
    h.scheduler.advance(by: 6)
    #expect(h.workspace.tree.allWindows.isEmpty, "a rule that was removed docked a window")
    #expect(h.system.isVisible(w))
  }

  // MARK: The file

  /// A sync tool touches the file a hundred times a second for a while.
  @Test func aStormOfChangesIsReadOnce() throws {
    let (h, _, _, _) = desk()
    var reads = 0
    var file = Settings()
    h.controller.loadSettings = {
      reads += 1
      return file
    }
    file.gap = 30
    for _ in 0..<500 {
      h.controller.settingsFileMayHaveChanged()
      h.scheduler.advance(by: 0.01)
    }
    #expect(reads <= 1)
    h.scheduler.advance(by: 0.5)
    #expect(reads == 1)
    #expect(h.controller.settings.gap == 30)
  }
}
