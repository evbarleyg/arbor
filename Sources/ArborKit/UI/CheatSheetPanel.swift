import AppKit
import ArborCore
import CoreGraphics
import Foundation

/// Draws the panel of shortcuts (`CheatSheetModel`) and reports the key press or click that ends it.
///
/// It takes the keyboard while it is up, without making Arbor the active app, so that the key that puts it away is
/// not also typed into the document behind it. Arbor's own shortcuts never arrive here; the controller puts the
/// panel away when one of them runs a command.
final class CheatSheetPanel: PassingPanel {
  var onDismiss: (() -> Void)?
  private let list = CheatSheetView()
  private var monitor: Any?

  override init() {
    super.init()
    // Said out loud: the window server lets clicks fall through where a borderless panel draws nothing.
    ignoresMouseEvents = false
    list.autoresizingMask = [.width, .height]
    background.addSubview(list)
  }

  override var canBecomeKey: Bool { true }

  /// Where everything goes, at the size that fits the model's area. Worked out without a window, so that tests can draw
  /// it off screen.
  static func layout(of model: CheatSheetModel) -> CheatSheetLayout {
    let room = NSSize(width: model.area.width - 2 * Self.margin, height: model.area.height - 2 * Self.margin)
    let layout = CheatSheetLayout(model, scale: 1)
    // A long list on a small display is drawn smaller rather than cut off.
    let fit = min(room.width / layout.size.width, room.height / layout.size.height)
    return fit < 1 ? CheatSheetLayout(model, scale: max(fit * 0.98, 0.4)) : layout
  }

  func show(_ model: CheatSheetModel) {
    let layout = Self.layout(of: model)
    let frame = CGRect(
      x: (model.area.midX - layout.size.width / 2).rounded(), y: (model.area.midY - layout.size.height / 2).rounded(),
      width: layout.size.width, height: layout.size.height)
    setFrame(ScreenGeometry.appKit(fromGlobal: frame), display: false)
    list.frame = background.bounds
    list.placed = layout
    invalidateShadow()
    appear()
    makeKey()
    Log.debug("the panel of shortcuts is up, \(isKeyWindow ? "with" : "without") the keyboard")
    watchOtherApps()
  }

  func hide() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    // At once: while it faded it would still have the keyboard, and swallow what is typed next.
    disappear(atOnce: true)
  }

  private static let margin: CGFloat = 24

  /// Clicks outside the panel go to other apps, and so do keys should macOS not have let the panel have the
  /// keyboard (secure text entry, say). Those cannot be kept from the app, but they still put the panel away.
  private func watchOtherApps() {
    guard monitor == nil else { return }
    monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) {
      [weak self] event in
      // A key held down since before the panel came up is not a key press.
      let isRepeat = event.type == .keyDown && event.isARepeat
      MainActor.assumeIsolated {
        if !isRepeat { self?.dismiss("something typed or clicked in another app") }
      }
    }
  }

  private func dismiss(_ cause: String) {
    guard isWanted else { return }
    Log.debug("the panel of shortcuts is put away by \(cause)")
    onDismiss?()
    // Whatever the controller makes of that: the keyboard goes back to the app it was taken from.
    hide()
  }

  // Not passed on to `super`, which beeps at keys nobody wants.
  override func keyDown(with event: NSEvent) {
    // The / of ⌃⌥⇧/ may still be down.
    if !event.isARepeat { dismiss("a key") }
  }
  override func mouseDown(with event: NSEvent) { dismiss("a click on it") }
  override func rightMouseDown(with event: NSEvent) { dismiss("a click on it") }

  override func resignKey() {
    super.resignKey()
    dismiss("losing the keyboard")
  }
}

/// Where every piece of text of the panel goes, in a view whose y grows downward.
@MainActor
struct CheatSheetLayout {
  var size = NSSize.zero
  var texts: [(text: NSAttributedString, origin: NSPoint)] = []

  init(_ model: CheatSheetModel, scale s: CGFloat) {
    let padding = 28 * s
    let rowHeight = 22 * s
    let headingHeight = 24 * s
    let sectionGap = 14 * s
    let gutter = 14 * s  // between the keys and what they do
    let columnGap = 40 * s

    func string(_ text: String, _ size: CGFloat, _ weight: NSFont.Weight, _ colour: NSColor) -> NSAttributedString {
      NSAttributedString(
        string: text, attributes: [.font: NSFont.systemFont(ofSize: size * s, weight: weight), .foregroundColor: colour])
    }

    let title = string(model.title, 17, .semibold, PanelInk.main)
    let footer = string(model.footer, 12, .regular, PanelInk.second)
    let top = padding + title.size().height + 14 * s
    var x = padding
    var bottom = top

    for column in model.columns {
      let rows = column.flatMap(\.rows).map { row in
        (keys: string(row.keys, 13, .medium, PanelInk.main), title: string(row.title, 13, .regular, PanelInk.main))
      }
      // Keys end and titles begin at the same line all the way down a column.
      let keysWidth = (rows.map { $0.keys.size().width }.max() ?? 0).rounded(.up)
      let titleWidth = (rows.map { $0.title.size().width }.max() ?? 0).rounded(.up)
      var y = top
      var next = 0
      for (index, section) in column.enumerated() {
        if index > 0 { y += sectionGap }
        texts.append((string(section.title, 12, .semibold, PanelInk.second), NSPoint(x: x + keysWidth + gutter, y: y)))
        y += headingHeight
        for _ in section.rows {
          let row = rows[next]
          next += 1
          texts.append((row.keys, NSPoint(x: x + keysWidth - row.keys.size().width, y: y)))
          texts.append((row.title, NSPoint(x: x + keysWidth + gutter, y: y)))
          y += rowHeight
        }
      }
      bottom = max(bottom, y)
      x += keysWidth + gutter + titleWidth + columnGap
    }

    let width = max(x - columnGap, padding + max(title.size().width, footer.size().width)) + padding
    let footerY = bottom + 12 * s
    size = NSSize(width: width.rounded(.up), height: (footerY + footer.size().height + padding * 0.8).rounded(.up))
    texts.append((title, NSPoint(x: (size.width - title.size().width) / 2, y: padding * 0.8)))
    texts.append((footer, NSPoint(x: (size.width - footer.size().width) / 2, y: footerY)))
  }
}

final class CheatSheetView: NSView {
  var placed: CheatSheetLayout? {
    didSet { needsDisplay = true }
  }

  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    for item in placed?.texts ?? [] { item.text.draw(at: item.origin) }
  }
}
