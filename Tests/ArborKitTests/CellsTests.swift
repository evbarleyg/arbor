import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A docked terminal keeps one frame (board 1.62). Its app sizes it in whole character cells, so it never has quite the size of
/// its slot. That is an answer, not a refusal and not a wish: what Arbor asks for comes from the slot, and what the app made of
/// it stands for as long as the slot comes out the same.
@Suite @MainActor struct CellsTests {
  enum Rounding: String, CaseIterable, Sendable { case nearest, down }

  /// Cells as Terminal and its like have them at ordinary fonts, and the board's 14 points.
  nonisolated static let cells = [
    CGSize(width: 7, height: 14), CGSize(width: 7, height: 15), CGSize(width: 8, height: 17), CGSize(width: 9, height: 19),
    CGSize(width: 13, height: 29),
  ]

  /// [terminal | Desktop | notes]
  func makeHarness(cell: CGSize, _ rounding: Rounding, margin: CGSize = .zero) -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let terminal = h.system.open(
      app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340), sizeStep: cell, stepsRoundDown: rounding == .down,
      sizeMargin: margin)
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(terminal.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    return (h, terminal, notes)
  }

  /// In the slot's top-left corner, where its app leaves it by itself, and less than a cell short of it: give or take the two points
  /// any window is allowed.
  func expectInItsCorner(
    _ h: Harness, _ window: WindowID, cell: CGSize, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let slot = try #require(h.layout?.windowFrames[window], "it is a tile or out of view", sourceLocation: sourceLocation)
    let frame = try #require(h.frame(window), sourceLocation: sourceLocation)
    #expect(frame.origin == slot.origin, "\(frame) in \(slot)", sourceLocation: sourceLocation)
    #expect(
      (-2..<cell.width).contains(slot.width - frame.width) && (-2..<cell.height).contains(slot.height - frame.height),
      "\(frame) in \(slot): within a cell, and not over", sourceLocation: sourceLocation)
  }

  // MARK: Ten layouts, one frame

  @Test(arguments: cells, Rounding.allCases)
  func tenLayoutsOfTheSameSlotLeaveItAlone(cell: CGSize, rounding: Rounding) throws {
    let (h, terminal, _) = makeHarness(cell: cell, rounding)
    try expectInItsCorner(h, terminal, cell: cell)
    let frame = try #require(h.frame(terminal))
    h.system.clearFrameLog()
    for _ in 0..<10 { h.controller.apply(settings: h.controller.settings) }
    #expect(h.frame(terminal) == frame)
    #expect(h.system.frameLog.filter { $0.window == terminal }.isEmpty, "asked again for the same slot")
    #expect(h.staleLayouts().isEmpty)
  }

  /// ⌃⌥0 and back, ten times: the slot goes and comes back the same, and so does the window: at every return one road, no
  /// growing by a cell to be talked down again.
  @Test(arguments: cells, Rounding.allCases)
  func theViewGoesAwayAndComesBackTenTimes(cell: CGSize, rounding: Rounding) throws {
    let (h, terminal, notes) = makeHarness(cell: cell, rounding)
    let frame = try #require(h.frame(terminal))
    for round in 1...10 {
      h.run("zoom \(notes.rawValue)")
      let mark = h.system.moveLog.count
      h.run("home")
      #expect(h.frame(terminal) == frame, "round \(round)")
      let road = h.system.road(of: terminal, since: mark)
      #expect(FakeWindowSystem.detour(road) == nil, "round \(round)")
      #expect(road.allSatisfy { $0.size == frame.size }, "round \(round): it came back by way of another size: \(road)")
    }
    try expectInItsCorner(h, terminal, cell: cell)
    #expect(h.staleLayouts().isEmpty)
  }

  /// The same with the terminal itself zoomed in on: two slots, each with its own answer.
  @Test(arguments: cells, Rounding.allCases)
  func zoomedInOnAndBackTenTimes(cell: CGSize, rounding: Rounding) throws {
    let (h, terminal, _) = makeHarness(cell: cell, rounding)
    let home = try #require(h.frame(terminal))
    h.run("zoom \(terminal.rawValue)")
    try expectInItsCorner(h, terminal, cell: cell)
    let zoomed = try #require(h.frame(terminal))
    h.run("home")
    for round in 1...10 {
      var mark = h.system.moveLog.count
      h.run("zoom \(terminal.rawValue)")
      #expect(h.frame(terminal) == zoomed, "round \(round)")
      #expect(FakeWindowSystem.detour(h.system.road(of: terminal, since: mark)) == nil, "round \(round), in")
      mark = h.system.moveLog.count
      h.run("home")
      #expect(h.frame(terminal) == home, "round \(round)")
      #expect(FakeWindowSystem.detour(h.system.road(of: terminal, since: mark)) == nil, "round \(round), out")
    }
    #expect(h.staleLayouts().isEmpty)
  }

  /// The board's proof: cells of 15 points, taken to the nearest. Ten acts that lay out the same slot: one size throughout, and
  /// each time the window comes back it is one frame that is set.
  @Test func eachReturnIsOneFrameSet() throws {
    let (h, terminal, notes) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest)
    let size = try #require(h.frame(terminal)).size
    #expect(size.height == 840, "offered 851 it took 855, and was talked down: \(size)")
    for round in 1...10 {
      h.run("zoom \(notes.rawValue)")
      h.system.clearFrameLog()
      h.run("home")
      let asked = h.system.frameLog.filter { $0.window == terminal }
      #expect(asked.count == 1, "round \(round): \(asked)")
      #expect(h.frame(terminal)?.size == size, "round \(round)")
    }
  }

  /// Nobody can know a cell before an app has shown it. So a terminal reaches out of its slot and is talked down once for its
  /// width and once for its height, whatever slots it is given afterwards: until its font changes, `relayout`, or Arbor starts again.
  @Test(arguments: cells + (3...36).map { CGSize(width: $0, height: $0) }, [CGSize.zero, CGSize(width: 2, height: 4)])
  func itIsTalkedDownOnce(cell: CGSize, margin: CGSize) throws {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.system.setSizeStep(terminal, cell, margin: margin)
    h.start()
    var detours: [String] = []
    func run(_ command: String) throws {
      let mark = h.system.moveLog.count
      h.run(command)
      if let detour = FakeWindowSystem.detour(h.system.road(of: terminal, since: mark)) { detours.append("\(command): \(detour)") }
      try expectInItsCorner(h, terminal, cell: cell)
    }
    let steps = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, -5, -5, -5, -5, -5, -5, 1, 1, 1, 1, 1, 1, 17, -40, 23]
    try run("dock \(terminal.rawValue) left")
    try run("dock \(notes.rawValue) right")
    for step in steps { try run("resize \(terminal.rawValue) right \(step)") }
    try run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    for step in steps { try run("resize \(terminal.rawValue) bottom \(step)") }
    try run("zoom \(terminal.rawValue)")
    try run("home")
    #expect(detours.filter { $0.contains("width") }.count <= 1, "\(detours)")
    #expect(detours.filter { $0.contains("height") }.count <= 1, "\(detours)")
    #expect(detours.allSatisfy { $0.contains("width") || $0.contains("height") }, "\(detours)")
  }

  // MARK: Nobody pays for a cell

  /// The shares are the tree's: what an app answers changes no weight and moves no neighbour.
  @Test(arguments: cells, Rounding.allCases)
  func theSharesAndTheNeighboursStayAsTheyAre(cell: CGSize, rounding: Rounding) throws {
    let (h, terminal, notes) = makeHarness(cell: cell, rounding)
    let tree = h.workspace.tree
    let slot = try #require(h.layout?.windowFrames[terminal])
    let neighbour = try #require(h.frame(notes))
    h.system.clearFrameLog()
    for _ in 0..<10 {
      h.run("zoom \(notes.rawValue)")
      h.run("home")
      h.controller.apply(settings: h.controller.settings)
      h.scheduler.runPending()
    }
    #expect(h.workspace.tree == tree)
    #expect(h.layout?.windowFrames[terminal] == slot)
    #expect(h.frame(notes) == neighbour)
    #expect(h.layout?.tiles.isEmpty == true, "a cell is no minimum")
  }

  /// What is asked for is worked out from the slot, whatever the window answered last time.
  @Test(arguments: cells, Rounding.allCases)
  func whatIsAskedForComesFromTheSlot(cell: CGSize, rounding: Rounding) throws {
    let (h, terminal, _) = makeHarness(cell: cell, rounding)
    // Every width a seam can give it, there and back, so that every remainder is met.
    for step in [3, 3, 3, 3, 3, 3, 3, -3, -3, -3, -3, -3, -3, -3] {
      h.run("resize \(terminal.rawValue) right \(step)")
      try expectInItsCorner(h, terminal, cell: cell)
    }
    #expect(h.staleLayouts().isEmpty)
  }

  /// One slot, one frame, whatever Arbor happens to know by then. A point or two over its slot any window may be, so a terminal whose
  /// nearest cell is that is left there before its cell is known, and must not be a cell smaller in the same slot afterwards.
  @Test(arguments: cells + [CGSize(width: 5, height: 5), CGSize(width: 6, height: 11)], Rounding.allCases)
  func oneSlotOneFrameWhateverIsKnown(cell: CGSize, rounding: Rounding) throws {
    for margin in [CGSize.zero, CGSize(width: 2, height: 4), CGSize(width: 3, height: 1)] {
      let (h, terminal, _) = makeHarness(cell: cell, rounding, margin: margin)
      var frames: [CGFloat: CGRect] = [:]
      for _ in 0..<3 {
        for step in [1, 2, 3, 2, 1, 3, 2, 2, 1, 3, -3, -1, -2, -2, -3, -1, -2, -3, -2, -1] {
          h.run("resize \(terminal.rawValue) right \(step)")
          let slot = try #require(h.layout?.windowFrames[terminal])
          let frame = try #require(h.frame(terminal))
          // Not what a window that was left alone for a point's difference has (`isInPlace`): what it is given when it is asked.
          guard abs(slot.width - frame.width) > 1 else { continue }
          if let before = frames[slot.width] { #expect(frame == before, "in a slot \(slot.width) wide, margin \(margin)") }
          frames[slot.width] = frame
        }
      }
    }
  }

  /// A real terminal is a title bar and a margin and then whole cells, so its sizes are no multiples of anything.
  @Test(arguments: Rounding.allCases)
  func aTitleBarAndAMarginBesideTheCells(rounding: Rounding) throws {
    let cell = CGSize(width: 7, height: 15)
    let (h, terminal, notes) = makeHarness(cell: cell, rounding, margin: CGSize(width: 10, height: 39))
    try expectInItsCorner(h, terminal, cell: cell)
    let frame = try #require(h.frame(terminal))
    for _ in 0..<10 {
      h.run("zoom \(notes.rawValue)")
      h.run("home")
    }
    #expect(h.frame(terminal) == frame)
  }

  // MARK: What is not rounding

  /// A hand is never an app's rounding. A terminal follows a hand in whole cells: pulled by less than half a cell it stays as it is, and
  /// nothing has happened; pulled further it is a cell wider, and the gap follows the hand as it follows any window's edge.
  @Test func aPullByAHandIsNotTakenForAnAnswer() throws {
    let cell = CGSize(width: 7, height: 15)
    let (h, terminal, notes) = makeHarness(cell: cell, .nearest)
    let slot = try #require(h.layout?.windowFrames[terminal])
    let frame = try #require(h.frame(terminal))
    func pull(by points: CGFloat) {
      var pulled = h.frame(terminal)!
      pulled.size.width += points
      h.system.userResize(terminal, to: pulled)
      h.scheduler.runPending()
    }
    pull(by: 3)
    #expect(h.frame(terminal) == frame && h.layout?.windowFrames[terminal] == slot, "less than half a cell is nothing")
    pull(by: 5)
    #expect(h.frame(terminal)?.width == frame.width + 7, "a cell")
    #expect(try #require(h.layout?.windowFrames[terminal]).maxX == frame.maxX + 7, "the gap follows the hand")
    pull(by: 21)
    #expect(h.frame(terminal)?.width == frame.width + 28)
    try expectInItsCorner(h, terminal, cell: cell)
    // What was learnt of its cells still holds: it comes back in one move.
    h.run("zoom \(notes.rawValue)")
    h.system.clearFrameLog()
    h.run("home")
    #expect(h.system.frameLog.filter { $0.window == terminal }.count == 1)
  }

  /// Pulled by one cell, whatever is left of its slot: the window is in the slot's corner, so all that is left lies on the side that is
  /// pulled, and a cell more can end within a few points of the slot's own edge. It is a hand's doing all the same, and stands.
  @Test(arguments: 0..<7) func aPullByOneCellStandsWhateverIsLeftOfTheSlot(wider: Int) throws {
    let cell = CGSize(width: 7, height: 15)
    let (h, terminal, notes) = makeHarness(cell: cell, .nearest, margin: CGSize(width: 2, height: 4))
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) right")
    h.run("resize \(terminal.rawValue) right \(wider)")
    let frame = try #require(h.frame(terminal))
    var pulled = frame
    pulled.size.width += cell.width
    h.system.userResize(terminal, to: pulled)
    h.scheduler.runPending()
    #expect(h.frame(terminal) == pulled, "the hand's size stands")
    #expect(try #require(h.frame(notes)).minX >= pulled.maxX, "and the neighbour makes way")
    try expectInItsCorner(h, terminal, cell: cell)
  }

  @Test(arguments: 0..<15) func aPullByOneLineStandsToo(higher: Int) throws {
    let cell = CGSize(width: 7, height: 15)
    let (h, terminal, notes) = makeHarness(cell: cell, .nearest, margin: CGSize(width: 2, height: 4))
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    h.run("resize \(terminal.rawValue) bottom \(higher)")
    var pulled = try #require(h.frame(terminal))
    pulled.size.height += cell.height
    h.system.userResize(terminal, to: pulled)
    h.scheduler.runPending()
    #expect(h.frame(terminal) == pulled, "the hand's size stands")
    #expect(try #require(h.frame(notes)).minY >= pulled.maxY, "and the neighbour makes way")
  }

  /// A window that stops well short of its slot cannot grow. It still sits in the middle.
  @Test func aWindowThatCannotGrowIsStillInTheMiddle() throws {
    let h = Harness()
    let fixed = h.system.open(app: "Calculator", frame: CGRect(x: 300, y: 200, width: 230, height: 400))
    h.system.setMaximumSize(fixed, CGSize(width: 230, height: 400))
    h.start()
    h.run("dock \(fixed.rawValue) left")
    let slot = try #require(h.layout?.windowFrames[fixed])
    let frame = try #require(h.frame(fixed))
    #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1, "\(frame) in \(slot)")
  }

  /// Less than twenty points short, nobody can tell a window that cannot grow from a terminal whose cell is not known yet. It stays in
  /// the corner, where its app left it: no second move for the sake of symmetry.
  @Test func aFewPointsShortAndNothingKnownItStaysInTheCorner() throws {
    let h = Harness()
    let other = h.system.open(app: "Notes")
    let fixed = h.system.open(app: "Settings", frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    h.system.setMaximumSize(fixed, CGSize(width: 3000, height: 400))
    h.start()
    h.run("dock \(other.rawValue) left")
    let mark = h.system.moveLog.count
    h.run("dock \(fixed.rawValue) beside \(other.rawValue) bottom")
    let slot = try #require(h.layout?.windowFrames[fixed])
    #expect((2..<20).contains(slot.height - 400), "\(slot)")
    #expect(h.frame(fixed) == CGRect(origin: slot.origin, size: CGSize(width: slot.width, height: 400)))
    #expect(FakeWindowSystem.detour(h.system.road(of: fixed, since: mark)) == nil)
  }

  /// An app that takes a new size a moment late answers with the size it still has. That looks like a window that misses what it is
  /// asked for, by whatever the gap was moved: like cells. A moment later it is seen at the very size it was asked for, which a
  /// terminal never is. Believed, it would be fitted to cells it does not have, for good: all it would ever be asked for is on their grid.
  /// (Growing. One that is slow to SHRINK looks like one that refuses to, and is a tile for ten minutes: an older matter, in the ledger.)
  @Test(arguments: [10, 6, 3, 17]) func anAppThatIsOnlySlowHasNoCells(step: Int) throws {
    let h = Harness()
    let slow = h.system.open(app: "Slow", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(slow.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.resizesLate = [slow]
    for _ in 0..<4 {
      h.run("resize \(slow.rawValue) right \(step)")
      h.system.appsSettle()
      h.scheduler.runPending()
    }
    h.system.resizesLate = []
    for odd in [3, 4, -5, 2] {
      h.run("resize \(slow.rawValue) right \(odd)")
      #expect(h.frame(slow) == h.layout?.windowFrames[slow], "it takes any size, and is asked for its slot")
    }
  }

  /// The same in a hurry: the gap is dragged on before the app has caught up.
  @Test(arguments: [10, 6, 3, 17]) func norWhenItNeverCatchesUpUntilTheEnd(step: Int) throws {
    let h = Harness()
    let slow = h.system.open(app: "Slow", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(slow.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.resizesLate = [slow]
    for _ in 0..<4 { h.run("resize \(slow.rawValue) right \(step)") }
    h.system.appsSettle()
    h.scheduler.runPending()
    h.system.resizesLate = []
    for odd in [3, 4, -5, 2] {
      h.run("resize \(slow.rawValue) right \(odd)")
      #expect(h.frame(slow) == h.layout?.windowFrames[slow], "it takes any size, and is asked for its slot")
    }
  }

  /// Late at one read only. At 464 it is asked for 454 and still shows 464; asked for less it takes that at once. It has been talked down
  /// like a terminal, and is twenty points short of its slot for nothing. The point less that it is asked for next it gives, which
  /// no terminal does: it is offered its slot again, and has it.
  @Test func anAppThatWasLateOnceHasItsSlotAtOnce() throws {
    let h = Harness()
    let slow = h.system.open(app: "Slow", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(slow.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    var asked = 0
    h.system.willSetFrame = { [system = h.system] window, _ in
      guard window == slow else { return }
      asked += 1
      system.resizesLate = asked == 1 ? [slow] : []
    }
    h.run("resize \(slow.rawValue) right -10")
    h.system.willSetFrame = nil
    #expect(h.frame(slow) == h.layout?.windowFrames[slow])
    for odd in [3, 4, -5, 2, -26, 11] {
      h.run("resize \(slow.rawValue) right \(odd)")
      #expect(h.frame(slow) == h.layout?.windowFrames[slow], "it takes any size, and is asked for its slot")
    }
  }

  /// Always one request behind: what it shows is what it was asked for the time before. Asked for 454 it shows 464; asked for less it shows
  /// 454. It has come down like a terminal, but to what it was asked for a moment ago, which slowness explains.
  @Test func anAppOneRequestBehindHasNoCells() throws {
    let h = Harness()
    let slow = h.system.open(app: "Slow", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(slow.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.resizesLate = [slow]
    h.system.willSetFrame = { [system = h.system] window, _ in if window == slow { system.appsSettle() } }
    h.run("resize \(slow.rawValue) right -10")
    h.system.willSetFrame = nil
    h.system.appsSettle()
    h.system.resizesLate = []
    h.scheduler.runPending()
    h.scheduler.advance(by: 5)
    for odd in [3, 4, -5, 2, 11, -7] {
      h.run("resize \(slow.rawValue) right \(odd)")
      #expect(h.frame(slow) == h.layout?.windowFrames[slow], "it takes any size, and is asked for its slot")
    }
  }

  /// A sheet is open: for a while the window will not be narrower than 460. It refuses, is a tile, the sheet closes, and it takes what it
  /// refused. Then it takes less, to the point. None of that is a cell.
  @Test func aLeastSizeThatPassesIsNoCell() throws {
    let h = Harness()
    let editor = h.system.open(app: "Editor", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.setMinimumSize(editor, CGSize(width: 460, height: 0))
    h.run("resize \(editor.rawValue) right -10")
    h.system.setMinimumSize(editor, .zero)
    h.run("relayout")
    for step in [-26, 5, 7, 11, 100, -3] {
      h.run("resize \(editor.rawValue) right \(step)")
      #expect(h.frame(editor) == h.layout?.windowFrames[editor], "after \(step)")
    }
  }

  /// Nor one that comes down: 460 at first, 448 later.
  @Test func aLeastSizeThatComesDownIsNoCell() throws {
    let h = Harness()
    let browser = h.system.open(app: "Browser", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(browser.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.setMinimumSize(browser, CGSize(width: 460, height: 0))
    h.run("resize \(browser.rawValue) right -10")
    h.system.setMinimumSize(browser, CGSize(width: 448, height: 0))
    h.run("relayout")
    h.run("resize \(browser.rawValue) right -10")
    h.system.setMinimumSize(browser, .zero)
    h.run("relayout")
    for step in [20, 7, 50, -3, -11] {
      h.run("resize \(browser.rawValue) right \(step)")
      #expect(h.frame(browser) == h.layout?.windowFrames[browser], "after \(step)")
    }
  }

  /// An app that always takes the next larger cells, never the nearest. Nobody has met one, but it must not end as a tile or give cells away.
  @Test(arguments: [CGFloat(7), 10, 15]) func anAppThatAlwaysRoundsUp(cell: CGFloat) throws {
    let h = Harness()
    let odd = h.system.open(app: "Odd", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.start()
    // Played with the hook: whatever is asked for, the window is given the next larger whole cells first.
    h.system.setSizeStep(odd, CGSize(width: cell, height: 1), down: true, margin: CGSize(width: cell - 0.001, height: 0))
    h.run("dock \(odd.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    for step in [3, 3, 3, 3, -5, -5, 2, 2, 9] {
      h.run("resize \(odd.rawValue) right \(step)")
      #expect(h.layout?.tiles.isEmpty == true, "after \(step)")
    }
  }

  // MARK: What costs nothing, and what is foretold

  @Test func aSlotThatChangesByLessThanACellCostsNoRequest() throws {
    let (h, terminal, _) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest)
    // Until its width has shown its cell too.
    for step in [3, 3, 3, 3, 3, 3, 3] { h.run("resize \(terminal.rawValue) right \(step)") }
    let width = try #require(h.frame(terminal)).width
    var idle = 0
    for step in [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1] {
      h.system.clearFrameLog()
      h.run("resize \(terminal.rawValue) right \(step)")
      let asked = h.system.frameLog.filter { $0.window == terminal }
      #expect(asked.count <= 1)
      if asked.isEmpty { idle += 1 }
    }
    #expect(h.frame(terminal)?.width == width + 14, "two cells in fourteen points")
    #expect(idle == 12, "and two requests")
  }

  /// What is foretold is to the point what is asked for, with cells too: nothing goes unclaimed, and nobody waits alone.
  @Test func whatIsForetoldOfATerminalIsWhatIsAsked() throws {
    let (h, terminal, notes) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest, margin: CGSize(width: 2, height: 4))
    let other = h.system.open(app: "Mail")
    h.run("dock \(other.rawValue) beside \(terminal.rawValue) bottom")
    for step in [3, 3, 3, 3, 3, 3, 3] { h.run("resize \(terminal.rawValue) right \(step)") }
    for step in [4, 4, 4, 4, 4, 4, 4] { h.run("resize \(terminal.rawValue) bottom \(step)") }
    h.run("zoom \(notes.rawValue)")
    let back = h.measure { h.run("home") }
    #expect(back.unclaimedMoves == 0 && back.movesAlone == 0 && back.waste == 0, "\(back)")
    // The gap moves by less than a cell: the others go, the terminal has nothing to do, and nothing is foretold for it.
    let gap = h.measure { h.run("resize \(terminal.rawValue) right 1") }
    #expect(gap.unclaimedMoves == 0 && gap.waste == 0, "\(gap)")
  }

  /// Three terminals and a gap that moves: two of them are asked where they stand and are then where they belong. Nothing more is
  /// foretold for them, for nothing more is asked.
  @Test func whoIsThereAfterAnsweringIsNotForetoldAgain() throws {
    let h = Harness()
    func terminal(_ size: CGSize, _ cell: CGSize, _ margin: CGSize, down: Bool = false) -> WindowID {
      h.system.open(
        app: "Terminal", pid: Int32(2000 + h.system.windows.count), frame: CGRect(origin: CGPoint(x: 300, y: 200), size: size),
        sizeStep: cell, stepsRoundDown: down, sizeMargin: margin)
    }
    _ = terminal(CGSize(width: 259, height: 333), CGSize(width: 5, height: 15), CGSize(width: 9, height: 33))
    _ = terminal(CGSize(width: 256, height: 359), CGSize(width: 5, height: 17), CGSize(width: 6, height: 19))
    let third = terminal(CGSize(width: 460, height: 222), CGSize(width: 9, height: 11), CGSize(width: 10, height: 2), down: true)
    _ = h.system.open(app: "Notes")
    h.start()
    h.run("arrange")
    h.scheduler.runPending()
    let budget = h.measure { h.run("resize \(third.rawValue) left -10") }
    #expect(budget.unclaimedMoves == 0, "\(budget)")
  }

  // MARK: Fonts that no sighting tells

  /// The font is changed and the window happens to keep a size that is on the old grid as well. Asked for whole cells of the old kind it
  /// takes something else: that ends what was known. It is learnt anew, once, and holds again.
  @Test(arguments: [
    (CGSize(width: 7, height: 15), CGSize(width: 14, height: 30)), (CGSize(width: 7, height: 15), CGSize(width: 7, height: 10)),
    (CGSize(width: 8, height: 18), CGSize(width: 12, height: 12)),
  ])
  func anotherFontThatNoSightingTells(from old: CGSize, to new: CGSize) throws {
    let (h, terminal, notes) = makeHarness(cell: old, .nearest)
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    h.run("resize \(terminal.rawValue) bottom 28")
    h.system.setSizeStep(terminal, new)
    // Twice, for its width and its height may show at different returns.
    for _ in 0..<2 {
      h.run("zoom \(notes.rawValue)")
      h.run("home")
    }
    let frame = try #require(h.frame(terminal))
    try expectInItsCorner(h, terminal, cell: new)
    for round in 1...5 {
      h.run("zoom \(notes.rawValue)")
      h.system.clearFrameLog()
      h.run("home")
      #expect(h.system.frameLog.filter { $0.window == terminal }.count == 1, "round \(round)")
      #expect(h.frame(terminal) == frame, "round \(round)")
    }
  }

  /// The same, slot after slot from the moment the font changes: whichever way the first answer misses, it is never left more than a cell
  /// of the new font short, or out of its corner.
  @Test(arguments: 0..<30) func aFontTwiceAsLargeIsToldByTheFirstAnswerThatMisses(higher: Int) throws {
    let (old, new) = (CGSize(width: 7, height: 15), CGSize(width: 14, height: 30))
    let (h, terminal, notes) = makeHarness(cell: old, .nearest)
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    // Until its height has shown its cell.
    for _ in 0..<5 { h.run("resize \(terminal.rawValue) bottom 4") }
    h.system.setSizeStep(terminal, new)
    h.run("resize \(terminal.rawValue) bottom \(higher + 3)")
    try expectInItsCorner(h, terminal, cell: new)
  }

  /// ⌘+ in a real Terminal: it keeps its rows and columns, so the window resizes itself, and is seen between two of its old cells. That is
  /// told at once: the next thing it is asked for is its slot, not whole cells of a font it no longer has.
  @Test func aFontChangeThatIsSeenCostsNoWrongRequest() throws {
    let (h, terminal, _) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest)
    let slot = try #require(h.layout?.windowFrames[terminal])
    let before = try #require(h.frame(terminal))
    h.system.setSizeStep(terminal, CGSize(width: 8, height: 17))
    let mark = h.system.moveLog.count
    h.system.userMove(terminal, to: CGRect(origin: before.origin, size: CGSize(width: before.width / 7 * 8, height: before.height / 15 * 17)))
    h.scheduler.runPending()
    let first = try #require(h.system.moveLog[mark...].first { $0.window == terminal })
    #expect(first.requested.size == slot.size, "\(first.requested)")
  }

  /// A trip into full screen, where a window is as large as macOS makes it, costs it nothing of what is known.
  @Test func fullScreenAndBackItsCellsAreStillKnown() throws {
    // With a margin, so that the display's own height is no whole number of its cells.
    let (h, terminal, notes) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest, margin: CGSize(width: 2, height: 14))
    let frame = try #require(h.frame(terminal))
    #expect(frame.height == 839, "offered 851 it took 854 and was talked down, so its cell is known: \(frame)")
    h.system.enterFullScreen(terminal, leaving: [notes])
    h.scheduler.advance(by: 2)
    h.system.leaveFullScreen(terminal, with: [notes], deafFor: 0)
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == frame)
    h.run("zoom \(notes.rawValue)")
    h.system.clearFrameLog()
    h.run("home")
    #expect(h.system.frameLog.filter { $0.window == terminal }.count == 1)
    #expect(h.frame(terminal) == frame)
  }

  /// A window that is known to grow no further is in the middle of its slot however little is missing: it does not leap from the
  /// corner to the middle where a gap is moved by a few points.
  @Test func oneThatIsKnownNotToGrowIsInTheMiddleHoweverLittleIsMissing() throws {
    let h = Harness()
    let fixed = h.system.open(app: "Calculator", frame: CGRect(x: 300, y: 200, width: 450, height: 600), isResizable: false)
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(fixed.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    for step in [0, 3, 3, 3, 3, 3, 3, 3, 3, -5, -5, -5] {
      h.run("resize \(fixed.rawValue) right \(step)")
      let slot = try #require(h.layout?.windowFrames[fixed])
      let frame = try #require(h.frame(fixed))
      #expect(abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1, "\(frame) in \(slot)")
    }
  }

  // MARK: Large cells, and other windows than docked ones

  /// Cells of 20 to 36 points, at a very large font: in the corner from the first moment on, whatever is known. Taking the nearest cells it
  /// is half a cell short at most until its cell has shown. (One that takes the cells that fit can be all but a cell short, never
  /// shows its cell, and more than twenty points short nobody can tell it from a window that cannot grow: it is in the middle then.)
  @Test(arguments: [CGSize(width: 13, height: 29), CGSize(width: 21, height: 35), CGSize(width: 18, height: 36)])
  func largeCellsRestInTheCornerToo(cell: CGSize) throws {
    let (h, terminal, notes) = makeHarness(cell: cell, .nearest)
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    for step in [12, 30, -30, 5, 5, 5, 5, 5, 5, 5, -17, -17] {
      h.run("resize \(terminal.rawValue) bottom \(step)")
      try expectInItsCorner(h, terminal, cell: cell)
    }
  }

  /// Alone on the Desktop and taking all of it (F18): the same window, the same cure.
  @Test func aTerminalThatFillsTheDesktopComesBackInOneMoveToo() throws {
    var settings = Settings.makingWay
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    let notes = h.system.open(app: "Notes")
    let terminal = h.system.open(
      app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340), sizeStep: CGSize(width: 7, height: 15),
      sizeMargin: CGSize(width: 2, height: 4))
    h.start()
    h.run("dock \(notes.rawValue) left")
    let desktop = try #require(h.layout?.desktopFrame)
    let frame = try #require(h.frame(terminal))
    #expect(frame.origin == desktop.origin, "\(frame) on \(desktop)")
    for round in 1...5 {
      h.run("zoom \(notes.rawValue)")
      let mark = h.system.moveLog.count
      h.run("home")
      #expect(h.frame(terminal) == frame, "round \(round)")
      #expect(FakeWindowSystem.detour(h.system.road(of: terminal, since: mark)) == nil, "round \(round)")
    }
  }

  /// Floating, and squeezed onto the Desktop (`floatingWindowsMakeWay`, which ships off): the same again.
  @Test func aFloatingTerminalSqueezedOntoTheDesktopComesBackInOneMoveToo() throws {
    let h = Harness(settings: .makingWay)
    let notes = h.system.open(app: "Notes")
    let other = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    let terminal = h.system.open(
      app: "Terminal", frame: CGRect(x: 300, y: 60, width: 1000, height: 800), sizeStep: CGSize(width: 7, height: 15),
      // The cells nearest to the Desktop's 702 points are 705: three over.
      sizeMargin: CGSize(width: 5, height: 4))
    h.start()
    h.run("dock \(notes.rawValue) left")
    _ = other
    let frame = try #require(h.frame(terminal))
    #expect(frame.width < 1000, "squeezed: \(frame)")
    for round in 1...5 {
      h.run("zoom \(notes.rawValue)")
      let mark = h.system.moveLog.count
      h.run("home")
      #expect(h.frame(terminal) == frame, "round \(round)")
      let road = h.system.road(of: terminal, since: mark)
      #expect(road.allSatisfy { $0.size == frame.size }, "round \(round): by way of another size: \(road)")
    }
    // Its cell is known by now. The Desktop becomes narrower, point by point: squeezed anew, it never reaches out of it to be talked down.
    for step in 1...14 {
      let mark = h.system.moveLog.count
      h.run("resize \(notes.rawValue) right 1")
      #expect(FakeWindowSystem.detour(h.system.road(of: terminal, since: mark)) == nil, "step \(step)")
    }
  }

  /// Float All, and it has its own size again, to the point (rule 5).
  @Test func itsOwnSizeComesBack() throws {
    let h = Harness()
    let terminal = h.system.open(
      app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340), sizeStep: CGSize(width: 7, height: 15),
      sizeMargin: CGSize(width: 2, height: 4))
    let own = try #require(h.system.windows[terminal]?.snapshot.frame)
    h.start()
    h.run("dock \(terminal.rawValue) left")
    h.run("zoom \(terminal.rawValue)")
    h.run("home")
    h.run("float-all")
    #expect(h.frame(terminal) == own)
  }

  /// A larger font: other cells, so what was learnt of the old ones is worth nothing.
  @Test func anotherFontIsLearntAnew() throws {
    let (h, terminal, notes) = makeHarness(cell: CGSize(width: 7, height: 15), .nearest)
    let larger = CGSize(width: 9, height: 19)
    h.system.setSizeStep(terminal, larger)
    let before = try #require(h.frame(terminal))
    h.system.userMove(
      terminal, to: CGRect(x: before.minX, y: before.minY, width: before.width / 7 * 9, height: before.height / 15 * 19))
    h.scheduler.runPending()
    try expectInItsCorner(h, terminal, cell: larger)
    let frame = try #require(h.frame(terminal))
    for _ in 0..<10 {
      h.run("zoom \(notes.rawValue)")
      h.run("home")
    }
    #expect(h.frame(terminal) == frame)
  }
}
