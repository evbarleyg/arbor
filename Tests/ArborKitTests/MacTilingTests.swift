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

  /// One point further in, the edge is Arbor's, as it is with macOS's tiling off.
  @Test(arguments: [MacTiling.on, .off]) func justInsideTheEdgeArborDocks(tiling: MacTiling) {
    for (point, edge) in [
      (CGPoint(x: 1, y: 450), Edge.left), (CGPoint(x: 1438, y: 450), .right), (CGPoint(x: 700, y: 25), .top),
      (CGPoint(x: 700, y: 899), .bottom),
    ] {
      let s = scene(tiling)
      s.h.system.beginDrag(s.c)
      s.h.system.moveDrag(to: point, holding: 0.3)
      #expect(s.h.overlays.preview != nil, "\(edge)")
      s.h.system.endDrag()
      s.h.scheduler.advance(by: 3)
      #expect(s.h.workspace.isDocked(s.c), "\(edge)")
      s.expectNothingLeftBehind()
    }
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

  /// The preview is a promise, so it goes as the pointer reaches macOS's part of the edge and comes back as it leaves.
  @Test func thePreviewGoesAtTheLastPointAndComesBack() {
    let s = scene()
    s.h.system.beginDrag(s.c)
    s.h.system.moveDrag(to: CGPoint(x: 5, y: 450))
    #expect(s.h.overlays.preview != nil)
    s.h.system.moveDrag(to: CGPoint(x: 0, y: 450))
    #expect(s.h.overlays.preview == nil)
    s.h.system.moveDrag(to: CGPoint(x: 4, y: 450))
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
    #expect(s.h.overlays.messages.allSatisfy { !$0.model.line.hasPrefix("macOS tiles") })
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
        #expect(said == ["macOS tiles windows let go here, so Arbor stood aside · Check Setup… in the menu"], "round \(round)")
      } else {
        #expect(said.isEmpty, "round \(round)")
      }
    }
  }
}
