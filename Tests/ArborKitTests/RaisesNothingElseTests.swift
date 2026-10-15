import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// "Arbor raises nothing else": which window lies in front of which is macOS's business. The window acted on or switched to comes to the
/// front, with the keyboard; a window kept in view has a raise of its own (Controller+Pin.swift). Taking a window out of view and bringing
/// it back does not change its place in the order (collab/QUESTIONS.md, Q20 and Q25).
///
/// Two raises went with that decision. A guest that came back with its host's view was raised over the host, which is the very window
/// its person had just switched to. And a floating window too large for the Desktop, which a layout left hanging over a docked one, was raised
/// over whatever lay there.
@Suite @MainActor struct RaisesNothingElseTests {
  // MARK: As the random walks found it

  /// Plays a script of the chaos lab and says how often the window switched to ended behind another. A script of which a line is refused, or
  /// at whose last step, when all has come to rest, the net does not ask, proves nothing. Nor does one in which nothing overlaps the window.
  func timesTheWindowSwitchedToEndedBehind(_ script: String, sourceLocation: SourceLocation = #_sourceLocation) -> [String] {
    let runner = ChaosRunner()
    var found: [String] = []
    var askedBeforeTheLastStep = 0
    for action in ChaosAction.script(script) {
      askedBeforeTheLastStep = ChaosRunner.questionsAsked["switched-to", default: 0]
      found += runner.step(action).filter { $0.rule == "switched-to-behind" }.map { "\($0)" }
      #expect(runner.refusals == [], "\(action.text)", sourceLocation: sourceLocation)
    }
    #expect(ChaosRunner.questionsAsked["switched-to", default: 0] > askedBeforeTheLastStep, "nobody asked at the end", sourceLocation: sourceLocation)
    let system = runner.system
    if let wanted = system.focusedWindow(), let frame = system.windows[wanted]?.snapshot.frame {
      let others = system.windows.values.map(\.snapshot).filter { $0.id != wanted && $0.isPresent && $0.frame.insetBy(dx: 2, dy: 2).overlaps(frame) }
      #expect(!others.isEmpty, "nothing lies where \(wanted) does, so nothing could be in front of it", sourceLocation: sourceLocation)
    } else {
      Issue.record("nobody has the keyboard at the end", sourceLocation: sourceLocation)
    }
    return found
  }

  @Test(arguments: [
    // A desk anybody has: two windows docked, one framed, a third opens over it. ⌘Tab to the other docked window, and back.
    """
    displays main:0,0,1440,900:25,0,70,0* windows-never
    open 101 Safari pid 1000 at 100 60 1100 700 min 574 240
    open 102 Terminal pid 1003 at 197 224 877 499 min 177 60
    launch
    settle
    focus 101
    key down dock left
    key up dock left
    settle
    focus 102
    key down dock right
    key up dock right
    settle
    key down zoom
    key up zoom
    settle
    open 103 Finder pid 1005 at 152 278 920 436 min 501 300
    focus 103
    settle
    focus 101
    settle
    focus 102
    settle
    """,
    // The same as the walk left it, shrunk.
    """
    open 101 Xcode pid 1004 at 70 31 1188 776 min 1188 685
    open 102 Terminal pid 1003 at 197 324 991 444 min 177 60
    launch
    key down arrange
    key down in
    open 103 Terminal pid 1003 at 152 278 965 394 min 177 60
    focus 101
    focus 102
    react
    advance 1
    """,
  ]) func aGuestThatComesBackIsNotRaisedOverTheHostItsPersonSwitchedTo(script: String) {
    #expect(timesTheWindowSwitchedToEndedBehind(script) == [])
  }

  @Test(arguments: [
    """
    open 101 Xcode pid 1004 at 0 25 1280 689 min 1188 685
    launch
    open 104 Terminal pid 1003 at 239 93 1026 554 min 177 60
    key down dock top
    key down toggle-float
    key down toggle-float
    open 105 Finder pid 1005 at 196 71 1021 506 min 501 300
    key down zoom
    restore 104
    open 106 Terminal pid 1003 at 357 146 719 464 min 177 60
    key down toggle-float
    focus 105
    settle
    """,
    """
    open 101 Safari pid 1000 at 178 1856 1140 560 min 574 240
    open 104 Safari pid 1000 at 999 38 900 816 min 574 240
    launch
    open 105 Preview pid 1007 at 578 1903 723 650 min 723 400 max 723 2000
    key down dock left
    key down zoom
    open 106 Finder pid 1005 at -292 1705 773 449 min 501 300
    key down dock right
    focus 101
    react
    advance 5
    """,
  ]) func aFloatingWindowLeftHangingOverDockedOnesIsNotRaisedOverTheWindowSwitchedTo(script: String) {
    #expect(timesTheWindowSwitchedToEndedBehind(script) == [])
  }

