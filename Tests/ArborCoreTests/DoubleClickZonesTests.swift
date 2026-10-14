import ArborCore
import CoreGraphics
import Foundation
import Testing

// F14 (double-click actions): the pure parts.

private typealias Zones = DoubleClickZones
private let mainDisplay = DisplayID("main")
private let sideDisplay = DisplayID("side")
private let a = WindowID(101)
private let b = WindowID(102)

/// A 1440×900 display showing [a | Desktop | b] with 12-point gaps and 28-point title bars.
private func overview(
  framed: Zones.Framed = .group, unframe: Command? = nil, tiles: [CGRect] = [], floating: [CGRect] = []
) -> Zones.Display {
  Zones.Display(
    id: mainDisplay, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    titleBars: [
      Zones.TitleBar(window: a, windowFrame: CGRect(x: 12, y: 37, width: 464, height: 851), height: 28),
      Zones.TitleBar(window: b, windowFrame: CGRect(x: 964, y: 37, width: 464, height: 851), height: 28),
    ],
    desktop: CGRect(x: 488, y: 37, width: 464, height: 851), tiles: tiles, floating: floating, framed: framed,
    unframe: unframe)
}

/// The same display with one thing filling the view.
private func zoomed(onto framed: Zones.Framed, unframe: Command?) -> Zones.Display {
  let content = CGRect(x: 12, y: 37, width: 1416, height: 851)
  var display = Zones.Display(
    id: mainDisplay, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), framed: framed, unframe: unframe)
  if case .window(let window) = framed {
    display.titleBars = [Zones.TitleBar(window: window, windowFrame: content, height: 28)]
  } else {
    display.desktop = content
  }
  return display
}

private let onTitleBarOfA = CGPoint(x: 200, y: 50)
private let onTitleBarOfB = CGPoint(x: 1200, y: 50)
private let onDesktop = CGPoint(x: 700, y: 400)

@Suite struct DoubleClickZonesTests {
  @Test func aDockedWindowsTitleBarFramesThatWindow() {
    let zones = Zones(displays: [overview()])
    #expect(zones.action(at: onTitleBarOfA) == .zoom(a))
    #expect(zones.action(at: onTitleBarOfB) == .zoom(b))
    #expect(zones.hit(at: onTitleBarOfA) == Zones.Hit(target: .titleBar(a), command: .zoom(a)))
    // The way out makes no difference until the window is framed.
    #expect(Zones(displays: [overview(unframe: .back)]).action(at: onTitleBarOfA) == .zoom(a))
  }

  @Test func theFramedWindowsTitleBarUnframesIt() {
    // Which of the two it is, the controller decides, by the rule ⌃⌥↩ pressed again follows.
    for way in [Command.back, .stepOut] {
      let zones = Zones(displays: [zoomed(onto: .window(a), unframe: way)])
      #expect(zones.hit(at: onTitleBarOfA) == Zones.Hit(target: .titleBar(a), command: way))
    }
  }

  @Test func onlyTheFramedWindowItselfUnframes() {
    // Another window is framed as far as the camera knows, yet this title bar is in view.
    let display = overview(framed: .window(b), unframe: .back)
    #expect(Zones(displays: [display]).action(at: onTitleBarOfA) == .zoom(a))
    #expect(Zones(displays: [display]).action(at: onTitleBarOfB) == .back)
  }

  @Test func bareDesktopMovesTheCameraToTheDesktop() {
    let zones = Zones(displays: [overview()])
    #expect(zones.hit(at: onDesktop) == Zones.Hit(target: .desktop(mainDisplay), command: .desktop))
  }

  @Test func theFramedDesktopUnframesToo() {
    #expect(Zones(displays: [zoomed(onto: .desktop, unframe: .back)]).action(at: onDesktop) == .back)
    #expect(Zones(displays: [zoomed(onto: .desktop, unframe: .stepOut)]).action(at: onDesktop) == .stepOut)
  }

  @Test func withNothingWiderTheDesktopIsLeftAlone() {
    // Nothing is docked, so the Desktop is all there is. Arbor has no business with double-clicks on
    // a Mac it is not arranging.
    #expect(Zones(displays: [zoomed(onto: .desktop, unframe: nil)]).hit(at: onDesktop) == nil)
  }

  /// Left to macOS, it would zoom or minimize a docked window, and Arbor would have to put it back.
  @Test func withNothingWiderAFramedWindowsTitleBarIsStillArborsAndDoesNothing() {
    let hit = Zones(displays: [zoomed(onto: .window(a), unframe: nil)]).hit(at: onTitleBarOfA)
    #expect(hit == Zones.Hit(target: .titleBar(a), command: nil))
    #expect(hit?.hidesClickFromApps == true)
    #expect(hit?.dependsOnWhatIsThere == true, "a button in the title bar still gets its clicks")
  }

  @Test func windowContentAndGapsAreNotArbors() {
    let zones = Zones(displays: [overview()])
    #expect(zones.action(at: CGPoint(x: 200, y: 400)) == nil, "inside a's content")
    #expect(zones.action(at: CGPoint(x: 482, y: 400)) == nil, "the gap between a and the Desktop")
    #expect(zones.action(at: CGPoint(x: 482, y: 50)) == nil, "the gap beside a title bar")
    #expect(zones.action(at: CGPoint(x: 5, y: 400)) == nil, "the margin at the screen edge")
    #expect(zones.action(at: CGPoint(x: 700, y: 10)) == nil, "the menu bar")
    #expect(zones.action(at: CGPoint(x: 700, y: 895)) == nil, "the margin at the bottom")
  }

