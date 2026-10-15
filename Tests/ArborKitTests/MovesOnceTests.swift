import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A window moves once, to where it ends up, also where an app does not take the size it is offered
/// (Controller+AskFirst.swift). A window of which nothing is known is asked for the size where it stands and goes to its
/// place afterwards, so what is checked is the road: it changes place once at most, and its left edge, its top edge,
/// its width and its height each go one way only, never past where they end up and back.
@Suite @MainActor struct MovesOnceTests {
  /// Every frame each window had while `body` ran and what it scheduled was done, beginning with the one it had before.
  func roads(_ h: Harness, during body: () -> Void) -> [WindowID: [CGRect]] {
    let mark = h.system.moveLog.count
    body()
    for _ in 0..<3 { h.scheduler.runPending() }
    var roads: [WindowID: [CGRect]] = [:]
    for move in h.system.moveLog[mark...] where move.before != move.after {
      roads[move.window, default: [move.before]].append(move.after)
    }
    return roads
  }

  func detour(_ road: [CGRect]) -> String? { FakeWindowSystem.detour(road) }

  /// `placesOnly`: a terminal that rounds up is talked down by a character cell (Controller+SizeSteps.swift), which is not at issue here.
  func expectStraightRoads(
    _ roads: [WindowID: [CGRect]], placesOnly: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    for (window, road) in roads.sorted(by: { $0.key < $1.key }) {
      let road = placesOnly ? road.map { CGRect(origin: $0.origin, size: .zero) } : road
      if let detour = detour(road) { Issue.record("\(window) \(detour)", sourceLocation: sourceLocation) }
    }
  }

  /// Nobody in view is asked to grow where it stands: a window grows in its slot, and one that turns out unable to goes on to the middle of
  /// it, as it is. `road` without the slot's corner, if that is how it ends; nil otherwise.
  func withoutTheWayToTheMiddle(_ road: [CGRect], of slot: CGRect?) -> [CGRect]? {
    guard let slot, road.count >= 3, let last = road.last else { return nil }
    let corner = road[road.count - 2]
    guard corner.origin == slot.origin, corner.size == last.size, slot.contains(corner), slot.contains(last), isCentred(last, in: slot)
    else { return nil }
    return road.dropLast(2) + [last]
  }

  /// How far a coordinate went beyond the straight way, there and back, as `FakeWindowSystem.detour` measures it.
  func excess(_ road: [CGRect], _ coordinate: KeyPath<CGRect, CGFloat>) -> CGFloat {
    guard let first = road.first, let last = road.last else { return 0 }
    return zip(road, road.dropFirst()).map { abs($1[keyPath: coordinate] - $0[keyPath: coordinate]) }.reduce(0, +)
      - abs(last[keyPath: coordinate] - first[keyPath: coordinate])
  }

  func isCentred(_ frame: CGRect?, in slot: CGRect?) -> Bool {
    guard let frame, let slot else { return false }
    return abs(frame.midX - slot.midX) <= 1 && abs(frame.midY - slot.midY) <= 1
  }

