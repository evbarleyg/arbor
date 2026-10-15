import AppKit
import ArborCore

/// What Arbor draws of itself: the images of the menu bar item, and the app icon for its own windows.
/// The shapes come from ArborCore (`MenuBarLayout`, `ArborGlyph`); this only fills them in.
///
/// Not on the main actor: AppKit calls an image's drawing handler whenever and wherever it draws the
/// image, so these functions use nothing but their arguments.
enum ArborArtwork {
  // MARK: The menu bar

  /// How opaque a disabled button's glyph is.
  private static let disabledOpacity: CGFloat = 0.35

  /// How opaque the item is during a pause: dimmer than when Arbor runs, and still to be seen (3 to 1 and more on a light bar and a dark one).
  static let pausedOpacity: CGFloat = 0.6

  /// The item's image during a pause.
  static func paused(_ image: NSImage) -> NSImage {
    let faint = NSImage(size: image.size, flipped: false) { bounds in
      image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: pausedOpacity)
      return true
    }
    faint.isTemplate = true
    return faint
  }

  /// Every button of `layout` in one image. A template image carries only opacity, which macOS
  /// turns into black or white to suit the menu bar: so a current button's background is drawn
  /// faint (`fill`), with its glyph solid on top.
  static func menuBarControls(_ layout: MenuBarLayout, fill: Double) -> NSImage {
    let image = NSImage(size: layout.size, flipped: false) { _ in
      for (button, cell) in zip(layout.buttons, layout.cells) {
        draw(button, in: cell, fill: CGFloat(fill))
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  /// The item as a single icon: Arbor's mark on its own, or whatever sign the model asks for in its place. One size whatever it
  /// shows: the item never changes its width, so nothing beside it in the menu bar moves when Arbor is paused or holds the view.
  static func menuBarIcon(_ glyph: MenuBarModel.Button.Glyph = .arbor) -> NSImage {
    let image = NSImage(size: ArborGlyph.iconSize, flipped: false) { bounds in
      if case .symbol(let name) = glyph, let symbol = symbol(name) {
        symbol.draw(in: ArborGlyph.place(ofSign: symbol.size), from: .zero, operation: .sourceOver, fraction: 1)
      } else {
        // Every macOS Arbor runs on has the symbols; the mark is better than a hole all the same.
        drawMark(in: bounds, opacity: 1)
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  private static func symbol(_ name: String) -> NSImage? {
    NSImage(systemSymbolName: name, accessibilityDescription: nil)?
      .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium))
  }

  private static func draw(_ button: MenuBarModel.Button, in cell: CGRect, fill: CGFloat) {
    if button.isCurrent {
      NSColor.black.withAlphaComponent(fill).setFill()
      NSBezierPath(
        roundedRect: MenuBarLayout.chip(in: cell), xRadius: MenuBarLayout.chipRadius, yRadius: MenuBarLayout.chipRadius
      ).fill()
    }
    let opacity = button.isEnabled ? 1 : disabledOpacity
    switch button.glyph {
    case .arbor:
      let size = ArborGlyph.buttonSize
      drawMark(
        in: CGRect(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2, width: size.width, height: size.height),
        opacity: opacity)
    case .digit(let digit):
      draw(String(digit), in: cell, opacity: opacity)
    case .symbol(let name):
      guard let symbol = symbol(name) else {
        // Every macOS Arbor runs on has these symbols; an initial is better than a hole all the same.
        draw(String(button.title.prefix(1)), in: cell, opacity: opacity)
        return
      }
      let size = symbol.size
      symbol.draw(
        in: NSRect(
          x: (cell.midX - size.width / 2).rounded(), y: (cell.midY - size.height / 2).rounded(), width: size.width,
          height: size.height),
        from: .zero, operation: .sourceOver, fraction: opacity)
    }
  }

  private static func draw(_ text: String, in cell: CGRect, opacity: CGFloat) {
    let string = NSAttributedString(
      string: text,
      attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: NSColor.black.withAlphaComponent(opacity),
      ])
    let size = string.size()
    string.draw(at: NSPoint(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2))
  }

  private static func drawMark(in rect: CGRect, opacity: CGFloat) {
    NSColor.black.withAlphaComponent(opacity).setFill()
    for cell in ArborGlyph.cells(in: rect, gap: 1, yUp: true) {
      NSBezierPath(roundedRect: cell, xRadius: 1, yRadius: 1).fill()
    }
  }

  // MARK: The app icon

  /// The app icon, drawn rather than loaded, so that it is there when Arbor runs outside its bundle too.
  /// `scripts/make-icon.swift` draws the same picture for `Arbor.icns`; keep the two in step.
  static func appIcon(side: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: side, height: side), flipped: false) { bounds in
      // Apple's grid for macOS icons: the shape takes 824 of 1024 points, with a corner radius of 185.4.
      let shape = bounds.insetBy(dx: bounds.width * 100 / 1024, dy: bounds.height * 100 / 1024)
      let radius = shape.width * 185.4 / 824
      let top = NSColor(srgbRed: 0.18, green: 0.63, blue: 0.38, alpha: 1)
      let bottom = NSColor(srgbRed: 0.04, green: 0.29, blue: 0.20, alpha: 1)
      NSGradient(starting: top, ending: bottom)?
        .draw(in: NSBezierPath(roundedRect: shape, xRadius: radius, yRadius: radius), angle: -90)

      let markSide = (shape.width * 0.58).rounded()
      let mark = CGRect(
        x: (bounds.midX - markSide / 2).rounded(), y: (bounds.midY - markSide / 2).rounded(), width: markSide,
        height: markSide)
      let gap = max((markSide * 0.07).rounded(), 1)
      let corner = markSide * 0.045
      for (cell, opacity) in zip(ArborGlyph.cells(in: mark, gap: gap, yUp: true), ArborGlyph.opacities) {
        NSColor.white.withAlphaComponent(opacity).setFill()
        NSBezierPath(roundedRect: cell, xRadius: corner, yRadius: corner).fill()
      }
      return true
    }
  }
}
