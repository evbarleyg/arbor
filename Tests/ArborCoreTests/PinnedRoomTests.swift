import ArborCore
import CoreGraphics
import Testing

/// The strip a window kept in view reserves (docs/features/F49-pin.md; collab/QUESTIONS.md Q25).
@Suite struct PinnedRoomTests {
  let call = WindowID(1)
  let timer = WindowID(2)
  let notes = WindowID(3)
  /// A display of 1440×900 under its menu bar.
  let view = CGRect(x: 0, y: 25, width: 1440, height: 875)

  func reserve(_ kept: (WindowID, CGRect)...) -> PinnedRoom { PinnedRoom.reserve(in: view, for: kept.map { (window: $0.0, frame: $0.1) }) }

  @Test func nothingKeptInViewLeavesTheWholeDisplay() {
    #expect(reserve() == PinnedRoom(room: view))
  }

  @Test func theStripRunsFromTheInnerEdgeToTheDisplaysEdgeOverTheWholeHeight() {
    let kept = reserve((call, CGRect(x: 1040, y: 60, width: 360, height: 240)))
    #expect(kept.strips == [.init(window: call, edge: .right, frame: CGRect(x: 1040, y: 25, width: 400, height: 875))])
    #expect(kept.room == CGRect(x: 0, y: 25, width: 1040, height: 875))
    #expect(kept.without.isEmpty)
  }

  @Test func ofTheFourStripsItIsTheCheapest() {
    // Each lies 20 points from one edge, and far from the others.
    let places: [(Edge, CGRect, CGRect)] = [
      (.left, CGRect(x: 20, y: 300, width: 300, height: 300), CGRect(x: 320, y: 25, width: 1120, height: 875)),
      (.right, CGRect(x: 1120, y: 300, width: 300, height: 300), CGRect(x: 0, y: 25, width: 1120, height: 875)),
      (.top, CGRect(x: 500, y: 45, width: 440, height: 200), CGRect(x: 0, y: 245, width: 1440, height: 655)),
      (.bottom, CGRect(x: 500, y: 680, width: 440, height: 200), CGRect(x: 0, y: 25, width: 1440, height: 655)),
    ]
    for (edge, frame, room) in places {
      let kept = reserve((call, frame))
      #expect(kept.strips.map(\.edge) == [edge])
      #expect(kept.room == room)
      #expect(!kept.room.overlaps(frame))
    }
    // In a corner, wide and low: the strip along the top costs 1440 × 175, the one along the right 700 × 875.
    #expect(reserve((call, CGRect(x: 740, y: 25, width: 700, height: 175))).strips.map(\.edge) == [.top])
  }

  @Test func aStripOfMoreThanFourTenthsIsNotReserved() {
    // 576 of 1440 points are four tenths to the point.
    let just = reserve((call, CGRect(x: 864, y: 100, width: 576, height: 700)))
    #expect(just.room == CGRect(x: 0, y: 25, width: 864, height: 875))
    let over = reserve((call, CGRect(x: 863, y: 100, width: 577, height: 700)))
    #expect(over == PinnedRoom(room: view, without: [call]))
    // In the middle, however small.
    #expect(reserve((call, CGRect(x: 620, y: 400, width: 200, height: 120))) == PinnedRoom(room: view, without: [call]))
    // As large as the display.
    #expect(reserve((call, view)) == PinnedRoom(room: view, without: [call]))
  }

  @Test func twoHaveTheirStripsWhileTheSumStaysUnderFourTenthsInTheOrderPinned() {
    let right = CGRect(x: 1140, y: 60, width: 300, height: 200)
    let left = CGRect(x: 0, y: 60, width: 200, height: 200)
    let both = reserve((call, right), (timer, left))
    #expect(both.strips.map(\.window) == [call, timer])
    #expect(both.room == CGRect(x: 200, y: 25, width: 940, height: 875))
    // 300 and 300 of 1440 are more: the one pinned first has its strip.
    let wide = CGRect(x: 0, y: 60, width: 300, height: 200)
    #expect(reserve((call, right), (timer, wide)) == PinnedRoom(
      room: CGRect(x: 0, y: 25, width: 1140, height: 875),
      strips: [.init(window: call, edge: .right, frame: CGRect(x: 1140, y: 25, width: 300, height: 875))], without: [timer]))
    #expect(reserve((timer, wide), (call, right)).without == [call])
    // A third that is small enough is not turned away because the second was.
    #expect(reserve((call, right), (timer, wide), (notes, left)).without == [timer])
  }

  @Test func oneThatLiesInAnothersStripNeedsNoneOfItsOwn() {
    let kept = reserve((call, CGRect(x: 1040, y: 60, width: 360, height: 240)), (timer, CGRect(x: 1100, y: 400, width: 300, height: 200)))
    #expect(kept.strips.map(\.window) == [call])
    #expect(kept.without.isEmpty)
    // One that reaches out of it widens the room taken by what reaches out.
    let wider = reserve((call, CGRect(x: 1040, y: 60, width: 360, height: 240)), (timer, CGRect(x: 1000, y: 400, width: 300, height: 200)))
    #expect(wider.room == CGRect(x: 0, y: 25, width: 1000, height: 875))
    #expect(wider.strips.last == .init(window: timer, edge: .right, frame: CGRect(x: 1000, y: 25, width: 40, height: 875)))
  }

  @Test func theSecondStripIsCutFromWhatTheFirstLeft() {
    let kept = reserve((call, CGRect(x: 1140, y: 60, width: 300, height: 200)), (timer, CGRect(x: 400, y: 25, width: 300, height: 100)))
    #expect(kept.strips.last == .init(window: timer, edge: .top, frame: CGRect(x: 0, y: 25, width: 1140, height: 100)))
    #expect(kept.room == CGRect(x: 0, y: 125, width: 1140, height: 775))
  }

  @Test func whatHangsOverTheEdgeNeedsNoRoom() {
    // Pushed aside by hand until 229 points show.
    #expect(reserve((call, CGRect(x: -251, y: 288, width: 480, height: 348))).room == CGRect(x: 229, y: 25, width: 1211, height: 875))
    // On another display altogether.
    #expect(reserve((call, CGRect(x: 1500, y: 100, width: 300, height: 200))) == PinnedRoom(room: view))
  }

  @Test func theRoomBeginsOnAWholePointClearOfTheWindow() {
    for (frame, room) in [
      (CGRect(x: 1040.5, y: 60, width: 399.5, height: 240), CGRect(x: 0, y: 25, width: 1040, height: 875)),
      (CGRect(x: 0, y: 60, width: 300.25, height: 240), CGRect(x: 301, y: 25, width: 1139, height: 875)),
      (CGRect(x: 500, y: 25, width: 440, height: 100.5), CGRect(x: 0, y: 126, width: 1440, height: 774)),
      (CGRect(x: 500, y: 799.5, width: 440, height: 100.5), CGRect(x: 0, y: 25, width: 1440, height: 774)),
    ] {
      #expect(reserve((call, frame)).room == room)
    }
  }

  @Test func aDisplayThatDoesNotBeginAtNought() {
    let second = CGRect(x: 1440, y: -180, width: 1920, height: 1080)
    let kept = PinnedRoom.reserve(in: second, for: [(window: call, frame: CGRect(x: 1460, y: 0, width: 400, height: 300))])
    #expect(kept.room == CGRect(x: 1860, y: -180, width: 1500, height: 1080))
  }
}
