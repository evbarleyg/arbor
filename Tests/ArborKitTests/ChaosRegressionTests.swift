import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Replays a chaos script and expects every invariant to hold after every step, but for the known failures.
@MainActor
private func expectEveryInvariantHolds(_ script: String, sourceLocation: SourceLocation = #_sourceLocation) {
  if let failure = ChaosRunner.replay(ChaosAction.script(script), excusing: ChaosRunner.knownRules) { Issue.record("\(failure)", sourceLocation: sourceLocation) }
}

/// Runs a script and hands back the world it leaves, for a closer look.
@MainActor
private func world(after script: String, sourceLocation: SourceLocation = #_sourceLocation) -> ChaosRunner {
  let runner = ChaosRunner()
  for action in ChaosAction.script(script) {
    let violations = runner.step(action).filter { !ChaosRunner.knownRules.contains($0.rule) }
    #expect(violations.isEmpty, "\(action.text): \(violations)", sourceLocation: sourceLocation)
  }
  return runner
}

private let a = WindowID(101)
private let b = WindowID(102)
private let c = WindowID(103)

/// Every bug the chaos test has found, as the smallest script that showed it
/// (collab/reports/2026-10-14-chaos.md tells the stories).
@Suite @MainActor struct ChaosRegressionTests {
  /// Two windows docked left and right of the Desktop on the standard display.
  static let twoDocked = """
    open 101 Safari pid 1000 at 100 100 600 400
    open 102 Notes pid 1001 at 300 200 600 400
    launch
    dock 101 left
    dock 102 right
    """

  // MARK: A view that followed the keyboard and was taken back

  /// Minimizing or closing the window with the keyboard hands the keyboard to its app's next window. macOS reports that
  /// first, the view follows, and the minimize takes the move back. Floating windows that lay over the view, which is not
  /// the Desktop's, went out of view with one of the two moves and nothing brought them back.
  @Test(arguments: ["minimize", "close"]) func oneFloatingWindowLeavingDoesNotTakeAnotherOutOfView(leave: String) {
    expectEveryInvariantHolds(Self.floatsOverAViewThatIsNotTheDesktops + "\nfocus 109\n\(leave) 109")
  }

  /// Preview is docked beside a hidden app's window, so the view is on a group that shows only Preview. Mail (104) and a
  /// window of Safari (109) float over it; Safari's other window (105) is docked and out of view.
  static let floatsOverAViewThatIsNotTheDesktops = """
    open 104 Mail pid 1002 at 371 506 948 407 min 948 407
    open 105 Safari pid 1000 at 1219 136 528 623
    launch
    open 108 Notes pid 1001 at -349 519 614 278 title Untitled
    layout Safari | Notes | Music
    hide 1001
    open 109 Safari pid 1000 at 608 356 514 532
    zoom-node 3
    open 110 Preview pid 1007 at 892 1716 732 402 min 374 256
    url arbor://dock/beside/108/bottom
    """

  /// The same with the report of the minimize or close later than the view waits for it within one app (`timeForAGoing`), and for an
  /// app that is hidden, whose next window is another app's. The camera moves in that step, so the lab's rule has nothing to say:
  /// the window is looked at.
  @Test(arguments: [
    (holder: 109, steps: "focus 105\nadvance 0.1\nminimize 109", stays: 104),
    (holder: 109, steps: "focus 105\nadvance 0.1\nclose 109", stays: 104),
    (holder: 104, steps: "focus 105\nhide 1002", stays: 109),
  ])
  func aViewThatDidFollowAndIsTakenBackLeavesTheFloatingWindowsWhereTheyWere(holder: Int, steps: String, stays: Int) {
    let start = Self.floatsOverAViewThatIsNotTheDesktops + "\nfocus \(holder)"
    let before = world(after: start)
    let followed = world(after: start + "\nfocus 105\nadvance 0.1")
    let after = world(after: start + "\n" + steps + "\nsettle")
    let window = WindowID(UInt32(stays))
    let main = before.controller.displays[0].id
    #expect(!before.controller.parked.contains(window))
    #expect(followed.controller.workspaces[main]?.camera != before.controller.workspaces[main]?.camera, "the view did follow")
    #expect(after.controller.workspaces[main]?.camera == before.controller.workspaces[main]?.camera, "the move was taken back")
    #expect(!after.controller.parked.contains(window))
    #expect(after.harness.frame(window) == before.harness.frame(window))
  }

  @Test(arguments: ["minimize", "close"]) func norAfterADisplayWentAndItsWindowArrived(leave: String) {
    expectEveryInvariantHolds(
      """
      launch
      open 101 Xcode pid 1004 at 86 925 888 383 min 888 383 title Übersicht
      open 104 Terminal pid 1003 at 979 1022 822 348 min 822 348
      displays main:0,0,2560,1440:25,0,0,0* side:-800,-77,800,600:0,68,0,0 windows-late
      dock left
      open 109 Finder pid 1005 at -730 333 686 654 min 686 365
      in
      displays main:0,0,1920,1080:25,0,0,0* windows-first
      open 114 Xcode pid 1004 at -1740 915 2965 992 max 356 912
      \(leave) 114
      """)
  }

  // MARK: A floating window whose app answers with less than it was asked for

