#if os(macOS)
  import AppKit
  import ArborCore
  import ArborTesting
  import CoreGraphics
  import Foundation
  import QuartzCore
  import Testing

  @testable import ArborKit

  private func near(_ a: RGBA, _ b: RGBA, within tolerance: Double = 0.04) -> Bool {
    abs(a.red - b.red) <= tolerance && abs(a.green - b.green) <= tolerance && abs(a.blue - b.blue) <= tolerance
      && abs(a.alpha - b.alpha) <= tolerance
  }

  private let red = RGBA(red: 0.9, green: 0.1, blue: 0.1)
  private let blue = RGBA(red: 0.1, green: 0.2, blue: 0.9)

  /// Red above, blue below, so that an icon drawn upside down shows.
  private func twoHalves() -> NSImage {
    NSImage(size: NSSize(width: 64, height: 64), flipped: false) { _ in
      NSColor(srgbRed: 0.1, green: 0.2, blue: 0.9, alpha: 1).setFill()
      NSRect(x: 0, y: 0, width: 64, height: 32).fill()
      NSColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1).setFill()
      NSRect(x: 0, y: 32, width: 64, height: 32).fill()
      return true
    }
  }

  /// What `TileArt` decides is tested without a screen on every platform (`TileArtTests`). This checks that AppKit draws
  /// it as decided: the right way up, in the right colours, inside the right shapes.
  @Suite @MainActor struct TileDrawingTests {
    func model(_ kind: Tile.Kind, size: CGSize, style: TileStyle = .icon, apps: [String] = ["Notes"]) -> TileModel {
      var items: [TileModel.Item] = []
      for (index, app) in apps.enumerated() {
        let width = (size.width - 16 - CGFloat(apps.count - 1) * 3) / CGFloat(apps.count)
        items.append(
          TileModel.Item(
            window: WindowID(UInt32(index + 1)), pid: Int32(index + 1), bundleID: nil, appName: app,
            miniatureFrame: kind == .group
              ? CGRect(x: 8 + CGFloat(index) * (width + 3), y: 8, width: width, height: size.height - 16) : nil))
      }
      var model = TileModel(
        display: DisplayID("main"), node: NodeID(1), kind: kind, frame: CGRect(origin: .zero, size: size),
        items: kind == .desktop ? [] : items)
      model.style = style
      return model
    }

    @Test func aTileIsRoundedLitFromAboveAndItsIconIsTheRightWayUp() throws {
      let size = CGSize(width: 200, height: 160)
      let art = TileArt(model(.window, size: size), isDark: false, scale: 2, cornerRadius: 17) { _ in blue }
      let canvas = try OffscreenPicture(size: size)
      let icon = twoHalves()
      canvas.draw { _ in TileDrawing.draw(art, image: { _ in icon }) }
      try canvas.save("test-window-tile", item: "F15")

      for corner in [CGPoint(x: 1, y: 1), CGPoint(x: 198.5, y: 1), CGPoint(x: 1, y: 158.5), CGPoint(x: 198.5, y: 158.5)] {
        #expect(canvas.pixel(corner.x, corner.y).alpha == 0, "the corners are cut off")
      }
      #expect(near(canvas.colour(100, 3), art.plate.top), "the lighter end of the fill is at the top")
      #expect(near(canvas.colour(100, 157), art.plate.bottom))
      let frame = try #require(art.icons.first?.frame)
      #expect(near(canvas.colour(frame.midX, frame.minY + frame.height * 0.25), red), "the icon's top is at the top")
      #expect(near(canvas.colour(frame.midX, frame.minY + frame.height * 0.75), blue))
      #expect(near(canvas.colour(frame.minX - 3, frame.midY), art.plate.top.mixed(with: art.plate.bottom, amount: 0.5)))
    }

    @Test func nothingIsDrawnOutsideTheTileAndItsCornersAreAWindows() throws {
      let size = CGSize(width: 200, height: 160)
      let origin = CGPoint(x: 30, y: 20)
      for kind in [Tile.Kind.window, .group, .desktop] {
        let art = TileArt(
          model(kind, size: size, style: .name, apps: ["Notes", "Mail"]), isDark: false, scale: 2, cornerRadius: 17
        ) { _ in blue }
        let canvas = try OffscreenPicture(size: CGSize(width: 260, height: 200))
        let icon = twoHalves()
        canvas.draw { context in
          context.translateBy(x: origin.x, y: origin.y)
          TileDrawing.draw(art, image: { _ in icon })
        }
        try canvas.save("test-bounds-\(kind.rawValue)", item: "F15")
        let all = canvas.count(in: CGRect(x: 0, y: 0, width: 260, height: 200)) { $0.alpha > 0 }
        let inside = canvas.count(in: CGRect(origin: origin, size: size)) { $0.alpha > 0 }
        #expect(all == inside, "\(kind): \(all - inside) pixels outside the tile")

        // On the diagonal a corner of radius 17 begins about 5 points in from both edges.
        for (dx, dy) in [(1.0, 1.0), (-1, 1), (1, -1), (-1, -1)] {
          let corner = CGPoint(x: dx > 0 ? origin.x : origin.x + 200, y: dy > 0 ? origin.y : origin.y + 160)
          #expect(canvas.pixel(corner.x + dx * 3, corner.y + dy * 3).alpha == 0, "\(kind): cut off 3 points in")
          #expect(canvas.pixel(corner.x + dx * 7.5, corner.y + dy * 7.5).alpha > 0.15, "\(kind): filled 7.5 points in")
        }
      }
    }

    @Test func theIconIsDrawnAsLargeAsDecided() throws {
      // 45 % of the short side, at most 64 points.
      for (size, side) in [(CGSize(width: 200, height: 160), CGFloat(64)), (CGSize(width: 300, height: 80), 36)] {
        let art = TileArt(model(.window, size: size), isDark: false, scale: 2, cornerRadius: 17) { _ in nil }
        let canvas = try OffscreenPicture(size: size)
        let icon = twoHalves()
        canvas.draw { _ in TileDrawing.draw(art, image: { _ in icon }) }
        let coloured = canvas.count(in: CGRect(origin: .zero, size: size)) {
          near(RGBA($0), red, within: 0.1) || near(RGBA($0), blue, within: 0.1)
        }
        // In pixels, four to the square point; the rows where red meets blue may be neither.
        let expected = Int(side * side * 4)
        #expect(abs(coloured - expected) <= Int(side * 2 * 6), "\(size): \(coloured) pixels, not about \(expected)")
      }
    }

    @Test func theNameIsDrawnInItsPlaceInItsColour() throws {
      let size = CGSize(width: 200, height: 160)
      for isDark in [false, true] {
        let art = TileArt(model(.window, size: size, style: .name), isDark: isDark, scale: 2, cornerRadius: 17) { _ in
          blue
        }
        let canvas = try OffscreenPicture(size: size, mode: isDark ? .dark : .light)
        canvas.draw { _ in TileDrawing.draw(art, image: { _ in nil }) }
        let caption = try #require(art.caption)
        let ink = canvas.count(in: caption.frame) { near(RGBA($0), caption.colour, within: 0.25) }
        #expect(ink > 30, "the letters of Notes, in \(isDark ? "dark" : "light") mode")
        let below = CGRect(x: 8, y: caption.frame.maxY + 2, width: 184, height: 20)
        #expect(canvas.count(in: below) { near(RGBA($0), caption.colour, within: 0.25) } == 0, "and nothing under them")
      }
    }

    @Test func theDesktopsGlyphExistsAndIsWhite() throws {
      let size = CGSize(width: 160, height: 300)
      let art = TileArt(model(.desktop, size: size), isDark: false, scale: 2, cornerRadius: 17) { _ in nil }
      let glyph = try #require(art.glyph)
      #expect(NSImage(systemSymbolName: glyph.symbol, accessibilityDescription: nil) != nil, "\(glyph.symbol)")
      let canvas = try OffscreenPicture(size: size)
      canvas.draw { _ in TileDrawing.draw(art) }
      try canvas.save("test-desktop-tile", item: "F15")
      #expect(canvas.count(in: glyph.frame) { $0.alpha > 0.8 && $0.brightness > 0.8 } > 30)
      #expect(canvas.pixel(80, 40).alpha < 0.4, "the rest is glass")
    }

    @Test func aGroupsTileShowsItsCellsAndItsCount() throws {
      let size = CGSize(width: 300, height: 140)
      let art = TileArt(
        model(.group, size: size, apps: ["Notes", "Mail"]), isDark: false, scale: 2, cornerRadius: 17
      ) { $0.appName == "Notes" ? red : blue }
      let canvas = try OffscreenPicture(size: size)
      canvas.draw { _ in TileDrawing.draw(art, image: { _ in nil }) }
      try canvas.save("test-group-tile", item: "F15")
      #expect(art.cells.count == 2)
      let left = canvas.pixel(art.cells[0].frame.midX, art.cells[0].frame.midY)
      let right = canvas.pixel(art.cells[1].frame.midX, art.cells[1].frame.midY)
      #expect(left.red > left.blue && right.blue > right.red, "each window in its app's colour")
      let badge = try #require(art.badge)
      #expect(canvas.count(in: badge.frame) { $0.brightness > 0.85 } > 3, "the digit")
    }

    @Test func aNamedGroupsCapsuleIsWideEnoughForTheName() throws {
      let size = CGSize(width: 400, height: 140)
      for name in ["Writing", "mmmmwwww", "HOME OFFICE 2026", "Büro", "good dog bob", "写作空间", "🎧 Music"] {
        var model = model(.group, size: size, apps: ["Notes", "Mail"])
        model.name = name
        let art = TileArt(model, isDark: false, scale: 2, cornerRadius: 17) { _ in blue }
        let badge = try #require(art.badge)
        let font = NSFont.systemFont(ofSize: badge.label.size, weight: .semibold)
        let width = (name as NSString).size(withAttributes: [.font: font]).width
        #expect(badge.label.text == name)
        #expect(width + 8 <= badge.label.frame.width, "\(name) is \(width) wide, its capsule \(badge.label.frame.width)")
        #expect(badge.label.frame.width <= width * 1.5 + 24, "\(name): nor is the capsule much too wide")
        let canvas = try OffscreenPicture(size: size)
        canvas.draw { _ in TileDrawing.draw(art, image: { _ in nil }) }
        try canvas.save("test-named-group-\(badge.label.text.count)-\(Int(width))", item: "F15")
        #expect(canvas.count(in: badge.frame) { $0.brightness > 0.85 } > 3, "\(name) is drawn")
      }
    }

    // MARK: Colours from icons

    @Test func anIconsColourIsReadFromItsPixels() throws {
      // A white tile with a red glyph, on a transparent margin: what many app icons are.
      let icon = NSImage(size: NSSize(width: 128, height: 128), flipped: false) { _ in
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 12, y: 12, width: 104, height: 104), xRadius: 24, yRadius: 24).fill()
        NSColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 40, y: 40, width: 48, height: 48)).fill()
        return true
      }
      let colour = try #require(AppAppearance.colour(of: icon))
      // The glyph's edge is mixed with the white around it, so it is a little paler than the red that was drawn.
      #expect(colour.red > 0.8 && colour.green < 0.35 && colour.blue < 0.35, "\(colour)")

      // Half transparent all over: the colour is the same, not half as bright.
      let faint = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
        NSColor(srgbRed: 0.1, green: 0.2, blue: 0.9, alpha: 0.5).setFill()
        rect.fill()
        return true
      }
      let seen = try #require(AppAppearance.colour(of: faint))
      #expect(abs(seen.red - blue.red) < 0.08 && abs(seen.green - blue.green) < 0.08 && abs(seen.blue - blue.blue) < 0.08)

      #expect(AppAppearance.colour(of: NSImage(size: NSSize(width: 32, height: 32))) == nil, "nothing to see")
    }

    // MARK: The backdrop

    @Test func theBackdropsLayerDarkensTheSlotsAndLeavesTheRestAlone() throws {
      // One slot in the top left of a display whose visible frame starts under the menu bar.
      let frame = CGRect(x: 0, y: 25, width: 720, height: 450)
      let model = BackdropModel(
        frame: frame, rects: [CGRect(x: 6, y: 31, width: 300, height: 200)], growth: 6, dim: 0.25, blur: 0)
      let surface = BackdropLayer()
      surface.show(model, in: frame, fade: 0)
      let canvas = try OffscreenPicture(size: frame.size)
      canvas.draw(surface.layer)
      try canvas.save("test-backdrop-layer", item: "F15")

      #expect(near(canvas.colour(150, 100), RGBA.black.withAlpha(0.25)), "inside, counted from the top of the visible frame")
      #expect(canvas.pixel(150, 350).alpha == 0, "below it")
      #expect(canvas.pixel(500, 100).alpha == 0, "beside it")
      #expect(canvas.pixel(7, 7).alpha == 0, "its corner is rounded")
      #expect(canvas.pixel(3, 100).alpha == 0 && canvas.pixel(9, 100).alpha > 0.2, "its edge is where the model says")

      surface.show(nil, in: frame, fade: 0)
      let empty = try OffscreenPicture(size: frame.size)
      empty.draw(surface.layer)
      #expect(empty.pixel(150, 100).alpha == 0)
    }

    @Test func theBackdropsLayerTintsAndDrawsTheLineAroundTheDesktop() throws {
      let frame = CGRect(x: 0, y: 25, width: 720, height: 450)
      let desktop = CGRect(x: 320, y: 37, width: 388, height: 426)
      let model = BackdropModel(
        frame: frame, rects: [CGRect(x: 6, y: 31, width: 300, height: 438)], growth: 6, dim: 0.25, blur: 0, tint: 0.5,
        desktop: desktop, desktopEdge: 1)
      let surface = BackdropLayer()
      surface.match(scale: 2)
      surface.show(model, in: frame, fade: 0)
      let canvas = try OffscreenPicture(size: frame.size)
      canvas.draw(surface.layer)
      try canvas.save("test-backdrop-tint-and-edge", item: "F36")

      let accent = try #require(NSColor.controlAccentColor.usingColorSpace(.sRGB))
      let expected = model.fill(
        accent: RGBA(
          red: Double(accent.redComponent), green: Double(accent.greenComponent), blue: Double(accent.blueComponent)))
      #expect(near(canvas.colour(150, 200), expected), "the accent colour over the black")

      // Half a point wide, just inside the Desktop's left edge, which is 320 from the left.
      #expect(canvas.pixel(320.25, 200).alpha > 0.8 && canvas.pixel(320.25, 200).brightness > 0.9)
      #expect(canvas.pixel(319.25, 200).alpha == 0 && canvas.pixel(322, 200).alpha == 0, "and nowhere else")
      #expect(canvas.pixel(500, 12.25).alpha > 0.8, "its top edge is 12 below the top of the visible frame")
      #expect(canvas.pixel(321, 13).alpha == 0, "its corners are rounded")
    }
  }

  // MARK: Pictures

  /// Whole scenes from the real controller (`OffscreenScene.swift`), saved for people to look at.
  @Suite @MainActor struct AppearancePictures {
    func picture(_ h: Harness, isDark: Bool, name: String) throws {
      let picture = try OffscreenPicture(size: h.system.displays()[0].frame.size, scale: 1, mode: isDark ? .dark : .light)
      picture.draw(display: h)
      try picture.save(name, item: "F15")
    }

    func harness(_ settings: Settings, squeezed: Bool) -> Harness {
      let h = Harness(settings: settings)
      var pid: Int32 = 2000
      func open(_ app: String) -> UInt32 {
        pid += 1
        return h.system.open(app: app, pid: pid).rawValue
      }
      let safari = open("Safari"), notes = open("Notes"), mail = open("Mail"), music = open("Music")
      let terminal = open("Terminal"), photos = open("Photos"), calendar = open("Calendar"), messages = open("Messages")
      h.start()
      h.run("dock \(safari) left")
      h.run("dock \(mail) right")
      if squeezed {
        h.run("resize \(safari) right 160")
        h.run("resize \(mail) left 160")
        h.run("dock \(notes) beside \(safari) bottom")
        h.run("resize \(notes) top -300")
        h.run("dock \(music) beside \(notes) bottom")
        h.run("dock \(terminal) beside \(mail) bottom")
        h.run("resize \(terminal) top -260")
        h.run("dock \(photos) beside \(terminal) right")
        h.run("dock \(calendar) beside \(photos) right")
        h.run("dock \(messages) beside \(calendar) bottom")
      } else {
        h.run("dock \(notes) beside \(safari) bottom")
        h.run("dock \(music) beside \(mail) bottom")
        h.run("dock \(terminal) beside \(music) right")
        h.run("dock \(photos) beside \(terminal) bottom")
        h.run("dock \(calendar) beside \(notes) right")
        h.run("dock \(messages) beside \(calendar) right")
      }
      return h
    }

    @Test func scenesInBothModes() throws {
      var icons = Settings()
      icons.tileStyle = "icon"
      var strong = Settings()
      strong.appColourAmount = 0.6
      var tinted = Settings()
      tinted.tintBehindArranged = 0.2
      tinted.desktopEdge = 0.3
      for isDark in [false, true] {
        let mode = isDark ? "dark" : "light"
        try picture(harness(Settings(), squeezed: false), isDark: isDark, name: "scene-\(mode)")
        try picture(harness(Settings(), squeezed: true), isDark: isDark, name: "scene-squeezed-\(mode)")
        try picture(harness(icons, squeezed: true), isDark: isDark, name: "scene-icons-\(mode)")
        try picture(harness(strong, squeezed: false), isDark: isDark, name: "scene-colour-60-\(mode)")
        try picture(harness(tinted, squeezed: false), isDark: isDark, name: "scene-tint-20-edge-30-\(mode)")
      }
    }

    /// The product owner's measure (collab/QUESTIONS.md, Q15): on a laptop's 1440 points, four apps that will not be smaller than
    /// the real ones, two of them Safari windows. Can the two be told apart from the picture?
    @Test func twoSafariWindowsOnALaptop() throws {
      for style in ["name", "icon"] {
        var settings = Settings()
        settings.tileStyle = style
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let h = Harness(
          displays: [
            DisplaySnapshot(
              id: DisplayID("main"), frame: frame, visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)
          ], settings: settings)
        func open(_ app: String, _ title: String, _ pid: Int32, least: CGFloat) -> UInt32 {
          h.system.open(
            app: app, title: title, pid: pid, frame: CGRect(x: 100, y: 100, width: 1100, height: 700),
            minimumSize: CGSize(width: least, height: 240)
          ).rawValue
        }
        let trains = open("Safari", "Train times to the coast", 2001, least: 574)
        let bread = open("Safari", "Bread without kneading", 2001, least: 574)
        let messages = open("Messages", "Family", 2002, least: 760)
        let notes = open("Notes", "Shopping", 2003, least: 709)
        h.start()
        h.run("dock \(trains) left")
        h.run("dock \(messages) right")
        h.run("dock \(bread) beside \(trains) right")
        h.run("dock \(notes) beside \(messages) left")
        h.run("show-all")
        let tiles = try #require(h.overlays.tiles[h.display]).filter { $0.kind == .window }
        #expect(tiles.contains { $0.items.first?.appName == "Safari" }, "one of the two is a tile")
        for mode in OffscreenPicture.Mode.allCases {
          let picture = try OffscreenPicture(size: frame.size, scale: 2, mode: mode)
          picture.draw(display: h)
          try picture.save("two-safaris-\(style)-\(mode.rawValue)@2x", item: "F15")
        }
      }
    }

    /// With the colours of real icons, as drawn: the darkest or lightest pixel of the name against the tile beside it.
    @Test func namesCanBeReadOnTheTilesOfApplesOwnApps() throws {
      let size = CGSize(width: 200, height: 120)
      for app in AppleIcons.paths.keys.sorted() {
        guard let image = AppleIcons.icon(app), let colour = AppAppearance.colour(of: image) else { continue }
        for amount in [0.25, 1] {
          for mode in OffscreenPicture.Mode.allCases {
            var tile = TileModel(
              display: DisplayID("main"), node: NodeID(1), kind: .window, frame: CGRect(origin: .zero, size: size),
              items: [TileModel.Item(window: WindowID(1), pid: 1, bundleID: nil, appName: app, miniatureFrame: nil)])
            tile.style = .name
            tile.colourAmount = amount
            let art = TileArt(tile, isDark: mode == .dark, scale: 2, cornerRadius: 17) { _ in colour }
            let caption = try #require(art.caption)
            let picture = try OffscreenPicture(size: size, mode: mode)
            picture.draw { _ in TileDrawing.draw(art, image: { _ in nil }) }
            let ground = picture.colour(4, caption.frame.midY)
            var best = 1.0
            for y in stride(from: caption.frame.minY + 0.25, to: caption.frame.maxY, by: 0.5) {
              for x in stride(from: caption.frame.minX + 0.25, to: caption.frame.maxX, by: 0.5) {
                best = max(best, picture.colour(x, y).contrast(with: ground))
              }
            }
            #expect(best >= 4.5, "\(app) at \(amount) in \(mode) mode: \(best) to 1 on \(ground)")
          }
        }
      }
    }

    /// Every app: its icon, the colour Arbor takes from it, and its tile in light and in dark mode.
    @Test func theColoursOfApplesOwnIcons() throws {
      let found = AppleIcons.paths.keys.sorted().filter { AppleIcons.icon($0) != nil }
      #expect(found.count >= 10, "\(found)")
      let row: CGFloat = 84
      let canvas = try OffscreenPicture(size: CGSize(width: 560, height: row * CGFloat(max(found.count, 1))))
      canvas.draw { _ in
        canvas.fill(RoundedPath.rect(CGRect(x: 0, y: 0, width: 300, height: canvas.size.height), radius: 0), RGBA(white: 0.85))
        canvas.fill(RoundedPath.rect(CGRect(x: 300, y: 0, width: 260, height: canvas.size.height), radius: 0), RGBA(white: 0.2))
        for (index, app) in found.enumerated() {
          let y = CGFloat(index) * row
          guard let image = AppleIcons.icon(app) else { continue }
          let colour = AppAppearance.colour(of: image)
          #expect(colour != nil, "\(app)")
          image.draw(
            in: NSRect(x: 10, y: y + 10, width: 64, height: 64), from: .zero, operation: .sourceOver, fraction: 1,
            respectFlipped: true, hints: nil)
          canvas.fill(RoundedPath.rect(CGRect(x: 84, y: y + 18, width: 48, height: 48), radius: 8), colour ?? .black)
          for isDark in [false, true] {
            var tile = TileModel(
              display: DisplayID("main"), node: NodeID(index), kind: .window,
              frame: CGRect(x: isDark ? 310 : 142, y: y + 6, width: isDark ? 240 : 148, height: 72),
              items: [TileModel.Item(window: WindowID(1), pid: 1, bundleID: nil, appName: app, miniatureFrame: nil)])
            tile.style = isDark ? .name : .icon
            canvas.drawTile(tile, isDark: isDark)
          }
        }
      }
      try canvas.save("icon-colours", item: "F15")
    }
  }
#endif
