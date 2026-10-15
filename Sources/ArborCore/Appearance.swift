import CoreGraphics

/// What a tile shows on its colour.
public enum TileStyle: String, Equatable, Sendable, CaseIterable {
  /// The app's icon and nothing else, as in TrellisWM.
  case icon
  /// The icon with a caption: the space's name, the window's title or the app's name.
  case name
  /// Nothing: the colour alone.
  case plain
}

/// What the gaps between docked windows are to the pointer.
public enum GapHandles: String, Equatable, Sendable, CaseIterable {
  /// Dragging a gap resizes the windows on both sides, and a handle shows in it under the pointer.
  case shown
  /// Dragging works the same, but nothing is drawn.
  case hidden
  /// Gaps are only gaps. The `resize` command and a window's own edges still resize.
  case off
}

/// The appearance settings, made safe to draw with: amounts are within their ranges and the style is one
/// Arbor knows. What is read from settings.json has been through `SettingsSchema.sanitize`, which also reports what it
/// changed; this holds for a `Settings` from anywhere.
public struct AppearanceOptions: Equatable, Sendable {
  /// Opacity of the black laid over the wallpaper behind docked windows, 0...1.
  public var dim: Double
  /// How much of macOS's blur is laid over the wallpaper in the same area, 0...1.
  public var blur: Double
  public var usesAppColours: Bool
  /// How much of an app's colour goes into its tiles, 0...1.
  public var appColourAmount: Double
  public var gapHandles: GapHandles
  public var tileStyle: TileStyle
  /// Opacity of the accent colour laid over the wallpaper in the same area as `dim`, 0...1.
  public var tint: Double
  /// Opacity of the hairline around the Desktop, 0...1.
  public var desktopEdge: Double
  /// Seconds a tile takes to fade in and out, 0...1.
  public var tileFade: Double

  public init(
    dim: Double, blur: Double, usesAppColours: Bool, appColourAmount: Double, gapHandles: GapHandles,
    tileStyle: TileStyle, tint: Double = 0, desktopEdge: Double = 0.05, tileFade: Double = 0.2
  ) {
    self.dim = dim
    self.blur = blur
    self.usesAppColours = usesAppColours
    self.appColourAmount = appColourAmount
    self.gapHandles = gapHandles
    self.tileStyle = tileStyle
    self.tint = tint
    self.desktopEdge = desktopEdge
    self.tileFade = tileFade
  }
}

extension Settings {
  private static let amounts = 0.0...1.0

  public var appearanceOptions: AppearanceOptions {
    let defaults = Settings()
    /// Too much or too little means the most or the least; not a number at all means nothing, so the default.
    func sane(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
      value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
    return AppearanceOptions(
      dim: sane(dimBehindArranged, Self.amounts, defaults.dimBehindArranged),
      blur: sane(blurBehindArranged, Self.amounts, defaults.blurBehindArranged),
      usesAppColours: appColours,
      appColourAmount: sane(appColourAmount, Self.amounts, defaults.appColourAmount),
      gapHandles: GapHandles(rawValue: gapHandles) ?? GapHandles(rawValue: defaults.gapHandles) ?? .shown,
      tileStyle: TileStyle(rawValue: tileStyle) ?? TileStyle(rawValue: defaults.tileStyle) ?? .icon,
      tint: sane(tintBehindArranged, Self.amounts, defaults.tintBehindArranged),
      desktopEdge: sane(desktopEdge, Self.amounts, defaults.desktopEdge),
      tileFade: sane(tileFade, Self.amounts, defaults.tileFade))
  }
}

/// The sizes Arbor's tiles, drop preview and backdrop share, so that they look like one family.
public enum TileMetrics {
  /// Corner radius of tiles and of the drop preview: that of the windows they stand in for, since a sharper or
  /// rounder corner looks out of place beside real ones. This is macOS 26's, measured on screenshots for the
  /// focus ring; the UI passes the radius of the macOS it runs on.
  public static let cornerRadius: CGFloat = 17

  /// The side of a tile's icon: 45% of the tile's short side, at most 64 points, in whole points.
  public static func iconSide(for size: CGSize) -> CGFloat {
    let short = min(size.width, size.height)
    guard short.isFinite, short > 0 else { return 0 }
    return min(64, (short * 0.45).rounded(.down))
  }

  /// Space between the windows in a group tile's miniature.
  public static let miniatureGap: CGFloat = 3

