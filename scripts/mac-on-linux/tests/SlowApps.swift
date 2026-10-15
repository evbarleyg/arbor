import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Apps that hang or are slow while Arbor has something to ask of them, and what a person is left with: at a quit, at a pause, when something else happens meanwhile. Told at storey two, by what
// is on the screen, so that they hold for a layer that asks on the main thread and for one that gives each app a lane of its own.
//
// Measured on hosted Macs: a hung app lets a call on the main thread go unanswered for 1.06 s; a call that timed out, after a second or after a tenth, is carried out when the app wakes, a park as well as a
// fetch, AS LONG AS ARBOR'S PROCESS LIVES. What a process has asked is dropped when it ends (`FakeMac.arborIsGone`).

extension StoreyTwo {
  /// The person quits Arbor: it puts things back as well as it can, and its process ends.
  func quit() {
    mac.note("Arbor is asked to quit")
    controller.shutdown()
    mac.arborIsGone()
  }
}

/// One window of mine and two of an app that will be busy, arranged.
@MainActor
private func stage(_ story: Story) -> (StoreyTwo, FakeMac.Window, [FakeMac.Window]) {
  var mine: FakeMac.Window!, theirs: [FakeMac.Window] = []
  let two = StoreyTwo(story) { mac in
    let busy = mac.launch("Busy")
    theirs = [mac.open("a", in: busy, frame: CGRect(x: 500, y: 60, width: 400, height: 300)), mac.open("b", in: busy, frame: CGRect(x: 500, y: 380, width: 400, height: 300))]
    mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
  }
  story.check("three windows are arranged", two.run("arrange").ok && ([mine] + theirs).allSatisfy { two.isDocked($0) })
  return (two, mine, theirs)
}

@MainActor
private func places(_ two: StoreyTwo, _ windows: [FakeMac.Window]) -> String { windows.map { two.whereabouts($0) }.joined(separator: "; ") }

