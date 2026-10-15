import CoreGraphics

/// Arbor's mark: a split layout that grows like a tree. The right column is whole (the trunk), the
/// left column is split in two (a branch), and its upper half is split again (two leaves).
///
/// The menu bar draws it as a template image, and the app icon draws it in white on green.
/// `scripts/make-icon.swift` cannot import this module, so it repeats `cells`; keep the two in step.
public enum ArborGlyph {
  /// The left column's share of the width, and the leaves' share of the height.
  static let leftShare: CGFloat = 0.54
  static let leafShare: CGFloat = 0.44

  /// The size of the mark among the menu bar item's buttons, and on its own, in points. Even numbers,
  /// so that it sits on whole points when centred in a cell or a menu bar of even size.
  public static let buttonSize = CGSize(width: 14, height: 12)
  public static let iconSize = CGSize(width: 18, height: 14)

  /// Where a sign of `size` that stands in for the mark (a lock, a warning) is drawn in the single icon's image, which is `iconSize`
  /// whatever it shows: an item that changes its width pushes its neighbours about in the menu bar. In the middle, on whole
  /// points if it fits; made smaller, in its own proportions, if it does not; never larger.
  public static func place(ofSign size: CGSize) -> CGRect {
    guard size.width > 0, size.height > 0 else { return CGRect(x: iconSize.width / 2, y: iconSize.height / 2, width: 0, height: 0) }
    let scale = min(iconSize.width / size.width, iconSize.height / size.height, 1)
    let (width, height) = (size.width * scale, size.height * scale)
    // Rounded down: rounded up, a sign nearly as large as the image would be pushed over its far edge.
    return CGRect(
      x: ((iconSize.width - width) / 2).rounded(.down), y: ((iconSize.height - height) / 2).rounded(.down), width: width, height: height)
  }

  /// How opaque the app icon draws each cell, in the order of `cells`: the further out, the lighter.
  /// The menu bar draws every cell solid; at that size shades only look blurred.
  public static let opacities: [CGFloat] = [1, 0.92, 0.8, 0.68]

  /// The rectangles of the mark inside `rect`, `gap` apart: the trunk, the branch, then the
  /// leaves from left to right. Give `rect` and `gap` in whole units (points or pixels) and the
  /// cells come out in whole units too, so their edges stay sharp.
  /// - Parameters:
  ///   - leaves: false leaves the upper left cell whole, for sizes where two leaves would be specks.
  ///   - yUp: true when y grows upward where the cells are drawn (AppKit, CoreGraphics), false when
  ///     it grows downward like the rest of ArborCore. The leaves are at the top either way.
  public static func cells(in rect: CGRect, gap: CGFloat, leaves: Bool = true, yUp: Bool = false) -> [CGRect] {
    // The leaves come first, so that both get the same width; the trunk takes what is left.
    let leafWidth = max((((rect.width - gap) * leftShare - gap) / 2).rounded(), 0)
    let leftWidth = leafWidth * 2 + gap
    let leafHeight = max(((rect.height - gap) * leafShare).rounded(), 0)
    let branchHeight = rect.height - gap - leafHeight
    let leafY = yUp ? rect.maxY - leafHeight : rect.minY
    let branchY = yUp ? rect.minY : rect.maxY - branchHeight

    var cells = [
      CGRect(
        x: rect.minX + leftWidth + gap, y: rect.minY, width: rect.width - leftWidth - gap, height: rect.height),
      CGRect(x: rect.minX, y: branchY, width: leftWidth, height: branchHeight),
    ]
    if leaves {
      cells.append(CGRect(x: rect.minX, y: leafY, width: leafWidth, height: leafHeight))
      cells.append(CGRect(x: rect.minX + leafWidth + gap, y: leafY, width: leafWidth, height: leafHeight))
    } else {
      cells.append(CGRect(x: rect.minX, y: leafY, width: leftWidth, height: leafHeight))
    }
    return cells
  }
}
