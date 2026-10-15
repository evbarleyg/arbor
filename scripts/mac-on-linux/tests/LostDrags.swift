import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Drags on a loaded Mac. On loaded hosted Macs Arbor saw no drag at all though the window moved (2026-10-14). What could lose one: the monitors hear of the press late; the
// window server begins to move the window late, with the pointer already some way off; Arbor's own main thread is busy at the press, and everything arrives at once.

@MainActor
private func stage(_ story: Story) -> (StoreyOne, FakeMac.Window) {
  var window: FakeMac.Window!
  let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300)) }
  return (one, window)
}

private let grip = CGPoint(x: 300, y: 112)

/// What became of a drag, in a line: for the table in the findings.
@MainActor
private func account(_ one: StoreyOne, _ window: FakeMac.Window, pressedAt: TimeInterval) -> String {
  let began = one.mac.journal.first { $0.contains("reports: drag began w\(window.number)") }.flatMap { Double($0.trimmingCharacters(in: .whitespaces).prefix(while: { $0 != " " })) }
  let moved = one.heard.all.filter { $0 == .dragMoved(window.number) }.count
  let changes = one.heard.all.filter { $0 == .changed(window.number, byUser: true) }.count
  return began.map { "drag began \(Int((($0 + one.mac.dawn) - pressedAt) * 1000)) ms after the press, \(moved) moves" } ?? "NO DRAG; \(changes) reports that the window changed, not by Arbor"
}

/// A slow drag (a second, 200 points) or a flick (a quarter of a second).
@MainActor
private func play(_ one: StoreyOne, flick: Bool) {
  if flick {
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262), steps: 4, interval: 0.03)
  } else {
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
  }
  one.mac.release()
  one.mac.pass(3)
}

@MainActor
private func judge(
  _ story: Story, _ one: StoreyOne, _ window: FakeMac.Window, pressedAt: TimeInterval, movedTo place: CGPoint = CGPoint(x: 300, y: 250)
) {
  let words = account(one, window, pressedAt: pressedAt)
  story.check("the window has moved", window.bounds.origin == place, window.bounds.text)
  story.check("the drag is reported to begin", one.heard.all.contains(.dragBegan(window.number)), words)
  story.check("and to end, so that there is a drop to act on", one.heard.all.contains(.dragEnded(window.number)), words)
  story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
  one.mac.note("IN SHORT: \(words)")
}

