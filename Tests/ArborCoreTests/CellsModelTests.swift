import ArborCore
import CoreGraphics
import Testing

/// What is made of a window's character cells once they have shown (`Cells`). How they show is the controller's: `CellsTests`.
@Suite struct CellsModelTests {
  func cells(width: Cells.Side = Cells.Side(), height: Cells.Side = Cells.Side()) -> Cells {
    var cells = Cells()
    (cells.width, cells.height) = (width, height)
    return cells
  }

  @Test func ofAWindowOfWhichNothingIsKnownTheSlotIsAsked() {
    #expect(!Cells().width.isKnown)
    #expect(Cells().fitting(CGSize(width: 613, height: 401)) == CGSize(width: 613, height: 401))
  }

  /// The figures of a real Terminal: cells of 7 by 15 points beside a margin of 2 by 4.
  @Test func whatIsAskedForIsTheWholeCellsThatFit() {
    let known = cells(width: Cells.Side(cell: 7, on: 247), height: Cells.Side(cell: 15, on: 649))
    #expect(known.fitting(CGSize(width: 858, height: 947)) == CGSize(width: 856, height: 949), "122 and 63 cells; two points over are allowed")
    #expect(known.fitting(CGSize(width: 853, height: 946)) == CGSize(width: 849, height: 934))
    #expect(known.fitting(CGSize(width: 247, height: 649)) == CGSize(width: 247, height: 649))
    #expect(known.fitting(CGSize(width: 100, height: 100)) == CGSize(width: 100, height: 94), "below where it was seen as well")
  }

  @Test(arguments: Array(stride(from: CGFloat(3), through: 36, by: 0.5)), [CGFloat(0), 2, 39.5])
  func itIsOnTheGridFitsAndGivesNoCellAway(cell: CGFloat, margin: CGFloat) {
    let side = Cells.Side(cell: cell, on: margin + 40 * cell)
    for slot in stride(from: CGFloat(300), through: 380, by: 1) {
      let asked = cells(width: side).fitting(CGSize(width: slot, height: 100)).width
      let count = (asked - margin) / cell
      #expect(abs(count - count.rounded()) < 0.001, "\(asked) is whole cells")
      // The two points over that any window is allowed, and that it is left at while nothing is known of its cells.
      #expect(asked <= slot + 2.01 && slot + 2 - asked < cell, "\(asked) for a slot of \(slot)")
    }
  }

  @Test func widthAndHeightAreKeptApart() {
    let known = cells(height: Cells.Side(cell: 15, on: 840))
    #expect(known.fitting(CGSize(width: 463, height: 851)) == CGSize(width: 463, height: 840))
  }

  // MARK: What ends it

  /// A terminal is never seen between two cells. Whoever is has another font by now, or a bar of tabs.
  @Test func seenBetweenTwoCellsEndsIt() {
    let known = cells(width: Cells.Side(cell: 7, on: 854), height: Cells.Side(cell: 15, on: 840))
    var seen = known
    seen.see(CGSize(width: 854 + 70, height: 840 - 45))
    #expect(seen == known, "pulled by a hand, by whole cells: nothing is learnt and nothing forgotten")
    seen.see(CGSize(width: 854 + 72, height: 840))
    #expect(seen == cells(height: known.height), "each way by itself")
    seen.see(CGSize(width: 900, height: 871))
    #expect(seen == Cells(), "Terminal's bar of tabs is 31 points high")
  }

  /// An app that was only slow, three times in a row, is seen a moment later at the point less it was asked for.
  @Test func aPointBesideTheGridIsBesideIt() {
    var seen = cells(width: Cells.Side(cell: 30, on: 610))
    seen.see(CGSize(width: 609, height: 100))
    #expect(seen == Cells())
  }

  /// It takes the whole cells it is asked for as they are: that is what knowing its cell means, and what can be seen to fail.
  @Test func askedForWholeCellsAndTakingSomethingElseEndsIt() {
    let known = cells(width: Cells.Side(cell: 7, on: 854), height: Cells.Side(cell: 15, on: 840))
    var answered = known
    var forgot = answered.forgetUnless(asked: CGSize(width: 861, height: 855), wasTakenAs: CGSize(width: 861, height: 855))
    #expect(!forgot && answered == known)
    // The font is twice as large: what it takes is on the old grid too, so no sighting would tell.
    forgot = answered.forgetUnless(asked: CGSize(width: 861, height: 855), wasTakenAs: CGSize(width: 861, height: 870))
    #expect(forgot && answered == cells(width: known.width), "each way by itself")
    var unknown = Cells()
    forgot = unknown.forgetUnless(asked: CGSize(width: 500, height: 500), wasTakenAs: CGSize(width: 497, height: 510))
    #expect(!forgot && unknown == Cells(), "nothing to forget")
  }

  @Test func aSightingTeachesNothing() {
    var seen = Cells()
    for width in [CGFloat(500), 507, 514, 521] { seen.see(CGSize(width: width, height: 300)) }
    #expect(seen == Cells())
  }

  // MARK: What is no cell

  @Test(arguments: [CGFloat(0), 1, 2.9, 36.5, 400, -7, .infinity, -.infinity, .nan])
  func whatIsNoCellIsNotKept(cell: CGFloat) {
    #expect(Cells.Side(cell: cell, on: 500) == Cells.Side())
  }

  @Test(arguments: [CGFloat(0), -500, .infinity, .nan]) func norALengthNoWindowHas(on: CGFloat) {
    #expect(Cells.Side(cell: 7, on: on) == Cells.Side())
  }

  @Test(arguments: [CGFloat.infinity, -.infinity, .nan, 1e300, -1e300, 0, -5]) func anAbsurdSlotIsHandedBack(length: CGFloat) {
    let asked = cells(width: Cells.Side(cell: 7, on: 500)).fitting(CGSize(width: length, height: 100)).width
    #expect(asked == length || (asked.isNaN && length.isNaN) || (asked > 0 && asked <= length + 2.01))
  }

  // MARK: Where a window rests

  /// Less than its cell short, a window has filled its slot; less than twenty points while nothing is known of its cell.
  @Test func lessThanACellShortItHasFilledItsSlot() {
    let unknown = Cells.Side()
    #expect(unknown.explains(short: 0) && unknown.explains(short: 19.5) && unknown.explains(short: -4))
    #expect(!unknown.explains(short: 20) && !unknown.explains(short: 300))
    let small = Cells.Side(cell: 7, on: 500)
    #expect(small.explains(short: 6.5) && !small.explains(short: 7))
    let large = Cells.Side(cell: 29, on: 500)
    #expect(large.explains(short: 28) && !large.explains(short: 29))
  }
}
