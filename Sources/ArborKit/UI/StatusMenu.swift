import AppKit
import ArborCore

/// The menu bar item (docs/features/F10-menu-bar-and-onboarding.md).
///
/// With `menuBarControls` it shows a row of buttons: back, forward, the Desktop, everything and each
/// saved view, drawn as one image from a `MenuBarModel`. A click on a button runs its command; a right
/// click, or a click with ⌃ or ⌥, opens the menu. Otherwise, and while Arbor is not arranging windows (it waits
/// for permission, or is paused), it is a single icon that opens the menu. What is shown and what a click means
/// are decided in ArborCore and the controller; this class draws the one and reports the other.
///
/// The menu is rebuilt each time it opens, so it reflects the current state (the display under
/// the pointer, the focused app, saved views, permission).
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
  private let item: NSStatusItem
  private unowned let app: ArborApp
  private let menu = NSMenu()
  private var watcher: MenuBarWatcher?
  /// The buttons in the item's image, which clicks are read against. Nil while it is a single icon.
  private var layout: MenuBarLayout?
  private var menuIsOpen = false
  /// What the single icon's tooltip says.
  private var iconLabel = "Arbor"
  private var wakeObservers: [any NSObjectProtocol] = []

  init(app: ArborApp) {
    self.app = app
    item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()
    menu.delegate = self
    menu.autoenablesItems = false
    if let button = item.button {
      button.imagePosition = .imageOnly
      button.target = self
      button.action = #selector(clicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    let watcher = MenuBarWatcher(
      controller: app.controller, isShowing: { [weak self] in self?.isShowing }, onChange: { [weak self] in self?.show($0) })
    self.watcher = watcher
    show(watcher.model)
    // Asleep, the displays show nothing, and neither does a session somebody else has switched away from: an item drawn just
    // then would be taken for one that found no room.
    for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
      wakeObservers.append(
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.watcher?.tryAgain() }
        })
    }
  }

  // MARK: The item

  /// Whether macOS shows the item, which it silently leaves out of a menu bar that is too full. Nil where that cannot be
  /// told: a menu bar that hides itself, or a full screen Space, shows no item however much room there is.
  private var isShowing: Bool? {
    guard let window = item.button?.window, let screen = window.screen ?? NSScreen.main,
      screen.frame.maxY - screen.visibleFrame.maxY > 1
    else { return nil }
    return window.occlusionState.contains(.visible)
  }

  private func show(_ model: MenuBarModel) {
    guard let button = item.button else { return }
    let image: NSImage
    if model.buttons.isEmpty {
      layout = nil
      image = ArborArtwork.menuBarIcon(model.icon.glyph)
    } else {
      let layout = MenuBarLayout(model)
      self.layout = layout
      image = ArborArtwork.menuBarControls(layout, fill: model.fill)
    }
    // Not `appearsDisabled`: macOS draws that at 1.8 to 1 on the bar, as faint as a greyed menu item, and during a pause this is the one thing
    // to click in order to resume. In the image, which is what every copy of the item on every display is drawn from.
    button.image = model.icon.isDimmed ? ArborArtwork.paused(image) : image
    button.setAccessibilityLabel(model.icon.label)
    iconLabel = model.icon.label
    attachMenu()
    // Once the item has taken the width of its new image.
    DispatchQueue.main.async { [weak self] in self?.placeToolTips() }
  }

  /// An item with a menu of its own opens it on every click and never calls `clicked`: right for the single
  /// icon, wrong for the buttons. Left alone while the menu is open, whichever way it was opened.
  private func attachMenu() {
    guard !menuIsOpen else { return }
    item.menu = layout == nil ? menu : nil
  }

  /// Where the image starts in the button, which centres it and is a little wider.
  private func imageOrigin(in button: NSStatusBarButton, layout: MenuBarLayout) -> CGFloat {
    (button.bounds.width - layout.size.width) / 2
  }

  /// One tooltip per button of the image.
  private func placeToolTips() {
    guard let button = item.button else { return }
    button.removeAllToolTips()
    guard let layout else {
      button.toolTip = iconLabel
      return
    }
    button.toolTip = nil
    let origin = imageOrigin(in: button, layout: layout)
    for cell in layout.cells {
      button.addToolTip(
        NSRect(x: origin + cell.minX, y: 0, width: cell.width, height: button.bounds.height), owner: self, userData: nil)
    }
  }

  /// AppKit asks the owner of a tooltip rectangle for its text under this name.
  @objc(view:stringForToolTip:point:userData:)
  func view(
    _ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData: UnsafeMutableRawPointer?
  ) -> String {
    guard let button = item.button, let layout else { return "Arbor" }
    return layout.button(atX: point.x - imageOrigin(in: button, layout: layout))?.tooltip ?? "Arbor"
  }

  @objc private func clicked(_ sender: Any?) {
    guard let button = item.button, let layout else { return openMenu() }
    // Anything but a mouse click (VoiceOver pressing the item, say) has no position, so it gets the menu.
    guard let event = NSApp.currentEvent, event.type == .leftMouseUp || event.type == .rightMouseUp,
      let x = position(of: event, in: button)
    else { return openMenu() }
    let secondary = event.type == .rightMouseUp || !event.modifierFlags.isDisjoint(with: [.control, .option])

    switch layout.click(atX: x - imageOrigin(in: button, layout: layout), secondary: secondary) {
    case .menu:
      openMenu()
    case .nothing:
      break
    case .run(let command):
      app.handle(command)
    }
    // The pointer may have come from another display since the item was drawn, and a command that
    // failed reports no change: show this display's buttons either way.
    watcher?.update()
  }

  /// How far from the button's left edge a click was. The event says, in the coordinates of the
  /// item's window. Should that fall outside the button (the item is shown on every display, and by another
  /// process since macOS 26), the pointer's place on screen against the button's is the second opinion.
  private func position(of event: NSEvent, in button: NSStatusBarButton) -> CGFloat? {
    let local = button.convert(event.locationInWindow, from: nil).x
    var onScreen: CGFloat?
    if let window = button.window {
      onScreen = NSEvent.mouseLocation.x - window.convertToScreen(button.convert(button.bounds, to: nil)).minX
    }
    Log.debug(
      "menu bar click: x \(local) by the event, \(onScreen.map { "\($0)" } ?? "unknown") by the screen, "
        + "button \(button.bounds.width) wide")
    let width = -1...(button.bounds.width + 1)
    if width.contains(local) { return local }
    if let onScreen, width.contains(onScreen) { return onScreen }
    return nil
  }

  /// Pops the menu up under the item, as if it were the item's own, for as long as it is open.
  private func openMenu() {
    item.menu = menu
    item.button?.performClick(nil)
    attachMenu()
  }

  // MARK: The menu

  func menuWillOpen(_ menu: NSMenu) {
    menuIsOpen = true
  }

  func menuDidClose(_ menu: NSMenu) {
    menuIsOpen = false
    attachMenu()
    // A single icon opens its menu without `clicked` ever running. If it was drawn for another display, where nothing
    // is docked, this is the moment to show the buttons of the one the pointer is on now.
    watcher?.update()
  }

  /// What is in the menu is the controller's business (Controller+Menu.swift); this only shows it.
  func menuNeedsUpdate(_ menu: NSMenu) {
    fill(menu, with: app.controller.menuModel().sections)
  }

  private func fill(_ menu: NSMenu, with sections: [MenuModel.Section]) {
    menu.removeAllItems()
    for (index, section) in sections.enumerated() {
      if index > 0 { menu.addItem(.separator()) }
      if let title = section.title { menu.addItem(.sectionHeader(title: title)) }
      for item in section.items { menu.addItem(menuItem(item)) }
    }
  }

  private func menuItem(_ model: MenuModel.Item) -> NSMenuItem {
    let item = NSMenuItem(title: model.title, action: nil, keyEquivalent: "")
    switch model.action {
    case .run(let command):
      choose(item) { [weak self] in self?.app.handle(command) }
    case .app(let action):
      choose(item) { [weak self] in self?.app.carryOut(action) }
    case .submenu(let sections):
      let submenu = NSMenu()
      submenu.autoenablesItems = false
      fill(submenu, with: sections)
      item.submenu = submenu
    case .text:
      break
    }
    // Only for show where it is one of Arbor's own: Carbon takes those keys before any menu sees them.
    if let shortcut = model.shortcut {
      item.keyEquivalent = shortcut.keyEquivalent
      item.keyEquivalentModifierMask = shortcut.modifiers.eventFlags
    }
    item.isEnabled = model.isEnabled
    item.state = model.isTicked ? .on : .off
    item.toolTip = model.help
    if let note = model.note { item.badge = NSMenuItemBadge(string: note) }
    // A copy: the size is the image's own, and the image is its app's. 16 points, or the row grows (docs/MENU.md, rule 3).
    if let pid = model.iconOfProcess, let icon = AppAppearance.icon(pid: pid)?.copy() as? NSImage {
      icon.size = NSSize(width: 16, height: 16)
      item.image = icon
    }
    return item
  }

  private func choose(_ item: NSMenuItem, _ perform: @escaping @MainActor () -> Void) {
    let target = MenuAction(perform)
    item.target = target
    item.action = #selector(MenuAction.run)
    item.representedObject = target  // keeps the target alive with the item
  }
}

extension KeyChord.Modifiers {
  /// The same modifiers as AppKit names them.
  fileprivate var eventFlags: NSEvent.ModifierFlags {
    var flags: NSEvent.ModifierFlags = []
    if contains(.command) { flags.insert(.command) }
    if contains(.shift) { flags.insert(.shift) }
    if contains(.option) { flags.insert(.option) }
    if contains(.control) { flags.insert(.control) }
    return flags
  }
}

@MainActor
private final class MenuAction: NSObject {
  private let perform: @MainActor () -> Void
  init(_ perform: @escaping @MainActor () -> Void) { self.perform = perform }
  @objc func run() { perform() }
}
