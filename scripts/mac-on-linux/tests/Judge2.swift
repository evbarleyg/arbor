import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// The judge's second round, against `WindowGrab.hold` as it stood after the first: `desktopIsShown`, the upper 60 points, the 10 points. By themselves: --only "judge2: K".

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
  story.check("no resize", !one.heard.all.contains(.resizeBegan(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
}

@MainActor
private func resizes(_ story: Story, _ one: StoreyOne, _ window: FakeMac.Window) {
  story.check("no drag", !one.heard.all.contains { if case .dragBegan = $0 { true } else { false } }, one.heard.outline.map(\.text).joined(separator: ", "))
  story.check("the resize is reported", one.heard.all.contains(.resizeBegan(window.number)) && one.heard.all.contains(.resizeEnded(window.number)), one.heard.outline.map(\.text).joined(separator: ", "))
}

@MainActor
func tellOfTheJudgesSecondRound(_ book: Book) {
  let latenesses: [(String, (FakeMac) -> Void)] = [
    ("served on time", { _ in }),
    ("the press heard 150 ms late", { $0.mouseDownIsLateBy = 0.15 }),
    ("the press heard 300 ms late", { $0.mouseDownIsLateBy = 0.3 }),
    ("the press heard 500 ms late", { $0.mouseDownIsLateBy = 0.5 }),
    ("Arbor busy for 300 ms, then byTime", { $0.arborIsBusy(for: 0.3, then: .byTime) }),
    ("Arbor busy for 300 ms, then accessibilityFirst", { $0.arborIsBusy(for: 0.3, then: .accessibilityFirst) }),
    ("Arbor busy for 300 ms, then mouseFirst", { $0.arborIsBusy(for: 0.3, then: .mouseFirst) }),
  ]

  // K1. The only window in view is carried to an edge of the display, where Arbor docks: less than a quarter of it is left on the display when the press is served. That is what
  // `SweptAside.isSwept` calls a sweep: one aside, none in place.
  for others in [0, 1] {
    for (edge, goal) in [("right", CGPoint(x: 1015, y: 300)), ("bottom", CGPoint(x: 400, y: 760)), ("left", CGPoint(x: 8, y: 300))] {
      for (name, prepare) in latenesses {
        book.story("judge2: K1 a window\(others == 0 ? ", the only one in view," : " beside another") is carried briskly to the \(edge) edge of the display and held there, \(name)") { story in
          var window: FakeMac.Window!
          let one = StoreyOne(story) { mac in
            if others > 0 { _ = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 420, width: 300, height: 200)) }
            window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 100, width: 400, height: 300))
          }
          prepare(one.mac)
          // By the end of the title bar that goes first, so that most of the window leaves the display.
          let start = CGPoint(x: edge == "left" ? 670 : 330, y: 112)
          one.mac.drag(from: start, to: goal, steps: 6, interval: 0.03, rest: 0.02)
          one.mac.pass(1)
          one.mac.release()
          one.mac.pass(3)
          drags(story, one, window)
        }
      }
    }
  }

  // K1b. What a person sees of it: the gesture Arbor is for.
  for (name, prepare) in latenesses {
    book.story("judge2: K1b the only window, floating, is carried briskly to the bottom edge of the display and held there, \(name)") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 100, width: 400, height: 300)) }
      prepare(two.mac)
      two.mac.drag(from: CGPoint(x: 500, y: 112), to: CGPoint(x: 500, y: 762), steps: 6, interval: 0.03, rest: 0.02)
      two.mac.pass(1)
      story.check("a preview shows where it would go", two.overlays.preview != nil)
      two.mac.release()
      two.mac.pass(2)
      story.check("let go, it is docked", two.isDocked(window), two.whereabouts(window))
    }
  }

  // K2. An edge or a corner taken within the window's upper 60 points.
  for (what, start, end) in [
    ("made wider by its left edge, taken 30 points below its top", CGPoint(x: 300, y: 230), CGPoint(x: 180, y: 230)),
    ("made wider by its left edge, taken 55 points below its top", CGPoint(x: 300, y: 255), CGPoint(x: 180, y: 255)),
    ("made wider by its left edge, taken 70 points below its top", CGPoint(x: 300, y: 270), CGPoint(x: 180, y: 270)),
    ("made taller by its top edge by 40 points", CGPoint(x: 500, y: 200), CGPoint(x: 500, y: 160)),
    ("made taller by its top edge by 120 points", CGPoint(x: 500, y: 200), CGPoint(x: 500, y: 80)),
    ("made larger by its top left corner", CGPoint(x: 300, y: 200), CGPoint(x: 200, y: 150)),
    ("made larger by its top right corner", CGPoint(x: 700, y: 200), CGPoint(x: 800, y: 150)),
    ("made wider by its right edge, taken 30 points below its top", CGPoint(x: 700, y: 230), CGPoint(x: 820, y: 230)),
  ] {
    for (name, prepare) in latenesses {
      book.story("judge2: K2 a window is \(what), \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 200, width: 400, height: 300)) }
        prepare(one.mac)
        one.mac.drag(from: start, to: end)
        one.mac.release()
        one.mac.pass(3)
        story.check("it has another size", window.bounds.size != CGSize(width: 400, height: 300), window.bounds.text)
        resizes(story, one, window)
      }
    }
  }

  // K3. The desktop is shown, and a window opens meanwhile, in view (seen on a Mac). One aside, one in place: `isSwept` says no.
  for opened in [1, 2] {
    for (name, prepare) in latenesses {
      book.story("judge2: K3 the desktop is shown, \(opened) window(s) open meanwhile, a rubber band from over a swept window's left edge is thrown to its strip, \(name)") { story in
        var window: FakeMac.Window!
        let frame = CGRect(x: 600, y: 43, width: 412, height: 600)
        var app: FakeMac.App!
        let one = StoreyOne(story) { mac in
          app = mac.launch("Notes")
          window = mac.open("window", in: app, frame: frame)
        }
        one.mac.pressShowDesktopKey()
        one.mac.pass(1)
        for number in 1...opened { _ = one.mac.open("new \(number)", in: app, frame: CGRect(x: 40 + 20 * CGFloat(number), y: 400, width: 300, height: 200)) }
        one.mac.pass(1)
        one.heard.clear()
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 603, y: 300), to: CGPoint(x: 1020, y: 330), steps: 6, interval: 0.02, rest: 0.01)
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
  }

  // K4. A window whose title bar is one with a toolbar and a tab bar, 90 points in all (Safari with tabs), taken by the empty part of it.
  for below in [20, 50, 58, 62, 75, 88] {
    for (name, prepare) in latenesses {
      book.story("judge2: K4 a window with 90 points of title bar and toolbar is dragged sideways by a place \(below) points below its top, \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Safari"), frame: CGRect(x: 100, y: 100, width: 500, height: 400)) }
        window.titleBarHeight = 90
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 300, y: 100 + CGFloat(below)), to: CGPoint(x: 500, y: 100 + CGFloat(below)))
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // K5. A double click on a title bar: the window is zoomed when the button comes up the second time. The pointer then goes away, the way the window's corner went.
  for (name, prepare) in latenesses + [("Arbor busy for 600 ms, then byTime", { $0.arborIsBusy(for: 0.6, then: .byTime) }), ("Arbor busy for 600 ms, then mouseFirst", { $0.arborIsBusy(for: 0.6, then: .mouseFirst) }), ("Arbor busy for 600 ms, then accessibilityFirst", { $0.arborIsBusy(for: 0.6, then: .accessibilityFirst) })] {
    for held in [false, true] {
      book.story("judge2: K5 a title bar is double-clicked, the window is zoomed\(held ? " with the button still down, which then slips the same way" : ", and the pointer goes the way its corner went"), \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 200, width: 400, height: 300)) }
        prepare(one.mac)
        let place = CGPoint(x: 500, y: 212)
        one.mac.press(at: place)
        one.mac.pass(0.06)
        one.mac.release()
        one.mac.pass(0.1)
        one.mac.press(at: place)
        one.mac.pass(0.06)
        if !held { one.mac.release() }
        one.mac.appMoves(window, to: CGRect(x: 220, y: 140, width: 600, height: 500))
        one.mac.pass(0.02)
        for step in 1...4 {
          one.mac.moveMouse(to: CGPoint(x: 500 - 25 * CGFloat(step), y: 212 - 18 * CGFloat(step)))
          one.mac.pass(0.03)
        }
        one.mac.pass(0.3)
        one.mac.release()
        one.mac.pass(3)
        nothingIsMadeOfIt(story, one)
        story.check("Arbor knows where the window is", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
      }
    }
  }

  // K6. The window closes between the press and its being served.
  for below in [false, true] {
    for (name, prepare) in latenesses {
      book.story("judge2: K6 a window\(below ? " over another" : "") is dragged by its title bar and closes 120 ms after the press, the hand going on, \(name)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window?
        let one = StoreyOne(story) { mac in
          if below { other = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 60, width: 900, height: 600)) }
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 200, width: 400, height: 300))
        }
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 500, y: 212), to: CGPoint(x: 580, y: 260), steps: 4, interval: 0.03, rest: 0)
        one.mac.close(window)
        for step in 1...8 {
          one.mac.moveMouse(to: CGPoint(x: 580 + 15 * CGFloat(step), y: 260 + 10 * CGFloat(step)))
          one.mac.pass(0.05)
        }
        one.mac.release()
        one.mac.pass(3)
        let begun = one.heard.all.filter { if case .dragBegan = $0 { true } else { false } }.count
        let over = one.heard.all.filter { if case .dragEnded = $0 { true } else if case .dragCancelled = $0 { true } else { false } }.count
        story.check("it is reported gone", one.heard.all.contains(.destroyed(window.number)), one.heard.texts)
        if let other { story.check("nothing is made of the window below", !grabs(one).contains { $0.window == other.number }, one.heard.texts) }
        let gone = one.heard.all.firstIndex(of: .destroyed(window.number)) ?? one.heard.all.count
        story.check("nothing is reported about it once it is gone", !one.heard.all[gone...].dropFirst().contains { $0.window == window.number }, one.heard.texts)
        _ = (begun, over)
      }
    }
  }

  // K7. ⌘ held: a window that lies behind another is taken along where it lies, and passes under the one in front.
  for (name, prepare) in latenesses {
    book.story("judge2: K7 with ⌘ a window behind another is dragged under it, \(name)") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
        mac.click(mac.open("front", in: mac.launch("Safari"), frame: CGRect(x: 380, y: 60, width: 500, height: 500)))
      }
      one.heard.clear()
      one.mac.setModifierFlags(1 << 20)
      one.mac.pass(0.1)
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 200, y: 112), to: CGPoint(x: 560, y: 212), steps: 10, interval: 0.05, rest: 0.03)
      one.mac.pass(0.3)
      one.mac.release()
      one.mac.setModifierFlags(0)
      one.mac.pass(3)
      story.check("the window has moved", window.bounds.origin == CGPoint(x: 420, y: 200), window.bounds.text)
      drags(story, one, window)
    }
  }

  // K8. The windows come back (the key), and 50 ms later one of them is really taken by its title bar; Arbor is busy from before the key.
  for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
    for busy in [0.0, 0.3, 0.6] {
      book.story("judge2: K8 the windows come back and 50 ms later one is dragged, Arbor busy for \(busy) s from before the key, then \(order)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          _ = mac.open("other", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 400, height: 600))
          window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 600, y: 43, width: 412, height: 600))
        }
        one.mac.pressShowDesktopKey()
        one.mac.pass(1)
        one.heard.clear()
        if busy > 0 { one.mac.arborIsBusy(for: busy, then: order) }
        one.mac.pressShowDesktopKey()
        one.mac.pass(0.05)
        one.mac.drag(from: CGPoint(x: 800, y: 55), to: CGPoint(x: 600, y: 255), steps: 8, interval: 0.04, rest: 0.02)
        one.mac.pass(0.5)
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // K10. The window trails the pointer: macOS holds a dragged window back where edges meet and it does not catch up (the ledger: a pointer that took hold 12 points below the top was 60, 100 and 112
  // points off). Here by a window server that is behind the pointer all through the drag. The pointer is then below the window's upper 60 points.
  for behind in [50, 100, 150] {
    for (name, prepare) in latenesses {
      book.story("judge2: K10 a window is dragged down briskly for a second, the window server \(behind) ms behind the pointer, \(name)") { story in
        var window: FakeMac.Window!
        let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 60, width: 400, height: 200)) }
        one.mac.serverLagsPointerBy = Double(behind) / 1000
        prepare(one.mac)
        one.mac.drag(from: CGPoint(x: 500, y: 72), to: CGPoint(x: 560, y: 672), steps: 20, interval: 0.04, rest: 0.02)
        one.mac.pass(0.3)
        one.mac.release()
        one.mac.pass(3)
        drags(story, one, window)
      }
    }
  }

  // K11. A tall window is dragged UP: it still covers the place of the press, which is then deep in it by its app's word.
  for up in [30, 60, 100, 200] {
    for goesOn in [false, true] {
      for (name, prepare) in latenesses {
        book.story("judge2: K11 a tall window is dragged up by \(up) points in 200 ms and \(goesOn ? "slowly on" : "held still"), \(name)") { story in
          var window: FakeMac.Window!
          let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 300, width: 400, height: 400)) }
          prepare(one.mac)
          one.mac.drag(from: CGPoint(x: 500, y: 312), to: CGPoint(x: 510, y: 312 - CGFloat(up)), steps: 5, interval: 0.04, rest: 0.02)
          if goesOn {
            for step in 1...10 {
              one.mac.moveMouse(to: CGPoint(x: 510 + 4 * CGFloat(step), y: 312 - CGFloat(up) - 2 * CGFloat(step)))
              one.mac.pass(0.08)
            }
          } else {
            one.mac.pass(0.8)
          }
          one.mac.release()
          one.mac.pass(3)
          drags(story, one, window)
        }
      }
    }
  }

  // K9. J2 again, but the text is in the window's upper 60 points: the address field of a browser.
  for (name, prepare) in latenesses {
    book.story("judge2: K9 text is selected in a field 30 points below a window's top while the window goes back 60 points the same way, \(name)") { story in
      var window: FakeMac.Window!
      let home = CGRect(x: 300, y: 100, width: 500, height: 400)
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Safari"), frame: home) }
      window.titleBarHeight = 12
      window.goesBackAfter = 0.2
      _ = one.layer.setFrame(home.offsetBy(dx: -60, dy: 0), of: WindowID(window.number))
      one.mac.pass(0.05)
      one.heard.clear()
      prepare(one.mac)
      one.mac.drag(from: CGPoint(x: 400, y: 130), to: CGPoint(x: 600, y: 132), steps: 8, interval: 0.04, rest: 0.02)
      one.mac.pass(0.5)
      for step in 1...4 {
        one.mac.moveMouse(to: CGPoint(x: 600 + 5 * CGFloat(step), y: 132))
        one.mac.pass(0.1)
      }
      one.mac.release()
      one.mac.pass(2)
      story.check("the window went back", window.bounds == home, window.bounds.text)
      nothingIsMadeOfIt(story, one)
    }
  }
}
