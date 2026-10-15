import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The decisions behind the Accessibility layer (F17 and the review of 2026-10-14). The code that talks to
/// macOS cannot run in tests, so what it decides is decided here.
/// `#expect` cannot call a mutating method, so the tests keep these value types in a box.
final class Box<Value> {
  var value: Value
  init(_ value: Value) { self.value = value }
}

extension Box where Value == EnforcementLimiter {
  func allowsPuttingBack(_ window: WindowID, at time: TimeInterval) -> Bool { value.allowsPuttingBack(window, at: time) }
  func reset(_ windows: [WindowID]) { value.reset(windows) }
  var givenUp: Set<WindowID> { value.givenUp }
}

extension Box where Value == EchoFilter {
  func expect(_ frame: CGRect, for window: WindowID, at time: TimeInterval) { value.expect(frame, for: window, at: time) }
  func isEcho(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> Bool { value.isEcho(frame, of: window, at: time) }
  func judge(_ frame: CGRect, of window: WindowID, at time: TimeInterval) -> EchoFilter.Verdict {
    value.judge(frame, of: window, at: time)
  }
  func forget(_ window: WindowID) { value.forget(window) }
  var count: Int { value.count }
}

@Suite struct EnforcementLimiterTests {
  let w = WindowID(7)

  @Test func theFourthPutBackWithinThreeSecondsIsRefused() {
    let limiter = Box(EnforcementLimiter())
    #expect(limiter.allowsPuttingBack(w, at: 10.0))
    #expect(limiter.allowsPuttingBack(w, at: 10.5))
    #expect(limiter.allowsPuttingBack(w, at: 11.0))
    #expect(!limiter.allowsPuttingBack(w, at: 11.5))
    #expect(limiter.givenUp == [w])
    #expect(!limiter.allowsPuttingBack(w, at: 100), "giving up lasts until the layout changes")
  }

