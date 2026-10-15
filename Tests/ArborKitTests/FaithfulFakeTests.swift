import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Writes down what a window system reports, in order.
@MainActor
private final class Recorder: WindowSystemEvents {
  var log: [String] = []
  func windowAppeared(_ window: WindowSnapshot) { log.append("appeared \(window.id)") }
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

  @Test func aNewWindowIsCreatedThenFocused() {
    let (system, recorder, _, _, _) = make()
    let new = system.open(app: "Safari", pid: 1)
    #expect(recorder.log == ["appeared \(new)", "focused \(new)"])
    #expect(system.focused == new)
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
    #expect(recorder.log == ["keyboard moved"], "nothing else is reported from inside the call")
    #expect(system.frame(of: b) == CGRect(x: 10, y: 20, width: 300, height: 200), "whole points")
    recorder.log.removeAll()
    #expect(system.deliverEchoes() == 1)
    #expect(recorder.log == ["focused \(b)", "changed \(b) echo"])
    recorder.log.removeAll()
    system.focus(b)
    system.setFrame(CGRect(x: 10, y: 20, width: 300, height: 200), of: b)
    system.deliverEchoes()
    #expect(recorder.log.isEmpty, "a window that has the keyboard and the frame already answers with nothing")
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
}
