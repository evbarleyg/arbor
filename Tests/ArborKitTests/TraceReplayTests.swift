import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Records `body` on a fresh harness, after `before` has set the scene.
@MainActor
private func record(
  settings: Settings = Settings(), displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
  before: (Harness) -> Void = { _ in }, _ body: (Harness) -> Void
) -> (trace: Trace, original: Harness) {
  let h = Harness(displays: displays, settings: settings)
  h.start()
  before(h)
  h.scheduler.advance(by: 1)
  h.run("trace on test")
  body(h)
  h.run("trace off")
  return (recordedTrace(h), h)
}

/// The replayed world ended up exactly as the recorded one did.
@MainActor
private func expectSameOutcome(
  _ replayer: TraceReplayer, _ original: Harness, sourceLocation: SourceLocation = #_sourceLocation
) {
  let replayed = replayer.harness
  #expect(replayed.controller.workspaces == original.controller.workspaces, sourceLocation: sourceLocation)
  #expect(replayed.controller.parked == original.controller.parked, sourceLocation: sourceLocation)
  #expect(replayed.system.windows.keys.sorted() == original.system.windows.keys.sorted(), sourceLocation: sourceLocation)
  for id in original.system.windows.keys.sorted() {
    #expect(replayed.frame(id) == original.frame(id), "\(id)", sourceLocation: sourceLocation)
  }
  #expect(replayed.ascii() == original.ascii(), sourceLocation: sourceLocation)
  // Tiles, gap handles, the focus ring: everything Arbor draws at rest. The ring's pulse is a counter that means nothing
  // beyond changing, and a trace started in the middle of a session starts counting afresh.
  func scenes(_ h: Harness) -> [DisplayID: OverlayScene] {
    h.overlays.scenes.mapValues { scene in
      var scene = scene
      scene.focusRing?.pulse = 0
      return scene
    }
  }
  #expect(scenes(replayed) == scenes(original), sourceLocation: sourceLocation)
}

/// `trace` with the line at `number` (as in the file) replaced, or removed when `line` is nil.
private func edited(_ trace: Trace, line number: Int, _ change: (TraceLine) -> TraceLine?) -> Trace {
  var trace = trace
  guard let index = trace.entries.firstIndex(where: { $0.number == number }) else { return trace }
  if let line = change(trace.entries[index].line) {
    trace.entries[index].line = line
  } else {
    trace.entries.remove(at: index)
  }
  return trace
}

private func firstLine(_ trace: Trace, where matches: (TraceLine) -> Bool) -> Int {
  trace.entries.first { matches($0.line) }?.number ?? -1
}

