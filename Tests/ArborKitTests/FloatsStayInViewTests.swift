import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// **Arbor never takes a floating window out of view** (collab/QUESTIONS.md, Q29, 4). "The one thing Arbor does to a floating window",
/// taking it away when the view leaves the Desktop and putting it back, is withdrawn.
///
/// What is held here: after every command, each floating window that the command does not name has the frame and the place in macOS's
/// order that it had, and Arbor has not called its app once.
@Suite @MainActor struct FloatsStayInViewTests {
  /// Two windows docked, left and right, and three that lie about, over them and over each other.
  @MainActor struct Desk {
    var h: Harness
    var safari, notes: WindowID
    var floats: [WindowID: CGRect] = [:]
    /// The floating windows from front to back, as macOS has them.
    var order: [WindowID] { h.system.windowsFrontToBack().filter { floats[$0] != nil } }
  }

  func makeDesk(_ change: (inout Settings) -> Void = { _ in }) -> Desk {
    var settings = Settings()
    change(&settings)
    let h = Harness(settings: settings)
    let safari = h.system.open(app: "Safari", pid: 2001)
    let notes = h.system.open(app: "Notes", pid: 2002)
    var desk = Desk(h: h, safari: safari, notes: notes)
    for (app, pid, frame) in [
      ("Mail", Int32(2003), CGRect(x: 500, y: 200, width: 640, height: 420)),
      ("Music", 2004, CGRect(x: 700, y: 350, width: 640, height: 420)),
      ("Preview", 2005, CGRect(x: 60, y: 90, width: 420, height: 300)),
    ] { desk.floats[h.system.open(app: app, pid: pid, frame: frame)] = frame }
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.clearFrameLog()
    h.system.clearRaiseLog()
    return desk
  }

  /// Runs `command` and holds every floating window to where and how it was before.
  func expectNothingOfWhatFloats(
    _ desk: Desk, changesWith command: String, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let order = desk.order
    desk.h.system.clearFrameLog()
    desk.h.system.clearRaiseLog()
    desk.h.run(command)
    desk.h.scheduler.advance(by: 1)
    for (window, frame) in desk.floats.sorted(by: { $0.key < $1.key }) {
      #expect(desk.h.frame(window) == frame, "\(window) after \(command)", sourceLocation: sourceLocation)
      #expect(desk.h.system.isVisible(window), "\(window) is in view after \(command)", sourceLocation: sourceLocation)
    }
    #expect(desk.order == order, "the order after \(command)", sourceLocation: sourceLocation)
    let touched = Set(desk.h.system.frameLog.map(\.window)).intersection(desk.floats.keys).sorted()
    #expect(touched.isEmpty, "\(command) set the frame of \(touched)", sourceLocation: sourceLocation)
    let raised = desk.h.system.raiseLog.filter { desk.floats[$0] != nil }
    #expect(raised.isEmpty, "\(command) raised \(raised)", sourceLocation: sourceLocation)
  }

  // MARK: Wherever the view goes

  @Test func aDockedWindowFillsTheScreenAndWhatFloatsStaysBehindIt() {
    let desk = makeDesk()
    expectNothingOfWhatFloats(desk, changesWith: "zoom \(desk.safari.rawValue)")
    #expect(desk.h.frame(desk.safari).map { $0.width > 1300 } == true, "or nothing was framed")
    #expect(!desk.h.system.isVisible(desk.notes), "a docked window the view leaves out goes, as ever")
    expectNothingOfWhatFloats(desk, changesWith: "show-all")
    expectWindowsMatchLayout(desk.h)
  }

  /// Every command that moves the view, one after another on one desk, there and back and across.
  @Test func noMoveOfTheViewTouchesWhatFloats() {
    let desk = makeDesk()
    let (safari, notes) = (desk.safari.rawValue, desk.notes.rawValue)
    // A view on the Desktop gives the keyboard to the window there that was used last. That it is in front already is this test's
    // doing: who comes to the front with the keyboard is macOS's business.
    desk.h.system.userFocus(desk.order[0])
    desk.h.system.userFocus(desk.safari)
    for command in [
      "zoom \(safari)", "neighbor right", "back", "forward", "out", "zoom \(notes)", "home", "zoom \(safari)", "save-view 1", "show-all",
      "view 1", "desktop", "back", "in", "out", "zoom \(notes)", "desktop", "show-all",
    ] { expectNothingOfWhatFloats(desk, changesWith: command) }
    expectWindowsMatchLayout(desk.h)
  }

