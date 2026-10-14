import ArborCore
import CoreGraphics
import Testing

private typealias Candidate = DirectionalSearch.Candidate<String>

private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
  CGRect(x: x, y: y, width: width, height: height)
}

/// The id of what `DirectionalSearch.nearest` picks.
private func pick(from origin: CGRect, _ direction: Edge, _ candidates: [Candidate]) -> String? {
  DirectionalSearch.nearest(from: origin, toward: direction, among: candidates)?.id
}

/// F22: which rectangle lies in a direction from another.
@Suite struct DirectionalSearchTests {
  @Test func theNearestOfThreeColumnsWins() {
    let a = rect(0, 0, 100, 300)
    let others = [Candidate(id: "c", frame: rect(224, 0, 100, 300)), Candidate(id: "b", frame: rect(112, 0, 100, 300))]
    #expect(pick(from: a, .right, others) == "b")
    #expect(pick(from: a, .left, others) == nil)
    #expect(pick(from: rect(224, 0, 100, 300), .left, [Candidate(id: "a", frame: a), others[1]]) == "b")
  }

  /// The reason nearness comes before overlap: a tall window two columns away shares more of the
  /// origin's span than either window of the column in between.
  @Test func aTallWindowFurtherAwayDoesNotBeatTheColumnInBetween() {
    let a = rect(0, 0, 100, 500)
    let candidates = [
      Candidate(id: "far", frame: rect(224, 0, 100, 875)), Candidate(id: "top", frame: rect(112, 0, 100, 300)),
      Candidate(id: "bottom", frame: rect(112, 312, 100, 563)),
    ]
    #expect(pick(from: a, .right, candidates) == "top")
  }

  @Test func betweenEquallyNearOnesTheLongerSharedSpanWins() {
    let a = rect(0, 0, 100, 900)
    let candidates = [
      Candidate(id: "short", frame: rect(112, 0, 100, 260), recency: 0),
      Candidate(id: "long", frame: rect(112, 272, 100, 628), recency: 5),
    ]
    #expect(pick(from: a, .right, candidates) == "long", "overlap counts before recency")
  }

