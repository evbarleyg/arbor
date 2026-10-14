import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A launch ends with the focused window in view, as a resume does. Nobody tells Arbor where the keyboard went while it was
/// not running, and the view it saved may not include that window.
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
  func relaunch(_ old: Harness, focused: WindowID?) -> Harness {
    let new = Harness(displays: old.system.displayList, saved: old.store.saved)
    for window in old.system.allWindows().sorted(by: { $0.id < $1.id }) {
      new.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    new.system.focused = focused
    new.start()
    return new
  }

  /// Quitting ends a summon, so state.json has the window as sent away. Whoever quits Arbor from the terminal they
  /// summoned, or starts it again from Spotlight, still has the keyboard in it.
  @Test func launchedWithTheKeyboardInTheWindowThatWasSummonedAtQuitItIsInView() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    let (place, camera) = (h.frame(terminal)!, h.workspace.camera)
    h.controller.shutdown()

    let new = relaunch(h, focused: terminal)
    settle(new)
    #expect(new.system.focused == terminal)
    #expect(new.system.isVisible(terminal), "keys must not go to a window out of view")
    #expect(!new.controller.parked.contains(terminal))
    #expect(new.frame(terminal) == place, "where it was")
    #expect(new.controller.role(of: terminal) == .summoned(app: "com.apple.Terminal"))
    #expect(new.workspace.camera == camera, "a summoned window comes over the view, which stays")

    // It goes like any summoned window.
    new.system.userFocus(editor)
    #expect(isOutOfView(terminal, new))
  }

  @Test func launchedWithTheKeyboardElsewhereAWindowThatWasSentAwayIsOutOfViewAsItWasLeft() {
    let (h, editor, _, terminal) = makeHarness()
    h.run("summon Terminal")
    h.controller.shutdown()
    let new = relaunch(h, focused: editor)
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

  @Test func launchedWithTheKeyboardInAWindowInViewTheViewDoesNotMove() {
    let (h, editor, browser, _) = makeHarness()
    let (camera, back) = (h.workspace.camera, h.workspace.back)
    h.controller.shutdown()

    let new = relaunch(h, focused: editor)
    settle(new)
    #expect(new.workspace.camera == camera)
    #expect(new.workspace.back == back, "nor is there anything new to go back to")
    #expect(new.system.focused == editor)
    #expect(isOutOfView(browser, new))
  }

  /// The watchdog starts Arbor again a second after it died: nothing was put back, and the view is the one of a second ago.
  @Test func startedAgainAfterItDiedTheViewOfASecondAgoStays() {
    let (h, editor, browser, terminal) = makeHarness()
    let (camera, frames) = (h.workspace.camera, [editor, browser, terminal].map { h.frame($0) })

    let new = relaunch(h, focused: editor)
    settle(new)
    #expect(new.workspace.camera == camera)
    #expect([editor, browser, terminal].map { new.frame($0) } == frames, "nothing has a reason to move")
    #expect(new.system.focused == editor)
  }

  @Test func launchedWithTheKeyboardInNothingArborKnowsTheViewDoesNotMove() {
    let (h, _, _, _) = makeHarness()
    let camera = h.workspace.camera
    h.controller.shutdown()
    let new = relaunch(h, focused: nil)
    settle(new)
    #expect(new.workspace.camera == camera)
  }
}
