import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A display above and to the left of the standard one: every coordinate on it is negative.
private let upperDisplay = DisplaySnapshot(
  id: DisplayID("upper"), frame: CGRect(x: -1000, y: -1100, width: 1900, height: 1100),
  visibleFrame: CGRect(x: -1000, y: -1075, width: 1900, height: 1075), isMain: false)

/// Every weight but that of a Desktop that nothing is left for: that one is 0 to the digit, and it is in nobody's sum.
@MainActor private func weights(_ h: Harness) -> [Double] {
  h.controller.workspaces.values.flatMap { workspace in
    workspace.tree.preorder(from: workspace.tree.root).filter { $0 != workspace.tree.desktop || workspace.tree[$0]!.weight != 0 }
      .map { workspace.tree[$0]!.weight }
  }
}

/// Review of F22 (keyboard tiling tools): what an independent reader tried to break.
@Suite @MainActor struct ReviewTilingTests {
  func nested() -> (Harness, [WindowID]) {
    var settings = Settings()
    settings.tabsEnabled = true
    return tilingScenario(
      ["A", "B", "C", "D", "E", "F"],
      ["dock $0 left", "dock $1 right", "dock $2 beside $0 down", "dock $3 beside $2 right", "dock $4 beside $3 down",
       "resize $0 right 77", "resize $2 top 33", "zoom $3", "save-view 1", "name deep", "out", "save-view 2", "name pair", "show-all"],
      settings: settings)
  }

  /// Twice (or four times) gives back the same workspace to the last digit: tree, ids, weights, view, history, saved views, names.
  @Test func mirrorRotateAndBalanceComeBackToWhereTheyWere() {
    for index in 0..<5 {
      for commands in [["mirror", "mirror"], ["rotate", "rotate"], ["rotate", "rotate", "rotate", "rotate"], ["mirror", "rotate", "mirror", "rotate"]] {
        let (h, w) = nested()
        h.system.userFocus(w[index])
        let before = h.workspace
        guard commands.allSatisfy({ h.run($0).ok }) else { continue }
        #expect(h.workspace == before, "\(w[index]): \(commands)")
        expectSound(h)
      }
      for command in ["balance", "balance all"] {
        let (h, w) = nested()
        h.system.userFocus(w[index])
        let (views, names) = (h.workspace.savedViews, h.workspace.names)
        runOK(h, command)
        let once = h.workspace
        runOK(h, command)
        #expect(h.workspace == once, "\(w[index]): \(command) twice")
        #expect(once.savedViews == views && once.names == names)
        expectSound(h)
      }
    }
  }