@MainActor
func tellOfLostDrags(_ book: Book) {
  for flick in [false, true] {
    let gesture = flick ? "a window is flicked" : "a window is dragged for a second"

    for late in [0, 20, 100, 500] {
      book.story("\(gesture), and the monitor hears of the press \(late) ms late") { story in
        let (one, window) = stage(story)
        one.mac.mouseDownIsLateBy = Double(late) / 1000
        let pressed = one.mac.now
        play(one, flick: flick)
        judge(story, one, window, pressedAt: pressed)
      }
    }

    for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
      book.story("\(gesture) while Arbor's main thread is busy for 300 ms from the press, and what queued up comes \(order)") { story in
        let (one, window) = stage(story)
        let pressed = one.mac.now
        one.mac.arborIsBusy(for: 0.3, then: order)
        play(one, flick: flick)
        judge(story, one, window, pressedAt: pressed)
      }
    }
  }

  // Along its title bar the window stays under the place of the press, so a press that is served late does find it: 60 points and more from where its app last said.
  // That is also how a window looks that macOS has swept aside (DesktopShown.swift).
  func sideways(_ story: Story, _ prepare: (FakeMac) -> Void) {
    let (one, window) = stage(story)
    prepare(one.mac)
    let pressed = one.mac.now
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: grip.y))
    one.mac.release()
    one.mac.pass(3)
    judge(story, one, window, pressedAt: pressed, movedTo: CGPoint(x: 300, y: 100))
  }
  for late in [0, 100, 500] {
    book.story("a window is dragged sideways for a second, and the monitor hears of the press \(late) ms late") { story in
      sideways(story) { $0.mouseDownIsLateBy = Double(late) / 1000 }
    }
  }
  for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
    book.story("a window is dragged sideways for a second while Arbor's main thread is busy for 300 ms from the press, and what queued up comes \(order)") { story in
      sideways(story) { $0.arborIsBusy(for: 0.3, then: order) }
    }
  }

  // A floating window over tiles: as soon as it has left the place of the press, another window that Arbor knows shows there.
  func overAnother(_ story: Story, _ prepare: (FakeMac) -> Void) {
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      _ = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 60, width: 900, height: 600))
      window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    }
    prepare(one.mac)
    let pressed = one.mac.now
    play(one, flick: false)
    judge(story, one, window, pressedAt: pressed)
  }
  book.story("a window that lies over another is dragged for a second, and the monitor hears of the press 500 ms late") { story in
    overAnother(story) { $0.mouseDownIsLateBy = 0.5 }
  }
  for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
    book.story("a window that lies over another is dragged for a second while Arbor's main thread is busy for 300 ms from the press, and what queued up comes \(order)") { story in
      overAnother(story) { $0.arborIsBusy(for: 0.3, then: order) }
    }
  }

  // A rubber band over the icons on the desktop. The pointer comes to a window, which is not therefore in the hand.
  book.story("the button goes down on the wallpaper while Arbor's main thread is busy for 300 ms, the pointer comes to a window, and its app moves it") { story in
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 100, width: 400, height: 300)) }
    one.mac.arborIsBusy(for: 0.3)
    // It is there, and rests, by the time the press is served.
    one.mac.drag(from: CGPoint(x: 100, y: 500), to: CGPoint(x: 400, y: 300), steps: 5, interval: 0.03, rest: 0.01)
    one.mac.pass(0.4)
    // The way the pointer came, and on: what a window does that started late.
    for step in 1...3 {
      one.mac.appMoves(window, to: CGRect(x: 300 + 10 * CGFloat(step), y: 100 - 5 * CGFloat(step), width: 400, height: 300))
      one.mac.pass(0.15)
      one.mac.moveMouse(to: CGPoint(x: 400 + 10 * CGFloat(step), y: 300 - 5 * CGFloat(step)))
      one.mac.pass(0.15)
    }
    one.mac.release()
    one.mac.pass(2)
    story.check("no drag and no resize is made of it", one.heard.outline.isEmpty, one.heard.texts)
  }

  // By its left edge a window's place changes with its size, as far as the pointer goes. Whatever becomes of a press that is served late, it is no drag: a drag ends
  // in a drop, and the window would be docked or set afloat where the hand only made it wider.
  func byTheLeftEdge(_ story: Story, wider: Bool, _ prepare: (FakeMac) -> Void) {
    let (one, window) = stage(story)
    prepare(one.mac)
    one.mac.drag(from: CGPoint(x: 100, y: 250), to: CGPoint(x: wider ? 20 : 220, y: 250))
    one.mac.release()
    one.mac.pass(3)
    story.check("the window has another size", window.bounds == (wider ? CGRect(x: 20, y: 100, width: 480, height: 300) : CGRect(x: 220, y: 100, width: 280, height: 300)), window.bounds.text)
    story.check("it is not taken for a drag", !one.heard.all.contains(.dragBegan(window.number)), one.heard.texts)
    story.check("the resize is reported to begin and to end", one.heard.outline == [.resizeBegan(window.number), .resizeEnded(window.number)], one.heard.texts)
    story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
  }
  for wider in [true, false] {
    let gesture = "a window is made \(wider ? "wider" : "narrower") by its left edge for a second"
    for late in [0, 100, 500] {
      book.story("\(gesture), and the monitor hears of the press \(late) ms late") { story in
        byTheLeftEdge(story, wider: wider) { $0.mouseDownIsLateBy = Double(late) / 1000 }
      }
    }
    for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
      book.story("\(gesture) while Arbor's main thread is busy for 300 ms from the press, and what queued up comes \(order)") { story in
        byTheLeftEdge(story, wider: wider) { $0.arborIsBusy(for: 0.3, then: order) }
      }
    }
  }

  // `WindowGrab.patience`: with the pointer more than 24 points from the press and the window where it was, the press is settled as not being about the window, and both
  // signs are ignored until the button comes up.
  for wait in [0, 100, 400] {
    for distance in [10, 24, 40] {
      book.story("the window server begins to move a dragged window \(wait) ms after the press, with the pointer \(distance) points away") { story in
        let (one, window) = stage(story)
        one.mac.serverFollowsPointerAfter = Double(wait) / 1000
        let pressed = one.mac.now
        one.mac.press(at: grip)
        // The pointer is that far away before the window stirs, in two steps.
        let step = max(Double(wait) / 1000 / 3, 0.01)
        one.mac.pass(step)
        one.mac.moveMouse(to: CGPoint(x: grip.x + CGFloat(distance) / 2, y: grip.y))
        one.mac.pass(step)
        one.mac.moveMouse(to: CGPoint(x: grip.x + CGFloat(distance), y: grip.y))
        one.mac.pass(step + 0.02)
        for part in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: grip.x + CGFloat(distance) + (200 - CGFloat(distance)) * CGFloat(part) / 8, y: grip.y + 150 * CGFloat(part) / 8))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        judge(story, one, window, pressedAt: pressed)
      }
    }
  }

  // Coarse steps, as scripts/mac-shell/pointer.swift makes them of a long drag: 30 steps of 42 and of 66 points, a tenth of a second apart. On a hosted Mac three of four such drags were
  // never taken for drags.
  let large = FakeMac.Screen(id: 1, name: "Large", frame: CGRect(x: 0, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 0, y: 31, width: 2560, height: 1340))
  let lateness: [(words: String, start: TimeInterval, always: TimeInterval)] = [
    ("on time", 0, 0), ("50 ms late to start", 0.05, 0), ("100 ms late to start", 0.1, 0), ("50 ms behind all the way", 0, 0.05), ("100 ms behind all the way", 0, 0.1),
  ]
  for step in [42, 66] {
    for late in lateness {
      for ahead in [
        "", ", the pointer read a step late", ", and then a step ahead of the pointer", ", and then a step ahead of the pointer, and the app says nothing until it is over",
      ] {
        let words = "a window is dragged in 30 steps of \(step) points, the window server \(late.words)\(ahead)"
        book.story(words) { story in
          var window: FakeMac.Window!
          let one = StoreyOne(story) { mac in
            mac.setScreens([large], notices: 1)
            window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300))
          }
          one.mac.serverFollowsPointerAfter = late.start
          one.mac.serverLagsPointerBy = late.always
          one.mac.pointerIsReadOneStepLate = ahead.contains("read")
          one.mac.serverRunsAStepAhead = ahead.contains("ahead")
          window.app.isSilentDuringDrags = ahead.contains("nothing")
          let further = ahead.contains("ahead") ? CGPoint(x: CGFloat(step), y: 10) : .zero
          let pressed = one.mac.now
          one.mac.drag(from: grip, to: CGPoint(x: grip.x + CGFloat(step * 30), y: grip.y + 300), steps: 30, interval: 0.1, rest: 0.02)
          one.mac.release()
          one.mac.pass(3)
          let short = account(one, window, pressedAt: pressed)
          story.check("the window has moved", window.bounds.origin == CGPoint(x: 100 + CGFloat(step * 30) + further.x, y: 400 + further.y), window.bounds.text)
          story.check("the drag is reported to begin", one.heard.all.contains(.dragBegan(window.number)), short)
          story.check("and to end, so that there is a drop to act on", one.heard.all.contains(.dragEnded(window.number)), short)
          story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
          one.mac.note("IN SHORT: \(short)")
        }
      }
    }
  }

  // The hand is quick and then rests; the window comes after it in one leap. No movement of the mouse follows that could prompt a look at the window server.
  for silent in [false, true] {
    for goesOn in [false, true] {
      let words = "a window is dragged 120 points in 80 ms, the hand rests, and the window comes after it in one leap 300 ms after the press"
        + (silent ? ", its app saying nothing until it is over" : "") + (goesOn ? "; a second later the hand goes on" : "")
      book.story(words) { story in
        let (one, window) = stage(story)
        window.app.isSilentDuringDrags = silent
        one.mac.serverFollowsPointerAfter = 0.3
        let pressed = one.mac.now
        one.mac.drag(from: grip, to: CGPoint(x: grip.x + 120, y: grip.y + 40), steps: 4, interval: 0.02, rest: 0.01)
        one.mac.pass(1)
        if goesOn {
          for part in 1...4 {
            one.mac.moveMouse(to: CGPoint(x: grip.x + 120 + CGFloat(part) * 20, y: grip.y + 40))
            one.mac.pass(0.08)
          }
        }
        one.mac.release()
        one.mac.pass(3)
        let short = account(one, window, pressedAt: pressed)
        story.check("the drag is reported to begin", one.heard.all.contains(.dragBegan(window.number)), short)
        story.check("and to end, so that there is a drop to act on", one.heard.all.contains(.dragEnded(window.number)), short)
        story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
        one.mac.note("IN SHORT: \(short)")
      }
    }
  }

  // The other side of the same coin: a selection, during which the window does something by itself. Never a drag, never a resize.
  let own: [(words: String, change: (CGRect) -> CGRect)] = [
    ("moves the pointer's way", { $0.offsetBy(dx: 40, dy: 0) }), ("moves the pointer's way, as far as the pointer has gone", { $0.offsetBy(dx: 80, dy: 0) }),
    ("jumps to within 24 points of the pointer's own travel", { $0.offsetBy(dx: 100, dy: 0) }), ("moves against the pointer", { $0.offsetBy(dx: -40, dy: 0) }), ("moves across the pointer's way", { $0.offsetBy(dx: 0, dy: 40) }),
    ("moves aslant, half the pointer's way", { $0.offsetBy(dx: 30, dy: 30) }), ("is resized", { CGRect(x: $0.minX, y: $0.minY, width: $0.width + 40, height: $0.height) }),
  ]
  for what in own {
    book.story("text is selected over 120 points, and meanwhile the window \(what.words), by itself") { story in
      let (one, window) = stage(story)
      one.mac.press(at: CGPoint(x: 200, y: 250))
      one.mac.pass(0.15)
      for part in 1...12 {
        one.mac.moveMouse(to: CGPoint(x: 200 + CGFloat(part) * 10, y: 250))
        one.mac.pass(0.05)
        if part == 8 { one.mac.appMoves(window, to: what.change(window.frame)) }
      }
      one.mac.pass(0.3)
      one.mac.release()
      one.mac.pass(2)
      story.check("it is not taken for a drag", !one.heard.all.contains(.dragBegan(window.number)), one.heard.texts)
      story.check("nor for a resize by hand", !one.heard.all.contains(.resizeBegan(window.number)), one.heard.texts)
      story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.frame, "\(one.snapshot(window)?.frame.text ?? "")")
    }
  }

  // Seen late in a job on a hosted Mac: a system alert, a window of another process at the level of modal panels, 260 by 250 at 382,118, lay over the title bar where the script pressed.
  for storey in [1, 2] {
    book.story("a system alert lies over the title bar where the button goes down\(storey == 2 ? ", and the window is docked" : "")") { story in
      var window: FakeMac.Window!
      let frame = CGRect(x: 300, y: 130, width: 400, height: 300)
      let (mac, heard, layer): (FakeMac, Listener, AXWindowSystem)
      var two: StoreyTwo?
      if storey == 1 {
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: frame) }
        (mac, heard, layer) = (one.mac, one.heard, one.layer)
      } else {
        let stage = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: frame) }
        stage.run("dock \(window.number) left")
        (mac, heard, layer, two) = (stage.mac, stage.heard, stage.layer, stage)
      }
      let home = window.frame
      // Over the title bar, wherever the window is by now.
      let alert = FakeMac.Furniture(number: 60, pid: 95, layer: 8, bounds: CGRect(x: home.midX - 130, y: home.minY - 12, width: 260, height: 250))
      mac.furniture.append(alert)
      heard.clear()
      mac.drag(from: CGPoint(x: home.midX, y: home.minY + 12), to: CGPoint(x: home.midX + 200, y: home.minY + 160))
      mac.release()
      mac.pass(2)
      story.check("the alert gets the press: the window stays where it is", window.frame == home, window.frame.text)
      story.check("the press is reported, for the monitor hears of it as of any other", heard.all.contains(.pressed), heard.texts)
      story.check("no drag and no resize is made of it", heard.outline.isEmpty, heard.texts)
      story.check("nothing is said about the window or the keyboard", heard.all == [.pressed], heard.texts)
      story.check("the alert is not among what Arbor takes for windows on screen", !layer.stackedWindows().contains { $0.id.rawValue == alert.number })
      if let two { story.check("the window is still docked", two.isDocked(window)) }
    }
  }

  // What a person sees of it.
  for wait in [0, 100] {
    let words = wait > 0 ? ", and the window server begins to move it \(wait) ms after the press, with the pointer 40 points away" : ""
    book.story("with macOS's tiling off, a floating window is dragged briskly to the left edge of the screen\(words)") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        mac.macOSTilesDraggedWindows = false
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 130, width: 400, height: 300))
      }
      two.mac.serverFollowsPointerAfter = Double(wait) / 1000
      two.mac.drag(from: CGPoint(x: 510, y: 148), to: CGPoint(x: 3, y: 368), steps: 12, interval: 0.04, rest: 0.02)
      two.mac.pass(0.3)
      story.check("a preview shows where it would go", two.overlays.preview != nil)
      two.mac.release()
      two.mac.pass(2)
      story.check("let go, it is docked", two.isDocked(window), two.whereabouts(window))
    }

    book.story("a docked window is dragged briskly out onto the Desktop\(words)") { story in
      var window: FakeMac.Window!, other: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        other = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
      }
      story.check(
        "two windows are docked, with the Desktop between them", two.run("dock \(window.number) left").ok && two.run("dock \(other.number) right").ok)
      let slot = window.frame
      let asked = window.timesAskedForAFrame
      two.mac.serverFollowsPointerAfter = Double(wait) / 1000
      two.mac.drag(from: CGPoint(x: slot.midX, y: slot.minY + 12), to: CGPoint(x: 512, y: 300), steps: 8, interval: 0.04, rest: 0.02)
      two.mac.pass(0.6)
      story.check(
        "while it is held Arbor does not pull at it", window.timesAskedForAFrame == asked,
        "asked for a place or a size \(window.timesAskedForAFrame - asked) times")
      two.mac.release()
      two.mac.pass(2)
      story.check(
        "let go over the Desktop, it floats there", !two.isDocked(window) && window.frame.minX > slot.minX + 100,
        "\(two.isDocked(window) ? "docked" : "floating"), \(two.whereabouts(window))")
    }
  }
}
