#if os(macOS)
  import AppKit
  import ArborCore
  import ArborTesting
  import CoreGraphics
  import Foundation

  @testable import ArborKit

  /// The icons of Apple's own apps, which are the same on every Mac. Asking for one launches nothing. Every path is under
  /// /System: never a running app's icon, never anything under /Applications or the home folder.
  @MainActor
  enum AppleIcons {
    static let paths: [String: String] = [
      "Safari": "/System/Cryptexes/App/System/Applications/Safari.app", "Notes": "/System/Applications/Notes.app",
      "Mail": "/System/Applications/Mail.app", "Music": "/System/Applications/Music.app",
      "Terminal": "/System/Applications/Utilities/Terminal.app", "Calendar": "/System/Applications/Calendar.app",
      "Messages": "/System/Applications/Messages.app", "Photos": "/System/Applications/Photos.app",
      "Finder": "/System/Library/CoreServices/Finder.app", "Maps": "/System/Applications/Maps.app",
      "Reminders": "/System/Applications/Reminders.app", "TextEdit": "/System/Applications/TextEdit.app",
      "Preview": "/System/Applications/Preview.app", "Calculator": "/System/Applications/Calculator.app",
      "Podcasts": "/System/Applications/Podcasts.app", "TV": "/System/Applications/TV.app",
      "Stocks": "/System/Applications/Stocks.app", "Weather": "/System/Applications/Weather.app",
      "FaceTime": "/System/Applications/FaceTime.app", "Freeform": "/System/Applications/Freeform.app",
      "App Store": "/System/Applications/App Store.app", "System Settings": "/System/Applications/System Settings.app",
      "Books": "/System/Applications/Books.app", "Shortcuts": "/System/Applications/Shortcuts.app",
    ]

    /// Nil for an app that is not Apple's or not on this Mac.
    static func icon(_ app: String) -> NSImage? {
      guard let path = paths[app], FileManager.default.fileExists(atPath: path) else { return nil }
      return NSWorkspace.shared.icon(forFile: path)
    }
  }

  extension RGBA {
    init(_ pixel: OffscreenPicture.Pixel) {
      self.init(red: pixel.red, green: pixel.green, blue: pixel.blue, alpha: pixel.alpha)
    }
  }

  /// A whole display at rest, as a picture: an `OverlayScene` from the real controller, drawn by the real drawing code. Open
  /// windows in a `Harness` under the names of Apple's apps (`h.system.open(app: "Notes", pid: 12)`, a process each) and
  /// tiles get real icons and the colours Arbor takes from them. Stand-ins for what belongs to macOS: the wallpaper, the
  /// windows and their shadows. An overlay that is not drawn here yet is a few lines in `draw(_:windows:)`.
  extension OffscreenPicture {
    /// The colour at a point as Arbor's own colour type.
    func colour(_ x: CGFloat, _ y: CGFloat) -> RGBA { RGBA(pixel(x, y)) }

    /// What `h`'s main display shows now. The picture should have the display's size.
    func draw(display h: Harness) {
      let windows = (h.layout?.windowFrames ?? [:]).keys.sorted().compactMap { h.frame($0) }
      draw(h.overlays.scenes[h.display] ?? OverlayScene(), windows: windows)
    }

    /// Back to front: wallpaper, backdrop, `windows` (frames in global coordinates), tiles.
    func draw(_ scene: OverlayScene, windows: [CGRect]) {
      let isDark = mode == .dark
      draw { _ in
        let sky =
          isDark
          ? [NSColor(srgbRed: 0.06, green: 0.13, blue: 0.15, alpha: 1), NSColor(srgbRed: 0.35, green: 0.22, blue: 0.5, alpha: 1)]
          : [NSColor(srgbRed: 0.97, green: 0.7, blue: 0.4, alpha: 1), NSColor(srgbRed: 0.37, green: 0.3, blue: 0.71, alpha: 1)]
        NSGradient(starting: sky[0], ending: sky[1])?.draw(in: NSRect(origin: .zero, size: size), angle: 60)
        if let backdrop = scene.backdrop {
          // A fixed accent, so that the picture is the same on every Mac.
          fill(
            backdrop.outline(slotRadius: ContinuousCorners.windowRadius),
            backdrop.fill(accent: RGBA(red: 0.04, green: 0.52, blue: 1)))
          if let edge = backdrop.desktopOutline(width: 1 / scale, radius: ContinuousCorners.windowRadius) {
            let line = NSBezierPath.make(edge)
            line.lineWidth = 1 / scale
            NSColor.white.withAlphaComponent(CGFloat(backdrop.desktopEdge)).setStroke()
            line.stroke()
          }
        }
        for frame in windows {
          shadowed {
            fill(RoundedPath.rect(frame, radius: ContinuousCorners.windowRadius), RGBA(white: isDark ? 0.12 : 0.98))
          }
        }
        for tile in scene.tiles { drawTile(tile, isDark: isDark) }
      }
    }

    /// Inside `draw { … }`: one tile at its frame, with the shadow the window server would give it.
    func drawTile(_ tile: TileModel, isDark: Bool) {
      let art = TileArt(tile, isDark: isDark, scale: scale, cornerRadius: ContinuousCorners.windowRadius) { item in
        AppleIcons.icon(item.appName).flatMap { AppAppearance.colour(of: $0) }
      }
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current?.cgContext.translateBy(x: tile.frame.minX, y: tile.frame.minY)
      if art.castsShadow { shadowed { fill(art.plate.outline, art.plate.top) } }
      TileDrawing.draw(art, image: { pid in tile.items.first { $0.pid == pid }.flatMap { AppleIcons.icon($0.appName) } })
      NSGraphicsContext.restoreGraphicsState()
    }

    /// Inside `draw { … }`.
    func fill(_ outline: [PathElement], _ colour: RGBA) {
      colour.nsColor.setFill()
      NSBezierPath.make(outline).fill()
    }

    /// Inside `draw { … }`: what `body` draws casts something like a window's shadow.
    func shadowed(_ body: () -> Void) {
      NSGraphicsContext.saveGraphicsState()
      let shadow = NSShadow()
      shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
      shadow.shadowBlurRadius = 20
      shadow.shadowOffset = NSSize(width: 0, height: -8)
      shadow.set()
      body()
      NSGraphicsContext.restoreGraphicsState()
    }
  }
#endif
