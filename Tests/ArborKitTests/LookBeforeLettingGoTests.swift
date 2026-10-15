import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Arbor hears of a change of displays only once it has settled, a second and a half after macOS's last notice
/// (`DisplayChange`). Whoever quits or pauses within that time (a laptop pulled off its dock and shut) had every window
/// given back "its own earlier frame" by the displays Arbor still believed in: on a display that was gone, with nobody
/// left to fetch it. Seen on a hosted Mac: a virtual display removed, Quit two seconds later.
///
/// Look before letting go: frames are given back by the displays that are.
@Suite @MainActor struct LookBeforeLettingGoTests {
  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false)

  enum Way: String, CaseIterable, CustomTestStringConvertible {
    case quit, pause
    var testDescription: String { rawValue }
  }

  /// What macOS does with the windows of a display that goes, before Arbor hears.
  enum MacOS: String, CaseIterable, CustomTestStringConvertible {
    /// It brings them to the display that stays, and their apps say so.
    case bringsThemHome
    /// It leaves them where they were.
    case leavesThem
    var testDescription: String { rawValue }
  }

  /// Three windows docked and one floating on the second display, and one that never left the main display.
  func make(from x: CGFloat = 1600) -> (Harness, onTheSide: [WindowID], atHome: WindowID) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let there = (0..<4).map { index in
      h.system.open(
        app: "App\(index)", pid: Int32(1001 + index),
        frame: CGRect(x: x + 100 * CGFloat(index), y: 100 + 50 * CGFloat(index), width: 480, height: 348))
    }
    let home = h.system.open(app: "Home", pid: 1010, frame: CGRect(x: 300, y: 200, width: 480, height: 348))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.run("dock \(there[0].rawValue) left")
    h.run("dock \(there[1].rawValue) right")
    h.run("dock \(there[2].rawValue) beside \(there[1].rawValue) bottom")
    h.scheduler.advance(by: 5)
    return (h, there, home)
  }

  /// macOS has other displays from here on, and Arbor is not told.
  func quietly(_ h: Harness, _ change: () -> Void) {
    let listener = h.system.events
    h.system.events = nil
    change()
    h.system.events = listener
  }

  func letGo(_ h: Harness, _ way: Way) {
    switch way {
    case .quit: h.controller.shutdown()
    case .pause: h.run("pause")
    }
  }

  func moves(of window: WindowID, _ h: Harness) -> [CGRect] {
    h.system.frameLog.filter { $0.window == window }.map(\.frame)
  }

  @Test(arguments: Way.allCases, MacOS.allCases)
  func lettingGoBeforeArborHasHeardThatADisplayWentLeavesEveryWindowInView(_ way: Way, _ macOS: MacOS) {
    let (h, there, home) = make()
    quietly(h) { h.system.unplug(Self.side.id) }
    if macOS == .bringsThemHome {
      for (index, window) in there.enumerated() {
        h.system.userMove(
          window, to: CGRect(x: 170 + 50 * CGFloat(index), y: 220 - 40 * CGFloat(index), width: 480, height: 348))
      }
    }
    h.scheduler.advance(by: 1)
    #expect(h.controller.displays.count == 2, "Arbor has not heard")
    h.system.clearFrameLog()
    letGo(h, way)
    for window in there + [home] {
      #expect(h.visibleFrame.contains(h.frame(window)!), "\(window) at \(h.frame(window)!)")
      #expect(h.frame(window)!.size == CGSize(width: 480, height: 348), "its own size: \(window) at \(h.frame(window)!)")
      #expect(moves(of: window, h).count <= 1, "a window moves once: \(window) \(moves(of: window, h))")
    }
    #expect(moves(of: home, h) == [], "and one that nothing happened to does not move at all")
  }

  /// The display has only got smaller, and where the windows floated before they were docked is beyond its edge now.
  @Test(arguments: Way.allCases) func orThatADisplayShrank(_ way: Way) {
    let (h, there, _) = make(from: 2500)
    var smaller = Self.side
    smaller.frame.size = CGSize(width: 800, height: 600)
    smaller.visibleFrame.size = smaller.frame.size
    quietly(h) { h.system.plug(smaller) }
    h.scheduler.advance(by: 1)
    letGo(h, way)
    for window in there {
      #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!)")
    }
  }

  /// What is written at the quit is true of the displays that are, so the next start finds the arrangement asleep with its
  /// display, and it comes back when the display does.
  @Test func theArrangementSleepsWithItsDisplayAndComesBackWithIt() {
    let (h, there, _) = make()
    quietly(h) { h.system.unplug(Self.side.id) }
    h.scheduler.advance(by: 1)
    h.controller.shutdown()
    let again = Harness(saved: h.store.saved, system: h.system)
    again.start()
    again.scheduler.advance(by: 5)
    for window in there { #expect(again.system.isVisible(window)) }
    again.system.plug(Self.side)
    again.scheduler.advance(by: 5)
    #expect(again.controller.workspaces[Self.side.id]?.tree.allWindows.sorted() == Array(there.prefix(3)))
    expectWindowsMatchLayout(again)
  }

  /// A pause that began so ends like any other: the resume goes by the displays that are then.
  @Test func aPauseThatBeganSoIsResumed() {
    let (h, there, home) = make()
    quietly(h) { h.system.unplug(Self.side.id) }
    h.scheduler.advance(by: 1)
    h.run("pause")
    h.scheduler.advance(by: 60)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 5)
    for window in there + [home] { #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!)") }
    expectWindowsMatchLayout(h)
  }

  // MARK: It looks, and moves nothing by looking

  /// The display has only got larger. Each docked window goes from its slot to its own frame, and not by way of a larger slot.
  @Test(arguments: Way.allCases) func aDisplayOfAnotherSizeCostsNoSecondMove(_ way: Way) {
    let (h, there, _) = make()
    var larger = Self.side
    larger.frame.size = CGSize(width: 2560, height: 1440)
    larger.visibleFrame.size = larger.frame.size
    quietly(h) { h.system.plug(larger) }
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    letGo(h, way)
    // The fourth floats, and the docked ones had pushed it aside: it too gets its own place back.
    for (index, window) in there.enumerated() {
      #expect(moves(of: window, h) == [CGRect(x: 1600 + 100 * CGFloat(index), y: 100 + 50 * CGFloat(index), width: 480, height: 348)])
    }
  }

  /// The laptop has an arrangement of its own. A window that comes over from the display that went goes to its place in one
  /// move, not by way of the laptop's Desktop, squeezed; and the laptop's own windows are let go of as ever.
  @Test(arguments: Way.allCases) func whereTheDisplayThatStaysHasDockedWindowsNobodyMovesTwice(_ way: Way) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let over = h.system.open(app: "Over", pid: 1001, frame: CGRect(x: 1600, y: 100, width: 480, height: 348))
    let a = h.system.open(app: "A", pid: 1002, frame: CGRect(x: 100, y: 100, width: 480, height: 348))
    let b = h.system.open(app: "B", pid: 1003, frame: CGRect(x: 200, y: 150, width: 480, height: 348))
    h.start()
    h.system.cursor = CGPoint(x: 500, y: 500)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 5)
    quietly(h) { h.system.unplug(Self.side.id) }
    h.system.userMove(over, to: CGRect(x: 170, y: 220, width: 480, height: 348))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    letGo(h, way)
    for window in [over, a, b] {
      #expect(moves(of: window, h).count <= 1, "\(window) \(moves(of: window, h))")
      #expect(h.frame(window)!.size == CGSize(width: 480, height: 348))
      #expect(h.visibleFrame.contains(h.frame(window)!))
    }
  }

  /// One window is framed on the laptop, and the keyboard is in a window on the display that goes. The view does not follow the
  /// keyboard any more: the framed window is not sent out of view and fetched again.
  @Test(arguments: Way.allCases, [false, true]) func theViewDoesNotFollowTheKeyboardAnyMore(_ way: Way, held: Bool) {
    let (h, there, home) = make()
    let other = h.system.open(app: "Other", pid: 1011, frame: CGRect(x: 100, y: 100, width: 480, height: 348))
    h.system.cursor = CGPoint(x: 500, y: 500)
    h.run("dock \(home.rawValue) left")
    h.run("dock \(other.rawValue) right")
    h.run("zoom \(home.rawValue)")
    if held {
      h.system.userFocus(home)
      h.run("hold")
      h.scheduler.advance(by: 2)
    }
    h.system.userFocus(there[0])
    h.scheduler.advance(by: 5)
    quietly(h) { h.system.unplug(Self.side.id) }
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    letGo(h, way)
    #expect(h.system.focusedWindow() == there[0], "whoever is typing goes on typing")
    for window in there + [home, other] {
      #expect(moves(of: window, h).count <= 1, "\(window) \(moves(of: window, h))")
      #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!)")
    }
  }

  /// One display goes and another, which Arbor remembers, comes within the same second. Windows that lie still on the laptop
  /// are not sent over to it, into their old slots and out again.
  @Test(arguments: Way.allCases) func aRememberedDisplayThatComesInTheSameSecondGetsNoWindows(_ way: Way) {
    let (h, there, _) = make()
    h.system.unplug(Self.side.id)
    h.scheduler.advance(by: 5)
    var desk = Self.side
    desk.id = DisplayID("desk")
    h.system.plug(desk)
    h.scheduler.advance(by: 5)
    let lying = there.map { h.frame($0)! }
    quietly(h) {
      h.system.unplug(desk.id)
      h.system.plug(Self.side)
    }
    h.scheduler.advance(by: 0.5)
    h.system.clearFrameLog()
    letGo(h, way)
    #expect(there.map { h.frame($0)! } == lying)
    for window in there { #expect(moves(of: window, h) == []) }
  }

  /// For a moment on wake, and when docking, there is no display at all. There is nothing to go by then, and Arbor lets go as it
  /// believes: each window at its own frame, on the display that is most likely to come back.
  @Test(arguments: Way.allCases) func withNoDisplayAtAllItLetsGoAsItBelieves(_ way: Way) {
    let h = Harness()
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 480, height: 348))
    let b = h.system.open(app: "B", frame: CGRect(x: 200, y: 150, width: 480, height: 348))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 5)
    quietly(h) { h.system.unplug(h.display) }
    h.scheduler.advance(by: 1)
    letGo(h, way)
    #expect(h.frame(a) == CGRect(x: 100, y: 100, width: 480, height: 348))
    #expect(h.frame(b) == CGRect(x: 200, y: 150, width: 480, height: 348))
  }

  /// A display's corner moves (a lid shuts, another display gets the menu bar, displays are rearranged) and macOS takes its windows
  /// along without a word. The look reads their new coordinates. That is not the pause's doing, and the resume has nothing to
  /// undo: a floating window that its person had laid over a docked one lies there afterwards.
  @Test func whatMacOSShiftedIsNotTakenForThePausesDoing() {
    let (h, there, _) = make()
    h.system.userMove(there[3], to: CGRect(x: 1500, y: 300, width: 480, height: 348))
    h.scheduler.advance(by: 3)
    quietly(h) { h.system.moveDisplay(Self.side.id, to: CGPoint(x: 1440, y: -500)) }
    h.scheduler.advance(by: 1)
    h.run("pause")
    h.scheduler.advance(by: 5)
    h.run("resume")
    h.scheduler.advance(by: 5)
    #expect(h.frame(there[3]) == CGRect(x: 1500, y: -200, width: 480, height: 348))
    expectWindowsMatchLayout(h)
  }

  /// On a Mac too `displays` answers otherwise before Arbor is told. A trace holds those answers, and a replay goes by them: the
  /// replayed Arbor finds out as the recorded one did.
  @Test(arguments: [TraceReplayer.Mode.strict, .free]) func aTraceOfItReplays(mode: TraceReplayer.Mode) {
    let (h, there, home) = make()
    h.run("trace on pulled-off")
    quietly(h) { h.system.unplug(Self.side.id) }
    for (index, window) in there.enumerated() {
      h.system.userMove(
        window, to: CGRect(x: 170 + 50 * CGFloat(index), y: 220 - 40 * CGFloat(index), width: 480, height: 348))
    }
    h.scheduler.advance(by: 1)
    h.run("pause")
    #expect(!h.recorder.isRecording, "a trace ends when Arbor pauses")
    let replayer = TraceReplayer(recordedTrace(h), mode: mode)
    #expect(replayer.run().problems == [])
    for window in there + [home] { #expect(replayer.harness.frame(window) == h.frame(window)) }
  }

  // MARK: What is not a reason to look

  /// A display that has only just been plugged in takes nothing away. Arbor lets go as it would have a second earlier, and does
  /// not first send windows over to it.
  @Test(arguments: Way.allCases) func aDisplayThatHasOnlyJustComeIsNoReasonToMoveAnything(_ way: Way) {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 5)
    quietly(h) { h.system.plug(Self.side) }
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    letGo(h, way)
    #expect(h.frame(a) == CGRect(x: 300, y: 200, width: 640, height: 420))
    #expect(moves(of: a, h).count == 1)
    #expect(moves(of: b, h).count <= 1)
    #expect(h.controller.displays.count == 1 || way == .pause, "it has not looked")
  }

  /// Without the permission nothing can be moved, and nothing is tried.
  @Test func withoutMovingWindowsNothingIsLookedAt() {
    let (h, _, _) = make()
    quietly(h) { h.system.unplug(Self.side.id) }
    h.system.clearFrameLog()
    h.controller.shutdown(movingWindows: false)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.controller.displays.count == 2, "nor are the books rewritten by what cannot be read")
  }
}
