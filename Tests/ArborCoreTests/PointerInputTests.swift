import ArborCore
import CoreGraphics
import Foundation
import Testing

// F03 (trackpad pinch) and F05 (drag a rectangle to frame it): the pure parts.

@Suite struct GestureInterpreterTests {
  /// Feeds a whole gesture that Arbor claims and returns every command it produced.
  func commands(_ deltas: [Double], threshold: Double = 0.25) -> [Command] {
    var interpreter = GestureInterpreter(threshold: threshold)
    var commands = interpreter.feed(.began, magnification: 0).commands
    for delta in deltas { commands += interpreter.feed(.changed, magnification: delta).commands }
    commands += interpreter.feed(.ended, magnification: 0).commands
    return commands
  }

  @Test func magnificationBelowTheThresholdDoesNothing() {
    #expect(commands([0.1, 0.1]).isEmpty)
    #expect(commands([-0.1, -0.12]).isEmpty)
    #expect(commands([0.2, -0.2, 0.2]).isEmpty)
  }

  @Test func spreadingStepsInAndPinchingStepsOut() {
    #expect(commands([0.15, 0.15]) == [.stepIn])
    #expect(commands([-0.15, -0.15]) == [.stepOut])
  }

  @Test func oneStepPerThresholdCrossed() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0)
    // 0.6 crosses 0.25 twice and leaves 0.1 over.
    #expect(interpreter.feed(.changed, magnification: 0.6).commands == [.stepIn, .stepIn])
    #expect(interpreter.feed(.changed, magnification: 0.1).commands.isEmpty)
    #expect(interpreter.feed(.changed, magnification: 0.06).commands == [.stepIn])
    #expect(commands([-0.8]) == [.stepOut, .stepOut, .stepOut])
    #expect(commands(Array(repeating: 0.05, count: 20)) == Array(repeating: .stepIn, count: 4))
  }

  @Test func smallDeltasAddUpExactly() {
    // 0.05 is not exact in binary; five of them must still make one 0.25 step.
    #expect(commands(Array(repeating: 0.05, count: 5)) == [.stepIn])
    #expect(commands(Array(repeating: -0.05, count: 5)) == [.stepOut])
  }

  @Test func reversingMidGestureStepsBack() {
    #expect(commands([0.3, -0.35]) == [.stepIn, .stepOut])
    // After a step, travel starts again from what was left over, so a small
    // wobble back does not undo it.
    #expect(commands([0.3, -0.2]) == [.stepIn])
  }

  @Test func travelIsNotCarriedFromOneGestureToTheNext() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0)
    #expect(interpreter.feed(.changed, magnification: 0.2).commands.isEmpty)
    #expect(interpreter.feed(.ended, magnification: 0).commands.isEmpty)
    #expect(interpreter.travel == 0)
    _ = interpreter.feed(.began, magnification: 0)
    #expect(interpreter.feed(.changed, magnification: 0.1).commands.isEmpty)
  }

  @Test func theBeganAndEndedEventsCountTheirMovementButCancelledDoesNot() {
    var interpreter = GestureInterpreter()
    #expect(interpreter.feed(.began, magnification: 0.3).commands == [.stepIn])
    #expect(interpreter.feed(.changed, magnification: 0.1).commands.isEmpty)
    #expect(interpreter.feed(.ended, magnification: 0.1) == .init(handled: true, commands: [.stepIn]))

    _ = interpreter.feed(.began, magnification: 0)
    _ = interpreter.feed(.changed, magnification: 0.2)
    #expect(interpreter.feed(.cancelled, magnification: 0.1) == .init(handled: true, commands: []))
    #expect(!interpreter.isClaimed)
  }

  @Test func aGestureArborDoesNotClaimIsNeverHandled() {
    var interpreter = GestureInterpreter()
    #expect(interpreter.feed(.began, magnification: 0, claim: false) == .ignored)
    // Pressing ⌥ halfway through does not take the gesture from the app.
    #expect(interpreter.feed(.changed, magnification: 0.6, claim: true) == .ignored)
    #expect(interpreter.feed(.ended, magnification: 0, claim: true) == .ignored)
    #expect(!interpreter.isClaimed)
  }

  @Test func aClaimedGestureStaysClaimedUntilItEnds() {
    var interpreter = GestureInterpreter()
    #expect(interpreter.feed(.began, magnification: 0, claim: true).handled)
    // Letting go of ⌥, or moving over a window, halfway through changes nothing.
    #expect(interpreter.feed(.changed, magnification: 0.3, claim: false) == .init(handled: true, commands: [.stepIn]))
    #expect(interpreter.feed(.ended, magnification: 0, claim: false).handled)
    #expect(interpreter.feed(.changed, magnification: 0.3) == .ignored, "the gesture is over")
  }

  @Test func theClaimIsCheckedOnlyWhenAGestureBegins() {
    var interpreter = GestureInterpreter()
    var checks = 0
    func check() -> Bool {
      checks += 1
      return true
    }
    _ = interpreter.feed(.began, magnification: 0, claim: check())
    _ = interpreter.feed(.changed, magnification: 0.1, claim: check())
    _ = interpreter.feed(.changed, magnification: 0.1, claim: check())
    _ = interpreter.feed(.ended, magnification: 0, claim: check())
    #expect(checks == 1)
  }

  @Test func aNewPinchDecidesAgainEvenIfTheLastOneNeverEnded() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0, claim: true)
    _ = interpreter.feed(.changed, magnification: 0.2)
    // The ended event was missed; the next pinch starts over an app window.
    #expect(interpreter.feed(.began, magnification: 0, claim: false) == .ignored)
    #expect(interpreter.feed(.changed, magnification: 0.1) == .ignored)
    #expect(interpreter.travel == 0)
  }

  @Test func eventsWithoutABeginningAreIgnored() {
    // The tap was installed, or switched back on, in the middle of a pinch.
    var interpreter = GestureInterpreter()
    #expect(interpreter.feed(.changed, magnification: 0.6) == .ignored)
    #expect(interpreter.feed(.ended, magnification: 0) == .ignored)
  }

  @Test func resetForgetsTheGestureInProgress() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0)
    _ = interpreter.feed(.changed, magnification: 0.2)
    interpreter.reset()
    #expect(!interpreter.isClaimed)
    #expect(interpreter.travel == 0)
    #expect(interpreter.feed(.changed, magnification: 0.2) == .ignored)
  }

  @Test func theThresholdIsConfigurableAndKeptSane() {
    #expect(commands([0.3], threshold: 0.5).isEmpty)
    #expect(commands([0.3, 0.3], threshold: 0.5) == [.stepIn])
    for bad in [0, -1, Double.nan, Double.infinity] {
      #expect(GestureInterpreter(threshold: bad).effectiveThreshold == GestureInterpreter.defaultThreshold)
    }
    #expect(GestureInterpreter(threshold: 0.001).effectiveThreshold == GestureInterpreter.minimumThreshold)
    #expect(commands([1.0], threshold: 0.001).count == 20)
  }

  /// A delta of 1e17 used to loop for ever: taking one step away from it does not change it.
  @Test(arguments: [1e6, 1e17, 1e300, -1e6, -1e17, -1e300]) func aHugeDeltaMeansAFewStepsNotMillions(delta: Double) {
    var interpreter = GestureInterpreter()
    let commands = interpreter.feed(.began, magnification: delta).commands
    #expect(commands == Array(repeating: delta > 0 ? .stepIn : .stepOut, count: 32))
    // And the gesture goes on normally from there.
    #expect(interpreter.feed(.changed, magnification: delta > 0 ? -0.25 : 0.25).commands.count == 1)
  }

  @Test func nonFiniteDeltasAreIgnored() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0)
    #expect(interpreter.feed(.changed, magnification: .nan) == .init(handled: true, commands: []))
    #expect(interpreter.feed(.changed, magnification: .infinity) == .init(handled: true, commands: []))
    #expect(interpreter.travel == 0)
    #expect(interpreter.feed(.changed, magnification: 0.25).commands == [.stepIn])
  }

  @Test func aRotationThatBeginsDuringArborsPinchIsKeptFromTheApp() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0, claim: true)
    #expect(interpreter.feedRotation(.began) == true)
    #expect(interpreter.feedRotation(.changed) == true)
    // The pinch ends first: the app never saw this rotation begin, so it must not see it end.
    _ = interpreter.feed(.ended, magnification: 0)
    #expect(interpreter.feedRotation(.changed) == true)
    #expect(interpreter.feedRotation(.ended) == true)
    #expect(interpreter.feedRotation(.changed) == false, "the rotation is over")
  }

  @Test func aRotationTheAppSawBeginStaysWithTheApp() {
    var interpreter = GestureInterpreter()
    #expect(interpreter.feedRotation(.began) == false)
    // ⌥ goes down and a pinch of Arbor's begins halfway through the rotation.
    _ = interpreter.feed(.began, magnification: 0, claim: true)
    #expect(interpreter.feedRotation(.changed) == false)
    #expect(interpreter.feedRotation(.ended) == false)
    // The next rotation of the same pinch is Arbor's.
    #expect(interpreter.feedRotation(.began) == true)
    #expect(interpreter.feedRotation(.cancelled) == true)
    #expect(!interpreter.isRotationClaimed)
  }

  @Test func rotationsDuringAnAppsPinchAreTheApps() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0, claim: false)
    #expect(interpreter.feedRotation(.began) == false)
    #expect(interpreter.feedRotation(.changed) == false)
    #expect(interpreter.feedRotation(.ended) == false)
  }

  @Test func resetForgetsTheRotationToo() {
    var interpreter = GestureInterpreter()
    _ = interpreter.feed(.began, magnification: 0, claim: true)
    _ = interpreter.feedRotation(.began)
    interpreter.reset()
    #expect(interpreter.feedRotation(.changed) == false)
  }
}

