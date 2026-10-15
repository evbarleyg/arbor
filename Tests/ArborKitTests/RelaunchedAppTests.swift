import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// An app that is quit and opened again while Arbor runs goes back to its place. A window that
/// is closed does not keep one. Both arrive as "this window is gone"; what tells them apart is that the app ended.
@Suite @MainActor struct RelaunchedAppTests {
  static let safariPID: Int32 = 2001
  static let notesPID: Int32 = 2002

  /// How an app's end is reported.
  enum Ending: CaseIterable {
    /// ⌘Q: the windows close one by one, then the process ends.
    case windowsFirst
    /// A crash, `kill`, or an app that just exits: the process is gone, and its windows with it.
    case processFirst
  }

  func end(_ pid: Int32, _ ending: Ending, in h: Harness) {
    h.system.quit(pid: pid, windowsFirst: ending == .windowsFirst)
  }

  /// Safari docked on the left and Notes on the right, each app a process of its own, Mail floating.
  func pair() -> (h: Harness, safari: WindowSnapshot, notes: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID)
    let b = h.system.open(app: "Notes", pid: Self.notesPID)
    h.system.open(app: "Mail", pid: 2003)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, h.controller.windows[a]!, b)
  }

  /// The app again, as another process.
  func relaunch(_ window: WindowSnapshot, in h: Harness, title: String? = nil, pid: Int32 = 3001) -> WindowID {
    h.system.open(
      app: window.appName, bundleID: window.bundleID, title: title ?? window.title, pid: pid,
      frame: CGRect(x: 200, y: 150, width: 500, height: 300))
  }

  @Test(arguments: Ending.allCases) func anAppThatIsQuitAndOpenedAgainGoesBackToItsPlace(ending: Ending) {
    let (h, safari, notes) = pair()
    let place = h.frame(safari.id)!
    let notesBefore = h.frame(notes)!
    end(Self.safariPID, ending, in: h)
    h.scheduler.advance(by: 20)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.frame(again) == place)
    #expect(h.frame(notes) == notesBefore)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(Set(h.workspace.tree.allWindows) == [again, notes])
    #expect(!h.run("status").message.contains("kept"))
  }

  @Test(arguments: Ending.allCases) func meanwhileTheNeighboursCloseOverThePlaceAsForAClosedWindow(ending: Ending) {
    let (h, _, notes) = pair()
    let (twin, closed, twinNotes) = pair()
    end(Self.safariPID, ending, in: h)
    twin.system.close(closed.id)
    for harness in [h, twin] { harness.scheduler.advance(by: 1) }
    #expect(h.frame(notes) == twin.frame(twinNotes))
    #expect(h.layout?.windowFrames.keys.sorted() == [notes])
    #expect(h.workspace == twin.workspace, "to the arrangement, a window that goes is a window that goes")
    #expect(!h.run("status").message.contains("kept"))
    #expect(h.controller.snapshot().waiting.isEmpty)
  }

  @Test(arguments: Ending.allCases) func anAppThatIsQuitAndStaysAwayCostsNothing(ending: Ending) {
    // The common case by far.
    let (h, _, _) = pair()
    end(Self.safariPID, ending, in: h)
    h.scheduler.advance(by: 1)
    let (moves, tree) = (h.system.moveLog.count, h.workspace.tree)
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.system.moveLog.count == moves, "nothing moves later on its account")
    #expect(h.workspace.tree == tree)
    #expect(h.scheduler.pendingKeys.filter { $0.hasPrefix("closed-") || $0.hasPrefix("ended-") || $0 == "pending-slots" }.isEmpty)
  }

  @Test func aWindowThatIsClosedKeepsNoPlace() {
    let (h, safari, notes) = pair()
    // Safari has another window, so closing this one ends nothing.
    h.system.open(app: "Safari", title: "Weather", pid: Self.safariPID)
    h.system.close(safari.id)
    #expect(h.workspace.tree.allWindows == [notes], "gone at once")
    // ⌘W, ⌘N: a new window, even with the same title, even at once.
    let new = relaunch(safari, in: h, pid: Self.safariPID)
    #expect(h.workspace.isFloating(new))
    h.scheduler.advance(by: Controller.closedPlaceGrace + 0.1)
    #expect(h.workspace.tree.allWindows == [notes])
    #expect(!h.scheduler.pendingKeys.contains("closed-places"))
    #expect(!h.scheduler.pendingKeys.contains("pending-slots"))
    let later = relaunch(safari, in: h, pid: Self.safariPID)
    #expect(h.workspace.isFloating(later))
  }

  @Test func closingAnAppsLastWindowKeepsNoPlaceEitherWhileTheAppLivesOn() {
    let (h, safari, notes) = pair()
    h.system.close(safari.id)
    h.scheduler.advance(by: Controller.closedPlaceGrace + 0.1)
    #expect(h.workspace.tree.allWindows == [notes])
    // Quit minutes later: there is no place left to keep.
    h.system.quit(pid: Self.safariPID, windowsFirst: true)
    #expect(!h.run("status").message.contains("kept"))
  }

  @Test func anAppThatTakesItsTimeToQuitStillKeepsItsPlace() {
    let (h, safari, _) = pair()
    h.system.close(safari.id)
    h.scheduler.advance(by: Controller.closedPlaceGrace - 0.5)
    h.system.quit(pid: Self.safariPID, windowsFirst: true)
    h.scheduler.advance(by: 30)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
  }

  @Test func thePlaceIsGivenUpWhenTheAppStaysAway() {
    let (h, safari, notes) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    #expect(h.workspace.tree.allWindows == [notes])
    #expect(!h.run("status").message.contains("kept"))
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
  }

  @Test func afterAnUpdateTheWindowMayHaveAnotherTitle() {
    let (h, safari, notes) = pair()
    end(Self.safariPID, .processFirst, in: h)
    let welcome = relaunch(safari, in: h, title: "What's New")
    #expect(h.workspace.isDocked(welcome), "the app's only window takes its only place, for now")
    let real = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(real))
    #expect(h.workspace.isFloating(welcome))
    #expect(Set(h.workspace.tree.allWindows) == [real, notes])
  }

  @Test(arguments: Ending.allCases) func everyWindowOfTheAppGoesBackToItsOwnPlace(ending: Ending) {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID)
    let b = h.system.open(app: "Safari", title: "Weather", pid: Self.safariPID)
    let c = h.system.open(app: "Notes", pid: Self.notesPID)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let (news, weather) = (h.controller.windows[a]!, h.controller.windows[b]!)
    let (newsPlace, weatherPlace) = (h.frame(a)!, h.frame(b)!)
    end(Self.safariPID, ending, in: h)
    // In the other order.
    let newWeather = relaunch(weather, in: h)
    #expect(h.frame(newWeather) == weatherPlace)
    let newNews = relaunch(news, in: h)
    #expect(h.frame(newNews) == newsPlace)
    #expect(h.frame(newWeather) == weatherPlace)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test(arguments: Ending.allCases) func quittingTheAppThatIsFramedDoesNotLeaveAnEmptyView(ending: Ending) {
    let (h, safari, notes) = pair()
    let (twin, closed, _) = pair()
    h.run("zoom \(safari.id.rawValue)")
    twin.run("zoom \(closed.id.rawValue)")
    end(Self.safariPID, ending, in: h)
    twin.system.close(closed.id)
    for harness in [h, twin] { harness.scheduler.advance(by: 1) }
    #expect(h.layout?.windowFrames.keys.sorted() == twin.layout?.windowFrames.keys.sorted(), "as after closing it")
    #expect(h.layout?.windowFrames[notes] != nil)
    #expect(h.system.isVisible(notes))
    // And it still comes back to its place.
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(h.workspace.tree.contains(h.workspace.camera))
  }

  @Test func floatingWindowsKeepNothing() {
    let (h, _, _) = pair()
    h.system.quit(pid: 2003, windowsFirst: true)
    #expect(!h.run("status").message.contains("kept"))
    #expect(!h.scheduler.pendingKeys.contains("closed-places"))
  }

  @Test func rearrangingGivesThePlaceUp() {
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("arrange").ok)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func anAppThatIsNoLongerArrangedKeepsNoPlace() {
    let (h, safari, notes) = pair()
    h.run("exclude \(safari.bundleID!)")
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.workspace.tree.allWindows == [notes])
    #expect(!h.run("status").message.contains("kept"))
  }

  @Test func aWindowClosedJustBeforeArborQuitsLeavesNoPlaceInTheFile() {
    let (h, safari, notes) = pair()
    h.system.close(safari.id)
    h.controller.shutdown()
    #expect(h.store.saved?.workspaces[h.display]?.tree.allWindows == [notes])
  }

  @Test func newsOfAnAppThatEndedIsHarmlessWhenArborIsNotRunningOrKnowsNothingOfIt() {
    let (h, _, notes) = pair()
    h.controller.applicationTerminated(4242)
    h.run("pause")
    h.controller.applicationTerminated(Self.safariPID)
    h.run("resume")
    #expect(h.workspace.isDocked(notes))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    h.controller.shutdown()
    h.controller.applicationTerminated(Self.notesPID)
  }

  @Test func aProcessNumberUsedAgainIsNotTakenForTheAppThatEnded() {
    let (h, _, _) = pair()
    end(Self.safariPID, .processFirst, in: h)
    h.scheduler.advance(by: 10)
    // Another app gets the number, docks a window, and the window is closed and opened again.
    let other = h.system.open(app: "Terminal", title: "zsh", pid: Self.safariPID)
    h.run("dock \(other.rawValue) top")
    h.system.close(other)
    let again = h.system.open(app: "Terminal", title: "zsh", pid: Self.safariPID)
    #expect(h.workspace.isFloating(again))
  }

  @Test(arguments: ["dock 103 top", "float 102", "arrange"])
  func whoeverHasRearrangedMeanwhileHasDecidedOtherwise(command: String) {
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run(command).ok)
    let tree = h.workspace.tree
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
    #expect(h.workspace.tree == tree)
  }

  @Test func movingTheViewIsNotRearranging() {
    let (h, safari, notes) = pair()
    let place = h.frame(safari.id)!
    end(Self.safariPID, .windowsFirst, in: h)
    h.run("zoom \(notes.rawValue)")
    h.run("desktop")
    h.run("show-all")
    let again = relaunch(safari, in: h)
    #expect(h.frame(again) == place)
  }

  /// How the view moves is the rule for any window that takes the keyboard, and not pinned here.
  @Test func theAppThatWasJustOpenedComesIntoViewLikeAnyWindowThatGetsTheKeyboard() {
    let (h, safari, notes) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    h.run("zoom \(notes.rawValue)")
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.system.focusedWindow() == again)
    #expect(h.system.isVisible(again))
    // Back is where the user was.
    h.run("back")
    #expect(h.layout?.windowFrames.keys.sorted() == [notes])
  }

  @Test func anAppThatRestartsItselfInTheBackgroundMovesNoView() {
    let (h, safari, notes) = pair()
    end(Self.safariPID, .processFirst, in: h)
    h.run("zoom \(notes.rawValue)")
    let (camera, back) = (h.workspace.camera, h.workspace.back)
    // An update: nobody asked for it, and the keyboard stays where it is.
    h.system.echoes.keyboard = false
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again), "in its place")
    #expect(h.system.focusedWindow() == notes)
    #expect(h.workspace.camera == camera)
    #expect(h.workspace.back == back)
    #expect(h.layout?.windowFrames.keys.sorted() == [notes])
    #expect(!h.system.isVisible(again), "out of view, like everything else beside what is framed")
    h.run("show-all")
    #expect(h.frame(again)!.maxX < h.frame(notes)!.minX)
  }

  @Test func aWindowClosedMeanwhileStaysClosed() {
    let (h, safari, notes) = pair()
    let mail = WindowID(103)
    h.run("dock 103 beside \(notes.rawValue) bottom")
    end(Self.safariPID, .windowsFirst, in: h)
    h.scheduler.advance(by: 30)
    h.system.close(mail)
    h.scheduler.advance(by: 30)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(Set(h.workspace.tree.allWindows) == [again, notes])
    #expect(h.frame(again)!.maxX < h.frame(notes)!.minX)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func twoAppsThatQuitBothGoBack() {
    let (h, safari, notesID) = pair()
    let notes = h.controller.windows[notesID]!
    let (safariPlace, notesPlace) = (h.frame(safari.id)!, h.frame(notesID)!)
    end(Self.safariPID, .windowsFirst, in: h)
    end(Self.notesPID, .processFirst, in: h)
    #expect(h.workspace.tree.allWindows.isEmpty)
    let newNotes = relaunch(notes, in: h, pid: 3002)
    #expect(h.workspace.isDocked(newNotes))
    h.scheduler.advance(by: 30)
    let newSafari = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(newSafari))
    #expect(h.frame(newSafari) == safariPlace)
    #expect(h.frame(newNotes) == notesPlace)
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  /// `[ a | visitor | b | Desktop ]`: whoever gave the visitor room gets it back, and gives it again.
  @Test func roomThatWasGivenBackIsTakenAgainFromWhereItCame() {
    // Wide enough for four columns.
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [wide])
    let (a, b) = (h.system.open(app: "A", pid: 2001), h.system.open(app: "B", pid: 2002))
    let v = h.system.open(app: "Visitor", pid: 2003)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    let without = [h.frame(a), h.frame(b)]
    h.run("dock \(v.rawValue) beside \(a.rawValue) right")
    let visitor = h.controller.windows[v]!
    let with = [h.frame(a), h.frame(b), h.frame(v)]
    #expect(h.layout!.tiles.isEmpty)
    h.system.quit(pid: 2003)
    #expect([h.frame(a), h.frame(b)] == without)
    let again = relaunch(visitor, in: h)
    #expect([h.frame(a), h.frame(b), h.frame(again)] == with)
    // And once more, for good this time.
    h.system.close(again)
    #expect([h.frame(a), h.frame(b)] == without)
  }
}

