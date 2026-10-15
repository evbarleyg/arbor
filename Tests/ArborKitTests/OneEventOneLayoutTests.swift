import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// One thing that happens is one layout. Whatever an event sets off is worked out to its end before the first frame is set, so
/// every window has one road: it changes place once at most, no edge goes past where it ends up and back
/// (`FakeWindowSystem.detour`), and nothing leaves the screen to come back or shows to go again.
@MainActor private struct Roads {
  var roads: [WindowID: [CGRect]] = [:]
  let display: CGRect

  /// Every frame each window had while `body` ran and what it scheduled was done, beginning with the one it had before.
  /// `atOnce`: only what is due without any time passing.
  init(_ h: Harness, atOnce: Bool = false, during body: () -> Void) {
    display = h.system.displayList[0].frame
    let mark = h.system.moveLog.count
    body()
    for _ in 0..<3 { if atOnce { h.scheduler.advance(by: 0) } else { h.scheduler.runPending() } }
    for window in Set(h.system.moveLog[mark...].map(\.window)) { roads[window] = h.system.road(of: window, since: mark) }
  }

  private func shows(_ frame: CGRect) -> Bool {
    let showing = frame.intersection(display)
    return !showing.isNull && showing.width > 2 && showing.height > 2
  }

  func expectOneRoadEach(sourceLocation: SourceLocation = #_sourceLocation) {
    for (window, road) in roads.sorted(by: { $0.key < $1.key }) where !road.isEmpty {
      if let detour = FakeWindowSystem.detour(road) { Issue.record("\(window) \(detour)", sourceLocation: sourceLocation) }
      let inView = road.map(shows)
      #expect(
        zip(inView, inView.dropFirst()).filter { $0 != $1 }.count <= 1, "\(window) came and went: \(road.map(\.brief))",
        sourceLocation: sourceLocation)
    }
  }
}

/// The rules of the walks that say so of docked windows. They are known failures for as long as one story is left, so a script that has
/// been cured is held to them here (`ChaosKnownFailures.swift`, "one thing that happens is one layout").
private let oneLayout: Set<String> = [
  "moved-twice", "moved-twice-sizing", "moved-twice-sizing-again", "moved-again", "moved-again-sizing", "moved-again-sizing-again",
  "flashed-into-view", "flashed-out-of-view", "moved-over-and-over", "sized-there-and-back", "moved-twice-floating-making-way",
]

/// Replays a script of the walks. At its last line, which is what the script is about, none of those rules is excused.
@MainActor private func expectOneLayoutAtTheEnd(of script: String, sourceLocation: SourceLocation = #_sourceLocation) {
  let runner = ChaosRunner()
  let actions = ChaosAction.script(script)
  for (index, action) in actions.enumerated() {
    let excused = index == actions.count - 1 ? ChaosRunner.knownRules.subtracting(oneLayout) : ChaosRunner.knownRules
    let violations = runner.step(action).filter { !excused.contains($0.rule) }
    #expect(violations.isEmpty, "\(action.text): \(violations)", sourceLocation: sourceLocation)
    #expect(runner.refusals.isEmpty, "\(action.text): \(runner.refusals)", sourceLocation: sourceLocation)
  }
}

