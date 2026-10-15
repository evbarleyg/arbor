#if os(macOS)
  import AppKit
  import ArborCore
  import CoreGraphics
  import Testing

  @testable import ArborKit

  /// What Arbor's panels stand on (`PanelGround`), drawn by AppKit. Whether the numbers are the right ones is `PanelLookTests`' business.
  @Suite @MainActor struct PanelGroundPictureTests {
    private let size = CGSize(width: 160, height: 90)
    private let panel = NSRect(x: 30, y: 20, width: 100, height: 50)
    private let radius = PanelLook.Corner.panel

    private func colour(_ pixel: OffscreenPicture.Pixel) -> RGBA { RGBA(red: pixel.red, green: pixel.green, blue: pixel.blue) }

    /// Seen on a hosted Mac: the light panel on a light wallpaper had no edge but its shadow.
    @Test func aHairlineTellsThePanelFromAWindowOfItsOwnBrightness() throws {
      try OffscreenPicture.each(size: size, item: "panels", name: "hairline-on-its-own") { picture in
        let white: CGFloat = picture.mode == .dark ? 0.15 : 0.894
        picture.draw { _ in
          NSColor(srgbRed: white, green: white, blue: white, alpha: 1).setFill()
          NSRect(origin: .zero, size: size).fill()
          PanelOutlineView.draw(in: panel, radius: radius, increasesContrast: false)
        }
        let line = picture.pixel(panel.minX + 0.5, panel.midY), around = picture.pixel(panel.minX - 4, panel.midY)
        #expect(abs(line.brightness - around.brightness) > 0.04, "\(picture.mode) at \(picture.scale)x: \(line) on \(around)")
      }
    }

    /// macOS draws its own then, round every window that has a shadow.
    @Test func withIncreaseContrastArborDrawsNoLineOfItsOwn() throws {
      let picture = try OffscreenPicture(size: size)
      picture.draw { _ in PanelOutlineView.draw(in: panel, radius: radius, increasesContrast: true) }
      #expect(picture.count(in: CGRect(origin: .zero, size: size)) { $0.alpha > 0 } == 0)
    }

    @Test func theVeilIsWhatTheTableSaysAndHasThePanelsCorners() throws {
      // What `.hudWindow` was measured to be over a red window, light and dark.
      let grounds: [OffscreenPicture.Mode: RGBA] = [
        .light: RGBA(red: 239 / 255, green: 131 / 255, blue: 136 / 255), .dark: RGBA(red: 163 / 255, green: 44 / 255, blue: 49 / 255),
      ]
      try OffscreenPicture.each(size: size, item: "panels", name: "veil-over-red") { picture in
        let ground = try #require(grounds[picture.mode])
        picture.draw { _ in
          ground.nsColor.setFill()
          NSRect(origin: .zero, size: size).fill()
        }
        let veil = PanelVeilView(frame: NSRect(origin: .zero, size: panel.size))
        picture.draw(veil, at: panel.origin)
        let expected = PanelLook.veil(isDark: picture.mode == .dark).over(ground)
        #expect(
          picture.pixel(panel.midX, panel.midY).isNear(red: expected.red, green: expected.green, blue: expected.blue),
          "\(picture.mode): \(picture.pixel(panel.midX, panel.midY)), not \(expected)")
        #expect(
          picture.pixel(panel.minX + 1, panel.minY + 1).isNear(red: ground.red, green: ground.green, blue: ground.blue),
          "nothing in the corner")
      }
    }

    /// Made once, long before they are drawn with, perhaps in another look.
    @Test func theInksFollowTheLookTheyAreDrawnIn() throws {
      try OffscreenPicture.each(size: size, item: "panels", name: "inks", scales: [1]) { picture in
        let isDark = picture.mode == .dark
        let ground = RGBA(white: isDark ? 0.15 : 0.894)
        picture.draw { _ in
          ground.nsColor.setFill()
          NSRect(origin: .zero, size: size).fill()
          PanelInk.main.setFill()
          NSRect(x: 10, y: 10, width: 40, height: 40).fill()
          PanelInk.second.setFill()
          NSRect(x: 60, y: 10, width: 40, height: 40).fill()
        }
        for (ink, x) in [(PanelLook.Ink.main, CGFloat(30)), (.second, 80)] {
          let expected = PanelLook.ink(ink, isDark: isDark).over(ground)
          #expect(
            picture.pixel(x, 30).isNear(red: expected.red, green: expected.green, blue: expected.blue),
            "\(ink), \(picture.mode): \(picture.pixel(x, 30)), not \(expected)")
        }
      }
    }

    @Test func theVeilLiesUnderWhatThePanelHoldsTheLineOverItAndNeitherTakesAClick() throws {
      let ground = PanelGround()
      ground.frame = NSRect(x: 0, y: 0, width: 100, height: 50)
      let content = NSView(frame: ground.bounds)
      ground.addSubview(content)
      let veil = try #require(ground.subviews.firstIndex { $0 is PanelVeilView })
      let held = try #require(ground.subviews.firstIndex { $0 === content })
      let line = try #require(ground.subviews.firstIndex { $0 is PanelOutlineView })
      #expect(veil < held && held < line)
      #expect(ground.subviews[veil].frame == ground.bounds && ground.subviews[line].frame == ground.bounds)
      #expect(ground.hitTest(NSPoint(x: 0.5, y: 25)) === content)
      #expect(!PanelGround(drawsOutline: false).subviews.contains { $0 is PanelOutlineView })
    }

    @Test func theLineOnScreenIsACapsule() {
      let ground = PanelGround()
      ground.radius = PanelLook.Corner.line(height: 38)
      #expect(ground.radius == 19)
      #expect(ground.subviews.compactMap { ($0 as? PanelVeilView)?.radius } == [19])
      #expect(ground.subviews.compactMap { ($0 as? PanelOutlineView)?.radius } == [19])
      #expect(ground.maskImage?.size == NSSize(width: 39, height: 39))
    }
  }
#endif
