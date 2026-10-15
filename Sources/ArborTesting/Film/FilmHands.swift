import ArborCore
import ArborKit
import CoreGraphics

/// Arbor's menu while it is open, as macOS would lay it out: the rows of `Controller.menuModel()`, one under the other.
public struct FilmMenu: Equatable {
  public enum Kind: String { case header, separator, item }

  public struct Row: Equatable {
    public var kind: Kind
    public var title = ""
    /// The shortcut at the right of the row: ⌃⌥Space.
    public var shortcut: String?
    public var isEnabled = true
    public var isTicked = false
    public var opensSubmenu = false
    /// It cannot be chosen and is drawn at full strength all the same (`MenuModel.Item.isNews`).
    public var isNews = false
    /// Global coordinates.
    public var frame = CGRect.zero
    var action: MenuModel.Item.Action?
  }

  public var frame: CGRect
  public var rows: [Row]
  /// The row under the pointer, if it can be chosen.
  public var highlighted: Int?

  /// What macOS gives a menu in the system font. A heading is as high as a row.
  static let rowHeight = CGFloat(MenuModel.Metrics.macOS26.row)
  static let separatorHeight = CGFloat(MenuModel.Metrics.macOS26.separator)
  static let padding = CGFloat(MenuModel.Metrics.macOS26.padding)
  static let width: CGFloat = 300

  /// The menu hanging from `item` in the menu bar, kept on `screen`.
  init(_ model: MenuModel, under item: CGRect, on screen: CGRect) {
    var rows: [Row] = []
    for (index, section) in model.sections.enumerated() {
      if index > 0 { rows.append(Row(kind: .separator)) }
      if let title = section.title { rows.append(Row(kind: .header, title: title, isEnabled: false)) }
      for item in section.items {
        var opensSubmenu = false
        if case .submenu = item.action { opensSubmenu = true }
        rows.append(
          Row(
            kind: .item, title: item.title, shortcut: item.showsShortcut ? item.shortcut?.label : nil,
            isEnabled: item.isEnabled, isTicked: item.isTicked, opensSubmenu: opensSubmenu, isNews: item.isNews, action: item.action))
      }
    }
    let x = min(item.minX, screen.maxX - Self.width - 8)
    var y = item.maxY + 1 + Self.padding
    for index in rows.indices {
      let height = rows[index].kind == .separator ? Self.separatorHeight : Self.rowHeight
      rows[index].frame = CGRect(x: x, y: y, width: Self.width, height: height)
      y += height
    }
    self.rows = rows
    frame = CGRect(x: x, y: item.maxY + 1, width: Self.width, height: y + Self.padding - item.maxY - 1)
  }

  func row(at point: CGPoint) -> Int? {
    rows.firstIndex { $0.kind == .item && $0.isEnabled && !$0.opensSubmenu && $0.frame.contains(point) }
  }
}

/// The person in a film: a pointer with a button, a keyboard, and what macOS makes of them before Arbor hears of it. A press
/// on a title bar brings the window forward and gives it the keyboard; moving on carries the window along; a press on
/// Arbor's menu bar item opens its menu. The order of the reports is the Accessibility layer's.
///
/// What is modelled is what a film needs. The fake Mac behind `scripts/mac-shell/rehearse.sh` (`Sources/arbor-fakemac`, `World+Input.swift`) knows more of
/// macOS and nothing of time; where the two model the same thing they are meant to agree, and one day should share it.
@MainActor
public final class FilmHands {
  private enum Held {
    case nothing
    case title(WindowID, grip: CGSize, moved: Bool)
    case seam(Seam, last: CGPoint)
    case tile(NodeID)
    case minimap
    case paletteRow(Int)
    case statusItem
    case menuRow(Int)
  }

