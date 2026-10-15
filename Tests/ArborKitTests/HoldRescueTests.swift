import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Arbor brings two kinds of windows to the middle of the display by itself, so that nobody loses them: a window that opens
/// mostly off screen, and a dialog that opens there (F47). Both open there because their app's own window is out of
/// view. During a hold (docs/features/F58-hold-the-view.md) that would put them in front of an audience, and so it would at
/// the end of one, which can come by itself. They come in when the view next moves.
@Suite @MainActor struct HoldRescueTests {
  /// [keynote | Desktop | mail], framed on keynote, which has the keyboard.
  func stage() -> (h: Harness, keynote: WindowID, mail: WindowID) {
    var settings = Settings()
    settings.holdStillWhileCameraIsOn = true  // it ships off
    let h = Harness(settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(keynote.rawValue)")
    h.system.userFocus(keynote)
    return (h, keynote, mail)
  }

  /// Where Mail would open a message: a little down and to the right of its own window, which is in the corner.
  func besideMail(_ h: Harness, _ mail: WindowID) -> CGRect {
    CGRect(origin: h.frame(mail)!.origin, size: CGSize(width: 500, height: 300)).offsetBy(dx: -200, dy: -20)
  }

  @Test func withoutAHoldAWindowThatOpensOffScreenIsBroughtToTheMiddle() {
    let (h, _, mail) = stage()
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(h.system.isVisible(message))
    #expect(h.frame(message)!.center.x == h.visibleFrame.midX)
  }

  @Test(arguments: ["hold", "hold still"]) func duringAHoldItStaysOutOfViewAndIsNotLost(text: String) {
    let (h, keynote, mail) = stage()
    h.run(text)
    let framed = h.frame(keynote)
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    #expect(h.frame(message)!.fractionInside(h.system.displayList[0].frame) < 0.02, "not the two fifths its app left showing, either")
    #expect(h.controller.parked.contains(message))
    #expect(h.workspace.isFloating(message))
    #expect(h.workspace.guests?[message] == nil, "it did not open over Keynote, so it is no guest of it")
    #expect(h.frame(keynote) == framed)

    // Whatever lays the display out again does not bring it in.
    h.run("relayout")
    h.scheduler.advance(by: 5)
    #expect(!h.system.isVisible(message))

    h.run("release")
    #expect(!h.system.isVisible(message), "the Desktop, where it floats, is not in view")
    h.run("desktop")
    #expect(h.system.isVisible(message), "it is on the Desktop, like every floating window")
    #expect(h.frame(message)!.size == CGSize(width: 500, height: 300))
  }

  /// The table drawn up before the release, in frames. Safari left, Terminal right, Safari framed; Terminal opens a second window beside its first, in
  /// the corner. The ordinary case, and meant: it waits until the view next moves, or until one turns to it.
  @Test(arguments: ["hold", "hold still"]) func aSecondWindowOfAnAppThatIsOutOfViewWaitsUntilTheViewMoves(text: String) {
    func play(_ steps: [String]) -> (h: Harness, second: WindowID) {
      let h = Harness()
      let safari = h.system.open(app: "Safari")
      let terminal = h.system.open(app: "Terminal")
      h.start()
      h.run("dock \(safari.rawValue) left")
      h.run("dock \(terminal.rawValue) right")
      h.run("zoom \(safari.rawValue)")
      h.system.userFocus(safari)
      if let first = steps.first { #expect(h.run(first).ok, "\(first)") }
      let second = h.system.open(app: "Terminal", frame: besideMail(h, terminal))
      for step in steps.dropFirst() { h.run(step) }
      h.scheduler.advance(by: 2)
      return (h, second)
    }
    func isInView(_ played: (h: Harness, second: WindowID)) -> Bool {
      played.h.frame(played.second)!.fractionInside(played.h.visibleFrame) > 0.99
    }
    #expect(isInView(play([])), "without a hold it is brought to the middle at once")
    #expect(!isInView(play([text])))
    #expect(!isInView(play([text, "release"])), "the end of a hold brings nothing in")
    #expect(!isInView(play([text, "release", "relayout"])), "nor does a layout that follows no move of the view")
    #expect(!isInView(play([text, "release", "forward"])), "nor a command that goes nowhere")
    for way in ["home", "show-all", "desktop", "float-all"] { #expect(isInView(play([text, "release", way])), "\(way)") }
    for played in [play([text, "release", "forward"]), play([text, "release", "relayout"]), play([text, "release", "home"])] {
      #expect(played.h.controller.invariantViolations().isEmpty, "and the books agree with the screen")
    }
  }

  /// Found by a hunt on round 2's own code. It waits until the view next moves, or until one turns to it. With the Desktop in view already,
  /// turning to it moves no view, so nothing let it in: it stayed in its corner with the keyboard.
  @Test(arguments: ["reveal", "⌘Tab"]) func turningToAWindowThatWaitsFetchesItThoughNoViewHasToMove(way: String) {
    for during in [false, true] {
      let (h, _, mail) = stage()
      h.system.open(app: "Notes")
      h.run("desktop")
      h.run(during ? "hold still" : "hold")
      let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
      #expect(!h.system.isVisible(message))
      if !during { h.run("release") }
      let camera = h.workspace.camera
      if way == "reveal" { #expect(h.run("reveal \(message.rawValue)").ok) } else { h.system.userFocus(message) }
      h.scheduler.advance(by: 1)
      #expect(h.workspace.camera == camera, "the Desktop was in view")
      #expect(h.system.isVisible(message), "\(way), \(during ? "holding still" : "after the hold")")
      #expect(h.system.focused == message)
      #expect(h.controller.invariantViolations().isEmpty)
    }
  }

  /// Found by HoldFuzzTests: a layout puts floating windows that are out of view back on a Desktop that is in view.
  @Test(arguments: ["hold", "hold still"]) func itIsKeptOffADesktopThatIsInViewUntilTheViewMoves(text: String) {
    let (h, keynote, mail) = stage()
    // The view is on the Desktop alone, where Notes floats: Mail's window is out of view, the Desktop its message would float on is not.
    h.system.open(app: "Notes")
    h.run("desktop")
    #expect(h.run(text).ok)
    let note = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(note))
    h.run("relayout")
    h.system.setMinimized(keynote, true)
    h.scheduler.advance(by: 5)
    #expect(!h.system.isVisible(note), "whatever lays the display out again")
    h.run("release")
    h.run("relayout")
    h.scheduler.advance(by: 5)
    #expect(!h.system.isVisible(note), "the end of a hold brings nothing into view")
    h.run("show-all")
    #expect(h.system.isVisible(note), "the next move of the view does")
    #expect(h.layout!.desktopFrame!.contains(h.frame(note)!.center))
  }

  /// Found by HoldFuzzTests. The rule would leave the view where it is, and put a window into it that nobody has seen.
  @Test func aRuleDoesNotDockAWindowThatWasKeptOut() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.mail", action: .dock(.right))]
    let h = Harness(settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(keynote.rawValue)")
    h.run("hold")
    let framed = h.frame(keynote)
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    #expect(h.run("release").message == "released; Mail was left floating")
    #expect(!h.system.isVisible(message))
    #expect(h.workspace.isFloating(message))
    #expect(h.frame(keynote) == framed)
  }

  @Test func nothingComesInWhenTheTimeIsUpOrTheCallIsOver() {
    let (h, _, mail) = stage()
    h.system.open(app: "Notes")
    h.run("desktop")
    let corner = besideMail(h, mail)
    #expect(h.run("hold 5").ok)
    let note = h.system.open(app: "Mail", frame: corner)
    h.scheduler.advance(by: 301)
    #expect(h.controller.holdLevel == nil)
    #expect(!h.system.isVisible(note))
    #expect(h.system.leavesStrayDialogs)

    h.controller.callSignalsChanged(CallSignals(cameraIsOn: true))
    let another = h.system.open(app: "Mail", frame: corner)
    h.controller.callSignalsChanged(CallSignals())
    h.scheduler.advance(by: 6)
    #expect(h.controller.holdLevel == nil)
    #expect(!h.system.isVisible(another))
  }

  /// It is kept out because it opened beside a window of its app that is out of view, which makes it something from out of view.
  /// One that is merely larger than the display would have opened over the view like any new window, and only went missing.
  @Test(arguments: ["hold", "hold still"]) func aWindowWithNoWindowOfItsAppOutOfViewIsBroughtInAsEver(text: String) {
    let (h, _, _) = stage()
    h.run(text)
    let huge = h.system.open(app: "Preview", frame: CGRect(x: 1295, y: 282, width: 2634, height: 2311))
    #expect(h.system.isVisible(huge))
    #expect(!h.controller.parked.contains(huge))
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// Found by HoldFuzzTests. Docking a window that floats in view at the edge of the view makes a group of the two, and the view is on
  /// that: a new node, the same things to see. It was taken for a move of the view.
  @Test func arrangingTheWindowsInViewAmongThemselvesLetsNothingIntoAHeldView() {
    let (h, _, mail) = stage()
    let notes = h.system.open(app: "Notes")
    h.run("desktop")
    h.run("hold")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    let camera = h.workspace.camera
    #expect(h.run("dock \(notes.rawValue) left").ok)
    #expect(h.workspace.camera != camera, "a new node")
    #expect(!h.system.isVisible(message))
    #expect(!h.system.isVisible(mail))
    #expect(h.system.leavesStrayDialogs)
  }

  /// Found by HoldFuzzTests. A rule that waited is applied when the hold ends, if it leaves the view as it is. It docks at the edge of the
  /// view, which makes a new node, and that let in what the end of a hold is not to let in.
  @Test func aRuleAppliedAtTheEndOfAHoldLetsNothingElseIn() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let h = Harness(settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    h.system.open(app: "Notes")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("desktop")
    h.run("hold")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    let terminal = h.system.open(app: "Terminal")
    #expect(h.run("release").message == "released")
    #expect(h.workspace.isDocked(terminal), "it leaves the view as it is")
    #expect(!h.system.isVisible(message))
    #expect(!h.system.isVisible(mail))
    h.run("show-all")
    #expect(h.system.isVisible(message))
  }

  /// The chaos lab's: pin says always in view, the hold says nothing comes in. Pin wins: it is the person's own word about that window,
  /// and a call pinned by a rule is what they want to see during a call.
  @Test(arguments: ["hold", "hold still"]) func aWindowThatARulePinsIsNotKeptOut(text: String) {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.mail", title: "Call", action: .pin)]
    let h = Harness(settings: settings)
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("zoom \(keynote.rawValue)")
    h.run(text)
    let call = h.system.open(app: "Mail", title: "Call", frame: besideMail(h, mail))
    #expect(h.controller.isPinned(call))
    #expect(h.system.isVisible(call))
    #expect(!h.controller.parked.contains(call))
    #expect(!h.system.isVisible(mail))
    #expect(h.controller.invariantViolations().isEmpty)
    let other = h.system.open(app: "Mail", title: "Inbox", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(other), "any other window of the app waits")
  }

  @Test func holdingStillAWindowThatWasKeptOutCanBePinnedIntoView() {
    let (h, _, mail) = stage()
    h.run("hold still")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    #expect(h.run("pin \(message.rawValue)").ok)
    #expect(h.system.isVisible(message))
    h.run("relayout")
    h.scheduler.advance(by: 5)
    #expect(h.system.isVisible(message), "and layouts go on keeping it there")
    #expect(h.controller.invariantViolations().isEmpty)
    // Also when that takes a move: the display is smaller now, and where the window was is beyond its edge.
    h.system.userMove(message, to: CGRect(x: 920, y: 560, width: 500, height: 300))
    h.system.setDisplays([
      DisplaySnapshot(
        id: h.display, frame: CGRect(x: 0, y: 0, width: 1024, height: 768), visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743),
        isMain: true)
    ])
    h.scheduler.advance(by: 5)
    #expect(h.frame(message)!.fractionInside(h.visibleFrame) > 0.99)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// The chaos lab's `parked-held`, and two scripts of the presets' owner: a command that announces a move and makes none, or
  /// moves nothing at all, ended the waiting, and nothing brought the window in.
  @Test(arguments: ["summon Finder", "reset screenEdgeBand", "view 9", "back"]) func aCommandThatMovesNoViewLetsNothingIn(text: String) {
    let (h, _, mail) = stage()
    h.run("desktop")
    h.run("hold still")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    let camera = h.workspace.camera
    h.run(text)
    h.scheduler.advance(by: 1)
    if h.workspace.camera == camera {
      #expect(!h.system.isVisible(message), "it goes on waiting")
    } else {
      #expect(h.system.isVisible(message) || h.layout?.desktopFrame == nil, "the view moved")
    }
    #expect(h.controller.invariantViolations().isEmpty)
    h.run("release")
    h.run("show-all")
    #expect(h.system.isVisible(message), "and comes in with the next move")
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// A move on one display lays out that display only.
  @Test func eachDisplaysWindowsWaitForTheirOwnView() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let keynote = h.system.open(app: "Keynote")
    let mail = h.system.open(app: "Mail")
    let xcode = h.system.open(app: "Xcode", frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(keynote.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(xcode.rawValue) left")
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("desktop")
    h.run("hold still")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    h.system.cursor = CGPoint(x: 2000, y: 500)
    h.run("desktop")
    #expect(!h.system.isVisible(message), "the other display's view moved")
    #expect(h.controller.invariantViolations().isEmpty)
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("show-all")
    #expect(h.system.isVisible(message))
  }

  /// The chaos lab's `focus-ring-held`. The keyboard was asked back when the window opened; a moment later its app activated it. That
  /// was taken for the same arrival, and nobody looked again: what was typed went to a window nobody could see.
  @Test func aWindowThatTakesTheKeyboardJustAfterItWasAskedBackIsTurnedAwayOnASecondLook() {
    let (h, keynote, mail) = stage()
    h.run("hold")
    h.system.defersFocus = true  // macOS does not do as it is asked at once, and this time not at all
    let asked = h.system.focusRequests.count
    h.system.comesForward(mail)
    h.system.comesForward(mail)
    #expect(h.system.focusRequests.count == asked + 1, "one arrival, reported twice: asked back once")
    #expect(h.system.focused == mail)
    h.scheduler.advance(by: 0.25)
    #expect(h.system.focusRequests.count == asked + 2, "it is still there, so once more")
    h.system.settleFocus()
    h.scheduler.advance(by: 0.5)
    #expect(h.system.focused == keynote)
    #expect(h.system.focusRequests.count == asked + 2, "and that is the end of it")
    #expect(h.overlays.scenes[h.display]?.focusRing?.window == keynote)
    #expect(!h.system.isVisible(mail))
  }

  /// An app that insists is left with the keyboard. Then the line is around no window, not around the one that lost it.
  @Test func leftWithAnAppThatInsistsThereIsNoLineAroundTheWindowInView() {
    let (h, _, mail) = stage()
    h.run("hold")
    for _ in 0..<8 {
      h.system.comesForward(mail)
      h.scheduler.advance(by: 0.3)
    }
    #expect(h.system.focused == mail)
    #expect(!h.system.isVisible(mail))
    #expect(h.overlays.scenes[h.display]?.focusRing == nil)
  }

  @Test func holdingStillSomeoneWhoMovesTheViewSeesWhatIsThere() {
    let (h, _, mail) = stage()
    h.run("hold still")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(message))
    h.run("show-all")
    #expect(h.system.isVisible(message), "they asked to see everything")
    #expect(h.controller.holdLevel == .still)
  }

  @Test func afterReleaseSwitchingToItBringsItIntoView() {
    let (h, _, mail) = stage()
    h.run("hold")
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    h.run("release")
    h.system.userFocus(message)
    #expect(h.system.isVisible(message))
    #expect(h.system.focused == message)
  }

  @Test func holdingStillAWindowTheUserOpenedIsBroughtInAtOnce() {
    let (h, _, mail) = stage()
    h.run("hold still")
    h.system.secondsSinceInput = 0.2  // ⌘N
    let message = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(h.system.isVisible(message))

    h.run("hold")
    let another = h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(!h.system.isVisible(another), "a held view takes in nobody")
  }

  @Test func aWindowThatOpensInViewFloatsThereAsEver() {
    let (h, keynote, _) = stage()
    h.run("hold")
    let place = CGRect(x: 300, y: 200, width: 500, height: 300)
    let window = h.system.open(app: "Finder", frame: place)
    #expect(h.frame(window) == place)
    #expect(h.workspace.guests?[window] == h.workspace.tree.leaf(containing: keynote), "and stays with the window it opened over (F57)")
  }

  // MARK: Dialogs (the Accessibility layer moves them; the controller says when not to)

  @Test func dialogsThatOpenOutOfViewWaitOnAHeldViewUntilTheViewMoves() {
    let (h, _, _) = stage()
    #expect(!h.system.leavesStrayDialogs)
    h.run("hold still")
    #expect(!h.system.leavesStrayDialogs, "a call can last an hour, and an app whose dialog cannot be found looks hung")
    h.run("hold")
    #expect(h.system.leavesStrayDialogs)
    h.run("release")
    #expect(h.system.leavesStrayDialogs, "an alert in the middle of the display is no better at the end of the hold")
    h.run("show-all")
    #expect(!h.system.leavesStrayDialogs)
  }

  @Test(arguments: ["release", "toggle-hold", "hold still"]) func lettingGoOfTheViewAloneDoesNotLetThemIn(text: String) {
    let (h, _, mail) = stage()
    h.run("hold")
    h.run(text)
    #expect(h.system.leavesStrayDialogs)
    // Whoever goes to the app whose dialog it is moves the view.
    h.system.userFocus(mail)
    #expect(h.system.isVisible(mail))
    #expect(!h.system.leavesStrayDialogs)
  }

  /// The product owner's safeguard. An app blocked on a dialog beeps at every click, so the person clicks its Dock icon. The
  /// keyboard goes to the dialog, which Arbor does not arrange: there is no focus report for a window, and the view stays.
  @Test func aDockClickOnAnAppBlockedOnADialogBringsThatDialogIn() {
    let (h, keynote, mail) = stage()
    h.run("hold")
    h.system.openStrayDialog(ofApp: "com.example.mail")
    h.system.openStrayDialog(ofApp: "com.example.calendar")
    h.system.activate(bundleID: "com.example.mail", name: "Mail")
    #expect(h.system.strayDialogs.count == 2, "not on a held view")
    h.system.activateApp(of: keynote)
    h.run("release")
    #expect(h.system.strayDialogs.count == 2, "nor at its end")

    let camera = h.workspace.camera
    h.system.activate(bundleID: "com.example.mail", name: "Mail")
    #expect(h.system.strayDialogs == ["com.example.calendar"], "Mail's own, and nobody else's")
    #expect(h.workspace.camera == camera)
    #expect(!h.system.isVisible(mail), "no window of Mail's was asked for")
    #expect(h.system.leavesStrayDialogs, "the other one waits for the view to move")
    h.run("show-all")
    #expect(h.system.strayDialogs.isEmpty)
  }

  /// Found by the keeper of the Accessibility layer. One window of Keynote is being shown, another is out of view, and Keynote puts
  /// an alert over that one ("the file has changed on disk"). It takes no input until the alert is answered, and its Dock icon
  /// does nothing, because it is in front already.
  @Test func anAlertOfTheAppBeingShownDoesNotWaitOrItWouldLookHung() {
    let (h, _, _) = stage()
    h.run("hold")
    #expect(h.system.appWhoseDialogsNeverWait == "com.example.keynote")
    #expect(!h.system.openStrayDialog(ofApp: "com.example.keynote"), "in the middle of the display at once, held or not")
    #expect(h.system.openStrayDialog(ofApp: "com.example.mail"), "anybody else's waits")
  }

  /// In front is not in use.
  @Test func anAppThatPushesItselfForwardWithItsAlertStillWaits() {
    let (h, _, mail) = stage()
    h.run("hold")
    h.system.activate(bundleID: "com.example.mail", name: "Mail")
    h.system.comesForward(mail)
    #expect(h.system.appWhoseDialogsNeverWait == "com.example.keynote")
    #expect(h.system.openStrayDialog(ofApp: "com.example.mail"))
  }

  /// Two windows in view. A click on the other one makes its app the one in use, and what it had waiting comes in.
  @Test func theAppInUseFollowsTheKeyboardAmongTheWindowsInView() {
    let (h, keynote, mail) = stage()
    h.run("show-all")
    h.system.userFocus(keynote)
    h.run("hold")
    #expect(h.system.openStrayDialog(ofApp: "com.example.mail"))
    h.system.userFocus(mail)
    #expect(h.system.appWhoseDialogsNeverWait == "com.example.mail")
    #expect(h.system.strayDialogs.isEmpty)
    #expect(h.system.leavesStrayDialogs, "the others' go on waiting")
    #expect(h.system.openStrayDialog(ofApp: "com.example.keynote"))
  }

  @Test func holdingStillOnlyThePersonsOwnSwitchBringsItIn() {
    let (h, keynote, _) = stage()
    h.run("hold")
    h.system.openStrayDialog(ofApp: "com.example.mail")
    h.run("hold still")
    h.system.activate(bundleID: "com.example.mail", name: "Mail")  // by itself
    #expect(h.system.strayDialogs.count == 1)
    h.system.activateApp(of: keynote)
    h.system.secondsSinceInput = 0.1  // a click in the Dock
    h.system.activate(bundleID: "com.example.mail", name: "Mail")
    #expect(h.system.strayDialogs.isEmpty)
  }

  /// Findable meanwhile.
  @Test func statusCountsTheDialogsThatWait() {
    let (h, _, _) = stage()
    #expect(h.run("status").message.hasSuffix("1 out of view"))
    h.run("hold")
    #expect(h.run("status").message.hasSuffix("1 out of view; the view is held until `release`"))
    h.system.openStrayDialog(ofApp: "com.example.mail")
    #expect(h.run("status").message.hasSuffix("1 out of view and 1 dialog; the view is held until `release`"))
    h.system.openStrayDialog(ofApp: "com.example.calendar")
    h.run("release")
    #expect(h.run("status").message.hasSuffix("1 out of view and 2 dialogs"), "also after the hold, for as long as they wait")
    h.run("show-all")
    #expect(h.run("status").message.hasSuffix("0 out of view"))
  }

  @Test func aWindowThatWasKeptOutIsCountedAsOutOfViewLikeAnyOther() {
    let (h, _, mail) = stage()
    h.run("hold")
    h.system.open(app: "Mail", frame: besideMail(h, mail))
    #expect(h.run("status").message.contains("2 out of view"))
    h.run("release")
    #expect(h.run("status").message.hasSuffix("2 out of view"))
  }

  /// They bring every window into view anyway.
  @Test(arguments: ["pause", "float-all"]) func theWaysOutThatShowEverythingLetThemIn(text: String) {
    let (h, _, _) = stage()
    h.run("hold")
    h.run(text)
    #expect(!h.system.leavesStrayDialogs)
  }

  @Test func soDoesQuitting() {
    let (h, _, _) = stage()
    h.run("hold")
    h.controller.shutdown()
    #expect(!h.system.leavesStrayDialogs)
  }
}