  /// F48: docking stretches a window, and floating gives it its own size back, also after it changed displays by `swap`.
  @Test func windowsSwappedAcrossDisplaysStillKnowTheSizeTheyFloatedAt() {
    var settings = Settings()
    settings.tabsEnabled = true
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay], settings: settings)
    let a = h.system.open(app: "A", frame: CGRect(x: 100, y: 100, width: 410, height: 310))
    let other = h.system.open(app: "Other", frame: CGRect(x: 200, y: 100, width: 420, height: 320))
    let b = h.system.open(app: "B", frame: CGRect(x: 1600, y: 100, width: 530, height: 430))
    let tab = h.system.open(app: "Tab", frame: CGRect(x: 1700, y: 100, width: 540, height: 440))
    h.start()
    for window in [a, other, b] { runOK(h, "dock \(window.rawValue) left") }
    h.system.drag(tab, through: [CGPoint(x: 1970, y: 110), h.frame(b)!.center])
    #expect(h.controller.workspaces[sideDisplay.id]?.tree.leaf(containing: tab) == h.controller.workspaces[sideDisplay.id]?.tree.leaf(containing: b))

    runOK(h, "swap \(a.rawValue) \(b.rawValue)")
    for (display, workspace) in h.controller.workspaces {
      let strangers = (workspace.undockedFrames ?? [:]).keys.filter { !workspace.isDocked($0) }
      #expect(strangers.isEmpty, "\(display) remembers the size of windows that have left: \(strangers)")
    }
    for (window, size) in [(a, CGSize(width: 410, height: 310)), (b, CGSize(width: 530, height: 430)), (tab, CGSize(width: 540, height: 440))] {
      runOK(h, "float \(window.rawValue)")
      #expect(h.frame(window)?.size == size, "\(window)")
    }
    #expect(sideDisplay.visibleFrame.contains(h.frame(a)!))
    #expect(h.visibleFrame.contains(h.frame(b)!) && h.visibleFrame.contains(h.frame(tab)!))
    expectSound(h)
  }

  /// F53: a summoned window goes away when the keyboard goes elsewhere, also after it was sent to another display.
  @Test func aSummonedWindowSentToAnotherDisplayIsStillSummoned() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    let a = h.system.open(app: "A")
    let notes = h.system.open(app: "Notes", frame: CGRect(x: 200, y: 100, width: 420, height: 320))
    let s = h.system.open(app: "S", frame: CGRect(x: 1700, y: 100, width: 400, height: 300))
    h.start()
    runOK(h, "dock \(a.rawValue) left")
    runOK(h, "dock \(s.rawValue) left")
    runOK(h, "summon Notes")
    runOK(h, "move-to-display next \(notes.rawValue)")
    #expect(h.controller.role(of: notes) == .summoned(app: "com.example.notes"))
    #expect(h.system.isVisible(notes) && h.system.focused == notes && sideDisplay.frame.contains(h.frame(notes)!))
    h.system.userFocus(s)
    #expect(!h.system.isVisible(notes) && h.controller.role(of: notes) == .stashed)
    // One that was sent away is named to be seen.
    runOK(h, "move-to-display 1 \(notes.rawValue)")
    #expect(h.system.isVisible(notes) && h.system.focused == notes && h.controller.role(of: notes) == nil)
    expectSound(h)
  }

  /// macOS has moved the keyboard where a command asked, and said so. A click in another app follows, of which no focus
  /// report comes (collab/evidence/ax-events.txt), and the next shortcut, all within half a second.
  @Test func aClickInAnotherAppAfterFocusHasArrivedIsBelieved() {
    for reported in [true, false] {
      let (h, w) = tilingScenario(["A", "B", "C"], ["dock $0 left", "dock $1 right", "dock $2 right"])
      h.system.userFocus(w[0])
      h.system.focusIsSlow = true
      runOK(h, "focus right")
      #expect(h.run("grow 10").message == "\(w[1]) grew", "macOS is not there yet, and the key is not lost")
      h.scheduler.advance(by: 0.05)
      h.system.focusIsSlow = false
      // Across apps macOS may only say that another app is in front.
      if reported { h.system.finishSlowFocus() } else { h.system.userSwitchesApp(to: w[1]) }
      h.scheduler.advance(by: 0.05)
      h.system.userSwitchesApp(to: w[0])
      #expect(h.run("grow 10").message == "\(w[0]) grew", "reported: \(reported)")
    }
  }

  /// Arbor sees no focused window while the keyboard is in a sheet, a panel or Spotlight. Commands that leave focus where it
  /// is leave it there too.
  @Test func theKeyboardStaysInASheet() {
    for command in ["balance", "balance all", "swap $0 $1", "swap $0 $3", "move-to-display next $2", "rotate", "mirror"] {
      let (h, w) = tilingScenario(
        ["A", "B", "M", "S"], ["dock $0 left", "dock $1 right", "dock $2 right", "resize $0 right 50", "move-to-display 2 $3", "dock $3 left"],
        displays: [FakeWindowSystem.standardDisplay, sideDisplay])
      h.system.setMinimized(w[2], true)
      h.system.userFocus(w[0])
      h.system.sheetTakesTheKeyboard()
      h.system.cursor = CGPoint(x: 300, y: 300)
      runOK(h, command, w)
      h.scheduler.advance(by: 1)
      #expect(h.system.focused == nil, "\(command) took the keyboard")
      expectSound(h)
    }
  }

  /// A key held down: a thousand of each. Sizes settle at their limits, the numbers in the tree stay numbers, and the window
  /// never becomes a tile, from which no key would bring it back.
  @Test(arguments: [CGSize.zero, CGSize(width: 300, height: 250)]) func aKeyHeldDownSettlesAtTheLimits(minimum: CGSize) {
    let (h, w) = tilingScenario(["A", "B", "C", "D"], ["dock $0 left", "dock $1 right", "dock $2 right", "dock $3 beside $1 down"])
    h.system.setMinimumSize(w[1], minimum)
    h.system.userFocus(w[1])
    for command in ["shrink", "grow", "shrink 7.3", "grow 3", "shrink 1000000", "grow 1000000", "shrink 0.001", "grow 0.001"] {
      var succeeded = 0
      for _ in 0..<1000 { succeeded += h.run(command).ok ? 1 : 0 }
      #expect(succeeded < 400, "\(command) never comes to an end")
      #expect(h.layout?.windowFrames[w[1]] != nil, "\(command) made a tile of the focused window")
      #expect(h.system.focused == w[1])
      #expect(h.frame(w[1])!.width >= max(minimum.width, h.controller.settings.minimumUsableWidth), "\(command)")
      #expect(h.frame(w[1])!.height >= max(minimum.height, h.controller.settings.minimumUsableHeight), "\(command)")
      #expect(weights(h).allSatisfy { $0.isFinite && $0 > 0.01 && $0 < 100 }, "\(command): \(weights(h))")
      #expect(h.workspace.tree.invariantViolations().isEmpty)
    }
    // And what a held key did, `balance` undoes.
    runOK(h, "balance all")
    #expect(h.layout?.tiles.isEmpty == true)
    expectSound(h)
  }

  /// What a key that repeats thirty times a second may ask of the window system (BudgetTests has no case for these).
  @Test(arguments: [12, 50]) func aRepeatingKeyDoesNothingTwiceOrForNothing(windows: Int) {
    for command in ["grow", "shrink", "focus right", "focus down", "focus next", "mirror", "balance", "focus left", "grow 1000000"] {
      let workload = Workload(windows: windows, grid: true)
      let h = workload.harness
      h.system.userFocus(workload.docked[0])
      h.scheduler.runPending()
      let budget = h.measure { h.run(command) }
      #expect(budget.waste == 0, "\(command) with \(windows) windows: \(budget)")
      #expect(budget.saves <= 1 && budget.overlayUpdates <= 1, "\(command) with \(windows) windows: \(budget)")
      if command.hasPrefix("focus") || command == "balance" { #expect(budget.moves == 0, "\(command): \(budget)") }
    }
  }

  /// The mouse holds a title bar while a shortcut rearranges: after the drop every window is in one place and can be seen.
  @Test(arguments: [
    "swap $0 right", "swap $0 $1", "swap $0 $3", "rotate", "mirror", "balance", "grow", "shrink", "move-to-display next $0", "move-to-display next",
    "focus right", "focus $2", "focus-display 2",
  ]) func aCommandDuringADragLosesNoWindow(command: String) {
    let (h, w) = tilingScenario(
      ["A", "B", "C", "S"], ["dock $0 left", "dock $1 right", "dock $2 beside $0 down", "move-to-display 2 $3", "dock $3 left"],
      displays: [FakeWindowSystem.standardDisplay, sideDisplay])
    h.system.userFocus(w[0])
    let frame = h.frame(w[0])!
    h.system.beginDrag(w[0], at: CGPoint(x: frame.midX, y: frame.minY + 10))
    h.system.moveDrag(to: CGPoint(x: 700, y: 400), holding: 0.4)
    var text = command
    for (index, window) in w.enumerated() { text = text.replacingOccurrences(of: "$\(index)", with: String(window.rawValue)) }
    _ = h.run(text)
    h.system.moveDrag(to: CGPoint(x: 720, y: 420), holding: 0.4)
    h.system.endDrag()
    h.scheduler.advance(by: 2)
    expectSound(h)
    #expect(h.controller.workspaces.values.flatMap(\.allWindows).sorted() == w.sorted())
    for window in w { #expect(h.system.isVisible(window), "\(window) is at \(h.frame(window)!)") }
  }

  /// The cable is pulled and Arbor has not heard yet. Nothing is lost, and everything goes home when the display is back.
  @Test(arguments: ["move-to-display 2 $0", "move-to-display 2 $2", "swap $0 $3", "focus-display 2", "focus right", "focus $3"])
  func aCommandForADisplayThatHasJustGoneLosesNoWindow(command: String) {
    let both = [FakeWindowSystem.standardDisplay, sideDisplay]
    let (h, w) = tilingScenario(["A", "B", "F", "S"], ["dock $0 left", "dock $1 right", "move-to-display 2 $3", "dock $3 left"], displays: both)
    h.system.userFocus(w[1])
    h.system.displayList = [FakeWindowSystem.standardDisplay]
    var text = command
    for (index, window) in w.enumerated() { text = text.replacingOccurrences(of: "$\(index)", with: String(window.rawValue)) }
    _ = h.run(text)
    for displays in [[FakeWindowSystem.standardDisplay], both] {
      h.system.setDisplays(displays)
      h.scheduler.advance(by: 5)
      expectSound(h)
      #expect(h.controller.workspaces.values.flatMap(\.allWindows).sorted() == w.sorted())
      for window in w where !h.controller.parked.contains(window) {
        #expect(h.system.isVisible(window), "\(window) is at \(h.frame(window)!) with \(displays.count) displays")
      }
    }
  }

  /// A laptop under its monitor, left edges in line: counted from the top, whatever the displays are called.
  @Test func displaysOneAboveTheOtherAreCountedFromTheTop() {
    let main = FakeWindowSystem.standardDisplay
    func display(_ id: String, y: CGFloat) -> DisplaySnapshot {
      let frame = CGRect(x: 0, y: y, width: 1440, height: 900)
      return DisplaySnapshot(id: DisplayID(id), frame: frame, visibleFrame: frame, isMain: false)
    }
    let (above, below) = (display("zenith", y: -900), display("abyss", y: 900))
    let (h, w) = tilingScenario(["A"], displays: [below, main, above])
    for (number, place) in [(1, above), (3, below), (2, main)] {
      runOK(h, "move-to-display \(number) $0", w)
      #expect(place.frame.contains(h.frame(w[0])!), "display \(number)")
    }
    runOK(h, "move-to-display next")
    #expect(below.frame.contains(h.frame(w[0])!))
    runOK(h, "move-to-display next")
    #expect(above.frame.contains(h.frame(w[0])!), "and round again")
  }

  /// A pinned window is passed over only when the view arrives somewhere (F49). In view, the keyboard can reach it like any other.
  @Test(arguments: [false, true]) func aPinnedWindowCanBeReachedFromTheKeyboard(makingWay: Bool) {
    let (h, w) = tilingScenario(
      ["A", "B", "Call"], ["dock $0 left", "dock $1 beside $0 down"], settings: makingWay ? .makingWay : Settings())
    // The docked windows have pushed it onto the Desktop. As Arbor ships they push nothing, and a hand takes it there.
    if !makingWay { h.system.userMove(w[2], to: CGRect(x: 900, y: 300, width: 400, height: 300)) }
    runOK(h, "pin $2", w)
    #expect(h.frame(w[2])!.minX > h.frame(w[0])!.maxX, "it floats on the Desktop, to the right")
    h.system.userFocus(w[0])
    runOK(h, "focus right")
    #expect(h.system.focused == w[2])
    h.system.userFocus(w[1])
    runOK(h, "focus next")
    #expect(h.system.focused == w[2])
    runOK(h, "focus next")
    #expect(h.system.focused == w[0])
  }

  // MARK: random

  /// `TilingRobustnessTests` with what it leaves out: displays that come and go (one of them at negative coordinates), names,
  /// summoned windows and absurd amounts; and stricter: the last layout is the layout, weights stay within bounds, what shows
  /// does not count as parked, what floats and is not parked can be seen, and nothing is remembered of windows that have left.
  @Test(arguments: Array<UInt64>(1...60)) func randomCommandsOnDisplaysThatComeAndGoKeepEverythingSound(seed: UInt64) {
    var random = SplitMix(seed: seed)
    var settings = Settings()
    settings.tabsEnabled = seed % 2 == 0
    settings.makeRoom = seed % 3 != 0
    let all = [FakeWindowSystem.standardDisplay, sideDisplay, upperDisplay]
    let h = Harness(displays: seed % 4 == 0 ? all : Array(all.prefix(2)), settings: settings)
    h.start()
    var open: [WindowID] = []
    var steps: [String] = []
    func int(_ n: Int) -> Int { Int.random(in: 0..<n, using: &random) }
    func pick() -> UInt32 { open.isEmpty ? 999 : open[int(open.count)].rawValue }
    func pickOpen() -> WindowID? { open.isEmpty ? nil : open[int(open.count)] }
    func isPresent(_ window: WindowID) -> Bool { h.system.windows[window]?.snapshot.isPresent == true }
    func direction() -> String { ["left", "right", "up", "down"][int(4)] }
    func amount() -> String { ["", " 1", " 0.001", " 40", " 333.3", " 5000", " 1000000"][int(7)] }
    func displayWord() -> String { ["next", "previous", "1", "2", "3", "4"][int(6)] }

    func problem() -> String? {
      for (display, workspace) in h.controller.workspaces.sorted(by: { $0.key < $1.key }) {
        let problems = workspace.tree.invariantViolations()
        if !problems.isEmpty { return "\(display): \(problems)" }
        if !workspace.tree.contains(workspace.camera) { return "\(display): the view is on \(workspace.camera), which is gone" }
        let referred = Array(workspace.savedViews.values) + Array((workspace.guests ?? [:]).values) + Array(workspace.names.values)
        for node in referred where !workspace.tree.contains(node) { return "\(display): something refers to \(node), which is gone" }
        for node in workspace.tree.preorder(from: workspace.tree.root) {
          let weight = workspace.tree[node]!.weight
          // The Desktop may be left with nothing, which is 0 to the digit. Nobody else may.
          if node == workspace.tree.desktop, weight == 0 { continue }
          if !(weight.isFinite && weight > 1e-6 && weight < 1e6) { return "\(display): \(node) weighs \(weight)" }
        }
        for window in (workspace.undockedFrames ?? [:]).keys.sorted() where !workspace.isDocked(window) {
          return "\(display): remembers the floating size of \(window), which is not docked here"
        }
        for (window, frame) in workspace.floating.sorted(by: { $0.key < $1.key }) {
          if !(frame.width >= 1 && frame.height >= 1 && frame.origin.x.isFinite && frame.origin.y.isFinite) {
            return "\(display): \(window) floats at \(frame)"
          }
        }
      }
      let places = h.controller.workspaces.values.flatMap(\.allWindows)
      if Set(places).count != places.count { return "a window is in two places: \(places.sorted())" }
      let known = Set(places.filter { h.system.windows[$0] != nil })
      if known != Set(open) { return "arranged: \(known.sorted()), open: \(open.sorted())" }
      let waiting = h.scheduler.pendingKeys.filter { $0.hasPrefix("space-") || $0.hasPrefix("enforce-") || $0.hasPrefix("landed-") || $0.hasPrefix("display") }
      guard waiting.isEmpty else { return nil }
      if let stale = h.staleLayouts().first { return stale }
      for (display, layout) in h.controller.layouts.sorted(by: { $0.key < $1.key }) {
        for (window, frame) in layout.windowFrames.sorted(by: { $0.key < $1.key }) {
          if h.controller.parked.contains(window) { return "\(display): \(window) shows and counts as parked" }
          if h.frame(window)?.approximatelyEquals(frame, tolerance: 2) != true {
            return "\(display): \(window) is at \(String(describing: h.frame(window))), its slot at \(frame)"
          }
        }
        for window in layout.hiddenWindows.sorted() where h.system.isVisible(window) { return "\(display): \(window) should be out of view" }
      }
      // A floating window that is present and not parked can be seen.
      for (display, workspace) in h.controller.workspaces.sorted(by: { $0.key < $1.key }) {
        for window in workspace.floating.keys.sorted()
        where isPresent(window) && !h.controller.parked.contains(window) && !h.system.isVisible(window)
          && h.system.windows[window]?.snapshot.isFullScreen != true
        {
          return "\(display): floating \(window) is not parked and cannot be seen, at \(String(describing: h.frame(window)))"
        }
      }
      return nil
    }

    for _ in 0..<220 {
      var line = ""
      switch int(40) {
      case 0, 1, 2:
        let place = h.system.displayList[int(h.system.displayList.count)].visibleFrame
        let minimum = int(4) == 0 ? CGSize(width: 700, height: 500) : .zero
        let app = "App\(int(5))"
        let id = h.system.open(
          app: app, frame: CGRect(x: place.minX + 200, y: place.minY + 100, width: 720, height: 520), minimumSize: minimum)
        open.append(id)
        steps.append("(open \(id) of \(app) at \(place.minX + 200), minimum \(minimum.width))")
      case 3:
        guard !open.isEmpty else { continue }
        let closed = open.remove(at: int(open.count))
        steps.append("(close \(closed))")
        h.system.close(closed)
      case 4:
        guard let id = pickOpen() else { continue }
        let minimized = Bool.random(using: &random)
        steps.append("(minimize \(id): \(minimized))")
        h.system.setMinimized(id, minimized)
      case 5:
        guard let id = pickOpen(), isPresent(id) else { continue }
        steps.append("(click \(id))")
        h.system.userFocus(id)
      case 6:
        guard let id = pickOpen(), let pid = h.system.windows[id]?.snapshot.pid else { continue }
        let hidden = Bool.random(using: &random)
        steps.append("(hide the app of \(id): \(hidden))")
        h.system.setHidden(pid: pid, hidden)
      case 7:
        // A display is unplugged, or comes back.
        let count = [1, 2, 2, 3][int(4)]
        let now = int(2) == 0 ? Array(all.prefix(count)) : [all[0]] + Array(all.suffix(count - 1))
        steps.append("(displays: \(now.map(\.id.rawValue)))")
        h.system.setDisplays(now)
        h.scheduler.advance(by: 3)
      case 8:
        let seconds = [0.1, 0.3, 1, 5][int(4)]
        steps.append("(\(seconds) s pass)")
        h.scheduler.advance(by: seconds)
      case 9:
        let frame = h.system.displayList[int(h.system.displayList.count)].frame
        h.system.cursor = CGPoint(x: frame.minX + CGFloat(int(Int(frame.width))), y: frame.minY + CGFloat(int(Int(frame.height))))
        steps.append("(pointer to \(h.system.cursor))")
      case 10: line = (Bool.random(using: &random) ? "save-view " : "view ") + String(1 + int(3))
      case 11: line = ["name one", "name two", "unname", "go one", "go two"][int(5)]
      case 12: line = "toggle-pin \(pick())"
      case 13: line = "summon App\(int(5))"
      case 14, 15, 16: line = "dock \(pick()) \(direction())"
      case 17: line = "arrange"
      case 18: line = "float \(pick())"
      case 19, 20: line = "dock \(pick()) beside \(pick()) \(direction())"
      case 21: line = ["show-all", "out", "in", "back", "desktop", "zoom \(pick())"][int(6)]
      case 22, 23, 24: line = "focus \(direction())"
      case 25: line = Bool.random(using: &random) ? "focus next" : "focus previous"
      case 26: line = "focus \(pick())"
      case 27, 28: line = "swap \(direction())"
      case 29, 30: line = "swap \(pick()) \(pick())"
      case 31: line = Bool.random(using: &random) ? "balance" : "balance all"
      case 32, 33: line = "rotate"
      case 34: line = "mirror"
      case 35: line = "grow\(amount())"
      case 36: line = "shrink\(amount())"
      case 37: line = "move-to-display \(displayWord())"
      case 38: line = "move-to-display \(displayWord()) \(pick())"
      default: line = "focus-display \(displayWord())"
      }
      if !line.isEmpty {
        let result = h.run(line)
        steps.append(line + (result.ok ? "" : "   -> " + result.message))
      }
      if let found = problem() {
        let picture = h.controller.perform(.ascii).text ?? ""
        Issue.record("seed \(seed): \(found)\n  \(steps.suffix(40).joined(separator: "\n  "))\n\(picture)")
        return
      }
    }
  }
}

/// SplitMix64, so the random test is reproducible.
private struct SplitMix: RandomNumberGenerator {
  var state: UInt64
  init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 &+ 17 }
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
