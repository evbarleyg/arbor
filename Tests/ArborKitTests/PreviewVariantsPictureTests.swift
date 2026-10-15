#if os(macOS)
  import AppKit
  import ArborCore
  import CoreGraphics
  import Testing

  @testable import ArborKit

  /// A sheet to decide by, not a test: the drop preview as it is and as it might be, side by side at two pixels to the point, in both
  /// looks, over a pale window, a busy one and one in the accent colour. `.build/pictures/preview/`.
  @Suite @MainActor struct PreviewVariantsPictureTests {
    private let cell = CGSize(width: 340, height: 300)
    private let accent = NSColor(srgbRed: 0, green: 0.48, blue: 1, alpha: 1)

    private enum Content: String, CaseIterable { case pale, busy, accent }

    private func window(_ frame: NSRect, _ content: Content, isDark: Bool, isInHand: Bool = false) {
      let shape = NSBezierPath.make(RoundedPath.rect(frame, radius: 17))
      NSGraphicsContext.saveGraphicsState()
      if isInHand {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -8)
        shadow.set()
      }
      (isDark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.97, alpha: 1)).setFill()
      shape.fill()
      NSGraphicsContext.restoreGraphicsState()
      NSGraphicsContext.saveGraphicsState()
      shape.addClip()
      let body = NSRect(x: frame.minX, y: frame.minY + 32, width: frame.width, height: frame.height - 32)
      switch content {
      case .pale: break
      case .accent:
        accent.setFill()
        body.fill()
      case .busy:
        // Lines of text, a picture, a sidebar: about what a page holds.
        (isDark ? NSColor(white: 0.22, alpha: 1) : NSColor(white: 0.9, alpha: 1)).setFill()
        NSRect(x: body.minX, y: body.minY, width: 70, height: body.height).fill()
        for (index, y) in stride(from: body.minY + 12, to: body.maxY - 8, by: 11).enumerated() {
          (isDark ? NSColor(white: 0.75, alpha: 1) : NSColor(white: 0.25, alpha: 1)).setFill()
          NSRect(x: body.minX + 82, y: y, width: CGFloat(60 + (index * 53) % 130), height: 4).fill()
        }
        for (index, hue) in [0.02, 0.13, 0.33, 0.58, 0.8].enumerated() {
          NSColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
          NSRect(x: body.minX + 8, y: body.minY + 10 + CGFloat(index) * 34, width: 54, height: 26).fill()
        }
      }
      for (index, colour) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        (isInHand ? colour : NSColor(white: 0.6, alpha: 0.6)).setFill()
        NSBezierPath(ovalIn: NSRect(x: frame.minX + 12 + CGFloat(index) * 20, y: frame.minY + 10, width: 12, height: 12)).fill()
      }
      NSGraphicsContext.restoreGraphicsState()
    }

    private func label(_ text: String, at point: NSPoint, isDark: Bool) {
      (text as NSString).draw(
        at: point,
        withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white])
    }

    @Test func sideBySide() throws {
      let variants = ["as it is: over the window", "under it, the window's corners", "under it, 3 points out, radius 20", "the system's: white, under it"]
      let size = CGSize(width: cell.width * CGFloat(variants.count), height: cell.height)
      for content in Content.allCases {
        try OffscreenPicture.each(size: size, item: "preview", name: "over-\(content.rawValue)", scales: [2]) { picture in
          let isDark = picture.mode == .dark
          picture.draw { _ in
            NSGradient(
              starting: isDark ? NSColor(srgbRed: 0.05, green: 0.06, blue: 0.19, alpha: 1) : NSColor(srgbRed: 0.25, green: 0.56, blue: 0.84, alpha: 1),
              ending: isDark ? NSColor(srgbRed: 0.12, green: 0.13, blue: 0.29, alpha: 1) : NSColor(srgbRed: 0.24, green: 0.56, blue: 0.41, alpha: 1)
            )?.draw(in: NSRect(origin: .zero, size: size), angle: 90)
            for (index, name) in variants.enumerated() {
              let origin = CGFloat(index) * cell.width
              let docked = NSRect(x: origin + 14, y: 26, width: cell.width - 28, height: cell.height - 40)
              let place = NSRect(x: docked.minX, y: docked.midY + 6, width: docked.width, height: docked.height / 2 - 6)
              let hand = NSRect(x: docked.minX + 60, y: place.minY + 44, width: 200, height: 130)
              window(docked, content, isDark: isDark)
              switch index {
              case 0:
                window(hand, .pale, isDark: isDark, isInHand: true)
                AccentInk.mark(place, radius: 17, fill: 0.18, width: 2, accent: accent)
              case 1:
                AccentInk.mark(place, radius: 17, fill: 0.18, width: 2, accent: accent)
                window(hand, .pale, isDark: isDark, isInHand: true)
              case 2:
                AccentInk.mark(place.insetBy(dx: -3, dy: -3), radius: 20, fill: 0.18, width: 2, accent: accent)
                window(hand, .pale, isDark: isDark, isInHand: true)
              default:
                let outer = place.insetBy(dx: -3, dy: -3)
                NSColor.white.withAlphaComponent(0.12).setFill()
                NSBezierPath.make(RoundedPath.rect(outer, radius: 20)).fill()
                let line = NSBezierPath.make(RoundedPath.rect(outer.insetBy(dx: 1, dy: 1), radius: 19))
                line.lineWidth = 2
                NSColor.white.withAlphaComponent(0.9).setStroke()
                line.stroke()
                window(hand, .pale, isDark: isDark, isInHand: true)
              }
              label(name, at: NSPoint(x: origin + 16, y: 7), isDark: isDark)
            }
          }
        }
      }
    }
  }
#endif
