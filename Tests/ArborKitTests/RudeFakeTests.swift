import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Writes down what a window system reports, in order.
@MainActor
private final class Listener: WindowSystemEvents {
  var log: [String] = []
  func windowAppeared(_ window: WindowSnapshot) { log.append("appeared \(window.id)") }
  func windowDestroyed(_ id: WindowID) { log.append("destroyed \(id)") }
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    log.append("changed \(window.id) \(userInitiated ? "by hand" : "echo")\(window.isMinimized ? " minimized" : "")")
  }
  func windowFocused(_ id: WindowID) { log.append("focused \(id)") }
  func applicationActivated(_ app: FrontmostApp?) { log.append("activated \(app?.name ?? "nobody")") }
  func accessibilityWasRefused() { log.append("refused") }
  func dragBegan(_ id: WindowID, at point: CGPoint) { log.append("drag began \(id)") }
  func dragMoved(_ id: WindowID, to point: CGPoint) { log.append("drag moved \(id)") }
  func dragEnded(_ id: WindowID, at point: CGPoint) { log.append("drag ended \(id)") }
  func displaysChanged() { log.append("displays") }
  func resizeBegan(_ id: WindowID) { log.append("resize began \(id)") }
  func resizeEnded(_ id: WindowID) { log.append("resize ended \(id)") }
  func keyboardFocusMoved() { log.append("keyboard moved") }
  func dragCancelled(_ id: WindowID) { log.append("drag cancelled \(id)") }
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) { log.append("replaced \(old) by \(window.id)") }
  func pointerPressed() { log.append("pressed") }
}

/// The rude fake is rude in the ways it says, in no others, and the same way for the same seed. Each test says which manners it wants,
/// so these hold whatever `ARBOR_RUDE` says; `scripts/rude.py` leaves them out all the same.
@Suite @MainActor struct RudeFakeTests {
  /// Two windows of app 1 (`a`, `b`), one of app 2 (`c`); `a` has the keyboard, `b` had it before, `c` before that.
  private func make(_ words: String, seed: UInt64 = 1) -> (FakeWindowSystem, Listener, WindowID, WindowID, WindowID) {
    let system = FakeWindowSystem(displays: [FakeWindowSystem.hostedMacDisplay])
    let listener = Listener()
    system.events = listener
    system.rudeness = Rudeness()
    let a = system.open(app: "Safari", pid: 1)
    let b = system.open(app: "Safari", pid: 1)
    let c = system.open(app: "Mail", pid: 2)
    system.start()
    for window in [c, b, a] { system.userFocus(window) }
    listener.log.removeAll()
    system.rudeness = Rudeness(words: words, seed: seed)!
    return (system, listener, a, b, c)
  }