  @Test func putBacksSpreadOverTimeAreAllAllowed() {
    let limiter = Box(EnforcementLimiter())
    for step in 0..<20 { #expect(limiter.allowsPuttingBack(w, at: Double(step) * 1.6)) }
    #expect(limiter.givenUp.isEmpty)
  }

  @Test func eachWindowIsCountedOnItsOwn() {
    let limiter = Box(EnforcementLimiter())
    let other = WindowID(8)
    for _ in 0..<3 { #expect(limiter.allowsPuttingBack(w, at: 1)) }
    #expect(!limiter.allowsPuttingBack(w, at: 1))
    #expect(limiter.allowsPuttingBack(other, at: 1))
  }

  @Test func aResetGivesAFreshStart() {
    let limiter = Box(EnforcementLimiter())
    for _ in 0..<4 { _ = limiter.allowsPuttingBack(w, at: 1) }
    limiter.reset([w])
    #expect(limiter.givenUp.isEmpty)
    #expect(limiter.allowsPuttingBack(w, at: 1.1))
  }

  @Test func aClockThatJumpsBackDoesNotCountOldPutBacksForEver() {
    let limiter = Box(EnforcementLimiter())
    for _ in 0..<3 { _ = limiter.allowsPuttingBack(w, at: 1000) }
    #expect(limiter.allowsPuttingBack(w, at: 5))
  }
}

@Suite struct WindowGrabTests {
  let frame = CGRect(x: 100, y: 100, width: 600, height: 400)
  var titleBar: CGPoint { CGPoint(x: 400, y: 114) }

  func verdict(pressedAt: CGPoint, now: CGRect, pointer: CGPoint? = nil) -> WindowGrab.Verdict {
    WindowGrab.classify(pressedAt: pressedAt, frameAtPress: frame, frameNow: now, pointerNow: pointer ?? pressedAt)
  }

  @Test func aWindowThatFollowsThePointerIsBeingDragged() {
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: -8, dy: 6)) == .drag)
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 0, dy: 1)) == .drag)
  }

  @Test func nothingIsDecidedWhileTheWindowStandsStillAndThePointerIsNear() {
    #expect(verdict(pressedAt: titleBar, now: frame) == .undecided)
    #expect(verdict(pressedAt: titleBar, now: frame, pointer: CGPoint(x: 410, y: 120)) == .undecided)
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 0.4, dy: 0)) == .undecided, "less than a point is noise")
  }

  @Test func aPointerThatTravelsWhileTheWindowStandsStillIsNotAboutTheWindow() {
    let inside = CGPoint(x: 300, y: 300)
    #expect(verdict(pressedAt: inside, now: frame, pointer: CGPoint(x: 330, y: 300)) == .neither)
  }

  // MARK: A press that is looked at again and again

  /// The looks of one press, in order: where the window and the pointer were at each.
  func verdicts(pressedAt: CGPoint, _ looks: [(now: CGRect, pointer: CGPoint)]) -> [WindowGrab.Verdict] {
    var memory = WindowGrab.Memory()
    return looks.map {
      WindowGrab.judge(pressedAt: pressedAt, frameAtPress: frame, frameNow: $0.now, pointerNow: $0.pointer, memory: &memory)
    }
  }

  /// The pointer after so many steps of 27 points, down and to the left.
  func pointer(_ steps: CGFloat) -> CGPoint { CGPoint(x: titleBar.x - 24 * steps, y: titleBar.y + 12.7 * steps) }

  /// Seen on a hosted Mac: the pointer went 27 points a step, and at the first look the window had not stirred.
  @Test func aWindowThatStartsLateIsStillBeingDragged() {
    #expect(
      verdicts(pressedAt: titleBar, [(frame, pointer(1)), (frame, pointer(2)), (frame.offsetBy(dx: -48, dy: 25), pointer(3))])
        == [.neither, .neither, .drag])
    #expect(
      verdicts(pressedAt: titleBar, [(frame, pointer(1)), (frame.offsetBy(dx: -240, dy: 127), pointer(10))]).last == .drag,
      "it has caught up in one leap, and the hand may be at rest by now")
  }

  /// It need not be under the pointer, as long as it goes on.
  @Test func aWindowThatStartsLateAndTrailsThePointerIsInHandAtTheSecondLook() {
    func looks(_ first: (CGFloat, CGFloat), _ second: (CGFloat, CGFloat)) -> [WindowGrab.Verdict] {
      verdicts(
        pressedAt: titleBar,
        [
          (frame, pointer(1)), (frame.offsetBy(dx: first.0, dy: first.1), pointer(10)),
          (frame.offsetBy(dx: second.0, dy: second.1), pointer(11)),
        ])
    }
    #expect(looks((-192, 102), (-216, 114)) == [.neither, .neither, .drag], "its app's reports are a step behind")
    #expect(looks((-242, 1), (-266, 1)) == [.neither, .neither, .drag], "macOS held it back one way")
    #expect(
      looks((-307, 127), (-331, 140)) == [.neither, .neither, .drag],
      "a pointer in steps of 66 points is a step further on by the time the window is read")
  }

  /// One jump cannot be told from a late start at one look. At two it can: this window then stands still.
  @Test func aWindowThatJumpsOnceThePointersWayDuringASelectionIsNotInHand() {
    let inside = CGPoint(x: 300, y: 300)
    for jump: CGFloat in [40, 80] {
      let jumped = frame.offsetBy(dx: jump, dy: 0)
      let looks = [(frame, CGPoint(x: 330, y: 300))] + (0..<4).map { (jumped, CGPoint(x: 420 + CGFloat($0) * 10, y: 300)) }
      #expect(verdicts(pressedAt: inside, looks) == Array(repeating: .neither, count: 5), "a jump of \(jump) points")
    }
  }

  @Test func aWindowThatGoesItsOwnWayDuringASelectionIsNotInHand() {
    let (inside, far) = (CGPoint(x: 300, y: 300), CGPoint(x: 420, y: 300))
    func late(_ now: CGRect) -> WindowGrab.Verdict? { verdicts(pressedAt: inside, [(frame, far), (now, far)]).last }
    #expect(late(frame) == .neither)
    #expect(late(frame.offsetBy(dx: -60, dy: 0)) == .neither, "against the pointer")
    #expect(late(frame.offsetBy(dx: 0, dy: 200)) == .neither, "across it")
    #expect(late(frame.offsetBy(dx: 400, dy: 0)) == .neither, "far past it")
    #expect(late(CGRect(x: 160, y: 100, width: 700, height: 400)) == .neither, "at another size")
  }

  @Test func anEdgeThatFollowsLateIsStillAnEdgeResize() {
    let (edge, far) = (CGPoint(x: 699, y: 300), CGPoint(x: 739, y: 300))
    #expect(
      verdicts(pressedAt: edge, [(frame, far), (CGRect(x: 100, y: 100, width: 640, height: 400), far)]) == [.neither, .resize])
  }

  /// Until the pointer has gone far nothing is remembered, and a look is what it always was.
  @Test func aPressThatIsDecidedAtOnceIsJudgedAsBefore() {
    #expect(verdicts(pressedAt: titleBar, [(frame, titleBar), (frame.offsetBy(dx: -8, dy: 6), titleBar)]) == [.undecided, .drag])
  }

  @Test func aSizeChangeAfterAPressOnTheBorderIsAnEdgeResize() {
    let wider = CGRect(x: 100, y: 100, width: 660, height: 400)
    #expect(verdict(pressedAt: CGPoint(x: 699, y: 300), now: wider) == .resize)
    #expect(verdict(pressedAt: CGPoint(x: 704, y: 300), now: wider) == .resize, "the resize area reaches outside the window")
    // The left and top edges move the origin too.
    #expect(verdict(pressedAt: CGPoint(x: 101, y: 300), now: CGRect(x: 60, y: 100, width: 640, height: 400)) == .resize)
    #expect(verdict(pressedAt: CGPoint(x: 103, y: 497), now: CGRect(x: 60, y: 100, width: 640, height: 440)) == .resize)
  }

  /// H5: macOS zooms a window whose title bar is double-clicked. That must never move a seam.
  @Test func aSizeChangeAfterAPressInTheTitleBarIsNotAnEdgeResize() {
    let zoomed = CGRect(x: 0, y: 25, width: 1440, height: 875)
    #expect(verdict(pressedAt: titleBar, now: zoomed) != .resize)
    #expect(verdict(pressedAt: titleBar, now: CGRect(x: 100, y: 100, width: 700, height: 400)) == .neither)
  }

  /// A window macOS had tiled or zoomed gets its old size back as soon as it is dragged away.
  @Test func aWindowThatChangesSizeWhileItIsDraggedByItsTitleBarIsStillDragged() {
    #expect(verdict(pressedAt: titleBar, now: CGRect(x: 250, y: 130, width: 300, height: 200)) == .drag)
  }

  /// macOS shows its desktop by sweeping every window aside, and a press on the strip of one that still shows brings them all
  /// back, with the button still down. As a hosted Mac listed it (macOS 26, 1024 × 768,
  /// `collab/reports/2026-10-14-the-desktop-is-shown.md`): a docked window, pressed at 6,350 by a hand that slipped less than a point
  /// before Arbor looked.
  @Test func aWindowThatComesBackFromTheSideOfTheDisplayUnderAPointerAtRestIsNotInTheHand() {
    let verdict = WindowGrab.classify(
      pressedAt: CGPoint(x: 6, y: 350), frameAtPress: CGRect(x: -313, y: 15, width: 325, height: 653),
      frameNow: CGRect(x: 12, y: 43, width: 325, height: 653), pointerNow: CGPoint(x: 6.75, y: 350.75))
    #expect(verdict == .neither)
  }

  @Test func norOneThatComesBackFromAboveOrBelow() {
    for (swept, home) in [(-306.0, 100.0), (756.0, 360.0)] {
      let strip = CGPoint(x: 512, y: swept < 0 ? 36 : 762)
      let verdict = WindowGrab.classify(
        pressedAt: strip, frameAtPress: CGRect(x: 349, y: swept, width: 326, height: 348),
        frameNow: CGRect(x: 349, y: home, width: 326, height: 348), pointerNow: CGPoint(x: strip.x + 3, y: strip.y + 3))
      #expect(verdict == .neither, "from \(swept)")
    }
  }

  @Test func norOneThatSomebodyTriesToPullInByItsStrip() {
    // The window is back long before the hand has gone as far as it has.
    let verdict = WindowGrab.classify(
      pressedAt: CGPoint(x: 6, y: 350), frameAtPress: CGRect(x: -313, y: 15, width: 325, height: 653),
      frameNow: CGRect(x: 12, y: 43, width: 325, height: 653), pointerNow: CGPoint(x: 26, y: 352))
    #expect(verdict == .neither)
  }

  @Test func aWindowListedAtTheSideOfTheDisplayIsNotWhereItsAppHasIt() {
    let docked = CGRect(x: 12, y: 43, width: 325, height: 653)
    #expect(WindowGrab.isListedElsewhere(CGRect(x: -313, y: 15, width: 325, height: 653), than: docked))
    #expect(WindowGrab.isListedElsewhere(CGRect(x: -313, y: 15, width: 325, height: 653), than: docked.insetBy(dx: 0, dy: 160)))
    #expect(WindowGrab.isListedElsewhere(CGRect(x: 349, y: -306, width: 326, height: 348), than: CGRect(x: 349, y: 100, width: 326, height: 348)))
  }

  @Test func aWindowAtRestIsWhereItsAppHasItGiveOrTakeAMoment() {
    #expect(!WindowGrab.isListedElsewhere(frame, than: frame))
    #expect(!WindowGrab.isListedElsewhere(frame.offsetBy(dx: 9, dy: -4), than: frame), "Accessibility is a step behind")
    #expect(!WindowGrab.isListedElsewhere(frame.insetBy(dx: 5, dy: 5), than: frame))
  }

  // What a press takes hold of. `frame` is where the window's app last had it.

  let window = WindowID(101)
  let below = WindowGrab.Top.known(
    WindowID(102), listed: CGRect(x: 0, y: 40, width: 1400, height: 800), believed: CGRect(x: 0, y: 40, width: 1400, height: 800))

  /// The press was on the title bar, and the pointer has gone so far by the time it is looked at.
  func hold(
    pressedAt: CGPoint? = nil, pointerWent x: CGFloat, _ y: CGFloat, listed: CGRect, believed: CGRect? = nil,
    behind: WindowGrab.Top? = nil, desktopIsShown: Bool = false
  ) -> WindowGrab.Hold {
    let pressedAt = pressedAt ?? titleBar
    let now = CGPoint(x: pressedAt.x + x, y: pressedAt.y + y)
    let top = WindowGrab.Top.known(window, listed: listed, believed: believed ?? frame)
    func shows(at point: CGPoint) -> WindowGrab.Top? { listed.insetBy(dx: -4, dy: -4).contains(point) ? top : behind }
    return WindowGrab.hold(
      pressedAt: pressedAt, pointerNow: now, underPress: shows(at: pressedAt), underPointer: shows(at: now),
      desktopIsShown: desktopIsShown)
  }

  @Test func aPressThatIsServedOnTimeTakesHoldOfWhatIsUnderIt() {
    #expect(hold(pointerWent: 0, 0, listed: frame) == .init(window: window, point: titleBar, frame: frame))
    #expect(WindowGrab.hold(pressedAt: titleBar, pointerNow: titleBar, underPress: nil, underPointer: nil) == .init(point: titleBar))
    #expect(
      WindowGrab.hold(pressedAt: titleBar, pointerNow: titleBar, underPress: .stranger, underPointer: .stranger)
        == .init(point: titleBar, isSettled: true))
  }

  @Test func aTrembleAndFramesThatDifferALittleMakeNoDifference() {
    // To go by the app's word here would make a drag of the difference, at the first look.
    for ahead in [1, 2, 9, 30] as [CGFloat] {
      let listed = frame.offsetBy(dx: ahead, dy: 0)
      #expect(hold(pointerWent: 2, 0, listed: listed) == .init(window: window, point: titleBar, frame: listed), "\(ahead)")
    }
    // A selection in a text, served late, in an app whose two frames differ for good.
    let inside = CGPoint(x: 300, y: 300)
    let listed = frame.offsetBy(dx: 2, dy: 2)
    #expect(hold(pressedAt: inside, pointerWent: 90, 40, listed: listed) == .init(window: window, point: inside, frame: listed))
  }

  @Test func servedLateItTakesHoldOfTheWindowInTheHandAsItsAppLastHadIt() {
    let expected = WindowGrab.Hold(window: window, point: titleBar, frame: frame, isInTheHand: true)
    // 300 ms late, the app not heard since. Sideways the window is still under the press, otherwise it has left.
    #expect(hold(pointerWent: 60, 0, listed: frame.offsetBy(dx: 60, dy: 0)) == expected)
    #expect(hold(pointerWent: 100, 75, listed: frame.offsetBy(dx: 100, dy: 75)) == expected)
    #expect(hold(pointerWent: 100, 75, listed: frame.offsetBy(dx: 100, dy: 75), behind: below) == expected, "over a tile")
    #expect(hold(pointerWent: 100, 0, listed: frame.offsetBy(dx: 40, dy: 0)) == expected, "a window trails the pointer")
    // The menu bar stops the window, and the pointer goes on, off the window.
    #expect(hold(pointerWent: 90, -110, listed: frame.offsetBy(dx: 90, dy: -60)) == expected)
    // Its app has been heard all along, and is a tenth of a second behind.
    let heard = frame.offsetBy(dx: 80, dy: 60)
    #expect(
      hold(pointerWent: 100, 75, listed: frame.offsetBy(dx: 100, dy: 75), believed: heard, behind: below)
        == .init(window: window, point: titleBar, frame: heard, isInTheHand: true))
  }

  @Test func anEdgeInTheHandIsJudgedFromThePressIfItsAppHasNotBeenHeardSince() {
    let edge = CGPoint(x: 100, y: 300)
    var wider = frame
    wider.origin.x -= 50
    wider.size.width += 50
    let expected = WindowGrab.Hold(window: window, point: edge, frame: frame, isInTheHand: true)
    #expect(hold(pressedAt: edge, pointerWent: -50, 2, listed: wider) == expected)
    // It trails the pointer, which is well off the edge.
    #expect(hold(pressedAt: edge, pointerWent: -80, 2, listed: wider) == expected)
  }

  @Test func andFromThePointersPlaceIfItHas() {
    let edge = CGPoint(x: 100, y: 300)
    var wider = frame
    wider.origin.x -= 50
    wider.size.width += 50
    let now = CGPoint(x: 50, y: 302)
    #expect(hold(pressedAt: edge, pointerWent: -50, 2, listed: wider, believed: wider) == .init(window: window, point: now, frame: wider))
    var behind = wider
    behind.origin.x += 15
    behind.size.width -= 15
    #expect(hold(pressedAt: edge, pointerWent: -50, 2, listed: wider, believed: behind) == .init(window: window, point: now, frame: wider))
    // Made narrower, it has left the press altogether, and is known by being a step ahead of its app.
    let narrower = CGRect(x: 150, y: 100, width: 550, height: 400)
    #expect(
      hold(pressedAt: edge, pointerWent: 50, 2, listed: narrower, believed: CGRect(x: 135, y: 100, width: 565, height: 400))
        == .init(window: window, point: CGPoint(x: 150, y: 302), frame: narrower, isInTheHand: true))
  }

  @Test func aWindowThatHasNotStirredIsJudgedFromThePress() {
    // It starts late, or its app does: the pointer is well on its way, on the window still.
    #expect(hold(pointerWent: 120, 0, listed: frame) == .init(window: window, point: titleBar, frame: frame))
    let edge = CGPoint(x: 100, y: 300)
    #expect(hold(pressedAt: edge, pointerWent: 40, 0, listed: frame) == .init(window: window, point: edge, frame: frame))
  }

  @Test func aWindowAtRestThatThePointerHasComeToIsNotTakenHoldOf() {
    let wallpaper = CGPoint(x: 40, y: 700)
    #expect(hold(pressedAt: wallpaper, pointerWent: 300, -300, listed: frame) == .init(point: wallpaper))
    #expect(hold(pressedAt: wallpaper, pointerWent: 300, -300, listed: frame.offsetBy(dx: 3, dy: -3)) == .init(point: wallpaper))
  }

  @Test func norIsOneThatWentAnotherWayOrFartherThanThePointer() {
    let wallpaper = CGPoint(x: 40, y: 700)
    for (x, y) in [(-25, 25), (0, 30), (-30, 0)] as [(CGFloat, CGFloat)] {
      #expect(hold(pressedAt: wallpaper, pointerWent: 300, -300, listed: frame.offsetBy(dx: x, dy: y)) == .init(point: wallpaper))
    }
    // Still under the press, and listed far from its app's word: that is what a swept window looks like.
    #expect(hold(pointerWent: 60, 0, listed: frame.offsetBy(dx: 200, dy: 0)) == .init(point: titleBar, isSettled: true))
    #expect(hold(pointerWent: 60, 0, listed: frame.offsetBy(dx: -60, dy: 0)) == .init(point: titleBar, isSettled: true))
  }

  @Test func aPressOnAStripTakesHoldOfNothingHoweverFarItIsPulledAndHoweverLateItIsServed() {
    // A strip lies at the side of the display, and can only be pulled inwards: the other way than the window was swept.
    let docked = CGRect(x: 12, y: 43, width: 325, height: 653)
    let swept = CGRect(x: -313, y: 15, width: 325, height: 653)
    let strip = CGPoint(x: 6, y: 350)
    for pull in [0, 3, 150, 325, 600] as [CGFloat] {
      #expect(
        hold(pressedAt: strip, pointerWent: pull, 3, listed: swept, believed: docked) == .init(point: strip, isSettled: true),
        "\(pull) points")
    }
    // Under the menu bar, where the window's own place reaches as far as the strip.
    let above = CGRect(x: 349, y: -306, width: 326, height: 348)
    let top = CGPoint(x: 500, y: 36)
    #expect(
      hold(pressedAt: top, pointerWent: 0, 400, listed: above, believed: above.offsetBy(dx: 0, dy: 340))
        == .init(point: top, isSettled: true))
  }

  @Test func norDoesAPressOnTheBareDesktopWhosePointerComesToAStrip() {
    // The way that window was swept. Its app has it nowhere near the press.
    let docked = CGRect(x: 1000, y: 43, width: 400, height: 653)
    let desktop = CGPoint(x: 900, y: 300)
    #expect(
      hold(pressedAt: desktop, pointerWent: 494, 0, listed: docked.offsetBy(dx: 388, dy: 0), believed: docked)
        == .init(point: desktop))
  }

  @Test func whileTheDesktopIsShownNothingIsInTheHand() {
    // Where the windows are, by Accessibility, the desktop is bare. A rubber band begins over the left edge of the right tile, which with
    // two tiles is the middle of the display, and is thrown to the right edge of the display, where that tile's strip is.
    let tile = CGRect(x: 600, y: 43, width: 412, height: 600)
    let swept = tile.offsetBy(dx: 412, dy: 0)
    for x in [595, 600, 605] as [CGFloat] {
      let desktop = CGPoint(x: x, y: 300)
      #expect(
        hold(pressedAt: desktop, pointerWent: 1018 - x, 0, listed: swept, believed: tile, desktopIsShown: true) == .init(point: desktop),
        "from \(x)")
      // The control: that is what a window looks like whose left edge a hand has taken so far.
      #expect(hold(pressedAt: desktop, pointerWent: 1018 - x, 0, listed: swept, believed: tile).isInTheHand, "from \(x)")
    }
    // A press on the strip itself is settled, as ever.
    let strip = CGPoint(x: 1018, y: 300)
    #expect(
      hold(pressedAt: strip, pointerWent: -3, 2, listed: swept, believed: tile, desktopIsShown: true)
        == .init(point: strip, isSettled: true))
  }

  @Test func aWindowThatGoesThePointersWayUnderASelectionGoesByItself() {
    // A hand takes a window by its top or by an edge. In the middle of it, it selects text.
    let inside = CGPoint(x: 300, y: 300)
    for back in [20, 60, 150] as [CGFloat] {
      let listed = frame.offsetBy(dx: back, dy: 0)
      #expect(!hold(pressedAt: inside, pointerWent: 200, 0, listed: listed).isInTheHand, "\(back)")
    }
    #expect(hold(pressedAt: CGPoint(x: 300, y: 150), pointerWent: 200, 0, listed: frame.offsetBy(dx: 60, dy: 0)).isInTheHand, "a toolbar")
  }

  @Test func norIsAWindowInTheHandThatMovedAsThePointerCameToTheMiddleOfIt() {
    let wallpaper = CGPoint(x: 40, y: 700)
    let listed = frame.offsetBy(dx: 30, dy: -30)
    #expect(hold(pressedAt: wallpaper, pointerWent: 300, -400, listed: listed) == .init(point: wallpaper))
  }

  @Test func aWindowHeldByItsTitleBarThatHasNotStirredIsJudgedFromThePressWhereverThePointerHasGotTo() {
    // Along the bar as far as the corner. Judged from there, the window's catching up would be a leap.
    #expect(hold(pointerWent: -297, 0, listed: frame) == .init(window: window, point: titleBar, frame: frame))
    #expect(hold(pointerWent: 296, 2, listed: frame) == .init(window: window, point: titleBar, frame: frame))
  }

  @Test func aWindowFlungAcrossTheDisplayIsStillDragged() {
    // The first look comes late, and the window has gone as far as the pointer, or not quite.
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 480, dy: 90), pointer: CGPoint(x: 880, y: 204)) == .drag)
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 430, dy: 80), pointer: CGPoint(x: 880, y: 204)) == .drag)
    // The menu bar stops the window and not the pointer.
    #expect(verdict(pressedAt: titleBar, now: frame.offsetBy(dx: 5, dy: -75), pointer: CGPoint(x: 405, y: 2)) == .drag)
  }

  @Test func nearTheEdgeMeansWithinTenPointsOfTheBorderOnEitherSide() {
    #expect(WindowGrab.isNearEdge(CGPoint(x: 100, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 109, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 91, y: 300), of: frame))
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 111, y: 300), of: frame))
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 89, y: 300), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 400, y: 495), of: frame))
    #expect(WindowGrab.isNearEdge(CGPoint(x: 400, y: 104), of: frame), "the top few points of the title bar resize")
    #expect(!WindowGrab.isNearEdge(titleBar, of: frame), "the middle of the title bar does not")
    #expect(!WindowGrab.isNearEdge(CGPoint(x: 400, y: 300), of: frame))
  }

  @Test func everyPointOfATinyWindowIsNearItsEdge() {
    let tiny = CGRect(x: 0, y: 0, width: 12, height: 12)
    #expect(WindowGrab.isNearEdge(CGPoint(x: 6, y: 6), of: tiny))
  }
}

