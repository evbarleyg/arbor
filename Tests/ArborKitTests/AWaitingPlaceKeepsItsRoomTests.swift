import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// At a login Arbor is up long before the apps whose windows it arranged, and they come one after the other. A docked
/// window that is restored before its neighbour goes straight to its final place, and a hole waits for the neighbour
/// (collab/QUESTIONS.md, Q16): no window moves twice because somebody else was late.
@Suite @MainActor struct AWaitingPlaceKeepsItsRoomTests {
  // MARK: The evening before, and the next morning

  /// What a person had docked when the Mac was shut down.
  enum Shape: String, CaseIterable {
    /// `[ A | B | C | Desktop ]`
    case aRowOfThree
    /// `[ A over B | Desktop | C ]`
    case twoOverEachOtherAndOne
    /// `[ A | B | C | D | Desktop ]`
    case aRowOfFour
    /// `[ A over B | C over D | Desktop ]`
    case twoByTwo
    /// `[ A | B over (C | D) | Desktop ]`
    case nested

    var count: Int { self == .aRowOfThree || self == .twoOverEachOtherAndOne ? 3 : 4 }

    /// Docking beside a window halves its place. `balance all` gives everybody the same again, so that nobody is a tile.
    func docks(_ w: [WindowID]) -> [String] { places(w) + ["balance all"] }

    private func places(_ w: [WindowID]) -> [String] {
      let id = w.map(\.rawValue)
      switch self {
      case .aRowOfThree:
        return ["dock \(id[0]) left", "dock \(id[1]) beside \(id[0]) right", "dock \(id[2]) beside \(id[1]) right"]
      case .twoOverEachOtherAndOne:
        return ["dock \(id[0]) left", "dock \(id[1]) beside \(id[0]) bottom", "dock \(id[2]) right"]
      case .aRowOfFour:
        return [
          "dock \(id[0]) left", "dock \(id[1]) beside \(id[0]) right", "dock \(id[2]) beside \(id[1]) right",
          "dock \(id[3]) beside \(id[2]) right",
        ]
      case .twoByTwo:
        return [
          "dock \(id[0]) left", "dock \(id[1]) beside \(id[0]) bottom", "dock \(id[2]) beside \(id[0]) right",
          "dock \(id[3]) beside \(id[2]) bottom",
        ]
      case .nested:
        return [
          "dock \(id[0]) left", "dock \(id[1]) beside \(id[0]) right", "dock \(id[2]) beside \(id[1]) bottom",
          "dock \(id[3]) beside \(id[2]) right",
        ]
      }
    }
  }

  static let wide = DisplaySnapshot(
    id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
    visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)

  struct Evening {
    var saved: PersistedState
    /// The docked windows as their apps will restore them: where the quit left them.
    var windows: [WindowSnapshot]
    /// Where each was while it was docked, with everything in view.
    var places: [CGRect]
    /// A window that was never docked.
    var loose: WindowSnapshot
  }

  /// - Parameter framing: the window the view is on when the Mac is shut down; nil: everything shows.
  func evening(_ shape: Shape, framing: Int? = nil) -> Evening {
    let h = Harness(displays: [Self.wide])
    // In pieces: as one expression Swift 6.2 gives up on it ("unable to type-check this expression in reasonable time").
    let apps = ["Safari", "Notes", "Mail", "Terminal"]
    let ids = (0..<shape.count).map { index in
      let frame = CGRect(x: 200 + 90 * index, y: 120 + 60 * index, width: 700, height: 500)
      return h.system.open(app: apps[index], pid: Int32(500 + index), frame: frame)
    }
    let loose = h.system.open(app: "Music", pid: 600, frame: CGRect(x: 1700, y: 700, width: 200, height: 150))
    h.start()
    for line in shape.docks(ids) { #expect(h.run(line).ok, "\(line)") }
    // On the Desktop, where its person wants it.
    let desktop = h.layout!.desktopFrame!
    h.system.userMove(loose, to: CGRect(x: (desktop.midX - 100).rounded(), y: (desktop.midY - 75).rounded(), width: 200, height: 150))
    h.scheduler.advance(by: 5)
    let places = ids.map { h.frame($0)! }
    #expect(h.layout?.tiles.isEmpty == true && h.layout?.windowFrames.count == shape.count, "everybody is in view: \(shape.rawValue)")
    if let framing { #expect(h.run("zoom \(ids[framing].rawValue)").ok) }
    h.controller.shutdown()
    return Evening(
      saved: h.store.saved!, windows: ids.map { id in h.system.allWindows().first { $0.id == id }! }, places: places,
      loose: h.system.allWindows().first { $0.id == loose }!)
  }

  func reopen(_ window: WindowSnapshot, in h: Harness, title: String? = nil) -> WindowID {
    h.system.open(app: window.appName, bundleID: window.bundleID, title: title ?? window.title, pid: window.pid, frame: window.frame)
  }

  /// Where Arbor sent `window`, leaving out requests that changed nothing. Nor is a question a move: a window Arbor does not know is
  /// asked for a size where it stands, before it goes anywhere, and from there straight on, which is one road (`Budget.tally`).
  func framesSet(_ window: WindowID, in h: Harness, since mark: Int = 0) -> [CGRect] {
    let moves = h.system.moveLog[mark...].filter { $0.window == window && $0.before != $0.after }
    return moves.dropFirst(Budget.tally(moves).questions).map(\.after)
  }

  static func permutations(_ count: Int) -> [[Int]] {
    func all(_ rest: [Int]) -> [[Int]] {
      rest.count <= 1 ? [rest] : rest.indices.flatMap { i in all(Array(rest[..<i] + rest[(i + 1)...])).map { [rest[i]] + $0 } }
    }
    return all(Array(0..<count))
  }

  /// The next morning: the first `early` windows of `order` are back before Arbor starts, the others come one after the other.
  /// Returns the harness and today's numbers, by yesterday's index.
  func morning(_ evening: Evening, order: [Int], early: Int, pause: Double = 2) -> (h: Harness, ids: [Int: WindowID], loose: WindowID) {
    let h = Harness(displays: [Self.wide], saved: evening.saved)
    // Numbers restart after a reboot: unrelated windows take the old ones.
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700, frame: CGRect(x: 1800, y: 100, width: 400, height: 300)) }
    let loose = reopen(evening.loose, in: h)
    var ids: [Int: WindowID] = [:]
    for index in order.prefix(early) { ids[index] = reopen(evening.windows[index], in: h) }
    h.start()
    h.scheduler.advance(by: pause)
    for index in order.dropFirst(early) {
      ids[index] = reopen(evening.windows[index], in: h)
      h.scheduler.advance(by: pause)
    }
    return (h, ids, loose)
  }

  // MARK: Every order

