import ArborCore
import CoreGraphics
import Testing

@Suite struct SeenSizesTests {
  let start = CGSize(width: 640, height: 420)

  @Test func onlyASizeBeyondWhatWasSeenIsAQuestion() {
    var seen = SeenSizes(start)
    #expect(!seen.mayRefuseToShrink(to: start) && !seen.mayRefuseToGrow(to: start, now: start))
    #expect(seen.mayRefuseToShrink(to: CGSize(width: 600, height: 420)))
    #expect(seen.mayRefuseToShrink(to: CGSize(width: 900, height: 400)), "each way by itself")
    #expect(seen.mayRefuseToGrow(to: CGSize(width: 600, height: 500), now: start))
    // Apps round.
    #expect(!seen.mayRefuseToShrink(to: CGSize(width: 638, height: 418)))
    #expect(!seen.mayRefuseToGrow(to: CGSize(width: 642, height: 422), now: start))

    seen.note(took: CGSize(width: 500, height: 800), offered: CGSize(width: 500, height: 800))
    #expect(seen.least == CGSize(width: 500, height: 420) && seen.most == CGSize(width: 640, height: 800))
    #expect(!seen.mayRefuseToShrink(to: CGSize(width: 500, height: 420)))
    #expect(!seen.mayRefuseToGrow(to: CGSize(width: 640, height: 800), now: CGSize(width: 500, height: 800)))
    #expect(seen.stoppedAt == .zero)
  }

  @Test func whatItTookInsteadHasBeenSeen() {
    var seen = SeenSizes(CGSize(width: 1000, height: 700))
    seen.note(took: CGSize(width: 800, height: 500), offered: CGSize(width: 460, height: 500))
    #expect(!seen.mayRefuseToShrink(to: CGSize(width: 800, height: 500)))
    #expect(seen.mayRefuseToShrink(to: CGSize(width: 700, height: 500)), "nobody records here that it will: `minimumSizes` does")
  }

  @Test func whereItStoppedGrowingItIsExpectedToStopAgain() {
    var seen = SeenSizes(start)
    let now = CGSize(width: 640, height: 800)
    let far = CGSize(width: 1400, height: 860)
    seen.note(took: now, offered: CGSize(width: 700, height: 800))
    #expect(seen.stoppedAt == CGSize(width: 640, height: 0))
    #expect(seen.limit(now: now, offered: far).width == 640 && seen.limit(now: now, offered: far).height == nil)
    #expect(!seen.mayRefuseToGrow(to: CGSize(width: 1400, height: 800), now: now), "the answer is known")
    #expect(seen.mayRefuseToGrow(to: CGSize(width: 1400, height: 860), now: now), "not for its height")
  }

  /// A terminal takes the whole character cells nearest to what it is offered. Offered more, it takes more.
  @Test func comingCloseIsNotStopping() {
    var seen = SeenSizes(start)
    seen.note(took: CGSize(width: 460, height: 840), offered: CGSize(width: 464, height: 851))
    #expect(seen.stoppedAt == .zero)
    #expect(!seen.mayRefuseToGrow(to: CGSize(width: 464, height: 851), now: CGSize(width: 460, height: 840)), "it has answered that")
    seen.note(took: CGSize(width: 666, height: 840), offered: CGSize(width: 702, height: 851))
    #expect(seen.stoppedAt == .zero, "the largest step there is")
    seen.note(took: CGSize(width: 665, height: 840), offered: CGSize(width: 702, height: 851))
    #expect(seen.stoppedAt == CGSize(width: 665, height: 0))
  }

