import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The built-in display of a laptop, and the display on the desk that is used with the lid shut: never both at once.
private let lap = DisplaySnapshot(
  id: DisplayID("lap"), frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
  visibleFrame: CGRect(x: 0, y: 37, width: 1512, height: 945), isMain: true)
private let desk = DisplaySnapshot(
  id: DisplayID("desk"), frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
/// A second display to the right of the laptop's own.
private let beside = DisplaySnapshot(
  id: DisplayID("beside"), frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
  visibleFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080), isMain: false)

/// **A frame a person gives a window while Arbor is paused, or not running, is its own from then on** (collab/QUESTIONS.md: Q16, Q20, Q21,
/// and the product owner's note of 2026-10-15 on F48 and rule 5, whose sentence this is). Two rules come of it for floating windows
/// (`Controller+FoundAtAStart.swift`): a display that is back fetches none that is in view; and one that somebody has touched since
/// Arbor let go of it has the frame it is found at for its own, so that is where, and how large, it comes back from then on.
/// A window that nobody has touched, or of which nobody can tell, keeps what is remembered: it may be as small as Arbor had squeezed it.
///
/// What was docked is docked again, one move each (Q16), also on a display that was away when Arbor quit and is back.
@Suite @MainActor struct FoundAtAStartTests {
  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  func newProcess(after old: Harness, byTheWatchdog: Bool = false) -> Harness {
    let new = old.newProcess(byTheWatchdog: byTheWatchdog)
    new.system.clearFrameLog()
    return new
  }

