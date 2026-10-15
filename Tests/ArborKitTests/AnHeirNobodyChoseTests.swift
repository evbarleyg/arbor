import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The window with the keyboard goes, macOS picks one that Arbor keeps out of view, and Arbor picks an heir among the windows in view.
/// Not a window of an app that Arbor pauses for, or passes its keys through to: brought forward, the one pauses Arbor, which
/// brings every window on every display into view, and the other takes Arbor's keys away. Nobody chose either. The product
/// owner's: Arbor hands the keyboard to no app it pauses for or passes keys through to, unless that app is in front already. Such
/// a window is nobody's heir, and the next in the order gets the keyboard.
@Suite @MainActor struct AnHeirNobodyChoseTests {
  enum List: String, CaseIterable { case pauseFor, passThrough }

  /// Safari docked and out of view, the view on the Desktop. On it a game and, if `withMail`, Mail. A second Safari window has the
  /// keyboard: beside them, or alone on a second display. Neither of the two was ever used, and the game, top left, would be
  /// chosen for its place; or both were, the game last. (Not with a pause: what is used in a pause Arbor does not see.)
  func aGameInView(on list: List, displays: Int, withMail: Bool = true, usedLast: Bool = false)
    -> (Harness, game: WindowID, mail: WindowID?, safari: WindowID, f: WindowID)
  {
    var settings = Settings()
    if list == .pauseFor { settings.pauseForApps = ["com.example.game"] } else { settings.passThroughApps = ["com.example.game"] }
    let all = [FakeWindowSystem.standardDisplay, Workload.secondDisplay]
    let h = Harness(displays: Array(all.prefix(displays)), settings: settings)
    let game = h.system.open(app: "Game", pid: 21, frame: CGRect(x: 760, y: 100, width: 300, height: 300))
    let mail = withMail ? h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 1100, y: 100, width: 300, height: 300)) : nil
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let place = displays == 2 ? InViewOnAnyDisplayTests.place(on: all[1].frame, x: 200) : CGRect(x: 760, y: 500, width: 300, height: 300)
    let f = h.system.open(app: "Safari", pid: 12, frame: place)
    h.start()
    h.run("dock \(safari.rawValue) left")
    // The keyboard first: a view that moves away from under it would hand it to the game there and then.
    h.system.userFocus(f)
    h.run("desktop")
    #expect(!h.system.focusLog.contains { $0.window == game }, "nobody has given the game the keyboard")
    if usedLast, let mail {
      h.system.userFocus(mail)
      h.system.userFocus(game)
    }
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(game) && !h.controller.isPaused)
    return (h, game, mail, safari, f)
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] {
    h.system.moveLog[mark...].filter { $0.before != $0.after }
  }

  @Test(arguments: List.allCases, [1, 2]) func theNextInTheOrderGetsTheKeyboard(list: List, displays: Int) {
    let (h, _, mail, safari, f) = aGameInView(on: list, displays: displays)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail)
    #expect(!h.controller.isPaused && !h.system.isVisible(safari))
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// ⌘M, and ⌘H, after which macOS brings another app forward: here one whose window is out of view.
  @Test(arguments: List.allCases, ["minimize", "hide"]) func atAMinimizeAndAHideToo(list: List, going: String) {
    let (h, _, mail, safari, f) = aGameInView(on: list, displays: 2)
    let preview = h.system.open(app: "Preview", pid: 13, frame: InViewOnAnyDisplayTests.place(on: Workload.secondDisplay.frame, x: 800))
    h.system.userFocus(going == "hide" ? preview : f)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    if going == "hide" {
      h.system.setMinimized(f, true)  // nothing else is in view beside it
      h.system.userFocus(preview)
      h.scheduler.advance(by: 2)
      h.system.echoes.keyboard = false
      h.system.setHidden(pid: 13, true)
      h.system.userFocus(safari)
    } else {
      h.system.setMinimized(preview, true)
      h.system.userFocus(f)
      h.scheduler.advance(by: 2)
      h.system.setMinimized(f, true)
    }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail && !h.controller.isPaused && !h.system.isVisible(safari))
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [1, 2]) func thoughItWasUsedLast(displays: Int) {
    let (h, _, mail, _, f) = aGameInView(on: .passThrough, displays: displays, usedLast: true)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// And when nothing says who has the keyboard now.
  @Test(arguments: List.allCases) func alsoWhenNothingReportsTheNewFocus(list: List) {
    let (h, _, mail, safari, f) = aGameInView(on: list, displays: 2)
    h.system.echoes.keyboard = false
    h.system.close(f)
    h.system.focused = safari
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail && !h.controller.isPaused)
    expectWindowsMatchLayout(h)
  }

  /// The game's is the only window in view anywhere. Three answers were on offer, and the product owner chose the first.
  /// (a) The view follows to macOS's pick: "in view" means in view and able to be an heir, so this is "nothing is in view". The person
  /// closed a window and macOS went on to its sibling, as on a Mac alone: showing it is the least surprise.
  /// (b) Nothing moves and the keyboard stays where macOS put it: typing into a window nobody sees, the one thing that must not be.
  /// (c) The keyboard goes to Finder: that is the answer for a held view, where no view may move.
  @Test(arguments: List.allCases, [1, 2]) func withNoOtherInViewTheViewFollows(list: List, displays: Int) {
    let (h, _, _, safari, f) = aGameInView(on: list, displays: displays, withMail: false)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == safari && h.system.isVisible(safari))
    #expect(!h.controller.isPaused)
    expectWindowsMatchLayout(h)
  }

  /// The going is reported so late that the view has followed. It is not taken back to a view with nobody in it but the game, from
  /// where it would only have to follow again.
  @Test(arguments: List.allCases, [1, 2]) func aViewThatHasFollowedIsNotTakenBackToTheGameAlone(list: List, displays: Int) {
    let (h, _, _, safari, f) = aGameInView(on: list, displays: displays, withMail: false)
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    #expect(h.system.isVisible(safari))
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.focused == safari && !h.controller.isPaused)
    #expect(realMoves(h, since: mark).isEmpty, "there and back: \(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// Nor because of a game on another display: it is in view there, and nobody's heir. A control: it holds the old way against the
  /// question that is now asked of the other displays.
  @Test(arguments: List.allCases) func norBecauseOfAGameOnAnotherDisplay(list: List) {
    var settings = Settings()
    if list == .pauseFor { settings.pauseForApps = ["com.example.game"] } else { settings.passThroughApps = ["com.example.game"] }
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay], settings: settings)
    let second = Workload.secondDisplay.frame
    let game = h.system.open(app: "Game", pid: 21, frame: InViewOnAnyDisplayTests.place(on: second, x: 900))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: InViewOnAnyDisplayTests.place(on: second, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.system.userFocus(f)
    h.run("desktop")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari) && h.system.isVisible(game) && !h.controller.isPaused)
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    #expect(h.system.isVisible(safari))
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.focused == safari && !h.controller.isPaused)
    #expect(realMoves(h, since: mark).isEmpty, "there and back: \(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// Nor to a docked one. The view was on the game's half, with the keyboard on the other display.
  @Test func norToADockedGameAlone() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.game"]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay], settings: settings)
    let game = h.system.open(app: "Game", pid: 21, frame: CGRect(x: 100, y: 100, width: 300, height: 300))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: InViewOnAnyDisplayTests.place(on: Workload.secondDisplay.frame, x: 200))
    h.start()
    h.run("dock \(game.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(game.rawValue)")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(game) && !h.system.isVisible(safari))
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    #expect(h.system.isVisible(safari))
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.focused == safari)
    #expect(realMoves(h, since: mark).isEmpty, "there and back: \(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// A docked game in view, and the going reported in time: Mail, docked beside it, is the heir though the game lies top left.
  @Test func aDockedGameIsNoHeirEither() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.game"]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay], settings: settings)
    let game = h.system.open(app: "Game", pid: 21, frame: CGRect(x: 100, y: 100, width: 300, height: 300))
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 500, y: 100, width: 300, height: 300))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: InViewOnAnyDisplayTests.place(on: Workload.secondDisplay.frame, x: 200))
    h.start()
    h.system.userFocus(f)
    h.run("dock \(game.rawValue) left")
    h.run("dock \(mail.rawValue) beside \(game.rawValue) bottom")
    h.run("dock \(safari.rawValue) right")
    // By way of the game, so that it is the one used last, and Mail was never used.
    h.run("zoom \(game.rawValue)")
    h.run("out")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(game) && h.system.isVisible(mail) && !h.system.isVisible(safari) && !h.controller.isPaused)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail && !h.controller.isPaused)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  // MARK: Unless its app is in front already

  /// Three frames of an editor that keeps its own keys: `f` with the keyboard, `beside` in view, `away` out of view. And Mail, if asked for.
  func threeFrames(withMail: Bool) -> (Harness, beside: WindowID, away: WindowID, f: WindowID) {
    var settings = Settings()
    settings.passThroughApps = ["com.example.emacs"]
    let h = Harness(settings: settings)
    if withMail { _ = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 1100, y: 100, width: 300, height: 300)) }
    let away = h.system.open(app: "Emacs", pid: 31, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let beside = h.system.open(app: "Emacs", pid: 31, frame: CGRect(x: 760, y: 100, width: 300, height: 300))
    let f = h.system.open(app: "Emacs", pid: 31, frame: CGRect(x: 760, y: 500, width: 300, height: 300))
    h.start()
    h.run("dock \(away.rawValue) left")
    h.system.userFocus(f)
    h.run("desktop")
    h.scheduler.advance(by: 2)
    #expect(h.controller.isPassingThrough && h.system.focused == f && !h.system.isVisible(away) && h.system.isVisible(beside))
    return (h, beside, away, f)
  }

  /// The rule's reason is that such an app comes forward and takes the keys. One that is in front changes nothing by keeping them: no
  /// other app jumps forward, and no view moves while a frame is in view. A control: so it was before there was a rule to except from.
  @Test(arguments: [false, true], [false, true]) func aSiblingInViewIsTheHeir(withMail: Bool, goingFirst: Bool) {
    let (h, beside, away, f) = threeFrames(withMail: withMail)
    let mark = h.system.moveLog.count
    if goingFirst { h.system.echoes.keyboard = false }
    h.system.close(f)
    if goingFirst { h.system.userFocus(away) }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == beside && !h.system.isVisible(away))
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// A person's own command that moves the view takes the keyboard along, to whatever is there: they asked. A control.
  @Test func aCommandThatMovesTheViewStillTakesTheKeyboardAlong() {
    let (h, game, _, safari, _) = aGameInView(on: .passThrough, displays: 2, withMail: false)
    h.run("zoom \(safari.rawValue)")
    #expect(h.system.focused == safari)
    h.run("desktop")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == game)
  }
}