  // MARK: Told as a person would

  /// `[a | b | Desktop]`, framed on `a`, with a guest over it; then the view goes to `b`, and the guest out of view with its host.
  func aGuestOutOfViewWithItsHost() -> (Harness, host: WindowID, other: WindowID, guest: WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    h.start()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    let guest = h.system.open(app: "Finder", pid: 13, frame: CGRect(x: 400, y: 200, width: 500, height: 400))
    h.system.userFocus(b)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: b) && !h.system.isVisible(guest))
    h.system.clearRaiseLog()
    return (h, a, b, guest)
  }

  @Test func theHostSwitchedToIsInFrontOfItsGuestAndTheGuestIsBackWhereItWas() {
    let (h, host, _, guest) = aGuestOutOfViewWithItsHost()
    h.system.userFocus(host)
    h.scheduler.advance(by: 1)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: host))
    #expect(h.frame(guest) == CGRect(x: 400, y: 200, width: 500, height: 400), "it comes back with its host's view, where it was")
    #expect(h.system.windowsFrontToBack().first == host, "the window switched to is in front: \(h.system.windowsFrontToBack())")
    #expect(h.system.focusedWindow() == host)
    #expect(h.system.raiseLog == [])
  }

  /// What the raise was there for: a guest behind a host that fills the view cannot be seen. These are the ways to it that remain.
  @Test(arguments: ["desktop", "focus %guest", "zoom %guest", "a switch", "Go to…"]) func aGuestBehindItsHostCanBeReached(way: String) {
    let (h, host, _, guest) = aGuestOutOfViewWithItsHost()
    h.system.userFocus(host)
    h.scheduler.advance(by: 1)
    #expect(h.frame(host)!.contains(h.frame(guest)!) && h.system.windowsFrontToBack().first == host, "wholly covered")
    h.system.clearRaiseLog()
    if way == "a switch" {
      // ⌘Tab, the Dock, Mission Control, ⌘` within one app.
      h.system.userFocus(guest)
    } else if way == "Go to…" {
      #expect(h.run("find").ok)
      #expect(h.overlays.finder?.model.rows.contains { $0.destination == .window(guest) } == true, "it is in the list")
      h.controller.finderChose(.window(guest))
    } else {
      #expect(h.run(way.replacingOccurrences(of: "%guest", with: String(guest.rawValue))).ok)
    }
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(guest))
    let above = h.system.windowsFrontToBack().prefix { $0 != guest }
    #expect(!above.contains { h.system.isVisible($0) && h.frame($0)!.overlaps(h.frame(guest)!) }, "\(way): still behind \(Array(above))")
    #expect(h.system.raiseLog == [], "and by no raise without the keyboard")
  }

  /// There and back changes no window's place in the order. Two guests, one in front of the host and one behind it: raised as they came
  /// back, both ended in front of the host.
  @Test(arguments: ["back", "zoom %host", "view 1"]) func outOfViewAndBackLeavesTheOrderAsItWas(command: String) {
    for hostWasInFront in [false, true] {
      let h = Harness()
      let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
      let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 200, width: 500, height: 400))
      h.start()
      h.run("arrange")
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      h.system.cursor = CGPoint(x: 1200, y: 700)
      let behind = h.system.open(app: "Finder", pid: 13, frame: CGRect(x: 300, y: 300, width: 500, height: 400))
      h.system.userFocus(a)
      let inFront = h.system.open(app: "Mail", pid: 14, frame: CGRect(x: 400, y: 200, width: 500, height: 400))
      h.system.userFocus(hostWasInFront ? a : inFront)
      func ofTheThree() -> [WindowID] { h.system.windowsFrontToBack().filter { $0 != b } }
      let before = ofTheThree()
      #expect(before == (hostWasInFront ? [a, inFront, behind] : [inFront, a, behind]))
      h.system.clearRaiseLog()
      h.run("zoom \(b.rawValue)")
      #expect(!h.system.isVisible(behind) && !h.system.isVisible(inFront))
      h.run(command.replacingOccurrences(of: "%host", with: String(a.rawValue)))
      h.scheduler.advance(by: 1)
      #expect(h.system.isVisible(behind) && h.system.isVisible(inFront))
      #expect(ofTheThree() == before, "`\(command)`, the \(hostWasInFront ? "host" : "guest") was in front")
      #expect(h.system.raiseLog == [])
    }
  }

  /// The view is on two docked windows, so both floating windows are out of view. Their person switches to one of them. The view steps out, both
  /// come back, and the other one is too wide for the Desktop and hangs over a docked window: raised for that, it ended in front of the window
  /// that was switched to.
  @Test func aWideFloatingWindowThatComesBackTooStaysBehindTheFloatingWindowSwitchedTo() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
    let wide = h.system.open(
      app: "Preview", pid: 12, frame: CGRect(x: 500, y: 38, width: 800, height: 689), minimumSize: CGSize(width: 800, height: 400))
    let wanted = h.system.open(app: "Finder", pid: 13, frame: CGRect(x: 600, y: 261, width: 700, height: 453))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    let b = h.system.open(app: "Terminal", pid: 14, frame: CGRect(x: 279, y: 190, width: 600, height: 354))
    h.run("dock \(b.rawValue) right")
    #expect(h.controller.parked.isSuperset(of: [wide, wanted]), "\(h.ascii())")
    h.system.clearRaiseLog()
    h.system.userFocus(wanted)
    #expect(h.controller.parked.isDisjoint(with: [wide, wanted]), "\(h.ascii())")
    #expect(h.frame(wide)!.overlaps(h.frame(b)!.insetBy(dx: 2, dy: 2)) && h.frame(wide)!.overlaps(h.frame(wanted)!), "\(h.ascii())")
    #expect(h.system.windowsFrontToBack().first == wanted, "the window switched to is in front: \(h.system.windowsFrontToBack())")
    #expect(h.system.focusedWindow() == wanted)
    #expect(h.system.raiseLog == [])
  }

  // MARK: What is still raised

  /// "The raise: one, when the pin is set" (Q25). A window pinned while it is out of view is raised as it comes in, also while another pinned
  /// window has the keyboard, when the looks that follow raise nothing (Controller+Pin.swift).
  @Test func aWindowPinnedWhileOutOfViewIsRaisedAsItComesIn() {
    let h = Harness()
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 800, y: 200, width: 500, height: 400))
    let call = h.system.open(app: "Zoom", pid: 13, frame: CGRect(x: 60, y: 60, width: 300, height: 200))
    let timer = h.system.open(app: "Clock", pid: 14, frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("pin \(call.rawValue)")
    h.system.userFocus(call)
    h.scheduler.advance(by: 1)
    #expect(!h.system.isVisible(timer))
    h.system.clearRaiseLog()
    #expect(h.run("pin \(timer.rawValue)").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.isVisible(timer))
    #expect(h.system.raiseLog == [timer], "once")
    let order = h.system.windowsFrontToBack()
    #expect(order.firstIndex(of: timer)! < order.firstIndex(of: a)!, "in front of the framed window: \(order)")
    #expect(h.system.focusedWindow() == call, "the keyboard stays where it is")
  }

  /// Q20, "what a person sees at their first dock": the window docked comes to the front, with the keyboard, also when it is docked by command
  /// while another is in front. The loose windows that lay there are behind it, untouched, in the order they had.
  @Test func atAFirstDockBesideTwoFloatingWindowsOnlyTheDockedOneComesToTheFront() {
    let h = Harness()
    let docked = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let one = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 200, y: 150, width: 500, height: 400))
    let other = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    h.start()
    h.system.userFocus(one)
    h.system.userFocus(other)
    #expect(h.system.windowsFrontToBack() == [other, one, docked])
    #expect(h.run("dock \(docked.rawValue) left").ok)
    h.scheduler.advance(by: 1)
    #expect(h.system.windowsFrontToBack() == [docked, other, one])
    #expect(h.system.focusedWindow() == docked)
    #expect(h.system.raiseLog == [])
  }

  // MARK: Nothing else, ever

  /// A morning without a window kept in view or summoned: whatever is asked of Arbor, it raises nothing. What comes to the front
  /// comes with the keyboard.
  @Test func withNothingKeptInViewNoCommandAndNoSwitchRaisesAnything() {
    let h = Harness()
    let ids = ["Safari", "Notes", "Mail", "Terminal"].enumerated().map { index, app in
      h.system.open(app: app, pid: Int32(11 + index), frame: CGRect(x: 80 + 90 * index, y: 60 + 50 * index, width: 700, height: 480))
    }
    let wide = h.system.open(
      app: "Xcode", pid: 20, frame: CGRect(x: 300, y: 120, width: 1000, height: 600), minimumSize: CGSize(width: 1000, height: 500))
    h.start()
    let acts = [
      "dock \(ids[0].rawValue) left", "dock \(ids[1].rawValue) right", "resize \(ids[0].rawValue) right 80", "zoom \(ids[0].rawValue)", "open",
      "neighbor right", "back", "switch \(ids[1].rawValue)", "switch \(ids[0].rawValue)", "show-all", "desktop", "home",
      "dock \(ids[2].rawValue) beside \(ids[0].rawValue) bottom", "zoom \(ids[2].rawValue)", "out", "switch \(wide.rawValue)", "home", "swap \(ids[0].rawValue) \(ids[1].rawValue)",
      "float \(ids[1].rawValue)", "undo", "arrange", "zoom \(wide.rawValue)", "show-all", "pause", "resume", "float-all",
    ]
    for act in acts {
      if act == "open" {
        _ = h.system.open(app: "Finder", pid: 30, frame: CGRect(x: 400, y: 200, width: 500, height: 400))
      } else if act.hasPrefix("switch "), let id = UInt32(act.dropFirst(7)) {
        h.system.userFocus(WindowID(id))
      } else {
        let result = h.run(act)
        #expect(result.ok, "\(act): \(result.message)")
      }
      h.scheduler.advance(by: 1)
      #expect(h.system.raiseLog == [], "after \(act)")
      h.system.clearRaiseLog()
    }
  }

  // MARK: The net over the random walks, and its controls

  /// Plays `lines`, then `last` with window `raised` raised as part of it, as if Arbor had done it. Says whether `raised-unasked` spoke.
  func theNetSpeaks(after lines: [String], then last: String, raising raised: WindowID?) -> Bool {
    let runner = ChaosRunner()
    for line in lines { _ = runner.step(ChaosAction(text: line)) }
    if let raised { runner.beforeTheNextCheck = { $0.system.raise(raised) } }
    return runner.step(ChaosAction(text: last)).contains { $0.rule == "raised-unasked" }
  }

  @Test func theNetSpeaksAtARaiseOfAnyWindowThatIsNotKeptInView() {
    // Apart from each other, so that no other net has anything to say: the raise is the fault, not what it covers.
    let desk = ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400", "dock 101 left", "settle"]
    for last in ["cursor 10 10", "zoom 101", "flush", "pause", "quit"] {
      #expect(!theNetSpeaks(after: desk, then: last, raising: nil), "\(last)")
      #expect(theNetSpeaks(after: desk, then: last, raising: WindowID(102)), "a floating window, at \(last)")
      #expect(theNetSpeaks(after: desk, then: last, raising: WindowID(101)), "a docked window, at \(last)")
    }
    // Once, at the step in which it was made.
    let runner = ChaosRunner()
    for line in desk { _ = runner.step(ChaosAction(text: line)) }
    runner.beforeTheNextCheck = { $0.system.raise(WindowID(102)) }
    #expect(runner.step(ChaosAction(text: "flush")).contains { $0.rule == "raised-unasked" })
    #expect(!runner.step(ChaosAction(text: "flush")).contains { $0.rule == "raised-unasked" })
  }

  @Test func theNetIsSilentAtARaiseOfAWindowKeptInView() {
    let desk = ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "open 102 Mail pid 1002 at 800 300 500 400", "dock 101 left", "settle"]
    #expect(!theNetSpeaks(after: desk, then: "pin 102", raising: WindowID(102)), "the raise at the pin")
    #expect(theNetSpeaks(after: desk + ["pin 102", "settle"], then: "zoom 101", raising: WindowID(102)), "there are no retries")
    #expect(theNetSpeaks(after: desk + ["pin 102", "settle"], then: "unpin 102", raising: WindowID(102)))
    #expect(theNetSpeaks(after: desk + ["pin 102", "settle", "unpin 102", "settle"], then: "zoom 101", raising: WindowID(102)), "no longer")
    #expect(theNetSpeaks(after: desk + ["pin 102", "settle"], then: "zoom 101", raising: WindowID(101)), "the other one is not")
    #expect(!theNetSpeaks(after: desk, then: "summon Mail", raising: WindowID(102)), "nor at one as it is summoned")
    #expect(theNetSpeaks(after: desk + ["set summonStays true", "summon Mail", "settle"], then: "zoom 101", raising: WindowID(102)), "later it is")
    #expect(theNetSpeaks(after: desk + ["summon Mail", "settle", "summon Mail", "settle"], then: "zoom 101", raising: WindowID(102)), "sent away again")
    // An Arbor that has paused or quit raises nothing, whatever it kept in view.
    for way in ["pause", "quit"] {
      #expect(!theNetSpeaks(after: desk + ["pin 102", "settle"], then: way, raising: nil), "\(way)")
      #expect(theNetSpeaks(after: desk + ["pin 102", "settle"], then: way, raising: WindowID(102)), "\(way)")
      #expect(theNetSpeaks(after: desk + ["pin 102", "settle", way], then: "flush", raising: WindowID(102)), "after \(way)")
    }
  }

  /// As 10,000 walks found it: a false alarm of this net, while Arbor still looked at a pin a moment after whatever might have covered it, and
  /// `way-back pause` let that look fall due and then paused, in one step. There are no such looks any more (Q25): the story raises nothing.
  @Test func aPinThatIsCoveredIsRaisedOnNoWayBack() {
    let covered = [
      "open 102 Mail pid 1002 at 78 171 1265 623 min 760 400", "open 104 Preview pid 1007 at 222 109 723 553 min 723 400 max 723 2000", "launch",
      "via menu arrange all", "via menu toggle-pin", "focus 102",
    ]
    let endings = [["way-back pause"], ["settle", "pause", "settle"], ["pause", "settle"], ["way-back quit"], ["quit", "settle"]]
    for ending in endings {
      let runner = ChaosRunner()
      for line in covered { _ = runner.step(ChaosAction(text: line)) }
      let raisedBefore = runner.system.raiseLog.count
      let found = ending.flatMap { runner.step(ChaosAction(text: $0)) }.filter { $0.rule == "raised-unasked" }.map { "\($0)" }
      #expect(found == [], "\(ending)")
      #expect(runner.system.raiseLog.count == raisedBefore, "\(ending): \(runner.system.raiseLog)")
    }
    // A window that nothing keeps in view is not excused on a way back either.
    #expect(theNetSpeaks(after: covered + ["unpin 104", "settle"], then: "way-back pause", raising: WindowID(104)))
  }

  /// Somebody who empties the window system's list between two steps does not blind the net.
  @Test func theNetKeepsCountWhenTheListOfRaisesIsEmptied() {
    let runner = ChaosRunner()
    for line in ["launch", "open 101 Notes pid 1001 at 100 100 500 400", "settle"] { _ = runner.step(ChaosAction(text: line)) }
    for _ in 0..<2 {
      runner.beforeTheNextCheck = { $0.system.raise(WindowID(101)) }
      #expect(runner.step(ChaosAction(text: "flush")).contains { $0.rule == "raised-unasked" })
      runner.system.clearRaiseLog()
    }
  }

  /// Walks a person could take find nothing. A net that never comes to its question catches nothing: counted is how often a floating window
  /// that nothing keeps in view came back into view, which is where the raises were. With either raise put back these forty walks find it;
  /// the next forty do not find the guest's.
  @Test func ordinaryWalksRaiseNothingUnasked() {
    let askedBefore = ChaosRunner.questionsAsked["raised", default: 0]
    for seed in UInt64(1)...40 {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed, ordinary: true)
      var found: [InvariantViolation] = []
      for _ in 0..<200 { found += runner.step(generator.next(runner)) }
      for way in ChaosRunner.WayBack.allCases { found += runner.step(.wayBack(way)) }
      #expect(found.filter { $0.rule == "raised-unasked" }.map { "\($0)" } == [], "seed \(seed)")
    }
    let asked = ChaosRunner.questionsAsked["raised", default: 0] - askedBefore
    #expect(asked >= 30, "a floating window came back into view \(asked) times")
  }
}