@Suite struct PointerSurfaceTests {
  typealias Window = PointerSurface.Window
  let display = CGRect(x: 0, y: 0, width: 1024, height: 768)

  /// What the window server lists on an idle macOS 26 (a GitHub runner, October 2026), front to
  /// back, without the wallpaper and the icons, which Arbor asks it to leave out.
  var idle: [Window] {
    [
      Window(frame: CGRect(x: 795, y: 0, width: 31, height: 30), layer: 25),  // Control Center: a menu bar item
      Window(frame: CGRect(x: 868, y: 0, width: 156, height: 30), layer: 25),
      Window(frame: CGRect(x: 0, y: 0, width: 1024, height: 30), layer: 24),  // Window Server: the menu bar
      Window(frame: CGRect(x: 0, y: 0, width: 1024, height: 768), layer: 20),  // the Dock, over the whole display
    ]
  }

  func appWindow(at x: CGFloat, _ y: CGFloat, _ windows: [Window]) -> Bool {
    PointerSurface.appWindowIsUnder(CGPoint(x: x, y: y), windows: windows, display: display)
  }

  @Test func theWallpaperIsBareAlthoughTheDocksWindowCoversIt() {
    #expect(!appWindow(at: 500, 400, idle))
    #expect(!appWindow(at: 500, 400, []))
  }

