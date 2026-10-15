import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// What a reader who built "what macOS does to a floating window at a change of displays is macOS's" and ran it found, each as the story that showed it,
/// and a guard for each limit of the rule that no test held (`MacOSsAtAChangeOfDisplaysTests` has the ground).
@Suite @MainActor struct ReviewMacOSsAtAChangeOfDisplaysTests {
  static let main = MacOSsAtAChangeOfDisplaysTests.main
  static let side = MacOSsAtAChangeOfDisplaysTests.side
  static let own = CGRect(x: 737, y: 300, width: 600, height: 400)
  static let macOSs = CGRect(x: 900, y: 260, width: 560, height: 380)

  func desk(_ displays: [DisplaySnapshot] = [main], terminalAt: CGRect = own) -> (h: Harness, terminal: WindowID, editor: WindowID) {
    let h = Harness(displays: displays, settings: Settings())
    let terminal = h.system.open(app: "Terminal", pid: 11, frame: terminalAt)
    let editor = h.system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 100, y: 65, width: 500, height: 400))
    h.start()
    h.scheduler.advance(by: 40)
    h.system.clearFrameLog()
    return (h, terminal, editor)
  }

  /// The side comes, or goes, or the displays are as given. The editor is nudged and speaks first, the terminal late.
  func change(_ h: Harness, _ terminal: WindowID, _ editor: WindowID, to frame: CGRect = macOSs, displays: [DisplaySnapshot]? = nil) {
    let new = displays ?? (h.system.displayList.count == 1 ? [Self.main, Self.side] : [Self.main])
    h.system.changeDisplaysAsAMacDoes(new, moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: 12)), (terminal, frame)])
    h.scheduler.advance(by: 3)
  }

  /// A fit as there still is one. At a change of displays nothing is fitted that somebody can get hold of (board 0.23, the second half): so it is out of
  /// view with its Desktop while the displays change, and comes back to where less than half of it would show.
  func fitWhileOutOfView(_ h: Harness, _ terminal: WindowID, _ editor: WindowID, displays: [DisplaySnapshot] = [main]) -> CGRect {
    h.run("dock \(editor.rawValue) left")
    h.run("zoom \(editor.rawValue)")
    h.scheduler.advance(by: 3)
    h.system.changeDisplaysAsAMacDoes(displays)
    h.scheduler.advance(by: 3)
    h.run("back")
    h.scheduler.advance(by: 40)
    return h.frame(terminal)!
  }

  func place(of window: WindowID, _ h: Harness) -> [DisplayID: CGRect] { h.controller.workspaces.compactMapValues { $0.floating[window] } }
  func framesSet(to window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  // MARK: What was found

  /// The side went with its view on one docked window. It comes back, and macOS takes the window being typed in over to it. It belongs there now, where the
  /// Desktop is out of view, and the first layout of a display that has only just come sent it out of view with the Desktop. It stays, as
  /// a window that opens over such a view does.
  @Test func takenOverToADisplayThatComesBackFramedItStaysInView() {
    let h = Harness(displays: [Self.main, Self.side], settings: Settings())
    let terminal = h.system.open(app: "Terminal", pid: 11, frame: Self.own)
    let editor = h.system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 100, y: 65, width: 500, height: 400))
    let browser = h.system.open(app: "Browser", pid: 13, frame: CGRect(x: 1800, y: 100, width: 700, height: 500))
    let chat = h.system.open(app: "Chat", pid: 14, frame: CGRect(x: 2600, y: 100, width: 700, height: 500))
    h.start()
    h.scheduler.advance(by: 40)
    h.system.cursor = CGPoint(x: 2000, y: 300)
    h.run("dock \(browser.rawValue) left")
    h.run("dock \(chat.rawValue) right")
    h.run("zoom \(browser.rawValue)")
    h.scheduler.advance(by: 3)
    h.system.cursor = CGPoint(x: 700, y: 600)
    h.system.changeDisplaysAsAMacDoes(
      [Self.main], moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: 12)), (browser, CGRect(x: 200, y: 100, width: 700, height: 500))])
    h.scheduler.advance(by: 40)
    h.system.userFocus(terminal)
    h.scheduler.advance(by: 40)
    h.system.clearFrameLog()
    let there = CGRect(x: 2017, y: 401, width: 600, height: 400)
    h.system.changeDisplaysAsAMacDoes([Self.main, Self.side], moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: -12)), (terminal, there)])
    h.scheduler.advance(by: 5)
    #expect(framesSet(to: terminal, h) == [])
    #expect(h.frame(terminal) == there)
    #expect(h.system.isVisible(terminal))
  }

  /// A display blinks, macOS moves one window and resizes another, and the next word about the displays is about the Dock alone. It comes before Arbor's own
  /// look-out for a blink and calls that off; and a word about the Dock is no change of displays. So nobody took them, and the books went on
  /// naming a display the window had left.
  @Test func aBlinkAndThenAWordAboutTheDock() {
    let (h, terminal, editor) = desk([Self.main, Self.side], terminalAt: CGRect(x: 2050, y: 190, width: 600, height: 400))
    let (terminals, editors) = (CGRect(x: 300, y: 105, width: 600, height: 400), CGRect(x: 140, y: 90, width: 480, height: 380))
    h.system.displayList = [Self.main]
    h.system.userMove(terminal, to: terminals)
    h.system.userMove(editor, to: editors)
    h.scheduler.advance(by: 0.6)
    h.system.displayList = [Self.main, Self.side]
    var withADock = Self.main
    withADock.visibleFrame = CGRect(x: 0, y: 31, width: 1600, height: 770)
    h.system.changeDisplaysAsAMacDoes([withADock, Self.side])
    h.scheduler.advance(by: 20)
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(place(of: terminal, h) == [Self.main.id: terminals])
    #expect(place(of: editor, h) == [Self.main.id: editors])
  }

  /// Arbor fitted it once. macOS has moved it since, and it was taken from there. At the next change macOS takes it to the very frame Arbor had fitted it to, which
  /// is macOS's place for it with those displays. The note of the fit had outlived the taking, so it passed for fitted, and was put back.
  @Test func aFitDoesNotOutliveATaking() {
    let hanging = CGRect(x: 1250, y: 690, width: 600, height: 400)
    let (h, terminal, editor) = desk([Self.main, Self.side], terminalAt: hanging)
    let fitted = fitWhileOutOfView(h, terminal, editor)
    #expect(fitted != hanging && Self.main.visibleFrame.contains(fitted), "the situation: it was fitted")
    change(h, terminal, editor, to: Self.macOSs)
    h.system.clearFrameLog()
    change(h, terminal, editor, to: fitted)
    #expect(framesSet(to: terminal, h) == [])
    #expect(h.frame(terminal) == fitted)
    #expect(place(of: terminal, h) == [Self.main.id: fitted])
  }

  /// Left by hand with a strip showing. macOS pulls it up at the plug and takes it back to the very frame at the unplug. The hand's note is about that frame, and
  /// says nothing while the window is elsewhere. It used to be thrown away at the taking, and the strip was fitted at the unplug.
  @Test func aStripLeftByHandThatMacOSTakesAwayAndBringsBack() {
    let (h, terminal, editor) = desk()
    h.system.drag(terminal, through: [CGPoint(x: 1000, y: 310), CGPoint(x: 1000, y: 800)])
    h.scheduler.advance(by: 40)
    let left = h.frame(terminal)!
    h.system.clearFrameLog()
    change(h, terminal, editor, to: CGRect(x: 737, y: 420, width: 600, height: 400))
    change(h, terminal, editor, to: left)
    #expect(framesSet(to: terminal, h) == [])
    #expect(h.frame(terminal) == left)
  }

  // MARK: What the walks found

  /// What macOS does to a window is macOS's. What Arbor did to it is given back. A window wider than the display it ends on is fitted by Arbor, 2416 wide to 1080. That display goes, macOS brings the window
  /// over, elsewhere than Arbor had fitted it, so it no longer passed for fitted: it was taken from where it was, at Arbor's size, and its own was
  /// forgotten for good. (One of 22 walks of 2,000 that end at this rule with the change and not without; 16 break it on the base too, by their shrunk
  /// scripts, and in 5 it was the lab's macOS that made the window smaller, which is macOS's by the ruling.)
  @Test func aSizeArborFittedItToIsNotTakenForItsOwn() {
    let broken = ChaosRunner.replayToTheEnd(
      ChaosAction.script(
        """
        displays main:0,0,800,600:37,0,0,45* side:800,19,1280,800:0,0,0,0 windows-first
        launch
        open 105 Preview pid 1007 at 323 273 2416 1222
        displays main:0,0,1440,900:25,0,0,0* side:-20,900,1080,1920:37,0,0,0 third:273,2820,1512,982:0,71,0,0 windows-late
        displays main:0,0,2560,1440:25,0,52,0* windows-late
        toggle-pause
        """))
    #expect(!broken.contains { $0.rule == "size-not-given-back" }, "\(broken)")
  }

  /// The same on a display that stays. It becomes narrower than the window while that is out of view, so Arbor fits the window as it comes back. It becomes wide again, and macOS
  /// nudges the window, which is no longer at the frame Arbor fitted it to. It goes back to its own frame all the same, as it does unnudged, and
  /// has it when Arbor lets go.
  @Test(arguments: ["quit", "pause"]) func nudgedByMacOSAtASizeArborGaveItGoesBackToItsOwnFrame(how: String) {
    let wide = CGRect(x: 280, y: 100, width: 1300, height: 500)
    let (h, terminal, editor) = desk(terminalAt: wide)
    var narrow = Self.main
    narrow.frame.size = CGSize(width: 800, height: 700)
    narrow.visibleFrame = CGRect(x: 0, y: 31, width: 800, height: 600)
    let fitted = fitWhileOutOfView(h, terminal, editor, displays: [narrow])
    #expect(fitted.width < wide.width, "the situation: Arbor made it narrower, \(fitted)")
    change(h, terminal, editor, to: fitted.offsetBy(dx: 0, dy: 24), displays: [Self.main])
    h.scheduler.advance(by: 20)
    #expect(h.frame(terminal) == wide)
    #expect(place(of: terminal, h) == [Self.main.id: wide])
    if how == "quit" { h.controller.shutdown() } else { h.run("pause") }
    #expect(h.frame(terminal) == wide)
  }

  /// Nor is the frame of a window that fills the view: Arbor put it there, at a key, and the same key takes it back to its own frame. macOS nudges it at a plug.
  /// (Green alone, red together: the key that fills the view landed while this change was being read, and a test of its own said so:
  /// `FillTheScreenTests.theDisplayShrinksWhileItFillsAndItsOwnFrameIsFittedOnTheWayBack`.)
  @Test func fillingTheViewItsOwnFrameIsNotForgotten() {
    let (h, terminal, editor) = desk()
    h.system.userFocus(terminal)
    h.scheduler.advance(by: 2)
    h.run("zoom")
    h.scheduler.advance(by: 3)
    #expect(h.controller.isFilled(terminal), "the situation")
    let fills = h.frame(terminal)!
    change(h, terminal, editor, to: fills.offsetBy(dx: 0, dy: 6))
    #expect(place(of: terminal, h) == [Self.main.id: Self.own])
    h.run("zoom")
    h.scheduler.advance(by: 3)
    #expect(h.frame(terminal) == Self.own)
  }

  /// The same where it filled the display that GOES, and macOS brings it over at the size it has. By then it is filed on the display that stays, where no fill is
  /// marked, so it passed for any other arrival within reach: it rested at the fill's size, the key said that it filled the screen already, and
  /// nothing gave its own size back while that display was away. It is placed like the arrivals that macOS has not brought over, at its own size.
  @Test func havingFilledTheDisplayThatGoesItArrivesAtItsOwnSize() {
    let there = CGRect(x: 2050, y: 190, width: 600, height: 400)
    let (h, terminal, editor) = desk([Self.main, Self.side], terminalAt: there)
    h.system.cursor = CGPoint(x: 2300, y: 400)
    h.system.userFocus(terminal)
    h.scheduler.advance(by: 2)
    h.run("zoom")
    h.scheduler.advance(by: 3)
    #expect(h.controller.isFilled(terminal), "the situation")
    let fills = h.frame(terminal)!
    #expect(fills.width > 1600, "the situation: wider than the display that stays, \(fills)")
    change(h, terminal, editor, to: CGRect(x: 0, y: 31, width: fills.width, height: fills.height))
    #expect(h.frame(terminal)?.size == there.size, "\(h.frame(terminal)!)")
    #expect(place(of: terminal, h)[Self.main.id]?.size == there.size)
  }

  // MARK: Limits that nothing held

  /// Three quarters of it show, so it is not stranded, and its title bar is above every display: nobody could get hold of it. That is no place to take it from.
  /// It used to go back to its own place. Decided since (board 0.23, the second half): it is fitted, the least move that brings it wholly into view, and
  /// the fitted frame is what the books hold.
  @Test func whereNobodyCouldGetHoldOfItItIsFittedAndThatIsItsPlace() {
    var above = Self.side
    above.frame = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
    above.visibleFrame = CGRect(x: 0, y: -1049, width: 1920, height: 1049)
    let (h, terminal, editor) = desk([Self.main, above])
    change(h, terminal, editor, to: CGRect(x: 400, y: -100, width: 600, height: 400), displays: [Self.main])
    let fitted = CGRect(x: 400, y: 31, width: 600, height: 400)
    #expect(framesSet(to: terminal, h) == [fitted])
    #expect(place(of: terminal, h) == [Self.main.id: fitted])
    #expect(h.frame(terminal) == fitted)
  }

  /// Whoever lists windows by display is told that one has changed display.
  @Test func whoeverListsWindowsIsTold() {
    let (h, terminal, editor) = desk()
    var told = 0
    h.controller.observe { if $0 == .windows { told += 1 } }
    change(h, terminal, editor, to: CGRect(x: 2017, y: 401, width: 600, height: 400))
    #expect(told > 0)
  }

  /// What is in the hand is the hand's. It has spoken lately, so by that it could be taken.
  @Test func inTheHandItIsNotTaken() {
    let (h, terminal, editor) = desk()
    let before = CGRect(x: 1000, y: 300, width: 600, height: 400)
    h.system.userMove(terminal, to: before)
    h.scheduler.advance(by: 2)
    h.system.beginDrag(terminal, at: CGPoint(x: 1200, y: 310))
    h.system.moveDrag(to: CGPoint(x: 1100, y: 500))
    #expect(h.frame(terminal) != before, "the situation: it is on its way")
    h.system.changeDisplaysAsAMacDoes([Self.main, Self.side], moving: [(editor, h.frame(editor)!.offsetBy(dx: 0, dy: 12))])
    h.scheduler.advance(by: 3)
    #expect(place(of: terminal, h) == [Self.main.id: before])
    h.system.endDrag()
  }

  /// In full screen its frame is the display's, which is no place to float at.
  @Test func inFullScreenItsFrameIsNoPlace() {
    let (h, terminal, editor) = desk()
    h.system.setFullScreen(terminal, true)
    h.scheduler.advance(by: 40)
    var smaller = Self.main
    smaller.frame.size = CGSize(width: 1440, height: 810)
    smaller.visibleFrame = CGRect(x: 0, y: 31, width: 1440, height: 701)
    change(h, terminal, editor, to: smaller.frame, displays: [smaller])
    #expect(place(of: terminal, h) == [Self.main.id: Self.own])
  }

  /// What Arbor fitted for the displays' sake has its own frame to go back to, also if its app has something to say.
  @Test func whatArborFittedGoesBackToItsOwnFrame() {
    let hanging = CGRect(x: 1250, y: 690, width: 600, height: 400)
    let (h, terminal, editor) = desk([Self.main, Self.side], terminalAt: hanging)
    let fitted = fitWhileOutOfView(h, terminal, editor)
    #expect(fitted != hanging && Self.main.visibleFrame.contains(fitted), "the situation: it was fitted")
    change(h, terminal, editor, to: fitted)
    #expect(place(of: terminal, h) == [Self.main.id: hanging])
    #expect(h.frame(terminal) == hanging)
  }

  /// A quit inside Arbor's wait for the displays, of a window macOS has only moved: what is written down for the next start is where it is.
  @Test func aQuitInsideTheWaitWritesDownWhereItIs() {
    let (h, terminal, _) = desk()
    let moved = CGRect(x: 1000, y: 300, width: 600, height: 400)
    h.system.displayList = [Self.main, Self.side]
    h.system.userMove(terminal, to: moved)
    h.scheduler.advance(by: 0.5)
    h.controller.shutdown()
    #expect(framesSet(to: terminal, h) == [])
    #expect(h.store.saved?.workspaces[Self.main.id]?.floating[terminal] == moved)
  }
}