  private let harness: Harness
  private var system: FakeWindowSystem { harness.system }
  private var held = Held.nothing
  /// The shortcuts held down, oldest first, as they were written.
  public private(set) var chords: [KeyChord] = []
  /// A plain key that is down to type with: a letter in Go to…, ↩, ⎋.
  public var typingKey: String?
  public private(set) var menu: FilmMenu?
  /// Whether Arbor's item is in the menu bar: from launch to quit.
  public var arborIsInTheMenuBar = false
  /// What the other items at the right of the menu bar take, in points. Arbor's is left of them.
  public var menuBarReserve: CGFloat = 200
  /// How much of a window's top is its title bar.
  public var titleBarHeight: CGFloat = 28
  /// Called when Quit Arbor is chosen.
  public var onQuit: () -> Void = {}
  /// The reply to the command the button last set off (a button of the menu bar item, a row of the menu), if it set one off.
  public private(set) var pointerResult: CommandResult?
  /// What the button last went down on, in a few words: a script that misses its window should be able to see that.
  public private(set) var landedOn = "nothing"

  public init(_ harness: Harness) { self.harness = harness }

  public var pointer: CGPoint { system.cursor }
  public var isButtonDown: Bool { system.mouseDown }
  private var display: DisplaySnapshot { system.displayList[0] }

  // MARK: The menu bar item

  /// The row of buttons, as `StatusMenu.show` lays it out. Nil while the item is a single icon.
  public var statusItemLayout: MenuBarLayout? {
    let model = harness.controller.menuBarModel()
    return model.buttons.isEmpty ? nil : MenuBarLayout(model)
  }

  /// macOS puts 8 points around the image of the buttons; the single icon's item was measured 26 points wide.
  public var statusItemFrame: CGRect {
    let width = statusItemLayout.map { $0.size.width + 16 } ?? 26
    return CGRect(
      x: display.frame.maxX - menuBarReserve - width,
      y: display.frame.minY + ((display.visibleFrame.minY - display.frame.minY - 22) / 2).rounded(.down), width: width,
      height: 22)
  }

  /// The middle of one of the item's buttons (`menu`, `everything`, `back`…), or of the item.
  public func statusItemSpot(_ name: String?) -> CGPoint? {
    let frame = statusItemFrame
    guard let name, let layout = statusItemLayout else { return name == nil || name == "menu" ? frame.center : nil }
    guard let index = layout.buttons.firstIndex(where: { $0.id.description == name }) else { return nil }
    return CGPoint(x: frame.minX + (frame.width - layout.size.width) / 2 + layout.cells[index].midX, y: frame.midY)
  }

  private func openMenu() {
    var opened = FilmMenu(harness.controller.menuModel(), under: statusItemFrame, on: display.frame)
    opened.highlighted = opened.row(at: pointer)
    menu = opened
  }

  /// The middle of the row with this title in the open menu.
  public func menuSpot(_ title: String) -> CGPoint? {
    menu?.rows.first { $0.kind == .item && $0.title == title }.map { CGPoint(x: $0.frame.minX + 210, y: $0.frame.midY + 3) }
  }

  private func choose(_ row: FilmMenu.Row) {
    menu = nil
    switch row.action {
    case .run(let command):
      pointerResult = harness.controller.perform(command, from: .menu)
      system.reportFocus()
    case .app(.quit):
      onQuit()
    default:
      break
    }
  }

  // MARK: The pointer

  /// The frontmost window at `point`.
  public func window(at point: CGPoint) -> WindowID? {
    system.windowsFrontToBack().first { id in
      guard let snapshot = system.windows[id]?.snapshot, snapshot.isPresent else { return false }
      return snapshot.frame.contains(point)
    }
  }

