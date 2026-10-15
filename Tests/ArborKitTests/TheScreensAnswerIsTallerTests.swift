import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The screen's answer is not the window's, also when it is the larger one (Controller+TheScreensAnswer.swift). No size call puts a window's foot into
/// the Dock's strip: a window that hangs off the display comes in no further than the display's bottom, and with its foot in the strip it is
/// held. Seen on a hosted Mac, each to the point: 480×360 for 480×348, 673×470 for 673×439, and at the next drop 673×480 for 673×470.
@Suite @MainActor struct TheScreensAnswerIsTallerTests {
  /// The display of the recordings: 1024×768, a Dock at the bottom.
  static let withADock = TheScreensAnswerTests.withADock
  static let own = CGSize(width: 480, height: 348)

  /// `w`, whose own size is 480×348, is docked at the left, in a slot as high as the screen allows; the rest is the Desktop.
  func deskWithAWindowInAHighSlot(own: CGSize = Self.own) throws -> (h: Harness, w: WindowID, slot: CGRect) {
    let h = Harness(displays: [Self.withADock])
    let w = h.system.open(app: "W", frame: CGRect(origin: CGPoint(x: 170, y: 100), size: own))
    h.start()
    h.run("dock \(w.rawValue) left")
    let slot = try #require(h.layout?.windowFrames[w])
    try #require(slot.height > 600 && h.frame(w) == slot, "\(slot)")
    return (h, w, slot)
  }

  /// Taken by its title bar and let go with the pointer at `y`.
  func letGo(_ h: Harness, _ w: WindowID, outOf slot: CGRect, at y: CGFloat) {
    h.system.drag(w, through: [CGPoint(x: slot.midX, y: slot.minY + 12), CGPoint(x: 600, y: (slot.minY + y) / 2), CGPoint(x: 760, y: y)])
  }

  /// Wherever it is let go: high up, where its foot comes right across the strip; where its own size ends in the strip; and so low that it hangs off the
  /// display before and after.
  @Test(arguments: [150, 300, 380, 400, 420, 440, 460, 520, 600] as [CGFloat]) func draggedOutOfAHighSlotItHasItsOwnSizeWhereverItIsLetGo(y: CGFloat) throws {
    let (h, w, slot) = try deskWithAWindowInAHighSlot()
    letGo(h, w, outOf: slot, at: y)
    try #require(h.workspace.isFloating(w), "it floats")
    let frame = try #require(h.frame(w))
    #expect(frame.size == Self.own, "\(frame)")
    #expect(frame.minY <= y && y <= frame.minY + 28 && frame.minX <= 760 && 760 <= frame.maxX, "its title bar is where it was let go: \(frame)")
    #expect(h.workspace.floating[w] == frame)
  }

  /// The case itself: let go at 420 its own size would end at 740, between the Dock's line at 705 and the display's bottom.
  @Test func itIsMovedWhereItCanShrinkAndSizedThere() throws {
    let (h, w, slot) = try deskWithAWindowInAHighSlot()
    let mark = h.system.moveLog.count
    letGo(h, w, outOf: slot, at: 420)
    let moves = h.system.moveLog[mark...].filter { $0.window == w }
    #expect(h.frame(w) == CGRect(x: h.frame(w)!.minX, y: 392, width: 480, height: 348))
    #expect(moves.count == 2, "\(moves.map(\.after))")
    let via = try #require(moves.first?.after)
    #expect(via.size == slot.size && via.minY + 348 <= 701 && via.minY + 348 >= 696, "as it is, straight above, no further than it takes: \(via)")
  }

  /// Where its own size fits at the place it is let go, but ends in the strip from where it hangs, there is nowhere else to size it: it goes there, as high
  /// as the screen held it, and is asked once more.
  @Test func whereItsSizeFitsAtTheGoalItIsAskedOnceMoreThere() throws {
    let (h, w, slot) = try deskWithAWindowInAHighSlot()
    let mark = h.system.moveLog.count
    letGo(h, w, outOf: slot, at: 380)
    let moves = h.system.moveLog[mark...].filter { $0.window == w }.map(\.after)
    #expect(moves.count == 2 && moves.first?.origin == moves.last?.origin && moves.last?.size == Self.own, "\(moves)")
    #expect((moves.last?.maxY ?? 0) <= 705 && (moves.first?.height ?? 0) < 420, "\(moves)")
  }