  @Test func theTitleBarIsTheTopOfTheWindowAndNoMore() {
    let zones = Zones(displays: [overview()])
    #expect(zones.action(at: CGPoint(x: 12, y: 37)) == .zoom(a), "its top-left corner")
    #expect(zones.action(at: CGPoint(x: 475.5, y: 64.5)) == .zoom(a), "just inside its bottom-right corner")
    #expect(zones.action(at: CGPoint(x: 200, y: 65)) == nil, "the first point below it")
    #expect(zones.action(at: CGPoint(x: 200, y: 36.5)) == nil, "just above the window")
    #expect(zones.action(at: CGPoint(x: 476, y: 50)) == nil, "just right of the window")
    #expect(zones.action(at: CGPoint(x: 11.5, y: 50)) == nil, "just left of the window")
  }

  @Test func aTitleBarIsNeverTallerThanItsWindow() {
    let window = CGRect(x: 100, y: 100, width: 300, height: 20)
    #expect(Zones.TitleBar(window: a, windowFrame: window, height: 28).frame == window)
    #expect(Zones.TitleBar(window: a, windowFrame: window, height: 12).frame == CGRect(x: 100, y: 100, width: 300, height: 12))
    #expect(Zones.TitleBar(window: a, windowFrame: window, height: -5).frame.height == 0)
    let none = Zones.Display(
      id: mainDisplay, frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
      titleBars: [Zones.TitleBar(window: a, windowFrame: window, height: 0)])
    #expect(Zones(displays: [none]).action(at: CGPoint(x: 100, y: 100)) == nil)
  }

  @Test func tilesTakeTheirOwnClicks() {
    // A tile where the Desktop would be, and (which no layout produces) one over a title bar.
    let tile = CGRect(x: 488, y: 37, width: 100, height: 851)
    let zones = Zones(displays: [overview(tiles: [tile, CGRect(x: 12, y: 37, width: 50, height: 50)])])
    #expect(zones.action(at: CGPoint(x: 500, y: 400)) == nil)
    #expect(zones.action(at: CGPoint(x: 30, y: 50)) == nil)
    #expect(zones.action(at: onDesktop) == .desktop, "beside the tile")
  }

  @Test func floatingWindowsCoverWhatIsUnderThem() {
    // Over part of the Desktop and part of a's title bar.
    let floating = CGRect(x: 400, y: 30, width: 200, height: 200)
    let zones = Zones(displays: [overview(floating: [floating])])
    #expect(zones.action(at: CGPoint(x: 550, y: 100)) == nil, "its content, over the Desktop")
    #expect(zones.action(at: CGPoint(x: 550, y: 40)) == nil, "its own title bar keeps macOS's behaviour")
    #expect(zones.action(at: CGPoint(x: 450, y: 50)) == nil, "over a's title bar")
    #expect(zones.action(at: onTitleBarOfA) == .zoom(a), "the part of the title bar it leaves free")
    #expect(zones.action(at: onDesktop) == .desktop)
  }

  @Test func theEventTapLooksThroughFloatingFramesBecauseItAsksTheWindowServer() {
    let zones = Zones(displays: [overview(floating: [CGRect(x: 400, y: 30, width: 200, height: 200)])])
    #expect(zones.hit(at: CGPoint(x: 550, y: 100), floatingWindowsCover: false)?.command == .desktop)
    #expect(zones.hit(at: CGPoint(x: 450, y: 50), floatingWindowsCover: false)?.command == .zoom(a))
    #expect(zones.hit(at: CGPoint(x: 200, y: 400), floatingWindowsCover: false) == nil, "content is still content")
  }

  @Test func everyDisplayAnswersForItself() {
    var second = Zones.Display(
      id: sideDisplay, frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      desktop: CGRect(x: 1452, y: 12, width: 1256, height: 776), framed: .desktop, unframe: .back)
    let zones = Zones(displays: [overview(), second])
    #expect(zones.hit(at: onDesktop) == Zones.Hit(target: .desktop(mainDisplay), command: .desktop))
    #expect(zones.hit(at: CGPoint(x: 2000, y: 400)) == Zones.Hit(target: .desktop(sideDisplay), command: .back))

    // A floating window of the second display that hangs over onto the first covers it there too.
    second.floating = [CGRect(x: 1300, y: 20, width: 400, height: 300)]
    #expect(Zones(displays: [overview(), second]).action(at: CGPoint(x: 1350, y: 50)) == nil)
    #expect(Zones(displays: [overview(), second]).action(at: onTitleBarOfB) == .zoom(b))
  }

  @Test func nothingHappensOffEveryDisplayOrWithoutZones() {
    #expect(Zones(displays: [overview()]).action(at: CGPoint(x: -50, y: 2000)) == nil)
    #expect(Zones().action(at: onDesktop) == nil)
    #expect(Zones(displays: [overview()]).action(at: CGPoint(x: CGFloat.nan, y: 50)) == nil)
    #expect(Zones(displays: [overview()]).action(at: CGPoint(x: CGFloat.infinity, y: 50)) == nil)
  }

  @Test func desktopClicksAloneStillReachTheApps() {
    #expect(Zones.Hit(target: .titleBar(a), command: .zoom(a)).hidesClickFromApps)
    #expect(Zones.Hit(target: .titleBar(a), command: .back).hidesClickFromApps)
    #expect(Zones.Hit(target: .openedTile, command: nil).hidesClickFromApps)
    #expect(!Zones.Hit(target: .desktop(mainDisplay), command: .desktop).hidesClickFromApps)
  }

  // MARK: A tile that opened on the first click

  /// a was a tile at the top left; one click at time 100 opened it, and it fills the view.
  private var justOpened: Zones {
    Zones(
      displays: [zoomed(onto: .window(a), unframe: .back)],
      openedTile: Zones.OpenedTile(frame: CGRect(x: 12, y: 37, width: 200, height: 150), time: 100))
  }

