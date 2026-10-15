import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Arbor never fights macOS over a window. With macOS's own tiling as a Mac comes, which is on, a window let go at the very
/// edge of the display, in the menu bar or with ⌥ held is macOS's: it grows the window to a tile of its own, asking nobody.
/// Seen on a Mac before this: two previews, and the window went into Arbor's slot, to macOS's tile and back into the slot.
///
/// The fake tiles as the Mac was seen to (`FakeWindowSystem.tiling`). The arrangement is [a | Desktop | b] with c floating.
@Suite @MainActor struct MacTilingTests {
  func scene(_ tiling: MacTiling = .on) -> DragScene {
    let s = DragScene()
    s.h.system.tiling = tiling
    return s
  }

  /// The places where macOS acts on the standard display, 1440×900 with a menu bar of 25, and what it makes of the window.
  nonisolated static let places: [(CGPoint, CGRect)] = [
    (CGPoint(x: 0, y: 450), CGRect(x: 0, y: 25, width: 720, height: 875)),
    (CGPoint(x: 1439, y: 450), CGRect(x: 720, y: 25, width: 720, height: 875)),
    (CGPoint(x: 700, y: 0), CGRect(x: 0, y: 25, width: 1440, height: 875)),
    (CGPoint(x: 700, y: 24), CGRect(x: 0, y: 25, width: 1440, height: 875)),
    (CGPoint(x: 0, y: 0), CGRect(x: 0, y: 25, width: 720, height: 437.5)),
    (CGPoint(x: 0, y: 899), CGRect(x: 0, y: 462.5, width: 720, height: 437.5)),
  ]

  @Test(arguments: places.indices) func aFloatingWindowLetGoWhereMacOSTilesIsLeftToMacOS(index: Int) {
    let (point, tile) = Self.places[index]
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
    let (point, tile) = Self.places[index]
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

  /// A docked window let go in macOS's part of the screen belongs to whoever takes it (board 1.56). macOS does not always: it fills the screen only
  /// for a pointer that has rested in the menu bar, and in the band short of its own point it does nothing at all. Then nothing was
  /// offered and nothing happens: the window goes home to its slot in one move, and its neighbours are not touched. At all three
  /// edges and in the corners alike, over the Desktop's part of the band too.
  @Test(arguments: [
    CGPoint(x: 5, y: 450), CGPoint(x: 1434, y: 450), CGPoint(x: 720, y: 27), CGPoint(x: 300, y: 30), CGPoint(x: 5, y: 30),
    CGPoint(x: 1434, y: 30),
  ])
  func aDockedWindowThatMacOSDoesNotTakeGoesHomeFromTheBand(point: CGPoint) {
    let s = scene()
    let before = s.outcome
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop, holding: 0.3)
    s.h.system.moveDrag(to: point, holding: 1)
    #expect(s.h.overlays.preview == nil)
    s.h.system.clearFrameLog()
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a), "at \(point)")
    #expect(s.outcome == before, "at \(point)")
    #expect(s.h.system.frameLog.map(\.window) == [s.a], "home in one move, nobody else moved: \(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty)
    s.expectNothingLeftBehind()
  }

  /// Thrown into the menu bar and let go at once: macOS's own place, and macOS leaves it. Arbor cannot know at the release, so it looks for
  /// macOS's move for a moment, and then takes the window home.
  @Test func aDockedWindowThrownIntoTheMenuBarGoesHomeWhenMacOSLeavesIt() {
    let s = scene()
    let before = s.outcome
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.clearFrameLog()
    s.h.system.endDrag()
    #expect(s.h.system.frameLog.isEmpty, "not at the release: macOS may be about to move it")
    s.h.scheduler.advance(by: 0.25)
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    s.h.scheduler.advance(by: 3)
    #expect(s.outcome == before)
    #expect(s.h.system.frameLog.map(\.window) == [s.a], "\(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty)
    s.expectNothingLeftBehind()
  }

  /// While Arbor looks, the window is still in the hand as far as everything else goes: whatever ends a drag ends the wait.
  @Test func theWaitForMacOSEndsWithWhateverEndsADrag() {
    let s = scene()
    let before = s.outcome
    s.h.system.beginDrag(s.a)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    s.h.system.endDrag()
    s.h.run("pause")
    s.h.run("resume")
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isDocked(s.a))
    #expect(s.outcome.workspaces == before.workspaces)
    s.expectNothingLeftBehind()

    // The next drag, of another window, begun within the wait.
    let other = scene()
    other.h.system.beginDrag(other.a)
    other.h.system.moveDrag(to: other.onDesktop)
    other.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    other.h.system.endDrag()
    other.h.system.drag(other.c, through: [other.frame(other.c).center, other.onDesktop])
    other.h.scheduler.advance(by: 3)
    #expect(other.h.workspace.isDocked(other.a) && other.h.workspace.isFloating(other.c))
    other.expectNothingLeftBehind()
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
    s.h.system.endDrag()
    s.h.system.holdModifierKeys([])
    s.h.scheduler.advance(by: 3)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.frame(s.c) == CGRect(x: 720, y: 25, width: 720, height: 875))
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
    #expect(third.h.workspace.isFloating(third.c))
    #expect(third.h.system.frameLog.isEmpty, "\(third.h.system.frameLog)")

    // With that switch off ⌥ means nothing to anybody.
    let other = scene(MacTiling(screenEdges: true, menuBar: true, optionKey: false))
    other.h.system.holdModifierKeys(.option)
    other.h.system.drag(other.c, through: [other.frame(other.c).center, other.edge(.bottom, of: other.b)])
    #expect(other.h.workspace.isDocked(other.c))
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
  /// tenth of a second what macOS will do, and nothing was promised. So a floating window stays where it was let go, and nothing is said.
  @Test func thrownIntoTheMenuBarAndLetGoAtOnceTheWindowStaysAsItIs() {
    let s = scene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: s.onDesktop)
    s.h.system.moveDrag(to: CGPoint(x: 700, y: 10), holding: 0.05)
    let letGo = s.frame(s.c)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == letGo)
    #expect(s.h.workspace.isFloating(s.c))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
    #expect(s.h.overlays.messages.isEmpty, "macOS took nothing, so there is nothing to say: \(s.h.overlays.messages.map(\.model.line))")
    s.expectNothingLeftBehind()
  }

  /// At the sides macOS waits for nothing.
  @Test func thrownAgainstTheSideItIsTiledAtOnce() {
    let s = scene()
    s.h.system.drag(s.c, through: [s.frame(s.c).center, CGPoint(x: 0, y: 450)], holding: 0)
    s.h.scheduler.advance(by: 3)
    #expect(s.frame(s.c) == CGRect(x: 0, y: 25, width: 720, height: 875))
    #expect(s.h.system.frameLog.isEmpty, "\(s.h.system.frameLog)")
  }

  /// macOS was seen to take a window that cannot change its size as well, and to move it into the tile as it is.
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
    let s = DragScene { $0.soleFloatTakesDesktop = true }
    s.h.system.tiling = .on
    s.h.scheduler.advance(by: 3)
    s.h.system.clearFrameLog()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 1439, y: 450), holding: 1)
    s.h.system.endDrag()
    s.h.scheduler.advance(by: 3)
    #expect(!s.h.system.frameLog.contains { $0.window == s.c }, "Arbor set no frame on it: \(s.h.system.frameLog)")
    #expect(s.frame(s.c) == CGRect(x: 720, y: 25, width: 720, height: 875))
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
}
