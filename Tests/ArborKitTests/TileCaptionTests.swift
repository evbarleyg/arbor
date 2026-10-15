import ArborCore
import ArborIPC
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Tiles say which window they are (collab/QUESTIONS.md, Q15; docs/features/F15-appearance-options.md). The measure: two windows of one app
/// can be told apart in the overview without a click.
@Suite @MainActor struct TileCaptionTests {
  /// A laptop's display, and two Safari windows docked beside Mail in places too low for them: two tiles.
  private func makeHarness(
    titles: (String, String) = ("Train times", "Bread without kneading"), settings: Settings = Settings(), id: String = "main",
    size: CGSize = CGSize(width: 1440, height: 900)
  ) -> (Harness, WindowID, WindowID) {
    let frame = CGRect(origin: .zero, size: size)
    var settings = settings
    if size.height == 900 { settings.minimumUsableHeight = 500 }
    let h = Harness(
      displays: [DisplaySnapshot(id: DisplayID(id), frame: frame, visibleFrame: frame, isMain: true)], settings: settings)
    h.system.cursor = frame.center
    let a = h.system.open(app: "Safari", title: titles.0, pid: 11)
    let b = h.system.open(app: "Safari", title: titles.1, pid: 11)
    let c = h.system.open(app: "Mail", title: "Inbox", pid: 12)
    h.start()
    h.run("dock \(c.rawValue) left")
    h.run("dock \(a.rawValue) right")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    h.run("show-all")
    return (h, a, b)
  }

  private func tile(of window: WindowID, _ h: Harness) -> TileModel? {
    h.overlays.tiles[h.display]?.first { $0.kind == .window && $0.items.first?.window == window }
  }

  private func caption(of window: WindowID, _ h: Harness) -> String? {
    tile(of: window, h).flatMap { TileArt($0, isDark: false) { _ in nil }.caption?.text }
  }

  @Test func asItShipsTwoWindowsOfOneAppAreToldApartByTheirTiles() throws {
    #expect(Settings().tileStyle == "name")
    let (h, a, b) = makeHarness()
    #expect(caption(of: a, h) == "Train times" && caption(of: b, h) == "Bread without kneading")
  }

