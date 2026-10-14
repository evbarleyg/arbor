import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Two things wait a quarter of a second in Controller+Focus.swift: another look at a window that was reported as focused and
/// is not (yet), and the look after the window with the keyboard has gone. Neither may put the other off (K1473).
@Suite @MainActor struct FocusTimerTests {
  /// Three apps, a window each, docked and all in view. The first has the keyboard.
  private func makeHarness() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 1001)
    let b = h.system.open(app: "Notes", pid: 1002)
    let c = h.system.open(app: "Mail", pid: 1003)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.system.userFocus(a)
    h.scheduler.advance(by: 1)
    return (h, a, b, c)
  }

  /// The control: its app's last window closes, macOS picks nobody, and nobody reports anything.
  @Test func afterTheLastWindowOfAnAppClosesAWindowInViewGetsTheKeyboard() {
    let (h, a, _, _) = makeHarness()
    h.system.close(a)
    #expect(h.system.focusedWindow() == nil, "macOS picked none")
    h.scheduler.advance(by: 0.3)
    #expect(h.system.focusedWindow() != nil)
  }

  @Test func aBackgroundAppsReportDoesNotPutOffTheLookAfterALoss() {
    let (h, a, _, c) = makeHarness()
    h.system.close(a)
    h.scheduler.advance(by: 0.1)
    h.system.backgroundFocus(c)
    #expect(h.system.focusedWindow() == nil, "a report, not the keyboard")
    h.scheduler.advance(by: 0.2)
    #expect(h.system.focusedWindow() != nil, "a quarter of a second after the loss")
    h.scheduler.advance(by: 3)
    #expect(h.system.focusedWindow() != nil, "or ever")
    #expect(waiting(h).isEmpty)
  }

  private func isInView(_ id: WindowID, _ h: Harness) -> Bool {
    h.workspace.tree.windows(under: h.workspace.camera).contains(id)
  }

  /// The control: macOS can report a window before it says that the window has the keyboard, and says nothing more.
  @Test func aWindowReportedBeforeItHasTheKeyboardIsLookedAtAgain() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.backgroundFocus(b)
    #expect(!isInView(b, h))
    h.system.focused = b
    h.scheduler.advance(by: 0.3)
    #expect(isInView(b, h), "typing into a window out of view is worse than a view that moves")
  }

  @Test func aBackgroundAppsReportDoesNotPutOffTheSecondLookAtTheWindowTakingTheKeyboard() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.backgroundFocus(b)
    h.scheduler.advance(by: 0.1)
    h.system.backgroundFocus(c)
    h.system.focused = b
    h.scheduler.advance(by: 3)
    #expect(isInView(b, h))
    #expect(waiting(h).isEmpty)
  }

  /// Not the focus ring's own (`focus-ring`, `focus-ring-again`).
  private func waiting(_ h: Harness) -> [String] {
    h.scheduler.pendingKeys.filter { $0 == "focus-after-loss" || $0.hasPrefix("focus-again-") }.sorted()
  }

  /// The other way round: the look after a loss does not put off the second look at a window.
  @Test func aLossDoesNotPutOffTheSecondLookAtTheWindowTakingTheKeyboard() {
    let (h, a, b, c) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.system.backgroundFocus(b)
    h.scheduler.advance(by: 0.1)
    h.system.close(a)
    #expect(waiting(h).count == 2)
    h.system.focused = b
    h.scheduler.advance(by: 3)
    #expect(h.system.focusedWindow() != nil)
    #expect(h.system.focusedWindow().map { isInView($0, h) } == true, "whoever has the keyboard is in view")
    #expect(waiting(h).isEmpty)
    _ = c
  }

  @Test func onceAWindowHasTheKeyboardNothingWaits() {
    let (h, a, b, c) = makeHarness()
    h.system.backgroundFocus(b)
    h.system.backgroundFocus(c)
    #expect(waiting(h) == ["focus-again-\(b.rawValue)", "focus-again-\(c.rawValue)"])
    h.system.userFocus(a)
    #expect(waiting(h).isEmpty)
  }

  @Test func reportsAboutOneWindowHoldOneTimerAndItGivesUp() {
    let (h, _, b, _) = makeHarness()
    for _ in 0..<20 { h.system.backgroundFocus(b) }
    #expect(waiting(h).count == 1)
    h.scheduler.advance(by: 3)
    #expect(waiting(h).isEmpty, "a window that never gets the keyboard is not looked at for ever")
  }

  @Test func aWindowThatClosesWhileItIsWaitedForLeavesNothingBehind() {
    let (h, _, b, _) = makeHarness()
    h.system.backgroundFocus(b)
    h.system.close(b)
    h.scheduler.advance(by: 1)
    #expect(waiting(h).isEmpty)
  }

  @Test(arguments: [true, false]) func stoppingLeavesNothingWaiting(forAPause: Bool) {
    let (h, a, b, c) = makeHarness()
    h.system.close(a)
    h.system.backgroundFocus(b)
    h.system.backgroundFocus(c)
    #expect(waiting(h).count == 3)
    if forAPause { h.run("pause") } else { h.controller.shutdown() }
    #expect(waiting(h).isEmpty)
  }

  /// No race is needed. A report is not the keyboard: the window that has it is still the one whose going is a loss.
  @Test func aBackgroundAppsReportLongAgoDoesNotMakeArborForgetWhoHasTheKeyboard() {
    let (h, a, b, _) = makeHarness()
    h.system.backgroundFocus(b)
    h.scheduler.advance(by: 5)
    #expect(h.system.focusedWindow() == a)
    h.system.close(a)
    #expect(h.system.focusedWindow() == nil, "macOS picked none")
    h.scheduler.advance(by: 1)
    #expect(h.system.focusedWindow() != nil)
  }
}