  @Test func theWordsAreRead() {
    #expect(Rudeness().isPolite)
    #expect(Rudeness(words: "")?.isPolite == true)
    #expect(Rudeness(words: "small")?.isPolite == true, "a display, not a manner")
    #expect(Rudeness(words: "order,late")?.shufflesReports == true)
    #expect(Rudeness(words: "order late")?.answersLate == true)
    #expect(Rudeness(words: "order")?.answersLate == false)
    #expect(Rudeness(words: "polite") == nil, "a word nobody knows must not pass for a rude run")
    for word in Rudeness.manners { #expect(Rudeness(words: word)?.isPolite == false, "\(word)") }
    #expect(Rudeness(words: Rudeness.manners.joined(separator: ",")) == Rudeness(words: "all"))
  }

  @Test func aPoliteFakeReportsStraightToItsListener() {
    let (system, listener, _, _, _) = make("")
    #expect(system.events === listener)
  }

  @Test func theSameSeedIsRudeInTheSameWay() {
    func story(seed: UInt64) -> [String] {
      let (system, listener, a, b, c) = make("all", seed: seed)
      system.close(a)
      system.setMinimized(b, true)
      system.userFocus(c)
      system.setMinimized(b, false)
      _ = system.setFrame(CGRect(x: 10, y: 40, width: 300, height: 300), of: c)
      system.deliverEchoes()
      return listener.log
    }
    #expect(story(seed: 7) == story(seed: 7))
    #expect(Set((1...20).map { story(seed: $0) }).count > 1)
  }

  // MARK: ahead

  @Test func byTheFirstReportAllOfItHasHappened() {
    final class Witness: WindowSystemEvents {
      unowned let system: FakeWindowSystem
      var seen: [String] = []
      init(_ system: FakeWindowSystem) { self.system = system }
      func windowAppeared(_ window: WindowSnapshot) {
        seen.append("appeared, the keyboard is in \(system.focusedWindow().map { "\($0)" } ?? "nothing"), in front is \(system.windowsFrontToBack()[0])")
      }
      func windowDestroyed(_ id: WindowID) {}
      func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
      func windowFocused(_ id: WindowID) { seen.append("focused, \(system.allWindows().count) windows") }
      func dragBegan(_ id: WindowID, at point: CGPoint) {}
      func dragMoved(_ id: WindowID, to point: CGPoint) {}
      func dragEnded(_ id: WindowID, at point: CGPoint) {}
      func displaysChanged() {}
      func resizeBegan(_ id: WindowID) {}
      func resizeEnded(_ id: WindowID) {}
      func keyboardFocusMoved() {}
      func dragCancelled(_ id: WindowID) {}
      func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
      func pointerPressed() {}
      func applicationActivated(_ app: FrontmostApp?) {}
      func accessibilityWasRefused() {}
    }
    // That a new window has the keyboard when it is first heard of is true of the polite fake as well by now. That one which closes has gone is not.
    for (words, keyboard) in [("", "w104"), ("ahead", "w104")] {
      let (system, _, a, _, _) = make(words)
      let witness = Witness(system)
      system.events = witness
      let new = system.open(app: "Safari", pid: 1)
      #expect(witness.seen.first == "appeared, the keyboard is in \(keyboard), in front is \(keyboard)", "\(words)")
      witness.seen.removeAll()
      system.close(new)
      #expect(witness.seen == ["focused, \(words.isEmpty ? 4 : 3) windows"], "\(words): the keyboard is back in \(a)")
    }
  }

  // MARK: order

  @Test func whatBelongsToOneHappeningComesInEitherOrder() {
    var orders = Set<[String]>()
    for seed in 1...20 {
      let (system, listener, a, _, _) = make("order", seed: UInt64(seed))
      system.close(a)
      orders.insert(listener.log)
    }
    #expect(orders == [["focused w102", "destroyed w101"], ["destroyed w101", "focused w102"]])
  }

  @Test func nothingIsSaidOfAWindowBeforeItIsThereOrAfterItHasGone() {
    for seed in 1...40 {
      let (system, listener, _, _, _) = make("order,twice", seed: UInt64(seed))
      let new = system.open(app: "Safari", pid: 1)
      system.close(new)
      let about = listener.log.filter { $0.hasSuffix(" \(new)") }
      #expect(about.first == "appeared \(new)", "seed \(seed): \(listener.log)")
      #expect(about.last == "destroyed \(new)", "seed \(seed): \(listener.log)")
    }
  }

  @Test func aClickIsAHandsDoingWheneverWordOfItComes() {
    final class Witness: WindowSystemEvents {
      unowned let system: FakeWindowSystem
      var seconds: [Double] = []
      init(_ system: FakeWindowSystem) { self.system = system }
      func windowFocused(_ id: WindowID) { seconds.append(system.secondsSinceClickOrModifierKey()) }
      func windowAppeared(_ window: WindowSnapshot) {}
      func windowDestroyed(_ id: WindowID) {}
      func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
      func dragBegan(_ id: WindowID, at point: CGPoint) {}
      func dragMoved(_ id: WindowID, to point: CGPoint) {}
      func dragEnded(_ id: WindowID, at point: CGPoint) {}
      func displaysChanged() {}
      func resizeBegan(_ id: WindowID) {}
      func resizeEnded(_ id: WindowID) {}
      func keyboardFocusMoved() {}
      func dragCancelled(_ id: WindowID) {}
      func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
      func pointerPressed() {}
      func applicationActivated(_ app: FrontmostApp?) {}
      func accessibilityWasRefused() {}
    }
    for words in ["", "ahead", "order", "closes", "twice", "slow"] {
      let (system, _, _, _, c) = make(words)
      let witness = Witness(system)
      system.events = witness
      system.userClick(c)
      #expect(!witness.seconds.isEmpty && witness.seconds.allSatisfy { $0 == 0 }, "\(words): \(witness.seconds)")
    }
  }

  @Test func theEchoesOfDifferentAppsComeInAnyOrderThoughTestsGiveThemOnePid() {
    var orders: [[String]] = []
    for seed in 1...40 {
      let system = FakeWindowSystem(displays: [FakeWindowSystem.hostedMacDisplay])
      let listener = Listener()
      system.events = listener
      system.rudeness = Rudeness()
      let windows = ["Safari", "Mail", "Notes"].map { system.open(app: $0) }
      system.start()
      system.rudeness = Rudeness(words: "order", seed: UInt64(seed))!
      for window in windows { _ = system.setFrame(CGRect(x: 10, y: 40, width: 300, height: 300), of: window) }
      system.deliverEchoes()
      // Who is heard of first, second, third: a move has several echoes.
      var order: [String] = []
      for line in listener.log where !order.contains(line) { order.append(line) }
      if !orders.contains(order) { orders.append(order) }
    }
    #expect(orders.count == 6, "\(orders)")
  }

  @Test func aBurstIsAMoment() {
    for words in ["", "ahead"] {
      let (system, listener, a, _, _) = make(words)
      var now = 0.0
      var times: [Double] = []
      system.clock = { now }
      system.passTime = { seconds in
        times.append(Double(listener.log.count))
        now += seconds
      }
      // Let go where macOS tiles, which takes it a third of a second.
      system.dragAndLoseTheRelease(a, to: CGPoint(x: 0, y: 400))
      #expect(times.first == 4, "\(words): the press, the beginning, the move and the pointer are heard of before any time passes: \(listener.log)")
    }
  }

  @Test func nobodyIsSaidToHaveTheKeyboardWhoHasGone() {
    let (system, listener, _, b, _) = make("ahead")
    system.quit(pid: 1)
    #expect(!listener.log.contains("focused \(b)"), "the layer reads who has it when the notification arrives: \(listener.log)")
    #expect(listener.log.contains("keyboard moved"))
  }

  @Test func whatTheLayerSendsInOneLoopKeepsItsOrder() {
    for seed in 1...40 {
      let (system, listener, a, b, _) = make("order", seed: UInt64(seed))
      system.setHidden(pid: 1, true)
      // Whose doing it is said to be is not the point here.
      let changed = listener.log.filter { $0.hasPrefix("changed") }.map { $0.split(separator: " ").prefix(2).joined(separator: " ") }
      #expect(changed == ["changed \(a)", "changed \(b)"], "seed \(seed): \(listener.log)")
      listener.log.removeAll()
      system.quit(pid: 1)
      #expect(listener.log.filter { $0.hasPrefix("destroyed") } == ["destroyed \(a)", "destroyed \(b)"], "seed \(seed): \(listener.log)")
    }
  }

  @Test func theMouseKeepsItsOrder() {
    for seed in 1...40 {
      let (system, listener, a, _, _) = make("order", seed: UInt64(seed))
      system.drag(a, through: [CGPoint(x: 400, y: 300), CGPoint(x: 500, y: 320), CGPoint(x: 520, y: 340)], holding: 0)
      let mouse = listener.log.filter { $0 == "pressed" || $0.hasPrefix("drag") }
      #expect(
        mouse == ["pressed", "drag began \(a)", "drag moved \(a)", "drag moved \(a)", "drag ended \(a)"],
        "seed \(seed): \(listener.log)")
      #expect(listener.log.prefix(2) == ["pressed", "drag began \(a)"], "a drag begins with the move it is made of: \(listener.log)")
    }
  }

