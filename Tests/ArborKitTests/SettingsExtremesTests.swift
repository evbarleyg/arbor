import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Every setting at the ends of what the schema allows, alone and all at once, however it got there: by `set`, by a
/// hand-edited file, by the settings window's model. Arbor then has an ordinary day. Nothing here knows a setting by name, so
/// a setting that lands tomorrow is tried tomorrow.
@Suite @MainActor struct SettingsExtremesTests {
  // MARK: An ordinary day

  /// Safari | Desktop | (Notes / Mail), Music floating.
  private func world(_ settings: Settings = Settings()) -> (h: Harness, windows: [WindowID]) {
    let h = Harness(settings: settings)
    let windows = ["Safari", "Notes", "Mail", "Music"].enumerated().map { index, app in
      h.system.open(app: app, frame: CGRect(x: 100 + 60 * index, y: 100 + 40 * index, width: 600, height: 400))
    }
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) right")
    h.run("dock \(windows[2].rawValue) beside \(windows[1].rawValue) bottom")
    h.system.userFocus(windows[0])
    return (h, windows)
  }

  /// What must hold at any moment, whatever the settings.
  private func problems(_ h: Harness, panelsToo: Bool = true) -> [String] {
    var problems = h.layoutProblems()
    func sound(_ frame: CGRect, _ what: String, inside bounds: CGRect?) {
      let numbers = [frame.minX, frame.minY, frame.width, frame.height]
      if !numbers.allSatisfy(\.isFinite) { return problems.append("\(what) is at \(frame)") }
      // Nothing is left of a space where the gaps alone are wider than the display (a gap of 100 on 800 points); less than
      // nothing is a mistake.
      if frame.width < 0 || frame.height < 0 { problems.append("\(what) is inside out: \(frame)") }
      if let bounds, !bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame) { problems.append("\(what) at \(frame) leaves \(bounds)") }
    }
    for display in h.system.displayList {
      guard let layout = h.controller.layouts[display.id] else { continue }
      for (window, frame) in layout.windowFrames { sound(frame, "the place of \(window)", inside: display.visibleFrame) }
      for tile in layout.tiles { sound(tile.frame, "the tile of \(tile.node)", inside: display.visibleFrame) }
      if let desktop = layout.desktopFrame { sound(desktop, "the Desktop", inside: display.visibleFrame) }
    }
    for window in h.system.allWindows() { sound(window.frame, "\(window.id)", inside: nil) }
    // Whatever is handed to the panels to draw, now and in time to come: no number in it is infinite or not a number, and
    // no rectangle inside out.
    func look(_ value: Any, _ path: String, _ depth: Int) {
      if let rect = value as? CGRect {
        if ![rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].allSatisfy(\.isFinite) || rect.size.width < 0
          || rect.size.height < 0
        {
          problems.append("\(path) is \(rect)")
        }
        return
      }
      if let number = value as? CGFloat, !number.isFinite { return problems.append("\(path) is \(number)") }
      if let number = value as? Double, !number.isFinite { return problems.append("\(path) is \(number)") }
      guard depth < 8 else { return }
      for (index, child) in Mirror(reflecting: value).children.enumerated() {
        look(child.value, "\(path).\(child.label ?? String(index))", depth + 1)
      }
    }
    guard panelsToo else { return problems }
    for (display, scene) in h.overlays.scenes { look(scene, "the scene of \(display)", 0) }
    if let preview = h.overlays.preview { look(preview, "the drop preview", 0) }
    for transition in h.overlays.transitions.suffix(3) { look(transition, "a transition", 0) }
    return problems
  }

  /// A bit of everything a person does in a day. Commands may be refused; nothing may be left in a bad way.
  /// Returns how much it found.
  @discardableResult
  private func day(
    _ h: Harness, _ windows: [WindowID], _ label: String, untilNoon: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation
  ) -> Int {
    let screen = h.visibleFrame
    var found = 0
    var steps = 0
    func check(_ step: String) {
      h.scheduler.advance(by: 3)
      // The first bad moment says the most: what follows is often its consequence.
      guard found == 0 else { return }
      steps += 1
      // Going through all that the panels were handed takes the longest, so not every time.
      for problem in problems(h, panelsToo: steps % 5 == 0).prefix(3) {
        found += 1
        Issue.record("\(label), after \(step): \(problem)", sourceLocation: sourceLocation)
      }
    }
    check("the settings took effect")
    for command in [
      "zoom \(windows[0].rawValue)", "step-out", "step-in", "neighbor right", "desktop", "back", "forward", "show-all",
      "save-view 1", "zoom \(windows[2].rawValue)", "view 1", "toggle-float \(windows[1].rawValue)",
      "toggle-float \(windows[1].rawValue)", "resize \(windows[0].rawValue) right 200", "resize \(windows[0].rawValue) right -5000",
      "arrange", "float-all", "arrange", "pause", "resume", "relayout", "pin \(windows[3].rawValue)", "desktop", "show-all",
      "unpin \(windows[3].rawValue)", "summon Music", "summon Music", "name work", "home", "go work", "unname work",
      "layout Safari | (Mail / Notes)", "exclude com.example.notes", "include com.example.notes", "pass-through com.example.mail",
      "pass-through com.example.mail", "show-shortcuts", "status", "state", "settings", "settings --json", "bindings", "rules", "menu",
      "menu-bar", "doctor", "spaces", "layout", "stats", "version", "help",
    ] {
      h.run(command)
      // A paused Arbor has no layout to compare with.
      if command != "pause" { check(command) }
      if untilNoon, command == "relayout" { return found }
    }
    h.system.drag(windows[3], through: [CGPoint(x: screen.midX, y: screen.midY), CGPoint(x: screen.maxX - 1, y: screen.midY)], holding: 3)
    check("a drag to the right edge")
    h.system.drag(windows[3], through: [CGPoint(x: screen.maxX - 60, y: screen.midY), CGPoint(x: screen.midX, y: screen.midY)], holding: 3)
    check("a drag to the middle")
    for delta: CGFloat in [40, 5000, -10000, 0.25] {
      if let seam = h.overlays.seams[h.display]?.first {
        h.overlays.dragSeam(seam, by: delta)
        check("a gap dragged by \(delta)")
      }
    }
    if let tile = h.overlays.tiles[h.display]?.first {
      h.overlays.clickTile(tile.node)
      check("a click on a tile")
      h.run("show-all")
    }
    let new = h.system.open(app: "Terminal", frame: CGRect(x: 200, y: 200, width: 500, height: 300))
    check("a window opened")
    h.run("dock \(new.rawValue) top")
    check("it was docked")
    h.system.setMinimized(windows[0], true)
    check("a window was minimized")
    h.system.setMinimized(windows[0], false)
    check("it came back")
    h.system.close(new)
    check("a window closed")
    h.system.setDisplays([
      DisplaySnapshot(
        id: h.display, frame: CGRect(x: 0, y: 0, width: 800, height: 600), visibleFrame: CGRect(x: 0, y: 25, width: 800, height: 575), isMain: true)
    ])
    check("the display shrank")
    h.run("show-all")
    check("show-all on the small display")
    return found
  }

  // MARK: The ends of each setting

  /// The values at the ends of what an entry allows, as `set` takes them. Lists have none.
  private func ends(of entry: SettingEntry) -> [String] {
    switch entry.kind {
    case .toggle: ["true", "false"]
    case .number(let range, _, _): [SettingValue.number(range.lowerBound).text, SettingValue.number(range.upperBound).text]
    case .choice(let choices): choices.map(\.value)
    case .text, .list: []
    }
  }

  private var simple: [SettingEntry] { SettingsSchema.entries.filter { !ends(of: $0).isEmpty } }

  @Test func eachSettingAtEachEndAlone() {
    for entry in simple {
      for value in ends(of: entry) {
        let (h, windows) = world()
        let result = h.run("set \(entry.key) \(value)")
        #expect(result.ok, "set \(entry.key) \(value): \(result.message)")
        #expect(entry.value(in: h.controller.settings).text == value, "\(entry.key)")
        day(h, windows, "\(entry.key) \(value)")
      }
    }
  }

  @Test func eachSettingAtEachEndFromTheStart() throws {
    for entry in simple {
      for value in ends(of: entry) {
        var settings = Settings()
        try entry.set(try entry.parse(value), in: &settings)
        let (h, windows) = world(settings)
        day(h, windows, "launched with \(entry.key) \(value)", untilNoon: true)
      }
    }
  }

  /// All at the low end, all at the high end, and some dozens of mixtures. The generator is seeded: a failure names its mixture.
  @Test func allSettingsAtTheirEndsAtOnce() throws {
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    func next() -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int(truncatingIfNeeded: state >> 33)
    }
    // ARBOR_MIXTURES=2000 for a longer look.
    for round in 0..<(Int(ProcessInfo.processInfo.environment["ARBOR_MIXTURES"] ?? "") ?? 30) {
      var settings = Settings()
      var said: [String] = []
      for entry in simple {
        let values = ends(of: entry)
        let value = round == 0 ? values[0] : round == 1 ? values[values.count - 1] : values[next() % values.count]
        try entry.set(try entry.parse(value), in: &settings)
        said.append("\(entry.key) \(value)")
      }
      let (h, windows) = world(settings)
      if day(h, windows, "mixture \(round)") > 0 {
        Issue.record("mixture \(round) is: \(said.joined(separator: ", "))")
        break
      }
      // What is written to the file is read back the same, with nothing to complain of.
      let read = try Settings.read(Data(try settings.fileText.utf8))
      #expect(read == settings && read.valueProblems.isEmpty, "mixture \(round): \(read.valueProblems)")
      // Scripts get JSON, people get numbers.
      let json = try #require(h.run("settings --json").text)
      #expect((try? JSONSerialization.jsonObject(with: Data(json.utf8))) != nil, "mixture \(round)")
      let report = try #require(h.run("settings").text).lowercased()
      #expect(!report.contains("nan") && !report.contains("inf ") && !report.contains("e+"), "mixture \(round)")
      // And there is a way back.
      #expect(h.run("reset all").ok)
      #expect(simple.allSatisfy { $0.isDefault(in: h.controller.settings) }, "mixture \(round)")
      h.run("show-all")
      h.scheduler.advance(by: 3)
      #expect(problems(h).isEmpty, "mixture \(round), after reset all: \(problems(h).first ?? "")")
    }
  }

  /// A file can be saved, and a script can run, at any moment: in the middle of a drag, of a motion, of a peek.
  @Test func aSettingChangesInTheMiddleOfThings() {
    for entry in simple {
      for value in ends(of: entry) {
        let (h, windows) = world()
        let screen = h.visibleFrame
        func check(_ moment: String) {
          h.scheduler.advance(by: 3)
          #expect(problems(h).isEmpty, "set \(entry.key) \(value) \(moment): \(problems(h).first ?? "")")
        }
        h.system.beginDrag(windows[3])
        h.system.moveDrag(to: CGPoint(x: screen.midX, y: screen.midY), holding: 0.1)
        h.run("set \(entry.key) \(value)")
        h.system.moveDrag(to: CGPoint(x: screen.maxX - 1, y: screen.midY), holding: 3)
        h.system.endDrag()
        check("during a drag of a floating window")
        h.run("reset \(entry.key)")
        h.system.beginDrag(windows[0])
        h.system.moveDrag(to: CGPoint(x: screen.midX, y: screen.midY), holding: 0.1)
        h.run("set \(entry.key) \(value)")
        h.system.moveDrag(to: CGPoint(x: screen.midX, y: screen.maxY - 1), holding: 3)
        h.system.endDrag()
        check("during a drag of a docked window")
        h.run("reset \(entry.key)")
        h.run("zoom \(windows[1].rawValue)")
        h.scheduler.advance(by: 0.05)
        h.run("set \(entry.key) \(value)")
        h.scheduler.advance(by: 0.05)
        h.run("show-all")
        check("during a motion")
        h.run("reset \(entry.key)")
        h.keyDown("ctrl+opt+space")
        h.scheduler.advance(by: 1)
        h.run("set \(entry.key) \(value)")
        h.keyUp("ctrl+opt+space")
        check("during a peek")
      }
    }
  }

  // MARK: Beyond the ends

  /// What nobody should be able to get in.
  private static let junk = [
    "nan", "NaN", "-nan", "inf", "-inf", "infinity", "1e400", "-1e400", "1e308", "-1e308", "1e-400", "0x10", "1_000", "١٢", "12,5",
    "12.5.1", "--3", "+", "-", ".", "e5", "", " ", "null", "true false", "[]", "{}", "\"12\"", "12 pt", "１２", "9223372036854775808",
    "yes", "no", "on", "off", "TRUE", "1", "0", "-0", "2", "maybe", "🙂", "a\u{0}b", String(repeating: "9", count: 400),
    String(repeating: "x", count: 100_000),
  ]

  /// Whatever `set` says, the settings in use stay within the schema, and a refusal changes nothing.
  @Test func setTakesNothingFromBeyondTheEnds() throws {
    let (h, _) = world()
    for entry in SettingsSchema.entries {
      if case .list = entry.kind { continue }
      var values = Self.junk
      if case .number(let range, let step, _) = entry.kind {
        values += [range.lowerBound - step, range.upperBound + step, range.lowerBound - 1e-9, range.upperBound + 1e-9]
          .map { "\($0)" }
      }
      for value in values {
        let before = h.controller.settings
        let result = h.controller.perform(.settings(.set(key: entry.key, value: value)))
        let after = entry.value(in: h.controller.settings)
        #expect((try? entry.validated(after)) == after, "set \(entry.key) \(value.prefix(20)) left \(after.text.prefix(40))")
        if !result.ok { #expect(h.controller.settings == before, "set \(entry.key) \(value.prefix(20)) was refused and changed something") }
        #expect(result.message.count < 600, "set \(entry.key) \(value.prefix(20)): a reply of \(result.message.count) characters")
        h.scheduler.advance(by: 3)
        #expect(problems(h).isEmpty, "set \(entry.key) \(value.prefix(20)): \(problems(h).first ?? "")")
        // From the default each time. (A gap that changes by a single point moves no window: `isInPlace` allows for one.)
        h.run("reset \(entry.key)")
        h.scheduler.advance(by: 3)
      }
    }
  }

  /// A file can say anything. What is read from it is within the schema, and what was not usable is reported.
  @Test func aFileGetsNothingInFromBeyondTheEnds() throws {
    let values = [
      "1e400", "-1e400", "1e308", "-1e308", "1e-320", "-0.0", "0", "-1", "99999999999999999999", "null", "true", "false", "\"\"", "\"12\"",
      "\"nan\"", "\"x\"", "[]", "{}", "[1]", "{\"a\": 1}", "[[[[[[[[[[]]]]]]]]]]", "\"\\u0000\"", "\"🙂\"",
    ]
    for entry in SettingsSchema.entries {
      for value in values {
        let text = "{\"\(entry.key)\": \(value)}"
        let settings: Settings
        do {
          settings = try Settings.read(Data(text.utf8))
        } catch {
          // Refused whole, with a reason: Arbor goes on with what it had.
          #expect(!"\(error)".isEmpty)
          continue
        }
        let read = entry.value(in: settings)
        if case .list = entry.kind {
        } else {
          #expect((try? entry.validated(read)) == read, "\(text) was read as \(read.text.prefix(40))")
        }
        // Either it is what the file says, or somebody is told.
        let isDefault = read == entry.defaultValue
        let told = !settings.valueProblems.isEmpty || !settings.skippedRules.isEmpty || !settings.skippedDisplays.isEmpty
          || !KeyBindings.effective(settings: settings).problems.isEmpty
        if isDefault, !told, value != "null" {
          let same = (try? entry.parse(value.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))) == entry.defaultValue
          let empty = ["[]", "{}"].contains(value)
          // An older spelling that means the default (`gapHandles` was a switch for a while): its opposite reads otherwise.
          let opposite = ["true": "false", "false": "true"][value].flatMap {
            try? Settings.read(Data("{\"\(entry.key)\": \($0)}".utf8))
          }
          let understood = opposite.map { entry.value(in: $0) != read } ?? false
          #expect(same || empty || understood, "\(text) was dropped and nobody was told")
        }
        if !isDefault {
          let (h, _) = world(settings)
          #expect(problems(h).isEmpty, "\(text): \(problems(h).first ?? "")")
        }
      }
    }
  }

  /// The same for what a file gives one display alone.
  @Test func aDisplaysOwnOptionsStayWithinTheEndsToo() throws {
    let values = [
      "1e400", "-1e400", "1e308", "-1e308", "-1", "-0.0", "0", "100000", "99999999999999999999", "null", "true", "\"12\"", "[]", "{}",
    ]
    for key in ["gap", "minimumUsableWidth", "minimumUsableHeight", "screenEdgeBand"] {
      let entry = try SettingsSchema.entry(named: key)
      for value in values {
        let text = "{\"displays\": [{\"match\": \"main\", \"\(key)\": \(value)}]}"
        guard let settings = try? Settings.read(Data(text.utf8)) else { continue }
        let (h, windows) = world(settings)
        for display in h.system.displayList {
          let there = entry.value(in: h.controller.options(for: display.id))
          #expect((try? entry.validated(there)) == there, "\(text) gives the display \(there.text.prefix(40))")
        }
        if settings.displays.isEmpty { #expect(!settings.skippedDisplays.isEmpty || value == "null", "\(text): nobody was told") }
        day(h, windows, text, untilNoon: true)
      }
    }
  }

  /// The window's model: a slider that reports nonsense, a field with anything typed into it.
  @Test func theWindowsModelGetsNothingInFromBeyondTheEnds() {
    let (h, _) = world()
    let model = SettingsPanelModel(controller: h.controller, runningApps: { [] }, run: { h.controller.perform($0) })
    for entry in SettingsSchema.entries {
      guard case .number(let range, _, _) = entry.kind else { continue }
      for value in [
        Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude, .leastNonzeroMagnitude, -0.0,
        range.lowerBound - 1, range.upperBound + 1, range.lowerBound, range.upperBound,
      ] {
        model.set(entry.key, to: value)
        let after = entry.value(in: h.controller.settings)
        #expect((try? entry.validated(after)) == after, "\(entry.key) to \(value) left \(after.text)")
        #expect(model.errors[entry.key] == nil, "a slider cannot be refused: \(entry.key) to \(value): \(model.errors[entry.key] ?? "")")
      }
      h.run("reset \(entry.key)")
    }
    for entry in SettingsSchema.entries {
      if case .list = entry.kind { continue }
      for text in Self.junk {
        model.type(text, into: .setting(entry.key))
        model.handOverDrafts()
        let after = entry.value(in: h.controller.settings)
        #expect((try? entry.validated(after)) == after, "\(entry.key): typed \(text.prefix(20)), left \(after.text.prefix(40))")
        #expect((model.errors[entry.key] ?? "").count < 600)
        #expect(model.row(for: entry) != nil || entry.level == .hidden)
      }
      h.run("reset \(entry.key)")
    }
    #expect(problems(h).isEmpty)
  }
}

