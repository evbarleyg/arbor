/// Which row of the window finder's list is selected, and which rows show when the list is longer
/// than the palette. The palette and the tests' stand-in for it share this, so arrow keys, Tab and ⌘1–9
/// mean the same in both.
public struct FinderSelection: Equatable, Sendable {
  /// How many rows the list has.
  public private(set) var count: Int
  /// How many rows show at once; at least one.
  public let pageSize: Int
  /// The selected row. Zero, and meaningless, while the list is empty: see `selected`.
  public private(set) var index = 0
  /// The first row that shows.
  public private(set) var top = 0

  /// Far more than any list or palette has; it keeps the sums below from overflowing whatever is passed in.
  private static let limit = 1_000_000

  public init(count: Int, pageSize: Int = 9) {
    self.count = min(max(count, 0), Self.limit)
    self.pageSize = min(max(pageSize, 1), Self.limit)
  }

  /// The selected row, or nil while the list is empty.
  public var selected: Int? { count > 0 ? index : nil }

  /// The rows that show.
  public var visible: Range<Int> { top..<min(top + pageSize, count) }

  /// Moves the selection down (or, negative, up) by `rows`, going round at the ends.
  public mutating func move(by rows: Int) {
    guard count > 0 else { return }
    // Reduced first, so that no number of rows overflows.
    select((index + rows % count + count) % count)
  }

  /// Moves the selection by whole pages, stopping at the ends.
  public mutating func page(by pages: Int) {
    guard count > 0 else { return }
    select(index + min(max(pages, -count), count) * pageSize)
  }

  /// Selects a row, or the nearest there is, and scrolls just far enough to show it.
  public mutating func select(_ row: Int) {
    index = min(max(row, 0), max(count - 1, 0))
    if index < top { top = index }
    if index >= top + pageSize { top = index - pageSize + 1 }
  }

  /// The row showing at `place` from the top of the palette, counted from 0. Nil if nothing shows there.
  public func row(atVisible place: Int) -> Int? {
    guard place >= 0, place < visible.count else { return nil }
    return top + place
  }

  /// The list changed length: keeps the selected row if it still exists, otherwise takes the last.
  public mutating func resize(to newCount: Int) {
    count = min(max(newCount, 0), Self.limit)
    top = min(top, max(count - pageSize, 0))
    select(index)
  }
}
