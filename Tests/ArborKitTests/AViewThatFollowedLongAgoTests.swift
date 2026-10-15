import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Arbor keeps on record that the view has followed the keyboard from one window to another: if the first goes in the same moment, macOS had handed the
/// keyboard on, nobody asked to see the other window, and the view is taken back (Controller+Focus.swift). These are about when that record ends.
@Suite @MainActor struct AViewThatFollowedLongAgoTests {
  /// ⌘Tab to Notes, out of view: the view steps out, and Safari stays in view. A click on Safari moves no view. Seconds later ⌘W on it,
  /// its app's last window. The record was still there and made this the late end of that story: no loss, no look, and nobody had the keyboard.
  @Test(arguments: ["close", "minimize"], [0.1, 5]) func itSwallowsNoLoss(going: String, later: Double) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11)
    let notes = h.system.open(app: "Notes", pid: 12)
    let mail = h.system.open(app: "Mail", pid: 13)
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(mail.rawValue) beside \(safari.rawValue) bottom")
    h.run("dock \(notes.rawValue) right")
    h.run("zoom \(safari.rawValue)")
    h.run("out")
    h.run("focus \(safari.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(safari) && h.system.isVisible(mail) && !h.system.isVisible(notes), "\(h.ascii())")
    h.system.userFocus(notes)
    h.scheduler.advance(by: later)
    #expect(h.system.isVisible(safari) && h.system.isVisible(notes), "\(h.ascii())")
    h.system.userFocus(safari)
    h.scheduler.advance(by: later)
    if going == "close" { h.system.close(safari) } else { h.system.setMinimized(safari, true) }
    #expect(h.system.focused == nil)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == notes, "the one used last: \(String(describing: h.system.focused))")
    expectWindowsMatchLayout(h)
  }

  /// What can come between the view's following and the report of the going, on a Mac that is busy. None of it ends the record.
  enum Between: String, CaseIterable { case nothing, saidAgain, anAppInTheBackground, aThirdWindowOutOfView, aThirdWindowInView }

  @Test(arguments: Between.allCases, ["close", "minimize"]) func withinTheMomentTheViewIsStillTakenBack(between: Between, going: String) {
    let (h, a, a2, b, c) = AGoingIsOneActTests().aColumnInView()
    let a3 = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 700, y: 300, width: 600, height: 400))
    h.run("dock \(a3.rawValue) beside \((between == .aThirdWindowInView ? c : b).rawValue) bottom")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a && !h.system.isVisible(a2))
    func name(_ window: WindowID, _ seconds: Double) {
      h.system.focused = window
      h.controller.windowFocused(window)
      h.scheduler.advance(by: seconds)
    }
    name(a2, 0.06)
    #expect(h.system.isVisible(a2), "the view has followed")
    switch between {
    case .nothing: break
    case .saidAgain: h.controller.windowFocused(a2)
    case .anAppInTheBackground: h.system.backgroundFocus(b)
    case .aThirdWindowOutOfView, .aThirdWindowInView: name(a3, 0.01)
    }
    h.scheduler.advance(by: 0.01)
    h.system.echoes.keyboard = false
    if going == "close" { h.system.close(a) } else { h.system.setMinimized(a, true) }
    h.scheduler.advance(by: 2)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(b), "\(h.ascii())")
    #expect(h.system.focused.map { h.system.isVisible($0) } == true, "\(String(describing: h.system.focused))")
    expectWindowsMatchLayout(h)
  }

  /// The window macOS picked goes first, and then the one that had the keyboard before it, each its app's own doing.
  @Test func theHeirGoesAndThenTheHolder() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11)
    let a2 = h.system.open(app: "Safari", pid: 11)
    let mail = h.system.open(app: "Mail", pid: 13)
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(mail.rawValue) beside \(a.rawValue) bottom")
    h.run("dock \(a2.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    h.system.userFocus(a2)
    h.scheduler.advance(by: 2)
    #expect(h.system.isVisible(a2) && h.system.isVisible(a))
    h.system.close(a2)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == a)
    h.system.close(a)
    h.scheduler.advance(by: 2)
    #expect(h.system.focused == mail, "\(String(describing: h.system.focused))")
  }
}
