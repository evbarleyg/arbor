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
@MainActor private let main = FakeWindowSystem.standardDisplay

private let notesFrame = CGRect(x: 300, y: 200, width: 400, height: 300)
private let safariFrame = CGRect(x: 520, y: 90, width: 800, height: 600)
private let mailFrame = CGRect(x: 60, y: 400, width: 640, height: 420)

/// The same windows seen by a new Arbor process that starts from what `old` saved.
@MainActor
private func relaunch(_ old: Harness, displays: [DisplaySnapshot]? = nil) -> Harness {
  let new = Harness(displays: displays ?? old.system.displayList, saved: old.store.saved)
  for window in old.system.allWindows() {
    new.system.open(
      app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
  }
  return new
}

/// A window that floats again gets its old size back (docs/features/F48-floating-restores-size.md).
@Suite @MainActor struct UndockedFrameTests {
  /// Notes (400 × 300), Safari and Mail, all floating.
  func makeHarness(settings: Settings = Harness.settingsWhenNoneAreGiven) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    let safari = h.system.open(app: "Safari", frame: safariFrame)
    let mail = h.system.open(app: "Mail", frame: mailFrame)
    h.start()
    return (h, notes, safari, mail)
  }

  // MARK: float, toggle-float

  /// Criterion 1. (Centred on its slot if it cannot go back: `FloatGivesThePlaceBackTests`.)
  @Test func aFloatedWindowTakesItsOldFrame() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let slot = try #require(h.layout?.windowFrames[notes])
    #expect(h.frame(notes) == slot)
    #expect(slot.size != notesFrame.size)

    #expect(h.run("float \(notes.rawValue)").ok)
    let frame = try #require(h.frame(notes))
    #expect(frame == notesFrame, "size and place")
    #expect(h.workspace.floating[notes] == frame)
    #expect(h.workspace.undockedFrames?[notes] == nil, "it floats, so there is nothing left to go back to")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aFloatedWindowIsMovedOnce() {
    let (h, notes, _, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.system.clearFrameLog()
    h.run("float \(notes.rawValue)")
    #expect(h.system.frameLog.filter { $0.window == notes }.count == 1, "no detour on the way")
  }

  /// Criterion 2.
  @Test func floatingAFramedWindowShowsTheDesktop() throws {
    let (h, notes, safari, mail) = makeHarness()
    // `[(safari / notes / mail) | Desktop]`: one column, 402 points wide, and the Desktop has what is left, the middle of the display with
    // it. A window that floats takes its own size around where it was, whatever is docked there (F64), and framed it was everywhere.
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(safari.rawValue) bottom")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.run("resize \(safari.rawValue) right -300")
    h.run("zoom \(notes.rawValue)")
    #expect(h.frame(notes)?.width == h.visibleFrame.width - 24, "framed, it fills the display")
    var cameraChanges = 0
    h.controller.observe { if case .camera = $0 { cameraChanges += 1 } }

    #expect(h.run("float \(notes.rawValue)").ok)
    #expect(h.layout?.desktopFrame != nil, "the view shows the Desktop")
    #expect(h.frame(notes) == notesFrame)
    #expect(h.workspace.camera == h.workspace.tree.root)
    #expect(cameraChanges == 1, "whoever mirrors the view hears that it moved")
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func floatingAFramedWindowFramesTheDesktopIfItWouldBeATile() throws {
    let (h, notes, safari, mail) = makeHarness(settings: .withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) right")
    h.run("resize \(notes.rawValue) right 250")
    #expect(h.layout?.tiles.map(\.kind) == [.desktop], "squeezed between them, the Desktop is a tile")
    h.run("zoom \(notes.rawValue)")
    h.run("float \(notes.rawValue)")
    #expect(h.workspace.camera == h.workspace.tree.desktop)
    #expect(h.frame(notes)?.size == notesFrame.size)
    #expect(h.system.isVisible(notes))
    for window in [safari, mail] { #expect(!h.system.isVisible(window)) }
  }

  @Test func withTheDesktopOutOfViewAFloatedWindowStaysInView() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    let tree = h.workspace.tree
    let leaf = try #require(tree.leaf(containing: notes))
    let column = try #require(tree.parent(of: leaf))
    h.run("zoom-node \(column.rawValue)")

    h.run("float \(notes.rawValue)")
    #expect(h.layout?.desktopFrame == nil, "the view stays on what is left of the group")
    let frame = try #require(h.frame(notes))
    #expect(frame == notesFrame)
    #expect(h.visibleFrame.contains(frame))
  }

  @Test func aWindowFloatedWhileOutOfViewWaitsForTheDesktopAtItsOldSize() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(notes))

    h.run("float \(notes.rawValue)")
    #expect(!h.system.isVisible(notes), "floating windows live on the Desktop, which is out of view")
    h.run("show-all")
    #expect(h.system.isVisible(notes))
    #expect(h.frame(notes)?.size == notesFrame.size)
  }

  @Test func togglingTwiceGivesTheSizeBack() {
    let (h, notes, _, _) = makeHarness()
    h.system.userFocus(notes)
    #expect(h.run("toggle-float").ok)
    #expect(h.workspace.isDocked(notes))
    #expect(h.frame(notes)?.size != notesFrame.size)
    #expect(h.run("toggle-float").ok)
    #expect(h.workspace.isFloating(notes))
    #expect(h.frame(notes)?.size == notesFrame.size)
  }

  @Test func whatCountsIsWhereTheUserLastPutIt() {
    let (h, notes, _, _) = makeHarness()
    let moved = CGRect(x: 700, y: 300, width: 520, height: 360)
    h.system.userMove(notes, to: moved)
    h.run("dock \(notes.rawValue) left")
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes)?.size == moved.size)
  }

  /// The product owner's replay: ⌃⌥A then ⌃⌥F, a newcomer's likeliest route.
  @Test func afterArrangeAFloatedWindowHasItsOwnSizeThoughTheDesktopIsNarrow() throws {
    let (h, notes, safari, _) = makeHarness(settings: .withDesktopColumn)
    h.system.open(app: "Slack")
    h.run("arrange")
    let desktop = try #require(h.layout?.desktopFrame)
    #expect(desktop.width < safariFrame.width)
    h.system.clearFrameLog()

    h.run("float \(safari.rawValue)")
    let frame = try #require(h.frame(safari))
    #expect(frame.size == safariFrame.size, "not squeezed: it was put there on purpose, like a dropped window")
    #expect(h.visibleFrame.contains(frame), "kept on the display")
    #expect(frame.overlaps(try #require(h.layout?.desktopFrame)), "on the Desktop as far as it fits")
    #expect(h.workspace.floating[safari] == frame)
    #expect(h.system.frameLog.filter { $0.window == safari }.count == 1)

    // Nor by what happens to the arrangement afterwards.
    h.run("resize \(notes.rawValue) right 40")
    #expect(h.frame(safari) == frame)
    h.run("dock \(safari.rawValue) right")
    #expect(h.workspace.undockedFrame(of: safari)?.size == safariFrame.size)
  }

  /// The chaos lab's story. After `arrange all` two large windows leave the third a tile and the Desktop a tile too.
  /// Floating the tile's window frees its slot, and the layout that follows gives that room to the Desktop (F61).
  func harnessWithATileAndTheDesktopATile() throws -> (Harness, WindowID, CGRect) {
    let h = Harness()
    h.system.open(app: "Preview", frame: CGRect(x: 243, y: 96, width: 81, height: 90))
    let musicFrame = CGRect(x: 380, y: 60, width: 855, height: 800)
    let music = h.system.open(app: "Music", frame: musicFrame, minimumSize: musicFrame.size)
    h.system.open(
      app: "Xcode", frame: CGRect(x: 409, y: 181, width: 1015, height: 584),
      minimumSize: CGSize(width: 1015, height: 584))
    h.start()
    h.run("arrange all")
    #expect(try #require(h.layout).tiles.contains { $0.windows == [music] })
    #expect(h.layout?.desktopFrame == nil)
    #expect(!h.system.isVisible(music))
    return (h, music, musicFrame)
  }

  @Test(.withTiles) func aTilesWindowFloatedWhileTheDesktopIsATileTooComesIntoViewWithTheDesktop() throws {
    for command in ["float", "toggle-float"] {
      let (h, music, musicFrame) = try harnessWithATileAndTheDesktopATile()
      h.system.clearFrameLog()
      #expect(h.run("\(command) \(music.rawValue)").ok)
      // (Xcode and Preview leave the Desktop 137 points, and no docked window becomes a tile for its sake: F61. It stays a tile,
      // and what floats on it shows over the arrangement.)
      let frame = try #require(h.frame(music))
      #expect(h.system.isVisible(music), "\(command): it floats, and nothing appears")
      #expect(h.visibleFrame.contains(frame))
      #expect(frame.size == musicFrame.size)
      #expect(h.workspace.floating[music] == frame)
      #expect(h.system.frameLog.filter { $0.window == music }.count == 1, "in one move")
      // The next layout has nothing to add.
      let desktop = h.layout?.desktopFrame
      h.run("relayout")
      #expect(h.frame(music) == frame)
      #expect(h.layout?.desktopFrame == desktop)
    }
  }

  @Test(.withTiles) func aFramedWindowFloatedWhileTheDesktopIsATileIsInViewToo() throws {
    let (h, music, musicFrame) = try harnessWithATileAndTheDesktopATile()
    h.run("zoom \(music.rawValue)")
    #expect(h.system.isVisible(music))
    h.run("float \(music.rawValue)")
    #expect(h.system.isVisible(music))
    #expect(h.frame(music)?.size == musicFrame.size)
    #expect(h.visibleFrame.contains(try #require(h.frame(music))))
    // The Desktop is part of the view: with its rectangle, where it has room at all.
    let tree = h.workspace.tree
    #expect(tree.subtree(try #require(h.layout).camera, contains: tree.desktop))
    #expect(h.layout?.desktopFrame != nil || !tree.desktopHasRoom)
  }

  @Test func theTwoWaysToFloatAgreeOnTheSize() throws {
    for way in ["float", "drag"] {
      let (h, _, safari, _) = makeHarness()
      h.system.open(app: "Slack")
      h.run("arrange")
      if way == "float" {
        h.run("float \(safari.rawValue)")
      } else {
        let slot = try #require(h.frame(safari))
        // Arranged, the windows leave the Desktop no room to drop it on: a plain drag takes a docked window out anywhere.
        h.system.drag(safari, through: [CGPoint(x: slot.midX, y: slot.minY + 10), CGPoint(x: 1380, y: 300)], plainly: true)
      }
      #expect(h.workspace.isFloating(safari), "\(way)")
      #expect(h.frame(safari)?.size == safariFrame.size, "\(way)")
    }
  }

  @Test func theReplySaysWhenTheViewMoved() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    #expect(h.run("float \(safari.rawValue)").message == "\(safari) is floating")
    h.run("zoom \(notes.rawValue)")
    #expect(h.run("float \(notes.rawValue)").message == "\(notes) is floating; showing the Desktop")
  }

  // MARK: With the Desktop out of view

  /// The product owner's replay: float out of a group view, walk away, come back.
  @Test func aWindowFloatedOutOfAGroupViewComesBackWithThatView() throws {
    let (h, notes, _, _) = makeHarness()
    h.system.open(app: "Slack")
    h.run("arrange")
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    #expect(h.layout?.desktopFrame == nil)
    h.run("float \(notes.rawValue)")
    let frame = try #require(h.frame(notes))
    #expect(h.system.isVisible(notes))
    #expect(h.workspace.guests?[notes] != nil, "it belongs to the view it floats over")

    #expect(h.run("neighbor right").ok)
    #expect(!h.system.isVisible(notes))
    #expect(h.run("back").ok)
    #expect(h.frame(notes) == frame)
  }

  @Test func aGuestToggledTwiceIsAGuestAgain() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(safari.rawValue) bottom")
    h.run("zoom \(safari.rawValue)")
    let guest = h.system.open(app: "Dialog", frame: CGRect(x: 400, y: 300, width: 500, height: 300))
    #expect(h.workspace.guests?[guest] != nil)
    h.run("toggle-float \(guest.rawValue)")
    #expect(h.workspace.isDocked(guest))
    #expect(h.layout?.desktopFrame == nil)
    h.run("toggle-float \(guest.rawValue)")
    #expect(h.workspace.guests?[guest] == h.workspace.tree.leaf(containing: safari), "of the same host")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: safari))
    #expect(h.frame(guest)?.size == CGSize(width: 500, height: 300))
  }

  @Test func aWindowDroppedWithTheDesktopOutOfViewBelongsToThatViewToo() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    let leaf = try #require(h.workspace.tree.leaf(containing: notes))
    h.run("zoom-node \(try #require(h.workspace.tree.parent(of: leaf)).rawValue)")
    let slot = try #require(h.frame(notes))
    h.system.drag(notes, through: [CGPoint(x: slot.midX, y: slot.minY + 10), try #require(h.frame(mail)).center], plainly: true)
    #expect(h.workspace.isFloating(notes))
    #expect(h.workspace.guests?[notes] != nil)
  }

  @Test func whoeverWantsFloatingWindowsOnTheDesktopGetsNoGuests() {
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let (h, notes, _, _) = makeHarness(settings: settings)
    h.system.open(app: "Slack")
    h.run("arrange")
    h.run("zoom \(notes.rawValue)")
    h.run("out")
    h.run("float \(notes.rawValue)")
    #expect(h.workspace.guests == nil)
    #expect(h.system.isVisible(notes), "it stays until the view next moves, like a new window")
  }

  // MARK: Moving a docked window

  /// Criterion 4.
  @Test func movingADockedWindowAroundDoesNotChangeWhatIsRemembered() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    for edge in ["right", "right", "down", "left", "up", "left", "left"] { h.run("dock \(notes.rawValue) \(edge)") }
    h.run("dock \(notes.rawValue) beside \(mail.rawValue) top")
    h.run("resize \(notes.rawValue) bottom 60")
    h.system.drag(notes, through: [CGPoint(x: 700, y: 300), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isDocked(notes))
    #expect(h.workspace.undockedFrames == [notes: notesFrame, safari: safariFrame, mail: mailFrame])
  }

  @Test func resizingADockedWindowByItsEdgeDoesNotChangeWhatIsRemembered() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) right")
    var frame = try #require(h.frame(notes))
    frame.size.width += 120
    h.system.userResize(notes, to: frame)
    h.scheduler.runPending()
    #expect(h.frame(notes)?.width == frame.width, "the gap moved")
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  // MARK: float-all

  /// Criterion 3, first half.
  @Test func floatAllPutsEveryWindowBackExactlyWhereItWas() {
    let (h, notes, safari, mail) = makeHarness()
    #expect(h.run("arrange").ok)
    #expect(h.workspace.floating.isEmpty)
    #expect(h.run("float-all").ok)
    #expect(h.frame(notes) == notesFrame)
    #expect(h.frame(safari) == safariFrame)
    #expect(h.frame(mail) == mailFrame)
    #expect(h.workspace.floating == [notes: notesFrame, safari: safariFrame, mail: mailFrame])
    #expect(h.workspace.undockedFrames == nil)
  }

  @Test func aWindowLeftHangingOverAScreenEdgeGoesBackThere() {
    let (h, notes, safari, _) = makeHarness()
    let overTheBottom = CGRect(x: 500, y: 720, width: 400, height: 300)
    let overTheRight = CGRect(x: 1000, y: 90, width: 800, height: 600)
    h.system.userMove(notes, to: overTheBottom)
    h.system.userMove(safari, to: overTheRight)
    h.run("arrange")
    h.run("float-all")
    #expect(h.frame(notes) == overTheBottom)
    #expect(h.frame(safari) == overTheRight)
    h.run("arrange")
    h.controller.shutdown()
    #expect(h.frame(notes) == overTheBottom)
    #expect(h.frame(safari) == overTheRight)
  }

  /// (Mostly off the display, where a hand left it with its title bar within reach, is a place: `FloatGivesThePlaceBackTests`.)
  @Test(arguments: [
    CGRect(x: 1430, y: 90, width: 800, height: 600),  // less of its title bar shows than a hand could get hold of
    CGRect(x: 300, y: 5, width: 400, height: 300),  // its title bar under the menu bar
    CGRect(x: -3000, y: -2000, width: 400, height: 300),  // nowhere
    CGRect(x: 0, y: 25, width: 1500, height: 300),  // wider than the display
  ])
  func aRememberedFrameThatIsNoPlaceForAWindowIsFittedIntoTheDisplay(_ frame: CGRect) throws {
    let (h, notes, _, _) = makeHarness()
    h.system.userMove(notes, to: frame)
    // However it got there, it belongs to this display.
    h.run("dock \(notes.rawValue) left")
    h.run("float-all")
    #expect(h.visibleFrame.contains(try #require(h.frame(notes))))
    #expect(h.workspace.floating[notes] == h.frame(notes), "fitted by Arbor, not cut by macOS")
  }

  @Test(.withTiles) func floatAllReachesWindowsFramedOutOfViewMinimizedAndInTiles() {
    let (h, notes, safari, mail) = makeHarness()
    let wide = h.system.open(
      app: "Xcode", frame: CGRect(x: 100, y: 100, width: 1250, height: 700),
      minimumSize: CGSize(width: 1250, height: 700))
    // Not in the new window: for the one with the keyboard the others would lend of their own room, and be the tiles.
    h.system.userFocus(notes)
    h.run("arrange")
    #expect(h.layout?.tiles.contains { $0.windows == [wide] } == true, "it refused its slot")
    h.system.setMinimized(mail, true)
    h.run("zoom \(notes.rawValue)")

    h.run("float-all")
    #expect(h.frame(notes) == notesFrame, "framed")
    #expect(h.frame(safari) == safariFrame, "out of view")
    #expect(h.frame(mail) == mailFrame, "minimized: it must not come back in the shape of its slot")
    #expect(h.frame(wide) == CGRect(x: 100, y: 100, width: 1250, height: 700), "a tile")
    #expect(h.controller.parked.isEmpty)
  }

  @Test func floatAllMovesEachWindowOnce() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.system.clearFrameLog()
    h.run("float-all")
    for window in [notes, safari, mail] {
      #expect(h.system.frameLog.filter { $0.window == window }.count == 1, "\(window)")
    }
  }

  // MARK: Dragging out of a slot

  @Test func aWindowDraggedOutOfItsSlotShrinksBackUnderThePointer() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) bottom")
    let drop = CGPoint(x: 1000, y: 300)
    h.system.clearFrameLog()
    // The fake grabs the title bar in the middle, 10 points below the top.
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: 500, y: 200), drop])

    #expect(h.workspace.isFloating(notes))
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.midX == drop.x, "the pointer is as far along the title bar as it was")
    #expect(frame.minY == drop.y - 10, "and as far below the top")
    #expect(h.workspace.floating[notes] == frame)
    #expect(h.system.frameLog.filter { $0.window == notes }.count == 1, "one move: it does not jump about")
    #expect(h.overlays.preview == nil)
  }

  @Test func aWindowGrabbedNearItsCornerKeepsThePointerNearThatCorner() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) bottom")
    let slot = try #require(h.frame(notes))
    // By hand, because the fake's `drag` always grabs the middle: pressed a tenth of the way along.
    let grab = CGPoint(x: slot.minX + slot.width / 10, y: slot.minY + 14)
    let drop = CGPoint(x: 900, y: 400)
    h.system.mouseDown = true
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(notes, at: grab)
    h.system.cursor = drop
    h.system.userMove(notes, to: slot.offsetBy(dx: drop.x - grab.x, dy: drop.y - grab.y))
    h.controller.dragMoved(notes, to: drop)
    h.system.mouseDown = false
    h.controller.dragEnded(notes, at: drop)

    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.minX == drop.x - notesFrame.width / 10)
    #expect(frame.minY == drop.y - 14)
  }

  /// The product owner's replay: a slot narrower than the window, dropped near the right edge.
  @Test func aWindowThatGrowsAtTheDropSlidesBackOntoTheDisplayUnderThePointer() throws {
    let (h, _, safari, _) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    let slot = try #require(h.frame(safari))
    #expect(slot.width < safariFrame.width)
    let drop = CGPoint(x: 1300, y: 300)
    h.system.drag(safari, through: [CGPoint(x: slot.midX, y: slot.minY + 10), drop])
    let frame = try #require(h.frame(safari))
    #expect(frame.size == safariFrame.size)
    #expect(frame.maxX == h.visibleFrame.maxX, "slid in from 1700")
    #expect(frame.minX <= drop.x && drop.x <= frame.maxX)
    #expect(frame.minY == drop.y - 10, "the pointer is still on the title bar")
  }

  @Test func droppedLowItSlidesUpOnlyAsFarAsThePointerStaysOnTheTitleBar() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) bottom")
    let drop = CGPoint(x: 1000, y: 800)
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), drop])
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.minY == drop.y - 28, "up from 790, and no further")
  }

  @Test func aStaleFrameNeverPutsTheWindowAwayFromThePointer() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) bottom")
    // macOS reports moves a few times a second: here, none since the drag began.
    let drop = CGPoint(x: 760, y: 500)
    h.system.heldModifiers = DragDocks.key
    h.controller.dragBegan(notes, at: CGPoint(x: 200, y: 50))
    h.controller.dragEnded(notes, at: drop)
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.minX <= drop.x && drop.x <= frame.maxX)
    #expect(frame.minY <= drop.y && drop.y <= frame.minY + 60, "the pointer is over the top of the window")
  }

  @Test func aWindowDroppedOverDockedWindowsFloatsThereAtItsOldSize() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let target = try #require(h.frame(safari)).center
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), target], plainly: true)
    #expect(h.workspace.isFloating(notes), "dragged plainly it floats anywhere")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.midX == target.x)
  }

  @Test(arguments: [false, true]) func aDroppedWindowStaysUnderThePointerThoughTheDesktopMovesAway(makingWay: Bool) throws {
    let (h, notes, safari, mail) = makeHarness(settings: (makingWay ? Settings.makingWay : Settings()).withDesktopColumn)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let before = try #require(h.layout?.desktopFrame)
    if makingWay {
      #expect(before.contains(try #require(h.frame(mail))), "another floating window, on the Desktop")
    } else {
      #expect(h.frame(mail) == mailFrame, "another floating window, where its person has it")
    }
    let drop = CGPoint(x: before.maxX - 20, y: 300)
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), drop])

    // With its slot closed, Safari has grown over the place where it was dropped.
    let desktop = try #require(h.layout?.desktopFrame)
    #expect(!desktop.contains(drop))
    #expect(try #require(h.frame(notes)).midX == drop.x, "what the user has just put down is not snatched away")
    if makingWay {
      #expect(desktop.contains(try #require(h.frame(mail))), "the others follow the Desktop as ever")
    } else {
      #expect(h.frame(mail) == mailFrame, "and the others stay as ever")
    }
  }

  @Test func droppingAWindowBackOnItsSlotKeepsItDockedAndRemembered() throws {
    let (h, notes, _, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    let slot = try #require(h.frame(notes))
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: slot.midX, y: slot.midY)])
    #expect(h.workspace.isDocked(notes))
    #expect(h.frame(notes) == slot)
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  @Test func aDragThatIsCalledOffPutsTheWindowBackInItsSlotStillRemembered() throws {
    let (h, notes, _, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    let slot = try #require(h.frame(notes))
    h.system.mouseDown = true
    h.system.heldModifiers = DragDocks.key  // held by whoever means to dock, as Arbor ships
    h.controller.dragBegan(notes, at: CGPoint(x: slot.midX, y: slot.minY + 10))
    h.system.userMove(notes, to: slot.offsetBy(dx: 300, dy: 100))
    h.system.mouseDown = false
    h.controller.dragCancelled(notes)
    h.scheduler.runPending()
    #expect(h.frame(notes) == slot)
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  @Test func draggingAWindowToAnEdgeRemembersWhereItWasBeforeTheDrag() {
    let (h, notes, _, _) = makeHarness()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(notes, through: [CGPoint(x: 500, y: 210), CGPoint(x: 200, y: 300), CGPoint(x: 2, y: 400)])
    #expect(h.workspace.isDocked(notes))
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  @Test func draggingAFloatingWindowAboutDoesNotResizeIt() {
    let (h, notes, _, _) = makeHarness()
    h.system.clearFrameLog()
    h.system.drag(notes, through: [CGPoint(x: 500, y: 210), CGPoint(x: 800, y: 500)])
    #expect(h.system.frameLog.isEmpty)
    #expect(h.frame(notes)?.size == notesFrame.size)
  }

  // MARK: The focus ring

  @Test func theFocusRingFollowsTheWindowToItsOldSize() {
    func ringProblem(_ h: Harness, _ window: WindowID) -> String? {
      ScenarioExpectation.check(["ring", "\(window.rawValue)"], harness: h, lastCommandOK: true)
    }
    let (h, notes, safari, _) = makeHarness(settings: .withRing)
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) beside \(notes.rawValue) bottom")
    h.system.userFocus(notes)
    h.run("float")
    #expect(h.frame(notes)?.size == notesFrame.size)
    #expect(ringProblem(h, notes) == nil)

    h.run("dock beside \(safari.rawValue) top")
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: 1000, y: 300)])
    h.scheduler.advance(by: 1)
    #expect(h.frame(notes)?.size == notesFrame.size)
    #expect(ringProblem(h, notes) == nil)
  }

  // MARK: Tabs

  @Test func aTabThatFloatsGetsItsOwnSizeBack() throws {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, notes, _, mail) = makeHarness(settings: settings)
    h.run("dock \(mail.rawValue) left")
    h.system.drag(notes, through: [CGPoint(x: 500, y: 210), try #require(h.frame(mail)).center])
    let group = try #require(h.workspace.tree.leaf(containing: mail))
    #expect(h.workspace.tree.leaf(containing: notes) == group, "they share a place")

    // The tab that is not showing.
    h.run("float \(mail.rawValue)")
    #expect(h.frame(mail) == mailFrame, "it comes out where it was")
    #expect(h.system.isVisible(mail))
    // Torn off with the mouse.
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: 1000, y: 300)])
    #expect(h.workspace.isFloating(notes))
    #expect(h.frame(notes)?.size == notesFrame.size)
  }

  /// macOS's own window tabs (Terminal, Finder): the tab in front is another window with another number.
  @Test func aNativeTabInFrontInheritsWhatWasRemembered() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let tab = try #require(h.system.openTab(in: notes))
    #expect(h.workspace.isDocked(tab))
    #expect(h.workspace.undockedFrames == [tab: notesFrame, safari: safariFrame], "nothing is left under the old number")
    h.run("float \(tab.rawValue)")
    #expect(h.frame(tab)?.size == notesFrame.size)
  }

  // MARK: Quit, pause, exclude

  /// Criterion 3, second half.
  @Test func quittingPutsEveryWindowBackExactlyWhereItWas() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.run("zoom \(safari.rawValue)")
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame)
    #expect(h.frame(safari) == safariFrame)
    #expect(h.frame(mail) == mailFrame)
  }

  @Test func quittingReachesWindowsThatTakeNoSpaceJustNow() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.system.setMinimized(notes, true)
    h.system.setOnActiveSpace(mail, false)
    h.scheduler.runPending()
    h.run("zoom \(safari.rawValue)")
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame, "minimized: it must not come back in the shape of its slot")
    #expect(h.frame(mail) == mailFrame, "on another macOS Space")
  }

  @Test func quittingMovesEachWindowOnce() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.system.clearFrameLog()
    h.controller.shutdown()
    for window in [notes, safari, mail] {
      #expect(h.system.frameLog.filter { $0.window == window }.count == 1, "\(window)")
    }
  }

  @Test func theNextLaunchDocksThemAgainAndStillRemembers() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    let arranged = h.workspace
    let slots = h.layout?.windowFrames
    h.controller.shutdown()

    let again = relaunch(h)
    again.start()
    #expect(again.workspace == arranged)
    #expect(again.layout?.windowFrames == slots)
    expectWindowsMatchLayout(again, on: again.display)
    again.run("float-all")
    #expect(again.frame(notes) == notesFrame)
    #expect(again.frame(safari) == safariFrame)
    #expect(again.frame(mail) == mailFrame)
  }

  @Test func afterACrashTheNextLaunchStillKnowsTheSizes() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    // The save that follows every change ran; `shutdown` never did. Windows are where Arbor had them.
    h.scheduler.runPending()
    #expect(!h.system.isVisible(notes))

    let again = relaunch(h)
    again.start()
    #expect(again.workspace.isDocked(notes))
    again.run("show-all")
    again.run("float \(notes.rawValue)")
    #expect(again.frame(notes)?.size == notesFrame.size)
    again.controller.shutdown()
    #expect(again.frame(safari) == safariFrame)
  }

  @Test func aWindowWhoseAppRestartedKeepsWhatIsRemembered() {
    let (h, notes, _, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.controller.shutdown()

    // The same app and title under a new number, where the app chose to reopen it.
    let again = Harness(saved: h.store.saved)
    again.system.open(app: "Filler")
    again.system.open(app: "Filler")
    again.system.open(app: "Filler")
    let reopened = again.system.open(
      app: "Notes", title: "Notes \(notes.rawValue)", frame: CGRect(x: 10, y: 40, width: 900, height: 700))
    again.start()
    #expect(again.workspace.isDocked(reopened))
    #expect(again.workspace.undockedFrames == [reopened: notesFrame])
  }

  // Pausing (also docs/features/F40-pause.md)

  @Test func aWindowItsAppRestoresLateStillHasWhatWasRemembered() {
    let (h, notes, _, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.controller.shutdown()

    // At the next launch its app has not restored it yet: its slot waits.
    let again = Harness(saved: h.store.saved)
    for _ in 0..<5 { again.system.open(app: "Filler") }
    again.start()
    let restored = again.system.open(
      app: "Notes", title: "Notes \(notes.rawValue)", frame: CGRect(x: 10, y: 40, width: 900, height: 700))
    #expect(again.workspace.isDocked(restored))
    #expect(again.workspace.undockedFrames == [restored: notesFrame])
  }

  @Test func aPauseGivesTheFramedWindowItsFrameBackLikeTheRestAndAResumeFramesItAgain() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.run("zoom \(safari.rawValue)")
    let framed = try #require(h.frame(safari))
    let arranged = h.workspace
    h.system.clearFrameLog()

    #expect(h.run("pause").ok)
    #expect(h.frame(safari) == safariFrame, "in view, and as it was all the same")
    #expect(h.frame(notes) == notesFrame, "what was out of view is back on screen, where it floated")
    #expect(h.frame(mail) == mailFrame)
    #expect(h.system.frameLog.map(\.window).sorted() == [notes, safari, mail], "one move each")

    h.system.clearFrameLog()
    #expect(h.run("resume").ok)
    #expect(h.frame(safari) == framed)
    #expect(h.system.frameLog.map(\.window).sorted() == [notes, safari, mail], "one move each")
    #expect(h.workspace == arranged)
    for window in [notes, mail] { #expect(!h.system.isVisible(window)) }
    #expect(h.workspace.undockedFrame(of: notes) == notesFrame)
  }

  /// Where floating windows make way the dock has pushed Notes and Mail aside. As Arbor ships it has moved Safari alone.
  @Test(arguments: [false, true]) func aPauseAndAResumeMoveOnlyWhatArborHadMovedOnceEachWay(makingWay: Bool) {
    let (h, notes, safari, mail) = makeHarness(settings: makingWay ? .makingWay : Settings())
    let clockFrame = CGRect(x: 1000, y: 500, width: 300, height: 200)
    let clock = h.system.open(app: "Clock", frame: clockFrame)
    h.run("dock \(safari.rawValue) left")
    #expect(h.frame(clock) == clockFrame, "on the Desktop as it is: Arbor has not touched it")
    let frames = [notes, safari, mail, clock].map { h.frame($0) }
    h.system.clearFrameLog()
    h.run("pause")
    #expect(h.system.frameLog.map(\.window).sorted() == (makingWay ? [notes, safari, mail] : [safari]))
    h.run("resume")
    #expect(h.system.frameLog.map(\.window).sorted() == (makingWay ? [notes, notes, safari, safari, mail, mail] : [safari, safari]))
    #expect([notes, safari, mail, clock].map { h.frame($0) } == frames)
  }

  @Test func aPauseGivesASqueezedFloatingWindowItsSizeBackAndAResumeSqueezesItAgain() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    let squeezed = try #require(h.frame(notes))
    h.run("pause")
    #expect(h.frame(notes) == notesFrame)
    h.run("resume")
    #expect(h.frame(notes) == squeezed)
    #expect(h.workspace.floating[notes] == notesFrame)
  }

  @Test func aFloatingWindowSomebodyMovedDuringThePauseIsLeftThereByTheResume() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    h.run("pause")
    let chosen = notesFrame.offsetBy(dx: 40, dy: 60)
    h.system.userMove(notes, to: chosen)
    h.run("resume")
    #expect(h.frame(notes) == chosen)
    #expect(h.workspace.floating[notes] == chosen, "and that is its place from then on")
  }

  @Test(.withTiles) func aPauseBringsBackTilesMinimizedWindowsAndFloatingWindowsThatWereOutOfView() {
    let (h, notes, safari, mail) = makeHarness()
    let wideFrame = CGRect(x: 100, y: 100, width: 1250, height: 700)
    let wide = h.system.open(app: "Xcode", frame: wideFrame, minimumSize: CGSize(width: 1250, height: 700))
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("dock \(wide.rawValue) beside \(mail.rawValue) bottom")
    #expect(h.layout?.tiles.contains { $0.windows == [wide] } == true)
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(notes), "it floats on the Desktop, which is out of view")
    h.system.setMinimized(mail, true)

    h.run("pause")
    #expect(h.frame(wide) == wideFrame, "a tile")
    #expect(h.frame(notes) == notesFrame, "floating")
    #expect(h.frame(mail) == mailFrame, "minimized in its corner: it must not come back there")
  }

  @Test func withNothingRememberedAPauseBringsAWindowBackToItsSlot() throws {
    let (h, notes, safari) = try harnessWithNothingRemembered()
    let slot = try #require(h.frame(notes))
    h.run("zoom \(safari.rawValue)")
    h.run("pause")
    #expect(h.frame(notes) == slot, "where it would sit if everything were shown")
  }

  @Test func quittingWhilePausedLeavesNoColumnShapedWindows() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.run("pause")
    let (saved, starts) = (h.store.saved, h.system.starts)
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame)
    #expect(h.frame(safari) == safariFrame)
    #expect(h.frame(mail) == mailFrame)
    #expect(h.system.frameLog.isEmpty, "they went back when the pause began")
    #expect(h.system.starts == starts && !h.system.started, "so there is nothing to look for")
    #expect(h.store.saved == saved, "the arrangement is still there for the next launch")
    #expect(h.run("state").state?.windows.isEmpty == true)
  }

  @Test func quittingWhilePausedLeavesWhatSomebodyMovedMeanwhile() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.run("pause")
    let chosen = CGRect(x: 40, y: 60, width: 500, height: 333)
    h.system.userMove(notes, to: chosen)
    h.system.close(mail)
    h.controller.shutdown()
    #expect(h.frame(notes) == chosen, "it is theirs now")
    #expect(h.frame(safari) == safariFrame)
  }

  @Test func quittingWhilePausedUndoesWhatDockedWindowsDidToAFloatingWindow() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    h.run("pause")
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame)
  }

  @Test func resumingAfterAPauseForgetsWhereThePauseLeftThings() {
    let (h, notes, _, _) = makeHarness()
    h.run("arrange")
    h.run("pause")
    h.run("resume")
    h.run("float-all")
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame)
    #expect(h.system.frameLog.isEmpty, "an ordinary quit with nothing to do")
  }

  @Test func anExcludedAppsWindowsGoBackToWhereTheyWere() {
    let (h, notes, safari, mail) = makeHarness()
    h.run("arrange")
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(notes))
    #expect(h.run("exclude com.example.notes").ok)
    #expect(h.frame(notes) == notesFrame, "out of view when its app was excluded")
    #expect(h.run("exclude com.example.safari").ok)
    #expect(h.frame(safari) == safariFrame, "in view when its app was excluded")
    #expect(h.workspace.undockedFrames == [mail: mailFrame])

    // Taken back, it is a floating window like any other.
    h.run("include com.example.notes")
    #expect(h.workspace.floating[notes] == notesFrame)
  }

  @Test func anExcludedAppsSqueezedFloatingWindowGetsItsSizeBack() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    h.run("exclude com.example.notes")
    #expect(h.frame(notes) == notesFrame)
  }

  @Test func anExcludedAppsFloatingWindowOutOfViewGoesBackToWhereItFloated() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(notes))
    h.run("exclude com.example.notes")
    #expect(h.frame(notes) == notesFrame)
  }

  @Test func closingAWindowDropsWhatIsRemembered() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.close(notes)
    #expect(h.workspace.undockedFrames == [safari: safariFrame])
    h.scheduler.runPending()
    #expect(h.store.saved?.workspaces[h.display]?.undockedFrames == [safari: safariFrame])
  }

  // MARK: Windows that floated all along

  /// Safari and Mail docked either side of a Desktop too narrow for Notes, which was squeezed onto it. Floating windows make
  /// way here, as until Q20 (`floatingWindowsMakeWay`): as Arbor ships nothing is squeezed, and there is nothing to undo.
  func harnessWithASqueezedWindow() throws -> (Harness, WindowID) {
    let (h, notes, safari, mail) = makeHarness(settings: .makingWay.withDesktopColumn)
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) right")
    h.run("resize \(safari.rawValue) right 150")
    let desktop = try #require(h.layout?.desktopFrame)
    #expect(desktop.width < notesFrame.width)
    #expect(h.frame(notes)?.width == desktop.width)
    return (h, notes)
  }

  @Test func quittingUndoesWhatDockedWindowsDidToAFloatingWindow() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    h.controller.shutdown()
    #expect(h.frame(notes) == notesFrame)
  }

  @Test func floatAllUndoesWhatDockedWindowsDidToAFloatingWindow() throws {
    let (h, notes) = try harnessWithASqueezedWindow()
    h.run("float-all")
    #expect(h.frame(notes) == notesFrame)
  }

  @Test func lettingGoLeavesAFloatingWindowWhereTheUserPutIt() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(safari.rawValue) left")
    // Half over the docked window, and hanging over the bottom of the display: on purpose.
    let chosen = CGRect(x: 500, y: 700, width: 400, height: 300)
    h.system.userMove(notes, to: chosen)
    h.system.clearFrameLog()
    h.controller.shutdown()
    #expect(h.frame(notes) == chosen)
    #expect(!h.system.frameLog.contains { $0.window == notes })
  }

  /// Squeezed by Arbor to keep it on the Desktop, then merely moved: a move is not a resize. Taken for "this is how I
  /// want it", size included, it left the window at the squeezed size for good. Floating windows make way here too.
  func harnessWithASqueezedWindow() throws -> (Harness, zoom: WindowID, own: CGSize, squeezed: CGRect) {
    let h = Harness(settings: .makingWay.withDesktopColumn)
    let chrome = h.system.open(app: "Chrome", pid: 2001, frame: CGRect(x: 20, y: 60, width: 1200, height: 760))
    let ghostty = h.system.open(app: "Ghostty", pid: 2002, frame: CGRect(x: 300, y: 100, width: 800, height: 600))
    let own = CGSize(width: 900, height: 600)
    let zoom = h.system.open(app: "Zoom", pid: 2003, frame: CGRect(origin: CGPoint(x: 270, y: 120), size: own))
    h.start()
    h.run("dock \(chrome.rawValue) left")
    h.run("dock \(ghostty.rawValue) right")
    let squeezed = try #require(h.frame(zoom))
    #expect(squeezed.width < own.width, "squeezed onto the Desktop: \(squeezed)")
    return (h, zoom, own, squeezed)
  }

  @Test func aSqueezedWindowThatIsOnlyMovedStillHasItsOwnSizeToGoBackTo() throws {
    for way in ["drag", "move"] {
      for ending in ["float-all", "quit"] {
        let (h, zoom, own, squeezed) = try harnessWithASqueezedWindow()
        let moved = squeezed.offsetBy(dx: 0, dy: 150)
        if way == "drag" {
          h.system.drag(
            zoom, through: [CGPoint(x: squeezed.midX, y: squeezed.minY + 10), CGPoint(x: moved.midX, y: moved.minY + 10)])
        } else {
          h.system.userMove(zoom, to: moved)
        }
        #expect(h.frame(zoom) == moved, "\(way): it stays where it was put, as it was put")
        #expect(h.workspace.floating[zoom]?.size == own, "\(way)")
        if ending == "quit" { h.controller.shutdown() } else { h.run("float-all") }
        let frame = try #require(h.frame(zoom))
        #expect(frame.size == own, "\(way), \(ending): \(frame)")
        #expect(h.visibleFrame.contains(frame), "\(way), \(ending): \(frame)")
        #expect(frame.minY == moved.minY, "and it is where its user moved it to, as far as it fits")
      }
    }
  }

  @Test func aSqueezedWindowThatIsResizedHasTheSizeItsUserGaveIt() throws {
    let (h, zoom, _, squeezed) = try harnessWithASqueezedWindow()
    let resized = CGRect(x: squeezed.minX, y: squeezed.minY, width: squeezed.width - 60, height: 400)
    h.system.userMove(zoom, to: resized)
    #expect(h.workspace.floating[zoom] == resized)
    h.run("float-all")
    #expect(h.frame(zoom) == resized)
  }

  /// Moved, it is not snatched back or made to grow by the next change of the arrangement.
  @Test func aSqueezedWindowThatWasMovedStaysPutWhileTheDesktopIsNarrow() throws {
    let (h, zoom, _, squeezed) = try harnessWithASqueezedWindow()
    let moved = squeezed.offsetBy(dx: 0, dy: 150)
    h.system.userMove(zoom, to: moved)
    h.controller.apply(settings: h.controller.settings)
    #expect(h.frame(zoom) == moved)
  }

  // MARK: Guests (docs/features/F57-new-windows-while-framed.md)

  /// Safari framed, with a dialog that opened over it; then Notes framed, so both are out of view.
  func harnessWithAGuestOutOfView() -> (Harness, safari: WindowID, guest: WindowID, guestFrame: CGRect) {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    let guestFrame = CGRect(x: 400, y: 300, width: 500, height: 300)
    let guest = h.system.open(app: "Dialog", frame: guestFrame)
    #expect(h.workspace.guests?[guest] != nil)
    h.run("zoom \(notes.rawValue)")
    #expect(!h.system.isVisible(guest), "it left with its host")
    return (h, safari, guest, guestFrame)
  }

  @Test(arguments: ["float-all", "pause", "quit", "pause, quit"])
  func aGuestOutOfViewComesBackWhereItWasHoweverArborLetsGo(_ way: String) {
    let (h, safari, guest, guestFrame) = harnessWithAGuestOutOfView()
    if way == "float-all" { h.run("float-all") }
    if way.hasPrefix("pause") { h.run("pause") }
    if way.hasSuffix("quit") { h.controller.shutdown() }
    #expect(h.frame(guest) == guestFrame)
    #expect(h.frame(safari) == safariFrame)
  }

  @Test func aPauseDoesNotTouchAGuestInView() {
    let (h, _, safari, _) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    let guest = h.system.open(app: "Dialog", frame: CGRect(x: 400, y: 300, width: 500, height: 300))
    h.system.clearFrameLog()
    h.run("pause")
    h.run("resume")
    #expect(!h.system.frameLog.contains { $0.window == guest }, "it is where its app put it: \(h.system.frameLog)")
    #expect(h.workspace.guests?[guest] != nil, "still a guest")
  }

  @Test func aGuestThatIsDockedAndFloatsAgainHasItsOwnSize() {
    let (h, _, safari, _) = makeHarness()
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    let guestFrame = CGRect(x: 400, y: 300, width: 500, height: 300)
    let guest = h.system.open(app: "Dialog", frame: guestFrame)
    h.run("dock \(guest.rawValue) left")
    #expect(h.workspace.undockedFrame(of: guest) == guestFrame)
    h.run("float \(guest.rawValue)")
    #expect(h.frame(guest)?.size == guestFrame.size)
  }

  // MARK: Whatever happens

  /// Nobody resizes a window here, so whatever Arbor is told to do, each window must have its own size
  /// again once Arbor has let go, and what is remembered must be about docked windows only.
  @Test(arguments: Array<UInt64>(1...100)) func afterAnythingLettingGoGivesEveryWindowItsOwnSize(seed: UInt64) {
    var random = SeededGenerator(seed: seed)
    let h = Harness()
    var sizes: [WindowID: CGSize] = [:]
    func open() {
      let size = CGSize(width: Int.random(in: 300...900, using: &random), height: Int.random(in: 200...700, using: &random))
      let origin = CGPoint(x: Int.random(in: 0...500, using: &random), y: Int.random(in: 25...175, using: &random))
      sizes[h.system.open(app: "App\(sizes.count)", frame: CGRect(origin: origin, size: size))] = size
    }
    for _ in 0..<4 { open() }
    h.start()
    var commands = 0
    /// Where a hand last dropped a window out of its slot: this test's own record, not what Arbor remembers.
    var dropped: [WindowID: CGRect] = [:]

    for step in 0..<50 {
      guard let window = sizes.keys.sorted().randomElement(using: &random),
        let other = sizes.keys.sorted().randomElement(using: &random)
      else { break }
      let edge = ["left", "right", "up", "down"].randomElement(using: &random)!
      let (id, otherID) = (window.rawValue, other.rawValue)
      /// What this step did, for the message of a failed expectation.
      var done: String
      func command(_ text: String) -> String {
        h.run(text)
        commands += 1
        return text
      }
      switch Int.random(in: 0..<28, using: &random) {
      case 0...5: done = command("dock \(id) \(edge)")
      case 6, 7, 8: done = command("dock \(id) beside \(otherID) \(edge)")
      case 9, 10: done = command("float \(id)")
      case 11: done = command("toggle-float \(id)")
      case 12: done = command("arrange")
      case 13: done = command("float-all")
      case 14, 15: done = command("zoom \(id)")
      case 16, 17: done = command(["show-all", "desktop", "out", "in", "back"].randomElement(using: &random)!)
      case 18: done = command("resize \(id) \(edge) \(Int.random(in: -200...200, using: &random))")
      case 19, 20, 21:
        done = "minimize or restore \(window)"
        h.system.setMinimized(window, h.system.windows[window]?.snapshot.isMinimized == false)
      case 22 where sizes.count > 2:
        done = "close \(window)"
        h.system.close(window)
        sizes[window] = nil
      case 23 where sizes.count < 7:
        done = "open"
        open()
      case 24:
        done = command("pause") + ", " + command("resume")
      case 25, 26:
        // Only out of a slot: dragging a floating window that is squeezed makes that size the user's own.
        guard h.workspace.isDocked(window), let frame = h.layout?.windowFrames[window] else { continue }
        let drop = CGPoint(x: Int.random(in: 1...1439, using: &random), y: Int.random(in: 30...890, using: &random))
        done = "drag \(window) to \(drop)"
        h.system.drag(window, through: [CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: 700, y: 450), drop])
        // From slot to slot it stays as it is: a slot is a place in the arrangement, not on the desk.
        if h.workspace.isFloating(window) { dropped[window] = h.frame(window) }
      default:
        done = "pending work"
        h.scheduler.runPending()
      }
      let workspace = h.workspace
      let docked = Set(workspace.tree.allWindows)
      #expect(Set((workspace.undockedFrames ?? [:]).keys) == docked, "step \(step), \(done): every docked window floated once")
      #expect(docked.isDisjoint(with: workspace.floating.keys), "step \(step), \(done)")
      for (window, frame) in workspace.undockedFrames ?? [:] {
        #expect(frame.size == sizes[window], "step \(step), \(done): \(window)")
      }
    }

    #expect(commands > 20)
    h.controller.shutdown()
    for (window, size) in sizes.sorted(by: { $0.key < $1.key }) {
      #expect(h.frame(window)?.size == size, "\(window)")
      // A window dropped over a screen edge goes back there, docked since or not: exactly there, if under half of it shows, and
      // enough of it to see and grab.
      let showing = h.frame(window)!.intersection(h.system.displayList[0].frame)
      let isWhereItWasDropped = dropped[window].map { h.frame(window)!.approximatelyEquals($0, tolerance: 1) } ?? false
      #expect(
        h.system.isVisible(window) || (isWhereItWasDropped && showing.width >= 24 && showing.height >= 24),
        "\(window) is in view, or where it was dropped: \(h.frame(window)!)")
    }
  }

  // MARK: Windows that never floated

  @Test func aWindowDockedByARuleAtBirthGoesBackToTheSizeItsAppGaveIt() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.terminal", action: .dock(.right))]
    let (h, _, _, _) = makeHarness(settings: settings)
    let opened = CGRect(x: 200, y: 150, width: 570, height: 370)
    let terminal = h.system.open(app: "Terminal", frame: opened)
    #expect(h.workspace.isDocked(terminal))
    #expect(h.frame(terminal)?.size != opened.size)

    h.run("float \(terminal.rawValue)")
    #expect(h.frame(terminal)?.size == opened.size)
  }

  /// An arrangement saved by an Arbor that remembered nothing.
  func harnessWithNothingRemembered() throws -> (Harness, WindowID, WindowID) {
    let (old, notes, safari, _) = makeHarness()
    old.run("dock \(notes.rawValue) left")
    old.run("dock \(safari.rawValue) right")
    old.scheduler.runPending()
    let saved = try #require(old.store.saved)
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
    var workspaces = try #require(object["workspaces"] as? [String: Any])
    var workspace = try #require(workspaces["main"] as? [String: Any])
    #expect(workspace.removeValue(forKey: "undockedFrames") != nil)
    workspaces["main"] = workspace
    object["workspaces"] = workspaces
    old.store.saved = try JSONDecoder().decode(
      PersistedState.self, from: JSONSerialization.data(withJSONObject: object))
    let h = relaunch(old)
    h.start()
    return (h, notes, safari)
  }

  /// Criterion 5 (the round trip is `theNextLaunchDocksThemAgainAndStillRemembers`).
  @Test func anOldStateFileLoadsAndItsWindowsKeepTheirSlotsSize() throws {
    let (h, notes, safari) = try harnessWithNothingRemembered()
    #expect(h.workspace.isDocked(notes))
    #expect(h.workspace.undockedFrames == nil)
    let slot = try #require(h.layout?.windowFrames[notes])
    let other = try #require(h.layout?.windowFrames[safari])

    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes)?.size == slot.size, "nothing better is known")
    h.controller.shutdown()
    #expect(h.frame(safari)?.height == other.height, "it stays in its slot")
  }

  @Test func withNothingRememberedFloatAllPutsTheFramedWindowInItsPlace() throws {
    let (h, notes, safari) = try harnessWithNothingRemembered()
    let place = try #require(h.frame(notes))
    h.run("zoom \(notes.rawValue)")
    h.run("float-all")
    #expect(h.frame(notes) == place, "where it would sit if everything were shown")
    #expect(h.system.isVisible(safari))
  }

  @Test func aWindowInFullScreenIsLeftAlone() {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.setFullScreen(notes, true)
    h.scheduler.runPending()
    h.system.clearFrameLog()
    h.run("float-all")
    #expect(!h.system.frameLog.contains { $0.window == notes })
    #expect(h.workspace.floating[notes] == notesFrame, "it floats there as far as Arbor is concerned")
  }

  @Test func withNothingRememberedFloatAllLeavesAMinimizedWindowAlone() throws {
    let (h, notes, _) = try harnessWithNothingRemembered()
    h.system.setMinimized(notes, true)
    h.system.clearFrameLog()
    h.run("float-all")
    #expect(!h.system.frameLog.contains { $0.window == notes })
    #expect(h.workspace.isFloating(notes))
  }

  @Test func withNothingRememberedADraggedWindowKeepsItsSizeAndPlace() throws {
    let (h, notes, _) = try harnessWithNothingRemembered()
    let slot = try #require(h.frame(notes))
    // Two halves leave the Desktop no room to drop it on: a plain drag takes a docked window out anywhere.
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: 720, y: 200)], plainly: true)
    #expect(h.workspace.isFloating(notes))
    #expect(h.frame(notes)?.height == slot.height)
  }

  // MARK: Apps with a will of their own

  @Test func aWindowThatCanNoLongerShrinkToItsOldSizeStaysOnTheDisplay() throws {
    let (h, notes, _, _) = makeHarness()
    h.system.userMove(notes, to: CGRect(x: 1000, y: 560, width: 400, height: 300))
    h.run("dock \(notes.rawValue) left")
    // A sidebar opened while it was docked.
    h.system.setMinimumSize(notes, CGSize(width: 700, height: 500))
    h.run("float-all")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 700, height: 500))
    #expect(h.visibleFrame.contains(frame), "larger than asked, it is slid back onto the display")
  }

  /// What is remembered about a floating window can be smaller than its app allows by now. Pushed onto the
  /// Desktop it then turns out larger than asked, and has to end on the screen all the same. Floating windows make way in
  /// this test and the three that follow, as until Q20 (`floatingWindowsMakeWay`): otherwise nothing pushes or squeezes one.
  @Test func aFloatingWindowThatCanNoLongerBeAsSmallAsItWasStaysOnTheScreenWhenPushedAside() throws {
    let (h, notes, safari, mail) = makeHarness(settings: .makingWay)
    h.run("close \(mail.rawValue)")
    h.system.userMove(notes, to: CGRect(x: 200, y: 200, width: 480, height: 352))
    // A sidebar opened: nothing moves yet, but it will not be made this small again.
    h.system.setMinimumSize(notes, CGSize(width: 1000, height: 537))
    h.run("dock \(safari.rawValue) left")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 1000, height: 537))
    #expect(h.visibleFrame.contains(frame), "\(frame) hangs off the screen")
    #expect(frame.maxX == h.visibleFrame.maxX, "it covers as little docked space as it can")
    // Once Arbor knows, other changes do not make the window twitch.
    let slack = h.system.open(app: "Slack", frame: CGRect(x: 800, y: 300, width: 400, height: 300))
    h.system.clearFrameLog()
    h.run("dock \(slack.rawValue) beside \(safari.rawValue) bottom")
    #expect(!h.system.frameLog.contains { $0.window == notes })
    h.run("zoom \(safari.rawValue)")
    h.run("back")
    #expect(h.frame(notes) == frame)
  }

  @Test func afterFloatAllAWindowThatCouldNotShrinkIsStillKeptOnTheScreen() throws {
    let (h, notes, safari, mail) = makeHarness(settings: .makingWay)
    h.run("close \(mail.rawValue)")
    h.system.userMove(notes, to: CGRect(x: 200, y: 200, width: 480, height: 352))
    h.system.setMinimumSize(notes, CGSize(width: 1000, height: 537))
    h.run("dock \(safari.rawValue) left")
    h.run("float-all")
    #expect(h.visibleFrame.contains(try #require(h.frame(notes))))
    h.run("dock \(safari.rawValue) left")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 1000, height: 537))
    #expect(h.visibleFrame.contains(frame), "\(frame) hangs off the screen")
  }

  /// What Arbor learned earlier about the other side may be out of date (F45): it is no reason to widen a window.
  @Test func onlyTheSideTheAppRefusesGrows() throws {
    let (h, notes, safari, mail) = makeHarness(settings: .makingWay)
    h.run("close \(mail.rawValue)")
    h.system.userMove(notes, to: CGRect(x: 200, y: 200, width: 800, height: 300))
    h.system.setMinimumSize(notes, CGSize(width: 760, height: 0))
    h.run("dock \(safari.rawValue) left")
    #expect(h.frame(notes)?.width == 760, "learned: no narrower than 760")
    h.run("float-all")
    // The sidebar closes, the user makes it narrow, and a toolbar makes it taller than it was.
    h.system.setMinimumSize(notes, .zero)
    h.system.userMove(notes, to: CGRect(x: 200, y: 200, width: 400, height: 300))
    h.system.setMinimumSize(notes, CGSize(width: 0, height: 537))
    h.run("dock \(safari.rawValue) left")
    #expect(h.frame(notes)?.size == CGSize(width: 400, height: 537))
    #expect(h.workspace.floating[notes]?.size == CGSize(width: 400, height: 537))
  }

  /// Only what the app refuses changes what is remembered: squeezed onto a narrow Desktop, a window still goes
  /// back to the size the user gave it.
  @Test func aWindowSqueezedOntoTheDesktopStillGoesBackToTheSizeItHad() throws {
    let (h, notes, safari, mail) = makeHarness(settings: .makingWay)
    h.run("close \(mail.rawValue)")
    h.system.userMove(notes, to: CGRect(x: 200, y: 200, width: 1000, height: 500))
    h.system.setMinimumSize(notes, CGSize(width: 900, height: 400))
    h.run("dock \(safari.rawValue) left")
    #expect(h.frame(notes)?.width == 900)
    #expect(h.workspace.floating[notes] == CGRect(x: 200, y: 200, width: 1000, height: 500))
    h.run("float-all")
    #expect(h.frame(notes) == CGRect(x: 200, y: 200, width: 1000, height: 500))
  }

  /// The chaos lab's story: a window out of view is to come back while its app does not answer. It cannot be moved
  /// now, and must not be forgotten in its corner: no longer counted as out of view, nothing would fetch it. On a
  /// display nobody is working on, no layout comes by to find it either.
  @Test(.withTiles) func aWindowOutOfViewWhoseAppHangsWhenItIsLetGoOfComesBackWhenTheAppAnswers() throws {
    let below = DisplaySnapshot(
      id: DisplayID("below"), frame: CGRect(x: 289, y: 900, width: 1080, height: 1920),
      visibleFrame: CGRect(x: 289, y: 900, width: 1080, height: 1920), isMain: false)
    for command in ["float", "toggle-float", "float-all"] {
      let h = Harness(displays: [main, below], settings: .withDesktopColumn)
      h.start()
      let xcode = h.system.open(app: "Xcode", pid: 1004, frame: CGRect(x: 321, y: 1529, width: 355, height: 316))
      h.system.setMinimumSize(xcode, CGSize(width: 1004, height: 773))
      h.run("arrange all")
      #expect(h.controller.snapshot().window(xcode)?.parked == true, "a tile: its slot beside the Desktop is too narrow")

      h.system.setUnresponsive(pid: 1004, true)
      h.run(command == "float-all" ? "float-all" : "\(command) \(xcode.rawValue)")
      #expect(!h.system.isVisible(xcode), "nobody can move it now")
      #expect(h.controller.snapshot().window(xcode)?.parked == true, "and Arbor knows")
      h.system.setUnresponsive(pid: 1004, false)
      h.scheduler.advance(by: 1)
      let frame = try #require(h.frame(xcode))
      #expect(h.system.isVisible(xcode), "\(command): lost at \(frame)")
      #expect(below.visibleFrame.contains(frame), "\(command): \(frame)")
      #expect(h.controller.snapshot().window(xcode)?.parked == false)
    }
  }

  /// One that was in view stays in view. It keeps its slot's size: nobody could give it its own.
  @Test func aWindowInViewWhoseAppHangsWhenItIsFloatedStaysInView() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let pid = try #require(h.system.allWindows().first { $0.id == notes }).pid
    h.system.setUnresponsive(pid: pid, true)
    h.run("float \(notes.rawValue)")
    h.system.setUnresponsive(pid: pid, false)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.isFloating(notes))
    #expect(h.system.isVisible(notes))
    #expect(h.visibleFrame.contains(try #require(h.frame(notes))))
    #expect(h.controller.snapshot().window(notes)?.parked == false)
  }

  /// The other way round: its app no longer allows the size it had. A window shrinks towards its top-left corner, so
  /// one that hung over the left edge of the screen can end beyond it, on no display.
  /// Here the layout gives the frame back (the Desktop comes into view again), not `putBack`.
  @Test func aWindowLeftHangingOverTheLeftEdgeThatComesBackNarrowerIsNotLost() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("close \(mail.rawValue)")
    h.run("dock \(safari.rawValue) right")
    let hanging = CGRect(x: -386, y: 133, width: 853, height: 206)
    h.system.userMove(notes, to: hanging)
    h.run("zoom \(safari.rawValue)")
    #expect(!h.system.isVisible(notes))
    // It left its wide mode while nobody looked.
    h.system.setMaximumSize(notes, CGSize(width: 252, height: 206))
    h.system.clearFrameLog()

    h.run("back")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 252, height: 206))
    #expect(h.visibleFrame.contains(frame), "\(frame) is on no display")
    #expect(h.workspace.floating[notes] == frame, "the frame it had is no frame to go back to")
    #expect(h.system.frameLog.filter { $0.window == notes }.count == 2, "asked, and slid back")
    // And it lasts.
    h.system.clearFrameLog()
    for command in ["relayout", "zoom \(safari.rawValue)", "home", "float-all"] {
      h.run(command)
      h.scheduler.advance(by: 1)
    }
    #expect(h.frame(notes) == frame)
  }

  @Test func aDisplayThatReturnsDoesNotTakeANarrowerWindowBeyondItsEdge() throws {
    let left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: -1280, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: -1280, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [main, left])
    let wide = h.system.open(app: "Wide", pid: 2001, frame: CGRect(x: -1666, y: 133, width: 853, height: 206))
    let safari = h.system.open(app: "Safari", pid: 2002, frame: CGRect(x: -900, y: 90, width: 800, height: 600))
    h.start()
    h.run("dock \(safari.rawValue) right")
    h.system.setDisplays([main])
    h.scheduler.advance(by: 2)
    h.system.setMaximumSize(wide, CGSize(width: 252, height: 206))
    h.system.setDisplays([main, left])
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(wide), "\(h.frame(wide)!) is on no display")
    // What `float-all` mends must not be undone by the next layout.
    for command in ["float-all", "home", "relayout"] {
      h.run(command)
      h.scheduler.advance(by: 2)
      #expect(left.visibleFrame.contains(try #require(h.frame(wide))), "\(command): \(h.frame(wide)!)")
    }
  }

  /// `putBack` slides such a window onto the display. If it floats, that is where it floats from now on, or the
  /// next layout would send it back beyond the edge.
  @Test func whatFloatAllMendsLasts() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("close \(mail.rawValue)")
    h.run("dock \(safari.rawValue) right")
    h.system.userMove(notes, to: CGRect(x: -386, y: 133, width: 853, height: 206))
    h.run("dock \(notes.rawValue) left")
    h.system.setMaximumSize(notes, CGSize(width: 252, height: 206))
    h.run("float-all")
    let frame = try #require(h.frame(notes))
    #expect(h.visibleFrame.contains(frame))
    #expect(h.workspace.floating[notes] == frame)
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.run("home")
    #expect(h.visibleFrame.contains(try #require(h.frame(notes))))
  }

  /// Only an answer smaller than asked is a reason: pushed aside until a strip shows, a window goes on hanging there.
  @Test func aWindowLeftWithAStripShowingGoesOnHangingThere() throws {
    let (h, notes, safari, mail) = makeHarness()
    h.run("close \(mail.rawValue)")
    h.run("dock \(safari.rawValue) right")
    let hanging = CGRect(x: -700, y: 133, width: 853, height: 206)
    h.system.userMove(notes, to: hanging)
    h.run("zoom \(safari.rawValue)")
    h.run("back")
    #expect(h.frame(notes) == hanging)
    #expect(h.workspace.floating[notes] == hanging)
  }

  @Test func aWindowThatResizedItselfWhileDockedStillGoesBackToItsOldSize() throws {
    let (h, notes, safari, _) = makeHarness()
    h.run("dock \(notes.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    let slot = try #require(h.frame(notes))
    h.system.userMove(notes, to: CGRect(x: slot.minX, y: slot.minY, width: 333, height: 222))
    h.scheduler.runPending()
    #expect(h.frame(notes) == slot, "put back in its slot")
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes)?.size == notesFrame.size)
  }

  @Test func aWindowThatCannotGrowSitsInItsSlotAndFloatsAsItWas() {
    let (h, notes, _, _) = makeHarness()
    h.system.setMaximumSize(notes, notesFrame.size)
    h.run("dock \(notes.rawValue) left")
    h.run("float-all")
    #expect(h.frame(notes) == notesFrame)
  }

  // MARK: Displays

  @Test func aSmallerDisplayFitsTheRememberedFrame() throws {
    let (h, notes, safari, _) = makeHarness()
    h.system.userMove(safari, to: CGRect(x: 100, y: 60, width: 1300, height: 800))
    h.system.userMove(notes, to: CGRect(x: 1000, y: 560, width: 400, height: 300))
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    let smaller = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)
    h.system.setDisplays([smaller])

    h.run("float-all")
    #expect(h.frame(safari) == smaller.visibleFrame, "too large now: as much of it as fits")
    let frame = try #require(h.frame(notes))
    #expect(frame.size == CGSize(width: 400, height: 300), "its size still fits")
    #expect(smaller.visibleFrame.contains(frame), "its place does not")
  }

  @Test func aStateFileFromALargerDisplayIsFittedAtQuit() {
    let (h, _, safari, _) = makeHarness()
    h.system.userMove(safari, to: CGRect(x: 100, y: 60, width: 1300, height: 800))
    h.run("dock \(safari.rawValue) left")
    h.controller.shutdown()
    let smaller = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)
    let again = relaunch(h, displays: [smaller])
    again.start()
    again.controller.shutdown()
    #expect(again.frame(safari) == smaller.visibleFrame)
  }

  @Test func aWindowDockedOnAnotherDisplayKeepsItsSizeAndItsPlaceFromTheCorner() throws {
    let h = Harness(displays: [main, side])
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 800, height: 600))
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(safari.rawValue) left")
    #expect(h.run("dock \(notes.rawValue) beside \(safari.rawValue) right").ok)
    #expect(h.controller.workspaces[side.id]?.isDocked(notes) == true)
    #expect(h.controller.workspaces[main.id]?.contains(notes) == false)

    h.run("float-all")
    // 300 from the left and 175 below the top of what is usable, on either display.
    #expect(h.frame(notes) == CGRect(x: 1440 + 300, y: 175, width: 400, height: 300))
  }

  @Test func aWindowDraggedToAnotherDisplaysEdgeKeepsItsSize() {
    let h = Harness(displays: [main, side])
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    h.start()
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(notes, through: [CGPoint(x: 500, y: 210), CGPoint(x: 2000, y: 300), CGPoint(x: 2718, y: 400)])
    #expect(h.controller.workspaces[side.id]?.isDocked(notes) == true)
    h.run("float \(notes.rawValue)")
    #expect(h.frame(notes)?.size == notesFrame.size)
    #expect(side.visibleFrame.contains(h.frame(notes) ?? .zero))
  }

  @Test func aDockedWindowMovedToAnotherDisplayKeepsWhatWasRememberedFirst() {
    let h = Harness(displays: [main, side])
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    let safari = h.system.open(app: "Safari", frame: CGRect(x: 1600, y: 100, width: 800, height: 600))
    h.start()
    h.run("dock \(notes.rawValue) left")
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) beside \(safari.rawValue) right")
    #expect(h.controller.workspaces[side.id]?.undockedFrame(of: notes)?.size == notesFrame.size)
    #expect(h.controller.workspaces[main.id]?.undockedFrames == nil)
  }

  @Test func aWindowDraggedOutOfItsSlotOntoAnotherDisplayShrinksUnderThePointer() throws {
    let h = Harness(displays: [main, side])
    let notes = h.system.open(app: "Notes", frame: notesFrame)
    h.start()
    h.run("dock \(notes.rawValue) left")
    let drop = CGPoint(x: 2000, y: 300)
    h.system.drag(notes, through: [CGPoint(x: 300, y: 60), CGPoint(x: 1400, y: 200), drop])
    #expect(h.controller.workspaces[side.id]?.isFloating(notes) == true)
    let frame = try #require(h.frame(notes))
    #expect(frame.size == notesFrame.size)
    #expect(frame.midX == drop.x)
    #expect(h.controller.workspaces[side.id]?.floating[notes] == frame)
  }

  @Test func aWindowDroppedOnASmallerDisplayIsNoLargerThanIt() throws {
    let h = Harness(displays: [main, side])
    let large = h.system.open(app: "Xcode", frame: CGRect(x: 20, y: 30, width: 1400, height: 860))
    h.start()
    h.run("dock \(large.rawValue) left")
    h.system.drag(large, through: [CGPoint(x: 300, y: 60), CGPoint(x: 2000, y: 20)])
    #expect(h.controller.workspaces[side.id]?.isFloating(large) == true)
    #expect(h.frame(large)?.size == CGSize(width: 1280, height: 800))
  }

  @Test func whenItsDisplayGoesAwayADockedWindowFloatsAtItsOwnSizeAndReturnsToItsSlot() throws {
    let h = Harness(displays: [main, side])
    let onSide = CGRect(x: 1600, y: 100, width: 500, height: 400)
    let notes = h.system.open(app: "Notes", frame: onSide)
    h.start()
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("dock \(notes.rawValue) left")
    let slot = try #require(h.frame(notes))

    h.system.setDisplays([main])
    #expect(h.frame(notes)?.size == onSide.size, "not the shape of a slot on a display that has gone")
    #expect(main.visibleFrame.contains(try #require(h.frame(notes))))

    h.system.setDisplays([main, side])
    #expect(h.frame(notes) == slot)
    #expect(h.controller.workspaces[side.id]?.undockedFrame(of: notes) == onSide)
  }
}

/// The same numbers on every run and every platform.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
