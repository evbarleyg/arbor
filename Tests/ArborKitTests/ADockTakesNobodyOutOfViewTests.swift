import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Board 0.26. ⌃⌥← on an editor, ⌃⌥→ on a mail app, a display 1920 wide: their smallest widths are 1188 and 760, which do not fit
/// side by side, and halves do not help. The one docked first used to leave as a tile. macOS alone lets them overlap and hides
/// nothing. So does Arbor as it ships: room first (F61), and for what is still missing they overlap.
@Suite @MainActor struct ADockTakesNobodyOutOfViewTests {
  static let wide = DisplaySnapshot(
    id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055), isMain: true)
  let whereTheEditorStood = CGRect(x: 150, y: 80, width: 1300, height: 800)
  let whereMailStood = CGRect(x: 620, y: 180, width: 1000, height: 680)

  /// The editor and the mail app, floating, Arbor started as it ships.
  func desk(settings: Settings = Settings()) -> (Harness, editor: WindowID, mail: WindowID) {
    let h = Harness(displays: [Self.wide], settings: settings)
    let editor = h.system.open(app: "Editor", frame: whereTheEditorStood, minimumSize: CGSize(width: 1188, height: 685))
    let mail = h.system.open(app: "Mail", frame: whereMailStood, minimumSize: CGSize(width: 760, height: 400))
    h.start()
    return (h, editor, mail)
  }

  /// The coach's first two keys.
  func bothDocked(settings: Settings = Settings()) -> (Harness, editor: WindowID, mail: WindowID) {
    let (h, editor, mail) = desk(settings: settings)
    h.system.userFocus(editor)
    h.press("dock left")
    h.system.userFocus(mail)
    h.press("dock right")
    return (h, editor, mail)
  }

  let editorFlushLeft = CGRect(x: 12, y: 37, width: 1188, height: 1031)
  let mailFlushRight = CGRect(x: 1148, y: 37, width: 760, height: 1031)

  // MARK: The story

  /// The same frames with a column for the Desktop between the two, which ships off, and without.
  @Test(arguments: [false, true]) func bothAreInViewEachAtItsSmallestFlushWithItsOuterSide(desktopColumn: Bool) {
    let (h, editor, mail) = bothDocked(settings: desktopColumn ? .withDesktopColumn : Settings())
    #expect(h.frame(editor) == editorFlushLeft)
    #expect(h.frame(mail) == mailFlushRight)
    #expect(h.system.isVisible(editor) && h.system.isVisible(mail))
    #expect(h.layout?.hiddenWindows.isEmpty == true)
    #expect(h.layout?.tiles.allSatisfy { $0.kind == .desktop } == true)
    #expect(h.workspace.isDocked(editor) && h.workspace.isDocked(mail))
    expectWindowsMatchLayout(h)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  @Test func theWindowTheKeyNamedIsInFrontAndNobodyElseIsRaised() {
    let (h, editor, mail) = desk()
    h.system.userFocus(editor)
    h.press("dock left")
    h.system.userFocus(mail)
    h.system.clearRaiseLog()
    let asked = h.system.focusRequests.count
    h.press("dock right")
    #expect(h.system.windowsFrontToBack().first == mail)
    #expect(h.system.raiseLog.isEmpty)
    #expect(h.system.focusRequests.dropFirst(asked).allSatisfy { $0 == mail })
    #expect(h.system.focused == mail)
  }

  @Test func namedByACommandItComesToTheFrontThoughAnotherHadTheKeyboard() {
    let (h, editor, mail) = desk()
    h.run("dock \(mail.rawValue) right")
    h.system.userFocus(mail)
    h.run("dock \(editor.rawValue) left")
    #expect(h.system.windowsFrontToBack().first == editor)
    #expect(h.frame(editor) == editorFlushLeft)
    #expect(h.frame(mail) == mailFlushRight)
  }

  @Test func eachWindowMovesOnce() throws {
    let (h, editor, mail) = desk()
    h.system.userFocus(editor)
    h.press("dock left")
    h.system.userFocus(mail)
    let mark = h.system.moveLog.count
    h.press("dock right")
    #expect(movesWithoutWaste(h, of: mail, since: mark) == 1)
    // The editor stood flush left already, wider: it shrinks where it stands.
    #expect((movesWithoutWaste(h, of: editor, since: mark) ?? 9) <= 1)
    #expect(h.system.jolts(since: mark).isEmpty)
  }

  @Test func inTheOtherOrderTheFramesAreTheSame() {
    let (h, editor, mail) = desk()
    h.system.userFocus(mail)
    h.press("dock right")
    h.system.userFocus(editor)
    h.press("dock left")
    #expect(h.frame(editor) == editorFlushLeft)
    #expect(h.frame(mail) == mailFlushRight)
    #expect(h.system.windowsFrontToBack().first == editor)
    expectWindowsMatchLayout(h)
  }

  // MARK: Who is in front later

  @Test func aClickOnTheOneBehindBringsItForwardAndMovesAndSizesNothing() {
    let (h, editor, mail) = bothDocked()
    let mark = h.system.moveLog.count
    let tree = h.workspace.tree
    h.system.userClick(editor)
    h.scheduler.advance(by: 2)
    #expect(h.system.windowsFrontToBack().first == editor)
    #expect(h.system.moveLog.count == mark)
    #expect(h.workspace.tree == tree)
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
    #expect(h.workspace.camera == tree.root)
    h.system.userClick(mail)
    h.scheduler.advance(by: 2)
    #expect(h.system.windowsFrontToBack().first == mail)
    #expect(h.system.moveLog.count == mark)
  }

  @Test func arborsOwnFocusKeysWalkBetweenThem() {
    let (h, editor, mail) = bothDocked()
    #expect(h.run("focus left").ok)
    #expect(h.system.focused == editor)
    #expect(h.system.windowsFrontToBack().first == editor)
    #expect(h.run("focus right").ok)
    #expect(h.system.focused == mail)
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
  }

  // MARK: How it ends, and comes back

  @Test func undoIsOneStepBackToTheFramesBeforeTheDock() {
    let (h, editor, mail) = desk()
    h.system.userFocus(editor)
    h.press("dock left")
    let before = h.frame(editor)
    h.system.userFocus(mail)
    h.press("dock right")
    h.press("undo")
    #expect(h.frame(mail) == whereMailStood)
    #expect(h.frame(editor) == before)
    #expect(h.workspace.isFloating(mail))
    h.press("redo")
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
    expectWindowsMatchLayout(h)
  }

  @Test func framedAndBackIsTheOverlapAsItWas() {
    let (h, editor, mail) = bothDocked()
    h.press("zoom")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: mail))
    h.press("zoom")
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
    h.press("zoom")
    h.press("show-all")
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
    expectWindowsMatchLayout(h)
  }

  @Test func itEndsWhenTheNeighbourClosesOrFloats() throws {
    for leave in ["close", "float"] {
      let (h, editor, mail) = bothDocked()
      if leave == "close" { h.system.close(mail) } else { h.run("float \(mail.rawValue)") }
      #expect(h.layout?.overhangs.isEmpty == true, "\(leave)")
      #expect(try #require(h.frame(editor)).width >= 1188, "\(leave)")
      expectWindowsMatchLayout(h)
    }
  }

  @Test func itEndsOnALargerDisplay() {
    let (h, editor, mail) = bothDocked()
    h.system.setDisplays([
      DisplaySnapshot(
        id: Self.wide.id, frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 0, y: 25, width: 2560, height: 1415),
        isMain: true)
    ])
    h.scheduler.advance(by: 5)
    #expect(h.layout?.overhangs.isEmpty == true)
    #expect(h.frame(editor).map { f in h.frame(mail).map { !f.overlaps($0) } } == true)
    expectWindowsMatchLayout(h)
  }

  @Test func timeAloneChangesNothing() {
    let (h, editor, mail) = bothDocked()
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: 3600)
    #expect(h.system.moveLog.count == mark)
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
  }

  @Test func quitGivesBothTheirOwnFramesBackAndTheNextStartTheOverlap() {
    let (h, editor, mail) = bothDocked()
    h.scheduler.advance(by: 5)
    h.controller.shutdown()
    #expect(h.frame(editor) == whereTheEditorStood)
    #expect(h.frame(mail) == whereMailStood)
    let next = h.newProcess()
    next.start()
    next.scheduler.advance(by: 5)
    #expect(next.system.isVisible(editor) && next.system.isVisible(mail))
    #expect(next.layout?.hiddenWindows.isEmpty == true)
    #expect(next.overlays.headsUp.isEmpty, "never at a launch")
  }

  // MARK: The hand

  @Test func noHandMakesATileEither() throws {
    // Two that fit: 700 and 760 of 1896.
    let h = Harness(displays: [Self.wide], settings: Settings())
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 700, height: 300))
    let mail = h.system.open(app: "Mail", frame: whereMailStood, minimumSize: CGSize(width: 760, height: 400))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    #expect(h.layout?.overhangs.isEmpty == true)
    // Mail's left side is pulled 300 points to the right of where Mail will go.
    let place = try #require(h.layout?.nodeFrames[h.workspace.tree.leaf(containing: mail)!])
    #expect(h.run("resize \(mail.rawValue) left -\(Int(place.width) - 460)").ok)
    #expect(h.layout?.tiles.allSatisfy { $0.kind == .desktop } == true)
    #expect(h.system.isVisible(mail))
    #expect(h.frame(mail)?.width == 760)
    #expect(h.frame(mail)?.maxX == 1908)
    #expect(h.layout?.overhangs[mail]?.width == 300)
    // The shares are the hand's: no later layout widens the place again.
    h.run("zoom \(notes.rawValue)")
    h.run("back")
    #expect(h.layout?.overhangs[mail]?.width == 300)
    expectWindowsMatchLayout(h)
    // And the same hand lets it out.
    #expect(h.run("resize \(mail.rawValue) left 300").ok)
    #expect(h.layout?.overhangs.isEmpty == true)
  }

  @Test func thereIsNoHandleUnderAWindow() throws {
    let (h, editor, _) = bothDocked()
    let frame = try #require(h.frame(editor))
    #expect(h.layout?.seams.isEmpty == false)
    for seam in h.overlays.seams[h.display] ?? [] { #expect(!seam.frame.overlaps(frame)) }
    #expect(h.overlays.seams[h.display]?.isEmpty == true)
  }

  @Test func pullingTheEditorsOwnEdgeIsObeyed() throws {
    let (h, editor, mail) = desk()
    #expect(h.run("dock \(editor.rawValue) left").ok && h.run("dock \(mail.rawValue) beside \(editor.rawValue) right").ok)
    let (was, over) = (try #require(h.frame(editor)), try #require(h.layout?.overhangs.values.map(\.width).reduce(0, +)))
    #expect(over > 0)
    // Its right edge, 100 points further right.
    h.system.userResize(editor, to: CGRect(x: was.minX, y: was.minY, width: was.width + 100, height: was.height))
    h.scheduler.advance(by: 2)
    #expect(h.frame(editor) == CGRect(x: was.minX, y: was.minY, width: was.width + 100, height: was.height))
    #expect(h.layout?.overhangs.values.map(\.width).reduce(0, +) == over + 100)
    #expect(h.system.isVisible(editor) && h.system.isVisible(mail))
    #expect(try #require(h.frame(mail)).width == 760)
    expectWindowsMatchLayout(h)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// A drag comes in small steps. The gap goes under the window that has stopped following, and its handle stays for as long as the hand is on it: it is
  /// what hears the mouse.
  @Test func theHandleStaysUnderTheHandThatDragsIt() throws {
    let h = Harness(displays: [Self.wide], settings: Settings())
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 700, height: 300))
    let mail = h.system.open(app: "Mail", frame: whereMailStood, minimumSize: CGSize(width: 760, height: 400))
    h.start()
    #expect(h.run("dock \(notes.rawValue) left").ok && h.run("dock \(mail.rawValue) beside \(notes.rawValue) right").ok)
    let (left, right) = (try #require(h.workspace.tree.leaf(containing: notes)), try #require(h.workspace.tree.leaf(containing: mail)))
    func handle() -> Seam? { h.overlays.seams[h.display]?.first { $0.leading == left && $0.trailing == right } }
    let place = try #require(h.layout?.nodeFrames[left]?.width)
    var steps = 0
    while let seam = handle(), (h.layout?.overhangs[notes]?.width ?? 0) < 300, steps < 200 {
      h.overlays.dragSeam(seam, by: -25)
      steps += 1
    }
    let over = try #require(h.layout?.overhangs[notes]?.width)
    #expect(over >= 300 && over < 325)
    #expect(steps == Int(((place - 400) / 25).rounded(.up)))
    #expect(handle() != nil)
    #expect(h.frame(notes)?.width == 700 && h.system.isVisible(notes))
    #expect(h.controller.invariantViolations().isEmpty)
    // The hand has gone: no handle under a window.
    h.scheduler.advance(by: 2)
    #expect(handle() == nil)
    #expect(h.layout?.overhangs[notes]?.width == over)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// Found by a walk: the layout that ends the hold was another display's, and the handle stayed on the first.
  @Test func theHandleGoesThoughTheNextLayoutIsAnotherDisplays() {
    let runner = ChaosRunner()
    var broken: [InvariantViolation] = []
    for line in [
      "displays main:3008,200,1728,1117:37,0,0,0 side:0,0,3008,1692:25,0,0,0* windows-never",
      "open 101 Terminal pid 1003 at 1109 232 667 559 min 177 64 title Terminal-101 cells 7 15 2 4",
      "open 103 Notes pid 1001 at 3579 284 900 684 min 709 320 title Notes-103", "launch", "key down dock left", "key up dock left",
      "seam main 0 -180", "hide 1003",
    ] { broken += runner.step(ChaosAction(text: line)) }
    #expect(broken.map(\.rule).filter { $0 == "overlays" } == [])
  }

  @Test func shrinkStopsAtTheSmallestAsEver() throws {
    let h = Harness(displays: [Self.wide], settings: Settings())
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 100, y: 100, width: 900, height: 600), minimumSize: CGSize(width: 700, height: 300))
    let mail = h.system.open(app: "Mail", frame: whereMailStood, minimumSize: CGSize(width: 760, height: 400))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.system.userFocus(mail)
    for _ in 0..<40 { h.run("shrink 40") }
    #expect(h.layout?.overhangs.isEmpty == true)
    #expect(try #require(h.frame(mail)).width >= 760)
  }

  // MARK: More than two, and columns

  /// Found by a walk. Three in a row, the first hangs over for want of room. A hand gives the last a hundred points of the second's. The last could now
  /// spare what the first is short of, and at the next layout, whatever it was for, both gaps went to the right. A gap dragged by hand lasts: whoever
  /// hangs over when a hand has set the row is left as it is.
  @Test func aGapSetByHandIsNotMovedLaterForSomebodyWhoHungOverAlready() throws {
    let h = Harness(settings: Settings())
    let windows = [700, 500, 240].map {
      h.system.open(app: "App\($0)", frame: CGRect(x: 100, y: 100, width: 800, height: 500), minimumSize: CGSize(width: $0, height: 300))
    }
    h.start()
    #expect(h.run("layout App700 | App500 | App240").ok)
    let short = try #require(h.layout?.overhangs[windows[0]]?.width)
    #expect(short > 0 && h.layout?.overhangs.count == 1)
    #expect(h.run("resize \(windows[2].rawValue) left 100").ok)
    #expect(h.layout?.overhangs[windows[1]]?.width == 100)
    #expect(h.layout?.overhangs[windows[0]]?.width == short)
    let left = windows.map { h.frame($0) }
    h.run("zoom \(windows[2].rawValue)")
    h.run("back")
    #expect(windows.map { h.frame($0) } == left)
    h.system.userFocus(windows[0])
    h.scheduler.advance(by: 5)
    #expect(windows.map { h.frame($0) } == left)
    // There and back is nothing.
    h.system.setMinimized(windows[1], true)
    h.system.setMinimized(windows[1], false)
    h.scheduler.advance(by: 5)
    #expect(windows.map { h.frame($0) } == left)
    expectWindowsMatchLayout(h)
    // The neighbor goes for good: there is room for both, and the marks go with it. Docked again, room is made as for anybody.
    #expect(h.run("float \(windows[1].rawValue)").ok)
    #expect(h.layout?.overhangs.isEmpty == true)
    #expect(h.run("dock \(windows[1].rawValue) beside \(windows[0].rawValue) right").ok)
    #expect(h.layout?.overhangs[windows[1]] == nil)
    expectWindowsMatchLayout(h)
  }

  @Test func threeThatDoNotFit() throws {
    let h = Harness(displays: [Self.wide], settings: Settings())
    let windows = (0..<3).map { index in
      h.system.open(app: "App\(index)", frame: CGRect(x: 100 + 40 * index, y: 100, width: 1000, height: 700), minimumSize: CGSize(width: 900, height: 400))
    }
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) right")
    h.run("dock \(windows[2].rawValue) right")
    for window in windows {
      #expect(h.system.isVisible(window))
      #expect(h.frame(window)?.width == 900)
      #expect(h.visibleFrame.contains(try #require(h.frame(window))))
    }
    #expect(h.frame(windows[0])?.minX == 12)
    #expect(h.frame(windows[2])?.maxX == 1908)
    #expect(h.system.windowsFrontToBack().first == windows[2])
    expectWindowsMatchLayout(h)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  @Test func oneAboveTheOther() throws {
    let h = Harness(displays: [Self.wide], settings: Settings())
    let top = h.system.open(app: "Top", frame: CGRect(x: 100, y: 100, width: 900, height: 700), minimumSize: CGSize(width: 400, height: 640))
    let bottom = h.system.open(app: "Bottom", frame: CGRect(x: 200, y: 150, width: 900, height: 700), minimumSize: CGSize(width: 400, height: 640))
    h.start()
    h.run("dock \(top.rawValue) left")
    h.system.userFocus(bottom)
    h.run("dock \(bottom.rawValue) beside \(top.rawValue) bottom", from: .shortcut)
    #expect(h.frame(top)?.minY == 37 && h.frame(top)?.height == 640)
    #expect(h.frame(bottom)?.maxY == 1068 && h.frame(bottom)?.height == 640)
    #expect(h.overlays.headsUp[h.display]?.line == "Too tall to stand one above the other · they overlap")
    expectWindowsMatchLayout(h)
  }

  @Test func rotateNoLongerRefusesForIt() throws {
    // Side by side they fit, one above the other they do not.
    let h = Harness(displays: [Self.wide], settings: Settings())
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 800, height: 700), minimumSize: CGSize(width: 400, height: 640))
    let b = h.system.open(app: "B", frame: CGRect(x: 200, y: 150, width: 800, height: 700), minimumSize: CGSize(width: 400, height: 640))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) right")
    #expect(h.layout?.overhangs.isEmpty == true)
    h.system.userFocus(a)
    #expect(h.run("rotate").ok)
    #expect(h.system.isVisible(a) && h.system.isVisible(b))
    #expect(h.layout?.overhangs.isEmpty == false)
    expectWindowsMatchLayout(h)
  }

  // MARK: What is said

  @Test func theLineIsSaidTheFirstThreeTimesInAll() {
    let (h, _, mail) = desk()
    h.run("dock 101 left")
    var said = 0
    for _ in 0..<5 {
      h.system.userFocus(mail)
      h.press("dock right")
      if h.overlays.headsUp[h.display]?.line == "Too wide to stand side by side · they overlap" { said += 1 }
      h.scheduler.advance(by: 10)
      h.run("float \(mail.rawValue)")
      h.scheduler.advance(by: 10)
    }
    #expect(said == 3)
  }

  @Test func neverAtAResume() {
    let (h, _, _) = bothDocked()
    h.scheduler.advance(by: 10)
    h.run("pause")
    h.scheduler.advance(by: 10)
    h.run("resume")
    #expect(h.overlays.headsUp[h.display]?.line.contains("overlap") != true)
    #expect(h.layout?.overhangs.isEmpty == false)
  }

  /// Which of the two is said to hang over goes by the places: the editor beside a column for the Desktop, the mail app without one.
  @Test(arguments: [false, true]) func stateSaysDockedInViewAndHowFarOver(desktopColumn: Bool) throws {
    let (h, editor, mail) = bothDocked(settings: desktopColumn ? .withDesktopColumn : Settings())
    let (hanging, by) = try #require(h.layout?.overhangs.first)
    #expect(h.layout?.overhangs.count == 1 && by.width > 0 && by.height == 0)
    let state = h.controller.snapshot()
    let window = try #require(state.windows.first { $0.id == hanging })
    #expect(window.docked && !window.parked)
    #expect(window.overItsPlaceBy == by)
    #expect(state.windows.first { $0.id == (hanging == editor ? mail : editor) }?.overItsPlaceBy == nil)
    let drawing = h.ascii()
    #expect(drawing.contains("over its place: \(hanging) \(hanging == editor ? "Editor" : "Mail") by \(Int(by.width))"))
    #expect(!drawing.contains("hidden:"))
  }

  @Test func theReplySaysIt() {
    let (h, _, mail) = desk()
    h.run("dock 101 left")
    #expect(h.run("dock \(mail.rawValue) right").message.hasSuffix("; too wide to stand side by side, so they overlap"))
  }

  // MARK: What a reviewer found

  /// The editor hangs 16 points over the Desktop's tile, and 88 free points lie between the two windows: nothing overlaps, and nothing is said of it.
  @Test func whatHangsOverNoWindowIsNotSaidToOverlap() throws {
    let laptop = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
      visibleFrame: CGRect(x: 0, y: 25, width: 1512, height: 957), isMain: true)
    let h = Harness(displays: [laptop], settings: Settings())
    let editor = h.system.open(app: "Editor", frame: CGRect(x: 100, y: 100, width: 1000, height: 800), minimumSize: CGSize(width: 900, height: 600))
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 300, y: 200, width: 600, height: 680), minimumSize: CGSize(width: 500, height: 400))
    h.start()
    h.system.userFocus(editor)
    h.press("dock left")
    h.system.userFocus(mail)
    let reply = h.press("dock right")
    guard h.layout?.overhangs.isEmpty == false else { return }
    #expect(try #require(h.frame(editor)).maxX < (try #require(h.frame(mail))).minX)
    #expect(h.layout?.overhangsOverWindows.isEmpty == true)
    #expect(!reply.message.contains("overlap"))
    #expect(h.overlays.headsUp[h.display]?.line.contains("overlap") != true)
  }

  /// Whoever hangs over already may go on doing so, and no further: nobody asked for this dock. The new window used to halve the editor's place, the
  /// window its person was in, side by side, and lay wholly over the editor. There is room below.
  @Test func automaticDockingMakesNoOverlapLarger() throws {
    var settings = Settings()
    settings.newWindows = "dock"
    settings.tabsEnabled = false
    let (h, editor, mail) = bothDocked(settings: settings)
    let over = h.layout?.overhangs
    h.system.userFocus(editor)
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 300, width: 600, height: 500), minimumSize: CGSize(width: 400, height: 300))
    h.scheduler.advance(by: 3)
    #expect(h.layout?.overhangs == over)
    #expect(h.workspace.isDocked(notes) && h.layout?.fits(notes) == true)
    #expect(!(try #require(h.frame(notes))).overlaps(try #require(h.frame(editor))))
    #expect(h.system.isVisible(editor) && h.system.isVisible(mail))
    expectWindowsMatchLayout(h)
  }

  /// Its app makes the editor narrower than Arbor thought it went: the record comes down, and the layout with it, at once.
  @Test(arguments: [false, true]) func seenSmallerThanItsRecordItIsLaidOutAgainAtOnce(desktopColumn: Bool) throws {
    let (h, _, _) = bothDocked(settings: desktopColumn ? .withDesktopColumn : Settings())
    let hanging = try #require(h.layout?.overhangs.keys.first)
    var narrower = try #require(h.frame(hanging))
    narrower.size.width -= 200
    h.system.setMinimumSize(hanging, CGSize(width: narrower.width, height: 400))
    h.system.userMove(hanging, to: narrower)
    #expect(h.layout?.overhangs.isEmpty == true)
    expectWindowsMatchLayout(h)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// A middle window that hangs over, grown by hand; another has the keyboard; ⌘H and back. There and back is nothing, for whoever has the keyboard too.
  @Test func hiddenAndBackAfterAGrowIsNothing() {
    let runner = ChaosRunner()
    var broken: [InvariantViolation] = []
    for line in [
      "settings {}", "displays main:0,0,1920,1080:37,0,0,0* windows-never", "open 101 Music pid 1001 at 130 149 1130 648 min 980 600",
      "open 102 Finder pid 1002 at 131 100 662 409 min 501 252", "open 103 Finder2 pid 1003 at 24 97 578 288 min 501 252", "launch",
      "focus 101", "key down dock left", "key up dock left", "focus 102", "key down dock left", "key up dock left",
      "focus 103", "key down dock right", "key up dock right", "settle", "focus 101", "grow 200", "settle", "focus 102", "settle",
      "hide 1001", "react", "settle", "show 1001", "react", "settle",
    ] { broken += runner.step(ChaosAction(text: line)) }
    #expect(broken.map(\.rule).filter { $0.hasPrefix("there-and-back") } == [])
  }

  /// Criterion 14. A newcomer's first keys, as a hunter played them: four laptops' displays, eight apps, alone or beside a browser or a mail app docked a moment
  /// before, ⌃⌥← and ⌃⌥→. 176 stories, of which 52 sent a window out of view.
  @Test(arguments: [false, true]) func ofTheFirstKeysNoneSendsAWindowAway(tiles: Bool) {
    let apps: [(name: String, pid: Int, minimum: String, size: String)] = [
      ("Xcode", 1004, "1188 685", "1188 700"), ("Mail", 1002, "760 400", "1000 650"), ("Notes", 1001, "709 300", "900 600"),
      ("Music", 1006, "680 480", "980 600"), ("Safari", 1000, "574 240", "1100 650"), ("Finder", 1005, "501 300", "920 436"),
      ("Terminal", 1003, "177 60", "877 499"), ("Preview", 1007, "723 400 max 723 2000", "723 650"),
    ]
    let displays = ["0,0,1280,800:25,0,70,0", "0,0,1440,900:25,0,70,0", "0,0,1512,982:37,0,70,0", "0,0,1728,1117:37,0,70,0"]
    let moment = ["react", "advance 1", "react", "advance 5", "settle"]
    var (stories, sentAway) = (0, 0)
    for display in displays {
      for app in apps {
        for other in [nil, apps[4], apps[1]] where other?.name != app.name {
          for key in ["dock right", "dock left"] {
            let runner = ChaosRunner()
            var lines = ["displays main:\(display)* windows-never", tiles ? #"settings {"windowsThatDoNotFit":"tile"}"# : "settings {}", "launch", "settle"]
            if let other {
              let first = key == "dock right" ? "dock left" : "dock right"
              lines += ["open 102 \(other.name) pid \(other.pid) at 90 70 \(other.size) min \(other.minimum)", "focus 102"] + moment
              lines += ["key down \(first)", "key up \(first)"] + moment
            }
            lines += ["open 101 \(app.name) pid \(app.pid) at 60 50 \(app.size) min \(app.minimum)", "focus 101"] + moment
            lines += ["key down \(key)", "key up \(key)"] + moment
            for line in lines { _ = runner.step(ChaosAction(text: line)) }
            stories += 1
            if !runner.system.isVisible(WindowID(101)) || (other != nil && !runner.system.isVisible(WindowID(102))) { sentAway += 1 }
          }
        }
      }
    }
    #expect(stories == 176)
    // The control: with tiles some do.
    #expect((sentAway == 0) == !tiles)
  }

  // MARK: Two more that were seen

  /// Seen on a hosted Mac: 1024 points wide, the Dock at a side, two docked and the Desktop's column. ⌃⌥F docks a third: four columns of 228, under the 240 that
  /// counts as usable, and all three windows went out of view at one key.
  @Test(arguments: [false, true]) func onASmallDisplayWithTheDockAtASideTheThirdDockSendsNobodyAway(tiles: Bool) {
    let small = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 50, y: 31, width: 974, height: 737), isMain: true)
    let h = Harness(displays: [small], settings: tiles ? .withDesktopColumn.withTiles : .withDesktopColumn)
    let windows = (0..<3).map { h.system.open(app: "App \($0)", frame: CGRect(x: 100 + 50 * CGFloat($0), y: 100, width: 400, height: 300)) }
    h.start()
    #expect(h.run("dock \(windows[0].rawValue) left").ok && h.run("dock \(windows[1].rawValue) left").ok)
    h.system.userFocus(windows[2])
    h.press("toggle-float")
    #expect(windows.allSatisfy { h.workspace.isDocked($0) })
    // The control: that is how it was, and is with the option.
    #expect(windows.allSatisfy { h.system.isVisible($0) } == !tiles)
    guard !tiles else { return }
    for window in windows {
      #expect(h.frame(window)?.width == 240)
      #expect(h.frame(window).map { small.visibleFrame.contains($0) } == true)
    }
    expectWindowsMatchLayout(h)
    #expect(h.controller.invariantViolations().isEmpty)
  }

  /// Found by a walk: the only window, out of the Dock a moment ago, docked by the key, on a display it all but fills: it was the tile, out of view, and stayed there.
  @Test(arguments: [false, true]) func theOnlyWindowOutOfTheDockAndDockedAtOnceStays(tiles: Bool) {
    let runner = ChaosRunner()
    var broken: [InvariantViolation] = []
    for line in [
      tiles ? #"settings {"windowsThatDoNotFit":"tile"}"# : "settings {}",
      "displays main:0,0,1280,800:25,48,0,0* side:1280,0,3008,1692:25,0,0,0 windows-never", "launch",
      "open 102 Xcode pid 1004 at 92 39 1188 704 min 1188 685", "minimize 102", "restore 102", "key down dock left", "advance 0.3",
      "focus 102", "advance 0.3", "react", "advance 10", "react",
    ] { broken += runner.step(ChaosAction(text: line)) + runner.counted }
    #expect(runner.harness.workspace.isDocked(WindowID(102)))
    #expect(runner.system.isVisible(WindowID(102)) == !tiles)
    guard !tiles else { return }
    #expect(broken.map(\.rule) == [])
    #expect(runner.harness.frame(WindowID(102)) == CGRect(x: 60, y: 37, width: 1188, height: 751))
  }

  /// By another door, found by a walk: after a login the apps come back one by one into the places kept for them. The second of two that cannot both fit arrives, and
  /// the one that came first left as a tile with nobody acting.
  @Test(arguments: [false, true]) func afterALoginTheSecondComesBackAndTheFirstStays(tiles: Bool) {
    let runner = ChaosRunner()
    var broken: [InvariantViolation] = []
    for line in [
      tiles ? #"settings {"windowsThatDoNotFit":"tile"}"# : "settings {}", "launch",
      "open 101 Finder pid 1005 at 198 77 1058 419 min 501 252 title Finder-101", "open 103 Music pid 1006 at 321 219 1147 600 min 980 600 title Music-103",
      "key down dock right", "key up dock right", "focus 101", "key down dock left", "key up dock left", "quit", "close 101", "close 103", "launch",
      "open 109 Music pid 1006 at 321 219 1147 600 min 980 600 title Music-103", "advance 2",
      "open 107 Finder pid 1005 at 198 77 1058 419 min 501 252 title Finder-101", "settle",
    ] { broken += runner.step(ChaosAction(text: line)) }
    #expect(runner.harness.workspace.isDocked(WindowID(107)) && runner.harness.workspace.isDocked(WindowID(109)))
    #expect(runner.system.isVisible(WindowID(107)))
    #expect(runner.system.isVisible(WindowID(109)) == !tiles)
    if !tiles { #expect(broken.map(\.rule) == []) }
  }

  // MARK: The option

  @Test func withTheOptionTheOneDockedFirstIsATileAsItWas() {
    let (h, editor, mail) = bothDocked(settings: .withTiles)
    #expect(h.layout?.tiles.contains { $0.windows == [editor] } == true)
    #expect(!h.system.isVisible(editor))
    #expect(h.system.isVisible(mail) && h.frame(mail)?.maxX == mailFlushRight.maxX)
    #expect(h.layout?.overhangs.isEmpty == true)
    expectWindowsMatchLayout(h)
  }

  @Test func switchedWhileTheyOverlapAndBack() {
    let (h, editor, mail) = bothDocked()
    #expect(h.run("set windowsThatDoNotFit tile").ok)
    #expect(!h.system.isVisible(editor))
    #expect(h.run("set windowsThatDoNotFit overlap").ok)
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight)
    expectWindowsMatchLayout(h)
  }

  // MARK: Whatever is done

  /// F61's own fuzz (`RoomBeforeTilesTests.anythingGoes`), as Arbor ships. Whatever is docked, floated, framed, resized and minimized, with whatever
  /// smallest sizes: nothing that the view holds is out of view, no window is a tile, each is where the layout says and inside the display if it
  /// fits there, those that are within their places lie over nobody, and a layout asked for again changes nothing.
  @Test func anythingGoesAndNobodyLeaves() {
    var seed: UInt64 = 0xF069_0001
    func random(_ bound: Int) -> Int {
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((seed >> 33) % UInt64(bound))
    }
    let edges = ["left", "right", "top", "bottom"]
    var overlapped = 0
    for round in 0..<120 {
      let h = Harness(settings: Settings())
      var windows: [WindowID] = []
      func open() {
        let minimum = random(3) == 0 ? CGSize.zero : CGSize(width: 100 + random(800), height: 46 + random(500))
        windows.append(h.system.open(app: "App\(windows.count)", pid: Int32(100 + windows.count), minimumSize: minimum))
      }
      for _ in 0..<(2 + random(4)) { open() }
      h.start()
      var story: [String] = []
      for _ in 0..<30 {
        let window = windows[random(windows.count)].rawValue
        let other = windows[random(windows.count)].rawValue
        let step: String
        switch random(15) {
        case 0, 1, 2: step = "dock \(window) \(edges[random(4)])"
        case 3, 4: step = "dock \(window) beside \(other) \(edges[random(4)])"
        case 5: step = "float \(window)"
        case 6: step = "zoom \(window)"
        case 7: step = ["back", "show-all", "out", "desktop", "arrange", "relayout", "rotate", "mirror", "balance", "undo"][random(10)]
        case 8, 9: step = "resize \(window) \(edges[random(4)]) \(random(600) - 300)"
        case 10:
          step = "minimize \(window)"
          h.system.setMinimized(WindowID(window), true)
        case 11:
          step = "restore \(window)"
          h.system.setMinimized(WindowID(window), false)
        case 12:
          step = "seam"
          if let seams = h.overlays.seams[h.display], !seams.isEmpty {
            h.overlays.dragSeam(seams[random(seams.count)], by: CGFloat(random(500) - 250))
          }
        case 13:
          step = "click \(window)"
          if h.system.isVisible(WindowID(window)) { h.system.userClick(WindowID(window)) }
        default:
          step = "open"
          if windows.count < 8 { open() }
        }
        story.append(step)
        if !["minimize", "restore", "seam", "open", "click"].contains(where: step.hasPrefix) { h.run(step) }
        h.scheduler.advance(by: 1)

        let tree = h.workspace.tree
        let told = "round \(round): \(story.joined(separator: "; "))"
        guard tree.invariantViolations().isEmpty, let layout = h.layout else {
          Issue.record("\(tree.invariantViolations()) after \(told)")
          return
        }
        let problems = h.controller.invariantViolations()
        guard problems.isEmpty else {
          Issue.record("\(problems) after \(told)")
          return
        }
        #expect(layout.tiles.allSatisfy { $0.kind == .desktop }, "\(told)")
        let held = tree.windows(under: layout.camera).filter { h.controller.windows[$0]?.isPresent == true }
        for id in held {
          #expect(layout.windowFrames[id] != nil && h.system.isVisible(id), "\(id) has left the view after \(told)")
        }
        let shown = layout.windowFrames.keys.sorted()
        for id in shown {
          let slot = layout.windowFrames[id]!.insetBy(dx: -2, dy: -2)
          #expect(h.frame(id).map(slot.contains) == true, "\(id) \(String(describing: h.frame(id))) in \(slot) after \(told)")
          if let frame = h.frame(id), frame.width <= h.visibleFrame.width, frame.height <= h.visibleFrame.height {
            #expect(h.visibleFrame.contains(frame), "\(id) at \(frame) after \(told)")
          }
        }
        let fitting = shown.filter(layout.fits)
        for (index, first) in fitting.enumerated() {
          for second in fitting[(index + 1)...] {
            #expect(h.frame(first)?.overlaps(h.frame(second) ?? .zero) == false, "\(first) over \(second) after \(told)")
          }
        }
        if !layout.overhangs.isEmpty { overlapped += 1 }
      }
      h.system.setDisplays(h.system.displayList)
      h.scheduler.runPending()
      // At rest: another layout moves no gap and no docked window.
      let tree = h.workspace.tree
      h.system.clearFrameLog()
      h.system.setDisplays(h.system.displayList)
      h.scheduler.runPending()
      #expect(h.workspace.tree == tree, "round \(round): \(story.joined(separator: "; "))")
      let moved = h.system.frameLog.filter { h.layout?.windowFrames[$0.window] != nil }
      #expect(moved.isEmpty, "round \(round): \(moved) after \(story.joined(separator: "; "))")
    }
    // It has met what it is about.
    #expect(overlapped > 300)
  }

  // MARK: What is not this rule's

  @Test func automaticDockingStillFloatsWhatHasNoRoom() {
    var settings = Settings()
    settings.newWindows = "dock"
    let h = Harness(displays: [Self.wide], settings: settings)
    let editor = h.system.open(app: "Editor", frame: whereTheEditorStood, minimumSize: CGSize(width: 1188, height: 685))
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.system.userFocus(editor)
    let mail = h.system.open(app: "Mail", frame: whereMailStood, minimumSize: CGSize(width: 760, height: 700))
    h.scheduler.advance(by: 3)
    #expect(h.workspace.isFloating(mail))
    #expect(h.layout?.overhangs.isEmpty == true)
  }

  @Test(arguments: [false, true]) func aRecordThatWasWrongIsFoundOutAtALaterLayout(desktopColumn: Bool) throws {
    let (h, editor, mail) = bothDocked(settings: desktopColumn ? .withDesktopColumn : Settings())
    let hanging = try #require(h.layout?.overhangs.keys.first)
    // The sheet that kept it wide has closed.
    h.system.setMinimumSize(hanging, CGSize(width: 600, height: 400))
    h.scheduler.advance(by: 11 * 60)
    #expect(h.frame(editor) == editorFlushLeft && h.frame(mail) == mailFlushRight, "no timer, no second look")
    // Something else causes a layout.
    h.run("zoom \((hanging == editor ? mail : editor).rawValue)")
    h.run("back")
    #expect(h.layout?.overhangs.isEmpty == true)
    #expect(h.frame(editor).map { f in h.frame(mail).map { !f.overlaps($0) } } == true)
    expectWindowsMatchLayout(h)
  }
}
