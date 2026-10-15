import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Apps that hang or are slow while Arbor has something to ask of them, and what a person is left with: at a quit, at a pause, when something else happens meanwhile. Told at storey two, by what
// is on the screen, so that they hold for a layer that asks on the main thread and for one that gives each app a lane of its own.
//
// Measured on a hosted Mac: a hung app lets a call on the main thread go unanswered for 1.06 s; a call that timed out is carried out when the app wakes, a park (the window goes out of view after Arbor
// is gone) as well as a fetch.

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

  // The park that is carried out after Arbor is gone.
  for (calls, words) in [(Int?.none, "at the beginning of"), (1, "at the first call that sets something in"), (2, "at the reading back in")] {
    book.story("an app hangs for 8 s \(words) a move out of view, and Arbor is quit meanwhile") { story in
      let (two, mine, theirs) = stage(story)
      let busy = theirs[0].app
      if let calls { busy.hangsAfterCalls = calls } else { two.mac.hang(busy) }
      two.mac.later(8) { two.mac.wake(busy) }
      two.run("zoom \(mine.number)", then: 0.3)
      two.quit()
      // Or the story has not been told.
      story.check("Arbor is gone while the app still hangs", busy.isHung)
      two.mac.pass(10)
      story.check("the app is awake again", !busy.isHung)
      story.check("in the end all its windows are in view: nothing that was asked of it in vain takes one away after Arbor is gone", theirs.allSatisfy { two.isInView($0) }, places(two, theirs))
      // The end does not show it where word is left at a quit, which fetches the window again. An app that hangs before the move begins is
      // asked a question first, and sent nothing when that goes unanswered.
      if calls == nil {
        story.check(
          "and it was never told to take one out of view: it hung before the move began",
          !two.mac.journal.contains { $0.contains("what was asked of it while it hung: AXPosition = point(Foundation.CGPoint(x: 1023.0") })
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
      two.mac.hang(busy, for: 0.7)
      two.mac.later(0.705) {
        switch what {
        case "opens a window": new = two.mac.open("new", in: busy, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
        case "resizes a docked window": two.mac.appMoves(theirs[1], to: CGRect(origin: theirs[1].frame.origin, size: CGSize(width: theirs[1].frame.width + 60, height: theirs[1].frame.height)))
        default: new = two.mac.newTab(of: theirs[1])
        }
      }
      two.run("show-all", then: 0)
      two.run("arrange", then: 6)
      _ = mine
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

  book.story("a window is moved by hand while Arbor moves its sibling, and their app is slow") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Busy")
      a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 300, height: 300))
      b = mac.open("b", in: app, frame: CGRect(x: 500, y: 60, width: 300, height: 300))
    }
    // Seven calls or so: a third of a second.
    a.app.answersIn = 0.05
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