  @Test func aResizeEndsWithTheLastFrameJustBeforeIt() {
    for seed in 1...40 {
      let (system, listener, a, _, _) = make("order", seed: UInt64(seed))
      system.userResize(a, to: CGRect(x: 300, y: 200, width: 700, height: 420))
      #expect(listener.log.suffix(2) == ["changed \(a) by hand", "resize ended \(a)"], "seed \(seed): \(listener.log)")
    }
  }

  // MARK: twice

  @Test func echoesAndAFocusAcrossAppsComeTwiceAndAHandsMoveOnce() {
    let (system, listener, a, b, c) = make("twice")
    system.userFocus(b)
    #expect(listener.log == ["focused \(b)"], "within one app the Accessibility layer swallows the second")
    listener.log.removeAll()
    system.userFocus(c)
    #expect(listener.log == ["activated Mail", "focused \(c)", "focused \(c)"])
    listener.log.removeAll()
    // How many echoes a move has is the polite fake's business.
    let (polite, politely, sameWindow, _, _) = make("")
    for (system, window) in [(system, a), (polite, sameWindow)] {
      _ = system.setFrame(CGRect(x: 10, y: 40, width: 300, height: 300), of: window)
      system.deliverEchoes()
    }
    #expect(listener.log == politely.log && !listener.log.isEmpty)
    listener.log.removeAll()
    system.userMove(a, to: CGRect(x: 20, y: 50, width: 300, height: 300))
    #expect(listener.log == ["changed \(a) by hand"])
  }

