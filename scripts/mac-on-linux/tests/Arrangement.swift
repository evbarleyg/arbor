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

  // With no gap a slot ends at the visible frame's bottom, and with the Dock below no window can: macOS stops it a point short, in every order of calls (the probe of `roomToGrow`: D1, D8, 8 of 8). That is no refusal.
  book.story("with no gap, a window is docked left: its slot ends at the Dock") { story in
    var window: FakeMac.Window!
    var settings = Settings()
    settings.gap = 0
    let two = StoreyTwo(story, settings: settings) { mac in window = mac.open("a", in: mac.launch("Notes"), frame: CGRect(x: 170, y: 100, width: 480, height: 348)) }
    story.check("the command is taken", two.run("dock \(window.number) left", then: 3).ok && two.isDocked(window))
    let place = two.controller.freshLayout(of: two.layer.displays()[0].id)?.windowFrames[WindowID(window.number)]
    story.check("its slot ends at the visible bottom", place?.maxY == 705, place?.text ?? "none")
    story.check("it is at the top of its slot, a point short at the bottom", window.frame.minY == 31 && window.frame.maxY == 704, two.whereabouts(window))
    let asked = window.timesAskedForAFrame
    two.mac.pass(5)
    story.check("and Arbor has done with it", window.timesAskedForAFrame == asked, "asked \(window.timesAskedForAFrame - asked) times more")
    let seen = two.controller.seenSizes[WindowID(window.number)]
    story.check("the point is not written down as where the app stops growing", (seen?.stoppedAt ?? .zero) == .zero, "stopped at \(seen.map { "\(Int($0.stoppedAt.width))×\(Int($0.stoppedAt.height))" } ?? "")")
    story.check("nor is the window down as one that does not fit its slot", two.controller.misfits[WindowID(window.number)] == nil)
  }

  // A window has just gone into the Dock, which is two points lower for it: macOS goes by the Dock as it is, Arbor by what it last heard (seen: an answer cut at 706 while Arbor still had 705).
  book.story("a window stands low on the screen and is docked a moment after another has landed in the Dock") { story in
    var window: FakeMac.Window!, other: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      let app = mac.launch("Notes")
      other = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
      window = mac.open("a", in: app, frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    }
    two.mac.minimize(other)
    two.mac.pass(0.56)
    story.check("the command is taken", two.run("dock \(window.number) left", then: 4).ok && two.isDocked(window))
    let place = two.controller.freshLayout(of: two.layer.displays()[0].id)?.windowFrames[WindowID(window.number)]
    story.check("it fills the place Arbor has for it", place == window.frame, "\(two.whereabouts(window)); Arbor's place for it is \(place?.text ?? "none")")
  }

  // Let go low on the screen, a window that was docked is given its own size back where there is no room for it.
  book.story("a docked window whose own size is tall is dragged out and let go low on the screen, and docked again") { story in
    var window: FakeMac.Window!
    var others: [FakeMac.Window] = []
    let two = StoreyTwo(story) { mac in
      window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 60, width: 400, height: 600))
      let app = mac.launch("Safari")
      others = [mac.open("b", in: app, frame: CGRect(x: 500, y: 100, width: 400, height: 300)), mac.open("c", in: app, frame: CGRect(x: 540, y: 140, width: 400, height: 300))]
    }
    story.check("three windows are arranged", two.run("arrange").ok && ([window] + others).allSatisfy { two.isDocked($0) })
    story.check("it is in a slot lower than its own size", window.frame.height < 400, two.whereabouts(window))
    let slot = window.frame
    two.mac.drag(from: CGPoint(x: slot.midX, y: slot.minY + 12), to: CGPoint(x: 915, y: 432), steps: 8, interval: 0.04, rest: 0.02)
    two.mac.pass(0.6)
    two.mac.release()
    two.mac.pass(3)
    story.check("let go over the Desktop, it floats", !two.isDocked(window), two.whereabouts(window))
    let floating = window.frame
    two.run("dock \(window.number) left", then: 2)
    two.run("float \(window.number)", then: 3)
    story.check("docked and floated again, it has its own size: 400×600", window.frame.size == CGSize(width: 400, height: 600), "\(two.whereabouts(window)); let go, it was at \(floating.text)")
  }

  // An answer that is short because of where the window stood when the size call reached it says nothing about the app. Two kinds of late app: one carries out everything it is asked so much later, in order, so that what
  // Arbor reads back at once is the old frame; the other is sized at once and moved late, so that the size call finds it at the old place, whatever the order of the calls.
  for late in [0.05, 0.2] {
    for (words, placeAlone) in [("carries out \(Int(late * 1000)) ms late what it is asked", false), ("is sized at once and moved \(Int(late * 1000)) ms late", true)] {
      book.story("a window that stands low on the screen is docked left, and its app \(words)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          window = mac.open("a", in: mac.launch("Late"), frame: CGRect(x: 170, y: 220, width: 480, height: 348))
          other = mac.open("b", in: mac.launch("Notes"), frame: CGRect(x: 560, y: 60, width: 400, height: 300))
        }
        if placeAlone { window.app.appliesPlaceAfter = late } else { window.app.carriesOutAfter = late }
        let slot = CGRect(x: 12, y: 43, width: 494, height: 650)
        story.check("the command is taken", two.run("dock \(window.number) left", then: 3).ok && two.isDocked(window))
        story.check("three seconds later it fills its slot", window.frame == slot, "\(two.whereabouts(window)), its slot is \(slot.text)")
        let asked = window.timesAskedForAFrame
        two.mac.pass(3)
        story.check("and Arbor has done with it", window.timesAskedForAFrame == asked, "asked \(window.timesAskedForAFrame - asked) times more")
        // What was learnt of it, if anything, shows at the next layout.
        two.run("dock \(other.number) right", then: 3)
        two.run("zoom \(other.number)", then: 2)
        two.run("show-all", then: 3)
        story.check("after the view has been away and come back it fills its slot", window.frame.minY == 43 && window.frame.height == 650, two.whereabouts(window))
      }
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