  @Test func theMenuBarAndItsItemsAreNotBare() {
    #expect(appWindow(at: 500, 10, idle))
    #expect(appWindow(at: 800, 10, idle))
  }

  @Test func anOrdinaryWindowIsAnApps() {
    let windows = idle + [Window(frame: CGRect(x: 100, y: 100, width: 400, height: 300), layer: 0)]
    #expect(appWindow(at: 300, 200, windows))
    #expect(!appWindow(at: 600, 200, windows), "beside it")
  }

  @Test func palettesMenusAndBannersOverTheWallpaperAreApps() {
    for layer in [3, 8, 23, 101] {
      let windows = [Window(frame: CGRect(x: 600, y: 100, width: 200, height: 300), layer: layer)] + idle
      #expect(appWindow(at: 700, 200, windows), "level \(layer)")
      #expect(!appWindow(at: 300, 200, windows), "level \(layer), beside it")
    }
  }

  @Test func arborsTilesAndSeamHandlesAreBare() {
    // They stand where windows are not: the windows a tile stands in for are out of view.
    let windows = idle + [
      Window(frame: CGRect(x: 100, y: 100, width: 200, height: 200), layer: 0, isOwn: true),
      Window(frame: CGRect(x: 400, y: 100, width: 300, height: 300), layer: 0),
    ]
    #expect(!appWindow(at: 200, 200, windows))
    #expect(appWindow(at: 500, 200, windows), "the window beside the tile")
  }

