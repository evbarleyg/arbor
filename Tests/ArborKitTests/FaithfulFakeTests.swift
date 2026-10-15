import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Writes down what a window system reports, in order.
@MainActor
private final class Recorder: WindowSystemEvents {
  var log: [String] = []
  /// Asked at the moment a window is reported.
  var whenAWindowAppears: (() -> Void)?
  func windowAppeared(_ window: WindowSnapshot) {
    log.append("appeared \(window.id)")
    whenAWindowAppears?()
  }
  func windowDestroyed(_ id: WindowID) { log.append("destroyed \(id)") }
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    var traits: [String] = []
    if window.isMinimized { traits.append("minimized") }
    if window.isHidden { traits.append("hidden") }
    log.append((["changed \(window.id)", userInitiated ? "by hand" : "echo"] + traits).joined(separator: " "))
  }
  func windowFocused(_ id: WindowID) { log.append("focused \(id)") }
  func dragBegan(_ id: WindowID, at point: CGPoint) {}
  func dragMoved(_ id: WindowID, to point: CGPoint) {}
  func dragEnded(_ id: WindowID, at point: CGPoint) {}
  func displaysChanged() { log.append("displays") }
  func resizeBegan(_ id: WindowID) {}
  func resizeEnded(_ id: WindowID) {}
  func keyboardFocusMoved() { log.append("keyboard moved") }
  func dragCancelled(_ id: WindowID) {}
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) { log.append("replaced \(old) by \(window.id)") }
  func pointerPressed() {}
}

/// The fake window system reports what macOS 26 was recorded to report, in that order
/// (`collab/evidence/ax-events.txt`), because every scenario test is only as good as the fake.
@Suite @MainActor struct FaithfulFakeTests {
  /// Two windows of app 1 (`a`, `b`), one of app 2 (`c`); `a` has the keyboard, `b` had it before, `c` before that.
  private func make(_ echoes: FakeWindowSystem.Echoes = .init()) -> (FakeWindowSystem, Recorder, WindowID, WindowID, WindowID) {
    let system = FakeWindowSystem()
    let recorder = Recorder()
    system.events = recorder
    system.echoes = echoes
    let a = system.open(app: "Safari", pid: 1)
    let b = system.open(app: "Safari", pid: 1)
    let c = system.open(app: "Mail", pid: 2)
    system.start()
    for window in [c, b, a] { system.userFocus(window) }
    recorder.log.removeAll()
    return (system, recorder, a, b, c)
  }

  /// Answers recorded on macOS 26 (1024×768, the visible frame ends at 705), as they came.
  @Test func aWindowGrowsNoFurtherThanTheScreenWhereItStands() {
    let system = FakeWindowSystem(displays: [
      DisplaySnapshot(
        id: DisplayID("small"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
        visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true)
    ])
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
      CGRect(x: x, y: y, width: width, height: height)
    }
    let a = system.open(app: "A", frame: rect(170, 220, 480, 348))
    #expect(system.setFrame(rect(170, 220, 494, 650), of: a) == rect(170, 220, 494, 484), "where it stands")
    #expect(system.setFrame(rect(12, 126, 494, 484), of: a) == rect(12, 126, 494, 484))
    #expect(system.setFrame(rect(12, 126, 325, 650), of: a) == rect(12, 126, 325, 578), "from higher up, further")
    // Moved first, it grows where it ends up. (Recorded under size, position, size, where the last call reached what the first did not.)
    #expect(system.setFrame(rect(12, 43, 325, 650), of: a) == rect(12, 43, 325, 650), "on its way up, all the way")
    // Past the line already it grows as it is asked to, and keeps that on its way back: into a frame that hangs over the line it grows first.
    #expect(system.setFrame(rect(1023, 767, 325, 524), of: a)?.size == CGSize(width: 325, height: 524))
    #expect(system.setFrame(rect(687, 106, 325, 650), of: a) == rect(687, 106, 325, 650), "its bottom at 756")
    // Each side by itself: as wide as to the right edge.
    #expect(system.setFrame(rect(687, 106, 494, 650), of: a) == rect(687, 106, 337, 650), "its right edge at 1024")
    #expect(system.setFrame(rect(249, 356, 446, 348), of: a) == rect(249, 356, 446, 348))
    #expect(system.setFrame(rect(249, 356, 273, 650), of: a) == rect(249, 356, 273, 348), "at the line already")
    // In the corner, past both.
    #expect(system.setFrame(rect(1023, 767, 325, 484), of: a)?.size == CGSize(width: 325, height: 484))
    let corner = system.windows[a]!.snapshot.frame.origin
    #expect(system.setFrame(CGRect(origin: corner, size: CGSize(width: 1000, height: 650)), of: a)?.size == CGSize(width: 1000, height: 650))
    // What its app insists on wins.
    let large = system.open(app: "Large", frame: rect(578, 220, 700, 500), minimumSize: CGSize(width: 700, height: 500))
    #expect(system.setFrame(rect(578, 220, 446, 348), of: large) == rect(578, 220, 700, 500))
    system.echoes.growsNoFurtherThanTheScreen = false
    #expect(system.setFrame(rect(687, 300, 300, 300), of: a) == rect(687, 300, 300, 300))
    #expect(system.setFrame(rect(687, 300, 400, 650), of: a) == rect(687, 300, 400, 650))
  }