/// The window can be open on any day: during a pause, before the permission, over a broken file, with no display at all.
@Suite @MainActor struct SettingsWindowOnABadDayTests {
  private func everything(_ model: SettingsPanelModel) {
    for pane in model.panes {
      model.go(to: pane)
      if case .section(let section) = pane {
        model.setAdvanced(true, in: section)
        for row in model.rows(in: section) + model.advancedRows(in: section) {
          switch row.control {
          case .toggle(let isOn):
            model.set(row.key, to: !isOn)
            model.set(row.key, to: isOn)
          case .number(_, let range, _, _):
            model.set(row.key, to: range.upperBound)
            model.type("1e9", into: .setting(row.key))
            model.handOver(.setting(row.key))
          case .choice(_, let choices): for choice in choices { model.set(row.key, to: choice.value) }
          case .text: model.set(row.key, to: "nonsense")
          case .apps:
            model.add("com.example.mail", to: row.key)
            model.remove("com.example.mail", from: row.key)
          case .list: break
          }
          model.reset(row.key)
        }
        model.restoreDefaults(in: section)
      }
    }
    model.go(to: .shortcuts)
    for row in model.shortcutRows.prefix(3) {
      model.startRecording(row)
      _ = model.keyPressed(code: KeyChord.Key.f9.code, modifiers: [.control, .option, .shift])
      model.replaceHolder()
      model.cancelRecording()
      if let now = model.shortcutRows.first(where: { $0.command == row.command }) {
        model.removeShortcut(now)
        if let then = model.shortcutRows.first(where: { $0.command == row.command }) { model.restoreShortcut(then) }
      }
    }
    model.startRecording(commandText: "set gap 0")
    _ = model.keyPressed(code: KeyChord.Key.f8.code, modifiers: [.control, .option])
    model.restoreAllShortcuts()
    model.answer(yes: true)
    model.answer(yes: true)
    model.go(to: .rules)
    model.addRule(app: "com.example.mail")
    model.addRule(app: "com.example.notes")
    for kind in SettingsPanelModel.RuleKind.allCases { if let row = model.ruleRows.first { model.setKind(kind, of: row) } }
    if let row = model.ruleRows.first {
      model.type("Inbox", into: row.titleField)
      model.moveRule(row, by: 1)
    }
    for row in model.ruleRows.reversed() { model.removeRule(row) }
    model.search = "a"
    _ = model.found
    model.search = ""
    model.setOpensAtLogin(true)
    model.setOpensAtLogin(false)
    model.replaceFileWithDefaults()
    model.answer(yes: false)
    model.handOverDrafts()
  }

