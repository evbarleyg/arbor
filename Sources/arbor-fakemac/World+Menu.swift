import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// The menu bar item's menu while it is open: a table of titles, places and what a click does.
struct Menu {
  enum Action {
    case command(Command)
    case openSettingsFile
    case openLog
    case quit
    /// Opens `children`.
    case submenu
    /// A line of text: there to be read.
    case nothing
  }

  struct Item {
    var title: String
    var action: Action
    var children: [Item] = []
    var ticked = false
    var frame = CGRect.zero
  }

  /// An item of the menu, or of the submenu that is open.
  struct Path: Equatable {
    var top: Int
    var child: Int?
  }

  var id: UInt32
  var submenuID: UInt32
  var frame = CGRect.zero
  var items: [Item]
  /// The item whose submenu is open.
  var openItem: Int?
  /// How much of the menu lies below where the display cuts it off.
  var hiddenBelow: CGFloat = 0

  var submenuFrame: CGRect? {
    guard let openItem, let first = items[openItem].children.first, let last = items[openItem].children.last
    else {
      return nil
    }
    return first.frame.union(last.frame).insetBy(dx: 0, dy: -Menu.padding)
  }

  // What macOS 26 gives them, so that the menu itself is as high here as on a Mac, and as `menu` says. Not so a submenu.
  static let rowHeight = CGFloat(MenuModel.Metrics.macOS26.row)
  static let separatorHeight = CGFloat(MenuModel.Metrics.macOS26.separator)
  static let padding = CGFloat(MenuModel.Metrics.macOS26.padding)
}

extension World {
  /// Where the runner's menu bar put Arbor's item: 763 4 26 22 on its 1024 points, left of Control Center's
  /// three. With its buttons it grows to the left, by what macOS puts around the image (8 points a side).
  var statusItemFrame: CGRect {
    let width = statusItemLayout.map { $0.size.width + 16 } ?? 26
    return CGRect(
      x: display.frame.maxX - 235 - width, y: ((display.visibleFrame.minY - 22) / 2).rounded(.down), width: width,
      height: 22)
  }

  /// The row of buttons, as `StatusMenu.show` lays it out. Nil while the item is a single icon.
  var statusItemLayout: MenuBarLayout? {
    guard let model = arbor?.controller.menuBarModel(), !model.buttons.isEmpty else { return nil }
    return MenuBarLayout(model)
  }

  /// `StatusMenu.clicked`. The image is centred in the item.
  func clickStatusItem(at point: CGPoint, secondary: Bool) {
    guard let layout = statusItemLayout else { return openMenu() }
    let origin = statusItemFrame.minX + (statusItemFrame.width - layout.size.width) / 2
    switch layout.click(atX: point.x - origin, secondary: secondary) {
    case .menu: openMenu()
    case .nothing: break
    case .run(let command): handle(command)
    }
  }

  var hasStatusItem: Bool { arbor.map { !$0.noStatusItem } ?? false }

  // MARK: Building, as `StatusMenu.menuNeedsUpdate` does: from the controller's model

  func openMenu() {
    guard let arbor else { return }
    func item(_ model: MenuModel.Item) -> Menu.Item {
      let action: Menu.Action
      switch model.action {
      case _ where !model.isEnabled: action = .nothing
      case .run(let command): action = .command(command)
      case .app(.openSettingsFile): action = .openSettingsFile
      case .app(.showLog): action = .openLog
      case .app(.quit): action = .quit
      case .app(.showAbout): action = .nothing  // there is no panel to open here
      case .submenu: action = .submenu
      case .text: action = .nothing
      }
      // One level of submenus, whose headings and separators are left out: they cannot be chosen.
      return Menu.Item(
        title: model.title, action: action, children: model.sections.flatMap(\.items).map(item), ticked: model.isTicked)
    }
    /// A nil stands for a separator. A heading is a row that is there to be read, and as high as one.
    var rows: [Menu.Item?] = []
    for (index, section) in arbor.controller.menuModel().sections.enumerated() {
      if index > 0 { rows.append(nil) }
      if let title = section.title { rows.append(Menu.Item(title: title, action: .nothing)) }
      rows += section.items.map(item)
    }
    arbor.menu = laidOut(rows)
  }