@Suite struct EchoFilterTests {
  let w = WindowID(7)
  let set = CGRect(x: 12, y: 37, width: 700, height: 851)

  @Test func anythingRightAfterAMoveIsAnEcho() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(filter.isEcho(CGRect(x: 12, y: 37, width: 640, height: 420), of: w, at: 100.1), "position set, size not yet")
  }

  @Test func theExpectedFrameIsAnEchoForASecond() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(filter.isEcho(set.offsetBy(dx: 1, dy: -2), of: w, at: 100.9))
    #expect(!filter.isEcho(set, of: w, at: 101.1))
  }

  @Test func anotherFrameAfterTheFirstMomentIsSomeoneElsesMove() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(!filter.isEcho(set.offsetBy(dx: 30, dy: 0), of: w, at: 100.2))
  }

  @Test func windowsNobodyMovedHaveNoEchoes() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    #expect(!filter.isEcho(set, of: WindowID(8), at: 100.01))
  }

  @Test func aClockBehindTheExpectationDoesNotKeepItFresh() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 4000)
    #expect(!filter.isEcho(set.offsetBy(dx: 50, dy: 0), of: w, at: 400))
    #expect(filter.count == 0)
  }

  /// Seen in real traces: a window resized itself 0.1 s after being docked, and stayed out of its slot for good.
  @Test func anotherFrameInTheFirstMomentIsLookedAtAgain() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    let own = CGRect(x: 12, y: 37, width: 640, height: 851)
    #expect(filter.judge(own, of: w, at: 100.1) == .early)
    #expect(filter.judge(set, of: w, at: 100.1) == .echo)
    #expect(filter.judge(own, of: w, at: 100.2) == .other)
    #expect(filter.value.hasStrayed(w, now: own), "still there when the dust has settled: the app's own doing")
    #expect(!filter.value.hasStrayed(w, now: set.offsetBy(dx: 1, dy: 1)), "a stage of Arbor's move: it arrived")
    #expect(!filter.value.hasStrayed(WindowID(8), now: own), "nothing is expected of a window nobody moved")
  }

  @Test func aNewerMoveIsWhatCounts() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    let next = set.offsetBy(dx: 300, dy: 0)
    filter.expect(next, for: w, at: 100.2)
    #expect(!filter.value.hasStrayed(w, now: next))
    #expect(filter.value.hasStrayed(w, now: set))
  }

  @Test func expectationsDoNotPileUp() {
    let filter = Box(EchoFilter())
    filter.expect(set, for: w, at: 100)
    filter.expect(set, for: WindowID(8), at: 100)
    _ = filter.isEcho(set, of: w, at: 200)
    filter.forget(WindowID(8))
    #expect(filter.count == 0)
  }
}

