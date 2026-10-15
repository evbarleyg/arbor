import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import FakeMacOS
import Foundation

// Whole stories: the real controller on the real layer. The checks look at the Mac's screen: where the windows are.

extension StoreyTwo {
  /// The window the focus ring is drawn around.
  var ring: UInt32? { overlays.scenes.values.compactMap(\.focusRing).first?.window.rawValue }
  func isDocked(_ window: FakeMac.Window) -> Bool { controller.snapshot().windows.first { $0.id.rawValue == window.number }?.docked ?? false }
  func knows(_ window: FakeMac.Window) -> Bool { controller.snapshot().windows.contains { $0.id.rawValue == window.number } }
}

@MainActor
private func twoDocked(_ story: Story, oneApp: Bool = false) -> (StoreyTwo, FakeMac.Window, FakeMac.Window) {
  var left: FakeMac.Window!, right: FakeMac.Window!
  let two = StoreyTwo(story) { mac in
    let app = mac.launch("Notes")
    right = mac.open("right", in: oneApp ? app : mac.launch("Safari"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))
    left = mac.open("left", in: app, frame: CGRect(x: 60, y: 100, width: 400, height: 300))
    mac.activate(app)
  }
  story.check(
    "two windows are arranged side by side", two.run("arrange").ok && two.isDocked(left) && two.isDocked(right),
    "\(two.whereabouts(left)); \(two.whereabouts(right))")
  if left.frame.minX > right.frame.minX { swap(&left, &right) }
  two.mac.click(left)
  two.mac.pass(1)
  return (two, left, right)
}

