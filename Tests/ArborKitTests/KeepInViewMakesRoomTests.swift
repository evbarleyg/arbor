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

/// Where the call sits in these tests: near the top right corner of the main display. Its cheapest strip is the one along the
/// right edge, 350 points of 1440.
private let corner = CGRect(x: 1090, y: 50, width: 320, height: 240)
/// What that leaves of the standard display's visible frame.
private let beside = CGRect(x: 0, y: 25, width: 1090, height: 875)
/// A place from which every strip costs more than four tenths.
private let middle = CGRect(x: 560, y: 330, width: 320, height: 240)

/// Keep in View makes room instead of fighting for the front (docs/features/F49-pin.md; collab/QUESTIONS.md Q25).
///
/// Seen on a hosted Mac: a pinned window of another app lay wholly behind the window that filled the screen, while the menu's tick
/// said "kept in view". macOS lets nobody lift another app's window over the one that has the keyboard, and the stand-in's `raise`
/// now stops there too, so what is green here is green for that reason.
@Suite @MainActor struct KeepInViewMakesRoomTests {
  /// [editor | Desktop | browser], and a video call that floats at `place`, each of an app of its own.
  func makeHarness(
    call place: CGRect = corner, pinned: Bool = true, displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
    settings: Settings = Settings()
  ) -> (Harness, editor: WindowID, browser: WindowID, call: WindowID) {
    let h = Harness(displays: displays, settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let call = h.system.open(app: "Zoom", title: "Meeting", pid: 1003, frame: place)
    h.start()
    // First, so that the docks do not push it onto the Desktop.
    h.run("pin \(call.rawValue)")
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    if !pinned { h.run("unpin \(call.rawValue)") }
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.clearRaiseLog()
    return (h, editor, browser, call)
  }

  /// Every frame Arbor has asked `window` to take since the log was last cleared.
  func moves(of window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// How often Arbor has moved `window` since then. A question put to it where it stood, before it went anywhere, is no move; nil if
  /// anything was done twice or for nothing.
  func moved(_ window: WindowID, _ h: Harness) -> Int? { movesWithoutWaste(h, of: window, since: h.system.movesWhenTheFrameLogWasCleared) }

  /// Whether another window lies over part of `window`, by the window server's order.
  func isCovered(_ window: WindowID, _ h: Harness) -> Bool {
    h.system.windowsFrontToBack().prefix { $0 != window }.contains { h.system.isVisible($0) && h.frame($0)!.overlaps(h.frame(window)!) }
  }

  /// Nothing the layout places lies under or over `window`: no docked window, no tile, nor the Desktop.
  func expectClear(_ window: WindowID, _ h: Harness, _ when: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
    guard let own = h.frame(window), let display = h.controller.workspaceID(containing: window),
      let layout = h.controller.layouts[display]
    else {
      Issue.record("\(window) is nowhere \(when)", sourceLocation: sourceLocation)
      return
    }
    for (docked, slot) in layout.windowFrames.sorted(by: { $0.key < $1.key }) {
      #expect(!slot.overlaps(own), "the slot of \(docked) \(when)", sourceLocation: sourceLocation)
      #expect(h.frame(docked)?.overlaps(own) == false, "\(docked) itself \(when)", sourceLocation: sourceLocation)
    }
    for tile in layout.tiles { #expect(!tile.frame.overlaps(own), "a tile \(when)", sourceLocation: sourceLocation) }
    #expect(layout.desktopFrame?.overlaps(own) != true, "the Desktop \(when)", sourceLocation: sourceLocation)
  }

  // MARK: Every view is laid out in what is left

  @Test func everyViewIsLaidOutBesideIt() {
    let (h, editor, browser, call) = makeHarness()
    let journey = [
      "zoom \(editor.rawValue)", "neighbor right", "neighbor right", "show-all", "desktop", "back", "forward", "out", "in", "home",
      "save-view 1", "zoom \(browser.rawValue)", "view 1", "arrange", "zoom \(editor.rawValue)", "show-all",
    ]
    for step in journey {
      #expect(h.run(step).ok, "\(step)")
      h.scheduler.advance(by: 1)
      expectClear(call, h, "after \(step)")
      #expect(h.layout?.frame == beside, "after \(step)")
      #expect(!isCovered(call, h), "after \(step)")
      expectWindowsMatchLayout(h)
    }
    #expect(h.frame(call) == corner && moves(of: call, h).isEmpty, "the window itself is never moved or sized")
    #expect(h.system.raiseLog.isEmpty, "and never raised: nothing has to be")
  }

  @Test func theWindowThatFillsTheScreenFillsWhatIsLeft() {
    // The very case seen on a Mac: another app's window has the keyboard and fills the screen.
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(editor)
    h.run("zoom")
    h.scheduler.advance(by: 1)
    #expect(h.frame(editor) == beside.insetBy(dx: 12, dy: 12))
    #expect(h.system.windowsFrontToBack().first == editor && h.system.focused == editor)
    #expect(!isCovered(call, h), "behind it in macOS's order, and all of it to be seen")
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == false)
  }

  @Test func whatArborDrawsBehindDockedWindowsEndsWhereTheRoomEnds() throws {
    let (h, _, _, call) = makeHarness()
    #expect(h.controller.snapshot().displays[0].room == beside)
    #expect(h.controller.snapshot().displays[0].visibleFrame == h.visibleFrame)
    let seams = try #require(h.overlays.seams[h.display])
    #expect(seams.count == 2)
    for seam in seams { #expect(beside.contains(seam.frame)) }
    let backdrop = try #require(h.overlays.scenes[h.display]?.backdrop)
    #expect(backdrop.frame == beside && !backdrop.rects.isEmpty)
    for rect in backdrop.rects { #expect(!rect.overlaps(h.frame(call)!)) }
    // The guard of the Desktop keeps the whole screen: there is wallpaper beside a call too.
    #expect(h.controller.desktopGuardZones().displays.allSatisfy { $0.view == h.visibleFrame })
  }

  @Test func withNothingKeptInViewTheWholeDisplayIsTheRoom() {
    let (h, editor, _, _) = makeHarness(pinned: false)
    #expect(h.layout?.frame == h.visibleFrame)
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(editor) == h.visibleFrame.insetBy(dx: 12, dy: 12))
  }

  @Test func withNothingDockedAPinMovesNothing() {
    // Nothing moves until the person docks something.
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001, frame: CGRect(x: 170, y: 216, width: 480, height: 348))
    let call = h.system.open(app: "Zoom", pid: 1003, frame: CGRect(x: 170, y: 216, width: 200, height: 150))
    h.start()
    h.system.userFocus(editor)
    h.system.clearFrameLog()
    #expect(h.run("pin \(call.rawValue)").ok)
    #expect(h.system.frameLog.isEmpty)
    #expect(h.system.raiseLog == [call], "the editor lies over it")
    #expect(h.run("unpin \(call.rawValue)").ok)
    #expect(h.system.frameLog.isEmpty)
  }

  @Test func onlyDockedWindowsKeepClearOfTheStrip() {
    // A loose window that lies in it, below the call, stays there: at the pin, and at every layout after it.
    let (h, editor, _, call) = makeHarness(pinned: false)
    let notes = h.system.open(app: "Notes", pid: 1005, frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.run("float-all")
    h.run("dock \(editor.rawValue) left")
    let below = CGRect(x: 1150, y: 500, width: 250, height: 300)
    h.system.userMove(notes, to: below)
    h.system.clearFrameLog()
    for step in ["pin \(call.rawValue)", "relayout", "resize \(editor.rawValue) right 40"] {
      #expect(h.run(step).ok, "\(step)")
      #expect(h.frame(notes) == below && moves(of: notes, h).isEmpty, "after \(step)")
    }
    #expect(h.layout?.frame == beside)
  }

  @Test func aWindowDraggedToTheScreensEdgeLandsBesideTheStrip() {
    var settings = Settings()
    settings.reflowWhileDragging = false
    let (h, _, browser, call) = makeHarness(settings: settings)
    h.system.tiling = .off
    let mail = h.system.open(app: "Mail", pid: 1004, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.system.beginDrag(mail)
    h.system.moveDrag(to: CGPoint(x: 1438, y: 600), holding: 0.5)
    let preview = h.overlays.preview
    #expect(preview.map { beside.contains($0) } == true, "the preview shows where it will land: \(String(describing: preview))")
    h.system.endDrag()
    #expect(h.workspace.isDocked(mail))
    #expect(h.frame(mail)!.maxX == beside.maxX - 12 && h.frame(mail)!.minX > h.frame(browser)!.minX)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func aWindowDockedByItselfIsPlannedInWhatIsLeft() {
    var settings = Settings()
    settings.newWindows = "dock"
    let (h, _, _, call) = makeHarness(settings: settings)
    let mail = h.system.open(app: "Mail", pid: 1004, frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isDocked(mail))
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  // MARK: Docked windows move once

  @Test func settingThePinAndTakingItOffMoveEachDockedWindowOnce() {
    let (h, editor, browser, call) = makeHarness(pinned: false)
    let before = [editor: h.frame(editor)!, browser: h.frame(browser)!]
    #expect(h.frame(browser)!.overlaps(corner), "or there would be nothing to see")
    #expect(h.run("pin \(call.rawValue)").message == "keeping \(call) in view")
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(moves(of: call, h).isEmpty && h.frame(call) == corner)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
    h.system.clearFrameLog()
    #expect(h.run("unpin \(call.rawValue)").ok)
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(h.frame(editor) == before[editor] && h.frame(browser) == before[browser], "there and back is nothing")
    #expect(h.layout?.frame == h.visibleFrame)
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [false, true]) func whileItIsDraggedNothingElseMovesAndWhenItIsLetGoEachDockedWindowMovesOnce(reflow: Bool) {
    var settings = Settings()
    settings.reflowWhileDragging = reflow
    let (h, editor, browser, call) = makeHarness(settings: settings)
    h.system.tiling = .off
    h.system.beginDrag(call)
    for point in [CGPoint(x: 1000, y: 200), CGPoint(x: 700, y: 400), CGPoint(x: 300, y: 500), CGPoint(x: 180, y: 70)] {
      h.system.moveDrag(to: point, holding: 0.4)
      #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty, "at \(point)")
      #expect(h.overlays.preview == nil)
    }
    // Something else lays out meanwhile: the others still wait where they are.
    h.run("relayout")
    #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty && h.layout?.frame == beside)
    h.system.endDrag()
    let dropped = h.frame(call)!
    #expect(dropped.minX < 100 && h.workspace.isPinned(call))
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(h.layout?.frame == CGRect(x: dropped.maxX, y: 25, width: 1440 - dropped.maxX, height: 875), "the strip is on the left now")
    #expect(moves(of: call, h).isEmpty)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
    h.scheduler.advance(by: 2)
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1, "and nothing follows later")
  }

  @Test func aDragWhoseEndIsNeverSeenEndsTheSameWay() {
    let (h, editor, _, call) = makeHarness()
    h.system.tiling = .off
    h.system.beginDrag(call)
    h.system.moveDrag(to: CGPoint(x: 180, y: 70), holding: 0.4)
    h.system.loseTheReleaseOfTheDrag()
    #expect(moved(editor, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func whileItsEdgeIsPulledNothingElseMovesAndWhenItIsLetGoEachDockedWindowMovesOnce() {
    let (h, editor, browser, call) = makeHarness()
    for width in [360, 420, 480] as [CGFloat] {
      h.system.userResize(call, to: CGRect(x: corner.maxX - width, y: 50, width: width, height: 300), release: false)
      h.scheduler.advance(by: 0.3)
      #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty, "at \(width)")
    }
    h.system.releaseMouse()
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(h.layout?.frame.maxX == corner.maxX - 480)
    #expect(h.frame(call)?.size == CGSize(width: 480, height: 300) && moves(of: call, h).isEmpty)
    #expect(h.workspace.floating[call] == h.frame(call), "that size is its person's")
    expectClear(call, h)
    expectWindowsMatchLayout(h)
    h.scheduler.advance(by: 2)
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
  }

  @Test func aGrabThatWasTakenForNeitherADragNorAResizeIsFollowedWhenTheButtonIsUp() {
    let (h, editor, _, call) = makeHarness()
    h.system.mouseDown = true
    h.system.userMove(call, to: corner.offsetBy(dx: -60, dy: 0))
    h.scheduler.advance(by: 1)
    #expect(moves(of: editor, h).isEmpty && h.layout?.frame == beside)
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.4)
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 1030)
    expectClear(call, h)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("pinned-room") }, "and then it stops looking")
  }

