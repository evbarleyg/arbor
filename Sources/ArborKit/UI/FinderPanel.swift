import AppKit
import ArborCore
import CoreGraphics
import Foundation

extension AppKitOverlays {
  public func showFinder(_ model: FinderModel?) {
    guard let model else {
      finderPanel?.hide()
      return
    }
    let panel = finderPanel ?? FinderPanel()
    finderPanel = panel
    panel.onChoose = { [weak self] destination in self?.actions?.finderChose(destination) }
    panel.onDismiss = { [weak self] in self?.actions?.finderDismissed() }
    panel.show(model)
  }
}

/// The palette of "Go to…": a text field over a list. What it lists, what matches, what is selected and
/// where everything sits is a `FinderSession` (ArborCore); this draws it and passes keys and clicks on.
///
/// Unlike Arbor's other panels it takes the keyboard. Being a non-activating panel it does so without
/// making Arbor the active app, so the app the user was in stays active behind it and simply has the keyboard
/// again when the palette goes: there is nothing to restore.
final class FinderPanel: NSPanel, NSTextFieldDelegate {
  var onChoose: ((FinderDestination) -> Void)?
  /// The palette closed itself.
  var onDismiss: (() -> Void)?

  /// Nil while the palette is closed.
  private var session: FinderSession?
  private let field = NSTextField(frame: .zero)
  private let finderView = FinderView()
  /// What watches, while the palette is open, for signs that the user has left it (`watchForLeaving`).
  private var eventMonitors: [Any] = []
  private var workspaceWatchers: [any NSObjectProtocol] = []

  init() {
    super.init(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    // Arbor is never active, so a panel that hides when its app is not would never show.
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .transient]
    ignoresMouseEvents = false
    // It lists the titles of every window, the most private thing Arbor touches: for the person at the Mac, not for an audience.
    // Like the minimap it keeps out of shared screens and recordings, as far as macOS honours this. The pictures of
    // scripts/mac-shell/shots-finder.sh need to see it.
    sharingType = ProcessInfo.processInfo.environment["ARBOR_PANELS_IN_PICTURES"] == "1" ? .readOnly : .none

    let backdrop = PanelGround(material: .popover, drawsOutline: false)
    contentView = backdrop

    finderView.frame = backdrop.bounds
    finderView.autoresizingMask = [.width, .height]
    finderView.onClick = { [weak self] place in self?.choose(self?.session?.destination(atVisible: place)) }
    backdrop.addSubview(finderView)

    field.isBordered = false
    field.isBezeled = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 22)
    field.textColor = PanelInk.main
    field.placeholderAttributedString = NSAttributedString(
      string: FinderSession.placeholder,
      attributes: [.font: NSFont.systemFont(ofSize: 22), .foregroundColor: PanelInk.second])
    field.usesSingleLineMode = true
    field.cell?.wraps = false
    field.cell?.isScrollable = true
    field.delegate = self
    finderView.addSubview(field)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  // MARK: Showing and closing

  /// Opens the palette, or, if it is open, replaces its list and keeps what was typed.
  func show(_ model: FinderModel) {
    let opening = load(model)
    if model.notice != nil { NSSound.beep() }
    guard opening else { return }
    // First, so that nothing can close the palette before there is something to take down.
    watchForLeaving()
    orderFrontRegardless()
    makeKey()
    makeFirstResponder(field)
    // AppKit's own book-keeping; whether the window server agreed shows only in where the keys go.
    Log.info("find: the palette is up, \(isKeyWindow ? "with" : "without") the keyboard")
  }

  /// Takes a list in and lays the palette out for it, without showing it or taking the keyboard: the first half of `show`,
  /// and all that the tests need that draw the palette off screen. Returns whether the palette was closed until now.
  @discardableResult
  func load(_ model: FinderModel) -> Bool {
    let opening = session == nil
    if opening {
      session = FinderSession(model: model)
      field.stringValue = ""
    } else {
      session?.replace(model: model)
    }
    finderView.forgetIcons()
    refresh()
    return opening
  }