/// `shrink` cannot know how small an app lets its window get. It asks the window where it stands, before a gap or a neighbour moves.
@Suite @MainActor struct ShrinkIsOneLayoutTests {
  /// A window that goes no narrower than 400 points on the left, a neighbour on the right, the keyboard in the first.
  private func pair(minimum: CGSize = CGSize(width: 400, height: 300)) -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Xcode", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 500), minimumSize: minimum)
    let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 500, y: 200, width: 500, height: 400))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.runPending()
    return (h, a, b)
  }

  @Test func aWindowThatWillNotBeThatSmallNeverLeavesTheScreen() {
    let (h, a, _) = pair()
    let roads = Roads(h) { runOK(h, "shrink 400") }
    roads.expectOneRoadEach()
    #expect((400...402).contains(h.frame(a)!.width), "as far as its app lets it: \(h.frame(a)!.brief)")
    #expect(h.layout!.tiles.isEmpty && h.system.focused == a)
    expectSound(h)
  }

  @Test func itsNeighboursMoveOnce() {
    let h = Harness()
    let a = h.system.open(app: "Mail", pid: 1001, frame: CGRect(x: 138, y: 215, width: 1166, height: 511), minimumSize: CGSize(width: 760, height: 400))
    let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 76, y: 60, width: 700, height: 500))
    h.start()
    runOK(h, "dock \(b.rawValue) left")
    runOK(h, "dock \(a.rawValue) top")
    h.system.userFocus(a)
    h.scheduler.runPending()
    let below = h.frame(b)!
    let roads = Roads(h) { runOK(h, "shrink 100") }
    roads.expectOneRoadEach()
    #expect((400...402).contains(h.frame(a)!.height), "\(h.frame(a)!.brief)")
    #expect(roads.roads[b]?.count == 2 && h.frame(b)!.minY < below.minY, "straight to where it ends up: \(roads.roads[b] ?? [])")
    expectSound(h)
  }

  /// What it takes it keeps: narrower as asked, no shorter than its app allows.
  @Test func oneWayIsRefusedAndTheOtherIsNot() {
    let h = Harness()
    let a = h.system.open(app: "Mail", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 420), minimumSize: CGSize(width: 200, height: 400))
    let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 500, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "Safari", pid: 1003, frame: CGRect(x: 300, y: 300, width: 500, height: 400))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    runOK(h, "dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.system.userFocus(a)
    h.scheduler.runPending()
    let before = h.frame(a)!
    let roads = Roads(h) { runOK(h, "shrink 60") }
    roads.expectOneRoadEach()
    #expect(abs(h.frame(a)!.width - (before.width - 60)) <= 1, "\(before.brief) → \(h.frame(a)!.brief)")
    #expect((400...402).contains(h.frame(a)!.height), "\(before.brief) → \(h.frame(a)!.brief)")
    expectSound(h)
  }

  /// A command that fails has changed nothing, to the eye either.
  @Test func aWindowAtItsSmallestIsAskedAndNothingMoves() {
    let (h, a, _) = pair()
    runOK(h, "shrink 400")
    // Forgotten, as after `relayout`: Arbor has to ask again.
    runOK(h, "relayout")
    let roads = Roads(h) { #expect(h.run("shrink").message == "\(a) cannot shrink any further") }
    #expect(roads.roads.values.allSatisfy { FakeWindowSystem.changesOfPlace($0) == 0 }, "\(roads.roads)")
    roads.expectOneRoadEach()
    expectSound(h)
  }

  /// Two side by side below a third thing, the keyboard in the right one, which goes no lower than `least`. `shrink` makes both lower.
  private func aRow(least: CGSize) -> (Harness, left: WindowID, right: WindowID) {
    let h = Harness()
    let left = h.system.open(app: "Music", pid: 1006, frame: CGRect(x: 111, y: 278, width: 867, height: 435), minimumSize: CGSize(width: 100, height: 60))
    let right = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 36, y: 80, width: 907, height: 426), minimumSize: least)
    h.start()
    runOK(h, "dock \(left.rawValue) bottom")
    runOK(h, "dock \(right.rawValue) beside \(left.rawValue) right")
    h.system.userFocus(right)
    h.scheduler.runPending()
    return (h, left, right)
  }

  /// The window the command is about is asked first: on its answer hangs what is asked of the others.
  @Test func aNeighbourThatShrinksAlongIsNotAskedForALayoutThatNeverComes() {
    let (h, left, right) = aRow(least: CGSize(width: 100, height: 312))
    let roads = Roads(h) { runOK(h, "shrink 200") }
    roads.expectOneRoadEach()
    #expect((312...314).contains(h.frame(right)!.height) && h.frame(left)!.height == h.frame(right)!.height)
    expectSound(h)
  }

  @Test func whereItCannotShrinkAtAllItsNeighbourIsNotTouched() {
    let (h, left, right) = aRow(least: CGSize(width: 702, height: 419))
    let roads = Roads(h) { #expect(h.run("shrink").message == "\(right) cannot shrink any further") }
    #expect(roads.roads[left] == nil, "\(roads.roads[left]?.map(\.brief) ?? [])")
    roads.expectOneRoadEach()
    expectSound(h)
  }

  /// Its app lets it be no smaller than a point or two more than its slot, which passes for rounding until it is asked for less. However
  /// that ends, no key goes to a window out of view.
  @Test func theKeyboardIsNeverLeftInAWindowOutOfView() {
    let h = Harness()
    let above = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 17, y: 193, width: 602, height: 433), minimumSize: CGSize(width: 100, height: 60))
    let below = h.system.open(app: "Preview", pid: 1007, frame: CGRect(x: 207, y: 161, width: 700, height: 557), minimumSize: CGSize(width: 702, height: 419))
    h.start()
    runOK(h, "dock \(above.rawValue) left")
    runOK(h, "dock \(below.rawValue) beside \(above.rawValue) bottom")
    h.system.userFocus(below)
    h.scheduler.runPending()
    _ = h.run("shrink 2")
    _ = h.run("shrink 2")
    h.scheduler.advance(by: 1)
    #expect(h.system.focused.map { !h.controller.parked.contains($0) } == true, "\(String(describing: h.system.focused)) has the keyboard")
  }

  /// Its app's smallest size has grown since it was seen smaller. The window the command is about is asked whatever is known of it, or
  /// it would refuse in its slot, when its neighbour has moved.
  @Test func aWindowThatWasOnceSmallerIsAskedAllTheSame() {
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [wide])
    let a = h.system.open(app: "Music", pid: 1006, frame: CGRect(x: 111, y: 278, width: 250, height: 300))
    let b = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 36, y: 80, width: 907, height: 426))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) beside \(a.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.runPending()
    let least = h.frame(a)!.width - 24
    #expect(least - 76 > 250, "the story needs a window that has been smaller than it is asked to be: \(h.frame(a)!.brief)")
    h.system.setMinimumSize(a, CGSize(width: least, height: 100))
    let roads = Roads(h) { runOK(h, "shrink 100") }
    roads.expectOneRoadEach()
    #expect((least...least + 2).contains(h.frame(a)!.width), "\(h.frame(a)!.brief)")
    #expect(roads.roads[b]?.count == 2, "its neighbour goes straight to where it ends up: \(roads.roads[b]?.map(\.brief) ?? [])")
    expectSound(h)
  }

  /// `[ a | visitor | b | Desktop ]`, and the visitor never comes: its place has waited too long. It does not go under a hand that holds
  /// the gaps (`dropOverdueSlots`), so the tree that is put back when a window refuses is the tree there is: nothing is lost and
  /// nothing comes back. It goes with the next layout that is asked for.
  @Test func aPlaceThatHasWaitedTooLongIsNeitherLostNorBroughtBack() {
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let first = Harness(displays: [wide])
    let (a, b, v) = (first.system.open(app: "A"), first.system.open(app: "B"), first.system.open(app: "Visitor"))
    first.start()
    first.run("dock \(a.rawValue) left")
    first.run("dock \(b.rawValue) beside \(a.rawValue) right")
    first.run("resize \(a.rawValue) right 200")
    first.run("dock \(v.rawValue) beside \(a.rawValue) right")
    first.controller.saveNow()

    let h = Harness(displays: [wide], saved: first.store.saved)
    h.system.open(app: "A")
    h.system.open(app: "B")
    h.start()
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 3)
    #expect(h.workspace.tree.allWindows.count == 3, "the story needs a place that is overdue: \(h.workspace.tree.allWindows)")
    let least = h.frame(a)!.width - 60
    h.system.setMinimumSize(a, CGSize(width: least, height: 300))
    h.system.userFocus(a)
    h.scheduler.runPending()
    _ = h.run("shrink 1000")
    #expect((least...least + 2).contains(h.frame(a)!.width), "the story needs a refusal: \(h.frame(a)!.brief)")
    #expect(h.workspace.tree.allWindows.count == 3, "\(h.workspace.tree.allWindows)")
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    h.run("relayout")
    #expect(Set(h.workspace.tree.allWindows) == [a, b])
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    #expect(!h.run("status").message.contains("kept"))
    expectSound(h)
  }

  /// An app that asks for more every time it is asked is not asked for ever, and no gap chases it: it ends as everything else that
  /// cannot be shrunk, with every window in its slot.
  @Test(arguments: [5, 15, 40]) func anAppThatAsksForMoreEveryTimeEndsInItsSlot(step: CGFloat) {
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [wide])
    let a = h.system.open(app: "A", pid: 1001, frame: CGRect(x: 100, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 300, height: 200))
    let b = h.system.open(app: "B", pid: 1002, frame: CGRect(x: 300, y: 100, width: 900, height: 700))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) beside \(a.rawValue) right")
    h.system.userFocus(a)
    h.scheduler.runPending()
    var least: CGFloat = 300
    h.system.willSetFrame = { window, _ in
      guard window == a else { return }
      least += step
      h.system.setMinimumSize(a, CGSize(width: least, height: 200))
    }
    _ = h.run("shrink 600")
    h.system.willSetFrame = nil
    // In its slot, or a tile, out of view, if by now it asks for more than it had.
    if let slot = h.layout!.windowFrames[a] {
      #expect(h.frame(a)!.width <= slot.width + 2, "larger than its slot: \(h.frame(a)!.brief) in \(slot.brief)")
      #expect(h.frame(a)!.maxX <= h.frame(b)!.minX, "\(h.frame(a)!.brief) lies over \(h.frame(b)!.brief)")
    } else {
      #expect(h.controller.parked.contains(a) && h.system.focused != a, "\(h.frame(a)!.brief), keyboard in \(String(describing: h.system.focused))")
    }
    #expect(h.frame(b) == h.layout!.windowFrames[b], "\(h.frame(b)!.brief)")
  }

  /// Once it is known there is nothing to ask. (So it was before: a guard.)
  @Test func theSecondTimeNothingIsAsked() {
    let (h, a, _) = pair()
    runOK(h, "shrink 400")
    runOK(h, "grow 100")
    let mark = h.system.frameLog.count
    runOK(h, "shrink 400")
    #expect(h.system.frameLog[mark...].filter { $0.window == a }.count == 1, "\(h.system.frameLog[mark...])")
    expectSound(h)
  }

  /// As the walks found it: the window left the screen and came back, its neighbours went there and back.
  @Test(arguments: [
    """
    launch
    open 102 Xcode pid 1004 at 76 25 1248 875 min 1188 685
    open 103 Mail pid 1002 at 138 215 1166 511 min 760 400
    via shortcut arrange
    key down dock top
    key down shrink
    """,
    """
    launch
    open 101 Terminal pid 1003 at 418 361 710 424 min 177 60
    open 102 Safari pid 1000 at 1884 235 1368 960 min 574 240
    displays side:0,0,1920,1080:25,70,0,0* windows-first
    open 104 Music pid 1006 at 464 230 1147 600 min 680 480
    via shortcut arrange
    key down shrink
    """,
    """
    displays main:-323,1080,1728,1117:37,0,0,0 side:0,0,1920,1080:25,0,59,0* windows-never
    launch
    open 106 Safari pid 1000 at 392 153 1068 784 min 574 240
    key down dock right
    open 107 Music pid 1006 at 353 472 823 582 min 680 480
    key down dock top
    key down shrink
    """,
    """
    displays side:0,0,3008,1692:25,0,0,0* windows-never
    open 102 Preview pid 1007 at 154 218 723 579 min 723 400 max 723 2000
    open 103 Notes pid 1001 at 280 307 709 462 min 709 300
    launch
    key down focus right
    key down dock right
    key down desktop
    key down home
    key down back
    key down dock right
    key down show-all
    key down shrink
    """,
    """
    displays main:0,0,1440,900:25,0,0,0* side:1440,150,1920,1080:25,0,0,0 windows-never
    open 101 Mail pid 1002 at 2200 325 803 658 min 760 400
    launch
    open 103 Safari pid 1000 at 2175 376 1128 656 min 574 240
    grab 103
    carry 3356 953
    via shortcut arrange
    quit
    launch
    focus 101
    key down shrink
    """,
    // Asked where it stands, it keeps a size that passes for rounding, and its slot begins a point further on. That move was foretold
    // with its neighbours', so it has to be asked for: Arbor took the window to be where it was.
    """
    displays main:0,0,1440,900:25,0,0,0* windows-never
    launch
    open 101 Terminal pid 1003 at 317 72 734 829 min 734 829 grid
    open 102 Preview pid 1007 at 151 30 763 436 min 100 436 max 877 617
    open 103 Mail pid 1002 at 247 148 1092 731 min 485 731
    open 104 Safari pid 1000 at 282 153 762 575 min 492 575
    open 105 Xcode pid 1004 at 214 37 828 584 min 828 162
    dock 101 left
    dock 102 right
    dock 103 beside 101 top
    dock 104 beside 103 left
    dock 105 beside 101 right
    relayout
    focus 103
    shrink 2
    """,
  ]) func theWalksOwnScripts(_ script: String) { expectOneLayoutAtTheEnd(of: script) }

  /// Seen on a hosted Mac first: one press, six frames, one of them out of view. A display of 1024 by 768 points, in thirds then, with a
  /// column for the Desktop; in halves as Arbor ships. Either way the press runs into the window's smallest size.
  @Test(arguments: [true, false]) func onASmallDisplay(desktopColumn: Bool) {
    let small = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737), isMain: true)
    let h = Harness(displays: [small], settings: desktopColumn ? .withDesktopColumn : Settings())
    let least: CGFloat = desktopColumn ? 300 : 470
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002, minimumSize: CGSize(width: least, height: 200))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    h.system.userFocus(b)
    h.scheduler.runPending()
    let roads = Roads(h) { runOK(h, "shrink") }
    roads.expectOneRoadEach()
    #expect((least...least + 2).contains(h.frame(b)!.width) && h.frame(b)!.maxX == h.layout!.windowFrames[b]!.maxX, "\(h.frame(b)!.brief)")
    expectSound(h)
  }
}