  @Test func movedByItsOwnAppTheDockedWindowsFollowOnceItHasStoodStill() {
    // A call grows in steps when somebody shares a screen. It must not drag the arrangement along step by step.
    let (h, editor, browser, call) = makeHarness()
    for width in [340, 360, 380, 410] as [CGFloat] {
      h.system.userMove(call, to: CGRect(x: corner.maxX - width, y: 50, width: width, height: 300))
      h.scheduler.advance(by: 0.2)
      #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty, "at \(width)")
    }
    h.scheduler.advance(by: 0.2)
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(h.layout?.frame.maxX == 1000)
    #expect(h.overlays.headsUp.isEmpty, "there is nothing to say")
    expectClear(call, h)
    expectWindowsMatchLayout(h)
    h.scheduler.advance(by: 2)
    #expect(moved(editor, h) == 1 && !h.scheduler.pendingKeys.contains { $0.hasPrefix("pinned-room") })
  }

  @Test func grownBeyondFourTenthsItsStripGoesAndTheLineIsSaid() {
    let (h, editor, _, call) = makeHarness()
    h.system.userMove(call, to: CGRect(x: 700, y: 50, width: 710, height: 600))
    h.scheduler.advance(by: 0.4)
    #expect(h.layout?.frame == h.visibleFrame && moved(editor, h) == 1)
    #expect(h.overlays.headsUp[h.display]?.spoken == "Zoom stays in view, but other windows can cover it here. Smaller, and near a screen edge, they make room for it", "no edge would help a window of that size")
    #expect(h.frame(call)?.width == 710 && moves(of: call, h).isEmpty)
    expectWindowsMatchLayout(h)
  }

