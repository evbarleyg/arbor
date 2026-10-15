import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A start ends with the focused window in view, as a resume does. Nobody tells Arbor where the keyboard went while it was
/// not running. A launch shows everything, that window included (LaunchShowsEverythingTests); the view that the watchdog's
/// start brings back may not include it.
@Suite @MainActor struct ReviewLaunchKeyboardTests {
  /// [editor | Desktop | browser], framed on the editor, which has the keyboard. The terminal floats, so it is out of
  /// view with the Desktop.
  func makeHarness() -> (Harness, editor: WindowID, browser: WindowID, terminal: WindowID) {
    let h = Harness()
    let editor = h.system.open(app: "Editor", pid: 1001)
    let browser = h.system.open(app: "Browser", pid: 1002)
    let terminal = h.system.open(
      app: "Terminal", bundleID: "com.apple.Terminal", pid: 1003, frame: CGRect(x: 300, y: 200, width: 400, height: 300))
    h.start()
    h.run("dock \(editor.rawValue) left")
    h.run("dock \(browser.rawValue) right")
    settle(h)
    h.system.userFocus(editor)
    h.run("zoom")
    settle(h)
    return (h, editor, browser, terminal)
  }

  func settle(_ h: Harness) { h.scheduler.advance(by: 3) }

  func isOutOfView(_ window: WindowID, _ h: Harness) -> Bool {
    h.controller.parked.contains(window) && !h.system.isVisible(window)
  }

  /// The same windows seen by a new Arbor process that loads what `old` saved, with the keyboard in `focused`.
  func relaunch(_ old: Harness, focused: WindowID?, byTheWatchdog: Bool = false) -> Harness {
    let new = Harness(displays: old.system.displayList, saved: old.store.saved)
    for window in old.system.allWindows().sorted(by: { $0.id < $1.id }) {
      new.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    new.system.focused = focused
    new.controller.restartedAfterAccident = byTheWatchdog
    new.start()
    return new
  }

  /// Quitting ends a summon, so state.json has the window as sent away. Whoever quits Arbor from the terminal they
  /// summoned, or starts it again from Spotlight, still has the keyboard in it.
  @Test func launchedWithTheKeyboardInTheWindowThatWasSummonedAtQuitItIsInView() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let place = h.frame(terminal)!
    h.controller.shutdown()

    let new = relaunch(h, focused: terminal)
    settle(new)
    #expect(new.system.focused == terminal)
    #expect(new.system.isVisible(terminal), "keys must not go to a window out of view")
    #expect(!new.controller.parked.contains(terminal))
    #expect(new.frame(terminal) == place, "where it was")
    #expect(new.workspace.camera == new.workspace.tree.root)

    // It is an ordinary floating window now, and stays.
    #expect(new.controller.role(of: terminal) == nil)
    new.system.userFocus(editor)
    #expect(new.frame(terminal) == place)
  }

  @Test func launchedWithTheKeyboardElsewhereAWindowThatWasSentAwayStaysWhereTheQuitPutIt() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.controller.shutdown()
    let place = h.frame(terminal)!
    let new = relaunch(h, focused: editor)
    settle(new)
    #expect(new.frame(terminal) == place && new.system.isVisible(terminal))
    #expect(new.controller.role(of: terminal) == nil)
  }

  /// Nobody quit, so it is sent away still, and in its corner.
  @Test func startedAgainAfterItDiedAWindowThatWasSentAwayIsOutOfViewAsItWasLeft() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.system.userFocus(editor)
    settle(h)
    let new = relaunch(h, focused: editor, byTheWatchdog: true)
    settle(new)
    #expect(isOutOfView(terminal, new))
    #expect(new.controller.role(of: terminal) == .stashed)
  }

  /// No summon involved: the saved view is framed on the editor, and somebody is typing in the browser by now.
  @Test func launchedWithTheKeyboardInADockedWindowThatTheSavedViewLeavesOutTheViewGoesToIt() {
    let (h, _, browser, _) = makeHarness()
    h.controller.shutdown()

    let new = relaunch(h, focused: browser)
    settle(new)
    #expect(new.system.focused == browser)
    #expect(new.layout?.windowFrames[browser] != nil)
    #expect(new.system.isVisible(browser), "keys must not go to a window out of view")
    #expect(!new.controller.parked.contains(browser))
  }

  @Test func launchedWithTheKeyboardInAWindowOfTheSavedViewEverythingShowsAllTheSame() {
    let (h, editor, browser, _) = makeHarness()
    let (camera, back) = (h.workspace.camera, h.workspace.back)
    h.controller.shutdown()

    let new = relaunch(h, focused: editor)
    settle(new)
    #expect(new.workspace.camera == new.workspace.tree.root)
    #expect(new.workspace.back == back + [camera], "the keyboard adds nothing to go back to")
    #expect(new.system.focused == editor)
    #expect(new.system.isVisible(browser))
  }

  /// The watchdog starts Arbor again a second after it died: nothing was put back, and the view is the one of a second ago.
  @Test func startedAgainAfterItDiedTheViewOfASecondAgoStays() {
    let (h, editor, browser, terminal) = makeHarness()
    let (camera, frames) = (h.workspace.camera, [editor, browser, terminal].map { h.frame($0) })

    let new = relaunch(h, focused: editor, byTheWatchdog: true)
    settle(new)
    #expect(new.workspace.camera == camera)
    #expect([editor, browser, terminal].map { new.frame($0) } == frames, "nothing has a reason to move")
    #expect(new.system.focused == editor)
  }

  /// ⌘Tab in the second that Arbor was gone: the browser has the keyboard in its corner.
  @Test func startedAgainAfterItDiedWithTheKeyboardInAWindowThatTheViewLeavesOutTheViewGoesToIt() {
    let (h, _, browser, _) = makeHarness()
    let new = relaunch(h, focused: browser, byTheWatchdog: true)
    settle(new)
    #expect(new.system.focused == browser)
    #expect(new.layout?.windowFrames[browser] != nil)
    #expect(new.system.isVisible(browser), "keys must not go to a window out of view")
    #expect(!new.controller.parked.contains(browser))
  }

  @Test func startedWithTheKeyboardInNothingArborKnowsTheViewDoesNotMove() {
    let (h, _, _, _) = makeHarness()
    let camera = h.workspace.camera
    let again = relaunch(h, focused: nil, byTheWatchdog: true)
    settle(again)
    #expect(again.workspace.camera == camera)

    h.controller.shutdown()
    let new = relaunch(h, focused: nil)
    settle(new)
    #expect(new.workspace.camera == new.workspace.tree.root)
  }
}