  func moves(of window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  func home(of window: WindowID, _ h: Harness) -> DisplayID? { h.controller.workspaceID(containing: window) }

  func remembered(_ window: WindowID, _ h: Harness) -> CGRect? {
    home(of: window, h).flatMap { h.controller.workspaces[$0]?.floating[window] }
  }

  /// The view goes to `docked` alone, which takes what floats out of view, and comes back.
  func frameAndShowEverything(_ h: Harness, _ docked: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    h.system.userFocus(docked)
    #expect(h.run("zoom").ok, sourceLocation: sourceLocation)
    settle(h)
    #expect(h.controller.workspaces.values.contains { $0.camera != $0.tree.root }, "the view is on one window", sourceLocation: sourceLocation)
    #expect(h.run("show-all").ok, sourceLocation: sourceLocation)
    settle(h)
  }

  // MARK: As the walks found it

  /// The scripts of the find, word for word. The rule that speaks depends on whether anything is docked, and one of the two is
  /// excused elsewhere for another story, so neither is excused here.
  @Test(arguments: [
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 102 Notes pid 1001 at 300 200 720 420 min 709 300
    displays side:0,0,2560,1440:25,0,0,0* windows-late
    settle
    quit
    displays main:0,0,1512,982:37,0,0,0* windows-first
    move 102 500 400 720 420
    launch
    """,
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Safari pid 1000 at 100 100 700 500 min 574 240
    open 102 Notes pid 1001 at 300 200 720 420 min 709 300
    dock 101 left
    settle
    displays side:0,0,2560,1440:25,0,0,0* windows-late
    settle
    move 102 1500 700 720 420
    settle
    quit
    displays main:0,0,1512,982:37,0,0,0* windows-first
    move 102 500 400 720 420
    launch
    settle
    """,
  ])
  func quitAtTheDeskStartedOnTheLap(script: String) {
    expectItStaysWhereItWasPut(script, WindowID(102))
  }

  /// Plays `script`, in which no rule may break, and expects `window` to end where it was before Arbor last came back.
  func expectItStaysWhereItWasPut(_ script: String, _ window: WindowID, sourceLocation: SourceLocation = #_sourceLocation) {
    let runner = ChaosRunner()
    var put: CGRect?
    for action in ChaosAction.script(script) {
      if ["launch", "resume"].contains(action.text) { put = runner.system.frame(of: window) }
      let broken = runner.step(action)
      #expect(broken.isEmpty, "\(action.text): \(broken)", sourceLocation: sourceLocation)
    }
    #expect(put != nil && runner.system.frame(of: window) == put, "\(String(describing: put))", sourceLocation: sourceLocation)
  }

  /// One display, nothing ever docked: no jump at the start, but the next ⌃⌥0 threw the window back to where it stood in the last run.
  /// And the first find again, as another walk met it.
  @Test(arguments: [
    (
      115 as UInt32,
      """
      launch
      open 115 Finder pid 1005 at 162 300 508 280
      settle
      quit
      grab 115
      carry 900 500
      release
      launch
      settle
      key down home
      key up home
      settle
      """
    ),
    (
      102,
      """
      displays main:0,0,1440,900:25,0,0,70* windows-never
      open 102 Notes pid 1001 at 650 300 720 420
      launch
      settle
      displays side:0,0,1920,1080:25,0,0,0* windows-first
      settle
      quit
      displays main:0,0,1440,900:25,0,0,70* windows-first
      move 102 50 400 720 420
      launch
      settle
      """
    ),
    // Kept in view, and made narrower by an edge while Arbor was away: it was blown up to the width of before.
    (
      106,
      """
      launch
      open 106 Xcode pid 1004 at 300 150 840 440
      pin 106
      settle
      pause
      edge 106 300 150 600 440
      resume
      settle
      """
    ),
    (
      106,
      """
      launch
      open 106 Xcode pid 1004 at 300 150 840 440
      pin 106
      settle
      quit
      edge 106 300 150 600 440
      launch
      settle
      """
    ),
  ])
  func asOtherWalksMetTheSameRoot(window: UInt32, script: String) {
    expectItStaysWhereItWasPut(script, WindowID(window))
  }

  /// The find's controls, which held before and must go on holding.
  @Test(arguments: [
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 102 Notes pid 1001 at 300 200 720 420 min 709 300
    displays side:0,0,2560,1440:25,0,0,0* windows-late
    settle
    displays main:0,0,1512,982:37,0,0,0* windows-late
    settle
    move 102 500 400 720 420
    settle
    quit
    launch
    """,
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 102 Notes pid 1001 at 300 200 720 420 min 709 300
    settle
    quit
    move 102 500 400 720 420
    launch
    """,
  ])
  func theControlsOfThatFind(script: String) {
    expectItStaysWhereItWasPut(script, WindowID(102))
  }

  // MARK: The display is another than at the quit

  /// On the lap in the morning, at the desk by day, where Arbor is quit; on the lap again in the evening.
  /// - Returns: a new process that has not started yet, with the windows where macOS or their person put them meanwhile.
  func homeFromTheDesk(docking: Bool) -> (h: Harness, editor: WindowID, notes: WindowID) {
    let old = Harness(displays: [lap])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 720, height: 420))
    old.start()
    if docking { old.run("dock \(editor.rawValue) left") }
    settle(old)
    old.system.setDisplays([desk])
    settle(old)
    old.system.userMove(notes, to: CGRect(x: 1500, y: 700, width: 720, height: 420))
    settle(old)
    old.controller.shutdown()
    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    return (h, editor, notes)
  }

  @Test(arguments: [false, true])
  func aFloatingWindowPlacedWhileArborWasAwayStaysThereThoughItsDisplayRemembersAnotherPlace(docking: Bool) {
    let (h, editor, notes) = homeFromTheDesk(docking: docking)
    let chosen = CGRect(x: 500, y: 400, width: 720, height: 420)
    h.system.place(editor, at: CGRect(x: 100, y: 88, width: 700, height: 500))
    h.system.place(notes, at: chosen)
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "it floats, and it was in view: \(h.system.frameLog)")
    #expect(h.frame(notes) == chosen)
    #expect(remembered(notes, h) == chosen, "from now on this is its place")
    #expect(!h.controller.parked.contains(notes))
    // What was docked on this display is docked again, in one move (Q16).
    #expect(h.workspace.isDocked(editor) == docking)
    #expect(h.movesInStep[editor] ?? 0 == (docking ? 1 : 0), "\(h.system.frameLog)")
    expectWindowsMatchLayout(h)
  }

  @Test func whereItWasFoundIsWhereItComesBackTo() {
    let (h, editor, notes) = homeFromTheDesk(docking: true)
    // Clear of the docked window, so that nothing has a reason to push it aside.
    let chosen = CGRect(x: 780, y: 500, width: 720, height: 420)
    h.system.place(notes, at: chosen)
    h.start()
    settle(h)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen, "there and back is nothing")
  }

  /// The display beside the laptop was unplugged when Arbor quit and is plugged in again when it starts. macOS may or may not have
  /// sent the window back there; its person has it on the laptop's own display.
  @Test func aDisplayThatIsBackDoesNotFetchWhatFloatsOnAnother() {
    let old = Harness(displays: [lap, beside])
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 1800, y: 200, width: 720, height: 420))
    old.start()
    settle(old)
    old.system.setDisplays([lap])
    settle(old)
    old.controller.shutdown()

    let h = newProcess(after: old)
    h.system.setDisplays([lap, beside])
    let chosen = CGRect(x: 500, y: 400, width: 720, height: 420)
    h.system.place(notes, at: chosen)
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(home(of: notes, h) == lap.id, "it floats where it is")
    #expect(remembered(notes, h) == chosen)
  }

  /// Docked at the desk, where Arbor is quit; started on the lap. There is no arrangement to bring back on this display: what was docked
  /// floats where it is found, and no frame is set. Plugged in again, the desk's display has its arrangement (Q16).
  @Test func whatWasDockedOnADisplayThatIsMissingFloatsWhereItIsFoundAndGoesBackWithItsDisplay() {
    let old = Harness(displays: [desk])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 1500, y: 700, width: 720, height: 420))
    old.start()
    old.run("dock \(editor.rawValue) left")
    settle(old)
    old.controller.shutdown()

    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    let (editorFound, notesFound) = (CGRect(x: 100, y: 100, width: 700, height: 500), CGRect(x: 600, y: 450, width: 720, height: 420))
    h.system.place(editor, at: editorFound)
    h.system.place(notes, at: notesFound)
    h.start()
    settle(h)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(remembered(editor, h) == editorFound && remembered(notes, h) == notesFound)

    h.system.setDisplays([desk])
    settle(h)
    #expect(h.controller.workspaces[desk.id]?.isDocked(editor) == true)
    expectWindowsMatchLayout(h)
  }

  /// The same evening, but Arbor did not quit at the desk: it was killed. A display that is back fetches no floating window that is in view,
  /// whoever ended the last run.
  @Test(arguments: [false, true])
  func afterARunThatDidNotQuitAFloatingWindowInViewIsNotFetchedEither(byTheWatchdog: Bool) {
    let old = Harness(displays: [lap])
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 720, height: 420))
    old.start()
    settle(old)
    old.system.setDisplays([desk])
    settle(old)
    old.controller.saveNow()
    let h = newProcess(after: old, byTheWatchdog: byTheWatchdog)
    h.system.setDisplays([lap])
    let found = CGRect(x: 500, y: 400, width: 720, height: 420)
    h.system.place(notes, at: found)
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == found)
    #expect(!h.controller.parked.contains(notes))
  }

  /// A display beside the laptop goes, Arbor squeezes what came over from it onto a narrow Desktop and is killed. The display is back
  /// when a person starts Arbor. The window is not fetched, it floats where it is, and its own size is still known there.
  @Test func afterARunThatDidNotQuitADisplayThatIsBackFetchesNothingAndWhatIsRememberedStands() throws {
    let old = Harness(displays: [lap, beside])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let browser = old.system.open(app: "Browser", pid: 1003, frame: CGRect(x: 200, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 1800, y: 200, width: 900, height: 420))
    old.start()
    old.system.cursor = CGPoint(x: 400, y: 400)
    old.run("dock \(editor.rawValue) left")
    old.run("dock \(browser.rawValue) right")
    settle(old)
    old.system.setDisplays([lap])
    settle(old)
    let own = try #require(remembered(notes, old))
    let squeezed = try #require(old.frame(notes))
    try #require(squeezed.width < own.width, "\(squeezed)")
    old.controller.saveNow()

    let h = newProcess(after: old)
    h.system.setDisplays([lap, beside])
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(home(of: notes, h) == lap.id)
    #expect(remembered(notes, h) == own)
  }

  /// Killed, and the window taken to the other display before Arbor is started: it floats where it is.
  @Test func afterARunThatDidNotQuitAWindowFoundOnAnotherDisplayFloatsThere() {
    let (old, editor, notes) = editorDockedNotesFloating(displays: [lap, beside])
    old.controller.saveNow()
    let h = newProcess(after: old)
    h.system.place(notes, at: CGRect(x: 1900, y: 300, width: 600, height: 420))
    h.start()
    settle(h)
    #expect(home(of: notes, h) == beside.id)
    h.system.clearFrameLog()
    frameAndShowEverything(h, editor)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
  }

  /// 720 wide on the lap in the morning, made 500 wide at the desk, where Arbor is quit. What the lap's display remembers is the older of the
  /// two: in the evening the window is 500 wide, and stays so.
  @Test func theSizeOfThisMorningDoesNotComeBackWithItsDisplay() {
    let old = Harness(displays: [lap])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 780, y: 200, width: 720, height: 420))
    old.start()
    old.run("dock \(editor.rawValue) left")
    settle(old)
    old.system.setDisplays([desk])
    settle(old)
    // Where it also fits on the lap, so that nothing has a reason to move it when the displays change.
    let small = CGRect(x: 800, y: 300, width: 500, height: 300)
    old.system.userMove(notes, to: small)
    settle(old)
    old.controller.shutdown()
    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h) == small)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == small)
  }

  /// Squeezed at the desk, where Arbor is killed; started on the lap. The display it floated on is not there, so it is taken in afresh where it
  /// is found, but its own size is not forgotten.
  @Test func squeezedOnADisplayThatIsGoneItsOwnSizeIsStillKnown() throws {
    let old = Harness(displays: [desk])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let browser = old.system.open(app: "Browser", pid: 1003, frame: CGRect(x: 200, y: 100, width: 700, height: 500))
    let own = CGRect(x: 300, y: 200, width: 1200, height: 420)
    let notes = old.system.open(app: "Notes", pid: 1002, frame: own)
    old.start()
    old.system.userMove(notes, to: own.offsetBy(dx: 10, dy: 0))
    old.run("dock \(editor.rawValue) left")
    old.run("dock \(browser.rawValue) right")
    settle(old)
    let narrow = try #require(old.frame(notes))
    try #require(narrow.width < own.width, "\(narrow)")
    old.controller.saveNow()
    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    // Near the right edge, where there is room for it as it is and not for its own width.
    h.system.place(notes, at: CGRect(x: lap.frame.maxX - narrow.width - 20, y: 200, width: narrow.width, height: narrow.height))
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h)?.size == own.size)
    #expect(remembered(notes, h).map { lap.visibleFrame.contains($0) } == true, "it does not grow over the edge: \(String(describing: remembered(notes, h)))")
  }

  /// Docked at the desk, where Arbor is killed; started on the lap, where the window is found in the shape of its slot. There is nothing to
  /// dock it in here, so it floats, and the size it floated at before it was docked is its own.
  @Test func dockedOnADisplayThatIsGoneAndFoundInTheShapeOfItsSlotItsOwnSizeIsStillKnown() throws {
    let old = Harness(displays: [desk])
    let own = CGRect(x: 300, y: 200, width: 720, height: 420)
    let notes = old.system.open(app: "Notes", pid: 1002, frame: own)
    old.start()
    old.run("dock \(notes.rawValue) left")
    settle(old)
    let slot = try #require(old.frame(notes))
    try #require(slot.height > own.height)
    old.controller.saveNow()
    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    h.system.place(notes, at: CGRect(x: 12, y: 49, width: slot.width, height: 900))
    h.start()
    settle(h)
    #expect(remembered(notes, h)?.size == own.size)
    h.controller.shutdown()
    #expect(h.frame(notes)?.size == own.size, "a quit gives it back (rule 5)")
  }

  /// After a restart of the Mac a number can belong to another window. What was remembered under it says nothing of this one.
  @Test(arguments: [false, true])
  func aNumberThatNowBelongsToAnotherAppBringsNoSizeWithIt(afterAQuit: Bool) {
    let old = Harness(displays: [desk])
    _ = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 1200, height: 700))
    old.start()
    settle(old)
    if afterAQuit { old.controller.shutdown() } else { old.controller.saveNow() }
    let h = Harness(displays: [lap], saved: old.store.saved)
    let found = CGRect(x: 100, y: 200, width: 500, height: 300)
    let other = h.system.open(app: "Mail", pid: 2001, frame: found)
    h.start()
    settle(h)
    #expect(remembered(other, h) == found)
  }

  /// 720 wide on the lap, 1000 wide at the desk, then no display at all, and Arbor is killed. Two displays that are gone remember the window.
  /// The one that went last knows its size.
  /// An arrangement whose date makes no sense is discarded at a launch, so it has no say either, though its date would make it the last.
  @Test(arguments: [false, true])
  func ofTwoDisplaysThatAreGoneTheOneThatWentLastKnowsTheSize(theOlderHasADateThatMakesNoSense: Bool) {
    let old = Harness(displays: [lap])
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 720, height: 420))
    old.start()
    settle(old)
    old.system.setDisplays([desk])
    settle(old)
    old.system.userMove(notes, to: CGRect(x: 300, y: 200, width: 1000, height: 600))
    settle(old)
    old.scheduler.advance(by: 60)
    old.system.setDisplays([])
    settle(old)
    old.controller.saveNow()
    if theOlderHasADateThatMakesNoSense { old.store.saved?.dormant[lap.id]?.since = .distantFuture }
    let h = newProcess(after: old)
    h.system.setDisplays([beside])
    h.system.place(notes, at: CGRect(x: 1800, y: 200, width: 600, height: 400))
    h.start()
    settle(h)
    #expect(remembered(notes, h)?.size == CGSize(width: 1000, height: 600))
  }

  /// Docked and sent to the other display, and Arbor is killed before the half second is over after which that is saved. The file has
  /// the window floating on the first display; it is found on the second, in the shape of a slot. That is not its own size.
  @Test func foundInTheShapeOfASlotTheFileKnowsNothingOfItKeepsItsOwnSize() throws {
    let old = Harness(displays: [lap, beside])
    let own = CGRect(x: 300, y: 200, width: 720, height: 420)
    let notes = old.system.open(app: "Notes", pid: 1002, frame: own)
    old.start()
    settle(old)
    let file = old.store.saved
    old.system.userFocus(notes)
    old.run("dock \(notes.rawValue) left")
    old.run("move-to-display next")
    let slot = try #require(old.frame(notes))
    try #require(beside.frame.contains(slot) && slot.height > own.height, "\(slot)")
    old.store.saved = file
    let h = newProcess(after: old)
    h.start()
    settle(h)
    #expect(remembered(notes, h)?.size == own.size)
    h.controller.shutdown()
    #expect(h.frame(notes)?.size == own.size, "a quit gives it back (rule 5)")
  }

  /// Killed, and the window is found on the other display, hanging over its edge. Nobody can tell that a hand left it there, so when Arbor
  /// next has to place it, it is wholly in view: where in doubt, in view (Q20).
  @Test func afterARunThatDidNotQuitAnOverhangOnAnotherDisplayIsNobodysChoice() {
    let old = Harness(displays: [lap, beside])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 1700, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 600, height: 420))
    old.start()
    old.system.cursor = CGPoint(x: 2000, y: 400)
    old.run("dock \(editor.rawValue) left")
    settle(old)
    old.controller.saveNow()
    let h = newProcess(after: old)
    h.system.place(notes, at: CGRect(x: 3000, y: 300, width: 600, height: 420))
    h.start()
    settle(h)
    #expect(home(of: notes, h) == beside.id)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes).map { beside.frame.contains($0) } == true, "\(String(describing: h.frame(notes)))")
  }

  /// 720 wide on the lap in the morning. At the desk it is made 500 wide and then DOCKED, and Arbor is quit, which gives it its 500 back. What the
  /// lap's display remembers is older than that.
  @Test func theSizeOfThisMorningDoesNotComeBackForAWindowThatWasDockedSince() {
    let old = Harness(displays: [lap])
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 780, y: 200, width: 720, height: 420))
    old.start()
    settle(old)
    old.system.setDisplays([desk])
    settle(old)
    let small = CGRect(x: 800, y: 300, width: 500, height: 300)
    old.system.userMove(notes, to: small)
    settle(old)
    old.run("dock \(notes.rawValue) left")
    settle(old)
    old.controller.shutdown()
    #expect(old.frame(notes) == small)
    let h = newProcess(after: old)
    h.system.setDisplays([lap])
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h) == small)
  }

  /// The second display is to the right at the quit and to the left at the start, and macOS has taken its windows along. That is nobody
  /// touching them: where the quit itself had fetched a window to does not become its own place.
  @Test func aDisplayWhoseCornerMovedWhileArborWasAwayTakesItsWindowsAlongAndNobodyHasTouchedThem() throws {
    let old = Harness(displays: [lap, beside])
    let editor = old.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 1700, y: 100, width: 700, height: 500))
    let notes = old.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 2500, y: 300, width: 600, height: 420))
    old.start()
    old.system.cursor = CGPoint(x: 2000, y: 400)
    old.run("dock \(editor.rawValue) left")
    settle(old)
    // Pushed aside by hand until a third of it shows. The quit brings it wholly into view.
    let aside = CGRect(x: 3232, y: 500, width: 600, height: 420)
    old.system.userMove(notes, to: aside)
    settle(old)
    old.controller.shutdown()
    let fetched = try #require(old.frame(notes))
    try #require(fetched != aside)

    let h = newProcess(after: old)
    let offset = -1920 - beside.frame.minX
    var moved = beside
    moved.frame = beside.frame.offsetBy(dx: offset, dy: 0)
    moved.visibleFrame = beside.visibleFrame.offsetBy(dx: offset, dy: 0)
    h.system.setDisplays([lap, moved])
    for window in [editor, notes] { h.system.place(window, at: h.frame(window)!.offsetBy(dx: offset, dy: 0)) }
    h.start()
    settle(h)
    #expect(remembered(notes, h) == aside.offsetBy(dx: offset, dy: 0), "what is remembered stands, and has gone with its display")
  }

  /// Kept in view, and taken during a pause to a display whose view is on one window. It is kept in view there. It is nobody's guest.
  @Test func whatIsKeptInViewIsNoGuestOfTheViewItWasTakenTo() {
    let h = Harness(displays: [lap, beside])
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 1700, y: 100, width: 700, height: 500))
    let browser = h.system.open(app: "Browser", pid: 1003, frame: CGRect(x: 2400, y: 100, width: 700, height: 500))
    let notes = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 600, height: 420))
    h.start()
    h.run("pin \(notes.rawValue)")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    h.run("pause")
    h.system.userMove(notes, to: CGRect(x: 2000, y: 300, width: 600, height: 420))
    h.run("resume")
    settle(h)
    #expect(h.controller.workspaces[beside.id]?.isPinned(notes) == true)
    #expect(h.controller.workspaces[beside.id]?.guests?[notes] == nil)
  }

  /// Out of view when the pause begins, and its app does not answer. It answers seconds later, and the pause fetches the window after all.
  /// That is still the pause's doing: nobody has touched it.
  @Test func whatThePauseFetchesLateIsStillWhereThePauseLeftIt() throws {
    let (h, editor, notes) = editorDockedNotesFloating()
    // Pushed aside by hand, so that where the pause fetches it to is not where it is remembered.
    let aside = CGRect(x: 1312, y: 500, width: 600, height: 420)
    h.system.userMove(notes, to: aside)
    settle(h)
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    try #require(!h.system.isVisible(notes))
    h.system.setUnresponsive(pid: 1002, true)
    h.run("pause")
    try #require(!h.system.isVisible(notes), "it could not be fetched")
    h.system.setUnresponsive(pid: 1002, false)
    h.scheduler.advance(by: 10)
    let fetched = try #require(h.frame(notes))
    try #require(h.system.isVisible(notes) && fetched != aside, "\(fetched)")
    #expect(h.store.saved?.leftAt?[notes] == fetched)
    h.run("resume")
    settle(h)
    #expect(remembered(notes, h) == aside)
  }

  // MARK: The displays are the same

  /// [editor | Desktop with the notes on it], the notes clear of the editor.
  func editorDockedNotesFloating(displays: [DisplaySnapshot] = [lap]) -> (h: Harness, editor: WindowID, notes: WindowID) {
    let h = Harness(displays: displays)
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let notes = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 780, y: 100, width: 600, height: 420))
    h.start()
    h.run("dock \(editor.rawValue) left")
    settle(h)
    return (h, editor, notes)
  }

  /// No jump at the start, which is why no net saw it: the jump came with the next Show Everything.
  @Test func movedWhileArborWasNotRunningItComesBackToWhereItWasMovedTo() {
    let (old, editor, notes) = editorDockedNotesFloating()
    old.controller.shutdown()
    let h = newProcess(after: old)
    let chosen = CGRect(x: 850, y: 500, width: 600, height: 420)
    h.system.place(notes, at: chosen)
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h) == chosen)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen, "there and back is nothing")
  }

  @Test func movedDuringAPauseItComesBackToWhereItWasMovedTo() {
    let (h, editor, notes) = editorDockedNotesFloating()
    h.run("pause")
    let chosen = CGRect(x: 850, y: 500, width: 600, height: 420)
    h.system.userMove(notes, to: chosen)
    h.system.clearFrameLog()
    h.run("resume")
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h) == chosen)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen, "there and back is nothing")
  }

  /// As a day with real apps on a hosted Mac met it: dragged 60 points during a pause and left there by the resume, the window was moved back
  /// by Float All, and by Quit.
  @Test(arguments: ["float-all", "pause", "quit"])
  func movedDuringAPauseNoWayOutMovesItBack(wayOut: String) {
    let (h, _, notes) = editorDockedNotesFloating()
    h.run("pause")
    let chosen = h.frame(notes)!.offsetBy(dx: 60, dy: 60)
    h.system.userMove(notes, to: chosen)
    h.run("resume")
    settle(h)
    h.system.clearFrameLog()
    if wayOut == "quit" { h.controller.shutdown() } else { h.run(wayOut) }
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == chosen)
  }

  /// Made smaller, not only moved: its size is its person's too.
  @Test(arguments: ["quit", "pause"])
  func madeSmallerWhileArborWasAwayItIsNotBlownUpAgain(away: String) {
    var (h, editor, notes) = editorDockedNotesFloating()
    let chosen = CGRect(x: 900, y: 300, width: 400, height: 300)
    if away == "quit" {
      h.controller.shutdown()
      h = newProcess(after: h)
      h.system.place(notes, at: chosen)
      h.start()
    } else {
      h.run("pause")
      h.system.userMove(notes, to: chosen)
      h.system.clearFrameLog()
      h.run("resume")
    }
    settle(h)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen)
  }

  /// A window kept in view is a floating window. What is remembered for it is also the size it is held to.
  @Test(arguments: ["quit", "pause"])
  func aWindowKeptInViewThatWasMadeSmallerWhileArborWasAwayStaysSmall(away: String) {
    var (h, _, notes) = editorDockedNotesFloating()
    h.run("pin \(notes.rawValue)")
    settle(h)
    let chosen = CGRect(x: 900, y: 300, width: 400, height: 300)
    if away == "quit" {
      h.controller.shutdown()
      h = newProcess(after: h)
      h.system.place(notes, at: chosen)
      h.start()
    } else {
      h.run("pause")
      h.system.userMove(notes, to: chosen)
      h.system.clearFrameLog()
      h.run("resume")
    }
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == chosen)
    #expect(h.workspace.isPinned(notes), "still kept in view")
  }

  /// Taken to the other display while Arbor was away: it belongs to the display it is on, or it would leave the view with the
  /// Desktop of a display it is not on, and come back there.
  @Test(arguments: ["quit", "pause"])
  func takenToAnotherDisplayWhileArborWasAwayItFloatsThere(away: String) {
    var (h, editor, notes) = editorDockedNotesFloating(displays: [lap, beside])
    let chosen = CGRect(x: 1900, y: 300, width: 600, height: 420)
    if away == "quit" {
      h.controller.shutdown()
      h = newProcess(after: h)
      h.system.place(notes, at: chosen)
      h.start()
    } else {
      h.run("pause")
      h.system.userMove(notes, to: chosen)
      h.system.clearFrameLog()
      h.run("resume")
    }
    settle(h)
    #expect(home(of: notes, h) == beside.id)
    #expect(remembered(notes, h) == chosen)
    h.system.clearFrameLog()
    frameAndShowEverything(h, editor)
    #expect(moves(of: notes, h).isEmpty, "the view of the other display is none of its business: \(h.system.frameLog)")
  }

  @Test func whatIsKeptInViewIsStillKeptInViewOnTheDisplayItWasTakenTo() {
    let (old, _, notes) = editorDockedNotesFloating(displays: [lap, beside])
    old.run("pin \(notes.rawValue)")
    settle(old)
    old.controller.shutdown()
    let h = newProcess(after: old)
    h.system.place(notes, at: CGRect(x: 1900, y: 300, width: 600, height: 420))
    h.start()
    settle(h)
    #expect(home(of: notes, h) == beside.id)
    #expect(h.controller.workspaces[beside.id]?.isPinned(notes) == true)
    #expect(h.controller.workspaces[lap.id]?.contains(notes) == false)
  }

  // MARK: Where what is remembered still counts

  /// Nobody let go of anything: the windows are where Arbor had them, and a floating one may be there in a size Arbor gave it.
  /// [editor | Desktop | browser] leaves a Desktop narrower than the notes.
  func squeezed(watchingThePermission: Bool = false) -> (h: Harness, notes: WindowID, own: CGRect) {
    let h = Harness(displays: [lap])
    if watchingThePermission { h.watchAccessibility() }
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let browser = h.system.open(app: "Browser", pid: 1003, frame: CGRect(x: 200, y: 100, width: 700, height: 500))
    let own = CGRect(x: 300, y: 200, width: 900, height: 420)
    let notes = h.system.open(app: "Notes", pid: 1002, frame: own)
    h.start()
    h.system.userMove(notes, to: own.offsetBy(dx: 10, dy: 0))
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    settle(h)
    return (h, notes, own.offsetBy(dx: 10, dy: 0))
  }

  @Test func afterAnAccidentWhatArborSqueezedKeepsItsOwnSize() throws {
    let (old, notes, own) = squeezed()
    try #require(old.frame(notes)!.width < own.width, "squeezed onto the Desktop: \(old.frame(notes)!)")
    old.controller.saveNow()
    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h) == own, "the size Arbor gave it has not become its own")
  }

  @Test func whenThePermissionIsBackWhatArborSqueezedKeepsItsOwnSize() throws {
    let (h, notes, own) = squeezed(watchingThePermission: true)
    try #require(h.frame(notes)!.width < own.width)
    h.revokeAccessibility()
    h.scheduler.advance(by: 5)
    try #require(!h.controller.isRunning)
    h.grantAccessibility()
    h.scheduler.advance(by: 5)
    try #require(h.controller.isRunning)
    #expect(remembered(notes, h) == own)
  }

  /// Both processes killed, or no watchdog: a person starts Arbor, and the windows are still as Arbor had them. "A person started it" is
  /// not "Arbor had quit": only a quit's file says where the windows were left (`PersistedState.leftAt`).
  @Test func startedByAPersonAfterARunThatDidNotQuitWhatArborSqueezedKeepsItsOwnSize() throws {
    let (old, notes, own) = squeezed()
    try #require(old.frame(notes)!.width < own.width)
    old.controller.saveNow()
    #expect(old.store.saved?.leftAt == nil, "written while Arbor runs")
    let h = newProcess(after: old)
    h.start()
    settle(h)
    #expect(remembered(notes, h) == own)
    h.controller.shutdown()
    #expect(h.frame(notes) == own, "a quit gives it back (rule 5)")
  }

  /// Its app does not answer when Arbor lets go, so it keeps the size Arbor gave it. Nobody chose that.
  @Test(arguments: ["quit", "pause"])
  func whatCouldNotBeGivenBackKeepsItsOwnSize(away: String) throws {
    var (h, notes, own) = squeezed()
    try #require(h.frame(notes)!.width < own.width)
    h.system.setUnresponsive(pid: 1002, true)
    if away == "quit" {
      h.controller.shutdown()
      h.system.setUnresponsive(pid: 1002, false)
      h = newProcess(after: h)
      h.start()
    } else {
      h.run("pause")
      h.system.setUnresponsive(pid: 1002, false)
      h.run("resume")
    }
    settle(h)
    #expect(remembered(notes, h) == own)
    h.controller.shutdown()
    #expect(h.frame(notes) == own, "a quit gives it back (rule 5)")
  }

  /// The permission goes while Arbor runs, so nothing can be given back, and Arbor is quit like that.
  @Test func quitWithoutThePermissionWhatArborSqueezedKeepsItsOwnSize() throws {
    let (old, notes, own) = squeezed(watchingThePermission: true)
    try #require(old.frame(notes)!.width < own.width)
    old.revokeAccessibility()
    old.scheduler.advance(by: 5)
    try #require(!old.controller.isRunning)
    old.controller.shutdown()
    #expect(old.store.saved?.leftAt == nil)
    old.grantAccessibility()
    let h = newProcess(after: old)
    h.start()
    settle(h)
    #expect(remembered(notes, h) == own)
  }

  @Test func onlyAQuitAndAPauseSayWhereArborLeftTheWindows() {
    let (h, editor, notes) = editorDockedNotesFloating()
    h.controller.saveNow()
    #expect(h.store.saved?.leftAt == nil, "running")
    h.run("pause")
    #expect(h.store.saved?.leftAt == [editor: h.frame(editor)!, notes: h.frame(notes)!], "paused")
    h.run("resume")
    #expect(h.store.saved?.leftAt == nil, "running again, at once: the file must not say so for the half second until the next save")
    h.controller.shutdown()
    #expect(h.store.saved?.leftAt == [editor: h.frame(editor)!, notes: h.frame(notes)!], "quit")
    let again = newProcess(after: h)
    again.start()
    #expect(again.store.saved?.leftAt == nil, "started again, at once")
  }

  /// What a quit writes is read by the next process from a file.
  @Test func whereTheWindowsWereLeftSurvivesTheFileAndCostsOnlyItselfIfItCannotBeRead() throws {
    let (h, editor, notes) = editorDockedNotesFloating()
    h.system.userMove(notes, to: CGRect(x: 850.5, y: 500.25, width: 600, height: 420))
    h.controller.shutdown()
    let written = try #require(h.store.saved)
    #expect(written.leftAt?.keys.sorted() == [editor, notes])
    let data = try JSONEncoder().encode(written)
    #expect(PersistedState.read(data) == .loaded(written))

    var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    json["leftAt"] = "nowhere"
    let remarks = DecodingNotes()
    guard case .loaded(let read) = PersistedState.read(try JSONSerialization.data(withJSONObject: json), notes: remarks) else {
      Issue.record("the file did not load")
      return
    }
    #expect(read.leftAt == nil, "as if nothing had been written: what is remembered stands")
    #expect(read.workspaces == written.workspaces)
    #expect(remarks.losses.isEmpty, "nothing a person made is gone: \(remarks.losses)")
    #expect(remarks.tidied == ["`leftAt` could not be read"])
  }

  /// The pause had let go. That it ends with the permission going and coming back, and not with `resume`, changes nothing.
  @Test func movedDuringAPauseThatEndsWithThePermissionGoingAndComingBack() throws {
    let h = Harness(displays: [lap])
    h.watchAccessibility()
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let notes = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 780, y: 100, width: 600, height: 420))
    h.start()
    h.run("dock \(editor.rawValue) left")
    settle(h)
    h.run("pause")
    let chosen = CGRect(x: 850, y: 500, width: 600, height: 420)
    h.system.userMove(notes, to: chosen)
    h.revokeAccessibility()
    h.scheduler.advance(by: 10)
    h.grantAccessibility()
    h.scheduler.advance(by: 10)
    try #require(h.controller.isRunning)
    #expect(remembered(notes, h) == chosen)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen)
  }

  /// A crash during the pause; the watchdog brings Arbor back paused. The pause had let go before, and the file says so.
  @Test func movedDuringAPauseThatOutlivesAnAccident() throws {
    let (old, editor, notes) = editorDockedNotesFloating()
    old.run("pause")
    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    try #require(h.controller.isPaused)
    let chosen = CGRect(x: 850, y: 500, width: 600, height: 420)
    h.system.place(notes, at: chosen)
    h.run("resume")
    settle(h)
    #expect(remembered(notes, h) == chosen)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen)
  }

  /// Found as Arbor had it: 488 points wide on a narrow Desktop, where its own width is 900. However the window came to be found like that,
  /// nobody chose it, and the next quit gives it its own size back (rule 5). Each of these lost it for good in an earlier cut of this change.
  @Test(arguments: [
    // Killed, and started by a person.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    save
    crash
    launch
    settle
    quit
    """,
    // Its app does not answer at the quit.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    hang 1002
    quit
    advance 1
    wake 1002
    advance 1
    launch
    settle
    quit
    """,
    // Nor at the pause.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    hang 1002
    pause
    advance 1
    wake 1002
    advance 1
    resume
    settle
    quit
    """,
    // Its app answers and does not obey, at the quit.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    behave 102 frozen
    quit
    behave 102 normal
    launch
    settle
    quit
    """,
    // And at the pause.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    behave 102 frozen
    pause
    advance 1
    behave 102 normal
    resume
    settle
    quit
    """,
    // In full screen at the quit.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    full-screen 102 on
    settle
    quit
    full-screen 102 off
    launch
    settle
    quit
    """,
    // In full screen at the pause.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    full-screen 102 on
    settle
    pause
    advance 1
    quit
    full-screen 102 off
    launch
    settle
    quit
    """,
    // And out of it during the pause.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    full-screen 102 on
    settle
    pause
    advance 1
    full-screen 102 off
    advance 3
    resume
    settle
    quit
    """,
    // Killed, and the window carried to the other display: a move is not a resize.
    """
    displays main:0,0,1512,982:37,0,0,0* side:1512,0,1920,1080:0,0,0,0 windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    cursor 400 400
    dock 101 left
    dock 103 right
    settle
    save
    crash
    move 102 1900 300 488 420
    launch
    settle
    quit
    """,
    // Killed within the half second after a resume, before the next save.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    pause
    advance 1
    resume
    crash
    launch
    settle
    quit
    """,
    // Quit with no display at all.
    """
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    open 101 Editor pid 1001 at 100 100 700 500
    open 103 Browser pid 1003 at 200 100 700 500
    open 102 Notes pid 1002 at 300 200 900 420
    move 102 310 200 900 420
    dock 101 left
    dock 103 right
    settle
    displays windows-never
    settle
    quit
    displays main:0,0,1512,982:37,0,0,0* windows-never
    launch
    settle
    quit
    """,
  ])
  func foundAsArborHadSqueezedItTheNextQuitStillGivesItsOwnSizeBack(script: String) {
    let runner = ChaosRunner()
    var narrowest = CGFloat.infinity
    for action in ChaosAction.script(script) {
      let broken = runner.step(action).filter { !ChaosRunner.knownRules.contains($0.rule) || $0.rule == "size-not-given-back" }
      #expect(broken.isEmpty, "\(action.text): \(broken)")
      narrowest = min(narrowest, runner.system.frame(of: WindowID(102))?.width ?? .infinity)
    }
    #expect(narrowest < 500, "it was squeezed, or the story proves nothing")
    #expect(runner.system.frame(of: WindowID(102))?.size == CGSize(width: 900, height: 420))
  }

  /// Left squeezed because its app did not answer, and then only moved by its person: a move is not a resize.
  @Test func leftSqueezedAndThenOnlyMovedItKeepsItsOwnSizeAndHasTheNewPlace() throws {
    let (old, notes, own) = squeezed()
    let narrow = try #require(old.frame(notes))
    try #require(narrow.width < own.width)
    old.system.setUnresponsive(pid: 1002, true)
    old.controller.shutdown()
    old.system.setUnresponsive(pid: 1002, false)
    let h = newProcess(after: old)
    h.system.place(notes, at: narrow.offsetBy(dx: -100, dy: 200))
    h.start()
    settle(h)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(remembered(notes, h)?.size == own.size)
    #expect(remembered(notes, h)?.minY == narrow.minY + 200)
  }

  /// A crash during a pause, the watchdog brings Arbor back paused, and the pause is asked for again, which writes it anew.
  @Test func aPauseAskedForAgainAfterAnAccidentStillSaysWhereTheWindowsWereLeft() throws {
    let (old, editor, notes) = editorDockedNotesFloating()
    old.run("pause")
    let h = newProcess(after: old, byTheWatchdog: true)
    h.start()
    try #require(h.controller.isPaused)
    h.run("pause 10")
    #expect(h.store.saved?.leftAt != nil)
    let chosen = CGRect(x: 850, y: 500, width: 600, height: 420)
    h.system.place(notes, at: chosen)
    h.run("resume")
    settle(h)
    #expect(remembered(notes, h) == chosen)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen)
  }

  /// The pause gave it its own frame back, and nobody has touched it since: the resume undoes what the pause did.
  @Test func whatThePauseGaveBackAndNobodyTouchedGoesBackOnTheDesktop() throws {
    let (h, notes, own) = squeezed()
    let onTheDesktop = try #require(h.frame(notes))
    try #require(onTheDesktop.width < own.width)
    h.run("pause")
    #expect(h.frame(notes) == own)
    h.run("resume")
    settle(h)
    #expect(h.frame(notes) == onTheDesktop)
    #expect(remembered(notes, h) == own)
  }

  /// Pushed by hand to where a third of it shows. The pause brings it wholly into view, which is not where it is remembered; nobody
  /// touches it. That place is the pause's doing, so it does not become the window's own.
  @Test func whereThePauseItselfPutItIsNotItsOwnPlace() throws {
    let (h, _, notes) = editorDockedNotesFloating()
    let aside = CGRect(x: 1312, y: 500, width: 600, height: 420)
    h.system.userMove(notes, to: aside)
    settle(h)
    try #require(remembered(notes, h) == aside)
    h.run("pause")
    try #require(h.frame(notes) != aside, "fetched by the pause: \(h.frame(notes)!)")
    h.run("resume")
    settle(h)
    #expect(remembered(notes, h) == aside)
  }

  /// Left hanging over the edge while Arbor was away: it comes back there, as it does when Arbor sees the move.
  @Test(arguments: ["quit", "pause", "seen"])
  func leftHangingOverAnEdgeItComesBackHanging(away: String) {
    var (h, editor, notes) = editorDockedNotesFloating()
    let chosen = CGRect(x: 1100, y: 500, width: 600, height: 420)
    switch away {
    case "quit":
      h.controller.shutdown()
      h = newProcess(after: h)
      h.system.place(notes, at: chosen)
      h.start()
    case "pause":
      h.run("pause")
      h.system.userMove(notes, to: chosen)
      h.run("resume")
    default:
      h.system.userMove(notes, to: chosen)
    }
    settle(h)
    frameAndShowEverything(h, editor)
    #expect(h.frame(notes) == chosen)
  }

  /// Taken during a pause to a display whose view is on one window. The view comes back; what was brought there is not swept away.
  @Test func takenToADisplayWhoseViewIsFramedItStaysInView() {
    let h = Harness(displays: [lap, beside])
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 1700, y: 100, width: 700, height: 500))
    let browser = h.system.open(app: "Browser", pid: 1003, frame: CGRect(x: 2400, y: 100, width: 700, height: 500))
    let notes = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 600, height: 420))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    h.run("pause")
    let chosen = CGRect(x: 2000, y: 300, width: 600, height: 420)
    h.system.userMove(notes, to: chosen)
    h.system.clearFrameLog()
    h.run("resume")
    settle(h)
    #expect(home(of: notes, h) == beside.id)
    #expect(moves(of: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == chosen)
    #expect(!h.system.isVisible(browser), "the view is back")
  }

  /// Found with nothing but a strip showing, so this start fetches it (`adopt`). Where the fetching put it is nobody's choice, and the place
  /// remembered with the display that is back is the better one.
  @Test func whatThisStartItselfHadToFetchGoesWhereItIsRemembered() {
    let (h, _, notes) = homeFromTheDesk(docking: false)
    h.system.place(notes, at: CGRect(x: 1400, y: 900, width: 720, height: 420))
    h.start()
    settle(h)
    #expect(h.frame(notes) == CGRect(x: 300, y: 200, width: 720, height: 420))
  }

  /// What a start noted does not outlive it: a later start, before which nobody let go, must not go by it.
  @Test(arguments: ["quit", "pause"])
  func whatOneStartFoundIsForgottenOnceItIsOver(away: String) {
    var (h, _, _) = editorDockedNotesFloating()
    if away == "quit" {
      h.controller.shutdown()
      h = newProcess(after: h)
      h.start()
    } else {
      h.run("pause")
      h.run("resume")
    }
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  /// Arbor had quit, and something has since put the window where no display shows it. Nobody could have chosen that, and nobody could get
  /// hold of it there: never lost outranks never moved.
  @Test func foundWhereNothingOfItShowsItGoesWhereItIsRemembered() {
    let (old, _, notes) = editorDockedNotesFloating()
    let place = old.frame(notes)
    old.controller.shutdown()
    let h = newProcess(after: old)
    h.system.place(notes, at: CGRect(x: 1511, y: 950, width: 600, height: 420))
    h.start()
    settle(h)
    #expect(h.frame(notes) == place)
    #expect(remembered(notes, h) == place)
  }

  /// The green button was pressed while Arbor was away. The frame of a window in full screen is the display's, not its own.
  @Test func aWindowFoundInFullScreenKeepsTheFrameThatIsRemembered() {
    let (old, _, notes) = editorDockedNotesFloating()
    let place = old.frame(notes)
    old.controller.shutdown()
    let h = newProcess(after: old)
    h.system.setFullScreen(notes, true)
    h.start()
    settle(h)
    #expect(remembered(notes, h) == place)
  }

  /// A run that ended without quitting left it in the corner, which nobody chose: it goes where it is remembered.
  @Test func whatACrashLeftOutOfViewGoesWhereItIsRemembered() {
    let (old, editor, notes) = editorDockedNotesFloating()
    let place = old.frame(notes)
    old.system.userFocus(editor)
    old.run("zoom")
    settle(old)
    #expect(!old.system.isVisible(notes))
    old.controller.saveNow()

    let h = newProcess(after: old)
    h.start()
    settle(h)
    #expect(h.frame(notes) == place)
    #expect(moves(of: notes, h).count == 1, "\(h.system.frameLog)")
  }
}
