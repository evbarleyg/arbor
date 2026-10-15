import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What a person set by hand is the strongest word there is about an arrangement. It outlasts every layout until they change it,
/// the windows in it change, or the room really is not there.
///
/// Where it did not: beside a window that stands at its app's smallest size on room that Arbor borrowed for it (F61). A drag forgot
/// what was lent across the gap it moved, and not what the window had from its other side. So the points the hand gave it
/// counted as points it could spare, and the next layout paid them back, over a gap that nobody had touched.
@Suite @MainActor struct AGapDraggedByHandLastsTests {
  nonisolated static let notesMinimum = CGSize(width: 709, height: 300)
  nonisolated static let mailPID: Int32 = 1001
  /// With a column for the Desktop, the lender on the far side that these stories are about; the rest as the run has it.
  nonisolated static var settings: Settings { Harness.settingsWhenNoneAreGiven.withDesktopColumn }

  /// [Mail | Notes | Desktop] on 1440 points. A third is 464: Notes stands at its 709 on what the Desktop lent it.
  func makeHarness(saved: PersistedState? = nil) -> (Harness, mail: WindowID, notes: WindowID) {
    let h = Harness(settings: Self.settings, saved: saved)
    let mail = h.system.open(app: "Mail", pid: Self.mailPID, frame: CGRect(x: 100, y: 100, width: 900, height: 600))
    let notes = h.system.open(
      app: "Notes", pid: 1002, frame: CGRect(x: 200, y: 100, width: 1000, height: 660), minimumSize: Self.notesMinimum)
    h.start()
    return (h, mail, notes)
  }