  private func play(_ lines: [String]) -> ChaosRunner {
    let runner = ChaosRunner()
    for line in lines { _ = runner.step(ChaosAction(text: line)) }
    return runner
  }
  private static let found = [
    "displays main:0,0,1024,768:31,0,63,0* windows-never", "launch", "open 101 Notes pid 1001 at 520 392 480 348",
    "open 102 Mail pid 1002 at 200 100 480 300", "settle", "dock 102 left", "settle", "crash", "move 101 520 392 480 370", "launch", "settle",
  ]

  /// Nobody asked it for less: a window that is higher than is remembered of it, with its foot in the strip, was made so by its person.
  @Test(arguments: [["zoom 102", "settle", "home", "settle"], ["pin 101", "settle", "unpin 101", "settle", "float-all", "settle"]])
  func whatIsOnlyRememberedIsNotHeldAgainstAWindowThatIsHigher(then: [String]) {
    #expect(play(Self.found + then).system.frame(of: WindowID(101))?.size == CGSize(width: 480, height: 370))
  }

  /// Slots without a gap end on the visible frame's bottom, which is on the screen.
  @Test func withoutAGapADockThatAppearsTeachesNothingEither() {
    let runner = play([
      "displays main:0,0,1024,768:31,0,0,0* windows-never", "settings {\"gap\":0}", "launch", "open 101 Notes pid 1001 at 100 100 480 300",
      "open 102 Mail pid 1002 at 200 100 480 300", "settle", "dock 101 left", "dock 102 right", "settle",
      "displays main:0,0,1024,768:31,0,60,0* windows-never", "settle",
    ])
    #expect(runner.controller.minimumSizes.isEmpty && runner.controller.parked.isEmpty)
    #expect(runner.system.frame(of: WindowID(101))?.maxY == 708 && runner.system.frame(of: WindowID(102))?.maxY == 708)
  }

  /// A low window that waits out of view, hanging off the display, is given back by way of nothing larger than the screen made it.
  @Test func aLowWindowComesBackFromTheCornerWithoutShowingItsOldSize() {
    let runner = play([
      "displays main:0,0,1024,768:31,0,63,0* windows-never", "launch", "open 101 Player pid 1001 at 100 100 300 60", "open 102 Mail pid 1002 at 200 100 480 300",
      "settle", "dock 101 left", "dock 102 right", "settle", "zoom 102", "settle",
    ])
    let mark = runner.system.moveLog.count
    _ = runner.step(ChaosAction(text: "float-all"))
    let moves = runner.system.moveLog[mark...].filter { $0.window == WindowID(101) }.map(\.after)
    #expect(moves.last == CGRect(x: 100, y: 100, width: 300, height: 60) && moves.allSatisfy { $0.height <= 100 }, "\(moves)")
  }

  /// It crept: what the screen had made of it was written down, and the next drop added to it. Quit gave the grown one.
  @Test func dropAfterDropItGrowsByNothing() throws {
    let (h, w, _) = try deskWithAWindowInAHighSlot()
    for y in [420, 410, 430, 420] as [CGFloat] {
      let slot = try #require(h.layout?.windowFrames[w])
      letGo(h, w, outOf: slot, at: y)
      #expect(h.frame(w)?.size == Self.own, "let go at \(y): \(h.frame(w) as Any)")
      h.run("dock \(w.rawValue) left")
      h.scheduler.advance(by: 1)
    }
    h.controller.shutdown()
    #expect(h.frame(w)?.size == Self.own, "\(h.frame(w) as Any)")
  }