  /// A point of `window` that a person can see and reach: on the display, with no other window and nothing of Arbor's that takes
  /// clicks in front. In `titleBar`, a point to drag it by, clear of its three buttons. The nearest to the middle there is; nil if all
  /// of it is covered or out of view.
  public func reachableSpot(of window: WindowID, titleBar: Bool = false) -> CGPoint? {
    guard let frame = system.frame(of: window) else { return nil }
    let shares: [CGFloat] = [0.5, 0.4, 0.6, 0.3, 0.7, 0.2, 0.8, 0.1, 0.9]
    let rows: [CGFloat] = titleBar ? [(titleBarHeight / 2).rounded()] : shares.map { titleBarHeight + (frame.height - titleBarHeight) * $0 }
    var spots: [CGPoint] = []
    for y in rows { for x in shares { spots.append(CGPoint(x: frame.minX + frame.width * x, y: frame.minY + y)) } }
    func distance(_ point: CGPoint) -> CGFloat { hypot(point.x - frame.midX, point.y - frame.midY) }
    return spots.filter { point in
      display.visibleFrame.contains(point) && self.window(at: point) == window && !isUnderAPanel(point)
        && (!titleBar || point.x - frame.minX > 76)
    }.min { distance($0) < distance($1) }
  }

  /// Whether a press at `point` would be Arbor's rather than a window's: what `land(at:)` asks before it asks for a window. While the
  /// menu is open every press is the menu's.
  private func isUnderAPanel(_ point: CGPoint) -> Bool {
    let overlays = harness.overlays
    if menu != nil || overlays.finder?.layout.panel.contains(point) == true { return true }
    if let model = overlays.minimaps[display.id], model.takesClicks, model.frame.contains(point) { return true }
    return false
  }

  /// The gap handle at `point`, where no window covers it.
  public func seam(at point: CGPoint) -> Seam? {
    guard menu == nil, window(at: point) == nil else { return nil }
    return harness.overlays.seams[display.id]?.first { $0.frame.contains(point) }
  }

  /// The middle of the gap that `first` and `second` have between them, side by side or one above the other, where both border on it.
  /// Nil if they are no neighbours, or something lies over that point.
  public func gapSpot(between first: WindowID, and second: WindowID) -> CGPoint? {
    guard let a = system.frame(of: first), let b = system.frame(of: second) else { return nil }
    for seam in harness.overlays.seams[display.id] ?? [] {
      let gap = seam.frame
      let spot: CGPoint
      if seam.axis == .horizontal {
        guard abs(min(a.maxX, b.maxX) - gap.minX) < 1, abs(max(a.minX, b.minX) - gap.maxX) < 1 else { continue }
        spot = CGPoint(x: gap.midX, y: (max(a.minY, b.minY, gap.minY) + min(a.maxY, b.maxY, gap.maxY)) / 2)
      } else {
        guard abs(min(a.maxY, b.maxY) - gap.minY) < 1, abs(max(a.minY, b.minY) - gap.maxY) < 1 else { continue }
        spot = CGPoint(x: (max(a.minX, b.minX, gap.minX) + min(a.maxX, b.maxX, gap.maxX)) / 2, y: gap.midY)
      }
      if gap.contains(spot), self.seam(at: spot) != nil, !isUnderAPanel(spot) { return spot }
    }
    return nil
  }

  /// The gap between the same two neighbours as `seam`, where it is now: it moves with every step of a drag.
  private func current(_ seam: Seam) -> Seam {
    harness.overlays.seams[display.id]?.first {
      $0.split == seam.split && $0.leading == seam.leading && $0.trailing == seam.trailing
    } ?? seam
  }

  /// The gap handle that is being dragged.
  public var draggedSeam: Seam? {
    if case .seam(let seam, _) = held { return current(seam) }
    return nil
  }

