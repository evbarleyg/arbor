import ArborCore
import CoreGraphics
import Foundation
import Testing

// F60: a click on the Desktop does not sweep the windows away.

@Suite struct DesktopClickGuardTests {
  typealias Modifiers = RectangleGesture.Modifiers
  let here = CGPoint(x: 500, y: 400)

  /// With every gesture on, and the guard.
  func guarding() -> RectangleGesture {
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    var gesture = RectangleGesture()
    gesture.follow(settings)
    return gesture
  }

  /// A plain press on bare Desktop inside Arbor's view, held.
  func pressed() -> RectangleGesture {
    var gesture = guarding()
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: 1))
    return gesture
  }

  @Test func aClickOnBareDesktopReachesNobody() {
    // macOS sees no click, so nothing is swept aside.
    var gesture = pressed()
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseUp(at: here) == .drop)
    #expect(!gesture.isTracking)
    #expect(gesture.mouseUp(at: here) == .pass, "the click is over")
  }

  @Test func aHandThatWobblesStillClicks() {
    var gesture = pressed()
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 503, y: 398)) == .swallow)
    #expect(gesture.mouseUp(at: CGPoint(x: 503, y: 398)) == .drop)
  }

  @Test func aDragIsGivenBackToFinderFromItsBeginning() {
    // Its selection rectangle works as ever.
    var gesture = pressed()
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 520, y: 430)) == .replay)
    #expect(!gesture.isTracking)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .pass, "nothing further is touched")
    #expect(gesture.mouseUp(at: CGPoint(x: 600, y: 500)) == .pass)
  }

  @Test func aClickOnAnIconIsGivenBack() {
    var gesture = pressed()
    gesture.desktopAnswered(isItem: true, press: 1)
    #expect(gesture.mouseUp(at: here) == .replay)
    #expect(!gesture.isTracking)
  }

  @Test func aDragOfAnIconIsGivenBack() {
    var gesture = pressed()
    gesture.desktopAnswered(isItem: true, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 540, y: 400)) == .replay)
  }

  @Test func withoutAnAnswerTheClickIsGivenBack() {
    // Finder is busy. A click that sweeps the windows aside can be undone with another; a click an icon
    // never got cannot. Not at once, though: see `QuickClickTests`.
    var gesture = pressed()
    #expect(gesture.mouseUp(at: here) == .holdClick)
    #expect(gesture.giveUpWaiting(press: 1) == true)
  }

  @Test func anAnswerToAnEarlierPressIsIgnored() {
    var gesture = pressed()
    #expect(gesture.mouseUp(at: here) == .holdClick)
    #expect(gesture.giveUpWaiting() == true)
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: 2))
    // Late, about what was under the first press.
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .pass)
    #expect(gesture.mouseUp(at: here) == .holdClick, "the second has no answer yet")
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .pass, "nor is this one")
    #expect(gesture.giveUpWaiting() == true)
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: 3))
    gesture.desktopAnswered(isItem: false, press: 3)
    #expect(gesture.mouseUp(at: here) == .drop)
  }

  @Test func onlyThePressThatIsHeldStillWantsItsAnswer() {
    // With Finder stuck, questions about presses long over must not queue up behind one another.
    var gesture = pressed()
    #expect(gesture.isWaitingForAnswer(press: 1))
    #expect(!gesture.isWaitingForAnswer(press: 2))
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(!gesture.isWaitingForAnswer(press: 1), "answered")
    _ = gesture.mouseUp(at: here)
    _ = gesture.mouseDown(at: here, modifiers: [], onDesktop: true)
    #expect(!gesture.isWaitingForAnswer(press: 1))
    #expect(gesture.isWaitingForAnswer(press: 2))
    _ = gesture.mouseUp(at: here)
    #expect(gesture.isWaitingForAnswer(press: 2), "the click is over and waits whole")
    _ = gesture.giveUpWaiting()
    #expect(!gesture.isWaitingForAnswer(press: 2), "given up")
  }

  @Test func anAnswerWhenNothingIsHeldDoesNothing() {
    var gesture = guarding()
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(!gesture.isTracking)
    #expect(gesture.mouseUp(at: here) == .pass)
    // Nor does it turn a rectangle in progress into something else.
    _ = gesture.mouseDown(at: here, modifiers: [.control, .option])
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseUp(at: here) == .replay)
  }

  @Test func aPressAnywhereElseIsNotArbors() {
    var gesture = guarding()
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: false) == .pass)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .pass)
    #expect(gesture.mouseUp(at: here) == .pass)
  }

  @Test func onlyAPlainPressIsGuarded() {
    var gesture = guarding()
    for modifiers: Modifiers in [[.command], [.option], [.control], [.shift, .option], [.control, .command], [.shift, .command]] {
      #expect(gesture.mouseDown(at: here, modifiers: modifiers, onDesktop: true) == .pass, "\(modifiers.text)")
    }
    // ⌃⌥ anywhere draws a rectangle, and nobody has to be asked.
    #expect(gesture.mouseDown(at: here, modifiers: [.control, .option], onDesktop: true) == .hold)
  }

  @Test func whatIsUnderThePointerIsLookedUpOnlyForAPlainPressAndOneWithShift() {
    var gesture = guarding()
    var looks = 0
    func look() -> Bool {
      looks += 1
      return true
    }
    _ = gesture.mouseDown(at: here, modifiers: [.command], onDesktop: look())
    _ = gesture.mouseDown(at: here, modifiers: [.control, .option], onDesktop: look())
    _ = gesture.mouseDown(at: here, modifiers: [.shift, .option], onDesktop: look())
    #expect(looks == 0)
    _ = gesture.mouseDown(at: here, modifiers: [], onDesktop: look())
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: look())
    #expect(looks == 2)
  }

  // One rule for "bare Desktop" (backlog K071): a ⇧-press is asked about like a plain one.

  @Test func aShiftDragThatStartsOnAnIconIsFinders() {
    var gesture = guarding()
    #expect(gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true) == .ask(press: 1))
    gesture.desktopAnswered(isItem: true, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .replay)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .pass)
    #expect(!gesture.isTracking)
  }

  @Test func aShiftDragThatOutrunsFinderWaitsForTheAnswer() {
    // The hand crosses four points in a few milliseconds, and Finder is asked up to ten things. Before F60 nobody
    // was asked, and the rectangle must not have become a matter of luck.
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .swallow)
    #expect(gesture.mouseDragged(to: CGPoint(x: 580, y: 480)) == .swallow)
    #expect(gesture.isWaitingForAnswer(press: 1))
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .band(CGRect(x: 500, y: 400, width: 100, height: 100)))
  }

  @Test func aShiftDragThatOutrunsFinderOnAnIconIsGivenBackWhenFinderSaysSo() {
    // Also when Finder does not say: whoever asks then answers that there is an item.
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .swallow)
    gesture.desktopAnswered(isItem: true, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 580, y: 480)) == .replay)
    #expect(!gesture.isTracking)
  }

  @Test func aShiftDragLetGoBeforeAnyAnswerIsGivenBack() {
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .swallow)
    #expect(gesture.mouseUp(at: CGPoint(x: 560, y: 460)) == .replay)
  }

  @Test func aShiftDragAnsweredForWhileTheHandRestsIsFramedAllTheSame() {
    // A quick stroke, then the finger rests before it lifts, and nothing is reported while it rests. An answer that comes
    // then is followed by the mouse-up, with no drag in between to draw a band for.
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .swallow)
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseUp(at: CGPoint(x: 600, y: 500)) == .frame(CGRect(x: 500, y: 400, width: 100, height: 100)))
    #expect(!gesture.isTracking)
  }

  @Test func aShiftClickOnTheWallpaperIsStillAClick() {
    // The pointer has not gone anywhere, so there is no rectangle: Finder gets its click, which clears nothing and sweeps nothing.
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 502, y: 401)) == .swallow)
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseUp(at: CGPoint(x: 502, y: 401)) == .replay)
  }

  @Test func aShiftDragFromAnIconAnsweredForWhileTheHandRestsIsGivenBack() {
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .swallow)
    gesture.desktopAnswered(isItem: true, press: 1)
    #expect(gesture.mouseUp(at: CGPoint(x: 600, y: 500)) == .replay)
  }

  @Test func aPlainDragWaitsForNobody() {
    // Whatever is there, it is Finder's: its selection rectangle, or an icon on its way.
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .replay)
  }

  @Test func onlyAPressThatCouldBeArborsOnTheDesktopAsksAboutIt() {
    var gesture = guarding()
    #expect(gesture.asksAboutDesktop(modifiers: []))
    #expect(gesture.asksAboutDesktop(modifiers: [.shift]))
    #expect(!gesture.asksAboutDesktop(modifiers: [.control, .option]), "Arbor's anywhere")
    #expect(!gesture.asksAboutDesktop(modifiers: [.command]))
    #expect(!gesture.asksAboutDesktop(modifiers: [.shift, .option]))
    gesture.guardsDesktopClicks = false
    #expect(!gesture.asksAboutDesktop(modifiers: []))
    gesture.desktopTrigger = []
    #expect(!gesture.asksAboutDesktop(modifiers: [.shift]))
    // With ⇧ alone as the frame modifier a ⇧-press is Arbor's anywhere.
    gesture.trigger = [.shift]
    gesture.desktopTrigger = [.shift]
    #expect(!gesture.asksAboutDesktop(modifiers: [.shift]))
  }

  @Test func aShiftDragOnTheWallpaperDrawsTheRectangle() {
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 502, y: 401)) == .swallow)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .band(CGRect(x: 500, y: 400, width: 100, height: 100)))
    #expect(gesture.mouseUp(at: CGPoint(x: 700, y: 600)) == .frame(CGRect(x: 500, y: 400, width: 200, height: 200)))
  }

  @Test func aShiftClickIsGivenBackWhateverIsThere() {
    // On an icon it adds to the selection. On the wallpaper macOS sweeps nothing for a click with ⇧ (seen on a Mac).
    for isItem in [true, false, nil] {
      var gesture = guarding()
      _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
      if let isItem { gesture.desktopAnswered(isItem: isItem, press: 1) }
      #expect(gesture.mouseUp(at: here) == .replay)
    }
  }

  @Test func theAnswerMayComeWhileThePointerIsAlreadyMoving() {
    var gesture = guarding()
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 503, y: 400)) == .swallow, "within the threshold nothing is decided")
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 560, y: 460)) == .band(CGRect(x: 500, y: 400, width: 60, height: 60)))
  }

  @Test func theGuardCanBeTurnedOff() {
    var gesture = guarding()
    gesture.guardsDesktopClicks = false
    var looks = 0
    func look() -> Bool {
      looks += 1
      return true
    }
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: look()) == .pass)
    #expect(looks == 0, "and then costs nothing")
    #expect(gesture.isEnabled, "the rectangles are still on")
  }

  @Test func theGuardAloneIsReasonEnoughToWatchTheMouse() {
    var gesture = RectangleGesture(trigger: [], desktopTrigger: [])
    #expect(!gesture.isEnabled)
    gesture.guardsDesktopClicks = true
    #expect(gesture.isEnabled)
  }

  @Test func theSettingsDecideEverythingAboutTheGesture() {
    var settings = Settings.withGestures
    var gesture = RectangleGesture(trigger: [], desktopTrigger: [])
    #expect(gesture.follow(settings) == true)
    #expect(gesture.trigger == [.control, .option] && gesture.desktopTrigger == [.shift] && !gesture.guardsDesktopClicks)
    settings.guardDesktopClicks = true
    #expect(gesture.follow(settings) == true)
    #expect(gesture.guardsDesktopClicks)
    settings.frameRectangleModifier = "none"
    settings.frameRectangleOnDesktop = false
    settings.guardDesktopClicks = false
    #expect(gesture.follow(settings) == true)
    #expect(!gesture.isEnabled)
    settings.frameRectangleModifier = "hyper"
    #expect(gesture.follow(settings) == false, "unreadable: say so, and use the default")
    #expect(gesture.trigger == [.control, .option])
  }

  @Test func aMissedMouseUpStartsOver() {
    var gesture = pressed()
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: false) == .pass)
    #expect(gesture.mouseUp(at: here) == .pass)
  }

  @Test func resetForgetsTheHeldPress() {
    var gesture = pressed()
    gesture.reset()
    #expect(!gesture.isTracking)
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseUp(at: here) == .pass)
  }

  @Test func aDoubleClickOnAnIconArrivesAsTwoClicks() {
    var gesture = guarding()
    for press in 1...2 {
      #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: press))
      gesture.desktopAnswered(isItem: true, press: press)
      #expect(gesture.mouseUp(at: here) == .replay)
    }
  }
}

