import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A window that went into macOS's full screen while it was out of view comes back to the corner, because that is the frame
/// macOS remembers. A pause and a quit bring everything else into view; this one must not be lost either.
@Suite @MainActor struct LeftInFullScreenTests {
  /// `[a | Desktop | b]` framed on `a`, and `b`, out of view, in full screen.
  func makeHarness() -> (Harness, a: WindowID, b: WindowID) {
    // With the gestures on: the zones they ask for have a timer of their own, and "no timer is left" is about every timer.
    let h = Harness(settings: .withGestures)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!isInView(b, h))
    h.system.setFullScreen(b, true)
    return (h, a, b)
  }

  func isInView(_ window: WindowID, _ h: Harness) -> Bool {
    h.system.frame(of: window)!.fractionInside(h.visibleFrame) > 0.9
  }

  @Test func whileArborRunsItIsLaidOutWhenItComesBack() {
    let (h, _, b) = makeHarness()
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func leavingFullScreenDuringAPauseItComesIntoView() {
    let (h, a, b) = makeHarness()
    h.run("pause")
    let framed = h.system.frame(of: a)
    h.scheduler.advance(by: 5)
    h.system.setFullScreen(b, false)
    #expect(!isInView(b, h), "macOS gives it the frame it had")
    h.scheduler.advance(by: 1)
    #expect(h.system.frame(of: b) == CGRect(x: 300, y: 200, width: 640, height: 420), "where it floated before it was docked")
    #expect(h.system.frame(of: a) == framed, "nothing else is touched")
    #expect(!h.system.started && h.system.starts == 1, "no app but its own is asked anything")
    #expect(h.scheduler.pendingKeys.isEmpty, "nor for a window that is back: \(h.scheduler.pendingKeys)")
  }

  @Test func aPauseWithNoSuchWindowLooksForNothing() {
    let (h, _, b) = makeHarness()
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    h.run("pause")
    #expect(h.scheduler.pendingKeys.isEmpty, "\(h.scheduler.pendingKeys)")
  }

  @Test func aWindowInFullScreenThatWasInViewIsNobodysBusiness() {
    let (h, a, b) = makeHarness()
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    h.system.setFullScreen(a, true)
    h.run("pause")
    #expect(h.scheduler.pendingKeys.isEmpty, "\(h.scheduler.pendingKeys)")
  }

  @Test func stillOnItsWayItIsAskedAgain() {
    let (h, _, b) = makeHarness()
    h.system.echoes.flightFromFullScreen = 1.5
    h.run("pause")
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 1)
    #expect(!isInView(b, h))
    h.scheduler.advance(by: 1)
    #expect(isInView(b, h))
  }

  @Test func oneThatNeverGoesIsGivenUp() {
    let (h, _, b) = makeHarness()
    h.system.echoes.flightFromFullScreen = 1000
    h.run("pause")
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 20)
    #expect(h.scheduler.pendingKeys.isEmpty, "\(h.scheduler.pendingKeys)")
  }

  @Test func closedDuringThePauseItIsForgotten() {
    let (h, _, b) = makeHarness()
    h.run("pause")
    h.system.close(b)
    h.scheduler.advance(by: 5)
    #expect(h.scheduler.pendingKeys.isEmpty, "\(h.scheduler.pendingKeys)")
  }

  @Test func ifItsDisplayWentDuringThePauseItComesToTheMainOne() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 1500, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Mail", pid: 12, frame: CGRect(x: 1700, y: 200, width: 640, height: 420))
    h.start()
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.setFullScreen(b, true)
    h.run("pause")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 1)
    #expect(isInView(b, h), "\(h.system.frame(of: b)!)")
    #expect(h.system.frame(of: b)!.size == CGSize(width: 640, height: 420))
  }

  @Test func afterAMinuteItLooksLessOften() {
    let (h, _, b) = makeHarness()
    h.run("pause")
    h.scheduler.advance(by: 61)
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 1.5)
    #expect(!isInView(b, h))
    h.scheduler.advance(by: 1.5)
    #expect(isInView(b, h))
  }

  @Test(arguments: [false, true]) func aFloatingWindowGoesWhereItFloated(makingWay: Bool) {
    let h = Harness(settings: makingWay ? .makingWay : Settings())
    let a = h.system.open(app: "Safari", pid: 11)
    let f = h.system.open(app: "Notes", pid: 13, frame: CGRect(x: 800, y: 300, width: 500, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    // Out of view with the Desktop only if it makes way. As Arbor ships macOS remembers the very frame it floats at.
    #expect(isInView(f, h) == !makingWay)
    h.system.setFullScreen(f, true)
    h.run("pause")
    h.system.setFullScreen(f, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.frame(of: f) == CGRect(x: 800, y: 300, width: 500, height: 300))
  }

  // MARK: Windows Arbor stops arranging

  @Test func excludedWhileInFullScreenItComesIntoViewWhenItLeaves() {
    let (h, a, b) = makeHarness()
    let framed = h.frame(a)
    h.run("exclude com.example.mail")
    #expect(!h.workspace.contains(b))
    h.system.setFullScreen(b, false)
    #expect(h.system.frame(of: b) == CGRect(x: 300, y: 200, width: 640, height: 420), "where it floated before it was docked")
    #expect(h.frame(a) == framed)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("back-from-full-screen") })
  }

  @Test func excludedAndStillOnItsWayItIsAskedAgain() {
    let (h, _, b) = makeHarness()
    h.system.echoes.flightFromFullScreen = 0.9
    h.run("exclude com.example.mail")
    h.system.setFullScreen(b, false)
    #expect(!isInView(b, h))
    h.scheduler.advance(by: 1)
    #expect(isInView(b, h))
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("back-from-full-screen") })
  }

  @Test func excludedThenPausedItIsStillOwedItsPlace() {
    let (h, _, b) = makeHarness()
    h.run("exclude com.example.mail")
    h.run("pause")
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 1)
    #expect(isInView(b, h))
  }

  @Test func theNoteDoesNotOutliveTheWindow() {
    let (h, _, b) = makeHarness()
    h.run("exclude com.example.mail")
    #expect(h.controller.windowsOwedAPlace == [b])
    h.system.close(b)
    #expect(h.controller.windowsOwedAPlace.isEmpty)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  @Test func norArbor() {
    let (first, _, b) = makeHarness()
    first.run("exclude com.example.mail")
    first.controller.shutdown()
    first.controller.start()
    #expect(first.controller.windowsOwedAPlace.isEmpty, "a launch sees to windows left off screen in its own way")
    _ = b
  }

  @Test func excludedPausedAndResumedItIsStillOwedItsPlace() {
    let (h, _, b) = makeHarness()
    h.run("exclude com.example.mail")
    h.run("pause")
    h.run("resume")
    #expect(h.controller.windowsOwedAPlace == [b])
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 1)
    #expect(isInView(b, h))
    #expect(h.controller.windowsOwedAPlace.isEmpty)
  }

  @Test func excludedAndIncludedAgainItIsArrangedLikeAnyWindow() {
    let (h, _, b) = makeHarness()
    h.run("exclude com.example.mail")
    h.run("include com.example.mail")
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    h.run("show-all")
    #expect(isInView(b, h))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func anExcludedWindowsOwnFullScreenIsNobodysBusiness() {
    let (h, _, b) = makeHarness()
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    h.run("exclude com.example.mail")
    let own = h.system.frame(of: b)
    h.system.setFullScreen(b, true)
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    #expect(h.system.frame(of: b) == own)
  }

  @Test func resumingEndsTheLookingAndLaysItOut() {
    let (h, _, b) = makeHarness()
    h.run("pause")
    h.run("resume")
    #expect(!h.scheduler.pendingKeys.contains("back-from-full-screen"))
    h.system.setFullScreen(b, false)
    h.scheduler.advance(by: 2)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func quittingDuringThePauseEndsTheLooking() {
    let (h, _, _) = makeHarness()
    h.run("pause")
    h.controller.shutdown()
    #expect(!h.scheduler.pendingKeys.contains("back-from-full-screen"))
  }

  @Test func afterAQuitTheNextLaunchBringsItBack() {
    let (first, a, b) = makeHarness()
    first.run("show-all")
    first.run("zoom \(a.rawValue)")
    first.controller.shutdown()
    first.system.setFullScreen(b, false)
    #expect(!isInView(b, first), "lost until Arbor runs again")
    let h = Harness(displays: first.system.displayList, saved: first.store.saved)
    for window in first.system.allWindows() {
      let id = h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
      #expect(id == window.id)
    }
    h.start()
    h.run("show-all")
    #expect(isInView(b, h))
    expectWindowsMatchLayout(h, on: h.display)
  }
}
