import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let both = "displays main:0,0,1512,982:37,0,0,0* side:1512,-200,2560,1440:25,0,0,0"
private let laptopAlone = "displays main:0,0,1512,982:37,0,0,0*"
/// `between` is the order nearly every window was recorded speaking in on hosted Macs. `first`, in which ALL of them speak while macOS's
/// list of displays is still the old one, is harsher than any recording (with real apps ONE window of a change often does): a control.
private let orders = ["between", "late", "silent", "first"]
/// The orders in which a window of a display that goes "arrives": in `first` macOS's move passes for somebody's own.
private let arrivingOrders = ["between", "late", "silent"]
private let terminal = WindowID(101)
private let music = WindowID(101)

/// A floating window that no layout can place when its display goes: its app is hidden, it is in the Dock, or the view of the display
/// it arrives on is held and shows nothing, which lets no layout through.
///
/// Whatever changes display counts as out of view until the layout has placed it. What no layout placed went on counting, and the last
/// step of a change of displays sends whatever counts as out of view to the corner of the displays as they are now. So with nothing
/// docked (rule 2) a window macOS had just brought onto the laptop, in full view, was taken to the corner behind its person's back.
/// Now it is put where it floats. Where the windows speak first the fault never showed (macOS's move passes for
/// somebody's own, so nothing "arrives"): that order is played all the same, as a control.
@Suite @MainActor struct AwayWhenItsDisplayGoesTests {
  @discardableResult
  private func play(
    _ lines: [String], in runner: ChaosRunner = ChaosRunner(), sourceLocation: SourceLocation = #_sourceLocation
  ) -> ChaosRunner {
    // Of the known failures only those that have nothing to do with a floating window being moved are let pass.
    let aboutThis: Set<String> = [
      "moved-before-any-dock", "moved-unasked", "moved-twice", "moved-again", "there-and-back-moved", "left-its-place", "parked-not-put-back",
    ]
    for line in lines {
      let violations = runner.step(ChaosAction(text: line)).filter { !ChaosRunner.knownRules.subtracting(aboutThis).contains($0.rule) }
      #expect(violations.isEmpty, "\(line): \(violations)", sourceLocation: sourceLocation)
    }
    return runner
  }

  private func frame(_ window: WindowID, in runner: ChaosRunner) -> CGRect { runner.system.windows[window]!.snapshot.frame }

  /// How much of `window` the displays show, of 1.
  private func share(of window: WindowID, in runner: ChaosRunner) -> CGFloat {
    let frame = frame(window, in: runner)
    return runner.system.displayList.map { frame.intersection($0.frame).area }.reduce(0, +) / frame.area
  }

