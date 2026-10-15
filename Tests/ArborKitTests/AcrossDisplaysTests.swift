import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// From a small display to a large one. Right after a position call has taken a window across, macOS judges a size call by the display the
/// window came from (`FakeWindowSystem.Echoes.theDisplayItCameFromJudgesForAMoment`): asked to be 947 high, it stops at the foot of the small
/// display. That is the screen's answer and not the window's. It is never written down and never taken for a refusal, the window is
/// not centred meanwhile, and it is asked once more when macOS has caught up: whole within about a second, in one further change.
@Suite @MainActor struct AcrossDisplaysTests {
  static let small = DisplaySnapshot(
    id: DisplayID("small"), frame: CGRect(x: 0, y: 0, width: 1280, height: 720),
    visibleFrame: CGRect(x: 0, y: 31, width: 1280, height: 689), isMain: true)
  static let large = DisplaySnapshot(
    id: DisplayID("large"), frame: CGRect(x: 1280, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1280, y: 31, width: 1920, height: 1049), isMain: false)

  /// Small: `[a | Desktop | b]`. Large: `[Desktop | c]`.
  func desk(small: DisplaySnapshot = small, large: DisplaySnapshot = large) -> (h: Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness(displays: [small, large])
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 500, height: 400))
    let c = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 1600, y: large.visibleFrame.minY + 70, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) right", "dock \(c.rawValue) right"] { h.run(command) }
    h.scheduler.advance(by: 3)
    return (h, a, b, c)
  }

  func slot(_ window: WindowID, _ h: Harness) -> CGRect? { h.controller.layouts[Self.large.id]?.windowFrames[window] }

  /// What N's judge asks of every road: it fills its place after three seconds and ten seconds later, nothing is written down of where it
  /// stopped, and from the journey on it has changed once more to the eye, not twice, and was never centred in its slot.
  func expectItEndsWhole(_ window: WindowID, _ h: Harness, since mark: Int, _ road: String) {
    h.scheduler.advance(by: 3)
    #expect(slot(window, h) != nil && h.frame(window) == slot(window, h), "\(road): after 3 s: \(String(describing: h.frame(window)))")
    h.scheduler.advance(by: 10)
    #expect(h.frame(window) == slot(window, h), "\(road): after 10 s more")
    #expect(h.controller.seenSizes[window]?.stoppedAt ?? .zero == .zero, "\(road): \(String(describing: h.controller.seenSizes[window]))")
    #expect(h.controller.misfits[window] == nil, "\(road)")
    let changes = h.system.moveLog[mark...].filter { $0.window == window && $0.before != $0.after }
    #expect(changes.count <= 2, "\(road): the journey and one more: \(changes.map(\.after))")
    if let slot = slot(window, h) {
      #expect(changes.allSatisfy { $0.after.origin == slot.origin }, "\(road): never anywhere but at its slot's corner: \(changes.map(\.after))")
    }
  }

  @Test func sentToTheLargeDisplayByCommandADockedWindowFillsItsSlot() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    let mark = h.system.moveLog.count
    #expect(h.run("move-to-display next").ok)
    #expect(h.frame(b)!.height < 700, "or this proves nothing: the first answer is the small display's")
    expectItEndsWhole(b, h, since: mark, "move-to-display")
    expectWindowsMatchLayout(h, on: Self.large.id)
  }

  /// Whole within about a second.
  @Test func itIsWholeWithinASecond() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    h.scheduler.advance(by: 1.1)
    #expect(h.frame(b) == slot(b, h))
  }

  /// An ordinary drop on the large display, near the border, with the larger part of the window still on the small one.
  @Test(arguments: [false, true]) func letGoNearTheBorderWithItsLargerPartStillOnTheSmallDisplay(docked: Bool) {
    let (h, a, _, c) = desk()
    // Large: `[c | Desktop]`, so that there is a window to dock beside, next to the border.
    h.run("dock \(c.rawValue) left")
    if !docked { h.run("float \(a.rawValue)") }
    h.scheduler.advance(by: 3)
    h.system.beginDrag(a)
    h.system.moveDrag(to: CGPoint(x: 900, y: 300), holding: 0.3)
    h.system.moveDrag(to: CGPoint(x: slot(c, h)!.minX + 30, y: 500), holding: 0.5)
    // Held at the right of its title bar, so that most of it hangs back over the small display. (The stand-in's hand holds the middle.)
    h.system.userMove(a, to: h.frame(a)!.offsetBy(dx: 20 - h.frame(a)!.width / 2, dy: 0))
    #expect(h.frame(a)!.midX < Self.large.frame.minX, "or this proves nothing: \(h.frame(a)!)")
    let mark = h.system.moveLog.count
    h.system.endDrag()
    guard h.controller.workspaces[Self.large.id]?.isDocked(a) == true else {
      Issue.record("it did not dock on the large display: \(h.ascii())")
      return
    }
    #expect(h.frame(a)!.height < 700, "or this proves nothing: it was cut: \(h.frame(a)!)")
    expectItEndsWhole(a, h, since: mark, "a drop")
  }

  /// The large display goes and comes back: its windows were carried to the small one meanwhile.
  @Test func whenTheLargeDisplayComesBackItsWindowsFillTheirSlots() {
    let (h, _, _, c) = desk()
    let was = h.frame(c)!
    h.system.unplug(Self.large.id)
    h.scheduler.advance(by: 5)
    #expect(Self.small.frame.contains(h.frame(c)!.origin) && h.frame(c)!.height < was.height, "or this proves nothing: \(h.frame(c)!)")
    h.system.plug(Self.large)
    h.scheduler.advance(by: 3)
    #expect(h.frame(c) == was, "\(String(describing: h.frame(c)))")
    h.scheduler.advance(by: 10)
    #expect(h.frame(c) == was)
    #expect(h.controller.seenSizes[c]?.stoppedAt ?? .zero == .zero && h.controller.misfits[c] == nil)
  }

  /// An app, or macOS, takes a docked window of the large display to the small one. Arbor puts it back, which is a journey across.
  @Test func takenAcrossBySomebodyElseAndPutBackItFillsItsSlot() {
    let (h, _, _, c) = desk()
    h.system.userMove(c, to: CGRect(x: 200, y: 100, width: 500, height: 400))
    let mark = h.system.moveLog.count
    expectItEndsWhole(c, h, since: mark, "put back")
  }

  /// A start: docked on the large display by what was saved, and standing on the small one.
  @Test func atAStartAWindowThatStandsOnTheSmallDisplayFillsItsSlotOnTheLargeOne() {
    let (first, _, _, c) = desk()
    let was = first.frame(c)!
    first.controller.saveNow()
    first.controller.shutdown()
    first.system.userMove(c, to: CGRect(x: 200, y: 100, width: 500, height: 400))
    let h = first.newProcess()
    h.start()
    guard h.controller.workspaces[Self.large.id]?.isDocked(c) == true else {
      Issue.record("it is not docked on the large display after the start: \(h.ascii())")
      return
    }
    h.scheduler.advance(by: 3)
    #expect(h.frame(c) == was, "\(String(describing: h.frame(c)))")
    #expect(h.controller.seenSizes[c]?.stoppedAt ?? .zero == .zero && h.controller.misfits[c] == nil)
  }

  /// Arbor's call only moves it across, at the size it has, and the next layout, within the same moment, asks it to grow. It stands on
  /// the large display by then.
  @Test func onlyMovedAcrossAndAskedToGrowByTheNextLayout() {
    let (h, _, b, c) = desk()
    // As high as the small display's slots, so that the journey changes no height; then Mail goes, and Notes has the display to itself.
    h.system.userFocus(b)
    let mark = h.system.moveLog.count
    h.run("move-to-display next")
    h.run("float \(c.rawValue)")
    #expect(h.frame(b)!.height < 700, "or this proves nothing")
    h.scheduler.advance(by: 3)
    #expect(h.frame(b) == slot(b, h), "\(String(describing: h.frame(b)))")
    #expect(h.controller.seenSizes[b]?.stoppedAt ?? .zero == .zero && h.controller.misfits[b] == nil)
    #expect(h.system.moveLog[mark...].filter { $0.window == b }.allSatisfy { $0.after.minY == slot(b, h)!.minY }, "never centred")
  }

  /// Fresh from another display it goes out of view, and is asked there how large it can be, as whoever waits out of view is. It is still
  /// judged by the display it came from, wherever it stands: with that one to the right, from the corner at 1439 it grew as far as 2720,
  /// the other display's right edge. 1281 wide was taken for all it can be, and it was centred in a slot of 1416. (A storm found it.)
  @Test func askedWhereItWaitsOutOfViewNothingIsMadeOfTheAnswerEither() {
    let left = DisplaySnapshot(
      id: DisplayID("left"), frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
      visibleFrame: CGRect(x: 0, y: 25, width: 1440, height: 875), isMain: true)
    let right = DisplaySnapshot(
      id: DisplayID("right"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [left, right])
    let a = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 500, height: 400))
    let b = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    for command in ["dock \(a.rawValue) left", "dock \(b.rawValue) left"] { h.run(command) }
    h.scheduler.advance(by: 3)
    h.system.userFocus(b)
    // All within the moment: across, out of view behind Safari, and back into a view of its own.
    #expect(h.run("move-to-display next").ok && h.controller.workspaces[left.id]?.isDocked(b) == true)
    h.run("zoom \(a.rawValue)")
    #expect(h.controller.parked.contains(b), "or this proves nothing")
    let mark = h.system.moveLog.count
    h.run("zoom \(b.rawValue)")
    #expect(h.system.moveLog[mark...].contains { $0.window == b && $0.after.width < $0.requested.width - 2 }, "or this proves nothing: it was cut")
    h.scheduler.advance(by: 3)
    let slot = h.controller.layouts[left.id]?.windowFrames[b]
    #expect(slot != nil && h.frame(b) == slot, "\(String(describing: h.frame(b))) in \(String(describing: slot))")
    #expect(h.controller.seenSizes[b]?.stoppedAt ?? .zero == .zero, "\(String(describing: h.controller.seenSizes[b]))")
    #expect(h.controller.misfits[b] == nil)
  }

  // MARK: Its own size

  /// Larger than the small display has room for.
  static let own = CGRect(x: 1500, y: 80, width: 700, height: 850)

  /// Mail, with a size of its own, docked on the large display and sent to the small one.
  func aLargeWindowDockedOnTheSmallDisplay() -> (h: Harness, c: WindowID) {
    let (h, _, _, c) = desk()
    h.run("float \(c.rawValue)")
    h.system.userMove(c, to: Self.own)
    h.scheduler.advance(by: 2)
    h.run("dock \(c.rawValue) right")
    h.system.userFocus(c)
    h.run("move-to-display next")
    h.scheduler.advance(by: 3)
    #expect(h.controller.workspaces[Self.small.id]?.isDocked(c) == true)
    return (h, c)
  }

  /// Let go of right after a journey, it has a moment later what it would have had, had it been let go of a moment later: size and place.
  @Test func floatedRightAfterAJourneyItHasItsOwnFrame() {
    func play(waiting: Double) -> (h: Harness, c: WindowID) {
      let (h, c) = aLargeWindowDockedOnTheSmallDisplay()
      h.run("move-to-display next")
      h.scheduler.advance(by: waiting)
      h.run("float-all")
      return (h, c)
    }
    let (twin, _) = play(waiting: 3)
    let (h, c) = play(waiting: 0)
    #expect(twin.frame(c)?.size == Self.own.size, "the twin: \(String(describing: twin.frame(c)))")
    #expect(h.frame(c)!.height < Self.own.height - 2, "or this proves nothing: it was cut")
    #expect(h.controller.workspaces[Self.large.id]?.floating[c]?.size == Self.own.size, "what is written down, at once")
    h.scheduler.advance(by: 1.1)
    #expect(h.frame(c) == twin.frame(c), "\(String(describing: h.frame(c))), the twin \(String(describing: twin.frame(c)))")
  }

  /// Let go of right after a journey, and the view goes elsewhere within the same moment. It stays, since no view takes a floating window out of view,
  /// and the size another display has made of it for the moment is not written down.
  @Test func withTheViewElsewhereWithinTheMomentTheShortSizeIsNotWrittenDown() {
    let (h, c) = aLargeWindowDockedOnTheSmallDisplay()
    let other = h.system.open(app: "Notes 2", pid: 14, frame: CGRect(x: 2400, y: 200, width: 500, height: 400))
    h.run("dock \(other.rawValue) right")
    h.scheduler.advance(by: 3)
    h.system.userFocus(c)
    h.run("move-to-display next")
    h.run("float-all")
    #expect(h.frame(c)!.height < Self.own.height - 2, "or this proves nothing: it was cut: \(h.frame(c)!)")
    h.run("dock \(other.rawValue) right")
    h.run("zoom \(other.rawValue)")
    #expect(h.controller.parked.contains(c) == h.floatingWindowsLeaveWithTheDesktop)
    #expect(h.controller.workspaces[Self.large.id]?.floating[c]?.size == Self.own.size, "\(String(describing: h.controller.workspaces[Self.large.id]?.floating[c]))")
    h.scheduler.advance(by: 5)
    h.run("show-all")
    h.scheduler.advance(by: 3)
    #expect(h.frame(c)?.size == Self.own.size, "\(String(describing: h.frame(c)))")
  }

  /// Into a frame that hangs over the bottom a window is sized where the size fits and then only moved (Controller+TheScreensAnswer.swift). Across
  /// displays it is cut where it was sized, and ends on no line where it ends up.
  @Test func sizedOnTheWayAndCutThereWhatIsWrittenDownIsStillWhatWasAsked() {
    let (h, _, _, c) = desk()
    h.run("float \(c.rawValue)")
    h.system.userMove(c, to: CGRect(x: 100, y: 43, width: 700, height: 330))
    h.scheduler.advance(by: 3)
    let wanted = CGRect(x: 1500, y: 400, width: 700, height: 850)
    let given = h.controller.give(wanted, to: c)
    #expect(given != nil && given!.frame.height < 848 && given!.frame.minY == 400, "or this proves nothing: cut, and moved on: \(String(describing: given))")
    #expect(given?.own.size == wanted.size, "\(String(describing: given))")
    h.scheduler.advance(by: 1.1)
    #expect(h.frame(c) == wanted, "\(String(describing: h.frame(c)))")
  }

  /// A size written down is lost for good. Dragged out of its slot on the small display and let go on the large one, near the border, with its
  /// larger part still over the small one, it takes its own size there: what is written down is what was asked for, at once.
  @Test func draggedOutOfItsSlotAndLetGoOverTheBorderWhatIsWrittenDownIsItsOwnSize() {
    let (h, c) = aLargeWindowDockedOnTheSmallDisplay()
    h.system.beginDrag(c)
    h.system.moveDrag(to: CGPoint(x: 900, y: 200), holding: 0.3)
    // On the Desktop of the large display, where a drop floats.
    h.system.moveDrag(to: CGPoint(x: Self.large.frame.minX + 60, y: 60), holding: 0.5)
    h.system.userMove(c, to: h.frame(c)!.offsetBy(dx: 20 - h.frame(c)!.width / 2, dy: 0))
    #expect(h.frame(c)!.midX < Self.large.frame.minX, "or this proves nothing: \(h.frame(c)!)")
    h.system.endDrag()
    guard let home = h.controller.workspaces.first(where: { $0.value.isFloating(c) }) else {
      Issue.record("it does not float: \(h.ascii())")
      return
    }
    #expect(h.frame(c)!.height < Self.own.height - 2, "or this proves nothing: it was cut: \(h.frame(c)!)")
    #expect(home.value.floating[c]?.size == Self.own.size, "what is written down, at once: \(String(describing: home.value.floating[c]))")
    h.scheduler.advance(by: 1.1)
    #expect(h.frame(c)?.size == Self.own.size, "\(String(describing: h.frame(c)))")
    h.scheduler.advance(by: 10)
    h.run("dock \(c.rawValue) left")
    h.scheduler.advance(by: 3)
    h.run("float \(c.rawValue)")
    h.scheduler.advance(by: 3)
    #expect(h.frame(c)?.size == Self.own.size, "long after: \(String(describing: h.frame(c)))")
  }

  /// Floated on the small display, where it does not fit, and sent across floating: position and size in one request. With the large
  /// display 200 points higher than the small one, so that the window's foot is still above the small display's as it arrives.
  @Test func sentAcrossFloatingItHasItsOwnSize() {
    let higher = DisplaySnapshot(
      id: Self.large.id, frame: Self.large.frame.offsetBy(dx: 0, dy: -200), visibleFrame: Self.large.visibleFrame.offsetBy(dx: 0, dy: -200),
      isMain: false)
    let (h, _, _, c) = desk(large: higher)
    h.run("float \(c.rawValue)")
    h.system.userMove(c, to: Self.own.offsetBy(dx: 0, dy: -200))
    h.scheduler.advance(by: 2)
    h.system.userFocus(c)
    h.run("move-to-display next")
    h.scheduler.advance(by: 3)
    #expect(Self.small.frame.contains(h.frame(c)!.origin) && h.frame(c)!.height < Self.own.height - 2, "or this proves nothing: \(h.frame(c)!)")
    h.run("move-to-display next")
    #expect(h.frame(c)!.height < Self.own.height - 2, "or this proves nothing: it was cut: \(h.frame(c)!)")
    h.scheduler.advance(by: 1.1)
    // (To a point: it is put in the middle of the Desktop, on whole points.)
    #expect(abs(h.frame(c)!.height - Self.own.height) <= 1 && h.frame(c)!.width == Self.own.width, "\(String(describing: h.frame(c)))")
    #expect(h.controller.workspaces[higher.id]?.floating[c]?.size == h.frame(c)?.size)
  }

  /// Whoever has moved or sized it meanwhile has had the last word.
  @Test func aHandThatTakesItMeanwhileHasTheLastWord() {
    let (h, c) = aLargeWindowDockedOnTheSmallDisplay()
    h.run("move-to-display next")
    h.run("float-all")
    let theirs = CGRect(x: 1600, y: 200, width: 500, height: 300)
    h.system.userMove(c, to: theirs)
    h.scheduler.advance(by: 5)
    #expect(h.frame(c) == theirs)
    #expect(h.controller.windowsToBeAskedAgain.isEmpty)
  }

  // MARK: The net that lets it be short for a moment

  /// A window that is due to be asked again may be short at its slot's corner, until it has been asked. Short and anywhere else, or short
  /// afterwards, the net has it.
  @Test func theNetLetsItBeShortOnlyAtItsSlotsCornerAndOnlyUntilItHasBeenAsked() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    #expect(h.frame(b)!.height < 700 && h.layoutProblems(on: Self.large.id).isEmpty, "\(h.layoutProblems(on: Self.large.id))")
    // Centred, as it used to be.
    let short = h.frame(b)!
    h.system.moveSilently(b, to: short.offsetBy(dx: 0, dy: 170))
    #expect(!h.layoutProblems(on: Self.large.id).isEmpty)
    h.system.moveSilently(b, to: short)
    #expect(h.layoutProblems(on: Self.large.id).isEmpty)
    // Short, at the corner, and nobody is going to ask: the time is not running.
    h.scheduler.cancel("across-\(Self.large.id.rawValue)")
    h.controller.displaysToAskAgain.removeAll()
    #expect(!h.layoutProblems(on: Self.large.id).isEmpty)
  }

  /// By chance a window cannot grow beyond the very line of the other display. It is asked twice more within a second, and what it says then is
  /// its own answer: it is centred like anybody who will not grow, that is on record, and no layout asks it again.
  @Test func oneThatReallyStopsOnThatVeryLineIsBelievedAfterASecond() {
    let (h, _, b, c) = desk()
    h.system.userFocus(b)
    h.system.setMaximumSize(b, CGSize(width: 3000, height: 677))
    h.run("move-to-display next")
    let slot = slot(b, h)!
    #expect(h.frame(b)!.origin == slot.origin && h.controller.windowsToBeAskedAgain == [b], "or this proves nothing: \(h.frame(b)!)")
    h.scheduler.advance(by: 1.1)
    #expect(h.frame(b)!.height == 677 && abs(h.frame(b)!.midY - slot.midY) <= 1, "\(h.frame(b)!) in \(slot)")
    #expect(h.controller.misfits[b] != nil && h.controller.journeys.isEmpty && h.controller.windowsToBeAskedAgain.isEmpty)
    let asked = h.system.moveLog.count
    h.scheduler.advance(by: 30)
    h.system.userFocus(c)
    h.system.userFocus(b)
    h.scheduler.advance(by: 5)
    #expect(h.system.moveLog[asked...].allSatisfy { $0.window != b }, "nobody is asked for ever: \(h.system.moveLog[asked...].map(\.requested))")
  }

  /// The small display has a Dock, and the large one begins 50 points lower. Fresh from the small one the window's foot is in the strip of that
  /// Dock, where a window keeps the height it has: it ends on no line at all.
  @Test func heldInTheStripOfTheOtherDisplaysDockItIsAskedAgainToo() {
    let withADock = DisplaySnapshot(id: Self.small.id, frame: Self.small.frame, visibleFrame: CGRect(x: 0, y: 31, width: 1280, height: 619), isMain: true)
    let lower = DisplaySnapshot(
      id: Self.large.id, frame: Self.large.frame.offsetBy(dx: 0, dy: 50), visibleFrame: Self.large.visibleFrame.offsetBy(dx: 0, dy: 50), isMain: false)
    let (h, _, b, _) = desk(small: withADock, large: lower)
    h.system.userFocus(b)
    let mark = h.system.moveLog.count
    h.run("move-to-display next")
    let foot = h.frame(b)!.maxY
    #expect(foot > 654 && foot < 716 && h.frame(b)!.height < 700, "or this proves nothing: in the strip, on no line: \(h.frame(b)!)")
    expectItEndsWhole(b, h, since: mark, "the strip")
  }

  /// Not under a hand: while the mouse button is down nothing is laid out, like any put-back. It is asked when the button is up.
  @Test func whileTheMouseButtonIsDownNobodyIsAsked() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    let short = h.frame(b)!
    h.system.mouseDown = true
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: 3)
    #expect(h.frame(b) == short && h.system.moveLog.count == mark, "\(h.system.moveLog[mark...].map(\.requested))")
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.5)
    #expect(h.frame(b) == slot(b, h))
    // However long it is held: held for twelve seconds, the window used to be given up on, and lay short until it next went out of view.
    h.system.userFocus(b)
    h.run("move-to-display next")
    h.scheduler.advance(by: 3)
    h.run("move-to-display next")
    h.system.mouseDown = true
    h.scheduler.advance(by: 60)
    #expect(h.frame(b)!.height < 700, "or this proves nothing")
    h.system.mouseDown = false
    h.scheduler.advance(by: 0.5)
    #expect(h.frame(b) == slot(b, h), "\(String(describing: h.frame(b)))")
  }

  /// Nor by displays that may be gone: while macOS's list of displays is not the one Arbor knows, nobody is asked. That is not waited for for ever:
  /// the report of the displays lays everything out anyway.
  @Test func whileTheDisplaysAreInDoubtNobodyIsAskedAndThatIsNotWaitedForForEver() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    let short = h.frame(b)!
    // macOS has moved the large display, and has not said so yet.
    h.system.displayList[1] = DisplaySnapshot(
      id: Self.large.id, frame: Self.large.frame.offsetBy(dx: 0, dy: 40), visibleFrame: Self.large.visibleFrame.offsetBy(dx: 0, dy: 40), isMain: false)
    let mark = h.system.moveLog.count
    h.scheduler.advance(by: 3)
    #expect(h.frame(b) == short && h.system.moveLog.count == mark, "\(h.system.moveLog[mark...].map(\.requested))")
    #expect(h.scheduler.pendingKeys.contains { $0.hasPrefix("across-") })
    h.scheduler.advance(by: 60)
    #expect(!h.scheduler.pendingKeys.contains { $0.hasPrefix("across-") } && h.controller.journeys.isEmpty, "\(h.scheduler.pendingKeys)")
  }

  /// All that Macs have said is that the old display judged no more after 200 ms. Should one take 300, the window does not stand short for a whole
  /// second: it is asked at a quarter, at half a second and at a second.
  @Test(arguments: [(0.3, 0.55), (0.45, 0.55), (0.9, 1.05)]) func aSlowerMacIsAskedAtHalfASecondToo(takes: Double, wholeBy: Double) {
    let (h, _, b, _) = desk()
    h.system.timeToCatchUp = takes
    h.system.userFocus(b)
    let mark = h.system.moveLog.count
    h.run("move-to-display next")
    h.scheduler.advance(by: 0.3)
    #expect(h.frame(b)!.height < 700, "or this proves nothing: still short after the first asking")
    h.scheduler.advance(by: wholeBy - 0.3)
    #expect(h.frame(b) == slot(b, h), "\(String(describing: h.frame(b)))")
    #expect(h.controller.seenSizes[b]?.stoppedAt ?? .zero == .zero && h.controller.misfits[b] == nil)
    #expect(h.system.moveLog[mark...].filter { $0.window == b }.allSatisfy { $0.after.origin == slot(b, h)!.origin }, "never centred")
  }

  /// How often Arbor turns to `window` while `body` runs, whether its app answers or not.
  func attempts(on window: WindowID, _ h: Harness, while body: () -> Void) -> Int {
    var count = 0
    h.system.willSetFrame = { asked, _ in if asked == window { count += 1 } }
    body()
    h.system.willSetFrame = nil
    return count
  }

  /// An asking that gets no answer ends the series: every call to an app that hangs holds the main thread for as long as the layer waits.
  @Test func anAskingThatGetsNoAnswerEndsTheSeries() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    #expect(h.controller.windowsToBeAskedAgain == [b], "or this proves nothing")
    h.system.setUnresponsive(pid: 12, true)
    #expect(attempts(on: b, h) { h.scheduler.advance(by: 5) } == 1)
    #expect(h.controller.journeys.isEmpty && !h.scheduler.pendingKeys.contains { $0.hasPrefix("across-") })
  }

  /// Also while somebody else's journey keeps the time of that display running.
  @Test func norIsItAskedAgainForSomebodyElsesSake() {
    let (h, a, b, _) = desk()
    // Safari never grows beyond the very line, so it is asked all three times.
    h.system.setMaximumSize(a, CGSize(width: 3000, height: 677))
    for window in [a, b] {
      h.system.userFocus(window)
      h.run("move-to-display next")
    }
    #expect(h.controller.windowsToBeAskedAgain == [a, b], "or this proves nothing: \(h.controller.windowsToBeAskedAgain)")
    h.system.setUnresponsive(pid: 12, true)
    var (ofTheHung, ofTheOther) = (0, 0)
    h.system.willSetFrame = { asked, _ in
      if asked == b { ofTheHung += 1 }
      if asked == a { ofTheOther += 1 }
    }
    h.scheduler.advance(by: 1.2)
    h.system.willSetFrame = nil
    #expect(ofTheOther >= 3, "or this proves nothing: the time went on running: \(ofTheOther)")
    #expect(ofTheHung == 1, "\(ofTheHung)")
  }

  /// The same for a window that is not docked.
  @Test func norIsAWindowThatFloats() {
    let (h, a, _, c) = desk()
    h.run("float \(c.rawValue)")
    h.system.userMove(c, to: CGRect(x: 100, y: 43, width: 700, height: 330))
    h.scheduler.advance(by: 3)
    h.system.setMaximumSize(a, CGSize(width: 3000, height: 677))
    h.system.userFocus(a)
    h.run("move-to-display next")
    let given = h.controller.give(CGRect(x: 1500, y: 43, width: 700, height: 850), to: c)
    #expect(given != nil && given!.frame.height < 848 && h.controller.windowsToBeAskedAgain == [a, c], "or this proves nothing: \(String(describing: given))")
    h.system.setUnresponsive(pid: 13, true)
    #expect(attempts(on: c, h) { h.scheduler.advance(by: 1.2) } == 1)
  }

  // MARK: What it must not become

  /// A window that truly cannot grow, and stops short of every line, is believed at once: centred in its slot as ever. (A control: none of this
  /// is for it.)
  @Test func aWindowThatReallyCannotGrowIsCentredInTheEnd() {
    let (h, _, b, _) = desk()
    h.system.setMaximumSize(b, CGSize(width: 2000, height: 600))
    h.system.userFocus(b)
    h.run("move-to-display next")
    #expect(h.controller.journeys.isEmpty && abs(h.frame(b)!.midY - slot(b, h)!.midY) <= 1, "at once: \(h.frame(b)!)")
    h.scheduler.advance(by: 5)
    let slot = slot(b, h)!
    #expect(h.frame(b)!.height == 600 && abs(h.frame(b)!.midY - slot.midY) <= 1, "\(String(describing: h.frame(b)))")
    let asked = h.system.moveLog.count
    h.scheduler.advance(by: 30)
    #expect(h.system.moveLog.count == asked, "nobody is asked for ever")
  }

  /// The other way, and within one display, nothing waits and nothing is asked twice.
  @Test func fromTheLargeDisplayToTheSmallOneIsOneMove() {
    let (h, _, _, c) = desk()
    h.system.userFocus(c)
    h.beginStep()
    #expect(h.run("move-to-display next").ok)
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("across") }, "\(h.scheduler.pendingKeys)")
    h.scheduler.advance(by: 5)
    // (It is asked to be smaller where it stands, which is a question and no move.)
    #expect(h.movesInStep[c] == 1 && h.jolts.isEmpty, "\(h.movesInStep) \(h.jolts)")
    #expect(h.frame(c) == h.controller.layouts[Self.small.id]?.windowFrames[c])
  }

  /// A window that closes, or goes elsewhere, before it is asked again leaves nothing behind.
  @Test func nothingIsLeftWaitingForAWindowThatHasGone() {
    let (h, _, b, _) = desk()
    h.system.userFocus(b)
    h.run("move-to-display next")
    h.system.close(b)
    h.scheduler.advance(by: 5)
    #expect(!h.scheduler.pendingKeys.contains { $0.contains("across") }, "\(h.scheduler.pendingKeys)")
    #expect(h.controller.invariantViolations().isEmpty, "\(h.controller.invariantViolations())")
  }
}