  // MARK: late

  @Test func aLateAnswerIsHalfTheDeedAndTheRestFollows() {
    let asked = CGRect(x: 10, y: 40, width: 300, height: 310)
    var answers: [CGRect] = []
    for seed in 1...40 {
      let (system, listener, a, _, _) = make("late", seed: UInt64(seed))
      let before = system.frame(of: a)!
      let answer = system.setFrame(asked, of: a)!
      if !answers.contains(answer) { answers.append(answer) }
      #expect(system.frame(of: a) == answer, "what is read back is where the window is")
      system.deliverEchoes()
      #expect(system.frame(of: a) == asked, "seed \(seed)")
      if answer != asked { #expect(listener.log.contains("changed \(a) by hand"), "seed \(seed): \(listener.log)") }
      #expect(
        [asked, before, CGRect(origin: asked.origin, size: before.size), CGRect(origin: before.origin, size: asked.size)]
          .contains(answer))
    }
    #expect(answers.count == 4, "done, not begun, only moved, only resized: \(answers)")
  }

  @Test func aSecondRequestReplacesWhatIsStillOwed() {
    for seed in 1...20 {
      let (system, _, a, _, _) = make("late", seed: UInt64(seed))
      _ = system.setFrame(CGRect(x: 10, y: 40, width: 300, height: 310), of: a)
      let second = CGRect(x: 500, y: 100, width: 400, height: 400)
      _ = system.setFrame(second, of: a)
      system.deliverEchoes()
      #expect(system.frame(of: a) == second, "seed \(seed)")
    }
  }

  // MARK: slow

  @Test func theKeyboardGoesWhereArborAskedOnlyAfterTheCallHasReturned() {
    let (system, listener, a, _, c) = make("slow")
    system.focus(c)
    #expect(system.focusedWindow() == a, "the old answer")
    #expect(listener.log.isEmpty)
    #expect(system.deliverEchoes() == 1, "a report of a focus like any other")
    #expect(system.focusedWindow() == c)
    #expect(listener.log == ["activated Mail", "focused \(c)", "keyboard moved"])
  }

  @Test func everyRequestComesTrueInOrder() {
    let (system, listener, _, b, c) = make("slow")
    system.focus(b)
    system.focus(c)
    #expect(system.deliverEchoes() == 2)
    #expect(listener.log == ["focused \(b)", "activated Mail", "focused \(c)", "keyboard moved"])
  }

  @Test func theWindowThatHasTheKeyboardIsRaisedAllTheSame() {
    let (system, listener, a, _, c) = make("slow")
    system.raise(c)
    #expect(system.windowsFrontToBack().first == c)
    system.focus(a)
    system.deliverEchoes()
    #expect(system.windowsFrontToBack().first == a)
    #expect(listener.log.isEmpty, "the keyboard has not moved")
  }

  @Test func aTestThatSaysWhenTheKeyboardArrivesIsNotOverruled() {
    let (system, _, a, _, c) = make("slow")
    system.focusIsSlow = true
    system.focus(c)
    #expect(system.slowFocus == c)
    system.deliverEchoes()
    #expect(system.focusedWindow() == a, "not before the test says so")
    system.finishSlowFocus()
    #expect(system.focusedWindow() == c)
  }

  @Test func whatIsOwedCountsAsHeldWhereEchoesWaitForTheApps() {
    let (system, _, a, _, c) = make("slow")
    system.holdsEchoes = true
    system.focus(c)
    #expect(system.hasHeldEchoes, "or the chaos lab would leave the keyboard on its way for minutes")
    #expect(system.focusedWindow() == a)
    system.appsReact()
    #expect(system.focusedWindow() == c)
    #expect(!system.hasHeldEchoes)
  }