  @Test func theSpacesNameComesFirstThenTheTitleThenTheApp() throws {
    let (h, a, b) = makeHarness(titles: ("Train times", ""))
    #expect(caption(of: b, h) == "Safari", "a window without a title")
    h.run("zoom \(a.rawValue)")
    h.run("name Journey")
    h.run("show-all")
    #expect(caption(of: a, h) == "Journey")
    h.system.setTitle(b, "   ")
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: b, h) == "Safari", "nor is blank a title")
  }

  @Test func aNewTitleIsDrawnAndNothingMoves() throws {
    let (h, a, b) = makeHarness()
    let frames = h.system.windows.mapValues(\.snapshot.frame)
    let other = tile(of: b, h)
    h.system.setTitle(a, "Platform 4")
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: a, h) == "Platform 4")
    #expect(tile(of: b, h) == other && h.system.windows.mapValues(\.snapshot.frame) == frames)
    expectWindowsMatchLayout(h)
  }

  /// A terminal gives its window a new title at every command, some apps ten times a second.
  @Test func aFlurryOfTitlesIsDrawnAFewTimesASecondAndEndsWithTheLast() throws {
    let (h, a, _) = makeHarness()
    let before = h.overlays.updateLog.count
    for step in 1...50 {
      h.system.setTitle(a, "Building \(step) of 50")
      h.scheduler.advance(by: 0.02)
    }
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: a, h) == "Building 50 of 50")
    #expect(h.overlays.updateLog.count - before <= 6, "\(h.overlays.updateLog.count - before) scenes in a second")
  }

  @Test func aTitleThatIsNotDrawnCostsNothing() throws {
    let (h, a, b) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("name Journey")
    h.run("show-all")
    let c = try #require(h.system.windows.keys.sorted().last)
    let before = h.overlays.updateLog.count
    h.system.setTitle(a, "Platform 4")  // its tile shows the space's name
    h.system.setTitle(c, "Inbox (3)")  // no tile
    h.run("hold still")
    let held = h.overlays.updateLog.count
    h.system.setTitle(b, "Sourdough")  // held: the app's name stands there
    h.scheduler.advance(by: 1)
    #expect(held - before <= 1 && h.overlays.updateLog.count == held)
  }

  /// The ring is worked out anew for every layout, and is taken away while a mouse button is down. A title is no layout.
  @Test func aNewTitleLeavesTheLineRoundTheFocusedWindowAlone() throws {
    let (h, a, _) = makeHarness()
    let c = try #require(h.system.windows.keys.sorted().last)
    h.system.userFocus(c)
    let ring = try #require(h.overlays.scenes[h.display]?.focusRing)
    h.system.mouseDown = true
    h.system.setTitle(a, "Platform 4")
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: a, h) == "Platform 4" && h.overlays.scenes[h.display]?.focusRing == ring)
  }

  /// On a shared screen a title is somebody's business.
  @Test(arguments: ["hold", "hold still"]) func whileTheViewIsHeldTheAppsNameStandsInForTheTitle(hold: String) throws {
    let (h, a, b) = makeHarness()
    h.run(hold)
    #expect(caption(of: a, h) == "Safari" && caption(of: b, h) == "Safari")
    #expect(tile(of: a, h)?.helpTag == "Safari", "and in the help tag")
    h.system.setTitle(a, "Platform 4")
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: a, h) == "Safari")
    h.run("release")
    #expect(caption(of: a, h) == "Platform 4" && caption(of: b, h) == "Bread without kneading", "its person let go")
  }

  /// The end of a hold can come by itself, when the time is up or the call is over, with the screen still shared. What a hold
  /// kept out of view waits for the view to move, and so do the titles.
  @Test func afterAHoldThatEndedByItselfTheTitlesWaitUntilTheViewMoves() throws {
    let (h, a, b) = makeHarness()
    h.run("hold still 1")
    h.scheduler.advance(by: 61)
    #expect(!h.controller.isHeld)
    #expect(caption(of: a, h) == "Safari" && tile(of: b, h)?.helpTag == "Safari")
    h.system.setTitle(a, "Platform 4")
    h.scheduler.advance(by: 0.3)
    #expect(caption(of: a, h) == "Safari")
    h.run("zoom \(b.rawValue)", from: .shortcut)
    h.run("show-all", from: .shortcut)
    #expect(caption(of: a, h) == "Platform 4" && caption(of: b, h) == "Bread without kneading")
  }

  /// Arbor learns of a call in progress a moment after it has laid everything out.
  @Test func atAStartNoTitleIsDrawnBeforeItIsKnownWhetherACallIsOn() throws {
    var settings = Settings()
    settings.holdStillFor = ["com.example.safari"]
    let (h, a, _) = makeHarness(settings: settings)
    #expect(h.controller.isHeld)
    h.run("pause")
    h.overlays.forgetCaptions()
    h.run("resume")
    #expect(h.controller.isHeld && caption(of: a, h) == "Safari")
    #expect(!h.overlays.captionsEverShown.contains("Train times"), "not for a moment")
  }

  /// A click on the tile of a tab group shows the tab in front.
  @Test func aTabGroupsTileIsCalledAfterTheTabInFront() throws {
    var settings = Settings()
    settings.tabsEnabled = true
    let (h, a, b) = makeHarness(settings: settings)
    #expect(h.run("layout Mail | Desktop | [Safari Safari*]").ok)
    h.run("set minimumUsableWidth 1000")
    let stack = try #require(h.overlays.tiles[h.display]?.first { $0.items.count == 2 && $0.kind == .window })
    guard case .stack(let tabs, let active)? = h.workspace.tree[stack.node]?.kind else {
      Issue.record("the tile stands for no tab group")
      return
    }
    #expect(Set(tabs) == [a, b])
    #expect(stack.title == (tabs[active] == a ? "Train times" : "Bread without kneading"))
    // The other tab comes to the front: the tile is called after that one.
    h.system.userFocus(tabs[1 - active])
    h.run("show-all")
    h.scheduler.advance(by: 0.3)
    let again = try #require(h.overlays.tiles[h.display]?.first { $0.node == stack.node })
    #expect(again.title == (tabs[1 - active] == a ? "Train times" : "Bread without kneading"))
  }

  /// With live reflow the display shows a trial, not the arrangement at rest.
  @Test func duringADragTheTilesThatShowAreTheOnesThatFollow() throws {
    var settings = Settings()
    settings.reflowWhileDragging = true
    let (h, a, b) = makeHarness(settings: settings)
    let c = try #require(h.system.windows.keys.sorted().last)
    h.run("float \(c.rawValue)")
    h.system.beginDrag(c)
    h.system.moveDrag(to: CGPoint(x: 2, y: 450), holding: 1)
    let shown = try #require(h.overlays.scenes[h.display])
    h.system.setTitle(a, "Platform 4")
    h.scheduler.advance(by: 0.3)
    let after = try #require(h.overlays.scenes[h.display])
    #expect(after.seams == shown.seams && after.tiles.map(\.frame) == shown.tiles.map(\.frame), "the trial stays up")
    #expect(after.tiles.contains { $0.title == "Platform 4" } || !shown.tiles.contains { $0.items.first?.window == a })
    h.system.endDrag()
    _ = b
  }

  @Test func aNameTheSpaceWasGivenIsShownHeldOrNot() throws {
    let (h, a, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("name Journey")
    h.run("show-all")
    h.run("hold still")
    #expect(caption(of: a, h) == "Journey", "its person chose that word for the screen")
  }

  @Test func withoutRoomForEightLettersTheIconStandsAlone() throws {
    let (h, a, _) = makeHarness()
    var model = try #require(tile(of: a, h))
    // Eight letters of eleven points, and eight points of margin on either side.
    for (width, shows) in [(63.0, false), (68.0, false), (69.0, true), (157.0, true)] {
      model.frame.size = CGSize(width: width, height: 851)
      let art = TileArt(model, isDark: false) { _ in nil }
      #expect((art.caption != nil) == shows, "\(width)")
      #expect(art.icons.count == 1, "\(width)")
      #expect(model.helpTag == "Train times", "\(width): what is not drawn can still be asked for")
    }
    // The rule is about words that would be cut. What fits whole is drawn, as it always was.
    model.frame.size = CGSize(width: 63, height: 851)
    for short in ["Mail", "Web", "Notes"] {
      model.name = short
      #expect(TileArt(model, isDark: false) { _ in nil }.caption?.text == short)
    }
    model.name = "Correspondence"
    #expect(TileArt(model, isDark: false) { _ in nil }.caption == nil)
  }

  @Test func everyTileHasItsCaptionAsItsHelpTag() throws {
    // So small that the two Safari windows are one tile and Mail is another.
    let (h, _, _) = makeHarness(size: CGSize(width: 700, height: 500))
    var tiles = try #require(h.overlays.tiles[h.display])
    #expect(Set(tiles.map(\.kind)) == [.group, .window])
    var desktop = try #require(tiles.first)
    (desktop.kind, desktop.items) = (.desktop, [])
    #expect(desktop.helpTag == "Desktop")
    tiles.append(desktop)
    for tile in tiles { #expect(tile.helpTag == tile.title && !tile.helpTag.isEmpty, "\(tile.kind)") }
    for style in TileStyle.allCases {
      var tile = try #require(tiles.first)
      tile.style = style
      #expect(!tile.helpTag.isEmpty, "whatever is drawn: \(style)")
    }
  }

  @Test func theIconStyleStillShowsNoWords() throws {
    var settings = Settings()
    settings.tileStyle = "icon"
    let (h, a, _) = makeHarness(settings: settings)
    #expect(caption(of: a, h) == nil && tile(of: a, h)?.helpTag == "Train times")
  }

  /// A title is drawn and nothing else.
  @Test func aTitleCrossesNoRecorderNoLogNoStateAndNoWatch() throws {
    let secret = "Quokkadoo\(UInt32.random(in: 0...UInt32.max))"
    let (h, a, b) = makeHarness(titles: ("\(secret) accounts", "\(secret) diary"), id: "display-\(secret.dropFirst(9))")
    let feed = EventFeed(controller: h.controller)
    var heard: [String] = []
    guard case .watch(let options) = try Command.parse("watch") else {
      Issue.record("`watch` is no longer the command that watches")
      return
    }
    _ = feed.subscribe(options) { heard.append($0) }
    h.run("trace on tiles")
    #expect(caption(of: a, h) == "\(secret) accounts", "it is drawn")
    h.system.setTitle(a, "\(secret) ledger")
    h.scheduler.advance(by: 0.3)
    h.run("zoom \(b.rawValue)")
    h.run("show-all")
    h.overlays.actions?.tileActivated(display: h.display, node: try #require(tile(of: a, h)).node)
    h.run("show-all")
    h.run("hold still")
    h.run("release")
    // Its line in the log names the display, which tells this run's lines from those of other tests.
    h.run("find")
    h.overlays.dismissFinder()
    h.scheduler.advance(by: 2)
    // `state` has always listed every window with its title, for the person who asks. What it says of tiles has none.
    let state = try #require(h.run("state").state)
    let tiles = String(decoding: try JSONEncoder().encode(state.displays), as: UTF8.self)
    h.run("trace off")

    #expect(caption(of: a, h) == "\(secret) ledger")
    #expect(!(h.lastTrace ?? "").isEmpty && h.lastTrace?.contains(secret) == false, "the trace")
    #expect(!heard.isEmpty && !heard.contains { $0.contains(secret) }, "watch")
    #expect(state.displays.contains { !$0.tiles.isEmpty } && !tiles.contains(secret), "state's tiles")
    let log = ((try? String(contentsOf: ArborPaths.logFile.appendingPathExtension("1"), encoding: .utf8)) ?? "")
      + (try String(contentsOf: ArborPaths.logFile, encoding: .utf8))
    #expect(log.contains(h.display.rawValue), "this run's lines are in the file")
    #expect(!log.contains(secret), "the log")
  }
}
