import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What tiles look like, and that the appearance settings reach them (docs/features/F15-appearance-options.md).
@Suite @MainActor struct TileArtTests {
  let blue = RGBA(red: 0.1, green: 0.45, blue: 0.95)
  let yellow = RGBA(red: 0.98, green: 0.85, blue: 0.3)

  /// [a / b | Desktop | c] on a display of `size`, which decides how large the tiles are. Each window
  /// belongs to its own app.
  func makeHarness(size: CGSize = CGSize(width: 700, height: 500), settings: Settings = Settings()) -> Harness {
    let frame = CGRect(origin: .zero, size: size)
    let h = Harness(
      displays: [DisplaySnapshot(id: DisplayID("main"), frame: frame, visibleFrame: frame, isMain: true)],
      settings: settings)
    h.system.cursor = frame.center
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    let c = h.system.open(app: "Mail", pid: 13)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(c.rawValue) right")
    return h
  }

  func tile(_ kind: Tile.Kind, _ h: Harness) -> TileModel? { h.overlays.tiles[h.display]?.first { $0.kind == kind } }

  /// A window's tile of the given size.
  func windowTile(
    _ width: CGFloat, _ height: CGFloat, app: String = "Mail", style: TileStyle = .icon
  ) throws -> TileModel {
    var model = try #require(tile(.window, makeHarness()))
    model.frame.size = CGSize(width: width, height: height)
    model.items[0].appName = app
    // Titles have tests of their own (TileCaptionTests).
    model.windowTitle = nil
    model.style = style
    return model
  }

  func art(_ model: TileModel, isDark: Bool = false, colour: RGBA? = nil) -> TileArt {
    TileArt(model, isDark: isDark) { _ in colour }
  }

  // MARK: The settings reach the tiles

  @Test func tilesCarryTheColourAndStyleSettings() throws {
    let standard = try #require(makeHarness().overlays.tiles[DisplayID("main")])
    #expect(Set(standard.map(\.kind)) == [.group, .desktop, .window])
    #expect(standard.allSatisfy { $0.usesAppColour && $0.colourAmount == 0.25 && $0.style == .name })

    var settings = Settings()
    settings.appColours = false
    settings.appColourAmount = 0.7
    settings.tileStyle = "icon"
    let h = makeHarness(settings: settings)
    #expect(h.overlays.tiles[h.display]?.count == 3)
    #expect(h.overlays.tiles[h.display]?.allSatisfy { !$0.usesAppColour && $0.colourAmount == 0.7 && $0.style == .icon } == true)

    h.controller.loadSettings = { Settings() }
    h.run("reload-settings")
    #expect(h.overlays.tiles[h.display] == standard)
  }

  @Test func settingsArborCannotUseReachTheTilesMadeSafe() {
    var settings = Settings()
    settings.appColourAmount = 12
    settings.tileStyle = "hologram"
    let h = makeHarness(settings: settings)
    #expect(h.overlays.tiles[h.display]?.allSatisfy { $0.colourAmount == 1 && $0.style == .name } == true)
  }

  @Test func gapsShowTheirHandleHideItOrAreNoHandlesAtAll() {
    func harness(_ gapHandles: String) -> Harness {
      var settings = Settings()
      settings.gapHandles = gapHandles
      return makeHarness(size: CGSize(width: 1440, height: 900), settings: settings)
    }
    let shown = harness("shown")
    #expect(shown.overlays.scenes[shown.display]?.showsSeamHandles == true)
    #expect(shown.overlays.seams[shown.display]?.count == 3)

    // Hidden: nothing is drawn, and dragging works as before.
    let hidden = harness("hidden")
    #expect(hidden.overlays.scenes[hidden.display]?.showsSeamHandles == false)
    #expect(hidden.overlays.seams[hidden.display] == shown.overlays.seams[shown.display])
    let seam = hidden.overlays.seams[hidden.display]!.first { $0.axis == .horizontal }!
    hidden.overlays.dragSeam(seam, by: 50)
    #expect(hidden.overlays.seams[hidden.display]!.first { $0.axis == .horizontal }!.frame.minX == seam.frame.minX + 50)

    // Off: there is nothing to drag, and windows are where they would be anyway.
    let off = harness("off")
    #expect(off.overlays.seams[off.display]?.isEmpty == true)
    #expect(off.layout?.windowFrames == shown.layout?.windowFrames)
    // A drag that was under way when the setting changed moves nothing more.
    off.overlays.dragSeam(seam, by: 50)
    #expect(off.layout?.windowFrames == shown.layout?.windowFrames)
    #expect(off.run("resize 101 right 40").ok, "the command still resizes")

    off.controller.loadSettings = { Settings() }
    off.run("reload-settings")
    #expect(off.overlays.seams[off.display]?.count == 3)
  }