  /// It does not stand where Arbor believes, so nobody foresaw it. An answer that is larger than was asked, of a window with its foot in the strip,
  /// is not written down, and is made good the same way, once.
  @Test func tallerAfterAllItIsNotWrittenDownAndMadeGood() throws {
    let left = CGRect(origin: CGPoint(x: 220, y: 392), size: Self.own)
    let h = Harness(displays: [Self.withADock])
    let w = h.system.open(app: "W", frame: CGRect(origin: CGPoint(x: 170, y: 100), size: Self.own))
    h.start()
    h.system.userMove(w, to: left)
    h.scheduler.advance(by: 2)
    h.run("dock \(w.rawValue) left")
    let listener = h.system.events
    h.system.events = nil
    h.system.userMove(w, to: CGRect(x: 314, y: 408, width: 325, height: 650))
    h.system.events = listener
    let mark = h.system.moveLog.count
    h.run("float-all")
    #expect(h.frame(w) == left, "\(h.system.moveLog[mark...].map(\.after))")
    #expect(h.workspace.floating[w] == left)
    #expect(h.system.moveLog[mark...].filter { $0.window == w }.count == 3, "no more than once more: \(h.system.moveLog[mark...].map(\.after))")
  }

  /// A window that will not be as small as it once was, for reasons of its own, is believed: judged where it was sized, where the screen holds nothing.
  @Test func anAppsOwnLimitIsStillItsOwn() throws {
    let (h, w, slot) = try deskWithAWindowInAHighSlot()
    h.system.setMinimumSize(w, CGSize(width: 480, height: 380))
    letGo(h, w, outOf: slot, at: 400)
    #expect(h.frame(w)?.size == CGSize(width: 480, height: 380), "\(h.frame(w) as Any)")
    #expect(h.workspace.floating[w]?.size == CGSize(width: 480, height: 380), "\(h.workspace.floating[w] as Any)")
  }

  /// A Dock appears under two rows of docked windows, or grows by more than the gap. Their feet stand in its strip. The lower row, which shrinks and moves
  /// up, is sized where it stands and held there; it came to its slot too high, Arbor took that for its app's smallest height and made room for
  /// it, and the upper row paid. It is the screen's answer: nothing is learnt, and it is asked once more in its slot. Nor is anybody asked
  /// for a size in place where the screen would answer.
  @Test func aDockThatAppearsUnderDockedWindowsTeachesNothing() throws {
    var display = DisplaySnapshot(
      id: DisplayID("the-dock-comes"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737), isMain: true)
    let h = Harness(displays: [display])
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 480, height: 300))
    let b = h.system.open(app: "B", frame: CGRect(x: 200, y: 100, width: 480, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let before = h.workspace
    display.visibleFrame.size.height = 674
    let mark = h.system.moveLog.count
    h.system.setDisplays([display])
    h.scheduler.advance(by: 2)
    #expect(h.workspace == before, "the arrangement is what it was")
    #expect(h.controller.minimumSizes.isEmpty, "\(h.controller.minimumSizes)")
    expectWindowsMatchLayout(h)
    #expect(abs((h.frame(a)?.height ?? 0) - (h.frame(b)?.height ?? 0)) <= 1, "\(h.frame(a) as Any), \(h.frame(b) as Any)")
    #expect(h.system.moveLog[mark...].filter { $0.window == a }.count == 1 && h.system.moveLog[mark...].filter { $0.window == b }.count == 2)
  }

  /// Without a Dock below there is no strip, and one request does it.
  @Test func withoutADockBelowOneRequestWillDo() throws {
    let display = DisplaySnapshot(
      id: DisplayID("no-dock-below"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737), isMain: true)
    let h = Harness(displays: [display])
    let w = h.system.open(app: "W", frame: CGRect(origin: CGPoint(x: 170, y: 100), size: Self.own))
    h.start()
    h.run("dock \(w.rawValue) left")
    let slot = try #require(h.layout?.windowFrames[w])
    let mark = h.system.moveLog.count
    letGo(h, w, outOf: slot, at: 420)
    #expect(h.frame(w)?.size == Self.own)
    #expect(h.system.moveLog[mark...].filter { $0.window == w }.count == 1)
  }
}