  @Test func aCommandMeanwhileLaysOutAroundWhereItIsAndNothingFollows() {
    let (h, editor, _, call) = makeHarness()
    h.system.userMove(call, to: corner.offsetBy(dx: -40, dy: 0))
    h.run("zoom \(editor.rawValue)")
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 1050)
    h.scheduler.advance(by: 2)
    #expect(moved(editor, h) == 1)
    expectClear(call, h)
  }

  @Test func movedWithinItsStripNothingElseMoves() {
    let (h, editor, browser, call) = makeHarness()
    h.system.userMove(call, to: corner.offsetBy(dx: 0, dy: 400))
    h.scheduler.advance(by: 1)
    #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty)
    h.system.userMove(call, to: corner.offsetBy(dx: 20, dy: 200))
    h.scheduler.advance(by: 1)
    // Nearer the edge the strip is narrower by 20 points: that is a move. Straight down is none.
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(h.layout?.frame.maxX == 1110)
    expectClear(call, h)
  }

  // MARK: It comes and goes

  @Test func minimizedHiddenOrClosedItsStripGoesBackAndComesAgainWithIt() {
    for way in ["minimize", "hide", "close"] {
      let (h, editor, browser, call) = makeHarness()
      let with = [h.frame(editor)!, h.frame(browser)!]
      switch way {
      case "minimize": h.system.setMinimized(call, true)
      case "hide": h.system.setHidden(pid: 1003, true)
      default: h.system.close(call)
      }
      h.scheduler.advance(by: 1)
      #expect(h.layout?.frame == h.visibleFrame, "\(way)")
      #expect(moved(editor, h) == 1 && moved(browser, h) == 1, "\(way)")
      expectWindowsMatchLayout(h)
      guard way != "close" else { continue }
      if way == "minimize" { h.system.setMinimized(call, false) } else { h.system.setHidden(pid: 1003, false) }
      h.scheduler.advance(by: 1)
      #expect(h.layout?.frame == beside, "\(way) and back")
      #expect([h.frame(editor)!, h.frame(browser)!] == with, "there and back is nothing: \(way)")
      #expect(h.frame(call) == corner && moves(of: call, h).isEmpty)
      expectClear(call, h)
    }
  }

  @Test func aRuleThatPinsAWindowAsItOpensMakesRoomForIt() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.facetime", action: .pin)]
    let (h, editor, _, _) = makeHarness(pinned: false, settings: settings)
    h.run("zoom \(editor.rawValue)")
    h.system.clearFrameLog()
    let call = h.system.open(app: "FaceTime", pid: 1006, frame: CGRect(x: 1100, y: 500, width: 300, height: 200))
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isPinned(call) && h.frame(call) == CGRect(x: 1100, y: 500, width: 300, height: 200))
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 1100)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func growAndShrinkByKeyAreFollowedAtOnce() {
    let (h, editor, _, call) = makeHarness()
    h.system.userFocus(call)
    #expect(h.run("grow 40").ok)
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == h.frame(call)!.minX)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
    // Beyond four tenths the strip goes, and whoever pressed the key is told, at that press.
    var said: [String] = []
    for _ in 0..<12 {
      let had = h.layout?.frame != h.visibleFrame
      h.run("grow 60", from: .shortcut)
      if had, h.layout?.frame == h.visibleFrame { said.append(h.overlays.headsUp[h.display]?.text ?? "nothing") }
    }
    #expect(h.layout?.frame == h.visibleFrame)
    #expect(said == ["Zoom stays in view, but other windows can cover it here"])
    expectWindowsMatchLayout(h)
  }

  @Test func pinnedWhileItIsInTheHandItGetsItsRoomWhenItIsLetGo() {
    let (h, editor, _, call) = makeHarness(pinned: false)
    h.system.tiling = .off
    h.system.beginDrag(call)
    h.system.moveDrag(to: CGPoint(x: 1200, y: 400), holding: 0.4)
    h.system.clearFrameLog()
    #expect(h.run("pin \(call.rawValue)").ok)
    h.system.moveDrag(to: CGPoint(x: 1250, y: 300), holding: 0.4)
    #expect(moves(of: editor, h).isEmpty && h.layout?.frame == h.visibleFrame)
    h.system.endDrag()
    #expect(h.layout?.frame.maxX == h.frame(call)!.minX && moved(editor, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func aKeyPressedBeforeItHasStoodStillStillSaysThatItLostItsRoom() {
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.userMove(call, to: CGRect(x: 500, y: 50, width: 910, height: 700))
    h.run("neighbor right", from: .shortcut)
    #expect(h.layout?.frame == h.visibleFrame)
    #expect(h.overlays.headsUp[h.display]?.text == "Zoom stays in view, but other windows can cover it here")
  }

  @Test func sentToAnotherDisplayItComesAtItsOwnSizeInOneMoveAndKeepsIt() {
    // It does not live on the Desktop, so it is not squeezed onto one; and nothing would give the size back later.
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let editor = h.system.open(app: "Editor", pid: 1001)
    let notes = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 1700, y: 100, width: 980, height: 624))
    h.start()
    h.run("dock \(editor.rawValue) right")
    h.run("pin \(notes.rawValue)")
    h.system.clearFrameLog()
    #expect(h.run("move-to-display 1 \(notes.rawValue)").ok)
    #expect(h.frame(notes)?.size == CGSize(width: 980, height: 624) && moved(notes, h) == 1)
    #expect(h.workspace.isPinned(notes) && h.visibleFrame.contains(h.frame(notes)!))
    expectWindowsMatchLayout(h)
    for way in ["pause", "resume", "unpin \(notes.rawValue)"] {
      h.run(way)
      h.scheduler.advance(by: 1)
      #expect(h.frame(notes)?.size == CGSize(width: 980, height: 624), "after \(way)")
    }
  }

  @Test func intoFullScreenAndBackMovesNobody() {
    let (h, editor, browser, call) = makeHarness()
    let before = [h.frame(editor)!, h.frame(browser)!]
    h.system.enterFullScreen(call, leaving: [editor, browser])
    h.scheduler.advance(by: 2)
    h.system.leaveFullScreen(call, with: [editor, browser])
    h.scheduler.advance(by: 2)
    #expect(moves(of: editor, h).isEmpty && moves(of: browser, h).isEmpty)
    #expect([h.frame(editor)!, h.frame(browser)!] == before && h.frame(call) == corner && h.layout?.frame == beside)
    expectWindowsMatchLayout(h)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("pinned-room") })
  }

  @Test func oneThatLeavesFullScreenAndDoesNotComeBackGivesItsRoomUpWhenTheTimeIsOver() {
    let (h, editor, browser, call) = makeHarness()
    h.system.enterFullScreen(call, leaving: [editor, browser])
    h.scheduler.advance(by: 2)
    for window in [editor, browser] { h.system.setOnActiveSpace(window, true) }
    h.system.setOnActiveSpace(call, false)
    h.system.setFullScreen(call, false)
    h.scheduler.advance(by: 0.5)
    #expect(h.layout?.frame == beside, "it may still come")
    h.scheduler.advance(by: 2)
    #expect(h.layout?.frame == h.visibleFrame)
    expectWindowsMatchLayout(h)
  }

  @Test func letGoWhereMacOSTilesItTheOthersMoveOnceToWhereThatLeavesThem() {
    // As a Mac comes: the screen's edges are macOS's, and it gives the window another frame a moment after it is let go.
    let (h, editor, browser, call) = makeHarness()
    h.system.tiling = .on
    h.system.drag(call, through: [CGPoint(x: corner.midX, y: corner.minY + 10), CGPoint(x: 1300, y: 300), CGPoint(x: 1439, y: 400)])
    h.scheduler.advance(by: 2)
    #expect(h.frame(call) != corner && h.workspace.isPinned(call))
    #expect(moved(editor, h) == 1 && moved(browser, h) == 1)
    #expect(moves(of: call, h).isEmpty, "Arbor stands aside")
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: ["hold", "hold still"]) func whileTheViewIsHeldWhatItsOwnAppDoesToItMovesNothing(hold: String) {
    // A call that grows when somebody shares, in front of the audience. `hold still` begins by itself in a call.
    let (h, editor, _, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    #expect(h.run(hold).ok)
    h.system.clearFrameLog()
    h.system.userMove(call, to: CGRect(x: 900, y: 50, width: 510, height: 400))
    h.scheduler.advance(by: 1)
    #expect(h.system.frameLog.isEmpty && h.layout?.frame == beside)
    #expect(h.controller.invariantViolations().isEmpty)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("pinned-room") }, "and nobody goes on looking for as long as the call lasts")
    #expect(h.run("release").ok)
    h.scheduler.advance(by: 1)
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 900, "followed when the hold ends")
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func aDisplayThatComesWhileTheViewIsHeldTakesNoRoomAway() {
    var settings = Settings()
    settings.holdStillFor = ["com.example.zoom"]
    let (h, editor, _, call) = makeHarness(settings: settings)
    #expect(h.controller.isHeld)
    h.run("zoom \(editor.rawValue)")
    let framed = h.frame(editor)
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    h.scheduler.advance(by: 3)
    #expect(h.frame(editor) == framed && h.layout?.frame == beside)
    expectClear(call, h)
  }

  @Test func aRuleThatPinsTheVeryWindowThatBeginsTheHoldStillMakesRoomForIt() {
    // A rule is its person's standing order.
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.facetime", action: .pin)]
    settings.holdStillFor = ["com.example.facetime"]
    let (h, editor, _, _) = makeHarness(pinned: false, settings: settings)
    h.run("zoom \(editor.rawValue)")
    let call = h.system.open(app: "FaceTime", pid: 1006, frame: CGRect(x: 1100, y: 500, width: 300, height: 200))
    h.scheduler.advance(by: 2)
    #expect(h.controller.isHeld && h.workspace.isPinned(call))
    #expect(h.layout?.frame.maxX == 1100)
    expectClear(call, h)
  }

  @Test func theWindowWhoseClosingEndsTheHoldMovesTheOthersOnce() {
    var settings = Settings()
    settings.holdStillFor = ["com.example.browser"]
    let (h, editor, browser, call) = makeHarness(settings: settings)
    #expect(h.controller.isHeld)
    h.system.userMove(call, to: CGRect(x: 900, y: 50, width: 510, height: 400))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.close(browser)
    h.scheduler.advance(by: 2)
    #expect(!h.controller.isHeld && moved(editor, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func whateverElseLaysOutDuringAHoldDoesSoAroundWhereItIs() {
    let (h, editor, _, call) = makeHarness()
    #expect(h.run("hold still").ok)
    h.system.userMove(call, to: CGRect(x: 1000, y: 50, width: 410, height: 300))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    #expect(h.run("set gap 20").ok)
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 1000)
    expectClear(call, h)
  }

  @Test func aScriptsCommandThatArrangesNothingMovesNothingInFrontOfAnAudience() {
    let (h, _, _, call) = makeHarness()
    #expect(h.run("hold still").ok)
    h.system.userMove(call, to: CGRect(x: 1000, y: 50, width: 410, height: 300))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    #expect(h.run("save-view 3", from: .script).ok)
    #expect(h.system.frameLog.isEmpty && h.layout?.frame == beside)
    // The person's own key, whatever it is for, is their next command.
    #expect(h.run("save-view 4", from: .shortcut).ok)
    #expect(h.layout?.frame.maxX == 1000)
  }

  @Test func letGoWhereMacOSTilesItDuringAHoldTheHandHasAskedAllTheSame() {
    let (h, editor, _, call) = makeHarness()
    h.system.tiling = .on
    h.run("zoom \(editor.rawValue)")
    #expect(h.run("hold still").ok)
    h.system.clearFrameLog()
    h.system.drag(call, through: [CGPoint(x: corner.midX, y: corner.minY + 10), CGPoint(x: 700, y: 300), CGPoint(x: 0, y: 400)])
    h.scheduler.advance(by: 2)
    #expect(h.frame(call)?.width == 720, "macOS's half")
    #expect(moved(editor, h) == 1 && h.layout?.frame == h.visibleFrame, "no strip is left behind where nothing is")
  }

  @Test func inFullScreenAcrossAStartOrAChangeOfTheDisplaysItsRoomIsStillKept() {
    for what in ["start", "displays"] {
      var (h, editor, browser, call) = makeHarness()
      h.system.enterFullScreen(call, leaving: [editor, browser])
      h.scheduler.advance(by: 5)
      if what == "start" {
        let new = Harness(displays: h.system.displayList, saved: h.store.saved)
        for window in h.system.allWindows() {
          new.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.id == call ? corner : window.frame)
        }
        new.system.enterFullScreen(call, leaving: [editor, browser])
        new.start()
        h = new
      } else {
        h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
      }
      h.scheduler.advance(by: 3)
      h.system.clearFrameLog()
      h.system.leaveFullScreen(call, with: [editor, browser])
      h.scheduler.advance(by: 3)
      #expect(h.workspace.isPinned(call) && h.layout?.frame == beside, "\(what)")
      for window in [editor, browser] { #expect((moved(window, h) ?? 9) <= 1, "\(what): \(moves(of: window, h))") }
      expectClear(call, h, what)
    }
  }

  @Test func theLineWaitsForACommandThatFailedAndComesBeforeAHint() {
    // Why a key did nothing comes first. The line is not lost for that.
    let (h, editor, _, call) = makeHarness()
    h.system.userMove(call, to: CGRect(x: 500, y: 50, width: 910, height: 700))
    #expect(!h.run("dock 999 left", from: .shortcut).ok)
    #expect(h.overlays.headsUp[h.display]?.text.contains("stays in view") != true)
    // Framing for the first time earns a teaching hint, which keeps its showing for the next time.
    #expect(h.run("zoom \(editor.rawValue)", from: .shortcut).ok)
    #expect(h.overlays.headsUp[h.display]?.spoken == "Zoom stays in view, but other windows can cover it here. Smaller, and near a screen edge, they make room for it")
    let said = h.overlays.messages.filter { $0.model.text.contains("stays in view") }.count
    h.run("show-all", from: .shortcut)
    h.run("zoom \(editor.rawValue)", from: .shortcut)
    #expect(h.overlays.messages.filter { $0.model.text.contains("stays in view") }.count == said, "once")
  }

  @Test func theLineIsForPeople() {
    var settings = Settings()
    settings.messages = "off"
    for (settings, source) in [(settings, CommandSource.shortcut), (Settings(), .script)] {
      let (h, _, _, call) = makeHarness(call: middle, pinned: false, settings: settings)
      h.system.userFocus(call)
      #expect(h.run("toggle-pin", from: source).message.hasPrefix("\(call) stays in view, but"), "the reply says it to everybody")
      h.scheduler.advance(by: 1)
      #expect(h.overlays.messages.allSatisfy { !$0.model.text.contains("stays in view") })
    }
  }

  @Test func itDoesNotStepOnALineThatIsUp() {
    // macOS has just tiled it to half the screen, and Arbor is saying so.
    let (h, _, _, call) = makeHarness()
    h.system.tiling = .on
    h.system.drag(call, through: [CGPoint(x: corner.midX, y: corner.minY + 10), CGPoint(x: 1300, y: 300), CGPoint(x: 1439, y: 400)])
    h.scheduler.advance(by: 1)
    let lines = h.overlays.messages.map(\.model.text)
    #expect(lines.last?.hasPrefix("macOS tiled this window") == true, "\(lines)")
    #expect(h.layout?.frame == h.visibleFrame)
  }

  @Test func holdingStillACommandOfThePersonsOwnLaysOutAroundWhereItIs() {
    let (h, editor, _, call) = makeHarness()
    #expect(h.run("hold still").ok)
    h.system.userMove(call, to: CGRect(x: 1000, y: 50, width: 410, height: 300))
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    #expect(h.run("zoom \(editor.rawValue)").ok)
    #expect(moved(editor, h) == 1 && h.layout?.frame.maxX == 1000)
    expectClear(call, h)
  }

  @Test func aMoveThatPassesForArborsOwnIsFollowedToo() {
    // A call that snaps to its aspect ratio right after Arbor sized it; a frame that happens to equal one Arbor has just set.
    let (h, editor, _, call) = makeHarness()
    _ = h.system.setFrame(CGRect(x: 100, y: 300, width: 320, height: 240), of: call)
    h.controller.windowChanged(h.system.windows[call]!.snapshot, userInitiated: false)
    h.system.clearFrameLog()
    h.scheduler.advance(by: 1)
    #expect(moved(editor, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func takingThePinOffNeitherMovesNorSizesTheWindowItself() {
    let (h, editor, _, _) = makeHarness()
    #expect(h.run("pin \(editor.rawValue)").ok)
    let own = h.frame(editor)!
    h.system.clearFrameLog()
    #expect(h.run("unpin \(editor.rawValue)").ok)
    #expect(h.frame(editor) == own && moves(of: editor, h).isEmpty, "nothing jumps at the moment of unpinning")
  }

  @Test func thePointThatShowsOfAWindowOutOfViewCoversNothing() {
    // In the bottom right corner, where windows out of view keep one point on screen.
    let (h, editor, browser, call) = makeHarness(call: CGRect(x: 1120, y: 660, width: 320, height: 240))
    h.system.userFocus(browser)
    h.system.userFocus(editor)
    h.run("zoom")
    #expect(h.controller.parked.contains(browser) && h.frame(browser)!.overlaps(h.frame(call)!), "or this would prove nothing")
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == false)
  }

  @Test func dockingItEndsThePinAndTheStrip() {
    let (h, _, _, call) = makeHarness()
    #expect(h.run("dock \(call.rawValue) right").ok)
    #expect(!h.workspace.isPinned(call) && h.layout?.frame == h.visibleFrame)
    expectWindowsMatchLayout(h)
  }

  @Test func pinnedWhileItIsOutOfViewItComesInAndRoomIsMadeInTheSameLayout() {
    let (h, editor, _, call) = makeHarness(pinned: false)
    h.run("zoom \(editor.rawValue)")
    #expect(!h.system.isVisible(call))
    h.system.clearFrameLog()
    #expect(h.run("pin \(call.rawValue)").ok)
    #expect(h.frame(call) == corner && moved(call, h) == 1)
    #expect(moved(editor, h) == 1 && h.frame(editor) == beside.insetBy(dx: 12, dy: 12), "once, to where it ends up")
    #expect(h.system.raiseLog == [call], "the one raise")
    expectWindowsMatchLayout(h)
  }

  @Test func aDockedWindowThatIsPinnedGetsItsOwnSizeAndTheRestIsLaidOutBesideIt() {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let call = h.system.open(app: "Zoom", pid: 1003, frame: corner)
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(call.rawValue) right")
    h.system.clearFrameLog()
    #expect(h.run("pin \(call.rawValue)").ok)
    #expect(h.frame(call)?.size == corner.size && h.visibleFrame.contains(h.frame(call)!) && moved(call, h) == 1)
    #expect(moved(editor, h) == 1)
    #expect(h.layout?.frame.maxX == h.frame(call)!.minX)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  // MARK: Where there is no room

  @Test func aPinInTheMiddleReservesNothingAndSaysSo() {
    let (h, editor, _, call) = makeHarness(call: middle, pinned: false)
    let reply = h.run("pin \(call.rawValue)")
    #expect(reply.ok)
    #expect(reply.message == "\(call) stays in view, but other windows can cover it here. Near a screen edge they make room for it.")
    #expect(h.layout?.frame == h.visibleFrame)
    #expect(moves(of: editor, h).isEmpty, "nobody has a reason to move")
    h.system.userFocus(editor)
    h.run("zoom")
    h.scheduler.advance(by: 1)
    #expect(h.frame(editor) == h.visibleFrame.insetBy(dx: 12, dy: 12))
    #expect(h.frame(call) == middle && !h.controller.parked.contains(call), "it still never goes out of view")
    #expect(isCovered(call, h), "which is what a Mac shows")
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == true, "and `state` says so")
    h.system.userFocus(call)
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == false)
  }

  @Test func theLineOnScreenSaysItToo() {
    let (h, _, _, call) = makeHarness(call: middle, pinned: false)
    h.system.userFocus(call)
    #expect(h.run("toggle-pin", from: .shortcut).ok)
    #expect(h.overlays.headsUp[h.display]?.spoken == "Zoom stays in view, but other windows can cover it here. Near a screen edge they make room for it")
    // With room, as ever.
    let (beside, _, _, other) = makeHarness(pinned: false)
    beside.system.userFocus(other)
    #expect(beside.run("toggle-pin", from: .shortcut).ok)
    #expect(beside.overlays.headsUp[beside.display]?.line == "Keeping Zoom in view")
  }

  @Test func draggedFromTheMiddleToAnEdgeItGetsItsStripAndBackItGivesItUp() {
    let (h, editor, _, call) = makeHarness(call: middle)
    h.system.tiling = .off
    #expect(h.layout?.frame == h.visibleFrame)
    h.system.drag(call, through: [CGPoint(x: middle.midX, y: middle.minY + 10), CGPoint(x: 1250, y: 100)])
    #expect(h.layout?.frame.maxX == h.frame(call)!.minX && moved(editor, h) == 1)
    expectClear(call, h)
    let there = h.frame(call)!
    h.system.clearFrameLog()
    h.system.drag(call, through: [CGPoint(x: there.midX, y: there.minY + 10), CGPoint(x: middle.midX, y: middle.minY + 10)])
    #expect(h.layout?.frame == h.visibleFrame)
    #expect(moved(editor, h) == 1, "once each time")
    #expect(h.overlays.headsUp[h.display]?.text == "Zoom stays in view, but other windows can cover it here", "it has lost its room, and is told")
    expectWindowsMatchLayout(h)
  }

  @Test func theMenusRowDoesNotPromiseMoreThanItKeeps() throws {
    func row(_ h: Harness) throws -> MenuModel.Item { try #require(h.controller.menuModel().allItems.first { $0.command == .togglePin(nil) }) }
    let (h, _, _, call) = makeHarness(call: middle)
    h.system.userFocus(call)
    #expect(try row(h).title == "Keep This Window in View (Can Be Covered Here)" && row(h).isTicked)
    #expect(try row(h).help?.contains("Near a screen edge they make room for it") == true)
    let (beside, editor, _, other) = makeHarness()
    beside.system.userFocus(other)
    #expect(try row(beside).title == "Keep This Window in View" && row(beside).isTicked)
    beside.system.userFocus(editor)
    #expect(try row(beside).title == "Keep This Window in View" && !row(beside).isTicked)
  }

  @Test func aSummonedWindowReservesNothingAndOneThatStaysSaysWhenItIsCovered() {
    var settings = Settings()
    settings.summonStays = true
    let (h, editor, _, call) = makeHarness(pinned: false, settings: settings)
    h.run("zoom \(editor.rawValue)")
    h.system.clearFrameLog()
    #expect(h.run("summon Zoom").ok)
    #expect(h.layout?.frame == h.visibleFrame && moves(of: editor, h).isEmpty, "it comes and goes: nobody makes way")
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == false)
    h.system.userFocus(editor)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isSummoned(call))
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == true)
  }

  @Test func oneAsLargeAsTheDisplayReservesNothing() {
    let (h, editor, _, call) = makeHarness(call: CGRect(x: 0, y: 25, width: 1440, height: 875))
    #expect(h.layout?.frame == h.visibleFrame)
    h.run("zoom \(editor.rawValue)")
    #expect(h.frame(call) == h.visibleFrame)
    expectWindowsMatchLayout(h)
  }

  @Test func twoEachHaveTheirStripInTheOrderPinned() {
    let (h, editor, _, call) = makeHarness()
    // 350 points on the right are taken. 200 on the left still fit under four tenths of 1440; 300 do not.
    let timer = h.system.open(app: "Timer", pid: 1004, frame: CGRect(x: 0, y: 600, width: 200, height: 120))
    #expect(h.run("pin \(timer.rawValue)").message == "keeping \(timer) in view")
    #expect(h.layout?.frame == CGRect(x: 200, y: 25, width: 890, height: 875))
    h.run("zoom \(editor.rawValue)")
    expectClear(call, h)
    expectClear(timer, h)
    h.system.userMove(timer, to: CGRect(x: 0, y: 600, width: 300, height: 120))
    h.scheduler.advance(by: 1)
    #expect(h.layout?.frame == beside, "the one pinned first keeps its strip")
    // Pinned the other way round, it is the call that goes without.
    h.run("unpin \(call.rawValue)")
    #expect(h.layout?.frame == CGRect(x: 300, y: 25, width: 1140, height: 875))
    #expect(h.run("pin \(call.rawValue)").message.hasSuffix("they make room for it."))
    #expect(h.layout?.frame == CGRect(x: 300, y: 25, width: 1140, height: 875))
    #expect(h.workspace.pinnedWindows == [timer, call])
    expectWindowsMatchLayout(h)
  }

  @Test func theOrderIsSavedWithTheArrangement() throws {
    let (h, _, _, call) = makeHarness()
    let timer = h.system.open(app: "Timer", pid: 1004, frame: CGRect(x: 0, y: 600, width: 300, height: 120))
    h.run("unpin \(call.rawValue)")
    h.run("pin \(timer.rawValue)")
    h.run("pin \(call.rawValue)")
    h.scheduler.advance(by: 5)
    let new = Harness(displays: h.system.displayList, saved: h.store.saved)
    for window in h.system.allWindows() {
      new.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    new.system.clearFrameLog()
    new.start()
    #expect(new.workspace.pinnedWindows == [timer, call])
    #expect(new.layout?.frame == h.layout?.frame)
    #expect(new.system.frameLog.isEmpty, "a start on windows that are where they belong moves nothing")
    expectWindowsMatchLayout(new)
  }

  // MARK: The raise: one, when the pin is set

  @Test func itIsRaisedOnceAsItIsPinnedAndOnlyIfSomethingCoversIt() {
    let (h, editor, _, call) = makeHarness(call: middle, pinned: false)
    let notes = h.system.open(app: "Notes", pid: 1005, frame: middle.offsetBy(dx: 40, dy: 40))
    h.system.userFocus(editor)
    #expect(isCovered(call, h))
    h.run("pin \(call.rawValue)")
    #expect(h.system.raiseLog == [call])
    #expect(h.system.windowsFrontToBack().prefix(3) == [editor, call, notes], "over everything but the window that has the keyboard")
    #expect(h.system.focused == editor, "which stays where it is")
    h.scheduler.advance(by: 3)
    #expect(h.system.raiseLog == [call], "no retries")

    let (uncovered, _, _, other) = makeHarness(pinned: false)
    uncovered.system.userFocus(other)
    uncovered.run("pin")
    #expect(uncovered.system.raiseLog.isEmpty, "raising asks its app, which may be busy with a call")
  }

  @Test func whenTheStackingCannotBeToldItIsRaisedAtThePin() {
    let (h, _, _, call) = makeHarness(pinned: false)
    h.system.stackingIsUnknown = true
    h.run("pin \(call.rawValue)")
    #expect(h.system.raiseLog == [call])
    #expect(h.controller.snapshot().windows.first { $0.id == call }?.covered == false, "what cannot be told is not claimed")
  }

  @Test func nothingThatHappensLaterRaisesIt() {
    for place in [corner, middle] {
      let (h, editor, browser, call) = makeHarness(call: place)
      h.system.userFocus(browser)
      h.system.userClick(browser)
      h.system.userClick(browser, release: false)
      h.scheduler.advance(by: 3)
      h.system.mouseDown = false
      h.system.userFocus(editor)
      for step in ["zoom", "neighbor right", "show-all", "relayout", "arrange"] { h.run(step) }
      h.scheduler.advance(by: 3)
      #expect(h.system.raiseLog.isEmpty)
      #expect(h.frame(call) == place)
      #expect(h.scheduler.pendingKeys.allSatisfy { !$0.hasPrefix("raise") && !$0.hasPrefix("pinned-room") }, "\(h.scheduler.pendingKeys)")
    }
  }

  @Test func theStandInsRaiseStopsBehindTheWindowThatHasTheKeyboardAsAMacsDoes() {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let second = h.system.open(app: "Editor", pid: 1001)
    let call = h.system.open(app: "Zoom", pid: 1003)
    h.start()
    h.system.userFocus(second)
    h.system.userFocus(editor)
    h.system.raise(call)
    #expect(h.system.windowsFrontToBack() == [editor, call, second])
    // A window of the app in front comes to the very front.
    h.system.raise(second)
    #expect(h.system.windowsFrontToBack() == [second, editor, call])
  }

  // MARK: Once pinned it is never moved or sized

  @Test func pushedMoreThanHalfOverAnEdgeByHandItStaysThere() {
    let (h, editor, _, call) = makeHarness()
    let pushed = CGRect(x: -251, y: 288, width: 480, height: 348)
    h.system.userMove(call, to: pushed)
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    for step in ["relayout", "zoom \(editor.rawValue)", "show-all", "arrange", "desktop", "back"] {
      h.run(step)
      #expect(h.frame(call) == pushed, "after \(step)")
    }
    #expect(moves(of: call, h).isEmpty)
    #expect(h.layout?.frame.minX == 229, "what shows of it has its strip")
    expectClear(call, h)
    #expect(h.workspace.floating[call] == pushed, "what is remembered is where it is, so nothing throws it to and fro:")
    for step in ["unpin \(call.rawValue)", "pin \(call.rawValue)", "unpin \(call.rawValue)", "pin \(call.rawValue)"] {
      h.run(step)
      #expect(h.frame(call) == pushed, "after \(step)")
    }
  }

  @Test func madeSmallerWhileArborWasNotLookingItIsNotBlownUp() {
    let (h, _, _, call) = makeHarness()
    h.run("pause")
    let smaller = CGRect(x: 1190, y: 50, width: 220, height: 160)
    h.system.userMove(call, to: smaller)
    h.system.clearFrameLog()
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect(h.frame(call) == smaller && moves(of: call, h).isEmpty)
    #expect(h.layout?.frame.maxX == 1190)
    h.run("relayout")
    #expect(h.frame(call) == smaller)
    h.controller.shutdown()
    #expect(h.frame(call) == smaller, "nor as Arbor quits")
  }

  @Test func madeSmallerAfterARunThatDidNotQuitItIsNotBlownUpAtTheStart() {
    // Nothing was written down as Arbor went, so what is remembered is the larger frame. The window is the better witness.
    let (h, _, _, call) = makeHarness()
    h.scheduler.advance(by: 5)
    let smaller = CGRect(x: 1190, y: 50, width: 220, height: 160)
    let new = Harness(displays: h.system.displayList, saved: h.store.saved)
    for window in h.system.allWindows() {
      new.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.id == call ? smaller : window.frame)
    }
    new.system.clearFrameLog()
    new.start()
    new.scheduler.advance(by: 3)
    #expect(new.workspace.isPinned(call) && new.frame(call) == smaller && moves(of: call, new).isEmpty)
    #expect(new.layout?.frame.maxX == 1190)
    expectWindowsMatchLayout(new)
  }

  @Test func quitFloatAllAndPauseLeaveItWhereItIsWhoeverMovedItThere() {
    for way in ["quit", "float-all", "pause"] {
      let (h, _, _, call) = makeHarness()
      // The way Arbor moves windows, so that it passes for Arbor's own doing and what is remembered stays.
      _ = h.system.setFrame(CGRect(x: 700, y: 300, width: 320, height: 240), of: call)
      h.system.clearFrameLog()
      if way == "quit" { h.controller.shutdown() } else { h.run(way) }
      #expect(h.frame(call)?.origin == CGPoint(x: 700, y: 300) && moves(of: call, h).isEmpty, "\(way)")
    }
  }

  @Test func asArborQuitsEveryoneHasTheirOwnFrameAndTheCallIsNotTouched() {
    let (h, editor, browser, call) = makeHarness()
    h.run("zoom \(editor.rawValue)")
    h.system.clearFrameLog()
    h.controller.shutdown()
    // Where both opened.
    for window in [editor, browser] { #expect(h.frame(window) == CGRect(x: 300, y: 200, width: 640, height: 420)) }
    #expect(h.frame(call) == corner && moves(of: call, h).isEmpty)
  }

  // MARK: Displays

  @Test func carriedToAnotherDisplayBothAreLaidOutOnce() {
    let (h, editor, _, call) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.tiling = .off
    let mail = h.system.open(app: "Mail", pid: 1004, frame: CGRect(x: 1600, y: 200, width: 400, height: 300))
    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(mail.rawValue) left")
    h.run("zoom \(mail.rawValue)")
    h.system.clearFrameLog()
    h.system.drag(call, through: [CGPoint(x: corner.midX, y: corner.minY + 10), CGPoint(x: 2500, y: 100)])
    #expect(h.controller.workspaceID(containing: call) == side.id && h.controller.isPinned(call))
    #expect(h.controller.layouts[h.display]?.frame == h.visibleFrame)
    #expect(h.controller.layouts[side.id]?.frame.maxX == h.frame(call)!.minX)
    #expect(moved(editor, h) == 1 && moved(mail, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h, on: h.display)
    expectWindowsMatchLayout(h, on: side.id)
  }

  @Test func itComesBackWithItsDisplayToThePointOverhangIncluded() {
    let (h, _, _, call) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    // 40 points over the right edge of the second display: carried over, and left there by hand.
    let there = CGRect(x: 2280, y: 79, width: 480, height: 347)
    h.system.userMove(call, to: there.offsetBy(dx: -100, dy: 0))
    h.system.userMove(call, to: there)
    h.scheduler.advance(by: 1)
    #expect(h.controller.workspaceID(containing: call) == side.id && h.controller.isPinned(call))
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaceID(containing: call) == h.display && h.system.isVisible(call))
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    h.scheduler.advance(by: 3)
    #expect(h.frame(call) == there)
    #expect(h.layout?.frame == h.visibleFrame, "and the main display has its room back")
    expectWindowsMatchLayout(h)
  }

  @Test func pinnedWhereItHangsOverAnEdgeThatIsAPlaceItsPersonChose() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let there = CGRect(x: 2280, y: 79, width: 480, height: 347)
    let call = h.system.open(app: "Zoom", pid: 1003, frame: there)
    h.start()
    h.run("pin \(call.rawValue)")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.advance(by: 3)
    #expect(h.visibleFrame.contains(h.frame(call)!), "on a display where nobody put it: wholly in view")
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    h.scheduler.advance(by: 3)
    #expect(h.frame(call) == there)
  }

  @Test func aFrameNobodyChoseOnThisDisplayIsFitted() {
    // Taken along from a larger display that went: what is remembered may hang over this one's edge, and nobody left it so.
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let call = h.system.open(app: "Zoom", pid: 1003, frame: CGRect(x: 1500, y: 500, width: 480, height: 290))
    h.start()
    h.run("pin \(call.rawValue)")
    let low = DisplaySnapshot(
      id: h.display, frame: CGRect(x: 0, y: 0, width: 1440, height: 700), visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 675), isMain: true)
    h.system.setDisplays([low])
    h.scheduler.advance(by: 3)
    #expect(low.visibleFrame.contains(h.frame(call)!))
  }

  @Test func aDisplayThatShrinksAndTakesMoreThanHalfOfItBringsItWhollyIntoViewOnce() {
    let (h, _, _, call) = makeHarness()
    h.system.clearFrameLog()
    let small = DisplaySnapshot(
      id: h.display, frame: CGRect(x: 0, y: 0, width: 1200, height: 800), visibleFrame: CGRect(x: 0, y: 25, width: 1200, height: 775),
      isMain: true)
    h.system.setDisplays([small])
    h.scheduler.advance(by: 3)
    #expect(small.visibleFrame.contains(h.frame(call)!) && h.frame(call)?.size == corner.size)
    #expect(moved(call, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func aChangeOfTheDisplaysThatTakesNothingFromItLeavesItAsItsPersonLeftIt() {
    let (h, _, _, call) = makeHarness()
    let pushed = CGRect(x: -251, y: 288, width: 480, height: 348)
    h.system.userMove(call, to: pushed)
    h.scheduler.advance(by: 1)
    h.system.clearFrameLog()
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    h.scheduler.advance(by: 3)
    #expect(h.frame(call) == pushed && moves(of: call, h).isEmpty)
  }

  // MARK: With the rest of Arbor

  @Test func undoAndRedoOfAPinLayOutAroundWhereItEndsUp() {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let call = h.system.open(app: "Zoom", pid: 1003, frame: corner)
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(call.rawValue) right")
    let docked = [h.frame(editor)!, h.frame(call)!]
    h.run("pin \(call.rawValue)")
    let pinned = [h.frame(editor)!, h.frame(call)!]
    #expect(h.run("undo").ok)
    #expect([h.frame(editor)!, h.frame(call)!] == docked)
    expectWindowsMatchLayout(h)
    h.system.clearFrameLog()
    #expect(h.run("redo").ok)
    #expect([h.frame(editor)!, h.frame(call)!] == pinned)
    #expect(moved(editor, h) == 1 && moved(call, h) == 1)
    expectWindowsMatchLayout(h)
  }

  @Test func whileTheViewIsHeldThePersonsOwnDragOfItStillMakesRoom() {
    // The view does not move: the same space is in it, beside the window where it lies now.
    let (h, editor, _, call) = makeHarness()
    h.system.tiling = .off
    h.run("zoom \(editor.rawValue)")
    #expect(h.run("hold").ok)
    #expect(!h.run("unpin \(call.rawValue)").ok, "a held view takes no command that changes it")
    let camera = h.workspace.camera
    h.system.clearFrameLog()
    h.system.drag(call, through: [CGPoint(x: corner.midX, y: corner.minY + 10), CGPoint(x: 180, y: 70)])
    #expect(h.workspace.camera == camera && moved(editor, h) == 1)
    expectClear(call, h)
    expectWindowsMatchLayout(h)
  }

  @Test func pauseAndResumeAreThereAndBack() {
    let (h, editor, browser, call) = makeHarness()
    let before = [h.frame(editor)!, h.frame(browser)!, h.frame(call)!]
    h.run("pause")
    h.run("resume")
    h.scheduler.advance(by: 2)
    #expect([h.frame(editor)!, h.frame(browser)!, h.frame(call)!] == before)
    #expect(h.layout?.frame == beside)
    expectWindowsMatchLayout(h)
  }

  @Test func theMinimapHasTheShapeOfWhatIsLeft() throws {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("minimap").ok)
    let map = try #require(h.overlays.minimaps[h.display])
    // Everything is in view, so what is framed is the whole map.
    let shape = map.highlight.size
    #expect(abs(shape.width / shape.height - beside.width / beside.height) < 0.05, "\(shape)")
  }
}