  /// Nothing docked, Terminal on the monitor; `away` takes it off the screen; the monitor is unplugged.
  private func unplugged(_ away: String?, order: String) -> ChaosRunner {
    play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "settle"]
        + [away, "settle", "\(laptopAlone) windows-\(order)", "settle"].compactMap { $0 })
  }

  // MARK: Nothing docked

  @Test(arguments: ["hide 1003", "minimize 101"], orders)
  func whatIsOffTheScreenWhenItsDisplayGoesIsNotSentToTheCorner(away: String, order: String) {
    let runner = unplugged(away, order: order)
    #expect(share(of: terminal, in: runner) == 1, "\(frame(terminal, in: runner))")
    #expect(!runner.controller.parked.contains(terminal))
    #expect(runner.controller.workspaces[DisplayID("main")]?.isFloating(terminal) == true)
    // Back on the screen it is there, and nothing moves before its person's eyes.
    let was = frame(terminal, in: runner)
    let mark = runner.system.frameLog.count
    play([away == "minimize 101" ? "restore 101" : "show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == was)
    #expect(runner.system.frameLog[mark...].allSatisfy { $0.frame == was }, "\(runner.system.frameLog[mark...])")
  }

  /// Kept in view and off the screen at once: put where it floats, and NOT raised as the layout raises what it brings in. On a Mac a raise
  /// fetches a minimized window out of the Dock (`a-raise-fetches-a-minimized-window-out-of-the-dock` in `collab/reality.json`), which
  /// would undo its person's ⌘M.
  @Test(arguments: ["hide 1003", "minimize 101"], arrivingOrders)
  func keptInViewAndOffTheScreenItIsNotRaised(away: String, order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "pin 101", "settle", away, "settle"])
    runner.system.clearRaiseLog()
    play(["\(laptopAlone) windows-\(order)", "settle"], in: runner)
    #expect(!runner.system.raiseLog.contains(terminal), "\(runner.system.raiseLog)")
    #expect(share(of: terminal, in: runner) == 1, "\(frame(terminal, in: runner))")
    #expect(!runner.controller.parked.contains(terminal))
    #expect(runner.controller.workspaces[DisplayID("main")]?.isPinned(terminal) == true)
  }

  /// The control: in sight all along, it ends in the same place.
  @Test(arguments: orders) func inSightItEndsInTheSamePlace(order: String) {
    #expect(frame(terminal, in: unplugged(nil, order: order)) == frame(terminal, in: unplugged("hide 1003", order: order)))
  }

  /// macOS goes by the displays' corners, Arbor went by what the menu bars leave, so the two places can differ by a few points.
  /// Where macOS has brought a window is where it is: Arbor moves nothing, not now and not when the window shows again. (Where the
  /// windows speak first the window counts as the laptop's from then on, and the monitor does not get it back: an older fault.)
  @Test(arguments: ["hide 1003", "minimize 101", nil], arrivingOrders)
  func whereMacOSHasBroughtItIsWhereItStays(away: String?, order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 0 800 500 min 177 60", "settle", away, "settle"]
        .compactMap { $0 })
    let mark = runner.system.frameLog.count
    play(["\(laptopAlone) windows-\(order)", "settle"], in: runner)
    let broughtTo = CGRect(x: 488, y: 200, width: 800, height: 500)
    #expect(frame(terminal, in: runner) == broughtTo)
    play([away == "minimize 101" ? "restore 101" : "show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == broughtTo)
    #expect(runner.system.frameLog[mark...].allSatisfy { $0.frame == broughtTo }, "\(runner.system.frameLog[mark...])")
    #expect(runner.controller.workspaces[DisplayID("main")]?.floating[terminal] == broughtTo)
    // And the monitor gets it back to the point.
    play(["\(both) windows-\(order)", "settle"], in: runner)
    #expect(frame(terminal, in: runner) == CGRect(x: 2000, y: 0, width: 800, height: 500))
  }

  // MARK: There and back is nothing, off the screen too

  /// The monitor is plugged in again while the window is still off the screen: it is back where it floated, and nothing moves when it shows.
  @Test(arguments: ["hide 1003", "minimize 101"], arrivingOrders)
  func pluggedInAgainItIsBackBeforeItShows(away: String, order: String) {
    let runner = unplugged(away, order: order)
    play(["\(both) windows-\(order)", "settle", "react", "advance 1", "react"], in: runner)
    let own = CGRect(x: 2000, y: 200, width: 800, height: 600)
    #expect(frame(terminal, in: runner) == own)
    #expect(runner.controller.workspaces[DisplayID("side")]?.isFloating(terminal) == true)
    let mark = runner.system.frameLog.count
    play([away == "minimize 101" ? "restore 101" : "show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == own)
    #expect(runner.system.frameLog[mark...].allSatisfy { $0.frame == own }, "\(runner.system.frameLog[mark...])")
  }

  /// A guard: it held before. Whether an app obeys a move while its window is off the screen, nobody has measured. If it does not, the
  /// window is fetched when it shows, as it always was: it must not pass for placed and be left on the laptop, filed under the monitor.
  @Test func anAppThatDoesNotObeyWhileHiddenIsFetchedWhenItShows() {
    let runner = unplugged("hide 1003", order: "late")
    play(["behave 101 frozen", "\(both) windows-late", "settle", "react", "advance 1", "react"], in: runner)
    play(["behave 101 normal", "show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == CGRect(x: 2000, y: 200, width: 800, height: 600))
    #expect(!runner.controller.parked.contains(terminal))
  }

  /// Left hanging over the monitor's edges by its person's own hand, it hangs there again, and does not jump when it shows.
  @Test(arguments: ["hide 1003", nil], arrivingOrders)
  func whereItsPersonLeftItHangingItHangsAgain(away: String?, order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "advance 1"]
        + ["grab 101", "carry 3900 700", "release", "settle", "advance 1"])
    let left = frame(terminal, in: runner)
    #expect(share(of: terminal, in: runner) < 1, "it hangs over the edge: \(left)")
    play(
      [away, "settle", "\(laptopAlone) windows-\(order)", "settle", "react", "advance 1", "react"].compactMap { $0 }
        + ["\(both) windows-\(order)", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == left)
    play(["show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == left)
  }

  /// The laptop's view is on one window, so hidden Terminal went out of view there, rightly. The monitor comes back, with its Desktop
  /// in view: Terminal is back where it floated, not in the monitor's corner, where a crash would leave it.
  @Test(arguments: arrivingOrders) func outOfViewOnTheLaptopItIsStillBackOnTheMonitor(order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "advance 1"]
        + ["open 110 Notes pid 1001 at 500 300 700 500 min 300 200", "key down dock right", "key up dock right", "advance 1"]
        + ["key down zoom", "key up zoom", "advance 1", "react", "hide 1003", "settle", "\(laptopAlone) windows-\(order)", "settle"])
    #expect(runner.controller.parked.contains(terminal))
    play(["react", "advance 1", "\(both) windows-\(order)", "settle", "react", "advance 1", "settle", "crash", "show 1003", "settle"], in: runner)
    #expect(frame(terminal, in: runner) == CGRect(x: 2000, y: 200, width: 800, height: 600))
  }

  /// In the Dock on the laptop while the lid is shut and opened. (A guard: it held before, by way of the corner.)
  @Test(arguments: ["hide 1003", "minimize 101"], arrivingOrders)
  func throughAShutLidItIsBackOnTheLaptop(away: String, order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 300 200 800 600 min 177 60", "advance 1", away, "react", "advance 1", "react"]
        + ["displays side:0,0,2560,1440:25,0,0,0* windows-\(order)", "settle", "react", "advance 1", "react"]
        + ["\(both) windows-\(order)", "settle", "react", "advance 1", "react"]
        + [away == "minimize 101" ? "restore 101" : "show 1003", "settle", "react", "advance 1", "react"])
    #expect(frame(terminal, in: runner) == CGRect(x: 300, y: 200, width: 800, height: 600))
  }

  /// What made it more than a detour: if Arbor ended there, by a crash, the window stayed in the corner.
  @Test func afterACrashItIsStillInView() {
    let runner = unplugged("hide 1003", order: "late")
    play(["crash", "show 1003", "settle"], in: runner)
    #expect(share(of: terminal, in: runner) == 1, "\(frame(terminal, in: runner))")
  }

  /// As a hosted Mac was seen to do it (`macos-leaves-a-window-that-is-off-the-screen-where-its-display-was` in `collab/reality.json`): macOS
  /// does not bring such a window over. It stays where its display was until it shows. Arbor puts it where it floats on the laptop,
  /// in one move, while it is away, and nothing moves when it shows. So it was on that Mac.
  @Test(arguments: ["hide 1003", "minimize 101"]) func leftWhereItsDisplayWasItIsPutInViewWhileItIsAway(away: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "settle", away, "settle"])
    let unplugging = runner.system.frameLog.count
    play(["\(laptopAlone) windows-never", "settle"], in: runner)
    #expect(runner.system.frameLog[unplugging...].filter { $0.window == terminal }.count == 1, "\(runner.system.frameLog[unplugging...])")
    #expect(share(of: terminal, in: runner) == 1, "\(frame(terminal, in: runner))")
    #expect(!runner.controller.parked.contains(terminal))
    let was = frame(terminal, in: runner)
    let showing = runner.system.frameLog.count
    play([away == "minimize 101" ? "restore 101" : "show 1003", "settle", "react", "advance 1", "react"], in: runner)
    #expect(frame(terminal, in: runner) == was)
    #expect(runner.system.frameLog[showing...].allSatisfy { $0.frame == was }, "\(runner.system.frameLog[showing...])")
  }

  // MARK: What belongs out of view goes out of view as before

  /// A guard: it held before. The laptop's view is on one window, so its Desktop is out of view, and what floats goes with it, hidden or not. (Where the
  /// windows speak first nothing arrives: macOS's move passes for somebody's own, and what somebody lays over a view stays.)
  @Test(arguments: ["hide 1003", nil], arrivingOrders)
  func withTheDesktopOutOfViewWhatArrivesGoesOutOfView(away: String?, order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Terminal pid 1003 at 2000 200 800 600 min 177 60", "advance 1"]
        + ["open 110 Notes pid 1001 at 500 300 700 500 min 300 200", "key down dock right", "key up dock right", "advance 1"]
        + ["key down zoom", "key up zoom", "advance 1", "react", away, "settle", "\(laptopAlone) windows-\(order)", "settle"]
        .compactMap { $0 })
    #expect(runner.controller.parked.contains(terminal))
    #expect(share(of: terminal, in: runner) < 0.01, "\(frame(terminal, in: runner))")
  }

  /// Out of view for real since before (the monitor's view is on one window), then hidden; the lid opens. It is the laptop's, and must
  /// not be left lying over the monitor's view, held or not. (A guard against letting be whatever happens to show somewhere.)
  @Test(arguments: [["toggle-hold", "advance 1"], []], arrivingOrders)
  func whatWasOutOfViewForRealIsNotLeftOverAnotherDisplaysView(hold: [String], order: String) {
    let runner = play(
      ["\(both) windows-first", "launch", "open 101 Mail pid 1002 at 200 150 900 600 min 400 300", "advance 1"]
        + ["open 120 Keynote pid 1007 at 2700 100 900 700 min 400 300", "advance 1", "key down dock right", "key up dock right", "advance 1", "react"]
        + ["key down zoom", "key up zoom", "advance 1", "react"] + hold
        + ["displays side:0,0,2560,1440:25,0,0,0* windows-\(order)", "settle", "react", "advance 1", "react", "hide 1002", "react", "advance 1", "react"]
        + ["\(both) windows-\(order)", "settle", "react", "advance 1", "react", "show 1002", "settle", "react", "advance 1", "react"])
    #expect(frame(WindowID(101), in: runner) == CGRect(x: 200, y: 150, width: 900, height: 600))
  }

  // MARK: A held view that shows nothing

  /// Music on the monitor; Terminal docked and framed on the laptop. `steps` come between that and the unplugging.
  private func unpluggedBesideAFramedTerminal(pinned: Bool, _ steps: [String], order: String) -> ChaosRunner {
    play(
      ["\(both) windows-first", "launch", "open 101 Music pid 1006 at 2000 200 800 600 min 680 480", pinned ? "pin 101" : nil, "advance 1"]
        .compactMap { $0 }
        + ["open 110 Terminal pid 1003 at 500 300 700 500 min 177 60", "key down dock right", "key up dock right", "advance 1"]
        + ["key down zoom", "key up zoom", "advance 1", "react"] + steps
        + ["react", "advance 1", "react", "\(laptopAlone) windows-\(order)", "react", "advance 1", "react"])
  }

  /// "Always in view" is its person's own word about that window. The one display left showed nothing at all.
  @Test(arguments: ["hide 1003", "close 110", "full-screen 110 on"], orders)
  func aPinnedWindowArrivesInViewUnderAHeldViewThatShowsNothing(emptiedBy: String, order: String) {
    let runner = unpluggedBesideAFramedTerminal(pinned: true, ["toggle-hold", "advance 1", emptiedBy], order: order)
    #expect(share(of: music, in: runner) == 1, "\(frame(music, in: runner))")
    #expect(!runner.controller.parked.contains(music))
    #expect(runner.controller.workspaces[DisplayID("main")]?.isPinned(music) == true)
  }

  /// The controls: without the hold, and with the held view still showing its window, it always did.
  @Test(arguments: [["advance 1", "hide 1003"], ["toggle-hold", "advance 1"]])
  func aPinnedWindowArrivesInViewOtherwiseToo(steps: [String]) {
    let runner = unpluggedBesideAFramedTerminal(pinned: true, steps, order: "late")
    #expect(share(of: music, in: runner) == 1, "\(frame(music, in: runner))")
    #expect(!runner.controller.parked.contains(music))
  }

  /// A guard: it held before. Not pinned, it is an ordinary floating window, and a held view gives nothing away: it goes out of view with the Desktop. However the
  /// view was emptied: after ⌘W the camera is on what was around the window, Desktop included. (Where the windows speak first it
  /// stays in view, before this change and after: macOS's move passes for somebody's own. An older fault, and a worse one here.)
  @Test(arguments: ["hide 1003", "close 110", "minimize 110"], arrivingOrders)
  func whatIsNotPinnedStaysOutOfAHeldView(emptiedBy: String, order: String) {
    let runner = unpluggedBesideAFramedTerminal(pinned: false, ["toggle-hold", "advance 1", emptiedBy], order: order)
    #expect(runner.controller.parked.contains(music))
    #expect(share(of: music, in: runner) < 0.01, "\(frame(music, in: runner))")
  }

  // MARK: A display that only blinked

  /// The same last step ends a blink: the monitor is gone and back before anything is reported.
  @Test func afterABlinkAHiddenAppsWindowIsNotInTheCorner() {
    let main = FakeWindowSystem.standardDisplay
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [main, side])
    let spot = CGRect(x: 1900, y: 100, width: 300, height: 200)
    let d = h.system.open(app: "Terminal", pid: 1003, frame: spot)
    h.start()
    h.system.setHidden(pid: 1003, true)
    h.scheduler.advance(by: 1)
    h.system.displayList = [main]
    h.system.userMove(d, to: CGRect(x: 100, y: 60, width: 300, height: 200))
    h.scheduler.advance(by: 1)
    h.system.displayList = [main, side]
    h.scheduler.advance(by: 5)
    // As a window in sight is (`afterABlinkWhatMacOSMovedIsPutBack`).
    #expect(h.frame(d) == spot)
    #expect(!h.controller.parked.contains(d))
  }
}
