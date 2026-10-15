import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A laptop's own 1440×900 display with a 25-point menu bar, and a 2560×1440 display to its right.
private let laptop = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
  visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true, name: "Built-in Retina Display",
  isBuiltIn: true)
private let studio = DisplaySnapshot(
  id: DisplayID("4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F"), frame: CGRect(x: 1440, y: 0, width: 2560, height: 1440),
  visibleFrame: CGRect(x: 1440, y: 0, width: 2560, height: 1440), isMain: false, name: "Studio Display")

/// A client of `arborctl watch`: keeps the lines it is sent.
@MainActor
private final class Listener {
  private var lines: [String] = []
  /// Nothing else holds it: the controller knows its observers weakly.
  private let feed: EventFeed

  init(_ controller: Controller, _ request: String) throws {
    feed = EventFeed(controller: controller)
    guard case .watch(let options) = try Command.parse(request) else { return }
    _ = feed.subscribe(options) { [weak self] line in self?.lines.append(line) }
  }

  /// The events since the last call.
  func take() throws -> [ArborEvent] {
    defer { lines.removeAll() }
    return try lines.map { try ArborEvent(line: $0) }
  }
}

/// Undo and redo (docs/features/F19-undo.md) where they meet the features that landed beside them: options per display
/// (F25), the events of `watch` (F24), "Go to…" (F27), automatic docking (F23), a held view (F58), apps that do not
/// answer, and the rule that the log sees no title and no name of a space.
@Suite @MainActor struct UndoMeetingsTests {
  /// Three floating windows of three apps, started.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  func undoLabels(_ h: Harness, on display: DisplayID? = nil) -> [String] {
    h.controller.undoHistory.steps(.undo, on: display ?? h.display).map(\.label)
  }

  func redoLabels(_ h: Harness, on display: DisplayID? = nil) -> [String] {
    h.controller.undoHistory.steps(.redo, on: display ?? h.display).map(\.label)
  }

  func frames(_ h: Harness) -> [WindowID: CGRect] {
    Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
  }

  /// The real log file, which every test writes to at once; at 2 MB it becomes arbor.log.1 and a new one is started. In this
  /// order: a line that moves between the two reads is read twice, not missed. Decoded leniently, because the last line may
  /// still be in the writing.
  func log() -> String {
    [ArborPaths.logFile, ArborPaths.logFile.appendingPathExtension("1")]
      .compactMap { try? Data(contentsOf: $0) }.map { String(decoding: $0, as: UTF8.self) }.joined()
  }

  /// A word nobody else uses, and no earlier run: the log outlives them all.
  func secret(_ word: String) -> String { "\(word)\(UInt32.random(in: 0...UInt32.max))" }

  // MARK: F25, options per display

  @Test func anUndoLaysEachDisplayOutWithItsOwnGap() {
    var settings = Settings()
    settings.displays = [DisplayOptions(match: .builtIn, gap: 6), DisplayOptions(match: .width(.atLeast, 2500), gap: 20)]
    let h = Harness(displays: [laptop, studio], settings: settings)
    let small = [
      h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400)),
      h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 500, height: 400)),
    ]
    let large = [
      h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 500, height: 400)),
      h.system.open(app: "Mail", frame: CGRect(x: 1800, y: 200, width: 500, height: 400)),
    ]
    h.start()
    for window in small + large { h.run("dock \(window.rawValue) left") }
    let docked = frames(h)

    for (display, windows, gap) in [(laptop, small, CGFloat(6)), (studio, large, CGFloat(20))] {
      h.system.cursor = display.frame.center
      h.system.userFocus(windows[0])
      #expect(h.run("float \(windows[1].rawValue)").ok)
      #expect(h.run("undo").message == "undid float \(windows[1])", "\(display.name)")
      #expect(frames(h) == docked, "\(display.name)")
      #expect(h.frame(windows[0])!.minX - h.frame(windows[1])!.maxX == gap, "between neighbours on \(display.name)")
      expectWindowsMatchLayout(h, on: display.id)
    }
  }

  @Test func aWindowSentToADisplayWithAnotherGapComesBackToItsSlot() {
    var settings = Settings()
    settings.displays = [DisplayOptions(match: .builtIn, gap: 6), DisplayOptions(match: .width(.atLeast, 2500), gap: 20)]
    let h = Harness(displays: [laptop, studio], settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Xcode", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) left")
    let before = frames(h)
    #expect(h.run("dock \(a.rawValue) beside \(b.rawValue) right").ok)
    #expect(h.frame(a)!.minX - h.frame(b)!.maxX == 20, "over there it keeps that display's distance")
    #expect(h.run("undo").ok)
    #expect(frames(h) == before)
    #expect(h.frame(a)!.minX == laptop.visibleFrame.minX + 6)
    for display in [laptop, studio] { expectWindowsMatchLayout(h, on: display.id) }
  }

  // MARK: F24, the events of `watch`

  @Test func watchHearsAnUndoAsTheWindowsThatChangedPlacesAndOneLayout() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let listener = try Listener(h.controller, "watch window layout")
    h.scheduler.advance(by: 0)
    _ = try listener.take()

    for (verb, change) in [("undo", ArborEvent.WindowChange.Change.floated), ("redo", .docked)] {
      #expect(h.run(verb).ok)
      h.scheduler.advance(by: 0)
      let events = try listener.take()
      let changes = events.compactMap { if case .window(let change) = $0 { change } else { nil } }
      #expect(changes.map(\.change) == [change], "\(verb): \(events)")
      #expect(changes.first?.window.id == b, "\(verb)")
      let layouts = events.compactMap { if case .layout(let layout) = $0 { layout } else { nil } }
      #expect(layouts.count == 1, "\(verb): \(events)")
      #expect(layouts.first?.frames == h.layout!.windowFrames.mapValues(ArborEvent.Rect.init), "\(verb)")
    }
  }

  @Test func watchHearsOfTheViewAnUndoSteppedOutTo() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("resize \(b.rawValue) left 100")
    h.run("zoom \(a.rawValue)")
    let listener = try Listener(h.controller, "watch view")
    h.scheduler.advance(by: 0)
    _ = try listener.take()
    #expect(h.run("undo").ok)
    h.scheduler.advance(by: 0)
    let views = try listener.take().compactMap { if case .view(let view) = $0 { view } else { nil } }
    #expect(views.last?.node == h.workspace.camera)
    #expect(h.workspace.camera != h.workspace.tree.leaf(containing: a), "it stepped out to show the change")
  }

  // MARK: F27, "Go to…"

  @Test func goingToAWindowIsNotAStepAndLeavesRedoAlone() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    h.run("zoom \(a.rawValue)")
    let (undos, redos) = (undoLabels(h), redoLabels(h))
    for command in ["reveal \(b.rawValue)", "find Safari", "find", "find", "reveal \(a.rawValue)"] {
      #expect(h.run(command).ok, "\(command)")
      #expect(undoLabels(h) == undos && redoLabels(h) == redos, "\(command)")
    }
    h.system.setMinimized(b, true)
    #expect(h.run("reveal \(b.rawValue)").ok)
    #expect(undoLabels(h) == undos && redoLabels(h) == redos, "nor is fetching it from the Dock")
    #expect(h.run("redo").message == "redid dock \(b) right")
    expectWindowsMatchLayout(h)
  }

  @Test func thePaletteClosesBeforeAnUndoChangesWhatItLists() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.run("find").ok)
    #expect(h.overlays.finder != nil)
    #expect(h.run("undo").ok)
    #expect(h.overlays.finder == nil)
  }

  @Test func whatThePaletteChoosesIsNotAStepEither() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    let undos = undoLabels(h)
    h.run("find")
    h.controller.finderChose(.window(b))
    #expect(h.layout!.windowFrames[b] != nil, "it is in view")
    #expect(undoLabels(h) == undos)
    #expect(h.run("undo").message == "undid dock \(b) right")
  }

  // MARK: F23, automatic docking

  @Test func aWindowThatDockedItselfIsUndockedByOneUndoAndRedoIsLeftAlone() {
    var settings = Settings()
    settings.newWindows = "dock"
    let (h, a, b, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("undo")
    let redos = redoLabels(h)
    #expect(redos == ["dock \(b) right"])

    let opening = CGRect(x: 300, y: 200, width: 640, height: 420)
    let new = h.system.open(app: "Terminal", pid: 1003, frame: opening)
    h.system.userFocus(new)
    h.scheduler.advance(by: 0)
    #expect(h.workspace.isDocked(new), "newWindows is \"dock\"")
    #expect(redoLabels(h) == redos, "nobody did anything")

    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(new), "it floats, and is not docked a second time")
    #expect(h.system.isVisible(new))
    #expect(h.workspace.isDocked(a))
    h.scheduler.advance(by: 5)
    #expect(h.workspace.isFloating(new), "nor a little later")
    expectWindowsMatchLayout(h)
  }

  // MARK: F54, arrangements as text

  @Test func aLineOfLayoutIsOneStep() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("save-view 1")
    let before = (h.workspace, frames(h), h.controller.parked)
    #expect(h.run("layout Notes | (Mail / Safari)").ok)
    let after = (h.workspace, frames(h), h.controller.parked)
    #expect(h.workspace.isDocked(a) && h.workspace.isDocked(b) && h.workspace.isDocked(c))

    #expect(h.run("undo").message == "undid layout Notes | (Mail / Safari)")
    #expect(h.workspace == before.0)
    #expect(frames(h) == before.1 && h.controller.parked == before.2)
    expectWindowsMatchLayout(h)
    #expect(h.run("redo").ok)
    #expect(h.workspace == after.0)
    #expect(frames(h) == after.1 && h.controller.parked == after.2)
    expectWindowsMatchLayout(h)
  }

  @Test func aWindowThatTookItsPlaceInALineLaterGoesAndComesWithTheLine() {
    let (h, a, b, _) = makeHarness()
    #expect(h.run("layout --open Safari | Xcode").ok)
    #expect(h.system.launchedApps == ["Xcode"])
    let steps = undoLabels(h)
    let late = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 200, y: 150, width: 700, height: 500))
    #expect(h.workspace.isDocked(late), "the line was waiting for it")
    #expect(undoLabels(h) == steps, "it is part of the line, not a change of its own")
    let whole = h.workspace

    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(a) && h.workspace.isFloating(b) && h.workspace.isFloating(late))
    #expect(h.system.isVisible(late))
    expectWindowsMatchLayout(h)
    // The line no longer waits: a second window of the app is a new window like any other.
    let second = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 260, y: 190, width: 700, height: 500))
    #expect(h.workspace.isFloating(second))

    #expect(h.run("redo").ok)
    #expect(h.workspace.tree.hasSameArrangement(as: whole.tree))
    #expect(h.workspace.isFloating(second))
    expectWindowsMatchLayout(h)
  }

  @Test func aFloatingWindowOfWhichAStripShowsIsStillInViewAfterUndoAndRedo() {
    // From the chaos lab. The Desktop is a tile, so no layout places the window: it is in view because it was. Pushed aside
    // until a strip shows, which is a place like any other (`Controller.reach`), it went out of view with the redo.
    var settings = Settings()
    settings.minimumUsableWidth = 800
    settings.minimumUsableHeight = 1
    let h = Harness(settings: settings)
    h.system.open(app: "Preview", pid: 1007, frame: CGRect(x: 78, y: 285, width: 329, height: 388))
    let b = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 500, y: 300, width: 397, height: 296))
    h.start()
    #expect(h.run("layout Preview | Xcode").ok)
    #expect(h.layout!.desktopFrame == nil, "the Desktop is a tile")
    let aside = CGRect(x: -350, y: 224, width: 397, height: 296)
    h.system.userMove(b, to: aside)
    let before = (h.workspace, frames(h))
    #expect(h.controller.parked.isEmpty)

    #expect(h.run("undo").ok)
    #expect(h.frame(b) == aside, "moved since, so it stays where it was put")
    #expect(h.run("redo").ok)
    #expect(h.controller.parked.isEmpty)
    #expect(h.workspace == before.0)
    #expect(frames(h) == before.1)
    expectWindowsMatchLayout(h)
  }

  @Test func aWindowLeftAsAStripGoesBackToItsStripWhenTheDockThatPushedItAsideIsUndone() {
    let h = Harness()
    let a = h.system.open(app: "Preview", pid: 1007, frame: CGRect(x: 78, y: 285, width: 329, height: 388))
    let b = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 500, y: 300, width: 397, height: 296))
    h.start()
    let aside = CGRect(x: -350, y: 224, width: 397, height: 296)
    h.system.userMove(b, to: aside)
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(b) != aside, "Preview has taken that side of the display")
    #expect(h.run("undo").ok)
    #expect(h.frame(b) == aside, "not pulled into full view, to jump back at the next layout")
    expectWindowsMatchLayout(h)
  }

  /// Five columns leave the Desktop too narrow to use. It is a tile, and part of the view.
  func makeFiveColumns() -> (Harness, floating: WindowID) {
    let h = Harness()
    for (index, app) in ["Safari", "Notes", "Mail", "Terminal", "Xcode"].enumerated() {
      h.system.open(app: app, pid: 1000 + Int32(index), frame: CGRect(x: 100 + 40 * index, y: 100, width: 600, height: 400))
    }
    let music = h.system.open(app: "Music", pid: 1005, frame: CGRect(x: 500, y: 350, width: 400, height: 300))
    h.start()
    #expect(h.run("layout Safari | Notes | Mail | Terminal | Xcode").ok)
    #expect(h.layout!.desktopFrame == nil && h.workspace.camera == h.workspace.tree.root)
    #expect(h.system.isVisible(music), "its windows are in view all the same, over the docked ones")
    return (h, music)
  }

  @Test func withTheDesktopATileInTheViewARedoTakesNoWindowMovedSinceOutOfView() {
    let (h, music) = makeFiveColumns()
    #expect(h.run("undo").ok)
    let place = CGRect(x: 600, y: 300, width: 400, height: 300)
    h.system.userMove(music, to: place)
    #expect(h.run("redo").ok)
    #expect(h.controller.parked.isEmpty)
    #expect(h.frame(music) == place)
    expectWindowsMatchLayout(h)
  }

  @Test func withTheDesktopATileInTheViewARedoTakesNoWindowOpenedSinceOutOfView() {
    let (h, _) = makeFiveColumns()
    #expect(h.run("undo").ok)
    let late = h.system.open(app: "Preview", pid: 1007, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    #expect(h.run("redo").ok)
    #expect(h.controller.parked.isEmpty)
    #expect(h.system.isVisible(late))
    expectWindowsMatchLayout(h)
  }

  @Test func withTheDesktopATileInTheViewAWindowThatFloatsAgainIsInView() {
    let (h, music) = makeFiveColumns()
    let xcode = WindowID(105)
    #expect(h.run("dock \(music.rawValue) beside \(xcode.rawValue) bottom").ok)
    // Looked elsewhere and back, so that where it floated is no longer "what was in view when the step was saved".
    h.run("zoom \(xcode.rawValue)")
    h.run("show-all")
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(music))
    #expect(h.controller.parked.isEmpty && h.system.isVisible(music))
    #expect(h.layout!.windowFrames.values.allSatisfy { $0 != h.frame(music) }, "and not left lying in the slot it had")
    expectWindowsMatchLayout(h)
  }

  @Test(arguments: [CGSize(width: 700, height: 500), CGSize(width: 1714, height: 2180)])
  func aWindowThatCameBackOverAFramedWindowIsStillThereAfterUndoAndRedo(size: CGSize) {
    // From the chaos lab, which found the second: half of a window larger than the display is never on the display, so its
    // place did not count as one, and it left the view when the redo put the framed window back.
    let h = Harness()
    let a = h.system.open(app: "Terminal", pid: 1003, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    let b = h.system.open(
      app: "Preview", pid: 1007, frame: CGRect(origin: CGPoint(x: 0, y: 25), size: size), minimumSize: size)
    h.system.setHidden(pid: 1007, true)
    h.run("zoom \(a.rawValue)")
    h.system.setHidden(pid: 1007, false)
    #expect(!h.controller.parked.contains(b) && h.frame(b)!.overlaps(h.system.displayList[0].frame), "back where it was when it went")
    let before = (h.workspace, frames(h))

    #expect(h.run("undo").message == "undid dock \(a) left")
    #expect(h.run("redo").ok)
    #expect(h.controller.parked.isEmpty)
    #expect(h.workspace == before.0)
    #expect(frames(h) == before.1)
  }

  /// Larger than the display, where its user left it, and pushed aside by the dock: the undo has to take it back there.
  @Test(arguments: [
    CGRect(x: -100, y: 25, width: 2000, height: 1500), CGRect(x: 0, y: 25, width: 1714, height: 2180),
    CGRect(x: -300, y: 40, width: 2400, height: 1400), CGRect(x: 200, y: 100, width: 1900, height: 1300),
  ])
  func aWindowLargerThanTheDisplayGoesBackWhereItWas(place: CGRect) {
    let h = Harness()
    let a = h.system.open(app: "Terminal", pid: 1003, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Preview", pid: 1007, frame: place)
    h.start()
    h.system.userMove(b, to: place)
    h.scheduler.advance(by: 2)
    let before = frames(h)
    h.run("dock \(a.rawValue) left")
    #expect(h.run("undo").ok)
    #expect(frames(h) == before, "neither made smaller nor slid onto the display")
    h.run("relayout")
    #expect(frames(h) == before, "nor only at the next layout")
  }

  // MARK: F18, a window that floats alone

  /// `opensLater`: where its app opened it is not a place anybody chose, and undo goes another way for such a window.
  @Test(arguments: [false, true]) func aWindowThatHadTheDesktopToItselfHasItAgainAfterAnUndo(opensLater: Bool) {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    if opensLater { h.start() }
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    if !opensLater { h.start() }
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(b) == h.layout!.desktopFrame, "alone on the Desktop, it takes all of it")
    let before = (h.workspace, frames(h))
    for change in ["dock \(b.rawValue) right", "redo"] {
      #expect(h.run(change).ok, "\(change)")
      #expect(h.run("undo").message == "undid dock \(b) right")
      #expect(h.workspace == before.0)
      #expect(frames(h) == before.1)
      h.run("relayout")
      #expect(frames(h) == before.1, "and it does not jump there only at the next layout")
    }
    expectWindowsMatchLayout(h)
  }

  /// Safari docked on the left, Notes alone on the Desktop, which it takes.
  func makeSoleFloat() -> (Harness, WindowID, WindowID) {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    h.start()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(b) == h.layout!.desktopFrame)
    return (h, a, b)
  }

  @Test func aWindowItsUserHadTakenInHandIsNotStretchedByAnUndo() {
    let (h, _, b) = makeSoleFloat()
    let place = CGRect(x: 900, y: 200, width: 400, height: 300)
    h.system.userMove(b, to: place)
    h.run("relayout")
    #expect(h.frame(b) == place, "it keeps the frame it was given (F18)")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("undo").ok)
    #expect(h.frame(b) == place)
    h.run("relayout")
    #expect(h.frame(b) == place, "nor by the next layout")
  }

  @Test func aWindowDraggedOutOntoTheEmptyDesktopIsNotStretchedByUndoAndRedo() {
    let (h, _, b) = makeSoleFloat()
    h.run("dock \(b.rawValue) right")
    let slot = h.frame(b)!
    h.system.drag(b, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 1000, y: 300), CGPoint(x: 900, y: 300)])
    #expect(h.workspace.isFloating(b))
    h.run("relayout")
    let before = (h.workspace, frames(h))
    #expect(h.frame(b) != h.layout!.desktopFrame, "what has just left the hand stays as it was dropped (F18)")
    #expect(h.run("undo").ok && h.workspace.isDocked(b))
    #expect(h.run("redo").ok)
    #expect(h.workspace == before.0 && frames(h) == before.1, "⌃⌥Z ⌃⌥⇧Z is nothing")
    h.run("relayout")
    #expect(frames(h) == before.1)
  }

  @Test func aWindowInHandThatNeitherStepWasAboutIsNotStretchedByUndoAndRedo() {
    let (h, _, b) = makeSoleFloat()
    let c = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 800, y: 300, width: 500, height: 300))
    h.run("dock \(b.rawValue) right")
    let place = CGRect(x: 560, y: 250, width: 300, height: 300)
    h.system.userMove(c, to: place)
    let before = frames(h)
    #expect(h.run("undo").ok && h.run("redo").ok)
    #expect(frames(h) == before)
    h.run("relayout")
    #expect(frames(h) == before)
  }

  @Test func aWindowThatFilledTheDesktopGetsItsOwnFrameWhenItComesBackToCompany() {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let h = Harness(settings: settings)
    h.start()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    // A frame its user gave it, while it had company and nothing was docked.
    let own = CGRect(x: 800, y: 300, width: 500, height: 300)
    h.system.userMove(b, to: own)
    h.run("dock \(a.rawValue) left")
    #expect(h.frame(b) == h.layout!.desktopFrame, "alone now, it takes the Desktop")
    h.run("dock \(b.rawValue) right")
    let c = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 560, y: 250, width: 300, height: 300))
    #expect(h.run("undo").ok)
    #expect(h.workspace.isFloating(b) && h.workspace.isFloating(c))
    #expect(h.frame(b) == own, "all of the Desktop was not a place anybody chose")
    let settled = frames(h)
    h.run("relayout")
    #expect(frames(h) == settled, "and it does not get there only at the next layout")
  }

  // MARK: F58, a held view

  @Test func whatIsDockedWhileTheViewIsHeldIsTakenBackAfterTheRelease() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let before = (h.workspace, frames(h))
    #expect(h.run("hold").ok)
    #expect(h.run("dock \(b.rawValue) right").ok, "both are in view, so the view stays as it is")
    #expect(!h.run("undo").ok)
    #expect(h.workspace.isDocked(b), "refused, and nothing has happened")
    #expect(h.run("release").ok)
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace == before.0)
    #expect(frames(h) == before.1)
    expectWindowsMatchLayout(h)
  }

  // MARK: F40, a pause

  @Test func aResizeAfterAPauseIsAStepOfItsOwn() {
    // From the independent review. The timer that ends the step finds Arbor paused and looks at nothing.
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("resize \(a.rawValue) right 40")
    h.run("pause")  // within the second in which another resize would go on with the step
    h.scheduler.advance(by: 60)
    h.run("resume")
    let width = h.frame(a)!.width
    h.run("resize \(a.rawValue) right 40")
    #expect(undoLabels(h) == ["dock \(a) left", "resize \(a) right", "resize \(a) right"])
    #expect(h.run("undo").ok)
    #expect(h.frame(a)!.width == width, "one undo takes back what was done after the pause, and no more")
  }

  @Test func aGapDraggedAfterAPauseIsAStepOfItsOwn() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    h.run("pause")  // with the button still down
    h.system.mouseDown = false
    h.scheduler.advance(by: 60)
    h.run("resume")
    h.system.mouseDown = true
    h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?.first), by: 40)
    h.system.mouseDown = false
    h.scheduler.advance(by: 1)
    #expect(undoLabels(h).count == 3)
  }

  // MARK: F20, names

  /// The pair exists only because it is named. Taking "Code" off first let it dissolve, and
  /// "Work" was then given to a node that was gone, which `setName` took for the root.
  @Test func aGroupRenamedSinceAStepKeepsItselfAndItsNewName() throws {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 200, y: 150, width: 500, height: 400))
    let c = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let d = h.system.open(app: "Terminal", pid: 1003, frame: CGRect(x: 400, y: 250, width: 500, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    h.run("dock \(c.rawValue) right")  // the view is on the pair Notes | Mail
    let pair = h.workspace.camera
    #expect(Set(h.workspace.tree.windows(under: pair)) == [b, c])
    #expect(h.run("name Code").ok)
    h.run("show-all")
    #expect(h.run("dock \(d.rawValue) beside \(a.rawValue) bottom").ok)  // the step
    h.run("go Code")
    #expect(h.run("name Work").ok)
    h.run("show-all")

    #expect(h.run("undo").message == "undid dock \(d) beside \(a) bottom")
    #expect(h.workspace.names == ["Work": pair], "\(h.workspace.names)")
    #expect(h.workspace.tree.contains(pair) && pair != h.workspace.tree.root)
    #expect(Set(h.workspace.tree.windows(under: pair)) == [b, c])
    expectWindowsMatchLayout(h)
  }

  // MARK: F22, the keyboard's tiling tools

  /// [Safari / Mail | Desktop | Notes] on the laptop with Safari focused and made wider, and a second display.
  func makeTiles() -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: [laptop, studio])
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    h.system.cursor = laptop.frame.center
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("resize \(a.rawValue) right 90")
    h.system.userFocus(a)
    h.scheduler.advance(by: 2)
    return (h, a, b, c)
  }

  @Test(arguments: [
    "swap down", "swap right", "grow", "shrink", "grow 60", "balance", "balance all", "rotate", "mirror", "move-to-display next",
  ])
  func eachOfTheTilingToolsIsOneStepThatGoesBackAndForth(command: String) {
    let (h, _, _, _) = makeTiles()
    let steps = undoLabels(h).count
    let before = (h.controller.workspaces, frames(h), h.controller.parked)
    #expect(h.run(command).ok, "\(command)")
    h.scheduler.advance(by: 2)
    let after = (h.controller.workspaces, frames(h), h.controller.parked)
    #expect(after.0 != before.0, "\(command) rearranges")
    #expect(undoLabels(h).count == steps + 1, "\(command): \(undoLabels(h))")
    for round in 1...2 {
      h.system.cursor = laptop.frame.center
      #expect(h.run("undo").ok, "\(command)")
      #expect(h.controller.workspaces == before.0, "undoing \(command), round \(round)")
      #expect(frames(h) == before.1 && h.controller.parked == before.2, "undoing \(command), round \(round)")
      #expect(h.run("redo").ok, "\(command)")
      #expect(h.controller.workspaces == after.0, "redoing \(command), round \(round)")
      #expect(frames(h) == after.1 && h.controller.parked == after.2, "redoing \(command), round \(round)")
      for display in [laptop, studio] { expectWindowsMatchLayout(h, on: display.id) }
    }
  }

  @Test func quickRepeatsOfGrowAreOneStepAndShrinkIsAnother() {
    let (h, a, _, _) = makeTiles()
    let (steps, width) = (undoLabels(h).count, h.frame(a)!.width)
    for _ in 1...4 { #expect(h.run("grow").ok) }
    #expect(undoLabels(h).count == steps + 1, "a dozen taps on a shortcut cost one undo")
    #expect(h.run("shrink").ok)
    #expect(undoLabels(h).suffix(2) == ["grow \(a)", "shrink \(a)"])
    #expect(h.run("undo").ok && h.run("undo").ok)
    #expect(h.frame(a)!.width == width)
  }

  @Test(arguments: ["focus right", "focus down", "focus next", "focus previous", "focus-display next"])
  func movingTheKeyboardIsNotAStep(command: String) {
    let (h, _, b, _) = makeTiles()
    h.run("float \(b.rawValue)")
    h.run("undo")
    let (undos, redos) = (undoLabels(h), redoLabels(h))
    _ = h.run(command)
    h.scheduler.advance(by: 2)
    #expect(undoLabels(h) == undos && redoLabels(h) == redos, "\(command)")
  }

  // MARK: F33, the switches

  @Test func aWindowClosedSinceLeavesTheRestoredArrangementAsTheSettingSays() {
    // Who gets the room of a window that leaves is a setting, also when it leaves an arrangement from the past.
    var widths: [Bool: CGFloat] = [:]
    for share in [true, false] {
      var settings = Settings()
      settings.shareRemovedSpace = share
      func row() -> (Harness, WindowID, WindowID, WindowID) {
        let (h, a, b, c) = makeHarness(settings: settings)
        h.run("dock \(a.rawValue) left")
        h.run("dock \(b.rawValue) beside \(a.rawValue) right")
        h.run("dock \(c.rawValue) beside \(b.rawValue) right")
        return (h, a, b, c)
      }
      let (plain, pa, pb, pc) = row()
      plain.system.close(pb)

      let (h, a, b, c) = row()
      h.run("float \(c.rawValue)")
      h.system.close(b)
      #expect(!h.run("undo").ok, "the closing cannot be taken back, which is said once")
      #expect(h.run("undo").message == "undid float \(c)")
      #expect(h.frame(a) == plain.frame(pa) && h.frame(c) == plain.frame(pc), "shareRemovedSpace \(share)")
      expectWindowsMatchLayout(h)
      widths[share] = h.frame(a)!.width
    }
    #expect(widths[true] != widths[false], "or this has tested nothing")
  }

  @Test func windowsThatWereMadeSmallOutOfViewComeBackAtTheirSizes() {
    var settings = Settings()
    settings.shrinkOutOfView = true
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = frames(h)
    h.run("resize \(b.rawValue) left 60")
    h.run("zoom \(a.rawValue)")
    #expect(!h.system.isVisible(b) && !h.system.isVisible(c))
    // Nothing of the resize shows while Safari is framed, so the view steps out, and everything comes back into view.
    #expect(h.run("undo").message == "undid resize \(b) left")
    #expect(frames(h) == before)
    expectWindowsMatchLayout(h)
  }

  @Test func withTheGapsNoHandlesADragOfOneIsNoStep() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let seam = try #require(h.overlays.seams[h.display]?.first)
    let steps = undoLabels(h)
    h.run("set gapHandles off")
    h.overlays.dragSeam(seam, by: 40)  // a handle that was still being dragged
    #expect(undoLabels(h) == steps)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("undo-continuation") })
  }

  // MARK: F63, the permission taken away

  @Test func theHistoryOutlivesALossOfThePermission() {
    let h = Harness()
    h.watchAccessibility()
    let a = h.system.open(app: "Safari", pid: 1000, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("resize \(b.rawValue) left 40")
    h.revokeAccessibility()  // within the second in which another resize would go on with the step
    h.scheduler.advance(by: 3)
    let refused = h.run("undo")
    #expect(!refused.ok && refused.message.contains("Accessibility"), "\(refused.message)")
    h.grantAccessibility()
    h.scheduler.advance(by: 10)
    #expect(h.controller.isRunning)
    h.run("resize \(b.rawValue) left 40")
    #expect(undoLabels(h).suffix(2) == ["resize \(b) left", "resize \(b) left"], "a step of its own, as after a pause")
    #expect(h.run("undo").ok && h.run("undo").ok)
    #expect(h.run("undo").message == "undid dock \(b) right")
    #expect(h.workspace.isFloating(b) && h.system.isVisible(b))
    expectWindowsMatchLayout(h)
  }

  // MARK: F43, saying what happened

  @Test func aShortcutsUndoSaysOnScreenWhatItTookBack() {
    // What changed is easy to miss, so both earn a line (`Command.worksUnseen`). On the display a person reads the menu's
    // language, "Undo Dock" there and "Undid Dock" here; a terminal keeps the words of commands (the product owner).
    let (h, a, b, _) = makeHarness()
    h.system.userFocus(a)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    func said(_ verb: String) -> [String] {
      let before = h.overlays.messages.count
      h.run(verb, from: .shortcut)
      return h.overlays.messages.dropFirst(before).map { "\($0.model.kind): \($0.model.text)" }
    }
    #expect(said("undo") == ["change: Undid Dock"])
    #expect(said("redo") == ["change: Redid Dock"])
    #expect(!h.overlays.messages.contains { $0.model.kind == .hint }, "nobody is taught to dock by going back and forth")
    #expect(said("redo") == ["problem: Nothing to redo"])
    h.run("float-all")
    #expect(said("undo") == ["change: Undid Float All"])
    #expect(h.run("redo", from: .script).message == "redid float-all")
    #expect(said("undo") == ["change: Undid Float All"])
    h.system.close(b)
    #expect(
      said("undo") == ["problem: Cannot undo the closing of a window of Notes; undo again to take back dock Safari left"])
    // A script reads its reply where it asked.
    let count = h.overlays.messages.count
    #expect(h.run("undo").ok)
    #expect(h.overlays.messages.count == count)
  }

  // MARK: F26, the minimap

  @Test func anOpenMinimapShowsTheArrangementTheUndoPutBack() throws {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(h.run("minimap").ok)
    let two = try #require(h.overlays.minimaps[h.display])
    #expect(h.run("undo").ok)
    let one = try #require(h.overlays.minimaps[h.display], "it stays, and never shows an arrangement that is no longer there")
    #expect(two.items.map(\.window) == [a, b] && one.items.map(\.window) == [a])
    #expect(h.run("redo").ok)
    #expect(h.overlays.minimaps[h.display] == two)
  }

  // MARK: Apps that do not answer

  @Test func aWindowWhoseAppDoesNotAnswerIsDockedAgainWhenItDoes() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let slot = h.frame(a)!
    h.run("float \(a.rawValue)")
    let floating = h.frame(a)!
    #expect(floating != slot)

    h.system.setUnresponsive(pid: 1000, true)
    #expect(h.run("undo").ok)
    #expect(h.workspace.isDocked(a), "the arrangement is the old one")
    #expect(h.frame(a) == floating, "the window cannot be moved yet")
    h.system.setUnresponsive(pid: 1000, false)
    h.scheduler.advance(by: 5)
    #expect(h.frame(a) == slot)
    expectWindowsMatchLayout(h)
  }

  @Test func aWindowOutOfViewWhoseAppDoesNotAnswerIsNotLostByAnUndoThatBringsItBack() {
    let (h, a, b, _) = makeHarness()
    // Safari floats on the Desktop; Notes is docked and framed, which takes the Desktop out of view.
    h.run("dock \(b.rawValue) left")
    h.run("zoom \(b.rawValue)")
    #expect(!h.system.isVisible(a))

    h.system.setUnresponsive(pid: 1000, true)
    #expect(h.run("undo").message == "undid dock \(b) left")
    #expect(h.workspace.isFloating(a) && h.workspace.isFloating(b))
    #expect(h.controller.parked.contains(a), "it is where it was, and still counts as out of view, or nothing would fetch it")
    h.system.setUnresponsive(pid: 1000, false)
    h.scheduler.advance(by: 5)
    #expect(h.system.isVisible(a), "fetched as soon as its app answers")
    #expect(!h.controller.parked.contains(a))
    expectWindowsMatchLayout(h)
  }

  // MARK: What was left hanging by hand

  /// Where Safari's user left it, by hand: over an edge of the screen, across the two displays, or well inside. And where the
  /// pointer is: on the display the window belongs to, which is where a scripted `undo` acts.
  nonisolated static let hangs: [(name: String, frame: CGRect, pointer: CGPoint)] = [
    ("across the two, mostly on the big one", CGRect(x: 1300, y: 300, width: 600, height: 400), CGPoint(x: 2600, y: 400)),
    ("over the big one's far edge", CGRect(x: 3700, y: 300, width: 600, height: 400), CGPoint(x: 2600, y: 400)),
    ("over the big one's bottom", CGRect(x: 1800, y: 1300, width: 600, height: 400), CGPoint(x: 2600, y: 400)),
    ("a strip at the laptop's left", CGRect(x: -560, y: 300, width: 600, height: 400), CGPoint(x: 700, y: 450)),
    ("over the laptop's bottom", CGRect(x: 400, y: 780, width: 600, height: 400), CGPoint(x: 700, y: 450)),
    ("across the two, mostly on the laptop", CGRect(x: 1000, y: 300, width: 600, height: 400), CGPoint(x: 700, y: 450)),
    ("well inside", CGRect(x: 1700, y: 200, width: 500, height: 350), CGPoint(x: 2600, y: 400)),
  ]

  /// Each takes back everything it did.
  nonisolated static let waysThereAndBack: [[String]] = [
    ["dock 101 left", "undo"], ["dock 101 left", "undo", "redo", "undo"], ["dock 101 left", "float 101", "undo", "undo"],
    ["dock 101 top", "resize 101 bottom 60", "undo", "undo"], ["arrange", "undo"], ["arrange all", "undo"],
    ["dock 101 left", "float-all", "undo", "undo"], ["toggle-float 101", "toggle-float 101", "undo", "undo"],
    ["dock 101 left", "move-to-display next 101", "undo", "undo"],
    ["dock 101 right", "undo", "redo", "undo", "redo", "undo"], ["layout Safari | Notes", "undo"],
  ]

  /// It comes back where it hung. Whatever fits the frames Arbor gives back to the display must leave
  /// alone what its user left there, by whichever road undo gives it back; and no layout afterwards may think otherwise.
  @Test(arguments: hangs.indices, waysThereAndBack) func whatWasLeftHangingByHandComesBackWhereItHung(hang: Int, way: [String]) {
    let (name, place, pointer) = Self.hangs[hang]
    let h = Harness(displays: [laptop, studio])
    h.start()
    // It opens on the display it is then left hanging on. A move that arrives across a border without a drag is not taken for
    // a hand's (an app, a tool or macOS does that), and such a place is fitted like any other that nobody chose.
    let opensAt = studio.frame.contains(pointer) ? CGPoint(x: 2400, y: 500) : CGPoint(x: 300, y: 200)
    let safari = h.system.open(app: "Safari", pid: 1000, frame: CGRect(origin: opensAt, size: CGSize(width: 600, height: 400)))
    h.system.open(app: "Notes", pid: 1001, frame: CGRect(x: 500, y: 300, width: 500, height: 350))
    h.system.open(app: "Mail", pid: 1002, frame: CGRect(x: 1800, y: 250, width: 500, height: 350))
    h.scheduler.advance(by: 2)
    h.system.userMove(safari, to: place)
    h.scheduler.advance(by: 2)
    h.system.userFocus(safari)
    h.system.cursor = pointer
    h.run("relayout")
    let before = (h.controller.workspaces, frames(h), h.controller.parked)
    #expect(h.frame(safari) == place, "\(name): no layout touches it to begin with")

    for command in way {
      #expect(h.run(command).ok, "\(name), \(way): \(command)")
      h.scheduler.advance(by: 2)
    }
    #expect(frames(h) == before.1, "\(name), \(way): Safari is at \(h.frame(safari)!)")
    #expect(h.controller.workspaces == before.0 && h.controller.parked == before.2, "\(name), \(way)")
    h.run("relayout")
    h.scheduler.advance(by: 2)
    #expect(frames(h) == before.1, "\(name), \(way): nor does the next layout move it: Safari is at \(h.frame(safari)!)")
  }

  // MARK: A long way back and forth

  /// Everything a person could tell apart: the arrangements, who is out of view, and where each of the others is.
  private struct Picture: Equatable {
    var workspaces: [DisplayID: Workspace]
    var parked: Set<WindowID>
    var frames: [WindowID: CGRect]

    @MainActor init(_ h: Harness) {
      workspaces = h.controller.workspaces
      parked = h.controller.parked
      frames = [:]
      for window in h.system.allWindows() where !h.controller.parked.contains(window.id) { frames[window.id] = window.frame }
    }

    /// What a person would see differently, for the message of a test that fails.
    func differences(from other: Picture) -> String {
      var found: [String] = []
      if workspaces != other.workspaces { found.append("the workspaces differ") }
      if parked != other.parked { found.append("out of view \(parked.sorted()), not \(other.parked.sorted())") }
      for window in Set(frames.keys).union(other.frames.keys).sorted() where frames[window] != other.frames[window] {
        found.append("\(window) at \(frames[window].map { "\($0)" } ?? "nowhere"), not \(other.frames[window].map { "\($0)" } ?? "nowhere")")
      }
      return found.joined(separator: "; ")
    }
  }

  /// Six windows, so that the Desktop is now wide, now narrow, now a tile; changes of every kind, by command and by hand.
  /// In three worlds: the windows were there when Arbor started; they opened later, so that each is where its app put it,
  /// which is not a place anybody chose; and with that, every switch that changes where windows go is the other way round.
  @Test(arguments: ["there at the start", "opened later", "every switch thrown"])
  func twentyChangesOfEveryKindGoBackAndForthToTheSamePictures(world: String) throws {
    var settings = Settings()
    settings.tabsEnabled = true
    if world == "every switch thrown" {
      settings.soleFloatTakesDesktop = true
      settings.shrinkOutOfView = true
      settings.shareRemovedSpace = false
      settings.makeRoom = false
    }
    let h = Harness(settings: settings)
    if world != "there at the start" { h.start() }
    for (index, app) in ["Safari", "Notes", "Mail", "Terminal", "Xcode", "Music"].enumerated() {
      h.system.open(
        app: app, pid: 1000 + Int32(index), frame: CGRect(x: 80 + 60 * index, y: 80 + 40 * index, width: 520, height: 380))
    }
    if world == "there at the start" { h.start() }
    h.scheduler.advance(by: 2)
    func drag(_ id: UInt32, to end: CGPoint) {
      let start = h.frame(WindowID(id))!
      let grab = CGPoint(x: start.midX, y: start.minY + 10)
      h.system.drag(WindowID(id), through: [grab, CGPoint(x: (grab.x + end.x) / 2, y: (grab.y + end.y) / 2), end])
    }
    func pull(_ id: UInt32, bottom points: CGFloat) {
      var frame = h.frame(WindowID(id))!
      frame.size.height += points
      h.system.userResize(WindowID(id), to: frame)
    }
    func gap(_ index: Int, by delta: CGFloat) throws {
      h.overlays.dragSeam(try #require(h.overlays.seams[h.display]?[index]), by: delta)
    }
    let changes: [(String, () throws -> Void)] = [
      ("dock 101 left", { h.run("dock 101 left") }), ("dock 102 right", { h.run("dock 102 right") }),
      ("dock 103 below 101", { h.run("dock 103 beside 101 bottom") }), ("resize 101", { h.run("resize 101 right 80") }),
      ("drag 104 to the right", { drag(104, to: CGPoint(x: 1300, y: 450)) }), ("a gap", { try gap(0, by: 40) }),
      ("float 102", { h.run("float 102") }), ("dock 102 beside 103", { h.run("dock 102 beside 103 right") }),
      ("pull 101", { pull(101, bottom: 60) }), ("arrange", { h.run("arrange") }), ("float-all", { h.run("float-all") }),
      ("layout", { h.run("layout Safari | (Notes / Mail) | Desktop") }), ("dock 104 top", { h.run("dock 104 top") }),
      ("toggle-float 104", { h.run("toggle-float 104") }), ("dock 105 below 101", { h.run("dock 105 beside 101 bottom") }),
      ("drag 106 onto 101", { drag(106, to: CGPoint(x: 300, y: 300)) }), ("resize 103", { h.run("resize 103 top 50") }),
      ("float 103", { h.run("float 103") }), ("five columns", { h.run("layout Safari | Notes | Mail | Terminal | Xcode") }),
      ("dock 106 below 105", { h.run("dock 106 beside 105 bottom") }),
    ]
    var pictures = [Picture(h)]
    var made: [String] = []
    for (name, change) in changes {
      let steps = undoLabels(h).count
      try change()
      h.scheduler.advance(by: 2)  // whatever is left open for more of the same closes
      // `layout` squeezes windows that are where their apps put them onto the Desktop's own width, and every layout after
      // it lets them have the margin beside it as well (`floatingRegion`). Not undo's affair: the picture that lasts counts.
      if ["layout", "five columns"].contains(name) { h.run("relayout") }
      // Where a pointer lands differs from world to world: a drop that rearranges nothing is no step.
      guard undoLabels(h).count != steps else { continue }
      #expect(undoLabels(h).count == steps + 1, "\(world): \(name) is one step")
      made.append(name)
      pictures.append(Picture(h))
    }
    #expect(made.count >= 18, "\(world): \(made)")

    for round in 1...2 {
      for (index, picture) in pictures.dropLast().enumerated().reversed() {
        #expect(h.run("undo").ok)
        #expect(Picture(h) == picture, "\(world), round \(round): undoing \(made[index]): \(Picture(h).differences(from: picture))")
        expectWindowsMatchLayout(h)
      }
      #expect(!h.run("undo").ok)
      for (index, picture) in pictures.dropFirst().enumerated() {
        #expect(h.run("redo").ok)
        #expect(Picture(h) == picture, "\(world), round \(round): redoing \(made[index]): \(Picture(h).differences(from: picture))")
        expectWindowsMatchLayout(h)
      }
      #expect(!h.run("redo").ok)
    }
  }

  // MARK: The log

  @Test func noPartOfATitleReachesTheLogThroughTheNameOfAStep() {
    // `layout` can pick a window by part of its title.
    let (word, app) = (secret("Xochimilco"), secret("Safari"))
    let h = Harness()
    h.system.open(app: app, title: "\(word) figures", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.system.open(app: "Mail", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    #expect(h.run("layout \(app)~\(word) | Mail").ok)
    #expect(h.run("undo").ok)
    #expect(h.run("redo").ok)
    #expect(!undoLabels(h).joined().contains(word), "what is not in the label cannot get out of it: \(undoLabels(h))")
    let log = log()
    #expect(!log.contains(word))
    #expect(log.contains("undo: undid layout \(app)~… | Mail"), "the lines of this very run are among those looked through")
  }

  @Test func noNameOfASpaceReachesTheLogThroughTheNameOfAStep() throws {
    // The name is taken off between the change and its undo, so by then nothing knows the word for a name.
    let word = secret("Popocatepetl")
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let safari = try #require(h.workspace.tree.leaf(containing: a))
    let column = try #require(h.workspace.tree.parent(of: safari))
    h.run("zoom-node \(column.rawValue)")
    #expect(h.run("name \(word)").ok)
    h.run("show-all")
    let seam = try #require(h.overlays.seams[h.display]?.first { $0.leading == column || $0.trailing == column })
    h.overlays.dragSeam(seam, by: 40)
    #expect(undoLabels(h).last?.hasPrefix("drag the gap between") == true)
    #expect(h.run("unname \(word)").ok)
    #expect(h.run("undo").ok)
    #expect(h.run("redo").ok)
    #expect(!(undoLabels(h) + redoLabels(h)).joined().contains(word))
    #expect(!log().contains(word))
  }

  @Test func takingOffTheNameThatHeldAGroupTogetherIsAStepThatDoesNotSayTheName() throws {
    let word = secret("Citlaltepetl")
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let safari = try #require(h.workspace.tree.leaf(containing: a))
    let column = try #require(h.workspace.tree.parent(of: safari))
    h.run("zoom-node \(column.rawValue)")
    #expect(h.run("name \(word)").ok)
    h.run("show-all")
    h.run("float \(b.rawValue)")
    #expect(h.workspace.tree.contains(column), "one window is left in it, and the name keeps it (F62)")
    #expect(h.run("unname \(word)").ok)
    #expect(!h.workspace.tree.contains(column))
    #expect(undoLabels(h).last == "unname")
    #expect(h.controller.nextStepTitle(.undo) == "Unname")
    #expect(h.run("undo").message == "undid unname")
    #expect(h.workspace.names.keys.contains(word), "group and name are back")
    // Called something else since: the old word is in no list of names any more when the step is named again.
    h.run("zoom-node \(column.rawValue)")
    #expect(h.run("name \(secret("Orizaba"))").ok)
    #expect(h.run("redo").message == "redid unname")
    #expect(!log().contains(word))
  }

  @Test func noNameOfASpaceReachesTheLogThroughADropBesideIt() throws {
    let word = secret("Iztaccihuatl")
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b, c) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let leaf = try #require(h.workspace.tree.leaf(containing: a))
    h.run("zoom \(a.rawValue)")
    #expect(h.run("name \(word)").ok)
    h.run("show-all")
    // Dropped on the middle of Safari: a tab of the space that has the name.
    let grabbed = h.frame(c)!
    h.system.drag(c, through: [CGPoint(x: grabbed.midX, y: grabbed.minY + 10), h.frame(a)!.center])
    #expect(h.workspace.tree.leaf(containing: c) == leaf, "\(h.controller.asciiDrawing())")
    #expect(h.run("unname \(word)").ok)
    #expect(h.run("undo").ok)
    #expect(!(undoLabels(h) + redoLabels(h)).joined().contains(word))
    #expect(!log().contains(word))
  }
}
