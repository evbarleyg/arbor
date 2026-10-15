import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Windows that open.

@MainActor
func tellOfOpening(_ book: Book) {
  // Both orders: an app keeps to none. The second was seen on hosted Macs on 2026-10-14, a millisecond apart, for every window opened in an app that was
  // already running; the layer then filed each as "seen for the first time and did not just open", and rules, automatic docking and the view ignored it.
  for focusFirst in [false, true] {
    book.story("a window opens in a running app\(focusFirst ? " that reports the focus before the creation" : "")") { story in
      var app: FakeMac.App!
      let one = StoreyOne(story) { mac in
        app = mac.launch("Notes")
        mac.open("first", in: app)
      }
      story.check(
        "the window that was open when Arbor started is known, and nothing is announced about it", one.known.count == 1 && one.heard.outline.isEmpty,
        one.heard.texts)

      app.reportsFocusBeforeCreated = focusFirst
      let window = one.mac.open("second", in: app, frame: CGRect(x: 200, y: 120, width: 500, height: 400))
      one.mac.pass(1)
      story.check(
        "the new window is announced once, as one that has just opened", one.heard.about(window).filter { $0 == .appeared(window.number) }.count == 1,
        one.heard.texts)
      story.check("it is not announced as one that was open all along", !one.heard.all.contains(.found(window.number)), one.heard.texts)
      story.check(
        "then it is reported to have the keyboard", one.heard.outline == [.appeared(window.number), .focused(window.number)], one.heard.texts)
      story.check("Arbor has its frame", one.snapshot(window)?.frame == window.frame, "\(String(describing: one.snapshot(window)?.frame))")
      story.check("and its title and app", one.snapshot(window)?.title == "second" && one.snapshot(window)?.appName == "Notes")
    }
  }
}