/// A docked window comes back (out of the Dock, with its app) and has the keyboard, to a place that does not show. The view follows
/// the keyboard, so that is the view the display is laid out for: not first for the one it is about to leave.
@Suite @MainActor struct BackWithTheKeyboardIsOneLayoutTests {
  /// Two windows too wide to show beside anything, one on each side of a third, which is in view. With the keyboard or without, `wide`
  /// is a tile there: its neighbour cannot spare what it needs.
  private func aTileAndItsNeighbour() -> (Harness, wide: WindowID, music: WindowID) {
    let h = Harness()
    let other = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 0, y: 52, width: 1370, height: 685), minimumSize: CGSize(width: 1188, height: 685))
    let music = h.system.open(app: "Music", pid: 1006, frame: CGRect(x: 336, y: 214, width: 853, height: 480), minimumSize: CGSize(width: 680, height: 480))
    let wide = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 39, y: 48, width: 1188, height: 800), minimumSize: CGSize(width: 1188, height: 685))
    h.start()
    runOK(h, "dock \(music.rawValue) left")
    runOK(h, "dock \(other.rawValue) left")
    h.system.userFocus(music)
    runOK(h, "dock \(wide.rawValue) right")
    h.system.userFocus(music)
    h.scheduler.advance(by: 1)
    return (h, wide, music)
  }

  @Test func outOfTheDock() {
    let (h, wide, music) = aTileAndItsNeighbour()
    #expect(h.layout!.windowFrames[wide] == nil && h.layout!.windowFrames[music] != nil, "the story needs a tile: \(h.layout!)")
    h.system.setMinimized(wide, true)
    h.scheduler.advance(by: 1)
    let roads = Roads(h) { h.system.setMinimized(wide, false) }
    roads.expectOneRoadEach()
    #expect(h.layout!.windowFrames[wide] != nil && h.system.focused == wide, "the view has followed the keyboard")
    #expect(roads.roads[music]?.count == 2, "straight out of view: \(roads.roads[music]?.map(\.brief) ?? [])")
    expectSound(h)
  }

  @Test func withItsApp() {
    let (h, wide, music) = aTileAndItsNeighbour()
    h.system.setHidden(pid: 1004, true)
    h.scheduler.advance(by: 1)
    // The keyboard is reported first, as out of the Dock.
    let roads = Roads(h) {
      h.system.userFocus(wide)
      h.system.setHidden(pid: 1004, false)
    }
    roads.expectOneRoadEach()
    #expect(h.layout!.windowFrames[wide] != nil && h.system.focused == wide, "the view has followed the keyboard")
    #expect(roads.roads[music]?.count == 2, "straight out of view: \(roads.roads[music]?.map(\.brief) ?? [])")
    expectSound(h)
  }

  /// Safari on the left, Notes above Mail on the right. Mail goes away, and the view is framed on Safari.
  private func framedElsewhere(_ away: (Harness, WindowID) -> Void) -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "dock \(safari.rawValue) left")
    runOK(h, "dock \(notes.rawValue) right")
    runOK(h, "dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.system.userFocus(safari)
    away(h, mail)
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(safari.rawValue)")
    h.scheduler.advance(by: 1)
    return (h, safari, notes, mail)
  }

  /// It stood in its old slot when it went. From there it goes straight to where it ends up, not by way of the corner.
  @Test func intoAViewThatWasFramedElsewhere() {
    let (h, _, notes, mail) = framedElsewhere { $0.system.setMinimized($1, true) }
    let roads = Roads(h) { h.system.setMinimized(mail, false) }
    roads.expectOneRoadEach()
    #expect(roads.roads[mail].map(FakeWindowSystem.changesOfPlace) == 1, "\(roads.roads[mail]?.map(\.brief) ?? [])")
    #expect(roads.roads[notes] == nil, "nobody asked for it: \(roads.roads[notes]?.map(\.brief) ?? [])")
    #expect(h.layout!.windowFrames[mail] != nil && h.system.focused == mail)
    expectSound(h)
  }

  /// The same by name: Go to…, `reveal`, a row of the menu.
  @Test func fetchedByName() {
    let (h, _, notes, mail) = framedElsewhere { $0.system.setMinimized($1, true) }
    let roads = Roads(h) { runOK(h, "reveal \(mail.rawValue)") }
    roads.expectOneRoadEach()
    #expect(roads.roads[mail].map(FakeWindowSystem.changesOfPlace) == 1, "\(roads.roads[mail]?.map(\.brief) ?? [])")
    #expect(roads.roads[notes] == nil, "nobody asked for it: \(roads.roads[notes]?.map(\.brief) ?? [])")
    #expect(h.layout!.windowFrames[mail] != nil && h.system.focused == mail)
    expectSound(h)
  }

  /// There and back is nothing (Controller+ThereAndBack.swift), also where the layout for the view that is left is skipped: it is carried out on
  /// paper. A crowded row in which room has been made; Mail goes, the view goes elsewhere, Mail comes back. With everything in view again
  /// everybody stands where they stood. Skipped altogether, the gaps that stood were forgotten and Safari ended as a tile.
  @Test(arguments: [true, false]) func backAtEverythingEverybodyStandsWhereTheyStood(byName: Bool) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.system.setMinimumSize(notes, CGSize(width: 700, height: 500))
    h.system.setMinimumSize(mail, CGSize(width: 900, height: 600))
    h.start()
    runOK(h, "dock \(safari.rawValue) right")
    runOK(h, "dock \(notes.rawValue) beside \(safari.rawValue) right")
    runOK(h, "dock \(mail.rawValue) beside \(notes.rawValue) right")
    h.system.userFocus(mail)
    h.scheduler.advance(by: 1)
    runOK(h, "home")
    h.scheduler.advance(by: 1)
    let stood = h.layout!.windowFrames
    #expect(stood[safari] != nil && stood[mail] != nil, "the story needs them in view: \(h.ascii())")
    h.system.setMinimized(mail, true)
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(notes.rawValue)")
    h.scheduler.advance(by: 1)
    let roads = Roads(h) { if byName { runOK(h, "reveal \(mail.rawValue)") } else { h.system.setMinimized(mail, false) } }
    roads.expectOneRoadEach()
    #expect(h.layout!.windowFrames.keys.sorted() == [mail], "the story needs the view to go to it: \(h.ascii())")
    h.scheduler.advance(by: 1)
    runOK(h, "home")
    h.scheduler.advance(by: 1)
    #expect(h.layout!.windowFrames == stood, "\(h.ascii())")
    expectSound(h)
  }

  /// Only for a window that comes back. For a new window that a rule docks where it does not show, the layout that is skipped has never been
  /// carried out, on paper or otherwise: room made for it there would stay behind when it closes. A gap moved by hand; the new
  /// window comes and goes at once; with everything in view again three of the four show. With room left behind it was two.
  @Test func aNewWindowThatARuleDocksLeavesNoRoomBehind() {
    let h = Harness()
    func open(_ app: String, _ pid: Int32, _ size: CGSize, least: CGSize) -> WindowID {
      h.system.open(app: app, pid: pid, frame: CGRect(origin: CGPoint(x: 300, y: 200), size: size), minimumSize: least)
    }
    let preview = open("Preview", 1000, CGSize(width: 700, height: 557), least: CGSize(width: 702, height: 419))
    let xcode = open("Xcode", 1001, CGSize(width: 1370, height: 685), least: CGSize(width: 1188, height: 685))
    let safari = open("Safari", 1002, CGSize(width: 1000, height: 700), least: CGSize(width: 574, height: 240))
    let pages = h.system.open(app: "Pages", pid: 1003)
    h.start()
    runOK(h, "dock \(preview.rawValue) left")
    runOK(h, "dock \(xcode.rawValue) beside \(preview.rawValue) top")
    runOK(h, "dock \(safari.rawValue) beside \(preview.rawValue) top")
    runOK(h, "dock \(pages.rawValue) beside \(preview.rawValue) right")
    h.overlays.dragSeam(h.overlays.seams[h.display]![3], by: -200)
    runOK(h, "rule add com.example.music dock beside com.example.safari bottom")
    h.scheduler.advance(by: 1)
    h.system.userFocus(preview)
    h.scheduler.advance(by: 1)
    let music = open("Music", 1004, CGSize(width: 853, height: 480), least: CGSize(width: 680, height: 480))
    #expect(h.layout!.windowFrames.keys.sorted() == [music], "the story needs the view to go to it: \(h.ascii())")
    h.system.close(music)
    h.scheduler.advance(by: 1)
    #expect(h.layout!.windowFrames.count == 3, "\(h.ascii())")
    expectSound(h)
  }

  /// Safari beside a tab group of Notes and Mail. Notes, the tab in front, goes away, so Mail is in front when it comes back.
  private func aTabThatWentAway() -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "layout Safari | [Notes Mail]")
    h.system.userFocus(notes)
    h.scheduler.advance(by: 1)
    h.system.setMinimized(notes, true)
    h.scheduler.advance(by: 1)
    return (h, safari, notes, mail)
  }

  /// On paper a tab that is not in front has no place, in any view. It needs no other view: it needs to be in front.
  @Test func aTabComesBackToTheFrontOfItsGroupAndTheViewStays() {
    let (h, safari, notes, _) = aTabThatWentAway()
    let camera = h.workspace.camera
    h.system.setMinimized(notes, false)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == camera && h.system.focused == notes)
    #expect(h.layout!.windowFrames[notes] != nil && h.layout!.windowFrames[safari] != nil, "\(h.ascii())")
    expectSound(h)
  }

  /// Where it shows in the view there is, the view stays.
  @Test func aWindowThatHasRoomComesBackToItsSlot() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right"])
    let (camera, slot) = (h.workspace.camera, h.frame(w[1])!)
    h.system.setMinimized(w[1], true)
    h.scheduler.advance(by: 1)
    let roads = Roads(h) { h.system.setMinimized(w[1], false) }
    roads.expectOneRoadEach()
    #expect(h.workspace.camera == camera && h.frame(w[1]) == slot)
    expectSound(h)
  }

  /// Without the keyboard it is a tile again, and the view stays.
  @Test func withoutTheKeyboardTheViewStays() {
    let (h, wide, music) = aTileAndItsNeighbour()
    let camera = h.workspace.camera
    h.system.echoes.keyboard = false
    h.system.setMinimized(wide, true)
    h.scheduler.advance(by: 1)
    let roads = Roads(h) { h.system.setMinimized(wide, false) }
    roads.expectOneRoadEach()
    #expect(h.workspace.camera == camera && h.layout!.windowFrames[wide] == nil && h.layout!.windowFrames[music] != nil)
    expectSound(h)
  }

  /// A held view does not follow, and is laid out all the same.
  @Test func underAHeldViewTheDisplayIsStillLaidOut() {
    let (h, wide, music) = aTileAndItsNeighbour()
    h.system.setMinimized(wide, true)
    h.scheduler.advance(by: 1)
    runOK(h, "hold")
    let camera = h.workspace.camera
    let roads = Roads(h) { h.system.setMinimized(wide, false) }
    roads.expectOneRoadEach()
    #expect(h.workspace.camera == camera, "a held view does not move")
    #expect(h.staleLayouts().isEmpty, "\(h.staleLayouts())")
    #expect(h.system.focused == music, "and the keyboard goes back to the window in view that had it")
  }

  // MARK: Where the view may stay after all, everything is as it was: laid out first, looked at afterwards, once

  /// Plays a script of the walks and hands back the world it leaves.
  private func world(after script: String) -> ChaosRunner {
    let runner = ChaosRunner()
    for action in ChaosAction.script(script) {
      _ = runner.step(action)
      #expect(runner.refusals.isEmpty, "\(action.text): \(runner.refusals)")
    }
    return runner
  }

  /// Its app would not let it be that small, more than ten minutes ago. On paper it is a tile. The layout asks such a window again, it
  /// fits by now, and the view has no reason to go anywhere.
  @Test func aTileByAnOldRecordIsAskedAgainAndTheViewStays() {
    let h = Harness()
    let pages = h.system.open(app: "Pages", pid: 1010)
    let notes = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 700, height: 500), minimumSize: CGSize(width: 600, height: 300))
    _ = h.system.open(app: "Preview", pid: 1007, frame: CGRect(x: 300, y: 200, width: 700, height: 557), minimumSize: CGSize(width: 702, height: 419))
    let safari = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 300, y: 200, width: 1000, height: 700), minimumSize: CGSize(width: 574, height: 240))
    h.start()
    // A tile by its record alone: where room is made, the window with the keyboard gets it at a neighbour's cost and is never the tile.
    runOK(h, "set makeRoom false")
    runOK(h, "dock \(pages.rawValue) top")
    runOK(h, "dock \(notes.rawValue) beside \(pages.rawValue) left")
    runOK(h, "dock \(safari.rawValue) left")
    #expect(h.layout!.windowFrames[notes] == nil, "the story needs a tile: \(h.ascii())")
    h.system.setMinimized(notes, true)
    h.system.setMinimumSize(notes, .zero)
    h.scheduler.advance(by: 700)
    let camera = h.workspace.camera
    h.system.setMinimized(notes, false)
    h.scheduler.runPending()
    #expect(h.workspace.camera == camera)
    #expect(Set(h.layout!.windowFrames.keys) == [pages, notes, safari], "\(h.ascii())")
  }

  /// The window with the keyboard goes into the Dock and another comes out of it in the same breath. Whom the keyboard is handed to is
  /// judged by what is on screen once that has been laid out: judged earlier, it went to a window that then left, and the view chased it.
  @Test func afterALossNobodyIsChased() {
    expectOneLayoutAtTheEnd(
      of: """
        launch
        open 101 Preview pid 1007 at 300 200 700 557 min 702 419
        open 102 Xcode pid 1004 at 300 200 1188 800 min 1188 685
        open 103 Mail pid 1002 at 300 200 900 600 min 760 400
        open 104 Music pid 1006 at 300 200 853 480 min 680 480
        open 105 Mail pid 1002 at 300 200 800 500 min 760 400
        dock 101 top
        dock 102 beside 101 right
        dock 103 beside 101 bottom
        dock 105 right
        seam main 3 -120
        minimize 103
        focus 101
        advance 1
        focus 105
        advance 1
        minimize 105
        restore 103
        react
        """)
  }

  /// macOS picked it: the window that had the keyboard has just gone, and this one is its app's next. Nobody asked to see it.
  @Test func aWindowThatMacOSPickedMovesNoView() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    let second = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "dock \(safari.rawValue) left")
    runOK(h, "dock \(notes.rawValue) right")
    runOK(h, "dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    runOK(h, "dock \(second.rawValue) beside \(safari.rawValue) bottom")
    h.system.setMinimized(mail, true)
    runOK(h, "zoom \(second.rawValue)")
    h.system.setMinimized(second, true)
    let camera = h.workspace.camera
    h.system.setMinimized(mail, false)
    h.scheduler.runPending()
    #expect(h.workspace.camera == camera && h.layout!.windowFrames[mail] == nil, "\(h.ascii())")
    #expect(h.system.focused.map { !h.controller.parked.contains($0) } == true, "\(String(describing: h.system.focused))")
  }

  /// A hold sends the keyboard back three times before it gives up. One arrival is one round.
  @Test func underAHoldOneArrivalIsOneRound() {
    let round = "\nrestore 103\nadvance 0.3\nfocus-nothing\nminimize 103\nadvance 0.3"
    let runner = world(
      after: """
        open 101 Safari pid 1000 at 100 100 640 420
        open 102 Notes pid 1001 at 200 100 640 420
        open 103 Mail pid 1002 at 300 100 640 420
        launch
        dock 101 left
        dock 102 right
        dock 103 beside 102 bottom
        focus 101
        minimize 103
        advance 1
        zoom 101
        advance 1
        focus-nothing
        hold
        advance 1
        """ + round + round + "\nrestore 103\nadvance 0.3\nadvance 1")
    #expect(runner.system.focused != WindowID(103), "sent back the third time too, not left out of view with the keyboard")
  }

  /// A window its person floated lies where they left it. Whether the Desktop "comes into view", and gathers what floats, is judged by
  /// what the display would have shown with the app back, not by what it showed while the app was hidden.
  @Test func aFloatingWindowIsLeftWhereItLies() {
    let before = """
      launch
      open 101 Mail pid 1002 at 300 200 800 500 min 760 400
      open 102 Xcode pid 1004 at 300 200 1188 800 min 1188 685
      open 103 Xcode pid 1004 at 300 200 1370 685 min 1188 685
      open 104 Mail pid 1002 at 300 200 900 600 min 760 400
      dock 101 left
      dock 102 beside 101 right
      dock 103 beside 101 left
      dock 104 bottom
      focus 102
      hide 1002
      toggle-float 102
      """
    let lay = world(after: before).system.windows[WindowID(102)]!.snapshot.frame
    let after = world(after: before + "\nfocus 104\nshow 1002\nreact")
    #expect(after.system.windows[WindowID(102)]!.snapshot.frame == lay)
  }

  /// `summon` waiting for some other app has nothing to do with this window.
  @Test func summonWaitingForAnotherAppChangesNothing() {
    let (h, wide, music) = aTileAndItsNeighbour()
    h.system.setMinimized(wide, true)
    h.scheduler.advance(by: 1)
    _ = h.run("summon Calendar")
    let roads = Roads(h) { h.system.setMinimized(wide, false) }
    roads.expectOneRoadEach()
    #expect(roads.roads[music].map(FakeWindowSystem.changesOfPlace) == 1, "\(roads.roads[music]?.map(\.brief) ?? [])")
  }

  /// As the walks found it.
  @Test(arguments: [
    """
    displays main:0,0,1440,900:25,0,0,70* windows-never
    open 102 Xcode pid 1004 at 0 52 1370 685 min 1188 685
    open 103 Music pid 1006 at 336 214 853 480 min 680 480
    launch
    key down arrange
    key down toggle-float
    key down toggle-float
    open 104 Xcode pid 1004 at 39 48 1188 800 min 1188 685
    key down dock right
    minimize 104
    restore 104
    """,
    """
    displays side:0,0,2560,1440:25,0,0,0* windows-never
    open 102 Xcode pid 1004 at 704 153 1404 800 min 1188 685
    launch
    key down focus up
    key down dock right
    open 106 Notes pid 1001 at 1583 609 738 504 min 709 300
    key down toggle-float
    seam side 1 191
    minimize 106
    advance 1
    restore 106
    """,
    // A tile before it went and a tile when it is back: the layout for a return starts from the gaps that stood, where no room is made
    // (Controller+ThereAndBack.swift). The look on paper has to begin as the layout does, or it sees room that will not be made.
    """
    displays main:-1280,-150,1280,800:25,0,0,0 side:0,0,1920,1080:25,86,0,0* windows-never
    open 101 Preview pid 1007 at -760 77 723 455 min 723 400 max 723 2000
    launch
    open 102 Terminal pid 1003 at -1158 170 947 464 min 177 60
    advance 0.3
    key down arrange
    open 103 Mail pid 1002 at -1280 -125 1280 775 min 760 400
    focus 101
    edge 101 -714 -113 435 751
    key down undo
    grab 102
    carry 349 709
    release
    grab 103
    carry -578 263
    advance 0.3
    release
    minimize 103
    advance 1
    restore 103
    """,
    // With `floatingWindowsMakeWay` on, which ships off: a floating window was pushed aside for the one layout and sent out of view by the
    // other. It stood among the known failures until there was one layout.
    """
    settings {"floatingWindowsMakeWay":true}
    launch
    displays main:0,0,2560,1440:25,0,86,0* side:2560,-170,1280,800:0,0,0,0 windows-never
    open 101 Music pid 1006 at 1518 281 353 294
    grab 101
    carry 2724 -15
    release
    double-click 101
    behave 101 frozen
    undo
    space 101 off
    space 101 on
    flush
    minimize 101
    via shortcut layout Music
    open 107 Notes pid 1001 at 2676 12 380 315 min 255 117 max 255 968 title Inbox
    restore 101
    """,
  ]) func theWalksOwnScripts(_ script: String) { expectOneLayoutAtTheEnd(of: script) }
}