extension RelaunchedAppTests {
  @Test func historyDoesNotLeadToAViewOfNothing() {
    let (h, safari, notes) = pair()
    h.run("zoom \(safari.id.rawValue)")
    h.run("show-all")
    end(Self.safariPID, .windowsFirst, in: h)
    let result = h.run("back")
    #expect(h.layout?.windowFrames[notes] != nil, "\(result.message): \(h.ascii())")
    #expect(h.system.isVisible(notes))
  }

  @Test func aSavedViewOfTheAppThatQuitComesBackWithIt() {
    let (h, safari, notes) = pair()
    h.run("zoom \(safari.id.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    end(Self.safariPID, .windowsFirst, in: h)
    let meanwhile = h.run("view 1")
    #expect(h.system.isVisible(notes), "\(meanwhile.message): \(h.ascii())")
    let again = relaunch(safari, in: h)
    #expect(h.run("view 1").ok)
    #expect(h.layout?.windowFrames.keys.sorted() == [again], "the saved view frames Safari again")
  }
}

/// Corners: the view, names and saved views, gaps, and a second copy of the app.
extension RelaunchedAppTests {
  @Test func whenTheLastDockedWindowHadGoneTheViewIsStillOnEverything() {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID)
    h.start()
    h.run("dock \(a.rawValue) left")
    let (safari, place) = (h.controller.windows[a]!, h.frame(a)!)
    #expect(h.workspace.camera == h.workspace.tree.root)
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.workspace.camera == h.workspace.tree.root, "which is the Desktop now")
    // In the background, so that no rule about the keyboard comes to the rescue.
    h.system.echoes.keyboard = false
    let again = relaunch(safari, in: h)
    #expect(h.workspace.camera == h.workspace.tree.root, "everything, as before")
    #expect(h.frame(again) == place)
    #expect(h.system.isVisible(again))
  }

  @Test func theNameOfItsSpaceComesBackWithTheApp() {
    let (h, safari, notes) = pair()
    h.run("zoom \(safari.id.rawValue)")
    #expect(h.run("name Web").ok)
    h.run("show-all")
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.workspace.names.isEmpty)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.names["Web"] == h.workspace.tree.leaf(containing: again))
    #expect(h.run("go Web").ok)
    #expect(h.layout?.windowFrames.keys.sorted() == [again])
    #expect(h.workspace.isDocked(notes))
  }

  @Test func aNameGivenToSomethingElseMeanwhileStaysThere() {
    let (h, safari, notes) = pair()
    h.run("zoom \(safari.id.rawValue)")
    h.run("name Web")
    h.run("show-all")
    end(Self.safariPID, .windowsFirst, in: h)
    h.run("zoom \(notes.rawValue)")
    #expect(h.run("name web").ok)
    _ = relaunch(safari, in: h)
    #expect(h.workspace.names == ["web": h.workspace.tree.leaf(containing: notes)!])
  }

  @Test func aViewSavedOverBetweenTwoGoingsIsNotOverwritten() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    h.run("zoom \(safari.id.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    end(Self.safariPID, .windowsFirst, in: h)
    h.run("zoom \(notes.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.system.quit(pid: 2003)  // Mail
    _ = relaunch(safari, in: h)
    #expect(h.workspace.savedViews["1"] == h.workspace.tree.leaf(containing: notes), "the person's, not the old one")
  }

  /// Arbor moves gaps by itself (room before tiles), and a person's `resize` fits the arrangement without the app.
  @Test(arguments: [400, 450, 500, 560]) func gapsThatMovedMeanwhileAreNotARearrangement(minimum: Int) {
    let h = Harness()
    let size = CGSize(width: minimum, height: 100)
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID, minimumSize: size)
    let b = h.system.open(app: "Notes", pid: Self.notesPID, minimumSize: size)
    let c = h.system.open(app: "Mail", pid: 2003, minimumSize: size)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) left")
    h.scheduler.advance(by: 2)
    let safari = h.controller.windows[a]!
    let before = h.workspace.tree
    end(Self.safariPID, .windowsFirst, in: h)
    h.scheduler.advance(by: 2)
    h.run("zoom \(b.rawValue)")
    h.run("show-all")
    let again = h.system.open(
      app: "Safari", title: "News", pid: 3001, frame: CGRect(x: 200, y: 150, width: 600, height: 300), minimumSize: size)
    #expect(h.workspace.isDocked(again), "\(safari.id)")
    #expect(h.workspace.tree.preorder() == before.preorder())
    #expect(h.workspace.tree.invariantViolations().isEmpty)
  }

  @Test func aGapMovedByHandMeanwhileIsNotARearrangementEither() {
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("resize 102 left 60").ok)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
  }

  @Test func anotherCopyOfTheAppThatWasRunningAllAlongIsNotTheAppComingBack() {
    let (h, safari, _) = pair()
    // `open -n`: the same bundle id, another process, alive before and after.
    h.system.open(app: "Safari", title: "Other", pid: 2900)
    end(Self.safariPID, .windowsFirst, in: h)
    let tree = h.workspace.tree
    let new = relaunch(safari, in: h, pid: 2900)
    #expect(h.workspace.isFloating(new))
    #expect(h.workspace.tree == tree)
    // The app itself still finds its place.
    let again = relaunch(safari, in: h, pid: 3001)
    #expect(h.workspace.isDocked(again))
  }
}

