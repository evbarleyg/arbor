import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// macOS shows its desktop, and a press on the strip of a window that still shows brings the windows back, with the button down. On a hosted Mac Arbor took that for
// a drag (collab/reports/2026-10-14-the-desktop-is-shown.md). What no Mac can be asked for: the same press served late, when a window that is really in the
// hand looks much the same (LostDrags.swift): listed far from where its app last had it. But the way the pointer went, and a strip can only be pulled the other way.

private let left = CGRect(x: 12, y: 43, width: 400, height: 600)
private let right = CGRect(x: 600, y: 43, width: 412, height: 600)
/// On the twelve points of the left window that still show.
private let strip = CGPoint(x: 6, y: 300)

@MainActor
private func stage(_ story: Story) -> (StoreyOne, FakeMac.Window) {
  var window: FakeMac.Window!
  let one = StoreyOne(story) { mac in
    _ = mac.open("other", in: mac.launch("Safari"), frame: right)
    window = mac.open("window", in: mac.launch("Notes"), frame: left)
  }
  one.mac.pressShowDesktopKey()
  one.mac.pass(1)
  story.check("the window server lists the window aside, and Accessibility has it where it is",
    one.mac.listedBounds(of: window).maxX == 12 && one.snapshot(window)?.frame == left, one.mac.listedBounds(of: window).text)
  return (one, window)
}

/// No hand is quite still: a click that slips by three points. Or a pull at the strip, 150 points into the display.
@MainActor
private func play(_ one: StoreyOne, pull: Bool) {
  if pull {
    one.mac.drag(from: strip, to: CGPoint(x: strip.x + 150, y: strip.y + 20), steps: 10, interval: 0.03, rest: 0.01)
  } else {
    one.mac.drag(from: strip, to: CGPoint(x: strip.x + 3, y: strip.y + 3), steps: 2, interval: 0.05, rest: 0.01)
  }
  one.mac.pass(0.2)
  one.mac.release()
  one.mac.pass(2)
}

@MainActor
private func judge(_ story: Story, _ one: StoreyOne, _ window: FakeMac.Window, at frame: CGRect = left) {
  let heard = one.heard.all.filter {
    switch $0 {
    case .dragBegan, .dragEnded, .dragCancelled, .resizeBegan, .resizeEnded, .changed(_, byUser: true): true
    default: false
    }
  }
  story.check("the windows are back", one.mac.sweptTo == nil && one.mac.listedBounds(of: window) == frame, one.mac.listedBounds(of: window).text)
  story.check("no drag, no resize, and no window moved by hand is reported", heard.isEmpty, heard.map(\.text).joined(separator: ", "))
  story.check("Arbor knows where the window is", one.snapshot(window)?.frame == frame, "\(one.snapshot(window)?.frame.text ?? "")")
}

@MainActor
func tellOfTheDesktopShown(_ book: Book) {
  for pull in [false, true] {
    let gesture = "macOS shows its desktop, and " + (pull ? "a window is pulled at by its strip" : "a click on a window's strip slips by three points")

    for late in [0, 20, 100, 500] {
      book.story("\(gesture), and the monitor hears of the press \(late) ms late") { story in
        let (one, window) = stage(story)
        one.mac.mouseDownIsLateBy = Double(late) / 1000
        play(one, pull: pull)
        judge(story, one, window)
      }
    }

    for order in [FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst] {
      book.story("\(gesture) while Arbor's main thread is busy for 300 ms from the press, and what queued up comes \(order)") { story in
        let (one, window) = stage(story)
        one.mac.arborIsBusy(for: 0.3, then: order)
        play(one, pull: pull)
        judge(story, one, window)
      }
    }
  }

  // 27 ms were measured on a Mac at rest, and a press is served late on a loaded one. With the list still as it was, a pointer that has gone as far as the window
  // was swept has gone the other way.
  for late in [0, 100, 300] {
    book.story("macOS shows its desktop and takes 400 ms to bring the windows back, and a window is pulled at by its strip as far as it was swept, heard \(late) ms late") { story in
      let (one, window) = stage(story)
      one.mac.stripBringsBackAfter = 0.4
      one.mac.mouseDownIsLateBy = Double(late) / 1000
      one.mac.drag(from: strip, to: CGPoint(x: strip.x + 390, y: strip.y + 10), steps: 10, interval: 0.03, rest: 0.01)
      one.mac.pass(0.4)
      one.mac.release()
      one.mac.pass(2)
      judge(story, one, window)
    }
  }

  // The list goes on showing the size the window had, so it comes back with another: by the sizes alone, a hand at its edge.
  for late in [0, 20, 100] {
    book.story("macOS shows its desktop, a window is given another frame meanwhile, and a click on its strip slips, heard \(late) ms late") { story in
      let (one, window) = stage(story)
      let frame = CGRect(x: 12, y: 43, width: 300, height: 500)
      _ = one.layer.setFrame(frame, of: WindowID(window.number))
      one.mac.pass(1)
      story.check("the frame is taken, and nothing of it shows", window.frame == frame && one.mac.listedBounds(of: window).size == left.size, window.frame.text)
      one.mac.mouseDownIsLateBy = Double(late) / 1000
      play(one, pull: false)
      judge(story, one, window, at: frame)
    }
  }

  // What a person sees of it: strips lie at the edges of the display, where Arbor docks.
  for late in [0, 100] {
    book.story("macOS shows its desktop, and a click on a floating window's strip slips and rests, heard \(late) ms late") { story in
      var window: FakeMac.Window!
      let two = StoreyTwo(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 40, y: 100, width: 400, height: 300)) }
      two.mac.pressShowDesktopKey()
      two.mac.pass(1)
      two.mac.mouseDownIsLateBy = Double(late) / 1000
      let shown = two.overlays.previewHistory.count
      two.mac.drag(from: CGPoint(x: 6, y: 250), to: CGPoint(x: 9, y: 253), steps: 2, interval: 0.05, rest: 0.01)
      two.mac.pass(0.8)
      two.mac.release()
      two.mac.pass(2)
      story.check("no preview was shown", two.overlays.previewHistory.count == shown)
      story.check("it floats where it was", !two.isDocked(window) && window.frame == CGRect(x: 40, y: 100, width: 400, height: 300), two.whereabouts(window))
    }
  }
}
