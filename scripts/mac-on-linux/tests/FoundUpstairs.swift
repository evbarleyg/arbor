import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// What the walk at storey two found on a polite Mac (WalkUpstairs.swift), each as a story. All three are the controller's, not the layer's: the stand-ins show the same, and the lines for `arbor-sim` that do are given with each.
// "No key may go to a window out of view" (the chaos lab's words for a launch).

@MainActor
func tellOfWhatTheWalkFoundUpstairs(_ book: Book) {
  /// Whether what is typed now would be seen.
  func keyboardIsInView(_ two: StoreyTwo) -> Bool { two.mac.keyWindow.map { two.visibleFraction($0) > 0.25 } ?? true }
  func keyboard(_ two: StoreyTwo) -> String { two.mac.keyWindow.map { "the keyboard is in \(two.whereabouts($0))" } ?? "nobody has the keyboard" }

  // arbor-sim "display-size 1024x768 31" "open App1 420x320" "open App1 380x300" "open App2 460x300" arrange "focus 101" "drag 101 492 344" "wait 2" health type
  //   → on screen: Too small to show…; HEALTH ok; typed into 101; 2 out of view
  book.story("three windows are arranged, and one is dropped beside another where there is no room for it") { story in
    var windows: [FakeMac.Window] = []
    let two = StoreyTwo(story) { mac in
      let first = mac.launch("App1")
      windows = [
        mac.open("a", in: first, frame: CGRect(x: 40, y: 60, width: 420, height: 320)), mac.open("b", in: first, frame: CGRect(x: 520, y: 80, width: 380, height: 300)),
        mac.open("c", in: mac.launch("App2"), frame: CGRect(x: 200, y: 330, width: 460, height: 300)),
      ]
    }
    story.check("they are arranged, all in view", two.run("arrange").ok && windows.allSatisfy { two.isInView($0) })
    let dragged = windows[0]
    two.mac.drag(from: CGPoint(x: dragged.frame.midX, y: dragged.frame.minY + 10), to: CGPoint(x: 492, y: 344))
    two.mac.release()
    two.mac.pass(3)
    story.check("the press gave it the keyboard", two.mac.keyWindow === dragged, keyboard(two))
    story.check("what is typed now goes to a window in view", keyboardIsInView(two), keyboard(two))
    story.check("the window that was in the hand is in view", two.isInView(dragged), two.whereabouts(dragged))
  }

  // arbor-sim "display-size 1024x768 31" "mac-tiling off" "open A" "open A" "open B" "open B" "open B" arrange "focus 101" "drag 101 1021 400" "wait 2" health type status
  //   → HEALTH ok; typed into 101; 5 docked, 5 out of view
  book.story("five windows are arranged on 1024 points, and one is dropped at the right edge of the screen, macOS's tiling off") { story in
    var windows: [FakeMac.Window] = []
    let two = StoreyTwo(story) { mac in
      mac.macOSTilesDraggedWindows = false
      let (first, second) = (mac.launch("App1"), mac.launch("App2"))
      for index in 0..<5 { windows.append(mac.open("w", in: index < 2 ? first : second, frame: CGRect(x: 40 + CGFloat(index) * 60, y: 60 + CGFloat(index) * 40, width: 400, height: 300))) }
    }
    story.check("they are arranged", two.run("arrange").ok)
    let dragged = windows[0]
    two.mac.drag(from: CGPoint(x: dragged.frame.midX, y: dragged.frame.minY + 10), to: CGPoint(x: 1021, y: 400))
    two.mac.release()
    two.mac.pass(3)
    story.check("some window is still in view", windows.contains { two.isInView($0) }, windows.map { two.whereabouts($0) }.joined(separator: "; "))
    story.check("what is typed now goes to a window in view", keyboardIsInView(two), keyboard(two))
  }

  // arbor-sim "open App1" "open App2" arrange desktop "wait 2" health type
  //   → camera n0, hidden: w101 w102; HEALTH ok; typed into 102. With a window on the Desktop the keyboard goes to it.
  for way in ["desktop", "back"] {
    book.story("with nothing floating, the view goes to the Desktop (\(way))") { story in
      var windows: [FakeMac.Window] = []
      let two = StoreyTwo(story) { mac in windows = [mac.open("a", in: mac.launch("App1")), mac.open("b", in: mac.launch("App2"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))] }
      story.check("two windows are arranged", two.run("arrange").ok)
      if way == "back" {
        // The Desktop has been looked at, while there was something on it.
        let third = two.mac.open("c", in: two.mac.launch("App3"), frame: CGRect(x: 300, y: 200, width: 400, height: 300))
        two.mac.pass(1)
        two.run("desktop")
        two.mac.close(third)
        two.mac.pass(1)
        two.mac.activate(windows[1].app)
        two.mac.pass(2)
        story.check("the view has followed the keyboard to a docked window", two.isInView(windows[1]), two.whereabouts(windows[1]))
      }
      story.check("Arbor takes the command", two.run(way, then: 2).ok)
      story.check("no window is in view", windows.allSatisfy { two.isOutOfView($0) }, windows.map { two.whereabouts($0) }.joined(separator: "; "))
      story.check("what is typed now goes to no window out of view", keyboardIsInView(two), keyboard(two))
    }
  }

  // The chaos lab has it on the stand-ins, with two scripts: `moved-unasked` in Sources/ArborTesting/ChaosKnownFailures.swift, severity 2: "A window opens over docked ones and stays there. The next thing that happens, which has
  // nothing to do with it…, shoves it onto the Desktop and shrinks it". Here it is on the real layer.
  book.story("a window opens over a docked one, and then another app quits") { story in
    var docked: FakeMac.Window!, other: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      docked = mac.open("docked", in: mac.launch("App2"), frame: CGRect(x: 200, y: 330, width: 460, height: 300))
      other = mac.open("other", in: mac.launch("App9"), frame: CGRect(x: 600, y: 450, width: 300, height: 200))
    }
    story.check("a window is docked at the top", two.run("dock \(docked.number) top").ok)
    let opened = CGRect(x: 460, y: 250, width: 380, height: 250)
    let new = two.mac.open("new", in: docked.app, frame: opened)
    two.mac.pass(2)
    story.check("the new window lies over it, and is left where its app opened it", new.frame == opened && new.frame.intersects(docked.frame), two.whereabouts(new))
    two.mac.quit(other.app)
    two.mac.pass(3)
    story.check("what happened was not about it: it is where it was", new.frame == opened, "\(two.whereabouts(new)), it opened at \(opened.text)")
  }
}