  // MARK: Colours

  @Test func theTileMixesTheAppsColourIntoGreyByTheAmount() throws {
    var model = try windowTile(200, 300)
    for isDark in [false, true] {
      model.colourAmount = 0.25
      let plate = art(model, isDark: isDark, colour: blue).plate
      let expected = TilePalette(appColour: blue, amount: 0.25, isDark: isDark)
      #expect(plate.top == expected.top && plate.bottom == expected.bottom && plate.border == expected.border)
      model.colourAmount = 0.8
      #expect(art(model, isDark: isDark, colour: blue).plate.top == TilePalette(appColour: blue, amount: 0.8, isDark: isDark).top)
    }
  }

  @Test func withAppColoursOffEveryTileIsTheSameGreyAndNoIconIsExamined() throws {
    var model = try windowTile(200, 300)
    model.usesAppColour = false
    var asked = false
    let plate = TileArt(model, isDark: true) { _ in
      asked = true
      return self.blue
    }.plate
    #expect(!asked)
    #expect(plate.top == TilePalette(appColour: nil, amount: 0, isDark: true).top)
  }

  @Test func anAppWithoutAColourGetsTheGrey() throws {
    #expect(art(try windowTile(200, 300), colour: nil).plate.top == TilePalette(appColour: nil, amount: 0, isDark: false).top)
  }

  @Test func captionsAreBlackOnPaleTilesAndWhiteOnDeepOnes() throws {
    var model = try windowTile(200, 300, style: .name)
    #expect(art(model, isDark: false, colour: blue).caption?.colour == .black)
    #expect(art(model, isDark: true, colour: blue).caption?.colour == .white)
    model.colourAmount = 1
    #expect(art(model, isDark: true, colour: yellow).caption?.colour == .black, "white on yellow cannot be read")
    #expect(art(model, isDark: false, colour: RGBA(red: 0.1, green: 0.1, blue: 0.3)).caption?.colour == .white)
  }

  // MARK: A window's tile

  @Test func aWindowsTileShowsItsIconAlone() throws {
    let tile = art(try windowTile(200, 300))
    let icon = try #require(tile.icons.first)
    #expect(tile.icons.count == 1 && icon.pid == 13)
    #expect(icon.frame.size == CGSize(width: 64, height: 64))
    // In the middle, a touch above it: that is what looks centred.
    #expect(icon.frame.midX == 100 && icon.frame.midY <= 150 && icon.frame.midY >= 142)
    #expect(tile.caption == nil)
    #expect(tile.castsShadow && tile.glyph == nil && tile.badge == nil && tile.cells.isEmpty)
  }