  @Test func aNewWindowIsCreatedThenFocused() {
    let (system, recorder, _, _, _) = make()
    let new = system.open(app: "Safari", pid: 1)
    #expect(recorder.log == ["appeared \(new)", "focused \(new)"])
    #expect(system.focused == new)
  }

  /// The reports lag behind the Mac: by the time anybody hears of a new window it has the keyboard and is in front.
  @Test(arguments: [false, true]) func aNewWindowHasTheKeyboardBeforeAnybodyHearsOfIt(underANumberOfTheCallersChoice: Bool) {
    let (system, recorder, a, _, _) = make()
    var met: [(keyboard: WindowID?, front: WindowID?)] = []
    recorder.whenAWindowAppears = { met.append((system.focusedWindow(), system.windowsFrontToBack().first)) }
    let new: WindowID
    if underANumberOfTheCallersChoice {
      new = WindowID(900)
      system.open(id: new, app: "Safari", bundleID: nil, title: "", pid: 1, frame: CGRect(x: 0, y: 25, width: 400, height: 300))
    } else {
      new = system.open(app: "Safari", pid: 1)
    }
    #expect(met.map(\.keyboard) == [new] && met.map(\.front) == [new])
    #expect(recorder.log == ["appeared \(new)", "focused \(new)"], "and what is reported is what it was")

    // One that opens in the background has neither.
    met = []
    system.echoes.keyboard = false
    system.userFocus(a)
    let quiet = system.open(app: "Mail", pid: 2)
    #expect(met.map(\.keyboard) == [a] && system.focused == a && quiet != a)
  }

  @Test func closingTheFocusedWindowFocusesTheAppsNextWindowBeforeItIsReportedGone() {
    let (system, recorder, a, b, _) = make()
    system.close(a)
    #expect(recorder.log == ["focused \(b)", "destroyed \(a)"])
    #expect(system.focused == b)
  }

  @Test func closingAWindowThatDoesNotHaveTheKeyboardMovesNoFocus() {
    let (system, recorder, a, b, _) = make()
    system.close(b)
    #expect(recorder.log == ["destroyed \(b)"])
    #expect(system.focused == a)
  }

  @Test func closingAnAppsLastWindowLeavesTheAppInFrontWithoutAWindow() {
    let (system, recorder, _, _, c) = make()
    system.userFocus(c)
    recorder.log.removeAll()
    system.close(c)
    #expect(recorder.log == ["keyboard moved", "destroyed \(c)"])
    #expect(system.focused == nil)
  }

