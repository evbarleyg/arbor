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
}
