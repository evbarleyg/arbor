import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The trial `outOfViewIsBehind` (collab/QUESTIONS.md, Q29, point 8): what is not in the framed space stays where it is, behind what is.
/// Each story is told with the switch on and, as a control, as Arbor ships: a test that cannot tell the two apart proves nothing.

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

private func settings(behind: Bool, _ change: (inout Settings) -> Void = { _ in }) -> Settings {
  var settings = Settings()
  settings.outOfViewIsBehind = behind
  change(&settings)
  return settings
}

/// Four windows of four apps, docked as two groups side by side with the Desktop to their right: (a / b) | (c / d) | Desktop.
@MainActor
private func makeFour(
  _ settings: Settings, displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], at corner: CGPoint = .zero
) -> (Harness, WindowID, WindowID, WindowID, WindowID) {
  let h = Harness(displays: displays, settings: settings)
  func open(_ app: String, _ pid: Int32, _ x: CGFloat, _ y: CGFloat) -> WindowID {
    h.system.open(app: app, pid: pid, frame: CGRect(x: corner.x + x, y: corner.y + y, width: 600, height: 400))
  }
  let (a, b, c, d) = (open("Safari", 1001, 100, 100), open("Notes", 1002, 200, 150), open("Mail", 1003, 300, 200), open("Terminal", 1004, 400, 250))
  h.start()
  h.run("dock \(a.rawValue) left")
  h.run("dock \(c.rawValue) beside \(a.rawValue) right")
  h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
  h.run("dock \(d.rawValue) beside \(c.rawValue) bottom")
  return (h, a, b, c, d)
}

@MainActor
private func frames(_ h: Harness) -> [WindowID: CGRect] {
  Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
}

/// The windows Arbor has asked to take a frame since the log was last cleared.
@MainActor
private func asked(_ h: Harness) -> Set<WindowID> { Set(h.system.frameLog.map(\.window)) }

/// Whether `front` lies in front of `back`.
@MainActor
private func lies(_ front: WindowID, inFrontOf back: WindowID, _ h: Harness) -> Bool {
  let order = h.system.windowsFrontToBack()
  guard let near = order.firstIndex(of: front), let far = order.firstIndex(of: back) else { return false }
  return near < far
}

/// Every window is wholly on a display: what a person, Mission Control and a Quit that never comes all find.
@MainActor
private func everyWindowIsOnADisplay(_ h: Harness) -> Bool {
  h.system.allWindows().allSatisfy { window in h.system.displayList.contains { window.frame.fractionInside($0.frame) > 0.99 } }
}

@MainActor
@Suite struct BehindNotAwayTests {
  @Test func itShipsOff() {
    #expect(!Settings().outOfViewIsBehind)
  }

  // MARK: The row's own sentence

  @Test func fillingTheScreenAndComingBackSetFramesOnlyForWhatIsFramed() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    let arranged = frames(h)
    h.system.clearFrameLog()