  @Test(arguments: [
    """
    launch
    open 116 Music pid 1006 at 1972 191 3729 946 min 3729 946
    grab 116
    carry 783 272
    release
    displays third:0,0,1440,900:37,0,0,60* windows-never
    limits 116 min 189 185 max 611 668
    displays main:0,0,1440,900:0,0,0,0* side:241,900,1920,1080:0,0,96,0 windows-never
    """,
    """
    open 104 Xcode pid 1004 at -1302 278 632 262 min 300 262
    launch
    summon Xcode
    displays side:58,982,1512,982:0,0,84,0 main:0,0,1512,982:0,0,0,0* windows-late
    move 104 -2271 1324 2915 1994
    open 115 Music pid 1006 at -184 1802 486 684
    limits 104 min 118 215 max 253 283
    advance 0.3
    float-all
    desktop
    """,
    """
    launch
    open 105 Safari pid 1000 at 273 1276 3298 1200 min 3298 1200
    move 105 -2662 629 3298 1200
    toggle-pause
    displays third:0,0,800,600:37,0,0,0* side:800,-249,1440,900:0,0,0,0 windows-first
    toggle-pause
    limits 105 min 0 0 max 222 382
    displays main:0,0,1080,1920:0,0,0,0* side:1080,118,1440,900:0,48,0,0 windows-first
    """,
  ])
  func aWindowThatMayNoLongerBeAsLargeAsItsRememberedFrameIsNotLost(script: String) {
    expectEveryInvariantHolds(script)
  }

  // MARK: A corner that is Arbor's, whatever the window's title bar

  /// Finder's window has a toolbar, so macOS stops it 52 points above the bottom, not the 32 that Arbor took for every window's measure.
  /// Arbor dies with the window out of view; Finder starts again; Arbor starts under a rule that ignores Finder. Not taken for
  /// a window in Arbor's corner, it was ignored where it was, with one point of it on the display, for good.
  @Test func aWindowWithAToolbarLeftOutOfViewByACrashIsFetchedBeforeItIsIgnored() {
    let runner = world(
      after: """
        launch
        open 101 Finder pid 1005 at 300 200 920 436
        open 102 Mail pid 1002 at 400 250 600 400
        dock 101 left
        dock 102 right
        zoom 102
        flush
        crash
        renumber 101 103
        settings {"rules":[{"app":"com.example.finder","action":"ignore"}]}
        launch
        settle
        """)
    #expect(runner.system.moveLog.contains { $0.window == a && $0.after.origin == CGPoint(x: 1439, y: 848) }, "where the crash left it")
    #expect(runner.controller.filter.ignoredWindowIDs == [c])
    #expect(runner.system.isVisible(c), "\(runner.system.frame(of: c)!)")
  }

  // MARK: An overhang nobody left

