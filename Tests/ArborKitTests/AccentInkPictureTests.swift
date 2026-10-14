#if os(macOS)
  import AppKit
  import CoreGraphics
  import Testing

  @testable import ArborKit

  /// What Arbor lays over other apps' windows has to show on whatever those windows hold.
  @Suite @MainActor struct AccentInkPictureTests {
    private let size = CGSize(width: 120, height: 80)

    /// The strongest difference in brightness between the ground and anything on a line across the mark's left edge.
    private func edge(on ground: NSColor, radius: CGFloat, width: CGFloat, name: String) throws -> [Double] {
      var found: [Double] = []
      try OffscreenPicture.each(size: size, item: "accent", name: name) { picture in
        picture.draw { _ in
          ground.setFill()
          NSRect(origin: .zero, size: size).fill()
          AccentInk.mark(NSRect(x: 20, y: 10, width: 80, height: 60), radius: radius, fill: 0.15, width: width)
        }
        let plain = picture.pixel(5, 40).brightness
        found.append(stride(from: 18.25, to: 30, by: 0.25).map { abs(picture.pixel($0, 40).brightness - plain) }.max() ?? 0)
      }
      return found
    }

    /// Seen on a hosted Mac: the rectangle of a ⌃⌥-drag over a window in the accent colour could not be made out.
    @Test(arguments: [(0.0, 1.0, "band"), (17.0, 2.0, "preview")])
    func anEdgeShowsOnContentOfTheAccentColourItself(radius: Double, width: Double, name: String) throws {
      for difference in try edge(on: .controlAccentColor, radius: radius, width: width, name: "\(name)-on-accent") {
        #expect(difference > 0.15, "\(name): \(difference)")
      }
    }

    @Test(arguments: [NSColor.white, .black, NSColor(white: 0.5, alpha: 1)])
    func andOnWhiteBlackAndGrey(ground: NSColor) throws {
      for difference in try edge(on: ground, radius: 17, width: 2, name: "preview-on-\(ground.whiteComponent)") {
        #expect(difference > 0.15, "\(difference)")
      }
    }
  }
#endif
