import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A floating window that Arbor squeezed beside what is docked keeps its own size to go back to when its user only moves it.
/// Let go a point under the Dock's line, it counted as left hanging, and its own width came back from the hand's corner, off
/// the right edge, which the hand had never taken it across: a third of it showed, and Show Everything did not mend it.
@Suite @MainActor struct ASizeGivenBackTests {
  /// How a hand moves a window: a report that it moved, or a drag with ⌘ held, which Arbor follows without docking.
  enum Hand: CaseIterable, Sendable { case moves, drags }

  struct Desk {
    let h: Harness
    let docked, floating: WindowID
    let visible: CGRect
  }

  /// One display with a Dock. `docked` insists on `minimum` of its width; `own` floats beside it, squeezed into the rest.
  func desk(width: CGFloat = 1512, height: CGFloat = 982, dock: CGFloat = 59, minimum: CGFloat = 1188, own: CGSize) -> Desk {
    let h = Harness()
    let display = AReportAcrossABorderTests.display(
      "laptop", CGRect(x: 0, y: 0, width: width, height: height), bottom: dock, isMain: true)
    h.system.displayList = [display]
    h.start()
    let floating = h.system.open(app: "Terminal", pid: 41, frame: CGRect(origin: CGPoint(x: 117, y: 200), size: own))
    let docked = h.system.open(
      app: "Xcode", pid: 42, frame: CGRect(x: 100, y: 100, width: minimum + 100, height: 800),
      minimumSize: CGSize(width: minimum, height: 600))
    h.scheduler.advance(by: 2)
    #expect(h.run("dock \(docked.rawValue) left").ok)
    h.scheduler.advance(by: 2)
    return Desk(h: h, docked: docked, floating: floating, visible: display.visibleFrame)
  }

  /// Takes the floating window straight down until its bottom edge is `points` under the Dock's line (above it if negative).
  func lower(_ desk: Desk, by hand: Hand, under points: CGFloat) throws {
    let frame = try #require(desk.h.frame(desk.floating))
    let down = desk.visible.maxY + points - frame.maxY
    switch hand {
    case .moves:
      desk.h.system.userMove(desk.floating, to: frame.offsetBy(dx: 0, dy: down))
    case .drags:
      let grip = CGPoint(x: frame.midX, y: frame.minY + 10)
      desk.h.system.heldModifiers = [.command]
      desk.h.system.drag(desk.floating, through: [grip, CGPoint(x: grip.x, y: grip.y + down)])
      desk.h.system.heldModifiers = []
    }
    desk.h.scheduler.advance(by: 2)
    #expect(desk.h.frame(desk.floating) == frame.offsetBy(dx: 0, dy: down), "the hand only moves it")
  }

  func run(_ commands: String..., on desk: Desk) {
    for command in commands {
      #expect(desk.h.run(command).ok, "\(command)")
      desk.h.scheduler.advance(by: 2)
    }
  }

  /// Nothing of the window lies beyond the left or the right edge of what the display shows.
  func keepsWithinTheSides(_ desk: Desk) -> Bool {
    guard let frame = desk.h.frame(desk.floating) else { return false }
    return frame.minX >= desk.visible.minX - 1 && frame.maxX <= desk.visible.maxX + 1
  }

  nonisolated static let terminal = CGSize(width: 763, height: 597)

  // MARK: The fault

  @Test(arguments: Hand.allCases, [1, 4, 40] as [CGFloat]) func letGoUnderTheDocksLine(hand: Hand, points: CGFloat) throws {
    let desk = desk(own: Self.terminal)
    #expect(try #require(desk.h.frame(desk.floating)).width < 400, "squeezed into the strip")
    try lower(desk, by: hand, under: points)
    run("relayout", "home", on: desk)
    #expect(keepsWithinTheSides(desk), "\(String(describing: desk.h.frame(desk.floating)))")
  }

  /// What brings it in brings it in for good: nothing wrong is remembered.
  @Test(arguments: [
    ["show-all"], ["desktop"], ["float-all"], ["float-all", "home"], ["desktop", "home"], ["undo", "home"],
    ["toggle-pause", "toggle-pause", "home"],
  ]) func everyWayBackLasts(commands: [String]) throws {
    let desk = desk(own: Self.terminal)
    try lower(desk, by: .moves, under: 4)
    run("relayout", on: desk)
    for command in commands { run(command, on: desk) }
    #expect(keepsWithinTheSides(desk), "\(commands): \(String(describing: desk.h.frame(desk.floating)))")
  }

  /// Something else is docked afterwards, which makes the strip narrower still.
  @Test func anotherWindowIsDockedAfterwards() throws {
    let desk = desk(own: Self.terminal)
    let safari = desk.h.system.open(app: "Safari", pid: 43, frame: CGRect(x: 176, y: 351, width: 431, height: 478))
    desk.h.scheduler.advance(by: 2)
    try lower(desk, by: .moves, under: 4)
    run("dock \(safari.rawValue) left", "home", on: desk)
    #expect(keepsWithinTheSides(desk), "\(String(describing: desk.h.frame(desk.floating)))")
  }

  /// Ordinary apps: a wide window beside one that insists on more than half of the display.
  @Test(arguments: [
    (1440, 820, 1300), (1512, 760, 1400),
  ] as [(CGFloat, CGFloat, CGFloat)])
  func aWideWindowBesideAnOrdinaryApp(width: CGFloat, minimum: CGFloat, own: CGFloat) throws {
    let desk = desk(width: width, height: 900, minimum: minimum, own: CGSize(width: own, height: 600))
    try lower(desk, by: .drags, under: 4)
    run("relayout", "home", on: desk)
    #expect(keepsWithinTheSides(desk), "\(String(describing: desk.h.frame(desk.floating)))")
  }

  // MARK: What stays

  /// Above the line it was always fitted.
  @Test(arguments: Hand.allCases, [0, -30] as [CGFloat]) func letGoAboveTheDocksLine(hand: Hand, points: CGFloat) throws {
    let desk = desk(own: Self.terminal)
    try lower(desk, by: hand, under: points)
    run("relayout", "home", on: desk)
    #expect(keepsWithinTheSides(desk))
  }

  /// How far under the line the hand left it is the hand's business.
  @Test func whereTheHandLeftItHangingItStillHangs() throws {
    let desk = desk(own: Self.terminal)
    try lower(desk, by: .moves, under: 40)
    let left = try #require(desk.h.frame(desk.floating))
    run("relayout", "home", on: desk)
    #expect(desk.h.frame(desk.floating)?.minY == left.minY)
  }

  /// Taken across the right edge by hand, it gets its own width back from the hand's corner, as before.
  @Test func takenOverTheRightEdgeByHand() throws {
    let desk = desk(own: Self.terminal)
    let frame = try #require(desk.h.frame(desk.floating))
    desk.h.system.userMove(desk.floating, to: frame.offsetBy(dx: 100, dy: 0))
    desk.h.scheduler.advance(by: 2)
    run("relayout", "home", on: desk)
    let after = try #require(desk.h.frame(desk.floating))
    #expect(after.minX == frame.minX + 100)
    #expect(after.width == Self.terminal.width)
  }

  /// Its own size is not forgotten: it comes back when there is room.
  @Test func itsOwnSizeComesBackWhenThereIsRoom() throws {
    let desk = desk(own: Self.terminal)
    try lower(desk, by: .moves, under: 4)
    run("float-all", on: desk)
    #expect(desk.h.frame(desk.floating)?.size == Self.terminal)
    #expect(keepsWithinTheSides(desk))
  }
}
