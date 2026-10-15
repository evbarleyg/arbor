import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// IS THE RACE OF BOARD 1.89 (N19) STILL REACHABLE? Every road that a reading of the controller gave, told at storey two.
//
// The race: inside ONE act Arbor asks for the keyboard twice. First for a window it picks itself, of ANOTHER app, because the window that had the keyboard goes out of view with the move of the view
// (`ensureFocusIsVisible`); then for the window its person named, of the app that is still named as in front, so that the layer's `focus` spares `activate()`. The other app's activation lands last.
//
// Each road: apps on time, 50 ms late, 200 ms late (`carriesOutAfter`); with B's window and, THE CONTROL, without it. Lines of the account that begin with "·" are what was found at the end.

@MainActor private func found(_ text: String) { FakeMac.current.note("· \(text)") }

/// App A ("Alpha") in front with the keyboard in its docked window, which fills the view; A and B ("Beta") each have a floating window, out of view with the Desktop.
@MainActor
private final class Floats {
  let two: StoreyTwo
  var docked: FakeMac.Window!, floating: FakeMac.Window!, others: FakeMac.Window?
  var display: DisplayID { two.controller.displays[0].id }

  /// `othersUsedLast`: of the two floating windows B's was used after A's, which is what makes Arbor pick it.
  /// `before`: what is done between the clicks on the floating windows and the zoom.
  init(_ story: Story, withB: Bool, late: TimeInterval, othersUsedLast: Bool = true, zoomed: Bool = true, before: (StoreyTwo) -> Void = { _ in }) {
    var docked: FakeMac.Window!, floating: FakeMac.Window!, others: FakeMac.Window?
    two = StoreyTwo(story) { mac in
      let a = mac.launch("Alpha")
      docked = mac.open("docked", in: a, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
      floating = mac.open("floating", in: a, frame: CGRect(x: 640, y: 420, width: 300, height: 220))
      if withB { others = mac.open("others", in: mac.launch("Beta"), frame: CGRect(x: 640, y: 80, width: 300, height: 220)) }
    }
    (self.docked, self.floating, self.others) = (docked, floating, others)
    two.run("dock \(docked.number) left")
    for window in othersUsedLast ? [floating, others] : [others, floating] {
      guard let window else { continue }
      two.mac.click(window)
      two.mac.pass(1)
    }
    before(two)
    two.mac.press(at: CGPoint(x: docked.bounds.minX + 60, y: docked.bounds.maxY - 60))
    two.mac.pass(0.08)
    two.mac.release()
    two.mac.pass(1)
    if zoomed { two.run("zoom \(docked.number)", then: 2) }
    let away = [floating, others].compactMap { $0 }
    story.check(
      "the stage: A is in front, its docked window has the keyboard\(zoomed ? " and fills the view, what floats is out of view" : "")",
      two.mac.frontmost === docked.app && two.mac.keyWindow === docked && (!zoomed || away.allSatisfy { two.isOutOfView($0) }),
      "w\(two.mac.keyWindow?.number ?? 0) has it; " + ([docked] + away).map { two.whereabouts($0) }.joined(separator: "; "))
    for app in Set(([docked] + away).map { ObjectIdentifier($0.app) }) { ([docked] + away).first { ObjectIdentifier($0.app) == app }?.app.carriesOutAfter = late }
  }
}

/// What every road is held to at its end. `named`: the window its person named, if the act names one.
@MainActor
private func judge(_ story: Story, _ two: StoreyTwo, named: FakeMac.Window?, all: [FakeMac.Window], since: Int) {
  let key = two.mac.keyWindow
  let forward = two.mac.journal.dropFirst(since).filter { $0.contains("comes forward") }.map { $0.trimmingCharacters(in: .whitespaces) }
  found("in front: \(two.mac.frontmost?.name ?? "nobody"); the keyboard: w\(key?.number ?? 0); Arbor believes: \(two.controller.keyboardFocus().map { "w\($0.rawValue)" } ?? "nobody"); the ring: \(two.ring.map { "w\($0)" } ?? "none")")
  found(all.map { two.whereabouts($0) }.joined(separator: "; "))
  found("who came forward since the act: \(forward.isEmpty ? "nobody" : forward.joined(separator: " | "))")
  if let named {
    story.check("the window that was named is in view", two.isInView(named), two.whereabouts(named))
    story.check("and has the keyboard", key === named, "w\(key?.number ?? 0) has it, of \(key?.app.name ?? "nobody")")
  }
  story.check("the window with the keyboard is in view", key.map { two.isInView($0) } ?? false, key.map { two.whereabouts($0) } ?? "nobody has it")
  story.check("the keyboard is where Arbor believes it", two.controller.keyboardFocus()?.rawValue == key?.number, "Arbor: \(two.controller.keyboardFocus().map { "w\($0.rawValue)" } ?? "nobody"), the Mac: w\(key?.number ?? 0)")
}

private let manners: [(words: String, late: TimeInterval)] = [("apps on time", 0), ("apps 50 ms late", 0.05), ("apps 200 ms late", 0.2)]

@MainActor
func tellOfTheRoadsOfN19(_ book: Book) {
  // MARK: Family 1. From a view that a docked window of A fills, to A's floating window

  /// (name, names the floating window?, what is done before the zoom, the act)
  let roads: [(name: String, names: Bool, before: @MainActor (StoreyTwo) -> Void, act: @MainActor (Floats) -> Void)] = [
    ("01 the menu's row of the window (`reveal`)", true, { _ in }, { $0.two.run("reveal \($0.floating.number)", then: 5) }),
    (
      "02 Go to…, Return on the window", true, { _ in },
      {
        $0.two.run("find", then: 0.5)
        $0.two.mac.note("Return on the row of w\($0.floating.number)")
        $0.two.controller.finderChose(.window(WindowID($0.floating.number)))
        $0.two.mac.pass(5)
      }
    ),
    ("03 `focus <window>`", true, { _ in }, { $0.two.run("focus \($0.floating.number)", then: 5) }),
    ("04 `zoom <window>`, the fill", true, { _ in }, { $0.two.run("zoom \($0.floating.number)", then: 5) }),
    ("05 `summon` of app A", false, { _ in }, { $0.two.run("summon Alpha", then: 5) }),
    (
      "06 cmd-backtick to the window", true, { _ in },
      {
        $0.two.mac.personAsksAppInFront(for: $0.floating)
        $0.two.mac.pass(5)
      }
    ),
    (
      "17 cmd-Tab, or a click in the Dock, to app B", false, { _ in },
      {
        if let others = $0.others { $0.two.mac.activate(others.app) }
        $0.two.mac.pass(5)
      }
    ),
    ("07 the Desktop's key (`desktop`)", false, { _ in }, { $0.two.run("desktop", then: 5) }),
    ("08 `back` to the Desktop", false, { $0.run("desktop", then: 1) }, { $0.two.run("back", then: 5) }),
    (
      "09 `forward` to the Desktop", false, { _ in },
      {
        $0.two.run("desktop", then: 2)
        $0.two.run("back", then: 2)
        // Whoever got the keyboard on the Desktop: the person is back in the docked window.
        $0.two.mac.click($0.docked)
        $0.two.mac.pass(1)
        $0.two.run("forward", then: 5)
      }
    ),
    ("10 `show-all`", false, { _ in }, { $0.two.run("show-all", then: 5) }),
    ("11 `out`", false, { _ in }, { $0.two.run("out", then: 5) }),
    (
      "12 the menu's row of the window, which lies in the Dock", true,
      { _ in },
      {
        // Sent there from where it stands, out of view.
        $0.two.mac.minimize($0.floating)
        $0.two.mac.pass(2)
        $0.two.mac.click($0.docked)
        $0.two.mac.pass(1)
        $0.two.run("reveal \($0.floating.number)", then: 6)
      }
    ),
    ("13 `side-by-side` of A's two windows", true, { _ in }, { $0.two.run("side-by-side \($0.floating.number) \($0.docked.number)", then: 5) }),
    ("14 `dock <window> right`", true, { _ in }, { $0.two.run("dock \($0.floating.number) right", then: 5) }),
    ("15 `pin <window>`", false, { _ in }, { $0.two.run("pin \($0.floating.number)", then: 5) }),
  ]
  for road in roads {
    for manner in manners {
      for withB in [true, false] {
        book.story("n19 \(road.name): \(manner.words), \(withB ? "B has a floating window" : "THE CONTROL: B has no window")") { story in
          let set = Floats(story, withB: withB, late: manner.late, before: road.before)
          let since = set.two.mac.journal.count
          road.act(set)
          judge(story, set.two, named: road.names ? set.floating : nil, all: [set.docked, set.floating, set.others].compactMap { $0 }, since: since)
        }
      }
    }
  }

  // The other control: B's window is there, and A's floating window was used after it, so that Arbor's own pick is the window named.
  for road in roads.prefix(3) {
    book.story("n19 \(road.name): apps on time, B has a floating window, A's was used after it") { story in
      let set = Floats(story, withB: true, late: 0, othersUsedLast: false, before: road.before)
      let since = set.two.mac.journal.count
      road.act(set)
      judge(story, set.two, named: set.floating, all: [set.docked, set.floating, set.others].compactMap { $0 }, since: since)
    }
  }

  // From everything, not from a zoomed view: the docked window stays in view.
  for road in roads.prefix(3) {
    book.story("n19 \(road.name): apps on time, B has a floating window, from the view of everything") { story in
      let set = Floats(story, withB: true, late: 0, zoomed: false, before: road.before)
      let since = set.two.mac.journal.count
      road.act(set)
      judge(story, set.two, named: set.floating, all: [set.docked, set.floating, set.others].compactMap { $0 }, since: since)
    }
  }

  // The Desktop's tile, if the view of everything has one.
  for manner in manners {
    for withB in [true, false] {
      book.story("n19 16 a click on the Desktop's tile: \(manner.words), \(withB ? "B has a floating window" : "THE CONTROL: B has no window")") { story in
        let set = Floats(story, withB: withB, late: manner.late, zoomed: false)
        let tiles = set.two.controller.layouts[set.display]?.tiles ?? []
        found("tiles in the view of everything: \(tiles.map { "\($0.kind) \($0.node)" }.joined(separator: ", "))")
        guard let tile = tiles.first(where: { $0.kind == .desktop }) else {
          story.check("(there is no such tile to click: the road does not exist from here)", true)
          return
        }
        let since = set.two.mac.journal.count
        set.two.mac.note("a click on the Desktop's tile")
        set.two.controller.tileActivated(display: set.display, node: tile.node)
        set.two.mac.pass(5)
        judge(story, set.two, named: nil, all: [set.docked, set.floating, set.others].compactMap { $0 }, since: since)
      }
    }
  }

  // MARK: Family 2. From one docked window of A to another, over which a window of B is a guest

  /// A has two docked windows. The view was on the second when B opened a window over it: a guest of that space. Now the first fills the view, with the keyboard.
  @MainActor
  final class Guest {
    let two: StoreyTwo
    var first: FakeMac.Window!, second: FakeMac.Window!, guest: FakeMac.Window?
    init(_ story: Story, withB: Bool, late: TimeInterval) {
      var first: FakeMac.Window!, second: FakeMac.Window!
      var b: FakeMac.App!
      two = StoreyTwo(story) { mac in
        let a = mac.launch("Alpha")
        first = mac.open("first", in: a, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
        second = mac.open("second", in: a, frame: CGRect(x: 540, y: 60, width: 400, height: 300))
        b = mac.launch("Beta")
      }
      (self.first, self.second) = (first, second)
      two.run("dock \(first.number) left")
      two.run("dock \(second.number) beside \(first.number) right")
      two.run("zoom \(second.number)", then: 2)
      if withB {
        two.mac.activate(b)
        two.mac.pass(0.5)
        guest = two.mac.open("guest", in: b, frame: CGRect(x: 300, y: 200, width: 360, height: 240))
        two.mac.pass(2)
      }
      two.run("zoom \(first.number)", then: 2)
      story.check(
        "the stage: A is in front, its first window has the keyboard and fills the view, the others are out of view",
        two.mac.frontmost === first.app && two.mac.keyWindow === first && two.isOutOfView(second) && (guest.map { two.isOutOfView($0) } ?? true),
        "w\(two.mac.keyWindow?.number ?? 0) has it; " + [first, second, guest].compactMap { $0 }.map { two.whereabouts($0) }.joined(separator: "; "))
      first.app.carriesOutAfter = late
      b.carriesOutAfter = late
    }
  }
  let docked: [(name: String, names: Bool, act: @MainActor (Guest) -> Void)] = [
    ("21 the menu's row of the docked window (`reveal`)", true, { $0.two.run("reveal \($0.second.number)", then: 5) }),
    ("22 `focus <docked window>`", true, { $0.two.run("focus \($0.second.number)", then: 5) }),
    ("23 `zoom <docked window>`", true, { $0.two.run("zoom \($0.second.number)", then: 5) }),
    ("24 `focus right`, past the edge of the view", false, { $0.two.run("focus right", then: 5) }),
    ("25 `go right`, the neighbouring space", false, { $0.two.run("go right", then: 5) }),
    ("26 `back`", false, { $0.two.run("back", then: 5) }),
    (
      "27 cmd-backtick to the docked window", true,
      {
        $0.two.mac.personAsksAppInFront(for: $0.second)
        $0.two.mac.pass(5)
      }
    ),
    (
      "28 a click on the docked window in the minimap (the way of a tile's click)", true,
      {
        let display = $0.two.controller.displays[0].id
        guard let leaf = $0.two.controller.workspaces[display]?.tree.leaf(containing: WindowID($0.second.number)) else { return }
        $0.two.mac.note("a click on w\($0.second.number) in the minimap")
        $0.two.controller.tileActivated(display: display, node: leaf)
        $0.two.mac.pass(5)
      }
    ),
  ]
  for road in docked {
    for manner in manners {
      for withB in [true, false] {
        book.story("n19 \(road.name): \(manner.words), \(withB ? "a window of B is its guest" : "THE CONTROL: B has no window")") { story in
          let set = Guest(story, withB: withB, late: manner.late)
          let since = set.two.mac.journal.count
          road.act(set)
          judge(story, set.two, named: road.names ? set.second : nil, all: [set.first, set.second, set.guest].compactMap { $0 }, since: since)
        }
      }
    }
  }

  // MARK: The lag. Roads 01 and 21 again, apps on time

  // Two different things. `frontmostLagsNoticeBy`: for how long `frontmostApplication` goes on naming the old app after the notice, MEASURED at 5 to 107 ms for an activation a program asks for.
  // `activationLandsAfter`: how long after the call the app comes forward at all; the model's 1 ms is a guess, and the knob is mine.
  for (knob, words) in [("property", "frontmostApplication names the old app for"), ("landing", "an app that is asked forward comes"), ("both", "the app comes forward, and the property follows, each after")] {
    for lag in [0.005, 0.05, 0.107] {
      for withB in [true, false] {
        let manner = "\(words) \(Int(lag * 1000)) ms\(knob == "landing" ? " after the call" : "")"
        book.story("n19 51 the menu's row of the floating window, \(manner): \(withB ? "B has a floating window" : "THE CONTROL: B has no window")") { story in
          let set = Floats(story, withB: withB, late: 0)
          if knob != "landing" { set.two.mac.frontmostLagsNoticeBy = lag }
          if knob != "property" { set.two.mac.activationLandsAfter = lag }
          let since = set.two.mac.journal.count
          set.two.run("reveal \(set.floating.number)", then: 5)
          judge(story, set.two, named: set.floating, all: [set.docked, set.floating, set.others].compactMap { $0 }, since: since)
        }
        book.story("n19 52 the menu's row of the docked window, \(manner): \(withB ? "a window of B is its guest" : "THE CONTROL: B has no window")") { story in
          let set = Guest(story, withB: withB, late: 0)
          if knob != "landing" { set.two.mac.frontmostLagsNoticeBy = lag }
          if knob != "property" { set.two.mac.activationLandsAfter = lag }
          let since = set.two.mac.journal.count
          set.two.run("reveal \(set.second.number)", then: 5)
          judge(story, set.two, named: set.second, all: [set.first, set.second, set.guest].compactMap { $0 }, since: since)
        }
      }
    }
  }

  // MARK: Family 3. A tile that stands for a group: Arbor picks one window with the move and asks for another after it

  for manner in manners {
    for withB in [true, false] {
      book.story("n19 31 a click on the tile of a group: \(manner.words), \(withB ? "the group holds a window of A and one of B" : "THE CONTROL: both are A's")") { story in
        var first: FakeMac.Window!, upper: FakeMac.Window!, lower: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          let a = mac.launch("Alpha")
          first = mac.open("first", in: a, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
          upper = mac.open("upper", in: a, frame: CGRect(x: 540, y: 60, width: 400, height: 250))
          lower = mac.open("lower", in: withB ? mac.launch("Beta") : a, frame: CGRect(x: 540, y: 380, width: 400, height: 250))
        }
        // Neither side can be made narrow, so that one of them is a tile.
        for window in [first!, upper!, lower!] { window.minimumSize = CGSize(width: 640, height: 200) }
        two.run("dock \(first.number) left")
        two.run("dock \(upper.number) right")
        two.run("dock \(lower.number) beside \(upper.number) down")
        two.mac.pass(1)
        two.run("show-all", then: 2)
        // The lower one is used after the upper one; then the person works in the first.
        two.run("focus \(upper.number)", then: 1)
        two.run("focus \(lower.number)", then: 1)
        two.run("focus \(first.number)", then: 1)
        two.run("show-all", then: 2)
        two.run("focus \(first.number)", then: 2)
        let display = two.controller.displays[0].id
        let tiles = two.controller.layouts[display]?.tiles ?? []
        found("tiles: \(tiles.map { "\($0.kind) \($0.node) \($0.windows.map(\.description).joined(separator: "+"))" }.joined(separator: ", ")); w\(two.mac.keyWindow?.number ?? 0) has the keyboard; \([first!, upper!, lower!].map { two.whereabouts($0) }.joined(separator: "; "))")
        guard let tile = tiles.first(where: { $0.windows.contains(WindowID(upper.number)) && $0.windows.contains(WindowID(lower.number)) }), two.mac.keyWindow === first else {
          story.check("(MY STAGE DOES NOT STAND: no tile holds the two, or the first has not the keyboard: nothing is told)", false)
          return
        }
        for app in [first.app, lower.app] { app.carriesOutAfter = manner.late }
        let since = two.mac.journal.count
        two.mac.note("a click on the tile of the group")
        two.controller.tileActivated(display: display, node: tile.node)
        two.mac.pass(5)
        // `tileActivated` asks last for the first window under the node that shows.
        judge(story, two, named: upper, all: [first, upper, lower], since: since)
      }
    }
  }

  // MARK: Family 4. Undo, which puts the view back and the keyboard where it was when the step was taken

  for manner in manners {
    for withB in [true, false] {
      book.story("n19 41 `undo` of a dock that was made from the Desktop: \(manner.words), \(withB ? "B has a floating window" : "THE CONTROL: B has no window")") { story in
        var docked: FakeMac.Window!, floating: FakeMac.Window!, others: FakeMac.Window?
        let two = StoreyTwo(story) { mac in
          let a = mac.launch("Alpha")
          docked = mac.open("docked", in: a, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
          floating = mac.open("floating", in: a, frame: CGRect(x: 640, y: 420, width: 300, height: 220))
          if withB { others = mac.open("others", in: mac.launch("Beta"), frame: CGRect(x: 640, y: 80, width: 300, height: 220)) }
        }
        let display = two.controller.displays[0].id
        two.run("dock \(docked.number) left")
        two.run("desktop", then: 1)
        two.mac.click(floating)
        two.mac.pass(1)
        // The step: made on the Desktop, with the keyboard in A's floating window.
        found("the view before the step: \(two.controller.workspaces[display]!.camera)")
        two.run("dock \(floating.number) right", then: 2)
        two.run("show-all", then: 1)
        if let others {
          two.mac.click(others)
          two.mac.pass(1)
        }
        two.run("zoom \(docked.number)", then: 2)
        story.check("the stage: A is in front, its docked window has the keyboard and fills the view", two.mac.frontmost === docked.app && two.mac.keyWindow === docked && two.isOutOfView(floating), "w\(two.mac.keyWindow?.number ?? 0) has it; \(two.whereabouts(floating))")
        docked.app.carriesOutAfter = manner.late
        others?.app.carriesOutAfter = manner.late
        let since = two.mac.journal.count
        let result = two.run("undo", then: 5)
        found("undo: \(result.ok ? "ok" : "refused"): \(result.message); the view: \(two.controller.workspaces[display]!.camera)")
        // Undo asks last for the window that had the keyboard when the step was taken.
        judge(story, two, named: floating, all: [docked, floating, others].compactMap { $0 }, since: since)
      }
    }
  }
}
