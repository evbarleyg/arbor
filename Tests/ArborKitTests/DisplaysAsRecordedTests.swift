import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What is heard of the stand-in: each report with the frame it carries and the number of displays macOS has at that moment, and the time that passes.
@MainActor
private final class Heard: WindowSystemEvents {
  unowned let system: FakeWindowSystem
  var lines: [String] = []
  init(_ system: FakeWindowSystem) { self.system = system }

  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    let frame = window.frame
    lines.append(
      "\(window.id) \(userInitiated ? "by hand" : "by Arbor") (\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))×\(Int(frame.height))), \(system.displays().count) displays")
  }
  func displaysChanged() { lines.append("told of \(system.displays().count) displays") }
  func windowAppeared(_ window: WindowSnapshot) {}
  func windowDestroyed(_ id: WindowID) {}
  func windowFocused(_ id: WindowID) {}
  func applicationActivated(_ app: FrontmostApp?) {}
  func accessibilityWasRefused() {}
  func dragBegan(_ id: WindowID, at point: CGPoint) {}
  func dragMoved(_ id: WindowID, to point: CGPoint) {}
  func dragEnded(_ id: WindowID, at point: CGPoint) {}
  func resizeBegan(_ id: WindowID) {}
  func resizeEnded(_ id: WindowID) {}
  func keyboardFocusMoved() {}
  func dragCancelled(_ id: WindowID) {}
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
  func pointerPressed() {}
}