  @Test func whatArborAskedForEarlierDoesNotOverruleWhatAPersonDoesLater() {
    for held in [false, true] {
      let (system, listener, a, b, c) = make("slow")
      system.holdsEchoes = held
      system.userFocus(b)
      listener.log.removeAll()
      system.focus(c)
      system.userFocus(a)
      #expect(system.focusedWindow() == a, "echoes held: \(held)")
      #expect(
        listener.log == ["activated Mail", "focused \(c)", "keyboard moved", "activated Safari", "focused \(a)"],
        "macOS does and reports both, in order: \(listener.log)")
    }
  }

  @Test func whenTimePassesWhatIsOwedComesTrueThoughNoWorkFallsDue() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.system.userFocus(a)
    h.scheduler.advance(by: 5)
    h.system.rudeness = Rudeness(words: "slow")!
    h.system.focus(b)
    h.scheduler.advance(by: 0)
    #expect(h.system.focused == a, "no time has passed")
    h.scheduler.advance(by: 0.1)
    #expect(h.system.focused == b)
  }

  @Test func aHelperGoesByTheWorldAsItIsOnceWhatWasAskedHasHappened() {
    /// Moves a window as soon as it hears that it has the keyboard, as Arbor does to bring it into view.
    final class Mover: WindowSystemEvents {
      unowned let system: FakeWindowSystem
      let place: CGRect
      init(_ system: FakeWindowSystem, to place: CGRect) { (self.system, self.place) = (system, place) }
      func windowFocused(_ id: WindowID) { _ = system.setFrame(place, of: id) }
      func keyboardFocusMoved() {}
      func windowAppeared(_ window: WindowSnapshot) {}
      func windowDestroyed(_ id: WindowID) {}
      func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
      func dragBegan(_ id: WindowID, at point: CGPoint) {}
      func dragMoved(_ id: WindowID, to point: CGPoint) {}
      func dragEnded(_ id: WindowID, at point: CGPoint) {}
      func displaysChanged() {}
      func resizeBegan(_ id: WindowID) {}
      func resizeEnded(_ id: WindowID) {}
      func dragCancelled(_ id: WindowID) {}
      func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
      func pointerPressed() {}
      func applicationActivated(_ app: FrontmostApp?) {}
      func accessibilityWasRefused() {}
    }
    let (system, _, _, _, c) = make("slow")
    let place = CGRect(x: 40, y: 60, width: 500, height: 400)
    let mover = Mover(system, to: place)
    system.events = mover
    system.holdsEchoes = true
    system.focus(c)
    system.beginDrag(c)
    #expect(system.frame(of: c) == place, "taken hold of where it is, not where it was before the keyboard came")
  }

  @Test func everyHelperLetsWhatIsOwedComeTrue() {
    /// Answers "the keyboard moved" by asking for it to go to one window, as Arbor does when it went out of view.
    final class Fetcher: WindowSystemEvents {
      unowned let system: FakeWindowSystem
      let home: WindowID
      init(_ system: FakeWindowSystem, home: WindowID) { (self.system, self.home) = (system, home) }
      func keyboardFocusMoved() { if system.focusedWindow() != home { system.focus(home) } }
      func windowAppeared(_ window: WindowSnapshot) {}
      func windowDestroyed(_ id: WindowID) {}
      func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
      func windowFocused(_ id: WindowID) {}
      func dragBegan(_ id: WindowID, at point: CGPoint) {}
      func dragMoved(_ id: WindowID, to point: CGPoint) {}
      func dragEnded(_ id: WindowID, at point: CGPoint) {}
      func displaysChanged() {}
      func resizeBegan(_ id: WindowID) {}
      func resizeEnded(_ id: WindowID) {}
      func dragCancelled(_ id: WindowID) {}
      func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
      func pointerPressed() {}
      func applicationActivated(_ app: FrontmostApp?) {}
      func accessibilityWasRefused() {}
    }
    for quiet in [false, true] {
      let (system, _, a, _, c) = make("slow")
      let fetcher = Fetcher(system, home: a)
      system.events = fetcher
      // One with a burst, one without.
      if quiet { system.userFocusesNothing() } else { system.userSwitchesApp(to: c) }
      #expect(system.focusedWindow() == a, "quiet: \(quiet)")
      #expect(!system.hasHeldEchoes)
    }
  }

  @Test func aTestThatSwitchedTheEchoOffHasSilence() {
    for words in ["", "slow"] {
      let (system, listener, _, _, c) = make(words)
      let front = system.frontmost
      system.echoes = .none
      system.focus(c)
      system.deliverEchoes()
      #expect(system.focusedWindow() == c)
      #expect(listener.log == [], "\(words)")
      #expect(system.frontmost == front, "\(words)")
    }
  }

  @Test func whatArborAskedForBeforeItsProcessEndedHappensAllTheSame() {
    for words in ["", "slow", "late"] {
      for seed in 1...6 {
        let (system, listener, a, _, c) = make(words, seed: UInt64(seed))
        let asked = CGRect(x: 10, y: 40, width: 300, height: 310)
        system.focus(c)
        _ = system.setFrame(asked, of: a)
        listener.log.removeAll()
        system.stop()
        system.forgetSession()
        #expect(listener.log.isEmpty, "nobody is there to hear of it")
        system.start()
        system.deliverEchoes()
        #expect(system.focusedWindow() == c, "\(words) \(seed)")
        #expect(system.frame(of: a) == asked, "\(words) \(seed)")
      }
    }
  }

  @Test func whateverHappensNextTimeHasPassed() {
    let (system, _, a, _, c) = make("slow")
    system.focus(c)
    system.userMove(a, to: CGRect(x: 20, y: 50, width: 300, height: 300))
    #expect(system.focusedWindow() == c, "also after a helper that lets no echoes through")
  }

  // MARK: silent

  @Test func anotherAppComesForwardAndSometimesNobodySaysWhichWindowHasTheKeyboard() {
    var silent = 0
    for seed in 1...60 {
      let (system, listener, _, _, c) = make("silent", seed: UInt64(seed))
      system.userFocus(c)
      #expect(system.focusedWindow() == c, "asked, it tells the truth")
      #expect(system.windowsFrontToBack().first == c)
      if listener.log == ["activated Mail"] { silent += 1 } else { #expect(listener.log == ["activated Mail", "focused \(c)"]) }
      #expect(system.unnoticedSwitches == (listener.log.count == 1 ? 1 : 0))
    }
    #expect((25...55).contains(silent), "two times in three, roughly: \(silent) of 60")
  }

  @Test func withinOneAppTheFocusIsAlwaysReported() {
    for seed in 1...30 {
      let (system, listener, a, b, _) = make("silent", seed: UInt64(seed))
      system.userFocus(b)
      #expect(listener.log == ["focused \(b)"])
      // Also after a click on the Desktop that left the app in front.
      system.userFocusesNothing()
      listener.log.removeAll()
      system.userFocus(a)
      #expect(listener.log == ["focused \(a)"], "seed \(seed)")
    }
  }

  // MARK: numbers

  @Test func anAppsOnlyWindowComesBackUnderItsOldNumber() {
    let (system, listener, _, _, c) = make("numbers")
    system.close(c)
    let again = system.open(app: "Mail", pid: 2)
    #expect(again == c)
    #expect(listener.log.contains("destroyed \(c)") && listener.log.contains("appeared \(c)"))
    let second = system.open(app: "Mail", pid: 2)
    #expect(second != c)
  }

  @Test func noAppGetsTheNumberOfAnothersWindow() {
    let (system, _, _, _, c) = make("numbers")
    system.close(c)
    // Most tests open every app under one pid.
    #expect(system.open(app: "Console", pid: 2) != c)
    #expect(system.open(app: "Mail", pid: 2) == c)
  }

  @Test func anAppThatIsStartedAgainGetsNewNumbers() {
    let (system, _, a, b, c) = make("numbers")
    system.quit(pid: 2)
    #expect(system.open(app: "Mail", pid: 2) != c)
    system.quitApp(pid: 1)
    let new = system.open(app: "Safari", pid: 1)
    #expect(new != a && new != b)
  }

  @Test func anAppWithAnotherWindowLeftGivesANewNumber() {
    let (system, _, a, b, _) = make("numbers")
    system.close(a)
    let new = system.open(app: "Safari", pid: 1)
    #expect(new != a && new != b)
  }

  // MARK: closes

  @Test func theEndOfAWindowIsTheLastThingHeard() {
    let (system, listener, a, b, _) = make("closes")
    system.quit(pid: 1)
    #expect(listener.log.suffix(2) == ["destroyed \(a)", "destroyed \(b)"], "\(listener.log)")
    #expect(system.setFrame(.zero, of: a) == nil)
  }
}