  /// The display a floating window was on goes, and a smaller one is all that is left (or comes back under its name). The
  /// remembered frame overlaps it by some 26 points, by chance, and Arbor itself set the window there, taking that for a
  /// strip somebody had left.
  @Test(arguments: [
    """
    launch
    displays main:0,0,1440,900:37,0,0,0* side:-1512,-295,1512,982:37,0,0,0 third:1440,61,1512,982:0,0,0,0 windows-late
    open 112 Mail pid 1002 at 2812 605 138 103 max 493 585
    grab 112
    carry 2763 831
    release
    displays side:-21,900,1440,900:0,69,0,0 main:0,0,1440,900:25,88,0,0* windows-late
    displays third:0,0,1280,800:37,0,0,0* windows-late
    """,
    """
    open 104 Terminal pid 1003 at 1691 290 345 488 max 201 677
    tab-open 106 in 104
    renumber 106 108
    launch
    move 108 774 115 877 595
    displays third:0,0,1280,800:25,0,0,62* side:1280,-211,1512,982:0,66,0,0 windows-late
    displays main:0,0,800,600:25,49,0,0* windows-late
    """,
    """
    launch
    settings {"gap":400}
    displays main:0,0,1512,982:37,0,0,0* side:1512,-68,1920,1080:25,0,0,61 windows-never
    open 105 Music pid 1006 at 2952 -11 334 188 min 334 188
    toggle-float 105
    toggle-pin
    displays third:0,0,1920,1080:25,49,0,0* side:-1512,98,1512,982:37,0,94,0 windows-first
    toggle-pin
    displays side:170,900,1440,900:0,0,60,0 main:0,0,1440,900:25,0,0,0* windows-first
    """,
  ])
  func whatArborPlacesInViewByItselfIsWhollyInView(script: String) {
    let runner = world(after: script)
    for (id, fake) in runner.system.windows.sorted(by: { $0.key < $1.key })
    where fake.snapshot.isPresent && !runner.controller.parked.contains(id) {
      let frame = fake.snapshot.frame
      #expect(
        runner.system.displays().contains { $0.frame.contains(frame) }, "\(id) at \(frame) hangs over an edge, and nobody left it so")
    }
  }

  // MARK: Settings nobody meant

  @Test func aNegativeGapKeepsEverySlotOnTheDisplay() {
    expectEveryInvariantHolds(Self.twoDocked + "\nsettings {\"gap\":-12}\nascii")
  }

  @Test func aGapWiderThanTheDisplayStillGivesFiniteFrames() {
    expectEveryInvariantHolds(Self.twoDocked + "\nsettings {\"gap\":1000000000}\nascii\nstate\nsave\nquit")
  }

  @Test func aDesktopWeightThatIsNotPositiveStillArranges() {
    for weight in ["0", "-1", "1e-300", "1e300"] {
      expectEveryInvariantHolds(Self.twoDocked + "\nsettings {\"arrangeDesktopWeight\":\(weight)}\narrange\nsave")
    }
  }

  // MARK: Parking

  @Test func parkedWindowsStayOutOfViewWhenADisplayIsAttachedBesideThem() {
    let world = world(
      after: Self.twoDocked + """

        zoom 101
        displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:0,0,0,0 windows-first
        """)
    #expect(world.controller.parked.contains(b))
    #expect(!world.system.isVisible(b))
  }

  @Test func parkedWindowsStayOutOfViewWhenTheResolutionGrows() {
    expectEveryInvariantHolds(Self.twoDocked + "\nzoom 101\ndisplays main:0,0,2560,1440:25,0,0,0* windows-late")
  }

  @Test func aDisplayAcrossTheWholeBottomEdgeDoesNotShowParkedWindows() {
    expectEveryInvariantHolds(
      """
      displays main:0,0,1280,800:25,0,0,0* side:-97,800,1440,900:0,0,0,0 windows-never
      """ + "\n" + Self.twoDocked + "\nzoom 101")
  }

  @Test func aParkedWindowSomethingMovedIntoViewGoesBackOut() {
    let world = world(after: Self.twoDocked + "\nzoom 101\nmove 102 203 281 600 400\nsettle")
    #expect(world.controller.parked.contains(b))
    #expect(!world.system.isVisible(b))
  }

  @Test func parkingCopesWithAnAppThatAnswersWithAnotherSize() {
    expectEveryInvariantHolds(
      """
      open 102 Finder pid 1005 at 1356 618 176 65
      launch
      dock 102 right
      displays side:1512,23,1080,1920:0,0,0,88 main:0,0,1512,982:25,0,66,0* windows-late
      open 109 Xcode pid 1004 at 2302 1560 1015 384 min 1015 384 grid
      dock 109 beside 102 left
      open 110 Mail pid 1002 at 678 174 2668 1143 min 2668 1143 title Untitled
      dock 110 beside 109 bottom
      move 110 813 680 521 414
      flush
      """)
  }

  // MARK: Windows nobody can reach

  @Test func floatingWindowsAreNotStrandedWhenTheirDisplayShrinks() {
    let world = world(
      after: """
        open 101 Terminal pid 1003 at 1212 510 200 300
        launch
        displays main:0,0,1080,1920:25,0,0,0* windows-never
        """)
    #expect(world.system.isVisible(a))
  }

  @Test func aMinimizedWindowStrandedByADisplayChangeComesBackInView() {
    let world = world(
      after: """
        displays main:0,0,1440,900:25,0,0,0* side:-246,900,2560,1440:0,0,0,0 windows-never
        open 101 Mail pid 1002 at 2003 1348 300 590
        launch
        minimize 101
        displays main:0,0,1440,900:25,0,0,0* windows-never
        restore 101
        """)
    #expect(world.system.isVisible(a))
  }

  @Test func aWindowStrandedWhileItsAppWasExcludedComesBackInViewOnceIncluded() {
    let world = world(
      after: """
        displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-never
        open 101 Safari pid 1000 at 1700 100 600 400
        launch
        minimize 101
        exclude com.example.safari
        displays main:0,0,1440,900:25,0,0,0* windows-never
        include com.example.safari
        restore 101
        """)
    #expect(world.system.isVisible(a))
  }

  @Test func floatingWindowsLeftParkedByACrashComeBack() {
    let world = world(
      after: """
        open 101 Safari pid 1000 at 100 100 600 400
        open 102 Notes pid 1001 at 300 200 600 400
        launch
        dock 101 left
        settle
        """)
    let spot = world.system.frame(of: b)
    // The crash comes before the zoom is saved, so state.json says the Desktop is in view.
    for action in [ChaosAction.command("zoom 101"), .crash, .launch] { #expect(world.step(action).isEmpty, "\(action)") }
    #expect(world.system.frame(of: b) == spot)
  }

  @Test func quittingBringsBackParkedWindowsThatAreMinimizedHiddenOrOnAnotherSpace() {
    for away in ["minimize 102", "hide 1001", "space 102 off\nflush"] {
      let world = world(after: Self.twoDocked + "\nzoom 101\n\(away)\nquit")
      #expect(world.system.isVisible(b), "\(away)")
    }
  }

  @Test func aMinimizedWindowLeftParkedByACrashIsBroughtBackByTheNextQuit() {
    let world = world(after: Self.twoDocked + "\nzoom 101\nsettle\nminimize 102\nsettle\ncrash\nlaunch\nquit")
    #expect(world.system.isVisible(b))
  }

  // MARK: Drags

  @Test func theWindowInTheUsersHandIsNeitherParkedNorPutBack() {
    // b floats and is being dragged when a hotkey zooms in on a; a is dragged when b closes.
    let floating = world(
      after: """
        open 101 Safari pid 1000 at 100 100 600 400
        open 102 Notes pid 1001 at 300 200 600 400
        launch
        dock 101 left
        grab 102
        carry 900 400
        zoom 101
        """)
    #expect(floating.system.frame(of: b)?.origin == CGPoint(x: 600, y: 390), "still under the pointer")
    #expect(!floating.controller.parked.contains(b))
    #expect(floating.step(.release).isEmpty)

    let docked = world(after: Self.twoDocked + "\ngrab 101\ncarry 700 300\nclose 102")
    #expect(docked.system.frame(of: a)?.midX == 700, "still under the pointer")
    #expect(docked.step(.release).isEmpty)
  }

  @Test func aDisplayChangeDuringADragDoesNotParkTheDraggedWindow() {
    expectEveryInvariantHolds(
      """
      open 107 Safari pid 1000 at 109 245 823 707 min 541 707
      launch
      grab 107
      displays third:0,0,2560,1440:25,0,0,0* windows-late
      release
      """)
  }

  @Test func aCommandDuringADragDoesNotLeaveTheWindowOnTwoDisplays() {
    let world = world(
      after: """
        displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-never
        open 101 Safari pid 1000 at 100 100 600 400
        open 102 Notes pid 1001 at 1600 100 600 400
        launch
        dock 102 left
        grab 101
        carry 500 400
        dock 101 beside 102 right
        release
        """)
    #expect(world.controller.workspaces.values.filter { $0.contains(a) }.count == 1)
  }

  @Test func excludingTheAppOfTheDraggedWindowLetsItGo() {
    let world = world(
      after: """
        open 101 Safari pid 1000 at 100 100 600 400
        launch
        grab 101
        carry 5 400
        exclude com.example.safari
        release
        """)
    #expect(world.controller.workspaceID(containing: a) == nil)
  }

  // MARK: Bookkeeping

  @Test func excludingAndIncludingAnAppKeepsTrackOfWhereItsWindowsAre() {
    expectEveryInvariantHolds(Self.twoDocked + "\nzoom 101\nexclude com.example.notes\ninclude com.example.notes\nshow-all")
  }

  @Test func aCommandDuringADragWhoseReleaseIsLostStillPutsTheWindowInItsNewSlot() {
    expectEveryInvariantHolds(
      """
      displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-never
      open 101 Safari pid 1000 at 100 100 600 400
      open 102 Notes pid 1001 at 1600 100 600 400
      launch
      dock 101 left
      dock 102 left
      grab 101
      carry 500 400
      dock 101 beside 102 right
      lose-release
      settle
      """)
  }

  // MARK: state.json

  /// A saved arrangement of two displays, as JSON that tests can damage.
  func savedState() throws -> [String: Any] {
    let world = world(
      after: """
        displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-never
        open 101 Safari pid 1000 at 100 100 600 400
        open 102 Notes pid 1001 at 1600 100 600 400
        launch
        dock 101 left
        dock 102 left
        save
        """)
    let data = try JSONEncoder().encode(try #require(world.harness.store.saved))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  /// Starts Arbor from `state` as the app does: a file that cannot be read means a fresh start.
  func launch(from state: [String: Any]) throws -> Harness {
    let data = try JSONSerialization.data(withJSONObject: state)
    let h = Harness(
      displays: [
        FakeWindowSystem.standardDisplay,
        DisplaySnapshot(
          id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
          visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false),
      ], saved: try? JSONDecoder().decode(PersistedState.self, from: data))
    h.system.open(id: a, app: "Safari", bundleID: "com.example.safari", title: "Safari 101", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.system.open(id: b, app: "Notes", bundleID: "com.example.notes", title: "Notes 102", pid: 1001, frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.system.open(id: c, app: "Mail", bundleID: "com.example.mail", title: "Mail 103", pid: 1002, frame: CGRect(x: 300, y: 300, width: 600, height: 400))
    h.start()
    return h
  }

  /// `state` with the saved tree of the main display changed by `edit`.
  func damaging(_ state: [String: Any], _ edit: (inout [String: Any]) throws -> Void) throws -> [String: Any] {
    var state = state
    var workspaces = try #require(state["workspaces"] as? [String: Any])
    var main = try #require(workspaces["main"] as? [String: Any])
    var tree = try #require(main["tree"] as? [String: Any])
    try edit(&tree)
    main["tree"] = tree
    workspaces["main"] = main
    state["workspaces"] = workspaces
    return state
  }

  @Test func aDisplayWhoseSavedTreeIsBrokenDoesNotCostTheOthersTheirs() throws {
    let h = try launch(from: damaging(try savedState()) { $0["root"] = 77 })
    #expect(h.controller.invariantViolations() == [])
    #expect(h.controller.workspaces[DisplayID("side")]?.isDocked(b) == true)
  }

  /// Whoever checks the file (the decoder, `repair()`), and whether it mends the tree or drops it: what the controller
  /// starts from is sound, and can be worked with. Every operation on a tree relies on its invariants, with force
  /// unwraps and with loops that end only because the tree is a tree.
  @Test func aSavedTreeThatBreaksAnInvariantNeverReachesTheController() throws {
    let state = try savedState()
    let saved = try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: state))
    let tree = try #require(saved.workspaces[DisplayID("main")]?.tree)
    let leaf = try #require(tree.leaf(containing: a))
    func node(_ id: NodeID, _ edit: @escaping (inout [String: Any]) -> Void) -> (inout [String: Any]) throws -> Void {
      { object in
        var nodes = try #require(object["nodes"] as? [String: Any])
        var node = try #require(nodes["\(id.rawValue)"] as? [String: Any])
        edit(&node)
        nodes["\(id.rawValue)"] = node
        object["nodes"] = nodes
      }
    }
    func split(_ axis: String, _ children: [NodeID]) -> [String: Any] { ["split": ["axis": axis, "children": children.map(\.rawValue)]] }
    func stack(_ windows: [Int], active: Int = 0) -> [String: Any] { ["stack": ["windows": windows, "active": active]] }
    let damage: [(String, (inout [String: Any]) throws -> Void)] = [
      ("the root is missing", { $0["root"] = 99 }),
      ("the root is a leaf, so the rest is unreachable", { $0["root"] = leaf.rawValue }),
      ("the Desktop is a window", { $0["desktop"] = leaf.rawValue }),
      ("there are no nodes", { $0["nodes"] = [String: Any]() }),
      ("a node is gone", { object in
        var nodes = object["nodes"] as! [String: Any]
        nodes["\(leaf.rawValue)"] = nil
        object["nodes"] = nodes
      }),
      ("a weight is zero", node(leaf) { $0["weight"] = 0 }),
      ("a weight is negative", node(leaf) { $0["weight"] = -1 }),
      ("a weight is absurd", node(leaf) { $0["weight"] = 1e300 }),
      ("a parent link is wrong", node(leaf) { $0["parent"] = leaf.rawValue }),
      ("a node is stored under another id", node(leaf) { $0["id"] = 55 }),
      ("a window is docked twice", node(tree.desktop) { $0["kind"] = stack([101]) }),
      ("a stack is empty", node(leaf) { $0["kind"] = stack([]) }),
      ("the active tab does not exist", node(leaf) { $0["kind"] = stack([101], active: 3) }),
      ("a split has no children", node(tree.root) { $0["kind"] = split("horizontal", []) }),
      ("a split has one child", node(tree.root) { $0["kind"] = split("horizontal", [leaf]) }),
      ("a split is its own child", node(tree.root) { $0["kind"] = split("horizontal", [leaf, tree.root]) }),
      ("a leaf becomes a split that holds the root", node(leaf) { $0["kind"] = split("vertical", [tree.desktop, tree.root]) }),
      ("the next id is in use", { $0["nextRawID"] = 1 }),
      ("the next id is negative", { $0["nextRawID"] = -5 }),
      ("the next id would overflow", { $0["nextRawID"] = Int.max }),
    ]
    for (what, edit) in damage {
      let h = try launch(from: damaging(state, edit))
      #expect(h.controller.invariantViolations() == [], "\(what)")
      for line in ["dock 103 left", "dock 101 beside 103 bottom", "arrange", "zoom 103", "out", "show-all", "float-all"] { h.run(line) }
      #expect(h.controller.invariantViolations() == [], "\(what), after working with it")
    }
  }

  @Test func referencesThatPointNowhereInASavedWorkspaceAreDropped() throws {
    var state = try savedState()
    var workspaces = try #require(state["workspaces"] as? [String: Any])
    var main = try #require(workspaces["main"] as? [String: Any])
    main["camera"] = 400
    main["back"] = [401, -3]
    main["forward"] = [402]
    main["savedViews"] = ["1": 403]
    main["floating"] = ["101": [[1, 2], [3, 4]]]  // 101 is docked
    workspaces["main"] = main
    state["workspaces"] = workspaces
    let h = try launch(from: state)
    #expect(h.controller.invariantViolations() == [])
    for line in ["back", "forward", "view 1", "out"] { h.run(line) }
    #expect(h.controller.invariantViolations() == [])
  }

  @Test func aDormantWorkspaceWithAnAbsurdDateDoesNotStopTheLaunch() throws {
    let h = Harness()
    let window = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(window.rawValue) left")
    for since in [-1e300, 1e300] {
      let dormant = DormantWorkspace(workspace: h.workspace, since: Date(timeIntervalSinceReferenceDate: since))
      let again = Harness(saved: PersistedState(workspaces: [:], hints: [:], dormant: [DisplayID("gone"): dormant]))
      again.start()
      #expect(again.controller.isRunning)
    }
  }

  @Test func anUndoThatPutsTheViewBackMayTakeAFloatingWindowOutOfViewThoughTheNumberOfTheSpaceIsTheSame() {
    // The rule's fault, not undo's. Music is framed (n1) and Preview out of view; `layout` starts a tree that numbers from 1
    // again and shows everything (n1), Preview too; the undo puts back what was there. The view has moved.
    expectEveryInvariantHolds("""
      launch
      open 107 Music pid 1006 at 2317 1516 863 260
      advance 0.3
      open 108 Xcode pid 1004 at 1820 726 638.5 497.25
      open 109 Preview pid 1007 at 2051 775 685 605
      dock 107 bottom
      zoom 107
      layout Xcode | (Music / Mail)
      undo
      """)
  }

  @Test func anUndoWhileAWindowHoldsASlotProvisionallyLeavesTheTimerThatEndsTheWait() {
    // Mail's new window takes the slot that waited for the old one, for the time being. The undo found no slot waiting
    // and stopped the timer; then the window closed, its slot waited again, and nothing would ever have ended that.
    expectEveryInvariantHolds("""
      launch
      open 108 Mail pid 1002 at -285 386 391 700
      dock left
      settle
      crash
      close 108
      launch
      open 117 Mail pid 1002 at 1052 203 566 347 min 175 347
      edge 117 12 324 1256 464
      undo
      close 117
      """)
  }

  @Test func givingUpOneSlotWhileAWindowHoldsAnotherProvisionallyLeavesTheTimerThatEndsTheWait() {
    // The same fault beside it: Notes' slot is given up because its app is no longer arranged, no slot waits, the timer is
    // stopped; then Mail's new window closes, and the slot it held provisionally waits again.
    expectEveryInvariantHolds("""
      launch
      open 108 Mail pid 1002 at 100 100 400 400
      dock 108 left
      open 109 Notes pid 1003 at 300 300 400 400
      dock 109 right
      settle
      crash
      close 108
      unlist 109
      launch
      open 117 Mail pid 1002 at 1052 203 566 347
      exclude com.example.notes
      list 109
      close 117
      """)
  }

  @Test func aRedoThatMakesTheDesktopATileTakesNoFloatingWindowOutOfView() {
    // Undo's fault, and the rule did not see it: everything was in view before and after, under another number.
    expectEveryInvariantHolds("""
      launch
      open 101 Safari pid 1000 at 100 100 600 400
      open 102 Notes pid 1001 at 140 100 600 400
      open 103 Mail pid 1002 at 180 100 600 400
      open 104 Terminal pid 1003 at 220 100 600 400
      open 105 Xcode pid 1004 at 260 100 600 400
      open 106 Music pid 1006 at 500 350 400 300
      layout Safari | Notes | Mail | Terminal | Xcode
      undo
      move 106 600 300 400 300
      redo
      """)
  }

  // MARK: What Arbor gives back is fitted unless its user left it there

  /// `layout` docks a wide app and Arbor squeezes the floating Terminal into the strip that is left. Its user moves it down inside the
  /// strip, four points behind the Dock. Docking another window makes room, and Arbor used to give the Terminal its own, larger size at
  /// the corner the hand gave: 253 of 716 points showed, and ⌃⌥0 did not fetch it.
  @Test func aSqueezedWindowItsUserNudgedGetsItsOwnSizeBackInView() {
    expectEveryInvariantHolds(Self.squeezedThenNudged(moveTo: 330))
    // The threshold: one point behind the Dock (the visible frame ends at 923, the window is 597 high).
    expectEveryInvariantHolds(Self.squeezedThenNudged(moveTo: 327))
  }

  /// Its controls, which end with the window wholly in view: no hand; a hand that leaves it wholly inside the visible frame.
  @Test func aSqueezedWindowThatIsLeftAloneOrLeftInsideTheVisibleFrameEndsWhollyInView() {
    for script in [Self.squeezedThenNudged(moveTo: nil), Self.squeezedThenNudged(moveTo: 326)] {
      let runner = world(after: script)
      let frame = runner.system.windows[WindowID(102)]!.snapshot.frame
      #expect(runner.system.displayList[0].frame.contains(frame), "\(frame)")
    }
  }

  private static func squeezedThenNudged(moveTo y: Int?) -> String {
    """
    launch
    open 102 Terminal pid 1003 at 117 200 763 597
    open 105 Xcode pid 1004 at 100 100 1300 800 min 1188 685
    displays third:0,0,1512,982:25,0,59,0* windows-late
    layout Finder / Xcode
    open 107 Safari pid 1000 at 176 351 431 478 max 437 480
    \(y.map { "move 102 1212 \($0) 288 597" } ?? "settle")
    dock left
    """
  }

  // MARK: What Arbor owes a window it has let go of

  /// Arbor never moves what it does not arrange, but for the way back it owes a window that it put out of view and whose app did
  /// not answer when it was let go of: hung, or in full screen.
  @Test func theWayBackIsPaidToAWindowArborNoLongerArranges() {
    expectEveryInvariantHolds(
      """
      open 101 Mail pid 1002 at 956 751 877 388
      open 102 Notes pid 1001 at 126 377 2038 1445 min 2038 1445
      launch
      grab 102
      release
      in
      behave 101 frozen
      settings {"excludedBundleIDs":["com.example.mail","com.example.finder"]}
      settle
      """)
    expectEveryInvariantHolds(
      """
      open 101 Finder pid 1005 at 943 176 628 377 min 249 377 title Draft
      renumber 101 102
      launch
      full-screen 102 on
      displays side:0,0,1512,982:25,77,0,0* main:1512,30,1920,1080:0,46,0,0 third:3432,-201,1440,900:37,0,0,42 windows-first
      displays side:-232,1920,1440,900:0,0,89,0 main:0,0,1080,1920:37,0,0,0* windows-never
      exclude com.example.finder
      displays main:0,0,1080,1920:25,0,0,54* side:-1440,-14,1440,900:0,0,0,0 windows-first
      """)
  }

  @Test func whateverIsDoneToStateJSONArborStartsWithEveryInvariantIntact() {
    for damage in 0..<60 {
      expectEveryInvariantHolds(
        Self.twoDocked + """

          open 103 Mail pid 1002 at 500 300 600 400
          dock 103 beside 101 bottom
          zoom 103
          save-view 2
          show-all
          displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-first
          quit
          corrupt \(damage)
          launch
          arrange
          back
          view 2
          quit
          """)
    }
  }

  // MARK: Go to…

  /// It came only once macOS reported that it had the keyboard, while the reply said it was in view.
  @Test func aWindowSentAwayAndChosenInGoToComesAtOnce() {
    expectEveryInvariantHolds(
      """
      open 106 Music pid 1006 at 170 400 521 355
      launch
      summon Music
      open 110 Xcode pid 1004 at 100 100 700 600
      find
      palette choose
      """)
  }

  /// Its slot at the level that holds both was too small for it, which Arbor had forgotten since it was last launched.
  @Test func aWindowThatRefusesItsSlotIsFramedWhenChosenInGoTo() {
    expectEveryInvariantHolds(
      """
      open 107 Preview pid 1007 at -169 57 404 398 min 175 398
      open 110 Notes pid 1001 at 517 625 3691 1807 min 3691 1807 title main.swift
      edge 107 12 12 942 1056
      open 111 Finder pid 1005 at 1638 762 1157 587 min 1157 587 title Inbox
      launch
      open 112 Notes pid 1001 at 262 1764 1978 1262 title Inbox
      arrange all
      restore 111
      dock beside 107 bottom
      quit
      launch
      find
      palette choose
      """)
  }

  @Test func aWindowSentAwayWhoseAppIsHiddenComesWhenChosenInGoTo() {
    expectEveryInvariantHolds(
      """
      open 109 Music pid 1006 at 472 301 579 479
      launch
      summon Music
      open 111 Mail pid 1002 at 124 120 1006 590
      hide 1006
      find
      palette choose
      """)
  }

  /// The rule was wrong: the camera had been on Music all along, and more was shown only while Music was hidden.
  @Test func goingToAWindowOfAHiddenAppTakesTheFloatingWindowsOutOfView() {
    expectEveryInvariantHolds(
      """
      open 101 Notes pid 1001 at 435 460 3608 2424 min 3608 2424
      launch
      arrange
      displays side:0,0,1080,1920:37,0,0,0* main:1080,185,2560,1440:37,0,88,0 windows-late
      open 108 Music pid 1006 at 433 1228 600 784 min 600 784 title main.swift
      dock 108 beside 101 bottom
      switch-app 101
      open 113 Music pid 1006 at 1102 752 81 124 max 608 1682
      frame-rect 840 1916 1520 -773
      hide 1006
      float 101
      focus 113
      find Music
      """)
  }

  /// The rule was wrong: an app that does not answer cannot be moved, so its window counts as out of view, truthfully, as after
  /// `zoom`. The view is on its space, it has the keyboard, and it takes its slot when the app answers again.
  @Test func aWindowOfAHungAppChosenInGoToFollowsWhenItsAppAnswersAgain() {
    let music = WindowID(103)
    let hung = """
      launch
      open 101 Xcode pid 1004 at 2789 894 1674 1091 min 1674 1091
      toggle-pause
      toggle-pause
      open 103 Music pid 1006 at -259 175 808 403 min 124 188 max 210 1339 grid
      arrange
      tile main 1
      hang 1006
      find
      palette choose
      """
    let waiting = world(after: hung)
    #expect(waiting.controller.parked.contains(music) && waiting.system.focused == music)
    #expect(waiting.controller.workspaces.values.contains { $0.camera == $0.tree.leaf(containing: music) }, "the view went there")
    let answered = world(after: hung + "\nwake 1006\nsettle")
    #expect(!answered.controller.parked.contains(music) && answered.system.focused == music)
  }

  // MARK: Holds (F58)

  /// The keyboard was asked back when the window opened; its app activated it a moment later, and nobody looked again.
  @Test func onAHeldViewTheLineIsNotLeftAroundAWindowThatHasLostTheKeyboard() {
    expectEveryInvariantHolds("""
      open 104 Terminal pid 1003 at 1267 127 145 117
      launch
      dock 104 right
      toggle-hold
      open 109 Finder pid 1005 at -281 451 1515 1385 max 794 1097 title Untitled
      focus 109
      flush
      react
      """)
  }

  /// What was kept out of view during a hold comes in when the view next moves. A command that announces a move and makes none, or
  /// moves nothing at all, ended the waiting, and nothing brought the window in.
  @Test(arguments: [
    """
    open 105 Notes pid 1001 at -1193 109 559 549
    launch
    hold
    open 109 Preview pid 1007 at 88 2036 97 56
    hold still 0.001
    summon Finder
    """,
    """
    launch
    hold still
    open 106 Mail pid 1002 at 1295 282 2634 2311 min 2634 2311 title main.swift
    reset screenEdgeBand
    """,
    """
    launch
    hold still 1440
    open 106 Preview pid 1007 at -549 56 2858 1563 min 2858 1563 title Inbox
    view 9
    """,
  ]) func aWindowKeptOutDuringAHoldIsNotForgottenInItsCorner(script: String) {
    expectEveryInvariantHolds(script)
  }

  /// A held view never widens by itself, so with the app being shown hidden the display should look empty. The rule asked the ordinary
  /// layout what it should look like, not `freshLayout(of:)`.
  @Test func aHeldViewWithNothingLeftInItIsNotTakenForAForgottenLayout() {
    expectEveryInvariantHolds("""
      launch
      open 112 Finder pid 1005 at -185 417 595 786 min 595 786
      open 114 Safari pid 1000 at 490 486 380 129 min 380 129 max 666 1837 title Untitled
      open 116 Finder pid 1005 at 200 497 808 638 max 477 1731
      arrange all
      zoom-node 5
      hold
      hide 1000
      """)
  }

  /// The view was on a window that was away already when the hold began, so what is around it showed. The fence was around the window.
  @Test(arguments: [
    """
    launch
    open 103 Xcode pid 1004 at 765 835 81 75
    open 106 Safari pid 1000 at 959 159 484 290
    displays main:0,0,1440,900:25,0,0,0* side:-2560,182,2560,1440:0,0,0,0 windows-first
    space 106 off
    cursor -504 1261
    layout Preview | Safari
    zoom 106
    toggle-hold
    """,
    """
    launch
    set minimumUsableHeight 1000
    rule add com.example.music dock top
    open 102 Music pid 1006 at -136 788 701 423 min 298 367
    open 103 Mail pid 1002 at -404 462 2161 1082 min 2161 1082 title main.swift no-bundle
    displays side:0,0,1080,1920:25,0,0,0* windows-late
    hide 1006
    hold
    displays main:0,0,1280,800:0,0,0,41* windows-late
    """,
    """
    displays main:0,0,1512,982:25,0,0,0* side:-1512,140,1512,982:0,78,0,0 windows-never
    launch
    open 104 Xcode pid 1004 at -1130 798 3203 1584 min 3203 1584
    hide 1004
    open 105 Safari pid 1000 at -705 407 176 128
    dock 104 bottom
    zoom-node 1
    toggle-hold
    """,
  ]) func whatIsSeenIsHeldThoughTheViewIsOnAWindowThatIsAway(script: String) {
    expectEveryInvariantHolds(script)
  }

  /// The chaos lab's own three, mended by the same changes: the window in view goes into full screen or to another macOS Space, and a window
  /// that was kept out is still out after the release, with a command after it that goes nowhere.
  @Test(arguments: [
    """
    launch
    open 104 Finder pid 1005 at -71 512 3036 2255 min 3036 2255
    dock left
    focus 104
    hold
    full-screen 104 on
    """,
    """
    open 101 Xcode pid 1004 at 2349 533 478 658 min 245 212
    open 102 Xcode pid 1004 at 1443 145 906 595 min 906 360
    open 103 Finder pid 1005 at -328 31 690 497
    launch
    open 105 Terminal pid 1003 at 1192 276 854 358 min 854 334
    open 106 Preview pid 1007 at 870 469 821 651 min 821 324 max 821 809
    arrange all
    dock 106 beside 102 right
    tile main 9
    toggle-hold
    space 106 off
    open 108 Music pid 1006 at 481 459 107 131 snaps-back
    """,
    """
    open 101 Safari pid 1000 at 929 281 786 481 min 775 336
    launch
    toggle-hold
    displays main:0,0,800,600:37,0,0,0* windows-first
    open 112 Preview pid 1007 at 608 63 1158 717 min 1158 717 max 1158 1824
    toggle-hold
    back
    """,
  ]) func theBooksAndTheScreenAgreeDuringAndAfterAHold(script: String) {
    expectEveryInvariantHolds(script)
  }

  /// A window that waited is chosen in Go to… with the Desktop in view already: no view has to move, and nothing let it in.
  @Test func aWindowThatWaitedComesWhenItIsChosenThoughNoViewMoves() {
    expectEveryInvariantHolds("""
      launch
      open 105 Xcode pid 1004 at 326 191 909 427 min 909 427
      open 108 Music pid 1006 at 207 359 3822 1504 min 3822 1504
      open 109 Safari pid 1000 at 736 1095 866 413 min 306 246 title Untitled
      arrange all
      exclude
      via shortcut hold 1440
      open 111 Music pid 1006 at 432 200 1824 1425
      focus 108
      settle
      focus 105
      open 112 Mail pid 1002 at -400 617 548 504 min 548 504 title Inbox
      find
      palette choose 3
      """)
  }

  /// The panic button. (The window here is no longer kept out at all: no window of its app is out of view.)
  @Test func floatAllFetchesWhatAHoldKeptOut() {
    expectEveryInvariantHolds("""
      open 101 Xcode pid 1000 at 1021 714 730 680
      launch
      toggle-hold
      open 113 Music pid 1006 at 304 37 3716 2388 min 3716 2388 max 3716 2388
      float-all
      settle
      """)
  }

  /// `float-all` lays out only the displays where something is docked, `float-all here` only one. The waiting ended on all of them.
  @Test(arguments: [
    """
    open 106 Music pid 1006 at 702 186 323 632 title ~
    displays third:0,0,1440,900:25,0,77,0* side:-1440,-193,1440,900:0,83,0,0 windows-first
    launch
    full-screen 106 on
    displays main:0,0,1440,900:37,0,0,57* side:126,900,1280,800:0,0,0,0 windows-late
    open 118 Preview pid 1007 at 1319 1539 670 642
    toggle-hold
    open 121 Music pid 1006 at -518 915 825 480 min 670 442
    float-all here
    """,
    """
    displays third:0,0,1512,982:37,66,0,0* side:-1440,-220,1440,900:0,61,0,0 windows-never
    open 103 Safari pid 1000 at 393 794 647 434
    launch
    open 104 Terminal pid 1003 at -682 539 415 612 max 430 267
    hide 1003
    displays main:0,0,1920,1080:25,0,0,0* side:-53,1080,800,600:37,0,82,0 windows-never
    toggle-hold
    open 113 Terminal pid 1003 at 466 1519 2985 2276 min 2985 2276
    float-all
    """,
    """
    launch
    open 101 Notes pid 1001 at 7 650 701 746 min 701 746
    displays side:1280,-211,1440,900:25,0,0,76 main:0,0,1280,800:25,0,0,0* windows-never
    toggle-hold
    dock top
    open 112 Notes pid 1001 at 2564 44 450 546 title ~
    float-all here
    """,
  ]) func floatingEverythingLeavesNoWindowWaitingOnADisplayItDidNotLayOut(script: String) {
    expectEveryInvariantHolds(script)
  }

  /// F22. A Desktop with nothing on it gives up room that one in use keeps (F61), and neither display was laid out again.
  @Test func aFloatingWindowSentToAnotherDisplayLeavesBothLaidOut() {
    expectEveryInvariantHolds(
      """
      launch
      open 103 Safari pid 1000 at 2152 631 573 542
      displays side:138,982,1280,800:0,0,0,0 main:0,0,1512,982:37,0,0,0* windows-first
      open 106 Finder pid 1005 at 1228 1356 698 793 min 698 793
      toggle-float
      move-to-display previous 106
      dock 103 bottom
      out
      open 109 Mail pid 1002 at 190 728 749 447 min 521 378
      move-to-display previous
      """)
  }

  /// F22. The size a window had before it was docked (F48) stayed behind on the display it left.
  @Test func aSwapBetweenDisplaysTakesTheWindowsOwnSizeAlong() {
    expectEveryInvariantHolds(
      """
      open 102 Notes pid 1001 at 126 377 2038 1445 min 2038 1445
      launch
      grab 102
      displays main:0,0,1280,800:25,0,0,0* side:-192,800,1920,1080:37,0,0,0 third:-186,1880,1512,982:25,0,0,0 windows-first
      release
      open 103 Safari pid 1000 at 1202 921 425 255
      dock 103 right
      swap 103 102
      """)
  }

  /// The rule `start-took-out-of-view`. Two docked, one framed, one that was never docked: the second start brought the framed view back and sent the
  /// other two to the corner, from where the quit had just fetched them. After a summon too, whatever the view.
  @Test(arguments: ["zoom 101", "summon Mail\nfocus 101\nshow-all"]) func aLaunchTakesNothingOutOfView(before: String) {
    expectEveryInvariantHolds(
      Self.twoDocked + """

        open 103 Mail pid 1002 at 420 300 500 400
        settle
        \(before)
        settle
        quit
        launch
        settle
        """)
  }

  /// The rule `codable-history`. With ⌃⌥Space held the view is only visiting, and history is kept by where it belongs: Back can lead to
  /// everything, where the camera is. Written down like that, without a word on the visit, it was read back with the entry tidied away.
  /// And with the window closing meanwhile: the root gives way to the Desktop, where the look began.
  @Test(arguments: ["settle", "close 103\nsettle"]) func whatIsSavedWhileAPeekIsHeldReadsBackAsItWasWritten(then: String) {
    expectEveryInvariantHolds(
      """
      displays main:0,0,1280,800:25,86,0,0* windows-never
      launch
      open 103 Finder pid 1005 at 189 80 1086 314 min 501 300
      key down dock right
      key down desktop
      key down show-all
      \(then)
      """)
  }

  /// The same root spoke as plain `codable` too, where history did not differ and only the visit did.
  @Test(arguments: [
    "open 104 Notes pid 1001 at 559 129 846 708 min 709 300\nlaunch\nkey down arrange\nkey down zoom\nkey down neighbor right",
    "open 102 Notes pid 1001 at 518 417 873 570 min 709 300\nlaunch\nkey down arrange\nkey down desktop\nkey down focus left",
  ]) func whateverTheViewWasWhatIsSavedWhileAPeekIsHeldReadsBack(before: String) {
    expectEveryInvariantHolds(before + "\nkey down show-all\nsettle")
  }
}
