import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

// An independent review of F33: what real macOS sends while windows are shrunk out of view, the ways out of
// the corner that come after a crash, and the switches flipped in the middle of everything.

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
@MainActor private let main = FakeWindowSystem.standardDisplay
private let small = CGSize(width: 320, height: 200)

private func shrinking(makingWay: Bool = false) -> Settings {
  var settings = makingWay ? Settings.makingWay : Settings()
  settings.shrinkOutOfView = true
  return settings
}

/// [a | b], two halves, with c floating over the two of them where the user put it.
@MainActor
private func makeDesk(_ settings: Settings) -> (Harness, WindowID, WindowID, WindowID) {
  let h = Harness(settings: settings)
  let a = h.system.open(app: "Safari", pid: 1001, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
  let b = h.system.open(app: "Notes", pid: 1002, frame: CGRect(x: 300, y: 200, width: 610, height: 410))
  let c = h.system.open(app: "Mail", pid: 1003, frame: CGRect(x: 500, y: 300, width: 620, height: 420))
  h.start()
  h.run("dock \(a.rawValue) left")
  h.run("dock \(b.rawValue) right")
  h.system.userMove(c, to: CGRect(x: 520, y: 300, width: 400, height: 420))
  return (h, a, b, c)
}

@MainActor
private func frames(_ h: Harness) -> [WindowID: CGRect] {
  Dictionary(uniqueKeysWithValues: h.system.allWindows().map { ($0.id, $0.frame) })
}

/// A new Arbor, started by the watchdog, that finds the windows of `old` as they are now, minimized ones included, and the state it saved. With
/// `nothingRemembered` the state holds no frames for docked windows (F48), like a file from before it: a docked window
/// that leaves the arrangement then goes by its slot, or by its own size.
@MainActor
private func relaunchAfterCrash(_ old: Harness, settings: Settings, nothingRemembered: Bool = false) -> Harness {
  old.controller.saveNow()
  func stripped(_ value: Any) -> Any {
    if let list = value as? [Any] { return list.map(stripped) }
    guard var object = value as? [String: Any] else { return value }
    object["undockedFrames"] = nil
    return object.mapValues(stripped)
  }
  var saved = old.store.saved
  if nothingRemembered {
    saved = try! JSONDecoder().decode(
      PersistedState.self,
      from: JSONSerialization.data(
        withJSONObject: stripped(JSONSerialization.jsonObject(with: JSONEncoder().encode(old.store.saved!)))))
  }
  let new = Harness(displays: old.system.displayList, settings: settings, saved: saved)
  for window in old.system.allWindows() {
    let id = new.system.open(
      app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    if window.isMinimized { new.system.setMinimized(id, true) }
  }
  // Whoever had the keyboard has it still: Arbor's end is nothing to the apps.
  new.system.focused = old.system.focused
  new.controller.restartedAfterAccident = true
  new.start()
  return new
}

/// What macOS reports after Arbor has set a window's frame (collab/evidence/ax-events.txt): resized where it stood,
/// moved, resized again, none of it the user's doing.
@MainActor
private func echo(_ h: Harness, _ window: WindowID, from old: CGRect) {
  guard var snapshot = h.controller.windows[window], let final = h.frame(window), final != old else { return }
  snapshot.frame = CGRect(origin: old.origin, size: final.size)
  h.controller.windowChanged(snapshot, userInitiated: false)
  snapshot.frame = final
  h.controller.windowChanged(snapshot, userInitiated: false)
  h.controller.windowChanged(snapshot, userInitiated: false)
}

@Suite @MainActor struct ReviewShrinkOutOfViewTests {
  @Test(arguments: [false, true]) func theEchoesOfGoingAndComingBackChangeNothing(makingWay: Bool) {
    let (h, a, b, c) = makeDesk(shrinking(makingWay: makingWay))
    let before = frames(h)
    let remembered = h.workspace.floating[c]

    h.run("zoom \(a.rawValue)")
    let away = frames(h)
    h.system.clearFrameLog()
    for window in [a, b, c] { echo(h, window, from: before[window]!) }
    h.scheduler.runPending()
    #expect(h.system.frameLog.isEmpty, "an echo of Arbor's own move made it move something: \(h.system.frameLog)")
    #expect(h.frame(b)!.size == small)
    // Mail floats: it goes, and is made small, only if it makes way. As Arbor ships it is where it was.
    if makingWay { #expect(h.frame(c)!.size == small) } else { #expect(h.frame(c) == before[c]) }
    #expect(h.workspace.floating[c] == remembered)

    h.run("back")
    h.system.clearFrameLog()
    for window in [a, b, c] { echo(h, window, from: away[window]!) }
    h.scheduler.runPending()
    #expect(h.system.frameLog.isEmpty, "an echo of Arbor's own move made it move something: \(h.system.frameLog)")
    #expect(frames(h) == before)
    #expect(h.workspace.floating[c] == remembered)
  }

  /// Minimizing a window makes macOS announce a display change although no display changed.
  @Test(arguments: [false, true]) func aDisplayChangeThatChangesNothingLeavesShrunkWindowsAlone(makingWay: Bool) {
    let (h, a, b, c) = makeDesk(shrinking(makingWay: makingWay))
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    h.system.clearFrameLog()
    h.system.setDisplays(h.system.displayList)
    h.scheduler.runPending()
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    // Mail floats: it leaves with the Desktop only if it makes way.
    #expect(h.controller.parked == (makingWay ? [b, c] : [b]))
    h.run("back")
    #expect(frames(h) == before)
  }

  /// ⌘H on an app whose floating window is out of view, then quit. Nobody is there to bring it back afterwards.
  @Test func aFloatingWindowHiddenWhileItIsShrunkIsBackAtItsSizeAfterQuitting() {
    let (h, a, _, c) = makeDesk(shrinking())
    let before = frames(h)
    h.run("zoom \(a.rawValue)")
    h.system.setHidden(pid: 1003, true)
    h.controller.shutdown()
    h.system.setHidden(pid: 1003, false)
    #expect(h.frame(c) == before[c])
  }

  @Test func afterACrashQuittingStraightAwayLeavesNothingSmallOrOutOfView() {
    let (old, a, b, c) = makeDesk(shrinking())
    let before = frames(old)
    old.run("zoom \(a.rawValue)")
    // The setting can have been turned off in between: what the crashed run did still has to be undone.
    for settings in [shrinking(), Settings()] {
      for nothingRemembered in [false, true] {
        let h = relaunchAfterCrash(old, settings: settings, nothingRemembered: nothingRemembered)
        #expect(h.frame(b)!.size == small, "still out of view, as the saved view says")
        h.controller.shutdown()
        // Where it floated before it was docked, or in its slot if nobody knows.
        #expect(h.frame(b) == (nothingRemembered ? before[b] : CGRect(x: 300, y: 200, width: 610, height: 410)))
        #expect(h.frame(c) == before[c])
      }
    }
  }

  @Test func afterACrashAMinimizedWindowLeftSmallInTheCornerGetsItsPlaceWhenItIsRestored() {
    let (old, a, b, c) = makeDesk(shrinking())
    let before = frames(old)
    old.run("zoom \(a.rawValue)")
    old.system.setMinimized(b, true)
    old.system.setMinimized(c, true)
    let h = relaunchAfterCrash(old, settings: shrinking())
    h.run("show-all")
    h.system.setMinimized(b, false)
    h.system.setMinimized(c, false)
    h.scheduler.runPending()
    #expect(h.frame(b) == before[b])
    #expect(h.frame(c) == before[c])
  }

  /// A native tab that comes to the front is another window to macOS, at the frame of the one it replaces. What
  /// Arbor knows about the one holds for the other, the size it has in view included.
  @Test func aNativeTabThatComesToTheFrontOutOfViewInheritsTheSizeToComeBackTo() {
    let (docked, a, b, _) = makeDesk(shrinking())
    let h = relaunchAfterCrash(docked, settings: shrinking(), nothingRemembered: true)
    let size = h.frame(b)!.size
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == small)
    let tab = h.system.openTab(in: b)!
    #expect(h.controller.parked.contains(tab))
    #expect(h.run("float \(tab.rawValue)").ok)
    #expect(h.workspace.floating[tab]?.size == size)
    h.run("show-all")
    #expect(h.frame(tab)?.size == size)
  }

  /// With a display to the right that reaches lower, windows go to the bottom-left corner, where an app that refuses to
  /// shrink is placed a second time. Arbor must know where that left the window: a frame it does not expect
  /// looks like somebody else's move.
  @Test func arborKnowsWhereAWindowThatRefusedToShrinkEndedUp() {
    let tall = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 1200),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 1200), isMain: false)
    let h = Harness(displays: [main, tall], settings: shrinking())
    let a = h.system.open(app: "Safari", pid: 1001)
    let b = h.system.open(app: "Music", pid: 1002, minimumSize: CGSize(width: 500, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(h.frame(b)!.size == CGSize(width: 500, height: 300))
    #expect(h.frame(b)!.maxX == 1, "bottom-left, one point showing")
    #expect(h.controller.windows[b]?.frame == h.frame(b))
  }

  /// "Back to a normal Mac" and quitting lay windows out as if nothing were too small to show. Windows that were
  /// inside tiles, shrunk in the corner, and whose own frames nobody remembers go side by side where their tiles were,
  /// not on top of each other.
  @Test(.withTiles) func floatAllAndQuittingPutWindowsThatWereInTilesWhereTheirTilesWere() {
    for leave in ["float-all", "quit"] {
      var settings = shrinking()
      // Three in a row are 464 points wide each.
      settings.minimumUsableWidth = 500
      let docked = Harness(settings: settings)
      let windows = (0..<3).map { docked.system.open(app: "App\($0)", pid: Int32(1001 + $0)) }
      docked.start()
      for window in windows.reversed() { docked.run("dock \(window.rawValue) left") }
      // With the keyboard in one of them, the start would bring that one into view.
      docked.system.userFocusesNothing()
      let h = relaunchAfterCrash(docked, settings: settings, nothingRemembered: true)
      let tiles = h.layout!.tiles.filter { $0.kind == .window }
      #expect(tiles.count == 3)
      for window in windows { #expect(h.frame(window)!.size == small) }
      if leave == "quit" { h.controller.shutdown() } else { h.run(leave) }
      for (window, tile) in zip(windows, tiles.sorted { $0.frame.minX < $1.frame.minX }) {
        #expect(h.frame(window) == tile.frame, "\(leave): \(window)")
      }
    }
  }

  /// The same for a tile that stands for a whole group, whose windows have no rectangle of their own in the layout.
  @Test(.withTiles) func floatAllAndQuittingBringBackTheWindowsOfAGroupTile() {
    for leave in ["float-all", "quit"] {
      var settings = shrinking()
      // Two columns are 702 points wide each.
      settings.minimumUsableWidth = 750
      let docked = Harness(settings: settings)
      let a = docked.system.open(app: "Safari", pid: 1001)
      let b = docked.system.open(app: "Notes", pid: 1002)
      let c = docked.system.open(app: "Mail", pid: 1003)
      docked.start()
      docked.run("dock \(c.rawValue) left")
      docked.run("dock \(a.rawValue) left")
      docked.run("dock \(b.rawValue) beside \(a.rawValue) bottom")
      docked.system.userFocusesNothing()
      let h = relaunchAfterCrash(docked, settings: settings, nothingRemembered: true)
      let group = h.layout!.tiles.first { $0.kind == .group }
      #expect(group?.windows == [a, b])
      for window in [a, b, c] { #expect(h.frame(window)!.size == small) }
      if leave == "quit" { h.controller.shutdown() } else { h.run(leave) }
      #expect(h.frame(a)!.union(h.frame(b)!) == group?.frame, "\(leave)")
      #expect(h.frame(a)!.maxY + 12 == h.frame(b)!.minY, "\(leave)")
      #expect(abs(h.frame(a)!.height - h.frame(b)!.height) <= 1, "\(leave)")
    }
  }

  /// A window that is a tile because its app will not shrink to its slot goes to the corner like the rest. What it
  /// does there says nothing new about it: it stays a tile, and Arbor does not keep trying.
  @Test(.withTiles) func aTileWhoseAppRefusesToShrinkStaysATileThroughTheEchoes() {
    // Without F61, which would take room from the neighbours instead of making a tile.
    var settings = shrinking()
    settings.makeRoom = false
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 1001)
    let b = h.system.open(app: "Music", pid: 1002, frame: CGRect(x: 300, y: 200, width: 900, height: 600),
      minimumSize: CGSize(width: 800, height: 500))
    h.start()
    h.run("dock \(a.rawValue) left")
    let shown = h.frame(b)!
    h.run("dock \(b.rawValue) left")
    #expect(h.layout?.tiles.contains { $0.windows == [b] } == true)
    #expect(h.frame(b)!.size == CGSize(width: 800, height: 500))
    h.system.clearFrameLog()
    echo(h, b, from: shown)
    h.scheduler.runPending()
    #expect(h.system.frameLog.isEmpty, "\(h.system.frameLog)")
    #expect(h.layout?.tiles.contains { $0.windows == [b] } == true)
    h.run("zoom \(b.rawValue)")
    #expect(h.frame(b) == h.layout?.windowFrames[b])
  }
}

/// A small repeatable random number generator, so that a failure can be run again.
private struct Dice {
  var state: UInt64
  mutating func roll(_ sides: Int) -> Int {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Int((state >> 33) % UInt64(sides))
  }
}

@Suite @MainActor struct ReviewSwitchesFlippedTests {
  /// Random commands and events while `shrinkOutOfView` and `shareRemovedSpace` go on and off. At every step no window
  /// that is in view is as small as the corner makes them, and the trees stay valid. Windows open larger
  /// than 320 × 200, so one that measures exactly that was forgotten.
  @Test(arguments: 1...8) func flippingTheSwitchesInTheMiddleOfEverythingLeavesNoWindowSmall(seed: Int) {
    var dice = Dice(state: UInt64(seed) &+ 77)
    var settings = Settings()
    let h = Harness(displays: [main, side], settings: settings)
    h.start()
    var open: [WindowID] = []
    func any() -> UInt32 { open.isEmpty ? 1 : open[dice.roll(open.count)].rawValue }
    func edge() -> String { ["left", "right", "top", "bottom"][dice.roll(4)] }
    func point() -> CGPoint {
      CGPoint(x: dice.roll(h.system.displayList.count == 2 ? 2720 : 1440), y: dice.roll(800))
    }
    func bringEveryoneBack() {
      for window in open {
        h.system.setMinimized(window, false)
        h.system.setOnActiveSpace(window, true)
        h.system.setFullScreen(window, false)
      }
      for pid in 2000..<2003 { h.system.setHidden(pid: Int32(pid), false) }
      h.scheduler.runPending()
    }
    func isCutSmall(_ frame: CGRect) -> Bool {
      (abs(frame.width - small.width) < 1 && frame.height <= small.height)
        || (abs(frame.height - small.height) < 1 && frame.width <= small.width)
    }

    for step in 0..<300 {
      switch dice.roll(23) {
      case 0, 1:
        if open.count < 6 {
          let size = CGSize(width: 330 + dice.roll(500), height: 210 + dice.roll(400))
          open.append(
            h.system.open(
              app: "App\(open.count % 3)", pid: Int32(2000 + open.count % 3),
              frame: CGRect(origin: point(), size: size).fitted(into: h.system.displayList[0].frame),
              minimumSize: CGSize(width: 100, height: 60)))
        }
      case 2: if open.count > 3 { h.system.close(open.remove(at: dice.roll(open.count))) }
      case 3: h.system.setMinimized(WindowID(any()), dice.roll(2) == 0)
      case 4: h.system.setHidden(pid: Int32(2000 + dice.roll(3)), dice.roll(2) == 0)
      case 5, 6: h.run("dock \(any()) \(edge())")
      case 7: h.run("dock \(any()) beside \(any()) \(edge())")
      case 8: h.run("float \(any())")
      case 9, 10: h.run("zoom \(any())")
      case 11: h.run(["in", "out", "back", "forward", "show-all", "desktop"][dice.roll(6)])
      case 12:
        h.system.cursor = point()
        h.system.userFocus(WindowID(any()))
      case 13:
        settings.shrinkOutOfView.toggle()
        h.controller.apply(settings: settings)
      case 14:
        settings.shareRemovedSpace.toggle()
        h.controller.apply(settings: settings)
      case 15 where h.controller.isRunning:
        // Everyone is brought back first: see the F33 report, "Found and not fixed".
        bringEveryoneBack()
        h.system.setDisplays(dice.roll(2) == 0 ? [main] : [main, side])
      case 16: h.run(["arrange", "float-all", "pause", "resume", "resume"][dice.roll(5)])
      case 17: h.run("\(["pin", "unpin", "toggle-pin"][dice.roll(3)]) \(any())")
      case 18: h.run("toggle-float \(any())")
      case 19 where h.controller.isRunning && !open.isEmpty:
        // A native tab comes to the front: to macOS, another window in the same place.
        let index = dice.roll(open.count)
        // (Not in full screen: the fake would not know what frame the new window leaves full screen to.)
        if h.system.windows[open[index]]?.snapshot.isFullScreen == false, let tab = h.system.openTab(in: open[index]) {
          open[index] = tab
        }
      case 20:
        // The green button of a window that can be seen. (One that entered full screen from the corner would leave it
        // for the corner, whatever the switches say.)
        let window = WindowID(any())
        if h.system.isVisible(window), h.system.windows[window]?.snapshot.isPresent == true {
          h.system.setFullScreen(window, dice.roll(2) == 0)
        }
      case 21: h.run("\(["save-view", "view"][dice.roll(2)]) \(1 + dice.roll(2))")
      default: h.run("resize \(any()) \(edge()) \(dice.roll(300) - 150)")
      }
      h.scheduler.runPending()
      h.scheduler.runPending()

      for workspace in h.controller.workspaces.values {
        #expect(workspace.tree.invariantViolations().isEmpty, "step \(step)")
      }
      for window in open where h.system.isVisible(window) && !h.controller.parked.contains(window) {
        let slot = h.controller.layouts.values.compactMap { $0.windowFrames[window] }.first
        // A slot can happen to have that size.
        if let slot, isCutSmall(slot) { continue }
        #expect(!isCutSmall(h.frame(window)!), "step \(step): \(window) is in view at \(h.frame(window)!)")
      }
    }

    h.run("resume")
    bringEveryoneBack()
    h.run("home")
    h.scheduler.runPending()
    // What is still out of view is in a tile, or on a Desktop that is one.
    for window in open where !h.controller.parked.contains(window) {
      #expect(h.system.isVisible(window), "\(window) at \(h.frame(window)!) with everything shown")
      if let remembered = h.controller.workspaces.values.compactMap({ $0.floating[window] }).first {
        if !isCutSmall(remembered) { #expect(!isCutSmall(h.frame(window)!), "\(window) at \(h.frame(window)!)") }
      }
    }
  }
}