  @Test func theSecondClickOnATileThatJustOpenedIsNobodys() {
    let echo = Zones.Hit(target: .openedTile, command: nil)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.2) == echo, "over the window's content")
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.2, floatingWindowsCover: false) == echo)
    #expect(justOpened.action(at: CGPoint(x: 100, y: 120)) == nil, "there is nothing to run")
  }

  @Test func itIsNotTakenForADoubleClickOnTheTitleBarThatCameUnderIt() {
    // That would go straight back: the double-click would open the tile and close it again.
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 50), time: 100.2) == Zones.Hit(target: .openedTile, command: nil))
    #expect(justOpened.hit(at: CGPoint(x: 400, y: 50), time: 100.2)?.command == .back, "beside where the tile was")
  }

  @Test func onceTheDoubleClickTimeIsOverTheSpotIsOrdinaryAgain() {
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.49)?.target == .openedTile)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.5) == nil)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 50), time: 100.5)?.command == .back)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 5000) == nil)
    // The user's own double-click time counts.
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.9, interval: 1)?.target == .openedTile)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.3, interval: 0.25) == nil)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 100.0, interval: 0) == nil)
  }

  @Test func aClockSetBackDoesNotKeepTheSpotDeadForHours() {
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: 99.9)?.target == .openedTile, "a hair's breadth")
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: -3500) == nil)
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120), time: .nan) == nil)
  }

  @Test func withoutTheTimeOrOutsideTheTileNothingIsSwallowed() {
    #expect(justOpened.hit(at: CGPoint(x: 100, y: 120)) == nil)
    #expect(justOpened.hit(at: CGPoint(x: 300, y: 120), time: 100.2) == nil)
    #expect(Zones(displays: [overview()]).hit(at: CGPoint(x: 200, y: 400), time: 100.2) == nil)
  }
}

@Suite struct PointerCoverTests {
  let arbor: Int32 = 1
  let safari: Int32 = 500
  let finder: Int32 = 300
  let wallpaper: Int32 = 200
  let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
  let point = CGPoint(x: 200, y: 50)

  /// What is always at the back: Finder's icons over the wallpaper.
  var desktopElements: [ListedWindow] {
    [
      ListedWindow(id: WindowID(11), pid: finder, layer: -2_147_483_603, frame: screen),
      ListedWindow(id: WindowID(10), pid: wallpaper, layer: -2_147_483_624, frame: screen),
    ]
  }

  func cover(_ windows: [ListedWindow], ownClickable: Set<WindowID> = []) -> PointerCover {
    PointerCover.at(
      point, windows: windows + desktopElements, ownPID: arbor, ownClickable: ownClickable, displays: [screen])
  }