  @Test func theFocusRingDoesNotMakeTheWindowItSurroundsBare() {
    // Its panel is Arbor's own, at the level of ordinary windows, in front of the focused window and as
    // large. A pinch or a ⇧-drag over that window is still the app's.
    let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
    let windows = idle + [Window(frame: frame.insetBy(dx: -4, dy: -4), layer: 0, isOwn: true), Window(frame: frame, layer: 0)]
    #expect(appWindow(at: 300, 200, windows))
    #expect(!appWindow(at: 98, 200, windows), "on the line itself, outside the window, there is only wallpaper")
  }

  @Test func arborsFloatingPanelsAreLookedThrough() {
    // The rubber band or a drop preview, at the floating level.
    let band = Window(frame: CGRect(x: 100, y: 100, width: 500, height: 400), layer: 3, isOwn: true)
    #expect(!appWindow(at: 200, 200, [band] + idle))
    let windows = [band] + idle + [Window(frame: CGRect(x: 150, y: 150, width: 100, height: 100), layer: 0)]
    #expect(appWindow(at: 200, 200, windows))
  }

  @Test func invisibleWindowsDoNotCount() {
    let windows = idle + [Window(frame: CGRect(x: 100, y: 100, width: 400, height: 300), layer: 0, alpha: 0)]
    #expect(!appWindow(at: 300, 200, windows))
  }

  @Test func whatIsBelowTheWindowsDoesNotCount() {
    let windows = idle + [Window(frame: display, layer: -2_147_483_603)]  // Finder's icons
    #expect(!appWindow(at: 300, 200, windows))
  }

  @Test func aFullScreenAppIsStillAnApp() {
    #expect(appWindow(at: 300, 200, idle + [Window(frame: display, layer: 0)]))
  }

  @Test func withoutTheDisplaysFrameNothingIsLookedThrough() {
    // Leaving the event to the app is the safe mistake.
    #expect(PointerSurface.appWindowIsUnder(CGPoint(x: 500, y: 400), windows: idle, display: nil))
  }

  @Test func aCoverOfOneDisplayDoesNotHideAnother() {
    let second = CGRect(x: 1024, y: 0, width: 1280, height: 800)
    let windows = idle + [Window(frame: second, layer: 20)]
    #expect(!PointerSurface.appWindowIsUnder(CGPoint(x: 1500, y: 400), windows: windows, display: second))
  }
}

@Suite struct TapHealthTests {
  @Test func anOccasionalSwitchOffGoesStraightBackOn() {
    var health = TapHealth()
    #expect(health.switchedOff(at: 100) == .switchOn)
    #expect(health.switchedOff(at: 105) == .switchOn)
    // The first has aged out by now, so this is again the second in ten seconds.
    #expect(health.switchedOff(at: 111) == .switchOn)
    #expect(health.switchedOff(at: 200) == .switchOn)
    #expect(!health.isResting)
  }

  @Test func repeatedSwitchOffsLeaveTheTapsOffForAWhile() {
    var health = TapHealth()
    #expect(health.switchedOff(at: 100) == .switchOn)
    #expect(health.switchedOff(at: 102) == .switchOn)
    #expect(health.switchedOff(at: 104) == .restAll)
    #expect(health.restingSince == 104)
    #expect(health.foundOff(at: 105) == .stayOff)
    #expect(health.foundOff(at: 104 + TapHealth.rest - 0.1) == .stayOff)
    #expect(health.foundOff(at: 104 + TapHealth.rest) == .wakeAll)
    #expect(!health.isResting)
  }

  @Test func afterARestTheCountStartsAgain() {
    var health = TapHealth()
    for time in [100.0, 101, 102] { _ = health.switchedOff(at: time) }
    #expect(health.foundOff(at: 140) == .wakeAll)
    #expect(health.switchedOff(at: 141) == .switchOn)
    #expect(health.switchedOff(at: 142) == .switchOn)
    #expect(health.switchedOff(at: 143) == .restAll, "still too slow: rest again")
  }

