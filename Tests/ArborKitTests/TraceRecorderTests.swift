import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The trace a harness has recorded, read back.
@MainActor
func recordedTrace(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) -> Trace {
  do {
    return try Trace(text: h.lastTrace ?? "")
  } catch {
    Issue.record("the recorded trace cannot be read: \(error)", sourceLocation: sourceLocation)
    return Trace(
      header: TraceHeader(
        name: "", arbor: "", os: "", recorded: "", displays: [], windows: [], settings: Settings(), workspaces: [:],
        focused: nil, cursor: .zero, mouseDown: false, thinning: 0),
      entries: [])
  }
}

/// The lines these tests are about. Reads, news of the keyboard focus and timers other than the save come and go as
/// features are added to the controller, and each of those has tests of its own.
private func essential(_ entries: [TraceEntry]) -> [TraceEntry] {
  entries.filter { entry in
    switch entry.line {
    case .focusedWindow, .cursorLocation, .isMouseButtonDown, .displays, .allWindows, .other(.read, _, _, _), .keyboardFocusMoved, .end: false
    case .timer(let key): key == "save"
    default: true
    }
  }
}

private func endReason(_ entries: [TraceEntry]) -> String? {
  if case .end(let reason, _, _)? = entries.last?.line { return reason }
  return nil
}

@MainActor
@Suite struct TraceRecorderTests {
  // MARK: The command