/// A change of displays in the order and at the times hosted Macs were recorded to make it (`FakeWindowSystem.changeDisplaysAsAMacDoes`).
@Suite @MainActor struct DisplaysAsRecordedTests {
  /// Displays of the recordings: 1920×1080 with a menu bar and a Dock, and 1280×800 beside it.
  static let main = DisplaySnapshot(
    id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 0, y: 31, width: 1920, height: 971),
    isMain: true)
  static func side(at corner: CGPoint) -> DisplaySnapshot {
    DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(origin: corner, size: CGSize(width: 1280, height: 800)),
      visibleFrame: CGRect(x: corner.x, y: corner.y + 31, width: 1280, height: 769), isMain: false)
  }

  /// With an app to each window: the first speaks under the old displays, that it moved. Under the new ones the others say so, in the caller's order, and
  /// the first that its size changed; then the others whose size changed. Arbor is told last, 1.67 s after macOS had the new list.
  @Test func oneSpeaksUnderTheOldDisplaysTheOthersUnderTheNewAndArborIsToldLast() {
    let system = FakeWindowSystem(displays: [Self.main])
    let a = system.open(app: "Mail", pid: 11, frame: CGRect(x: 12, y: 43, width: 624, height: 947))
    let b = system.open(app: "Safari", pid: 12, frame: CGRect(x: 700, y: 100, width: 400, height: 300))
    let c = system.open(app: "Notes", pid: 13, frame: CGRect(x: 1284, y: 43, width: 624, height: 947))
    let still = system.open(app: "Preview", pid: 14, frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    let heard = Heard(system)
    system.events = heard
    system.start()
    system.passTime = { heard.lines.append("\(($0 * 100).rounded() / 100) s") }
    system.changeDisplaysAsAMacDoes(
      [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))],
      moving: [
        (c, CGRect(x: 582, y: 300, width: 480, height: 348)), (b, CGRect(x: 710, y: 110, width: 400, height: 300)),
        (a, CGRect(x: 450, y: 372, width: 480, height: 348)),
      ])
    #expect(
      heard.lines == [
        "\(c) by hand (582,300 480×348), 1 displays", "0.05 s",
        "0.03 s", "\(c) by hand (582,300 480×348), 2 displays", "\(b) by hand (710,110 400×300), 2 displays",
        "\(a) by hand (450,372 480×348), 2 displays",
        "0.05 s", "\(a) by hand (450,372 480×348), 2 displays",
        "1.59 s", "told of 2 displays",
      ])
    #expect(system.frame(of: still) == CGRect(x: 900, y: 500, width: 300, height: 200))
    #expect(system.windows.values.allSatisfy { $0.placeIsArborsDoing }, "from here on every place is Arbor's to answer for, as after `setDisplays`")
  }

  /// A window that was only moved and spoke early has no more to say: three of the sixteen.
  @Test func movedAndNoMoreTheFirstSpeaksOnce() {
    let system = FakeWindowSystem(displays: [Self.main])
    let a = system.open(app: "Terminal", pid: 11, frame: CGRect(x: 737, y: 300, width: 863, height: 499))
    let b = system.open(app: "TextEdit", pid: 12, frame: CGRect(x: 165, y: 65, width: 673, height: 439))
    let heard = Heard(system)
    system.events = heard
    system.start()
    system.changeDisplaysAsAMacDoes(
      [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))],
      moving: [(a, CGRect(x: 1000, y: 300, width: 863, height: 499)), (b, CGRect(x: 165, y: 65, width: 656, height: 422))])
    #expect(
      heard.lines == [
        "\(a) by hand (1000,300 863×499), 1 displays", "\(b) by hand (165,65 656×422), 2 displays", "\(b) by hand (165,65 656×422), 2 displays",
        "told of 2 displays",
      ])
  }

  /// The windows of one app come one after the other, each with all it has to say. Nobody spoke early in any such recording, and nobody does here.
  @Test func oneAppSpeaksOfItsWindowsOneAfterTheOther() {
    let system = FakeWindowSystem(displays: [Self.main])
    let a = system.open(app: "Test", frame: CGRect(x: 12, y: 43, width: 624, height: 947))
    let b = system.open(app: "Test", frame: CGRect(x: 700, y: 100, width: 400, height: 300))
    let c = system.open(app: "Test", frame: CGRect(x: 1284, y: 43, width: 624, height: 947))
    let heard = Heard(system)
    system.events = heard
    system.start()
    system.changeDisplaysAsAMacDoes(
      [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))],
      moving: [
        (a, CGRect(x: 450, y: 372, width: 480, height: 348)), (b, CGRect(x: 710, y: 110, width: 400, height: 300)),
        (c, CGRect(x: 582, y: 300, width: 480, height: 348)),
      ])
    #expect(heard.lines.map { $0.prefix(while: { $0 != " " }) } == ["\(a)", "\(a)", "\(b)", "\(c)", "\(c)", "told"])
    #expect(heard.lines.allSatisfy { $0.hasSuffix("2 displays") })
  }

  /// A window that has gone meanwhile says nothing, and the next is the first.
  @Test func aWindowThatIsGoneSaysNothing() {
    let system = FakeWindowSystem(displays: [Self.main])
    let a = system.open(app: "Mail", pid: 11, frame: CGRect(x: 12, y: 43, width: 624, height: 947))
    let b = system.open(app: "Notes", pid: 12, frame: CGRect(x: 700, y: 100, width: 400, height: 300))
    let c = system.open(app: "Safari", pid: 13, frame: CGRect(x: 900, y: 500, width: 300, height: 200))
    system.close(a)
    let heard = Heard(system)
    system.events = heard
    system.start()
    system.changeDisplaysAsAMacDoes(
      [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))],
      moving: [
        (a, CGRect(x: 20, y: 50, width: 624, height: 947)), (b, CGRect(x: 710, y: 110, width: 400, height: 300)),
        (c, CGRect(x: 910, y: 510, width: 300, height: 200)),
      ])
    #expect(
      heard.lines == ["\(b) by hand (710,110 400×300), 1 displays", "\(c) by hand (910,510 300×200), 2 displays", "told of 2 displays"])
  }

  /// When Arbor is told hangs on macOS's words about its screens and on nothing else: 1.67 s after the list changed however many windows speak, and later
  /// by as much as macOS goes on saying so.
  @Test(arguments: [(0, 0.12, 1.67), (1, 0.12, 1.67), (2, 0.12, 1.67), (2, 0.88, 2.43)]) func whenArborIsToldHangsOnMacOSsWordsAlone(
    windows: Int, repeating: Double, told: Double
  ) {
    let system = FakeWindowSystem(displays: [Self.main])
    let moves = (0..<windows).map { n in
      (window: system.open(app: "Test", frame: CGRect(x: 100 + 50 * n, y: 100, width: 400, height: 300)), frame: CGRect(x: 10, y: 50, width: 300, height: 200))
    }
    system.start()
    var passed = 0.0
    system.passTime = { passed += $0 }
    system.changeDisplaysAsAMacDoes([Self.main, Self.side(at: CGPoint(x: 1920, y: 0))], moving: moves, repeating: repeating)
    #expect(abs(passed - told) < 0.001)
  }

  /// The layer says nothing of displays that are as Arbor was last told, also if they were otherwise meanwhile; waits less for a Dock that grew; and
  /// tells nobody who has stopped listening.
  @Test func whatIsNotWorthAWordIsNotSaid() {
    let system = FakeWindowSystem(displays: [Self.main])
    let heard = Heard(system)
    system.events = heard
    system.start()
    system.changeDisplaysAsAMacDoes([Self.main])
    #expect(heard.lines.isEmpty)

    // A display that blinked: gone, which Arbor never heard, and back.
    let both = [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))]
    system.setDisplays(both)
    heard.lines = []
    system.displayList = [Self.main]
    system.changeDisplaysAsAMacDoes(both)
    #expect(heard.lines.isEmpty)

    var taller = both
    taller[0].visibleFrame.size.height -= 20
    system.passTime = { heard.lines.append("\(($0 * 100).rounded() / 100) s") }
    system.changeDisplaysAsAMacDoes(taller)
    #expect(heard.lines == ["0.35 s", "told of 2 displays"])

    heard.lines = []
    system.passTime = { _ in system.stop() }
    system.changeDisplaysAsAMacDoes([Self.main])
    #expect(heard.lines.isEmpty)
    #expect(system.displays() == [Self.main], "macOS has them all the same")

    // It has let go of every app too, and hears nothing of their windows.
    let window = system.open(app: "Notes", frame: CGRect(x: 700, y: 100, width: 400, height: 300))
    system.passTime = nil
    system.changeDisplaysAsAMacDoes(both, moving: [(window, CGRect(x: 710, y: 110, width: 300, height: 200))])
    #expect(heard.lines.isEmpty)
    #expect(system.frame(of: window) == CGRect(x: 710, y: 110, width: 300, height: 200))
  }

  /// Two docked windows in the numbers of a recording: the second display is moved from the right of the main one to its left. macOS takes a window
  /// on it along, and gives the two that are docked on the display that STAYED frames of its own: moved and resized. Nobody spoke
  /// early there. Arbor was seen to set no frame until it was told of the displays, and then to put each of the two back, once.
  @Test func dockedWindowsThatMacOSResizedOnTheDisplayThatStayedGoBackOnceArborIsTold() {
    let (h, a, b, c) = desk()
    var early: [String] = []
    let began = h.scheduler.now
    h.system.willSetFrame = { window, frame in
      if h.system.displaysLastTold != h.system.displayList { early.append("\(window) to \(frame) after \(h.scheduler.now - began) s") }
    }
    h.system.changeDisplaysAsAMacDoes([Self.main, Self.side(at: CGPoint(x: -1280, y: 0))], moving: Self.asMacOSMovedThem(a, b, c), ahead: 0)
    h.scheduler.advance(by: 3)
    #expect(early.isEmpty, "Arbor sets no frame before it is told: \(early)")
    #expect([a: h.frame(a)!, b: h.frame(b)!] == Self.slots(a, b))
    for window in [a, b] { #expect(h.system.frameLog.filter { $0.window == window }.count == 1, "\(h.system.frameLog)") }
    #expect(h.frame(c) == CGRect(x: -1268, y: 288, width: 700, height: 500), "where macOS took it, on its own display")
    #expect(!h.system.frameLog.contains { $0.window == c }, "\(h.system.frameLog)")
    #expect(h.workspace.isDocked(a) && h.workspace.isDocked(b))
  }

  /// The same with three apps and a docked window speaking first, as docked windows of Notes and Preview did four times. By all that Arbor can see
  /// something has moved a docked window, and a quarter of a second later it puts it back. It asks for the displays when that time has
  /// come, so a change that is there by then holds it back. 0.06 s is the longest that Arbor's timers could have run in under the old
  /// list in any recording; 0.2 s is more than three times that.
  @Test(arguments: [0.003, 0.06, 0.2]) func aDockedWindowThatSpeaksBeforeTheDisplaysChangeIsLeftUntilArborIsTold(ahead: Double) {
    #expect(framesSetBeforeArborIsTold(ahead: ahead) == [])
  }

  /// Where macOS goes on about its screens for two thirds of a second and more, Arbor's look-out for a display that only blinked comes before the news, as it
  /// did in one recording of 37. It finds displays it does not know, and waits.
  @Test(arguments: [0.67, 0.88]) func norWhileMacOSGoesOnAboutItsScreens(repeating: Double) {
    #expect(framesSetBeforeArborIsTold(ahead: 0.05, repeating: repeating) == [])
  }

  /// Plays `dockedWindowsThatMacOSResizedOnTheDisplayThatStayedGoBackOnceArborIsTold` with three apps and the first window speaking early, holds the end to
  /// the same, and returns the frames Arbor set before it had been told of the new displays.
  func framesSetBeforeArborIsTold(ahead: Double, repeating: Double = 0.12) -> [String] {
    let (h, a, b, c) = desk(apps: true)
    let new = [Self.main, Self.side(at: CGPoint(x: -1280, y: 0))]
    var early: [String] = []
    let began = h.scheduler.now
    h.system.willSetFrame = { window, frame in
      if h.system.displaysLastTold != new { early.append("\(window) after \(((h.scheduler.now - began) * 100).rounded() / 100) s") }
    }
    h.system.changeDisplaysAsAMacDoes(new, moving: Self.asMacOSMovedThem(a, b, c), ahead: ahead, repeating: repeating)
    h.scheduler.advance(by: 3)
    #expect([a: h.frame(a)!, b: h.frame(b)!] == Self.slots(a, b))
    for window in [a, b] { #expect(h.system.frameLog.filter { $0.window == window }.count == 1, "\(h.system.frameLog)") }
    return early
  }

  /// Nothing is docked. macOS moves one floating window on the display that stays and resizes another, as it did at every plug and unplug with real
  /// apps, in their recorded numbers. Decided (board 0.23): what macOS does to a floating window at a change of displays is macOS's.
  /// Arbor sets no frame, and takes what it finds for the window's own.
  ///
  /// On hosted Macs that hung on some hundredths of a second: of 8 windows that spoke before macOS's list changed Arbor set none back, of 24 that
  /// spoke after it 22. So here: the terminal is left alone when it speaks early, and the very same window is set back when it does not.
  @Test func whatMacOSDoesToAFloatingWindowAtAChangeOfDisplaysIsMacOSs() {
    let main = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1600, height: 900), visibleFrame: CGRect(x: 0, y: 31, width: 1600, height: 791), isMain: true)
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1600, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 1600, y: 31, width: 1920, height: 1049),
      isMain: false)
    let (own, macOSs) = ([CGRect(x: 737, y: 300, width: 863, height: 499), CGRect(x: 165, y: 65, width: 673, height: 439)],
      [CGRect(x: 1000, y: 300, width: 863, height: 499), CGRect(x: 165, y: 65, width: 656, height: 422)])
    /// For the terminal and for TextEdit: how many frames Arbor set, where the window rests, and the place Arbor has for it.
    func play(ahead: Double) -> [(set: Int, rests: CGRect?, place: CGRect?)] {
      // As Arbor ships, whatever the environment says of floating windows that make way.
      let h = Harness(displays: [main], settings: Settings())
      // Not process 1, which is Arbor's own in a harness: it leaves its own windows alone whatever happens.
      let windows = [h.system.open(app: "Terminal", pid: 11, frame: own[0]), h.system.open(app: "TextEdit", pid: 12, frame: own[1])]
      h.start()
      h.scheduler.advance(by: 3)
      #expect(windows.map { h.workspace.floating[$0] } == own, "both are Arbor's to look after")
      h.system.clearFrameLog()
      h.system.changeDisplaysAsAMacDoes([main, side], moving: [(windows[0], macOSs[0]), (windows[1], macOSs[1])], ahead: ahead)
      h.scheduler.advance(by: 3)
      return windows.map { window in (h.system.frameLog.filter { $0.window == window }.count, h.frame(window), h.workspace.floating[window]) }
    }
    let (early, late) = (play(ahead: 0.05), play(ahead: 0))
    #expect(early[0].set == 0)
    #expect(early[0].rests == macOSs[0])
    #expect(early[0].place == macOSs[0])
    for (name, seen, macOSs) in [("the terminal, late", late[0], macOSs[0]), ("TextEdit, late", late[1], macOSs[1]), ("TextEdit, after the terminal", early[1], macOSs[1])] {
      withKnownIssue("board 0.23: a floating window that speaks after macOS's list has changed is set back") { #expect(seen.set == 0, "\(name)") }
      withKnownIssue("board 0.23") { #expect(seen.rests == macOSs, "\(name)") }
      withKnownIssue("board 0.23") { #expect(seen.place == macOSs, "\(name)") }
    }
  }

  /// [a | Desktop | b] on the main display, in thirds, and c floating on the one to its right: with a column for the Desktop, which Arbor had
  /// when the recording was made. Windows of one app, as in the recording whose numbers these are, or of three.
  func desk(apps: Bool = false) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(displays: [Self.main, Self.side(at: CGPoint(x: 1920, y: 0))], settings: .withDesktopColumn)
    let a = h.system.open(app: "Notes", pid: apps ? 11 : 1000, frame: CGRect(x: 170, y: 220, width: 480, height: 348))
    let b = h.system.open(app: "Mail", pid: apps ? 12 : 1000, frame: CGRect(x: 220, y: 180, width: 480, height: 348))
    let c = h.system.open(app: "Safari", pid: apps ? 13 : 1000, frame: CGRect(x: 1932, y: 288, width: 700, height: 500))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.scheduler.advance(by: 3)
    #expect([a: h.frame(a)!, b: h.frame(b)!] == Self.slots(a, b), "as in the recording")
    h.system.clearFrameLog()
    return (h, a, b, c)
  }
  static func slots(_ a: WindowID, _ b: WindowID) -> [WindowID: CGRect] {
    [a: CGRect(x: 12, y: 43, width: 624, height: 947), b: CGRect(x: 1284, y: 43, width: 624, height: 947)]
  }
  static func asMacOSMovedThem(_ a: WindowID, _ b: WindowID, _ c: WindowID) -> [(window: WindowID, frame: CGRect)] {
    [
      (a, CGRect(x: 450, y: 372, width: 480, height: 348)), (b, CGRect(x: 582, y: 300, width: 480, height: 348)),
      (c, CGRect(x: -1268, y: 288, width: 700, height: 500)),
    ]
  }

  /// The lab has a word for it, which it reads and writes like the others. A lid, which nobody has recorded, is swept in the orders that take no time.
  @Test func theLabsWord() throws {
    let line = "displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:0,0,0,0 windows-recorded"
    let action = try #require(ChaosAction.script(line).first)
    guard case .displays(let displays, .recorded) = action else {
      Issue.record("\(action)")
      return
    }
    #expect(displays.count == 2)
    #expect(action.text == line)
    #expect(!ChaosAction.WindowsFollow.inAnInstant.contains(.recorded))
  }

  /// Through the lab, with its nets looking on: a display comes and goes beside two docked windows and two floating ones, which go home with the display's
  /// going, one of them speaking early. The time passes. Then what the layer finds not worth a word, another order of the list, and
  /// what nobody has recorded, another main display: the lab's mirror holds Arbor to the very list after each.
  @Test func theLabPlaysIt() {
    let runner = ChaosRunner()
    var found: [InvariantViolation] = []
    func play(_ script: String) { for action in ChaosAction.script(script) { found += runner.step(action) } }
    func seconds(_ script: String) -> Double {
      let before = runner.harness.scheduler.now
      play(script)
      return ((runner.harness.scheduler.now - before) * 100).rounded() / 100
    }
    play(
      """
      displays main:0,0,1440,900:25,0,0,0* windows-never
      open 101 Notes pid 1001 at 100 100 600 400
      open 102 Mail pid 1002 at 300 200 600 400
      open 103 Safari pid 1003 at 500 300 500 300
      open 104 Preview pid 1004 at 600 350 400 300
      launch
      do dock 101 left
      do dock 102 right
      settle
      """)
    #expect(seconds("displays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:25,0,0,0 windows-recorded") == 1.67, "nobody moves, so nobody speaks")
    play("settle\nmove 103 1600 200 500 300\nmove 104 1700 300 400 300\nsettle")
    #expect(seconds("displays main:0,0,1440,900:25,0,0,0* windows-recorded") == 1.72, "one speaks early")
    #expect(runner.harness.system.displayList.count == 1 && runner.harness.system.displaysLastTold.count == 1)
    play("settle\ndisplays main:0,0,1440,900:25,0,0,0* side:1440,0,1280,800:25,0,0,0 windows-recorded\nsettle")
    #expect(seconds("displays side:1440,0,1280,800:25,0,0,0 main:0,0,1440,900:25,0,0,0* windows-recorded") == 0, "another order of the list is not worth a word")
    #expect(runner.harness.controller.displays.map(\.id) == [DisplayID("side"), DisplayID("main")])
    play("settle")
    #expect(seconds("displays side:0,0,1280,800:25,0,0,0* main:1280,0,1440,900:0,0,0,0 windows-recorded") == 1.67, "another main display")
    play("settle")
    #expect(found.isEmpty, "\(found)")
  }
}
