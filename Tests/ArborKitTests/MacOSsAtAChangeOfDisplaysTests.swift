import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What macOS does to a floating window at a change of displays is macOS's (board 0.23): none is put back. `DisplaysAsRecordedTests` has the recorded
/// case and `SpokeAheadTests` the twins. Here: how far that goes, and what stays Arbor's.
@Suite @MainActor struct MacOSsAtAChangeOfDisplaysTests {
  static let main = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1600, height: 900), visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791), isMain: true)
  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1600, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1600, y: 31, width: 1920, height: 1049),
    isMain: false)

  static let own = CGRect(x: 737, y: 300, width: 600, height: 400)
  static let macOSs = CGRect(x: 900, y: 260, width: 560, height: 380)

  /// A terminal, which the stories are about, and an editor that speaks before it, so that the terminal speaks late: the half that used to be set back.
  func desk(_ displays: [DisplaySnapshot] = [main], settings: Settings = Settings()) -> (h: Harness, terminal: WindowID, editor: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let terminal = h.system.open(app: "Terminal", pid: 11, frame: Self.own)
    let editor = h.system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 100, y: 65, width: 500, height: 400))
    h.start()
    h.scheduler.advance(by: 3)
    return (h, terminal, editor)
  }

  /// The side comes, or goes if it is there, and macOS gives the terminal `frame`. The editor is nudged, and speaks first.
  func change(_ h: Harness, _ terminal: WindowID, _ editor: WindowID, to frame: CGRect = macOSs, repeating: Double = 0.12) {
    let new = h.system.displayList.count == 1 ? [Self.main, Self.side] : [Self.main]
    h.system.clearFrameLog()
    h.system.changeDisplaysAsAMacDoes(
      new, moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: 12)), (terminal, frame)], repeating: repeating)
    h.scheduler.advance(by: 3)
  }

  func place(of window: WindowID, _ h: Harness) -> [DisplayID: CGRect] { h.controller.workspaces.compactMapValues { $0.floating[window] } }
  func framesSet(to window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  // MARK: How far it goes

  /// There and back, and there again: each time where macOS puts it, and Arbor sets nothing.
  @Test func plugAfterPlugNothingIsSet() {
    let (h, terminal, editor) = desk()
    for frame in [Self.macOSs, Self.own, Self.macOSs, Self.own] {
      change(h, terminal, editor, to: frame)
      #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
      #expect(h.frame(terminal) == frame)
      #expect(place(of: terminal, h) == [Self.main.id: frame])
    }
  }

  /// macOS takes it to the display that came. It belongs there from now on.
  @Test func takenToTheOtherDisplayItBelongsThere() {
    let (h, terminal, editor) = desk()
    let there = CGRect(x: 2017, y: 401, width: 600, height: 400)
    change(h, terminal, editor, to: there)
    #expect(framesSet(to: terminal, h).isEmpty)
    #expect(h.frame(terminal) == there)
    #expect(place(of: terminal, h) == [Self.side.id: there])
  }

  /// Seen on a hosted Mac, three times of three: a window that lives wholly on the second display reports its way home 2 ms before macOS's word at the
  /// unplug. Arbor files it under the main display for that. The display comes back, macOS takes the window to the very point it had there, and
  /// Arbor's books went on having it under the main display, of which it shows nothing. Whoever spoke first: afterwards the books name the
  /// display the window lies on, and a move of the view on the main display is nothing to it.
  @Test(arguments: [true, false]) func wentAndCameBackTheBooksNameTheDisplayItLiesOn(speaksEarly: Bool) {
    let h = Harness(displays: [Self.main, Self.side], settings: Settings())
    let there = CGRect(x: 2050, y: 190, width: 600, height: 400)
    let notes = h.system.open(app: "Notes", pid: 11, frame: there)
    let editor = h.system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 100, y: 65, width: 500, height: 400))
    h.start()
    h.scheduler.advance(by: 3)
    #expect(place(of: notes, h) == [Self.side.id: there])
    let nudged = h.frame(editor)!.offsetBy(dx: 0, dy: 12)
    h.system.changeDisplaysAsAMacDoes(
      [Self.main], moving: [(notes, CGRect(x: 300, y: 105, width: 600, height: 400)), (editor, nudged)], ahead: speaksEarly ? 0.05 : 0)
    h.scheduler.advance(by: 3)
    let mark = h.system.moveLog.count
    h.system.changeDisplaysAsAMacDoes([Self.main, Self.side], moving: [(editor, nudged.offsetBy(dx: 0, dy: -12)), (notes, there)])
    h.scheduler.advance(by: 3)
    // (Where it spoke late at the unplug it sleeps with its display and Arbor fetches it at the return, to the point where macOS has it already: a
    // call that moves nothing. That fetching is another step's.)
    #expect(h.system.moveLog[mark...].filter { $0.window == notes && $0.before != $0.after }.isEmpty, "\(h.system.moveLog[mark...])")
    #expect(h.frame(notes) == there)
    #expect(place(of: notes, h) == [Self.side.id: there])
    h.system.clearFrameLog()
    h.run("dock \(editor.rawValue) left")
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(framesSet(to: notes, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == there)
  }

  /// The most ordinary journey there is: a laptop carried to a desk and away. The display comes and macOS takes a window of the laptop over to it. It goes, and
  /// macOS puts the window back at the very place it had. It belonged to the display that went by then, so Arbor placed it like that display's
  /// other windows: 240 points from where macOS had just put it, every round. A floating window that comes from a display that went and is
  /// found where somebody can get hold of it is taken from where it is, like any other.
  @Test func takenOverAtThePlugAndBroughtBackAtTheUnplugNothingIsSet() {
    let (h, terminal, editor) = desk()
    let there = CGRect(x: 2600, y: 500, width: 600, height: 400)
    for round in 1...3 {
      let mark = h.system.moveLog.count
      change(h, terminal, editor, to: there)
      // (From the second round on it is one of that display's own, and Arbor fetches it, to the point where macOS has it already: a call that moves
      // nothing. That fetching is another step's.)
      #expect(h.system.moveLog[mark...].filter { $0.before != $0.after }.isEmpty, "round \(round), the plug: \(h.system.moveLog[mark...])")
      #expect(h.frame(terminal) == there)
      #expect(place(of: terminal, h) == [Self.side.id: there])
      change(h, terminal, editor, to: Self.own)
      #expect(h.system.frameLog.isEmpty, "round \(round), the unplug: \(h.system.frameLog)")
      #expect(h.frame(terminal) == Self.own)
      #expect(place(of: terminal, h) == [Self.main.id: Self.own])
    }
  }

  /// The lid shuts, and the monitor takes over the origin. macOS leaves a window of the laptop at the numbers it had, which are a place on the monitor now: it has
  /// not moved and has nothing to say. For want of such a sign Arbor placed it, as far under the new menu bar as it had been under the old:
  /// 12 points up (walks played with and without Arbor, side by side). Of what comes from a display that went no sign is asked.
  @Test func theLidShutsAndItsNumbersStayAsTheyAre() {
    let laptop = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117), visibleFrame: CGRect(x: 0, y: 37, width: 1728, height: 994), isMain: true)
    let monitor = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: -2560, y: 323, width: 2560, height: 1440), visibleFrame: CGRect(x: -2560, y: 348, width: 2560, height: 1415),
      isMain: false)
    let h = Harness(displays: [laptop, monitor], settings: Settings())
    let lies = CGRect(x: 483, y: 88, width: 723, height: 748)
    let window = h.system.open(app: "Settings", pid: 11, frame: lies)
    h.start()
    h.scheduler.advance(by: 40)
    h.system.clearFrameLog()
    let alone = DisplaySnapshot(
      id: monitor.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1329), isMain: true)
    h.system.changeDisplaysAsAMacDoes([alone])
    h.scheduler.advance(by: 3)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(window) == lies)
    #expect(place(of: window, h) == [monitor.id: lies])
  }

  /// Whatever size macOS brings it back at.
  @Test func broughtBackAtAnotherSizeThatIsItsFrame() {
    let (h, terminal, editor) = desk()
    change(h, terminal, editor, to: CGRect(x: 2600, y: 500, width: 600, height: 400))
    change(h, terminal, editor, to: Self.macOSs)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: Self.macOSs])
  }

  /// Left where its display was, on no display now, it is Arbor's to place: never lost outranks never moved.
  @Test func leftWhereItsDisplayWasItIsPlaced() {
    let (h, terminal, editor) = desk()
    let there = CGRect(x: 2600, y: 500, width: 600, height: 400)
    change(h, terminal, editor, to: there)
    change(h, terminal, editor, to: there.offsetBy(dx: 10, dy: 0))
    #expect(Self.main.frame.contains(CGPoint(x: h.frame(terminal)!.midX, y: h.frame(terminal)!.minY + 12)), "\(h.frame(terminal)!)")
    #expect(h.system.isVisible(terminal))
    #expect(place(of: terminal, h).keys.sorted() == [Self.main.id])
  }

  /// Unless the view is held. The laptop's view is on one docked window and is held for an audience; it may show nothing at all just now. A floating window of
  /// the display that goes is brought onto the laptop by macOS, whole and within reach. It does not stay there: a held view gives nothing
  /// away, and whatever arrives under a hold waits out of view. Where macOS brought it is its place all the same, for when the hold is over.
  /// Over a view that is framed and not held it stays: an arrival is as a window that comes out of the Dock.
  @Test(arguments: ["held", "held and empty", "framed"]) func whatArrivesUnderAHeldViewWaitsOutOfView(view: String) {
    let h = Harness(displays: [Self.main, Self.side], settings: Settings())
    let music = h.system.open(app: "Music", pid: 11, frame: CGRect(x: 2100, y: 200, width: 800, height: 600))
    let terminal = h.system.open(app: "Terminal", pid: 12, frame: CGRect(x: 500, y: 300, width: 700, height: 500))
    h.start()
    h.system.cursor = CGPoint(x: 700, y: 500)
    h.run("dock \(terminal.rawValue) right")
    h.run("zoom \(terminal.rawValue)")
    h.scheduler.advance(by: 2)
    if view != "framed" {
      h.run("hold")
      h.scheduler.advance(by: 1)
    }
    if view == "held and empty" {
      h.system.setHidden(pid: 12, true)
      h.scheduler.advance(by: 2)
      #expect(h.controller.displaysHeldEmpty == [Self.main.id], "the situation")
    }
    let brought = CGRect(x: 488, y: 182, width: 800, height: 600)
    h.system.clearFrameLog()
    // Nobody speaks before macOS's list is new: who does passes for a hand's, under a hold too, which is older than this.
    h.system.changeDisplaysAsAMacDoes([Self.main], moving: [(music, brought)], ahead: 0)
    h.scheduler.advance(by: 3)
    #expect(place(of: music, h) == [Self.main.id: brought])
    if view == "framed" {
      #expect(h.frame(music) == brought)
      #expect(framesSet(to: music, h).isEmpty, "\(h.system.frameLog)")
    } else {
      #expect(!h.system.isVisible(music), "\(h.frame(music)!)")
      h.run("release")
      h.run("show-all")
      h.scheduler.advance(by: 2)
      #expect(h.frame(music) == brought)
    }
  }

  /// It stays where macOS left it when the view goes away and comes back: no view takes a floating window out of view.
  @Test func thatIsWhereItStaysWhereverTheViewGoes() {
    let (h, terminal, editor) = desk()
    change(h, terminal, editor)
    h.run("dock \(editor.rawValue) left")
    h.system.clearFrameLog()
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == Self.macOSs)
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == Self.macOSs)
    #expect(!h.system.frameLog.contains { $0.window == terminal }, "\(h.system.frameLog)")
  }

  /// macOS goes on about its screens for so long that Arbor's own look-out for a display that blinked comes before the news (one recording of 37).
  @Test func theLookOutForABlinkComesBeforeTheNews() {
    let (h, terminal, editor) = desk()
    change(h, terminal, editor, repeating: 0.9)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: Self.macOSs])
  }

  /// Quit within Arbor's wait for the displays. It gives every window its remembered place, and that is where the window is.
  @Test func aQuitInsideTheWaitSetsNothingEither() {
    let (h, terminal, _) = desk()
    h.system.clearFrameLog()
    h.system.displayList = [Self.main, Self.side]
    h.system.userMove(terminal, to: Self.macOSs)
    h.scheduler.advance(by: 0.5)
    h.controller.shutdown()
    #expect(framesSet(to: terminal, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == Self.macOSs)
  }

  /// The same where macOS has taken the window onto the display that has only just come, which Arbor has not heard of: it looks before it lets go.
  @Test(arguments: ["quit", "pause"]) func lettingGoInsideTheWaitItGoesByTheDisplaysThatAre(how: String) {
    let (h, terminal, _) = desk()
    let there = CGRect(x: 2017, y: 401, width: 600, height: 400)
    h.system.clearFrameLog()
    h.system.displayList = [Self.main, Self.side]
    h.system.userMove(terminal, to: there)
    h.scheduler.advance(by: 0.5)
    if how == "quit" { h.controller.shutdown() } else { h.run("pause") }
    #expect(framesSet(to: terminal, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == there)
  }

  /// Why the look used to leave out a display that comes: this one comes BACK, and its arrangement sleeps. Letting go a moment later, Arbor must not first send
  /// that display's windows over to it. It does not: with the books alone brought up to date the arrangement sleeps on. And where macOS has fetched
  /// the window home itself it stays there, where it used to be pulled back onto the laptop.
  @Test(arguments: ["quit", "pause"], [true, false]) func lettingGoAsADisplayComesBackSendsNothingOver(how: String, macOSFetchesIt: Bool) {
    let h = Harness(displays: [Self.main, Self.side], settings: Settings())
    let there = CGRect(x: 2050, y: 190, width: 600, height: 400)
    let notes = h.system.open(app: "Notes", pid: 11, frame: there)
    let editor = h.system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 100, y: 65, width: 500, height: 400))
    h.start()
    h.scheduler.advance(by: 3)
    h.system.changeDisplaysAsAMacDoes(
      [Self.main], moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: 12)), (notes, CGRect(x: 300, y: 105, width: 600, height: 400))])
    h.scheduler.advance(by: 60)
    h.system.clearFrameLog()
    h.system.displayList = [Self.main, Self.side]
    if macOSFetchesIt { h.system.userMove(notes, to: there) }
    h.scheduler.advance(by: 0.5)
    let found = h.frame(notes)!
    if how == "quit" { h.controller.shutdown() } else { h.run("pause") }
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(notes) == found)
  }

  /// A pause inside the wait, and the resume. What was taken outlives both: the books went back to what they had said before the pause, and
  /// ten minutes later an ordinary quit set the window back: the put-back, only late.
  @Test func whatAPauseInsideTheWaitTookOutlivesTheResume() {
    let (h, terminal, _) = desk()
    h.system.displayList = [Self.main, Self.side]
    h.system.userMove(terminal, to: Self.macOSs)
    h.scheduler.advance(by: 0.5)
    h.system.clearFrameLog()
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 5)
    #expect(h.run("resume").ok)
    h.scheduler.advance(by: 600)
    #expect(h.frame(terminal) == Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: Self.macOSs])
    h.controller.shutdown()
    #expect(framesSet(to: terminal, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == Self.macOSs)
  }

  /// What is taken after a blink is written down like any other place: a minute later Arbor crashes, and starts again.
  @Test func whatABlinkLeftIsSaved() {
    let (h, terminal, _) = desk([Self.main, Self.side])
    h.system.displayList = [Self.main]
    h.system.userMove(terminal, to: Self.macOSs)
    h.scheduler.advance(by: 0.6)
    h.system.displayList = [Self.main, Self.side]
    h.scheduler.advance(by: 60)
    #expect(place(of: terminal, h) == [Self.main.id: Self.macOSs])
    let after = h.newProcess()
    after.start()
    after.scheduler.advance(by: 3)
    #expect(after.controller.workspaces.compactMapValues { $0.floating[terminal] } == [Self.main.id: Self.macOSs])
    #expect(after.frame(terminal) == Self.macOSs)
  }

  /// An ordinary quit or pause is no change of displays. A window that its person moved a moment ago, and that its app has moved since, which is nobody's
  /// choice of a place: what Arbor remembers of it is not rewritten on the way out.
  @Test(arguments: ["quit", "pause"]) func anOrdinaryQuitOrPauseTakesNothing(how: String) {
    let (h, terminal, _) = desk()
    let byHand = CGRect(x: 500, y: 200, width: 600, height: 400)
    h.system.userMove(terminal, to: byHand)
    h.scheduler.advance(by: 5)
    #expect(place(of: terminal, h) == [Self.main.id: byHand])
    h.system.moveSilently(terminal, to: Self.macOSs)
    h.system.report(terminal, userInitiated: false)
    #expect(place(of: terminal, h) == [Self.main.id: byHand], "the situation: Arbor knows where it is, and its place is still its person's")
    if how == "quit" { h.controller.shutdown() } else { h.run("pause") }
    #expect(place(of: terminal, h) == [Self.main.id: byHand])
  }

  // MARK: What stays Arbor's

  /// Out of view is Arbor's doing, and so is the way back: its own frame is what its person gave it. Sent away by name, that is: no view
  /// takes a floating window out of view.
  @Test func whatArborHasOutOfViewKeepsItsPlace() {
    let (h, terminal, editor) = desk()
    h.run("summon Terminal")
    h.scheduler.advance(by: 2)
    let own = h.frame(terminal)!
    h.run("summon Terminal")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(terminal))
    // macOS pulls it into view, as it was seen to do with windows past the corner.
    change(h, terminal, editor, to: Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: own])
    #expect(!h.system.isVisible(terminal), "it was sent away")
    h.run("summon Terminal")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == own)
  }

  /// Behind a framed window it is in view like any other, and taken from where macOS left it like any other.
  @Test func behindAFramedWindowItIsTakenFromWhereItIsLikeAnyOther() {
    let (h, terminal, editor) = desk()
    h.run("dock \(editor.rawValue) left")
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 2)
    change(h, terminal, editor, to: Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: Self.macOSs])
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == Self.macOSs)
    #expect(!h.system.frameLog.contains { $0.window == terminal }, "\(h.system.frameLog)")
  }

  /// A docked window goes back to its slot.
  @Test func aDockedWindowGoesBack() {
    let (h, terminal, editor) = desk()
    h.run("dock \(terminal.rawValue) right")
    h.scheduler.advance(by: 2)
    let slot = h.frame(terminal)!
    change(h, terminal, editor)
    #expect(h.frame(terminal) == slot)
    expectWindowsMatchLayout(h)
  }

  /// A window that nobody could get hold of is fetched: never lost outranks never moved. (Wholly beyond every display, so it counts as out of view before the rule
  /// looks. The rule's own limit, most of it showing and the title bar out of reach: `ReviewMacOSsAtAChangeOfDisplaysTests`.)
  @Test func whereNobodyCouldGetHoldOfItArborActs() {
    let (h, terminal, editor) = desk([Self.main, Self.side])
    change(h, terminal, editor, to: CGRect(x: 1700, y: 300, width: 600, height: 400))
    // All of its title bar lay beyond the only display that is left.
    #expect(Self.main.frame.contains(CGPoint(x: h.frame(terminal)!.midX, y: h.frame(terminal)!.minY + 12)), "\(h.frame(terminal)!)")
    #expect(h.system.isVisible(terminal))
  }

  /// Where floating windows make way the layout places them, as before.
  @Test func whereFloatingWindowsMakeWayTheLayoutPlacesThem() {
    let (h, terminal, editor) = desk(settings: .makingWay)
    change(h, terminal, editor)
    #expect(place(of: terminal, h) == [Self.main.id: Self.own])
    #expect(h.frame(terminal) == Self.own)
  }

  /// A window kept in view has a part to play. What Arbor remembers of it is not overwritten, and no frame is set to it either: as before this change.
  @Test func aWindowKeptInViewKeepsWhatIsRememberedOfIt() {
    let (h, terminal, editor) = desk()
    h.run("pin \(terminal.rawValue)")
    h.scheduler.advance(by: 2)
    let before = place(of: terminal, h)
    change(h, terminal, editor)
    #expect(place(of: terminal, h) == before)
    #expect(framesSet(to: terminal, h).isEmpty, "\(h.system.frameLog)")
    #expect(h.frame(terminal) == Self.macOSs)
  }
}