@Suite struct DesktopGuardZonesTests {
  let view = CGRect(x: 0, y: 31, width: 1024, height: 674)
  var zones: DesktopGuardZones {
    DesktopGuardZones(displays: [
      .init(
        view: view,
        windows: [CGRect(x: 12, y: 43, width: 325, height: 650), CGRect(x: 687, y: 43, width: 325, height: 650)],
        panels: [CGRect(x: 337, y: 43, width: 12, height: 650), CGRect(x: 400, y: 500, width: 200, height: 150)])
    ])
  }

  @Test func theDesktopAndTheGapsMayBeBare() {
    #expect(zones.mayBeBare(CGPoint(x: 512, y: 368)), "the Desktop, between the docked windows")
    #expect(zones.mayBeBare(CGPoint(x: 5, y: 300)), "the gap at the left edge")
    #expect(zones.mayBeBare(CGPoint(x: 680, y: 300)), "the gap beside a window")
  }

  @Test func whereAWindowStandsIsNot() {
    // The cheap way out: most clicks on a Mac are on windows.
    for throughPanels in [false, true] {
      #expect(!zones.mayBeBare(CGPoint(x: 100, y: 300), throughPanels: throughPanels))
      #expect(!zones.mayBeBare(CGPoint(x: 900, y: 300), throughPanels: throughPanels))
    }
  }