  @Test func aTapFoundOffWithoutAWordGoesBackOn() {
    // macOS 26 tells the callback only in place of the next event the tap would have had (seen on
    // a real Mac, scripts/mac-shell/input-taps.sh). The check that runs every second is often first.
    var health = TapHealth()
    #expect(health.foundOff(at: 50) == .switchOn)
    #expect(!health.isResting)
  }

  @Test func switchOffsFoundWithoutAWordCountToo() {
    var health = TapHealth()
    #expect(health.foundOff(at: 100) == .switchOn)
    #expect(health.switchedOff(at: 103) == .switchOn)
    #expect(health.foundOff(at: 106) == .restAll, "the third in ten seconds")
    #expect(health.restingSince == 106)
    #expect(health.foundOff(at: 107) == .stayOff)
    #expect(health.foundOff(at: 106 + TapHealth.rest) == .wakeAll)
    // The end of a rest is not another switch-off.
    #expect(health.foundOff(at: 106 + TapHealth.rest + 1) == .switchOn)
    #expect(health.foundOff(at: 106 + TapHealth.rest + 2) == .switchOn)
    #expect(health.foundOff(at: 106 + TapHealth.rest + 3) == .restAll)
  }

  @Test func aWordThatComesDuringARestChangesNothing() {
    // macOS tells the callback late, so the word about the third switch-off can come after the check found it.
    var health = TapHealth()
    for time in [100.0, 101, 102] { _ = health.foundOff(at: time) }
    #expect(health.restingSince == 102)
    #expect(health.switchedOff(at: 103) == .stayOff)
    #expect(health.restingSince == 102, "the rest is not begun again")
  }

  // MARK: Several taps, one thread

  /// The taps of one thread as `EventTap` keeps them: each on or off, all doing as one health says.
  struct Taps {
    var isOn: [Bool]
    var health = TapHealth()
    /// How often all input on the Mac has waited for a tap that did not answer.
    var freezes = 0

    init(_ count: Int) { isOn = Array(repeating: true, count: count) }

    private mutating func act(on verdict: TapHealth.Verdict, _ tap: Int) {
      switch verdict {
      case .switchOn: isOn[tap] = true
      case .stayOff: break
      case .restAll: isOn = isOn.map { _ in false }
      case .wakeAll: isOn = isOn.map { _ in true }
      }
    }

    /// The thread does not answer. The event waits at the first tap that is on until macOS switches that one off.
    mutating func stall(at time: Double) {
      guard let tap = isOn.firstIndex(of: true) else { return }
      freezes += 1
      isOn[tap] = false
      act(on: health.switchedOff(at: time), tap)
    }

    /// `PointerInput` has every tap look at itself once a second.
    mutating func check(at time: Double) {
      for tap in isOn.indices where !isOn[tap] { act(on: health.foundOff(at: time), tap) }
    }
  }

  @Test(arguments: [1, 2, 5]) func threeFreezesAreTheLimitHoweverManyTapsThereAre(count: Int) {
    // With a count of its own for each tap, the next in the chain took over when the first went to rest: two taps
    // on mouse-downs froze the Mac six times before Arbor let go.
    var taps = Taps(count)
    for time in stride(from: 100.0, to: 109, by: 1) { taps.stall(at: time) }
    #expect(taps.freezes == TapHealth.limit)
    #expect(taps.isOn.allSatisfy { !$0 })
  }

  @Test func theEndOfARestIsNotCountedOnceForEachTap() {
    var taps = Taps(5)
    for time in [100.0, 101, 102] { taps.stall(at: time) }
    taps.check(at: 110)
    #expect(taps.isOn.allSatisfy { !$0 }, "resting")
    taps.check(at: 102 + TapHealth.rest)
    #expect(taps.isOn.allSatisfy { $0 }, "all back at once")
    #expect(!taps.health.isResting, "and five taps found off were not five new switch-offs")
    taps.stall(at: 140)
    #expect(taps.isOn.allSatisfy { $0 }, "the count began again")
  }
}

@Suite struct RectangleGestureTests {
  typealias Modifiers = RectangleGesture.Modifiers
  let frameKeys: Modifiers = [.control, .option]

