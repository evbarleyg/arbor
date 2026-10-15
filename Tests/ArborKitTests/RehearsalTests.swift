import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The first motion after a start has nothing to make while somebody waits (Controller+Rehearsal.swift). On a hosted Mac
/// the first dock of a day waited two seconds for the stage, the icons and the colours of nine apps.
@Suite @MainActor struct RehearsalTests {
  let display = FakeWindowSystem.standardDisplay.id

  /// A desk as a day begins: windows of several apps, nothing docked. A moment after the start, unless `rested` is false.
  private func desk(settings: Settings = Settings(), rested: Bool = true) -> (h: Harness, windows: [WindowID]) {
    let h = Harness(settings: settings)
    let windows = ["Finder", "Safari", "Notes", "Mail"].enumerated().map { index, app in
      h.system.open(app: app, pid: Int32(2000 + index), frame: CGRect(x: 100 + 60 * index, y: 100 + 40 * index, width: 600, height: 400))
    }
    h.start()
    if rested { h.scheduler.advance(by: 1) }
    return (h, windows)
  }

  private func app(_ name: String, _ pid: Int32) -> Rehearsal { Rehearsal(displays: [], apps: [Rehearsal.App(pid: pid, bundleID: "com.example.\(name)")]) }

  @Test func theFirstDockMakesNothingThatTheSecondDoesNot() {
    let (h, windows) = desk()
    h.run("dock \(windows[0].rawValue) left")
    #expect(!h.overlays.transitions.isEmpty, "a dock is shown as motion")
    #expect(h.overlays.madeInTheMotion == [])
    h.run("dock \(windows[1].rawValue) right")
    #expect(h.overlays.madeInTheMotion == [])
    expectWindowsMatchLayout(h)
  }

  /// Rule 2: nothing moves until the person docks something. Getting ready asks nothing of any window.
  @Test func gettingReadyTouchesNoWindow() {
    let h = Harness()
    let window = h.system.open(app: "Finder", pid: 2000)
    let before = h.frame(window)
    let budget = h.measure {
      h.start()
      h.scheduler.advance(by: 1)
    }
    #expect(h.overlays.rehearsals.count == 2)
    #expect(budget.moves == 0 && budget.focuses == 0, "\(budget)")
    #expect(h.frame(window) == before)
    #expect(h.overlays.transitions.isEmpty)
  }