  @Test func theFrontmostOrdinaryWindowUnderThePointerCounts() {
    let front = ListedWindow(id: b, pid: 600, layer: 0, frame: CGRect(x: 100, y: 20, width: 300, height: 300))
    let behind = ListedWindow(id: a, pid: safari, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 851))
    #expect(cover([front, behind]) == .window(b, pid: 600))
    #expect(cover([behind, front]) == .window(a, pid: safari))
    #expect(cover([behind]).owner == safari)
  }

  @Test func windowsElsewhereAndInvisibleOnesAreSkipped() {
    let elsewhere = ListedWindow(id: b, pid: 600, layer: 0, frame: CGRect(x: 600, y: 20, width: 300, height: 300))
    let invisible = ListedWindow(id: WindowID(7), pid: 700, layer: 0, frame: screen, alpha: 0)
    let docked = ListedWindow(id: a, pid: safari, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 851))
    #expect(cover([elsewhere, invisible, docked]) == .window(a, pid: safari))
  }

  @Test func withNoWindowItIsTheDesktopAndWhoeverDrawsIt() {
    #expect(cover([]) == .desktop(pid: finder))
    #expect(cover([]).owner == finder)
    // Finder shows no icons, or is not running.
    #expect(
      PointerCover.at(point, windows: [desktopElements[1]], ownPID: arbor, displays: [screen]) == .desktop(pid: wallpaper))
    #expect(PointerCover.at(point, windows: [], ownPID: arbor) == .desktop(pid: nil))
    #expect(PointerCover.at(point, windows: [], ownPID: arbor).owner == nil)
  }

  /// What belongs to the Desktop itself is as large as the display. Anything smaller down there is somebody's.
  @Test func aWidgetOnTheDesktopKeepsItsClicks() {
    let widget = ListedWindow(id: WindowID(12), pid: 350, layer: -2_147_483_610, frame: CGRect(x: 100, y: 20, width: 340, height: 160))
    #expect(cover([widget]) == .somethingElse)
    #expect(!Zones.Hit(target: .desktop(mainDisplay), command: .desktop).lands(on: cover([widget])))
  }

  @Test func arborsOwnWindowsAreLookedThroughUnlessTheyTakeClicks() {
    let docked = ListedWindow(id: a, pid: safari, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 851))
    let panel = ListedWindow(id: WindowID(900), pid: arbor, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 30))
    let preview = ListedWindow(id: WindowID(901), pid: arbor, layer: 3, frame: CGRect(x: 0, y: 0, width: 700, height: 900))
    let backdrop = ListedWindow(id: WindowID(902), pid: arbor, layer: -1, frame: screen)
    #expect(cover([preview, panel, docked]) == .window(a, pid: safari))
    #expect(cover([preview, panel, docked], ownClickable: [WindowID(900)]) == .somethingElse)
    #expect(cover([backdrop]) == .desktop(pid: finder))
    #expect(cover([panel], ownClickable: [WindowID(900)]).owner == nil)
  }

  @Test func whateverFloatsAboveOrdinaryWindowsKeepsItsClicks() {
    let docked = ListedWindow(id: a, pid: safari, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 851))
    let video = ListedWindow(id: WindowID(40), pid: 800, layer: 3, frame: CGRect(x: 100, y: 30, width: 320, height: 180))
    let menu = ListedWindow(id: WindowID(41), pid: safari, layer: 101, frame: CGRect(x: 150, y: 24, width: 200, height: 400))
    #expect(cover([video, docked]) == .somethingElse)
    #expect(cover([menu, docked]) == .somethingElse)
    #expect(cover([video]) == .somethingElse, "over the Desktop as well")
    let justAbove = ListedWindow(id: WindowID(42), pid: 800, layer: 1, frame: CGRect(x: 100, y: 30, width: 320, height: 180))
    #expect(cover([justAbove, docked]) == .somethingElse, "any level above the ordinary windows")
  }

  @Test func onlyTheDocksLayerOverTheWholeDisplayIsLookedThrough() {
    // The Dock's window spans the display although the Dock does not.
    let docked = ListedWindow(id: a, pid: safari, layer: 0, frame: CGRect(x: 12, y: 37, width: 464, height: 851))
    let dock = ListedWindow(id: WindowID(20), pid: 250, layer: 20, frame: screen)
    #expect(cover([dock, docked]) == .window(a, pid: safari))
    #expect(cover([dock]) == .desktop(pid: finder))
    // Mission Control, the crosshair of a screenshot, a tool to draw on the screen with: nobody has measured them, and some
    // take clicks. A click is about to be kept from everybody, so what is not known to be harmless keeps it.
    let unknown = ListedWindow(id: WindowID(21), pid: 260, layer: 1000, frame: screen.insetBy(dx: -10, dy: -10))
    #expect(cover([unknown, dock, docked]) == .somethingElse)
    #expect(cover([unknown, dock]) == .somethingElse)
    #expect(cover([ListedWindow(id: WindowID(22), pid: 250, layer: 20, frame: CGRect(x: 100, y: 20, width: 400, height: 80)), docked]) == .somethingElse, "the Dock itself")
    // Without the displays' frames nothing can be told apart, so everything above blocks.
    #expect(PointerCover.at(point, windows: [dock, docked], ownPID: arbor) == .somethingElse)
    // An ordinary window is never looked through, however large.
    #expect(cover([ListedWindow(id: b, pid: 600, layer: 0, frame: screen), docked]) == .window(b, pid: 600))
  }

  @Test func aTitleBarClickMustLandOnThatVeryWindow() {
    let hit = Zones.Hit(target: .titleBar(a), command: .zoom(a))
    #expect(hit.lands(on: .window(a, pid: safari)))
    #expect(!hit.lands(on: .window(b, pid: safari)), "a window Arbor does not arrange, or a floating one, is in front")
    #expect(!hit.lands(on: .desktop(pid: finder)), "the window is not where Arbor thinks")
    #expect(!hit.lands(on: .somethingElse))
  }

  @Test func whateverLiesWhereATileWasTheClickWasNotMeantForIt() {
    let hit = Zones.Hit(target: .openedTile, command: nil)
    #expect(!hit.dependsOnWhatIsThere)
    for cover in [PointerCover.window(a, pid: safari), .desktop(pid: finder), .desktop(pid: nil), .somethingElse] {
      #expect(hit.lands(on: cover), "\(cover)")
    }
    #expect(hit.isBackground(roles: ["AXButton", "AXWindow"], windowHasButtons: false))
    #expect(Zones.Hit(target: .titleBar(a), command: .zoom(a)).dependsOnWhatIsThere)
    #expect(Zones.Hit(target: .desktop(mainDisplay), command: .desktop).dependsOnWhatIsThere)
  }

  @Test func aDesktopClickMustLandOnNoWindowAtAll() {
    let hit = Zones.Hit(target: .desktop(mainDisplay), command: .desktop)
    #expect(hit.lands(on: .desktop(pid: finder)))
    #expect(hit.lands(on: .desktop(pid: nil)))
    #expect(!hit.lands(on: .window(a, pid: safari)))
    #expect(!hit.lands(on: .somethingElse))
  }
}

@Suite struct DoubleClickRoleTests {
  private let titleBar = Zones.Hit(target: .titleBar(a), command: .zoom(a))
  private let desktop = Zones.Hit(target: .desktop(mainDisplay), command: .desktop)

  /// In an ordinary window, one with its three buttons.
  private func isTitleBarScenery(_ roles: [String]) -> Bool {
    titleBar.isBackground(roles: roles, windowHasButtons: true)
  }

  /// What stock apps have in the empty parts of the top of their windows on macOS 26, by a survey with
  /// `scripts/mac-shell/ax-roles.swift`, which `scripts/mac-shell/check-F14.sh` repeats at its end.
  @Test func theSceneryOfATitleBarIsArbors() {
    for roles in [
      ["AXWindow"], ["AXStaticText", "AXWindow"], ["AXToolbar", "AXWindow"], ["AXGroup", "AXToolbar", "AXWindow"],
      ["AXGroup", "AXSplitGroup", "AXGroup", "AXWindow"], ["AXSplitGroup", "AXGroup", "AXWindow"],
    ] {
      #expect(isTitleBarScenery(roles), "\(roles)")
    }
    for roles in [["AXStaticText", "AXToolbar", "AXWindow"], ["AXWindow", "AXApplication"]] {
      #expect(isTitleBarScenery(roles), "\(roles)")
    }
  }

  /// Apps that draw their own title bar beside real traffic lights (Electron: VS Code, Slack, Notion) put buttons there
  /// that Accessibility may know only as a group, or not at all. No stock app has a bare group in its title bar; the
  /// one place one was seen (TextEdit, 40 points down) is content.
  @Test func aGroupIsSceneryOnlyInAToolbarOrASplitGroup() {
    #expect(!isTitleBarScenery(["AXGroup", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXGroup", "AXGroup", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXGroup", "AXGroup", "AXGroup", "AXGroup"]), "deeper than Arbor looks")
    #expect(!isTitleBarScenery(["AXUnknown", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXUnknown"]))
    #expect(isTitleBarScenery(["AXGroup", "AXGroup", "AXToolbar", "AXWindow"]))
    #expect(isTitleBarScenery(["AXGroup", "AXSplitGroup", "AXWindow"]))
  }

