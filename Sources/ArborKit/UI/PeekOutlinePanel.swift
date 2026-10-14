import AppKit
import ArborCore
import CoreGraphics

/// Draws the outline of a peek (`OverlayScene.peekOutline`): one panel per display, of which at most one shows.
@MainActor
final class PeekOutlines {
  private var panels: [DisplayID: PeekOutlinePanel] = [:]

  func update(display: DisplayID, frame: CGRect?, onClick: @escaping () -> Void) {
    guard let frame else {
      panels[display]?.orderOut(nil)
      return
    }
    let panel = panels[display] ?? PeekOutlinePanel()
    panels[display] = panel
    panel.outline.onClick = onClick
    // The line runs round the space, in the gap, rather than over its edge.
    let area = frame.insetBy(dx: -PeekOutlineView.reach, dy: -PeekOutlineView.reach)
    panel.setFrame(ScreenGeometry.appKit(fromGlobal: area), display: true)
    panel.orderFrontRegardless()
  }

  func removeAll() {
    panels.values.forEach { $0.close() }
    panels.removeAll()
  }
}

/// The panel takes the click meant for what it outlines and only reports it. With ⌃⌥ held, as they are during a
/// peek, the app underneath would open a contextual menu (⌃-click), and macOS would hide the app that had the
/// keyboard (⌥-click on another app).
final class PeekOutlinePanel: OverlayPanel {
  fileprivate let outline = PeekOutlineView()

  override init() {
    super.init()
    level = .floating
    // Said explicitly: clicks fall through the transparent parts of a borderless panel otherwise.
    ignoresMouseEvents = false
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    contentView = outline
  }
}

private final class PeekOutlineView: NSView {
  /// How far outside the space the panel reaches.
  static let reach: CGFloat = 5
  private static let lineWidth: CGFloat = 4

  var onClick: (() -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseDown(with event: NSEvent) {}
  override func mouseUp(with event: NSEvent) { onClick?() }
  // A ⌃-click may arrive as the other button's.
  override func rightMouseDown(with event: NSEvent) {}
  override func rightMouseUp(with event: NSEvent) { onClick?() }

  /// Windows on macOS 26 have the continuous curve of radius 17. The middle of the line runs `reach` less half
  /// its width outside them, so this radius keeps it parallel to their corners.
  private static let cornerRadius: CGFloat = 17 + reach - lineWidth / 2

  override func draw(_ dirtyRect: NSRect) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    let inset = Self.lineWidth / 2
    let path = ContinuousCorners.path(bounds.insetBy(dx: inset, dy: inset), radius: Self.cornerRadius)
    context.addPath(path)
    context.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor)
    context.fillPath()
    context.addPath(path)
    context.setStrokeColor(NSColor.controlAccentColor.cgColor)
    context.setLineWidth(Self.lineWidth)
    context.strokePath()
  }
}
