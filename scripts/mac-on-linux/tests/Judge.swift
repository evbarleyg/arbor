import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// An independent reviewer's stories, written to break `WindowGrab.hold` as it first stood: false drags of swept windows and of windows that move by themselves, a drag lost that
// used to be seen. By themselves: --only "judge: J".

@MainActor
private func grabs(_ one: StoreyOne) -> [Heard] {
  one.heard.all.filter {
    switch $0 {
    case .dragBegan, .dragEnded, .dragCancelled, .resizeBegan, .resizeEnded: true
    default: false
    }
  }
}

@MainActor
private func nothingIsMadeOfIt(_ story: Story, _ one: StoreyOne) {
  story.check("no drag and no resize is made of it", grabs(one).isEmpty, one.heard.texts)
}

@MainActor
private func drags(_ story: Story, _ one: StoreyOne, _ window: FakeMac.Window) {
  story.check("the drag is reported to begin", one.heard.all.contains(.dragBegan(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
  story.check("and to end", one.heard.all.contains(.dragEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
}

@MainActor
func tellOfTheJudge(_ book: Book) {
  let latenesses: [(String, (FakeMac) -> Void)] = [
    ("served on time", { _ in }),
    ("the press heard 300 ms late", { $0.mouseDownIsLateBy = 0.3 }),
    ("the press heard 500 ms late", { $0.mouseDownIsLateBy = 0.5 }),
    ("Arbor busy for 500 ms, then byTime", { $0.arborIsBusy(for: 0.5, then: .byTime) }),
    ("Arbor busy for 500 ms, then accessibilityFirst", { $0.arborIsBusy(for: 0.5, then: .accessibilityFirst) }),
    ("Arbor busy for 500 ms, then mouseFirst", { $0.arborIsBusy(for: 0.5, then: .mouseFirst) }),
  ]

  // J1. The desktop is shown. Where the windows ARE, by Accessibility, the desktop is bare. A rubber band begins there: over the left edge of the right tile, which with two
  // tiles is the middle of the display. It is thrown to the right edge of the display, where that tile's strip is.
  for start in [560, 595, 605, 614, 640] {
    for (name, prepare) in latenesses {
      book.story("judge: J1 macOS shows its desktop, a rubber band from x \(start) is thrown to the right edge of the display and let go, \(name)") { story in
        var window: FakeMac.Window!
        let frame = CGRect(x: 600, y: 43, width: 412, height: 600)
        let one = StoreyOne(story) { mac in
          _ = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 400, height: 600))
          window = mac.open("window", in: mac.launch("Notes"), frame: frame)
        }
        one.mac.pressShowDesktopKey()
        one.mac.pass(1)
        one.heard.clear()
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: CGFloat(start), y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.04, rest: 0.02)
        one.mac.pass(0.5)
        one.mac.moveMouse(to: CGPoint(x: 1021, y: 332))
        one.mac.pass(0.2)
        one.mac.release()
        one.mac.pass(0.5)
        one.mac.pressShowDesktopKey()
        one.mac.pass(2)
        nothingIsMadeOfIt(story, one)
        story.check("no window is reported moved by hand", !one.heard.all.contains(.changed(window.number, byUser: true)), one.heard.texts)
        story.check("Arbor knows where the window is", one.snapshot(window)?.frame == frame, "\(one.snapshot(window)?.frame.text ?? "")")
      }
    }
  }

  // J1c. A window that hangs off the display is swept by less than 100 points: then the place of the press does not matter at all.
  for (name, prepare) in latenesses {
    book.story("judge: J1c macOS shows its desktop, a window that hung off the right edge is swept by 68 points, a rubber band from the middle comes to its strip, \(name)") { story in
      var window: FakeMac.Window!
      let frame = CGRect(x: 944, y: 143, width: 400, height: 400)
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: frame) }
      one.mac.pressShowDesktopKey()
      one.mac.pass(1)
      story.check("it is listed 68 points aside", one.mac.listedBounds(of: window).minX == 1012, one.mac.listedBounds(of: window).text)
      one.heard.clear()
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 500, y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.04, rest: 0.02)
      one.mac.pass(0.5)
      one.mac.moveMouse(to: CGPoint(x: 1021, y: 332))
      one.mac.pass(0.2)
      one.mac.release()
      one.mac.pass(0.5)
      one.mac.pressShowDesktopKey()
      one.mac.pass(2)
      nothingIsMadeOfIt(story, one)
      story.check("Arbor knows where the window is", one.snapshot(window)?.frame == frame, "\(one.snapshot(window)?.frame.text ?? "")")
    }
  }

  // J1b. What a person sees of J1, with the real controller.
  for tiling in [true, false] {
    for docked in [false, true] {
      for (name, prepare) in [latenesses[0], latenesses[2], latenesses[3]] {
        book.story("judge: J1b macOS's tiling \(tiling ? "on" : "off"), the desktop is shown, a rubber band from over the left edge of a \(docked ? "docked" : "floating") window is thrown to the right edge, \(name)") { story in
          var window: FakeMac.Window!, other: FakeMac.Window!
          let two = StoreyTwo(story) { mac in
            mac.macOSTilesDraggedWindows = tiling
            other = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 100, width: 400, height: 400))
            window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 560, y: 100, width: 400, height: 400))
          }
          if docked { story.check("arranged", two.run("arrange").ok && two.isDocked(window) && two.isDocked(other), two.whereabouts(window)) }
          let (home, otherHome) = (window.frame, other.frame)
          two.mac.pressShowDesktopKey()
          two.mac.pass(1)
          story.check("it is swept to the right", two.mac.listedBounds(of: window).minX == 1012, two.mac.listedBounds(of: window).text)
          let shown = two.overlays.previewHistory.count
          let asked = window.timesAskedForAFrame + other.timesAskedForAFrame
          prepare(two.mac)
          two.mac.drag(from: CGPoint(x: home.minX + 3, y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.04, rest: 0.02)
          two.mac.pass(0.5)
          two.mac.moveMouse(to: CGPoint(x: 1021, y: 332))
          two.mac.pass(0.3)
          two.mac.release()
          two.mac.pass(0.5)
          two.mac.pressShowDesktopKey()
          two.mac.pass(3)
          story.check("no drag is reported", !two.heard.all.contains(.dragBegan(window.number)), two.heard.outline.map(\.text).joined(separator: ", "))
          let previews = two.overlays.previewHistory.dropFirst(shown).compactMap { $0 }
          story.check("no preview was shown", previews.isEmpty, previews.map(\.text).joined(separator: "; "))
          story.check("Arbor asked no window for a frame", window.timesAskedForAFrame + other.timesAskedForAFrame == asked, "\(window.timesAskedForAFrame + other.timesAskedForAFrame - asked) times")
          story.check("it is \(docked ? "docked" : "floating") as before", two.isDocked(window) == docked)
          story.check("both windows are where they were", window.frame == home && other.frame == otherHome, "\(two.whereabouts(window)), was \(home.text); \(two.whereabouts(other)), was \(otherHome.text)")
          let believed = two.controller.snapshot().windows.first { $0.id.rawValue == window.number }?.frame
          story.check("Arbor believes it where it is", believed == window.frame, "\(believed?.text ?? "nil")")
        }
      }
    }
  }

  // J1d. The same, and the hand goes on: back from the edge to the left half of the display, rests there and lets go. (An icon is dragged about; a rubber band is drawn wide and narrowed.)
  for docked in [false, true] {
    for (name, prepare) in [latenesses[0], latenesses[1], latenesses[3]] {
      book.story("judge: J1d the desktop is shown, a hand goes from over the left edge of a \(docked ? "docked" : "floating") window to the right edge of the display, back to the left half, and lets go, \(name)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          other = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 100, width: 400, height: 400))
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 560, y: 100, width: 400, height: 400))
        }
        if docked { story.check("arranged", two.run("arrange").ok && two.isDocked(window) && two.isDocked(other), two.whereabouts(window)) }
        let (home, otherHome) = (window.frame, other.frame)
        two.mac.pressShowDesktopKey()
        two.mac.pass(1)
        let shown = two.overlays.previewHistory.count
        prepare(two.mac)
        two.mac.drag(from: CGPoint(x: home.minX + 3, y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.04, rest: 0.02)
        two.mac.pass(0.3)
        for step in 1...10 {
          two.mac.moveMouse(to: CGPoint(x: 1020 - (1020 - otherHome.minX - 40) * CGFloat(step) / 10, y: 330))
          two.mac.pass(0.05)
        }
        two.mac.pass(1.2)
        two.mac.release()
        two.mac.pass(0.5)
        two.mac.pressShowDesktopKey()
        two.mac.pass(3)
        story.check("no drag is reported", !two.heard.all.contains(.dragBegan(window.number)), two.heard.outline.map(\.text).joined(separator: ", "))
        let previews = two.overlays.previewHistory.dropFirst(shown).compactMap { $0 }
        story.check("no preview was shown", previews.isEmpty, previews.map(\.text).joined(separator: "; "))
        story.check("it is \(docked ? "docked" : "floating") as before", two.isDocked(window) == docked)
        story.check("both windows are where they were", window.frame == home && other.frame == otherHome, "\(two.whereabouts(window)), was \(home.text); \(two.whereabouts(other)), was \(otherHome.text)")
      }
    }
  }

  // J1e. What becomes of the wrong belief about a floating window (J1b): commands given afterwards.
  for command in ["pause", "show-all", "arrange", "dock 102 left", "focus 101", "zoom-out", "quit"] {
    for (name, prepare) in [latenesses[0], latenesses[2]] {
      book.story("judge: J1e after the rubber band over a floating window's left edge to its strip, \(command), \(name)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window!
        let two = StoreyTwo(story) { mac in
          other = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 100, width: 400, height: 400))
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 560, y: 100, width: 400, height: 400))
        }
        let home = window.frame
        two.mac.pressShowDesktopKey()
        two.mac.pass(1)
        prepare(two.mac)
        two.mac.drag(from: CGPoint(x: home.minX + 3, y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.04, rest: 0.02)
        two.mac.pass(0.8)
        two.mac.release()
        two.mac.pass(0.5)
        two.mac.pressShowDesktopKey()
        two.mac.pass(3)
        let result = two.run(command, then: 3)
        _ = other
        story.check("WHERE: \(two.whereabouts(window)); \(two.whereabouts(other)); docked \(two.isDocked(window)); ok \(result.ok)", true)
      }
    }
  }

  // J2. A stubborn window (traces stubborn-fast, stubborn-slow) goes back to where it was 0.2 s after Arbor moved it, while Arbor's main thread is busy. Somebody selects text in it meanwhile,
  // the way it goes back.
  for distance in [20, 60, 90, 150] {
    for (name, prepare) in latenesses {
      book.story("judge: J2 a stubborn window goes back \(distance) points while text is selected in it the same way, \(name)") { story in
        var window: FakeMac.Window!
        let home = CGRect(x: 300, y: 100, width: 500, height: 400)
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: home) }
        window.goesBackAfter = 0.2
        _ = one.layer.setFrame(home.offsetBy(dx: -CGFloat(distance), dy: 0), of: WindowID(window.number))
        one.mac.pass(0.05)
        one.heard.clear()
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 400, y: 300), to: CGPoint(x: 600, y: 310), steps: 8, interval: 0.04, rest: 0.02)
        one.mac.pass(0.5)
        for step in 1...4 {
          one.mac.moveMouse(to: CGPoint(x: 600 + 5 * CGFloat(step), y: 310))
          one.mac.pass(0.1)
        }
        one.mac.release()
        one.mac.pass(2)
        story.check("the window went back", window.bounds == home, window.bounds.text)
        nothingIsMadeOfIt(story, one)
      }
    }
  }

  // J2b. The author's rubber band from the wallpaper to a window, but its app moves it BEFORE the press is served, the pointer's way.
  for (name, prepare) in latenesses {
    book.story("judge: J2b the button goes down on the wallpaper, the pointer comes to a window whose app has moved it 40 points the same way meanwhile, \(name)") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 100, width: 400, height: 300)) }
      prepare(one.mac)
      one.mac.press(at: CGPoint(x: 100, y: 500))
      one.mac.pass(0.03)
      one.mac.moveMouse(to: CGPoint(x: 200, y: 430))
      one.mac.pass(0.03)
      one.mac.appMoves(window, to: CGRect(x: 340, y: 80, width: 400, height: 300))
      one.mac.moveMouse(to: CGPoint(x: 300, y: 370))
      one.mac.pass(0.03)
      one.mac.moveMouse(to: CGPoint(x: 400, y: 300))
      one.mac.pass(0.6)
      for step in 1...4 {
        one.mac.moveMouse(to: CGPoint(x: 400 + 5 * CGFloat(step), y: 300))
        one.mac.pass(0.1)
      }
      one.mac.release()
      one.mac.pass(2)
      nothingIsMadeOfIt(story, one)
    }
  }

  // J3. A window that starts late (seen on a hosted Mac), alone on the display, held by the middle of its title bar. The pointer is at its left edge when the press is served.
  for distance in [60, 90, 120, 195] {
    for (name, prepare) in latenesses {
      book.story("judge: J3 the window starts 400 ms late, the pointer \(distance) points along its title bar at its left edge by then, \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 100, width: 400, height: 300)) }
        one.mac.serverFollowsPointerAfter = 0.4
        prepare(one.mac)
        let start = CGPoint(x: 305 + CGFloat(distance), y: 114)
        one.mac.press(at: start)
        one.mac.pass(0.05)
        for step in 1...4 {
          one.mac.moveMouse(to: CGPoint(x: start.x - CGFloat(distance) * CGFloat(step) / 4, y: 114))
          one.mac.pass(0.05)
        }
        one.mac.pass(0.2)
        for part in 1...12 {
          one.mac.moveMouse(to: CGPoint(x: 305 - 10 * CGFloat(part), y: 114 + 15 * CGFloat(part)))
          one.mac.pass(0.08)
        }
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // J4. The window server has a dragged window a step further than the pointer (a hosted Mac: 67 points), and the press is served late.
  for (name, prepare) in latenesses {
    book.story("judge: J4 a window is dragged sideways in steps of 60 points, the window server a step ahead of the pointer, \(name)") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300)) }
      one.mac.serverRunsAStepAhead = true
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 300, y: 112), to: CGPoint(x: 780, y: 112), steps: 8, interval: 0.1, rest: 0.1)
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
    }
  }

  // J6. A window is held by the middle of its title bar, 12 points below its top, and dragged up and away; served a little late, the pointer is within 10 points of the top edge.
  for late in [0, 10, 20, 40, 80] {
    book.story("judge: J6 a window is dragged up by its title bar, the window server 100 ms behind the pointer, the press heard \(late) ms late") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 300, width: 400, height: 300)) }
      one.mac.serverLagsPointerBy = 0.1
      one.mac.mouseDownIsLateBy = Double(late) / 1000
      one.mac.drag(from: CGPoint(x: 500, y: 314), to: CGPoint(x: 500, y: 114), steps: 40, interval: 0.01, rest: 0.005)
      one.mac.pass(0.3)
      one.mac.release()
      one.mac.pass(3)
      drags(story, one, window)
      story.check("no resize", !one.heard.all.contains(.resizeBegan(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
    }
  }
}