@MainActor
func tellOfOddOpenings(_ book: Book) {
  // Apps with one window (Music, Notes, Calendar) put it away when it is closed and show it again under the same number, and the window server has it all the while.
  for rude in [false, true] {
    book.story("an app closes its one window and opens it again under the same number\(rude ? ", after a trip to another Space, the focus reported first" : "")") { story in
      var window: FakeMac.Window!
      let one = StoreyOne(story) { mac in window = mac.open("library", in: mac.launch("Music")) }
      one.mac.close(window, putAway: true)
      one.mac.pass(1)
      story.check("the window is reported gone, once", one.heard.outline == [.destroyed(window.number)], one.heard.texts)
      story.check("Arbor no longer counts it among the windows", one.known.isEmpty)
      story.check("the window server has the number all the same", one.layer.existingWindowIDs().contains(WindowID(window.number)))
      if rude {
        // At every switch the layer counts what the window server has.
        one.mac.switchSpace(to: 2)
        one.mac.pass(2)
        one.mac.switchSpace(to: 1)
        one.mac.pass(2)
        window.app.reportsFocusBeforeCreated = true
      }
      one.heard.clear()
      one.mac.reopen(window)
      one.mac.pass(1)
      story.check(
        "opened again, it is announced as a window that has just opened", one.heard.outline.first == .appeared(window.number), one.heard.texts)
      story.check("and has the keyboard", one.heard.outline == [.appeared(window.number), .focused(window.number)], one.heard.texts)
    }
  }

  for delay in [0.3, 0.5] {
    book.story("a new window gets its subrole \(delay) s after it is created") { story in
      var app: FakeMac.App!
      let one = StoreyOne(story) { mac in
        app = mac.launch("Slow")
        mac.open("first", in: app)
      }
      app.subroleComesAfter = delay
      let window = one.mac.open("late", in: app)
      one.mac.pass(0.1)
      story.check("at first it is not taken for a window", !one.known.contains(window.number))
      one.mac.pass(2)
      story.check(
        "a moment later it is announced, once, as one that has just opened",
        one.heard.about(window).filter { $0 != .focused(window.number) } == [.appeared(window.number)], one.heard.texts)
      story.check("and is said to have the keyboard, which it has had all along", one.lastWordOnTheKeyboard == window.number, one.heard.texts)
    }
  }

  book.story("a tooltip and a helper are reported as created and never become windows") { story in
    var app: FakeMac.App!, first: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      app = mac.launch("Safari")
      first = mac.open("page", in: app)
    }
    let tip = one.mac.open("", in: app, frame: CGRect(x: 300, y: 300, width: 120, height: 20), subrole: "AXUnknown", takesKeyboard: false)
    let helper = one.mac.open("", in: app, frame: CGRect(x: 0, y: 0, width: 1024, height: 30), subrole: nil, takesKeyboard: false)
    one.mac.pass(2)
    story.check("neither is announced", one.heard.outline.isEmpty, one.heard.texts)
    one.mac.close(tip)
    one.mac.close(helper)
    one.mac.pass(1)
    story.check("nor reported gone", one.heard.outline.isEmpty, one.heard.texts)
    story.check("the app's real window is all Arbor knows", one.known == [first.number])
  }

  book.story("a window opens and its app never says that it was created") { story in
    var app: FakeMac.App!
    let one = StoreyOne(story) { mac in
      app = mac.launch("Quiet")
      mac.open("first", in: app)
    }
    app.doesNotReportCreated = true
    let window = one.mac.open("second", in: app)
    one.mac.pass(1)
    story.check("it is announced all the same, as one that has just opened", one.heard.outline.first == .appeared(window.number), one.heard.texts)
  }

  // Apps that have just launched refuse observers (scripts/mac-shell/apptool.swift tries every 0.25 s, up to twenty times).
  for wait in [0.0, 1.0, 6.0] {
    book.story("an app is launched\(wait > 0 ? " and refuses observers for \(Int(wait)) s" : "")") { story in
      let one = StoreyOne(story) { mac in mac.open("mine", in: mac.launch("Mine")) }
      let app = one.mac.launch("Fresh", readyAfter: wait)
      one.mac.pass(0.3)
      let window = one.mac.open("hello", in: app)
      one.mac.pass(wait + 10)
      story.check(
        "its window is announced once, as one that has just opened",
        one.heard.about(window).filter { $0 != .focused(window.number) } == [.appeared(window.number)], one.heard.texts)
      story.check("and is said to have the keyboard", one.lastWordOnTheKeyboard == window.number, one.heard.texts)
    }
  }

  book.story("an app becomes a regular app only after its launch") { story in
    let one = StoreyOne(story) { mac in mac.open("mine", in: mac.launch("Mine")) }
    let app = one.mac.launch("Late", policy: .accessory, announced: false)
    one.mac.pass(1)
    app.policy = .regular
    let window = one.mac.open("hello", in: app)
    one.mac.pass(1)
    story.check("nothing says so, and Arbor does not know its window yet", !one.known.contains(window.number))
    one.mac.activate(app)
    one.mac.pass(1)
    story.check(
      "when it comes forward its window is announced",
      one.heard.about(window).contains { $0 == .appeared(window.number) || $0 == .found(window.number) }, one.heard.texts)
    story.check("and is said to have the keyboard", one.lastWordOnTheKeyboard == window.number, one.heard.texts)
  }

  // macOS 26 reports AXDialog for every minimized window and every window of a hidden app, ordinary ones included.
  book.story("windows are minimized and hidden when Arbor starts") { story in
    var small: FakeMac.Window!, hidden: FakeMac.Window!, dialog: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Docs")
      small = mac.open("small", in: app)
      mac.open("stays", in: app)
      mac.minimize(small)
      let shy = mac.launch("Shy")
      hidden = mac.open("hidden", in: shy)
      dialog = mac.open("really a dialog", in: shy, subrole: "AXDialog")
      mac.open("mine", in: mac.launch("Mine"))
      mac.hide(shy)
    }
    story.check("the minimized window is known, as minimized", one.snapshot(small)?.isMinimized == true)
    story.check("the hidden app's window is known, as hidden", one.snapshot(hidden)?.isHidden == true)
    one.heard.clear()
    one.mac.restore(small)
    one.mac.pass(2)
    story.check("restored, it stays", one.known.contains(small.number) && one.snapshot(small)?.isMinimized == false, one.heard.texts)
    one.mac.activate(hidden.app)
    one.mac.pass(2)
    story.check("shown again, the window stays", one.known.contains(hidden.number) && one.snapshot(hidden)?.isHidden == false, one.heard.texts)
    story.check("and what turns out to be a dialog goes", !one.known.contains(dialog.number), "\(one.known)")
  }
}
