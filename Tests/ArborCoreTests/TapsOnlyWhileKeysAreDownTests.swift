import CoreGraphics
import Testing

@testable import ArborCore

/// "Arbor stands in the path of your input only while you hold its keys" (board 1.53): when each event tap is wanted on.
/// The scroll tap's own tests are in ScrollZoomTests.
@Suite struct TapsOnlyWhileKeysAreDownTests {
  typealias Modifiers = RectangleGesture.Modifiers
  typealias Keys = GestureRouter.Keys

  /// Every combination of the four modifier keys.
  static let allModifiers: [Modifiers] = (0..<16).map { bits in
    var modifiers: Modifiers = []
    if bits & 1 != 0 { modifiers.insert(.control) }
    if bits & 2 != 0 { modifiers.insert(.option) }
    if bits & 4 != 0 { modifiers.insert(.shift) }
    if bits & 8 != 0 { modifiers.insert(.command) }
    return modifiers
  }
  static let allKeys: [Keys] = (0..<16).map {
    Keys(control: $0 & 1 != 0, option: $0 & 2 != 0, shift: $0 & 4 != 0, command: $0 & 8 != 0)
  }

  func gesture(_ change: (inout Settings) -> Void = { _ in }) -> RectangleGesture {
    var settings = Settings()
    change(&settings)
    var gesture = RectangleGesture()
    _ = gesture.follow(settings)
    return gesture
  }

  // MARK: As Arbor ships

  @Test func asArborShipsNoTapIsWantedOnWithNoKeyHeld() {
    // The sentence itself. Whoever adds a gesture that breaks it finds out here.
    let settings = Settings()
    #expect(!gesture().downTapIsWanted(modifiers: []))
    var router = GestureRouter()
    router.zoomsWithScroll = settings.scrollZoom
    router.zoomsOnDesktop = settings.scrollOnDesktopZooms
    router.pinchesOnDesktop = settings.pinchOnDesktop
    _ = router.setContinuous(settings.continuousZoom)
    #expect(!router.pinchTapIsWanted(keys: .none))
    #expect(!router.scrollTapIsWanted(keys: .none))
  }

  @Test func asArborShipsShiftAloneIsNotOneOfItsKeys() {
    // It goes down with every capital letter.
    #expect(!gesture().downTapIsWanted(modifiers: [.shift]))
    #expect(!GestureRouter().pinchTapIsWanted(keys: Keys(shift: true)))
  }

  // MARK: The tap on mouse-downs

  @Test func theDownTapIsWantedWithExactlyTheFrameKeysAndNoOthers() {
    let gesture = gesture()
    for modifiers in Self.allModifiers {
      #expect(gesture.downTapIsWanted(modifiers: modifiers) == (modifiers == [.control, .option]), "\(modifiers)")
    }
  }

  @Test func itGoesByTheKeysThatAreSet() {
    let gesture = gesture { $0.frameRectangleModifier = "shift+cmd" }
    #expect(gesture.downTapIsWanted(modifiers: [.shift, .command]))
    #expect(!gesture.downTapIsWanted(modifiers: [.control, .option]))
  }

