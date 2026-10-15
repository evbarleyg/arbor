import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

private let notesFrame = CGRect(x: 800, y: 300, width: 500, height: 400)
private let safariFrame = CGRect(x: 100, y: 200, width: 600, height: 450)

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
/// What the standard display, 1440 × 900, becomes.
private let smaller = DisplaySnapshot(
  id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
  visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)

/// How a docked window leaves the arrangement, but for a drag, where the place is the hand's.
enum WayOut: String, CaseIterable, Sendable {
  case float, toggleFloat = "toggle-float", floatAll = "float-all", pause, quit, exclude

  @MainActor func take(_ window: WindowID, _ h: Harness) {
    switch self {
    case .float, .toggleFloat: #expect(h.run("\(rawValue) \(window.rawValue)").ok)
    case .floatAll, .pause: #expect(h.run(rawValue).ok)
    case .quit: h.controller.shutdown()
    case .exclude:
      let app = h.system.allWindows().first { $0.id == window }.flatMap(\.bundleID) ?? ""
      #expect(h.run("exclude \(app)").ok)
    }
  }
}

/// There and back is nothing: a window that is docked and leaves the arrangement again has the frame it had, size and place
/// (docs/features/F48-floating-restores-size.md). Floated by a key it used to have its size back somewhere else, and one pushed
/// aside until a strip showed came back from a quit in the middle of the screen. One function, one answer, on every way out.
@Suite @MainActor struct FloatGivesThePlaceBackTests {
  /// As Arbor ships: a floating window's frame is its person's.
  func makeHarness(settings: Settings = Settings(), displays: [DisplaySnapshot]? = nil) -> (Harness, WindowID, WindowID) {
    let h = displays.map { Harness(displays: $0, settings: settings) } ?? Harness(settings: settings)
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    let safari = h.system.open(app: "Safari", frame: safariFrame)
    h.start()
    return (h, notes, safari)
  }

  func moves(of window: WindowID, _ h: Harness) -> Int { h.system.frameLog.filter { $0.window == window }.count }

  // MARK: Where it was