  /// What typing does, for the same tests.
  func type(_ text: String) {
    field.stringValue = text
    session?.type(text)
    refresh()
  }

  /// `resignKey` should cover all of this. But a palette left on screen, over everything, with no way to be rid of
  /// it would be worse than closing it twice, and the second time does nothing.
  private func watchForLeaving() {
    // Clicks in other apps; and keys, which go to another app only if the palette does not have the keyboard, for
    // whatever reason. They cannot be kept from the app, but they still close the palette.
    let elsewhere = NSEvent.addGlobalMonitorForEvents(
      matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
    ) { [weak self] event in
      let isKey = event.type == .keyDown
      // The G of ⌃⌥G may still be down.
      let isRepeat = isKey && event.isARepeat
      MainActor.assumeIsolated {
        guard let self, !isRepeat else { return }
        // An input method's candidates, and the strip of accents, are windows of other processes: a click on one
        // in the middle of a word is not a click elsewhere.
        if !isKey, (self.field.currentEditor() as? NSTextView)?.hasMarkedText() == true { return }
        self.dismiss()
      }
    }
    // Clicks on Arbor's own tiles and gap handles, which take no keyboard and which a global monitor does not see.
    let here = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
      [weak self] event in
      let number = event.windowNumber
      MainActor.assumeIsolated {
        if let self, number != self.windowNumber { self.dismiss() }
      }
      return event
    }
    eventMonitors = [elsewhere, here].compactMap { $0 }
    // ⌘Tab, a swipe to another macOS Space (the palette is on all of them, so it would come along), Mission Control's
    // choice of one, the lock screen.
    let center = NSWorkspace.shared.notificationCenter
    workspaceWatchers = [
      NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
      NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.screensDidSleepNotification,
    ].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        // Arbor itself coming forward (its settings window, say) is no reason.
        let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
        guard app != ProcessInfo.processInfo.processIdentifier else { return }
        MainActor.assumeIsolated { self?.dismiss() }
      }
    }
  }

  /// Closes the palette because the controller said so.
  func hide() {
    guard session != nil else { return }
    // Cleared first: ordering out makes the panel resign the keyboard, which must not count as the user leaving.
    session = nil
    for monitor in eventMonitors { NSEvent.removeMonitor(monitor) }
    eventMonitors.removeAll()
    for watcher in workspaceWatchers { NSWorkspace.shared.notificationCenter.removeObserver(watcher) }
    workspaceWatchers.removeAll()
    orderOut(nil)
  }

  /// Closes the palette because the user left it, and says so.
  func dismiss() {
    guard session != nil else { return }
    hide()
    onDismiss?()
  }

  /// The keyboard went to another window: the user clicked elsewhere or switched apps.
  override func resignKey() {
    super.resignKey()
    dismiss()
  }

  private func refresh() {
    guard let session else { return }
    let geometry = session.layout
    setFrame(ScreenGeometry.appKit(fromGlobal: geometry.panel), display: false)
    finderView.frame = NSRect(origin: .zero, size: geometry.panel.size)
    field.frame = geometry.field
    finderView.show(items: session.items, message: session.message, geometry: geometry)
    invalidateShadow()
  }

  private func choose(_ destination: FinderDestination?) {
    if let destination {
      onChoose?(destination)
    } else {
      NSSound.beep()
    }
  }

  // MARK: Keys

  func controlTextDidChange(_ obj: Notification) {
    session?.type(field.stringValue)
    refresh()
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.moveDown(_:)):
      session?.moveSelection(by: 1)
    case #selector(NSResponder.moveUp(_:)):
      session?.moveSelection(by: -1)
    case #selector(NSResponder.insertTab(_:)):
      session?.tab(by: 1)
    case #selector(NSResponder.insertBacktab(_:)):
      session?.tab(by: -1)
    case #selector(NSResponder.scrollPageDown(_:)), #selector(NSResponder.pageDown(_:)):
      session?.pageSelection(by: 1)
    case #selector(NSResponder.scrollPageUp(_:)), #selector(NSResponder.pageUp(_:)):
      session?.pageSelection(by: -1)
    case #selector(NSResponder.insertNewline(_:)):
      choose(session?.selected)
      return true
    case #selector(NSResponder.cancelOperation(_:)):
      dismiss()
      return true
    default:
      return false
    }
    refresh()
    return true
  }

  /// Escape, should the field ever not have the keyboard.
  override func cancelOperation(_ sender: Any?) {
    dismiss()
  }

  /// ⌘1–⌘9 choose a place. ⌘A, ⌘X, ⌘C and ⌘V are an Edit menu's work in other apps; Arbor has no menu bar.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.type == .keyDown,
      event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
      let key = event.charactersIgnoringModifiers
    else { return super.performKeyEquivalent(with: event) }
    if let digit = Int(key), (1...9).contains(digit) {
      choose(session?.destination(atDigit: digit))
      return true
    }
    guard let editor = field.currentEditor() else { return super.performKeyEquivalent(with: event) }
    switch key {
    case "a": editor.selectAll(nil)
    case "x": editor.cut(nil)
    case "c": editor.copy(nil)
    case "v": editor.paste(nil)
    default: return super.performKeyEquivalent(with: event)
    }
    return true
  }
}

