#if os(macOS)
  import AppKit
  import CoreGraphics
  import Foundation
  import QuartzCore
  import Testing

  /// A picture of what Arbor draws, made without a screen: the real AppKit code draws into a bitmap in memory. A test
  /// reads pixels back, and saves the picture for people to look at (docs/TESTING.md, "Pictures without a screen").
  ///
  ///     let picture = try OffscreenPicture(size: CGSize(width: 200, height: 120), scale: 2, mode: .dark)
  ///     picture.draw(view)                               // an NSView with its subviews; it needs no window
  ///     picture.draw(layer, at: CGPoint(x: 20, y: 10))   // a CALayer with its sublayers
  ///     picture.draw { context in … }                    // anything that draws into the current context
  ///     #expect(picture.pixel(100, 3).isNear(red: 1, green: 1, blue: 1))
  ///     try picture.save("tile-dark", item: "F15")       // .build/pictures/F15/tile-dark.png
  ///
  /// Or every mode and scale in one go: `try OffscreenPicture.each(size:item:name:) { picture in … }`.
  ///
  /// It opens no window, reads nothing from the screen and posts no input, so it runs inside an ordinary `swift test` on
  /// anybody's Mac, and nothing of that person's can be in a picture. Keep it so: draw only what the test made itself.
  /// No running apps, their icons or their windows' titles; the icons of Apple's own apps under /System/Applications
  /// (`NSWorkspace.shared.icon(forFile:)`, which launches nothing) are the same on every Mac.
  ///
  /// All coordinates are in points from the picture's top-left corner, y down, like Arbor's global coordinates.
  @MainActor
  final class OffscreenPicture {
    /// Light or dark, said out loud: the Mac's own setting plays no part.
    enum Mode: String, CaseIterable {
      case light, dark

      var appearance: NSAppearance? { NSAppearance(named: self == .dark ? .darkAqua : .aqua) }
    }

    /// A colour in sRGB with straight alpha, every component from 0 to 1.
    struct Pixel: Equatable, CustomStringConvertible {
      var red, green, blue, alpha: Double

      static let clear = Pixel(red: 0, green: 0, blue: 0, alpha: 0)

      func isNear(red: Double, green: Double, blue: Double, alpha: Double = 1, within tolerance: Double = 0.04) -> Bool {
        abs(self.red - red) <= tolerance && abs(self.green - green) <= tolerance && abs(self.blue - blue) <= tolerance
          && abs(self.alpha - alpha) <= tolerance
      }

      /// From 0 (black) to 1 (white), roughly as the eye weighs the three. Alpha is ignored.
      var brightness: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

      var description: String {
        String(format: "(%.2f %.2f %.2f, alpha %.2f)", red, green, blue, alpha)
      }
    }

    let size: CGSize
    let scale: CGFloat
    let mode: Mode
    /// In sRGB, so that colours come back as they went in.
    private let bitmap: CGContext

    /// Clear to begin with. `scale` is pixels per point: 1, or 2 as on a Retina display.
    init(size: CGSize, scale: CGFloat = 2, mode: Mode = .light) throws {
      self.size = size
      self.scale = scale
      self.mode = mode
      let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      bitmap = try #require(
        CGContext(
          data: nil, width: Int((size.width * scale).rounded(.up)), height: Int((size.height * scale).rounded(.up)),
          bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }

    // MARK: Drawing

    /// Runs `body` with the picture as the current graphics context and `mode` as the current appearance. Flipped, y
    /// grows downward from the top-left corner, as in a flipped view; otherwise upward from the bottom-left corner.
    func draw(flipped: Bool = true, _ body: (CGContext) -> Void) {
      bitmap.saveGState()
      bitmap.scaleBy(x: scale, y: scale)
      if flipped {
        bitmap.translateBy(x: 0, y: size.height)
        bitmap.scaleBy(x: 1, y: -1)
      }
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: flipped)
      inMode { body(bitmap) }
      NSGraphicsContext.restoreGraphicsState()
      bitmap.restoreGState()
    }

    /// Runs `body` with `mode` as the current appearance. Layers take plain colours, so whoever gives a layer a colour
    /// that differs between light and dark (`NSColor.labelColor.cgColor`) has to do it in here.
    func inMode(_ body: () -> Void) {
      if let appearance = mode.appearance { appearance.performAsCurrentDrawingAppearance(body) } else { body() }
    }

    /// Draws `view` and its subviews at their size, flipped or not as they are, with the view's top-left corner at
    /// `origin`. The view is told the picture's mode. For a view that hosts layers of its own, draw `view.layer` too.
    func draw(_ view: NSView, at origin: CGPoint = .zero) {
      let bounds = view.bounds
      guard bounds.width >= 1, bounds.height >= 1,
        let rep = NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: Int((bounds.width * scale).rounded(.up)),
          pixelsHigh: Int((bounds.height * scale).rounded(.up)), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
          isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )?.retagging(with: .sRGB)
      else { return }
      // In points, which is what makes AppKit draw `scale` pixels to the point.
      rep.size = bounds.size
      view.appearance = mode.appearance
      view.layoutSubtreeIfNeeded()
      view.cacheDisplay(in: bounds, to: rep)
      guard let image = rep.cgImage else { return }
      draw(flipped: false) { context in
        context.draw(
          image,
          in: CGRect(
            x: origin.x, y: size.height - origin.y - bounds.height, width: bounds.width, height: bounds.height))
      }
    }

    /// Draws `layer` and its sublayers as they are now (no animation plays), with the layer's top-left corner at
    /// `origin`. Core Animation leaves out masks, filters, 3D transforms and what the window server adds (blur behind a
    /// window, window shadows).
    func draw(_ layer: CALayer, at origin: CGPoint = .zero) {
      layer.layoutIfNeeded()
      draw(flipped: false) { context in
        context.translateBy(x: origin.x, y: size.height - origin.y - layer.bounds.height)
        layer.render(in: context)
      }
    }

    // MARK: Looking

    /// The colour at a point. Clear outside the picture.
    func pixel(_ x: CGFloat, _ y: CGFloat) -> Pixel {
      let column = Int(x * scale), row = Int(y * scale)
      guard x >= 0, y >= 0, column < bitmap.width, row < bitmap.height,
        let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self)
      else { return .clear }
      // The first row in memory is the top one. Red, green, blue, alpha, the colours multiplied by alpha.
      let at = row * bitmap.bytesPerRow + column * 4
      let alpha = Double(bytes[at + 3])
      guard alpha > 0 else { return .clear }
      return Pixel(
        red: min(Double(bytes[at]) / alpha, 1), green: min(Double(bytes[at + 1]) / alpha, 1),
        blue: min(Double(bytes[at + 2]) / alpha, 1), alpha: alpha / 255)
    }

    /// How many of the pixels in `rect` satisfy `test`.
    func count(in rect: CGRect, where test: (Pixel) -> Bool) -> Int {
      var found = 0
      let step = 1 / scale
      for y in stride(from: rect.minY + step / 2, to: rect.maxY, by: step) {
        for x in stride(from: rect.minX + step / 2, to: rect.maxX, by: step) where test(pixel(x, y)) { found += 1 }
      }
      return found
    }

    // MARK: Keeping

    /// The checkout's `.build/pictures`. Whoever builds pull requests on a Mac pushes what is in there to the branch
    /// `pictures/<pull request>`.
    static var folder: URL {
      var root = URL(fileURLWithPath: #filePath)
      for _ in 0..<3 { root.deleteLastPathComponent() }
      return root.appendingPathComponent(".build/pictures")
    }

    /// Saves the picture as `.build/pictures/<item>/<name>.png`. Save before the checks: a picture of what went wrong is
    /// worth more than one of what went right.
    @discardableResult
    func save(_ name: String, item: String) throws -> URL {
      let folder = Self.folder.appendingPathComponent(item)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let image = try #require(bitmap.makeImage())
      let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      let file = folder.appendingPathComponent(name + ".png")
      try data.write(to: file)
      return file
    }

    /// One picture per mode and scale: `body` draws (and checks), then the picture is saved as
    /// `<name>-light@1x.png`, `<name>-light@2x.png`, `<name>-dark@1x.png`, `<name>-dark@2x.png`, also if `body` throws.
    static func each(
      size: CGSize, item: String, name: String, scales: [CGFloat] = [1, 2], modes: [Mode] = Mode.allCases,
      _ body: (OffscreenPicture) throws -> Void
    ) throws {
      for mode in modes {
        for scale in scales {
          let picture = try OffscreenPicture(size: size, scale: scale, mode: mode)
          defer { _ = try? picture.save("\(name)-\(mode.rawValue)@\(Int(scale))x", item: item) }
          try body(picture)
        }
      }
    }
  }
#endif