  /// The key is `toggle-float`; the menu and arborctl have both.
  @Test(arguments: WayOut.allCases) func dockedByAKeyItIsWhereItWasOnEveryWayOut(way: WayOut) {
    let (h, notes, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    #expect(h.frame(notes) != notesFrame)
    h.system.clearFrameLog()
    way.take(notes, h)
    #expect(h.frame(notes) == notesFrame)
    #expect(moves(of: notes, h) == 1, "no detour on the way")
  }

  @Test func floatedItIsRememberedThereAndTheLayoutAgrees() {
    let (h, notes, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    #expect(h.workspace.floating[notes] == notesFrame)
    #expect(h.workspace.undockedFrames?[notes] == nil, "it floats, so there is nothing left to go back to")
    expectWindowsMatchLayout(h, on: h.display)
  }

  /// It stays there: no later layout has another idea.
  @Test func itStaysThereWhateverIsDockedNext() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    h.run("dock \(safari.rawValue) right")
    h.run("relayout")
    h.scheduler.runPending()
    #expect(h.frame(notes) == notesFrame)
  }

  /// A floating window's frame is its person's, and this is the one they gave it.
  @Test func overAWindowThatStaysDockedToo() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(notes.rawValue) left")
    let neighbour = try #require(h.frame(safari))
    #expect(neighbour.overlaps(notesFrame), "or this tests nothing")
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes) == notesFrame)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func howeverOftenItGoesThereAndBack() {
    let (h, notes, _) = makeHarness()
    for edge in ["left", "right", "left"] {
      h.run("dock \(notes.rawValue) \(edge)")
      h.run("toggle-float \(notes.rawValue)")
      #expect(h.frame(notes) == notesFrame)
    }
  }

  /// ⌃⌥F twice is still a return to its slot (Controller+FloatAndBack.swift).
  @Test func theKeyPressedAgainDocksItWhereItWas() throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(notes.rawValue) left")
    let slot = try #require(h.frame(notes))
    h.run("toggle-float \(notes.rawValue)")
    #expect(h.run("toggle-float \(notes.rawValue)").message.contains("where it was"))
    #expect(h.frame(notes) == slot)
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  /// A key is no hand: it is the arrangement that changed, not where the window lay before there was one.
  @Test func movedFromSlotToSlotByKeysItStillGoesBack() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(notes.rawValue) left")
    var slots = [h.frame(notes)]
    for command in ["dock \(notes.rawValue) right", "dock \(notes.rawValue) left", "resize \(notes.rawValue) right 60"] {
      #expect(h.run(command).ok, "\(command)")
      #expect(h.frame(notes) != slots.last, "\(command) moved it, or this tests nothing")
      slots.append(h.frame(notes))
    }
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes) == notesFrame)
  }

  /// Nor is a slot that a hand chose a place on the desk: it is a place in the arrangement. The window's own frame is still the
  /// one it had before it was docked, and quitting, a pause and Float All have always given it that.
  @Test func draggedFromSlotToSlotByHandItStillGoesBack() {
    let (h, notes, safari) = makeHarness()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) left")
    let before = h.frame(notes)
    h.system.drag(notes, through: [CGPoint(x: 200, y: 45), CGPoint(x: 900, y: 300), CGPoint(x: 1438, y: 400)])
    #expect(h.workspace.isDocked(notes))
    #expect(h.frame(notes) != before, "or this tests nothing")
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes) == notesFrame)
  }

  /// What is remembered of a drag to an edge is where it began.
  @Test func dockedByADragItGoesBackToWhereTheDragBegan() {
    let (h, notes, _) = makeHarness()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(notes, through: [CGPoint(x: 1000, y: 310), CGPoint(x: 400, y: 350), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isDocked(notes))
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes) == notesFrame)
  }

  /// Dragged to an edge of another display it belongs there, and what is remembered is as far from that display's corner.
  @Test func dockedOnAnotherDisplayItGoesToWhatIsRememberedThere() throws {
    let (h, notes, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(notes, through: [CGPoint(x: 1000, y: 310), CGPoint(x: 2000, y: 300), CGPoint(x: 2718, y: 400)])
    let remembered = try #require(h.controller.workspaces[side.id]?.undockedFrame(of: notes))
    #expect(side.visibleFrame.contains(remembered))
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes) == remembered)
    #expect(h.controller.workspaces[side.id]?.floating[notes] == remembered)
  }

  /// Out of view, with the Desktop out of view too: it is where it was at once, since no view keeps a floating window away. One that makes way
  /// waits, and is where it was when the Desktop comes back.
  @Test(arguments: [false, true]) func floatedWhileOutOfViewItIsWhereItWas(makingWay: Bool) {
    let (h, notes, safari) = makeHarness(settings: makingWay ? .makingWay : Settings())
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.run("float \(notes.rawValue)")
    if makingWay {
      #expect(!h.system.isVisible(notes), "floating windows that make way live on the Desktop, which is out of view")
    } else {
      #expect(h.frame(notes) == notesFrame)
    }
    h.run("show-all")
    // (On the Desktop beside Safari, if it makes way: at its own size, pushed aside.)
    #expect(makingWay ? h.system.isVisible(notes) && h.frame(notes)?.size == notesFrame.size : h.frame(notes) == notesFrame)
  }

  // MARK: In front

  /// What names a window gives it the keyboard, and with it the front. Where it was lies under a window that stays docked and
  /// was used last: behind that one it would look lost.
  @Test(arguments: ["float", "toggle-float"]) func namedWhileAnotherWindowIsInFrontItComesToTheFront(command: String) throws {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(safari)
    #expect(try #require(h.frame(safari)).overlaps(notesFrame), "or this tests nothing")
    #expect(h.system.windowsFrontToBack().first == safari)
    h.system.clearRaiseLog()
    h.run("\(command) \(notes.rawValue)")
    #expect(h.frame(notes) == notesFrame)
    #expect(h.system.windowsFrontToBack().first == notes)
    #expect(h.system.focusedWindow() == notes, "by the keyboard")
    #expect(h.system.raiseLog.isEmpty, "not by a raise, which does not lift it over the window that is worked in on a Mac")
  }

  /// With ⌃⌥F it has the keyboard already.
  @Test func withTheKeyboardAlreadyNothingIsAsked() {
    let (h, notes, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.system.userFocus(notes)
    let asked = h.system.focusRequests.count
    h.run("toggle-float")
    #expect(h.frame(notes) == notesFrame)
    #expect(h.system.focusRequests.count == asked)
  }

  /// One that makes way waits for the Desktop out of view: whoever has the keyboard keeps it, and the view stays.
  @Test func outOfViewItIsNotGivenTheKeyboard() {
    let (h, notes, safari) = makeHarness(settings: .makingWay)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    let camera = h.workspace.camera
    h.run("float \(notes.rawValue)")
    h.scheduler.runPending()
    #expect(h.system.focusedWindow() == safari)
    #expect(h.workspace.camera == camera)
    #expect(!h.system.isVisible(notes))
  }

  /// As Arbor ships it comes into view over the framed window, which the command named it for: in front, with the keyboard, and the view stays.
  @Test func floatedFromOutOfViewItComesToTheFrontOfTheFramedWindow() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    let camera = h.workspace.camera
    h.run("float \(notes.rawValue)")
    h.scheduler.runPending()
    #expect(h.frame(notes) == notesFrame && h.workspace.camera == camera)
    #expect(h.system.focusedWindow() == notes && h.system.windowsFrontToBack().first == notes)
  }

  /// Floating the framed window moves the view. The keyboard goes to the window named, and to nobody else on the way. Across apps a
  /// Mac moves the keyboard only after the call has returned: asked in the same breath, it still names nobody.
  @Test func framedAndNamedFromElsewhereNobodyElseIsHandedTheKeyboardOnTheWay() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.system.userFocus(safari)
    h.run("zoom \(notes.rawValue)")
    h.system.userFocusesNothing()
    h.system.focusIsSlow = true
    let asked = h.system.focusRequests.count
    h.run("float \(notes.rawValue)")
    #expect(Array(h.system.focusRequests.dropFirst(asked)) == [notes])
    h.system.finishSlowFocus()
    #expect(h.system.focusedWindow() == notes)
  }

  /// Float All names nobody.
  @Test func floatAllGivesNobodyTheKeyboard() {
    let (h, notes, safari) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(safari)
    let asked = h.system.focusRequests.count
    h.run("float-all")
    #expect(h.system.focusRequests.count == asked)
    #expect(h.system.focusedWindow() == safari)
  }

  // MARK: What hangs over an edge

  /// Pushed aside until a strip shows, or let down until only its title bar does, by its person's own hand: that is a place,
  /// and a hand can get hold of it there.
  @Test(
    arguments: WayOut.allCases,
    [CGRect(x: 1340, y: 300, width: 500, height: 400), CGRect(x: 300, y: 850, width: 500, height: 400)])
  func leftHangingOverAnEdgeByAHandItHangsThereAgain(way: WayOut, aside: CGRect) {
    let (h, notes, _) = makeHarness()
    h.system.userMove(notes, to: aside)
    h.run("dock \(notes.rawValue) left")
    h.system.clearFrameLog()
    way.take(notes, h)
    #expect(h.frame(notes) == aside)
    #expect(moves(of: notes, h) == 1, "there, and not fetched from there")
  }

  @Test func andNoLaterLayoutFetchesIt() {
    let (h, notes, safari) = makeHarness()
    let aside = CGRect(x: 1340, y: 300, width: 500, height: 400)
    h.system.userMove(notes, to: aside)
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    h.run("dock \(safari.rawValue) left")
    h.run("relayout")
    h.scheduler.runPending()
    #expect(h.frame(notes) == aside)
  }

  /// Found by a walk: 50 points of a window showed, where its app had opened it. A key docked it, and a quit gave it back fitted in.
  @Test(arguments: WayOut.allCases) func whereItsAppOpenedItMostlyOffTheScreenToo(way: WayOut) {
    let (h, _, _) = makeHarness()
    let corner = CGRect(x: 1390, y: 700, width: 723, height: 566)
    let preview = h.system.open(app: "Preview", frame: corner, minimumSize: CGSize(width: 723, height: 400))
    #expect(h.frame(preview) == corner, "Arbor leaves it where it opened")
    h.run("dock \(preview.rawValue) top")
    #expect(h.workspace.isDocked(preview))
    way.take(preview, h)
    #expect(h.frame(preview) == corner)
  }

  /// Where Arbor lets go nothing stays docked that anything would have to make way for.
  @Test(arguments: [WayOut.floatAll, .pause, .quit]) func lettingGoIsTheSameWhereFloatingWindowsMakeWay(way: WayOut) {
    let (h, notes, _) = makeHarness(settings: .makingWay)
    let aside = CGRect(x: 1340, y: 300, width: 500, height: 400)
    h.system.userMove(notes, to: aside)
    h.run("dock \(notes.rawValue) left")
    way.take(notes, h)
    #expect(h.frame(notes) == aside)
  }

  // MARK: What is no place

  /// All of it was in view. The display has shrunk, and now a third of it would hang over the edge, where nobody put it.
  @Test(arguments: [WayOut.float, .toggleFloat]) func whatAChangeOfDisplaysLeftHangingIsNoPlace(way: WayOut) throws {
    let (h, notes, _) = makeHarness()
    h.system.userMove(notes, to: CGRect(x: 700, y: 300, width: 500, height: 400))
    h.run("dock \(notes.rawValue) left")
    h.system.setDisplays([smaller])
    h.scheduler.runPending()
    way.take(notes, h)
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 500, height: 400))
    #expect(smaller.visibleFrame.contains(frame), "all of it is in view, as it was before the key gave places back")
  }

  /// A hand left it across two displays, where all of it showed. The one next door goes: its own display is as it was, two thirds of
  /// the window would still show, and nobody chose that.
  @Test(arguments: [WayOut.float, .toggleFloat]) func whatTheDisplayNextDoorShowedIsGoneWithIt(way: WayOut) throws {
    let (h, notes, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    let across = CGRect(x: 1100, y: 300, width: 500, height: 400)
    h.system.userMove(notes, to: across)
    #expect(h.workspace.floating[notes] == across, "it belongs to the display most of it is on, or this tests nothing")
    h.run("dock \(notes.rawValue) left")
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    #expect(h.workspace.undockedFrame(of: notes) == across, "or this tests nothing")
    way.take(notes, h)
    let frame = try #require(h.frame(notes))
    #expect(frame.size == across.size)
    #expect(h.visibleFrame.contains(frame))
  }

  /// The note of whose hand left it there is not saved: after a new start nobody knows.
  @Test func afterANewStartNobodyVouchesForWhatHangs() throws {
    let (old, notes, safari) = makeHarness()
    old.system.userMove(notes, to: CGRect(x: 1340, y: 300, width: 500, height: 400))
    old.run("dock \(notes.rawValue) left")
    old.scheduler.runPending()
    let h = Harness(settings: Settings(), saved: old.store.saved)
    for window in old.system.allWindows() {
      h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(h.workspace.isDocked(notes))
    h.run("float \(notes.rawValue)")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 500, height: 400))
    #expect(h.visibleFrame.contains(frame))
    _ = safari
  }

  /// Frames macOS gives no window, whoever vouches for them. Asked for, the answer would be another, and what is remembered a
  /// frame the window never has.
  @Test(
    arguments: WayOut.allCases,
    [
      CGRect(x: 0, y: 25, width: 1500, height: 300),  // wider than the display
      CGRect(x: 300, y: 25, width: 400, height: 900),  // higher
      CGRect(x: 300, y: 5, width: 400, height: 300),  // its title bar under the menu bar
      CGRect(x: 300, y: 880, width: 400, height: 300),  // lower than anybody but a hand can put a window
    ])
  func aFrameNoWindowCanHaveIsNotAskedFor(way: WayOut, frame: CGRect) throws {
    let (h, notes, _) = makeHarness()
    h.system.userMove(notes, to: frame)
    h.run("dock \(notes.rawValue) left")
    h.system.clearFrameLog()
    way.take(notes, h)
    #expect(h.visibleFrame.contains(try #require(h.frame(notes))))
    // What Arbor asked for, not what came of it: macOS, and the fake, cut a window that is too large.
    let asked = h.system.moveLog.dropFirst(h.system.movesWhenTheFrameLogWasCleared).filter { $0.window == notes }.map(\.requested)
    #expect(!asked.isEmpty && asked.allSatisfy { h.visibleFrame.contains($0) }, "\(asked)")
    if [.float, .toggleFloat, .floatAll].contains(way) {
      #expect(h.workspace.floating[notes] == h.frame(notes), "and what is remembered is what it has")
    }
  }

  // MARK: One window with no place to go back to: as before

  /// Notes and Safari lie at the bottom right, are docked, and the display shrinks: where they lay is beyond it now.
  func makeHarnessWithNoPlaceToGoBackTo(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let (h, notes, safari) = makeHarness(settings: settings)
    let mail = h.system.open(app: "Mail", frame: CGRect(x: 60, y: 100, width: 300, height: 200))
    h.system.userMove(notes, to: CGRect(x: 1000, y: 560, width: 400, height: 300))
    h.system.userMove(safari, to: CGRect(x: 1010, y: 570, width: 380, height: 280))
    return (h, notes, safari, mail)
  }

  func shrinkTheDisplay(_ h: Harness) {
    h.system.setDisplays([smaller])
    h.scheduler.runPending()
  }

  @Test func itTakesItsSizeCentredOnItsSlotInOneMove() throws {
    let (h, notes, safari, _) = makeHarnessWithNoPlaceToGoBackTo()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    shrinkTheDisplay(h)
    let slot = try #require(h.layout?.windowFrames[notes])
    h.system.clearFrameLog()
    h.run("float \(notes.rawValue)")
    let centred = CGRect(x: (slot.midX - 200).rounded(), y: (slot.midY - 150).rounded(), width: 400, height: 300)
    #expect(h.frame(notes) == centred.fitted(into: smaller.visibleFrame), "its own size, which still fits, and all of it in view")
    #expect(moves(of: notes, h) == 1, "no detour on the way")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func framedItTakesItsSizeInAViewThatShowsTheDesktop() throws {
    let (h, notes, safari, _) = makeHarnessWithNoPlaceToGoBackTo()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    shrinkTheDisplay(h)
    h.run("zoom \(notes.rawValue)")
    h.run("float \(notes.rawValue)")
    #expect(h.layout?.desktopFrame != nil, "the view shows the Desktop")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 400, height: 300))
    #expect(smaller.visibleFrame.contains(frame))
  }

  @Test func withTheDesktopOutOfViewItIsCentredOnItsSlotToo() throws {
    let (h, notes, safari, mail) = makeHarnessWithNoPlaceToGoBackTo()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    shrinkTheDisplay(h)
    let tree = h.workspace.tree
    let leaf = try #require(tree.leaf(containing: notes))
    let column = try #require(tree.parent(of: leaf))
    h.run("zoom-node \(column.rawValue)")
    let slot = try #require(h.layout?.windowFrames[notes])
    h.run("float \(notes.rawValue)")
    #expect(h.layout?.desktopFrame == nil, "the view stays on what is left of the group")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 400, height: 300))
    #expect(abs(frame.midX - slot.midX) <= 0.5 && abs(frame.midY - slot.midY) <= 0.5)
  }

  /// A tab that is not showing has no slot of its own: it comes out where its group is.
  @Test func aTabThatIsNotShowingComesOutWhereItsGroupIs() throws {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, notes, safari, _) = makeHarnessWithNoPlaceToGoBackTo(settings: settings)
    h.run("dock \(safari.rawValue) left")
    h.system.drag(notes, through: [CGPoint(x: 1200, y: 570), try #require(h.frame(safari)).center])
    let group = try #require(h.workspace.tree.leaf(containing: safari))
    #expect(h.workspace.tree.leaf(containing: notes) == group, "they share a place")
    shrinkTheDisplay(h)
    let place = try #require(h.layout?.nodeFrames[group])
    h.run("float \(safari.rawValue)")
    let frame = try #require(h.frame(safari))
    #expect(frame.size == CGSize(width: 380, height: 280))
    #expect(h.system.isVisible(safari))
    #expect(abs(frame.midY - place.midY) <= 1)
  }

  /// There the layout keeps floating windows off the docked ones that stay, and would push it away again at once.
  @Test func whereFloatingWindowsMakeWayOneWindowIsPutOnTheDesktopAsBefore() throws {
    let (h, notes, safari) = makeHarness(settings: .makingWay)
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame != notesFrame)
    #expect(!frame.overlaps(try #require(h.frame(safari))))
  }
}