  @Test func anAppThatDoesNotAnswerKeepsTheClick() {
    // The first click lands on a browser's sidebar button, the browser is busy sliding the sidebar out when the
    // second arrives, and asked what is under the pointer it answers with an error.
    #expect(!isTitleBarScenery([]))
    #expect(!titleBar.isBackground(roles: []))
    #expect(!titleBar.isBackground(roles: ["AXWindow"], windowHasButtons: nil), "it fell silent half way")
  }

  @Test func nobodyNeedsToAnswerForTheDesktop() {
    // With Finder's icons switched off, whoever draws the wallpaper has nothing to say about it.
    #expect(desktop.isBackground(roles: []))
  }

  @Test func controlsInATitleBarKeepTheirDoubleClicks() {
    for role in [
      "AXButton", "AXTextField", "AXTextArea", "AXTabGroup", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
      "AXComboBox", "AXSlider", "AXCheckBox", "AXImage", "AXLink", "AXMenuItem", "AXMenuBarItem", "AXSearchField",
      "AXScrollArea", "AXWebArea", "AXCell", "AXColorWell", "AXSheet", "AXSomethingNobodyHasHeardOf", "",
    ] {
      #expect(!isTitleBarScenery([role, "AXToolbar", "AXWindow"]), "\(role)")
      #expect(!isTitleBarScenery([role, "AXWindow"]), "\(role)")
    }
  }

  @Test func aWindowWithoutButtonsHasNoTitleBar() {
    // A terminal with its title bar hidden: the top of the window is its first line of text, and
    // one that draws for itself calls that nothing more than a window.
    #expect(!titleBar.isBackground(roles: ["AXWindow"], windowHasButtons: false))
    #expect(!titleBar.isBackground(roles: ["AXUnknown", "AXWindow"], windowHasButtons: false))
    #expect(titleBar.isBackground(roles: ["AXWindow"], windowHasButtons: true))
    #expect(!titleBar.isBackground(roles: ["AXButton", "AXWindow"], windowHasButtons: true), "one of the buttons")
    #expect(desktop.isBackground(roles: ["AXScrollArea"], windowHasButtons: false), "the Desktop has none to have")
  }

  @Test func onlyTextRightUnderTheWindowIsItsTitle() {
    // Safari's address, while the field is not being edited.
    #expect(!isTitleBarScenery(["AXStaticText", "AXGroup", "AXToolbar", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXStaticText", "AXGroup", "AXGroup", "AXGroup"]), "text in a web page")
    #expect(!isTitleBarScenery(["AXStaticText"]))
    #expect(isTitleBarScenery(["AXStaticText", "AXWindow"]))
  }

  @Test func sceneryInsideAControlBelongsToTheControl() {
    #expect(!isTitleBarScenery(["AXStaticText", "AXButton", "AXToolbar", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXImage", "AXButton", "AXToolbar", "AXWindow"]))
    #expect(!isTitleBarScenery(["AXStaticText", "AXRadioButton", "AXTabGroup", "AXWindow"]), "a browser tab")
    #expect(!isTitleBarScenery(["AXGroup", "AXGroup", "AXTextField", "AXToolbar"]))
    #expect(!isTitleBarScenery(["AXGroup", "AXRadioButton", "AXRadioGroup", "AXGroup"]))
  }

  /// Every question holds the click back a little longer, and the click that is not Arbor's should wait least.
  @Test func aControlIsKnownForOneAtTheFirstAnswer() {
    for role in ["AXButton", "AXTextField", "AXRadioButton", "AXTabGroup", "AXImage", "AXUnknown", ""] {
      #expect(!titleBar.canStillBeBackground(rolesSoFar: [role]), "\(role)")
    }
    #expect(!titleBar.canStillBeBackground(rolesSoFar: ["AXStaticText", "AXGroup"]), "Safari's address")
    #expect(!titleBar.canStillBeBackground(rolesSoFar: ["AXGroup", "AXButton"]))
    #expect(!desktop.canStillBeBackground(rolesSoFar: ["AXImage"]), "an icon")
    for roles in [[], ["AXWindow"], ["AXStaticText"], ["AXStaticText", "AXWindow"], ["AXGroup"], ["AXGroup", "AXToolbar"]] {
      #expect(titleBar.canStillBeBackground(rolesSoFar: roles), "\(roles)")
    }
    #expect(desktop.canStillBeBackground(rolesSoFar: ["AXGroup", "AXScrollArea"]))
  }

  /// Giving up early never changes the answer: where it is not worth asking on, every way the roles could go on is a no.
  @Test func givingUpEarlyIsAlwaysANo() {
    let all = ["AXWindow", "AXToolbar", "AXGroup", "AXStaticText", "AXSplitGroup", "AXApplication", "AXButton", "AXImage", "AXTextField"]
    for first in all {
      for second in all {
        for hit in [titleBar, desktop] {
          for soFar in [[first], [first, second]] where !hit.canStillBeBackground(rolesSoFar: soFar) {
            for third in all {
              for fourth in all {
                #expect(!hit.isBackground(roles: soFar + [third, fourth], windowHasButtons: true), "\(soFar + [third, fourth])")
              }
            }
            #expect(!hit.isBackground(roles: soFar, windowHasButtons: true), "\(soFar)")
          }
        }
      }
    }
  }

  @Test func iconsAndWidgetsOnTheDesktopKeepTheirDoubleClicks() {
    #expect(!desktop.isBackground(roles: ["AXImage", "AXGroup", "AXScrollArea", "AXApplication"]), "an icon, as seen")
    #expect(!desktop.isBackground(roles: ["AXTextField", "AXImage", "AXGroup", "AXScrollArea"]), "a name being edited")
    #expect(!desktop.isBackground(roles: ["AXStaticText", "AXButton", "AXGroup"]), "a widget")
  }

