import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What a reader who built "a person's ⌘M is never undone" and ran it found, each as the story that showed it
/// (`TheFlightToTheDockTests` has the ground).
@Suite @MainActor struct ReviewFlightToTheDockTests {
  func aFramedWindow(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) -> (
    h: Harness, keynote: WindowID, notes: WindowID, keynote2: WindowID
  ) {
    TheFlightToTheDockTests().aFramedWindow(displays: displays)
  }

  func isInTheDock(_ window: WindowID, _ h: Harness) -> Bool { h.system.windows[window]?.snapshot.isMinimized == true }

  /// A window on the second display.
  func mail(_ h: Harness) -> WindowID {
    let second = h.system.displayList[1].frame
    return h.system.open(app: "Mail", pid: 13, frame: CGRect(x: second.minX + 200, y: second.minY + 200, width: 500, height: 300))
  }

  /// ⌘M as Arbor meets it: the landing, and the report a moment later.
  func minimize(_ window: WindowID, _ h: Harness) {
    h.system.landInTheDock(window)
    h.scheduler.advance(by: 0.004)
    h.system.reportTheLanding()
  }

  // MARK: What was not sent is not counted

  /// With the one window in view in the Dock there is nobody to send the keyboard to. Each look counted as a round of a fight all the same,
  /// three of them within the second, and for five seconds after that whoever took the keyboard out of view kept it.
  @Test(arguments: [0.1, 0.3, 1.0]) func backOutOfTheDockTheHoldStillSendsTheKeyboardBack(later: Double) {
    let (h, keynote, _, keynote2) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    minimize(keynote, h)
    h.scheduler.advance(by: later)
    h.system.setMinimized(keynote, false)
    h.scheduler.advance(by: 2 - later)
    #expect(h.system.focused == keynote && h.system.isVisible(keynote), "back by a click in the Dock")
    h.system.userFocus(keynote2)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == keynote, "the keyboard is in \(String(describing: h.system.focused))")
    #expect(!h.system.isVisible(keynote2))
    expectWindowsMatchLayout(h)
  }

  /// Round after round, as check-F58.sh does it on a Mac: the window is asked every time, however soon the next round comes.
  @Test(arguments: [3.0, 4.0, 6.0]) func minimizedAgainAndAgainItIsAskedEveryTime(apart: Double) {
    let (h, keynote, _, _) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    for round in 1...3 {
      #expect(h.system.focused == keynote, "round \(round)")
      let mark = h.system.whereaboutsAsked.count
      minimize(keynote, h)
      h.scheduler.advance(by: apart - 0.7)
      #expect(isInTheDock(keynote, h), "round \(round)")
      #expect(h.system.whereaboutsAsked[mark...].contains(keynote), "round \(round)")
      h.system.setMinimized(keynote, false)
      h.scheduler.advance(by: 0.7)
    }
  }

  /// While nobody can be sent the keyboard nobody is asked over and over either.
  @Test func anEmptyHeldViewAsksOnce() {
    let (h, keynote, _, _) = aFramedWindow()
    h.run("hold")
    h.scheduler.advance(by: 1)
    let (asked, requests) = (h.system.whereaboutsAsked.count, h.system.focusRequests.count)
    minimize(keynote, h)
    h.scheduler.advance(by: 5)
    #expect(Array(h.system.whereaboutsAsked[asked...]) == [keynote])
    #expect(h.system.focusRequests.count == requests)
    #expect(isInTheDock(keynote, h))
  }

  /// A second ⌘M within five seconds of the first, and by now there is a window in view on the other display.
  @Test func aSecondMinimizeSoonAfterFindsTheOtherDisplay() {
    let (h, keynote, _, _) = aFramedWindow(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    h.system.userFocus(keynote)
    h.run("hold")
    h.scheduler.advance(by: 1)
    minimize(keynote, h)
    h.scheduler.advance(by: 1)
    h.system.setMinimized(keynote, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == keynote)
    let mail = mail(h)
    h.system.userFocus(keynote)
    h.scheduler.advance(by: 0.5)
    minimize(keynote, h)
    h.scheduler.advance(by: 2)
    #expect(isInTheDock(keynote, h))
    #expect(h.system.focused == mail, "the keyboard is in \(String(describing: h.system.focused))")
  }

  // MARK: Nobody is asked twice in a breath

  /// `[safari | terminal]`, or `[safari / mail | terminal]`, with the view on the left and the keyboard in `safari`.
  func aViewBesideTheTerminal(withMail: Bool) -> (h: Harness, safari: WindowID, terminal: WindowID, mail: WindowID?) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 1001)
    let terminal = h.system.open(app: "Terminal", pid: 1002)
    let mail = withMail ? h.system.open(app: "Mail", pid: 1003) : nil
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(terminal.rawValue) right")
    if let mail { h.run("dock \(mail.rawValue) beside \(safari.rawValue) bottom") }
    h.run("zoom \(safari.rawValue)")
    if withMail { h.run("out") }
    h.system.userFocus(safari)
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(safari) && !h.system.isVisible(terminal))
    return (h, safari, terminal, mail)
  }

  /// The move of the view chose for itself, and then the window that had the keyboard before was asked again.
  @Test func theWayBackFromADockedWindowAsksOnce() {
    let (h, safari, _, _) = aViewBesideTheTerminal(withMail: false)
    #expect(h.run("summon Terminal").ok)
    h.scheduler.advance(by: 1)
    let mark = h.system.whereaboutsAsked.count
    #expect(h.run("summon Terminal").ok)
    #expect(Array(h.system.whereaboutsAsked[mark...]) == [safari])
    #expect(h.system.focused == safari)
    expectWindowsMatchLayout(h)
  }

  /// The one that had the keyboard has landed in the Dock meanwhile: it stays there, is asked once, and its neighbour in view gets the keyboard.
  @Test func theWayBackFromADockedWindowFetchesNothingOutOfTheDock() throws {
    let (h, safari, _, mail) = aViewBesideTheTerminal(withMail: true)
    #expect(h.run("summon Terminal").ok)
    h.scheduler.advance(by: 1)
    h.system.landInTheDock(safari)
    let mark = h.system.whereaboutsAsked.count
    #expect(h.run("summon Terminal").ok)
    let asked = Array(h.system.whereaboutsAsked[mark...])
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(isInTheDock(safari, h))
    #expect(asked.filter { $0 == safari }.count == 1, "\(asked)")
    #expect(h.system.focused == (try #require(mail)))
  }

  // MARK: Arbor's own picks

  /// The yellow button works from behind: the keyboard is on the other display. A space is named, not a window, and which of its windows gets
  /// the keyboard is Arbor's pick.
  @Test func goingToANamedSpaceFetchesNothingOutOfTheDock() {
    let (h, keynote, _, _) = aFramedWindow(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let mail = mail(h)
    h.system.userFocus(keynote)
    h.run("name talk")
    h.scheduler.advance(by: 1)
    h.system.userFocus(mail)
    h.scheduler.advance(by: 1)
    h.system.landInTheDock(keynote)
    h.run("go talk")
    h.scheduler.advance(by: 0.01)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(isInTheDock(keynote, h))
  }

  /// A view that moves takes the keyboard along, to the window used last among those it shows. ⌘M, and the key for the view before straight after it.
  @Test(arguments: [true, false]) func aViewThatMovesPicksNothingOutOfTheDock(everythingShows: Bool) {
    let (h, keynote, notes, _) = aFramedWindow()
    if everythingShows {
      h.run("show-all")
      h.system.userFocus(keynote)
    } else {
      h.run("zoom \(notes.rawValue)")
    }
    h.scheduler.advance(by: 1)
    h.system.landInTheDock(keynote)
    let mark = h.system.whereaboutsAsked.count
    #expect(h.run("back").ok)
    #expect(h.system.whereaboutsAsked[mark...].contains(keynote), "or this story no longer comes by the choice")
    h.scheduler.advance(by: 0.01)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(isInTheDock(keynote, h))
  }

  /// Pinned while it is out of view a window comes into view and is raised, which is the raise at the pin. Not out of the Dock.
  @Test func pinnedOutOfViewAWindowThatHasLandedIsNotRaisedOutOfTheDock() {
    let h = Harness()
    let keynote = h.system.open(app: "Keynote", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let chat = h.system.open(app: "Chat", pid: 14, frame: CGRect(x: 700, y: 200, width: 400, height: 300))
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("zoom \(keynote.rawValue)")
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(chat), "it floats on the Desktop, which is out of view")
    h.system.landInTheDock(chat)
    h.run("pin \(chat.rawValue)")
    h.scheduler.advance(by: 0.01)
    h.system.reportTheLanding()
    h.scheduler.advance(by: 2)
    #expect(isInTheDock(chat, h))
  }

  // MARK: The walks' net is cast

  /// A net that never asks its question catches nothing. It asks at every minimize, which ordinary walks seldom do (4 times in ten walks, the plain ones
  /// 31 times), and few of those could go wrong: a view has to be held. The floor is about half of what these twenty gave when this was written.
  @Test func theWalksMinimize() {
    let before = ChaosRunner.questionsAsked["undone", default: 0]
    for ordinary in [true, false] {
      for seed in UInt64(1)...10 {
        let runner = ChaosRunner()
        var generator = ChaosGenerator(seed: seed, ordinary: ordinary)
        for _ in 0..<200 { _ = runner.step(generator.next(runner)) }
      }
    }
    let asked = ChaosRunner.questionsAsked["undone", default: 0] - before
    #expect(asked >= 17, "minimize-undone was asked \(asked) times")
  }
}
