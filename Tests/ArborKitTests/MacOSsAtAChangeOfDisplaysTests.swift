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

  /// It comes back where macOS left it when the view has been away.
  @Test func thatIsWhereItComesBackTo() {
    let (h, terminal, editor) = desk()
    change(h, terminal, editor)
    h.run("dock \(editor.rawValue) left")
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(terminal))
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == Self.macOSs)
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

  /// Out of view is Arbor's doing, and so is the way back: its own frame is what its person gave it.
  @Test func whatArborHasOutOfViewKeepsItsPlace() {
    let (h, terminal, editor) = desk()
    h.run("dock \(editor.rawValue) left")
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(terminal))
    // macOS pulls it into view, as it was seen to do with windows past the corner.
    change(h, terminal, editor, to: Self.macOSs)
    #expect(place(of: terminal, h) == [Self.main.id: Self.own])
    #expect(!h.system.isVisible(terminal), "the view is on the editor")
    h.run("show-all")
    h.scheduler.advance(by: 2)
    #expect(h.frame(terminal) == Self.own)
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

  /// A window that nobody could get hold of is fetched: never lost outranks never moved.
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

  /// A window kept in view has a part to play. What Arbor remembers of it is not overwritten.
  @Test func aWindowKeptInViewKeepsWhatIsRememberedOfIt() {
    let (h, terminal, editor) = desk()
    h.run("pin \(terminal.rawValue)")
    h.scheduler.advance(by: 2)
    let before = place(of: terminal, h)
    change(h, terminal, editor)
    #expect(place(of: terminal, h) == before)
  }
}
