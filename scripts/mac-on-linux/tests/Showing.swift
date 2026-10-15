import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Windows that stop showing and show again: Spaces, native tabs, the Dock, ⌘H, full screen.


@MainActor
func tellOfShowing(_ book: Book) {
  // The notice of a Space switch comes in the middle of the transition, when apps have been seen to list neither the old windows nor the new ones.
  for lists in [FakeMac.ListsDuringTransition.right, .neither] {
    for appFirst in [true, false] {
      let words = (lists == .neither ? ", and in the transition apps list no windows at all" : "") + (appFirst ? "" : ", the app coming forward after the notice")
      book.story("the Space is switched\(words)") { story in
        var here: FakeMac.Window!, alsoHere: FakeMac.Window!, there: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          let app = mac.launch("Safari")
          there = mac.open("there", in: app, frame: CGRect(x: 500, y: 300, width: 450, height: 350))
          mac.send(there, toSpace: 2)
          here = mac.open("here", in: app, frame: CGRect(x: 40, y: 60, width: 400, height: 300))
          alsoHere = mac.open("also here", in: mac.launch("Notes"), frame: CGRect(x: 300, y: 200, width: 400, height: 300))
        }
        story.check("to begin with Arbor knows the windows of the Space that shows", one.known == [here.number, alsoHere.number], "\(one.known)")
        story.check("and that the other one exists", one.layer.existingWindowIDs().contains(WindowID(there.number)))

        one.mac.switchSpace(to: 2, lists: lists, appComesForwardFirst: appFirst)
        one.mac.pass(3)
        story.check(
          "the windows left behind are marked as not showing",
          one.snapshot(here)?.isOnActiveSpace == false && one.snapshot(alsoHere)?.isOnActiveSpace == false)
        story.check("none is reported gone", !one.heard.all.contains { if case .destroyed = $0 { true } else { false } }, one.heard.texts)
        story.check(
          "the window of the new Space is announced once, as one that was open all along", one.heard.about(there).filter { $0 != .focused(there.number) && $0 != .changed(there.number, byUser: false) } == [.found(there.number)],
          one.heard.texts)
        story.check(
          "and is said to have the keyboard", one.lastWordOnTheKeyboard == there.number && one.heard.all.contains(.focused(there.number)),
          one.heard.texts)

        one.heard.clear()
        one.mac.switchSpace(to: 1, lists: lists, appComesForwardFirst: appFirst)
        one.mac.pass(3)
        story.check(
          "back again, the first windows show", one.snapshot(here)?.isOnActiveSpace == true && one.snapshot(alsoHere)?.isOnActiveSpace == true)
        story.check("the other does not", one.snapshot(there)?.isOnActiveSpace == false)
        story.check(
          "nothing is announced or reported gone", one.heard.outline.allSatisfy { if case .focused = $0 { true } else { false } }, one.heard.texts)
        story.check(
          "the window with the keyboard is reported focused", one.mac.keyWindow.map { one.heard.all.contains(.focused($0.number)) } ?? false,
          one.heard.texts)
      }
    }
  }

  // Two browser windows, each filling the display on a Space of its own. Nobody knows in which order the reports of a switch arrive.
  for appFirst in [false, true] {
    book.story("two windows of one app fill the same place on two Spaces, and the Space is switched\(appFirst ? ", the focus reported before the notice" : "")") { story in
      var here: FakeMac.Window!, there: FakeMac.Window!
      let frame = CGRect(x: 12, y: 43, width: 1000, height: 650)
      let one = StoreyOne(story) { mac in
        let app = mac.launch("Safari")
        there = mac.open("there", in: app, frame: frame)
        mac.send(there, toSpace: 2)
        here = mac.open("here", in: app, frame: frame)
      }
      one.mac.switchSpace(to: 2, appComesForwardFirst: appFirst)
      one.mac.pass(3)
      story.check("the one is not taken for a tab of the other", !one.heard.all.contains(.replaced(here.number, by: there.number)), one.heard.texts)
      story.check(
        "Arbor knows both, one showing and one not", one.snapshot(here)?.isOnActiveSpace == false && one.snapshot(there)?.isOnActiveSpace == true,
        "\(one.known)")
      one.heard.clear()
      one.mac.switchSpace(to: 1, appComesForwardFirst: appFirst)
      one.mac.pass(3)
      story.check("back again, the first window is not announced as a new one", !one.heard.all.contains(.appeared(here.number)), one.heard.texts)
    }
  }

  // Each native tab is a window of its own, but its app lists only the one in front.
  for grows in [CGFloat(0), 31] {
    book.story("native tabs\(grows > 0 ? " of an app whose window grows by the tab bar" : "")") { story in
      var first: FakeMac.Window!
      let one = StoreyOne(story) { mac in first = mac.open("first", in: mac.launch("Terminal"), frame: CGRect(x: 100, y: 60, width: 625, height: 500)) }
      let second = one.mac.newTab(of: first, grows: grows)
      one.mac.pass(1)
      story.check(
        "a new tab takes the place of the window it was opened in", one.heard.outline.first == .replaced(first.number, by: second.number),
        one.heard.texts)
      story.check(
        "nothing is announced as new or reported gone",
        !one.heard.outline.contains { [.appeared(second.number), .found(second.number), .destroyed(first.number)].contains($0) }, one.heard.texts)
      story.check(
        "the new tab is said to have the keyboard", one.lastWordOnTheKeyboard == second.number && one.heard.all.contains(.focused(second.number)),
        one.heard.texts)
      story.check("to Arbor the group is one window", one.known == [second.number], "\(one.known)")

      one.heard.clear()
      one.mac.chooseTab(first)
      one.mac.pass(1)
      story.check(
        "choosing the first tab, which posts only that the main window changed, puts it in the other's place",
        one.heard.outline.first == .replaced(second.number, by: first.number), one.heard.texts)
      story.check("and it is said to have the keyboard", one.heard.all.contains(.focused(first.number)), one.heard.texts)
      story.check("the group is still one window", one.known == [first.number], "\(one.known)")

      one.heard.clear()
      one.mac.close(first)
      one.mac.pass(1)
      story.check(
        "closing the tab in front hands its place to the one behind", one.heard.outline.first == .replaced(first.number, by: second.number),
        one.heard.texts)
      story.check(
        "and nothing is reported gone: to the person the window is still there",
        !one.heard.all.contains { if case .destroyed = $0 { true } else { false } }, one.heard.texts)
      story.check("one window is left", one.known == [second.number], "\(one.known)")

      one.heard.clear()
      one.mac.close(second)
      one.mac.pass(1)
      story.check("closing the last tab closes the window", one.heard.outline == [.destroyed(second.number)] && one.known.isEmpty, one.heard.texts)
    }
  }

  // A window in plain view has been seen missing from its app's list: the list is behind, or in flux.
  for lag in [0.01, 0.05] {
    book.story("native tabs of an app whose list of windows is \(Int(lag * 1000)) ms behind") { story in
      var first: FakeMac.Window!
      let one = StoreyOne(story) { mac in first = mac.open("first", in: mac.launch("Finder")) }
      first.app.listLagsBy = lag
      let second = one.mac.newTab(of: first)
      one.mac.pass(2)
      story.check(
        "a new tab takes the place of the window it was opened in", one.heard.all.contains(.replaced(first.number, by: second.number)),
        one.heard.texts)
      story.check("it is not announced as a window of its own", !one.heard.all.contains(.appeared(second.number)), one.heard.texts)
      story.check("to Arbor the group is one window", one.known == [second.number], "\(one.known)")
    }

    book.story("the tab in front is closed, and the app's list of windows is \(Int(lag * 1000)) ms behind") { story in
      var first: FakeMac.Window!
      let one = StoreyOne(story) { mac in first = mac.open("first", in: mac.launch("Finder")) }
      let second = one.mac.newTab(of: first)
      one.mac.pass(2)
      first.app.listLagsBy = lag
      one.heard.clear()
      one.mac.close(second)
      one.mac.pass(2)
      story.check(
        "nothing is reported gone: to the person the window is still there", !one.heard.all.contains(.destroyed(second.number)), one.heard.texts)
      story.check("Arbor knows the tab that shows now", one.known == [first.number], "\(one.known)")
    }
  }

  book.story("a tab in the background is closed") { story in
    var first: FakeMac.Window!
    let one = StoreyOne(story) { mac in first = mac.open("first", in: mac.launch("Finder")) }
    let second = one.mac.newTab(of: first)
    one.mac.pass(1)
    one.heard.clear()
    one.mac.close(first)
    one.mac.pass(1)
    story.check("nothing is reported: the controller does not know it", one.heard.outline.isEmpty, one.heard.texts)
    story.check("the window in front stays", one.known == [second.number])
  }

  // Trace `minimize-restore`.
  book.story("a window is minimized and restored") { story in
    var window: FakeMac.Window!, other: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Notes")
      other = mac.open("other", in: app)
      window = mac.open("window", in: app)
    }
    one.mac.minimize(window)
    one.mac.pass(0.3)
    story.check("while it shrinks into the Dock nothing is said", one.heard.all.isEmpty, one.heard.texts)
    one.mac.pass(1.5)
    story.check(
      "then it is reported minimized", one.snapshot(window)?.isMinimized == true && one.heard.all.contains(.changed(window.number, byUser: true)),
      one.heard.texts)
    story.check("the app's other window gets the keyboard", one.lastWordOnTheKeyboard == other.number, one.heard.texts)
    // A recording of a hosted Mac: the next window's focus 6.6 ms before "miniaturized", at the end of the flight.
    story.check(
      "which is reported first, as at a close", one.heard.all.firstIndex(of: .focused(other.number)) ?? .max < one.heard.all.firstIndex(of: .changed(window.number, byUser: true)) ?? .min,
      one.heard.texts)
    story.check(
      "the Dock has grown, which is reported once as a change of the displays", one.heard.all.filter { $0 == .displaysChanged }.count == 1,
      one.heard.texts)
    story.check("and Arbor has the new visible frame", one.layer.displays().first?.visibleFrame.height == 676)

    one.heard.clear()
    one.mac.restore(window)
    one.mac.pass(2)
    // The focus is reported 1 to 4 ms before "deminiaturized".
    story.check(
      "restored, it is reported focused first and then no longer minimized",
      one.heard.all.first == .focused(window.number) && one.snapshot(window)?.isMinimized == false, one.heard.texts)
    story.check(
      "it is neither announced nor reported gone", one.heard.outline.filter { $0 != .displaysChanged } == [.focused(window.number)], one.heard.texts)
  }

  // Trace `hide-unhide`.
  book.story("an app is hidden and shown again") { story in
    var mine: FakeMac.Window!, a: FakeMac.Window!, parked: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"))
      let app = mac.launch("Shy")
      parked = mac.open("parked", in: app, frame: CGRect(x: 1023, y: 673, width: 1000, height: 650))
      a = mac.open("a", in: app)
    }
    one.mac.hide(a.app)
    one.mac.pass(1)
    story.check("its windows are reported hidden", one.snapshot(a)?.isHidden == true && one.snapshot(parked)?.isHidden == true)
    story.check("none is reported gone", !one.heard.all.contains { if case .destroyed = $0 { true } else { false } }, one.heard.texts)
    story.check(
      "the app behind gets the keyboard", one.lastWordOnTheKeyboard == mine.number && one.heard.all.contains(.focused(mine.number)), one.heard.texts)

    one.heard.clear()
    one.mac.activate(a.app)
    one.mac.pass(2)
    story.check("shown again, they are no longer hidden", one.snapshot(a)?.isHidden == false && one.snapshot(parked)?.isHidden == false)
    story.check(
      "macOS has brought the one that was nearly off screen into view, and Arbor knows where it is",
      one.snapshot(parked)?.frame == CGRect(x: 24, y: 55, width: 1000, height: 650), "\(one.snapshot(parked)?.frame.text ?? "")")
    story.check("that move is not taken for an echo of Arbor's own", one.heard.all.contains(.changed(parked.number, byUser: true)), one.heard.texts)
    story.check(
      "they stay the windows they were",
      Set(one.known) == [mine.number, a.number, parked.number] && one.heard.outline.allSatisfy { if case .focused = $0 { true } else { false } },
      one.heard.texts)
    story.check("the window with the keyboard is reported focused", one.heard.all.contains(.focused(a.number)), one.heard.texts)
  }

  // Nothing is posted about full screen itself, but the size changes, and the window gets a Space to itself.
  for late in [false, true] {
    for lists in [FakeMac.ListsDuringTransition.right, .neither] {
      let words = (late ? ", which it says only after the last report of its size" : "") + (lists == .neither ? ", and in the transition apps list no windows at all" : "")
      book.story("a window enters full screen\(words)") { story in
        var window: FakeMac.Window!, other: FakeMac.Window!
        let one = StoreyOne(story) { mac in
          other = mac.open("other", in: mac.launch("Notes"))
          window = mac.open("film", in: mac.launch("Player"), frame: CGRect(x: 100, y: 100, width: 600, height: 400))
        }
        one.mac.enterFullScreen(window, saysSoLate: late, lists: lists)
        one.mac.pass(4)
        story.check("Arbor knows that it is in full screen", one.snapshot(window)?.isFullScreen == true, one.heard.texts)
        story.check("and that it shows", one.snapshot(window)?.isOnActiveSpace == true)
        story.check("the window left behind is marked as not showing", one.snapshot(other)?.isOnActiveSpace == false)
        story.check("macOS's helper windows are not announced", Set(one.known) == [window.number, other.number], "\(one.known)")
        story.check("nothing is reported gone or new", !one.heard.outline.contains { if case .focused = $0 { false } else { true } }, one.heard.texts)
        story.check(
          "asked for another size, the layer leaves it alone",
          one.layer.setFrame(CGRect(x: 0, y: 40, width: 300, height: 300), of: WindowID(window.number)) == window.frame)

        one.heard.clear()
        one.mac.leaveFullScreen(window)
        one.mac.pass(4)
        story.check("out of full screen again, Arbor knows", one.snapshot(window)?.isFullScreen == false, one.heard.texts)
        story.check(
          "it has its old frame", one.snapshot(window)?.frame == CGRect(x: 100, y: 100, width: 600, height: 400),
          "\(one.snapshot(window)?.frame.text ?? "")")
        story.check("both windows show", one.snapshot(window)?.isOnActiveSpace == true && one.snapshot(other)?.isOnActiveSpace == true)
        story.check("and again nothing is reported gone or new", !one.heard.outline.contains { if case .focused = $0 { false } else { true } }, one.heard.texts)
      }
    }
  }

  // macOS says that the screen parameters changed several times in a row when a display comes or goes.
  book.story("a second display is plugged in and unplugged") { story in
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in window = mac.open("a", in: mac.launch("Notes")) }
    let second = FakeMac.Screen(id: 2, name: "Second", frame: CGRect(x: 1024, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1024, y: 25, width: 1920, height: 1055))
    one.mac.setScreens([.hostedMac, second])
    one.mac.pass(1)
    story.check("for a moment nothing is said: displays blink", !one.heard.all.contains(.displaysChanged), one.heard.texts)
    one.mac.pass(2)
    story.check("then the change is reported, once for three notices", one.heard.all.filter { $0 == .displaysChanged }.count == 1, one.heard.texts)
    story.check(
      "Arbor sees two displays, each where it is", one.layer.displays().map(\.frame) == [FakeMac.Screen.hostedMac.frame, second.frame],
      "\(one.layer.displays().map(\.frame.text))")
    story.check("and tells them apart", Set(one.layer.displays().map(\.id)).count == 2)

    // A display that blinks on wake.
    one.heard.clear()
    one.mac.setScreens([.hostedMac])
    one.mac.pass(0.8)
    one.mac.setScreens([.hostedMac, second])
    one.mac.pass(4)
    story.check("a display that is gone for less than a second is not reported at all", !one.heard.all.contains(.displaysChanged), one.heard.texts)
    _ = window
  }

  // When the main display changes, so do the coordinates of every window, and apps post nothing about it.
  book.story("another display becomes the main one") { story in
    var window: FakeMac.Window!
    let left = FakeMac.Screen(id: 2, name: "Left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: -1920, y: 25, width: 1920, height: 1055))
    let one = StoreyOne(story) { mac in
      mac.setScreens([.hostedMac, left])
      window = mac.open("a", in: mac.launch("Notes"), frame: CGRect(x: 100, y: 100, width: 400, height: 300))
    }
    var main = left, side = FakeMac.Screen.hostedMac
    main.frame.origin.x = 0
    main.visibleFrame.origin.x = 0
    side.frame.origin.x = 1920
    side.visibleFrame.origin.x = 1920
    one.mac.renumber(dx: 1920, dy: 0)
    one.mac.setScreens([main, side])
    one.mac.pass(3)
    story.check("the change is reported", one.heard.all.contains(.displaysChanged), one.heard.texts)
    story.check(
      "Arbor has the window's new coordinates, though its app said nothing",
      one.snapshot(window)?.frame == CGRect(x: 2020, y: 100, width: 400, height: 300), "\(one.snapshot(window)?.frame.text ?? "")")
  }
}