    h.run("zoom")
    #expect(asked(h) == [a])
    #expect(h.frame(a) == h.layout?.windowFrames[a])
    for other in [b, c, d] { #expect(h.frame(other) == arranged[other]) }
    // They are out of view all the same, for the view, the keyboard and `state`.
    #expect(h.controller.parked == [b, c, d])
    #expect(h.system.focusedWindow() == a)
    expectWindowsMatchLayout(h)

    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a])
    #expect(frames(h) == arranged)
    #expect(h.controller.parked.isEmpty)
    expectWindowsMatchLayout(h)
  }

  @Test func asItShipsTheSameStoryMovesEveryWindowTwice() {
    let (h, a, b, c, d) = makeFour(settings(behind: false))
    h.system.userFocus(a)
    let arranged = frames(h)
    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a, b, c, d])
    #expect(!everyWindowIsOnADisplay(h))
    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a, b, c, d])
    #expect(frames(h) == arranged)
  }

  @Test func nothingIsForetoldThatIsNotAskedFor() {
    let (h, a, _, _, _) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    for _ in 0..<2 {
      h.run("zoom")
      #expect(h.system.answersAhead.isEmpty)
    }
    h.run("in")
    h.run("out")
    #expect(h.system.answersAhead.isEmpty)
  }

  // MARK: Two of four

  @Test func twoOfFourFramedComeInFrontOfTheOtherTwo() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    // Used last to first: a, d, c, b. So b, which is about to grow, lies at the very back.
    for window in [b, c, d, a] { h.system.userFocus(window) }
    let arranged = frames(h)
    h.system.clearFrameLog()
    h.system.clearRaiseLog()

    h.run("out")  // from everything there is no further out
    h.run("zoom")
    h.run("out")  // the group a / b
    #expect(Set(h.layout!.windowFrames.keys) == [a, b])
    #expect(asked(h) == [a, b])
    for other in [c, d] { #expect(h.frame(other) == arranged[other]) }
    for other in [c, d] { #expect(lies(b, inFrontOf: other, h)) }
    // Only what something covered was raised, and the keyboard is where it was.
    #expect(Set(h.system.raiseLog) == [b])
    #expect(h.system.focusedWindow() == a)
    #expect(h.system.windowsFrontToBack().first { [a, b].contains($0) } != nil)
    expectWindowsMatchLayout(h)
  }

  @Test func whatIsInViewIsRaisedBeforeItGrows() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    for window in [b, c, d, a] { h.system.userFocus(window) }
    h.run("zoom")
    h.system.clearRaiseLog()
    // At the moment b is asked to grow it is in front of what it grows over: nobody sees it underneath.
    var wasInFront: Bool?
    h.system.willSetFrame = { window, _ in if window == b, wasInFront == nil { wasInFront = lies(b, inFrontOf: c, h) && lies(b, inFrontOf: d, h) } }
    h.run("out")
    h.system.willSetFrame = nil
    #expect(wasInFront == true)
  }

  @Test func whateverComesForwardWhileTheWindowsMoveTheViewEndsInFront() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    for window in [b, c, d, a] { h.system.userFocus(window) }
    h.run("zoom")
    // An app brings its window forward by itself at the worst moment: after the view was raised, while it is being laid out.
    h.system.willSetFrame = { window, _ in if window == b { h.system.raise(d) } }
    h.run("out")
    h.system.willSetFrame = nil
    #expect(h.frame(b)!.overlaps(h.frame(d)!))
    #expect(lies(b, inFrontOf: d, h))
    expectWindowsMatchLayout(h)
  }

  /// A Mac's raise does not lift a window over the one that has the keyboard. So what goes behind with the keyboard in it stays in front
  /// of whatever is raised, until the keyboard has moved into the view.
  @Test func theKeyboardInAWindowThatGoesBehindDoesNotKeepItInFront() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.raiseStopsBehindTheKeyWindow = true
    // The keyboard is in d, bottom right, which b is about to grow over; and of the two that are framed a was used last, so a gets it.
    for window in [b, c, a, d] { h.system.userFocus(window) }
    let group = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(group.rawValue)")
    #expect(Set(h.layout!.windowFrames.keys) == [a, b])
    #expect(h.system.focusedWindow() == a)
    #expect(h.frame(b)!.overlaps(h.frame(d)!))
    #expect(lies(b, inFrontOf: d, h))
    #expect(lies(a, inFrontOf: c, h))
    expectWindowsMatchLayout(h)
  }

  /// The same where macOS says only that another app has come forward, and nothing of a window: its focused window did not change.
  @Test func theSameWhenNoWindowIsReported() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.raiseStopsBehindTheKeyWindow = true
    h.system.echoes.focus = false
    for window in [b, c, a, d] { h.system.userFocus(window) }
    let group = h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!
    h.run("zoom-node \(group.rawValue)")
    #expect(h.system.focusedWindow() == a)
    #expect(lies(b, inFrontOf: d, h))
    #expect(lies(a, inFrontOf: c, h))
    expectWindowsMatchLayout(h)
  }

  /// And where it says only which window has the keyboard: from one window to another of the same app no app comes forward. (Every such
  /// report ends where the other kind does, `keyboardFocusMoved`.)
  @Test func aClickInTheViewBringsAllOfItInFront() {
    let h = Harness(settings: settings(behind: true))
    func open(_ app: String, _ pid: Int32, _ x: CGFloat) -> WindowID {
      h.system.open(app: app, pid: pid, frame: CGRect(x: x, y: 100, width: 600, height: 400))
    }
    let (a, b, d) = (open("Safari", 1001, 100), open("Safari", 1001, 200), open("Terminal", 1004, 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(d.rawValue) beside \(a.rawValue) right")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    for window in [d, a, b] { h.system.userFocus(window) }
    h.run("zoom")
    h.run("out")
    #expect(Set(h.layout!.windowFrames.keys) == [a, b])
    // Something behind comes forward by itself, over a. Then a click in a.
    h.system.raise(d)
    #expect(h.frame(a)!.overlaps(h.frame(d)!) && h.frame(b)!.overlaps(h.frame(d)!))
    #expect(lies(d, inFrontOf: b, h))
    h.system.userFocus(a)
    #expect(lies(b, inFrontOf: d, h))
    expectWindowsMatchLayout(h)
  }

  @Test func asItShipsNothingIsRaised() {
    let (h, a, b, c, d) = makeFour(settings(behind: false))
    for window in [b, c, d, a] { h.system.userFocus(window) }
    h.system.clearRaiseLog()
    h.run("zoom")
    h.run("out")
    h.run("show-all")
    #expect(h.system.raiseLog.isEmpty)
  }

  @Test func aWindowThatFloatsOverTheViewIsNotBuriedByTheRaise() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    let note = h.system.open(app: "Stickies", pid: 1005, frame: CGRect(x: 60, y: 500, width: 300, height: 200))
    h.run("pin \(note.rawValue)")
    for window in [b, c, d, a] { h.system.userFocus(window) }
    h.system.raise(note)
    h.run("zoom")
    h.run("out")
    #expect(lies(b, inFrontOf: c, h))
    #expect(lies(note, inFrontOf: b, h))
    #expect(lies(note, inFrontOf: a, h))
  }

  // MARK: Finding a window again

  @Test func aClickOnWhatShowsThroughBringsItIntoView() {
    let (h, a, _, c, _) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    h.run("zoom")
    h.system.clearFrameLog()
    h.beginStep()
    h.system.userClick(c)
    h.scheduler.runPending()
    // Someone who lives framed stays framed: the window clicked is the one that fills the screen now, moved once.
    #expect(h.layout?.windowFrames.keys.sorted() == [c])
    #expect(asked(h) == [c])
    #expect(h.movesInStep == [c: 1])
    #expect(h.jolts.isEmpty)
    #expect(h.system.focusedWindow() == c)
    #expect(h.system.windowsFrontToBack().first == c)
    #expect(h.controller.parked.contains(a))
    expectWindowsMatchLayout(h)
  }

  @Test func switchingToAnAppBehindBringsItsWindowIntoViewAndLeavesTheRest() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    h.run("zoom")
    let filled = h.frame(a)
    h.system.clearFrameLog()
    h.system.userFocus(d)
    h.scheduler.runPending()
    #expect(asked(h) == [d])
    // What filled the screen is as large as it was, behind: it has no slot to go to while it is out of view.
    #expect(h.frame(a) == filled)
    #expect(h.controller.parked == [a, b, c])
    h.system.clearFrameLog()
    h.run("show-all")
    #expect(asked(h) == [a, d])
    #expect(h.controller.parked.isEmpty)
    expectWindowsMatchLayout(h)
  }

  @Test func aWindowBehindThatIsMovedIsNobodysToPutBack() {
    for behind in [true, false] {
      let (h, a, _, c, _) = makeFour(settings(behind: behind))
      h.system.userFocus(a)
      h.run("zoom")
      h.scheduler.runPending()
      // Its app, another tool, macOS: as it ships that is a window pulled out of its corner, which goes back there.
      h.system.userMove(c, to: CGRect(x: 500, y: 300, width: 500, height: 300))
      #expect(h.scheduler.pendingKeys.contains { $0.hasPrefix("enforce-") } == !behind)
    }
  }

  // MARK: What floats

  @Test func aFloatingWindowStaysWhereItIsBehindWhatFillsTheScreen() {
    let h = Harness(settings: settings(behind: true))
    let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let note = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 900, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    let floated = h.frame(note)
    h.system.userFocus(note)
    h.system.userFocus(a)
    h.system.raise(note)
    h.system.clearFrameLog()
    // It counts as behind from before anything moves: what fills the screen does not grow underneath it.
    var wasInFront: Bool?
    h.system.willSetFrame = { window, _ in if window == a, wasInFront == nil { wasInFront = lies(a, inFrontOf: note, h) } }
    h.run("zoom")
    h.system.willSetFrame = nil
    #expect(wasInFront == true)
    #expect(asked(h) == [a])
    #expect(h.frame(note) == floated)
    #expect(lies(a, inFrontOf: note, h))
    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a])
    #expect(h.frame(note) == floated)
    #expect(!h.controller.parked.contains(note))
  }

  @Test func aWindowAloneOnTheDesktopThatFillsItIsLeftAsItIs() {
    let h = Harness(settings: settings(behind: true) { $0.soleFloatTakesDesktop = true })
    let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let note = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 900, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.runPending()
    let filling = h.frame(note)
    #expect(filling != CGRect(x: 900, y: 300, width: 400, height: 300))
    h.system.userFocus(a)
    h.run("zoom")
    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a])
    #expect(h.frame(note) == filling)
    #expect(!h.controller.parked.contains(note))
  }

  @Test func whatItsPersonSentAwayStillGoesAway() {
    let (h, a, _, _, _) = makeFour(settings(behind: true))
    let music = h.system.open(app: "Music", pid: 1006, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.system.userFocus(a)
    h.run("summon Music")
    #expect(h.system.isVisible(music))
    h.run("summon Music")
    #expect(h.controller.parked.contains(music))
    #expect(!h.system.isVisible(music))
  }

  // MARK: What cannot go wrong any more

  @Test func anAppThatHangsIsAskedNothingAndItsWindowIsNowhereButWhereItWas() {
    let (h, a, b, _, _) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    let arranged = frames(h)
    h.system.setUnresponsive(pid: 1002, true)
    h.run("zoom")
    #expect(h.frame(b) == arranged[b])
    #expect(h.controller.parked.contains(b))
    #expect(h.controller.windowsOwedAMove.isEmpty)
    // Arbor goes while the app still hangs.
    h.controller.shutdown()
    #expect(everyWindowIsOnADisplay(h))
  }

  @Test func aMoveOwedByAnAppThatHangsIsNoLongerOwedOnceItsWindowIsBehind() {
    let (h, a, b, _, _) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    h.system.setUnresponsive(pid: 1002, true)
    h.run("resize \(a.rawValue) bottom 60")
    #expect(h.controller.windowsOwedAMove == [b])
    h.run("zoom")
    #expect(h.controller.windowsOwedAMove.isEmpty)
    // It gets its place when it is framed again and its app answers.
    h.system.setUnresponsive(pid: 1002, false)
    h.run("zoom")
    expectWindowsMatchLayout(h)
  }

  @Test func anArborThatDiesLeavesEveryWindowOnADisplay() {
    for behind in [true, false] {
      let (h, a, _, _, _) = makeFour(settings(behind: behind))
      h.system.userFocus(a)
      h.run("zoom")
      // No shutdown: killed, crashed, the permission gone. What is on screen now is what its person is left with.
      #expect(everyWindowIsOnADisplay(h) == behind)
    }
  }

  @Test func aDisplayThatGoesHasNothingInItsCornerToSpill() {
    let (h, a, b, c, d) = makeFour(settings(behind: true), displays: [FakeWindowSystem.standardDisplay, side], at: side.frame.origin)
    h.system.userFocus(a)
    h.run("zoom")
    #expect(h.controller.workspaceID(containing: a) == side.id)
    #expect(everyWindowIsOnADisplay(h))
    h.system.unplug(side.id)
    h.scheduler.runPending()
    #expect(everyWindowIsOnADisplay(h))
    h.system.plug(side)
    h.scheduler.runPending()
    #expect(everyWindowIsOnADisplay(h))
    #expect(h.controller.workspaceID(containing: a) == side.id)
    h.run("home")
    #expect(h.controller.parked.isEmpty)
    for window in [a, b, c, d] { #expect(h.controller.layouts[side.id]?.windowFrames[window] == h.frame(window)) }
    expectWindowsMatchLayout(h)
    h.controller.shutdown()
    #expect(everyWindowIsOnADisplay(h))
  }

  // MARK: Sizes

  @Test func aWindowThatCannotFillItsSlotComesBackWithoutBeingWalkedThroughIt() {
    let h = Harness(settings: settings(behind: true))
    let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let small = h.system.open(app: "Calculator", pid: 1002, frame: CGRect(x: 300, y: 200, width: 230, height: 408))
    h.system.setMaximumSize(small, CGSize(width: 230, height: 408))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(small.rawValue) beside \(a.rawValue) right")
    let centred = h.frame(small)
    h.system.userFocus(a)
    h.run("zoom")
    h.system.clearFrameLog()
    h.run("zoom")
    #expect(asked(h) == [a])
    #expect(h.frame(small) == centred)
    #expect(h.controller.parked.isEmpty)
  }

  @Test func quittingWhileWindowsAreBehindGivesEachItsOwnSizeBack() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    h.run("zoom")
    h.controller.shutdown()
    for window in [a, b, c, d] { #expect(h.frame(window)?.size == CGSize(width: 600, height: 400)) }
    #expect(everyWindowIsOnADisplay(h))
  }

  // MARK: The switch itself

  @Test func turnedOffWhatWasLeftBehindGoesWhereWindowsOutOfViewGo() {
    let (h, a, b, c, d) = makeFour(settings(behind: true))
    h.system.userFocus(a)
    h.run("zoom")
    h.run("set outOfViewIsBehind off")
    for other in [b, c, d] { #expect(!h.system.isVisible(other)) }
    #expect(h.controller.parked == [b, c, d])
    expectWindowsMatchLayout(h)
    h.run("zoom")
    #expect(h.controller.parked.isEmpty)
    expectWindowsMatchLayout(h)
  }

  @Test func turnedOnWhatIsAwayComesBackWhenItIsFramed() {
    let (h, a, b, c, d) = makeFour(settings(behind: false))
    h.system.userFocus(a)
    let arranged = frames(h)
    h.run("zoom")
    h.system.clearFrameLog()
    h.run("set outOfViewIsBehind on")
    #expect(asked(h).isEmpty)
    for other in [b, c, d] { #expect(!h.system.isVisible(other)) }
    h.run("zoom")
    #expect(frames(h) == arranged)
    expectWindowsMatchLayout(h)
  }
}
