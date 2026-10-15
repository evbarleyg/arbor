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

/// A few windows into one group, in one step: `side-by-side` (QUESTIONS Q29, 9; board 0.12; the maintainer's I18).
@Suite @MainActor struct SideBySideTests {
  /// Five apps' windows, each with a process of its own, floating.
  private func desk(
    displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], minimums: [Int: CGSize] = [:]
  ) -> (Harness, [WindowID]) {
    let h = Harness(displays: displays)
    let windows = ["Safari", "Notes", "Mail", "Music", "Preview"].enumerated().map { place, app in
      h.system.open(
        app: app, pid: Int32(2000 + place),
        frame: CGRect(
          x: 60 + 90 * CGFloat(place), y: 80 + 40 * CGFloat(place), width: max(640, minimums[place]?.width ?? 0), height: 420),
        minimumSize: minimums[place] ?? .zero)
    }
    h.start()
    return (h, windows)
  }

  private func line(_ windows: [WindowID]) -> String { "side-by-side " + windows.map { "\($0.rawValue)" }.joined(separator: " ") }

  /// From left to right, together as wide as the display, each as high.
  private func expectSideBySide(
    _ h: Harness, _ windows: [WindowID], in area: CGRect? = nil, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let area = area ?? h.visibleFrame
    let frames = windows.compactMap(h.frame)
    #expect(frames.count == windows.count, sourceLocation: sourceLocation)
    for (left, right) in zip(frames, frames.dropFirst()) {
      #expect(left.maxX <= right.minX && right.minX - left.maxX < 40, "\(frames)", sourceLocation: sourceLocation)
    }
    #expect((frames.first?.minX ?? 0) - area.minX < 40 && area.maxX - (frames.last?.maxX ?? 0) < 40, "\(frames)", sourceLocation: sourceLocation)
    for frame in frames { #expect(frame.height > area.height - 60, "\(frames)", sourceLocation: sourceLocation) }
  }

  @Test func threeOfFiveInTheOrderNamedFillTheDisplay() {
    let (h, w) = desk()
    h.beginStep()
    let result = h.run(line([w[2], w[0], w[3]]))
    #expect(result.ok && result.message == "docked \(w[2]), \(w[0]) and \(w[3]) side by side")
    expectSideBySide(h, [w[2], w[0], w[3]])
    let widths = [w[2], w[0], w[3]].map { h.frame($0)!.width }
    #expect(widths.max()! - widths.min()! <= 1, "equally wide: \(widths)")
    #expect(h.layout!.tiles.isEmpty && h.layout!.windowFrames.count == 3)
    #expect(h.workspace.floating.keys.sorted() == [w[1], w[4]])
    // Each goes to its place once.
    for window in [w[2], w[0], w[3]] { #expect(h.movesInStep[window] == 1, "\(window): \(h.movesInStep)") }
    expectWindowsMatchLayout(h)
  }

  @Test func allOfThemComeToTheFrontAndTheFirstHasTheKeyboard() {
    let (h, w) = desk()
    h.system.userFocus(w[4])
    h.system.clearRaiseLog()
    #expect(h.run(line([w[1], w[3]])).ok)
    #expect(h.system.focused == w[1])
    #expect(Set(h.system.raiseLog).isSuperset(of: [w[3]]))
  }

  @Test func oneUndoTakesAllOfItBack() {
    let (h, w) = desk()
    #expect(h.run("dock \(w[4].rawValue) left").ok)
    h.system.userFocus(w[1])
    let (before, frames) = (h.workspace, w.map { h.frame($0)! })
    #expect(h.run(line([w[2], w[4], w[0]])).ok)
    let result = h.run("undo")
    #expect(result.ok, "\(result.message)")
    #expect(h.workspace.hasSameArrangement(as: before) && h.workspace.camera == before.camera)
    #expect(w.map { h.frame($0)! } == frames)
    #expect(h.system.focused == w[1], "the keyboard is back where it was")
    expectWindowsMatchLayout(h)
    // And one redo puts all of it back.
    #expect(h.run("redo").ok)
    expectSideBySide(h, [w[2], w[4], w[0]])
    #expect(h.system.focused == w[2])
    expectWindowsMatchLayout(h)
    #expect(h.run("undo").ok && h.run("undo").message == "undid dock \(w[4]) left")
  }

  @Test func whatWasDockedStaysDockedAndIsThereWhenEverythingShows() {
    let (h, w) = desk()
    for window in [w[0], w[1], w[2]] { #expect(h.run("dock \(window.rawValue) right").ok) }
    #expect(h.run(line([w[4], w[1]])).ok)
    expectSideBySide(h, [w[4], w[1]])
    #expect(h.workspace.isDocked(w[0]) && h.workspace.isDocked(w[2]) && h.workspace.isFloating(w[3]))
    #expect(h.run("show-all").ok)
    #expect(h.workspace.tree.allWindows == [w[0], w[2], w[4], w[1]])
    // Back is one step.
    #expect(h.run("back").ok)
    expectSideBySide(h, [w[4], w[1]])
    expectWindowsMatchLayout(h)
  }

  // MARK: Nobody who was just asked for is a tile

  @Test func whoNeedsMoreGetsItAndTheOthersShareTheRest() {
    let (h, w) = desk(minimums: [0: CGSize(width: 760, height: 300)])
    #expect(h.run(line([w[1], w[0], w[2]])).ok)
    expectSideBySide(h, [w[1], w[0], w[2]])
    #expect(h.frame(w[0])!.width >= 760 && h.layout!.tiles.isEmpty)
    #expect(abs(h.frame(w[1])!.width - h.frame(w[2])!.width) <= 1)
    expectWindowsMatchLayout(h)
  }

  @Test func togetherTooWideItIsRefusedByNameAndEverythingIsAsItWas() {
    let wide = CGSize(width: 620, height: 300)
    let (h, w) = desk(minimums: [0: wide, 2: wide, 3: wide])
    #expect(h.run("dock \(w[1].rawValue) left").ok)
    h.system.userFocus(w[4])
    let (before, frames) = (h.workspace, w.map { h.frame($0)! })
    let result = h.run(line([w[0], w[2], w[3]]))
    #expect(!result.ok && result.message == "Safari, Mail and Music do not fit side by side on this display")
    #expect(h.workspace == before && w.map { h.frame($0)! } == frames)
    #expect(h.system.focused == w[4])
    expectWindowsMatchLayout(h)
    // The second time Arbor knows, and moves nothing.
    h.system.clearFrameLog()
    #expect(!h.run(line([w[0], w[2], w[3]])).ok && h.system.frameLog.isEmpty)
    // Nothing to take back.
    #expect(!h.run("undo").message.contains("side-by-side"))
  }

  // MARK: Who can be one of them

  @Test func fromTheDockAndFromAHiddenAppTheyComeBack() {
    for late in [false, true] {
      let (h, w) = desk()
      h.system.setMinimized(w[1], true)
      h.system.setHidden(pid: 2003, true)
      h.system.restoresLate = late
      h.beginStep()
      let result = h.run(line([w[0], w[1], w[3]]))
      #expect(result.ok, "\(result.message)")
      // Its place is kept open: the one that is here goes straight to its third.
      let third = h.frame(w[0])!
      #expect(third.width < h.visibleFrame.width / 2, "late: \(late), \(third)")
      h.system.finishRestoring()
      h.scheduler.advance(by: 3)
      #expect(h.frame(w[0]) == third)
      for window in [w[0], w[1], w[3]] { #expect(h.movesInStep[window] == 1, "late: \(late), \(window): \(h.movesInStep)") }
      #expect(h.system.windows[w[1]]?.snapshot.isMinimized == false && h.system.windows[w[3]]?.snapshot.isHidden == false)
      expectSideBySide(h, [w[0], w[1], w[3]])
      #expect(h.layout!.tiles.isEmpty && h.system.focused == w[0], "late: \(late)")
      expectWindowsMatchLayout(h)
    }
  }

  @Test func oneThatNeverComesBackLosesItsPlace() {
    let (h, w) = desk()
    h.system.setMinimized(w[1], true)
    h.system.restoresLate = true
    #expect(h.run(line([w[0], w[1], w[3]])).ok)
    #expect(h.layout!.windowFrames[w[1]] != nil, "kept open")
    h.scheduler.advance(by: 3)
    #expect(h.layout!.windowFrames.keys.sorted() == [w[0], w[3]])
    expectSideBySide(h, [w[0], w[3]])
    expectWindowsMatchLayout(h)
    // And has it again when it does.
    h.system.finishRestoring()
    h.scheduler.advance(by: 2)
    expectSideBySide(h, [w[0], w[1], w[3]])
    expectWindowsMatchLayout(h)
  }

  /// The one that flies out of the Dock takes the keyboard with it. It belongs to the first.
  @Test func theKeyboardEndsInTheFirstAlsoWhenALaterOneFliesIn() {
    for late in [false, true] {
      let (h, w) = desk()
      h.system.setMinimized(w[3], true)
      h.system.restoresLate = late
      #expect(h.run(line([w[2], w[3]])).ok)
      h.system.finishRestoring()
      h.system.userFocus(w[3])  // as macOS does for a window out of the Dock
      h.scheduler.advance(by: 3)
      #expect(h.system.focused == w[2], "late: \(late)")
      expectSideBySide(h, [w[2], w[3]])
    }
  }

  /// In the Dock it could not be asked how small it goes. All or nothing holds for it too.
  @Test func oneThatLandsAndDoesNotFitTakesAllOfItBack() {
    let wide = CGSize(width: 800, height: 300)
    let (h, w) = desk(minimums: [0: wide, 2: wide])
    h.system.userFocus(w[4])
    h.system.setMinimized(w[0], true)
    let before = h.workspace
    let own = h.frame(w[2])!
    h.system.restoresLate = true
    #expect(h.run(line([w[2], w[0]])).ok)
    h.system.finishRestoring()
    h.scheduler.advance(by: 3)
    #expect(h.workspace.hasSameArrangement(as: before), "\(h.ascii())")
    #expect(h.frame(w[2]) == own && h.layout!.tiles.isEmpty)
    #expect(h.overlays.headsUp[h.display]?.text == "Mail and Safari do not fit side by side on this display")
    expectWindowsMatchLayout(h)
  }

  @Test func whileOneIsAwaitedItClosesOrArborPausesOrThePersonGoesOn() {
    for what in ["close", "pause", "show-all"] {
      let (h, w) = desk()
      h.system.setMinimized(w[1], true)
      h.system.restoresLate = true
      #expect(h.run(line([w[0], w[1], w[3]])).ok)
      if what == "close" { h.system.close(w[1]) } else { #expect(h.run(what).ok) }
      h.system.finishRestoring()
      h.scheduler.advance(by: 4)
      #expect(h.controller.invariantViolations().isEmpty, "\(what): \(h.controller.invariantViolations())")
      if what != "pause" { expectWindowsMatchLayout(h) }
      if what == "close" { expectSideBySide(h, [w[0], w[3]]) }
    }
  }

  /// What macOS says beforehand is known beforehand: nobody is asked, nothing flies there and back.
  @Test func aSizeThatCannotChangeIsCountedBeforeAnybodyIsAsked() {
    let h = Harness()
    let fixed = h.system.open(app: "Settings", pid: 2000, frame: CGRect(x: 60, y: 80, width: 900, height: 500), isResizable: false)
    let other = h.system.open(app: "Fonts", pid: 2001, frame: CGRect(x: 160, y: 120, width: 900, height: 500), isResizable: false)
    h.start()
    h.system.clearFrameLog()
    let result = h.run(line([fixed, other]))
    #expect(!result.ok, "\(result.message)")
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// A place its person chose is not one Arbor chose, after a refusal either.
  @Test func afterARefusalAFloatingWindowStaysWhereItsPersonPutIt() {
    let wide = CGSize(width: 800, height: 300)
    let (h, w) = desk(minimums: [0: wide, 2: wide])
    #expect(h.run("dock \(w[1].rawValue) left").ok && h.run("dock \(w[3].rawValue) right").ok)
    // Laid over a docked window, by hand.
    h.system.userMove(w[0], to: CGRect(x: 20, y: 60, width: 900, height: 500))
    let own = h.frame(w[0])!
    #expect(!h.run(line([w[0], w[2]])).ok)
    #expect(h.frame(w[0]) == own)
    h.system.close(w[4])
    h.scheduler.advance(by: 2)
    #expect(h.frame(w[0]) == own, "no unasked move a moment later")
  }

  @Test func eachUndoGivesTheKeyboardBackToWhoHadItThen() {
    let (h, w) = desk()
    h.system.userFocus(w[4])
    #expect(h.run(line([w[0], w[1]])).ok)
    #expect(h.run("float \(w[0].rawValue)").ok)
    h.system.userFocus(w[3])
    #expect(h.run(line([w[0], w[1]])).ok, "the same words a second time")
    #expect(h.run("undo").ok && h.system.focused == w[3])
    #expect(h.run("undo").ok)
    #expect(h.run("undo").ok && h.system.focused == w[4])
  }

  @Test func aTileAWindowOutOfViewAndAPinnedOne() {
    let (h, w) = desk()
    for window in [w[0], w[1]] { #expect(h.run("dock \(window.rawValue) right").ok) }
    #expect(h.run("pin \(w[2].rawValue)").ok)
    #expect(h.run("zoom \(w[0].rawValue)").ok)
    let result = h.run(line([w[1], w[2]]))
    #expect(result.ok && result.message.hasSuffix("side by side; \(w[2]) is no longer kept in view"), "\(result.message)")
    expectSideBySide(h, [w[1], w[2]])
    #expect(!h.controller.isPinned(w[2]))
    expectWindowsMatchLayout(h)
  }

  @Test func whoCannotIsRefusedWithTheReasonAndNothingMoves() {
    let (h, w) = desk()
    #expect(h.run("exclude com.example.music").ok)
    h.system.setFullScreen(w[4], true)
    h.system.setOnActiveSpace(w[2], false)
    let before = h.workspace
    h.system.clearFrameLog()
    for (other, words) in [
      (w[3], "Arbor does not arrange Music"), (w[4], "\(w[4]) is full screen"), (w[2], "\(w[2]) is on another macOS Space"),
      (WindowID(9999), "there is no window w9999"),
    ] {
      let result = h.run(line([w[0], other, w[1]]))
      #expect(!result.ok && result.message.hasPrefix(words), "\(result.message)")
    }
    #expect(h.workspace == before && h.system.frameLog.isEmpty)
  }

  @Test func notWhileTheViewIsHeldNorWithAWindowInTheHand() {
    let (h, w) = desk()
    #expect(h.run("hold").ok)
    #expect(!h.run(line([w[0], w[1]])).ok)
    #expect(h.run("release").ok)
    let before = w.map(h.frame)
    h.system.beginDrag(w[4])
    h.system.moveDrag(to: CGPoint(x: 700, y: 300))
    let held = h.frame(w[4])
    #expect(h.run(line([w[0], w[4]])).message == "a window is being dragged; drop it first")
    #expect(h.run(line([w[0], w[1]])).message == "a window is being dragged; drop it first", "whichever it is")
    #expect(w.dropLast().map(h.frame) == Array(before.dropLast()) && h.frame(w[4]) == held && h.workspace.tree.allWindows.isEmpty)
    h.system.endDrag()
    #expect(h.run(line([w[0], w[1]])).ok)
  }

  // MARK: Found by walks that draw the command (seeds from 1,000,000), shrunk

  private func expectNoRuleBroken(_ script: String, sourceLocation: SourceLocation = #_sourceLocation) {
    if let failure = ChaosRunner.replay(ChaosAction.script(script), excusing: ChaosRunner.knownRules) {
      Issue.record("\(failure)", sourceLocation: sourceLocation)
    }
  }

  /// One of the named could only be asked in its slot and refused there. The workspaces were given back, `parked` was not: two who
  /// floated out of view when they were named came back, at the next Show Everything, with the slots' frames for their own.
  @Test func afterALateRefusalWhoFloatedOutOfViewStillHasItsOwnFrame() {
    expectNoRuleBroken(
      """
      open 102 Xcode pid 1004 at 1407 703 2355 958 min 2355 958 title Draft frozen
      open 107 Preview pid 1007 at 1800 1859 726 360
      open 108 Music pid 1006 at 1050 957 178 304 min 178 304 title Untitled
      launch
      tab-open 110 in 102
      open 112 Terminal pid 1003 at 539 680 630 515
      open 113 Mail pid 1002 at 253 497 52 62
      open 114 Notes pid 1001 at 972 205 429 301 frozen
      side-by-side 114 107
      side-by-side 110 113 112 108
      key down show-all
      """)
  }

  /// The one in the Dock could not be asked how small it goes. It lands, does not fit, and all of it is taken back: there and back,
  /// which is nothing, also a step after the command.
  @Test func oneFromTheDockThatDoesNotFitIsThereAndBackForTheNetsToo() {
    expectNoRuleBroken(
      """
      open 101 Finder pid 1005 at 2300 1065 2780 1759
      launch
      open 103 Mail pid 1002 at 1257 911 1000 590 min 1000 590
      minimize 103
      open 104 Xcode pid 1004 at -727 826 789 511
      side-by-side 103 101 104
      settle
      """)
  }

  /// Two of three were in the Dock, and an act came between the command and their landing: the road then begins in the slot.
  @Test func thereAndBackWhateverCameBetween() {
    expectNoRuleBroken(
      """
      open 101 Finder pid 1005 at 2300 1065 2780 1759
      launch
      open 103 Mail pid 1002 at 1257 911 1000 590 min 1000 590
      minimize 103
      limits 101 min 2272 2036
      open 104 Xcode pid 1004 at -727 826 789 511
      minimize 101
      side-by-side 103 101 104
      release
      settle
      """)
  }

  @Test func namingTheWindowInTheHandMovesNobody() {
    expectNoRuleBroken(
      """
      displays side:-800,-16,800,600:37,0,0,0 main:0,0,1280,800:37,95,0,0* windows-never
      open 101 Safari pid 1000 at 227 576 376 408
      renumber 101 102
      open 103 Finder pid 1005 at 58 478 616 579 min 616 579
      launch
      grab 103
      carry 157 740
      settle
      open 104 Music pid 1006 at 1198 525 877 248 min 318 248 title Untitled
      side-by-side 104 103 102
      """)
  }

  // MARK: Two displays

  @Test func onTheDisplayAskedForWhereverTheyWere() {
    let (h, w) = desk(displays: [main, side])
    let far = h.system.open(app: "Terminal", pid: 2100, frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    let docked = h.system.open(app: "Xcode", pid: 2101, frame: CGRect(x: 1700, y: 240, width: 600, height: 400))
    #expect(h.run("dock \(docked.rawValue) left").ok)
    h.system.userFocus(w[0])
    #expect(h.run(line([far, w[0], docked])).ok)
    expectSideBySide(h, [far, w[0], docked], in: main.visibleFrame)
    #expect(h.controller.workspaces[side.id]!.allWindows.isEmpty)
    expectWindowsMatchLayout(h, on: main.id)
    expectWindowsMatchLayout(h, on: side.id)
    #expect(h.run("undo").ok)
    #expect(h.controller.workspaces[side.id]!.isDocked(docked) && h.controller.workspaces[side.id]!.isFloating(far))
    #expect(side.frame.contains(h.frame(far)!.center) && side.frame.contains(h.frame(docked)!.center))
  }
}

/// The same from Go to…: tick, tick, Return.
@Suite @MainActor struct SideBySideFromGoToTests {
  private func desk(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) -> (Harness, [WindowID]) {
    let h = Harness(displays: displays)
    let windows = ["Safari", "Notes", "Mail", "Music", "Preview"].enumerated().map { place, app in
      h.system.open(
        app: app, pid: Int32(2000 + place),
        frame: CGRect(x: 60 + 90 * CGFloat(place), y: 80 + 40 * CGFloat(place), width: 640, height: 420))
    }
    h.start()
    return (h, windows)
  }

  private func tick(_ h: Harness, _ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
    h.overlays.typeInFinder(text)
    #expect(h.overlays.tickInFinder(), "\(text)", sourceLocation: sourceLocation)
  }

  @Test func tickedInThatOrderTheyStandInThatOrder() {
    let (h, w) = desk()
    #expect(h.run("find").ok)
    for app in ["mail", "safari", "music"] { tick(h, app) }
    #expect(h.overlays.finder?.ticked == [w[2], w[0], w[3]])
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil, "the palette has closed")
    let frames = [w[2], w[0], w[3]].map { h.frame($0)! }
    #expect(frames[0].maxX <= frames[1].minX && frames[1].maxX <= frames[2].minX)
    #expect(h.layout!.windowFrames.count == 3 && h.layout!.tiles.isEmpty && h.system.focused == w[2])
    expectWindowsMatchLayout(h)
    // One step to take back, by its name in the menu.
    #expect(h.controller.nextStepTitle(.undo) == "Dock Side by Side")
    #expect(h.run("undo").ok && h.workspace.tree.allWindows.isEmpty)
  }

  @Test func withOneTickedReturnGoesThere() {
    let (h, w) = desk()
    #expect(h.run("find").ok)
    tick(h, "notes")
    h.overlays.typeInFinder("prev")
    #expect(h.overlays.chooseInFinder())
    #expect(h.system.focused == w[1] && h.workspace.tree.allWindows.isEmpty)
  }

  @Test func aRefusalIsSaidOnScreenAndNothingHasMoved() {
    let h = Harness()
    let wide = CGSize(width: 800, height: 300)
    let a = h.system.open(app: "Safari", pid: 2000, frame: CGRect(x: 60, y: 80, width: 900, height: 500), minimumSize: wide)
    let b = h.system.open(app: "Xcode", pid: 2001, frame: CGRect(x: 160, y: 120, width: 900, height: 500), minimumSize: wide)
    h.start()
    let frames = [h.frame(a)!, h.frame(b)!]
    #expect(h.run("find").ok)
    for app in ["safari", "xcode"] { tick(h, app) }
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder == nil && [h.frame(a)!, h.frame(b)!] == frames && h.workspace.tree.allWindows.isEmpty)
    #expect(h.overlays.headsUp[h.display]?.spoken.contains("Safari and Xcode do not fit side by side") == true)
  }

  @Test func aRefusalIsSaidWhereThePaletteWas() {
    let h = Harness(displays: [main, side])
    let wide = CGSize(width: 800, height: 300)
    let a = h.system.open(app: "Safari", pid: 2000, frame: CGRect(x: 60, y: 80, width: 900, height: 500), minimumSize: wide)
    let b = h.system.open(app: "Xcode", pid: 2001, frame: CGRect(x: 160, y: 120, width: 900, height: 500), minimumSize: wide)
    h.start()
    _ = (a, b)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("find").ok && h.overlays.finder?.model.display == side.id)
    h.system.cursor = CGPoint(x: 720, y: 450)
    for app in ["safari", "xcode"] { tick(h, app) }
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.headsUp[side.id]?.text.contains("do not fit side by side") == true && h.overlays.headsUp[main.id] == nil)
  }

  @Test func oneOfThemClosedMeanwhileThePaletteSaysSoAndStays() {
    let (h, w) = desk()
    #expect(h.run("find").ok)
    for app in ["mail", "safari"] { tick(h, app) }
    h.system.close(w[0])
    #expect(h.overlays.chooseInFinder())
    #expect(h.overlays.finder?.message == "One of those windows has closed")
    #expect(h.overlays.finder?.ticked == [w[2]] && h.workspace.tree.allWindows.isEmpty)
  }

  @Test func onTheDisplayThePaletteIsOpenOn() {
    let (h, w) = desk(displays: [main, side])
    let far = h.system.open(app: "Terminal", pid: 2100, frame: CGRect(x: 1600, y: 200, width: 600, height: 400))
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(h.run("find").ok)
    #expect(h.overlays.finder?.model.display == side.id)
    // Wherever the pointer goes meanwhile.
    h.system.cursor = CGPoint(x: 720, y: 450)
    for app in ["mail", "terminal"] { tick(h, app) }
    #expect(h.overlays.chooseInFinder())
    #expect(side.frame.contains(h.frame(w[2])!) && side.frame.contains(h.frame(far)!))
    #expect(h.controller.workspaces[side.id]!.tree.allWindows == [w[2], far])
    expectWindowsMatchLayout(h, on: side.id)
  }

  /// A trace holds numbers, and plays back.
  @Test func inATraceItIsNumbers() throws {
    let together = FinderDestination.together([WindowID(103), WindowID(101)])
    let data = try JSONEncoder().encode(TraceFinderDestination(together))
    #expect(String(decoding: data, as: UTF8.self) == #"{"windows":[103,101]}"#)
    #expect(try JSONDecoder().decode(TraceFinderDestination.self, from: data).destination == together)
  }
}
