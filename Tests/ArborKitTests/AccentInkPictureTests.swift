#if os(macOS)
  import AppKit
  import CoreGraphics
  import Testing

  @testable import ArborKit

  /// What Arbor lays over other apps' windows has to show on whatever those windows hold.
  @Suite @MainActor struct AccentInkPictureTests {
    private let size = CGSize(width: 120, height: 80)

    /// About the accent colours System Settings offers, said out loud: the Mac's own choice plays no part.
    private static let accents: [(name: String, red: Double, green: Double, blue: Double)] = [
      ("blue", 0, 0.48, 1), ("purple", 0.65, 0.31, 0.65), ("pink", 0.97, 0.31, 0.62), ("red", 0.88, 0.22, 0.24),
      ("orange", 0.97, 0.51, 0.11), ("yellow", 1, 0.78, 0.15), ("green", 0.38, 0.73, 0.28), ("graphite", 0.55, 0.55, 0.55),
    ]

    /// The strongest difference in brightness between the ground and anything on a line across the mark's left edge, in
    /// each look and at each scale.
    private func edge(of accent: NSColor, on ground: NSColor, radius: CGFloat, width: CGFloat, name: String) throws -> [Double] {
      var found: [Double] = []
      try OffscreenPicture.each(size: size, item: "accent", name: name) { picture in
        picture.draw { _ in
          ground.setFill()
          NSRect(origin: .zero, size: size).fill()
          AccentInk.mark(NSRect(x: 20, y: 10, width: 80, height: 60), radius: radius, fill: 0.15, width: width, accent: accent)
        }
        let plain = picture.pixel(5, 40).brightness
        found.append(stride(from: 18.25, to: 30, by: 0.25).map { abs(picture.pixel($0, 40).brightness - plain) }.max() ?? 0)
      }
      return found
    }

    /// Seen on a hosted Mac: the rectangle of a ⌃⌥-drag over a window in the accent colour could not be made out.
    @Test func anEdgeShowsOnContentOfTheAccentColourItself() throws {
      for accent in Self.accents {
        let colour = NSColor(srgbRed: accent.red, green: accent.green, blue: accent.blue, alpha: 1)
        for (radius, width, what) in [(CGFloat(0), CGFloat(1), "band"), (17, 2, "preview"), (22, 4, "peek")] {
          for difference in try edge(of: colour, on: colour, radius: radius, width: width, name: "\(what)-on-\(accent.name)") {
            #expect(difference > 0.15, "\(what), \(accent.name): \(difference)")
          }
        }
      }
    }

    @Test func andOnWhiteBlackAndGrey() throws {
      for accent in Self.accents {
        let colour = NSColor(srgbRed: accent.red, green: accent.green, blue: accent.blue, alpha: 1)
        for white in [0.0, 0.5, 1.0] {
          let ground = NSColor(srgbRed: white, green: white, blue: white, alpha: 1)
          for difference in try edge(of: colour, on: ground, radius: 17, width: 2, name: "\(accent.name)-on-\(white)") {
            #expect(difference > 0.15, "\(accent.name) on \(white): \(difference)")
          }
        }
      }
    }

    /// The rectangle of a drag begins a point high and a point wide.
    @Test func aMarkTooSmallForItsLinesIsDrawnAsFarAsItGoes() throws {
      let picture = try OffscreenPicture(size: size)
      picture.draw { _ in
        for side: CGFloat in [0, 0.5, 1, 2, 3] {
          AccentInk.mark(NSRect(x: 10, y: 10 + side * 10, width: 60, height: side), radius: 0, fill: 0.15, width: 1)
          AccentInk.mark(NSRect(x: 80, y: 10 + side * 10, width: side, height: side), radius: 17, fill: 0.15, width: 2)
        }
      }
      #expect(picture.pixel(40, 30.5).alpha > 0, "two points high")
    }
  }
#endif