  /// Nor does the count of what it costs take any resize in place for a question.
  @Test func onlyAQuestionCountsAsAQuestion() {
    let system = FakeWindowSystem()
    let a = system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 600, height: 400), minimumSize: CGSize(width: 300, height: 200))
    func ask(_ width: CGFloat, x: CGFloat = 100) { system.setFrame(CGRect(x: x, y: 100, width: width, height: 400), of: a) }
    var mark = system.moveLog.count
    func tally() -> Budget {
      defer { mark = system.moveLog.count }
      return Budget.tally(system.moveLog[mark...])
    }
    ask(500); ask(400); ask(400, x: 700)
    var budget = tally()
    #expect(budget.questions == 2 && budget.waste == 0, "smaller, smaller still, and off it goes: \(budget)")
    ask(500); ask(400); ask(550); ask(450); ask(450, x: 100)
    budget = tally()
    #expect(budget.waste > 0, "there and back is no question: \(budget)")
    ask(200); ask(200); ask(200); ask(300, x: 700)
    budget = tally()
    #expect(budget.waste > 0, "nor is the same question again: \(budget)")
    ask(350, x: 100); ask(400)
    budget = tally()
    #expect(budget.questions == 0 && budget.repeatMoves == 1, "nor one that comes after the move: \(budget)")
  }

  /// The same measure as the detector on a Mac has, so that Linux lets nothing pass that a Mac would not: 4 points there and 4 back are 8.
  @Test func theCheckMeasuresAsTheDetectorOnAMacDoes() {
    func road(_ widths: CGFloat...) -> [CGRect] { widths.map { CGRect(x: 12, y: 37, width: $0, height: 851) } }
    #expect(detour(road(700, 497, 500)) == nil, "3 and 3 are 6")
    #expect(detour(road(700, 496, 500)) != nil)
    #expect(detour(road(700, 500, 400)) == nil)
  }

  @Test func theCheckItselfSeesADetour() {
    let start = CGRect(x: 300, y: 200, width: 640, height: 420)
    #expect(detour([start, CGRect(x: 300, y: 200, width: 700, height: 800), CGRect(x: 720, y: 33, width: 700, height: 800)]) == nil)
    // Corner, then middle.
    #expect(detour([start, CGRect(x: 8, y: 33, width: 640, height: 420), CGRect(x: 40, y: 250, width: 640, height: 420)]) != nil)
    // To the planned layout, then to the one that holds.
    #expect(detour([start, CGRect(x: 300, y: 200, width: 400, height: 420), CGRect(x: 300, y: 200, width: 500, height: 420)]) != nil)
  }

  // MARK: An app that will not make its window as small as the slot

  /// A first meeting: the newcomer will not be as narrow or as low as the slot it is offered, on each side of the window
  /// that gives it room. To the right of the gap that gives, and below it, its slot ends up beginning elsewhere than planned.
  @Test(arguments: ["left", "right", "top", "bottom"]) func aWindowThatRefusesItsSlotCostsNobodyADetour(side: String) throws {
    let h = Harness(settings: Settings())
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.start()
    h.run("dock \(a.rawValue) left")
    // Nothing is left over for a newcomer to take: it is offered half of A's place.
    h.run("dock \(b.rawValue) right")
    // Opened now, so that nothing has been asked of it yet.
    let large = h.system.open(
      app: "Large", frame: CGRect(x: 200, y: 60, width: 1000, height: 760), minimumSize: CGSize(width: 560, height: 560))
    let roads = roads(h) { h.run("dock \(large.rawValue) beside \(a.rawValue) \(side)") }
    let slot = try #require(h.layout?.windowFrames[large], "room was made for it")
    #expect(h.frame(large) == slot && slot.width >= 560 && slot.height >= 560)
    #expect(roads[a] != nil, "the neighbour gave room")
    expectStraightRoads(roads)
    expectWindowsMatchLayout(h)
  }

  /// The order of the work must not hang on who has the lower number.
  @Test(arguments: ["left", "right"]) func whicheverOfThemWasOpenedFirst(side: String) throws {
    let h = Harness()
    // Small enough to float undisturbed until it is docked.
    let large = h.system.open(
      app: "Large", frame: CGRect(x: 470, y: 60, width: 500, height: 760), minimumSize: CGSize(width: 480, height: 300))
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userMove(large, to: CGRect(x: 470, y: 60, width: 500, height: 760))
    let roads = roads(h) { h.run("dock \(large.rawValue) beside \(b.rawValue) \(side)") }
    #expect(try #require(h.frame(large)).width >= 480)
    expectStraightRoads(roads)
    expectWindowsMatchLayout(h)
  }

  /// Found by a random walk at ordinary sizes: the neighbour went to the planned layout and then to the one that held.
  @Test func aMusicPlayerBesideATerminal() throws {
    let h = Harness()
    h.start()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 388, y: 150, width: 543, height: 541))
    h.run("dock \(terminal.rawValue) right")
    let music = h.system.open(
      app: "Music", frame: CGRect(x: 689, y: 71, width: 854, height: 685), minimumSize: CGSize(width: 854, height: 432))
    let roads = roads(h) { h.run("dock \(music.rawValue) beside \(terminal.rawValue) right") }
    #expect(roads[terminal] != nil && roads[music] != nil)
    expectStraightRoads(roads)
    expectWindowsMatchLayout(h)
  }

  /// Another: on a laptop with a Dock the slot is five points lower than the window will go, and the neighbour moved twice for it.
  @Test func aFewPointsShortOnALaptopWithADock() throws {
    let laptop = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
      visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 827), isMain: true, isBuiltIn: true)
    let h = Harness(displays: [laptop])
    let finder = h.system.open(
      app: "Finder", frame: CGRect(x: 302, y: 264, width: 837, height: 449), minimumSize: CGSize(width: 501, height: 300))
    h.start()
    h.system.userFocus(finder)
    h.run("dock right")
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 289, y: 102, width: 1078, height: 539), minimumSize: CGSize(width: 760, height: 400))
    h.system.userFocus(mail)
    let roads = roads(h) { h.run("dock top") }
    #expect(roads[finder] != nil && roads[mail] != nil)
    expectStraightRoads(roads)
    expectWindowsMatchLayout(h)
  }

  /// There is no room to be made: it ends as a tile. The others have not shrunk for a layout that never came.
  @Test(.withTiles) func oneThatEndsAsATileCostsNobodyADetour() throws {
    let h = Harness()
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let large = h.system.open(
      app: "Large", frame: CGRect(x: 20, y: 60, width: 1400, height: 760), minimumSize: CGSize(width: 1380, height: 300))
    let roads = roads(h) { h.run("dock \(large.rawValue) beside \(a.rawValue) right") }
    #expect(h.layout?.tiles.contains { $0.windows.contains(large) } == true)
    expectStraightRoads(roads)
    expectWindowsMatchLayout(h)
  }

  /// A neighbour that has to give room and will not.
  @Test func aNeighbourThatRefusesToGiveRoomCostsNobodyADetour() throws {
    let h = Harness(displays: [Workload.largeDisplay])
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B", minimumSize: CGSize(width: 600, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    #expect(try #require(h.layout?.windowFrames[b]).width > 620, "it has not been asked for less than it will give")
    let d = h.system.open(app: "D")
    let all = roads(h) { h.run("dock \(d.rawValue) beside \(b.rawValue) left") }
    #expect(all[a] != nil || all[b] != nil)
    #expect(try #require(h.layout?.windowFrames[b]).width >= 600)
    expectStraightRoads(all)
    expectWindowsMatchLayout(h)
  }

  /// Its size cannot be changed and is more than the slot's. Accessibility says so beforehand, so nobody has to be asked.
  @Test func aWindowOfFixedSizeIsGivenRoomAtOnce() throws {
    let h = Harness()
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let fixed = h.system.open(app: "Fixed", frame: CGRect(x: 300, y: 100, width: 600, height: 500), isResizable: false)
    let roads = roads(h) { h.run("dock \(fixed.rawValue) beside \(a.rawValue) right") }
    #expect(roads[fixed]?.count == 2, "one move: \(roads[fixed] ?? [])")
    #expect(try #require(h.layout?.windowFrames[fixed]).width >= 600)
    #expect(isCentred(h.frame(fixed), in: h.layout?.windowFrames[fixed]))
    expectStraightRoads(roads)
    #expect(h.staleLayouts() == [])
  }

  /// A size a window has had it can have again: nobody is asked, and nobody waits for anybody.
  @Test func aSizeItHasHadBeforeIsNotAQuestion() throws {
    let h = Harness()
    let ids = (0..<4).map { h.system.open(app: "App\($0)", pid: Int32(3000 + $0)) }
    h.start()
    h.run("dock \(ids[0].rawValue) left")
    h.run("dock \(ids[1].rawValue) right")
    h.run("dock \(ids[2].rawValue) beside \(ids[0].rawValue) bottom")
    h.run("dock \(ids[3].rawValue) beside \(ids[1].rawValue) bottom")
    h.run("zoom \(ids[0].rawValue)")
    let budget = h.measure { h.run("back") }
    #expect(budget.movesAlone == 0 && budget.repeatMoves == 0 && budget.idleMoves == 0, "\(budget)")
  }

  // MARK: A window that cannot grow

  /// Its size cannot be changed at all.
  @Test func aWindowOfFixedSizeGoesStraightToTheMiddleOfItsSlot() throws {
    let h = Harness()
    let fixed = h.system.open(app: "Calculator", frame: CGRect(x: 500, y: 300, width: 230, height: 408), isResizable: false)
    h.start()
    let roads = roads(h) { h.run("dock \(fixed.rawValue) left") }
    #expect(roads[fixed]?.count == 2, "one move: \(roads[fixed] ?? [])")
    #expect(isCentred(h.frame(fixed), in: h.layout?.windowFrames[fixed]))
    #expect(h.frame(fixed)?.size == CGSize(width: 230, height: 408))
  }

  /// A first meeting with a window that has one fixed side, like a settings window, or two, and does not say so. That shows in its
  /// slot, where it grows: corner, then middle, both within the slot. Nobody else pays for it.
  @Test(arguments: ["left", "right", "top", "bottom"], [CGSize(width: 500, height: 2000), CGSize(width: 3000, height: 400), CGSize(width: 500, height: 400)])
  func aWindowThatTurnsOutUnableToGrowGoesOnToTheMiddleWithinItsSlot(side: String, most: CGSize) throws {
    let h = Harness()
    let a = h.system.open(app: "A")
    let settings = h.system.open(app: "Settings", frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    h.system.setMaximumSize(settings, most)
    h.start()
    h.run("dock \(a.rawValue) left")
    var roads = roads(h) { h.run("dock \(settings.rawValue) beside \(a.rawValue) \(side)") }
    #expect(isCentred(h.frame(settings), in: h.layout?.windowFrames[settings]))
    let road = try #require(roads[settings])
    // Where its slot asks for nothing it cannot do it fills the slot, and there is no such hop.
    if h.frame(settings) != h.layout?.windowFrames[settings] {
      roads[settings] = try #require(withoutTheWayToTheMiddle(road, of: h.layout?.windowFrames[settings]), "\(road)")
    }
    expectStraightRoads(roads)
    #expect(h.staleLayouts() == [])
  }

  /// From then on it is known, and it is moved with one request.
  @Test func oneThatCouldNotGrowIsMovedWithOneRequestFromThenOn() throws {
    let h = Harness()
    let settings = h.system.open(app: "Settings", frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    let notes = h.system.open(app: "Notes")
    h.system.setMaximumSize(settings, CGSize(width: 500, height: 2000))
    h.start()
    h.run("dock \(settings.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(settings.rawValue) bottom")
    h.run("float \(notes.rawValue)")

    func check(_ what: String, _ body: () -> Void, sourceLocation: SourceLocation = #_sourceLocation) {
      let mark = h.system.moveLog.count
      let roads = roads(h, during: body)
      let requests = h.system.moveLog[mark...].filter { $0.window == settings }.count
      #expect(requests == 1 && roads[settings]?.count == 2, "\(what): \(requests) requests, \(roads[settings] ?? [])", sourceLocation: sourceLocation)
      #expect(isCentred(h.frame(settings), in: h.layout?.windowFrames[settings]), "\(what)", sourceLocation: sourceLocation)
    }
    check("its slot changes") { h.run("dock \(notes.rawValue) beside \(settings.rawValue) bottom") }
    h.run("float \(settings.rawValue)")
    check("docked again, somewhere else") { h.run("dock \(settings.rawValue) beside \(notes.rawValue) top") }
    h.run("zoom \(notes.rawValue)")
    check("out of view and back") { h.run("back") }
    #expect(h.staleLayouts() == [])
  }

  /// Found by a random walk: corner, then middle, and again when it was docked on the other side. The first time nobody could know.
  @Test func aPreviewWindowDockedLeftAndThenRight() throws {
    let h = Harness()
    h.start()
    let preview = h.system.open(app: "Preview", frame: CGRect(x: 300, y: 200, width: 500, height: 455))
    h.system.setMaximumSize(preview, CGSize(width: 500, height: 2000))
    h.system.userFocus(preview)
    var all = roads(h) { h.run("dock left") }
    all[preview] = try #require(withoutTheWayToTheMiddle(all[preview] ?? [], of: h.layout?.windowFrames[preview]), "\(all)")
    expectStraightRoads(all)
    #expect(isCentred(h.frame(preview), in: h.layout?.windowFrames[preview]))
    all = roads(h) { h.run("toggle-float") }
    expectStraightRoads(all)
    let mark = h.system.moveLog.count
    all = roads(h) { h.run("dock right") }
    expectStraightRoads(all)
    #expect(h.system.moveLog[mark...].filter { $0.window == preview }.count == 1, "it is known by now")
    #expect(isCentred(h.frame(preview), in: h.layout?.windowFrames[preview]))
  }

  /// It stops a few points short of its slot, as a terminal would, so nobody calls that a limit. But the same slot gets the same answer.
  @Test func oneThatStopsJustShortOfItsSlotComesBackToTheMiddleOfIt() throws {
    let h = Harness()
    let preview = h.system.open(app: "Preview", frame: CGRect(x: 300, y: 100, width: 680, height: 600))
    let notes = h.system.open(app: "Notes")
    h.system.setMinimumSize(preview, CGSize(width: 680, height: 300))
    h.system.setMaximumSize(preview, CGSize(width: 680, height: 2000))
    h.start()
    h.run("dock \(preview.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(preview.rawValue) bottom")
    let slot = try #require(h.layout?.windowFrames[preview])
    #expect(slot.width > 690 && slot.width < 716, "\(slot)")
    h.run("zoom \(notes.rawValue)")
    let all = roads(h) { h.run("back") }
    #expect(all[preview]?.count == 2, "one move: \(all[preview] ?? [])")
    #expect(isCentred(h.frame(preview), in: h.layout?.windowFrames[preview]))
  }

  /// A gap dragged with the pointer: a quick hand takes it far in one step.
  @Test(.withTiles) func aGapDraggedFarCostsNobodyADetour() throws {
    let h = Harness(settings: Settings())
    let a = h.system.open(app: "A", minimumSize: CGSize(width: 500, height: 300))
    let preview = h.system.open(app: "Preview", frame: CGRect(x: 300, y: 100, width: 600, height: 600))
    h.system.setMaximumSize(preview, CGSize(width: 720, height: 2000))
    h.start()
    h.run("dock \(a.rawValue) left")
    // It takes all that is left: two halves of 702.
    h.run("dock \(preview.rawValue) beside \(a.rawValue) right")
    let seam = try #require(h.overlays.seams[h.display]?.first)
    // The one grows further than it can, the other is to be smaller than it goes.
    var roads = roads(h) { h.overlays.dragSeam(seam, by: -250) }
    let slot = try #require(h.layout?.windowFrames[preview])
    #expect(slot.width == 952 && h.frame(preview)?.width == 720 && h.layout?.tiles.contains { $0.windows.contains(a) } == true, "the case: \(slot)")
    // That it cannot shows in its slot, where it grows: corner, then middle, both within the slot.
    roads[preview] = try #require(withoutTheWayToTheMiddle(roads[preview] ?? [], of: slot), "\(roads)")
    expectStraightRoads(roads)
    #expect(h.staleLayouts() == [])
  }

  /// What was learnt can stop being true: a sheet was open. It is offered the whole slot every time, so it is found out.
  @Test func oneThatCanGrowAgainFillsItsSlotAtTheNextChange() throws {
    let h = Harness()
    let editor = h.system.open(app: "Editor", frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    let notes = h.system.open(app: "Notes")
    h.system.setMaximumSize(editor, CGSize(width: 500, height: 400))
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.system.setMaximumSize(editor, nil)
    h.run("dock \(notes.rawValue) beside \(editor.rawValue) bottom")
    #expect(h.frame(editor) == h.layout?.windowFrames[editor])
    // And that is the end of what was learnt.
    h.run("float \(notes.rawValue)")
    #expect(h.frame(editor) == h.layout?.windowFrames[editor])
    let roads = roads(h) { h.run("dock \(notes.rawValue) beside \(editor.rawValue) bottom") }
    #expect(roads[editor]?.count == 2 && h.frame(editor) == h.layout?.windowFrames[editor], "\(roads)")
    expectWindowsMatchLayout(h)
  }

  // MARK: What must not be taken for a limit

  /// A terminal takes whole character cells, a few points short of its slot. That is not a window that cannot grow: sent to
  /// the middle for the size it had, it would land far from where it ends up. How many cells go into a slot shows in the slot, where
  /// it grows, so it is set right there, by less than half a cell.
  @Test(arguments: [CGSize(width: 10, height: 15), CGSize(width: 7, height: 15)]) func aTerminalGrowsWithoutADetour(cell: CGSize) throws {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal")
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.system.setSizeStep(terminal, cell)
    h.start()
    func step(_ body: () -> Void, sourceLocation: SourceLocation = #_sourceLocation) {
      let mark = h.system.moveLog.count
      var roads = roads(h, during: body)
      if let road = roads.removeValue(forKey: terminal) {
        #expect(
          FakeWindowSystem.changesOfPlace(road) <= 1 && excess(road, \.minX) <= cell.width && excess(road, \.minY) <= cell.height, "\(road)",
          sourceLocation: sourceLocation)
      }
      expectStraightRoads(roads, placesOnly: true, sourceLocation: sourceLocation)
      let sizes = h.system.moveLog[mark...].filter { $0.window == terminal }.map { "\($0.requested.size)" }
      #expect(Set(sizes).count == sizes.count, "no size is asked for twice: \(sizes)", sourceLocation: sourceLocation)
    }
    step { h.run("dock \(terminal.rawValue) left") }
    for window in [a, b] { step { h.run("dock \(window.rawValue) right") } }
    for window in [a, b] { step { h.system.close(window) } }
    let slot = try #require(h.layout?.windowFrames[terminal])
    let frame = try #require(h.frame(terminal))
    #expect(slot.width - frame.width < cell.width + 1 && slot.height - frame.height < cell.height + 1, "\(frame) in \(slot)")
  }

  /// At a first meeting it rounds up and is talked down once.
  @Test func aTerminalIsTalkedDownOnce() throws {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal")
    h.system.setSizeStep(terminal, CGSize(width: 7, height: 15))
    h.start()
    let mark = h.system.moveLog.count
    let road = try #require(roads(h) { h.run("dock \(terminal.rawValue) right") }[terminal])
    #expect(FakeWindowSystem.changesOfPlace(road) == 1 && excess(road, \.minX) <= 7 && excess(road, \.minY) <= 15, "\(road)")
    let sizes = h.system.moveLog[mark...].filter { $0.window == terminal }.map(\.requested.size)
    #expect(Set(sizes.map { "\($0)" }).count == sizes.count, "no size is asked for twice: \(sizes)")
  }

  /// It is a few points short of any slot, so a slot that only becomes narrower is higher than it is. The width it has answered for where it stood
  /// is not offered again with the height, or it would round up and be talked down a second time.
  @Test func aSideThatHasAnsweredIsNotOfferedAgain() throws {
    let h = Harness(settings: Settings())
    let terminal = h.system.open(app: "Terminal")
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.system.setSizeStep(terminal, CGSize(width: 7, height: 15))
    h.start()
    h.run("dock \(terminal.rawValue) left")
    // Nothing is left over for a newcomer to take: it is offered half of the terminal's place.
    h.run("dock \(b.rawValue) right")
    let mark = h.system.moveLog.count
    let road = try #require(roads(h) { h.run("dock \(a.rawValue) beside \(terminal.rawValue) right") }[terminal])
    let slot = try #require(h.layout?.windowFrames[terminal])
    #expect(try #require(h.frame(terminal)).height < slot.height - 2, "the case: \(road) in \(slot)")
    let offers = h.system.moveLog[mark...].filter { $0.window == terminal && $0.requested.width == slot.width }
    #expect(offers.count == 1, "\(h.system.moveLog[mark...].filter { $0.window == terminal }.map(\.requested))")
    #expect(excess(road, \.width) == 0, "\(road)")
  }

  /// How many cells go into a slot shows only in the slot, where it grows, and the terminal is set right by less than a cell. Once: what
  /// it made of this size is remembered.
  @Test func aTerminalIsSetRightInItsSlotByLessThanACellOnce() throws {
    let h = Harness()
    let cell = CGSize(width: 7, height: 15)
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 200, width: 640, height: 420))
    h.system.setSizeStep(terminal, cell)
    h.start()
    let first = try #require(roads(h) { h.run("dock \(terminal.rawValue) right") }[terminal])
    #expect(FakeWindowSystem.changesOfPlace(first) == 1, "\(first)")
    let highest = try #require(first.map(\.minY).min())
    #expect(try #require(first.last).minY - highest < cell.height, "\(first)")
    #expect(isCentred(h.frame(terminal), in: h.layout?.windowFrames[terminal]))
    h.run("float \(terminal.rawValue)")
    h.system.userMove(terminal, to: CGRect(x: 300, y: 200, width: 640, height: 420))
    expectStraightRoads(roads(h) { h.run("dock \(terminal.rawValue) right") }, placesOnly: true)
    #expect(isCentred(h.frame(terminal), in: h.layout?.windowFrames[terminal]))
  }

  /// Accessibility said its size cannot be changed when it was first seen: a splash window that has become a main window since.
  @Test func aWindowThatWasFixedOnceIsNotFixedForLife() throws {
    let h = Harness()
    let splash = h.system.open(app: "Editor", frame: CGRect(x: 500, y: 300, width: 400, height: 300), isResizable: false)
    h.start()
    h.system.setMinimumSize(splash, .zero)
    h.system.setMaximumSize(splash, nil)
    h.run("dock \(splash.rawValue) left")
    #expect(h.frame(splash) == h.layout?.windowFrames[splash], "it is offered the whole slot, and takes it")
    expectWindowsMatchLayout(h)
  }

  /// And `relayout`, which tries every window again, tries this one.
  @Test func relayoutForgetsThatAWindowWasSaidToBeFixed() throws {
    let h = Harness()
    let a = h.system.open(app: "A")
    let fixed = h.system.open(app: "Editor", frame: CGRect(x: 300, y: 100, width: 900, height: 500), isResizable: false)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(fixed.rawValue) right")
    #expect(try #require(h.layout?.windowFrames[fixed]).width >= 900)
    h.system.setMinimumSize(fixed, .zero)
    h.system.setMaximumSize(fixed, nil)
    h.run("relayout")
    h.run("balance")
    #expect(h.frame(fixed) == h.layout?.windowFrames[fixed])
    expectWindowsMatchLayout(h)
  }

  /// macOS lets a window be as large as the display it is on allows, so whether it can grow is not asked on another display.
  @Test func aWindowIsNotAskedToGrowOnAnotherDisplay() throws {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let a = h.system.open(app: "A")
    h.start()
    h.run("dock \(a.rawValue) left")
    // What the first display allows.
    h.system.willSetFrame = { [system = h.system] window, frame in
      let onTheFirst = FakeWindowSystem.standardDisplay.frame.contains(frame.origin)
      system.setMaximumSize(window, onTheFirst ? FakeWindowSystem.standardDisplay.visibleFrame.size : nil)
    }
    let all = roads(h) { h.run("move-to-display next") }
    expectStraightRoads(all)
    #expect(h.frame(a) == h.controller.layouts[Workload.secondDisplay.id]?.windowFrames[a])
  }

  /// What is foretold is what is asked (`moveTogether`), for these windows too.
  @Test func nothingForetoldGoesUnclaimed() throws {
    let h = Harness()
    let fixed = h.system.open(
      app: "Calculator", pid: 4001, frame: CGRect(x: 500, y: 300, width: 230, height: 408), isResizable: false)
    let settings = h.system.open(app: "Settings", pid: 4002, frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    let notes = h.system.open(app: "Notes", pid: 4003)
    h.system.setMaximumSize(settings, CGSize(width: 500, height: 2000))
    h.start()
    h.run("dock \(fixed.rawValue) left")
    h.run("dock \(settings.rawValue) right")
    h.run("dock \(notes.rawValue) beside \(fixed.rawValue) bottom")
    h.run("zoom \(notes.rawValue)")
    let budget = h.measure { h.run("back") }
    #expect(budget.unclaimedMoves == 0 && budget.repeatMoves == 0 && budget.movesAlone == 0, "\(budget)")
  }

  /// Left so low that macOS would not let anybody put it there: resized, it would be pushed up. So it is not asked where it stands.
  @Test func aWindowLeftLowerThanMacOSLetsAnybodyPutOneIsNotAskedThere() throws {
    let h = Harness()
    let a = h.system.open(app: "A")
    h.start()
    h.system.userMove(a, to: CGRect(x: 580, y: 887, width: 640, height: 420))
    let mark = h.system.moveLog.count
    h.run("dock \(a.rawValue) bottom")
    #expect(h.system.moveLog[mark...].filter { $0.window == a }.count == 1)
    expectWindowsMatchLayout(h)
  }

  // MARK: Only just back

  /// A window just out of the Dock may not be ready to take a frame, and nothing is concluded from one that answers with the frame
  /// it has. One that has changed its size has heard the question, and need not be moved a second time half a second later.
  @Test func aWindowJustBackThatAnswersIsBelieved() throws {
    let h = Harness()
    let mail = h.system.open(
      app: "Mail", frame: CGRect(x: 128, y: 182, width: 1001, height: 511), minimumSize: CGSize(width: 760, height: 400))
    h.start()
    h.system.setMinimized(mail, true)
    h.system.setMinimized(mail, false)
    let all = roads(h) {
      h.run("dock \(mail.rawValue) right")
      h.scheduler.advance(by: 1)
    }
    expectStraightRoads(all)
    expectWindowsMatchLayout(h)
  }

  /// And one that cannot grow goes on to the middle at once, though nothing is concluded yet, and is not walked about again when it is.
  @Test func aWindowJustBackThatCannotGrowIsNotWalkedAboutWhenTheMomentIsOver() throws {
    let h = Harness()
    let preview = h.system.open(app: "Preview", frame: CGRect(x: 468, y: 62, width: 723, height: 650))
    h.system.setMinimumSize(preview, CGSize(width: 723, height: 400))
    h.system.setMaximumSize(preview, CGSize(width: 723, height: 2000))
    h.start()
    h.system.setMinimized(preview, true)
    h.system.setMinimized(preview, false)
    var all = roads(h) {
      h.run("dock \(preview.rawValue) top")
      h.scheduler.advance(by: 1)
    }
    all[preview] = try #require(withoutTheWayToTheMiddle(all[preview] ?? [], of: h.layout?.windowFrames[preview]), "\(all)")
    expectStraightRoads(all)
    #expect(isCentred(h.frame(preview), in: h.layout?.windowFrames[preview]))
  }

  // MARK: Out of view, and while a window is dragged

  /// A window out of view is asked out of view: nothing of it shows before it arrives.
  @Test func aWindowOutOfViewIsAskedOutOfView() throws {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    let c = h.system.open(app: "C")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b))
    // It comes back to a slot smaller than it has ever been.
    h.run("dock \(c.rawValue) beside \(a.rawValue) right")
    let mark = h.system.moveLog.count
    h.run("home")
    let road = h.system.moveLog[mark...].filter { $0.window == b }.map(\.after)
    let slot = try #require(h.layout?.windowFrames[b])
    for frame in road where frame != slot {
      for display in h.system.displayList {
        let showing = frame.intersection(display.frame)
        #expect(showing.isNull || showing.width <= 2 || showing.height <= 2, "\(frame) shows on \(display.id)")
      }
    }
    #expect(h.frame(b) == slot)
    expectWindowsMatchLayout(h)
  }

  /// The arrangement a drop would give is shown during the drag, and a window can refuse that as well.
  @Test func aTrialDuringADragCostsNobodyADetour() throws {
    var settings = Settings()
    settings.reflowWhileDragging = true
    let h = Harness(displays: [Workload.largeDisplay], settings: settings)
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B", minimumSize: CGSize(width: 600, height: 300))
    let d = h.system.open(app: "D", frame: CGRect(x: 2600, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    let slot = try #require(h.layout?.windowFrames[b])
    h.system.beginDrag(d)
    var roads = roads(h) { h.system.moveDrag(to: CGPoint(x: slot.minX + 20, y: slot.midY), holding: 1) }
    roads[d] = nil
    #expect(!roads.isEmpty, "the trial was shown")
    expectStraightRoads(roads)
    h.system.endDrag()
  }

  // MARK: Nobody in view is asked to grow where it stands

  /// The display of the recording that showed it: 1024×768, a Dock at the bottom.
  static let withADock = DisplaySnapshot(
    id: DisplayID("with-a-dock"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
    visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true)

  func expectEveryDockedWindowFillsItsSlot(_ h: Harness, _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
    for (window, slot) in (h.layout?.windowFrames ?? [:]).sorted(by: { $0.key < $1.key }) {
      #expect(h.frame(window) == slot, "\(window) after \(what)", sourceLocation: sourceLocation)
    }
  }

  /// macOS does not let a window grow across the bottom of the visible frame where it stands. That says nothing about
  /// the window: recorded on a Mac, where each of these windows ended up short of its slot, in the middle of it.
  @Test func aWindowThatStandsLowFillsItsSlotAtTheFirstLayout() {
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    let b = h.system.open(app: "B", frame: CGRect(x: 220, y: 180, width: 480, height: 348))
    let c = h.system.open(app: "C", frame: CGRect(x: 270, y: 140, width: 480, height: 348))
    h.start()
    let journey = [
      "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(a.rawValue) bottom", "zoom \(a.rawValue)",
      "back", "resize \(a.rawValue) right 100", "float \(b.rawValue)", "arrange", "desktop", "show-all", "zoom \(c.rawValue)", "back",
    ]
    for command in journey {
      let mark = h.system.moveLog.count
      let roads = roads(h) { h.run(command) }
      expectEveryDockedWindowFillsItsSlot(h, command)
      // But for a slot that begins where the window stands.
      for move in h.system.moveLog[mark...]
      where move.requested.origin == move.before.origin && Self.withADock.frame.contains(move.before)
        && move.requested != h.layout?.windowFrames[move.window]
      {
        #expect(
          move.requested.width <= move.before.width + 1 && move.requested.height <= move.before.height + 1,
          "\(move.window) was asked for \(move.requested) at \(move.before) by \(command)")
      }
      for (window, road) in roads.sorted(by: { $0.key < $1.key }) where h.workspace.isDocked(window) {
        if let detour = detour(road) { Issue.record("\(window) \(detour) at \(command)") }
      }
      expectWindowsMatchLayout(h)
    }
  }

  /// By hand as by command.
  @Test func aWindowDroppedFromLowOnTheDisplayFillsItsSlot() throws {
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 300, y: 330, width: 480, height: 348))
    h.start()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: 400, y: 340), CGPoint(x: 200, y: 400), CGPoint(x: 3, y: 450)])
    try #require(h.workspace.isDocked(a), "it docked")
    expectEveryDockedWindowFillsItsSlot(h, "the drop")
  }

  /// That a window cannot grow shows in its slot, then. It goes on to the middle, within the slot, and never again by that way.
  @Test func aWindowThatTurnsOutUnableToGrowGoesOnToTheMiddleWithinItsSlotOnce() throws {
    let h = Harness(displays: [Self.withADock])
    let limited = h.system.open(app: "Limited", frame: CGRect(x: 170, y: 220, width: 400, height: 300))
    h.system.setMaximumSize(limited, CGSize(width: 440, height: 348))
    h.start()
    let first = try #require(roads(h) { h.run("dock \(limited.rawValue) left") }[limited])
    let slot = try #require(h.layout?.windowFrames[limited])
    #expect(first.count == 3 && first.dropFirst().allSatisfy { slot.contains($0) }, "\(first) in \(slot)")
    #expect(h.frame(limited)?.size == CGSize(width: 440, height: 348) && isCentred(h.frame(limited), in: slot))
    h.run("float \(limited.rawValue)")
    h.system.userMove(limited, to: CGRect(x: 170, y: 220, width: 400, height: 300))
    expectStraightRoads(roads(h) { h.run("dock \(limited.rawValue) left") })
    #expect(isCentred(h.frame(limited), in: h.layout?.windowFrames[limited]))
  }

  /// An app that carries out a move late is still at its old place when it is asked for the size, and takes the room there is there. Taken
  /// for a refusal that would be remembered, and the window short of every slot from then on.
  @Test func anAnswerThatEndsOnTheLineOfWhereTheWindowStoodIsNoRefusal() throws {
    let h = Harness(displays: [Self.withADock])
    let slow = h.system.open(app: "Slow", frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    h.system.movesLate = [slow]
    h.start()
    let mark = h.system.moveLog.count
    h.run("dock \(slow.rawValue) left")
    let first = try #require(h.system.moveLog[mark...].first { $0.window == slow })
    #expect(first.after.height == 484 && first.after.origin == first.requested.origin, "the stand-in plays it: \(first)")
    expectEveryDockedWindowFillsItsSlot(h, "it was asked once more, in the slot")
    // Nor is anything remembered of it.
    h.system.movesLate = []
    h.run("float \(slow.rawValue)")
    h.system.userMove(slow, to: CGRect(x: 170, y: 220, width: 480, height: 348))
    let roads = roads(h) { h.run("dock \(slow.rawValue) right") }
    expectEveryDockedWindowFillsItsSlot(h, "the next docking")
    expectStraightRoads(roads)
  }

  /// With no gap a slot ends on the line itself, and a terminal in it a few points above: an answer that looks like the screen's. In the slot
  /// it cannot be, so it is believed, and the terminal is left in peace from then on.
  @Test func aTerminalWhoseSlotEndsOnTheLineIsNotWalkedAbout() throws {
    var settings = Settings()
    settings.gap = 0
    let h = Harness(settings: settings)
    let terminal = h.system.open(app: "Terminal")
    let a = h.system.open(app: "A")
    h.system.setSizeStep(terminal, CGSize(width: 10, height: 15))
    h.start()
    h.run("dock \(terminal.rawValue) left")
    h.run("dock \(a.rawValue) beside \(terminal.rawValue) right")
    let rests = try #require(h.frame(terminal))
    #expect(h.visibleFrame.maxY - rests.maxY <= 4, "the case: \(rests)")
    for command in ["show-all", "home", "zoom \(a.rawValue)", "back"] {
      let road = roads(h) { h.run(command) }[terminal] ?? []
      // Where it rests, or out of view.
      #expect(road.allSatisfy { $0 == rests || $0.minX >= h.visibleFrame.maxX - 2 } && road.count <= 2, "\(command): \(road)")
    }
  }

  /// What was learnt can stop being true by half: it grows further than it did, far from any line, and that is its answer. It is not sent
  /// to the slot's corner to be asked again.
  @Test func oneThatCanGrowALittleFurtherIsBelievedWhereItIsAsked() throws {
    let h = Harness(settings: Settings())
    let editor = h.system.open(app: "Editor", frame: CGRect(x: 400, y: 100, width: 500, height: 300))
    let notes = h.system.open(app: "Notes")
    let b = h.system.open(app: "B")
    h.system.setMaximumSize(editor, CGSize(width: 2000, height: 300))
    h.start()
    h.run("dock \(editor.rawValue) left")
    // Nothing is left over for a newcomer to take: it is offered half of the editor's place.
    h.run("dock \(b.rawValue) right")
    h.system.setMaximumSize(editor, CGSize(width: 2000, height: 400))
    let road = try #require(roads(h) { h.run("dock \(notes.rawValue) beside \(editor.rawValue) right") }[editor])
    let slot = try #require(h.layout?.windowFrames[editor])
    #expect(h.frame(editor)?.height == 400 && isCentred(h.frame(editor), in: slot))
    #expect(!road.dropFirst().contains { $0.minY == slot.minY }, "\(road) in \(slot)")
  }

  /// One request, as before anybody was asked anything.
  @Test func aWindowThatOnlyHasToGrowIsMovedWithOneRequest() throws {
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 170, y: 356, width: 480, height: 348))
    h.start()
    let mark = h.system.moveLog.count
    let roads = roads(h) { h.run("dock \(a.rawValue) left") }
    expectEveryDockedWindowFillsItsSlot(h, "dock")
    expectStraightRoads(roads)
    #expect(movesWithoutWaste(h, of: a, since: mark) == 1)
  }

  /// A window that has to become narrower and higher: the width is what the others wait for, and only that is asked where it stands.
  @Test func theSideThatShrinksIsAskedWhereItStandsAndTheOtherGrowsInTheSlot() throws {
    let h = Harness(displays: [Self.withADock])
    let a = h.system.open(app: "A", frame: CGRect(x: 20, y: 60, width: 480, height: 348))
    h.start()
    h.run("dock \(a.rawValue) left")
    let wide = h.system.open(
      app: "Wide", frame: CGRect(x: 300, y: 300, width: 700, height: 348), minimumSize: CGSize(width: 600, height: 200))
    let mark = h.system.moveLog.count
    let roads = roads(h) { h.run("dock \(wide.rawValue) right") }
    let question = try #require(h.system.moveLog[mark...].first { $0.window == wide })
    #expect(question.requested.origin == question.before.origin && question.requested.height == 348 && question.requested.width < 600)
    let slot = try #require(h.layout?.windowFrames[wide], "room was made for it")
    #expect(slot.width >= 600 && h.frame(wide) == slot)
    expectEveryDockedWindowFillsItsSlot(h, "dock")
    expectStraightRoads(roads)
  }
}
