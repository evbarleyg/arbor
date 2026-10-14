import ArborCore
import CoreGraphics

/// Everything there is to decide about how a tile looks: shapes, colours, and where the icon, the caption,
/// the miniature and the badge go. The UI draws the parts in the order they are declared and decides
/// nothing (`UI/TileDrawing.swift`), so the look is covered by tests that run without a screen.
///
/// Coordinates are the tile's own: origin at its top-left corner, y down, in points.
public struct TileArt: Equatable, Sendable {
  /// A filled shape with a hairline just inside its edge.
  public struct Plate: Equatable, Sendable {
    public var frame: CGRect
    public var outline: [PathElement]
    public var top: RGBA
    public var bottom: RGBA
    /// The middle of the hairline, half its width inside `outline`.
    public var borderOutline: [PathElement]
    public var border: RGBA
    public var borderWidth: CGFloat
  }

  /// A running app's icon.
  public struct Icon: Equatable, Sendable {
    public var pid: Int32
    public var frame: CGRect
  }

  /// An SF Symbol, fitted into `frame` and centred there.
  public struct Glyph: Equatable, Sendable {
    public var symbol: String
    public var frame: CGRect
    public var colour: RGBA
    public var shadow: RGBA?
  }

  /// One line of text in the system font. Text too long for `frame` ends in an ellipsis.
  public struct Label: Equatable, Sendable {
    public enum Alignment: Equatable, Sendable { case left, centre }

    public var text: String
    public var frame: CGRect
    public var size: CGFloat
    /// Semibold rather than medium.
    public var isStrong: Bool
    public var alignment: Alignment
    public var colour: RGBA
    public var shadow: RGBA?
  }

  public struct Badge: Equatable, Sendable {
    public var frame: CGRect
    public var outline: [PathElement]
    public var fill: RGBA
    public var label: Label
  }

  public var plate: Plate
  /// A group's windows in miniature.
  public var cells: [Plate] = []
  public var icons: [Icon] = []
  public var glyph: Glyph?
  public var caption: Label?
  /// How many windows a group holds.
  public var badge: Badge?
  /// Tiles stand in for windows, so they cast a window's shadow. Glass does not.
  public var castsShadow = true

  /// - Parameters:
  ///   - isDark: whether macOS is in dark mode.
  ///   - scale: pixels per point of the display, for the width of hairlines.
  ///   - cornerRadius: the radius of a window's corners on this macOS.
  ///   - appColour: the colour of an item's app (`IconColour`), nil if it has none. Asked only when
  ///     the tile uses app colours.
  public init(
    _ model: TileModel, isDark: Bool, scale: CGFloat = 2, cornerRadius: CGFloat = TileMetrics.cornerRadius,
    appColour: (TileModel.Item) -> RGBA?
  ) {
    let bounds = CGRect(origin: .zero, size: model.frame.size)
    let hairline = 1 / max(scale.isFinite ? scale : 1, 1)
    // A name is the person's own word for the space (F20): it shows whatever the style.
    let text = model.name ?? (model.style == .name ? model.title : nil)
    let isPlain = model.style == .plain
    func palette(for item: TileModel.Item?) -> TilePalette {
      let colour = model.usesAppColour ? item.flatMap(appColour) : nil
      return TilePalette(appColour: colour, amount: model.colourAmount, isDark: isDark)
    }

    switch model.kind {
    case .window:
      let colours = palette(for: model.items.first)
      plate = Self.plate(bounds, radius: cornerRadius, colours, hairline)
      let side = model.items.isEmpty || isPlain ? 0 : TileMetrics.iconSide(for: bounds.size)
      // An app icon's artwork stops short of the image's edge, so little space is needed below it.
      let parts = Self.arrange(in: bounds.size, emblem: side, spacing: 3, text: text)
      if let frame = parts.emblem, let item = model.items.first { icons = [Icon(pid: item.pid, frame: frame)] }
      caption = parts.label.map { Self.caption(model.title, $0, colours) }

    case .group:
      plate = Self.plate(bounds, radius: cornerRadius, .tray(isDark: isDark), hairline)
      badge = Self.badge(name: model.name, count: model.items.count, in: bounds.size, isDark: isDark)
      let inset = TileMetrics.miniatureInset(for: bounds.size)
      for item in model.items {
        guard let global = item.miniatureFrame else { continue }
        let frame = global.offsetBy(dx: -model.frame.minX, dy: -model.frame.minY)
        guard frame.width >= 1, frame.height >= 1 else { continue }
        // Concentric with the tile's own corners.
        cells.append(Self.plate(frame, radius: max(cornerRadius - inset, 2), palette(for: item), hairline))
        let side = min(48, TileMetrics.iconSide(for: frame.size))
        let icon = CGRect(
          x: (frame.midX - side / 2).rounded(), y: (frame.midY - side / 2).rounded(), width: side, height: side)
        if !isPlain, side >= 10, badge.map({ !$0.frame.overlaps(icon) }) ?? true {
          icons.append(Icon(pid: item.pid, frame: icon))
        }
      }

    case .desktop:
      let colours = TilePalette.desktop
      plate = Self.plate(bounds, radius: cornerRadius, colours, hairline)
      castsShadow = false
      let side = isPlain ? 0 : min(28, TileMetrics.iconSide(for: bounds.size))
      let parts = Self.arrange(in: bounds.size, emblem: side, spacing: 5, text: text)
      glyph = parts.emblem.map {
        Glyph(symbol: "menubar.dock.rectangle", frame: $0, colour: colours.ink, shadow: colours.inkShadow)
      }
      caption = parts.label.map { Self.caption(model.title, $0, colours) }
    }
  }