  /// Space around a group tile's miniature, the same on all four sides: 8 points, less on a small tile.
  public static func miniatureInset(for size: CGSize) -> CGFloat {
    let short = min(size.width, size.height)
    guard short.isFinite, short > 0 else { return 0 }
    return min(8, max(3, (short * 0.08).rounded()))
  }
}

/// The colours of one tile.
public struct TilePalette: Equatable, Sendable {
  /// The fill runs from `top` to `bottom`: a little lighter above, as if lit from there.
  public var top: RGBA
  public var bottom: RGBA
  /// A hairline just inside the edge, which separates the tile from whatever is behind it.
  public var border: RGBA
  /// Text and glyphs.
  public var ink: RGBA
  /// A soft shadow under text, where the background is not Arbor's to choose.
  public var inkShadow: RGBA?

  /// The greys macOS uses for grouped content in light and dark mode.
  static func neutral(isDark: Bool) -> RGBA {
    isDark ? RGBA(red: 0.173, green: 0.173, blue: 0.180) : RGBA(red: 0.949, green: 0.949, blue: 0.969)
  }

  /// The least contrast between the ink and any part of the fill. WCAG asks 4.5 to 1 of small text; a little more, because
  /// the thin strokes of small text are drawn paler than their colour.
  public static let legibleContrast = 5.0

  init(base: RGBA) {
    var base = base
    let ink = base.ink
    func shades(of base: RGBA) -> (top: RGBA, bottom: RGBA) {
      (base.mixed(with: .white, amount: 0.06), base.mixed(with: .black, amount: 0.06))
    }
    // On a colour of middling lightness (a full red, a strong blue) the better ink only just reaches 4.5 to 1, and on the
    // half of the fill that is shaded towards it, it does not. Such a fill moves away from its ink until the ink can be read.
    // It ends: the last step is white under black ink, or black under white.
    var (top, bottom) = shades(of: base)
    while min(ink.contrast(with: top), ink.contrast(with: bottom)) < Self.legibleContrast {
      base = base.mixed(with: ink == .black ? .white : .black, amount: 0.04)
      (top, bottom) = shades(of: base)
    }
    self.top = top
    self.bottom = bottom
    self.ink = ink
    border = ink.withAlpha(ink == .white ? 0.16 : 0.12)
    inkShadow = nil
  }

  /// A window's tile: the neutral grey of the current mode with `amount` of the app's colour mixed in.
  /// Without a colour (app colours are off, or the app has no icon) it is the plain grey.
  public init(appColour: RGBA?, amount: Double, isDark: Bool) {
    let neutral = Self.neutral(isDark: isDark)
    self.init(base: appColour.map { neutral.mixed(with: $0.withAlpha(1), amount: amount) } ?? neutral)
  }

  /// A group's tile: a tray a shade darker than the miniature windows lying in it.
  public static func tray(isDark: Bool) -> TilePalette {
    TilePalette(base: neutral(isDark: isDark).mixed(with: .black, amount: isDark ? 0.4 : 0.1))
  }

  /// The Desktop's tile is smoked glass: the wallpaper itself shows through, which says "Desktop" better than
  /// any colour. What is behind it has nothing to do with light or dark mode, so like the labels
  /// of icons on the Desktop its text is white with a shadow in both.
  public static let desktop: TilePalette = {
    var palette = TilePalette(base: .black)
    palette.top = RGBA.black.withAlpha(0.20)
    palette.bottom = RGBA.black.withAlpha(0.32)
    palette.border = RGBA.white.withAlpha(0.22)
    palette.inkShadow = RGBA.black.withAlpha(0.55)
    return palette
  }()
}

/// The handle shown in the gap between two docked windows while the pointer is over it.
public enum SeamHandle {
  public static let thickness: CGFloat = 4
  public static let length: CGFloat = 36

  /// A pill in the middle of `seam`, lying along it, or nil if the seam is too small for one. `axis` is
  /// the split's: the seam of a horizontal split is an upright strip.
  public static func pill(in seam: CGRect, axis: Axis) -> CGRect? {
    guard RoundedPath.isDrawable(seam) else { return nil }
    let across = min(thickness, seam.length(along: axis))
    let along = min(length, seam.length(along: axis.perpendicular) - 16)
    guard across >= 2, along >= across * 3 else { return nil }
    let size = axis == .horizontal ? CGSize(width: across, height: along) : CGSize(width: along, height: across)
    return CGRect(x: seam.midX - size.width / 2, y: seam.midY - size.height / 2, width: size.width, height: size.height)
  }
}