  @Test func withTheRectangleOffNoKeysWantIt() {
    let gesture = gesture { $0.frameRectangleModifier = "none" }
    for modifiers in Self.allModifiers { #expect(!gesture.downTapIsWanted(modifiers: modifiers), "\(modifiers)") }
  }

  @Test func withShiftDragOnTheDesktopItIsWantedWhileShiftAloneIsDown() {
    let gesture = gesture { $0.frameRectangleOnDesktop = true }
    #expect(gesture.downTapIsWanted(modifiers: [.shift]))
    #expect(!gesture.downTapIsWanted(modifiers: []))
    #expect(!gesture.downTapIsWanted(modifiers: [.shift, .command]))
  }

  @Test func withTheGuardOfTheWallpaperClickItIsWantedAllDay() {
    let gesture = gesture { $0.guardDesktopClicks = true }
    for modifiers in Self.allModifiers { #expect(gesture.downTapIsWanted(modifiers: modifiers), "\(modifiers)") }
  }

  @Test func whileAPressIsFollowedItStaysWantedWhateverTheKeysDo() {
    // The keys come up in the middle of a drag. A press that came now would have to start the gesture over.
    var gesture = gesture()
    #expect(gesture.mouseDown(at: CGPoint(x: 100, y: 100), modifiers: [.control, .option]) == .hold)
    #expect(gesture.downTapIsWanted(modifiers: []))
    _ = gesture.mouseDragged(to: CGPoint(x: 300, y: 250))
    #expect(gesture.downTapIsWanted(modifiers: []))
    _ = gesture.mouseUp(at: CGPoint(x: 300, y: 250))
    #expect(!gesture.downTapIsWanted(modifiers: []), "over, and the keys are up")
  }

  @Test func whateverTheDownTapWouldTakeItIsWantedFor() {
    // The two must never part: a press that `mouseDown` would hold, with keys for which the tap is off, would be a dead gesture.
    for change: (inout Settings) -> Void in [
      { _ in }, { $0.frameRectangleOnDesktop = true }, { $0.guardDesktopClicks = true },
      { $0.frameRectangleModifier = "shift+cmd" }, { $0.frameRectangleModifier = "none" },
    ] {
      for modifiers in Self.allModifiers {
        var gesture = gesture(change)
        let isWanted = gesture.downTapIsWanted(modifiers: modifiers)
        let response = gesture.mouseDown(at: CGPoint(x: 10, y: 10), modifiers: modifiers, onDesktop: true)
        if response != .pass { #expect(isWanted, "\(modifiers): \(response)") }
      }
    }
  }

  // MARK: The pinch tap

  @Test func thePinchTapIsWantedWhileOptionIsDownWhateverElseIs() {
    // As the claim goes: ⌥ held as the pinch begins.
    let router = GestureRouter()
    for keys in Self.allKeys { #expect(router.pinchTapIsWanted(keys: keys) == keys.option, "\(keys)") }
  }

  @Test func whileAPinchOfArborsIsInProgressItStaysWantedWhateverTheKeysDo() {
    // ⌥ comes up before the fingers do. The rest of the pinch must not reach the app, which never saw it begin.
    var router = GestureRouter()
    _ = router.pinch(.began, magnification: 0, at: .zero, claim: true)
    #expect(router.pinchTapIsWanted(keys: .none))
    _ = router.pinch(.changed, magnification: 0.1, at: .zero)
    #expect(router.pinchTapIsWanted(keys: .none))
    _ = router.pinch(.ended, magnification: 0, at: .zero)
    #expect(!router.pinchTapIsWanted(keys: .none))
  }

  @Test func aRotationThatBeganDuringItKeepsItWantedUntilItEnds() {
    var router = GestureRouter()
    _ = router.pinch(.began, magnification: 0, at: .zero, claim: true)
    #expect(router.rotation(.began) == true)
    _ = router.pinch(.ended, magnification: 0, at: .zero)
    #expect(router.pinchTapIsWanted(keys: .none), "the rotation is Arbor's until it ends")
    #expect(router.rotation(.ended) == true)
    #expect(!router.pinchTapIsWanted(keys: .none))
  }

  @Test func anAppsPinchDoesNotKeepItWanted() {
    var router = GestureRouter()
    _ = router.pinch(.began, magnification: 0, at: .zero, claim: false)
    #expect(!router.pinchTapIsWanted(keys: .none))
  }

  @Test func afterAResetNothingIsInProgress() {
    var router = GestureRouter()
    _ = router.pinch(.began, magnification: 0, at: .zero, claim: true)
    _ = router.reset()
    #expect(!router.pinchTapIsWanted(keys: .none))
  }

  @Test func withThePinchOnTheDesktopItIsWantedAllDay() {
    var router = GestureRouter()
    router.pinchesOnDesktop = true
    for keys in Self.allKeys { #expect(router.pinchTapIsWanted(keys: keys), "\(keys)") }
  }

  // MARK: The settings say what they cost

  @Test func everySettingThatNeedsATapOnWithoutArborsKeysSaysSoAndShipsOff() throws {
    let defaults = Settings()
    #expect(!defaults.guardDesktopClicks && !defaults.scrollOnDesktopZooms && !defaults.pinchOnDesktop)
    #expect(!defaults.frameRectangleOnDesktop)
    for key in ["guardDesktopClicks", "scrollOnDesktopZooms", "pinchOnDesktop", "frameRectangleOnDesktop"] {
      let entry = try SettingsSchema.entry(named: key)
      #expect(entry.help.contains("Needs Arbor in the path of every"), "\(key)")
    }
    let master = try SettingsSchema.entry(named: "pointerGestures")
    #expect(master.help.contains("Arbor stands in the path of your input only while you hold its keys"))
  }
}