  private func model(_ h: Harness) -> SettingsPanelModel {
    SettingsPanelModel(
      controller: h.controller, runningApps: { [.init(bundleID: "com.example.mail", name: "Mail")] }, run: { h.controller.perform($0) })
  }

  private func harness() -> Harness {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    return h
  }

  @Test func onAnOrdinaryDayEverythingEndsWhereItBegan() {
    let h = harness()
    everything(model(h))
    #expect(h.controller.settings == Settings())
    h.scheduler.advance(by: 3)
    #expect(h.layoutProblems().isEmpty)
  }

  @Test func duringAPause() {
    let h = harness()
    h.run("pause")
    everything(model(h))
    #expect(h.controller.settings == Settings() && h.controller.isPaused)
    h.run("resume")
    h.scheduler.advance(by: 3)
    #expect(h.layoutProblems().isEmpty)
  }

  @Test func beforeThePermission() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    everything(model(h))
    #expect(h.controller.settings == Settings())
  }

  @Test func overAFileThatCannotBeRead() {
    let h = harness()
    h.controller.loadSettings = { throw Settings.FileError("line 1, column 1: no") }
    h.controller.takeInSettingsFile()
    let model = self.model(h)
    everything(model)
    #expect(h.controller.settings == Settings(), "nothing is changed while nothing can be saved")
    #expect(model.fileProblem != nil)
  }

  @Test func whereNothingCanBeSaved() {
    let h = harness()
    struct Full: Error, CustomStringConvertible { let description = "the disk is full" }
    h.controller.saveSettings = { _, _ in throw Full() }
    h.controller.loadSettings = { Settings() }
    let model = self.model(h)
    everything(model)
    #expect(h.controller.settings == Settings(), "the settings in use are what the file says")
  }

  @Test func withNoDisplayAtAll() {
    let h = harness()
    h.system.setDisplays([])
    everything(model(h))
    #expect(h.controller.settings == Settings())
  }
}
