import ArborCore
import CoreGraphics
import Foundation
import Testing

@Suite struct AppearanceSettingsTests {
  func decode(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  @Test func oldSettingsFilesGetTheAppearanceDefaults() throws {
    let settings = try decode(#"{"gap": 20, "tabsEnabled": true}"#)
    #expect(settings.gap == 20)
    #expect(settings.dimBehindArranged == 0.25)
    #expect(settings.blurBehindArranged == 0)
    #expect(settings.appColours)
    #expect(settings.appColourAmount == 0.25)
    #expect(settings.gapHandles == "shown")
    #expect(settings.tileStyle == "name")
    #expect(settings.tintBehindArranged == 0)
    #expect(settings.desktopEdge == 0.05)
    #expect(settings.tileFade == 0.2)
    #expect(settings.valueProblems.isEmpty)
    #expect(
      settings.appearanceOptions
        == AppearanceOptions(
          dim: 0.25, blur: 0, usesAppColours: true, appColourAmount: 0.25, gapHandles: .shown, tileStyle: .name,
          tint: 0, desktopEdge: 0.05, tileFade: 0.2))
  }

  @Test func appearanceSettingsDecodeAndRoundTrip() throws {
    let settings = try decode(
      """
      {"dimBehindArranged": 0.4, "blurBehindArranged": 0.7, "appColours": false, "appColourAmount": 0.6,
       "gapHandles": "hidden", "tileStyle": "name", "tintBehindArranged": 0.8, "desktopEdge": 0.1, "tileFade": 0.5}
      """)
    #expect(
      settings.appearanceOptions
        == AppearanceOptions(
          dim: 0.4, blur: 0.7, usesAppColours: false, appColourAmount: 0.6, gapHandles: .hidden, tileStyle: .name,
          tint: 0.8, desktopEdge: 0.1, tileFade: 0.5))
    #expect(settings.valueProblems.isEmpty)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }

  @Test func newSettingsFilesListTheAppearanceKeys() throws {
    let json = String(decoding: try JSONEncoder().encode(Settings()), as: UTF8.self)
    for key in [
      "dimBehindArranged", "blurBehindArranged", "appColours", "appColourAmount", "gapHandles", "tileStyle",
      "tintBehindArranged", "desktopEdge", "tileFade",
    ] {
      #expect(json.contains("\"\(key)\""), "\(key)")
    }
  }

  @Test func amountsOutsideTheirRangesAreClampedAndReported() throws {
    let settings = try decode(#"{"dimBehindArranged": 3, "blurBehindArranged": -5, "appColourAmount": 1e9}"#)
    let options = settings.appearanceOptions
    #expect(options.dim == 1 && options.blur == 0 && options.appColourAmount == 1)
    #expect(settings.valueProblems.count == 3)
    #expect(settings.valueProblems.contains { $0.hasPrefix("dimBehindArranged") })

    // Someone who read "blur" as a radius in points gets all the blur there is.
    #expect(try decode(#"{"blurBehindArranged": 20}"#).appearanceOptions.blur == 1)
  }

  @Test func theLeftoversAreClampedAndReportedLikeTheRest() throws {
    let settings = try decode(#"{"tintBehindArranged": 2, "desktopEdge": -1, "tileFade": 30}"#)
    let options = settings.appearanceOptions
    #expect(options.tint == 1 && options.desktopEdge == 0 && options.tileFade == 1)
    #expect(settings.valueProblems.count == 3)
    for key in ["tintBehindArranged", "desktopEdge", "tileFade"] {
      #expect(settings.valueProblems.contains { $0.hasPrefix(key) }, "\(key)")
      #expect(try SettingsSchema.entry(named: key).section == .appearance && SettingsSchema.entry(named: key).isAdvanced)
    }
    var odd = Settings()
    odd.tintBehindArranged = .nan
    odd.desktopEdge = .infinity
    odd.tileFade = -.infinity
    #expect(odd.appearanceOptions.tint == 0 && odd.appearanceOptions.desktopEdge == 0.05)
    #expect(odd.appearanceOptions.tileFade == 0.2)
  }

  /// A `Settings` made in code has not been through the schema.
  @Test func valuesFromAnywhereAreMadeSafeToDrawWith() {
    var settings = Settings()
    settings.dimBehindArranged = .nan
    settings.blurBehindArranged = .infinity
    settings.appColourAmount = -.infinity
    settings.tileStyle = "hologram"
    settings.gapHandles = "sometimes"
    var options = settings.appearanceOptions
    #expect(options.dim == 0.25 && options.blur == 0 && options.appColourAmount == 0.25)
    #expect(options.tileStyle == .name && options.gapHandles == .shown)
    settings.dimBehindArranged = 40
    settings.blurBehindArranged = -1
    options = settings.appearanceOptions
    #expect(options.dim == 1 && options.blur == 0)
  }

  @Test func everyChoiceIsRead() throws {
    for (text, style) in [("icon", TileStyle.icon), ("name", .name), ("plain", .plain)] {
      #expect(try decode(#"{"tileStyle": "\#(text)"}"#).appearanceOptions.tileStyle == style)
    }
    for (text, handles) in [("shown", GapHandles.shown), ("hidden", .hidden), ("off", .off)] {
      let settings = try decode(#"{"gapHandles": "\#(text)"}"#)
      #expect(settings.appearanceOptions.gapHandles == handles && settings.valueProblems.isEmpty)
    }
  }

  @Test func unknownChoicesFallBackToTheDefaultsAndAreReported() throws {
    let settings = try decode(#"{"tileStyle": "hologram", "gapHandles": "sometimes", "gap": 8}"#)
    #expect(settings.gap == 8, "the rest of the file still loads")
    #expect(settings.appearanceOptions.tileStyle == .name)
    #expect(settings.appearanceOptions.gapHandles == .shown)
    #expect(settings.valueProblems.count == 2)
    #expect(settings.valueProblems.contains { $0.hasPrefix("tileStyle") })
    #expect(settings.valueProblems.contains { $0.hasPrefix("gapHandles") })
  }

  @Test func theSettingsCommandsKnowTheSixKeys() throws {
    for key in ["dimBehindArranged", "blurBehindArranged", "appColours", "appColourAmount", "gapHandles", "tileStyle"] {
      #expect(try SettingsSchema.entry(named: key).section == .appearance, "\(key)")
    }
    #expect(try !SettingsSchema.entry(named: "dimBehindArranged").isAdvanced)
    #expect(try SettingsSchema.entry(named: "dimBehindArranged").label == "Darken behind docked windows")
    #expect(try SettingsSchema.entry(named: "blurBehindArranged").label == "Blur behind docked windows")
  }
}

@Suite struct TileMetricsTests {
  @Test func theIconIsNearlyHalfTheShortSideUpToSixtyFourPoints() {
    #expect(TileMetrics.iconSide(for: CGSize(width: 100, height: 400)) == 45)
    #expect(TileMetrics.iconSide(for: CGSize(width: 400, height: 100)) == 45)
    #expect(TileMetrics.iconSide(for: CGSize(width: 230, height: 800)) == 64)
    #expect(TileMetrics.iconSide(for: CGSize(width: 50, height: 50)) == 22, "whole points")
    #expect(TileMetrics.iconSide(for: .zero) == 0)
    #expect(TileMetrics.iconSide(for: CGSize(width: CGFloat.nan, height: 10)) == 0)
  }

  @Test func theMiniatureIsInsetByTheSameAmountOnEverySide() {
    #expect(TileMetrics.miniatureInset(for: CGSize(width: 230, height: 400)) == 8)
    #expect(TileMetrics.miniatureInset(for: CGSize(width: 60, height: 400)) == 5)
    #expect(TileMetrics.miniatureInset(for: CGSize(width: 20, height: 20)) == 3)

    // The layout engine uses it: the miniature's windows span the tile less the inset on all four sides.
    var tree = LayoutTree()
    let a = WindowID(1), b = WindowID(2), c = WindowID(3)
    let leaf = tree.dock(a, beside: tree.root, edge: .left)
    tree.dock(b, beside: leaf, edge: .bottom)
    tree.dock(c, beside: tree.root, edge: .right)
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: CGRect(x: 0, y: 25, width: 700, height: 875), isPresent: { _ in true })
    let tile = layout.tiles.first { $0.kind == .group }!
    let union = tile.miniature.values.reduce(CGRect.null) { $0.union($1) }
    #expect(union == tile.frame.insetBy(dx: 8, dy: 8))
    #expect(tile.miniature[b]!.minY - tile.miniature[a]!.maxY == TileMetrics.miniatureGap)
  }
}

@Suite struct TilePaletteTests {
  let blue = RGBA(red: 0.1, green: 0.45, blue: 0.95)
  let yellow = RGBA(red: 0.98, green: 0.85, blue: 0.3)

  /// The colour between the two ends of the fill.
  func middle(_ palette: TilePalette) -> RGBA { palette.top.mixed(with: palette.bottom, amount: 0.5) }

  @Test func withoutAnAppColourTheTileIsGrey() {
    for isDark in [false, true] {
      let palette = TilePalette(appColour: nil, amount: 0.25, isDark: isDark)
      let colour = middle(palette)
      #expect(max(colour.red, colour.green, colour.blue) - min(colour.red, colour.green, colour.blue) < 0.03)
      #expect(palette == TilePalette(appColour: blue, amount: 0, isDark: isDark), "an amount of 0 is the same gray")
      #expect(palette == TilePalette(appColour: nil, amount: 1, isDark: isDark))
    }
  }

  @Test func moreOfTheAppColourMovesTheTileTowardIt() {
    func distance(_ a: RGBA, _ b: RGBA) -> Double {
      abs(a.red - b.red) + abs(a.green - b.green) + abs(a.blue - b.blue)
    }
    for isDark in [false, true] {
      let steps = [0, 0.25, 0.5, 1].map { distance(middle(TilePalette(appColour: blue, amount: $0, isDark: isDark)), blue) }
      #expect(steps == steps.sorted(by: >) && Set(steps).count == 4)
      // This blue is of middling lightness, so it gives way to its ink a little (`theInkCanBeReadOnEveryPartOfEveryFill`).
      #expect(steps[3] < 0.4, "at 1 the tile is the app's color, but for the gradient and what the ink needs: \(steps[3])")
      let navy = RGBA(red: 0.05, green: 0.1, blue: 0.35)
      #expect(distance(middle(TilePalette(appColour: navy, amount: 1, isDark: isDark)), navy) < 0.1, "a deep colour is left as it is")
    }
  }

  @Test func tilesAreLightInLightModeAndDarkInDarkMode() {
    #expect(middle(TilePalette(appColour: blue, amount: 0.25, isDark: false)).luminance > 0.5)
    #expect(middle(TilePalette(appColour: blue, amount: 0.25, isDark: true)).luminance < 0.1)
    #expect(TilePalette(appColour: blue, amount: 0.25, isDark: false).ink == .black)
    #expect(TilePalette(appColour: blue, amount: 0.25, isDark: true).ink == .white)
  }

  @Test func aPaleAppColourGetsBlackTextEvenInDarkMode() {
    #expect(TilePalette(appColour: yellow, amount: 1, isDark: true).ink == .black)
    #expect(TilePalette(appColour: RGBA(red: 0.1, green: 0.1, blue: 0.3), amount: 1, isDark: false).ink == .white)
  }

  @Test func theFillIsASubtleGradientLitFromAbove() {
    for isDark in [false, true] {
      let palette = TilePalette(appColour: blue, amount: 0.25, isDark: isDark)
      #expect(palette.top.luminance > palette.bottom.luminance)
      #expect(palette.top.contrast(with: palette.bottom) < 1.5)
      #expect(palette.top.alpha == 1 && palette.bottom.alpha == 1, "tiles hide what is behind them")
    }
  }

  @Test func textCanBeReadAndTheBorderShowsOnEveryAppColour() {
    let steps = stride(from: 0.0, through: 1.0, by: 0.125)
    for red in steps {
      for green in steps {
        for blue in steps {
          for (amount, isDark) in [(0.25, false), (0.25, true), (1, false), (1, true)] {
            let palette = TilePalette(appColour: RGBA(red: red, green: green, blue: blue), amount: amount, isDark: isDark)
            #expect(palette.ink.contrast(with: palette.top) >= 4 && palette.ink.contrast(with: palette.bottom) >= 4)
            // The hairline is a faint version of the ink, so it contrasts with the fill in both modes.
            #expect(palette.border.withAlpha(1) == palette.ink && palette.border.alpha > 0.05 && palette.border.alpha < 0.3)
          }
        }
      }
    }
  }

  @Test func aGroupsTrayIsDarkerThanTheWindowsInIt() {
    for isDark in [false, true] {
      let tray = middle(TilePalette.tray(isDark: isDark))
      #expect(tray.luminance < middle(TilePalette(appColour: nil, amount: 0, isDark: isDark)).luminance)
    }
  }

  /// Seen on a Mac with Apple's own icons: at full strength two of their colours left the name under 4.5 to 1.
  @Test func theInkCanBeReadOnEveryPartOfEveryFill() {
    let steps = stride(from: 0.0, through: 1.0, by: 0.1)
    for red in steps {
      for green in steps {
        for blue in steps {
          for amount in [0, 0.25, 0.5, 0.75, 1] {
            for isDark in [false, true] {
              let colour = RGBA(red: red, green: green, blue: blue)
              let palette = TilePalette(appColour: colour, amount: amount, isDark: isDark)
              let least = min(palette.ink.contrast(with: palette.top), palette.ink.contrast(with: palette.bottom))
              #expect(least >= TilePalette.legibleContrast, "\(colour) at \(amount), dark \(isDark): \(least) to 1")
            }
          }
        }
      }
    }
  }

  @Test func onlyAFillOfMiddlingLightnessGivesWayToItsInk() {
    // Pale and deep fills are the app's color as mixed, shaded by 6 % either way.
    for (colour, isDark) in [(RGBA(red: 0.1, green: 0.4, blue: 0.9), false), (RGBA(red: 0.98, green: 0.85, blue: 0.3), true)] {
      let grey = isDark ? RGBA(red: 0.173, green: 0.173, blue: 0.180) : RGBA(red: 0.949, green: 0.949, blue: 0.969)
      let base = grey.mixed(with: colour, amount: 0.25)
      let palette = TilePalette(appColour: colour, amount: 0.25, isDark: isDark)
      #expect(palette.top == base.mixed(with: .white, amount: 0.06) && palette.bottom == base.mixed(with: .black, amount: 0.06))
    }
    // This red is neither: its better ink falls short on the half of the fill that is shaded towards it, so the red moves away
    // from the ink until it can be read on all of it. It stays red.
    let red = RGBA(red: 0.9, green: 0.2, blue: 0.2)
    let palette = TilePalette(appColour: red, amount: 1, isDark: false)
    #expect(red.ink.contrast(with: red.mixed(with: red.ink == .black ? .black : .white, amount: 0.06)) < TilePalette.legibleContrast)
    #expect(palette.ink == red.ink)
    #expect(palette.top.red > palette.top.green * 2 && palette.top.red > palette.top.blue * 2)
  }

  @Test func theDesktopsTileIsGlassWithWhiteShadowedText() {
    let palette = TilePalette.desktop
    #expect(palette.top.alpha < 0.5 && palette.bottom.alpha < 0.5 && palette.top.alpha > 0)
    #expect(palette.ink == .white)
    #expect(palette.inkShadow != nil)
  }
}

@Suite struct SeamHandleTests {
  @Test func thePillLiesAlongTheMiddleOfTheSeam() {
    // Between two columns: an upright strip, so an upright pill.
    let upright = CGRect(x: 476, y: 37, width: 12, height: 851)
    #expect(SeamHandle.pill(in: upright, axis: .horizontal) == CGRect(x: 480, y: 444.5, width: 4, height: 36))
    // Between two rows.
    let level = CGRect(x: 12, y: 457, width: 464, height: 12)
    #expect(SeamHandle.pill(in: level, axis: .vertical) == CGRect(x: 226, y: 461, width: 36, height: 4))
  }

  @Test func aShortSeamGetsAShorterPillAndATinyOneNone() {
    #expect(SeamHandle.pill(in: CGRect(x: 0, y: 0, width: 12, height: 40), axis: .horizontal)?.height == 24)
    #expect(SeamHandle.pill(in: CGRect(x: 0, y: 0, width: 12, height: 27), axis: .horizontal) == nil)
  }

  @Test func aNarrowGapGetsAThinnerPillAndAHairlineGapNone() {
    #expect(SeamHandle.pill(in: CGRect(x: 0, y: 0, width: 3, height: 400), axis: .horizontal)?.width == 3)
    #expect(SeamHandle.pill(in: CGRect(x: 0, y: 0, width: 1, height: 400), axis: .horizontal) == nil)
    #expect(SeamHandle.pill(in: .zero, axis: .horizontal) == nil)
    #expect(SeamHandle.pill(in: .null, axis: .vertical) == nil)
  }

  @Test func thePillStaysInsideItsSeam() {
    for width in stride(from: CGFloat(2), through: 40, by: 1) {
      for height in stride(from: CGFloat(2), through: 120, by: 7) {
        let seam = CGRect(x: 100, y: 50, width: width, height: height)
        for axis in Axis.allCases {
          if let pill = SeamHandle.pill(in: seam, axis: axis) { #expect(seam.contains(pill)) }
        }
      }
    }
  }
}
