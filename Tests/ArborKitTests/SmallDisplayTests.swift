import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The display of a hosted Mac: 1024 × 768, a menu bar above and the Dock below. What arbor-e2e does to real windows there, with
/// the same numbers, so that what it finds can be told from what a display this small brings with it.
@Suite @MainActor struct SmallDisplayTests {
  static let display = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
    visibleFrame: CGRect(x: 0, y: 31, width: 1024, height: 674), isMain: true, isBuiltIn: true)

  /// The frame `b` had before Arbor touched it.
  let untouched = CGRect(x: 220, y: 180, width: 480, height: 348)
  /// Where `float` puts it: its own size, over the docked column for what the Desktop has no room for.
  let floated = CGRect(x: 544, y: 194, width: 480, height: 348)

  /// `[(a / c) | Desktop]`, the column 100 points wider than the half it was docked with, and `b` just floated out of the other
  /// half: the column stays as it is, and what `b` had is the Desktop's.
  /// `makingWay`: floating windows are kept on the Desktop, as until Q20 (`floatingWindowsMakeWay`).
  func makeHarness(makingWay: Bool = false) -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness(displays: [Self.display], settings: makingWay ? .makingWay : Settings())
    let a = h.system.open(app: "Safari", frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    let b = h.system.open(app: "Notes", frame: untouched)
    let c = h.system.open(app: "Mail", frame: CGRect(x: 270, y: 140, width: 480, height: 348))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("resize \(a.rawValue) right 100")
    h.system.clearFrameLog()
    h.run("float \(b.rawValue)")
    return (h, a, b, c)
  }

  func moves(of window: WindowID, _ h: Harness) -> [CGRect] { h.system.frameLog.filter { $0.window == window }.map(\.frame) }

  /// F48, "its own size, also beside a narrow Desktop". Whether or not floating windows make way: `float` is about this window.
  @Test(arguments: [false, true]) func aWindowFloatedBesideADesktopNarrowerThanItselfHasItsOwnSize(makingWay: Bool) {
    let (h, _, b, _) = makeHarness(makingWay: makingWay)
    #expect(h.layout!.desktopFrame == CGRect(x: 618, y: 43, width: 394, height: 650), "\(h.ascii())")
    #expect(h.frame(b) == floated, "as on the real display")
    #expect(moves(of: b, h) == [floated], "in one move")
  }

  /// F18. The frame that is its own hangs over the docked column, where `float` put it. Once it has filled the Desktop it is a window
  /// Arbor placed, and such a window stays on the Desktop: as near to its own frame as there is room for. Filling and staying on
  /// the Desktop are both what floating windows do when they make way.
  @Test func afterFillingADesktopNarrowerThanItselfItStaysOnTheDesktop() {
    let (h, _, b, _) = makeHarness(makingWay: true)
    h.run("set soleFloatTakesDesktop true")
    #expect(h.frame(b) == h.layout!.desktopFrame)
    h.scheduler.advance(by: 1.5)
    h.system.clearFrameLog()
    h.run("set soleFloatTakesDesktop false")
    #expect(h.frame(b) == CGRect(x: 618, y: 194, width: 406, height: 348), "from the Desktop's left edge to the display's right one")
    #expect(moves(of: b, h).count == 1, "in one move")
    #expect(h.workspace.floating[b] == floated, "its own frame is still the one remembered")
  }

  /// Rule 5 of the product's direction: whatever Arbor made of it meanwhile, letting go gives it its own size back. Only where
  /// floating windows make way does Arbor make anything of it.
  @Test(arguments: [true, false]) func lettingGoGivesTheSqueezedWindowItsOwnSizeBack(byQuitting: Bool) {
    let (h, _, b, _) = makeHarness(makingWay: true)
    h.run("set soleFloatTakesDesktop true")
    h.run("set soleFloatTakesDesktop false")
    #expect(h.frame(b)!.width == 406)
    h.system.clearFrameLog()
    if byQuitting { h.controller.shutdown() } else { h.run("float-all") }
    #expect(h.frame(b) == floated)
    #expect(moves(of: b, h).count == 1, "in one move")
  }
}