@MainActor
func tellOfSlowApps(_ book: Book) {
  for gap in [0.0, 0.3, 1.0] {
    book.story("Arbor is quit \(gap) s after an app with windows out of view begins to hang") { story in
      let (two, mine, theirs) = stage(story)
      two.run("zoom \(mine.number)")
      story.check("the app's windows are out of view", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
      two.mac.hang(theirs[0].app)
      two.mac.pass(gap)
      let began = two.mac.now
      two.quit()
      story.check("the quit takes four seconds at most", two.mac.now - began <= 4, "\(two.mac.now - began) s")
      two.mac.pass(3)
      two.mac.wake(theirs[0].app)
      two.mac.pass(3)
      story.check("when the app wakes its windows come back into view, though Arbor is gone", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
    }

    book.story("Arbor is paused \(gap) s after an app with windows out of view begins to hang") { story in
      let (two, mine, theirs) = stage(story)
      two.run("zoom \(mine.number)")
      two.mac.hang(theirs[0].app)
      two.mac.pass(gap)
      let began = two.mac.now
      story.check("the pause is taken", two.run("pause", then: 0).ok)
      story.check("within four seconds", two.mac.now - began <= 4, "\(two.mac.now - began) s")
      two.mac.pass(3)
      let woke = two.mac.now
      two.mac.wake(theirs[0].app)
      var back: TimeInterval?
      for _ in 0..<80 where back == nil {
        two.mac.pass(0.5)
        if theirs.allSatisfy({ two.isInView($0) }) { back = two.mac.now - woke }
      }
      story.check("when the app wakes its windows come back into view", back != nil, places(two, theirs))
      story.check("within ten seconds", (back ?? .infinity) <= 10, "\(back.map { "\($0) s" } ?? "never")")
    }
  }

  // Sessions 2 and 3 of scripts/mac-shell/check-hang.sh, second for second, as hosted Macs have played them (macOS 26.6.2, 2026-10-15): arrange, 1 s, zoom, 1 s, the app hangs for 20 s, 0.5 s, quit or pause, and a look
  // 22.5 s after the hang began. At the quit the windows were out of view at that look and for good, with a layer that sent nothing and with one that left word. At the pause they were in view at that look with both:
  // the one that sent nothing fetched them with the controller's fourth try, which was waiting for the app as it woke; the one that left word made no such try, the word had done it.
  for ending in ["quit", "paused"] {
    book.story("as on a hosted Mac: an app with windows out of view hangs for 20 s, and half a second later Arbor is \(ending)") { story in
      let (two, mine, theirs) = stage(story)
      two.mac.pass(1)
      two.run("zoom \(mine.number)", then: 1)
      story.check("the app's windows are out of view", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
      let began = two.mac.now
      two.mac.hang(theirs[0].app, for: 20)
      two.mac.pass(0.5)
      if ending == "quit" { two.quit() } else { two.run("pause", then: 0) }
      story.check("that takes two seconds at most", two.mac.now - began <= 2.5, "\(two.mac.now - began - 0.5) s")
      two.mac.pass(began + 22.5 - two.mac.now)
      story.check("two and a half seconds after the app has woken its windows are in view", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
    }
  }

  // A park that waits in the queue of an app that hangs goes with Arbor's process. One that the app is in the middle of is taken to be carried out after Arbor is gone, which is a guess; one that has been carried
  // out, with the app hanging at the next call, leaves a window out of view that Arbor cannot fetch and cannot leave word for.
  for (seconds, calls, words) in [
    (8.0, Int?.none, "at the beginning of"), (8, 1, "at the first call that sets something in"), (8, 1, "in the middle of carrying out the first call that sets something in"), (8, 2, "at the reading back in"),
    // Short enough that only a layer that does not wait for the app gets to the quit in time; of another the story has not been told, and its second check says so.
    (2, nil, "at the beginning of"), (2, 1, "at the first call that sets something in"),
  ] {
    book.story("an app hangs for \(Int(seconds)) s \(words) a move out of view, and Arbor is quit meanwhile") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      busy.hangsInTheMiddleOfThatCall = words.hasPrefix("in the middle")
      if let calls { busy.hangsAfterCalls = calls } else { two.mac.hang(busy) }
      two.mac.later(seconds) { two.mac.wake(busy) }
      two.run("zoom \(mine.number)", then: 0.3)
      two.quit()
      // Or the story has not been told.
      story.check("Arbor is gone while the app still hangs", busy.isHung)
      two.mac.pass(10)
      story.check("the app is awake again", !busy.isHung)
      story.check("in the end all its windows are in view: nothing that was asked of it in vain takes one away after Arbor is gone", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
    }
  }

  // A layer that remembers for a while what an app has answered may make the park its first call to an app that hangs. From both sides of a second.
  for silence in [0.5, 1.5] {
    book.story("an app hangs \(silence) s after it last answered Arbor, its windows are sent out of view, and Arbor is quit") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      // The last it hears of Arbor: a move, there and back.
      two.run("zoom \(mine.number)", then: 1)
      two.run("show-all", then: 0)
      two.mac.pass(silence)
      two.mac.hang(busy, for: 8)
      two.run("zoom \(mine.number)", then: 0.3)
      two.quit()
      story.check("Arbor is gone while the app still hangs", busy.isHung)
      two.mac.pass(10)
      story.check("in the end all its windows are in view", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
    }
  }

  // The same at a pause, where Arbor lives on and what it has sent is carried out. The park lies in the app's queue; until the app wakes the window server shows the windows in view, and whoever asks it whether
  // they still have to be fetched is told no.
  for silence in [0.5, 1.5] {
    book.story("an app hangs \(silence) s after it last answered Arbor, its windows are sent out of view, and Arbor is paused") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      two.run("zoom \(mine.number)", then: 1)
      two.run("show-all", then: 0)
      two.mac.pass(silence)
      two.mac.hang(busy, for: 8)
      two.run("zoom \(mine.number)", then: 0.3)
      story.check("the pause is taken", two.run("pause", then: 0).ok)
      story.check("while the app still hangs", busy.isHung)
      two.mac.pass(4)
      two.mac.pass(5)
      story.check("the app is awake again", !busy.isHung)
      var back: TimeInterval?
      for half in 0..<80 where back == nil {
        if theirs.allSatisfy({ two.isInView($0) }) { back = Double(half) / 2 }
        two.mac.pass(0.5)
      }
      story.check("once the app has woken, all its windows are in view, or come back", back != nil, places(two, theirs))
      story.check("within ten seconds", (back ?? .infinity) <= 10, "\(back.map { "\($0) s" } ?? "never, in 40 s")")
      two.run("resume", then: 3)
      two.run("show-all", then: 3)
      story.check("and after `resume` they are in view", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
    }
  }

  // At a pause nobody leaves word and goes: Arbor stays, and has to fetch what comes to lie out of view after all.
  for (words, calls) in [("has hung for 2.5 s when", Int?.none), ("hangs between the question and the move as", 1)] {
    book.story("an app \(words) its windows are sent out of view, and Arbor is paused") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      two.mac.pass(2)
      if let calls {
        busy.hangsAfterCalls = calls
      } else {
        two.mac.hang(busy)
        two.mac.pass(2.5)
      }
      two.run("zoom \(mine.number)", then: 3)
      story.check("the app hangs", busy.isHung)
      story.check("the pause is taken", two.run("pause", then: 2.5).ok)
      let woke = two.mac.now
      two.mac.wake(busy)
      var back: TimeInterval?
      for _ in 0..<80 where back == nil {
        two.mac.pass(0.5)
        if theirs.allSatisfy({ two.isInView($0) }) { back = two.mac.now - woke }
      }
      story.check("once the app has woken, all its windows are in view, or come back", back != nil, places(two, theirs))
      story.check("within ten seconds", (back ?? .infinity) <= 10, "\(back.map { "\($0) s" } ?? "never, in 40 s")")
    }
  }

  // Two points: what the Dock gives back when a window leaves it. Too little to count as having strayed.
  book.story("an app carries out 50 ms late what it is asked, and Arbor makes its window two points higher") { story in
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Late")) }
    var target = CGRect(x: 12, y: 43, width: 494, height: 650)
    _ = one.layer.setFrame(target, of: WindowID(window.number))
    one.mac.pass(2)
    window.app.carriesOutAfter = 0.05
    target.size.height += 2
    _ = one.layer.setFrame(target, of: WindowID(window.number))
    one.mac.pass(3)
    story.check("the window has the frame", window.frame == target, window.frame.text)
    story.check("Arbor knows how high it is", one.snapshot(window)?.frame == target, "\(one.snapshot(window)?.frame.text ?? "")")
  }

  // The app says yes at once and does it a moment later, so that what Arbor reads back right after the call is the old frame. Its report, when it comes, is the only word on how things stand.
  for late in [0.02, 0.05, 0.2] {
    let words = "an app carries out \(Int(late * 1000)) ms late what it is asked"
    book.story("\(words), and Arbor gives its window a frame") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Late")) }
      window.app.carriesOutAfter = late
      let target = CGRect(x: 12, y: 43, width: 500, height: 650)
      _ = one.layer.setFrame(target, of: WindowID(window.number))
      one.mac.pass(3)
      story.check("the window has the frame", window.frame == target, window.frame.text)
      story.check("Arbor knows where it is", one.snapshot(window)?.frame == target, "\(one.snapshot(window)?.frame.text ?? "")")
      story.check("nothing of it counts as the person's doing", !one.heard.all.contains(.changed(window.number, byUser: true)), one.heard.texts)
    }

    book.story("\(words), and the view goes to another window and comes back") { story in
      let (two, mine, theirs) = stage(story)
      let homes = theirs.map(\.frame)
      theirs[0].app.carriesOutAfter = late
      two.run("zoom \(mine.number)", then: 3)
      story.check("its windows are out of view", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
      let believed = { (window: FakeMac.Window) in two.controller.windows[WindowID(window.number)]?.frame }
      story.check("and Arbor knows where they are", theirs.allSatisfy { believed($0) == $0.frame }, theirs.map { "w\($0.number): \(believed($0)?.text ?? "") against \($0.frame.text)" }.joined(separator: "; "))
      story.check("still docked: nobody has moved them but Arbor", theirs.allSatisfy { two.isDocked($0) })
      two.run("show-all", then: 3)
      story.check("shown again, they are in their places", zip(theirs, homes).allSatisfy { $0.frame == $1 }, places(two, theirs))
      story.check("and Arbor knows that", theirs.allSatisfy { believed($0) == $0.frame }, theirs.map { "w\($0.number): \(believed($0)?.text ?? "") against \($0.frame.text)" }.joined(separator: "; "))
    }

    book.story("\(words), one of its windows floats, and the view goes to another window and comes back") { story in
      let (two, mine, theirs) = stage(story)
      two.run("float \(theirs[1].number)")
      let home = theirs[1].frame
      theirs[0].app.carriesOutAfter = late
      two.run("zoom \(mine.number)", then: 3)
      story.check("it is out of view with the Desktop", two.isOutOfView(theirs[1]), two.whereabouts(theirs[1]))
      two.run("show-all", then: 3)
      story.check("shown again, it is in view", two.isInView(theirs[1]), two.whereabouts(theirs[1]))
      story.check("where it was", theirs[1].frame == home, "\(two.whereabouts(theirs[1])), it was at \(home.text)")
    }
  }

  // What Arbor reads back right after a move of such an app is the old frame. Whoever then spares a call because the window "is there already" leaves it where the move that is still to be carried out takes it.
  for late in [0.05, 0.2] {
    book.story("an app carries out \(Int(late * 1000)) ms late what it is asked, one of its windows floats, and the view goes to another window and comes back at once") { story in
      let (two, mine, theirs) = stage(story)
      two.run("float \(theirs[1].number)")
      theirs[0].app.carriesOutAfter = late
      two.run("zoom \(mine.number)", then: 0)
      two.run("show-all", then: 5)
      story.check("the one that floats is in view", two.isInView(theirs[1]), two.whereabouts(theirs[1]))
      story.check("so is the docked one", two.isInView(theirs[0]), two.whereabouts(theirs[0]))
    }
  }

  // Found by the walk upstairs under all four (`upstairs, all four|10|resize 21 29; dock 70 20; launch 70 0; zoom 8 96`), told without dice. The app comes forward at once and makes the window main late, so its OTHER window is
  // reported focused first: the view goes there, the Desktop out of view, and back a moment later.
  for late in [0.05, 0.2] {
    book.story("apps carry out \(Int(late * 1000)) ms late what they are asked, and Arbor is asked for a floating window of an app in the background whose docked window had its keyboard") { story in
      let (two, mine, theirs) = stage(story)
      two.run("float \(theirs[1].number)")
      two.run("float \(mine.number)")
      two.mac.click(theirs[0])
      two.mac.pass(1)
      two.mac.click(mine)
      two.mac.pass(1)
      for app in [mine.app, theirs[0].app] { app.carriesOutAfter = late }
      story.check("the command is taken", two.run("zoom \(theirs[1].number)", then: 5).ok)
      story.check("the window that was asked for is in view", two.isInView(theirs[1]), two.whereabouts(theirs[1]))
      story.check("and has the keyboard", two.mac.keyWindow === theirs[1], "w\(two.mac.keyWindow?.number ?? 0) has it")
      story.check("the other floating window is in view with it", two.isInView(mine), two.whereabouts(mine))
    }
  }

  // A reading that the layer passes on upstairs must not set off a correction, whose reading is passed on in its turn. The app that is on time comes first and sets the measure.
  var askedOfAnAppOnTime: Int?
  for late in [0.0, 0.02, 0.05, 0.2] {
    book.story("how often Arbor asks for a frame as the view goes away and comes back, of an app that \(late > 0 ? "carries out \(Int(late * 1000)) ms late what it is asked" : "is on time")") { story in
      let (two, mine, theirs) = stage(story)
      theirs[0].app.carriesOutAfter = late
      let before = theirs.reduce(0) { $0 + $1.timesAskedForAFrame }
      two.run("zoom \(mine.number)", then: 3)
      two.run("show-all", then: 3)
      let asked = theirs.reduce(0) { $0 + $1.timesAskedForAFrame } - before
      if late == 0 { askedOfAnAppOnTime = asked }
      story.check("no oftener than of an app that is on time", asked <= askedOfAnAppOnTime ?? asked, "\(asked) times against \(askedOfAnAppOnTime ?? 0)")
      two.mac.pass(5)
      story.check("and then it has done with them", theirs.reduce(0) { $0 + $1.timesAskedForAFrame } - before == asked, "\(theirs.reduce(0) { $0 + $1.timesAskedForAFrame } - before - asked) times more")
    }
  }

  // The ways out give every window its own earlier frame back. One whose app does not answer at that moment, or is busy with its sibling's move, floats from then on, in view, in the shape of its slot. Whoever remembers what
  // it is owed has to pay it, once, and to forget it as soon as somebody else has had a say.
  let own = [CGRect(x: 500, y: 60, width: 400, height: 300), CGRect(x: 500, y: 380, width: 400, height: 300)]
  for way in ["float-all", "undo"] {
    book.story("`\(way)` while an app with two docked windows takes 0.8 s over every move") { story in
      let (two, _, theirs) = stage(story)
      theirs[0].app.answersIn = 0.12
      story.check("Arbor takes the command", two.run(way, then: 0).ok)
      two.mac.pass(30)
      story.check("both have their own earlier frames back", theirs.map(\.frame) == own, places(two, theirs))
      let asked = theirs.map(\.timesAskedForAFrame)
      two.mac.pass(10)
      story.check("and Arbor has done with them", theirs.map(\.timesAskedForAFrame) == asked, "asked again \(zip(theirs.map(\.timesAskedForAFrame), asked).map { $0 - $1 }) times")
    }
  }
  for (what, slow) in [
    ("nothing else happens", false), ("nothing else happens", true), ("the view goes to my window and comes back", false), ("the view goes to my window and comes back", true), ("the view goes to my window and stays there", false), ("one of them is docked again", false),
    ("one of them is moved by hand", false), ("one of them closes", false), ("one of them is minimized by hand", true), ("Arbor is paused and resumed", false), ("Arbor is paused", false), ("they are arranged again", false),
    ("they are arranged again", true),
  ] {
    book.story("`float-all` while an app with two docked windows \(slow ? "takes 0.8 s over every move" : "hangs for 6 s"), and \(what) meanwhile") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      let slots = theirs.map(\.frame)
      if slow { busy.answersIn = 0.12 } else { two.mac.hang(busy, for: 6) }
      story.check("Arbor takes the command", two.run("float-all", then: slow ? 0.1 : 1).ok)
      var expected: [CGRect?] = own
      let byHand = CGRect(x: 300, y: 200, width: slots[1].width, height: slots[1].height)
      switch what {
      case "the view goes to my window and comes back":
        two.run("dock \(mine.number) left", then: 0.2)
        two.run("zoom \(mine.number)", then: slow ? 3 : 1)
        two.run("show-all", then: 0)
        // With a window docked the Desktop is another, and what floats on it is shifted to fit: the sizes tell.
        expected = [nil, nil]
      case "the view goes to my window and stays there":
        two.run("dock \(mine.number) left", then: 0.2)
        two.run("zoom \(mine.number)", then: 0)
        expected = [nil, nil]
        for window in theirs { window.road.removeAll() }
      case "one of them is docked again":
        two.run("dock \(theirs[1].number) right", then: 0)
        expected[1] = nil
      case "one of them is moved by hand":
        // The window server moves a window by its title bar whether its app answers or not.
        two.mac.drag(from: CGPoint(x: slots[1].midX, y: slots[1].minY + 10), to: CGPoint(x: byHand.midX, y: byHand.minY + 10))
        two.mac.release()
        expected[1] = byHand
      case "one of them closes":
        two.mac.later(5.5) { two.mac.close(theirs[1]) }
        expected[1] = nil
      case "one of them is minimized by hand":
        two.mac.minimize(theirs[1])
        expected[1] = nil
      case "Arbor is paused and resumed":
        two.run("pause", then: 1)
        two.run("resume", then: 0)
      case "Arbor is paused": two.run("pause", then: 0)
      case "they are arranged again":
        two.run("arrange", then: 0)
        expected = [nil, nil]
      default: break
      }
      two.mac.pass(20)
      story.check("the app answers again", !busy.isHung)
      story.check(
        "each is where the last word on it has sent it", zip(theirs, expected).allSatisfy { $1 == nil || $0.frame == $1 },
        zip(theirs, expected).map { "\(two.whereabouts($0)), to be at \($1?.text ?? "wherever")" }.joined(separator: "; "))
      if what.hasSuffix("comes back") { story.check("both are in view, in their own sizes", theirs.allSatisfy { two.isInView($0) && $0.frame.size == own[0].size }, places(two, theirs)) }
      if what.hasSuffix("stays there") {
        story.check("both are out of view, with the Desktop", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
        story.check(
          "and went there in one move, not by way of a place over my window", theirs.allSatisfy { $0.road.count <= 1 },
          theirs.map { window in "w\(window.number): " + window.road.map(\.text).joined(separator: ", then ") }.joined(separator: "; "))
      }
      if what == "they are arranged again" { story.check("both are docked, in view, neither over the other", theirs.allSatisfy { two.isDocked($0) && two.isInView($0) } && !theirs[0].frame.intersects(theirs[1].frame), places(two, theirs)) }
      if what == "one of them is docked again" { story.check("the one that was docked again is docked, in view", two.isDocked(theirs[1]) && two.isInView(theirs[1]), two.whereabouts(theirs[1])) }
      if what == "one of them is minimized by hand" { story.check("the one that was minimized is in the Dock", theirs[1].isMinimized) }
      let (asked, frames) = (theirs.map(\.timesAskedForAFrame), theirs.map(\.frame))
      // A debt that was not paid and not forgotten shows when the app next falls silent and answers again.
      if what.hasSuffix("stays there") {
        two.run("show-all", then: 3)
        story.check("shown again, both are in view, in their own sizes", theirs.allSatisfy { two.isInView($0) && $0.frame.size == own[0].size }, places(two, theirs))
      } else if what != "Arbor is paused" {
        two.mac.hang(busy, for: 3)
        two.run("zoom \(mine.number)", then: 1)
        two.run("show-all", then: 8)
        story.check("after another hang, with the view away and back, each is where it was", theirs.map(\.frame) == frames, places(two, theirs))
      } else {
        two.mac.pass(10)
        story.check("and Arbor asks nothing more of them", theirs.map(\.timesAskedForAFrame) == asked, "asked again \(zip(theirs.map(\.timesAskedForAFrame), asked).map { $0 - $1 }) times")
      }
    }
  }

  // What came of a late move has to be in the books before the app's own report of it is judged.
  for late in [0.0, 0.02] {
    book.story("an app takes 0.7 s to wake in the middle of a move\(late > 0 ? ", and Arbor's main queue has its turn 20 ms late" : "")") { story in
      let (two, mine, theirs) = stage(story)
      two.mac.mainQueueIsLateBy = late
      two.mac.hang(theirs[0].app, for: 0.7)
      two.run("zoom \(mine.number)", then: 6)
      story.check("my window fills the view", mine.frame.width > 900, two.whereabouts(mine))
      story.check("the app's windows are out of view", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
      let asked = theirs.map(\.timesAskedForAFrame)
      two.mac.pass(5)
      story.check("and Arbor has done with them", theirs.map(\.timesAskedForAFrame) == asked, "asked again \(zip(theirs.map(\.timesAskedForAFrame), asked).map { $0 - $1 }) times")
      two.run("show-all", then: 4)
      story.check("shown again, no window lies over another", !theirs[0].frame.intersects(theirs[1].frame) && theirs.allSatisfy { !$0.frame.intersects(mine.frame) && two.isInView($0) }, places(two, theirs + [mine]))
    }
  }

  // Something happens in the app just as it wakes, while Arbor is still busy with what it asked.
  for what in ["opens a window", "resizes a docked window", "gets a new tab"] {
    book.story("an app that was busy for 0.7 s during a move \(what) as it wakes") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      var new: FakeMac.Window?
      // Out of view first, so that showing everything has something to ask of the app.
      two.run("zoom \(mine.number)")
      story.check("the app's windows are out of view", theirs.allSatisfy { two.isOutOfView($0) }, places(two, theirs))
      let asked = theirs.map(\.timesAskedForAFrame)
      two.mac.hang(busy, for: 0.7)
      two.mac.later(0.705) {
        switch what {
        case "opens a window": new = two.mac.open("new", in: busy, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
        case "resizes a docked window": two.mac.appMoves(theirs[1], to: CGRect(origin: theirs[1].frame.origin, size: CGSize(width: theirs[1].frame.width + 60, height: theirs[1].frame.height)))
        default: new = two.mac.newTab(of: theirs[1])
        }
      }
      two.run("show-all", then: 6)
      // Or the story has not been told.
      story.check("Arbor has asked them back", zip(theirs.map(\.timesAskedForAFrame), asked).allSatisfy { $0 > $1 })
      story.check("they are in view again", theirs.filter(\.isFrontTab).allSatisfy { two.isInView($0) }, places(two, theirs))
      switch what {
      case "opens a window":
        story.check("Arbor knows the new window", new.map { two.knows($0) } ?? false)
        story.check("it is in view", new.map { two.isInView($0) } ?? false, new.map { two.whereabouts($0) } ?? "")
      case "resizes a docked window":
        let believed = two.controller.snapshot().windows.first { $0.id.rawValue == theirs[1].number }?.frame
        story.check("Arbor knows how large the window is", believed == theirs[1].frame, "\(believed?.text ?? "") against \(theirs[1].frame.text)")
        story.check("no window lies over another", !theirs[0].frame.intersects(theirs[1].frame) && theirs.allSatisfy { !$0.frame.intersects(mine.frame) }, places(two, theirs + [mine]))
      default:
        story.check("the tab has the place of the window it was opened in", new.map { two.isDocked($0) } ?? false, new.map { two.whereabouts($0) } ?? "")
        story.check("to Arbor the group is one window", !two.knows(theirs[1]))
      }
    }
  }

  book.story("⌘Tab away while Arbor's request for the keyboard waits for a slow app") { story in
    let (two, mine, theirs) = stage(story)
    var third: FakeMac.Window!
    third = two.mac.open("third", in: two.mac.launch("Third"), frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    two.mac.pass(1)
    two.mac.click(mine)
    two.mac.pass(1)
    two.mac.hang(theirs[0].app, for: 0.8)
    two.mac.later(0.2) { two.mac.activate(third.app) }
    two.run("focus \(theirs[0].number)", then: 5)
    story.check("the keyboard stays where the person went", two.mac.keyWindow === third, "w\(two.mac.keyWindow?.number ?? 0) has it")
    story.check("and the focus ring is there", two.ring == third.number, "\(String(describing: two.ring))")
  }

  for (answer, words) in [(0.05, "slow"), (0.15, "slower than Arbor's patience")] {
  book.story("a window is moved by hand while Arbor moves its sibling, and their app is \(words)") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Busy")
      a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 300, height: 300))
      b = mac.open("b", in: app, frame: CGRect(x: 500, y: 60, width: 300, height: 300))
    }
    // Seven calls or so: a third of a second, or a whole one.
    a.app.answersIn = answer
    let moved = CGRect(x: 560, y: 160, width: 300, height: 300)
    one.mac.later(0.1) { one.mac.appMoves(b, to: moved) }
    let target = CGRect(x: 12, y: 43, width: 400, height: 500)
    _ = one.layer.setFrame(target, of: WindowID(a.number))
    one.mac.pass(3)
    story.check("the one Arbor moved is where it was sent", a.frame == target && one.snapshot(a)?.frame == target, a.frame.text)
    story.check("Arbor knows where the other is", one.snapshot(b)?.frame == moved, "\(one.snapshot(b)?.frame.text ?? "")")
    story.check("and that this was not its own doing", one.heard.all.contains(.changed(b.number, byUser: true)), one.heard.texts)
    story.check("while its own move counts as its own", !one.heard.all.contains(.changed(a.number, byUser: true)), one.heard.texts)
  }
  }

  // Headless twin: SlowAppTests.whatABusyAppMakesOfTheSizeIsLearntWhenItIsDone.
  book.story("an app takes 0.7 s over every move, and one of its windows refuses its slot's width") { story in
    var mine: FakeMac.Window!, theirs: [FakeMac.Window] = []
    let two = StoreyTwo(story) { mac in
      let busy = mac.launch("Busy")
      theirs = [mac.open("a", in: busy, frame: CGRect(x: 500, y: 60, width: 400, height: 300)), mac.open("wide", in: busy, frame: CGRect(x: 300, y: 380, width: 620, height: 300))]
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
    }
    theirs[1].minimumSize = CGSize(width: 600, height: 200)
    theirs[0].app.answersIn = 0.1
    let began = two.mac.now
    story.check("Arbor takes the command", two.run("arrange", then: 0).ok)
    story.check("and answers within two seconds", two.mac.now - began <= 2, "\(two.mac.now - began) s")
    two.mac.pass(15)
    let showing = (theirs + [mine]).filter { two.visibleFraction($0) > 0.05 }
    var overlaps: [String] = []
    for (index, first) in showing.enumerated() {
      for second in showing[(index + 1)...] where first.frame.insetBy(dx: 1, dy: 1).intersects(second.frame) { overlaps.append("w\(first.number) over w\(second.number)") }
    }
    story.check("in the end no window lies over another", overlaps.isEmpty, overlaps.joined(separator: ", ") + "; " + places(two, theirs + [mine]))
    story.check("what shows is wholly in view", showing.allSatisfy { two.isInView($0) }, places(two, showing))
    let asked = theirs.map(\.timesAskedForAFrame)
    two.mac.pass(10)
    story.check("and Arbor has done with them", theirs.map(\.timesAskedForAFrame) == asked, "asked again \(zip(theirs.map(\.timesAskedForAFrame), asked).map { $0 - $1 }) times")
  }
}