  @Test func minimizingTheFocusedWindowFocusesTheNextFirstAndRestoringFocusesFirstToo() {
    let (system, recorder, a, b, _) = make()
    system.setMinimized(a, true)
    #expect(recorder.log == ["focused \(b)", "changed \(a) by hand minimized"])
    recorder.log.removeAll()
    system.setMinimized(a, false)
    #expect(recorder.log == ["focused \(a)", "changed \(a) by hand"])
  }

  @Test func hidingTheAppInFrontReportsItsWindowsThenTheAppThatComesForward() {
    let (system, recorder, a, b, c) = make()
    system.setHidden(pid: 1, true)
    #expect(recorder.log == ["changed \(a) echo hidden", "changed \(b) echo hidden", "focused \(c)"], "nobody moved anything")
    #expect(system.focused == c)
    recorder.log.removeAll()
    system.setHidden(pid: 1, false)
    #expect(recorder.log == ["changed \(a) echo", "changed \(b) echo"])
  }

  /// What the Accessibility layer calls somebody's doing: a move, a resize, a window into the Dock or out of it. Not a title, which
  /// terminals and browsers change all the time, nor an app that hides or shows, however late it says so.
  @Test func aNewTitleAndAnAppThatShowsAgainAreNobodysDoing() {
    let (system, recorder, a, b, _) = make()
    system.setTitle(a, "another")
    #expect(recorder.log == ["changed \(a) echo"])
    system.setHidden(pid: 1, true)
    system.setMinimized(b, true)
    system.restoresLate = true
    system.setHidden(pid: 1, false)
    system.setMinimized(b, false)
    recorder.log.removeAll()
    system.finishRestoring()
    #expect(recorder.log == ["changed \(a) echo", "changed \(b) echo", "changed \(b) by hand"], "shown, shown, and out of the Dock")
  }

  @Test func arborsOwnCallsAreAnsweredAfterTheyReturn() {
    let (system, recorder, _, b, _) = make()
    system.focus(b)
    system.setFrame(CGRect(x: 10.5, y: 20, width: 300.7, height: 200), of: b)
    #expect(recorder.log.isEmpty, "nothing is reported from inside the call")
    #expect(system.frame(of: b) == CGRect(x: 10, y: 20, width: 300, height: 200), "whole points")
    recorder.log.removeAll()
    #expect(system.deliverEchoes() == 1)
    #expect(recorder.log == ["focused \(b)", "changed \(b) echo", "changed \(b) echo"], "resized, and moved")
    recorder.log.removeAll()
    system.focus(b)
    system.setFrame(CGRect(x: 10, y: 20, width: 300, height: 200), of: b)
    system.deliverEchoes()
    #expect(recorder.log.isEmpty, "a window that has the keyboard and the frame already answers with nothing")
  }

  /// That the keyboard has moved is what the Accessibility layer makes of an app coming forward or stepping back. So Arbor's own `focus`
  /// brings it only across apps, and after the echoes of the frames and the window's own report. As recorded on a hosted Mac: within
  /// an app "changed… focused", 13 times of 13; across apps "changed… focused, keyboard moved", 5 times of 7.
  @Test func theKeyboardIsSaidToHaveMovedOnlyAcrossAppsAndAfterTheCall() {
    let (system, recorder, _, b, c) = make()
    system.setFrame(CGRect(x: 10, y: 20, width: 640, height: 420), of: b)
    system.focus(b)
    #expect(recorder.log.isEmpty)
    system.deliverEchoes()
    #expect(recorder.log == ["changed \(b) echo", "focused \(b)"], "within one app")
    recorder.log.removeAll()
    system.setFrame(CGRect(x: 30, y: 40, width: 640, height: 420), of: c)
    system.focus(c)
    #expect(recorder.log.isEmpty)
    system.deliverEchoes()
    #expect(recorder.log == ["changed \(c) echo", "focused \(c)", "keyboard moved"], "to another app")
  }

  @Test func everySwitchCanBeTurnedOff() {
    let (system, recorder, a, b, _) = make(.none)
    system.focus(b)
    system.setFrame(CGRect(x: 10.5, y: 20, width: 300, height: 200), of: b)
    system.deliverEchoes()
    system.userFocus(a)
    recorder.log.removeAll()
    system.close(a)
    let new = system.open(app: "Safari", pid: 1)
    #expect(recorder.log == ["keyboard moved", "destroyed \(a)", "appeared \(new)"])
    #expect(system.frame(of: b)?.minX == 10.5)
    #expect(system.focused == nil)
  }

