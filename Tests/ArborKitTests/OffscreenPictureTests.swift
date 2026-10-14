#if os(macOS)
  import AppKit
  import CoreGraphics
  import Foundation
  import QuartzCore
  import Testing

  /// Red in the half where y is small, blue in the other: at the top in a flipped view, at the bottom otherwise.
  private class HalvesView: NSView {
    override func draw(_ dirtyRect: NSRect) {
      NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1).setFill()
      bounds.fill()
      NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
      NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height / 2).fill()
    }
  }

  private final class FlippedHalvesView: HalvesView {
    override var isFlipped: Bool { true }
  }

  /// White in light mode, nearly black in dark mode.
  private final class PaperView: NSView {
    override func draw(_ dirtyRect: NSRect) {
      NSColor.textBackgroundColor.setFill()
      bounds.fill()
    }
  }

  /// The tool other tests look through has to be right itself: which way is up, how large a point is, which mode.
  @Suite @MainActor struct OffscreenPictureTests {
    typealias Pixel = OffscreenPicture.Pixel
    let size = CGSize(width: 40, height: 20)

    func isRed(_ pixel: Pixel) -> Bool { pixel.isNear(red: 1, green: 0, blue: 0) }
    func isBlue(_ pixel: Pixel) -> Bool { pixel.isNear(red: 0, green: 0, blue: 1) }

    @Test func aNewPictureIsClearAndSoIsEverythingOutsideIt() throws {
      let picture = try OffscreenPicture(size: size)
      #expect(picture.pixel(20, 10) == .clear)
      #expect(picture.pixel(-1, 10) == .clear && picture.pixel(20, 20) == .clear && picture.pixel(40, 10) == .clear)
      #expect(picture.count(in: CGRect(origin: .zero, size: size)) { $0.alpha > 0 } == 0)
    }

    @Test func drawingCountsFromTheTopLeftCornerUnlessToldOtherwise() throws {
      let flipped = try OffscreenPicture(size: size)
      flipped.draw { _ in
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 10, height: 5).fill()
      }
      #expect(isRed(flipped.pixel(5, 2)) && flipped.pixel(5, 17) == .clear && flipped.pixel(15, 2) == .clear)

      let upright = try OffscreenPicture(size: size)
      upright.draw(flipped: false) { _ in
        NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 10, height: 5).fill()
      }
      #expect(isRed(upright.pixel(5, 17)) && upright.pixel(5, 2) == .clear)
    }

    @Test(arguments: [CGFloat(1), 2]) func aPointIsAsManyPixelsAsTheScaleSays(scale: CGFloat) throws {
      let picture = try OffscreenPicture(size: size, scale: scale)
      picture.draw { _ in
        NSColor.black.setFill()
        NSRect(x: 10, y: 0, width: 1, height: 20).fill()
      }
      let covered = picture.count(in: CGRect(origin: .zero, size: size)) { $0.alpha == 1 }
      #expect(covered == Int(scale * 20 * scale))
    }

    @Test func translucentColoursComeBackAsTheyWentIn() throws {
      let picture = try OffscreenPicture(size: size)
      picture.draw { _ in
        NSColor(srgbRed: 0.2, green: 0.6, blue: 0.9, alpha: 0.5).setFill()
        NSRect(origin: .zero, size: size).fill()
      }
      #expect(picture.pixel(20, 10).isNear(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.5), "\(picture.pixel(20, 10))")
    }

    @Test(arguments: [CGFloat(1), 2]) func viewsAreDrawnTheWayUpTheyAre(scale: CGFloat) throws {
      let upright = try OffscreenPicture(size: size, scale: scale)
      upright.draw(HalvesView(frame: NSRect(origin: .zero, size: size)))
      try upright.save("test-view-upright@\(Int(scale))x", item: "offscreen")
      #expect(isBlue(upright.pixel(20, 4)) && isRed(upright.pixel(20, 16)), "y grows upward in a plain view")

      let flipped = try OffscreenPicture(size: size, scale: scale)
      flipped.draw(FlippedHalvesView(frame: NSRect(origin: .zero, size: size)))
      try flipped.save("test-view-flipped@\(Int(scale))x", item: "offscreen")
      #expect(isRed(flipped.pixel(20, 4)) && isBlue(flipped.pixel(20, 16)), "and downward in a flipped one")
    }

    @Test func aViewGoesWhereItIsPutWithItsSubviews() throws {
      let parent = FlippedHalvesView(frame: NSRect(x: 0, y: 0, width: 20, height: 10))
      // In a flipped parent: two points from its left and one from its top.
      parent.addSubview(PaperView(frame: NSRect(x: 2, y: 1, width: 4, height: 3)))
      let picture = try OffscreenPicture(size: size)
      picture.draw(parent, at: CGPoint(x: 10, y: 6))
      try picture.save("test-view-placed", item: "offscreen")
      #expect(picture.pixel(9, 8) == .clear && picture.pixel(31, 8) == .clear)
      #expect(picture.pixel(20, 5) == .clear && picture.pixel(20, 17) == .clear)
      #expect(isRed(picture.pixel(25, 8)) && isBlue(picture.pixel(25, 14)))
      #expect(picture.pixel(14, 8.5).brightness > 0.9, "the subview, white in light mode")
    }

    @Test func theModeIsThePicturesNotTheMacs() throws {
      for mode in OffscreenPicture.Mode.allCases {
        let picture = try OffscreenPicture(size: size, mode: mode)
        picture.draw(PaperView(frame: NSRect(origin: .zero, size: size)))
        let view = picture.pixel(20, 10).brightness
        #expect(mode == .light ? view > 0.9 : view < 0.3, "a view in \(mode) mode: \(view)")

        let drawn = try OffscreenPicture(size: size, mode: mode)
        drawn.draw { _ in
          NSColor.textBackgroundColor.setFill()
          NSRect(origin: .zero, size: size).fill()
        }
        let plain = drawn.pixel(20, 10).brightness
        #expect(mode == .light ? plain > 0.9 : plain < 0.3, "plain drawing in \(mode) mode: \(plain)")

        let layered = try OffscreenPicture(size: size, mode: mode)
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layered.inMode { layer.backgroundColor = NSColor.textBackgroundColor.cgColor }
        layered.draw(layer)
        let made = layered.pixel(20, 10).brightness
        #expect(mode == .light ? made > 0.9 : made < 0.3, "a layer coloured in \(mode) mode: \(made)")
      }
    }

    @Test func layersAreDrawnWithTheirSublayersCountingFromTheBottom() throws {
      let parent = CALayer()
      parent.frame = CGRect(x: 0, y: 0, width: 20, height: 10)
      parent.backgroundColor = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
      let child = CAShapeLayer()
      child.frame = parent.bounds
      child.path = CGPath(rect: CGRect(x: 0, y: 0, width: 20, height: 5), transform: nil)
      child.fillColor = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
      parent.addSublayer(child)
      let picture = try OffscreenPicture(size: size)
      picture.draw(parent, at: CGPoint(x: 10, y: 6))
      try picture.save("test-layers", item: "offscreen")
      #expect(isBlue(picture.pixel(20, 8)) && isRed(picture.pixel(20, 14)), "a layer's y grows upward")
      #expect(picture.pixel(9, 10) == .clear && picture.pixel(20, 5) == .clear && picture.pixel(20, 17) == .clear)
    }

    @Test func picturesAreSavedWhereTheBuilderLooksForThem() throws {
      let picture = try OffscreenPicture(size: size, scale: 2)
      picture.draw(FlippedHalvesView(frame: NSRect(origin: .zero, size: size)))
      let file = try picture.save("test-saved", item: "offscreen")
      #expect(file.path.hasSuffix("/.build/pictures/offscreen/test-saved.png"))
      let data = try Data(contentsOf: file)
      let saved = try #require(NSBitmapImageRep(data: data))
      #expect(saved.pixelsWide == 80 && saved.pixelsHigh == 40)
    }

    @Test func eachMakesOnePictureForEveryModeAndScale() throws {
      var seen: [String] = []
      try OffscreenPicture.each(size: size, item: "offscreen", name: "test-each") { picture in
        seen.append("\(picture.mode.rawValue) \(Int(picture.scale))")
        picture.draw(PaperView(frame: NSRect(origin: .zero, size: size)))
      }
      #expect(seen == ["light 1", "light 2", "dark 1", "dark 2"])
      for name in ["light@1x", "light@2x", "dark@1x", "dark@2x"] {
        let file = OffscreenPicture.folder.appendingPathComponent("offscreen/test-each-\(name).png")
        #expect(FileManager.default.fileExists(atPath: file.path), "\(name)")
      }
    }
  }
#endif
