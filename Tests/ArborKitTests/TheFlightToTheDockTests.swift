import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A person's ⌘M is never undone.
///
/// Measured on a hosted Mac, by key, by the yellow button and through Accessibility, with test windows and TextEdit: a window flies to the Dock for half a
/// second, in which its app answers nobody. When it has landed the app names its next window, and 0 to 32 ms later it reports the
/// minimizing. The window itself says that it is minimized from the landing on. And a raise, which is part of giving a window the keyboard,
/// fetches a minimized window out of the Dock. A held view sends the keyboard back to the window that is shown as soon as another is named: the
/// window flew to the Dock and straight back, in front of an audience.
@Suite @MainActor struct TheFlightToTheDockTests {
  /// The longest the report of a minimizing was seen to come after the naming of the next window.
  nonisolated static let gap = 0.032

  /// `[keynote | notes | keynote2]` with the view on `keynote`, which has the keyboard. `keynote2` is the same app's.
  func aFramedWindow(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) -> (
    h: Harness, keynote: WindowID, notes: WindowID, keynote2: WindowID
  ) {
    let h = Harness(displays: displays)
    let keynote = h.system.open(app: "Keynote", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let keynote2 = h.system.open(app: "Keynote", pid: 11, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(keynote2.rawValue) right")
    h.run("zoom \(keynote.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == keynote)
    #expect(!h.system.isVisible(notes) && !h.system.isVisible(keynote2))
    return (h, keynote, notes, keynote2)
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] { h.system.moveLog[mark...].filter { $0.before != $0.after } }

  // MARK: What the stand-in plays

  @Test func givenTheKeyboardAWindowThatHasJustLandedComesStraightBack() {
    let h = Harness()
    let a = h.system.open(app: "Keynote", pid: 11)
    let a2 = h.system.open(app: "Keynote", pid: 11)
    h.system.start()
    h.system.userFocus(a)
    h.system.landInTheDock(a)
    #expect(h.system.focused == a2, "the app names its next window")
    #expect(h.system.whereabouts(of: a) == .inTheDockOrGone, "and the window itself says where it is")
    h.system.focus(a)
    h.system.reportTheLanding()
    #expect(h.system.windows[a]?.snapshot.isMinimized == false)
    #expect(h.system.focused == a)
    #expect(h.system.whereabouts(of: a) == .here)
  }

  @Test func soDoesOneThatHasBeenThereForAnHour() {
    let h = Harness()
    let a = h.system.open(app: "Keynote", pid: 11)
    h.system.start()
    h.system.setMinimized(a, true)
    h.system.focus(a)
    #expect(h.system.windows[a]?.snapshot.isMinimized == false)
    #expect(h.system.focused == a)
  }

  /// The keyboard stays where it is, unless the window's app is the one in front.
  @Test func aRaiseWithoutTheKeyboardFetchesItAsWell() {
    let h = Harness()
    let a = h.system.open(app: "Keynote", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    h.system.start()
    h.system.userFocus(b)
    h.system.setMinimized(a, true)
    h.system.raise(a)
    #expect(h.system.windows[a]?.snapshot.isMinimized == false)
    #expect(h.system.focused == b)
  }

  @Test func leftAloneItStays() {
    let h = Harness()
    let a = h.system.open(app: "Keynote", pid: 11)
    h.system.start()
    h.system.userFocus(a)
    h.system.landInTheDock(a)
    h.system.reportTheLanding()
    #expect(h.system.windows[a]?.snapshot.isMinimized == true)
    #expect(h.system.whereabouts(of: a) == .inTheDockOrGone)
    #expect(h.system.whereabouts(of: WindowID(4711)) == .inTheDockOrGone, "there is no such window")
    h.system.setUnresponsive(pid: 11, true)
    #expect(h.system.whereabouts(of: a) == .unknown, "an app that hangs does not say")
  }

  // MARK: A held view

  /// In front of an audience: the window flew to the Dock and back.
  @Test(arguments: [0, 0.002, gap]) func onAHeldViewTheWindowThatIsShownStaysInTheDock(seconds: Double) {
    let (h, keynote, notes, keynote2) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    let (mark, asked, questions) = (h.system.moveLog.count, h.system.focusRequests.count, h.system.whereaboutsAsked.count)
    h.system.landInTheDock(keynote)
    #expect(h.system.whereaboutsAsked[questions...] == [keynote], "asked once: each question is a round trip to an app")
    h.scheduler.advance(by: seconds)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(h.system.windows[keynote]?.snapshot.isMinimized == true)
    #expect(!h.system.focusRequests[asked...].contains(keynote), "\(h.system.focusRequests[asked...])")
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(!h.system.isVisible(notes) && !h.system.isVisible(keynote2))
    #expect(h.controller.holdLevel == .view)
    #expect(h.controller.displaysHeldEmpty == [h.display])
    #expect(h.controller.holdMenu.first?.title == "The view is held: nothing is in it")
  }

  /// ⌘` is turned away as ever: the window that is shown says that it is there, and gets the keyboard back at once.
  @Test func aSwitchWithinTheAppIsStillSentBackAtOnce() {
    let (h, keynote, _, keynote2) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    h.system.userFocus(keynote2)
    #expect(h.system.focused == keynote)
    #expect(!h.system.isVisible(keynote2))
  }

  /// Nothing is in view on the held display. A window in view on another one is better than a window nobody sees.
  @Test func aWindowInViewOnAnotherDisplayGetsTheKeyboard() {
    let (h, keynote, _, _) = aFramedWindow(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1]
    let mail = h.system.open(
      app: "Mail", pid: 13, frame: CGRect(x: second.frame.minX + 200, y: second.frame.minY + 200, width: 500, height: 300))
    h.system.userFocus(keynote)
    h.run("hold")
    h.scheduler.advance(by: 1)
    let mark = h.system.moveLog.count
    h.system.landInTheDock(keynote)
    h.scheduler.advance(by: Self.gap)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(h.system.windows[keynote]?.snapshot.isMinimized == true)
    #expect(h.system.focused == mail)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
  }

  // MARK: Whoever else looks for somebody to give the keyboard to

  /// The window used last is the first choice, and it is the one that has gone. Its neighbour in the view gets the keyboard, at once.
  @Test func theChoiceGoesOnToTheNextWindowInView() {
    // `[a / c | Desktop | b / a2]`, where `a2` is a second Safari window, with the view on the left column and the keyboard in `a`.
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    let a2 = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(a2.rawValue) beside \(b.rawValue) bottom")
    h.system.userFocus(b)
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a && !h.system.isVisible(a2) && !h.system.isVisible(b))
    h.run("hold")
    h.scheduler.advance(by: 1)
    let asked = h.system.focusRequests.count
    h.system.landInTheDock(a)
    #expect(h.system.focused == c)
    h.scheduler.advance(by: Self.gap)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(h.system.windows[a]?.snapshot.isMinimized == true)
    #expect(!h.system.focusRequests[asked...].contains(a), "\(h.system.focusRequests[asked...])")
    #expect(h.system.focused == c && !h.system.isVisible(a2))
  }

  /// A call is kept in view, and the browser has just been clicked and lies over it. A press on the call's yellow button, which works from behind: Arbor
  /// looks at what is kept in view after every press, finds the call covered, and raises it as it lands.
  @Test func aWindowKeptInViewIsNotRaisedOutOfTheDock() {
    let (h, _, browser, call) = PinTests().makeHarness()
    h.system.userFocus(browser)
    h.scheduler.advance(by: 1)
    h.system.focus(browser)
    h.system.clearRaiseLog()
    h.system.landInTheDock(call)
    h.controller.pointerPressed()
    h.scheduler.advance(by: Self.gap)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(h.system.raiseLog.isEmpty, "\(h.system.raiseLog)")
    #expect(h.system.windows[call]?.snapshot.isMinimized == true)
  }

  // MARK: Whoever names a window gets it

  /// Go to… fetches a window out of the Dock because its person asked for it.
  @Test func aWindowAskedOutOfTheDockStillComes() {
    let (h, keynote, _, _) = aFramedWindow()
    h.system.setMinimized(keynote, true)
    h.scheduler.advance(by: 2)
    #expect(h.run("reveal \(keynote.rawValue)").ok)
    h.scheduler.advance(by: 2)
    #expect(h.system.windows[keynote]?.snapshot.isMinimized == false)
    #expect(h.system.focused == keynote && h.system.isVisible(keynote))
  }

  /// What a person asks for last counts, and nobody is asked anything: a command costs as many round trips as before.
  @Test(arguments: ["reveal", "zoom"]) func aCommandThatNamesAWindowAsksItNothing(command: String) {
    let (h, _, notes, _) = aFramedWindow()
    let (asked, questions) = (h.system.focusRequests.count, h.system.whereaboutsAsked.count)
    #expect(h.run("\(command) \(notes.rawValue)").ok)
    #expect(h.system.focusRequests[asked...].contains(notes))
    #expect(h.system.whereaboutsAsked.count == questions)
  }

  /// A request to an app that hangs waits with the app and is served when it wakes. A question first would time out, and nothing would be left there.
  @Test func aWindowOfAnAppThatHangsIsStillAskedToTakeTheKeyboardWhenItIsNamed() {
    let (h, _, notes, _) = aFramedWindow()
    h.system.setUnresponsive(pid: 12, true)
    let asked = h.system.focusRequests.count
    h.run("reveal \(notes.rawValue)")
    #expect(h.system.focusRequests[asked...].contains(notes))
  }

  // MARK: An app that does not say

  /// What cannot be found out is no leave to act, where it is Arbor that picks.
  @Test func anAppThatDoesNotAnswerIsNotSentTheKeyboard() {
    let (h, keynote, _, keynote2) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    h.system.setUnresponsive(pid: 11, true)
    let asked = h.system.focusRequests.count
    h.system.userFocus(keynote2)
    #expect(!h.system.focusRequests[asked...].contains(keynote))
  }

  /// A raise that is not made does not wait with the app until it wakes. So Arbor looks again.
  @Test func aWindowKeptInViewIsRaisedWhenItsAppWakes() {
    let (h, _, browser, call) = PinTests().makeHarness()
    h.system.userFocus(browser)
    h.scheduler.advance(by: 1)
    h.system.setUnresponsive(pid: 1003, true)
    h.system.clearRaiseLog()
    h.system.userClick(browser)
    h.scheduler.advance(by: 5)
    #expect(h.system.raiseLog.isEmpty)
    h.system.setUnresponsive(pid: 1003, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.raiseLog == [call])
    h.scheduler.advance(by: 2)
    #expect(!h.scheduler.pendingKeys.contains("raise-pins"), "and then it stops looking")
  }

  /// Not for ever.
  @Test func anAppThatNeverWakesIsLetBeAfterAMinute() {
    let (h, _, browser, _) = PinTests().makeHarness()
    h.system.userFocus(browser)
    h.scheduler.advance(by: 1)
    h.system.setUnresponsive(pid: 1003, true)
    h.system.userClick(browser)
    h.scheduler.advance(by: 90)
    #expect(!h.scheduler.pendingKeys.contains("raise-pins"))
  }

  // MARK: The way back from a summon

  /// Terminal is summoned over the editor. The editor's yellow button works from behind. Terminal is sent away as the editor lands: the keyboard was
  /// to go back to the editor.
  @Test func sentAwayASummonedWindowDoesNotFetchTheOneThatHadTheKeyboard() {
    let (h, editor, _, terminal) = SummonTests().makeHarness()
    #expect(h.run("summon Terminal").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == terminal)
    let asked = h.system.focusRequests.count
    h.system.landInTheDock(editor)
    #expect(h.run("summon Terminal").ok)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(h.system.windows[editor]?.snapshot.isMinimized == true)
    #expect(!h.system.focusRequests[asked...].contains(editor), "\(h.system.focusRequests[asked...])")
  }

  // MARK: The walks' net

  /// The story of the held view as a walk plays it, then the same with the fault done to the world as if Arbor had done it.
  @Test func theNetSpeaksWhenAMinimizedWindowIsBack() {
    let held = [
      "launch", "open 101 Keynote pid 1001 at 100 100 500 400", "open 102 Keynote pid 1001 at 800 300 500 400", "dock 101 left", "dock 102 right",
      "focus 101", "zoom 101", "settle", "do hold", "settle",
    ]
    func rules(fault: Bool) -> [String] {
      let runner = ChaosRunner()
      for line in held { _ = runner.step(ChaosAction(text: line)) }
      #expect(runner.controller.holdLevel == .view && runner.system.focused == WindowID(101))
      if fault { runner.beforeTheNextCheck = { $0.system.setMinimized(WindowID(101), false) } }
      return runner.step(ChaosAction(text: "minimize 101")).map(\.rule)
    }
    let asked = ChaosRunner.questionsAsked["undone", default: 0]
    #expect(!rules(fault: false).contains("minimize-undone"))
    #expect(rules(fault: true).contains("minimize-undone"))
    #expect(ChaosRunner.questionsAsked["undone", default: 0] >= asked + 2)
  }
}