@MainActor
func tellOfArrangements(_ book: Book) {
  // What fault (a) cost: rules, automatic docking and the view ignored every window opened in a running app.
  for focusFirst in [false, true] {
    book.story("with automatic docking, a window opens in a running app\(focusFirst ? " that reports the focus before the creation" : "")") { story in
      var first: FakeMac.Window!
      var settings = Settings()
      settings.newWindows = "dock"
      let two = StoreyTwo(story, settings: settings) { mac in first = mac.open("first", in: mac.launch("Notes")) }
      two.run("dock \(first.number) left")
      first.app.reportsFocusBeforeCreated = focusFirst
      let second = two.mac.open("second", in: first.app, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
      two.mac.pass(2)
      story.check(
        "it is docked beside the other", two.isDocked(second) && !second.frame.intersects(first.frame),
        "\(two.whereabouts(first)); \(two.whereabouts(second))")
      story.check("the focus ring is around it", two.ring == second.number, "\(String(describing: two.ring))")
    }
  }

  for delay in [0.0, 0.3] {
    book.story("while a window is framed, another opens\(delay > 0 ? " and gets its subrole \(delay) s late" : "")") { story in
      let (two, left, _) = twoDocked(story, oneApp: true)
      two.run("zoom \(left.number)")
      left.app.subroleComesAfter = delay
      let new = two.mac.open("new", in: left.app, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
      two.mac.pass(3)
      story.check("it is in view", two.isInView(new), two.whereabouts(new))
      story.check("Arbor knows it", two.knows(new))
      story.check("the focus ring is around it, for it has the keyboard", two.ring == new.number, "\(String(describing: two.ring))")
    }
  }

  book.story("an app that refuses observers for 6 s is launched, and its window has the keyboard all along") { story in
    let (two, _, _) = twoDocked(story)
    let app = two.mac.launch("Slow", readyAfter: 6)
    two.mac.pass(0.3)
    let window = two.mac.open("hello", in: app, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    two.mac.pass(12)
    story.check("Arbor knows its window", two.knows(window))
    story.check("the focus ring is around it", two.ring == window.number, "\(String(describing: two.ring))")
  }

  book.story("a docked window closes") { story in
    let (two, left, right) = twoDocked(story)
    let half = left.frame.width
    two.mac.close(right)
    two.mac.pass(2)
    story.check("its neighbour gets the room", left.frame.width > half * 1.5, two.whereabouts(left))
  }

  book.story("a docked window closes and the notification never comes") { story in
    let (two, left, right) = twoDocked(story)
    let half = left.frame.width
    two.mac.close(right, announced: false)
    two.mac.pass(5)
    story.check("its neighbour gets the room", left.frame.width > half * 1.5, two.whereabouts(left))
    two.mac.click(left)
    two.run("show-all")
    two.run("zoom \(left.number)")
    two.run("show-all")
    two.mac.pass(3)
    story.check("at the latest after the person has gone on working", left.frame.width > half * 1.5, two.whereabouts(left))
  }

  book.story("an app with a docked window quits") { story in
    let (two, left, right) = twoDocked(story)
    let half = left.frame.width
    two.mac.quit(right.app)
    two.mac.pass(2)
    story.check("the neighbour gets the room", left.frame.width > half * 1.5, two.whereabouts(left))
    story.check("and the focus ring, with the keyboard", two.ring == left.number, "\(String(describing: two.ring))")
  }

  // Where the three test windows of the hosted Macs' scripts stand when Arbor first sees them. Below the first there are 484 points to the Dock, and its slot is 650 high.
  for (command, slots) in [
    ("dock 101 left", [CGRect(x: 12, y: 43, width: 494, height: 650)]),
    ("arrange", [CGRect(x: 12, y: 43, width: 390, height: 319), CGRect(x: 12, y: 374, width: 390, height: 319), CGRect(x: 414, y: 43, width: 391, height: 650)]),
  ] {
    book.story("windows that stand low on the screen: \(command)") { story in
      var windows: [FakeMac.Window] = []
      let two = StoreyTwo(story) { mac in
        let app = mac.launch("Notes")
        for (name, x, y) in [("a", 170, 220), ("b", 220, 180), ("c", 270, 140)] { windows.append(mac.open(name, in: app, frame: CGRect(x: x, y: y, width: 480, height: 348))) }
      }
      story.check("the command is taken", two.run(command, then: 3).ok)
      story.check("each docked window fills its slot", zip(windows, slots).allSatisfy { two.isDocked($0) && $0.frame == $1 }, zip(windows, slots).map { "\(two.whereabouts($0)), its slot is \($1.text)" }.joined(separator: "; "))
    }
  }

  book.story("a docked window is minimized and restored") { story in
    let (two, left, right) = twoDocked(story)
    let (leftHome, rightHome) = (left.frame, right.frame)
    two.mac.minimize(right)
    two.mac.pass(3)
    story.check("its neighbour gets the room", left.frame.width > leftHome.width * 1.5, two.whereabouts(left))
    two.mac.restore(right)
    two.mac.pass(3)
    story.check(
      "restored, both are where they were", left.frame == leftHome && right.frame == rightHome, "\(two.whereabouts(left)); \(two.whereabouts(right))")
  }

  book.story("an app with a docked window is hidden and shown again") { story in
    let (two, left, right) = twoDocked(story)
    let (leftHome, rightHome) = (left.frame, right.frame)
    two.mac.hide(right.app)
    two.mac.pass(3)
    story.check("the neighbour gets the room", left.frame.width > leftHome.width * 1.5, two.whereabouts(left))
    two.mac.activate(right.app)
    two.mac.pass(3)
    story.check(
      "shown again, both are where they were", left.frame == leftHome && right.frame == rightHome,
      "\(two.whereabouts(left)); \(two.whereabouts(right))")
  }

  for lists in [FakeMac.ListsDuringTransition.right, .neither] {
    book.story("a trip to another Space and back\(lists == .neither ? ", and in the transitions apps list no windows at all" : "")") { story in
      let (two, left, right) = twoDocked(story)
      let (leftHome, rightHome) = (left.frame, right.frame)
      two.mac.switchSpace(to: 2, lists: lists)
      two.mac.pass(3)
      two.mac.switchSpace(to: 1, lists: lists)
      two.mac.pass(3)
      story.check(
        "both windows are docked where they were", two.isDocked(left) && two.isDocked(right) && left.frame == leftHome && right.frame == rightHome,
        "\(two.whereabouts(left)); \(two.whereabouts(right))")
      two.run("zoom \(left.number)")
      story.check(
        "and Arbor goes on arranging them: one is framed, the other goes out of view", left.frame.width > 900 && two.isOutOfView(right),
        "\(two.whereabouts(left)); \(two.whereabouts(right))")
    }
  }

  book.story("a docked window gets a new tab") { story in
    let (two, left, right) = twoDocked(story)
    let home = right.frame
    let tab = two.mac.newTab(of: right)
    two.mac.pass(2)
    story.check("the tab is docked in its place", two.isDocked(tab) && tab.frame == home, two.whereabouts(tab))
    story.check("the neighbour has not moved", left.frame.maxX < tab.frame.minX)
    two.mac.chooseTab(right)
    two.mac.pass(2)
    story.check("so is the first tab when it is chosen again", two.isDocked(right) && right.frame == home, two.whereabouts(right))
  }

  for late in [false, true] {
    book.story("a docked window enters full screen and leaves it\(late ? ", saying so late" : "")") { story in
      let (two, left, right) = twoDocked(story)
      let (leftHome, rightHome) = (left.frame, right.frame)
      let asked = right.timesAskedForAFrame
      two.mac.enterFullScreen(right, saysSoLate: late, lists: late ? .neither : .right)
      two.mac.pass(4)
      story.check("it fills the display", right.frame == FakeMac.Screen.hostedMac.frame, two.whereabouts(right))
      story.check(
        "and Arbor has not pulled at it on the way", right.timesAskedForAFrame == asked,
        "asked for a place or a size \(right.timesAskedForAFrame - asked) times")
      two.mac.leaveFullScreen(right)
      two.mac.pass(4)
      story.check(
        "afterwards both are where they were", left.frame == leftHome && right.frame == rightHome,
        "\(two.whereabouts(left)); \(two.whereabouts(right))")
    }
  }

  // Trace `drag-to-edge`. The left, right and top edges of the screen are Arbor's only where macOS's own tiling is switched off.
  for silent in [false, true] {
    book.story("with macOS's tiling off, a floating window is dragged to the left edge of the screen\(silent ? ", and its app says nothing until it is over" : "")") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        mac.macOSTilesDraggedWindows = false
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300))
      }
      window.app.isSilentDuringDrags = silent
      two.mac.drag(from: CGPoint(x: 510, y: 148), to: CGPoint(x: 3, y: 368), steps: 25)
      story.check("a preview shows where it would go", two.overlays.preview != nil)
      two.mac.release(.seenTwice)
      two.mac.pass(2)
      story.check("let go, it is docked", two.isDocked(window), two.whereabouts(window))
      story.check("in view", two.isInView(window), two.whereabouts(window))
      story.check("and the preview is gone", two.overlays.preview == nil)
    }
  }

  // As a Mac comes, those edges are macOS's. It acts only at their last point, and in the menu bar only for a pointer that has rested; but a hand pushes a window against an edge, so Arbor leaves it the whole of its own band
  // along them. A window let go there belongs to whoever takes it. If macOS does, it is macOS's: Arbor sets no frame, and a docked window's place closes. If macOS does not, nothing was offered and nothing happens: a floating
  // window stays where it was let go, a docked one goes home to its slot, in one move, its neighbours untouched (QUESTIONS, Q23).
  // The throw: five movements in a tenth of a second, the last of them into the menu bar, and the hand opens 20 ms later.
  let short: [(words: String, goal: CGPoint, steps: Int, interval: TimeInterval)] = [
    ("let go three points short of the left edge of the screen", CGPoint(x: 3, y: 368), 25, 0.08), ("let go three points short of the right edge of the screen", CGPoint(x: 1020, y: 368), 25, 0.08),
    ("let go just under the menu bar", CGPoint(x: 512, y: 35), 25, 0.08), ("thrown into the menu bar and let go at once", CGPoint(x: 512, y: 20), 5, 0.02),
  ]
  for place in short {
    book.story("with macOS's tiling on, a floating window is \(place.words)") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300)) }
      two.mac.drag(from: CGPoint(x: 510, y: 148), to: place.goal, steps: place.steps, interval: place.interval)
      story.check("the drag is seen", two.heard.all.contains(.dragBegan(window.number)), two.heard.texts)
      story.check("Arbor stands aside: no preview", two.overlays.preview == nil)
      let letGo = window.bounds
      let asked = window.timesAskedForAFrame
      two.mac.release()
      two.mac.pass(2)
      story.check("let go, it is not docked", !two.isDocked(window), two.whereabouts(window))
      story.check("it stays where it was let go, and nobody asks it to move", window.frame == letGo && window.timesAskedForAFrame == asked, two.whereabouts(window))
    }

    book.story("with macOS's tiling on, a docked window is \(place.words)") { story in
      let (two, left, right) = twoDocked(story)
      // The one that is not at that edge already.
      let (window, neighbour) = place.goal.x < 100 ? (right, left) : (left, right)
      let (home, beside) = (window.frame, neighbour.frame)
      two.mac.drag(from: CGPoint(x: home.midX, y: home.minY + 12), to: place.goal, steps: place.steps, interval: place.interval)
      story.check("Arbor stands aside: no preview", two.overlays.preview == nil)
      let asked = (window.timesAskedForAFrame, neighbour.timesAskedForAFrame)
      let besideInTheDrag = neighbour.frame
      two.mac.release()
      two.mac.pass(0.6)
      story.check("macOS does not take it, so it goes home: half a second later it is in its slot", two.isDocked(window) && window.frame == home, "\(two.whereabouts(window)), its slot is \(home.text)")
      two.mac.pass(2)
      story.check("and stays there, docked", two.isDocked(window) && window.frame == home, "\(two.whereabouts(window)), its slot is \(home.text)")
      // A position and perhaps a size: one `setFrame`.
      story.check("in one move", (1...3).contains(window.timesAskedForAFrame - asked.0), "asked for a place or a size \(window.timesAskedForAFrame - asked.0) times")
      story.check(
        "its neighbour is where it was", neighbour.frame == beside && (besideInTheDrag != beside || neighbour.timesAskedForAFrame == asked.1),
        "\(two.whereabouts(neighbour)), it was at \(beside.text); asked \(neighbour.timesAskedForAFrame - asked.1) times")
    }
  }

  let taken: [(words: String, goal: CGPoint, tile: CGRect)] = [
    ("pushed against the left edge of the screen", CGPoint(x: 0, y: 368), CGRect(x: -1, y: 31, width: 512, height: 674)),
    ("pushed against the right edge of the screen", CGPoint(x: 1023, y: 368), CGRect(x: 513, y: 31, width: 512, height: 674)),
    ("held in the menu bar", CGPoint(x: 512, y: 20), CGRect(x: 0, y: 31, width: 1024, height: 674)),
  ]
  for place in taken {
    book.story("with macOS's tiling on, a floating window is \(place.words)") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300)) }
      two.mac.drag(from: CGPoint(x: 510, y: 148), to: place.goal, steps: 25)
      two.mac.pass(0.3)
      story.check("Arbor stands aside: no preview", two.overlays.preview == nil)
      let asked = window.timesAskedForAFrame
      two.mac.release()
      two.mac.pass(3)
      story.check("macOS gives it its tile", window.frame == place.tile, two.whereabouts(window))
      story.check("there is one writer: Arbor asks nothing of it", window.timesAskedForAFrame == asked, "asked for a place or a size \(window.timesAskedForAFrame - asked) times")
      story.check("it is not docked", !two.isDocked(window))
      let believed = two.controller.snapshot().windows.first { $0.id.rawValue == window.number }?.frame
      story.check("Arbor knows where it is", believed == window.frame, "\(believed?.text ?? "")")
    }

    book.story("with macOS's tiling on, a docked window is \(place.words)") { story in
      let (two, left, right) = twoDocked(story)
      let (window, neighbour) = place.goal.x < 100 ? (right, left) : (left, right)
      let beside = neighbour.frame
      two.mac.drag(from: CGPoint(x: window.frame.midX, y: window.frame.minY + 12), to: place.goal, steps: 25)
      two.mac.pass(0.3)
      story.check("Arbor stands aside: no preview", two.overlays.preview == nil)
      let asked = window.timesAskedForAFrame
      two.mac.release()
      two.mac.pass(3)
      story.check("macOS gives it its tile", window.frame == place.tile, two.whereabouts(window))
      story.check("there is one writer: Arbor asks nothing of it", window.timesAskedForAFrame == asked, "asked for a place or a size \(window.timesAskedForAFrame - asked) times")
      story.check("it is macOS's: no longer docked", !two.isDocked(window))
      story.check("and its place closes", neighbour.frame.width > beside.width * 1.5, two.whereabouts(neighbour))
    }
  }

  book.story("with macOS's tiling on, a floating window is dragged to the bottom edge of the screen, which is nobody's but Arbor's") { story in
    var window: FakeMac.Window!
    let two = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300)) }
    two.mac.drag(from: CGPoint(x: 510, y: 148), to: CGPoint(x: 512, y: 765), steps: 25)
    two.mac.pass(0.3)
    story.check("a preview shows where it would go", two.overlays.preview != nil)
    two.mac.release()
    two.mac.pass(2)
    story.check("let go, it is docked", two.isDocked(window), two.whereabouts(window))
  }

  book.story("a floating window is dragged to the edge and the release is never heard") { story in
    var window: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      mac.macOSTilesDraggedWindows = false
      window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300))
    }
    two.mac.drag(from: CGPoint(x: 510, y: 148), to: CGPoint(x: 3, y: 368), steps: 25)
    story.check("there is a preview", two.overlays.preview != nil)
    two.mac.release(.lost)
    two.mac.pass(3)
    story.check("the preview does not stay on screen for ever", two.overlays.preview == nil)
    story.check("the window is not docked: nobody knows that this was meant", !two.isDocked(window))
  }

  // Trace `edge-resize`.
  book.story("the edge between two docked windows is dragged") { story in
    let (two, left, right) = twoDocked(story)
    let (leftHome, rightHome) = (left.frame, right.frame)
    two.mac.drag(from: CGPoint(x: left.frame.maxX, y: 368), to: CGPoint(x: left.frame.maxX + 60, y: 368), steps: 10)
    two.mac.release()
    two.mac.pass(2)
    story.check("the window has grown", left.frame.width == leftHome.width + 60, two.whereabouts(left))
    story.check(
      "and its neighbour has made way", right.frame.minX == rightHome.minX + 60 && right.frame.maxX == rightHome.maxX, two.whereabouts(right))
  }

  // Trace `self-move`: Arbor puts it back 0.26 s later.
  book.story("an app moves its own docked window") { story in
    let (two, left, _) = twoDocked(story)
    let home = left.frame
    two.mac.appMoves(left, to: home.offsetBy(dx: 80, dy: 60))
    two.mac.pass(2)
    story.check("Arbor puts it back", left.frame == home, two.whereabouts(left))
  }

  book.story("the permission is taken away while windows are out of view") { story in
    let (two, left, right) = twoDocked(story)
    two.run("zoom \(left.number)")
    story.check("one window is out of view", two.isOutOfView(right))
    two.mac.isTrusted = false
    let began = two.mac.now
    two.run("show-all")
    story.check("Arbor does not hang", two.mac.now - began < 3)
    story.check("and knows that it has lost the permission", !two.controller.accessibilityGranted)
  }
}
