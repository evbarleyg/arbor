import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// The surface behind docked windows follows the layout (docs/features/F15-appearance-options.md).
@Suite @MainActor struct BackdropTests {
  /// Three floating windows, started.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    h.start()
    return (h, a, b, c)
  }

  func backdrop(_ h: Harness, on display: DisplayID? = nil) -> BackdropModel? {
    h.overlays.scenes[display ?? h.display]?.backdrop
  }

  /// A slot as the surface covers it with the default gap of 12.
  func grown(_ rect: CGRect?) -> CGRect { (rect ?? .null).insetBy(dx: -6, dy: -6) }

  /// The surface is exactly the slots in view, each grown by half the gap: it covers all of them and
  /// nothing else, and keeps off the Desktop.
  func expectBackdropMatchesLayout(
    _ h: Harness, on display: DisplayID? = nil, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let display = display ?? h.display
    guard let layout = h.controller.layouts[display] else {
      Issue.record("no layout", sourceLocation: sourceLocation)
      return
    }
    let slots = Array(layout.windowFrames.values) + layout.tiles.map(\.frame)
    let rects = backdrop(h, on: display)?.rects ?? []
    #expect(rects.isEmpty == slots.isEmpty, sourceLocation: sourceLocation)
    for slot in slots {
      let covered = rects.map { $0.intersection(grown(slot)) }.filter { !$0.isNull }.map(\.area).reduce(0, +)
      #expect(covered == grown(slot).area, "\(slot) is not covered", sourceLocation: sourceLocation)
    }
    #expect(
      rects.map(\.area).reduce(0, +) == slots.map { grown($0).area }.reduce(0, +), "something else is covered",
      sourceLocation: sourceLocation)
    if let desktop = layout.desktopFrame {
      #expect(rects.allSatisfy { !$0.overlaps(desktop) }, "the Desktop is covered", sourceLocation: sourceLocation)
    }
  }

  @Test func nothingDockedMeansNoBackdrop() {
    let (h, _, _, _) = makeHarness()
    #expect(h.overlays.scenes[h.display] != nil)
    #expect(backdrop(h) == nil)
  }

  @Test func dockingPutsTheSurfaceBehindTheSlot() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(
      backdrop(h)
        == BackdropModel(
          frame: h.visibleFrame, rects: [grown(h.frame(a))], growth: 6, dim: 0.25, blur: 0, tint: 0,
          desktop: h.layout?.desktopFrame, desktopEdge: 0.05))
    #expect(h.layout?.desktopFrame != nil)
  }

  @Test func neighboursShareOneSurfaceAndTheDesktopStaysClear() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    #expect(backdrop(h)?.rects == [grown(h.frame(a)!.union(h.frame(c)!))], "the gap between them is covered")
    h.run("dock \(b.rawValue) right")
    #expect(backdrop(h)?.rects == [grown(h.frame(a)!.union(h.frame(c)!)), grown(h.frame(b))])
    expectBackdropMatchesLayout(h)
    // The surface stops half a gap short of the Desktop and of the screen's edges.
    let desktop = h.layout!.desktopFrame!
    #expect(backdrop(h)!.rects[0].maxX == desktop.minX - 6 && backdrop(h)!.rects[1].minX == desktop.maxX + 6)
    #expect(backdrop(h)!.rects[0].minX == h.visibleFrame.minX + 6 && backdrop(h)!.rects[0].minY == h.visibleFrame.minY + 6)
  }

  @Test func zoomingMovesTheSurfaceWithTheCamera() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let overview = backdrop(h)
    h.run("zoom \(a.rawValue)")
    #expect(backdrop(h)?.rects == [h.visibleFrame.insetBy(dx: 6, dy: 6)])
    expectBackdropMatchesLayout(h)
    h.run("back")
    #expect(backdrop(h) == overview)
    h.run("desktop")
    #expect(backdrop(h) == nil, "nothing docked is in view")
    h.run("show-all")
    #expect(backdrop(h) == overview)
  }

  @Test func floatingAWindowTakesItOffTheSurface() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("float \(a.rawValue)")
    #expect(backdrop(h)?.rects == [grown(h.frame(b))])
    expectBackdropMatchesLayout(h)
    h.run("float-all")
    #expect(backdrop(h) == nil)
  }

  @Test func draggingAWindowOntoTheDesktopTakesItOffTheSurface() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let start = h.frame(a)!
    h.system.drag(a, through: [CGPoint(x: start.midX, y: start.minY + 10), h.layout!.desktopFrame!.center])
    #expect(h.workspace.isFloating(a))
    #expect(backdrop(h)?.rects == [grown(h.frame(b))])
  }

  @Test func closingAWindowShrinksTheSurfaceAndTheLastOneRemovesIt() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(b.rawValue) right")
    h.system.close(b)
    #expect(backdrop(h)?.rects.count == 1)
    expectBackdropMatchesLayout(h)
    h.system.close(c)
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
    h.system.close(a)
    #expect(backdrop(h) == nil)
  }

  @Test func minimizedHiddenAndOtherSpaceWindowsLeaveTheSurface() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let both = backdrop(h)
    h.system.setMinimized(b, true)
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
    expectBackdropMatchesLayout(h)
    h.system.setMinimized(b, false)
    #expect(backdrop(h) == both)

    h.system.setOnActiveSpace(b, false)
    h.scheduler.runPending()
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
    h.system.setOnActiveSpace(a, false)
    h.scheduler.runPending()
    #expect(backdrop(h) == nil, "a Space with none of the docked windows shows the plain wallpaper")
    h.system.setOnActiveSpace(a, true)
    h.system.setOnActiveSpace(b, true)
    h.scheduler.runPending()
    #expect(backdrop(h) == both)
  }

  @Test func tilesLieOnTheSurfaceToo() {
    // With room made for it (F61) the window would be no tile.
    var settings = Settings()
    settings.makeRoom = false
    let (h, a, b, _) = makeHarness(settings: settings)
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 900, height: 600))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let tile = h.overlays.tiles[h.display]![0]
    #expect(tile.items.first?.window == big)
    #expect(backdrop(h)?.rects == [grown(h.frame(a)), grown(h.frame(b)!.union(tile.frame))])
    expectBackdropMatchesLayout(h)
  }

  @Test func whenTheDesktopIsATileTheSurfaceRunsUnderIt() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    // The two columns squeeze the Desktop between them until it is too narrow to use.
    h.run("resize \(a.rawValue) right 300")
    h.run("resize \(b.rawValue) left 300")
    #expect(h.overlays.tiles[h.display]?.contains { $0.kind == .desktop } == true)
    #expect(backdrop(h)?.rects == [h.visibleFrame.insetBy(dx: 6, dy: 6)])
  }

  @Test func aWindowThatSitsInsideItsSlotLeavesNoHole() {
    let (h, a, b, _) = makeHarness()
    h.system.setMaximumSize(a, CGSize(width: 400, height: 500))
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
    let slot = h.layout!.windowFrames[a]!
    #expect(h.frame(a)!.width < slot.width, "the app kept the window smaller than its slot")
    #expect(backdrop(h)?.rects == [grown(slot.union(h.frame(b)!))])
  }

  @Test func changesThatKeepTheSameAreaLeaveTheBackdropAsItWas() {
    let (h, a, _, c) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    let before = backdrop(h)
    let seam = h.overlays.seams[h.display]!.first { $0.axis == .vertical }!
    let height = h.frame(a)!.height
    h.overlays.dragSeam(seam, by: 90)
    #expect(h.frame(a)!.height == height + 90)
    #expect(backdrop(h) == before, "the seam between two windows moved inside the surface")
    h.run("dock \(a.rawValue) down")
    #expect(h.frame(a)!.minY > h.frame(c)!.minY)
    #expect(backdrop(h) == before, "two windows traded places")
  }

  @Test func draggingTheSeamBesideTheDesktopMovesTheSurfacesEdge() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let edge = backdrop(h)!.rects[0].maxX
    h.overlays.dragSeam(h.overlays.seams[h.display]![0], by: 80)
    #expect(backdrop(h)!.rects[0].maxX == edge + 80)
    expectBackdropMatchesLayout(h)
  }

  @Test func eachDisplayHasItsOwnSurface() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
    #expect(backdrop(h, on: side.id) == nil)

    h.system.cursor = CGPoint(x: 1800, y: 300)
    h.run("dock \(b.rawValue) right")
    #expect(backdrop(h, on: side.id)?.rects == [grown(h.frame(b))])
    #expect(backdrop(h, on: side.id)?.frame == side.visibleFrame)
    #expect(backdrop(h)?.frame == h.visibleFrame)
    #expect(backdrop(h)?.rects == [grown(h.frame(a))], "the other display's surface is untouched")
    expectBackdropMatchesLayout(h)
    expectBackdropMatchesLayout(h, on: side.id)

    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(backdrop(h, on: side.id) == nil, "a display that went away keeps nothing on screen")
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
  }

  @Test func aDisplayThatChangesSizeGetsASurfaceThatFits() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    var smaller = FakeWindowSystem.standardDisplay
    smaller.frame.size = CGSize(width: 1024, height: 768)
    smaller.visibleFrame = CGRect(x: 0, y: 25, width: 1024, height: 743)
    h.system.setDisplays([smaller])
    #expect(backdrop(h)?.frame == smaller.visibleFrame)
    #expect(backdrop(h)?.rects == [smaller.visibleFrame.insetBy(dx: 6, dy: 6)])
  }

  // MARK: Settings

  @Test func withoutDimOrBlurThereIsNoBackdrop() {
    var settings = Settings()
    settings.dimBehindArranged = 0
    settings.desktopEdge = 0
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h) == nil)
  }

  @Test func tintAloneIsEnoughForABackdrop() {
    var settings = Settings()
    settings.dimBehindArranged = 0
    settings.desktopEdge = 0
    settings.tintBehindArranged = 0.3
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.dim == 0 && backdrop(h)?.tint == 0.3)
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
  }

  // MARK: The Desktop's edge

  @Test func theDesktopBetweenDockedWindowsHasALineAroundIt() {
    let (h, a, b, _) = makeHarness()
    #expect(backdrop(h) == nil, "nothing is docked: the Desktop is the whole display and needs no line")
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    #expect(backdrop(h)?.desktop == h.layout?.desktopFrame)
    #expect(backdrop(h)?.desktopEdge == 0.05)

    // It follows the gap beside the Desktop.
    let before = backdrop(h)?.desktop
    h.run("resize \(a.rawValue) right 100")
    #expect(backdrop(h)?.desktop == h.layout?.desktopFrame)
    #expect(backdrop(h)?.desktop?.minX == before.map { $0.minX + 100 })
  }

  @Test func theLineAloneIsEnoughForABackdropThatDarkensNothing() {
    var settings = Settings()
    settings.dimBehindArranged = 0
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.fill(accent: RGBA(red: 0, green: 0.5, blue: 1)).alpha == 0)
    #expect(backdrop(h)?.desktopOutline(width: 1) != nil)
  }

  @Test func whereTheDesktopIsNotInViewThereIsNoLine() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(backdrop(h) != nil)
    #expect(backdrop(h)?.desktop == nil && backdrop(h)?.desktopOutline(width: 1) == nil)

    // As a tile it has a tile's own border.
    h.run("show-all")
    h.run("resize \(a.rawValue) right 300")
    h.run("resize \(b.rawValue) left 300")
    #expect(h.overlays.tiles[h.display]?.contains { $0.kind == .desktop } == true)
    #expect(backdrop(h)?.desktop == nil)

    // Framed by itself it is the whole view.
    h.run("desktop")
    #expect(backdrop(h) == nil)
  }

  @Test func theLineLiesJustInsideTheDesktopsRectangle() throws {
    let desktop = CGRect(x: 500, y: 40, width: 400, height: 800)
    var model = BackdropModel(
      frame: CGRect(x: 0, y: 25, width: 1440, height: 875), rects: [CGRect(x: 6, y: 31, width: 480, height: 860)],
      growth: 6, dim: 0.25, blur: 0, desktop: desktop, desktopEdge: 0.05)
    let outline = try #require(model.desktopOutline(width: 0.5, radius: 17))
    #expect(outline == RoundedPath.rect(desktop.insetBy(dx: 0.25, dy: 0.25), radius: 16.75))
    #expect(model.desktopOutline(width: 0) == nil && model.desktopOutline(width: .nan) == nil)
    model.desktopEdge = 0
    #expect(model.desktopOutline(width: 0.5) == nil)
    model.desktopEdge = 0.05
    model.desktop = CGRect(x: 500, y: 40, width: 0.2, height: 800)
    #expect(model.desktopOutline(width: 0.5) == nil, "too narrow for a line on both sides")
  }

  // MARK: Tint

  @Test func theTintLiesOverTheBlack() {
    let accent = RGBA(red: 0, green: 0.48, blue: 1)
    func fill(dim: Double, tint: Double) -> RGBA {
      BackdropModel(frame: .zero, rects: [], growth: 6, dim: dim, blur: 0, tint: tint).fill(accent: accent)
    }
    #expect(fill(dim: 0.25, tint: 0) == RGBA.black.withAlpha(0.25), "without a tint it is as before")
    #expect(fill(dim: 0, tint: 0.4) == accent.withAlpha(0.4))
    #expect(fill(dim: 0.5, tint: 1) == accent, "all of the tint hides the black")
    let both = fill(dim: 0.5, tint: 0.5)
    #expect(abs(both.alpha - 0.75) < 1e-9, "half of what the tint lets through is stopped by the black")
    #expect(abs(both.blue - 2.0 / 3) < 1e-9 && both.red == 0, "two parts of accent to one of black")
    #expect(fill(dim: 0, tint: 0).alpha == 0)
  }

  @Test func blurAloneIsEnoughForABackdrop() {
    var settings = Settings()
    settings.dimBehindArranged = 0
    settings.blurBehindArranged = 0.6
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.dim == 0 && backdrop(h)?.blur == 0.6)
    #expect(backdrop(h)?.rects == [grown(h.frame(a))])
  }

  @Test func reloadSettingsChangesTheBackdropAtOnce() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    var edited = Settings()
    edited.dimBehindArranged = 0.5
    edited.blurBehindArranged = 1
    h.controller.loadSettings = { edited }
    #expect(h.run("reload-settings").ok)
    #expect(backdrop(h)?.dim == 0.5 && backdrop(h)?.blur == 1)
    edited.tintBehindArranged = 0.2
    edited.desktopEdge = 0.5
    h.run("reload-settings")
    #expect(backdrop(h)?.tint == 0.2 && backdrop(h)?.desktopEdge == 0.5)
    edited.dimBehindArranged = 0
    edited.blurBehindArranged = 0
    edited.tintBehindArranged = 0
    edited.desktopEdge = 0
    h.run("reload-settings")
    #expect(backdrop(h) == nil)
  }

  @Test func amountsOutOfRangeAreMadeSafeBeforeTheyAreDrawn() {
    var settings = Settings()
    settings.dimBehindArranged = 40
    settings.blurBehindArranged = .nan
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.dim == 1 && backdrop(h)?.blur == 0)
  }

  @Test func theLeftoversAreMadeSafeToo() {
    var settings = Settings()
    settings.tintBehindArranged = -3
    settings.desktopEdge = 7
    settings.tileFade = .infinity
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.tint == 0 && backdrop(h)?.desktopEdge == 1)
    #expect(h.overlays.scenes[h.display]?.tileFade == 0.2)
  }

  @Test func tilesFadeForAsLongAsTheSettingSays() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    #expect(h.overlays.scenes[h.display]?.tileFade == 0.2)
    var edited = Settings()
    edited.tileFade = 0
    h.controller.loadSettings = { edited }
    h.run("reload-settings")
    #expect(h.overlays.scenes[h.display]?.tileFade == 0)
  }

  @Test func theGapDecidesHowFarTheSurfaceReachesAndHowRoundItIs() {
    var settings = Settings()
    settings.gap = 20
    let (h, a, _, _) = makeHarness(settings: settings)
    h.run("dock \(a.rawValue) left")
    #expect(backdrop(h)?.rects == [h.frame(a)!.insetBy(dx: -10, dy: -10)])
    #expect(backdrop(h)?.growth == 10)

    settings.gap = 0
    h.controller.apply(settings: settings)
    #expect(backdrop(h)?.rects == [h.frame(a)!])
    #expect(backdrop(h)?.growth == 0)
  }

  @Test func theSurfacesCornersAreConcentricWithTheWindowsOnIt() throws {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    let model = try #require(backdrop(h))
    let rect = model.rects[0]
    /// Where the straight top edge begins: a continuous corner reaches 1.528665 radii along the edge.
    func reach(_ outline: [PathElement]) -> CGFloat? {
      let stops = outline.compactMap { element -> CGPoint? in
        switch element {
        case .move(let point), .line(let point), .curve(let point, _, _): return point
        case .close: return nil
        }
      }
      return stops.filter { $0.y == rect.minY }.map { ($0.x - rect.minX) / 1.528665 }.min()
    }
    // A window radius of 17 and 6 points of surface around it make 23; on older systems 10 and 6 make 16.
    #expect(abs((reach(model.outline()) ?? 0) - 23) < 1e-6)
    #expect(abs((reach(model.outline(slotRadius: 10)) ?? 0) - 16) < 1e-6)
    #expect(abs((reach(model.outline(slotRadius: -5)) ?? 0) - 6) < 1e-6)
  }

  @Test func quittingTakesTheBackdropAway() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.controller.shutdown()
    #expect(h.overlays.scenes.isEmpty)
  }

  @Test func pausingTakesTheBackdropAwayAndResumingBringsItBack() {
    let (h, a, b, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    let before = backdrop(h)
    #expect(h.run("pause").ok)
    #expect(h.overlays.scenes.isEmpty, "nothing of Arbor's stays on screen during a pause")
    // Settings applied meanwhile draw nothing either.
    var edited = Settings()
    edited.dimBehindArranged = 0.6
    h.controller.apply(settings: edited)
    #expect(h.overlays.scenes.isEmpty)
    #expect(h.run("resume").ok)
    #expect(backdrop(h)?.rects == before?.rects && backdrop(h)?.dim == 0.6)
  }

  /// Final window frames are the same with every cosmetic option on or off.
  @Test func windowsGoToTheSamePlacesWhateverTheAppearance() {
    var plain = Settings()
    plain.dimBehindArranged = 0
    plain.appColours = false
    plain.gapHandles = "off"
    plain.tileStyle = "plain"
    var fancy = Settings()
    fancy.dimBehindArranged = 0.8
    fancy.blurBehindArranged = 1
    fancy.appColourAmount = 1
    fancy.tileStyle = "name"
    var outcomes: [[WindowID: CGRect]] = []
    for settings in [plain, Settings(), fancy] {
      let (h, a, b, c) = makeHarness(settings: settings)
      h.system.setMinimumSize(c, CGSize(width: 900, height: 600))
      for command in [
        "dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) beside \(b.rawValue) bottom",
        "zoom \(b.rawValue)", "back", "resize \(a.rawValue) right 70",
      ] { #expect(h.run(command).ok) }
      outcomes.append(Dictionary(uniqueKeysWithValues: [a, b, c].map { ($0, h.frame($0)!) }))
    }
    #expect(outcomes[0] == outcomes[1] && outcomes[1] == outcomes[2])
  }
}
