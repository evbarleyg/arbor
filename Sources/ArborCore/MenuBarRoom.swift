import CoreGraphics

/// Whether the menu bar has room for Arbor's item. macOS silently leaves out the status items that do not fit, which on a
/// MacBook with a notch and a full menu bar happens early, and Arbor's row of buttons is wide: 118 points with no
/// saved view, 320 with nine. An item that is left out is Arbor without a face, so Arbor falls back to its single icon,
/// which has the best chance of fitting and opens the whole menu.
///
/// The app can only ask macOS whether the item is showing, and nobody has seen what it answers on every macOS. So its word
/// counts only after it has once said "showing" on this Mac: an answer that is always "no" takes nobody's buttons away.
public struct MenuBarRoom: Equatable, Sendable {
  /// What macOS last said. Nil if it cannot be told (the menu bar hides itself, there is no item).
  public private(set) var isShowing: Bool?
  /// macOS has said "showing" at least once.
  public private(set) var hasBeenSeen = false
  /// The narrowest item that was found left out.
  public private(set) var tooWide: CGFloat?

  public init() {}

  /// What macOS says about the item a moment after it was drawn `width` points wide.
  public mutating func observe(width: CGFloat, isShowing: Bool?) {
    self.isShowing = isShowing
    guard let isShowing else { return }
    if isShowing {
      hasBeenSeen = true
      // There is room for this much after all.
      if let limit = tooWide, width >= limit { tooWide = nil }
    } else if hasBeenSeen, width > ArborGlyph.iconSize.width {
      tooWide = min(tooWide ?? .infinity, width)
    }
  }

  /// Whether an item this wide is worth drawing. Anything narrower than what was left out is tried.
  public func fits(_ width: CGFloat) -> Bool { tooWide.map { width < $0 } ?? true }

  /// The menu bar may have changed (another display, other settings): everything is tried again.
  public mutating func forget() { tooWide = nil }
}
