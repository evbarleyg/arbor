import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// Where the note floats in these tests, by its person's hand.
private let own = CGRect(x: 200, y: 150, width: 640, height: 420)

/// The key that fills the screen fills it with a floating window too, and keeps it there (collab/QUESTIONS.md, Q29; board 0.16;
/// Controller+Fill.swift).
@Suite @MainActor struct FillTheScreenTests {
  /// Nothing is docked: a note in front, and a second window that nobody touches.
  func newcomer(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], settings: Settings = Harness.settingsWhenNoneAreGiven) -> (
    Harness, note: WindowID, other: WindowID
  ) {
    let h = Harness(displays: displays, settings: settings)
    let note = h.system.open(app: "Notes", pid: 1001)
    let other = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 700, y: 300, width: 500, height: 400))
    h.start()
    h.system.userMove(note, to: own)
    h.system.userFocus(note)
    settle(h)
    h.system.clearFrameLog()
    return (h, note, other)
  }

  /// [editor | Desktop | browser], with the note and a second window floating on the Desktop.
  func desk(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, editor: WindowID, browser: WindowID, note: WindowID, other: WindowID) {
    let h = Harness(settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let note = h.system.open(app: "Notes", pid: 1003)
    let other = h.system.open(app: "Mail", pid: 1004)
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    h.system.userMove(note, to: CGRect(x: 520, y: 100, width: 380, height: 300))
    h.system.userMove(other, to: CGRect(x: 540, y: 450, width: 360, height: 300))
    h.system.userFocus(note)
    settle(h)
    h.system.clearFrameLog()
    return (h, editor, browser, note, other)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 1) }

  /// What a framed window fills.
  func view(_ h: Harness, _ display: DisplaySnapshot? = nil) -> CGRect {
    (display?.visibleFrame ?? h.visibleFrame).insetBy(dx: 12, dy: 12)
  }

  /// The windows Arbor has asked anything of since the log was last cleared.
  func touched(_ h: Harness) -> Set<WindowID> { Set(h.system.frameLog.map(\.window)) }

  // MARK: 1. There and back

  @Test func theKeyFillsTheScreenWithAWindowThatWasNeverDocked() {
    let (h, note, other) = newcomer()
    let (camera, elsewhere, raised) = (h.workspace.camera, h.frame(other), h.system.raiseLog)
    let mark = h.system.moveLog.count
    let reply = h.press("zoom")
    #expect(reply.ok && reply.message == "filled the screen with \(note)")
    #expect(h.frame(note) == view(h))
    #expect(h.workspace.isFloating(note) && h.controller.isFilled(note))
    #expect(h.workspace.floating[note] == own, "the fill's size is Arbor's, never the window's own")
    #expect(h.workspace.camera == camera, "the view does not move")
    #expect(touched(h) == [note] && h.frame(other) == elsewhere)
    #expect(h.system.raiseLog == raised, "nothing is raised")
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1)
    #expect(h.system.focusedWindow() == note)
    expectWindowsMatchLayout(h)
  }

  @Test func theSameKeyAgainGivesBackExactlyTheFrameItHad() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    let mark = h.system.moveLog.count
    let reply = h.press("zoom")
    #expect(reply.ok)
    #expect(h.frame(note) == own)
    #expect(!h.controller.isFilled(note) && h.workspace.filled == nil)
    #expect(touched(h) == [note], "\(other) is not touched")
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1)
    // And so on, for ever.
    for _ in 0..<3 {
      h.press("zoom")
      #expect(h.frame(note) == view(h))
      h.press("zoom")
      #expect(h.frame(note) == own)
    }
    expectWindowsMatchLayout(h)
  }

  @Test func amongDockedWindowsNothingElseIsTouchedEitherWay() {
    let (h, editor, browser, note, other) = desk()
    let before = [editor, browser, other].map { h.frame($0) }
    let (had, camera, order) = (h.frame(note), h.workspace.camera, h.system.windowsFrontToBack())
    h.press("zoom")
    #expect(h.frame(note) == view(h))
    #expect(touched(h) == [note])
    #expect([editor, browser, other].map { h.frame($0) } == before)
    #expect(h.workspace.camera == camera)
    #expect(h.system.windowsFrontToBack() == order, "what is behind stays behind, in its order")
    #expect(h.controller.parked.isEmpty)
    expectWindowsMatchLayout(h)
    h.press("zoom")
    #expect(h.frame(note) == had)
    #expect(touched(h) == [note])
    expectWindowsMatchLayout(h)
  }

  /// There is one frame to go back to, whoever asks: the key gives what Quit, a pause and a drag give. Two records came apart.
  @Test func aWindowThatDockedWindowsHadPushedAsideGoesBackToItsOwnFrameAndTheNextLayoutLeavesItThere() {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let note = h.system.open(app: "Notes", pid: 1002)
    h.start()
    let byHand = CGRect(x: 200, y: 150, width: 900, height: 600)
    h.system.userMove(note, to: byHand)
    h.run("dock \(editor.rawValue) left")
    h.system.userFocus(note)
    settle(h)
    #expect(h.workspace.floating[note] == byHand)
    h.press("zoom")
    #expect(h.frame(note) == view(h))
    // What squeezed it goes meanwhile.
    h.run("float \(editor.rawValue)")
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == byHand)
    h.system.clearFrameLog()
    h.run("relayout")
    settle(h)
    #expect(h.frame(note) == byHand && !touched(h).contains(note), "to where it ends up, at once")
  }

  @Test func itsOwnFrameComesBackExactlyAlsoWhereItHangsOverAnEdge() {
    let (h, note, _) = newcomer()
    for hanging in [CGRect(x: -400, y: 150, width: 640, height: 420), CGRect(x: 1000, y: 700, width: 640, height: 420)] {
      h.system.userMove(note, to: hanging)
      settle(h)
      h.press("zoom")
      #expect(h.frame(note) == view(h))
      h.press("zoom")
      #expect(h.frame(note) == hanging)
    }
  }

  /// Found by `UndoTests.randomWalksStayConsistent`, seed 36: let go across two displays, one of which then went.
  @Test func aStripTooNarrowToGrabIsNoPlaceToGoBackTo() {
    let (h, note, _) = newcomer()
    h.system.userMove(note, to: CGRect(x: 1430, y: 150, width: 640, height: 420))
    settle(h)
    for way in ["zoom", "undo", "show-all"] {
      h.press("zoom")
      #expect(h.frame(note) == view(h), "\(way)")
      h.system.clearFrameLog()
      h.run(way)
      settle(h)
      #expect(h.frame(note) == CGRect(x: 800, y: 150, width: 640, height: 420), "\(way)")
      #expect(h.system.frameLog.filter { $0.window == note }.count == 1, "\(way): in one move")
    }
  }

  @Test func withTheWindowNamedTheCommandIsIdempotent() {
    let (h, note, _) = newcomer()
    #expect(h.run("zoom \(note.rawValue)").ok)
    h.system.clearFrameLog()
    let again = h.run("zoom \(note.rawValue)")
    #expect(again.ok && again.message == "\(note) fills the screen already")
    #expect(h.frame(note) == view(h) && touched(h).isEmpty)
  }

  @Test func namedFromBehindItComesToTheFront() {
    let (h, note, other) = newcomer()
    h.system.userFocus(other)
    h.run("zoom \(note.rawValue)")
    #expect(h.frame(note) == view(h))
    #expect(h.system.focusedWindow() == note)
  }

  // MARK: 2. It stays

  @Test func itStaysFilledThroughWhateverHappensByItself() {
    let (h, editor, browser, note, other) = desk()
    h.press("zoom")
    h.system.clearFrameLog()
    var opened: WindowID?
    let events: [(String, () -> Void)] = [
      ("time passes", { h.scheduler.advance(by: 5) }),
      ("another window is focused", { h.system.userFocus(editor) }),
      ("it is focused again", { h.system.userFocus(note) }),
      ("a window opens", { opened = h.system.open(app: "Preview", pid: 1009) }),
      ("that window closes", { h.system.close(opened!) }),
      ("a docked window is minimized", { h.system.setMinimized(browser, true) }),
      ("and comes back", { h.system.setMinimized(browser, false) }),
      ("a floating window closes", { h.system.close(other) }),
      ("a docked window closes", { h.system.close(browser) }),
      ("its title changes", { h.system.setTitle(note, "Another note") }),
    ]
    for (name, event) in events {
      event()
      settle(h)
      #expect(h.frame(note) == view(h), "\(name)")
      #expect(h.controller.isFilled(note), "\(name)")
      #expect(!touched(h).contains(note), "\(name): it is there, and is not asked again")
      expectWindowsMatchLayout(h)
    }
  }

  @Test func itStaysFilledWhereverTheViewGoesAndWhateverIsArranged() {
    let (h, editor, browser, note, other) = desk()
    h.press("zoom")
    h.system.clearFrameLog()
    let journey = [
      "zoom \(editor.rawValue)", "neighbor right", "out", "desktop", "back", "forward", "out", "in", "relayout",
      "swap \(editor.rawValue) right", "dock \(other.rawValue) right", "float \(other.rawValue)", "equalize", "resize \(editor.rawValue) right 40",
      "zoom \(browser.rawValue)", "out",
    ]
    for step in journey {
      h.run(step)
      settle(h)
      #expect(h.frame(note) == view(h), "\(step)")
      #expect(h.controller.isFilled(note) && !h.controller.parked.contains(note), "\(step)")
      #expect(!touched(h).contains(note), "\(step)")
      expectWindowsMatchLayout(h)
    }
  }

  /// Rule 4, and the controller's own: a command that moves the view says where the attention goes.
  @Test func whenTheViewMovesTheKeyboardAndTheFrontGoToWhatArrives() {
    let (h, editor, browser, note, _) = desk()
    h.press("zoom")
    for (step, arrives) in [("zoom \(editor.rawValue)", editor), ("neighbor right", nil), ("neighbor right", browser), ("back", nil)] {
      h.press(step)
      settle(h)
      #expect(h.system.focusedWindow() != note, "\(step)")
      if let arrives {
        #expect(h.system.focusedWindow() == arrives, "\(step)")
        #expect(h.system.windowsFrontToBack().first == arrives, "\(step): it is not behind what fills the view")
      }
      #expect(h.frame(note) == view(h) && h.controller.isFilled(note), "\(step)")
    }
  }

  /// For a docked window ⌃⌥↩ and then ⌃⌥Space is "everything is back". The same keys, the same for every window.
  @Test func showEverythingMeansEverything() {
    for command in ["show-all", "home"] {
      let (h, editor, browser, note, other) = desk()
      let (had, before) = (h.workspace.floating[note], [editor, browser, other].map { h.frame($0) })
      h.press("zoom")
      h.system.clearFrameLog()
      #expect(h.press(command).ok)
      #expect(h.frame(note) == had && !h.controller.isFilled(note), "\(command)")
      #expect(touched(h) == [note] && [editor, browser, other].map { h.frame($0) } == before, "\(command)")
      #expect(h.controller.nextStepTitle(.undo) == "Own Size")
      #expect(h.press("undo").ok)
      #expect(h.frame(note) == view(h), "\(command)")
      expectWindowsMatchLayout(h)
    }
  }

  @Test func minimizedAndBackItStillFills() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.setMinimized(note, true)
    settle(h)
    h.system.setMinimized(note, false)
    settle(h)
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  @Test func theViewChangesItsShapeAndTheWindowFollows() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    // The Dock comes up on the left.
    var display = FakeWindowSystem.standardDisplay
    display.visibleFrame.origin.x += 80
    display.visibleFrame.size.width -= 80
    h.system.setDisplays([display])
    settle(h)
    h.scheduler.advance(by: 5)
    #expect(h.frame(note) == view(h, display))
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  @Test func anAppThatRoundsItsSizeALittleLaterHasNotTakenItInHand() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    // A terminal says late that it holds whole lines only.
    var rounded = view(h)
    rounded.size.height -= 9
    rounded.size.width -= 5
    h.system.userMove(note, to: rounded)
    settle(h)
    #expect(h.controller.isFilled(note))
    #expect(h.workspace.floating[note] == own)
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  // MARK: 3. The person's hand

  @Test func aSizeGivenByHandIsItsOwnFromThenOn() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    let byHand = CGRect(x: 12, y: 37, width: 900, height: 600)
    h.system.clearFrameLog()
    h.system.userResize(note, to: byHand)
    settle(h)
    #expect(h.frame(note) == byHand && touched(h).isEmpty, "a hand set outranks every debt Arbor remembers")
    #expect(!h.controller.isFilled(note))
    #expect(h.workspace.floating[note] == byHand)
    // The key starts afresh from there.
    h.press("zoom")
    #expect(h.frame(note) == view(h))
    h.press("zoom")
    #expect(h.frame(note) == byHand)
  }

  /// A point at a time, each report is as good as the size of the one before. It is the size the fill left that counts.
  @Test(arguments: ["bottom", "top"]) func anEdgeDraggedSlowlyIsASizeGivenByHandToo(edge: String) {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    h.system.mouseDown = true
    var byHand = view(h)
    for _ in 1...60 {
      byHand.size.height -= 1
      if edge == "top" { byHand.origin.y += 1 }
      h.system.userResize(note, to: byHand)
      h.scheduler.advance(by: 0.02)
    }
    h.system.releaseMouse()
    settle(h)
    #expect(h.frame(note) == byHand && touched(h).isEmpty)
    #expect(!h.controller.isFilled(note))
    // (What is remembered of it from the third point on is `frameToRemember`'s to say, as of any floating window made smaller that
    // slowly: it takes each report for a move. The same without a fill.)
    #expect(h.workspace.floating[note]?.width == byHand.width)
  }

  @Test func draggedByItsTitleBarItComesOutInItsOwnSizeWhereItIsLetGo() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    let mark = h.system.moveLog.count
    h.system.beginDrag(note)
    #expect(touched(h).isEmpty, "nothing happens to a window in the hand")
    h.system.moveDrag(to: CGPoint(x: 600, y: 300))
    #expect(touched(h).isEmpty)
    h.system.endDrag()
    settle(h)
    let frame = h.frame(note)!
    #expect(frame.size == own.size, "the fill's size is Arbor's: whoever nudges a filled window has not lost its size")
    #expect(frame.minX < 600 && frame.maxX > 600 && frame.minY <= 300 && frame.minY > 300 - 60, "the pointer is still on its title bar")
    #expect(!h.controller.isFilled(note) && h.workspace.isFloating(note))
    #expect(h.workspace.floating[note] == frame)
    #expect(touched(h) == [note], "\(other) is not touched")
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1, "one resize at the release")
    // The key fills again, and gives back the frame of the drop.
    h.press("zoom")
    h.press("zoom")
    #expect(h.frame(note) == frame)
    expectWindowsMatchLayout(h)
  }

  @Test func afterASlipOfTheHandItGoesOnFilling() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.beginDrag(note)
    let hold = h.system.cursorLocation()
    h.system.moveDrag(to: CGPoint(x: hold.x + 15, y: hold.y + 10))
    h.system.endDrag()
    settle(h)
    #expect(h.frame(note) == view(h))
    #expect(h.controller.isFilled(note) && h.workspace.floating[note] == own)
    // 24 points are a drag.
    h.system.beginDrag(note)
    h.system.moveDrag(to: CGPoint(x: hold.x + 24, y: hold.y))
    h.system.endDrag()
    settle(h)
    #expect(!h.controller.isFilled(note) && h.frame(note)?.size == own.size)
  }

  /// macOS does not always take a window that is let go where it tiles. "A plain drag means out, wherever it ends: macOS takes the window, or
  /// it floats at its own size where it lies" (QUESTIONS Q29).
  @Test func thrownIntoTheMenuBarAndNotTakenByMacOSItHasItsOwnSizeWhereItLies() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.tiling = .on
    h.system.drag(note, through: [CGPoint(x: 720, y: 47), CGPoint(x: 710, y: 24), CGPoint(x: 700, y: 1)], holding: 0)
    #expect(h.frame(note)?.size == view(h).size, "or this proves nothing: Arbor stood aside, and macOS did not take it")
    #expect(h.workspace.floating[note]?.size == own.size, "the fill's size is not written down as its own")
    settle(h)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note))
    #expect(h.frame(note)!.minY >= h.system.displayList[0].visibleFrame.minY, "its title bar is not under the menu bar")
    h.controller.shutdown()
    #expect(h.frame(note)?.size == own.size)
  }

  @Test func letGoWhereLessThanHalfWouldShowItIsPulledIntoView() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.beginDrag(note)
    h.system.moveDrag(to: CGPoint(x: 1438, y: 880))
    h.system.endDrag()
    settle(h)
    let frame = h.frame(note)!
    #expect(frame.size == own.size)
    #expect(frame.fractionInside(h.system.displayList[0].frame) >= 0.5)
  }

  /// macOS's Window ▸ Center, its keys, every other window tool move a window at its size with no button down, at a person's asking.
  /// Arbor reverses nothing (docs/VIABLE.md, section 6), and does not take the fill's size for the window's own either.
  @Test func movedAtItsSizeWithNoButtonDownItIsLetBeAndKeepsTheMark() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    let put = view(h).offsetBy(dx: 200, dy: 100)
    h.system.userMove(note, to: put)
    settle(h)
    // Layouts come by.
    h.run("dock \(other.rawValue) left")
    h.system.close(h.system.open(app: "Preview", pid: 1009))
    h.system.userFocus(note)
    h.scheduler.advance(by: 5)
    #expect(h.frame(note) == put && !touched(h).contains(note), "it stays where it was put, at the size it has")
    #expect(h.controller.isFilled(note) && h.workspace.floating[note] == own)
    h.press("zoom")
    #expect(h.frame(note) == own, "and the key gives its own frame back as ever")
  }

  @Test func letBeItStillGetsItsOwnFrameFromEveryWayOut() {
    for way in ["show-all", "pause", "float-all", "quit", "drag"] {
      let (h, note, _) = newcomer()
      h.press("zoom")
      h.system.userMove(note, to: view(h).offsetBy(dx: 200, dy: 100))
      settle(h)
      switch way {
      case "quit": h.controller.shutdown()
      case "drag": h.system.drag(note, through: [CGPoint(x: 900, y: 147), CGPoint(x: 700, y: 400)])
      default: h.run(way)
      }
      settle(h)
      #expect(h.frame(note)?.size == own.size, "\(way)")
      if way != "drag" { #expect(h.frame(note) == own, "\(way)") }
    }
  }

  @Test func sentToTheOtherDisplayAtItsSizeItKeepsTheMarkItsPinAndItsOwnFrame() {
    let (h, note, _) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    h.run("pin \(note.rawValue)")
    h.press("zoom")
    let put = CGRect(x: 1450, y: 10, width: view(h).width, height: view(h).height)
    h.system.userMove(note, to: put)
    settle(h)
    #expect(h.frame(note) == put)
    #expect(h.controller.workspaceID(containing: note) == side.id && h.controller.isFilled(note) && h.controller.isPinned(note))
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note)?.size == own.size && side.frame.contains(h.frame(note)!))
  }

  @Test func carriedToTheOtherDisplayWithTheButtonDownAPinnedOneKeepsItsPin() {
    let (h, note, _) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    h.run("pin \(note.rawValue)")
    h.press("zoom")
    h.system.mouseDown = true
    h.system.userMove(note, to: view(h).offsetBy(dx: 1500, dy: 20))
    h.system.releaseMouse()
    settle(h)
    #expect(!h.controller.isFilled(note) && h.frame(note)?.size == own.size)
    #expect(h.controller.workspaceID(containing: note) == side.id && h.controller.isPinned(note))
  }

  @Test func whileTheButtonIsDownNothingIsDoneToIt() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    h.system.mouseDown = true
    for step in 1...5 {
      h.system.userMove(note, to: view(h).offsetBy(dx: CGFloat(step) * 40, dy: 0))
      h.scheduler.advance(by: 0.3)
      // A layout comes by meanwhile.
      h.run("relayout")
      #expect(touched(h).isEmpty, "step \(step)")
    }
    h.system.releaseMouse()
    settle(h)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note))
  }

  // MARK: 4. Apps that will not grow that far

  /// In view nobody is asked to grow where it stands (a Mac clips the answer there). So the first time such an app is met it goes by way of
  /// the view's corner, inside the view; from then on straight to the middle.
  @Test func anAppThatWillNotGrowThatFarGoesAsFarAsItCanInTheMiddle() {
    let (h, note, _) = newcomer()
    h.system.setMaximumSize(note, CGSize(width: 900, height: 600))
    var mark = h.system.moveLog.count
    let reply = h.press("zoom")
    #expect(reply.ok && reply.message == "\(note) goes no larger than 900×600")
    let frame = h.frame(note)!
    #expect(frame.size == CGSize(width: 900, height: 600))
    #expect(abs(frame.midX - view(h).midX) <= 1 && abs(frame.midY - view(h).midY) <= 1)
    #expect(h.system.road(of: note, since: mark).dropFirst().allSatisfy { view(h).contains($0) }, "never outside the view on its way")
    #expect(h.overlays.headsUp[h.display]?.line == "Notes goes no larger")
    // It stays, and is not asked again at every layout.
    h.system.clearFrameLog()
    h.system.close(h.system.open(app: "Preview", pid: 1009))
    settle(h)
    #expect(h.frame(note) == frame && !touched(h).contains(note))
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == own)
    // Known by now: one move.
    mark = h.system.moveLog.count
    h.press("zoom")
    #expect(h.frame(note) == frame)
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1)
    #expect(FakeWindowSystem.detour(h.system.road(of: note, since: mark)) == nil)
  }

  @Test func aTerminalThatMerelyRoundsIsNotSaidToGoNoLarger() {
    let (h, note, _) = newcomer()
    h.system.setSizeStep(note, CGSize(width: 7, height: 15))
    let reply = h.press("zoom")
    #expect(reply.message == "filled the screen with \(note)")
    #expect(h.overlays.headsUp.isEmpty)
    #expect(h.frame(note)!.width > view(h).width - 7 && h.frame(note)!.height > view(h).height - 15)
  }

  @Test func arborSaysSoOncePerWindow() {
    let (h, note, _) = newcomer()
    h.system.setMaximumSize(note, CGSize(width: 900, height: 600))
    h.press("zoom")
    #expect(h.overlays.headsUp[h.display] != nil)
    h.press("zoom")
    #expect(h.overlays.headsUp[h.display] == nil)
    h.press("zoom")
    #expect(h.overlays.headsUp[h.display] == nil, "it has been said")
  }

  @Test func whatAScriptMetIsNotToldToWhoeverPressesTheNextKey() {
    let (h, note, other) = newcomer()
    h.system.setMaximumSize(note, CGSize(width: 900, height: 600))
    h.run("zoom \(note.rawValue)")
    #expect(h.overlays.headsUp.isEmpty)
    h.system.userFocus(other)
    h.press("zoom")
    #expect(h.overlays.headsUp.isEmpty)
  }

  @Test func aWindowOfAFixedSizeGoesToTheMiddleAndBack() {
    let h = Harness()
    let settings = h.system.open(
      app: "System Settings", pid: 1001, frame: CGRect(x: 100, y: 100, width: 715, height: 600), isResizable: false)
    h.start()
    h.system.userFocus(settings)
    let mark = h.system.moveLog.count
    h.press("zoom")
    let frame = h.frame(settings)!
    #expect(frame.size == CGSize(width: 715, height: 600))
    #expect(abs(frame.midX - view(h).midX) <= 1 && abs(frame.midY - view(h).midY) <= 1)
    #expect(movesWithoutWaste(h, of: settings, since: mark) == 1)
    h.press("zoom")
    #expect(h.frame(settings) == CGRect(x: 100, y: 100, width: 715, height: 600))
  }

  // MARK: 5. Arbor lets go

  @Test func quitGivesTheOwnFrameBackAndALaunchFillsNothing() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(h.frame(note) == own)
    #expect(touched(h) == [note], "\(other) is not touched")
    #expect(h.store.saved?.workspaces[h.display]?.filled == nil)
    let next = h.newProcess()
    next.start()
    settle(next)
    #expect(next.frame(note) == own && !next.controller.isFilled(note))
  }

  @Test func aPauseGivesTheOwnFrameBackAndAResumeFillsAgain() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    let elsewhere = h.frame(other)
    h.run("pause")
    #expect(h.frame(note) == own)
    let mark = h.system.moveLog.count
    h.run("resume")
    settle(h)
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1)
    #expect(h.frame(other) == elsewhere)
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  @Test func movedDuringThePauseItIsWhereItsPersonWantsIt() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.run("pause")
    let byHand = CGRect(x: 300, y: 200, width: 500, height: 400)
    h.system.userMove(note, to: byHand)
    h.run("resume")
    settle(h)
    #expect(h.frame(note) == byHand && !h.controller.isFilled(note))
  }

  @Test func afterAnAccidentTheKeyStillGivesTheOwnFrameBack() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.scheduler.advance(by: 2)  // saved
    let next = h.newProcess(byTheWatchdog: true)
    next.start()
    settle(next)
    #expect(next.frame(note) == view(h) && next.controller.isFilled(note), "it is as it was left, and known to be")
    next.system.userFocus(note)
    next.press("zoom")
    #expect(next.frame(note) == own)
  }

  /// What is known about an app's sizes dies with the process. Where the fill left the window is written down.
  @Test func afterAnAccidentAFillThatStoppedShortIsStillKnown() {
    let (h, note, _) = newcomer()
    h.system.setMaximumSize(note, CGSize(width: 800, height: 600))
    h.press("zoom")
    let short = h.frame(note)
    h.scheduler.advance(by: 2)
    let next = h.newProcess(byTheWatchdog: true)
    next.start()
    settle(next)
    #expect(next.frame(note) == short && next.controller.isFilled(note))
    next.system.userFocus(note)
    next.press("zoom")
    #expect(next.frame(note) == own)
  }

  @Test func movedWhileArborWasGoneItNoLongerFillsAndItsOwnFrameIsStillItsOwn() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.scheduler.advance(by: 2)
    h.system.events = nil
    h.system.userMove(note, to: view(h).offsetBy(dx: 300, dy: 150))
    let next = h.newProcess(byTheWatchdog: true)
    next.start()
    settle(next)
    #expect(!next.controller.isFilled(note))
    next.system.userFocus(note)
    next.press("zoom")
    #expect(next.frame(note) == view(h))
    next.press("zoom")
    #expect(next.frame(note) == own, "not the fill's size somewhere else")
  }

  // MARK: 5b. An app that does not answer

  @Test func anAppThatHangsOnTheWayBackLeavesTheKeyAlive() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.setUnresponsive(pid: 1001, true)
    let reply = h.press("zoom")
    #expect(!reply.ok, "\(reply.message)")
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note), "the mark goes when the window is really back")
    h.system.setUnresponsive(pid: 1001, false)
    settle(h)
    #expect(h.press("zoom").ok)
    #expect(h.frame(note) == own && !h.controller.isFilled(note))
  }

  @Test func anAppThatHangsAtQuitIsStillKnownToFillInTheNextRun() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.setUnresponsive(pid: 1001, true)
    h.controller.shutdown()
    #expect(h.frame(note) == view(h))
    h.system.setUnresponsive(pid: 1001, false)
    let next = h.newProcess()
    next.start()
    settle(next)
    #expect(next.controller.isFilled(note))
    next.system.userFocus(note)
    next.press("zoom")
    #expect(next.frame(note) == own)
  }

  @Test func anAppThatHangsAtTheFillIsFilledWhenItAnswers() {
    let (h, note, _) = newcomer()
    h.system.setUnresponsive(pid: 1001, true)
    h.press("zoom")
    #expect(h.frame(note) == own && h.controller.isFilled(note))
    h.system.setUnresponsive(pid: 1001, false)
    h.system.setTitle(note, "It answers")
    settle(h)
    #expect(h.frame(note) == view(h))
  }

  @Test func floatAllGivesTheOwnFrameBackAlsoWhereNothingIsDocked() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    #expect(h.run("float-all").ok)
    #expect(h.frame(note) == own && !h.controller.isFilled(note))

    let (d, _, _, floating, _) = desk()
    let had = d.workspace.floating[floating]
    d.press("zoom")
    d.run("float-all")
    #expect(d.frame(floating) == had && !d.controller.isFilled(floating))
  }

  @Test func anAppThatArborNoLongerArrangesHasItsWindowBack() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.run("exclude")
    #expect(h.frame(note) == own && !h.controller.isFilled(note))
  }

  // MARK: 6. Undo

  @Test func undoTakesTheFillBackAndRedoFillsAgain() {
    let (h, editor, browser, note, other) = desk()
    let had = h.frame(note)
    let before = [editor, browser, other].map { h.frame($0) }
    h.press("zoom")
    h.system.clearFrameLog()
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == had && !h.controller.isFilled(note))
    #expect(touched(h) == [note])
    #expect(h.press("redo").ok)
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    #expect(touched(h) == [note])
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == had)
    #expect([editor, browser, other].map { h.frame($0) } == before)
    expectWindowsMatchLayout(h)
  }

  /// Found by the review: no branch of the plan applied, the mark went, the window stayed as large, and the key was dead.
  @Test func undoAndRedoWorkWithTheDesktopOutOfView() {
    let (h, editor, _, note, _) = desk()
    let had = h.workspace.floating[note]
    h.press("zoom")
    h.run("zoom \(editor.rawValue)")
    h.system.userFocus(note)
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == had && !h.controller.isFilled(note))
    #expect(h.press("redo").ok)
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    h.press("zoom")
    #expect(h.frame(note) == had)
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == view(h))
    #expect(h.press("redo").ok)
    #expect(h.frame(note) == had && !h.controller.isFilled(note))
  }

  @Test func redoneAfterAHandMovedItTheKeyGivesBackWhatTheHandMade() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.press("undo")
    let byHand = CGRect(x: 50, y: 60, width: 700, height: 500)
    h.system.userMove(note, to: byHand)
    h.press("redo")
    #expect(h.frame(note) == view(h))
    h.press("zoom")
    #expect(h.frame(note) == byHand)
  }

  @Test func undoAfterTheKeyWentBackFillsAgain() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.press("zoom")
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    #expect(h.press("undo").ok)
    #expect(h.frame(note) == own && !h.controller.isFilled(note))
  }

  @Test func undoDoesNotFillAWindowThatAHandHasSizedSince() {
    let (h, editor, _, note, _) = desk()
    h.press("zoom")
    h.run("swap \(editor.rawValue) right")
    let byHand = CGRect(x: 100, y: 100, width: 700, height: 500)
    h.system.userResize(note, to: byHand)
    settle(h)
    h.run("undo")
    #expect(h.frame(note) == byHand && !h.controller.isFilled(note))
  }

  // MARK: 7. Other kinds of windows, other displays

  @Test func dockedAfterwardsItFloatsAgainInItsOwnSize() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.press("dock left")
    #expect(h.workspace.isDocked(note) && !h.controller.isFilled(note))
    h.press("float")
    #expect(h.frame(note)?.size == own.size)
  }

  @Test func onTwoDisplaysItFillsTheOneItIsOn() {
    let (h, note, other) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    let there = CGRect(x: 1600, y: 100, width: 500, height: 400)
    h.system.userMove(note, to: there)
    settle(h)
    h.system.clearFrameLog()
    h.press("zoom")
    #expect(h.frame(note) == view(h, side))
    #expect(touched(h) == [note], "\(other) is not touched")
    h.press("zoom")
    #expect(h.frame(note) == there)
  }

  @Test func sentToTheOtherDisplayItArrivesInItsOwnSize() {
    let (h, note, _) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    h.press("zoom")
    h.press("move-to-display next")
    settle(h)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note))
    #expect(side.frame.contains(h.frame(note)!))
  }

  @Test func itsDisplayGoesAndItIsInItsOwnSizeOnTheOther() {
    let (h, note, _) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.userMove(note, to: CGRect(x: 1600, y: 100, width: 500, height: 400))
    settle(h)
    h.press("zoom")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 5)
    #expect(h.frame(note)?.size == CGSize(width: 500, height: 400))
    #expect(FakeWindowSystem.standardDisplay.frame.contains(h.frame(note)!))
  }

  @Test func aPinnedWindowFillsTooAndStaysPinned() {
    let (h, editor, _, note, _) = desk()
    h.run("pin \(note.rawValue)")
    let had = h.frame(note)
    #expect(h.press("zoom").ok)
    #expect(h.frame(note) == view(h) && h.controller.isPinned(note))
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(note) == view(h))
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == had && h.controller.isPinned(note))
  }

  /// A pin is raised again when it is covered. One that fills the view would cover whatever its person switches to.
  @Test func aPinnedWindowThatFillsIsNotRaisedOverWhatIsSwitchedTo() {
    let (h, note, other) = newcomer()
    h.run("pin \(note.rawValue)")
    h.press("zoom")
    h.system.userFocus(other)
    h.scheduler.advance(by: 2)
    #expect(h.system.focusedWindow() == other && h.system.windowsFrontToBack().first == other)
    // In its own size it is a pin like any other again.
    h.system.userFocus(note)
    h.press("zoom")
    h.system.userFocus(other)
    h.scheduler.advance(by: 2)
    #expect(h.frame(note) == own)
  }

  @Test func pinnedWhileItFillsItsOwnFrameIsStillItsOwn() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    #expect(h.run("pin \(note.rawValue)").ok)
    #expect(h.frame(note) == view(h) && h.workspace.floating[note] == own, "where it is pinned is not all of the view")
    h.press("zoom")
    #expect(h.frame(note) == own && h.controller.isPinned(note))
  }

  /// Found by a walk with every switch on: it was taken for a window stretched over the Desktop (F18), made its own size, and filled again.
  @Test func withTheDesktopTakenByAWindowAloneAFilledOneIsStillMovedOnce() {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    settings.floatingWindowsMakeWay = true
    let h = Harness(settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let note = h.system.open(app: "Notes", pid: 1002)
    h.start()
    h.system.userMove(note, to: own)
    h.run("dock \(editor.rawValue) left")
    h.system.userFocus(note)
    settle(h)
    let stretched = h.frame(note)
    #expect(stretched != own, "alone on the Desktop, it has all of it")
    h.press("zoom")
    #expect(h.frame(note) == view(h))
    h.system.clearFrameLog()
    #expect(h.run("pin \(note.rawValue)").ok)
    #expect(touched(h).isEmpty && h.frame(note) == view(h))
    h.run("unpin \(note.rawValue)")
    // Dragged out, one resize.
    let mark = h.system.moveLog.count
    h.system.drag(note, through: [CGPoint(x: 720, y: 47), CGPoint(x: 900, y: 300)])
    settle(h)
    #expect(h.frame(note)?.size == own.size)
    #expect(movesWithoutWaste(h, of: note, since: mark) == 1)
  }

  @Test func summonedWhileItFillsItComesInItsOwnSize() {
    let (h, note, other) = newcomer()
    h.press("zoom")
    h.system.userFocus(other)
    #expect(h.run("summon Notes").ok)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note))
  }

  @Test func anotherTabOfTheSameWindowGoesOnFilling() throws {
    let (h, note, _) = newcomer()
    h.press("zoom")
    let tab = try #require(h.system.openTab(in: note))
    settle(h)
    #expect(h.controller.isFilled(tab) && h.frame(tab) == view(h))
    #expect(h.workspace.floating[tab] == own)
    h.press("zoom")
    #expect(h.frame(tab) == own)
  }

  @Test func aSizeAskedForWithAKeyIsItsOwnToo() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    #expect(h.press("shrink 100").ok)
    let shrunk = h.frame(note)!
    #expect(shrunk.width < view(h).width && !h.controller.isFilled(note))
    h.run("relayout")
    settle(h)
    #expect(h.frame(note) == shrunk && h.workspace.floating[note] == shrunk)
  }

  @Test func aWindowInTheHandIsNotTakenOutOfIt() {
    let (h, note, _) = newcomer()
    h.system.beginDrag(note)
    h.system.moveDrag(to: CGPoint(x: 700, y: 400))
    h.system.clearFrameLog()
    #expect(!h.run("zoom \(note.rawValue)").ok)
    #expect(touched(h).isEmpty && !h.controller.isFilled(note))
    h.system.endDrag()
    #expect(h.frame(note)?.size == own.size)
  }

  @Test func theKeyPressedWhileAFilledWindowIsDraggedGivesItItsSizeAtTheDrop() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.beginDrag(note)
    h.system.moveDrag(to: CGPoint(x: 700, y: 400))
    h.system.clearFrameLog()
    #expect(h.press("zoom").ok)
    #expect(touched(h).isEmpty, "it stays in the hand")
    h.system.endDrag()
    settle(h)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note))
  }

  @Test func filledOnADisplayThatIsAwayAtQuitItIsNotFilledInTheNextRun() {
    let (h, note, _) = newcomer(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.userMove(note, to: CGRect(x: 1600, y: 100, width: 500, height: 400))
    settle(h)
    h.press("zoom")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 5)
    h.controller.shutdown()
    #expect(h.store.saved?.dormant.values.allSatisfy { $0.workspace.filled == nil } == true)
    #expect(h.store.saved?.workspaces.values.allSatisfy { $0.filled == nil } == true)
  }

  @Test func undoCallsItByItsName() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    #expect(h.controller.nextStepTitle(.undo) == "Fill the Screen")
    #expect(h.controller.nextStepLabel(.undo) == "fill the screen with \(note)")
    h.press("zoom")
    #expect(h.controller.nextStepTitle(.undo) == "Own Size")
  }

  @Test func alreadyAsLargeBySomebodyElsesDoingNothingIsMovedAndNothingRemembered() {
    let (h, note, _) = newcomer()
    // macOS's own fill: the whole visible frame.
    h.system.userMove(note, to: h.visibleFrame)
    settle(h)
    h.system.clearFrameLog()
    let reply = h.press("zoom")
    #expect(reply.ok && reply.message == "\(note) fills the screen already")
    #expect(touched(h).isEmpty && !h.controller.isFilled(note))
    #expect(h.frame(note) == h.visibleFrame)
  }

  @Test func inFullScreenItIsRefusedAsEver() {
    let (h, note, _) = newcomer()
    h.system.setFullScreen(note, true)
    settle(h)
    #expect(!h.press("zoom").ok)
    #expect(!h.controller.isFilled(note))
  }

  @Test func aDockedWindowIsFramedAsEver() {
    let (h, editor, _, _, _) = desk()
    h.system.userFocus(editor)
    #expect(h.press("zoom").message == "framed \(editor)")
    #expect(h.frame(editor) == view(h) && !h.controller.isFilled(editor))
    h.press("zoom")
    #expect(h.workspace.camera == h.workspace.tree.root)
  }

  // MARK: 8. What is said

  @Test func theMenusRowIsThereForAFloatingWindowAndTickedWhileItFills() throws {
    let (h, _, _) = newcomer()
    var row = try #require(h.controller.menuModel().item("Frame Focused Window"))
    #expect(row.isEnabled && !row.isTicked)
    h.press("zoom")
    row = try #require(h.controller.menuModel().item("Frame Focused Window"))
    #expect(row.isEnabled && row.isTicked)
  }

  @Test func stateSaysWhoFills() throws {
    let (h, note, other) = newcomer()
    h.press("zoom")
    let windows = try #require(h.run("state").state?.windows)
    #expect(windows.first { $0.id == note }?.filled == true)
    #expect(windows.first { $0.id == other }?.filled == false)
  }

  @Test func nothingIsSaidOnScreenOfAFillThatWorked() {
    let (h, _, _) = newcomer()
    h.press("zoom")
    #expect(h.overlays.headsUp.isEmpty, "the window says it")
    h.press("zoom")
    #expect(h.overlays.headsUp.isEmpty)
  }

  // MARK: What a second reader found by running it

  /// The real key can be held to peek, and then comes by another road than the command (Controller+Peek.swift).
  @Test(arguments: [false, true]) func theRealKeyForShowEverythingEndsTheFillToo(held: Bool) {
    let (h, editor, _, note, _) = desk()
    let was = h.frame(note)
    h.key("ctrl+opt+return")
    #expect(h.controller.isFilled(note))
    h.system.clearFrameLog()
    h.keyDown("ctrl+opt+space")
    if held { h.scheduler.advance(by: 1) }
    h.keyUp("ctrl+opt+space")
    settle(h)
    #expect(!h.controller.isFilled(note) && h.frame(note) == was)
    #expect(h.system.frameLog.filter { $0.window == note }.count == 1, "in one move")
    #expect(h.workspace.camera == h.workspace.tree.root && h.system.isVisible(editor))
    #expect(h.run("undo").ok && h.controller.isFilled(note), "and it is a step like the command's")
  }

  /// Who has the keyboard after a person's own ⌘W or ⌘M is not for the fill to say: the view has not moved, so nothing has arrived. (It
  /// went to a bystander, which was raised over the window that fills the view.)
  @Test(arguments: ["close", "minimize"]) func whatLayOverItGoesAndTheKeyboardIsWhereItWouldBeWithoutAFill(going: String) {
    func play(filling: Bool) -> (keyboardInTheNote: Bool, keyboardInTheBystander: Bool, raises: Int) {
      let (h, note, other) = newcomer()
      if filling { h.press("zoom") }
      let third = h.system.open(app: "Third", pid: 1003, frame: CGRect(x: 300, y: 300, width: 300, height: 200))
      h.system.userFocus(third)
      settle(h)
      let raised = h.system.raiseLog.filter { $0 == other }.count
      if going == "close" { h.system.close(third) } else { h.system.setMinimized(third, true) }
      settle(h)
      return (h.system.focused == note, h.system.focused == other, h.system.raiseLog.filter { $0 == other }.count - raised)
    }
    #expect(play(filling: true) == play(filling: false))
    #expect(!play(filling: true).keyboardInTheBystander && play(filling: true).raises == 0)
  }

  @Test func theViewMovesToWhereNothingArrivesAndTheKeyboardIsInWhatFillsIt() {
    let (h, editor, _, note, other) = desk()
    h.system.close(other)
    h.press("zoom")
    h.system.userFocus(editor)
    h.press("zoom")
    #expect(h.system.focused == editor)
    h.press("desktop")
    settle(h)
    #expect(!h.system.isVisible(editor))
    #expect(h.system.focused == note, "not in a window that is out of view")
  }

  @Test func undoWhileItsAppHangsLeavesTheKeyAlive() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.setUnresponsive(pid: 1001, true)
    #expect(!h.run("undo").ok, "nothing has come of it, and it says so")
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note), "the mark goes when the window is really back")
    #expect(!h.run("redo").ok)
    h.system.setUnresponsive(pid: 1001, false)
    settle(h)
    #expect(h.run("undo").ok, "the step is still there")
    #expect(h.frame(note) == own && !h.controller.isFilled(note))
  }

  /// Without the fill the change of the display would have fitted it at once.
  @Test func theDisplayShrinksWhileItFillsAndItsOwnFrameIsFittedOnTheWayBack() {
    let (h, note, _) = newcomer()
    h.system.userMove(note, to: CGRect(x: 780, y: 440, width: 640, height: 420))
    settle(h)
    h.press("zoom")
    var display = FakeWindowSystem.standardDisplay
    display.frame.size = CGSize(width: 900, height: 600)
    display.visibleFrame = CGRect(x: 0, y: 25, width: 900, height: 575)
    h.system.setDisplays([display])
    h.scheduler.advance(by: 6)
    #expect(h.frame(note) == view(h, display))
    h.system.clearFrameLog()
    h.press("zoom")
    let back = h.frame(note)
    #expect(back == CGRect(x: 260, y: 180, width: 640, height: 420))
    h.run("relayout")
    settle(h)
    #expect(h.frame(note) == back && h.system.frameLog.filter { $0.window == note }.count == 1, "to where it ends up, at once")
  }

  @Test func showEverythingIsNotTickedOverAWindowThatHidesEverything() throws {
    let (h, _, _) = newcomer()
    #expect(try #require(h.controller.menuModel().item("Show Everything")).isTicked)
    h.press("zoom")
    #expect(try !#require(h.controller.menuModel().item("Show Everything")).isTicked)
    h.press("zoom")
    #expect(try #require(h.controller.menuModel().item("Show Everything")).isTicked)
  }

  @Test(arguments: ["zoom", "show-all"]) func aKeyPressedWhileItIsInAHandThatNoDragReportedTakesItOutOfNoHand(key: String) {
    let (h, note, _) = newcomer()
    h.press("zoom")
    h.system.mouseDown = true
    let carried = view(h).offsetBy(dx: 200, dy: 200)
    h.system.userMove(note, to: carried)
    h.system.clearFrameLog()
    h.press(key)
    #expect(h.frame(note) == carried && touched(h).isEmpty)
    h.system.releaseMouse()
    settle(h)
    #expect(h.frame(note)?.size == own.size && !h.controller.isFilled(note), "let go, it comes out as ever")
  }

  // MARK: What the walks found on the last build

  /// What Arbor gave up on while the window was docked is over when its person asks for something else.
  @Test func aWindowThatWasLetBeInItsSlotAfterADoubleClickFillsLikeAnyOther() {
    let (h, note, _) = newcomer()
    h.run("dock \(note.rawValue) right")
    settle(h)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    h.run("float \(note.rawValue)")
    settle(h)
    let floats = h.frame(note)
    h.system.userFocus(note)
    h.press("zoom")
    #expect(h.frame(note) == view(h) && h.controller.isFilled(note))
    h.press("zoom")
    #expect(h.frame(note) == floats)
  }

  /// A pinned window that is mostly beyond an edge is fetched by every layout (Controller+Pin.swift): not by way of there.
  @Test(arguments: ["zoom", "undo", "show-all"]) func aPinnedWindowGoesBackToWhereAPinIsKeptInOneMove(way: String) {
    let (h, note, _) = newcomer()
    h.run("pin \(note.rawValue)")
    h.system.beginDrag(note)
    h.system.moveDrag(to: CGPoint(x: 1300, y: 800))
    h.system.endDrag()
    settle(h)
    h.press("zoom")
    #expect(h.frame(note) == view(h))
    h.system.clearFrameLog()
    h.press(way)
    settle(h)
    #expect(h.system.frameLog.filter { $0.window == note }.count == 1, "\(h.system.frameLog)")
    #expect(h.frame(note)?.size == own.size && h.frame(note)!.fractionInside(h.system.displayList[0].frame) >= 0.5)
  }

  /// Found by `TransitionInvariantTests`, seed 1: moved after the stage had gone, it jumped behind the motion's back.
  @Test func theMotionThatShowsEverythingShowsItGoingBackToo() throws {
    let (h, editor, _, note, _) = desk(settings: Harness.settingsWhenNoneAreGiven.withMotion)
    let was = try #require(h.frame(note))
    h.press("zoom")
    h.system.userFocus(editor)
    h.press("zoom")
    h.overlays.clearTransitions()
    h.press("show-all")
    let motion = try #require(h.overlays.transitions.last)
    #expect(motion[note]?.from == view(h) && motion[note]?.to == was)
    #expect(h.frame(note) == was)
  }

  /// Found by the walks: it was taken for one that docked windows had pushed aside, sent to its own frame, and filled again.
  @Test func floatingWindowsNoLongerMakeWayAndWhatFillsTheViewIsLeftAlone() {
    var settings = Settings()
    settings.floatingWindowsMakeWay = true
    let (h, note, _) = newcomer(settings: settings)
    h.press("zoom")
    h.system.clearFrameLog()
    #expect(h.run("set floatingWindowsMakeWay false").ok)
    settle(h)
    #expect(touched(h).isEmpty && h.frame(note) == view(h) && h.controller.isFilled(note))
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  // MARK: macOS gives the fill's frame back

  /// Fills, and then two double-clicks on the title bar: macOS zooms the window, and gives it back what it had before its zoom.
  private func filledZoomedAndBack() -> (Harness, note: WindowID, other: WindowID) {
    let (h, note, other) = newcomer()
    h.press("zoom")
    settle(h)
    for _ in 1...2 {
      h.system.doubleClickTitleBar(of: note)
      settle(h)
    }
    h.system.clearFrameLog()
    return (h, note, other)
  }

  /// Found by a hunter's walk. What macOS had before its zoom was the fill's frame, and Arbor remembered it like any other: the window's own
  /// size was lost for good.
  @Test func whatMacOSGivesBackAfterItsOwnZoomIsTheFillAndNotTheWindowsOwnFrame() {
    let (h, note, _) = filledZoomedAndBack()
    #expect(h.frame(note) == view(h), "the story: macOS has put it where the fill had")
    #expect(h.controller.isFilled(note), "so it fills")
    #expect(h.workspace.floating[note] == own, "and has the frame to go back to that it had")
    #expect(touched(h).isEmpty, "nothing moves for that")
  }

  @Test(arguments: ["zoom", "show-all", "undo", "float-all", "pause", "quit"]) func afterMacOSsZoomAndBackEveryWayOutGivesTheOwnFrameBack(way: String) {
    let (h, note, other) = filledZoomedAndBack()
    let others = h.frame(other)
    if way == "quit" { h.controller.shutdown() } else { h.press(way) }
    settle(h)
    #expect(h.frame(note) == own, "\(way)")
    #expect(h.frame(other) == others)
    #expect(way == "pause" || !h.controller.isFilled(note), "\(way)")
  }

  /// By another road: macOS's own half, and its Return to Previous Size.
  @Test func whatMacOSGivesBackAfterItsOwnTileIsTheFillToo() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.askMacOS(for: .left, about: note)
    settle(h)
    #expect(!h.controller.isFilled(note), "the story: a size that its person asked macOS for is its own")
    h.system.userMove(note, to: view(h))
    settle(h)
    #expect(h.controller.isFilled(note) && h.workspace.floating[note] == own)
    h.press("zoom")
    #expect(h.frame(note) == own)
  }

  /// A terminal stops short of the view, at whole lines. Where the fill left it is what counts, not the view.
  @Test func aWindowThatStoppedShortIsKnownByWhereTheFillLeftIt() throws {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal", pid: 1003, frame: own)
    h.system.setMaximumSize(terminal, CGSize(width: 1000, height: 700))
    h.start()
    h.system.userFocus(terminal)
    h.press("zoom")
    settle(h)
    let left = try #require(h.frame(terminal))
    #expect(left.size == CGSize(width: 1000, height: 700))
    h.system.userMove(terminal, to: CGRect(x: 0, y: 25, width: 900, height: 600))
    settle(h)
    #expect(!h.controller.isFilled(terminal))
    h.system.userMove(terminal, to: left)
    settle(h)
    #expect(h.controller.isFilled(terminal) && h.workspace.floating[terminal] == own)
  }

  // The controls: what has not come back to where the fill had put it is the window's own, as ever.

  @Test func afterOneDoubleClickMacOSsZoomIsTheWindowsOwn() throws {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    let zoomed = try #require(h.frame(note))
    #expect(zoomed != view(h) && !h.controller.isFilled(note) && h.workspace.floating[note] == zoomed)
    h.controller.shutdown()
    #expect(h.frame(note) == zoomed)
  }

  /// But the key is never dead where Arbor knows the way back: whoever filled the screen with the key and presses it again means "back".
  @Test func afterOneDoubleClickTheKeyGivesTheOwnFrameBack() {
    let (h, note, other) = newcomer()
    let others = h.frame(other)
    h.press("zoom")
    settle(h)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    h.system.clearFrameLog()
    #expect(h.press("zoom").ok)
    settle(h)
    #expect(h.frame(note) == own && !h.controller.isFilled(note) && h.workspace.floating[note] == own)
    #expect(h.system.frameLog.filter { $0.window == note }.count == 1 && h.frame(other) == others, "in one move, and nothing else")
    // What was kept is spent: macOS's zoom of a window that Arbor never filled is its own, and the key says so.
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    let zoomed = h.frame(note)
    #expect(h.press("zoom").message.contains("fills the screen already") && h.frame(note) == zoomed)
  }

  /// Named, the command is idempotent, as for any window: a script that says `zoom 101` twice does not get the opposite.
  @Test func afterOneDoubleClickTheCommandWithTheWindowNamedLeavesIt() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    let zoomed = h.frame(note)
    #expect(h.run("zoom \(note.rawValue)").message.contains("fills the screen already") && h.frame(note) == zoomed)
  }

  @Test(arguments: ["show-all", "float-all", "pause"]) func afterOneDoubleClickWhatDoesNotNameTheWindowLeavesMacOSsZoom(way: String) {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    let zoomed = h.frame(note)
    h.press(way)
    settle(h)
    #expect(h.frame(note) == zoomed, "\(way)")
  }

  @Test func aFrameBesideWhereTheFillHadPutItIsTheWindowsOwn() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.askMacOS(for: .left, about: note)
    settle(h)
    let near = view(h).offsetBy(dx: 3, dy: 0)
    h.system.userMove(note, to: near)
    settle(h)
    #expect(!h.controller.isFilled(note) && h.workspace.floating[note] == near)
  }

  /// With the button down it is a hand that sizes it, and what a hand gives a window is its own.
  @Test func aHandThatSizesItToTheViewGivesItThatSize() {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.askMacOS(for: .left, about: note)
    settle(h)
    h.system.mouseDown = true
    h.system.userResize(note, to: view(h))
    #expect(!h.controller.isFilled(note))
    h.system.releaseMouse()
    settle(h)
    #expect(!h.controller.isFilled(note) && h.workspace.floating[note] == view(h))
  }

  /// A size that a hand gave it is its own: "back" after macOS's zoom is not to what it had before a fill of long ago.
  @Test(arguments: [true, false]) func aSizeGivenByHandEndsWhatIsKeptOfAFill(endsTheFill: Bool) throws {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    if !endsTheFill {
      h.system.askMacOS(for: .left, about: note)
      settle(h)
    }
    let byHand = CGRect(x: 100, y: 100, width: 800, height: 500)
    h.system.mouseDown = true
    h.system.userResize(note, to: byHand)
    h.system.releaseMouse()
    settle(h)
    #expect(!h.controller.isFilled(note) && h.workspace.floating[note] == byHand)
    h.system.doubleClickTitleBar(of: note)
    settle(h)
    let zoomed = try #require(h.frame(note))
    #expect(h.press("zoom").message.contains("fills the screen already") && h.frame(note) == zoomed, "Arbor knows no way back, and macOS does")
    h.system.userMove(note, to: view(h))
    settle(h)
    #expect(!h.controller.isFilled(note) && h.workspace.floating[note] == view(h))
  }

  /// What was kept of a fill is over with the next one, and when the window is docked.
  @Test(arguments: ["fill", "dock"]) func whatIsKeptOfAFillIsForgotten(by way: String) throws {
    let (h, note, _) = newcomer()
    h.press("zoom")
    settle(h)
    h.system.askMacOS(for: .left, about: note)
    settle(h)
    let half = try #require(h.frame(note))
    if way == "fill" {
      h.press("zoom")
      settle(h)
      h.system.askMacOS(for: .right, about: note)
      settle(h)
      h.system.userMove(note, to: view(h))
      settle(h)
      #expect(h.controller.isFilled(note) && h.workspace.floating[note] == half, "the frame it had before the last fill")
    } else {
      h.run("dock \(note.rawValue) left")
      settle(h)
      h.run("float \(note.rawValue)")
      settle(h)
      h.system.userMove(note, to: view(h))
      settle(h)
      #expect(!h.controller.isFilled(note) && h.workspace.floating[note] == view(h))
    }
  }
}
