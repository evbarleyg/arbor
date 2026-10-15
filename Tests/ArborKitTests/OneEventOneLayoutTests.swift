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
  init(_ h: Harness, during body: () -> Void) {
    display = h.system.displayList[0].frame
    let mark = h.system.moveLog.count
    body()
    for _ in 0..<3 { h.scheduler.runPending() }
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
  "flashed-into-view", "flashed-out-of-view", "moved-over-and-over", "sized-there-and-back",
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

  /// Seen on a hosted Mac first: one press, six frames, one of them out of view. A display of 1024 by 768 points.
  @Test func onASmallDisplay() {
    let small = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 737), isMain: true)
    let h = Harness(displays: [small])
    let a = h.system.open(app: "A", pid: 1001)
    let b = h.system.open(app: "B", pid: 1002, minimumSize: CGSize(width: 300, height: 200))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(b.rawValue) right")
    h.system.userFocus(b)
    h.scheduler.runPending()
    let roads = Roads(h) { runOK(h, "shrink") }
    roads.expectOneRoadEach()
    #expect((300...302).contains(h.frame(b)!.width) && h.frame(b)!.maxX == h.layout!.windowFrames[b]!.maxX, "\(h.frame(b)!.brief)")
    expectSound(h)
  }
}