  /// But what it made of that offer it makes of it again, and of anything between the offer and what it took, terminal or not.
  @Test func whatItTookOfAnOfferItCameCloseToIsExpectedAgain() {
    var seen = SeenSizes(CGSize(width: 723, height: 600))
    let now = CGSize(width: 723, height: 851)
    seen.note(took: now, offered: CGSize(width: 749, height: 851))
    #expect(seen.stoppedAt == .zero)
    #expect(seen.limit(now: now, offered: CGSize(width: 749, height: 851)).width == 723)
    #expect(seen.limit(now: now, offered: CGSize(width: 730, height: 851)).width == 723)
    #expect(seen.limit(now: now, offered: CGSize(width: 760, height: 851)).width == nil, "offered more, a terminal takes more")
    #expect(seen.limit(now: now, offered: CGSize(width: 700, height: 851)).width == nil)
    #expect(seen.limit(now: CGSize(width: 740, height: 851), offered: CGSize(width: 749, height: 851)).width == nil, "it has outgrown it")
    seen.note(took: CGSize(width: 749, height: 851), offered: CGSize(width: 749, height: 851))
    #expect(seen.closeTook.width == 0)
  }

  /// Of a terminal whose cell is known it is known what it makes of any offer: nothing is left to ask.
  @Test func withItsCellKnownNoOfferIsAQuestion() {
    var seen = SeenSizes(CGSize(width: 464, height: 840))
    #expect(seen.mayRefuseToGrow(to: CGSize(width: 464, height: 1200), now: CGSize(width: 464, height: 840)))
    seen.cells.height = Cells.Side(cell: 15, on: 840)
    #expect(!seen.mayRefuseToGrow(to: CGSize(width: 464, height: 1200), now: CGSize(width: 464, height: 840)))
    #expect(seen.limit(now: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 1200)).height == 1200)
    #expect(seen.limit(now: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 1197)).height == 1185)
    #expect(seen.limit(now: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 1197)).width == nil, "each way by itself")
  }

  /// What it took of an offer it came close to holds for that offer. The grid holds for every offer, so it comes first: an offer two
  /// points larger can be a cell more.
  @Test func theGridComesBeforeWhatItTookLastTime() {
    var seen = SeenSizes(CGSize(width: 464, height: 840))
    seen.note(took: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 852))
    let now = CGSize(width: 464, height: 840)
    #expect(seen.limit(now: now, offered: CGSize(width: 464, height: 854)).height == 840, "nothing else is known")
    seen.cells.height = Cells.Side(cell: 15, on: 840)
    #expect(seen.limit(now: now, offered: CGSize(width: 464, height: 854)).height == 855)
  }

  /// Where it really stopped growing counts for more than its cells.
  @Test func whereItStoppedComesBeforeTheGrid() {
    var seen = SeenSizes(CGSize(width: 464, height: 840))
    seen.cells.height = Cells.Side(cell: 15, on: 840)
    seen.note(took: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 1200))
    #expect(seen.limit(now: CGSize(width: 464, height: 840), offered: CGSize(width: 464, height: 1200)).height == 840)
  }

  @Test func forgettingWhereItStoppedForgetsItsCellsToo() {
    var seen = SeenSizes(CGSize(width: 464, height: 840))
    seen.cells.height = Cells.Side(cell: 15, on: 840)
    seen.forgetWhereItStopped()
    #expect(seen.cells == Cells())
  }

  @Test func aSizeItFillsSaysNothingAboutALargerOne() {
    var seen = SeenSizes(start)
    seen.note(took: start, offered: CGSize(width: 700, height: 420))
    seen.note(took: CGSize(width: 400, height: 420), offered: CGSize(width: 400, height: 420))
    #expect(seen.stoppedAt.width == 640)
  }

  @Test func seenLargerItHasOutgrownWhatStoppedIt() {
    var seen = SeenSizes(start)
    seen.note(took: start, offered: CGSize(width: 700, height: 500))
    #expect(seen.stoppedAt == start)
    // In its person's hands, which nobody notes.
    let far = CGSize(width: 1400, height: 860)
    #expect(seen.limit(now: CGSize(width: 900, height: 420), offered: far).width == nil)
    #expect(seen.limit(now: CGSize(width: 900, height: 420), offered: far).height == 420)
    // Or when it was offered more again.
    seen.note(took: CGSize(width: 700, height: 420), offered: CGSize(width: 700, height: 500))
    #expect(seen.stoppedAt == CGSize(width: 0, height: 420))
  }
}