private let second = DisplaySnapshot(
  id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

@MainActor
@Suite struct TraceReplayTests {
  // MARK: Round trips

  /// A bit of everything a person does in a session.
  private func busySession(_ h: Harness) {
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    let c = h.system.open(app: "Xcode", minimumSize: CGSize(width: 900, height: 600))
    let d = h.system.open(app: "Calculator", frame: CGRect(x: 500, y: 300, width: 230, height: 408))
    h.system.setMinimumSize(d, CGSize(width: 230, height: 408))
    h.system.setMaximumSize(d, CGSize(width: 230, height: 408))
    h.scheduler.advance(by: 0.6)
    h.system.userFocus(a)
    h.run("dock left")
    h.scheduler.advance(by: 0.2)
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.scheduler.advance(by: 1)
    h.run("state")
    h.system.cursor = CGPoint(x: 100, y: 400)
    h.run("in")
    h.run("back")
    h.run("zoom \(b.rawValue)")
    h.scheduler.advance(by: 0.7)
    h.system.userFocus(a)  // ⌘Tab to a window out of view.
    h.run("show-all")
    if let tile = h.overlays.tiles[h.display]?.first { h.overlays.clickTile(tile.node) }
    h.run("show-all")
    h.scheduler.advance(by: 0.3)
    h.system.drag(d, through: [CGPoint(x: 615, y: 310), CGPoint(x: 400, y: 500), CGPoint(x: 200, y: 870)])
    h.scheduler.advance(by: 0.3)
    var wider = h.frame(a)!
    wider.size.width += 80
    h.system.userResize(a, to: wider, release: false)
    h.scheduler.advance(by: 0.3)
    wider.size.width += 20
    h.system.userResize(a, to: wider)
    h.scheduler.advance(by: 0.6)
    if let seam = h.overlays.seams[h.display]?.first {
      h.overlays.dragSeam(seam, by: -15)
      h.overlays.dragSeam(seam, by: -15)
    }
    h.system.setMinimized(b, true)
    h.scheduler.advance(by: 0.6)
    h.system.setMinimized(b, false)
    h.system.userMove(a, to: CGRect(x: 40, y: 60, width: 500, height: 400))  // Another tool moves a docked window.
    h.scheduler.advance(by: 0.3)
    h.system.setHidden(pid: 1000, true)
    h.system.setHidden(pid: 1000, false)
    h.run("save-view 1")
    h.run("desktop")
    h.run("view 1")
    h.run("resize \(a.rawValue) right -40")
    h.run("float \(a.rawValue)")
    h.run("arrange")
    h.run("exclude com.example.notes")
    h.run("include com.example.notes")
    h.run("dock 12345 left")
    h.system.close(c)
    h.scheduler.advance(by: 1)
    h.run("float-all")
    h.scheduler.advance(by: 1)
  }

  @Test func aRecordedSessionReplaysStrictlyWithoutADivergence() {
    let (trace, original) = record { busySession($0) }
    #expect(trace.entries.count > 150)
    let replayer = TraceReplayer(trace, mode: .strict)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(report.answeredByModel == 0)
    #expect(report.answeredFromTrace > 40)
    expectSameOutcome(replayer, original)
  }

  /// Found by replaying scenario 25 in a second process: with a framed window and its guest both under the pointer, which of them
  /// got the keyboard depended on the order of a dictionary, which differs from launch to launch. A replay is another launch.
  @Test func whichWindowGetsTheKeyboardDoesNotDependOnTheOrderOfADictionary() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    _ = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    h.start()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    // Enough of them that an arbitrary pick is seldom the right one, and never four times.
    let place = CGRect(x: 400, y: 200, width: 500, height: 400)
    let guests = (0..<5).map { _ in h.system.open(app: "Safari", pid: 11, frame: place) }
    h.system.cursor = CGPoint(x: place.midX, y: place.midY)
    for guest in guests.prefix(4) {
      h.system.userFocus(guest)
      h.run("neighbor right")
      #expect(h.system.focused.map { !guests.contains($0) } == true)
      h.run("back")
      #expect(h.system.focused == guest)
    }
  }

  /// F51 and F56: a key that is held is more than the command it is bound to, and the same command means another display
  /// from a shortcut than from a script. Both came in beside `perform(_:)`, where a trace did not see them at first.
  @Test func shortcutsHeldAndTheSourcesOfCommandsAreReplayed() throws {
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    var windows: [WindowID] = []
    let (trace, original) = record(displays: [FakeWindowSystem.standardDisplay, second]) { h in
      windows = ["Safari", "Notes", "Mail"].map { h.system.open(app: $0) }
      h.run("dock \(windows[0].rawValue) left")
      h.run("dock \(windows[1].rawValue) right")
      h.run("zoom \(windows[0].rawValue)")
      // Held, moved over the other window, let go.
      h.keyDown("ctrl+opt+space")
      h.scheduler.advance(by: 0.4)
      h.system.cursor = CGPoint(x: 1200, y: 400)
      h.scheduler.advance(by: 0.1)
      h.keyUp("ctrl+opt+space")
      // Held, and the outline clicked.
      h.keyDown("ctrl+opt+space")
      h.scheduler.advance(by: 0.4)
      h.overlays.clickOutline()
      h.keyUp("ctrl+opt+space")
      // Held, and a script's command comes between.
      h.keyDown("ctrl+opt+space")
      h.scheduler.advance(by: 0.4)
      h.run("desktop", from: .script)
      h.keyUp("ctrl+opt+space")
      // The pointer is on the second display and the keyboard on the first.
      h.system.userFocus(windows[0])
      h.system.type()
      h.system.cursor = CGPoint(x: 2000, y: 500)
      h.scheduler.advance(by: 5)
      h.press("show-all")
      h.run("show-all", from: .gesture)
    }
    let lines = trace.entries.map(\.line)
    #expect(lines.contains(.command("desktop", from: .script)))
    #expect(lines.contains(.command("show-all", from: .shortcut)))
    #expect(lines.contains(.command("show-all", from: .gesture)))
    #expect(lines.contains { if case .other(.event, "shortcut", _, _) = $0 { true } else { false } })
    #expect(lines.contains { if case .other(.action, "peekOutlineClicked", _, _) = $0 { true } else { false } })
    #expect(lines.contains { if case .other(.read, "isHolding", _, _) = $0 { true } else { false } })
    #expect(lines.contains { if case .other(.read, "inputActivity", _, _) = $0 { true } else { false } })
    let replayer = TraceReplayer(try Trace(text: try trace.text()), mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  /// F58. That a camera went on reaches the controller from the app, not through a protocol; and whether a change of app was
  /// the user's own doing is a question of time that only the recording can answer.
  @Test func aCallIsReplayed() throws {
    var windows: [WindowID] = []
    var settings = Settings()
    settings.holdStillWhileCameraIsOn = true  // it ships off
    let (trace, original) = record(settings: settings) { h in
      windows = ["Keynote", "Mail", "Slack"].map { h.system.open(app: $0) }
      h.run("dock \(windows[0].rawValue) left")
      h.run("dock \(windows[1].rawValue) right")
      h.run("dock \(windows[2].rawValue) beside \(windows[1].rawValue) bottom")
      h.run("zoom \(windows[0].rawValue)")
      h.system.userFocus(windows[0])
      h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
      h.scheduler.advance(by: 2)
      h.system.comesForward(windows[2])  // by itself: turned away
      h.scheduler.advance(by: 2)
      h.system.userFocus(windows[1])  // ⌘Tab: followed
      h.scheduler.advance(by: 2)
      #expect(h.controller.holdLevel == .still)
      #expect(h.system.isVisible(windows[1]))
    }
    let lines = trace.entries.map(\.line)
    #expect(lines.contains { if case .other(.event, "callSignalsChanged", _, _) = $0 { true } else { false } })
    #expect(lines.contains { if case .other(.read, "secondsSinceClickOrModifierKey", _, _) = $0 { true } else { false } })
    let replayer = TraceReplayer(try Trace(text: try trace.text()), mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.holdLevel == .still)
    expectSameOutcome(replayer, original)
  }

  @Test func theSameSessionReplaysInFreeMode() {
    let (trace, original) = record { busySession($0) }
    let replayer = TraceReplayer(trace, mode: .free)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func aTraceSurvivesBeingWrittenToTextAndReadBack() throws {
    let (trace, original) = record { busySession($0) }
    let replayer = TraceReplayer(try Trace(text: try trace.text()), mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func aTraceStartedInTheMiddleOfASessionIsSelfContained() {
    var ids: [WindowID] = []
    let (trace, original) = record(
      before: { h in
        let a = h.system.open(app: "Safari")
        let b = h.system.open(app: "Notes")
        let c = h.system.open(app: "Xcode", minimumSize: CGSize(width: 900, height: 600))
        let d = h.system.open(app: "Mail")
        let e = h.system.open(app: "Music")
        ids = [a, b, c, d, e]
        h.run("dock \(a.rawValue) left")
        h.run("dock \(b.rawValue) right")
        h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")  // A tile.
        h.system.setMinimized(e, true)
        h.run("save-view 2")
        h.run("zoom \(a.rawValue)")  // Everything else is parked, the floating window too.
      },
      { h in
        h.run("back")
        h.run("view 2")
        h.run("forward")
        h.run("show-all")
        h.system.setMinimized(ids[4], false)
        h.run("dock \(ids[3].rawValue) beside \(ids[0].rawValue) bottom")
        h.scheduler.advance(by: 1)
      })
    #expect(!trace.header.parked.isEmpty)
    let replayer = TraceReplayer(trace, mode: .strict)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(!report.story.contains { $0.hasPrefix("starting up moved") })
    expectSameOutcome(replayer, original)
  }

  @Test func displaysComingAndGoingReplay() {
    var a = WindowID(0)
    let (trace, original) = record(
      displays: [FakeWindowSystem.standardDisplay, second],
      before: { h in
        a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
        let b = h.system.open(app: "Notes")
        h.run("dock \(a.rawValue) left")
        h.run("dock \(b.rawValue) right")
      },
      { h in
        h.system.setDisplays([FakeWindowSystem.standardDisplay])
        h.scheduler.advance(by: 1)
        h.run("dock \(a.rawValue) left")
        h.run("float \(a.rawValue)")
        h.system.setDisplays([FakeWindowSystem.standardDisplay, second])
        h.scheduler.advance(by: 1)
      })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func aTraceRecordedWhileADisplayWasAwayBringsItsWorkspaceBack() {
    var a = WindowID(0)
    let (trace, original) = record(
      displays: [FakeWindowSystem.standardDisplay, second],
      before: { h in
        a = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
        h.run("dock \(a.rawValue) left")
        h.system.setDisplays([FakeWindowSystem.standardDisplay])
      },
      { h in
        h.system.setDisplays([FakeWindowSystem.standardDisplay, second])
        h.scheduler.advance(by: 1)
      })
    #expect(trace.header.dormant[second.id] != nil)
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.workspaces[second.id]?.isDocked(a) == true)
    expectSameOutcome(replayer, original)
  }

  @Test func rulesThatLookAtTitlesReplayThoughTheTitlesAreGone() {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.left)),
      AppRule(app: "com.example.mail", title: "Reminder", action: .ignore),
    ]
    var ids: [WindowID] = []
    let (trace, original) = record(settings: settings) { h in
      ids = [
        h.system.open(app: "Mail", title: "Inbox (3 unread)"), h.system.open(app: "Mail", title: "New message"),
        h.system.open(app: "Mail", title: "Reminder: dentist"),
      ]
      h.run("arrange")
    }
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
    #expect(replayer.harness.controller.filter.ignoredWindowIDs == [ids[2]])
  }

  @Test func windowsAnIgnoreRuleHadMatchedBeforeTheTraceStayIgnored() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.palette", action: .ignore)]
    var palette = WindowID(0)
    let (trace, original) = record(
      settings: settings, before: { palette = $0.system.open(app: "Palette") },
      { h in
        h.system.open(app: "Safari")
        h.run("arrange")
      })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.workspaceID(containing: palette) == nil)
    expectSameOutcome(replayer, original)
  }

  @Test func settingsChangedDuringATraceReplay() {
    var wide = Settings()
    wide.gap = 40
    let (trace, original) = record(
      before: { h in
        let a = h.system.open(app: "Safari")
        h.run("dock \(a.rawValue) left")
      },
      { h in
        h.controller.loadSettings = { wide }
        h.run("reload-settings")
        var wider = wide
        wider.gap = 60
        h.controller.apply(settings: wider)
      })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.settings.gap == 60)
    expectSameOutcome(replayer, original)
  }

  @Test func onlyTheProcessesArborWasLimitedToAreArranged() {
    let h = Harness()
    h.controller.filter.onlyPIDs = [7]
    let mine = h.system.open(app: "Test", pid: 7)
    let other = h.system.open(app: "Mail", pid: 8)
    h.start()
    h.run("trace on pids")
    h.run("arrange")
    h.run("trace off")
    let replayer = TraceReplayer(recordedTrace(h), mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.workspace.isDocked(mine))
    #expect(replayer.harness.controller.workspaceID(containing: other) == nil)
  }

  @Test func eventsThatArriveFromInsideACallAreDeliveredInsideTheSameCall() {
    // The fake reports that the keyboard moved from within `focus`, so in the middle of the `dock` command.
    let (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
        h.system.userFocus(WindowID(101))
      },
      { $0.run("dock 102 left") })
    let focus = trace.entries.firstIndex { $0.line == .focus(WindowID(102)) } ?? -1
    let moved = trace.entries.firstIndex { $0.line == .keyboardFocusMoved } ?? -1
    let done = trace.entries.firstIndex { if case .done = $0.line { true } else { false } } ?? -1
    #expect(focus >= 0 && focus < moved && moved < done)
    #expect(trace.entries[moved].nested)

    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    // The command and the event, at least.
    #expect(replayer.report.delivered >= 2)
    #expect(replayer.harness.overlays.scenes[replayer.harness.display]?.focusRing?.window == WindowID(102))
    expectSameOutcome(replayer, original)
  }

  @Test func quittingReplays() {
    let (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
        h.run("dock 101 left")
        h.run("zoom 101")
      },
      { h in
        h.run("quit")
        h.controller.shutdown()
      })
    #expect(trace.entries.contains { $0.line == .stop })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(!replayer.harness.controller.isRunning)
    #expect(replayer.harness.frame(WindowID(102)) == original.frame(WindowID(102)))
    #expect(replayer.harness.system.isVisible(WindowID(102)))
  }

  /// Since F12 the app tells the controller that settings.json may have changed, and every command that changes settings reads
  /// the file first. A replay has no file: it finds news where the recording did, and nowhere else.
  @Test func settingsReadFromTheFileAreReplayedWhereTheyWereRead() {
    final class File { var settings = Settings() }
    let file = File()
    let (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
        h.controller.loadSettings = { file.settings }
        h.controller.saveSettings = { _, new in file.settings = new }
      },
      { h in
        h.run("arrange")
        file.settings.gap = 30
        h.controller.settingsFileMayHaveChanged()
        h.scheduler.advance(by: 0.5)
        h.run("exclude com.example.notes")
        h.run("include com.example.notes")
      })
    #expect(original.controller.settings.gap == 30)
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.settings.gap == 30)
    expectSameOutcome(replayer, original)
  }

  /// Where an app opened a window is no place anybody chose, so Arbor may move it onto the Desktop. It remembers that from the
  /// moment the window appeared, which can be before the recording began.
  @Test func whereAppsOpenedTheirWindowsBeforeTheRecordingIsReplayed() {
    let (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
      },
      { h in
        h.run("arrange")
        h.run("exclude com.example.notes")
        h.run("include com.example.notes")
      })
    #expect(trace.header.appPlaced.keys.sorted() == [WindowID(101), WindowID(102)])
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func pausingEndsATraceAndReplays() {
    let (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
        h.run("dock 101 left")
        h.run("zoom 101")
      },
      { $0.run("pause") })
    #expect(!original.recorder.isRecording)
    #expect(trace.entries.last?.line.description.hasPrefix("recording ended: Arbor stopped") == true)
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.controller.isPaused)
    #expect(replayer.harness.frame(WindowID(102)) == original.frame(WindowID(102)))
  }

  // MARK: Strict mode finds what changed

  private func dockingTrace() -> Trace {
    record(before: { h in
      h.system.open(app: "Safari")
      h.system.open(app: "Notes")
    }) { h in
      h.run("dock 101 left")
      h.run("dock 102 right")
      h.scheduler.advance(by: 1)
    }.trace
  }

  @Test func strictModeReportsADifferentFrameWithItsLineAndBothFrames() {
    let trace = dockingTrace()
    // Not the question that comes before it, where the window stood.
    let line = firstLine(trace) { if case .setFrame(_, let frame, _, _) = $0 { frame.origin == CGPoint(x: 12, y: 37) } else { false } }
    let changed = edited(trace, line: line) { _ in
      let old = CGRect(x: 12, y: 37, width: 650, height: 851)
      return .setFrame(WindowID(101), old, result: old, took: nil)
    }
    let report = TraceReplayer(changed, mode: .strict).run()
    #expect(
      report.problems.first
        == TraceReplayer.Problem(
          kind: .divergence, line: line,
          text: "the recording has `setFrame w101 12,37 650×851 (taken)`; Arbor now does `setFrame w101 12,37 702×851`"))
    #expect(report.problems.first?.description.hasPrefix("line \(line): divergence: the recording has") == true)
    #expect(report.story.contains { $0.contains("✘ line \(line)") })
    #expect(TraceReplayer(changed, mode: .free).run().problems == [])
  }

  @Test func strictModeReportsACallArborNoLongerMakes() {
    var trace = dockingTrace()
    let index = trace.entries.firstIndex { $0.line == .focus(WindowID(101)) }!
    var extra = trace.entries[index]
    extra.line = .focus(WindowID(102))
    extra.number = 1000
    trace.entries.insert(extra, at: index + 1)
    let report = TraceReplayer(trace, mode: .strict).run()
    #expect(report.problems.map(\.text) == ["the recording has `focus w102`; Arbor no longer does that here"])
    #expect(report.problems.map(\.line) == [1000])
  }

  @Test func strictModeReportsACallTheRecordingDoesNotHave() {
    let trace = dockingTrace()
    let line = firstLine(trace) { $0 == .focus(WindowID(101)) }
    let report = TraceReplayer(edited(trace, line: line) { _ in nil }, mode: .strict).run()
    #expect(report.problems.map(\.text) == ["Arbor now does `focus w101`; the recording has no such call here"])
  }

  @Test func strictModeReportsCallsInADifferentOrder() {
    var trace = dockingTrace()
    let first = trace.entries.firstIndex { $0.line.window == WindowID(101) && $0.line.isEffect && $0.t > 0 || $0.line == .command("dock 102 right") }!
    // `dock 102 right` moves both windows, lower id first. Swap the two recorded calls.
    let calls = trace.entries.indices.filter { $0 > first && trace.entries[$0].line.description.hasPrefix("setFrame") }
    #expect(calls.count >= 2)
    trace.entries.swapAt(calls[0], calls[1])
    let report = TraceReplayer(trace, mode: .strict).run()
    #expect(report.problems.count == 1)
    #expect(report.problems.first?.text.contains("the other way round") == true)
  }

  @Test func strictModeReportsADifferentCommandResult() {
    let trace = dockingTrace()
    let line = firstLine(trace) { if case .done = $0 { true } else { false } }
    let changed = edited(trace, line: line) { _ in .done("dock 101 left", ok: false, message: "no") }
    let report = TraceReplayer(changed, mode: .strict).run()
    #expect(
      report.problems.map(\.text) == [
        "`dock 101 left` failed with \"no\" in the recording; now it succeeds with \"docked w101 at the left edge\""
      ])
    #expect(report.problems.map(\.line) == [line])
  }

  @Test func strictModeReportsACommandThatNoLongerExists() {
    let trace = dockingTrace()
    let line = firstLine(trace) { $0 == .command("dock 102 right") }
    let report = TraceReplayer(edited(trace, line: line) { _ in .command("teleport 102") }, mode: .strict).run()
    #expect(report.problems.first?.line == line)
    #expect(report.problems.first?.text.hasPrefix("Arbor no longer understands `teleport 102`") == true)
  }

  @Test func strictModeReportsADifferentDropPreview() {
    let (trace, _) = record(before: { $0.system.open(app: "Safari") }) { h in
      h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
      h.system.drag(WindowID(101), through: [CGPoint(x: 620, y: 210), CGPoint(x: 300, y: 300), CGPoint(x: 3, y: 450)])
    }
    #expect(TraceReplayer(trace, mode: .strict).run().problems == [])
    let line = firstLine(trace) { if case .showDropPreview(.some) = $0 { true } else { false } }
    let changed = edited(trace, line: line) { _ in .showDropPreview(CGRect(x: 0, y: 25, width: 720, height: 875)) }
    let report = TraceReplayer(changed, mode: .strict).run()
    #expect(
      report.problems.map(\.text) == [
        "the recording has `showDropPreview 0,25 720×875`; Arbor now does `showDropPreview 12,37 702×851`"
      ])
    let missing = TraceReplayer(edited(trace, line: line) { _ in nil }, mode: .strict).run()
    #expect(missing.problems.map(\.text) == ["the recording changes the drop preview 0 time(s) here, Arbor now 1"])
  }

  @Test func aReplayThatHasLeftTheRailsStopsCounting() {
    var (trace, _) = record { busySession($0) }
    trace.header.settings.gap = 33  // Every frame differs from here on.
    let report = TraceReplayer(trace, mode: .strict).run()
    #expect(report.problems.count == 25)
  }

  // MARK: Answers come from the trace

  private let header =
    #"{"trace":1,"displays":[{"id":"main","frame":[0,0,1440,900],"visible":[0,25,1440,875],"main":true}],"#
    + #""windows":[{"id":7,"pid":70,"bundle":"com.apple.systempreferences","app":"System Settings","title":"title-1","frame":[300,100,715,600]},"#
    + #"{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[200,200,800,500]}]}"#

  @Test func anAppThatRefusedASizeInTheRecordingRefusesItInTheReplay() throws {
    // System Settings is asked to be 348 wide and stays 715: Arbor makes it a tile.
    var trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":1,"call":"setFrame","id":8,"frame":[12,37,702,851],"result":[12,37,702,851]}
        {"t":2,"command":"dock 7 beside 8 right"}
        {"t":2,"call":"setFrame","id":7,"frame":[372,37,348,851],"result":[372,37,715,851],"took":0.021}
        """)
    // As when this was recorded: since F61 Arbor would first make room for it.
    trace.header.settings.makeRoom = false
    let replayer = TraceReplayer(trace)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(replayer.harness.layout?.tiles.contains { $0.windows == [WindowID(7)] } == true)
    #expect(replayer.harness.controller.parked.contains(WindowID(7)))
    #expect(replayer.harness.frame(WindowID(7))?.width == 715)
  }

  @Test func whatTheTraceShowsOfAnAppsLimitsHoldsForRequestsItDoesNotHave() throws {
    // The only recorded request was for 348 points. Any other width below 715 must be refused too, and
    // Calculator-like windows that gave less than was asked must not grow.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"note":"what the apps did when Arbor asked"}
        {"t":1,"call":"setFrame","id":7,"frame":[372,37,348,851],"result":[372,37,715,851]}
        {"t":1,"call":"setFrame","id":8,"frame":[12,37,1000,851],"result":[12,37,800,500]}
        {"t":2,"command":"dock 7 left"}
        {"t":3,"command":"dock 8 right"}
        """)
    let replayer = TraceReplayer(trace)
    let report = replayer.run()
    #expect(report.answeredByModel > 0)
    #expect(replayer.harness.frame(WindowID(7))?.width == 715)
    #expect(replayer.harness.frame(WindowID(8))?.height == 500)
  }

  @Test func anAppThatRoundsToStepsIsNotTakenForOneWithAMinimumSize() throws {
    // Terminal as recorded on a Mac: 681 wide at first; asked for 494 it took 492, asked for 244 it took 247. All three are 2 more than a
    // multiple of 7. Asked for a little less than 244 a real Terminal goes down a character; it has no minimum of 247.
    let trace = try Trace(
      text: """
        {"trace":1,"displays":[{"id":"main","frame":[0,0,1024,768],"visible":[0,31,1024,680],"main":true}],\
        "windows":[{"id":9,"pid":90,"bundle":"com.apple.Terminal","app":"Terminal","title":"title-1","frame":[331,49,681,649]}]}
        {"t":1,"note":"what Terminal did when Arbor asked"}
        {"t":1,"call":"setFrame","id":9,"frame":[12,43,494,655],"result":[12,43,492,649]}
        {"t":1,"call":"setFrame","id":9,"frame":[12,43,244,655],"result":[12,43,247,649]}
        """)
    let replayer = TraceReplayer(trace)
    replayer.run()
    let system = replayer.harness.controller.system
    func width(_ asked: CGFloat) -> CGFloat? { system.setFrame(CGRect(x: 12, y: 43, width: asked, height: 649), of: WindowID(9))?.width }
    #expect(width(238) == 240)
    #expect(width(232) == 233)
    #expect(width(243) == 240)
    #expect(width(600) == 597)
    // What was recorded still comes first.
    #expect(width(244) == 247)
  }

  @Test func anAppWithARealMinimumKeepsItThoughItMissedByLittle() throws {
    // Finder, asked for 494, took 501, and was seen at widths that share no step.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"note":"what the app did when Arbor asked"}
        {"t":1,"call":"setFrame","id":8,"frame":[12,37,494,655],"result":[12,37,501,655]}
        {"t":1,"call":"setFrame","id":8,"frame":[12,37,760,655],"result":[12,37,760,655]}
        """)
    let replayer = TraceReplayer(trace)
    replayer.run()
    let took = replayer.harness.controller.system.setFrame(CGRect(x: 12, y: 37, width: 480, height: 655), of: WindowID(8))
    #expect(took?.width == 501)
  }

  @Test func theSameRequestAtAnotherMomentGetsTheRecordedAnswer() throws {
    // A terminal rounds its size to whole characters. The trace has that answer once, later than the replay asks.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":5,"event":"focused","id":7}
        {"t":5,"call":"setFrame","id":8,"frame":[12,37,702,851],"result":[12,37,700,840]}
        """)
    let replayer = TraceReplayer(trace)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.frame(WindowID(8))?.size == CGSize(width: 700, height: 840))
  }

  @Test func aWindowThatWasGoneWhenArborMovedItIsGoneInTheReplay() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":1,"call":"setFrame","id":8,"frame":[12,37,702,851],"result":null}
        {"t":1.1,"event":"destroyed","id":8}
        """)
    let replayer = TraceReplayer(trace, mode: .strict)
    let report = replayer.run()
    #expect(report.problems.filter { $0.kind == .invariant } == [])
    #expect(replayer.harness.controller.windows[WindowID(8)] == nil)
  }

  @Test func readsAreAnsweredFromTheTrace() throws {
    // The pointer is over the second half of the screen only according to the trace.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":2,"command":"dock 7 right"}
        {"t":3,"command":"in"}
        {"t":3,"call":"cursorLocation","result":[1300,400]}
        {"t":4,"command":"zoom"}
        {"t":4,"call":"focusedWindow","result":8}
        """)
    let replayer = TraceReplayer(trace)
    var cameras: [NodeID] = []
    replayer.harness.controller.observe { change in
      if case .camera = change { cameras.append(replayer.harness.workspace.camera) }
    }
    #expect(replayer.run().problems == [])
    let tree = replayer.harness.workspace.tree
    #expect(cameras.suffix(2) == [tree.leaf(containing: WindowID(7))!, tree.leaf(containing: WindowID(8))!])
  }

  @Test func theMouseButtonIsDownBetweenTheStartAndTheEndOfADrag() throws {
    // Another tool moves a docked window while the user holds a different one. Arbor waits for the button.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":2,"event":"dragBegan","id":7,"point":[600,110]}
        {"t":2.1,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[50,60,500,400]}}
        {"t":4,"note":"still held"}
        {"t":5,"event":"dragEnded","id":7,"point":[1000,110]}
        {"t":6,"note":"released"}
        """)
    let replayer = TraceReplayer(trace)
    var putBackAt: Double?
    replayer.harness.controller.observe { [harness = replayer.harness] _ in
      if putBackAt == nil, harness.scheduler.now > 2.1, harness.frame(WindowID(8))?.minX == 12 {
        putBackAt = harness.scheduler.now
      }
    }
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.frame(WindowID(8)) == CGRect(x: 12, y: 37, width: 702, height: 851))
    #expect((putBackAt ?? 0) >= 5)
  }

  @Test func theMouseButtonIsAlsoKnownFromWhatMacOSSent() throws {
    // A press that never became a drag Arbor knows of: only the raw mouse events say the button is down.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":2,"raw":"leftMouseDown 300,45"}
        {"t":2.1,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[50,60,702,851]}}
        {"t":4,"raw":"leftMouseDragged 340,70.5"}
        {"t":5,"raw":"leftMouseUp 340,70.5"}
        {"t":6,"note":"released"}
        """)
    let replayer = TraceReplayer(trace)
    var putBackAt: Double?
    replayer.harness.controller.observe { [harness = replayer.harness] _ in
      if putBackAt == nil, harness.scheduler.now > 2.1, harness.frame(WindowID(8))?.minX == 12 {
        putBackAt = harness.scheduler.now
      }
    }
    #expect(replayer.run().problems == [])
    #expect((putBackAt ?? 0) >= 5)
    #expect(replayer.harness.system.cursor == CGPoint(x: 340, y: 70.5))
  }

  // MARK: Free mode after Arbor's behaviour has changed

  @Test func echoesOfFramesTheOldArborSetDoNotMoveWindowsTheNewArborPlaced() throws {
    // Recorded with a gap of 12. The echoes carry the frames Arbor set then.
    let recorded = """
      \(header)
      {"t":1,"command":"dock 8 left"}
      {"t":1,"call":"setFrame","id":8,"frame":[12,37,702,851],"result":[12,37,702,851]}
      {"t":1.05,"event":"changed","user":false,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[12,37,702,851]}}
      {"t":1.4,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-3","frame":[12,37,702,851]}}
      {"t":3,"note":"at rest"}
      """
    var trace = try Trace(text: recorded)
    trace.header.settings.gap = 40  // Stands for any change to how Arbor lays windows out.
    let replayer = TraceReplayer(trace)
    let report = replayer.run()
    #expect(report.problems == [])
    let frame = CGRect(x: 40, y: 65, width: 660, height: 795)
    #expect(replayer.harness.frame(WindowID(8)) == frame)
    #expect(replayer.harness.controller.windows[WindowID(8)]?.frame == frame)
    #expect(replayer.harness.controller.windows[WindowID(8)]?.title == "title-3")
    // Placed once. Had the echoes moved it, Arbor would have had to put it back.
    #expect(movesWithoutWaste(replayer.harness, of: WindowID(8)) == 1)
  }

  @Test func movesThatCameFromOutsideArborAreCarriedOver() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[640,300,800,500]}}
        """)
    let replayer = TraceReplayer(trace)
    #expect(replayer.run().problems == [])
    #expect(replayer.harness.frame(WindowID(8)) == CGRect(x: 640, y: 300, width: 800, height: 500))
    #expect(replayer.harness.workspace.floating[WindowID(8)] == CGRect(x: 640, y: 300, width: 800, height: 500))
  }

  @Test func theAnswerToAFocusCallArborNoLongerMakesIsNotDelivered() throws {
    // The recorded Arbor focused w7 after `relayout`; today's does not. Without the call macOS would have had nothing to report.
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"relayout"}
        {"t":1,"call":"focus","id":7}
        {"t":1.02,"event":"focused","id":7}
        {"t":1.02,"call":"focusedWindow","result":7}
        {"t":1.03,"event":"focused","id":7}
        {"t":1.5,"command":"state"}
        {"t":1.5,"call":"focusedWindow","result":7}
        {"t":3,"note":"much later the user clicks it"}
        {"t":3,"event":"focused","id":7}
        """)
    let replayer = TraceReplayer(trace)
    var heard: [Double] = []
    replayer.harness.controller.observe { [harness = replayer.harness] change in
      if change == .focus(WindowID(7)) { heard.append(harness.scheduler.now) }
    }
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(heard == [3])
    #expect(report.story.filter { $0.contains("not delivered: it answered a `focus w7`") }.count == 2)
  }

  @Test func whatTheRecordingSaysAboutTheFocusDoesNotCountWhileItRestsOnACallThatWasNotMade() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":0.5,"event":"focused","id":8}
        {"t":1,"command":"relayout"}
        {"t":1,"call":"focus","id":7}
        {"t":1.5,"command":"dock left"}
        {"t":1.5,"call":"focusedWindow","result":7}
        """)
    let replayer = TraceReplayer(trace)
    #expect(replayer.run().problems == [])
    // `dock left` acts on the focused window, which in the replayed world is still w8.
    #expect(replayer.harness.workspace.isDocked(WindowID(8)))
    #expect(!replayer.harness.workspace.isDocked(WindowID(7)))
  }

  @Test func aFocusCallTheRecordingDoesNotHaveIsAnsweredAsMacOSWould() throws {
    // As if `dock` had learned to focus since the trace was recorded.
    let trace = try Trace(text: header + "\n" + #"{"t":1,"command":"dock 8 left"}"# + "\n" + #"{"t":2,"command":"dock 8 left"}"#)
    let replayer = TraceReplayer(trace)
    var heard: [Double] = []
    replayer.harness.controller.observe { [harness = replayer.harness] change in
      if change == .focus(WindowID(8)) { heard.append(harness.scheduler.now) }
    }
    let report = replayer.run()
    #expect(report.problems == [])
    // Once: the second time the window has the focus already, and macOS says nothing.
    #expect(heard == [1])
    #expect(report.story.contains { $0.contains("macOS would answer the new `focus w8`") })
  }

  // MARK: Scheduled work

  @Test func scheduledWorkRunsWhereTheTraceSaysItRan() {
    // A Space switch reports each window separately and Arbor lays out once afterwards, with a delay of
    // zero. Going by the clock, that work would run between the two reports.
    var ids: [WindowID] = []
    let (trace, original) = record(
      before: { h in
        ids = [h.system.open(app: "Safari"), h.system.open(app: "Notes"), h.system.open(app: "Mail")]
        h.run("arrange")
      },
      { h in
        h.system.setOnActiveSpace(ids[0], false)
        h.scheduler.advance(by: 0)  // Nothing is due yet… except that it is, so this is the order to keep.
        h.system.setOnActiveSpace(ids[1], false)
        h.scheduler.runPending()
      })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func workThatRanLateInTheRecordingRunsLateInTheReplay() {
    var (trace, original) = record(
      before: { h in
        h.system.open(app: "Safari")
        h.system.open(app: "Notes")
        h.run("dock 101 left")
      },
      { h in
        h.system.userMove(WindowID(101), to: CGRect(x: 50, y: 60, width: 500, height: 400))
        h.system.setMinimized(WindowID(101), true)
        h.scheduler.runPending()
      })
    // The put-back was due 0.25 s after the move, but the Mac was busy and the window was minimized first, at
    // 0.3 s. By the clock the put-back would come before that and move the window.
    let minimized = trace.entries.firstIndex { if case .changed(let window, _) = $0.line { window.minimized } else { false } }!
    for index in trace.entries.indices where index >= minimized { trace.entries[index].t = 0.3 }
    #expect(trace.entries.contains { $0.line == .timer("enforce-main") && $0.t == 0.3 })
    let replayer = TraceReplayer(trace, mode: .strict)
    #expect(replayer.run().problems == [])
    expectSameOutcome(replayer, original)
  }

  @Test func workTheTraceDoesNotMentionRunsByTheClock() throws {
    // As if Arbor had gained the put-back since the trace was recorded.
    let trace = try Trace(
      text: """
        \(header)
        {"t":0.5,"command":"dock 8 left"}
        {"t":1,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[50,60,500,400]}}
        {"t":1.2,"note":"not yet"}
        {"t":1.3,"note":"by now"}
        """)
    let replayer = TraceReplayer(trace, verbose: true)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(replayer.harness.frame(WindowID(8)) == CGRect(x: 12, y: 37, width: 702, height: 851))
    let story = report.story
    let ran = story.firstIndex { $0.contains("`enforce-main` runs by the clock") } ?? -1
    #expect(ran > (story.firstIndex { $0.contains("not yet") } ?? .max))
    #expect(ran < (story.firstIndex { $0.contains("by now") } ?? -1))

    let strict = TraceReplayer(trace, mode: .strict).run()
    #expect(strict.problems.contains { $0.text.contains("from scheduled work `enforce-main`, which did not run here") })
  }

  @Test func strictModeMissesScheduledWorkThatDidSomething() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"timer":"save"}
        {"t":2,"timer":"tidy-up"}
        {"t":2,"call":"setFrame","id":8,"frame":[0,25,100,100],"result":[0,25,100,100]}
        """)
    let report = TraceReplayer(trace, mode: .strict).run()
    #expect(report.problems.first?.text == "the recording ran scheduled work `tidy-up` here; Arbor now has none under that name")
    #expect(report.problems.first?.line == 3)
  }

  // MARK: Invariants

  /// A replay of `rounds` put-backs. The real controller gives up a fight after three (F17), so a stand-in schedules the work: at every
  /// `moved` it arms `enforce-main`, which puts the window back when the trace says it ran.
  private func fight(rounds: Int, between: String? = nil) throws -> TraceReplayer {
    var lines = [header]
    for round in 0..<rounds {
      let t = 1 + Double(round) * 0.3
      lines.append(#"{"t":\#(t),"event":"moved"}"#)
      lines.append(#"{"t":\#(t + 0.26),"timer":"enforce-main"}"#)
      if let between { lines.append(#"{"t":\#(t + 0.28),\#(between)}"#) }
    }
    let replayer = TraceReplayer(try Trace(text: lines.joined(separator: "\n")))
    replayer.otherStimuli["moved"] = { [unowned replayer] _ in
      let harness = replayer.harness
      harness.controller.scheduler.schedule("enforce-main", after: 0.25) {
        _ = harness.controller.system.setFrame(CGRect(x: 12, y: 37, width: 702, height: 851), of: WindowID(8))
      }
    }
    return replayer
  }

  @Test func anAppThatKeepsMovingItsWindowIsReportedAsEndlessEnforcement() throws {
    let report = try fight(rounds: 12).run()
    #expect(report.problems.count == 1)
    #expect(report.problems.first?.kind == .invariant)
    #expect(report.problems.first?.text.hasPrefix("endless enforcement: `enforce-main` has put windows back 10 times in a row") == true)
    // The tenth round's timer: two lines a round after the header.
    #expect(report.problems.first?.line == 1 + 10 * 2)
    #expect(try fight(rounds: 9).run().problems == [])
  }

  @Test func puttingWindowsBackNowAndThenIsNotEndless() throws {
    #expect(try fight(rounds: 12, between: #""command":"relayout""#).run().problems == [])
  }

  @Test func askingAWindowAgainAndAgainForAFrameItRefusesIsReported() throws {
    // Stands for a controller that, at every `poke`, asks System Settings for the width it has refused before.
    func replay(_ widths: [CGFloat]) throws -> [TraceReplayer.Problem] {
      var lines = [header, #"{"t":0.5,"call":"setFrame","id":7,"frame":[12,37,348,600],"result":[12,37,715,600]}"#]
      for index in widths.indices { lines.append(#"{"t":\#(index + 1),"event":"poke"}"#) }
      let replayer = TraceReplayer(try Trace(text: lines.joined(separator: "\n")))
      var asked = 0
      replayer.otherStimuli["poke"] = { [unowned replayer] _ in
        _ = replayer.harness.controller.system.setFrame(CGRect(x: 12, y: 37, width: widths[asked], height: 600), of: WindowID(7))
        asked += 1
      }
      return replayer.run().problems
    }
    let problems = try replay([348, 348, 348, 348, 348, 348, 348])
    #expect(problems.map(\.kind) == [.invariant])
    #expect(problems.first?.text == "asking in vain: w7 was asked for 12,37 348×600 5 times in a row and took 12,37 715×600 every time")
    #expect(problems.first?.line == 7)
    // Four times is trying; another request, or one the window takes, starts the count afresh.
    #expect(try replay([348, 348, 348, 348]) == [])
    #expect(try replay([348, 348, 348, 348, 400, 348, 348, 348, 348]) == [])
    #expect(try replay([348, 348, 348, 348, 800, 348, 348, 348, 348]) == [])
  }

  @Test func aDockedWindowLeftWhereArborDidNotPutItIsReported() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(ReplayInvariants.always(h) == [])
    #expect(ReplayInvariants.atRest(h, placed: [:]) == [])

    let slot = h.frame(a)!
    h.system.place(a, at: CGRect(x: 100, y: 100, width: 300, height: 300))
    #expect(
      ReplayInvariants.atRest(h, placed: [:]) == [
        "\(a) is docked in the slot \(traceText(slot)) but ended up at 100,100 300×300, where Arbor did not put it"
      ])
    // An app that rounds or refuses the size it was asked for is where Arbor put it.
    #expect(ReplayInvariants.atRest(h, placed: [a: CGRect(x: 100, y: 100, width: 302, height: 298)]) == [])
    h.system.place(a, at: slot)

    h.system.place(b, at: CGRect(x: 200, y: 200, width: 300, height: 300))
    #expect(ReplayInvariants.atRest(h, placed: [:]).isEmpty)  // Floating and parked: `always` and the layout do not list it.
  }

  @Test func aWindowArborDoesNotKnowIsReportedAsLost() {
    let h = Harness()
    h.start()
    h.system.install(
      WindowSnapshot(
        id: WindowID(55), pid: 5, bundleID: "a.b", appName: "A", title: "", frame: CGRect(x: 0, y: 0, width: 100, height: 100)))
    #expect(ReplayInvariants.always(h) == ["w55 exists but Arbor does not know it"])
  }

  @Test func aTraceThatEndsInTheMiddleOfADragIsNotCheckedForWhereWindowsEndedUp() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"command":"dock 8 left"}
        {"t":2,"event":"dragBegan","id":8,"point":[300,45]}
        {"t":2.1,"event":"changed","user":true,"window":{"id":8,"pid":80,"bundle":"com.apple.Safari","app":"Safari","title":"title-2","frame":[400,300,702,851]}}
        {"t":2.1,"event":"dragMoved","id":8,"point":[690,310]}
        """)
    let report = TraceReplayer(trace).run()
    #expect(report.problems == [])
    #expect(report.story.contains { $0.hasPrefix("the trace ends while w8 is being dragged") })
  }

  // MARK: Expectations

  @Test func expectationsAreCheckedAtTheEnd() {
    let trace = dockingTrace()
    let good = """
      # Both docked, side by side.
      expect docked 101
      left-of 101 102

      count docked 2
      expect ok
      """
    #expect(TraceReplayer(trace).run(expectations: good).problems == [])
    let report = TraceReplayer(trace).run(expectations: "expect floating 101\nleft-of 102 101\nexpect sideways 3")
    #expect(report.problems.map(\.kind) == [.expectation, .expectation, .expectation])
    #expect(report.problems.first?.text == "`floating 101`: w101 is docked")
    #expect(report.problems.first?.line == trace.entries.last?.number)
  }

  @Test func expectationsOfATraceThatEndsWithoutADisplayFailInsteadOfCrashing() throws {
    let trace = try Trace(text: header + "\n" + #"{"t":1,"event":"displaysChanged","to":[]}"#)
    let report = TraceReplayer(trace).run(expectations: "camera root")
    #expect(report.problems.map(\.kind) == [.expectation])
  }

  @Test func numbersNoScreenHasDoNotCrashTheStory() throws {
    let trace = try Trace(
      text: header + "\n" + #"{"t":1,"call":"setFrame","id":8,"frame":[1e300,-1e300,1e300,0],"result":[1e300,0,0,0],"took":1e300}"#
        + "\n" + #"{"t":2,"event":"dragMoved","id":8,"point":[1e300,-1e300]}"#)
    #expect(!TraceReplayer(trace, verbose: true).run().story.isEmpty)
  }

  @Test func aKnownProblemIsToleratedUntilItIsFixed() throws {
    #expect(try fight(rounds: 12).run(expectations: "problem endless enforcement\nfloating 8").problems == [])

    let report = TraceReplayer(dockingTrace()).run(expectations: "problem endless enforcement")
    #expect(report.problems.map(\.kind) == [.expectation])
    #expect(report.problems.first?.text.contains("if it is fixed, delete that line") == true)
  }

  // MARK: The story

  @Test func theStoryTellsWhatHappenedWithDrawings() {
    let (trace, _) = record(before: { $0.system.open(app: "Safari") }) { h in
      h.run("trace note drag Safari to the left edge")
      h.scheduler.advance(by: 0.5)
      h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
      h.system.drag(WindowID(101), through: [CGPoint(x: 620, y: 210), CGPoint(x: 300, y: 300), CGPoint(x: 3, y: 450)])
    }
    let story = TraceReplayer(trace).run().story
    #expect(story[0] == "trace test: recorded 2026-05-09T06:13:21Z by Arbor test on simulated")
    #expect(story[1].hasPrefix("\(trace.entries.count + 1) lines, ") && story[1].hasSuffix(" s, replayed in free mode"))
    #expect(story.contains("display main 0,0 1440×900, visible 0,25 1440×875, main"))
    #expect(story.contains("w101 Safari 300,200 640×420"))
    #expect(story.contains("    2    0.000  # drag Safari to the left edge"))
    #expect(story.contains { $0.hasSuffix("    0.500  drag of w101 began at 620,210") })
    #expect(story.contains { $0.hasSuffix("    setFrame w101 12,37 702×851 (taken)") })
    #expect(story.contains { $0.contains("… 2 line(s)") })
    #expect(!story.contains { $0.contains("moved to") })
    // The layout before and after, and none in between.
    #expect(story.filter { $0.hasPrefix("display main\n") }.count == 2)
    #expect(story.last { $0.hasPrefix("display main\n") }?.contains("|w101 Safari") == true)

    let verbose = TraceReplayer(trace, verbose: true).run().story
    #expect(verbose.contains { $0.hasSuffix("drag of w101 moved to 3,450") })
    #expect(!verbose.contains { $0.contains("line(s)") })
  }

  @Test func eventsThisArborDoesNotKnowAreSkippedAndSaidSo() throws {
    let trace = try Trace(text: header + "\n" + #"{"t":1,"event":"levitated","args":[8]}"# + "\n" + #"{"t":2,"command":"dock 8 left"}"#)
    let replayer = TraceReplayer(trace)
    let report = replayer.run()
    #expect(report.problems == [])
    #expect(report.delivered == 1)
    #expect(report.story.contains { $0.contains("not delivered: this Arbor does not know `levitated`") })
    #expect(replayer.harness.workspace.isDocked(WindowID(8)))
  }

  @Test func eventsReadsAndCallsWithoutALineOfTheirOwnReplay() throws {
    // Stands for a controller that, told of `levitated`, asks `altitude` and then calls `tether`.
    let text = """
      \(header)
      {"t":1,"event":"levitated","args":[8,[10,20]]}
      {"t":1,"read":"altitude","args":[8],"result":{"points":120}}
      {"t":1,"call":"tether","args":[8,"firmly"],"result":true}
      {"t":1,"call":"announce","args":["w8 is back"]}
      """
    struct Altitude: Codable, Equatable { var points: Double }
    func replay(_ mode: TraceReplayer.Mode, tether: String) throws -> (TraceReplayer.Report, [String]) {
      let replayer = TraceReplayer(try Trace(text: text), mode: mode)
      var log: [String] = []
      replayer.otherStimuli["levitated"] = { [unowned replayer] arguments in
        let id: WindowID? = arguments.first?.decoded()
        let point: [Double]? = arguments.last?.decoded()
        log.append("levitated \(id?.description ?? "?") \(point ?? [])")
        let altitude: Altitude? = replayer.answer(read: "altitude")
        log.append("altitude \(altitude?.points ?? -1)")
        log.append("again \(replayer.answer(read: "altitude", as: Altitude.self)?.points ?? -1)")
        let held: Bool? = replayer.answer(call: "tether", [WindowID(8), tether])?.decoded()
        log.append("tethered \(held.map(String.init) ?? "by the model")")
        replayer.answer(call: "announce", ["w8 is back"])
      }
      return (replayer.run(), log)
    }

    let same = try replay(.strict, tether: "firmly")
    #expect(same.0.problems == [])
    #expect(same.0.delivered == 1)
    // The second time the trace has no answer left, and the fake would be asked.
    #expect(same.1 == ["levitated w8 [10.0, 20.0]", "altitude 120.0", "again -1.0", "tethered true"])

    let changed = try replay(.strict, tether: "loosely")
    #expect(changed.1.last == "tethered by the model")
    #expect(changed.0.problems.map(\.text) == [
      "the recording has `tether 8 \"firmly\" is true`; Arbor now does `tether 8 \"loosely\"`",
      "Arbor now does `announce \"w8 is back\"` before `tether 8 \"firmly\" is true`; the recording has them the other way round",
      "the recording has `tether 8 \"firmly\" is true`; Arbor no longer does that here",
    ])
    #expect(try replay(.free, tether: "loosely").0.problems == [])
  }

  @Test func eventsAboutWindowsNobodyHasHeardOfDoNoHarm() throws {
    let trace = try Trace(
      text: """
        \(header)
        {"t":1,"event":"destroyed","id":99}
        {"t":1,"event":"focused","id":99}
        {"t":1,"event":"dragBegan","id":99,"point":[1,1]}
        {"t":1,"event":"dragMoved","id":99,"point":[-5000,99999]}
        {"t":1,"event":"dragEnded","id":99,"point":[1,1]}
        {"t":1,"event":"resizeBegan","id":99}
        {"t":1,"event":"resizeEnded","id":99}
        {"t":1,"action":"tileActivated","display":"nowhere","node":12}
        {"t":1,"action":"tileActivated","display":"main","node":12}
        {"t":1,"timer":"nothing"}
        {"t":0.5,"command":"dock 99 left"}
        {"t":1,"done":"something else","ok":true,"message":""}
        {"t":1,"event":"displaysChanged","to":[]}
        {"t":1,"command":"show-all"}
        {"t":2,"event":"displaysChanged","to":[{"id":"main","frame":[0,0,1440,900],"visible":[0,25,1440,875],"main":true}]}
        """)
    for mode in TraceReplayer.Mode.allCases {
      let report = TraceReplayer(trace, mode: mode).run()
      #expect(report.problems.filter { $0.kind == .invariant } == [], "\(mode)")
    }
  }
}
