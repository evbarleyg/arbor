import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// There and back is nothing: a docked window that is hidden or minimized and comes back, nothing else having changed,
/// gets its place back and its neighbours their exact sizes (Controller+ThereAndBack.swift).
@MainActor @Suite struct ThereAndBackTests {
  /// Finder, Safari and TextEdit docked on a display of 1600 × 900 with a Terminal floating, as on the hosted Mac where it was
  /// seen. The smallest sizes are the real apps'. With a column for the Desktop and floating windows making way, as it was seen, Safari has
  /// borrowed from the Desktop and from TextEdit; without the column the three have the display to themselves, and it has borrowed from Finder
  /// and from TextEdit. `make test-classic` runs all of this on the desk as it was seen.
  private struct Desk {
    let h: Harness
    let finder, safari, textEdit, terminal: WindowID
    var docked: [WindowID] { [finder, safari, textEdit] }

    @MainActor init(settings: Settings = Harness.settingsWhenNoneAreGiven) {
      let h = Harness(
        displays: [
          DisplaySnapshot(
            id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1600, height: 900),
            visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 869), isMain: true)
        ], settings: settings)
      func open(_ app: String, _ pid: Int32, _ size: CGSize, atLeast minimum: CGSize = .zero) -> WindowID {
        h.system.open(app: app, pid: pid, frame: CGRect(origin: CGPoint(x: 140, y: 60), size: size), minimumSize: minimum)
      }
      finder = open("Finder", 2001, CGSize(width: 920, height: 436), atLeast: CGSize(width: 501, height: 300))
      safari = open("Safari", 2002, CGSize(width: 1324, height: 791), atLeast: CGSize(width: 574, height: 240))
      textEdit = open("TextEdit", 2003, CGSize(width: 673, height: 439), atLeast: CGSize(width: 115, height: 100))
      terminal = open("Terminal", 2004, CGSize(width: 877, height: 499))
      self.h = h
      h.start()
      h.run("dock \(finder.rawValue) left")
      h.run("dock \(safari.rawValue) right")
      h.run("dock \(textEdit.rawValue) right")
    }

    /// Where the docked windows that take space are, and the Desktop.
    @MainActor var places: [CGRect?] {
      docked.map { h.controller.windows[$0]?.isPresent == true ? h.frame($0) : nil } + [h.layout?.nodeFrames[h.workspace.tree.desktop]]
    }

    @MainActor func hide(_ window: WindowID, _ hidden: Bool = true) {
      h.system.setHidden(pid: h.system.windows[window]!.snapshot.pid, hidden)
      h.scheduler.runPending()
    }
  }

  /// That day floating windows made way (`floatingWindowsMakeWay`).
  @Test func theDeskIsTheOneThatWasSeen() {
    let desk = Desk(settings: .makingWay.withDesktopColumn)
    #expect(desk.h.frame(desk.finder) == CGRect(x: 12, y: 43, width: 501, height: 845))
    #expect(desk.h.frame(desk.safari) == CGRect(x: 712, y: 43, width: 574, height: 845))
    #expect(desk.h.frame(desk.textEdit) == CGRect(x: 1298, y: 43, width: 290, height: 845))
    expectWindowsMatchLayout(desk.h)
  }

  /// Thirds of 1552 points are 517, 518 and 517, and Safari lacks 56. Finder can spare 16 (it goes down to 501) and TextEdit 277 (down to
  /// the smallest usable width, 240): each gives in proportion, 3 and 53.
  @Test func theDeskAsArborShips() {
    let desk = Desk(settings: Settings())
    #expect(desk.docked.map { desk.h.frame($0)?.size } == [514, 574, 464].map { CGSize(width: $0, height: 845) })
    #expect(desk.h.layout?.desktopFrame == nil, "the three have the display to themselves")
    #expect(desk.h.frame(desk.terminal) == CGRect(x: 140, y: 60, width: 877, height: 499), "nobody touched it")
    expectWindowsMatchLayout(desk.h)
  }

  @Test func anAppThatIsHiddenAndShownAgainLeavesItsNeighboursAsWideAsTheyWere() {
    let desk = Desk()
    let before = desk.places
    desk.h.system.userFocus(desk.finder)
    desk.hide(desk.finder)
    // The neighbours close up meanwhile.
    #expect(desk.h.frame(desk.safari)!.width > 574)
    #expect(desk.h.frame(desk.textEdit)!.width > 290)
    desk.hide(desk.finder, false)
    #expect(desk.places == before)
    expectWindowsMatchLayout(desk.h)
  }

  @Test func soDoesEachOfThemHiddenOrMinimized() {
    for index in 0..<3 {
      for minimizes in [true, false] {
        let desk = Desk()
        let (before, tree) = (desk.places, desk.h.workspace.tree)
        let window = desk.docked[index]
        for round in 1...3 {
          if minimizes { desk.h.system.setMinimized(window, true) } else { desk.hide(window) }
          #expect(desk.places != before)
          if minimizes { desk.h.system.setMinimized(window, false) } else { desk.hide(window, false) }
          #expect(desk.places == before, "\(window), \(minimizes ? "minimized" : "hidden"), round \(round)")
          #expect(desk.h.workspace.tree == tree)
        }
        expectWindowsMatchLayout(desk.h)
      }
    }
  }

  @Test func allThreeInEveryOrderThereAndEveryOrderBack() {
    let orders = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
    for leaving in orders {
      for returning in orders {
        let desk = Desk()
        let before = desk.places
        for index in leaving { desk.h.system.setMinimized(desk.docked[index], true) }
        for index in returning { desk.h.system.setMinimized(desk.docked[index], false) }
        #expect(desk.places == before, "\(leaving) left, \(returning) came back")
        expectWindowsMatchLayout(desk.h)
      }
    }
  }

  @Test func twoOfThemOneHiddenAndOneMinimized() {
    for (first, second) in [(0, 1), (1, 0), (0, 2), (2, 0), (1, 2), (2, 1)] {
      for sameWayBack in [true, false] {
        let desk = Desk()
        let before = desk.places
        desk.hide(desk.docked[first])
        desk.h.system.setMinimized(desk.docked[second], true)
        if sameWayBack { desk.h.system.setMinimized(desk.docked[second], false) }
        desk.hide(desk.docked[first], false)
        if !sameWayBack { desk.h.system.setMinimized(desk.docked[second], false) }
        #expect(desk.places == before, "\(first) hidden, \(second) minimized")
        expectWindowsMatchLayout(desk.h)
      }
    }
  }

  /// What it looks like meanwhile depends on who is away, not on the order in which they went or on who has been away since.
  @Test func whoIsAwayDecidesWhatItLooksLikeMeanwhile() {
    let alone = Desk()
    alone.h.system.setMinimized(alone.safari, true)

    let afterAnother = Desk()
    afterAnother.hide(afterAnother.finder)
    afterAnother.h.system.setMinimized(afterAnother.safari, true)
    afterAnother.hide(afterAnother.finder, false)
    #expect(afterAnother.places == alone.places)
    expectWindowsMatchLayout(afterAnother.h)
  }

  /// Judged by the road (`FakeWindowSystem.detour`): one change of place at most, and no edge goes past where it ends up.
  @Test func eachWindowMovesOnceOnTheWayThereAndOnceOnTheWayBack() {
    let desk = Desk()
    var mark = desk.h.system.moveLog.count
    func roads() -> [WindowID: [CGRect]] {
      desk.docked.reduce(into: [:]) { $0[$1] = desk.h.system.road(of: $1, since: mark) }.filter { !$0.value.isEmpty }
    }
    desk.hide(desk.finder)
    #expect(Set(roads().keys) == [desk.safari, desk.textEdit])
    #expect(roads().values.compactMap(FakeWindowSystem.detour) == [])
    mark = desk.h.system.moveLog.count
    desk.hide(desk.finder, false)
    // Finder shows again where it was, which is its place: nobody has to move it.
    #expect(Set(roads().keys) == [desk.safari, desk.textEdit])
    #expect(roads().values.compactMap(FakeWindowSystem.detour) == [])
    expectWindowsMatchLayout(desk.h)
  }

  @Test func aSwitchOfSpaceAndBackIsNothingEither() {
    let desk = Desk()
    let before = desk.places
    desk.h.system.setOnActiveSpace(desk.finder, false)
    desk.h.scheduler.runPending()
    #expect(desk.places != before)
    desk.h.system.setOnActiveSpace(desk.finder, true)
    desk.h.scheduler.runPending()
    #expect(desk.places == before)
    expectWindowsMatchLayout(desk.h)
  }

  @Test func movingTheViewMeanwhileChangesNothing() {
    let desk = Desk()
    let before = desk.places
    desk.hide(desk.finder)
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("show-all")
    desk.h.run("desktop")
    desk.h.run("back")
    desk.hide(desk.finder, false)
    desk.h.run("show-all")
    #expect(desk.places == before)
    expectWindowsMatchLayout(desk.h)
  }

  // MARK: Something else has changed

  /// A gap moved by hand while a window is away is the person's. The window that comes back takes its share of the row as
  /// it stands, and nothing goes back to where it was before the hand.
  @Test(arguments: [false, true]) func aGapMovedByHandMeanwhileIsThePersons(makingWay: Bool) {
    let desk = Desk(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    let before = desk.places
    desk.hide(desk.finder)
    desk.h.run("resize \(desk.textEdit.rawValue) left 100")
    #expect(desk.h.frame(desk.textEdit)!.width == (makingWay ? 674 : 675))
    desk.hide(desk.finder, false)
    #expect(desk.places != before)
    #expect(desk.h.frame(desk.finder)!.width == 501)
    #expect(desk.h.frame(desk.textEdit)!.width > 290)
    expectWindowsMatchLayout(desk.h)
    // From here on this is the arrangement that comes back.
    let standing = desk.places
    desk.hide(desk.finder)
    desk.hide(desk.finder, false)
    #expect(desk.places == standing)
  }

  /// (On the desk that was seen. Finder is a tile once it is back, and `places` also tells how large a window is that is out of view: there
  /// Finder shows at its smallest size while Safari is away, which is the size it went out of view with before.)
  @Test func aWindowDockedOrClosedMeanwhileStartsAfresh() {
    let desk = Desk(settings: .withDesktopColumn)
    desk.hide(desk.finder)
    desk.h.run("dock \(desk.terminal.rawValue) right")
    desk.hide(desk.finder, false)
    expectWindowsMatchLayout(desk.h)
    let standing = desk.places + [desk.h.frame(desk.terminal)]
    desk.h.system.setMinimized(desk.safari, true)
    desk.h.system.setMinimized(desk.safari, false)
    #expect(desk.places + [desk.h.frame(desk.terminal)] == standing)

    desk.h.system.setMinimized(desk.safari, true)
    desk.h.system.close(desk.terminal)
    desk.h.system.setMinimized(desk.safari, false)
    expectWindowsMatchLayout(desk.h)
    #expect(desk.docked.allSatisfy { desk.h.layout!.windowFrames[$0] != nil })
  }

  /// On a smaller display the gaps that stood leave Finder and Safari short, and room is made for them as ever.
  @Test func aDisplayThatShrankMeanwhileIsAnOccasionToMakeRoom() {
    let desk = Desk()
    desk.hide(desk.finder)
    desk.h.system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1500, height: 900),
        visibleFrame: CGRect(x: 0, y: 31, width: 1500, height: 869), isMain: true)
    ])
    desk.h.scheduler.advance(by: 2)
    desk.hide(desk.finder, false)
    #expect(desk.docked.allSatisfy { desk.h.layout!.windowFrames[$0] != nil })
    expectWindowsMatchLayout(desk.h)
  }

  /// Two windows are tiles, and Arbor has never asked how small they go. With another away they show, and of one it learns. That
  /// is an occasion to make room (F61): when the other is back, that one is not sent back into its tile.
  /// (They are tiles because the Desktop has half of their column: `(104 / ((101 / 103 / Desktop:2) | 102)) | 105`.)
  @Test(.withTiles) func whatArborLearnsMeanwhileIsAnOccasionToMakeRoom() {
    let h = Harness(
      displays: [
        DisplaySnapshot(
          id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
          visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 875), isMain: true)
      ], settings: .withDesktopColumn)
    let windows = [(501, 100), (0, 240), (501, 0), (574, 0), (334, 240)].enumerated().map {
      h.system.open(app: "App\($0.offset)", pid: Int32(3000 + $0.offset), minimumSize: CGSize(width: $0.element.0, height: $0.element.1))
    }
    h.start()
    for line in ["dock 101 top", "dock 102 right", "dock 103 beside 101 bottom", "dock 104 top", "dock 105 right"] { h.run(line) }
    #expect(h.layout!.windowFrames[windows[0]] == nil && h.layout!.windowFrames[windows[2]] == nil)
    h.system.setMinimized(windows[3], true)
    #expect(h.layout!.windowFrames[windows[0]] != nil && h.layout!.windowFrames[windows[2]] != nil)
    h.system.setMinimized(windows[3], false)
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[windows[0]] != nil)
    expectWindowsMatchLayout(h)
  }

  /// Whoever went during a pause is away when Arbor looks again. A window put back in its place then moves nothing else.
  @Test func aPauseMeanwhileChangesNothing() {
    let desk = Desk()
    let before = desk.places
    desk.h.run("pause")
    desk.hide(desk.finder)
    desk.h.run("resume")
    desk.h.scheduler.advance(by: 2)
    let found = desk.places
    #expect(found != before)
    desk.h.controller.relayout(desk.h.display, reason: .enforce)
    #expect(desk.places == found)
    desk.hide(desk.finder, false)
    #expect(desk.places == before)
    expectWindowsMatchLayout(desk.h)
  }

  /// No gap moves under a window that is being dragged, and the drop finds the gaps that these windows have had before.
  @Test func whoComesAndGoesDuringADragMovesNoGap() {
    let desk = Desk()
    desk.hide(desk.finder)
    let meanwhile = desk.places
    desk.h.system.beginDrag(desk.terminal)
    desk.h.system.moveDrag(to: CGPoint(x: 140, y: 500), holding: 0.1)
    desk.h.system.setMinimized(desk.textEdit, true)
    desk.h.system.setMinimized(desk.textEdit, false)
    desk.h.scheduler.advance(by: 2)
    #expect(desk.places == meanwhile)
    desk.h.system.endDrag()
    desk.h.scheduler.advance(by: 2)
    #expect(desk.places == meanwhile)
    expectWindowsMatchLayout(desk.h)
  }

  /// The next layout after the drop is the one for whoever went during the drag: it looks as it would have without a drag.
  @Test(arguments: [false, true]) func whoWentDuringADragIsAwayAfterTheDrop(makingWay: Bool) {
    let plain = Desk(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    plain.hide(plain.finder)
    plain.h.system.setMinimized(plain.textEdit, true)

    let desk = Desk(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    desk.hide(desk.finder)
    desk.h.system.beginDrag(desk.terminal)
    desk.h.system.moveDrag(to: CGPoint(x: 140, y: 500), holding: 0.1)
    desk.h.system.setMinimized(desk.textEdit, true)
    desk.h.scheduler.advance(by: 2)
    desk.h.system.endDrag()
    desk.h.scheduler.advance(by: 2)
    // A drop that changes nothing lays nothing out, and a window put back in its place moves nothing else.
    let dropped = desk.places
    desk.h.controller.relayout(desk.h.display, reason: .enforce)
    #expect(desk.places == dropped)
    desk.h.controller.relayout(desk.h.display, reason: .structure)
    #expect(desk.places == plain.places)
    // A control, on the desk that was seen. As Arbor ships the layout at the drop has seen to it already.
    if makingWay { #expect(desk.places != dropped) }
    expectWindowsMatchLayout(desk.h)
  }

  /// An undo settles what the Desktop is owed after it has laid out.
  @Test func whatTheDesktopIsOwedAfterAnUndoOutlivesThereAndBack() {
    let h = Harness(settings: .withDesktopColumn)
    let notes = h.system.open(app: "Notes", pid: 2001, minimumSize: CGSize(width: 709, height: 300))
    let safari = h.system.open(app: "Safari", pid: 2002, minimumSize: CGSize(width: 574, height: 240))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.workspace.desktopIsOwedRoom == true)
    h.run("resize \(notes.rawValue) right -300")
    h.run("undo")
    #expect(h.workspace.desktopIsOwedRoom == true)
    h.system.setHidden(pid: 2002, true)
    h.scheduler.runPending()
    h.system.setHidden(pid: 2002, false)
    h.scheduler.runPending()
    #expect(h.workspace.desktopIsOwedRoom == true)
    expectWindowsMatchLayout(h)
  }

  /// A has room only because C went, and somebody types in it when C comes back by itself (Show All, a Space that returns). The window
  /// with the keyboard is the last to become a tile (F61): it stays, and the gaps go on from where they are.
  @Test(.withTiles) func theWindowBeingTypedInDoesNotLeaveTheViewForIt() {
    let h = Harness(displays: [
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1280, height: 900),
        visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 875), isMain: true)
    ])
    let windows = [501, 574, 334].enumerated().map {
      h.system.open(app: "App\($0.offset)", pid: Int32(3000 + $0.offset), minimumSize: CGSize(width: $0.element, height: 0))
    }
    h.start()
    for line in ["dock 101 left", "dock 102 right", "dock 103 right"] { h.run(line) }
    #expect(h.layout!.windowFrames[windows[0]] == nil)
    h.system.setHidden(pid: 3002, true)
    h.scheduler.runPending()
    #expect(h.layout!.windowFrames[windows[0]] != nil)
    h.system.userFocus(windows[0])
    h.system.setHidden(pid: 3002, false)
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[windows[0]] != nil)
    expectWindowsMatchLayout(h)
  }

  /// A window put back in its place between the report that Finder went and the layout for it sees a wide Desktop, to which
  /// nothing is owed. That is not what stood.
  @Test func whatTheDesktopIsOwedOutlivesALayoutThatComesInBetween() {
    let desk = Desk(settings: .withDesktopColumn)
    #expect(desk.h.workspace.desktopIsOwedRoom == true)
    let (before, tree) = (desk.places, desk.h.workspace.tree)
    desk.h.system.setOnActiveSpace(desk.finder, false)
    desk.h.controller.relayout(desk.h.display, reason: .enforce)
    desk.h.scheduler.runPending()
    desk.h.system.setOnActiveSpace(desk.finder, true)
    desk.h.scheduler.runPending()
    #expect(desk.places == before)
    #expect(desk.h.workspace.desktopIsOwedRoom == true)

    // Gone and back before the layout for it: what the put-back made of the gaps is nobody's.
    desk.h.system.setOnActiveSpace(desk.finder, false)
    desk.h.controller.relayout(desk.h.display, reason: .enforce)
    desk.h.system.setOnActiveSpace(desk.finder, true)
    desk.h.scheduler.runPending()
    #expect(desk.h.workspace.tree == tree)
    expectWindowsMatchLayout(desk.h)
  }

  /// TextEdit is in the Dock when a gap is moved by hand. Once it is back it is of the party: with all three there, that is what comes back.
  @Test func aWindowThatWasAwayAtTheLastChangeIsOfThePartyOnceItIsBack() {
    let desk = Desk()
    desk.h.system.setMinimized(desk.textEdit, true)
    desk.h.run("resize \(desk.finder.rawValue) right 40")
    desk.h.system.setMinimized(desk.textEdit, false)
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("show-all")
    let (standing, tree) = (desk.places, desk.h.workspace.tree)
    desk.hide(desk.finder)
    desk.hide(desk.finder, false)
    #expect(desk.places == standing)
    #expect(desk.h.workspace.tree == tree)
    expectWindowsMatchLayout(desk.h)
  }

  /// Undo takes back what the person did, with the gaps of that time, whoever has come and gone since.
  @Test func undoStillTakesBackTheLastDock() {
    let desk = Desk()
    desk.hide(desk.finder)
    desk.hide(desk.finder, false)
    desk.h.run("undo")
    #expect(desk.h.workspace.isFloating(desk.textEdit))
    expectWindowsMatchLayout(desk.h)
  }

  /// (On the desk that was seen, where Safari is a tile with Finder there and with Finder away. Without the column it shows meanwhile, and goes
  /// out of view again at another size than before, which `places` tells.)
  @Test func withoutRoomBeforeTilesItHeldAllAlong() {
    var settings = Settings.withDesktopColumn
    settings.makeRoom = false
    let desk = Desk(settings: settings)
    let before = desk.places
    desk.hide(desk.finder)
    desk.hide(desk.finder, false)
    #expect(desk.places == before)
    expectWindowsMatchLayout(desk.h)
  }

  // MARK: The net

  /// Random arrangements of windows with the smallest sizes of real apps, on displays of several sizes, with gaps moved by hand.
  /// Then windows are hidden, minimized and sent to another Space and come back, in any order. Once all are back the
  /// arrangement and every docked window's frame are what they were, and nothing moved more than once at any step.
  @Test(arguments: 0..<8) func anyOrderOverRandomArrangements(block: UInt64) {
    for seed in (block * 80)..<(block * 80 + 80) {
      var random = ChaosRandom(seed: seed)
      let width = random.pick([1280, 1440, 1600, 1920, 2560])!
      let h = Harness(displays: [
        DisplaySnapshot(
          id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: width, height: 900),
          visibleFrame: CGRect(x: 0, y: 25, width: width, height: 875), isMain: true)
      ])
      let widths: [CGFloat] = [0, 115, 177, 334, 501, 574, 660, 709, 740]
      var script: [String] = ["display \(width)"]
      let windows = (0..<random.int(2...6)).map { index -> WindowID in
        let minimum = CGSize(width: random.pick(widths)!, height: random.pick([0, 100, 240, 300, 384])!)
        script.append("open min \(Int(minimum.width))x\(Int(minimum.height))")
        return h.system.open(app: "App\(index)", pid: Int32(3000 + index), minimumSize: minimum)
      }
      h.start()
      func run(_ line: String) {
        script.append(line)
        h.run(line)
      }
      var docked: [WindowID] = []
      for window in windows where docked.isEmpty || random.chance(85) {
        let edge = random.pick(["left", "right", "top", "bottom"])!
        if let other = random.pick(docked), random.chance(50) {
          run("dock \(window.rawValue) beside \(other.rawValue) \(edge)")
        } else {
          run("dock \(window.rawValue) \(edge)")
        }
        docked.append(window)
      }
      // In some walks a window is in the Dock while the gaps are moved by hand.
      let late = random.chance(25) ? random.pick(docked) : nil
      if let late {
        script.append("minimize \(late.rawValue)")
        h.system.setMinimized(late, true)
      }
      for _ in 0..<random.int((late == nil ? 0 : 1)...2) {
        run("resize \(random.pick(docked)!.rawValue) \(random.pick(["left", "right", "top", "bottom"])!) \(random.pick([-1, 1])! * random.int(20...120))")
      }
      if let late {
        script.append("restore \(late.rawValue)")
        h.system.setMinimized(late, false)
      }
      run("show-all")
      h.scheduler.advance(by: 2)
      // Where there is not room for all, the window with the keyboard is served first (F61), so who has it when a layout is made
      // is part of what the layout depends on. In every other walk it stays in a floating window that stays.
      let keyboardStays = seed % 2 == 0
      if keyboardStays {
        h.system.userFocus(h.system.open(app: "Bystander", pid: 2999, frame: CGRect(x: 40, y: 60, width: 200, height: 120)))
        h.system.echoes.keyboard = false
        script.append("the keyboard stays in a floating window")
      }

      enum Way: CaseIterable { case hidden, minimized, elsewhere }
      var walk: [(window: WindowID, way: Way, gone: Bool, interrupted: Bool)] = []
      var away: [WindowID: Way] = [:]
      for _ in 0..<random.int(1...8) {
        let window = random.pick(docked)!
        if let way = away.removeValue(forKey: window) {
          walk.append((window, way, false, random.chance(20)))
        } else {
          away[window] = random.pick(Way.allCases)!
          walk.append((window, away[window]!, true, random.chance(20)))
        }
      }
      while let window = random.pick(away.keys.sorted()) { walk.append((window, away.removeValue(forKey: window)!, false, false)) }
      script += walk.map { "\($0.gone ? "away" : "back") \($0.window.rawValue) \($0.way)\($0.interrupted ? ", interrupted" : "")" }
      let story = Comment(rawValue: "seed \(seed):\n" + script.joined(separator: "\n"))

      /// The window being typed in would have left the view, so the gaps went on from where they were.
      var startedAfresh = false
      /// Returns what went wrong on the way. A window took a detour at a step (`FakeWindowSystem.detour`): not where the view moved as well (a
      /// window that comes back as a tile and has the keyboard is framed, after the layout that gave it its tile), nor
      /// where Arbor learns how small a window goes (it is asked, refuses, and room is made for it, F61). Or the same
      /// windows, with the same known of their sizes, did not give the same layout as before. Or a window put back in its
      /// place afterwards moved something else.
      func goThereAndBack() -> [String] {
        var problems: [String] = []
        var layouts: [String: Layout] = [:]
        let stood = h.controller.standingGaps[h.display]!
        for (step, (window, way, gone, interrupted)) in walk.enumerated() {
          let (view, known, mark) = (h.workspace.camera, h.controller.minimumSizes, h.system.moveLog.count)
          switch way {
          case .hidden: h.system.setHidden(pid: h.system.windows[window]!.snapshot.pid, gone)
          case .minimized: h.system.setMinimized(window, gone)
          case .elsewhere: h.system.setOnActiveSpace(window, !gone)
          }
          // A window put back in its place can come between the report and the layout for it.
          if interrupted { h.controller.relayout(h.display, reason: .enforce) }
          // Long enough for all of a step's reports to be in, and for a window that is only just back to be asked again
          // (Controller+OnTheWayBack.swift).
          h.scheduler.advance(by: 2)
          let there = docked.filter { h.controller.windows[$0]!.isPresent }
          let sizes = h.controller.minimumSizes.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
          if keyboardStays, let last = layouts.updateValue(h.layout!, forKey: "\(there) \(sizes)"), last != h.layout {
            problems.append("step \(step + 1): with \(there) there it was \(last.windowFrames) and is \(h.layout!.windowFrames)")
          }
          if h.workspace.camera == view, h.controller.minimumSizes == known, !interrupted {
            problems += docked.map { h.system.road(of: $0, since: mark) }.filter { !$0.isEmpty }.compactMap(FakeWindowSystem.detour).map { "step \(step + 1): \($0)" }
          }
          let stands = h.controller.standingGaps[h.display]!
          if stands.present != stood.present || !stands.tree.hasSameArrangement(as: stood.tree) { startedAfresh = true }
          let settled = h.layout
          h.controller.relayout(h.display, reason: .enforce)
          if h.layout != settled { problems.append("step \(step + 1): a window put back in its place moved something else") }
        }
        h.run("show-all")
        h.scheduler.advance(by: 2)
        return problems
      }
      // How small a window goes Arbor learns when the window refuses a slot, which takes a second move and is an occasion to
      // make room (F61). The first time round it may learn; then it knows.
      _ = goThereAndBack()
      let (before, tree, owed) = (h.layout!, h.workspace.tree, h.workspace.desktopIsOwedRoom)
      let frames = Dictionary(uniqueKeysWithValues: docked.map { ($0, h.frame($0)!) })
      startedAfresh = false
      #expect(goThereAndBack() == [], story)
      #expect(h.staleLayouts() == [], story)
      #expect(!startedAfresh || !keyboardStays, story)
      if startedAfresh { continue }

      #expect(h.workspace.tree.hasSameArrangement(as: tree), story)
      #expect(h.layout == before, story)
      #expect(h.workspace.desktopIsOwedRoom == owed, story)
      // The slots are the same to the last digit. A window within a point of its slot is left where it is (`Controller.isInPlace`).
      let moved = docked.filter { before.windowFrames[$0] != nil && !h.frame($0)!.approximatelyEquals(frames[$0]!, tolerance: 1) }
        .map { "\($0): \(frames[$0]!) became \(h.frame($0)!)" }
      #expect(moved == [], story)
    }
  }
}
