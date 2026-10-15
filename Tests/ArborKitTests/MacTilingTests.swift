import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Arbor never fights macOS over a window. With macOS's own tiling as a Mac comes, which is on, a window let go at the very
/// edge of the display, in the menu bar or with ⌥ held is macOS's: it takes the window to a tile of its own, asking nobody, or leaves it.
/// Seen on a Mac before this: two previews, and the window went into Arbor's slot, to macOS's tile and back into the slot.
///
/// The fake tiles as the Mac was seen to (`FakeWindowSystem.tiling`). The arrangement is [a | Desktop | b] with c floating.
@Suite @MainActor struct MacTilingTests {
  func scene(_ tiling: MacTiling = .on) -> DragScene {
    let s = DragScene()
    s.h.system.tiling = tiling
    return s
  }

  /// The places where macOS acts on the standard display, 1440×900 with a menu bar of 25, and what it makes of the floating
  /// window, 400×300, and of a docked one, 464×851. They rest a hair short of the tile: a point to the left where they come
  /// from the left, a point lower where they reached lower than the tile (`sightings`).
  nonisolated static let places: [(CGPoint, CGRect, CGRect)] = [
    (CGPoint(x: 0, y: 450), CGRect(x: -1, y: 25, width: 720, height: 875), CGRect(x: -1, y: 26, width: 720, height: 875)),
    (CGPoint(x: 1439, y: 450), CGRect(x: 720, y: 25, width: 720, height: 875), CGRect(x: 720, y: 26, width: 720, height: 875)),
    (CGPoint(x: 700, y: 0), CGRect(x: 0, y: 25, width: 1440, height: 875), CGRect(x: 0, y: 25, width: 1440, height: 875)),
    (CGPoint(x: 700, y: 24), CGRect(x: 0, y: 25, width: 1440, height: 875), CGRect(x: 0, y: 25, width: 1440, height: 875)),
    (CGPoint(x: 0, y: 0), CGRect(x: -1, y: 25, width: 720, height: 437.5), CGRect(x: -1, y: 26, width: 720, height: 437.5)),
    (CGPoint(x: 0, y: 899), CGRect(x: -1, y: 463.5, width: 720, height: 437.5), CGRect(x: -1, y: 463.5, width: 720, height: 437.5)),
  ]