  /// The control: with floating windows kept on the Desktop, as until Q20, they leave with it. If they stop, the tests above prove nothing.
  @Test func withFloatingWindowsMakingWayTheyLeaveWithTheDesktopAsTheyDid() {
    let desk = makeDesk { $0.floatingWindowsMakeWay = true }
    desk.h.run("zoom \(desk.safari.rawValue)")
    for window in desk.floats.keys.sorted() { #expect(!desk.h.system.isVisible(window), "\(window)") }
    desk.h.run("show-all")
    for window in desk.floats.keys.sorted() { #expect(desk.h.system.isVisible(window), "\(window)") }
  }

  // MARK: What happens by itself

  @Test func aClickOnAFloatingWindowBesideAFramedOneLeavesTheViewAlone() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let (view, mail) = (desk.h.workspace.camera, desk.floats.keys.sorted()[0])
    desk.h.system.clearFrameLog()
    desk.h.system.userFocus(mail)
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.workspace.camera == view, "it is in view: there is nothing to bring into view")
    #expect(desk.h.system.frameLog.isEmpty, "\(desk.h.system.frameLog)")
    #expect(desk.h.system.focused == mail)
  }

  /// Somebody types in a floating window and presses a key that only moves the view: everything, back, forward, out, in, the Desktop, a
  /// direction. Nobody has said whose the keyboard shall be. It stays in view, so it keeps the keyboard, and nobody is raised over it.
  @Test func aKeyThatOnlyMovesTheViewLeavesTheKeyboardInTheFloatingWindowTypedIn() {
    let desk = makeDesk()
    let mail = desk.floats.keys.sorted()[0]
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("show-all")
    desk.h.system.userFocus(mail)
    desk.h.scheduler.advance(by: 1)
    for command in ["back", "show-all", "back", "forward", "in", "out", "home", "desktop", "neighbor left", "neighbor right", "neighbor right"] {
      expectNothingOfWhatFloats(desk, changesWith: command)
      #expect(desk.h.system.focused == mail, "after \(command)")
      #expect(desk.h.system.windowsFrontToBack().first == mail, "after \(command)")
    }
  }