  @Test func tilesAndGapHandlesKeepPlainPressesButARectangleMayStartOnThem() {
    // A plain press on a handle begins a resize and one on a tile opens it. ⇧-drag may start there (Q11).
    for panel in [CGPoint(x: 342, y: 300), CGPoint(x: 500, y: 600)] {
      #expect(!zones.mayBeBare(panel))
      #expect(zones.mayBeBare(panel, throughPanels: true))
    }
  }

  @Test func outsideTheViewIsNot() {
    #expect(!zones.mayBeBare(CGPoint(x: 500, y: 10)), "the menu bar")
    #expect(!zones.mayBeBare(CGPoint(x: 500, y: 740)), "the Dock")
    #expect(!zones.mayBeBare(CGPoint(x: 1500, y: 300)), "a display with nothing docked")
  }

  @Test func withoutDisplaysNothingIs() {
    #expect(!DesktopGuardZones().mayBeBare(CGPoint(x: 512, y: 368)))
    #expect(DesktopGuardZones().isEmpty)
    #expect(!zones.isEmpty)
  }

  @Test func aPlaceThatIsNotAPlaceIsNot() {
    #expect(!zones.mayBeBare(CGPoint(x: CGFloat.nan, y: 300)))
    #expect(!zones.mayBeBare(CGPoint(x: CGFloat.infinity, y: 300)))
  }
}

