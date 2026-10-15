import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A window that leaves the arrangement has its own earlier size, also when it leaves by Keep in View, and a trip to a smaller
/// display and back costs it nothing. Random walks at ordinary sizes found the three scripts; each asks the window system what it
/// saw, not the controller what it believes.
@Suite @MainActor struct ItsOwnSizeTests {
  /// Plays a script of the chaos lab, and says how often Arbor moved `window` in its last step.
  private func play(_ script: String, watching window: WindowID) -> (world: ChaosRunner, movesInTheLastStep: Int) {
    let (world, requests) = playCountingRequests(script, watching: window)
    return (world, requests.filter { $0.before != $0.after }.count)
  }

  /// The same, with everything Arbor asked of `window` in the last step, whether it changed anything or not.
  private func playCountingRequests(_ script: String, watching window: WindowID) -> (world: ChaosRunner, requests: [FakeWindowSystem.Move]) {
    let runner = ChaosRunner()
    var mark = 0
    for action in ChaosAction.script(script) {
      mark = runner.system.moveLog.count
      let violations = runner.step(action).filter { !ChaosRunner.knownRules.contains($0.rule) }
      #expect(violations.isEmpty, "\(action.text): \(violations)")
    }
    return (runner, runner.system.moveLog[mark...].filter { $0.window == window })
  }

  private func go(on world: ChaosRunner, _ script: String) {
    for action in ChaosAction.script(script) { _ = world.step(action) }
  }

  private func frame(_ window: WindowID, in world: ChaosRunner) throws -> CGRect {
    try #require(world.system.windows[window]?.snapshot.frame)
  }

  // MARK: Keep in View on a docked window

  static let aLargeBrowserDockedAndPinned = """
    open 107 Safari pid 1000 at 209 87 1176 832 min 574 240
    focus 107
    launch
    key down dock right
    via menu toggle-pin
    """