/// Where it meets undo (F19).
extension RelaunchedAppTests {
  @Test(arguments: Ending.allCases) func undoAfterTheAppIsBackActsOnTheWindowItHasNow(ending: Ending) {
    let (h, safari, notes) = pair()
    end(Self.safariPID, ending, in: h)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    // The last thing the person did was to dock Notes on the right.
    for _ in 0..<4 {
      h.run("undo")
      #expect(h.workspace.tree.invariantViolations().isEmpty)
      #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
      #expect(!h.workspace.tree.allWindows.contains(safari.id), "no number of a window that is gone")
    }
    for _ in 0..<4 { h.run("redo") }
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    h.controller.shutdown()
    for window in [again, notes] { #expect(h.system.isVisible(window)) }
  }

  /// The first `undo` says that a window closed; the second undocks Notes, and whoever rearranges has decided otherwise.
  @Test func undoWhileTheAppIsAwayCanBeARearrangement() {
    let (h, safari, notes) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(!h.run("undo").ok)
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(notes))
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }

  /// A step from before the app went, taken back or put back while it is away, is made anew of arrangements without it.
  @Test(arguments: [false, true]) func aStepFromBeforeThatWasWalkedThroughMeanwhileLeavesTheAppInItsPlace(redoneMeanwhile: Bool) {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    #expect(h.run("resize 103 top 80").ok)
    h.scheduler.advance(by: 2)
    let resized = h.frame(WindowID(103))!.height
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(!h.run("undo").ok)
    #expect(h.run("undo").message.contains("resize"))
    let plain = h.frame(WindowID(103))!.height
    #expect(plain != resized)
    if redoneMeanwhile { #expect(h.run("redo").ok) }
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.run(redoneMeanwhile ? "undo" : "redo").message.contains("resize"))
    #expect(h.workspace.isDocked(again))
    #expect(h.frame(WindowID(103))!.height == (redoneMeanwhile ? plain : resized))
    expectWindowsMatchLayout(h)
  }
}

