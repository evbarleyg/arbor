import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// The window with the keyboard goes, its app's next window is out of view, and the Mac is busy: the going is reported later than the moment the view
/// waits (`Controller.timeForAGoing`), so the view has followed. It is taken back. However late the report, within the time that makes them one
/// event, the end is the one of a going that was reported in time, and from the going on every window goes straight to where it ends up.
@Suite @MainActor struct ALateGoingIsOneMoveTests {
  enum Going: String { case close, minimize }

  /// All there is to see and to go back to.
  struct End: Equatable, CustomStringConvertible {
    var frames: [WindowID: CGRect]
    var cameras: [DisplayID: NodeID]
    var back: [DisplayID: [NodeID]]
    var forward: [DisplayID: [NodeID]]
    var focused: WindowID?
    var parked: Set<WindowID>
    var description: String {
      let places = frames.sorted { $0.key < $1.key }.map { "\($0.key.rawValue): \($0.value)" }
      return "\(places) views \(cameras.sorted { $0.key < $1.key }.map(\.value)) back \(back.sorted { $0.key < $1.key }.map(\.value)) "
        + "forward \(forward.sorted { $0.key < $1.key }.map(\.value)) keyboard \(String(describing: focused)) out of view \(parked.sorted())"
    }
  }

  func realMoves(_ h: Harness, since mark: Int) -> [FakeWindowSystem.Move] { h.system.moveLog[mark...].filter { $0.before != $0.after } }

  /// macOS names `heir`, and `late` seconds pass before anything else is heard.
  func name(_ heir: WindowID, in h: Harness, late: Double) {
    h.system.focused = heir
    h.controller.windowFocused(heir)
    h.scheduler.advance(by: late)
  }

  func go(_ going: Going, _ window: WindowID, in h: Harness) {
    h.system.echoes.keyboard = false
    if going == .close { h.system.close(window) } else { h.system.setMinimized(window, true) }
    h.scheduler.advance(by: 2)
  }