  func docked() throws -> (Harness, mail: WindowID, notes: WindowID) {
    let (h, mail, notes) = makeHarness()
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) right")
    #expect(try #require(h.frame(notes)).width == 709, "at its smallest")
    #expect(h.workspace.tree.hasLoans, "on borrowed room")
    return (h, mail, notes)
  }

  /// The gap between Mail and Notes goes `points` to the right.
  enum Hand: String, CaseIterable {
    case gap, edge, command

    @MainActor func move(_ h: Harness, mail: WindowID, notes: WindowID, by points: CGFloat) throws {
      switch self {
      case .gap:
        let leaf = h.workspace.tree.leaf(containing: notes)
        h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first { $0.trailing == leaf }), by: points)
      case .edge:
        // Mail's own right edge: no app lets its window be dragged below its smallest size.
        var frame = try #require(h.frame(mail))
        frame.size.width += points
        h.system.userResize(mail, to: frame)
      case .command:
        #expect(h.run("resize \(notes.rawValue) left \(Int(-points))").ok)
      }
    }
  }

  /// All that Arbor does by itself, or on a word that says nothing about gaps.
  enum Afterwards: String, CaseIterable {
    case home, showEverything, frameAndBack, lookAtTheDesktopAndBack, aWindowOpensAndCloses, aPanelOpensOverItAndCloses
    case minimizeAndRestore, hideAndUnhide, pauseAndResume, relayout

    var putsAWindowAway: Bool { self == .minimizeAndRestore || self == .hideAndUnhide }

    @MainActor func happen(_ h: Harness, mail: WindowID) {
      switch self {
      case .home: h.run("home")
      case .showEverything: h.run("show-all")
      case .frameAndBack:
        h.run("zoom \(mail.rawValue)")
        h.run("back")
      case .lookAtTheDesktopAndBack:
        h.run("desktop")
        h.run("show-all")
      case .aWindowOpensAndCloses:
        let calculator = h.system.open(app: "Calculator", pid: 1003, frame: CGRect(x: 1150, y: 200, width: 230, height: 408))
        h.scheduler.runPending()
        h.system.close(calculator)
      case .aPanelOpensOverItAndCloses:
        let panel = h.system.open(app: "Mail", pid: AGapDraggedByHandLastsTests.mailPID, frame: CGRect(x: 60, y: 200, width: 300, height: 200))
        h.scheduler.runPending()
        h.system.close(panel)
      case .minimizeAndRestore:
        h.system.setMinimized(mail, true)
        h.scheduler.runPending()
        h.system.setMinimized(mail, false)
      case .hideAndUnhide:
        h.system.setHidden(pid: AGapDraggedByHandLastsTests.mailPID, true)
        h.scheduler.runPending()
        h.system.setHidden(pid: AGapDraggedByHandLastsTests.mailPID, false)
      case .pauseAndResume:
        h.run("pause")
        h.run("resume")
      case .relayout: h.run("relayout")
      }
      h.scheduler.runPending()
    }
  }

  /// Where every gap of the view is, and what shows between them.
  func picture(_ h: Harness) -> [String] {
    guard let layout = h.layout else { return ["no layout"] }
    return layout.nodeFrames.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
      + layout.windowFrames.keys.sorted().map { "\($0) \(String(describing: h.frame($0)))" }
      + layout.tiles.map { "tile \($0.node)" }.sorted()
  }

  nonisolated static let everything = Hand.allCases.flatMap { hand in Afterwards.allCases.map { (hand, $0) } }

  @Test(arguments: everything) func theWindowAtItsSmallestThatTheHandMadeWiderStaysWider(_ hand: Hand, _ afterwards: Afterwards) throws {
    let (h, mail, notes) = try docked()
    try hand.move(h, mail: mail, notes: notes, by: -60)
    #expect(try #require(h.frame(notes)).width == 769)
    let (left, tree) = (picture(h), h.workspace.tree)
    afterwards.happen(h, mail: mail)
    #expect(picture(h) == left)
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  /// Someone who squeezes a window below its smallest size gets the tile they asked for, as wide as they left it.
  @Test(.withTiles, arguments: everything) func theTileTheHandMadeOfItStaysAsWideAsItWasLeft(_ hand: Hand, _ afterwards: Afterwards) throws {
    let (h, mail, notes) = try docked()
    try hand.move(h, mail: mail, notes: notes, by: 100)
    #expect(h.layout?.tiles.contains { $0.windows.contains(notes) } == true)
    // Whoever puts a window away like this goes on working in another. (The view follows the keyboard, at a resume too.)
    h.system.userFocus(mail)
    let (left, tree) = (picture(h), h.workspace.tree)
    afterwards.happen(h, mail: mail)
    #expect(picture(h) == left)
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  /// Several short drags, as a hand makes them, with a layout of Arbor's own between.
  @Test func eachOfSeveralDragsStartsWhereTheLastOneEnded() throws {
    let (h, mail, notes) = try docked()
    for step in 1...4 {
      try Hand.gap.move(h, mail: mail, notes: notes, by: -15)
      h.run("home")
      #expect(try #require(h.frame(notes)).width == 709 + CGFloat(step) * 15)
    }
  }

  func quitAndStart(_ old: Harness) -> (Harness, mail: WindowID, notes: WindowID) {
    old.scheduler.runPending()
    old.controller.shutdown()
    let new = makeHarness(saved: old.store.saved)
    new.0.scheduler.runPending()
    return new
  }

  @Test func quitAndStartAndTheGapStands() throws {
    let (old, oldMail, oldNotes) = try docked()
    try Hand.gap.move(old, mail: oldMail, notes: oldNotes, by: -60)
    let (left, tree) = (picture(old), old.workspace.tree)

    let (h, mail, _) = quitAndStart(old)
    #expect(picture(h) == left)
    #expect(h.workspace.tree == tree)
    // And once Arbor knows again how small Notes goes: squeezed for a moment, it refuses, and is let out again.
    try Hand.gap.move(h, mail: mail, notes: oldNotes, by: 100)
    try Hand.gap.move(h, mail: mail, notes: oldNotes, by: -100)
    for afterwards in Afterwards.allCases { afterwards.happen(h, mail: mail) }
    #expect(picture(h) == left)
    expectWindowsMatchLayout(h)
  }

  // MARK: Other desks

  /// An arrangement on 1440 × 900 in which somebody stands at their smallest size on borrowed room, and one drag of one gap.
  struct Desk: CustomTestStringConvertible, Sendable {
    var testDescription: String
    /// Ids from 101 on. A smallest size of nothing: Arbor never learns one.
    var windows: [(size: CGSize, minimum: CGSize)]
    var docks: [String]
    /// Who has the keyboard when the hand lets go.
    var keyboard: Int
    var gap: Int
    var points: CGFloat
    /// The drag squeezes somebody below their smallest size.
    var makesATile = false
  }

  nonisolated static func size(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width, height: height) }

  nonisolated static let desks = [
    Desk(
      testDescription: "made wider, lent from the far side", windows: [(size(900, 600), .zero), (size(1000, 660), notesMinimum)],
      docks: ["dock 101 left", "dock 102 beside 101 right"], keyboard: 102, gap: 0, points: -60),
    Desk(
      testDescription: "squeezed, lent from the far side", windows: [(size(900, 600), .zero), (size(1000, 660), notesMinimum)],
      docks: ["dock 101 left", "dock 102 beside 101 right"], keyboard: 101, gap: 0, points: 100, makesATile: true),
    Desk(
      testDescription: "made taller, lent from below", windows: [(size(900, 500), .zero), (size(1100, 560), size(680, 480))],
      docks: ["dock 101 top", "dock 102 beside 101 bottom"], keyboard: 102, gap: 0, points: -20),
    Desk(
      testDescription: "two borrowers, the Desktop at the far left",
      windows: [(size(1000, 660), size(709, 300)), (size(1324, 800), size(574, 240))],
      docks: ["dock 102 right", "dock 101 beside 102 left"], keyboard: 101, gap: 1, points: 90, makesATile: true),
    // The neighbour becomes the tile, and the Desktop, a tile too, is owed room: nobody takes what the hand gave, or what it left.
    Desk(
      testDescription: "the neighbour squeezed, the Desktop owed", windows: [(size(900, 600), size(400, 300)), (size(1000, 660), size(900, 300))],
      docks: ["dock 101 left", "dock 102 beside 101 right"], keyboard: 102, gap: 0, points: -60, makesATile: true),
    Desk(
      testDescription: "the neighbour squeezed further, the Desktop owed",
      windows: [(size(900, 600), size(400, 300)), (size(1000, 660), size(900, 300))],
      docks: ["dock 101 left", "dock 102 beside 101 right"], keyboard: 102, gap: 0, points: -160, makesATile: true),
    // Squeezed in height, it is a tile, and a tile could spare nearly all of the width it was lent.
    Desk(
      testDescription: "squeezed in height, lent in width", windows: [(size(900, 600), .zero), (size(1000, 660), size(709, 300))],
      docks: ["dock 101 bottom", "dock 102 beside 101 right"], keyboard: 101, gap: 1, points: 150, makesATile: true),
    // Mail and Chat, whose gap it is, have both lent to Notes at the far end.
    Desk(
      testDescription: "the gap between two lenders", windows: [(size(900, 600), .zero), (size(1000, 660), size(709, 300)), (size(800, 600), .zero)],
      docks: ["dock 103 left", "dock 101 left", "dock 102 right"], keyboard: 101, gap: 0, points: 20),
    // The column was lent width for the sake of Notes, in the row inside it. The gap is the one inside.
    Desk(
      testDescription: "a gap inside a group that was lent",
      windows: [(size(600, 600), size(300, 200)), (size(1000, 660), size(709, 300)), (size(900, 600), size(864, 300))],
      docks: ["dock 101 left", "dock 103 beside 101 bottom", "dock 102 beside 101 right"], keyboard: 102, gap: 0, points: -40, makesATile: true),
    // The same shape with the Desktop a tile that is owed room. The gap is not one of the Desktop's row, but it runs the same way.
    Desk(
      testDescription: "a gap inside a group, the Desktop owed",
      windows: [(size(900, 600), size(400, 300)), (size(1000, 660), size(900, 300)), (size(800, 600), .zero)],
      docks: ["dock 101 left", "dock 103 beside 101 bottom", "dock 102 beside 101 right"], keyboard: 102, gap: 0, points: -160, makesATile: true),
  ]

  /// The desk's windows, floating, and Arbor started. The window whose `turn` it is is Mail's.
  func open(_ desk: Desk, turn: Int = 0, saved: PersistedState? = nil) -> Harness {
    let h = Harness(settings: Self.settings, saved: saved)
    for (index, window) in desk.windows.enumerated() {
      h.system.open(
        app: index == turn ? "Mail" : "App\(index)", pid: index == turn ? Self.mailPID : 2000 + Int32(index),
        frame: CGRect(origin: CGPoint(x: 100, y: 100), size: window.size), minimumSize: window.minimum)
    }
    h.start()
    return h
  }

  func arrange(_ desk: Desk, turn: Int = 0) throws -> Harness {
    let h = open(desk, turn: turn)
    for dock in desk.docks { #expect(h.run(dock).ok) }
    #expect(h.workspace.tree.hasLoans, "somebody is on borrowed room")
    h.system.userFocus(WindowID(UInt32(desk.keyboard)))
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?[desk.gap]), by: desk.points)
    h.scheduler.runPending()
    return h
  }

  @Test(arguments: desks, Afterwards.allCases) func onEveryDeskTheGapsStayWhereTheHandLeftThem(_ desk: Desk, _ afterwards: Afterwards) throws {
    // Each docked window in its turn is the one framed, minimized or hidden.
    for turn in desk.windows.indices {
      let h = try arrange(desk, turn: turn)
      let (left, tree) = (picture(h), h.workspace.tree)
      afterwards.happen(h, mail: WindowID(UInt32(101 + turn)))
      // Whoever was put away and fetched back has the keyboard, and the view may have gone after it (rule 4).
      h.run("show-all")
      #expect(picture(h) == left, "with w\(101 + turn)")
      // While a window is away room is given back, and borrowed again in whole points when it returns: the weights come back to
      // within a point, and do not wander further however often it happens.
      if !afterwards.putsAWindowAway { #expect(h.workspace.tree == tree, "with w\(101 + turn)") }
      expectWindowsMatchLayout(h)
    }
  }

  /// Where the hand made no tile. That a window was squeezed on purpose is not saved (F61: "after a restart such a window is served like
  /// any other"), so on the other desks it is served at the next start from whoever can spare the room.
  @Test(arguments: desks.filter { !$0.makesATile }) func quitAndStartAndTheGapsStand(_ desk: Desk) throws {
    let old = try arrange(desk)
    #expect(old.layout?.tiles.allSatisfy { $0.kind == .desktop } == true)
    let (left, tree) = (picture(old), old.workspace.tree)
    old.controller.shutdown()

    let h = open(desk, saved: old.store.saved)
    h.scheduler.runPending()
    #expect(picture(h) == left)
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  /// The gap that squeezed Notes stands then, too: its room comes from the Desktop, on its other side.
  @Test func afterQuitAndStartTheGapThatSqueezedAWindowStandsAndTheWindowIsServed() throws {
    let (old, oldMail, oldNotes) = try docked()
    try Hand.gap.move(old, mail: oldMail, notes: oldNotes, by: 100)
    let left = try #require(old.frame(oldMail))

    let (h, mail, notes) = quitAndStart(old)
    #expect(h.frame(mail) == left)
    #expect(try #require(h.frame(notes)).width == 709)
    expectWindowsMatchLayout(h)
  }

  /// The hand that squeezed it in height lets it out again, and it is a window again, as wide as it was.
  @Test(.withTiles) func squeezedInHeightAndLetOutAgainItIsAWindowAgain() throws {
    let (h, mail, notes) = makeHarness()
    h.run("dock \(mail.rawValue) bottom")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) right")
    let before = try #require(h.frame(notes))
    #expect(before.width == 709)
    h.system.userFocus(mail)
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?[1]), by: 150)
    #expect(h.layout?.tiles.contains { $0.windows.contains(notes) } == true)
    h.run("home")
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?[1]), by: -150)
    h.run("home")
    #expect(h.frame(notes) == before)
    expectWindowsMatchLayout(h)
  }

  // MARK: What still ends it

  /// The windows in it change. What Notes had is shared out as any window's is (T06): Mail, which the hand made narrower, has less
  /// than the half it would have had.
  @Test func whenTheWindowClosesTheOthersShareWhatItHad() throws {
    let (h, mail, notes) = try docked()
    try Hand.gap.move(h, mail: mail, notes: notes, by: -60)
    h.system.close(notes)
    h.scheduler.runPending()
    #expect(!h.workspace.tree.hasLoans)
    #expect(try #require(h.frame(mail)).width == 649)
    #expect(h.layout?.desktopFrame?.width == 755)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// The room really is not there: on a smaller display Notes is served again, as any window is. Back on the larger one it has
  /// no less than the hand gave it.
  @Test func onASmallerDisplayRoomIsMadeAgain() throws {
    let (h, mail, notes) = try docked()
    try Hand.gap.move(h, mail: mail, notes: notes, by: -60)
    func display(_ width: CGFloat, _ height: CGFloat) -> DisplaySnapshot {
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: width, height: height),
        visibleFrame: CGRect(x: 0, y: 25, width: width, height: height - 25), isMain: true)
    }
    h.system.setDisplays([display(1280, 800)])
    h.scheduler.runPending()
    // In proportion it would have 683.
    #expect(try #require(h.frame(notes)).width == 709)
    expectWindowsMatchLayout(h)
    h.system.setDisplays([display(1440, 900)])
    h.scheduler.runPending()
    #expect(try #require(h.frame(notes)).width >= 769)
    expectWindowsMatchLayout(h)
  }

  /// A gap says nothing about a borrower on one side of it whom it has not resized, nor any of its lenders: [Notes | Mail | Desktop | Safari],
  /// and the gap between Notes and Mail. Safari goes on owing the Desktop, and pays when it leaves.
  @Test func aGapMovedElsewhereLeavesTheLoanAlone() throws {
    let (h, mail, notes) = makeHarness()
    let safari = h.system.open(
      app: "Safari", pid: 1004, frame: CGRect(x: 60, y: 60, width: 1324, height: 800), minimumSize: CGSize(width: 574, height: 240))
    h.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2240, height: 1260),
        visibleFrame: CGRect(x: 0, y: 25, width: 2240, height: 1235), isMain: true)
    ])
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    // A quarter each: 545. The Desktop lends 164 and 29 and is still a Desktop, so nobody else has lent anything.
    #expect(try #require(h.frame(notes)).width == 709)
    #expect(try #require(h.frame(safari)).width == 574)
    let leaf = h.workspace.tree.leaf(containing: mail)
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first { $0.trailing == leaf }), by: 20)
    #expect(h.workspace.tree.hasLoans, "Notes and Mail have changed size, Safari and the Desktop have not")
    let left = picture(h)
    h.run("home")
    #expect(picture(h) == left)
    let desktop = try #require(h.layout?.nodeFrames[h.workspace.tree.desktop]).width
    h.system.close(safari)
    h.scheduler.runPending()
    #expect(!h.workspace.tree.hasLoans)
    #expect(try #require(h.layout?.desktopFrame).width > desktop + 29, "what the Desktop lent is back, and its part of what Safari had of its own")
    expectWindowsMatchLayout(h)
  }

  /// The mark that a slot was squeezed outlives the tile. [Top over (Mail | Notes | Desktop)]: the row is squeezed in height, Top closes, and
  /// Notes is a window again. On a larger display it pays back what it can spare, like anybody.
  @Test(.withTiles) func squeezedOnceAndAWindowAgainItPaysBackWhatItCanSpare() throws {
    let (h, mail, notes) = makeHarness()
    let top = h.system.open(app: "Top", pid: 1004, frame: CGRect(x: 300, y: 100, width: 800, height: 400))
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) right")
    h.run("dock \(top.rawValue) top")
    #expect(try #require(h.frame(notes)).width == 709)
    let row = h.workspace.tree.parent(of: try #require(h.workspace.tree.leaf(containing: notes)))
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first { $0.trailing == row }), by: 250)
    #expect(h.layout?.tiles.contains { $0.windows.contains(notes) } == true)
    h.system.close(top)
    h.scheduler.runPending()
    #expect(try #require(h.frame(notes)).width == 709)
    h.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
    ])
    h.scheduler.runPending()
    #expect(try #require(h.frame(notes)).width == 709, "in proportion it would have 953")
    expectWindowsMatchLayout(h)
  }
}