  // MARK: Parts

  private static let captionSize: CGFloat = 11
  private static let captionHeight: CGFloat = 14
  /// Space kept clear on both sides of a caption.
  private static let margin: CGFloat = 8
  /// Below this nothing readable is left of a caption, ellipsis included.
  private static let narrowestCaption: CGFloat = 28
  private static let smallestEmblem: CGFloat = 12

  private static func plate(_ frame: CGRect, radius: CGFloat, _ colours: TilePalette, _ hairline: CGFloat) -> Plate {
    Plate(
      frame: frame, outline: RoundedPath.rect(frame, radius: radius), top: colours.top, bottom: colours.bottom,
      borderOutline: RoundedPath.rect(
        frame.insetBy(dx: hairline / 2, dy: hairline / 2), radius: max(radius - hairline / 2, 0)),
      border: colours.border, borderWidth: hairline)
  }

  private static func caption(
    _ text: String, _ place: (frame: CGRect, alignment: Label.Alignment), _ colours: TilePalette
  ) -> Label {
    Label(
      text: text, frame: place.frame, size: captionSize, isStrong: false, alignment: place.alignment,
      colour: colours.ink, shadow: colours.inkShadow)
  }

  /// Only the UI can measure text. Rather too wide than too narrow, for a capsule that is too narrow cuts a name short
  /// that there was room for: in ems of the system font, the widest letter of each kind.
  private static func estimatedWidth(of text: String) -> CGFloat {
    text.reduce(0) { width, character in
      let ems: CGFloat
      if character.unicodeScalars.contains(where: { $0.value >= 0x2E80 }) {
        ems = 1.3  // Ideographs, syllables, emoji.
      } else if "mwMW@%".contains(character) {
        ems = 1
      } else {
        ems = character.isUppercase || character.isNumber ? 0.78 : 0.6
      }
      return width + captionSize * ems
    }.rounded(.up)
  }

  /// What looks centred sits a little above the middle.
  private static func lift(in size: CGSize) -> CGFloat { min(6, (size.height * 0.02).rounded()) }

  /// Places an emblem (an icon or a glyph, `emblem` points square) in a tile, with a caption if there is `text`.
  ///
  /// Where there is room the caption goes under the emblem and the two are centred as one block. A tile
  /// too low for that but wide enough gets them side by side. Failing both, the emblem stands alone,
  /// and in a tile too small even for that the colour has to do.
  private static func arrange(
    in size: CGSize, emblem side: CGFloat, spacing: CGFloat, text: String?
  ) -> (emblem: CGRect?, label: (frame: CGRect, alignment: Label.Alignment)?) {
    let hasEmblem = side >= smallestEmblem
    let side = hasEmblem ? side : 0
    let spacing = hasEmblem ? spacing : 0
    let room = size.width - 2 * margin

    let stacked = side + spacing + captionHeight
    if text != nil, room >= narrowestCaption, stacked + 20 <= size.height {
      let top = ((size.height - stacked) / 2 - lift(in: size)).rounded()
      return (
        hasEmblem ? CGRect(x: ((size.width - side) / 2).rounded(), y: top, width: side, height: side) : nil,
        (CGRect(x: margin, y: top + side + spacing, width: room, height: captionHeight), .centre)
      )
    }

    let beside = room - side - 6
    if let text, hasEmblem, beside >= narrowestCaption, captionHeight + 4 <= size.height {
      // An estimate is enough to centre the pair; the label's frame runs on to the margin, so a low one cuts nothing off.
      let estimate = min(beside, estimatedWidth(of: text))
      let left = (margin + (beside - estimate) / 2).rounded()
      return (
        CGRect(x: left, y: ((size.height - side) / 2).rounded(), width: side, height: side),
        (
          CGRect(
            x: left + side + 6, y: ((size.height - captionHeight) / 2).rounded(),
            width: size.width - margin - (left + side + 6), height: captionHeight),
          .left
        )
      )
    }

    guard hasEmblem else { return (nil, nil) }
    return (
      CGRect(
        x: ((size.width - side) / 2).rounded(), y: ((size.height - side) / 2 - lift(in: size)).rounded(),
        width: side, height: side),
      nil
    )
  }

  /// A capsule in the bottom-right corner with the group's name, or else the number of its windows. It is glass, dark
  /// over light mode's pale colours and light over dark mode's deep ones, so it stands out from any of them and white
  /// text reads on it.
  private static func badge(name: String?, count: Int, in size: CGSize, isDark: Bool) -> Badge? {
    let height: CGFloat = 18
    let inset = TileMetrics.miniatureInset(for: size) + 4
    let room = size.width - 2 * inset
    var text = String(count)
    var width = max(height, CGFloat(text.count) * 7 + 11)
    // A long name is cut short by the UI; a tile with no room for the beginning of one shows the number.
    if let name, room >= narrowestCaption + 14 {
      text = name
      width = min(room, max(height, estimatedWidth(of: name) + 14))
    }
    guard count > 0, width <= room, height + 2 * inset <= size.height else { return nil }
    let frame = CGRect(
      x: size.width - inset - width, y: size.height - inset - height, width: width, height: height)
    return Badge(
      frame: frame, outline: RoundedPath.capsule(frame),
      fill: isDark ? RGBA.white.withAlpha(0.24) : RGBA.black.withAlpha(0.5),
      label: Label(
        text: text, frame: frame.insetBy(dx: 0, dy: 2), size: captionSize, isStrong: true, alignment: .centre,
        colour: .white, shadow: nil))
  }
}