  // MARK: How many reports one setFrame brings

  /// A hosted Mac's display: a menu bar of 31 points, a Dock of 63.
  private static let hosted = DisplaySnapshot(
    id: DisplayID("hosted"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
    visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true)

  /// Each line was recorded on a hosted Mac: where the window was, what Arbor asked for, how many reports came back. They are from the
  /// traces of one script played on a hosted Mac to be compared with its rehearsal (collab/evidence/reality-mac/traces, journeys
  /// apps, commands and keys), which come into the tree with that comparison. All were made under the first order of calls, size, position,
  /// size, so that is the order they are played by.
  @Test(arguments: [
    // A move alone, and a resize alone.
    (CGRect(x: 270, y: 140, width: 480, height: 348), CGRect(x: 518, y: 140, width: 480, height: 348), 1),
    (CGRect(x: 12, y: 43, width: 494, height: 650), CGRect(x: 12, y: 43, width: 325, height: 650), 1),
    // Both: "resized" and "moved".
    (CGRect(x: 518, y: 220, width: 480, height: 348), CGRect(x: 349, y: 220, width: 326, height: 348), 2),
    (CGRect(x: 12, y: 43, width: 390, height: 319), CGRect(x: 40, y: 71, width: 346, height: 277), 2),
    // The new size does not fit at the old place, downwards or to the right: "resized", "moved", "resized".
    (CGRect(x: 170, y: 220, width: 480, height: 348), CGRect(x: 12, y: 43, width: 494, height: 650), 3),
    (CGRect(x: 687, y: 43, width: 325, height: 650), CGRect(x: 518, y: 43, width: 494, height: 650), 3),
    (CGRect(x: 771, y: 43, width: 241, height: 650), CGRect(x: 272, y: 194, width: 480, height: 348), 3),
    // Out of view it hangs over both edges already, and nothing is cut short.
    (CGRect(x: 1023, y: 677, width: 325, height: 650), CGRect(x: 12, y: 43, width: 1000, height: 650), 2),
  ])
  func aSetFrameBringsAsManyReportsAsOnAMac(from: CGRect, to: CGRect, reports: Int) {
    expectReports(reports, from: from, to: to, framePlan: 1)
  }

  /// The same windows and the same askings by today's order of calls: what shrinks is sized first, what grows is moved first. The rule is the
  /// recorded one, a report for each call that changed something. The numbers are worked out from it: no Mac has been recorded yet.
  @Test(arguments: [
    (CGRect(x: 270, y: 140, width: 480, height: 348), CGRect(x: 518, y: 140, width: 480, height: 348), 1),
    (CGRect(x: 12, y: 43, width: 494, height: 650), CGRect(x: 12, y: 43, width: 325, height: 650), 1),
    (CGRect(x: 518, y: 220, width: 480, height: 348), CGRect(x: 349, y: 220, width: 326, height: 348), 2),
    (CGRect(x: 12, y: 43, width: 390, height: 319), CGRect(x: 40, y: 71, width: 346, height: 277), 2),
    // It grows where it ends up, where the new size fits: "moved", "resized", and nothing is cut.
    (CGRect(x: 170, y: 220, width: 480, height: 348), CGRect(x: 12, y: 43, width: 494, height: 650), 2),
    (CGRect(x: 687, y: 43, width: 325, height: 650), CGRect(x: 518, y: 43, width: 494, height: 650), 2),
    // Wider and shorter: "resized", "moved", "resized".
    (CGRect(x: 771, y: 43, width: 241, height: 650), CGRect(x: 272, y: 194, width: 480, height: 348), 3),
    (CGRect(x: 1023, y: 677, width: 325, height: 650), CGRect(x: 12, y: 43, width: 1000, height: 650), 2),
  ])
  func byTodaysOrderOfCallsNothingIsCutOnTheWay(from: CGRect, to: CGRect, reports: Int) {
    expectReports(reports, from: from, to: to, framePlan: FramePlan.version)
  }

  private func expectReports(_ reports: Int, from: CGRect, to: CGRect, framePlan: Int) {
    let system = FakeWindowSystem(displays: [Self.hosted])
    system.framePlan = framePlan
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: from)
    system.start()
    #expect(system.setFrame(to, of: window) == to)
    #expect(recorder.log.isEmpty, "nothing is reported from inside the call")
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: reports))
  }

  /// macOS does not cut a window below its minimum size, so the first resize is the whole of it. As recorded: 480×348 at 518,220, asked
  /// to be 446×348 at 578,220, took 700×500 and sent "resized" and "moved". By today's order of calls it is asked to shrink, so the same two in the same order.
  @Test(arguments: [1, FramePlan.version]) func aWindowAtItsMinimumIsNotCutShort(framePlan: Int) {
    let system = FakeWindowSystem(displays: [Self.hosted])
    system.framePlan = framePlan
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: CGRect(x: 518, y: 220, width: 480, height: 348))
    system.setMinimumSize(window, CGSize(width: 700, height: 500))
    system.start()
    recorder.log.removeAll()
    #expect(system.setFrame(CGRect(x: 578, y: 220, width: 446, height: 348), of: window) == CGRect(x: 578, y: 220, width: 700, height: 500))
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: 2))
  }

  /// The plan is made for the frame that is asked for, not for the one the window takes. Below its minimum, asked to be narrower and higher, it
  /// is sized (and goes to its minimum), moved and sized again: three reports. From the frame it took, wider and higher, it would be two.
  /// Worked out, like the rows above.
  @Test func thePlanIsMadeForWhatIsAskedNotForWhatIsTaken() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: CGRect(x: 118, y: 60, width: 480, height: 348))
    system.setMinimumSize(window, CGSize(width: 700, height: 500))
    system.start()
    recorder.log.removeAll()
    #expect(system.setFrame(CGRect(x: 178, y: 60, width: 446, height: 600), of: window) == CGRect(x: 178, y: 60, width: 700, height: 600))
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: 3))
  }

  /// Given a minimum since it was last sized, the fake's window takes another size when it is asked only to move. That is the fake's manner: a
  /// Mac's kept its size for as long as it was only moved. As long as the fake has it, both changes are reported, though the plan was one call:
  /// the number goes by what changed.
  @Test func aSizeNobodyAskedForIsReportedToo() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: CGRect(x: 118, y: 60, width: 480, height: 348))
    system.setMinimumSize(window, CGSize(width: 700, height: 500))
    system.start()
    recorder.log.removeAll()
    #expect(system.setFrame(CGRect(x: 178, y: 60, width: 480, height: 348), of: window) == CGRect(x: 178, y: 60, width: 700, height: 500))
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: 2))
  }

  /// Into a frame that hangs over the display's edge a window grows first, by the old plan, and the fake goes by the same plan as the layer. It
  /// fits at the old place: whole, as measured, "resized" and "moved". Moved first it would end 494 wide.
  @Test func intoAFrameThatHangsOverTheEdgeItIsTheOldPlan() {
    expectReports(
      2, from: CGRect(x: 170, y: 220, width: 480, height: 348), to: CGRect(x: 530, y: 43, width: 495, height: 400), framePlan: FramePlan.version)
  }

  /// Where there is no room at the old place either, no order of these calls gets it whole: cut to 337 where it stood, moved, and grown as far
  /// as the edge from where it is then, 424 for 494. Three reports. Worked out from the measured rule. What to do about it is not settled here.
  @Test func withoutRoomAtEitherPlaceItEndsAtTheEdge() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: CGRect(x: 687, y: 43, width: 325, height: 650))
    system.start()
    #expect(system.setFrame(CGRect(x: 600, y: 43, width: 494, height: 650), of: window) == CGRect(x: 600, y: 43, width: 424, height: 650))
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: 3))
  }

  /// No report stands for two calls: asked twice before its app gets round to reporting, a window reports both.
  @Test func twoCallsBringTheReportsOfBoth() {
    let system = FakeWindowSystem(displays: [Self.hosted])
    let recorder = Recorder()
    system.events = recorder
    let window = system.open(app: "Safari", frame: CGRect(x: 12, y: 374, width: 700, height: 300))
    system.start()
    system.setFrame(CGRect(x: 12, y: 43, width: 700, height: 300), of: window)
    system.setFrame(CGRect(x: 1023, y: 767, width: 700, height: 300), of: window)
    system.deliverEchoes()
    #expect(recorder.log == Array(repeating: "changed \(window) echo", count: 2))
  }

  /// The rule, held against every recording of real windows on one display. Calls on one window less than 1.5 s apart count together: their
  /// reports cannot be told apart, and come up to 0.7 s late where Arbor is busy. Left out: what a hand, a drag, a display that comes or
  /// goes, the window's end or the end of the session cuts across; a window that is minimized, hidden, in full screen or on its way out of
  /// it, which is macOS's to move; and reports that say something else (a title, a Space, the Dock), which are no echoes. A few
  /// bundles bring one report more than the rule says, most after a drop or from Terminal, and nobody knows why. Most are one call and
  /// one report: a rule of one report a call, one without the cut and one without the exception for a window that hangs over the
  /// edge all fail this. Each recording is held against the order of calls it says it was made by.
  @Test func theRecordingsBearTheNumberOfReportsOut() throws {
    var (agreeing, differing) = (0, [String]())
    for name in TraceCorpusTests.names {
      let trace = try Trace(contentsOf: TraceCorpusTests.folder.appendingPathComponent(name + ".jsonl"))
      guard trace.header.os != "simulated", trace.header.displays.count == 1 else { continue }
      let system = FakeWindowSystem(displays: trace.header.displays.map { DisplaySnapshot($0) })
      system.framePlan = trace.header.framePlan
      var known = Dictionary(trace.header.windows.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
      var open: [WindowID: (expected: Int, seen: Int, at: Double)] = [:]
      func close(_ window: WindowID) {
        guard let bundle = open.removeValue(forKey: window) else { return }
        if bundle.expected == bundle.seen { agreeing += 1 } else { differing.append("\(name) \(window): \(bundle.expected), not \(bundle.seen)") }
      }
      for entry in trace.entries {
        for (window, bundle) in open where entry.t - bundle.at > 1.5 { close(window) }
        switch entry.line {
        case .displaysChanged(let displays):
          // The Dock changing size is no cut. A display that comes or goes is: macOS moves windows then.
          if displays.count != 1 || system.displayList.count != 1 { open.removeAll() }
          system.displayList = displays.map { DisplaySnapshot($0) }
        case .stop, .dragBegan, .resizeBegan: open.removeAll()
        case .setFrame(let window, let asked, let took, _):
          guard let took, let before = known[window], system.displayList.count == 1,
            !(before.minimized || before.hidden || before.offSpace || before.fullScreen)
          else {
            open[window] = nil
            if let took { known[window]?.frame = took }
            continue
          }
          guard took != before.frame else { continue }
          open[window, default: (0, 0, entry.t)].expected += system.reports(ofTheWayFrom: before.frame, to: took, asked: asked)
          open[window]?.at = entry.t
          known[window]?.frame = took
        case .appeared(let window): known[window.id] = window
        case .destroyed(let window): open[window] = nil
        case .changed(let window, let user):
          var sameButForTheFrame = window
          if let before = known[window.id] { sameButForTheFrame.frame = before.frame }
          let saysSomethingElse = known[window.id].map { $0 != sameButForTheFrame } ?? false
          known[window.id] = window
          if user { open[window.id] = nil } else if !saysSomethingElse { open[window.id]?.seen += 1 }
        default: break
        }
      }
    }
    #expect(agreeing >= 60, "the recordings are there and were read")
    #expect(differing.count * 20 <= agreeing, "\(differing)")
  }
}
