import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// Every window Arbor arranges is docked or floating on exactly one display, and every tree is sound.
@MainActor
private func expectNothingLost(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
  var seen: [WindowID: Int] = [:]
  for workspace in h.controller.workspaces.values {
    #expect(workspace.tree.invariantViolations().isEmpty, sourceLocation: sourceLocation)
    #expect(workspace.tree.contains(workspace.camera), sourceLocation: sourceLocation)
    for window in workspace.tree.allWindows + Array(workspace.floating.keys) { seen[window, default: 0] += 1 }
  }
  for window in h.system.windows.keys { #expect(seen[window] == 1, "\(window)", sourceLocation: sourceLocation) }
  #expect(seen.count == h.system.windows.count, sourceLocation: sourceLocation)
}

/// The `layout` command against the real controller (docs/features/F54-layouts-as-text.md).
@Suite @MainActor struct LayoutCommandTests {
  /// One window of each app, opened in this order (ids from 101), floating.
  func harness(_ apps: String..., displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Settings()) -> Harness {
    let h = Harness(displays: displays, settings: settings)
    for app in apps { h.system.open(app: app) }
    h.start()
    return h
  }

  func w(_ id: UInt32) -> WindowID { WindowID(id) }

  /// Opens a window of `app` and says whether it was left floating, or was docked.
  func floats(_ h: Harness, _ app: String) -> Bool {
    let window = h.system.open(app: app)
    return h.workspace.isFloating(window)
  }

  /// A window of an app that `open -g` started: it appears and becomes its app's focused window, but the app is not in
  /// front, so the keyboard stays where it was.
  func openInBackground(_ h: Harness, _ app: String) -> WindowID {
    let echoes = h.system.echoes
    h.system.echoes.keyboard = false
    let window = h.system.open(app: app)
    h.system.echoes = echoes
    h.system.backgroundFocus(window)
    return window
  }

  func docks(_ h: Harness, _ app: String) -> Bool {
    let window = h.system.open(app: app)
    return h.workspace.isDocked(window)
  }

  // MARK: Arranging

  @Test func sideBySideAboveAndTheDesktop() throws {
    let h = harness("Safari", "Mail", "Notes")
    let result = h.run("layout Safari | Desktop | (Mail / Notes)")
    #expect(result.ok)
    #expect(result.message == "arranged 3 windows")
    let (safari, mail, notes) = (try #require(h.frame(w(101))), try #require(h.frame(w(102))), try #require(h.frame(w(103))))
    let desktop = try #require(h.layout?.desktopFrame)
    // Three columns of one width, in the order written; the last is two rows of one height.
    #expect(safari.maxX < desktop.minX && desktop.maxX < mail.minX)
    #expect(abs(safari.width - mail.width) <= 1 && abs(safari.width - desktop.width) <= 1)
    #expect(mail.minX == notes.minX && mail.maxY < notes.minY && abs(mail.height - notes.height) <= 1)
    #expect(safari.height > 800)
    expectWindowsMatchLayout(h, on: h.display)
    expectNothingLost(h)
  }

  @Test func sizesAreRelative() throws {
    let h = harness("Xcode", "Simulator", "Terminal")
    #expect(h.run("layout Xcode:2 | (Simulator / Terminal) | Desktop").ok)
    let (xcode, simulator) = (try #require(h.frame(w(101))), try #require(h.frame(w(102))))
    #expect(abs(xcode.width / simulator.width - 2) < 0.05)
  }

  @Test func theDesktopIsAddedAtTheRightAtTheWidthArrangeGivesIt() throws {
    var settings = Settings()
    settings.arrangeDesktopWeight = 0.75
    let h = harness("Safari", "Mail", settings: settings)
    #expect(h.run("layout Safari | Mail").ok)
    let (mail, desktop) = (try #require(h.frame(w(102))), try #require(h.layout?.desktopFrame))
    #expect(desktop.minX > mail.maxX)
    #expect(abs(desktop.width / mail.width - 0.75) < 0.02)
    // What `arrange` makes of the same two windows.
    let frames = [h.frame(w(101)), h.frame(w(102))]
    #expect(h.run("arrange").ok)
    #expect([h.frame(w(101)), h.frame(w(102))] == frames)
  }

  @Test func aTabGroupSharesOnePlace() throws {
    let h = harness("Safari", "Chrome", "Slack")
    h.system.userFocus(w(102))
    #expect(h.run("layout [Safari Chrome] | Slack").ok)
    let leaf = try #require(h.workspace.tree.leaf(containing: w(101)))
    #expect(h.workspace.tree.leaf(containing: w(102)) == leaf)
    #expect(h.workspace.tree[leaf]?.kind == .stack(windows: [w(101), w(102)], active: 1))
    // The one used last shows; the other is out of view.
    #expect(h.layout?.windowFrames[w(102)] != nil)
    #expect(!h.system.isVisible(w(101)))
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func namesAreAppNamesOrBundleIDsInAnyCase() {
    let h = Harness()
    h.system.open(app: "Visual Studio Code", bundleID: "com.microsoft.VSCode")
    h.system.open(app: "Google Chrome", bundleID: "com.google.Chrome")
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.start()
    for line in [
      "\"Visual Studio Code\" | \"Google Chrome\" | Safari", "com.microsoft.VSCode | com.google.Chrome | com.apple.Safari",
      "'visual studio code' | CHROME | safari", "VSCode | Chrome | COM.APPLE.SAFARI", "Code | Google | Safari",
    ] {
      h.run("float-all")
      #expect(h.run("layout \(line)").message == "arranged 3 windows", "\(line)")
      #expect(h.workspace.tree.allWindows == [w(101), w(102), w(103)], "\(line)")
    }
  }

  @Test func windowsCanBeNamedByNumber() {
    let h = harness("Safari", "Safari", "Safari")
    #expect(h.run("layout 103 | w101 | Desktop").message == "arranged 2 windows")
    #expect(h.workspace.tree.allWindows == [w(103), w(101)])
    #expect(h.workspace.isFloating(w(102)))
    #expect(h.run("layout 103 | 999").message == "arranged 1 window, floated 1; no window 999")
  }

  // MARK: Several windows of one app

  @Test func twoWindowsOfOneAppArePlacedInFocusOrder() {
    let h = harness("Safari", "Safari", "Safari", "Mail")
    h.system.userFocus(w(101))
    h.system.userFocus(w(103))
    h.system.userFocus(w(104))
    h.system.userFocus(w(102))
    #expect(h.run("layout Safari | Mail | Safari").ok)
    // 102 was used last, 103 before it.
    #expect(h.workspace.tree.allWindows == [w(102), w(104), w(103)])
    #expect(h.workspace.isFloating(w(101)))
  }

  @Test func theFocusedWindowComesFirstEvenIfNoEventSaidSo() {
    let h = harness("Safari", "Safari")
    h.system.focus(w(102))
    #expect(h.run("layout Safari").ok)
    #expect(h.workspace.tree.allWindows == [w(102)])
  }

  @Test func windowsNeverFocusedComeInTheOrderTheyOpened() {
    let h = harness("Safari", "Safari", "Safari")
    h.system.userFocus(w(103))
    #expect(h.run("layout Safari | Safari | Safari").ok)
    #expect(h.workspace.tree.allWindows == [w(103), w(101), w(102)])
  }

  @Test func aStarCollectsTheRestAsTabs() throws {
    let h = harness("Safari", "Safari", "Safari", "Mail")
    h.system.userFocus(w(102))
    #expect(h.run("layout Safari | Mail | Safari*").message == "arranged 4 windows; 1 window is behind a tab: ⌘Tab or ⌘` brings one forward")
    #expect(h.workspace.tree.allWindows == [w(102), w(104), w(101), w(103)])
    #expect(h.workspace.tree.leaf(containing: w(101)) == h.workspace.tree.leaf(containing: w(103)))
    #expect(h.workspace.tree.leaf(containing: w(101)) != h.workspace.tree.leaf(containing: w(102)))
  }

  @Test func aTitlePicksTheWindow() {
    let h = Harness()
    h.system.open(app: "Safari", title: "News")
    h.system.open(app: "Safari", title: "Inbox (3)")
    h.system.open(app: "Safari", title: "Docs")
    h.start()
    #expect(h.run("layout Safari~docs | Safari~\"inbox (\" | Safari").ok)
    #expect(h.workspace.tree.allWindows == [w(103), w(102), w(101)])
  }

  // MARK: What is missing

  @Test func missingAppsAreReportedAndTheirSlotsClosedUp() throws {
    let h = harness("Safari", "Notes", "Slack", "Xcode")
    let result = h.run("layout Safari | Desktop | (Mail / Notes) | Slack | Xcode")
    #expect(result.ok)
    #expect(result.message == "arranged 4 windows; no window of Mail")
    // Notes has the whole column.
    #expect(try #require(h.frame(w(102))).height == #require(h.frame(w(101))).height)
    expectNothingLost(h)
  }

  @Test func repliesListWhatIsMissingInWords() {
    let h = harness("Safari")
    #expect(h.run("layout Safari | Mail | Notes").message == "arranged 1 window; no window of Mail or Notes")
    #expect(h.run("layout Safari | A | B | C").message == "arranged 1 window; no window of A, B or C")
    #expect(h.run("layout Safari | A | B | C | D | E | F | G").message == "arranged 1 window; no window of A, B, C, D or 3 more")
    #expect(h.run("layout Safari | Safari").message == "arranged 1 window; only 1 window of Safari")
    #expect(h.run("layout Safari | Safari | Mail | 7").message == "arranged 1 window; no window of Mail; no window 7; only 1 window of Safari")
    #expect(h.run("layout Safari | Safari*").message == "arranged 1 window")
  }

  @Test func whenNothingIsFoundNothingChanges() {
    let h = harness("Safari", "Mail")
    h.run("layout Safari | Mail")
    let before = h.workspace
    h.system.clearFrameLog()
    let result = h.run("layout Sfari | Mial")
    #expect(!result.ok)
    #expect(result.message == "no window of Sfari or Mial; nothing changed")
    #expect(h.workspace == before)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func appsArborDoesNotArrangeHaveNoWindows() {
    var settings = Settings()
    settings.excludedBundleIDs = ["com.example.music"]
    let h = harness("Safari", "Music", settings: settings)
    #expect(h.run("layout Safari | Music").message == "arranged 1 window; Arbor does not arrange Music")
    #expect(h.run("layout --open Safari | Music").message == "arranged 1 window; Arbor does not arrange Music")
    #expect(h.system.launchedApps.isEmpty)
    #expect(h.run("layout Music").message == "Arbor does not arrange Music; nothing changed")
    #expect(h.run("layout Safari | 102").message == "arranged 1 window; no window 102")
    #expect(h.frame(w(102)) == CGRect(x: 300, y: 200, width: 640, height: 420))
  }

  @Test func aMinimisedWindowGetsItsPlaceAndTakesItWhenItIsBack() throws {
    let h = harness("Safari", "Mail", "Mail")
    h.system.setMinimized(w(102), true)
    // The window that can be seen is preferred, whichever was used last.
    h.system.userFocus(w(102))
    #expect(h.run("layout Safari | Mail").message == "arranged 2 windows")
    #expect(h.workspace.tree.allWindows == [w(101), w(103)])

    h.system.setMinimized(w(103), true)
    let result = h.run("layout Safari | Mail | Mail | Desktop")
    #expect(result.message == "arranged 3 windows; Mail is minimized or hidden, and will be in place when back")
    let alone = try #require(h.frame(w(101))).width
    h.system.setMinimized(w(102), false)
    #expect(try #require(h.frame(w(101))).width < alone)
    #expect(try #require(h.frame(w(102))).minX > #require(h.frame(w(101))).maxX)
    expectWindowsMatchLayout(h, on: h.display)
  }

  // MARK: Windows that are not mentioned

  @Test func windowsNotMentionedFloatOnTheDesktop() {
    let h = harness("Safari", "Mail", "Notes", "Slack")
    h.run("arrange")
    #expect(h.workspace.tree.allWindows.count == 4)
    let result = h.run("layout Safari | Desktop | Mail")
    #expect(result.message == "arranged 2 windows, floated 2")
    for window in [w(103), w(104)] {
      #expect(h.workspace.isFloating(window))
      #expect(isOnDesktop(window, h), "\(window)")
    }
    expectNothingLost(h)
  }

  @Test func windowsThatFloatedAlreadyMoveOffTheDockedOnes() {
    let h = harness("Safari", "Mail", "Notes")
    #expect(h.run("layout Safari | Mail | Desktop").ok)
    #expect(isOnDesktop(w(103), h))
  }

  @Test func aPinnedWindowKeepsItsPlaceUnlessTheLineNamesIt() throws {
    let h = harness("Safari", "Mail", "Zoom")
    h.system.userMove(w(103), to: CGRect(x: 40, y: 60, width: 320, height: 200))
    h.run("pin 103")
    let frame = h.frame(w(103))
    #expect(h.run("layout Safari | Mail").ok)
    #expect(h.frame(w(103)) == frame)
    #expect(h.workspace.isPinned(w(103)))
    // It does not live on the Desktop, so the Desktop is not widened for it.
    #expect(h.run("layout").text == "Safari | Mail | Desktop:0.5")
    #expect(h.run("layout Safari | Zoom").ok)
    #expect(h.workspace.isDocked(w(103)) && !h.workspace.isPinned(w(103)))
  }

  @Test func windowsOutOfViewComeBack() throws {
    let h = harness("Safari", "Mail", "Notes")
    h.run("arrange")
    h.run("zoom 101")
    #expect(!h.system.isVisible(w(102)) && !h.system.isVisible(w(103)))
    #expect(h.run("layout Mail | Desktop").message == "arranged 1 window, floated 2")
    for window in [w(101), w(102), w(103)] { #expect(h.system.isVisible(window), "\(window)") }
    #expect(h.controller.parked.isEmpty)
  }

  @Test func theDesktopAloneFloatsEverything() {
    let h = harness("Safari", "Mail")
    h.run("arrange")
    #expect(h.run("layout Desktop").message == "arranged 0 windows, floated 2")
    #expect(h.workspace.tree.root == h.workspace.tree.desktop)
    // Asked for again, it is already so, which is not a failure: scripts can say what they want to be true.
    #expect(h.run("layout Desktop").ok)
    expectNothingLost(h)
  }

  // MARK: A window moves once

  /// What Arbor has asked of each window since the log was last cleared: "w103 (960,200 480×420)".
  func given(_ h: Harness) -> [String] { h.system.frameLog.map { "\($0.window) \($0.frame.brief)" } }

  /// None of `windows` has been moved more than once since the log was last cleared, besides a question put to it where it stood
  /// (Controller+AskFirst.swift), nothing was done twice or for nothing, and each is where the last frame put it.
  func expectMovedAtMostOnce(_ h: Harness, _ windows: [WindowID], _ story: String, sourceLocation: SourceLocation = #_sourceLocation) {
    for window in windows {
      let frames = h.system.frameLog.filter { $0.window == window }.map(\.frame)
      let moves = movesWithoutWaste(h, of: window, since: h.system.movesWhenTheFrameLogWasCleared)
      #expect((moves ?? 2) <= 1, "\(story): \(window) was given \(frames.map(\.brief))", sourceLocation: sourceLocation)
      if let last = frames.last { #expect(h.frame(window) == last, "\(story): \(window)", sourceLocation: sourceLocation) }
    }
  }

  /// A line is one action, and for one action a window is given one frame: the one it ends at. That goes for the windows the
  /// line places, for those it takes out of their slots, and for those that floated already and have to make way.
  @Test(arguments: ["102", "B", "B | Desktop", "Desktop | B", "B / Desktop", "C | B", "Desktop"], [0.46, 0])
  func whateverALineMovesMovesOnce(line: String, duration: Double) {
    var settings = Settings()
    settings.animationDuration = duration
    let h = harness("A", "B", "C", settings: settings)
    #expect(h.run("layout A | Desktop | B").ok, "C floats on the Desktop")
    h.scheduler.advance(by: 2)
    h.system.clearFrameLog()
    #expect(h.run("layout \(line)").ok)
    h.scheduler.advance(by: 2)
    expectMovedAtMostOnce(h, [w(101), w(102), w(103)], "layout \(line)")
    expectWindowsMatchLayout(h)
  }

  /// The same from other beginnings: a window that will float alone, one that fills the view, one its user laid over a docked
  /// window, a Desktop too small to use, before the line or after it.
  @Test(arguments: [
    (["layout A | B | C"], "B | C | Desktop"), (["layout A | B | C"], "C"), (["layout A | B | C", "zoom 101"], "B | Desktop"),
    (["layout A | B | C", "zoom 101"], "B | C"), (["layout A | B | Desktop", "hand"], "B | A | Desktop"), (["layout A | B", "hand"], "B"),
    (["layout A | B | C"], "A | Desktop:0.01"), (["layout A | B | Desktop:0.01"], "A | Desktop"), (["layout A | B | Desktop:0.01"], "B"),
  ])
  func whereverItStartsFromALineMovesAWindowOnce(before: [String], line: String) {
    let h = harness("A", "B", "C")
    for step in before {
      if step == "hand" { h.system.userMove(w(103), to: CGRect(x: 60, y: 120, width: 400, height: 300)) } else { #expect(h.run(step).ok) }
      h.scheduler.advance(by: 2)
    }
    h.system.clearFrameLog()
    #expect(h.run("layout \(line)").ok)
    h.scheduler.advance(by: 2)
    expectMovedAtMostOnce(h, [w(101), w(102), w(103)], "\(before), layout \(line)")
    for window in [w(101), w(102), w(103)] { #expect(h.system.isVisible(window), "\(before), layout \(line): \(window)") }
    // And it is where the next layout, whatever it is for, would leave it.
    h.system.clearFrameLog()
    #expect(h.run("relayout").ok)
    #expect(given(h).isEmpty, "\(before), layout \(line): \(given(h))")
    expectWindowsMatchLayout(h)
  }

  /// Where the Desktop is too small to use, a window that leaves its slot stays in view at its own size, over the docked ones. It is
  /// put back as `float` puts its window back: one whose app keeps it larger than it floated is slid wholly onto the display,
  /// and it counts as lying where its user had it, so that no later layout squeezes it onto a Desktop that has room again.
  @Test func overADesktopTooSmallToUseAWindowIsPutBackAndNotPlaced() throws {
    let h = harness("A", "B", "C")
    #expect(h.run("layout A | B | C").ok)
    h.system.setMinimumSize(w(103), CGSize(width: 400, height: 700))
    h.system.clearFrameLog()
    #expect(h.run("layout A | Desktop:0.01").ok)
    #expect(h.layout?.desktopFrame == nil)
    expectMovedAtMostOnce(h, [w(101), w(102)], "the one that takes any size")
    #expect(h.frame(w(102))?.size == CGSize(width: 640, height: 420))
    #expect(h.visibleFrame.contains(try #require(h.frame(w(103)))), "\(given(h))")
    let frames = [w(102), w(103)].map { h.frame($0) }
    #expect(h.run("resize 101 right -500").ok)
    #expect(h.layout?.desktopFrame != nil)
    #expect([w(102), w(103)].map { h.frame($0) } == frames)
  }

  /// A window refuses its slot, which Arbor could not know, and the room it takes costs the Desktop that was to come. The window
  /// that left its slot has its own size all the same, and has still moved once.
  @Test func aSlotThatIsRefusedCostsAWindowThatLeavesItsSlotNoSecondMove() {
    let h = harness("A", "B")
    #expect(h.run("layout B").ok)
    h.scheduler.advance(by: 2)
    h.system.setMinimumSize(w(101), CGSize(width: 1250, height: 300))
    h.system.clearFrameLog()
    #expect(h.run("layout A | Desktop").ok)
    h.scheduler.advance(by: 2)
    #expect(h.layout?.desktopFrame == nil, "or this tries nothing")
    expectMovedAtMostOnce(h, [w(102)], "layout A | Desktop")
    #expect(h.frame(w(102))?.size == CGSize(width: 640, height: 420), "\(given(h))")
    #expect(h.system.isVisible(w(102)))
  }

  /// A window its user's own hand left hanging over the edge of the screen, where the Desktop still reaches that edge, hangs there
  /// after a line as after every other layout. (It used to be fetched by the line and sent back by the next layout.)
  @Test func aWindowLeftHangingOverTheEdgeOfTheScreenIsNotFetchedAndSentBack() {
    let h = harness("A", "B", "C")
    #expect(h.run("layout A | Desktop").ok)
    let hanging = CGRect(x: 1200, y: 300, width: 400, height: 300)
    h.system.userMove(w(103), to: hanging)
    h.system.clearFrameLog()
    #expect(h.run("layout B | Desktop").ok)
    #expect(h.frame(w(103)) == hanging, "\(given(h))")
    #expect(h.run("dock 101 left").ok)
    #expect(h.frame(w(103)) == hanging, "\(given(h))")
  }

  /// Two walks of the chaos lab's that ended at this: a floating window squeezed twice by one line, and one moved by the width of
  /// the gap when a display came to stand beside its own, which was the first layout after the line.
  @Test(arguments: [
    """
    launch
    open 103 Xcode pid 1004 at 1372 303 824 577 title Draft
    open 104 Mail pid 1002 at -413 158 554.5 698.25 title Untitled
    layout Xcode | Terminal
    """,
    """
    open 104 Music pid 1006 at 638 248 352 519 max 310 1909 title main.swift
    launch
    open 113 Mail pid 1002 at -1019 232 732 742 min 732 742 title Untitled
    layout Preview | (Safari / Music)
    displays side:-1440,109,1440,900:0,0,0,43 main:0,0,1440,900:25,0,0,0* windows-late
    """,
  ])
  func theWalksThatFoundItBreakNeitherRuleAnyMore(script: String) {
    let others = ChaosRunner.knownRules.subtracting(["moved-twice", "left-its-place"])
    #expect(ChaosRunner.replay(ChaosAction.script(script), excusing: others)?.violations.map(\.rule) ?? [] == [])
  }

  /// What is so already is not made so again: the line said a second time moves nothing, docked or floating.
  @Test(arguments: ["A | Desktop | B", "A | B", "B | Desktop", "Desktop | B", "B / Desktop", "Desktop"])
  func theSameLineAgainMovesNothing(line: String) {
    let h = harness("A", "B", "C", "D")
    #expect(h.run("layout \(line)").ok)
    h.scheduler.advance(by: 2)
    let frames = [w(101), w(102), w(103), w(104)].map { h.frame($0) }
    h.system.clearFrameLog()
    #expect(h.run("layout \(line)").ok)
    h.scheduler.advance(by: 2)
    #expect(given(h).isEmpty, "layout \(line): \(given(h))")
    #expect([w(101), w(102), w(103), w(104)].map { h.frame($0) } == frames)
  }

  // MARK: The view

  @Test func theViewShowsTheWholeArrangement() {
    let h = harness("Safari", "Mail", "Notes")
    h.run("arrange")
    h.run("save-view 1")
    h.run("zoom 102")
    #expect(h.run("layout Safari | Mail").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  @Test func savedViewsAndHistoryFollowTheSpacesThatStillHoldTheSameWindows() {
    let h = harness("Safari", "Mail", "Notes")
    h.run("layout Safari | (Mail / Notes)")
    h.run("save-view 9")
    h.run("zoom 101")
    h.run("save-view 1")
    h.run("zoom 102")
    h.run("out")
    h.run("save-view 2")
    h.run("show-all")
    // Other sizes, another order, one window fewer in the column.
    #expect(h.run("layout Mail | Safari:2").ok)
    #expect(h.workspace.savedView(slot: 1) == h.workspace.tree.leaf(containing: w(101)))
    #expect(h.workspace.savedView(slot: 9) == h.workspace.tree.root)
    #expect(h.workspace.savedView(slot: 2) == nil, "Mail and Notes are no longer together")
    #expect(h.run("view 1").ok)
    #expect(h.layout?.windowFrames.keys.sorted() == [w(101)])
    h.run("show-all")
    for _ in 1...2 { h.run("back") }
    #expect(h.workspace.tree.contains(h.workspace.camera))
  }

  @Test func backReturnsToWhereTheViewWas() {
    let h = harness("Safari", "Mail")
    h.run("layout Safari | Mail")
    h.run("zoom 102")
    #expect(h.run("layout Safari:3 | Mail").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w(102)))
  }

  @Test func askedForAgainItOnlyLooks() {
    let h = harness("Safari", "Mail", "Notes")
    h.run("layout Safari | (Mail / Notes)")
    h.run("zoom 102")
    h.run("save-view 3")
    let tree = h.workspace.tree
    h.system.clearFrameLog()
    #expect(h.run("layout Safari | (Mail / Notes)").message == "arranged 3 windows")
    #expect(h.workspace.tree == tree)
    #expect(h.workspace.camera == tree.root)
    #expect(h.workspace.savedView(slot: 3) == tree.leaf(containing: w(102)))
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == tree.leaf(containing: w(102)))
  }

  @Test func afterAGapWasDraggedTheLinePutsItBack() throws {
    let h = harness("Safari", "Mail")
    h.run("layout Safari | Mail | Desktop")
    let width = try #require(h.frame(w(101))).width
    h.run("resize 101 right 100")
    #expect(try #require(h.frame(w(101))).width > width + 50)
    h.run("layout Safari | Mail | Desktop")
    #expect(try #require(h.frame(w(101))).width == width)
  }

  @Test func theWindowItWasTypedInStaysInView() throws {
    // The first line a laptop user types, in a Terminal that the line does not mention.
    let h = harness("Safari", "Mail", "Notes", "Terminal")
    h.system.userFocus(w(104))
    #expect(h.run("layout Safari | Mail | Notes").message == "arranged 3 windows")
    #expect(h.system.isVisible(w(104)))
    #expect(h.system.focused == w(104))
    #expect(h.controller.parked.isEmpty)
    // The Desktop that was added is wide enough to use, and the Terminal is on it.
    let desktop = try #require(h.layout?.desktopFrame)
    #expect(desktop.width >= 240 && desktop.width < 260)
    #expect(h.layout?.tiles.isEmpty == true)
    #expect(try #require(h.frame(w(104))).minX >= desktop.minX - 12)
    // The columns share what is left evenly.
    let widths = try [w(101), w(102), w(103)].map { try #require(h.frame($0)).width }
    #expect(widths.max()! - widths.min()! <= 1)
  }

  @Test func withNothingFloatingTheDesktopIsAsNarrowAsArrangeMakesIt() {
    let h = harness("Safari", "Mail", "Notes")
    h.run("layout Safari | Mail | Notes")
    #expect(h.run("layout").text == "Safari | Mail | Notes | Desktop:0.5")
    #expect(h.layout?.desktopFrame == nil)
  }

  @Test func theDesktopIsNotWidenedAtThePriceOfADockedWindow() {
    // Five columns on 1440 points are just usable; a usable Desktop beside them would make tiles of them.
    let h = harness("A", "B", "C", "D", "E", "Terminal")
    h.system.userFocus(w(106))
    let result = h.run("layout A | B | C | D | E")
    #expect(result.ok)
    #expect(h.layout?.windowFrames.count == 5)
    // Even so, what floats stays in view: only a move of the view takes it away.
    #expect(h.system.isVisible(w(106)) && h.system.focused == w(106))
  }

  @Test func aDesktopThatIsMentionedIsAsLargeAsItSays() {
    let h = harness("Safari", "Chrome", "Mail")
    h.system.userFocus(w(103))
    #expect(h.run("layout Safari | Chrome | Desktop:0.01").message == "arranged 2 windows")
    #expect(h.layout?.desktopFrame == nil)
    #expect(h.system.isVisible(w(103)) && h.system.focused == w(103))
  }

  @Test func windowsThatWereOutOfViewComeBackAlsoToADesktopTooSmallToUse() {
    let h = harness("Safari", "Chrome", "Mail", "Notes")
    h.run("layout Safari | Chrome | Desktop")
    h.run("zoom 101")
    #expect(!h.system.isVisible(w(103)) && !h.system.isVisible(w(104)))
    // The Desktop is part of the view again, if only as a tile, so its windows are in view, over the docked ones.
    #expect(h.run("layout Safari | Chrome | Desktop:0.01").message == "arranged 2 windows")
    #expect(h.layout?.desktopFrame == nil)
    #expect(h.system.isVisible(w(103)) && h.system.isVisible(w(104)))
  }

  @Test func theSameLineAgainDoesNotSwapTwoWindowsOfOneApp() {
    let h = harness("Safari", "Safari")
    h.system.userFocus(w(102))
    h.run("layout Safari | Safari")
    #expect(h.workspace.tree.allWindows == [w(102), w(101)])
    h.system.userFocus(w(101))
    h.system.clearFrameLog()
    h.run("layout Safari | Safari")
    #expect(h.workspace.tree.allWindows == [w(102), w(101)])
    #expect(h.system.frameLog.isEmpty)
    // Nor with other sizes.
    h.run("layout Safari:2 | Safari")
    #expect(h.workspace.tree.allWindows == [w(102), w(101)])
  }

  @Test func windowsBehindTabsAreMentioned() {
    let h = harness("Safari", "Safari", "Safari", "Mail")
    #expect(h.run("layout [Safari Mail] | Safari*").message == "arranged 4 windows; 2 windows are behind tabs: ⌘Tab or ⌘` brings one forward")
    #expect(h.run("layout Safari | Mail").message == "arranged 2 windows, floated 2")
    h.system.setMinimized(w(104), true)
    #expect(!h.run("layout [Safari Mail]").message.contains("behind"))
  }

  @Test func anAppWhoseOnlyWindowIsAlreadyPlacedIsNotSaidToHaveNone() {
    let h = harness("Safari", "Mail")
    #expect(h.run("layout 101 | Safari | Mail").message == "arranged 2 windows; only 1 window of Safari")
  }

  @Test func theHelpsExampleWorksWhereNoShellTakesTheQuotesOff() {
    let h = harness("Safari", "Mail", "Notes")
    #expect(h.run("layout \"Safari | Desktop | (Mail / Notes)\"").message == "arranged 3 windows")
    var settings = Settings()
    settings.bindings = ["ctrl+opt+cmd+3": "layout \"Safari | Mail\""]
    #expect(KeyBindings.effective(settings: settings).bindings.contains { $0.command.text == "layout Safari | Mail" })
  }

  @Test func observersHearOfTheNewView() {
    let h = harness("Safari", "Mail")
    var heard: [String] = []
    h.controller.observe { change in
      switch change {
      case .camera: heard.append("camera")
      case .savedViews: heard.append("savedViews")
      case .layout: heard.append("layout")
      default: break
      }
    }
    h.run("layout Safari | Mail")
    #expect(Set(heard) == ["camera", "savedViews", "layout"])
  }

  @Test func theArrangementIsSaved() {
    let h = harness("Safari", "Mail")
    h.run("layout Safari / Mail")
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.tree == h.workspace.tree)
  }

  // MARK: Displays

  func twoDisplays() -> Harness {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    h.system.open(app: "Mail", frame: CGRect(x: 300, y: 150, width: 500, height: 400))
    h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.system.open(app: "Slack", frame: CGRect(x: 1800, y: 150, width: 500, height: 400))
    h.start()
    return h
  }

  @Test func itAppliesToTheDisplayUnderThePointer() {
    let h = twoDisplays()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("layout Notes | Slack").ok)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(103), w(104)])
    #expect(h.workspace.tree.allWindows.isEmpty)
    expectWindowsMatchLayout(h, on: side.id)
  }

  /// `summon` (F53) waits for an app's window too. One window that both are waiting for takes its place in the arrangement, once,
  /// whichever was asked for first, and neither goes on waiting.
  @Test(arguments: [["layout --open Safari | Xcode", "summon Xcode"], ["summon Xcode", "layout --open Safari | Xcode"]])
  func aWindowThatSummonAwaitsAsWellIsNotLost(commands: [String]) throws {
    let h = harness("Safari", "Mail")
    for command in commands { #expect(h.run(command).ok, "\(command)") }
    #expect(h.system.launchedApps == ["Xcode"] && h.system.openRequests == ["Xcode"], "each asks in its own way: behind, and in front")
    let window = h.system.open(app: "Xcode")
    h.scheduler.runPending()
    expectNothingLost(h)
    #expect(h.workspace.tree.allWindows == [w(101), window], "it took the place the line kept for it")
    // Another window of the app is an ordinary new window to both.
    let second = h.system.open(app: "Xcode")
    h.scheduler.runPending()
    expectNothingLost(h)
    #expect(h.workspace.isFloating(second))
  }

  // MARK: What is printed can be read

  /// A line is at most 4096 bytes, and a title is cut by characters: 60 of them are 180 bytes in Chinese or Japanese.
  @Test(arguments: [8, 22, 40, 120]) func manyWindowsWithLongTitlesStillPrintALineThatCanBeRead(count: Int) throws {
    let h = Harness()
    let title = String(repeating: "書類の下書きと会議の記録", count: 10)
    let windows = (0..<count).map { h.system.open(app: "Safari", bundleID: "com.apple.Safari", title: "\($0) \(title)") }
    h.start()
    #expect(h.run("arrange").ok)
    #expect(h.workspace.tree.allWindows.count == count)
    for option in ["", " --titles", " --ids"] {
      let printed = h.run("layout\(option)")
      let line = try #require(printed.text, "layout\(option): \(printed.message)")
      #expect(printed.ok && line.utf8.count <= 4096, "layout\(option) printed \(line.utf8.count) bytes")
      #expect(throws: Never.self, "layout\(option)") { try Command.parse("layout \(line)") }
    }
    // And it puts every window back where it is.
    let before = h.workspace.tree
    let line = try #require(h.run("layout --titles").text)
    #expect(h.run("layout \(line)").ok)
    #expect(h.workspace.tree.allWindows == before.allWindows, "\(windows.count) windows")
  }

  /// A part of a title is looked for anywhere in a title, so the whole of one title can be a part of another's.
  @Test(arguments: [["Inbox", "Inbox (2)", "Re: Inbox"], ["Re: Inbox", "Inbox (2)", "Inbox"], ["1 x", "11 x", "21 x", "111 x"], ["111 x", "21 x", "11 x", "1 x"]])
  func aTitleThatIsPartOfAnotherStillFindsItsOwnWindow(titles: [String]) throws {
    let h = Harness()
    let windows = titles.map { h.system.open(app: "Mail", bundleID: "com.apple.mail", title: $0) }
    h.start()
    #expect(h.run("arrange").ok)
    let line = try #require(h.run("layout --titles").text)
    let places = h.workspace.tree.allWindows
    // Whichever was used last: that is the order in which windows are offered.
    for last in windows {
      h.system.userFocus(last)
      #expect(h.run("float-all").ok && h.run("layout \(line)").ok)
      #expect(h.workspace.tree.allWindows == places, "\(line) after \(last) was used")
    }
  }

  /// Titles are given up a little at a time, so that a line that nearly fits still tells the windows apart.
  @Test func titlesAreShortenedBeforeTheyAreDropped() throws {
    let h = Harness()
    let title = String(repeating: "書類の下書きと会議の記録", count: 10)
    for index in 0..<22 { h.system.open(app: "Safari", bundleID: "com.apple.Safari", title: "\(index) \(title)") }
    h.start()
    h.run("arrange")
    let line = try #require(h.run("layout --titles").text)
    #expect(line.contains("~"), "there are titles in it still")
    #expect(line.contains("21 書類"), "and they begin as the windows' do")
    // A few windows keep all sixty characters.
    let few = Harness()
    few.system.open(app: "Safari", title: "0 \(title)")
    few.start()
    few.run("arrange")
    #expect(try #require(few.run("layout --titles").text).contains(String("0 \(title)".prefix(60))))
  }

  /// `bind` (F12) takes a whole command, and a line has signs of its own in it: `|`, `/` and brackets.
  @Test func bindTakesALineSignsAndAll() throws {
    let h = harness("Safari", "Mail", "Notes")
    let line = "layout Safari | (Mail / Notes)"
    #expect(h.run("bind ctrl+opt+1 \(line)").message == "ctrl+opt+1 runs `\(line)` (it ran `view 1`)")
    let bound = try #require(KeyBindings.effective(settings: h.controller.settings).bindings.first { $0.chord.text == "ctrl+opt+1" })
    #expect(try bound.command == Command.parse(line))
    #expect(h.controller.settings.bindings["ctrl+opt+1"] == .some(line), "as it will stand in settings.json")
    #expect(h.controller.perform(bound.command).ok)
    #expect(h.workspace.tree.allWindows == [w(101), w(102), w(103)])
    #expect(h.run("bind ctrl+opt+2 layout --open Safari~Inbox | Xcode").ok)

    // What is wrong with the line is said as it is anywhere else, and nothing is bound.
    let refused = h.run("bind ctrl+opt+3 layout Safari | | Mail")
    #expect(!refused.ok && refused.message.hasPrefix("layout, column 10: expected an app's name"), "\(refused.message)")
    #expect(!h.run("bind ctrl+opt+3 layout").ok, "a shortcut has nowhere to show a query's answer")
    #expect(KeyBindings.effective(settings: h.controller.settings).bindings.first { $0.chord.text == "ctrl+opt+3" }?.command.text == "view 3")
  }

  @Test func fromAShortcutItAppliesToTheDisplayBeingTypedOn() {
    // As every command that has to choose a display does (F56): the pointer was left on the other one.
    let h = twoDisplays()
    h.system.cursor = CGPoint(x: 400, y: 400)
    h.scheduler.advance(by: 5)
    h.system.userFocus(w(103))
    h.scheduler.advance(by: 1)
    h.system.type()
    h.scheduler.advance(by: 0.3)
    #expect(h.press("layout Notes | Slack").ok)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(103), w(104)])
    #expect(h.workspace.tree.allWindows.isEmpty)
  }

  @Test func anotherDisplayCanBeNamedByNumberOrID() {
    let h = twoDisplays()
    #expect(h.run("layout @2 Notes | Slack").ok)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(103), w(104)])
    #expect(h.run("layout @1 Safari").ok)
    #expect(h.workspace.tree.allWindows == [w(101)])
    #expect(h.run("layout @SIDE Slack").ok)
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(104)])
    #expect(h.run("layout @main Mail").ok)
    #expect(h.workspace.tree.allWindows == [w(102)])
    expectNothingLost(h)
  }

  @Test func displaysAreCountedFromTheMainOneThenFromLeftToRight() {
    let left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: -1000, y: 0, width: 1000, height: 800),
      visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 800), isMain: false)
    let h = Harness(displays: [side, left, FakeWindowSystem.standardDisplay])
    h.system.open(app: "A")
    h.start()
    for (number, display) in [(1, DisplayID("main")), (2, left.id), (3, side.id)] {
      #expect(h.run("layout @\(number) A").ok)
      #expect(h.controller.workspaceID(containing: w(101)) == display)
      #expect(h.run("layout @\(number)").message == "display \(number): 1 docked window")
    }
  }

  @Test(arguments: ["0", "3", "-1", "99999999999999999999", "-9223372036854775808", "9223372036854775807", "nowhere", "1.5", "٢"])
  func aDisplayThatDoesNotExistIsRefused(name: String) {
    let h = twoDisplays()
    let before = h.controller.workspaces
    for command in ["layout @\(name) Safari", "layout @\(name)"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(result.message == "no display \(name); there are 2 displays, counted from @1")
    }
    #expect(h.controller.workspaces == before)
  }

  @Test func windowsComeOverFromOtherDisplays() throws {
    let h = twoDisplays()
    h.run("layout @2 Notes | Slack")
    #expect(h.run("layout @1 Safari | Notes").message == "arranged 2 windows")
    #expect(h.workspace.tree.allWindows == [w(101), w(103)])
    #expect(FakeWindowSystem.standardDisplay.frame.contains(try #require(h.frame(w(103)))))
    // The display it left closes up.
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(104)])
    expectWindowsMatchLayout(h, on: side.id)
    expectWindowsMatchLayout(h, on: h.display)
    expectNothingLost(h)
  }

  @Test func windowsNotMentionedOnOtherDisplaysStayAsTheyAre() {
    let h = twoDisplays()
    h.run("layout @2 Notes | Slack")
    let other = h.controller.workspaces[side.id]
    h.run("layout @1 Safari | Mail")
    #expect(h.controller.workspaces[side.id] == other)
  }

  // MARK: Printing

  @Test func onItsOwnItPrintsTheArrangement() {
    let h = harness("Safari", "Mail", "Notes")
    #expect(h.run("layout").text == "Desktop")
    h.run("dock 101 left")
    h.run("dock 102 right")
    h.run("dock 103 beside 102 bottom")
    let result = h.run("layout")
    #expect(result.ok)
    #expect(result.text == "Safari | Desktop | (Mail / Notes)")
    #expect(result.message == "display 1: 3 docked windows")
  }

  @Test(arguments: [
    "Safari | Desktop | (Mail / Notes)", "Xcode:2 | (Mail / Terminal) | Desktop:0.75", "[Safari Chrome] | Slack | Desktop:0.5", "Desktop | Safari",
    "(Safari / Mail) | Desktop:0.5", "Safari / Desktop / Mail", "Safari | (Mail / (Notes | (Slack / Xcode))) | Desktop:3",
  ]) func whatItPrintsIsWhatWasTyped(line: String) {
    let h = harness("Safari", "Mail", "Notes", "Xcode", "Terminal", "Chrome", "Slack")
    #expect(h.run("layout \(line)").ok)
    #expect(h.run("layout").text == line)
  }

  @Test func theLinePrintedRecreatesTheArrangement() throws {
    let h = harness("Safari", "Mail", "Notes", "Xcode", "Terminal")
    h.run("dock 101 left")
    h.run("dock 102 right")
    h.run("dock 103 beside 102 bottom")
    h.run("dock 104 beside 101 top")
    h.run("resize 101 right 137")
    h.run("resize 103 top -61")
    let line = try #require(h.run("layout").text)
    let frames = h.system.windows.mapValues(\.snapshot.frame)

    h.run("float-all")
    #expect(h.run("layout \(line)").ok)
    for window in [w(101), w(102), w(103), w(104)] {
      #expect(try #require(h.frame(window)).approximatelyEquals(try #require(frames[window]), tolerance: 2), "\(window): \(line)")
    }
    #expect(h.workspace.isFloating(w(105)))
    #expect(h.run("layout").text == line)
  }

  @Test func namesThatNeedQuotesGetThem() {
    let h = Harness()
    h.system.open(app: "Visual Studio Code")
    h.system.open(app: "Desktop")
    h.system.open(app: "2048")
    h.start()
    h.run("arrange")
    #expect(h.run("layout").text == "(\"Visual Studio Code\" / \"Desktop\") | \"2048\" | Desktop:0.5")
    let tree = h.workspace.tree.allWindows
    h.run("float-all")
    h.run("layout (\"Visual Studio Code\" / \"Desktop\") | \"2048\" | Desktop:0.5")
    #expect(h.workspace.tree.allWindows == tree)
  }

  @Test func appsThatShareANameAreWrittenByBundleID() {
    let h = Harness()
    h.system.open(app: "Chrome", bundleID: "com.google.Chrome")
    h.system.open(app: "Chrome", bundleID: "com.google.Chrome.canary")
    h.system.open(app: "Mail", bundleID: "com.apple.mail")
    h.start()
    h.run("layout 102 | 101 | 103 | Desktop")
    #expect(h.run("layout").text == "com.google.Chrome.canary | com.google.Chrome | Mail | Desktop")
    h.run("float-all")
    h.run("layout com.google.Chrome.canary | com.google.Chrome | Mail | Desktop")
    #expect(h.workspace.tree.allWindows == [w(102), w(101), w(103)])
  }

  @Test func aWindowWhoseAppCannotBeWrittenIsWrittenByNumber() {
    let h = Harness()
    h.system.open(app: "", bundleID: "")
    h.system.open(app: "a\u{202E}b", bundleID: "x\ny")
    h.system.open(app: "\u{0}", bundleID: "com.example.ok")
    h.system.open(app: "\u{301}accent", bundleID: "")
    h.start()
    h.run("layout 101 | 102 | 103 | 104 | Desktop")
    #expect(h.run("layout").text == "101 | 102 | com.example.ok | 104 | Desktop")
  }

  @Test func idsSayExactlyWhichWindowGoesWhere() throws {
    let h = harness("Safari", "Safari", "Safari")
    h.run("layout 102 | (103 / 101) | Desktop")
    #expect(h.run("layout").text == "Safari | (Safari / Safari) | Desktop")
    let line = try #require(h.run("layout --ids").text)
    #expect(line == "102 | (103 / 101) | Desktop")
    let tree = h.workspace.tree
    h.system.userFocus(w(101))
    h.run("float-all")
    h.run("layout \(line)")
    #expect(h.workspace.tree == tree)
  }

  @Test func titlesAreWrittenOnlyWhenAskedFor() throws {
    let h = Harness()
    h.system.open(app: "Safari", title: "Secret plans")
    h.system.open(app: "Safari", title: "News: \"today\"")
    h.system.open(app: "Mail", title: String(repeating: "long ", count: 40))
    h.system.open(app: "Notes", title: "")
    h.system.open(app: "Slack", title: "line\nbreak")
    h.start()
    h.run("layout 102 | 101 | 103 | 104 | 105 | Desktop")
    #expect(h.run("layout").text == "Safari | Safari | Mail | Notes | Slack | Desktop")
    let line = try #require(h.run("layout --titles").text)
    #expect(line == "Safari~'News: \"today\"' | Safari~\"Secret plans\" | Mail~\"\(String(repeating: "long ", count: 12))\" | Notes | Slack | Desktop")
    // With them, each window finds its own place again, whichever was used last.
    h.system.userFocus(w(101))
    h.run("float-all")
    h.run("layout \(line)")
    #expect(h.workspace.tree.allWindows == [w(102), w(101), w(103), w(104), w(105)])
  }

  @Test func repliesNeverHoldTitles() {
    let h = Harness()
    h.system.open(app: "Safari", title: "Secret plans")
    h.system.open(app: "Mail", title: "Payroll")
    h.start()
    h.system.setMinimized(w(102), true)
    for command in ["layout Safari~Secret | Mail~Payroll | Notes~Diary", "layout", "layout --titles", "layout --ids", "layout Notes~Diary"] {
      let message = h.run(command).message
      for word in ["Secret", "Payroll", "Diary"] { #expect(!message.contains(word), "\(command): \(message)") }
    }
  }

  @Test func eachDisplayPrintsItsOwn() {
    let h = twoDisplays()
    h.run("layout @1 Safari | Mail")
    h.run("layout @2 Notes / Slack")
    #expect(h.run("layout").text == "Safari | Mail | Desktop:0.5")
    #expect(h.run("layout @2").text == "(Notes / Slack) | Desktop:0.5")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("layout").text == "(Notes / Slack) | Desktop:0.5")
  }

  // MARK: When it cannot act

  @Test func beforeArborRunsAndWhilePausedItSaysSo() {
    let h = Harness()
    h.system.open(app: "Safari")
    #expect(!h.run("layout Safari").ok)
    #expect(!h.run("layout").ok)
    h.start()
    h.run("layout Safari")
    h.run("pause")
    for command in ["layout Safari", "layout"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(result.message.hasPrefix("paused"))
    }
    h.run("resume")
    #expect(h.run("layout").text == "Safari | Desktop:0.5")
  }

  @Test func notWhileAWindowIsInTheHand() {
    let h = harness("Safari", "Mail")
    h.system.mouseDown = true
    h.controller.dragBegan(w(101), at: CGPoint(x: 600, y: 210))
    let result = h.run("layout Safari | Mail")
    #expect(!result.ok)
    #expect(result.message == "cannot arrange while a window is being dragged")
    h.system.mouseDown = false
    h.controller.dragEnded(w(101), at: CGPoint(x: 600, y: 400))
    #expect(h.run("layout Safari | Mail").ok)
  }

  @Test func aWindowThatClosesAfterwardsLeavesASoundTree() {
    let h = harness("Safari", "Mail", "Notes")
    h.run("layout Safari | (Mail / Notes)")
    h.system.close(w(102))
    h.system.close(w(101))
    #expect(h.run("layout").text == "Notes | Desktop:0.5")
    expectNothingLost(h)
  }

  // MARK: Shortcuts and URLs

  @Test func aShortcutCanHoldALine() throws {
    var settings = Settings()
    settings.bindings = [
      "ctrl+opt+1": "layout Safari | (Mail / 'Visual Studio Code')", "ctrl+opt+2": "layout", "ctrl+opt+3": "layout Safari | Mail / Notes",
    ]
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    #expect(bindings.contains { $0.command.text == "layout Safari | (Mail / \"Visual Studio Code\")" })
    #expect(problems.count == 2)
    #expect(problems[0].contains("is a query"))
    #expect(problems[1].contains("column 15"))
  }

  @Test func aURLArranges() throws {
    let h = harness("Safari", "Mail", "Notes")
    let command = try h.controller.admit(url: "arbor://layout/Safari%20%7C%20(Mail%20%2F%20Notes)").get()
    #expect(h.controller.perform(command).ok)
    #expect(h.run("layout").text == "Safari | (Mail / Notes) | Desktop:0.5")
  }

  @Test(arguments: ["arbor://layout/--open%20Safari", "arbor://layout", "arbor://layout/--ids"])
  func aURLNeitherOpensAppsNorAsks(url: String) throws {
    let h = harness("Mail")
    guard case .failure(let error) = h.controller.admit(url: url) else {
      Issue.record("\(url) was admitted")
      return
    }
    #expect(error.description.contains("`layout\(url.contains("open") ? " --open" : "")` is not accepted from URLs"))
    var settings = Settings()
    settings.allowAllURLCommands = true
    h.controller.apply(settings: settings)
    #expect(throws: Never.self) { try h.controller.admit(url: url).get() }
  }

  @Test func aURLMayNotFloatEverythingByAnotherName() {
    let h = harness("Safari")
    h.run("layout Safari")
    h.run("save-view 1")
    let before = h.workspace
    guard case .failure(let error) = h.controller.admit(url: "arbor://layout/Desktop") else {
      Issue.record("admitted")
      return
    }
    #expect(error.description.hasPrefix("`layout` without a window, which floats everything like `float-all` is not accepted from URLs"))
    #expect(h.workspace == before)
  }

  @Test func aURLThatIsRefusedLeavesNoPartOfATitleInTheLog() throws {
    // The reason quotes the line around the mistake, and a line can hold part of a title after `~`.
    // The real log file, which every test writes to: a word nobody else uses.
    let h = harness("Safari")
    guard case .failure(let error) = h.controller.admit(url: "arbor://layout/Safari~Quetzalcoatl%20%7C%20%7C") else {
      Issue.record("admitted")
      return
    }
    #expect(error.description.contains("Quetzalcoatl"), "whoever sent the URL is shown where the mistake is")
    let log =
      ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    #expect(!log.contains("Quetzalcoatl"))
    #expect(log.contains("refused a URL, arbor://layout…"))
  }

  // MARK: Places kept for windows that are not there yet

  /// Arbor starts with a saved arrangement of Safari and Mail, and only Safari is open yet.
  func afterALogin() -> Harness {
    let first = harness("Safari", "Mail")
    first.run("layout Safari | Mail")
    first.controller.saveNow()
    let h = Harness(saved: first.store.saved)
    h.system.open(app: "Safari", title: "Safari 101")
    h.start()
    return h
  }

  @Test func aKeptPlaceIsPrintedByItsApp() {
    let h = afterALogin()
    #expect(h.run("layout").text == "Safari | com.example.mail | Desktop:0.5")
    #expect(h.run("layout --ids").text == "101 | com.example.mail | Desktop:0.5")
    #expect(h.run("layout --titles").text == "Safari~\"Safari 101\" | com.example.mail | Desktop:0.5")
  }

  @Test func arrangingDropsThePlacesThatWereKept() {
    let h = afterALogin()
    #expect(h.run("layout Safari").message == "arranged 1 window")
    #expect(h.workspace.allWindows == [w(101)])
    #expect(h.run("layout").text == "Safari | Desktop:0.5")
    expectNothingLost(h)
    // But not when the line finds nothing and nothing changes.
    let other = afterALogin()
    let before = other.workspace
    #expect(!other.run("layout Sfari").ok)
    #expect(other.workspace == before)
  }

  // MARK: Opening apps

  @Test func withoutTheOptionNothingIsOpened() {
    let h = harness("Safari")
    h.run("layout Safari | Mail")
    #expect(h.system.launchedApps.isEmpty)
    // And a Mail window that happens to open later floats like any other.
    let mail = h.system.open(app: "Mail")
    #expect(h.workspace.isFloating(mail))
  }

  @Test func missingAppsAreOpenedAndJoinWhenTheirWindowAppears() throws {
    let h = harness("Safari", "Notes")
    let result = h.run("layout --open Safari | Desktop | (Mail / Notes) | Slack")
    #expect(result.message == "arranged 2 windows; opening Mail and Slack")
    #expect(h.system.launchedApps == ["Mail", "Slack"])
    #expect(h.run("layout").text == "Safari | Desktop | Notes")

    let slack = h.system.open(app: "Slack")
    #expect(h.run("layout").text == "Safari | Desktop | Notes | Slack")
    let mail = h.system.open(app: "Mail")
    #expect(h.run("layout").text == "Safari | Desktop | (Mail / Notes) | Slack")
    #expect(h.workspace.tree.allWindows == [w(101), mail, w(102), slack])
    expectWindowsMatchLayout(h, on: h.display)
    expectNothingLost(h)

    // Exactly what the line gives when everything is open from the start.
    let frames = h.system.windows.mapValues(\.snapshot.frame)
    h.run("float-all")
    h.run("layout Safari | Desktop | (Mail / Notes) | Slack")
    #expect(h.system.windows.mapValues(\.snapshot.frame) == frames)
  }

  @Test func appsThatHaveAWindowAreNotOpened() {
    let h = harness("Safari", "Mail")
    #expect(h.run("layout --open Safari | Mail").message == "arranged 2 windows")
    #expect(h.system.launchedApps.isEmpty)
  }

  @Test func everythingCanBeOpenedFromNothing() {
    let h = harness()
    #expect(h.run("layout --open Safari | (Mail / Notes)").message == "arranged 0 windows; opening Safari, Mail and Notes")
    h.system.open(app: "Notes")
    h.system.open(app: "Safari")
    h.system.open(app: "Mail")
    #expect(h.run("layout").text == "Safari | (Mail / Notes) | Desktop:0.5")
  }

  @Test func anAppThatCannotBeOpenedIsReportedAsMissing() {
    let h = harness("Safari")
    h.system.unlaunchableApps = ["Mial"]
    #expect(h.run("layout --open Safari | Mial | Notes").message == "arranged 1 window; no window of Mial; opening Notes")
    let before = h.workspace
    let result = h.run("layout --open Mial")
    #expect(!result.ok)
    #expect(result.message == "no window of Mial; nothing changed")
    #expect(h.workspace == before)
  }

  @Test func onlySoManyAppsAreOpenedAtOnce() {
    let h = harness()
    let names = (1...40).map { "App\($0)" }
    let result = h.run("layout --open " + names.joined(separator: " | "))
    #expect(h.system.launchedApps == Array(names.prefix(12)))
    #expect(result.message.hasPrefix("arranged 0 windows; no window of App13, App14, App15, App16 or 24 more; opening App1, "))
  }

  @Test func theViewStaysWhereItIsWhenALatecomerArrives() throws {
    let h = harness("Safari", "Notes")
    h.run("layout --open Safari | (Mail / Notes)")
    h.run("save-view 2")
    h.run("zoom 101")
    let camera = h.workspace.camera
    let frame = h.frame(w(101))
    let mail = openInBackground(h, "Mail")
    #expect(h.workspace.camera == camera)
    #expect(h.workspace.tree.leaf(containing: w(101)) == camera)
    #expect(h.frame(w(101)) == frame)
    // It took its place out of view.
    #expect(h.workspace.isDocked(mail) && !h.system.isVisible(mail))
    #expect(h.run("back").ok)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(h.workspace.savedView(slot: 2) == h.workspace.tree.root)
    #expect(h.run("layout").text == "Safari | (Mail / Notes) | Desktop:0.5")
  }

  @Test func aLatecomerThatTakesTheKeyboardIsFollowedLikeAnyWindow() {
    // Opened by hand meanwhile, in front: the view goes where the keyboard goes.
    let h = harness("Safari", "Notes")
    h.run("layout --open Safari | (Mail / Notes)")
    h.run("zoom 101")
    let mail = h.system.open(app: "Mail")
    #expect(h.workspace.isDocked(mail) && h.system.isVisible(mail))
    #expect(h.run("layout").text == "Safari | (Mail / Notes) | Desktop:0.5")
  }

  @Test func aLatecomerJoinsItsTabGroupWithoutTakingItOver() throws {
    let h = harness("Safari", "Mail")
    h.run("layout --open [Safari Chrome Mail] | Desktop")
    h.system.userFocus(w(102))
    let chrome = openInBackground(h, "Chrome")
    let leaf = try #require(h.workspace.tree.leaf(containing: chrome))
    #expect(h.workspace.tree[leaf]?.kind == .stack(windows: [w(101), chrome, w(102)], active: 2))
  }

  @Test func aSecondWindowOfAnAppIsWaitedForToo() {
    let h = harness("Safari")
    #expect(h.run("layout --open Safari | Safari").message == "arranged 1 window; only 1 window of Safari")
    #expect(h.system.launchedApps.isEmpty)
    let second = h.system.open(app: "Safari")
    #expect(h.workspace.tree.allWindows == [w(101), second])
    // Both slots are taken now.
    #expect(floats(h, "Safari"))
  }

  @Test func aLatecomerWithTheTitleAskedForGetsThatSlot() {
    let h = harness()
    h.run("layout --open Safari~Docs | Safari~Inbox")
    let inbox = h.system.open(app: "Safari", title: "Inbox")
    let other = h.system.open(app: "Safari", title: "News")
    #expect(h.workspace.tree.allWindows == [other, inbox])
  }

  @Test func otherAppsWindowsFloatAsUsual() {
    let h = harness("Safari")
    h.run("layout --open Safari | Mail")
    #expect(floats(h, "Notes"))
    #expect(docks(h, "Mail"))
  }

  @Test func theArrangementComesBeforeARuleButNotBeforeIgnore() {
    var settings = Settings()
    settings.rules = [
      AppRule(app: "com.example.mail", action: .dock(.top)), AppRule(app: "com.example.notes", action: .ignore),
    ]
    let h = harness("Safari", settings: settings)
    h.run("layout --open Safari | Mail | Notes | Desktop")
    h.system.open(app: "Mail")
    #expect(h.run("layout").text == "Safari | Mail | Desktop")
    let notes = h.system.open(app: "Notes")
    #expect(h.controller.workspaceID(containing: notes) == nil)
    // Once the slot is filled, the rule is back in charge.
    h.system.open(app: "Mail")
    #expect(h.run("layout").text == "Mail / (Safari | Mail | Desktop)")
  }

  @Test func itStopsWaitingAfterAMinute() {
    let h = harness("Safari")
    h.run("layout --open Safari | Mail | Notes")
    h.scheduler.advance(by: 59)
    #expect(docks(h, "Mail"))
    h.scheduler.advance(by: 2)
    #expect(floats(h, "Notes"))
  }

  @Test func itStopsWaitingOnceTheUserRearranges() {
    for change in ["dock 102 left", "float 101", "resize 101 right 50", "arrange", "float-all", "layout Safari", "layout Safari | Mail | Desktop"] {
      let h = harness("Safari", "Notes", "Xcode")
      h.run("layout --open Safari | Xcode | Mail | Desktop")
      #expect(h.run(change).ok, "\(change)")
      let tree = h.workspace.tree
      #expect(floats(h, "Mail"), "\(change)")
      #expect(h.workspace.tree == tree, "\(change)")
    }
  }

  @Test func lookingAroundIsNotRearranging() {
    let h = harness("Safari", "Notes", "Xcode")
    h.run("layout --open [Safari Notes] | Xcode | Mail | Desktop")
    for look in ["zoom 103", "out", "desktop", "show-all", "save-view 1"] { #expect(h.run(look).ok, "\(look)") }
    h.system.userFocus(w(102))
    h.system.setMinimized(w(103), true)
    #expect(docks(h, "Mail"))
    #expect(h.run("layout").text == "[Safari Notes] | Xcode | Mail | Desktop")
  }

  @Test func aSplashScreenThatClosesLeavesTheSlotForTheRealWindow() {
    let h = harness("Safari")
    h.run("layout --open Safari | (Mail / Notes) | Desktop")
    let splash = h.system.open(app: "Mail", title: "Loading…")
    #expect(h.workspace.isDocked(splash))
    h.system.close(splash)
    let real = h.system.open(app: "Mail")
    h.system.open(app: "Notes")
    #expect(h.workspace.isDocked(real))
    #expect(h.run("layout").text == "Safari | (Mail / Notes) | Desktop")
    expectNothingLost(h)
  }

  @Test func aWindowThatWasPlacedAndClosesDoesNotEndTheWait() {
    let h = harness("Safari", "Notes")
    h.run("layout --open Safari | Mail | Notes | Desktop")
    h.system.close(w(102))
    #expect(docks(h, "Mail"))
    #expect(h.run("layout").text == "Safari | Mail | Desktop")
    // Its slot is free again as well.
    #expect(docks(h, "Notes"))
    #expect(h.run("layout").text == "Safari | Mail | Notes | Desktop")
  }

  @Test func pausingAndQuittingEndTheWait() {
    let h = harness("Safari")
    h.run("layout --open Safari | Mail")
    h.run("pause")
    #expect(!h.scheduler.pendingKeys.contains("layout-open main"))
    h.run("resume")
    #expect(floats(h, "Mail"))

    h.run("layout --open Safari | Notes")
    #expect(h.scheduler.pendingKeys.contains("layout-open main"))
    h.controller.shutdown()
    #expect(!h.scheduler.pendingKeys.contains("layout-open main"))
  }

  @Test func eachDisplayWaitsForItsOwn() {
    let h = twoDisplays()
    h.run("layout @1 --open Safari | Xcode")
    h.run("layout @2 --open Notes | Terminal")
    let terminal = h.system.open(app: "Terminal")
    let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 1700, y: 100, width: 400, height: 300))
    #expect(h.controller.workspaces[side.id]?.tree.allWindows == [w(103), terminal])
    #expect(h.workspace.tree.allWindows == [w(101), xcode])
    expectNothingLost(h)
    expectWindowsMatchLayout(h, on: h.display)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func aDisplayThatGoesAwayTakesItsWaitWithIt() {
    let h = twoDisplays()
    h.run("layout @2 --open Notes | Terminal")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    let terminal = h.system.open(app: "Terminal")
    #expect(h.workspace.isFloating(terminal))
    expectNothingLost(h)
  }

  // MARK: Hostile input

  @Test func noLineLosesAWindowOrBreaksATree() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    for app in ["Safari", "Safari", "Mail", "Notes", "Visual Studio Code", "Desktop", "412"] { h.system.open(app: app) }
    h.system.open(app: "Slack", frame: CGRect(x: 1700, y: 100, width: 400, height: 300))
    h.start()
    let pieces = [
      "Safari", "Safari*", "Mail", "Notes", "\"Visual Studio Code\"", "Code", "\"Desktop\"", "Desktop", "\"412\"", "412", "101", "w103", "108", "Slack", "Zed",
      "|", "|", "/", "/", "(", ")", "[", "]", ":2", ":0.001", ":1000", "~Safari", "*", "@1", "@2", "@3", "--open", "--ids", " ",
    ]
    var state: UInt64 = 54
    func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    var arranged = 0
    for round in 0..<4000 {
      let line = (0..<(1 + next(9))).map { _ in pieces[next(pieces.count)] }.joined(separator: " ")
      if h.run("layout \(line)").ok { arranged += 1 }
      if round % 7 == 0 { h.run(["zoom 101", "out", "float 103", "dock 104 left", "arrange", "desktop"][next(6)]) }
      if round % 97 == 0 { h.system.close(h.system.open(app: ["Zed", "Safari", "Mail"][next(3)])) }
      if round % 50 == 0 { expectNothingLost(h) }
    }
    expectNothingLost(h)
    #expect(arranged > 300)
    // What is on screen is what the layouts say.
    h.run("home")
    expectWindowsMatchLayout(h, on: h.display)
    expectWindowsMatchLayout(h, on: side.id)
  }
}