  @Test func dragsWithoutTheModifierPassThrough() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: []) == .pass)
    #expect(gesture.mouseDragged(to: CGPoint(x: 400, y: 300)) == .pass)
    #expect(gesture.mouseUp(at: CGPoint(x: 400, y: 300)) == .pass)
    #expect(!gesture.isTracking)
  }

  @Test func aModifierDragDrawsABandAndFramesOnRelease() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys) == .hold)
    // Within the drag threshold it is still possibly a click.
    #expect(gesture.mouseDragged(to: CGPoint(x: 103, y: 98)) == .swallow)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .band(CGRect(x: 100, y: 100, width: 200, height: 150)))
    #expect(gesture.mouseDragged(to: CGPoint(x: 101, y: 101)) == .band(CGRect(x: 100, y: 100, width: 1, height: 1)))
    #expect(gesture.mouseDragged(to: CGPoint(x: 500, y: 400)) == .band(CGRect(x: 100, y: 100, width: 400, height: 300)))
    #expect(gesture.mouseUp(at: CGPoint(x: 520, y: 410)) == .frame(CGRect(x: 100, y: 100, width: 420, height: 310)))
    #expect(!gesture.isTracking)
    #expect(gesture.mouseDragged(to: CGPoint(x: 600, y: 600)) == .pass, "the gesture is over")
  }

  @Test func draggingUpAndLeftGivesTheSameRectangle() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 500, y: 400), modifiers: frameKeys)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .band(CGRect(x: 300, y: 250, width: 200, height: 150)))
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250)) == .frame(CGRect(x: 300, y: 250, width: 200, height: 150)))
  }

  @Test func aModifierClickIsHandedBackToTheApp() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys) == .hold)
    #expect(gesture.mouseUp(at: CGPoint(x: 100, y: 100)) == .replay)
    // A hand that wobbles a few points while clicking still clicks.
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys) == .hold)
    #expect(gesture.mouseDragged(to: CGPoint(x: 104, y: 96)) == .swallow)
    #expect(gesture.mouseUp(at: CGPoint(x: 104, y: 96)) == .replay)
    #expect(!gesture.isTracking)
  }

  @Test func theModifiersMustMatchExactly() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: .zero, modifiers: [.control, .option, .command]) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.control, .option, .shift]) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.control]) == .pass, "a click with ⌃ is the app's contextual menu")
    #expect(gesture.mouseDown(at: .zero, modifiers: [.option]) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift]) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift, .command]) == .pass, "the design tools' own, since 2026-10-14")
    gesture.trigger = [.shift, .command]
    #expect(gesture.mouseDown(at: .zero, modifiers: frameKeys) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift, .command]) == .hold)
  }

  @Test func anEmptyTriggerTurnsTheGestureOff() {
    // Otherwise every plain click would be taken.
    var gesture = RectangleGesture(trigger: [])
    #expect(gesture.mouseDown(at: .zero, modifiers: []) == .pass)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 300)) == .pass)
    #expect(!gesture.isTracking)
  }

  // The F05 follow-up (QUESTIONS Q11): plain ⇧-drag where no app's window is under the pointer.

  // MARK: Called off: the keys are let go before the button

  @Test func lettingGoOfTheKeysFirstCallsTheRectangleOff() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .band(CGRect(x: 100, y: 100, width: 200, height: 150)))
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: []) == .cancel)
    #expect(!gesture.isTracking)
    // The next one is a rectangle like any other.
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(
      gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: [.control, .option])
        == .frame(CGRect(x: 100, y: 100, width: 200, height: 150)))
  }

  @Test func oneOfTheKeysLetGoIsEnough() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: [.option]) == .cancel)
  }

  @Test func aKeyMoreAtTheEndCallsNothingOff() {
    // The keys it began with are all still down.
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(
      gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: [.control, .option, .shift])
        == .frame(CGRect(x: 100, y: 100, width: 200, height: 150)))
  }

  @Test func aShiftDragOnTheDesktopIsCalledOffByLettingGoOfShift() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.shift], onDesktop: true)
    gesture.desktopAnswered(isItem: false, press: 1)
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: []) == .cancel)
    // Also when Finder answered while the hand was at rest, so that no band was ever drawn.
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.shift], onDesktop: true)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .swallow)
    gesture.desktopAnswered(isItem: false, press: 2)
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250), modifiers: []) == .cancel)
  }

  @Test func aClickIsGivenBackWhateverTheKeysDoMeanwhile() {
    // Nothing was begun, so there is nothing to call off, and the app must not lose its press.
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    #expect(gesture.mouseUp(at: CGPoint(x: 101, y: 100), modifiers: []) == .replay)
  }

  @Test func whoeverDoesNotKnowTheKeysGetsTheRectangle() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option])
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250)) == .frame(CGRect(x: 100, y: 100, width: 200, height: 150)))
  }

  @Test func aShiftDragThatStartsOnTheDesktopFrames() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.shift], onDesktop: true) == .ask(press: 1))
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .band(CGRect(x: 100, y: 100, width: 200, height: 150)))
    // Only the start counts: the rectangle is drawn over the windows it is meant to frame.
    #expect(gesture.mouseUp(at: CGPoint(x: 500, y: 400)) == .frame(CGRect(x: 100, y: 100, width: 400, height: 300)))
    #expect(!gesture.isTracking)
  }

  @Test func aShiftDragThatStartsOverAnAppIsTheApps() {
    // It extends a selection there.
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.shift], onDesktop: false) == .pass)
    #expect(gesture.mouseDragged(to: CGPoint(x: 300, y: 250)) == .pass)
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 250)) == .pass)
  }

  @Test func aShiftClickOnTheDesktopStillReachesFinder() {
    // It adds an icon to the selection.
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.shift], onDesktop: true) == .ask(press: 1))
    gesture.desktopAnswered(isItem: false, press: 1)
    #expect(gesture.mouseDragged(to: CGPoint(x: 102, y: 101)) == .swallow)
    #expect(gesture.mouseUp(at: CGPoint(x: 102, y: 101)) == .replay)
    #expect(!gesture.isTracking)
  }

  @Test func onTheDesktopTheModifiersMustMatchExactlyToo() {
    var gesture = RectangleGesture()
    for modifiers: Modifiers in [[], [.command], [.shift, .option], [.shift, .control], [.option]] {
      #expect(gesture.mouseDown(at: .zero, modifiers: modifiers, onDesktop: true) == .pass, "\(modifiers.text)")
    }
  }

  @Test func theModifierDragStillWorksAnywhere() {
    var gesture = RectangleGesture()
    #expect(gesture.mouseDown(at: .zero, modifiers: frameKeys, onDesktop: false) == .hold)
    #expect(gesture.mouseDown(at: .zero, modifiers: frameKeys, onDesktop: true) == .hold)
  }

  @Test func whatIsUnderThePointerIsLookedUpOnlyForAShiftPress() {
    // Looking takes milliseconds, and every click on the Mac waits for the answer.
    var gesture = RectangleGesture()
    var looks = 0
    func look() -> Bool {
      looks += 1
      return true
    }
    _ = gesture.mouseDown(at: .zero, modifiers: [], onDesktop: look())
    _ = gesture.mouseDown(at: .zero, modifiers: [.command], onDesktop: look())
    _ = gesture.mouseDown(at: .zero, modifiers: frameKeys, onDesktop: look())
    _ = gesture.mouseDown(at: .zero, modifiers: [.shift, .option], onDesktop: look())
    #expect(looks == 0)
    _ = gesture.mouseDown(at: .zero, modifiers: [.shift], onDesktop: look())
    #expect(looks == 1)
  }

  @Test func theDesktopDragCanBeTurnedOffOnItsOwn() {
    var gesture = RectangleGesture(desktopTrigger: [])
    #expect(gesture.isEnabled)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift], onDesktop: true) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [], onDesktop: true) == .pass, "an empty trigger matches nothing")
    #expect(gesture.mouseDown(at: .zero, modifiers: frameKeys, onDesktop: true) == .hold)
  }

  @Test func theDesktopDragWorksWithTheModifierDragTurnedOff() {
    var gesture = RectangleGesture(trigger: [])
    #expect(gesture.isEnabled)
    #expect(gesture.mouseDown(at: .zero, modifiers: frameKeys, onDesktop: true) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [], onDesktop: true) == .pass)
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift], onDesktop: true) == .ask(press: 1))
  }

  @Test func withBothTurnedOffThereIsNothingToWatchFor() {
    #expect(!RectangleGesture(trigger: [], desktopTrigger: []).isEnabled)
  }

  @Test func shiftAsTheModifierForEverywhereWinsOverTheDesktop() {
    var gesture = RectangleGesture(trigger: [.shift])
    #expect(gesture.mouseDown(at: .zero, modifiers: [.shift], onDesktop: false) == .hold)
  }

  @Test func aMissedMouseUpStartsOver() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys)
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 300))
    #expect(gesture.mouseDown(at: CGPoint(x: 50, y: 50), modifiers: frameKeys) == .hold)
    #expect(gesture.mouseUp(at: CGPoint(x: 50, y: 50)) == .replay)
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys)
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 300))
    #expect(gesture.mouseDown(at: CGPoint(x: 50, y: 50), modifiers: []) == .pass)
    #expect(!gesture.isTracking)
  }

  @Test func resetForgetsTheDragInProgress() {
    var gesture = RectangleGesture()
    _ = gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: frameKeys)
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 300))
    gesture.reset()
    #expect(!gesture.isTracking)
    #expect(gesture.mouseUp(at: CGPoint(x: 300, y: 300)) == .pass)
  }

  @Test func modifiersParseNamesGlyphsAndAliases() {
    #expect(Modifiers(text: "shift+cmd") == [.shift, .command])
    #expect(Modifiers(text: "Command + Shift") == [.shift, .command])
    #expect(Modifiers(text: "⇧⌘") == [.shift, .command])
    #expect(Modifiers(text: "⌘+⇧") == [.shift, .command])
    #expect(Modifiers(text: "⌃⌥") == frameKeys)
    #expect(Modifiers(text: "ctrl+opt") == [.control, .option])
    #expect(Modifiers(text: "control+alt") == [.control, .option])
    #expect(Modifiers(text: "⌃⌥⇧⌘") == [.control, .option, .shift, .command])
    #expect(Modifiers(text: "none") == [])
    #expect(Modifiers(text: " Off ") == [])
  }

  @Test func modifiersRejectAnythingElse() {
    for text in ["", "+", "shift+", "+cmd", "hyper", "shift+x", "fn", "cmd shift", "⇧a"] {
      #expect(Modifiers(text: text) == nil, "\(text)")
    }
  }

  @Test func modifiersTextRoundTrips() {
    for raw in 0..<16 {
      let modifiers = Modifiers(rawValue: UInt8(raw))
      #expect(Modifiers(text: modifiers.text) == modifiers, "\(modifiers.text)")
    }
    #expect(frameKeys.text == Settings().frameRectangleModifier)
  }
}

