import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What Arbor promises (docs/GUIDE.md, "What Arbor promises"; issue #3's seven rules), by example. One scenario for each rule is in
/// `collab/scenarios/rule-*.sim`; here is what a scenario cannot play, above all windows that are open before Arbor starts.
///
/// A promise the trunk breaks stands here as a known issue that names its row on the board. Such a test fails as soon as the
/// fault is mended: then the `withKnownIssue` goes.
@Suite @MainActor struct PromisesTests {
  let safariFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
  let notesFrame = CGRect(x: 760, y: 300, width: 500, height: 300)
  let mailFrame = CGRect(x: 400, y: 420, width: 520, height: 340)

  /// A Mac with three windows open, all wholly in view, and Arbor not started.
  func mac(settings: Settings = Settings()) -> (h: Harness, windows: [WindowID]) {
    let h = Harness(settings: settings)
    let windows = [
      h.system.open(app: "Safari", pid: 1001, frame: safariFrame), h.system.open(app: "Notes", pid: 1002, frame: notesFrame),
      h.system.open(app: "Mail", pid: 1003, frame: mailFrame),
    ]
    return (h, windows)
  }

  /// Lets whatever a step has put off happen.
  func settle(_ h: Harness) {
    h.system.deliverEchoes()
    h.scheduler.advance(by: 5)
  }

  // MARK: 1. Never fight macOS

  /// The switches as macOS comes: nobody has written a value.
  static let macOSDefaults = MacSwitch.inTheWay(macOS: 26) { _ in nil }

  /// Before anything is arranged Arbor has looked, and whoever asks is told (`doctor`, Check Setup…). The first minute does not speak of it:
  /// its moves are keys, which fight nothing of macOS's (Q29, 11). Nothing has moved.
  @Test func atMacOSDefaultsArborHasLookedBeforeAnythingIsArrangedAndMovesNothing() {
    let (h, _) = mac()
    let facts = SystemFacts(accessibility: true, screenRecording: true, switches: Self.macOSDefaults, inputSources: 1)
    h.controller.systemFacts = { facts }
    h.controller.isFirstLaunch = true
    h.start()
    settle(h)
    #expect(h.controller.onboardingModel(facts, flow: OnboardingFlow(isReady: true)).rows.map(\.id) == [.accessibility])
    #expect(h.controller.onboardingModel(facts).row(.desktopAndDock)?.state == .recommended, "Check Setup…")
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
    let report = h.run("doctor")
    #expect(!report.ok)
    for macSwitch in [MacSwitch.screenEdges, .menuBar, .optionKey] { #expect(report.text?.contains(macSwitch.label) == true) }
  }

  // MARK: 2. Nothing moves until the person docks something

  @Test func theFirstLaunchMovesNothingAndDocksNothing() {
    let (h, windows) = mac()
    h.start()
    settle(h)
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
    #expect(h.system.raiseLog.isEmpty && h.system.focusLog.isEmpty, "nor is anything raised or focused")
    #expect(h.workspace.tree.allWindows.isEmpty)
    for window in windows { #expect(h.workspace.isFloating(window)) }
  }

  /// Whoever has new windows docked asked for that of windows that open from now on, not of the ones that are there.
  @Test func withNewWindowsDockedTheWindowsThatWereOpenAllAlongStillFloat() {
    var settings = Settings()
    settings.newWindows = "dock"
    let (h, _) = mac(settings: settings)
    h.start()
    settle(h)
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
    #expect(h.workspace.tree.allWindows.isEmpty)
  }

  @Test func withNothingDockedAPauseAResumeAQuitAndTheNextLaunchMoveNothing() {
    let (h, _) = mac()
    h.start()
    for command in ["pause", "resume", "toggle-pause", "toggle-pause"] {
      h.run(command)
      settle(h)
    }
    h.controller.shutdown()
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
    let next = Harness(saved: h.store.saved, system: h.system)
    next.start()
    settle(next)
    #expect(next.system.moveLog.isEmpty, "\(next.system.moveLog)")
  }

  /// Arbor dies where it stands and is started again.
  @Test func withNothingDockedAStartAfterACrashMovesNothing() {
    let (h, _) = mac()
    h.start()
    settle(h)
    h.system.events = nil
    let next = Harness(saved: h.store.saved, system: h.system)
    next.start()
    settle(next)
    #expect(next.system.moveLog.isEmpty, "\(next.system.moveLog)")
  }

  @Test func aWindowThatOpensStaysWhereItsAppPutItAndNothingElseMoves() {
    let (h, _) = mac()
    h.start()
    let place = CGRect(x: 240, y: 160, width: 700, height: 480)
    let new = h.system.open(app: "Maps", pid: 1004, frame: place)
    settle(h)
    #expect(h.frame(new) == place)
    #expect(h.workspace.isFloating(new))
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
  }

  /// People leave windows hanging over the edge of the screen. More than half of each shows.
  nonisolated static let hanging = [
    CGRect(x: 242, y: 461, width: 451, height: 687), CGRect(x: -211, y: 247, width: 673, height: 471),
    CGRect(x: 1002, y: 307, width: 731, height: 379),
  ]

  @Test(arguments: hanging) func aWindowFoundHangingOverAnEdgeStaysThereAtTheStart(frame: CGRect) {
    let h = Harness()
    let window = h.system.open(app: "Mail", pid: 1001, frame: frame)
    h.start()
    settle(h)
    #expect(h.frame(window) == frame)
  }

  /// Nothing is docked, another app's window closes, and the window that hangs over the edge stays: what is found counts as left.
  @Test(arguments: hanging) func aWindowHangingOverAnEdgeStaysThereWhenAnotherWindowCloses(frame: CGRect) {
    let h = Harness()
    let window = h.system.open(app: "Mail", pid: 1001, frame: frame)
    let other = h.system.open(app: "Music", pid: 1002, frame: CGRect(x: 370, y: 65, width: 648, height: 286))
    h.start()
    h.system.close(other)
    settle(h)
    #expect(h.frame(window) == frame)
    #expect(h.system.moveLog.isEmpty, "\(h.system.moveLog)")
  }

  /// Nothing is docked. A window is moved by hand while Arbor is paused. Until 2026-10-15, at the next thing that happened after the
  /// resume, Arbor took it back to where it was before the pause (`FoundAtAStartTests`).
  @Test func aWindowMovedByHandDuringAPauseStaysWhereTheHandPutIt() {
    let (h, windows) = mac()
    h.start()
    h.run("pause")
    let chosen = CGRect(x: 60, y: 80, width: 500, height: 300)
    h.system.userMove(windows[1], to: chosen)
    h.run("resume")
    settle(h)
    #expect(h.frame(windows[1]) == chosen)
    h.system.close(windows[2])
    settle(h)
    #expect(h.frame(windows[1]) == chosen)
  }

  // MARK: 3. A window moves once, to where it ends up

  /// The detector itself (Jolts.swift), on moves made by hand.
  @Test func aJoltIsArborChangingItsMindWhereAPersonCanSeeIt() {
    let (h, windows) = mac()
    h.start()
    let (a, b, corner) = (
      CGRect(x: 0, y: 25, width: 400, height: 300), CGRect(x: 500, y: 25, width: 400, height: 300),
      CGRect(x: 1439, y: 868, width: 400, height: 300)
    )
    h.beginStep()
    _ = h.system.setFrame(a, of: windows[0])
    #expect(h.jolts.isEmpty, "one move is no jolt")
    _ = h.system.setFrame(a, of: windows[0])
    #expect(h.jolts.isEmpty, "nor is asking for the same again")
    _ = h.system.setFrame(b, of: windows[0])
    #expect(h.jolts == [Jolt(window: windows[0], from: safariFrame, via: a, to: b)])
    #expect(h.movesInStep == [windows[0]: 2])

    // A size where it stands, and then its place: one road, and how a Mac moves any window.
    h.beginStep()
    _ = h.system.setFrame(CGRect(origin: b.origin, size: CGSize(width: 600, height: 500)), of: windows[0])
    _ = h.system.setFrame(CGRect(x: 100, y: 200, width: 600, height: 500), of: windows[0])
    #expect(h.jolts.isEmpty && h.movesInStep == [windows[0]: 1])
    // Not the other way about, nor a size that is taken back.
    _ = h.system.setFrame(CGRect(x: 100, y: 200, width: 580, height: 500), of: windows[0])
    #expect(h.jolts.count == 1)
    h.beginStep()
    _ = h.system.setFrame(CGRect(x: 100, y: 200, width: 400, height: 500), of: windows[0])
    _ = h.system.setFrame(CGRect(x: 100, y: 200, width: 500, height: 500), of: windows[0])
    #expect(h.jolts.count == 1)

    // Out of view and back: seen as a flash.
    h.beginStep()
    _ = h.system.setFrame(corner, of: windows[1])
    _ = h.system.setFrame(notesFrame, of: windows[1])
    #expect(h.jolts.map(\.window) == [windows[1]])
    // Also when it was asked for a size out there, which nobody saw.
    h.beginStep()
    _ = h.system.setFrame(corner, of: windows[1])
    _ = h.system.setFrame(CGRect(origin: corner.origin, size: CGSize(width: 700, height: 500)), of: windows[1])
    _ = h.system.setFrame(CGRect(origin: notesFrame.origin, size: CGSize(width: 700, height: 500)), of: windows[1])
    #expect(h.jolts.map(\.window) == [windows[1]])

    // Two places out of view, then into view: a person sees one move.
    _ = h.system.setFrame(corner, of: windows[2])
    h.beginStep()
    _ = h.system.setFrame(corner.offsetBy(dx: 0, dy: -200), of: windows[2])
    _ = h.system.setFrame(mailFrame, of: windows[2])
    #expect(h.jolts.isEmpty)

    // Somebody else had the window in between.
    h.beginStep()
    _ = h.system.setFrame(a, of: windows[0])
    h.system.userMove(windows[0], to: safariFrame)
    _ = h.system.setFrame(b, of: windows[0])
    #expect(h.jolts.isEmpty)
  }

  @Test func askingAgainBecauseAnAppRefusedCountsAsLearning() {
    let h = Harness()
    let window = h.system.open(app: "Xcode", frame: safariFrame, minimumSize: CGSize(width: 500, height: 300))
    let other = h.system.open(app: "Notes", frame: notesFrame)
    h.start()
    h.beginStep()
    _ = h.system.setFrame(CGRect(x: 0, y: 25, width: 300, height: 300), of: window)
    _ = h.system.setFrame(CGRect(x: 100, y: 25, width: 500, height: 300), of: window)
    #expect(h.jolts.isEmpty, "the app did not do as it was asked: there was something to learn")
    // What was learnt can change where the others go.
    _ = h.system.setFrame(CGRect(x: 700, y: 25, width: 300, height: 300), of: other)
    _ = h.system.setFrame(CGRect(x: 800, y: 25, width: 300, height: 300), of: other)
    #expect(h.jolts.map(\.whileLearning) == [true])
  }

  /// System Settings, Calculator: macOS says beforehand that their size cannot be changed, so there is nothing to learn by asking.
  @Test func aWindowWhoseSizeCannotBeChangedGoesStraightToTheMiddleOfItsPlace() throws {
    let h = Harness()
    let window = h.system.open(app: "Calculator", frame: CGRect(x: 900, y: 500, width: 300, height: 400), isResizable: false)
    h.start()
    h.beginStep()
    h.run("dock \(window.rawValue) left")
    let slot = try #require(h.layout?.windowFrames[window])
    let frame = try #require(h.frame(window))
    #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1, "\(frame) in \(slot)")
    #expect(h.movesInStep[window] == 1, "\(h.system.moveLog.map(\.after))")
  }

  // MARK: 4. The window you switch to comes to the front and into view

  /// From every view, to every window, however it floats or is docked.
  @Test func fromEveryViewASwitchToAnyWindowShowsItInFront() throws {
    let (h, windows) = mac()
    let extra = h.system.open(app: "Maps", pid: 1004, frame: CGRect(x: 500, y: 200, width: 500, height: 400))
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) right")
    h.run("dock \(windows[2].rawValue) beside \(windows[1].rawValue) bottom")
    let views = ["home", "zoom \(windows[0].rawValue)", "zoom \(windows[2].rawValue)", "desktop", "zoom \(windows[1].rawValue), out"]
    for view in views {
      for target in windows + [extra] {
        for command in view.split(separator: ",") { h.run(command.trimmingCharacters(in: .whitespaces)) }
        h.system.userFocus(target)
        settle(h)
        let frame = try #require(h.frame(target))
        #expect(h.system.focused == target, "\(view), then \(target)")
        #expect(h.system.isVisible(target) && !h.controller.parked.contains(target), "\(view), then \(target): \(frame)")
        let above = h.system.windowsFrontToBack().prefix { $0 != target }
        #expect(!above.contains { h.frame($0)?.overlaps(frame) == true }, "\(view), then \(target): behind \(Array(above))")
        expectWindowsMatchLayout(h)
      }
    }
  }

  // MARK: 5. Leave things as you found them

  /// Docked, framed, and let go of in each of the three ways.
  @Test(arguments: ["float-all", "quit", "pause"]) func eachWayOutGivesEveryWindowItsOwnFrameBack(way: String) {
    let (h, windows) = mac()
    h.start()
    h.run("arrange")
    h.run("zoom \(windows[0].rawValue)")
    settle(h)
    h.beginStep()
    if way == "quit" { h.controller.shutdown() } else { h.run(way) }
    #expect(h.frame(windows[1]) == notesFrame)
    #expect(h.frame(windows[2]) == mailFrame)
    #expect(h.movesInStep.values.allSatisfy { $0 == 1 }, "\(h.movesInStep)")
    #expect(h.frame(windows[0]) == safariFrame)
  }

  // MARK: 6. Drags never block input

  /// However a drag ends, the preview is gone with it: dropped, called off, the release never seen, the window closed in the hand.
  @Test(arguments: ["dropped", "lost", "closed", "paused"]) func noPreviewOutlivesItsDrag(ending: String) {
    let (h, windows) = mac()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.start()
    h.system.beginDrag(windows[0])
    h.system.moveDrag(to: CGPoint(x: 2, y: 400), holding: 0.5)
    #expect(h.overlays.preview != nil, "the control: there is one to lose")
    switch ending {
    case "dropped": h.system.endDrag()
    case "lost": h.system.loseTheReleaseOfTheDrag()
    case "closed": h.system.close(windows[0])
    default: h.run("pause")
    }
    settle(h)
    #expect(h.overlays.preview == nil)
    #expect(h.controller.draggedWindow == nil)
  }

  // MARK: 7. There is always a way back

  /// By the keys the guide names, from a view three steps in.
  @Test(arguments: ["ctrl+opt+space", "ctrl+opt+0", "ctrl+opt+shift+f"]) func eachWayBackShowsEveryWindow(key: String) {
    let (h, windows) = mac()
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) right")
    h.run("zoom \(windows[1].rawValue)")
    #expect(!h.system.isVisible(windows[0]) && !h.system.isVisible(windows[2]), "the control")
    h.key(key)
    settle(h)
    for window in windows { #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!)") }
    #expect(h.controller.parked.isEmpty)
    expectWindowsMatchLayout(h)
  }
}
