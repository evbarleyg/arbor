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

  /// What a material comes to over what lies behind the panel. Read off pictures of the real panels on a hosted Mac
  /// with macOS 26.6 and Reduce Transparency off (2026-10-15, run 38669956766), over test windows of (255, 56, 60) and
  /// (0, 136, 255).
  static let measured: [Ground] = [
    Ground("hudWindow over red", 239, 131, 136), Ground("hudWindow over blue", 119, 197, 242),
    Ground("hudWindow over green hills", 129, 172, 150), Ground("popover over red", 237, 156, 160),
    Ground("popover over blue", 148, 213, 239), Ground("any, Reduce Transparency", 228, 228, 228),
    Ground("hudWindow over red", dark: true, 163, 44, 49), Ground("hudWindow over blue", dark: true, 21, 108, 166),
    Ground("hudWindow over a night sky", dark: true, 32, 33, 59), Ground("popover over red", dark: true, 122, 36, 42),
    Ground("popover over blue", dark: true, 29, 93, 125), Ground("any, Reduce Transparency", dark: true, 38, 38, 38),
  ]

  /// The same over plain wallpapers, the worst there is: (255, 82, 76), (0, 157, 255), white and black as they came out on
  /// screen. Read off pictures of the panels with the veil on them (run 38685258262), and the veil taken off again by
  /// arithmetic. In the dark look over white a material is lighter than anybody had reckoned: 172, not 164.
  static let overWallpapers: [Ground] = [
    Ground("hudWindow over red", 247, 141, 135), Ground("hudWindow over blue", 113, 209, 247),
    Ground("hudWindow over white", 247, 247, 247), Ground("hudWindow over black", 113, 113, 113),
    Ground("popover over red", 243, 163, 157), Ground("popover over blue", 141, 219, 243),
    Ground("popover over white", 243, 243, 243), Ground("popover over black", 141, 141, 141),
    Ground("hudWindow over red", dark: true, 172, 54, 47), Ground("hudWindow over blue", dark: true, 19, 122, 172),
    Ground("hudWindow over white", dark: true, 172, 172, 172), Ground("hudWindow over black", dark: true, 19, 19, 19),
    Ground("popover over red", dark: true, 132, 44, 39), Ground("popover over blue", dark: true, 27, 99, 132),
    Ground("popover over white", dark: true, 132, 132, 132), Ground("popover over black", dark: true, 27, 27, 27),
  ]

  /// On a picture thin strokes do not quite reach their colour. Measured on those pictures with the judges' ruler: words of 13
  /// points and more came out as their colours promise (5.79 for 5.79), the 10-point notes an eighth short (5.18 for 5.89). So
  /// the colours have to promise that much more than the picture is asked for, and a little.
  static let lostToThinStrokes = 1.15

  func contrast(of ink: PanelLook.Ink, on ground: Ground, veiled: Bool = true) -> Double {
    let under = veiled ? PanelLook.veil(isDark: ground.isDark).over(ground.colour) : ground.colour
    return PanelLook.ink(ink, isDark: ground.isDark).over(under).contrast(with: under)
  }

  @Test(arguments: measured + overWallpapers) func wordsAPersonMustReadStandOutByFourAndAHalfToOne(ground: Ground) {
    #expect(contrast(of: .main, on: ground) >= 4.5 * Self.lostToThinStrokes, "\(ground), dark: \(ground.isDark)")
  }

  @Test(arguments: measured + overWallpapers) func allOtherWordsByThreeToOne(ground: Ground) {
    #expect(contrast(of: .second, on: ground) >= 3 * Self.lostToThinStrokes, "\(ground), dark: \(ground.isDark)")
  }

  /// The control: what the veil is for.
  @Test func withoutTheVeilTheyWouldNot() {
    let bare = (Self.measured + Self.overWallpapers).filter {
      contrast(of: .second, on: $0, veiled: false) < 3 * Self.lostToThinStrokes
    }
    #expect(bare.contains { $0.description == "hudWindow over white" && $0.isDark })
    #expect(bare.contains { $0.description == "popover over white" && $0.isDark })
    #expect(bare.contains { $0.description == "hudWindow over black" && !$0.isDark })
  }

  /// And the greys that were there: macOS's secondary label colour came out as (129, 127, 128) in the light look and
  /// (124, 124, 124) in the dark one.
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
        let plain = PanelLook.ink(ink, isDark: isDark)
        let strong = PanelLook.ink(ink, isDark: isDark, increasesContrast: true)
        #expect(strong.alpha > plain.alpha)
        #expect(strong.over(flat).contrast(with: flat) >= 7, "\(ink), dark: \(isDark)")
      }
    }
  }

  /// About macOS's colours for a selected row, by accent colour, in the light look.
  @Test func onASelectedRowTheInkIsWhiteWhereWhiteCanBeRead() {
    let blue = RGBA(red: 0, green: 0.39, blue: 0.88), purple = RGBA(red: 0.49, green: 0.16, blue: 0.49)
    let yellow = RGBA(red: 0.87, green: 0.62, blue: 0.08), green = RGBA(red: 0.26, green: 0.57, blue: 0.14)
    for fill in [blue, purple] { #expect(PanelLook.ink(onSelection: fill) == .white) }
    #expect(PanelLook.ink(onSelection: yellow) == .black)
    for fill in [blue, purple, yellow, green] {
      let ink = PanelLook.ink(onSelection: fill)
      #expect(ink.contrast(with: fill) >= 4.5, "\(fill)")
    }
  }

  /// macOS's colour for a selected row with Increase Contrast, light and dark, read off pictures from a hosted Mac (run
  /// 38685258262). White on it is macOS's own pair and the measure; what Arbor makes fainter than that counts against Arbor.
  @Test func nothingOnASelectedRowIsThinned() {
    let light = RGBA(red: 0, green: 64 / 255, blue: 221 / 255), dark = RGBA(red: 23 / 255, green: 116 / 255, blue: 218 / 255)
    for fill in [light, dark] { #expect(PanelLook.ink(onSelection: fill) == .white) }
    #expect(RGBA.white.contrast(with: light) >= 7)
    // The control: the row's note at 0.85 of it, as it was. The ruler read 5.79 and 3.75.
    #expect(RGBA.white.withAlpha(0.85).over(light).contrast(with: light) < 6)
    #expect(RGBA.white.withAlpha(0.85).over(dark).contrast(with: dark) < 4)
  }

  // MARK: The field for a name

  static let underAHeadsUpPanel = (measured + overWallpapers).filter { !$0.description.hasPrefix("popover") }
  static let underGoTo = (measured + overWallpapers).filter { !$0.description.hasPrefix("hudWindow") }

  @Test(arguments: underAHeadsUpPanel) func theNameFieldsHeadingAndNoteAreReadToAct(ground: Ground) {
    for ink in [PanelLook.NameField.heading, PanelLook.NameField.note] {
      #expect(contrast(of: ink, on: ground) >= 4.5 * Self.lostToThinStrokes, "\(ground), dark: \(ground.isDark)")
    }
    #expect(contrast(of: PanelLook.NameField.placeholder, on: ground) >= 3 * Self.lostToThinStrokes, "\(ground)")
  }

  /// The control. The ruler read 4.09 off the picture.
  @Test func inTheSecondInkTheyCouldNotBeOverAWhiteWindowInTheDarkLook() throws {
    let worst = try #require(Self.underAHeadsUpPanel.min { contrast(of: .second, on: $0) < contrast(of: .second, on: $1) })
    #expect(worst.description == "hudWindow over white" && worst.isDark)
    #expect(abs(contrast(of: .second, on: worst) - 4.14) < 0.01)
  }

  // MARK: The line under Go to…'s field

  /// No mark is set for it. Half as much again as its ground is a line one finds when looking for it.
  @Test(arguments: underGoTo) func theLineUnderTheFieldCanBeSeen(ground: Ground) {
    let under = PanelLook.veil(isDark: ground.isDark).over(ground.colour)
    #expect(PanelLook.rule(isDark: ground.isDark).over(under).contrast(with: under) >= 1.5, "\(ground), dark: \(ground.isDark)")
    // The control: macOS's separator colour is the look's ink at a tenth.
    #expect(RGBA(white: ground.isDark ? 1 : 0, alpha: 0.1).over(under).contrast(with: under) < 1.5)
  }

  // MARK: With Increase Contrast

  /// What the panels' grounds were with it on: 229 and 22 of 255 (the same run).
  static func flat(isDark: Bool) -> RGBA { RGBA(white: (isDark ? 22 : 229) / 255) }

  @Test func withIncreaseContrastTheLineUnderTheFieldIsALine() {
    for isDark in [false, true] {
      let ground = Self.flat(isDark: isDark)
      #expect(PanelLook.rule(isDark: isDark, increasesContrast: true).over(ground).contrast(with: ground) >= 3)
    }
  }

  // MARK: The minimap

  /// White, black, a grey, and strong and dark colours of apps.
  static let apps: [RGBA] = [
    .white, .black, RGBA(white: 0.5), RGBA(red: 1, green: 0.22, blue: 0.24), RGBA(red: 0, green: 0.53, blue: 1),
    RGBA(red: 0.08, green: 0.12, blue: 0.31), RGBA(red: 1, green: 0.8, blue: 0),
  ]

  /// The line round a window of `app`'s, as it comes out on the window's own fill, against the map's ground.
  func line(_ strength: Double, round app: RGBA, isInView: Bool, on ground: RGBA, isDark: Bool) -> Double {
    let fill = app.withAlpha(isInView ? 1 : PanelLook.Map.fillOutOfView).over(ground)
    return RGBA(white: isDark ? 1 : 0, alpha: strength).over(fill).contrast(with: ground)
  }

  @Test(arguments: underAHeadsUpPanel) func aWindowOutOfViewHasALineThatStandsOutFromTheMap(ground: Ground) throws {
    let under = PanelLook.veil(isDark: ground.isDark).over(ground.colour)
    let strength = try #require(PanelLook.Map.line(isInView: false, increasesContrast: false))
    // Also an app of the ground's own colour: its fill is not there at all.
    for app in Self.apps + [under] {
      #expect(
        line(strength, round: app, isInView: false, on: under, isDark: ground.isDark) >= 3,
        "\(app) on \(ground), dark: \(ground.isDark)")
    }
  }

  /// The control: at 0.3, as it was. The ruler read 1.91 in the light look over black.
  @Test func atAThirdItDidNot() throws {
    let ground = try #require(Self.overWallpapers.first { $0.description == "hudWindow over black" && !$0.isDark })
    let under = PanelLook.veil(isDark: false).over(ground.colour)
    #expect(abs(line(0.3, round: under, isInView: false, on: under, isDark: false) - 1.95) < 0.02)
  }

  @Test func withIncreaseContrastEveryWindowOnTheMapAndTheDesktopHaveAWholeLine() throws {
    for isDark in [false, true] {
      let ground = Self.flat(isDark: isDark)
      for isInView in [false, true] {
        let strength = try #require(PanelLook.Map.line(isInView: isInView, increasesContrast: true))
        for app in Self.apps + [ground] {
          #expect(line(strength, round: app, isInView: isInView, on: ground, isDark: isDark) >= 3, "\(app), dark: \(isDark)")
        }
        let desktop = PanelLook.Map.desktopLine(isInView: isInView, increasesContrast: true)
        #expect(RGBA(white: isDark ? 1 : 0, alpha: desktop).over(ground).contrast(with: ground) >= 3)
      }
      // The control: the setting changed nothing. The ruler read 2.08 and 2.71 off the Desktop's rectangle.
      let before = PanelLook.Map.desktopLine(isInView: false, increasesContrast: false)
      #expect(RGBA(white: isDark ? 1 : 0, alpha: before).over(ground).contrast(with: ground) < 3)
    }
    #expect(PanelLook.Map.line(isInView: true, increasesContrast: false) == nil, "without it a window in view has its colour alone")
  }

  // MARK: Lines on other apps' windows

  func best(of lines: [RGBA], on ground: RGBA) -> Double { lines.map { $0.contrast(with: ground) }.max() ?? 1 }

  @Test func withIncreaseContrastOneOfTheLinesStandsOutFromAnyGround() {
    var worst = 21.0
    for white in 0...255 { worst = min(worst, best(of: PanelLook.strongLines, on: RGBA(white: Double(white) / 255))) }
    for red in stride(from: 0.0, through: 255, by: 15) {
      for green in stride(from: 0.0, through: 255, by: 15) {
        for blue in stride(from: 0.0, through: 255, by: 15) {
          worst = min(worst, best(of: PanelLook.strongLines, on: RGBA(red: red / 255, green: green / 255, blue: blue / 255)))
        }
      }
    }
    #expect(worst >= 4.5, "\(worst)")
  }

  /// The control: the accent colour as Increase Contrast makes it in the dark look, with a white line inside it, over the two windows
  /// of the picture. The ruler read 2.94 and 2.78.
  @Test func theAccentAndWhiteDidNot() {
    let accent = RGBA(red: 23 / 255, green: 116 / 255, blue: 218 / 255)
    let red = RGBA(red: 1, green: 97 / 255, blue: 101 / 255), cyan = RGBA(red: 59 / 255, green: 221 / 255, blue: 236 / 255)
    #expect(abs(best(of: [accent, .white], on: red) - 2.94) < 0.01)
    #expect(abs(best(of: [accent, .white], on: cyan) - 2.8) < 0.01)
    for window in [red, cyan] { #expect(best(of: PanelLook.strongLines, on: window) >= 7) }
  }

  /// The gap's handle is ordered behind the docked windows, and their shadows fall on it as on the wallpaper beside it: the accent
  /// (0, 64, 221) came out as (0, 45, 156) in the light look, (23, 116, 218) as (11, 56, 107) in the dark one (the same run). So white
  /// is a grey there. The grounds are what lay beside the handle in those pictures.
  @Test func inTheGapOneOfThemStillStandsOutUnderTheWindowsShadows() {
    let pictures: [(left: Double, grounds: [RGBA])] = [
      (0.705, [RGBA(red: 73 / 255, green: 101 / 255, blue: 81 / 255), RGBA(red: 77 / 255, green: 107 / 255, blue: 86 / 255)]),
      (0.49, [RGBA(red: 19 / 255, green: 19 / 255, blue: 41 / 255), RGBA(red: 23 / 255, green: 23 / 255, blue: 49 / 255)]),
    ]
    for (left, grounds) in pictures {
      let shaded = PanelLook.strongLines.map { $0.mixed(with: .black, amount: 1 - left) }
      for ground in grounds { #expect(best(of: shaded, on: ground) >= 3, "\(ground): \(best(of: shaded, on: ground))") }
    }
  }

  /// No red can be read on red: a problem is said in the main ink.
  @Test func aRedForWhatIsWrongCouldNotBeRead() {
    let systemRed = RGBA(red: 1, green: 0.22, blue: 0.24)
    let worst = Self.measured.filter { !$0.isDark }.map {
      systemRed.contrast(with: PanelLook.veil(isDark: false).over($0.colour))
    }.min()
    #expect((worst ?? 9) < 3)
  }

  @Test func oneTableOfCorners() {
    #expect(PanelLook.Corner.panel == 20)
    #expect(PanelLook.Corner.line(height: 38) == 19, "one line of text: a capsule")
    #expect(PanelLook.Corner.line(height: 56) == 20, "two: a panel")
    #expect(PanelLook.Corner.inside(20, inset: 8) == 12)
    #expect(PanelLook.Corner.inside(20, inset: 30) == 2)
  }
}