  /// Plays the going of `a` with the heir `a2` in time and late, then `commands`.
  func bothOrdersEndAlike(
    _ going: Going, late: Double = 0.06, then commands: [String] = [], _ build: () -> (Harness, a: WindowID, a2: WindowID),
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    var ends: [End] = []
    var pictures: [String] = []
    for wait in [0.004, late] {
      let (h, a, a2) = build()
      name(a2, in: h, late: wait)
      let mark = h.system.moveLog.count
      h.overlays.clearTransitions()
      go(going, a, in: h)
      // One motion shows the going and the way back.
      #expect(h.overlays.transitions.count <= 1, "after \(wait): \(h.overlays.transitions.count) motions", sourceLocation: sourceLocation)
      // Each goes straight to where it ends up. A size it is asked for where it stands is part of the road, not a second move.
      for window in Set(realMoves(h, since: mark).map(\.window)).sorted() {
        let detour = FakeWindowSystem.detour(h.system.road(of: window, since: mark))
        #expect(detour == nil, "after \(wait): \(window) \(detour ?? "")", sourceLocation: sourceLocation)
      }
      for problem in h.layoutProblems() { Issue.record("after \(wait): \(problem)", sourceLocation: sourceLocation) }
      let holder = h.system.focused
      #expect(
        holder.map { h.system.isVisible($0) && !h.controller.parked.contains($0) } == true, "after \(wait): the keyboard is in \(String(describing: holder))",
        sourceLocation: sourceLocation)
      for command in commands {
        h.run(command)
        h.scheduler.advance(by: 2)
      }
      var end = End(
        frames: h.system.windows.mapValues(\.snapshot.frame), cameras: h.controller.workspaces.mapValues(\.camera),
        back: h.controller.workspaces.mapValues(\.back), forward: h.controller.workspaces.mapValues(\.forward), focused: h.system.focused,
        parked: h.controller.parked)
      end.frames[a] = nil
      end.parked.remove(a)
      // Out of view is out of view: a window that was never shown lies in the corner at another size than one that was.
      for window in end.parked { end.frames[window] = .zero }
      ends.append(end)
      pictures.append(h.ascii())
    }
    #expect(ends[0] == ends[1], "\nIN TIME \(ends[0])\nLATE    \(ends[1])\n\(pictures[0])\n\(pictures[1])", sourceLocation: sourceLocation)
  }

  // MARK: What is in view

  /// What is left of the group is a row in a row, which the tree keeps whole only while the view is on it. The view was taken back after the
  /// window had left the arrangement: history led to everything, Notes and Mail went out of view, and every window moved.
  @Test(arguments: [Going.close, .minimize], [0.06, 0.2, 0.29]) func aGroupThatDissolves(going: Going, late: Double) {
    bothOrdersEndAlike(going, late: late) {
      let s = AGoingIsOneActTests().aGroupInView()
      return (s.0, s.a, s.a2)
    }
  }

  @Test func whatIsLeftOfTheGroupStaysInView() {
    let (h, a, b, c, a2) = AGoingIsOneActTests().aGroupInView()
    name(a2, in: h, late: 0.06)
    #expect(h.system.isVisible(a2), "the view has followed")
    go(.close, a, in: h)
    #expect(h.system.isVisible(b) && h.system.isVisible(c) && !h.system.isVisible(a2), "\(h.ascii())")
    #expect(h.workspace.camera != h.workspace.tree.root)
    #expect(h.system.focused == b || h.system.focused == c)
    expectWindowsMatchLayout(h)
  }

  /// Laid out for the going at the view that had followed, and then for the way back, the neighbour moved twice.
  @Test(arguments: [Going.close, .minimize]) func aColumn(going: Going) {
    bothOrdersEndAlike(going) {
      let s = AGoingIsOneActTests().aColumnInView()
      return (s.0, s.a, s.a2)
    }
  }

  // MARK: What floats

  /// `[a / c | Desktop | b / a2]` or the group, the keyboard in `a`, and Music floating on the Desktop, out of view.
  func aFloatOutOfView(group: Bool) -> (Harness, a: WindowID, a2: WindowID, music: WindowID) {
    let (h, a, a2): (Harness, WindowID, WindowID)
    if group {
      let s = AGoingIsOneActTests().aGroupInView()
      (h, a, a2) = (s.0, s.a, s.a2)
    } else {
      let s = AGoingIsOneActTests().aColumnInView()
      (h, a, a2) = (s.0, s.a, s.a2)
    }
    let view = h.workspace.camera
    h.run("show-all")
    let music = h.system.open(app: "Music", pid: 14, frame: CGRect(x: 620, y: 300, width: 200, height: 200))
    h.scheduler.advance(by: 2)
    h.run("focus \(a.rawValue)")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == view && h.system.focused == a)
    #expect(!h.system.isVisible(a2) && !h.system.isVisible(music), "\(h.ascii())")
    return (h, a, a2, music)
  }

  /// The view goes out, the Desktop comes into view and the float with it, and back. A layout that only follows a change of the arrangement
  /// sends nothing out of view: the float stayed lying over a view it had never been in.
  @Test(arguments: [false, true], [Going.close, .minimize]) func aFloatThatWasOutOfViewIsOutOfViewAgain(group: Bool, going: Going) {
    let (h, a, a2, music) = aFloatOutOfView(group: group)
    name(a2, in: h, late: 0.06)
    #expect(h.system.isVisible(a2) && h.system.isVisible(music))
    go(going, a, in: h)
    #expect(!h.system.isVisible(a2))
    #expect(!h.system.isVisible(music) && h.controller.parked.contains(music), "\(String(describing: h.frame(music)))\n\(h.ascii())")
    bothOrdersEndAlike(going) {
      let s = aFloatOutOfView(group: group)
      return (s.0, s.a, s.a2)
    }
  }

  /// A window of another app has opened over the view and floats there.
  @Test(arguments: [false, true], [Going.close, .minimize]) func aFloatOverTheViewStaysWhereItIs(group: Bool, going: Going) {
    bothOrdersEndAlike(going) {
      let (h, a, a2): (Harness, WindowID, WindowID)
      if group {
        let s = AGoingIsOneActTests().aGroupInView()
        (h, a, a2) = (s.0, s.a, s.a2)
      } else {
        let s = AGoingIsOneActTests().aColumnInView()
        (h, a, a2) = (s.0, s.a, s.a2)
      }
      let music = h.system.open(app: "Music", pid: 14, frame: CGRect(x: 500, y: 300, width: 200, height: 200))
      h.scheduler.advance(by: 2)
      h.system.userFocus(a)
      h.scheduler.advance(by: 2)
      #expect(h.system.isVisible(music) && h.system.focused == a && !h.system.isVisible(a2))
      return (h, a, a2)
    }
  }

  /// The window macOS picks floats itself, and went out of view with the Desktop when Safari was framed. It stayed over Safari and kept the keyboard.
  @Test(arguments: [Going.close, .minimize]) func theHeirFloats(going: Going) {
    bothOrdersEndAlike(going) {
      let h = Harness()
      let safari = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 700, height: 500))
      let a2 = h.system.open(app: "Music", pid: 16, frame: CGRect(x: 300, y: 200, width: 700, height: 480))
      h.start()
      h.run("dock \(safari.rawValue) left")
      h.run("focus \(safari.rawValue)")
      h.run("zoom \(safari.rawValue)")
      h.scheduler.advance(by: 2)
      let a = h.system.open(app: "Music", pid: 16, frame: CGRect(x: 400, y: 300, width: 600, height: 400))
      h.scheduler.advance(by: 2)
      #expect(h.system.focused == a && !h.system.isVisible(a2) && h.system.isVisible(safari))
      return (h, a, a2)
    }
  }

  // MARK: Afterwards

  /// The way back is no part of what the closing changed. As part of the step, `undo` said that it had undone the closing and threw the view out
  /// to everything.
  @Test(arguments: [["undo"], ["back"], ["back", "forward"], ["out"], ["undo", "redo"]]) func whatComesAfterwardsEndsAlikeToo(commands: [String]) {
    bothOrdersEndAlike(.close, then: commands) {
      let s = AGoingIsOneActTests().aGroupInView()
      return (s.0, s.a, s.a2)
    }
  }

  @Test func aClosingCannotBeUndoneHoweverLateItWasReported() {
    let (h, a, b, c, a2) = AGoingIsOneActTests().aGroupInView()
    name(a2, in: h, late: 0.06)
    go(.close, a, in: h)
    let (view, mark) = (h.workspace.camera, h.system.moveLog.count)
    #expect(!h.run("undo").ok)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == view && h.system.isVisible(b) && h.system.isVisible(c))
    #expect(realMoves(h, since: mark).isEmpty)
  }

  // MARK: A window in no arrangement

  /// A rule has come to leave the window alone (a late title), so it is in no arrangement and nothing is laid out when it goes. A view taken back on
  /// paper for it stayed on paper, and the next layout took the window with the keyboard out of view.
  @Test func aWindowThatARuleLeavesAloneTakesNoViewBack() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.safari", title: "Picture", action: .ignore)]
    let h = Harness(settings: settings)
    let mail = h.system.open(app: "Mail", pid: 13)
    let a2 = h.system.open(app: "Safari", pid: 11)
    h.start()
    h.run("dock \(mail.rawValue) left")
    h.run("dock \(a2.rawValue) right")
    h.run("zoom \(mail.rawValue)")
    h.scheduler.advance(by: 2)
    let a = h.system.open(app: "Safari", title: "", pid: 11, frame: CGRect(x: 500, y: 300, width: 300, height: 200))
    h.scheduler.advance(by: 0.5)
    h.system.setTitle(a, "Picture in Picture")
    #expect(h.controller.filter.ignoredWindowIDs == [a] && !h.workspace.contains(a))
    h.scheduler.advance(by: 5)
    #expect(h.system.focused == a && !h.system.isVisible(a2))
    name(a2, in: h, late: 0.06)
    #expect(h.system.isVisible(a2), "the view has followed")
    go(.close, a, in: h)
    #expect(h.staleLayouts().isEmpty, "\(h.staleLayouts())")
    h.run("relayout")
    h.scheduler.advance(by: 2)
    #expect(h.system.focused.map { h.system.isVisible($0) } == true, "typing into \(String(describing: h.system.focused))\n\(h.ascii())")
  }

  // MARK: Tabs, room that was lent, and what floats over the docked windows

  /// `next` is named, a tenth of a second passes, in which the view follows, and only then is the going of `going` reported.
  func closeLate(_ going: WindowID, next: WindowID, in h: Harness) {
    h.system.focused = next
    h.controller.windowFocused(next)
    h.scheduler.advance(by: 0.1)
    #expect(h.system.isVisible(next), "the view has followed: \(h.ascii())")
    h.system.echoes.keyboard = false
    h.beginStep()
    h.system.close(going)
    h.system.echoes.keyboard = true
    h.scheduler.advance(by: 2)
  }

  /// The Desktop is in the view, with two floating windows: one on it, one that its person left over the docked windows. In the view that
  /// followed the Desktop is a tile, so on the way back it "comes into view", which gathers what floats. Not what nobody had touched.
  ///
  /// As Arbor ships no layout places a floating window at all. This is for whoever has `floatingWindowsMakeWay` on.
  @Test(arguments: [false, true], [false, true]) func whatFloatsStaysWhereItsPersonLeftIt(late: Bool, makeWay: Bool) {
    var settings = Settings()
    settings.floatingWindowsMakeWay = makeWay
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11)
    let b = h.system.open(app: "Notes", pid: 12)
    let a2 = h.system.open(app: "Safari", pid: 11)
    let onTheDesktop = h.system.open(app: "Calc", pid: 15, frame: CGRect(x: 900, y: 200, width: 300, height: 200))
    let overTheOthers = h.system.open(app: "Clock", pid: 16, frame: CGRect(x: 950, y: 500, width: 300, height: 200))
    h.start()
    h.run("dock \(a2.rawValue) right")
    h.run("desktop")
    h.run("dock \(b.rawValue) left")
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 2)
    h.system.userMove(overTheOthers, to: CGRect(x: 60, y: 300, width: 300, height: 200))
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    if late { closeLate(a, next: a2, in: h) } else { h.system.close(a) }
    h.scheduler.advance(by: 2)
    #expect(h.frame(overTheOthers) == CGRect(x: 60, y: 300, width: 300, height: 200), "\(h.ascii())")
    // The Desktop is wider by the room the window left, and what had made way on it is back at its own place.
    #expect(h.frame(onTheDesktop) == CGRect(x: 900, y: 200, width: 300, height: 200), "\(h.ascii())")
    #expect(h.system.isVisible(b) && !h.system.isVisible(a2), "\(h.ascii())")
  }

  /// Out of a tab group the tab that comes forward is the one that comes forward at any closing, at once: not one, then another.
  @Test(arguments: ["[Notes Safari Mail]", "[Notes Mail Safari]", "[Safari Notes Mail]"]) func aTabThatGoesLateLeavesOneTabInFront(group: String) {
    func play(late: Bool) -> (h: Harness, shows: [WindowID]) {
      let h = Harness()
      let a = h.system.open(app: "Safari", pid: 11)
      let others = [h.system.open(app: "Notes", pid: 12), h.system.open(app: "Mail", pid: 13)]
      let a2 = h.system.open(app: "Safari", pid: 11)
      h.start()
      h.system.userFocus(a2)
      h.system.userFocus(a)
      #expect(h.run("layout \(group) | Safari").ok)
      h.run("focus \(a.rawValue)")
      h.run("zoom \(a.rawValue)")
      h.scheduler.advance(by: 2)
      #expect(h.system.focused == a && h.system.isVisible(a) && !h.system.isVisible(a2))
      if late {
        closeLate(a, next: a2, in: h)
      } else {
        h.beginStep()
        h.system.close(a)
        h.scheduler.advance(by: 2)
      }
      expectWindowsMatchLayout(h)
      return (h, others.filter { h.system.isVisible($0) })
    }
    let (late, first) = (play(late: true), play(late: false))
    #expect(late.h.jolts.isEmpty, "\(late.h.jolts)")
    #expect(late.shows == first.shows && late.shows.count == 1, "\(late.h.ascii())")
    #expect(late.h.system.focused == late.shows.first)
  }

  /// The window that goes had borrowed room from its neighbours (F61). They get it back in the move that brings them into view.
  @Test(arguments: [true, false]) func neighboursThatHadLentRoomMoveOnce(share: Bool) {
    var settings = Settings()
    settings.shareRemovedSpace = share
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, minimumSize: CGSize(width: 200, height: 420))
    let c = h.system.open(app: "Notes", pid: 12, minimumSize: CGSize(width: 200, height: 200))
    let d = h.system.open(app: "Mail", pid: 13)
    let b = h.system.open(app: "Music", pid: 14)
    let a2 = h.system.open(app: "Safari", pid: 11)
    h.start()
    h.run("dock \(c.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(d.rawValue) beside \(c.rawValue) bottom")
    h.run("dock \(a.rawValue) beside \(c.rawValue) top")
    h.run("dock \(a2.rawValue) beside \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    #expect(h.workspace.tree.hasLoans)
    closeLate(a, next: a2, in: h)
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.system.isVisible(c) && h.system.isVisible(d) && !h.system.isVisible(a2), "\(h.ascii())")
    expectWindowsMatchLayout(h)
  }

  /// With the neighbours in the view that followed as well: they used to move for the room the window left, and again for the way back.
  @Test(arguments: [true, false]) func neighboursInBothViewsMoveOnce(share: Bool) {
    var settings = Settings()
    settings.shareRemovedSpace = share
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", pid: 11, minimumSize: CGSize(width: 200, height: 420))
    let c = h.system.open(app: "Notes", pid: 12, minimumSize: CGSize(width: 200, height: 260))
    let d = h.system.open(app: "Mail", pid: 13)
    let b = h.system.open(app: "Music", pid: 14)
    let a2 = h.system.open(app: "Safari", pid: 11)
    h.start()
    h.run("dock \(c.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(d.rawValue) beside \(c.rawValue) bottom")
    h.run("dock \(a.rawValue) beside \(c.rawValue) top")
    h.run("dock \(a2.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(a.rawValue)")
    h.run("out")
    h.run("focus \(a.rawValue)")
    h.scheduler.advance(by: 2)
    closeLate(a, next: a2, in: h)
    #expect(h.jolts.isEmpty, "\(h.jolts)")
    #expect(h.system.isVisible(c) && h.system.isVisible(d) && !h.system.isVisible(a2), "\(h.ascii())")
    expectWindowsMatchLayout(h)
  }
}