  /// What names a window or a space gives it the keyboard, out of a floating window too.
  @Test(arguments: ["zoom-node", "view 1", "zoom"]) func aCommandThatNamesWhereToGoTakesTheKeyboardThere(command: String) {
    let desk = makeDesk()
    let mail = desk.floats.keys.sorted()[0]
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("save-view 1")
    desk.h.run("zoom \(desk.notes.rawValue)")
    desk.h.system.userFocus(mail)
    desk.h.scheduler.advance(by: 1)
    let named = ["zoom": "zoom \(desk.safari.rawValue)", "zoom-node": "zoom-node \(desk.h.workspace.tree.leaf(containing: desk.safari)!.rawValue)"]
    expectNothingOfWhatFloats(desk, changesWith: named[command] ?? command)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.safari))
    #expect(desk.h.system.focused == desk.safari)
  }

  /// Named though the view is on it already: somebody clicked the floating window beside the framed one, which moves no view, and says where to.
  @Test(arguments: ["go work", "view 1", "zoom-node"]) func namingThePlaceTheViewIsOnAlreadyTakesTheKeyboardThereToo(command: String) {
    let desk = makeDesk()
    let mail = desk.floats.keys.sorted()[0]
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("name work")
    desk.h.run("save-view 1")
    desk.h.system.userFocus(mail)
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.safari), "the premise: the click moved no view")
    expectNothingOfWhatFloats(desk, changesWith: command == "zoom-node" ? "zoom-node \(desk.h.workspace.camera.rawValue)" : command)
    #expect(desk.h.system.focused == desk.safari)
  }

  /// A direction goes to what can be seen. What floats behind the framed window cannot: it is no stop, nothing fetches it to the front, and the key
  /// reaches the neighbor as it did when floating windows left with the Desktop. One that lies in front is a stop like any window in view.
  @Test func aDirectionDoesNotStopAtWhatFloatsBehindTheFramedWindow() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.system.focused == desk.safari && desk.h.system.windowsFrontToBack().first == desk.safari, "the premise: it covers them")
    expectNothingOfWhatFloats(desk, changesWith: "focus right")
    #expect(desk.h.system.focused == desk.notes && desk.h.workspace.camera == desk.h.workspace.tree.leaf(containing: desk.notes))
    let music = desk.floats.keys.sorted()[1]
    desk.h.system.userFocus(music)
    desk.h.system.userFocus(desk.floats.keys.sorted()[2])
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.run("focus right").ok)
    #expect(desk.h.system.focused == music, "Preview at the left, Music at the right, both in front of Notes")
  }

  /// Nor under a held view, where nothing comes to the front that was not there.
  @Test func underAHeldViewADirectionFetchesNothingFromBehind() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("hold")
    desk.h.scheduler.advance(by: 1)
    let order = desk.h.system.windowsFrontToBack()
    #expect(!desk.h.run("focus right").ok)
    #expect(desk.h.system.focused == desk.safari && desk.h.system.windowsFrontToBack() == order)
  }

  @Test func aWindowThatOpensWhileAnotherIsFramedStaysWhenTheViewMovesOn() {
    var desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let guest = desk.h.system.open(app: "Calculator", pid: 2006, frame: CGRect(x: 300, y: 300, width: 240, height: 320))
    desk.h.scheduler.advance(by: 1)
    desk.floats[guest] = desk.h.frame(guest)
    #expect(desk.floats[guest] == CGRect(x: 300, y: 300, width: 240, height: 320), "where its app opened it")
    for command in ["show-all", "zoom \(desk.notes.rawValue)", "desktop", "back"] { expectNothingOfWhatFloats(desk, changesWith: command) }
  }

  @Test func closingTheFramedWindowTakesNothingThatFloatsAway() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.system.clearFrameLog()
    desk.h.system.close(desk.safari)
    desk.h.scheduler.advance(by: 1)
    for (window, frame) in desk.floats { #expect(desk.h.frame(window) == frame && desk.h.system.isVisible(window), "\(window)") }
    #expect(Set(desk.h.system.frameLog.map(\.window)).isDisjoint(with: desk.floats.keys))
    #expect(desk.h.system.isVisible(desk.notes))
  }

  @Test func aPauseAResumeAndAStartWhileAWindowIsFramedTouchNothingThatFloats() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    for command in ["toggle-pause", "toggle-pause"] { expectNothingOfWhatFloats(desk, changesWith: command) }
    desk.h.system.clearFrameLog()
    desk.h.controller.shutdown()
    desk.h.system.clearFrameLog()
    let next = Harness(settings: Settings(), saved: desk.h.store.saved, system: desk.h.system)
    next.start()
    for (window, frame) in desk.floats { #expect(next.frame(window) == frame && next.system.isVisible(window), "\(window)") }
    #expect(Set(next.system.frameLog.map(\.window)).isDisjoint(with: desk.floats.keys))
  }

  // MARK: Undo

  /// The step before had a window floating while another was framed. Taken back, it floats in view, at its own frame.
  @Test func anUndoThatMakesAWindowFloatAgainUnderAFramedViewLeavesItInView() {
    let desk = makeDesk()
    let mail = desk.floats.keys.sorted()[0]
    desk.h.run("zoom \(desk.safari.rawValue)")
    desk.h.run("dock \(mail.rawValue) right")
    #expect(desk.h.workspace.isDocked(mail))
    desk.h.run("undo")
    desk.h.scheduler.advance(by: 1)
    #expect(desk.h.workspace.isFloating(mail))
    #expect(desk.h.frame(mail) == desk.floats[mail], "its own frame")
    #expect(desk.h.system.isVisible(mail))
    for (window, frame) in desk.floats where window != mail { #expect(desk.h.frame(window) == frame, "\(window)") }
  }

  // MARK: A command that names it

  /// What is withdrawn is what Arbor did by itself. Sent away by name, a window goes, and comes when it is called.
  @Test func aWindowSentAwayByNameGoesAndTheOthersStay() {
    var desk = makeDesk()
    let mail = desk.floats.keys.sorted()[0]
    let own = desk.floats.removeValue(forKey: mail)
    expectNothingOfWhatFloats(desk, changesWith: "summon Mail")
    expectNothingOfWhatFloats(desk, changesWith: "summon Mail")
    #expect(!desk.h.system.isVisible(mail), "summoned and sent back: out of view, because its person said so")
    expectNothingOfWhatFloats(desk, changesWith: "zoom \(desk.safari.rawValue)")
    #expect(!desk.h.system.isVisible(mail), "and stays away whatever the view does")
    expectNothingOfWhatFloats(desk, changesWith: "summon Mail")
    #expect(desk.h.system.isVisible(mail) && desk.h.frame(mail)?.size == own?.size)
  }

  // MARK: A hold

  /// A hold is its person's own word that nothing comes into view. A display goes, and the floating window it sends over waits out of
  /// view: beside a held window, and under a held view that has emptied, where a layout made now would show the Desktop. It comes when
  /// the hold ends. No rule of the walks speaks at any step. (After a story of the keeper of displays that come and go.)
  @Test(arguments: [nil, "hide 1003", "close 110", "minimize 110"], ["between", "late", "silent"])
  func duringAHoldWhatADisplayThatGoesSendsOverWaitsOutOfView(emptiedBy: String?, order: String) {
    let runner = ChaosRunner()
    func play(_ lines: [String?]) {
      for line in lines.compactMap({ $0 }) {
        let broken = runner.step(ChaosAction(text: line)).filter { !ChaosRunner.knownRules.contains($0.rule) }
        #expect(broken.isEmpty, "\(line): \(broken)")
      }
    }
    func share() -> CGFloat {
      let frame = runner.system.windows[WindowID(101)]!.snapshot.frame
      return runner.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +) / frame.area
    }
    play([
      "displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0 windows-first", "launch",
      "open 101 Music pid 1006 at 2000 200 800 600 min 680 480", "advance 1", "open 110 Terminal pid 1003 at 500 300 700 500 min 177 60",
      "key down dock right", "key up dock right", "advance 1", "key down zoom", "key up zoom", "advance 1", "react", "toggle-hold", "advance 1",
      emptiedBy, "react", "advance 1", "react", "displays main:0,0,1512,982:37,0,0,0* windows-\(order)", "react", "advance 1", "react",
    ])
    #expect(runner.controller.parked.contains(WindowID(101)) && share() < 0.01)
    play(["toggle-hold", "advance 1", "react"])
    #expect(!runner.controller.parked.contains(WindowID(101)) && share() == 1)
  }

  /// The control: without a hold it arrives in view, over the framed window.
  @Test(arguments: ["between", "late", "silent"]) func withoutAHoldItArrivesInViewOverAFramedWindow(order: String) {
    let runner = ChaosRunner()
    for line in [
      "displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0 windows-first", "launch",
      "open 101 Music pid 1006 at 2000 200 800 600 min 680 480", "advance 1", "open 110 Terminal pid 1003 at 500 300 700 500 min 177 60",
      "key down dock right", "key up dock right", "advance 1", "key down zoom", "key up zoom", "advance 1", "react",
      "displays main:0,0,1512,982:37,0,0,0* windows-\(order)", "react", "advance 1", "react",
    ] { _ = runner.step(ChaosAction(text: line)) }
    let frame = runner.system.windows[WindowID(101)]!.snapshot.frame
    #expect(!runner.controller.parked.contains(WindowID(101)) && runner.system.displayList[0].frame.contains(frame), "\(frame)")
    #expect(runner.controller.workspaces[DisplayID("main")].map { $0.camera == $0.tree.leaf(containing: WindowID(110)) } == true)
  }

  /// What a reader who played the hold found, each as the story that showed it. `lines` are played, and after each of `then` window 103 is in
  /// view (true) or waits out of view.
  private func expect103(_ lines: [String], then: [(String, Bool)], sourceLocation: SourceLocation = #_sourceLocation) {
    let runner = ChaosRunner()
    for line in lines { _ = runner.step(ChaosAction(text: line)) }
    for (line, inView) in then {
      for step in [line, "settle", "advance 5", "settle"] { _ = runner.step(ChaosAction(text: step)) }
      let frame = runner.system.windows[WindowID(103)]!.snapshot.frame
      let share = runner.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +) / frame.area
      #expect(inView ? share > 0.2 : share < 0.01, "after \(line): \(frame)", sourceLocation: sourceLocation)
      #expect(runner.controller.parked.contains(WindowID(103)) != inView, "after \(line)", sourceLocation: sourceLocation)
    }
  }

  private static let heldOn101 = [
    "launch", "open 101 Safari pid 1000 at 100 100 600 400", "open 102 Mail pid 1001 at 200 200 600 400", "dock 101 left", "dock 102 right",
    "zoom 101", "focus 101",
  ]

  /// What was in view when the hold began stays. No display for a moment, as at a wake: it is no arrival from a display that went.
  @Test func whatWasInViewWhenTheHoldBeganStaysThoughItsDisplayBlinks() {
    expect103(
      ["displays main:0,0,1440,900:25,0,0,0* windows-never"] + Self.heldOn101 + ["open 103 Notes pid 1002 at 700 300 500 400", "hold", "settle", "displays windows-never", "settle"],
      then: [("displays main:0,0,1440,900:25,0,0,0* windows-never", true), ("do release", true)])
  }

  /// One that waits goes home when its display is back, where it was in view: nothing keeps it out there.
  @Test func whatWaitedGoesHomeIntoViewWhenItsDisplayIsBack() {
    let both = "displays main:0,0,1440,900:25,0,0,0* side:1440,0,1920,1080:25,0,0,0"
    expect103(
      ["\(both) windows-never"] + Self.heldOn101 + ["open 103 Notes pid 1002 at 1700 300 500 400", "focus 101", "toggle-hold"],
      then: [("displays main:0,0,1440,900:25,0,0,0* windows-silent", false), ("\(both) windows-silent", true), ("toggle-hold", true)])
  }

  /// A held view that has emptied is not laid out. The display shrinks under a floating window: counted as out of view for the layout
  /// to put back, it was taken away in earnest.
  @Test func underAHeldViewThatHasEmptiedAChangeOfDisplaysTakesNothingAway() {
    expect103(
      ["displays main:0,0,1440,900:25,0,0,0* windows-never"] + Self.heldOn101
        + ["open 103 Notes pid 1002 at 800 300 500 400", "focus 101", "hold", "minimize 101", "settle"],
      then: [("displays main:0,0,1024,640:25,0,0,0* windows-never", true)])
  }

  /// An undo of something else fetches nothing that a hold keeps out: here a window that opened off screen while Arbor holds still.
  @Test func anUndoBringsInNothingThatTheHoldKeepsOut() {
    expect103(
      ["displays main:0,0,1440,900:25,0,0,0* windows-never"] + Self.heldOn101
        + ["open 104 Maps pid 1004 at 300 200 600 400", "focus 101", "hold still", "open 103 Mail pid 1001 at 1500 900 400 300", "settle"],
      then: [("dock 104 right", false), ("undo", false)])
  }

  // MARK: Out of view all the same

  /// An earlier build, or an Arbor with the setting on, died with a window framed: what floats is in its corner. Whatever the view that
  /// comes back shows, the start fetches it.
  @Test func whatAnArborThatDiedLeftInItsCornerComesBackAtTheStartWhateverTheViewShows() {
    let desk = makeDesk { $0.floatingWindowsMakeWay = true }
    desk.h.run("zoom \(desk.safari.rawValue)")
    #expect(desk.floats.keys.allSatisfy { !desk.h.system.isVisible($0) }, "or there is nothing to fetch")
    desk.h.scheduler.advance(by: 5)
    // No shutdown: nothing was fetched on the way out.
    let next = Harness(settings: Settings(), saved: desk.h.store.saved, system: desk.h.system)
    next.system.clearFrameLog()
    next.start()
    next.scheduler.advance(by: 1)
    for (window, own) in desk.floats.sorted(by: { $0.key < $1.key }) {
      #expect(next.frame(window) == own, "\(window): where its person had it")
      #expect(next.system.frameLog.filter { $0.window == window }.count == 1, "\(window): in one move")
    }
  }

  /// The setting goes off while they are away: they come back now, not when the Desktop next shows.
  @Test func switchingTheSettingOffWhileTheyAreAwayBringsThemBack() {
    let desk = makeDesk { $0.floatingWindowsMakeWay = true }
    desk.h.run("zoom \(desk.safari.rawValue)")
    #expect(desk.floats.keys.allSatisfy { !desk.h.system.isVisible($0) })
    desk.h.system.clearFrameLog()
    desk.h.run("set floatingWindowsMakeWay false")
    desk.h.scheduler.advance(by: 1)
    for (window, own) in desk.floats.sorted(by: { $0.key < $1.key }) {
      #expect(desk.h.frame(window) == own, "\(window): where its person had it")
      #expect(desk.h.system.frameLog.filter { $0.window == window }.count == 1, "\(window): in one move")
    }
    #expect(desk.h.frame(desk.safari).map { $0.width > 1300 } == true, "and the view is as it was")
  }
}
