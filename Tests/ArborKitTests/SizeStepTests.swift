import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Windows that take sizes only in steps, as Terminal does with its character cells, and take the step nearest
/// to what they are asked for. Seen on real windows.
@Suite @MainActor struct SizeStepTests {
  /// [terminal | Desktop | notes]
  func makeHarness(step: CGSize) -> (Harness, WindowID, WindowID) {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal", frame: CGRect(x: 300, y: 200, width: 560, height: 340))
    let notes = h.system.open(app: "Notes")
    h.system.setSizeStep(terminal, step)
    h.start()
    h.run("dock \(terminal.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    return (h, terminal, notes)
  }

  func isTile(_ h: Harness, _ window: WindowID) -> Bool {
    h.layout?.tiles.contains { $0.windows.contains(window) } == true
  }

  /// Inside the slot, give or take the two points any window is allowed, and no more than a step smaller.
  func expectFits(
    _ h: Harness, _ window: WindowID, step: CGSize, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    #expect(!isTile(h, window), "it is a tile", sourceLocation: sourceLocation)
    let slot = try #require(h.layout?.windowFrames[window], sourceLocation: sourceLocation)
    let frame = try #require(h.frame(window), sourceLocation: sourceLocation)
    #expect(slot.insetBy(dx: -2, dy: -2).contains(frame), "\(frame) in \(slot)", sourceLocation: sourceLocation)
    #expect(
      slot.width - frame.width <= step.width + 2 && slot.height - frame.height <= step.height + 2,
      "\(frame) in \(slot) gives away more than a step", sourceLocation: sourceLocation)
  }

  @Test(arguments: [
    CGSize(width: 7, height: 15), CGSize(width: 7, height: 17), CGSize(width: 8, height: 19), CGSize(width: 10, height: 23),
    CGSize(width: 13, height: 29), CGSize(width: 17, height: 35),
  ])
  func aWindowThatRoundsToTheNearestStepStaysInsideItsSlot(step: CGSize) throws {
    let (h, terminal, notes) = makeHarness(step: step)
    try expectFits(h, terminal, step: step)
    // Every width a seam can give it, so that both roundings are met.
    for _ in 0..<12 {
      h.run("resize \(terminal.rawValue) right 3")
      try expectFits(h, terminal, step: step)
    }
    h.run("dock \(notes.rawValue) beside \(terminal.rawValue) bottom")
    try expectFits(h, terminal, step: step)
    h.run("zoom \(terminal.rawValue)")
    try expectFits(h, terminal, step: step)
  }

  @Test func aLargerFontDoesNotTurnADockedTerminalIntoATile() throws {
    let (h, terminal, _) = makeHarness(step: CGSize(width: 7, height: 15))
    let before = try #require(h.frame(terminal))
    // ⌘+: the cells grow, the rows and columns stay, so the window resizes itself out of its slot.
    let larger = CGSize(width: 8, height: 17)
    h.system.setSizeStep(terminal, larger)
    h.system.userMove(
      terminal,
      to: CGRect(x: before.minX, y: before.minY, width: before.width / 7 * 8, height: before.height / 15 * 17))
    h.scheduler.runPending()
    try expectFits(h, terminal, step: larger)
  }