@Suite struct DesktopItemTests {
  typealias Window = PointerSurface.Window
  let display = CGRect(x: 0, y: 0, width: 1024, height: 768)

  // What Finder says on macOS 26.6 (F14's survey on a real Mac, 2026-10-14), from the element under the pointer up.
  @Test func theWallpaperIsNoItem() {
    #expect(PointerSurface.isDesktopItem(roles: ["AXGroup", "AXScrollArea", "AXApplication"], focused: "") == false)
  }

  @Test func anIconIs() {
    #expect(PointerSurface.isDesktopItem(roles: ["AXImage", "AXGroup", "AXScrollArea", "AXApplication"], focused: "") == true)
  }

  @Test func aNameBeingEditedAndAWidgetsButtonAre() {
    #expect(PointerSurface.isDesktopItem(roles: ["AXTextField", "AXGroup", "AXScrollArea"], focused: "") == true)
    #expect(PointerSurface.isDesktopItem(roles: ["AXButton", "AXGroup", "AXWindow"], focused: "") == true)
  }

  @Test func noAnswerIsNoAnswer() {
    #expect(PointerSurface.isDesktopItem(roles: [], focused: "") == nil)
    #expect(PointerSurface.isDesktopItem(roles: [], focused: "AXTextField") == nil)
  }

  @Test func aNameBeingEditedIsEndedByAClickBesideIt() {
    let wallpaper = ["AXGroup", "AXScrollArea", "AXApplication"]
    #expect(PointerSurface.isDesktopItem(roles: wallpaper, focused: "AXTextField") == true)
    #expect(PointerSurface.isDesktopItem(roles: wallpaper, focused: "AXTextArea") == true)
    #expect(PointerSurface.isDesktopItem(roles: wallpaper, focused: "AXScrollArea") == false)
    #expect(PointerSurface.isDesktopItem(roles: wallpaper, focused: "") == false, "nothing has the keyboard")
    #expect(PointerSurface.isDesktopItem(roles: wallpaper, focused: nil) == nil, "Finder did not say")
    #expect(PointerSurface.isDesktopItem(roles: ["AXImage"] + wallpaper, focused: nil) == true, "an icon is enough")
  }

  @Test func whoOwnsTheDesktopUnderThePointer() {
    // Front to back, as the window server lists an idle macOS 26 with the Desktop's elements included.
    let windows = [
      Window(frame: CGRect(x: 0, y: 0, width: 1024, height: 30), layer: 24, pid: 166),
      Window(frame: display, layer: 20, pid: 356),  // the Dock's cover
      Window(frame: CGRect(x: 100, y: 100, width: 300, height: 300), layer: 0, pid: 2890),
      Window(frame: display, layer: -2_147_483_603, pid: 359),  // Finder's icons
      Window(frame: display, layer: -2_147_483_624, pid: 356),  // the wallpaper, the Dock's
    ]
    #expect(PointerSurface.under(CGPoint(x: 600, y: 400), windows: windows, displays: [display], mayVanish: true) == .bare(owner: 359))
    #expect(PointerSurface.under(CGPoint(x: 200, y: 200), windows: windows, displays: [display], mayVanish: true) == .taken)
    #expect(PointerSurface.under(CGPoint(x: 600, y: 10), windows: windows, displays: [display], mayVanish: true) == .taken)
    // Without somebody to ask, a press is not held.
    #expect(PointerSurface.under(CGPoint(x: 600, y: 400), windows: [], displays: [display], mayVanish: true) == .taken)
  }

  @Test func theOldQuestionGetsTheOldAnswer() {
    let windows = [Window(frame: display, layer: -2_147_483_603, pid: 359)]
    #expect(!PointerSurface.appWindowIsUnder(CGPoint(x: 600, y: 400), windows: windows, display: display))
  }
}

/// The three questions in the order `RectangleFramer.handleDown` asks them, in its own words, with the window
/// server's answer passed in. The tap cannot run in a test; this is the part of it that can.
@Suite struct DesktopGuardOrderTests {
  struct State {
    var gesture = RectangleGesture()
    var zones = DesktopGuardZones()
  }

  func press(
    _ state: inout State, at point: CGPoint, modifiers: RectangleGesture.Modifiers = [],
    under: () -> PointerSurface.Surface
  ) -> (response: RectangleGesture.Response, owner: Int32?) {
    let (asks, zones) = (state.gesture.asksAboutDesktop(modifiers: modifiers), state.zones)
    var surface = PointerSurface.Surface.taken
    if asks, zones.mayBeBare(point, throughPanels: !modifiers.isEmpty) { surface = under() }
    let isOnDesktop = surface != .taken
    let response = state.gesture.mouseDown(at: point, modifiers: modifiers, onDesktop: isOnDesktop)
    guard case .ask(let press) = response, case .bare(let desktopOwner) = surface else { return (response, nil) }
    // Nobody draws icons here, so it is the wallpaper.
    if desktopOwner == nil { state.gesture.desktopAnswered(isItem: false, press: press) }
    return (response, desktopOwner)
  }