@Suite struct FramePlanTests {
  let known = CGRect(x: 12, y: 37, width: 700, height: 851)

  @Test func aWindowThatOnlyChangesPlaceNeedsOneCall() {
    let parked = CGRect(x: 1439, y: 899, width: 700, height: 851)
    #expect(FramePlan.steps(from: known, to: parked) == [.position])
  }

  @Test func aChangeOfSizeTakesTheFullPlan() {
    #expect(FramePlan.steps(from: known, to: CGRect(x: 12, y: 37, width: 701, height: 851)) == FramePlan.full)
    #expect(FramePlan.steps(from: nil, to: known) == FramePlan.full)
  }

  @Test func evenAWindowBelievedToBeInPlaceIsMoved() {
    #expect(FramePlan.steps(from: known, to: known) == [.position], "the belief may be out of date")
  }

  @Test func aWrongBeliefAboutTheSizeIsCaughtByReadingBack() {
    let target = CGRect(x: 1439, y: 899, width: 700, height: 851)
    let surprise = CGRect(x: 1439, y: 899, width: 500, height: 851)
    #expect(FramePlan.needsFullPlan(after: [.position], result: surprise, target: target))
    #expect(!FramePlan.needsFullPlan(after: [.position], result: target, target: target))
    // macOS keeps title bars on screen, so a parked window ends up higher than asked. That is not a reason.
    #expect(!FramePlan.needsFullPlan(after: [.position], result: target.offsetBy(dx: 0, dy: -94), target: target))
    #expect(!FramePlan.needsFullPlan(after: FramePlan.full, result: surprise, target: target), "the app refused; once is enough")
  }
}

