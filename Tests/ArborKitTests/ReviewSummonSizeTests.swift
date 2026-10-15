import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Summoning (docs/features/F53-summon.md) next to remembered sizes (F48) and the window that takes the Desktop (F18): a
/// window is summoned at its own size, not at one Arbor gave it, and keeps it.
///
/// Arbor gives a floating window a size only where floating windows make way, as until Q20 (`floatingWindowsMakeWay`): they do in
/// the whole suite.
@Suite @MainActor struct ReviewSummonSizeTests {
  /// [editor | Desktop | browser], framed on the editor, which has the keyboard. The terminal floats, so it is out of
  /// view with the Desktop. So does a note, so that the terminal is not alone there.
  func makeHarness(
    terminal size: CGSize = CGSize(width: 400, height: 300), company: Bool = true, settings: Settings = .makingWay
  ) -> (Harness, editor: WindowID, browser: WindowID, terminal: WindowID) {
    let h = Harness(settings: settings)
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let terminal = h.system.open(
      app: "Terminal", bundleID: "com.apple.Terminal", pid: 1003, frame: CGRect(origin: CGPoint(x: 300, y: 200), size: size))
    if company { h.system.open(app: "Notes", pid: 1004, frame: CGRect(x: 500, y: 400, width: 300, height: 300)) }
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    settle(h)
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    return (h, editor, browser, terminal)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  func isOutOfView(_ window: WindowID, _ h: Harness) -> Bool {
    h.controller.parked.contains(window) && !h.system.isVisible(window)
  }

  // MARK: Its own size (F48, F18)

  /// Between two docked windows the Desktop is 464 points wide, and Arbor squeezes what floats on it to fit.
  @Test func squeezedOntoTheDesktopItIsSummonedAtItsOwnSizeAndKeepsIt() {
    let own = CGSize(width: 900, height: 600)
    let (h, _, _, terminal) = makeHarness(terminal: own)
    #expect(h.frame(terminal)!.width < 500, "the premise: Arbor squeezed it before it went out of view")

    h.run("summon Terminal")
    #expect(h.frame(terminal)?.size == own, "the first time: centred, its own size")
    #expect(h.visibleFrame.contains(h.frame(terminal)!))
    h.run("summon Terminal")
    h.run("summon Terminal")
    #expect(h.frame(terminal)?.size == own)
    h.run("summon Terminal")

    h.run("float-all")
    settle(h)
    #expect(h.frame(terminal)?.size == own, "back to a normal Mac: at the size its user gave it")
  }

  @Test func squeezedAndSummonedQuittingGivesItsOwnSizeBack() {
    let own = CGSize(width: 900, height: 600)
    let (h, _, _, terminal) = makeHarness(terminal: own)
    h.run("summon Terminal")
    h.run("summon Terminal")
    h.controller.shutdown()
    #expect(h.frame(terminal)?.size == own)
    #expect(h.system.isVisible(terminal))
  }

  @Test func inUseOnTheDesktopAtASizeArborGaveItItTakesItsOwnSizeAroundWhereItIs() {
    // The product owner, 12:03 UTC: its own size, "within the display, around where it is". (The review had its whole frame.)
    let own = CGSize(width: 900, height: 600)
    let (h, _, _, terminal) = makeHarness(terminal: own)
    h.run("show-all")
    settle(h)
    h.system.userFocus(terminal)
    let squeezed = h.frame(terminal)!
    #expect(squeezed.width < 500)

    h.run("summon Terminal")
    #expect(h.frame(terminal)?.size == own)
    #expect(abs(h.frame(terminal)!.midX - squeezed.midX) <= 1 && h.frame(terminal)!.minY == squeezed.minY)
    #expect(h.workspace.floating[terminal] == h.frame(terminal))
  }

  @Test func stretchedOverTheDesktopItIsSummonedAtItsOwnSize() {
    var settings = Settings.makingWay
    settings.soleFloatTakesDesktop = true
    let own = CGSize(width: 400, height: 300)
    let (h, editor, _, terminal) = makeHarness(company: false, settings: settings)
    h.run("show-all")
    settle(h)
    #expect(h.frame(terminal)!.height > 800, "the premise: alone on the Desktop, it takes all of it")
    h.run("zoom \(editor.rawValue)")
    settle(h)

    h.run("summon Terminal")
    #expect(h.frame(terminal)?.size == own)
    h.run("summon Terminal")
    h.run("float-all")
    settle(h)
    #expect(h.frame(terminal)?.size == own)
  }
}