  /// No Mac lets the pointer leave the screen: a script that aims at a window that is out of view ends up at the edge.
  private func onScreen(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, display.frame.minX), display.frame.maxX - 1),
      y: min(max(point.y, display.frame.minY), display.frame.maxY - 1))
  }

  public func move(to target: CGPoint) {
    let point = onScreen(target)
    system.cursor = point
    switch held {
    case .title(let window, let grip, let moved):
      guard var frame = system.frame(of: window) else { return }
      // The window server does not let a title bar go under the menu bar.
      frame.origin = CGPoint(x: point.x - grip.width, y: max(point.y - grip.height, display.visibleFrame.minY))
      // The first move with the button down is what tells the Accessibility layer that a drag began.
      if !moved {
        var grip = grip
        // Dragged off the tile macOS put it in, a window has its own size again, under the hand as before.
        if let own = system.takeSizeBeforeTile(of: window) {
          grip.width = (grip.width * own.width / max(frame.width, 1)).rounded()
          frame = CGRect(x: point.x - grip.width, y: frame.minY, width: own.width, height: own.height)
        }
        system.events?.dragBegan(window, at: point)
        held = .title(window, grip: grip, moved: true)
      }
      system.userMove(window, to: frame)
      system.events?.dragMoved(window, to: point)
    case .seam(let seam, let last):
      let delta = seam.axis == .horizontal ? point.x - last.x : point.y - last.y
      held = .seam(seam, last: point)
      if delta != 0 { harness.overlays.dragSeam(current(seam), by: delta, on: display.id) }
    default:
      let row = menu?.row(at: point)
      menu?.highlighted = row
    }
  }

  public func press() {
    held = .nothing
    pointerResult = nil
    system.mouseDown = true
    land(at: pointer)
  }

  /// What the press lands on, from front to back. Whatever that is, the Accessibility layer's monitor of the mouse reports the press.
  private func land(at point: CGPoint) {
    let overlays = harness.overlays
    if let menu {
      // A press beside an open menu closes it and does nothing else; one on a row that is greyed out leaves it open.
      if let row = menu.row(at: point) {
        held = .menuRow(row)
        landedOn = "the menu's \(menu.rows[row].title)"
      } else if menu.frame.contains(point) {
        landedOn = "nothing to choose in the menu"
      } else {
        self.menu = nil
        landedOn = "nothing: the menu closes"
      }
      return system.click()
    }
    // Any click puts the panel of shortcuts away, and goes on to whatever is under it.
    if overlays.cheatSheets[display.id] != nil { overlays.dismissCheatSheet() }
    if arborIsInTheMenuBar, statusItemFrame.contains(point) {
      overlays.dismissFinder()
      landedOn = "Arbor's menu bar item"
      // A single icon has the menu attached, which opens as the button goes down; the buttons act as it comes up.
      if statusItemLayout == nil { openMenu() } else { held = .statusItem }
      return system.click()
    }
    if let palette = overlays.finder {
      let layout = palette.layout
      if layout.panel.contains(point) {
        let inList = CGPoint(x: point.x - layout.panel.minX - layout.list.minX, y: point.y - layout.panel.minY - layout.list.minY)
        held = layout.row(at: inList).map { .paletteRow($0) } ?? .nothing
        landedOn = "Go to…"
        return system.click()
      }
      // A click anywhere else closes it, and is a click there all the same.
      overlays.dismissFinder()
    }
    if let model = overlays.minimaps[display.id], model.takesClicks, model.frame.contains(point) {
      held = .minimap
      landedOn = "the minimap"
      return system.click()
    }
    if let window = window(at: point), let frame = system.frame(of: window) {
      // With ⌘ down macOS moves a window by its title bar without bringing it forward or giving it the keyboard.
      if modifiers.contains(.command), point.y - frame.minY < titleBarHeight { system.click() } else { system.userClick(window, release: false) }
      landedOn = "\(window)"
      if point.y - frame.minY < titleBarHeight {
        held = .title(window, grip: CGSize(width: point.x - frame.minX, height: point.y - frame.minY), moved: false)
        landedOn = "the title bar of \(window)"
      }
      return
    }
    if let tile = overlays.tiles[display.id]?.first(where: { $0.frame.contains(point) }) {
      held = .tile(tile.node)
      landedOn = "the tile of \(tile.node)"
    } else if let seam = seam(at: point) {
      held = .seam(seam, last: point)
      landedOn = "a gap"
    } else if point.y >= display.visibleFrame.minY {
      // The bare Desktop is Finder's, which takes the keyboard. (What macOS's "click wallpaper to reveal desktop" does then is not modelled.)
      landedOn = "the Desktop"
      system.userFocusesNothing()
    } else {
      landedOn = "the menu bar"
    }
    system.click()
  }

  public func lift() {
    let released = held
    held = .nothing
    system.releaseMouse()
    switch released {
    case .title(let window, _, let moved):
      guard moved else { break }
      // Arbor hears of the release first; then macOS does what its own tiling does with a window let go here.
      let letGo = system.frame(of: window)
      system.events?.dragEnded(window, at: pointer)
      if let letGo { system.letMacOSTile(window, letGoAt: letGo) }
    case .tile(let node):
      harness.overlays.clickTile(node, on: display.id)
    case .minimap:
      if let frame = harness.overlays.minimaps[display.id]?.frame, frame.contains(pointer) {
        harness.overlays.clickMinimap(at: CGPoint(x: pointer.x - frame.minX, y: pointer.y - frame.minY), on: display.id)
      }
    case .paletteRow(let row):
      harness.overlays.chooseInFinder(row: row + 1)
    case .statusItem:
      guard let layout = statusItemLayout, statusItemFrame.contains(pointer) else { return }
      let origin = statusItemFrame.minX + (statusItemFrame.width - layout.size.width) / 2
      switch layout.click(atX: pointer.x - origin, secondary: false) {
      case .menu: openMenu()
      case .nothing: break
      case .run(let command):
        pointerResult = harness.controller.perform(command, from: .menu)
        system.reportFocus()
      }
    case .menuRow(let index):
      if let menu, menu.row(at: pointer) == index { choose(menu.rows[index]) }
    case .nothing, .seam:
      break
    }
  }

  // MARK: The keyboard

  /// Presses a shortcut and keeps it down. Returns the reply of the command it ran, if it ran one.
  @discardableResult
  public func keyDown(_ chord: KeyChord) -> CommandResult? {
    // An open menu has the keyboard. What macOS does with a global shortcut meanwhile is not known, so a film does not show it.
    guard menu == nil else { return .failure("Arbor's menu is open and takes the keys: choose from it, or `tap escape`") }
    // With another modifier key down these keys are another shortcut, or none.
    guard chord.modifiers.isSuperset(of: modifiers) else { return .failure("a modifier key that is no part of \(chord.label) is held") }
    chords.append(chord)
    let result = harness.keyDown(chord.text)
    // A key that is nobody's shortcut goes to the panel of shortcuts, which any key puts away.
    if result == nil, harness.overlays.cheatSheets[display.id] != nil { harness.overlays.dismissCheatSheet() }
    return result
  }

  public func keyUp(_ chord: KeyChord) {
    guard chords.contains(chord) else { return }
    chords.removeAll { $0 == chord }
    harness.keyUp(chord.text)
    tellWhichModifiersAreDown()
  }

  /// Modifier keys that are held down by themselves, as somebody holds ⌘ while they drag.
  public private(set) var modifiers: KeyChord.Modifiers = []

  /// Presses and lets go of modifier keys until exactly these are held by themselves.
  public func hold(_ modifiers: KeyChord.Modifiers) {
    guard modifiers != self.modifiers else { return }
    self.modifiers = modifiers
    tellWhichModifiersAreDown()
    // A modifier key is input like a click. During a drag the Accessibility layer reports it as a move to the same point.
    let before = system.secondsSinceInput
    system.secondsSinceInput = 0
    defer { system.secondsSinceInput = before }
    if case .title(let window, _, moved: true) = held { system.events?.dragMoved(window, to: pointer) }
  }

  /// What macOS answers when it is asked which modifier keys are down: the ones held by themselves and those of every shortcut that
  /// is held. The stand-in forgets all of them when the last key of a shortcut comes up.
  private func tellWhichModifiersAreDown() {
    system.heldModifiers = chords.reduce(modifiers) { $0.union($1.modifiers) }
  }

  /// ⎋ with the menu open.
  public func closeMenu() { menu = nil }
}