  @Test func thePlainStyleShowsOnlyColour() throws {
    let window = art(try windowTile(200, 300, style: .plain), colour: blue)
    #expect(window.icons.isEmpty && window.caption == nil && window.glyph == nil)
    #expect(window.plate == art(try windowTile(200, 300), colour: blue).plate, "the colour is the same")

    var settings = Settings()
    settings.tileStyle = "plain"
    let h = makeHarness(settings: settings)
    let desktop = art(try #require(tile(.desktop, h)))
    #expect(desktop.glyph == nil && desktop.caption == nil)
    // A group keeps what makes it a group: its windows in miniature, and how many there are.
    let group = art(try #require(tile(.group, h)), colour: blue)
    #expect(group.icons.isEmpty && group.cells.count == 2 && group.badge?.label.text == "2")
  }

  @Test func theNameStylePutsTheAppsNameUnderTheIcon() throws {
    let model = try windowTile(200, 300, style: .name)
    let tile = art(model)
    let icon = try #require(tile.icons.first)
    let caption = try #require(tile.caption)
    #expect(tile.icons.count == 1 && icon.pid == 13)
    #expect(icon.frame.size == CGSize(width: 64, height: 64))
    #expect(icon.frame.midX == 100)
    #expect(caption.text == "Mail" && caption.size == 11 && !caption.isStrong && caption.alignment == .centre)
    #expect(caption.frame.midX == 100)
    #expect(caption.frame.minY >= icon.frame.maxY && caption.frame.minY - icon.frame.maxY <= 6)
    // The two are centred as one block, a touch above the middle.
    let block = icon.frame.union(caption.frame)
    #expect(block.midY <= 150 && block.midY >= 140)
    #expect(abs((300 - block.maxY) - block.minY - 12) <= 1, "six points above the middle: twelve more below than above")
    #expect(tile.castsShadow && tile.glyph == nil && tile.badge == nil && tile.cells.isEmpty)
  }

  @Test func theIconIsFortyFivePerCentOfTheShortSide() throws {
    #expect(art(try windowTile(100, 400)).icons.first?.frame.width == 45)
    #expect(art(try windowTile(600, 120)).icons.first?.frame.width == 54)
    #expect(art(try windowTile(236, 800)).icons.first?.frame.width == 64)
  }

  @Test func aNameTooLongForTheTileIsTruncatedNotDropped() throws {
    let caption = try #require(art(try windowTile(90, 300, app: "Visual Studio Code Insiders", style: .name)).caption)
    #expect(caption.text == "Visual Studio Code Insiders", "the label cuts it to fit when it is drawn")
    #expect(caption.frame.minX == 8 && caption.frame.maxX == 82)
  }

  @Test func aLowWideTileSetsTheNameBesideTheIcon() throws {
    let tile = art(try windowTile(600, 50, style: .name))
    let icon = try #require(tile.icons.first)
    let caption = try #require(tile.caption)
    #expect(icon.frame.midY == 25 && caption.frame.midY == 25)
    #expect(caption.alignment == .left && caption.frame.minX == icon.frame.maxX + 6)
    #expect(caption.frame.maxX == 592, "room for a longer name than estimated")
    // The pair is centred, give or take the estimate of the text's width.
    #expect(abs((icon.frame.minX + caption.frame.minX + 26) / 2 - 300) < 20)
  }

  @Test func aSmallTileShowsOnlyTheIconAndASpeckOnlyItsColour() throws {
    for style in [TileStyle.icon, .name] {
      let small = art(try windowTile(40, 40, style: style))
      #expect(small.icons.first?.frame == CGRect(x: 11, y: 10, width: 18, height: 18))
      #expect(small.caption == nil)
      let speck = art(try windowTile(20, 20, style: style))
      #expect(speck.icons.isEmpty && speck.caption == nil)
      #expect(!speck.plate.outline.isEmpty)
    }
  }

  // MARK: A group's tile

  @Test func aGroupsTileShowsItsWindowsInMiniatureWithACount() throws {
    let model = try #require(tile(.group, makeHarness()))
    let colours: [Int32: RGBA] = [11: blue, 12: yellow]
    let tile = TileArt(model, isDark: false) { colours[$0.pid] }
    #expect(tile.plate.top == TilePalette.tray(isDark: false).top)
    #expect(tile.caption == nil && tile.glyph == nil)

    // The miniature is inset evenly, and each window has its app's color and icon.
    let bounds = CGRect(origin: .zero, size: model.frame.size)
    #expect(tile.cells.count == 2)
    #expect(tile.cells[0].frame.union(tile.cells[1].frame) == bounds.insetBy(dx: 8, dy: 8))
    #expect(tile.cells[0].top == TilePalette(appColour: blue, amount: 0.25, isDark: false).top)
    #expect(tile.cells[1].top == TilePalette(appColour: yellow, amount: 0.25, isDark: false).top)
    #expect(tile.icons.map(\.pid) == [11, 12])
    for (icon, cell) in zip(tile.icons, tile.cells) {
      #expect(cell.frame.contains(icon.frame) && abs(icon.frame.midX - cell.frame.midX) <= 0.5)
    }

    let badge = try #require(tile.badge)
    #expect(badge.label.text == "2" && badge.label.colour == .white)
    #expect(bounds.insetBy(dx: 8, dy: 8).contains(badge.frame))
    #expect(bounds.maxX - badge.frame.maxX == bounds.maxY - badge.frame.maxY, "tucked evenly into the corner")
    #expect(badge.frame.contains(badge.label.frame))
  }

  @Test func theBadgeGrowsWithTheCountAndHidesNoIcon() throws {
    var model = try #require(tile(.group, makeHarness()))
    let one = try #require(art(model).badge)
    model.items += Array(repeating: model.items[0], count: 10)
    let twelve = try #require(art(model).badge)
    #expect(twelve.label.text == "12" && twelve.frame.width > one.frame.width && twelve.frame.maxX == one.frame.maxX)

    // A window whose icon would sit under the badge goes without.
    model.items = [model.items[1]]
    model.items[0].miniatureFrame = twelve.frame.insetBy(dx: -6, dy: -6).offsetBy(dx: model.frame.minX, dy: model.frame.minY)
    #expect(art(model).cells.count == 1 && art(model).icons.isEmpty)
  }

  @Test func aGroupsTileTooSmallForTheCountStillShowsItsIcons() throws {
    var model = try #require(tile(.group, makeHarness()))
    model.frame.size = CGSize(width: 90, height: 30)
    model.items = Array(model.items.prefix(2))
    model.items[0].miniatureFrame = CGRect(x: 3, y: 3, width: 40, height: 24).offsetBy(dx: model.frame.minX, dy: model.frame.minY)
    model.items[1].miniatureFrame = CGRect(x: 46, y: 3, width: 40, height: 24).offsetBy(dx: model.frame.minX, dy: model.frame.minY)
    let small = art(model)
    #expect(small.badge == nil)
    #expect(small.cells.count == 2 && small.icons.count == 2)
  }

  // MARK: Named spaces (F20)

  @Test func aNamedSpacesTileShowsItsNameWhateverTheStyle() throws {
    for style in [TileStyle.icon, .name, .plain] {
      var model = try windowTile(200, 300, style: style)
      model.name = "Post"
      let tile = art(model)
      #expect(tile.caption?.text == "Post", "\(style)")
      #expect(tile.icons.isEmpty == (style == .plain), "\(style)")
    }
    var desktop = try #require(tile(.desktop, makeHarness()))
    desktop.frame.size = CGSize(width: 200, height: 300)
    desktop.name = "Scratch"
    #expect(art(desktop).caption?.text == "Scratch" && art(desktop).glyph != nil)
  }

  @Test func aNamedGroupsCapsuleHoldsTheNameInPlaceOfTheCount() throws {
    var model = try #require(tile(.group, makeHarness()))
    let count = try #require(art(model).badge)
    model.name = "Writing"
    let named = try #require(art(model).badge)
    let bounds = CGRect(origin: .zero, size: model.frame.size)
    #expect(named.label.text == "Writing" && named.frame.width > count.frame.width)
    #expect(named.frame.maxX == count.frame.maxX && named.frame.maxY == count.frame.maxY && named.frame.height == count.frame.height)
    #expect(bounds.insetBy(dx: 8, dy: 8).contains(named.frame) && named.frame.contains(named.label.frame))
    #expect(art(model).caption == nil && art(model).cells.count == 2)

    // Wide letters get more room than narrow ones, and what is not ASCII the most.
    func width(_ name: String) throws -> CGFloat {
      model.name = name
      return try #require(art(model).badge).frame.width
    }
    #expect(try width("HHHH") > width("hhhh") && width("mmmm") > width("nnnn"))
    #expect(try width("写作写作") > width("WWWW"))

    // A name too long for the tile has all the room there is, and the UI cuts it short.
    let inset = bounds.maxX - count.frame.maxX
    #expect(try width(String(repeating: "Writing ", count: 20)) == bounds.width - 2 * inset)
  }

  @Test func aNamedGroupsTileWithoutRoomForTheNameShowsTheCount() throws {
    var model = try #require(tile(.group, makeHarness()))
    model.name = "Writing"
    model.frame.size = CGSize(width: 56, height: 120)
    #expect(art(model).badge?.label.text == "2")
  }

  @Test func theNameGivenToASpaceIsDrawnOnItsTile() throws {
    let h = makeHarness()
    h.overlays.clickTile(try #require(tile(.group, h)).node)
    #expect(h.run("name Writing").ok)
    h.run("show-all")
    #expect(art(try #require(tile(.group, h))).badge?.label.text == "Writing")
    h.run("unname Writing")
    #expect(art(try #require(tile(.group, h))).badge?.label.text == "2")
  }

  @Test func whatLooksCentredSitsALittleAboveTheMiddleByTheTilesHeight() throws {
    // Two per cent of the height, at most six points.
    let tall = try #require(art(try windowTile(100, 600)).icons.first)
    #expect(abs(tall.frame.midY - (300 - 6)) <= 0.5 && abs(tall.frame.midX - 50) <= 0.5)
    let low = try #require(art(try windowTile(600, 100)).icons.first)
    #expect(abs(low.frame.midY - (50 - 2)) <= 0.5 && abs(low.frame.midX - 300) <= 0.5)
  }

  // MARK: The Desktop's tile

  @Test func theDesktopsTileIsGlassWithAGlyphInBothModes() throws {
    var model = try #require(tile(.desktop, makeHarness()))
    model.style = .icon
    let tile = art(model, isDark: false, colour: blue)
    #expect(tile == art(model, isDark: true, colour: yellow), "the wallpaper does not change with the mode")
    #expect(tile.plate.top.alpha < 0.5, "the wallpaper shows through")
    #expect(!tile.castsShadow)
    let glyph = try #require(tile.glyph)
    #expect(glyph.symbol == "menubar.dock.rectangle" && glyph.frame.width <= 28)
    #expect(glyph.colour == .white && glyph.shadow != nil)
    #expect(glyph.frame.midX == model.frame.width / 2)
    #expect(tile.icons.isEmpty && tile.caption == nil)

    model.style = .name
    let named = art(model)
    let caption = try #require(named.caption)
    #expect(caption.text == "Desktop" && caption.colour == .white && caption.shadow != nil)
    #expect(caption.frame.minY > (named.glyph?.frame.maxY ?? .infinity))
  }

  // MARK: Every size

  @Test func hairlinesAreOnePixelWide() throws {
    let model = try windowTile(200, 300)
    func width(_ scale: CGFloat) -> CGFloat { TileArt(model, isDark: false, scale: scale) { _ in nil }.plate.borderWidth }
    #expect(width(1) == 1 && width(2) == 0.5 && width(3) == 1 / 3)
    #expect(width(0) == 1 && width(.nan) == 1 && width(-2) == 1)
  }

  /// Displays from tiny to small produce tiles of every kind and many sizes. Whatever the size, every part
  /// lies inside the tile, and the caption clears the icon.
  @Test func everyPartStaysInsideTheTileAtEverySize() {
    var seen: Set<Tile.Kind> = []
    for width in stride(from: CGFloat(60), through: 760, by: 70) {
      for height in stride(from: CGFloat(50), through: 500, by: 45) {
        for style in ["icon", "name", "plain"] {
          var settings = Settings()
          settings.tileStyle = style
          let h = makeHarness(size: CGSize(width: width, height: height), settings: settings)
          for model in h.overlays.tiles[h.display] ?? [] {
            seen.insert(model.kind)
            let bounds = CGRect(origin: .zero, size: model.frame.size)
            let tile = art(model, colour: blue)
            var frames = tile.icons.map(\.frame) + tile.cells.map(\.frame)
            frames += [tile.glyph?.frame, tile.caption?.frame, tile.badge?.frame, tile.badge?.label.frame].compactMap { $0 }
            for frame in frames {
              #expect(bounds.contains(frame), "\(frame) leaves a \(model.kind) tile of \(bounds.size)")
            }
            let outlines = [tile.plate.outline, tile.plate.borderOutline] + tile.cells.map(\.outline)
            for point in outlines.flatMap(\.points) {
              #expect(point.x >= -0.001 && point.x <= bounds.maxX + 0.001 && point.y >= -0.001 && point.y <= bounds.maxY + 0.001)
            }
            if let caption = tile.caption, model.kind != .group {
              for emblem in tile.icons.map(\.frame) + [tile.glyph?.frame].compactMap({ $0 }) {
                #expect(!caption.frame.overlaps(emblem))
              }
            }
          }
        }
      }
    }
    #expect(seen == [.window, .group, .desktop])
  }
}