  @Test func anythingElseOnTheDesktopIsWallpaper() {
    #expect(desktop.isBackground(roles: ["AXGroup", "AXScrollArea", "AXApplication"]), "bare Desktop, as seen")
    for roles in [["AXScrollArea"], ["AXUnknown"], ["AXList"], ["AXWindow"]] {
      #expect(desktop.isBackground(roles: roles), "\(roles)")
    }
  }
}

@Suite struct DoubleClickGestureTests {
  private let titleBar = Zones.Hit(target: .titleBar(a), command: .zoom(a))
  private let desktop = Zones.Hit(target: .desktop(mainDisplay), command: .desktop)
  private let spot = CGPoint(x: 300, y: 20)

  /// A mouse-down at `spot` with no modifier keys held.
  private func press(
    _ gesture: inout DoubleClickGesture, clicks: Int = 2, hit: Zones.Hit?, confirm: (Zones.Hit) -> Bool = { _ in true }
  ) -> DoubleClickGesture.Response {
    gesture.mouseDown(at: spot, clicks: clicks, modifiersHeld: false, hit: hit, confirm: confirm)
  }

  private func away(_ points: CGFloat) -> CGPoint { CGPoint(x: spot.x + points, y: spot.y) }

  @Test func aTitleBarDoubleClickIsHiddenDownAndUpAndRunsWhenTheButtonComesUp() {
    var gesture = DoubleClickGesture()
    // The first click goes to the app, which focuses the window.
    #expect(press(&gesture, clicks: 1, hit: titleBar) == .pass)
    #expect(gesture.mouseUp() == .pass)
    #expect(press(&gesture, hit: titleBar) == .hold, "nothing runs yet: it may be the start of a drag")
    #expect(gesture.isFollowing)
    #expect(gesture.mouseUp() == .run(.zoom(a), swallow: true))
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseUp() == .pass, "only the one mouse-up")
  }

  /// Click a title bar and start dragging it within the double-click time, or drag with a double tap on a trackpad
  /// set up for that: the press counts as a second click, and it is how a docked window is docked elsewhere.
  @Test func aSecondPressThatTurnsIntoADragIsGivenBackWhole() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: titleBar) == .hold)
    #expect(gesture.mouseDragged(to: away(5)) == .replay, "the app gets the mouse-down it missed, then this")
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseDragged(to: away(9)) == .pass)
    #expect(gesture.mouseUp() == .pass, "the app saw the mouse-down, so the mouse-up is its own, and nothing runs")
  }

  @Test func aHandThatTremblesStillDoubleClicks() {
    var gesture = DoubleClickGesture()
    #expect(gesture.mouseDragged(to: spot) == .pass, "an ordinary drag")
    _ = press(&gesture, hit: titleBar)
    // An app that has not seen the button go down has no use for a drag.
    #expect(gesture.mouseDragged(to: away(2)) == .swallow)
    #expect(gesture.mouseDragged(to: CGPoint(x: spot.x - 3, y: spot.y + DoubleClickGesture.slack)) == .swallow)
    #expect(gesture.mouseUp() == .run(.zoom(a), swallow: true))
    #expect(gesture.mouseDragged(to: away(2)) == .pass)
  }

  @Test func aDragCountsInEveryDirection() {
    let beyond = DoubleClickGesture.slack + 1
    for point in [
      CGPoint(x: spot.x + beyond, y: spot.y), CGPoint(x: spot.x - beyond, y: spot.y),
      CGPoint(x: spot.x, y: spot.y + beyond), CGPoint(x: spot.x, y: spot.y - beyond),
    ] {
      var gesture = DoubleClickGesture()
      _ = press(&gesture, hit: titleBar)
      #expect(gesture.mouseDragged(to: point) == .replay, "\(point)")
    }
  }

  @Test func theSecondClickOnAnOpenedTileDisappearsWithoutAsking() {
    var gesture = DoubleClickGesture()
    let echo = Zones.Hit(target: .openedTile, command: nil)
    #expect(press(&gesture, hit: echo, confirm: { _ in false }) == .hold)
    #expect(gesture.isFollowing)
    #expect(gesture.mouseDragged(to: away(1)) == .swallow)
    #expect(gesture.mouseUp() == .swallow)
    #expect(gesture.mouseUp() == .pass)
  }

  /// The title bar of a framed window with nothing wider to go to: nothing runs, macOS's own action least of all.
  @Test func aTitleBarDoubleClickWithNothingToDoDisappears() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: Zones.Hit(target: .titleBar(a), command: nil)) == .hold)
    #expect(gesture.mouseUp() == .swallow)
  }

  @Test func aDesktopDoubleClickRunsAndStillReachesFinder() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: desktop) == .watch)
    #expect(gesture.isFollowing)
    #expect(gesture.mouseDragged(to: away(1)) == .pass)
    #expect(gesture.mouseUp() == .run(.desktop, swallow: false))
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseUp() == .pass)
  }

  /// Click the Desktop to drop a selection and at once draw a new one.
  @Test func aSecondPressOnTheDesktopThatTurnsIntoADragRunsNothing() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: desktop) == .watch)
    #expect(gesture.mouseDragged(to: away(30)) == .pass, "Finder saw the mouse-down: there is nothing to give back")
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseUp() == .pass)
  }

  @Test func everySecondClickInARowIsADoubleClick() {
    // Double-click, and at once double-click again: macOS counts 1, 2, 3, 4.
    var gesture = DoubleClickGesture()
    var responses: [DoubleClickGesture.Response] = []
    for clicks in 1...6 {
      responses.append(press(&gesture, clicks: clicks, hit: titleBar))
      responses.append(gesture.mouseUp())
    }
    let click: [DoubleClickGesture.Response] = [.pass, .pass]
    let doubleClick: [DoubleClickGesture.Response] = [.hold, .run(.zoom(a), swallow: true)]
    #expect(responses == click + doubleClick + click + doubleClick + click + doubleClick)
    for clicks in [0, -1, -2, Int.min, Int.max] {
      #expect(press(&gesture, clicks: clicks, hit: titleBar) == .pass, "\(clicks)")
    }
  }

  @Test func withNobodyToAskTheZonesWordCounts() {
    var gesture = DoubleClickGesture()
    #expect(gesture.mouseDown(at: spot, clicks: 2, modifiersHeld: false, hit: titleBar) == .hold)
  }

  @Test func modifiedDoubleClicksStayWithTheApps() {
    var gesture = DoubleClickGesture()
    #expect(gesture.mouseDown(at: spot, clicks: 2, modifiersHeld: true, hit: titleBar) == .pass)
    #expect(gesture.mouseUp() == .pass)
  }

  @Test func outsideTheZonesEverythingPasses() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: nil) == .pass)
    #expect(gesture.mouseUp() == .pass)
  }

  @Test func aDoubleClickTheChecksRefusePassesWhole() {
    var gesture = DoubleClickGesture()
    #expect(press(&gesture, hit: titleBar, confirm: { _ in false }) == .pass)
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseUp() == .pass)
  }

  @Test func theChecksRunOnlyForADoubleClickInsideAZone() {
    var gesture = DoubleClickGesture()
    var lookups = 0
    var checks: [Zones.Hit] = []
    func look(_ hit: Zones.Hit?) -> Zones.Hit? {
      lookups += 1
      return hit
    }
    let confirm: (Zones.Hit) -> Bool = {
      checks.append($0)
      return true
    }
    _ = gesture.mouseDown(at: spot, clicks: 1, modifiersHeld: false, hit: look(titleBar), confirm: confirm)
    _ = gesture.mouseDown(at: spot, clicks: 3, modifiersHeld: false, hit: look(titleBar), confirm: confirm)
    _ = gesture.mouseDown(at: spot, clicks: 2, modifiersHeld: true, hit: look(titleBar), confirm: confirm)
    #expect(lookups == 0, "ordinary clicks cost nothing")
    _ = gesture.mouseDown(at: spot, clicks: 2, modifiersHeld: false, hit: look(nil), confirm: confirm)
    #expect(lookups == 1)
    #expect(checks.isEmpty)
    _ = gesture.mouseDown(at: spot, clicks: 2, modifiersHeld: false, hit: look(titleBar), confirm: confirm)
    #expect(checks == [titleBar])
  }

  @Test func aMissedMouseUpDoesNotCostTheNextClickItsOwn() {
    var gesture = DoubleClickGesture()
    _ = press(&gesture, hit: titleBar)
    // The mouse-up never came (macOS switched the tap off for a moment). An app that got the next
    // mouse-down without its mouse-up would think the button was still held.
    #expect(press(&gesture, clicks: 1, hit: nil) == .pass)
    #expect(gesture.mouseUp() == .pass, "and the command of the click that was lost does not run now")
  }

  @Test func resetForgetsTheClickInProgress() {
    var gesture = DoubleClickGesture()
    _ = press(&gesture, hit: titleBar)
    gesture.reset()
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseDragged(to: away(9)) == .pass)
    #expect(gesture.mouseUp() == .pass)
  }

  /// macOS switches a tap off, a pause or a setting takes the taps away: whatever ends the watch, the app that is going
  /// to get the mouse-up gets the mouse-down first, and then the double-click is the app's alone.
  @Test func aPressHeldBackWhenTheWatchEndsIsGivenBackWhileTheButtonIsDown() {
    var gesture = DoubleClickGesture()
    _ = press(&gesture, hit: titleBar)
    #expect(gesture.reset(buttonIsDown: true) == .replay)
    #expect(!gesture.isFollowing)
    #expect(gesture.mouseUp() == .pass, "nothing of Arbor's runs as well")
    #expect(gesture.reset(buttonIsDown: true) == .pass, "once")
  }

  @Test func withTheButtonUpAPressHeldBackIsDropped() {
    // Its mouse-up was among the events that were missed. Given the press now, the app would think the button held.
    var gesture = DoubleClickGesture()
    _ = press(&gesture, hit: titleBar)
    #expect(gesture.reset(buttonIsDown: false) == .pass)
    #expect(!gesture.isFollowing)
  }

  @Test func whatWasNeverHeldBackIsNotGivenBack() {
    var gesture = DoubleClickGesture()
    #expect(gesture.reset(buttonIsDown: true) == .pass, "no press")
    _ = press(&gesture, hit: desktop)
    #expect(gesture.reset(buttonIsDown: true) == .pass, "Finder saw this one go down")
    #expect(gesture.mouseUp() == .pass)
  }

  /// Rule: one double-click, one answer. Every way through a press that may be Arbor's ends in exactly one of two: the
  /// app sees neither half of the second click and Arbor may run its command, or the app sees the press and Arbor
  /// runs nothing. macOS's own title-bar action needs the press, so it can never run beside Arbor's.
  @Test func neverBothArborAndTheApp() {
    enum Step: CaseIterable { case tremble, drag, up, resetDown, resetUp, nextPress }
    func walk(_ steps: [Step]) -> (appSawThePress: Bool, ran: Bool) {
      var gesture = DoubleClickGesture()
      var appSawThePress = !press(&gesture, hit: titleBar).swallows
      var ran = false
      for step in steps {
        let response: DoubleClickGesture.Response
        switch step {
        case .tremble: response = gesture.mouseDragged(to: away(2))
        case .drag: response = gesture.mouseDragged(to: away(40))
        case .up: response = gesture.mouseUp()
        case .resetDown: response = gesture.reset(buttonIsDown: true)
        case .resetUp: response = gesture.reset(buttonIsDown: false)
        case .nextPress: response = press(&gesture, clicks: 1, hit: nil)
        }
        if response == .replay { appSawThePress = true }
        if case .run = response { ran = true }
      }
      return (appSawThePress, ran)
    }
    for first in Step.allCases {
      for second in Step.allCases {
        for third in Step.allCases {
          let outcome = walk([first, second, third])
          #expect(!(outcome.appSawThePress && outcome.ran), "\([first, second, third])")
        }
      }
    }
    // The controls: a plain double-click runs, and a drag is the app's.
    #expect(walk([.up]).ran && !walk([.up]).appSawThePress)
    #expect(walk([.drag, .up]).appSawThePress && !walk([.drag, .up]).ran)
  }

  @Test func numbersNoHandCouldMakeAreNotADrag() {
    var gesture = DoubleClickGesture()
    _ = press(&gesture, hit: titleBar)
    #expect(gesture.mouseDragged(to: CGPoint(x: CGFloat.nan, y: CGFloat.nan)) == .swallow)
    #expect(gesture.mouseDragged(to: CGPoint(x: CGFloat.infinity, y: 0)) == .replay)
  }

  @Test func responsesSayWhetherTheEventIsHidden() {
    for response in [DoubleClickGesture.Response.pass, .watch, .replay, .run(.desktop, swallow: false)] {
      #expect(!response.swallows, "\(response)")
    }
    for response in [DoubleClickGesture.Response.hold, .swallow, .run(.back, swallow: true)] {
      #expect(response.swallows, "\(response)")
    }
  }
}