  @Test func theStartNamesEveryDisplayAndEveryAppOnce() {
    let (h, _) = desk()
    #expect(
      h.overlays.rehearsals == [
        Rehearsal(displays: [display], apps: []), app("finder", 2000), app("safari", 2001), app("notes", 2002), app("mail", 2003),
      ])
    #expect(!h.scheduler.pendingKeys.contains("rehearsal"), "and then the timer stops")
  }

  /// Shortcuts, taps and the socket are served on the thread the presenter works on.
  @Test func onePieceAtATimeWithAPauseBetweenThem() {
    let (h, _) = desk(rested: false)
    #expect(h.overlays.rehearsals.isEmpty, "the start itself waits for nothing")
    for pieces in 1...5 {
      h.scheduler.advance(by: Controller.pauseBetweenPieces)
      #expect(h.overlays.rehearsals.count == pieces)
    }
  }

  @Test func onlyWhatIsNewIsSaid() {
    let (h, windows) = desk()
    h.run("dock \(windows[0].rawValue) left")
    h.run("zoom \(windows[0].rawValue)")
    h.run("show-all")
    h.system.open(app: "Safari", pid: 2001)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 5, "another window of an app that is known")
    h.system.open(app: "Calendar", pid: 2010)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.last == app("calendar", 2010))
    #expect(h.overlays.rehearsals.count == 6)
  }

  @Test func anAppThatOpensLaterIsReadyBeforeItIsDocked() {
    let (h, windows) = desk()
    h.run("dock \(windows[0].rawValue) left")
    let late = h.system.open(app: "Calendar", pid: 2010)
    h.scheduler.advance(by: 1)
    h.run("dock \(late.rawValue) right")
    #expect(h.overlays.madeInTheMotion == [])
  }

  /// What cannot be helped: nobody knew of the app before its window was there, and a rule docks it in the same breath. (On a Mac
  /// the motion does not wait for the costume either: the window travels as a plain card.)
  @Test func aWindowDockedTheMomentItOpensLacksItsOwnCostumeOnly() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.calendar", action: .dock(.right))]
    let (h, windows) = desk(settings: settings)
    h.run("dock \(windows[0].rawValue) left")
    h.system.open(app: "Calendar", pid: 2010)
    #expect(h.overlays.madeInTheMotion == ["the costume of com.example.calendar"])
  }

  /// Whoever docks in the first instant waits for what is missing, as before, and the rest is got ready afterwards.
  @Test func aMotionThatComesEarlyMakesWhatIsMissingAndTheRestWaitsForItsEnd() {
    let (h, windows) = desk(rested: false)
    h.scheduler.advance(by: Controller.pauseBetweenPieces * 2)
    #expect(h.overlays.rehearsals.count == 2)
    h.run("dock \(windows[0].rawValue) left")
    #expect(h.overlays.madeInTheMotion.count == 3, "three apps' costumes: \(h.overlays.madeInTheMotion)")
    // The timer that lifts the stage runs on the thread a piece would keep busy.
    h.scheduler.advance(by: 0.46)
    #expect(h.overlays.rehearsals.count == 2)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 5)
  }

  /// Nor does news that arrives during a motion jump the queue, nor a correction end the wait early.
  @Test func newsDuringAMotionAndItsCorrectionWaitForTheEndToo() {
    let (h, windows) = desk()
    // It takes its place but not the width: the motion is corrected.
    h.system.setMaximumSize(windows[1], CGSize(width: 300, height: 2000))
    h.run("dock \(windows[0].rawValue) left")
    h.scheduler.advance(by: 1)
    h.overlays.clearTransitions()
    h.run("dock \(windows[1].rawValue) right")
    #expect(h.overlays.transitions.count == 2)
    h.system.open(app: "Calendar", pid: 2010)
    h.scheduler.advance(by: 0.46)
    #expect(h.overlays.rehearsals.count == 5, "the stage is still up, or coming down")
    h.scheduler.advance(by: 0.3)
    #expect(h.overlays.rehearsals.last == app("calendar", 2010))
  }

  /// Coming back from the Dock is a motion with the window in it.
  @Test func aWindowThatWasMinimizedAtTheStartIsReadyToo() {
    let h = Harness()
    let docked = h.system.open(app: "Finder", pid: 2000)
    let away = h.system.open(app: "Notes", pid: 2001)
    h.system.setMinimized(away, true)
    h.start()
    h.scheduler.advance(by: 1)
    h.run("dock \(docked.rawValue) left")
    h.run("dock \(away.rawValue) right")
    h.system.setMinimized(away, false)
    #expect(h.overlays.madeInTheMotion == [])
  }

  @Test func aProcessNumberWithANewOwnerIsSaidAgain() {
    let (h, windows) = desk()
    h.system.close(windows[3])
    h.run("relayout")
    h.system.open(app: "Mail", pid: 2003)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.last == app("mail", 2003))
    #expect(h.overlays.rehearsals.count == 6)
  }

  @Test func anAppThatQuitsBeforeItsTurnIsNotGotReady() {
    let (h, windows) = desk(rested: false)
    h.system.close(windows[3])
    h.run("relayout")
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 4 && !h.overlays.rehearsals.contains(app("mail", 2003)))
  }

  @Test func aDisplayThatJoinsIsNamedAndOneThatComesBackAgain() {
    let (h, windows) = desk()
    let second = Rehearsal(displays: [Workload.secondDisplay.id], apps: [])
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 6 && h.overlays.rehearsals.last == second, "the one that stayed has its stage")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 6)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, Workload.secondDisplay])
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 7 && h.overlays.rehearsals.last == second)
    h.run("dock \(windows[0].rawValue) left")
    #expect(h.overlays.madeInTheMotion == [])
  }

  /// What is not shown is not paid for.
  @Test func withoutMotionNothingIsGotReady() {
    var settings = Settings()
    settings.animationDuration = 0
    let (h, windows) = desk(settings: settings)
    h.run("dock \(windows[0].rawValue) left")
    #expect(h.overlays.rehearsals.isEmpty && !h.scheduler.pendingKeys.contains("rehearsal"))

    settings.animationDuration = 0.3
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 5, "switched on, it is")
    h.run("dock \(windows[1].rawValue) right")
    #expect(h.overlays.madeInTheMotion == [])
  }

  /// The presenter lets go of things when Arbor stops, and nobody tells Arbor what happened meanwhile. It skips what it still has.
  @Test func aStartAfterAPauseSaysItAllAgain() {
    let (h, windows) = desk()
    h.run("dock \(windows[0].rawValue) left")
    h.run("pause")
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 5)
    h.run("resume")
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 10)
  }

  @Test func anArborThatStopsGetsNothingMoreReady() {
    for quits in [false, true] {
      let (h, _) = desk(rested: false)
      h.scheduler.advance(by: Controller.pauseBetweenPieces)
      // Quitting is the app's: it stops the controller.
      if quits { h.controller.shutdown() } else { h.run("pause") }
      #expect(!h.scheduler.pendingKeys.contains("rehearsal"), "\(quits ? "quit" : "pause")")
      h.scheduler.advance(by: 1)
      #expect(h.overlays.rehearsals.count == 1, "\(quits ? "quit" : "pause")")
    }
  }

  /// With macOS's Reduce Motion on a Mac's presenter gets nothing ready. Switched off, it has to hear it all again.
  @Test func askedToItSaysItAllAgain() {
    let (h, _) = desk()
    h.controller.rehearseAfresh()
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 10)
    #expect(Array(h.overlays.rehearsals[5...]) == Array(h.overlays.rehearsals[..<5]))
  }

  /// A Mac's presenter leaves out the covers while stand-ins are pictures of their windows.
  @Test func picturesSwitchedOnOrOffSayItAllAgain() {
    let (h, _) = desk()
    var settings = Settings()
    settings.windowPictures = true
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 10)
    settings.gap = 20
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 1)
    #expect(h.overlays.rehearsals.count == 10, "any other setting does not")
  }

  /// A layout that brings nothing new costs no timer: a gap being dragged lays out at every move of the mouse.
  @Test func aLayoutWithNothingNewSchedulesNothing() {
    let (h, windows) = desk()
    h.run("dock \(windows[0].rawValue) left")
    h.scheduler.advance(by: 1)
    h.run("resize \(windows[0].rawValue) right 40")
    #expect(!h.scheduler.pendingKeys.contains("rehearsal"))
  }

  /// What the first dock asks of the window system is what the second asks: no observer, size or list is fetched late.
  @Test func theFirstDockAsksTheWindowSystemWhatALaterOneAsks() {
    func questions(docksBefore: Int) -> Budget {
      let h = Harness()
      let windows = (0..<4).map { h.system.open(app: "App\($0)", pid: Int32(2000 + $0)) }
      h.start()
      for _ in 0..<docksBefore {
        h.run("dock \(windows[0].rawValue) left")
        h.run("float \(windows[0].rawValue)")
      }
      h.system.userFocus(windows[0])
      return h.measure { h.run("dock \(windows[0].rawValue) left") }
    }
    let (first, later) = (questions(docksBefore: 0), questions(docksBefore: 1))
    #expect(first.focusReads == later.focusReads && first.focuses == later.focuses, "\(first) against \(later)")
    #expect(first.moves <= later.moves, "\(first) against \(later)")
  }
}
