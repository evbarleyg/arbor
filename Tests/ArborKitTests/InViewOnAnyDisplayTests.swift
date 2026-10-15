import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The window with the keyboard goes, and a window in view gets the keyboard; only if nothing is in view does a view follow.
/// "In view" is asked of all displays: a display that shows nothing but its wallpaper after its last window closed is what a
/// person expects of closing the last window, and nobody at the other display asked for anything. The order is the product
/// owner's (collab/QUESTIONS.md, "closing a window takes nobody elsewhere; verdict, and one case more").
@Suite @MainActor struct InViewOnAnyDisplayTests {
  /// Main: Notes framed, Safari docked beside it and out of view. Second display: nothing but `f`, which floats and has the
  /// keyboard.
  func aLoneWindowOnTheSecondDisplay(of app: String, pid: Int32) -> (Harness, notes: WindowID, safari: WindowID, f: WindowID) {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let notes = h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: app, pid: pid, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(notes.rawValue)")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(notes))
    return (h, notes, safari, f)
  }

  static let third = DisplaySnapshot(
    id: DisplayID("third"), frame: CGRect(x: 3360, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 3360, y: 25, width: 1920, height: 1055), isMain: false)

  static func place(on display: CGRect, x: CGFloat) -> CGRect {
    CGRect(x: display.minX + x, y: display.minY + 200, width: 400, height: 300)
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] {
    h.system.moveLog[mark...].filter { $0.before != $0.after }
  }

  /// macOS picks the app's other window, out of view on the other display, where Notes is in view.
  @Test(arguments: ["close", "minimize"], [false, true])
  func aGoingOnOneDisplayMovesNoViewOnAnother(going: String, goingFirst: Bool) {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let mark = h.system.moveLog.count
    if goingFirst { h.system.echoes.keyboard = false }
    if going == "close" { h.system.close(f) } else { h.system.setMinimized(f, true) }
    if goingFirst { h.system.userFocus(safari) }
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(!h.system.isVisible(safari))
    #expect(h.system.focused == notes)
    expectWindowsMatchLayout(h)
  }

  /// And when nothing says who has the keyboard now.
  @Test func norWhenNothingReportsTheNewFocus() {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let mark = h.system.moveLog.count
    h.system.echoes.keyboard = false
    h.system.close(f)
    h.system.focused = safari
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(h.system.focused == notes)
    expectWindowsMatchLayout(h)
  }

