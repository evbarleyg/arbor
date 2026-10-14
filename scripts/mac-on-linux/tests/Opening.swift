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
      story.check("then it is reported to have the keyboard", one.heard.outline == [.appeared(window.number), .focused(window.number)], one.heard.texts)
      story.check("Arbor has its frame", one.snapshot(window)?.frame == window.frame, "\(String(describing: one.snapshot(window)?.frame))")
      story.check("and its title and app", one.snapshot(window)?.title == "second" && one.snapshot(window)?.appName == "Notes")
    }
  }
}