  @Test func nothingIsRecordedUntilATraceIsStarted() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.runPending()
    #expect(!h.recorder.isRecording)
    #expect(h.recorder.sink == nil)
    #expect(h.run("trace status").message == "not recording")
  }

  @Test func traceOnOffAndStatusSayWhatIsGoingOn() {
    let h = Harness()
    h.start()
    let on = h.run("trace on safari-drag")
    #expect(on.ok)
    // The harness's clock starts on 9 May 2026 at 06:13:20 UTC.
    #expect(on.message.hasPrefix("recording 2026-05-09-061320-safari-drag.jsonl: 1 lines"))
    #expect(on.message.contains("stops by itself at 20 MB or 10 minutes"))
    #expect(h.run("trace status").message == on.message)
    #expect(h.run("trace").ok)

    let again = h.run("trace on other")
    #expect(!again.ok)
    #expect(again.message.contains("already recording") && again.message.contains("trace off"))

    let off = h.run("trace off")
    #expect(off.ok)
    #expect(off.message == "trace saved: 2026-05-09-061320-safari-drag.jsonl: 2 lines, trace off")
    #expect(h.run("trace status").message == "not recording; last trace 2026-05-09-061320-safari-drag.jsonl: 2 lines, trace off")
    #expect((h.recorder.sink as? MemoryTraceSink)?.isClosed == true)
    #expect(!h.run("trace off").ok)
    #expect(!h.run("trace note too late").ok)
  }

  @Test func aTraceWithoutANameIsCalledTrace() {
    let h = Harness()
    h.start()
    h.run("trace on")
    #expect(h.recorder.sink?.location == "2026-05-09-061320-trace.jsonl")
    #expect(recordedTrace(h).header.name == "trace")
  }

  @Test func aTraceNeedsArborToBeRunning() {
    let h = Harness()
    #expect(!h.run("trace on early").ok)
    #expect(h.run("trace status").ok)
    #expect(!h.recorder.isRecording)
  }

  @Test func aControllerOnAPlainWindowSystemCannotRecord() {
    let controller = Controller(
      system: FakeWindowSystem(), overlays: FakeOverlays(), store: MemoryStateStore(), scheduler: ManualScheduler())
    controller.start()
    for command in [Command.trace(.on(name: nil)), .trace(.off), .trace(.status), .trace(.note("x"))] {
      let result = controller.perform(command)
      #expect(!result.ok)
      #expect(result.message == "traces cannot be recorded here")
    }
    #expect(controller.perform(.showAll).ok)
  }

  @Test func aSecondTraceStartsAfresh() {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "First")
    h.start()
    h.run("trace on one")
    h.run("dock \(a.rawValue) left")
    h.run("trace off")
    h.scheduler.advance(by: 5)
    h.run("trace on two")
    h.run("float \(a.rawValue)")
    h.run("trace off")
    let trace = recordedTrace(h)
    #expect(trace.header.name == "two")
    #expect(trace.header.workspaces[h.display]?.isDocked(a) == true)
    #expect(trace.entries.first?.t == 0)
    #expect(trace.entries.first?.line == .command("float \(a.rawValue)"))
  }

  // MARK: One trace after the other

  @Test func theNextTraceBeginsWhereTheLastOneEnds() {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "First")
    h.start()
    var sinks: [MemoryTraceSink] = []
    h.recorder.openSink = { name in
      sinks.append(MemoryTraceSink(location: name))
      return sinks[sinks.count - 1]
    }
    #expect(h.run("trace next day-1 the first hour").ok)
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 5)
    #expect(h.run("trace next day-2 the second hour").ok)
    h.run("float \(a.rawValue)")
    #expect(h.run("trace off").ok)

    #expect(sinks.count == 2)
    let first = try! Trace(text: sinks[0].text)
    #expect(first.header.name == "day-1")
    #expect(first.entries.first?.line == .note("the first hour"))
    #expect(first.entries.contains { $0.line == .command("dock \(a.rawValue) left") })
    guard case .end(let reason, _, _)? = first.entries.last?.line else {
      Issue.record("the first trace has no last line")
      return
    }
    #expect(reason == "another trace was started")
    // The second begins with the world as it was by then, and holds nothing of the first.
    let second = try! Trace(text: sinks[1].text)
    #expect(second.header.name == "day-2")
    #expect(second.header.workspaces[h.display]?.isDocked(a) == true)
    #expect(second.entries.first?.t == 0)
    #expect(second.entries.map(\.line).prefix(2) == [.note("the second hour"), .command("float \(a.rawValue)")])
  }

  /// Whoever records all the time must not be in the way of somebody who records one thing, nor cut their trace in two.
  @Test func aTraceAskedForByNameTakesOverFromARowAndIsLeftAloneByIt() {
    let h = Harness()
    h.system.open(app: "Safari", title: "First")
    h.start()
    #expect(h.run("trace next row-1").ok)
    #expect(h.run("trace on mine").ok)
    #expect(recordedHeaderName(h) == "mine")
    let refusal = h.run("trace next row-2")
    #expect(!refusal.ok)
    #expect(refusal.message.contains("until `trace off`"))
    #expect(recordedHeaderName(h) == "mine")
    // As ever.
    #expect(!h.run("trace on another").ok)
    #expect(h.run("trace off").ok)
    #expect(h.run("trace next row-3").ok)
    #expect(recordedHeaderName(h) == "row-3")
  }

  private func recordedHeaderName(_ h: Harness) -> String? {
    (h.recorder.sink as? MemoryTraceSink).flatMap { try? Trace(text: $0.text) }?.header.name
  }

  @Test func theNextTraceNeedsArborToBeRunningToo() {
    let h = Harness()
    #expect(!h.run("trace next early").ok)
    h.start()
    h.run("pause")
    #expect(!h.run("trace next paused").ok)
    #expect(!h.recorder.isRecording)
  }

  /// The header says where the windows are, not what a hand is in the middle of.
  @Test func noTraceBeginsInTheMiddleOfADragOrWhileAKeyIsHeld() {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "First")
    h.start()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("trace next row-1").ok)

    h.system.beginDrag(a)
    #expect(!h.run("trace next row-2 in the hand").ok)
    #expect(recordedHeaderName(h) == "row-1")
    #expect(recordedTrace(h).entries.last?.line == .note("in the hand"), "the remark is in the trace that goes on")
    h.system.endDrag()
    h.scheduler.advance(by: 1)
    #expect(h.run("trace next row-2").ok)

    // The button alone: a press that is no drag yet, or one on something Arbor hears nothing of.
    h.system.mouseDown = true
    #expect(!h.run("trace next row-3").ok)
    h.system.mouseDown = false

    h.system.userFocus(a)
    h.keyDown("ctrl+opt+space")
    #expect(!h.run("trace next row-3").ok)
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.run("trace next row-3").ok)
    #expect(recordedHeaderName(h) == "row-3")
  }

  // MARK: Whoever watches changes nothing

  /// A script that is recorded says a word to the recorder at every step and after every check. As commands those words ended what was being checked.
  @Test(arguments: ["trace next row-1 a remark", "trace note a remark", "trace status", "trace on mine", "trace off"])
  func aWordToTheRecorderLeavesWhatIsOnScreenAlone(word: String) throws {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "First")
    let b = h.system.open(app: "Notes", title: "Second")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("trace next row-0")

    // Go to… is open.
    h.run("find")
    #expect(h.overlays.finder != nil)
    h.run(word)
    #expect(h.overlays.finder != nil, "`\(word)` closed Go to…")
    h.run("find")

    // The cheat sheet shows.
    h.controller.perform(.showShortcuts, from: .shortcut)
    #expect(!h.overlays.cheatSheets.isEmpty)
    h.run(word)
    #expect(!h.overlays.cheatSheets.isEmpty, "`\(word)` put the cheat sheet away")
    h.overlays.dismissCheatSheet()

    // ⌃⌥Space is held: a peek.
    h.system.userFocus(a)
    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 0.4)
    #expect(h.controller.isPeeking)
    h.run(word)
    #expect(h.controller.isPeeking, "`\(word)` ended the peek")
  }

  /// A command without a window follows whichever hand was used last, and remembers what it followed (F56). A word to the recorder follows nothing.
  @Test func aWordToTheRecorderIsNoCommandToCount() {
    let h = Harness()
    h.start()
    h.run("stats reset")
    for word in ["trace next row-1 a remark", "trace note a remark", "trace off"] { #expect(h.run(word).ok) }
    #expect(h.run("stats").text?.contains("trace") != true)
  }

  // MARK: The header

  @Test func theHeaderDescribesTheWorldAndWhatArborKnows() {
    var settings = Settings()
    settings.gap = 20
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Xcode", pid: 12, minimumSize: CGSize(width: 900, height: 600))
    let c = h.system.open(app: "Notes", pid: 13)
    let d = h.system.open(app: "Mail", pid: 14)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) right")
    h.run("dock \(b.rawValue) beside \(c.rawValue) bottom")  // Too big for its slot: a tile.
    h.system.setMinimized(d, true)
    h.system.userFocus(a)
    h.system.cursor = CGPoint(x: 100, y: 200)
    h.run("zoom \(a.rawValue)")
    h.run("trace on world")

    let header = recordedTrace(h).header
    #expect(header.trace == TraceHeader.currentVersion)
    #expect(header.name == "world")
    #expect(header.arbor == "test")
    #expect(header.os == "simulated")
    #expect(header.recorded == "2026-05-09T06:13:20Z")
    #expect(header.displays == [TraceDisplay(FakeWindowSystem.standardDisplay)])
    #expect(header.settings == settings)
    #expect(header.workspaces == h.controller.workspaces)
    #expect(header.windows.map(\.id) == [a, b, c, d])
    #expect(header.windows.map(\.pid) == [11, 12, 13, 14])
    #expect(header.windows.map(\.app) == ["Safari", "Xcode", "Notes", "Mail"])
    #expect(header.windows.map(\.bundle) == ["com.example.safari", "com.example.xcode", "com.example.notes", "com.example.mail"])
    #expect(header.windows.map(\.frame) == [a, b, c, d].map { h.frame($0)! })
    #expect(header.windows.map(\.minimized) == [false, false, false, true])
    #expect(header.parked == h.controller.parked.sorted())
    #expect(header.parked.contains(c))
    #expect(header.minimumSizes == [b: CGSize(width: 900, height: 600)])
    #expect(header.focusHistory.first == a)
    #expect(header.focused == a)
    #expect(header.cursor == CGPoint(x: 100, y: 200))
    #expect(!header.mouseDown)
    #expect(header.thinning == 0.05)
    #expect(header.onlyPIDs == nil)
    // Reading the world for the header is not part of what is recorded.
    #expect(recordedTrace(h).entries.isEmpty)
  }

  @Test func theHeaderHoldsTheFilterAndTheDisplaysThatAreAway() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.palette", action: .ignore)]
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1000, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1000, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, second], settings: settings)
    h.controller.filter.onlyPIDs = [1000, 7]
    h.start()
    let palette = h.system.open(app: "Palette", pid: 1000)
    let a = h.system.open(app: "Safari", pid: 7, frame: CGRect(x: 1500, y: 100, width: 400, height: 300))
    h.run("dock \(a.rawValue) left")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.run("trace on filter")
    let header = recordedTrace(h).header
    #expect(header.onlyPIDs == [7, 1000])
    #expect(header.ignored == [palette])
    #expect(header.dormant[second.id]?.isDocked(a) == true)
  }

  // MARK: Privacy

  /// F27. What is typed to find a window is part of its title, any part, so looking for whole titles in the text of commands
  /// does not catch it; and the finder's rows are made of titles.
  @Test func whatIsTypedToFindAWindowNeverReachesATraceAndTheCommandStillReplays() throws {
    let named = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: FakeWindowSystem.standardDisplay.frame,
      visibleFrame: FakeWindowSystem.standardDisplay.visibleFrame, isMain: true, name: "Robin's iPad")
    var settings = Settings()
    settings.bindings = ["ctrl+opt+m": "find payslip"]
    let h = Harness(displays: [named], settings: settings)
    let a = h.system.open(app: "Safari", title: "My diagnosis - Search")
    let b = h.system.open(app: "Safari", title: "Divorce lawyers near me")
    let c = h.system.open(app: "Mail", title: "Your payslip for October")
    h.start()
    h.run("arrange")
    h.run("trace on private")
    // Parts of titles, of fewer than four letters too, and letters that are not next to each other.
    #expect(h.run("find diag").ok)
    #expect(h.system.focused == a)
    #expect(h.run("find law").ok)
    #expect(h.system.focused == b)
    #expect(h.run("find pyslp").ok)
    #expect(h.system.focused == c)
    // A shortcut somebody made for it.
    h.system.userFocus(a)
    #expect(h.key("ctrl+opt+m")?.ok == true)
    #expect(h.system.focused == c)
    // Nothing matches, and the reply quotes what was asked for.
    let failed = h.run("find chemotherapy")
    #expect(!failed.ok && failed.message.contains("chemotherapy"))
    // The palette: what is typed stays in it.
    #expect(h.run("find").ok)
    h.overlays.typeInFinder("diagnosis")
    #expect(h.overlays.chooseInFinder())
    #expect(h.system.focused == a)
    #expect(h.run("find").ok)
    h.overlays.dismissFinder()
    h.run("trace off")

    let text = h.lastTrace ?? ""
    for secret in [
      "diag", "law", "pyslp", "chemo", "payslip", "October", "Divorce", "Search", "iPad", "Robin",
    ] {
      #expect(!text.contains(secret), "\(secret)")
    }
    let lines = recordedTrace(h).entries.map(\.line)
    #expect(recordedTrace(h).header.settings.bindings == ["ctrl+opt+m": "find …"])
    #expect(lines.contains(.command("find title[3]", from: .shortcut)))
    #expect(lines.contains(.command("find title[1]")) && lines.contains(.command("find title[2]")) && lines.contains(.command("find title[3]")))
    #expect(lines.contains(.command("find …")))
    #expect(lines.contains { if case .other(.action, "finderChose", _, _) = $0 { true } else { false } })
    #expect(lines.contains { if case .other(.action, "finderDismissed", _, _) = $0 { true } else { false } })

    // Each finds the same window again, where the titles are tokens, and the one that found nothing finds nothing.
    let replayer = TraceReplayer(try Trace(text: text), mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.system.focused == a)
    #expect(replayer.harness.controller.workspaces == h.controller.workspaces)
  }

  @Test func noWindowTitleEverReachesATrace() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.mail", title: "Payslip", action: .dock(.left))]
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", title: "My diagnosis - Search")
    h.start()
    h.run("trace on private")
    let b = h.system.open(app: "Mail", title: "Your payslip for October")
    var renamed = h.system.windows[a]!.snapshot
    renamed.title = "Divorce lawyers near me"
    h.system.install(renamed)
    h.system.events?.windowChanged(renamed, userInitiated: true)
    h.system.userFocus(a)
    h.run("state")
    h.run("rules")
    h.run("ascii")
    h.run("dock \(a.rawValue) right")
    h.run("exclude com.example.notes")
    h.system.drag(b, through: [CGPoint(x: 300, y: 300), CGPoint(x: 900, y: 400)])
    h.system.close(a)
    h.scheduler.runPending()
    h.run("trace off")

    let text = h.lastTrace ?? ""
    for secret in ["diagnosis", "payslip", "Payslip", "October", "Divorce", "lawyers"] {
      #expect(!text.contains(secret), "\(secret)")
    }
    // The rule still worked, and will again in a replay.
    #expect(h.workspace.isDocked(b) || h.workspace.isFloating(b))
    let trace = recordedTrace(h)
    #expect(trace.header.windows.map(\.title) == ["title[1]"])
    #expect(trace.header.settings.rules.map(\.title) == ["[p1]"])
    #expect(trace.entries.first?.line.description.contains("w\(b.rawValue) appeared") == true)
    guard case .appeared(let mail)? = trace.entries.first?.line else { return }
    #expect(mail.title == "title[2][p1]")
  }

  @Test func settingsAppliedDuringATraceAreRecordedWithoutTitlePatterns() {
    let h = Harness()
    h.start()
    h.run("trace on settings")
    var settings = Settings()
    settings.gap = 30
    settings.rules = [AppRule(app: "com.example.mail", title: "Payslip", action: .float)]
    h.controller.apply(settings: settings)
    h.controller.loadSettings = { settings }
    h.run("reload-settings")
    h.run("trace off")
    let entries = essential(recordedTrace(h).entries).filter { !$0.line.isEffect }
    guard entries.count >= 3, case .settings(let direct) = entries[0].line, case .settings(let reloaded) = entries[2].line else {
      Issue.record("expected settings lines, got \(entries.map(\.line))")
      return
    }
    #expect(direct.gap == 30)
    #expect(direct.rules.map(\.title) == ["[p1]"])
    #expect(!entries[0].nested)
    #expect(entries[1].line == .command("reload-settings"))
    // A consequence of the command, which a replay must not apply a second time.
    #expect(entries[2].nested)
    #expect(reloaded == direct)
    #expect(h.lastTrace?.contains("Payslip") == false)
  }

  // MARK: What is recorded

  @Test func eventsCallsCommandsActionsAndTimersAreRecordedInTheOrderTheyHappened() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.scheduler.runPending()
    h.run("trace on order")
    h.run("trace note dock, open, focus, close")
    h.scheduler.advance(by: 0.25)
    let docked = h.run("dock \(a.rawValue) left")
    let slot = h.frame(a)!
    h.scheduler.advance(by: 0.25)
    let b = h.system.open(app: "Notes")
    h.system.userFocus(b)
    h.scheduler.advance(by: 1)
    h.system.close(b)
    let refused = h.run("dock 999 left")
    #expect(docked.ok && !refused.ok)
    h.run("trace off")

    // What else is in between (reads, echoes, other features' timers) is the controller's and the fake's business.
    let all = recordedTrace(h).entries
    let landmarks: [(what: String, t: Double, matches: (TraceLine) -> Bool)] = [
      ("the remark", 0, { $0 == .note("dock, open, focus, close") }),
      ("the command", 0.25, { $0 == .command("dock \(a.rawValue) left") }),
      ("the frame it set", 0.25, { $0 == .setFrame(a, slot, result: slot, took: nil) }),
      ("the focus it asked for", 0.25, { $0 == .focus(a) }),
      ("its result", 0.25, { $0 == .done("dock \(a.rawValue) left", ok: true, message: docked.message) }),
      ("the new window", 0.5, { if case .appeared(let window) = $0 { window.id == b && window.title == "title[2]" } else { false } }),
      ("its focus", 0.5, { $0 == .focused(b) }),
      ("the save", 1, { $0 == .timer("save") }),
      ("the window closing", 1.5, { $0 == .destroyed(b) }),
      ("the second command", 1.5, { $0 == .command("dock 999 left") }),
      ("its failure", 1.5, { $0 == .done("dock 999 left", ok: false, message: refused.message) }),
    ]
    var position = all.startIndex
    for landmark in landmarks {
      guard let index = all[position...].firstIndex(where: { landmark.matches($0.line) }) else {
        Issue.record("\(landmark.what) is missing, or out of order")
        continue
      }
      #expect(all[index].t == landmark.t, "\(landmark.what)")
      #expect(!all[index].nested, "\(landmark.what)")
      position = index + 1
    }
    #expect(all.map(\.t) == all.map(\.t).sorted())
    #expect(all.map(\.number) == Array(2...(all.count + 1)))
    #expect(all.last?.line == .end(reason: "trace off", lines: all.count, thinned: 0))
  }

  @Test func aDragIsRecordedWithItsPreviews() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("trace on drag")
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: 620, y: 210), CGPoint(x: 300, y: 300), CGPoint(x: 3, y: 450)])
    h.run("trace off")
    let kinds = essential(recordedTrace(h).entries).map { $0.line.description.split(separator: " ").prefix(3).joined(separator: " ") }
    // In this order, whatever else a drag has come to involve.
    var rest = kinds[...]
    for landmark in [
      "drag of w101", "w101 changed (not", "drag of w101", "showDropPreview 12,37 702×851", "drag of w101", "showDropPreview off",
      "setFrame w101 12,37",
    ] {
      guard let index = rest.firstIndex(of: landmark) else {
        Issue.record("`\(landmark)` is missing or out of order in \(kinds)")
        return
      }
      rest = rest[(index + 1)...]
    }
  }

  @Test func edgeResizesReadsOverlayActionsAndDisplayChangesAreRecorded() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Xcode", minimumSize: CGSize(width: 900, height: 600))
    let c = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) right")
    h.run("trace on more")
    h.run("dock \(b.rawValue) beside \(c.rawValue) bottom")
    var wider = h.frame(a)!
    wider.size.width += 60
    h.system.userResize(a, to: wider)
    let seam = h.overlays.seams[h.display]![0]
    h.overlays.dragSeam(seam, by: -20)
    let tile = h.overlays.tiles[h.display]![0].node
    h.overlays.clickTile(tile)
    h.run("show-all")
    h.system.userMove(a, to: CGRect(x: 50, y: 50, width: 300, height: 300))
    h.scheduler.advance(by: 0.3)
    let bigger = DisplaySnapshot(
      id: h.display, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    h.system.setDisplays([bigger])
    h.run("trace off")

    let lines = recordedTrace(h).entries.map(\.line)
    #expect(lines.contains(.resizeBegan(a)))
    #expect(lines.contains(.resizeEnded(a)))
    #expect(lines.contains(.seamDragged(display: h.display, seam: seam, by: -20)))
    #expect(lines.contains(.tileActivated(display: h.display, node: tile)))
    #expect(lines.contains(.cursorLocation(h.system.cursor)))
    #expect(lines.contains(.timer("enforce-main")))
    #expect(lines.contains(.isMouseButtonDown(false)))
    #expect(lines.contains(.displaysChanged([TraceDisplay(bigger)])))
    #expect(lines.contains(.displays([TraceDisplay(bigger)])))
    #expect(lines.contains { if case .focusedWindow = $0 { true } else { false } })
  }

  @Test func aRefusedSizeShowsAsAnAnswerThatDiffersFromTheRequest() {
    let h = Harness()
    let a = h.system.open(app: "Xcode", minimumSize: CGSize(width: 900, height: 600))
    h.start()
    h.run("trace on refusal")
    let asked = CGRect(x: 10, y: 30, width: 300, height: 700)
    let took = CGRect(x: 10, y: 30, width: 900, height: 700)
    #expect(h.controller.system.setFrame(asked, of: a) == took)
    #expect(h.controller.system.setFrame(asked, of: WindowID(999)) == nil)
    let lines = recordedTrace(h).entries.map(\.line)
    #expect(lines.contains(.setFrame(a, asked, result: took, took: nil)))
    #expect(lines.contains(.setFrame(WindowID(999), asked, result: nil, took: nil)))
  }

  @Test func quittingEndsTheTrace() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("trace on quit")
    h.run("quit")
    h.controller.shutdown()
    #expect(!h.recorder.isRecording)
    let lines = recordedTrace(h).entries.map(\.line)
    #expect(lines.suffix(2) == [.stop, .end(reason: "Arbor stopped", lines: lines.count, thinned: 0)])
    #expect(lines.first == .command("quit"))
  }

  @Test func slowCallsSayHowLongTheyTook() {
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    var time = 100.0
    recorder.clock = { time }
    recorder.openSink = { _ in sink }
    let slow = SpyWindowSystem()
    slow.onSetFrame = { time += 0.0304 }
    let system = RecordingWindowSystem(wrapping: slow, recorder: recorder)
    try? recorder.begin(name: "slow", fileName: "slow") { _ in Self.emptyHeader }
    _ = system.setFrame(CGRect(x: 1, y: 2, width: 3, height: 4), of: WindowID(5))
    #expect(sink.lines.last == #"{"t":0.0304,"call":"setFrame","frame":[1,2,3,4],"id":5,"result":[1,2,3,4],"took":0.0304}"#)
  }

  // MARK: Thinning

  /// A drag as a Mac reports it: the pointer and the frame every few milliseconds.
  private func longDrag(_ h: Harness, _ window: WindowID, steps: Int, every seconds: Double) {
    let start = h.frame(window)!
    h.system.mouseDown = true
    h.system.events?.dragBegan(window, at: CGPoint(x: 700, y: 210))
    for step in 1...steps {
      h.scheduler.advance(by: seconds)
      var snapshot = h.system.windows[window]!.snapshot
      snapshot.frame.origin = CGPoint(x: start.minX, y: start.minY + CGFloat(step))
      h.system.install(snapshot)
      h.system.events?.windowChanged(snapshot, userInitiated: true)
      h.system.events?.dragMoved(window, to: CGPoint(x: 700, y: 210 + CGFloat(step)))
    }
    h.system.mouseDown = false
    h.system.events?.dragEnded(window, at: CGPoint(x: 700, y: 210 + CGFloat(steps)))
  }

  @Test func aLongDragIsThinnedButKeepsItsFirstAndLastMoves() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("trace on long")
    longDrag(h, a, steps: 200, every: 0.008)  // 1.6 s at 125 reports a second.
    h.run("trace off")

    let entries = recordedTrace(h).entries
    let moves = entries.filter { if case .dragMoved = $0.line { true } else { false } }
    let changes = entries.filter { if case .changed = $0.line { true } else { false } }
    // One per 50 ms, give or take the ends.
    #expect((28...36).contains(moves.count), "\(moves.count)")
    #expect((28...36).contains(changes.count), "\(changes.count)")
    #expect(moves.first?.line == .dragMoved(a, to: CGPoint(x: 700, y: 211)))
    #expect(moves.last?.line == .dragMoved(a, to: CGPoint(x: 700, y: 410)))
    guard case .changed(let last, _)? = changes.last?.line else { return }
    // Where the window is dropped is where it floats, so the last frame matters most.
    #expect(last.frame == h.frame(a))
    #expect(entries.map(\.t) == entries.map(\.t).sorted())
    guard case .end(_, let lines, let thinned)? = entries.last?.line else { return }
    #expect(lines == entries.count)
    #expect(thinned == 400 - moves.count - changes.count)
  }

  /// F09 asks for the modifier keys at every step of a drag. A question is not a reaction, or nothing would ever be thinned; a new
  /// answer is news, or a replay would not know when ⌘ went down.
  @Test func questionsWithTheSameAnswerGoWithTheirLineAndANewAnswerKeepsIt() throws {
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    recorder.openSink = { _ in sink }
    var now = 0.0
    recorder.clock = { now }
    try recorder.begin(name: "x", fileName: "x") { _ in Self.emptyHeader }
    let id = WindowID(5)
    for step in 1...100 {
      now = Double(step) * 0.001
      recorder.stimulus(.dragMoved(id, to: CGPoint(x: step, y: 0)), thinKey: "dragMoved") {
        _ = recorder.read("keys") { step < 60 ? "none" : "cmd" }
      }
    }
    recorder.end(reason: "done")
    let lines = try Trace(text: sink.text).entries.map(\.line.description)
    let moves = lines.filter { $0.hasPrefix("drag of") }
    // The first, which comes with the first answer; one 0.05 s later; the one that found ⌘ down; the last.
    #expect(moves.count == 4, "\(lines)")
    #expect(moves.contains { $0.hasSuffix("60,0") })
    // Every move that is kept has its answer after it, and no answer stands alone.
    #expect(lines.filter { $0.hasPrefix("keys") }.count == moves.count)
    for (index, line) in lines.enumerated() where line.hasPrefix("drag of") { #expect(lines[index + 1].hasPrefix("keys")) }
  }

  @Test func movesArborReactedToAreNeverThinned() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("trace on edges")
    h.system.mouseDown = true
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.heldModifiers = DragDocks.key  // held by whoever means to dock, as Arbor ships
    h.system.events?.dragBegan(a, at: CGPoint(x: 100, y: 400))
    // In and out of the band along the screen's left edge, a millisecond apart: the preview changes every time.
    let xs: [CGFloat] = [100, 3, 100, 3, 100, 3]
    for x in xs {
      h.scheduler.advance(by: 0.001)
      h.system.events?.dragMoved(a, to: CGPoint(x: x, y: 400))
    }
    h.system.events?.dragEnded(a, at: CGPoint(x: 3, y: 400))
    h.run("trace off")
    let lines = recordedTrace(h).entries.map(\.line)
    #expect(lines.filter { if case .dragMoved = $0 { true } else { false } }.count == xs.count)
    #expect(lines.filter { if case .showDropPreview = $0 { true } else { false } }.count == xs.count + 1)
  }

  @Test func onlyMovesOfTheWindowBeingDraggedAreThinned() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("trace on others")
    h.system.events?.dragBegan(a, at: CGPoint(x: 700, y: 210))
    for step in 1...10 {
      h.scheduler.advance(by: 0.001)
      h.system.userMove(b, to: CGRect(x: 10 + CGFloat(step), y: 100, width: 300, height: 300))
    }
    // A change of something other than the frame is news, even for the window being dragged.
    var minimized = h.system.windows[a]!.snapshot
    minimized.isMinimized = true
    h.system.events?.windowChanged(minimized, userInitiated: true)
    h.system.events?.windowChanged(minimized, userInitiated: true)
    h.run("trace off")
    let changes = recordedTrace(h).entries.filter { if case .changed = $0.line { true } else { false } }
    #expect(changes.filter { $0.line.window == b }.count == 10)
    #expect(changes.filter { $0.line.window == a }.count == 2)
  }

  // MARK: Limits and failures

  @Test func aTraceStopsByItselfAtItsSizeLimitAndSaysSo() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.recorder.limits.bytes = 3 * 1024 * 1024 / 1024  // 3 KB, written so that the message's arithmetic shows.
    h.run("trace on big")
    for step in 0..<200 where h.recorder.isRecording {
      h.system.userMove(a, to: CGRect(x: CGFloat(step), y: 100, width: 300, height: 300))
    }
    #expect(!h.recorder.isRecording)
    let text = h.lastTrace ?? ""
    #expect(text.utf8.count < 3 * 1024 + 400)
    guard case .end(let reason, _, _)? = recordedTrace(h).entries.last?.line else {
      Issue.record("the trace has no last line")
      return
    }
    #expect(reason == "stopped by itself at 0 MB")
    #expect(h.run("trace status").message.contains("stopped by itself"))
    // Arbor carries on, and another trace can be started.
    #expect(h.run("dock \(a.rawValue) left").ok)
    #expect(h.run("trace on next").ok)
  }

  @Test func aTraceStopsByItselfAfterTenMinutes() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("trace on long")
    h.scheduler.advance(by: 599)
    h.system.userFocus(a)
    #expect(h.recorder.isRecording)
    h.scheduler.advance(by: 2)
    h.system.userFocus(a)
    #expect(!h.recorder.isRecording)
    #expect(endReason(recordedTrace(h).entries) == "stopped by itself after 10 minutes")
    #expect(h.run("trace status").message.hasSuffix("stopped by itself after 10 minutes"))
  }

  /// Scenario 45 waits ten minutes and then runs a command. The trace used to end right after the command's own line, and the replay
  /// found Arbor doing what the trace did not hold.
  @Test func aTraceThatReachesALimitFinishesTheReactionItIsIn() throws {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    _ = h.system.open(app: "Notes")
    h.start()
    h.run("trace on long")
    h.scheduler.advance(by: 601)
    #expect(h.recorder.isRecording, "nothing has happened since")
    h.run("dock \(a.rawValue) left")
    #expect(!h.recorder.isRecording)
    let entries = recordedTrace(h).entries
    #expect(endReason(entries) == "stopped by itself after 10 minutes")
    let kinds = entries.suffix(3).map(\.line)
    guard case .done(_, true, _) = kinds[1] else {
      Issue.record("the line before the last is \(kinds[1].description), not the command's result")
      return
    }
    #expect(entries.contains { if case .setFrame(a, _, _, _) = $0.line { true } else { false } })
    let report = TraceReplayer(recordedTrace(h), mode: .strict).run()
    #expect(report.problems == [])
  }

  @Test func aTraceThatCannotBeWrittenStopsAndArborCarriesOn() {
    struct DiskFull: Error {}
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("trace on full")
    (h.recorder.sink as? MemoryTraceSink)?.failure = DiskFull()
    #expect(h.run("dock \(a.rawValue) left").ok)
    #expect(h.workspace.isDocked(a))
    #expect(!h.recorder.isRecording)
    #expect(h.run("trace status").message.contains("could not be written"))

    h.recorder.openSink = { _ in throw DiskFull() }
    let result = h.run("trace on again")
    #expect(!result.ok)
    #expect(result.message.contains("could not start the trace"))
    #expect(!h.recorder.isRecording)
  }

  @Test func theFileSinkWritesLinesAsTheyComeIntoAPrivateFile() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-trace-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: folder) }
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    h.recorder.openSink = { try FileTraceSink(url: folder.appendingPathComponent("traces").appendingPathComponent($0)) }
    let on = h.run("trace on file")
    let url = folder.appendingPathComponent("traces/2026-05-09-061320-file.jsonl")
    #expect(on.message.contains(url.path))
    h.run("dock \(a.rawValue) left")
    // Before the trace is closed: a crash must not cost what was recorded.
    let soFar = try Trace(contentsOf: url).entries
    #expect(soFar.contains { if case .done = $0.line { true } else { false } })
    h.run("trace off")
    let trace = try Trace(contentsOf: url)
    #expect(trace.entries.count == soFar.count + 1)
    #expect(trace.header.name == "file")
    let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
  }

  // MARK: The decorators pass everything on

  static let emptyHeader = TraceHeader(
    name: "x", arbor: "x", os: "x", recorded: "", displays: [TraceDisplay(FakeWindowSystem.standardDisplay)], windows: [],
    settings: Settings(), workspaces: [:], focused: nil, cursor: .zero, mouseDown: false, thinning: 0.05)

  @Test(arguments: [false, true])
  func theWindowSystemDecoratorForwardsEveryCallAndEvent(recording: Bool) throws {
    let recorder = TraceRecorder()
    recorder.openSink = { MemoryTraceSink(location: $0) }
    let spy = SpyWindowSystem()
    let listener = SpyEvents()
    let system = RecordingWindowSystem(wrapping: spy, recorder: recorder)
    system.events = listener
    if recording { try recorder.begin(name: "spy", fileName: "spy") { _ in Self.emptyHeader } }

    let id = WindowID(5)
    let frame = CGRect(x: 1, y: 2, width: 3, height: 4)
    system.start()
    #expect(system.allWindows() == spy.allWindows())
    #expect(system.displays() == spy.displays())
    #expect(system.setFrame(frame, of: id) == frame)
    system.focus(id)
    #expect(system.focusedWindow() == WindowID(42))
    #expect(system.cursorLocation() == CGPoint(x: 7, y: 8))
    #expect(system.isMouseButtonDown())
    #expect(system.existingWindowIDs() == [WindowID(5), WindowID(77)])
    // JSON has no infinity; what the controller is told must not depend on whether a trace is being recorded.
    #expect(system.inputActivity() == InputActivity(pointerIdle: 0.25, keyboardIdle: .infinity, keyPresses: 9))
    #expect(!system.isHolding(KeyChord([.control, .option], .space)))
    #expect(spy.calls.last == "isHolding ctrl+opt+space")
    #expect(system.secondsSinceClickOrModifierKey() == 0.125)
    spy.secondsSinceInput = .infinity  // no infinity in JSON here either
    #expect(system.secondsSinceClickOrModifierKey() == .infinity)
    system.raise(id)
    #expect(spy.calls.last == "raise w5")
    system.moveTogether([(id, frame)])
    #expect(spy.calls.last == "moveTogether w5")
    #expect(system.windowsFrontToBack() == [WindowID(77), WindowID(5)])
    #expect(system.macTiling() == MacTiling(screenEdges: true, menuBar: false, optionKey: true))
    system.setMinimized(id, true)
    #expect(spy.calls.last == "setMinimized w5 true")
    system.unhideApp(pid: 9)
    #expect(spy.calls.last == "unhideApp 9")
    #expect(spy.calls.prefix(2) == ["start", "allWindows"])
    #expect(spy.calls.contains("setFrame w5 1,2 3×4"))
    #expect(spy.calls.contains("focus w5"))

    let snapshot = spy.allWindows()[0]
    let point = CGPoint(x: 9, y: 10)
    let events = try #require(spy.events)
    events.windowAppeared(snapshot)
    events.windowChanged(snapshot, userInitiated: true)
    events.windowChanged(snapshot, userInitiated: false)
    events.windowFocused(id)
    events.dragBegan(id, at: point)
    events.dragMoved(id, to: point)
    events.dragEnded(id, at: point)
    events.resizeBegan(id)
    events.resizeEnded(id)
    events.displaysChanged()
    events.keyboardFocusMoved()
    events.dragCancelled(id)
    events.windowReplaced(WindowID(4), by: snapshot)
    events.windowFound(snapshot)
    events.doubleClickReached(id)
    events.applicationActivated(FrontmostApp(bundleID: nil, name: "a.out"))
    events.applicationActivated(nil)
    events.windowDestroyed(id)
    #expect(
      listener.heard == [
        "appeared w5", "changed w5 true", "changed w5 false", "focused w5", "dragBegan w5 9,10", "dragMoved w5 9,10",
        "dragEnded w5 9,10", "resizeBegan w5", "resizeEnded w5", "displaysChanged", "keyboardFocusMoved", "dragCancelled w5",
        "windowReplaced w4 w5", "found w5", "doubleClickReached w5", "activated a.out", "activated nobody", "destroyed w5",
      ])
    system.stop()
    #expect(spy.calls.last == "stop")
    #expect(!recorder.isRecording)
  }

  @Test(arguments: [false, true])
  func theOverlayAndSchedulerDecoratorsForwardEverything(recording: Bool) throws {
    let recorder = TraceRecorder()
    recorder.openSink = { MemoryTraceSink(location: $0) }
    if recording { try recorder.begin(name: "spy", fileName: "spy") { _ in Self.emptyHeader } }
    let fake = FakeOverlays()
    let overlays = RecordingOverlays(wrapping: fake, recorder: recorder)
    let frame = CGRect(x: 1, y: 2, width: 3, height: 4)
    overlays.showDropPreview(frame)
    #expect(fake.preview == frame)
    overlays.update(display: DisplayID("main"), scene: OverlayScene())
    #expect(fake.scenes[DisplayID("main")] == OverlayScene())
    overlays.removeAll()
    #expect(fake.scenes.isEmpty && fake.preview == nil)

    let manual = ManualScheduler()
    let scheduler = RecordingScheduler(wrapping: manual, recorder: recorder)
    var ran: [String] = []
    scheduler.schedule("a", after: 1) { ran.append("a") }
    scheduler.schedule("b", after: 2) { ran.append("b") }
    scheduler.schedule("c", after: 3) { ran.append("c") }
    scheduler.cancel("b")
    #expect(manual.pendingKeys == ["a", "c"])
    manual.advance(by: 1.5)
    #expect(ran == ["a"])
    manual.runPending()
    #expect(ran == ["a", "c"])
  }

  @Test(arguments: [false, true])
  func requirementsWithoutALineOfTheirOwnAreForwardedAndRecordedInOneLine(recording: Bool) throws {
    struct Activity: Codable, Equatable {
      var keys: Double
      var last: String
    }
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    recorder.clock = { 0 }
    recorder.openSink = { _ in sink }
    if recording { try recorder.begin(name: "other", fileName: "other") { _ in Self.emptyHeader } }
    var did: [String] = []
    var argumentsBuilt = 0
    func arguments(_ values: [any Encodable]) -> [any Encodable] {
      argumentsBuilt += 1
      return values
    }

    recorder.call("raise", arguments([WindowID(7)])) { did.append("raise") }
    // Not inside #expect, which works its arguments out ahead of the call.
    let launched = recorder.call("launchApp", arguments(["Safari"]), returning: {
      did.append("launch")
      return true
    })
    #expect(launched)
    #expect(recorder.read("inputActivity") { Activity(keys: 1.5, last: "pointer") } == Activity(keys: 1.5, last: "pointer"))
    #expect(recorder.read("frontmost") { WindowID?.none } == nil)
    recorder.event("dragCancelled", arguments([WindowID(7)])) {
      did.append("cancelled")
      recorder.call("raise", [WindowID(8)]) { did.append("raise again") }
    }
    recorder.action("cheatSheetDismissed") { did.append("dismissed") }

    #expect(did == ["raise", "launch", "cancelled", "raise again", "dismissed"])
    // While nothing is recorded the arguments are not even put together.
    #expect(argumentsBuilt == (recording ? 3 : 0))
    #expect(
      Array(sink.lines.dropFirst()) == (recording
        ? [
          #"{"t":0.0000,"args":[7],"call":"raise"}"#, #"{"t":0.0000,"args":["Safari"],"call":"launchApp","result":true}"#,
          #"{"t":0.0000,"read":"inputActivity","result":{"keys":1.5,"last":"pointer"}}"#, #"{"t":0.0000,"read":"frontmost","result":null}"#,
          #"{"t":0.0000,"args":[7],"event":"dragCancelled"}"#, #"{"t":0.0000,"args":[8],"call":"raise"}"#,
          #"{"t":0.0000,"action":"cheatSheetDismissed"}"#,
        ] : []))
  }

  @Test func titlesInCommandsRepliesRemarksAndArgumentsAreReplacedToo() {
    let h = Harness()
    let a = h.system.open(app: "Pages", title: "Salary review 2026.docx")
    h.system.open(app: "Calculator", title: "Calculator")
    h.start()
    h.run("trace on scrub")
    h.run("trace note about to move Salary review 2026.docx beside Calculator")
    h.recorder.stimulus(.command("layout Pages~Salary review 2026.docx")) {}
    h.recorder.record(.done("layout Pages~Salary review 2026.docx", ok: false, message: "no window called Salary review 2026.docx"))
    h.recorder.call("showHeadsUp", [["text": "Salary review 2026.docx docked", "window": "\(a)"]]) {}
    _ = h.recorder.read("frontmostTitle") { "Salary review 2026.docx" }
    h.run("trace off")
    let text = h.lastTrace ?? ""
    #expect(!text.contains("Salary"))
    let lines = recordedTrace(h).entries.map(\.line)
    // A window named after its app gives nothing away, and replies that name the app must stay readable.
    #expect(lines.contains(.note("about to move title[1] beside Calculator")))
    // This text cannot be read as a command, so of the command only the verb is written (`CanaryTests`). The reply keeps its tokens.
    #expect(lines.contains(.command("layout …")))
    #expect(lines.contains(.done("layout …", ok: false, message: TraceLine.aboutMark + "no window called title[1]")))
    #expect(lines.contains(.other(.call, "showHeadsUp", arguments: [.object(["text": .string("title[1] docked"), "window": .string("\(a)")])])))
    #expect(lines.contains(.other(.read, "frontmostTitle", result: .string("title[1]"))))
  }

  @Test func aStimulusThatArrivesWhileArborIsReactingToAnotherIsMarkedAsNested() throws {
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    recorder.clock = { 0 }
    recorder.openSink = { _ in sink }
    try recorder.begin(name: "nest", fileName: "nest") { _ in Self.emptyHeader }
    recorder.stimulus(.command("home")) {
      recorder.record(.focus(WindowID(1)))
      recorder.stimulus(.focused(WindowID(1))) { recorder.record(.focus(WindowID(2))) }
    }
    recorder.stimulus(.focused(WindowID(3))) {}
    #expect(
      sink.lines.dropFirst() == [
        #"{"t":0.0000,"command":"home"}"#, #"{"t":0.0000,"call":"focus","id":1}"#,
        #"{"t":0.0000,"nested":true,"event":"focused","id":1}"#, #"{"t":0.0000,"call":"focus","id":2}"#,
        #"{"t":0.0000,"event":"focused","id":3}"#,
      ])
  }
}