@Suite struct WindowKindTests {
  func kind(_ role: String?, _ subrole: String?, minimized: Bool = false, hidden: Bool = false) -> WindowKind {
    WindowKind.classify(role: role, subrole: subrole, isMinimized: minimized, appIsHidden: hidden)
  }

  @Test func standardWindowsAreWindows() {
    #expect(kind("AXWindow", "AXStandardWindow") == .window)
    #expect(kind("AXWindow", "AXStandardWindow", minimized: true, hidden: true) == .window)
  }

  @Test func everythingElseInViewIsNot() {
    for subrole in ["AXDialog", "AXSystemDialog", "AXFloatingWindow", "AXSystemFloatingWindow", "AXUnknown", "Quick Look", nil] {
      #expect(kind("AXWindow", subrole) == .other)
    }
    #expect(kind("AXSheet", nil) == .other)
    #expect(kind("AXPopover", "AXStandardWindow") == .other)
    #expect(kind(nil, nil) == .other, "an app that does not answer")
  }

  /// Seen on macOS 26: minimized windows and the windows of hidden apps all say they are dialogs.
  @Test func aDialogOutOfSightMayBeAWindow() {
    #expect(kind("AXWindow", "AXDialog", minimized: true) == .unconfirmed)
    #expect(kind("AXWindow", "AXDialog", hidden: true) == .unconfirmed)
    #expect(kind("AXWindow", "AXFloatingWindow", hidden: true) == .other)
  }
}

