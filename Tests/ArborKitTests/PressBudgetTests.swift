import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What a click that brings another app forward may ask of that app.
///
/// On a Mac `focusedWindow()` is a round trip to the app in front, which answers on its main thread. The moment an app comes forward is the
/// moment it has most to do there: it draws itself as active, and the press that brought it forward is waiting in its queue. Whatever Arbor
/// asks then is served first or in between (rule 6: input is never held). So the questions are counted.
@Suite @MainActor struct PressBudgetTests {
  /// [a | b] docked and c floating, three apps, with the keyboard on a, long enough ago that nothing is still pending. With the focus ring, an
  /// option, switched on: it is one more that wants the answer, so that is where the budget is tight.
  func desk(settings: Settings = .withRing) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Finder", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Calendar", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.advance(by: 2)
    return (h, a, b, c)
  }

  /// The questions asked from the press until nothing is pending any more.
  func questions(_ h: Harness, _ act: () -> Void) -> (atOnce: Int, later: Int) {
    let before = h.system.focusedWindowReads
    act()
    let atOnce = h.system.focusedWindowReads - before
    h.scheduler.advance(by: 2)
    return (atOnce, h.system.focusedWindowReads - before - atOnce)
  }

  /// Four things are heard of such a click: the window has the keyboard, its app is active, the press, the other app is not active any
  /// more. Three of them say that the keyboard may have moved, and each is worth one look: it was two, and three for the first.
  @Test func eachSignThatTheKeyboardMovedIsWorthOneLook() {
    let (h, _, b, c) = desk()
    for window in [b, c, b] {
      let asked = questions(h) { h.system.userClickBringsAppForward(window) }
      // Whether the report is the keyboard (an app in the background reports its windows too), then one for each sign.
      #expect(asked.atOnce <= 4, "a click on \(window) asked the app that came forward \(asked.atOnce) times at once")
      // The look a quarter of a second later, in case macOS had not changed everything at once.
      #expect(asked.later <= 1, "and \(asked.later) times afterwards")
      #expect(h.overlays.scenes[h.display]?.focusRing?.window == window)
    }
    expectWindowsMatchLayout(h)
  }

  /// Without the ring there is one user of the answer fewer, and no question more.
  @Test func withoutTheRingNoMoreIsAsked() {
    var settings = Settings()
    settings.focusRing = false
    let (h, _, b, _) = desk(settings: settings)
    let asked = questions(h) { h.system.userClickBringsAppForward(b) }
    #expect(asked.atOnce <= 4 && asked.later == 0, "\(asked)")
  }

  /// The one answer serves both who need it: the ring goes to the window, and the next command follows the keyboard there.
  @Test func theOneAnswerReachesTheRingAndTheLead() {
    let (h, a, b, _) = desk()
    h.system.userClickBringsAppForward(b)
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == b)
    h.system.userFocusesNothing()
    #expect(h.overlays.scenes[h.display]?.focusRing == nil)
    h.system.userClickBringsAppForward(a)
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == a)
    expectWindowsMatchLayout(h)
  }
}
