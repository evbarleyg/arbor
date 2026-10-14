import ArborCore
import CoreGraphics
import Testing

/// Where macOS itself takes a window that is let go (`MacTiling`). The points are the ones tried on a Mac: macOS 26.6, every
/// switch as it comes, a display of 1024×768 with the visible frame beginning at y 31.
@Suite struct MacTilingZoneTests {
  static let frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
  static let visible = CGRect(x: 0, y: 31, width: 1024, height: 674)

  func takes(_ tiling: MacTiling, _ x: CGFloat, _ y: CGFloat, option: Bool = false) -> Bool {
    claim(tiling, x, y, option: option) != nil
  }

  func claim(_ tiling: MacTiling, _ x: CGFloat, _ y: CGFloat, option: Bool = false) -> MacTiling.Claim? {
    tiling.claim(onWindowLetGoAt: CGPoint(x: x, y: y), on: Self.frame, visibleFrame: Self.visible, optionHeld: option)
  }

  @Test(arguments: [
    (0, 368), (1023, 368), (512, 30), (512, 24), (512, 16), (512, 8), (512, 4), (512, 1), (512, 0), (0, 31), (0, 0), (0, 60),
    (0, 250), (0, 500), (0, 700), (0, 740), (0, 767),
  ])
  func macOSShowedItsPreviewHere(x: CGFloat, y: CGFloat) {
    #expect(takes(.on, x, y))
    #expect(!takes(.off, x, y))
  }

  @Test(arguments: [
    (1, 368), (2, 368), (3, 368), (1021, 368), (1022, 368), (512, 31), (512, 32), (512, 42), (512, 103), (512, 767),
    (-40, 368),
  ])
  func andNotHere(x: CGFloat, y: CGFloat) {
    #expect(!takes(.on, x, y))
  }

  /// Where a display was until a moment ago there is nothing for macOS to tile on.
  @Test func beyondTheDisplayNothingIsTaken() {
    for (x, y) in [(-40, 368), (1024, 368), (2000, 368), (512, -1), (512, 768)] as [(CGFloat, CGFloat)] {
      #expect(!takes(.on, x, y) && !takes(.on, x, y, option: true), "\(x) \(y)")
    }
  }

  /// Which says what macOS makes of the window, and whether it was asked for.
  @Test func theClaimSaysWhy() {
    #expect(claim(.on, 0, 368) == .side && claim(.on, 1023, 368) == .side)
    #expect(claim(.on, 512, 0) == .menuBar)
    #expect(claim(.on, 0, 0) == .side, "in the corner of the menu bar macOS showed a quarter")
    #expect(claim(.on, 512, 368, option: true) == .optionKey)
    #expect(claim(.on, 0, 368, option: true) == .side && claim(.on, 512, 0, option: true) == .menuBar)
  }

  @Test func withOptionHeldItTakesTheWindowAnywhere() {
    #expect(takes(.on, 200, 368, option: true))
    #expect(takes(.on, 512, 368, option: true))
    #expect(!takes(.on, 512, 368))
    #expect(!takes(.off, 512, 368, option: true))
  }

  @Test func eachSwitchCountsForItsOwnPlacesOnly() {
    let sides = MacTiling([.screenEdges]), top = MacTiling([.menuBar]), option = MacTiling([.optionKey])
    #expect(takes(sides, 0, 368) && !takes(sides, 512, 0) && !takes(sides, 512, 368, option: true))
    #expect(!takes(top, 0, 368) && takes(top, 512, 0) && !takes(top, 512, 368, option: true))
    #expect(!takes(option, 0, 368) && !takes(option, 512, 0) && takes(option, 512, 368, option: true))
    // The two that have nothing to do with drags.
    #expect(MacTiling([.clickWallpaper, .stageManager]) == .off)
    #expect(MacTiling(MacSwitch.inTheWay(macOS: 26) { _ in nil }) == .on, "as a Mac comes")
    #expect(MacTiling(MacSwitch.inTheWay(macOS: 14) { _ in nil }) == .off, "macOS 14 tiles nothing")
  }

  /// Measured from the display under the pointer, not from zero, and a pointer between two whole points counts too.
  @Test func aSecondDisplayHasEdgesOfItsOwn() {
    let frame = CGRect(x: 1024, y: -200, width: 1920, height: 1080)
    let visible = CGRect(x: 1024, y: -175, width: 1920, height: 1055)
    func takes(_ x: CGFloat, _ y: CGFloat) -> Bool {
      MacTiling.on.claim(onWindowLetGoAt: CGPoint(x: x, y: y), on: frame, visibleFrame: visible, optionHeld: false) != nil
    }
    #expect(takes(1024, 300) && takes(1024.5, 300) && !takes(1025, 300))
    #expect(takes(2943, 300) && takes(2943.5, 300) && !takes(2942.5, 300))
    #expect(takes(2000, -200) && takes(2000, -176) && !takes(2000, -175))
  }

  /// With the menu bar hidden the visible frame begins where the display does, and the pointer stops in its first row.
  @Test func withoutAMenuBarTheTopIsTheFirstRow() {
    let tiling = MacTiling.on
    func claim(_ y: CGFloat) -> MacTiling.Claim? {
      tiling.claim(onWindowLetGoAt: CGPoint(x: 512, y: y), on: Self.frame, visibleFrame: Self.frame, optionHeld: false)
    }
    #expect(claim(0) == .menuBar)
    #expect(claim(1) == nil)
  }
}
