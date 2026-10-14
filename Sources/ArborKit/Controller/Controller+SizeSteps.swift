import ArborCore
import CoreGraphics

/// Windows that come in steps. Terminal sizes its windows in whole character cells and takes the size
/// nearest to the one it is asked for, which half the time is the larger one: asked for 624 × 947 it took
/// 621 × 954. Seven points too tall is not a window that
/// refuses its slot, but it was read as one, so pressing ⌘+ in a docked Terminal turned it into a tile.
extension Controller {
  /// No step is larger than this: character cells at a very large font.
  private static let largestStep: CGFloat = 36

  /// Called when `window` was offered `slot` and `took` another frame. If it came out a little larger than
  /// the slot, asks for less, and less again, until it takes the step below. Returns the frame it ended
  /// at. A window that stays too large has a real minimum, and the caller learns it as before.
  func askForLess(_ window: WindowID, slot: CGRect, took: CGRect) -> CGRect {
    var took = took
    var less = CGSize.zero
    // An app that takes the nearest step gives way once it is asked for half a step less, one that rounds up once
    // it is asked for a whole step less. The step is unknown, so what is held back doubles, up to the largest
    // step there is: a window that was asked for that much less and did not budge has a real minimum.
    for _ in 0..<4 {
      let over = CGSize(width: took.width - slot.width, height: took.height - slot.height)
      guard over.width > 2 || over.height > 2, max(over.width, over.height) <= Self.largestStep else { break }
      let before = less
      if over.width > 2 { less.width = min(max(less.width, over.width) * 2, Self.largestStep) }
      if over.height > 2 { less.height = min(max(less.height, over.height) * 2, Self.largestStep) }
      guard less != before else { break }
      let request = CGRect(
        x: slot.minX, y: slot.minY, width: max(slot.width - less.width, 1), height: max(slot.height - less.height, 1))
      guard let next = system.setFrame(request, of: window) else { break }
      took = next
    }
    return took
  }
}