/// A window that is in the Dock, or hidden with its app, is fetched by name: Go to…, `reveal`, a row of the menu. On a Mac the report that
/// it is back comes a moment after it was asked. The view waits for the window: what is on screen stays while macOS flies it
/// out, and at the report there is one layout, for the view that shows it. (The view used to go at once, to the place of a window
/// that was not there yet: its neighbour filled the screen for the length of the flight, and was sent away again.)
@Suite @MainActor struct TheViewWaitsForTheWindowTests {
  enum Away: CaseIterable { case minimized, hidden }

  /// Safari on the left, Notes above Mail on the right. Mail goes away, and the view is framed on Safari.
  private func framedElsewhere(_ away: Away) -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "dock \(safari.rawValue) left")
    runOK(h, "dock \(notes.rawValue) right")
    runOK(h, "dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.system.userFocus(safari)
    switch away {
    case .minimized: h.system.setMinimized(mail, true)
    case .hidden: h.system.setHidden(pid: 1002, true)
    }
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(safari.rawValue)")
    h.scheduler.advance(by: 1)
    return (h, safari, notes, mail)
  }

  private func expectMailAlone(_ h: Harness, _ mail: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(h.layout!.windowFrames.keys.sorted() == [mail], "\(h.layout!.windowFrames)", sourceLocation: sourceLocation)
    #expect(h.system.focused == mail, sourceLocation: sourceLocation)
    expectSound(h, sourceLocation: sourceLocation)
  }

  @Test(arguments: Away.allCases) func whatIsOnScreenStaysUntilItIsBack(_ away: Away) {
    let (h, safari, notes, mail) = framedElsewhere(away)
    let camera = h.workspace.camera
    h.system.restoresLate = true
    let flight = Roads(h, atOnce: true) { runOK(h, "reveal \(mail.rawValue)") }
    #expect(flight.roads.isEmpty, "nothing moves while it is on its way: \(flight.roads)")
    #expect(h.workspace.camera == camera && h.system.isVisible(safari))
    let landing = Roads(h) {
      h.system.finishRestoring()
      h.system.reportFocus()
    }
    landing.expectOneRoadEach()
    #expect(landing.roads[notes] == nil, "nobody asked for it: \(landing.roads[notes]?.map(\.brief) ?? [])")
    expectMailAlone(h, mail)
  }

  /// The stand-ins' own order: the report comes while the command is still at work.
  @Test(arguments: Away.allCases) func theReportMayComeAtOnce(_ away: Away) {
    let (h, _, notes, mail) = framedElsewhere(away)
    let roads = Roads(h) { runOK(h, "reveal \(mail.rawValue)") }
    roads.expectOneRoadEach()
    #expect(roads.roads[mail].map(FakeWindowSystem.changesOfPlace) == 1, "\(roads.roads[mail]?.map(\.brief) ?? [])")
    #expect(roads.roads[notes] == nil, "nobody asked for it: \(roads.roads[notes]?.map(\.brief) ?? [])")
    expectMailAlone(h, mail)
  }

  /// It was asked for by name, so it comes into view whether or not it gets the keyboard: macOS does not always give it.
  @Test(arguments: Away.allCases) func itNeedNotHaveTheKeyboard(_ away: Away) {
    let (h, safari, _, mail) = framedElsewhere(away)
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    // Nobody reports the keyboard anywhere.
    h.system.finishRestoring()
    h.scheduler.advance(by: 0)
    #expect(h.layout!.windowFrames[mail] != nil && h.layout!.windowFrames[safari] == nil, "\(h.ascii())")
  }

  /// Whoever turns to another app meanwhile keeps what they turned to: a click, ⌘Tab. The window lands where it belongs, out of view.
  @Test(arguments: Away.allCases, [true, false]) func whoeverTurnsElsewhereMeanwhileKeepsIt(_ away: Away, itLands: Bool) {
    let (h, safari, _, mail) = framedElsewhere(away)
    let camera = h.workspace.camera
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.1)
    h.system.userFocus(safari)
    h.scheduler.advance(by: 0.1)
    if itLands { h.system.finishRestoring() }
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera && h.system.focused == safari && h.system.isVisible(safari), "\(h.ascii())")
  }

  /// A view that was asked for by name has not "followed the keyboard": nothing takes it back when the window that had the keyboard goes.
  @Test func whatWasAskedForIsNotTakenBack() {
    let (h, _, _, mail) = framedElsewhere(.hidden)
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.2)
    h.system.setHidden(pid: 1000, true)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: mail) && h.layout!.windowFrames[mail] != nil, "\(h.ascii())")
  }

  /// The last one asked for is the one that is shown.
  @Test func ofTwoThatWereAskedBackTheLastIsShown() {
    let (h, _, notes, mail) = framedElsewhere(.minimized)
    runOK(h, "show-all")
    h.system.setMinimized(notes, true)
    h.scheduler.advance(by: 1)
    runOK(h, "zoom 101")
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.1)
    runOK(h, "reveal \(notes.rawValue)")
    h.system.finishRestoring()
    h.system.reportFocus()
    h.scheduler.advance(by: 2)
    #expect(h.layout!.windowFrames[notes] != nil && h.system.focused == notes, "\(h.ascii())")
    expectSound(h)
  }

  /// Nothing is left waiting when Arbor stops.
  @Test(arguments: ["pause", "quit"]) func nothingWaitsOnceArborStops(_ stop: String) {
    let (h, _, _, mail) = framedElsewhere(.minimized)
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    #expect(h.scheduler.pendingKeys.contains("focus-asked-back"))
    // As the app does at Quit.
    if stop == "quit" { h.controller.shutdown() } else { runOK(h, stop) }
    #expect(!h.scheduler.pendingKeys.contains("focus-asked-back"))
  }

  /// The answer says what is so.
  @Test func theAnswerDoesNotClaimWhatHasNotHappened() {
    let (h, _, _, mail) = framedElsewhere(.minimized)
    h.system.restoresLate = true
    #expect(runOK(h, "reveal \(mail.rawValue)").message == "\(mail) is on its way back, and comes into view when it is there")
    h.system.finishRestoring()
    h.system.restoresLate = false
    h.scheduler.advance(by: 1)
    #expect(runOK(h, "reveal \(mail.rawValue)").message == "\(mail) is in view and focused")
  }

  /// It goes by what was so when the window was asked for, not by how soon the report came: the same words in both orders, and in a replay.
  @Test(arguments: Away.allCases) func theAnswerIsTheSameHoweverSoonTheReportComes(_ away: Away) {
    let (h, _, _, mail) = framedElsewhere(away)
    #expect(runOK(h, "reveal \(mail.rawValue)").message == "\(mail) is on its way back, and comes into view when it is there")
    h.scheduler.advance(by: 1)
    expectMailAlone(h, mail)
  }

  /// A tab that is not in front, fetched by name, in a Mac's order.
  @Test func aTabFetchedByName() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    _ = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "layout Safari | [Notes Mail]")
    h.system.userFocus(notes)
    h.scheduler.advance(by: 1)
    h.system.setMinimized(notes, true)
    h.scheduler.advance(by: 1)
    h.system.restoresLate = true
    runOK(h, "reveal \(notes.rawValue)")
    h.system.reportFocus()
    h.system.finishRestoring()
    h.system.reportFocus()
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(notes) && h.system.focused == notes && h.system.isVisible(safari), "\(h.ascii())")
    expectSound(h)
  }

  /// The same with the view elsewhere: it comes to the front of its group before the layout and not after it, so it goes straight into
  /// view. Laid out first as a tab behind another, it went to the corner and was fetched.
  @Test func aTabFetchedByNameWhileTheViewIsElsewhereMovesOnce() {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "layout Safari | [Notes Mail]")
    h.system.userFocus(notes)
    h.scheduler.advance(by: 1)
    h.system.setMinimized(notes, true)
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(safari.rawValue)")
    h.scheduler.advance(by: 1)
    h.system.restoresLate = true
    let roads = Roads(h) {
      runOK(h, "reveal \(notes.rawValue)")
      h.scheduler.advance(by: 0.05)
      h.system.finishRestoring()
    }
    roads.expectOneRoadEach()
    #expect(roads.roads[notes].map(FakeWindowSystem.changesOfPlace) == 1, "\(roads.roads[notes]?.map(\.brief) ?? [])")
    #expect(roads.roads[mail] == nil, "nobody asked for it: \(roads.roads[mail]?.map(\.brief) ?? [])")
    #expect(h.system.isVisible(notes) && h.system.focused == notes && !h.system.isVisible(mail), "\(h.ascii())")
    expectSound(h)
  }

  /// And it comes to the front after the gaps that stood have come back, which are known by the arrangement, of which the tab in front is a
  /// part. Safari beside three tabs, room made for Notes; Mail's app is hidden and Mail fetched by name: Safari is as wide as it was.
  /// With a column for the Desktop: it has lent so much that it is a tile, and what it is owed is what moves the gaps meanwhile.
  @Test func aTabFetchedByNameLeavesTheGapsAsTheyStood() {
    let h = Harness(settings: .withDesktopColumn)
    h.start()
    runOK(h, "set tabsEnabled true")
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001, minimumSize: CGSize(width: 700, height: 500))
    let mail = h.system.open(app: "Mail", pid: 1002)
    _ = h.system.open(app: "Music", pid: 1003, minimumSize: CGSize(width: 600, height: 300))
    runOK(h, "layout Safari | [Notes Mail Music]")
    h.scheduler.advance(by: 2)
    runOK(h, "focus \(notes.rawValue)")
    h.scheduler.advance(by: 1)
    runOK(h, "home")
    h.scheduler.advance(by: 2)
    let stood = h.frame(safari)!
    h.system.setHidden(pid: 1002, true)
    h.scheduler.advance(by: 2)
    #expect(h.frame(safari) != stood, "the story needs the gaps to move while it is away: \(h.ascii())")
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 3)
    #expect(h.system.isVisible(mail) && h.system.focused == mail, "\(h.ascii())")
    #expect(h.frame(safari) == stood, "\(h.frame(safari)!.brief), it was \(stood.brief)")
    expectSound(h)
  }

  /// Known, and let pass by the product owner on 2026-10-15: under `hold still` the view waits like any other, but a hold's bookkeeping is not
  /// pre-empted, so the display is laid out first and the window lands by way of the corner. One jolt, in an option, in place of three
  /// pictures and a keyboard astray. **Whoever mends it deletes the `withKnownIssue`**, which fails once nothing jolts.
  @Test func underHoldStillItStillLandsByWayOfTheCorner() {
    let (h, safari, _, mail) = framedElsewhere(.minimized)
    runOK(h, "hold still")
    h.system.restoresLate = true
    let mark = h.system.moveLog.count
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.05)
    #expect(h.system.isVisible(safari), "what is on screen stays: \(h.ascii())")
    h.system.finishRestoring()
    h.scheduler.advance(by: 2)
    expectMailAlone(h, mail)
    withKnownIssue("rule 3: it is seen to move twice") { #expect(h.system.jolts(since: mark) == []) }
  }

  /// An app that hangs reports nothing. The view goes all the same, as it used to go at once.
  @Test(arguments: Away.allCases) func withNoReportTheViewGoesAfterAMoment(_ away: Away) {
    let (h, _, _, mail) = framedElsewhere(away)
    let camera = h.workspace.camera
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    #expect(h.workspace.camera == camera)
    h.scheduler.advance(by: Controller.timeToLand + 0.01)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: mail))
    h.system.finishRestoring()
    h.system.reportFocus()
    h.scheduler.runPending()
    expectMailAlone(h, mail)
  }

  /// Whoever moves the view meanwhile has said where it goes: at the report, and when none comes.
  @Test(arguments: [true, false]) func aViewMovedMeanwhileIsNotTakenAway(itLands: Bool) {
    let (h, _, notes, mail) = framedElsewhere(.minimized)
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.1)
    runOK(h, "zoom \(notes.rawValue)")
    let camera = h.workspace.camera
    h.scheduler.advance(by: 0.1)
    if itLands { h.system.finishRestoring() }
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera && h.system.isVisible(notes), "\(h.ascii())")
  }

  /// `zoom` also hands the keyboard to another app, which ends the wait by itself. `out` hands it to nobody, and the keyboard is slow to
  /// reach the window that was asked for: there only the view tells. Safari above Notes on the left, Mail on the right; from
  /// Safari `out` leads to the two on the left, where Mail does not show.
  @Test(arguments: [true, false]) func aViewMovedMeanwhileWithoutTheKeyboardIsNotTakenAwayEither(itLands: Bool) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1000)
    let notes = h.system.open(app: "Notes", pid: 1001)
    let mail = h.system.open(app: "Mail", pid: 1002)
    h.start()
    runOK(h, "dock \(safari.rawValue) left")
    runOK(h, "dock \(notes.rawValue) beside \(safari.rawValue) bottom")
    runOK(h, "dock \(mail.rawValue) right")
    h.system.userFocus(safari)
    h.system.setHidden(pid: 1002, true)
    h.scheduler.advance(by: 1)
    runOK(h, "zoom \(safari.rawValue)")
    h.scheduler.advance(by: 1)
    (h.system.restoresLate, h.system.focusIsSlow) = (true, true)
    runOK(h, "reveal \(mail.rawValue)")
    h.scheduler.advance(by: 0.1)
    runOK(h, "out")
    let camera = h.workspace.camera
    #expect(h.layout!.windowFrames.keys.sorted() == [safari, notes], "the story needs a view without Mail's place: \(h.ascii())")
    h.scheduler.advance(by: 0.1)
    if itLands { h.system.finishRestoring() }
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera && h.system.isVisible(safari) && h.system.isVisible(notes), "\(h.ascii())")
  }

  /// It closes on its way.
  @Test func closedOnItsWay() {
    let (h, safari, _, mail) = framedElsewhere(.minimized)
    let camera = h.workspace.camera
    h.system.restoresLate = true
    runOK(h, "reveal \(mail.rawValue)")
    h.system.close(mail)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera && h.system.isVisible(safari) && !h.scheduler.pendingKeys.contains("focus-asked-back"))
    expectSound(h)
  }

  /// A window that is there is shown at once, as ever.
  @Test func aWindowThatIsThereIsShownAtOnce() {
    let (h, w) = tilingScenario(["A", "B"], ["dock $0 left", "dock $1 right", "zoom $0"])
    h.system.restoresLate = true
    runOK(h, "reveal \(w[1].rawValue)")
    #expect(h.layout!.windowFrames[w[1]] != nil && h.system.focused == w[1])
    expectSound(h)
  }
}
