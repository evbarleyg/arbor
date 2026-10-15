import ArborCore
import ArborKit
import CoreGraphics
import Testing

/// Whether the words on Arbor's panels can be read, reckoned from what macOS's materials were measured to be.
@Suite struct PanelLookTests {
  struct Ground: CustomStringConvertible, Sendable {
    var description: String
    var isDark: Bool
    var colour: RGBA

    init(_ what: String, dark: Bool = false, _ red: Double, _ green: Double, _ blue: Double) {
      description = what
      isDark = dark
      colour = RGBA(red: red / 255, green: green / 255, blue: blue / 255)
    }
  }

  /// What a material comes to over what lies behind the panel. Read off pictures of the real panels on a hosted Mac with macOS
  /// 26.6 and Reduce Transparency off (2026-10-15, run 38669956766), over test windows of (255, 56, 60) and (0, 136, 255).
  static let measured: [Ground] = [
    Ground("hudWindow over red", 239, 131, 136), Ground("hudWindow over blue", 119, 197, 242),
    Ground("hudWindow over green hills", 129, 172, 150), Ground("popover over red", 237, 156, 160),
    Ground("popover over blue", 148, 213, 239), Ground("any, Reduce Transparency", 228, 228, 228),
    Ground("hudWindow over red", dark: true, 163, 44, 49), Ground("hudWindow over blue", dark: true, 21, 108, 166),
    Ground("hudWindow over a night sky", dark: true, 32, 33, 59), Ground("popover over red", dark: true, 122, 36, 42),
    Ground("popover over blue", dark: true, 29, 93, 125), Ground("any, Reduce Transparency", dark: true, 38, 38, 38),
  ]

  /// Not measured yet: reckoned from the above, which fit a material that lets through about half of what is behind it.
  static let reckoned: [Ground] = [
    Ground("hudWindow over black", 125, 125, 125), Ground("hudWindow over white", 244, 244, 244),
    Ground("hudWindow over white", dark: true, 164, 164, 164), Ground("hudWindow over black", dark: true, 21, 21, 21),
  ]

  /// On a picture thin strokes never reach their colour: 15-point text that is 6.9 to 1 by its colours measured 5.3. So the colours have
  /// to promise a third more than the picture is asked for.
  static let lostToThinStrokes = 4.0 / 3

  func contrast(of ink: PanelLook.Ink, on ground: Ground, veiled: Bool = true) -> Double {
    let under = veiled ? PanelLook.veil(isDark: ground.isDark).over(ground.colour) : ground.colour
    return PanelLook.ink(ink, isDark: ground.isDark).over(under).contrast(with: under)
  }

  @Test(arguments: measured + reckoned) func wordsAPersonMustReadStandOutByFourAndAHalfToOne(ground: Ground) {
    #expect(contrast(of: .main, on: ground) >= 4.5 * Self.lostToThinStrokes, "\(ground), dark: \(ground.isDark)")
  }

  @Test(arguments: measured + reckoned) func allOtherWordsByThreeToOne(ground: Ground) {
    #expect(contrast(of: .second, on: ground) >= 3 * Self.lostToThinStrokes, "\(ground), dark: \(ground.isDark)")
  }

  /// The control: what the veil is for.
  @Test func withoutTheVeilTheyWouldNot() {
    let bare = (Self.measured + Self.reckoned).filter { contrast(of: .second, on: $0, veiled: false) < 3 * Self.lostToThinStrokes }
    #expect(bare.contains { $0.description == "hudWindow over red" && $0.isDark })
    #expect(bare.contains { $0.description == "hudWindow over white" && $0.isDark })
  }

  /// And the greys that were there: macOS's secondary label colour came out as (129, 127, 128) in the light look and (124, 124, 124) in the dark one.
  @Test func norDidTheGreysThatStayedGrey() {
    for ground in Self.measured where ground.description.hasSuffix("over red") {
      let grey = RGBA(white: (ground.isDark ? 124 : 128) / 255)
      #expect(grey.contrast(with: ground.colour) < 3, "\(ground)")
    }
  }

  @Test func thePanelStillSaysWhatItFloatsOver() {
    for isDark in [false, true] {
      #expect(PanelLook.veil(isDark: isDark).alpha <= 0.6)
      let red = Self.measured.first { $0.description == "hudWindow over red" && $0.isDark == isDark }!
      let seen = PanelLook.veil(isDark: isDark).over(red.colour)
      #expect(seen.red - seen.blue > 0.15, "still plainly reddish: \(seen)")
    }
  }

  @Test func withIncreaseContrastTheInksAreStronger() {
    for isDark in [false, true] {
      let flat = RGBA(white: isDark ? 0.04 : 0.87)  // what the panels' grounds were with it on
      for ink in PanelLook.Ink.allCases {
        let plain = PanelLook.ink(ink, isDark: isDark), strong = PanelLook.ink(ink, isDark: isDark, increasesContrast: true)
        #expect(strong.alpha > plain.alpha)
        #expect(strong.over(flat).contrast(with: flat) >= 7, "\(ink), dark: \(isDark)")
      }
    }
  }

  @Test func oneTableOfCorners() {
    #expect(PanelLook.Corner.panel == 20)
    #expect(PanelLook.Corner.line(height: 38) == 19, "one line of text: a capsule")
    #expect(PanelLook.Corner.line(height: 56) == 20, "two: a panel")
    #expect(PanelLook.Corner.inside(20, inset: 8) == 12)
    #expect(PanelLook.Corner.inside(20, inset: 30) == 2)
  }
}
