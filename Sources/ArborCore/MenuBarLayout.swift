import CoreGraphics

/// Where the buttons of a `MenuBarModel` sit in the one image the menu bar item shows, and which of
/// them a click lands on. x grows to the right from the image's left edge; every cell is as tall as
/// the image, so nothing here depends on which way y grows.
public struct MenuBarLayout: Equatable, Sendable {
  /// The width of a button's cell. Glyphs are about 16 points wide, centred in it.
  public static let pitch: CGFloat = 22
  /// The image's height. It fits the shortest menu bar (24 points), so AppKit never scales the image,
  /// which would move the glyphs away from where `button(atX:)` expects them.
  public static let height: CGFloat = 22
  /// Extra space between history, places, saved views and the menu button, so the row reads as groups.
  public static let groupGap: CGFloat = 4
  /// The corner radius of the background of a current button.
  public static let chipRadius: CGFloat = 5

  public let buttons: [MenuBarModel.Button]
  /// One cell per button, in the same order.
  public let cells: [CGRect]

  public init(_ model: MenuBarModel) {
    var cells: [CGRect] = []
    var x: CGFloat = 0
    var previousGroup: Int?
    for button in model.buttons {
      let group = Self.group(of: button.id)
      if let previousGroup, previousGroup != group { x += Self.groupGap }
      cells.append(CGRect(x: x, y: 0, width: Self.pitch, height: Self.height))
      x += Self.pitch
      previousGroup = group
    }
    buttons = model.buttons
    self.cells = cells
  }

  private static func group(of id: MenuBarModel.Button.ID) -> Int {
    switch id {
    case .back, .forward: 0
    case .desktop, .everything: 1
    case .view: 2
    case .menu: 3
    }
  }

  /// The size of the image. Zero wide without buttons.
  public var size: CGSize { CGSize(width: cells.last?.maxX ?? 0, height: Self.height) }

  /// The background of a current button: its cell, with a little air around it.
  public static func chip(in cell: CGRect) -> CGRect { cell.insetBy(dx: 1, dy: 2) }

  /// The index of the button at `x`. The gaps between groups, and the padding macOS puts around
  /// the image (x below zero or beyond the width), belong to the nearest button, so no part of the
  /// menu bar item is dead. Nil only when there are no buttons.
  public func index(atX x: CGFloat) -> Int? {
    func distance(_ cell: CGRect) -> CGFloat { max(cell.minX - x, 0, x - cell.maxX) }
    return cells.indices.min { distance(cells[$0]) < distance(cells[$1]) }
  }

  public func button(atX x: CGFloat) -> MenuBarModel.Button? { index(atX: x).map { buttons[$0] } }

  /// What a click does.
  public enum Click: Equatable, Sendable {
    case run(Command)
    /// Open the full menu.
    case menu
    /// The button under the pointer is disabled.
    case nothing
  }

  /// - Parameter secondary: a right click, or a click with ⌃ or ⌥ held.
  public func click(atX x: CGFloat, secondary: Bool) -> Click {
    guard !secondary, let button = button(atX: x), let command = button.command else { return .menu }
    return button.isEnabled ? .run(command) : .nothing
  }
}