  /// Gives every item a place: the menu hangs below the menu bar item, pushed left to fit the screen, and
  /// submenus open on the side that has room. The widths are made up; only this file knows them.
  private func laidOut(_ rows: [Menu.Item?]) -> Menu {
    let width: CGFloat = 300
    let submenuWidth: CGFloat = 240
    let left = min(statusItemFrame.minX, display.frame.maxX - width - 8)
    let top = display.visibleFrame.minY
    var menu = Menu(id: newOverlayID(), submenuID: newOverlayID(), items: [])
    var y = top + Menu.padding
    for row in rows {
      guard var item = row else {
        y += Menu.separatorHeight
        continue
      }
      item.frame = CGRect(x: left, y: y, width: width, height: Menu.rowHeight)
      let fitsRight = left + width + submenuWidth <= display.frame.maxX
      for index in item.children.indices {
        item.children[index].frame = CGRect(
          x: fitsRight ? left + width : left - submenuWidth, y: y + CGFloat(index) * Menu.rowHeight,
          width: submenuWidth,
          height: Menu.rowHeight)
      }
      menu.items.append(item)
      y += Menu.rowHeight
    }
    // A menu taller than the display is cut off above the Dock (a hosted Mac: 31 to 699 of 768 points) and scrolls.
    // Accessibility goes on giving the rows below the cut the places they would have.
    let foot = min(y + Menu.padding, display.visibleFrame.maxY - 6)
    menu.frame = CGRect(x: left, y: top, width: width, height: foot - top)
    menu.hiddenBelow = y + Menu.padding - foot
    return menu
  }

  /// ↑ with no row chosen goes to the last row, and a menu that is cut off scrolls to its end.
  func scrollMenuToItsEnd() {
    guard let arbor, var menu = arbor.menu, menu.hiddenBelow > 0 else { return }
    for index in menu.items.indices {
      menu.items[index].frame.origin.y -= menu.hiddenBelow
      for child in menu.items[index].children.indices { menu.items[index].children[child].frame.origin.y -= menu.hiddenBelow }
    }
    menu.hiddenBelow = 0
    arbor.menu = menu
  }

  func closeMenu() { arbor?.menu = nil }

  // MARK: Finding items

  func menuItem(at point: CGPoint) -> Menu.Path? {
    guard let menu = arbor?.menu else { return nil }
    if let top = menu.openItem,
      let child = menu.items[top].children.firstIndex(where: { $0.frame.contains(point) })
    {
      return Menu.Path(top: top, child: child)
    }
    // What the display cuts off cannot be pressed.
    guard menu.frame.contains(point) else { return nil }
    return menu.items.firstIndex { $0.frame.contains(point) }.map { Menu.Path(top: $0, child: nil) }
  }

  /// The first item whose title starts with `prefix`, in the order Accessibility lists them: a submenu's items
  /// come right after the item that opens it. Those of a closed submenu have no place yet.
  func menuItem(titled prefix: String) -> Menu.Item? {
    guard let menu = arbor?.menu else { return nil }
    for (index, item) in menu.items.enumerated() {
      if item.title.hasPrefix(prefix) { return item }
      if menu.openItem == index, let child = item.children.first(where: { $0.title.hasPrefix(prefix) }) {
        return child
      }
    }
    return nil
  }

  // MARK: Using it

  /// A submenu opens as the pointer comes to rest on its item and closes when it goes to another.
  func hoverInMenu(at point: CGPoint) {
    guard let arbor, let path = menuItem(at: point), path.child == nil, let menu = arbor.menu else { return }
    arbor.menu?.openItem = menu.items[path.top].children.isEmpty ? nil : path.top
  }

  func choose(_ path: Menu.Path) {
    guard let arbor, let menu = arbor.menu, menu.items.indices.contains(path.top) else { return }
    var item = menu.items[path.top]
    if let child = path.child {
      guard item.children.indices.contains(child) else { return }
      item = item.children[child]
    }
    if case .submenu = item.action {
      arbor.menu?.openItem = path.top
      return
    }
    // A click on an item that is greyed out leaves the menu open.
    if case .nothing = item.action { return }
    closeMenu()
    switch item.action {
    case .command(let command): handle(command)
    case .openSettingsFile:
      // `ArborApp.openSettingsFile`; nothing here opens the file in an editor.
      createSettings(arbor.controller.settings)
    case .openLog: break
    case .quit: quitRequested = true
    case .submenu, .nothing: break
    }
  }
}
