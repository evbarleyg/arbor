import ArborCore
import ArborTesting
import CoreGraphics
import Testing

@testable import ArborKit

/// What stands for a window has one look, at rest (a tile) and on its way (a card).
@MainActor @Suite struct TheCardIsTheTileTests {
  private let safari = RGBA(red: 0.1, green: 0.5, blue: 0.95)

  private func tile(_ settings: Settings, isDark: Bool) -> TileArt {
    let look = settings.appearanceOptions
    var model = TileModel(
      display: DisplayID("main"), node: NodeID(rawValue: 1), kind: .window, frame: CGRect(x: 0, y: 0, width: 300, height: 200),
      items: [TileModel.Item(window: WindowID(101), pid: 1, bundleID: nil, appName: "Safari", miniatureFrame: nil)])
    model.usesAppColour = look.usesAppColours
    model.colourAmount = look.appColourAmount
    return TileArt(model, isDark: isDark) { _ in safari }
  }

  private func motion(_ settings: Settings) throws -> Transition {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.overlays.clearTransitions()
    h.run("zoom \(a.rawValue)")
    return try #require(h.overlays.transitions.last)
  }

  @Test(arguments: [false, true]) func asItShipsTheirColoursAreTheSame(isDark: Bool) throws {
    let card = try motion(Settings()).cover.palette(appColour: safari, isDark: isDark)
    let plate = tile(Settings(), isDark: isDark).plate
    #expect(card.top == plate.top && card.bottom == plate.bottom && card.border == plate.border)
    // Pale in the light look, dark in the dark one, and nowhere the app's own colour.
    #expect(isDark ? card.top.luminance < 0.1 : card.top.luminance > 0.5)
  }

  @Test func andWhateverTheSettingsSay() throws {
    var grey = Settings()
    grey.appColours = false
    var strong = Settings()
    strong.appColourAmount = 0.6
    for settings in [grey, strong] {
      let card = try motion(settings).cover.palette(appColour: safari, isDark: false)
      let plate = tile(settings, isDark: false).plate
      #expect(card.top == plate.top && card.bottom == plate.bottom && card.border == plate.border)
    }
    #expect(try motion(grey).cover.palette(appColour: safari, isDark: false) == TilePalette(appColour: nil, amount: 0.25, isDark: false))
  }

  @Test func anAppWhoseColourIsNotKnownYetTravelsAsThePlainTile() {
    #expect(Transition.Cover().palette(appColour: nil, isDark: true) == TilePalette(appColour: nil, amount: 0.25, isDark: true))
  }

  @Test func theIconIsATilesHoweverLargeTheCard() {
    #expect(TileMetrics.iconSide(for: CGSize(width: 1400, height: 850)) == 64)
    #expect(TileMetrics.iconSide(for: CGSize(width: 100, height: 300)) == 45)
  }
}
