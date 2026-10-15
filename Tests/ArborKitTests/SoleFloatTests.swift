import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// F18 (T21): with `soleFloatTakesDesktop` on, a window that floats alone takes the whole Desktop, and is its old
/// self again as soon as it has company.
///
/// Taking the Desktop is placing and sizing a floating window, so since Q20 F18 needs `floatingWindowsMakeWay` too. That is on
/// in the whole suite, also where `soleFloatTakesDesktop` is off. That F18 does nothing without it is in `FloatingFrameTests`.
@Suite @MainActor struct SoleFloatTests {
  /// The frame `f`'s user gave it.
  let own = CGRect(x: 900, y: 300, width: 320, height: 300)

  /// With a column for the Desktop: these tests are about a Desktop that has room, also beside two docked windows and after `arrange`.
  static func settings(on: Bool = true) -> Settings {
    var settings = Settings.makingWay.withDesktopColumn
    settings.soleFloatTakesDesktop = on
    return settings
  }

  /// `[a | Desktop]` with `f` floating on the Desktop.
  func makeHarness(on: Bool = true, displays: [DisplaySnapshot] = [main]) -> (Harness, a: WindowID, f: WindowID) {
    let h = Harness(displays: displays, settings: Self.settings(on: on))
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Notes", frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    return (h, a, f)
  }

  func desktop(_ h: Harness) -> CGRect { h.layout!.desktopFrame! }

  // MARK: Filling