  func makeState() -> State {
    var state = State()
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    state.gesture.follow(settings)
    state.zones = DesktopGuardZones(displays: [
      .init(
        view: CGRect(x: 0, y: 31, width: 1024, height: 674), windows: [CGRect(x: 12, y: 43, width: 325, height: 650)],
        panels: [])
    ])
    return state
  }

  @Test func aClickOnADockedWindowNeverReadsTheWindowList() {
    var state = makeState()
    var reads = 0
    let result = press(&state, at: CGPoint(x: 100, y: 300)) {
      reads += 1
      return .bare(owner: 359)
    }
    #expect(result.response == .pass)
    #expect(reads == 0)
  }

  @Test func aClickWithAModifierNeverReadsItEither() {
    var state = makeState()
    var reads = 0
    _ = press(&state, at: CGPoint(x: 600, y: 300), modifiers: [.command]) {
      reads += 1
      return .bare(owner: 359)
    }
    #expect(reads == 0)
  }

  @Test func aPressOnBareDesktopIsHeldAndItsOwnerAsked() {
    var state = makeState()
    let result = press(&state, at: CGPoint(x: 600, y: 300)) { .bare(owner: 359) }
    #expect(result.response == .ask(press: 1))
    #expect(result.owner == 359)
  }

  @Test func whereNobodyDrawsIconsNobodyIsAsked() {
    // People hide the icons of the Desktop. Then there is no window of Finder's to ask about, and nothing to ask.
    var state = makeState()
    let click = press(&state, at: CGPoint(x: 600, y: 300)) { .bare(owner: nil) }
    #expect(click.response == .ask(press: 1) && click.owner == nil)
    #expect(!state.gesture.isWaitingForAnswer(press: 1), "answered on the spot")
    #expect(state.gesture.mouseUp(at: CGPoint(x: 600, y: 300)) == .drop)
    _ = press(&state, at: CGPoint(x: 600, y: 300), modifiers: [.shift]) { .bare(owner: nil) }
    #expect(state.gesture.mouseDragged(to: CGPoint(x: 700, y: 400)) == .band(CGRect(x: 600, y: 300, width: 100, height: 100)))
  }

  @Test func aFloatingWindowOverTheDesktopGetsItsClick() {
    var state = makeState()
    let result = press(&state, at: CGPoint(x: 600, y: 300)) { .taken }
    #expect(result.response == .pass)
    #expect(result.owner == nil)
  }
}

@Suite struct DesktopGuardSettingsTests {
  /// Off until it has been seen at work on a Mac: it keeps clicks from everybody, and a click on the wallpaper is
  /// also how people close a menu.
  @Test func nobodyGetsTheGuardWithoutAskingForIt() throws {
    #expect(!Settings().guardDesktopClicks)
    #expect(try !JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8)).guardDesktopClicks)
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"guardDesktopClicks": true}"#.utf8)).guardDesktopClicks)
  }

  @Test func theSettingDecodesAndRoundTrips() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"guardDesktopClicks": false}"#.utf8))
    #expect(!settings.guardDesktopClicks)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }
}

/// A click that is kept from everybody must be one nobody is waiting for, wherever on the screen they are.
@Suite struct QuietDesktopTests {
  typealias Window = PointerSurface.Window
  let display = CGRect(x: 0, y: 0, width: 1024, height: 768)
  /// On the Desktop's part of the layout.
  let wallpaper = CGPoint(x: 500, y: 400)

  /// What the window server listed on macOS 26.6 with three windows docked and nothing else going on, in its
  /// order (`scripts/mac-shell/input-taps.sh`, "windows on screen", 2026-10-14).
  var atRest: [Window] {
    [
      Window(frame: CGRect(x: 337, y: 43, width: 12, height: 650), layer: 0, isOwn: true, pid: 3254),
      Window(frame: CGRect(x: 12, y: 362, width: 325, height: 12), layer: 0, isOwn: true, pid: 3254),
      Window(frame: CGRect(x: 675, y: 43, width: 12, height: 650), layer: 0, isOwn: true, pid: 3254),
      Window(frame: CGRect(x: 12, y: 374, width: 325, height: 319), layer: 0, pid: 3247),
      Window(frame: CGRect(x: 687, y: 43, width: 325, height: 650), layer: 0, pid: 3247),
      Window(frame: CGRect(x: 12, y: 43, width: 325, height: 319), layer: 0, pid: 3247),
      Window(frame: CGRect(x: 795, y: 0, width: 31, height: 30), layer: 25, pid: 358),  // Control Center's items
      Window(frame: CGRect(x: 826, y: 0, width: 42, height: 30), layer: 25, pid: 358),
      Window(frame: CGRect(x: 868, y: 0, width: 156, height: 30), layer: 25, pid: 358),
      Window(frame: CGRect(x: 0, y: 0, width: 1024, height: 30), layer: 24, pid: 165),  // the menu bar
      Window(frame: display, layer: -2_147_483_603, pid: 360),  // Finder's icons
      Window(frame: display, layer: -2_147_483_624, pid: 357),  // the wallpaper, the Dock's
      Window(frame: display, layer: 20, pid: 357),  // the Dock's cover
      Window(frame: display, layer: -2_147_483_626, pid: 165),
    ]
  }

