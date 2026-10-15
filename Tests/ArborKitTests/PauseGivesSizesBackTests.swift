import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// "Quitting, Float All and pause give windows back their own earlier sizes, not just a visible position."
///
/// The desk is the one a day with real apps on a hosted Mac had reached when it pressed ⌃⌥⎋: a display of 1600 × 900,
/// two docked windows with the Desktop between them, and seven floating windows, four of them squeezed to stay on it.
@Suite @MainActor struct PauseGivesSizesBackTests {
  static let display = DisplaySnapshot(
    id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1600, height: 900),
    visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791), isMain: true)

  @MainActor struct Desk {
    let h: Harness
    let finder, safari, terminal, notes, mail, textEdit, calendar, settings, preview: WindowID
    /// Where each window was, and how large, before Arbor touched it.
    let own: [WindowID: CGRect]
    var all: [WindowID] { own.keys.sorted() }
    /// The windows Arbor has moved or resized.
    var touched: [WindowID] { all.filter { h.frame($0) != own[$0] } }
    func frames() -> [WindowID: CGRect] { Dictionary(uniqueKeysWithValues: all.map { ($0, h.frame($0)!) }) }
    /// How often each window has been moved since the log was cleared.
    func moves() -> [WindowID: Int] { h.system.frameLog.reduce(into: [:]) { $0[$1.window, default: 0] += 1 } }
  }

  func makeDesk(settings: Settings = Settings()) -> Desk {
    let h = Harness(displays: [Self.display], settings: settings)
    var own: [WindowID: CGRect] = [:]
    func open(_ app: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, atLeast: CGFloat = 0) -> WindowID {
      let frame = CGRect(x: x, y: y, width: width, height: height)
      let window = h.system.open(
        app: app, pid: Int32(2000 + own.count), frame: frame, minimumSize: CGSize(width: atLeast, height: 0))
      own[window] = frame
      return window
    }
    let finder = open("Finder", 340, 120, 920, 436)
    let safari = open("Safari", 138, 31, 1324, 791)
    let terminal = open("Terminal", 40, 51, 877, 499)
    let notes = open("Notes", 300, 105, 1000, 660, atLeast: 709)
    let mail = open("Mail", 240, 72, 1120, 630, atLeast: 871)
    let textEdit = open("TextEdit", 165, 65, 673, 439)
    let calendar = open("Calendar", 431, 86, 680, 598, atLeast: 680)
    let settingsWindow = open("System Settings", 410, 85, 723, 625, atLeast: 723)
    let preview = open("Preview", 417, 35, 708, 424, atLeast: 708)
    h.start()
    h.run("dock \(finder.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    // By then the gap between the Desktop and Safari had been moved.
    h.overlays.dragSeam(h.overlays.seams[h.display]![1], by: -57)
    h.system.userFocus(safari)
    return Desk(
      h: h, finder: finder, safari: safari, terminal: terminal, notes: notes, mail: mail, textEdit: textEdit,
      calendar: calendar, settings: settingsWindow, preview: preview, own: own)
  }

  /// To the point, but for Terminal, which was four points narrower there: it is as wide as whole letters.
  @Test func theDeskIsTheOneTheDayHadReached() {
    let desk = makeDesk()
    #expect(desk.h.workspace.isDocked(desk.finder) && desk.h.workspace.isDocked(desk.safari))
    #expect(desk.h.frame(desk.finder) == CGRect(x: 12, y: 43, width: 517, height: 767))
    #expect(desk.h.frame(desk.safari) == CGRect(x: 1014, y: 43, width: 574, height: 767))
    #expect(desk.h.frame(desk.terminal) == CGRect(x: 541, y: 51, width: 461, height: 499))
    #expect(desk.h.frame(desk.notes) == CGRect(x: 417, y: 105, width: 709, height: 660))
    #expect(desk.h.frame(desk.mail) == CGRect(x: 336, y: 72, width: 871, height: 630))
    #expect(desk.h.frame(desk.textEdit) == CGRect(x: 541, y: 65, width: 461, height: 439))
    expectWindowsMatchLayout(desk.h)
  }

  @Test func aPauseGivesEveryWindowItsOwnFrameBackInOneMove() {
    let desk = makeDesk()
    let touched = desk.touched
    desk.h.system.clearFrameLog()

    #expect(desk.h.press("toggle-pause").ok)
    for window in desk.all {
      #expect(desk.h.frame(window) == desk.own[window], "\(window)")
      #expect(desk.h.frame(window)!.fractionInside(Self.display.frame) > 0.99, "\(window) is in view")
    }
    #expect(desk.moves() == Dictionary(uniqueKeysWithValues: touched.map { ($0, 1) }), "one move each, and none for the rest")
  }

  @Test func aPauseRaisesNothingAndLeavesTheKeyboardWhereItIs() {
    let desk = makeDesk()
    let raised = desk.h.system.raiseLog.count
    desk.h.press("toggle-pause")
    #expect(desk.h.system.raiseLog.count == raised)
    #expect(desk.h.system.focused == desk.safari)
  }

  @Test func resumingBringsTheArrangementAndTheViewBackInOneMove() {
    let desk = makeDesk()
    let (arranged, frames, touched) = (desk.h.workspace, desk.frames(), desk.touched)
    desk.h.press("toggle-pause")
    desk.h.system.clearFrameLog()

    #expect(desk.h.press("toggle-pause").ok)
    #expect(desk.h.workspace == arranged)
    #expect(desk.frames() == frames)
    #expect(desk.moves() == Dictionary(uniqueKeysWithValues: touched.map { ($0, 1) }), "one move each, and none for the rest")
    expectWindowsMatchLayout(desk.h)
  }

  @Test func framedOnAWindowAPauseGivesThatOneItsSizeBackToo() {
    let desk = makeDesk()
    desk.h.run("zoom \(desk.safari.rawValue)")
    let (arranged, framed) = (desk.h.workspace, desk.h.frame(desk.safari))
    desk.h.system.clearFrameLog()

    desk.h.press("toggle-pause")
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")

    desk.h.system.clearFrameLog()
    desk.h.press("toggle-pause")
    #expect(desk.h.workspace == arranged)
    #expect(desk.h.frame(desk.safari) == framed)
    #expect(desk.moves().values.allSatisfy { $0 == 1 }, "\(desk.moves())")
    for window in desk.all where window != desk.safari { #expect(!desk.h.system.isVisible(window), "\(window)") }
    expectWindowsMatchLayout(desk.h)
  }

  /// One road: whatever is mended on it is mended for both.
  @Test func aPauseLeavesTheWindowsWhereAQuitWould() {
    let (paused, quit) = (makeDesk(), makeDesk())
    paused.h.run("pause")
    quit.h.controller.shutdown()
    #expect(paused.frames() == quit.frames())
  }

  @Test func aPauseWithAnEndDoesTheSame() {
    let desk = makeDesk()
    let frames = desk.frames()
    desk.h.run("pause 5")
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }
    desk.h.scheduler.advance(by: 5 * 60)
    #expect(desk.frames() == frames)
  }

  @Test func soDoesThePauseArborBeginsForAnApp() {
    var settings = Settings()
    settings.pauseForApps = ["com.example.game"]
    let desk = makeDesk(settings: settings)
    let frames = desk.frames()

    desk.h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.game", name: "Game"))
    #expect(desk.h.controller.isPausedForApp)
    for window in desk.all { #expect(desk.h.frame(window) == desk.own[window], "\(window)") }

    desk.h.controller.applicationActivated(FrontmostApp(bundleID: "com.example.safari", name: "Safari"))
    #expect(desk.h.controller.isRunning)
    #expect(desk.frames() == frames)
  }

  @Test func aQuitDuringThePauseHasNothingLeftToDo() {
    let desk = makeDesk()
    desk.h.run("pause")
    let saved = desk.h.store.saved
    desk.h.system.clearFrameLog()
    desk.h.controller.shutdown()
    #expect(desk.h.system.frameLog.isEmpty, "\(desk.h.system.frameLog)")
    #expect(!desk.h.system.started)
    #expect(desk.h.store.saved == saved, "the arrangement is still there for the next launch")
  }

  @Test func stateListsNoWindowDuringThePause() {
    let desk = makeDesk()
    desk.h.run("pause")
    #expect(desk.h.run("state").state?.windows.isEmpty == true, "Arbor is not looking, and does not pass off old frames as current")
  }

  // MARK: An app that does not answer when the pause begins

  /// Finder (docked) and Notes (squeezed) hang, and then a pause.
  func pausedWithFinderAndNotesHung() -> (Desk, slot: CGRect, squeezed: CGRect) {
    let desk = makeDesk()
    let (slot, squeezed) = (desk.h.frame(desk.finder)!, desk.h.frame(desk.notes)!)
    for window in [desk.finder, desk.notes] { desk.h.system.setUnresponsive(pid: desk.h.controller.windows[window]!.pid, true) }
    desk.h.run("pause")
    for pid in desk.h.system.unresponsive { desk.h.system.setUnresponsive(pid: pid, false) }
    return (desk, slot, squeezed)
  }

  /// As after a quit while an app hangs. Starting to look again, at a logout for one, would mean waiting for that very app.
  @Test func aQuitDuringThePauseAsksNoAppAgain() {
    let (desk, slot, squeezed) = pausedWithFinderAndNotesHung()
    #expect(desk.h.frame(desk.finder) == slot && desk.h.frame(desk.notes) == squeezed, "nothing could be done about them")
    let starts = desk.h.system.starts
    desk.h.system.clearFrameLog()
    desk.h.controller.shutdown()
    #expect(desk.h.system.frameLog.isEmpty && desk.h.system.starts == starts)
  }

  @Test func aResumeFindsThemWhereTheyWereAndMovesNeither() {
    let (desk, slot, squeezed) = pausedWithFinderAndNotesHung()
    desk.h.system.clearFrameLog()
    desk.h.run("resume")
    #expect(desk.h.frame(desk.finder) == slot && desk.h.frame(desk.notes) == squeezed)
    #expect(desk.moves()[desk.finder] == nil && desk.moves()[desk.notes] == nil, "\(desk.moves())")
    expectWindowsMatchLayout(desk.h)
  }

  /// What somebody does with a window during the pause is theirs for as long as it lasts; the arrangement comes back all the same.
  @Test func aDockedWindowResizedDuringThePauseGoesBackToItsSlotAndStillRemembersItsOwnSize() {
    let desk = makeDesk()
    let slot = desk.h.frame(desk.finder)
    desk.h.run("pause")
    desk.h.system.userMove(desk.finder, to: CGRect(x: 60, y: 60, width: 500, height: 333))
    desk.h.run("resume")
    #expect(desk.h.frame(desk.finder) == slot)
    #expect(desk.h.workspace.undockedFrame(of: desk.finder) == desk.own[desk.finder])
  }
}