@Suite struct NativeTabsTests {
  let frame = CGRect(x: 76, y: 160, width: 360, height: 272)

  func candidate(_ id: UInt32, _ frame: CGRect, tab: Bool = false) -> NativeTabs.Candidate {
    NativeTabs.Candidate(id: WindowID(id), frame: frame, wasBackgroundTab: tab)
  }

  @Test func aNewWindowInExactlyTheSamePlaceTakesOver() {
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, frame)]) == WindowID(45))
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, frame.offsetBy(dx: 1, dy: 0))]) == WindowID(45))
  }

  /// Seen in Terminal (collab/evidence/compat-lab/tabs-terminal.log): it keeps its rows, so the window grows by the height
  /// of the tab bar at the first ⌘T (625 × 940, then 625 × 971), and the two tabs go on differing by as much.
  @Test func aTabMayDifferInHeightByATabBar() {
    let left = CGRect(x: 12, y: 43, width: 625, height: 940)
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 971))]) == WindowID(392))
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 904))]) == WindowID(392))
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 43, width: 625, height: 990))]) == nil)
    #expect(NativeTabs.successor(toWindowAt: left, among: [candidate(392, CGRect(x: 12, y: 74, width: 625, height: 909))]) == nil, "the top edge stays")
  }

  @Test func theOneThatFitsBestTakesOver() {
    let exact = candidate(50, frame)
    let taller = candidate(40, CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + 31))
    #expect(NativeTabs.successor(toWindowAt: frame, among: [taller, exact]) == WindowID(50))
  }

  /// New windows open a little down and to the right of the last one.
  @Test func aWindowSomewhereElseDoesNot() {
    let cascaded = frame.offsetBy(dx: 22, dy: 22)
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, cascaded, tab: true)]) == nil)
    let larger = CGRect(x: frame.minX, y: frame.minY, width: frame.width + 40, height: frame.height)
    #expect(NativeTabs.successor(toWindowAt: frame, among: [candidate(45, larger)]) == nil)
  }

  @Test func aKnownBackgroundTabIsPreferredToANewcomer() {
    let found = NativeTabs.successor(toWindowAt: frame, among: [candidate(30, frame), candidate(36, frame, tab: true)])
    #expect(found == WindowID(36))
  }

  @Test func nobodyTakesOverWhenNobodyJoined() {
    #expect(NativeTabs.successor(toWindowAt: frame, among: []) == nil)
  }
}

