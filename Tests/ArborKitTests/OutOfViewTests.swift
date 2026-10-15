import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

@MainActor private let main = FakeWindowSystem.standardDisplay
/// A taller display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false)

/// Windows Arbor has moved out of view must stay out of view while they are meant to be, and must
/// never be left there.
@Suite @MainActor struct OutOfViewTests {
  /// `[a | b]` with `f` floating in the middle, zoomed onto `a`: `b` and `f` are parked. (With a column for the Desktop
  /// `[a | Desktop | b]`.)
  func zoomedIn(displays: [DisplaySnapshot] = [main]) -> (Harness, a: WindowID, b: WindowID, f: WindowID) {
    let h = Harness(displays: displays)
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", pid: 13, frame: CGRect(x: 560, y: 300, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    return (h, a, b, f)
  }

  /// What may show of a parked window: one point across, and its title bar, which macOS keeps on screen and which is the window's own.
  func sliver(_ h: Harness, _ window: WindowID) -> CGFloat { h.system.windows[window]!.titleBar }

  /// How much of a window shows on any display.
  func visibleArea(_ h: Harness, _ window: WindowID) -> CGFloat {
    let frame = h.frame(window)!
    return h.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +)
  }

  @Test func parkedWindowsStayOutOfViewWhenADisplayIsPluggedInBesideThem() {
    let (h, _, b, f) = zoomedIn()
    h.system.setDisplays([main, side])
    #expect(visibleArea(h, b) <= sliver(h, b), "\(h.frame(b)!) shows on the new display")
    #expect(visibleArea(h, f) <= sliver(h, f), "\(h.frame(f)!) shows on the new display")
  }

  @Test func parkedWindowsDoNotShowOnANeighbourThatEndsJustAboveTheBottom() {
    // The neighbour ends 20 points above this display's bottom. A window parked at the very corner would clear it,
    // but macOS stops the window its title bar's height up, where it would show along the neighbour's bottom edge.
    let shorter = DisplaySnapshot(
      id: DisplayID("shorter"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 880),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 880), isMain: false)
    let (h, _, b, f) = zoomedIn(displays: [main, shorter])
    #expect(visibleArea(h, b) <= sliver(h, b), "\(h.frame(b)!)")
    #expect(visibleArea(h, f) <= sliver(h, f), "\(h.frame(f)!)")
  }

  @Test func parkedWindowsStayOutOfViewBetweenTwoTallerDisplays() {
    let left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false)
    let (h, _, b, f) = zoomedIn(displays: [main, side, left])
    #expect(visibleArea(h, b) <= h.frame(b)!.width * sliver(h, b), "\(h.frame(b)!) shows on a neighbouring display")
    #expect(visibleArea(h, f) <= h.frame(f)!.width * sliver(h, f), "\(h.frame(f)!) shows on a neighbouring display")
  }

  @Test func parkedWindowsStayOutOfViewWhenTheResolutionGrows() {
    let (h, _, b, f) = zoomedIn()
    let larger = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1920, height: 1200),
      visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1175), isMain: true)
    h.system.setDisplays([larger])
    #expect(visibleArea(h, b) <= sliver(h, b), "\(h.frame(b)!)")
    #expect(visibleArea(h, f) <= sliver(h, f), "\(h.frame(f)!)")
    h.run("back")
    #expect(h.system.isVisible(b) && h.system.isVisible(f))
  }

  /// macOS reports changes of the displays in bursts, and often nothing that matters has changed.
  @Test func aReportOfTheDisplaysThatChangesNothingMovesNoWindowOutOfView() {
    let (h, _, _, _) = zoomedIn()
    h.system.clearFrameLog()
    h.system.setDisplays([main])
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog) are where they were already")
  }

  /// Three displays: one to the left that ends higher and has a tall Dock, one below. Where macOS stops a window on
  /// its way down depends on the display it is over, and the place must be judged by that one.
  @Test func aPlaceIsJudgedByTheDisplayThatStopsTheWindowThere() {
    var left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: -1440, y: -270, width: 1440, height: 900),
      visibleFrame: CGRect(x: -1440, y: -233, width: 1440, height: 772), isMain: false)
    left.isMain = false
    let below = DisplaySnapshot(
      id: DisplayID("below"), frame: CGRect(x: 269, y: 900, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 269, y: 900, width: 2560, height: 1440), isMain: false)
    let h = Harness(displays: [main, left, below])
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 100, width: 600, height: 648))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    #expect(visibleArea(h, b) <= 648, "\(h.frame(b)!) shows \(visibleArea(h, b)) square points")
  }

  @Test func aFloatingWindowWhoseAppDoesNotAnswerStillCountsAsOutOfView() {
    let (h, _, _, f) = zoomedIn()
    h.system.setUnresponsive(pid: 13, true)
    h.run("show-all")
    #expect(!h.system.isVisible(f), "it could not be moved")
    #expect(h.controller.snapshot().window(f)?.parked == true, "and Arbor knows")
    h.system.setUnresponsive(pid: 13, false)
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(f), "it comes back when its app answers")
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300), "where the user had it")
  }

  // MARK: No display at all (asleep, or unplugged with the lid closed)

  @Test func quittingWithNoDisplayLeavesNothingInTheCorner() {
    let (h, a, b, f) = zoomedIn()
    h.system.setDisplays([])
    h.controller.shutdown()
    h.system.setDisplays([main])
    for window in [a, b, f] { #expect(main.frame.contains(h.frame(window)!), "\(window) at \(h.frame(window)!)") }
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300), "where the user had it")
  }

  @Test func aWindowOpenedWithNoDisplayIsInViewWhenOneComesBack() {
    let (h, a, _, _) = zoomedIn()
    h.system.setDisplays([])
    let new = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.system.setDisplays([main])
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(h.system.isVisible(new), "nobody has seen it yet")
    h.run("show-all")
    h.run("back")
    #expect(h.system.isVisible(new))
  }

  @Test func everyWindowHasAPlaceAgainOnADifferentDisplay() {
    let (h, a, b, f) = zoomedIn()
    h.system.setDisplays([])
    var other = side
    other.frame.origin = .zero
    other.visibleFrame.origin = .zero
    other.isMain = true
    h.system.setDisplays([other])
    for window in [a, b, f] {
      #expect(h.controller.workspaces[other.id]?.contains(window) == true)
      #expect(other.frame.contains(h.frame(window)!), "\(window) at \(h.frame(window)!)")
    }
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300), "where the user had it")
  }

  @Test func aParkedWindowThatMacOSPullsBackIntoViewIsParkedAgain() {
    // Seen on macOS 26: when a window leaves full screen, the app's parked windows are moved onto the screen.
    let (h, _, b, f) = zoomedIn()
    h.system.userMove(b, to: CGRect(x: 270, y: 31, width: 464, height: 851))
    h.system.userMove(f, to: CGRect(x: 300, y: 100, width: 320, height: 300))
    h.scheduler.advance(by: 1)
    #expect(visibleArea(h, b) <= sliver(h, b), "\(h.frame(b)!)")
    #expect(visibleArea(h, f) <= sliver(h, f), "\(h.frame(f)!)")
    h.run("back")
    #expect(h.frame(b) == h.layout!.windowFrames[b])
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300), "where the user had it, not where macOS put it")
  }

  @Test func arborDoesNotFightOverAParkedWindowForEver() {
    let (h, _, b, _) = zoomedIn()
    var moves = 0
    for _ in 0..<10 {
      h.system.clearFrameLog()
      h.system.userMove(b, to: CGRect(x: 270, y: 31, width: 464, height: 851))
      h.scheduler.advance(by: 1)
      moves += h.system.frameLog.filter { $0.window == b }.count
    }
    #expect(moves == 3)
    // A fresh start the next time it is parked.
    h.run("back")
    h.run("forward")
    h.system.userMove(b, to: CGRect(x: 270, y: 31, width: 464, height: 851))
    h.scheduler.advance(by: 1)
    #expect(visibleArea(h, b) <= sliver(h, b))
  }

  @Test func floatingWindowsStayOnTheScreenWhenTheResolutionShrinks() {
    let h = Harness()
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = h.system.open(app: "Calculator", frame: CGRect(x: 1080, y: 540, width: 320, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    let smaller = DisplaySnapshot(
      id: main.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 768),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 743), isMain: true)
    h.system.setDisplays([smaller])
    #expect(smaller.visibleFrame.contains(h.frame(f)!) && !h.frame(f)!.overlaps(h.frame(a)!), "\(h.frame(f)!)")
    h.system.setDisplays([main])
    #expect(h.frame(f) == CGRect(x: 1080, y: 540, width: 320, height: 300), "and go back when it grows again")
  }

  @Test func quittingBringsBackParkedWindowsOfHiddenApps() {
    let (h, _, b, f) = zoomedIn()
    // ⌥⌘H, "Hide Others", while zoomed in.
    h.system.setHidden(pid: 12, true)
    h.system.setHidden(pid: 13, true)
    h.controller.shutdown()
    #expect(h.system.isVisible(b), "\(h.frame(b)!): showing the app again must not show an empty screen")
    #expect(h.system.isVisible(f), "\(h.frame(f)!)")
  }

  @Test func quittingBringsBackParkedWindowsOnAnotherSpace() {
    let (h, a, b, f) = zoomedIn()
    for window in [a, b, f] { h.system.setOnActiveSpace(window, false) }
    h.scheduler.runPending()
    h.controller.shutdown()
    #expect(h.system.isVisible(b), "\(h.frame(b)!)")
    #expect(h.system.isVisible(f), "\(h.frame(f)!)")
  }

  @Test func aFloatingWindowLeftParkedByACrashComesBack() {
    let (old, _, _, f) = zoomedIn()
    // The state on disk is from just before the zoom; then Arbor is killed.
    old.run("back")
    old.controller.saveNow()
    let saved = old.store.saved
    old.run("forward")
    #expect(!old.system.isVisible(f))

    let h = Harness(saved: saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    #expect(h.system.isVisible(f), "\(h.frame(f)!)")
    #expect(h.frame(f) == CGRect(x: 560, y: 300, width: 320, height: 300))
  }

  /// People push a large window aside until a strip of it shows, to pull it back by. A strip is not "out of view",
  /// however small a share of the window it is.
  @Test func aLargeWindowPushedAsideToAStripIsNotTakenAway() {
    // An ordinary floating window: a guest is left alone anyway.
    var settings = Settings()
    settings.newWindowsWhileFramed = "float"
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    // It opens over the framed window, and is pushed aside until 24 points show: 1.7 % of it.
    let big = h.system.open(app: "Figma", pid: 13, frame: CGRect(x: 20, y: 30, width: 1400, height: 860))
    let aside = CGRect(x: 1440 - 24, y: 30, width: 1400, height: 860)
    h.system.userMove(big, to: aside)
    for command in ["relayout", "resize \(a.rawValue) right 20", "zoom \(a.rawValue)"] {
      h.run(command)
      #expect(h.frame(big) == aside, "`\(command)` took it away")
    }
  }

  // MARK: What a relaunch and a smaller display must not take away

  /// Five windows arranged, and two floating windows in view over them: the Desktop has no room, or with a column of its own
  /// is a tile.
  func overDockedWindows(settings: Settings) -> (Harness, note: WindowID, call: WindowID) {
    let h = Harness(settings: settings)
    for name in ["A", "B", "C", "D", "E"] { h.system.open(app: name) }
    h.start()
    h.run("arrange")
    #expect(h.layout!.desktopFrame == nil)
    let note = h.system.open(app: "Note", pid: 21, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let call = h.system.open(app: "Call", pid: 22, frame: CGRect(x: 200, y: 100, width: 400, height: 300))
    h.system.userMove(call, to: CGRect(x: 900, y: 500, width: 400, height: 300))
    return (h, note, call)
  }

  @Test(arguments: ["guest", "float"], [false, true])
  func aRelaunchTakesNothingOutOfViewThatWasInView(mode: String, desktopColumn: Bool) {
    var settings = Settings()
    settings.desktopColumn = desktopColumn
    settings.newWindowsWhileFramed = mode
    let (h, note, call) = overDockedWindows(settings: settings)
    let before = [note, call].map { h.frame($0)! }
    h.controller.shutdown()
    h.controller.start()
    #expect([note, call].map { h.frame($0)! } == before, "\(mode)")
  }

  @Test(arguments: [false, true]) func norDoesAPauseAndResume(desktopColumn: Bool) {
    var settings = Settings()
    settings.desktopColumn = desktopColumn
    settings.newWindowsWhileFramed = "float"
    let (h, note, call) = overDockedWindows(settings: settings)
    let before = [note, call].map { h.frame($0)! }
    h.run("pause")
    h.run("resume")
    #expect([note, call].map { h.frame($0)! } == before)
  }

  @Test func norWhatWasOutOfViewBeforeTheQuit() {
    let (h, _, b, f) = zoomedIn()
    h.controller.shutdown()
    #expect(h.system.isVisible(f) && h.system.isVisible(b), "quitting brings everything back")
    h.controller.start()
    #expect(h.system.isVisible(f) && h.system.isVisible(b), "and a launch leaves it in view")
  }

  /// A very wide window hangs far over the left edge, on purpose. Its display goes and comes back; meanwhile its app
  /// has stopped allowing that size. Sent to the frame it had, it takes the corner of it that lies beyond the edge.
  @Test func aWindowSentBackToAFrameItsAppNoLongerAllowsIsNotLeftBeyondTheEdge() {
    let h = Harness()
    h.start()
    let wide = h.system.open(app: "Music", frame: CGRect(x: 0, y: 100, width: 3700, height: 700))
    h.system.userMove(wide, to: CGRect(x: -1080, y: 260, width: 3700, height: 700))
    var other = main
    other.id = DisplayID("other")
    h.system.setDisplays([other])
    h.system.setMaximumSize(wide, CGSize(width: 611, height: 668))
    h.system.setDisplays([main])
    let showing = h.frame(wide)!.intersection(main.frame)
    #expect(showing.width > 100 && showing.height > 100, "\(h.frame(wide)!) is on no display")
    let place = h.frame(wide)!
    for next in ["home", "relayout", "float-all", "home", "desktop"] { h.run(next) }
    #expect(h.frame(wide) == place, "what is remembered is right too")
  }

  /// Less than half of it shows, because that is where its user left it, and its app takes the frame it is asked to.
  /// Being put back there (undo and redo do that) neither moves it nor changes what is remembered.
  @Test func aWindowLeftMostlyBelowTheEdgeKeepsItsPlaceThroughUndoAndRedo() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let low = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 900, y: 200, width: 420, height: 320))
    h.start()
    let place = CGRect(x: 900, y: 760, width: 420, height: 320)
    h.system.userMove(low, to: place)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(low.rawValue) right")
    h.run("undo")
    #expect(h.frame(low) == place, "undo puts it back where it floated")
    #expect(h.workspace.floating[low] == place)
    h.run("redo")
    h.run("undo")
    #expect(h.frame(low) == place)
    #expect(h.workspace.floating[low] == place)
  }

  // MARK: An overhang is known, not guessed

  /// Wholly in view on a large display, which goes; a smaller one is left, which the remembered frame overlaps by 30 points.
  @Test func aFrameThatOverlapsAnotherDisplayByChanceIsNoStripSomebodyLeft() {
    var large = main
    large.frame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    large.visibleFrame = CGRect(x: 0, y: 25, width: 2560, height: 1415)
    let h = Harness(displays: [large])
    h.start()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 1000, y: 300, width: 500, height: 400))
    h.system.userMove(notes, to: CGRect(x: 1410, y: 300, width: 500, height: 400))
    var small = main
    small.id = DisplayID("small")
    h.system.setDisplays([small])
    h.scheduler.advance(by: 3)
    #expect(small.frame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
    for way in ["home", "relayout", "desktop", "home"] { h.run(way) }
    #expect(small.frame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
  }

  /// The same display under the same name, smaller.
  @Test func norOnItsOwnDisplayOnceThatHasShrunk() {
    var large = main
    large.frame = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    large.visibleFrame = CGRect(x: 0, y: 25, width: 2560, height: 1415)
    let h = Harness(displays: [large])
    h.start()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 1000, y: 300, width: 500, height: 400))
    h.system.userMove(notes, to: CGRect(x: 1410, y: 300, width: 500, height: 400))
    h.system.setDisplays([main])
    h.scheduler.advance(by: 3)
    #expect(main.frame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
  }

  /// What its user left hanging, on the display as it is, goes on hanging: out of view and back, and through every way home.
  @Test func whatItsUserLeftHangingOnThisDisplayGoesOnHanging() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 300, width: 500, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    let strip = CGRect(x: 1400, y: 300, width: 500, height: 400)
    h.system.userMove(notes, to: strip)
    for way in ["zoom \(a.rawValue)", "back", "home", "relayout", "desktop", "home"] { h.run(way) }
    #expect(h.frame(notes) == strip)
  }

  /// A frame Arbor was given by nobody's hand: its app opened the window there, more than half of it showing. One of which under half
  /// shows was taken to the middle as it opened; since what is found counts as left it stays, and goes out of view and back like one that
  /// a hand left (FoundCountsAsLeftTests). Arbor places floating windows only where they make way. As it ships both come back exactly where
  /// they were (F64).
  @Test(arguments: [false, true]) func aWindowItsAppOpenedOverTheEdgeIsBroughtInWhenArborPlacesIt(makingWay: Bool) {
    let h = Harness(settings: makingWay ? .makingWay : Settings())
    let a = h.system.open(app: "Safari", pid: 11)
    h.start()
    h.run("dock \(a.rawValue) left")
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 1100, y: 300, width: 500, height: 400))
    let strip = CGRect(x: 1300, y: 300, width: 500, height: 400)
    let mail = h.system.open(app: "Mail", pid: 13, frame: strip)
    h.run("zoom \(a.rawValue)")
    h.run("back")
    if makingWay {
      #expect(main.frame.contains(h.frame(notes)!), "\(h.frame(notes)!)")
    } else {
      #expect(h.frame(notes) == CGRect(x: 1100, y: 300, width: 500, height: 400))
    }
    #expect(h.frame(mail) == strip)
  }

  /// However a floating window came to be where no display shows it, unmarked: the first way home fetches it, and
  /// it stays fetched.
  @Test(arguments: ["home", "show-all", "relayout", "desktop", "float-all"])
  func theWaysHomeFetchAFloatingWindowThatNoDisplayShows(way: String) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let stray = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 700, y: 200, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    // Its app takes it there by itself, and Arbor takes that for its place.
    h.system.userMove(stray, to: CGRect(x: -2000, y: 200, width: 400, height: 300))
    h.run(way)
    #expect(main.frame.contains(h.frame(stray)!), "`\(way)` left it at \(h.frame(stray)!)")
    for next in ["zoom \(a.rawValue)", "home", "relayout"] { h.run(next) }
    #expect(main.frame.contains(h.frame(stray)!), "and it stays fetched: \(h.frame(stray)!)")
  }

  /// Five roads: it hangs over the FAR edge of a side display, 64 % showing. The display goes; its app makes it
  /// narrower; the display returns.
  @Test(arguments: ["replug", "a stranger between", "all gone", "paused"])
  func aDisplayThatReturnsDoesNotTakeANarrowerWindowBeyondItsFarEdge(road: String) {
    let left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false)
    let h = Harness(displays: [main, left])
    h.start()
    let notes = h.system.open(app: "Notes", frame: CGRect(x: -2100, y: 300, width: 500, height: 400))
    if road == "paused" { h.run("pause") }
    h.system.setDisplays(road == "all gone" ? [] : [main])
    h.system.setMaximumSize(notes, CGSize(width: 150, height: 400))
    h.system.userMove(notes, to: CGRect(origin: h.frame(notes)!.origin, size: CGSize(width: 150, height: 400)))
    if road == "a stranger between" { h.system.setDisplays([main, side]) }
    h.system.setDisplays([main, left])
    if road == "paused" { h.run("resume") }
    h.scheduler.advance(by: 3)
    #expect(visibleArea(h, notes) >= 150 * 400 / 2, "\(road): \(h.frame(notes)!)")
    let place = h.frame(notes)!
    for next in ["home", "relayout", "float-all", "home"] { h.run(next) }
    #expect(h.frame(notes) == place, "\(road): and what is remembered is right too")
  }

  /// It lay over a docked window, on purpose, so it was left alone. Now no display shows it.
  @Test func aFloatingWindowOverDockedSpaceIsBroughtBackWhenTheDisplayShrinksAwayFromIt() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Mail", pid: 12)
    let call = h.system.open(app: "Call", pid: 13, frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.system.userMove(call, to: CGRect(x: 1120, y: 680, width: 300, height: 200))
    var smaller = main
    smaller.frame.size = CGSize(width: 1024, height: 768)
    smaller.visibleFrame = CGRect(x: 0, y: 25, width: 1024, height: 743)
    h.system.setDisplays([smaller])
    #expect(smaller.frame.contains(h.frame(call)!), "\(h.frame(call)!) is on no display")
  }

  /// After a crash Arbor finds the window in the corner but does not know that it put it there.
  @Test func aWindowFoundInItsCornerAtLaunchIsSentBackIfSomethingPullsItIntoView() {
    let (old, _, _, f) = zoomedIn()
    old.controller.saveNow()
    let h = Harness(saved: old.store.saved)
    for window in old.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.system.focused = old.system.focused
    h.controller.restartedAfterAccident = true
    h.start()
    #expect(!h.system.isVisible(f), "the view is still on Safari")
    h.system.userMove(f, to: CGRect(x: 500, y: 300, width: 320, height: 300))
    h.run("relayout")
    #expect(!h.system.isVisible(f), "\(h.frame(f)!)")
  }

  @Test(arguments: [false, true]) func aWindowHangingOffTheScreenAtLaunchIsNotCountedAsOutOfView(makingWay: Bool) {
    // Framed on Safari when Arbor quit. Meanwhile a floating window was left hanging off the right edge, most of
    // it off screen but 180 points of it showing.
    let old = Harness()
    let a = old.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let f = old.system.open(app: "Notes", frame: CGRect(x: 500, y: 300, width: 500, height: 400))
    old.start()
    old.run("dock \(a.rawValue) left")
    old.controller.saveNow()
    var saved = old.store.saved!
    saved.workspaces[old.display]!.moveCamera(to: saved.workspaces[old.display]!.tree.leaf(containing: a)!)

    let h = Harness(settings: makingWay ? .makingWay : Settings(), saved: saved)
    _ = h.system.open(app: "Safari", frame: old.frame(a)!)
    _ = h.system.open(app: "Notes", frame: CGRect(x: 1260, y: 300, width: 500, height: 400))
    h.start()
    // The books and the screen agree, one way or the other.
    #expect(h.controller.parked.contains(f) == (visibleArea(h, f) < 40), "\(h.frame(f)!)")
    h.run("show-all")
    // Either way: nobody can tell who left it there, and less than half of it shows. Where in doubt, in view (Q20).
    #expect(h.system.isVisible(f))
  }

  /// Arbor lets go of a window that is out of view while its app does not answer. It still owes it the way back.
  @Test func aWindowLetGoOfWhileItsAppDoesNotAnswerIsBroughtBackWhenItDoes() {
    let (h, _, b, f) = zoomedIn()
    for (window, pid, bundle) in [(b, Int32(12), "com.example.notes"), (f, Int32(13), "com.example.calculator")] {
      h.system.setUnresponsive(pid: pid, true)
      h.run("exclude \(bundle)")
      #expect(!h.system.isVisible(window), "it could not be moved")
      h.system.setUnresponsive(pid: pid, false)
      h.scheduler.runPending()
      #expect(main.frame.contains(h.frame(window)!), "\(window) is still at \(h.frame(window)!)")
    }
  }

  @Test func orAtTheLatestWhenArborQuits() {
    let (h, _, b, _) = zoomedIn()
    h.system.setUnresponsive(pid: 12, true)
    h.run("exclude com.example.notes")
    // It answers again without having anything to report.
    h.system.events = nil
    h.system.setUnresponsive(pid: 12, false)
    h.system.events = h.controller
    h.controller.shutdown()
    #expect(main.frame.contains(h.frame(b)!), "\(h.frame(b)!)")
  }

  @Test func excludingAnAppBringsBackItsParkedWindowAtItsOwnSize() {
    let (h, _, b, _) = zoomedIn()
    h.run("exclude com.example.notes")
    #expect(h.system.isVisible(b))
    #expect(h.visibleFrame.contains(h.frame(b)!))
  }
}