  /// Its app's last window: macOS picks none, and after a person's own act macOS decides (board 0.20). Arbor steps in where
  /// macOS picks a window that Arbor keeps out of view, and only there. A control: so it was before.
  @Test func closingAnAppsLastWindowBringsNoAppForwardOnAnotherDisplay() {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    let (asked, mark) = (h.system.focusLog.count, h.system.moveLog.count)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == nil)
    #expect(h.system.focusLog.count == asked)
    #expect(realMoves(h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// A window beside the one that went comes first, whichever was used last: the eyes and the pointer are there. A control: so
  /// it was while only that display was asked.
  @Test(arguments: [false, true]) func aWindowInViewOnTheSameDisplayComesFirst(theOtherDisplaysWasUsedLast: Bool) {
    let (h, notes, _, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let second = h.system.displayList[1].frame
    let beside = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: second, x: 800))
    h.system.userFocus(theOtherDisplaysWasUsedLast ? beside : notes)
    h.system.userFocus(theOtherDisplaysWasUsedLast ? notes : beside)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == beside)
    #expect(realMoves(h, since: mark).isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// Among several there, the one used last. A control too.
  @Test(arguments: [false, true]) func ofSeveralOnOneDisplayTheOneUsedLastGetsIt(theLeftOne: Bool) {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let second = h.system.displayList[1].frame
    let left = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: second, x: 700))
    let right = h.system.open(app: "Music", pid: 15, frame: Self.place(on: second, x: 1200))
    h.system.userFocus(theLeftOne ? right : left)
    h.system.userFocus(theLeftOne ? left : right)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == (theLeftOne ? left : right))
    expectWindowsMatchLayout(h)
  }

  /// With none there, the display of the window that macOS picked comes next: that is where its app goes on. Mail, on a display
  /// that comes before it in every list, was used after Notes.
  @Test(arguments: ["the next window is named first", "the going is reported first", "nothing names the next window"])
  func thenTheDisplayOfTheWindowThatMacOSPicked(order: String) {
    let third = Self.third
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay, third])
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 11, frame: Self.place(on: third.frame, x: 100))
    let safari = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: third.frame, x: 600))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(notes.rawValue)")
    h.system.userFocus(mail)
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(notes) && h.system.isVisible(mail))
    let mark = h.system.moveLog.count
    if order != "the next window is named first" { h.system.echoes.keyboard = false }
    h.system.close(f)
    if order == "the going is reported first" { h.system.userFocus(safari) }
    if order == "nothing names the next window" { h.system.focused = safari }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// With none there either, any other display.
  @Test func thenAnyOtherDisplay() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay, Self.third])
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: Self.third.frame, x: 600))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.system.cursor = CGPoint(x: Self.third.frame.midX, y: Self.third.frame.midY)  // whose view `desktop` is about
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && h.system.isVisible(mail))
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// The going is reported so late that the view has followed macOS's pick. It goes back, and the order is the same.
  @Test func aGoingReportedLateStillPrefersTheDisplayOfTheWindowThatWent() {
    let (h, _, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let beside = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: h.system.displayList[1].frame, x: 800))
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    #expect(h.system.isVisible(safari))
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari))
    #expect(h.system.focused == beside)
    expectWindowsMatchLayout(h)
  }

  /// Nor does the view stay where it followed to because nothing would be in view on ITS display: Mail is in view on the other.
  @Test func aGoingReportedLateTakesTheViewBackWhileAWindowIsInViewAnywhere() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    let mail = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: second, x: 800))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari))
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    #expect(h.system.isVisible(safari))
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari))
    #expect(h.system.focused == mail)
    expectWindowsMatchLayout(h)
  }

  /// But with nothing else in view anywhere it stays: the window that is going does not count. A control.
  @Test func aGoingReportedLateLeavesTheViewWhereItFollowedToWithNothingElseInView() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.focused == safari)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  /// ⌘H: macOS brings another app forward, and its window is out of view on the other display.
  @Test func hidingTheOnlyAppOnADisplayMovesNoViewOnAnother() {
    let (h, notes, safari, _) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    let mark = h.system.moveLog.count
    h.system.echoes.keyboard = false
    h.system.setHidden(pid: 13, true)
    h.system.userFocus(safari)
    h.scheduler.advance(by: 2)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    #expect(h.system.focused == notes && !h.system.isVisible(safari))
    expectWindowsMatchLayout(h)
  }

  /// Nor does a docked window that is going count as in view. A control too.
  @Test func norDoesADockedWindowThatIsGoingCountAsInView() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: h.system.displayList[1].frame, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("desktop")
    h.run("dock \(f.rawValue) left")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari) && h.system.isVisible(f))
    h.system.userFocus(safari)
    h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
    let mark = h.system.moveLog.count
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.focused == safari)
    #expect(realMoves(h, since: mark).isEmpty, "\(realMoves(h, since: mark))")
    expectWindowsMatchLayout(h)
  }

  // MARK: Whose display the next key means
  //
  // The product owner's: after Arbor has handed the keyboard across displays, the next key of Arbor's ends it, whatever it did. If that
  // key names no display and no window it means the display of the going; if it acts on the focused window it acts on the heir, where
  // the heir is. From the key after that, a key means the display the keyboard is on. A key is an act of its moment: the eye is on
  // the display of the going for one beat, and nobody who uses only the keyboard may be locked out of a display.
  // The hand-over across was a stopgap for want of a window there. If that one key brings into view, on the display of the going, a
  // window that can be an heir, that window gets the keyboard, macOS's own pick first: and then there is no special case left.
  // Thirty seconds at most: whoever comes back later sees the heir lit on the other display and means that one.

  /// The keyboard was in `f`, on the second display. `f` closes and Notes, on the main display, gets the keyboard. macOS's pick is out
  /// of view beside Notes, or on the second display (its space is named "web"), which then shows its wallpaper.
  /// The pointer was left on the main display, so that it is not the pointer that says "the second". Where a test expects the main
  /// one, `thePointerRestsOnTheSecondDisplay`, so that it is not the pointer that says "the main" either.
  func handedAcross(thePickIsOnTheSecondDisplay: Bool, slowly: Bool = false, thePointerRestsOnTheSecondDisplay: Bool = false)
    -> (Harness, notes: WindowID, mail: WindowID)
  {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let notes = h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let mail = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 200, y: 150, width: 600, height: 400))
    let there = thePickIsOnTheSecondDisplay ? Self.place(on: second, x: 900) : CGRect(x: 300, y: 200, width: 600, height: 400)
    let safari = h.system.open(app: "Safari", pid: 12, frame: there)
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(safari.rawValue) \(thePickIsOnTheSecondDisplay ? "left" : "beside \(mail.rawValue) bottom")")
    if thePickIsOnTheSecondDisplay {
      h.system.cursor = CGPoint(x: second.midX, y: second.midY)
      h.run("zoom \(safari.rawValue)")
      h.run("name web")
      h.run("desktop")
    }
    h.system.cursor = thePointerRestsOnTheSecondDisplay ? CGPoint(x: second.midX, y: second.midY) : CGPoint(x: 300, y: 300)
    h.run("zoom \(notes.rawValue)")
    h.scheduler.advance(by: 1)  // the hand leaves the pointer: whichever was touched last leads, and a tie is the pointer's
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && !h.system.isVisible(mail) && h.system.isVisible(notes))
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
    h.system.focusIsSlow = slowly
    h.system.close(f)
    if slowly {
      // macOS has been asked and is not there yet. Something makes Arbor look who has the keyboard: it is still macOS's own pick.
      #expect(h.system.focused == safari && h.system.slowFocus == notes)
      h.controller.keyboardFocusMoved()
      #expect(h.controller.displayForCommands(from: .script) == Workload.secondDisplay.id, "already on the way")
      h.system.finishSlowFocus()
    }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes && !h.system.isVisible(safari))
    // Asking ends nothing. Without this, a set-up that handed nothing across would make every "it has ended" below pass.
    #expect(h.controller.displayForCommands(from: .script) == Workload.secondDisplay.id)
    return (h, notes, mail)
  }

  /// The eyes are where the window went. That Arbor handed the keyboard to another display is not the person going there.
  @Test(arguments: [false, true]) func aKeyThatNamesNoDisplayStillMeansTheDisplayWhereTheWindowWent(thePickIsOnTheSecondDisplay: Bool) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: thePickIsOnTheSecondDisplay)
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
    let view = h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.camera
    h.run("show-all", from: .shortcut)
    #expect(h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.camera == view, "the main display's view is nobody's business")
    expectWindowsMatchLayout(h)
  }

  /// Once. The key after it means the display the keyboard is on, though the first found nothing to do. Also where no key is pressed
  /// for it, and no count of presses could tell: a script's commands, a URL's.
  @Test(arguments: ["show-all", "out", "back"], [true, false])
  func theKeyAfterThatMeansTheDisplayTheKeyboardIsOn(first: String, pressed: Bool) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false, thePointerRestsOnTheSecondDisplay: true)
    if pressed { h.system.keyDown() }
    h.run(first, from: pressed ? .shortcut : .script)
    if pressed { h.system.keyDown() }
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
    #expect(h.run("out", from: .shortcut).ok, "Notes is framed on the main display: nobody is locked out of it")
    expectWindowsMatchLayout(h)
  }

  /// And where the first did something: it floated the heir.
  @Test(arguments: [true, false]) func alsoAfterAKeyThatDidSomething(pressed: Bool) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false, thePointerRestsOnTheSecondDisplay: true)
    if pressed { h.system.keyDown() }
    #expect(h.run("toggle-float", from: pressed ? .shortcut : .script).ok)
    if pressed { h.system.keyDown() }
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  // The want ends, and the stopgap with it.

  /// `out` on the second display brings Safari, macOS's own pick, into view there. It gets the keyboard, typing lands in it, and `back`
  /// goes back on the same display: two keys do not change displays halfway.
  @Test func theWindowThatTheKeyBringsIntoViewThereGetsTheKeyboard() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    let (main, second) = (FakeWindowSystem.standardDisplay.id, Workload.secondDisplay.id)
    let views = h.controller.workspaces.mapValues(\.camera)
    #expect(h.press("out").ok)
    h.scheduler.advance(by: 1)
    let safari = h.system.focused
    #expect(safari.flatMap { h.controller.workspaces[second]?.isDocked($0) } == true, "the window that came into view has the keyboard")
    #expect(h.controller.workspaces[main]?.camera == views[main])
    #expect(h.press("back").ok)
    #expect(h.controller.workspaces[second]?.camera == views[second] && h.controller.workspaces[main]?.camera == views[main])
    expectWindowsMatchLayout(h)
  }

  /// ⌃⌥Space as it is pressed, a tap: everything shows on the second display and stays, and Safari gets the keyboard.
  @Test func atATapOnShowEverythingToo() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.key("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.system.focused != notes && h.system.focused.flatMap { h.controller.workspaces[Workload.secondDisplay.id]?.isDocked($0) } == true)
  }

  /// Held, looked, let go: the view is back where it was, nothing has come into view, and the keyboard stays where it is.
  /// It was that one key all the same: nothing goes on waiting.
  @Test func aPeekThatGoesBackBringsNothingIntoView() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    let views = h.controller.workspaces.mapValues(\.camera)
    h.keyDown("ctrl+opt+space")
    #expect(h.controller.workspaces[Workload.secondDisplay.id]?.camera != views[Workload.secondDisplay.id], "it looks where the window went")
    #expect(!h.scheduler.pendingKeys.contains("handed-across"))
    h.scheduler.advance(by: 2)
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes && h.controller.workspaces.mapValues(\.camera) == views)
    expectWindowsMatchLayout(h)
  }

  /// The key is down, the pointer is pressed, the key comes up. Everything shows and stays, and the keyboard too: a click has fallen.
  @Test func aPressOfThePointerWhileTheKeyIsDownEndsItToo() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.keyDown("ctrl+opt+space")
    h.controller.pointerPressed()
    h.keyUp("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes)
  }

  /// Brought into view, not merely in view: a window has opened there meanwhile, behind, as a chat's does. The key floats the heir, and
  /// the keyboard stays in it.
  @Test func aWindowThatOpenedThereByItselfIsNotWhatTheKeyBrought() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: false)
    h.system.echoes.keyboard = false
    let chat = h.system.open(app: "Chat", pid: 15, frame: Self.place(on: h.system.displayList[1].frame, x: 300))
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(chat) && h.system.focused == notes)
    #expect(h.controller.displayForCommands(from: .script) == Workload.secondDisplay.id, "it still holds")
    #expect(h.press("toggle-float").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes)
  }

  /// Tapped twice, as scripts/mac-shell/check-a-going-on-two-displays.sh taps it: the first finds nothing to show on the emptied display and
  /// leaves the main one alone, the second follows the keyboard.
  @Test func tappedTwiceTheSecondTapFollowsTheKeyboard() {
    let (h, notes, mail) = handedAcross(thePickIsOnTheSecondDisplay: false, thePointerRestsOnTheSecondDisplay: true)
    h.key("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(mail) && h.system.focused == notes, "the main display's view is nobody's business")
    h.key("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(mail) && h.system.focused == notes)
    expectWindowsMatchLayout(h)
  }

  /// A letter typed into the heir, then the tap: everything shows on the main display, and the second keeps its view.
  @Test func aTapAfterALetterFollowsTheKeyboard() {
    let (h, notes, mail) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    let view = h.controller.workspaces[Workload.secondDisplay.id]?.camera
    h.system.type(keys: 1)
    h.key("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(mail) && h.system.focused == notes)
    #expect(h.controller.workspaces[Workload.secondDisplay.id]?.camera == view)
    expectWindowsMatchLayout(h)
  }

  /// macOS's own pick first, though another window that comes into view with it was used after it.
  @Test func macOSsOwnPickComesFirst() {
    let (h, _, _, pick, other) = twoComeIntoView(theOtherIsAGame: false)
    #expect(h.press("out").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == pick, "not \(other), which was used last")
  }

  /// Chosen as any heir is: not a window of an app that Arbor passes its keys through to. The pick has been minimized meanwhile.
  @Test func aGameThatComesIntoViewIsNoHeirHereEither() {
    let (h, notes, _, pick, _) = twoComeIntoView(theOtherIsAGame: true)
    h.system.echoes.keyboard = false
    h.system.setMinimized(pick, true)
    #expect(h.press("out").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes)
  }

  /// Notes framed on the main display with the keyboard, handed across. On the second: the pick and another window docked in one column, out of view.
  func twoComeIntoView(theOtherIsAGame: Bool) -> (Harness, notes: WindowID, f: WindowID, pick: WindowID, other: WindowID) {
    var settings = Settings()
    settings.passThroughApps = ["com.example.game"]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay], settings: settings)
    let second = h.system.displayList[1].frame
    let notes = h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let pick = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 900))
    let other = h.system.open(app: theOtherIsAGame ? "Game" : "Mail", pid: 14, frame: Self.place(on: second, x: 1300))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(pick.rawValue) left")
    h.run("dock \(other.rawValue) beside \(pick.rawValue) bottom")  // one column beside the Desktop, whose view shows neither
    h.system.userFocus(pick)
    h.system.userFocus(other)
    h.system.userFocus(f)
    h.system.cursor = CGPoint(x: second.midX, y: second.midY)
    h.run("desktop")
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(pick) && !h.system.isVisible(other) && h.system.isVisible(notes))
    // Nothing names the next window, so the pick does not count as used after the other: it comes first because macOS picked it.
    h.system.echoes.keyboard = false
    h.system.close(f)
    h.system.focused = pick
    h.scheduler.advance(by: 2)
    h.system.echoes.keyboard = true
    #expect(h.system.focused == notes && h.controller.displayForCommands(from: .script) == Workload.secondDisplay.id)
    return (h, notes, f, pick, other)
  }

  /// Only that one key, and only while it holds. A key typed into the heir has ended it: `out` then means the main display, and whatever
  /// is in view on the second is nobody's business.
  @Test func notOnceAKeyHasBeenTypedIntoTheHeir() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    let view = h.controller.workspaces[Workload.secondDisplay.id]?.camera
    h.system.type(keys: 1)
    #expect(h.press("out").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes && h.controller.workspaces[Workload.secondDisplay.id]?.camera == view)
  }

  /// The minimap's key twice: up, and away. It brings no window into view, so the second press means the display the keyboard is on, and
  /// still puts away the one that the first raised.
  @Test func theMinimapAskedForTwiceIsPutAway() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    #expect(h.press("minimap").ok)
    #expect(h.overlays.minimaps.keys.sorted() == [Workload.secondDisplay.id])
    #expect(h.press("minimap").ok)
    #expect(h.overlays.minimaps.isEmpty, "\(h.overlays.minimaps.keys.sorted())")
  }

  // Thirty seconds.

  @Test(arguments: [29.0, 31.0]) func itLastsThirtySeconds(later seconds: Double) {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: seconds > 30)
    let (moves, lines) = (h.system.moveLog.count, h.overlays.headsUp)
    h.scheduler.advance(by: seconds - 2)  // two have passed in the set-up
    #expect(h.system.moveLog.count == moves && h.overlays.headsUp.keys == lines.keys && h.system.focused == notes, "nothing is said or moved")
    h.system.keyDown()
    let expected = seconds > 30 ? FakeWindowSystem.standardDisplay.id : Workload.secondDisplay.id
    #expect(h.controller.displayForCommands(from: .shortcut) == expected)
  }

  /// Nothing goes on waiting once it is over, or once Arbor stops.
  @Test(arguments: ["a key", "a click", "a stop"]) func nothingWaitsOnceItIsOver(by what: String) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false)
    #expect(h.scheduler.pendingKeys.contains("handed-across"))
    switch what {
    case "a key": h.press("out")
    case "a click": h.controller.pointerPressed()
    default: h.controller.shutdown()
    }
    #expect(!h.scheduler.pendingKeys.contains("handed-across"))
  }

  /// A question is no key: a menu that names the display its items act on, `state`, `status`.
  @Test func askingEndsNothing() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    _ = h.controller.displayForCommands(from: .shortcut)
    h.run("state")
    h.run("status", from: .shortcut)
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
  }

  /// `float` acts on Notes, on the main display, and `undo` takes that back: it does not go looking on the other display. A control:
  /// so it was before; it was red on a version in which a key for the focused window ended nothing.
  @Test func undoTakesBackWhatTheKeyBeforeItDid() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.system.keyDown()
    #expect(h.run("float", from: .shortcut).ok)
    h.system.keyDown()
    h.run("undo", from: .shortcut)
    #expect(h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.isDocked(notes) == true)
  }

  /// Whoever types there is there. The press that runs a shortcut is one; more than that is typing, as for who leads.
  /// The first key typed. What runs without a press, a script or a URL, has no press of its own to allow for.
  @Test(arguments: [true, false]) func typingInTheHeirIsBeingThere(thenAShortcut: Bool) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    h.system.type(keys: 1)
    if thenAShortcut { h.system.keyDown() }
    #expect(h.controller.displayForCommands(from: thenAShortcut ? .shortcut : .script) == FakeWindowSystem.standardDisplay.id)
  }

  /// ⌃⌥Space as it is pressed: a peek, which takes the command's place, and no command runs. It is that key all the same. Here it
  /// brings nothing into view: the second display is empty.
  @Test func aTapOnShowEverythingIsThatKeyToo() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false, thePointerRestsOnTheSecondDisplay: true)
    let view = h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.camera
    h.key("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.camera == view, "it meant the display of the going")
    #expect(h.controller.displayForCommands(from: .script) == FakeWindowSystem.standardDisplay.id)
  }

  /// Whoever goes to a space by its name has gone there, and the keyboard goes along, also where that is the display the key meant anyway.
  @Test func goingToASpaceThereTakesTheKeyboardAlong() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.system.keyDown()
    #expect(h.run("go web", from: .shortcut).ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused != notes && h.system.focused.flatMap { h.frame($0) }.map { $0.minX >= Workload.secondDisplay.frame.minX } == true)
  }

  /// By the person's own word, so also to an app that is nobody's heir: they named its space. What the key brings into view would not
  /// get the keyboard by itself here.
  @Test func alsoToASpaceThatHoldsOnlyAGame() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.game"]
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay], settings: settings)
    let second = h.system.displayList[1].frame
    let notes = h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let game = h.system.open(app: "Game", pid: 14, frame: Self.place(on: second, x: 900))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(game.rawValue) left")
    h.system.cursor = CGPoint(x: second.midX, y: second.midY)
    h.run("zoom \(game.rawValue)")
    h.run("name games")
    h.run("desktop")
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.run("zoom \(notes.rawValue)")
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == f && !h.system.isVisible(safari) && !h.system.isVisible(game))
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes && h.controller.displayForCommands(from: .script) == Workload.secondDisplay.id)
    #expect(h.press("go games").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == game)
  }

  /// A key that starts from the focused window says what it has to say where that window is.
  @Test(arguments: ["rotate", "grow", "shrink", "swap right"])
  func theLineOfAKeyForTheFocusedWindowShowsWhereThatWindowIs(key: String) {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.system.keyDown()
    _ = h.run(key, from: .shortcut)
    #expect(h.overlays.headsUp[FakeWindowSystem.standardDisplay.id] != nil && h.overlays.headsUp[Workload.secondDisplay.id] == nil)
  }

  /// ⌘H. macOS brings Mail forward, whose window is out of view, and says so in two ways that come in either order. The word that its
  /// app is in front comes after Arbor has asked for Notes, and is no news of the person.
  @Test func norTheLateWordThatTheAppOfMacOSsPickIsInFront() {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    h.system.echoes.keyboard = false
    h.system.focusIsSlow = true
    h.system.setHidden(pid: 13, true)
    h.system.focused = safari
    h.controller.windowFocused(safari)
    #expect(h.system.slowFocus == notes)
    h.system.activate(bundleID: "com.example.safari", name: "Safari")
    h.system.finishSlowFocus()
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes)
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
  }

  /// An heir on the same display is no hand-over across, and a key that fails there goes on naming the focused window's display.
  @Test func anHeirOnTheSameDisplayChangesNoWords() {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    let beside = h.system.open(app: "Mail", pid: 14, frame: Self.place(on: h.system.displayList[1].frame, x: 800))
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == beside)
    h.system.keyDown()
    let said = h.run("out", from: .shortcut)
    #expect(!said.ok && said.message.hasSuffix("on the focused window's display"), "\(said.message)")
  }

  /// ⌘M in the heir, whose app goes on naming it: the window went on the main display, and that is what the next key means.
  @Test func norDoesItOutliveTheHeirsOwnGoing() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    h.system.echoes.keyboard = false
    h.system.setMinimized(notes, true)
    h.scheduler.advance(by: 2)
    h.system.keyDown()
    #expect(h.system.focused == notes)
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// A key that fails says which display it chose, because the other may have been meant. Here it is not the focused window's.
  @Test func aKeyThatFailsDoesNotNameTheWrongDisplay() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false)
    h.system.keyDown()
    let said = h.run("out", from: .shortcut)
    #expect(!said.ok && !said.message.contains("display"), "\(said.message)")
  }

  /// Nor where macOS picked nobody, and the key means the display where the window went: there is no focused window to speak of.
  @Test func norWhereNobodyHasTheKeyboard() {
    let (h, _, _, f) = aLoneWindowOnTheSecondDisplay(of: "Preview", pid: 13)
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    h.system.close(f)
    h.scheduler.advance(by: 2)
    h.system.keyDown()
    #expect(h.system.focused == nil && h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
    let said = h.run("out", from: .shortcut)
    #expect(!said.ok && !said.message.contains("display"), "\(said.message)")
  }

  /// It is set on each road to an heir: with the going in time, with nothing naming the next window, and at a view taken back.
  @Test(arguments: ["nothing names the next window", "the going is reported late"]) func onTheOtherRoadsToo(road: String) {
    let (h, notes, safari, f) = aLoneWindowOnTheSecondDisplay(of: "Safari", pid: 12)
    h.system.cursor = CGPoint(x: 300, y: 300)
    h.scheduler.advance(by: 1)
    h.system.userFocus(f)
    h.system.keyDown()
    h.scheduler.advance(by: 2)
    if road == "the going is reported late" {
      h.system.userFocus(safari)
      h.scheduler.advance(by: Controller.timeForAGoing + 0.01)
      h.system.close(f)
    } else {
      h.system.echoes.keyboard = false
      h.system.close(f)
      h.system.focused = safari
    }
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes)
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
  }

  /// What macOS says again about the hand-over itself ends nothing: the heir's app comes forward, the heir is named once more.
  @Test func norDoTheEchoesOfTheHandOverEndIt() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.system.activate(bundleID: "com.example.notes", name: "Notes")
    h.controller.windowFocused(notes)
    h.scheduler.advance(by: 2)
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
  }

  @Test func norWhomMacOSNamesWhileTheKeyboardIsOnItsWay() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: true, slowly: true)
    #expect(h.controller.displayForCommands(from: .shortcut) == Workload.secondDisplay.id)
  }

  /// The display where the window went is unplugged: there is nothing left to mean.
  @Test func norDoesItOutliveItsDisplay() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false)
    h.system.unplug(Workload.secondDisplay.id)
    h.scheduler.advance(by: 5)
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// The heir's display is unplugged, and the heir lands beside where the window went, in view. Showing everything there takes the keyboard
  /// from nobody.
  @Test func norTheHeirsDisplay() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    h.system.unplug(FakeWindowSystem.standardDisplay.id)
    h.scheduler.advance(by: 5)
    #expect(!h.scheduler.pendingKeys.contains("handed-across") && h.system.focused == notes)
    #expect(h.press("show-all").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.focused == notes)
  }

  @Test func norDoesItComeBackWithItsDisplay() {
    let (h, _, _) = handedAcross(thePickIsOnTheSecondDisplay: false)
    h.system.unplug(Workload.secondDisplay.id)
    h.scheduler.advance(by: 5)
    h.system.plug(Workload.secondDisplay)
    h.scheduler.advance(by: 5)
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// A key that acts on the focused window goes on meaning the window that has the keyboard. A control.
  @Test func aKeyForTheFocusedWindowMeansTheWindowWithTheKeyboard() {
    let (h, notes, _) = handedAcross(thePickIsOnTheSecondDisplay: true)
    #expect(h.run("float", from: .shortcut).ok)
    #expect(h.controller.workspaces[FakeWindowSystem.standardDisplay.id]?.isFloating(notes) == true)
  }

  /// Gone elsewhere and come back to that very window by themselves, they are there. By way of another app, or of another window of
  /// the same one, at which no app comes forward.
  @Test(arguments: [false, true]) func norDoesItComeBackWithTheKeyboard(withinOneApp: Bool) {
    let (h, notes, mail) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    h.system.userFocus(withinOneApp ? h.system.open(app: "Notes", pid: 11, frame: CGRect(x: 400, y: 300, width: 300, height: 300)) : mail)
    h.scheduler.advance(by: 1)
    h.system.userFocus(notes)
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// The keyboard has moved on and nothing has said so yet: ⌘Tab to an app whose focused window is the same as ever.
  @Test func norDoesItHoldOnceAnotherWindowHasTheKeyboardUnreported() {
    let (h, _, mail) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    h.system.focused = mail
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// Until the person goes elsewhere: to another window, to another app, or with the pointer.
  @Test(arguments: ["another window", "another app", "a click"]) func untilThePersonGoesElsewhere(by what: String) {
    let (h, _, mail) = handedAcross(thePickIsOnTheSecondDisplay: true, thePointerRestsOnTheSecondDisplay: true)
    switch what {
    case "another window": h.system.userFocus(mail)
    case "another app": h.system.activate(bundleID: "com.apple.finder", name: "Finder")
    default: h.controller.pointerPressed()
    }
    h.system.keyDown()
    #expect(h.controller.displayForCommands(from: .shortcut) == FakeWindowSystem.standardDisplay.id)
  }

  /// Nothing is in view on any display: typing into a window nobody sees is worse than a view that moves. A control too.
  @Test func withNothingInViewAnywhereTheViewFollows() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    let second = h.system.displayList[1].frame
    let safari = h.system.open(app: "Safari", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Safari", pid: 12, frame: Self.place(on: second, x: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("desktop")
    h.system.userFocus(f)
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(safari))
    h.system.close(f)
    #expect(h.system.isVisible(safari))
    #expect(h.system.focused == safari)
    expectWindowsMatchLayout(h)
  }
}
