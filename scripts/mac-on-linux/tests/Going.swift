import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Windows and apps that go, and apps that hang.

@MainActor
func tellOfGoing(_ book: Book) {
  // Trace `close`: the app's next window is reported focused 12 ms before the closing one is reported destroyed.
  book.story("a window closes") { story in
    var first: FakeMac.Window!, second: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Notes")
      first = mac.open("first", in: app)
      second = mac.open("second", in: app)
    }
    one.mac.close(second)
    one.mac.pass(1)
    story.check(
      "the app's next window is reported focused, then the window is reported gone",
      one.heard.outline == [.focused(first.number), .destroyed(second.number)], one.heard.texts)
    story.check("Arbor knows the one that is left", one.known == [first.number])
  }

  book.story("a window closes and the notification never comes") { story in
    var first: FakeMac.Window!, second: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Notes")
      first = mac.open("first", in: app)
      second = mac.open("second", in: app)
    }
    one.mac.close(second, announced: false)
    one.mac.pass(1)
    // The focus report comes 12 ms before the window goes, so the list read then still has it.
    one.mac.rename(first, "something happens in the app")
    one.mac.click(first)
    one.mac.pass(1)
    story.check("it is reported gone all the same, once", one.heard.all.filter { $0 == .destroyed(second.number) }.count == 1, one.heard.texts)
    story.check("Arbor knows the one that is left", one.known == [first.number], "\(one.known)")
  }

  book.story("the last window of an app closes and the notification never comes") { story in
    var only: FakeMac.Window!, mine: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 40, y: 60, width: 300, height: 300))
      only = mac.open("only", in: mac.launch("Notes"), frame: CGRect(x: 500, y: 60, width: 300, height: 300))
    }
    one.mac.close(only, announced: false)
    one.mac.pass(1)
    one.mac.click(mine)
    one.mac.pass(1)
    one.mac.activate(only.app)
    one.mac.pass(2)
    story.check(
      "by the time its app has been left and come back to, it is reported gone", one.heard.all.contains(.destroyed(only.number)), one.heard.texts)
  }

  // Trace `app-quits`: no window is reported destroyed by the app; the workspace's notice is all there is.
  book.story("an app quits") { story in
    var mine: FakeMac.Window!, a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"))
      let app = mac.launch("TextEdit")
      a = mac.open("a", in: app)
      b = mac.open("b", in: app)
    }
    one.mac.quit(a.app)
    one.mac.pass(1)
    story.check(
      "both its windows are reported gone, once each",
      one.heard.outline.filter { $0 != .focused(mine.number) } == [.destroyed(a.number), .destroyed(b.number)], one.heard.texts)
    story.check("the app that comes forward instead has the keyboard", one.lastWordOnTheKeyboard == mine.number, one.heard.texts)
  }

  // Nothing reports the end of an accessory app or of a process started from a shell. Calls to it fail at once instead of timing out.
  book.story("an app ends and nothing says so") { story in
    var mine: FakeMac.Window!, ghost: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"))
      ghost = mac.open("ghost", in: mac.launch("FromAShell", announced: false))
    }
    story.check("to begin with Arbor knows its window", one.known.contains(ghost.number))
    one.mac.quit(ghost.app, announced: false)
    one.mac.pass(1)
    let before = one.mac.now
    let answer = one.layer.setFrame(CGRect(x: 10, y: 40, width: 300, height: 300), of: WindowID(ghost.number))
    story.check("asked to move its window, the layer says that it does not know what came of it", answer == nil)
    story.check("without waiting", one.mac.now - before < 0.1, "\(one.mac.now - before) s")
    one.mac.pass(0.1)
    story.check("and reports the window gone", one.heard.all.contains(.destroyed(ghost.number)), one.heard.texts)
    story.check("Arbor knows the one that is left", one.known == [mine.number])
  }

  book.story("an app with a docked window ends and nothing says so") { story in
    var mine: FakeMac.Window!, ghost: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"))
      ghost = mac.open("ghost", in: mac.launch("FromAShell", announced: false))
    }
    story.check("both windows are docked", two.run("dock \(mine.number) left").ok && two.run("dock \(ghost.number) right").ok)
    let half = mine.frame.width
    two.mac.quit(ghost.app, announced: false)
    two.mac.pass(5)
    story.check("the window that is left gets the room", mine.frame.width > half * 1.5, two.whereabouts(mine))
  }

  // Every call is synchronous, on the main thread, and waits up to the timeout of 1 s. A hung app with three docked windows used to stop Arbor for 19.5 s.
  book.story("an app hangs") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Busy")
      a = mac.open("a", in: app, frame: CGRect(x: 40, y: 60, width: 300, height: 300))
      b = mac.open("b", in: app, frame: CGRect(x: 400, y: 60, width: 300, height: 300))
    }
    one.mac.hang(a.app)
    let began = one.mac.now
    let first = one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(a.number))
    story.check("asked to move a window, the layer says that it does not know what came of it", first == nil)
    story.check("after waiting for one call, a second, and not for six", abs(one.mac.now - began - 1) < 0.01, "\(one.mac.now - began) s")
    let again = one.mac.now
    let second = one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(b.number))
    one.layer.focus(WindowID(b.number))
    one.layer.setMinimized(WindowID(b.number), true)
    _ = one.layer.focusedWindow()
    story.check(
      "from then on nothing is asked of the app, and nothing waits for it", second == nil && one.mac.now == again, "\(one.mac.now - again) s")
    one.mac.pass(5)
    story.check(
      "while it hangs no window of its is reported gone or changed",
      one.heard.outline.isEmpty && !one.heard.all.contains { if case .changed = $0 { true } else { false } }, one.heard.texts)
    story.check("and Arbor's main thread has waited one second in all", one.mac.secondsWaitedInVain == 1, "\(one.mac.secondsWaitedInVain) s")
    one.mac.wake(a.app)
    one.mac.pass(1)
    story.check(
      "once it wakes its windows are reported, so that they can be placed", one.heard.all.contains(.changed(a.number, byUser: true)) && one.heard.all.contains(.changed(b.number, byUser: true)),
      one.heard.texts)
    story.check(
      "and it can be moved again",
      one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(a.number)) == CGRect(x: 10, y: 40, width: 500, height: 500))
  }

  book.story("an app hangs in the middle of a move, and carries the calls out when it wakes") { story in
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in window = mac.open("a", in: mac.launch("Busy"), frame: CGRect(x: 40, y: 60, width: 300, height: 300)) }
    // It answers the question about the enhanced user interface, and takes the new size no more.
    window.app.hangsAfterCalls = 1
    let answer = one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(window.number))
    story.check("the layer says that it does not know what came of the move", answer == nil)
    story.check("the window is where it was", window.frame == CGRect(x: 40, y: 60, width: 300, height: 300), window.frame.text)
    one.mac.pass(3)
    one.heard.clear()
    one.mac.wake(window.app)
    one.mac.pass(1)
    story.check(
      "when the app wakes the window takes the size that was asked of it in vain", window.frame.size == CGSize(width: 500, height: 500),
      window.frame.text)
    story.check(
      "Arbor hears of it", one.snapshot(window)?.frame == window.frame,
      "\(one.snapshot(window)?.frame.text ?? "nothing") against \(window.frame.text)")
    story.check(
      "as something it has to look at again, not as the echo of a move of its own", one.heard.all.contains(.changed(window.number, byUser: true)),
      one.heard.texts)
  }

  book.story("Arbor asks a hung app for the focus, and the app takes it when it wakes") { story in
    var a: FakeMac.Window!, b: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Busy")
      a = mac.open("a", in: app)
      b = mac.open("b", in: app)
    }
    one.mac.hang(a.app)
    one.layer.focus(WindowID(a.number))
    one.mac.pass(2)
    story.check("while it hangs the keyboard stays where it was", one.mac.keyWindow === b)
    one.heard.clear()
    one.mac.wake(a.app)
    one.mac.pass(1)
    story.check(
      "when it wakes the window gets the keyboard, and is reported focused", one.mac.keyWindow === a && one.lastWordOnTheKeyboard == a.number,
      one.heard.texts)
  }

  // An app that is busy as it is switched to is an everyday thing.
  book.story("⌘Tab to an app that hangs, and wakes two seconds later") { story in
    var other: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      other = mac.open("other", in: mac.launch("Other"))
      mac.open("mine", in: mac.launch("Mine"))
    }
    one.mac.hang(other.app)
    one.mac.activate(other.app)
    one.mac.pass(2)
    story.check("Arbor's main thread has waited a second for it, and no more", one.mac.secondsWaitedInVain <= 1, "\(one.mac.secondsWaitedInVain) s")
    one.mac.wake(other.app)
    one.mac.pass(3)
    story.check(
      "once it wakes, its window, which has the keyboard, is reported focused", one.heard.all.contains(.focused(other.number)), one.heard.texts)
  }

  book.story("⌘Tab three times to an app that hangs") { story in
    var other: FakeMac.Window!, mine: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      other = mac.open("other", in: mac.launch("Other"))
      mine = mac.open("mine", in: mac.launch("Mine"))
    }
    one.mac.hang(other.app)
    for _ in 1...3 {
      one.mac.activate(other.app)
      one.mac.pass(1.5)
      one.mac.activate(mine.app)
      one.mac.pass(1.5)
    }
    story.check(
      "Arbor's main thread has waited a second for it once, not each time", one.mac.secondsWaitedInVain <= 1, "\(one.mac.secondsWaitedInVain) s")
  }

  book.story("⌘Tab to an app whose window is out of view and which hangs for two seconds") { story in
    var mine: FakeMac.Window!, other: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      other = mac.open("other", in: mac.launch("Other"), frame: CGRect(x: 500, y: 100, width: 400, height: 300))
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
    }
    story.check(
      "one of two docked windows is framed",
      two.run("dock \(mine.number) left").ok && two.run("dock \(other.number) right").ok && two.run("zoom \(mine.number)").ok && two.isOutOfView(other))
    two.mac.hang(other.app)
    two.mac.activate(other.app)
    two.mac.pass(2)
    two.mac.wake(other.app)
    two.mac.pass(4)
    story.check("once the app wakes the view moves to show its window, which has the keyboard", two.isInView(other), two.whereabouts(other))
  }

  // "Whoever posts a notification is awake" does not hold for what was on its way when the app hung.
  book.story("an app opens a window and is busy at once, loading what goes into it") { story in
    var app: FakeMac.App!
    let one = StoreyOne(story) { mac in
      app = mac.launch("Editor")
      mac.open("first", in: app)
    }
    let window = one.mac.open("a large document", in: app)
    one.mac.pass(0.001)
    one.mac.hang(app)
    one.mac.pass(3)
    story.check(
      "Arbor's main thread waits for it two seconds at most", one.mac.secondsWaitedInVain <= 2,
      "\(one.mac.secondsWaitedInVain) s for three notifications that were on their way")
    one.mac.wake(app)
    one.mac.pass(3)
    story.check("once the app wakes the window is announced as new", one.heard.all.contains(.appeared(window.number)), one.heard.texts)
    story.check("and is said to have the keyboard", one.lastWordOnTheKeyboard == window.number, one.heard.texts)
  }

  book.story("three docked windows of an app that hangs") { story in
    var windows: [FakeMac.Window] = []
    var mine: FakeMac.Window!
    let two = StoreyTwo(story) { mac in
      let app = mac.launch("Busy")
      for name in ["a", "b", "c"] { windows.append(mac.open(name, in: app)) }
      mine = mac.open("mine", in: mac.launch("Mine"))
    }
    story.check("four windows are arranged", two.run("arrange").ok)
    two.mac.hang(windows[0].app)
    let began = two.mac.now
    story.check("Arbor answers a command all the same", two.run("zoom \(mine.number)", then: 0).ok)
    story.check("within three seconds", two.mac.now - began < 3, "\(two.mac.now - began) s")
    two.mac.pass(3)
    story.check("the window that was asked for fills the view", mine.frame.width > 900, two.whereabouts(mine))
    two.mac.wake(windows[0].app)
    two.mac.pass(4)
    story.check(
      "once the app wakes its windows go out of view", windows.allSatisfy { two.isOutOfView($0) },
      windows.map { two.whereabouts($0) }.joined(separator: "; "))
    story.check("in all, Arbor's main thread waited less than three seconds", two.mac.secondsWaitedInVain < 3, "\(two.mac.secondsWaitedInVain) s")
  }

  // Taking the permission away shows as `apiDisabled` from inside a call.
  book.story("the Accessibility permission is taken away") { story in
    var window: FakeMac.Window!
    let one = StoreyOne(story) { mac in window = mac.open("a", in: mac.launch("Notes")) }
    one.mac.isTrusted = false
    let began = one.mac.now
    story.check(
      "asked to move a window, the layer says that it does not know what came of it",
      one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(window.number)) == nil)
    story.check("and that macOS refused", one.heard.all.contains(.refused), one.heard.texts)
    one.heard.clear()
    one.layer.focus(WindowID(window.number))
    story.check("the same when asked to give it the keyboard", one.heard.all.contains(.refused), one.heard.texts)
    story.check("nothing waits", one.mac.now - began < 0.1)
    one.mac.pass(3)
    story.check(
      "the app is not taken to hang, nor its window to be gone", one.known == [window.number] && !one.heard.all.contains(.destroyed(window.number)),
      one.heard.texts)
    one.mac.isTrusted = true
    story.check(
      "given back, the window moves again", one.layer.setFrame(CGRect(x: 10, y: 40, width: 500, height: 500), of: WindowID(window.number)) != nil)
  }
}