@Suite struct RetryScheduleTests {
  @Test func retriesStartQuicklyAndLastHalfAMinute() {
    let delays = (0..<20).compactMap { RetrySchedule.delay(beforeRetry: $0) }
    #expect(delays == [0.25, 0.5, 1, 2, 4, 8, 8, 8])
    #expect(delays.reduce(0, +) > 30)
    #expect(RetrySchedule.delay(beforeRetry: -1) == nil)
    #expect(RetrySchedule.delay(beforeRetry: Int.max) == nil)
  }
}

@Suite struct AppThatCameForwardTests {
  @Test func anAppThatMacOSNamesIsReportedAtOnce() {
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: 0) == .report)
  }

  /// It used to be dropped, and nothing else tells of ⌘Tab.
  @Test func oneThatMacOSDoesNotNameYetIsLookedAtAgainWithinTheBlinkOfAnEye() {
    #expect(AppThatCameForward.verdict(isNamedInFront: false, earlierLooks: 0) == .lookAgain(after: 0.01))
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: 1) == .report)
  }

  @Test func theLookingEndsAfterHalfASecond() {
    let verdicts = (0..<100).map { AppThatCameForward.verdict(isNamedInFront: false, earlierLooks: $0) }
    let waits = verdicts.compactMap { if case .lookAgain(let seconds) = $0 { seconds } else { nil } }
    #expect(abs(waits.reduce(0, +) - 0.5) < 0.001)
    #expect(verdicts[waits.count...].allSatisfy { $0 == .giveUp })
    #expect(AppThatCameForward.verdict(isNamedInFront: true, earlierLooks: Int.max) == .report, "better late than never")
  }
}