  @Test func offByDefaultAndThenNothingIsStretched() {
    #expect(!Settings().soleFloatTakesDesktop)
    let (h, a, f) = makeHarness(on: false)
    #expect(h.frame(f) == own)
    h.run("resize \(a.rawValue) right 100")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == own)
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 400, width: 300, height: 200))
    h.system.close(g)
    #expect(h.frame(f) == own)
  }

  @Test func theOnlyFloatingWindowTakesTheDesktop() {
    let (h, _, f) = makeHarness()
    #expect(h.frame(f) == desktop(h), "\(h.ascii())")
    #expect(h.workspace.isFloating(f), "it looks docked and is not")
    #expect(h.workspace.floating[f] == own, "the frame its user gave it is still the one remembered")
  }

  @Test func itFollowsTheDesktop() {
    let (h, a, f) = makeHarness()
    let before = desktop(h)
    h.run("resize \(a.rawValue) right 100")
    #expect(desktop(h).width == before.width - 100)
    #expect(h.frame(f) == desktop(h), "a gap moved")
    let b = h.system.open(app: "Mail", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    h.run("dock \(b.rawValue) right")
    #expect(h.frame(f) == desktop(h), "a window was docked beside it\n\(h.ascii())")
    h.system.close(b)
    #expect(h.frame(f) == desktop(h), "and closed")
  }

  @Test func itGoesOutOfViewAndComesBackWithTheDesktop() {
    let (h, a, f) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(f))
    h.run("back")
    #expect(h.frame(f) == desktop(h))
    h.run("zoom-node \(h.workspace.tree.desktop.rawValue)")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.frame(f) == desktop(h), "the Desktop framed: it fills the view")
    #expect(h.frame(f)!.width > 1300)
  }

  @Test func itStaysInViewWhenTheDesktopIsSqueezedIntoATile() {
    let (h, a, f) = makeHarness()
    let filled = h.frame(f)!
    h.run("resize \(a.rawValue) right 600")
    #expect(h.layout!.desktopFrame == nil)
    #expect(h.frame(f) == filled, "a change of the arrangement takes no floating window out of view, nor shrinks it")
    h.run("resize \(a.rawValue) right -600")
    #expect(h.frame(f) == desktop(h))
  }

  @Test func aWindowFloatedOutOfTheArrangementTakesTheDesktop() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("float \(b.rawValue)")
    #expect(h.frame(b) == desktop(h), "\(h.ascii())")
  }

  @Test func aNewWindowThatIsTheOnlyFloatingOneTakesTheDesktopWhereverItOpened() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    // Over Safari, where its app happened to put it.
    let opened = CGRect(x: 60, y: 80, width: 400, height: 300)
    let f = h.system.open(app: "Notes", frame: opened)
    #expect(h.frame(f) == desktop(h))
    #expect(h.workspace.floating[f] == opened)
  }

  @Test func aNewWindowOpenedWhileTheDesktopIsOutOfViewStaysWhereItOpened() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    let opened = CGRect(x: 60, y: 80, width: 400, height: 300)
    let f = h.system.open(app: "Notes", frame: opened)
    #expect(h.frame(f) == opened)
  }

  @Test func aLayoutThatChangesNothingAsksNothingOfIt() {
    let (h, _, f) = makeHarness()
    h.system.clearFrameLog()
    h.controller.apply(settings: h.controller.settings)
    h.scheduler.runPending()
    #expect(!h.system.frameLog.contains { $0.window == f })
  }

  @Test func theMotionShowsItGoingWhereItGoes() {
    // F02 plans a transition before anything moves, so the plan has to know who takes the Desktop.
    let (h, a, f) = makeHarness()
    h.switchOn(\.withMotion)
    let company = h.system.open(app: "Preview", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    #expect(h.frame(f) == own)
    h.overlays.clearTransitions()
    h.system.close(company)
    #expect(h.overlays.transitions.last?[f]?.from == own)
    #expect(h.overlays.transitions.last?[f]?.to == desktop(h))
    h.overlays.clearTransitions()
    h.run("resize \(a.rawValue) right 100")
    #expect(h.overlays.transitions.last?[f]?.to == desktop(h))
    h.overlays.clearTransitions()
    _ = h.system.open(app: "Mail", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    #expect(h.overlays.transitions.last?[f]?.to == own)
    #expect(h.frame(f) == own)
  }

  // MARK: Its own frame comes back

  @Test func aSecondFloatingWindowGivesItItsOwnFrameBack() {
    let (h, _, f) = makeHarness()
    let opened = CGRect(x: 900, y: 400, width: 300, height: 200)
    let g = h.system.open(app: "Mail", frame: opened)
    #expect(h.frame(f) == own)
    #expect(h.frame(g) == opened, "the newcomer is not moved")
    h.system.close(g)
    #expect(h.frame(f) == desktop(h), "alone again")
  }

  @Test func windowsThatTakeNoRoomAreNoCompany() {
    let (h, _, f) = makeHarness()
    let g = h.system.open(app: "Mail", pid: 2000, frame: CGRect(x: 900, y: 400, width: 300, height: 200))
    #expect(h.frame(f) == own)
    h.system.setMinimized(g, true)
    #expect(h.frame(f) == desktop(h), "minimized")
    h.system.setMinimized(g, false)
    #expect(h.frame(f) == own)
    h.system.setHidden(pid: 2000, true)
    h.scheduler.runPending()
    #expect(h.frame(f) == desktop(h), "hidden with its app")
    h.system.setHidden(pid: 2000, false)
    h.scheduler.runPending()
    #expect(h.frame(f) == own)
    h.system.setOnActiveSpace(g, false)
    h.scheduler.runPending()
    #expect(h.frame(f) == desktop(h), "on another macOS Space")
    h.system.setOnActiveSpace(g, true)
    h.scheduler.runPending()
    #expect(h.frame(f) == own)
    h.system.setFullScreen(g, true)
    h.scheduler.runPending()
    #expect(h.frame(f) == desktop(h), "in macOS's full screen")
  }

  @Test func windowsArborDoesNotArrangeAreNoCompany() {
    let (h, _, f) = makeHarness()
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 400, width: 300, height: 200))
    #expect(h.frame(f) == own)
    h.run("exclude \(h.system.windows[g]!.snapshot.bundleID!)")
    #expect(h.frame(f) == desktop(h))
  }

  @Test func turningTheSettingOffAndOn() {
    let (h, _, f) = makeHarness()
    h.controller.apply(settings: Self.settings(on: false))
    #expect(h.frame(f) == own)
    h.controller.apply(settings: Self.settings())
    #expect(h.frame(f) == desktop(h))
  }

  @Test func floatAllMeansANormalMac() {
    let (h, a, f) = makeHarness()
    h.run("float-all")
    #expect(h.frame(f) == own)
    h.system.close(a)
    #expect(h.frame(f) == own, "alone, but nothing is docked: Arbor has arranged nothing")
  }

  @Test func withNothingDockedNothingIsStretched() {
    let h = Harness(settings: Self.settings())
    let f = h.system.open(app: "Notes", frame: own)
    h.start()
    h.controller.apply(settings: h.controller.settings)
    #expect(h.frame(f) == own)
    let g = h.system.open(app: "Mail")
    h.system.close(g)
    #expect(h.frame(f) == own)
  }

  @Test func onAMacOSSpaceWhereNothingDockedShowsNothingIsStretched() {
    let (h, a, f) = makeHarness()
    h.system.setOnActiveSpace(a, false)
    h.scheduler.runPending()
    #expect(h.frame(f) == own)
    h.system.setOnActiveSpace(a, true)
    h.scheduler.runPending()
    #expect(h.frame(f) == desktop(h))
  }

  @Test func closingTheLastDockedWindowGivesItItsOwnFrameBack() {
    let (h, a, f) = makeHarness()
    h.system.close(a)
    #expect(h.frame(f) == own)
  }

  @Test func quittingGivesItItsOwnFrameBack() {
    let (h, _, f) = makeHarness()
    h.controller.shutdown()
    #expect(h.frame(f) == own)
    #expect(h.store.saved?.workspaces[h.display]?.floating[f] == own)
  }

  @Test func quittingWhileItIsOutOfViewGivesItItsOwnFrameBack() {
    let (h, a, f) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.controller.shutdown()
    #expect(h.frame(f) == own)
  }

  @Test func aPauseGivesItItsOwnFrameBackAndAResumeTheDesktop() {
    let (h, a, f) = makeHarness()
    let filled = desktop(h)
    h.system.clearFrameLog()
    h.run("pause")
    #expect(h.frame(f) == own)
    h.run("resume")
    #expect(h.system.frameLog.filter { $0.window == f }.count == 2, "one move each way")
    #expect(h.frame(f) == filled)
    h.run("resize \(a.rawValue) right 50")
    #expect(h.frame(f) == desktop(h), "and it goes on following the Desktop")
    #expect(h.workspace.floating[f] == own)
  }

  @Test func draggedRightAfterAPauseItIsStillItsOwnSizeAgain() {
    // Found by SoleFloatFuzzTests: resuming forgets what Arbor placed where, and the Desktop's size became the window's own.
    let (h, _, f) = makeHarness()
    h.run("pause")
    h.run("resume")
    let filled = h.frame(f)!
    #expect(filled == desktop(h))
    h.system.drag(f, through: [CGPoint(x: filled.midX, y: filled.minY + 10), CGPoint(x: filled.midX - 40, y: filled.minY + 90)])
    #expect(h.frame(f)!.size == own.size)
    #expect(h.workspace.floating[f]!.size == own.size)
  }

  @Test func pinnedRightAfterAPauseItIsItsOwnSize() {
    let (h, _, f) = makeHarness()
    h.run("pause")
    h.run("resume")
    h.run("pin \(f.rawValue)")
    #expect(h.frame(f) == own)
  }

  @Test func quittingDuringAPauseGivesItItsOwnFrameBack() {
    let (h, _, f) = makeHarness()
    h.run("pause")
    h.controller.shutdown()
    #expect(h.frame(f) == own)
  }

  @Test func quittingWhileItIsMinimizedGivesItItsOwnFrameBack() {
    let (h, _, f) = makeHarness()
    h.system.setMinimized(f, true)
    h.controller.shutdown()
    #expect(h.frame(f) == own, "or it would come out of the Dock in the shape of the Desktop")
  }

  @Test func excludingItsAppGivesItItsOwnFrameBack() {
    let (h, _, f) = makeHarness()
    h.run("exclude \(h.system.windows[f]!.snapshot.bundleID!)")
    #expect(h.frame(f) == own)
  }

  @Test func dockedItRemembersItsOwnFrameNotTheDesktops() {
    let (h, _, f) = makeHarness()
    #expect(h.frame(f) == desktop(h))
    h.run("dock \(f.rawValue) right")
    _ = h.system.open(app: "Mail", frame: CGRect(x: 800, y: 600, width: 200, height: 150))
    h.run("float \(f.rawValue)")
    #expect(h.frame(f)!.size == own.size, "with company it floats at the size its user gave it (F48)")
  }

  @Test func floatedAloneItGoesStraightToTheDesktopsSize() {
    let (h, _, f) = makeHarness()
    h.run("dock \(f.rawValue) right")
    h.system.clearFrameLog()
    h.run("float \(f.rawValue)")
    #expect(h.frame(f) == desktop(h))
    #expect(h.system.frameLog.filter { $0.window == f }.count == 1, "not by way of its own size")
    #expect(h.workspace.floating[f]!.size == own.size)
  }

  /// Quit with `[a | Desktop]` and `f` alone on it, and start again with the same windows.
  func relaunched() -> (Harness, a: WindowID, f: WindowID) {
    let (first, a, f) = makeHarness()
    first.controller.shutdown()
    let h = Harness(settings: Self.settings(), saved: first.store.saved)
    #expect(h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400)) == a)
    #expect(h.system.open(app: "Notes", frame: own) == f)
    h.start()
    #expect(h.workspace.isDocked(a))
    return (h, a, f)
  }

  @Test func atLaunchItTakesTheDesktopOnceTheWindowsHaveTurnedUp() {
    let (h, _, f) = relaunched()
    #expect(h.frame(f) == own, "not at once: windows may still be turning up")
    h.scheduler.advance(by: 1.9)
    #expect(h.frame(f) == own)
    h.scheduler.advance(by: 0.2)
    #expect(h.frame(f) == desktop(h), "and not only when some unrelated command comes along")
  }

  @Test func aWindowThatTurnsUpLateAtLaunchSparesItTheTrip() {
    let (h, _, f) = relaunched()
    h.system.clearFrameLog()
    h.scheduler.advance(by: 1.5)
    _ = h.system.open(app: "Mail", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    h.scheduler.advance(by: 5)
    #expect(!h.system.frameLog.contains { $0.window == f }, "it never grew, so it never had to shrink")
  }

  @Test func eachLateWindowAtLaunchStartsTheWaitAfresh() {
    let (h, _, f) = relaunched()
    h.scheduler.advance(by: 1.5)
    let late = h.system.open(app: "Mail", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    h.scheduler.advance(by: 1)
    h.system.setMinimized(late, true)
    // Alone now by an ordinary change, which fills at once as always.
    #expect(h.frame(f) == desktop(h))
  }

  @Test func aPauseRightAfterLaunchSilencesTheWait() {
    let (h, _, f) = relaunched()
    h.run("pause")
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("sole-float") })
    h.system.clearFrameLog()
    h.scheduler.advance(by: 5)
    #expect(!h.system.frameLog.contains { $0.window == f })
  }

  @Test func atLaunchOtherFloatingWindowsStayAsTheyWereFound() {
    let (first, a, f) = makeHarness()
    let place = CGRect(x: 300, y: 500, width: 500, height: 300)  // half over Safari
    let g = first.system.open(app: "Mail", frame: place)
    first.controller.shutdown()
    let h = Harness(settings: Self.settings(), saved: first.store.saved)
    #expect(h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400)) == a)
    #expect(h.system.open(app: "Notes", frame: own) == f)
    #expect(h.system.open(app: "Mail", frame: place) == g)
    h.start()
    h.system.clearFrameLog()
    h.scheduler.advance(by: 5)
    #expect(!h.system.frameLog.contains { $0.window == f || $0.window == g })
  }

  // MARK: The user's hand

  @Test func aResizeByTheUserSticksUntilTheWindowHasHadCompany() {
    let (h, a, f) = makeHarness()
    var chosen = desktop(h)
    chosen.size.height = 400
    h.system.userResize(f, to: chosen)
    #expect(h.workspace.floating[f] == chosen)
    h.run("resize \(a.rawValue) right -50")
    #expect(h.frame(f) == chosen, "later layouts leave it")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == chosen, "and so does the Desktop going and coming")
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    h.system.close(g)
    #expect(h.frame(f) == desktop(h), "it has had company: a new beginning")
  }

  @Test func aMoveByAnotherToolCountsAsTheUsers() {
    let (h, a, f) = makeHarness()
    let chosen = CGRect(x: 850, y: 200, width: 400, height: 350)
    h.system.userMove(f, to: chosen)
    h.run("resize \(a.rawValue) right -50")
    #expect(h.frame(f) == chosen)
  }

  @Test func beingAwayItselfIsNotCompany() {
    let (h, _, f) = makeHarness()
    let chosen = CGRect(x: 850, y: 200, width: 400, height: 350)
    h.system.userMove(f, to: chosen)
    h.system.setMinimized(f, true)
    h.system.setMinimized(f, false)
    #expect(h.frame(f) == chosen)
    h.system.setOnActiveSpace(f, false)
    h.scheduler.runPending()
    h.system.setOnActiveSpace(f, true)
    h.scheduler.runPending()
    #expect(h.frame(f) == chosen)
  }

  @Test func anotherTabOfItsNativeTabGroupIsTheSameWindow() throws {
    let (h, a, f) = makeHarness()
    let tab = try #require(h.system.openTab(in: f))
    #expect(h.frame(tab) == desktop(h), "it goes on filling")
    #expect(h.workspace.floating[tab] == own)
    let chosen = CGRect(x: 850, y: 200, width: 400, height: 350)
    h.system.userMove(tab, to: chosen)
    h.system.selectTab(f, insteadOf: tab)
    h.run("resize \(a.rawValue) right -50")
    #expect(h.frame(f) == chosen, "and what its user chose for one tab holds for the other")
  }

  @Test func dockingItAndFloatingItAgainIsANewBeginning() {
    let (h, _, f) = makeHarness()
    h.system.userMove(f, to: CGRect(x: 850, y: 200, width: 400, height: 350))
    h.run("dock \(f.rawValue) right")
    h.run("float \(f.rawValue)")
    #expect(h.frame(f) == desktop(h))
  }

  @Test func floatSaysTakeTheDesktopAgain() {
    let (h, a, f) = makeHarness()
    let chosen = CGRect(x: 850, y: 200, width: 400, height: 350)
    h.system.userMove(f, to: chosen)
    let result = h.run("float \(f.rawValue)")
    #expect(result.ok, "\(result.message)")
    #expect(result.message.contains("takes the Desktop"))
    #expect(h.frame(f) == desktop(h))
    #expect(h.workspace.floating[f] == chosen, "what its user chose is its own frame still")
    h.run("resize \(a.rawValue) right 50")
    #expect(h.frame(f) == desktop(h))
    // Where there is nothing to say, the old answer.
    #expect(!h.run("float \(f.rawValue)").ok)
    _ = h.system.open(app: "Mail", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    #expect(!h.run("float \(f.rawValue)").ok, "with company it is simply floating")
  }

  @Test func floatOnAFloatingWindowIsRefusedAsEverWithoutTheSetting() {
    let (h, _, f) = makeHarness(on: false)
    h.system.userMove(f, to: CGRect(x: 850, y: 200, width: 400, height: 350))
    #expect(h.run("float \(f.rawValue)").message.contains("already floating"))
  }

  @Test func aTerminalSnappingToWholeCellsLateIsNotTheUser() {
    let (h, a, f) = makeHarness()
    // Eleven points narrower and fourteen shorter, in the same corner, nobody's finger on the button.
    var snapped = desktop(h)
    snapped.size.width -= 11
    snapped.size.height -= 14
    h.system.userMove(f, to: snapped)
    #expect(h.workspace.floating[f] == own, "its own frame is not replaced by the Desktop's")
    h.system.clearFrameLog()
    h.controller.apply(settings: h.controller.settings)
    #expect(!h.system.frameLog.contains { $0.window == f }, "and it is not asked again for what it has just declined")
    h.run("resize \(a.rawValue) right 100")
    #expect(h.frame(f) == desktop(h), "a new Desktop is a new question")
    _ = h.system.open(app: "Mail", frame: CGRect(x: 1000, y: 650, width: 300, height: 200))
    #expect(h.frame(f) == own)
  }

  @Test func theSameChangeWithTheButtonDownIsTheUser() {
    let (h, _, f) = makeHarness()
    var pulled = desktop(h)
    pulled.size.height -= 14
    h.system.userResize(f, to: pulled)
    #expect(h.workspace.floating[f] == pulled)
  }

  @Test func growingOrMovingByThatMuchIsTheUser() {
    for change in [CGRect(x: 0, y: 0, width: 14, height: 0), CGRect(x: 14, y: 0, width: 0, height: 0), CGRect(x: 0, y: 0, width: -50, height: 0)] {
      let (h, _, f) = makeHarness()
      let filled = desktop(h)
      let moved = CGRect(
        x: filled.minX + change.minX, y: filled.minY + change.minY, width: filled.width + change.width,
        height: filled.height + change.height)
      h.system.userMove(f, to: moved)
      #expect(h.workspace.floating[f] == moved, "\(change)")
    }
  }

  @Test func anAppRoundingItsSizeAMomentLaterIsNotTheUser() {
    let (h, a, f) = makeHarness()
    // A terminal snapping to whole characters, reported too late to be taken for an echo of Arbor's own move.
    var rounded = desktop(h)
    rounded.size.width -= 4
    rounded.size.height -= 4
    h.system.userMove(f, to: rounded)
    #expect(h.workspace.floating[f] == own, "its own frame is not replaced by the Desktop's")
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(h.frame(f) == own)
    _ = (a, g)
  }

  @Test func draggedOffTheDesktopItFilledItIsItsOwnSizeAgainUnderThePointer() {
    let (h, a, f) = makeHarness()
    let filled = desktop(h)
    // Grabbed in the middle of its title bar, let go a little further down and to the left, still on the Desktop.
    let drop = CGPoint(x: filled.midX - 40, y: filled.minY + 90)
    h.system.drag(f, through: [CGPoint(x: filled.midX, y: filled.minY + 10), drop])
    let frame = h.frame(f)!
    #expect(frame.size == own.size)
    #expect(frame.midX == drop.x, "the pointer is as far along the title bar as it was")
    #expect(frame.minY == drop.y - 10)
    #expect(h.workspace.floating[f] == frame, "and that is its own frame now")
    h.run("resize \(a.rawValue) right -50")
    #expect(h.frame(f) == frame, "where it was dropped, it stays")
  }

  @Test func aWindowThatOpensOverADesktopThatIsATileChangesNothing() {
    // Bug bash 1. Finder cannot be narrower than 1044, so on a display 1280 wide the empty Desktop has given it its room.
    let laptop = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 0, y: 25, width: 1280, height: 775), isMain: true)
    let h = Harness(displays: [laptop], settings: Self.settings(on: true))
    let finder = h.system.open(
      app: "Finder", frame: CGRect(x: 100, y: 40, width: 1044, height: 729), minimumSize: CGSize(width: 1044, height: 729))
    h.start()
    h.run("dock \(finder.rawValue) right")
    #expect(h.layout!.desktopFrame == nil && h.layout!.windowFrames[finder] != nil, "\(h.ascii())")
    let place = CGRect(x: 300, y: 200, width: 180, height: 150)
    let terminal = h.system.open(app: "Terminal", frame: place)
    #expect(h.layout!.windowFrames[finder] != nil, "the only docked window stays in view\n\(h.ascii())")
    #expect(h.frame(terminal) == place, "and the new one floats over the arrangement, as with the setting off")
  }

  @Test func ifItsAppRefusesItsOwnSizeItIsStillUnderThePointer() {
    // Found by the chaos lab: its app has closed a sidebar since, and the window cannot be as wide as it was.
    let (h, a, f) = makeHarness()
    h.system.setMaximumSize(f, CGSize(width: 200, height: 2000))
    h.run("resize \(a.rawValue) right 50")
    let sits = h.frame(f)!
    #expect(sits.width == 200)
    let drop = CGPoint(x: sits.midX - 30, y: sits.minY + 90)
    h.system.drag(f, through: [CGPoint(x: sits.midX, y: sits.minY + 10), drop])
    let frame = h.frame(f)!
    #expect(frame.width == 200)
    #expect(frame.midX == drop.x, "\(frame): the pointer is as far along the title bar as it was")
    #expect(h.workspace.floating[f] == frame)
  }

  @Test func afterADragWhoseEndNobodySawItIsItsOwnSizeWhereItWasLeft() {
    let (h, _, f) = makeHarness()
    let filled = desktop(h)
    h.system.dragAndLoseTheRelease(f, to: CGPoint(x: filled.midX + 20, y: filled.minY + 60))
    let left = h.frame(f)!
    // By the time anybody notices, the pointer is in the menu bar at the other end of the screen.
    h.system.cursor = CGPoint(x: 5, y: 5)
    h.controller.dragCancelled(f)
    #expect(h.frame(f)!.size == own.size)
    #expect(left.contains(h.frame(f)!), "\(h.frame(f)!) is not where it was left, \(left)")
    #expect(h.frame(f)!.minY == left.minY)
  }

  @Test func draggedToADropTargetItDocks() {
    let (h, _, f) = makeHarness()
    let filled = desktop(h)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(f, through: [CGPoint(x: filled.midX, y: filled.minY + 10), CGPoint(x: 1438, y: 400)])
    #expect(h.workspace.isDocked(f), "\(h.ascii())")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aDockedWindowDroppedOnTheEmptyDesktopStaysWhereItWasDropped() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let slot = h.frame(b)!
    let drop = CGPoint(x: desktop(h).midX, y: 300)
    h.system.drag(b, through: [CGPoint(x: slot.midX, y: slot.minY + 10), drop])
    #expect(h.workspace.isFloating(b))
    let dropped = h.frame(b)!
    #expect(dropped != desktop(h), "what has just left the user's hand is not snatched away")
    h.run("resize \(a.rawValue) right 20")
    #expect(h.frame(b)!.size == dropped.fitted(into: desktop(h)).size)
    #expect(h.frame(b) != desktop(h))
  }

  @Test func aWindowDraggedWhileItHadCompanyFillsOnceItIsAlone() {
    let (h, _, f) = makeHarness()
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    h.system.drag(f, through: [CGPoint(x: own.midX, y: own.minY + 10), CGPoint(x: own.midX + 30, y: own.minY + 40)])
    #expect(h.frame(f)!.size == own.size)
    h.system.close(g)
    #expect(h.frame(f) == desktop(h))
  }

  @Test func draggingAnotherWindowDoesNotUndoTheUsersChoice() {
    let (h, a, f) = makeHarness()
    let chosen = CGRect(x: 850, y: 200, width: 400, height: 350)
    h.system.userMove(f, to: chosen)
    // Safari is picked up and put back at the left edge.
    let slot = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 400, y: 300), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isDocked(a))
    #expect(h.frame(f) == chosen, "\(h.ascii())")
  }

  @Test func aLayoutDuringTheDragLeavesTheDraggedWindowAlone() {
    let (h, a, f) = makeHarness()
    let filled = desktop(h)
    h.controller.dragBegan(f, at: CGPoint(x: filled.midX, y: filled.minY + 10))
    h.system.clearFrameLog()
    h.run("resize \(a.rawValue) right 40")
    #expect(!h.system.frameLog.contains { $0.window == f })
    h.controller.dragEnded(f, at: CGPoint(x: filled.midX, y: filled.minY + 10))
  }

  // MARK: Windows that refuse

  @Test func aWindowThatCannotGrowThatFarSitsInTheMiddleAndIsAskedOnce() {
    let (h, a, f) = makeHarness(on: false)
    h.system.setMaximumSize(f, CGSize(width: 400, height: 500))
    h.controller.apply(settings: Self.settings())
    let frame = h.frame(f)!
    #expect(frame.size == CGSize(width: 400, height: 500))
    #expect(abs(frame.midX - desktop(h).midX) <= 0.5 && abs(frame.midY - desktop(h).midY) <= 0.5)
    h.system.clearFrameLog()
    h.controller.apply(settings: h.controller.settings)
    #expect(!h.system.frameLog.contains { $0.window == f }, "not again while the Desktop stays as it is")
    h.run("resize \(a.rawValue) right 100")
    #expect(abs(h.frame(f)!.midX - desktop(h).midX) <= 0.5, "it stays in the middle as the Desktop changes")
    let g = h.system.open(app: "Mail", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(h.frame(f) == own)
    _ = g
  }

  @Test func aWindowThatOnlyGrowsSidewaysSitsHalfwayDown() {
    let (h, _, f) = makeHarness(on: false)
    h.system.setMaximumSize(f, CGSize(width: 5000, height: 400))
    h.controller.apply(settings: Self.settings())
    let frame = h.frame(f)!
    #expect(frame.width == desktop(h).width && frame.minX == desktop(h).minX)
    #expect(frame.height == 400)
    #expect(abs(frame.midY - desktop(h).midY) <= 0.5)
    // The Desktop framed is wider than it is tall.
    h.run("desktop")
    #expect(h.frame(f)!.width == desktop(h).width && h.frame(f)!.minX == desktop(h).minX)
    #expect(abs(h.frame(f)!.midY - desktop(h).midY) <= 0.5)
  }

  @Test func aWindowThatIsOnlyTooTallHangsOverTheTopOfTheDesktop() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let f = h.system.open(app: "Xcode", frame: own, minimumSize: CGSize(width: 100, height: 600))
    h.start()
    // The Desktop is the lower right quarter.
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) top")
    h.run("dock \(a.rawValue) left")
    let frame = h.frame(f)!
    #expect(desktop(h).height < 600, "\(h.ascii())")
    #expect(frame.height == 600)
    #expect(frame.width == desktop(h).width && frame.minX == desktop(h).minX)
    #expect(frame.maxY == desktop(h).maxY)
    #expect(h.visibleFrame.contains(frame))
    // Nothing was learned about its width, so it goes on following the Desktop sideways.
    h.run("resize \(a.rawValue) right 100")
    #expect(h.frame(f)!.width == desktop(h).width && h.frame(f)!.minX == desktop(h).minX, "\(h.ascii())")
  }

  @Test func aWindowThatCannotShrinkThatFarStaysOnTheDisplay() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    let big = CGRect(x: 200, y: 200, width: 1000, height: 500)
    let f = h.system.open(app: "Xcode", frame: big, minimumSize: CGSize(width: 900, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    let frame = h.frame(f)!
    #expect(frame.width == 900)
    #expect(frame.height == desktop(h).height, "it fills what it can")
    #expect(frame.maxX == desktop(h).maxX, "and covers as little docked space as it can")
    #expect(h.visibleFrame.contains(frame))
    h.system.clearFrameLog()
    h.controller.apply(settings: h.controller.settings)
    #expect(!h.system.frameLog.contains { $0.window == f })
    h.run("float-all")
    #expect(h.frame(f) == big)
  }

  @Test func aWindowOutOfViewWhoseAppDoesNotAnswerComesBackWhenItDoes() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    let f = h.system.open(app: "Notes", pid: 2000, frame: own)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.system.setUnresponsive(pid: 2000, true)
    h.run("back")
    #expect(h.controller.parked.contains(f), "it could not be moved, so it still counts as out of view")
    h.system.setUnresponsive(pid: 2000, false)
    h.scheduler.advance(by: 0.5)
    #expect(h.frame(f) == desktop(h))
    #expect(h.workspace.floating[f] == own)
  }

  // MARK: Pinned windows (F49)

  @Test func aPinnedWindowIsNoCompany() {
    let (h, _, f) = makeHarness()
    let place = CGRect(x: 1000, y: 500, width: 300, height: 200)
    let call = h.system.open(app: "Zoom", frame: place)
    #expect(h.frame(f) == own)
    h.run("pin \(call.rawValue)")
    #expect(h.frame(f) == desktop(h), "it does not live on the Desktop")
    #expect(h.frame(call) == place)
    h.run("unpin \(call.rawValue)")
    #expect(h.frame(f) == own, "now it does again")
    #expect(h.frame(call) == place)
  }

  @Test func aPinnedWindowDoesNotTakeTheDesktop() {
    let (h, a, f) = makeHarness()
    #expect(h.frame(f) == desktop(h))
    h.run("pin \(f.rawValue)")
    #expect(h.frame(f) == own, "pinned, it is its own size, not the size Arbor happened to give it")
    #expect(h.workspace.floating[f] == own)
    h.run("resize \(a.rawValue) right 50")
    h.run("zoom \(a.rawValue)")
    h.run("back")
    #expect(h.frame(f) == own)
    h.run("unpin \(f.rawValue)")
    #expect(h.frame(f) == desktop(h), "back on the Desktop, and alone there")
  }

  // MARK: Guests (F57)

  @Test func aGuestTakesTheDesktopWhileThatIsInViewAndIsItselfAgainOverItsHost() {
    let h = Harness(settings: Self.settings())
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    let opened = CGRect(x: 200, y: 150, width: 400, height: 300)
    let g = h.system.open(app: "Notes", frame: opened)
    #expect(h.workspace.guests?[g] != nil)
    #expect(h.frame(g) == opened)
    h.run("back")
    #expect(h.frame(g) == desktop(h), "on the Desktop it is a floating window like any other\n\(h.ascii())")
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(g) == opened)
  }

  // MARK: Displays

  /// Main: `[a | Desktop]` with `f`. Side: `[Desktop | b]` with `g`.
  func makeTwoDisplays() -> (Harness, f: WindowID, g: WindowID) {
    let (h, _, f) = makeHarness(displays: [main, side])
    let b = h.system.open(app: "Mail", frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(b.rawValue) right")
    let g = h.system.open(app: "Calculator", frame: CGRect(x: 1500, y: 300, width: 320, height: 300))
    return (h, f, g)
  }

  @Test func eachDisplayCountsForItself() {
    let (h, f, g) = makeTwoDisplays()
    #expect(h.frame(f) == h.controller.layouts[main.id]!.desktopFrame!)
    #expect(h.frame(g) == h.controller.layouts[side.id]!.desktopFrame!)
  }

  @Test func aWindowDroppedOnAnotherDisplaysDesktopIsCompanyThereAndMissedHere() {
    let (h, f, g) = makeTwoDisplays()
    let e = h.system.open(app: "Preview", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(h.frame(f) == own)
    h.system.drag(e, through: [CGPoint(x: 1050, y: 510), CGPoint(x: 1700, y: 400)])
    #expect(h.controller.workspaces[side.id]!.isFloating(e))
    #expect(h.frame(f) == h.controller.layouts[main.id]!.desktopFrame!, "alone again")
    #expect(h.frame(g) == CGRect(x: 1500, y: 300, width: 320, height: 300), "not alone any more")
  }

  @Test func aWindowMovedToAnotherDisplayByAnotherToolIsCompanyThereAndMissedHere() {
    let (h, f, g) = makeTwoDisplays()
    let e = h.system.open(app: "Preview", frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(h.frame(f) == own)
    h.system.userMove(e, to: CGRect(x: 1600, y: 400, width: 300, height: 200))
    #expect(h.controller.workspaces[side.id]!.isFloating(e))
    #expect(h.frame(f) == h.controller.layouts[main.id]!.desktopFrame!, "alone again")
    #expect(h.frame(g) == CGRect(x: 1500, y: 300, width: 320, height: 300), "not alone any more")
  }

  @Test func draggedToASmallerDisplayItsOwnSizeIsCutToWhatFitsThere() {
    let h = Harness(displays: [main, side], settings: Self.settings())
    let a = h.system.open(app: "Safari")
    // Taller than the side display is.
    let f = h.system.open(app: "Notes", frame: CGRect(x: 800, y: 30, width: 500, height: 860))
    h.start()
    h.run("dock \(a.rawValue) left")
    let filled = h.frame(f)!
    #expect(filled == desktop(h))
    h.system.drag(f, through: [CGPoint(x: filled.midX, y: filled.minY + 10), CGPoint(x: 2000, y: 20)])
    #expect(h.controller.workspaces[side.id]!.isFloating(f))
    #expect(h.frame(f)!.size == CGSize(width: 500, height: 800))
  }

  @Test func anUnpluggedDisplaysWindowArrivesAtItsOwnSize() {
    let (h, f, g) = makeTwoDisplays()
    h.system.setDisplays([main])
    #expect(h.frame(g)!.size == CGSize(width: 320, height: 300))
    #expect(h.frame(f) == own, "and is company")
  }

  // MARK: Files

  @Test func settingsFilesWithoutTheKeyLoadAndTheKeyIsWrittenAndRead() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 10}"#.utf8))
    #expect(!old.soleFloatTakesDesktop)
    let saved = try JSONEncoder().encode(Self.settings())
    #expect(try JSONDecoder().decode(Settings.self, from: saved).soleFloatTakesDesktop)
  }
}