  func surface(with more: [Window] = [], at point: CGPoint? = nil) -> PointerSurface.Surface {
    PointerSurface.under(point ?? wallpaper, windows: more + atRest, displays: [display], mayVanish: true)
  }

  @Test func aMacAtRestHasBareWallpaper() {
    #expect(surface() == .bare(owner: 360))
    #expect(surface(at: CGPoint(x: 343, y: 300)) == .bare(owner: 360), "under a gap handle of Arbor's")
    #expect(surface(at: CGPoint(x: 100, y: 100)) == .taken, "a window")
  }

  @Test func anOpenMenuAnywhereIsWaitingForTheClick() {
    // The Apple menu, far from the pointer. People click the wallpaper to get rid of it.
    #expect(surface(with: [Window(frame: CGRect(x: 10, y: 30, width: 220, height: 300), layer: 101, pid: 165)]) == .taken)
  }

  @Test func arborsOwnMenuIsAMenu() {
    // It has Arbor's pid and no title, like a tile. An item that hangs over the Desktop's part must get its click.
    let menu = Window(frame: CGRect(x: 400, y: 30, width: 260, height: 500), layer: 101, isOwn: true, pid: 3254)
    #expect(surface(with: [menu]) == .taken, "under the pointer")
    #expect(surface(with: [menu], at: CGPoint(x: 343, y: 600)) == .taken, "beside the pointer")
    #expect(PointerSurface.appWindowIsUnder(wallpaper, windows: [menu] + atRest, display: display), "nor for a pinch")
  }

  /// Nobody has printed the levels of Spotlight, Control Centre, Notification Centre, a Dock stack or a banner, so
  /// no level is taken to be harmless but those a Mac at rest has been seen to use.
  @Test(arguments: [4, 8, 19, 20, 21, 23, 24, 25, 26, 100, 101, 102, 200, 500, 1000, 1500, 2_147_483_630])
  func whateverElseIsUpMayBeWaitingForTheClick(layer: Int) {
    #expect(surface(with: [Window(frame: CGRect(x: 700, y: 40, width: 300, height: 400), layer: layer, pid: 900)]) == .taken)
  }

  @Test func aSecondCoverOfTheDisplayIsNotTheDocks() {
    // Mission Control, Launchpad, the crosshair of a screenshot: the windows' real places are still listed under them.
    #expect(surface(with: [Window(frame: display, layer: 20, pid: 357)]) == .taken, "another at the Dock's level")
    #expect(surface(with: [Window(frame: display, layer: 18, pid: 357)]) == .taken)
    #expect(surface(with: [Window(frame: display, layer: 1000, pid: 901)]) == .taken)
  }

  @Test func palettesAndArborsFloatingPanelsWaitForNothing() {
    let palette = Window(frame: CGRect(x: 700, y: 100, width: 200, height: 300), layer: 3, pid: 900)
    let band = Window(frame: CGRect(x: 300, y: 300, width: 400, height: 300), layer: 3, isOwn: true, pid: 3254)
    #expect(surface(with: [palette, band]) == .bare(owner: 360))
    #expect(surface(with: [palette], at: CGPoint(x: 800, y: 200)) == .taken, "but a click on one is its own")
  }

  @Test func whatCannotBeSeenWaitsForNothing() {
    #expect(surface(with: [Window(frame: CGRect(x: 10, y: 30, width: 220, height: 300), layer: 101, alpha: 0)]) == .bare(owner: 360))
  }

  @Test func moreItemsInATallerMenuBarAreFurniture() {
    // A MacBook with a notch, and other apps' items.
    #expect(surface(with: [Window(frame: CGRect(x: 600, y: 0, width: 28, height: 37), layer: 25, pid: 950)]) == .bare(owner: 360))
  }

  @Test func whateverLiesInFrontOfTheIconsGetsTheClick() {
    // A widget, or a tool that draws on the wallpaper: it may cover the display, and would answer for an icon under it.
    let widget = Window(frame: CGRect(x: 440, y: 340, width: 160, height: 160), layer: -2_147_483_602, pid: 777)
    #expect(surface(with: [widget]) == .taken)
    #expect(surface(with: [widget], at: CGPoint(x: 500, y: 600)) == .bare(owner: 360), "beside it")
    #expect(surface(with: [Window(frame: display, layer: -2_147_483_602, pid: 778)]) == .taken)
  }