// MARK: Reading files

@Suite struct TraceFileTests {
  private let header = #"{"trace":1,"displays":[{"id":"main","frame":[0,0,1440,900],"visible":[0,25,1440,875],"main":true}]}"#

  @Test func remarksAndBlankLinesAreSkippedAndLineNumbersAreThoseOfTheFile() throws {
    let trace = try Trace(
      text: """
        # Safari posts "moved" only when the drag ends.

        \(header)
        # The drop:
        {"t":0.5,"event":"focused","id":7}

        {"t":1,"note":"done"}
        """)
    #expect(trace.entries.map(\.number) == [5, 7])
    #expect(trace.entries.map(\.line) == [.focused(WindowID(7)), .note("done")])
    #expect(trace.warnings.isEmpty)
  }

  @Test func aLastLineThatIsCutOffIsDroppedWithAWarning() throws {
    let trace = try Trace(text: header + "\n" + #"{"t":0.5,"event":"focused","id":7}"# + "\n" + #"{"t":0.6,"event":"chan"#)
    #expect(trace.entries.count == 1)
    #expect(trace.warnings == ["line 3: the last line is cut off and was dropped"])
  }

  @Test func aBrokenLineInTheMiddleIsAnErrorThatNamesTheLine() {
    let text = header + "\n" + #"{"t":0.5,"event":"focused"}"# + "\n" + #"{"t":1,"note":"done"}"# + "\n"
    #expect(throws: Trace.ParseError(line: 2, reason: "`id` is missing")) { try Trace(text: text) }
  }

  @Test func whatIsNotATraceIsRefusedWithAReason() {
    #expect(throws: Trace.ParseError(line: 1, reason: "the file is empty")) { try Trace(text: "\n\n") }
    #expect(throws: Trace.ParseError(line: 1, reason: "not a trace header: `trace` is missing")) {
      try Trace(text: #"{"t":0.5,"event":"focused","id":7}"#)
    }
    #expect(throws: Trace.ParseError(line: 1, reason: "the header lists no display")) {
      try Trace(text: #"{"trace":1,"displays":[]}"#)
    }
    #expect(throws: Trace.ParseError(line: 1, reason: "format 99 is newer than this Arbor reads (1)")) {
      try Trace(text: header.replacingOccurrences(of: #""trace":1"#, with: #""trace":99"#))
    }
  }

  @Test func linesThatSayNothingAboutTheirKindAreReadWithAWarning() throws {
    let trace = try Trace(text: header + "\n" + #"{"t":0.5,"gesture":"pinch"}"# + "\n" + #"{"t":0.6,"event":"levitated","args":[7]}"# + "\n" + #"{"t":1,"note":"done"}"#)
    #expect(trace.entries.count == 3)
    #expect(trace.warnings == ["line 2: skipped unknown line"])
  }

  @Test func aTraceWrittenAgainIsTheSameText() throws {
    let lines = [#"{"t":0.5000,"event":"focused","id":7}"#, #"{"t":12.0312,"nested":true,"command":"dock 7 left"}"#]
    let trace = try Trace(text: ([header] + lines).joined(separator: "\n"))
    let written = try trace.text().split(separator: "\n").map(String.init)
    #expect(Array(written.dropFirst()) == lines)
    #expect(try Trace(text: written.joined(separator: "\n")).header == trace.header)
  }
}

// MARK: Spies

@MainActor
final class SpyWindowSystem: WindowSystem {
  weak var events: (any WindowSystemEvents)?
  var calls: [String] = []
  var onSetFrame: () -> Void = {}
  var secondsSinceInput = 0.125

  func start() { calls.append("start") }
  func stop() { calls.append("stop") }
  func allWindows() -> [WindowSnapshot] {
    calls.append("allWindows")
    return [
      WindowSnapshot(
        id: WindowID(5), pid: 1, bundleID: "a.b", appName: "A", title: "T", frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    ]
  }
  func displays() -> [DisplaySnapshot] {
    calls.append("displays")
    return [FakeWindowSystem.standardDisplay]
  }
  func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? {
    calls.append("setFrame \(window) \(traceText(frame))")
    onSetFrame()
    return frame
  }
  func focus(_ window: WindowID) { calls.append("focus \(window)") }
  func focusedWindow() -> WindowID? { WindowID(42) }
  func cursorLocation() -> CGPoint { CGPoint(x: 7, y: 8) }
  func isMouseButtonDown() -> Bool { true }
  func existingWindowIDs() -> Set<WindowID> { [WindowID(5), WindowID(77)] }
  func inputActivity() -> InputActivity { InputActivity(pointerIdle: 0.25, keyboardIdle: .infinity, keyPresses: 9) }
  func raise(_ window: WindowID) { calls.append("raise \(window)") }
  func setMinimized(_ window: WindowID, _ minimized: Bool) { calls.append("setMinimized \(window) \(minimized)") }
  func unhideApp(pid: Int32) { calls.append("unhideApp \(pid)") }
  func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) {
    calls.append("moveTogether " + frames.map { "\($0.window)" }.joined(separator: " "))
  }
  func windowsFrontToBack() -> [WindowID] { [WindowID(77), WindowID(5)] }
  func stackedWindows() -> [StackedWindow] { [] }
  func modifierKeysDown() -> KeyChord.Modifiers { [.command] }
  func macTiling() -> MacTiling { MacTiling(screenEdges: true, menuBar: false, optionKey: true) }
  func whereabouts(of window: WindowID) -> Whereabouts { window == WindowID(5) ? .inTheDockOrGone : .here }
  func openApplication(_ app: String) -> Bool {
    calls.append("openApplication \(app)")
    return true
  }
  func launchApp(_ name: String) -> Bool {
    calls.append("launchApp \(name)")
    return true
  }
  func isHolding(_ chord: KeyChord) -> Bool {
    calls.append("isHolding \(chord.text)")
    return false
  }
  func secondsSinceClickOrModifierKey() -> Double { secondsSinceInput }
}

@MainActor
final class SpyEvents: WindowSystemEvents {
  var heard: [String] = []
  func windowAppeared(_ window: WindowSnapshot) { heard.append("appeared \(window.id)") }
  func windowDestroyed(_ id: WindowID) { heard.append("destroyed \(id)") }
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) { heard.append("changed \(window.id) \(userInitiated)") }
  func windowFocused(_ id: WindowID) { heard.append("focused \(id)") }
  func dragBegan(_ id: WindowID, at point: CGPoint) { heard.append("dragBegan \(id) \(traceText(point))") }
  func dragMoved(_ id: WindowID, to point: CGPoint) { heard.append("dragMoved \(id) \(traceText(point))") }
  func dragEnded(_ id: WindowID, at point: CGPoint) { heard.append("dragEnded \(id) \(traceText(point))") }
  func displaysChanged() { heard.append("displaysChanged") }
  func resizeBegan(_ id: WindowID) { heard.append("resizeBegan \(id)") }
  func resizeEnded(_ id: WindowID) { heard.append("resizeEnded \(id)") }
  func keyboardFocusMoved() { heard.append("keyboardFocusMoved") }
  func dragCancelled(_ id: WindowID) { heard.append("dragCancelled \(id)") }
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) { heard.append("windowReplaced \(old) \(window.id)") }
  func windowFound(_ window: WindowSnapshot) { heard.append("found \(window.id)") }
  func applicationActivated(_ app: FrontmostApp?) { heard.append("activated \(app?.name ?? "nobody")") }
  func pointerPressed() { heard.append("pointerPressed") }
  func doubleClickReached(_ window: WindowID) { heard.append("doubleClickReached \(window)") }
}
