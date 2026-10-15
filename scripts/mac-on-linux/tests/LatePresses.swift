import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// A press that is served late, in the shapes a hand gives it. LostDrags.swift has the plain ones; these are the ones in which a rule that cures one shape breaks
// another: a window or an app that starts late as well, an edge that trails the pointer, a hand that has come to rest, a window below, the menu bar in the way.
// Each is played on time too, as a control. What `WindowGrab.hold` makes of the two places and the two frames is tabled in `WindowGrabTests`.

@MainActor
private func stage(_ story: Story, frame: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300)) -> (StoreyOne, FakeMac.Window) {
  var window: FakeMac.Window!
  let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: frame) }
  return (one, window)
}

@MainActor
private func drags(_ story: Story, _ one: StoreyOne, _ window: FakeMac.Window) {
  story.check("the drag is reported to begin", one.heard.all.contains(.dragBegan(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
  story.check("and to end", one.heard.all.contains(.dragEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
}

@MainActor
func tellOfLatePresses(_ book: Book) {
  let latenesses: [(String, (FakeMac) -> Void)] = [
    ("served on time", { _ in }),
    ("the press heard 300 ms late", { $0.mouseDownIsLateBy = 0.3 }),
    ("Arbor busy for 300 ms, then byTime", { $0.arborIsBusy(for: 0.3, then: .byTime) }),
    ("Arbor busy for 300 ms, then accessibilityFirst", { $0.arborIsBusy(for: 0.3, then: .accessibilityFirst) }),
    ("Arbor busy for 300 ms, then mouseFirst", { $0.arborIsBusy(for: 0.3, then: .mouseFirst) }),
  ]

  // the window starts late AND the press is served late, the pointer still on the title bar.
  for distance in [20, 40, 80, 120, 160] {
    for (name, prepare) in latenesses {
      book.story("the window starts 400 ms late, the pointer \(distance) points along its title bar by then, \(name)") { story in
        let (one, window) = stage(story)
        one.mac.serverFollowsPointerAfter = 0.4
        prepare(one.mac)
        one.mac.press(at: CGPoint(x: 150, y: 112))
        one.mac.pass(0.05)
        for step in 1...4 {
          one.mac.moveMouse(to: CGPoint(x: 150 + CGFloat(distance) * CGFloat(step) / 4, y: 112))
          one.mac.pass(0.05)
        }
        one.mac.pass(0.2)
        for part in 1...12 {
          one.mac.moveMouse(to: CGPoint(x: 150 + CGFloat(distance) + 15 * CGFloat(part), y: 112 + 10 * CGFloat(part)))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // a tall window is dragged against the menu bar; the pointer goes on into it; the window still covers the place of the press.
  for (name, prepare) in latenesses {
    book.story("a tall window is dragged up against the menu bar and along it, \(name)") { story in
      let (one, window) = stage(story, frame: CGRect(x: 12, y: 43, width: 700, height: 650))
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 300, y: 55), to: CGPoint(x: 420, y: 8), steps: 4, interval: 0.05, rest: 0.05)
      for step in 1...10 {
        one.mac.moveMouse(to: CGPoint(x: 420 + 15 * CGFloat(step), y: 8))
        one.mac.pass(0.08)
      }
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // narrower by the right edge, shorter by the bottom edge.
  for (name, prepare) in latenesses + [("the press heard 500 ms late", { $0.mouseDownIsLateBy = 0.5 })] {
    for below in [false, true] {
      book.story("a window\(below ? " over another" : "") is made narrower by its right edge, \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          if below { _ = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 60, width: 900, height: 600)) }
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300))
        }
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 500, y: 250), to: CGPoint(x: 380, y: 250))
        one.mac.release()
        one.mac.pass(3)
        story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.texts)
        story.check("the resize is reported", one.heard.all.contains(.resizeBegan(window.number)) && one.heard.all.contains(.resizeEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
      }
    }
  }

  // the desktop is shown; the button goes down on the bare desktop; the pointer comes to a strip, the way that window was swept.
  for resized in [false, true] {
    for (name, prepare) in [("served on time", { (_: FakeMac) in }), ("Arbor busy for 500 ms", { (mac: FakeMac) in mac.arborIsBusy(for: 0.5) }), ("the press heard 500 ms late", { (mac: FakeMac) in mac.mouseDownIsLateBy = 0.5 })] {
      book.story("macOS shows its desktop\(resized ? ", a window laid out meanwhile" : ""), a rubber band from the middle comes to the strip at the right, the key brings the windows back, \(name)") { story in
        var window: FakeMac.Window!
        let frame = CGRect(x: 600, y: 43, width: 412, height: 600)
        let one = StoreyOne(story) { mac in
          _ = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 400, height: 600))
          window = mac.open("window", in: mac.launch("Notes"), frame: frame)
        }
        one.mac.pressShowDesktopKey()
        one.mac.pass(1)
        if resized {
          _ = one.layer.setFrame(CGRect(x: 600, y: 43, width: 300, height: 500), of: WindowID(window.number))
          one.mac.pass(1)
        }
        one.heard.clear()
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 560, y: 300), to: CGPoint(x: 1018, y: 300), steps: 6, interval: 0.04, rest: 0.02)
        one.mac.pass(0.4)
        // Back towards the middle, with the windows still aside.
        for step in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: 1018 - 51 * CGFloat(step), y: 300))
          one.mac.pass(0.05)
        }
        one.mac.pressShowDesktopKey()
        one.mac.pass(0.15)
        one.mac.moveMouse(to: CGPoint(x: 608, y: 301))
        one.mac.pass(0.15)
        one.mac.moveMouse(to: CGPoint(x: 606, y: 302))
        one.mac.pass(0.15)
        one.mac.release()
        one.mac.pass(2)
        story.check("no drag and no resize is made of it", one.heard.outline.isEmpty, one.heard.outline.map(\.text).joined(separator: ", "))
      }
    }
  }

  // over another window; the hand rests when the press is served, and goes on afterwards.
  for (name, prepare) in latenesses + [("the press heard 500 ms late", { $0.mouseDownIsLateBy = 0.5 })] {
    for below in [false, true] {
      book.story("a window\(below ? " over another" : "") is dragged 150 points, rests for 600 ms and is dragged on, \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          if below { _ = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 60, width: 900, height: 600)) }
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300))
        }
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 300, y: 112), to: CGPoint(x: 400, y: 262), steps: 3, interval: 0.03, rest: 0.02)
        one.mac.pass(0.6)
        for step in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: 400 + 15 * CGFloat(step), y: 262))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // The menu bar stops the window, and the pointer goes on. From 0.36 s on the press is served with the pointer over no window and no window at the place of the press: what
  // is left to go by is where the window's app had it, and for that the place of the press must be kept.
  for busy in [0.3, 0.36, 0.45] {
    for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
      book.story("a window is dragged up into the menu bar and along it, Arbor busy for \(busy) s, then \(order)") { story in
        let (one, window) = stage(story)
        one.mac.arborIsBusy(for: busy, then: order)
        one.mac.drag(from: CGPoint(x: 130, y: 112), to: CGPoint(x: 290, y: 5), steps: 4, interval: 0.06)
        for step in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: 290 + 20 * CGFloat(step), y: 5))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // wider by the left edge, with a neighbour to the left (tiles), the press served late.
  for (name, prepare) in latenesses + [("the press heard 500 ms late", { $0.mouseDownIsLateBy = 0.5 })] {
    book.story("a tile is made wider by its left edge over its neighbour, \(name)") { story in
      var window: FakeMac.Window!, neighbour: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        neighbour = mac.open("neighbour", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 494, height: 600))
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 518, y: 43, width: 494, height: 600))
      }
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 518, y: 300), to: CGPoint(x: 418, y: 300))
      one.mac.release()
      one.mac.pass(3)
      _ = neighbour
      story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
      story.check("the resize is reported", one.heard.outline.filter { $0.window == window.number } == [.resizeBegan(window.number), .resizeEnded(window.number)], one.heard.outline.map(\.text).joined(separator: ", "))
    }
    book.story("a tile is made narrower by its left edge beside its neighbour, \(name)") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        _ = mac.open("neighbour", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 502, height: 600))
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 518, y: 43, width: 494, height: 600))
      }
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 518, y: 300), to: CGPoint(x: 618, y: 300))
      one.mac.release()
      one.mac.pass(3)
      story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
      story.check("the resize is reported", one.heard.outline.filter { $0.window == window.number } == [.resizeBegan(window.number), .resizeEnded(window.number)], one.heard.outline.map(\.text).joined(separator: ", "))
    }
  }

  // an edge whose app follows late (busy from the press), or trails the pointer, with the press served late.
  for (name, prepare) in latenesses {
    for left in [true, false] {
      book.story("a window is made narrower by its \(left ? "left" : "right") edge, its app busy for 400 ms from the press, \(name)") { story in
        let (one, window) = stage(story)
        prepare(one.mac)
        let start = CGPoint(x: left ? 100 : 500, y: 250)
        let way: CGFloat = left ? 1 : -1
        one.mac.press(at: start)
        one.mac.hang(window.app)
        one.mac.pass(0.05)
        for step in 1...4 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * 10 * CGFloat(step), y: 250))
          one.mac.pass(0.05)
        }
        one.mac.pass(0.15)
        one.mac.wake(window.app)
        for step in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * (40 + 10 * CGFloat(step)), y: 250))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        story.check("the window has another size", window.bounds.width == 280, window.bounds.text)
        story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
        story.check("the resize is reported", one.heard.all.contains(.resizeBegan(window.number)) && one.heard.all.contains(.resizeEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
      }
      book.story("a window is made narrower by its \(left ? "left" : "right") edge, which trails the pointer by 30 points when the press is served, \(name)") { story in
        let (one, window) = stage(story)
        prepare(one.mac)
        let start = CGPoint(x: left ? 100 : 500, y: 250)
        let way: CGFloat = left ? 1 : -1
        one.mac.press(at: start)
        one.mac.pass(0.05)
        for step in 1...3 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * 20 * CGFloat(step), y: 250))
          one.mac.pass(0.04)
        }
        one.mac.hang(window.app)
        for step in 1...3 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * (60 + 10 * CGFloat(step)), y: 250))
          one.mac.pass(0.04)
        }
        one.mac.pass(0.1)
        one.mac.wake(window.app)
        for step in 1...6 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * (90 + 5 * CGFloat(step)), y: 250))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        story.check("the window has another size", window.bounds.width == 280, window.bounds.text)
        story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
        story.check("the resize is reported", one.heard.all.contains(.resizeBegan(window.number)) && one.heard.all.contains(.resizeEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
      }
      book.story("a window is made wider by its \(left ? "left" : "right") edge, which trails the pointer by 30 points when the press is served, \(name)") { story in
        let (one, window) = stage(story, frame: CGRect(x: 300, y: 100, width: 400, height: 300))
        prepare(one.mac)
        let start = CGPoint(x: left ? 300 : 700, y: 250)
        let way: CGFloat = left ? -1 : 1
        one.mac.press(at: start)
        one.mac.pass(0.05)
        for step in 1...3 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * 8 * CGFloat(step), y: 250))
          one.mac.pass(0.04)
        }
        one.mac.hang(window.app)
        for step in 1...3 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * (24 + 10 * CGFloat(step)), y: 250))
          one.mac.pass(0.04)
        }
        one.mac.pass(0.1)
        one.mac.wake(window.app)
        for step in 1...6 {
          one.mac.moveMouse(to: CGPoint(x: start.x + way * (54 + 11 * CGFloat(step)), y: 250))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        story.check("the window has another size", window.bounds.width == 520, window.bounds.text)
        story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
        story.check("the resize is reported", one.heard.all.contains(.resizeBegan(window.number)) && one.heard.all.contains(.resizeEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
      }
    }
  }

  // in the hand when the press is served, and at rest from then on.
  for (name, prepare) in latenesses {
    book.story("a window is dragged for 280 ms, held still for a second and let go, \(name)") { story in
      let (one, window) = stage(story)
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 300, y: 112), to: CGPoint(x: 500, y: 262), steps: 5, interval: 0.05, rest: 0.03)
      one.mac.pass(1)
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // A press on a window that has not got the keyboard brings its app forward first, and Arbor hears of that about when it hears of the press (trace `drag-onto-window`: 0.4 ms
  // before). What the layer then asks the app keeps the main thread: 100 to 190 ms for one focus report with Safari and Finder. So this press is late by Arbor's own doing, on a
  // Mac that is not loaded at all. (A real Mac, macOS 26, 2026-10-15: such a drag was not seen as a drag; the window in front docked fine. THE MODEL DOES NOT SHOW THAT: here the drag
  // is seen with every slowness played, before `WindowGrab.hold` as well. So whatever lost it is something this model has not got; scripts/mac-shell/check-drag-from-behind.sh asks a Mac.)
  for answer in [0, 10, 25, 50] {
    for front in [false, true] {
      let which = front ? "has the keyboard" : "has not got the keyboard"
      book.story("a floating window that \(which), of an app that takes \(answer) ms to answer a call, is dragged briskly onto a docked window") { story in
        var docked: FakeMac.Window!, floating: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          floating = mac.open("floating", in: mac.launch("Notes"), frame: CGRect(x: 600, y: 300, width: 360, height: 260))
          docked = mac.open("docked", in: mac.launch("Safari"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
        }
        story.check("one window is docked at the left, one floats", two.run("dock \(docked.number) left").ok && !two.isDocked(floating), two.whereabouts(docked))
        two.mac.click(front ? floating : docked)
        two.mac.pass(1)
        if answer > 0 { floating.app.answersIn = Double(answer) / 1000 }
        two.heard.clear()
        let to = CGPoint(x: docked.frame.maxX - 30, y: docked.frame.midY)
        two.mac.drag(from: CGPoint(x: floating.frame.midX, y: floating.frame.minY + 12), to: to, steps: 8, interval: 0.04, rest: 0.02)
        two.mac.pass(0.6)
        story.check("the drag is reported to begin", two.heard.all.contains(.dragBegan(floating.number)), two.heard.outline.map(\.text).joined(separator: ", "))
        story.check("a preview shows where it would go", two.overlays.preview != nil)
        two.mac.release()
        two.mac.pass(2)
        story.check("let go, it is docked", two.isDocked(floating), two.whereabouts(floating))
      }
    }
  }

  // The same hand with ⌘: held from before the press, macOS moves the window without bringing it forward, so there is no report of a focus at all; or going down on the way.
  for sameApp in [false, true] {
    for command in ["without ⌘", "with ⌘ held from before the press", "with ⌘ going down after fifty points"] {
      book.story("a window of \(sameApp ? "the app in front" : "an app in the background") that has not got the keyboard is dragged 300 points, \(command)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          let front = mac.launch("Safari")
          window = mac.open("window", in: sameApp ? front : mac.launch("Notes"), frame: CGRect(x: 560, y: 300, width: 360, height: 260))
          mac.click(mac.open("front", in: front, frame: CGRect(x: 60, y: 100, width: 400, height: 300)))
        }
        one.heard.clear()
        if command.contains("before") { one.mac.setModifierFlags(1 << 20) }
        one.mac.drag(from: CGPoint(x: 700, y: 312), to: CGPoint(x: 660, y: 342), steps: 3, interval: 0.04)
        if command.contains("after") { one.mac.setModifierFlags(1 << 20) }
        for step in 1...10 {
          one.mac.moveMouse(to: CGPoint(x: 660 - 20 * CGFloat(step), y: 342 + 15 * CGFloat(step)))
          one.mac.pass(0.04)
        }
        one.mac.release()
        one.mac.setModifierFlags(0)
        one.mac.pass(2)
        story.check("the window has moved", window.bounds.origin == CGPoint(x: 320, y: 480), window.bounds.text)
        story.check("it comes forward, or with ⌘ from the first does not", one.heard.all.contains(.focused(window.number)) != command.contains("before"), one.heard.texts)
        drags(story, one, window)
      }
    }
  }

  // Arbor lays out, and the window server's list is behind for 150 ms (seen on a Mac): listed is where the window WAS, its app's word where Arbor has just put it. That is what a window in the hand
  // looks like, if the pointer happens to go from the new place towards the old one. A layout keeps Arbor's main thread, so a press made meanwhile is served right after it, late, and within those 150 ms.
  // By the title bar it is a drag, whatever the frames say. In a field of a toolbar, 40 points below the top, it is none.
  for (way, dx, dy) in [("towards where it was", -1, 0), ("away from where it was", 1, 0), ("across", 0, 1)] as [(String, CGFloat, CGFloat)] {
    for grip in [true, false] {
      // Late, but served while the list is still behind.
      let within: [(String, (FakeMac) -> Void)] = [
        ("served on time", { _ in }), ("the press heard 60 ms late", { $0.mouseDownIsLateBy = 0.06 }), ("the press heard 100 ms late", { $0.mouseDownIsLateBy = 0.1 }),
        ("Arbor busy for 100 ms, then byTime", { $0.arborIsBusy(for: 0.1, then: .byTime) }),
        ("Arbor busy for 100 ms, then accessibilityFirst", { $0.arborIsBusy(for: 0.1, then: .accessibilityFirst) }),
        ("Arbor busy for 100 ms, then mouseFirst", { $0.arborIsBusy(for: 0.1, then: .mouseFirst) }),
      ]
      for (name, prepare) in within {
        book.story("Arbor moves a window 80 points, 20 ms later the button goes down \(grip ? "on its title bar" : "in a field of its toolbar") and the pointer goes \(way), \(name)") { story in
          let (one, window) = stage(story, frame: CGRect(x: 200, y: 200, width: 400, height: 300))
          one.mac.serverListsACallAfter = 0.15
          _ = one.layer.setFrame(CGRect(x: 280, y: 200, width: 400, height: 300), of: WindowID(window.number))
          one.mac.pass(0.02)
          one.heard.clear()
          prepare(one.mac)
          // Where both the old frame and the new one have the window.
          let start = CGPoint(x: 440, y: grip ? 212 : 240)
          one.mac.drag(from: start, to: CGPoint(x: start.x + 90 * dx, y: start.y + 90 * dy), steps: 6, interval: 0.015, rest: 0.01)
          // And on, slowly: what comes right after a move of Arbor's own is taken for its echo, whatever it says, so a gesture that is over in a tenth of a second is another story.
          for step in 1...8 {
            one.mac.moveMouse(to: CGPoint(x: start.x + (90 + 10 * CGFloat(step)) * dx, y: start.y + (90 + 10 * CGFloat(step)) * dy))
            one.mac.pass(0.08)
          }
          one.mac.pass(0.3)
          one.mac.release()
          one.mac.pass(3)
          if grip {
            drags(story, one, window)
          } else {
            story.check("no drag and no resize is made of it", one.heard.outline.isEmpty, one.heard.outline.map(\.text).joined(separator: ", "))
            story.check("the window is where Arbor put it", window.bounds == CGRect(x: 280, y: 200, width: 400, height: 300), window.bounds.text)
          }
        }
      }
    }
  }

  // A false drag costs a tile: whatever is taken for a drag of a docked window takes it out of the arrangement. A stubborn window goes back by itself to where it was before Arbor moved it, in one jump, and
  // if text is being selected in it meanwhile, the pointer has gone some way too. The judge's stories, with the real controller: `resize` of the left tile sends the right one 80 points to the right.
  for (back, after) in [(0.196, 0.02), (0.474, 0.02), (0.474, 0.2)] {
    for (hand, dx) in [("the way it goes back", -120), ("the way Arbor sent it", 120)] as [(String, CGFloat)] {
      book.story("Arbor sends a stubborn tile 80 points, it goes back after \(back) s, the list 150 ms behind; \(Int(after * 1000)) ms after the call text is selected in it \(hand)") { story in
        var left: FakeMac.Window!, right: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          right = mac.open("right", in: mac.launch("Safari"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))
          left = mac.open("left", in: mac.launch("Notes"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
        }
        story.check("two tiles", two.run("arrange").ok && two.isDocked(left) && two.isDocked(right))
        if left.frame.minX > right.frame.minX { swap(&left, &right) }
        right.goesBackAfter = back
        two.mac.serverListsACallAfter = 0.15
        two.heard.clear()
        let shown = two.overlays.previewHistory.count
        story.check("the left tile is made wider", two.run("resize \(left.number) right 80", then: after).ok)
        two.mac.drag(from: CGPoint(x: 720, y: 400), to: CGPoint(x: 720 + dx, y: 404), steps: 12, interval: 0.05, rest: 0.02)
        two.mac.pass(0.9)
        two.mac.release()
        two.mac.pass(4)
        story.check("no drag and no resize is made of it", two.heard.outline.allSatisfy { $0.isNoGrab }, two.heard.outline.map(\.text).joined(separator: ", "))
        story.check("no preview shows", two.overlays.previewHistory.dropFirst(shown).allSatisfy { $0 == nil })
        story.check("both are tiles still", two.isDocked(left) && two.isDocked(right), "\(two.whereabouts(left)); \(two.whereabouts(right))")
      }
    }
  }

  // The same jump, where a review looked for it. `send` moves the window through the layer, as Arbor does; it goes back by itself 0.3 s later.
  func stubborn(_ story: Story, sentBy dx: CGFloat, _ dy: CGFloat, listLag: TimeInterval = 0, prepare: (FakeMac) -> Void = { _ in }) -> (StoreyOne, FakeMac.Window) {
    let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    prepare(one.mac)
    window.goesBackAfter = 0.3
    one.mac.serverListsACallAfter = listLag
    _ = one.layer.setFrame(CGRect(x: 300 + dx, y: 200 + dy, width: 400, height: 300), of: WindowID(window.number))
    return (one, window)
  }
  func nothing(_ story: Story, _ one: StoreyOne) {
    story.check("no drag and no resize is made of it", one.heard.outline.allSatisfy { $0.isNoGrab }, one.heard.outline.map(\.text).joined(separator: ", "))
  }
  for inside in [6, 9, 12] {
    book.story("a stubborn window goes back 60 points while a scroll bar \(inside) points inside its right border is pulled down") { story in
      let (one, _) = stubborn(story, sentBy: 60, 0)
      one.mac.pass(0.1)
      one.heard.clear()
      one.mac.drag(from: CGPoint(x: 760 - CGFloat(inside), y: 300), to: CGPoint(x: 760 - CGFloat(inside), y: 420), steps: 12, interval: 0.05, rest: 0.02)
      one.mac.pass(0.5)
      one.mac.release()
      one.mac.pass(2)
      nothing(story, one)
    }
  }
  // The list is behind Arbor's call, so that by the frame it lists the press is at the window's top, or at its edge; by the window's real place it is in the text.
  for after in [20, 100, 200] {
    for (what, dx, dy, start, way) in [
      ("up 80 points, the press 125 below its new top", 0, -80, CGPoint(x: 500, y: 245), CGSize(width: 0, height: 120)),
      ("left 80 points, the press 85 inside its new left edge", -80, 0, CGPoint(x: 305, y: 380), CGSize(width: 120, height: 0)),
    ] as [(String, CGFloat, CGFloat, CGPoint, CGSize)] {
      book.story("Arbor sends a stubborn window \(what), \(after) ms after the call, the list 150 ms behind, and the pointer goes the way it goes back") { story in
        let (one, _) = stubborn(story, sentBy: dx, dy, listLag: 0.15)
        one.mac.pass(Double(after) / 1000)
        one.heard.clear()
        one.mac.drag(from: start, to: CGPoint(x: start.x + way.width, y: start.y + way.height), steps: 12, interval: 0.05, rest: 0.02)
        one.mac.pass(0.5)
        one.mac.release()
        one.mac.pass(2)
        nothing(story, one)
      }
    }
  }
  // One jump shows as two places if the two signs of it differ a little for good.
  for off in [0, 1, 2] {
    for back in [20, 60, 90] {
      book.story("the list is \(off) points off the app's word, and a stubborn window goes back \(back) points while text is selected in it the same way") { story in
        let (one, _) = stubborn(story, sentBy: CGFloat(back), 0) { $0.listIsOffBy = CGFloat(off) }
        one.mac.pass(0.1)
        one.heard.clear()
        one.mac.drag(from: CGPoint(x: 560, y: 380), to: CGPoint(x: 440, y: 384), steps: 12, interval: 0.05, rest: 0.02)
        one.mac.pass(0.5)
        one.mac.release()
        one.mac.pass(2)
        nothing(story, one)
      }
    }
  }
  // Without a list the press is held against where the window's app had it.
  for back in [20, 60] {
    book.story("the window server gives no list, and a stubborn window goes back \(back) points while text is selected in it the same way") { story in
      let (one, _) = stubborn(story, sentBy: CGFloat(back), 0)
      one.mac.pass(0.1)
      one.mac.serverGivesNoList = true
      one.heard.clear()
      one.mac.drag(from: CGPoint(x: 560, y: 380), to: CGPoint(x: 440, y: 384), steps: 12, interval: 0.05, rest: 0.02)
      one.mac.pass(0.5)
      one.mac.release()
      one.mac.pass(2)
      nothing(story, one)
    }
  }
  // A press that found no window keeps to the one whose app had it under the press, so that it can be looked at twice.
  for (name, prepare) in latenesses {
    book.story("the window server gives no list, and a window is dragged for a second by its background, \(name)") { story in
      // Up and to the left: going down, the window's top would come to the place of the press, where one look is enough.
      let (one, window) = stage(story, frame: CGRect(x: 320, y: 300, width: 400, height: 300))
      window.isMovedByItsBackground = true
      one.mac.serverGivesNoList = true
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 520, y: 460), to: CGPoint(x: 370, y: 340))
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }
  // Not for good: the first to speak need not be the one on top, and may close. The judge's.
  for (what, dx, dy) in [("the pointer's way", 30, 20), ("another way", -40, 0)] as [(String, CGFloat, CGFloat)] {
    for closes in [false, true] {
      book.story("the window server gives no list; a window over another app's is dragged by its title bar; the one beneath moves first by itself, \(what)\(closes ? ", and closes" : "")") { story in
        var above: FakeMac.Window!, below: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          below = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 150, y: 100, width: 600, height: 500))
          above = mac.open("above", in: mac.launch("Notes"), frame: CGRect(x: 250, y: 250, width: 400, height: 300))
        }
        one.mac.serverGivesNoList = true
        one.mac.press(at: CGPoint(x: 400, y: 262))
        one.mac.later(0.03) { one.mac.appMoves(below, to: below.frame.offsetBy(dx: dx, dy: dy)) }
        if closes { one.mac.later(0.13) { one.mac.close(below) } }
        one.mac.pass(0.02)
        for step in 1...60 {
          one.mac.moveMouse(to: CGPoint(x: 400 + 3.2 * CGFloat(step), y: 262 + 2.4 * CGFloat(step)))
          one.mac.pass(1.0 / 60)
        }
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, above)
        story.check("nothing is made of the one beneath", !one.heard.all.contains(.dragBegan(below.number)), one.heard.outline.map(\.text).joined(separator: ", "))
      }
    }
  }
  // Two jumps with a move of Arbor's own between them are two first looks.
  book.story("text is selected, the window jumps 30 points the pointer's way, Arbor puts it elsewhere, and it jumps 30 points from there") { story in
    let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    one.mac.press(at: CGPoint(x: 440, y: 380))
    one.mac.pass(0.02)
    for tick in 1...30 {
      one.mac.moveMouse(to: CGPoint(x: 440 + 4 * CGFloat(tick), y: 380))
      if tick == 8 { one.mac.appMoves(window, to: CGRect(x: 330, y: 200, width: 400, height: 300)) }
      if tick == 14 { _ = one.layer.setFrame(CGRect(x: 310, y: 200, width: 400, height: 300), of: WindowID(window.number)) }
      if tick == 24 { one.mac.appMoves(window, to: CGRect(x: 340, y: 200, width: 400, height: 300)) }
      one.mac.pass(0.03)
    }
    one.mac.pass(0.4)
    one.mac.release()
    one.mac.pass(2)
    nothing(story, one)
  }
  // The pointer's way, against it, and the pointer's way again to another place.
  book.story("text is selected, and the window jumps the pointer's way, back beyond where it was, and the pointer's way again") { story in
    let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    one.mac.press(at: CGPoint(x: 440, y: 380))
    one.mac.pass(0.02)
    for tick in 1...30 {
      one.mac.moveMouse(to: CGPoint(x: 440 + 4 * CGFloat(tick), y: 380))
      if tick == 8 { one.mac.appMoves(window, to: CGRect(x: 330, y: 200, width: 400, height: 300)) }
      if tick == 14 { one.mac.appMoves(window, to: CGRect(x: 290, y: 200, width: 400, height: 300)) }
      if tick == 22 { one.mac.appMoves(window, to: CGRect(x: 350, y: 200, width: 400, height: 300)) }
      one.mac.pass(0.03)
    }
    one.mac.pass(0.4)
    one.mac.release()
    one.mac.pass(2)
    nothing(story, one)
  }
  // After one jump a long selection must not cost a look at the window server with every movement: from the moment the pointer has gone 24 points on. In strides, so that this comes
  // long before the half second of the next story.
  book.story("a window jumps once early in a selection of 600 movements") { story in
    let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    one.mac.press(at: CGPoint(x: 320, y: 380))
    one.mac.pass(0.02)
    one.mac.moveMouse(to: CGPoint(x: 330, y: 380))
    one.mac.appMoves(window, to: CGRect(x: 310, y: 200, width: 400, height: 300))
    one.mac.pass(0.1)
    let before = one.mac.timesTheListWasAskedFor
    for tick in 1...600 {
      // To the far side of the text and back, six points a movement.
      let way = tick % 100
      one.mac.moveMouse(to: CGPoint(x: 330 + 6 * CGFloat(way < 50 ? way : 100 - way), y: 380))
      one.mac.pass(1.0 / 120)
    }
    let asked = one.mac.timesTheListWasAskedFor - before
    one.mac.release()
    one.mac.pass(2)
    nothing(story, one)
    story.check("in those five seconds the window server is asked some ten times a second from the fifth movement on", asked < 75, "\(asked) times")
  }
  // Nor while text is selected in a small spot, where the pointer never goes far. The judge's.
  book.story("a window jumps 30 ms after the press, and the pointer stays within 20 points of there for 600 movements") { story in
    let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    one.mac.press(at: CGPoint(x: 440, y: 380))
    one.mac.pass(0.02)
    one.mac.moveMouse(to: CGPoint(x: 446, y: 380))
    one.mac.pass(0.01)
    one.mac.appMoves(window, to: CGRect(x: 306, y: 200, width: 400, height: 300))
    one.mac.pass(0.05)
    let before = one.mac.timesTheListWasAskedFor
    for tick in 1...600 {
      one.mac.moveMouse(to: CGPoint(x: 446 + CGFloat(tick % 20) - 10, y: 380 + CGFloat(tick % 7)))
      one.mac.pass(1.0 / 120)
    }
    let asked = one.mac.timesTheListWasAskedFor - before
    one.mac.release()
    one.mac.pass(2)
    nothing(story, one)
    story.check("in those five seconds the window server is asked with every movement for half a second, then ten times a second", asked < 130, "\(asked) times")
  }

  // What the slower looks must not cost: a hand that trembles for a second and then flicks the window away and lets go, all between two looks. The judge's, at eight phases of the tenth of a second.
  for ticks in 60...67 {
    book.story("a window is taken by its background, the hand goes 6 points, trembles for \(ticks) movements at sixty a second, flicks it away in 32 ms and lets go") { story in
      let (one, window) = stage(story, frame: CGRect(x: 320, y: 300, width: 400, height: 300))
      window.isMovedByItsBackground = true
      let start = CGPoint(x: 520, y: 460)
      one.mac.press(at: start)
      one.mac.pass(0.02)
      one.mac.moveMouse(to: CGPoint(x: start.x + 6, y: start.y))
      for tick in 1...ticks {
        one.mac.pass(1.0 / 60)
        one.mac.moveMouse(to: CGPoint(x: start.x + 6 + CGFloat(tick % 2), y: start.y))
      }
      one.mac.pass(0.008)
      for step in 1...4 {
        one.mac.moveMouse(to: CGPoint(x: start.x + 6 + 16 * CGFloat(step), y: start.y + 12 * CGFloat(step)))
        one.mac.pass(0.008)
      }
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // A window that moves by itself in steps goes on too, but not as the pointer does.
  for steps in [1, 2, 3, 8] {
    book.story("text is selected over 120 points in 0.6 s, and the window goes 90 points the same way by itself in \(steps) step(s) within 0.2 s") { story in
      let (one, window) = stage(story, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
      one.mac.press(at: CGPoint(x: 440, y: 380))
      one.mac.pass(0.02)
      var done = 0
      for tick in 1...24 {
        one.mac.moveMouse(to: CGPoint(x: 440 + 5 * CGFloat(tick), y: 380))
        // From 0.2 s on.
        let due = min(max((tick - 8) * steps / 8, 0), steps)
        if due > done {
          done = due
          one.mac.appMoves(window, to: CGRect(x: 300 + 90 * CGFloat(done) / CGFloat(steps), y: 200, width: 400, height: 300))
        }
        one.mac.pass(0.025)
      }
      one.mac.pass(0.4)
      one.mac.release()
      one.mac.pass(2)
      nothing(story, one)
    }
  }

  // The other side of that rule: a window that is taken along by its background goes on with the pointer, and is dragged.
  for (name, prepare) in latenesses {
    book.story("a window is dragged for a second by its background, \(name)") { story in
      let (one, window) = stage(story)
      window.isMovedByItsBackground = true
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 300, y: 260), to: CGPoint(x: 500, y: 410))
      one.mac.release()
      one.mac.pass(3)
      story.check("the window has moved", window.bounds.origin == CGPoint(x: 300, y: 250), window.bounds.text)
      drags(story, one, window)
    }
  }

  // THE SENTENCE THAT MATTERS: on time, with a hand that goes on, nothing is lost. Whatever the window is taken by below its top, whichever way it goes, at whatever pace.
  for (grip, down, background) in [("its background", 160, true), ("a bar of 90 points, 70 down", 70, false)] as [(String, CGFloat, Bool)] {
    for (way, dx, dy) in [("down and to the right", 1, 0.6), ("to the left", -1, 0), ("up", 0, -1), ("down and to the left", -0.7, 0.7)] as [(String, CGFloat, CGFloat)] {
      for (pace, step, interval, steps) in [("slowly, 2 points a movement at sixty a second", 2, 1.0 / 60, 40), ("briskly, 8 points a movement at sixty a second", 8, 1.0 / 60, 20), ("in coarse steps of 66 points", 66, 0.08, 3)]
        as [(String, CGFloat, TimeInterval, Int)]
      {
        book.story("served on time, a window is taken by \(grip) and goes \(way), \(pace)") { story in
          let (one, window) = stage(story, frame: CGRect(x: 320, y: 300, width: 400, height: 300))
          window.isMovedByItsBackground = background
          if !background { window.titleBarHeight = 90 }
          let start = CGPoint(x: 520, y: 300 + down)
          let far = step * CGFloat(steps)
          one.mac.drag(from: start, to: CGPoint(x: start.x + dx * far, y: start.y + dy * far), steps: steps, interval: interval, rest: 0.02)
          one.mac.release()
          one.mac.pass(3)
          drags(story, one, window)
        }
      }
    }
  }

  // macOS had tiled it, and in the hand it gets its old size back, over the first third of a second. Whatever it is taken by.
  for (grip, down, background) in [("its title bar", 12, false), ("a bar of 90 points, 70 down", 70, false), ("its background", 160, true)] as [(String, CGFloat, Bool)] {
    book.story("a window that gets its old size back in the hand is dragged by \(grip)") { story in
      let (one, window) = stage(story, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
      window.isMovedByItsBackground = background
      if down == 70 { window.titleBarHeight = 90 }
      one.mac.press(at: CGPoint(x: 300, y: 100 + down))
      one.mac.pass(0.03)
      for step in 1...20 {
        one.mac.moveMouse(to: CGPoint(x: 300 + 8 * CGFloat(step), y: 100 + down + 6 * CGFloat(step)))
        if step <= 6 { one.mac.appMoves(window, to: CGRect(origin: window.bounds.origin, size: CGSize(width: 500 - 20 * CGFloat(step), height: 400 - 10 * CGFloat(step)))) }
        one.mac.pass(0.05)
      }
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // THE PRICE of two looks: a window that starts late and catches up in one jump, with the hand at rest by then, gives one look and no more.
  for (grip, down, background) in [("its title bar", 12, false), ("its background", 160, true)] as [(String, CGFloat, Bool)] {
    book.story("a window that starts 0.4 s late is thrown by \(grip) in 0.18 s and held still") { story in
      let (one, window) = stage(story)
      window.isMovedByItsBackground = background
      one.mac.serverFollowsPointerAfter = 0.4
      one.mac.drag(from: CGPoint(x: 300, y: 100 + down), to: CGPoint(x: 500, y: 160 + down), steps: 6, interval: 0.03, rest: 0.0)
      one.mac.pass(1.5)
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // THE PRICE, the judge's: a gesture of ONE movement of the pointer gives one look. A hand never makes one; a script that warps the pointer does.
  book.story("served on time, a window is taken by its background and carried 120 points in one movement, and held for a second") { story in
    let (one, window) = stage(story)
    window.isMovedByItsBackground = true
    one.mac.drag(from: CGPoint(x: 300, y: 260), to: CGPoint(x: 400, y: 326), steps: 1, interval: 0.02, rest: 0.02)
    one.mac.pass(1)
    one.mac.release()
    one.mac.pass(3)
    drags(story, one, window)
  }

  // The slowest hands, and a Mac that says every movement twice: how many movements later than by the title bar.
  for (pace, step, twice, atMost) in [("1 point a movement", 1, false, 3), ("half a point a movement", 0.5, false, 6), ("8 points a movement, each heard twice", 8, true, 2)] as [(String, CGFloat, Bool, Int)] {
    book.story("a window is dragged by its background at sixty movements a second, \(pace)") { story in
      @MainActor func began(byTheBackground: Bool) -> Int? {
        let (one, window) = stage(story)
        window.isMovedByItsBackground = byTheBackground
        let start = CGPoint(x: 300, y: byTheBackground ? 260 : 112)
        one.mac.press(at: start)
        one.mac.pass(0.05)
        for tick in 1...60 {
          let place = CGPoint(x: start.x + step * CGFloat(tick), y: start.y)
          one.mac.moveMouse(to: place)
          if twice { one.mac.moveMouse(to: place) }
          one.mac.pass(1.0 / 60)
        }
        one.mac.release()
        one.mac.pass(2)
        let lines = one.mac.journal
        guard let index = lines.firstIndex(where: { $0.contains("reports: drag began w\(window.number)") }) else { return nil }
        return lines[..<index].filter { $0.contains("→ leftMouseDragged") }.count / (twice ? 2 : 1)
      }
      let (bar, middle) = (began(byTheBackground: false), began(byTheBackground: true))
      story.check("by the title bar it is seen", bar != nil, "\(bar.map(String.init) ?? "never")")
      story.check("by the background \(atMost) movements later at the most", bar != nil && middle != nil && middle! <= bar! + atMost, "\(middle.map(String.init) ?? "never") against \(bar.map(String.init) ?? "never")")
    }
  }

  // Two looks cost a movement of the pointer or two, which at sixty a second are frames: the window must have gone on by more than two points. Held against the same drag by the title bar.
  book.story("a window is dragged by its background at sixty movements a second") { story in
    @MainActor func began(byTheBackground: Bool) -> Int? {
      let (one, window) = stage(story)
      window.isMovedByItsBackground = byTheBackground
      let start = CGPoint(x: 300, y: byTheBackground ? 260 : 112)
      one.mac.drag(from: start, to: CGPoint(x: start.x + 120, y: start.y + 90), steps: 60, interval: 1.0 / 60, rest: 0.05)
      one.mac.release()
      one.mac.pass(2)
      let lines = one.mac.journal
      guard let index = lines.firstIndex(where: { $0.contains("reports: drag began w\(window.number)") }) else { return nil }
      return lines[..<index].filter { $0.contains("→ leftMouseDragged") }.count
    }
    let (bar, middle) = (began(byTheBackground: false), began(byTheBackground: true))
    story.check("by the title bar the drag is seen at the first movement that moves the window", bar != nil, "\(bar.map(String.init) ?? "never")")
    story.check("by the background two movements later at the most", bar != nil && middle != nil && middle! <= bar! + 2, "\(middle.map(String.init) ?? "never") against \(bar.map(String.init) ?? "never")")
  }
}

private extension Heard {
  var isNoGrab: Bool {
    switch self {
    case .dragBegan, .dragEnded, .dragCancelled, .resizeBegan, .resizeEnded: false
    default: true
    }
  }
}