extension Settings {
  /// Every gesture that needs an event tap switched on, whatever Arbor ships with: the pinch, ⌃⌥ + scroll, the ⌃⌥ rectangle, ⇧-drag on
  /// the Desktop. For a test that is about one of them.
  static var withGestures: Settings {
    var settings = Settings()
    settings.gesturesEnabled = true
    settings.scrollZoom = true
    settings.frameRectangleModifier = "ctrl+opt"
    settings.frameRectangleOnDesktop = true
    return settings
  }
}

@Suite struct PointerSettingsTests {
  @Test func oldSettingsFilesGetThePointerDefaults() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(settings.gesturesEnabled)
    #expect(settings.pinchThreshold == 0.25)
    #expect(settings.frameRectangleModifier == "ctrl+opt")
    #expect(RectangleGesture.Modifiers(text: settings.frameRectangleModifier) == [.control, .option])
    #expect(settings.frameRectangleOnDesktop)
  }

  @Test func pointerSettingsDecodeAndRoundTrip() throws {
    let json = #"""
      {"gesturesEnabled": false, "pinchThreshold": 0.4, "frameRectangleModifier": "ctrl+opt",
       "frameRectangleOnDesktop": false}
      """#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(!settings.frameRectangleOnDesktop)
    #expect(!settings.gesturesEnabled)
    #expect(settings.pinchThreshold == 0.4)
    #expect(settings.frameRectangleModifier == "ctrl+opt")
    let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(again == settings)
  }
}
