#if os(macOS)
  import AppKit
  import ArborCore
  import CoreGraphics
  import Testing

  @testable import ArborKit

  /// The card a window travels as (`StandIn`), drawn by Core Animation, beside the tile that stands for it at rest, drawn by AppKit.
  @Suite @MainActor struct StandInPictureTests {
    private let size = CGSize(width: 300, height: 200)
    private let safari = RGBA(red: 0.1, green: 0.5, blue: 0.95)

    private func magenta() throws -> CGImage {
      let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      let context = try #require(
        CGContext(
          data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 1, alpha: 1))
      context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
      return try #require(context.makeImage())
    }

    private func isMagenta(_ pixel: OffscreenPicture.Pixel) -> Bool { pixel.isNear(red: 1, green: 0, blue: 1, within: 0.1) }

    @Test func theCardIsTheTile() throws {
      let icon = try magenta()
      try OffscreenPicture.each(size: CGSize(width: size.width * 2 + 60, height: size.height + 40), item: "card", name: "tile-and-card") { picture in
        let isDark = picture.mode == .dark
        var model = TileModel(
          display: DisplayID("main"), node: NodeID(rawValue: 1), kind: .window, frame: CGRect(origin: .zero, size: size),
          items: [TileModel.Item(window: WindowID(101), pid: 1, bundleID: nil, appName: "Safari", miniatureFrame: nil)])
        model.style = .icon
        let art = TileArt(model, isDark: isDark, scale: picture.scale, cornerRadius: ContinuousCorners.windowRadius) { _ in safari }
        picture.draw { context in
          context.translateBy(x: 20, y: 20)
          TileDrawing.draw(art) { _ in NSImage(cgImage: icon, size: NSSize(width: 64, height: 64)) }
        }

        let card = StandIn()
        card.hairline = 1 / picture.scale
        card.wear(Costume(palette: Transition.Cover().palette(appColour: safari, isDark: isDark), icon: icon))
        card.place(CGRect(origin: .zero, size: size))
        card.show(.cover, opacity: 1)
        picture.draw(card.layer, at: CGPoint(x: size.width + 40, y: 20))

        // The same points of both, away from the icon and the edge.
        for point in [CGPoint(x: 40, y: 10), CGPoint(x: 150, y: 30), CGPoint(x: 40, y: 100), CGPoint(x: 260, y: 190)] {
          let tile = picture.pixel(20 + point.x, 20 + point.y), other = picture.pixel(size.width + 40 + point.x, 20 + point.y)
          #expect(
            other.isNear(red: tile.red, green: tile.green, blue: tile.blue, within: 0.03),
            "\(picture.mode) at \(picture.scale)x, \(point): the tile \(tile), the card \(other)")
        }
        // The icon: as large, and in the middle.
        let side = TileMetrics.iconSide(for: size)
        let middle = CGPoint(x: size.width + 40 + size.width / 2, y: 20 + size.height / 2)
        #expect(isMagenta(picture.pixel(middle.x, middle.y)))
        #expect(isMagenta(picture.pixel(middle.x - side / 2 + 2, middle.y)) && isMagenta(picture.pixel(middle.x + side / 2 - 2, middle.y)))
        #expect(!isMagenta(picture.pixel(middle.x - side / 2 - 2, middle.y)) && !isMagenta(picture.pixel(middle.x, middle.y - side / 2 - 2)))
      }
    }

    /// Seen on a hosted Mac: 150 points of icon on a card the size of the display.
    @Test func onALargeCardTheIconStaysATiles() throws {
      let large = CGSize(width: 1000, height: 640)
      let picture = try OffscreenPicture(size: large, scale: 1)
      let card = StandIn()
      card.wear(Costume(palette: Transition.Cover().palette(appColour: safari, isDark: false), icon: try magenta()))
      card.place(CGRect(origin: .zero, size: large))
      card.show(.cover, opacity: 1)
      picture.draw(card.layer)
      try picture.save("large-card", item: "card")
      #expect(picture.count(in: CGRect(x: 0, y: large.height / 2, width: large.width, height: 1), where: isMagenta) == 64)
    }
  }
#endif
