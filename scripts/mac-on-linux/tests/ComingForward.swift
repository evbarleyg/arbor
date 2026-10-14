import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Another app comes forward.
//
// Switching apps posts no "focused window changed" if the app's focused window is the one it was: `didActivateApplication` is the only sign. On hosted Macs that
// notice arrived while `NSWorkspace.shared.frontmostApplication` STILL NAMED THE OLD APP, 27 times in three runs on 2026-10-14. What macOS said in the switches
// that failed: did activate; the other app deactivated 0.6 ms later; this one activated 8 ms later; nothing more. For eight seconds the window with the keyboard
// lay out of view. How long the property takes to catch up nobody has measured, so the stale case is told twice: it has caught up when
// "application activated" comes (5 ms), and it has not (50 ms).

private let lags: [(words: String, seconds: TimeInterval)] = [
  ("", 0), (", and NSWorkspace names the old app for 5 ms more", 0.005), (", and NSWorkspace names the old app for 50 ms more", 0.05),
]

@MainActor
func tellOfComingForward(_ book: Book) {
  for lag in lags {
    book.story("⌘Tab to another app\(lag.words)") { story in
      var mine: FakeMac.Window!, other: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        other = mac.open("other", in: mac.launch("Other"))
        mine = mac.open("mine", in: mac.launch("Mine"))
      }
      story.check("to begin with the keyboard is in the first app's window", one.layer.focusedWindow()?.rawValue == mine.number)
      one.mac.frontmostLagsNoticeBy = lag.seconds
      one.heard.clear()
      one.mac.activate(other.app)
      one.mac.pass(2)
      story.check("the window that has the keyboard now is reported focused", one.heard.all.contains(.focused(other.number)), one.heard.texts)
      story.check("once", one.heard.all.filter { $0 == .focused(other.number) }.count <= 1, one.heard.texts)
      story.check("asked where the keyboard is, the layer names it", one.layer.focusedWindow()?.rawValue == other.number)
    }

    book.story("a click on another window of another app\(lag.words)") { story in
      var mine: FakeMac.Window!, first: FakeMac.Window!, second: FakeMac.Window!
      let one = StoreyOne(story) { mac in
        let app = mac.launch("Other")
        second = mac.open("second", in: app, frame: CGRect(x: 500, y: 300, width: 300, height: 200))
        first = mac.open("first", in: app, frame: CGRect(x: 500, y: 60, width: 300, height: 200))
        mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 40, y: 60, width: 400, height: 300))
      }
      story.check("to begin with the other app's focused window is another one", first.app.focused === first && one.mac.keyWindow === mine)
      one.mac.frontmostLagsNoticeBy = lag.seconds
      one.heard.clear()
      one.mac.click(second)
      one.mac.pass(2)
      story.check("the window that was clicked is reported focused", one.heard.all.contains(.focused(second.number)), one.heard.texts)
      story.check("no other window is", !one.heard.all.contains(.focused(first.number)) && !one.heard.all.contains(.focused(mine.number)), one.heard.texts)
    }

    book.story("⌘Tab to an app whose window is out of view\(lag.words)") { story in
      var mine: FakeMac.Window!, other: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        other = mac.open("other", in: mac.launch("Other"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))
        mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
      }
      story.check("both windows are docked", two.run("dock \(mine.number) left").ok && two.run("dock \(other.number) right").ok)
      story.check("one is framed", two.run("zoom \(mine.number)").ok)
      story.check("the other app's window is out of view", two.isOutOfView(other), two.whereabouts(other))
      story.check("the keyboard is in the framed window", two.mac.keyWindow === mine)
      two.mac.frontmostLagsNoticeBy = lag.seconds
      two.mac.activate(other.app)
      two.mac.pass(3)
      story.check("the view moves to show the window that has the keyboard now", two.isInView(other), two.whereabouts(other))
    }
  }
}