/// Everything in the palette but the text field, which is its subview: the line under the field, the rows,
/// the message and the outline. Coordinates are `FinderLayout`'s: origin top-left, y down.
private final class FinderView: NSView {
  static let cornerRadius = PanelLook.Corner.panel

  /// A click on the row at this place from the top.
  var onClick: ((Int) -> Void)?

  private var items: [FinderSession.Item] = []
  private var message: String?
  /// Not called `layout`, which is a method of every view.
  private var geometry: FinderLayout?
  /// App icons by process, looked up once each time the palette gets a list.
  private var icons: [Int32: NSImage] = [:]

  private static let truncating: NSParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byTruncatingTail
    return style
  }()

  private static let truncatingRightAligned: NSParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byTruncatingTail
    style.alignment = .right
    return style
  }()

  override var isFlipped: Bool { true }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  func show(items: [FinderSession.Item], message: String?, geometry: FinderLayout) {
    self.items = items
    self.message = message
    self.geometry = geometry
    needsDisplay = true
  }

  func forgetIcons() { icons.removeAll() }

  override func mouseUp(with event: NSEvent) {
    guard let geometry else { return }
    let point = convert(event.locationInWindow, from: nil)
    if let place = geometry.row(at: CGPoint(x: point.x - geometry.list.minX, y: point.y - geometry.list.minY)) {
      onClick?(place)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let geometry else { return }
    let list = geometry.list
    drawGlyph(in: geometry.glyph)
    if list.height > 0 {
      NSColor.separatorColor.setFill()
      NSBezierPath(rect: NSRect(x: 0, y: list.minY, width: bounds.width, height: 1)).fill()
    }
    for (place, item) in items.enumerated() {
      draw(item, in: geometry.rowFrame(place).offsetBy(dx: list.minX, dy: list.minY))
    }
    if let message {
      let frame = geometry.messageFrame.offsetBy(dx: list.minX, dy: list.minY)
      NSAttributedString(
        string: message,
        attributes: [
          .font: NSFont.systemFont(ofSize: 12), .foregroundColor: PanelInk.second,
          .paragraphStyle: Self.truncating,
        ]
      ).draw(in: NSRect(x: frame.minX + 12, y: frame.midY - 8, width: max(frame.width - 24, 0), height: 16))
    }
    // Here and not on the ground, so that it is in the pictures the tests take of this view.
    PanelOutlineView.draw(
      in: bounds, radius: Self.cornerRadius, increasesContrast: effectiveAppearance.increasesContrast)
  }

  private func drawGlyph(in frame: NSRect) {
    let configuration = NSImage.SymbolConfiguration(pointSize: frame.height - 2, weight: .medium)
      // In the second ink its thin ring stood out by 2.75 to 3 to 1 in the light look (measured on a hosted Mac).
      .applying(NSImage.SymbolConfiguration(paletteColors: [PanelInk.main]))
    guard
      let image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration),
      image.size.width > 0, image.size.height > 0
    else { return }
    let scale = min(frame.width / image.size.width, frame.height / image.size.height, 1)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    image.draw(
      in: NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2, width: size.width, height: size.height),
      from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
  }

  private func draw(_ item: FinderSession.Item, in frame: NSRect) {
    let selected = item.isSelected
    let selection = selected ? PanelInk.selection() : nil
    if let selection {
      selection.fill.setFill()
      // Side by side with the panel's own corner.
      let radius = PanelLook.Corner.inside(Self.cornerRadius, inset: frame.minX)
      NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).fill()
    }
    // The title is in the main ink too: it is what tells six windows of one app apart. The app's name is set off by its
    // weight, and the letters that matched by theirs: the accent colour cannot be read on every ground.
    let primary: NSColor = selection?.ink ?? PanelInk.main
    let faint: NSColor = selection?.ink.withAlphaComponent(0.85) ?? PanelInk.second

    let iconFrame = NSRect(x: frame.minX + 10, y: frame.midY - 12, width: 24, height: 24)
    if let pid = item.row.pid {
      icon(for: pid)?.draw(
        in: iconFrame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    } else if let badge = item.row.badge {
      (selection?.ink.withAlphaComponent(0.25) ?? NSColor.quaternaryLabelColor).setFill()
      NSBezierPath(roundedRect: iconFrame, xRadius: 6, yRadius: 6).fill()
      let text = NSAttributedString(
        string: badge, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: primary])
      let size = text.size()
      text.draw(at: NSPoint(x: iconFrame.midX - size.width / 2, y: iconFrame.midY - size.height / 2))
    }

    let note = NSAttributedString(
      string: item.row.note,
      attributes: [
        .font: NSFont.systemFont(ofSize: 11), .foregroundColor: faint, .paragraphStyle: Self.truncatingRightAligned,
      ])
    let noteWidth = min(note.size().width.rounded(.up) + 2, frame.width * 0.45)
    let noteFrame = NSRect(x: frame.maxX - 12 - noteWidth, y: frame.midY - 7, width: noteWidth, height: 15)
    note.draw(in: noteFrame)

    let line = styled(
      item.row.name, item.match.nameRanges, font: .systemFont(ofSize: 13, weight: .semibold), colour: primary)
    if !item.row.detail.isEmpty {
      line.append(NSAttributedString(string: "   ", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
      line.append(
        styled(item.row.detail, item.match.detailRanges, font: .systemFont(ofSize: 13), colour: primary))
    }
    line.addAttribute(.paragraphStyle, value: Self.truncating, range: NSRange(location: 0, length: line.length))
    let left = iconFrame.maxX + 10
    line.draw(in: NSRect(x: left, y: frame.midY - 9, width: max(noteFrame.minX - 12 - left, 0), height: 18))
  }

  /// `text` with the characters in `ranges` (character offsets) set off: heavy, and underlined, which shows in the app's
  /// name too.
  private func styled(
    _ text: String, _ ranges: [Range<Int>], font: NSFont, colour: NSColor
  ) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: colour])
    let bold = NSFont.systemFont(ofSize: font.pointSize, weight: .heavy)
    for range in FinderMatch.utf16Ranges(ranges, in: text) where range.upperBound <= result.length {
      result.addAttributes(
        [.font: bold, .underlineStyle: NSUnderlineStyle.single.rawValue],
        range: NSRange(location: range.lowerBound, length: range.count))
    }
    return result
  }

  private func icon(for pid: Int32) -> NSImage? {
    if let known = icons[pid] { return known }
    let image = AppAppearance.icon(pid: pid)
    icons[pid] = image
    return image
  }
}