  @Test func whateverLiesBehindTheIconsGetsTheClickToo() {
    // Nobody has measured where macOS keeps widgets. Behind the icons, Finder would say "wallpaper" of one: it is not its own.
    // What belongs to the Desktop itself is as large as the display.
    let widget = Window(frame: CGRect(x: 440, y: 340, width: 160, height: 160), layer: -2_147_483_610, pid: 777)
    for mayVanish in [true, false] {
      #expect(PointerSurface.under(wallpaper, windows: [widget] + atRest, displays: [display], mayVanish: mayVanish) == .taken)
      #expect(
        PointerSurface.under(CGPoint(x: 500, y: 600), windows: [widget] + atRest, displays: [display], mayVanish: mayVanish)
          == .bare(owner: 360), "beside it")
    }
    #expect(surface(with: [Window(frame: widget.frame, layer: -2_147_483_610, alpha: 0, pid: 777)]) == .bare(owner: 360))
  }

  @Test func arborsOwnBackdropIsNotInTheWay() {
    // F15 darkens the wallpaper behind the docked windows: a panel of Arbor's over the display's visible frame, one level above
    // the icons, which the mouse goes straight through.
    let backdrop = Window(
      frame: CGRect(x: 0, y: 30, width: 1024, height: 675), layer: -2_147_483_602, isOwn: true, pid: 3254)
    for mayVanish in [true, false] {
      #expect(
        PointerSurface.under(wallpaper, windows: [backdrop] + atRest, displays: [display], mayVanish: mayVanish)
          == .bare(owner: 360))
    }
    // With the icons hidden it is still nobody's.
    let hidden = atRest.filter { $0.layer != -2_147_483_603 }
    #expect(PointerSurface.under(wallpaper, windows: [backdrop] + hidden, displays: [display], mayVanish: true) == .bare(owner: nil))
    // Alone it does not stand for the Desktop.
    let none = atRest.filter { $0.layer >= 0 }
    #expect(PointerSurface.under(wallpaper, windows: [backdrop] + none, displays: [display], mayVanish: false) == .taken)
  }

  @Test func arborsOtherPanelsAboveTheFloatingLevelMayBeWaiting() {
    // The window finder and the minimap are both at level 5, and only one of them closes at a click beside it. The list cannot
    // tell them apart, so with either up the click is given back.
    let panel = Window(frame: CGRect(x: 700, y: 500, width: 240, height: 160), layer: 5, isOwn: true, pid: 3254)
    #expect(surface(with: [panel]) == .taken, "beside the pointer")
    #expect(surface(with: [panel], at: CGPoint(x: 800, y: 560)) == .taken, "under it")
    #expect(
      PointerSurface.under(wallpaper, windows: [panel] + atRest, displays: [display], mayVanish: false) == .bare(owner: 360),
      "a press with ⇧ beside it takes nothing from anybody")
  }

  @Test func theStageOfAMotionWaitsForNothing() {
    // F02's, one level above the floating panels, as large as the display, for as long as the view moves. Given back, a
    // click during a motion would sweep the windows aside.
    #expect(surface(with: [Window(frame: display, layer: 4, isOwn: true, pid: 3254)]) == .bare(owner: 360))
    #expect(surface(with: [Window(frame: display, layer: 4, pid: 900)]) == .taken, "somebody else's")
    #expect(surface(with: [Window(frame: display, layer: 5, isOwn: true, pid: 3254)]) == .taken, "nothing of Arbor's is known there")
  }

  @Test func withTheIconsHiddenItIsTheWallpaper() {
    // `CreateDesktop false`, or "Show Items: On Desktop" off: Finder keeps no window there.
    let hidden = atRest.filter { $0.layer != -2_147_483_603 }
    for mayVanish in [true, false] {
      #expect(PointerSurface.under(wallpaper, windows: hidden, displays: [display], mayVanish: mayVanish) == .bare(owner: nil))
    }
    // With nothing at all below the windows the list is not what it should be.
    let none = atRest.filter { $0.layer >= 0 }
    #expect(PointerSurface.under(wallpaper, windows: none, displays: [display], mayVanish: false) == .taken)
  }

  @Test func everyDisplayHasItsOwnCover() {
    let second = CGRect(x: 1024, y: 0, width: 1280, height: 800)
    let more = [
      Window(frame: second, layer: 20, pid: 357), Window(frame: second, layer: -2_147_483_603, pid: 360),
      Window(frame: CGRect(x: 1024, y: 0, width: 1280, height: 30), layer: 24, pid: 165),
    ]
    #expect(PointerSurface.under(wallpaper, windows: more + atRest, displays: [display, second], mayVanish: true) == .bare(owner: 360))
    #expect(
      PointerSurface.under(CGPoint(x: 1600, y: 400), windows: more + atRest, displays: [display, second], mayVanish: true)
        == .bare(owner: 360))
    // A menu on the other display waits for the click as well.
    let menu = Window(frame: CGRect(x: 1100, y: 30, width: 200, height: 300), layer: 101, pid: 902)
    #expect(PointerSurface.under(wallpaper, windows: [menu] + more + atRest, displays: [display, second], mayVanish: true) == .taken)
  }

  @Test func aPressThatIsGivenBackNeedNotWaitForAQuietMac() {
    // ⇧-drag is on by default. It takes no click from anybody, and must not stop working on every Mac that has
    // something unknown above its windows all day.
    func shift(with more: [Window], at point: CGPoint? = nil) -> PointerSurface.Surface {
      PointerSurface.under(point ?? wallpaper, windows: more + atRest, displays: [display], mayVanish: false)
    }
    #expect(shift(with: []) == .bare(owner: 360))
    #expect(shift(with: [Window(frame: CGRect(x: 700, y: 40, width: 300, height: 400), layer: 1000, pid: 900)]) == .bare(owner: 360))
    #expect(shift(with: [Window(frame: CGRect(x: 10, y: 30, width: 220, height: 300), layer: 101, pid: 165)]) == .bare(owner: 360))
    // What is under the pointer counts all the same.
    let menu = Window(frame: CGRect(x: 400, y: 30, width: 260, height: 500), layer: 101, isOwn: true, pid: 3254)
    #expect(shift(with: [menu]) == .taken, "Arbor's own menu")
    #expect(shift(with: [Window(frame: CGRect(x: 440, y: 340, width: 160, height: 160), layer: -2_147_483_602, pid: 777)]) == .taken)
    #expect(shift(with: [], at: CGPoint(x: 100, y: 100)) == .taken, "a window")
  }

  @Test func withoutTheDisplaysNothingIsBare() {
    #expect(PointerSurface.under(wallpaper, windows: atRest, displays: [], mayVanish: true) == .taken)
  }
}