  @Test(arguments: places.indices) func aFloatingWindowLetGoWhereMacOSTilesIsLeftToMacOS(index: Int) {
    let (point, tile, _) = Self.places[index]
    let s = scene()
    let others = [s.a: s.frame(s.a), s.b: s.frame(s.b)]
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: point, holding: 1)
    #expect(s.h.overlays.preview == nil, "macOS shows its own preview here; a second one promises something else")
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == tile, "where macOS put it")
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "Arbor moved nothing: \(s.h.system.frameLog)")
    #expect(s.h.overlays.previewHistory.allSatisfy { $0 == nil })
    #expect([s.a: s.frame(s.a), s.b: s.frame(s.b)] == others)
    s.expectNothingLeftBehind()
  }

  /// It cannot go back to its slot: macOS is about to move it. So it leaves the arrangement, as over the Desktop, and Arbor
  /// does not give it its own size either, which would be a second hand on a window that is moving.
  @Test(arguments: places.indices) func aDockedWindowLetGoThereLeavesTheArrangementAndIsNotTouched(index: Int) {
    let (point, _, tile) = Self.places[index]
    let s = scene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == tile, "where macOS put it")
    #expect(s.h.workspace.isFloating(s.a))
    #expect(!s.h.system.frameLog.contains { $0.window == s.a }, "Arbor set no frame on it: \(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// A pointer travels. On its way to macOS's point of an edge it crosses Arbor's own band along that edge, and a preview that came up there
  /// would go again as macOS's comes: two promises for one drag. So with the switch for an edge on, the whole edge is macOS's.
  @Test(arguments: [CGPoint(x: 0, y: 450), CGPoint(x: 1439, y: 450), CGPoint(x: 700, y: 0), CGPoint(x: 0, y: 25), CGPoint(x: 1439, y: 899)])
  func onItsWayToTheEdgePointByPointNoPreviewEverShows(end: CGPoint) {
    let s = scene()
    // From the middle of the Desktop, where nothing is offered either.
    let start = CGPoint(x: s.desktop.midX, y: s.desktop.midY)
    s.h.system.beginDrag(s.c, at: start)
    let steps = Int(max(abs(end.x - start.x), abs(end.y - start.y)))
    for step in 1...steps {
      let share = CGFloat(step) / CGFloat(steps)
      let point = CGPoint(x: start.x + (end.x - start.x) * share, y: start.y + (end.y - start.y) * share)
      // Over the docked windows on the way Arbor may well offer something: what counts is the band along the edge.
      let visible = s.h.visibleFrame
      let inBand = point.x < visible.minX + 12 || point.x > visible.maxX - 12 || point.y < visible.minY + 12
      s.h.system.moveDrag(to: point, holding: inBand ? 0.3 : 0)
      if inBand { #expect(s.h.overlays.preview == nil, "at \(point)") }
    }
    s.h.system.holdDrag(for: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// Let go in the band, short of macOS's own point, nobody acts: a floating window floats where it is.
  @Test(arguments: [CGPoint(x: 1, y: 450), CGPoint(x: 11, y: 450), CGPoint(x: 1438, y: 450), CGPoint(x: 1429, y: 450), CGPoint(x: 700, y: 25), CGPoint(x: 700, y: 36)])
  func letGoInTheBandShortOfMacOSsPointAFloatingWindowStaysWhereItIs(point: CGPoint) {
    let s = scene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: point, holding: 1)
    #expect(s.h.overlays.preview == nil)
    let letGo = s.frame(s.c)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == letGo)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty, "nobody took it")
    s.expectNothingLeftBehind()
  }

  /// A docked one goes back to its slot, as wherever nothing is promised: macOS does not act there, so there is nobody to fight.
  @Test func letGoInTheBandShortOfMacOSsPointADockedWindowGoesBack() {
    let s = scene()
    let slot = s.frame(s.b)
    s.h.system.beginDrag(s.b)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 5, y: 450), holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.b))
    #expect(s.frame(s.b) == slot)
    s.expectNothingLeftBehind()
  }

  /// The bottom edge is nobody's but Arbor's, away from the corners. With the switches off so are the others, to one point from the end.
  @Test func theBottomEdgeStaysArborsAndWithTheSwitchesOffSoDoTheOthers() {
    for (tiling, point, edge) in [
      (MacTiling.on, CGPoint(x: 700, y: 899), Edge.bottom), (.on, CGPoint(x: 700, y: 890), .bottom),
      (.off, CGPoint(x: 1, y: 450), .left), (.off, CGPoint(x: 1438, y: 450), .right), (.off, CGPoint(x: 700, y: 25), .top),
      (.off, CGPoint(x: 700, y: 899), .bottom),
      // Each switch for its own edges.
      (MacTiling(screenEdges: true, menuBar: false, optionKey: true), CGPoint(x: 700, y: 30), .top),
      (MacTiling(screenEdges: false, menuBar: true, optionKey: true), CGPoint(x: 5, y: 450), .left),
    ] {
      let s = scene(tiling)
      s.h.system.beginDrag(s.c)
      s.h.system.moveDrag(to: point, holding: 0.3)
      #expect(s.h.overlays.preview != nil, "\(edge) with \(tiling)")
      s.h.system.endDrag()
      s.h.scheduler.advance(by: 3)
      #expect(s.h.workspace.isDocked(s.c), "\(edge) with \(tiling)")
      s.expectNothingLeftBehind()
    }
  }

  /// A window that lies under the menu bar, as every zoomed one does, has its title bar in the top band. Slid sideways, or merely nudged, it has
  /// not been carried to the top: it used to dock to the top half. An edge in whose band the pointer took hold offers nothing until
  /// the pointer has left the band once. At every setting of macOS's tiling; with it on the top band is silent anyway.
  @Test(arguments: [MacTiling.off, .on]) func slidAlongTheEdgeItLiesAtAWindowDoesNotDock(tiling: MacTiling) {
    let h = Harness()
    h.system.tiling = tiling
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 25, width: 700, height: 500))
    h.start()
    h.system.clearFrameLog()
    h.system.beginDrag(window)
    for step in 1...60 { h.system.moveDrag(to: CGPoint(x: 650 + CGFloat(step), y: 35), holding: 0.05) }
    h.system.holdDrag(for: 1)
    #expect(h.overlays.previewHistory.allSatisfy { $0 == nil })
    h.system.endDrag()
    h.scheduler.advance(by: 3)
    #expect(h.workspace.isFloating(window))
    #expect(h.frame(window) == CGRect(x: 360, y: 25, width: 700, height: 500))
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
  }

  /// Taken away from the edge and brought back, it has been carried there.
  @Test func takenOutOfTheBandAndBroughtBackItDocks() {
    let h = Harness()
    h.system.tiling = .off
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 25, width: 700, height: 500))
    h.start()
    h.system.beginDrag(window)
    h.system.moveDrag(to: CGPoint(x: 660, y: 35), holding: 0.3)
    #expect(h.overlays.preview == nil)
    h.system.moveDrag(to: CGPoint(x: 660, y: 120), holding: 0.3)
    h.system.moveDrag(to: CGPoint(x: 660, y: 30), holding: 0.3)
    #expect(h.overlays.preview != nil)
    h.system.endDrag()
    #expect(h.workspace.isDocked(window))
  }

  /// Only that edge. From the top band down the side to the left edge is a journey like any other.
  @Test func theOtherEdgesAreOpenToIt() {
    let h = Harness()
    h.system.tiling = .off
    let window = h.system.open(app: "Safari", frame: CGRect(x: 300, y: 25, width: 700, height: 500))
    h.start()
    h.system.beginDrag(window)
    h.system.moveDrag(to: CGPoint(x: 300, y: 200), holding: 0.1)
    h.system.moveDrag(to: CGPoint(x: 3, y: 450), holding: 0.3)
    #expect(h.overlays.preview != nil)
    h.system.endDrag()
    #expect(h.workspace.isDocked(window))
  }

  /// What the switches are for: with them off every edge is Arbor's to its last point, and so is the menu bar.
  @Test(arguments: places.indices) func withMacOSTilingOffArborDocksThere(index: Int) {
    let s = scene(.off)
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: Self.places[index].0, holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    s.expectNothingLeftBehind()
  }

  /// ⌥ brings up macOS's preview wherever the pointer is, over Arbor's own targets too.
  @Test func withOptionHeldEveryPlaceIsMacOSs() {
    let s = scene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    #expect(s.h.overlays.preview != nil)
    s.h.system.holdModifierKeys(.option)
    #expect(s.h.overlays.preview == nil)
    let letGo = s.frame(s.c)
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.frame(s.c) == letGo, "with nothing else held macOS shows its preview and leaves it at that")
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty, "whoever holds ⌥ asked macOS, and needs no telling")

    // Whatever else is held: with ⌃⌥⌘, the beginning of a shortcut of Arbor's own, macOS was seen to tile all the same.
    let third = scene()
    third.h.system.beginDrag(third.c)
    third.h.system.moveDrag(to: third.edge(.bottom, of: third.b), holding: 0.3)
    third.h.system.holdModifierKeys([.control, .option, .command])
    #expect(third.h.overlays.preview == nil)
    third.h.system.endDrag()
    third.h.scheduler.advance(by: 3)
    #expect(third.frame(third.c) == CGRect(x: 720, y: 26, width: 720, height: 875), "its lower edge came from below the tile's")
    #expect(third.h.workspace.isFloating(third.c))
    #expect(third.h.system.frameLog.isEmpty, "\(third.h.system.frameLog)")

    // With that switch off ⌥ means nothing to anybody.
    let other = scene(MacTiling(screenEdges: true, menuBar: true, optionKey: false))
    other.h.system.holdModifierKeys(.option)
    other.h.system.drag(other.c, through: [other.frame(other.c).center, other.edge(.bottom, of: other.b)])
    #expect(other.h.workspace.isDocked(other.c))
  }

  /// With ⌥ and nothing else held macOS was seen to show its preview and then to leave the window where it was let go, with posted keys. By the
  /// name of its switch it tiles. Arbor cannot know which it will be, and stands aside all the same: whichever macOS does, Arbor has
  /// shown nothing and set no frame.
  @Test(arguments: [false, true]) func letGoWithOptionAloneAFloatingWindowIsMacOSsWhicheverItDoes(tiles: Bool) {
    let s = scene()
    s.h.system.optionAloneTiles = tiles
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    s.h.system.holdModifierKeys(.option)
    s.h.system.holdDrag(for: 1)
    #expect(s.h.system.macTile(at: s.h.system.cursor) != nil, "macOS shows its preview")
    #expect(s.h.overlays.preview == nil, "and Arbor none beside it")
    let letGo = s.frame(s.c)
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == (tiles ? CGRect(x: 720, y: 26, width: 720, height: 875) : letGo))
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// Should ⌥ alone tile after all, a docked window is macOS's like any other that it takes: whatever is done about the one below must not
  /// put a second hand on a window that macOS is moving.
  @Test func shouldOptionAloneTileADockedWindowArborKeepsItsHandsOffIt() {
    let s = scene()
    s.h.system.optionAloneTiles = true
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.holdModifierKeys(.option)
    s.h.system.holdDrag(for: 1)
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == CGRect(x: 0, y: 26, width: 720, height: 875))
    #expect(s.h.workspace.isFloating(s.a))
    #expect(!s.h.system.frameLog.contains { $0.window == s.a }, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// A docked window has its slot's size in the hand. Arbor leaves it so where macOS is about to size it. Where macOS then does not, nobody has
  /// given it its own size. Decided: a plain drag means out wherever it ends, so macOS takes the window or it floats at its own size where it
  /// lies; and Arbor never takes a slot's size for a window's own, so the ways out give it back whatever else happens (rule 5).
  /// `thrownIntoTheMenuBarAndLetGoAtOnceTheWindowStaysAsItIs` holds the same window to its slot's size, and changes with the cure.
  @Test func letGoWithOptionAloneADockedWindowIsNotLeftWithItsSlotsSize() {
    let s = scene()
    let own = CGSize(width: 600, height: 400)
    let slot = s.frame(s.a).size
    #expect(slot != own)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.holdModifierKeys(.option)
    s.h.system.holdDrag(for: 1)
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.system.takeSizeBeforeTile(of: s.a) == nil, "macOS has tiled nothing")
    #expect(s.h.workspace.isFloating(s.a))
    withKnownIssue("board 1.67: left to macOS and left alone by it, a docked window keeps its slot's size for good") {
      #expect(s.frame(s.a).size == own, "it floats at \(s.frame(s.a)); its slot was \(slot)")
    }
    withKnownIssue("board 1.67") {
      #expect(s.h.workspace.floating[s.a]?.size == own, "what is remembered: \(String(describing: s.h.workspace.floating[s.a]))")
    }
    s.expectNothingLeftBehind()
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    withKnownIssue("board 1.67") {
      #expect(s.frame(s.a).size == own, "after Float All: \(s.frame(s.a))")
    }
  }

  /// Another tool's event tap can swallow the release. macOS has seen it all the same and has tiled the window by the time Arbor
  /// finds the button up.
  @Test func aReleaseThatArborNeverSawIsNoReasonToPullTheWindowBack() {
    let s = scene()
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 0.3)
    s.h.system.loseTheReleaseOfTheDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.a) == s.h.visibleFrame)
    #expect(s.h.workspace.isFloating(s.a))
    #expect(!s.h.system.frameLog.contains { $0.window == s.a }, "\(s.h.system.frameLog)")
    s.expectNothingLeftBehind()
  }

  /// macOS fills the screen only for a pointer that has rested in the menu bar. Arbor stands aside all the same: it cannot tell to a
  /// tenth of a second what macOS will do, and nothing was promised. So the window floats where it was let go, and nothing is said.
  @Test func thrownIntoTheMenuBarAndLetGoAtOnceTheWindowStaysAsItIs() {
    for docked in [false, true] {
      let s = scene()
      let window = docked ? s.a : s.c
      s.h.system.beginDrag(window)
      s.h.system.moveDrag(to: s.onDesktop)
      s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
      let letGo = s.frame(window)
      s.h.system.endDrag()
      s.h.scheduler.advance(by: 3)
      #expect(s.frame(window) == letGo, "docked: \(docked)")
      #expect(s.h.workspace.isFloating(window))
      #expect(!s.h.system.frameLog.contains { $0.window == window }, "\(s.h.system.frameLog)")
      #expect(s.h.overlays.messages.isEmpty, "macOS took nothing, so there is nothing to say: \(s.h.overlays.messages.map(\.model.line))")
      s.expectNothingLeftBehind()
    }
  }

  /// At the sides macOS waits for nothing.
  @Test func thrownAgainstTheSideItIsTiledAtOnce() {
    let s = scene()
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 0, y: 450)], holding: 0)
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == CGRect(x: -1, y: 25, width: 720, height: 875))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
  }

  /// What hosted Macs were seen to do, in their numbers: where the pointer let go, the frame the window was last seen with
  /// before that, the smallest and the largest size it takes, and where it came to rest. The displays are theirs: 1024×768 and
  /// 1600×900, visible from y 31, with a Dock below.
  struct Sighting: Sendable, CustomTestStringConvertible {
    var testDescription: String
    var wide = false
    var pointer: CGPoint
    var held: CGRect
    var smallest = CGSize.zero
    var largest: CGSize?
    var rest: CGRect
  }

  nonisolated static let sightings: [Sighting] = [
    Sighting(
      testDescription: "grows into the left half", pointer: CGPoint(x: 0, y: 368), held: CGRect(x: -240, y: 356, width: 480, height: 348),
      rest: CGRect(x: -1, y: 31, width: 512, height: 674)),
    Sighting(
      testDescription: "a docked window, wider and lower than the left half", pointer: CGPoint(x: 0, y: 368),
      held: CGRect(x: -202, y: 212, width: 554, height: 650), rest: CGRect(x: -1, y: 32, width: 513, height: 674)),
    Sighting(
      testDescription: "thrown there, reaching six points lower than the half", pointer: CGPoint(x: 0, y: 368),
      held: CGRect(x: -243, y: 356, width: 487, height: 355), rest: CGRect(x: -1, y: 32, width: 512, height: 674)),
    Sighting(
      testDescription: "a smallest width of 700", pointer: CGPoint(x: 0, y: 368), held: CGRect(x: -221, y: 356, width: 480, height: 348),
      smallest: CGSize(width: 700, height: 100), rest: CGRect(x: -1, y: 31, width: 700, height: 674)),
    Sighting(
      testDescription: "a largest size of 300×240", pointer: CGPoint(x: 0, y: 368), held: CGRect(x: -136, y: 356, width: 300, height: 236),
      largest: CGSize(width: 300, height: 240), rest: CGRect(x: -1, y: 249, width: 300, height: 240)),
    Sighting(
      testDescription: "a fixed size, only moved", pointer: CGPoint(x: 0, y: 368), held: CGRect(x: -136, y: 298, width: 300, height: 240),
      smallest: CGSize(width: 300, height: 240), largest: CGSize(width: 300, height: 240),
      rest: CGRect(x: 0, y: 248, width: 300, height: 240)),
    Sighting(
      testDescription: "fills the screen", pointer: CGPoint(x: 512, y: 15), held: CGRect(x: 296, y: 31, width: 480, height: 348),
      rest: CGRect(x: 0, y: 31, width: 1024, height: 674)),
    Sighting(
      testDescription: "Notes", wide: true, pointer: CGPoint(x: 0, y: 450), held: CGRect(x: -350, y: 240, width: 709, height: 660),
      rest: CGRect(x: -1, y: 32, width: 800, height: 791)),
    Sighting(
      testDescription: "Notes, as large as the tile already: only moved", wide: true, pointer: CGPoint(x: 0, y: 450),
      held: CGRect(x: -115, y: 435, width: 800, height: 791), rest: CGRect(x: 0, y: 31, width: 800, height: 791)),
    Sighting(
      testDescription: "Safari, wide and from the left into the right half", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 661, y: 433, width: 1324, height: 224), rest: CGRect(x: 799, y: 31, width: 801, height: 791)),
    Sighting(
      testDescription: "TextEdit", wide: true, pointer: CGPoint(x: 1599, y: 450), held: CGRect(x: 1207, y: 438, width: 782, height: 212),
      rest: CGRect(x: 800, y: 31, width: 800, height: 791)),
    Sighting(
      testDescription: "TextEdit, reaching lower, with no Arbor running", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 961, y: 424, width: 674, height: 440), rest: CGRect(x: 800, y: 32, width: 800, height: 791)),
    Sighting(
      testDescription: "Calendar, ending level with the tile", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 1351, y: 319, width: 794, height: 503), rest: CGRect(x: 800, y: 31, width: 800, height: 791)),
    Sighting(
      testDescription: "Mail, which goes no narrower than 872", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 1013, y: 307, width: 1120, height: 630), smallest: CGSize(width: 872, height: 400),
      rest: CGRect(x: 729, y: 32, width: 872, height: 791)),
    // Its rows of text leave it short of the tile's height, by an odd number of points and by an even one.
    Sighting(
      testDescription: "Terminal, 784 high", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 1165, y: 322, width: 877, height: 499), largest: CGSize(width: 2000, height: 784), rest: CGRect(x: 800, y: 35, width: 801, height: 784)),
    Sighting(
      testDescription: "Terminal, 785 high, with no Arbor running", wide: true, pointer: CGPoint(x: 1599, y: 450),
      held: CGRect(x: 1139, y: 410, width: 877, height: 500), largest: CGSize(width: 2000, height: 785),
      rest: CGRect(x: 800, y: 35, width: 801, height: 785)),
    Sighting(
      testDescription: "Calendar fills the screen", wide: true, pointer: CGPoint(x: 800, y: 0),
      held: CGRect(x: 310, y: 31, width: 680, height: 600), rest: CGRect(x: 0, y: 31, width: 1600, height: 791)),
  ]

  /// A Mac like theirs with one window, held where it was held, the pointer having rested where it let go.
  func mac(_ seen: Sighting) -> (Harness, WindowID) {
    let size = seen.wide ? CGSize(width: 1600, height: 900) : CGSize(width: 1024, height: 768)
    let h = Harness(displays: [
      DisplaySnapshot(
        id: DisplayID("main"), frame: CGRect(origin: .zero, size: size),
        visibleFrame: CGRect(x: 0, y: 31, width: size.width, height: seen.wide ? 791 : 674), isMain: true)
    ])
    let window = h.system.open(app: "Notes", frame: seen.held, minimumSize: seen.smallest)
    h.system.setMaximumSize(window, seen.largest)
    h.start()
    h.system.clearFrameLog()
    h.system.cursor = seen.pointer
    h.scheduler.advance(by: 1)
    return (h, window)
  }

  /// The stand-in is held to them.
  @Test(arguments: sightings) func theStandInLeavesAWindowWhereAMacDid(_ seen: Sighting) {
    let (h, window) = mac(seen)
    let began = h.scheduler.now
    h.system.letMacOSTile(window, letGoAt: seen.held)
    #expect(h.frame(window) == seen.rest)
    #expect(abs(h.scheduler.now - began - 0.3) < 0.001, "a third of a second: \(h.scheduler.now - began)")
    h.scheduler.advance(by: 3)
    #expect(h.frame(window) == seen.rest)
    #expect(h.system.frameLog.isEmpty, "Arbor has no hand in it, then or later: \(h.system.frameLog)")
  }

  /// And to the way there, as the controller heard it of the second of them: 18 reports in 0.3 s, ever closer together, the
  /// last a point apart.
  @Test func theStandInTravelsAsAMacDid() {
    let recorded: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
      (-202, 211, 554, 651), (-182, 194, 550, 653), (-150, 165, 544, 657), (-117, 135, 537, 661), (-88, 109, 531, 664), (-64, 88, 526, 667),
      (-46, 72, 522, 669), (-33, 60, 519, 671), (-23, 51, 517, 672), (-16, 45, 516, 673), (-11, 41, 515, 673), (-8, 37, 514, 674),
      (-6, 35, 514, 674), (-4, 34, 513, 674), (-3, 33, 513, 674), (-2, 33, 513, 674), (-2, 32, 513, 674), (-1, 32, 513, 674),
    ]
    let (h, window) = mac(Self.sightings[1])
    // Where it is each time the clock moves on, which is before each step, and at the end.
    var steps: [CGRect] = []
    let passTime = h.system.passTime
    h.system.passTime = { seconds in
      steps.append(h.system.frame(of: window)!)
      passTime?(seconds)
    }
    h.system.letMacOSTile(window, letGoAt: Self.sightings[1].held)
    steps.append(h.system.frame(of: window)!)
    #expect(steps.count == recorded.count + 1)
    for (step, (x, y, width, height)) in zip(steps.dropFirst(), recorded) {
      let off = max(abs(step.minX - x), abs(step.minY - y), abs(step.width - width), abs(step.height - height))
      #expect(off <= 2, "\(step) for (\(x),\(y) \(width)×\(height))")
    }
    #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 != $1 }, "each of the 18 is a step, and is reported")
  }

  /// macOS goes by where the window was let go, whatever has become of it since: a frame set on it during the travel lasts
  /// until the next step, and one set when it has all but arrived does not outlast the end.
  @Test(arguments: [0.1, 0.29]) func whateverBecomesOfTheWindowOnTheWayMacOSTakesItToItsTile(after seconds: Double) {
    let seen = Self.sightings[0]
    let (h, window) = mac(seen)
    h.scheduler.schedule("somebody", after: seconds) { h.system.place(window, at: CGRect(x: 300, y: 300, width: 200, height: 200)) }
    h.system.letMacOSTile(window, letGoAt: seen.held)
    #expect(h.frame(window) == seen.rest)
  }

  /// A tile that lies a point off the display is no reason to fetch the window. It lies over the Desktop here, where Arbor does
  /// place floating windows: it comes back to the very point from out of view, and Float All leaves it there.
  @Test func aTileAPointOffTheDisplayComesBackWhereMacOSLeftIt() {
    let h = Harness()
    let docked = h.system.open(app: "Notes", frame: CGRect(x: 900, y: 200, width: 400, height: 400))
    let window = h.system.open(app: "Mail", frame: CGRect(x: 300, y: 300, width: 400, height: 700))
    h.start()
    h.run("dock \(docked.rawValue) right")
    h.scheduler.advance(by: 3)
    h.system.drag(window, through: [h.frame(window)!.center, CGPoint(x: 0, y: 450)])
    h.scheduler.advance(by: 3)
    let tile = CGRect(x: -1, y: 26, width: 720, height: 875)
    #expect(h.frame(window) == tile, "from the left, and reaching lower than the tile")
    h.run("zoom \(docked.rawValue)")
    h.scheduler.advance(by: 3)
    #expect(h.frame(window) != tile, "out of view")
    h.run("back")
    h.scheduler.advance(by: 3)
    // The point is what this is about. That it comes back narrower, squeezed off the docked window, is the board's 1.18.
    #expect(h.frame(window)?.origin == tile.origin)
    h.run("float-all")
    h.scheduler.advance(by: 3)
    #expect(h.frame(window) == tile)
  }

  /// macOS's last steps are a point apart, which is how far a report may differ in size from the one before and still be taken
  /// for a move. The size the window ends with is its own all the same, and Float All leaves it as it is. A window as high as
  /// the display is remembered two points wider than it ends, and Float All makes it so. One whose height grows meanwhile is
  /// spared by that alone: what is remembered is never less high than the window. On a Mac a window of 513×674 was given 514 at
  /// the next layout.
  @Test(arguments: [CGSize(width: 1000, height: 500), CGSize(width: 1000, height: 875)])
  func aWindowThatShrankIntoItsTileIsRememberedAsLargeAsItIs(size: CGSize) {
    let s = scene()
    // "A move is not a resize" is about windows that Arbor squeezed. As it ships it squeezes none (F64), and takes a report at its word.
    let makesWay = s.h.controller.settings.floatingWindowsMakeWay
    s.h.system.userMove(s.c, to: CGRect(origin: CGPoint(x: 200, y: 25), size: size))
    s.h.scheduler.advance(by: 3)
    s.h.system.clearFrameLog()
    s.h.system.drag(s.c, through: [CGPoint(x: 700, y: 35), CGPoint(x: 400, y: 300), CGPoint(x: 0, y: 450)])
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.c)
    #expect(tile.size == CGSize(width: 721, height: 875))
    withKnownIssue("board 1.68: the last steps of macOS's tiling are taken for moves") {
      #expect(s.h.workspace.floating[s.c] == tile, "what is remembered: \(String(describing: s.h.workspace.floating[s.c]))")
    } when: {
      size.height == 875 && makesWay
    }
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    withKnownIssue("board 1.68") {
      #expect(s.frame(s.c) == tile)
    } when: {
      size.height == 875 && makesWay
    }
    withKnownIssue("board 1.68") {
      #expect(!s.h.system.frameLog.contains { $0.window == s.c }, "\(s.h.system.frameLog)")
    } when: {
      size.height == 875 && makesWay
    }
  }

  /// macOS was seen to take a window that cannot change its size as well, and to move it into the tile as it is: that one
  /// arrives.
  @Test func aWindowOfAFixedSizeIsLeftToMacOSToo() {
    let s = scene()
    let fixed = s.h.system.open(app: "Calculator", frame: CGRect(x: 600, y: 300, width: 230, height: 400), isResizable: false)
    s.h.scheduler.advance(by: 1)
    s.h.system.clearFrameLog()
    s.h.system.beginDrag(fixed)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450), holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(fixed) == CGRect(x: 0, y: 263, width: 230, height: 400))
    #expect(s.h.workspace.isFloating(fixed))
    #expect(!s.h.system.frameLog.contains { $0.window == fixed }, "\(s.h.system.frameLog)")
  }

  /// Only a release does that. A pause, a quit or a window that closes ends a drag with the button still down, and macOS tiles nothing:
  /// the docked window goes back to its slot as ever, though ⌥, which every shortcut of Arbor's has in it, is down.
  @Test func aDragThatEndsWithoutAReleaseIsNotMacOSs() {
    let s = scene()
    let slot = s.frame(s.a)
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.holdModifierKeys([.control, .option])
    s.h.run("pause")
    #expect(s.h.overlays.messages.allSatisfy { !$0.model.line.hasPrefix("macOS tiled") })
    s.h.system.holdModifierKeys([])
    s.h.run("resume")
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.frame(s.a) == slot)

    // With the pointer resting in the menu bar, too.
    let other = scene()
    other.h.system.beginDrag(other.a)
    other.h.system.moveDrag(to: CGPoint(x: 700, y: 0), holding: 0.3)
    other.h.run("pause")
    other.h.run("resume")
    #expect(other.h.workspace.isDocked(other.a))
    #expect(other.h.controller.headsUp.hintsShown[HeadsUpHint.leftToMacOS.rawValue] == nil)
  }

  /// The keys of a shortcut pressed with a window in the hand go up again, and the target under the pointer is Arbor's again.
  @Test func whenOptionComesUpThePreviewIsBack() {
    let s = scene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.edge(.bottom, of: s.b), holding: 0.3)
    let preview = s.h.overlays.preview
    #expect(preview != nil)
    s.h.system.holdModifierKeys([.control, .option, .command])
    #expect(s.h.overlays.preview == nil)
    s.h.system.holdModifierKeys([])
    s.h.system.holdDrag(for: 0.3)
    #expect(s.h.overlays.preview == preview)
    s.h.system.endDrag()
    #expect(s.h.workspace.isDocked(s.c))
    s.expectNothingLeftBehind()
  }

  /// macOS gives a window dragged off its tile the size it had before. That is its own size from then on: taken for one that Arbor
  /// had squeezed, it would be blown up to the tile's size at the next layout, and left so at the end.
  @Test func draggedOffItsTileTheWindowIsItsOwnSizeForGood() {
    let s = scene()
    let own = s.frame(s.c).size
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 700, y: 0)])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == s.h.visibleFrame)
    s.h.system.drag(s.c, through: [CGPoint(x: 720, y: 35), s.onDesktop])
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c).size == own)
    #expect(s.h.workspace.floating[s.c]?.size == own, "what is remembered: \(String(describing: s.h.workspace.floating[s.c]))")
    // Whatever lays the display out afresh leaves it that size, and so does the end.
    s.h.run("float \(s.b.rawValue)")
    s.h.run("dock \(s.b.rawValue) right")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c).width <= own.width && s.frame(s.c).height <= own.height, "\(s.frame(s.c))")
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c).size == own)
  }

  /// Docked at the end of that drag, it remembers its own size at the place where it floated, not somewhere on the way.
  @Test func draggedOffItsTileAndDockedItComesBackWhereItFloated() {
    let s = scene()
    let own = s.frame(s.c).size
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 0, y: 450)])
    s.h.scheduler.advance(by: 3)
    let tile = s.frame(s.c)
    s.h.system.drag(s.c, through: [CGPoint(x: tile.midX, y: tile.minY + 10), CGPoint(x: 700, y: 880), CGPoint(x: 700, y: 897)])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.c))
    s.h.run("float-all")
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == CGRect(origin: tile.origin, size: own))
  }

  /// With `soleFloatTakesDesktop` a lone floating window fills the Desktop and gets its own size back when it is dragged off. Not
  /// from Arbor where macOS is about to size it.
  @Test func aWindowThatFilledTheDesktopIsNotSizedByBoth() {
    let s = DragScene { ($0.soleFloatTakesDesktop, $0.floatingWindowsMakeWay) = (true, true) }  // it takes both (F64)
    s.h.system.tiling = .on
    s.h.scheduler.advance(by: 3)
    s.h.system.clearFrameLog()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 1439, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(!s.h.system.frameLog.contains { $0.window == s.c }, "Arbor set no frame on it: \(s.h.system.frameLog)")
    #expect(s.frame(s.c) == CGRect(x: 720, y: 26, width: 720, height: 875))
  }

  /// What a trace holds is what Arbor was told, so that a replay stands aside where the recording did, whatever the
  /// machine that replays it would say. A trace from before Arbor asked is replayed as that Arbor behaved.
  @Test func aTraceSaysWhatArborWasToldAboutMacOSTiling() throws {
    let recorder = TraceRecorder()
    let sink = MemoryTraceSink(location: "memory")
    recorder.openSink = { _ in sink }
    let fake = FakeWindowSystem()
    fake.tiling = MacTiling(screenEdges: false, menuBar: true, optionKey: false)
    let system = RecordingWindowSystem(wrapping: fake, recorder: recorder)
    try recorder.begin(name: "tiling", fileName: "tiling") { _ in TraceRecorderTests.emptyHeader }
    #expect(system.macTiling() == fake.tiling)
    #expect(sink.lines.contains { $0.contains("macTiling") && $0.contains("\"menuBar\":true") && $0.contains("\"screenEdges\":false") })
  }

  /// People change the setting while Arbor runs, in the window that Check Setup sent them to.
  @Test func theSettingIsReadAtEveryDrag() {
    let s = scene()
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 700, y: 0)])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    s.h.system.tiling = .off
    s.h.system.drag(s.c, through: [CGPoint(x: 700, y: 35), CGPoint(x: 700, y: 300), CGPoint(x: 700, y: 0)])
    #expect(s.h.workspace.isDocked(s.c))
    s.expectNothingLeftBehind()
  }

  /// Whoever meant Arbor's edge and got macOS's tile is told, a few times ever, where that can be changed.
  @Test func theFirstTimesItSaysWhoTookTheWindow() {
    let s = scene()
    for round in 1...4 {
      let before = s.h.overlays.messages.count
      s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 700, y: 300), CGPoint(x: 700, y: 0)])
      s.h.scheduler.advance(by: 8)
      let said = s.h.overlays.messages.dropFirst(before).map(\.model.line)
      if round <= HeadsUpHint.timesShown {
        #expect(said == ["macOS tiled this window; Arbor stood aside · ⌃⌥⌘← docks it · Check Setup… in the menu"], "round \(round)")
      } else {
        #expect(said.isEmpty, "round \(round)")
      }
    }
  }

  /// Whoever set the band to 0 meant no edge of Arbor's, very likely so as to keep macOS's tiling: nothing stood aside, and there
  /// is nothing to change.
  @Test func withNoEdgesOfArborsNobodyIsToldThatItStoodAside() {
    let s = DragScene { $0.screenEdgeBand = 0 }
    s.h.system.tiling = .on
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 700, y: 300), CGPoint(x: 700, y: 0)])
    s.h.scheduler.advance(by: 8)
    #expect(s.frame(s.c) == CGRect(x: 0, y: 25, width: 1440, height: 875), "macOS tiled it")
    #expect(s.h.overlays.messages.isEmpty, "\(s.h.overlays.messages.map(\.model.line))")
    #expect(s.h.controller.headsUp.hintsShown[HeadsUpHint.leftToMacOS.rawValue] == nil)
  }

  /// The strip along macOS's edges is kept clear for macOS's sake, so it is there whatever Arbor's own band is. With narrow gaps a
  /// docked window reaches into it, and its edge would be offered two points from where macOS tiles.
  @Test func withNoEdgesOfArborsTheStripAlongMacOSsEdgesIsStillKeptClear() {
    let s = DragScene {
      $0.screenEdgeBand = 0
      $0.gap = 0
      $0.dropDwell = 0
    }
    s.h.system.tiling = .on
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 450), holding: 0.3)
    s.h.system.moveDrag(to: CGPoint(x: 2, y: 450), holding: 1)
    #expect(s.h.overlays.preview == nil, "two promises for one drag")
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    s.expectNothingLeftBehind()
  }
}