  @Test func betweenEqualOnesTheMostRecentlyFocusedWins() {
    let a = rect(0, 0, 100, 612)
    let top = rect(112, 0, 100, 300)
    let bottom = rect(112, 312, 100, 300)
    #expect(
      pick(from: a, .right, [Candidate(id: "top", frame: top, recency: 3), Candidate(id: "bottom", frame: bottom, recency: 1)])
        == "bottom")
    #expect(
      pick(from: a, .right, [Candidate(id: "top", frame: top, recency: 3), Candidate(id: "bottom", frame: bottom)])
        == "top", "never focused is the least recent")
  }

  @Test func withNothingElseToGoByTheTopmostThenTheLeftmostThenTheFirstWins() {
    let a = rect(0, 0, 100, 612)
    let top = Candidate(id: "top", frame: rect(112, 0, 100, 300))
    let bottom = Candidate(id: "bottom", frame: rect(112, 312, 100, 300))
    #expect(pick(from: a, .right, [bottom, top]) == "top")
    let wide = rect(0, 0, 612, 100)
    let left = Candidate(id: "left", frame: rect(0, 112, 300, 100))
    let right = Candidate(id: "right", frame: rect(312, 112, 300, 100))
    #expect(pick(from: wide, .bottom, [right, left]) == "left")
    let twin = Candidate(id: "twin", frame: left.frame)
    #expect(pick(from: wide, .bottom, [twin, left]) == "twin")
  }

  @Test func aSmallWindowInBetweenIsNotJumpedOver() {
    // A docked window, a small floating window on the Desktop, a docked window beyond it.
    let a = rect(12, 37, 464, 851)
    let floating = Candidate(id: "floating", frame: rect(560, 300, 320, 240))
    let docked = Candidate(id: "docked", frame: rect(964, 37, 464, 851))
    #expect(pick(from: a, .right, [docked, floating]) == "floating")
    #expect(pick(from: floating.frame, .right, [docked, Candidate(id: "a", frame: a)]) == "docked")
    #expect(pick(from: docked.frame, .left, [Candidate(id: "a", frame: a), floating]) == "floating")
  }

  @Test func oneThatBarelyOverlapsLosesToOneBesideTheOriginFurtherAway() {
    let a = rect(0, 0, 400, 400)
    let sliver = Candidate(id: "sliver", frame: rect(420, 395, 300, 300))  // shares 5 of its 300 points
    let beside = Candidate(id: "beside", frame: rect(800, 0, 400, 400))
    #expect(pick(from: a, .right, [sliver, beside]) == "beside")
    // A quarter of the shorter span is enough to count as beside it.
    let quarter = Candidate(id: "quarter", frame: rect(420, 325, 300, 300))
    #expect(pick(from: a, .right, [quarter, beside]) == "quarter")
  }

  @Test func aDiagonalOneIsBetterThanNothing() {
    let a = rect(0, 0, 200, 200)
    let near = Candidate(id: "near", frame: rect(300, 300, 200, 200))
    let far = Candidate(id: "far", frame: rect(300, 900, 200, 200))
    #expect(pick(from: a, .right, [far, near]) == "near", "corner to corner, the shorter way")
    #expect(pick(from: a, .bottom, [far, near]) == "near")
    #expect(pick(from: a, .left, [far, near]) == nil)
    #expect(pick(from: a, .top, [far, near]) == nil)
  }

  @Test func anOverlappingWindowCountsIfItsCentreIsPastTheEdge() {
    // A floating window lying over the right part of a docked one and reaching past it.
    let docked = rect(12, 37, 464, 851)
    let floating = rect(300, 200, 640, 420)
    #expect(pick(from: docked, .right, [Candidate(id: "floating", frame: floating)]) == "floating")
    #expect(pick(from: floating, .left, [Candidate(id: "docked", frame: docked)]) == "docked")
    #expect(pick(from: docked, .left, [Candidate(id: "floating", frame: floating)]) == nil)
    // One in the very middle of the other is in no direction from it.
    let inner = rect(docked.midX - 100, docked.midY - 100, 200, 200)
    for direction in Edge.allCases {
      #expect(pick(from: docked, direction, [Candidate(id: "inner", frame: inner)]) == nil)
      #expect(pick(from: inner, direction, [Candidate(id: "docked", frame: docked)]) == nil)
    }
  }

  @Test func oneThatLiesOverTheOriginCountsTheWayItsCentreLies() {
    let origin = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let inside = Candidate(id: "inside", frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    let beyond = Candidate(id: "beyond", frame: CGRect(x: 1010, y: 0, width: 400, height: 800))
    #expect(DirectionalSearch.nearest(from: origin, toward: .right, among: [beyond, inside])?.id == "inside", "nothing is nearer")
    #expect(DirectionalSearch.nearest(from: origin, toward: .left, among: [beyond, inside]) == nil)
    // Level with the origin's centre up and down, to the point or two that count as a tie.
    #expect(DirectionalSearch.nearest(from: origin, toward: .top, among: [inside]) == nil)
    #expect(DirectionalSearch.nearest(from: origin, toward: .bottom, among: [inside]) == nil)
    // And back: the large one lies the other way from the small one.
    let large = Candidate(id: "large", frame: origin)
    #expect(DirectionalSearch.nearest(from: inside.frame, toward: .left, among: [large])?.id == "large")
    #expect(DirectionalSearch.nearest(from: inside.frame, toward: .right, among: [large]) == nil)
    // Two that only touch do not lie over each other.
    let touching = Candidate(id: "touching", frame: CGRect(x: 1000, y: 0, width: 10, height: 800))
    #expect(DirectionalSearch.nearest(from: origin, toward: .left, among: [touching]) == nil)
  }

  @Test func everyDirectionWorksTheSameWay() {
    let middle = rect(300, 300, 100, 100)
    let around = [
      Candidate(id: "left", frame: rect(100, 300, 100, 100)), Candidate(id: "right", frame: rect(500, 300, 100, 100)),
      Candidate(id: "top", frame: rect(300, 100, 100, 100)), Candidate(id: "bottom", frame: rect(300, 500, 100, 100)),
    ]
    for direction in Edge.allCases {
      #expect(pick(from: middle, direction, around) == direction.rawValue)
    }
  }

  @Test func aPointOrTwoOfRoundingIsATie() {
    let a = rect(0, 0, 100, 900)
    let candidates = [
      Candidate(id: "short", frame: rect(111, 0, 100, 260)),  // a point nearer
      Candidate(id: "long", frame: rect(112, 272, 100, 628)),
    ]
    #expect(pick(from: a, .right, candidates) == "long")
    let halves = [
      Candidate(id: "top", frame: rect(112, 0, 100, 445), recency: 4),  // a point longer
      Candidate(id: "bottom", frame: rect(112, 456, 100, 444), recency: 2),
    ]
    #expect(pick(from: a, .right, halves) == "bottom")
  }

  @Test func emptyRectanglesAndEmptyListsFindNothing() {
    let a = rect(0, 0, 100, 100)
    #expect(pick(from: a, .right, []) == nil)
    #expect(pick(from: a, .right, [Candidate(id: "flat", frame: rect(200, 0, 100, 0))]) == nil)
    #expect(pick(from: a, .right, [Candidate(id: "null", frame: .null)]) == nil)
    #expect(pick(from: a, .right, [Candidate(id: "nan", frame: rect(.nan, 0, 100, 100))]) == nil)
  }

  @Test func approachingPutsTheFrameJustOutsideTheSideOneEntersFrom() {
    let view = rect(0, 25, 1440, 875)
    let frame = rect(500, 100, 300, 200)
    #expect(DirectionalSearch.approaching(view, from: frame, toward: .right) == rect(-300, 100, 300, 200))
    #expect(DirectionalSearch.approaching(view, from: frame, toward: .left) == rect(1440, 100, 300, 200))
    #expect(DirectionalSearch.approaching(view, from: frame, toward: .bottom) == rect(500, -175, 300, 200))
    #expect(DirectionalSearch.approaching(view, from: frame, toward: .top) == rect(500, 900, 300, 200))
    // From there, everything in the view lies ahead, and what is nearest that side comes first.
    let inside = [Candidate(id: "second", frame: rect(732, 37, 696, 851)), Candidate(id: "first", frame: rect(12, 37, 708, 851))]
    #expect(pick(from: DirectionalSearch.approaching(view, from: frame, toward: .right), .right, inside) == "first")
    #expect(pick(from: DirectionalSearch.approaching(view, from: frame, toward: .left), .left, inside) == "second")
  }

  @Test func theFacingEdgeIsTheOneTowardsWhereOneCameFrom() {
    let main = rect(0, 0, 1440, 900)
    #expect(DirectionalSearch.facingEdge(of: rect(1440, 0, 1280, 800), from: main) == .left)
    #expect(DirectionalSearch.facingEdge(of: rect(-1280, 100, 1280, 800), from: main) == .right)
    #expect(DirectionalSearch.facingEdge(of: rect(100, -800, 1280, 800), from: main) == .bottom)
    #expect(DirectionalSearch.facingEdge(of: rect(100, 900, 1280, 800), from: main) == .top)
  }
}