  @Test func aWindowWhoseMinimumIsALittleOverItsSlotIsStillATile() throws {
    let h = Harness()
    let stubborn = h.system.open(app: "Stubborn")
    let notes = h.system.open(app: "Notes")
    h.start()
    h.run("dock \(stubborn.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    let slot = try #require(h.layout?.windowFrames[stubborn])
    h.system.setMinimumSize(stubborn, CGSize(width: slot.width - 20, height: 100))
    h.system.clearFrameLog()
    h.run("resize \(stubborn.rawValue) right -30")
    #expect(isTile(h, stubborn))
    // The slot, then 20, 36 points less (ten over: a step of 36 would have given way by then), then out of view.
    #expect(h.system.frameLog.filter { $0.window == stubborn }.count <= 5, "a handful of requests, once")
    // What was learned holds: the next layouts do not try again.
    h.system.clearFrameLog()
    h.run("resize \(notes.rawValue) left 10")
    #expect(h.system.frameLog.filter { $0.window == stubborn }.isEmpty)
  }

  @Test func itIsNotAskedAgainWhileItsSlotStaysTheSame() throws {
    let (h, terminal, notes) = makeHarness(step: CGSize(width: 7, height: 17))
    h.system.clearFrameLog()
    h.run("resize \(notes.rawValue) left 40")
    h.run("resize \(notes.rawValue) left -40")
    #expect(h.system.frameLog.filter { $0.window == terminal }.isEmpty, "no growing and shrinking on every layout")
  }

  // MARK: Floating

  /// The guide's first two moves on a 1728 × 1117 display, with the sizes the compat lab measured (Terminal's to the
  /// whole cell: the fake has no title bar to add).
  func firstMinute(settings: Settings = Settings()) -> (Harness, safari: WindowID, terminal: WindowID) {
    let display = DisplaySnapshot(
      id: DisplayID("main"), frame: CGRect(x: 0, y: 0, width: 1728, height: 1117),
      visibleFrame: CGRect(x: 0, y: 33, width: 1728, height: 1084), isMain: true)
    let h = Harness(displays: [display], settings: settings)
    let safari = h.system.open(
      app: "Safari", pid: 2001, frame: CGRect(x: 200, y: 100, width: 1324, height: 940),
      minimumSize: CGSize(width: 574, height: 240))
    let terminal = h.system.open(
      app: "Terminal", pid: 2002, frame: CGRect(x: 300, y: 150, width: 875, height: 495),
      minimumSize: CGSize(width: 177, height: 124))
    h.system.setSizeStep(terminal, CGSize(width: 7, height: 15))
    h.start()
    return (h, safari, terminal)
  }

  /// Squeezed onto the Desktop, a floating Terminal takes the cell nearest to what it is asked for, which can be the
  /// larger one. Read as "it will not be made that small", that was a minimum of 861 points for a window that goes
  /// down to 177, and when it was docked next, room was made for it: browser 574, Desktop 245, Terminal 861.
  @Test func aFloatingTerminalSqueezedOntoTheDesktopTeachesNoMinimum() throws {
    let (h, safari, terminal) = firstMinute()
    h.run("dock \(safari.rawValue) left")
    let floating = try #require(h.frame(terminal))
    #expect(floating.width == 854, "asked for 858 it took 861, the nearest cell; asked for less, the cell below: \(floating)")
    #expect(h.visibleFrame.contains(floating))

    h.run("dock \(terminal.rawValue) right")
    // Thirds, but for the browser's own minimum, which is real.
    #expect(h.frame(safari)?.width == 574)
    #expect(h.frame(terminal)?.width == 560)
    #expect(try #require(h.layout?.desktopFrame).width > 500, "\(h.layout!.desktopFrame!)")
    #expect(!isTile(h, terminal) && !isTile(h, safari))
  }

  /// Nor is it asked over and over for the frame it answers with a cell less.
  @Test func aFloatingTerminalThatTookTheCellBelowIsLeftInPeace() throws {
    let (h, safari, terminal) = firstMinute()
    h.run("dock \(safari.rawValue) left")
    let took = try #require(h.frame(terminal))
    h.system.clearFrameLog()
    for _ in 0..<3 { h.controller.apply(settings: h.controller.settings) }
    #expect(h.system.frameLog.filter { $0.window == terminal }.isEmpty)
    #expect(h.frame(terminal) == took)
    // What it had before is still what it goes back to.
    h.run("float-all")
    #expect(h.frame(terminal) == CGRect(x: 300, y: 150, width: 875, height: 495))
  }

  /// A real minimum is still learned: more than a step over, or standing by it when asked for less.
  @Test func aFloatingWindowWithARealMinimumStillTeachesIt() throws {
    let (h, safari, terminal) = firstMinute()
    h.system.setMinimumSize(terminal, CGSize(width: 861, height: 124))
    h.run("dock \(safari.rawValue) left")
    #expect(h.frame(terminal)?.width == 861)
    #expect(h.visibleFrame.contains(try #require(h.frame(terminal))))
    h.system.clearFrameLog()
    h.controller.apply(settings: h.controller.settings)
    #expect(h.system.frameLog.filter { $0.window == terminal }.isEmpty, "known, so placed in one move and left there")
  }

  /// Alone on the Desktop and taking all of it (F18), the same.
  @Test func aTerminalThatFillsTheDesktopTeachesNoMinimumEither() throws {
    var settings = Settings()
    settings.soleFloatTakesDesktop = true
    let (h, safari, terminal) = firstMinute(settings: settings)
    h.run("dock \(safari.rawValue) left")
    let desktop = try #require(h.layout?.desktopFrame)
    let filling = try #require(h.frame(terminal))
    #expect(desktop.insetBy(dx: -2, dy: -2).contains(filling), "\(filling) on \(desktop)")
    h.run("dock \(terminal.rawValue) right")
    #expect(h.frame(safari)?.width == 574)
    #expect(h.frame(terminal)?.width == 560)
  }
}
