import CoreGraphics

/// The character cells one window's app sizes it in, where that has shown. A terminal is a title bar, a margin and a whole number of
/// cells, so it never has quite the size it is asked for: it takes the cells nearest to it, which half the time is more.
///
/// Nobody can ask an app for its cell, and most of what looks like one is something else: a least size that holds while a sheet is
/// open, an app that takes a size a moment late. So only one thing is believed, and it is over in a few milliseconds
/// (`Controller.askForLess`): the window took MORE than it was asked for; asked for less, it took less than it had, which one
/// that has a least size does not do; and asked for a point less than that, it did not budge, which one that takes any size does
/// not do. The step it came down by is its cell, and where it stopped is on its grid.
public struct Cells: Equatable, Sendable {
  /// Width or height.
  public struct Side: Equatable, Sendable {
    /// The cell; 0 while it has not shown.
    public var cell: CGFloat = 0
    /// A length the window has had with these cells.
    public var on: CGFloat = 0

    public init() {}

    public init(cell: CGFloat, on: CGFloat) {
      guard cell.isFinite, on.isFinite, (Cells.smallest...Cells.largest).contains(cell), on > 0 else { return }
      (self.cell, self.on) = (cell, on)
    }

    public var isKnown: Bool { cell > 0 }

    func isOnTheGrid(_ length: CGFloat) -> Bool {
      let cells = (length - on) / cell
      return abs(cells - cells.rounded()) * cell < 0.5
    }

    /// How long the window becomes when it is to fill `length`: the whole cells that fit, which it takes as they are. Nil while the cell
    /// is not known. A point or two over any window may be, and that is where an app that takes the nearest cells is left while
    /// nothing is known of them. So it is the same afterwards: one slot, one frame, whatever Arbor happens to know.
    func wholeCells(in length: CGFloat) -> CGFloat? {
      guard isKnown, length.isFinite else { return nil }
      let fits = on + ((length + Cells.slack - on + 0.01) / cell).rounded(.down) * cell
      return fits > 0 ? fits : nil
    }

    /// Whether a window this much shorter than its slot has filled it as far as its app lets it. An app that takes the nearest cells is half
    /// a cell short at most until its cell has shown, so for such a one this never changes with what is known.
    public func explains(short: CGFloat) -> Bool { short < (isKnown ? cell : Cells.largestUnknown) }

    /// The window is seen to be this long, whoever made it so. That teaches nothing, for a hand is no rounding, but it can show that what
    /// was learnt holds no longer: a terminal is never seen between two cells, until its font changes or it gets a bar of tabs. Nothing
    /// else would show it: all that is asked of it is on its grid.
    mutating func see(_ length: CGFloat) {
      if isKnown, !isOnTheGrid(length) { self = Side() }
    }
  }

  /// A difference that is no refusal: apps round.
  static let slack: CGFloat = 2
  /// Less is any app's rounding, not a cell.
  static let smallest: CGFloat = 3
  /// No cell is larger than this: characters at a very large font.
  public static let largest: CGFloat = 36
  /// What passes for a cell while nothing is known of it.
  public static let largestUnknown: CGFloat = 20

  public var width = Side()
  public var height = Side()

  public init() {}

  /// The window was asked for the whole cells that fit, and this is what it took. It takes them as they are: that is what knowing its
  /// cell means. Where it took anything else what was known holds no longer (another font), and is forgotten. Returns true if so.
  public mutating func forgetUnless(asked: CGSize, wasTakenAs took: CGSize) -> Bool {
    let before = self
    if width.isKnown, abs(took.width - asked.width) > 0.5 { width = Side() }
    if height.isKnown, abs(took.height - asked.height) > 0.5 { height = Side() }
    return self != before
  }

  /// The window is seen at this size, whoever gave it that.
  public mutating func see(_ size: CGSize) {
    width.see(size.width)
    height.see(size.height)
  }

  /// What to ask for so that the window fills a slot of `size` and does not reach out of it: the slot's own size, except where the
  /// cell is known. Worked out from the slot every time, never from the size the window happens to have.
  public func fitting(_ size: CGSize) -> CGSize {
    CGSize(width: width.wholeCells(in: size.width) ?? size.width, height: height.wholeCells(in: size.height) ?? size.height)
  }
}