/// With tap to click, and from a quick finger, the button is up a few milliseconds after it went down, before Finder has
/// said what is under the pointer. Then the whole click waits for the answer.
@Suite struct QuickClickTests {
  let here = CGPoint(x: 500, y: 400)

  /// A plain click on bare Desktop that is over before anybody has answered.
  func clicked() -> RectangleGesture {
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    var gesture = RectangleGesture()
    gesture.follow(settings)
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: 1))
    #expect(gesture.mouseUp(at: here) == .holdClick)
    return gesture
  }

  @Test func onTheWallpaperNobodyGetsIt() {
    var gesture = clicked()
    #expect(gesture.isTracking)
    #expect(gesture.isWaitingForAnswer(press: 1), "or Finder would not be asked at all")
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .drop)
    #expect(!gesture.isTracking)
  }

  @Test func onAnIconBothHalvesAreGivenBack() {
    var gesture = clicked()
    #expect(gesture.desktopAnswered(isItem: true, press: 1) == .replayClick)
    #expect(!gesture.isTracking)
    #expect(gesture.desktopAnswered(isItem: true, press: 1) == .pass, "once")
  }

  @Test func anAnswerWhileTheButtonIsDownDecidesNothingYet() {
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    var gesture = RectangleGesture()
    gesture.follow(settings)
    _ = gesture.mouseDown(at: here, modifiers: [], onDesktop: true)
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .pass)
    #expect(gesture.mouseUp(at: here) == .drop)
  }

  @Test func aNewPressSendsTheWaitingClickAhead() {
    // The second click of a pair, say. Events must arrive in the order they were made.
    var gesture = clicked()
    #expect(gesture.giveUpWaiting() == true)
    #expect(!gesture.isTracking)
    #expect(gesture.mouseDown(at: here, modifiers: [], onDesktop: true) == .ask(press: 2))
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .pass, "too late for the first")
    #expect(gesture.isWaitingForAnswer(press: 2))
  }

  @Test func afterAWhileItIsGivenBackUnanswered() {
    var gesture = clicked()
    #expect(gesture.giveUpWaiting(press: 2) == false, "another press's time limit")
    #expect(gesture.giveUpWaiting(press: 1) == true)
    #expect(gesture.giveUpWaiting(press: 1) == false, "once")
    #expect(gesture.desktopAnswered(isItem: false, press: 1) == .pass)
  }

  @Test func thereIsNothingToGiveUpWhileTheButtonIsDown() {
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    var gesture = RectangleGesture()
    gesture.follow(settings)
    #expect(gesture.giveUpWaiting() == false)
    _ = gesture.mouseDown(at: here, modifiers: [], onDesktop: true)
    #expect(gesture.giveUpWaiting() == false)
    #expect(gesture.giveUpWaiting(press: 1) == false)
    #expect(gesture.isTracking, "the press is still held")
  }

  @Test func aClickWithShiftDoesNotWait() {
    // macOS sweeps nothing for it, so it is given back whatever is there.
    var gesture = RectangleGesture()
    gesture.follow(.withGestures)
    _ = gesture.mouseDown(at: here, modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseUp(at: here) == .replay)
  }

  @Test func strayEventsWhileItWaitsPass() {
    var gesture = clicked()
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 500)) == .pass)
    #expect(gesture.mouseUp(at: here) == .pass)
    #expect(gesture.desktopAnswered(isItem: true, press: 1) == .replayClick, "and it goes on waiting")
  }
}