@Suite struct StrayDialogTests {
  let main = StrayDialog.Display(
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 805))
  let side = StrayDialog.Display(
    frame: CGRect(x: -1280, y: 0, width: 1280, height: 800), visibleFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800))
  /// Where Arbor keeps a window that is out of view.
  let corner = CGRect(x: 1439, y: 805, width: 700, height: 600)
  let dialog = CGRect(x: 1639, y: 905, width: 300, height: 160)

  @Test func aDialogOverAWindowThatIsOutOfViewComesToTheMiddleOfTheDisplay() {
    let home = StrayDialog.home(for: dialog, siblings: [corner], displays: [main])
    #expect(home == CGPoint(x: 570, y: 348))
  }

  @Test func aDialogThatCanBeSeenIsLeftAlone() {
    let half = CGRect(x: 1280, y: 400, width: 300, height: 160)
    #expect(StrayDialog.home(for: half, siblings: [corner], displays: [main]) == nil)
    #expect(StrayDialog.home(for: CGRect(x: 500, y: 300, width: 300, height: 160), siblings: [corner], displays: [main]) == nil)
  }

  @Test func whatIsTinyIsOffScreenOnPurpose() {
    #expect(StrayDialog.home(for: CGRect(x: 2000, y: 1000, width: 39, height: 200), siblings: [corner], displays: [main]) == nil)
    #expect(StrayDialog.home(for: CGRect(x: 2000, y: 1000, width: 200, height: 1), siblings: [corner], displays: [main]) == nil)
  }

  @Test func anAppWhoseWindowsAreAllInViewIsNotArborsBusiness() {
    let inView = CGRect(x: 100, y: 100, width: 700, height: 600)
    #expect(StrayDialog.home(for: dialog, siblings: [inView], displays: [main]) == nil)
    #expect(StrayDialog.home(for: dialog, siblings: [], displays: [main]) == nil)
  }

  @Test func withoutDisplaysNothingIsMoved() {
    #expect(StrayDialog.home(for: dialog, siblings: [corner], displays: []) == nil)
  }

  @Test func itGoesToTheDisplayItsAppsWindowWaitsAt() {
    // Out of view at the bottom left corner of the display on the left.
    let waiting = CGRect(x: -1979, y: 799, width: 700, height: 600)
    let there = CGRect(x: -1800, y: 900, width: 300, height: 160)
    let home = StrayDialog.home(for: there, siblings: [waiting], displays: [main, side])
    #expect(home == CGPoint(x: -790, y: 320))
  }

  @Test func aDialogLargerThanTheDisplayKeepsItsTitleBarInReach() {
    let huge = CGRect(x: 1639, y: 905, width: 1600, height: 1000)
    #expect(StrayDialog.home(for: huge, siblings: [corner], displays: [main]) == CGPoint(x: 0, y: 25))
  }
}