  @Test func pinnedOutOfItsSlotAWindowHasItsOwnSizeHoweverLarge() throws {
    let safari = WindowID(107)
    let (world, moves) = play(Self.aLargeBrowserDockedAndPinned, watching: safari)
    #expect(world.controller.isPinned(safari))
    #expect(try frame(safari, in: world).size == CGSize(width: 1176, height: 832))
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(try frame(safari, in: world)))
    #expect(moves == 1, "to where it ends up, at once")
  }

  @Test(arguments: ["way-back float-all", "way-back quit", "do pause", "do home", "do show-all"])
  func noWayHomeFindsAPinnedWindowAtAnotherSizeThanItsOwn(way: String) throws {
    let safari = WindowID(107)
    let (world, _) = play(Self.aLargeBrowserDockedAndPinned, watching: safari)
    let pinned = try frame(safari, in: world)
    go(on: world, way)
    #expect(try frame(safari, in: world) == pinned, "a pinned window is left exactly where it is")
    #expect(pinned.size == CGSize(width: 1176, height: 832))
  }

  /// The app would not be as small as half the display, grew from the corner it was given, and hung 108 points over the right edge.
  /// (It is docked by a drag to the top edge, which is Arbor's only with macOS's tiling off.)
  static let anEditorThatWillNotBeSmallDockedAndPinned = """
    mac-tiling off
    open 101 Xcode pid 1004 at 0 41 1280 685 min 1188 685
    launch
    grab 101
    carry 714 28
    release
    tile main 1
    via menu toggle-pin
    """

  @Test func pinnedOutOfItsSlotAWindowIsWhollyInView() throws {
    let xcode = WindowID(101)
    let (world, moves) = play(Self.anEditorThatWillNotBeSmallDockedAndPinned, watching: xcode)
    #expect(world.controller.isPinned(xcode))
    #expect(try frame(xcode, in: world).size == CGSize(width: 1280, height: 685))
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(try frame(xcode, in: world)))
    #expect(moves == 1, "to where it ends up, at once")
    go(on: world, "do home\nsettle")
    #expect(FakeWindowSystem.standardDisplay.visibleFrame.contains(try frame(xcode, in: world)))
  }

  /// Its app has come to insist on more than the window's own size since it was docked. That costs a second move, and no more.
  @Test func anAppThatMakesItLargerThanItsOwnSizeDoesNotLeaveItHangingOverAnEdge() throws {
    let h = Harness()
    let editor = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 700, y: 100, width: 700, height: 500))
    h.start()
    #expect(h.run("dock \(editor.rawValue) right").ok)
    h.system.setMinimumSize(editor, CGSize(width: 1188, height: 685))
    #expect(h.run("pin \(editor.rawValue)").ok)
    let frame = try #require(h.frame(editor))
    #expect(frame.size == CGSize(width: 1188, height: 685))
    #expect(h.visibleFrame.contains(frame))
    #expect(h.workspace.floating[editor] == frame, "where it is pinned is where it stays")
  }

  /// More than the display holds. What its app has just refused is not asked of it again.
  @Test func anAppThatInsistsOnMoreThanTheDisplayHoldsIsAskedOnce() throws {
    let xcode = WindowID(103)
    let (world, requests) = playCountingRequests(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 800
        key down dock left
        via menu move-to-display next
        via menu toggle-pin
        """, watching: xcode)
    #expect(world.controller.isPinned(xcode))
    #expect(requests.count == 1, "\(requests.map(\.requested))")
  }

  /// Its app is busy at the moment of the pin. It is still in its slot's shape, which is not what to remember as its own.
  @Test func pinnedWhileItsAppDoesNotAnswerItTakesItsOwnSizeWhenTheAppDoes() throws {
    let safari = WindowID(107)
    let (world, _) = play(
      """
      open 107 Safari pid 1000 at 209 87 900 600 min 574 240
      focus 107
      launch
      key down dock right
      hang 1000
      via menu toggle-pin
      wake 1000
      settle
      """, watching: safari)
    #expect(world.controller.isPinned(safari))
    #expect(try frame(safari, in: world).size == CGSize(width: 900, height: 600))
    go(on: world, "way-back float-all")
    #expect(try frame(safari, in: world).size == CGSize(width: 900, height: 600))
  }

  /// Docked for as long as Arbor has known it (a file from before sizes were remembered): it keeps its slot's size, as when it floats (F48).
  @Test func withNothingRememberedItKeepsItsSlotsSize() throws {
    let old = Harness()
    let a = old.system.open(app: "A", pid: 1001)
    let b = old.system.open(app: "B", pid: 1002)
    old.start()
    #expect(old.run("dock \(a.rawValue) left").ok && old.run("dock \(b.rawValue) right").ok)
    old.controller.saveNow()
    func stripped(_ value: Any) -> Any {
      if let list = value as? [Any] { return list.map(stripped) }
      guard var object = value as? [String: Any] else { return value }
      object["undockedFrames"] = nil
      return object.mapValues(stripped)
    }
    let saved = try JSONDecoder().decode(
      PersistedState.self,
      from: JSONSerialization.data(withJSONObject: stripped(JSONSerialization.jsonObject(with: JSONEncoder().encode(old.store.saved!)))))
    let h = Harness(saved: saved)
    for window in old.system.allWindows() {
      _ = h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(h.workspace.isDocked(a) && h.workspace.undockedFrames == nil)
    let slot = try #require(h.frame(a))
    #expect(h.run("pin \(a.rawValue)").ok)
    #expect(h.frame(a) == slot, "and does not move at all")
  }

  // MARK: Keep in View on a floating window

  /// Left hanging most of the way over the bottom edge by a hand, then squeezed by a Desktop that grew narrower. Pinned, it came into
  /// view at the squeezed size, which was written down as its own.
  @Test(arguments: [
    (
      WindowID(102), CGSize(width: 1080, height: 800),
      """
      displays side:0,0,2560,1440:25,0,70,0* windows-never
      launch
      open 102 Safari pid 1000 at 1395 239 1080 800 min 574 240
      grab 102
      carry 184 1176
      release
      open 104 Terminal pid 1003 at 239 542 930 469 min 177 60
      key down dock left
      seam side 0 280
      focus 102
      via menu toggle-pin
      """
    ),
    (
      WindowID(105), CGSize(width: 1164, height: 945),
      """
      displays main:0,0,1512,982:37,0,0,70* windows-never
      launch
      open 101 Finder pid 1005 at 226 535 957 384 min 501 300
      key down dock left
      open 105 Safari pid 1000 at 142 37 1164 945 min 574 240
      key down desktop
      grab 105
      carry 465 931
      release
      key down show-all
      via menu toggle-pin
      """
    ),
  ])
  func squeezedAndMostlyOutOfViewItComesIntoViewAtItsOwnSize(window: WindowID, own: CGSize, script: String) throws {
    let (world, moves) = play(script, watching: window)
    #expect(world.controller.isPinned(window))
    #expect(try frame(window, in: world).size == own)
    #expect(world.system.displayList[0].visibleFrame.contains(try frame(window, in: world)))
    #expect(moves == 1, "to where it ends up, at once")
    go(on: world, "way-back float-all")
    #expect(try frame(window, in: world).size == own)
  }

  // MARK: To a smaller display and back

  static let twoDisplays = "displays main:-1280,0,1280,800:25,0,0,0 side:0,0,3008,1692:25,0,70,0* windows-never\nlaunch\n"
  static let own = CGSize(width: 1188, height: 832)

  @Test func toTheSmallerDisplayAndBackAFloatingWindowHasItsOwnSize() throws {
    let xcode = WindowID(103)
    let (world, moves) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == Self.own)
    #expect(moves == 1)
    go(on: world, "way-back float-all")
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  @Test func toTheSmallerDisplayAndBackADockedWindowFloatsAtItsOwnSize() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        key down dock left
        via menu move-to-display next
        via menu move-to-display next
        way-back float-all
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  /// Docked on the way there, floated on the smaller display, and sent back floating.
  @Test func theWayBackNeedNotBeTheWayThere() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        key down dock left
        via menu move-to-display next
        via menu toggle-float
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  /// The size somebody gave it on the smaller display is its own from then on.
  @Test func resizedByHandOnTheSmallerDisplayItKeepsThatSize() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        edge 103 -1270 40 1200 700
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == CGSize(width: 1200, height: 700))
  }

  /// The roads a docked window takes to another display, each there and back.
  @Test(arguments: [
    // Trading places with a window of the other display, twice.
    """
    open 104 Notes pid 1001 at -1000 100 600 400
    focus 104
    key down dock left
    focus 103
    key down dock left
    do swap 103 104
    do swap 103 104
    """,
    // Docked beside a window of the other display, and sent back.
    """
    open 104 Notes pid 1001 at -1000 100 600 400
    focus 104
    key down dock left
    do dock 103 beside 104 right
    focus 103
    via menu move-to-display next
    """,
    // Carried to the smaller display's edge by hand and docked there, and sent back. The edge is Arbor's only with macOS's tiling off.
    """
    mac-tiling off
    grab 103
    carry -1278 400
    advance 1
    release
    focus 103
    via menu move-to-display next
    """,
    // Another tab of its window comes to the front on the smaller display: to its person the same window.
    """
    key down dock left
    via menu move-to-display next
    tab-open 105 in 103
    via menu move-to-display next
    """,
  ])
  func whicheverRoadADockedWindowTakesThereAndBackItFloatsAtItsOwnSize(road: String) throws {
    let xcode = WindowID(road.contains("tab-open 105") ? 105 : 103)
    let (world, _) = play(
      Self.twoDisplays + "open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685\n" + road + "\nsettle", watching: xcode)
    #expect(world.controller.workspaces[DisplayID("side")]?.isDocked(xcode) == true, "or the road led nowhere")
    go(on: world, "way-back float-all")
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  @Test func draggedOutOfItsSlotOnTheSmallerDisplayOntoTheLargerOneItHasItsOwnSize() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        key down dock left
        via menu move-to-display next
        grab 103
        carry 1500 600
        advance 1
        release
        settle
        """, watching: xcode)
    #expect(world.controller.workspaces[DisplayID("side")]?.isFloating(xcode) == true)
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  @Test(arguments: ["", "key down dock left\n"])
  func undoOfTheWayBackDoesNotCostItItsSize(docked: String) throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + "open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685\n" + docked + """
        via menu move-to-display next
        via menu move-to-display next
        key down undo
        via menu move-to-display next
        way-back float-all
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  /// Keep in View remembers what the app made of the frame, and this app will not be as low as the smaller display.
  @Test func pinnedOnTheSmallerDisplayByAnAppThatAnswersWithAnotherSizeItStillHasItsOwnToGoBackTo() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 800
        key down dock left
        via menu move-to-display next
        via menu toggle-pin
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == Self.own)
  }

  /// Made smaller by hand, and then by hand as large as the smaller display again, as macOS's zoom does.
  @Test func givenTheFittedSizeByAHandItKeepsIt() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        edge 103 -1234 25 1188 700
        edge 103 -1234 25 1188 775
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 775))
  }

  /// The same of a docked window, by hand during two pauses (`DockedAsFoundTests`).
  @Test func givenTheFittedSizeByAHandDuringAPauseADockedWindowKeepsIt() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        dock 103 left
        settle
        pause
        move 103 -1234 25 1188 700
        resume
        settle
        pause
        move 103 -1234 25 1188 775
        resume
        settle
        float 103
        settle
        via menu move-to-display next
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 775))
  }

  /// Carried back by hand it stays as it is: a floating window's frame is its person's. Later trips must not change that.
  /// The second way is a move that is only reported, as a tool's or macOS's own shortcut makes it.
  @Test(arguments: ["grab 103\ncarry 1500 600\nrelease", "move 103 900 500 1188 775"])
  func takenBackByAnybodyButArborItIsLeftAsItIsAlsoByLaterTrips(back: String) throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next

        """ + back + "\nsettle", watching: xcode)
    let left = try frame(xcode, in: world)
    #expect(left.size == CGSize(width: 1188, height: 775))
    #expect(world.controller.workspaces[DisplayID("side")]?.isFloating(xcode) == true)
    go(on: world, "via menu move-to-display next\nvia menu move-to-display next")
    #expect(try frame(xcode, in: world).size == left.size)
  }

  /// A size its person asks Arbor for on the smaller display is its own as well.
  @Test func madeSmallerByCommandOnTheSmallerDisplayItKeepsThatSize() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        do shrink 40
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 735), "its app keeps the width")
    go(on: world, "via menu move-to-display next")
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 735))
  }

  /// At home again, its person asks Arbor for the very size the smaller display had left of it. That is its own now.
  @Test func givenTheFittedSizeByCommandAtHomeItKeepsItThroughLaterTrips() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        via menu move-to-display next
        do shrink 57
        """, watching: xcode)
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 775), "its app keeps the width")
    go(on: world, "via menu move-to-display next\nvia menu move-to-display next")
    #expect(try frame(xcode, in: world).size == CGSize(width: 1188, height: 775))
  }

  /// It goes during a pause, when Arbor does not listen: at the start that ends the pause it is not among the windows.
  @Test func goneDuringAPauseItLeavesNothingBehind() throws {
    let small = AReportAcrossABorderTests.display("main", CGRect(x: -1280, y: 0, width: 1280, height: 800))
    let large = AReportAcrossABorderTests.display("side", CGRect(x: 0, y: 0, width: 3008, height: 1692), isMain: true)
    let h = Harness(displays: [small, large])
    h.start()
    let xcode = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(origin: CGPoint(x: 1435, y: 753), size: Self.own))
    #expect(h.run("move-to-display next \(xcode.rawValue)").ok)
    #expect(h.frame(xcode)?.height == small.visibleFrame.height)
    #expect(h.run("pause").ok)
    h.system.setListed(xcode, false)
    #expect(h.run("resume").ok)
    #expect(h.controller.invariantViolations().filter { $0.rule.hasPrefix("leak") }.isEmpty)
  }

  /// A place kept for a window that is not there yet has a number and no window: nothing is remembered about it that could outlive it.
  @Test func aPlaceThatWaitsForItsWindowLeavesNothingBehind() throws {
    let (world, _) = play(
      Self.twoDisplays + """
        open 101 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        open 102 Notes pid 1001 at 200 100 1400 1000
        open 103 Mail pid 1002 at -1000 100 600 400
        focus 101
        do layout [Xcode Notes] | desktop
        focus 103
        key down dock left
        save
        crash
        unlist 102
        launch
        do swap 101 103
        """, watching: WindowID(102))
    #expect(world.controller.workspaces[DisplayID("main")]?.isDocked(WindowID(102)) == true, "the place went along with its neighbour")
    #expect(world.controller.invariantViolations().filter { $0.rule.hasPrefix("leak") }.isEmpty)
  }

  /// With windows making way during a drag, Arbor tries what a release would do at every target the pointer passes. A trial is no
  /// trip, neither to the display it came from nor to a third that is smaller still.
  @Test(arguments: [CGPoint(x: 4, y: 800), CGPoint(x: 4028, y: 400)])
  func heldOverAnotherDisplayAndBroughtBackItHasNotBeenThere(edge: CGPoint) throws {
    var settings = Settings()
    settings.reflowWhileDragging = true
    let small = AReportAcrossABorderTests.display("main", CGRect(x: -1280, y: 0, width: 1280, height: 800))
    let large = AReportAcrossABorderTests.display("side", CGRect(x: 0, y: 0, width: 3008, height: 1692), isMain: true)
    let smallest = AReportAcrossABorderTests.display("third", CGRect(x: 3008, y: 0, width: 1024, height: 768))
    let h = Harness(displays: [small, large, smallest], settings: settings)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.start()
    let xcode = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(origin: CGPoint(x: 1435, y: 753), size: Self.own))
    #expect(h.run("move-to-display 1 \(xcode.rawValue)").ok)
    let fitted = try #require(h.frame(xcode))
    #expect(fitted.height == small.visibleFrame.height && small.visibleFrame.contains(fitted))
    // At the other display's edge long enough for a preview, and back to the middle of the small one, far from its edges.
    h.system.beginDrag(xcode)
    h.system.moveDrag(to: edge, holding: 1)
    #expect(h.overlays.previewHistory.contains { $0 != nil }, "or nothing was tried")
    h.system.moveDrag(to: small.frame.center, holding: 1)
    h.system.endDrag()
    h.scheduler.advance(by: 2)
    #expect(h.frame(xcode)?.size == fitted.size && h.controller.workspaces[small.id]?.isFloating(xcode) == true)
    #expect(h.run("move-to-display 2 \(xcode.rawValue)").ok)
    #expect(h.frame(xcode)?.size == Self.own)
  }

  @Test func whatIsRememberedOfTheTripGoesWithTheWindow() throws {
    let xcode = WindowID(103)
    let (world, _) = play(
      Self.twoDisplays + """
        open 103 Xcode pid 1004 at 1435 753 1188 832 min 1188 685
        via menu move-to-display next
        close 103
        """, watching: xcode)
    #expect(world.controller.invariantViolations().isEmpty)
  }
}
