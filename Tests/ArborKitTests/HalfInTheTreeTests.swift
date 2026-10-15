import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Much of what a workspace holds lives half in the tree and half beside it: a saved view and the mark that keeps its
/// group, a name and its mark, a guest and its host, history and the nodes it lists. Commands that put another tree in
/// place (`layout`, `arrange`, `float-all`) or take the last thing out of a group have each lost one half at some time.
/// So: everything set up at once, random commands, and after each one the two halves must agree.
@MainActor @Suite struct HalfInTheTreeTests {
  private struct Random: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 }
    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }
  }

  /// What is wrong with `workspace`, in words.
  static func problems(in workspace: Workspace) -> [String] {
    var problems = workspace.tree.invariantViolations()
    let tree = workspace.tree
    if let data = try? JSONEncoder().encode(workspace), let read = try? JSONDecoder().decode(Workspace.self, from: data) {
      if read != workspace {
        var fields: [String] = []
        if read.tree != tree { fields.append("tree") }
        if read.camera != workspace.camera { fields.append("camera") }
        if read.back != workspace.back || read.forward != workspace.forward { fields.append("history") }
        if read.savedViews != workspace.savedViews { fields.append("savedViews") }
        if read.names != workspace.names { fields.append("names") }
        if read.guests != workspace.guests { fields.append("guests") }
        if read.floating != workspace.floating { fields.append("floating") }
        problems.append("does not read back equal: \(fields.isEmpty ? "something else" : fields.joined(separator: ", "))")
      }
    } else {
      problems.append("cannot be saved and read")
    }
    for (what, nodes) in [
      ("the view", [workspace.camera]), ("back", workspace.back), ("forward", workspace.forward),
      ("a saved view", Array(workspace.savedViews.values)), ("a name", Array(workspace.names.values)),
      ("a guest's host", Array((workspace.guests ?? [:]).values)),
    ] {
      for node in nodes where !tree.contains(node) { problems.append("\(what) is on \(node), which is gone") }
    }
    let namedGroups = Set(workspace.names.values.filter { tree.isSplit($0) })
    if Set(tree.kept(for: .name)) != namedGroups {
      problems.append("kept for a name: \(tree.kept(for: .name)); groups that have one: \(namedGroups.sorted())")
    }
    if Set(workspace.names.values).count != workspace.names.count { problems.append("a space has two names") }
    if workspace.back.last == workspace.camera || workspace.forward.last == workspace.camera {
      problems.append("history ends where the view is")
    }
    for window in (workspace.guests ?? [:]).keys where !workspace.isFloating(window) {
      problems.append("\(window) is a guest and does not float")
    }
    for window in workspace.pinnedWindows where !workspace.isFloating(window) {
      problems.append("\(window) is pinned and does not float")
    }
    for window in tree.allWindows where workspace.isFloating(window) { problems.append("\(window) is docked and floats") }
    return problems
  }

  @Test(arguments: Array<UInt64>(1...40)) func theTwoHalvesAgreeAfterEveryCommand(seed: UInt64) {
    var random = Random(seed: seed)
    var settings = Settings()
    settings.minimumUsableWidth = 60
    settings.minimumUsableHeight = 60
    settings.tabsEnabled = seed % 2 == 0
    let h = Harness(settings: settings)
    let apps = ["Alpha", "Beta", "Gamma", "Delta", "Echo"]
    for app in apps.prefix(3) { h.system.open(app: app) }
    h.start()
    var script: [String] = []
    let edges = ["left", "right", "top", "bottom"]
    let lines = [
      "Alpha | Beta | Desktop", "Alpha | (Beta / Gamma) | Desktop", "(Alpha / Beta) | Gamma", "Alpha* | Desktop",
      "Desktop", "Alpha | (Beta | Gamma) | Delta", "Gamma / (Alpha | Beta) / Desktop", "Echo | Delta",
    ]
    for _ in 0..<140 {
      let windows = h.system.allWindows().map(\.id.rawValue)
      let nodes = h.workspace.tree.preorder().map(\.rawValue)
      func window() -> UInt32 { windows.randomElement(using: &random) ?? 1 }
      let edge = edges.randomElement(using: &random)!
      let step: String
      switch Int.random(in: 0..<34, using: &random) {
      case 0, 1: step = "open \(apps.randomElement(using: &random)!)"
      case 2, 3: step = "close \(window())"
      case 4, 5, 6: step = "dock \(window()) \(edge)"
      case 7, 8, 9: step = "dock \(window()) beside \(window()) \(edge)"
      case 10: step = "float \(window())"
      case 11: step = "toggle-float \(window())"
      case 12: step = "arrange"
      case 13: step = "float-all"
      case 14, 15, 16: step = "layout \(lines.randomElement(using: &random)!)"
      case 17, 18: step = "zoom \(window())"
      case 19, 20: step = "zoom-node \(nodes.randomElement(using: &random)!)"
      case 21: step = "out"
      case 22: step = "show-all"
      case 23: step = "back"
      case 24: step = "forward"
      case 25, 26: step = "save-view \(Int.random(in: 1...3, using: &random))"
      case 27: step = "view \(Int.random(in: 1...3, using: &random))"
      case 28, 29: step = "name \(["Code", "Mail", "Talk"].randomElement(using: &random)!)"
      case 30: step = "unname"
      case 31: step = "pin \(window())"
      case 32: step = "summon \(apps.randomElement(using: &random)!)"
      default: step = "desktop"
      }
      script.append(step)
      let words = step.split(separator: " ")
      if words[0] == "open" {
        guard windows.count < 9 else { continue }
        h.system.open(app: String(words[1]))
      } else if words[0] == "close" {
        h.system.close(WindowID(UInt32(words[1])!))
      } else {
        h.run(step)
      }
      let problems = Self.problems(in: h.workspace)
      guard problems.isEmpty else {
        let what = problems.joined(separator: "; ")
        Issue.record("seed \(seed), after \(script.count) steps: \(what)\n\(script.joined(separator: "\n"))")
        return
      }
    }
  }

  // MARK: What the hunt found

  /// `layout --open` waits for an app. When its window came, a fresh tree was put in place of the old one, and
  /// a fresh tree has no marks: the name stayed and its group was no longer kept for it.
  @Test func aGroupNamedWhileALayoutWaitsIsStillKeptWhenTheWindowComes() throws {
    let h = Harness()
    let ids = ["Alpha", "Beta", "Gamma"].map { h.system.open(app: $0) }
    h.start()
    h.run("layout --open Yankee | (Alpha / Beta) | Gamma")
    let pair = try #require(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: ids[0])!))
    h.run("zoom-node \(pair.rawValue)")
    h.run("name Pair")
    h.run("save-view 1")
    h.run("show-all")
    let late = h.system.open(app: "Yankee")
    #expect(h.workspace.isDocked(late), "it took its place")
    #expect(Self.problems(in: h.workspace) == [])
    let named = try #require(h.workspace.names["Pair"])
    #expect(h.workspace.tree.windows(under: named) == [ids[0], ids[1]] && h.workspace.tree.isKeptFirmly(named))
    #expect(h.workspace.savedView(slot: 1) == named)
    // What a name is for: the group survives down to one window.
    h.system.close(ids[0])
    #expect(h.workspace.names["Pair"] == named && h.workspace.tree.isSplit(named))
  }

  /// A window that opens during a hold beside a window of its app that is out of view is kept out, and comes in when the view
  /// of its display next moves. On a display where nothing is docked no view can move, and `float-all` let in what
  /// waited only while the hold was still on: after `release` the window stayed in the corner whatever was asked for, and
  /// Arbor answered "showing everything". Both scripts were found and shrunk by the hunt on the commit frozen at 15:59 UTC
  /// on 2026-10-14 (K2028).
  @Test(arguments: [
    (
      true,
      [
        "displays main", "open Echo at 2112,60", "open Yankee at 2490,477", "minimize w103", "close w101", "minimize w102",
        "open Echo at 2018,786", "open Delta at 365,78", "close w104", "close w105", "minimize w106",
        "open Yankee at 1848,235", "arrange all", "float 108", "zoom 106", "hold", "open Delta at 2666,721",
        "drag w107 to 770,771",
      ]
    ),
    (
      false,
      [
        "open Yankee at 2232,102", "open Gamma at 1984,481", "open Yankee at 574,111", "open Echo at 115,568",
        "dock 107 top", "drag w106 to 791,380", "open Alpha at 349,440", "dock 101 beside 107 right",
        "open Delta at 538,392", "float-all here", "open Delta at 2304,60", "dock 107 top", "zoom 110",
        "layout Alpha | Beta | Desktop", "zoom 108", "undo", "hold", "open Echo at 1242,543",
      ]
    ),
  ]) func whatAHoldKeptOutIsWithinReachWhenEverythingIsLetGoOf(tight: Bool, script: [String]) {
    #expect(Self.outcome(of: script + ["ways-back"], tabs: true, tight: tight) == [])
  }

  /// Somebody with two displays: Mail is docked on the main one and out of view, and Mail opens a window that lands on the other.
  /// With `hold`, the command that holds, or nil for none. With `docked`, something is docked on the other display too.
  private func lateMail(hold: String?, docked: Bool) -> (h: Harness, mail: WindowID, late: WindowID) {
    let h = Harness(displays: [Self.main, Self.side])
    let mail = h.system.open(app: "Mail", pid: 2001)
    let slides = h.system.open(app: "Slides", pid: 2002)
    let notes = h.system.open(app: "Notes", pid: 2003, frame: CGRect(x: 1700, y: 200, width: 500, height: 350))
    h.start()
    if docked {
      h.system.cursor = CGPoint(x: Self.side.frame.midX, y: Self.side.frame.midY)
      h.run("dock \(notes.rawValue) left")
    }
    h.system.cursor = CGPoint(x: Self.main.frame.midX, y: Self.main.frame.midY)
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(slides.rawValue) right")
    h.run("zoom \(slides.rawValue)")
    if let hold { h.run(hold) }
    // Mostly off every screen, as an app opens a window beside one of its own that is in a corner.
    let late = h.system.open(app: "Mail", pid: 2001, frame: CGRect(x: 2700, y: 780, width: 500, height: 350))
    h.scheduler.advance(by: 2)
    return (h, mail, late)
  }

  private func isWithinReach(_ window: WindowID, _ h: Harness) -> Bool {
    guard let frame = h.frame(window) else { return false }
    return [Self.main, Self.side].contains {
      let part = $0.visibleFrame.intersection(frame)
      return part.width >= 40 && part.height >= 5
    }
  }

  /// Each way of asking for everything, by itself, after a release that is real: ⌃⌥0, ⌃⌥Space, ⌃⌥⇧F, ⌃⌥D. Whichever hold it
  /// was, whether or not anything is docked on the window's display, and wherever the pointer is.
  @Test(arguments: ["home", "show-all", "float-all", "desktop"], ["hold", "hold still"])
  func eachWayOfAskingForEverythingFetchesWhatAHoldKeptOut(way: String, hold: String) {
    for docked in [false, true] {
      for pointer in [Self.main, Self.side] {
        let (h, mail, late) = lateMail(hold: hold, docked: docked)
        let what = "\(docked ? "something" : "nothing") docked there, the pointer on \(pointer.id)"
        #expect(h.controller.workspaces[Self.side.id]?.isFloating(late) == true, "it belongs to the other display")
        #expect(!isWithinReach(late, h), "kept out during the hold; \(what)")
        if hold == "hold" { #expect(h.run("zoom \(mail.rawValue)").ok == false, "the hold is real") }
        #expect(h.run("release").ok)
        #expect(!isWithinReach(late, h), "the end of a hold brings nothing in by itself; \(what)")
        h.system.cursor = CGPoint(x: pointer.frame.midX, y: pointer.frame.midY)
        h.run(way)
        h.scheduler.advance(by: 2)
        #expect(isWithinReach(late, h), "`\(way)` after `\(hold)` left it at \(h.frame(late)!); \(what)")
        #expect(h.run("zoom \(mail.rawValue)").ok, "and the hold is over")
      }
    }
  }

  /// The same by the keys themselves. A pressed ⌃⌥Space is not the command: it begins a peek, which takes `show-all`'s place.
  /// Tapped, and held for two seconds and let go; wherever the pointer is, as for the commands.
  @Test(arguments: ["ctrl+opt+0", "ctrl+opt+space", "ctrl+opt+shift+f", "ctrl+opt+d"], [false, true])
  func eachKeyFetchesWhatAHoldKeptOut(key: String, docked: Bool) {
    for seconds in key == "ctrl+opt+space" ? [0, 2.0] : [0] {
      for pointer in [Self.main, Self.side] {
        let (h, _, late) = lateMail(hold: "hold", docked: docked)
        h.run("release")
        h.system.cursor = CGPoint(x: pointer.frame.midX, y: pointer.frame.midY)
        #expect(!isWithinReach(late, h))
        h.keyDown(key)
        h.scheduler.advance(by: seconds)
        h.keyUp(key)
        h.scheduler.advance(by: 2)
        #expect(
          isWithinReach(late, h), "\(key), down for \(seconds) s, the pointer on \(pointer.id), left it at \(h.frame(late)!)")
        expectWindowsMatchLayout(h)
      }
    }
  }

  @Test(arguments: ["ctrl+opt+0", "ctrl+opt+space", "ctrl+opt+d"], ["hold", "hold still"])
  func duringAHoldNoKeyLetsInWhatWaits(key: String, hold: String) {
    for seconds in key == "ctrl+opt+space" ? [0, 2.0] : [0] {
      let (h, _, late) = lateMail(hold: hold, docked: false)
      h.system.cursor = CGPoint(x: Self.side.frame.midX, y: Self.side.frame.midY)
      h.keyDown(key)
      h.scheduler.advance(by: seconds)
      h.keyUp(key)
      h.scheduler.advance(by: 2)
      #expect(!isWithinReach(late, h), "\(key), down for \(seconds) s during `\(hold)`, let it in at \(h.frame(late)!)")
      expectWindowsMatchLayout(h)
    }
  }

  /// As somebody met it who read only the guide: a laptop with Mail and Safari docked and Mail framed, a large display beside it
  /// with nothing docked, the view held for a call. Safari opens a page, the call ends, and ⌃⌥0 did not show the page.
  @Test(arguments: ["home", "float-all"]) func thePageThatOpenedDuringTheCallComesWhenEverythingIsAskedFor(way: String) {
    let laptop = DisplaySnapshot(
      id: DisplayID("laptop"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
      visibleFrame: CGRect(x: 0, y: 25, width: 1728, height: 1092), isMain: true)
    let large = DisplaySnapshot(
      id: DisplayID("large"), frame: CGRect(x: 1728, y: -323, width: 2560, height: 1440),
      visibleFrame: CGRect(x: 1728, y: -298, width: 2560, height: 1415), isMain: false)
    let h = Harness(displays: [laptop, large])
    let mail = h.system.open(app: "Mail", pid: 1101)
    let safari = h.system.open(app: "Safari", pid: 1102)
    h.start()
    h.system.cursor = CGPoint(x: 800, y: 500)
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.run("zoom \(mail.rawValue)")
    h.run("hold")
    let page = h.system.open(app: "Safari", pid: 1102, frame: CGRect(x: 1749, y: 1107, width: 1000, height: 700))
    h.scheduler.advance(by: 2)
    #expect(h.run("zoom \(safari.rawValue)").ok == false, "the hold is real")
    h.run("release")
    h.run(way)
    h.scheduler.advance(by: 2)
    let frame = h.frame(page)!
    let shows = [laptop, large].contains {
      let part = $0.visibleFrame.intersection(frame)
      return part.width >= 40 && part.height >= 5
    }
    #expect(shows, "`\(way)` left the page at \(frame)")
    expectWindowsMatchLayout(h)
  }

  /// `float-all here` is about one display: the one under the pointer.
  @Test(arguments: [false, true]) func floatAllHereFetchesWhatWaitedOnItsOwnDisplay(docked: Bool) {
    let (h, _, late) = lateMail(hold: "hold", docked: docked)
    h.run("release")
    h.run("float-all here")
    h.scheduler.advance(by: 2)
    #expect(!isWithinReach(late, h), "the pointer is on the main display, and the window waits on the other")
    h.system.cursor = CGPoint(x: Self.side.frame.midX, y: Self.side.frame.midY)
    h.run("float-all here")
    h.scheduler.advance(by: 2)
    #expect(isWithinReach(late, h))
  }

  /// While the view is held, asking shows an audience nothing new. (`float-all` is a way out of the hold, and meant.)
  @Test(arguments: ["home", "show-all", "desktop"], [false, true])
  func duringAHoldNothingThatWaitsComesIn(way: String, docked: Bool) {
    for pointer in [Self.main, Self.side] {
      let (h, _, late) = lateMail(hold: "hold", docked: docked)
      h.system.cursor = CGPoint(x: pointer.frame.midX, y: pointer.frame.midY)
      h.run(way)
      h.scheduler.advance(by: 2)
      #expect(!isWithinReach(late, h), "`\(way)` with the pointer on \(pointer.id) let it in at \(h.frame(late)!)")
    }
  }

  /// Dialogs wait with a held view too, and `float-all` lets them in: also when no window was kept out, and when nothing is
  /// docked, so that no view moves and `float-all` itself has nothing to do.
  @Test(arguments: [false, true]) func floatAllLetsWaitingDialogsInThoughNoWindowWaits(docked: Bool) {
    let h = Harness()
    let (a, b) = (h.system.open(app: "A", pid: 2001), h.system.open(app: "B", pid: 2002))
    h.start()
    if docked {
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) right")
      h.run("zoom \(b.rawValue)")
    }
    #expect(h.run("hold").ok)
    h.system.openStrayDialog(ofApp: "com.example.a")
    #expect(h.system.strayDialogsWaiting() == 1, "it waits while the view is held")
    h.run("float-all")
    #expect(h.system.strayDialogsWaiting() == 0)
  }

  /// The control: without a hold the window is brought into view as it opens, as ever.
  @Test(arguments: [false, true]) func withoutAHoldTheWindowIsInViewAtOnce(docked: Bool) {
    let (h, _, late) = lateMail(hold: nil, docked: docked)
    #expect(isWithinReach(late, h))
  }

  // MARK: Wider: two displays that come and go, drags, gaps, waiting slots, time, a pause

  private static let main = FakeWindowSystem.standardDisplay
  private static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

  /// What is wrong with everything the controller holds.
  static func problems(in h: Harness) -> [String] {
    let c = h.controller
    var problems: [String] = []
    for (display, workspace) in c.workspaces.sorted(by: { $0.key < $1.key }) {
      problems += Self.problems(in: workspace).map { "\(display): \($0)" }
      if let layout = c.layouts[display] {
        if !workspace.tree.contains(layout.camera) { problems.append("\(display): the layout's view \(layout.camera) is gone") }
        for node in layout.nodeFrames.keys.sorted() where !workspace.tree.contains(node) {
          problems.append("\(display): the layout has \(node), which is gone")
        }
      }
    }
    for (display, dormant) in c.dormant.sorted(by: { $0.key < $1.key }) {
      problems += Self.problems(in: dormant.workspace).map { "\(display), remembered: \($0)" }
    }
    guard c.isRunning, !c.workspaces.isEmpty else { return problems }
    for state in c.snapshot().windows {
      let homes = c.workspaces.filter { $0.value.contains(state.id) }.keys.sorted()
      if homes.count > 1 { problems.append("\(state.id) is on \(homes)") }
      if homes.isEmpty, state.managed { problems.append("\(state.id) is in no workspace") }
    }
    return problems
  }

  /// A session as lines of text, so that one that fails can be replayed and shrunk.
  @MainActor final class Session {
    let h: Harness
    private(set) var problems: [String] = []

    /// With `tight`, slots are soon too small: the default smallest usable size, and windows that will not go below a
    /// size of their own, each app in its own process. So windows become tiles, and room is made for them (F61).
    let tight: Bool

    init(tabs: Bool, tight: Bool = false) {
      self.tight = tight
      var settings = Settings()
      if !tight {
        settings.minimumUsableWidth = 60
        settings.minimumUsableHeight = 60
      }
      settings.tabsEnabled = tabs
      h = Harness(displays: [HalfInTheTreeTests.main, HalfInTheTreeTests.side], settings: settings)
      for app in ["Alpha", "Beta", "Gamma"] { h.system.open(app: app) }
      h.start()
    }

    /// Does what `step` says and notes what is wrong afterwards. A step that makes no sense now does nothing.
    func apply(_ step: String) {
      let words = step.split(separator: " ").map(String.init)
      func window(_ word: String) -> WindowID? { UInt32(word.drop { $0 == "w" }).map { WindowID($0) } }
      func point(_ word: String) -> CGPoint? {
        let parts = word.split(separator: ",").compactMap { Double($0) }
        return parts.count == 2 ? CGPoint(x: parts[0], y: parts[1]) : nil
      }
      let windows = h.system.allWindows().map(\.id)
      let before = h.controller.workspaces
      let keyboardBefore = h.system.focusedWindow()
      var leaving: WindowID?
      switch words[0] {
      case "open":
        guard let at = point(words[3]) else { return }
        let letter = Int(words[1].unicodeScalars.first!.value)
        h.system.open(
          app: words[1], pid: tight ? Int32(1000 + letter) : 1000,
          frame: CGRect(origin: at, size: CGSize(width: 400, height: 300)),
          minimumSize: tight ? CGSize(width: 150 + (letter % 5) * 90, height: 100 + (letter % 3) * 120) : .zero)
      case "close":
        guard let w = window(words[1]), windows.contains(w) else { return }
        leaving = w
        h.system.close(w)
      case "drag":
        guard let w = window(words[1]), let frame = h.frame(w), let to = point(words[3]) else { return }
        h.system.drag(
          w, through: [CGPoint(x: frame.midX, y: frame.minY + 10), CGPoint(x: (frame.midX + to.x) / 2, y: to.y), to])
      case "gap":
        let display = DisplayID(words[3])
        guard let seam = h.controller.layouts[display]?.seams.first(where: { "\($0.leading)|\($0.trailing)" == words[1] }),
          let by = Double(words[5])
        else { return }
        h.overlays.dragSeam(seam, by: CGFloat(by), on: display)
      case "pointer":
        guard let to = point(words[1]) else { return }
        h.system.cursor = to
      case "minimize", "restore":
        guard let w = window(words[1]), windows.contains(w) else { return }
        h.system.setMinimized(w, words[0] == "minimize")
      case "wait": h.scheduler.advance(by: Double(words[1]) ?? 0)
      case "ways-back":
        // Whatever happened: both displays there, Arbor at work, nothing held, and everything let go of.
        h.system.setDisplays([HalfInTheTreeTests.main, HalfInTheTreeTests.side])
        h.scheduler.advance(by: 5)
        h.run("resume")
        h.run("release")
        let reply = h.run("float-all").message
        h.scheduler.advance(by: 5)
        problems = HalfInTheTreeTests.problems(in: h)
        let screens = h.system.displays().map(\.visibleFrame)
        for window in h.system.allWindows() where window.isPresent {
          let seen = screens.contains { screen in
            let part = screen.intersection(window.frame)
            return part.width >= 40 && part.height >= 5
          }
          if !seen {
            problems.append("a window is out of reach after float-all [\(window.id) at \(window.frame); \(reply)]")
          }
        }
        return
      case "displays":
        h.system.setDisplays(
          words.dropFirst().compactMap { $0 == "main" ? HalfInTheTreeTests.main : $0 == "side" ? HalfInTheTreeTests.side : nil })
      default:
        if words[0] == "float", words.count > 1 { leaving = window(words[1]) }
        h.run(step)
      }
      problems = HalfInTheTreeTests.problems(in: h)
      guard let leaving else { return }
      // F62: whatever leaves, a view or a saved view on a group goes on showing the rest of it and nothing else.
      func views(_ w: Workspace) -> [(what: String, node: NodeID)] {
        [("the view", w.camera)] + w.savedViews.sorted { $0.key < $1.key }.map { ("view \($0.key)", $0.value) }
      }
      for (display, old) in before.sorted(by: { $0.key < $1.key }) {
        guard let w = h.controller.workspaces[display], views(old).map(\.what) == views(w).map(\.what) else { continue }
        for (then, now) in zip(views(old), views(w)) {
          let shown = Set(old.tree.windows(under: then.node))
          let rest = shown.subtracting([leaving])
          // Only if it has really left: a command can be refused, and the slot of a window that closed can wait for the next.
          // And only if something of the rest can be seen: with nothing in view the controller steps out, on purpose.
          let present = Set(h.system.allWindows().filter(\.isPresent).map(\.id))
          guard shown.contains(leaving), !rest.isDisjoint(with: present),
            !old.tree.subtree(then.node, contains: old.tree.desktop), !w.isDocked(leaving),
            w.tree.allWindows.allSatisfy({ windows.contains($0) })
          else { continue }
          // Floating the framed window shows the Desktop, on purpose.
          if then.what == "the view", words[0] == "float" { continue }
          let after = Set(w.tree.windows(under: now.node))
          guard after != rest else { continue }
          var model = old
          model.forget(leaving)
          problems.append(
            "\(display): \(then.what) showed \(shown.sorted()), \(leaving) left, and it shows \(after.sorted())"
              + " [the model alone: \(then.what == "the view" ? model.tree.windows(under: model.camera) : []); keyboard "
              + "\(keyboardBefore.map { "\($0)" } ?? "nowhere") -> \(h.system.focusedWindow().map { "\($0)" } ?? "nowhere")]")
        }
      }
    }
  }

  /// The kind of a problem: its text without the numbers.
  static func kind(_ problems: [String]) -> String {
    problems.first.map { $0.prefix { $0 != "[" }.filter { !$0.isNumber } } ?? ""
  }

  /// What is wrong at the end of `script`, if everything before it went well.
  static func outcome(of script: [String], tabs: Bool, tight: Bool = false) -> [String] {
    let session = Session(tabs: tabs, tight: tight)
    for step in script {
      session.apply(step)
      if !session.problems.isEmpty { return step == script.last ? session.problems : [] }
    }
    return []
  }

  /// The shortest script found, by leaving out one step after another, that ends in the same kind of problem.
  static func shrunk(_ script: [String], tabs: Bool, tight: Bool = false) -> [String] {
    let wanted = kind(outcome(of: script, tabs: tabs, tight: tight))
    var script = script
    var changed = true
    while changed {
      changed = false
      for index in script.indices.dropLast().reversed() {
        var shorter = script
        shorter.remove(at: index)
        if kind(outcome(of: shorter, tabs: tabs, tight: tight)) == wanted {
          script = shorter
          changed = true
        }
      }
    }
    return script
  }

  /// Commands of features that may or may not have landed. Those the parser knows are used, so that the hunt takes in
  /// a new feature the day it arrives. Whoever adds a command that changes an arrangement or a view adds it here.
  static let later: [String] = [
    "undo", "undo", "undo", "redo", "preset save Desk", "preset load Desk", "preset load Desk --open", "preset delete Desk",
    "rotate", "rotate", "mirror", "equalize", "swap left", "swap right", "swap top", "swap bottom", "grow 60", "shrink 60",
    "focus left", "focus right", "move-to-display next", "focus-display next", "hold", "release", "toggle-hold", "carry",
    "drop", "cancel", "next-display", "toggle-auto-dock",
  ].filter { (try? Command.parse($0)) != nil }

  @Test(arguments: Array<UInt64>(1...40)) func alsoOnTwoDisplaysWithDragsGapsAndWaitingSlots(seed: UInt64) {
    var random = Random(seed: seed)
    let tight = seed % 3 == 0
    let session = Session(tabs: seed % 2 == 0, tight: tight)
    let h = session.h
    let apps = ["Alpha", "Beta", "Gamma", "Delta", "Echo"]
    var script: [String] = []
    let edges = ["left", "right", "top", "bottom"]
    let lines = [
      "Alpha | Beta | Desktop", "Alpha | (Beta / Gamma) | Desktop", "--open Alpha | Zulu | Desktop", "@2 Beta | Gamma",
      "--open (Yankee / Alpha) | Beta", "Alpha | (Beta | Gamma) | Delta", "Desktop",
    ]
    func point() -> String { "\(Int.random(in: 2...2715, using: &random)),\(Int.random(in: 27...795, using: &random))" }
    for _ in 0..<140 {
      let windows = h.system.allWindows().map(\.id)
      func window() -> UInt32 { (windows.randomElement(using: &random) ?? WindowID(1)).rawValue }
      let edge = edges.randomElement(using: &random)!
      let step: String
      switch Int.random(in: 0..<(Self.later.isEmpty ? 40 : 48), using: &random) {
      case 40...: step = Self.later.randomElement(using: &random)!
      case 0, 1:
        guard windows.count < 9 else { continue }
        step = "open \((apps + ["Zulu", "Yankee"]).randomElement(using: &random)!) at \(point())"
      case 2, 3: step = "close w\(window())"
      case 4, 5, 6: step = "dock \(window()) \(edge)"
      case 7, 8, 9: step = "dock \(window()) beside \(window()) \(edge)"
      case 10, 11: step = "float \(window())"
      case 12: step = "arrange all"
      case 13: step = "float-all here"
      case 14, 15, 16: step = "layout \(lines.randomElement(using: &random)!)"
      case 17, 18: step = "zoom \(window())"
      case 19, 20:
        let nodes = h.controller.workspaces.sorted { $0.key < $1.key }.flatMap { $0.value.tree.preorder() }
        step = "zoom-node \(nodes.randomElement(using: &random)?.rawValue ?? 0)"
      case 21: step = ["out", "in", "show-all", "home", "desktop"].randomElement(using: &random)!
      case 22: step = ["back", "forward"].randomElement(using: &random)!
      case 23, 24: step = "save-view \(Int.random(in: 1...3, using: &random))"
      case 25: step = "view \(Int.random(in: 1...3, using: &random))"
      case 26, 27: step = "name \(["Code", "Mail", "Talk"].randomElement(using: &random)!)"
      case 28: step = ["unname", "go Code", "go Mail"].randomElement(using: &random)!
      case 29: step = "pin \(window())"
      case 30: step = "summon \(apps.randomElement(using: &random)!)"
      case 31, 32, 33: step = "drag w\(window()) to \(point())"
      case 34:
        guard let (display, layout) = h.controller.layouts.sorted(by: { $0.key < $1.key }).randomElement(using: &random),
          let seam = layout.seams.randomElement(using: &random)
        else { continue }
        step = "gap \(seam.leading)|\(seam.trailing) on \(display) by \(Int.random(in: -200...200, using: &random))"
      case 35: step = "pointer \(point())"
      case 36:
        let w = window()
        let minimized = h.system.allWindows().first { $0.id.rawValue == w }?.isMinimized ?? false
        step = "\(minimized ? "restore" : "minimize") w\(w)"
      case 37: step = "wait \([0.3, 1, 5, 200].randomElement(using: &random)!)"
      case 38: step = "displays \(["main side", "main", "main side", ""].randomElement(using: &random)!)"
      default: step = ["pause", "resume", "resume"].randomElement(using: &random)!
      }
      script.append(step)
      session.apply(step)
      guard session.problems.isEmpty else {
        let short = Self.shrunk(script, tabs: seed % 2 == 0, tight: tight)
        let what = Self.outcome(of: short, tabs: seed % 2 == 0, tight: tight).joined(separator: "; ")
        let how = "seed \(seed)\(tight ? ", tight" : ""), \(script.count) steps shrunk to \(short.count)"
        Issue.record("\(how): \(what)\n\(short.joined(separator: "\n"))")
        return
      }
    }
    script.append("ways-back")
    session.apply("ways-back")
    if !session.problems.isEmpty {
      let short = Self.shrunk(script, tabs: seed % 2 == 0, tight: tight)
      let what = Self.outcome(of: short, tabs: seed % 2 == 0, tight: tight).joined(separator: "; ")
      let how = "seed \(seed)\(tight ? ", tight" : ""), \(script.count) steps shrunk to \(short.count)"
      Issue.record("\(how): \(what)\n\(short.joined(separator: "\n"))")
    }
  }
}
