import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The focus ring's settings and geometry (docs/features/F37-focus-ring.md).
@Suite struct FocusRingTests {
  // MARK: Colour

  @Test func coloursAreAccentOrHex() {
    #expect(FocusRingColour(text: "accent") == .accent)
    #expect(FocusRingColour(text: " Accent ") == .accent)
    #expect(FocusRingColour(text: "#FF8000") == .rgba(red: 1, green: 128.0 / 255, blue: 0, alpha: 1))
    #expect(FocusRingColour(text: "#ff800080") == .rgba(red: 1, green: 128.0 / 255, blue: 0, alpha: 128.0 / 255))
    #expect(FocusRingColour(text: "#00000000") == .rgba(red: 0, green: 0, blue: 0, alpha: 0))
    #expect(FocusRingColour(text: "#FFFFFFFF") == .rgba(red: 1, green: 1, blue: 1, alpha: 1))
  }

  @Test(arguments: [
    "", "#", "blue", "FF8000", "#FFF", "#FF80", "#FF80000", "#FF8000801", "#GG8000", "#+F8000", "#-F8000",
    "# FF800", "#FF 800", "0xFF8000", "#ＦＦ８０００", "accent2",
  ])
  func otherColoursAreRefused(text: String) {
    #expect(FocusRingColour(text: text) == nil)
  }

  // MARK: Settings

  @Test func theDefaultsAreAThinAccentLine() {
    #expect(Settings().focusRingOptions == FocusRingOptions(width: 3, colour: .accent, radius: 0))
    #expect(Settings().focusRingColourProblem == nil)
  }

  @Test func settingsFilesFromBeforeTheRingStillLoad() throws {
    let old = #"{"gap": 20, "tabsEnabled": true, "frameRectangleModifier": "ctrl+opt"}"#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(old.utf8))
    #expect(settings.gap == 20)
    #expect(settings.focusRing)
    #expect(settings.focusRingWidth == 3)
    #expect(settings.focusRingColour == "accent")
    #expect(settings.focusRingRadius == 0)
  }

  @Test func theRingsSettingsSurviveSavingAndLoading() throws {
    var settings = Settings()
    settings.focusRing = false
    settings.focusRingWidth = 5
    settings.focusRingColour = "#12345678"
    settings.focusRingRadius = 10
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(Settings.self, from: data) == settings)
  }

  @Test func switchedOffMeansNoOptions() {
    var settings = Settings()
    settings.focusRing = false
    #expect(settings.focusRingOptions == nil)
  }

  @Test func widthAndRadiusAreClamped() {
    var settings = Settings()
    settings.focusRingWidth = 0
    settings.focusRingRadius = -4
    #expect(settings.focusRingOptions?.width == 1)
    #expect(settings.focusRingOptions?.radius == 0)
    settings.focusRingWidth = -100
    #expect(settings.focusRingOptions?.width == 1)
    settings.focusRingWidth = 400
    settings.focusRingRadius = 1e9
    #expect(settings.focusRingOptions?.width == 12)
    #expect(settings.focusRingOptions?.radius == 60)
    settings.focusRingWidth = 4.5
    settings.focusRingRadius = 10
    #expect(settings.focusRingOptions?.width == 4.5)
    #expect(settings.focusRingOptions?.radius == 10)
  }

  @Test func anUnknownColourFallsBackToAccentAndSaysSo() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"focusRingColour": "mauve"}"#.utf8))
    #expect(settings.focusRingOptions?.colour == .accent)
    #expect(settings.focusRingColourProblem?.contains("mauve") == true)
  }

  // MARK: Geometry

  let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
  let window = CGRect(x: 100, y: 100, width: 600, height: 400)

  @Test func theLineLiesOutsideTheWindowWhenThereIsRoom() {
    let outer = FocusRingGeometry.outerFrame(around: window, width: 3, room: 12, within: screen)
    #expect(outer == CGRect(x: 97, y: 97, width: 606, height: 406))
  }

  @Test func withoutAGapTheLineLiesInside() {
    #expect(FocusRingGeometry.outerFrame(around: window, width: 3, room: 0, within: screen) == window)
    #expect(FocusRingGeometry.outerFrame(around: window, width: 3, room: -5, within: screen) == window)
  }

  @Test func aGapThinnerThanTheLineTakesWhatFits() {
    let outer = FocusRingGeometry.outerFrame(around: window, width: 6, room: 2, within: screen)
    #expect(outer == window.insetBy(dx: -2, dy: -2))
  }

  @Test func aWindowThatFillsTheScreenHasItsLineInside() {
    #expect(FocusRingGeometry.outerFrame(around: screen, width: 3, room: 3, within: screen) == screen)
  }

  @Test func onlyTheSidesAgainstTheScreenEdgeMoveInside() {
    let left = CGRect(x: 0, y: 26, width: 600, height: 400)
    let outer = FocusRingGeometry.outerFrame(around: left, width: 3, room: 3, within: screen)
    #expect(outer == CGRect(x: 0, y: 25, width: 603, height: 404))
  }

  @Test func aWindowHangingOffTheScreenKeepsItsLineAtItsOwnEdgeThere() {
    let hanging = CGRect(x: 1200, y: 700, width: 600, height: 400)
    let outer = FocusRingGeometry.outerFrame(around: hanging, width: 3, room: 3, within: screen)
    #expect(outer == CGRect(x: 1197, y: 697, width: 603, height: 403))
  }

  @Test func windowsTooSmallForALineGetNone() {
    let speck = CGRect(x: 10, y: 30, width: 11, height: 400)
    #expect(FocusRingGeometry.outerFrame(around: speck, width: 3, room: 0, within: screen) == nil)
    #expect(FocusRingGeometry.outerFrame(around: .zero, width: 1, room: 12, within: screen) == nil)
  }
}