  /// The board's row 1.28: windows restored in every order: each is set one frame, its last.
  @Test(arguments: Shape.allCases) func inEveryOrderEachWindowIsSetOneFrameItsLast(shape: Shape) {
    let evening = evening(shape)
    for order in Self.permutations(shape.count) {
      for early in 0...shape.count {
        let (h, ids, loose) = morning(evening, order: order, early: early)
        let story = "\(shape.rawValue), order \(order), \(early) before Arbor"
        for (index, id) in ids.sorted(by: { $0.key < $1.key }) {
          #expect(framesSet(id, in: h) == [evening.places[index]], "window \(index): \(story)")
          #expect(h.workspace.isDocked(id), "window \(index): \(story)")
        }
        #expect(framesSet(loose, in: h).isEmpty, "a window that was never docked: \(story)")
        #expect(h.controller.snapshot().waiting.isEmpty, "\(story)")
        #expect(!h.scheduler.pendingKeys.contains("pending-slots"), "\(story)")
        #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations()): \(story)")
        expectWindowsMatchLayout(h)
      }
    }
  }

  /// And at no moment on the way is anything other than what a fresh layout says.
  @Test(arguments: Shape.allCases) func onTheWayEveryWindowThatIsThereIsInItsFinalPlace(shape: Shape) {
    let evening = evening(shape)
    for order in Self.permutations(shape.count) {
      let h = Harness(displays: [Self.wide], saved: evening.saved)
      for _ in 0..<7 { h.system.open(app: "Filler", pid: 700, frame: CGRect(x: 1800, y: 100, width: 400, height: 300)) }
      h.start()
      var back: [Int: WindowID] = [:]
      for index in order {
        back[index] = reopen(evening.windows[index], in: h)
        h.scheduler.advance(by: 1)
        for (index, id) in back { #expect(h.frame(id) == evening.places[index], "\(shape.rawValue), order \(order)") }
        #expect(h.controller.snapshot().waiting.count == shape.count - back.count)
        #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
        expectWindowsMatchLayout(h)
      }
    }
  }

  // MARK: What is in the hole

  /// Arbor is up, and of yesterday's docked windows only `back` have come so far, in that order.
  func morningSoFar(_ evening: Evening, back: [Int]) -> (h: Harness, ids: [Int: WindowID], loose: WindowID) {
    let h = Harness(displays: [Self.wide], saved: evening.saved)
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700, frame: CGRect(x: 1800, y: 100, width: 400, height: 300)) }
    let loose = reopen(evening.loose, in: h)
    h.start()
    h.scheduler.advance(by: 1)
    var ids: [Int: WindowID] = [:]
    for index in back {
      ids[index] = reopen(evening.windows[index], in: h)
      h.scheduler.advance(by: 1)
    }
    return (h, ids, loose)
  }

  /// A thing that is not there yet does not pretend to be: no tile, no icon, nothing to click. The menu and `status` say
  /// that a place is kept.
  @Test func nothingIsDrawnInTheHole() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    let layout = try #require(h.layout)
    #expect(layout.windowFrames.keys.sorted() == [notes], "the layout speaks of windows that are there")
    #expect(layout.tiles.isEmpty)
    #expect(layout.hiddenWindows.isEmpty)
    #expect(h.overlays.tiles[h.display]?.isEmpty != false)
    #expect(h.frame(notes) == evening.places[1])
    #expect(h.run("status").message.contains("2 places kept for windows that are not open yet"))
    // The surface behind docked windows runs through the holes as behind any place, and is what it will be when everybody is back.
    let surface = try #require(h.overlays.scenes[h.display]?.backdrop?.rects)
    for place in evening.places { #expect(surface.contains { $0.contains(place.center) }, "\(place)") }
    _ = reopen(evening.windows[0], in: h)
    _ = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.scenes[h.display]?.backdrop?.rects == surface)
  }

  /// A place too narrow to use would be a tile if its window were there. Kept open it is still nothing.
  @Test func aHoleTooSmallToUseIsNoTile() throws {
    let first = Harness()
    let ids = (0..<4).map { first.system.open(app: ["Safari", "Notes", "Mail", "Terminal"][$0], pid: Int32(500 + $0)) }
    first.start()
    for line in Shape.aRowOfFour.docks(ids) { first.run(line) }
    first.run("resize \(ids[0].rawValue) right -200")
    first.scheduler.advance(by: 5)
    #expect(first.layout?.tiles.contains { $0.windows == [ids[0]] } == true, "Safari was a tile in the evening")
    let place = first.frame(ids[1])!
    let windows = ids.map { id in first.system.allWindows().first { $0.id == id }! }
    first.controller.shutdown()

    let h = Harness(saved: first.store.saved)
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700) }
    h.start()
    let notes = reopen(windows[1], in: h)
    h.scheduler.advance(by: 1)
    #expect(h.frame(notes) == place)
    let layout = try #require(h.layout)
    let safari = try #require(h.controller.snapshot().waiting.first { $0.bundleID == windows[0].bundleID })
    let leaf = try #require(h.workspace.tree.leaf(containing: safari.id))
    #expect(try #require(layout.openPlaces[leaf]).width < 240, "the situation: room is kept, and it is too narrow to use")
    #expect(layout.tiles.allSatisfy { $0.kind == .desktop }, "\(layout.tiles)")
    #expect(h.overlays.tiles[h.display]?.contains { $0.node == leaf } != true)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// A rectangle drawn round a hole frames nothing that is not there.
  @Test func aRectangleDrawnRoundAHoleDoesNotFrameIt() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    let safari = try #require(h.controller.snapshot().waiting.first { $0.bundleID == evening.windows[0].bundleID })
    let hole = evening.places[0].insetBy(dx: 10, dy: 10)
    _ = h.run("frame-rect \(Int(hole.minX)) \(Int(hole.minY)) \(Int(hole.width)) \(Int(hole.height))")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera != h.workspace.tree.leaf(containing: safari.id))
    #expect(h.system.isVisible(notes))
    expectWindowsMatchLayout(h)
  }

  /// The keyboard does not walk into a hole.
  @Test func theKeyboardWalksPastTheHole() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [0, 2])
    let (safari, mail) = (try #require(ids[0]), try #require(ids[2]))
    h.system.userFocus(safari)
    #expect(h.run("focus right").ok)
    #expect(h.system.focusedWindow() == mail)
    #expect(h.frame(safari) == evening.places[0] && h.frame(mail) == evening.places[2])
  }

  // MARK: What ends the wait

  /// The app never comes. Nothing moves by a timer; the room goes back at the next layout the person causes.
  @Test func anAppThatNeverComesGivesItsRoomBackAtTheNextLayoutSomebodyCauses() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 3)
    #expect(h.system.moveLog.count == mark, "nothing moves by a timer")
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)

    #expect(h.run("relayout").ok)
    #expect(Set(h.workspace.tree.allWindows) == [notes, mail])
    #expect(h.frame(notes)!.minX == evening.places[0].minX, "the room is shared out again")
    #expect(framesSet(notes, in: h, since: mark).count == 1 && framesSet(mail, in: h, since: mark).count == 1)
    #expect(framesSet(loose, in: h).isEmpty)
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    expectWindowsMatchLayout(h)

    // Minutes later, a window of that app is a new window.
    let late = reopen(evening.windows[0], in: h)
    #expect(h.workspace.isFloating(late))
  }

  /// Never by the timer under their eyes. But where nothing that is in view would change, the hole closes unseen when its time is up.
  @Test func aHoleThatIsOutOfViewWhenItsTimeIsUpClosesUnseen() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    #expect(h.run("zoom \(notes.rawValue)").ok)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.system.moveLog.count == mark, "nothing moves by a timer")
    #expect(Set(h.workspace.tree.allWindows) == [notes, mail])
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)!.minX == evening.places[0].minX)
    #expect(framesSet(notes, in: h, since: mark).count == 1 && framesSet(mail, in: h, since: mark).count == 1)
    expectWindowsMatchLayout(h)
  }

  /// A morning on which nobody came: there is nothing beside the holes that could move.
  @Test func holesWithNobodyBesideThemGoWhenTheirTimeIsUp() {
    let evening = evening(.twoByTwo)
    let (h, _, loose) = morningSoFar(evening, back: [])
    #expect(h.run("status").message.contains("4 places kept"))
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.system.moveLog.count == mark)
    #expect(h.workspace.tree.allWindows.isEmpty)
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    #expect(framesSet(loose, in: h).isEmpty)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// Whoever changes the arrangement has taken it in hand: the hole closes in the same move, and the place still waits, without
  /// room, as a minimized window's does.
  @Test(arguments: ["dock", "float", "arrange", "swap", "close", "float-all", "layout"])
  func aChangeOfTheArrangementClosesTheHoleAtOnce(how: String) throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let mark = h.system.moveLog.count
    switch how {
    case "dock": #expect(h.run("dock \(loose.rawValue) right").ok)
    case "float": #expect(h.run("float \(mail.rawValue)").ok)
    case "arrange": #expect(h.run("arrange").ok)
    case "swap": #expect(h.run("swap \(notes.rawValue) \(mail.rawValue)").ok)
    case "float-all": #expect(h.run("float-all").ok)
    case "layout": #expect(h.run("layout \(notes.rawValue) | \(mail.rawValue)").ok)
    default: h.system.close(mail)
    }
    h.scheduler.advance(by: 2)
    let left = how == "swap" ? mail : notes
    if how != "float-all" {
      #expect(h.frame(left)!.minX == evening.places[0].minX, "nothing is kept open on the left: \(h.frame(left)!)")
    }
    for window in [notes, mail, loose] where h.frame(window) != nil {
      #expect(framesSet(window, in: h, since: mark).count <= 1, "\(window) moved \(framesSet(window, in: h, since: mark))")
    }
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
    // These three give up the places that wait, as they always have.
    guard !["arrange", "float-all", "layout"].contains(how) else {
      #expect(!h.run("status").message.contains("kept"))
      return
    }

    #expect(h.run("status").message.contains("1 place kept"))
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(safari))
    #expect(h.frame(safari)!.minX == evening.places[0].minX, "on the left, where it was")
    expectWindowsMatchLayout(h)
  }

  /// A gap in the hand stays in the hand: the hole gets wider or narrower like any neighbour.
  @Test func aGapBesideTheHoleCanBeDragged() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let seam = try #require(h.overlays.seams[h.display]?.first { $0.frame.maxX <= evening.places[1].minX + 1 })
    h.overlays.dragSeam(seam, by: 100)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)!.minX == evening.places[1].minX + 100)
    #expect(h.frame(notes)!.maxX == evening.places[1].maxX)
    #expect(h.frame(mail) == evening.places[2])
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari)!.width == evening.places[0].width + 100)
    #expect(h.frame(notes)!.minX == evening.places[1].minX + 100)
    expectWindowsMatchLayout(h)
  }

  /// A move of the view changes no arrangement. There and back is nothing.
  @Test func aMoveOfTheViewKeepsTheHole() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let looseAt = h.frame(loose)
    let mark = h.system.moveLog.count
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    #expect(h.system.moveLog[mark...].allSatisfy { $0.before == $0.after }, "everything was showing")

    #expect(h.run("zoom \(notes.rawValue)").ok)
    h.scheduler.advance(by: 2)
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    #expect(h.frame(loose) == looseAt, "\(h.frame(loose)!) and not \(looseAt!), Desktop \(h.layout!.desktopFrame!)")

    // It comes while the view is elsewhere, and is in its place when the view is back.
    #expect(h.run("zoom \(notes.rawValue)").ok)
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(safari))
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == evening.places[0] && h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    expectWindowsMatchLayout(h)
  }

  /// Hidden and shown again, minimized and restored: the neighbours of the hole come and go, and the hole stays.
  @Test(arguments: ["hide", "minimize"]) func aNeighbourThatGoesAndComesBackLeavesTheHoleAlone(how: String) throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let pid = try #require(h.controller.windows[mail]?.pid)
    if how == "hide" { h.system.setHidden(pid: pid, true) } else { h.system.setMinimized(mail, true) }
    h.scheduler.advance(by: 2)
    // The room of who is away is shared by the row, of which the hole is one.
    #expect(h.frame(notes)!.minX >= evening.places[1].minX, "the hole on its left is still there")
    #expect(h.frame(notes)!.width > evening.places[1].width)
    if how == "hide" { h.system.setHidden(pid: pid, false) } else { h.system.setMinimized(mail, false) }
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    expectWindowsMatchLayout(h)
  }

  /// A quit in the middle of the wait: everybody has their own size back, and the next start waits again.
  @Test func aQuitInTheMiddleOfTheWaitLosesNoPlace() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    h.controller.shutdown()
    #expect(h.frame(notes) == evening.windows[1].frame, "its own frame")

    let again = Harness(saved: h.store.saved, system: h.system)
    let mark = h.system.moveLog.count
    again.start()
    again.scheduler.advance(by: 2)
    #expect(again.frame(notes) == evening.places[1])
    let safari = reopen(evening.windows[0], in: again)
    let mail = reopen(evening.windows[2], in: again)
    again.scheduler.advance(by: 2)
    #expect(framesSet(notes, in: again, since: mark) == [evening.places[1]])
    #expect(framesSet(safari, in: again) == [evening.places[0]] && framesSet(mail, in: again) == [evening.places[2]])
    expectWindowsMatchLayout(again)
  }

  /// A pause is as if Arbor had quit, and it comes back (Q21): with the frames from before, so with the hole.
  @Test func aPauseAndAResumeKeepTheHole() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    #expect(h.run("pause").ok)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == evening.places[0] && h.frame(notes) == evening.places[1])
    expectWindowsMatchLayout(h)
  }

  /// And without it, if the person had closed it before the pause.
  @Test func aHoleThatWasClosedBeforeAPauseStaysClosedAfterIt() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    #expect(h.run("dock \(loose.rawValue) right").ok)
    h.scheduler.advance(by: 2)
    let before = [h.frame(notes), h.frame(mail), h.frame(loose)]
    #expect(h.run("pause").ok)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 2)
    #expect([h.frame(notes), h.frame(mail), h.frame(loose)] == before)
    expectWindowsMatchLayout(h)
  }

  // MARK: Who comes instead

  /// What an app shows first is often a welcome window. It holds the place for now, closes, and the real one comes: the
  /// neighbours have not moved once.
  @Test func aWelcomeWindowThatComesAndGoesMovesNoNeighbour() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let mark = h.system.moveLog.count
    let welcome = reopen(evening.windows[0], in: h, title: "Welcome")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(welcome))
    h.system.close(welcome)
    h.scheduler.advance(by: 2)
    #expect(h.run("status").message.contains("1 place kept"))
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == evening.places[0])
    #expect(framesSet(notes, in: h, since: mark).isEmpty && framesSet(mail, in: h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// The welcome window is still there when the real one comes and takes the place over. The neighbours have not moved, and the other hole stays.
  @Test func theRealWindowTakesThePlaceOverAndNoNeighbourMoves() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    let mark = h.system.moveLog.count
    let welcome = reopen(evening.windows[0], in: h, title: "Welcome")
    h.scheduler.advance(by: 2)
    let safari = reopen(evening.windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(safari) && h.workspace.isFloating(welcome))
    #expect(h.frame(safari) == evening.places[0])
    #expect(framesSet(notes, in: h, since: mark).isEmpty)
    let mail = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 2)
    #expect(framesSet(mail, in: h) == [evening.places[2]] && framesSet(notes, in: h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  // MARK: Who keeps no room

  /// A window that exists and takes no room now (minimized, its app hidden) is away, not late: the gaps depend on who is away, as they
  /// do all day. After a restart of the Mac, beside a place that does keep its room.
  @Test(arguments: ["minimized", "hidden"]) func aWindowThatIsOnlyAwayKeepsNoRoom(how: String) throws {
    let evening = evening(.aRowOfThree)
    let h = Harness(displays: [Self.wide], saved: evening.saved)
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700, frame: CGRect(x: 1800, y: 100, width: 400, height: 300)) }
    let (safari, notes) = (reopen(evening.windows[0], in: h), reopen(evening.windows[1], in: h))
    if how == "minimized" { h.system.setMinimized(safari, true) } else { h.system.setHidden(pid: evening.windows[0].pid, true) }
    h.start()
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(safari))
    #expect(h.frame(notes)!.minX == evening.places[0].minX, "Notes has the room of the window that is away")
    #expect(h.frame(notes)!.maxX < evening.places[2].minX, "and not that of Mail, which is late")
    expectWindowsMatchLayout(h)
    if how == "minimized" { h.system.setMinimized(safari, false) } else { h.system.setHidden(pid: evening.windows[0].pid, false) }
    let mail = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 2)
    #expect([h.frame(safari), h.frame(notes), h.frame(mail)] == evening.places.map { Optional($0) })
  }

  /// Arbor is quit at noon, two of three docked windows are closed, and it is started in the evening. They are not late: their
  /// person closed them. The third has the room at once, as it always had, and nothing is kept open beside it.
  @Test func aWindowThatWasClosedWhileArborWasNotRunningKeepsNoRoom() throws {
    let first = Harness(displays: [Self.wide])
    let ids = (0..<3).map { first.system.open(app: ["Safari", "Notes", "Mail"][$0], pid: Int32(500 + $0)) }
    first.start()
    for line in Shape.aRowOfThree.docks(ids) { first.run(line) }
    first.scheduler.advance(by: 5)
    let (left, safari) = (first.frame(ids[0])!.minX, first.system.allWindows().first { $0.id == ids[0] }!)
    first.controller.shutdown()
    first.system.close(ids[0])
    first.system.close(ids[2])

    let h = first.newProcess()
    let mark = h.system.moveLog.count
    h.start()
    h.scheduler.advance(by: 2)
    #expect(h.frame(ids[1])!.minX == left)
    #expect(framesSet(ids[1], in: h, since: mark).count == 1)
    #expect(h.run("status").message.contains("2 places kept"), "in case their apps are only being restarted")
    expectWindowsMatchLayout(h)
    // Taking no room, they can go when their time is up, and nothing moves.
    let moves = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.system.moveLog.count == moves)
    #expect(h.workspace.tree.allWindows == [ids[1]])
    let late = reopen(safari, in: h)
    #expect(h.workspace.isFloating(late), "\(h.run("state").message)")
  }

  /// The price of telling a login by the numbers: a window that happens to get its old number after a restart. That morning is as
  /// mornings were. Everybody still ends in their own place.
  @Test func aWindowThatHappensToGetItsOldNumberCostsNoPlace() {
    let evening = evening(.aRowOfThree)
    let h = Harness(displays: [Self.wide], saved: evening.saved)
    #expect(reopen(evening.windows[0], in: h) == evening.windows[0].id)
    h.start()
    h.scheduler.advance(by: 2)
    let (notes, mail) = (reopen(evening.windows[1], in: h), reopen(evening.windows[2], in: h))
    h.scheduler.advance(by: 2)
    #expect([h.frame(evening.windows[0].id), h.frame(notes), h.frame(mail)] == evening.places.map { Optional($0) })
    #expect(h.controller.snapshot().waiting.isEmpty)
    expectWindowsMatchLayout(h)
  }

  // MARK: The view

  /// Room is kept while everything shows, which is how a start begins. A view on a part of the arrangement is filled by who is there, as
  /// it always was: no half-empty screen, and no step of the view that changes nothing. Back at everything the hole is where it was.
  @Test func aViewOnAPartIsFilledByWhoIsThere() throws {
    let evening = evening(.twoOverEachOtherAndOne)
    let (h, ids, _) = morningSoFar(evening, back: [0, 2])
    let (safari, mail) = (try #require(ids[0]), try #require(ids[2]))
    #expect(h.frame(safari) == evening.places[0], "the upper half of its column")
    h.system.userFocus(safari)
    #expect(h.run("in").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == h.visibleFrame.insetBy(dx: 12, dy: 12), "\(h.frame(safari)!)")
    #expect(!h.run("in").ok, "there is nothing further in")
    expectWindowsMatchLayout(h)
    #expect(h.run("show-all").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == evening.places[0] && h.frame(mail) == evening.places[2])
    expectWindowsMatchLayout(h)
  }

  /// The evening ended framed on Safari. A start shows everything, and Back leads to the view of last night: a place that waits. What is shown
  /// is what is around it, as for a window that is away: nothing moves, and the holes are where they were. Never a screen with
  /// nothing on it and everything else swept out of view.
  @Test func aViewOfNothingButAHoleIsNotShown() throws {
    let evening = evening(.aRowOfThree, framing: 0)
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    #expect(h.frame(notes) == evening.places[1])
    let mark = h.system.moveLog.count
    #expect(h.run("back").ok)
    h.scheduler.advance(by: 2)
    let safari = try #require(h.controller.snapshot().waiting.first { $0.bundleID == evening.windows[0].bundleID })
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: safari.id), "the situation: the view is asked to be on the hole")
    #expect(h.system.moveLog[mark...].allSatisfy { $0.before == $0.after }, "\(h.system.moveLog[mark...])")
    #expect(h.frame(notes) == evening.places[1])
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
    let mail = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(mail) == evening.places[2] && h.frame(notes) == evening.places[1], "the holes have not been given up")
  }

  // MARK: Never at a window's cost

  /// Four windows docked by halving on a laptop: the last two places are too small to use. One of those windows is back before Arbor and in
  /// view. A start takes nothing out of view (Q16): it is not made a tile beside an empty screen for the sake of who is late.
  @Test func aHoleNeverMakesATileOfAWindowThatCouldShow() throws {
    let first = Harness()
    let ids = (0..<4).map { first.system.open(app: ["Safari", "Notes", "Mail", "Terminal"][$0], pid: Int32(500 + $0)) }
    first.start()
    let n = ids.map(\.rawValue)
    for line in ["dock \(n[0]) left", "dock \(n[1]) beside \(n[0]) top", "dock \(n[2]) beside \(n[0]) bottom", "dock \(n[3]) beside \(n[2]) top"] {
      #expect(first.run(line).ok)
    }
    first.scheduler.advance(by: 5)
    #expect(first.layout?.tiles.contains { $0.windows.contains(ids[2]) } == true, "the situation: Mail was a tile in the evening")
    let windows = ids.map { id in first.system.allWindows().first { $0.id == id }! }
    first.controller.shutdown()

    for early in [true, false] {
      let h = Harness(saved: first.store.saved)
      for _ in 0..<7 { h.system.open(app: "Filler", pid: 700) }
      var mail = early ? reopen(windows[2], in: h) : WindowID(0)
      h.start()
      if !early { mail = reopen(windows[2], in: h) }
      h.scheduler.advance(by: 2)
      #expect(h.workspace.isDocked(mail))
      #expect(h.system.isVisible(mail), "\(h.frame(mail)!), there \(early ? "before" : "after") Arbor")
      #expect(h.layout?.windowFrames[mail] != nil)
      #expect(framesSet(mail, in: h).count == 1)
      #expect(h.workspace.camera == h.workspace.tree.root, "and the view has not gone anywhere")
      // For good: room that is kept, not kept and kept again would move windows more often than none at all.
      #expect(h.controller.stateToSave.roomKept == nil)
      expectWindowsMatchLayout(h)
    }
  }

  /// Nobody is back yet. Windows that nobody docked are not kept off places that nobody can see.
  @Test func withNobodyBackNothingIsKeptOffTheHoles() throws {
    let evening = evening(.aRowOfThree)
    let (h, _, _) = morningSoFar(evening, back: [])
    let hole = evening.places[0]
    let preview = h.system.open(app: "Preview", pid: 800, frame: CGRect(x: hole.minX + 60, y: 100, width: 400, height: 300))
    let splash = h.system.open(app: "Splash", pid: 801, frame: CGRect(x: 900, y: 300, width: 300, height: 200))
    h.scheduler.advance(by: 1)
    h.system.close(splash)
    h.scheduler.advance(by: 1)
    for line in ["desktop", "show-all"] { _ = h.run(line) }
    h.scheduler.advance(by: 1)
    #expect(framesSet(preview, in: h).isEmpty, "\(framesSet(preview, in: h))")
    expectWindowsMatchLayout(h)
  }

  // MARK: What is no change of the arrangement

  /// ⌘T in a docked window, and back to the first tab: macOS gives the window another number. Who is where has not changed.
  @Test func anotherTabOfADockedWindowLeavesTheHoleAlone() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let mark = h.system.moveLog.count
    let tab = try #require(h.system.openTab(in: notes))
    h.scheduler.advance(by: 2)
    #expect(h.frame(mail) == evening.places[2] && h.frame(tab) == evening.places[1])
    h.system.selectTab(notes, insteadOf: tab)
    h.scheduler.advance(by: 2)
    #expect(h.frame(mail) == evening.places[2] && h.frame(notes) == evening.places[1])
    #expect(framesSet(mail, in: h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// Beside a hole a window can be made wider and narrower by every road there is, not by the gap's handle alone.
  @Test(arguments: ["resize", "grow", "edge"]) func aWindowBesideAHoleCanBeResized(how: String) throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [0, 2])
    let (safari, mail) = (try #require(ids[0]), try #require(ids[2]))
    h.system.userFocus(safari)
    var wider = evening.places[0]
    wider.size.width += 60
    switch how {
    case "resize": #expect(h.run("resize \(safari.rawValue) right 60").ok)
    case "grow": #expect(h.run("grow 60").ok)
    default: h.system.userResize(safari, to: wider)
    }
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) == wider, "\(h.frame(safari)!)")
    #expect(h.frame(mail) == evening.places[2], "the hole gave")
    let notes = reopen(evening.windows[1], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)!.minX == evening.places[1].minX + 60 && h.frame(notes)!.maxX == evening.places[1].maxX)
    expectWindowsMatchLayout(h)
  }

  /// With windows making way while another is dragged (`reflowWhileDragging`): carried over a target and away again, everybody is
  /// back where they were, hole and all, before the button is up.
  @Test func aWindowCarriedOverATargetAndAwayLeavesTheHole() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    var settings = h.controller.settings
    settings.reflowWhileDragging = true
    h.controller.apply(settings: settings)
    let home = try #require(h.frame(loose))
    h.system.beginDrag(loose)
    h.system.moveDrag(to: CGPoint(x: evening.places[1].minX + 40, y: evening.places[1].midY), holding: 1)
    #expect(h.frame(notes) != evening.places[1], "the situation: Notes has made way")
    h.system.moveDrag(to: CGPoint(x: home.midX, y: home.minY + 10), holding: 1)
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    h.system.endDrag()
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    expectWindowsMatchLayout(h)
  }

  // MARK: Apps that refuse a size

  /// In the evening Mail, which will not go under 600 points, was a tile under Notes. In the morning it comes first. With holes Arbor does no
  /// worse than without: Mail shows, everything shows, and the holes of that display are given up for good, also in the file.
  @Test func aWindowThatWillNotFitBesideAHoleShowsAllTheSame() throws {
    let first = Harness()
    let notes = first.system.open(app: "Notes", pid: 501, frame: CGRect(x: 190, y: 140, width: 600, height: 400))
    let mail = first.system.open(
      app: "Mail", pid: 502, frame: CGRect(x: 280, y: 180, width: 600, height: 600), minimumSize: CGSize(width: 300, height: 600))
    first.start()
    #expect(first.run("dock \(notes.rawValue) top").ok && first.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom").ok)
    first.scheduler.advance(by: 5)
    let windows = [notes, mail].map { id in first.system.allWindows().first { $0.id == id }! }
    first.controller.shutdown()

    let h = Harness(saved: first.store.saved)
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700) }
    h.start()
    h.scheduler.advance(by: 2)
    let back = h.system.open(
      app: "Mail", bundleID: windows[1].bundleID, title: windows[1].title, pid: 502, frame: windows[1].frame,
      minimumSize: CGSize(width: 300, height: 600))
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(back) && h.layout?.windowFrames[back] != nil, "\(h.frame(back)!)")
    #expect(h.workspace.camera == h.workspace.tree.root, "the view has not left everything")
    #expect(h.controller.stateToSave.roomKept == nil)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// An app refuses the size of its place in the middle of a layout, and beside the holes it would be a tile. They are given up there and
  /// then, and the file says so: the watchdog's restart a moment later sets no frame (Q16).
  @Test func roomGivenUpInTheMiddleOfALayoutIsGivenUpInTheFileToo() throws {
    let evening = evening(.aRowOfThree)
    let (h, _, _) = morningSoFar(evening, back: [])
    let wide = CGSize(width: 1900, height: 500)
    let safari = h.system.open(
      app: "Safari", bundleID: evening.windows[0].bundleID, title: evening.windows[0].title, pid: 500,
      frame: evening.windows[0].frame, minimumSize: wide)
    h.scheduler.advance(by: 2)
    #expect(h.layout?.windowFrames[safari] != nil, "\(h.frame(safari)!)")
    #expect(h.store.saved?.roomKept == nil)
    let again = h.newProcess(byTheWatchdog: true)
    let mark = again.system.moveLog.count
    again.start()
    again.scheduler.advance(by: 2)
    #expect(again.system.moveLog[mark...].allSatisfy { $0.before == $0.after }, "\(again.system.moveLog[mark...])")
    expectWindowsMatchLayout(again)
  }

  /// A crash in the middle of a login: the watchdog's restart finds everybody where they were, holes and all, and sets no frame.
  @Test func theWatchdogsRestartKeepsTheHolesAndSetsNoFrame() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    h.scheduler.advance(by: 2)
    let again = h.newProcess(byTheWatchdog: true)
    let mark = again.system.moveLog.count
    again.start()
    again.scheduler.advance(by: 2)
    #expect(again.system.moveLog[mark...].allSatisfy { $0.before == $0.after }, "\(again.system.moveLog[mark...])")
    #expect(again.frame(try #require(ids[1])) == evening.places[1])
    let safari = reopen(evening.windows[0], in: again)
    again.scheduler.advance(by: 2)
    #expect(framesSet(safari, in: again, since: mark) == [evening.places[0]])
    #expect(again.system.moveLog[mark...].allSatisfy { $0.window == safari || $0.before == $0.after })
    expectWindowsMatchLayout(again)
  }

  // MARK: Other ends

  /// Its time is up, and the hole waits for the next thing that moves windows anyway. A floating window that closes, perhaps by its app's own
  /// doing, is not that: docked windows do not jump for something that is not about them.
  @Test func anOverdueHoleDoesNotCloseForSomethingThatMovesNothing() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    let mark = h.system.moveLog.count
    let desktop = try #require(h.layout?.desktopFrame)
    let splash = h.system.open(app: "Splash", pid: 801, frame: CGRect(x: desktop.minX + 20, y: 300, width: 200, height: 150))
    h.scheduler.advance(by: 1)
    h.system.close(splash)
    h.scheduler.advance(by: 1)
    #expect(framesSet(notes, in: h, since: mark).isEmpty && framesSet(mail, in: h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
    // Mail is minimized: Notes moves anyway, once, and takes the hole's room with Mail's.
    h.system.setMinimized(mail, true)
    h.scheduler.advance(by: 1)
    #expect(framesSet(notes, in: h, since: mark).count == 1)
    #expect(h.frame(notes)!.minX == evening.places[0].minX)
    #expect(!h.run("status").message.contains("kept"))
    expectWindowsMatchLayout(h)
  }

  /// Nor under a hand. Its time is up, and the first touch of a gap or an edge does not make the thing in the hand jump away.
  @Test(arguments: ["gap", "edge"]) func anOverdueHoleDoesNotCloseUnderAHand(how: String) throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [0, 2])
    let (safari, mail) = (try #require(ids[0]), try #require(ids[2]))
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    var wider = evening.places[2]
    wider.size.width += 30
    if how == "gap" {
      let seam = try #require(h.overlays.seams[h.display]?.first { $0.frame.minX >= evening.places[2].maxX - 1 })
      h.overlays.dragSeam(seam, by: 30)
    } else {
      h.system.userResize(mail, to: wider)
    }
    h.scheduler.advance(by: 2)
    #expect(h.frame(mail) == wider, "\(h.frame(mail)!)")
    #expect(h.frame(safari) == evening.places[0])
    #expect(h.run("status").message.contains("1 place kept"))
    expectWindowsMatchLayout(h)
  }

  /// What a person sees is the promise, not the clock: a hole that can still be seen takes its window, at seven minutes as at two. Nobody
  /// else moves, and the other hole stays.
  @Test func anOverdueHoleStillTakesItsWindowAndNobodyElseMoves() throws {
    let evening = evening(.aRowOfFour)
    let (h, ids, _) = morningSoFar(evening, back: [0, 3])
    let (safari, terminal) = (try #require(ids[0]), try #require(ids[3]))
    h.scheduler.advance(by: 420)
    let mark = h.system.moveLog.count
    let mail = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 2)
    #expect(framesSet(mail, in: h) == [evening.places[2]])
    #expect(framesSet(safari, in: h, since: mark).isEmpty && framesSet(terminal, in: h, since: mark).isEmpty)
    #expect(h.run("status").message.contains("1 place kept"))
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// Safari and Mail have come, Notes is late. Arbor is quit, Mail is closed, Arbor is started: Notes is still late and has its hole. Mail
  /// had come: its person closed it, and nothing is kept open for it.
  @Test func aWindowThatHadComeAndIsMissingAtTheNextStartWasClosed() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [0, 2])
    let (safari, mail) = (try #require(ids[0]), try #require(ids[2]))
    h.controller.shutdown()
    h.system.close(mail)
    let again = h.newProcess()
    again.start()
    again.scheduler.advance(by: 2)
    let layout = try #require(again.layout)
    let open = again.controller.snapshot().waiting.filter { slot in
      again.workspace.tree.leaf(containing: slot.id).flatMap { layout.openPlaces[$0] } != nil
    }
    #expect(open.map(\.bundleID) == [evening.windows[1].bundleID], "one hole, and it is Notes's")
    #expect(again.frame(safari)!.width > evening.places[0].width, "Mail's room is shared out")
    expectWindowsMatchLayout(again)
  }

  /// Arbor alone is started again while its windows are on another macOS Space, so that none of them is listed and the start looks like one
  /// after a restart of the Mac. The first that comes back under its own number proves that it was not: what is missing was closed.
  @Test func aWindowThatComesBackUnderItsOwnNumberProvesTheSameLogin() throws {
    let first = Harness(displays: [Self.wide])
    let ids = (0..<3).map { first.system.open(app: ["Safari", "Notes", "Mail"][$0], pid: Int32(500 + $0)) }
    first.start()
    for line in Shape.aRowOfThree.docks(ids) { first.run(line) }
    first.scheduler.advance(by: 5)
    let left = first.frame(ids[0])!.minX
    first.controller.shutdown()
    first.system.close(ids[0])
    first.system.setListed(ids[1], false)
    first.system.setListed(ids[2], false)
    let h = first.newProcess()
    h.start()
    h.scheduler.advance(by: 2)
    h.system.setListed(ids[1], true)
    h.system.setListed(ids[2], true)
    h.scheduler.advance(by: 2)
    #expect(h.frame(ids[1])!.minX == left, "nothing is kept open for the window that was closed: \(h.frame(ids[1])!)")
    #expect(h.controller.stateToSave.roomKept == nil)
    expectWindowsMatchLayout(h)
  }

  /// A saved window of an app without a bundle id is not "found again under its own number, with its own app": not when it is long gone,
  /// and not when another window without one has its number.
  @Test(arguments: [4242, 103]) func aSavedWindowWithoutABundleIDDoesNotPassForTheSameLogin(number: UInt32) throws {
    var evening = evening(.aRowOfThree)
    evening.saved.hints[WindowID(number)] = WindowHint(bundleID: nil, title: "Untitled")
    let h = Harness(displays: [Self.wide], saved: evening.saved)
    for id in 101...107 {
      h.system.open(
        id: WindowID(UInt32(id)), app: "Filler", bundleID: nil, title: "Filler", pid: 700,
        frame: CGRect(x: 1800, y: 100, width: 400, height: 300))
    }
    h.start()
    let notes = reopen(evening.windows[1], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes) == evening.places[1])
  }

  /// Two displays. The start was taken for one after a restart of the Mac, and on the side display Mail sits beside a hole. On the main one a
  /// window comes back under its own number: both displays are laid out, not its own alone.
  @Test func whenTheSameLoginIsProvedEveryDisplayIsLaidOut() throws {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 2560, y: 25, width: 1920, height: 1055), isMain: false)
    let first = Harness(displays: [Self.wide, side])
    let safari = first.system.open(app: "Safari", pid: 500, frame: CGRect(x: 200, y: 200, width: 600, height: 400))
    let (notes, mail) = (
      first.system.open(app: "Notes", pid: 501, frame: CGRect(x: 2700, y: 200, width: 600, height: 400)),
      first.system.open(app: "Mail", pid: 502, frame: CGRect(x: 2800, y: 200, width: 600, height: 400))
    )
    first.start()
    for line in ["dock \(safari.rawValue) left", "dock \(notes.rawValue) left", "dock \(mail.rawValue) beside \(notes.rawValue) right"] {
      #expect(first.run(line).ok)
    }
    first.scheduler.advance(by: 5)
    first.controller.shutdown()
    first.system.close(notes)
    first.system.setListed(safari, false)
    first.system.setListed(mail, false)
    let h = first.newProcess()
    h.start()
    h.scheduler.advance(by: 2)
    h.system.setListed(mail, true)
    h.scheduler.advance(by: 2)
    h.system.setListed(safari, true)
    h.scheduler.advance(by: 2)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(h.controller.layouts[side.id]?.openPlaces.isEmpty == true)
    expectWindowsMatchLayout(h)
  }

  /// A crash in the middle of a login, with Mail on another macOS Space meanwhile. The start knows that it is the same login, and keeps Safari's
  /// hole because the file says so. Mail coming back under its own number proves nothing new, and costs no hole.
  @Test func aWindowBackFromAnotherSpaceCostsNoHoleThatTheFileKept() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    h.scheduler.advance(by: 2)
    h.system.setListed(mail, false)
    let again = h.newProcess(byTheWatchdog: true)
    again.start()
    again.scheduler.advance(by: 2)
    again.system.setListed(mail, true)
    again.scheduler.advance(by: 2)
    #expect(again.frame(notes) == evening.places[1] && again.frame(mail) == evening.places[2])
    #expect(again.layout?.openPlaces.count == 1)
    expectWindowsMatchLayout(again)
  }

  /// A place whose time is up is not written down, to be waited for all over again at the next start and the one after.
  @Test(arguments: ["quit", "pause"]) func anOverdueHoleIsNotRevivedByTheNextStart(how: String) throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let notes = try #require(ids[1])
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.frame(notes) == evening.places[1], "the situation: overdue, and still open")
    var after = h
    if how == "quit" {
      h.controller.shutdown()
      after = h.newProcess()
      after.start()
    } else {
      #expect(h.run("pause").ok && h.run("resume").ok)
    }
    after.scheduler.advance(by: 2)
    #expect(after.frame(notes)!.minX == evening.places[0].minX)
    #expect(!after.run("status").message.contains("kept"))
    #expect(after.workspace.tree.allWindows.count == 2)
    expectWindowsMatchLayout(after)
  }

  /// The overdue hole goes with a move of the view. That is Arbor giving up its waiting, not a change anybody made: ⌃⌥Z takes back what the
  /// person did last, and does not say that it cannot undo a zoom.
  @Test func anOverdueHoleThatGoesIsNoStepToUndo() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    #expect(h.run("swap \(notes.rawValue) \(mail.rawValue)").ok)
    #expect(h.run("swap \(notes.rawValue) \(mail.rawValue)").ok)
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.run("zoom \(notes.rawValue)").ok)
    h.scheduler.advance(by: 2)
    #expect(!h.run("status").message.contains("kept"), "the situation: the hole went with the zoom")
    let undone = h.run("undo")
    #expect(undone.ok && undone.message.contains("swap"), "\(undone.message)")
  }

  /// A docked window of which no own frame is remembered stays in its place when Arbor lets go of it: the place it has on screen, beside
  /// the hole, and not the one it would have without.
  @Test func atAQuitAWindowThatStaysInItsPlaceStaysWhereItIs() throws {
    var evening = evening(.aRowOfThree)
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(evening.saved)) as? [String: Any])
    var workspaces = try #require(json["workspaces"] as? [String: Any])
    var workspace = try #require(workspaces[Self.wide.id.rawValue] as? [String: Any])
    #expect(workspace.removeValue(forKey: "undockedFrames") != nil)
    workspaces[Self.wide.id.rawValue] = workspace
    json["workspaces"] = workspaces
    evening.saved = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
    let (h, ids, _) = morningSoFar(evening, back: [1])
    let notes = try #require(ids[1])
    #expect(h.frame(notes) == evening.places[1])
    h.controller.shutdown()
    #expect(h.frame(notes) == evening.places[1])
  }

  /// A hole that its person closed stays closed when Arbor is quit and started again in the same login.
  @Test func aHoleThatWasClosedStaysClosedAfterAQuit() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    #expect(h.run("dock \(loose.rawValue) right").ok)
    h.scheduler.advance(by: 2)
    let before = [h.frame(notes), h.frame(mail), h.frame(loose)]
    h.controller.shutdown()
    #expect(h.store.saved?.roomKept == nil)
    let again = h.newProcess()
    again.start()
    again.scheduler.advance(by: 2)
    #expect([again.frame(notes), again.frame(mail), again.frame(loose)] == before)
    #expect(again.run("status").message.contains("1 place kept"))
    expectWindowsMatchLayout(again)
  }

  /// What the file says of it: which places were kept open, in the minutes in which some are, and otherwise nothing.
  @Test func theFileSaysWhichPlacesAreKeptOpenOnlyWhileSomeAre() throws {
    let evening = evening(.aRowOfThree)
    #expect(evening.saved.roomKept == nil)
    let (h, _, _) = morningSoFar(evening, back: [1])
    h.scheduler.advance(by: 2)
    let saved = try #require(h.store.saved)
    #expect(saved.roomKept?[h.display]?.count == 2, "not Notes's: it has come, and if it is missing at the next start its person closed it")
    #expect(try JSONDecoder().decode(PersistedState.self, from: JSONEncoder().encode(saved)) == saved)
    _ = reopen(evening.windows[0], in: h)
    _ = reopen(evening.windows[2], in: h)
    h.scheduler.advance(by: 2)
    #expect(h.store.saved?.roomKept == nil)

    // Whatever stands there instead costs a move, not the arrangement.
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
    json["roomKept"] = "nonsense"
    let read = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(read.roomKept == nil && read.workspaces == saved.workspaces)
  }

  /// Nothing is kept open for an app that Arbor is told not to arrange any more.
  @Test func nothingIsKeptOpenForAnAppThatIsExcluded() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, _) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let mark = h.system.moveLog.count
    #expect(h.run("exclude \(evening.windows[0].bundleID!)").ok)
    h.scheduler.advance(by: 2)
    #expect(h.frame(notes)!.minX == evening.places[0].minX)
    #expect(framesSet(notes, in: h, since: mark).count == 1 && framesSet(mail, in: h, since: mark).count == 1)
    expectWindowsMatchLayout(h)
    // Taking no room, the place goes when its time is up, and nothing moves.
    let moves = h.system.moveLog.count
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.system.moveLog.count == moves)
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
  }

  /// A display that wakes a moment after Arbor: the places on it keep their room too.
  @Test func aDisplayThatWakesAfterArborKeepsItsHoles() throws {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 2560, y: 25, width: 1920, height: 1055), isMain: false)
    let first = Harness(displays: [Self.wide, side])
    let ids = (0..<2).map {
      first.system.open(app: ["Safari", "Notes"][$0], pid: Int32(500 + $0), frame: CGRect(x: 2700 + 100 * $0, y: 200, width: 600, height: 400))
    }
    first.start()
    #expect(first.run("dock \(ids[0].rawValue) left").ok && first.run("dock \(ids[1].rawValue) beside \(ids[0].rawValue) bottom").ok)
    first.scheduler.advance(by: 5)
    #expect(first.controller.workspaceID(containing: ids[1]) == side.id)
    let places = ids.map { first.frame($0)! }
    first.controller.shutdown()
    let windows = ids.map { id in first.system.allWindows().first { $0.id == id }! }

    let h = Harness(displays: [Self.wide], saved: first.store.saved)
    for _ in 0..<7 { h.system.open(app: "Filler", pid: 700, frame: CGRect(x: 1800, y: 100, width: 400, height: 300)) }
    h.start()
    h.scheduler.advance(by: 2)
    h.system.setDisplays([Self.wide, side])
    h.scheduler.advance(by: 2)
    let notes = reopen(windows[1], in: h)
    h.scheduler.advance(by: 2)
    let safari = reopen(windows[0], in: h)
    h.scheduler.advance(by: 2)
    #expect(framesSet(notes, in: h) == [places[1]] && framesSet(safari, in: h) == [places[0]])
    expectWindowsMatchLayout(h)
  }

  // MARK: A drop lands where its preview was

  @Test func aWindowDroppedWhileAPlaceWaitsLandsWhereThePreviewWas() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let notes = try #require(ids[1])
    // On the left of Notes, beside the hole.
    let place = evening.places[1]
    h.system.beginDrag(loose)
    h.system.moveDrag(to: CGPoint(x: place.midX, y: place.midY), holding: 0.1)
    h.system.moveDrag(to: CGPoint(x: place.minX + 40, y: place.midY), holding: 1)
    let promised = try #require(h.overlays.preview)
    h.system.endDrag()
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(loose))
    #expect(h.frame(loose) == promised)
    #expect(h.frame(loose)!.maxX < h.frame(notes)!.minX)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// Over the hole itself there is nothing to drop a window on: it is let go there and floats, and nothing else moves.
  @Test func aWindowLetGoOverTheHoleFloatsThere() throws {
    let evening = evening(.aRowOfThree)
    let (h, ids, loose) = morningSoFar(evening, back: [1, 2])
    let (notes, mail) = (try #require(ids[1]), try #require(ids[2]))
    let hole = evening.places[0]
    h.system.beginDrag(loose)
    h.system.moveDrag(to: CGPoint(x: hole.midX, y: hole.midY), holding: 1)
    #expect(h.overlays.preview == nil)
    h.system.endDrag()
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isFloating(loose))
    #expect(h.frame(notes) == evening.places[1] && h.frame(mail) == evening.places[2])
    expectWindowsMatchLayout(h)
  }
}