/// It comes back in one layout, and takes nothing back that a person has done.
extension RelaunchedAppTests {
  /// How often Arbor has moved each window since `mark`, leaving out answers that changed nothing.
  func moves(since mark: Int, in h: Harness) -> [WindowID: Int] {
    h.system.moveLog[mark...].filter { $0.before != $0.after }.reduce(into: [:]) { $0[$1.window, default: 0] += 1 }
  }

  /// `[ a | visitor | b | Desktop ]` on a display wide enough for four columns.
  func row() -> (h: Harness, a: WindowID, b: WindowID, visitor: WindowSnapshot) {
    let wide = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415), isMain: true)
    let h = Harness(displays: [wide])
    let (a, b) = (h.system.open(app: "A", pid: 2001), h.system.open(app: "B", pid: 2002))
    let v = h.system.open(app: "Visitor", pid: 2003)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    h.run("dock \(v.rawValue) beside \(a.rawValue) right")
    return (h, a, b, h.controller.windows[v]!)
  }

  @Test(arguments: Ending.allCases) func whenTheAppIsBackEveryWindowMovesOnce(ending: Ending) {
    let (h, a, b, visitor) = row()
    end(2003, ending, in: h)
    let mark = h.system.moveLog.count
    let again = relaunch(visitor, in: h)
    #expect(moves(since: mark, in: h) == [a: 1, b: 1, again: 1])
    expectWindowsMatchLayout(h)
  }

  /// By the time Arbor hears of a new window it has the keyboard as a rule (docs/REALITY.md), and the view goes to whoever has it.
  /// The window is not sent out of view first.
  @Test func withTheViewElsewhereTheWindowThatHasTheKeyboardStillMovesOnce() {
    let (h, safari, notes) = pair()
    h.run("zoom \(notes.rawValue)")
    end(Self.safariPID, .windowsFirst, in: h)
    let mark = h.system.moveLog.count
    h.system.focused = WindowID(104)
    let again = relaunch(safari, in: h)
    #expect(again == WindowID(104))
    h.scheduler.advance(by: 2)
    #expect(h.workspace.isDocked(again))
    #expect(h.system.isVisible(again))
    #expect(moves(since: mark, in: h) == [again: 1, notes: 1])
    h.run("back")
    #expect(h.layout?.windowFrames.keys.sorted() == [notes])
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: ["hold", "hold still"]) func onAHeldViewNothingIsPutBack(hold: String) {
    let (h, safari, notes) = pair()
    #expect(h.run(hold).ok)
    end(Self.safariPID, .processFirst, in: h)
    let (camera, tree, mark) = (h.workspace.camera, h.workspace.tree, h.system.moveLog.count)
    // It restarts by itself, in front of an audience.
    h.system.echoes.keyboard = false
    let again = relaunch(safari, in: h)
    #expect(h.workspace.camera == camera)
    #expect(h.workspace.tree == tree)
    #expect(h.workspace.isFloating(again))
    #expect(moves(since: mark, in: h)[notes] == nil)
    #expect(h.system.isVisible(notes))
    // Nor when the view is let go, nor for a title that comes late.
    #expect(h.run("release").ok)
    h.system.setTitle(again, "Loading")
    h.system.setTitle(again, safari.title)
    #expect(h.workspace.isFloating(again))
    #expect(moves(since: mark, in: h)[notes] == nil)
    #expect(h.controller.snapshot().waiting.isEmpty)
    expectWindowsMatchLayout(h)
  }

  /// `[ Safari | Desktop | Notes / Mail ]`: the gap between Notes and Mail has nothing to do with Safari.
  @Test func aGapMovedElsewhereMeanwhileStaysWhereItWasPut() {
    let (h, safari, notes) = pair()
    let mail = WindowID(103)
    h.run("dock 103 beside \(notes.rawValue) bottom")
    let (place, width) = (h.frame(safari.id)!, h.frame(notes)!.width)
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("resize 103 top 80").ok)
    let heights = [h.frame(notes)!.height, h.frame(mail)!.height]
    let again = relaunch(safari, in: h)
    #expect([h.frame(notes)!.height, h.frame(mail)!.height] == heights)
    #expect(h.frame(again) == place)
    #expect(h.frame(notes)!.width == width)
    expectWindowsMatchLayout(h)
  }

  /// `[ Safari | Desktop | Notes ]`: with Safari away the person makes Notes wider. Safari gets its width back, and of what
  /// is left Notes has the share the person gave it.
  @Test func aGapMovedInItsOwnRowMeanwhileStaysMoved() {
    let (h, safari, notes) = pair()
    let (place, before) = (h.frame(safari.id)!, h.frame(notes)!)
    end(Self.safariPID, .windowsFirst, in: h)
    let closedUp = h.frame(notes)!.width
    #expect(h.run("resize \(notes.rawValue) left 200").ok)
    let share = h.frame(notes)!.width / closedUp
    #expect(share > 1.2)
    let again = relaunch(safari, in: h)
    #expect(h.frame(again) == place)
    #expect(h.frame(notes)!.maxX == before.maxX)
    #expect(abs(h.frame(notes)!.width / before.width - share) < 0.02, "\(h.frame(notes)!.width) of \(before.width), \(share)")
    expectWindowsMatchLayout(h)
  }

  /// `[ Safari | Desktop | Notes / Mail ]`: when Mail goes, the column it was in goes too, and Notes stands in the row itself.
  @Test func aGapMovedBesideWhatIsLeftOfItsGroupStaysMoved() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    let mail = h.controller.windows[WindowID(103)]!
    let (width, heights) = (h.frame(notes)!.width, [h.frame(notes)!.height, h.frame(mail.id)!.height])
    end(2003, .windowsFirst, in: h)
    #expect(h.frame(notes)!.width == width)
    #expect(h.run("resize \(notes.rawValue) left 120").ok)
    let (wider, place) = (h.frame(notes)!, h.frame(safari.id)!)
    #expect(wider.width == width + 120)
    let again = relaunch(mail, in: h, pid: 3003)
    #expect(h.workspace.isDocked(again))
    #expect([h.frame(notes)!.width, h.frame(again)!.width] == [wider.width, wider.width])
    #expect([h.frame(notes)!.height, h.frame(again)!.height] == heights)
    #expect(h.frame(safari.id) == place)
    expectWindowsMatchLayout(h)
  }

  @Test func aGapMovedBetweenTwoGoingsStaysMoved() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    let mail = h.controller.windows[WindowID(103)]!
    h.system.open(app: "Chat", pid: 2004)
    h.run("dock 104 beside \(notes.rawValue) top")
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("resize 104 bottom 60").ok)
    let height = h.frame(WindowID(104))!.height
    end(2003, .windowsFirst, in: h)
    _ = relaunch(mail, in: h, pid: 3003)
    _ = relaunch(safari, in: h)
    #expect(h.workspace.tree.allWindows.count == 4)
    #expect(h.frame(WindowID(104))!.height == height)
    expectWindowsMatchLayout(h)
  }

  @Test func undoAfterTheReturnTakesBackWhatThePersonDidAndLeavesTheAppInItsPlace() {
    let (h, safari, notes) = pair()
    let before = [h.frame(safari.id)!, h.frame(notes)!]
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("resize \(notes.rawValue) left 60").ok)
    let again = relaunch(safari, in: h)
    let resized = [h.frame(again)!, h.frame(notes)!]
    #expect(resized != before)
    let undone = h.run("undo")
    #expect(undone.ok && undone.message.contains("resize"), "\(undone.message)")
    #expect(h.workspace.isDocked(again))
    #expect([h.frame(again)!, h.frame(notes)!] == before)
    #expect(h.run("redo").ok)
    #expect(h.workspace.isDocked(again))
    #expect([h.frame(again)!, h.frame(notes)!] == resized)
    expectWindowsMatchLayout(h)
  }

  /// A window that closed cannot be brought back by `undo`, which says so once. This one is back.
  @Test(arguments: Ending.allCases) func undoNoLongerSaysThatAWindowClosed(ending: Ending) {
    let (h, safari, notes) = pair()
    end(Self.safariPID, ending, in: h)
    #expect(h.run("undo").message.contains("cannot undo the closing"))
    let (other, closed, _) = pair()
    end(Self.safariPID, ending, in: other)
    let again = relaunch(closed, in: other)
    let undone = other.run("undo")
    #expect(undone.ok && undone.message.contains("dock"), "\(undone.message)")
    #expect(other.workspace.isDocked(again) && other.workspace.isFloating(notes))
    _ = safari
  }

  /// Docked and taken back while the app was away: the arrangement is as the app left it, so it goes back. Putting the dock
  /// back now would put back an arrangement without the app.
  @Test func redoAfterTheReturnDoesNotTakeTheAppOutOfItsPlace() {
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    #expect(h.run("dock 103 top").ok)
    #expect(h.run("undo").ok)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    h.run("redo")
    #expect(h.workspace.isDocked(again))
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
    expectWindowsMatchLayout(h)
  }

  /// `[ a | News | Desktop | Weather | b ]`.
  func browserBetweenOthers() -> (h: Harness, a: WindowID, news: WindowID, weather: WindowID, b: WindowID) {
    let (h, a, b, visitor) = row()
    h.system.close(visitor.id)
    h.run("dock \(b.rawValue) right")
    let news = h.system.open(app: "Safari", title: "News", pid: 2010)
    let weather = h.system.open(app: "Safari", title: "Weather", pid: 2010)
    h.run("dock \(news.rawValue) beside \(a.rawValue) right")
    h.run("dock \(weather.rawValue) beside \(b.rawValue) left")
    #expect(h.layout!.tiles.isEmpty)
    return (h, a, news, weather, b)
  }

  /// The browser comes back with one window that is neither of the two it had.
  @Test func aWindowThatTakesNoPlaceMovesNothingAndThePlacesGoOnWaiting() {
    let (h, a, news, weather, b) = browserBetweenOthers()
    let (snapshot, places) = (h.controller.windows[news]!, [h.frame(a)!, h.frame(news)!, h.frame(weather)!, h.frame(b)!])
    end(2010, .windowsFirst, in: h)
    h.scheduler.advance(by: 10)
    #expect([h.frame(a)!, h.frame(b)!] != [places[0], places[3]])
    let (tree, mark) = (h.workspace.tree, h.system.moveLog.count)
    let start = relaunch(snapshot, in: h, title: "Start Page")
    #expect(h.workspace.isFloating(start))
    #expect(h.workspace.tree == tree)
    #expect(moves(since: mark, in: h).isEmpty, "\(moves(since: mark, in: h))")
    #expect(h.controller.snapshot().waiting.isEmpty)
    // It was only slow to say which it is.
    h.system.setTitle(start, "Weather")
    #expect(h.workspace.isDocked(start))
    #expect(moves(since: mark, in: h).values.allSatisfy { $0 == 1 }, "\(moves(since: mark, in: h))")
    let again = relaunch(snapshot, in: h)
    #expect([h.frame(a)!, h.frame(again)!, h.frame(start)!, h.frame(b)!] == places)
    expectWindowsMatchLayout(h)
  }

  /// What it looks like depends on who is away, never on the order they went or come back in.
  @Test(arguments: Ending.allCases, [false, true]) func whileOneWindowIsStillAwayThingsAreAsIfOnlyThatOneHadGone(
    ending: Ending, newsFirst: Bool
  ) {
    let (h, a, news, weather, b) = browserBetweenOthers()
    let (first, second) = newsFirst ? (news, weather) : (weather, news)
    let (back, away) = (h.controller.windows[first]!, h.controller.windows[second]!)
    let places = [a, first, second, b].map { h.frame($0)! }
    end(2010, ending, in: h)
    var mark = h.system.moveLog.count
    let one = relaunch(back, in: h)
    #expect(moves(since: mark, in: h).values.allSatisfy { $0 == 1 }, "\(moves(since: mark, in: h))")
    // Nothing waits in the tree, so that nothing has to be taken out of it if the other never comes.
    #expect(Set(h.workspace.tree.allWindows) == [a, one, b])
    #expect(h.controller.snapshot().waiting.isEmpty)
    #expect(!h.run("status").message.contains("kept"))

    let twin = browserBetweenOthers()
    twin.h.system.close(newsFirst ? twin.weather : twin.news)
    #expect([a, one, b].map { h.frame($0)! } == [twin.a, newsFirst ? twin.news : twin.weather, twin.b].map { twin.h.frame($0)! })

    mark = h.system.moveLog.count
    let other = relaunch(away, in: h)
    #expect(moves(since: mark, in: h).values.allSatisfy { $0 == 1 }, "\(moves(since: mark, in: h))")
    #expect([a, one, other, b].map { h.frame($0)! } == places)
    expectWindowsMatchLayout(h)
  }

  @Test func theWindowThatStaysAwayCostsNothing() {
    let (h, _, news, _, _) = browserBetweenOthers()
    let back = h.controller.windows[news]!
    end(2010, .windowsFirst, in: h)
    _ = relaunch(back, in: h)
    h.scheduler.advance(by: 1)
    let (moves, tree) = (h.system.moveLog.count, h.workspace.tree)
    h.scheduler.advance(by: Controller.pendingSlotLifetime * 2)
    #expect(h.system.moveLog.count == moves)
    #expect(h.workspace.tree == tree)
    #expect(h.scheduler.pendingKeys.filter { $0.hasPrefix("closed-") || $0.hasPrefix("ended-") || $0 == "pending-slots" }.isEmpty)
  }

  /// The first window to open may be one that floated. It is not moved into the place and out again.
  @Test(arguments: Ending.allCases, [false, true]) func anAppThatHadOtherWindowsGoesBackByTitleAlone(ending: Ending, looseOneIsOlder: Bool) {
    let h = Harness()
    var loose = looseOneIsOlder ? h.system.open(app: "Safari", title: "Downloads", pid: Self.safariPID) : WindowID(0)
    let docked = h.system.open(app: "Safari", title: "News", pid: Self.safariPID)
    if !looseOneIsOlder { loose = h.system.open(app: "Safari", title: "Downloads", pid: Self.safariPID) }
    let notes = h.system.open(app: "Notes", pid: Self.notesPID)
    h.start()
    h.run("dock \(docked.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    let (news, downloads, place) = (h.controller.windows[docked]!, h.controller.windows[loose]!, h.frame(docked)!)
    end(Self.safariPID, ending, in: h)
    let (tree, mark) = (h.workspace.tree, h.system.moveLog.count)
    let first = relaunch(downloads, in: h)
    #expect(h.workspace.isFloating(first))
    #expect(h.workspace.tree == tree)
    #expect(moves(since: mark, in: h)[notes] == nil)
    let second = relaunch(news, in: h)
    #expect(h.frame(second) == place)
    #expect(h.workspace.isFloating(first))
    #expect(moves(since: mark, in: h)[notes] == 1 && moves(since: mark, in: h)[second] == 1)
    expectWindowsMatchLayout(h)
  }

  /// One window on each display. Rearranging one display gives up the place there, and the window that had it does not take the other's.
  @Test func aSiblingOnAnotherDisplayCountsAsOne() {
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, second])
    let far = h.system.open(app: "Safari", title: "Weather", pid: Self.safariPID, frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    let near = h.system.open(app: "Safari", title: "News", pid: Self.safariPID)
    let notes = h.system.open(app: "Notes", pid: Self.notesPID, frame: CGRect(x: 1700, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(far.rawValue) left")
    h.run("dock \(near.rawValue) left")
    #expect(h.controller.workspaces[second.id]!.isDocked(far) && h.workspace.isDocked(near))
    let weather = h.controller.windows[far]!
    end(Self.safariPID, .windowsFirst, in: h)
    h.run("dock \(notes.rawValue) right")
    #expect(h.controller.workspaces[second.id]!.isDocked(notes))
    let again = relaunch(weather, in: h)
    #expect(!h.controller.workspaces.values.contains { $0.isDocked(again) })
  }

  /// ⌘T in a docked Terminal gives its window another number. Nobody has rearranged anything.
  @Test func aNeighbourThatChangesItsNumberMeanwhileIsStillTheSameWindow() {
    let (h, safari, notes) = pair()
    let place = h.frame(safari.id)!
    end(Self.safariPID, .windowsFirst, in: h)
    var tab = h.controller.windows[notes]!
    tab.id = WindowID(140)
    h.controller.windowReplaced(notes, by: tab)
    #expect(h.workspace.isDocked(tab.id))
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.frame(again) == place)
  }

  /// `[ a | Desktop | (b | e | c | d) ]`: the group lies in a row on its own axis, and goes on existing because the view is on it, and
  /// then because it has a name or a saved view.
  @Test(arguments: ["name Work", "save-view 1"]) func aGroupNamedOrSavedMeanwhileIsStillOneWhileSomebodyIsAway(mark: String) throws {
    let h = Harness(displays: [row().h.system.displayList[0]])
    let windows = ["A", "B", "E", "C", "D"].enumerated().map { h.system.open(app: $1, pid: Int32(2001 + $0)) }
    let (a, b, e, c, d) = (windows[0], windows[1], windows[2], windows[3], windows[4])
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    for window in [e, c, d] { h.run("dock \(window.rawValue) right") }
    let group = h.workspace.camera
    try #require(h.workspace.tree.windows(under: group) == [b, e, c, d])
    let (third, fourth) = (h.controller.windows[c]!, h.controller.windows[d]!)
    h.system.quit(pid: third.pid)
    h.system.quit(pid: fourth.pid)
    try #require(h.workspace.camera == group && h.workspace.tree.windows(under: group) == [b, e])
    #expect(h.run(mark).ok)
    h.run("show-all")
    try #require(h.workspace.tree.contains(group))
    let mark = h.system.moveLog.count
    let again = relaunch(third, in: h, pid: 3003)
    #expect(h.workspace.isDocked(again))
    #expect(h.workspace.tree.windows(under: group) == [b, e, again], "\(h.ascii())")
    #expect((h.workspace.names.values.first ?? h.workspace.savedViews["1"]) == group)
    #expect(moves(since: mark, in: h).values.allSatisfy { $0 == 1 }, "\(moves(since: mark, in: h))")
    let last = relaunch(fourth, in: h, pid: 3004)
    #expect(h.workspace.tree.windows(under: group) == [b, e, again, last])
    #expect((h.workspace.names.values.first ?? h.workspace.savedViews["1"]) == group)
    expectWindowsMatchLayout(h)
  }

  /// A tab that has the keyboard comes to the front. It is not sent out of view first, as the tab behind.
  @Test func aTabThatHasTheKeyboardMovesOnce() {
    let (h, safari, notes) = pair()
    h.system.userFocus(safari.id)
    #expect(h.run("layout [Notes Safari] | Mail").ok)
    end(Self.safariPID, .windowsFirst, in: h)
    let mark = h.system.moveLog.count
    h.system.focused = WindowID(104)
    let again = relaunch(safari, in: h)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.tree.leaf(containing: again) == h.workspace.tree.leaf(containing: notes))
    #expect(h.layout?.windowFrames[again] != nil)
    #expect(moves(since: mark, in: h)[again] == 1, "\(moves(since: mark, in: h))")
    expectWindowsMatchLayout(h)
  }

  /// Closings in a row are one step of `undo`, the last. A window that was closed for good just before is still closed.
  @Test func undoStillSaysThatAnotherWindowClosed() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    h.system.open(app: "Mail", title: "Other", pid: 2003)
    h.system.close(WindowID(103))
    h.scheduler.advance(by: 20)
    end(Self.safariPID, .windowsFirst, in: h)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    let reply = h.run("undo")
    #expect(!reply.ok && reply.message.contains("cannot undo the closing"), "\(reply.message)")
    #expect(h.workspace.isDocked(again) && h.workspace.isDocked(notes))
  }

  /// What is known of the window that had the place is lent to the one that holds it, and handed on.
  @Test func whatWasKnownOfTheWindowGoesToTheOneThatTakesThePlaceOver() throws {
    let h = Harness()
    let size = CGSize(width: 560, height: 100)
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID, minimumSize: size)
    let b = h.system.open(app: "Notes", pid: Self.notesPID, minimumSize: size)
    let c = h.system.open(app: "Mail", pid: 2003, minimumSize: size)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) left")
    h.scheduler.advance(by: 2)
    let known = try #require(h.controller.minimumSizes[a])
    end(Self.safariPID, .windowsFirst, in: h)
    let welcome = h.system.open(app: "Safari", title: "What's New", pid: 3001, frame: CGRect(x: 200, y: 150, width: 300, height: 200))
    #expect(h.workspace.isDocked(welcome))
    let real = h.system.open(
      app: "Safari", title: "News", pid: 3001, frame: CGRect(x: 200, y: 150, width: 600, height: 300), minimumSize: size)
    #expect(h.workspace.isDocked(real) && h.workspace.isFloating(welcome))
    #expect(h.controller.minimumSizes[real] == known)
    #expect(h.controller.minimumSizes[welcome] == nil)
  }

  /// Rule 5. The window that is back is another window, and its own size is the one it opened with, not the one that the
  /// window before it had before it was docked.
  @Test(arguments: ["float 104", "float-all", "pause", "quit"]) func whatIsGivenBackToTheReturnedWindowIsTheSizeItOpenedWith(way: String) {
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    let again = relaunch(safari, in: h)
    #expect(again == WindowID(104) && h.workspace.isDocked(again))
    #expect(h.frame(again)!.size != CGSize(width: 500, height: 300))
    if way == "quit" { h.controller.shutdown() } else { #expect(h.run(way).ok) }
    #expect(h.frame(again)!.size == CGSize(width: 500, height: 300))
  }

  /// `undo` of the dock from before the app went floats the window there is now, at its own size.
  @Test func undoingTheDockOfTheWindowBeforeItGivesTheReturnedWindowItsOwnSize() {
    let h = Harness()
    let a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID, frame: CGRect(x: 300, y: 200, width: 789, height: 499))
    h.start()
    h.run("dock \(a.rawValue) left")
    let safari = h.controller.windows[a]!
    end(Self.safariPID, .windowsFirst, in: h)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(again))
    #expect(h.run("undo").message.contains("dock"))
    #expect(h.workspace.isFloating(again))
    #expect(h.frame(again) == CGRect(x: 200, y: 150, width: 500, height: 300))
    #expect(h.run("redo").ok && h.workspace.isDocked(again))
    #expect(h.run("float \(again.rawValue)").ok)
    #expect(h.frame(again)!.size == CGSize(width: 500, height: 300))
  }

  /// The window that takes the place over from the one that held it has its own size too, not the holder's.
  @Test func theWindowThatTakesThePlaceOverHasItsOwnSize() {
    let (h, safari, _) = pair()
    end(Self.safariPID, .processFirst, in: h)
    let welcome = h.system.open(
      app: "Safari", title: "What's New", pid: 3001, frame: CGRect(x: 240, y: 180, width: 420, height: 260))
    #expect(h.workspace.isDocked(welcome))
    let real = relaunch(safari, in: h)
    #expect(h.workspace.isDocked(real) && h.workspace.isFloating(welcome))
    #expect(h.frame(welcome)!.size == CGSize(width: 420, height: 260))
    #expect(h.run("float \(real.rawValue)").ok)
    #expect(h.frame(real)!.size == CGSize(width: 500, height: 300))
  }

  /// One that floated for a while first, until its title came, has the size its person gave it meanwhile.
  @Test func whatIsGivenBackToAWindowThatWasSlowToSayWhichItIsIsTheSizeItHadThen() {
    let (h, _, news, _, _) = browserBetweenOthers()
    let snapshot = h.controller.windows[news]!
    end(2010, .windowsFirst, in: h)
    let start = relaunch(snapshot, in: h, title: "Start Page")
    h.system.userMove(start, to: CGRect(x: 900, y: 300, width: 700, height: 450))
    h.system.setTitle(start, "News")
    #expect(h.workspace.isDocked(start))
    #expect(h.run("float \(start.rawValue)").ok)
    #expect(h.frame(start)!.size == CGSize(width: 700, height: 450))
  }

  /// Arbor moves gaps by itself (room before tiles). That is nobody's decision, and with that alone there and back is nothing.
  @Test(arguments: [400, 450, 500, 560]) func withOnlyArborsOwnGapsMovedEverybodyIsExactlyWhereTheyWere(minimum: Int) {
    let h = Harness()
    let size = CGSize(width: minimum, height: 100)
    var a = h.system.open(app: "Safari", title: "News", pid: Self.safariPID, minimumSize: size)
    let b = h.system.open(app: "Notes", pid: Self.notesPID, minimumSize: size)
    let c = h.system.open(app: "Mail", pid: 2003, minimumSize: size)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) left")
    h.scheduler.advance(by: 2)
    /// Safari quits, the person looks about, Safari is opened again. Returns what there is to see of everything.
    func thereAndBack() -> ([CGRect?], [NodeID: Double]) {
      h.system.quit(pid: h.controller.windows[a]!.pid)
      h.scheduler.advance(by: 2)
      h.run("zoom \(b.rawValue)")
      h.run("show-all")
      a = h.system.open(
        app: "Safari", title: "News", pid: h.system.allWindows().map(\.pid).max()! + 1,
        frame: CGRect(x: 200, y: 150, width: 600, height: 300), minimumSize: size)
      h.scheduler.advance(by: 2)
      h.run("show-all")
      h.scheduler.advance(by: 2)
      #expect(h.workspace.isDocked(a))
      let tree = h.workspace.tree
      return ([a, b, c].map { h.layout!.windowFrames[$0] }, Dictionary(uniqueKeysWithValues: tree.preorder().map { ($0, tree[$0]!.weight) }))
    }
    // The first time Arbor still learns how small the windows go.
    let first = thereAndBack()
    for _ in 0..<3 {
      let next = thereAndBack()
      #expect(next.0 == first.0)
      // (To the last digits but a few: where somebody is short, room is made afresh, by arithmetic.)
      #expect(next.1.keys == first.1.keys && next.1.allSatisfy { abs($0.value - first.1[$0.key]!) < 1e-9 }, "\(next.1), \(first.1)")
    }
    expectWindowsMatchLayout(h)
  }

  /// The tab in front is what the person is looking at. An app that restarts by itself does not cover it.
  @Test func theTabInFrontStaysInFront() {
    let (h, safari, notes) = pair()
    h.system.userFocus(safari.id)
    #expect(h.run("layout [Notes Safari] | Mail").ok)
    #expect(h.workspace.tree.leaf(containing: notes) == h.workspace.tree.leaf(containing: safari.id))
    #expect(h.layout?.windowFrames[safari.id] != nil)
    end(Self.safariPID, .processFirst, in: h)
    #expect(h.layout?.windowFrames[notes] != nil)
    h.system.echoes.keyboard = false
    let again = relaunch(safari, in: h)
    #expect(h.workspace.tree.leaf(containing: again) == h.workspace.tree.leaf(containing: notes))
    #expect(h.layout?.windowFrames[notes] != nil)
    expectWindowsMatchLayout(h)
  }

  @Test func eachWindowHasItsOwnTime() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    // ⌘W in Safari, four seconds later ⌘W in Mail, and three seconds after that Safari quits: it was closed, not quit.
    h.system.close(safari.id)
    h.scheduler.advance(by: 4)
    h.system.close(WindowID(103))
    h.scheduler.advance(by: 3)
    h.system.quit(pid: Self.safariPID)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
  }

  @Test func anotherAppThatQuitsLaterGivesTheFirstNoMoreTime() {
    let (h, safari, notes) = pair()
    h.run("dock 103 beside \(notes.rawValue) bottom")
    end(Self.safariPID, .windowsFirst, in: h)
    h.scheduler.advance(by: Controller.pendingSlotLifetime - 10)
    end(2003, .windowsFirst, in: h)
    h.scheduler.advance(by: 20)
    let again = relaunch(safari, in: h)
    #expect(h.workspace.isFloating(again))
  }

  /// What is remembered of a window lies in the coordinates of the displays as they were.
  @Test func displaysThatMoveGiveThePlacesUp() {
    let second = DisplaySnapshot(
      id: DisplayID("second"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    let (h, safari, _) = pair()
    end(Self.safariPID, .windowsFirst, in: h)
    var moved = FakeWindowSystem.standardDisplay
    moved.frame.origin.x += 1920
    moved.visibleFrame.origin.x += 1920
    var left = second
    left.frame.origin.x = 0
    left.visibleFrame.origin.x = 0
    h.system.setDisplays([moved, left])
    h.scheduler.advance(by: 2)
    let again = h.system.open(
      app: safari.appName, bundleID: safari.bundleID, title: safari.title, pid: 3001,
      frame: CGRect(x: 2200, y: 150, width: 500, height: 300))
    #expect(!h.controller.workspaces.values.contains { $0.isDocked(again) })
    #expect(!h.scheduler.pendingKeys.contains("closed-places"))
  }
}