@Suite struct MacTitleBarActionSettingTests {
  @Test func theSettingIsReadAsSystemSettingsWritesIt() {
    #expect(MacTitleBarAction(setting: "Fill") == .fill)
    #expect(MacTitleBarAction(setting: "Maximize") == .zoom)
    #expect(MacTitleBarAction(setting: "Minimize") == .minimize)
    #expect(MacTitleBarAction(setting: "None") == .nothing)
  }

  @Test func notSetOrUnheardOfIsMacOSAsItComes() {
    for setting in [nil, "", "minimize", "Something a later macOS writes"] {
      #expect(MacTitleBarAction(setting: setting) == .fill, "\(setting ?? "nil")")
    }
  }

  @Test func onlyWhatMakesTheWindowBigIsReplaced() {
    #expect(MacTitleBarAction.allCases.filter(\.makesTheWindowBig) == [.fill, .zoom])
    for action in MacTitleBarAction.allCases {
      #expect((action.whyArborLeavesTitleBarsAlone == nil) == action.makesTheWindowBig, "\(action)")
    }
  }
}

@Suite struct DoubleClickSettingsTests {
  func decode(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  @Test func oldSettingsFilesGetTheDoubleClickDefaults() throws {
    let settings = try decode(#"{"gap": 20, "gesturesEnabled": false}"#)
    #expect(!settings.titleBarDoubleClick, "until its script has passed on a hosted Mac")
    #expect(!settings.desktopDoubleClick, "until the wallpaper click is guarded (F60)")
    #expect(settings.titleBarHeight == 28)
    #expect(settings.effectiveTitleBarHeight == 28)
    #expect(settings.valueProblems.isEmpty)
    #expect(!settings.wantsDoubleClickTap)
    #expect(settings.gap == 20)
  }

  @Test func doubleClickSettingsDecodeAndRoundTrip() throws {
    let settings = try decode(#"{"titleBarDoubleClick": true, "desktopDoubleClick": true, "titleBarHeight": 40}"#)
    #expect(settings.titleBarDoubleClick)
    #expect(settings.desktopDoubleClick)
    #expect(settings.effectiveTitleBarHeight == 40)
    #expect(settings.valueProblems.isEmpty)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }

  @Test func theTapIsWantedOnlyWhileSomethingNeedsIt() {
    var settings = Settings()
    #expect(!settings.wantsDoubleClickTap)
    settings.titleBarDoubleClick = true
    #expect(settings.wantsDoubleClickTap)
    settings.titleBarDoubleClick = false
    settings.desktopDoubleClick = true
    #expect(settings.wantsDoubleClickTap)
  }

  @Test func theTitleBarHeightStaysBetween10And80() throws {
    #expect(try decode(#"{"titleBarHeight": 0}"#).effectiveTitleBarHeight == 10)
    #expect(try decode(#"{"titleBarHeight": -40}"#).effectiveTitleBarHeight == 10)
    #expect(try decode(#"{"titleBarHeight": 5000}"#).effectiveTitleBarHeight == 80)
    #expect(try decode(#"{"titleBarHeight": 52.5}"#).effectiveTitleBarHeight == 52.5)
    #expect(try decode(#"{"titleBarHeight": 10}"#).valueProblems.isEmpty)
    #expect(try decode(#"{"titleBarHeight": 80}"#).valueProblems.isEmpty)
    // Reported (the schema's doing, F12), and the rest of the file applies.
    let settings = try decode(#"{"titleBarHeight": 5000, "gap": 20}"#)
    #expect(settings.valueProblems.count == 1)
    #expect(settings.valueProblems.first?.hasPrefix("titleBarHeight: ") == true)
    #expect(settings.titleBarHeight == 80)
    #expect(settings.gap == 20)
    // A value that did not come through the file.
    var odd = Settings()
    for bad in [Double.nan, .infinity, -.infinity] {
      odd.titleBarHeight = bad
      #expect(odd.effectiveTitleBarHeight == 28, "\(bad)")
    }
    odd.titleBarHeight = 5000
    #expect(odd.effectiveTitleBarHeight == 80)
    odd.titleBarHeight = 0
    #expect(odd.effectiveTitleBarHeight == 10)
  }
}
