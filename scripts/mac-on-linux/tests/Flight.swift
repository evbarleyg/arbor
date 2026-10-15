import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// The flight to the Dock. Half a second in which the window's whole app is deaf, at the end of which the app names its next window, and after which `AXRaise` fetches the window out again (`FakeMac.minimize` has the
// measurements, what was varied in them and what was not).

@MainActor
func tellOfTheFlightToTheDock(_ book: Book) {
  // The model held to the probe, round for round, with nothing of Arbor's between: the calls are the probe's.
  book.story("the model's flight to the Dock is the one that was measured") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Notes")
      b = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
      a = mac.open("a", in: app, frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    }
    let mac = one.mac
    let began = mac.now
    mac.minimize(a)
    mac.pass(0.1)
    story.check("a tenth of a second on, the window server has it on screen, in a wider box", mac.isShowing(a) && a.bounds.width > 500 && a.bounds.origin == a.frame.origin, a.bounds.text)
    let answer = mac.read("AXMinimized", of: b.element, timeout: 1)
    story.check("a question about its SIBLING, asked in flight, is answered when the flight is over", answer.answer == .success && abs(mac.now - began - 0.55) < 0.01, "\(answer.answer) after \(mac.now - began) s")
    story.check("by then the window itself says that it is minimized", a.isMinimized)
    mac.pass(1)
    story.check("AXMain does nothing to it", mac.write(.bool(true), to: "AXMain", of: a.element, timeout: 1) == .success && a.isMinimized && mac.keyWindow === b)
    let raised = mac.now
    story.check("AXRaise fetches it out of the Dock", mac.perform("AXRaise", on: a.element, timeout: 1) == .success && !a.isMinimized)
    story.check("and takes as long as the flight out", abs(mac.now - raised - 0.55) < 0.01, "\(mac.now - raised) s")
  }

  book.story("a window flies to the Dock, and Arbor moves its sibling in mid-flight") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Notes")
      b = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
      a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
    }
    one.mac.minimize(a)
    one.mac.pass(0.1)
    let stoodStill = one.mac.secondsTheMainThreadWaited
    let target = CGRect(x: 12, y: 43, width: 500, height: 650)
    _ = one.layer.setFrame(target, of: WindowID(b.number))
    story.check("Arbor's main thread stands still for the rest of the flight at most", one.mac.secondsTheMainThreadWaited - stoodStill < 0.47, "\(one.mac.secondsTheMainThreadWaited - stoodStill) s")
    one.mac.pass(2)
    story.check("the sibling has the frame", b.frame == target && one.snapshot(b)?.frame == target, b.frame.text)
    story.check("its move counts as Arbor's own", !one.heard.all.contains(.changed(b.number, byUser: true)), one.heard.texts)
    story.check("the app is not written off as one that does not answer", one.layer.setFrame(target.offsetBy(dx: 10, dy: 0), of: WindowID(b.number)) != nil)
  }

  for (when, wait) in [("as soon as its sibling is reported focused", 0.0), ("a second after it has landed", 1.0)] {
    book.story("a window goes to the Dock, and Arbor is asked to give it the keyboard \(when)") { story in
      var a: FakeMac.Window!, b: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        let app = mac.launch("Notes")
        b = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
        a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
      }
      one.mac.minimize(a)
      for _ in 0..<2000 where !one.heard.all.contains(.focused(b.number)) { one.mac.pass(0.0005) }
      story.check("its sibling is reported focused at the end of the flight", one.heard.all.contains(.focused(b.number)) && a.isMinimized, one.heard.texts)
      one.mac.pass(wait)
      let stoodStill = one.mac.secondsTheMainThreadWaited
      one.layer.focus(WindowID(a.number))
      let cost = one.mac.secondsTheMainThreadWaited - stoodStill
      one.mac.pass(2)
      if wait == 0 {
        story.check("it stays in the Dock, where the person has just put it", a.isMinimized, "it is out again")
      } else {
        // Whoever asks for a window that lies in the Dock wants it out.
        story.check("it comes out of the Dock and has the keyboard", !a.isMinimized && one.mac.keyWindow === a, "w\(one.mac.keyWindow?.number ?? 0) has it")
      }
      story.check("and Arbor's main thread has not stood still for a flight", cost < 0.1, "\(cost) s")
    }
  }

  // Storey two.
  for held in [false, true] {
    book.story("the window that fills the view is minimized by hand\(held ? ", and the view is held" : "")") { story in
      var a: FakeMac.Window!, b: FakeMac.Window!, mine: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        let app = mac.launch("Notes")
        b = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
        a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
        mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 400, width: 400, height: 250))
      }
      story.check("three windows are arranged", two.run("arrange").ok)
      two.mac.click(a)
      two.mac.pass(1)
      story.check("one fills the view", two.run("zoom \(a.number)").ok && a.frame.width > 900, two.whereabouts(a))
      if held { story.check("the view is held", two.run("hold").ok) }
      let stoodStill = two.mac.secondsTheMainThreadWaited
      two.mac.minimize(a)
      two.mac.pass(4)
      story.check("it is in the Dock, and stays there", a.isMinimized, "it is out again: \(two.whereabouts(a))")
      story.check("Arbor's main thread has stood still for a tenth of a second at most", two.mac.secondsTheMainThreadWaited - stoodStill < 0.1, "\(two.mac.secondsTheMainThreadWaited - stoodStill) s")
      story.check(
        "the window with the keyboard is in view", two.mac.keyWindow.map { two.isInView($0) } ?? false,
        "w\(two.mac.keyWindow?.number ?? 0): \(two.mac.keyWindow.map { two.whereabouts($0) } ?? "nobody has it"); \(two.whereabouts(b)); \(two.whereabouts(mine))")
    }
  }

  // The longest flight that was measured is longer than the patience of a layer that gives each app a lane and waits half a second for it.
  for (gap, flight) in [(0.1, 0.55), (0.4, 0.55), (0.01, 0.66)] {
    book.story("the view moves \(gap) s into the flight of a docked window to the Dock\(flight > 0.55 ? ", which takes \(flight) s" : "")") { story in
      var a: FakeMac.Window!, b: FakeMac.Window!, mine: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        let app = mac.launch("Notes")
        b = mac.open("b", in: app, frame: CGRect(x: 560, y: 60, width: 400, height: 300))
        a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
        mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 400, width: 400, height: 250))
      }
      story.check("three windows are arranged", two.run("arrange").ok)
      two.mac.click(a)
      two.mac.pass(1)
      two.mac.timing.minimizing = flight
      two.mac.minimize(a)
      two.mac.pass(gap)
      let (began, stoodStill) = (two.mac.now, two.mac.secondsTheMainThreadWaited)
      story.check("the command is taken", two.run("zoom \(mine.number)", then: 0).ok)
      story.check("and answered by the end of the flight", two.mac.now - began < flight + 0.05 - gap, "\(two.mac.now - began) s")
      two.mac.pass(3)
      // The rest of the flight, the 50 ms or so that Arbor's own work on such a command costs here, and room for a few calls more (0.7 ms each): the check is for a second wait, not for a call.
      story.check("in all, Arbor's main thread has stood still for the rest of the flight at most", two.mac.secondsTheMainThreadWaited - stoodStill < flight + 0.07 - gap, "\(two.mac.secondsTheMainThreadWaited - stoodStill) s")
      story.check("the window that was asked for fills the view", mine.frame.width > 900, two.whereabouts(mine))
      story.check("the sibling is out of view", two.isOutOfView(b), two.whereabouts(b))
      story.check("the window is in the Dock", a.isMinimized)
      two.run("show-all", then: 3)
      story.check("shown again, the two that are left share the room", two.isInView(b) && two.isInView(mine) && !b.frame.intersects(mine.frame), "\(two.whereabouts(b)); \(two.whereabouts(mine))")
    }
  }
}
