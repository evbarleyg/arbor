import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// From one display to another. For a moment after a position call has taken a window to another display, macOS judges how far it may grow by the display it came from; and a position call that takes a window to a display
// lower than itself cuts it (`FakeMac.roomToGrow`, `setPosition`: measured by a probe on a hosted Mac, with the displays of these stories).

private let large = FakeMac.Screen(id: 1, name: "Large", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 0, y: 31, width: 1920, height: 971))
private func small(_ side: String) -> FakeMac.Screen {
  let origin = ["right": CGPoint(x: 1920, y: 0), "left": CGPoint(x: -800, y: 0), "below": CGPoint(x: 0, y: 1080)][side]!
  return FakeMac.Screen(id: 2, name: "Small", frame: CGRect(origin: origin, size: CGSize(width: 800, height: 600)), visibleFrame: CGRect(x: origin.x, y: origin.y + 31, width: 800, height: 569))
}

@MainActor
func tellOfTwoDisplays(_ book: Book) {
  // The model held to the probe, line for line (grow.jsonl: 964 to 977, 1077 to 1080, 1095 to 1108). With the small display below the Dock went there on the Mac; here it stays, so that side is not held to the lines.
  for side in ["right", "left"] {
    book.story("the model's two displays are those that were measured, the small one to the \(side)") { story in
      var window: FakeMac.Window!
      let x: CGFloat = side == "right" ? 1932 : -788
      let one = StoreyOne(story) { mac in
        mac.setScreens([large, small(side)])
        window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: x, y: 43, width: 776, height: 545))
      }
      let mac = one.mac
      @MainActor func size(_ width: CGFloat, _ height: CGFloat) -> String {
        _ = mac.write(.size(CGSize(width: width, height: height)), to: "AXSize", of: window.element, timeout: 1)
        return window.frame.text
      }
      @MainActor func place(_ x: CGFloat, _ y: CGFloat) -> String {
        _ = mac.write(.point(CGPoint(x: x, y: y)), to: "AXPosition", of: window.element, timeout: 1)
        return window.frame.text
      }
      story.check("on the small display it grows to that display's edges, whole: no Dock is there", size(1000, 650) == "\(Int(x)),43 788×557", window.frame.text)
      story.check("it goes to the large one as it is", place(12, 43) == "12,43 788×557", window.frame.text)
      story.check("asked at once, it grows as far as the display it came from would let it", size(1000, 650) == "12,43 1000×557", window.frame.text)
      mac.pass(0.35)
      story.check("and stays so", window.frame.text == "12,43 1000×557", window.frame.text)
      story.check("asked again a third of a second later, it takes all", size(1000, 650) == "12,43 1000×650", window.frame.text)
      mac.pass(1)
      if side == "left" {
        one.heard.clear()
        story.check("sent to the small display, which is lower than it, it is cut to that display's visible height, at its visible top", place(-788, 43) == "-788,31 1000×569", window.frame.text)
      }
    }
  }

  for side in ["right", "left", "below"] {
    for docked in [true, false] {
      book.story("a \(docked ? "docked" : "floating") window is sent from a display of 800×600 to one of 1920×1080, which has the small one to its \(side == "below" ? "south" : side)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window!
        let little = small(side)
        let two = StoreyTwo(story) { mac in
          mac.setScreens([large, little])
          other = mac.open("other", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 600, height: 400))
          window = mac.open("window", in: mac.launch("Mine"), frame: CGRect(x: little.frame.minX + 60, y: little.frame.minY + 80, width: 500, height: 400))
        }
        if docked {
          story.check("it is docked on the small display", two.run("dock \(window.number) left").ok && two.isDocked(window), two.whereabouts(window))
          story.check("a window is docked on the large one", two.run("dock \(other.number) left").ok && two.isDocked(other), two.whereabouts(other))
        }
        story.check("the command is taken", two.run("move-to-display next \(window.number)", then: 3).ok)
        story.check("it is on the large display", large.frame.contains(window.frame), two.whereabouts(window))
        let id = WindowID(window.number)
        let main = two.layer.displays().first { $0.frame == large.frame }!.id
        @MainActor func fills() -> (Bool, String) {
          let place = two.controller.freshLayout(of: main)?.windowFrames[id]
          return (place == window.frame, "\(two.whereabouts(window)); Arbor's place for it is \(place?.text ?? "none")")
        }
        if docked {
          story.check("docked there", two.isDocked(window))
          story.check("three seconds later it fills the place Arbor has for it", fills().0, fills().1)
          two.mac.pass(10)
          story.check("left alone for ten seconds more, it fills it", fills().0, fills().1)
        } else {
          story.check("in its own size", window.frame.size == CGSize(width: 500, height: 400), two.whereabouts(window))
        }
        if docked {
          // What is remembered of the short answer. `stoppedAt` is "the width and the height it stopped at when it was offered more".
          let seen = two.controller.seenSizes[id]
          story.check("the short answer is not written down as where the app stops growing", (seen?.stoppedAt ?? .zero) == .zero, "stopped at \(seen.map { "\(Int($0.stoppedAt.width))×\(Int($0.stoppedAt.height))" } ?? "")")
        }
        story.check("Arbor knows where it is", two.controller.windows[id]?.frame == window.frame, "\(two.controller.windows[id]?.frame.text ?? "") against \(window.frame.text)")
        if docked {
          two.run("zoom \(other.number)", then: 2)
          two.run("show-all", then: 3)
          story.check("after the view has been away and come back it fills it", fills().0, fills().1)
        }
      }
    }
  }

  // A display goes, or comes back. macOS moves the windows itself, 20 to 150 ms after its word on the displays, to frames it remembers, and Arbor acts 1.65 s after that word (17 recordings of a hosted Mac with one virtual
  // display, 2026-10-15). So Arbor's own calls take no window from one display to another here. WHERE macOS puts a window is the story's telling: the model does not work it out.
  for (what, side) in [("the small display goes", "right"), ("the small display goes", "below"), ("the large display goes and comes back", "right")] {
    book.story("a window is docked on each of two displays, 1920×1080 and 800×600 to its \(side == "below" ? "south" : side), and \(what)") { story in
      var onSmall: FakeMac.Window!, onLarge: FakeMac.Window!
      let little = small(side)
      let two = StoreyTwo(story) { mac in
        mac.setScreens([large, little])
        onLarge = mac.open("on the large", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 600, height: 400))
        onSmall = mac.open("on the small", in: mac.launch("Mine"), frame: CGRect(x: little.frame.minX + 60, y: little.frame.minY + 80, width: 500, height: 400))
      }
      story.check("both are docked", two.run("dock \(onSmall.number) left").ok && two.run("dock \(onLarge.number) left").ok && two.isDocked(onSmall) && two.isDocked(onLarge))
      let homes = (onLarge.frame, onSmall.frame)
      @MainActor func misfits(_ windows: [FakeMac.Window]) -> String {
        var places: [UInt32: CGRect] = [:]
        for display in two.layer.displays() { for (id, place) in two.controller.freshLayout(of: display.id)?.windowFrames ?? [:] { places[id.rawValue] = place } }
        return windows.filter { places[$0.number] != nil && places[$0.number] != $0.frame }.map { "\(two.whereabouts($0)); Arbor's place for it is \(places[$0.number]!.text)" }.joined(separator: "; ")
      }
      if what.hasPrefix("the small") {
        two.mac.setScreens([large])
        two.mac.later(0.12) { two.mac.appMoves(onSmall, to: CGRect(x: 700, y: 120, width: homes.1.width, height: homes.1.height)) }
        two.mac.pass(6)
        story.check("both are on the display that is left", large.frame.contains(onSmall.frame) && large.frame.contains(onLarge.frame), "\(two.whereabouts(onSmall)); \(two.whereabouts(onLarge))")
        story.check("whatever is docked fills the place Arbor has for it", misfits([onSmall, onLarge]).isEmpty, misfits([onSmall, onLarge]))
      } else {
        // The small one is the only one now, and has the menu bar; its coordinates begin at 0,0.
        let alone = FakeMac.Screen(id: 2, name: "Small", frame: CGRect(x: 0, y: 0, width: 800, height: 600), visibleFrame: CGRect(x: 0, y: 31, width: 800, height: 506))
        two.mac.setScreens([alone])
        two.mac.later(0.12) {
          two.mac.appMoves(onSmall, to: homes.1.offsetBy(dx: -little.frame.minX, dy: 0))
          two.mac.appMoves(onLarge, to: CGRect(x: 100, y: 31, width: min(homes.0.width, 800), height: 506))
        }
        two.mac.pass(6)
        story.check("both are on the display that is left", alone.frame.contains(onSmall.frame) && alone.frame.contains(onLarge.frame), "\(two.whereabouts(onSmall)); \(two.whereabouts(onLarge))")
        two.mac.setScreens([large, little])
        two.mac.later(0.12) {
          two.mac.appMoves(onSmall, to: homes.1)
          two.mac.appMoves(onLarge, to: homes.0)
        }
        two.mac.pass(6)
        story.check("each is on its own display again", large.frame.contains(onLarge.frame) && little.frame.contains(onSmall.frame), "\(two.whereabouts(onSmall)); \(two.whereabouts(onLarge))")
        story.check("whatever is docked fills the place Arbor has for it", misfits([onSmall, onLarge]).isEmpty, misfits([onSmall, onLarge]))
      }
    }
  }
}
